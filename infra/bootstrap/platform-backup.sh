#!/usr/bin/env bash
# infra/bootstrap/platform-backup.sh — 노드 A /usr/local/bin/platform-backup.sh: K3s SQLite 번들 + Vault Raft 스냅샷 → age → OCI Object Storage
#   (joshuatech-backup-platform) — 003-platform-foundation T036, FR-047. 정적 계약은 tests/infra/platform-backup.tests.ps1 이 고정한다.
#
# 실행 주체: (a) platform-backup.timer(매일 02:30 KST, platform-backup.service oneshot) (b) system-upgrade-controller k3s-server Plan 의 prepare 컨테이너가
#   `chroot /host /usr/local/bin/platform-backup.sh --pre-upgrade`(T037 — 성공한 뒤에만 업그레이드) (c) 운영자 수동. 항상 root, 노드 A 전용
#   (동적 그룹 joshuatech-node-a 의 instance principal 만 버킷에 OBJECT_CREATE·OBJECT_INSPECT 를 갖는다 — iam.tf; 삭제·읽기 권한 없음, 보존은 버킷 lifecycle
#   k3s/ 7일·vault/ 30일 — storage.tf).
# 멱등(.claude/rules/infra.md): 재실행은 새 타임스탬프의 오브젝트를 하나 더 만들 뿐 오류·중복 상태가 없다. 동시 실행은 flock 으로 한 번에 하나만.
#
# 컴포넌트(BACKUP_COMPONENTS 기본 k3s,vault; --components 로 덮어쓴다; --pre-upgrade 는 k3s 필수 + vault 는 "배포돼 있으면 필수" — 아래 게이트 절):
#   k3s   : sqlite3 ".backup" 온라인 스냅샷(kine SQLite 는 WAL — 파일 복사는 -wal 누락 위험, K3S-D9) + PRAGMA integrity_check=ok 확인 + server/token(bootstrap 데이터
#           PBKDF2 키 — 없으면 복원 불가) + server/cred/(encryption-config.json 등) + server/tls/(없이 복원하면 인증서가 재생성되어 노드 B 재조인이 깨진다 — rollback.md)
#           → tar(0600) → age -r <공개키> → k3s/k3s-<UTC ts>.tar.age.
#           **번들 레이아웃**: 구성원은 `server/` 접두를 그대로 쓴다(server/db/state.db, server/token, server/cred/, server/tls/) — 복원은 경로 이동 없이
#           `tar -C /var/lib/rancher/k3s -xf k3s-<ts>.tar` 한 번이면 되고, plan.md·T106 rollback.md 가 말하는 경로와 문자 그대로 같다(평면 이름 + mv 는 사고를 부른다).
#           복원 순서: k3s 정지 → 위 tar 전개 → 같은 token·tls 유지 → 기동(docs/runbooks/rollback.md).
#           GNU cp 는 항목별 오류에서 나머지를 계속 복사하고 마지막에만 non-zero 를 낸다 — 그래서 tar 뒤에 원본 cred+tls 파일 수와 번들 항목 수를 대조한다
#           (빈 cred/·tls/ 가 든 "정상" 번들이 업로드되는 것을 막는 유일한 방어선).
#   vault : k3s kubectl -n vault create token vault-backup --audience vault --duration=10m(role vault-backup 의 audiences: [vault] 와 일치 — T044) → 백그라운드
#           kubectl port-forward svc/vault <빈 로컬 포트>:8200(공개 호스트 = Vault Ingress 도메인·pod IP 직접 접근 금지 — .claude/rules/infra.md, contracts/network-policy.md
#           allow-apiserver-webhook 의 vault 8200 행) → VAULT_ADDR=<scheme>://127.0.0.1:<port> → vault write auth/kubernetes/login role=vault-backup(JWT 는 stdin 파이프,
#           명령줄·디스크에 두지 않는다) → vault operator raft snapshot save → age → vault/vault-<UTC ts>.snap.age → 토큰 revoke-self → port-forward 종료.
#           스냅샷은 seal 래핑이라 복원에는 같은 KMS 키가 필요하다(docs/runbooks/vault-unseal.md).
# 성공 시 컴포넌트별로 /var/lib/node_exporter/textfile_collector/platform_backup_<component>.prom 에
#   platform_backup_last_success_timestamp{component="<c>"} <unix> 를 임시 파일 + mv 로 원자적으로 쓴다(둘 중 하나만 실패해도 PlatformBackupStale 이 그 컴포넌트만 잡는다).
#   이 기록이 실패하면(디렉터리 부재·읽기 전용·ENOSPC) 업로드가 됐더라도 그 컴포넌트를 FAIL 로 보고한다 — 감시할 수 없는 백업은 성공이 아니다.
# 어느 하나가 실패해도 나머지 컴포넌트는 계속 시도하고, 하나라도 실패면 exit 1(--pre-upgrade 에서는 이 exit≠0 이 SUC prepare 를 막아 업그레이드가 시작되지 않는다).
#
# **errexit 주의(이 파일의 안전 규칙)**: main 은 컴포넌트를 `backup_k3s || true` 로 부른다 — `||` 목록에 들어간 명령은 그 **동적 범위 전체**에서 set -e 가 꺼진다
#   (중첩 함수 안까지). 그래서 backup_* 와 그들이 부르는 함수 안에서는 errexit 에 절대 기대지 않고, 실패할 수 있는 모든 명령에 `|| { fail_component …; return 1; }`
#   또는 `|| return 1` 을 붙인다. 이 규칙이 깨지면 cp/textfile 실패가 조용히 RESULT=OK·exit 0 으로 보고된다(실측 확인).
#
# **--pre-upgrade 게이트 범위(설계 결정)**: k3s 번들은 **항상 필수**다. Vault 는 **배포돼 있을 때만 필수**로 한다(`kubectl -n vault get svc vault` 로 탐지).
#   이유: T044(Vault 배포) 이전에는 vault ns/Service 가 없어 vault 를 무조건 강제하면 T037 SUC prepare 가 항상 exit 1 이 되어 **K3s 자동 업그레이드가 구조적으로 막힌다**.
#   게이트를 약화시키지 않는 근거: 없을 때만(그리고 WARN 을 남기고) 건너뛰며, **존재하는데 실패하면 그대로 exit 1** 이다 — 지킬 수 있는 보호는 전부 지킨다.
#   또 --pre-upgrade 는 --components 와 병용을 거부한다(인자로 게이트 범위를 좁히지 못하게).
#
# 입력(환경 변수 — 전부 선택; 자격은 instance principal 뿐이며 어떤 자격도 파일·환경에 두지 않는다):
#   BACKUP_COMPONENTS   기본 k3s,vault. T044(Vault) 전에는 /etc/platform-backup/env 에 BACKUP_COMPONENTS=k3s 를 두면 timer 도 k3s 만 백업한다(service 의 EnvironmentFile=-).
#   AGE_RECIPIENT_FILE  기본 /etc/platform-backup/age-recipient — 운영자 age 공개키(age1…) 한 줄. 노드에는 공개키만; 개인키는 오프라인(§0 키쌍, recovery key 와 같은 곳).
#                       없으면 중단(암호화 없는 업로드는 없다).
#   OCI_BUCKET          기본 joshuatech-backup-platform(이름 예외: 설계 표기 jt-backup-platform).   OCI_NAMESPACE  기본 axvjykgvo2m1(테넌시 Object Storage 네임스페이스, storage.tf).
#   VAULT_ADDR_SCHEME   기본 http — helm 차트 기본(global.tlsDisable=true, Ingress 가 TLS 종단)에 맞춘 가정이며 T044 가 리스너를 TLS 로 확정하면 https 로 바꾸고
#   VAULT_CACERT        (그때) CA 파일 경로를 준다. 두 값은 /etc/platform-backup/env 로 timer 에도 전달된다.
#
# 운영자 절차(워크스테이션 PowerShell 7; ssh/scp 공통 옵션 -i ~/.ssh/joshuatech-ops -o IdentitiesOnly=yes 는 "…" 로 줄인다; 노드 A 144.24.85.118):
#   1. age 공개키 배치(§0 에서 만든 키쌍 joshuatech-age.key 의 공개키만 — 개인키 파일은 워크스테이션 오프라인 보관 위치를 벗어나지 않는다):
#        $pub = (age-keygen -y "<오프라인 보관 경로>\joshuatech-age.key").Trim()      # age1… 62자; 키 파일 머리의 "# public key:" 줄과 같다
#        [IO.File]::WriteAllText("$env:TEMP\age-recipient", $pub + "`n")
#        scp … "$env:TEMP\age-recipient" ubuntu@144.24.85.118:/home/ubuntu/age-recipient
#        ssh … ubuntu@144.24.85.118 "sudo install -d -m 755 -o root -g root /etc/platform-backup && sudo install -m 644 -o root -g root /home/ubuntu/age-recipient /etc/platform-backup/age-recipient && rm -f /home/ubuntu/age-recipient"
#        Remove-Item "$env:TEMP\age-recipient"; Remove-Variable pub
#   2. 스크립트·unit 설치(재실행해도 같은 결과):
#        scp … infra/bootstrap/platform-backup.sh infra/bootstrap/platform-backup.service infra/bootstrap/platform-backup.timer ubuntu@144.24.85.118:/home/ubuntu/
#        ssh … ubuntu@144.24.85.118 "sudo install -m 755 -o root -g root /home/ubuntu/platform-backup.sh /usr/local/bin/platform-backup.sh && sudo install -m 644 -o root -g root /home/ubuntu/platform-backup.service /home/ubuntu/platform-backup.timer /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl enable --now platform-backup.timer && rm -f /home/ubuntu/platform-backup.sh /home/ubuntu/platform-backup.service /home/ubuntu/platform-backup.timer"
#      T044 전(Vault 없음)에는 timer 가 k3s 만 백업하도록: ssh … "printf 'BACKUP_COMPONENTS=k3s\n' | sudo install -m 644 -o root -g root /dev/stdin /etc/platform-backup/env"
#      T044 뒤에는 그 파일을 지운다(sudo rm /etc/platform-backup/env) — 기본 k3s,vault 로 돌아간다.
#   3. 첫 실행(수동 2회 — 2회차도 exit 0 이고 새 오브젝트가 하나씩 더 생기면 멱등): ssh … "sudo /usr/local/bin/platform-backup.sh --components k3s"(T044 전) /
#      ssh … "sudo /usr/local/bin/platform-backup.sh"(T044 뒤) / ssh … "sudo /usr/local/bin/platform-backup.sh --pre-upgrade"(T037 prepare 와 같은 경로 리허설).
#   4. 확인: ssh … "systemctl list-timers platform-backup.timer --no-pager; systemd-analyze calendar '*-*-* 02:30:00 Asia/Seoul'; cat /var/lib/node_exporter/textfile_collector/platform_backup_k3s.prom"
#      워크스테이션(svc-verify 세션): oci --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup-platform --prefix k3s/ (vault/ 도)
#   5. 복원 가능성 검증은 T048(오브젝트 get → age -d -i <개인키> → sqlite3 'PRAGMA integrity_check' / vault operator raft snapshot inspect) — 이 스크립트의 일이 아니다.
#
# 절대 하지 않는 것: 비밀(SA JWT·Vault 토큰·server/token 내용·평문 스냅샷) 출력·로그, vault login(~/.vault-token 잔존), 공개 호스트/pod IP 로 Vault 접근,
#   instance principal 이외의 OCI 자격(정적 API 키·세션 토큰·홈 디렉터리 설정 파일), 오브젝트 삭제·목록·다운로드, kubectl 로 리소스 생성·삭제·변경(create token 은
#   TokenRequest — 리소스를 만들지 않는다), k3s/vault 재시작, age -d(복호화는 운영자 워크스테이션).
set -euo pipefail
umask 077
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin   # SUC prepare 의 chroot /host 에서는 PATH 가 비어 있을 수 있다
export HOME="${HOME:-/root}"

