#!/usr/bin/env bash
# infra/bootstrap/host-prep.sh — K3s 노드 호스트 준비(두 노드 공용, 멱등) — 003-platform-foundation T014
#
# 대상: OCI VM.Standard.A1.Flex(aarch64) 위 Canonical Ubuntu 24.04 (재이미지 직후의 노드 A joshtech_api_1st / 노드 B joshtech_cache).
# root 로 실행한다(sudo). 재실행해도 같은 최종 상태이고 중복·오류가 없어야 한다(.claude/rules/infra.md "Bootstrap and operations scripts") —
# 모든 변경 단계는 "존재 검사 → 없을 때만 변경" 형태이며, 마지막 summary 의 "changes this run" 이 2회차에 0(노드 A 2회차는 v1 키 제거 1건)이면
# 멱등이 증명된 것이다. 정적 계약은 tests/infra/host-prep.tests.ps1 이 고정한다.
#
# 실행 방법(운영자 워크스테이션, PowerShell 7 — '<' 입력 리다이렉션이 없고 파이프는 끝에 CRLF 를 붙이므로 scp 로 올려서 실행한다):
#   scp -i <키> infra/bootstrap/host-prep.sh ubuntu@<노드 IP>:/tmp/host-prep.sh
#   ssh -i <키> ubuntu@<노드 IP> "sudo NEW_PUBKEY='<ssh-ed25519 공개 키 한 줄>' NODE_ROLE=<platform|data> bash /tmp/host-prep.sh"
#   (POSIX 셸에서는 ssh ... 'sudo NEW_PUBKEY=... NODE_ROLE=... bash -s' < infra/bootstrap/host-prep.sh 도 된다 — 본문은 main 을 </dev/null 로
#    호출하므로 자식 명령이 stdin 의 스크립트 본문을 먹지 않는다.)
#
# 입력(환경 변수; sudo VAR=값 형식 — sudoers 의 command ALL 매치가 명령행 환경 변수 지정을 허용한다):
#   NEW_PUBKEY   필수. 운영자 새 키(설계 표기 jt-ops, 실명 joshuatech-ops)의 공개 키 한 줄. ssh-ed25519 또는 sk-ssh-ed25519@openssh.com 만.
#   NODE_ROLE    필수. platform(노드 A) | data(노드 B). platform 에서만 vault CLI·OCI CLI 를 설치하고(platform-backup.sh 의존; 동적 그룹
#                joshuatech-node-a 가 노드 A 에만 권한을 주므로 노드 B 의 OCI CLI 는 쓸 곳이 없다) 443/tcp INPUT 을 연다.
#   DROP_V1_KEY  선택. 1 이면 authorized_keys 에서 NEW_PUBKEY 와 같지 않은 줄을 전부 제거한다(v1 키 무효화). 기본 = 제거하지 않음.
#                이유: OCI 는 인스턴스 metadata 의 ssh_authorized_keys 를 launch 뒤 불변으로 취급해 재이미지 첫 부팅이 항상 v1 키만 심는다
#                (instances.tf 머리 주석). 그래서 1회차는 v1 키 세션에서 새 키를 "추가"만 하고, 새 키로 다시 접속(그 접속 성공이 곧 검증)한
#                2회차에서만 DROP_V1_KEY=1 로 v1 을 지운다 — T013 6단계의 "추가 → 새 키로 검증 → v1 제거" 순서를 스크립트가 상속한다.
#                새 키 접속이 실패해도 v1 이 남아 있어 잠기지 않는다. 안전장치: 이 부팅의 sshd 로그에서 마지막 'Accepted publickey for ubuntu'
#                지문(= 지금 이 세션)이 NEW_PUBKEY 의 지문과 다르면 제거를 거부한다(v1 세션에서 v1 을 지우는 실수 차단).
#                v1 개인키 파기는 docs/runbooks/bootstrap.md §0 토큰 표 ⑦ 순서(T103 구 키 0 확인 → T105 뒤)를 따른다 — 이 스크립트의 일이 아니다.
#   POD_CIDR / SERVICE_CIDR / VCN_CIDR  선택. 기본 10.42.0.0/16 / 10.43.0.0/16 / 10.0.0.0/16 (아래 상수 주석).
#
# 절대 하지 않는 것: cloud-init clean·/var/lib/cloud 삭제(PER_INSTANCE 세마포어가 사라지면 다음 부팅에 불변 metadata 의 v1 키가 재주입된다),
#   authorized_keys 파일 삭제, ufw 편집(Oracle: OCI Ubuntu 에서 ufw 로 규칙 편집 시 부팅 실패 가능 — 비활성 확인만), apt upgrade,
#   비밀 읽기·쓰기(OCI CLI 는 설치만 — 인증은 실행 시 --auth instance_principal 플래그이며 ~/.oci/config 를 만들지 않는다).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ---------- 상수 ----------
# K3s 기본 cluster-cidr / service-cidr. plan.md·contracts/network-policy.md 는 CIDR 를 고정하지 않고 T035 의 /etc/rancher/k3s/config.yaml 문면도
# cluster-cidr/service-cidr 를 지정하지 않으므로 K3s 기본값(10.42.0.0/16 / 10.43.0.0/16; research.md 호스트 방화벽 결정과 같은 값)이다.
# 기본값을 바꾸면 여기와 T035 config.yaml 을 함께 바꾼다.
POD_CIDR="${POD_CIDR:-10.42.0.0/16}"
SERVICE_CIDR="${SERVICE_CIDR:-10.43.0.0/16}"
# infra/oci/network.tf vcn cidr_block. 노드 간 K3s 포트(6443·51820/udp·10250)의 허용 출발지 — NSG(nsg-cluster 자기참조)가 VNIC 에서 이미
# 노드 간으로 좁히고, 호스트 방화벽은 그 안쪽의 2차 경계다.
VCN_CIDR="${VCN_CIDR:-10.0.0.0/16}"
RULES_V4=/etc/iptables/rules.v4
WG_MODULES_CONF=/etc/modules-load.d/wireguard.conf
AK_DIR=/home/ubuntu/.ssh
AK_FILE="$AK_DIR/authorized_keys"
HC_KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg
HC_LIST=/etc/apt/sources.list.d/hashicorp.list
HC_PIN=/etc/apt/preferences.d/vault
# HashiCorp 공식 apt 서명 키 지문(developer.hashicorp.com/vault/install "Linux → Ubuntu/Debian" 문서의 --fingerprint 출력). 다르면 실패한다.
HC_GPG_FPR=798AEC654E5C15428C8E42EEAA16FCBCA621E701
VAULT_MAJOR=2   # plan.md: Vault 2.0.x(서버 2.0.4) — CLI 도 같은 메이저에 고정(apt pin)
UU_CONF=/etc/apt/apt.conf.d/50unattended-upgrades
UU_AUTO=/etc/apt/apt.conf.d/20auto-upgrades
PIPX_HOME_DIR=/opt/pipx      # pipx 격리 venv 루트 — 시스템 python 에 pip 오염 없음
PIPX_BIN_DIR=/usr/local/bin  # oci 실행 파일 위치 — sudo secure_path 에 포함되어 platform-backup.sh(systemd timer, root)가 찾는다
TZ_WANT=Asia/Seoul

