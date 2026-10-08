#!/usr/bin/env bash
# infra/bootstrap/k3s-server.sh — 노드 A(joshtech-api, role=platform) K3s server 설치 + /etc/rancher/k3s/config.yaml 렌더(멱등) — 003-platform-foundation T035
#
# 대상: T014 host-prep.sh 를 마친 노드 A(OCI VM.Standard.A1.Flex, Ubuntu 24.04 arm64, 사설 IP 10.0.7.78). 노드 B(agent) 는 T036 몫이다.
# root 로 실행한다(sudo). 재실행해도 같은 최종 상태이고 중복·오류가 없어야 한다(.claude/rules/infra.md "Bootstrap and operations scripts") —
# 모든 변경 단계는 "존재 검사 → 없을 때만 변경" 형태이며, 2회차 summary 의 "changes this run: 0" 이 멱등의 증명이다.
# 정적 계약은 tests/infra/k3s-server.tests.ps1 이 고정한다.
#
# 하는 일(순서): 전제 검증(host-prep 결과를 검증만 한다 — iptables·모듈·시간대를 재구성하지 않는다) → resolv.conf 렌더(0644, 파드 DNS 업스트림 — 아래 "파드 DNS")
#   → config.yaml 렌더(0600, 내용이 같으면 손대지 않음)
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
#   K3S_RESOLV_NAMESERVERS 선택. 기본 "1.1.1.1 8.8.8.8"(공백 구분). /etc/rancher/k3s/resolv.conf 에 nameserver 줄로 렌더되고 kubelet 이 파드 DNS 의
#                         업스트림으로 쓴다(아래 "파드 DNS"). 공개 주소만 받는다 — 루프백·링크로컬(169.254/16: OCI VCN 리졸버·IMDS)·사설(10/8·
#                         172.16/12·192.168/16)·멀티캐스트는 preflight 에서 die 한다. 노드 자신의 DNS(systemd-resolved → VCN)는 건드리지 않는다.
#
# 파드 DNS(resolv-conf) — 사용자 결정 2026-09-08 옵션 B, T041 PR-B2 선행 게이트:
#   실측(운영자 2026-09-08, 노드 A): /etc/resolv.conf 는 systemd-resolved 스텁(127.0.0.53), /run/systemd/resolve/resolv.conf 와 resolvectl 의 유일한
#   업스트림은 OCI VCN 리졸버(링크로컬 주소, IMDS 와 같은 IP). CoreDNS 컨테이너가 실제로 마운트한 sandbox resolv.conf 도 같은 주소였고,
#   /var/lib/rancher/k3s/agent/etc/resolv.conf 는 없었다. 이유는 K3s 소스에 있다 — pkg/agent/config/config.go 의 locateOrGenerateResolvConf 는
#   ["/etc/resolv.conf", "/run/systemd/resolve/resolv.conf"] 를 훑어 첫 유효 파일을 kubelet 에 넘기고, isValidNameserver 는 전역 유니캐스트가 아니어도
#   IMDS 주소만은 예외로 통과시킨다("some cloud providers require traffic be forwarded to [it] in order for private DNS to work"). 그래서 스텁은
#   걸러지고 VCN 리졸버가 그대로 파드 업스트림이 된다(생성 파일이 없는 이유이기도 하다).
#   문제: T041 이 배포할 계약 정책 kube-system/deny-imds 는 egress ipBlock 0.0.0.0/0 except IMDS 를 ports 없이 허용한다(contracts/network-policy.md).
#   kube-system 에는 default-deny 가 없으므로 이 정책이 파드를 선택하는 순간 egress 가 그 규칙으로 제한되고, 업스트림이 IMDS 주소인 CoreDNS 는
#   외부 이름 해석이 통째로 끊긴다(repo-server github.com, cert-manager ACME, vault OCI KMS, cloudflared 엣지 재해석 = 유일한 접근 경로).
#   결정 B: 계약·정책을 고치지 않고 노드가 파드에 물려주는 resolv.conf 만 공개 리졸버로 바꾼다. 업스트림이 더는 IMDS 주소가 아니므로 deny-imds 가
#   이미 허용하는 "0.0.0.0/0 except IMDS" 안에 들어가고, 계약 매트릭스에 행을 추가할 필요가 없다(cert-manager → 1.1.1.1:53 행이 이미 있어 공개
#   리졸버 자체도 새 의존이 아니다). 노드 자신의 이름 해석(apt·oci-cli·ssh)은 systemd-resolved 그대로다.
#   구현: config.yaml 의 resolv-conf 키 = kubelet --resolv-conf. K3s v1.36.4+k3s1 에서 이 플래그는 server·agent 양쪽에 있고(pkg/cli/cmds/agent.go
#   197-202 ResolvConfFlag 정의, agent.go 322 = agent 명령, pkg/cli/cmds/server.go 606 = ServerFlags; docs.k3s.io/cli/server·/cli/agent 의 CLI help
#   "--resolv-conf value (agent/networking) Kubelet resolv.conf file"), config.yaml 의 키는 CLI 플래그와 1:1 로 매핑된다
#   (docs.k3s.io/installation/configuration "In general, CLI arguments map to their respective YAML key"; pkg/configfilearg/parser.go readConfigFile
#   이 키를 --key=value 로 바꾸고 stripInvalidFlags 가 그 명령의 유효 플래그만 남긴다). 플래그가 지정되면 위 탐색·검증을 건너뛰고 이 파일이 그대로 쓰인다.
#   파일 형식: nameserver 줄만 둔다. search 줄을 두지 않는 이유 — 파드는 클러스터 안에서는 서비스 DNS(*.svc.cluster.local), 밖에서는 완전한 공개
#   FQDN(github.com·ACME·OCI·Grafana Cloud)만 쓰고 oraclevcn.com 이름을 쓰지 않으며, 노드 사이 통신은 사설 IP 로 지정한다(config.yaml 의 server:,
#   계약의 ipBlock <노드 IP>/32). '#' 로 시작하는 줄은 kubelet 파서가 건너뛴다(k8s pkg/kubelet/network/dns/dns.go parseResolvConf 246-248).
#   반영 범위: dnsPolicy: Default 파드(= K3s 번들 CoreDNS, manifests/coredns.yaml 182행)만 이 파일의 nameserver 를 직접 받는다 — sandbox 생성 시점에
#   결정되므로 이미 도는 CoreDNS 는 rollout restart 가 필요하다. ClusterFirst 파드는 CoreDNS 만 보므로(dns.go GetPodDNS: servers = clusterDNS)
#   재생성이 필요 없다. 살아 있는 노드에 적용하는 운영자 절차는 docs/runbooks/bootstrap.md §3 "파드 DNS 업스트림 전환".
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
#        $tok = [Convert]::ToHexString([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)).ToLower()   # 64 hex, .NET 만으로
#        # (openssl 이 PATH 에 있으면 $tok = (openssl rand -hex 32).Trim() 도 같다 — PowerShell 7 기본 PATH 에는 없을 수 있다)
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
#        (같은 명령 한 번 더) → summary: changes this run: 0, node Ready=1, labels=1, secrets-encrypt Enabled(XSalsa20-POLY1305)
#      첫 설치(1회차)는 install.sh 안의 서비스 기동에서 멈춰 보일 수 있다: k3s.service 는 TimeoutStartSec=0 이라 systemd 가 기동을 기다리며,
#      이 스크립트의 180 s Ready 상한은 그 뒤(재실행 경로 포함)에만 적용된다. 진행 상황은 다른 세션에서 ssh … "sudo journalctl -u k3s -f" 로 본다.
#   4. admin kubeconfig(/etc/rancher/k3s/k3s.yaml, root 0600) 1회 취득 — 터미널에 출력하지 않는다(sudo cat … 금지). 복사본을 만들어 scp 로 가져온다:
#        ssh … ubuntu@144.24.85.118 "sudo install -m 600 -o ubuntu -g ubuntu /etc/rancher/k3s/k3s.yaml /home/ubuntu/k3s-admin.yaml"
#        scp … ubuntu@144.24.85.118:/home/ubuntu/k3s-admin.yaml "$env:TEMP\k3s-admin.yaml"
#        ssh … ubuntu@144.24.85.118 "shred -u /home/ubuntu/k3s-admin.yaml"
#      파일의 server: 는 기본 https://127.0.0.1:6443 — 그대로 둔다. 부트스트랩 창에는 SSH 로컬 포워딩(아래 5), T039 뒤에는 cloudflared
#      (cloudflared access tcp --hostname k8s.joshuatech.dev --url 127.0.0.1:6443)가 같은 주소를 제공하므로 편집이 필요 없다.
#      보관: 비밀번호 관리자 항목 "k3s admin kubeconfig (node A)" + 운영자 워크스테이션 $HOME\.kube\joshuatech-admin.yaml(소유자 전용 ACL —
#      icacls "$HOME\.kube\joshuatech-admin.yaml" /inheritance:r /grant:r "$env:USERNAME:(R,W)"), 그리고 Remove-Item "$env:TEMP\k3s-admin.yaml".
#      취급: 운영자 셸에서 kubectl --kubeconfig "$HOME\.kube\joshuatech-admin.yaml" … 로만 쓴다. 에이전트 셸의 KUBECONFIG 로 내보내지 않고,
#      이 저장소·워크트리·CI 에 두지 않는다(.claude/rules/infra.md "Credentials": admin kubeconfig 는 에이전트 환경 변수·파일·저장소에 "임시로도"
#      두지 않는다). 에이전트·tester 는 T041 의 agent-view 토큰 kubeconfig 만 쓴다.
#   5. 확인 — 둘 중 하나. (a) 노드에서 직접:
#        ssh … ubuntu@144.24.85.118 "sudo k3s kubectl get nodes -L role,svccontroller.k3s.cattle.io/enablelb"
#      (b) 워크스테이션에서 SSH 로컬 포워딩(NSG 변경 0, kubeconfig 편집 0 — server: 가 이미 127.0.0.1:6443):
#        ssh -i ~/.ssh/joshuatech-ops -o IdentitiesOnly=yes -N -L 6443:127.0.0.1:6443 ubuntu@144.24.85.118      # 별도 창에서 유지
#        kubectl --kubeconfig "$HOME\.kube\joshuatech-admin.yaml" get nodes -L role,svccontroller.k3s.cattle.io/enablelb
#      기대: 1 Ready, role=platform, enablelb=true.
#   6. 실행 기록은 docs/runbooks/bootstrap.md §3 에 컨트롤러 지시로 적는다. Access 세션 종료(cloudflared 토큰 캐시 삭제)는 부트스트랩 예외 경로에서 해당 없음
#      (`cloudflared access logout` 하위 명령은 존재하지 않는다 — 2026-09-07 확인, 규칙 infra.md 참조).
#
# 절대 하지 않는 것: 토큰 생성·출력·로그, kubeconfig 출력·복사(절차 4 는 운영자의 손), IMDS 조회, "curl 파이프 sh", 버전 변경(다른 버전이 있으면 중단),
#   k3s 재시작(config 가 바뀌어도 실행 중인 k3s 는 건드리지 않고 경고만), 노드 자신의 이름 해석 변경(/etc/resolv.conf·systemd-resolved·netplan 은
#   손대지 않는다 — 이 스크립트가 만드는 것은 kubelet 이 파드에 물려줄 별도 파일뿐이다), host-prep 결과의 재구성(iptables·모듈·시간대·패키지는 검증만),
#   kubectl 로 리소스 생성·삭제·변경. k3s-uninstall.sh 실행(그 스크립트는 /etc/rancher/k3s 를 통째로 지운다 — 토큰과 config.yaml 까지 사라지므로
#   재부트스트랩은 위 절차 1단계(토큰 배치)부터 다시 해야 한다).
set -euo pipefail