# ---------- 상수 ----------
BACKUP_COMPONENTS="${BACKUP_COMPONENTS:-k3s,vault}"
AGE_RECIPIENT_FILE="${AGE_RECIPIENT_FILE:-/etc/platform-backup/age-recipient}"
OCI_BUCKET="${OCI_BUCKET:-joshuatech-backup-platform}"
OCI_NAMESPACE="${OCI_NAMESPACE:-axvjykgvo2m1}"
OCI_BIN=/usr/local/bin/oci                     # host-prep.sh 가 pipx 로 둔 경로(T014) — PATH 탐색에 맡기지 않는다
VAULT_ADDR_SCHEME="${VAULT_ADDR_SCHEME:-http}"
VAULT_CACERT="${VAULT_CACERT:-}"
K3S_SERVER_DIR=/var/lib/rancher/k3s/server
K3S_STATE_DB="$K3S_SERVER_DIR/db/state.db"
VAULT_NAMESPACE=vault
VAULT_SA=vault-backup
VAULT_ROLE=vault-backup
VAULT_SERVICE=vault
TEXTFILE_DIR=/var/lib/node_exporter/textfile_collector
LOCK_FILE=/run/lock/platform-backup.lock
WORK_PARENT=/var/tmp
PF_TIMEOUT=30          # 초. port-forward 준비 대기 상한. 한 바퀴 ≈ 3 s(curl --max-time 2 + sleep 1)이므로 반복은 PF_TIMEOUT/3 회다.
PF_PORT_RANGE_START=18200
PF_PORT_RANGE_END=18299
KUBECTL=(k3s kubectl)  # 노드 A 의 admin kubeconfig(/etc/rancher/k3s/k3s.yaml, root 0600)를 k3s 가 스스로 읽는다 — 이 스크립트는 kubeconfig 경로를 다루지 않는다