CHANGES=()
APT_UPDATED=0
AK_LINES=0

log()  { printf '[host-prep] %s\n' "$*"; }
warn() { printf '[host-prep] WARN: %s\n' "$*" >&2; }
die()  { printf '[host-prep] ERROR: %s\n' "$*" >&2; exit 1; }
mark_changed() { CHANGES+=("$*"); log "CHANGED: $*"; }

# ---------- 공통 헬퍼(멱등) ----------
# $1 경로, $2 내용(끝 개행은 여기서 보장), [$3 mode]. 내용이 같으면 손대지 않는다.
write_if_changed() {
  local path=$1 content=$2 mode=${3:-644} tmp
  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"
  if [ -f "$path" ] && cmp -s "$tmp" "$path"; then rm -f "$tmp"; log "unchanged: $path"; return 0; fi
  install -m "$mode" -o root -g root "$tmp" "$path"
  rm -f "$tmp"
  mark_changed "wrote $path"
}

apt_update_once() {
  if [ "$APT_UPDATED" != 1 ]; then apt-get update -qq; APT_UPDATED=1; fi
}

# 인자: 패키지... — 설치되지 않은 것만 설치한다(전부 있으면 apt-get update 도 생략).
apt_install_missing() {
  local missing=() p
  for p in "$@"; do
    if [ "$(dpkg-query -W -f='${Status}' "$p" 2>/dev/null || true)" != "install ok installed" ]; then missing+=("$p"); fi
  done
  if [ "${#missing[@]}" -eq 0 ]; then log "apt: already installed: $*"; return 0; fi
  apt_update_once
  apt-get install -y -qq --no-install-recommends "${missing[@]}"
  mark_changed "apt installed: ${missing[*]}"
}

