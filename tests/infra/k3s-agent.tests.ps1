# tests/infra/k3s-agent.tests.ps1 — infra/bootstrap/k3s-agent.sh 정적 검사 스위트 (T036)
# Run: pwsh -NoProfile -File tests/infra/k3s-agent.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크 없음(tests/infra/k3s-server.tests.ps1 과 같은 구조). 문자열 비교는 전부 Ordinal.
#
# fail closed: 대상 파일이 없으면 전 단언 FAIL. 유일한 SKIP은 syntax-1(bash -n) — Windows에서 Git bash를 찾지 못하면
# 'SKIP syntax-1 -- ...' 한 줄을 내고 합계(passed/failed)에 넣지 않는다(WSL의 System32\bash.exe는 쓰지 않는다: Windows 경로를 못 읽는다).
# 실행(SSH·노드·K3s 설치)은 하지 않는다 — 이 스위트는 원문만 읽는다. 실행 검증(두 번 실행해 changes this run: 0, 워크스테이션에서 2 Ready)은
# 운영자가 노드 B에서 한다(.claude/rules/infra.md).
#
# 검사 계약(k3s-agent.sh 구현자가 따라야 하는 형태 — 이 스위트가 곧 계약이다):
#   FILE   file-1 존재  file-2 첫 줄 '#!/usr/bin/env bash'  file-3 CR 없음(LF only)·끝 개행  file-4 'set -euo pipefail' 한 줄
#          file-5 한 local 안에서 자기 선언 변수를 참조하지 않음(SC2318)
#   CFG    cfg-1 경로 /etc/rancher/k3s/config.yaml  cfg-2 server: "$K3S_URL"(기본 https://10.0.7.78:6443)  cfg-3 token-file: $K3S_TOKEN_FILE(기본 /etc/rancher/k3s/token)
#          cfg-4 node-label 정확히 ["role=data"]  cfg-5 write_if_changed ... 600  cfg-6 렌더된 최상위 키가 허용 집합(4개)과 정확히 같다
#          cfg-7 main 순서 check_server_reachable < check_token_file < render_resolv_conf < render_config < install_k3s < ensure_service < wait_node_registered
#          cfg-8 resolv-conf: $K3S_RESOLV_CONF(= $K3S_CONFIG_DIR/resolv.conf)
#   DNS    dns-1 render_resolv_conf 가 write_if_changed … 644 로 렌더  dns-2 기본 K3S_RESOLV_NAMESERVERS 목록이 전부 공개 주소
#          dns-3 렌더 본문은 주석 + nameserver 줄뿐(search·options·domain 없음)  dns-4 코드에 링크로컬 169.254/16 리터럴 없음
#          dns-5 preflight 가 목록을 배열로 읽어 is_public_nameserver 로 검사·die + 헬퍼가 루프백·사설·링크로컬·멀티캐스트 거부
#          dns-6 main 순서 preflight < render_resolv_conf < render_config  dns-7 resolv.conf 변경이 CHANGES·CONFIG_CHANGED 에 반영(재시작 없음)
#          dns-8 summary 에 resolv-conf 경로·mode·nameservers
#   FORBID forbid-1 외부 IP 키 없음  forbid-2 번들 컴포넌트 끄기 없음  forbid-3 서버 전용 키 없음(tls-san·secrets-encryption·flannel-backend·write-kubeconfig-mode)
#          forbid-4 구 호스트명 k3s.joshuatech.dev 없음  forbid-5 채널 설치 없음  forbid-6 curl 파이프 sh 없음  forbid-7 IMDS 조회 없음
#          forbid-8 kubectl 호출 없음(노드 B에는 없다)·클러스터 변경 명령 없음  forbid-9 host-prep 재구성 없음  forbid-10 set -x/xtrace/bash -x 없음
#   TOKEN  tok-1 openssl rand 없음  tok-2 echo … token 없음  tok-3 K3S_TOKEN= 없음  tok-4 토큰 파일을 읽어 출력하는 도구 없음
#          tok-5 존재·600·root:root·-s 검증 + die  tok-6 짧은 형식 거부(^K10 요구)  tok-7 보안 형식 정규식 K10<hex64>::server:
#          tok-8 k3s.yaml 참조 없음  tok-9 check_token_file 본문에 내용 판독 도구 없음 + 그 안의 모든 grep이 -q/-c
#          tok-10 CA 해시 추출은 K10<hex64> 캡처만(비밀번호 미출력) + 로그는 절단 표기
#   VER    ver-1 기본 v1.36.4+k3s1  ver-2 INSTALL_K3S_VERSION="$K3S_VERSION"  ver-3 INSTALL_K3S_EXEC=agent 뿐(CLI 인자·K3S_URL·K3S_TOKEN env 없음)
#          ver-4 다른 버전 die  ver-5 같은 버전 + unit 존재면 skip  ver-6 버전 형식 정규식
#   PRE    pre-1 root  pre-2 Ubuntu 24.04 + aarch64  pre-3 cgroup2fs  pre-4 wireguard  pre-5 rules.v4 51820/udp·10250/tcp  pre-6 Asia/Seoul 검증
#          pre-7 ufw 활성 die  pre-8 'host-prep.sh 먼저' die ≥ 5  pre-9 NODE_PRIVATE_IP 기본 10.0.10.193 + 로컬 인터페이스 가드
#          pre-10 K3S_URL 기본·형식 검증  pre-11 노드 A 오실행 가드(server 디렉터리·자기 자신 URL)
#   INST   inst-1 INSTALL_SCRIPT 기본 + 사본 sanity  inst-2 sha256 대조  inst-3 env -i 격리 실행 한 줄(EXEC=agent)  inst-4 설치 뒤 버전 재확인
#          inst-5 is-enabled/is-active 가드가 enable --now 보다 앞(unit k3s-agent)  inst-6 등록 로그 대기(REGISTER_TIMEOUT=90, journalctl, warn)
#          inst-7 config 변경 + 실행 중이면 warn(재시작 없음)  inst-8 서버 도달 확인이 설치보다 앞
#   IDEM   idem-1 cmp -s가 mv보다 앞  idem-2 같은 디렉터리 mktemp -p + mv -f  idem-3 내용 같고 권한만 다르면 권한만  idem-4 버전 검사가 설치보다 앞
#   LOG    log-1 '[k3s-agent]' 접두  log-2 'changes this run: %d'  log-3 summary 필드
#   STDIN  stdin-1 마지막 줄 'main "$@" </dev/null; exit'
#   SECRET secret-1 비밀로 보이는 문자열 없음
#   SYNTAX syntax-1 bash -n (bash 없으면 SKIP)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$target = Join-Path $repo 'infra/bootstrap/k3s-agent.sh'

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