PRE_UPGRADE=0
COMPONENTS_ARG=""
TS=""
WORKDIR=""
PF_ERR=""              # $WORKDIR/pf.err — kubectl port-forward stderr(진단용, 자격 아님)
VAULT_ERR=""           # $WORKDIR/vault.err — vault status stderr
PF_PID=""
AGE_RECIPIENT=""
declare -A RESULT=()      # component -> OK|FAIL
declare -A OBJECT=()      # component -> object name
declare -A BYTES=()       # component -> encrypted size
declare -A REASON=()      # component -> failure reason (never a secret)

log()  { printf '[platform-backup] %s\n' "$*"; }
warn() { printf '[platform-backup] WARN: %s\n' "$*" >&2; }
err()  { printf '[platform-backup] ERROR: %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

usage() {
  cat <<'EOF'
usage: platform-backup.sh [--components k3s,vault] [--pre-upgrade]
  --components <list>  comma-separated subset of k3s,vault (overrides BACKUP_COMPONENTS; default k3s,vault)
  --pre-upgrade        SUC k3s-server Plan prepare gate: both components are mandatory, any failure exits non-zero
EOF
}

# ---------- 종료 정리(성공·실패·중단 모두) ----------
# shellcheck disable=SC2329  # trap 으로만 호출된다(아래 trap cleanup EXIT) — shellcheck 는 간접 호출을 보지 못한다
cleanup() {
  if [ -n "$PF_PID" ] && kill -0 "$PF_PID" 2>/dev/null; then
    kill "$PF_PID" 2>/dev/null || true
    wait "$PF_PID" 2>/dev/null || true
  fi
  PF_PID=""
  if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
    find "$WORKDIR" -type f -exec shred -u -- {} + 2>/dev/null || true   # 평문 sqlite·token·tls·스냅샷은 디스크에 남기지 않는다
    rm -rf -- "$WORKDIR"
  fi
}
trap cleanup EXIT

# ---------- 인자 ----------
parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --pre-upgrade) PRE_UPGRADE=1 ;;
      --components) [ $# -ge 2 ] || die "--components 에 값이 없다"; COMPONENTS_ARG=$2; shift ;;
      --components=*) COMPONENTS_ARG=${1#--components=} ;;
      -h|--help) usage; exit 0 ;;
      *) usage >&2; die "알 수 없는 인자: $1" ;;
    esac
    shift
  done
  if [ "$PRE_UPGRADE" = 1 ]; then
    [ -z "$COMPONENTS_ARG" ] || die "--pre-upgrade 는 --components 와 함께 쓸 수 없다(인자로 게이트 범위를 좁힐 수 없다)"
    BACKUP_COMPONENTS=k3s   # vault 는 preflight 에서 배포 여부를 탐지해 덧붙인다(pre_upgrade_components)
  elif [ -n "$COMPONENTS_ARG" ]; then
    BACKUP_COMPONENTS=$COMPONENTS_ARG
  fi
  local c
  for c in ${BACKUP_COMPONENTS//,/ }; do
    case "$c" in k3s|vault) ;; *) die "알 수 없는 컴포넌트 '$c' (허용: k3s, vault)" ;; esac
  done
  [ -n "${BACKUP_COMPONENTS//,/}" ] || die "컴포넌트가 비어 있다"
}

