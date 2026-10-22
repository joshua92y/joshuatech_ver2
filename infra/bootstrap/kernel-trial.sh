#!/usr/bin/env bash
# infra/bootstrap/kernel-trial.sh — 커널 시험 부팅 도구: GRUB 기본값 고정(pin) · 새 커널 1회 부팅(trial) · 고정 해제(unpin) — 003-platform-foundation T048
#
# 왜: 노드(Ubuntu 24.04 · arm64 · OCI)에 unattended-upgrades 가 새 커널을 설치해 두었고 자동 재부팅은 꺼져 있어, 다음 재부팅이 곧 메이저 커널
#   전환이다. GRUB 메뉴는 숨김 · 대기 0초라 새 커널이 부팅에 실패하면 콘솔에서 옛 커널을 고를 방법이 사실상 없다. 그래서 재부팅 전에 복구
#   경로를 먼저 만든다:
#     pin          지금 돌고 있는(검증된) 커널을 GRUB 기본값으로 고정한다 — /etc/default/grub.d/99-kernel-trial-pin.cfg + update-grub.
#                  이제 "그냥 재부팅"은 그 커널로 올라온다.
#     trial <kver> 새 커널을 다음 한 번만 부팅하게 한다 — grubenv 의 next_entry(grub.cfg 의 00_header 가 한 번 쓰고 지운다). 새 커널이
#                  실패하면 재부팅 한 번(부팅조차 안 되면 인스턴스 강제 재시작)으로 고정된 커널로 돌아온다. 재부팅은 하지 않는다.
#     unpin        새 커널로 부팅해 검증한 뒤 고정을 풀어 기본값(메뉴 0번 = 가장 새 커널)으로 되돌린다.
#     status       읽기 전용 진단(커널 · GRUB · grubenv · 패키지 작업 · 잔여 파일 · 판정 줄). cancel-trial 은 next_entry 를 지운다.
#
# 실행(운영자 워크스테이션 PowerShell 7 — 노드에 파일을 남기지 않는다; 스크립트는 표준 입력으로 들어간다):
#   Get-Content -Raw infra/bootstrap/kernel-trial.sh | ssh <노드> "sudo bash -s -- status"
#   순서: status → pin → trial 7.0.0-1012-oracle → (재부팅 · 검증 · status) → unpin. 시험을 접으려면 cancel-trial.
#   표준 입력 실행이므로 자기 파일 경로에 의존하지 않고, 마지막 줄의 명시 exit 로 끝난다 — PowerShell 파이프가 끝에 붙이는 CRLF 등 뒤따르는
#   바이트를 해석하지 않는다. main 은 </dev/null 로 부른다 — 자식 명령(update-grub 등)이 표준 입력의 스크립트 본문을 먹지 않는다.
#   출력에 'RESULT:' 줄이 없으면 실패로 본다 — 전송이 잘렸거나(스크립트가 끝까지 오지 않으면 정의만 읽고 아무것도 실행하지 않는다) 세션이
#   끊겼을 수 있다. 그때는 다시 접속해 status 로 지금 상태를 본다.
#
# 출력 계약: 'OK|FAIL|INFO <주제>: <내용>' 줄들 + 마지막 줄 'RESULT: OK|FAIL <하위 명령> -- <한 줄 요약>'. 모든 출력은 stdout 이고 ASCII 만
#   (운영자 콘솔이 CP949 일 수 있다) — emit 이 탭은 공백으로, 그 밖의 비ASCII · 제어 바이트는 '?' 로 바꾼다(파일 · 명령에서 읽은 값 포함).
#   외부 명령의 출력은 변수로 받아 INFO 줄로 옮긴다(stderr 를 그대로 흘리지 않는다).
#   종료 코드: 0 = OK · 1 = FAIL · 2 = 사용법 오류. FAIL 줄이 하나라도 나오면 RESULT 는 FAIL 이다. 쓰기 하위 명령은 끝에 status 의 판정 줄 셋
#   (next boot · later boots · pin)을 다시 내며, 그 판정이 INCONSISTENT 이면 그것도 FAIL 이다(쓰기는 성공했다고 믿어도 끝 상태가 어긋나면 실패).
# 가드: 전부 fail-closed — 판단할 수 없으면 FAIL 하고 아무것도 바꾸지 않는다. 첫 FAIL 에서 멈춘다(그 앞의 통과한 가드는 OK 줄로 보인다).
#   쓰기 뒤에는 다시 읽어 검증하고, 검증이 실패하면 되돌린다. 되돌리기도 실패하면 그 사실과 지금 상태(고정 파일 유무 · grub.cfg 기본값)를
#   FAIL 줄에 적는다.
#   패키지 작업(리뷰 #1): grub-mkconfig 에는 잠금이 없어 다른 update-grub(커널 · grub 패키지 훅)과 겹치면 메뉴 항목이 0 개인 grub.cfg 가 남을 수
#     있다. 그래서 pin · unpin · trial 은 쓰기 전에, pin · unpin 은 update-grub 직전에 한 번 더 본다(되돌리기 · 복원의 update-grub 앞에서는
#     프로세스만 — 방금 실패한 우리 update-grub 이 남긴 grub.cfg.new 는 겹칠 상대가 아니다). pin · unpin 은 update-grub 이 exit 0 으로 돌아온
#     직후(사후 검증 전)에도 프로세스를 한 번 더 보고, 보이면 FAIL 한다(수정 2 L1 — 훅의 update-grub 이 우리 것보다 늦게 시작해 쓰다 멈춘 파일이
#     grub.cfg 로 설치되면 꼬리 섹션이 빠져도 기본값과 0 번 항목은 맞아 보인다). 그때는 되돌리지 않는다(겹친 훅이 아직 쓰고 있을 수 있다 —
#     unpin 은 치워 둔 고정 파일만 지운다). 판정: pgrep -x 가 dpkg · apt · apt-get · unattended-upgr · grub-mkconfig · update-grub 가운데 하나라도 찾거나 /boot/grub/grub.cfg.new 가 있으면
#     작업 중이다(프로세스 없이 grub.cfg.new 만 있으면 실패하거나 죽은 grub-mkconfig 의 잔여물이고, 성공한 update-grub 한 번이 치운다 — 줄에
#     그 방법을 적는다). pgrep 이 없거나 0 · 1 이 아닌 코드로 끝나면 판단 불가 = 작업 중. 예외는 하나뿐이다 — 우분투의 unattended-upgrades.service 가
#     늘 띄워 두는 종료 대기 도우미(명령 줄이 정확히 UU_IDLE_HELPER 인 unattended-upgr; 2026-10-02 ubuntu:24.04 실측: 패키지가 단위를 enable
#     하고 pgrep -x unattended-upgr 가 이 프로세스를 찾는다)는 패키지 작업이 아니다. update-grub 직전에 작업이 보이면 쓴 것만 되돌린다(grub.cfg
#     는 아직 그대로다) — 이미 고정 파일을 읽은 훅이 끝나며 기본값을 바꿀 수 있어 OK 줄에 "작업이 끝난 뒤 status 를 다시"를 적는다(수정 2 L2).
#     cancel-trial 은 막지 않는다(next_entry 를 지우는 것은 안전한 방향이다).
#   initrd 없는 부팅 폴백(리뷰 #2): grub.cfg 에 'set partuuid=' 가 있으면 하위 메뉴 안의 항목(이 도구가 쓰는 경로)은 언제나 initrd 없이
#     부팅하고 재시도가 없다 — 고정된 복구 커널도, 시험 부팅도 평소 부팅과 같지 않으므로 pin · trial 을 하지 않는다(status 는 FAIL 줄).
#   grubenv 의 initrdfail · prev_entry(리뷰 #9): 하나라도 값이 있으면 GRUB 이 다음 부팅을 바꿀 수 있다 — status 는 INCONSISTENT, pin · trial 은
#     거부한다. 빈 값(GRUB 이 남기는 'x=')은 없음으로 읽는다. 그 줄에 할 일을 적는다(수정 2 L3 · INITRD_HINT): grub-common 2.12-1ubuntu7.3 에서
#     값을 쓰는 것은 GRUB 뿐이고('set partuuid=' 가 있을 때만 — 00_header 의 initrdfail 함수), grub-initrd-fallback.service 가 부팅마다 둘 다
#     지운다(grub-editenv … unset initrdfail · unset prev_entry). 메뉴에 커널 항목이 하나도 없는 grub.cfg(겹친 grub-mkconfig 의 잔여)도
#     거부 줄에 할 일을 적는다(EMPTY_MENU_HINT).
#   복구용 커널(리뷰 #6): trial 은 고정 값이 pin 이 지금 쓸 값(실행 중 커널의 -advanced- 항목)과 정확히 같고 그 커널의 vmlinuz · initrd 가
#     비어 있지 않을 때만 쓴다. status 는 고정된 커널의 -advanced- 항목 · 파일까지 보고 OK 를 낸다(고정된 커널이 실행 중 커널과 다른 것은
#     시험 커널로 부팅한 뒤의 정상 상태다).
#   모듈 검사(수정 2 M1 + 후속 F-A · F-B · F-C + 3라운드 R3-1 · R3-2 + R3c F1–F4 — trial 의 가드 · status 의 커널별 줄): 지금 적재된 모듈의 이름을 대상 커널 k 에서
#     modinfo -k 로 찾고, 못 찾은 모듈 m 은 지금 커널의 lsmod 한 줄(3열 사용 수 · 4열 사용자)과 modprobe -S <k> --show-depends 로 나눈다 —
#     대체됨(사용자 경로: 사용자가 있고 그 전부가 k 의 modules.dep 에 있다(exit 0 + insmod/builtin 줄 — depmod 는 풀리지 않는 심볼을 경고만 하고 의존
#     목록에서 빼므로, 트리가 온전하다는 전제의 판정이다) → 'm->u1+u2') ·
#     대체됨(별칭 경로: 사용자가 없고 부팅 때 이름으로 적재되는 목록에 없으며, 지금 커널의 modinfo -F alias 가운데 glob 글자가 없는 별칭 a 하나가
#     k 에서 풀리고 그 답의 모듈(insmod · builtin 줄) 가운데 m 의 계승자가 있다 — 계승자는 k 에서 a 를 스스로 선언하고, 지금 커널에 같은 이름으로
#     있으면서 이미 a 를 선언하던 형제가 아니다(R3-1: 풀리기만 해서는 m 의 기능이 k 에 있다는 근거가 아니다 — MODULE_ALIAS_CRYPTO 가 함께 선언하는
#     맨 이름 sm4 · crc32 는 이름이 같은 다른 모듈로 풀리고, 7.0 의 crypto-stdrng 는 6.17 에도 내장이던 drbg 로 풀린다; 지금 커널 쪽 조회가 'not found'
#     아닌 이유로 실패하면 형제인지 알 수 없으므로 세지 않는다 — R3c F1) → 'm=<처음 그렇게 풀린 별칭>'; 설계 한계(R3c F3): 여럿이 선언하는 가족
#     별칭(net-pf-N · crypto-stdrng)은 새 구성원이 생기면 m 의 기능과 무관해도 계승자로 센다 — 노드의 모듈(crypto · wireguard · btrfs)에는 그런 별칭이
#     없고, 실제 6.17 ↔ 7.0 · 7.0.0-1012 ↔ 1013 트리에도 그런 짝은 없다(2026-10-07 실측);
#     사용 수는 보지 않는다 — 노드의 wireguard 는 쓰는 중에도 사용 수 0 이다) · 없음(그 밖 전부 — fail-closed). 부팅 목록은 systemd 가 읽는
#     modules-load.d 넷 · /etc/modules · /etc/initramfs-tools/modules · /usr/share/initramfs-tools/modules.d/* · 지금 명령 줄의 modules_load= ·
#     rd.modules_load= 이다 — EFI 변수 SystemdOptions(systemd 가 명령 줄 뒤에 덧붙인다)는 보지 않는다(R3c F4). trial 은 없음이 0 이면 옵션 없이
#     진행하고, 없음이 있으면 --accept-missing-modules <없음 목록> 이 사전순으로 정확히 같을 때만 진행한다(--ignore-missing-modules 는 전부
#     받아들이되 그렇다고 한 줄 알린다). modprobe 가 없거나 -S 를 모르거나 답을 믿을 수 없으면(이름으로 못 찾은 첫 모듈을 먼저 물어 'not found' 를
#     확인한다) 이름 기준만 쓴다.
#     판정의 근거는 노드의 실제 모듈 트리다: modprobe -S <k> 는 /lib/modules/<k>/modules.dep(.bin) · modules.builtin 을 읽는다(-d 없이 기본 경로).
#     판정의 범위(R3-4): 사용자 경로는 부팅 목록 · m 자신의 별칭 · 이름 없는 사용 수를 보지 않는다. 실제 6.17 ↔ 7.0 트리에서 이 경로로 대체될 수
#     있는 모듈(이름으로 없고 사용자 하나 이상이 k 에서 풀리는 것 — 23개: 6.17 → 7.0 넷 · 7.0 → 6.17 열아홉; 사용자가 될 수 있는 모듈이 전부 적재돼
#     있으면 대체되는 것은 둘 · 열하나)은 전부 구체적인 별칭이 없다(2026-10-07 실측: 사용자가 있는 이름 없는 모듈 다섯 · 서른넷 가운데 구체적인 별칭이
#     있는 것은 nhpoly1305 하나이고, 그 사용자 nhpoly1305_neon 도 7.0 에 없어 이 경로로 대체되지 않는다). 별칭이 있는 모듈이 이 경로로 대체되면 그 별칭의 기능은 따로 확인한다.
#     실행 중에 사용자 공간이 이름으로 적재하는 모듈(k3s · containerd 의 'modprobe <이름>' · systemd 의 modprobe@<이름>.service)은 보지 않는다 —
#     별칭 · 사용자 경로로 대체된 모듈은 k 에서 이름으로는 적재되지 않는다(그래서 이름 검사에 걸렸다). 노드의 wireguard 는 infra/bootstrap/host-prep.sh 가
#     /etc/modules-load.d/wireguard.conf 에 적으므로 부팅 목록 규칙이 판정한다.
# 접속이 끊겨도 끝까지 간다(리뷰 #3): trap '' HUP PIPE — 출력이 닫힌 뒤에도(SSH 세션 끊김) 쓰기 단계와 되돌리기가 끝까지 실행된다. 출력 실패는
#   흐름을 바꾸지 않는다(출력 함수의 종료 코드로 분기하지 않는다). 도중에 죽은 실행(전원 · kill -9)이 남긴 과도 상태(고정 파일은 있는데
#   grub.cfg 가 옛 값 / 고정 파일은 없는데 grub.cfg 기본값이 ID)는 이어 끝내지 않는다 — 쓰기 명령은 거부하고, 그 FAIL 줄과 status 의
#   INCONSISTENT 줄이 수동 복구 한 줄(FIX_LINE)을 적는다. status 는 죽은 실행의 잔여 파일도 보여 준다(INFO leftovers).
# errexit 를 쓰지 않는다(set -u · pipefail 만): 쓰기 도중의 예기치 못한 실패가 되돌리기 없이 스크립트를 끝내면 안 된다 — 실패할 수 있는 모든
#   명령의 종료 코드를 명시적으로 본다.
#
# 노드 실측 전제(2026-10-01, 두 노드 동일):
#   /etc/default/grub: GRUB_DEFAULT=0 · GRUB_TIMEOUT_STYLE=hidden · GRUB_TIMEOUT=0. 드롭인은 50-cloudimg-settings.cfg 하나. grub-mkconfig 는
#     /etc/default/grub 뒤에 grub.d/*.cfg 를 이름 순으로 읽으므로 99-…cfg 가 마지막에 이긴다(점으로 시작하는 이름 · .cfg 가 아닌 이름은 읽지 않는다).
#   grub.cfg 의 기본값 논리(우분투 00_header): next_entry 가 있으면 그 항목을 한 번 부팅하고 지우고(save_env), 없으면 set default="<GRUB_DEFAULT>".
#   메뉴 항목 ID: 하위 메뉴 gnulinux-advanced-<uuid>, 커널 gnulinux-<kver>-advanced-<uuid>(복구 모드 …-recovery-… 는 쓰지 않는다).
#     하위 메뉴 안의 항목을 가리키는 값은 '<하위 메뉴 ID>><항목 ID>'. GRUB 은 풀 수 없는 값이면 0번(가장 새 커널)으로 간다 — 그래서 값이 메뉴에서
#     정확히 하나의 커널 항목으로 풀리는지를 쓰기 전과 쓴 뒤에 모두 본다.
#   /boot 는 별도 ext4, grubenv 는 /boot/grub/grubenv(1024 바이트). grub-reboot 는 판에 따라 next_entry 가 아니라 saved_entry 를 쓰므로 부르지
#     않고, grub-editenv <grubenv> set next_entry=<값> 으로 grub.cfg 논리와 정확히 맞는 변수를 직접 쓴다.
#   kernel.panic=10 → 시험 커널이 패닉하면 사람 없이도 재부팅되어 고정된 커널로 돌아온다.
#
# 시험 훅: KT_ROOT 가 설정돼 있으면 모든 경로 앞에 붙이고 첫 줄에 'INFO note: KT_ROOT=<값> (test root)' 를 낸다(tests/infra/kernel-trial.tests.ps1 이
#   가짜 루트 + 가짜 명령으로 실제 실행한다 — 부팅 때의 모듈 목록(modules-load.d · /etc/modules)도 KT_ROOT 아래에서 읽는다). sudo 는 환경을
#   초기화하므로 노드에서는 비어 있다. 외부 명령은 PATH 에서 찾는다: uname · id · update-grub · grub-editenv · lsmod · modinfo · modprobe(없어도
#   된다 — 이름 기준으로 되돌아간다) · dmesg · apt-config · pgrep · sort · awk(+ coreutils mktemp · mv · rm · chmod).
#   awk 프로그램은 POSIX 문법만 쓴다(노드의 awk 는 mawk).
#
# 절대 하지 않는 것: grub.cfg 직접 수정(update-grub 만이 쓴다), /etc/default/grub · 기존 드롭인 수정, 재부팅 · 전원 조작, 패키지 설치/삭제,
#   커널 삭제, saved_entry 쓰기, 비밀 읽기, 남의 프로세스에 신호 보내기.
set -uo pipefail
export LC_ALL=C
# 첫 출력 전에: SSH 세션이 끊겨 표준 출력이 닫혀도(SIGPIPE) · 터미널이 끊겨도(SIGHUP) 끝까지 실행한다. 자식(update-grub 등)도 물려받는다.
trap '' HUP PIPE