# ---------- 상수 ----------
K3S_TOKEN_FILE="${K3S_TOKEN_FILE:-/etc/rancher/k3s/token}"
NODE_PRIVATE_IP="${NODE_PRIVATE_IP:-10.0.7.78}"
K3S_VERSION="${K3S_VERSION:-v1.36.4+k3s1}"
TLS_SAN_HOST="${TLS_SAN_HOST:-k8s.joshuatech.dev}"
INSTALL_SCRIPT="${INSTALL_SCRIPT:-/tmp/install-k3s.sh}"
K3S_RESOLV_NAMESERVERS="${K3S_RESOLV_NAMESERVERS:-1.1.1.1 8.8.8.8}"
K3S_CONFIG_DIR=/etc/rancher/k3s
K3S_CONFIG="$K3S_CONFIG_DIR/config.yaml"
K3S_RESOLV_CONF="$K3S_CONFIG_DIR/resolv.conf"
K3S_UNIT=/etc/systemd/system/k3s.service
RULES_V4=/etc/iptables/rules.v4
WG_MODULES_CONF=/etc/modules-load.d/wireguard.conf
TZ_WANT=Asia/Seoul
READY_TIMEOUT=180   # 초. 노드 Ready 대기 상한(5 s 간격)

CHANGES=()
RESOLV_NS=()   # preflight 가 K3S_RESOLV_NAMESERVERS 를 검증해 채운다(render_resolv_conf 의 입력)
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