# Vault 가 이 클러스터에 배포돼 있는가(읽기 전용 조회 — 리소스를 만들지 않는다).
vault_deployed() {
  "${KUBECTL[@]}" -n "$VAULT_NAMESPACE" get svc "$VAULT_SERVICE" >/dev/null 2>&1
}

# --pre-upgrade 의 컴포넌트 확정: k3s 는 항상, vault 는 배포돼 있을 때만(헤더 "게이트 범위" 절의 근거).
pre_upgrade_components() {
  command -v k3s >/dev/null 2>&1 || die "k3s 가 없다 — --pre-upgrade 는 노드 A(server)에서만 실행한다"
  if vault_deployed; then
    BACKUP_COMPONENTS=k3s,vault
    log "pre-upgrade: vault Service 감지 — k3s,vault 둘 다 필수(하나라도 실패하면 업그레이드를 막는다)"
  else
    BACKUP_COMPONENTS=k3s
    warn "vault 미배포(ns $VAULT_NAMESPACE 에 svc $VAULT_SERVICE 없음) — 이번 pre-upgrade 에서 건너뜀(T044 이후에는 필수)"
  fi
}

# ---------- 0. 사전 확인 ----------
preflight() {
  local t
  [ "$(id -u)" -eq 0 ] || die "root 로 실행해야 한다(sudo / systemd / SUC chroot)"
  for t in sqlite3 age tar flock shred; do command -v "$t" >/dev/null 2>&1 || die "$t 가 없다 — host-prep.sh(T014) 패키지 확인"; done
  [ -x "$OCI_BIN" ] || die "$OCI_BIN 이 없다 — host-prep.sh(platform) 의 pipx oci-cli 확인"
  [ -f "$AGE_RECIPIENT_FILE" ] || die "age 공개키 파일 $AGE_RECIPIENT_FILE 이 없다 — 운영자 절차 1(공개키만 노드에 둔다; 암호화 없는 업로드는 하지 않는다)"
  AGE_RECIPIENT=$(head -n 1 "$AGE_RECIPIENT_FILE" | tr -d '[:space:]')
  [[ "$AGE_RECIPIENT" =~ ^age1[a-z0-9]{58}$ ]] || die "$AGE_RECIPIENT_FILE 의 첫 줄이 age 공개키(age1 + 58자) 형식이 아니다 — age-keygen -y 출력을 그대로 둔다(개인키 AGE-SECRET-KEY 는 절대 노드에 두지 않는다)"
  ! grep -q 'AGE-SECRET-KEY' "$AGE_RECIPIENT_FILE" || die "$AGE_RECIPIENT_FILE 에 개인키가 들어 있다 — 즉시 shred 하고 공개키만 다시 배치한다"
  [ "$PRE_UPGRADE" != 1 ] || pre_upgrade_components   # vault 도구 검사보다 앞: 게이트 범위가 여기서 확정된다
  case ",$BACKUP_COMPONENTS," in
    *,vault,*) for t in vault k3s curl ss; do command -v "$t" >/dev/null 2>&1 || die "$t 가 없다(vault 컴포넌트에 필요) — host-prep.sh(platform) 확인"; done ;;
  esac
  mkdir -p "$(dirname "$LOCK_FILE")"
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "다른 platform-backup 실행이 진행 중이다($LOCK_FILE) — timer 와 --pre-upgrade 가 겹쳤는지 확인"
  TS=$(date -u +%Y%m%dT%H%M%SZ)
  WORKDIR=$(mktemp -d -p "$WORK_PARENT" platform-backup.XXXXXX)   # 0700 — 평문은 이 안에서만, EXIT trap 이 shred 한다
  PF_ERR="$WORKDIR/pf.err"
  VAULT_ERR="$WORKDIR/vault.err"
  log "preflight OK: $(hostname) ts=$TS components=$BACKUP_COMPONENTS mode=$([ "$PRE_UPGRADE" = 1 ] && printf pre-upgrade || printf normal) recipient=${AGE_RECIPIENT:0:10}… workdir=$WORKDIR"
}

