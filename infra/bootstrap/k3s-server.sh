#!/usr/bin/env bash
# infra/bootstrap/k3s-server.sh — 노드 A(joshtech-api, role=platform) K3s server 설치 + /etc/rancher/k3s/config.yaml 렌더(멱등) — 003-platform-foundation T035
#
# 대상: T014 host-prep.sh 를 마친 노드 A(OCI VM.Standard.A1.Flex, Ubuntu 24.04 arm64, 사설 IP 10.0.7.78). 노드 B(agent) 는 T036 몫이다.
# root 로 실행한다(sudo). 재실행해도 같은 최종 상태이고 중복·오류가 없어야 한다(.claude/rules/infra.md "Bootstrap and operations scripts") —
# 모든 변경 단계는 "존재 검사 → 없을 때만 변경" 형태이며, 2회차 summary 의 "changes this run: 0" 이 멱등의 증명이다.
# 정적 계약은 tests/infra/k3s-server.tests.ps1 이 고정한다.
#
# 하는 일(순서): 전제 검증(host-prep 결과를 검증만 한다 — iptables·모듈·시간대를 재구성하지 않는다) → config.yaml 렌더(0600, 내용이 같으면 손대지 않음)
#   → K3s 설치(운영자가 미리 내려받아 검토한 공식 설치 스크립트 사본을 버전 고정으로 실행; 같은 버전이 이미 있으면 skip, 다른 버전이면 중단)
#   → k3s.service enabled/active 확인 → 노드 Ready 대기(최대 180 s) → 라벨·secrets-encryption 확인 → summary.
#   클러스터 상태를 바꾸는 명령은 설치와 기동(systemctl enable --now)뿐이다.
#
# 입력(환경 변수; sudo VAR=값 형식 — sudoers 의 command ALL 매치가 명령행 환경 변수 지정을 허용한다):
#   K3S_TOKEN_FILE        선택. 기본 /etc/rancher/k3s/token. 운영자가 미리 둔 짧은 형식(비밀번호만) 서버 토큰 파일 — root:root 0600, 한 줄, 공백 없음.
#                         부재·권한 불량·빈 파일·보안 형식(K10…)이면 중단. 이 스크립트는 토큰을 만들지도, 읽어 출력하지도, 로그에 남기지도 않는다.
#   NODE_PRIVATE_IP       선택. 기본 10.0.7.78(노드 A VNIC 사설 IP, T014 실측). IMDS 를 조회하지 않는다(IMDS v1 off — 정적 값). 이 IP 가 로컬
#                         인터페이스에 없으면 중단한다(노드 B 에서 실수로 실행하는 것을 막는다).
#   K3S_VERSION           선택. 기본 v1.36.4+k3s1(research R1 버전 표, 고정). 패치 승격은 system-upgrade-controller Plan 몫이며 여기서 바꾸지 않는다.
#   TLS_SAN_HOST          선택. 기본 k8s.joshuatech.dev(cloudflared 터널 호스트, T011 CNAME).
#   INSTALL_SCRIPT        선택. 기본 /tmp/install-k3s.sh — 운영자가 미리 내려받아 검토한 get.k3s.io 사본(절차 2). 설치가 필요할 때만 요구된다.
#   INSTALL_SCRIPT_SHA256 선택. 지정하면 사본의 sha256 이 이 값과 다를 때 중단한다(워크스테이션에서 검토한 바이트와 노드의 사본이 같음을 증명).
#
# 설치 스크립트 무결성: K3s 는 install.sh 자체의 체크섬을 문서화하지 않는다(2026-09-04 확인). 대신 install.sh 가 내려받는 k3s 바이너리는 릴리스 자산
#   sha256sum-arm64.txt 와 대조된다(install.sh 의 verify_binary). 그래서 이 스크립트는 "curl 파이프 sh" 를 하지 않고, 운영자가 내려받아 눈으로 확인한
#   사본(INSTALL_SCRIPT)을 실행하며 선택적으로 그 사본의 sha256 을 대조한다. 설치 스크립트는 env -i 로 격리 실행한다 — install.sh 는 K3S_* 환경 변수를
#   /etc/systemd/system/k3s.service.env 에 그대로 기록하므로, 모든 플래그가 config.yaml 한 곳에만 있게(K3S-D1) 상속을 끊는다.
#
# 운영자 절차(워크스테이션 PowerShell 7; 키 joshuatech-ops 는 ssh-add -c 로 로드; 노드 A reserved 공개 IP 144.24.85.118; ssh/scp 공통 옵션
#   -i ~/.ssh/joshuatech-ops -o IdentitiesOnly=yes 는 아래에서 "…" 로 줄인다):
#   0. 임시 22/tcp 규칙(사용자 결정 2026-09-04 옵션 A — 창 단위; .claude/rules/infra.md 부트스트랩 예외): T035 시작 때 nsg-cluster 에 운영자 /32 규칙
#      하나를 추가해 T039(cloudflared 터널 가동) 끝까지 유지한다. 추가는 infra/oci/instances.tf 머리 주석 T014 5단계와 같은 명령(description
#      'T035-T039 temp ssh (remove at T039)'). 이 절차에서는 제거하지 않음(T039 몫 — 제거 증명은 nsg rules list). 창 동안 노드 B 의 22 도 열린다.
#   1. 서버 토큰(짧은 형식) — 워크스테이션에서 생성해 비밀번호 관리자에 먼저 저장하고, 노드에는 파일로만 올린다(화면에 찍지 않는다):
#        $tok = (openssl rand -hex 32).Trim()                                   # 64 hex
#        # → 비밀번호 관리자 항목 "k3s server token (node A, short form)" 에 $tok 저장. 노드 B 조인(T036)은 A 가 생성하는 K10 보안 형식을 따로 쓴다.
#        [IO.File]::WriteAllText("$env:TEMP\k3s-token", $tok)                  # 개행 없이 — PowerShell 파이프/Set-Content 는 CRLF 를 붙인다
#        scp … "$env:TEMP\k3s-token" ubuntu@144.24.85.118:/home/ubuntu/k3s-token   # /home/ubuntu 는 0750 — /tmp 보다 좁다
#        ssh … ubuntu@144.24.85.118 "sudo install -d -m 755 -o root -g root /etc/rancher/k3s && sudo install -m 600 -o root -g root /home/ubuntu/k3s-token /etc/rancher/k3s/token && shred -u /home/ubuntu/k3s-token"
#        Remove-Item "$env:TEMP\k3s-token"; Remove-Variable tok
#   2. 설치 스크립트 사본 — 워크스테이션에서 받아 검토·해시를 기록한 뒤 올린다:
#        curl.exe -fsSLo "$env:TEMP\install-k3s.sh" https://get.k3s.io
#        Get-Content "$env:TEMP\install-k3s.sh" | Select-String 'INSTALL_K3S_VERSION|verify_binary|sha256sum-'   # 버전 고정·바이너리 해시 검증 코드가 있는지 눈으로 확인
#        (Get-FileHash -Algorithm SHA256 "$env:TEMP\install-k3s.sh").Hash.ToLower()                                # → runbook §3 T035 기록 + 아래 INSTALL_SCRIPT_SHA256
#        scp … "$env:TEMP\install-k3s.sh" ubuntu@144.24.85.118:/tmp/install-k3s.sh
#   3. 이 스크립트 실행(두 번 — 2회차는 changes this run: 0 이어야 한다):
#        scp … infra/bootstrap/k3s-server.sh ubuntu@144.24.85.118:/tmp/k3s-server.sh
#        ssh … ubuntu@144.24.85.118 "sudo K3S_TOKEN_FILE=/etc/rancher/k3s/token INSTALL_SCRIPT_SHA256=<절차 2 의 해시> bash /tmp/k3s-server.sh"
#        (같은 명령 한 번 더) → summary: changes this run: 0, node Ready=1, labels=1, secrets-encrypt Enabled
#   4. admin kubeconfig(/etc/rancher/k3s/k3s.yaml, root 0600) 1회 취득 — 터미널에 출력하지 않는다(sudo cat … 금지). 복사본을 만들어 scp 로 가져온다:
#        ssh … ubuntu@144.24.85.118 "sudo install -m 600 -o ubuntu -g ubuntu /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s-admin.yaml"
#        scp … ubuntu@144.24.85.118:/home/ubuntu/k3s-admin.yaml "$env:TEMP\k3s-admin.yaml"
#        ssh … ubuntu@144.24.85.118 "shred -u /home/ubuntu/k3s-admin.yaml"
#      파일의 server: 는 기본 https://127.0.0.1:6443 — cloudflared 경유(T039 뒤: cloudflared access tcp --hostname k8s.joshuatech.dev --url 127.0.0.1:6443)
#      에는 그대로 쓰고, 부트스트랩 창의 직접 접근(사설 IP, 점프/VPN 경유)에는 https://10.0.7.78:6443 으로 바꾼다(둘 다 SAN 에 있다). 내용을 비밀번호
#      관리자 항목 "k3s admin kubeconfig (node A)" 에 저장한 뒤 Remove-Item "$env:TEMP\k3s-admin.yaml". 이 kubeconfig 는 운영자 전용 —
#      에이전트·tester·CI 에는 절대 배포하지 않는다(그들은 T041 의 agent-view 토큰 kubeconfig).
#   5. 확인(운영자 kubeconfig): kubectl get nodes -L role,svccontroller.k3s.cattle.io/enablelb → 1 Ready, role=platform, enablelb=true.
#   6. 실행 기록은 docs/runbooks/bootstrap.md §3 에 컨트롤러 지시로 적는다. cloudflared access logout 은 부트스트랩 예외 경로에서 해당 없음.
#
# 절대 하지 않는 것: 토큰 생성·출력·로그, kubeconfig 출력·복사(절차 4 는 운영자의 손), IMDS 조회, "curl 파이프 sh", 버전 변경(다른 버전이 있으면 중단),
#   k3s 재시작(config 가 바뀌어도 실행 중인 k3s 는 건드리지 않고 경고만), host-prep 결과의 재구성(iptables·모듈·시간대·패키지는 검증만),
#   kubectl 로 리소스 생성·삭제·변경.
set -euo pipefail