# ---------- 0. 사전 확인 ----------
preflight() {
  [ "$(id -u)" -eq 0 ] || die "root 로 실행해야 한다(sudo)"
  # shellcheck disable=SC1091
  . /etc/os-release
  { [ "${ID:-}" = ubuntu ] && [ "${VERSION_ID:-}" = 24.04 ]; } || die "Ubuntu 24.04 전용이다 (감지: ${ID:-?} ${VERSION_ID:-?})"
  [ "$(uname -m)" = aarch64 ] || die "arm64(aarch64) 전용이다 (감지: $(uname -m))"
  id ubuntu >/dev/null 2>&1 || die "ubuntu 사용자가 없다"
  [ -n "${NEW_PUBKEY:-}" ] || die "NEW_PUBKEY 가 비어 있다 — 새 키(joshuatech-ops)의 공개 키 한 줄을 넘긴다"
  local re='^(ssh-ed25519|sk-ssh-ed25519@openssh\.com) [A-Za-z0-9+/]+=*( [^[:cntrl:]]*)?$'
  [[ "$NEW_PUBKEY" =~ $re ]] || die "NEW_PUBKEY 는 ssh-ed25519 또는 sk-ssh-ed25519@openssh.com 공개 키 한 줄이어야 한다(개행·제어 문자 없이)"
  case "${NODE_ROLE:-}" in platform|data) ;; *) die "NODE_ROLE 은 platform(노드 A) 또는 data(노드 B)여야 한다 (감지: '${NODE_ROLE:-}')" ;; esac
  case "${DROP_V1_KEY:-0}" in 0|1) ;; *) die "DROP_V1_KEY 는 미설정 또는 1 이어야 한다" ;; esac
  command -v netfilter-persistent >/dev/null 2>&1 || die "netfilter-persistent 가 없다 — OCI Ubuntu 이미지가 아니다(iptables-persistent 를 새로 설치하면 rules.v4 를 덮어쓸 수 있어 자동 설치하지 않는다)"
  [ -f "$RULES_V4" ] || die "$RULES_V4 가 없다 — OCI Ubuntu 이미지 기본 파일이 있어야 한다"
  if command -v ufw >/dev/null 2>&1 && [ "$(ufw status 2>/dev/null | head -n 1)" = "Status: active" ]; then
    die "ufw 가 활성이다 — Oracle 은 OCI Ubuntu 에서 ufw 편집을 금지한다(부팅 실패 가능). 수동으로 비활성화한 뒤 다시 실행한다"
  fi
  log "preflight OK: $(hostname) role=$NODE_ROLE ubuntu=$VERSION_ID arch=$(uname -m) kernel=$(uname -r)"
}

# ---------- (d) cgroup v2 ----------
check_cgroup_v2() {
  local fs
  fs=$(stat -fc %T /sys/fs/cgroup)
  [ "$fs" = cgroup2fs ] || die "cgroup v2 가 아니다 (/sys/fs/cgroup = $fs) — K3s 요구 조건"
  log "cgroup v2 OK ($fs)"
}

# ---------- (c) authorized_keys ----------
# 공개 키 한 줄 → SHA256 지문(비밀 아님).
pubkey_fingerprint() {
  local f fpr
  f=$(mktemp)
  printf '%s\n' "$1" > "$f"
  fpr=$(ssh-keygen -lf "$f" | awk '{print $2}')
  rm -f "$f"
  printf '%s' "$fpr"
}

# 이 부팅의 sshd 로그에서 마지막 'Accepted publickey for ubuntu' 지문 — 직전 성공 로그인이 곧 지금 이 세션이다.
current_session_fingerprint() {
  journalctl -b -o cat --no-pager -t sshd -t sshd-session 2>/dev/null \
    | grep -E '^Accepted publickey for ubuntu ' | tail -n 1 | grep -oE 'SHA256:[A-Za-z0-9+/=]+' || true
}