# ---------- 공통: 암호화·업로드·지표 ----------
# $1 평문, $2 출력(.age). 성공하면 평문은 즉시 shred.
encrypt_file() {
  local plain=$1 enc=$2
  age -r "$AGE_RECIPIENT" -o "$enc" "$plain" || return 1
  chmod 600 "$enc"
  shred -u -- "$plain"
}

# $1 파일, $2 오브젝트 이름. instance principal 뿐(OBJECT_CREATE); 도착 확인은 head(OBJECT_INSPECT). 출력은 버린다(etag 등 불필요).
upload_object() {
  local file=$1 name=$2
  "$OCI_BIN" os object put --auth instance_principal --namespace "$OCI_NAMESPACE" --bucket-name "$OCI_BUCKET" \
    --name "$name" --file "$file" --content-type application/octet-stream --force >/dev/null || return 1
  "$OCI_BIN" os object head --auth instance_principal --namespace "$OCI_NAMESPACE" --bucket-name "$OCI_BUCKET" --name "$name" >/dev/null || return 1
}

# $1 component, $2 unix time. 임시 파일(.prom 아님 — node_exporter 는 *.prom 만 읽는다) + mv 원자 교체, 0644.
# errexit 은 여기서 꺼져 있다(헤더 errexit 주의) — 모든 단계에 명시적 실패 반환을 붙인다.
write_textfile() {
  local component=$1 now=$2 tmp
  # 두 번째 local: bash 는 local 한 줄의 모든 단어를 builtin 실행 전에 확장하므로, 같은 줄에서 방금 선언한 $component 는 아직 보이지 않는다
  # (호출자의 동명 변수가 우연히 보일 뿐 — SC2318). 컴포넌트별 파일 이름이 조용히 비는 것을 막으려고 줄을 나눈다.
  local file="$TEXTFILE_DIR/platform_backup_$component.prom"
  install -d -m 755 "$TEXTFILE_DIR" || return 1
  tmp=$(mktemp -p "$TEXTFILE_DIR" ".platform_backup_$component.XXXXXX") || return 1
  printf '# HELP platform_backup_last_success_timestamp Unix time of the last successful platform backup upload, per component.\n# TYPE platform_backup_last_success_timestamp gauge\nplatform_backup_last_success_timestamp{component="%s"} %s\n' "$component" "$now" > "$tmp" || { rm -f -- "$tmp"; return 1; }
  chmod 644 "$tmp" || { rm -f -- "$tmp"; return 1; }
  mv -f "$tmp" "$file" || { rm -f -- "$tmp"; return 1; }
}

