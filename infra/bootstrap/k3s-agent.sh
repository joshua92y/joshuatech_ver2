#!/usr/bin/env bash
# infra/bootstrap/k3s-agent.sh — 노드 B(joshtech-cache, role=data) K3s agent 설치 + /etc/rancher/k3s/config.yaml 렌더(멱등) — 003-platform-foundation T036
#
# 대상: T014 host-prep.sh 를 마친 노드 B(OCI VM.Standard.A1.Flex, Ubuntu 24.04 arm64, 사설 IP 10.0.10.193, reserved 공개 IP 129.154.62.250).
# 노드 A(server, 사설 IP 10.0.7.78)는 T035 k3s-server.sh 로 먼저 Ready 여야 한다. 노드 A 에서 실행하면 중단한다(로컬 IP 가드 + server 데이터 디렉터리 가드).
# root 로 실행한다(sudo). 재실행해도 같은 최종 상태이고 중복·오류가 없어야 한다(.claude/rules/infra.md "Bootstrap and operations scripts") —
# 모든 변경 단계는 "존재 검사 → 없을 때만 변경" 형태이며, 2회차 summary 의 "changes this run: 0" 이 멱등의 증명이다.
# 정적 계약은 tests/infra/k3s-agent.tests.ps1 이 고정한다.
#
# 하는 일(순서): 전제 검증(host-prep 결과를 검증만 한다 — iptables·모듈·시간대를 재구성하지 않는다) → 서버 도달 확인(K3S_URL TLS 핸드셰이크)
#   → 토큰 파일 검증(보안 형식 K10<CA sha256>::server:<pw>, 내용 미출력) → config.yaml 렌더(0600, 내용이 같으면 손대지 않음)
#   → K3s 설치(운영자가 미리 내려받아 검토한 공식 설치 스크립트 사본을 버전 고정으로 실행; 같은 버전이 이미 있으면 skip, 다른 버전이면 중단)
#   → k3s-agent.service enabled/active 확인 → 등록 로그 대기(최대 90 s; 이 노드에는 kubectl 이 없다 — Ready 판정은 운영자 절차 4) → summary.
#   클러스터 상태를 바꾸는 명령은 설치와 기동(systemctl enable --now)뿐이다.
#
# 입력(환경 변수; sudo VAR=값 형식 — sudoers 의 command ALL 매치가 명령행 환경 변수 지정을 허용한다):
#   K3S_TOKEN_FILE        선택. 기본 /etc/rancher/k3s/token. 운영자가 미리 둔 노드 A 의 /var/lib/rancher/k3s/server/token 값(보안 형식
#                         K10<CA sha256 hex 64>::server:<pw>) — root:root 0600, 한 줄, 공백 없음. 부재·권한 불량·빈 파일·짧은 형식(비밀번호만)이면 중단.
#                         보안 형식은 조인 전에 클러스터 CA 해시를 검증해 MITM 을 막는다(K3S-D5). 이 스크립트는 토큰을 읽어 출력하지도, 로그에 남기지도 않는다.
#   K3S_URL               선택. 기본 https://10.0.7.78:6443(노드 A 사설 IP, T014 실측 — config.yaml 의 server: 로 들어간다; 환경 변수로는 넘기지 않는다).
#   NODE_PRIVATE_IP       선택. 기본 10.0.10.193(노드 B VNIC 사설 IP, T014 실측). IMDS 를 조회하지 않는다(IMDS v1 off — 정적 값). 이 IP 가 로컬
#                         인터페이스에 없으면 중단한다(노드 A 에서 실수로 실행하는 것을 막는다).
#   K3S_VERSION           선택. 기본 v1.36.4+k3s1(research R1 버전 표, 고정 — 서버와 같은 버전). 패치 승격은 system-upgrade-controller agent Plan 몫.
#   INSTALL_SCRIPT        선택. 기본 /tmp/install-k3s.sh — 운영자가 T035 절차 2 에서 내려받아 검토한 get.k3s.io 사본(같은 파일). 설치가 필요할 때만 요구된다.
#   INSTALL_SCRIPT_SHA256 선택. 지정하면 사본의 sha256 이 이 값과 다를 때 중단한다(T035 에서 기록한 해시와 같아야 한다).
#
# install.sh 조합(2026-09-04 get.k3s.io 원문 확인, 사본 sha256 e5cc3b3d9dfc1662c2d9be6da5abc9a4cd317d6abc3a5ffc02e3dd3248207fee):
#   setup_env 은 첫 인자가 명령이면 CMD_K3S=$1 로 잡는다 — INSTALL_K3S_EXEC=agent 만으로 CMD_K3S=agent, SYSTEM_NAME=k3s-agent 가 되고 K3S_URL 은
#   요구되지 않는다(K3S_URL 은 "명령 없이 플래그만" 줄 때 agent 기본값을 정하고 K3S_TOKEN/K3S_TOKEN_FILE 을 강제하는 용도일 뿐). create_env_file 은 환경의
#   K3S_* 를 전부 /etc/systemd/system/k3s-agent.service.env 에 기록하므로 env -i 로 상속을 끊고 server:/token-file 은 config.yaml 에만 둔다
#   (K3S-D1; K3S_TOKEN 환경 변수는 env 파일에 평문으로 잔존한다 — K3S-D5 대안 기각 사유). 바이너리 sha256 은 install.sh 의 verify_binary 가 릴리스 자산과 대조한다.
#
# 운영자 절차(워크스테이션 PowerShell 7; 키 joshuatech-ops 는 ssh-add -c 로 로드; ssh/scp 공통 옵션 -i ~/.ssh/joshuatech-ops -o IdentitiesOnly=yes 는
#   아래에서 "…" 로 줄인다; 노드 A 144.24.85.118, 노드 B 129.154.62.250):
#   0. 임시 22/tcp 규칙은 T035 절차 0 의 nsg-cluster 규칙이 그대로 유효하다(두 노드가 같은 NSG — 노드 B 의 22 도 열려 있다). 새로 만들지 않는다.
#   1. 조인 토큰 — 노드 A 의 server/token 을 화면에 찍지 않고 파일로만 옮긴다(sudo cat 금지):
#        ssh … ubuntu@144.24.85.118 "sudo install -m 600 -o ubuntu -g ubuntu /var/lib/rancher/k3s/server/token /home/ubuntu/k3s-join-token"
#        scp … ubuntu@144.24.85.118:/home/ubuntu/k3s-join-token "$env:TEMP\k3s-join-token"
#        ssh … ubuntu@144.24.85.118 "shred -u /home/ubuntu/k3s-join-token"
#        scp … "$env:TEMP\k3s-join-token" ubuntu@129.154.62.250:/home/ubuntu/k3s-join-token
#        ssh … ubuntu@129.154.62.250 "sudo install -d -m 755 -o root -g root /etc/rancher/k3s && sudo install -m 600 -o root -g root /home/ubuntu/k3s-join-token /etc/rancher/k3s/token && shred -u /home/ubuntu/k3s-join-token"
#        Remove-Item "$env:TEMP\k3s-join-token"     # 워크스테이션 사본 삭제(비밀번호 관리자에 저장하지 않는다 — 원본은 노드 A 가 계속 보유하고 백업 번들에도 들어간다)
#   2. 설치 스크립트 사본 — T035 절차 2 의 같은 파일(해시 동일)을 노드 B 에 올린다(남아 있지 않으면 T035 절차 2 를 반복하고 해시가 같은지 확인):
#        scp … "$env:TEMP\install-k3s.sh" ubuntu@129.154.62.250:/tmp/install-k3s.sh
#   3. 이 스크립트 실행(두 번 — 2회차는 changes this run: 0 이어야 한다):
#        scp … infra/bootstrap/k3s-agent.sh ubuntu@129.154.62.250:/tmp/k3s-agent.sh
#        ssh … ubuntu@129.154.62.250 "sudo INSTALL_SCRIPT_SHA256=<T035 절차 2 의 해시> bash /tmp/k3s-agent.sh"
#        (같은 명령 한 번 더) → summary: changes this run: 0, service enabled+active, registration=confirmed
#      ⚠ 멈춘 것처럼 보이면(무한 대기): 토큰이나 CA 해시가 어긋나면 k3s agent 는 **실패하지 않고 영원히 재시도**하고 unit 은 TimeoutStartSec=0 이라
#        install.sh 의 서비스 기동과 systemctl enable --now 가 그대로 블록된다. 다른 터미널에서
#          ssh … ubuntu@129.154.62.250 "sudo journalctl -u k3s-agent -f"
#        로 'Waiting to retrieve agent configuration; server is not ready' 가 반복되는지 확인한다(= 토큰/CA/도달성 문제). 이 스크립트는 실행 전에
#        토큰 형식과 서버 CA 해시를 대조해 경고하지만(check_ca_hash), 대조는 진단이지 차단이 아니다 — 중단은 Ctrl-C 후 토큰을 다시 배치한다.
#   4. 확인(운영자 admin kubeconfig, T035 절차 4): kubectl get nodes -L role → 2 Ready(joshtech-api role=platform, joshtech-cache role=data);
#        kubectl get nodes -o wide 로 INTERNAL-IP 가 10.0.7.78 / 10.0.10.193 인지 확인.
#   5. 실행 기록은 docs/runbooks/bootstrap.md §3 에 컨트롤러 지시로 적는다. 임시 22/tcp 규칙 제거는 T039 몫.
#
# 절대 하지 않는 것: 토큰 생성·출력·로그, kubeconfig 취급(이 노드에는 없다), IMDS 조회, "curl 파이프 sh", 버전 변경(다른 버전이 있으면 중단),
#   k3s-agent 재시작(config 가 바뀌어도 실행 중인 agent 는 건드리지 않고 경고만), host-prep 결과의 재구성(iptables·모듈·시간대·패키지는 검증만),
#   K3S_URL/K3S_TOKEN 을 환경 변수로 설치 스크립트에 넘기기(service.env 평문 잔존).
set -euo pipefail