# NEW_PUBKEY 이외의 줄을 전부 제거한다. DROP_V1_KEY=1 게이트 안에서만 호출된다(머리 주석 순서).
drop_other_keys() {
  local want have others tmp
  want=$(pubkey_fingerprint "$NEW_PUBKEY")
  have=$(current_session_fingerprint)
  [ -n "$have" ] || die "DROP_V1_KEY=1 거부: 이 부팅의 sshd 로그에 'Accepted publickey for ubuntu' 가 없다 — 새 키로 SSH 접속한 세션에서만 실행한다"
  [ "$have" = "$want" ] || die "DROP_V1_KEY=1 거부: 이 세션의 로그인 키 지문($have)이 NEW_PUBKEY 지문($want)과 다르다 — v1 키 세션에서 v1 을 지우면 잠긴다. 새 키로 다시 접속해 실행한다"
  others=$(grep -vxF -- "$NEW_PUBKEY" "$AK_FILE" | grep -c . || true)
  if [ "${others:-0}" -eq 0 ]; then log "authorized_keys: 제거할 다른 키 없음(이미 새 키뿐)"; return 0; fi
  tmp=$(mktemp -p "$AK_DIR" .ak.XXXXXX)   # 같은 디렉터리 → 아래 mv 가 rename(2) 원자 교체가 된다
  grep -xF -- "$NEW_PUBKEY" "$AK_FILE" > "$tmp"   # 새 키 줄만 남긴다
  [ -s "$tmp" ] || { rm -f "$tmp"; die "내부 오류: 새 키 줄이 비어 있다 — authorized_keys 를 건드리지 않았다"; }
  chown ubuntu:ubuntu "$tmp"
  chmod 600 "$tmp"
  mv -f "$tmp" "$AK_FILE"   # 원자 교체(rename) — sshd 는 구 파일 또는 새 파일만 본다; 파일을 지우는 경로는 없다
  mark_changed "authorized_keys: 다른 키 $others 줄 제거(v1 키 무효화)"
}

setup_authorized_keys() {
  install -d -m 700 -o ubuntu -g ubuntu "$AK_DIR"
  [ -f "$AK_FILE" ] || install -m 600 -o ubuntu -g ubuntu /dev/null "$AK_FILE"
  if grep -qxF -- "$NEW_PUBKEY" "$AK_FILE"; then
    log "authorized_keys: 새 키 이미 있음"
  else
    # 마지막 줄에 개행이 없으면(수동 편집 흔적) 새 키가 그 줄에 이어 붙어 두 키 모두 깨진다 → 개행을 먼저 보장한다
    if [ -s "$AK_FILE" ] && [ -n "$(tail -c 1 "$AK_FILE")" ]; then printf '\n' >> "$AK_FILE"; fi
    printf '%s\n' "$NEW_PUBKEY" >> "$AK_FILE"
    mark_changed "authorized_keys: 새 키 추가"
  fi
  if [ "${DROP_V1_KEY:-0}" = 1 ]; then
    drop_other_keys
  else
    log "authorized_keys: DROP_V1_KEY 미설정 — 다른 키 유지(새 키로 재접속해 검증한 뒤 2회차에서 DROP_V1_KEY=1)"
  fi
  chown ubuntu:ubuntu "$AK_FILE"
  chmod 600 "$AK_FILE"
  AK_LINES=$(grep -c . "$AK_FILE" || true)
  log "authorized_keys 줄 수: $AK_LINES"
}

# ---------- (b) wireguard 커널 모듈 ----------
# K3s flannel-backend: wireguard-native 는 커널 wireguard 모듈을 요구한다(없으면 flannel 이 뜨지 않는다). 부팅마다 자동 로드되게 등재한다.
setup_wireguard_module() {
  lsmod | grep -q '^wireguard' || modprobe wireguard || die "wireguard 모듈을 로드할 수 없다 ($(uname -r)) — 커널 지원 확인"
  [ -d /sys/module/wireguard ] || die "modprobe 뒤에도 wireguard 모듈이 보이지 않는다(/sys/module/wireguard 없음)"   # 로드된 모듈(built-in 포함)의 확정 증거
  if [ -f "$WG_MODULES_CONF" ] && grep -qxF wireguard "$WG_MODULES_CONF"; then
    log "modules-load: wireguard 이미 등재"
  else
    printf 'wireguard\n' >> "$WG_MODULES_CONF"
    mark_changed "modules-load: wireguard 등재 ($WG_MODULES_CONF)"
  fi
  log "wireguard module OK"
}

