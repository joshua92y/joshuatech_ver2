# infra/bootstrap/kernel-trial.sh 테스트(T048 커널 시험 부팅 도구). Run: pwsh -NoProfile -File tests/infra/kernel-trial.tests.ps1
# Exit 0 = all pass(또는 bash 없음 SKIP), 1 = failures. 외부 테스트 프레임워크 없음(tests/scripts/kubeconform-deploy.tests.ps1와 같은 구조).
#
# 방식: 스크립트를 Git/POSIX bash로 "실제로" 실행한다 — 운영자와 같은 표준 입력 실행(bash -s -- <하위 명령>; 스크립트 바이트 뒤에
#   PowerShell 파이프처럼 CRLF를 붙인다). 경로는 전부 가짜 루트(KT_ROOT = 임시 픽스처의 root/, C:/... 형태)이고, 외부 명령은
#   공용 가짜 bin/이 PATH 맨 앞에서 가린다: uname · id · update-grub · grub-editenv · lsmod · modinfo · dmesg · apt-config · pgrep.
#   가짜는 상태를 가진다(KT_FAKE_STATE = 픽스처의 state/): update-grub은 가짜 루트의 /etc/default/grub과 grub.d/*.cfg를 이름 순으로
#   읽어 GRUB_DEFAULT를 구하고 grub.cfg를 픽스처 템플릿에서 다시 만든다(모드 ok · fail · noop · wrong · dup-ids · alt(다른 템플릿) · fail-leave-new —
#   호출마다 차례로, 마지막 모드가 반복. state/update-grub.utf8이 있으면 그 비ASCII 줄도 낸다), grub-editenv는 1024바이트 환경 블록을
#   list · set · unset 한다(모드 낱말을 겹쳐 쓴다: ok · set-noop · set-wrong · unset-noop), lsmod · modinfo -k는 커널별 모듈 목록 파일을
#   본다, pgrep(-a -x NAME만)은 이름별 호출 횟수를 세어 state/pgrep.plan의 "NAME 호출 PID ARGS" 줄(호출 = * | N | N+)을 프로세스로
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
#   KERNEL_TRIAL_TESTS_ONLY  쉼표로 구분한 그룹 이름(K1 ... K20, F1 F2 F3 F6 F9 F10, S) — 그 그룹만 돈다. 요약 줄에 ' (filtered: ...)'가 붙는다.
# 단언 이름의 K1–K20 · S는 지시서(T048 kernel-trial)의 케이스 번호, F1–F10은 리뷰 반영 지시서(kernel-trial-fix)의 항목 번호다
#   (F1 패키지 작업 · F2 set partuuid= · F3 출력이 닫혀도 끝까지 + 잔여 파일 + 수동 복구 줄 · F6 복구용 커널 · F9 initrdfail/prev_entry ·
#   F10 테스트의 빈 곳). 'x'가 붙은 것(예: K4x-transient)과 S-runs는 지시서 밖에서 더한 단언이다.
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
    param([string[]]$Kernels, [switch]$NoNextEntryLogic, [switch]$NoSubmenu, [string[]]$DupEntry = @(), [string[]]$DropEntry = @(), [int]$Partuuid = 0)
    $sb = [Text.StringBuilder]::new()
    [void]$sb.Append($cfgHead)
    [void]$sb.Append($(if ($NoNextEntryLogic) { $cfgPlainDefault } else { $cfgNextEntry }))
    [void]$sb.Append($cfgMiddle)
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
        $have = @($Loaded | Where-Object { -not ($Lacking.ContainsKey($k) -and $Lacking[$k] -contains $_) }) + @('ext4', 'xfs')
        Write-Text "$state/modules-$k" (($have -join "`n") + "`n")
    }
    $tmpl = New-GrubCfgText -Kernels $Kernels -NoNextEntryLogic:$NoNextEntryLogic -NoSubmenu:$NoSubmenu -DupEntry $DupEntry -DropEntry $DropEntry -Partuuid $Partuuid
    Write-Text "$state/grub.cfg.tmpl" $tmpl
    if ($AltKernels.Count -gt 0) { Write-Text "$state/grub.cfg.tmpl.alt" (New-GrubCfgText -Kernels $AltKernels -Partuuid $Partuuid) }
    Write-Text "$root/boot/grub/grub.cfg" $tmpl.Replace('@DEFAULT@', $Default)
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
    Write-Text "$state/lsmod" (($Loaded -join "`n") + "`n")
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
function Invoke-KT($fx, [string[]]$cmdArgs = @(), [string]$trailer = "`r`n", [string]$label = '', [switch]$CloseStdout) {
    $script:runNo++
    if (-not $label) { $label = "$($script:group)#$($script:runNo)" }
    $res = [pscustomobject]@{ label = $label; root = $fx.RootPosix; missing = $false; closed = [bool]$CloseStdout; code = 127; out = ''; err = ''; lines = [string[]]@(); calls = [string[]]@(); ug = 0; set = 0; unset = 0; pg = 0; trip = 0; writes = 0; outBytes = [byte[]]@(); errBytes = [byte[]]@() }
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
    $psi.Environment['PATH'] = $script:childPath
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
# fake lsmod (kernel-trial harness): header + one line per module in $KT_FAKE_STATE/lsmod
printf 'lsmod %s\n' "$*" >> "$KT_FAKE_STATE/calls.log"
echo "Module                  Size  Used by"
while IFS= read -r m || [ -n "$m" ]; do
  [ -n "$m" ] && printf '%-24s %6s  0\n' "$m" 16384
done < "$KT_FAKE_STATE/lsmod"
exit 0
'@
$fakeFiles['modinfo'] = @'
#!/bin/sh
# fake modinfo (kernel-trial harness): "modinfo -k KVER MODULE" succeeds iff MODULE is listed in $KT_FAKE_STATE/modules-KVER
printf 'modinfo %s\n' "$*" >> "$KT_FAKE_STATE/calls.log"
if [ "$#" -ne 3 ] || [ "$1" != "-k" ]; then echo "fake modinfo: usage: modinfo -k KVER MODULE" >&2; exit 2; fi
f="$KT_FAKE_STATE/modules-$2"
if [ -f "$f" ]; then
  while IFS= read -r m || [ -n "$m" ]; do
    if [ "$m" = "$3" ]; then echo "filename:       /lib/modules/$2/kernel/fake/$3.ko"; exit 0; fi
  done < "$f"
fi
echo "modinfo: ERROR: Module $3 not found." >&2
exit 1
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
    $sep = [IO.Path]::PathSeparator
    $script:childPath = if ($IsWindows) { $script:binDir + $sep + $script:bashDir + $sep + $env:PATH } else { $script:binDir + $sep + $env:PATH }

    # ---------- setup: PATH 우선순위 탐침(실패하면 아무 케이스도 돌리지 않는다) ----------
    $probeNames = @('uname', 'id', 'update-grub', 'grub-editenv', 'lsmod', 'modinfo', 'dmesg', 'apt-config', 'pgrep') + $tripwireNames
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
            "INFO kernel ${K6}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 [running]",
            "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 [newest]",
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
        $guards = @("OK initrdless-boot fallback: off (no 'set partuuid=' in grub.cfg)", 'OK initrd fallback: grubenv initrdfail and prev_entry are empty', 'OK package activity: none', 'OK package activity: none right before update-grub')
        $missing = @($guards | Where-Object { -not (Test-HasLine $r.lines $_) })
        Assert 'K2x-guards: the normal pin passes the new guards in the open: F2 initrd-less boot fallback off, F9 initrdfail/prev_entry empty, F1 package activity none (guard) and none right before update-grub (pgrep asked 12 times = 6 names x 2)' (
            $missing.Count -eq 0 -and $r.pg -eq 12
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
        $lack = @{ Lacking = @{ $K7 = @('wireguard') } }
        $fx = New-Pinned $lack
        $r = Invoke-KT $fx @('trial', $K7) -label 'K11a'
        Assert 'K11a: one loaded module (wireguard) is not available for 7.0 -> exit 1, "FAIL modules: 1 of 4 loaded modules missing for 7.0.0-1012-oracle: wireguard (rerun with --ignore-missing-modules to accept)", set not called, no next_entry' (
            $r.code -eq 1 -and (Test-HasLine $r.lines "FAIL modules: 1 of 4 loaded modules missing for ${K7}: wireguard (rerun with --ignore-missing-modules to accept)") -and $r.set -eq 0 -and $null -eq (Get-NextEntry $fx)
        ) (Format-Result $r)
        $r = Invoke-KT $fx @('trial', $K7, '--ignore-missing-modules') -label 'K11b'
        Assert 'K11b: the same with --ignore-missing-modules -> exit 0, "INFO modules: 1 of 4 loaded modules missing for 7.0.0-1012-oracle: wireguard (accepted: --ignore-missing-modules)", next_entry set to the 7.0 value' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO modules: 1 of 4 loaded modules missing for ${K7}: wireguard (accepted: --ignore-missing-modules)") -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7)) -and $r.set -eq 1
        ) (Format-Result $r)
        $fx = New-Pinned $lack
        $r = Invoke-KT $fx @('trial', '--ignore-missing-modules', $K7) -label 'K11x-order'
        Assert 'K11x-order: the option may come before the version -> exit 0, next_entry set' ($r.code -eq 0 -and (Test-Same (Get-NextEntry $fx) (Get-PinValue $K7))) (Format-Result $r)
        $fx = New-Pinned $lack
        $r = Invoke-KT $fx @('status') -label 'K11x-status'
        Assert 'K11x-status: status names the module missing for 7.0: "... missing-loaded-modules=1 (wireguard) [newest]"' (
            $r.code -eq 0 -and (Test-HasLine $r.lines "INFO kernel ${K7}: vmlinuz=yes initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=1 (wireguard) [newest]")
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
        Assert 'F1j: pin, grub-mkconfig absent at the guard but present right before update-grub -> exit 1, "OK package activity: none", "FAIL package activity: grub-mkconfig(5150) appeared right before update-grub -- update-grub not run", "OK undo: pin file removed again; grub.cfg untouched", no pin file, grub.cfg byte-identical, update-grub not called, RESULT FAIL pin -- refused: package activity right before update-grub ...' (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'OK package activity: none') -and (Test-HasLine $r.lines 'FAIL package activity: grub-mkconfig(5150) appeared right before update-grub -- update-grub not run') -and
            (Test-HasLine $r.lines 'OK undo: pin file removed again; grub.cfg untouched') -and $null -eq (Get-PinText $fx) -and (Test-Same (Get-CfgHash $fx) $cfgHash) -and $r.ug -eq 0 -and
            (Test-LastPrefix $r 'RESULT: FAIL pin -- refused: package activity right before update-grub')
        ) (Format-Result $r)
        $fx = New-Pinned @{ Running = $K7; PgrepPlan = @('dpkg 2+ 4242 /usr/bin/dpkg --configure -a') }
        $pinHash = Get-PinHash $fx; $cfgHash = Get-CfgHash $fx
        $r = Invoke-KT $fx @('unpin') -label 'F1k'
        Assert 'F1k: unpin, dpkg absent at the guard but present right before update-grub -> exit 1, "FAIL package activity: dpkg(4242) appeared right before update-grub -- update-grub not run", "OK undo: pin file moved back; grub.cfg untouched", pin file and grub.cfg byte-identical, update-grub not called (no set-aside file left: S-runs)' (
            $r.code -eq 1 -and (Test-HasLine $r.lines 'FAIL package activity: dpkg(4242) appeared right before update-grub -- update-grub not run') -and (Test-HasLine $r.lines 'OK undo: pin file moved back; grub.cfg untouched') -and
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
            @{ n = 'F6g: status, the pinned kernel''s vmlinuz is empty'; p = @{ EmptyVmlinuz = @($K6) }; line = "FAIL pin: INCONSISTENT (pinned kernel ${K6}: empty /boot/vmlinuz-$K6)"; more = "INFO kernel ${K6}: vmlinuz=empty initrd=yes modules-dir=yes menu-entry-ids=1 missing-loaded-modules=0 [running]" }
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
        $tail = " (GRUB's initrd-less boot fallback may override the next boot shown here))"
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
        $line = 'FAIL initrd fallback: grubenv initrdfail="1" prev_entry="" -- GRUB''s initrd-less boot fallback may override the next boot; pin/trial refuse while either is set'
        Assert "F9d: pin with grubenv initrdfail=1 -> exit 1, `"$line`", no pin file, no write call, RESULT FAIL pin -- refused: grubenv holds initrdfail/prev_entry ..." (
            $r.code -eq 1 -and (Test-HasLine $r.lines $line) -and $null -eq (Get-PinText $fx) -and $r.writes -eq 0 -and (Test-LastPrefix $r 'RESULT: FAIL pin -- refused: grubenv holds initrdfail/prev_entry')
        ) (Format-Result $r)
        $fx = New-Pinned @{ EnvVars = @("prev_entry=$v7") }
        $r = Invoke-KT $fx @('trial', $K7) -label 'F9e'
        $line = "FAIL initrd fallback: grubenv initrdfail=`"`" prev_entry=`"$v7`" -- GRUB's initrd-less boot fallback may override the next boot; pin/trial refuse while either is set"
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