# 파드 DNS 업스트림으로 쓸 수 있는 주소인가 — 스크립트의 is_public_nameserver 와 같은 판정을 PowerShell 쪽에서 독립 구현한다
# (0/8·127/8·10/8·172.16/12·192.168/16·169.254/16(OCI VCN 리졸버·IMDS)·224+ 거부). 기본값 목록을 문자열 비교가 아니라 의미로 검사하기 위한 것.
function Test-PublicIPv4([string]$ip) {
    $m = [regex]::Match($ip, '^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
    if (-not $m.Success) { return $false }
    $o = @(1, 2, 3, 4 | ForEach-Object { [int]$m.Groups[$_].Value })
    if (@($o | Where-Object { $_ -gt 255 }).Count -gt 0) { return $false }
    if (@(0, 10, 127) -contains $o[0]) { return $false }
    if ($o[0] -eq 169 -and $o[1] -eq 254) { return $false }
    if ($o[0] -eq 172 -and $o[1] -ge 16 -and $o[1] -le 31) { return $false }
    if ($o[0] -eq 192 -and $o[1] -eq 168) { return $false }
    if ($o[0] -ge 224) { return $false }
    return $true
}

$allNames = @('file-1', 'file-2', 'file-3', 'file-4', 'file-5',
    'cfg-1', 'cfg-2', 'cfg-3', 'cfg-4', 'cfg-5', 'cfg-6', 'cfg-7', 'cfg-8',
    'dns-1', 'dns-2', 'dns-3', 'dns-4', 'dns-5', 'dns-6', 'dns-7', 'dns-8',
    'forbid-1', 'forbid-2', 'forbid-3', 'forbid-4', 'forbid-5', 'forbid-6', 'forbid-7', 'forbid-8', 'forbid-9', 'forbid-10',
    'tok-1', 'tok-2', 'tok-3', 'tok-4', 'tok-5', 'tok-6', 'tok-7', 'tok-8', 'tok-9', 'tok-10',
    'ver-1', 'ver-2', 'ver-3', 'ver-4', 'ver-5', 'ver-6',
    'pre-1', 'pre-2', 'pre-3', 'pre-4', 'pre-5', 'pre-6', 'pre-7', 'pre-8', 'pre-9', 'pre-10', 'pre-11',
    'inst-1', 'inst-2', 'inst-3', 'inst-4', 'inst-5', 'inst-6', 'inst-7', 'inst-8',
    'idem-1', 'idem-2', 'idem-3', 'idem-4', 'log-1', 'log-2', 'log-3', 'stdin-1', 'secret-1', 'syntax-1')

if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    # fail closed: 파일이 없으면 계약의 단언 전부 FAIL
    foreach ($n in $allNames) { Assert $n $false "missing: infra/bootstrap/k3s-agent.sh" }
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

# render_resolv_conf 가 실제로 파일에 쓰는 줄들 — 'content=' / 'content+=' 오른쪽의 큰따옴표 문자열만 모은다(루프 줄의 "nameserver $ns" 포함).
# 없으면 빈 배열(dns 단언이 FAIL 되게).
$resolvBody = Get-FunctionBody $text 'render_resolv_conf'
$resolvRendered = @()
if ($null -ne $resolvBody) {
    foreach ($l in @($resolvBody -split "`n")) {
        $rhs = [regex]::Match($l, 'content\+?=(.*)$')
        if (-not $rhs.Success) { continue }
        foreach ($q in [regex]::Matches($rhs.Groups[1].Value, '"([^"]*)"')) { $resolvRendered += $q.Groups[1].Value }
    }
}
# 기본 nameserver 목록(상수 줄에서 뽑는다)
$resolvDefaults = @()
$mDef = [regex]::Match($codeText, '(?m)^K3S_RESOLV_NAMESERVERS="\$\{K3S_RESOLV_NAMESERVERS:-([^}"]*)\}"$')
if ($mDef.Success) { $resolvDefaults = @($mDef.Groups[1].Value -split '\s+' | Where-Object { $_.Length -gt 0 }) }

# ---------- FILE ----------
Test-Group 'file' {
    Assert 'file-1: infra/bootstrap/k3s-agent.sh exists' $true ''
    Assert 'file-2: first line is #!/usr/bin/env bash' ([string]::Equals($lines[0], '#!/usr/bin/env bash', [StringComparison]::Ordinal)) "first line: '$($lines[0])'"
    Assert 'file-3: LF only (no CR) and ends with newline' ((-not (Has $text "`r")) -and $text.EndsWith("`n", [StringComparison]::Ordinal)) 'CR found or missing final newline (.gitattributes forces LF; bash chokes on CRLF)'
    Assert 'file-4: set -euo pipefail present as a whole line' (@($lines | Where-Object { [string]::Equals($_, 'set -euo pipefail', [StringComparison]::Ordinal) }).Count -ge 1) 'no exact line "set -euo pipefail"'
    # SC2318: bash는 'local a=1 b=$a' 한 줄의 모든 단어를 builtin 실행 전에 확장한다 — $a는 호출자 스코프의 동명 변수로 우연히 채워질 뿐이다.
    $badLocal = @()
    foreach ($l in $code) {
        if ($l -cnotmatch '^\s*local\s') { continue }
        foreach ($d in @([regex]::Matches($l, '(?<![\w$])([A-Za-z_][A-Za-z0-9_]*)=') | ForEach-Object { $_.Groups[1].Value })) {
            if ($l -cmatch ('\$\{?' + [regex]::Escape($d) + '\b')) { $badLocal += $l.Trim() }
        }
    }
    Assert 'file-5: no single "local" declares and dereferences the same name (SC2318 — it silently reads the caller scope)' ($badLocal.Count -eq 0) ($badLocal -join ' | ')
}

# ---------- CFG ----------
Test-Group 'cfg' {
    Assert 'cfg-1: config path /etc/rancher/k3s/config.yaml' ((Has $codeText 'K3S_CONFIG_DIR=/etc/rancher/k3s') -and (Has $codeText 'K3S_CONFIG="$K3S_CONFIG_DIR/config.yaml"') -and ($cfg.Length -gt 0)) 'path constants or render_config heredoc missing'
    Assert 'cfg-2: server: "$K3S_URL" with default https://10.0.7.78:6443 (node A private IP)' (((CfgVal 'server') -contains '"$K3S_URL"') -and (Has $codeText 'K3S_URL="${K3S_URL:-https://10.0.7.78:6443}"')) "server = $((CfgVal 'server') -join ',')"
    Assert 'cfg-3: token-file: $K3S_TOKEN_FILE with default /etc/rancher/k3s/token' (((CfgVal 'token-file') -contains '$K3S_TOKEN_FILE') -and (Has $codeText 'K3S_TOKEN_FILE="${K3S_TOKEN_FILE:-/etc/rancher/k3s/token}"')) "token-file = $((CfgVal 'token-file') -join ',')"
    $lbl = @(CfgVal 'node-label')
    Assert 'cfg-4: node-label exactly ["role=data"]' ($lbl.Count -eq 1 -and $lbl[0] -eq '"role=data"') "node-label = [$($lbl -join ', ')]"
    Assert 'cfg-5: rendered with write_if_changed "$K3S_CONFIG" "$content" 600' ($null -ne $renderBody -and (Has $renderBody 'write_if_changed "$K3S_CONFIG" "$content" 600')) 'write_if_changed ... 600 call missing'
    $allowed = @('server', 'token-file', 'node-label', 'resolv-conf')
    $keys = @($cfgKeys.Keys)
    $extra = @($keys | Where-Object { $allowed -notcontains $_ })
    $missing = @($allowed | Where-Object { $keys -notcontains $_ })
    Assert 'cfg-6: rendered top-level keys are exactly the allowed 4 (no extra keys, no unparsed lines)' ($extra.Count -eq 0 -and $missing.Count -eq 0) "extra=[$($extra -join ',')] missing=[$($missing -join ',')]"
    # 주석 제거 후 판정(줄 끝 주석의 함수 이름이 호출 위치로 오인되지 않게). preflight·check_host_prep·check_install_script 의 호출부까지 고정한다 —
    # 정의만 있고 아무도 부르지 않으면 검증이 통째로 죽는다.
    $mb = Get-FunctionBody $text 'main'
    $mbCode = $null
    if ($null -ne $mb) { $mbCode = (($mb -split "`n" | ForEach-Object { ($_ -replace '#.*$', '') }) -join "`n") }
    $order = @('preflight', 'check_host_prep', 'check_server_reachable', 'check_token_file', 'check_ca_hash', 'render_resolv_conf', 'render_config', 'install_k3s', 'ensure_service', 'wait_node_registered', 'summary')
    $ok = $null -ne $mbCode
    if ($ok) { for ($i = 0; $i -lt $order.Count; $i++) { if ((Idx $mbCode $order[$i]) -lt 0) { $ok = $false } elseif ($i -gt 0 -and (Idx $mbCode $order[$i - 1]) -ge (Idx $mbCode $order[$i])) { $ok = $false } } }
    $ib = Get-FunctionBody $text 'install_k3s'
    $installCheck = ($null -ne $ib) -and ((Idx $ib 'check_install_script') -ge 0) -and ((Idx $ib 'check_install_script') -lt (Idx $ib 'sh "$INSTALL_SCRIPT"'))
    Assert 'cfg-7: main calls preflight -> check_host_prep -> check_server_reachable -> check_token_file -> check_ca_hash -> render_resolv_conf -> render_config -> install_k3s -> ensure_service -> wait_node_registered -> summary, and install_k3s calls check_install_script before running it' ($ok -and $installCheck) "order ok=$ok install_k3s calls check_install_script first=$installCheck"
    Assert 'cfg-8: resolv-conf: $K3S_RESOLV_CONF (= $K3S_CONFIG_DIR/resolv.conf) — kubelet --resolv-conf, valid agent flag (pkg/cli/cmds/agent.go ResolvConfFlag)' (((CfgVal 'resolv-conf') -contains '$K3S_RESOLV_CONF') -and (Has $codeText 'K3S_RESOLV_CONF="$K3S_CONFIG_DIR/resolv.conf"')) "resolv-conf = $((CfgVal 'resolv-conf') -join ',')"
}

# ---------- DNS(파드 DNS 업스트림, 2026-09-08 결정 B — T041 kube-system/deny-imds 선행 게이트) ----------
Test-Group 'dns' {
    $pb = Get-FunctionBody $text 'preflight'
    $hb = Get-FunctionBody $text 'is_public_nameserver'
    $sb = Get-FunctionBody $text 'ensure_service'
    Assert 'dns-1: render_resolv_conf renders $K3S_RESOLV_CONF with write_if_changed ... 644 (root:root via the helper)' ($null -ne $resolvBody -and (Has $resolvBody 'write_if_changed "$K3S_RESOLV_CONF" "$content" 644')) 'render_resolv_conf missing or not rendered through write_if_changed with mode 644'
    $badDefault = @($resolvDefaults | Where-Object { -not (Test-PublicIPv4 $_) })
    Assert 'dns-2: K3S_RESOLV_NAMESERVERS default is a non-empty list of public resolvers (no VCN/IMDS link-local, loopback, private or multicast address)' ($resolvDefaults.Count -ge 1 -and $badDefault.Count -eq 0) "defaults=[$($resolvDefaults -join ' ')] rejected=[$($badDefault -join ' ')]"
    $bad = @($resolvRendered | Where-Object { $_ -cnotmatch '^#' -and $_ -cnotmatch '^nameserver \S+$' })
    $hasNs = @($resolvRendered | Where-Object { $_ -cmatch '^nameserver ' }).Count -ge 1
    Assert 'dns-3: the rendered resolv.conf holds only comments and "nameserver <x>" lines (no search/options/domain — pods never use oraclevcn.com names)' ($resolvRendered.Count -ge 1 -and $hasNs -and $bad.Count -eq 0) "rendered=[$($resolvRendered -join ' | ')] offending=[$($bad -join ' | ')]"
    Assert 'dns-4: no 169.254/16 literal in code lines (the VCN resolver = IMDS address must never be a rendered or default nameserver)' (-not (Has $codeText '169.254.')) 'a link-local nameserver would be blocked by kube-system/deny-imds and break cluster DNS'
    $helperOk = ($null -ne $hb) -and (Has $hb '0 | 10 | 127) return 1') -and (Has $hb '169) [ "$b" -ne 254 ] || return 1') -and (Has $hb '172)') -and (Has $hb '-lt 16') -and (Has $hb '-gt 31') -and (Has $hb '192) [ "$b" -ne 168 ] || return 1') -and (Has $hb '[ "$a" -lt 224 ] || return 1')
    $preOk = ($null -ne $pb) -and (Has $pb 'read -r -a RESOLV_NS <<< "$K3S_RESOLV_NAMESERVERS"') -and (Has $pb 'is_public_nameserver "$ns" || die')
    Assert 'dns-5: preflight reads the list into RESOLV_NS and dies on a non-public entry; is_public_nameserver rejects 0/8,10/8,127/8,169.254/16,172.16/12,192.168/16,224+' ($helperOk -and $preOk) "helper ok=$helperOk preflight ok=$preOk"
    $mb = Get-FunctionBody $text 'main'
    Assert 'dns-6: main order preflight < render_resolv_conf < render_config (the file must exist before config.yaml points at it)' ($null -ne $mb -and (Idx $mb 'render_resolv_conf') -gt (Idx $mb 'preflight') -and (Idx $mb 'render_resolv_conf') -lt (Idx $mb 'render_config')) 'render_resolv_conf missing from main or in the wrong place'
    Assert 'dns-7: a resolv.conf change counts as a change and only warns (CONFIG_CHANGED wiring, no restart)' ($null -ne $resolvBody -and (Has $resolvBody 'before=${#CHANGES[@]}') -and (Has $resolvBody '[ "${#CHANGES[@]}" -eq "$before" ] || CONFIG_CHANGED=1') -and ($null -ne $sb) -and (Has $sb '$K3S_RESOLV_CONF') -and (-not (Has $codeText 'systemctl restart'))) 'idempotency counter or the warn-only branch is missing'
    $sm = Get-FunctionBody $text 'summary'
    Assert 'dns-8: summary prints the resolv-conf path, mode and nameservers' ($null -ne $sm -and (Has $sm 'resolv-conf: %s mode=%s nameservers=[%s]') -and (Has $sm '"$K3S_RESOLV_CONF"') -and (Has $sm '"${RESOLV_NS[*]}"')) 'summary line missing'
}

# ---------- FORBID ----------
Test-Group 'forbid' {
    Assert 'forbid-1: no node-external-ip (code or rendered config)' (-not (Has $codeText 'node-external-ip')) 'K3S-D3: OCI public IP is NAT; ServiceLB externalTrafficPolicy=Local misbehaves'
    Assert 'forbid-2: no "disable" key/flag' (($cfg -cnotmatch '(?m)^\s*disable[A-Za-z-]*:') -and (-not (Has $codeText '--disable'))) 'K3S-D3: bundled components stay (server decides)'
    $serverOnly = @('tls-san', 'secrets-encryption', 'flannel-backend', 'write-kubeconfig-mode')
    $leak = @($serverOnly | Where-Object { $cfg -cmatch ('(?m)^' + [regex]::Escape($_) + ':') })
    Assert 'forbid-3: no server-only keys in the agent config (tls-san, secrets-encryption, flannel-backend, write-kubeconfig-mode)' ($leak.Count -eq 0) "server-only keys rendered: $($leak -join ',')"
    Assert 'forbid-4: no stale hostname k3s.joshuatech.dev anywhere' (-not (Has $text 'k3s.joshuatech.dev')) 'the tunnel host is k8s.joshuatech.dev and the agent joins by private IP anyway'
    Assert 'forbid-5: no INSTALL_K3S_CHANNEL in code (version pinned)' (-not (Has $codeText 'INSTALL_K3S_CHANNEL')) 'K3S-D1: channel resolution is not reproducible'
    Assert 'forbid-6: no curl | sh (installer runs from a reviewed local copy)' (($codeText -cnotmatch 'curl[^\n]*get\.k3s\.io') -and ($codeText -cnotmatch '\|\s*(sudo\s+)?sh\b')) 'curl ... get.k3s.io or "| sh" found in code'
    Assert 'forbid-7: no IMDS lookup (static NODE_PRIVATE_IP)' ((-not (Has $codeText '169.254.169.254')) -and (-not (Has $codeText '/opc/v'))) 'IMDS v1 is off; the private IP is a static input'
    Assert 'forbid-8: no kubectl invocation (node B has none) and no cluster-mutating commands' ((-not (Has $codeText 'k3s kubectl')) -and ($codeText -cnotmatch '(?m)^\s*(sudo\s+)?kubectl\s') -and ($codeText -cnotmatch '(?m)^\s*systemctl\s+(restart|stop)\b') -and (-not (Has $codeText 'k3s-uninstall')) -and ($codeText -cnotmatch '\btofu\b')) 'only install + enable --now may change state; Ready is judged by the operator from the workstation'
    Assert 'forbid-9: host-prep state is verified, never reconfigured' (($codeText -cnotmatch '\biptables\s+-[AI]\b') -and (-not (Has $codeText 'netfilter-persistent reload')) -and (-not (Has $codeText 'modprobe')) -and (-not (Has $codeText 'timedatectl set-timezone')) -and ($codeText -cnotmatch '\bapt(-get)?\s+install\b') -and ($codeText -cnotmatch '\bufw\s+(allow|deny|enable|default|reject|route|insert)\b')) 'iptables/modules/timezone/packages belong to host-prep.sh'
    Assert 'forbid-10: no shell tracing (set -x / xtrace / bash -x) — tracing would echo the token path handling' (($codeText -cnotmatch '(?m)^\s*set\s+-[a-z]*x') -and (-not (Has $codeText 'xtrace')) -and ($codeText -cnotmatch '\bbash\s+-[a-z]*x\b')) 'tracing found in code lines'
}

# ---------- TOKEN ----------
Test-Group 'tok' {
    $t = Get-FunctionBody $text 'check_token_file'
    Assert 'tok-1: no openssl rand in code (the token comes from node A server/token)' (-not (Has $codeText 'openssl rand')) 'the script must not generate a token'
    Assert 'tok-2: no echo ... token line in code' ($codeText -cnotmatch '(?im)echo[^\n]*token') 'token content must never reach stdout/logs'
    Assert 'tok-3: no K3S_TOKEN= env usage' (-not (Has $codeText 'K3S_TOKEN=')) 'K3S_TOKEN would be persisted in k3s-agent.service.env; token-file in config.yaml only'
    Assert 'tok-4: the token file is never read into output (no cat/head/tail/od/xxd/hexdump/base64/strings on token paths)' (($codeText -cnotmatch '(?m)\b(cat|head|tail|od|xxd|hexdump|base64|strings)\b[^\n]*(K3S_TOKEN_FILE|/etc/rancher/k3s/token|server/token)') -and ($codeText -cnotmatch '\$\(<[^\n]*TOKEN') -and ($codeText -cnotmatch '\bread\b[^\n]*<[^\n]*TOKEN')) 'token file content read found'
    Assert 'tok-5: token file checked for existence, mode 600, owner root:root, non-empty (die otherwise)' ($null -ne $t -and (Has $t '[ -f "$f" ] || die') -and (Has $t 'stat -c %a "$f"') -and (Has $t '[ "$mode" = 600 ] || die') -and (Has $t '[ "$owner" = root:root ] || die') -and (Has $t '[ -s "$f" ] || die')) 'check_token_file missing one of the guards'
    Assert 'tok-6: short-form token (password only) is rejected — the join token MUST be the secure form' ($null -ne $t -and (Has $t "grep -q '^K10' `"`$f`" || die")) 'agent join needs node A server/token (K10...) so the cluster CA hash is verified before joining (K3S-D5)'
    Assert 'tok-7: secure-format regex K10<64 hex>::server:<pw>, single line, no whitespace' ($null -ne $t -and (Has $t "'^K10[0-9a-f]{64}::server:[^[:space:]]+[[:space:]]*`$'") -and (Has $t "grep -c '' `"`$f`"") -and (Has $t '-eq 1 ] || die')) 'secure-format / line-count guard missing'
    Assert 'tok-8: code never references the admin kubeconfig path (k3s.yaml)' (-not (Has $codeText 'k3s.yaml')) 'the agent node has no kubeconfig'
    # T035 리뷰가 찾은 구멍: 판독 도구가 함수 본문에 있거나 grep이 -q/-c 없이 쓰이면 토큰이 출력으로 샌다.
    $readers = $null -ne $t -and ($t -cmatch '(?m)\b(cat|head|tail|od|xxd|hexdump|base64|strings|awk|sed)\b')
    $greps = @()
    if ($null -ne $t) { $greps = @([regex]::Matches($t, 'grep(\s+-[^\s]+)*') | ForEach-Object { $_.Value }) }
    $badGreps = @($greps | Where-Object { $_ -cnotmatch '^grep\s+-[A-Za-z]*[qc]' })
    Assert 'tok-9: check_token_file body has no content-reading tool and every grep on the token path is -q/-c' ($null -ne $t -and (-not $readers) -and $greps.Count -ge 3 -and $badGreps.Count -eq 0) "readers=$readers greps=[$($greps -join ' | ')] non-quiet=[$($badGreps -join ' | ')]"
    # CA 해시 대조는 토큰 파일을 읽는 유일한 예외다. 허용 범위: K10<hex64> 캡처만 출력하고 비밀번호(::server: 뒤)는 치환에서 버린다.
    $th = Get-FunctionBody $text 'token_ca_hash'
    $ch = Get-FunctionBody $text 'check_ca_hash'
    # 출력 문구 부분만 본다 — `[ -z "$want" ]` 같은 검사식에 들어간 변수는 출력이 아니다.
    $hashPrints = @()
    if ($null -ne $ch) {
        foreach ($l in ($ch -split "`n")) {
            $m = [regex]::Match($l, '\b(log|warn|die|printf|echo)\b(?<msg>.*)$')
            if (-not $m.Success) { continue }
            $msg = $m.Groups['msg'].Value
            if ($msg -cmatch '\$\{?(want|have)\b' -and $msg -cnotmatch '\$\{(want|have):0:') { $hashPrints += $l.Trim() }
        }
    }
    $sedSafe = ($null -ne $th) -and (Has $th 'sed -n ''1s/^K10\([0-9a-f]\{64\}\)::server:.*$/\1/p'' "$K3S_TOKEN_FILE"')
    Assert 'tok-10: the CA-hash reader prints only the K10 hash capture (never the password half) and logs hashes truncated' ($sedSafe -and ($null -ne $ch) -and $hashPrints.Count -eq 0 -and (Has $ch '/cacerts')) "sed capture ok=$sedSafe; untruncated hash logged on: $($hashPrints -join ' | ')"
}

# ---------- VER ----------
Test-Group 'ver' {
    $ib = Get-FunctionBody $text 'install_k3s'
    Assert 'ver-1: K3S_VERSION default v1.36.4+k3s1 (same as the server)' (Has $codeText 'K3S_VERSION="${K3S_VERSION:-v1.36.4+k3s1}"') 'version pin missing'
    Assert 'ver-2: installer gets INSTALL_K3S_VERSION="$K3S_VERSION"' (Has $codeText 'INSTALL_K3S_VERSION="$K3S_VERSION"') 'INSTALL_K3S_VERSION not passed from K3S_VERSION'
    Assert 'ver-3: INSTALL_K3S_EXEC=agent only; no K3S_URL/K3S_TOKEN env to the installer (they would land in k3s-agent.service.env)' (($codeText -cmatch '(?m)INSTALL_K3S_EXEC=agent sh "\$INSTALL_SCRIPT"(\s*\|\|\s*die[^\n]*)?\s*$') -and (-not (Has $codeText 'INSTALL_K3S_EXEC="')) -and ($codeText -cnotmatch 'sh "\$INSTALL_SCRIPT"\s+(?!\|\|)\S') -and ($codeText -cnotmatch 'env -i[^\n]*K3S_URL')) 'INSTALL_K3S_EXEC must be exactly agent and the installer env carries no K3S_URL/K3S_TOKEN'
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
    Assert 'pre-5: rules.v4 must already contain 51820/udp (flannel) and 10250/tcp (kubelet) INPUT rules' ($null -ne $hb -and (Has $codeText 'RULES_V4=/etc/iptables/rules.v4') -and (Has $hb '--dport 51820 -j ACCEPT') -and (Has $hb '--dport 10250 -j ACCEPT') -and (Has $hb 'grep -qE "^-A INPUT -s [0-9./]+ $p\$" "$RULES_V4" || die')) 'rules.v4 verification missing'
    Assert 'pre-6: timezone Asia/Seoul verified, never set' ($null -ne $hb -and (Has $codeText 'TZ_WANT=Asia/Seoul') -and (Has $hb 'timedatectl show -p Timezone --value') -and (Has $hb '= "$TZ_WANT" ] || die')) 'timezone verification missing'
    Assert 'pre-7: ufw active -> die' ($null -ne $hb -and (Has $hb '"Status: active"') -and ($hb -cmatch 'Status: active"[^\n]*\n\s*die ')) 'ufw guard missing'
    $n = ([regex]::Matches($codeText, 'host-prep\.sh 먼저')).Count
    Assert 'pre-8: at least 5 "host-prep.sh 먼저" die messages' ($n -ge 5) "found $n"
    Assert 'pre-9: NODE_PRIVATE_IP default 10.0.10.193 (node B) and must be a local interface address' ($null -ne $pb -and (Has $codeText 'NODE_PRIVATE_IP="${NODE_PRIVATE_IP:-10.0.10.193}"') -and (Has $pb 'ip -4 -o addr show') -and (Has $pb 'grep -qxF -- "$NODE_PRIVATE_IP" <<< "$addrs" || die') -and (Has $pb '노드 B 전용')) 'local-address guard missing'
    Assert 'pre-10: K3S_URL default https://10.0.7.78:6443 and validated (https, host:port, no path)' ($null -ne $pb -and (Has $codeText 'K3S_URL="${K3S_URL:-https://10.0.7.78:6443}"') -and (Has $pb '"$K3S_URL" =~ ^https://')) 'K3S_URL default/validation missing'
    Assert 'pre-11: running on node A is refused (server data dir present, or K3S_URL pointing at itself)' ($null -ne $pb -and (Has $codeText 'K3S_SERVER_DIR=/var/lib/rancher/k3s/server') -and (Has $pb '[ ! -d "$K3S_SERVER_DIR" ] || die') -and (Has $pb '[ "$server_host" != "$NODE_PRIVATE_IP" ] || die')) 'node A misfire guards missing'
}

# ---------- INST ----------
Test-Group 'inst' {
    $cb = Get-FunctionBody $text 'check_install_script'
    $ib = Get-FunctionBody $text 'install_k3s'
    $sb = Get-FunctionBody $text 'ensure_service'
    $wb = Get-FunctionBody $text 'wait_node_registered'
    $rb = Get-FunctionBody $text 'check_server_reachable'
    $mb = Get-FunctionBody $text 'main'
    Assert 'inst-1: INSTALL_SCRIPT default /tmp/install-k3s.sh; missing -> die; copy sanity (#!/bin/sh, verify_binary)' ((Has $codeText 'INSTALL_SCRIPT="${INSTALL_SCRIPT:-/tmp/install-k3s.sh}"') -and ($null -ne $cb) -and (Has $cb '[ -f "$f" ] || die') -and (Has $cb "'#!/bin/sh'") -and (Has $cb "grep -q 'verify_binary'")) 'install script guard missing'
    Assert 'inst-2: optional INSTALL_SCRIPT_SHA256 compared with sha256sum, mismatch -> die' ($null -ne $cb -and (Has $cb 'sha256sum "$f"') -and (Has $cb '${INSTALL_SCRIPT_SHA256:-}') -and (Has $cb '[ "$have" = "$want" ] || die')) 'sha256 verification missing'
    Assert 'inst-3: installer runs isolated (env -i ... INSTALL_K3S_EXEC=agent sh "$INSTALL_SCRIPT") and a non-zero exit dies' ($null -ne $ib -and ($ib -cmatch '(?m)^\s*env -i PATH="\$PATH" HOME=/root INSTALL_K3S_VERSION="\$K3S_VERSION" INSTALL_K3S_EXEC=agent sh "\$INSTALL_SCRIPT" \|\| die "[^\n]*\$\?[^\n]*"\s*$')) 'env -i invocation line missing, or the installer failure is not turned into a die with $?'
    Assert 'inst-4: version re-checked after install and the k3s-agent unit must exist (die on mismatch)' ($null -ne $ib -and ((Idx $ib 'sh "$INSTALL_SCRIPT"') -lt (Idx $ib '[ "$have" = "$K3S_VERSION" ] || die')) -and (Has $codeText 'K3S_UNIT=/etc/systemd/system/k3s-agent.service') -and (Has $ib '[ -f "$K3S_UNIT" ] || die')) 'post-install verification missing'
    Assert 'inst-5: is-enabled/is-active read before systemctl enable --now k3s-agent' ($null -ne $sb -and (Has $sb 'systemctl is-enabled k3s-agent') -and (Has $sb 'systemctl is-active k3s-agent') -and (Has $sb 'systemctl enable --now k3s-agent') -and ((Idx $sb 'systemctl is-enabled k3s-agent') -lt (Idx $sb 'systemctl enable --now k3s-agent')) -and ((Idx $sb 'systemctl is-active k3s-agent') -lt (Idx $sb 'systemctl enable --now k3s-agent'))) 'service guard missing or after enable'
    # 3단계 판정(T036 실행 실측): 이번 실행(--since) / 이번 부팅(-b, --since 없음) / 없음. 재실행은 새 등록 로그를 남기지 않으므로
    # 두 번째 단계가 없으면 정상 재실행이 매번 WARN 으로 보고돼 오해를 부른다. 세 분기 중 하나라도 빠지면 FAIL 이어야 한다.
    $sinceIdx = if ($null -ne $wb) { Idx $wb 'journalctl -u k3s-agent -b --since "$since"' } else { -1 }
    $bootIdx = if ($null -ne $wb) { Idx $wb 'journalctl -u k3s-agent -b --no-pager' } else { -1 }
    $threeState = ($null -ne $wb) -and ($sinceIdx -ge 0) -and ($bootIdx -ge 0) -and ($sinceIdx -lt $bootIdx) -and
        (Has $wb 'REGISTERED=confirmed') -and (Has $wb 'REGISTERED=confirmed-earlier-in-boot') -and
        ($wb -cmatch '(?m)^\s*warn ') -and ($wb -cnotmatch '(?m)^\s*die ')
    Assert 'inst-6: registration is judged in three states — this run (--since) / earlier in this boot (-b) / neither (WARN only), never dying, with kubectl left to the operator' ((Has $codeText 'REGISTER_TIMEOUT=90') -and (Has $codeText "REGISTER_PATTERN='Successfully registered node|Node was previously registered'") -and (Has $wb 'since=$(date') -and (Has $codeText 'RUN_STARTED_AT=$(date +%s)') -and $threeState -and (Has $wb 'kubectl get nodes')) "three-state=$threeState sinceIdx=$sinceIdx bootIdx=$bootIdx (a stale line must not count as this run, and a re-run must not be reported as a failure)"
    Assert 'inst-7: config changed while the agent already runs -> warn only (no restart)' ($null -ne $sb -and (Has $sb 'CONFIG_CHANGED') -and (Has $sb 'INSTALLED_THIS_RUN') -and ($sb -cmatch '(?m)^\s*warn ') -and (-not (Has $codeText 'systemctl restart'))) 'warn branch missing or restart present'
    Assert 'inst-8: server reachability (curl $K3S_URL/ping) is checked before the installer runs' ($null -ne $rb -and (Has $rb '"$K3S_URL/ping"') -and (Has $rb '|| die') -and ($null -ne $mb) -and ((Idx $mb 'check_server_reachable') -lt (Idx $mb 'install_k3s'))) 'reachability check missing or after install'
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
    Assert 'log-1: [k3s-agent] prefixed log/warn/die helpers' ((Has $codeText "printf '[k3s-agent] %s\n'") -and (Has $codeText "printf '[k3s-agent] WARN: %s\n'") -and (Has $codeText "printf '[k3s-agent] ERROR: %s\n'")) 'log helpers missing'
    Assert 'log-2: summary prints changes this run: N' (Has $codeText "printf 'changes this run: %d\n' `"`${#CHANGES[@]}`"") 'changes summary missing'
    $s = Get-FunctionBody $text 'summary'
    Assert 'log-3: summary shows installed/want version, server, registration state, config changed flag' ($null -ne $s -and (Has $s 'installed=%s want=%s') -and (Has $s 'registration=%s') -and (Has $s 'changed=%s')) 'summary fields missing'
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
    Assert 'secret-1: no secret-looking strings (private key blocks, cloud tokens, embedded keys/OCIDs, literal passwords, real K10 tokens, bare 64-hex)' ($hits.Count -eq 0) ("matched: " + ($hits -join ' | '))
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
        Write-Host 'SKIP syntax-1 -- bash -n: no Git/POSIX bash found on this machine (WSL System32 bash is not used); run "bash -n infra/bootstrap/k3s-agent.sh" where bash exists'
    } else {
        $unixPath = $target -replace '\\', '/'
        $out = & $bash -n $unixPath 2>&1 | Out-String
        $c = $LASTEXITCODE
        Assert "syntax-1: bash -n passes ($bash)" ($c -eq 0) "exit=$c; $($out.Trim())"
    }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