# ---------- 상수 ----------
R=${KT_ROOT:-}
GRUB_CFG=$R/boot/grub/grub.cfg
GRUB_CFG_NEW=$R/boot/grub/grub.cfg.new
GRUBENV=$R/boot/grub/grubenv
DEFAULT_GRUB=$R/etc/default/grub
GRUBD=$R/etc/default/grub.d
PIN_FILE=$GRUBD/99-kernel-trial-pin.cfg
BOOT_DIR=$R/boot
MODULES_DIR=$R/lib/modules
REBOOT_REQ=$R/var/run/reboot-required
CMDLINE_FILE=$R/proc/cmdline
# 출력에 쓰는 경로(시험 루트 접두 없이)
D_GRUB_CFG=/boot/grub/grub.cfg
D_GRUB_CFG_NEW=/boot/grub/grub.cfg.new
D_GRUBENV=/boot/grub/grubenv
D_GRUBD=/etc/default/grub.d
D_PIN_FILE=/etc/default/grub.d/99-kernel-trial-pin.cfg
KVER_RE='^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-[a-z0-9]+$'
ID_RE='^[A-Za-z0-9._-]+$'
NUM_RE='^(0|[1-9][0-9]?[0-9]?[0-9]?)$'
DEFLINE_RE='^[[:space:]]*(export[[:space:]]+)?GRUB_DEFAULT='
PINLINE_RE='^GRUB_DEFAULT="([^"]*)"$'
SUB_PREFIX=gnulinux-advanced-
NL=$'\n'
# 패키지 작업으로 보는 프로세스 이름(pgrep -x — 커널의 15 자 프로세스 이름). 따옴표 안에 둔다(명령으로 부르지 않는다).
PKG_NAMES=('dpkg' 'apt' 'apt-get' 'unattended-upgr' 'grub-mkconfig' 'update-grub')
# 패키지 작업이 아닌 유일한 unattended-upgr: unattended-upgrades.service 의 종료 대기 도우미(pgrep -a 의 명령 줄과 글자 그대로 같을 때만).
UU_IDLE_HELPER='/usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal'
# 수동 복구 한 줄(과도 상태 · 검증 실패 · 끝내지 못한 되돌리기). 조건은 "패키지 프로세스가 없을 때"다 — 홀로 남은 오래된 grub.cfg.new 는
#   성공한 update-grub 만이 치우므로, "package activity: none" 을 기다리라고 하면 끝나지 않는다.
FIX_LINE="manual fix: when status lists no package process, run 'sudo update-grub' one time, then run status again"
# 메뉴에 커널 항목이 하나도 없는 grub.cfg(겹친 grub-mkconfig 가 남기는 모양 — 수정 2 L3 (a))의 거부 줄에 붙이는 할 일.
EMPTY_MENU_HINT="grub.cfg has no kernel menu entry (a partial grub-mkconfig output?): do not reboot -- $FIX_LINE"
# grubenv 의 initrdfail · prev_entry 에 값이 있을 때의 할 일(수정 2 L3 (b)). 근거(grub-common 2.12-1ubuntu7.3):
#   /lib/systemd/system/grub-initrd-fallback.service 10–11행 — 부팅마다 grub-editenv /boot/grub/grubenv unset initrdfail · unset prev_entry;
#   /etc/grub.d/00_header 117–128행 — 값은 'set partuuid=' 가 있을 때 GRUB 의 initrdfail 함수만 쓴다; 54–63행 — initrdfail=1 이면 다음 부팅이
#   prev_entry 를 한 번 쓴다.
INITRD_HINT="unexpected (grub-initrd-fallback.service clears both at every boot): before any reboot, check 'systemctl status grub-initrd-fallback.service', clear them as that unit does with 'sudo systemctl start grub-initrd-fallback.service', then run status"
# lsmod 사용자 열에서 받는 모듈 이름(그 밖의 글자가 하나라도 있으면 그 모듈은 '없음' — fail-closed).
MODNAME_RE='^[A-Za-z0-9_-]+$'

# ---------- 실행 상태 ----------
# 함수들이 주고받는 전역은 전부 여기서 먼저 정한다 — set -u 에서 읽기 전 대입이 빠지면 bash 가 쓰기 도중에 끝나 되돌리기를 건너뛴다.
FAILS=0
CMD=""
TRIAL_KVER=""
IGNORE_MISSING=0
SUMMARY=""
SHOW_VERDICT=0
TRIAL_SET=0
FIRST=""; YN=""; COUNT=0; UG_RC=0; STATE_TEXT=""
RK=""; RD=""; RI=""; RP=""; RV=""
RESOLVED=""; RESOLVE_ERR=""; SUB_ID=""; ENTRY_ID=""; ID_PATH=""; IDS_ERR=""
PIN_PRESENT=0; PIN_VALUE=""; PIN_ERR=""
GE_OK=0; GE_LIST=""; NEXT_ENTRY=""; INITRDFAIL=""; PREV_ENTRY=""; GE_ERR=""
RUNNING=""; KERNELS=(); LOADED=(); LOADED_ERR=""; MISSING=()
LOADED_CNT=(); LOADED_BY=(); ACCOUNTED=(); NAME_MISS=0; MP_FALLBACK=""; MP_NOTED=""; MPQ=""; MPQ_WHY=""
BOOTMODS=""; BOOTMODS_READ=0; BOOTMODS_ERR=""; SORTED=(); USERS=()
ACCEPT_SET=0; ACCEPT_LIST=(); ACCEPT_DIFF=""; ALIAS_HIT=""; MPQ_MODS=""
V_NEXT=unknown; V_NEXT_HOW=default; V_LATER=unknown; V_PIN_OK=0; V_PIN_TEXT=""
PKG_BUSY=0; PKG_ITEMS=""; PKG_IGNORED=""; PKG_CFGNEW_ONLY=0; LEFTOVERS=""; KF_ERR=""; PE_ERR=""

