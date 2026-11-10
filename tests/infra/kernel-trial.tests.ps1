# infra/bootstrap/kernel-trial.sh 테스트(T048 커널 시험 부팅 도구). Run: pwsh -NoProfile -File tests/infra/kernel-trial.tests.ps1
# Exit 0 = all pass(또는 bash 없음 SKIP), 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/kubeconform-deploy.tests.ps1와 같은 구조).
#
# 방식: 스크립트를 Git/POSIX bash로 "실제로" 실행한다 — 운영자와 같은 표준 입력 실행(bash -s -- <하위 명령>; 스크립트 바이트 뒤에
#   PowerShell 파이프처럼 CRLF를 붙인다). 경로는 전부 가짜 루트(KT_ROOT = 임시 픽스처의 root/, C:/... 형태)이고, 외부 명령은
#   공용 가짜 bin/이 PATH 맨 앞에서 가린다: uname · id · update-grub · grub-editenv · lsmod · modinfo · modprobe · dmesg · apt-config · pgrep.
#   가짜는 상태를 가진다(KT_FAKE_STATE = 픽스처의 state/): update-grub은 가짜 루트의 /etc/default/grub과 grub.d/*.cfg를 이름 순으로
#   읽어 GRUB_DEFAULT를 구하고 grub.cfg를 픽스처 템플릿에서 다시 만든다(모드 ok · fail · noop · wrong · dup-ids · alt(다른 템플릿) · fail-leave-new —
#   호출마다 차례로, 마지막 모드가 반복. state/update-grub.utf8이 있으면 그 비ASCII 줄도 낸다), grub-editenv는 1024바이트 환경 블록을
#   list · set · unset 한다(모드 낱말을 겹쳐 쓴다: ok · set-noop · set-wrong · unset-noop), lsmod는 state/lsmod 줄(이름 크기 사용 수
#   [사용자 열] — kmod 31의 모양)을 그대로 내고, modinfo -k는 커널별 모듈 목록 파일을 보고(이름의 '-'와 '_'는 kmod처럼 같게 본다 · -F alias면
#   커널별 별칭 지도 state/aliases-KVER의 별칭을 순서대로 낸다 · state/modinfo-alias.fail의 모듈은 실패 · -F name이면 목록의 이름 한 줄 —
#   목록에 없으면 kmod 31의 not-found 문구와 exit 1; 3라운드 R3-1의 계승자 확인. -F name · -F alias에서 목록에 없는 이름이 목록에 있는 모듈의
#   별칭이면 kmod처럼 그 모듈들로 푼다 — R3b F3. state/modinfo-fail-KVER의 모듈은 그 커널에서 -F name · -F alias가 kmod 31의 '읽을 수 없음'
#   실패('could not get modinfo from' · exit 1)를 내고, state/modinfo-alias-fail-KVER의 모듈은 -F alias만 그렇게 실패한다 — R3c F1),
#   modprobe(-S KVER --show-depends NAME만)는
#   커널별 지도 state/modprobe-KVER("NAME 출력 줄")에서 exit 0 + 그 줄들을, 없으면 exit 1 + 'modprobe: FATAL: Module NAME not found in
#   directory /lib/modules/KVER'를 낸다(모드 ok · missing(exit 127) · no-S(-S를 모르는 modprobe) — 2026-10-06 실제 kmod 31 · 실제 모듈
#   트리로 모양을 확인했다), pgrep(-a -x NAME만)은 이름별 호출 횟수를 세어 state/pgrep.plan의 "NAME 호출 PID ARGS" 줄(호출 = * | N | N+)을 프로세스로
#   돌려주고 state/pgrep.fail의 "NAME 호출 EXIT 메시지" 줄로 실패 코드를 낸다(가드 때는 없고 update-grub 직전에는 있음 = "NAME 2+ ...").
#   가짜마다 호출(인자)을 state/calls.log에 남긴다 — "가드에서 거부되면 쓰기 호출 0".
#   덫 가짜(reboot · shutdown · poweroff · halt · kexec · grub-reboot · grub-set-default · grub-mkconfig · grub-install · apt · apt-get ·
#   dpkg · systemctl)는 불리면 기록하고 exit 99 — 모든 실행에서 0회를 단언한다.
# 안전: 이 PC의 실제 부트로더 · /boot에 닿지 않는다. 실행마다 KT_ROOT를 픽스처로 주고, 시작할 때 PATH 우선순위 탐침으로 가짜가 실제
#   명령보다 먼저 풀리는지 확인한다(실패하면 아무 케이스도 돌리지 않고 FAIL). Windows에서는 Git의 usr/bin/bash.exe만 쓴다 — Git의
#   bin/bash.exe는 PATH 앞에 /mingw64/bin:/usr/bin을 붙여 가짜를 가리고(2026-10-01 실측), WSL의 bash는 Windows 경로를 못 읽는다.
#   자식 환경에 MSYS_NO_PATHCONV=1 · MSYS2_ARG_CONV_EXCL=*를 준다(/로 시작하는 인자를 Git bash가 경로로 바꾸지 않게).
# 실행마다 확인하는 부작용(S-runs): 출력(stdout+stderr)이 ASCII · stderr가 비었다 · 첫 줄 KT_ROOT 안내 · 마지막 줄 RESULT와 종료 코드 일치 ·
#   모든 줄이 OK|FAIL|INFO <주제>: 형식 · 가짜 루트에서 바뀐 것은 grub.cfg(update-grub 가짜가 쓴 내용과 같을 때만) · grubenv(grub-editenv
#   가짜가 쓴 내용과 같을 때만) · 고정 파일뿐(임시 파일 잔여 · 커널 파일 삭제 · /etc/default/grub과 기존 드롭인 변경 = FAIL) · 덫 0회.
# SKIP: bash가 없으면 첫 줄 'SKIP kernel-trial tests -- <이유>' + exit 0(tests/run-all.ps1의 kernel-trial 항목이 이 첫 줄만 SKIP으로 읽는다).
#   스크립트 부재는 SKIP이 아니다 — 실행 단언이 전부 FAIL한다(fail closed).
# 환경 변수:
#   KERNEL_TRIAL_SCRIPT      시험할 스크립트(기본 infra/bootstrap/kernel-trial.sh) — 변이 시험에서 사본을 가리킬 때. 설정되면 요약 줄에
#                            ' (script override)'가 붙어 run-all의 판정을 통과하지 못한다.
#   KERNEL_TRIAL_TESTS_ONLY  쉼표로 구분한 그룹 이름(K1 ... K20, F1 F2 F3 F6 F9 F10, M1 FA FB FC L1 L3 L4, S) — 그 그룹만 돈다. 요약 줄에
#                            ' (filtered: ...)'가 붙는다.
# 단언 이름의 K1–K20 · S는 지시서(T048 kernel-trial)의 케이스 번호, F1–F10은 리뷰 반영 지시서(kernel-trial-fix)의 항목 번호다
#   (F1 패키지 작업 · F2 set partuuid= · F3 출력이 닫혀도 끝까지 + 잔여 파일 + 수동 복구 줄 · F6 복구용 커널 · F9 initrdfail/prev_entry ·
#   F10 테스트의 빈 곳). M1 · L1–L4는 수정 지시서 2(kernel-trial-fix2)의 항목이다(M1 모듈 검사 = 사용자가 새 커널에서 풀리는가 · L1 update-grub
#   직후 패키지 작업 · L2 되돌린 뒤의 안내 = F1j · F1k의 기대 줄 · L3 수동 복구 안내 = L3 그룹 + F9의 기대 줄 · L4 종료 대기 도우미 예외).
#   FA · FB · FC는 그 후속 지시(F-A 사용자 없는 모듈은 별칭으로 판정 — '쓰이지 않음' 분류는 없다 · F-B 정확한 수용 옵션
#   --accept-missing-modules · F-C 부팅 목록에 명령 줄 modules_load= · rd.modules_load= · /etc/initramfs-tools/modules)이고, M1의 기대도
#   그 규칙과 F-D 실측(6.17 → 7.0: 없음 polyval_ce · 대체됨 셋)에 맞췄다.
#   3라운드(kernel-trial-fix2-round3): R3-1 별칭 경로의 계승자 규칙 = FA-5(맨 이름 별칭이 다른 모듈로 풀림) · FA-6(지금 커널에 이미 있던 형제) ·
#   FA-7(새 모듈 · 합쳐진 계승자 · 공유 별칭) · FA-4b와 M1-1a의 호출 순서, R3-2 낱말 전체가 따옴표인 명령 줄 키 = FC-3, R3-5 준수 리뷰의 단언 =
#   M1-5d · M1-6i · FA-4 · FB-ignore-none · L3c. 별칭 경로로 대체되는 픽스처는 7.0 쪽 제공자가 그 커널의 모듈 목록(Extra)에 있고 그 별칭을
#   선언한다(aliases-K7) — 실제 이름을 쓰는 M1은 실제 7.0 트리의 별칭 그대로($AL7Real).
#   R3c(kernel-trial-fix2-round3c — 실제 kmod 31 리뷰의 F1 · F2): F1 지금 커널 쪽 조회의 'not found' 아닌 실패는 fail-closed = FA-4e(status) ·
#   FA-6b(trial) · FA-4f(-F alias만 실패), F2 systemd와 같은 낱말 나누기(따옴표 안의 공백 · 탭 · 닫히지 않은 따옴표) = FC-3c.
#   'x'가 붙은 것(예: K4x-transient)과 S-runs는 지시서 밖에서 더한 단언이다.
# M1의 "modprobe 없음"(M1-6a)은 가짜 modprobe만 뺀 두 번째 가짜 bin(PATH)으로 돈다 — 시작할 때 그 PATH에서 modprobe가 어디에서도 풀리지
#   않는지 따로 확인한다(실제 modprobe가 PATH에 있는 호스트에서는 그 단언과 M1-6a가 FAIL한다 — fail closed).
# 출력이 닫힌 실행(-CloseStdout: 첫 줄을 쓰기 전에 표준 출력의 읽는 쪽을 닫는다)은 S-runs의 stderr · 틀 · 형식 검사에서 뺀다
#   (bash가 'write error: Broken pipe'를 stderr로 내는 것이 정상이다).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptOverride = -not [string]::IsNullOrEmpty($env:KERNEL_TRIAL_SCRIPT)
$scriptPath = if ($scriptOverride) { $env:KERNEL_TRIAL_SCRIPT } else { Join-Path $repo 'infra/bootstrap/kernel-trial.sh' }
$script:only = @(if (-not [string]::IsNullOrEmpty($env:KERNEL_TRIAL_TESTS_ONLY)) { $env:KERNEL_TRIAL_TESTS_ONLY -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } })
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:runs = [Collections.Generic.List[object]]::new()
$script:blast = [Collections.Generic.List[string]]::new()
$script:group = ''
$script:runNo = 0
$sw = [Diagnostics.Stopwatch]::StartNew()

# ---------- bash ----------
# Windows: Git의 usr/bin/bash.exe만(머리 주석). 그 밖: PATH의 bash.
function Find-Bash {
    if ($IsWindows) {
        $roots = [Collections.Generic.List[string]]::new()
        foreach ($r in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) { if ($r) { $roots.Add((Join-Path $r 'Git')) } }
        if ($env:LOCALAPPDATA) { $roots.Add((Join-Path $env:LOCALAPPDATA 'Programs/Git')) }
        $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($git) {
            $d = Split-Path -Parent $git.Source          # .../Git/cmd 또는 .../Git/mingw64/bin
            $roots.Add((Split-Path -Parent $d)); $roots.Add((Split-Path -Parent (Split-Path -Parent $d)))
        }
        foreach ($r in $roots) {
            $c = Join-Path $r 'usr/bin/bash.exe'
            if (Test-Path -LiteralPath $c -PathType Leaf) { return (Resolve-Path -LiteralPath $c).Path }
        }
        return $null
    }
    $cmd = Get-Command bash -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}
$script:bash = Find-Bash
if (-not $script:bash) {
    Write-Host 'SKIP kernel-trial tests -- no POSIX bash found (Windows: Git for Windows usr/bin/bash.exe; Git bin/bash.exe and WSL bash are not used)'
    exit 0
}
$script:bashDir = Split-Path -Parent $script:bash

# ---------- 단언 도구 ----------
function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 단언 그룹 격리 + 선택 실행. $names는 'K2,K3'처럼 쉼표로 여러 이름을 줄 수 있다(하나라도 KERNEL_TRIAL_TESTS_ONLY에 있으면 돈다).
function Test-Group([string]$names, [scriptblock]$body) {
    $list = @($names -split ',')
    if ($script:only.Count -gt 0 -and @($list | Where-Object { $script:only -contains $_ }).Count -eq 0) { return }
    $script:group = $list[0]
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $names -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Test-HasLine([string[]]$lines, [string]$line) { foreach ($l in $lines) { if (Test-Same $l $line) { return $true } }; return $false }
function Test-HasLinePrefix([string[]]$lines, [string]$prefix) { foreach ($l in $lines) { if ($l.StartsWith($prefix, [StringComparison]::Ordinal)) { return $true } }; return $false }
function Get-LinesWithPrefix([string[]]$lines, [string]$prefix) { return ,@($lines | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }) }
function Test-LastPrefix($r, [string]$prefix) { return ($r.lines.Count -gt 0 -and $r.lines[$r.lines.Count - 1].StartsWith($prefix, [StringComparison]::Ordinal)) }

function ConvertTo-BashPath([string]$p) { return ($p -replace '\\', '/') }
function Write-Text([string]$path, [string]$text) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
}
function Get-Sha([string]$path) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([IO.File]::ReadAllBytes($path))) }

function Format-Result($r) {
    $c = if ($r.calls.Count -gt 0) { $r.calls -join ' ; ' } else { '-' }
    $s = "[exit=$($r.code)] [calls: $c]`n      " + ($r.lines -join "`n      ")
    if ($r.err) { $s += "`n      stderr: $($r.err)" }
    return $s
}

# ---------- 픽스처 상수 ----------
$UUID = '0f1e2d3c-4b5a-4697-8877-665544332211'
$BOOTUUID = '5c1f8b0e-7f6a-4d2b-9c3e-1a2b3c4d5e6f'
$K6 = '6.17.0-1020-oracle'
$K7 = '7.0.0-1012-oracle'
$K68 = '6.8.0-1001-oracle'
$SUB = "gnulinux-advanced-$UUID"
function Get-EntryId([string]$k) { return "gnulinux-$k-advanced-$UUID" }
function Get-PinValue([string]$k) { return "$SUB>$(Get-EntryId $k)" }
# 6.17의 복구 모드 항목 경로(F6 — 고정 값으로 쓰면 안 된다).
$REC6 = "$SUB>gnulinux-$K6-recovery-$UUID"
# 수동 복구 문구(F1 · F3) — 스크립트의 FIX_LINE과 글자 그대로 같아야 한다. 조건은 "패키지 프로세스가 없을 때"다: 홀로 남은 오래된
#   grub.cfg.new는 성공한 update-grub만이 치우므로 "package activity: none"을 기다리라고 하면 끝나지 않는다.
$FIX = "manual fix: when status lists no package process, run 'sudo update-grub' one time, then run status again"
# 우분투 24.04의 unattended-upgrades.service가 상시 띄우는 종료 대기 도우미(프로세스 이름 unattended-upgr)의 명령 줄 — 패키지 작업이 아니다
#   (2026-10-02 ubuntu:24.04 컨테이너 실측: 단위가 설치 때 enable되고, pgrep -x unattended-upgr가 이 프로세스를 찾는다).
$UU_HELPER = '/usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal'
# 가짜 도구가 내는 비ASCII 글자(F10): e-acute · 한글 두 자 · 줄임표. 스크립트(LC_ALL=C)는 바이트마다 '?'로 바꿔야 한다(2 · 3 · 3 · 3 바이트).
$NONASCII = 'G' + [char]0x00E9 + 'n' + [char]0x00E9 + 'ration ' + [char]0xD55C + [char]0xAE00 + ' ' + [char]0x2026
$NONASCII_SANITIZED = 'G??n??ration ?????? ???'
# L3 — 수동 복구 안내(스크립트의 EMPTY_MENU_HINT · INITRD_HINT와 글자 그대로 같아야 한다). (b)의 근거: grub-common 2.12-1ubuntu7.3의
#   /lib/systemd/system/grub-initrd-fallback.service 10–11행(부팅마다 grub-editenv … unset initrdfail · unset prev_entry) ·
#   /etc/grub.d/00_header 54–63행(initrdfail=1이면 prev_entry를 next_entry로 한 번 부팅) · 117–128행(partuuid가 있을 때만 값을 쓴다).
$EMPTY_MENU_HINT = "grub.cfg has no kernel menu entry (a partial grub-mkconfig output?): do not reboot -- $FIX"
$INITRD_HINT = "unexpected (grub-initrd-fallback.service clears both at every boot): before any reboot, check 'systemctl status grub-initrd-fallback.service', clear them as that unit does with 'sudo systemctl start grub-initrd-fallback.service', then run status"
# F-B — --ignore-missing-modules를 쓰면 내는 한 줄(글자 그대로 — '<names>'도 그대로다).
$IGNORE_HINT = 'INFO modules: --ignore-missing-modules accepts every missing module; prefer --accept-missing-modules <names>'
# L1 · L2 문구.
$PARTIAL = "while update-grub ran -- grub.cfg may be partial; do not reboot -- $FIX"
$AFTER_PKG = ' -- run status again after the package work ends'
# M1 — 6.17 → 7.0의 실제 넷(노드 증거 · design §10.6)과 실제 modprobe 출력: 2026-10-06 ubuntu:24.04 컨테이너(kmod 31+20240202-2ubuntu7.2)에서
#   linux-modules(-extra)-6.17.0-1020-oracle · linux-modules-7.0.0-1012-oracle(arm64 .deb)을 dpkg-deb -x로 풀고 depmod한 트리에
#   modprobe -d <root> -S <k> --show-depends를 돌린 줄 그대로(끝의 공백만 뺐다 — kmod는 'insmod <경로> <옵션>'이라 끝에 공백이 붙는다).
$MP7 = @{
    'wireguard'  = @("insmod /lib/modules/$K7/kernel/net/ipv4/udp_tunnel.ko.zst", "insmod /lib/modules/$K7/kernel/net/ipv6/ip6_udp_tunnel.ko.zst", "insmod /lib/modules/$K7/kernel/lib/crypto/libcurve25519.ko.zst", "insmod /lib/modules/$K7/kernel/drivers/net/wireguard/wireguard.ko.zst")
    'aes_ce_blk' = @("insmod /lib/modules/$K7/kernel/arch/arm64/crypto/aes-ce-blk.ko.zst")
}
$MP6 = @{
    'btrfs' = @("insmod /lib/modules/$K6/kernel/lib/raid6/raid6_pq.ko.zst", "insmod /lib/modules/$K6/kernel/arch/arm64/lib/xor-neon.ko.zst", "insmod /lib/modules/$K6/kernel/crypto/xor.ko.zst", "insmod /lib/modules/$K6/kernel/crypto/blake2b_generic.ko.zst", "insmod /lib/modules/$K6/kernel/fs/btrfs/btrfs.ko.zst")
}
# 6.17에서 적재된 모듈(lsmod 순서)과 3열 이후(사용 수 [사용자]) — 이름이 7.0에서 바뀐 넷은 노드의 lsmod 그대로: libcurve25519_generic(사용자
#   wireguard) · aes_ce_cipher(사용자 aes_ce_blk) · blake2b_generic · polyval_ce(사용자 없음 · 사용 수 0).
$M1Loaded = @('wireguard', 'libcurve25519_generic', 'ip6_udp_tunnel', 'udp_tunnel', 'aes_ce_blk', 'aes_ce_cipher', 'btrfs', 'blake2b_generic', 'polyval_ce', 'overlay', 'br_netfilter')
$M1Lsmod = @{ 'libcurve25519_generic' = '1 wireguard'; 'ip6_udp_tunnel' = '1 wireguard'; 'udp_tunnel' = '1 wireguard'; 'aes_ce_cipher' = '1 aes_ce_blk'; 'overlay' = '2' }
$M1Renamed = @('libcurve25519_generic', 'aes_ce_cipher', 'blake2b_generic', 'polyval_ce')
# F-A — 사용자 없는 모듈은 별칭으로 판정한다. 6.17의 실제 별칭(modinfo -k 6.17.0-1020-oracle -F alias, 순서 그대로)과 그 7.0 결과
#   (2026-10-06 같은 컨테이너 · 같은 트리): blake2b_generic 16개 가운데 '*-generic' 여덟은 7.0에서 exit 1, 나머지 여덟(crypto-blake2b-512 …)은
#   exit 0 + insmod libblake2b · blake2b — 처음 풀리는 것은 세 번째 crypto-blake2b-512. polyval_ce의 구체적인 별칭 넷은 전부 exit 1이고 다섯째는
#   glob(묻지 않는다). wireguard의 별칭은 두 판 모두 net-pf-16-proto-16-family-wireguard · rtnl-link-wireguard.
$AL6 = @{
    'blake2b_generic' = @(foreach ($b in @('512', '384', '256', '160')) { "crypto-blake2b-$b-generic"; "blake2b-$b-generic"; "crypto-blake2b-$b"; "blake2b-$b" })
    'polyval_ce'      = @('crypto-polyval-ce', 'polyval-ce', 'crypto-polyval', 'polyval', 'cpu:type:*:feature:*0004*')
    'wireguard'       = @('net-pf-16-proto-16-family-wireguard', 'rtnl-link-wireguard')
}
$B2LINES = @("insmod /lib/modules/$K7/kernel/lib/crypto/libblake2b.ko.zst", "insmod /lib/modules/$K7/kernel/crypto/blake2b.ko.zst")
foreach ($b in @('512', '384', '256', '160')) { $MP7["crypto-blake2b-$b"] = $B2LINES; $MP7["blake2b-$b"] = $B2LINES }
# R3-1 — 별칭 경로는 그 답의 모듈(insmod · builtin 줄) 가운데 m의 계승자가 있을 때만 센다: 7.0에서 그 별칭을 스스로 선언하고, 6.17에 같은
#   이름으로 있으면서 이미 그 별칭을 선언하던 형제가 아니다. 7.0의 실제 별칭(2026-10-07 같은 모양의 ubuntu:24.04 컨테이너 · kmod 31 · 같은 .deb,
#   modinfo -k 7.0.0-1012-oracle -F alias, 순서 그대로): blake2b 16개('*-lib' 여덟과 crypto-blake2b-512 …) · libblake2b 없음(exit 0 · 빈 출력) ·
#   wireguard 둘. blake2b · libblake2b는 6.17에 이름으로 없다(modinfo -k 6.17.0-1020-oracle -F name → exit 1).
$AL7Real = @{
    'blake2b'   = @(foreach ($b in @('512', '384', '256', '160')) { "crypto-blake2b-$b-lib"; "blake2b-$b-lib"; "crypto-blake2b-$b"; "blake2b-$b" })
    'wireguard' = @('net-pf-16-proto-16-family-wireguard', 'rtnl-link-wireguard')
}
# 7.0의 모듈 목록에 더하는 제공자(적재되지 않음 — crypto-blake2b-512의 답 insmod libblake2b · blake2b).
$M1Extra7 = @('libblake2b', 'blake2b')
# 실측: 6.17 → 7.0에서 없음은 polyval_ce 하나, 대체됨은 셋(사용자 경로 둘 + 별칭 경로 하나).
$M1Miss = 'polyval_ce'
$M1Acc = 'aes_ce_cipher->aes_ce_blk blake2b_generic=crypto-blake2b-512 libcurve25519_generic->wireguard'
# M1-1의 modprobe 질의 순서: 확인(이름으로 못 찾은 첫 모듈) → aes_ce_cipher의 사용자 → blake2b_generic의 별칭(처음 풀리는 데서 멈춤) →
#   libcurve25519_generic의 사용자 → polyval_ce의 구체적인 별칭 넷(glob 하나는 묻지 않는다).
$M1Queries = @('aes_ce_cipher', 'aes_ce_blk', 'crypto-blake2b-512-generic', 'blake2b-512-generic', 'crypto-blake2b-512', 'wireguard', 'crypto-polyval-ce', 'polyval-ce', 'crypto-polyval', 'polyval')
# 실제 grub-mkconfig가 GRUB_FORCE_PARTUUID에서 10_linux 머리에 넣는 줄(kernel-review/out/real-grub/v2-forcepartuuid-pinned.cfg 120행).
$cfgPartuuid = @'
#
# GRUB_FORCE_PARTUUID is set, will attempt initrdless boot
# Upon panic fallback to booting with initrd
set partuuid=aaaaaaaa-0000-4000-8000-000000000001
'@ + "`n"

# 우분투 24.04 grub-mkconfig 출력의 모양(00_header · 10_linux · 30_uefi-firmware · 41_custom). @DEFAULT@는 else 가지의 값 자리다.
$cfgHead = @'
#
# DO NOT EDIT THIS FILE
#
# It is automatically generated by grub-mkconfig using templates
# from /etc/grub.d and settings from /etc/default/grub
#

### BEGIN /etc/grub.d/00_header ###
if [ -s $prefix/grubenv ]; then
  set have_grubenv=true
  load_env
fi
if [ "${initrdfail}" = 2 ]; then
   set initrdfail=
elif [ "${initrdfail}" = 1 ]; then
   set next_entry="${prev_entry}"
   set prev_entry=
   save_env prev_entry
   if [ "${next_entry}" ]; then
      set initrdfail=2
   fi
fi
'@ + "`n"
$cfgNextEntry = @'
if [ "${next_entry}" ] ; then
   set default="${next_entry}"
   set next_entry=
   save_env next_entry
   set boot_once=true
else
   set default="@DEFAULT@"
fi
'@ + "`n"
$cfgPlainDefault = "set default=`"@DEFAULT@`"`n"
$cfgMiddle = @'

if [ x"${feature_menuentry_id}" = xy ]; then
  menuentry_id_option="--id"
else
  menuentry_id_option=""
fi

export menuentry_id_option

if [ "${prev_saved_entry}" ]; then
  set saved_entry="${prev_saved_entry}"
  save_env saved_entry
  set prev_saved_entry=
  save_env prev_saved_entry
  set boot_once=true
fi

function savedefault {
  if [ -z "${boot_once}" ]; then
    saved_entry="${chosen}"
    save_env saved_entry
  fi
}
function initrdfail {
    if [ -n "${have_grubenv}" ]; then if [ -n "${partuuid}" ]; then
      if [ -z "${initrdfail}" ]; then
        set initrdfail=1
        if [ -n "${boot_once}" ]; then
          set prev_entry="${default}"
          save_env prev_entry
        fi
      fi
      save_env initrdfail
    fi; fi
}
function recordfail {
  set recordfail=1
  if [ -n "${have_grubenv}" ]; then if [ -z "${boot_once}" ]; then save_env recordfail; fi; fi
}
function load_video {
  if [ x$feature_all_video_module = xy ]; then
    insmod all_video
  else
    insmod efi_gop
    insmod efi_uga
    insmod ieee1275_fb
    insmod vbe
    insmod vga
    insmod video_bochs
    insmod video_cirrus
  fi
}

terminal_input console
terminal_output console
if [ "${recordfail}" = 1 ] ; then
  set timeout=0
else
  if [ x$feature_timeout_style = xy ] ; then
    set timeout_style=hidden
    set timeout=0
  # Fallback hidden-timeout code in case the timeout_style feature is
  # unavailable.
  elif sleep --interruptible 0 ; then
    set timeout=0
  fi
fi
### END /etc/grub.d/00_header ###

### BEGIN /etc/grub.d/05_debian_theme ###
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray
### END /etc/grub.d/05_debian_theme ###

### BEGIN /etc/grub.d/10_linux ###
function gfxmode {
	set gfxpayload="${1}"
	if [ "${1}" = "keep" ]; then
		set vt_handoff=vt.handoff=7
	else
		set vt_handoff=
	fi
}
if [ "${recordfail}" != 1 ]; then
  if [ -e ${prefix}/gfxblacklist.txt ]; then
    if [ ${grub_platform} != pc ]; then
      set linux_gfx_mode=keep
    elif hwmatch ${prefix}/gfxblacklist.txt 3; then
      if [ ${match} = 0 ]; then
        set linux_gfx_mode=keep
      else
        set linux_gfx_mode=text
      fi
    else
      set linux_gfx_mode=text
    fi
  else
    set linux_gfx_mode=keep
  fi
else
  set linux_gfx_mode=text
fi
export linux_gfx_mode
'@ + "`n"
$cfgSimple = @'
menuentry 'Ubuntu' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-simple-@UUID@' {
	recordfail
	load_video
	gfxmode $linux_gfx_mode
	insmod gzio
	if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
	insmod part_gpt
	insmod ext2
	search --no-floppy --fs-uuid --set=root @BOOTUUID@
	linux	/vmlinuz-@K@ root=UUID=@UUID@ ro  console=tty1 console=ttyS0
	initrd	/initrd.img-@K@
}
'@ + "`n"
$cfgSubOpen = "submenu 'Advanced options for Ubuntu' `$menuentry_id_option 'gnulinux-advanced-@UUID@' {`n"
$cfgAdvanced = @'
	menuentry 'Ubuntu, with Linux @K@' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-@K@-advanced-@UUID@' {
		recordfail
		load_video
		gfxmode $linux_gfx_mode
		insmod gzio
		if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
		insmod part_gpt
		insmod ext2
		search --no-floppy --fs-uuid --set=root @BOOTUUID@
		echo	'Loading Linux @K@ ...'
		linux	/vmlinuz-@K@ root=UUID=@UUID@ ro  console=tty1 console=ttyS0
		echo	'Loading initial ramdisk ...'
		initrd	/initrd.img-@K@
	}
'@ + "`n"
$cfgRecovery = @'
	menuentry 'Ubuntu, with Linux @K@ (recovery mode)' --class ubuntu --class gnu-linux --class gnu --class os $menuentry_id_option 'gnulinux-@K@-recovery-@UUID@' {
		recordfail
		load_video
		insmod gzio
		if [ x$grub_platform = xxen ]; then insmod xzio; insmod lzopio; fi
		insmod part_gpt
		insmod ext2
		search --no-floppy --fs-uuid --set=root @BOOTUUID@
		echo	'Loading Linux @K@ ...'
		linux	/vmlinuz-@K@ root=UUID=@UUID@ ro recovery nomodeset dis_ucode_ldr console=tty1 console=ttyS0
		echo	'Loading initial ramdisk ...'
		initrd	/initrd.img-@K@
	}
'@ + "`n"
$cfgTail = @'

### END /etc/grub.d/10_linux ###

### BEGIN /etc/grub.d/30_uefi-firmware ###
if [ "$grub_platform" = "efi" ]; then
	fwsetup --is-supported
	if [ "$?" = 0 ]; then
		menuentry 'UEFI Firmware Settings' $menuentry_id_option 'uefi-firmware' {
			fwsetup
		}
	fi
fi
### END /etc/grub.d/30_uefi-firmware ###

### BEGIN /etc/grub.d/40_custom ###
# This file provides an easy way to add custom menu entries.  Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.
### END /etc/grub.d/40_custom ###

### BEGIN /etc/grub.d/41_custom ###
if [ -f  ${config_directory}/custom.cfg ]; then
  source ${config_directory}/custom.cfg
elif [ -z "${config_directory}" -a -f  $prefix/custom.cfg ]; then
  source $prefix/custom.cfg