# 파드 DNS 업스트림으로 쓸 수 있는 주소인가(머리 주석 "파드 DNS"). IPv4 점 표기 + 전역 유니캐스트만 통과시킨다:
# 0/8·루프백 127/8·사설 10/8·172.16/12·192.168/16·링크로컬 169.254/16(OCI VCN 리졸버·IMDS)·멀티캐스트 이상 224+ 는 거부.
# K3s 의 isValidNameserver 와 달리 IMDS 예외를 두지 않는다 — 그 예외가 지금 이 전환의 원인이다(deny-imds 가 그 주소를 막는다).
is_public_nameserver() {
  local ip=$1 a b o
  [[ "$ip" =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]] || return 1
  # BASH_REMATCH 는 다음 [[ =~ ]] 마다 덮어써지므로(실패하면 비어 버린다) 옥텟을 먼저 배열로 옮긴다
  local -a oct=("${BASH_REMATCH[@]:1}")
  # 옥텟은 0-255, 선행 0 금지("010" 을 8진수로 읽는 리졸버 구현이 있다)
  for o in "${oct[@]}"; do
    case "$o" in 0?*) return 1 ;; esac
    [ "$((10#$o))" -le 255 ] || return 1
  done
  a=$((10#${oct[0]}))
  b=$((10#${oct[1]}))
  case "$a" in
    0 | 10 | 127) return 1 ;;
    169) [ "$b" -ne 254 ] || return 1 ;;
    172) { [ "$b" -lt 16 ] || [ "$b" -gt 31 ]; } || return 1 ;;
    192) [ "$b" -ne 168 ] || return 1 ;;
  esac
  [ "$a" -lt 224 ] || return 1
  return 0
}