# ---------- 상수 ----------
K3S_TOKEN_FILE="${K3S_TOKEN_FILE:-/etc/rancher/k3s/token}"
K3S_URL="${K3S_URL:-https://10.0.7.78:6443}"
NODE_PRIVATE_IP="${NODE_PRIVATE_IP:-10.0.10.193}"
K3S_VERSION="${K3S_VERSION:-v1.36.4+k3s1}"
INSTALL_SCRIPT="${INSTALL_SCRIPT:-/tmp/install-k3s.sh}"
K3S_CONFIG_DIR=/etc/rancher/k3s
K3S_CONFIG="$K3S_CONFIG_DIR/config.yaml"
K3S_UNIT=/etc/systemd/system/k3s-agent.service
K3S_SERVER_DIR=/var/lib/rancher/k3s/server
RULES_V4=/etc/iptables/rules.v4
WG_MODULES_CONF=/etc/modules-load.d/wireguard.conf
TZ_WANT=Asia/Seoul
REGISTER_TIMEOUT=90   # 초. 등록 로그 대기 상한(5 s 간격)

CHANGES=()
CONFIG_CHANGED=0
INSTALLED_THIS_RUN=0
REGISTERED=unconfirmed
RUN_STARTED_AT=$(date +%s)   # 등록 로그를 이번 실행분으로만 한정하는 기준 시각(낡은 성공 로그로 confirmed 되는 것을 막는다)