# ---------- 출력 ----------
# 모든 줄은 emit 을 지난다: 탭 → 공백, 그 밖의 비ASCII · 제어 바이트 → '?'(LC_ALL=C 라 바이트 단위로 바뀐다).
emit() {
  local s=$1
  s=${s//$'\t'/ }
  s=${s//[^ -~]/?}
  printf '%s\n' "$s"
}
ok()   { emit "OK $1: $2"; }
info() { emit "INFO $1: $2"; }
fail() { FAILS=$((FAILS + 1)); emit "FAIL $1: $2"; }
first_line() { FIRST=${1%%"$NL"*}; }
# 파일 상태 → YN: yes(비어 있지 않은 일반 파일) · empty(크기 0 인 일반 파일) · no(없음 · 일반 파일 아님). 디렉터리 → yes · no.
file_yn() { if [ -f "$1" ] && [ -s "$1" ]; then YN=yes; elif [ -f "$1" ]; then YN=empty; else YN=no; fi; }
dir_yn() { if [ -d "$1" ]; then YN=yes; else YN=no; fi; }

# ---------- grub.cfg ----------
# grub.cfg 를 한 번 읽어 네 종류의 줄을 낸다(POSIX awk — 노드는 mawk):
#   B|<next_entry 블록 수>|<그 else 가지의 기본값>
#   P|<'set partuuid=' 가 든 줄 수>(grep -c 'set partuuid=' 와 같은 셈 — initrd 없는 부팅 폴백)
#   E|<M 메뉴 항목 | S 하위 메뉴>|<깊이>|<ID>|<부모 하위 메뉴 ID>|<linux 줄의 커널>
#   Z|<끝 깊이>|<짝 없는 닫는 괄호 1/0>
# 블록 깊이는 'menuentry … {' · 'submenu … {' · 'function … {' 줄과 '}' 만 줄로 센다(grub-mkconfig 출력의 모양).
AWK_MENU='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function getid(line,   opt, pos, rest, e) {
  opt = "$menuentry_id_option " q
  pos = index(line, opt)
  if (pos == 0) return ""
  rest = substr(line, pos + length(opt))
  e = index(rest, q)
  if (e == 0) return ""
  return substr(rest, 1, e - 1)
}
{ sub(/\r$/, ""); T[NR] = trim($0) }
END {
  depth = 0; n = 0; nb = 0; dv = ""; bad = 0; np = 0
  for (i = 1; i <= NR; i++) {
    t = T[i]
    if (index(t, "set partuuid=") > 0) np++
    if (t == "if [ \"${next_entry}\" ] ; then" && T[i+1] == "set default=\"${next_entry}\"" && T[i+2] == "set next_entry=" && T[i+3] == "save_env next_entry" && T[i+4] == "set boot_once=true" && T[i+5] == "else" && T[i+7] == "fi") {
      v = T[i+6]
      if (length(v) >= 14 && substr(v, 1, 13) == "set default=\"" && substr(v, length(v), 1) == "\"") { nb++; dv = substr(v, 14, length(v) - 14) }
    }
    if ((t ~ /^menuentry[ \t]/ || t ~ /^submenu[ \t]/) && t ~ /[{]$/) {
      n++
      K[n] = (t ~ /^menuentry/) ? "M" : "S"
      D[n] = depth; I[n] = getid(t); P[n] = (depth > 0) ? SI[depth] : ""; V[n] = ""
      depth++; SI[depth] = I[n]; SN[depth] = n
      continue
    }
    if (t ~ /^function[ \t]/ && t ~ /[{]$/) { depth++; SI[depth] = ""; SN[depth] = 0; continue }
    if (t == "}") { if (depth > 0) depth--; else bad = 1; continue }
    if (depth > 0 && SN[depth] > 0 && K[SN[depth]] == "M" && V[SN[depth]] == "" && t ~ /^linux[ \t]/) {
      split(t, f, /[ \t]+/)
      k = index(f[2], "vmlinuz-")
      if (k > 0) V[SN[depth]] = substr(f[2], k + 8)
    }
  }
  print "B|" nb "|" dv
  print "P|" np
  for (j = 1; j <= n; j++) print "E|" K[j] "|" D[j] "|" I[j] "|" P[j] "|" V[j]
  print "Z|" depth "|" bad
}'

MENU=()
NE_BLOCKS=0
CFG_DEFAULT=""
MENU_ERR=""
PARTUUID_LINES=""
load_menu() {
  MENU=(); NE_BLOCKS=0; CFG_DEFAULT=""; MENU_ERR=""; PARTUUID_LINES=""
  if [ ! -f "$GRUB_CFG" ]; then MENU_ERR="$D_GRUB_CFG not found"; return 1; fi
  local out rc line z=""
  out=$(awk -v q="'" "$AWK_MENU" "$GRUB_CFG" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then first_line "$out"; MENU_ERR="cannot parse $D_GRUB_CFG (awk exit $rc: $FIRST)"; return 1; fi
  while IFS= read -r line; do
    case $line in
      'B|'*) line=${line#B|}; NE_BLOCKS=${line%%|*}; CFG_DEFAULT=${line#*|} ;;
      'P|'*) PARTUUID_LINES=${line#P|} ;;
      'E|'*) MENU+=("${line#E|}") ;;
      'Z|'*) z=${line#Z|} ;;
    esac
  done <<< "$out"
  if [ "$z" != "0|0" ]; then MENU_ERR="unbalanced menu blocks in $D_GRUB_CFG"; return 1; fi
  if ! [[ $PARTUUID_LINES =~ ^[0-9]+$ ]]; then PARTUUID_LINES=""; MENU_ERR="cannot count the 'set partuuid=' lines of $D_GRUB_CFG"; return 1; fi
  return 0
}

# 표 한 줄(kind|depth|id|parent|kver) → RK RD RI RP RV
split_row() {
  local r=$1
  RK=${r%%|*}; r=${r#*|}
  RD=${r%%|*}; r=${r#*|}
  RI=${r%%|*}; r=${r#*|}
  RP=${r%%|*}; r=${r#*|}
  RV=$r
}

# 유일성 판정은 전부 이 함수 하나를 지난다(메뉴 ID 가 "정확히 하나"인가).
exactly_one() { [ "$1" -eq 1 ]; }

# grub.cfg 에 커널 항목(linux 줄이 있는 menuentry)이 하나라도 있는가(load_menu 뒤 — RK 등 split_row 의 전역을 바꾼다).
menu_has_kernel() {
  local row
  for row in "${MENU[@]}"; do
    split_row "$row"
    if [ "$RK" = M ] && [ -n "$RV" ]; then return 0; fi
  done
  return 1
}

count_id() {
  local row
  COUNT=0
  for row in "${MENU[@]}"; do
    split_row "$row"
    if [ "$RI" = "$1" ]; then COUNT=$((COUNT + 1)); fi
  done
  return 0
}

# GRUB 의 기본값 해석을 흉내 낸다 → RESOLVED(커널) 또는 RESOLVE_ERR.
#   숫자 N = 최상위 N 번째 항목 · 'A>B' = 최상위 하위 메뉴 A 의 직속 항목 B · 그 밖 = 최상위 항목 ID. 쓰인 ID 는 메뉴에 정확히 하나여야 한다.
resolve_value() {
  local v=$1 row idx=0 a b
  RESOLVED=""; RESOLVE_ERR=""
  if [ -z "$v" ]; then RESOLVE_ERR="empty value"; return 1; fi
  if [[ $v =~ $NUM_RE ]]; then
    for row in "${MENU[@]}"; do
      split_row "$row"
      [ "$RD" = 0 ] || continue
      if [ "$idx" = "$v" ]; then
        if [ "$RK" = M ] && [ -n "$RV" ]; then RESOLVED=$RV; return 0; fi
        RESOLVE_ERR="top-level item $v is not a kernel entry"; return 1
      fi
      idx=$((idx + 1))
    done
    RESOLVE_ERR="grub.cfg has no top-level item $v"; return 1
  fi
  if [[ $v == *'>'* ]]; then
    a=${v%%>*}; b=${v#*>}
    if [[ $b == *'>'* ]]; then RESOLVE_ERR="more than one '>' in the value"; return 1; fi
    count_id "$a"
    if ! exactly_one "$COUNT"; then RESOLVE_ERR="id $a found $COUNT times (want exactly 1)"; return 1; fi
    for row in "${MENU[@]}"; do split_row "$row"; [ "$RI" = "$a" ] && break; done
    if [ "$RK" != S ] || [ "$RD" != 0 ]; then RESOLVE_ERR="id $a is not a top-level submenu"; return 1; fi
  else
    a=""; b=$v
  fi
  count_id "$b"
  if ! exactly_one "$COUNT"; then RESOLVE_ERR="id $b found $COUNT times (want exactly 1)"; return 1; fi
  for row in "${MENU[@]}"; do
    split_row "$row"
    [ "$RI" = "$b" ] || continue
    if [ "$RK" != M ]; then RESOLVE_ERR="id $b is not a menu entry"; return 1; fi
    if [ -n "$a" ]; then
      if [ "$RD" != 1 ] || [ "$RP" != "$a" ]; then RESOLVE_ERR="entry $b is not directly inside submenu $a"; return 1; fi
    elif [ "$RD" != 0 ]; then
      RESOLVE_ERR="entry $b is not a top-level entry"; return 1
    fi
    if [ -z "$RV" ]; then RESOLVE_ERR="entry $b has no linux line"; return 1; fi
    RESOLVED=$RV
    return 0
  done
  RESOLVE_ERR="id $b not found"
  return 1
}

# 커널 $1 의 하위 메뉴 ID · 항목 ID 를 찾아 ID_PATH='<하위 메뉴 ID>><항목 ID>' 를 만든다(각각 정확히 하나 · 안전한 글자 · 그 값이 $1 로 풀린다).
#   pin 이 쓰는 값이 곧 이것이다 — 복구 모드 항목(…-recovery-…)은 '-advanced-' 가 아니어서 여기서 나오지 않는다.
find_ids() {
  local k=$1 row subs=0 ents=0
  SUB_ID=""; ENTRY_ID=""; ID_PATH=""; IDS_ERR=""
  for row in "${MENU[@]}"; do
    split_row "$row"
    if [ "$RK" = S ] && [[ $RI == "$SUB_PREFIX"* ]]; then subs=$((subs + 1)); SUB_ID=$RI; fi
    if [ "$RK" = M ] && [[ $RI == "gnulinux-$k-advanced-"* ]]; then ents=$((ents + 1)); ENTRY_ID=$RI; fi
  done
  if ! exactly_one "$subs"; then IDS_ERR="submenu ${SUB_PREFIX}* found $subs times in $D_GRUB_CFG (want exactly 1)"; return 1; fi
  if ! exactly_one "$ents"; then IDS_ERR="entry gnulinux-$k-advanced-* found $ents times in $D_GRUB_CFG (want exactly 1)"; return 1; fi
  if ! [[ $SUB_ID =~ $ID_RE ]] || ! [[ $ENTRY_ID =~ $ID_RE ]]; then IDS_ERR="menu ids contain characters outside [A-Za-z0-9._-]"; return 1; fi
  ID_PATH="$SUB_ID>$ENTRY_ID"
  if ! resolve_value "$ID_PATH"; then IDS_ERR="$ID_PATH does not resolve: $RESOLVE_ERR"; return 1; fi
  if [ "$RESOLVED" != "$k" ]; then IDS_ERR="$ID_PATH boots $RESOLVED, not $k"; return 1; fi
  return 0
}

# ---------- 고정 파일 · grubenv · 커널 ----------
# 고정 파일: 주석 · 빈 줄 + GRUB_DEFAULT="<하위 메뉴 ID>><항목 ID>" 정확히 한 줄. 그 밖의 줄이 있으면 형식 오류(fail-closed).
read_pin_file() {
  PIN_PRESENT=0; PIN_VALUE=""; PIN_ERR=""
  [ -e "$PIN_FILE" ] || return 0
  PIN_PRESENT=1
  if [ ! -f "$PIN_FILE" ] || [ ! -r "$PIN_FILE" ]; then PIN_ERR="not a readable regular file"; return 1; fi
  local line n=0 val=""
  while IFS= read -r line || [ -n "$line" ]; do
    case $line in ''|'#'*) continue ;; esac
    if [[ $line =~ $PINLINE_RE ]]; then n=$((n + 1)); val=${BASH_REMATCH[1]}; else PIN_ERR="unexpected line: $line"; return 1; fi
  done < "$PIN_FILE"
  if [ "$n" -ne 1 ]; then PIN_ERR="$n GRUB_DEFAULT lines (want exactly 1)"; return 1; fi
  if [[ $val != *'>'* ]] || ! [[ ${val%%>*} =~ $ID_RE ]] || ! [[ ${val#*>} =~ $ID_RE ]]; then PIN_ERR="value \"$val\" is not <submenu id>><entry id>"; return 1; fi
  PIN_VALUE=$val
  return 0
}

# grubenv 를 list 로 읽는다 → NEXT_ENTRY · INITRDFAIL · PREV_ENTRY. 빈 값('x=' — GRUB 이 한 번 쓴 변수를 지우는 모양)은 없음과 같다.
read_grubenv() {
  GE_OK=0; GE_LIST=""; NEXT_ENTRY=""; INITRDFAIL=""; PREV_ENTRY=""; GE_ERR=""
  if [ ! -f "$GRUBENV" ]; then GE_ERR="$D_GRUBENV not found"; return 1; fi
  local out rc line ne=0 nf=0 np=0
  out=$(grub-editenv "$GRUBENV" list 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then first_line "$out"; GE_ERR="grub-editenv list exit $rc: $FIRST"; return 1; fi
  GE_LIST=$out
  while IFS= read -r line; do
    case $line in
      next_entry=*) ne=$((ne + 1)); NEXT_ENTRY=${line#next_entry=} ;;
      initrdfail=*) nf=$((nf + 1)); INITRDFAIL=${line#initrdfail=} ;;
      prev_entry=*) np=$((np + 1)); PREV_ENTRY=${line#prev_entry=} ;;
    esac
  done <<< "$out"
  if [ "$ne" -gt 1 ]; then GE_ERR="grubenv lists next_entry $ne times"
  elif [ "$nf" -gt 1 ]; then GE_ERR="grubenv lists initrdfail $nf times"
  elif [ "$np" -gt 1 ]; then GE_ERR="grubenv lists prev_entry $np times"; fi
  if [ -n "$GE_ERR" ]; then NEXT_ENTRY=""; INITRDFAIL=""; PREV_ENTRY=""; return 1; fi
  GE_OK=1
  return 0
}

read_running() {
  RUNNING=$(uname -r 2>/dev/null) || { RUNNING=""; return 1; }
  [[ $RUNNING =~ $KVER_RE ]]
}

# 설치된 커널 = /boot/vmlinuz-* 전부(이름 형식과 무관 — grub-mkconfig 도 전부 본다), sort -V 순(마지막이 가장 새 것).
list_kernels() {
  KERNELS=()
  local f out k names=()
  for f in "$BOOT_DIR"/vmlinuz-*; do
    [ -e "$f" ] || continue
    names+=("${f##*/vmlinuz-}")
  done
  [ "${#names[@]}" -gt 0 ] || return 0
  out=$(printf '%s\n' "${names[@]}" | sort -V) || return 1
  while IFS= read -r k; do [ -n "$k" ] && KERNELS+=("$k"); done <<< "$out"
  return 0
}

# lsmod → LOADED(이름) · LOADED_CNT(3열 사용 수, 원문) · LOADED_BY(4열 사용자 열, 원문 — 없으면 빈 값). 같은 첨자끼리 한 줄이다.
read_loaded_modules() {
  LOADED=(); LOADED_CNT=(); LOADED_BY=(); LOADED_ERR=""
  local out rc line name cnt by first=1
  out=$(lsmod 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then first_line "$out"; LOADED_ERR="lsmod exit $rc: $FIRST"; return 1; fi
  while IFS= read -r line; do
    if [ "$first" = 1 ]; then first=0; [[ $line == Module[[:space:]]* ]] && continue; fi
    name=${line%%[[:space:]]*}
    [ -n "$name" ] || continue
    cnt=""; by=""
    read -r name _ cnt by _ <<< "$line"
    LOADED+=("$name"); LOADED_CNT+=("$cnt"); LOADED_BY+=("$by")
  done <<< "$out"
  return 0
}

# 값들을 사전순(LC_ALL=C — 바이트 순)으로 SORTED 에 담는다. 같은 값은 한 번만.
sort_words() {
  SORTED=()
  local w s i dup
  for w in "$@"; do
    dup=0
    for s in "${SORTED[@]}"; do if [ "$s" = "$w" ]; then dup=1; break; fi; done
    [ "$dup" = 0 ] || continue
    i=${#SORTED[@]}
    SORTED+=("$w")
    while [ "$i" -gt 0 ] && [[ ${SORTED[i-1]} > "$w" ]]; do SORTED[i]=${SORTED[i-1]}; i=$((i - 1)); done
    SORTED[i]=$w
  done
  return 0
}

# lsmod 4열(사용자 열) → USERS. 없음 · '-' → 빈 목록. 쉼표로 나눈 토큰 가운데 빈 것(끝의 쉼표)과 '[...]'(예: [permanent])는 버린다.
#   MODNAME_RE 밖의 글자가 든 토큰이 하나라도 있으면 1 — 그 모듈은 '없음'(fail-closed).
parse_users() {
  local col=$1 t
  local -a toks=()
  USERS=()
  if [ -z "$col" ] || [ "$col" = - ]; then return 0; fi
  IFS=, read -r -a toks <<< "$col"
  for t in "${toks[@]}"; do
    [ -n "$t" ] || continue
    case $t in '['*']') continue ;; esac
    [[ $t =~ $MODNAME_RE ]] || return 1
    USERS+=("$t")
  done
  return 0
}

# 부팅 때 이름으로 적재되는 모듈 → BOOTMODS(' 이름 이름 ... ' — '-' 는 '_' 로). systemd-modules-load 가 읽는 자리(systemd 255.4-1ubuntu8.17:
#   /etc · /run · /usr/local/lib · /usr/lib 의 modules-load.d/*.conf)와 /etc/modules 를 KT_ROOT 아래에서 읽는다(합집합 — 같은 이름으로 가린
#   파일도 넣는다). 빈 줄과 앞 공백 뒤 첫 글자가 # · ; 인 줄은 버리고, 각 줄의 첫 낱말만 쓴다(CR 도 [[:space:]] 라 떨어진다). /dev/null 로 가린 것(문자
#   장치)은 빈 목록이다. 정규 파일이 아니거나 읽을 수 없는 것이 있으면 판단 불가 → BOOTMODS_ERR · INFO 한 줄 · 1(부른 쪽은 '목록에 있다'로
#   본다 — fail-closed). 한 번만 읽는다.
#   후속 F-C: /etc/initramfs-tools/modules 와 /usr/share/initramfs-tools/modules.d/*(initrd 에 들어가 부팅 때 이름으로 적재되는 목록 —
#   initramfs-tools-core 0.142ubuntu25.8 의 mkinitramfs 351–355행이 둘을 함께 읽는다; 같은 해석)와 지금 커널 명령 줄(KT_ROOT 아래 /proc/cmdline)의
#   modules_load= · rd.modules_load=(systemd-modules-load 가 읽는다; 키의 - 와 _ 는 같게 본다 — modules-load= 도; 값은 쉼표 목록; 낱말은 systemd 와
#   같게 나눈다 — 따옴표 밖의 공백 · 탭에서 나누고, 낱말 안의 큰따옴표 · 작은따옴표는 자리를 가리지 않고 벗기되 따옴표 안의 공백은 낱말을 잇는다:
#   낱말 전체를 감싼 '"modules_load=a,b"' 도, 값 중간의 'modules_load=a,"b"' 도, 작은따옴표의 "'modules_load=c'" 도, 'modules_load="a b",c' 의 c 도
#   부팅 목록이다 — 3라운드 R3-2 · R3b F6 · R3c F2)도 넣는다. 시험 부팅도 같은 명령 줄(GRUB_CMDLINE_LINUX)로 올라오므로 지금 명령 줄이 그 근사다.
read_boot_modules() {
  if [ "$BOOTMODS_READ" = 1 ]; then [ -z "$BOOTMODS_ERR" ]; return; fi
  BOOTMODS_READ=1; BOOTMODS=" "; BOOTMODS_ERR=""
  local f line w cl="" tok key val rest item i ch q word inw
  local -a toks=()
  for f in "$R"/etc/modules-load.d/*.conf "$R"/run/modules-load.d/*.conf "$R"/usr/local/lib/modules-load.d/*.conf "$R"/usr/lib/modules-load.d/*.conf "$R"/etc/modules "$R"/etc/initramfs-tools/modules "$R"/usr/share/initramfs-tools/modules.d/*; do
    if [ ! -e "$f" ] && [ ! -L "$f" ]; then continue; fi
    if [ -c "$f" ]; then continue; fi
    if [ ! -f "$f" ] || [ ! -r "$f" ]; then BOOTMODS_ERR="${f#"$R"} is not a readable regular file"; break; fi
    if ! { while IFS= read -r line || [ -n "$line" ]; do
             line=${line#"${line%%[![:space:]]*}"}
             case $line in ''|'#'*|';'*) continue ;; esac
             w=${line%%[[:space:]]*}
             BOOTMODS="$BOOTMODS${w//-/_} "
           done < "$f"; } 2>/dev/null; then
      BOOTMODS_ERR="cannot read ${f#"$R"}"; break
    fi
  done
  if [ -z "$BOOTMODS_ERR" ]; then
    if [ ! -r "$CMDLINE_FILE" ]; then
      BOOTMODS_ERR="cannot read ${CMDLINE_FILE#"$R"}"
    else
      # 끝에 줄바꿈이 없어도 read 는 값을 채운다(종료 코드는 보지 않는다).
      IFS= read -r cl < "$CMDLINE_FILE"
      # systemd 255.4-1ubuntu8.17 의 낱말 나누기(proc_cmdline_extract_first = extract_first_word(EXTRACT_UNQUOTE|EXTRACT_RELAX|EXTRACT_RETAIN_ESCAPE))와
      #   같게 자른다: 따옴표 밖의 공백 · 탭에서 낱말을 나누고, 낱말 안의 " 와 ' 는 어디에 있든 벗기되 따옴표 안의 공백은 낱말을 잇는다(그래서
      #   'modules_load="a b",c' 의 c 도 부팅 목록이다 — read -a 는 따옴표 안의 공백에서 먼저 잘라 c 를 놓쳤다). 닫히지 않은 따옴표는 줄 끝에서 닫히고
      #   (EXTRACT_RELAX), 역슬래시는 글자 그대로다(EXTRACT_RETAIN_ESCAPE). 2026-10-07 systemd-modules-load 실측 50 모양과 같다.
      toks=(); word=""; q=""; inw=0
      for ((i = 0; i < ${#cl}; i++)); do
        ch=${cl:i:1}
        if [ -n "$q" ]; then
          if [ "$ch" = "$q" ]; then q=""; else word=$word$ch; fi
        elif [ "$ch" = '"' ] || [ "$ch" = "'" ]; then q=$ch; inw=1
        elif [ "$ch" = ' ' ] || [ "$ch" = $'\t' ] || [ "$ch" = $'\r' ]; then
          if [ "$inw" = 1 ]; then toks+=("$word"); fi
          word=""; inw=0
        else word=$word$ch; inw=1; fi
      done
      if [ "$inw" = 1 ]; then toks+=("$word"); fi
      for tok in "${toks[@]}"; do
        case $tok in *=*) ;; *) continue ;; esac
        key=${tok%%=*}; key=${key//-/_}
        case $key in modules_load|rd.modules_load) ;; *) continue ;; esac
        val=${tok#*=}
        rest=$val
        while :; do
          item=${rest%%,*}
          # 빈 항목과 따옴표 안의 공백을 품은 항목('"a b"' — 모듈 이름이 될 수 없고 systemd 도 적재에 실패한다)은 목록에 넣지 않는다.
          case $item in ''|*[[:space:]]*) ;; *) BOOTMODS="$BOOTMODS${item//-/_} " ;; esac
          [ "$rest" != "$item" ] || break
          rest=${rest#*,}
        done
      done
    fi
  fi
  if [ -n "$BOOTMODS_ERR" ]; then
    info modules "boot-time module lists unreadable ($BOOTMODS_ERR) -- loaded modules without users count as missing"
    return 1
  fi
  return 0
}

# 사용자 없는 모듈 $2 의 별칭 경로(후속 F-A · 3라운드 R3-1): 지금 커널의 modinfo -k <RUNNING> -F alias 가운데 glob 글자(* ? [)가 없는 구체적인
#   별칭을 나온 순서대로 modprobe -S <$1> --show-depends 에 물어, 풀리고(MPQ=ok — exit 0 + insmod/builtin 줄만) 그 답의 모듈 가운데 m 의 계승자가
#   있는(alias_successor) 첫 별칭 → ALIAS_HIT 와 0. modinfo 가 실패하거나 · 구체적인 별칭이 없거나 · 그런 별칭이 하나도 없으면 1(없음 —
#   fail-closed). 풀리기만 해서는 세지 않는다 — MODULE_ALIAS_CRYPTO 가 함께 선언하는 맨 이름(sm4 · crc32)은 이름이 같은 다른 모듈로 풀리고, 여럿이
#   선언하는 별칭(crypto-stdrng · net-pf-40)은 지금 커널에도 있던 형제로 풀린다; 둘 다 m 의 기능을 잇는다는 근거가 아니다. '-' 로 시작하는 별칭은
#   modprobe 가 옵션으로 읽으므로 묻지 않는다. 별칭에 대한 이상한 답(bad — 예: 블랙리스트된 별칭의 대상은 exit 0 · 빈 출력)은 그 별칭이 풀리지 않은
#   것으로 본다(modprobe 자체는 확인 질의가 이미 확인했다).
alias_resolves() {
  local k=$1 m=$2 out rc a
  local -a als=()
  ALIAS_HIT=""
  out=$(modinfo -k "$RUNNING" -F alias "$m" 2>/dev/null)
  rc=$?
  [ "$rc" -eq 0 ] || return 1
  mapfile -t als <<< "$out"
  for a in "${als[@]}"; do
    case $a in ''|-*|*'*'*|*'?'*|*'['*) continue ;; esac
    mp_query "$k" "$a"
    if [ "$MPQ" = ok ] && alias_successor "$k" "$a"; then ALIAS_HIT=$a; return 0; fi
  done
  return 1
}

# alias_resolves 의 mp_query 직후(MPQ_MODS = 별칭 $2 의 답이 k 에서 적재할 모듈 · 내장): 그 가운데 하나라도 m 의 계승자면 0 — k 에서 별칭 $2 를
#   스스로 선언하고(modinfo -k <k> -F alias), 지금 커널에 같은 이름으로 있으면서 이미 그 별칭을 선언하던 형제가 아니다. 계승자가 아닌 예(2026-10-07
#   실제 6.17.0-1020 · 7.0.0-1012 oracle 트리): 'sm4' = SM4 라이브러리 모듈(별칭 없음) · 'crc32' = crc32_cryptoapi 가 빠진 커널에서는 내장
#   lib crc32(별칭 없음) · crypto-stdrng = 6.17 에도 내장이던 drbg · net-pf-40 = 두 커널에 다 있는 vsock 전송 셋. 계승자인 예:
#   crypto-blake2b-512 = 7.0 에 새로 생긴 blake2b · crypto-sha3-512 = 7.0 의 내장 sha3. modinfo -F name 은 이름이 별칭으로 풀리면 다른 이름이나 여러
#   줄을 낸다(6.17 의 crc32 → crc32_cryptoapi · net-pf-40 → 셋) — 정확히 같은 한 줄일 때만 '같은 이름의 모듈'로 본다.
alias_successor() {
  local k=$1 a=$2 x ka rn ra rc
  for x in $MPQ_MODS; do
    ka=$(modinfo -k "$k" -F alias "$x" 2>/dev/null) || continue
    case $NL$ka$NL in *"$NL$a$NL"*) ;; *) continue ;; esac
    # 지금 커널 쪽 조회의 실패는 둘로 나눈다: 'Module <x> not found.'(kmod 31 — 지금 커널에 그 이름이 없다 = 새 모듈)만 계승자 후보이고, 그 밖의
    #   실패(모듈 파일 · modules.builtin.modinfo 를 읽지 못함 — 'could not get modinfo from ...')는 형제인지 알 수 없으므로 세지 않는다(fail-closed —
    #   2026-10-07 실측: 손상된 지금 커널 트리에서 이 실패는 형제를 '새 모듈'로 보이게 해 잘못된 대체됨을 냈다).
    rn=$(modinfo -k "$RUNNING" -F name "$x" 2>&1); rc=$?
    if [ "$rc" -ne 0 ]; then
      [ "$rn" = "modinfo: ERROR: Module $x not found." ] || continue
    else
      case $NL$rn in *"${NL}modinfo:"*) continue ;; esac
      if [ "${rn//-/_}" = "$x" ]; then
        ra=$(modinfo -k "$RUNNING" -F alias "$x" 2>/dev/null) || continue
        case $NL$ra$NL in *"$NL$a$NL"*) continue ;; esac
      fi
    fi
    return 0
  done
  return 1
}

# 모듈 $1 이 부팅 때 이름으로 적재되는 목록에 없다(목록을 판단할 수 없으면 '있다'로 본다 — fail-closed).
boot_unlisted() {
  read_boot_modules || return 1
  [[ $BOOTMODS != *" ${1//-/_} "* ]]
}

# modprobe -S <k> --show-depends <이름> 한 번 → MPQ: ok(exit 0 · insmod/builtin 줄만, 하나 이상 — k 의 modules.dep 이 아는 사슬이다; depmod 가 뺀
#   풀리지 않는 심볼 의존은 여기에 보이지 않는다) · no(exit 1 · 'modprobe: FATAL: Module ... not found in directory ...' 줄) · bad(그 밖 — 이
#   modprobe 의 답을 믿을 수 없다; 사유는 MPQ_WHY). MPQ_MODS = 그 답이 k 에서 적재할 모듈 · 내장의 이름(insmod 경로의 파일 이름 · builtin 줄의 이름,
#   '-' 는 '_' 로, 나온 순서대로 — 별칭 경로의 계승자 확인(alias_successor)이 쓴다; MPQ=ok 일 때만 뜻이 있다).
#   모양은 2026-10-06 kmod 31(noble)과 실제 6.17.0-1020 · 7.0.0-1012 oracle 모듈 트리로 확인했다(-S 를 모르는 modprobe 는 exit 1 'invalid option';
#   insmod 줄은 '<경로> ' 처럼 끝에 공백이 붙고, builtin 줄은 'builtin drbg' 처럼 이름만 — 2026-10-07 재확인).
mp_query() {
  local k=$1 n=$2 out rc line x good=0 nf=0 odd=""
  MPQ=bad; MPQ_WHY=""; MPQ_MODS=""
  out=$(modprobe -S "$k" --show-depends "$n" 2>&1)
  rc=$?
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case $line in
      'insmod /'*) good=$((good + 1)); x=${line#insmod }; x=${x%% *}; x=${x##*/}; x=${x%%.ko*}; MPQ_MODS="$MPQ_MODS ${x//-/_}" ;;
      'builtin '*) good=$((good + 1)); x=${line#builtin }; x=${x%% *}; MPQ_MODS="$MPQ_MODS ${x//-/_}" ;;
      'modprobe: FATAL: Module '*' not found in directory '*) nf=$((nf + 1)) ;;
      *) [ -n "$odd" ] || odd=$line ;;
    esac
  done <<< "$out"
  if [ "$rc" -eq 0 ] && [ "$good" -gt 0 ] && [ "$nf" -eq 0 ] && [ -z "$odd" ]; then MPQ=ok; return 0; fi
  if [ "$rc" -eq 1 ] && [ "$nf" -gt 0 ] && [ "$good" -eq 0 ]; then MPQ=no; return 0; fi
  if [ -z "$odd" ]; then first_line "$out"; odd=${FIRST:-no output}; fi
  MPQ_WHY="modprobe -S $k --show-depends $n: exit $rc: $odd"
  return 0
}

# 지금 적재된 모듈을 커널 $1 에 대해 판정한다(머리 주석의 '모듈 검사') → MISSING(없음) · ACCOUNTED('m->u1+u2' 사용자 경로 · 'm=<별칭>' 별칭
#   경로 — 둘 다 대체됨) · NAME_MISS(이름으로 못 찾은 수 = 둘의 합) · MP_FALLBACK(비어 있지 않으면 modprobe 를 쓸 수 없어 이름 기준만 썼다 — 그 사유; INFO
#   한 줄을 사유마다 한 번 낸다). 이름 · 사용자는 사전순. 내장 모듈은 modinfo 가 modules.builtin 으로 찾는다.
missing_modules_for() {
  local k=$1 m u i j c entry ok_all
  local -a names=()
  MISSING=(); ACCOUNTED=(); NAME_MISS=0; MP_FALLBACK=""
  for m in "${LOADED[@]}"; do
    modinfo -k "$k" "$m" >/dev/null 2>&1 || names+=("$m")
  done
  NAME_MISS=${#names[@]}
  [ "$NAME_MISS" -gt 0 ] || return 0
  sort_words "${names[@]}"; names=("${SORTED[@]}")
  # modprobe 를 믿을 수 있는가: 없거나, 이름으로 못 찾은 첫 모듈을 물었을 때 'not found' 로 답하지 않으면(-S 를 모른다 · modinfo 와 어긋난다)
  #   이름 기준만 쓴다.
  if ! command -v modprobe >/dev/null 2>&1; then MP_FALLBACK="not on PATH"
  else
    mp_query "$k" "${names[0]}"
    case $MPQ in
      no) ;;
      ok) MP_FALLBACK="modprobe -S $k finds ${names[0]} but modinfo -k $k does not" ;;
      *) MP_FALLBACK=$MPQ_WHY ;;
    esac
  fi
  if [ -z "$MP_FALLBACK" ]; then
    for m in "${names[@]}"; do
      j=-1
      for i in "${!LOADED[@]}"; do if [ "${LOADED[i]}" = "$m" ]; then j=$i; break; fi; done
      if [ "$j" -lt 0 ]; then MISSING+=("$m"); continue; fi
      c=${LOADED_CNT[j]}
      if ! [[ $c =~ ^[0-9]+$ ]] || ! parse_users "${LOADED_BY[j]}"; then MISSING+=("$m"); continue; fi
      if [ "${#USERS[@]}" -gt 0 ]; then
        # 대체됨: 사용자 전부가 k 의 modules.dep 에 있다(하나라도 'not found' 면 없음; modprobe 의 답을 믿을 수 없으면 이 커널 전체가 이름 기준).
        sort_words "${USERS[@]}"
        entry=""; ok_all=1
        for u in "${SORTED[@]}"; do
          mp_query "$k" "$u"
          case $MPQ in
            ok) entry="$entry+$u" ;;
            no) ok_all=0; break ;;
            *) MP_FALLBACK=$MPQ_WHY; break 2 ;;
          esac
        done
        if [ "$ok_all" = 1 ]; then ACCOUNTED+=("$m->${entry#+}"); else MISSING+=("$m"); fi
      elif ! boot_unlisted "$m"; then
        # 사용자 없음 + 부팅 때 이름으로 적재된다(또는 목록을 판단할 수 없다) → 없음.
        MISSING+=("$m")
      elif alias_resolves "$k" "$m"; then
        # 사용자 없음: 사용 수와 무관하게 별칭으로 판정한다(후속 F-A — 사용 수 0 은 '안 쓰임'이 아니다: 노드의 wireguard 는 쓰는 중에도 0).
        ACCOUNTED+=("$m=$ALIAS_HIT")
      else
        MISSING+=("$m")
      fi
    done
  fi
  if [ -n "$MP_FALLBACK" ]; then
    MISSING=("${names[@]}"); ACCOUNTED=()
    case $MP_NOTED in
      *"|$MP_FALLBACK|"*) ;;
      *) MP_NOTED="$MP_NOTED|$MP_FALLBACK|"; info modules "modprobe unavailable ($MP_FALLBACK) -- name check only" ;;
    esac
  fi
  return 0
}

# MISSING 과 ACCEPT_LIST 의 차이 → ACCEPT_DIFF('missing but not accepted: a b; accepted but not missing: c' — 빈 쪽은 뺀다; 메시지용 — 판정은
#   부른 쪽이 사전순 목록을 그대로 비교한다).
accept_diff() {
  local m a hit notacc="" notmiss=""
  for m in "${MISSING[@]}"; do
    hit=0; for a in "${ACCEPT_LIST[@]}"; do if [ "$a" = "$m" ]; then hit=1; break; fi; done
    [ "$hit" = 1 ] || notacc="$notacc $m"
  done
  for a in "${ACCEPT_LIST[@]}"; do
    hit=0; for m in "${MISSING[@]}"; do if [ "$m" = "$a" ]; then hit=1; break; fi; done
    [ "$hit" = 1 ] || notmiss="$notmiss $a"
  done
  ACCEPT_DIFF=""
  if [ -n "$notacc" ]; then ACCEPT_DIFF="missing but not accepted:$notacc"; fi
  if [ -n "$notmiss" ]; then ACCEPT_DIFF="${ACCEPT_DIFF:+$ACCEPT_DIFF; }accepted but not missing:$notmiss"; fi
  return 0
}

# 커널 $1 의 파일: vmlinuz · initrd 는 비어 있지 않은 일반 파일(-s), modules 는 디렉터리 → 문제가 있으면 KF_ERR 와 1.
kernel_files_problem() {
  local k=$1 f miss="" empty=""
  for f in "vmlinuz-$k" "initrd.img-$k"; do
    if [ ! -f "$BOOT_DIR/$f" ]; then miss="$miss /boot/$f"
    elif [ ! -s "$BOOT_DIR/$f" ]; then empty="$empty /boot/$f"; fi
  done
  [ -d "$MODULES_DIR/$k" ] || miss="$miss /lib/modules/$k/"
  KF_ERR=""
  if [ -n "$miss" ]; then KF_ERR="missing$miss"; fi
  if [ -n "$empty" ]; then KF_ERR="${KF_ERR:+$KF_ERR, }empty$empty"; fi
  [ -z "$KF_ERR" ]
}

# ---------- 패키지 작업 · 잔여 파일 ----------
# 패키지 작업 판정 → PKG_BUSY(1 = 작업 중 또는 판단 불가) · PKG_ITEMS('이름(PID)' · grub.cfg.new · pgrep 실패) · PKG_IGNORED(종료 대기 도우미) ·
#   PKG_CFGNEW_ONLY(1 = 프로세스는 없고 grub.cfg.new 만 있다 — 실패하거나 죽은 grub-mkconfig 의 오래된 잔여물).
#   이름마다 pgrep -a -x 를 한 번씩 부른다: 1 = 없음, 0 = 'PID 명령 줄' 줄들, 그 밖(없는 pgrep 의 127 포함) = 판단 불가 — 거기서 멈춘다.
#   $1 = procs 면 프로세스만 본다(되돌리기 · 복원 직전: 방금 실패한 우리 update-grub 이 남긴 grub.cfg.new 는 겹칠 상대가 아니다).
check_package_activity() {
  local n out rc line pid args seen items="" ignored="" what=${1-all}
  PKG_BUSY=0; PKG_ITEMS=""; PKG_IGNORED=""; PKG_CFGNEW_ONLY=0
  for n in "${PKG_NAMES[@]}"; do
    out=$(pgrep -a -x "$n" 2>&1)
    rc=$?
    if [ "$rc" -eq 1 ]; then continue; fi
    if [ "$rc" -ne 0 ]; then
      first_line "$out"
      items="$items pgrep-failed($n: exit $rc${FIRST:+: $FIRST})"
      break
    fi
    seen=0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      seen=1
      pid=${line%%[[:space:]]*}
      args=""
      if [[ $line == *[[:space:]]* ]]; then args=${line#*[[:space:]]}; fi
      if ! [[ $pid =~ ^[0-9]+$ ]]; then items="$items pgrep-unparsable($n: $line)"; continue; fi
      if [ "$n" = 'unattended-upgr' ] && [ "$args" = "$UU_IDLE_HELPER" ]; then ignored="$ignored $n($pid)"; continue; fi
      items="$items $n($pid)"
    done <<< "$out"
    if [ "$seen" = 0 ]; then items="$items pgrep-failed($n: exit 0 without a process)"; fi
  done
  if [ "$what" != procs ] && { [ -e "$GRUB_CFG_NEW" ] || [ -L "$GRUB_CFG_NEW" ]; }; then
    if [ -z "$items" ]; then PKG_CFGNEW_ONLY=1; fi
    items="$items $D_GRUB_CFG_NEW"
  fi
  PKG_ITEMS=${items# }
  PKG_IGNORED=${ignored# }
  if [ -n "$PKG_ITEMS" ]; then PKG_BUSY=1; fi
  return 0
}

report_ignored_helpers() {
  if [ -n "$PKG_IGNORED" ]; then info "package activity ignored" "$PKG_IGNORED -- the idle unattended-upgrade-shutdown --wait-for-signal helper, not package work"; fi
  return 0
}

# 쓰기 전 가드: 작업 중이면 FAIL(찾은 이름과 PID). 프로세스 없이 grub.cfg.new 만 있으면 기다려도 사라지지 않는다 — 치우는 방법을 적는다.
guard_package_activity() {
  check_package_activity
  report_ignored_helpers
  if [ "$PKG_BUSY" = 1 ]; then
    if [ "$PKG_CFGNEW_ONLY" = 1 ]; then
      fail "package activity" "$PKG_ITEMS -- refusing to write; no package process runs, so it is a stale leftover of a failed or killed grub-mkconfig: run 'sudo update-grub' one time (it replaces the file), then run status and retry"
    else
      fail "package activity" "$PKG_ITEMS -- refusing to write; run status, wait until it shows 'package activity: none', then retry"
    fi
    SUMMARY="refused: package activity ($PKG_ITEMS); nothing changed"
    return 1
  fi
  ok "package activity" "none"
  return 0
}

# update-grub 직전 재확인(가드와 호출 사이의 창을 줄인다). 작업이 보이면 1 — 부른 쪽이 쓴 것을 되돌린다.
recheck_package_activity() {
  check_package_activity
  if [ "$PKG_BUSY" = 1 ]; then fail "package activity" "$PKG_ITEMS appeared right before update-grub -- update-grub not run"; return 1; fi
  ok "package activity" "none right before update-grub"
  return 0
}

# update-grub 이 exit 0 으로 돌아온 직후(사후 검증 전) 재확인(수정 2 L1): 패키지 프로세스가 보이면 그 훅의 update-grub 이 우리 것과 겹쳤을 수
#   있다 — 늦게 시작한 쪽이 쓰다 멈춘 파일이 grub.cfg 로 설치되면 꼬리 섹션이 빠지는데 기본값과 0 번 항목은 맞아 사후 검증을 통과한다.
#   보이면 FAIL 과 1 — 부른 쪽은 검증 · 되돌리기를 하지 않는다(겹친 훅이 아직 쓰고 있을 수 있다). 프로세스만 본다(grub.cfg.new 는 그 훅의 것이다).
postcheck_package_activity() {
  check_package_activity procs
  if [ "$PKG_BUSY" = 1 ]; then fail "package activity" "$PKG_ITEMS while update-grub ran -- grub.cfg may be partial; do not reboot -- $FIX_LINE"; return 1; fi
  ok "package activity" "none right after update-grub"
  return 0
}

# 죽은 실행이 남길 수 있는 것: 고정 파일의 임시 이름(.kernel-trial-pin.XXXXXX) · 치워 둔 이름(.kernel-trial-pin.aside.XXXXXX) · grub.cfg.new.
#   점으로 시작하고 .cfg 가 아니라 grub-mkconfig 는 읽지 않는다(GRUB 에는 해가 없다) → LEFTOVERS(표시용 경로).
list_leftovers() {
  local f out=""
  for f in "$GRUBD"/.kernel-trial-pin.*; do
    if [ -e "$f" ] || [ -L "$f" ]; then out="$out ${f#"$R"}"; fi
  done
  if [ -e "$GRUB_CFG_NEW" ] || [ -L "$GRUB_CFG_NEW" ]; then out="$out $D_GRUB_CFG_NEW"; fi
  LEFTOVERS=${out# }
  return 0
}

# initrd 없는 부팅 폴백(grub.cfg 의 'set partuuid='). load_menu 뒤에 부른다. 켜져 있으면 FAIL 줄과 1.
report_partuuid() {
  if [ "$PARTUUID_LINES" -eq 0 ]; then ok "initrdless-boot fallback" "off (no 'set partuuid=' in grub.cfg)"; return 0; fi
  fail "initrdless-boot fallback" "on ($PARTUUID_LINES 'set partuuid=' line(s)) -- submenu entries boot without an initrd and are never retried; pin/trial are not supported here"
  return 1
}

# grubenv 의 initrdfail · prev_entry(initrd 없는 부팅 폴백의 상태). read_grubenv 뒤에 부른다.
initrd_fallback_set() { [ -n "$INITRDFAIL" ] || [ -n "$PREV_ENTRY" ]; }
check_initrd_fallback() {
  if initrd_fallback_set; then
    fail "initrd fallback" "grubenv initrdfail=\"$INITRDFAIL\" prev_entry=\"$PREV_ENTRY\" -- GRUB's initrd-less boot fallback may override the next boot; pin/trial refuse while either is set -- $INITRD_HINT"
    return 1
  fi
  ok "initrd fallback" "grubenv initrdfail and prev_entry are empty"
  return 0
}

# ---------- 가드 ----------
guard_root() {
  local uid
  uid=$(id -u 2>/dev/null) || uid=""
  if [ "$uid" = 0 ]; then ok root "uid 0"; return 0; fi
  fail root "uid ${uid:-unknown} -- run with sudo"
  SUMMARY="refused: not root; nothing changed"
  return 1
}

need_tools() {
  local t missing=""
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing="$missing $t"; done
  if [ -n "$missing" ]; then fail tools "not found on PATH:$missing"; SUMMARY="refused: missing tools; nothing changed"; return 1; fi
  return 0
}

# 커널 $1 의 파일 가드. $2 = 줄의 주제(기본 'kernel files').
check_kernel_files() {
  local k=$1 topic=${2:-kernel files}
  if ! kernel_files_problem "$k"; then fail "$topic" "$k: $KF_ERR"; return 1; fi
  ok "$topic" "$k has /boot/vmlinuz-$k, /boot/initrd.img-$k and /lib/modules/$k/"
  return 0
}

# ---------- 쓰기 · 검증 · 되돌리기 ----------
# update-grub 의 출력(stdout+stderr)은 INFO 줄로 옮긴다 → UG_RC
run_update_grub() {
  local out line
  out=$(update-grub 2>&1)
  UG_RC=$?
  while IFS= read -r line; do [ -n "$line" ] && info update-grub "$line"; done <<< "$out"
  return 0
}

# 지금 상태 한 줄 → STATE_TEXT
state_text() {
  local p=absent
  [ -e "$PIN_FILE" ] && p=present
  load_menu
  if [ -n "$MENU_ERR" ]; then STATE_TEXT="pin file $p, grub.cfg unreadable ($MENU_ERR)"
  elif [ "$NE_BLOCKS" -ne 1 ]; then STATE_TEXT="pin file $p, grub.cfg next_entry logic found $NE_BLOCKS times"
  else STATE_TEXT="pin file $p, grub.cfg default \"$CFG_DEFAULT\""
  fi
}

# 고정 파일을 같은 디렉터리의 임시 파일 + mv(rename) 로 쓴다. 이름이 점으로 시작하고 .cfg 가 아니라 grub-mkconfig 는 임시 파일을 읽지 않는다.
write_pin_file() {
  local k=$1 tmp out rc
  if [ ! -d "$GRUBD" ]; then fail write "$D_GRUBD is not a directory"; return 1; fi
  tmp=$(mktemp "$GRUBD/.kernel-trial-pin.XXXXXX" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then first_line "$tmp"; fail write "mktemp in $D_GRUBD failed: $FIRST"; return 1; fi
  if ! { printf '%s\n' "# Managed by infra/bootstrap/kernel-trial.sh: boot the verified kernel $k by default." "# Remove only with: kernel-trial.sh unpin" "GRUB_DEFAULT=\"$ID_PATH\"" > "$tmp"; } 2>/dev/null; then
    rm -f -- "$tmp"; fail write "cannot write the temp pin file in $D_GRUBD"; return 1
  fi
  out=$(chmod 0644 "$tmp" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then rm -f -- "$tmp"; first_line "$out"; fail write "chmod failed: $FIRST"; return 1; fi
  out=$(mv -f "$tmp" "$PIN_FILE" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then rm -f -- "$tmp"; first_line "$out"; fail write "mv to $D_PIN_FILE failed: $FIRST"; return 1; fi
  info write "$D_PIN_FILE: GRUB_DEFAULT=\"$ID_PATH\""
  return 0
}

# pin 검증: update-grub 뒤 else 가지가 정확히 기대 값이고, 그 값이 여전히 정확히 하나씩인 ID 들을 지나 같은 커널로 풀린다.
#   실패 줄에는 수동 복구를 적는다(다른 update-grub 이 겹쳤을 수 있다).
verify_pinned() {
  local k=$1 why=""
  if ! load_menu; then why=$MENU_ERR
  elif [ "$NE_BLOCKS" -ne 1 ]; then why="next_entry logic found $NE_BLOCKS times after update-grub (want exactly 1)"
  elif [ "$CFG_DEFAULT" != "$ID_PATH" ]; then why="grub.cfg default is \"$CFG_DEFAULT\", want \"$ID_PATH\""
  elif ! resolve_value "$CFG_DEFAULT"; then why="grub.cfg default does not resolve: $RESOLVE_ERR"
  elif [ "$RESOLVED" != "$k" ]; then why="grub.cfg default boots $RESOLVED, not $k"
  fi
  if [ -n "$why" ]; then fail verify "$why -- $FIX_LINE"; return 1; fi
  ok verify "grub.cfg default is \"$CFG_DEFAULT\" -> $k (ids unique)"
  return 0
}

# pin 의 update-grub 직전에 패키지 작업이 보였다: 방금 쓴 고정 파일만 지운다(grub.cfg 는 아직 그대로라 원래 상태가 된다).
undo_pin_write() {
  local out rc
  out=$(rm -f -- "$PIN_FILE" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ] || [ -e "$PIN_FILE" ]; then
    first_line "$out"; state_text
    fail undo "cannot remove the pin file ($FIRST); state now: $STATE_TEXT -- $FIX_LINE"
    SUMMARY="refused: package activity right before update-grub, and the pin file could not be removed; state now: $STATE_TEXT"
    return 1
  fi
  # 이미 고정 파일을 읽은 훅이 끝나며 기본값을 고정 ID 로 쓸 수 있다(부팅은 안전 · 다음 status 가 INCONSISTENT 로 잡는다 — 수정 2 L2).
  ok undo "pin file removed again; grub.cfg untouched -- run status again after the package work ends"
  SUMMARY="refused: package activity right before update-grub ($PKG_ITEMS); pin file removed again; nothing changed"
  return 0
}

# pin 되돌리기: 고정 파일 삭제 → (패키지 작업이 보이면 멈춘다) → update-grub → 기본값 "0" 확인.
rollback_pin() {
  local out rc
  info rollback "removing $D_PIN_FILE and running update-grub again"
  out=$(rm -f -- "$PIN_FILE" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ] || [ -e "$PIN_FILE" ]; then
    first_line "$out"; state_text
    fail rollback "cannot remove the pin file ($FIRST); state now: $STATE_TEXT"
    SUMMARY="pin failed and the rollback failed; state now: $STATE_TEXT"
    info "next step" "fix this before any reboot: make $D_PIN_FILE and $D_GRUB_CFG agree (run status)"
    return 1
  fi
  # 되돌리기의 update-grub 도 다른 update-grub 과 겹치지 않게 한다 — 겹쳐 돌리느니 멈추고 수동 복구를 적는다(프로세스만 본다).
  check_package_activity procs
  if [ "$PKG_BUSY" = 1 ]; then
    state_text
    fail rollback "package activity $PKG_ITEMS -- update-grub not run again; state now: $STATE_TEXT -- $FIX_LINE"
    SUMMARY="pin failed and the rollback could not finish (package activity); state now: $STATE_TEXT"
    return 1
  fi
  run_update_grub
  rc=$UG_RC
  load_menu
  if [ "$rc" -eq 0 ] && [ -z "$MENU_ERR" ] && [ "$NE_BLOCKS" -eq 1 ] && [ "$CFG_DEFAULT" = 0 ]; then
    ok rollback "pin file removed; grub.cfg default is \"0\" again"
    SUMMARY="pin failed (see FAIL lines) and was rolled back: no pin file, grub.cfg default \"0\""
    return 0
  fi
  state_text
  if [ "$rc" -ne 0 ]; then fail rollback "update-grub exit $rc; state now: $STATE_TEXT"
  else fail rollback "grub.cfg default is not \"0\" after update-grub; state now: $STATE_TEXT"; fi
  SUMMARY="pin failed and the rollback failed; state now: $STATE_TEXT"
  info "next step" "fix this before any reboot: fix the update-grub error, run update-grub, then run status"
  return 1
}

# unpin 검증: else 가지가 "0" 이고 0 번 항목이 지금 돌고 있는(검증된) 커널이다. 실패 줄에는 수동 복구를 적는다.
verify_unpinned() {
  local why=""
  if ! load_menu; then why=$MENU_ERR
  elif [ "$NE_BLOCKS" -ne 1 ]; then why="next_entry logic found $NE_BLOCKS times after update-grub (want exactly 1)"
  elif [ "$CFG_DEFAULT" != 0 ]; then why="grub.cfg default is \"$CFG_DEFAULT\", want \"0\""
  elif ! resolve_value 0; then why="entry 0 does not resolve: $RESOLVE_ERR"
  elif [ "$RESOLVED" != "$RUNNING" ]; then why="entry 0 boots $RESOLVED, not the running kernel $RUNNING"
  fi
  if [ -n "$why" ]; then fail verify "$why -- $FIX_LINE"; return 1; fi
  ok verify "grub.cfg default is \"0\" -> $RESOLVED"
  return 0
}

# unpin 의 update-grub 직전에 패키지 작업이 보였다: 치워 둔 고정 파일만 제자리로(grub.cfg 는 아직 그대로라 원래 상태가 된다).
undo_unpin_aside() {
  local aside=$1 out rc
  out=$(mv -f "$aside" "$PIN_FILE" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ] || [ ! -f "$PIN_FILE" ]; then
    first_line "$out"; state_text
    fail undo "cannot move ${aside#"$R"} back ($FIRST); state now: $STATE_TEXT; the pin content is in ${aside#"$R"} -- move it back to $D_PIN_FILE by hand, then $FIX_LINE"
    SUMMARY="refused: package activity right before update-grub, and the pin file could not be moved back; state now: $STATE_TEXT"
    return 1
  fi
  # 고정 파일이 없던 사이에 그것을 읽은 훅이 끝나며 기본값을 "0" 으로 쓸 수 있다(다음 status 가 INCONSISTENT 로 잡는다 — 수정 2 L2).
  ok undo "pin file moved back; grub.cfg untouched -- run status again after the package work ends"
  SUMMARY="refused: package activity right before update-grub ($PKG_ITEMS); pin file moved back; nothing changed"
  return 0
}

# unpin 되돌리기: 치워 둔 고정 파일을 제자리로 → (패키지 작업이 보이면 멈춘다) → update-grub → 기본값 = 고정 값 확인.
restore_pin() {
  local aside=$1 out rc
  info restore "moving the pin file back and running update-grub again"
  out=$(mv -f "$aside" "$PIN_FILE" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ] || [ ! -f "$PIN_FILE" ]; then
    first_line "$out"; state_text
    fail restore "cannot move ${aside#"$R"} back ($FIRST); state now: $STATE_TEXT; the pin content is in ${aside#"$R"}"
    SUMMARY="unpin failed and the restore failed; state now: $STATE_TEXT"
    info "next step" "fix this before any reboot: move ${aside#"$R"} back to $D_PIN_FILE, run update-grub, then run status"
    return 1
  fi
  # 복원의 update-grub 도 다른 update-grub 과 겹치지 않게 한다(프로세스만 본다).
  check_package_activity procs
  if [ "$PKG_BUSY" = 1 ]; then
    state_text
    fail restore "package activity $PKG_ITEMS -- update-grub not run again; state now: $STATE_TEXT -- $FIX_LINE"
    SUMMARY="unpin failed and the restore could not finish (package activity); state now: $STATE_TEXT"
    return 1
  fi
  run_update_grub
  rc=$UG_RC
  load_menu
  if [ "$rc" -eq 0 ] && [ -z "$MENU_ERR" ] && [ "$NE_BLOCKS" -eq 1 ] && [ "$CFG_DEFAULT" = "$PIN_VALUE" ]; then
    ok restore "pin file restored; grub.cfg default is the pinned value \"$PIN_VALUE\""
    SUMMARY="unpin failed (see FAIL lines) and was undone: pin file back, grub.cfg default is the pinned value"
    return 0
  fi
  state_text
  if [ "$rc" -ne 0 ]; then fail restore "update-grub exit $rc; state now: $STATE_TEXT"
  else fail restore "grub.cfg default is not the pinned value after update-grub; state now: $STATE_TEXT"; fi
  SUMMARY="unpin failed and the restore did not finish; state now: $STATE_TEXT"
  info "next step" "before any reboot: fix the update-grub error, run update-grub, then run status"
  return 1
}

# grubenv 를 list 로 다시 읽어 next_entry 가 정확히 $1 인지 본다.
verify_next_entry() {
  if ! read_grubenv; then fail verify "cannot read grubenv back: $GE_ERR"; return 1; fi
  if [ "$NEXT_ENTRY" != "$1" ]; then fail verify "next_entry is \"$NEXT_ENTRY\", want \"$1\""; return 1; fi
  ok verify "next_entry is exactly \"$1\""
  return 0
}

# next_entry 를 unset 하고 비었는지 다시 읽어 본다. $1 = 줄의 주제.
clear_next_entry() {
  local topic=$1 out rc
  out=$(grub-editenv "$GRUBENV" unset next_entry 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then first_line "$out"; fail "$topic" "grub-editenv unset next_entry exit $rc: $FIRST"; fi
  if ! read_grubenv; then fail "$topic" "cannot read grubenv back: $GE_ERR -- the next boot may still use next_entry; run status"; return 1; fi
  if [ -n "$NEXT_ENTRY" ]; then fail "$topic" "next_entry is still \"$NEXT_ENTRY\" -- the next boot will use it; run cancel-trial"; return 1; fi
  ok "$topic" "next_entry is empty"
  [ "$rc" -eq 0 ]
}

# ---------- 판정 ----------
refresh_state() {
  load_menu
  read_pin_file
  read_grubenv
  return 0
}

# 고정 판정(복구용 커널): 고정 값이 커널 $1 의 -advanced- 항목 경로(= pin 이 그 커널에 쓰는 값 — 복구 모드 · 다른 항목이 아니다)이고
#   그 커널의 vmlinuz · initrd 가 비어 있지 않다 → 아니면 PE_ERR 와 1. find_ids 의 전역(ID_PATH 등)을 바꾼다.
pin_entry_ok() {
  local k=$1
  PE_ERR=""
  if ! find_ids "$k"; then PE_ERR="pinned kernel $k: $IDS_ERR"; return 1; fi
  if [ "$PIN_VALUE" != "$ID_PATH" ]; then PE_ERR="pin value \"$PIN_VALUE\" is not the -advanced- entry of $k (want \"$ID_PATH\"; recovery mode or another entry)"; return 1; fi
  if ! kernel_files_problem "$k"; then PE_ERR="pinned kernel $k: $KF_ERR"; return 1; fi
  return 0
}

# GRUB 이 실제로 할 일(V_NEXT · V_LATER)과 고정의 일관성(V_PIN_OK · V_PIN_TEXT). 호출 전에 load_menu · read_pin_file · read_grubenv.
evaluate_verdict() {
  V_NEXT=unknown; V_NEXT_HOW=default; V_LATER=unknown; V_PIN_OK=0; V_PIN_TEXT=""
  local reason="" dres=1 nres=1 derr="" nerr=""
  if [ -z "$MENU_ERR" ] && [ "$NE_BLOCKS" -eq 1 ]; then
    if resolve_value "$CFG_DEFAULT"; then V_LATER=$RESOLVED; dres=0; else derr=$RESOLVE_ERR; fi
    if [ "$GE_OK" = 1 ] && [ -n "$NEXT_ENTRY" ]; then
      V_NEXT_HOW="one-shot next_entry"
      if resolve_value "$NEXT_ENTRY"; then V_NEXT=$RESOLVED; nres=0; else nerr=$RESOLVE_ERR; fi
    elif [ "$GE_OK" = 1 ]; then
      V_NEXT=$V_LATER
    fi
  fi
  if [ -n "$MENU_ERR" ]; then reason=$MENU_ERR
  elif [ "$NE_BLOCKS" -ne 1 ]; then reason="next_entry logic found $NE_BLOCKS times in $D_GRUB_CFG (want exactly 1)"
  elif [ "$PIN_PRESENT" = 1 ] && [ -n "$PIN_ERR" ]; then reason="pin file malformed: $PIN_ERR"
  elif [ "$PIN_PRESENT" = 1 ] && [ "$PIN_VALUE" != "$CFG_DEFAULT" ]; then reason="pin file says \"$PIN_VALUE\" but grub.cfg default is \"$CFG_DEFAULT\" (update-grub not run or failed) -- $FIX_LINE"
  elif [ "$PIN_PRESENT" = 0 ] && [ "$CFG_DEFAULT" != 0 ]; then reason="no pin file but grub.cfg default is \"$CFG_DEFAULT\" (want \"0\") -- $FIX_LINE"
  elif [ "$dres" -ne 0 ]; then reason="grub.cfg default \"$CFG_DEFAULT\" does not resolve to one kernel entry: $derr"
    menu_has_kernel || reason="$reason -- $EMPTY_MENU_HINT"
  elif [ "$GE_OK" != 1 ]; then reason="cannot read grubenv: $GE_ERR"
  elif [ -n "$NEXT_ENTRY" ] && [ "$nres" -ne 0 ]; then reason="next_entry \"$NEXT_ENTRY\" does not resolve to one kernel entry: $nerr"
  elif initrd_fallback_set; then reason="grubenv initrdfail=\"$INITRDFAIL\" prev_entry=\"$PREV_ENTRY\" (GRUB's initrd-less boot fallback may override the next boot shown here) -- $INITRD_HINT"
  elif [ "$PIN_PRESENT" = 1 ] && ! pin_entry_ok "$V_LATER"; then reason=$PE_ERR
  fi
  if [ -n "$reason" ]; then V_PIN_TEXT="INCONSISTENT ($reason)"; return 1; fi
  V_PIN_OK=1
  if [ "$PIN_PRESENT" = 1 ]; then V_PIN_TEXT="present -> $V_LATER"; else V_PIN_TEXT="absent"; fi
  return 0
}

print_verdict() {
  info "next boot" "$V_NEXT ($V_NEXT_HOW)"
  info "later boots" "$V_LATER"
  if [ "$V_PIN_OK" = 1 ]; then ok pin "$V_PIN_TEXT"; else fail pin "$V_PIN_TEXT"; fi
}

# ---------- status(읽기 전용) ----------
cmd_status() {
  need_tools uname grub-editenv sort awk || return
  if read_running; then info running "$RUNNING"; else fail running "uname -r gave '$RUNNING' (not a kernel version)"; fi
  if list_kernels; then info kernels "${#KERNELS[@]} installed (/boot/vmlinuz-*, sort -V): ${KERNELS[*]:-none}"; else KERNELS=(); fail kernels "cannot sort the /boot/vmlinuz-* list"; fi
  load_menu || fail grub.cfg "$MENU_ERR"
  local have_mods=0 newest="" k row ids miss acc tags vz ird md
  if ! command -v lsmod >/dev/null 2>&1 || ! command -v modinfo >/dev/null 2>&1; then LOADED_ERR="lsmod or modinfo not on PATH"
  elif read_loaded_modules; then have_mods=1; fi
  [ "${#KERNELS[@]}" -gt 0 ] && newest=${KERNELS[$((${#KERNELS[@]} - 1))]}
  for k in "${KERNELS[@]}"; do
    ids=0
    for row in "${MENU[@]}"; do
      split_row "$row"
      if [ "$RK" = M ] && [[ $RI == "gnulinux-$k-advanced-"* ]]; then ids=$((ids + 1)); fi
    done
    # missing-loaded-modules = 없음(키 · 모양은 수정 2 전과 같다), accounted = 이름으로 못 찾았지만 대체됨으로 설명된 것('m->u1+u2' · 'm=<별칭>').
    if [ "$have_mods" = 1 ]; then
      missing_modules_for "$k"
      miss=${#MISSING[@]}
      [ "${#MISSING[@]}" -gt 0 ] && miss="$miss (${MISSING[*]})"
      acc=${#ACCOUNTED[@]}
      [ "${#ACCOUNTED[@]}" -gt 0 ] && acc="$acc (${ACCOUNTED[*]})"
    else
      miss="unknown ($LOADED_ERR)"; acc=unknown
    fi
    tags=""
    [ "$k" = "$RUNNING" ] && tags="$tags [running]"
    [ "$k" = "$newest" ] && tags="$tags [newest]"
    file_yn "$BOOT_DIR/vmlinuz-$k"; vz=$YN
    file_yn "$BOOT_DIR/initrd.img-$k"; ird=$YN
    dir_yn "$MODULES_DIR/$k"; md=$YN
    info "kernel $k" "vmlinuz=$vz initrd=$ird modules-dir=$md menu-entry-ids=$ids missing-loaded-modules=$miss accounted=$acc$tags"
  done

  local p pkgs=""
  if [ -e "$REBOOT_REQ" ]; then
    if [ -f "$REBOOT_REQ.pkgs" ]; then
      while IFS= read -r p || [ -n "$p" ]; do [ -n "$p" ] && pkgs="$pkgs $p"; done < "$REBOOT_REQ.pkgs"
    fi
    info reboot-required "yes (pkgs:${pkgs:- none listed})"
  else
    info reboot-required "no"
  fi

  local f n line last=""
  for f in "$DEFAULT_GRUB" "$GRUBD"/*.cfg; do
    [ -f "$f" ] || continue
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      if [[ $line =~ $DEFLINE_RE ]]; then info grub-default-src "${f#"$R"}:$n: $line"; last="${f#"$R"}:$n"; fi
    done < "$f"
  done
  if [ -n "$last" ]; then info grub-default-src "effective = $last (read last by grub-mkconfig)"
  else info grub-default-src "none set (grub-mkconfig uses 0)"; fi

  if [ -z "$MENU_ERR" ]; then
    if [ "$NE_BLOCKS" -eq 1 ]; then
      info "grub.cfg next_entry logic" "present"
      info "grub.cfg default" "\"$CFG_DEFAULT\" (else branch of the next_entry block)"
    else
      fail "grub.cfg next_entry logic" "found $NE_BLOCKS blocks (want exactly 1)"
    fi
    report_partuuid
  fi

  read_pin_file
  if [ "$PIN_PRESENT" = 0 ]; then info "pin file" "absent ($D_PIN_FILE)"
  elif [ -n "$PIN_ERR" ]; then fail "pin file" "malformed ($D_PIN_FILE): $PIN_ERR"
  else info "pin file" "present ($D_PIN_FILE): GRUB_DEFAULT=\"$PIN_VALUE\""; fi

  if read_grubenv; then
    if [ -z "$GE_LIST" ]; then info grubenv "(no variables)"
    else while IFS= read -r line; do info grubenv "$line"; done <<< "$GE_LIST"; fi
  else
    fail grubenv "$GE_ERR"
  fi

  check_package_activity
  if [ "$PKG_BUSY" = 1 ]; then info "package activity" "$PKG_ITEMS -- pin/unpin/trial will refuse"
  else info "package activity" "none"; fi
  if [ "$PKG_CFGNEW_ONLY" = 1 ]; then
    info "package activity hint" "no package process runs, so $D_GRUB_CFG_NEW is a stale leftover of a failed or killed grub-mkconfig -- one successful 'sudo update-grub' replaces it"
  fi
  report_ignored_helpers
  list_leftovers
  info leftovers "${LEFTOVERS:-none}"

  local ac v=""
  if command -v apt-config >/dev/null 2>&1 && ac=$(apt-config dump Unattended-Upgrade::Automatic-Reboot 2>/dev/null); then
    while IFS= read -r line; do
      case $line in 'Unattended-Upgrade::Automatic-Reboot '*) v=${line#Unattended-Upgrade::Automatic-Reboot } ;; esac
    done <<< "$ac"
    v=${v%;}
    info auto-reboot "Unattended-Upgrade::Automatic-Reboot = ${v:-(not set; unattended-upgrades default is false)}"
  else
    info auto-reboot "apt-config not available"
  fi

  local dm cnt=0
  if command -v dmesg >/dev/null 2>&1 && dm=$(dmesg 2>/dev/null); then
    while IFS= read -r line; do
      if [[ $line == *'apparmor="DENIED"'* ]]; then cnt=$((cnt + 1)); fi
    done <<< "$dm"
    info "apparmor denials" "$cnt apparmor=\"DENIED\" lines in this boot's dmesg"
  else
    info "apparmor denials" "dmesg not readable"
  fi

  local cl=""
  if [ -r "$CMDLINE_FILE" ]; then
    IFS= read -r cl < "$CMDLINE_FILE"
    info cmdline "$cl"
  else
    info cmdline "$CMDLINE_FILE not readable"
  fi

  evaluate_verdict
  print_verdict
  if [ "$FAILS" -eq 0 ]; then SUMMARY="pin $V_PIN_TEXT; next boot $V_NEXT ($V_NEXT_HOW); later boots $V_LATER"
  elif [ "$V_PIN_OK" != 1 ]; then SUMMARY="pin INCONSISTENT -- see the FAIL lines before any reboot"
  else SUMMARY="see the FAIL lines"; fi
}

# ---------- pin ----------
cmd_pin() {
  guard_root || return
  SHOW_VERDICT=1
  need_tools uname update-grub grub-editenv awk mktemp mv rm chmod || return
  if ! read_running; then fail running "uname -r gave '$RUNNING' (not a kernel version)"; SUMMARY="refused: running kernel unknown; nothing changed"; return; fi
  ok running "$RUNNING"
  local k=$RUNNING
  if ! check_kernel_files "$k"; then SUMMARY="refused: files of the running kernel $k missing or empty; nothing changed"; return; fi
  if ! load_menu; then fail grub.cfg "$MENU_ERR"; SUMMARY="refused: cannot read $D_GRUB_CFG; nothing changed"; return; fi
  if ! find_ids "$k"; then
    # 커널 항목이 하나도 없는 grub.cfg(겹친 grub-mkconfig 의 잔여)면 할 일을 붙인다(수정 2 L3 (a)).
    if menu_has_kernel; then
      fail "menu ids" "$IDS_ERR"; SUMMARY="refused: menu ids for $k are not unique; nothing changed"
    else
      fail "menu ids" "$IDS_ERR -- $EMPTY_MENU_HINT"; SUMMARY="refused: grub.cfg has no kernel menu entry; nothing changed -- do not reboot"
    fi
    return
  fi
  ok "menu ids" "submenu $SUB_ID x1, entry $ENTRY_ID x1"
  if [ "$NE_BLOCKS" -ne 1 ]; then fail "next_entry logic" "found $NE_BLOCKS blocks in $D_GRUB_CFG (want exactly 1)"; SUMMARY="refused: no next_entry logic in $D_GRUB_CFG; nothing changed"; return; fi
  ok "next_entry logic" "present in $D_GRUB_CFG (default \"$CFG_DEFAULT\")"
  # 가드: initrd 없는 부팅 폴백이 꺼져 있다 — 켜져 있으면 고정된 하위 메뉴 항목이 평소 부팅과 다르게(initrd 없이 · 재시도 없이) 부팅한다.
  if ! report_partuuid; then SUMMARY="refused: initrd-less boot fallback is on ('set partuuid=' in $D_GRUB_CFG); nothing changed"; return; fi
  # 가드: grubenv 의 initrdfail · prev_entry 가 비어 있다(값이 있으면 GRUB 이 다음 부팅을 바꿀 수 있다).
  if ! read_grubenv; then fail grubenv "$GE_ERR"; SUMMARY="refused: cannot read grubenv; nothing changed"; return; fi
  if ! check_initrd_fallback; then SUMMARY="refused: grubenv holds initrdfail/prev_entry; nothing changed"; return; fi
  read_pin_file
  if [ "$PIN_PRESENT" = 1 ]; then
    if [ -n "$PIN_ERR" ]; then fail "pin file" "malformed ($D_PIN_FILE): $PIN_ERR"; SUMMARY="refused: malformed pin file; nothing changed"; return; fi
    if [ "$PIN_VALUE" != "$ID_PATH" ]; then
      fail "pin file" "present with another value \"$PIN_VALUE\" (this kernel needs \"$ID_PATH\") -- run status"
      SUMMARY="refused: something else is pinned; nothing changed"
      return
    fi
    if [ "$CFG_DEFAULT" != "$ID_PATH" ]; then
      fail "pin file" "present with this value but grub.cfg default is \"$CFG_DEFAULT\" (update-grub did not finish) -- $FIX_LINE"
      SUMMARY="refused: transient state (pin file without update-grub); nothing changed"
      return
    fi
    ok "pin file" "already pinned -> $k (pin file and grub.cfg default agree; update-grub not run)"
    SUMMARY="already pinned to the running kernel $k; nothing changed"
    return
  fi
  if [ "$CFG_DEFAULT" != 0 ]; then
    fail "pin file" "absent but grub.cfg default is \"$CFG_DEFAULT\" (want \"0\") -- $FIX_LINE"
    SUMMARY="refused: grub.cfg default is not 0 without a pin file (transient state); nothing changed"
    return
  fi
  ok "pin file" "absent; grub.cfg default is \"0\""
  # 가드: 패키지 작업이 없다(다른 update-grub 과 겹치지 않게) — 쓰기 바로 앞, 그리고 update-grub 바로 앞에서 한 번 더.
  guard_package_activity || return
  if ! write_pin_file "$k"; then SUMMARY="could not write the pin file; nothing changed"; return; fi
  if ! recheck_package_activity; then undo_pin_write; return; fi
  run_update_grub
  local rc=$UG_RC
  if [ "$rc" -eq 0 ]; then ok update-grub "exit 0"; else fail update-grub "exit $rc"; fi
  # update-grub 직후: 패키지 작업이 보이면 FAIL — 검증도 되돌리기도 하지 않는다(수정 2 L1).
  if [ "$rc" -eq 0 ] && ! postcheck_package_activity; then
    SUMMARY="package activity while update-grub ran ($PKG_ITEMS); pin file written, not verified, not rolled back -- do not reboot; see the FAIL lines"
    return
  fi
  if [ "$rc" -eq 0 ] && verify_pinned "$k"; then
    SUMMARY="default boot pinned to the running kernel $k"
    return
  fi
  rollback_pin
}

# ---------- trial ----------
cmd_trial() {
  guard_root || return
  SHOW_VERDICT=1
  local k=$TRIAL_KVER
  if ! [[ $k =~ $KVER_RE ]]; then fail kver "'$k' is not a kernel version (want e.g. 7.0.0-1012-oracle)"; SUMMARY="refused: bad kernel version; nothing changed"; return; fi
  ok kver "$k"
  need_tools uname grub-editenv lsmod modinfo awk || return
  if ! read_running; then fail running "uname -r gave '$RUNNING' (not a kernel version)"; SUMMARY="refused: running kernel unknown; nothing changed"; return; fi
  ok running "$RUNNING"
  if ! load_menu; then fail grub.cfg "$MENU_ERR"; SUMMARY="refused: cannot read $D_GRUB_CFG; nothing changed"; return; fi
  if [ "$NE_BLOCKS" -ne 1 ]; then fail "next_entry logic" "found $NE_BLOCKS blocks in $D_GRUB_CFG (want exactly 1)"; SUMMARY="refused: no next_entry logic in $D_GRUB_CFG; nothing changed"; return; fi
  ok "next_entry logic" "present in $D_GRUB_CFG (default \"$CFG_DEFAULT\")"
  # 가드: initrd 없는 부팅 폴백이 꺼져 있다 — 켜져 있으면 시험 부팅이 평소 부팅과 같지 않다.
  if ! report_partuuid; then SUMMARY="refused: initrd-less boot fallback is on ('set partuuid=' in $D_GRUB_CFG); nothing changed"; return; fi
  read_pin_file
  if [ "$PIN_PRESENT" != 1 ]; then
    if [ "$CFG_DEFAULT" != 0 ]; then
      fail "pin file" "absent but grub.cfg default is \"$CFG_DEFAULT\" (want \"0\") -- $FIX_LINE"
      SUMMARY="refused: grub.cfg default is not 0 without a pin file (transient state); nothing changed"
      return
    fi
    fail "pin file" "absent -- run pin first (the running kernel must be the pinned fallback)"; SUMMARY="refused: no pin (no recovery path); nothing changed"; return
  fi
  if [ -n "$PIN_ERR" ]; then fail "pin file" "malformed ($D_PIN_FILE): $PIN_ERR"; SUMMARY="refused: malformed pin file; nothing changed"; return; fi
  ok "pin file" "present: GRUB_DEFAULT=\"$PIN_VALUE\""
  # 가드: 고정이 일관된다(고정 파일 값 = grub.cfg 기본값) — 복구 경로가 실제로 grub.cfg 에 들어가 있어야 한다.
  if [ "$PIN_VALUE" != "$CFG_DEFAULT" ]; then
    fail "pin consistent" "pin file \"$PIN_VALUE\" differs from grub.cfg default \"$CFG_DEFAULT\" (update-grub not run?) -- $FIX_LINE"
    SUMMARY="refused: the pin is not in grub.cfg yet; nothing changed"
    return
  fi
  ok "pin consistent" "pin file and grub.cfg default agree"
  if ! resolve_value "$PIN_VALUE"; then fail "pinned kernel" "the pin value does not resolve: $RESOLVE_ERR"; SUMMARY="refused: the pin does not resolve; nothing changed"; return; fi
  if [ "$RESOLVED" != "$RUNNING" ]; then
    fail "pinned kernel" "$RESOLVED is not the running kernel $RUNNING -- the fallback must be the kernel that runs now"
    SUMMARY="refused: the pinned kernel is not the running kernel; nothing changed"
    return
  fi
  ok "pinned kernel" "$RESOLVED (= running kernel)"
  # 가드: 고정 값 = pin 이 지금 쓸 값(실행 중 커널의 -advanced- 항목 경로 — 복구 모드 항목 · 다른 항목이면 거부).
  if ! find_ids "$RUNNING"; then fail "pin value" "$IDS_ERR"; SUMMARY="refused: the running kernel's menu ids are not unique; nothing changed"; return; fi
  if [ "$PIN_VALUE" != "$ID_PATH" ]; then
    fail "pin value" "\"$PIN_VALUE\" is not what pin would write for the running kernel $RUNNING (\"$ID_PATH\") -- the fallback must be the running kernel's -advanced- entry (not recovery mode)"
    SUMMARY="refused: the pin is not the running kernel's -advanced- entry; nothing changed"
    return
  fi
  ok "pin value" "\"$PIN_VALUE\" is what pin would write for the running kernel"
  # 가드: 복구용(= 실행 중) 커널의 vmlinuz · initrd 가 비어 있지 않고 modules 디렉터리가 있다.
  if ! check_kernel_files "$RUNNING" "fallback kernel files"; then SUMMARY="refused: files of the fallback kernel $RUNNING missing or empty; nothing changed"; return; fi
  if [ "$k" = "$RUNNING" ]; then fail target "$k is the running kernel -- nothing to try"; SUMMARY="refused: the target is the running kernel; nothing changed"; return; fi
  ok target "$k differs from the running kernel"
  if ! check_kernel_files "$k"; then SUMMARY="refused: files of $k missing or empty; nothing changed"; return; fi
  if ! find_ids "$k"; then fail "menu ids" "$IDS_ERR"; SUMMARY="refused: menu ids for $k are not unique; nothing changed"; return; fi
  ok "menu ids" "submenu $SUB_ID x1, entry $ENTRY_ID x1"
  if ! read_grubenv; then fail grubenv "$GE_ERR"; SUMMARY="refused: cannot read grubenv; nothing changed"; return; fi
  ok grubenv "$D_GRUBENV readable"
  # 가드: grubenv 의 initrdfail · prev_entry 가 비어 있다.
  if ! check_initrd_fallback; then SUMMARY="refused: grubenv holds initrdfail/prev_entry; nothing changed"; return; fi
  # 가드: 지금 적재된 모듈이 대상 커널에서 이름으로 있거나, 없으면 대체됨(사용자 경로 · 별칭 경로)으로 설명된다. 없음이 남으면 그 기능이 시험
  #   부팅에서 빠진다 — 진행하려면 --accept-missing-modules 로 없음 목록을 정확히(사전순으로 같게) 적는다(후속 F-B). --ignore-missing-modules 는
  #   그대로 전부 받아들이되 그렇다고 한 줄 알린다.
  if ! read_loaded_modules; then fail modules "$LOADED_ERR"; SUMMARY="refused: cannot list loaded modules; nothing changed"; return; fi
  if [ "${#LOADED[@]}" -eq 0 ]; then fail modules "lsmod listed no modules (cannot judge)"; SUMMARY="refused: cannot judge the modules; nothing changed"; return; fi
  missing_modules_for "$k"
  if [ "$IGNORE_MISSING" = 1 ]; then info modules "--ignore-missing-modules accepts every missing module; prefer --accept-missing-modules <names>"; fi
  local mtext="${#MISSING[@]} of ${#LOADED[@]} loaded modules missing for $k: ${MISSING[*]:-none}" mlist=${MISSING[*]}
  if [ "$ACCEPT_SET" = 1 ]; then
    # 둘 다 사전순이고 중복이 없다 — 문자열로 정확히 같아야 한다.
    if [ "${MISSING[*]}" != "${ACCEPT_LIST[*]}" ]; then
      accept_diff
      fail modules "$mtext -- --accept-missing-modules differs: $ACCEPT_DIFF"
      SUMMARY="refused: the missing modules for $k differ from --accept-missing-modules; nothing changed"
      return
    fi
    info modules "accepted exactly: ${ACCEPT_LIST[*]} (${#MISSING[@]} of ${#LOADED[@]} loaded modules missing for $k)"
  elif [ "${#MISSING[@]}" -gt 0 ]; then
    if [ "$IGNORE_MISSING" = 1 ]; then
      info modules "$mtext (accepted: --ignore-missing-modules)"
    else
      fail modules "$mtext (rerun with --accept-missing-modules ${mlist// /,} to accept exactly these)"
      SUMMARY="refused: loaded modules missing for $k; nothing changed"
      return
    fi
  elif [ "$NAME_MISS" -gt 0 ]; then
    ok modules "$NAME_MISS of ${#LOADED[@]} loaded modules not found by name in $k; all accounted for: ${ACCOUNTED[*]}"
  else
    ok modules "all ${#LOADED[@]} loaded modules exist for $k"
  fi
  if [ -n "$NEXT_ENTRY" ]; then
    if [ "$NEXT_ENTRY" = "$ID_PATH" ]; then
      ok next_entry "already set to \"$ID_PATH\" (nothing written)"
      SUMMARY="already set: next boot only $k; later boots $RUNNING"
      TRIAL_SET=1
      return
    fi
    fail next_entry "already set to \"$NEXT_ENTRY\" -- run cancel-trial first"
    SUMMARY="refused: next_entry already holds another value; nothing changed"
    return
  fi
  ok next_entry "empty"
  # 가드: 패키지 작업이 없다(쓰기 바로 앞).
  guard_package_activity || return
  local out rc
  info write "grub-editenv $D_GRUBENV set next_entry=$ID_PATH"
  out=$(grub-editenv "$GRUBENV" set "next_entry=$ID_PATH" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then first_line "$out"; fail grub-editenv "set exit $rc: $FIRST"; fi
  # 읽어 보기 확인: list 로 다시 읽어 정확히 그 값인가(아니면 unset).
  if [ "$rc" -eq 0 ] && verify_next_entry "$ID_PATH"; then
    SUMMARY="next boot only: $k; later boots: $RUNNING"
    TRIAL_SET=1
    return
  fi
  if clear_next_entry cleanup; then SUMMARY="could not set next_entry (see FAIL lines); next_entry cleared"
  else SUMMARY="could not set next_entry and could not clear it -- see FAIL lines before any reboot"; fi
}

# ---------- cancel-trial ----------
cmd_cancel_trial() {
  guard_root || return
  SHOW_VERDICT=1
  need_tools grub-editenv awk || return
  if ! read_grubenv; then fail grubenv "$GE_ERR"; SUMMARY="cannot read grubenv; nothing changed"; return; fi
  ok grubenv "$D_GRUBENV readable"
  # 패키지 작업 중이어도 막지 않는다(next_entry 를 지우는 것은 안전한 방향이다) — 알리기만 한다.
  check_package_activity
  if [ "$PKG_BUSY" = 1 ]; then info "package activity" "$PKG_ITEMS -- cancel-trial goes ahead (clearing next_entry is the safe direction)"; fi
  if [ -z "$NEXT_ENTRY" ]; then ok next_entry "empty -- nothing to cancel"; SUMMARY="nothing to cancel"; return; fi
  info write "grub-editenv $D_GRUBENV unset next_entry (was \"$NEXT_ENTRY\")"
  if clear_next_entry verify; then SUMMARY="next_entry cleared; the next boot uses the default"
  else SUMMARY="could not clear next_entry -- see FAIL lines before any reboot"; fi
}

# ---------- unpin ----------
cmd_unpin() {
  guard_root || return
  SHOW_VERDICT=1
  need_tools uname update-grub grub-editenv sort awk mktemp mv rm || return
  if ! read_running; then fail running "uname -r gave '$RUNNING' (not a kernel version)"; SUMMARY="refused: running kernel unknown; nothing changed"; return; fi
  ok running "$RUNNING"
  if ! load_menu; then fail grub.cfg "$MENU_ERR"; SUMMARY="refused: cannot read $D_GRUB_CFG; nothing changed"; return; fi
  read_pin_file
  if [ "$PIN_PRESENT" != 1 ]; then
    if [ "$NE_BLOCKS" -eq 1 ] && [ "$CFG_DEFAULT" != 0 ]; then
      fail "pin file" "absent but grub.cfg default is \"$CFG_DEFAULT\" (want \"0\") -- $FIX_LINE"
      SUMMARY="refused: grub.cfg default is not 0 without a pin file (transient state); nothing changed"
      return
    fi
    fail "pin file" "absent -- nothing to unpin"; SUMMARY="refused: no pin; nothing changed"; return
  fi
  if [ -n "$PIN_ERR" ]; then fail "pin file" "malformed ($D_PIN_FILE): $PIN_ERR -- inspect it by hand"; SUMMARY="refused: malformed pin file; nothing changed"; return; fi
  ok "pin file" "present: GRUB_DEFAULT=\"$PIN_VALUE\""
  if ! read_grubenv; then fail grubenv "$GE_ERR"; SUMMARY="refused: cannot read grubenv; nothing changed"; return; fi
  if [ -n "$NEXT_ENTRY" ]; then fail grubenv "next_entry is set (\"$NEXT_ENTRY\") -- run cancel-trial first"; SUMMARY="refused: a one-shot boot is pending; nothing changed"; return; fi
  ok grubenv "next_entry empty"
  if ! list_kernels || [ "${#KERNELS[@]}" -eq 0 ]; then fail newest "cannot list the installed kernels (/boot/vmlinuz-*)"; SUMMARY="refused: installed kernels unknown; nothing changed"; return; fi
  local newest=${KERNELS[$((${#KERNELS[@]} - 1))]}
  # 가드: 실행 중 커널 = 설치된 것 중 가장 새 커널 — 아니면 고정을 푸는 순간 다음 부팅이 검증되지 않은 커널이 된다.
  if [ "$RUNNING" != "$newest" ]; then
    fail newest "running kernel $RUNNING is not the newest installed kernel $newest -- unpinning now would make the unverified $newest the default"
    SUMMARY="refused: the running kernel is not the newest; nothing changed"
    return
  fi
  ok newest "running kernel $RUNNING is the newest installed kernel (sort -V)"
  if [ "$NE_BLOCKS" -ne 1 ]; then fail "next_entry logic" "found $NE_BLOCKS blocks in $D_GRUB_CFG (want exactly 1)"; SUMMARY="refused: no next_entry logic in $D_GRUB_CFG; nothing changed"; return; fi
  ok "next_entry logic" "present in $D_GRUB_CFG (default \"$CFG_DEFAULT\")"
  # 가드: 패키지 작업이 없다 — 치우기 바로 앞, 그리고 update-grub 바로 앞에서 한 번 더.
  guard_package_activity || return
  # 고정 파일을 같은 디렉터리의 임시 이름(점으로 시작 · .cfg 아님 — grub-mkconfig 가 읽지 않는다)으로 치워 둔다.
  local aside out rc
  aside=$(mktemp "$GRUBD/.kernel-trial-pin.aside.XXXXXX" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then first_line "$aside"; fail write "mktemp in $D_GRUBD failed: $FIRST"; SUMMARY="could not set the pin file aside; nothing changed"; return; fi
  out=$(mv -f "$PIN_FILE" "$aside" 2>&1)
  rc=$?
  if [ "$rc" -ne 0 ]; then rm -f -- "$aside"; first_line "$out"; fail write "cannot move the pin file aside: $FIRST"; SUMMARY="could not set the pin file aside; nothing changed"; return; fi
  info write "moved $D_PIN_FILE aside to ${aside#"$R"}"
  if ! recheck_package_activity; then undo_unpin_aside "$aside"; return; fi
  run_update_grub
  rc=$UG_RC
  if [ "$rc" -eq 0 ]; then ok update-grub "exit 0"; else fail update-grub "exit $rc"; fi
  # update-grub 직후: 패키지 작업이 보이면 FAIL — 검증도 복원도 하지 않고 치워 둔 고정 파일만 지운다(고정을 푸는 것이 목표 상태이고, 수동 복구의
  #   update-grub 한 번이 고정 없는 설정으로 grub.cfg 를 다시 만든다 — 수정 2 L1).
  if [ "$rc" -eq 0 ] && ! postcheck_package_activity; then
    remove_aside "$aside"
    SUMMARY="package activity while update-grub ran ($PKG_ITEMS); pin file removed, not verified -- do not reboot; see the FAIL lines"
    return
  fi
  if [ "$rc" -eq 0 ] && verify_unpinned; then
    remove_aside "$aside"
    SUMMARY="pin removed; default boot is entry 0 ($RUNNING)"
    return
  fi
  restore_pin "$aside"
}

# unpin 이 치워 둔 고정 파일(.kernel-trial-pin.aside.*)을 지운다. 지우지 못해도 GRUB 에는 해가 없다(점으로 시작 · .cfg 아님).
remove_aside() {
  local out
  out=$(rm -f -- "$1" 2>&1)
  if [ -e "$1" ]; then first_line "$out"; fail cleanup "cannot remove ${1#"$R"} ($FIRST) -- harmless to GRUB, remove it by hand"
  else ok cleanup "removed the set-aside pin file"; fi
  return 0
}

# ---------- 인자 ----------
usage_error() {
  fail usage "$1"
  info usage "kernel-trial.sh status | pin | trial <kver> [--accept-missing-modules <m1,m2,...> | --ignore-missing-modules] | cancel-trial | unpin"
  info usage "run as root on the node: Get-Content -Raw infra/bootstrap/kernel-trial.sh | ssh <node> \"sudo bash -s -- <subcommand>\""
  emit "RESULT: FAIL usage -- $1"
}

# --accept-missing-modules 의 값(쉼표 목록) → ACCEPT_LIST(사전순). 빈 목록 · 빈 이름 · MODNAME_RE 밖의 이름 · 중복은 사용법 오류(usage_error 를
#   내고 1). 쉼표로 직접 자른다 — read 는 끝의 빈 이름을 버리고 줄바꿈에서 멈춘다.
parse_accept_list() {
  local raw=$1 rest t s
  ACCEPT_LIST=()
  if [ -z "$raw" ]; then usage_error "--accept-missing-modules got an empty list"; return 1; fi
  case $raw in ,*|*,|*,,*) usage_error "--accept-missing-modules: empty name in '$raw'"; return 1 ;; esac
  rest=$raw
  while :; do
    t=${rest%%,*}
    if ! [[ $t =~ $MODNAME_RE ]]; then usage_error "--accept-missing-modules: '$t' is not a module name"; return 1; fi
    for s in "${ACCEPT_LIST[@]}"; do
      if [ "$s" = "$t" ]; then usage_error "--accept-missing-modules: '$t' listed twice"; return 1; fi
    done
    ACCEPT_LIST+=("$t")
    [ "$rest" != "$t" ] || break
    rest=${rest#*,}
  done
  sort_words "${ACCEPT_LIST[@]}"; ACCEPT_LIST=("${SORTED[@]}")
  return 0
}

parse_args() {
  CMD=${1-}
  case $CMD in
    status|pin|cancel-trial|unpin)
      if [ "$#" -ne 1 ]; then usage_error "$CMD takes no arguments"; return 2; fi ;;
    trial)
      shift
      local a seen=0 want=0 raw=""
      for a in "$@"; do
        # --accept-missing-modules 의 값은 다음 인자다. '-' 로 시작하면 값이 아니다(모듈 이름은 '-' 로 시작하지 않는다).
        if [ "$want" = 1 ]; then
          want=0
          case $a in -*) usage_error "--accept-missing-modules needs a comma-separated list of module names"; return 2 ;; esac
          raw=$a
          continue
        fi
        case $a in
          --ignore-missing-modules)
            if [ "$IGNORE_MISSING" = 1 ]; then usage_error "--ignore-missing-modules given twice"; return 2; fi
            IGNORE_MISSING=1 ;;
          --accept-missing-modules)
            if [ "$ACCEPT_SET" = 1 ]; then usage_error "--accept-missing-modules given twice"; return 2; fi
            ACCEPT_SET=1; want=1 ;;
          --*) usage_error "unknown option '$a'"; return 2 ;;
          *)
            if [ "$seen" = 1 ]; then usage_error "trial takes exactly one kernel version"; return 2; fi
            TRIAL_KVER=$a; seen=1 ;;
        esac
      done
      if [ "$want" = 1 ]; then usage_error "--accept-missing-modules needs a comma-separated list of module names"; return 2; fi
      if [ "$IGNORE_MISSING" = 1 ] && [ "$ACCEPT_SET" = 1 ]; then usage_error "--accept-missing-modules and --ignore-missing-modules cannot be combined"; return 2; fi
      if [ "$seen" != 1 ]; then usage_error "trial takes exactly one kernel version"; return 2; fi
      if [ "$ACCEPT_SET" = 1 ] && ! parse_accept_list "$raw"; then return 2; fi ;;
    '') usage_error "missing subcommand"; return 2 ;;
    *) usage_error "unknown subcommand '$CMD'"; return 2 ;;
  esac
  return 0
}

main() {
  if [ -n "$R" ]; then info note "KT_ROOT=$R (test root)"; fi
  parse_args "$@" || return 2
  case $CMD in
    status) cmd_status ;;
    pin) cmd_pin ;;
    trial) cmd_trial ;;
    cancel-trial) cmd_cancel_trial ;;
    unpin) cmd_unpin ;;
  esac
  local own=$FAILS
  if [ "$SHOW_VERDICT" = 1 ]; then
    refresh_state
    evaluate_verdict
    print_verdict
  fi
  if [ "$CMD" = trial ] && [ "$TRIAL_SET" = 1 ]; then
    info guide "only the next boot uses $TRIAL_KVER; every boot after it uses the pinned $RUNNING"
    info guide "if $TRIAL_KVER misbehaves, one reboot returns to $RUNNING (if it does not boot at all, force-restart the instance once)"
    info guide "nothing was rebooted; reboot when ready, run status, and run unpin once $TRIAL_KVER is verified"
  fi
  if [ "$FAILS" -eq 0 ]; then emit "RESULT: OK $CMD -- ${SUMMARY:-done}"; return 0; fi
  if [ "$own" -eq 0 ]; then SUMMARY="${SUMMARY:-done}, but the final state check failed (see the FAIL pin line)"; fi
  emit "RESULT: FAIL $CMD -- ${SUMMARY:-see the FAIL lines}"
  return 1
}

# 표준 입력(bash -s)으로 실행되므로 main 의 표준 입력은 /dev/null 로 — 자식 명령이 스크립트 본문을 먹지 않는다. 뒤의 exit 는 그 뒤에 오는 어떤 입력
# (PowerShell 파이프가 붙이는 CRLF 등)도 읽지 않게 하고 main 의 종료 코드를 그대로 돌려준다.
main "$@" </dev/null; exit