# ---------- 상수 ----------
K3S_TOKEN_FILE="${K3S_TOKEN_FILE:-/etc/rancher/k3s/token}"
NODE_PRIVATE_IP="${NODE_PRIVATE_IP:-10.0.7.78}"
K3S_VERSION="${K3S_VERSION:-v1.36.4+k3s1}"
TLS_SAN_HOST="${TLS_SAN_HOST:-k8s.joshuatech.dev}"
INSTALL_SCRIPT="${INSTALL_SCRIPT:-/tmp/install-k3s.sh}"
K3S_CONFIG_DIR=/etc/rancher/k3s
K3S_CONFIG="$K3S_CONFIG_DIR/config.yaml"
K3S_UNIT=/etc/systemd/system/k3s.service
RULES_V4=/etc/iptables/rules.v4
WG_MODULES_CONF=/etc/modules-load.d/wireguard.conf
TZ_WANT=Asia/Seoul
READY_TIMEOUT=180   # 초. 노드 Ready 대기 상한(5 s 간격)

CHANGES=()
CONFIG_CHANGED=0
INSTALLED_THIS_RUN=0
READY_NODES=0
LABELED_NODES=0
SE_STATUS=""

log()  { printf '[k3s-server] %s\n' "$*"; }
warn() { printf '[k3s-server] WARN: %s\n' "$*" >&2; }
die()  { printf '[k3s-server] ERROR: %s\n' "$*" >&2; exit 1; }
mark_changed() { CHANGES+=("$*"); log "CHANGED: $*"; }