log()  { printf '[k3s-agent] %s\n' "$*"; }
warn() { printf '[k3s-agent] WARN: %s\n' "$*" >&2; }
die()  { printf '[k3s-agent] ERROR: %s\n' "$*" >&2; exit 1; }
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
  local addrs server_host
  [ "$(id -u)" -eq 0 ] || die "root 로 실행해야 한다(sudo)"
  # shellcheck disable=SC1091
  . /etc/os-release
  { [ "${ID:-}" = ubuntu ] && [ "${VERSION_ID:-}" = 24.04 ]; } || die "Ubuntu 24.04 전용이다 (감지: ${ID:-?} ${VERSION_ID:-?})"
  [ "$(uname -m)" = aarch64 ] || die "arm64(aarch64) 전용이다 (감지: $(uname -m))"
  [[ "$NODE_PRIVATE_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || die "NODE_PRIVATE_IP 형식 불량: '$NODE_PRIVATE_IP'"
  [[ "$K3S_URL" =~ ^https://[A-Za-z0-9.-]+:[0-9]{2,5}$ ]] || die "K3S_URL 형식 불량: '$K3S_URL' (예: https://10.0.7.78:6443 — https 만, 경로 없음)"
  [[ "$K3S_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+\+k3s[0-9]+$ ]] || die "K3S_VERSION 형식 불량: '$K3S_VERSION' (예: v1.36.4+k3s1)"
  case "$K3S_TOKEN_FILE" in /*) ;; *) die "K3S_TOKEN_FILE 은 절대 경로여야 한다: '$K3S_TOKEN_FILE'" ;; esac
  case "$INSTALL_SCRIPT" in /*) ;; *) die "INSTALL_SCRIPT 는 절대 경로여야 한다: '$INSTALL_SCRIPT'" ;; esac
  # 노드 B 전용 가드 1: IMDS 대신 로컬 인터페이스에서 확인한다(변수로 받아 herestring 으로 검사 — pipefail 하 grep -q 조기 종료 SIGPIPE 회피)
  addrs=$(ip -4 -o addr show scope global | awk '{ split($4, a, "/"); print a[1] }')
  grep -qxF -- "$NODE_PRIVATE_IP" <<< "$addrs" || die "NODE_PRIVATE_IP $NODE_PRIVATE_IP 가 이 호스트의 인터페이스에 없다(있는 IP: $(tr '\n' ' ' <<< "$addrs")) — 노드 B 전용 스크립트다"
  # 노드 B 전용 가드 2: server 데이터 디렉터리가 있으면 여기는 노드 A(server)다
  [ ! -d "$K3S_SERVER_DIR" ] || die "$K3S_SERVER_DIR 가 있다 — 이 호스트는 K3s server(노드 A)다. 노드 B 전용 스크립트다"
  # 노드 B 전용 가드 3: K3S_URL 이 자기 자신을 가리키면 조인이 아니다
  server_host=${K3S_URL#https://}; server_host=${server_host%:*}
  [ "$server_host" != "$NODE_PRIVATE_IP" ] || die "K3S_URL($K3S_URL)이 NODE_PRIVATE_IP 자신을 가리킨다 — server 는 노드 A(10.0.7.78)여야 한다"
  log "preflight OK: $(hostname) ubuntu=$VERSION_ID arch=$(uname -m) kernel=$(uname -r) ip=$NODE_PRIVATE_IP k3s=$K3S_VERSION server=$K3S_URL"
}

# ---------- 1. host-prep 결과 검증(재구성하지 않는다) ----------
# 노드 B 에는 6443/tcp INPUT 도 있지만(host-prep 공용) agent 에 필요한 것은 flannel wireguard 51820/udp 와 kubelet 10250/tcp 뿐이라 그 둘만 검증한다.
check_host_prep() {
  local fs p
  fs=$(stat -fc %T /sys/fs/cgroup)
  [ "$fs" = cgroup2fs ] || die "cgroup v2 가 아니다 (/sys/fs/cgroup = $fs) — host-prep.sh 먼저"
  [ -d /sys/module/wireguard ] || die "wireguard 모듈이 로드돼 있지 않다(/sys/module/wireguard 없음; flannel wireguard-native 요구) — host-prep.sh 먼저"
  grep -qxF wireguard "$WG_MODULES_CONF" 2>/dev/null || die "$WG_MODULES_CONF 에 wireguard 가 등재돼 있지 않다 — host-prep.sh 먼저"
  [ -f "$RULES_V4" ] || die "$RULES_V4 가 없다 — host-prep.sh 먼저"
  for p in '-p udp -m udp --dport 51820 -j ACCEPT' '-p tcp -m tcp --dport 10250 -j ACCEPT'; do
    grep -qE "^-A INPUT -s [0-9./]+ $p\$" "$RULES_V4" || die "$RULES_V4 에 INPUT 규칙($p)이 없다 — host-prep.sh 먼저"
  done
  [ "$(timedatectl show -p Timezone --value)" = "$TZ_WANT" ] || die "시간대가 $TZ_WANT 가 아니다 — host-prep.sh 먼저"
  if command -v ufw >/dev/null 2>&1 && [ "$(ufw status 2>/dev/null | head -n 1)" = "Status: active" ]; then
    die "ufw 가 활성이다 — host-prep.sh 먼저(Oracle: OCI Ubuntu 에서 ufw 편집 금지 — 수동으로 비활성화한다)"
  fi
  command -v curl >/dev/null 2>&1 || die "curl 이 없다(설치 스크립트가 k3s 바이너리를 내려받는 데 필요) — host-prep.sh 먼저"
  log "host-prep state OK: cgroup2fs, wireguard, rules.v4(51820/udp 10250/tcp), $TZ_WANT, ufw inactive"
}

# ---------- 2. 서버 도달 확인 ----------
# K3s supervisor(6443)의 /ping 은 인증 없이 "pong" 을 돌려준다. -k: 노드 B 에는 아직 클러스터 CA 가 없다(조인 때 토큰의 CA 해시로 검증한다 — K3S-D5).
# 여기서는 TCP+TLS 핸드셰이크가 되는지만 본다(NSG nsg-cluster 자기참조 + 노드 A rules.v4 6443 INPUT 이 열려 있다는 증거).
check_server_reachable() {
  local resp
  resp=$(curl -sk --max-time 5 "$K3S_URL/ping" 2>/dev/null) || die "K3S_URL $K3S_URL 에 닿지 않는다(curl 실패) — 노드 A 의 k3s.service 가 active 인지, nsg-cluster 와 노드 A rules.v4 6443/tcp 를 확인"
  [ "$resp" = pong ] || warn "$K3S_URL/ping 응답이 'pong' 이 아니다('$resp') — 도달은 되지만 supervisor 응답이 예상과 다르다"
  log "server reachable: $K3S_URL (ping=$resp)"
}

# ---------- 3. 토큰 파일 검증(내용은 읽어 들이지도 출력하지도 않는다) ----------
check_token_file() {
  local f=$K3S_TOKEN_FILE mode owner
  [ -f "$f" ] || die "토큰 파일 $f 가 없다 — 운영자 절차 1(노드 A server/token → scp → install -m 600)"
  mode=$(stat -c %a "$f")
  owner=$(stat -c %U:%G "$f")
  [ "$mode" = 600 ] || die "토큰 파일 $f 의 권한이 $mode 다(600 필요): chmod 600 $f"
  [ "$owner" = root:root ] || die "토큰 파일 $f 의 소유가 $owner 다(root:root 필요): chown root:root $f"
  [ -s "$f" ] || die "토큰 파일 $f 가 비어 있다"
  [ "$(grep -c '' "$f")" -eq 1 ] || die "토큰 파일 $f 는 한 줄이어야 한다"
  grep -q '^K10' "$f" || die "토큰 파일 $f 가 짧은 형식(비밀번호만)이다 — agent 조인은 노드 A server/token 의 보안 형식(K10<CA sha256>::server:<pw>)이어야 한다(K3S-D5: 조인 전 CA 해시 검증)"
  grep -qE '^K10[0-9a-f]{64}::server:[^[:space:]]+[[:space:]]*$' "$f" || die "토큰 파일 $f 형식 불량 — K10<CA sha256 hex 64>::server:<pw> 한 줄이어야 한다(노드 A /var/lib/rancher/k3s/server/token 을 그대로 복사)"
  log "token file OK: $f (root:root $mode, 1 line, secure format K10…::server:…; contents never printed)"
}

# 토큰의 CA 해시 부분만 뽑는다(K10<sha256 hex 64>::server:<pw> 의 가운데 64자). 이 값은 비밀이 아니다 — 서버가 /cacerts 로 공개하는 인증서의 해시이고,
# 비밀번호(::server: 뒤)는 이 치환에서 버려진다. 뽑히지 않으면 빈 문자열.
token_ca_hash() {
  sed -n '1s/^K10\([0-9a-f]\{64\}\)::server:.*$/\1/p' "$K3S_TOKEN_FILE"
}

# 조인 전 CA 해시 대조. 어긋나면 agent 는 실패하지 않고 영원히 재시도하므로(머리 절차 3 의 경고), 설치 전에 알려 주는 것이 목적이다.
# 진단이지 차단이 아니다: 라이브 클러스터에서 실측하기 전이라 die 로 올리지 않는다(실측 뒤 승격은 T036 실행 기록에서 판단).
check_ca_hash() {
  local want have
  want=$(token_ca_hash)
  if [ -z "$want" ]; then warn "토큰에서 CA 해시를 뽑지 못했다 — 대조를 건너뛴다(형식 검증은 통과)"; return 0; fi
  have=$(curl -sk --max-time 5 "$K3S_URL/cacerts" 2>/dev/null | sha256sum 2>/dev/null | awk '{ print $1 }') || true
  if [ -z "$have" ]; then warn "$K3S_URL/cacerts 를 읽지 못해 CA 해시를 대조하지 못했다 — 조인이 무한 재시도로 멈추면 절차 3 의 journalctl 확인"; return 0; fi
  if [ "$want" = "$have" ]; then
    log "CA hash OK: 토큰의 CA 해시가 $K3S_URL/cacerts 와 일치(${want:0:12}…)"
  else
    warn "토큰의 CA 해시(${want:0:12}…)가 서버 CA(${have:0:12}…)와 다르다 — 이 토큰으로 조인하면 k3s-agent 가 'Waiting to retrieve agent configuration' 을 무한 반복한다. 노드 A 의 /var/lib/rancher/k3s/server/token 을 다시 복사할 것(절차 1)"
  fi
}

# ---------- 4. config.yaml ----------
# 모든 agent 플래그는 이 파일 한 곳(K3S-D1). 항목은 tasks T036 문면 + research 노드 B 스니펫에 있는 것만: server, token-file, node-label [role=data].
# 외부 IP 지정 없음(K3S-D3), 서버 전용 키(tls-san·secrets-encryption·flannel-backend·write-kubeconfig-mode) 없음 — agent 는 server 의 flannel 설정을 따른다.
render_config() {
  local content
  content=$(cat <<EOF
# $K3S_CONFIG — managed by infra/bootstrap/k3s-agent.sh (T036). Edit the script, not this file.
# All K3s agent flags live here (K3S-D1); the installer receives only INSTALL_K3S_VERSION + INSTALL_K3S_EXEC=agent.
server: "$K3S_URL"
token-file: $K3S_TOKEN_FILE
node-label:
  - "role=data"
EOF
)
  local before=${#CHANGES[@]}
  write_if_changed "$K3S_CONFIG" "$content" 600
  [ "${#CHANGES[@]}" -eq "$before" ] || CONFIG_CHANGED=1
}

# ---------- 5. 설치 ----------
check_install_script() {
  local f=$INSTALL_SCRIPT have want
  [ -f "$f" ] || die "설치 스크립트 사본 $f 가 없다 — 운영자 절차 2(T035 절차 2 의 get.k3s.io 사본을 scp)"
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
    die "설치된 k3s $have ≠ 요구 $K3S_VERSION — 이 스크립트는 버전을 바꾸지 않는다(패치 승격은 system-upgrade-controller agent Plan 몫, 다운그레이드 불가)"
  fi
  if [ "$have" = "$K3S_VERSION" ] && [ -f "$K3S_UNIT" ]; then
    log "k3s $have already installed ($K3S_UNIT present) — installer skipped"
    return 0
  fi
  check_install_script
  # env -i: install.sh 는 K3S_* 를 k3s-agent.service.env 에 기록하므로 이 셸의 K3S_URL/K3S_TOKEN_FILE/K3S_VERSION 을 넘기지 않는다. 플래그는 config.yaml 에만(K3S-D1).
  # INSTALL_K3S_EXEC=agent 뿐 — CLI 인자 없음, K3S_URL 없음(머리 주석 "install.sh 조합"). 바이너리 sha256 은 install.sh 의 verify_binary 가 릴리스 자산과 대조한다.
  log "installing k3s $K3S_VERSION (agent) from $INSTALL_SCRIPT"
  env -i PATH="$PATH" HOME=/root INSTALL_K3S_VERSION="$K3S_VERSION" INSTALL_K3S_EXEC=agent sh "$INSTALL_SCRIPT" || die "install.sh 실패(exit $?) — 위 [ERROR] 참조"
  have=$(installed_k3s_version)
  [ "$have" = "$K3S_VERSION" ] || die "설치 뒤 버전 불일치: got '$have' want '$K3S_VERSION'"
  [ -f "$K3S_UNIT" ] || die "설치 뒤에도 $K3S_UNIT 이 없다(install.sh 가 k3s-agent 가 아닌 다른 unit 을 만들었는지 확인: ls /etc/systemd/system/k3s*.service)"
  INSTALLED_THIS_RUN=1
  mark_changed "k3s $K3S_VERSION installed (agent)"
}

# ---------- 6. 서비스 상태 ----------
ensure_service() {
  local enabled active
  enabled=$(systemctl is-enabled k3s-agent 2>/dev/null || true)
  active=$(systemctl is-active k3s-agent 2>/dev/null || true)
  if [ "$enabled" != enabled ] || [ "$active" != active ]; then
    systemctl enable --now k3s-agent >/dev/null
    mark_changed "systemd: k3s-agent enable --now (was enabled=$enabled active=$active)"
  else
    log "systemd: k3s-agent already enabled+active"
  fi
  systemctl is-active --quiet k3s-agent || die "k3s-agent.service 가 active 가 아니다 — journalctl -u k3s-agent -n 100"
  if [ "$CONFIG_CHANGED" = 1 ] && [ "$INSTALLED_THIS_RUN" != 1 ]; then
    warn "$K3S_CONFIG 가 바뀌었지만 실행 중인 k3s-agent 는 건드리지 않는다 — 반영(k3s-agent.service 재시작)은 운영자 판단(node-label 은 등록 시 1회만 적용)"
  fi
}

# ---------- 7. 등록 로그 대기 ----------
# 이 노드에는 kubectl 이 없다. 이 부팅의 k3s-agent 저널에서 kubelet 의 등록 메시지("Successfully registered node" — 첫 등록, 또는
# "Node was previously registered" — 재부팅/재실행)를 기다린다. 없으면 die 하지 않고 warn 한다: Ready 판정의 권위는 운영자 절차 4 의 kubectl 이다.
# SINCE: 이 실행이 시작된 시각. -b(부팅 전체)만 쓰면 지난 실행의 낡은 성공 로그로도 confirmed 가 되어 이번 조인의 증거가 되지 못한다.
wait_node_registered() {
  local i out since
  since=$(date '+%Y-%m-%d %H:%M:%S' -d "@$RUN_STARTED_AT")
  for ((i = 0; i < REGISTER_TIMEOUT / 5; i++)); do
    out=$(journalctl -u k3s-agent -b --since "$since" --no-pager -o cat 2>/dev/null || true)
    if grep -qE 'Successfully registered node|Node was previously registered' <<< "$out"; then REGISTERED=confirmed; break; fi
    sleep 5
  done
  if [ "$REGISTERED" = confirmed ]; then
    log "node registration: confirmed in journal (waited ~$((i * 5))s)"
  else
    warn "${REGISTER_TIMEOUT}s 안에 등록 로그를 찾지 못했다 — journalctl -u k3s-agent -n 100 / 운영자 워크스테이션에서 kubectl get nodes -L role"
  fi
}

# ---------- summary ----------
summary() {
  local rule
  printf '\n==== k3s-agent summary: %s %s ====\n' "$(hostname)" "$(date -Is)"
  printf 'changes this run: %d\n' "${#CHANGES[@]}"
  for rule in "${CHANGES[@]:-}"; do [ -n "$rule" ] && printf '  - %s\n' "$rule"; done
  printf 'k3s: installed=%s want=%s  service: enabled=%s active=%s\n' "$(installed_k3s_version)" "$K3S_VERSION" "$(systemctl is-enabled k3s-agent 2>/dev/null || true)" "$(systemctl is-active k3s-agent 2>/dev/null || true)"
  printf 'config: %s changed=%s mode=%s\n' "$K3S_CONFIG" "$([ "$CONFIG_CHANGED" = 1 ] && printf yes || printf no)" "$(stat -c %a "$K3S_CONFIG")"
  printf 'server: %s  registration=%s  label=role=data (verify from the workstation: kubectl get nodes -L role -> 2 Ready)\n' "$K3S_URL" "$REGISTERED"
  printf 'flannel-wg iface: %s  token-file: %s (mode %s, secure format, contents never printed)\n' "$(ip link show flannel-wg >/dev/null 2>&1 && printf present || printf absent)" "$K3S_TOKEN_FILE" "$(stat -c %a "$K3S_TOKEN_FILE")"
  printf '==== end ====\n'
}

main() {
  preflight
  check_host_prep
  check_server_reachable
  check_token_file
  check_ca_hash
  render_config
  install_k3s
  ensure_service
  wait_node_registered
  summary
}

# stdin 을 /dev/null 로: `bash -s < k3s-agent.sh` 스트리밍에서도 자식 명령(설치 스크립트 포함)이 스크립트 본문을 소비하지 않는다. 뒤의 exit 는
# 그 뒤에 어떤 입력(예: PowerShell 파이프가 붙이는 CRLF)이 와도 읽지 않게 한다 — main 의 종료 상태를 그대로 반환한다.
main "$@" </dev/null; exit