# ---------- (a) iptables ----------
# OCI Ubuntu 이미지의 /etc/iptables/rules.v4(iptables-persistent)는 22·ICMP·NTP·RELATED,ESTABLISHED 만 INPUT 에서 받고 마지막의
#   -A INPUT -j REJECT --reject-with icmp-host-prohibited
#   -A FORWARD -j REJECT --reject-with icmp-host-prohibited
# 두 줄로 나머지 INPUT·FORWARD 를 전부 거부한다. 체인은 위에서 아래로 평가되므로 REJECT 뒤에 붙인 규칙은 영원히 닿지 않는다 —
# 반드시 그 REJECT 줄 "앞"에 넣는다. InstanceServices 체인·iSCSI(169.254.0.2:3260) 규칙은 Oracle 이 제거를 금지하므로 그대로 둔다.
# 규칙 문자열은 iptables-save 정규형으로 적어 두어 grep -x 로 정확히 재인식한다(멱등).
input_rules() {
  printf '%s\n' \
    "-A INPUT -s $VCN_CIDR -p tcp -m tcp --dport 6443 -j ACCEPT" \
    "-A INPUT -s $VCN_CIDR -p udp -m udp --dport 51820 -j ACCEPT" \
    "-A INPUT -s $VCN_CIDR -p tcp -m tcp --dport 10250 -j ACCEPT" \
    "-A INPUT -s $POD_CIDR -j ACCEPT" \
    "-A INPUT -s $SERVICE_CIDR -j ACCEPT"
  # 노드 A 만: Cloudflare → 443. NSG(nsg-node-a-platform)가 Cloudflare IPv4 로 이미 한정한다. ServiceLB(klipper-lb) hostPort 는 DNAT 되어
  # FORWARD 로 흐르지만, hostNetwork 리스너가 생겨도 막히지 않도록 INPUT 도 연다(리스너가 없으면 무해).
  if [ "$NODE_ROLE" = platform ]; then
    printf '%s\n' "-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT"
  fi
}
forward_rules() {
  printf '%s\n' \
    "-A FORWARD -s $POD_CIDR -j ACCEPT" \
    "-A FORWARD -d $POD_CIDR -j ACCEPT"
}

# $1 = 앵커 정규식(*filter 테이블 안 첫 등장), $2 = 규칙 줄. 앵커 바로 앞에 삽입하고 같은 디렉터리 임시 파일 + mv(rename) 로 원자 교체한다.
insert_rule_before() {
  local anchor=$1 rule=$2 tmp
  [ -f "$RULES_V4.host-prep.orig" ] || cp -p "$RULES_V4" "$RULES_V4.host-prep.orig"   # 최초 변경 전 원본 1회 보존
  tmp=$(mktemp -p "$(dirname "$RULES_V4")" .rules.v4.XXXXXX)
  if ! awk -v anchor="$anchor" -v rule="$rule" '
      /^\*/ { infilter = ($0 == "*filter") }
      !done && infilter && $0 ~ anchor { print rule; done = 1 }
      { print }
      END { if (!done) exit 3 }' "$RULES_V4" > "$tmp"; then
    rm -f "$tmp"
    die "$RULES_V4: *filter 테이블에 앵커($anchor)가 없다 — 수동 검토"
  fi
  chmod --reference="$RULES_V4" "$tmp"   # 원본의 권한·소유를 그대로 물려받는다(root:root, 이미지 기본 모드)
  chown --reference="$RULES_V4" "$tmp"
  mv -f "$tmp" "$RULES_V4"   # rename(2) — 원자 교체; iptables-restore 가 반쪽 파일을 읽을 수 없다
}