# 설치된 k3s 버전(k3s --version 첫 줄 "k3s version vX.Y.Z+k3sN (hash)"). 바이너리가 없으면 빈 문자열.
installed_k3s_version() {
  command -v k3s >/dev/null 2>&1 || return 0
  k3s --version 2>/dev/null | awk 'NR == 1 && $1 == "k3s" && $2 == "version" { print $3 }'
}

# ---------- 0. 사전 확인 ----------
preflight() {
  local addrs ns
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
  # 파드 DNS 업스트림(머리 주석 "파드 DNS"): 공백 구분 목록 → 배열. 비었거나 공개 주소가 아니면 중단한다.
  read -r -a RESOLV_NS <<< "$K3S_RESOLV_NAMESERVERS"
  [ "${#RESOLV_NS[@]}" -ge 1 ] || die "K3S_RESOLV_NAMESERVERS 가 비어 있다 — 공개 리졸버를 최소 하나 지정해야 한다(기본 '1.1.1.1 8.8.8.8')"
  for ns in "${RESOLV_NS[@]}"; do
    is_public_nameserver "$ns" || die "K3S_RESOLV_NAMESERVERS 항목 '$ns' 가 공개 리졸버가 아니다 — 루프백·링크로컬(169.254/16: OCI VCN 리졸버·IMDS)·사설(10/8·172.16/12·192.168/16)·멀티캐스트는 파드 업스트림으로 쓸 수 없다(kube-system deny-imds 가 IMDS egress 를 막아 클러스터 이름 해석이 끊긴다)"
  done
  # 노드 A 전용 가드: IMDS 대신 로컬 인터페이스에서 확인한다(변수로 받아 herestring 으로 검사 — pipefail 하 grep -q 조기 종료 SIGPIPE 회피)
  addrs=$(ip -4 -o addr show scope global | awk '{ split($4, a, "/"); print a[1] }')
  grep -qxF -- "$NODE_PRIVATE_IP" <<< "$addrs" || die "NODE_PRIVATE_IP $NODE_PRIVATE_IP 가 이 호스트의 인터페이스에 없다(있는 IP: $(tr '\n' ' ' <<< "$addrs")) — 노드 A 전용 스크립트다"
  log "preflight OK: $(hostname) ubuntu=$VERSION_ID arch=$(uname -m) kernel=$(uname -r) ip=$NODE_PRIVATE_IP k3s=$K3S_VERSION san=$TLS_SAN_HOST resolv=[${RESOLV_NS[*]}]"
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

# ---------- 3. resolv.conf(파드 DNS 업스트림) ----------
# config.yaml 의 resolv-conf 가 가리키는 파일. kubelet 이 dnsPolicy: Default 파드(번들 CoreDNS)에 그대로 물려주므로 config.yaml 보다 먼저 렌더한다.
# 0644: 비밀이 없고 kubelet·컨테이너 런타임이 읽는다(config.yaml 0600 과 다른 이유). nameserver 줄만 — search·options 는 두지 않는다(머리 주석).
render_resolv_conf() {
  local content ns before
  [ "${#RESOLV_NS[@]}" -ge 1 ] || die "RESOLV_NS 가 비어 있다 — preflight 가 먼저 돌아야 한다"
  content="# $K3S_RESOLV_CONF — managed by infra/bootstrap/k3s-server.sh. Edit the script, not this file."
  content+=$'\n'"# Kubelet --resolv-conf (config.yaml key resolv-conf): upstream for pods with dnsPolicy: Default (bundled CoreDNS)."
  content+=$'\n'"# Public resolvers only. The OCI VCN resolver is the IMDS address, which kube-system/deny-imds blocks (T041)."
  content+=$'\n'"# The node's own resolution (systemd-resolved) is untouched. No search domain: pods use service DNS or public FQDNs."
  for ns in "${RESOLV_NS[@]}"; do content+=$'\n'"nameserver $ns"; done
  before=${#CHANGES[@]}
  write_if_changed "$K3S_RESOLV_CONF" "$content" 644
  [ "${#CHANGES[@]}" -eq "$before" ] || CONFIG_CHANGED=1
}

# ---------- 4. config.yaml ----------
# 모든 서버 플래그는 이 파일 한 곳(K3S-D1). 항목은 tasks T035 문면 + research K3S-D2·D3·D4·D5 결정에 있는 것만:
#   외부 IP 지정 없음(K3S-D3: OCI 공인 IP 는 NAT — ServiceLB externalTrafficPolicy=Local 오동작 경고), 번들 컴포넌트 끄기 없음(K3S-D3),
#   cluster-cidr/service-cidr 미지정 = K3s 기본 10.42.0.0/16·10.43.0.0/16(host-prep.sh 의 iptables 규칙과 같은 값).
#   resolv-conf 는 T035 문면 밖의 후속 추가다(사용자 결정 2026-09-08 옵션 B — 머리 주석 "파드 DNS"; T041 PR-B2 선행 게이트).
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
resolv-conf: $K3S_RESOLV_CONF
EOF
)
  local before=${#CHANGES[@]}
  write_if_changed "$K3S_CONFIG" "$content" 600
  [ "${#CHANGES[@]}" -eq "$before" ] || CONFIG_CHANGED=1
}

# ---------- 5. 설치 ----------
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
    die "설치된 k3s $have ≠ 요구 $K3S_VERSION — 이 스크립트는 버전을 바꾸지 않는다(패치 승격은 system-upgrade-controller Plan 몫, 다운그레이드 불가). 설치는 그대로 두고 config·상태만 재검증하려면 K3S_VERSION=$have 로 다시 실행한다"
  fi
  if [ "$have" = "$K3S_VERSION" ] && [ -f "$K3S_UNIT" ]; then
    log "k3s $have already installed ($K3S_UNIT present) — installer skipped"
    return 0
  fi
  check_install_script
  # env -i: install.sh 는 K3S_* 를 k3s.service.env 에 기록하므로 이 셸의 K3S_TOKEN_FILE/K3S_VERSION 을 넘기지 않는다. 플래그는 config.yaml 에만(K3S-D1).
  # INSTALL_K3S_EXEC=server 뿐 — CLI 인자 없음. 바이너리 sha256 은 install.sh 의 verify_binary 가 릴리스 자산과 대조한다.
  log "installing k3s $K3S_VERSION (server) from $INSTALL_SCRIPT"
  env -i PATH="$PATH" HOME=/root INSTALL_K3S_VERSION="$K3S_VERSION" INSTALL_K3S_EXEC=server sh "$INSTALL_SCRIPT" || die "install.sh 실패(exit $?) — 위 [ERROR] 참조"
  have=$(installed_k3s_version)
  [ "$have" = "$K3S_VERSION" ] || die "설치 뒤 버전 불일치: got '$have' want '$K3S_VERSION'"
  [ -f "$K3S_UNIT" ] || die "설치 뒤에도 $K3S_UNIT 이 없다"
  INSTALLED_THIS_RUN=1
  mark_changed "k3s $K3S_VERSION installed (server)"
}