# $1 component, $2 object, $3 encrypted file. 지표 기록까지 성공해야 OK 다(감시할 수 없는 백업은 성공이 아니다).
finish_component() {
  local component=$1 obj=$2 enc=$3 now size
  size=$(stat -c %s "$enc") || { fail_component "$component" "업로드본 크기 조회 실패: $enc"; return 1; }
  now=$(date -u +%s) || { fail_component "$component" "시각 조회 실패"; return 1; }
  write_textfile "$component" "$now" || { fail_component "$component" "textfile 지표 기록 실패($TEXTFILE_DIR) — 업로드는 됐지만 신선도 감시(PlatformBackupStale)가 불가능하다"; return 1; }
  BYTES[$component]=$size
  OBJECT[$component]=$obj
  RESULT[$component]=OK
  log "$component: OK object=$obj bytes=${BYTES[$component]} textfile=$TEXTFILE_DIR/platform_backup_$component.prom"
}

fail_component() {
  local component=$1 reason=$2
  RESULT[$component]=FAIL
  REASON[$component]=$reason
  err "$component: FAIL — $reason"
}

# ---------- 1. K3s 번들 ----------
backup_k3s() {
  local dir="$WORKDIR/k3s" tar="$WORKDIR/k3s-$TS.tar" enc="$WORKDIR/k3s-$TS.tar.age" obj="k3s/k3s-$TS.tar.age" check src dst
  [ -f "$K3S_STATE_DB" ] || { fail_component k3s "$K3S_STATE_DB 가 없다(SQLite 데이터스토어가 아니거나 노드 A 가 아니다)"; return 1; }
  [ -f "$K3S_SERVER_DIR/token" ] || { fail_component k3s "$K3S_SERVER_DIR/token 이 없다(없으면 복원 불가)"; return 1; }
  [ -d "$K3S_SERVER_DIR/cred" ] || { fail_component k3s "$K3S_SERVER_DIR/cred 가 없다"; return 1; }
  [ -d "$K3S_SERVER_DIR/tls" ] || { fail_component k3s "$K3S_SERVER_DIR/tls 가 없다(없으면 복원 시 인증서 재생성 → 노드 B 재조인 깨짐)"; return 1; }
  # 번들 안 경로는 복원 경로와 같게 server/ 접두를 쓴다(헤더 "번들 레이아웃").
  install -d -m 700 "$dir/server/db" || { fail_component k3s "작업 디렉터리 생성 실패: $dir/server/db"; return 1; }
  sqlite3 "$K3S_STATE_DB" ".backup '$dir/server/db/state.db'" || { fail_component k3s "sqlite3 .backup 실패"; return 1; }
  check=$(sqlite3 "$dir/server/db/state.db" 'PRAGMA integrity_check' 2>/dev/null || true)
  [ "$check" = ok ] || { fail_component k3s "스냅샷 PRAGMA integrity_check ≠ ok (got '${check:-<없음>}')"; return 1; }
  cp -p -- "$K3S_SERVER_DIR/token" "$dir/server/token" || { fail_component k3s "server/token 복사 실패"; return 1; }
  cp -rp -- "$K3S_SERVER_DIR/cred" "$dir/server/cred" || { fail_component k3s "server/cred/ 복사 실패"; return 1; }
  cp -rp -- "$K3S_SERVER_DIR/tls" "$dir/server/tls" || { fail_component k3s "server/tls/ 복사 실패"; return 1; }
  tar -C "$dir" --owner=0 --group=0 -cf "$tar" server || { fail_component k3s "tar 실패"; return 1; }
  chmod 600 "$tar" || { fail_component k3s "tar 권한 설정 실패: $tar"; return 1; }
  # GNU cp 는 항목별 오류 뒤에도 나머지를 계속 복사한다 — 원본 파일 수와 번들 항목 수를 대조해 "빈 cred/·tls/ 가 든 정상 번들"을 막는다.
  src=$(find "$K3S_SERVER_DIR/cred" "$K3S_SERVER_DIR/tls" -type f 2>/dev/null | wc -l)
  dst=$(tar -tf "$tar" 2>/dev/null | grep -cE '^server/(cred|tls)/.*[^/]$' || true)
  { [ "${src:-0}" -gt 0 ] && [ "${src:-0}" -eq "${dst:-0}" ]; } || { fail_component k3s "번들 항목 수 불일치(원본 cred+tls 파일 ${src:-?} ≠ 번들 ${dst:-?}) — 부분 복사된 번들은 업로드하지 않는다"; return 1; }
  find "$dir" -type f -exec shred -u -- {} + || { fail_component k3s "임시 번들 shred 실패: $dir"; return 1; }
  rm -rf -- "$dir" || { fail_component k3s "임시 번들 디렉터리 삭제 실패: $dir"; return 1; }
  encrypt_file "$tar" "$enc" || { fail_component k3s "age 암호화 실패"; return 1; }
  upload_object "$enc" "$obj" || { fail_component k3s "OCI 업로드/확인 실패(object put/head, instance principal) — journalctl 참조"; return 1; }
  finish_component k3s "$obj" "$enc" || return 1
}