# ---------- 공통 헬퍼(멱등) ----------
# $1 경로, $2 내용(끝 개행은 여기서 보장), [$3 mode]. 내용이 같으면 손대지 않는다(권한만 어긋나면 권한만 고친다).
# 같은 디렉터리 mktemp(0600 으로 생성) + mv(rename) — K3s 가 반쪽 파일을 읽을 수 없다.
write_if_changed() {
  local path=$1 content=$2 mode=${3:-644} dir tmp cur
  dir=$(dirname "$path")
  install -d -m 755 -o root -g root "$dir"
  tmp=$(mktemp -p "$dir" ".$(basename "$path").XXXXXX")
  printf '%s\n' "$content" > "$tmp"
  if [ -f "$path" ] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"
    cur=$(stat -c %a "$path")
    if [ "$cur" != "$mode" ]; then chmod "$mode" "$path"; chown root:root "$path"; mark_changed "mode $cur -> $mode: $path"; fi
    log "unchanged: $path"
    return 0
  fi
  chmod "$mode" "$tmp"
  chown root:root "$tmp"
  mv -f "$tmp" "$path"
  mark_changed "wrote $path"
}

# 설치된 k3s 버전(k3s --version 첫 줄 "k3s version vX.Y.Z+k3sN (hash)"). 바이너리가 없으면 빈 문자열.
installed_k3s_version() {
  command -v k3s >/dev/null 2>&1 || return 0
  k3s --version 2>/dev/null | awk 'NR == 1 && $1 == "k3s" && $2 == "version" { print $3 }'
}