fi
### END /etc/grub.d/41_custom ###
'@ + "`n"
$etcDefaultGrub = @'
# If you change this file or any /etc/default/grub.d/*.cfg file,
# run 'update-grub' afterwards to update /boot/grub/grub.cfg.
# For full documentation of the options in these files, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=Ubuntu
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX=""
'@ + "`n"
$cloudimgCfg = @'
# Cloud Image specific Grub settings for Generic Cloud Images
# CLOUD_IMG: This file was created/modified by the Cloud Image build process

# Set the recordfail timeout
GRUB_RECORDFAIL_TIMEOUT=0

# Do not wait on grub prompt
GRUB_TIMEOUT=0

# Set the grub console type
GRUB_TERMINAL=console
'@ + "`n"
$dmesgText = @'
[    0.000000] Booting Linux on physical CPU 0x0000000000 [0x413fd0c1]
[   12.345678] audit: type=1400 audit(1700000000.123:42): apparmor="DENIED" operation="open" class="file" profile="cri-containerd.apparmor.d" name="/proc/sys/kernel/foo" pid=1234 comm="runc" requested_mask="r" denied_mask="r" fsuid=0 ouid=0
[   13.000001] audit: type=1400 audit(1700000001.456:43): apparmor="DENIED" operation="capable" class="cap" profile="cri-containerd.apparmor.d" pid=2345 comm="sh" capability=21  capname="sys_admin"
[   20.000000] wireguard: WireGuard 1.0.0 loaded. See www.wireguard.com for information.
'@ + "`n"

function New-GrubCfgText {
    param([string[]]$Kernels, [switch]$NoNextEntryLogic, [switch]$NoSubmenu, [string[]]$DupEntry = @(), [string[]]$DropEntry = @(), [int]$Partuuid = 0, [switch]$HeaderOnly)
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append($cfgHead)
    [void]$sb.Append($(if ($NoNextEntryLogic) { $cfgPlainDefault } else { $cfgNextEntry }))
    [void]$sb.Append($cfgMiddle)
    # -HeaderOnly: 겹친 grub-mkconfig가 남기는 모양(L3 (a)) — 머리(00_header · 10_linux 머리)까지만 있고 메뉴 항목이 하나도 없다.
    if ($HeaderOnly) { return ($sb.ToString().Replace('@UUID@', $UUID).Replace('@BOOTUUID@', $BOOTUUID) -replace "`r`n", "`n") }
    if ($Kernels.Count -gt 0) { [void]$sb.Append($cfgSimple.Replace('@K@', $Kernels[0])) }
    if (-not $NoSubmenu) { [void]$sb.Append($cfgSubOpen) }
    foreach ($k in $Kernels) {
        if ($DropEntry -notcontains $k) {
            [void]$sb.Append($cfgAdvanced.Replace('@K@', $k))
            if ($DupEntry -contains $k) { [void]$sb.Append($cfgAdvanced.Replace('@K@', $k)) }
        }
        [void]$sb.Append($cfgRecovery.Replace('@K@', $k))
    }
    if (-not $NoSubmenu) { [void]$sb.Append("}`n") }
    [void]$sb.Append($cfgTail)
    $t = ($sb.ToString().Replace('@UUID@', $UUID).Replace('@BOOTUUID@', $BOOTUUID) -replace "`r`n", "`n")
    # $Partuuid > 0: 10_linux 머리에 'set partuuid=' 줄을 그 수만큼(첫 줄은 실제 모양 그대로, 나머지는 같은 줄의 반복).
    if ($Partuuid -gt 0) {
        $begin = "### BEGIN /etc/grub.d/10_linux ###`n"
        if ($t.IndexOf($begin, [StringComparison]::Ordinal) -lt 0) { throw 'New-GrubCfgText: 10_linux BEGIN line not found' }
        $extra = ''
        for ($i = 1; $i -lt $Partuuid; $i++) { $extra += "set partuuid=aaaaaaaa-0000-4000-8000-000000000001`n" }
        $t = $t.Replace($begin, $begin + ($cfgPartuuid -replace "`r`n", "`n") + $extra)
    }
    return $t
}

# 1024바이트 GRUB 환경 블록(머리 줄 + 변수 줄 + # 채움). 바이트 수는 UTF-8로 센다(F10의 비ASCII 값).
function Set-Grubenv([string]$path, [string[]]$vars) {
    $body = "# GRUB Environment Block`n" + (($vars | ForEach-Object { "$_`n" }) -join '')
    Write-Text $path ($body + ('#' * (1024 - [Text.Encoding]::UTF8.GetByteCount($body))))
}