# ---------- 2. Vault Raft 스냅샷 ----------
pick_free_port() {
  local p
  for ((p = PF_PORT_RANGE_START; p <= PF_PORT_RANGE_END; p++)); do
    if [ -z "$(ss -Hltn "sport = :$p" 2>/dev/null)" ]; then printf '%s' "$p"; return 0; fi
  done
  return 1
}

# $1 로컬 포트. 백그라운드 port-forward 를 띄우고 어떤 HTTP 응답이든(sealed 503 포함) 올 때까지 기다린다 — 터널 열림의 증거.
# 한 바퀴는 curl --max-time 2 + sleep 1 ≈ 3 s 이므로 반복은 PF_TIMEOUT/3 회 = 최악 약 PF_TIMEOUT 초다(주석과 메시지의 단위를 일치시킨다).
# stderr 는 $WORKDIR 에 남겨 실패 원인(services "vault" not found / unable to listen / 연결 거부)을 저널에 보여 준다 — 자격이 아니라 진단 문구다.
start_port_forward() {
  local port=$1 i curl_opts=(-s -o /dev/null --max-time 2)
  [ -z "$VAULT_CACERT" ] || curl_opts+=(--cacert "$VAULT_CACERT")
  "${KUBECTL[@]}" -n "$VAULT_NAMESPACE" port-forward --address 127.0.0.1 "svc/$VAULT_SERVICE" "$port:8200" >/dev/null 2>"$PF_ERR" &
  PF_PID=$!
  for ((i = 0; i < PF_TIMEOUT / 3; i++)); do
    kill -0 "$PF_PID" 2>/dev/null || return 1
    if curl "${curl_opts[@]}" "$VAULT_ADDR_SCHEME://127.0.0.1:$port/v1/sys/health"; then return 0; fi
    sleep 1
  done
  return 1
}

# 실패 분기용: 캡처한 stderr 마지막 3줄을 한 줄로(없으면 빈 문자열).
err_tail() {
  local f=$1
  [ -s "$f" ] || return 0
  tail -n 3 -- "$f" 2>/dev/null | tr '\n' ' '
}

stop_port_forward() {
  if [ -n "$PF_PID" ] && kill -0 "$PF_PID" 2>/dev/null; then kill "$PF_PID" 2>/dev/null || true; wait "$PF_PID" 2>/dev/null || true; fi
  PF_PID=""
}