# ---------- 0. 사전 확인 ----------
preflight() {
  local addrs
  [ "$(id -u)" -eq 0 ] || die "root 로 실행해야 한다(sudo)"
  # shellcheck disable=SC1091
  . /etc/os-release
  { [ "${ID:-}" = ubuntu ] && [ "${VERSION_ID:-}" = 24.04 ]; } || die "Ubuntu 24.04 전용이다 (감지: ${ID:-?} ${VERSION_ID:-?})"
  [ "$(uname -m)" = aarch64 ] || die "arm64(aarch64) 전용이다 (감지: $(uname -m))"
  [[ "$NODE_PRIVATE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "NODE_PRIVATE_IP 형식 불량: '$NODE_PRIVATE_IP'"
  [[ "$TLS_SAN_HOST" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] || die "TLS_SAN_HOST 형식 불량: '$TLS_SAN_HOST'"
  [[ "$K3S_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]] || die "K3S_VERSION 형식 불량: '$K3S_VERSION' (예: v1.36.4+k3s1)"
  case "$K3S_TOKEN_FILE" in /*) ;; *) die "K3S_TOKEN_FILE 은 절대 경로여야 한다: '$K3S_TOKEN_FILE'" ;; esac
  case "$INSTALL_SCRIPT" in /*) ;; *) die "INSTALL_SCRIPT 는 절대 경로여야 한다: '$INSTALL_SCRIPT'" ;; esac
  # 노드 A 전용 가드: IMDS 대신 로컬 인터페이스에서 확인한다(변수로 받아 herestring 으로 검사 — pipefail 하 grep -q 조기 종료 SIGPIPE 회피)
  addrs=$(ip -4 -o addr show scope global | awk '{ split($4, a, "/"); print a[1] }')
  grep -qxF -- "$NODE_PRIVATE_IP" <<< "$addrs" || die "NODE_PRIVATE_IP $NODE_PRIVATE_IP 가 이 호스트의 인터페이스에 없다(있는 IP: $(tr '\n' ' ' <<< "$addrs")) — 노드 A 전용 스크립트다"
  log "preflight OK: $(hostname) ubuntu=$VERSION_ID arch=$(uname -m) kernel=$(uname -r) ip=$NODE_PRIVATE_IP k3s=$K3S_VERSION san=$TLS_SAN_HOST"
}

# ---------- 1. host-prep 결과 검증(재구성하지 않는다) ----------
check_host_prep() {
  local fs p
  fs=$(stat -fc %T /sys/fs/cgroup)
  [ "$fs" = cgroup2fs ] || die "cgroup v2 가 아니다 (/sys/fs/cgroup = $fs) — host-prep.sh 먼저"
  [ -d /sys/module/wireguard ] || die "wireguard 모듈이 로드돼 있지 않다(/sys/module/wireguard 없음; flannel wireguard-native 요구) — host-prep.sh 먼저"
  grep -qxF wireguard "$WG_MODULES_CONF" 2>/dev/null || die "$WG_MODULES_CONF 에 wireguard 가 등재돼 있지 않다 — host-prep.sh 먼저"
  [ -f "$RULES_V4" ] || die "$RULES_V4 가 없다 — host-prep.sh 먼저"
  for p in '-p tcp -m tcp --dport 6443 -j ACCEPT' '-p udp -m udp --dport 51820 -j ACCEPT' '-p tcp -m tcp --dport 10250 -j ACCEPT'; do
    grep -qE "^-A INPUT -s [0-9./]+ $p\$" "$RULES_V4" || die "$RULES_V4 에 INPUT 규칙($p)이 없다 — host-prep.sh 먼저"
  done
  [ "$(timedatectl show -p Timezone --value)" = "$TZ_WANT" ] || die "시간대가 $TZ_WANT 가 아니다 — host-prep.sh 먼저"
  if command -v ufw >/dev/null 2>&1 && [ "$(ufw status 2>/dev/null | head -n 1)" = "Status: active" ]; then
    die "ufw 가 활성이다 — host-prep.sh 먼저(Oracle: OCI Ubuntu 에서 ufw 편집 금지 — 수동으로 비활성화한다)"
  fi
  command -v curl >/dev/null 2>&1 || die "curl 이 없다(설치 스크립트가 k3s 바이너리를 내려받는 데 필요) — host-prep.sh 먼저"
  log "host-prep state OK: cgroup2fs, wireguard, rules.v4(6443/tcp 51820/udp 10250/tcp), $TZ_WANT, ufw inactive"
}

# ---------- 2. 토큰 파일 검증(내용은 읽어 들이지도 출력하지도 않는다) ----------
check_token_file() {
  local f=$K3S_TOKEN_FILE mode owner
  [ -f "$f" ] || die "토큰 파일 $f 가 없다 — 운영자 절차 1(워크스테이션에서 생성 → 비밀번호 관리자 → install -m 600)"
  mode=$(stat -c %a "$f")
  owner=$(stat -c %U:%G "$f")
  [ "$mode" = 600 ] || die "토큰 파일 $f 의 권한이 $mode 다(600 필요): chmod 600 $f"
  [ "$owner" = root:root ] || die "토큰 파일 $f 의 소유가 $owner 다(root:root 필요): chown root:root $f"
  [ -s "$f" ] || die "토큰 파일 $f 가 비어 있다"
  [ "$(grep -c '' "$f")" -eq 1 ] || die "토큰 파일 $f 는 한 줄이어야 한다"
  grep -qE '^[^[:space:]]{32,}[[:space:]]*$' "$f" || die "토큰 파일 $f 형식 불량 — 공백 없는 32자 이상 한 줄이어야 한다(절차 1 의 64 hex 권장)"
  ! grep -q '^K10' "$f" || die "토큰 파일 $f 가 보안 형식(K10…)이다 — 첫 서버는 짧은 형식(비밀번호만)이어야 한다(K3S-D5)"
  log "token file OK: $f (root:root $mode, 1 line; contents never printed)"
}

# ---------- 3. config.yaml ----------
# 모든 서버 플래그는 이 파일 한 곳(K3S-D1). 항목은 tasks T035 문면 + research K3S-D2·D3·D4·D5 결정에 있는 것만:
#   외부 IP 지정 없음(K3S-D3: OCI 공인 IP 는 NAT — ServiceLB externalTrafficPolicy=Local 오동작 경고), 번들 컴포넌트 끄기 없음(K3S-D3),
#   cluster-cidr/service-cidr 미지정 = K3s 기본 10.42.0.0/16·10.43.0.0/16(host-prep.sh 의 iptables 규칙과 같은 값).
render_config() {
  local content
  content=$(cat <<EOF
# $K3S_CONFIG — managed by infra/bootstrap/k3s-server.sh (T035). Edit the script, not this file.
# All K3s server flags live here (K3S-D1); the installer receives only INSTALL_K3S_VERSION + INSTALL_K3S_EXEC=server.
write-kubeconfig-mode: "0600"
token-file: $K3S_TOKEN_FILE
tls-san:
  - "$NODE_PRIVATE_IP"
  - "$TLS_SAN_HOST"
node-label:
  - "role=platform"
  - "svccontroller.k3s.cattle.io/enablelb=true"
secrets-encryption: true
secrets-encryption-provider: secretbox
flannel-backend: wireguard-native
EOF
)
  local before=${#CHANGES[@]}
  write_if_changed "$K3S_CONFIG" "$content" 600
  [ "${#CHANGES[@]}" -eq "$before" ] || CONFIG_CHANGED=1
}

# ---------- 4. 설치 ----------
check_install_script() {
  local f=$INSTALL_SCRIPT have want
  [ -f "$f" ] || die "설치 스크립트 사본 $f 가 없다 — 운영자 절차 2(get.k3s.io 를 워크스테이션에서 내려받아 검토·해시 기록 후 scp)"
  [ "$(head -n 1 "$f")" = '#!/bin/sh' ] || die "$f 의 첫 줄이 #!/bin/sh 가 아니다 — get.k3s.io 사본이 맞는지 확인"
  { grep -q 'INSTALL_K3S_VERSION' "$f" && grep -q 'verify_binary' "$f"; } || die "$f 에 INSTALL_K3S_VERSION/verify_binary 가 없다 — 공식 설치 스크립트가 아니다"
  have=$(sha256sum "$f" | awk '{ print $1 }')
  if [ -n "${INSTALL_SCRIPT_SHA256:-}" ]; then
    want=${INSTALL_SCRIPT_SHA256,,}
    [ "$have" = "$want" ] || die "설치 스크립트 sha256 불일치: got $have want $want — 워크스테이션에서 검토한 사본과 다르다"
    log "install script OK: $f sha256=$have (matches INSTALL_SCRIPT_SHA256)"
  else
    log "install script present: $f sha256=$have (INSTALL_SCRIPT_SHA256 미지정 — 운영자 검토 사본으로 간주)"
  fi
}

install_k3s() {
  local have
  have=$(installed_k3s_version)
  if [ -n "$have" ] && [ "$have" != "$K3S_VERSION" ]; then
    die "설치된 k3s $have ≠ 요구 $K3S_VERSION — 이 스크립트는 버전을 바꾸지 않는다(패치 승격은 system-upgrade-controller Plan 몫, 다운그레이드 불가)"
  fi
  if [ "$have" = "$K3S_VERSION" ] && [ -f "$K3S_UNIT" ]; then
    log "k3s $have already installed ($K3S_UNIT present) — installer skipped"
    return 0
  fi
  check_install_script
  # env -i: install.sh 는 K3S_* 를 k3s.service.env 에 기록하므로 이 셸의 K3S_TOKEN_FILE/K3S_VERSION 을 넘기지 않는다. 플래그는 config.yaml 에만(K3S-D1).
  # INSTALL_K3S_EXEC=server 뿐 — CLI 인자 없음. 바이너리 sha256 은 install.sh 의 verify_binary 가 릴리스 자산과 대조한다.
  log "installing k3s $K3S_VERSION (server) from $INSTALL_SCRIPT"
  env -i PATH="$PATH" HOME=/root INSTALL_K3S_VERSION="$K3S_VERSION" INSTALL_K3S_EXEC=server sh "$INSTALL_SCRIPT"
  have=$(installed_k3s_version)
  [ "$have" = "$K3S_VERSION" ] || die "설치 뒤 버전 불일치: got '$have' want '$K3S_VERSION'"
  [ -f "$K3S_UNIT" ] || die "설치 뒤에도 $K3S_UNIT 이 없다"
  INSTALLED_THIS_RUN=1
  mark_changed "k3s $K3S_VERSION installed (server)"
}

# ---------- 5. 서비스 상태 ----------
ensure_service() {
  local enabled active
  enabled=$(systemctl is-enabled k3s 2>/dev/null || true)
  active=$(systemctl is-active k3s 2>/dev/null || true)
  if [ "$enabled" != enabled ] || [ "$active" != active ]; then
    systemctl enable --now k3s >/dev/null
    mark_changed "systemd: k3s enable --now (was enabled=$enabled active=$active)"
  else
    log "systemd: k3s already enabled+active"
  fi
  systemctl is-active --quiet k3s || die "k3s.service 가 active 가 아니다 — journalctl -u k3s -n 100"
  if [ "$CONFIG_CHANGED" = 1 ] && [ "$INSTALLED_THIS_RUN" != 1 ]; then
    warn "$K3S_CONFIG 가 바뀌었지만 실행 중인 k3s 는 건드리지 않는다 — 반영(k3s.service 재시작)은 운영자 판단(node-label 은 등록 시 1회만 적용, secrets-encryption 변경은 rotate 절차)"
  fi
}

# ---------- 6. 노드 Ready 대기 ----------
wait_node_ready() {
  local i out ready=0
  for ((i = 0; i < READY_TIMEOUT / 5; i++)); do
    out=$(k3s kubectl get nodes --no-headers 2>/dev/null || true)
    if awk '$2 == "Ready" { f = 1 } END { exit !f }' <<< "$out"; then ready=1; break; fi
    sleep 5
  done
  [ "$ready" = 1 ] || die "노드가 ${READY_TIMEOUT}s 안에 Ready 가 아니다 — journalctl -u k3s -n 100 / k3s kubectl get nodes"
  READY_NODES=$(awk '$2 == "Ready"' <<< "$out" | grep -c . || true)
  log "node Ready: $READY_NODES (waited ~$((i * 5))s)"
}

# 라벨은 kubelet 등록 시 1회만 적용된다(research: node-label 주의). 첫 기동 전에 config.yaml 이 확정돼 있어야 하고, 어긋나면 수동 복구 뒤 재실행.
check_labels() {
  LABELED_NODES=$(k3s kubectl get nodes -l 'role=platform,svccontroller.k3s.cattle.io/enablelb=true' --no-headers 2>/dev/null | grep -c . || true)
  [ "${LABELED_NODES:-0}" -ge 1 ] || die "role=platform + svccontroller.k3s.cattle.io/enablelb=true 라벨을 가진 노드가 없다 — node-label 은 등록 시 1회만 적용된다(수동 복구: kubectl label node <A> role=platform svccontroller.k3s.cattle.io/enablelb=true 뒤 재실행)"
  log "labels OK: role=platform + enablelb on $LABELED_NODES node(s)"
}

check_secrets_encryption() {
  local i st=""
  for i in 1 2 3; do
    st=$(k3s secrets-encrypt status 2>/dev/null || true)
    if grep -q '^Encryption Status: Enabled' <<< "$st"; then break; fi
    sleep 5
  done
  grep -q '^Encryption Status: Enabled' <<< "$st" || die "secrets-encryption 이 Enabled 가 아니다(k3s secrets-encrypt status) — config.yaml 의 secrets-encryption: true 가 첫 기동에 적용됐는지 확인"
  grep -qi 'secretbox' <<< "$st" || warn "secrets-encrypt status 에 secretbox 가 보이지 않는다 — provider 확인(K3S-D2)"
  SE_STATUS=$(grep -E '^(Encryption Status|Current Rotation Stage|Server Encryption Hashes):' <<< "$st" | tr '\n' ';' || true)
  log "secrets-encrypt: $SE_STATUS"
}

# ---------- summary ----------
summary() {
  local rule
  printf '\n==== k3s-server summary: %s %s ====\n' "$(hostname)" "$(date -Is)"
  printf 'changes this run: %d\n' "${#CHANGES[@]}"
  for rule in "${CHANGES[@]:-}"; do [ -n "$rule" ] && printf '  - %s\n' "$rule"; done
  printf 'k3s: installed=%s want=%s  service: enabled=%s active=%s\n' "$(installed_k3s_version)" "$K3S_VERSION" "$(systemctl is-enabled k3s 2>/dev/null || true)" "$(systemctl is-active k3s 2>/dev/null || true)"
  printf 'config: %s changed=%s mode=%s\n' "$K3S_CONFIG" "$([ "$CONFIG_CHANGED" = 1 ] && printf yes || printf no)" "$(stat -c %a "$K3S_CONFIG")"
  printf 'node: Ready=%s  labels(role=platform,enablelb)=%s  tls-san=%s,%s\n' "$READY_NODES" "$LABELED_NODES" "$NODE_PRIVATE_IP" "$TLS_SAN_HOST"
  printf 'secrets-encrypt: %s\n' "$SE_STATUS"
  printf 'flannel-wg iface: %s  token-file: %s (mode %s, contents never printed)\n' "$(ip link show flannel-wg >/dev/null 2>&1 && printf present || printf absent)" "$K3S_TOKEN_FILE" "$(stat -c %a "$K3S_TOKEN_FILE")"
  printf '==== end ====\n'
}

main() {
  preflight
  check_host_prep
  check_token_file
  render_config
  install_k3s
  ensure_service
  wait_node_ready
  check_labels
  check_secrets_encryption
  summary
}

# stdin 을 /dev/null 로: `bash -s < k3s-server.sh` 스트리밍에서도 자식 명령(설치 스크립트 포함)이 스크립트 본문을 소비하지 않는다. 뒤의 exit 는
# 그 뒤에 어떤 입력(예: PowerShell 파이프가 붙이는 CRLF)이 와도 읽지 않게 한다 — main 의 종료 상태를 그대로 반환한다.
main "$@" </dev/null; exit