# ---------- 6. 서비스 상태 ----------
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
    warn "$K3S_CONFIG 또는 $K3S_RESOLV_CONF 가 바뀌었지만 실행 중인 k3s 는 건드리지 않는다 — 반영(k3s.service 재시작)은 운영자 판단(node-label 은 등록 시 1회만 적용, secrets-encryption 변경은 rotate 절차, resolv-conf 는 재시작 뒤 CoreDNS rollout restart 까지 필요: docs/runbooks/bootstrap.md §3 '파드 DNS 업스트림 전환')"
  fi
}

# ---------- 7. 노드 Ready 대기 ----------
wait_node_ready() {
  local i out ready=0
  for ((i = 0; i < READY_TIMEOUT / 5; i++)); do
    out=$(k3s kubectl get nodes --no-headers 2>/dev/null || true)
    # STATUS 열은 Ready / Ready,SchedulingDisabled(cordon) / NotReady 등 — 쉼표 앞부분이 Ready 면 Ready 로 센다
    if awk '$2 ~ /^Ready(,|$)/ { f = 1 } END { exit !f }' <<< "$out"; then ready=1; break; fi
    sleep 5
  done
  [ "$ready" = 1 ] || die "노드가 ${READY_TIMEOUT}s 안에 Ready 가 아니다 — journalctl -u k3s -n 100 / k3s kubectl get nodes"
  READY_NODES=$(awk '$2 ~ /^Ready(,|$)/' <<< "$out" | grep -c . || true)
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
  # v1.36 의 status 는 키 타입을 XSalsa20-POLY1305(= secretbox 의 알고리즘)로 표기한다 — 두 표기 모두 허용한다
  grep -qiE 'XSalsa20|secretbox' <<< "$st" || warn "secrets-encrypt status 에 secretbox/XSalsa20 표기가 없다 — provider 확인(K3S-D2)"
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
  printf 'resolv-conf: %s mode=%s nameservers=[%s] (pods only; node resolver untouched)\n' "$K3S_RESOLV_CONF" "$(stat -c %a "$K3S_RESOLV_CONF")" "${RESOLV_NS[*]}"
  printf 'node: Ready=%s  labels(role=platform,enablelb)=%s  tls-san=%s,%s\n' "$READY_NODES" "$LABELED_NODES" "$NODE_PRIVATE_IP" "$TLS_SAN_HOST"
  printf 'secrets-encrypt: %s\n' "$SE_STATUS"
  printf 'flannel-wg iface: %s  token-file: %s (mode %s, contents never printed)\n' "$(ip link show flannel-wg >/dev/null 2>&1 && printf present || printf absent)" "$K3S_TOKEN_FILE" "$(stat -c %a "$K3S_TOKEN_FILE")"
  printf '==== end ====\n'
}

main() {
  preflight
  check_host_prep
  check_token_file
  render_resolv_conf
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