backup_vault() {
  local snap="$WORKDIR/vault-$TS.snap" enc="$WORKDIR/vault-$TS.snap.age" obj="vault/vault-$TS.snap.age" port
  port=$(pick_free_port) || { fail_component vault "빈 로컬 포트($PF_PORT_RANGE_START-$PF_PORT_RANGE_END)가 없다"; return 1; }
  start_port_forward "$port" || { stop_port_forward; fail_component vault "kubectl port-forward svc/$VAULT_SERVICE ${port}:8200 이 ${PF_TIMEOUT}s 안에 준비되지 않았다(vault ns·Service·API 서버 확인): $(err_tail "$PF_ERR")"; return 1; }
  export VAULT_ADDR="$VAULT_ADDR_SCHEME://127.0.0.1:$port"
  [ -z "$VAULT_CACERT" ] || export VAULT_CACERT
  if ! vault status >/dev/null 2>"$VAULT_ERR"; then stop_port_forward; fail_component vault "vault status ≠ 0 (sealed 이거나 응답 없음 — KMS auto-unseal·VaultSealed 알림 확인): $(err_tail "$VAULT_ERR")"; return 1; fi
  # SA 토큰(TokenRequest, 10 m, audience vault) → kubernetes auth 로그인. JWT 는 파이프로만 흐른다(파일·명령줄·로그 없음); 받은 Vault 토큰은 이 셸 변수에만.
  local vault_token
  vault_token=$("${KUBECTL[@]}" -n "$VAULT_NAMESPACE" create token "$VAULT_SA" --audience vault --duration=10m \
    | vault write -field=token "auth/kubernetes/login" role="$VAULT_ROLE" jwt=-) || { stop_port_forward; fail_component vault "auth/kubernetes/login role=$VAULT_ROLE 실패(SA $VAULT_NAMESPACE/$VAULT_SA·role audiences [vault]·정책 sys/storage/raft/snapshot 확인 — T044)"; return 1; }
  [ -n "$vault_token" ] || { stop_port_forward; fail_component vault "로그인 응답에 토큰이 없다"; return 1; }
  if ! VAULT_TOKEN="$vault_token" vault operator raft snapshot save "$snap"; then
    VAULT_TOKEN="$vault_token" vault token revoke -self >/dev/null 2>&1 || true
    unset vault_token; stop_port_forward
    fail_component vault "vault operator raft snapshot save 실패"; return 1
  fi
  VAULT_TOKEN="$vault_token" vault token revoke -self >/dev/null 2>&1 || warn "vault token revoke -self 실패(10 m 뒤 만료)"
  unset vault_token
  stop_port_forward
  chmod 600 "$snap"
  [ -s "$snap" ] || { fail_component vault "스냅샷 파일이 비어 있다"; return 1; }
  encrypt_file "$snap" "$enc" || { fail_component vault "age 암호화 실패"; return 1; }
  upload_object "$enc" "$obj" || { fail_component vault "OCI 업로드/확인 실패(object put/head, instance principal)"; return 1; }
  finish_component vault "$obj" "$enc" || return 1
}

# ---------- summary ----------
summary() {
  local c rc=0 line
  printf '\n==== platform-backup summary: %s %s (mode=%s, components=%s) ====\n' "$(hostname)" "$(date -Is)" "$([ "$PRE_UPGRADE" = 1 ] && printf pre-upgrade || printf normal)" "$BACKUP_COMPONENTS"
  for c in ${BACKUP_COMPONENTS//,/ }; do
    if [ "${RESULT[$c]:-FAIL}" = OK ]; then
      line=$(printf '%-6s OK   object=%s bytes=%s' "$c:" "${OBJECT[$c]}" "${BYTES[$c]}")
    else
      rc=1
      line=$(printf '%-6s FAIL reason=%s' "$c:" "${REASON[$c]:-not attempted}")
    fi
    printf '%s\n' "$line"
  done
  printf 'bucket=%s (lifecycle k3s/ 7d, vault/ 30d)  textfile dir=%s  secrets: none printed\n' "$OCI_BUCKET" "$TEXTFILE_DIR"
  if [ "$PRE_UPGRADE" = 1 ]; then printf 'pre-upgrade gate: %s\n' "$([ "$rc" = 0 ] && printf PASS || printf 'FAIL (upgrade must not proceed)')"; fi
  printf '==== end: exit %d ====\n' "$rc"
  return "$rc"
}

main() {
  parse_args "$@"
  preflight
  local c
  for c in ${BACKUP_COMPONENTS//,/ }; do
    case "$c" in
      k3s)   backup_k3s || true ;;     # 실패해도 다음 컴포넌트를 계속 시도한다(summary 가 exit 1 을 정한다)
      vault) backup_vault || true ;;
    esac
  done
  summary
}

# stdin 을 /dev/null 로: 자식 명령(kubectl·vault·oci)이 호출자의 stdin 을 소비하지 않는다(jwt=- 파이프는 함수 안의 명시적 파이프라 영향 없음).
main "$@" </dev/null; exit