# $1 = 체인(INPUT|FORWARD), $2 = 규칙 줄(rules.v4 문법). 없을 때만 그 체인의 첫 '-j REJECT' 줄 바로 앞에 삽입한다.
# 앵커 부재: INPUT 은 die(이미지 기본 규칙과 다르다 — 수동 검토). FORWARD 는 정책이 ACCEPT 면 규칙이 불필요하므로 skip(로그),
# ACCEPT 가 아니면(DROP 정책 등) COMMIT 직전에 append 한다.
ensure_rule_before_reject() {
  local chain=$1 rule=$2
  if grep -qxF -- "$rule" "$RULES_V4"; then log "rules.v4: present  $rule"; return 0; fi
  if grep -qE "^-A $chain -j REJECT" "$RULES_V4"; then
    insert_rule_before "^-A $chain -j REJECT" "$rule"
  elif [ "$chain" = FORWARD ] && grep -qE '^:FORWARD ACCEPT ' "$RULES_V4"; then
    log "rules.v4: FORWARD 에 REJECT 앵커가 없고 정책이 ACCEPT — 규칙 불필요, skip  $rule"
    return 0
  elif [ "$chain" = FORWARD ]; then
    warn "rules.v4: FORWARD 에 REJECT 앵커가 없고 정책이 ACCEPT 가 아니다 — COMMIT 직전에 append  $rule"
    insert_rule_before '^COMMIT$' "$rule"
  else
    die "$RULES_V4 에 '-A $chain -j REJECT' 줄이 없다 — 이미지 기본 규칙과 다르므로 수동 검토"
  fi
  mark_changed "rules.v4: inserted  $rule"
}