# 픽스처 하나: <dir>/root(KT_ROOT) + <dir>/state(KT_FAKE_STATE). $Kernels는 새 것 먼저(grub.cfg 순서).
#   F 항목용: $PinText(고정 파일 원문 그대로 — 형식 변형) · $EnvVars(grubenv의 그 밖 변수 줄) · $EmptyVmlinuz/$EmptyInitrd(0바이트 파일) ·
#   $Partuuid('set partuuid=' 줄 수) · $AltKernels(update-grub 'alt' 모드의 템플릿 커널 순서) · $PgrepPlan/$PgrepFail(가짜 pgrep) ·
#   $Leftovers(가짜 루트 기준 상대 경로 — 죽은 실행이 남긴 파일) · $Utf8UpdateGrub(가짜 update-grub이 비ASCII 줄을 낸다) · $CmdlineExtra.
#   M1 · L3용: $Lsmod(모듈 이름 → lsmod 3열 이후 원문 '사용 수 [사용자 열]'; 없으면 '0') · $Modprobe(커널 → @{ 이름 = 출력 줄들 } — 가짜
#   modprobe의 지도) · $ModprobeMode(ok · missing · no-S) · $BootLists(가짜 루트 기준 상대 경로 → 내용; $null이면 그 이름의 디렉터리) ·
#   $EmptyMenu(grub.cfg = 메뉴 항목이 하나도 없는 머리만 — update-grub 가짜의 템플릿은 그대로).
#   F-A용: $Aliases(커널 → @{ 모듈 = 별칭들 } — 가짜 modinfo -F alias의 답, 순서 그대로) · $AliasFail(-F alias가 실패하는 모듈) ·
#   $ModinfoFail(커널 → 읽을 수 없는 모듈들: 그 커널의 -F name · -F alias가 kmod 31의 'could not get modinfo from' 실패를 낸다 — R3c F1) ·
#   $ModinfoAliasFail(커널 → -F alias만 그렇게 실패하는 모듈들 — R3c 하네스 추가).
#   R3-1용: $Extra(커널 → 이름들 — 적재되지 않았지만 그 커널의 모듈 목록에 있는 모듈: 별칭 답의 제공자 · 같은 이름의 형제; 가짜 modinfo의
#   이름 확인 · -F alias · -F name이 그 목록을 본다).
function New-Kt {
    param(
        [string[]]$Kernels = @($K7, $K6),
        [string]$Running = $K6,
        [string]$Default = '0',
        [string]$Pin = '',
        [object]$PinText = $null,
        [string]$NextEntry = '',
        [string[]]$EnvVars = @(),
        [string[]]$NoVmlinuz = @(), [string[]]$NoInitrd = @(), [string[]]$NoModulesDir = @(),
        [string[]]$EmptyVmlinuz = @(), [string[]]$EmptyInitrd = @(),
        [switch]$NoNextEntryLogic, [switch]$NoSubmenu, [string[]]$DupEntry = @(), [string[]]$DropEntry = @(),
        [int]$Partuuid = 0,
        [string[]]$AltKernels = @(),
        [string[]]$Loaded = @('wireguard', 'overlay', 'br_netfilter', 'nf_conntrack'),
        [hashtable]$Lacking = @{},
        [hashtable]$Lsmod = @{}, [hashtable]$Modprobe = @{}, [string]$ModprobeMode = 'ok', [hashtable]$BootLists = @{}, [switch]$EmptyMenu,
        [hashtable]$Aliases = @{}, [string[]]$AliasFail = @(), [hashtable]$Extra = @{}, [hashtable]$ModinfoFail = @{}, [hashtable]$ModinfoAliasFail = @{},
        [string]$UpdateGrubMode = 'ok', [string]$EditenvMode = 'ok', [string]$Uid = '0',
        [string[]]$PgrepPlan = @(), [string[]]$PgrepFail = @(),
        [string[]]$Leftovers = @(),
        [switch]$Utf8UpdateGrub,
        [string]$CmdlineExtra = ''
    )
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('kt-' + [guid]::NewGuid().ToString('N'))
    $script:fixtures += $dir
    $root = Join-Path $dir 'root'
    $state = Join-Path $dir 'state'
    foreach ($d in @("$root/boot/grub", "$root/etc/default/grub.d", "$root/var/run", "$root/proc", "$root/lib/modules", $state)) { [void][IO.Directory]::CreateDirectory($d) }
    foreach ($k in $Kernels) {
        if ($NoVmlinuz -notcontains $k) { Write-Text "$root/boot/vmlinuz-$k" $(if ($EmptyVmlinuz -contains $k) { '' } else { "fake vmlinuz $k`n" }) }
        if ($NoInitrd -notcontains $k) { Write-Text "$root/boot/initrd.img-$k" $(if ($EmptyInitrd -contains $k) { '' } else { "fake initrd $k`n" }) }
        Write-Text "$root/boot/config-$k" "CONFIG_LOCALVERSION=`"`"`n"
        if ($NoModulesDir -notcontains $k) { Write-Text "$root/lib/modules/$k/modules.dep" '' }
        $have = @($Loaded | Where-Object { -not ($Lacking.ContainsKey($k) -and $Lacking[$k] -contains $_) }) + @('ext4', 'xfs') + @(if ($Extra.ContainsKey($k)) { $Extra[$k] })
        Write-Text "$state/modules-$k" (($have -join "`n") + "`n")
    }
    $tmpl = New-GrubCfgText -Kernels $Kernels -NoNextEntryLogic:$NoNextEntryLogic -NoSubmenu:$NoSubmenu -DupEntry $DupEntry -DropEntry $DropEntry -Partuuid $Partuuid
    Write-Text "$state/grub.cfg.tmpl" $tmpl
    if ($AltKernels.Count -gt 0) { Write-Text "$state/grub.cfg.tmpl.alt" (New-GrubCfgText -Kernels $AltKernels -Partuuid $Partuuid) }
    $cfgNow = if ($EmptyMenu) { New-GrubCfgText -Kernels @() -HeaderOnly } else { $tmpl }
    Write-Text "$root/boot/grub/grub.cfg" $cfgNow.Replace('@DEFAULT@', $Default)
    Set-Grubenv "$root/boot/grub/grubenv" (@(if ($NextEntry) { "next_entry=$NextEntry" }) + @($EnvVars))
    Write-Text "$root/etc/default/grub" $etcDefaultGrub
    Write-Text "$root/etc/default/grub.d/50-cloudimg-settings.cfg" $cloudimgCfg
    if ($null -ne $PinText) { Write-Text "$root/etc/default/grub.d/99-kernel-trial-pin.cfg" ([string]$PinText) }
    elseif ($Pin) { Write-Text "$root/etc/default/grub.d/99-kernel-trial-pin.cfg" "# kernel-trial pin (test fixture)`nGRUB_DEFAULT=`"$Pin`"`n" }
    foreach ($rel in $Leftovers) { Write-Text (Join-Path $root $rel) "leftover of a killed run`n" }
    Write-Text "$root/var/run/reboot-required" "*** System restart required ***`n"
    Write-Text "$root/var/run/reboot-required.pkgs" "linux-image-$K7`nlinux-base`n"
    Write-Text "$root/proc/cmdline" "BOOT_IMAGE=/vmlinuz-$Running root=UUID=$UUID ro console=tty1 console=ttyS0$CmdlineExtra`n"
    Write-Text "$state/uname-r" "$Running`n"
    Write-Text "$state/id-u" "$Uid`n"
    # lsmod 본문: kmod 31의 '%-19s %8lu  %d[ 사용자,…]' 모양(머리 줄은 가짜가 붙인다). 3열 이후는 $Lsmod 원문(없으면 사용 수 0 · 사용자 없음).
    $lsLines = @(foreach ($m in $Loaded) { $tail = if ($Lsmod.ContainsKey($m)) { [string]$Lsmod[$m] } else { '0' }; ('{0,-24} {1,6}  {2}' -f $m, 16384, $tail).TrimEnd() })
    Write-Text "$state/lsmod" (($lsLines -join "`n") + "`n")
    foreach ($mk in $Modprobe.Keys) {
        $map = $Modprobe[$mk]
        Write-Text "$state/modprobe-$mk" ((@(foreach ($mn in $map.Keys) { foreach ($ml in @($map[$mn])) { "$mn $ml" } }) -join "`n") + "`n")
    }
    Write-Text "$state/modprobe.mode" "$ModprobeMode`n"
    # 가짜 modinfo -F alias의 지도: 커널 → @{ 모듈 = 별칭들(modinfo가 내는 순서 그대로) }. 실패시킬 모듈은 modinfo-alias.fail.
    foreach ($ak in $Aliases.Keys) {
        $amap = $Aliases[$ak]
        Write-Text "$state/aliases-$ak" ((@(foreach ($an in $amap.Keys) { foreach ($av in @($amap[$an])) { "$an $av" } }) -join "`n") + "`n")
    }
    if ($AliasFail.Count -gt 0) { Write-Text "$state/modinfo-alias.fail" (($AliasFail -join "`n") + "`n") }
    # 커널별로 '읽을 수 없는' 모듈(가짜 modinfo -F name · -F alias가 kmod 31의 'could not get modinfo from' 실패를 낸다): modinfo-fail-KVER.
    foreach ($fk in $ModinfoFail.Keys) { Write-Text "$state/modinfo-fail-$fk" ((@($ModinfoFail[$fk]) -join "`n") + "`n") }
    # 커널별로 -F alias만 실패하는 모듈(-F name은 답한다 — alias_successor의 지금 커널 쪽 -F alias 실패 분기용; R3c 하네스 추가): modinfo-alias-fail-KVER.
    foreach ($fk in $ModinfoAliasFail.Keys) { Write-Text "$state/modinfo-alias-fail-$fk" ((@($ModinfoAliasFail[$fk]) -join "`n") + "`n") }
    foreach ($rel in $BootLists.Keys) {
        if ($null -eq $BootLists[$rel]) { [void][IO.Directory]::CreateDirectory((Join-Path $root $rel)) } else { Write-Text (Join-Path $root $rel) ([string]$BootLists[$rel]) }
    }
    Write-Text "$state/dmesg" $dmesgText
    Write-Text "$state/update-grub.mode" "$UpdateGrubMode`n"
    Write-Text "$state/grub-editenv.mode" "$EditenvMode`n"
    if ($PgrepPlan.Count -gt 0) { Write-Text "$state/pgrep.plan" (($PgrepPlan -join "`n") + "`n") }
    if ($PgrepFail.Count -gt 0) { Write-Text "$state/pgrep.fail" (($PgrepFail -join "`n") + "`n") }
    if ($Utf8UpdateGrub) { Write-Text "$state/update-grub.utf8" "$NONASCII`n" }
    Write-Text "$state/calls.log" ''
    return [pscustomobject]@{ Dir = $dir; Root = $root; State = $state; RootPosix = (ConvertTo-BashPath $root); StatePosix = (ConvertTo-BashPath $state) }
}

# 실행 중 커널(6.17)이 고정된 일관 상태(고정 파일 = grub.cfg 기본값). $p로 New-Kt 인자를 덮어쓴다.
function New-Pinned([hashtable]$p = @{}) {
    $q = @{ Pin = (Get-PinValue $K6); Default = (Get-PinValue $K6) }
    foreach ($k in $p.Keys) { $q[$k] = $p[$k] }
    return (New-Kt @q)
}

# M1의 6.17 → 7.0 픽스처: 6.17이 고정된 일관 상태 + 실제 넷의 lsmod 모양($M1Loaded · $M1Lsmod) + 7.0에서 이름이 없는 넷 + 7.0의 실제
#   modprobe 지도($MP7) + 6.17의 실제 별칭($AL6 — F-A) + 7.0의 실제 별칭과 제공자($AL7Real · $M1Extra7 — R3-1). $p로 덮어쓴다(Aliases · Extra를
#   덮어쓰는 케이스는 7.0 쪽도 함께 준다).
function New-M1([hashtable]$p = @{}) {
    $q = @{ Pin = (Get-PinValue $K6); Default = (Get-PinValue $K6); Loaded = $M1Loaded; Lsmod = $M1Lsmod.Clone(); Lacking = @{ $K7 = $M1Renamed }; Modprobe = @{ $K7 = $MP7 }; Aliases = @{ $K6 = $AL6; $K7 = $AL7Real }; Extra = @{ $K7 = $M1Extra7 } }
    foreach ($k in $p.Keys) { $q[$k] = $p[$k] }
    return (New-Kt @q)
}

# ---------- 픽스처 상태 읽기 ----------
function Get-CfgDefault($fx) {
    $t = [IO.File]::ReadAllText((Join-Path $fx.Root 'boot/grub/grub.cfg'))
    $m = [regex]::Matches($t, '(?m)^\s*if \[ "\$\{next_entry\}" \] ; then\n\s*set default="\$\{next_entry\}"\n\s*set next_entry=\n\s*save_env next_entry\n\s*set boot_once=true\n\s*else\n\s*set default="([^"\n]*)"\n\s*fi$')
    if ($m.Count -ne 1) { return "<next_entry blocks: $($m.Count)>" }
    return $m[0].Groups[1].Value
}
function Get-EnvVars($fx) {
    $t = [IO.File]::ReadAllText((Join-Path $fx.Root 'boot/grub/grubenv'))
    return ,@($t -split "`n" | Where-Object { $_ -and -not $_.StartsWith('#') })
}
function Get-NextEntry($fx) {
    $v = @((Get-EnvVars $fx) | Where-Object { $_.StartsWith('next_entry=') })
    if ($v.Count -eq 0) { return $null }
    if ($v.Count -gt 1) { return '<next_entry listed more than once>' }
    return $v[0].Substring('next_entry='.Length)
}
function Get-PinPath($fx) { return (Join-Path $fx.Root 'etc/default/grub.d/99-kernel-trial-pin.cfg') }
function Get-PinText($fx) { $p = Get-PinPath $fx; if (Test-Path -LiteralPath $p -PathType Leaf) { return [IO.File]::ReadAllText($p) } else { return $null } }
function Get-PinHash($fx) { $p = Get-PinPath $fx; if (Test-Path -LiteralPath $p -PathType Leaf) { return (Get-Sha $p) } else { return $null } }
function Get-CfgHash($fx) { return (Get-Sha (Join-Path $fx.Root 'boot/grub/grub.cfg')) }

# 고정 파일 내용: ASCII 주석 줄 1–2개('# ') + 정확히 GRUB_DEFAULT="<값>" 한 줄, 그 밖의 줄 없음, LF.
function Test-PinContent([string]$text, [string]$value) {
    if ($null -eq $text -or $text.Contains("`r") -or -not $text.EndsWith("`n")) { return $false }
    if ([regex]::IsMatch($text, '[^\n\x20-\x7E]')) { return $false }
    $lines = @($text.Substring(0, $text.Length - 1) -split "`n")
    $comments = @($lines | Where-Object { $_.StartsWith('# ') })
    $assign = @($lines | Where-Object { -not $_.StartsWith('#') })
    return ($comments.Count -ge 1 -and $comments.Count -le 2 -and $assign.Count -eq 1 -and (Test-Same $assign[0] "GRUB_DEFAULT=`"$value`"") -and ($comments.Count + $assign.Count) -eq $lines.Count)
}

# 가짜 루트의 파일 목록(상대 경로 → SHA-256). 디렉터리는 'D <rel>'.
function Get-Snapshot([string]$root) {
    $h = @{}
    foreach ($it in @(Get-ChildItem -LiteralPath $root -Recurse -Force)) {
        $rel = [IO.Path]::GetRelativePath($root, $it.FullName) -replace '\\', '/'
        if ($it.PSIsContainer) { $h["D $rel"] = '' } else { $h["F $rel"] = (Get-Sha $it.FullName) }
    }
    return $h
}

# 한 실행의 부작용 판정: 바뀌어도 되는 것은 고정 파일 · grub.cfg(가짜 update-grub이 마지막에 쓴 내용과 같을 때) ·
# grubenv(가짜 grub-editenv가 마지막에 쓴 내용과 같을 때)뿐이다.
function Test-Blast($fx, [hashtable]$before, [hashtable]$after, [string]$label) {
    $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($k in $before.Keys) { [void]$keys.Add($k) }
    foreach ($k in $after.Keys) { [void]$keys.Add($k) }
    foreach ($k in $keys) {
        $inB = $before.ContainsKey($k); $inA = $after.ContainsKey($k)
        if ($inB -and $inA -and (Test-Same $before[$k] $after[$k])) { continue }
        if (Test-Same $k 'F etc/default/grub.d/99-kernel-trial-pin.cfg') { continue }
        if ($inA -and (Test-Same $k 'F boot/grub/grub.cfg')) {
            $last = Join-Path $fx.State 'grub.cfg.last'
            if ((Test-Path -LiteralPath $last) -and (Test-Same (Get-Sha $last) $after[$k])) { continue }
        }
        if ($inA -and (Test-Same $k 'F boot/grub/grubenv')) {
            $last = Join-Path $fx.State 'grubenv.last'
            if ((Test-Path -LiteralPath $last) -and (Test-Same (Get-Sha $last) $after[$k])) { continue }
        }
        $what = if (-not $inB) { 'added' } elseif (-not $inA) { 'removed' } else { 'changed' }
        $script:blast.Add("${label}: $k $what")
    }
}

function Get-FileLines([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return ,@() }
    $t = [IO.File]::ReadAllText($path)
    return ,@($t -split "`n" | Where-Object { $_ -ne '' })
}

# 스크립트를 운영자와 같은 방식으로 실행한다: bash -s -- <인자>, 표준 입력 = 스크립트 바이트 + $trailer(기본 CRLF — PowerShell 파이프가 붙이는 꼬리).
# 자식 환경만 바꾼다(KT_ROOT · KT_FAKE_STATE · PATH · MSYS_*) — 이 프로세스의 환경은 그대로다.
# -CloseStdout: 스크립트를 보내기 전에 표준 출력의 읽는 쪽을 닫는다(SSH 세션이 끊긴 것과 같다 — 첫 줄부터 쓰기가 EPIPE/SIGPIPE).
# -NoModprobe: 가짜 modprobe만 뺀 두 번째 가짜 bin을 PATH 맨 앞에 둔다(M1-6a — modprobe가 PATH 어디에도 없다).
function Invoke-KT($fx, [string[]]$cmdArgs = @(), [string]$trailer = "`r`n", [string]$label = '', [switch]$CloseStdout, [switch]$NoModprobe) {
    $script:runNo++
    if (-not $label) { $label = "$($script:group)#$($script:runNo)" }
    $res = [pscustomobject]@{ label = $label; root = $fx.RootPosix; missing = $false; closed = [bool]$CloseStdout; code = 127; out = ''; err = ''; lines = [string[]]@(); calls = [string[]]@(); ug = 0; set = 0; unset = 0; pg = 0; mp = 0; trip = 0; writes = 0; outBytes = [byte[]]@(); errBytes = [byte[]]@() }
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        $res.missing = $true
        $res.out = "<missing script: $scriptPath>"; $res.lines = [string[]]@($res.out)
        $script:runs.Add($res)
        return $res
    }
    $callsPath = Join-Path $fx.State 'calls.log'
    $nBefore = (Get-FileLines $callsPath).Count
    $before = Get-Snapshot $fx.Root
    $scriptBytes = [IO.File]::ReadAllBytes($scriptPath)
    $tail = [Text.Encoding]::ASCII.GetBytes($trailer)
    $payload = [byte[]]::new($scriptBytes.Length + $tail.Length)
    [Array]::Copy($scriptBytes, 0, $payload, 0, $scriptBytes.Length)
    [Array]::Copy($tail, 0, $payload, $scriptBytes.Length, $tail.Length)
    $psi = [Diagnostics.ProcessStartInfo]::new($script:bash)
    foreach ($a in @('-s', '--') + @($cmdArgs)) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false
    $psi.Environment['KT_ROOT'] = $fx.RootPosix
    $psi.Environment['KT_FAKE_STATE'] = $fx.StatePosix
    $psi.Environment['PATH'] = if ($NoModprobe) { $script:childPathNoMp } else { $script:childPath }
    $psi.Environment['MSYS_NO_PATHCONV'] = '1'
    $psi.Environment['MSYS2_ARG_CONV_EXCL'] = '*'
    $p = [Diagnostics.Process]::Start($psi)
    $outMs = [IO.MemoryStream]::new(); $errMs = [IO.MemoryStream]::new()
    $t1 = $null
    if ($CloseStdout) { $p.StandardOutput.Close() } else { $t1 = $p.StandardOutput.BaseStream.CopyToAsync($outMs) }
    $t2 = $p.StandardError.BaseStream.CopyToAsync($errMs)
    try { $p.StandardInput.BaseStream.Write($payload, 0, $payload.Length); $p.StandardInput.BaseStream.Flush(); $p.StandardInput.Close() } catch [IO.IOException] { }
    if ($p.WaitForExit(120000)) { $res.code = $p.ExitCode } else { try { $p.Kill($true) } catch { }; $res.code = -2 }
    if ($t1) { [void]$t1.Wait(10000) }
    [void]$t2.Wait(10000)
    $res.outBytes = $outMs.ToArray(); $res.errBytes = $errMs.ToArray()
    $res.out = [Text.Encoding]::UTF8.GetString($res.outBytes)
    $res.err = [Text.Encoding]::UTF8.GetString($res.errBytes)
    $body = if ($res.out.EndsWith("`n")) { $res.out.Substring(0, $res.out.Length - 1) } else { $res.out }
    # 직접 대입한다 — if 식의 출력으로 받으면 원소 하나짜리 배열이 문자열 하나로 풀린다.
    $res.lines = [string[]]@()
    if ($body.Length -gt 0) { $res.lines = [string[]]@($body -split "`n") }
    $all = Get-FileLines $callsPath
    $res.calls = [string[]]@()
    if ($all.Count -gt $nBefore) { $res.calls = [string[]]@($all[$nBefore..($all.Count - 1)]) }
    $res.ug = @($res.calls | Where-Object { $_.StartsWith('update-grub', [StringComparison]::Ordinal) }).Count
    $res.set = @($res.calls | Where-Object { $_.StartsWith('grub-editenv cmd=set ', [StringComparison]::Ordinal) }).Count
    $res.unset = @($res.calls | Where-Object { $_.StartsWith('grub-editenv cmd=unset ', [StringComparison]::Ordinal) }).Count
    $res.pg = @($res.calls | Where-Object { $_.StartsWith('pgrep ', [StringComparison]::Ordinal) }).Count
    $res.mp = @($res.calls | Where-Object { $_.StartsWith('modprobe ', [StringComparison]::Ordinal) }).Count
    $res.trip = @($res.calls | Where-Object { $_.StartsWith('TRIPWIRE', [StringComparison]::Ordinal) }).Count
    $res.writes = $res.ug + $res.set + $res.unset
    Test-Blast $fx $before (Get-Snapshot $fx.Root) $label
    $script:runs.Add($res)
    return $res
}

# bash 원문을 (1) 주석만 지운 코드(Code) (2) 주석을 지우고 따옴표 문자열 내용을 비운 코드(Bare)로 나눈다.
# '#'은 단어 시작(줄 머리 · 공백 · ; & | ( ) 뒤)일 때만 주석이다. 따옴표가 닫히지 않으면 Ok=$false(판정 불가 = FAIL).
function Split-BashSource([string]$src) {
    $code = [Text.StringBuilder]::new(); $bare = [Text.StringBuilder]::new()
    $n = $src.Length; $i = 0; $ok = $true
    $wordStart = " `t`n;&|()"
    while ($i -lt $n) {
        $c = $src[$i]
        if ($c -eq [char]'#' -and ($i -eq 0 -or $wordStart.IndexOf($src[$i - 1]) -ge 0)) {
            while ($i -lt $n -and $src[$i] -ne [char]"`n") { $i++ }
            continue
        }
        if ($c -eq [char]'\') {
            $len = [Math]::Min(2, $n - $i)
            [void]$code.Append($src, $i, $len); [void]$bare.Append($src, $i, $len); $i += $len; continue
        }
        if ($c -eq [char]"'") {
            $ansi = ($i -gt 0 -and $src[$i - 1] -eq [char]'$')
            $j = $i + 1
            while ($j -lt $n) {
                if ($ansi -and $src[$j] -eq [char]'\') { $j += 2; continue }
                if ($src[$j] -eq [char]"'") { break }
                $j++
            }
            if ($j -ge $n) { $ok = $false; break }
            [void]$code.Append($src, $i, $j - $i + 1); [void]$bare.Append("''"); $i = $j + 1; continue
        }
        if ($c -eq [char]'"') {
            $j = $i + 1
            while ($j -lt $n) {
                if ($src[$j] -eq [char]'\') { $j += 2; continue }
                if ($src[$j] -eq [char]'"') { break }
                $j++
            }
            if ($j -ge $n) { $ok = $false; break }
            [void]$code.Append($src, $i, $j - $i + 1); [void]$bare.Append('""'); $i = $j + 1; continue
        }
        [void]$code.Append($c); [void]$bare.Append($c); $i++
    }
    return [pscustomobject]@{ Ok = $ok; Code = $code.ToString(); Bare = $bare.ToString() }
}

# ---------- 가짜 명령(공용 bin) ----------
$fakeFiles = [ordered]@{}
$fakeFiles['uname'] = @'
#!/bin/sh
# fake uname (kernel-trial harness): only "uname -r" -> $KT_FAKE_STATE/uname-r
printf 'uname %s\n' "$*" >> "$KT_FAKE_STATE/calls.log"
if [ "$#" -eq 1 ] && [ "$1" = "-r" ]; then cat "$KT_FAKE_STATE/uname-r"; exit 0; fi
echo "fake uname: only -r is supported" >&2
exit 1
'@
$fakeFiles['id'] = @'
#!/bin/sh
# fake id (kernel-trial harness): only "id -u" -> $KT_FAKE_STATE/id-u
printf 'id %s\n' "$*" >> "$KT_FAKE_STATE/calls.log"
if [ "$#" -eq 1 ] && [ "$1" = "-u" ]; then cat "$KT_FAKE_STATE/id-u"; exit 0; fi
echo "fake id: only -u is supported" >&2
exit 1
'@
$fakeFiles['lsmod'] = @'
#!/bin/sh
# fake lsmod (kernel-trial harness): the header + $KT_FAKE_STATE/lsmod verbatim ("NAME SIZE COUNT [USERS]" lines, the kmod 31 shape --
#   the fixture writes column 3 on and may give any shape: no column 4, '-', a trailing comma, [permanent], odd characters)
printf 'lsmod %s\n' "$*" >> "$KT_FAKE_STATE/calls.log"
echo "Module                  Size  Used by"
cat "$KT_FAKE_STATE/lsmod"
exit 0
'@
$fakeFiles['modprobe'] = @'
#!/bin/sh
# fake modprobe (kernel-trial harness): only "modprobe -S KVER --show-depends NAME".
# Map $KT_FAKE_STATE/modprobe-KVER, lines "NAME OUTPUT...": every line of NAME prints OUTPUT and the call exits 0; NAME absent ->
#   "modprobe: FATAL: Module NAME not found in directory /lib/modules/KVER" on stderr and exit 1 (the kmod 31 shapes, checked 2026-10-06
#   against the real linux-modules 6.17.0-1020 / 7.0.0-1012 oracle trees).
# Mode $KT_FAKE_STATE/modprobe.mode: ok | missing (exit 127, as if the binary vanished) | no-S (exit 1 "invalid option -- 'S'", a modprobe
#   without -S). Any other argument shape -> exit 1.
S=${KT_FAKE_STATE:?}
printf 'modprobe %s\n' "$*" >> "$S/calls.log"
mode=ok; [ -f "$S/modprobe.mode" ] && read -r mode < "$S/modprobe.mode"
case $mode in
  missing) echo "modprobe: command not found" >&2; exit 127 ;;
  no-S) echo "modprobe: invalid option -- 'S'" >&2; exit 1 ;;
esac
if [ "$#" -ne 4 ] || [ "$1" != "-S" ] || [ "$3" != "--show-depends" ]; then echo "fake modprobe: unsupported arguments: $*" >&2; exit 1; fi
found=0
if [ -f "$S/modprobe-$2" ]; then
  while read -r mn ml || [ -n "$mn" ]; do
    if [ "$mn" = "$4" ]; then found=1; printf '%s\n' "$ml"; fi
  done < "$S/modprobe-$2"
fi
[ "$found" = 1 ] && exit 0
echo "modprobe: FATAL: Module $4 not found in directory /lib/modules/$2" >&2
exit 1
'@
$fakeFiles['modinfo'] = @'
#!/usr/bin/env bash
# fake modinfo (kernel-trial harness): "modinfo -k KVER MODULE" succeeds iff MODULE is listed in $KT_FAKE_STATE/modules-KVER;
#   "modinfo -k KVER -F alias MODULE" (MODULE listed) prints MODULE's aliases in order from $KT_FAKE_STATE/aliases-KVER ("MODULE ALIAS" lines;
#   none -> no output, exit 0) and fails with exit 1 for a MODULE listed in $KT_FAKE_STATE/modinfo-alias.fail (any kernel) or in
#   modinfo-alias-fail-KVER (that kernel only; R3c); "modinfo -k KVER -F name MODULE" (MODULE listed) prints the listed name, one line, exit 0 --
#   unless MODULE is listed in modinfo-fail-KVER, where -F name and -F alias both fail like kmod 31 on an unreadable file (R3c F1). Not listed ->
#   the kmod 31 message "modinfo: ERROR: Module MODULE not found." and
#   exit 1. Module names compare with '-' and '_' alike, as kmod does (2026-10-07, kmod 31 on the real 6.17.0-1020 / 7.0.0-1012 trees:
#   "modinfo -F name aes-ce-blk" -> "aes_ce_blk"; -F name of a builtin such as drbg -> "drbg"). Like kmod 31, -F name / -F alias of a MODULE
#   that names no listed module but is an alias declared by listed modules resolve to those modules (-F name -> their names, one per line;
#   -F alias -> their aliases; R3b F3). Real 2026-10-07: 6.17 "-F name aes" -> aes_arm64, "-F alias aes" -> crypto-aes aes; 7.0 "-F name net-pf-40"
#   -> three names. The plain "modinfo -k KVER MODULE" (no -F) still needs the name itself (the real tool resolves aliases there too -- review F9).
S=${KT_FAKE_STATE:?}
printf 'modinfo %s\n' "$*" >> "$S/calls.log"
if [ "$#" -eq 5 ] && [ "$1" = "-k" ] && [ "$3" = "-F" ] && { [ "$4" = "alias" ] || [ "$4" = "name" ]; }; then k=$2; mod=$5; field=$4
elif [ "$#" -eq 3 ] && [ "$1" = "-k" ]; then k=$2; mod=$3; field=""
else echo "fake modinfo: usage: modinfo -k KVER [-F alias|name] MODULE" >&2; exit 2; fi
want=${mod//-/_}
name=""
if [ -f "$S/modules-$k" ]; then
  while IFS= read -r m || [ -n "$m" ]; do [ "${m//-/_}" = "$want" ] && name=${m//-/_}; done < "$S/modules-$k"
fi
# Like kmod 31, -F name / -F alias of a MODULE that names no listed module but is an alias declared by listed modules resolve to those
#   modules (-F name -> their names, -F alias -> their aliases). Real 2026-10-07: 6.17 "-F name aes" -> aes_arm64, "-F alias aes" ->
#   crypto-aes aes; 7.0 "-F name net-pf-40" -> three names.
listed() { local m; [ -f "$S/modules-$k" ] || return 1; while IFS= read -r m || [ -n "$m" ]; do [ "${m//-/_}" = "$1" ] && return 0; done < "$S/modules-$k"; return 1; }
if [ -z "$name" ] && [ -n "$field" ] && [ -f "$S/aliases-$k" ]; then
  res=""
  while IFS= read -r line || [ -n "$line" ]; do
    key=${line%% *}; key=${key//-/_}; al=${line#* }
    if [ "${al//-/_}" = "$want" ] && listed "$key"; then case " $res " in *" $key "*) ;; *) res="$res $key" ;; esac; fi
  done < "$S/aliases-$k"
  if [ -n "$res" ]; then
    for r in $res; do
      if [ "$field" = name ]; then printf '%s\n' "$r"; continue; fi
      while IFS= read -r line || [ -n "$line" ]; do key=${line%% *}; [ "${key//-/_}" = "$r" ] && printf '%s\n' "${line#* }"; done < "$S/aliases-$k"
    done
    exit 0
  fi
fi
if [ -z "$name" ]; then echo "modinfo: ERROR: Module $mod not found." >&2; exit 1; fi
# A listed module whose file (or modules.builtin.modinfo entry) cannot be read: kmod 31 fails -F name / -F alias with exit 1 and
#   "could not get modinfo from '<mod>': Invalid argument" (2026-10-07, real tree with a truncated .ko.zst) -- per kernel, modinfo-fail-KVER.
if [ -n "$field" ] && [ -f "$S/modinfo-fail-$k" ]; then
  while IFS= read -r m || [ -n "$m" ]; do
    if [ "${m//-/_}" = "$want" ]; then echo "modinfo: ERROR: could not get modinfo from '$mod': Invalid argument" >&2; exit 1; fi
  done < "$S/modinfo-fail-$k"
fi
case $field in
  '') echo "filename:       /lib/modules/$k/kernel/fake/$name.ko"; exit 0 ;;
  name) printf '%s\n' "$name"; exit 0 ;;
esac
if [ -f "$S/modinfo-alias.fail" ]; then
  while IFS= read -r m || [ -n "$m" ]; do
    if [ "${m//-/_}" = "$want" ]; then echo "modinfo: ERROR: could not get modinfo from '$mod': Exec format error" >&2; exit 1; fi
  done < "$S/modinfo-alias.fail"
fi
# Per kernel, -F alias only (-F name answered above): modinfo-alias-fail-KVER -- a synthetic shape for alias_successor's running-side
#   "-F alias failed" branch (R3c, harness addition; kmod reads name and aliases from the same file, so a real tree fails both).
if [ -f "$S/modinfo-alias-fail-$k" ]; then
  while IFS= read -r m || [ -n "$m" ]; do
    if [ "${m//-/_}" = "$want" ]; then echo "modinfo: ERROR: could not get modinfo from '$mod': Invalid argument" >&2; exit 1; fi
  done < "$S/modinfo-alias-fail-$k"
fi
if [ -f "$S/aliases-$k" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    key=${line%% *}
    if [ "${key//-/_}" = "$want" ]; then printf '%s\n' "${line#* }"; fi
  done < "$S/aliases-$k"
fi
exit 0
'@
$fakeFiles['dmesg'] = @'
#!/bin/sh
# fake dmesg (kernel-trial harness): $KT_FAKE_STATE/dmesg
printf 'dmesg %s\n' "$*" >> "$KT_FAKE_STATE/calls.log"
[ -f "$KT_FAKE_STATE/dmesg" ] && cat "$KT_FAKE_STATE/dmesg"
exit 0
'@
$fakeFiles['apt-config'] = @'
#!/bin/sh
# fake apt-config (kernel-trial harness): only "apt-config dump Unattended-Upgrade::Automatic-Reboot"
printf 'apt-config %s\n' "$*" >> "$KT_FAKE_STATE/calls.log"
if [ "$#" -eq 2 ] && [ "$1" = "dump" ] && [ "$2" = "Unattended-Upgrade::Automatic-Reboot" ]; then
  echo 'Unattended-Upgrade::Automatic-Reboot "false";'
  exit 0
fi
echo "fake apt-config: unsupported arguments" >&2
exit 1
'@
$fakeFiles['update-grub'] = @'
#!/usr/bin/env bash
# fake update-grub (kernel-trial harness): regenerates $KT_ROOT/boot/grub/grub.cfg from the fixture template like grub-mkconfig:
# GRUB_DEFAULT = the value left after sourcing /etc/default/grub, then /etc/default/grub.d/*.cfg in name order (empty -> 0).
# Modes per call ($KT_FAKE_STATE/update-grub.mode, space separated; the last one repeats):
#   ok | fail (exit 1, files untouched) | noop (exit 0, files untouched) | wrong (writes default 1) | dup-ids (right default, every 10_linux id twice)
#   | alt (right default from the other template $KT_FAKE_STATE/grub.cfg.tmpl.alt)
#   | fail-leave-new (exit 1, grub.cfg untouched, a partial grub.cfg.new left behind -- what a grub-script-check failure leaves)
# $KT_FAKE_STATE/update-grub.utf8, if present, is copied to stderr first (non-ASCII tool output).
S=${KT_FAKE_STATE:?}; R=${KT_ROOT:?}
printf 'update-grub %s\n' "$*" >> "$S/calls.log"
n=0; [ -f "$S/update-grub.count" ] && read -r n < "$S/update-grub.count"
n=$((n + 1)); printf '%s\n' "$n" > "$S/update-grub.count"
modes=(ok); [ -f "$S/update-grub.mode" ] && read -r -a modes < "$S/update-grub.mode"
[ "${#modes[@]}" -gt 0 ] || modes=(ok)
i=$((n - 1)); [ "$i" -lt "${#modes[@]}" ] || i=$((${#modes[@]} - 1))
mode=${modes[$i]}
[ -f "$S/update-grub.utf8" ] && cat "$S/update-grub.utf8" >&2
echo "Sourcing file \`/etc/default/grub'" >&2
for x in "$R"/etc/default/grub.d/*.cfg; do [ -e "$x" ] && echo "Sourcing file \`${x#"$R"}'" >&2; done
echo "Generating grub configuration file ..." >&2
case $mode in
  fail) echo "fake update-grub: failure injected (call $n)" >&2; exit 1 ;;
  fail-leave-new) printf '# partial\n' > "$R/boot/grub/grub.cfg.new"; echo "Syntax errors are detected in generated GRUB config file (fake, call $n)." >&2; exit 1 ;;
  noop) echo "done" >&2; exit 0 ;;
esac
val=$(GRUB_DEFAULT=; . "$R/etc/default/grub"; for x in "$R"/etc/default/grub.d/*.cfg; do [ -e "$x" ] && . "$x"; done; printf '%s' "${GRUB_DEFAULT:-0}")
[ "$mode" = wrong ] && val=1
dup=0; [ "$mode" = dup-ids ] && dup=1
tmpl="$S/grub.cfg.tmpl"; [ "$mode" = alt ] && tmpl="$S/grub.cfg.tmpl.alt"
cfg="$R/boot/grub/grub.cfg"
awk -v val="$val" -v dup="$dup" '
  { gsub(/@DEFAULT@/, val); print }
  /^### BEGIN \/etc\/grub.d\/10_linux ###$/ { cap = 1 }
  cap { buf = buf $0 "\n" }
  /^### END \/etc\/grub.d\/10_linux ###$/ { cap = 0 }
  END { if (dup == 1) printf "%s", buf }
' "$tmpl" > "$cfg.new" || exit 1
mv -f "$cfg.new" "$cfg" || exit 1
cp -f "$cfg" "$S/grub.cfg.last"
for k in "$R"/boot/vmlinuz-*; do [ -e "$k" ] && echo "Found linux image: ${k#"$R"}" >&2; done
echo "done" >&2
exit 0
'@
$fakeFiles['grub-editenv'] = @'
#!/usr/bin/env bash
# fake grub-editenv (kernel-trial harness): FILE list | set K=V... | unset K... on a 1024-byte GRUB environment block.
# Mode words ($KT_FAKE_STATE/grub-editenv.mode, space separated, combinable): ok | set-noop (set exits 0 and writes nothing)
#   | set-wrong (set writes V-wrong) | unset-noop (unset exits 0 and removes nothing)
S=${KT_FAKE_STATE:?}
f=${1-}; cmd=${2-}
printf 'grub-editenv cmd=%s file=%s args=%s\n' "$cmd" "$f" "${*:3}" >> "$S/calls.log"
modes=(ok); [ -f "$S/grub-editenv.mode" ] && read -r -a modes < "$S/grub-editenv.mode"
has() { local m; for m in "${modes[@]}"; do [ "$m" = "$1" ] && return 0; done; return 1; }
if [ ! -f "$f" ]; then printf "grub-editenv: error: cannot open \`%s': No such file or directory.\n" "$f" >&2; exit 1; fi
keys=(); declare -A vals=()
while IFS= read -r line || [ -n "$line" ]; do
  case $line in
    '#'*|'') continue ;;
    *=*) k=${line%%=*}; [ -n "${vals[$k]+x}" ] || keys+=("$k"); vals[$k]=${line#*=} ;;
  esac
done < "$f"
save() {
  local body='# GRUB Environment Block'$'\n' k pad
  for k in "${keys[@]}"; do [ -n "${vals[$k]+x}" ] && body+="$k=${vals[$k]}"$'\n'; done
  pad=$((1024 - ${#body}))
  if [ "$pad" -lt 0 ]; then echo "grub-editenv: error: environment block too small." >&2; exit 1; fi
  { printf '%s' "$body"; printf "%${pad}s" '' | tr ' ' '#'; } > "$f.new" && mv -f "$f.new" "$f" && cp -f "$f" "$S/grubenv.last"
}
shift 2 2>/dev/null
case $cmd in
  list) for k in "${keys[@]}"; do [ -n "${vals[$k]+x}" ] && printf '%s=%s\n' "$k" "${vals[$k]}"; done; exit 0 ;;
  set)
    has set-noop && exit 0
    for kv in "$@"; do
      k=${kv%%=*}; v=${kv#*=}
      has set-wrong && v="$v-wrong"
      [ -n "${vals[$k]+x}" ] || keys+=("$k")
      vals[$k]=$v
    done
    save; exit $? ;;
  unset)
    has unset-noop && exit 0
    for k in "$@"; do unset "vals[$k]"; done; save; exit $? ;;
  *) echo "grub-editenv: error: unrecognized command \`$cmd'." >&2; exit 1 ;;
esac
'@
$fakeFiles['pgrep'] = @'
#!/bin/sh
# fake pgrep (kernel-trial harness): only "pgrep -a -x NAME". Calls are counted per NAME ($KT_FAKE_STATE/pgrep.count.NAME).
# Processes: $KT_FAKE_STATE/pgrep.plan lines "NAME CALLS PID ARGS..." (CALLS = * every call | N only the N-th call | N+ from the N-th call on)
#   -> "PID ARGS" lines and exit 0; none -> exit 1. Failures: $KT_FAKE_STATE/pgrep.fail lines "NAME CALLS EXIT MESSAGE..." (NAME * = any).
S=${KT_FAKE_STATE:?}
printf 'pgrep %s\n' "$*" >> "$S/calls.log"
if [ "$#" -ne 3 ] || [ "$1" != "-a" ] || [ "$2" != "-x" ]; then echo "fake pgrep: usage: pgrep -a -x NAME" >&2; exit 2; fi
name=$3
n=0; [ -f "$S/pgrep.count.$name" ] && read -r n < "$S/pgrep.count.$name"
n=$((n + 1)); printf '%s\n' "$n" > "$S/pgrep.count.$name"
hit() { case $1 in '*') return 0 ;; *+) [ "$n" -ge "${1%+}" ] ;; *) [ "$n" -eq "$1" ] ;; esac; }
if [ -f "$S/pgrep.fail" ]; then
  while read -r fn fc fx fm; do
    [ -n "$fn" ] || continue
    if { [ "$fn" = '*' ] || [ "$fn" = "$name" ]; } && hit "$fc"; then printf '%s\n' "${fm:-fake pgrep: failure injected}" >&2; exit "$fx"; fi
  done < "$S/pgrep.fail"
fi
found=0
if [ -f "$S/pgrep.plan" ]; then
  while read -r pn pc pp pa; do
    [ -n "$pn" ] || continue
    if [ "$pn" = "$name" ] && hit "$pc"; then printf '%s %s\n' "$pp" "$pa"; found=1; fi
  done < "$S/pgrep.plan"
fi
[ "$found" = 1 ] && exit 0
exit 1
'@
$tripwire = @'
#!/bin/sh
# tripwire (kernel-trial harness): kernel-trial.sh must never call this command
printf 'TRIPWIRE %s %s\n' "${0##*/}" "$*" >> "$KT_FAKE_STATE/calls.log"
echo "tripwire: ${0##*/} must never be called" >&2
exit 99
'@
$tripwireNames = @('reboot', 'shutdown', 'poweroff', 'halt', 'kexec', 'grub-reboot', 'grub-set-default', 'grub-mkconfig', 'grub-install', 'apt', 'apt-get', 'dpkg', 'systemctl')
foreach ($t in $tripwireNames) { $fakeFiles[$t] = $tripwire }

try {
    $script:binDir = Join-Path ([IO.Path]::GetTempPath()) ('kt-bin-' + [guid]::NewGuid().ToString('N'))
    $script:fixtures += $script:binDir
    Write-Text (Join-Path $script:binDir '.kt-fake-bin') "kernel-trial harness fake bin`n"
    foreach ($name in $fakeFiles.Keys) {
        $fp = Join-Path $script:binDir $name
        Write-Text $fp ($fakeFiles[$name] -replace "`r`n", "`n")
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($fp, [IO.UnixFileMode]'UserRead, UserWrite, UserExecute') }
    }
    # 두 번째 가짜 bin: modprobe만 없다(M1-6a). 표지 파일은 같다 — 다른 가짜는 그대로 먼저 풀린다.
    $script:binDirNoMp = Join-Path ([IO.Path]::GetTempPath()) ('kt-bin-nomp-' + [guid]::NewGuid().ToString('N'))
    $script:fixtures += $script:binDirNoMp
    Write-Text (Join-Path $script:binDirNoMp '.kt-fake-bin') "kernel-trial harness fake bin (no modprobe)`n"
    foreach ($name in $fakeFiles.Keys) {
        if ($name -eq 'modprobe') { continue }
        $fp = Join-Path $script:binDirNoMp $name
        Write-Text $fp ($fakeFiles[$name] -replace "`r`n", "`n")
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($fp, [IO.UnixFileMode]'UserRead, UserWrite, UserExecute') }
    }
    $sep = [IO.Path]::PathSeparator
    $script:childPath = if ($IsWindows) { $script:binDir + $sep + $script:bashDir + $sep + $env:PATH } else { $script:binDir + $sep + $env:PATH }
    $script:childPathNoMp = if ($IsWindows) { $script:binDirNoMp + $sep + $script:bashDir + $sep + $env:PATH } else { $script:binDirNoMp + $sep + $env:PATH }

    # ---------- setup: PATH 우선순위 탐침(실패하면 아무 케이스도 돌리지 않는다) ----------
    $probeNames = @('uname', 'id', 'update-grub', 'grub-editenv', 'lsmod', 'modinfo', 'modprobe', 'dmesg', 'apt-config', 'pgrep') + $tripwireNames
    $probe = 'for c in "$@"; do p=$(command -v "$c") || { echo "MISSING $c"; continue; }; if [ -f "${p%/*}/.kt-fake-bin" ]; then echo "FAKE $c"; else echo "REAL $c $p"; fi; done'
    $psi = [Diagnostics.ProcessStartInfo]::new($script:bash)
    foreach ($a in @('-c', $probe, 'probe') + $probeNames) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false
    $psi.Environment['PATH'] = $script:childPath
    $psi.Environment['MSYS_NO_PATHCONV'] = '1'; $psi.Environment['MSYS2_ARG_CONV_EXCL'] = '*'
    $pp = [Diagnostics.Process]::Start($psi)
    $po = $pp.StandardOutput.ReadToEnd(); $pe = $pp.StandardError.ReadToEnd(); $pp.WaitForExit()
    $plines = @($po -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })
    $precedenceOk = ($pp.ExitCode -eq 0 -and @($plines | Where-Object { $_.StartsWith('FAKE ') }).Count -eq $probeNames.Count)
    Assert "setup: every faked or tripwired command resolves into the fake bin first on the child PATH ($($probeNames.Count) names, bash $script:bash)" $precedenceOk "exit=$($pp.ExitCode) out=[$($plines -join '; ')] err=[$pe]"
    if (-not $precedenceOk) { $script:only = @('<none: PATH precedence probe failed>') }
    # 두 번째 PATH(M1-6a): modprobe는 어디에서도 풀리지 않고(MISSING), 나머지는 전부 가짜 bin에서 먼저 풀린다.
    $psi = [Diagnostics.ProcessStartInfo]::new($script:bash)
    foreach ($a in @('-c', $probe, 'probe') + $probeNames) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false
    $psi.Environment['PATH'] = $script:childPathNoMp
    $psi.Environment['MSYS_NO_PATHCONV'] = '1'; $psi.Environment['MSYS2_ARG_CONV_EXCL'] = '*'
    $pp = [Diagnostics.Process]::Start($psi)
    $po = $pp.StandardOutput.ReadToEnd(); $pe = $pp.StandardError.ReadToEnd(); $pp.WaitForExit()
    $plines = @($po -split "`n" | ForEach-Object { $_.TrimEnd("`r") } | Where-Object { $_ })
    $script:noMpOk = ($pp.ExitCode -eq 0 -and (Test-HasLine $plines 'MISSING modprobe') -and @($plines | Where-Object { $_.StartsWith('FAKE ') }).Count -eq ($probeNames.Count - 1))
    Assert "setup: on the second PATH (M1-6a) modprobe resolves nowhere and the other $($probeNames.Count - 1) names still resolve into the fake bin first" $script:noMpOk "exit=$($pp.ExitCode) out=[$($plines -join '; ')] err=[$pe]"

    # ---------- K1: status — 깨끗한 상태 ----------
    Test-Group 'K1' {
        $fx = New-Kt
        $r = Invoke-KT $fx @('status')
        Assert 'K1: status on a clean state (no pin, grub.cfg default 0, kernels 6.17 running + 7.0 newest) -> exit 0, "INFO next boot: 7.0.0-1012-oracle (default)", "INFO later boots: 7.0.0-1012-oracle", "OK pin: absent", RESULT OK, no write call' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO next boot: $K7 (default)") -and (Test-HasLine $r.lines "INFO later boots: $K7") -and (Test-HasLine $r.lines 'OK pin: absent') -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: OK status -- ')
        ) (Format-Result $r)
        $want = @(
            "INFO running: $K6",
            "INFO kernels: 2 installed (/boot/vmlinuz-*, sort -V): $K6 $K7",
            "INFO kernel ${K6}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 accounted=0 [running]",
            "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 accounted=0 [newest]",
            "INFO reboot-required: yes (pkgs: linux-image-$K7 linux-base)",
            'INFO grub-default-src: /etc/default/grub:6: GRUB_DEFAULT=0',
            'INFO grub-default-src: effective = /etc/default/grub:6 (read last by grub-mkconfig)',
            'INFO grub.cfg next_entry logic: present',
            'INFO grub.cfg default: "0" (else branch of the next_entry block)',
            "OK initrdless-boot fallback: off (no 'set partuuid=' in grub.cfg)",
            'INFO pin file: absent (/etc/default/grub.d/99-kernel-trial-pin.cfg)',
            'INFO grubenv: (no variables)',
            'INFO package activity: none',
            'INFO leftovers: none',
            'INFO auto-reboot: Unattended-Upgrade::Automatic-Reboot = "false"',
            'INFO apparmor denials: 2 apparmor="DENIED" lines in this boot''s dmesg',
            "INFO cmdline: BOOT_IMAGE=/vmlinuz-$K6 root=UUID=$UUID ro console=tty1 console=ttyS0"
        )
        $missing = @($want | Where-Object { -not (Test-HasLine $r.lines $_) })
        Assert 'K1b: status reports the running kernel, the sorted kernel list with per-kernel files / menu-entry ids / loaded modules missing, reboot-required + pkgs, every GRUB_DEFAULT source line and the effective one, grub.cfg next_entry logic and default, initrd-less boot fallback off (F2), pin file, grubenv, package activity none (F1), leftovers none (F3), auto-reboot, apparmor denials, /proc/cmdline' (
            $missing.Count -eq 0
        ) ("missing: [$($missing -join ' | ')] " + (Format-Result $r))
    }

    # ---------- K2 · K3: pin 정상 · 다시(멱등) ----------
    Test-Group 'K2,K3' {
        $fx = New-Kt
        $r = Invoke-KT $fx @('pin') -label 'K2'
        $pinText = Get-PinText $fx
        Assert 'K2: pin on a clean state -> exit 0, pin file = 1-2 ASCII comment lines + exactly GRUB_DEFAULT="<submenu id>><6.17 entry id>", grub.cfg default = that value, update-grub once, no grubenv write, "OK pin: present -> 6.17.0-1020-oracle", next boot 6.17 (default), RESULT OK' (
            $r.code -eq 0 -and (Test-PinContent $pinText (Get-PinValue $K6)) -and (Test-Same (Get-CfgDefault $fx) (Get-PinValue $K6)) -and $r.ug -eq 1 -and $r.set -eq 0 -and $r.unset -eq 0 -and
            (Test-HasLine $r.lines "OK verify: grub.cfg default is `"$(Get-PinValue $K6)`" -> $K6 (ids unique)") -and (Test-HasLine $r.lines "OK pin: present -> $K6") -and (Test-HasLine $r.lines "INFO next boot: $K6 (default)") -and (Test-LastPrefix $r 'RESULT: OK pin -- ')
        ) ("pin file=[$pinText] grub.cfg default=[$(Get-CfgDefault $fx)] " + (Format-Result $r))
        $guards = @("OK initrdless-boot fallback: off (no 'set partuuid=' in grub.cfg)", 'OK initrd fallback: grubenv initrdfail and prev_entry are empty', 'OK package activity: none', 'OK package activity: none right before update-grub', 'OK package activity: none right after update-grub')
        $missing = @($guards | Where-Object { -not (Test-HasLine $r.lines $_) })
        Assert 'K2x-guards: the normal pin passes the new guards in the open: F2 initrd-less boot fallback off, F9 initrdfail/prev_entry empty, F1 package activity none (guard) and none right before update-grub, L1 none right after update-grub (pgrep asked 18 times = 6 names x 3)' (
            $missing.Count -eq 0 -and $r.pg -eq 18
        ) ("missing: [$($missing -join ' | ')] " + (Format-Result $r))
        $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('pin') -label 'K3'
        Assert 'K3: pin again (idempotent) -> exit 0, "OK pin file: already pinned -> 6.17.0-1020-oracle ...", update-grub not called, pin file and grub.cfg byte-identical, RESULT OK' (
            $r.code -eq 0 -and (Test-HasLinePrefix $r.lines "OK pin file: already pinned -> $K6") -and $r.writes -eq 0 -and $null -ne $pinHash -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and (Test-LastPrefix $r 'RESULT: OK pin -- ')
        ) (Format-Result $r)
    }

    # ---------- K4: pin 가드 — 하나라도 어긋나면 아무것도 쓰지 않는다 ----------
    Test-Group 'K4' {
        $cases = @(
            @{ n = 'K4a: the running kernel''s -advanced- entry id is absent from grub.cfg'; p = @{ DropEntry = @($K6) }; line = "FAIL menu ids: entry gnulinux-$K6-advanced-* found 0 times in /boot/grub/grub.cfg (want exactly 1)" },
            @{ n = 'K4b: the running kernel''s entry id appears twice'; p = @{ DupEntry = @($K6) }; line = "FAIL menu ids: entry gnulinux-$K6-advanced-* found 2 times in /boot/grub/grub.cfg (want exactly 1)" },
            @{ n = 'K4c: no submenu id (entries at the top level)'; p = @{ NoSubmenu = $true }; line = 'FAIL menu ids: submenu gnulinux-advanced-* found 0 times in /boot/grub/grub.cfg (want exactly 1)' },
            @{ n = 'K4d: grub.cfg has no next_entry logic'; p = @{ NoNextEntryLogic = $true }; line = 'FAIL next_entry logic: found 0 blocks in /boot/grub/grub.cfg (want exactly 1)' },
            @{ n = 'K4e: the running kernel''s initrd is absent'; p = @{ NoInitrd = @($K6) }; line = "FAIL kernel files: ${K6}: missing /boot/initrd.img-$K6" },
            @{ n = 'K4f: not root (id -u = 1000)'; p = @{ Uid = '1000' }; line = 'FAIL root: uid 1000 -- run with sudo' },
            @{ n = 'K4x-vmlinuz: the running kernel''s vmlinuz is absent'; p = @{ NoVmlinuz = @($K6) }; line = "FAIL kernel files: ${K6}: missing /boot/vmlinuz-$K6" },
            @{ n = 'K4x-modules: the running kernel''s /lib/modules directory is absent'; p = @{ NoModulesDir = @($K6) }; line = "FAIL kernel files: ${K6}: missing /lib/modules/$K6/" },
            @{ n = 'K4x-prestate: no pin file but grub.cfg default is already an id (inconsistent pre-state; F3 manual fix in the FAIL line)'; p = @{ Default = (Get-PinValue $K6) }; line = "FAIL pin file: absent but grub.cfg default is `"$(Get-PinValue $K6)`" (want `"0`") -- $FIX" }
        )
        foreach ($c in $cases) {
            $p = $c.p
            $fx = New-Kt @p
            $cfgHash = Get-CfgHash $fx
            $r = Invoke-KT $fx @('pin') -label ($c.n -split ':')[0]
            Assert "$($c.n) -> exit 1, `"$($c.line)`", no pin file, grub.cfg unchanged, update-grub not called, RESULT FAIL" (
                $r.code -eq 1 -and (Test-HasLine $r.lines $c.line) -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL pin -- ')
            ) (Format-Result $r)
        }
        $fx = New-Kt -Pin (Get-PinValue $K6)
        $pinHash = Get-PinHash $fx
        $r = Invoke-KT $fx @('pin') -label 'K4x-transient'
        Assert 'K4x-transient: pin file already holds this value but grub.cfg still says 0 (update-grub did not finish) -> exit 1, "FAIL pin file: present with this value but grub.cfg default is "0" (update-grub did not finish) -- <F3 manual fix>", pin file unchanged, update-grub not called' (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL pin file: present with this value but grub.cfg default is `"0`" (update-grub did not finish) -- $FIX") -and (Test-Same (Get-PinHash $fx) $pinHash) -and $r.writes -eq 0
        ) (Format-Result $r)
    }

    # ---------- K5: pin — update-grub 실패 · 검증 실패 → 되돌림 ----------
    Test-Group 'K5' {
        $v = Get-PinValue $K6
        $cases = @(
            @{ n = 'K5a: update-grub exits 1 (files untouched), the rollback run succeeds'; m = 'fail ok'; line = 'FAIL update-grub: exit 1'; prefix = $null },
            @{ n = 'K5b: update-grub exits 0 but does not change the default'; m = 'noop ok'; line = "FAIL verify: grub.cfg default is `"0`", want `"$v`" -- $FIX"; prefix = $null },
            @{ n = 'K5c: update-grub writes a wrong default (1)'; m = 'wrong ok'; line = "FAIL verify: grub.cfg default is `"1`", want `"$v`" -- $FIX"; prefix = $null },
            @{ n = 'K5x-dup: update-grub writes the right default but every menu id twice'; m = 'dup-ids ok'; line = $null; prefix = "FAIL verify: grub.cfg default does not resolve: id $SUB found 2 times" }
        )
        foreach ($c in $cases) {
            $fx = New-Kt -UpdateGrubMode $c.m
            $r = Invoke-KT $fx @('pin') -label ($c.n -split ':')[0]
            $hit = if ($c.line) { Test-HasLine $r.lines $c.line } else { Test-HasLinePrefix $r.lines $c.prefix }
            Assert "$($c.n) -> exit 1, the failure line, then `"OK rollback: pin file removed; grub.cfg default is `"0`" again`", no pin file, grub.cfg default 0, update-grub twice, final `"OK pin: absent`"" (
                $r.code -eq 1 -and $hit -and (Test-HasLine $r.lines 'OK rollback: pin file removed; grub.cfg default is "0" again') -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) '0') -and $r.ug -eq 2 -and (Test-HasLine $r.lines 'OK pin: absent') -and (Test-LastPrefix $r 'RESULT: FAIL pin -- ')
            ) (Format-Result $r)
        }
    }

    # ---------- K6: pin — 되돌리기의 update-grub도 실패 → 지금 상태를 FAIL 줄로 ----------
    Test-Group 'K6' {
        foreach ($c in @(@{ n = 'K6a'; m = 'fail fail'; d = '0' }, @{ n = 'K6b'; m = 'wrong fail'; d = '1' })) {
            $fx = New-Kt -UpdateGrubMode $c.m
            $r = Invoke-KT $fx @('pin') -label $c.n
            $line = "FAIL rollback: update-grub exit 1; state now: pin file absent, grub.cfg default `"$($c.d)`""
            Assert "$($c.n): pin with update-grub modes '$($c.m)' (the rollback's update-grub fails as well) -> exit 1 and the FAIL line states the current state: `"$line`"; update-grub twice, RESULT FAIL" (
                $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) $c.d) -and $r.ug -eq 2 -and (Test-LastPrefix $r 'RESULT: FAIL pin -- ')
            ) (Format-Result $r)
        }
    }

    # ---------- K7: pin — 다른 커널로 이미 고정 ----------
    Test-Group 'K7' {
        $fx = New-Kt -Pin (Get-PinValue $K7) -Default (Get-PinValue $K7)
        $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('pin')
        Assert 'K7: pin while another kernel (7.0) is pinned -> exit 1, "FAIL pin file: present with another value "<7.0 value>" ...", pin file and grub.cfg unchanged, update-grub not called' (
            $r.code -eq 1 -and (Test-HasLinePrefix $r.lines "FAIL pin file: present with another value `"$(Get-PinValue $K7)`"") -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.writes -eq 0
        ) (Format-Result $r)
    }

    # ---------- K8: trial 정상 ----------
    Test-Group 'K8' {
        $fx = New-Pinned
        $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('trial', $K7)
        $vars = Get-EnvVars $fx
        Assert 'K8: trial 7.0.0-1012-oracle with 6.17 pinned -> exit 0, grubenv holds exactly one variable next_entry=<submenu id>><7.0 entry id>, grub-editenv set once, pin file and grub.cfg unchanged, next boot 7.0 (one-shot) / later boots 6.17 / pin present -> 6.17, guide lines, RESULT OK' (
            $r.code -eq 0 -and $vars.Count -eq 1 -and (Test-Same $vars[0] "next_entry=$(Get-PinValue $K7)") -and $r.set -eq 1 -and $r.unset -eq 0 -and $r.ug -eq 0 -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and
            (Test-HasLine $r.lines "OK verify: next_entry is exactly `"$(Get-PinValue $K7)`"") -and (Test-HasLine $r.lines "INFO next boot: $K7 (one-shot next_entry)") -and (Test-HasLine $r.lines "INFO later boots: $K6") -and (Test-HasLine $r.lines "OK pin: present -> $K6") -and
            (Get-LinesWithPrefix $r.lines 'INFO guide: ').Count -ge 2 -and (Test-LastPrefix $r 'RESULT: OK trial -- ')
        ) ("grubenv=[$($vars -join ' ; ')] " + (Format-Result $r))
    }

    # ---------- K9: trial — 복구 경로(고정)가 준비되지 않음 ----------
    Test-Group 'K9' {
        $cases = @(
            @{ n = 'K9a: no pin'; mk = { New-Kt }; prefix = 'FAIL pin file: absent -- run pin first' },
            @{ n = 'K9b: pin file present but grub.cfg still has the old default (transient; F3 manual fix in the FAIL line)'; mk = { New-Kt -Pin (Get-PinValue $K6) }; prefix = "FAIL pin consistent: pin file `"$(Get-PinValue $K6)`" differs from grub.cfg default `"0`" (update-grub not run?) -- $FIX" },
            @{ n = 'K9c: the pinned kernel (6.8.0) is not the running kernel (6.17.0)'; mk = { New-Kt -Kernels @($K7, $K6, $K68) -Pin (Get-PinValue $K68) -Default (Get-PinValue $K68) }; prefix = "FAIL pinned kernel: $K68 is not the running kernel $K6" }
        )
        foreach ($c in $cases) {
            $fx = & $c.mk
            $r = Invoke-KT $fx @('trial', $K7) -label ($c.n -split ':')[0]
            Assert "$($c.n) -> exit 1, `"$($c.prefix)...`", grub-editenv set/unset not called, grubenv has no next_entry" (
                $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $c.prefix) -and $r.set -eq 0 -and $r.unset -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-LastPrefix $r 'RESULT: FAIL trial -- ')
            ) (Format-Result $r)
        }
    }

    # ---------- K10: trial — 대상 커널 가드 ----------
    Test-Group 'K10' {
        $cases = @(
            @{ n = 'K10a: target = the running kernel'; p = @{}; a = @('trial', $K6); line = "FAIL target: $K6 is the running kernel -- nothing to try" },
            @{ n = 'K10b: malformed version 7.0.0'; p = @{}; a = @('trial', '7.0.0'); line = "FAIL kver: '7.0.0' is not a kernel version (want e.g. 7.0.0-1012-oracle)" },
            @{ n = 'K10b2: path-like version'; p = @{}; a = @('trial', "$K7/../x"); line = "FAIL kver: '$K7/../x' is not a kernel version (want e.g. 7.0.0-1012-oracle)" },
            @{ n = 'K10c: the target''s vmlinuz is absent'; p = @{ NoVmlinuz = @($K7) }; a = @('trial', $K7); line = "FAIL kernel files: ${K7}: missing /boot/vmlinuz-$K7" },
            @{ n = 'K10d: the target''s initrd is absent'; p = @{ NoInitrd = @($K7) }; a = @('trial', $K7); line = "FAIL kernel files: ${K7}: missing /boot/initrd.img-$K7" },
            @{ n = 'K10e: the target''s /lib/modules directory is absent'; p = @{ NoModulesDir = @($K7) }; a = @('trial', $K7); line = "FAIL kernel files: ${K7}: missing /lib/modules/$K7/" },
            @{ n = 'K10f: the target''s entry id appears twice'; p = @{ DupEntry = @($K7) }; a = @('trial', $K7); line = "FAIL menu ids: entry gnulinux-$K7-advanced-* found 2 times in /boot/grub/grub.cfg (want exactly 1)" }
        )
        foreach ($c in $cases) {
            $fx = New-Pinned $c.p
            $r = Invoke-KT $fx $c.a -label ($c.n -split ':')[0]
            Assert "$($c.n) -> exit 1, `"$($c.line)`", grub-editenv set/unset not called, grubenv has no next_entry" (
                $r.code -eq 1 -and (Test-HasLine $r.lines $c.line) -and $r.set -eq 0 -and $r.unset -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-LastPrefix $r 'RESULT: FAIL trial -- ')
            ) (Format-Result $r)
        }
    }

    # ---------- K11: trial — 적재된 모듈이 대상 커널에 없다 ----------
    Test-Group 'K11' {
        # 픽스처는 원래대로(wireguard 사용 수 0 · 사용자 없음 · 별칭 없음) — F-A에서 사용자 없는 모듈은 별칭이 풀려야 대체됨이라 '없음'이다.
        #   FAIL 줄의 안내는 F-B의 정확한 수용 옵션을 가리킨다.
        $lack = @{ Lacking = @{ $K7 = @('wireguard') } }
        $fx = New-Pinned $lack
        $r = Invoke-KT $fx @('trial', $K7) -label 'K11a'
        Assert 'K11a: one loaded module (wireguard) is not available for 7.0 -> exit 1, "FAIL modules: 1 of 4 loaded modules missing for 7.0.0-1012-oracle: wireguard (rerun with --accept-missing-modules wireguard to accept exactly these)", set not called, no next_entry' (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL modules: 1 of 4 loaded modules missing for ${K7}: wireguard (rerun with --accept-missing-modules wireguard to accept exactly these)") -and $r.set -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        $r = Invoke-KT $fx @('trial', $K7, '--ignore-missing-modules') -label 'K11b'
        Assert 'K11b: the same with --ignore-missing-modules -> exit 0, "INFO modules: 1 of 4 loaded modules missing for 7.0.0-1012-oracle: wireguard (accepted: --ignore-missing-modules)" and the F-B hint "INFO modules: --ignore-missing-modules accepts every missing module; prefer --accept-missing-modules <names>", next_entry set to the 7.0 value' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO modules: 1 of 4 loaded modules missing for ${K7}: wireguard (accepted: --ignore-missing-modules)") -and (Test-HasLine $r.lines $IGNORE_HINT) -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7)) -and $r.set -eq 1
        ) (Format-Result $r)
        $fx = New-Pinned $lack
        $r = Invoke-KT $fx @('trial', '--ignore-missing-modules', $K7) -label 'K11x-order'
        Assert 'K11x-order: the option may come before the version -> exit 0, next_entry set' ($r.code -eq 0 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7))) (Format-Result $r)
        $fx = New-Pinned $lack
        $r = Invoke-KT $fx @('status') -label 'K11x-status'
        Assert 'K11x-status: status names the module missing for 7.0: "... missing-loaded-modules=1 (wireguard) accounted=0 [newest]"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=1 (wireguard) accounted=0 [newest]")
        ) (Format-Result $r)
    }

    # ---------- K12: trial — next_entry가 이미 있다 ----------
    Test-Group 'K12' {
        $fx = New-Pinned @{ NextEntry = (Get-PinValue $K7) }
        $r = Invoke-KT $fx @('trial', $K7) -label 'K12a'
        Assert 'K12a: next_entry already holds the same value -> exit 0, "OK next_entry: already set to "<7.0 value>" (nothing written)", no write, next_entry unchanged' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "OK next_entry: already set to `"$(Get-PinValue $K7)`" (nothing written)") -and $r.writes -eq 0 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7)) -and (Test-LastPrefix $r 'RESULT: OK trial -- ')
        ) (Format-Result $r)
        $fx = New-Pinned @{ NextEntry = (Get-PinValue $K6) }
        $r = Invoke-KT $fx @('trial', $K7) -label 'K12b'
        Assert 'K12b: next_entry holds another value -> exit 1, "FAIL next_entry: already set to "<6.17 value>" -- run cancel-trial first", no write, next_entry unchanged' (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL next_entry: already set to `"$(Get-PinValue $K6)`" -- run cancel-trial first") -and $r.writes -eq 0 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K6))
        ) (Format-Result $r)
    }

    # ---------- K13: trial — 쓰기를 읽어 보니 다르다 → unset ----------
    Test-Group 'K13' {
        $v = Get-PinValue $K7
        $fx = New-Pinned @{ EditenvMode = 'set-noop' }
        $r = Invoke-KT $fx @('trial', $K7) -label 'K13a'
        Assert 'K13a: grub-editenv set exits 0 but writes nothing -> exit 1, "FAIL verify: next_entry is "", want "<7.0 value>"", then "OK cleanup: next_entry is empty", no next_entry' (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL verify: next_entry is `"`", want `"$v`"") -and (Test-HasLine $r.lines 'OK cleanup: next_entry is empty') -and $null -eq (Get-NextEntry $fx) -and $r.set -eq 1 -and $r.unset -eq 1
        ) (Format-Result $r)
        $fx = New-Pinned @{ EditenvMode = 'set-wrong' }
        $r = Invoke-KT $fx @('trial', $K7) -label 'K13b'
        Assert 'K13b: grub-editenv set writes another value -> exit 1, "FAIL verify: next_entry is "<value>-wrong", want "<value>"", then unset: "OK cleanup: next_entry is empty", no next_entry' (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL verify: next_entry is `"$v-wrong`", want `"$v`"") -and (Test-HasLine $r.lines 'OK cleanup: next_entry is empty') -and $null -eq (Get-NextEntry $fx) -and $r.set -eq 1 -and $r.unset -eq 1
        ) (Format-Result $r)
    }

    # ---------- K14: cancel-trial ----------
    Test-Group 'K14' {
        $fx = New-Pinned @{ NextEntry = (Get-PinValue $K7) }
        $r = Invoke-KT $fx @('cancel-trial') -label 'K14a'
        Assert 'K14a: cancel-trial with next_entry set -> exit 0, "OK verify: next_entry is empty", grubenv without next_entry, unset once, next boot back to the pinned 6.17 (default), RESULT OK' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'OK verify: next_entry is empty') -and $null -eq (Get-NextEntry $fx) -and $r.unset -eq 1 -and $r.set -eq 0 -and $r.ug -eq 0 -and (Test-HasLine $r.lines "INFO next boot: $K6 (default)") -and (Test-LastPrefix $r 'RESULT: OK cancel-trial -- ')
        ) (Format-Result $r)
        $fx = New-Pinned
        $r = Invoke-KT $fx @('cancel-trial') -label 'K14b'
        Assert 'K14b: cancel-trial with next_entry empty -> exit 0, "OK next_entry: empty -- nothing to cancel", no write, RESULT OK' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'OK next_entry: empty -- nothing to cancel') -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-LastPrefix $r 'RESULT: OK cancel-trial -- ')
        ) (Format-Result $r)
    }

    # ---------- K15: unpin 정상 ----------
    Test-Group 'K15' {
        $fx = New-Pinned @{ Running = $K7 }
        $r = Invoke-KT $fx @('unpin')
        Assert 'K15: unpin while running the newest kernel (7.0) with 6.17 pinned -> exit 0, no pin file, grub.cfg default 0, update-grub once, "OK verify: grub.cfg default is "0" -> 7.0.0-1012-oracle", "OK cleanup: removed the set-aside pin file", "OK pin: absent", next boot 7.0 (default)' (
            $r.code -eq 0 -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) '0') -and $r.ug -eq 1 -and $r.set -eq 0 -and $r.unset -eq 0 -and
            (Test-HasLine $r.lines "OK verify: grub.cfg default is `"0`" -> $K7") -and (Test-HasLine $r.lines 'OK cleanup: removed the set-aside pin file') -and (Test-HasLine $r.lines 'OK pin: absent') -and (Test-HasLine $r.lines "INFO next boot: $K7 (default)") -and (Test-LastPrefix $r 'RESULT: OK unpin -- ')
        ) (Format-Result $r)
    }

    # ---------- K16: unpin 가드 ----------
    Test-Group 'K16' {
        $cases = @(
            @{ n = 'K16a: the running kernel (6.17) is not the newest installed (7.0)'; p = @{}; prefix = "FAIL newest: running kernel $K6 is not the newest installed kernel $K7" },
            @{ n = 'K16b: next_entry is still set'; p = @{ Running = $K7; NextEntry = (Get-PinValue $K7) }; prefix = "FAIL grubenv: next_entry is set (`"$(Get-PinValue $K7)`") -- run cancel-trial first" },
            @{ n = 'K16c: no pin'; p = @{ Running = $K7; Pin = ''; Default = '0' }; prefix = 'FAIL pin file: absent -- nothing to unpin' }
        )
        foreach ($c in $cases) {
            $fx = New-Pinned $c.p
            $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx
            $r = Invoke-KT $fx @('unpin') -label ($c.n -split ':')[0]
            Assert "$($c.n) -> exit 1, `"$($c.prefix)...`", pin file and grub.cfg unchanged, update-grub not called" (
                $r.code -eq 1 -and (Test-HasLinePrefix $r.lines $c.prefix) -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL unpin -- ')
            ) (Format-Result $r)
        }
    }

    # ---------- K17: unpin — update-grub 실패 → 고정 파일 복원 ----------
    Test-Group 'K17' {
        $v = Get-PinValue $K6
        $cases = @(
            @{ n = 'K17a: update-grub fails on every call'; m = 'fail'; want = @('FAIL update-grub: exit 1', "FAIL restore: update-grub exit 1; state now: pin file present, grub.cfg default `"$v`"") },
            @{ n = 'K17b: update-grub fails, the restore run succeeds'; m = 'fail ok'; want = @('FAIL update-grub: exit 1', "OK restore: pin file restored; grub.cfg default is the pinned value `"$v`"") },
            @{ n = 'K17x-wrong: update-grub writes a wrong default (1), the restore run succeeds'; m = 'wrong ok'; want = @("FAIL verify: grub.cfg default is `"1`", want `"0`" -- $FIX", "OK restore: pin file restored; grub.cfg default is the pinned value `"$v`"") }
        )
        foreach ($c in $cases) {
            $fx = New-Pinned @{ Running = $K7; UpdateGrubMode = $c.m }
            $pinHash = Get-PinHash $fx
            $r = Invoke-KT $fx @('unpin') -label ($c.n -split ':')[0]
            $missing = @($c.want | Where-Object { -not (Test-HasLine $r.lines $_) })
            Assert "$($c.n) -> exit 1, [$($c.want -join ' / ')], pin file restored byte for byte, grub.cfg default = the pinned value, update-grub twice, final `"OK pin: present -> 6.17.0-1020-oracle`"" (
                $r.code -eq 1 -and $missing.Count -eq 0 -and $null -ne $pinHash -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgDefault $fx) $v) -and $r.ug -eq 2 -and (Test-HasLine $r.lines "OK pin: present -> $K6") -and (Test-LastPrefix $r 'RESULT: FAIL unpin -- ')
            ) ("missing: [$($missing -join ' | ')] " + (Format-Result $r))
        }
    }

    # ---------- K18: status — INCONSISTENT(이유가 서로 다르다) ----------
    Test-Group 'K18' {
        $v = Get-PinValue $K6
        $bogus = "$SUB>gnulinux-9.9.9-1-oracle-advanced-$UUID"
        $cases = @(
            @{ n = 'K18a: pin file present but grub.cfg still default 0'; p = @{ Pin = $v }; prefix = "FAIL pin: INCONSISTENT (pin file says `"$v`" but grub.cfg default is `"0`"" },
            @{ n = 'K18b: no pin file but grub.cfg default is an id'; p = @{ Default = $v }; prefix = "FAIL pin: INCONSISTENT (no pin file but grub.cfg default is `"$v`"" },
            @{ n = 'K18c: next_entry names an id that is not in the menu'; p = @{ NextEntry = $bogus }; prefix = "FAIL pin: INCONSISTENT (next_entry `"$bogus`" does not resolve" }
        )
        $reasons = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $seen = @()
        foreach ($c in $cases) {
            $p = $c.p
            $fx = New-Kt @p
            $r = Invoke-KT $fx @('status') -label ($c.n -split ':')[0]
            $pl = Get-LinesWithPrefix $r.lines 'FAIL pin: INCONSISTENT ('
            foreach ($l in $pl) { [void]$reasons.Add($l); $seen += $l }
            Assert "$($c.n) -> status exit 1, exactly one `"$($c.prefix)...`" line, no write, RESULT FAIL" (
                $r.code -eq 1 -and $pl.Count -eq 1 -and (Test-HasLinePrefix $r.lines $c.prefix) -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL status -- ')
            ) (Format-Result $r)
        }
        Assert 'K18d: the three INCONSISTENT reasons differ from one another' ($seen.Count -eq 3 -and $reasons.Count -eq 3) "lines: [$($seen -join ' | ')]"
    }

    # ---------- K19: 사용법 오류 → exit 2, 아무것도 읽거나 쓰지 않는다 ----------
    Test-Group 'K19' {
        $fx = New-Kt
        $cases = @(
            @{ a = @(); line = 'FAIL usage: missing subcommand' },
            @{ a = @('bogus'); line = "FAIL usage: unknown subcommand 'bogus'" },
            @{ a = @('status', 'extra'); line = 'FAIL usage: status takes no arguments' },
            @{ a = @('pin', $K6); line = 'FAIL usage: pin takes no arguments' },
            @{ a = @('cancel-trial', 'now'); line = 'FAIL usage: cancel-trial takes no arguments' },
            @{ a = @('unpin', '--force'); line = 'FAIL usage: unpin takes no arguments' },
            @{ a = @('trial'); line = 'FAIL usage: trial takes exactly one kernel version' },
            @{ a = @('trial', $K7, $K6); line = 'FAIL usage: trial takes exactly one kernel version' },
            @{ a = @('trial', $K7, '--force'); line = "FAIL usage: unknown option '--force'" },
            @{ a = @('trial', $K7, '--ignore-missing-modules', '--ignore-missing-modules'); line = 'FAIL usage: --ignore-missing-modules given twice' }
        )
        foreach ($c in $cases) {
            $r = Invoke-KT $fx $c.a -label "K19[$($c.a -join ' ')]"
            $other = @($r.lines | Where-Object { -not ($_.StartsWith('INFO note: ') -or $_.StartsWith('FAIL usage: ') -or $_.StartsWith('INFO usage: ') -or $_.StartsWith('RESULT: FAIL usage -- ')) })
            Assert "K19: args [$($c.a -join ' ')] -> exit 2, `"$($c.line)`", only usage lines, RESULT FAIL usage, no fake command called at all" (
                $r.code -eq 2 -and (Test-HasLine $r.lines $c.line) -and $other.Count -eq 0 -and $r.calls.Count -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL usage -- ')
            ) (Format-Result $r)
        }
    }

    # ---------- K20: 전 과정 — pin → trial → (가짜 부팅) → status → unpin ----------
    Test-Group 'K20' {
        $fx = New-Kt
        $r = Invoke-KT $fx @('pin') -label 'K20-1'
        Assert 'K20-1: pin -> exit 0, grub.cfg default = the 6.17 value, "OK pin: present -> 6.17.0-1020-oracle"' (
            $r.code -eq 0 -and (Test-Same (Get-CfgDefault $fx) (Get-PinValue $K6)) -and (Test-HasLine $r.lines "OK pin: present -> $K6")
        ) (Format-Result $r)
        $r = Invoke-KT $fx @('trial', $K7) -label 'K20-2'
        Assert 'K20-2: trial 7.0 -> exit 0, next_entry = the 7.0 value, next boot 7.0 (one-shot), later boots 6.17' (
            $r.code -eq 0 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7)) -and (Test-HasLine $r.lines "INFO next boot: $K7 (one-shot next_entry)") -and (Test-HasLine $r.lines "INFO later boots: $K6")
        ) (Format-Result $r)
        $r = Invoke-KT $fx @('status') -label 'K20-3'
        Assert 'K20-3: status before the reboot -> exit 0, next boot 7.0 (one-shot next_entry), later boots 6.17, pin present -> 6.17' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO next boot: $K7 (one-shot next_entry)") -and (Test-HasLine $r.lines "INFO later boots: $K6") -and (Test-HasLine $r.lines "OK pin: present -> $K6") -and $r.writes -eq 0
        ) (Format-Result $r)
        # 가짜 "부팅": 실제 GRUB처럼 'set next_entry=' + save_env next_entry — 변수를 없애지 않고 빈 값(next_entry=)으로 남긴다(F10).
        #   그 뒤 7.0으로 올라온다.
        Set-Grubenv (Join-Path $fx.Root 'boot/grub/grubenv') @('next_entry=')
        Write-Text (Join-Path $fx.State 'uname-r') "$K7`n"
        Write-Text (Join-Path $fx.Root 'proc/cmdline') "BOOT_IMAGE=/vmlinuz-$K7 root=UUID=$UUID ro console=tty1 console=ttyS0`n"
        $r = Invoke-KT $fx @('status') -label 'K20-4'
        Assert 'K20-4: status after the one-shot boot (running 7.0, grubenv keeps "next_entry=" with an empty value, as real GRUB leaves it) -> exit 0, "INFO grubenv: next_entry=", the empty value reads as no one-shot boot: next boot = the pinned 6.17 (default), later boots 6.17, pin present -> 6.17 (pinned kernel != running kernel is normal here)' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO running: $K7") -and (Test-HasLine $r.lines 'INFO grubenv: next_entry=') -and (Test-HasLine $r.lines "INFO next boot: $K6 (default)") -and (Test-HasLine $r.lines "INFO later boots: $K6") -and (Test-HasLine $r.lines "OK pin: present -> $K6") -and $r.writes -eq 0
        ) (Format-Result $r)
        $r = Invoke-KT $fx @('unpin') -label 'K20-5'
        Assert 'K20-5: unpin (grubenv "next_entry=" empty counts as none) -> exit 0, "OK grubenv: next_entry empty", no pin file, grub.cfg default 0, next boot 7.0 (default), "OK pin: absent"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'OK grubenv: next_entry empty') -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) '0') -and (Test-HasLine $r.lines "INFO next boot: $K7 (default)") -and (Test-HasLine $r.lines 'OK pin: absent')
        ) (Format-Result $r)
        $r = Invoke-KT $fx @('status') -label 'K20-6'
        Assert 'K20-6: final status -> exit 0, next boot 7.0 (default), later boots 7.0, pin absent, grubenv still lists the empty "next_entry=" (unpin does not touch grubenv)' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO next boot: $K7 (default)") -and (Test-HasLine $r.lines "INFO later boots: $K7") -and (Test-HasLine $r.lines 'OK pin: absent') -and (Test-HasLine $r.lines 'INFO grubenv: next_entry=') -and (Test-Same (Get-NextEntry $fx) '')
        ) (Format-Result $r)
    }

    # ---------- F1: 패키지 작업 중이면 쓰지 않는다(grub-mkconfig에는 잠금이 없다 — 겹치면 메뉴 항목 0개인 grub.cfg) ----------
    Test-Group 'F1' {
        $refuse = " -- refusing to write; run status, wait until it shows 'package activity: none', then retry"
        $ignored = 'INFO package activity ignored: unattended-upgr(812) -- the idle unattended-upgrade-shutdown --wait-for-signal helper, not package work'
        $fx = New-Kt
        $r = Invoke-KT $fx @('status') -label 'F1a'
        $pgCalls = @($r.calls | Where-Object { $_.StartsWith('pgrep ', [StringComparison]::Ordinal) })
        Assert 'F1a: status with no package process -> exit 0, "INFO package activity: none", pgrep asked exactly once per name in the order dpkg, apt, apt-get, unattended-upgr, grub-mkconfig, update-grub (pgrep -a -x NAME), no write' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'INFO package activity: none') -and $r.writes -eq 0 -and
            (Test-Same ($pgCalls -join ';') 'pgrep -a -x dpkg;pgrep -a -x apt;pgrep -a -x apt-get;pgrep -a -x unattended-upgr;pgrep -a -x grub-mkconfig;pgrep -a -x update-grub')
        ) (Format-Result $r)
        $fx = New-Kt -PgrepPlan @('dpkg * 4242 /usr/bin/dpkg --status-fd 23 --configure linux-image-7.0.0-1012-oracle', 'grub-mkconfig * 5150 /bin/sh /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg') -Leftovers @('boot/grub/grub.cfg.new')
        $r = Invoke-KT $fx @('status') -label 'F1b'
        Assert 'F1b: status while dpkg(4242) and grub-mkconfig(5150) run and /boot/grub/grub.cfg.new exists -> exit 0 (INFO only), "INFO package activity: dpkg(4242) grub-mkconfig(5150) /boot/grub/grub.cfg.new -- pin/unpin/trial will refuse", no write' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'INFO package activity: dpkg(4242) grub-mkconfig(5150) /boot/grub/grub.cfg.new -- pin/unpin/trial will refuse') -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-Kt -PgrepPlan @("unattended-upgr * 812 $UU_HELPER")
        $r = Invoke-KT $fx @('status') -label 'F1c'
        Assert "F1c (x): status with only the idle unattended-upgrade-shutdown --wait-for-signal helper (process name unattended-upgr, always running on Ubuntu 24.04) -> exit 0, `"INFO package activity: none`" and `"$ignored`"" (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'INFO package activity: none') -and (Test-HasLine $r.lines $ignored)
        ) (Format-Result $r)
        $fx = New-Kt -PgrepPlan @("unattended-upgr * 812 $UU_HELPER")
        $r = Invoke-KT $fx @('pin') -label 'F1d'
        Assert 'F1d (x): pin with only the idle helper running -> exit 0 (the helper is not package work), the ignored line, "OK package activity: none" and "OK package activity: none right before update-grub", pin file written, update-grub once' (
            $r.code -eq 0 -and (Test-HasLine $r.lines $ignored) -and (Test-HasLine $r.lines 'OK package activity: none') -and (Test-HasLine $r.lines 'OK package activity: none right before update-grub') -and
            (Test-PinContent (Get-PinText $fx) (Get-PinValue $K6)) -and $r.ug -eq 1
        ) (Format-Result $r)
        # 쓰기 전 가드: 찾으면 FAIL · 쓰기 0 · 파일 그대로
        $cases = @(
            @{ n = 'F1e: pin while unattended-upgrade itself runs (the idle helper next to it is ignored)'; c = 'pin'; mk = { New-Kt -PgrepPlan @("unattended-upgr * 812 $UU_HELPER", 'unattended-upgr * 913 /usr/bin/python3 /usr/bin/unattended-upgrade') }; line = "FAIL package activity: unattended-upgr(913)$refuse" },
            @{ n = 'F1f: pin while dpkg(4242) and apt-get(4240) run'; c = 'pin'; mk = { New-Kt -PgrepPlan @('apt-get * 4240 apt-get -y install linux-generic', 'dpkg * 4242 /usr/bin/dpkg --configure -a') }; line = "FAIL package activity: dpkg(4242) apt-get(4240)$refuse" },
            @{ n = 'F1g: pin while /boot/grub/grub.cfg.new exists and no package process runs (a stale leftover: the line says how to clear it)'; c = 'pin'; mk = { New-Kt -Leftovers @('boot/grub/grub.cfg.new') }; line = "FAIL package activity: /boot/grub/grub.cfg.new -- refusing to write; no package process runs, so it is a stale leftover of a failed or killed grub-mkconfig: run 'sudo update-grub' one time (it replaces the file), then run status and retry" },
            @{ n = 'F1g2: pin while grub-mkconfig runs and grub.cfg.new exists (it is being written: wait)'; c = 'pin'; mk = { New-Kt -Leftovers @('boot/grub/grub.cfg.new') -PgrepPlan @('grub-mkconfig * 5150 /bin/sh /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg') }; line = "FAIL package activity: grub-mkconfig(5150) /boot/grub/grub.cfg.new$refuse" },
            @{ n = 'F1h: pin when pgrep fails with exit 3 (cannot judge = busy)'; c = 'pin'; mk = { New-Kt -PgrepFail @('* * 3 pgrep: cannot allocate memory') }; line = "FAIL package activity: pgrep-failed(dpkg: exit 3: pgrep: cannot allocate memory)$refuse" },
            @{ n = 'F1i: pin when pgrep is missing (exit 127 = cannot judge = busy)'; c = 'pin'; mk = { New-Kt -PgrepFail @('* * 127 bash: pgrep: command not found') }; line = "FAIL package activity: pgrep-failed(dpkg: exit 127: bash: pgrep: command not found)$refuse" },
            @{ n = 'F1l: unpin while update-grub(6000) runs'; c = 'unpin'; mk = { New-Pinned @{ Running = $K7; PgrepPlan = @('update-grub * 6000 /bin/sh /usr/sbin/update-grub') } }; line = "FAIL package activity: update-grub(6000)$refuse" },
            @{ n = 'F1m: trial while apt(777) runs'; c = 'trial'; mk = { New-Pinned @{ PgrepPlan = @('apt * 777 /usr/bin/apt upgrade') } }; line = "FAIL package activity: apt(777)$refuse" }
        )
        foreach ($c in $cases) {
            $fx = & $c.mk
            $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx; $ne = Get-NextEntry $fx
            $a = if ($c.c -eq 'trial') { @('trial', $K7) } else { @($c.c) }
            $r = Invoke-KT $fx $a -label ($c.n -split ':')[0]
            Assert "$($c.n) -> exit 1, `"$($c.line)`", no write call (update-grub, grub-editenv set/unset 0), pin file, grub.cfg and next_entry unchanged, RESULT FAIL $($c.c) -- refused: package activity (...)" (
                $r.code -eq 1 -and (Test-HasLine $r.lines $c.line) -and $r.writes -eq 0 -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and (Test-Same (Get-NextEntry $fx) $ne) -and
                (Test-LastPrefix $r "RESULT: FAIL $($c.c) -- refused: package activity (")
            ) (Format-Result $r)
        }
        # update-grub 직전 재확인: 가드 때는 없고 직전에는 있다 → 쓴 것을 되돌리고 FAIL · update-grub 0회
        $fx = New-Kt -PgrepPlan @('grub-mkconfig 2+ 5150 /bin/sh /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg')
        $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('pin') -label 'F1j'
        Assert "F1j: pin, grub-mkconfig absent at the guard but present right before update-grub -> exit 1, `"OK package activity: none`", `"FAIL package activity: grub-mkconfig(5150) appeared right before update-grub -- update-grub not run`", `"OK undo: pin file removed again; grub.cfg untouched$AFTER_PKG`" (L2), no pin file, grub.cfg byte-identical, update-grub not called, RESULT FAIL pin -- refused: package activity right before update-grub ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'OK package activity: none') -and (Test-HasLine $r.lines 'FAIL package activity: grub-mkconfig(5150) appeared right before update-grub -- update-grub not run') -and
            (Test-HasLine $r.lines "OK undo: pin file removed again; grub.cfg untouched$AFTER_PKG") -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.ug -eq 0 -and
            (Test-LastPrefix $r 'RESULT: FAIL pin -- refused: package activity right before update-grub')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Running = $K7; PgrepPlan = @('dpkg 2+ 4242 /usr/bin/dpkg --configure -a') }
        $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('unpin') -label 'F1k'
        Assert "F1k: unpin, dpkg absent at the guard but present right before update-grub -> exit 1, `"FAIL package activity: dpkg(4242) appeared right before update-grub -- update-grub not run`", `"OK undo: pin file moved back; grub.cfg untouched$AFTER_PKG`" (L2), pin file and grub.cfg byte-identical, update-grub not called (no set-aside file left: S-runs)" (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'FAIL package activity: dpkg(4242) appeared right before update-grub -- update-grub not run') -and (Test-HasLine $r.lines "OK undo: pin file moved back; grub.cfg untouched$AFTER_PKG") -and
            $null -ne $pinHash -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.ug -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL unpin -- refused: package activity right before update-grub')
        ) (Format-Result $r)
        # cancel-trial은 막지 않는다(안전한 방향) — INFO로 알린다
        $fx = New-Pinned @{ NextEntry = (Get-PinValue $K7); PgrepPlan = @('dpkg * 4242 /usr/bin/dpkg --configure -a') }
        $r = Invoke-KT $fx @('cancel-trial') -label 'F1n'
        Assert 'F1n: cancel-trial while dpkg(4242) runs -> not blocked: exit 0, "INFO package activity: dpkg(4242) -- cancel-trial goes ahead (clearing next_entry is the safe direction)", next_entry cleared, unset once' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'INFO package activity: dpkg(4242) -- cancel-trial goes ahead (clearing next_entry is the safe direction)') -and $null -eq (Get-NextEntry $fx) -and $r.unset -eq 1 -and
            (Test-LastPrefix $r 'RESULT: OK cancel-trial -- ')
        ) (Format-Result $r)
        # 되돌리기 · 복원의 update-grub 직전에도 본다(지시서 밖: 겹쳐 돌리지 않고 수동 복구를 적는다)
        $fx = New-Kt -UpdateGrubMode 'fail ok' -PgrepPlan @('grub-mkconfig 3+ 5150 /bin/sh /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg')
        $r = Invoke-KT $fx @('pin') -label 'F1o'
        $line = "FAIL rollback: package activity grub-mkconfig(5150) -- update-grub not run again; state now: pin file absent, grub.cfg default `"0`" -- $FIX"
        Assert "F1o (x): pin, update-grub fails and grub-mkconfig shows up before the rollback's update-grub -> exit 1, `"FAIL update-grub: exit 1`", `"$line`", update-grub once (the rollback does not overlap it), no pin file, grub.cfg default 0" (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'FAIL update-grub: exit 1') -and (Test-HasLine $r.lines $line) -and $r.ug -eq 1 -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) '0')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Running = $K7; UpdateGrubMode = 'fail ok'; PgrepPlan = @('dpkg 3+ 4242 /usr/bin/dpkg --configure -a') }
        $pinHash = Get-PinHash $fx
        $r = Invoke-KT $fx @('unpin') -label 'F1p'
        $line = "FAIL restore: package activity dpkg(4242) -- update-grub not run again; state now: pin file present, grub.cfg default `"$(Get-PinValue $K6)`" -- $FIX"
        Assert "F1p (x): unpin, update-grub fails and dpkg shows up before the restore's update-grub -> exit 1, `"$line`", update-grub once, pin file restored byte for byte" (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'FAIL update-grub: exit 1') -and (Test-HasLine $r.lines $line) -and $r.ug -eq 1 -and $null -ne $pinHash -and (Test-Same (Get-PinHash $fx) $pinHash)
        ) (Format-Result $r)
        $fx = New-Kt -PgrepFail @('* * 3 pgrep: cannot allocate memory')
        $r = Invoke-KT $fx @('status') -label 'F1q'
        Assert 'F1q: status when pgrep fails (exit 3) -> exit 0 (INFO only), "INFO package activity: pgrep-failed(dpkg: exit 3: pgrep: cannot allocate memory) -- pin/unpin/trial will refuse"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'INFO package activity: pgrep-failed(dpkg: exit 3: pgrep: cannot allocate memory) -- pin/unpin/trial will refuse')
        ) (Format-Result $r)
        $fx = New-Kt -Leftovers @('boot/grub/grub.cfg.new')
        $r = Invoke-KT $fx @('status') -label 'F1r'
        $hint = "INFO package activity hint: no package process runs, so /boot/grub/grub.cfg.new is a stale leftover of a failed or killed grub-mkconfig -- one successful 'sudo update-grub' replaces it"
        Assert "F1r (x): status with a lone /boot/grub/grub.cfg.new -> exit 0, `"INFO package activity: /boot/grub/grub.cfg.new -- pin/unpin/trial will refuse`" and the hint `"$hint`"" (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'INFO package activity: /boot/grub/grub.cfg.new -- pin/unpin/trial will refuse') -and (Test-HasLine $r.lines $hint)
        ) (Format-Result $r)
        $fx = New-Kt -Leftovers @('boot/grub/grub.cfg.new') -PgrepPlan @('dpkg * 4242 /usr/bin/dpkg --configure -a')
        $r = Invoke-KT $fx @('status') -label 'F1r2'
        Assert 'F1r2 (x): status with grub.cfg.new while dpkg runs -> no stale-leftover hint (something may still be writing it)' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'INFO package activity: dpkg(4242) /boot/grub/grub.cfg.new -- pin/unpin/trial will refuse') -and -not (Test-HasLinePrefix $r.lines 'INFO package activity hint: ')
        ) (Format-Result $r)
        # 우리 update-grub이 실패하며 남긴 grub.cfg.new(grub-script-check 실패의 모양)는 되돌리기를 막지 않는다 — 되돌리기 직전 검사는 프로세스만 본다.
        $fx = New-Kt -UpdateGrubMode 'fail-leave-new ok'
        $r = Invoke-KT $fx @('pin') -label 'F1s'
        Assert 'F1s (x): pin, update-grub fails and leaves /boot/grub/grub.cfg.new (as grub-script-check failures do) -> the rollback still runs update-grub (no process = no overlap): exit 1, "OK rollback: pin file removed; grub.cfg default is "0" again", update-grub twice, no pin file, no grub.cfg.new left' (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'OK rollback: pin file removed; grub.cfg default is "0" again') -and $r.ug -eq 2 -and $null -eq (Get-PinText $fx) -and
            -not (Test-Path -LiteralPath (Join-Path $fx.Root 'boot/grub/grub.cfg.new'))
        ) (Format-Result $r)
    }

    # ---------- F2: grub.cfg에 'set partuuid='가 있으면 pin · trial을 하지 않는다 ----------
    Test-Group 'F2' {
        $on1 = "FAIL initrdless-boot fallback: on (1 'set partuuid=' line(s)) -- submenu entries boot without an initrd and are never retried; pin/trial are not supported here"
        $fx = New-Kt -Partuuid 1
        $r = Invoke-KT $fx @('status') -label 'F2a'
        Assert "F2a: status with one 'set partuuid=' line in grub.cfg -> exit 1, `"$on1`", no write, RESULT FAIL status" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $on1) -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL status -- ')
        ) (Format-Result $r)
        $fx = New-Kt -Partuuid 2
        $r = Invoke-KT $fx @('status') -label 'F2b'
        Assert "F2b: status with two 'set partuuid=' lines -> exit 1, the line counts 2 (`"... on (2 'set partuuid=' line(s)) ...`")" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $on1.Replace("(1 'set", "(2 'set"))
        ) (Format-Result $r)
        $fx = New-Kt -Partuuid 1
        $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('pin') -label 'F2c'
        Assert "F2c: pin with 'set partuuid=' in grub.cfg -> exit 1, `"$on1`", no pin file, grub.cfg unchanged, no write call, RESULT FAIL pin -- refused: initrd-less boot fallback is on ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines $on1) -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL pin -- refused: initrd-less boot fallback is on')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Partuuid = 1 }
        $r = Invoke-KT $fx @('trial', $K7) -label 'F2d'
        Assert "F2d: trial (6.17 pinned) with 'set partuuid=' in grub.cfg -> exit 1, `"$on1`", grub-editenv set/unset not called, no next_entry, RESULT FAIL trial -- refused: initrd-less boot fallback is on ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines $on1) -and $r.set -eq 0 -and $r.unset -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-LastPrefix $r 'RESULT: FAIL trial -- refused: initrd-less boot fallback is on')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Partuuid = 1; Running = $K7 }
        $r = Invoke-KT $fx @('unpin') -label 'F2e'
        Assert "F2e: unpin is not blocked by 'set partuuid=' -> exit 0, no pin file, grub.cfg default 0, update-grub once" (
            $r.code -eq 0 -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) '0') -and $r.ug -eq 1 -and (Test-LastPrefix $r 'RESULT: OK unpin -- ')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Partuuid = 1; NextEntry = (Get-PinValue $K7) }
        $r = Invoke-KT $fx @('cancel-trial') -label 'F2f'
        Assert "F2f: cancel-trial is not blocked by 'set partuuid=' -> exit 0, next_entry cleared, unset once" (
            $r.code -eq 0 -and $null -eq (Get-NextEntry $fx) -and $r.unset -eq 1 -and (Test-LastPrefix $r 'RESULT: OK cancel-trial -- ')
        ) (Format-Result $r)
    }

    # ---------- F3: 죽은 실행의 잔여 파일 · 과도 상태의 수동 복구 줄 · 출력이 닫혀도 끝까지 ----------
    Test-Group 'F3' {
        $v6 = Get-PinValue $K6
        $fx = New-Kt -Leftovers @('etc/default/grub.d/.kernel-trial-pin.Xy12Ab', 'etc/default/grub.d/.kernel-trial-pin.aside.Qw34Er', 'boot/grub/grub.cfg.new')
        $r = Invoke-KT $fx @('status') -label 'F3a'
        $want = 'INFO leftovers: /etc/default/grub.d/.kernel-trial-pin.Xy12Ab /etc/default/grub.d/.kernel-trial-pin.aside.Qw34Er /boot/grub/grub.cfg.new'
        Assert "F3a: status lists what killed runs leave behind (pin temp file, set-aside pin file, grub.cfg.new) -> exit 0, `"$want`", no write, the files stay (S-runs)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $want) -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-Kt -Pin $v6
        $r = Invoke-KT $fx @('status') -label 'F3b'
        $line = "FAIL pin: INCONSISTENT (pin file says `"$v6`" but grub.cfg default is `"0`" (update-grub not run or failed) -- $FIX)"
        Assert "F3b: status in the state a killed pin leaves (pin file written, update-grub never ran) -> exit 1, the INCONSISTENT line carries the manual fix: `"$line`"" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line)
        ) (Format-Result $r)
        $fx = New-Kt -Default $v6 -Leftovers @('etc/default/grub.d/.kernel-trial-pin.aside.Qw34Er')
        $r = Invoke-KT $fx @('status') -label 'F3c'
        $line = "FAIL pin: INCONSISTENT (no pin file but grub.cfg default is `"$v6`" (want `"0`") -- $FIX)"
        Assert "F3c: status in the state a killed unpin leaves (pin file set aside, grub.cfg still pinned) -> exit 1, `"$line`", `"INFO leftovers: /etc/default/grub.d/.kernel-trial-pin.aside.Qw34Er`"" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.lines 'INFO leftovers: /etc/default/grub.d/.kernel-trial-pin.aside.Qw34Er')
        ) (Format-Result $r)
        $absentLine = "FAIL pin file: absent but grub.cfg default is `"$v6`" (want `"0`") -- $FIX"
        $fx = New-Kt -Default $v6
        $r = Invoke-KT $fx @('trial', $K7) -label 'F3d'
        Assert "F3d: trial in that state -> exit 1, `"$absentLine`", grub-editenv set/unset not called" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $absentLine) -and $r.set -eq 0 -and $r.unset -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        $fx = New-Kt -Default $v6 -Running $K7
        $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('unpin') -label 'F3e'
        Assert "F3e: unpin in that state -> exit 1, `"$absentLine`", no write call, grub.cfg unchanged" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $absentLine) -and $r.writes -eq 0 -and (Test-Same (Get-CfgHash $fx) $cfgHash)
        ) (Format-Result $r)
        # 출력이 닫힌 채 실행(SSH 세션이 끊긴 것과 같다): trap '' HUP PIPE 덕분에 쓰기와 되돌리기가 끝까지 간다.
        $fx = New-Kt
        $r = Invoke-KT $fx @('pin') -label 'F3f' -CloseStdout
        Assert 'F3f: pin with stdout closed before the first line (the session is gone) -> bash keeps going (stderr shows the failed writes: "Broken pipe"), exit 0, pin file written, grub.cfg default = the 6.17 value, update-grub once' (
            $r.code -eq 0 -and $r.err.Contains('Broken pipe') -and (Test-PinContent (Get-PinText $fx) $v6) -and (Test-Same (Get-CfgDefault $fx) $v6) -and $r.ug -eq 1
        ) ("[exit=$($r.code)] [calls: $($r.calls -join ' ; ')] stderr: $($r.err)")
        $fx = New-Kt -UpdateGrubMode 'fail ok'
        $r = Invoke-KT $fx @('pin') -label 'F3g' -CloseStdout
        Assert 'F3g: pin with stdout closed and update-grub failing -> the rollback still runs to the end: exit 1, no pin file, grub.cfg default 0, update-grub twice' (
            $r.code -eq 1 -and $r.err.Contains('Broken pipe') -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) '0') -and $r.ug -eq 2
        ) ("[exit=$($r.code)] [calls: $($r.calls -join ' ; ')] stderr: $($r.err)")
        $fx = New-Pinned @{ Running = $K7 }
        $r = Invoke-KT $fx @('unpin') -label 'F3h' -CloseStdout
        Assert 'F3h: unpin with stdout closed -> exit 0, no pin file, grub.cfg default 0, update-grub once, no set-aside file left (S-runs)' (
            $r.code -eq 0 -and $r.err.Contains('Broken pipe') -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgDefault $fx) '0') -and $r.ug -eq 1
        ) ("[exit=$($r.code)] [calls: $($r.calls -join ' ; ')] stderr: $($r.err)")
    }

    # ---------- F6: 복구용(고정된) 커널을 다시 확인한다 ----------
    Test-Group 'F6' {
        $v6 = Get-PinValue $K6
        $fx = New-Pinned
        $r = Invoke-KT $fx @('trial', $K7) -label 'F6a'
        Assert "F6a: trial checks the fallback in the open -> exit 0, `"OK pin value: `"$v6`" is what pin would write for the running kernel`" and `"OK fallback kernel files: $K6 has ...`"" (
            $r.code -eq 0 -and (Test-HasLine $r.lines "OK pin value: `"$v6`" is what pin would write for the running kernel") -and (Test-HasLinePrefix $r.lines "OK fallback kernel files: $K6 has ")
        ) (Format-Result $r)
        $cases = @(
            @{ n = 'F6b: the pin is the running kernel''s recovery-mode entry (and grub.cfg agrees)'; p = @{ Pin = $REC6; Default = $REC6 }; line = "FAIL pin value: `"$REC6`" is not what pin would write for the running kernel $K6 (`"$v6`") -- the fallback must be the running kernel's -advanced- entry (not recovery mode)" },
            @{ n = 'F6c: the running (pinned) kernel''s initrd is empty'; p = @{ EmptyInitrd = @($K6) }; line = "FAIL fallback kernel files: ${K6}: empty /boot/initrd.img-$K6" },
            @{ n = 'F6d: the running (pinned) kernel''s vmlinuz is missing'; p = @{ NoVmlinuz = @($K6) }; line = "FAIL fallback kernel files: ${K6}: missing /boot/vmlinuz-$K6" }
        )
        foreach ($c in $cases) {
            $fx = New-Pinned $c.p
            $r = Invoke-KT $fx @('trial', $K7) -label ($c.n -split ':')[0]
            Assert "$($c.n) -> trial exit 1, `"$($c.line)`", grub-editenv set/unset not called, no next_entry, RESULT FAIL trial -- refused: ..." (
                $r.code -eq 1 -and (Test-HasLine $r.lines $c.line) -and $r.set -eq 0 -and $r.unset -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-LastPrefix $r 'RESULT: FAIL trial -- refused: ')
            ) (Format-Result $r)
        }
        $cases = @(
            @{ n = 'F6e: status, the pin is the recovery-mode entry of 6.17'; p = @{ Pin = $REC6; Default = $REC6 }; line = "FAIL pin: INCONSISTENT (pin value `"$REC6`" is not the -advanced- entry of $K6 (want `"$v6`"; recovery mode or another entry))"; more = $null },
            @{ n = 'F6f: status, the pinned kernel''s initrd is missing'; p = @{ NoInitrd = @($K6) }; line = "FAIL pin: INCONSISTENT (pinned kernel ${K6}: missing /boot/initrd.img-$K6)"; more = $null },
            @{ n = 'F6g: status, the pinned kernel''s vmlinuz is empty'; p = @{ EmptyVmlinuz = @($K6) }; line = "FAIL pin: INCONSISTENT (pinned kernel ${K6}: empty /boot/vmlinuz-$K6)"; more = "INFO kernel ${K6}: vmlinuz=empty initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 accounted=0 [running]" }
        )
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($c in $cases) {
            $fx = New-Pinned $c.p
            $r = Invoke-KT $fx @('status') -label ($c.n -split ':')[0]
            foreach ($l in (Get-LinesWithPrefix $r.lines 'FAIL pin: INCONSISTENT (')) { [void]$seen.Add($l) }
            $moreOk = if ($c.more) { Test-HasLine $r.lines $c.more } else { $true }
            $moreText = if ($c.more) { ', "' + $c.more + '"' } else { '' }
            Assert "$($c.n) -> status exit 1, `"$($c.line)`"$moreText, no write" (
                $r.code -eq 1 -and (Test-HasLine $r.lines $c.line) -and $moreOk -and $r.writes -eq 0
            ) (Format-Result $r)
        }
        Assert 'F6h: the three INCONSISTENT reasons (entry kind, missing file, empty file) differ from one another' ($seen.Count -eq 3) "lines: [$($seen -join ' | ')]"
        $fx = New-Kt -EmptyInitrd @($K6)
        $r = Invoke-KT $fx @('pin') -label 'F6i'
        Assert "F6i (x): pin refuses an empty initrd of the running kernel too (-s, not only -f) -> exit 1, `"FAIL kernel files: ${K6}: empty /boot/initrd.img-$K6`", no pin file, no write call" (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL kernel files: ${K6}: empty /boot/initrd.img-$K6") -and $null -eq (Get-PinText $fx) -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-Pinned @{ Running = $K7 }
        $r = Invoke-KT $fx @('status') -label 'F6j'
        Assert "F6j: status with 6.17 pinned while 7.0 runs (after the trial boot) -> exit 0, `"OK pin: present -> $K6`" (the pinned kernel need not be the running one)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines "OK pin: present -> $K6")
        ) (Format-Result $r)
    }

    # ---------- F9: grubenv의 initrdfail · prev_entry ----------
    Test-Group 'F9' {
        $v7 = Get-PinValue $K7
        # L3 (b): 이유 끝에 운영자가 할 일($INITRD_HINT)이 붙는다.
        $tail = " (GRUB's initrd-less boot fallback may override the next boot shown here) -- $INITRD_HINT)"
        $fx = New-Kt -EnvVars @('initrdfail=1', "prev_entry=$v7")
        $r = Invoke-KT $fx @('status') -label 'F9a'
        $line = "FAIL pin: INCONSISTENT (grubenv initrdfail=`"1`" prev_entry=`"$v7`"$tail"
        Assert "F9a: status with grubenv initrdfail=1 and prev_entry set -> exit 1, `"$line`", no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-Kt -EnvVars @("prev_entry=$v7")
        $r = Invoke-KT $fx @('status') -label 'F9b'
        $line = "FAIL pin: INCONSISTENT (grubenv initrdfail=`"`" prev_entry=`"$v7`"$tail"
        Assert "F9b: status with only prev_entry set -> exit 1, `"$line`"" ($r.code -eq 1 -and (Test-HasLine $r.lines $line)) (Format-Result $r)
        $fx = New-Kt -EnvVars @('initrdfail=', 'prev_entry=')
        $r = Invoke-KT $fx @('status') -label 'F9c'
        Assert 'F9c: status with initrdfail= and prev_entry= listed but empty (as GRUB leaves them) -> empty reads as none: exit 0, "OK pin: absent"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines 'OK pin: absent') -and (Test-HasLine $r.lines 'INFO grubenv: initrdfail=')
        ) (Format-Result $r)
        $fx = New-Kt -EnvVars @('initrdfail=1')
        $r = Invoke-KT $fx @('pin') -label 'F9d'
        $line = 'FAIL initrd fallback: grubenv initrdfail="1" prev_entry="" -- GRUB''s initrd-less boot fallback may override the next boot; pin/trial refuse while either is set -- ' + $INITRD_HINT
        Assert "F9d: pin with grubenv initrdfail=1 -> exit 1, `"$line`", no pin file, no write call, RESULT FAIL pin -- refused: grubenv holds initrdfail/prev_entry ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $null -eq (Get-PinText $fx) -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL pin -- refused: grubenv holds initrdfail/prev_entry')
        ) (Format-Result $r)
        $fx = New-Pinned @{ EnvVars = @("prev_entry=$v7") }
        $r = Invoke-KT $fx @('trial', $K7) -label 'F9e'
        $line = "FAIL initrd fallback: grubenv initrdfail=`"`" prev_entry=`"$v7`" -- GRUB's initrd-less boot fallback may override the next boot; pin/trial refuse while either is set -- $INITRD_HINT"
        Assert "F9e: trial with grubenv prev_entry set -> exit 1, `"$line`", grub-editenv set/unset not called" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.set -eq 0 -and $r.unset -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
    }

    # ---------- F10: 테스트의 빈 곳(리뷰의 생존 변이 m3 · m4 · m5 · m6 · m14 · m15) ----------
    Test-Group 'F10' {
        $v6 = Get-PinValue $K6; $v7 = Get-PinValue $K7
        # 비root: trial · unpin · cancel-trial — 쓰기 호출 0, grub-editenv 호출 자체가 0
        $cases = @(
            @{ n = 'F10a: trial as uid 1000'; a = @('trial', $K7); p = @{ Uid = '1000' } },
            @{ n = 'F10b: unpin as uid 1000 (running the newest kernel)'; a = @('unpin'); p = @{ Uid = '1000'; Running = $K7 } },
            @{ n = 'F10c: cancel-trial as uid 1000 (next_entry set)'; a = @('cancel-trial'); p = @{ Uid = '1000'; NextEntry = $v7 } }
        )
        foreach ($c in $cases) {
            $fx = New-Pinned $c.p
            $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx; $ne = Get-NextEntry $fx
            $r = Invoke-KT $fx $c.a -label ($c.n -split ':')[0]
            $editenv = @($r.calls | Where-Object { $_.StartsWith('grub-editenv ', [StringComparison]::Ordinal) }).Count
            Assert "$($c.n) -> exit 1, `"FAIL root: uid 1000 -- run with sudo`", no write call and no grub-editenv call at all, pin file / grub.cfg / next_entry unchanged, RESULT FAIL" (
                $r.code -eq 1 -and (Test-HasLine $r.lines 'FAIL root: uid 1000 -- run with sudo') -and $r.writes -eq 0 -and $editenv -eq 0 -and (Test-Same (Get-PinHash $fx) $pinHash) -and
                (Test-Same (Get-CfgHash $fx) $cfgHash) -and (Test-Same (Get-NextEntry $fx) $ne) -and (Test-LastPrefix $r "RESULT: FAIL $($c.a[0]) -- refused: not root")
            ) (Format-Result $r)
        }
        # grub-editenv의 unset이 exit 0인데 지우지 않는다 → 읽어 보기가 잡는다
        $fx = New-Pinned @{ NextEntry = $v7; EditenvMode = 'unset-noop' }
        $r = Invoke-KT $fx @('cancel-trial') -label 'F10d'
        Assert "F10d: cancel-trial when grub-editenv unset exits 0 but removes nothing -> exit 1, `"FAIL verify: next_entry is still `"$v7`" -- the next boot will use it; run cancel-trial`", next_entry still set, unset once, RESULT FAIL" (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL verify: next_entry is still `"$v7`" -- the next boot will use it; run cancel-trial") -and (Test-Same (Get-NextEntry $fx) $v7) -and $r.unset -eq 1 -and
            (Test-LastPrefix $r 'RESULT: FAIL cancel-trial -- ')
        ) (Format-Result $r)
        $fx = New-Pinned @{ EditenvMode = 'set-wrong unset-noop' }
        $r = Invoke-KT $fx @('trial', $K7) -label 'F10e'
        Assert "F10e: trial when set writes a wrong value and unset removes nothing -> exit 1, `"FAIL verify: next_entry is `"$v7-wrong`", want `"$v7`"`", `"FAIL cleanup: next_entry is still `"$v7-wrong`" -- the next boot will use it; run cancel-trial`", set once, unset once, RESULT FAIL trial -- could not set next_entry and could not clear it ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL verify: next_entry is `"$v7-wrong`", want `"$v7`"") -and (Test-HasLine $r.lines "FAIL cleanup: next_entry is still `"$v7-wrong`" -- the next boot will use it; run cancel-trial") -and
            (Test-Same (Get-NextEntry $fx) "$v7-wrong") -and $r.set -eq 1 -and $r.unset -eq 1 -and (Test-LastPrefix $r 'RESULT: FAIL trial -- could not set next_entry and could not clear it')
        ) (Format-Result $r)
        # 고정 파일 변형 → 거부(grub.cfg 기본값은 그 값과 같다 — 형식만 어긋난다)
        $entry6 = Get-EntryId $K6
        $variants = @(
            @{ n = 'unknown line mixed in'; t = "# kernel-trial pin`nGRUB_DEFAULT=`"$v6`"`nGRUB_TIMEOUT=5`n"; why = 'unexpected line: GRUB_TIMEOUT=5'; cmds = @('pin', 'trial', 'unpin', 'status') },
            @{ n = 'two GRUB_DEFAULT lines'; t = "# kernel-trial pin`nGRUB_DEFAULT=`"$v6`"`nGRUB_DEFAULT=`"$v6`"`n"; why = '2 GRUB_DEFAULT lines (want exactly 1)'; cmds = @('pin', 'trial', 'unpin', 'status') },
            @{ n = 'value without quotes'; t = "# kernel-trial pin`nGRUB_DEFAULT=$v6`n"; why = "unexpected line: GRUB_DEFAULT=$v6"; cmds = @('pin', 'status') },
            @{ n = 'value in single quotes'; t = "# kernel-trial pin`nGRUB_DEFAULT='$v6'`n"; why = "unexpected line: GRUB_DEFAULT='$v6'"; cmds = @('pin', 'status') },
            @{ n = 'export prefix'; t = "# kernel-trial pin`nexport GRUB_DEFAULT=`"$v6`"`n"; why = "unexpected line: export GRUB_DEFAULT=`"$v6`""; cmds = @('pin', 'status') },
            @{ n = 'no submenu part'; t = "# kernel-trial pin`nGRUB_DEFAULT=`"$entry6`"`n"; why = "value `"$entry6`" is not <submenu id>><entry id>"; cmds = @('status') }
        )
        foreach ($vt in $variants) {
            foreach ($cmd in $vt.cmds) {
                $p = @{ PinText = $vt.t; Default = $v6 }
                if ($cmd -eq 'unpin') { $p.Running = $K7 }
                $fx = New-Kt @p
                $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx
                $a = if ($cmd -eq 'trial') { @('trial', $K7) } else { @($cmd) }
                $r = Invoke-KT $fx $a -label "F10f[$($vt.n)/$cmd]"
                $line = "FAIL pin file: malformed (/etc/default/grub.d/99-kernel-trial-pin.cfg): $($vt.why)" + $(if ($cmd -eq 'unpin') { ' -- inspect it by hand' } else { '' })
                $extra = if ($cmd -eq 'status') { Test-HasLine $r.lines "FAIL pin: INCONSISTENT (pin file malformed: $($vt.why))" } else { $true }
                Assert "F10f: pin file [$($vt.n)] with $cmd -> exit 1, `"$line`"$(if ($cmd -eq 'status') { ' and the INCONSISTENT pin line' }), no write call, pin file and grub.cfg unchanged" (
                    $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $extra -and $r.writes -eq 0 -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgHash $fx) $cfgHash)
                ) (Format-Result $r)
            }
        }
        # unpin 사후 검증: 기본값은 0인데 0번 항목이 실행 중 커널이 아니다 → 되돌리고 FAIL
        $fx = New-Pinned @{ Running = $K7; UpdateGrubMode = 'alt ok'; AltKernels = @($K6, $K7) }
        $pinHash = Get-PinHash $fx
        $r = Invoke-KT $fx @('unpin') -label 'F10g'
        $line = "FAIL verify: entry 0 boots $K6, not the running kernel $K7 -- $FIX"
        Assert "F10g: unpin when update-grub writes default 0 but entry 0 is not the running kernel (6.17 sorted first) -> exit 1, `"$line`", `"OK restore: pin file restored; grub.cfg default is the pinned value `"$v6`"`", pin file byte-identical, grub.cfg default = the pinned value, update-grub twice" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.lines "OK restore: pin file restored; grub.cfg default is the pinned value `"$v6`"") -and
            $null -ne $pinHash -and (Test-Same (Get-PinHash $fx) $pinHash) -and (Test-Same (Get-CfgDefault $fx) $v6) -and $r.ug -eq 2
        ) (Format-Result $r)
        # 가짜 도구가 비ASCII 글자를 낸다 → 스크립트 출력은 ASCII만(바이트마다 '?')
        $fx = New-Kt -Utf8UpdateGrub
        $r = Invoke-KT $fx @('pin') -label 'F10h'
        $raw = [Text.Encoding]::Latin1.GetString($r.outBytes)
        Assert "F10h: pin when update-grub prints non-ASCII text -> exit 0, `"INFO update-grub: $NONASCII_SANITIZED`" (one '?' per non-ASCII byte), every output byte printable ASCII or LF" (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO update-grub: $NONASCII_SANITIZED") -and -not [regex]::IsMatch($raw, '[^\n\x20-\x7E]')
        ) (Format-Result $r)
        $fx = New-Kt -EnvVars @("note=$NONASCII") -CmdlineExtra " $NONASCII"
        $r = Invoke-KT $fx @('status') -label 'F10i'
        $raw = [Text.Encoding]::Latin1.GetString($r.outBytes)
        Assert "F10i: status when grubenv and /proc/cmdline hold non-ASCII text -> exit 0, `"INFO grubenv: note=$NONASCII_SANITIZED`", the cmdline line ends in `"$NONASCII_SANITIZED`", every output byte printable ASCII or LF" (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO grubenv: note=$NONASCII_SANITIZED") -and (Test-HasLine $r.lines "INFO cmdline: BOOT_IMAGE=/vmlinuz-$K6 root=UUID=$UUID ro console=tty1 console=ttyS0 $NONASCII_SANITIZED") -and
            -not [regex]::IsMatch($raw, '[^\n\x20-\x7E]')
        ) (Format-Result $r)
    }

    # ---------- M1: 모듈 검사 — 이름으로 못 찾은 모듈을 대체됨(사용자 경로 · 별칭 경로) · 없음으로 나눈다(수정 지시서 2 + 후속 F-A) ----------
    Test-Group 'M1' {
        $tag7 = "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 "
        $q7 = "modprobe -S $K7 --show-depends"
        # 0. 이름으로 다 찾으면 줄은 그대로이고 modprobe를 부르지 않는다
        $fx = New-Pinned
        $r = Invoke-KT $fx @('trial', $K7) -label 'M1-0'
        Assert "M1-0: trial when every loaded module is found by name in 7.0 -> the line stays as before: `"OK modules: all 4 loaded modules exist for $K7`", modprobe never asked, one write (grub-editenv set)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines "OK modules: all 4 loaded modules exist for $K7") -and $r.mp -eq 0 -and $r.writes -eq 1 -and $r.set -eq 1
        ) (Format-Result $r)
        # 1. 6.17 → 7.0의 실제 넷(F-D 실측): 없음 polyval_ce · 대체됨 셋(사용자 경로 둘 · 별칭 경로 blake2b_generic=crypto-blake2b-512)
        $fx = New-M1
        $r = Invoke-KT $fx @('trial', $K7) -label 'M1-1a'
        $mpCalls = @($r.calls | Where-Object { $_.StartsWith('modprobe ', [StringComparison]::Ordinal) })
        $fCalls = @($r.calls | Where-Object { $_.StartsWith('modinfo ', [StringComparison]::Ordinal) -and ($_.Contains(' -F alias ') -or $_.Contains(' -F name ')) })
        $want = (@($M1Queries | ForEach-Object { "$q7 $_" })) -join ';'
        # R3-1: crypto-blake2b-512의 답(insmod libblake2b · blake2b)에서 계승자를 찾는다 — libblake2b는 별칭이 없고, blake2b는 7.0에서 그 별칭을
        #   선언하며 6.17에 그 이름이 없다(-F name exit 1)라서 6.17의 alias는 묻지 않는다.
        $wantF = "modinfo -k $K6 -F alias blake2b_generic;modinfo -k $K7 -F alias libblake2b;modinfo -k $K7 -F alias blake2b;modinfo -k $K6 -F name blake2b;modinfo -k $K6 -F alias polyval_ce"
        $line = "FAIL modules: 1 of 11 loaded modules missing for ${K7}: polyval_ce (rerun with --accept-missing-modules polyval_ce to accept exactly these)"
        Assert "M1-1a: trial 7.0 with the real four renamed modules (6.17: libcurve25519_generic used by wireguard, aes_ce_cipher used by aes_ce_blk, blake2b_generic and polyval_ce without users) and no option -> exit 1, `"$line`" (none of polyval_ce's four concrete aliases resolves in 7.0), no write; modprobe asked exactly [$($M1Queries -join ', ')] with -S $K7 (probe, user, blake2b_generic's aliases up to the first that resolves, user, polyval_ce's concrete aliases -- its glob alias is never asked); modinfo -F alias / -F name asked exactly [$($wantF -replace ';', ', ')] (the two user-less modules' aliases on $K6, and for crypto-blake2b-512 the successor check of its answer libblake2b, blake2b: blake2b declares it on $K7 and has no name on $K6)" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-Same ($mpCalls -join ';') $want) -and
            (Test-Same ($fCalls -join ';') $wantF)
        ) (Format-Result $r)
        $fx = New-M1
        $r = Invoke-KT $fx @('status') -label 'M1-1b'
        $line = "${tag7}missing-loaded-modules=1 ($M1Miss) accounted=3 ($M1Acc) [newest]"
        Assert "M1-1b: status with the same fixture -> exit 0, `"$line`", the 6.17 line `"... missing-loaded-modules=0 accounted=0 [running]`", modprobe asked $($M1Queries.Count) times (never for 6.17), no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.lines "INFO kernel ${K6}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 accounted=0 [running]") -and $r.mp -eq $M1Queries.Count -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-M1
        $r = Invoke-KT $fx @('trial', $K7, '--accept-missing-modules', 'polyval_ce') -label 'M1-1c'
        $line = "INFO modules: accepted exactly: polyval_ce (1 of 11 loaded modules missing for $K7)"
        Assert "M1-1c: the same trial with --accept-missing-modules polyval_ce -> exit 0, `"$line`", no FAIL modules line, next_entry set (one write)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and -not (Test-HasLinePrefix $r.lines 'FAIL modules: ') -and $r.writes -eq 1 -and $r.set -eq 1 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7))
        ) (Format-Result $r)
        # 2. 7.0 → 6.17: libblake2b(사용자 btrfs — 6.17에서 btrfs의 사슬은 blake2b_generic으로 풀린다) → 없음 0
        $fx = New-Pinned @{ Running = $K7; Loaded = @('wireguard', 'libcurve25519', 'ip6_udp_tunnel', 'udp_tunnel', 'aes_ce_blk', 'btrfs', 'libblake2b', 'overlay'); Lsmod = @{ 'libcurve25519' = '1 wireguard'; 'ip6_udp_tunnel' = '1 wireguard'; 'udp_tunnel' = '1 wireguard'; 'libblake2b' = '1 btrfs'; 'overlay' = '2' }; Lacking = @{ $K6 = @('libblake2b') }; Modprobe = @{ $K6 = $MP6 } }
        $r = Invoke-KT $fx @('status') -label 'M1-2'
        $line = "INFO kernel ${K6}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 accounted=1 (libblake2b->btrfs)"
        Assert "M1-2: status while running 7.0 (7.0 lsmod: libblake2b used by btrfs; no libblake2b in 6.17 -- the node showed 'missing-loaded-modules=1 (libblake2b)' before M1) -> exit 0, `"$line`", the 7.0 line accounted=0 [running] [newest], modprobe asked twice with -S $K6 (probe libblake2b, user btrfs), no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.lines "${tag7}missing-loaded-modules=0 accounted=0 [running] [newest]") -and $r.writes -eq 0 -and
            (Test-Same (@($r.calls | Where-Object { $_.StartsWith('modprobe ', [StringComparison]::Ordinal) }) -join ';') "modprobe -S $K6 --show-depends libblake2b;modprobe -S $K6 --show-depends btrfs")
        ) (Format-Result $r)
        # 3. 진짜 없음: foo_lib의 사용자 foo_drv가 7.0에서 풀리지 않는다(modprobe exit 1) → 없음(polyval_ce와 함께 둘)
        $ls3 = $M1Lsmod.Clone(); $ls3['foo_drv'] = '2'; $ls3['foo_lib'] = '1 foo_drv'
        $p3 = @{ Loaded = $M1Loaded + @('foo_drv', 'foo_lib'); Lsmod = $ls3; Lacking = @{ $K7 = $M1Renamed + @('foo_lib') } }
        $fx = New-M1 $p3
        $r = Invoke-KT $fx @('trial', $K7) -label 'M1-3a'
        $line = "FAIL modules: 2 of 13 loaded modules missing for ${K7}: foo_lib polyval_ce (rerun with --accept-missing-modules foo_lib,polyval_ce to accept exactly these)"
        Assert "M1-3a: trial 7.0 where foo_lib (lsmod: used by foo_drv) has no name in 7.0 and its user foo_drv does not resolve there (modprobe exit 1) -> exit 1, `"$line`" (only the missing ones are counted and named; the hint gives them comma-separated), no write, RESULT FAIL trial -- refused: loaded modules missing ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-LastPrefix $r 'RESULT: FAIL trial -- refused: loaded modules missing')
        ) (Format-Result $r)
        $r = Invoke-KT $fx @('trial', $K7, '--ignore-missing-modules') -label 'M1-3b'
        $line = "INFO modules: 2 of 13 loaded modules missing for ${K7}: foo_lib polyval_ce (accepted: --ignore-missing-modules)"
        Assert "M1-3b: the same with --ignore-missing-modules -> exit 0, `"$IGNORE_HINT`" and then `"$line`" as the only two modules lines (the three accounted for are not listed as missing), next_entry set (one write)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.lines $IGNORE_HINT) -and (Get-LinesWithPrefix $r.lines 'INFO modules: ').Count -eq 2 -and -not (Test-HasLinePrefix $r.lines 'OK modules: ') -and
            [array]::IndexOf($r.lines, $IGNORE_HINT) -lt [array]::IndexOf($r.lines, $line) -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7)) -and $r.set -eq 1 -and $r.writes -eq 1
        ) (Format-Result $r)
        $fx = New-M1 $p3
        $r = Invoke-KT $fx @('status') -label 'M1-3c'
        $line = "${tag7}missing-loaded-modules=2 (foo_lib polyval_ce) accounted=3 ($M1Acc) [newest]"
        Assert "M1-3c: status -> `"$line`", no write" ($r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0) (Format-Result $r)
        # 4. 사용 수와 무관(F-A): 사용자 없는 모듈은 사용 수가 0이든 아니든 별칭으로 판정한다
        $ls4 = $M1Lsmod.Clone(); $ls4['blake2b_generic'] = '2'; $ls4['polyval_ce'] = '0'
        $fx = New-M1 @{ Lsmod = $ls4 }
        $r = Invoke-KT $fx @('status') -label 'M1-4'
        $line = "${tag7}missing-loaded-modules=1 ($M1Miss) accounted=3 ($M1Acc) [newest]"
        Assert "M1-4: status where blake2b_generic (no users) has a use count of 2 and polyval_ce (no users) a use count of 0 -> the count decides nothing: blake2b_generic is replaced through its alias, polyval_ce (count 0) is still missing: `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        # 5. 부팅 때 이름으로 적재되는 목록에 있으면 별칭이 풀려도 없음(별칭은 묻지도 않는다)
        $fx = New-M1 @{ BootLists = @{ 'etc/modules-load.d/x.conf' = "# loaded at boot by name`nblake2b_generic`n" } }
        $r = Invoke-KT $fx @('trial', $K7) -label 'M1-5a'
        $line = "FAIL modules: 2 of 11 loaded modules missing for ${K7}: blake2b_generic polyval_ce (rerun with --accept-missing-modules blake2b_generic,polyval_ce to accept exactly these)"
        Assert "M1-5a: trial 7.0 where blake2b_generic (no users; its alias crypto-blake2b-512 resolves in 7.0) is listed in /etc/modules-load.d/x.conf -> missing anyway: exit 1, `"$line`", its aliases never looked up, no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and -not (Test-HasLine $r.calls "modinfo -k $K6 -F alias blake2b_generic") -and $r.writes -eq 0
        ) (Format-Result $r)
        # 5b: 목록의 자리와 모양 — 자리마다 다른 모듈(전부 사용자 없음 · 7.0에 이름 없음 · 저마다 7.0에서 풀리는 별칭 'alias-<이름>'이 있다)
        $u = @('u_etc', 'u_run', 'u_local', 'u_usr', 'u_modules', 'u_dash', 'u_arg', 'u_ws', 'u_crlf', 'u_hash', 'u_semi', 'u_txt', 'u_free')
        $lists = @{
            'etc/modules-load.d/a.conf'           = "u_etc`nu-dash`n# u_hash`n  ;u_semi`n   u_ws   `nu_crlf`r`n"
            'run/modules-load.d/b.conf'           = "u_run`n"
            'usr/local/lib/modules-load.d/c.conf' = "u_local`n"
            'usr/lib/modules-load.d/d.conf'       = "u_usr`n"
            'etc/modules'                         = "# /etc/modules: kernel modules to load at boot time.`n`nu_modules`nu_arg some=option`n"
            'etc/modules-load.d/e.txt'            = "u_txt`n"
        }
        # 7.0 쪽 제공자 <이름>_new(파일 <이름>-new.ko.zst — 스크립트가 '-'를 '_'로 읽는다)는 7.0에만 있고 그 별칭을 선언한다(R3-1 계승자).
        $alu = $AL6.Clone(); $mpu = $MP7.Clone(); $alu7 = $AL7Real.Clone(); $exu7 = @($M1Extra7)
        foreach ($x in $u) { $alu[$x] = @("alias-$x"); $mpu["alias-$x"] = @("insmod /lib/modules/$K7/kernel/fake/$x-new.ko.zst"); $alu7["${x}_new"] = @("alias-$x"); $exu7 += "${x}_new" }
        $fx = New-M1 @{ Loaded = $M1Loaded + $u; Lacking = @{ $K7 = $M1Renamed + $u }; BootLists = $lists; Aliases = @{ $K6 = $alu; $K7 = $alu7 }; Extra = @{ $K7 = $exu7 }; Modprobe = @{ $K7 = $mpu } }
        $r = Invoke-KT $fx @('status') -label 'M1-5b'
        $line = "${tag7}missing-loaded-modules=10 (polyval_ce u_arg u_crlf u_dash u_etc u_local u_modules u_run u_usr u_ws) accounted=7 ($M1Acc u_free=alias-u_free u_hash=alias-u_hash u_semi=alias-u_semi u_txt=alias-u_txt) [newest]"
        Assert "M1-5b: status where modules without users are listed for boot in /etc/modules-load.d, /run/modules-load.d, /usr/local/lib/modules-load.d (systemd 255 reads it too), /usr/lib/modules-load.d and /etc/modules (first word of a line; '-' = '_'; blanks and a CR ignored) -> those are missing although their aliases resolve; non-.conf and unlisted ones are replaced through their aliases (a commented line cannot name a module; the # and ; rows only document the format): `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        # 5c: 목록 자리에 정규 파일이 아닌 .conf(디렉터리) → 목록을 판단할 수 없다 → 사용자 없는 것은 전부 없음 + INFO 한 줄(fail closed)
        $fx = New-M1 @{ BootLists = @{ 'etc/modules-load.d/bad.conf' = $null } }
        $r = Invoke-KT $fx @('trial', $K7) -label 'M1-5c'
        $info = 'INFO modules: boot-time module lists unreadable (/etc/modules-load.d/bad.conf is not a readable regular file) -- loaded modules without users count as missing'
        $line = "FAIL modules: 2 of 11 loaded modules missing for ${K7}: blake2b_generic polyval_ce (rerun with --accept-missing-modules blake2b_generic,polyval_ce to accept exactly these)"
        Assert "M1-5c (x): trial where /etc/modules-load.d/bad.conf is a directory (the boot-time lists cannot be judged: fail closed) -> exit 1, `"$info`", `"$line`" (the two with users stay replaced), no alias looked up, no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $info) -and (Test-HasLine $r.lines $line) -and -not (Test-HasLinePrefix $r.calls "modinfo -k $K6 -F alias ") -and $r.writes -eq 0
        ) (Format-Result $r)
        # 5d(R3-5 준수 리뷰): /proc/cmdline을 읽을 수 없다 → 부팅 목록을 판단할 수 없다 → 사용자 없는 것은 전부 없음 + INFO 한 줄(fail closed)
        $fx = New-M1
        Remove-Item -LiteralPath (Join-Path $fx.Root 'proc/cmdline')
        $r = Invoke-KT $fx @('trial', $K7) -label 'M1-5d'
        $info = 'INFO modules: boot-time module lists unreadable (cannot read /proc/cmdline) -- loaded modules without users count as missing'
        $line = "FAIL modules: 2 of 11 loaded modules missing for ${K7}: blake2b_generic polyval_ce (rerun with --accept-missing-modules blake2b_generic,polyval_ce to accept exactly these)"
        Assert "M1-5d (x): trial when /proc/cmdline cannot be read -> exit 1, `"$info`", `"$line`", no alias looked up, no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $info) -and (Test-HasLine $r.lines $line) -and -not (Test-HasLinePrefix $r.calls "modinfo -k $K6 -F alias ") -and $r.writes -eq 0
        ) (Format-Result $r)
        # 6. modprobe를 쓸 수 없다 → 이름 기준으로 되돌아감 + INFO 한 줄
        $all4 = "FAIL modules: 4 of 11 loaded modules missing for ${K7}: aes_ce_cipher blake2b_generic libcurve25519_generic polyval_ce (rerun with --accept-missing-modules aes_ce_cipher,blake2b_generic,libcurve25519_generic,polyval_ce to accept exactly these)"
        $mp7x = $MP7.Clone(); $mp7x['aes_ce_cipher'] = @("insmod /lib/modules/$K7/kernel/arch/arm64/crypto/aes-ce-cipher.ko.zst")
        $cases = @(
            @{ n = 'M1-6a: modprobe is not on PATH at all'; p = @{}; nomp = $true; why = 'not on PATH' },
            @{ n = 'M1-6b: modprobe exits 127 when called (as if it vanished)'; p = @{ ModprobeMode = 'missing' }; nomp = $false; why = "$q7 aes_ce_cipher: exit 127: modprobe: command not found" },
            @{ n = 'M1-6c: modprobe does not know -S (exit 1, invalid option)'; p = @{ ModprobeMode = 'no-S' }; nomp = $false; why = "$q7 aes_ce_cipher: exit 1: modprobe: invalid option -- 'S'" },
            @{ n = 'M1-6d (x): modprobe resolves the first name-missing module although modinfo does not (the tools disagree)'; p = @{ Modprobe = @{ $K7 = $mp7x } }; nomp = $false; why = "modprobe -S $K7 finds aes_ce_cipher but modinfo -k $K7 does not" },
            @{ n = 'M1-6e (x): a later user query (wireguard, after aes_ce_cipher was already replaced) exits 0 with a line that is neither insmod nor builtin (an install command) -- the partial result is dropped'; p = @{ Modprobe = @{ $K7 = @{ 'aes_ce_blk' = $MP7['aes_ce_blk']; 'wireguard' = @('install /bin/true') } } }; nomp = $false; why = "$q7 wireguard: exit 0: install /bin/true" },
            @{ n = 'M1-6i (x): the user aes_ce_blk answers exit 0 with an insmod line and an install line (install aes_ce_blk /bin/false in modprobe.d)'; p = @{ Modprobe = @{ $K7 = @{ 'aes_ce_blk' = @("insmod /lib/modules/$K7/kernel/arch/arm64/crypto/aes-ce-blk.ko.zst", 'install /bin/false'); 'wireguard' = $MP7['wireguard'] } } }; nomp = $false; why = "$q7 aes_ce_blk: exit 0: install /bin/false" },
            @{ n = 'M1-6j (x): the user aes_ce_blk answers exit 0 with no insmod or builtin line at all'; p = @{ Modprobe = @{ $K7 = @{ 'aes_ce_blk' = @(''); 'wireguard' = $MP7['wireguard'] } } }; nomp = $false; why = "$q7 aes_ce_blk: exit 0: no output" }
        )
        foreach ($c in $cases) {
            $fx = New-M1 $c.p
            $r = Invoke-KT $fx @('trial', $K7) -label ($c.n -split ':')[0] -NoModprobe:$c.nomp
            $info = "INFO modules: modprobe unavailable ($($c.why)) -- name check only"
            $pathOk = if ($c.nomp) { $script:noMpOk -and $r.mp -eq 0 } else { $true }
            Assert "$($c.n) -> falls back to the name check: exit 1, `"$info`", `"$all4`", no write" (
                $r.code -eq 1 -and (Test-HasLine $r.lines $info) -and (Test-HasLine $r.lines $all4) -and $r.writes -eq 0 -and $pathOk
            ) (Format-Result $r)
        }
        # 6h: status에서도 — 되돌아가면 그 전에 센 accounted를 버린다(accounted=0)
        $fx = New-M1 @{ Modprobe = @{ $K7 = @{ 'aes_ce_blk' = $MP7['aes_ce_blk']; 'wireguard' = @('install /bin/true') } } }
        $r = Invoke-KT $fx @('status') -label 'M1-6h'
        $info = "INFO modules: modprobe unavailable ($q7 wireguard: exit 0: install /bin/true) -- name check only"
        $line = "${tag7}missing-loaded-modules=4 (aes_ce_cipher blake2b_generic libcurve25519_generic polyval_ce) accounted=0 [newest]"
        Assert "M1-6h: status with the M1-6e answers -> exit 0, `"$info`", `"$line`" (what was accounted for before the bad answer is dropped), no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $info) -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        # 6g: -S를 모르는 modprobe — 이름으로 못 찾은 것이 사용자 없는 하나뿐이어도 첫 확인 질의로 알아채고 되돌아간다
        $fx = New-M1 @{ Lacking = @{ $K7 = @('polyval_ce') }; ModprobeMode = 'no-S' }
        $r = Invoke-KT $fx @('trial', $K7) -label 'M1-6g'
        $info = "INFO modules: modprobe unavailable ($q7 polyval_ce: exit 1: modprobe: invalid option -- 'S') -- name check only"
        $line = "FAIL modules: 1 of 11 loaded modules missing for ${K7}: polyval_ce (rerun with --accept-missing-modules polyval_ce to accept exactly these)"
        Assert "M1-6g: modprobe without -S support while the only name-missing module (polyval_ce) has no users -> the probe query still notices: exit 1, `"$info`", `"$line`", modprobe asked once, no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $info) -and (Test-HasLine $r.lines $line) -and $r.mp -eq 1 -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-M1 @{ Kernels = @($K7, $K6, $K68); Lacking = @{ $K7 = $M1Renamed; $K68 = @('polyval_ce') } }
        $r = Invoke-KT $fx @('status') -label 'M1-6f' -NoModprobe
        $info = 'INFO modules: modprobe unavailable (not on PATH) -- name check only'
        $line = "${tag7}missing-loaded-modules=4 (aes_ce_cipher blake2b_generic libcurve25519_generic polyval_ce) accounted=0 [newest]"
        $line68 = "INFO kernel ${K68}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=1 (polyval_ce) accounted=0"
        Assert "M1-6f: status with modprobe not on PATH and two kernels lacking modules (7.0 and 6.8) -> exit 0, `"$line`", `"$line68`", `"$info`" exactly once, no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.lines $line68) -and @($r.lines | Where-Object { Test-Same $_ $info }).Count -eq 1 -and $script:noMpOk -and $r.writes -eq 0
        ) (Format-Result $r)
        # 7. 사슬: m(xt_foo_helper)의 사용자 u(xt_foo)가 7.0에서 이름으로 풀리지 않는다 → m은 없음; u는 u대로(사용자 없는 모듈 → 별칭) 판정
        #   7.0의 제공자 ipt_foo는 7.0에만 있고 자기 이름과 같은 별칭 ipt_foo를 선언한다(실제에도 있는 모양 — sm4_generic의 별칭 sm4-generic; R3-1 계승자).
        $mp7c = $MP7.Clone(); $mp7c['ipt_foo'] = @("insmod /lib/modules/$K7/kernel/net/netfilter/ipt_foo.ko.zst")
        $al7c = $AL7Real.Clone(); $al7c['ipt_foo'] = @('ipt_foo')
        foreach ($c in @(@{ n = 'M1-7a'; ucnt = '3'; ual = @(); miss = "3 ($M1Miss xt_foo xt_foo_helper)"; acc = "3 ($M1Acc)" }, @{ n = 'M1-7b'; ucnt = '0'; ual = @('ipt_foo'); miss = "2 ($M1Miss xt_foo_helper)"; acc = "4 ($M1Acc xt_foo=ipt_foo)" })) {
            $ls7 = $M1Lsmod.Clone(); $ls7['xt_foo'] = $c.ucnt; $ls7['xt_foo_helper'] = '1 xt_foo'
            $al7 = $AL6.Clone(); if ($c.ual.Count -gt 0) { $al7['xt_foo'] = $c.ual }
            $fx = New-M1 @{ Loaded = $M1Loaded + @('xt_foo', 'xt_foo_helper'); Lsmod = $ls7; Lacking = @{ $K7 = $M1Renamed + @('xt_foo', 'xt_foo_helper') }; Aliases = @{ $K6 = $al7; $K7 = $al7c }; Extra = @{ $K7 = $M1Extra7 + @('ipt_foo') }; Modprobe = @{ $K7 = $mp7c } }
            $r = Invoke-KT $fx @('status') -label $c.n
            $line = "${tag7}missing-loaded-modules=$($c.miss) accounted=$($c.acc) [newest]"
            Assert "$($c.n): status where xt_foo_helper is used by xt_foo and neither has a name in 7.0 (xt_foo: use count $($c.ucnt), aliases [$($c.ual -join ' ')]) -> the user path asks modprobe for xt_foo by name (exit 1), so xt_foo_helper is missing; xt_foo is judged by its own row through its aliases: `"$line`", no write" (
                $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "$q7 xt_foo") -and $r.writes -eq 0
            ) (Format-Result $r)
        }
        # 8. lsmod 사용자 열의 모양 — 모든 s_* 모듈에 7.0에서 풀리는 별칭을 준다: 사용자가 없다고 읽힌 것만 별칭으로 대체되고, 읽지 못한 것은 없음
        $shapes = [ordered]@{
            's_empty'    = '0'
            's_dash'     = '0 - Live 0x0000000000000000'
            's_trailing' = '1 wireguard,'
            's_perm'     = '2 wireguard,[permanent],'
            's_permonly' = '0 [permanent],'
            's_two'      = '2 wireguard,aes_ce_blk'
            's_mixed'    = '2 wireguard,foo_drv'
            's_dot'      = '1 wire.guard'
            's_dollar'   = '1 wireguard,bad$name'
            's_nonascii' = "1 wiregu$([char]0x00E9)rd"
            's_nocount'  = ''
            's_badcount' = '-1'
        }
        $ls8 = $M1Lsmod.Clone(); foreach ($k in $shapes.Keys) { $ls8[$k] = $shapes[$k] }
        $als = $AL6.Clone(); $mps = $MP7.Clone(); $als7 = $AL7Real.Clone(); $exs7 = @($M1Extra7)
        foreach ($x in $shapes.Keys) { $als[$x] = @("alias-$x"); $mps["alias-$x"] = @("insmod /lib/modules/$K7/kernel/fake/$x-new.ko.zst"); $als7["${x}_new"] = @("alias-$x"); $exs7 += "${x}_new" }
        $fx = New-M1 @{ Loaded = $M1Loaded + @($shapes.Keys); Lsmod = $ls8; Lacking = @{ $K7 = $M1Renamed + @($shapes.Keys) }; Aliases = @{ $K6 = $als; $K7 = $als7 }; Extra = @{ $K7 = $exs7 }; Modprobe = @{ $K7 = $mps } }
        $r = Invoke-KT $fx @('status') -label 'M1-8'
        $line = "${tag7}missing-loaded-modules=7 ($M1Miss s_badcount s_dollar s_dot s_mixed s_nocount s_nonascii) accounted=9 ($M1Acc s_dash=alias-s_dash s_empty=alias-s_empty s_perm->wireguard s_permonly=alias-s_permonly s_trailing->wireguard s_two->aes_ce_blk+wireguard) [newest]"
        $unread = @('s_dot', 's_dollar', 's_nonascii', 's_nocount', 's_badcount') | Where-Object { Test-HasLine $r.calls "modinfo -k $K6 -F alias $_" }
        Assert "M1-8: status over lsmod user-column shapes (no column 4 / '-' as in /proc/modules / a trailing comma / [permanent] / two users that both resolve / two users of which one (foo_drv) does not resolve / '.', '$' or non-ASCII in a user name / no use count / a use count of -1) -> `"$line`"; a row that cannot be read is missing before any alias lookup; no modprobe query for a user name that is not [A-Za-z0-9_-]; no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and @($unread).Count -eq 0 -and -not (Test-HasLinePrefix $r.calls "$q7 wire.") -and -not (Test-HasLinePrefix $r.calls "$q7 bad") -and $r.writes -eq 0
        ) ("alias lookups for unreadable rows: [$(@($unread) -join ' ')] " + (Format-Result $r))
    }

    # ---------- FA: 사용자 없는 모듈은 별칭으로 판정한다 — 쓰이지 않음 분류는 없다(후속 F-A) ----------
    Test-Group 'FA' {
        $tag7 = "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 "
        $q7 = "modprobe -S $K7 --show-depends"
        # FA-1: 별칭 — 풀림(처음 풀리는 것에서 멈춘다) · 안 풀림 · glob뿐 · modinfo -F alias 실패 · 별칭 없음 · '-'로 시작하는 별칭 · 사용 수와 무관
        $am = @('a_res', 'a_unres', 'a_glob', 'a_fail', 'a_none', 'a_dash', 'a_count')
        $alA = @{
            'a_res'   = @('x-res-old', 'x-res', 'x-res-later')
            'a_unres' = @('x-unres', 'x-unres-2')
            'a_glob'  = @('cpu:type:*:feature:*0004*', 'pci:v00001AF4d*sv*sd*bc*sc*i*', 'acpi?:FOO0001', 'of:N[ab]')
            'a_fail'  = @('x-fail')
            'a_dash'  = @('-x-dash')
            'a_count' = @('x-count')
        }
        # 지도에는 glob 별칭 · 실패하는 모듈의 별칭 · '-' 별칭도 '풀린다'로 넣어 둔다 — 그것을 묻는 변이가 있으면 결과가 바뀐다. 그 답의 제공자
        #   new_<길이>(파일 new-<길이>.ko.zst)는 7.0에만 있고 그 별칭을 선언한다(R3-1 계승자 — 그런 변이가 계승자 확인에 가려지지 않게).
        $mpA = @{}; $alA7 = @{}
        foreach ($a in @('x-res', 'x-res-later', 'cpu:type:*:feature:*0004*', 'acpi?:FOO0001', 'x-fail', '-x-dash', 'x-count')) {
            $mpA[$a] = @("insmod /lib/modules/$K7/kernel/fake/new-$($a.Length).ko.zst")
            $pv = "new_$($a.Length)"; if (-not $alA7.ContainsKey($pv)) { $alA7[$pv] = @() }; $alA7[$pv] += $a
        }
        $p1 = @{ Loaded = @('wireguard', 'overlay') + $am; Lsmod = @{ 'a_count' = '5' }; Lacking = @{ $K7 = $am }; Aliases = @{ $K6 = $alA; $K7 = $alA7 }; Extra = @{ $K7 = @($alA7.Keys) }; AliasFail = @('a_fail'); Modprobe = @{ $K7 = $mpA } }
        $fx = New-Pinned $p1
        $r = Invoke-KT $fx @('status') -label 'FA-1'
        $mpCalls = @($r.calls | Where-Object { $_.StartsWith('modprobe ', [StringComparison]::Ordinal) })
        $globAsked = @($mpCalls | Where-Object { $_.Contains('*') -or $_.Contains('?') -or $_.Contains('[') })
        $line = "${tag7}missing-loaded-modules=5 (a_dash a_fail a_glob a_none a_unres) accounted=2 (a_count=x-count a_res=x-res) [newest]"
        Assert "FA-1: status over user-less modules missing by name in 7.0 -> `"$line`": a_res is replaced by its first alias that resolves (x-res-old asked first, x-res-later never), a_count too although its use count is 5; a_unres (no alias resolves), a_glob (only glob aliases -- never asked, though the map would resolve them), a_fail (modinfo -F alias fails), a_none (no aliases) and a_dash (an alias starting with '-' is not passed to modprobe) are missing; no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $globAsked.Count -eq 0 -and -not (Test-HasLine $mpCalls "$q7 x-fail") -and -not (Test-HasLine $mpCalls "$q7 -x-dash") -and -not (Test-HasLine $mpCalls "$q7 x-res-later") -and
            [array]::IndexOf($mpCalls, "$q7 x-res-old") -ge 0 -and [array]::IndexOf($mpCalls, "$q7 x-res-old") -lt [array]::IndexOf($mpCalls, "$q7 x-res") -and (Test-HasLine $r.calls "modinfo -k $K6 -F alias a_fail") -and $r.writes -eq 0
        ) ("glob aliases asked: [$($globAsked -join ' | ')] " + (Format-Result $r))
        $fx = New-Pinned $p1
        $r = Invoke-KT $fx @('trial', $K7) -label 'FA-2'
        $line = "FAIL modules: 5 of 9 loaded modules missing for ${K7}: a_dash a_fail a_glob a_none a_unres (rerun with --accept-missing-modules a_dash,a_fail,a_glob,a_none,a_unres to accept exactly these)"
        Assert "FA-2: trial on the same fixture -> exit 1, `"$line`", no write" ($r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx)) (Format-Result $r)
        # FA-3: 사용 수 0인 넷디바이스형 모듈(노드 lsmod 'wireguard 110592 0' — flannel-wg가 쓰는 중)이 대상에 없다 → 없음(예전 '쓰이지 않음'의 구멍)
        $p3 = @{ Lacking = @{ $K7 = @('wireguard') }; Aliases = @{ $K6 = @{ 'wireguard' = $AL6['wireguard'] } } }
        $fx = New-Pinned $p3
        $r = Invoke-KT $fx @('trial', $K7) -label 'FA-3a'
        $line = "FAIL modules: 1 of 4 loaded modules missing for ${K7}: wireguard (rerun with --accept-missing-modules wireguard to accept exactly these)"
        Assert "FA-3a: trial where wireguard is loaded with use count 0 and no users (as on the node) and 7.0 has neither the module nor its aliases (net-pf-16-proto-16-family-wireguard, rtnl-link-wireguard) -> missing: exit 1, `"$line`", both aliases asked, no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "$q7 net-pf-16-proto-16-family-wireguard") -and (Test-HasLine $r.calls "$q7 rtnl-link-wireguard") -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        # FA-3b: 7.0의 wg_next는 7.0에만 있고 wireguard의 별칭 둘을 선언한다(R3-1 계승자).
        $fx = New-Pinned @{ Lacking = $p3.Lacking; Aliases = @{ $K6 = $p3.Aliases[$K6]; $K7 = @{ 'wg_next' = $AL6['wireguard'] } }; Extra = @{ $K7 = @('wg_next') }; Modprobe = @{ $K7 = @{ 'rtnl-link-wireguard' = @("insmod /lib/modules/$K7/kernel/drivers/net/wg-next/wg_next.ko.zst") } } }
        $r = Invoke-KT $fx @('trial', $K7) -label 'FA-3b'
        $line = "OK modules: 1 of 4 loaded modules not found by name in ${K7}; all accounted for: wireguard=rtnl-link-wireguard"
        Assert "FA-3b: control -- the same, but 7.0 provides the function under another module name (its alias rtnl-link-wireguard resolves to wg_next, new in 7.0 and declaring it) -> replaced: exit 0, `"$line`", next_entry set (one write)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 1 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7))
        ) (Format-Result $r)
        # FA-4(R3-5 준수 리뷰 — 실제 kmod 31의 답 모양 셋): install로 막힌 모듈(exit 0 · insmod + 'install /bin/false') · 블랙리스트된 별칭(exit 0 · 빈 줄) ·
        #   내장('builtin aes'). R3-1 뒤에는 내장 aes가 7.0에서 x-bi를 선언하고 6.17에는 그 이름이 없어야(계승자) c_bi가 대체됨으로 남는다.
        $amC = @('c_bi', 'c_bl', 'c_inst')
        $alC = @{ 'c_inst' = @('x-inst'); 'c_bl' = @('x-bl'); 'c_bi' = @('x-bi') }
        $mpC = @{ 'x-inst' = @("insmod /lib/modules/$K7/kernel/lib/crypto/libblake2b.ko.zst", 'install /bin/false'); 'x-bl' = @(''); 'x-bi' = @('builtin aes') }
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $amC; Lacking = @{ $K7 = $amC }; Aliases = @{ $K6 = $alC; $K7 = @{ 'aes' = @('x-bi') } }; Extra = @{ $K7 = @('aes') }; Modprobe = @{ $K7 = $mpC } }
        $r = Invoke-KT $fx @('status') -label 'FA-4'
        $line = "${tag7}missing-loaded-modules=2 (c_bl c_inst) accounted=1 (c_bi=x-bi) [newest]"
        Assert "FA-4 (x): status over user-less modules whose only alias answers like real kmod 31 does for an install-disabled module (exit 0, insmod + 'install /bin/false'), a blacklisted alias (exit 0, empty line) and a builtin ('builtin aes' -- aes declares x-bi on $K7 and has no name on ${K6}: a successor) -> `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        # FA-4b: 같은 모양에서 내장 aes가 6.17에도 있고 x-bi를 이미 선언했다 → 형제(계승자가 아니다) → c_bi도 없음
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $amC; Lacking = @{ $K7 = $amC }; Aliases = @{ $K6 = $alC + @{ 'aes' = @('x-bi') }; $K7 = @{ 'aes' = @('x-bi') } }; Extra = @{ $K6 = @('aes'); $K7 = @('aes') }; Modprobe = @{ $K7 = $mpC } }
        $r = Invoke-KT $fx @('status') -label 'FA-4b'
        $line = "${tag7}missing-loaded-modules=3 (c_bi c_bl c_inst) accounted=0 [newest]"
        Assert "FA-4b (x): the same, but the builtin aes is on $K6 as well and already declared x-bi there (a sibling, not a successor) -> c_bi is missing too: `"$line`", the sibling check asked modinfo -k $K6 -F name aes and -F alias aes, no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "modinfo -k $K6 -F name aes") -and (Test-HasLine $r.calls "modinfo -k $K6 -F alias aes") -and $r.writes -eq 0
        ) (Format-Result $r)
        # FA-4c: 이상한 답(insmod 줄 + 'install /bin/false')에 계승자(inst_new — 7.0에만 있고 x-inst를 선언)가 섞여 있어도 MPQ=ok가 아니면 세지 않는다
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay', 'c_inst'); Lacking = @{ $K7 = @('c_inst') }; Aliases = @{ $K6 = @{ 'c_inst' = @('x-inst') }; $K7 = @{ 'inst_new' = @('x-inst') } }; Extra = @{ $K7 = @('inst_new') }; Modprobe = @{ $K7 = @{ 'x-inst' = @("insmod /lib/modules/$K7/kernel/fake/inst_new.ko.zst", 'install /bin/false') } } }
        $r = Invoke-KT $fx @('status') -label 'FA-4c'
        $line = "${tag7}missing-loaded-modules=1 (c_inst) accounted=0 [newest]"
        Assert "FA-4c (x): status where c_inst's only alias x-inst answers exit 0 with an insmod line of inst_new (new in $K7 and declaring x-inst) and an 'install /bin/false' line -> not a trusted answer, so the successor in it does not count: `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        # FA-4d: 답의 제공자 mf_new에 대한 modinfo -k 7.0 -F alias가 실패한다 → 선언을 확인할 수 없다 → 계승자가 아니다 → 없음
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay', 'c_mf'); Lacking = @{ $K7 = @('c_mf') }; Aliases = @{ $K6 = @{ 'c_mf' = @('x-mf') }; $K7 = @{ 'mf_new' = @('x-mf') } }; Extra = @{ $K7 = @('mf_new') }; AliasFail = @('mf_new'); Modprobe = @{ $K7 = @{ 'x-mf' = @("insmod /lib/modules/$K7/kernel/fake/mf_new.ko.zst") } } }
        $r = Invoke-KT $fx @('status') -label 'FA-4d'
        $line = "${tag7}missing-loaded-modules=1 (c_mf) accounted=0 [newest]"
        Assert "FA-4d (x): status where c_mf's alias x-mf resolves to mf_new but modinfo -k $K7 -F alias mf_new fails -> the declaration cannot be checked, not a successor: `"$line`", that modinfo asked, no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "modinfo -k $K7 -F alias mf_new") -and $r.writes -eq 0
        ) (Format-Result $r)
        # FA-4e(R3c F1 · 실제 kmod 리뷰): 제공자 aes가 지금 커널(6.17)에 '있지만' modinfo -k 6.17 -F name aes가 'not found'가 아닌 오류(kmod 31의
        #   "could not get modinfo from 'aes': Invalid argument" — 잘린 .ko.zst · 읽을 수 없는 modules.builtin.modinfo)로 실패한다 → 형제인지 알 수 없다 →
        #   계승자가 아니다(fail-closed) → c_bi도 없음. 3b는 빈 답을 '다른 이름의 모듈 = 새 모듈'로 읽어 c_bi=x-bi를 냈다(잘못된 통과). 대조군(not-found
        #   실패 → 새 모듈 → 대체됨)은 FA-4(aes가 6.17에 없다)와 FA-7(a)(n_new)가 다룬다.
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $amC; Lacking = @{ $K7 = $amC }; Aliases = @{ $K6 = $alC + @{ 'aes' = @('x-bi') }; $K7 = @{ 'aes' = @('x-bi') } }; Extra = @{ $K6 = @('aes'); $K7 = @('aes') }; Modprobe = @{ $K7 = $mpC }; ModinfoFail = @{ $K6 = @('aes') } }
        $r = Invoke-KT $fx @('status') -label 'FA-4e'
        $line = "${tag7}missing-loaded-modules=3 (c_bi c_bl c_inst) accounted=0 [newest]"
        Assert "FA-4e: the same as FA-4b, but modinfo -k $K6 -F name aes fails with kmod 31's 'could not get modinfo from' (a damaged running tree, not 'not found') -> whether aes is a sibling cannot be judged, so it is not a successor: `"$line`", modinfo -k $K6 -F name aes asked and -F alias aes not (the failure ends the check first), no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "modinfo -k $K6 -F name aes") -and -not (Test-HasLine $r.calls "modinfo -k $K6 -F alias aes") -and $r.writes -eq 0
        ) (Format-Result $r)
        # FA-4f (x — R3c 하네스 추가): 지금 커널의 -F name aes는 답하지만(같은 이름) -F alias aes가 실패한다 → 이미 x-bi를 선언하던 형제인지 알 수 없다 →
        #   계승자가 아니다(fail-closed; alias_successor의 지금 커널 쪽 -F alias 실패 분기) → c_bi 없음. 3b는 빈 답을 '선언하지 않았다'로 읽어 c_bi=x-bi를 냈다.
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $amC; Lacking = @{ $K7 = $amC }; Aliases = @{ $K6 = $alC + @{ 'aes' = @('x-bi') }; $K7 = @{ 'aes' = @('x-bi') } }; Extra = @{ $K6 = @('aes'); $K7 = @('aes') }; Modprobe = @{ $K7 = $mpC }; ModinfoAliasFail = @{ $K6 = @('aes') } }
        $r = Invoke-KT $fx @('status') -label 'FA-4f'
        Assert "FA-4f (x): the same as FA-4b, but modinfo -k $K6 -F alias aes fails (-F name aes answers 'aes') -> whether aes already declared x-bi there cannot be judged, so it is not a successor: `"$line`", modinfo -k $K6 -F name aes and -F alias aes asked, no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "modinfo -k $K6 -F name aes") -and (Test-HasLine $r.calls "modinfo -k $K6 -F alias aes") -and $r.writes -eq 0
        ) (Format-Result $r)
        # FA-5(R3-1 · 리뷰 F1): MODULE_ALIAS_CRYPTO가 함께 선언하는 맨 이름 별칭이 이름이 같은 다른 모듈로 풀린다. sm4_generic(6.17)의 실제 별칭 넷 가운데
        #   7.0 지도에는 맨 이름 'sm4'만 있다 — 실제 6.17 · 7.0에서 'sm4'는 SM4 라이브러리 모듈(kernel/crypto/sm4.ko.zst)이고 두 커널 모두 별칭이 없다
        #   (2026-10-07 실측; 실제 7.0에는 sm4_generic이 이름으로 있어 이 케이스는 그것이 빠진 커널을 흉내 낸다) → 계승자가 아니다 → 없음.
        $p5 = @{ Loaded = @('wireguard', 'overlay', 'sm4_generic'); Lacking = @{ $K7 = @('sm4_generic') }; Extra = @{ $K6 = @('sm4'); $K7 = @('sm4') }; Aliases = @{ $K6 = @{ 'sm4_generic' = @('crypto-sm4-generic', 'sm4-generic', 'crypto-sm4', 'sm4') } }; Modprobe = @{ $K7 = @{ 'sm4' = @("insmod /lib/modules/$K7/kernel/crypto/sm4.ko.zst") } } }
        $fx = New-Pinned $p5
        $r = Invoke-KT $fx @('trial', $K7) -label 'FA-5'
        $line = "FAIL modules: 1 of 3 loaded modules missing for ${K7}: sm4_generic (rerun with --accept-missing-modules sm4_generic to accept exactly these)"
        Assert "FA-5: trial where sm4_generic (no users; aliases crypto-sm4-generic, sm4-generic, crypto-sm4, sm4 on $K6) has no name in $K7 and only its bare alias sm4 resolves there -- to the SM4 library module sm4, which declares no alias -> not a successor: missing, exit 1, `"$line`", sm4 asked, modinfo -k $K7 -F alias sm4 asked (and no -F name sm4 on $K6), no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "$q7 sm4") -and (Test-HasLine $r.calls "modinfo -k $K7 -F alias sm4") -and -not (Test-HasLine $r.calls "modinfo -k $K6 -F name sm4") -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        # FA-5b: 같은 모양에서 7.0의 sm4가 'sm4'를 품은 다른 별칭(sm4-lib · crypto-sm4-lib)만 선언한다 → 선언은 줄 전체가 같을 때만 → 없음
        $p5b = $p5.Clone(); $p5b['Aliases'] = @{ $K6 = $p5.Aliases[$K6]; $K7 = @{ 'sm4' = @('sm4-lib', 'crypto-sm4-lib') } }
        $fx = New-Pinned $p5b
        $r = Invoke-KT $fx @('trial', $K7) -label 'FA-5b'
        Assert "FA-5b (x): the same, but $K7's sm4 declares only aliases that contain 'sm4' (sm4-lib, crypto-sm4-lib) -- a declaration is a whole line -> missing: exit 1, `"$line`", no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        # FA-6(R3-1 · 리뷰 F2): 지금 커널에 이미 있던 형제. ansi_cprng(6.17)의 실제 별칭 넷 가운데 crypto-stdrng · stdrng는 7.0에서 'builtin drbg'로 풀리고,
        #   drbg는 두 커널 모두 내장이며 둘 다 이미 선언한다(실측 — drbg의 별칭 38개 가운데 앞 넷만 둔다) → 계승자가 아니다 → 없음(X9.31은 7.0에 없다).
        $drbgAl = @('crypto-stdrng', 'stdrng', 'crypto-drbg_nopr_sha256', 'drbg_nopr_sha256')
        $p6 = @{ Loaded = @('wireguard', 'overlay', 'ansi_cprng'); Lacking = @{ $K7 = @('ansi_cprng') }; Extra = @{ $K6 = @('drbg'); $K7 = @('drbg') }; Aliases = @{ $K6 = @{ 'ansi_cprng' = @('crypto-ansi_cprng', 'ansi_cprng', 'crypto-stdrng', 'stdrng'); 'drbg' = $drbgAl }; $K7 = @{ 'drbg' = $drbgAl } }; Modprobe = @{ $K7 = @{ 'crypto-stdrng' = @('builtin drbg'); 'stdrng' = @('builtin drbg') } } }
        $fx = New-Pinned $p6
        $r = Invoke-KT $fx @('trial', $K7) -label 'FA-6'
        $line = "FAIL modules: 1 of 3 loaded modules missing for ${K7}: ansi_cprng (rerun with --accept-missing-modules ansi_cprng to accept exactly these)"
        Assert "FA-6: trial where ansi_cprng (no users) has no name in $K7 and its aliases crypto-stdrng and stdrng resolve there to the builtin drbg, which is builtin on $K6 as well and already declared both (a sibling, not a successor) -> missing: exit 1, `"$line`", both aliases asked, the sibling check asked modinfo -k $K6 -F name drbg and -F alias drbg, no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "$q7 crypto-stdrng") -and (Test-HasLine $r.calls "$q7 stdrng") -and (Test-HasLine $r.calls "modinfo -k $K6 -F name drbg") -and (Test-HasLine $r.calls "modinfo -k $K6 -F alias drbg") -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        # FA-6b (x): 같은 모양인데 지금 커널(6.17)의 drbg 조회가 '읽을 수 없음'으로 실패한다(modinfo -F name · -F alias exit 1 'could not get modinfo from' —
        #   손상된 지금 커널 트리; 'not found'가 아니다) — 형제인지 알 수 없으므로 계승자로 세지 않는다(fail-closed) → 없음.
        $p6b = $p6.Clone(); $p6b['ModinfoFail'] = @{ $K6 = @('drbg') }
        $fx = New-Pinned $p6b
        $r = Invoke-KT $fx @('trial', $K7) -label 'FA-6b'
        Assert "FA-6b (x): the same, but modinfo -k $K6 -F name drbg fails with 'could not get modinfo from' (a damaged running tree, not 'not found') -> the sibling cannot be judged, so it is not a successor: exit 1, `"$line`", modinfo -k $K6 -F name drbg asked, no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "modinfo -k $K6 -F name drbg") -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        # FA-7(R3-1): 계승자의 모양 — (a) 7.0에만 있는 새 모듈 n_new가 n-func를 선언 · (b) 6.17에도 같은 이름으로 있던 g_host가 g-func를 7.0에서 처음
        #   선언(합쳐진 계승자) · (c) 공유 별칭 — 실제 7.0 net-pf-40의 답 모양(공통 의존 모듈 사이에 제공자 셋: vsock vmw_vmci vmw_vsock_vmci_transport
        #   hv_vmbus vsock hv_sock vsock vmw_vsock_virtio_transport_common vsock_loopback)에서 제공자가 전부 형제(p_all → 없음)이거나 그 가운데 하나만
        #   계승자(p_one → 대체됨). 형제 하나는 파일 이름에 '-'가 있다(pf-tr-a.ko.zst — '_'로 읽어야 같은 이름의 형제로 알아본다).
        #   R3b F4: n-func의 insmod 줄에는 modprobe.d 옵션(fw=/lib/firmware/n-new.bin — '/'가 든 값)이 붙고, g_host의 6.17 별칭에는 g-func를 품은
        #   g-func-v1이 있다 — 경로 뒤 옵션 떼기와 형제의 선언 비교(줄 전체)를 검사한다. 기대 줄은 그대로다.
        # (변수 이름은 대소문자를 가리지 않는다 — $insPf · $insBus를 지도 $mpF와 겹치지 않게 둔다.)
        $insPf = "insmod /lib/modules/$K7/kernel/net/pf"
        $insBus = "insmod /lib/modules/$K7/kernel/drivers/pf"
        $pfShape = @("$insPf/pf_core.ko.zst", "$insBus/pf_bus_a.ko.zst", "$insPf/pf-tr-a.ko.zst", "$insBus/pf_bus_b.ko.zst", "$insPf/pf_core.ko.zst", "$insPf/pf_tr_b.ko.zst", "$insPf/pf_core.ko.zst", "$insPf/pf_common.ko.zst")
        $mpF = @{
            'n-func'    = @("insmod /lib/modules/$K7/kernel/fake/n_new.ko.zst fw=/lib/firmware/n-new.bin")
            'g-func'    = @("insmod /lib/modules/$K7/kernel/fake/g_host.ko.zst")
            'net-pf-77' = $pfShape + @("$insPf/pf_tr_c.ko.zst")
            'net-pf-78' = $pfShape + @("$insPf/pf_tr_new.ko.zst")
        }
        $sibF = @('pf_core', 'pf_bus_a', 'pf_bus_b', 'pf_common', 'pf_tr_a', 'pf_tr_b', 'pf_tr_c', 'g_host')
        $alF6 = @{ 'n_old' = @('n-func'); 'g_old' = @('g-func'); 'p_all' = @('net-pf-77'); 'p_one' = @('net-pf-78'); 'pf_tr_a' = @('net-pf-77', 'net-pf-78'); 'pf_tr_b' = @('net-pf-77', 'net-pf-78'); 'pf_tr_c' = @('net-pf-77'); 'g_host' = @('g-host', 'g-func-v1') }
        $alF7 = @{ 'n_new' = @('n-func'); 'pf_tr_a' = @('net-pf-77', 'net-pf-78'); 'pf_tr_b' = @('net-pf-77', 'net-pf-78'); 'pf_tr_c' = @('net-pf-77'); 'pf_tr_new' = @('net-pf-78'); 'g_host' = @('g-host', 'g-func') }
        $mF = @('n_old', 'g_old', 'p_all', 'p_one')
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $mF; Lacking = @{ $K7 = $mF }; Extra = @{ $K6 = $sibF; $K7 = $sibF + @('n_new', 'pf_tr_new') }; Aliases = @{ $K6 = $alF6; $K7 = $alF7 }; Modprobe = @{ $K7 = $mpF } }
        $r = Invoke-KT $fx @('status') -label 'FA-7'
        $line = "${tag7}missing-loaded-modules=1 (p_all) accounted=3 (g_old=g-func n_old=n-func p_one=net-pf-78) [newest]"
        $want7 = @("modinfo -k $K6 -F name n_new", "modinfo -k $K6 -F name g_host", "modinfo -k $K6 -F alias g_host", "modinfo -k $K6 -F name pf_tr_a", "modinfo -k $K6 -F alias pf_tr_c", "modinfo -k $K7 -F alias pf_tr_new", "modinfo -k $K6 -F name pf_tr_new")
        $miss7 = @($want7 | Where-Object { -not (Test-HasLine $r.calls $_) })
        Assert "FA-7: status over (a) n_old whose alias n-func resolves to n_new, new in $K7 and declaring it, (b) g_old whose alias g-func resolves to g_host, present on $K6 too but declaring g-func only on $K7 (a merged successor), (c) p_all and p_one whose shared alias resolves like net-pf-40 to common dependencies and three providers that were on $K6 and already declared it (p_all: all siblings), or two of them and pf_tr_new, new in $K7 (p_one) -> `"$line`"; the successor checks asked [$($want7 -join ', ')] and no -F alias n_new on $K6 (it has no name there); no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $miss7.Count -eq 0 -and -not (Test-HasLine $r.calls "modinfo -k $K6 -F alias n_new") -and $r.writes -eq 0
        ) ("not asked: [$($miss7 -join ' | ')] " + (Format-Result $r))
        # FA-8: 실제 aes_arm64(6.17 별칭 crypto-aes · aes) → 7.0의 내장 aes(별칭 crypto-aes-lib · aes-lib · crypto-aes · aes). 6.17에서 'aes'는
        #   모듈 이름이 아니라 aes_arm64의 별칭이라 -F name aes가 aes_arm64를 낸다(2026-10-07 실측) — 정확히 같은 한 줄이 아니므로 형제가 아니다 → 대체됨
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay', 'aes_arm64'); Lacking = @{ $K7 = @('aes_arm64') }; Aliases = @{ $K6 = @{ 'aes_arm64' = @('crypto-aes', 'aes') }; $K7 = @{ 'aes' = @('crypto-aes-lib', 'aes-lib', 'crypto-aes', 'aes') } }; Extra = @{ $K7 = @('aes') }; Modprobe = @{ $K7 = @{ 'crypto-aes' = @('builtin aes'); 'aes' = @('builtin aes') } } }
        $r = Invoke-KT $fx @('status') -label 'FA-8'
        $line = "${tag7}missing-loaded-modules=0 accounted=1 (aes_arm64=crypto-aes) [newest]"
        Assert "FA-8 (x): status where aes_arm64 (aliases crypto-aes, aes on $K6) has no name in $K7 and crypto-aes resolves to the builtin aes, whose name on $K6 is only aes_arm64's alias (-F name aes -> aes_arm64) -> not a same-named sibling: `"$line`", modinfo -k $K6 -F name aes asked and -F alias aes not, no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.calls "modinfo -k $K6 -F name aes") -and -not (Test-HasLine $r.calls "modinfo -k $K6 -F alias aes") -and $r.writes -eq 0
        ) (Format-Result $r)
    }

    # ---------- FB: 정확한 수용 옵션 --accept-missing-modules(후속 F-B) ----------
    Test-Group 'FB' {
        # 사용법 오류: exit 2 · usage 줄만 · RESULT FAIL usage · 가짜 명령 0회(K19와 같은 단언)
        $fx = New-Kt
        $both = 'FAIL usage: --accept-missing-modules and --ignore-missing-modules cannot be combined'
        $cases = @(
            @{ a = @('trial', $K7, '--accept-missing-modules'); line = 'FAIL usage: --accept-missing-modules needs a comma-separated list of module names' },
            @{ a = @('trial', $K7, '--accept-missing-modules', '--ignore-missing-modules'); line = 'FAIL usage: --accept-missing-modules needs a comma-separated list of module names' },
            @{ a = @('trial', $K7, '--accept-missing-modules', ''); line = 'FAIL usage: --accept-missing-modules got an empty list' },
            @{ a = @('trial', $K7, '--accept-missing-modules', 'polyval_ce,,foo'); line = "FAIL usage: --accept-missing-modules: empty name in 'polyval_ce,,foo'" },
            @{ a = @('trial', $K7, '--accept-missing-modules', 'polyval_ce,'); line = "FAIL usage: --accept-missing-modules: empty name in 'polyval_ce,'" },
            @{ a = @('trial', $K7, '--accept-missing-modules', 'polyval_ce,polyval_ce'); line = "FAIL usage: --accept-missing-modules: 'polyval_ce' listed twice" },
            @{ a = @('trial', $K7, '--accept-missing-modules', 'poly.val'); line = "FAIL usage: --accept-missing-modules: 'poly.val' is not a module name" },
            @{ a = @('trial', $K7, '--accept-missing-modules', 'a', '--accept-missing-modules', 'b'); line = 'FAIL usage: --accept-missing-modules given twice' },
            @{ a = @('trial', $K7, '--accept-missing-modules', 'polyval_ce', '--ignore-missing-modules'); line = $both },
            @{ a = @('trial', '--ignore-missing-modules', $K7, '--accept-missing-modules', 'polyval_ce'); line = $both }
        )
        foreach ($c in $cases) {
            $r = Invoke-KT $fx $c.a -label "FB-usage[$($c.a -join ' ')]"
            $other = @($r.lines | Where-Object { -not ($_.StartsWith('INFO note: ') -or $_.StartsWith('FAIL usage: ') -or $_.StartsWith('INFO usage: ') -or $_.StartsWith('RESULT: FAIL usage -- ')) })
            Assert "FB-usage: args [$($c.a -join ' ')] -> exit 2, `"$($c.line)`", only usage lines, RESULT FAIL usage, no fake command called at all" (
                $r.code -eq 2 -and (Test-HasLine $r.lines $c.line) -and $other.Count -eq 0 -and $r.calls.Count -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL usage -- ')
            ) (Format-Result $r)
        }
        # 판정: 계산한 '없음'과 준 목록이 사전순으로 정확히 같아야 진행한다
        $ls3 = $M1Lsmod.Clone(); $ls3['foo_drv'] = '2'; $ls3['foo_lib'] = '1 foo_drv'
        $p3 = @{ Loaded = $M1Loaded + @('foo_drv', 'foo_lib'); Lsmod = $ls3; Lacking = @{ $K7 = $M1Renamed + @('foo_lib') } }
        $cases = @(
            @{ n = 'FB-more: one name too many'; p = @{}; acc = 'blake2b_generic,polyval_ce'; line = "FAIL modules: 1 of 11 loaded modules missing for ${K7}: polyval_ce -- --accept-missing-modules differs: accepted but not missing: blake2b_generic" },
            @{ n = 'FB-fewer: one missing name not given'; p = $p3; acc = 'polyval_ce'; line = "FAIL modules: 2 of 13 loaded modules missing for ${K7}: foo_lib polyval_ce -- --accept-missing-modules differs: missing but not accepted: foo_lib" },
            @{ n = 'FB-typo: polyval-ce for polyval_ce'; p = @{}; acc = 'polyval-ce'; line = "FAIL modules: 1 of 11 loaded modules missing for ${K7}: polyval_ce -- --accept-missing-modules differs: missing but not accepted: polyval_ce; accepted but not missing: polyval-ce" },
            @{ n = 'FB-none: nothing is missing but a name is given'; p = @{ Lacking = @{ $K7 = @('aes_ce_cipher', 'libcurve25519_generic') } }; acc = 'polyval_ce'; line = "FAIL modules: 0 of 11 loaded modules missing for ${K7}: none -- --accept-missing-modules differs: accepted but not missing: polyval_ce" }
        )
        foreach ($c in $cases) {
            $fx = New-M1 $c.p
            $r = Invoke-KT $fx @('trial', $K7, '--accept-missing-modules', $c.acc) -label ($c.n -split ':')[0]
            Assert "$($c.n) (--accept-missing-modules $($c.acc)) -> exit 1, `"$($c.line)`", no write, RESULT FAIL trial -- refused: the missing modules for $K7 differ from --accept-missing-modules ..." (
                $r.code -eq 1 -and (Test-HasLine $r.lines $c.line) -and $r.writes -eq 0 -and $null -eq (Get-NextEntry $fx) -and (Test-LastPrefix $r "RESULT: FAIL trial -- refused: the missing modules for $K7 differ from --accept-missing-modules")
            ) (Format-Result $r)
        }
        $fx = New-M1 $p3
        $r = Invoke-KT $fx @('trial', $K7, '--accept-missing-modules', 'polyval_ce,foo_lib') -label 'FB-order'
        $line = "INFO modules: accepted exactly: foo_lib polyval_ce (2 of 13 loaded modules missing for $K7)"
        Assert "FB-order: the list in another order (polyval_ce,foo_lib) for the missing foo_lib and polyval_ce -> compared in sorted order: exit 0, `"$line`", next_entry set (one write)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and -not (Test-HasLinePrefix $r.lines 'FAIL modules: ') -and $r.writes -eq 1 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7))
        ) (Format-Result $r)
        # FB-ignore-none(R3-5 준수 리뷰): 아무것도 없을 때도 --ignore-missing-modules 안내 줄이 나온다
        $fx = New-Pinned
        $r = Invoke-KT $fx @('trial', $K7, '--ignore-missing-modules') -label 'FB-ignore-none'
        Assert "FB-ignore-none (x): --ignore-missing-modules when nothing is missing -> exit 0, `"$IGNORE_HINT`", `"OK modules: all 4 loaded modules exist for $K7`", one write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $IGNORE_HINT) -and (Test-HasLine $r.lines "OK modules: all 4 loaded modules exist for $K7") -and $r.writes -eq 1
        ) (Format-Result $r)
    }

    # ---------- FC: 부팅 목록을 넓힌다 — 명령 줄 modules_load= · rd.modules_load= · /etc/initramfs-tools/modules(후속 F-C) ----------
    Test-Group 'FC' {
        # 모든 b_* 모듈: 사용자 없음 · 7.0에 이름 없음 · 7.0에서 풀리는 별칭 'alias-<이름>' — 목록에 있는 것만 없음이 된다. 그 답의 제공자
        #   <이름>_new(파일 <이름>-new.ko.zst)는 7.0에만 있고 그 별칭을 선언한다(R3-1 계승자).
        $bm = @('b_cmd', 'b_rd', 'b_rdtwo', 'b_dashkey', 'b_quoted', 'b_irt', 'b_irtd', 'b_free')
        $alB = @{}; $mpB = @{}; $alB7 = @{}
        foreach ($x in $bm) { $alB[$x] = @("alias-$x"); $mpB["alias-$x"] = @("insmod /lib/modules/$K7/kernel/fake/$x-new.ko.zst"); $alB7["${x}_new"] = @("alias-$x") }
        $extra = ' modules_load=b_cmd rd.modules_load=b_rd,b-rdtwo modules-load=b_dashkey rd.modules_load="b_quoted" xmodules_load=b_free quiet'
        $irt = "# List of modules that you want to include in your initramfs.`n# They will be loaded at boot time in the order below.`n`nb_irt`n"
        # initramfs-tools-core 0.142ubuntu25.8 mkinitramfs 351–355: "${CONFDIR}/modules"와 /usr/share/initramfs-tools/modules.d/*를 함께 읽는다.
        $lists = @{ 'etc/initramfs-tools/modules' = $irt; 'usr/share/initramfs-tools/modules.d/zz-kt' = "# shipped by a package`nb_irtd`n" }
        $pB = @{ Loaded = @('wireguard', 'overlay') + $bm; Lacking = @{ $K7 = $bm }; Aliases = @{ $K6 = $alB; $K7 = $alB7 }; Extra = @{ $K7 = @($alB7.Keys) }; Modprobe = @{ $K7 = $mpB }; CmdlineExtra = $extra; BootLists = $lists }
        $fx = New-Pinned $pB
        $r = Invoke-KT $fx @('status') -label 'FC-1'
        $line = "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=7 (b_cmd b_dashkey b_irt b_irtd b_quoted b_rd b_rdtwo) accounted=1 (b_free=alias-b_free) [newest]"
        Assert "FC-1: status where the running kernel's command line has modules_load=b_cmd, rd.modules_load=b_rd,b-rdtwo, modules-load=b_dashkey (systemd treats - and _ in the key alike) and rd.modules_load=`"b_quoted`", /etc/initramfs-tools/modules lists b_irt and /usr/share/initramfs-tools/modules.d/zz-kt lists b_irtd -> those are missing although their aliases resolve; b_free (only in a token 'xmodules_load=') is replaced: `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-Pinned $pB
        $r = Invoke-KT $fx @('trial', $K7) -label 'FC-2'
        $line = "FAIL modules: 7 of 10 loaded modules missing for ${K7}: b_cmd b_dashkey b_irt b_irtd b_quoted b_rd b_rdtwo (rerun with --accept-missing-modules b_cmd,b_dashkey,b_irt,b_irtd,b_quoted,b_rd,b_rdtwo to accept exactly these)"
        Assert "FC-2: trial on the same fixture -> exit 1, `"$line`", no write" ($r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0) (Format-Result $r)
        # FC-3(R3-2): 낱말 전체가 큰따옴표인 명령 줄 키 — systemd(255.4-1ubuntu8.17 실측)는 낱말마다 따옴표를 먼저 벗긴 뒤 키를 나눈다:
        #   '"modules_load=x"'도 부팅 때 x를 적재한다. b_ctl은 목록에 없는 대조군(별칭으로 대체됨).
        $bq = @('b_wq', 'b_wq2', 'b_wq3', 'b_ctl')
        $alQ6 = @{}; $alQ7 = @{}; $mpQ = @{}
        foreach ($x in $bq) { $alQ6[$x] = @("alias-$x"); $alQ7["${x}_new"] = @("alias-$x"); $mpQ["alias-$x"] = @("insmod /lib/modules/$K7/kernel/fake/$x-new.ko.zst") }
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $bq; Lacking = @{ $K7 = $bq }; Aliases = @{ $K6 = $alQ6; $K7 = $alQ7 }; Extra = @{ $K7 = @($alQ7.Keys) }; Modprobe = @{ $K7 = $mpQ }; CmdlineExtra = ' "modules_load=b_wq" "rd.modules_load=b_wq2,b-wq3"' }
        $r = Invoke-KT $fx @('status') -label 'FC-3'
        $line = "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=3 (b_wq b_wq2 b_wq3) accounted=1 (b_ctl=alias-b_ctl) [newest]"
        Assert "FC-3: status where the command line has the whole words `"modules_load=b_wq`" and `"rd.modules_load=b_wq2,b-wq3`" in double quotes (systemd strips a word's quotes before it splits off the key) -> b_wq, b_wq2 and b_wq3 are missing although their aliases resolve; b_ctl (not listed) is replaced: `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        # FC-3b: 낱말 안의 다른 따옴표 — systemd 255.4-1ubuntu8.17은 'modules_load=b_qa,"b_qb"'의 b_qb와 "'modules_load=b_qc'"의 b_qc도 적재한다(2026-10-07 실측)
        $bq2 = @('b_qa', 'b_qb', 'b_qc', 'b_ctl2')
        $alQ26 = @{}; $alQ27 = @{}; $mpQ2 = @{}
        foreach ($x in $bq2) { $alQ26[$x] = @("alias-$x"); $alQ27["${x}_new"] = @("alias-$x"); $mpQ2["alias-$x"] = @("insmod /lib/modules/$K7/kernel/fake/$x-new.ko.zst") }
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $bq2; Lacking = @{ $K7 = $bq2 }; Aliases = @{ $K6 = $alQ26; $K7 = $alQ27 }; Extra = @{ $K7 = @($alQ27.Keys) }; Modprobe = @{ $K7 = $mpQ2 }; CmdlineExtra = ' modules_load=b_qa,"b_qb" ''modules_load=b_qc''' }
        $r = Invoke-KT $fx @('status') -label 'FC-3b'
        $line = "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=3 (b_qa b_qb b_qc) accounted=1 (b_ctl2=alias-b_ctl2) [newest]"
        Assert "FC-3b (x): status where the command line has modules_load=b_qa,`"b_qb`" and 'modules_load=b_qc' (systemd strips every quote of a word) -> b_qa, b_qb and b_qc are missing; b_ctl2 is replaced: `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        # FC-3c(R3c F2 · 실제 kmod 리뷰): 따옴표 안의 공백 — systemd(extract_first_word EXTRACT_UNQUOTE|EXTRACT_RELAX)는 따옴표 안의 공백에서 낱말을 나누지
        #   않으므로 'modules_load="b_qa b_qb",b_qc'는 한 낱말이고 쉼표 뒤의 b_qc를 적재한다('b_qa b_qb'는 모듈 이름이 아니라 적재에 실패한다 — 목록에 들지
        #   않으니 적재돼 있으면 별칭 경로로 간다 = 대조군). read -a는 따옴표 안의 공백에서 먼저 잘라 b_qc를 놓쳤다(3b). 함께: 탭으로 나뉜 낱말
        #   (modules_load=b_tab) · 작은따옴표 안의 공백("modules_load='b_sq x',b_sq2" → b_sq2) · 닫히지 않은 따옴표(줄 끝의 'modules_load=b_unc,"b_unc2' →
        #   둘 다; EXTRACT_RELAX는 줄 끝에서 닫는다). 2026-10-07 systemd-modules-load 255.4-1ubuntu8.17 실측 모양.
        $bq3 = @('b_qa', 'b_qb', 'b_qc', 'b_tab', 'b_sq', 'b_sq2', 'b_unc', 'b_unc2')
        $alQ36 = @{}; $alQ37 = @{}; $mpQ3 = @{}
        foreach ($x in $bq3) { $alQ36[$x] = @("alias-$x"); $alQ37["${x}_new"] = @("alias-$x"); $mpQ3["alias-$x"] = @("insmod /lib/modules/$K7/kernel/fake/$x-new.ko.zst") }
        $extra3 = ' modules_load="b_qa b_qb",b_qc' + "`t" + 'modules_load=b_tab' + " modules_load='b_sq x',b_sq2" + ' modules_load=b_unc,"b_unc2'
        $fx = New-Pinned @{ Loaded = @('wireguard', 'overlay') + $bq3; Lacking = @{ $K7 = $bq3 }; Aliases = @{ $K6 = $alQ36; $K7 = $alQ37 }; Extra = @{ $K7 = @($alQ37.Keys) }; Modprobe = @{ $K7 = $mpQ3 }; CmdlineExtra = $extra3 }
        $r = Invoke-KT $fx @('status') -label 'FC-3c'
        $line = "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=5 (b_qc b_sq2 b_tab b_unc b_unc2) accounted=3 (b_qa=alias-b_qa b_qb=alias-b_qb b_sq=alias-b_sq) [newest]"
        Assert "FC-3c: status where the command line has modules_load=`"b_qa b_qb`",b_qc, a tab before modules_load=b_tab, modules_load='b_sq x',b_sq2 and an unclosed modules_load=b_unc,`"b_unc2 at the end (systemd joins quoted blanks into the word and closes an unbalanced quote at the end of the line) -> b_qc, b_sq2, b_tab, b_unc and b_unc2 are listed and missing; 'b_qa b_qb' and 'b_sq x' are not module names, so b_qa, b_qb and b_sq are replaced through their aliases: `"$line`", no write" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
    }

    # ---------- L1: update-grub 직후에 패키지 작업을 다시 본다(재리뷰 ①) ----------
    Test-Group 'L1' {
        $v6 = Get-PinValue $K6
        $fx = New-Kt -PgrepPlan @('grub-mkconfig 3+ 5150 /bin/sh /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg')
        $r = Invoke-KT $fx @('pin') -label 'L1a'
        $line = "FAIL package activity: grub-mkconfig(5150) $PARTIAL"
        Assert "L1a: pin, grub-mkconfig absent at the guard and right before update-grub but present right after it (update-grub exit 0) -> exit 1, `"$line`", neither verified nor rolled back (no verify/rollback line, update-grub once), pin file written, grub.cfg default = the 6.17 value, RESULT FAIL pin -- package activity while update-grub ran ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'OK package activity: none right before update-grub') -and (Test-HasLine $r.lines 'OK update-grub: exit 0') -and (Test-HasLine $r.lines $line) -and
            -not (Test-HasLinePrefix $r.lines 'OK verify: ') -and -not (Test-HasLinePrefix $r.lines 'FAIL verify: ') -and -not (Test-HasLinePrefix $r.lines 'INFO rollback: ') -and
            $r.ug -eq 1 -and (Test-PinContent (Get-PinText $fx) $v6) -and (Test-Same (Get-CfgDefault $fx) $v6) -and (Test-LastPrefix $r 'RESULT: FAIL pin -- package activity while update-grub ran')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Running = $K7; PgrepPlan = @('dpkg 3+ 4242 /usr/bin/dpkg --configure -a') }
        $r = Invoke-KT $fx @('unpin') -label 'L1b'
        $line = "FAIL package activity: dpkg(4242) $PARTIAL"
        $asides = @(Get-ChildItem -LiteralPath (Join-Path $fx.Root 'etc/default/grub.d') -Force -Filter '.kernel-trial-pin.*')
        Assert "L1b: unpin, dpkg present right after update-grub (exit 0) -> exit 1, `"$line`", neither verified nor restored (no verify/restore line, update-grub once), `"OK cleanup: removed the set-aside pin file`", no pin file, no set-aside file, grub.cfg default 0, RESULT FAIL unpin -- package activity while update-grub ran ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and (Test-HasLine $r.lines 'OK cleanup: removed the set-aside pin file') -and -not (Test-HasLinePrefix $r.lines 'OK verify: ') -and -not (Test-HasLinePrefix $r.lines 'INFO restore: ') -and
            $r.ug -eq 1 -and $null -eq (Get-PinText $fx) -and $asides.Count -eq 0 -and (Test-Same (Get-CfgDefault $fx) '0') -and (Test-LastPrefix $r 'RESULT: FAIL unpin -- package activity while update-grub ran')
        ) (Format-Result $r)
        $fx = New-Kt -PgrepFail @('* 3+ 3 pgrep: cannot allocate memory')
        $r = Invoke-KT $fx @('pin') -label 'L1c'
        $line = "FAIL package activity: pgrep-failed(dpkg: exit 3: pgrep: cannot allocate memory) $PARTIAL"
        Assert "L1c: pin, pgrep fails right after update-grub (cannot judge = busy) -> exit 1, `"$line`", no rollback (update-grub once)" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.ug -eq 1 -and -not (Test-HasLinePrefix $r.lines 'INFO rollback: ')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Running = $K7 }
        $r = Invoke-KT $fx @('unpin') -label 'L1d'
        $okAfter = 'OK package activity: none right after update-grub'
        Assert "L1d: a normal unpin -> exit 0, `"$okAfter`" before `"OK verify: ...`", pgrep asked 18 times (6 names x 3)" (
            $r.code -eq 0 -and (Test-HasLine $r.lines $okAfter) -and $r.pg -eq 18 -and
            [array]::IndexOf($r.lines, $okAfter) -lt [array]::IndexOf($r.lines, "OK verify: grub.cfg default is `"0`" -> $K7")
        ) (Format-Result $r)
    }

    # ---------- L3: 수동 복구 안내가 없던 거부 상태(재리뷰 ③) — (a) 메뉴 항목 0개; (b) initrdfail/prev_entry는 F9의 기대 줄 ----------
    Test-Group 'L3' {
        $fx = New-Kt -EmptyMenu
        $r = Invoke-KT $fx @('status') -label 'L3a'
        $line = "FAIL pin: INCONSISTENT (grub.cfg default `"0`" does not resolve to one kernel entry: grub.cfg has no top-level item 0 -- $EMPTY_MENU_HINT)"
        Assert "L3a: status when grub.cfg has no menu entry at all (what an overlapping grub-mkconfig leaves), default 0, no pin -> exit 1, `"$line`", no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
        $fx = New-Kt -EmptyMenu
        $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('pin') -label 'L3b'
        $line = "FAIL menu ids: submenu gnulinux-advanced-* found 0 times in /boot/grub/grub.cfg (want exactly 1) -- $EMPTY_MENU_HINT"
        Assert "L3b: pin in that state -> exit 1, `"$line`", no pin file, grub.cfg unchanged, no write call, RESULT FAIL pin -- refused: grub.cfg has no kernel menu entry ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.writes -eq 0 -and
            (Test-LastPrefix $r 'RESULT: FAIL pin -- refused: grub.cfg has no kernel menu entry')
        ) (Format-Result $r)
        # L3c(R3-5 준수 리뷰): 고정된 항목만 사라지고 다른 커널 항목은 있다 → 빈 메뉴 안내를 붙이지 않는다
        $v6 = Get-PinValue $K6
        $fx = New-Kt -Pin $v6 -Default $v6 -DropEntry @($K6)
        $r = Invoke-KT $fx @('status') -label 'L3c'
        $line = "FAIL pin: INCONSISTENT (grub.cfg default `"$v6`" does not resolve to one kernel entry: id gnulinux-$K6-advanced-$UUID found 0 times (want exactly 1))"
        Assert "L3c (x): status when the pinned entry is gone but other kernel entries exist -> exit 1, `"$line`" (no empty-menu hint), no write" (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $r.writes -eq 0
        ) (Format-Result $r)
    }

    # ---------- L4: 종료 대기 도우미 예외는 명령 줄이 글자 그대로 같을 때만(재리뷰 ④) ----------
    Test-Group 'L4' {
        $refuse = " -- refusing to write; run status, wait until it shows 'package activity: none', then retry"
        $cases = @(
            @{ n = 'L4a: the helper command line plus one more argument'; a = "$UU_HELPER --debug" },
            @{ n = 'L4b: the same script under another path'; a = '/usr/bin/python3 /usr/local/share/unattended-upgrades/unattended-upgrade-shutdown --wait-for-signal' },
            @{ n = 'L4c: only a part of the helper command line (no --wait-for-signal)'; a = '/usr/bin/python3 /usr/share/unattended-upgrades/unattended-upgrade-shutdown' },
            @{ n = 'L4d: the helper command line inside a longer one'; a = "/bin/sh -c $UU_HELPER" }
        )
        $pidNo = 900
        foreach ($c in $cases) {
            $pidNo++
            $fx = New-Kt -PgrepPlan @("unattended-upgr * $pidNo $($c.a)")
            $r = Invoke-KT $fx @('pin') -label ($c.n -split ':')[0]
            $line = "FAIL package activity: unattended-upgr($pidNo)$refuse"
            Assert "$($c.n) [$($c.a)] -> package work: exit 1, `"$line`", no 'package activity ignored' line, no write call, no pin file" (
                $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and -not (Test-HasLinePrefix $r.lines 'INFO package activity ignored: ') -and $r.writes -eq 0 -and $null -eq (Get-PinText $fx)
            ) (Format-Result $r)
        }
    }

    # ---------- S: 정적 검사 + 꼬리 바이트 ----------
    Test-Group 'S' {
        $bytes = if (Test-Path -LiteralPath $scriptPath -PathType Leaf) { [IO.File]::ReadAllBytes($scriptPath) } else { $null }
        $hasBom = $null -ne $bytes -and $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $src = if ($null -ne $bytes) { [Text.UTF8Encoding]::new($false).GetString($bytes) } else { '' }
        $srcLines = @($src -split "`n")
        if ($null -eq $bytes) { Assert 'S1: bash -n passes' $false "missing script: $scriptPath" }
        else {
            $o = & $script:bash -n (ConvertTo-BashPath $scriptPath) 2>&1 | Out-String
            Assert "S1: bash -n passes ($script:bash)" ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE; $($o.Trim())"
        }
        Assert 'S2: the first line is exactly "#!/usr/bin/env bash"' ($null -ne $bytes -and (Test-Same $srcLines[0] '#!/usr/bin/env bash')) "first line: [$($srcLines[0])]"
        $trailing = @(for ($i = 0; $i -lt $srcLines.Count; $i++) { if ($srcLines[$i] -match '[ \t]+$') { $i + 1 } })
        Assert 'S3: no BOM, no CR, ends with LF, no trailing whitespace' ($null -ne $bytes -and -not $hasBom -and -not $src.Contains("`r") -and $src.EndsWith("`n") -and $trailing.Count -eq 0) "bom=$hasBom cr=$($src.Contains("`r")) trailing-ws lines: [$($trailing -join ',')]"
        $lastCode = @($srcLines | Where-Object { $_.Trim() -ne '' }) | Select-Object -Last 1
        Assert 'S4: the script ends with an explicit exit: last line is exactly main "$@" </dev/null; exit' ($null -ne $bytes -and (Test-Same $lastCode 'main "$@" </dev/null; exit')) "last line: [$lastCode]"
        $sp = Split-BashSource $src
        $forbidden = [ordered]@{
            'grub-reboot'                                = '(?<![\w./-])grub-reboot(?![\w-])'
            'reboot'                                     = '(?<![\w./-])reboot(?![\w-])'
            'shutdown'                                   = '(?<![\w./-])shutdown(?![\w-])'
            'apt / apt-get / apt-mark / aptitude / dpkg' = '(?<![\w./-])(apt|apt-get|apt-mark|aptitude|dpkg)(?![\w-])'
            'rm -r / rm -rf'                             = '(?<![\w./-])rm\s+(-[A-Za-z]*[rR][A-Za-z]*|--recursive)(?![\w-])'
            'x: poweroff / halt / kexec / systemctl'     = '(?<![\w./-])(poweroff|halt|kexec|systemctl)(?![\w-])'
            'x: grub-set-default / grub-mkconfig / grub-install' = '(?<![\w./-])(grub-set-default|grub-mkconfig|grub-install)(?![\w-])'
            'x: eval / awk system()'                     = '(?<![\w./-])eval(?![\w-])|system\('
        }
        $hits = @(foreach ($k in $forbidden.Keys) { if ([regex]::IsMatch($sp.Bare, $forbidden[$k])) { $k } })
        $hits += @(foreach ($k in @('grub-reboot', 'rm -rf', 'system(')) { if ($sp.Code.Contains($k)) { "literal $k in code" } })
        Assert 'S5: grub-reboot, reboot, shutdown, apt, rm -rf (and x: poweroff, halt, kexec, systemctl, dpkg, grub-set-default, grub-mkconfig, grub-install, eval, awk system()) do not occur as commands in the executable code (comments removed, quoted text blanked; the tokenizer must close every quote)' (
            $null -ne $bytes -and $sp.Ok -and $hits.Count -eq 0
        ) "tokenizer ok=$($sp.Ok); hits: [$($hits -join ' | ')]"
        Assert 'S6x: Korean (any non-ASCII) appears only in comments: the code with comments removed is ASCII' ($null -ne $bytes -and $sp.Ok -and -not [regex]::IsMatch($sp.Code, '[^\t\n\x20-\x7E]')) 'non-ASCII outside comments'
        $direct = @()
        if ([regex]::IsMatch($sp.Code, '>{1,2}\s*"?\$\{?(GRUB_CFG|GRUBENV|DEFAULT_GRUB)\b')) { $direct += 'redirect into GRUB_CFG/GRUBENV/DEFAULT_GRUB' }
        if ([regex]::IsMatch($sp.Code, '(?m)^[^\n]*(?<![\w-])(mv|cp|rm|install|ln|truncate|dd|tee)\b[^\n;|&]*\$\{?(GRUB_CFG|GRUBENV|DEFAULT_GRUB)\b')) { $direct += 'mv/cp/rm/install/ln/truncate/dd/tee on GRUB_CFG/GRUBENV/DEFAULT_GRUB' }
        if ([regex]::IsMatch($sp.Bare, '(?<![\w-])sed\s+(-[A-Za-z]*i|--in-place)')) { $direct += 'sed -i' }
        Assert 'S7x: no direct write to grub.cfg, grubenv or /etc/default/grub in the code (no redirect, mv/cp/rm/install/ln/truncate/dd/tee on them, no sed -i) -- update-grub and grub-editenv are the only writers' ($null -ne $bytes -and $sp.Ok -and $direct.Count -eq 0) "found: [$($direct -join ' | ')]"
        $trapAt = -1; $trapCount = 0; $emitAt = -1
        for ($i = 0; $i -lt $srcLines.Count; $i++) {
            if (Test-Same $srcLines[$i] "trap '' HUP PIPE") { $trapCount++; if ($trapAt -lt 0) { $trapAt = $i } }
            if ($emitAt -lt 0 -and $srcLines[$i].StartsWith('emit() {', [StringComparison]::Ordinal)) { $emitAt = $i }
        }
        Assert "S9x: F3 -- exactly one top-level line `"trap '' HUP PIPE`", before the output functions are defined (so before the first output line)" (
            $null -ne $bytes -and $trapCount -eq 1 -and $trapAt -ge 0 -and $emitAt -gt $trapAt
        ) "trap lines: $trapCount (first at line $($trapAt + 1)), emit() at line $($emitAt + 1)"
        $fx = New-Kt
        $r = Invoke-KT $fx @('status') "`r`necho TRAILER-RAN`nexit 42`n" -label 'S8x-trailer'
        Assert 'S8x: bytes after the final exit line are never run (stdin = script + CRLF + "echo TRAILER-RAN" + "exit 42") -> status exit 0, no TRAILER-RAN in the output' (
            $r.code -eq 0 -and -not $r.out.Contains('TRAILER-RAN') -and (Test-LastPrefix $r 'RESULT: OK status -- ')
        ) (Format-Result $r)
    }

    # ---------- S-runs: 모든 실행의 출력 · 부작용 ----------
    if ($script:runs.Count -gt 0) {
        $nonAscii = @(); $stderrRuns = @(); $frame = @(); $format = @(); $trips = @()
        foreach ($run in $script:runs) {
            $raw = [Text.Encoding]::Latin1.GetString($run.outBytes) + [Text.Encoding]::Latin1.GetString($run.errBytes)
            if ([regex]::IsMatch($raw, '[^\n\x20-\x7E]')) { $nonAscii += $run.label }
            if ($run.trip -gt 0) { $trips += "$($run.label): $($run.calls -join ' ; ')" }
            # 출력이 닫힌 실행(F3)은 stdout이 없고 stderr에 'Broken pipe'가 남는 것이 정상이다 — 아래 세 검사에서 뺀다.
            if ($run.closed) { continue }
            if ($run.errBytes.Length -gt 0) { $stderrRuns += "$($run.label): $($run.err.Trim())" }
            $first = if ($run.lines.Count -gt 0) { $run.lines[0] } else { '' }
            $last = if ($run.lines.Count -gt 0) { $run.lines[$run.lines.Count - 1] } else { '' }
            $want = if ($last.StartsWith('RESULT: OK ', [StringComparison]::Ordinal)) { 0 } elseif ($last.StartsWith('RESULT: FAIL usage -- ', [StringComparison]::Ordinal)) { 2 } elseif ($last.StartsWith('RESULT: FAIL ', [StringComparison]::Ordinal)) { 1 } else { -1 }
            if (-not (Test-Same $first "INFO note: KT_ROOT=$($run.root) (test root)") -or $want -lt 0 -or $want -ne $run.code) { $frame += "$($run.label) [exit=$($run.code)] first=[$first] last=[$last]" }
            for ($i = 1; $i -lt $run.lines.Count; $i++) {
                $l = $run.lines[$i]
                $okLine = if ($i -eq $run.lines.Count - 1) { [regex]::IsMatch($l, '^RESULT: (OK|FAIL) [a-z-]+ -- \S') } else { [regex]::IsMatch($l, '^(OK|FAIL|INFO) [^:]+: \S') }
                if (-not $okLine) { $format += "$($run.label): [$l]"; break }
            }
        }
        $n = $script:runs.Count
        # 스크립트가 없어서 실행되지 않은 run이 하나라도 있으면 아래 단언은 전부 FAIL이다(출력이 없어 "위반 없음"이 공허하게 참이 되는 것을 막는다).
        $missingRuns = @($script:runs | Where-Object { $_.missing }).Count
        $why = if ($missingRuns -gt 0) { "$missingRuns of $n runs had no script to execute; " } else { '' }
        Assert "S: every output byte of every run ($n runs, stdout + stderr) is printable ASCII or LF" ($missingRuns -eq 0 -and $nonAscii.Count -eq 0) "${why}runs: [$($nonAscii -join ', ')]"
        $nOpen = @($script:runs | Where-Object { -not $_.closed }).Count
        Assert "S-runs x: stderr is empty in every run with an open stdout ($nOpen of $n runs) -- tool output is captured and re-printed as INFO lines" ($missingRuns -eq 0 -and $stderrRuns.Count -eq 0) "${why}[$($stderrRuns -join ' | ')]"
        Assert "S-runs x: every run with an open stdout starts with 'INFO note: KT_ROOT=<fixture root> (test root)' and ends with a RESULT line whose OK/FAIL/usage matches the exit code 0/1/2 ($nOpen of $n runs)" ($missingRuns -eq 0 -and $frame.Count -eq 0) "${why}[$($frame -join ' | ')]"
        Assert "S-runs x: every other line is 'OK|FAIL|INFO <topic>: <text>' ($nOpen of $n runs)" ($missingRuns -eq 0 -and $format.Count -eq 0) "${why}[$($format -join ' | ')]"
        Assert "S-runs x: across all runs the fake root changed only in the pin file, in grub.cfg as written by update-grub and in grubenv as written by grub-editenv (no leftover temp file, no kernel file removed, /etc/default/grub and 50-cloudimg-settings.cfg untouched)" ($missingRuns -eq 0 -and $script:blast.Count -eq 0) "${why}[$($script:blast -join ' | ')]"
        Assert "S-runs x: no tripwire command (reboot, shutdown, poweroff, halt, kexec, grub-reboot, grub-set-default, grub-mkconfig, grub-install, apt, apt-get, dpkg, systemctl) was called in any run" ($missingRuns -eq 0 -and $trips.Count -eq 0) "${why}[$($trips -join ' | ')]"
        if ($script:only.Count -eq 0) { Assert "S-runs x: the full suite executed the script at least 60 times (executed $($n - $missingRuns) of $n)" (($n - $missingRuns) -ge 60) "${why}runs: $n" }
    }
} finally {
    foreach ($f in $script:fixtures) { if ($f -and (Split-Path -Leaf $f) -like 'kt-*') { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue } }
}

$suffix = ''
if ($script:only.Count -gt 0) { $suffix += " (filtered: $($script:only -join ','))" }
if ($scriptOverride) { $suffix += ' (script override)' }
Write-Host ("`nelapsed: {0:N1} s, script runs: {1}" -f $sw.Elapsed.TotalSeconds, $script:runs.Count)
Write-Host "$($script:pass) passed, $($script:fail) failed$suffix"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