# 살아 있는 커널 규칙에 없을 때만 그 체인의 REJECT 앞 위치에 삽입한다(K3s 실행 중 경로 전용).
live_insert_before_reject() {
  local chain=$1 rule=$2 idx
  # shellcheck disable=SC2086
  if iptables ${rule/#-A /-C } 2>/dev/null; then return 0; fi
  idx=$(iptables -S "$chain" | awk '!f && /-j REJECT/ { print NR-1; f=1 }')   # -S 의 첫 줄은 -P(정책)이라 규칙 번호 = NR-1 (awk 는 끝까지 읽는다 — pipefail 하 SIGPIPE 회피)
  if [ -n "$idx" ]; then
    # shellcheck disable=SC2086
    iptables ${rule/#-A $chain /-I $chain $idx }
  else
    # shellcheck disable=SC2086
    iptables $rule
  fi
  mark_changed "iptables(live): $rule"
}

setup_iptables() {
  local rule k3s_active=0
  while IFS= read -r rule; do ensure_rule_before_reject INPUT "$rule"; done < <(input_rules)
  while IFS= read -r rule; do ensure_rule_before_reject FORWARD "$rule"; done < <(forward_rules)
  if systemctl is-active --quiet k3s 2>/dev/null || systemctl is-active --quiet k3s-agent 2>/dev/null; then k3s_active=1; fi
  if [ "$k3s_active" = 1 ]; then
    # 전체 재적재(netfilter-persistent reload = iptables-restore)는 kube-proxy·flannel 의 런타임 체인을 지운다 → 빠진 규칙만 라이브 삽입.
    warn "K3s 실행 중 — netfilter-persistent reload 를 건너뛰고 빠진 규칙만 라이브 삽입한다(파일은 이미 갱신됨)"
    while IFS= read -r rule; do live_insert_before_reject INPUT "$rule"; done < <(input_rules)
    while IFS= read -r rule; do live_insert_before_reject FORWARD "$rule"; done < <(forward_rules)
  else
    netfilter-persistent reload >/dev/null   # 파일 전체 재적재 — 멱등(같은 파일 = 같은 상태). 파일과 커널 상태를 항상 일치시킨다
    log "netfilter-persistent reload OK"
  fi
  # 검증: 모든 규칙이 커널에 있어야 한다(fail closed)
  while IFS= read -r rule; do
    # shellcheck disable=SC2086
    iptables ${rule/#-A /-C } || die "적용 뒤에도 커널에 없다: $rule"
  done < <(input_rules; forward_rules)
  log "iptables OK (6443/tcp, 51820/udp, 10250/tcp, pod $POD_CIDR, svc $SERVICE_CIDR, forward $POD_CIDR$([ "$NODE_ROLE" = platform ] && printf ', 443/tcp'))"
}

# ---------- (e) 패키지 ----------
install_vault_cli() {
  local tmp fpr
  if [ ! -s "$HC_KEYRING" ]; then
    tmp=$(mktemp)
    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor > "$tmp"
    fpr=$(gpg --show-keys --with-colons "$tmp" 2>/dev/null | awk -F: '!f && $1=="fpr" { print $10; f=1 }')   # 첫 fpr(기본 키)만; awk 는 끝까지 읽는다
    [ "$fpr" = "$HC_GPG_FPR" ] || { rm -f "$tmp"; die "HashiCorp apt 서명 키 지문 불일치: got '$fpr' want '$HC_GPG_FPR' — 문서의 지문과 대조한다"; }
    install -m 644 -o root -g root "$tmp" "$HC_KEYRING"
    rm -f "$tmp"
    mark_changed "hashicorp apt keyring installed ($HC_KEYRING)"
  else
    log "hashicorp keyring present"
  fi
  write_if_changed "$HC_LIST" "deb [arch=arm64 signed-by=$HC_KEYRING] https://apt.releases.hashicorp.com noble main"
  write_if_changed "$HC_PIN" "$(printf 'Package: vault\nPin: version %s.*\nPin-Priority: 1001' "$VAULT_MAJOR")"
  if command -v vault >/dev/null 2>&1 && [[ "$(vault version 2>/dev/null)" == "Vault v${VAULT_MAJOR}."* ]]; then
    log "vault CLI present: $(vault version)"
  else
    # 새 소스가 추가됐거나 메이저가 다르면 목록을 다시 읽고 pin 범위(2.*) 안에서 설치한다
    APT_UPDATED=0
    apt_update_once
    apt-get install -y -qq vault
    # pin 은 2.* 에만 우선순위를 주므로 저장소에 2.* 가 없으면 apt 가 다른 메이저를 고를 수 있다 → 설치 결과의 메이저를 확정 검사
    [[ "$(vault version 2>/dev/null)" == "Vault v${VAULT_MAJOR}."* ]] || die "vault CLI 메이저 불일치: $(vault version 2>/dev/null || echo none) (want v${VAULT_MAJOR}.x) — apt.releases.hashicorp.com 의 arm64 목록을 확인한다"
    mark_changed "vault CLI installed: $(vault version)"
  fi
}

# OCI CLI: pipx 격리 venv(/opt/pipx) + /usr/local/bin/oci. 시스템 python 에 pip 설치 없음(공식 install.sh 대신 — 같은 결과, 더 단순한 멱등 검사).
# 인증은 설정하지 않는다: platform-backup.sh 가 실행 시 `oci --auth instance_principal ...` 로 노드 신원(동적 그룹 joshuatech-node-a)을 쓴다.
install_oci_cli() {
  apt_install_missing pipx python3-venv
  export PIPX_HOME="$PIPX_HOME_DIR" PIPX_BIN_DIR="$PIPX_BIN_DIR"
  local installed
  installed=$(pipx list --short 2>/dev/null || true)   # 변수로 받아 herestring 으로 검사 — pipefail 하 grep -q 조기 종료 SIGPIPE 회피
  if grep -q '^oci-cli ' <<< "$installed"; then
    log "oci-cli present: $("$PIPX_BIN_DIR/oci" --version)"
  else
    pipx install oci-cli >/dev/null
    mark_changed "oci-cli installed via pipx: $("$PIPX_BIN_DIR/oci" --version)"
  fi
}

setup_packages() {
  # 두 노드 공통: sqlite3(K3s 데이터스토어 백업 읽기), age(백업 번들 암호화), wireguard-tools(`wg show flannel-wg` 진단; 모듈 자체는 커널)
  apt_install_missing sqlite3 age wireguard-tools ca-certificates curl gnupg
  if [ "$NODE_ROLE" = platform ]; then
    install_vault_cli
    install_oci_cli
  else
    log "role=data: vault CLI·OCI CLI 는 설치하지 않는다(platform 전용)"
  fi
}

# ---------- (f) unattended-upgrades: security only ----------
setup_unattended_upgrades() {
  apt_install_missing unattended-upgrades
  write_if_changed "$UU_CONF" "$(cat <<'EOF'
// managed by infra/bootstrap/host-prep.sh (T014) — security pockets only. Edit the script, not this file.
Unattended-Upgrade::Allowed-Origins {
        "${distro_id}:${distro_codename}-security";
        "${distro_id}ESMApps:${distro_codename}-apps-security";
        "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
EOF
)"
  write_if_changed "$UU_AUTO" "$(printf '%s\n%s' 'APT::Periodic::Update-Package-Lists "1";' 'APT::Periodic::Unattended-Upgrade "1";')"
  systemctl enable --now apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || warn "apt-daily timers: enable 실패(수동 확인)"
  log "unattended-upgrades: security-only, automatic reboot off (재부팅은 docs/runbooks §6 업그레이드 창)"
}

# ---------- (g) 시간대 ----------
setup_timezone() {
  local cur
  cur=$(timedatectl show -p Timezone --value)
  if [ "$cur" = "$TZ_WANT" ]; then
    log "timezone already $TZ_WANT"
  else
    timedatectl set-timezone "$TZ_WANT"
    mark_changed "timezone $cur -> $TZ_WANT"
  fi
}

# ---------- summary ----------
summary() {
  local others rule
  others=$(grep -vxF -- "$NEW_PUBKEY" "$AK_FILE" | grep -c . || true)
  printf '\n==== host-prep summary: %s role=%s %s ====\n' "$(hostname)" "$NODE_ROLE" "$(date -Is)"
  printf 'changes this run: %d\n' "${#CHANGES[@]}"
  for rule in "${CHANGES[@]:-}"; do [ -n "$rule" ] && printf '  - %s\n' "$rule"; done
  printf 'os: %s  kernel: %s  cgroup: %s\n' "$(lsb_release -ds 2>/dev/null || true)" "$(uname -r)" "$(stat -fc %T /sys/fs/cgroup)"
  printf 'wireguard: loaded=%s  modules-load=%s\n' "$([ -d /sys/module/wireguard ] && echo yes || echo no)" "$(grep -qxF wireguard "$WG_MODULES_CONF" 2>/dev/null && echo yes || echo no)"
  printf 'iptables (kernel):'
  while IFS= read -r rule; do
    # shellcheck disable=SC2086
    printf ' [%s]=%s' "$(printf '%s' "$rule" | awk '{for(i=1;i<=NF;i++) if($i=="--dport"||$i=="-s"||$i=="-d") printf "%s%s", (o++?"/":""), $(i+1)}')" "$(iptables ${rule/#-A /-C } 2>/dev/null && echo ok || echo MISSING)"
  done < <(input_rules; forward_rules)
  printf '\n'
  printf 'authorized_keys: %s line(s), new key present=%s, other keys=%s (DROP_V1_KEY=%s)\n' "$AK_LINES" "$(grep -qxF -- "$NEW_PUBKEY" "$AK_FILE" && echo yes || echo no)" "${others:-0}" "${DROP_V1_KEY:-unset}"
  printf 'packages: sqlite3=%s age=%s wireguard-tools=%s' "$(sqlite3 --version 2>/dev/null | awk '{print $1}')" "$(age --version 2>/dev/null || true)" "$(wg --version 2>/dev/null | awk '{print $2}')"
  if [ "$NODE_ROLE" = platform ]; then
    printf ' vault=%s oci=%s' "$(vault version 2>/dev/null | awk '{print $2}')" "$("$PIPX_BIN_DIR/oci" --version 2>/dev/null || true)"
  fi
  printf '\n'
  printf 'unattended-upgrades: security-only (%s)  timezone: %s\n' "$UU_CONF" "$(timedatectl show -p Timezone --value)"
  printf '==== end ====\n'
}

main() {
  preflight
  check_cgroup_v2
  setup_authorized_keys
  setup_wireguard_module
  setup_iptables
  setup_packages
  setup_unattended_upgrades
  setup_timezone
  summary
}

# stdin 을 /dev/null 로: `bash -s < host-prep.sh` 스트리밍에서도 자식 명령이 스크립트 본문을 소비하지 않는다. 뒤의 exit 는 그 뒤에 어떤
# 입력(예: PowerShell 파이프가 붙이는 CRLF)이 와도 읽지 않게 한다 — main 의 종료 상태를 그대로 반환한다.
main "$@" </dev/null; exit
