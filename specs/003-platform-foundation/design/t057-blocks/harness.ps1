param([string]$Show = '', [string]$Block = '', [string]$Runbook = '')
# ===== T057 OP1-DRAGONFLY 시드 블록(op1-seed-dragonfly.ps1) + 런북 「정리 판단」 두 블록(① 점검 · ② 삭제) — 모의 실행 하네스 =====
# 선례: T056 하네스(../t056-blocks/harness.ps1 — 시나리오 100 · 단언 2608 · T054 하네스의 파생)의 파생이다. 가드 · 모의(vault · Read-Host · Set-Clipboard · Get-ItemProperty …) ·
#   공통 사후 조건 · S12 정적 관문 · 런북 블록 추출(R1 · R2 → GA · GB) · 과도 상태 모의는 그대로이고, 경로(7) · 키 집합(1/2/1) · url · acl 렌더 · live 판정 규칙(B3) · 의존(B4) ·
#   쌍 판정(B5)에 맞춰 계약 상수 · 독립 구현(Url-For · Acl-For · Hex-Lower · 로더 모의 Test-AclLoader) · 노출 바늘(url · users.acl 의 hex) · tamper 모드(url · aclCrlf) ·
#   S12 정적 추가(acl 렌더 규칙 — B8) · 렌더 단위 시험(U01–U04) · 시나리오를 고쳤다(README §4).
# 실물 Vault·클러스터에 닿지 않는다. 가드:
#   ⓪ S12 정적 검사를 맨 먼저 돌린다(블록을 실행하지 않는다) — 관문(파서 오류 0 · 명령 · 정적 형식 · $Host · 파일 리다이렉트 허용 목록)이 하나라도 FAIL 이면
#      런타임 시나리오를 하나도 돌리지 않고 exit 1(①②는 절대 경로 호출 · 프로세스 직접 기동을 막지 못한다 — T054 리뷰 O8)
#   ① PowerShell 함수가 native 명령보다 우선하는 성질로 vault·kubectl(+ vault.exe·kubectl.exe·curl·curl.exe·oci·gh)을 모의 함수로 가린다
#   ② 실물 vault·kubectl 이 있는 디렉터리를 이 프로세스 PATH 에서 빼고 맨 앞에 함정 디렉터리(vault.cmd·kubectl.cmd — 불리면 표식 파일 + exit 97)를 둔다 ·
#      이 프로세스의 KUBECONFIG 를 없는 경로로 덮는다(운영자의 관리자 kubeconfig 를 상속하지 않는다 — 끝나면 복원)
#   ③ 블록을 돌리기 직전마다 ①②를 다시 확인하고(아니면 블록을 돌리지 않고 중단), 시나리오가 끝날 때마다 함정 표식 0 을 단언한다
# 그 밖의 모의: Read-Host(-AsSecureString · -MaskInput · 호출 시점의 화면 출력 수 기록) · Set-Clipboard(실패 결함 clipFail · 실물처럼 -WhatIf/ShouldProcess 를 따른다) ·
#   Get-Clipboard · Get-ItemProperty(클립보드 기록 설정 · PowerShell 모듈 로깅 정책 키 4) · Test-Path(~/.vault-token) · Set-PSDebug(-Off 만 허용 — 그 밖의 인자는 위반).
# 가짜 Vault = 메모리 kv v2(경로 → 버전 · 메타데이터 · soft-delete/destroy · CAS). kv put 은 stdin JSON 만 받는다(argv 값 = 위반).
# 모의 vault 는 허용 목록(version · status · token lookup · kv metadata get · kv get · kv put)만 답하고 그 밖은 전부 위반으로 기록한다
#   (kv metadata delete 는 런북 ② 삭제 블록 시나리오에서만 답한다 — 시드 블록 · ① 점검 블록이 부르면 위반).
# 과도 상태 모의(T054 · T056 그대로): metadata 거짓 No value found · 빈 응답 · 500 · 되읽기 실패 · 깨진 JSON(안에 비밀번호 · acl 전문) · 저장 때 값 변형(tamper — password ·
#   passwordCase · dropKey · extraKey + T057 url · aclCrlf) · put 거부 · put 응답 유실 뒤 자기 CAS 충돌(putLost) · put 성공 뒤 metadata 만 바꾸기(postMeta cv2 · deletion · err) ·
#   put 도중 중단(putInterrupt) · 클립보드 비우기 실패 · 삭제 실패(delFail) · 삭제 noop(delNoop) · 삭제 뒤 조회 오류(postDelErr).
# 가짜 값은 전부 MOCK- 이 들어간 누가 봐도 가짜인 문자열이다 — 블록 파일에는 가짜 값이 하나도 없다(S12 가 검사). url 은 문자열 이어 붙이기로만 만든다(이 파일에 url 리터럴 0).
# 호스트 UI 직접 쓰기($Host.UI.WriteLine 등)는 *>&1 로 잡히지 않는다 — 런타임 노출 검사의 사각이라 S12 정적 규칙($Host · $ExecutionContext 는 FlushInputBuffer 한 모양만)으로 막는다.
# acl 렌더(결정 B2): S12 가 블록의 $render 대입문을 AST 로 찾아 정적 규칙(순수 함수 · CR/NewLine 0 · -join 백틱 n · ToLowerInvariant)을 보고, U01–U04 가 그 스크립트블록만 떼어 내
#   고정 입력(모의 비밀번호)으로 돌려 독립 구현 Acl-For(바이트마다 x2 hex)와 바이트 단위로 대조한다 · Dragonfly v1.40.1 aclfile 로더 모의(Test-AclLoader)를 통과하는지도 본다.
# 런북 블록: docs/runbooks/bootstrap.md §4 T057 「정리 판단」의 ① 점검(읽기 전용) · ② 삭제 블록을 코드 펜스에서 그대로 추출해(표식 [t057-cleanup-inspect] · [t057-cleanup-delete])
#   같은 모의 vault/Read-Host 로 돌린다 — R1 · R2(정적 · 관문 6: 추출 · 파서 · 명령 · 정적 형식 · $Host · 리다이렉트) → GA01–GA09 · GA01b · GA03d · GA03e · GA08b(① 점검 — vault 쓰기 명령 0 단언) ·
#   GB01–GB12 · GB03b · GB03c · GB06b · GB07b(② 삭제 — 7경로 허용 목록 Ordinal · 경로 타자 재입력(Ordinal — 대소문자만 다른 재입력도 중단) · 삭제 뒤 No value found 확인 · 조회/삭제 실패 · 잔존 · 삭제 뒤 조회 오류 → 중단).
#   관문이 FAIL 인 런북 블록은 런타임 시나리오에서 한 번도 실행하지 않는다. 두 블록은 첫 Read-Host 전에 클립보드를 공백으로 덮는다
#   (R1 · R2 가 문장을, Run-RbCase 공통 단언이 순서(clip:set < read:plain)와 값(공백만)을 고정한다).
# 사용: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t057-blocks\harness.ps1
#       [-Show 'S01*'] 해당 시나리오의 화면 출력 표시 · [-Block <경로>] 다른 블록 파일(변이 사본)에 같은 시나리오를 돌린다 ·
#       [-Runbook <경로>] 다른 런북 파일(변이 사본)에서 「정리 판단」 두 블록을 추출한다
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$Clock = [Diagnostics.Stopwatch]::StartNew()
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$BlockPath = if ([string]::IsNullOrEmpty($Block)) { Join-Path $here 'op1-seed-dragonfly.ps1' } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Block) }
# $here 는 절대 경로다 — GetFullPath 는 .. 만 정리한다(.NET cwd 에 기대지 않는다)
$RunbookPath = if ([string]::IsNullOrEmpty($Runbook)) { [IO.Path]::GetFullPath((Join-Path $here '..\..\..\..\docs\runbooks\bootstrap.md')) } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Runbook) }
# 세션 설정 원래 값(S10e 가 바꾼다 — Reset-Mocks 가 시나리오마다 되돌린다). $PSDefaultParameterValues 는 참조가 아니라 복제본을 저장한다 —
# S10e 가 제자리(['키'] = …)로 바꾸면 참조 저장은 같은 객체라 대입 복원이 무효다(T054 리뷰 r4 O4 실측) → Clone 저장 · Clone 교체 복원 + S10e 가 복원 뒤 키 없음을 스스로 단언한다
$OrigWhatIf = $global:WhatIfPreference
$OrigPSDPV = $global:PSDefaultParameterValues.Clone()
# 런북 블록 추출 결과(표식 → 코드 본문 · 실패 사유) — R1 · R2 가 채우고 GA · GB 가 쓴다(Reset-Mocks 는 건드리지 않는다)
$global:RbCode = @{}
$global:RbWhy = @{}

# ---------------------------------------------------------------- 계약(블록과 독립으로 하네스가 들고 있는 기대값 — 결정 B1 · B2 · B3 · B4 · B5)
$global:EXPECTED_ADDR = 'http://127.0.0.1:18200'
$global:FAKE_ROOT = 'hvs.MOCK-ROOT-T057-dF5gH7jK9lM1nP3qR4sT'
$global:FAKE_PRE_TOKEN = 'hvs.MOCK-PREEXISTING-zY8xW6vU4tS2rQ0pO9n'
# 형식(hvs.)은 맞지만 root 토큰이 아닌 값 — 모의 Vault 는 FAKE_ROOT 가 아닌 토큰에 403(exit 2)으로 답한다(S14b · T056 리뷰 r1 H1 — token lookup 실패 분기)
$global:FAKE_WRONG_TOKEN = 'hvs.MOCK-WRONG-Ar9Ys3Fd5Tg7Uh2Jk4Il6Ox8'
$global:FAKE_SHARE = 'MOCK-recovery-share-Nl6Mi9Hg4Et1Bq3Rx8Fs'
# 경로 7(B1 — 배열 순서 = 블록의 판정 · 쓰기 순서: env 마다 사용자 → acl · dev → prod). keys = 키 집합(B3) · user = url · acl 의 사용자 이름 · use = 블록의 "쓸 경로" 목록 줄 괄호 안(값 없음 — 목록 줄 대조에만 쓴다)
$PATHS = @(
  [pscustomobject]@{ path = 'kv/dev/dragonfly/admin'; env = 'dev'; user = 'admin'; role = 'admin'; keys = @('password'); use = '키 password · 사용자 admin — 운영자 전용 · ESO 소비자 없음' }
  [pscustomobject]@{ path = 'kv/dev/dragonfly/identity-admin'; env = 'dev'; user = 'identity-admin'; role = 'pod'; keys = @('password', 'url'); use = '키 password · url · 사용자 identity-admin — 뒤에 vault-dev <pod>-env(T072) · 검사 Job jt-dev/assert-env' }
  [pscustomobject]@{ path = 'kv/dev/dragonfly/sample-pod'; env = 'dev'; user = 'sample-pod'; role = 'pod'; keys = @('password', 'url'); use = '키 password · url · 사용자 sample-pod(검사 전용) — 검사 Job jt-dev/assert-env' }
  [pscustomobject]@{ path = 'kv/dev/dragonfly/acl'; env = 'dev'; user = ''; role = 'acl'; keys = @('users.acl'); use = '키 users.acl · dev 사용자 비밀번호의 SHA-256 으로 렌더 — ExternalSecret data/dragonfly-dev-acl → Deployment dragonfly-dev' }
  [pscustomobject]@{ path = 'kv/prod/dragonfly/admin'; env = 'prod'; user = 'admin'; role = 'admin'; keys = @('password'); use = '키 password · 사용자 admin — 운영자 전용 · ESO 소비자 없음' }
  [pscustomobject]@{ path = 'kv/prod/dragonfly/identity-admin'; env = 'prod'; user = 'identity-admin'; role = 'pod'; keys = @('password', 'url'); use = '키 password · url · 사용자 identity-admin — 뒤에 vault-prod <pod>-env(T072)' }
  [pscustomobject]@{ path = 'kv/prod/dragonfly/acl'; env = 'prod'; user = ''; role = 'acl'; keys = @('users.acl'); use = '키 users.acl · prod 사용자 비밀번호의 SHA-256 으로 렌더(sample-pod 없음) — ExternalSecret data/dragonfly-prod-acl → Deployment dragonfly-prod' })
$USERS = @($PATHS | Where-Object { -not [string]::Equals($_.role, 'acl', [StringComparison]::Ordinal) })
# live-ok 모양(B3) = base64url 43자(\A…\z — 앞뒤 공백 · 끝 개행 없음)
$RE_PW = '\A[A-Za-z0-9_-]{43}\z'
# live 가짜 값(사용자 경로 5) — B3 의 live-ok 모양(base64url 43자) · 서로 다르다 · '_' 가 든 값이 있다(시나리오 시작 전에 하네스가 스스로 확인한다 — T056 리뷰 r1 H2)
$LIVE_PW = @{
  'kv/dev/dragonfly/admin'           = 'MOCK-live_da-Hq3Lp8Vz1Rt6Wm4Ky9Bn2Dc7Fs5Gj0'
  'kv/dev/dragonfly/identity-admin'  = 'MOCK-live-di-Ue5Ix2Oa8Pb3Qc6Rd1Se4Tf7Ug9Vh0'
  'kv/dev/dragonfly/sample-pod'      = 'MOCK-live-ds-Wk1Xl4Ym7Zn2Ao5Bp8Cq3Dr6Es9Ft0'
  'kv/prod/dragonfly/admin'          = 'MOCK-live-pa-Gu2Hv5Iw8Jx1Ky4Lz7Ma3Nb6Oc9Pd0'
  'kv/prod/dragonfly/identity-admin' = 'MOCK-live_pi-Qe3Rf6Sg9Th2Ui5Vj8Wk1Xl4Ym7Zn0' }
# 시나리오용 가짜 값(전부 MOCK): 다른 43자 · 같은 값 쌍 · 대소문자만 다른 쌍 · base64url 밖 문자 3종 · 대소문자만 다른 키의 값
$pwOther = 'MOCK-other-oo-Jt4Kn7Lb2Mq5Nw8Pe1Rs6Tx9Va3Wd'
$pwSame = 'MOCK-same-Ns3Kd8Lq1Wx6Zp4Rv9Ht2Mb7Jc5Fy0Gu1'
$pwKa = 'MOCK-pair-Hx2Vn7Bq4Kz9Lw1Rt6Pm3Yd8Jf5Cs0Ga1'
$pwKb = 'MOCK-pair-hx2Vn7Bq4Kz9Lw1Rt6Pm3Yd8Jf5Cs0Ga1'
$pwEq = 'MOCK-live-eq-Rt5Wn8Kp2Lx7Vb4Hd9Fq3Mz6Yc1Js='
$pwDot = 'MOCK-live.dt~Rt5Wn8Kp2Lx7Vb4Hd9Fq3Mz6Yc1Js0'
$pwPlus = 'MOCK-live+st/Qx7Vb2Lm9Pt4Rk8Wn3Hd6Fb1Yc5Js0'
$pwDup = 'MOCK-dup-Qm8Kn3Lb6Vx1Zc4Rw7Ty2Up5Io9Ae0Sd'
# 블록 finally 요약 머리(이 줄 뒤의 경로 행이 요약 표다)
$SUMMARY = '--- T057 Dragonfly ACL · 비밀번호 시드 결과 요약'
function SEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::Ordinal) }
function IEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::OrdinalIgnoreCase) }
function P { param([string]$path) foreach ($e in $PATHS) { if (SEq $e.path $path) { return $e } }; throw "하네스 결함: 경로 $path 없음" }
function Uniq { param($xs) $h = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal); foreach ($x in @($xs)) { [void]$h.Add([string]$x) }; $h.Count }
# ---- 독립 구현(블록의 $render · url 조립과 코드를 나누지 않는다): hex 는 바이트마다 ToString('x2') · 줄은 문자열 리터럴로 잇는다
function Hex-Lower { param([string]$s) -join @([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) }
function Url-For { param($e, [string]$pw) 'redis://' + $e.user + ':' + $pw + '@dragonfly-' + $e.env + '.data.svc:6379/0' }
function Acl-For { param([string]$ev, $pwMap)
  $t = 'USER default OFF -@all' + "`n"
  $t += 'USER admin ON #' + (Hex-Lower ([string]$pwMap['admin'])) + ' ~* &* +@all' + "`n"
  $t += 'USER identity-admin ON #' + (Hex-Lower ([string]$pwMap['identity-admin'])) + ' ~revoked:* ~identity-admin:* +@all' + "`n"
  if (SEq $ev 'dev') { $t += 'USER sample-pod ON #' + (Hex-Lower ([string]$pwMap['sample-pod'])) + ' %R~revoked:* ~sample-pod:* +@all' + "`n" }
  $t }
# 그 env 의 live 가짜 비밀번호 맵(사용자 → password)
function Live-Map { param([string]$ev) $m = @{}; foreach ($e in $USERS) { if (SEq $e.env $ev) { $m[$e.user] = [string]$LIVE_PW[$e.path] } }; $m }
# Dragonfly v1.40.1 aclfile 로더 모의(build-notes 「T057」 1차 자료 — acl_family.cc MaterializeFileContents :727–748 · ParseAclSetUser :1082– · user.cc SetPasswordHash :92–104):
#   LF 로 줄을 나누고 빈 줄은 건너뛴다 · 공백(' ')으로 토큰을 가른다(빈 토큰 버림) · 첫 토큰 USER(대소문자 무시) · 토큰 ≥ 4 · 나머지 토큰은 인식되는 종류여야 한다 · default 줄이 있어야 한다.
#   돌려주는 값 '' = 로드됨 · 그 밖 = 로드 실패 사유(실물은 실패하면 파일 전체를 버리고 default nopass 로 기동한다). # 뒤가 짝수 길이 hex 가 아니면 실물은 LOG(ERROR) 뒤
#   그 사용자를 비밀번호 없이 두는데, 이 모의는 더 엄격하게 실패로 본다
function Test-AclLoader { param([string]$text)
  if ([string]::IsNullOrEmpty($text)) { return 'Empty file' }
  $users = @()
  foreach ($line in $text.Split("`n")) {
    if ($line.Length -eq 0) { continue }
    $tk = @($line.Split(' ') | Where-Object { $_.Length -gt 0 })
    if ($tk.Count -lt 4 -or -not (IEq $tk[0] 'USER')) { return "materialize 실패(첫 토큰 USER · 토큰 ≥ 4 — 이 줄 토큰 $($tk.Count))" }
    $users += $tk[1]
    for ($i = 2; $i -lt $tk.Count; $i++) {
      $t = [string]$tk[$i]
      if ((SEq $t 'nopass') -or (SEq $t 'resetpass') -or $t.StartsWith('>', [StringComparison]::Ordinal) -or $t.StartsWith('<', [StringComparison]::Ordinal)) { continue }
      if ($t.StartsWith('#', [StringComparison]::Ordinal)) { if ($t.Substring(1) -cnotmatch '\A(?:[0-9A-Fa-f]{2})+\z') { return 'Invalid password hash(짝수 길이 hex 아님)' }; continue }
      if ((SEq $t '~*') -or (IEq $t 'ALLKEYS') -or (IEq $t 'RESETKEYS') -or ($t -cmatch '\A(?:%RW|%R|%W)?~.+\z')) { continue }
      if ((SEq $t '&*') -or (IEq $t 'ALLCHANNELS') -or (IEq $t 'RESETCHANNELS') -or ($t -cmatch '\A&.+\z')) { continue }
      $u = $t.ToUpperInvariant()
      if ((SEq $u 'ON') -or (SEq $u 'OFF') -or ($u -cmatch '\A[+-]@[A-Z]+\z')) { continue }
      return "Unrecognized parameter(토큰 $($i + 1)번째)" } }
  if (-not (@($users) -ccontains 'default')) { return 'default 줄 없음(로더가 nopass default 를 만든다 — 무인증)' }
  '' }

# ---------------------------------------------------------------- 0) 실물 차단 가드(블록을 한 번이라도 돌리기 전에)
$TrapDir = Join-Path ([IO.Path]::GetTempPath()) ('t057-harness-trap-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $TrapDir)
foreach ($n in 'vault', 'kubectl') {
  [IO.File]::WriteAllText((Join-Path $TrapDir "$n.cmd"), "@echo off`r`necho TRAP>`"%~dp0CALLED-$n`"`r`nexit /b 97`r`n", [Text.UTF8Encoding]::new($false)) }
$RealDirs = @(Get-Command vault, kubectl, vault.exe, kubectl.exe -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { (Split-Path -Parent $_.Source).TrimEnd('\') })
$sep = [IO.Path]::PathSeparator
$keptPath = @($env:PATH -split [regex]::Escape($sep) | Where-Object {
    $d = $_; if ([string]::IsNullOrEmpty($d)) { return $false }
    foreach ($r in $RealDirs) { if ([string]::Equals($d.TrimEnd('\'), $r, [StringComparison]::OrdinalIgnoreCase)) { return $false } }
    $true })
$OrigPath = $env:PATH
$env:PATH = (@($TrapDir) + $keptPath) -join $sep
# 운영자 KUBECONFIG(관리자 자격일 수 있다)를 이 프로세스에서 끊는다 — 함정 디렉터리 안의 없는 경로로 덮고, 맨 끝 finally 에서 원래 값(없었으면 없음)으로 되돌린다
$OrigKubeconfig = $env:KUBECONFIG
$FakeKubeconfig = Join-Path $TrapDir 'no-such-kubeconfig'
$env:KUBECONFIG = $FakeKubeconfig

# ---------------------------------------------------------------- 모의 명령(블록의 StrictMode 3.0 아래에서 돈다 — 해시 테이블은 ['키'] 로만 읽는다)
function At { param($arr, [int]$i) $l = @($arr); if ($i -ge 0 -and $i -lt $l.Count) { [string]$l[$i] } else { '' } }
function Has-Flag { param($list, [string]$f) foreach ($x in @($list)) { if (SEq $x $f) { return $true } }; $false }
function Add-Event { param([string]$e) [void]$global:Events.Add($e) }
function Add-Violation { param([string]$v) [void]$global:Violations.Add($v) }
# native stderr 흉내: 호출자의 EAP=Stop 아래에서도 종료 오류가 되지 않게 지역 EAP 를 Continue 로 둔다(2>&1 이면 ErrorRecord 로 섞이고 2>$null 이면 버려진다 — 실물과 같다)
function Mock-Stderr { param([string[]]$lines) $ErrorActionPreference = 'Continue'; foreach ($l in $lines) { Write-Error -Message $l } }
function Json-Lines { param($obj) @((ConvertTo-Json -InputObject $obj -Depth 10) -split "`r?`n") }
function Take-Fault { param([string]$kind, [string]$path)
  $t = $global:F[$kind]
  if ($null -eq $t -or -not $t.ContainsKey($path)) { return $false }
  $c = [int]$t[$path]
  if ($c -le 0) { return $false }
  $t[$path] = $c - 1
  $true }
function KvRest { param([string]$path) if ($path.StartsWith('kv/', [StringComparison]::Ordinal)) { $path.Substring(3) } else { $path } }
function Split-FlagsPath { param($rest)
  $flags = @(); $path = $null; $trail = @(); $bad = ''
  foreach ($x in @($rest)) {
    $s = [string]$x
    if ($null -eq $path) {
      if (SEq $s '-') { $bad = 'stdin 표식이 경로 앞' }
      elseif ($s.StartsWith('-', [StringComparison]::Ordinal)) { $flags += $s }
      else { $path = $s } }
    else { $trail += $s } }
  [pscustomobject]@{ flags = $flags; path = $path; trailing = $trail; bad = $bad } }
function Need-Auth {
  if (-not (SEq $env:VAULT_ADDR $global:EXPECTED_ADDR)) {
    Mock-Stderr @('Error making API request.', '', "URL: GET $([string]$env:VAULT_ADDR)", '* dial tcp: connection refused'); return 'addr' }
  if (-not (SEq $env:VAULT_TOKEN $global:FAKE_ROOT)) {
    Mock-Stderr @('Error making API request.', '', 'Code: 403. Errors:', '', '* permission denied'); return 'token' }
  '' }
# mode(postMeta 결함 — put 이 성공한 뒤의 metadata 응답만 바꾼다. 저장소 자체는 그대로): cv2 = 다른 기록자가 v2 를 쓴 것처럼 current_version 2(v2 도 live) /
#   deletion = 마운트의 delete_version_after 처럼 현재 버전에 deletion_time(삭제 예약)
function Kv-MetaObj { param([string]$path, [string]$mode = '')
  $e = $global:Kv[$path]
  $cur = [int]$e['current']; $dva = '0s'
  $vers = [ordered]@{}
  foreach ($k in @($e['versions'].Keys | Sort-Object { [int]$_ })) {
    $v = $e['versions'][$k]
    $vers[[string]$k] = [ordered]@{ created_time = $v['created_time']; deletion_time = $v['deletion_time']; destroyed = $v['destroyed'] } }
  if ((SEq $mode 'cv2') -and $vers.Count -gt 0) { $cur = $cur + 1; $vers[[string]$cur] = [ordered]@{ created_time = '2026-10-14T03:00:01Z'; deletion_time = ''; destroyed = $false } }
  if ((SEq $mode 'deletion') -and $vers.Contains([string]$cur)) { $vers[[string]$cur]['deletion_time'] = '2026-10-21T03:00:00Z'; $dva = '168h0m0s' }
  $oldest = 0; if ($e['versions'].Count -gt 0) { $oldest = 1 }
  [ordered]@{ request_id = 'mock-req'; lease_id = ''; lease_duration = 0; renewable = $false
    data = [ordered]@{ cas_required = $false; created_time = $e['created']; current_version = $cur; custom_metadata = $null; delete_version_after = $dva
      max_versions = 0; oldest_version = $oldest; updated_time = $e['created']; versions = $vers }
    warnings = $null } }
function Mock-Status { param($rest)
  Add-Event 'vault:status'
  if (-not (Has-Flag $rest '-format=json')) { Add-Violation 'vault status 에 -format=json 없음'; $global:LASTEXITCODE = 1; return }
  $mode = [string]$global:F['status']
  if (-not (SEq $env:VAULT_ADDR $global:EXPECTED_ADDR) -or (SEq $mode 'down')) {
    Mock-Stderr @("Error checking seal status: Get `"$([string]$env:VAULT_ADDR)/v1/sys/seal-status`": dial tcp 127.0.0.1:18200: connectex: No connection could be made because the target machine actively refused it.")
    $global:LASTEXITCODE = 1; return }
  if (SEq $mode 'garbage') { $global:LASTEXITCODE = 0; return 'not-json-at-all' }
  $o = [ordered]@{ type = 'ocikms'; initialized = $true; sealed = $false; t = 1; n = 1; progress = 0; nonce = ''; version = '2.0.4-MOCK'; build_date = '2026-01-01T00:00:00Z'
    migration = $false; cluster_name = 'vault-cluster-MOCK'; cluster_id = 'MOCK-cluster-id'; recovery_seal = $true; storage_type = 'raft'; ha_enabled = $true }
  $rc = 0
  if (SEq $mode 'sealed') { $o['sealed'] = $true; $rc = 2 }
  if (SEq $mode 'uninit') { $o['initialized'] = $false; $o['sealed'] = $true; $rc = 2 }
  if (SEq $mode 'stringbool') { $o['sealed'] = 'false' }
  # okrc1: 응답은 unsealed JSON 인데 종료 코드 1(T054 리뷰 O3 — 블록의 "unsealed 인데 exit≠0 → 판단 불가" 분기를 고정한다)
  if (SEq $mode 'okrc1') { $rc = 1 }
  $global:LASTEXITCODE = $rc
  Json-Lines $o }
function Mock-TokenLookup { param($rest)
  Add-Event 'vault:token-lookup'
  if (-not (Has-Flag $rest '-format=json')) { Add-Violation 'token lookup 에 -format=json 없음'; $global:LASTEXITCODE = 1; return }
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  # 실물처럼 data.id 에 토큰 평문이 들어 있다 — 블록이 응답을 출력하면 노출 검사가 잡는다
  Json-Lines ([ordered]@{ request_id = 'mock-req'; data = [ordered]@{ accessor = 'MOCK-accessor'; id = [string]$env:VAULT_TOKEN; policies = @($global:TokenPolicies); ttl = 0 } }) }
function Mock-MetaGet { param($rest)
  $p = Split-FlagsPath $rest
  if ($null -eq $p.path -or @($p.trailing).Count -gt 0 -or -not (Has-Flag $p.flags '-format=json')) { Add-Violation "kv metadata get 인자 형식(플래그는 경로 앞 · -format=json): $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  Add-Event "vault:meta-get:$path"
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if (Take-Fault 'metaFalseAbsent' $path) { Mock-Stderr @("No value found at kv/metadata/$r"); $global:LASTEXITCODE = 2; return }
  if (Take-Fault 'metaEmpty' $path) { $global:LASTEXITCODE = 2; return }
  if (Take-Fault 'metaError' $path) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', "URL: GET $($global:EXPECTED_ADDR)/v1/kv/metadata/$r", 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  # postMeta 'err'(T054 리뷰 r3 O3): 이 경로에 put 이 한 번이라도 불린 뒤의 metadata 조회만 500 — 판정 단계(put 전)는 정상이다.
  # 쓰기 뒤 metadata 확인(S20c)과 put 비 0 뒤 재판정(S16e)의 일시 오류 분기를 고정한다
  if ((SEq ([string]$global:F['postMeta'][$path]) 'err') -and @($global:PutCalls | Where-Object { SEq $_.path $path }).Count -gt 0) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', "URL: GET $($global:EXPECTED_ADDR)/v1/kv/metadata/$r", 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  # postDelErr: 이 경로를 지운 뒤의 metadata 조회만 500 — 런북 ② 삭제 블록의 삭제 뒤 확인이 조회 오류를 "없어졌다"로 보지 않는지(GB12)
  if ($global:F['postDelErr'].ContainsKey($path) -and $global:Deleted.ContainsKey($path)) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", '', 'Code: 500. Errors:', '', '* context deadline exceeded')
    $global:LASTEXITCODE = 2; return }
  if (-not $global:Kv.ContainsKey($path)) { Mock-Stderr @("No value found at kv/metadata/$r"); $global:LASTEXITCODE = 2; return }
  Json-Lines (Kv-MetaObj $path ([string]$global:F['postMeta'][$path])) }
function Mock-KvGet { param($rest)
  foreach ($x in @($rest)) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { Add-Violation 'kv get -field 사용(끝 개행을 잃는다 — T045 교훈)'; $global:LASTEXITCODE = 1; return } }
  $p = Split-FlagsPath $rest
  if ($null -eq $p.path -or @($p.trailing).Count -gt 0 -or -not (Has-Flag $p.flags '-format=json')) { Add-Violation "kv get 인자 형식(플래그는 경로 앞 · -format=json): $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  Add-Event "vault:kv-get:$path"
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if (Take-Fault 'readFail' $path) { $global:LASTEXITCODE = 2; return }
  if (-not $global:Kv.ContainsKey($path)) { Mock-Stderr @("No value found at kv/data/$r"); $global:LASTEXITCODE = 2; return }
  $e = $global:Kv[$path]
  $cur = [string]$e['current']
  $v = $e['versions'][$cur]
  if ($null -eq $v) { Mock-Stderr @("No value found at kv/data/$r"); $global:LASTEXITCODE = 2; return }
  if (Take-Fault 'readGarbage' $path) {
    # 잘린 JSON — 안에 값(첫 키 — password 또는 users.acl 전문 · 줄바꿈 포함)이 들어 있다(블록이 해석 실패를 어떻게 다루는지 · $Error 에 값이 남는지 본다)
    $global:LASTEXITCODE = 0
    $k0 = [string]@($v['data'].Keys)[0]
    return @('{', '  "data": {', '    "data": {', ('      "' + $k0 + '": "' + [string]$v['data'][$k0] + '",'), '      "x": ') }
  $meta = [ordered]@{ created_time = $v['created_time']; custom_metadata = $null; deletion_time = $v['deletion_time']; destroyed = $v['destroyed']; version = [int]$cur }
  $data = $null
  if (-not $v['destroyed'] -and [string]::IsNullOrEmpty([string]$v['deletion_time'])) { $data = $v['data'] }
  Json-Lines ([ordered]@{ request_id = 'mock-req'; lease_id = ''; lease_duration = 0; renewable = $false; data = [ordered]@{ data = $data; metadata = $meta }; warnings = $null }) }
# tamper 결함(키 지정형 — T054 리뷰 O2): $global:F['tamper'][<경로>] = 모드. 저장 때 한 번만 값을 바꾼다.
#   password = 마지막 한 글자(모양은 그대로 — 모양 판정으로는 못 잡고 해시 대조로만 잡힌다) · dropKey = password 키(acl 경로면 users.acl)를 뺀다 · extraKey = 키 note 를 더한다 ·
#   passwordCase = 첫 영문자의 대소문자만 뒤집는다(T056 리뷰 r1 H3 — 대소문자를 무시하는 원값 비교(-eq)로는 같아 보이고 Ordinal 해시 대조로만 잡힌다 · S09d) ·
#   url = url 의 비밀번호 부분 마지막 글자(S09e) · aclCrlf = users.acl 의 LF 를 CRLF 로(S09f — 줄마다 1바이트)
function One-Char { param([string]$s, [int]$i)
  if ($i -lt 0 -or $i -ge $s.Length) { return $s }
  $s.Substring(0, $i) + $(if (SEq $s.Substring($i, 1) 'A') { 'B' } else { 'A' }) + $s.Substring($i + 1) }
# 첫 ASCII 영문자의 대소문자를 뒤집는다(영문자가 없으면 위반으로 남긴다 — 변형 없이 통과하는 거짓 PASS 를 막는다)
function Flip-FirstLetter { param([string]$s)
  $m = [regex]::Match($s, '[A-Za-z]')
  if (-not $m.Success) { Add-Violation '하네스: passwordCase 로 뒤집을 영문자가 없다'; return $s }
  $c = $m.Value
  $f = if ($c -cmatch '[A-Z]') { $c.ToLowerInvariant() } else { $c.ToUpperInvariant() }
  $s.Substring(0, $m.Index) + $f + $s.Substring($m.Index + 1) }
function Take-Tamper { param([string]$path)
  $t = $global:F['tamper']
  if (-not $t.ContainsKey($path)) { return '' }
  $m = [string]$t[$path]
  $t.Remove($path)
  $m }
function Tamper-Data { param($data, [string]$mode)
  if (SEq $mode 'password') { $p = [string]$data['password']; $data['password'] = One-Char $p ($p.Length - 1) }
  elseif (SEq $mode 'passwordCase') { $data['password'] = Flip-FirstLetter ([string]$data['password']) }
  elseif (SEq $mode 'dropKey') { if ($data.Contains('password')) { $data.Remove('password') } else { $data.Remove('users.acl') } }
  elseif (SEq $mode 'extraKey') { $data['note'] = 'x' }
  elseif (SEq $mode 'url') { $u = [string]$data['url']; $data['url'] = One-Char $u ($u.LastIndexOf('@') - 1) }
  elseif (SEq $mode 'aclCrlf') { $data['users.acl'] = ([string]$data['users.acl']).Replace("`n", "`r`n") }
  else { Add-Violation "하네스: 알 수 없는 tamper 모드 $mode" } }
# acl 문자열의 첫 # hex 한 글자를 다른 hex 로 바꾼다(1바이트 변형 — S04q8)
function Flip-HexChar { param([string]$s)
  $i = $s.IndexOf('#')
  if ($i -lt 0 -or $i + 1 -ge $s.Length) { Add-Violation '하네스: Flip-HexChar 로 바꿀 # hex 가 없다'; return $s }
  $c = $s.Substring($i + 1, 1)
  $s.Substring(0, $i + 1) + $(if (SEq $c '0') { '1' } else { '0' }) + $s.Substring($i + 2) }
function Mock-KvPut { param($rest, $stdin)
  $p = Split-FlagsPath $rest
  $cas = $null
  foreach ($f in @($p.flags)) { if ($f.StartsWith('-cas=', [StringComparison]::Ordinal)) { $cas = [int]$f.Substring(5) } else { Add-Violation "kv put 플래그: $f" } }
  $trail = @($p.trailing)
  $useStdin = ($trail.Count -eq 1 -and (SEq $trail[0] '-'))
  if (@($trail | Where-Object { -not (SEq $_ '-') }).Count -gt 0) { Add-Violation 'kv put 이 argv 로 값을 받았다(k=v — 값이 argv 에 나온다)' }
  $body = (@($stdin) | ForEach-Object { [string]$_ }) -join "`n"
  [void]$global:PutCalls.Add([pscustomobject]@{ path = [string]$p.path; cas = $cas; stdin = $useStdin })
  if (-not [string]::IsNullOrEmpty($body)) { [void]$global:PutBodies.Add($body) }
  Add-Event "vault:put:$([string]$p.path)"
  if ($null -eq $p.path -or -not $useStdin -or $p.bad) { $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if ($global:F['putFail'].ContainsKey($path)) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', 'Code: 403. Errors:', '', '* permission denied')
    $global:LASTEXITCODE = [int]$global:F['putFail'][$path]; return }
  $obj = $null
  try { $obj = $body | ConvertFrom-Json -AsHashtable -DateKind String } catch { $global:LASTEXITCODE = 1; return }
  if ($obj -isnot [System.Collections.IDictionary]) { $global:LASTEXITCODE = 1; return }
  $data = [ordered]@{}
  foreach ($k in @($obj.Keys)) {
    if ($obj[$k] -isnot [string]) { Add-Violation "kv put 값이 문자열이 아니다: $k"; $global:LASTEXITCODE = 1; return }
    $data[[string]$k] = [string]$obj[$k] }
  $cur = 0
  if ($global:Kv.ContainsKey($path)) { $cur = [int]$global:Kv[$path]['current'] }
  if ($null -ne $cas -and $cas -ne $cur) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', "URL: PUT $($global:EXPECTED_ADDR)/v1/kv/data/$r", 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version')
    $global:LASTEXITCODE = 2; return }
  $tm = Take-Tamper $path
  if ($tm) { Tamper-Data $data $tm }
  if (-not $global:Kv.ContainsKey($path)) { $global:Kv[$path] = @{ current = 0; created = $global:NowIso; versions = @{} } }
  $n = [int]$global:Kv[$path]['current'] + 1
  $global:Kv[$path]['versions'][[string]$n] = @{ data = $data; deletion_time = ''; destroyed = $false; created_time = $global:NowIso }
  $global:Kv[$path]['current'] = $n
  # 중단(Ctrl+C) 대용(putInterrupt 결함): 서버는 이미 커밋했는데 클라이언트 쪽 파이프라인이 끊겼다 — 블록 요약이 "쓰지 않았다"로 남으면 안 된다
  if (Take-Fault 'putInterrupt' $path) { throw '모의 중단(put 도중 Ctrl+C 대용) — 서버는 이미 커밋했다' }
  # putLost 결함(T054 리뷰 r3 O6): 서버는 커밋했는데 응답이 유실돼 CLI 자동 재시도(VAULT_MAX_RETRIES 기본 2)가 자기 기록과 CAS 충돌했다 —
  # 종료 2 · 진짜 CAS 충돌과 같은 문구(블록은 문구로 가를 수 없다 — 재판정으로만 가른다)
  if (Take-Fault 'putLost' $path) {
    Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', "URL: PUT $($global:EXPECTED_ADDR)/v1/kv/data/$r", 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version')
    $global:LASTEXITCODE = 2; return }
  $global:LASTEXITCODE = 0
  @('====== Secret Path ======', "kv/data/$r", '', '======= Metadata =======', 'Key                Value', '---                -----', "created_time       $($global:NowIso)",
    'custom_metadata    <nil>', 'deletion_time      n/a', 'destroyed          false', "version            $n") }
# kv metadata delete — 런북 ② 삭제 블록 시나리오($global:AllowDelete)에서만 답한다. 시드 블록 · ① 점검 블록이 부르면 위반이다.
# 결함: delFail(권한 거부 · 종료 2) · delNoop(종료 0 인데 지우지 않음) — 지운 경로는 $global:Deleted 에 남긴다(postDelErr 용)
function Mock-MetaDelete { param($rest)
  $p = Split-FlagsPath $rest
  if ($null -eq $p.path -or @($p.flags).Count -gt 0 -or @($p.trailing).Count -gt 0) { Add-Violation "kv metadata delete 인자 형식(경로 하나만): $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  $path = [string]$p.path
  Add-Event "vault:meta-delete:$path"
  if (-not $global:AllowDelete) { Add-Violation "kv metadata delete 호출(시드 블록 · ① 점검 블록은 지우지 않는다): $path"; $global:LASTEXITCODE = 1; return }
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if ($global:F['delFail'].ContainsKey($path)) {
    Mock-Stderr @("Error deleting kv/metadata/${r}: Error making API request.", '', 'Code: 403. Errors:', '', '* permission denied'); $global:LASTEXITCODE = 2; return }
  if (-not $global:F['delNoop'].ContainsKey($path)) { [void]$global:Kv.Remove($path); $global:Deleted[$path] = $true }
  $global:LASTEXITCODE = 0
  "Success! Data deleted (if it existed) at: kv/metadata/$r" }
function vault {
  $stdin = @($input)
  $a = @($args | ForEach-Object { [string]$_ })
  $line = $a -join ' '
  [void]$global:ArgvLog.Add($line)
  $global:LASTEXITCODE = 0
  $isPut = (SEq (At $a 0) 'kv') -and (SEq (At $a 1) 'put')
  if ($stdin.Count -gt 0 -and -not $isPut) { Add-Violation "put 이 아닌 vault 호출에 stdin: $line" }
  $rest1 = @($a | Select-Object -Skip 1)
  if (SEq (At $a 0) 'version') { Add-Event 'vault:version'; return 'Vault v0.0.0-MOCK (harness)' }
  if (SEq (At $a 0) 'status') { return (Mock-Status $rest1) }
  if ((SEq (At $a 0) 'token') -and (SEq (At $a 1) 'lookup')) { return (Mock-TokenLookup @($a | Select-Object -Skip 2)) }
  if (SEq (At $a 0) 'kv') {
    if ((SEq (At $a 1) 'metadata') -and (SEq (At $a 2) 'get')) { return (Mock-MetaGet @($a | Select-Object -Skip 3)) }
    if ((SEq (At $a 1) 'metadata') -and (SEq (At $a 2) 'delete')) { return (Mock-MetaDelete @($a | Select-Object -Skip 3)) }
    if (SEq (At $a 1) 'get') { return (Mock-KvGet @($a | Select-Object -Skip 2)) }
    if ($isPut) { return (Mock-KvPut @($a | Select-Object -Skip 2) $stdin) } }
  Add-Violation "허용 목록 밖 vault 호출: $line"
  $global:LASTEXITCODE = 1 }
function vault.exe { Add-Violation ('vault.exe 직접 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function kubectl { Add-Violation ('kubectl 호출(이 블록은 클러스터에 닿지 않는다): ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function kubectl.exe { Add-Violation ('kubectl.exe 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function curl { Add-Violation 'curl 호출'; $global:LASTEXITCODE = 1 }
function curl.exe { Add-Violation 'curl.exe 호출'; $global:LASTEXITCODE = 1 }
function oci { Add-Violation 'oci 호출'; $global:LASTEXITCODE = 1 }
function gh { Add-Violation 'gh 호출'; $global:LASTEXITCODE = 1 }
function Read-Host { param([Parameter(Position = 0)]$Prompt, [switch]$AsSecureString, [switch]$MaskInput)
  $p = [string]$Prompt
  [void]$global:Prompts.Add($p)
  $v = ''
  if ($global:Inputs.Count -gt 0) { $v = [string]$global:Inputs.Dequeue() }
  # items = 이 입력을 묻는 시점까지 화면에 나온 출력 수(Run-Case 가 센다 — T054 리뷰 r3 O2: INFO vault CLI 줄이 root 토큰 프롬프트보다 먼저인지)
  [void]$global:ReadLog.Add([pscustomobject]@{ prompt = $p; secure = [bool]$AsSecureString; masked = [bool]$MaskInput; value = $v; items = [int]$global:ItemCount })
  if ($AsSecureString) {
    Add-Event 'read:secure'
    $ss = [securestring]::new()
    foreach ($c in $v.ToCharArray()) { $ss.AppendChar($c) }
    return $ss }
  Add-Event 'read:plain'
  $v }
# clipFail 결함(T054 리뷰 O5): 다른 프로세스(rdpclip · 클립보드 관리자)가 클립보드를 잡고 있을 때처럼 예외 — 쓰려던 값은 먼저 기록한다("공백만" 단언 유지)
# 실물 Set-Clipboard 처럼 ShouldProcess 를 따른다(T054 리뷰 r3 O5): 세션 $WhatIfPreference · $PSDefaultParameterValues 의 -WhatIf 가 살아 있으면
# 아무것도 쓰지 않고(clip:whatif) 예외도 없다 — 블록이 비웠다고 믿는 채 root 토큰이 클립보드에 남는 경로를 재현한다
function Set-Clipboard { [CmdletBinding(SupportsShouldProcess = $true)] param([Parameter(ValueFromPipeline = $true, Position = 0)]$Value)
  if (-not $PSCmdlet.ShouldProcess('clipboard', 'Set-Clipboard')) { Add-Event 'clip:whatif'; return }
  [void]$global:ClipValues.Add([string]$Value); Add-Event 'clip:set'
  if ($global:F['clipFail']) { Add-Event 'clip:fail'; throw '모의 클립보드 열기 실패(다른 프로세스가 클립보드를 잡고 있다)' } }
# Set-PSDebug: -Off 만 허용(이벤트) — -Trace · -Step · -Strict 는 위반(T054 리뷰 O6). 실물을 부르지 않는다(하네스 프로세스의 strict 설정을 건드리지 않는다)
function Set-PSDebug { param([switch]$Off, [int]$Trace = -1, [switch]$Step, [switch]$Strict)
  if ($Off -and $Trace -lt 0 -and -not $Step -and -not $Strict) { Add-Event 'psdebug:off' } else { Add-Violation 'Set-PSDebug 를 -Off 가 아닌 인자로 호출' } }
function Get-Clipboard { Add-Violation 'Get-Clipboard 호출(블록은 클립보드를 읽지 않는다)'; ' ' }
# PowerShell 모듈 로깅 정책 키(PowerShellCore 2 + UseWindowsPowerShellPolicySetting 값이 1 일 때 Windows PowerShell 2). 값 = $global:Policy[<키>] 해시(없으면 키 없음)
$global:PolicyPaths = @('HKLM:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging',
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging', 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging')
function Get-ItemProperty { param([Parameter(Position = 0)]$Path, [Parameter(Position = 1)]$Name)
  foreach ($pp in $global:PolicyPaths) {
    if ([string]::Equals([string]$Path, $pp, [StringComparison]::OrdinalIgnoreCase)) {
      Add-Event "reg:policy:$pp"
      $h = $global:Policy[$pp]
      if ($null -eq $h) { return $null }
      return [pscustomobject]$h } }
  Add-Event 'reg:get'
  if (-not ([string]$Path).EndsWith('Microsoft\Clipboard', [StringComparison]::OrdinalIgnoreCase)) { Add-Violation "Get-ItemProperty 다른 경로: $Path"; return $null }
  if (SEq $global:ClipHistoryMode 'nokey') { return $null }
  if (SEq $global:ClipHistoryMode 'novalue') { return [pscustomobject]@{ ShellHotKeyUsed = 1 } }
  [pscustomobject]@{ EnableClipboardHistory = $global:ClipHistory } }
function Test-Path { param([Parameter(Position = 0)]$Path)
  if (([string]$Path).EndsWith('.vault-token', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:vault-token'; return [bool]$global:VaultTokenFile }
  Microsoft.PowerShell.Management\Test-Path -Path $Path }

# ---------------------------------------------------------------- 가드 확인 · 모의 상태
function Assert-Guard {
  foreach ($n in 'vault', 'kubectl', 'vault.exe', 'kubectl.exe', 'Set-PSDebug') {
    $c = Get-Command $n -ErrorAction SilentlyContinue
    if ($null -eq $c -or $c.CommandType -ne 'Function') { throw "가드 실패: $n 이 모의 함수로 풀리지 않는다 — 블록을 실행하지 않는다" } }
  foreach ($a in @(Get-Command vault, kubectl, vault.exe, kubectl.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
    if (-not $a.Source.StartsWith($TrapDir, [StringComparison]::OrdinalIgnoreCase)) { throw "가드 실패: 실물 실행 파일이 PATH 에 남아 있다($($a.Source)) — 블록을 실행하지 않는다" } }
  if (-not (SEq $env:KUBECONFIG $FakeKubeconfig) -or (Microsoft.PowerShell.Management\Test-Path -LiteralPath $FakeKubeconfig)) { throw '가드 실패: KUBECONFIG 가 하네스의 없는 경로가 아니다 — 블록을 실행하지 않는다' } }
function Trap-Markers { @(Get-ChildItem -LiteralPath $TrapDir -Filter 'CALLED-*' -ErrorAction SilentlyContinue).Count }
function Reset-Mocks {
  # 세션 설정을 먼저 원래 값으로(S10e 가 WhatIf · 기본 매개변수 값을 바꾼다 — 아래 Remove-Item 이 그 설정에 걸리지 않게 맨 앞)
  $global:WhatIfPreference = $OrigWhatIf
  $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
  $global:Kv = @{}
  $global:F = @{ status = 'ok'; metaFalseAbsent = @{}; metaEmpty = @{}; metaError = @{}; readFail = @{}; readGarbage = @{}; tamper = @{}; putFail = @{}; postMeta = @{}; putInterrupt = @{}; clipFail = $false
    putLost = @{}; delFail = @{}; delNoop = @{}; postDelErr = @{} }
  $global:AllowDelete = $false
  $global:Deleted = @{}
  $global:ItemCount = 0
  $global:Policy = @{}
  $global:Inputs = [System.Collections.Queue]::new()
  foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls', 'PutBodies', 'Violations', 'ExtraSecrets') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
  $global:TokenPolicies = @('default', 'root')
  $global:ClipHistory = 0
  $global:ClipHistoryMode = 'value'
  $global:VaultTokenFile = $false
  $global:NowIso = '2026-10-14T03:00:00Z'
  $global:PreRunPuts = -1
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) } }
Reset-Mocks
function Seed-Path { param([string]$path, $data, [int]$current = 1, [string]$deletion = '', [bool]$destroyed = $false)
  $vers = @{}
  if ($current -gt 0) { $vers[[string]$current] = @{ data = $data; deletion_time = $deletion; destroyed = $destroyed; created_time = '2026-10-13T00:00:00Z' } }
  $global:Kv[$path] = @{ current = $current; created = '2026-10-13T00:00:00Z'; versions = $vers } }
# live 데이터(B3 의 live-ok 모양): admin = {password} · pod = {password, url(같은 password)} · acl = {users.acl = 그 env 의 live 가짜 비밀번호로 독립 렌더}
function Live-Data { param($e, [string]$pw = '')
  if (SEq $e.role 'acl') { return [ordered]@{ 'users.acl' = (Acl-For $e.env (Live-Map $e.env)) } }
  if ([string]::IsNullOrEmpty($pw)) { $pw = [string]$LIVE_PW[$e.path] }
  $d = [ordered]@{ password = $pw }
  if (@($e.keys) -ccontains 'url') { $d['url'] = Url-For $e $pw }
  $d }
function Seed-LiveOk { param($e) Seed-Path $e.path (Live-Data $e) }
function Seed-Env { param([string]$ev) foreach ($e in $PATHS) { if (SEq $e.env $ev) { Seed-LiveOk $e } } }
function Seed-All { foreach ($e in $PATHS) { Seed-LiveOk $e } }
# 7경로 중 -only(비면 전부)를 live-ok 모양으로 심는다 — 사용자 password 는 -pw[경로] 가 있으면 그 값(같은 값 쌍 · 대소문자 쌍 시나리오), 없으면 LIVE_PW ·
# acl 은 그 env 의 (덮어쓴) 사용자 비밀번호로 독립 렌더(acl 자체는 모양이 맞는 상태 — 쌍 판정만 걸리게)
function Seed-Set { param([hashtable]$pw = @{}, [string[]]$only = @())
  $map = @{ dev = @{}; prod = @{} }
  foreach ($e in $USERS) { $v = [string]$LIVE_PW[$e.path]; if ($pw.ContainsKey($e.path)) { $v = [string]$pw[$e.path] }; $map[$e.env][$e.user] = $v }
  foreach ($e in $PATHS) {
    if ($only.Count -gt 0 -and -not ($only -ccontains $e.path)) { continue }
    if (SEq $e.role 'acl') { Seed-Path $e.path ([ordered]@{ 'users.acl' = (Acl-For $e.env $map[$e.env]) }) }
    else { Seed-Path $e.path (Live-Data $e $map[$e.env][$e.user]) } } }
function KvCur { param([string]$path) if ($global:Kv.ContainsKey($path)) { [int]$global:Kv[$path]['current'] } else { -1 } }
function KvData { param([string]$path)
  if (-not $global:Kv.ContainsKey($path)) { return $null }
  $v = $global:Kv[$path]['versions'][[string]$global:Kv[$path]['current']]
  if ($null -eq $v) { return $null }
  $v['data'] }
function Invoke-PreRun { param([string[]]$inputs)
  foreach ($x in $inputs) { $global:Inputs.Enqueue($x) }
  try { & $BlockPath *>&1 | Out-Null } catch { }
  $global:PreRunPuts = $global:PutCalls.Count
  $global:ItemCount = 0
  foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
  $global:Inputs = [System.Collections.Queue]::new()
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) } }

# ---------------------------------------------------------------- 노출 검사(바늘: 비밀 전체 · base64 · 8자 조각 전부 · SHA-256 hex)
$script:NSecrets = [System.Collections.Generic.List[string]]::new()
$script:NFulls = [System.Collections.Generic.List[string]]::new()
# 비밀 = kv 의 password 값(키 이름 Ordinal) + 블록이 put stdin 으로 보낸 password + root 토큰 · 시나리오가 더한 값(ExtraSecrets — 대소문자가 다른 키 Password 의 값 · 터널 토큰 등)
#   → 전체 · base64 · 8자 조각 · SHA-256 hex. url 은 전체(NFulls)에 더해 그 안의 비밀번호 부분(사용자 : 와 마지막 @ 사이)을 비밀로 · users.acl 은 전문과 그 안의 # hex 전부를
#   NFulls 로(hex 는 대 · 소문자 전체 + 앞 16자 — 해시 출력 = 비밀 노출 · 원칙 e). url · acl 전문은 8자 조각을 만들지 않는다(호스트 · 규칙 문자열은 비밀이 아니다 — 거짓 양성 방지).
# 그 밖의 키(username · note · token 이 아닌 값)는 비밀이 아니다
function Add-SecretField { param($k, $v)
  if ($null -eq $v) { return }
  $s = [string]$v
  if ([string]::IsNullOrEmpty($s)) { return }
  if (SEq $k 'password') { $script:NSecrets.Add($s); return }
  # url · acl 은 8자 미만이면 바늘로 쓰지 않는다(숫자형 값 시나리오의 짧은 문자열이 환경 변수 · 경로에 우연히 걸리는 거짓 양성 — 비밀 모양이 아니다)
  if ($s.Length -lt 8) { return }
  if (SEq $k 'url') {
    $script:NFulls.Add($s)
    $i = -1; if ($s.Length -gt 8) { $i = $s.IndexOf(':', 8) }
    $j = $s.LastIndexOf('@')
    if ($i -ge 0 -and $j -gt $i + 8) { $script:NSecrets.Add($s.Substring($i + 1, $j - $i - 1)) }
    return }
  if (SEq $k 'users.acl') {
    $script:NFulls.Add($s)
    foreach ($m in [regex]::Matches($s, '#([0-9A-Fa-f]{16,})')) { $script:NFulls.Add($m.Groups[1].Value) } } }
function Build-Needles {
  $script:NSecrets = [System.Collections.Generic.List[string]]::new()
  $script:NFulls = [System.Collections.Generic.List[string]]::new()
  $script:NSecrets.Add($global:FAKE_ROOT)
  foreach ($x in $global:ExtraSecrets) { $script:NSecrets.Add([string]$x) }
  foreach ($path in @($global:Kv.Keys)) { foreach ($ver in @($global:Kv[$path]['versions'].Values)) {
      $d = $ver['data']; if ($null -eq $d) { continue }
      foreach ($k in @($d.Keys)) { Add-SecretField $k $d[$k] } } }
  foreach ($b in $global:PutBodies) { try { $o = $b | ConvertFrom-Json -AsHashtable -DateKind String; foreach ($k in @($o.Keys)) { Add-SecretField $k $o[$k] } } catch { } }
  $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
  foreach ($s in $script:NSecrets) {
    [void]$set.Add($s)
    [void]$set.Add([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s)))
    if ($s.Length -gt 8) { for ($i = 0; $i -le $s.Length - 8; $i++) { [void]$set.Add($s.Substring($i, 8)) } } }
  # 해시도 바늘이다(원칙 e "값 · 해시 출력 금지" — T054 리뷰 O1 변이 ③): 비밀마다 SHA-256 hex 의 대문자 · 소문자 전체 + 앞 16자
  # (블록의 $sha 는 UTF-8 바이트의 대문자 hex 다. 앞 16자 = 잘라 낸 "지문" 출력까지 잡는다 — 16 hex 우연 일치는 사실상 0)
  foreach ($s in @($script:NSecrets)) {
    $hx = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s)))
    foreach ($h in @($hx, $hx.ToLowerInvariant())) { [void]$set.Add($h); [void]$set.Add($h.Substring(0, 16)) } }
  # url · acl 전문(조각 없이) + acl 안의 hex(대 · 소문자 전체 + 앞 16자)
  foreach ($s in @($script:NFulls)) {
    [void]$set.Add($s)
    if ($s -cmatch '\A[0-9A-Fa-f]{16,}\z') { foreach ($h in @($s.ToLowerInvariant(), $s.ToUpperInvariant())) { [void]$set.Add($h); [void]$set.Add($h.Substring(0, 16)) } } }
  , @($set) }
function First-Needle { param([string]$text, $needles) foreach ($n in @($needles)) { if ($text.Contains($n)) { return $n } }; $null }
function Error-Text {
  $sb = [System.Text.StringBuilder]::new()
  foreach ($e in @($global:Error)) {
    [void]$sb.AppendLine([string]$e)
    if ($e -is [System.Management.Automation.ErrorRecord]) {
      [void]$sb.AppendLine($e.Exception.ToString()); [void]$sb.AppendLine([string]$e.TargetObject)
      if ($null -ne $e.ErrorDetails) { [void]$sb.AppendLine([string]$e.ErrorDetails) } }
    elseif ($e -is [Exception]) { [void]$sb.AppendLine($e.ToString()) } }
  $sb.ToString() }
# pwsh -File 로 돌리면 이 스크립트의 script 범위가 곧 global 범위다 — 시나리오 도중 하네스가 다시 만드는 내부 상태(바늘 목록 등)는 제외한다
$HarnessGlobals = @('Kv', 'F', 'Inputs', 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls', 'PutBodies', 'Violations', 'ExtraSecrets', 'TokenPolicies',
  'ClipHistory', 'ClipHistoryMode', 'VaultTokenFile', 'NowIso', 'PreRunPuts', 'CaseChecks', 'LastText', 'LastItems', 'GvBefore', 'EXPECTED_ADDR', 'FAKE_ROOT', 'FAKE_PRE_TOKEN', 'FAKE_WRONG_TOKEN', 'FAKE_SHARE',
  'NSecrets', 'NFulls', 'Policy', 'PolicyPaths', 'Error', 'ItemCount', 'AllowDelete', 'Deleted', 'WhatIfPreference', 'PSDefaultParameterValues', 'OrigWhatIf', 'OrigPSDPV',
  'RbCode', 'RbWhy', 'RenderSbx', 'RenderWhy')
function Flat-Text { param($v)
  if ($null -eq $v) { return '' }
  if ($v -is [string]) { return $v }
  if ($v -is [System.Collections.IDictionary]) { return ((@($v.Keys) | ForEach-Object { [string]$_ + '=' + [string]$v[$_] }) -join "`n") }
  if ($v -is [System.Collections.IEnumerable]) { return ((@($v) | ForEach-Object { [string]$_ }) -join "`n") }
  [string]$v }
function Snapshot-Globals { $h = @{}; foreach ($g in @(Get-Variable -Scope Global)) { $h[$g.Name] = $g.Value }; $h }
function Globals-Hit { param($before, $needles)
  # 이 시나리오 동안 새로 생기거나 바뀐 전역 변수만 본다(하네스 자신의 모의 상태는 제외) — 맞으면 변수 이름만 돌려준다(값은 내지 않는다)
  foreach ($g in @(Get-Variable -Scope Global)) {
    if ($HarnessGlobals -contains $g.Name) { continue }
    if ($before.ContainsKey($g.Name) -and [object]::ReferenceEquals($before[$g.Name], $g.Value)) { continue }
    $hit = First-Needle (Flat-Text $g.Value) $needles
    if ($null -ne $hit) { return "`$$($g.Name)(바늘 길이 $($hit.Length))" } }
  $null }
function Env-Text { param([string[]]$skip = @()) ((@(Get-ChildItem Env: | Where-Object { $skip -notcontains $_.Name }) | ForEach-Object { [string]$_.Value }) -join "`n") }

# ---------------------------------------------------------------- 시나리오 실행기
$Results = [System.Collections.ArrayList]::new()
# -Gate: S12 의 관문 단언(파서 오류 · 명령 · 정적 형식 · $Host · 리다이렉트 허용 목록) — 하나라도 FAIL 이거나 빠지면 런타임 시나리오를 돌리지 않는다
function Check { param([string]$name, [bool]$ok, [string]$detail = '', [switch]$Gate) [void]$global:CaseChecks.Add([pscustomobject]@{ name = $name; ok = $ok; detail = $detail; gate = [bool]$Gate }) }
function Finish-Case { param([string]$id, [string]$desc, [string]$text)
  $bad = @($global:CaseChecks | Where-Object { -not $_.ok })
  [void]$Results.Add([pscustomobject]@{ id = $id; desc = $desc; pass = ($bad.Count -eq 0 -and $global:CaseChecks.Count -gt 0); total = $global:CaseChecks.Count; failed = $bad.Count
      detail = (($bad | Select-Object -First 6 | ForEach-Object { $_.name + $(if ($_.detail) { ' [' + $_.detail + ']' } else { '' }) }) -join ' | ') })
  if ($bad.Count -gt 0 -or ($Show -and $id -like $Show)) { Write-Host "---- $id 화면 출력 ----`n$text`n" -ForegroundColor DarkGray } }
# finally 요약 표의 경로 행 전부(요약 머리 뒤에서 7경로 중 하나 + 공백으로 시작하는 줄 — 출력 순서 그대로)
function Summary-Rows {
  $after = $false; $rows = @()
  foreach ($l in ([string]$global:LastText -split "`n")) {
    if ($l.StartsWith($SUMMARY, [StringComparison]::Ordinal)) { $after = $true; continue }
    if ($after -and @($PATHS | Where-Object { $l.StartsWith($_.path + ' ', [StringComparison]::Ordinal) }).Count -gt 0) { $rows += $l } }
  , $rows }
# 그 경로의 요약 행(없으면 ''). Summary-Rows 는 ", $rows" 로 배열 하나를 내므로 대입으로 한 겹 벗긴다(@(Summary-Rows) 는 배열을 원소 1개로 감싼다)
function Summary-Row { param([string]$path)
  $rows = Summary-Rows
  foreach ($l in @($rows)) { if (([string]$l).StartsWith($path + ' ', [StringComparison]::Ordinal)) { return [string]$l } }
  '' }
function Ev-Index { param([string]$e, [int]$from = 0) for ($i = [Math]::Max(0, $from); $i -lt $global:Events.Count; $i++) { if (SEq $global:Events[$i] $e) { return $i } }; -1 }
function Ev-First { param([string]$prefix, [int]$from = 0) for ($i = [Math]::Max(0, $from); $i -lt $global:Events.Count; $i++) { if (([string]$global:Events[$i]).StartsWith($prefix, [StringComparison]::Ordinal)) { return $i } }; -1 }
# 그 env 의 kv 에 저장된 사용자 비밀번호 맵(사용자 → password — acl 기대값 계산용)
function Kv-PwMap { param([string]$ev)
  $m = @{}
  foreach ($e in $USERS) { if (SEq $e.env $ev) { $d = KvData $e.path; if ($null -ne $d -and $d.Contains('password')) { $m[$e.user] = [string]$d['password'] } } }
  $m }
# 생성된 경로: v1 · 키 집합 정확히 경로의 키(B3) · password = base64url 43자(B2 생성기) · url = 'redis://' + 사용자 + ':' + 같은 password + '@dragonfly-<env>.data.svc:6379/0' ·
#   users.acl = 그 env 의 kv 사용자 비밀번호로 독립 계산한 렌더(Acl-For)와 바이트 일치 + 로더 모의 통과
function Check-Created { param($e)
  $d = KvData $e.path
  Check "$($e.path): v1" ((KvCur $e.path) -eq 1) "current=$(KvCur $e.path)"
  if ($null -eq $d) { Check "$($e.path): 데이터 있음" $false; return }
  $names = @(@($d.Keys) | ForEach-Object { [string]$_ })
  $want = @($e.keys)
  Check "$($e.path): 키 집합 = $($want -join ' · ')(정확히 — B3)" ($names.Count -eq $want.Count -and @($want | Where-Object { -not ($names -ccontains $_) }).Count -eq 0) ($names -join ',')
  if (SEq $e.role 'acl') {
    $a = [string]$d['users.acl']
    $m = Kv-PwMap $e.env
    Check "$($e.path): users.acl = 그 env 의 kv 사용자 비밀번호로 독립 계산한 렌더(Acl-For)와 바이트 일치(B2 · B4)" (SEq $a (Acl-For $e.env $m))
    $why = Test-AclLoader $a
    Check "$($e.path): Dragonfly 로더 모의 통과" ([string]::IsNullOrEmpty($why)) $why
    return }
  $pw = [string]$d['password']
  Check "$($e.path): password = base64url 43자(A–Z a–z 0–9 - _)" ($pw -cmatch $RE_PW) "len=$($pw.Length)"
  if ($want -ccontains 'url') { Check "$($e.path): url = 'redis://' + 사용자 + ':' + 같은 password + '@dragonfly-$($e.env).data.svc:6379/0'(B2)" (SEq $d['url'] (Url-For $e $pw)) } }
# 값 불변: 버전 v1 그대로 · 저장된 데이터의 키와 값이 기대(사전)와 Ordinal 로 같다
function Check-Unchanged { param($e, $want)
  Check "$($e.path): 버전 불변(v1)" ((KvCur $e.path) -eq 1) "current=$(KvCur $e.path)"
  $d = KvData $e.path
  $ok = ($null -ne $d -and $null -ne $want -and @($d.Keys).Count -eq @($want.Keys).Count)
  if ($ok) { foreach ($k in @($want.Keys)) { if (-not $d.Contains($k) -or -not (SEq $d[$k] $want[$k])) { $ok = $false } } }
  Check "$($e.path): 값 불변" $ok }
function Check-Absent { param($e) Check "$($e.path): 쓰지 않음(경로 없음)" (-not $global:Kv.ContainsKey($e.path)) }
function Check-WriteOrder { param([object[]]$creates)
  $iStatus = Ev-Index 'vault:status'; $iSecure = Ev-Index 'read:secure'; $iLookup = Ev-Index 'vault:token-lookup'
  Check '순서: status → root 토큰 입력 → token lookup' ($iStatus -ge 0 -and $iSecure -gt $iStatus -and $iLookup -gt $iSecure)
  $iSeed = Ev-Index 'read:plain'
  Check '순서: 쓰기 확인 정지점(seed) 이 있다' ($iSeed -ge 0)
  $before = 0
  foreach ($e in $PATHS) { $j = Ev-Index "vault:meta-get:$($e.path)"; if ($j -gt $iLookup -and $j -lt $iSeed) { $before++ } }
  Check "순서: $($PATHS.Count)경로 판정(metadata get) 이 전부 정지점 앞(판정 단계 분리)" ($before -eq $PATHS.Count) "정지점 앞 $before"
  $firstPut = Ev-First 'vault:put:'
  Check '순서: 첫 put 이 정지점 뒤' ($firstPut -gt $iSeed) "put=$firstPut seed=$iSeed"
  $cursor = $iSeed; $ok = $true
  foreach ($e in $creates) {
    $ip = Ev-Index "vault:put:$($e.path)" $cursor
    $ig = Ev-Index "vault:kv-get:$($e.path)" ($ip + 1)
    $im = Ev-Index "vault:meta-get:$($e.path)" ($ig + 1)
    $nx = Ev-First 'vault:put:' ($ip + 1)
    if ($ip -lt 0 -or $ig -lt 0 -or $im -lt 0 -or ($nx -ge 0 -and $im -gt $nx)) { $ok = $false }
    $cursor = [Math]::Max($cursor, $im) }
  Check '순서: 경로마다 put → 되읽기(kv get) → metadata 확인 → 다음 경로' $ok
  # 쓰기 순서(결정 B4): put 이 일어난 경로 순서 = 기대 목록 순서(env 마다 사용자 → acl · dev → prod)
  $puts = @($global:Events | Where-Object { ([string]$_).StartsWith('vault:put:', [StringComparison]::Ordinal) } | ForEach-Object { ([string]$_).Substring(10) })
  $wantSeq = @($creates | ForEach-Object { $_.path })
  Check "쓰기 순서 = $($wantSeq -join ' → ')(env 마다 사용자 → acl · dev → prod — B4)" (SEq ($puts -join '|') ($wantSeq -join '|')) ($puts -join ' → ') }
function Run-Case {
  param([string]$Id, [string]$Desc, [scriptblock]$Setup = $null, [string[]]$Inputs = @(), [string]$Expect = 'ok',
    [string[]]$Want = @(), [string[]]$NotWant = @(), [scriptblock]$Post = $null, [hashtable]$PreEnv = @{})
  Assert-Guard
  Reset-Mocks
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  if ($Setup) { try { & $Setup } catch { Check 'setup 실행' $false ([string]$_.Exception.Message) } }
  foreach ($x in $Inputs) { $global:Inputs.Enqueue($x) }
  foreach ($k in @($PreEnv.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value ([string]$PreEnv[$k]) }
  $global:Error.Clear()
  $gvBefore = Snapshot-Globals
  $global:GvBefore = $gvBefore
  $items = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''
  if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $BlockPath) {
    # 출력은 나오는 즉시 하류로 흐른다(한 스레드 파이프라인) — ItemCount = 지금까지 화면에 나온 출력 수(모의 Read-Host 가 호출 시점의 값을 남긴다)
    $global:ItemCount = 0
    try { & $BlockPath *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } }
    catch { $threw = $true; $errMsg = [string]$_.Exception.Message } }
  else { $threw = $true; $errMsg = '블록 파일 없음' }
  $lines = @($items | ForEach-Object { [string]$_ })
  if ($threw) { $lines += "THROW: $errMsg" }
  $text = $lines -join "`n"
  $global:LastText = $text
  $global:LastItems = $items
  # ---- 결과 · 기대 줄
  if (SEq $Expect 'ok') { Check 'outcome: 완주(throw 없음)' (-not $threw) $errMsg }
  else { Check "outcome: throw '$Expect'" ($threw -and $errMsg.Contains($Expect)) $errMsg }
  foreach ($w in $Want) { Check "want: $w" $text.Contains($w) }
  foreach ($w in $NotWant) { Check "notwant: $w" (-not $text.Contains($w)) }
  # ---- 공통 사후 조건 1: 비밀 노출 0(모든 면 · 8자 조각 · 해시까지)
  $needles = Build-Needles
  $skipEnv = @(); if ($PreEnv.ContainsKey('VAULT_TOKEN')) { $skipEnv += 'VAULT_TOKEN' }
  $surfaces = [ordered]@{ '화면(모든 스트림)' = $text; '프롬프트' = ($global:Prompts -join "`n"); 'argv' = ($global:ArgvLog -join "`n"); '클립보드' = ($global:ClipValues -join "`n")
    '$Error' = (Error-Text); '환경 변수' = (Env-Text $skipEnv) }
  foreach ($sn in $surfaces.Keys) { $hit = First-Needle ([string]$surfaces[$sn]) $needles; Check "노출 0: $sn" ($null -eq $hit) $(if ($null -ne $hit) { "바늘(길이 $($hit.Length)) 발견" } else { '' }) }
  $gHit = Globals-Hit $gvBefore $needles
  Check '노출 0: 전역 변수(이 시나리오에서 새로 생기거나 바뀐 것)' ($null -eq $gHit) ([string]$gHit)
  # ---- 공통 사후 조건 2: 환경 정리(조건부)
  if ($PreEnv.ContainsKey('VAULT_TOKEN')) { Check 'env: 시작 전 VAULT_TOKEN 은 건드리지 않는다' (SEq $env:VAULT_TOKEN $PreEnv['VAULT_TOKEN']) }
  else { Check 'env: VAULT_TOKEN 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_TOKEN)) }
  if ($PreEnv.ContainsKey('VAULT_ADDR') -and -not (SEq $PreEnv['VAULT_ADDR'] $global:EXPECTED_ADDR)) { Check 'env: 시작 전 (다른 값의) VAULT_ADDR 은 건드리지 않는다' (SEq $env:VAULT_ADDR $PreEnv['VAULT_ADDR']) }
  else { Check 'env: VAULT_ADDR 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_ADDR)) }
  # ---- 공통 사후 조건 3: 실물·허용 목록·스트림·클립보드·입력 위생
  Check '위반 0(허용 목록 밖 vault · kubectl · -field · argv 값 · put 밖 stdin)' ($global:Violations.Count -eq 0) $(if ($global:Violations.Count) { [string]$global:Violations[0] } else { '' })
  Check '함정 표식 0(실물 vault/kubectl 실행 파일이 불리지 않았다)' ((Trap-Markers) -eq 0)
  $succ = @($items | Where-Object { -not ($_ -is [System.Management.Automation.InformationRecord] -or $_ -is [System.Management.Automation.WarningRecord] -or $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord]) })
  Check '성공 스트림 0(출력은 Write-Host/Write-Warning 뿐 — 돌려받지 않은 값이 화면에 찍힐 경로 없음)' ($succ.Count -eq 0) "성공 스트림 $($succ.Count)개"
  Check '클립보드에는 공백만 쓴다' (@($global:ClipValues | Where-Object { -not (SEq $_ ' ') }).Count -eq 0)
  $secretReads = @($global:ReadLog | Where-Object { ([string]$_.value).StartsWith('hvs.', [StringComparison]::Ordinal) -or ([string]$_.value).Contains('MOCK') -or ([string]$_.value).Trim().StartsWith('hvs.', [StringComparison]::Ordinal) })
  Check '비밀 입력은 전부 -AsSecureString' (@($secretReads | Where-Object { -not $_.secure }).Count -eq 0)
  Check '입력은 전부 가려진다(비밀 = -AsSecureString · 정지점 단어 = -MaskInput — 정지점에 비밀을 잘못 붙여도 화면 · 스크롤백에 남지 않는다)' (@($global:ReadLog | Where-Object { -not $_.secure -and -not $_.masked }).Count -eq 0)
  Check 'kv put 은 전부 -cas=0 + stdin(-)' (@($global:PutCalls | Where-Object { $null -eq $_.cas -or $_.cas -ne 0 -or -not $_.stdin }).Count -eq 0)
  $iSeedAny = Ev-Index 'read:plain'; $iPut = Ev-First 'vault:put:'
  Check '쓰기 확인(seed 정지점) 전 put 0' ($iPut -lt 0 -or ($iSeedAny -ge 0 -and $iPut -gt $iSeedAny))
  Check 'finally 요약 출력(성공·실패 어느 쪽이든)' ($text.Contains($SUMMARY) -and $text.Contains('창 종료 체크리스트'))
  Check '첫 동작 = Set-PSDebug -Off 1회(창에 켜져 있던 -Trace 가 이후 대입 — 토큰 · 비밀번호 — 을 찍지 않게 · T054 리뷰 O6)' ((Ev-Index 'psdebug:off') -eq 0 -and @($global:Events | Where-Object { SEq $_ 'psdebug:off' }).Count -eq 1) $(if ($global:Events.Count) { "첫 이벤트 $($global:Events[0])" } else { '이벤트 0' })
  # root 토큰 프롬프트까지 간 시나리오: INFO vault CLI 줄(명령 종류 · 경로)이 그 프롬프트보다 먼저 화면에 나와야 한다 — 런북은 "토큰을 붙이기 전에 종류가 Application 인지 본다"를
  # 이 순서에 기댄다(T054 리뷰 r3 O2)
  $secRead = @($global:ReadLog | Where-Object { $_.secure })
  if ($secRead.Count -gt 0) {
    $iInfo = -1
    for ($i = 0; $i -lt $items.Count; $i++) { if (([string]$items[$i]).StartsWith('INFO vault CLI: ', [StringComparison]::Ordinal)) { $iInfo = $i; break } }
    Check '순서: INFO vault CLI 줄이 root 토큰 프롬프트보다 먼저 화면에 나온다(토큰을 붙이기 전 명령 종류 확인 · T054 리뷰 r3 O2)' ($iInfo -ge 0 -and $iInfo -lt [int]$secRead[0].items) "INFO 출력 순번 $iInfo · 토큰 프롬프트 시점 출력 수 $($secRead[0].items)" }
  if (SEq $Expect 'ok') { Check '입력 전부 소비(정지점 누락 없음)' ($global:Inputs.Count -eq 0) "남은 입력 $($global:Inputs.Count)" }
  if ($Post) { try { & $Post } catch { Check 'post 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  foreach ($k in @($PreEnv.Keys)) { if (Microsoft.PowerShell.Management\Test-Path -LiteralPath ('Env:' + $k)) { Remove-Item -LiteralPath ('Env:' + $k) } }
  Finish-Case $Id $Desc $text }

# ---------------------------------------------------------------- S12 정적 구조·위생(블록을 실행하지 않는다 — 모든 시나리오보다 먼저 돈다)
$AllowedCmds = @('vault', 'Read-Host', 'Write-Host', 'Write-Warning', 'Set-Clipboard', 'Get-ItemProperty', 'Test-Path', 'Get-ChildItem', 'Remove-Item', 'Remove-Variable',
  'Get-Command', 'ConvertFrom-Json', 'ConvertTo-Json', 'ConvertFrom-SecureString', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug')
# 관문 단언 수(파서 오류 0 · 명령 · 정적 형식 · $Host · 파일 리다이렉트 허용 목록) — Static-Gate 는 이 수만큼 있고 전부 PASS 일 때만 통과다(빠진 관문 = FAIL)
$GateCount = 5
$AllowedHelpers = @('eq', 'has', 'sha', 'stop', 'readSecret', 'firstErr', 'parseJson', 'prop', 'render', 'state', 'judge', 'write')
$AllowedTypes = @('string', 'System.String', 'Convert', 'System.Convert', 'StringComparison', 'System.StringComparison', 'System.Security.Cryptography.RandomNumberGenerator',
  'System.Security.Cryptography.SHA256', 'System.Text.Encoding', 'Array', 'System.Array', 'object', 'System.Object', 'System.Collections.Generic.List[object]', 'Math', 'System.Math')
$FinallyCmds = @('Write-Host', 'Write-Warning', 'Remove-Item', 'Remove-Variable', 'Set-Clipboard')
function Finally-Emitters { param($stmts)
  $bad = @()
  foreach ($s in @($stmts)) {
    if ($s -is [System.Management.Automation.Language.AssignmentStatementAst]) { continue }
    if ($s -is [System.Management.Automation.Language.PipelineAst]) {
      $last = $s.PipelineElements[$s.PipelineElements.Count - 1]
      if ($last -is [System.Management.Automation.Language.CommandAst]) { if ($FinallyCmds -notcontains [string]$last.GetCommandName()) { $bad += "L$($s.Extent.StartLineNumber) $($last.GetCommandName())" } }
      elseif ($last -is [System.Management.Automation.Language.CommandExpressionAst] -and $last.Expression -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and (@('RemoveAt', 'Clear') -contains [string]$last.Expression.Member.Value)) { }
      else { $bad += "L$($s.Extent.StartLineNumber) 값 출력 가능 식" }
      continue }
    if ($s -is [System.Management.Automation.Language.IfStatementAst]) {
      foreach ($c in $s.Clauses) { $bad += Finally-Emitters $c.Item2.Statements }
      if ($null -ne $s.ElseClause) { $bad += Finally-Emitters $s.ElseClause.Statements }
      continue }
    if ($s -is [System.Management.Automation.Language.TryStatementAst]) {
      $bad += Finally-Emitters $s.Body.Statements
      foreach ($cc in $s.CatchClauses) { $bad += Finally-Emitters $cc.Body.Statements }
      if ($null -ne $s.Finally) { $bad += Finally-Emitters $s.Finally.Statements }
      continue }
    if ($s -is [System.Management.Automation.Language.LoopStatementAst]) { $bad += Finally-Emitters $s.Body.Statements; continue }
    $bad += "L$($s.Extent.StartLineNumber) 알 수 없는 문장($($s.GetType().Name))" }
  , $bad }
# $Host 규칙용: 변수 이름(범위 · 드라이브 접두를 뗀 것 — $global:Host · $variable:Host · ${Host} 모두 Host). VariablePath.UnqualifiedPath 는 공개 속성이 아니다
function Var-Name { param($n) $u = [string]$n.VariablePath.UserPath; $i = $u.LastIndexOf(':'); if ($i -ge 0) { $u.Substring($i + 1) } else { $u } }
# $Host 규칙용: $node 가 $expr 를 대상으로 하는 인스턴스 멤버 $name(호출 여부 $invoke · 호출이면 인자 0)인가
function Is-Member { param($node, $expr, [string]$name, [bool]$invoke)
  if ($null -eq $node -or $node -isnot [System.Management.Automation.Language.MemberExpressionAst] -or $node.Static) { return $false }
  if (-not [object]::ReferenceEquals($node.Expression, $expr)) { return $false }
  if (-not (SEq $node.Member.Extent.Text $name)) { return $false }
  $isInv = $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst]
  if ($invoke -ne $isInv) { return $false }
  if ($isInv -and $null -ne $node.Arguments -and $node.Arguments.Count -gt 0) { return $false }
  $true }
# 입력 버퍼 비움 규칙용(T054 리뷰 O1): 문장 $s 가 "$Host.UI.RawUI.FlushInputBuffer()" 한 식만으로 된 파이프라인 문장인가 — AST 노드로 본다
# (주석 · 문자열 안의 글자는 노드가 아니다)
function Is-FlushStmt { param($s)
  if ($s -isnot [System.Management.Automation.Language.PipelineAst] -or $s.PipelineElements.Count -ne 1) { return $false }
  $ce = $s.PipelineElements[0]
  if ($ce -isnot [System.Management.Automation.Language.CommandExpressionAst]) { return $false }
  $m3 = $ce.Expression
  if ($m3 -isnot [System.Management.Automation.Language.InvokeMemberExpressionAst]) { return $false }
  $m2 = $m3.Expression
  if ($m2 -isnot [System.Management.Automation.Language.MemberExpressionAst]) { return $false }
  $m1 = $m2.Expression
  if ($m1 -isnot [System.Management.Automation.Language.MemberExpressionAst]) { return $false }
  $v = $m1.Expression
  ($v -is [System.Management.Automation.Language.VariableExpressionAst]) -and [string]::Equals((Var-Name $v), 'Host', [StringComparison]::OrdinalIgnoreCase) -and
    (Is-Member $m1 $v 'UI' $false) -and (Is-Member $m2 $m1 'RawUI' $false) -and (Is-Member $m3 $m2 'FlushInputBuffer' $true) }
# 그 문장 자체이거나, 본문이 그 문장 하나뿐인 try(catch 는 무엇이든 — 블록의 모양 try { …FlushInputBuffer() } catch { })인가
function Is-FlushOrTry { param($s)
  if (Is-FlushStmt $s) { return $true }
  ($s -is [System.Management.Automation.Language.TryStatementAst]) -and $s.Body.Statements.Count -eq 1 -and (Is-FlushStmt $s.Body.Statements[0]) }
# S12 관문 판정(T054 리뷰 O8): 관문 단언이 $GateCount 개 있고 전부 PASS 면 '' — 아니면 실패 사유(단언 이름 · 세부)
function Static-Gate { param([int]$Expected = $GateCount)
  $g = @($global:CaseChecks | Where-Object { $_.gate })
  $bad = @($g | Where-Object { -not $_.ok } | ForEach-Object { $_.name + $(if ($_.detail) { ' [' + $_.detail + ']' } else { '' }) })
  if ($g.Count -ne $Expected) { $bad += "관문 단언 $($g.Count)개(기대 $Expected)" }
  $bad -join ' · ' }
# ---- 정적 판정 함수(시드 블록 S12 · 런북 블록 R1/R2 공통 — 위반 목록을 돌려준다, 빈 목록 = 통과)
# 최상위가 "& { … }" 한 문이면 그 안쪽 스크립트블록 AST, 아니면 $null
function Find-Inner { param($ast)
  $stmts = $ast.EndBlock.Statements
  if ($stmts.Count -ne 1 -or $null -ne $ast.BeginBlock -or $null -ne $ast.ProcessBlock -or $null -ne $ast.ParamBlock) { return $null }
  if ($stmts[0] -isnot [System.Management.Automation.Language.PipelineAst] -or $stmts[0].PipelineElements.Count -ne 1) { return $null }
  $c = $stmts[0].PipelineElements[0]
  if ($c -is [System.Management.Automation.Language.CommandAst] -and $c.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and $c.CommandElements.Count -eq 1 -and $c.CommandElements[0] -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { return $c.CommandElements[0].ScriptBlock }
  $null }
function Bad-Cmds { param($ast, [string[]]$allowed, [string[]]$helpers, $inner)
  $bad = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
    if ($c.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Dot) { $bad += "L$($c.Extent.StartLineNumber) dot-source"; continue }
    $nm = $c.GetCommandName()
    if ($null -ne $nm) { if (-not (@($allowed | Where-Object { [string]::Equals($_, $nm, [StringComparison]::OrdinalIgnoreCase) }).Count)) { $bad += "L$($c.Extent.StartLineNumber) $nm" }; continue }
    $first = $c.CommandElements[0]
    if ($first -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -and [object]::ReferenceEquals($first.ScriptBlock, $inner)) { continue }
    if ($first -is [System.Management.Automation.Language.VariableExpressionAst] -and (@($helpers) -ccontains $first.VariablePath.UserPath)) { continue }
    $bad += "L$($c.Extent.StartLineNumber) & $($first.Extent.Text)" }
  , $bad }
function Bad-Types { param($ast, [string[]]$allowed)
  $bad = @()
  foreach ($m in $ast.FindAll({ param($n) ($n -is [System.Management.Automation.Language.MemberExpressionAst]) -and $n.Static -and $n.Expression -is [System.Management.Automation.Language.TypeExpressionAst] }, $true)) {
    $tn = $m.Expression.TypeName.FullName
    if (-not (@($allowed | Where-Object { [string]::Equals($_, $tn, [StringComparison]::OrdinalIgnoreCase) }).Count)) { $bad += "L$($m.Extent.StartLineNumber) [$tn]::" } }
  , $bad }
function Bad-Host { param($ast)
  $bad = @()
  foreach ($v in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and ([string]::Equals((Var-Name $n), 'Host', [StringComparison]::OrdinalIgnoreCase) -or [string]::Equals((Var-Name $n), 'ExecutionContext', [StringComparison]::OrdinalIgnoreCase)) }, $true)) {
    $m1 = $v.Parent; $m2 = $null; $m3 = $null
    if ($null -ne $m1) { $m2 = $m1.Parent }
    if ($null -ne $m2) { $m3 = $m2.Parent }
    $ok = [string]::Equals((Var-Name $v), 'Host', [StringComparison]::OrdinalIgnoreCase) -and (Is-Member $m1 $v 'UI' $false) -and (Is-Member $m2 $m1 'RawUI' $false) -and (Is-Member $m3 $m2 'FlushInputBuffer' $true)
    if (-not $ok) {
      $top = $v
      while ($null -ne $top.Parent -and $top.Parent -is [System.Management.Automation.Language.MemberExpressionAst] -and [object]::ReferenceEquals($top.Parent.Expression, $top)) { $top = $top.Parent }
      $t = $top.Extent.Text; if ($t.Length -gt 60) { $t = $t.Substring(0, 60) + '…' }
      $bad += "L$($v.Extent.StartLineNumber) $t" } }
  , $bad }
function Bad-Redir { param($ast)
  $bad = @()
  foreach ($r in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FileRedirectionAst] }, $true)) { if (-not (SEq $r.Location.Extent.Text '$null')) { $bad += "L$($r.Extent.StartLineNumber) $($r.Extent.Text)" } }
  , $bad }
# 비밀처럼 보이는 상수(대·소문자·숫자 섞인 32자+ 연속) — 앞 6자만 돌려준다
function Bad-Secrets { param([string]$text)
  , @([regex]::Matches($text, '[A-Za-z0-9_\-+/=]{32,}') | Where-Object { $_.Value -cmatch '[A-Z]' -and $_.Value -cmatch '[a-z]' -and $_.Value -cmatch '[0-9]' } | ForEach-Object { $_.Value.Substring(0, 6) + '…' }) }
# ---- acl 렌더(결정 B2) 정적 · 단위 시험 도구
# 블록 AST 에서 $render 대입문(정확히 1개 · 오른쪽 = 스크립트블록 리터럴)의 ScriptBlockExpressionAst. 아니면 $null — 사유는 $global:RenderWhy
function Get-RenderAst { param($ast)
  $global:RenderWhy = ''
  $as = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) 'render') }, $true))
  if ($as.Count -ne 1) { $global:RenderWhy = "`$render 대입문 $($as.Count)개(기대 1)"; return $null }
  $r = $as[0].Right
  if ($r -is [System.Management.Automation.Language.CommandExpressionAst] -and $r.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { return $r.Expression }
  $global:RenderWhy = '$render 의 오른쪽이 스크립트블록 리터럴이 아니다'
  $null }
# 순수 함수 위반 목록: 명령 호출(& $eq 같은 헬퍼 호출 포함) · param · 지역 대입 · foreach 변수 · $null/$true/$false 밖의 변수 참조
function Render-Impurities { param($sbx)
  $bad = @()
  $sb = $sbx.ScriptBlock
  foreach ($c in $sb.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) { $t = $c.Extent.Text; if ($t.Length -gt 40) { $t = $t.Substring(0, 40) + '…' }; $bad += "L$($c.Extent.StartLineNumber) 명령 $t" }
  $ok = @('null', 'true', 'false')
  if ($null -ne $sb.ParamBlock) { $ok += @($sb.ParamBlock.Parameters | ForEach-Object { Var-Name $_.Name }) }
  $ok += @($sb.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) | ForEach-Object { Var-Name $_.Left })
  $ok += @($sb.FindAll({ param($n) $n -is [System.Management.Automation.Language.ForEachStatementAst] }, $true) | ForEach-Object { Var-Name $_.Variable })
  foreach ($v in $sb.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true)) {
    $nm = Var-Name $v
    if (-not ($ok -ccontains $nm)) { $bad += "L$($v.Extent.StartLineNumber) 바깥 변수 `$$nm" } }
  , $bad }
# U01–U04: S12 가 찾은 $render 스크립트블록만 떼어 내(블록 전체는 실행하지 않는다) 본문에 넘긴다 — 관문 통과 뒤에만 부른다
function Run-Unit { param([string]$Id, [string]$Desc, [scriptblock]$Body)
  Assert-Guard
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  if ($null -eq $global:RenderSbx) { Check '렌더 스크립트블록 추출(S12)' $false ([string]$global:RenderWhy) }
  else { try { & $Body ($global:RenderSbx.ScriptBlock.GetScriptBlock()) } catch { Check '단위 시험 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  Finish-Case $Id $Desc '' }
# 렌더 결과 단언(결정 B2 · build-notes 「T057」 D6 · 계약 §ACL 표): 독립 계산과 Ordinal 일치 + 바이트 규칙 + 줄 규칙 + 로더 모의 + 평문 0
function Check-Render { param([string]$ev, $m, $out)
  Check '렌더 결과 = 문자열' ($out -is [string]) $(if ($null -eq $out) { 'null' } else { $out.GetType().Name })
  $s = [string]$out
  Check '렌더 결과 = 독립 계산(Acl-For — 바이트마다 x2 hex · 문자열 리터럴)과 Ordinal 일치' (SEq $s (Acl-For $ev $m))
  $b = [Text.Encoding]::UTF8.GetBytes($s)
  Check 'CR 0' (@($b | Where-Object { $_ -eq 13 }).Count -eq 0)
  Check 'TAB 0' (@($b | Where-Object { $_ -eq 9 }).Count -eq 0)
  Check 'ASCII 인쇄 문자 + LF 만(BOM · 제어 문자 · 비 ASCII 0)' (@($b | Where-Object { ($_ -lt 0x20 -and $_ -ne 10) -or $_ -gt 0x7E }).Count -eq 0)
  Check '끝 = LF 정확히 1개' ($s.EndsWith("`n") -and -not $s.EndsWith("`n`n"))
  $body = $s; if ($s.EndsWith("`n")) { $body = $s.Substring(0, $s.Length - 1) }
  $lines = @($body.Split("`n"))
  $nWant = 3; if (SEq $ev 'dev') { $nWant = 4 }
  Check "줄 수 = $nWant($ev)" ($lines.Count -eq $nWant) "줄 $($lines.Count)"
  Check '빈 줄 0 · 앞뒤 공백 0 · 연속 공백 0(토큰 사이 공백 1개)' (@($lines | Where-Object { $_.Length -eq 0 -or $_.StartsWith(' ') -or $_.EndsWith(' ') -or $_.Contains('  ') }).Count -eq 0)
  Check '줄마다 토큰 ≥ 4(로더 MaterializeFileContents)' (@($lines | Where-Object { @($_.Split(' ')).Count -lt 4 }).Count -eq 0)
  Check '1줄 = USER default OFF -@all(없으면 로더가 nopass default 를 만든다)' ($lines.Count -gt 0 -and (SEq $lines[0] 'USER default OFF -@all'))
  $order = @('admin', 'identity-admin'); if (SEq $ev 'dev') { $order += 'sample-pod' }
  $rule = @{ 'admin' = '~* &* +@all'; 'identity-admin' = '~revoked:* ~identity-admin:* +@all'; 'sample-pod' = '%R~revoked:* ~sample-pod:* +@all' }
  for ($i = 0; $i -lt $order.Count; $i++) {
    $u = $order[$i]
    $l = ''; if ($i + 1 -lt $lines.Count) { $l = $lines[$i + 1] }
    $tk = @($l.Split(' '))
    Check "$($i + 2)줄 = USER $u ON #<소문자 hex 64> $($rule[$u])(계약 §ACL 표 · 글자 단위)" ($tk.Count -ge 5 -and (SEq $tk[0] 'USER') -and (SEq $tk[1] $u) -and (SEq $tk[2] 'ON') -and ($tk[3] -cmatch '\A#[0-9a-f]{64}\z') -and (SEq (@($tk | Select-Object -Skip 4) -join ' ') $rule[$u]))
    Check "$($i + 2)줄 # 뒤 = SHA-256(UTF-8 password) 소문자 hex(독립 계산 Hex-Lower)" ($tk.Count -ge 4 -and (SEq $tk[3] ('#' + (Hex-Lower ([string]$m[$u]))))) }
  Check 'prod 렌더에 sample-pod 0(dev 전용 검사 계정 — 계약)' ((SEq $ev 'dev') -or -not $s.Contains('sample-pod'))
  $why = Test-AclLoader $s
  Check 'Dragonfly v1.40.1 로더 모의 통과(MaterializeFileContents · 토큰 종류 · default 줄)' ([string]::IsNullOrEmpty($why)) $why
  $leak = @(@($m.Values) | Where-Object { $_ -is [string] -and $_.Length -ge 8 -and ($s.Contains($_) -or $s.Contains($_.Substring(0, 8))) })
  Check '렌더 결과에 평문 비밀번호(전체 · 앞 8자) 0 — 해시만' ($leak.Count -eq 0) }
function Run-Static {
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  $exists = Microsoft.PowerShell.Management\Test-Path -LiteralPath $BlockPath
  Check '블록 파일 존재' $exists
  $bytes = [byte[]]@(); if ($exists) { $bytes = [IO.File]::ReadAllBytes($BlockPath) }
  Check '비어 있지 않다' ($bytes.Length -gt 0)
  Check 'BOM 없음' (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF))
  Check 'CR 0' (@($bytes | Where-Object { $_ -eq 13 }).Count -eq 0)
  # 키 이벤트로 들어오는 붙여넣기(conhost 우클릭 · Windows Terminal)에서 PSReadLine 은 탭을 완성 키로 처리한다 — 탭 하나가 붙여 넣은 코드를 바꿀 수 있다(T054 리뷰 r3 O4)
  Check 'TAB 0(붙여넣기 탭 완성 방지)' (@($bytes | Where-Object { $_ -eq 9 }).Count -eq 0)
  $utf8ok = $true; try { [void][Text.UTF8Encoding]::new($false, $true).GetString($bytes) } catch { $utf8ok = $false }
  Check 'UTF-8 유효' $utf8ok
  # 끝 2바이트가 } LF 이면 } 뒤 개행은 정확히 1개다(T045 정본의 끝 3바이트 = 0A 7D 0A — } 앞의 0A 는 앞 줄의 끝)
  Check '끝 = } + LF 1개(7D 0A)' ($bytes.Length -ge 2 -and $bytes[$bytes.Length - 2] -eq 0x7D -and $bytes[$bytes.Length - 1] -eq 0x0A)
  $text = [Text.Encoding]::UTF8.GetString($bytes)
  $lines = $text.Split("`n")
  Check '첫 줄 = & {' ($lines.Count -gt 0 -and (SEq $lines[0] '& {'))
  $blank = 0; for ($i = 0; $i -lt $lines.Count - 1; $i++) { if ($lines[$i].Trim().Length -eq 0) { $blank++ } }
  Check '빈 줄 0(파일 전체)' ($blank -eq 0 -and $lines.Count -gt 1) "빈 줄 $blank"
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tk, [ref]$er)
  Check '파서 오류 0' ($er.Count -eq 0) $(if ($er.Count) { "L$($er[0].Extent.StartLineNumber) $($er[0].Message)" } else { '' }) -Gate
  $stmts = $ast.EndBlock.Statements
  $inner = Find-Inner $ast
  Check '최상위 문장 1개 = & { … }' ($null -ne $inner)
  Check '} 뒤 남는 문자 0' ($null -ne $inner -and $stmts[0].Extent.EndOffset -eq $text.Length - 1)
  # ---- 관문 4종(명령 · 정적 형식 · $Host · 리다이렉트 허용 목록 — T054 리뷰 O8): 파일 전체 AST 에서 늘 잰다($inner 가 없어도 — 그때 & { … } 자체가 위반으로 잡힌다).
  #      Static-Gate 가 이 넷 + 파서 오류 0 이 전부 PASS 여야 런타임 시나리오를 돌린다(판정 함수는 런북 블록 R1 · R2 와 같은 것을 쓴다)
  $badCmd = Bad-Cmds $ast $AllowedCmds $AllowedHelpers $inner
  Check '명령 허용 목록(vault · 출력 · env/클립보드/JSON 기본 cmdlet · Set-PSDebug · 헬퍼 스크립트블록만 — Start-Transcript·Out-File·Invoke-Expression·Start-Process · 절대 경로 실행 파일 등 0)' ($badCmd.Count -eq 0) ($badCmd -join '; ') -Gate
  $badType = Bad-Types $ast $AllowedTypes
  Check '정적 .NET 호출 허용 목록([Console]·[IO.File]·[Environment]·[Diagnostics.Process] 등 0)' ($badType.Count -eq 0) ($badType -join '; ') -Gate
  # $Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양으로만 — 호스트 UI 직접 쓰기($Host.UI.WriteLine · WriteErrorLine ·
  # $ExecutionContext.Host.UI …)는 *>&1 로 잡히지 않아 런타임 노출 검사가 보지 못한다(T054 리뷰 O1). 변수에 담는 별칭($h = $Host)도 위반.
  $badHost = Bad-Host $ast
  Check '$Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양만(호스트 UI 직접 쓰기 · 별칭 0 — *>&1 밖의 화면 경로)' ($badHost.Count -eq 0) ($badHost -join '; ') -Gate
  $badRedir = Bad-Redir $ast
  Check '파일 리다이렉트 0($null 만)' ($badRedir.Count -eq 0) ($badRedir -join '; ') -Gate
  # ---- 본문(& { … }) 구조 — 최상위가 & { … } 가 아니면 FAIL 하나로 남긴다
  if ($null -eq $inner) { Check '본문 구조 검사(첫 문장 · try/finally)' $false '최상위 & { … } 아님 — 본문 검사 생략' }
  else {
    $b0 = @($inner.EndBlock.Statements)
    $psd = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Set-PSDebug', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
    $t0 = ''; if ($b0.Count -gt 0) { $t0 = $b0[0].Extent.Text; if ($t0.Length -gt 40) { $t0 = $t0.Substring(0, 40) + '…' } }
    Check '본문 첫 문장 = Set-PSDebug -Off · Set-PSDebug 는 그 1곳뿐(붙여넣기 창에 켜져 있던 -Trace 가 뒤의 대입 — 토큰 · 비밀번호 — 을 찍기 전에 끈다 · T054 리뷰 O6)' ($b0.Count -gt 0 -and (SEq $b0[0].Extent.Text 'Set-PSDebug -Off') -and $psd -eq 1) "첫 문장: $t0 · Set-PSDebug $psd 곳"
    # 붙여넣기 창의 세션 상태($WhatIfPreference = $true · $ConfirmPreference Low/Medium · $PSDefaultParameterValues 의 -WhatIf)는 finally 의 Remove-Item Env: 와 Set-Clipboard 를
    # 예외 없이 건너뛰게 한다(T054 리뷰 r3 O5 실측 — root 토큰이 env · 클립보드에 남는다). 블록은 try 앞의 직계 문장으로 셋을 자기 범위에 고정해야 한다(런타임은 S10e 가 재현)
    $pre0 = @($b0 | ForEach-Object { $_.Extent.Text })
    $fix0 = @('$WhatIfPreference = $false', "`$ConfirmPreference = 'High'", '$PSDefaultParameterValues = @{}')
    $fixMissing = @($fix0 | Where-Object { $f = $_; @($pre0 | Where-Object { SEq $_ $f }).Count -ne 1 })
    Check '본문 직계 문장으로 세션 설정 고정: $WhatIfPreference = $false · $ConfirmPreference = ''High'' · $PSDefaultParameterValues = @{} 각 1문장(붙여넣기 창의 WhatIf · 확인 · 기본 매개변수 값이 finally 의 env 제거 · 클립보드 비우기를 조용히 무력화하지 못하게 · T054 리뷰 r3 O5)' ($fixMissing.Count -eq 0) ($fixMissing -join '; ')
    $tries = @($b0 | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] })
    Check '본문 try 1개 + finally' ($tries.Count -eq 1 -and $null -ne $tries[0].Finally)
    if ($tries.Count -eq 1 -and $null -ne $tries[0].Finally) {
      $fe = Finally-Emitters $tries[0].Finally.Statements
      Check 'finally 는 Write-Host/Write-Warning · Remove-* · Set-Clipboard 만(성공 스트림 출력 없음 — Ctrl+C 때 끊기지 않게)' ($fe.Count -eq 0) ($fe -join '; ')
      $fs = @($tries[0].Finally.Statements | ForEach-Object { $_.Extent.Text })
      Check 'finally 첫 두 문장 = 블록이 만든 VAULT_TOKEN · VAULT_ADDR 제거(Ctrl+C 를 거듭 눌러 finally 가 끊겨도 root 토큰부터 사라진다)' ($fs.Count -ge 2 -and $fs[0].StartsWith('if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN', [StringComparison]::Ordinal) -and $fs[1].StartsWith('if ($addrOwned) { Remove-Item Env:VAULT_ADDR', [StringComparison]::Ordinal)) $(if ($fs.Count -gt 0) { '첫 문장: ' + $fs[0].Substring(0, [Math]::Min(40, $fs[0].Length)) } else { '' }) } }
  # Read-Host 는 $stop/$readSecret 헬퍼 안에서만. 그 헬퍼 본문(직계 문장)에서 Read-Host 를 담은 문장의 "바로 앞" 직계 문장이 입력 버퍼 비움이어야 한다 —
  # $Host.UI.RawUI.FlushInputBuffer() 한 식 문장 또는 본문이 그 문장 하나뿐인 try. AST 로 본다: 주석 · 문자열 안의 글자 · 조건문(if) 안 · throw 뒤(도달 불가) ·
  # Read-Host 뒤의 호출은 인정하지 않는다(T054 리뷰 O1 — 텍스트 검색은 주석 처리한 호출로도 통과했다)
  $badRead = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)) {
    # Read-Host 를 감싸는 가장 가까운 스크립트블록 식을 찾고, 그 스크립트블록이 대입되는 변수 이름을 본다($ans = Read-Host 같은 안쪽 대입은 건너뛴다)
    $p = $c.Parent; $owner = $null; $sbx = $null
    while ($null -ne $p -and $null -eq $sbx) { if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { $sbx = $p }; $p = $p.Parent }
    if ($null -ne $sbx) {
      $p = $sbx.Parent
      while ($null -ne $p) {
        if ($p -is [System.Management.Automation.Language.AssignmentStatementAst] -and $p.Left -is [System.Management.Automation.Language.VariableExpressionAst]) { $owner = $p.Left.VariablePath.UserPath; break }
        if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { break }
        $p = $p.Parent } }
    if (-not (@('stop', 'readSecret') -ccontains [string]$owner) -or $null -eq $sbx) { $badRead += "L$($c.Extent.StartLineNumber) 헬퍼 밖 Read-Host"; continue }
    $eb = $sbx.ScriptBlock.EndBlock
    $body = @(); if ($null -ne $eb) { $body = @($eb.Statements) }
    $iR = -1
    for ($i = 0; $i -lt $body.Count; $i++) { if ($c.Extent.StartOffset -ge $body[$i].Extent.StartOffset -and $c.Extent.EndOffset -le $body[$i].Extent.EndOffset) { $iR = $i; break } }
    if ($iR -lt 1 -or -not (Is-FlushOrTry $body[$iR - 1])) { $badRead += "L$($c.Extent.StartLineNumber) Read-Host 바로 앞 직계 문장이 입력 버퍼 비움(`$Host.UI.RawUI.FlushInputBuffer())이 아니다" } }
  Check 'Read-Host 는 정지점 헬퍼 안에서만 + 바로 앞 직계 문장이 입력 버퍼 비움(AST — 주석 · 문자열 · 조건문 안 · throw 뒤 · Read-Host 뒤 = 위반)' ($badRead.Count -eq 0) ($badRead -join '; ')
  $rhCount = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
  Check 'Read-Host 2곳($stop · $readSecret)' ($rhCount -eq 2) "Read-Host $rhCount 곳"
  # vault 호출의 정적 모양: kv put 은 "-cas=0" + 마지막 인자 - · -field 0 · kv 하위 명령 허용 목록
  $badVault = @(); $putN = 0
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) }, $true)) {
    $el = @($c.CommandElements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
    $sig = ($el | Select-Object -First 3) -join ' '
    foreach ($x in $el) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { $badVault += "L$($c.Extent.StartLineNumber) -field" } }
    if ((SEq (At $el 0) 'kv') -and (SEq (At $el 1) 'put')) {
      $putN++
      if (-not (Has-Flag $el '-cas=0') -or -not (SEq $el[$el.Count - 1] '-')) { $badVault += "L$($c.Extent.StartLineNumber) kv put 모양(-cas=0 · stdin -)" } }
    elseif (-not ($sig.StartsWith('version') -or $sig.StartsWith('status -format=json') -or $sig.StartsWith('token lookup -format=json') -or $sig.StartsWith('kv metadata get') -or $sig.StartsWith('kv get -format=json'))) { $badVault += "L$($c.Extent.StartLineNumber) vault $sig" } }
  Check 'vault 호출 모양(kv put = "-cas=0" … - · -field 0 · 하위 명령 허용 목록 · delete/destroy/patch 0)' ($badVault.Count -eq 0 -and $putN -eq 1) "$($badVault -join '; ') put=$putN"
  # ---- acl 렌더 정적 규칙(결정 B2 · B8 정적 추가): $render 대입문 정확히 1개(스크립트블록 리터럴) · 순수 함수(명령 호출 0 · 바깥 변수 참조 0 — 입력은 param 둘뿐) ·
  #      렌더 코드에 CR(백틱 r · [char]13 · 0x0D) 0 · NewLine([Environment]::NewLine 등) 0 · 줄은 -join 백틱 n 으로 잇는다 · hex 는 ToLowerInvariant 로 소문자 · 블록 전체 백틱 r 0
  #      (U01–U04 가 이 스크립트블록을 떼어 내 고정 입력으로 돌린다 — S12 가 찾은 AST 를 $global:RenderSbx 에 둔다)
  $global:RenderSbx = Get-RenderAst $ast
  Check '$render 대입문 정확히 1개 · 오른쪽 = 스크립트블록 리터럴(acl 렌더 순수 함수 — B2)' ($null -ne $global:RenderSbx) ([string]$global:RenderWhy)
  if ($null -ne $global:RenderSbx) {
    $rt = $global:RenderSbx.Extent.Text
    Check 'acl 렌더 코드에 CR 0(백틱 r · [char]13 · 0x0D 없음 — CR 이 붙은 토큰 하나 = aclfile 전체 미적재 = 무인증 기동)' (-not $rt.Contains('`r') -and -not $rt.Contains('[char]13') -and -not $rt.Contains('0x0D') -and -not $rt.Contains('0x0d') -and -not $rt.Contains('\r'))
    Check 'acl 렌더 코드에 NewLine 0([Environment]::NewLine — Windows 에서 CRLF)' (-not $rt.Contains('NewLine'))
    Check 'acl 렌더 코드가 줄을 -join 백틱 n 으로 잇는다' ($rt.Contains('-join "`n"'))
    Check 'acl 렌더 코드가 hex 를 ToLowerInvariant 로 소문자로 만든다(로더 · ACL SAVE 와 같은 모양)' ($rt.Contains('.ToLowerInvariant()'))
    $imp = Render-Impurities $global:RenderSbx
    Check 'acl 렌더 = 순수 함수(명령 호출 0 · 바깥 변수 참조 0 — 입력은 param 둘뿐 · 헬퍼 $eq 등도 부르지 않는다)' ($imp.Count -eq 0) ($imp -join '; ') }
  Check '블록 전체에 백틱 r 0(CR 을 만드는 표기 없음)' (-not $text.Contains('`r'))
  # 비밀처럼 보이는 상수 0(가짜 값은 하네스에만)
  Check 'MOCK 문자열 0(가짜 값은 하네스 파일에만)' (-not $text.Contains('MOCK'))
  $ent = Bad-Secrets $text
  Check '비밀처럼 보이는 상수 0(대·소문자·숫자 섞인 32자+ 연속)' ($ent.Count -eq 0) ($ent -join ', ')
  Check 'Vault 토큰 모양 상수 0(hvs.<영숫자>)' (-not ($text -cmatch 'hvs\.[A-Za-z0-9]'))
  Check 'Start-Transcript 0' (-not $text.Contains('Start-Transcript')) }

# ---------------------------------------------------------------- 런북 「정리 판단」 두 블록: 추출 · 정적(R1 · R2) · 런타임(GA · GB) — T054 · T056 하네스 그대로(표식 · 허용 경로만 T057)
# 런북 블록은 운영자 창(vault-unseal.md §0 절대 규칙 1 로 VAULT_ADDR · VAULT_TOKEN 이 들어 있는 창 D)에서 통째로 붙여 넣는 & { … } 한 문이다 — 시드 블록과 달리
# env 를 만들지도 지우지도 않고, Read-Host 는 평문(경로 · 재입력 — 비밀 아님)이다. 그래서 공통 사후 조건이 시드 블록(Run-Case)과 다르다(Run-RbCase).
# Set-Clipboard · Write-Warning: 첫 Read-Host 전 클립보드 비움 `try { Set-Clipboard -Value ' ' } catch { Write-Warning … }` 한 문장만을 위한 허용이다(T054 리뷰 r6 S1)
$RbAllowedCmds = @('vault', 'Read-Host', 'Write-Host', 'Write-Warning', 'Set-Clipboard', 'ConvertFrom-Json', 'Where-Object', 'ForEach-Object', 'Sort-Object')
$RbAllowedTypes = @('string', 'System.String', 'StringComparison', 'System.StringComparison')
# 관문 단언 수(추출 · 파서 오류 0 · 명령 · 정적 형식 · $Host · 리다이렉트) — 하나라도 FAIL 이면 그 블록의 런타임 시나리오(GA 또는 GB)를 돌리지 않는다
$RbGateCount = 6
# 런북 텍스트에서 표식 주석이 든 ```powershell 코드 펜스 정확히 하나를 찾아, 펜스의 들여쓰기를 뗀 본문을 돌려준다(끝 LF 1개). 못 찾거나 둘 이상이면 $null — 사유는 $global:RbWhy[표식]
function Get-RbBlock { param([string]$marker)
  $global:RbWhy[$marker] = ''
  if (-not (Microsoft.PowerShell.Management\Test-Path -LiteralPath $RunbookPath)) { $global:RbWhy[$marker] = "런북 파일 없음: $RunbookPath"; return $null }
  $lines = [IO.File]::ReadAllText($RunbookPath, [Text.UTF8Encoding]::new($false)).Split("`n")
  $found = @()
  $i = 0
  while ($i -lt $lines.Count) {
    $m = [regex]::Match($lines[$i], '^(\s*)```powershell\s*$')
    if (-not $m.Success) { $i++; continue }
    $indent = $m.Groups[1].Value
    $body = @(); $j = $i + 1; $closed = $false
    while ($j -lt $lines.Count) {
      if ($lines[$j] -cmatch ('^' + [regex]::Escape($indent) + '```\s*$')) { $closed = $true; break }
      $body += $lines[$j]; $j++ }
    if ($closed -and @($body | Where-Object { $_.Contains($marker) }).Count -gt 0) { $found += [pscustomobject]@{ line = $i + 1; indent = $indent; body = $body } }
    $i = $j + 1 }
  if ($found.Count -ne 1) { $global:RbWhy[$marker] = "표식 $marker 가 든 powershell 코드 펜스 $($found.Count)개(기대 1)"; return $null }
  $f = $found[0]
  $out = @(foreach ($l in $f.body) { if ($l.StartsWith($f.indent, [StringComparison]::Ordinal)) { $l.Substring($f.indent.Length) } else { $l } })
  ($out -join "`n") + "`n" }
# Read-Host 바로 앞 직계 문장이 입력 버퍼 비움인가 — 헬퍼 소유를 요구하지 않는 일반형(런북 블록은 본문 직계 문장에서 Read-Host 를 부른다). AST 로 본다(주석 · 문자열 안 = 노드 아님)
function Bad-ReadFlush { param($ast)
  $bad = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)) {
    $p = $c.Parent
    while ($null -ne $p -and -not ($p -is [System.Management.Automation.Language.StatementBlockAst] -or $p -is [System.Management.Automation.Language.NamedBlockAst])) { $p = $p.Parent }
    $body = @(); if ($null -ne $p) { $body = @($p.Statements) }
    $iR = -1
    for ($i = 0; $i -lt $body.Count; $i++) { if ($c.Extent.StartOffset -ge $body[$i].Extent.StartOffset -and $c.Extent.EndOffset -le $body[$i].Extent.EndOffset) { $iR = $i; break } }
    if ($iR -lt 1 -or -not (Is-FlushOrTry $body[$iR - 1])) { $bad += "L$($c.Extent.StartLineNumber) Read-Host 바로 앞 직계 문장이 입력 버퍼 비움(`$Host.UI.RawUI.FlushInputBuffer())이 아니다" } }
  , $bad }
# vault 호출 모양(런북 블록): 하위 명령 + 첫 플래그까지(요소 4개)가 허용 접두 중 하나로 시작해야 한다 · -field 0. 점검 블록 = metadata get · kv get 만(put · delete 0) / 삭제 블록 = metadata get · metadata delete 만
function Bad-VaultRb { param($ast, [string[]]$allowed)
  $bad = @()
  foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) }, $true)) {
    $el = @($c.CommandElements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
    $sig = ($el | Select-Object -First 4) -join ' '
    foreach ($x in $el) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { $bad += "L$($c.Extent.StartLineNumber) -field" } }
    if (-not @($allowed | Where-Object { $sig.StartsWith($_, [StringComparison]::Ordinal) }).Count) { $bad += "L$($c.Extent.StartLineNumber) vault $sig" } }
  , $bad }
# R1 · R2: 런북 블록 정적 검사 + 관문. 돌려주는 값 = 관문 실패 사유('' = 통과 → GA/GB 를 돌린다)
function Run-RbStatic { param([string]$Id, [string]$Desc, [string]$Marker, [string[]]$AllowedVault, [int]$ReadHosts)
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  $code = Get-RbBlock $Marker
  Check "런북 코드 펜스에서 추출(표식 $Marker 가 든 powershell 펜스 정확히 1개 · 펜스 들여쓰기 제거)" ($null -ne $code) ([string]$global:RbWhy[$Marker]) -Gate
  if ($null -eq $code) { $code = '' }
  $global:RbCode[$Marker] = $code
  $lines = $code.Split("`n")
  Check '첫 줄 = & {' ($lines.Count -gt 0 -and (SEq $lines[0] '& {'))
  Check "표식 주석 = & { 다음 줄(# $Marker …)" ($lines.Count -gt 1 -and $lines[1].TrimStart().StartsWith('# ' + $Marker, [StringComparison]::Ordinal))
  $nonEmpty = @($lines | Where-Object { $_.Length -gt 0 })
  Check '끝 줄 = }' ($nonEmpty.Count -gt 0 -and (SEq $nonEmpty[$nonEmpty.Count - 1] '}'))
  $blank = 0; for ($i = 0; $i -lt $lines.Count - 1; $i++) { if ($lines[$i].Trim().Length -eq 0) { $blank++ } }
  Check '빈 줄 0(붙여넣기 — 기본 콘솔 호스트의 빈 줄 종료 대비)' ($blank -eq 0 -and $lines.Count -gt 1) "빈 줄 $blank"
  Check 'TAB 0(붙여넣기 탭 완성 방지)' (-not $code.Contains("`t"))
  Check 'CR 0' (-not $code.Contains("`r"))
  $tk = $null; $er = $null
  $ast = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tk, [ref]$er)
  Check '파서 오류 0' ($er.Count -eq 0) $(if ($er.Count) { "L$($er[0].Extent.StartLineNumber) $($er[0].Message)" } else { '' }) -Gate
  $inner = Find-Inner $ast
  Check '최상위 문장 1개 = & { … }' ($null -ne $inner)
  $badCmd = Bad-Cmds $ast $RbAllowedCmds @() $inner
  Check '명령 허용 목록(vault · Read-Host · Write-Host · Write-Warning · Set-Clipboard · ConvertFrom-Json · Where-Object · ForEach-Object · Sort-Object 만 — Start-Transcript · Out-File · Invoke-Expression · kubectl · 절대 경로 실행 파일 등 0)' ($badCmd.Count -eq 0) ($badCmd -join '; ') -Gate
  $badType = Bad-Types $ast $RbAllowedTypes
  Check '정적 .NET 호출 허용 목록([string]:: · [StringComparison]:: 만)' ($badType.Count -eq 0) ($badType -join '; ') -Gate
  $badHost = Bad-Host $ast
  Check '$Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양만(호스트 UI 직접 쓰기 · 별칭 0)' ($badHost.Count -eq 0) ($badHost -join '; ') -Gate
  $badRedir = Bad-Redir $ast
  Check '파일 리다이렉트 0($null 만)' ($badRedir.Count -eq 0) ($badRedir -join '; ') -Gate
  $badRead = Bad-ReadFlush $ast
  Check 'Read-Host 바로 앞 직계 문장이 입력 버퍼 비움(AST — 주석 · 문자열 · if 안 · throw 뒤 = 위반)' ($badRead.Count -eq 0) ($badRead -join '; ')
  $rhCount = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
  Check "Read-Host $ReadHosts 곳 · 전부 평문(경로 · 재입력은 비밀이 아니다 — -AsSecureString · -MaskInput 0)" ($rhCount -eq $ReadHosts -and -not $code.Contains('-AsSecureString') -and -not $code.Contains('-MaskInput')) "Read-Host $rhCount 곳"
  # 첫 Read-Host 전 클립보드 비움(T054 리뷰 r6 S1/O1): 운영자는 vault-unseal.md §0 절대 규칙 1 로 root 토큰을 PM 에서 붙인 뒤 이 블록을 돌린다 — 프롬프트(경로 · 재입력)는
  # 평문이라 오붙임(우클릭 · Ctrl+V)이 나면 토큰이 화면 · 스크롤백에 남는다. 블록은 첫 Read-Host 전에 `Set-Clipboard -Value ' '` 로 클립보드를 덮고(정확히 1문장 · try 안),
  # 실패하면 catch 의 Write-Warning(값 없음 — "클립보드를 비우지 못했다 … root 토큰 …")을 낸다. AST 로 본다(런타임 순서 · 값은 Run-RbCase 공통 단언)
  $clips = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Set-Clipboard', [StringComparison]::OrdinalIgnoreCase) }, $true))
  $warns = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Write-Warning', [StringComparison]::OrdinalIgnoreCase) }, $true))
  $reads = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true))
  $firstRead = -1; foreach ($r in $reads) { if ($firstRead -lt 0 -or $r.Extent.StartOffset -lt $firstRead) { $firstRead = $r.Extent.StartOffset } }
  $clipTry = $null; $warnInCatch = $false
  if ($clips.Count -eq 1) { $p = $clips[0].Parent; while ($null -ne $p -and $null -eq $clipTry) { if ($p -is [System.Management.Automation.Language.TryStatementAst]) { $clipTry = $p }; $p = $p.Parent } }
  if ($null -ne $clipTry) { foreach ($cc in $clipTry.CatchClauses) { foreach ($w in $warns) { if ($w.Extent.StartOffset -ge $cc.Extent.StartOffset -and $w.Extent.EndOffset -le $cc.Extent.EndOffset -and $w.Extent.Text.Contains('클립보드를 비우지 못했다') -and $w.Extent.Text.Contains('root 토큰')) { $warnInCatch = $true } } } }
  Check "첫 Read-Host 전 클립보드 비움: Set-Clipboard -Value ' ' 문장 정확히 1개 · 첫 Read-Host 앞 · try 안 · catch 의 Write-Warning 1개(클립보드를 비우지 못했다 … root 토큰 — 값 없음)(§0 규칙 1 로 붙인 토큰의 오붙임 방어 · T054 리뷰 r6 S1)" ($clips.Count -eq 1 -and (SEq $clips[0].Extent.Text "Set-Clipboard -Value ' '") -and $firstRead -ge 0 -and $clips[0].Extent.StartOffset -lt $firstRead -and $warns.Count -eq 1 -and $warnInCatch) "Set-Clipboard $($clips.Count) 곳 · Write-Warning $($warns.Count) 곳"
  $badVault = Bad-VaultRb $ast $AllowedVault
  Check "vault 호출 모양(허용 접두: $($AllowedVault -join ' / ') · 그 밖 0 · -field 0)" ($badVault.Count -eq 0) ($badVault -join '; ')
  Check 'MOCK 문자열 0' (-not $code.Contains('MOCK'))
  $ent = Bad-Secrets $code
  Check '비밀처럼 보이는 상수 0(대·소문자·숫자 섞인 32자+ 연속)' ($ent.Count -eq 0) ($ent -join ', ')
  Check 'Vault 토큰 모양 상수 0(hvs.<영숫자>)' (-not ($code -cmatch 'hvs\.[A-Za-z0-9]'))
  Check 'Start-Transcript 0 · env 쓰기 0(VAULT_ADDR · VAULT_TOKEN 은 창의 것 — 블록이 만들지도 지우지도 않는다)' (-not $code.Contains('Start-Transcript') -and -not $code.Contains('$env:') -and -not $code.Contains('Env:'))
  # T057 허용 목록 = 계약 7경로 정확히(Ordinal 집합) — 다른 과제(T054 6경로 · T056 2경로 등)의 경로가 섞이면 안 된다(블록 안 kv/ 문자열 상수 집합 = $PATHS 경로 집합)
  $litSet = [System.Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
  foreach ($n in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.StringConstantExpressionAst] -and ([string]$x.Value).StartsWith('kv/', [StringComparison]::Ordinal) }, $true)) { [void]$litSet.Add([string]$n.Value) }
  $wantSet = [System.Collections.Generic.SortedSet[string]]::new([StringComparer]::Ordinal)
  foreach ($e in $PATHS) { [void]$wantSet.Add([string]$e.path) }
  Check "허용 경로 상수 = 계약 7경로 정확히($(@($wantSet) -join ' · ') — 그 밖의 kv/ 상수 0)" ($litSet.SetEquals($wantSet)) (@($litSet) -join ' · ')
  Finish-Case $Id $Desc ''
  Static-Gate -Expected $RbGateCount }
# GA · GB: 추출한 런북 블록을 [scriptblock]::Create 로 그대로 돌린다 — 창 상태(VAULT_ADDR · VAULT_TOKEN)는 하네스가 넣고 끝나면 지운다. 공통 사후 조건은 아래
function Run-RbCase {
  param([string]$Id, [string]$Desc, [string]$Marker, [scriptblock]$Setup = $null, [string[]]$Inputs = @(), [string]$Expect = 'ok',
    [string[]]$Want = @(), [string[]]$NotWant = @(), [scriptblock]$Post = $null, [switch]$AllowDelete)
  Assert-Guard
  Reset-Mocks
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  $global:AllowDelete = [bool]$AllowDelete
  if ($Setup) { try { & $Setup } catch { Check 'setup 실행' $false ([string]$_.Exception.Message) } }
  foreach ($x in $Inputs) { $global:Inputs.Enqueue($x) }
  $env:VAULT_ADDR = $global:EXPECTED_ADDR
  $env:VAULT_TOKEN = $global:FAKE_ROOT
  $global:Error.Clear()
  $gvBefore = Snapshot-Globals
  $global:GvBefore = $gvBefore
  $items = [System.Collections.ArrayList]::new()
  $threw = $false; $errMsg = ''
  $code = [string]$global:RbCode[$Marker]
  if ([string]::IsNullOrEmpty($code)) { $threw = $true; $errMsg = '런북 블록 추출 실패(R1 · R2 참조) — 실행하지 않았다' }
  else {
    $sb = [scriptblock]::Create($code)
    $global:ItemCount = 0
    try { & $sb *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } }
    catch { $threw = $true; $errMsg = [string]$_.Exception.Message } }
  $lines = @($items | ForEach-Object { [string]$_ })
  if ($threw) { $lines += "THROW: $errMsg" }
  $text = $lines -join "`n"
  $global:LastText = $text
  $global:LastItems = $items
  if (SEq $Expect 'ok') { Check 'outcome: 완주(throw 없음)' (-not $threw) $errMsg }
  else { Check "outcome: throw '$Expect'" ($threw -and $errMsg.Contains($Expect)) $errMsg }
  foreach ($w in $Want) { Check "want: $w" $text.Contains($w) }
  foreach ($w in $NotWant) { Check "notwant: $w" (-not $text.Contains($w)) }
  # ---- 공통 사후 조건 1: 비밀 노출 0(저장된 password · url · acl(hex) · 7경로 밖 소비 중 경로의 가짜 값 · root 토큰 — 8자 조각 · 해시까지) — 점검 블록은 값을 읽지만 키 이름만 낸다
  $needles = Build-Needles
  $surfaces = [ordered]@{ '화면(모든 스트림)' = $text; '프롬프트' = ($global:Prompts -join "`n"); 'argv' = ($global:ArgvLog -join "`n"); '$Error' = (Error-Text); '환경 변수' = (Env-Text @('VAULT_TOKEN')) }
  foreach ($sn in $surfaces.Keys) { $hit = First-Needle ([string]$surfaces[$sn]) $needles; Check "노출 0: $sn" ($null -eq $hit) $(if ($null -ne $hit) { "바늘(길이 $($hit.Length)) 발견" } else { '' }) }
  $gHit = Globals-Hit $gvBefore $needles
  Check '노출 0: 전역 변수(이 시나리오에서 새로 생기거나 바뀐 것)' ($null -eq $gHit) ([string]$gHit)
  # ---- 공통 사후 조건 2: 쓰기 경계 · 실물 · 스트림 · 창 상태
  Check '위반 0(허용 목록 밖 vault · kubectl · 점검 블록의 kv metadata delete · argv 값)' ($global:Violations.Count -eq 0) $(if ($global:Violations.Count) { [string]$global:Violations[0] } else { '' })
  Check '함정 표식 0(실물 vault/kubectl 실행 파일이 불리지 않았다)' ((Trap-Markers) -eq 0)
  $succ = @($items | Where-Object { -not ($_ -is [System.Management.Automation.InformationRecord] -or $_ -is [System.Management.Automation.WarningRecord] -or $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord]) })
  Check '성공 스트림 0(출력은 Write-Host 뿐 — vault 응답 · 삭제 응답이 그대로 화면에 흐르지 않는다)' ($succ.Count -eq 0) "성공 스트림 $($succ.Count)개"
  Check 'kv put 0(런북 블록은 값을 쓰지 않는다)' ($global:PutCalls.Count -eq 0)
  if (-not $AllowDelete) { Check 'vault 쓰기 명령 0(① 점검 블록 — kv metadata delete · put · destroy 호출 없음)' ((Ev-First 'vault:meta-delete:') -lt 0 -and (Ev-First 'vault:put:') -lt 0) }
  Check '창의 VAULT_ADDR · VAULT_TOKEN 은 그대로(블록이 만든 것이 아니다 — 건드리지 않는다 · 창 종료 체크리스트가 지운다)' ((SEq $env:VAULT_ADDR $global:EXPECTED_ADDR) -and (SEq $env:VAULT_TOKEN $global:FAKE_ROOT))
  Check '입력은 전부 평문 Read-Host(경로 · 재입력 — 비밀 아님) · 보안 입력 0' (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0)
  # 첫 Read-Host 전 클립보드 비움(T054 리뷰 r6 S1/O1): §0 절대 규칙 1 로 붙인 root 토큰이 클립보드에 남은 채 평문 프롬프트에 오붙임되는 경로를 막는다 —
  # 모의 Set-Clipboard 의 clip:set 이 모의 Read-Host 의 read:plain 보다 앞이고, 기록된 클립보드 값은 전부 공백 하나(SEq Ordinal)여야 한다
  $iClip = Ev-Index 'clip:set'; $iRead = Ev-Index 'read:plain'
  Check '첫 Read-Host 전 클립보드 비움(clip:set ≥ 1 · 값은 공백만 — 첫 clip:set 이 첫 read:plain 보다 앞 · §0 규칙 1 로 붙인 root 토큰의 오붙임 방어 · T054 리뷰 r6 S1)' ($iClip -ge 0 -and $iRead -ge 0 -and $iClip -lt $iRead -and @($global:ClipValues | Where-Object { -not (SEq $_ ' ') }).Count -eq 0) "clip:set=$iClip · read:plain=$iRead · 클립보드 기록 $($global:ClipValues.Count)개"
  if (SEq $Expect 'ok') { Check '입력 전부 소비(정지점 누락 없음)' ($global:Inputs.Count -eq 0) "남은 입력 $($global:Inputs.Count)" }
  if ($Post) { try { & $Post } catch { Check 'post 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  foreach ($v in @('VAULT_ADDR', 'VAULT_TOKEN')) { Remove-Item -LiteralPath ('Env:' + $v) -ErrorAction SilentlyContinue }
  Finish-Case $Id $Desc $text }

# ---------------------------------------------------------------- 시나리오
$GateMsg = ''
try {
  Write-Host "=== T057 모의 하네스 — 블록: $BlockPath ==="
  # 하네스 자체 전제(어긋나면 하네스 결함 → 예외 — 시나리오가 엉뚱한 이유로 FAIL 하지 않게): live 가짜 값 5개 = base64url 43자 · 서로 다르다 · '_' 가 든 값이 있다(B3 문자 집합
  #   고정 — T056 리뷰 r1 H2) · 독립 hex 도우미(Hex-Lower)가 SHA-256 표준 벡터("abc")와 맞는다 · 독립 렌더(Acl-For)가 로더 모의를 통과한다
  foreach ($e in $USERS) { if (-not (([string]$LIVE_PW[$e.path]) -cmatch $RE_PW)) { throw "하네스 결함: LIVE_PW[$($e.path)] 가 base64url 43자가 아니다" } }
  if ((Uniq @($USERS | ForEach-Object { $LIVE_PW[$_.path] })) -ne 5) { throw '하네스 결함: LIVE_PW 5개가 서로 다르지 않다' }
  if (@($USERS | Where-Object { ([string]$LIVE_PW[$_.path]).Contains('_') }).Count -eq 0) { throw "하네스 결함: LIVE_PW 에 '_' 가 든 값이 없다('_' 수용 고정 — T056 리뷰 r1 H2)" }
  if (-not (SEq (Hex-Lower 'abc') 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')) { throw '하네스 결함: Hex-Lower 가 SHA-256 표준 벡터(abc)와 다르다' }
  foreach ($ev in 'dev', 'prod') { $w = Test-AclLoader (Acl-For $ev (Live-Map $ev)); if ($w) { throw "하네스 결함: Acl-For($ev) 가 로더 모의를 통과하지 못한다: $w" } }
  # ---- S12: 구조(정적 — 블록을 실행하지 않는다)를 맨 먼저 돌린다. 관문(파서 오류 0 · 명령 · 정적 형식 · $Host · 리다이렉트 허용 목록)이 하나라도
  #      FAIL 이면 런타임 시나리오를 하나도 돌리지 않는다 — 함수 가림 · PATH 함정은 절대 경로 실행 파일 · 프로세스 직접 기동을 막지 못한다(T054 리뷰 O8)
  Run-Static
  Finish-Case 'S12' '구조: & { 로 시작하는 한 문 · 빈 줄 0 · 끝 } + LF 1 · BOM/CR/TAB 0 · Start-Transcript 0 · 파서 오류 0 · 명령/형식/$Host/리다이렉트 허용 목록(관문) · 첫 문장 Set-PSDebug -Off · 세션 설정 고정 3문장 · finally 출력 규칙 + 첫 두 문장 = env 제거 · Read-Host 바로 앞 입력 버퍼 비움(AST) · vault 호출 모양 · MOCK/비밀 상수 0 + (B8) acl 렌더 정적 규칙: $render 대입문 1개 · 순수 함수(명령 0 · 바깥 변수 0) · CR(백틱 r · [char]13) · NewLine 0 · -join 백틱 n · ToLowerInvariant · 블록 전체 백틱 r 0' ''
  $GateMsg = Static-Gate
  if ($GateMsg) {
    Write-Host "관문 FAIL(S12): $GateMsg — 런타임 시나리오를 실행하지 않는다(블록 실행 0회)" -ForegroundColor Red
    throw 'S12 관문 FAIL' }
  Assert-Guard
  Write-Host ("가드: S12 관문 PASS(블록 실행 전) · vault·kubectl(.exe 포함) · Set-PSDebug = 모의 함수 · 실물 디렉터리 {0}개를 PATH 에서 뺌 · 함정 디렉터리 맨 앞(표식 0 단언) · KUBECONFIG = 없는 경로" -f $RealDirs.Count)
  $ROOT = $global:FAKE_ROOT
  $OK2 = @($global:FAKE_ROOT, 'seed')
  $OKLINE = { param($e) "OK   $($e.path) v1 — 생성 · 되읽기 해시 일치($(@($e.keys) -join '·'))" }
  $SKIPLINE = { param($e) "SKIP $($e.path) — live-ok" }
  $PLANLINE = { param($e) "PLAN $($e.path) — absent → 생성 예정" }
  $DA = P 'kv/dev/dragonfly/admin'; $DI = P 'kv/dev/dragonfly/identity-admin'; $DS = P 'kv/dev/dragonfly/sample-pod'; $DACL = P 'kv/dev/dragonfly/acl'
  $PA = P 'kv/prod/dragonfly/admin'; $PI = P 'kv/prod/dragonfly/identity-admin'; $PACL = P 'kv/prod/dragonfly/acl'
  $pwA = [string]$LIVE_PW[$DA.path]; $pwI = [string]$LIVE_PW[$DI.path]; $pwS = [string]$LIVE_PW[$DS.path]; $pwPA = [string]$LIVE_PW[$PA.path]; $pwPI = [string]$LIVE_PW[$PI.path]

  # ---- U01–U04(⑨ · 결정 B2): acl 렌더 순수 함수 단위 시험 — 블록 파일의 $render 대입문을 AST 로 떼어 내(S12 가 찾은 것) 고정 입력(모의 비밀번호)을 넣고
  #      독립 계산(Acl-For — 바이트마다 x2 hex · 문자열 리터럴로 줄을 잇는다)과 바이트 단위로 대조한다. 블록 전체는 실행하지 않는다
  Run-Unit 'U01' '(⑨) 렌더 — dev: 모의 비밀번호 3개 → 독립 계산 기대 바이트열과 Ordinal 일치 · 4줄 · 줄 순서(default · admin · identity-admin · sample-pod) · USER default OFF -@all · # 뒤 SHA-256 소문자 hex 64자 · 규칙 문자열(계약 §ACL 표) · 끝 LF 정확히 1 · CR/TAB/BOM/빈 줄/앞뒤·연속 공백 0 · ASCII · 토큰 ≥ 4 · 로더 모의 통과 · 평문 비밀번호 0' {
    param($r)
    $m = Live-Map 'dev'
    Check-Render 'dev' $m (& $r 'dev' $m) }
  Run-Unit 'U02' '(⑨) 렌더 — prod: 모의 비밀번호 2개 → 3줄(sample-pod 없음) · 같은 바이트 규칙 / 맵에 sample-pod 가 더 있어도 prod 렌더에는 sample-pod 줄 0' {
    param($r)
    $m = Live-Map 'prod'
    Check-Render 'prod' $m (& $r 'prod' $m)
    $m3 = Live-Map 'prod'; $m3['sample-pod'] = $pwS
    $o3 = [string](& $r 'prod' $m3)
    Check 'prod 렌더 + 맵에 sample-pod 있음 → sample-pod 줄 0 · 3줄 · 독립 계산과 일치' ((-not $o3.Contains('sample-pod')) -and (SEq $o3 (Acl-For 'prod' $m3)) -and @($o3.TrimEnd("`n").Split("`n")).Count -eq 3)
    $m4 = Live-Map 'dev'
    $o4 = [string](& $r 'dev' $m4)
    $o5 = [string](& $r 'dev' $m4)
    Check '같은 입력 두 번 → 같은 출력(순수 — 상태 없음)' (SEq $o4 $o5) }
  Run-Unit 'U03' '(⑨) 렌더 — 잘못된 입력은 렌더하지 않고 throw(값 미출력): env staging · Dev(대소문자) · 빈 env · 사용자 누락(dev 에 sample-pod 없음) · 42자 · + 섞인 43자 · 숫자 · 맵 $null · 맵이 사전 아님' {
    param($r)
    $mMiss = Live-Map 'prod'
    $m42 = Live-Map 'dev'; $m42['identity-admin'] = $pwI.Substring(0, 42)
    $mPlus = Live-Map 'dev'; $mPlus['admin'] = $pwPlus
    $mNum = Live-Map 'dev'; $mNum['sample-pod'] = [long]98765432109876
    $cases = @(@('env staging', 'staging', (Live-Map 'dev')), @('env Dev(대소문자 — Ordinal)', 'Dev', (Live-Map 'dev')), @('env 빈 문자열', '', (Live-Map 'dev')),
      @('dev 맵에 sample-pod 없음', 'dev', $mMiss), @('identity-admin 42자', 'dev', $m42), @('admin 에 + / 섞인 43자', 'dev', $mPlus), @('sample-pod 가 숫자', 'dev', $mNum),
      @('맵 $null', 'dev', $null), @('맵이 사전 아님(문자열 배열)', 'dev', @('admin', 'identity-admin')))
    $nd = @($pwA, $pwI, $pwS, $pwPA, $pwPI, $pwPlus)
    foreach ($c in $cases) {
      $threw = $false; $msg = ''
      try { $null = & $r $c[1] $c[2] } catch { $threw = $true; $msg = [string]$_.Exception.Message }
      Check "거부(throw): $($c[0])" $threw
      $leak = @($nd | Where-Object { $msg.Contains($_) -or $msg.Contains($_.Substring(0, 8)) -or $msg.Contains($_.Substring(35, 8)) })
      Check "거부 문구에 비밀번호(전체 · 앞 8자 · 끝 8자) 0: $($c[0])" ($leak.Count -eq 0) } }
  Run-Unit 'U04' '(⑨) 로더 모의 자체 시험 — Dragonfly v1.40.1 MaterializeFileContents · 토큰 종류 규칙이 렌더 결과는 통과시키고, 로드 실패를 만드는 바이트(CR · BOM · 탭 · 3토큰 줄 · 주석 줄 · default 없음 · 홀수 hex)는 잡는다' {
    param($r)
    $good = [string](& $r 'dev' (Live-Map 'dev'))
    Check '렌더 결과 → 로더 모의 통과' ([string]::IsNullOrEmpty((Test-AclLoader $good))) (Test-AclLoader $good)
    $bad = [ordered]@{
      'CRLF(줄 끝 CR — +@all 뒤에 CR 이 붙는다)' = $good.Replace("`n", "`r`n")
      '마지막 줄에만 CR 1바이트' = ($good.Substring(0, $good.Length - 1) + "`r`n")
      'BOM(U+FEFF) 앞머리' = ([string][char]0xFEFF + $good)
      '탭으로 토큰 구분(한 곳)' = $good.Replace(' ~* &*', ([string][char]9 + '~* &*'))
      '3토큰 줄(USER default OFF)' = $good.Replace('USER default OFF -@all', 'USER default OFF')
      '주석 줄(# …)' = ('# T057' + "`n" + $good)
      'default 줄 없음' = $good.Replace(('USER default OFF -@all' + "`n"), '')
      '홀수 길이 hex(# 뒤 63자)' = [regex]::Replace($good, '#([0-9a-f]{63})[0-9a-f]', '#$1', 'None', [TimeSpan]::FromSeconds(5)) }
    foreach ($k in $bad.Keys) { Check "로더 모의가 잡는다: $k" (-not [string]::IsNullOrEmpty((Test-AclLoader ([string]$bad[$k])))) } }

  # ---- S01 · S02: 정상 첫 시드(⑦) + 노출 검사
  Run-Case 'S01' '(⑦) 7경로 absent → 7개 생성(v1 · 키 집합 1/2/1 · password base64url 43자 · url 모양 · acl = 그 env 사용자 비밀번호로 독립 계산한 렌더 · 로더 모의 통과) · 쓰기 순서 env 마다 사용자 → acl · dev → prod · 사용자 비밀번호 5개 서로 다름 · 쓸 경로 목록 줄 · vault 호출 31회' -Inputs $OK2 `
    -Want (@($PATHS | ForEach-Object { & $OKLINE $_ }) + @($PATHS | ForEach-Object { & $PLANLINE $_ }) + @('OK   Vault 도달 · 초기화됨 · unsealed', 'OK   토큰 정책에 root 포함', '판정 결과: 생성 예정 7 · 건너뜀(live-ok) 0 · 중단 0', '쓸 경로 7개(이 순서로 쓴다)', '이 실행이 kv 에 새로 쓴 경로: 7건(생성·검증 완료 7 · 응답 유실 뒤 재판정으로 검증 완료 0 · 기록 후 검증 실패 0) · 결과 미확인 0 · 건너뜀 0 · 중단 0 · 미실행 0', '판정: kv 7경로 준비 완료(생성 또는 live-ok) — gitops T057 PR 머지 전제 충족 · 이 출력을 컨트롤러에게 붙인 뒤에만 머지한다')) `
    -NotWant @('STOP ', '중단(') -Post {
      foreach ($e in $PATHS) { Check-Created $e }
      $pws = @($USERS | ForEach-Object { [string](KvData $_.path)['password'] })
      Check '사용자 비밀번호 5개가 서로 다르다(B5 — Ordinal)' ((Uniq $pws) -eq 5) "고유 $(Uniq $pws)"
      Check 'put 7회' ($global:PutCalls.Count -eq 7)
      $bodyKeys = @($global:PutBodies | ForEach-Object { $o = $_ | ConvertFrom-Json -AsHashtable -DateKind String; (@($o.Keys | ForEach-Object { [string]$_ }) | Sort-Object) -join ',' })
      $wantKeys = @($PATHS | ForEach-Object { (@($_.keys) | Sort-Object) -join ',' })
      Check 'put 본문(stdin JSON) 7개 · 키 집합 = 경로 순서대로 password / password,url / users.acl(B1 · B3)' (SEq ($bodyKeys -join ' | ') ($wantKeys -join ' | ')) ($bodyKeys -join ' | ')
      Check 'put 본문의 users.acl 은 JSON 이스케이프 \n 으로 실린다(본문 문자열에 날 LF 0 — 한 줄 JSON)' (@($global:PutBodies | Where-Object { ([string]$_).Contains("`n") -or ([string]$_).Contains("`r") }).Count -eq 0)
      Check '입력 2회(root 토큰 보안 입력 1 · seed 1)' ($global:ReadLog.Count -eq 2 -and $global:ReadLog[0].secure -and -not $global:ReadLog[1].secure)
      Check 'seed 정지점 문구에 -cas=0 · 덮어쓰기 없음' ($global:Prompts.Count -eq 2 -and ([string]$global:Prompts[1]).Contains('seed') -and ([string]$global:Prompts[1]).Contains('-cas=0'))
      foreach ($e in $PATHS) { Check "쓰기 전 목록에 $($e.path)(키 · 사용자 · 소비자 — 값 없음 · B1)" ($global:LastText.Contains("  - $($e.path)  ($($e.use))")) }
      Check-WriteOrder $PATHS
      Check '클립보드를 비웠다(토큰 입력 직후 + finally)' ($global:ClipValues.Count -ge 2)
      Check 'seed 정지점은 -MaskInput(가려진 입력)이고 문구에 "입력은 가려진다"' ($global:ReadLog.Count -eq 2 -and $global:ReadLog[1].masked -and ([string]$global:Prompts[1]).Contains('입력은 가려진다'))
      Check 'INFO 줄에 vault CLI 버전 · 명령 종류 · 경로(모의 = Function · 경로 없음) · LF 값이 처음이라는 고지' ($global:LastText.Contains('INFO vault CLI: Vault v0.0.0-MOCK (harness) · Function (경로 없음) — ') -and $global:LastText.Contains('줄바꿈(LF)이 든 값(users.acl)은 이 블록이 처음이다'))
      Check '모듈 로깅 정책 키는 PowerShellCore 2개만 읽었다(UseWindowsPowerShellPolicySetting 없음)' ((Ev-Index "reg:policy:$($global:PolicyPaths[0])") -ge 0 -and (Ev-Index "reg:policy:$($global:PolicyPaths[1])") -ge 0 -and (Ev-First 'reg:policy:HKLM:\SOFTWARE\Policies\Microsoft\Windows') -lt 0 -and (Ev-First 'reg:policy:HKCU:\SOFTWARE\Policies\Microsoft\Windows') -lt 0)
      Check '모듈 로깅 정책 확인은 root 토큰 입력 전' ((Ev-First 'reg:policy:') -ge 0 -and (Ev-First 'reg:policy:') -lt (Ev-Index 'read:secure'))
      Check 'vault 호출 31회(version 1 · status 1 · token lookup 1 · 판정 metadata get 7 · 경로마다 put · kv get · metadata get 3×7 — 런북 「실행」 소요 문장의 근거)' ($global:ArgvLog.Count -eq 31) "vault 호출 $($global:ArgvLog.Count)"
      $rows = Summary-Rows
      $okRows = 0
      for ($i = 0; $i -lt [Math]::Min($rows.Count, $PATHS.Count); $i++) { if ($rows[$i].StartsWith($PATHS[$i].path + ' ', [StringComparison]::Ordinal) -and $rows[$i].Contains("생성 v1 · 되읽기 해시 일치($(@($PATHS[$i].keys) -join '·'))")) { $okRows++ } }
      Check '요약 표 7행(경로 순서 · 전부 생성 v1 · 되읽기 해시 일치(경로의 키))' ($rows.Count -eq 7 -and $okRows -eq 7) ($rows -join ' | ') }

  Run-Case 'S02' '노출 검사 — 저장된 password · url · users.acl(hex 포함) · root 토큰이 화면·프롬프트·argv·클립보드·$Error·전역·환경 어디에도 없다(8자 조각 · 해시 포함) + 검출기 자체 시험' -Inputs $OK2 -Post {
      $nd = Build-Needles
      Check '바늘 수 ≥ 5×(36 조각 + 전체 + base64) + 토큰 30' ($nd.Count -ge 5 * 38 + 30) "바늘 $($nd.Count)"
      $pw0 = [string](KvData $DA.path)['password']
      $url0 = [string](KvData $DI.path)['url']
      $acl0 = [string](KvData $DACL.path)['users.acl']
      Check '검출기 자체 시험: 비밀번호 앞 · 가운데 · 끝 8자를 잡는다' (($null -ne (First-Needle ('a ' + $pw0.Substring(0, 8) + ' b') $nd)) -and ($null -ne (First-Needle ('x' + $pw0.Substring(17, 8) + 'y') $nd)) -and ($null -ne (First-Needle ('x' + $pw0.Substring(35, 8)) $nd)))
      Check '검출기 자체 시험: root 토큰 앞 8자를 잡는다' ($null -ne (First-Needle ('token=' + $global:FAKE_ROOT.Substring(0, 8)) $nd))
      Check '검출기 자체 시험: url 전체 · url 안의 비밀번호를 잡는다' (($nd -ccontains $url0) -and ($null -ne (First-Needle ('u ' + $url0) $nd)))
      Check '검출기 자체 시험: acl 전문이 바늘이다' ($nd -ccontains $acl0)
      $h0 = Hex-Lower $pw0
      Check '검출기 자체 시험: acl 에 든 # hex(소문자 64자 · 대문자 · 앞 16자)가 바늘이다' (($nd -ccontains $h0) -and ($nd -ccontains $h0.ToUpperInvariant()) -and ($nd -ccontains $h0.Substring(0, 16)))
      Check '검출기 자체 시험: 출력에 섞인 acl 한 줄을 잡는다(# hex 부분)' ($null -ne (First-Needle ('x USER admin ON #' + $h0 + ' ~* &* +@all') $nd))
      Check '검출기 자체 시험: 경로 · 사용자 이름 · 쓸 경로 목록 문구(비밀 아님)는 잡지 않는다' ($null -eq (First-Needle ((@($PATHS | ForEach-Object { $_.path + ' ' + $_.user + ' ' + $_.use })) -join "`n") $nd))
      Check '검출기 자체 시험: acl 규칙 문자열(비밀 아님)은 잡지 않는다' ($null -eq (First-Needle 'USER default OFF -@all ~revoked:* ~identity-admin:* +@all %R~revoked:* ~sample-pod:* +@all' $nd))
      Check '검출기 자체 시험: 이번 화면 출력 전체에는 바늘 0' ($null -eq (First-Needle $global:LastText $nd))
      $ht = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($global:FAKE_ROOT)))
      Check '검출기 자체 시험: root 토큰의 SHA-256 hex 도 바늘 집합에 있다' (($nd -ccontains $ht) -and ($nd -ccontains $ht.ToLowerInvariant())) }

  # ---- S03 · S03b: 한 env 만 live-ok(사용자 + acl) · 다른 env 는 absent → 그 env 만 생성(B8 유지 목록 「한쪽만 live-ok」)
  function Run-EnvLive { param([string]$id, [string]$desc, [string]$liveEnv)
    $script:elEnv = $liveEnv
    $script:elLive = @($PATHS | Where-Object { SEq $_.env $liveEnv })
    $script:elAbsent = @($PATHS | Where-Object { -not (SEq $_.env $liveEnv) })
    $script:elCalls = 3 + 7 + $script:elLive.Count + 3 * $script:elAbsent.Count
    $nA = $script:elAbsent.Count; $nL = $script:elLive.Count
    Run-Case $id $desc -Setup { Seed-Env $script:elEnv } -Inputs $OK2 `
      -Want (@($script:elLive | ForEach-Object { & $SKIPLINE $_ }) + @($script:elAbsent | ForEach-Object { & $OKLINE $_ }) + @("판정 결과: 생성 예정 $nA · 건너뜀(live-ok) $nL · 중단 0", "쓸 경로 ${nA}개", "이 실행이 kv 에 새로 쓴 경로: ${nA}건(생성·검증 완료 $nA · 응답 유실 뒤 재판정으로 검증 완료 0 · 기록 후 검증 실패 0) · 결과 미확인 0 · 건너뜀 $nL · 중단 0 · 미실행 0", '판정: kv 7경로 준비 완료')) `
      -NotWant (@('STOP ') + @($script:elLive | ForEach-Object { "PLAN $($_.path) " }) + @($script:elLive | ForEach-Object { "  - $($_.path)  " })) -Post {
        foreach ($e in $script:elLive) { Check-Unchanged $e (Live-Data $e) }
        foreach ($e in $script:elAbsent) { Check-Created $e }
        Check "put $($script:elAbsent.Count)회 · live 경로 put 0" ($global:PutCalls.Count -eq $script:elAbsent.Count -and @($global:PutCalls | Where-Object { $p = $_.path; @($script:elLive | Where-Object { SEq $_.path $p }).Count -gt 0 }).Count -eq 0)
        Check-WriteOrder $script:elAbsent
        Check "vault 호출 $($script:elCalls)회(version · status · token lookup 3 · 판정 metadata get 7 + live 경로 kv get $($script:elLive.Count) · 쓰기 3×$($script:elAbsent.Count))" ($global:ArgvLog.Count -eq $script:elCalls) "vault 호출 $($global:ArgvLog.Count)" } }
  Run-EnvLive 'S03' '(한쪽만 live-ok) dev 4경로 live-ok · prod absent → dev SKIP 4 · prod 3 생성(prod acl = 새 prod 비밀번호로 렌더) · live 경로 버전 · 값 불변' 'dev'
  Run-EnvLive 'S03b' '(한쪽만 live-ok 역순) prod 3경로 live-ok · dev absent → prod SKIP 3 · dev 4 생성(새 값은 prod live 값과 다르다 — B5 생성 몫)' 'prod'

  # ---- S35a–c(⑥ · 결정 B4ⓑ): 사용자 경로 live-ok + acl absent → acl 만 생성 — 렌더는 판정 단계에서 읽은 live 비밀번호로(기대 바이트열 = 모의 비밀번호로 독립 계산)
  Run-Case 'S35a' '(⑥ · B4ⓑ) dev 사용자 3 live-ok · dev acl absent · prod 전부 live-ok → dev acl 1경로만 생성 · 저장된 users.acl = 모의 live 비밀번호로 독립 계산한 기대 바이트열 · 사용자 경로 put 0 · vault 호출 19회' `
    -Setup { Seed-Set -only @($DA.path, $DI.path, $DS.path, $PA.path, $PI.path, $PACL.path) } -Inputs $OK2 `
    -Want (@($PATHS | Where-Object { -not (SEq $_.path $DACL.path) } | ForEach-Object { & $SKIPLINE $_ }) + @((& $PLANLINE $DACL), (& $OKLINE $DACL), '판정 결과: 생성 예정 1 · 건너뜀(live-ok) 6 · 중단 0', '쓸 경로 1개', '판정: kv 7경로 준비 완료')) `
    -NotWant @('STOP ') -Post {
      Check 'put 1회 = dev acl' ($global:PutCalls.Count -eq 1 -and (SEq $global:PutCalls[0].path $DACL.path))
      Check 'dev acl = Acl-For(dev, 모의 live 비밀번호) 바이트열 일치(B2 · B4ⓑ)' (SEq ([string](KvData $DACL.path)['users.acl']) (Acl-For 'dev' (Live-Map 'dev')))
      Check-Created $DACL
      foreach ($e in $PATHS) { if (-not (SEq $e.path $DACL.path)) { Check-Unchanged $e (Live-Data $e) } }
      Check 'vault 호출 19회(3 + 판정 metadata get 7 + live kv get 6 + 쓰기 3)' ($global:ArgvLog.Count -eq 19) "vault 호출 $($global:ArgvLog.Count)" }
  Run-Case 'S35b' '(⑥ · B4ⓑ) prod 사용자 2 live-ok · prod acl absent · dev 전부 live-ok → prod acl 1경로만 생성 · 기대 바이트열(3줄 · sample-pod 없음) 일치' `
    -Setup { Seed-Set -only @($DA.path, $DI.path, $DS.path, $DACL.path, $PA.path, $PI.path) } -Inputs $OK2 `
    -Want @((& $PLANLINE $PACL), (& $OKLINE $PACL), '판정 결과: 생성 예정 1 · 건너뜀(live-ok) 6 · 중단 0') -NotWant @('STOP ') -Post {
      Check 'put 1회 = prod acl' ($global:PutCalls.Count -eq 1 -and (SEq $global:PutCalls[0].path $PACL.path))
      Check 'prod acl = Acl-For(prod, 모의 live 비밀번호) 바이트열 일치' (SEq ([string](KvData $PACL.path)['users.acl']) (Acl-For 'prod' (Live-Map 'prod')))
      Check-Created $PACL
      foreach ($e in $PATHS) { if (-not (SEq $e.path $PACL.path)) { Check-Unchanged $e (Live-Data $e) } } }
  Run-Case 'S35c' '(B4 — 일부 live-ok + 일부 absent + acl absent) dev admin · sample-pod live-ok · dev identity-admin absent · dev acl absent · prod live-ok → identity-admin 생성 → acl 생성(live 2 + 새 1 로 렌더) · 쓰기 순서 사용자 → acl' `
    -Setup { Seed-Set -only @($DA.path, $DS.path, $PA.path, $PI.path, $PACL.path) } -Inputs $OK2 `
    -Want @((& $SKIPLINE $DA), (& $SKIPLINE $DS), (& $PLANLINE $DI), (& $PLANLINE $DACL), (& $OKLINE $DI), (& $OKLINE $DACL), '판정 결과: 생성 예정 2 · 건너뜀(live-ok) 5 · 중단 0') -NotWant @('STOP ') -Post {
      Check-Created $DI; Check-Created $DACL
      $newI = [string](KvData $DI.path)['password']
      $m = @{ 'admin' = $pwA; 'identity-admin' = $newI; 'sample-pod' = $pwS }
      Check 'dev acl = live admin · live sample-pod · 새 identity-admin 으로 독립 계산한 렌더' (SEq ([string](KvData $DACL.path)['users.acl']) (Acl-For 'dev' $m))
      Check '새 identity-admin password 는 live 사용자 비밀번호 4개와 다르다(B5 생성 몫)' (@($pwA, $pwS, $pwPA, $pwPI) -cnotcontains $newI)
      Check-WriteOrder @($DI, $DACL)
      Check 'vault 호출 21회(3 + 7 + live kv get 5 + 쓰기 3×2)' ($global:ArgvLog.Count -eq 21) "vault 호출 $($global:ArgvLog.Count)" }

  # ---- S04: 사용자 경로 live-mismatch(쓰기 0) — 한 경로만 모양이 다른 live 값, 나머지는 absent(결정 B3: 덮어쓰기 0 · 자동 교정 0 · 사유는 분류만)
  function Run-Mismatch { param([string]$id, [string]$desc, $e, $data, [string]$reason, [string[]]$extraSecrets = @())
    $script:mmE = $e; $script:mmData = $data; $script:mmX = $extraSecrets
    Run-Case $id $desc -Setup { Seed-Path $script:mmE.path $script:mmData; foreach ($x in $script:mmX) { [void]$global:ExtraSecrets.Add($x) } } -Inputs $OK2 -Expect '판정 단계에서 중단' `
      -Want @("STOP $($e.path) — live-mismatch: $reason", '미실행(판정 단계에서 중단 — 쓰지 않았다)', $SUMMARY, '이 실행이 kv 에 새로 쓴 경로: 0건') -Post {
        Check 'put 0(쓰기 0)' ($global:PutCalls.Count -eq 0)
        Check '쓰기 확인 정지점까지 가지 않았다(입력 1 = 토큰)' ($global:ReadLog.Count -eq 1)
        Check 'live 경로 버전 불변(덮어쓰기 0 · 자동 교정 0)' ((KvCur $script:mmE.path) -eq 1)
        foreach ($o in $PATHS) { if (-not (SEq $o.path $script:mmE.path)) { Check-Absent $o } } } }
  Run-Mismatch 'S04a' 'live-mismatch: admin 경로 키 이름 대소문자 다름(Password — Ordinal · ESO remoteRef.property 는 대소문자를 가린다) → 키 집합 불일치 · 쓰기 0' $DA ([ordered]@{ Password = $pwA }) '키 집합 불일치(누락: password · 여분 1개)' @($pwA)
  Run-Mismatch 'S04b' '(여분 키) admin 경로에 password + url(pod 모양) → 키 집합 불일치(여분 1) · 쓰기 0(admin 은 운영자 전용 — url 을 두지 않는다)' $DA ([ordered]@{ password = $pwA; url = (Url-For $DI $pwA) }) '키 집합 불일치(누락: 없음 · 여분 1개)'
  Run-Mismatch 'S04c' '(키 누락) identity-admin 경로에 password 만(url 없음) → 키 집합 불일치(누락: url) · 쓰기 0' $DI ([ordered]@{ password = $pwI }) '키 집합 불일치(누락: url · 여분 0개)'
  Run-Mismatch 'S04c2' '(여분 키) identity-admin 경로에 T054 모양(username · password · url) → 키 집합 불일치(여분 1) · 쓰기 0' $DI ([ordered]@{ username = 'identity-admin'; password = $pwI; url = (Url-For $DI $pwI) }) '키 집합 불일치(누락: 없음 · 여분 1개)'
  Run-Mismatch 'S04d' '(길이) identity-admin password 42자(base64url 문자뿐 · url 도 같은 값) → 쓰기 0' $DI ([ordered]@{ password = $pwI.Substring(0, 42); url = (Url-For $DI $pwI.Substring(0, 42)) }) 'password 길이가 43이 아니다'
  Run-Mismatch 'S04e' '(길이) admin password 44자(한 글자 많음 — 패딩 = 도 같은 길이) → 쓰기 0' $DA ([ordered]@{ password = ($pwA + 'Z') }) 'password 길이가 43이 아니다'
  Run-Mismatch 'S04f' '43자인데 표준 base64 문자(+ /)가 섞였다 → 쓰기 0' $DA ([ordered]@{ password = $pwPlus }) 'password 에 base64url 밖의 문자가 있다'
  Run-Mismatch 'S04f2' "43자인데 '=' 가 섞였다(base64url 42자 + 패딩) → 쓰기 0" $DA ([ordered]@{ password = $pwEq }) 'password 에 base64url 밖의 문자가 있다'
  Run-Mismatch 'S04f3' "43자인데 '.' · '~'(T054 판정의 URL 비예약 문자)가 섞였다 → 쓰기 0" $DA ([ordered]@{ password = $pwDot }) 'password 에 base64url 밖의 문자가 있다'
  Run-Mismatch 'S04g' 'password 가 문자열이 아님(JSON 숫자) → 쓰기 0' $DA ([ordered]@{ password = [long]98765432109876 }) 'password 값이 문자열이 아니다' @('98765432109876')
  Run-Mismatch 'S04g2' 'url 이 문자열이 아님(JSON 숫자) → 쓰기 0' $DI ([ordered]@{ password = $pwI; url = [long]12345678901234 }) 'url 값이 문자열이 아니다'
  Run-Mismatch 'S04h' 'password = 43자 + 끝 LF(길이 44) → 쓰기 0(\z 앵커 — ^…$ 면 끝 개행 앞에서 맞아 live-ok 로 SKIP 된다)' $DA ([ordered]@{ password = ($pwA + "`n") }) 'password 길이가 43이 아니다'
  Run-Case 'S04i' 'password 와 Password(대소문자만 다른 키)가 함께 있다 → JSON 해석 불가 = 판정 불가 STOP(live-ok 아님 · 쓰기 0 · 값 미출력)' `
    -Setup { $d = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal); $d['password'] = $pwA; $d['Password'] = $pwDup; Seed-Path $DA.path $d; [void]$global:ExtraSecrets.Add($pwDup) } `
    -Inputs $OK2 -Expect '판정 단계에서 중단' -Want @("STOP $($DA.path) — 판정 불가: kv get 응답을 해석하지 못했다(원문 미출력)", '미실행(판정 단계에서 중단 — 쓰지 않았다)') -NotWant @('live-mismatch', "SKIP $($DA.path)") -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰)' ($global:ReadLog.Count -eq 1)
      Check "$($DA.path): 버전 불변(v1)" ((KvCur $DA.path) -eq 1); Check-Absent $DI }

  # ---- S04l–n(①②③ · 결정 B3ⓑ): url 은 정확히 'redis://' + <사용자> + ':' + <같은 password> + '@dragonfly-<env>.data.svc:6379/0' — 어긋나면 분류만 담은 사유로 STOP
  $uOk = Url-For $DI $pwI
  Run-Mismatch 'S04l' '(① url 사용자) url 의 사용자 부분만 다르다 — 같은 길이(identity-admix) · 비밀번호 · 호스트는 일치 → url 스킴 · 사용자 불일치 · 쓰기 0(접두 검사가 없으면 길이가 같아 가운데 대조가 우연히 맞는다 — T054 S04j)' $DI ([ordered]@{ password = $pwI; url = $uOk.Replace('//identity-admin:', '//identity-admix:') }) 'url 스킴 · 사용자 불일치(접두가 redis://identity-admin: 와 다르다)'
  Run-Mismatch 'S04l2' '(① url 사용자) sample-pod 경로의 url 이 identity-admin 사용자(다른 길이) → url 스킴 · 사용자 불일치 · 쓰기 0' $DS ([ordered]@{ password = $pwS; url = (Url-For $DI $pwS) }) 'url 스킴 · 사용자 불일치(접두가 redis://sample-pod: 와 다르다)'
  Run-Mismatch 'S04l3' '(① url 스킴) rediss 스킴 → url 스킴 · 사용자 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = ('rediss' + $uOk.Substring(5)) }) 'url 스킴 · 사용자 불일치(접두가 redis://identity-admin: 와 다르다)'
  Run-Mismatch 'S04m' '(② url 호스트) dev 경로의 url 이 prod 호스트(dragonfly-prod) → url 호스트 · 포트 · db 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = $uOk.Replace('@dragonfly-dev.', '@dragonfly-prod.') }) 'url 호스트 · 포트 · db 불일치(접미가 @dragonfly-dev.data.svc:6379/0 와 다르다)'
  Run-Mismatch 'S04m2' '(② url 포트) 6380 → url 호스트 · 포트 · db 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = $uOk.Replace(':6379/0', ':6380/0') }) 'url 호스트 · 포트 · db 불일치'
  Run-Mismatch 'S04m3' '(② url db) /1 → url 호스트 · 포트 · db 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = ($uOk.Substring(0, $uOk.Length - 1) + '1') }) 'url 호스트 · 포트 · db 불일치'
  Run-Mismatch 'S04m4' '(② url 끝 개행) url + LF → url 호스트 · 포트 · db 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = ($uOk + "`n") }) 'url 호스트 · 포트 · db 불일치'
  Run-Mismatch 'S04m5' '(② url 네임스페이스) .data.svc → .jt-dev.svc → url 호스트 · 포트 · db 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = $uOk.Replace('.data.svc', '.jt-dev.svc') }) 'url 호스트 · 포트 · db 불일치'
  Run-Mismatch 'S04n' '(③ url 비밀번호) url 의 비밀번호 부분이 같은 경로 password 와 다른 43자 → url 비밀번호 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = (Url-For $DI $pwOther) }) 'url 비밀번호 불일치(url 의 비밀번호 부분이 password 값과 다르다)'
  Run-Mismatch 'S04n2' '(③ url 비밀번호) dev identity-admin url 에 prod identity-admin 비밀번호(호스트는 dev) → url 비밀번호 불일치 · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = (Url-For $DI $pwPI) }) 'url 비밀번호 불일치'
  Run-Mismatch 'S04n3' '(③ url 비밀번호) url 의 비밀번호가 대소문자 한 글자만 다르다 → url 비밀번호 불일치(Ordinal) · 쓰기 0' $DI ([ordered]@{ password = $pwI; url = (Url-For $DI (Flip-FirstLetter $pwI)) }) 'url 비밀번호 불일치'

  # ---- S04q(④ · 결정 B3ⓒ): acl live 내용이 그 env 의 live 사용자 비밀번호로 렌더한 결과와 다르면(1바이트라도) STOP — 덮어쓰기 0 · 사유에 내용 · 모양 0
  function Run-AclMismatch { param([string]$id, [string]$desc, $acl, $data, [string]$reason, [string[]]$extra = @())
    $script:amAcl = $acl; $script:amData = $data; $script:amX = $extra
    $script:amUsers = @($USERS | Where-Object { SEq $_.env $acl.env }); $script:amOthers = @($PATHS | Where-Object { -not (SEq $_.env $acl.env) })
    $nO = $script:amOthers.Count; $nU = $script:amUsers.Count
    Run-Case $id $desc -Setup { foreach ($u in $script:amUsers) { Seed-LiveOk $u }; Seed-Path $script:amAcl.path $script:amData; foreach ($x in $script:amX) { [void]$global:ExtraSecrets.Add($x) } } -Inputs $OK2 -Expect '판정 단계에서 중단' `
      -Want (@($script:amUsers | ForEach-Object { & $SKIPLINE $_ }) + @("STOP $($acl.path) — live-mismatch: $reason", "판정 결과: 생성 예정 $nO · 건너뜀(live-ok) $nU · 중단 1", '미실행(판정 단계에서 중단 — 쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 0건')) -NotWant @("SKIP $($acl.path)") -Post {
        Check 'put 0(쓰기 0)' ($global:PutCalls.Count -eq 0)
        Check '입력 1(토큰 — 쓰기 확인 정지점까지 가지 않았다)' ($global:ReadLog.Count -eq 1)
        Check-Unchanged $script:amAcl $script:amData
        foreach ($u in $script:amUsers) { Check-Unchanged $u (Live-Data $u) }
        foreach ($o in $script:amOthers) { Check-Absent $o } } }
  $aclDev = Acl-For 'dev' (Live-Map 'dev')
  $aclProd = Acl-For 'prod' (Live-Map 'prod')
  $ACLWHY = 'acl 내용 불일치(그 env 의 live 사용자 비밀번호로 렌더한 결과와 Ordinal 로 다르다 — 내용 · 모양 미출력)'
  Run-AclMismatch 'S04q' '(④ 1바이트) dev 사용자 3 live-ok · dev acl = 렌더 + 마지막 줄 끝에 CR 1바이트 → acl 내용 불일치 STOP · 쓰기 0 · 덮어쓰기 0' $DACL ([ordered]@{ 'users.acl' = ($aclDev.Substring(0, $aclDev.Length - 1) + "`r`n") }) $ACLWHY
  Run-AclMismatch 'S04q1' '(④ CRLF) dev acl 의 줄 끝이 전부 CRLF → acl 내용 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = $aclDev.Replace("`n", "`r`n") }) $ACLWHY
  Run-AclMismatch 'S04q2' '(④ 대문자 hex) dev acl 의 # hex 가 대문자(로더는 받지만 렌더 규칙은 소문자 — Ordinal) → acl 내용 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = [regex]::Replace($aclDev, '#[0-9a-f]{64}', { param($m) $m.Value.ToUpperInvariant() }) }) $ACLWHY
  Run-AclMismatch 'S04q3' '(④ 끝 LF 없음) dev acl 끝 LF 를 뺐다 → acl 내용 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = $aclDev.TrimEnd("`n") }) $ACLWHY
  Run-AclMismatch 'S04q4' '(④ 끝 LF 2개) dev acl 끝에 LF 하나 더 → acl 내용 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = ($aclDev + "`n") }) $ACLWHY
  $mStale = Live-Map 'dev'; $mStale['identity-admin'] = $pwOther
  Run-AclMismatch 'S04q5' '(④ 낡은 acl) dev acl 이 다른 identity-admin 비밀번호로 렌더됐다(회전 반쪽 — kv <user> 만 바뀐 상태) → acl 내용 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = (Acl-For 'dev' $mStale) }) $ACLWHY @($pwOther)
  Run-AclMismatch 'S04q6' '(④ 줄 누락) dev acl 에 sample-pod 줄이 없다(prod 모양) → acl 내용 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = (Acl-For 'prod' (Live-Map 'dev')) }) $ACLWHY
  Run-AclMismatch 'S04q7' '(④ BOM) dev acl 앞머리에 U+FEFF → acl 내용 불일치 STOP(Ordinal — 문화권 비교 -eq 는 U+FEFF 를 무시해 같다고 본다)' $DACL ([ordered]@{ 'users.acl' = ([string][char]0xFEFF + $aclDev) }) $ACLWHY
  Run-AclMismatch 'S04q8' '(④ hex 한 글자) dev acl 의 admin # hex 한 글자만 다르다 → acl 내용 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = (Flip-HexChar $aclDev) }) $ACLWHY
  Run-AclMismatch 'S04q9' '(④ 키 집합) dev acl 에 users.acl + 여분 키 note → 키 집합 불일치 STOP' $DACL ([ordered]@{ 'users.acl' = $aclDev; note = 'x' }) '키 집합 불일치(누락: 없음 · 여분 1개)'
  Run-AclMismatch 'S04q10' '(④ 문자열 아님) dev acl users.acl 이 JSON 숫자 → users.acl 값이 문자열이 아니다 STOP' $DACL ([ordered]@{ 'users.acl' = [long]81726354453627 }) 'users.acl 값이 문자열이 아니다'
  $mProdSp = Live-Map 'prod'; $mProdSp['sample-pod'] = $pwS
  Run-AclMismatch 'S04q11' '(④ prod 에 sample-pod) prod acl 이 dev 모양(sample-pod 줄 포함) → acl 내용 불일치 STOP(prod aclfile 에 sample-pod 0 — 계약)' $PACL ([ordered]@{ 'users.acl' = (Acl-For 'dev' $mProdSp) }) $ACLWHY

  # ---- S36(⑤ · 결정 B4ⓐ): 사용자 경로가 absent 인데 acl 이 live → STOP(이 실행이 모르는 비밀번호) · STOP 이 섞인 env 의 live acl → 판정 불가 STOP — 둘 다 acl 값을 읽지 않는다
  Run-Case 'S36a' '(⑤ · B4ⓐ) dev 사용자 3 absent + dev acl live → acl live-mismatch STOP · acl 값은 읽지 않는다(kv get 0) · 쓰기 0 · vault 호출 10회' `
    -Setup { Seed-LiveOk $DACL } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DACL.path) — live-mismatch: 같은 env 의 사용자 경로 $($DA.path) 가 absent 인데 acl 이 이미 있다", '이 acl 은 이 실행이 모르는 비밀번호를 가리킨다(결정 B4 · 덮어쓰지 않는다)', '판정 결과: 생성 예정 6 · 건너뜀(live-ok) 0 · 중단 1', '미실행(판정 단계에서 중단 — 쓰지 않았다)') -NotWant @("SKIP $($DACL.path)") -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰)' ($global:ReadLog.Count -eq 1)
      Check 'acl 경로 kv get 0(값을 읽기 전에 정했다)' ((Ev-Index "vault:kv-get:$($DACL.path)") -lt 0)
      Check-Unchanged $DACL (Live-Data $DACL)
      foreach ($o in $PATHS) { if (-not (SEq $o.path $DACL.path)) { Check-Absent $o } }
      Check 'vault 호출 10회(version · status · token lookup · 판정 metadata get 7 — kv get 0)' ($global:ArgvLog.Count -eq 10) "vault 호출 $($global:ArgvLog.Count)" }
  Run-Case 'S36b' '(⑤ · B4ⓐ) dev admin · sample-pod live-ok · dev identity-admin 만 absent + dev acl live → acl live-mismatch STOP(identity-admin 을 가리킨다) · 쓰기 0' `
    -Setup { Seed-Set -only @($DA.path, $DS.path, $DACL.path) } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @((& $SKIPLINE $DA), (& $SKIPLINE $DS), (& $PLANLINE $DI), "STOP $($DACL.path) — live-mismatch: 같은 env 의 사용자 경로 $($DI.path) 가 absent 인데 acl 이 이미 있다", '판정 결과: 생성 예정 4 · 건너뜀(live-ok) 2 · 중단 1') -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0)
      Check 'acl 경로 kv get 0' ((Ev-Index "vault:kv-get:$($DACL.path)") -lt 0)
      Check-Unchanged $DACL (Live-Data $DACL); Check-Absent $DI }
  Run-Case 'S36c' '(B4 — STOP 섞임) dev identity-admin live-mismatch(password 42자) · dev admin · sample-pod live-ok · dev acl live → identity-admin STOP + acl 판정 불가 STOP(대조하지 않는다) · 쓰기 0' `
    -Setup { Seed-Set -only @($DA.path, $DS.path, $DACL.path); Seed-Path $DI.path ([ordered]@{ password = $pwI.Substring(0, 42); url = (Url-For $DI $pwI.Substring(0, 42)) }) } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DI.path) — live-mismatch: password 길이가 43이 아니다", "STOP $($DACL.path) — 판정 불가: 같은 env 의 사용자 경로 $($DI.path) 가 live-ok 가 아니라 acl 을 대조하지 않았다", '판정 결과: 생성 예정 3 · 건너뜀(live-ok) 2 · 중단 2') -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0)
      Check 'acl 경로 kv get 0' ((Ev-Index "vault:kv-get:$($DACL.path)") -lt 0)
      Check-Unchanged $DACL (Live-Data $DACL) }
  Run-Case 'S36d' '(⑤ · env 독립) dev 4경로 live-ok · prod 사용자 2 absent + prod acl live → prod acl 만 STOP · dev 는 SKIP · 쓰기 0' `
    -Setup { Seed-Env 'dev'; Seed-LiveOk $PACL } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want (@($PATHS | Where-Object { SEq $_.env 'dev' } | ForEach-Object { & $SKIPLINE $_ }) + @("STOP $($PACL.path) — live-mismatch: 같은 env 의 사용자 경로 $($PA.path) 가 absent 인데 acl 이 이미 있다", '판정 결과: 생성 예정 2 · 건너뜀(live-ok) 4 · 중단 1')) -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check-Unchanged $PACL (Live-Data $PACL) }

  # ---- S04j · S04k(⑧ · 결정 B5 — T056 C1 확장): 사용자 비밀번호 5개는 전부 서로 달라야 한다 — 같은 값을 가진 경로를 모두 STOP(판정 단계 · 쓰기 0 · 값 · 해시 미출력)
  $PAIRWHY = '사용자 비밀번호 5개는 전부 달라야 한다(dev 값은 jt-dev assert-env 로도 복사되고 admin 은 전권이다) · 값 미출력 · 쓰기 0'
  $PAIRROW = '중단(다른 사용자 경로와 password 가 같다 — 값 미출력 · 쓰기 0)'
  function Run-Pair { param([string]$id, [string]$desc, [hashtable]$pw, [string[]]$stopLines, [string[]]$stopPaths)
    $script:prPw = $pw; $script:prStops = $stopPaths
    $nS = $stopPaths.Count
    Run-Case $id $desc -Setup { Seed-Set -pw $script:prPw } -Inputs $OK2 -Expect '판정 단계에서 중단' `
      -Want (@($PATHS | ForEach-Object { & $SKIPLINE $_ }) + $stopLines + @("판정 결과: 생성 예정 0 · 건너뜀(live-ok) $(7 - $nS) · 중단 $nS", $PAIRROW, '판정: 미완')) `
      -NotWant @('INFO 쓸 경로 없음', '판정: kv 7경로 준비 완료') -Post {
        Check 'put 0(쓰기 0)' ($global:PutCalls.Count -eq 0)
        Check '입력 1(토큰 — 쓰기 확인 정지점까지 가지 않았다)' ($global:ReadLog.Count -eq 1)
        Check 'vault 호출 17회(판정용 읽기만 — 3 + metadata get 7 + kv get 7)' ($global:ArgvLog.Count -eq 17) "vault 호출 $($global:ArgvLog.Count)"
        $tl = @([string]$global:LastText -split "`n")
        $iSkip = -1; $iStop = -1; $iRes = -1
        for ($i = 0; $i -lt $tl.Count; $i++) {
          if ($tl[$i].StartsWith('SKIP ', [StringComparison]::Ordinal)) { $iSkip = $i }
          if ($iStop -lt 0 -and $tl[$i].Contains('사용자 비밀번호 5개는 전부 달라야 한다')) { $iStop = $i }
          if ($iRes -lt 0 -and $tl[$i].StartsWith('판정 결과: ', [StringComparison]::Ordinal)) { $iRes = $i } }
        Check '순서: 경로별 SKIP 줄 7개 → 쌍 판정 STOP 줄 → 판정 결과 줄' ($iSkip -ge 0 -and $iStop -gt $iSkip -and $iRes -gt $iStop) "SKIP 끝 $iSkip · STOP 첫 $iStop · 판정 결과 $iRes"
        $rows = Summary-Rows
        $bad = 0
        foreach ($e in $PATHS) {
          $r = Summary-Row $e.path
          $isStop = @($script:prStops) -ccontains $e.path
          if ($isStop -and -not $r.Contains($PAIRROW)) { $bad++ }
          if (-not $isStop -and -not $r.Contains('건너뜀(live-ok — 덮어쓰지 않았다)')) { $bad++ } }
        Check "요약 표 7행 — 같은 값 경로 $($script:prStops.Count)개는 중단(다른 사용자 경로와 password 가 같다 …) · 나머지는 건너뜀(live-ok)" ($rows.Count -eq 7 -and $bad -eq 0) ($rows -join ' | ')
        foreach ($e in $PATHS) { Check "값 불변: $($e.path)" ((KvCur $e.path) -eq 1) } } }
  Run-Pair 'S04j' '(⑧ · B5) 7경로 live-ok 인데 dev identity-admin 과 prod identity-admin 의 password 가 같다(acl 은 각 env 값으로 렌더 — 모양 OK) → 경로별 SKIP 뒤 두 경로 쌍 판정 STOP · 쓰기 0 · 값 · 해시 미출력' `
    @{ ($DI.path) = $pwSame; ($PI.path) = $pwSame } @("STOP $($DI.path) — password 가 $($PI.path) 의 것과 같다 — $PAIRWHY", "STOP $($PI.path) — password 가 $($DI.path) 의 것과 같다 — $PAIRWHY") @($DI.path, $PI.path)
  Run-Pair 'S04j2' '(⑧ · B5) 같은 env 의 admin 과 identity-admin password 가 같다(dev) → 두 경로 STOP · 쓰기 0' `
    @{ ($DA.path) = $pwSame; ($DI.path) = $pwSame } @("STOP $($DA.path) — password 가 $($DI.path) 의 것과 같다 — $PAIRWHY", "STOP $($DI.path) — password 가 $($DA.path) 의 것과 같다 — $PAIRWHY") @($DA.path, $DI.path)
  Run-Pair 'S04j3' '(⑧ · B5) 셋이 같다(dev admin · dev sample-pod · prod admin) → 세 경로 STOP · 각 줄이 나머지 둘을 가리킨다 · 쓰기 0' `
    @{ ($DA.path) = $pwSame; ($DS.path) = $pwSame; ($PA.path) = $pwSame } @("STOP $($DA.path) — password 가 $($DS.path) · $($PA.path) 의 것과 같다 — $PAIRWHY", "STOP $($DS.path) — password 가 $($DA.path) · $($PA.path) 의 것과 같다 — $PAIRWHY", "STOP $($PA.path) — password 가 $($DA.path) · $($DS.path) 의 것과 같다 — $PAIRWHY") @($DA.path, $DS.path, $PA.path)
  Run-Case 'S04k' '(⑧ · B5) 7경로 live-ok · dev identity-admin 과 prod identity-admin 이 대소문자 한 글자만 다르다(Ordinal SHA-256 비교 — 다르다) → 7 SKIP · 쓰기 0 · 정상 종료' `
    -Setup { Seed-Set -pw @{ ($DI.path) = $pwKa; ($PI.path) = $pwKb } } -Inputs @($ROOT) `
    -Want (@($PATHS | ForEach-Object { & $SKIPLINE $_ }) + @('판정 결과: 생성 예정 0 · 건너뜀(live-ok) 7 · 중단 0', 'INFO 쓸 경로 없음 — 7경로 모두 live-ok', '이 실행이 kv 에 새로 쓴 경로: 0건', '건너뜀 7', '판정: kv 7경로 준비 완료')) `
    -NotWant @('STOP ', 'password 가 ') -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰만)' ($global:ReadLog.Count -eq 1)
      Check 'vault 호출 17회' ($global:ArgvLog.Count -eq 17) "vault 호출 $($global:ArgvLog.Count)" }

  # ---- S05: dead(쓰기 0)
  Run-Case 'S05a' 'dead: dev identity-admin 현재 버전 soft-delete → 쓰기 0으로 중단' -Setup { Seed-Path $DI.path (Live-Data $DI) 1 '2026-10-13T05:00:00Z' } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DI.path) — dead: 현재 버전 1 에 deletion_time 이 있다") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰)' ($global:ReadLog.Count -eq 1); Check-Absent $DA }
  Run-Case 'S05b' 'dead: dev acl 현재 버전 destroy(dev 사용자 3 live-ok) → acl STOP · 쓰기 0' -Setup { foreach ($u in @($DA, $DI, $DS)) { Seed-LiveOk $u }; Seed-Path $DACL.path $null 1 '' $true } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DACL.path) — dead: 현재 버전 1 이 파기(destroy)됐다") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S05c' 'dead: prod admin 메타데이터만 있고 버전 없음(current_version 0) → 쓰기 0' -Setup { Seed-Path $PA.path $null 0 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($PA.path) — dead: current_version=0") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0) }

  # ---- S06: 정지점
  foreach ($c in @(@('S06a', '다른 단어(go)', 'go'), @('S06b', '빈 Enter', ''), @('S06c', '공백이 붙은 단어(" seed")', ' seed'), @('S06d', '대문자 단어("SEED" — Ordinal 대소문자 구분)', 'SEED'))) {
    Run-Case $c[0] "쓰기 확인 정지점에서 $($c[1]) → 쓰기 0으로 중단 · finally 정리 줄 출력" -Inputs @($ROOT, $c[2]) -Expect '정지점에서 중단' `
      -Want @('미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)', $SUMMARY, '창 종료 체크리스트', '이 실행이 kv 에 새로 쓴 경로: 0건') -Post {
        Check 'put 0' ($global:PutCalls.Count -eq 0)
        Check 'kv 비어 있음' ($global:Kv.Count -eq 0) } }

  # ---- S07: Vault 도달·봉인(토큰을 묻기 전에 중단)
  foreach ($c in @(@('S07a', 'Vault 도달 실패(port-forward 없음)', 'down', 'Vault 도달 실패'), @('S07b', 'sealed=true', 'sealed', 'Vault sealed'),
      @('S07c', '미초기화', 'uninit', 'Vault 미초기화'), @('S07d', 'status 응답이 JSON 아님', 'garbage', 'Vault 도달 실패'), @('S07e', 'sealed 가 bool 이 아닌 문자열', 'stringbool', 'Vault 도달 실패'),
      @('S07f', 'status 응답은 unsealed JSON 인데 exit=1(비 0 종료 분기 고정)', 'okrc1', 'vault status 가 unsealed 인데 exit=1 — 판단 불가'))) {
    $script:st7 = $c[2]
    Run-Case $c[0] "$($c[1]) → root 토큰을 묻기 전에 중단(쓰기 0)" -Setup { $global:F['status'] = $script:st7 } -Inputs $OK2 -Expect $c[3] -Want @('root 토큰은 아직 묻지 않았다') -Post {
        Check '입력 0(토큰을 묻지 않았다)' ($global:ReadLog.Count -eq 0)
        Check 'status 뒤 다른 vault 호출 0' (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) -and -not (SEq $_ 'vault:status') -and -not (SEq $_ 'vault:version') }).Count -eq 0)
        Check 'put 0' ($global:PutCalls.Count -eq 0) } }

  # ---- S08: 일시 상태(transient) · 부분 실패 뒤 재실행(B4)
  # S08a: put 비 0 은 "쓰지 않았다"로 단정하지 않고 값 없이 재판정한다 — 재판정 live v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌(다른 기록자의 값)
  Run-Case 'S08a' '일시 상태: metadata get 이 실제로 있는 경로(prod identity-admin · live-ok)를 "No value found"(absent)로 오판 → dev 4 · prod admin 생성 뒤 prod identity-admin -cas=0 put 거부 → 재판정 live v1 · 되읽기 해시 불일치 = CAS 충돌(다른 값) → fail-closed(덮어쓰기 0 · prod acl 미실행)' `
    -Setup { Seed-LiveOk $PI; $global:F['metaFalseAbsent'][$PI.path] = 1 } -Inputs $OK2 -Expect 'put 거부' `
    -Want (@("STOP $($PI.path) — put 거부(exit=2) · CAS 충돌(다른 값)") + @(@($DA, $DI, $DS, $DACL, $PA) | ForEach-Object { & $OKLINE $_ }) + @('중단(put 거부 exit=2 — 재판정 live v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 5건', '미실행(앞 경로에서 중단 — 쓰지 않았다)')) `
    -NotWant @("OK   $($PI.path)", '기록됨(응답 유실', '결과 미확인 1') -Post {
      Check-Unchanged $PI (Live-Data $PI)
      foreach ($e in @($DA, $DI, $DS, $DACL, $PA)) { Check-Created $e }
      Check-Absent $PACL
      Check 'put 6회(여섯 번째가 CAS 거부)' ($global:PutCalls.Count -eq 6)
      $ip = Ev-Index "vault:put:$($PI.path)"; $im = Ev-Index "vault:meta-get:$($PI.path)" ($ip + 1); $ig = Ev-Index "vault:kv-get:$($PI.path)" ($ip + 1)
      Check '재판정 순서: put 거부 → metadata get(live v1) → kv get(값 미출력 해시 대조)' ($ip -ge 0 -and $im -gt $ip -and $ig -gt $im) "put=$ip meta=$im get=$ig" }
  Run-Case 'S08b' '일시 상태: metadata get 일시 오류(비 0 · 빈 출력 · 오류 문구 없음 · dev sample-pod) → absent 로 보지 않고 판정 불가 → 쓰기 0' `
    -Setup { $global:F['metaEmpty'][$DS.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' -Want @("STOP $($DS.path) — 판정 불가: metadata 조회 exit=2 · (오류 출력 없음)") -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check 'kv 비어 있음' ($global:Kv.Count -eq 0) }
  Run-Case 'S08c' '일시 상태: metadata get 서버 오류(500 · dev admin) → 판정 불가 · 오류의 * 줄만 표시 → 쓰기 0' `
    -Setup { $global:F['metaError'][$DA.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' -Want @("STOP $($DA.path) — 판정 불가: metadata 조회 exit=2 · * context deadline exceeded") -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S08d' '일시 상태: 되읽기 일시 실패(첫 경로 dev admin) → 다음 경로로 가지 않고 중단' -Setup { $global:F['readFail'][$DA.path] = 1 } -Inputs $OK2 -Expect '되읽기 실패' `
    -Want @("STOP $($DA.path) — 되읽기 실패(exit=2)", '기록됨 — 되읽기 실패', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 1건') -Post {
      Check "$($DA.path): put 은 됐다(v1)" ((KvCur $DA.path) -eq 1)
      foreach ($e in $PATHS) { if (-not (SEq $e.path $DA.path)) { Check-Absent $e } }
      Check 'put 1회(다음 경로 put 0)' ($global:PutCalls.Count -eq 1) }
  Run-Case 'S08e' '재실행 복구: S08d 상태에서 다시 실행 → dev admin live-ok SKIP(덮어쓰기 0) · 나머지 6 생성(dev acl 은 live admin 비밀번호로 렌더)' `
    -Setup { $global:F['readFail'][$DA.path] = 1; Invoke-PreRun @($global:FAKE_ROOT, 'seed') } -Inputs $OK2 `
    -Want @((& $SKIPLINE $DA), (& $OKLINE $DI), (& $OKLINE $DACL), (& $OKLINE $PACL), '판정: kv 7경로 준비 완료') -NotWant @('STOP ') -Post {
      Check '사전 실행은 첫 경로에서 멈췄다(put 1)' ($global:PreRunPuts -eq 1) "사전 put $($global:PreRunPuts)"
      foreach ($e in $PATHS) { Check-Created $e }
      Check '본 실행 put 6회(dev admin 0)' ($global:PutCalls.Count -eq 6 -and @($global:PutCalls | Where-Object { SEq $_.path $DA.path }).Count -eq 0) }
  # S08f · S08g(B4 「부분 실패 뒤 재실행은 live 사용자로 다시 렌더해 acl 만 쓴다」): dev 사용자 3을 쓴 뒤 dev acl put 이 거부되면 거기서 멈추고, 재실행은 dev 사용자 3을
  #   live-ok 로 건너뛰고 그 live 비밀번호로 acl 을 렌더해 쓴다(prod 는 이어서 생성)
  Run-Case 'S08f' '(B4 부분 실패) dev 사용자 3 생성 뒤 dev acl put 거부(권한 · exit 2 · 경로 그대로 없음) → 재판정 absent = 쓰지 않았다 · prod 미실행' `
    -Setup { $global:F['putFail'][$DACL.path] = 2 } -Inputs $OK2 -Expect 'put 거부' `
    -Want (@(@($DA, $DI, $DS) | ForEach-Object { & $OKLINE $_ }) + @("STOP $($DACL.path) — put 거부(exit=2) · 재판정 absent", '이 실행이 kv 에 새로 쓴 경로: 3건', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '판정: 미완')) -Post {
      foreach ($e in @($DA, $DI, $DS)) { Check-Created $e }
      foreach ($e in @($DACL, $PA, $PI, $PACL)) { Check-Absent $e }
      Check 'put 4회' ($global:PutCalls.Count -eq 4) }
  Run-Case 'S08g' '(B4 재실행) S08f 상태에서 다시 실행 → dev 사용자 3 SKIP · dev acl 만 생성(그 live 비밀번호로 렌더 — 독립 계산과 일치) · prod 3 생성' `
    -Setup { $global:F['putFail'][$DACL.path] = 2; Invoke-PreRun @($global:FAKE_ROOT, 'seed'); [void]$global:F['putFail'].Remove($DACL.path) } -Inputs $OK2 `
    -Want @((& $SKIPLINE $DA), (& $SKIPLINE $DI), (& $SKIPLINE $DS), (& $OKLINE $DACL), (& $OKLINE $PA), (& $OKLINE $PI), (& $OKLINE $PACL), '판정 결과: 생성 예정 4 · 건너뜀(live-ok) 3 · 중단 0', '판정: kv 7경로 준비 완료') -NotWant @('STOP ') -Post {
      Check '사전 실행은 dev acl 에서 멈췄다(put 4)' ($global:PreRunPuts -eq 4) "사전 put $($global:PreRunPuts)"
      foreach ($e in $PATHS) { Check-Created $e }
      Check '본 실행 put 4회 = dev acl · prod 3(dev 사용자 put 0)' ($global:PutCalls.Count -eq 4 -and @($global:PutCalls | Where-Object { $p = $_.path; @(@($DA, $DI, $DS) | Where-Object { SEq $_.path $p }).Count -gt 0 }).Count -eq 0)
      Check-WriteOrder @($DACL, $PA, $PI, $PACL) }

  # ---- S09: 되읽기 대조(모의 Vault 가 저장 때 값을 바꾼다 — tamper 모드는 키 지정형)
  function Run-Tamper { param([string]$id, [string]$desc, [int]$idx, [string]$mode, [string]$expect, [string]$stopText, [string]$rowText)
    $script:tmE = $PATHS[$idx]; $script:tmMode = $mode; $script:tmIdx = $idx; $script:tmRow = $rowText
    $want = @("STOP $($PATHS[$idx].path) — $stopText", $SUMMARY, "이 실행이 kv 에 새로 쓴 경로: $($idx + 1)건")
    if ($idx + 1 -lt $PATHS.Count) { $want += '미실행(앞 경로에서 중단 — 쓰지 않았다)' }
    Run-Case $id $desc -Setup { $global:F['tamper'][$script:tmE.path] = $script:tmMode } -Inputs $OK2 -Expect $expect `
      -Want $want -NotWant @("OK   $($PATHS[$idx].path)") -Post {
        $row = Summary-Row $script:tmE.path
        Check "요약 행($($script:tmE.path)) = $script:tmRow" ($row.Contains($script:tmRow)) $row
        for ($i = 0; $i -lt $script:tmIdx; $i++) { Check-Created $PATHS[$i] }
        Check "$($script:tmE.path): put 은 됐다(v1)" ((KvCur $script:tmE.path) -eq 1)
        for ($i = $script:tmIdx + 1; $i -lt $PATHS.Count; $i++) { Check-Absent $PATHS[$i] }
        Check "put $($script:tmIdx + 1)회(뒤 경로 put 0)" ($global:PutCalls.Count -eq $script:tmIdx + 1) "put $($global:PutCalls.Count)" } }
  Run-Tamper 'S09' '되읽기 해시 불일치(dev admin password 한 글자 변형 — 모양은 그대로) → 중단 · "해시 불일치" 줄 · 값 미출력 · 다음 경로로 가지 않음' 0 'password' '되읽기 해시 불일치' `
    '되읽기 해시 불일치(password)' '기록됨 — 되읽기 해시 불일치(password) · 수동 확인'
  Run-Tamper 'S09b' '되읽기: dev identity-admin password 키 누락(dev admin 생성 뒤) → 키 집합 불일치로 중단' 1 'dropKey' '되읽기 불일치' `
    '되읽기 키 집합 불일치(누락: password · 여분 0개)' '기록됨 — 되읽기 키 집합 불일치(누락 1 · 여분 0) · 수동 확인'
  Run-Tamper 'S09c' '되읽기: dev admin 여분 키(note) → 키 집합 불일치로 중단 · 다음 경로 put 0' 0 'extraKey' '되읽기 불일치' `
    '되읽기 키 집합 불일치(누락: 없음 · 여분 1개)' '기록됨 — 되읽기 키 집합 불일치(누락 0 · 여분 1) · 수동 확인'
  Run-Tamper 'S09d' '되읽기 해시 불일치(dev admin password 첫 영문자의 대소문자만 변형 — 대소문자를 무시하는 원값 비교로는 같아 보인다) → 중단' 0 'passwordCase' '되읽기 해시 불일치' `
    '되읽기 해시 불일치(password)' '기록됨 — 되읽기 해시 불일치(password) · 수동 확인'
  Run-Tamper 'S09e' '되읽기 해시 불일치(dev identity-admin url 의 비밀번호 마지막 글자 변형) → 중단 · 해시 불일치(url)' 1 'url' '되읽기 해시 불일치' `
    '되읽기 해시 불일치(url)' '기록됨 — 되읽기 해시 불일치(url) · 수동 확인'
  Run-Tamper 'S09f' '되읽기 해시 불일치(dev acl 의 LF 를 저장 때 CRLF 로 — 1줄마다 1바이트) → dev 사용자 3 생성 뒤 중단 · 해시 불일치(users.acl) · prod 미실행' 3 'aclCrlf' '되읽기 해시 불일치' `
    '되읽기 해시 불일치(users.acl)' '기록됨 — 되읽기 해시 불일치(users.acl) · 수동 확인'
  Run-Tamper 'S09g' '되읽기: dev acl users.acl 키 누락 → 키 집합 불일치로 중단' 3 'dropKey' '되읽기 불일치' `
    '되읽기 키 집합 불일치(누락: users.acl · 여분 0개)' '기록됨 — 되읽기 키 집합 불일치(누락 1 · 여분 0) · 수동 확인'

  # ---- S10: 클립보드 기록 · 세션 설정
  Run-Case 'S10a' '클립보드 기록 켜짐 → 시작 전 중단(입력 0 · vault 호출 0)' -Setup { $global:ClipHistory = 1 } -Inputs $OK2 -Expect '클립보드 기록이 켜져 있음' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S10b' '클립보드 기록 설정 키 없음 → 시작 전 중단' -Setup { $global:ClipHistoryMode = 'nokey' } -Inputs $OK2 -Expect '클립보드 기록 설정값을 읽지 못했다' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S10c' '클립보드 기록 설정값 없음(키만 있음) → 시작 전 중단' -Setup { $global:ClipHistoryMode = 'novalue' } -Inputs $OK2 -Expect '클립보드 기록 설정값을 읽지 못했다' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0) }
  Run-Case 'S10d' '클립보드 비우기 실패(Set-Clipboard 예외 · 세션 $WarningPreference = SilentlyContinue) → 경고 2줄(토큰 입력 직후 · finally — Write-Warning · 값 없음) · 7개 생성 완주' `
    -Setup { $global:F['clipFail'] = $true; $script:wpBefore = $global:WarningPreference; $global:WarningPreference = 'SilentlyContinue' } -Inputs $OK2 `
    -Want @('클립보드를 비우지 못했다', (& $OKLINE $PACL), '판정: kv 7경로 준비 완료') -Post {
      $global:WarningPreference = $script:wpBefore
      $warn = @($global:LastItems | Where-Object { $_ -is [System.Management.Automation.WarningRecord] -and ([string]$_).Contains('클립보드를 비우지 못했다') })
      Check '클립보드 경고 2개 = WarningRecord(Write-Warning — 토큰 입력 직후 1 · finally 1)' ($warn.Count -eq 2) "경고 $($warn.Count)개"
      $tl = @([string]$global:LastText -split "`n")
      $iw = @(for ($i = 0; $i -lt $tl.Count; $i++) { if ($tl[$i].Contains('클립보드를 비우지 못했다')) { $i } })
      $iTok = -1; $iSum = -1
      for ($i = 0; $i -lt $tl.Count; $i++) { if ($iTok -lt 0 -and $tl[$i].StartsWith('OK   토큰 정책에 root 포함', [StringComparison]::Ordinal)) { $iTok = $i }; if ($iSum -lt 0 -and $tl[$i].StartsWith($SUMMARY, [StringComparison]::Ordinal)) { $iSum = $i } }
      Check '첫 경고는 토큰 확인 줄보다 앞(붙여넣은 직후) · 둘째 경고는 요약 머리보다 앞(finally 정리)' ($iw.Count -eq 2 -and $iTok -ge 0 -and $iw[0] -lt $iTok -and $iw[1] -gt $iTok -and $iSum -gt $iw[1]) "경고 줄 $($iw -join ',') · 토큰 $iTok · 요약 $iSum"
      Check '클립보드 비우기를 두 번 시도했다(값은 공백)' ($global:ClipValues.Count -eq 2 -and (Ev-Index 'clip:fail') -ge 0)
      foreach ($e in $PATHS) { Check-Created $e } }
  Run-Case 'S10e' '세션 $WhatIfPreference = $true + $PSDefaultParameterValues[Set-Clipboard:WhatIf] = $true(붙여넣기 창) → 블록이 자기 범위에서 고정 → 클립보드 비우기 2회 실제 실행 · VAULT_* 제거 · 7개 생성 완주' `
    -Setup { $global:WhatIfPreference = $true; $global:PSDefaultParameterValues['Set-Clipboard:WhatIf'] = $true } -Inputs $OK2 `
    -Want @((& $OKLINE $PACL), '판정: kv 7경로 준비 완료') -NotWant @('What if') -Post {
      $global:WhatIfPreference = $OrigWhatIf
      $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
      Check '하네스 자체: 세션 $PSDefaultParameterValues 복원 뒤 Set-Clipboard:WhatIf 키 없음(Clone 저장 · Clone 교체 복원 — T054 리뷰 r4 O4)' (-not $global:PSDefaultParameterValues.ContainsKey('Set-Clipboard:WhatIf'))
      Check '하네스 자체: 세션 $WhatIfPreference 복원' ($global:WhatIfPreference -eq $OrigWhatIf)
      Check '클립보드 비우기 2회가 실제로 실행됐다(clip:set 2 · clip:whatif 0 — ShouldProcess 를 따르는 모의)' (@($global:Events | Where-Object { SEq $_ 'clip:set' }).Count -eq 2 -and (Ev-Index 'clip:whatif') -lt 0) "clip:set $(@($global:Events | Where-Object { SEq $_ 'clip:set' }).Count) · whatif $(@($global:Events | Where-Object { SEq $_ 'clip:whatif' }).Count)"
      Check 'VAULT_* 환경 변수 0(finally 의 Remove-Item 이 WhatIf 로 건너뛰어지지 않았다)' (@(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0)
      foreach ($e in $PATHS) { Check-Created $e } }

  # ---- S11: 실행 뒤 환경 · 조건부 정리 · $Error
  Run-Case 'S11a' '정상 완주 뒤 VAULT_TOKEN·VAULT_ADDR 없음 · 블록이 남긴 전역 변수·$Error 에 값 없음' -Inputs $OK2 -Post {
      Check 'VAULT_* 환경 변수 0' (@(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) }).Count -eq 0)
      $newG = @(Get-Variable -Scope Global | Where-Object { $HarnessGlobals -notcontains $_.Name -and -not ($global:GvBefore.ContainsKey($_.Name) -and [object]::ReferenceEquals($global:GvBefore[$_.Name], $_.Value)) } |
          Where-Object { $t = Flat-Text $_.Value; $t.Contains('"password"') -or $t.Contains('"users.acl"') -or $t.Contains('redis:') -or $t.Contains('USER admin') -or $t.Contains('hvs.') } | ForEach-Object { $_.Name })
      Check '이 실행으로 생기거나 바뀐 전역 변수에 put 본문(JSON "password" · "users.acl") · url · acl 줄 · 토큰 모양 문자열 0' ($newG.Count -eq 0) ($newG -join ', ')
      Check '$Error 에 블록이 남긴 기록 0(finally 가 이 실행분을 지운다)' ($global:Error.Count -eq 0) "Error $($global:Error.Count)" }
  Run-Case 'S11b' '시작 전 VAULT_TOKEN 이 이미 있음 → 토큰을 묻지 않고 중단 · 기존 값은 건드리지 않는다(조건부 정리)' -PreEnv @{ VAULT_TOKEN = $global:FAKE_PRE_TOKEN } `
    -Setup { [void]$global:ExtraSecrets.Add($global:FAKE_PRE_TOKEN) } -Inputs $OK2 -Expect 'VAULT_* 환경 변수가 이미 있다: VAULT_TOKEN' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S11c' '시작 전 VAULT_ADDR = 기대값(http://127.0.0.1:18200) → 그대로 진행 · 끝나면 제거' -PreEnv @{ VAULT_ADDR = $global:EXPECTED_ADDR } -Inputs $OK2 `
    -Want @((& $OKLINE $PACL)) -Post { foreach ($e in $PATHS) { Check-Created $e } }
  Run-Case 'S11d' '시작 전 다른 VAULT_*(VAULT_NAMESPACE) → 이름만 보이고 중단 · 기존 변수는 건드리지 않는다' -PreEnv @{ VAULT_NAMESPACE = 'MOCK-ns' } -Inputs $OK2 `
    -Expect 'VAULT_NAMESPACE' -Post {
      Check '기존 VAULT_NAMESPACE 그대로' (SEq $env:VAULT_NAMESPACE 'MOCK-ns'); Check '입력 0' ($global:ReadLog.Count -eq 0) }
  Run-Case 'S11e' '시작 전 VAULT_ADDR 가 다른 주소 → 중단 · 기존 값 그대로(어느 Vault 인지 모호)' -PreEnv @{ VAULT_ADDR = 'https://vault.example.invalid' } -Inputs $OK2 `
    -Expect 'VAULT_ADDR' -Post { Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S11f' '되읽기 응답이 깨진 JSON(안에 비밀번호 · 첫 경로 dev admin) → 고정 문구로 중단 · 화면·$Error 에 값 없음' -Setup { $global:F['readGarbage'][$DA.path] = 1 } -Inputs $OK2 `
    -Expect '되읽기 실패' -Want @('되읽기 응답을 해석하지 못했다') -Post { Check 'put 1회' ($global:PutCalls.Count -eq 1); Check-Absent $DI }

  # ---- S12(구조 · 정적)는 맨 앞에서 관문으로 돌았다

  # ---- S13–S19: 토큰 · put · 재실행 · 그 밖의 fail-closed
  Run-Case 'S13a' 'root 토큰 빈 입력 → 중단(token lookup 0 · 쓰기 0)' -Inputs @('', 'seed') -Expect '빈 입력 — 중단' -Post {
      Check 'token lookup 0' ((Ev-Index 'vault:token-lookup') -lt 0); Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S13b' 'root 토큰 앞뒤 공백 → Trim 뒤 정상 완주' -Inputs @((' ' + $ROOT + ' '), 'seed') -Want @((& $OKLINE $DA)) -Post { foreach ($e in $PATHS) { Check-Created $e } }
  Run-Case 'S14' '토큰 정책에 root 없음 → 판정 전 중단(metadata 조회 0 · 쓰기 0)' -Setup { $global:TokenPolicies = @('default', 'admin') } -Inputs $OK2 -Expect '토큰 정책에 root 가 없다' -Post {
      Check 'metadata 조회 0' ((Ev-First 'vault:meta-get:') -lt 0); Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S14b' '(T056 리뷰 r1 H1) 형식은 맞지만(hvs.) root 가 아닌 토큰 → token lookup 403(exit 2) → root 토큰 확인 실패로 판정 전 중단(token lookup 1 · metadata 조회 0 · 쓰기 0 · VAULT_TOKEN 제거 · 노출 0)' `
    -Setup { [void]$global:ExtraSecrets.Add($global:FAKE_WRONG_TOKEN) } -Inputs @($global:FAKE_WRONG_TOKEN, 'seed') -Expect 'root 토큰 확인 실패(token lookup exit=2)' -Post {
      Check 'token lookup 1회' (@($global:Events | Where-Object { SEq $_ 'vault:token-lookup' }).Count -eq 1)
      Check 'metadata 조회 0' ((Ev-First 'vault:meta-get:') -lt 0); Check 'put 0' ($global:PutCalls.Count -eq 0)
      Check '입력 1(토큰 — seed 정지점까지 가지 않았다)' ($global:ReadLog.Count -eq 1) }
  Run-Case 'S15' 'hvs. 로 시작하지 않는 값(복구 키 조각 등) → Vault 로 보내기 전에 중단' -Setup { [void]$global:ExtraSecrets.Add($global:FAKE_SHARE) } -Inputs @($global:FAKE_SHARE, 'seed') `
    -Expect '입력이 Vault 토큰 형식' -Post { Check 'token lookup 0(Vault 로 보내지 않았다)' ((Ev-Index 'vault:token-lookup') -lt 0); Check 'put 0' ($global:PutCalls.Count -eq 0) }
  # S16 · S16d · S16e: put 비 0 = CAS 거부 · 권한 · 연결 · "응답 유실 뒤 CLI 자동 재시도(VAULT_MAX_RETRIES 기본 2)가 자기 기록과 CAS 충돌" 중 하나 —
  # 종료 코드 · 문구로 가를 수 없다. 블록은 값을 출력하지 않고 재판정한다(T056 그대로 — 경로만 T057)
  Run-Case 'S16' 'put 거부(권한 등 비 0 · 경로는 그대로 없음 · 첫 경로 dev admin) → 재판정 absent = 쓰지 않았다 · 그 경로에서 중단 · 뒤 경로 미실행' -Setup { $global:F['putFail'][$DA.path] = 2 } -Inputs $OK2 -Expect 'put 거부' `
    -Want @("STOP $($DA.path) — put 거부(exit=2) · 재판정 absent", '중단(put 거부 exit=2 — 재판정 absent · 쓰지 않았다)', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 0건') -NotWant @('기록됨(응답 유실', '결과 미확인 1', 'CAS 충돌') -Post {
      Check 'put 1회' ($global:PutCalls.Count -eq 1); foreach ($e in $PATHS) { Check-Absent $e }
      $ip = Ev-Index "vault:put:$($DA.path)"
      Check '재판정: put 거부 뒤 metadata get 1 · kv get 0(absent 라 되읽지 않는다)' ($ip -ge 0 -and (Ev-Index "vault:meta-get:$($DA.path)" ($ip + 1)) -gt $ip -and (Ev-First 'vault:kv-get:') -lt 0) }
  Run-Case 'S16d' 'put 응답 유실(dev acl — 서버는 커밋 · CLI 재시도가 자기 기록과 CAS 충돌 → exit 2) → 재판정 live v1 · 되읽기 해시 일치 → 기록됨(응답 유실 — 이 실행의 값) · cv=1 확인 · 다음 경로 계속 · 7개 완주' `
    -Setup { $global:F['putLost'][$DACL.path] = 1 } -Inputs $OK2 `
    -Want @("OK   $($DACL.path) v1 — 기록됨(응답 유실 — 이 실행의 값 · put exit=2 뒤 재판정) · 되읽기 해시 일치(users.acl)", (& $OKLINE $PACL), '응답 유실 뒤 재판정으로 검증 완료 1', '판정: kv 7경로 준비 완료') `
    -NotWant @('STOP ', 'CAS 충돌', '결과 미확인 1') -Post {
      foreach ($e in $PATHS) { Check-Created $e }
      $row = Summary-Row $DACL.path
      Check "요약 행($($DACL.path)) = 기록됨(응답 유실 — 이 실행의 값 …) · 되읽기 해시 일치(users.acl)" ($row.Contains('기록됨(응답 유실 — 이 실행의 값') -and $row.Contains('되읽기 해시 일치(users.acl)')) $row
      Check 'put 7회(유실 경로를 다시 put 하지 않는다 — 재판정으로 가른다)' ($global:PutCalls.Count -eq 7)
      $ip = Ev-Index "vault:put:$($DACL.path)"; $im = Ev-Index "vault:meta-get:$($DACL.path)" ($ip + 1); $ig = Ev-Index "vault:kv-get:$($DACL.path)" ($ip + 1); $im2 = Ev-Index "vault:meta-get:$($DACL.path)" ($ig + 1)
      Check '재판정 순서: put(exit 2) → metadata get(live v1) → kv get(해시 대조) → metadata get(cv=1 확인) → 다음 경로 put' ($ip -ge 0 -and $im -gt $ip -and $ig -gt $im -and $im2 -gt $ig -and (Ev-Index "vault:put:$($PA.path)") -gt $im2) "put=$ip meta=$im get=$ig meta2=$im2"
      Check-WriteOrder $PATHS }
  Run-Case 'S16e' 'put 비 0 뒤 재판정 자체가 일시 오류(metadata 500 · 둘째 경로 dev identity-admin) → 결과 미확인(이 실행의 값이 기록됐는지 모른다 — 지우지 말고 재실행) · 그 자리에서 중단' `
    -Setup { $global:F['putFail'][$DI.path] = 2; $global:F['postMeta'][$DI.path] = 'err' } -Inputs $OK2 -Expect '결과 미확인' `
    -Want @("STOP $($DI.path) — put 거부(exit=2) · 재판정 error(current_version=-1 · metadata 조회 exit=2 · * context deadline exceeded)", (& $OKLINE $DA), '결과 미확인(put exit=2 — 재판정 error · current_version=-1 · 재실행이 판정한다)', '결과 미확인 1 ·', '판정: 미완') `
    -NotWant @("OK   $($DI.path)", 'CAS 충돌', '기록됨(응답 유실') -Post {
      $row = Summary-Row $DI.path
      Check "요약 행($($DI.path)) = 결과 미확인 · '쓰지 않았다' 없음" ($row.Contains('결과 미확인(put exit=2 — 재판정 error') -and -not $row.Contains('쓰지 않았다')) $row
      Check-Created $DA
      Check-Absent $DI
      Check 'put 2회' ($global:PutCalls.Count -eq 2)
      $ip = Ev-Index "vault:put:$($DI.path)"
      Check '재판정: put 거부 뒤 metadata get(500) · kv get 0' ($ip -ge 0 -and (Ev-Index "vault:meta-get:$($DI.path)" ($ip + 1)) -gt $ip -and (Ev-Index "vault:kv-get:$($DI.path)") -lt 0) }
  Run-Case 'S17' '재실행: 7경로 모두 live-ok → 7 SKIP · 쓰기 0 · 쓰기 확인 정지점 없음 · vault 호출 17회' -Setup { Seed-All } -Inputs @($ROOT) `
    -Want (@($PATHS | ForEach-Object { & $SKIPLINE $_ }) + @('INFO 쓸 경로 없음 — 7경로 모두 live-ok', '이 실행이 kv 에 새로 쓴 경로: 0건', '건너뜀 7', '판정: kv 7경로 준비 완료')) -NotWant @('STOP ', '쓸 경로 7개') -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰만)' ($global:ReadLog.Count -eq 1)
      foreach ($e in $PATHS) { Check-Unchanged $e (Live-Data $e) }
      Check 'vault 호출 17회(version 1 · status 1 · token lookup 1 · 경로마다 metadata get · kv get 2×7 — 런북 「실행」 재실행 문장의 근거)' ($global:ArgvLog.Count -eq 17) "vault 호출 $($global:ArgvLog.Count)" }
  Run-Case 'S18' '~/.vault-token 존재 → 시작 전 중단' -Setup { $global:VaultTokenFile = $true } -Inputs $OK2 -Expect '~/.vault-token 존재' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S19' 'live 판정 중 kv get 실패(dev admin) → 판정 불가 · 쓰기 0' -Setup { Seed-LiveOk $DA; $global:F['readFail'][$DA.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DA.path) — 판정 불가: kv get exit=2") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S19b' 'live 판정 중 kv get 응답이 깨진 JSON(안에 비밀번호 · dev admin) → 판정 불가(재실행 — live-mismatch 아님) · 쓰기 0 · 화면 · $Error 에 값 없음' `
    -Setup { Seed-LiveOk $DA; $global:F['readGarbage'][$DA.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DA.path) — 판정 불가: kv get 응답을 해석하지 못했다(원문 미출력)", '중단(판정 불가 — kv get 응답을 해석하지 못했다(원문 미출력))') -NotWant @('live-mismatch') -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0); Check '입력 1(토큰 — 쓰기 확인 정지점까지 가지 않았다)' ($global:ReadLog.Count -eq 1)
      Check-Unchanged $DA (Live-Data $DA) }
  Run-Case 'S19c' 'acl live 판정 중 kv get 실패(dev 사용자 3 live-ok · dev acl live) → acl 판정 불가 · 쓰기 0' -Setup { Seed-Env 'dev'; $global:F['readFail'][$DACL.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DACL.path) — 판정 불가: kv get exit=2") -Post { Check 'put 0' ($global:PutCalls.Count -eq 0); Check-Unchanged $DACL (Live-Data $DACL) }
  Run-Case 'S19d' 'acl live 판정 중 kv get 응답이 깨진 JSON(안에 acl 전문 · hex) → 판정 불가 · 쓰기 0 · 화면 · $Error 에 acl 내용 · hex 없음' -Setup { Seed-Env 'dev'; $global:F['readGarbage'][$DACL.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' `
    -Want @("STOP $($DACL.path) — 판정 불가: kv get 응답을 해석하지 못했다(원문 미출력)") -NotWant @('live-mismatch') -Post { Check 'put 0' ($global:PutCalls.Count -eq 0); Check-Unchanged $DACL (Live-Data $DACL) }

  # ---- S20: 쓰기 뒤 metadata 판정(current_version=1 · 삭제 없음)을 행동으로 단언 — put 이 성공한 뒤의 metadata 응답만 바꾼다
  Run-Case 'S20a' '쓰기 뒤 metadata 가 current_version 2(다른 기록자 — v2 도 live · 둘째 경로 dev identity-admin) → 메타데이터 확인 실패로 중단' `
    -Setup { $global:F['postMeta'][$DI.path] = 'cv2' } -Inputs $OK2 -Expect '메타데이터 확인 실패' `
    -Want @("STOP $($DI.path) — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(live · current_version=2", (& $OKLINE $DA), '기록됨 — 메타데이터 확인 실패(live · current_version=2)', '이 실행이 kv 에 새로 쓴 경로: 2건') `
    -NotWant @("OK   $($DI.path)") -Post {
      Check-Created $DA
      Check "$($DI.path): put 은 됐다(v1)" ((KvCur $DI.path) -eq 1)
      Check 'put 2회' ($global:PutCalls.Count -eq 2) }
  Run-Case 'S20b' '쓰기 뒤 metadata 의 현재 버전에 deletion_time(마운트 delete_version_after 의 삭제 예약 · 첫 경로 dev admin) → dead 로 중단 · 다음 경로 put 0' `
    -Setup { $global:F['postMeta'][$DA.path] = 'deletion' } -Inputs $OK2 -Expect '메타데이터 확인 실패' `
    -Want @("STOP $($DA.path) — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(dead · current_version=1", '기록됨 — 메타데이터 확인 실패(dead · current_version=1)', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '이 실행이 kv 에 새로 쓴 경로: 1건') `
    -NotWant @("OK   $($DA.path)") -Post {
      Check "$($DA.path): put 은 됐다(v1)" ((KvCur $DA.path) -eq 1)
      Check-Absent $DI
      Check 'put 1회(다음 경로 put 0)' ($global:PutCalls.Count -eq 1) }
  Run-Case 'S20c' '쓰기 뒤 metadata 조회가 일시 오류(500 · kind=error · 첫 경로 dev admin) → 메타데이터 확인 실패로 중단(OK 아님) · 다음 경로 put 0' `
    -Setup { $global:F['postMeta'][$DA.path] = 'err' } -Inputs $OK2 -Expect '메타데이터 확인 실패' `
    -Want @("STOP $($DA.path) — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(error · current_version=-1 · metadata 조회 exit=2 · * context deadline exceeded)", '기록됨 — 메타데이터 확인 실패(error · current_version=-1)', '이 실행이 kv 에 새로 쓴 경로: 1건') `
    -NotWant @("OK   $($DA.path)") -Post {
      Check "$($DA.path): put 은 됐다(v1)" ((KvCur $DA.path) -eq 1)
      Check-Absent $DI
      Check 'put 1회(다음 경로 put 0)' ($global:PutCalls.Count -eq 1) }

  # ---- S21: put 도중 중단(서버는 커밋) — 요약이 "쓰지 않았다"로 남지 않는다 · 재실행이 판정한다(B4: acl 은 live 사용자 비밀번호로 렌더)
  Run-Case 'S21a' 'put 도중 중단(Ctrl+C 대용 — 서버는 이미 커밋 · 둘째 경로 dev identity-admin) → 요약 행 = 결과 미확인("쓰지 않았다" 아님) · 집계 결과 미확인 1 · 판정 미완' `
    -Setup { $global:F['putInterrupt'][$DI.path] = 1 } -Inputs $OK2 -Expect '모의 중단' `
    -Want @('결과 미확인 1 ·', '판정: 미완', $SUMMARY, '창 종료 체크리스트', '미실행(앞 경로에서 중단 — 쓰지 않았다)', (& $OKLINE $DA)) -NotWant @("OK   $($DI.path)") -Post {
      $row = Summary-Row $DI.path
      Check "요약 행($($DI.path)) = 결과 미확인 · '쓰지 않았다' 없음" ($row.Contains('결과 미확인(put 진행 중 중단') -and -not $row.Contains('쓰지 않았다')) $row
      Check "$($DI.path): 서버 쪽은 커밋됐다(v1)" ((KvCur $DI.path) -eq 1)
      Check-Absent $DS
      Check 'put 2회' ($global:PutCalls.Count -eq 2) }
  Run-Case 'S21b' '재실행 복구: S21a 상태에서 다시 실행 → dev admin · dev identity-admin(결과 미확인 경로)은 live-ok 로 SKIP(덮어쓰기 0) · sample-pod · acl(live 2 + 새 1 로 렌더) · prod 3 생성' `
    -Setup { $global:F['putInterrupt'][$DI.path] = 1; Invoke-PreRun @($global:FAKE_ROOT, 'seed') } -Inputs $OK2 `
    -Want @((& $SKIPLINE $DA), (& $SKIPLINE $DI), (& $OKLINE $DS), (& $OKLINE $DACL), '판정: kv 7경로 준비 완료') -NotWant @('STOP ') -Post {
      Check '사전 실행은 둘째 경로 put 도중 멈췄다(put 2)' ($global:PreRunPuts -eq 2) "사전 put $($global:PreRunPuts)"
      foreach ($e in $PATHS) { Check-Created $e }
      Check '본 실행 put 5회(dev admin · identity-admin put 0)' ($global:PutCalls.Count -eq 5 -and @($global:PutCalls | Where-Object { (SEq $_.path $DA.path) -or (SEq $_.path $DI.path) }).Count -eq 0) }

  # ---- S22: PowerShell 모듈 로깅 정책(켜져 있으면 ConvertFrom-Json 의 InputObject — kv · token lookup 응답 원문 — 이 이벤트 4103 에 남는다 · T054 리뷰 O5)
  $PC_LM = $global:PolicyPaths[0]; $PC_CU = $global:PolicyPaths[1]; $WP_LM = $global:PolicyPaths[2]
  foreach ($c in @(@('S22a', 'PowerShellCore 모듈 로깅 켜짐(HKLM)', @{ $PC_LM = @{ EnableModuleLogging = 1 } }),
      @('S22b', 'PowerShellCore 모듈 로깅 켜짐(HKCU)', @{ $PC_CU = @{ EnableModuleLogging = 1 } }),
      @('S22c', 'UseWindowsPowerShellPolicySetting 값 1 + Windows PowerShell 모듈 로깅 켜짐(HKLM)', @{ $PC_LM = @{ UseWindowsPowerShellPolicySetting = 1 }; $WP_LM = @{ EnableModuleLogging = 1 } }))) {
    $script:pol22 = $c[2]
    Run-Case $c[0] "$($c[1]) → 시작 전 중단(입력 0 · vault 호출 0)" -Setup { foreach ($k in @($script:pol22.Keys)) { $global:Policy[$k] = $script:pol22[$k] } } -Inputs $OK2 `
      -Expect '모듈 로깅 정책이 켜져 있다' -Post { Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) } }
  Run-Case 'S22d' 'UseWindowsPowerShellPolicySetting 값 1 · 양쪽 EnableModuleLogging 값 0 → 그대로 진행(7개 생성) · 정책 키 4개를 모두 읽었다' `
    -Setup { $global:Policy[$PC_LM] = @{ UseWindowsPowerShellPolicySetting = 1; EnableModuleLogging = 0 }; $global:Policy[$WP_LM] = @{ EnableModuleLogging = 0 } } -Inputs $OK2 `
    -Want @((& $OKLINE $PACL)) -Post {
      foreach ($e in $PATHS) { Check-Created $e }
      Check '정책 키 4개(PowerShellCore 2 · Windows PowerShell 2)를 읽었다' (@($global:PolicyPaths | Where-Object { (Ev-Index "reg:policy:$_") -ge 0 }).Count -eq 4) }

  # ---- 런북 「정리 판단」 두 블록: R1 · R2 정적(관문 6) → GA(① 점검 · vault 쓰기 명령 0) · GB(② 삭제)
  #      가짜 kv 에는 7경로 밖의 소비 중인 경로(kv/platform/cloudflare/tunnel · T056 의 kv/prod/kafka/identity-admin · T054 의 kv/prod/db/identity_admin/owner — 가짜 값)도 둔다 —
  #      허용 목록 밖 입력이 그 경로에 닿지 않는지(vault 호출 0) 본다
  $MI = '[t057-cleanup-inspect]'; $MD = '[t057-cleanup-delete]'
  $TUN = 'kv/platform/cloudflare/tunnel'
  $TUNTOK = 'MOCK-tunnel-token-Gy7Jq3Lw8Pz2Rt5Vb9Nm4Yc1Kd6Fs0Hp'
  $T056P = 'kv/prod/kafka/identity-admin'
  $T056PW = 'MOCK-t056-scram-Xc4Vb7Nm1Qw9Er3Ty6Ui8Op2As5D'
  $T054P = 'kv/prod/db/identity_admin/owner'
  $T054PW = 'MOCK-t054-owner-Wq3Ze8Rv1Tb6Yn4Um9Ik2Ol7Pa5Sd0X'
  function Seed-Others {
    Seed-Path $TUN ([ordered]@{ token = $TUNTOK }); [void]$global:ExtraSecrets.Add($TUNTOK)
    Seed-Path $T056P ([ordered]@{ password = $T056PW })
    Seed-Path $T054P ([ordered]@{ username = 'identity_admin_owner'; password = $T054PW; url = 'MOCK-t054-url' }) }
  function Others-Intact { Check '7경로 밖 경로(터널 · T056 · T054) 그대로' ($global:Kv.ContainsKey($TUN) -and $global:Kv.ContainsKey($T056P) -and $global:Kv.ContainsKey($T054P) -and (KvCur $TUN) -eq 1 -and (KvCur $T056P) -eq 1 -and (KvCur $T054P) -eq 1) }
  $gateR1 = Run-RbStatic 'R1' '런북 ① 점검 블록(읽기 전용) 정적: 코드 펜스 추출(표식 1 · 들여쓰기 제거) · 첫 줄 & { · 표식 주석 · 끝 } · 빈 줄 0 · TAB 0 · CR 0 · 파서 오류 0 · 최상위 1문 · 명령/형식/$Host/리다이렉트 허용 목록(관문) · Read-Host 1곳 평문 + 바로 앞 비움(AST) · 첫 Read-Host 전 클립보드 비움 · vault = kv metadata get · kv get -format=json 만(put · delete 0) · 허용 경로 = 계약 7경로 · MOCK/비밀 상수/hvs./Start-Transcript/env 쓰기 0' $MI @('kv metadata get -format=json', 'kv get -format=json') 1
  $gateR2 = Run-RbStatic 'R2' '런북 ② 삭제 블록 정적: 같은 검사 · Read-Host 2곳 평문(경로 · 재입력) + 바로 앞 비움 · vault = kv metadata get -format=json · kv metadata delete 만(put · kv get 0) · 허용 경로 = 계약 7경로' $MD @('kv metadata get -format=json', 'kv metadata delete') 2
  if ($gateR1) { Write-Host "관문 FAIL(R1): $gateR1 — GA 시나리오(① 점검 블록 실행)를 돌리지 않는다" -ForegroundColor Red }
  else {
    Run-RbCase 'GA01' '① 점검: live 사용자 경로(dev identity-admin) → 상태 · current_version · delete_version_after · 버전 이력(값 없음) · 현재 버전 키 이름만(password · url) · vault = metadata get 1 + kv get 1 · 쓰기 명령 0 · 값 노출 0' $MI `
      -Setup { Seed-LiveOk $DI; Seed-Others } -Inputs @($DI.path) `
      -Want @("$($DI.path) — current_version=1 · delete_version_after=0s", '  v1  created=2026-10-13T00:00:00Z  deletion_time=  destroyed=False', '현재 버전 키 이름(값 미출력): password · url', '점검 끝 — 이 블록은 아무것도 쓰지 않았다') -NotWant @('OK   ') -Post {
        Check 'vault 호출 = metadata get 1 · kv get 1(그 밖 0)' ((Ev-Index "vault:meta-get:$($DI.path)") -ge 0 -and (Ev-Index "vault:kv-get:$($DI.path)") -gt (Ev-Index "vault:meta-get:$($DI.path)") -and @($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 2)
        Check '입력 1(경로)' ($global:ReadLog.Count -eq 1)
        Check-Unchanged $DI (Live-Data $DI) }
    Run-RbCase 'GA01b' '① 점검: live acl 경로(dev acl) → 키 이름 users.acl 만 · acl 내용 · hex 노출 0 · 쓰기 명령 0' $MI `
      -Setup { Seed-Env 'dev'; Seed-Others } -Inputs @($DACL.path) `
      -Want @("$($DACL.path) — current_version=1 · delete_version_after=0s", '현재 버전 키 이름(값 미출력): users.acl', '점검 끝 — 이 블록은 아무것도 쓰지 않았다') -NotWant @('USER ', '#') -Post {
        Check 'vault 호출 = metadata get 1 · kv get 1' (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 2)
        Check-Unchanged $DACL (Live-Data $DACL) }
    Run-RbCase 'GA02' '① 점검: absent 경로 → "absent(메타데이터 없음 …)" 한 줄 · vault = metadata get 1 · kv get 0' $MI -Setup { Seed-Others } -Inputs @($DS.path) `
      -Want @("$($DS.path) — absent(메타데이터 없음") -Post {
        Check 'vault 호출 = metadata get 1 만' (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 1 -and (Ev-First 'vault:kv-get:') -lt 0) }
    foreach ($c in @(@('GA03a', '7경로 밖(소비 중인 kv/platform/cloudflare/tunnel)', $TUN), @('GA03b', '끝 공백이 붙은 경로', ($DI.path + ' ')), @('GA03c', '대소문자가 다른 경로(Ordinal)', $DI.path.ToUpperInvariant()),
        @('GA03d', 'T056 경로(kv/prod/kafka/identity-admin — 다른 과제의 소비 중 경로)', $T056P), @('GA03e', 'T054 경로(kv/prod/db/identity_admin/owner — 다른 과제의 소비 중 경로)', $T054P))) {
      $script:ga3 = $c[2]
      Run-RbCase $c[0] "① 점검: $($c[1]) → vault 호출 0 으로 중단(아무것도 조회하지 않았다)" $MI -Setup { Seed-LiveOk $DI; Seed-Others } -Inputs @($script:ga3) -Expect '7경로 밖이다' -Post {
          Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0); Check '입력 1' ($global:ReadLog.Count -eq 1) } }
    Run-RbCase 'GA04' '① 점검: dead(현재 버전 soft-delete) → deletion_time 이 보이고 현재 버전 데이터 없음 · 값 노출 0' $MI `
      -Setup { Seed-Path $DI.path (Live-Data $DI) 1 '2026-10-13T05:00:00Z'; Seed-Others } -Inputs @($DI.path) `
      -Want @("$($DI.path) — current_version=1", '  v1  created=2026-10-13T00:00:00Z  deletion_time=2026-10-13T05:00:00Z  destroyed=False', '현재 버전 데이터: 없음(soft-delete · destroy)') -Post {
        Check '버전 불변' ((KvCur $DI.path) -eq 1) }
    Run-RbCase 'GA05' '① 점검: metadata 조회 일시 오류(500) → 판정 불가로 중단 · kv get 0' $MI -Setup { Seed-LiveOk $DA; $global:F['metaError'][$DA.path] = 1 } -Inputs @($DA.path) -Expect 'metadata 조회 실패(exit=2)' -Post {
        Check 'kv get 0' ((Ev-First 'vault:kv-get:') -lt 0) }
    Run-RbCase 'GA06' '① 점검: metadata 는 live 인데 kv get 이 비 0 → "현재 버전 데이터: 읽지 못했다" 로 끝난다(값 없음 · 완주)' $MI -Setup { Seed-LiveOk $DA; $global:F['readFail'][$DA.path] = 1 } -Inputs @($DA.path) `
      -Want @("$($DA.path) — current_version=1", '현재 버전 데이터: 읽지 못했다') -Post { Check-Unchanged $DA (Live-Data $DA) }
    Run-RbCase 'GA07' '① 점검: 메타데이터만 있고 버전 없음(current_version 0) → 이력 0행 · 데이터 읽지 못했다 · 쓰기 0' $MI -Setup { Seed-Path $DS.path $null 0 } -Inputs @($DS.path) `
      -Want @("$($DS.path) — current_version=0", '현재 버전 데이터: 읽지 못했다') -NotWant @('  v1  ') -Post { Check 'kv 그대로' ($global:Kv.ContainsKey($DS.path)) }
    Run-RbCase 'GA08' '① 점검: kv get 응답이 깨진 JSON(안에 비밀번호 — 과도기 상태 · dev admin) → ConvertFrom-Json 종료 오류로 중단 · 화면 · $Error 에 값 없음 · 쓰기 0 · 값 불변' $MI `
      -Setup { Seed-LiveOk $DA; Seed-Others; $global:F['readGarbage'][$DA.path] = 1 } -Inputs @($DA.path) -Expect 'Unexpected end when reading token' `
      -Want @("$($DA.path) — current_version=1 · delete_version_after=0s") -NotWant @('현재 버전 키 이름', '점검 끝') -Post {
        Check 'vault 호출 = metadata get 1 · kv get 1(그 밖 0)' (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 2)
        Check '입력 1(경로)' ($global:ReadLog.Count -eq 1)
        Check-Unchanged $DA (Live-Data $DA) }
    Run-RbCase 'GA08b' '① 점검: dev acl 의 kv get 응답이 깨진 JSON(안에 acl 전문 — 줄바꿈 · hex) → ConvertFrom-Json 종료 오류(경로 · 위치만)로 중단 · acl 내용 · hex 노출 0' $MI `
      -Setup { Seed-Env 'dev'; $global:F['readGarbage'][$DACL.path] = 1 } -Inputs @($DACL.path) -Expect 'Unexpected end when reading token' `
      -Want @("$($DACL.path) — current_version=1 · delete_version_after=0s") -NotWant @('현재 버전 키 이름', '점검 끝', 'USER ') -Post { Check-Unchanged $DACL (Live-Data $DACL) }
    Run-RbCase 'GA09' '① 점검: password 와 Password(대소문자만 다른 키)가 함께 있다 → ConvertFrom-Json 종료 오류(키 이름만 — 값 없음)로 중단 · 쓰기 0 · 값 불변' $MI `
      -Setup { $d = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal); $d['password'] = $pwA; $d['Password'] = $pwDup; Seed-Path $DA.path $d; [void]$global:ExtraSecrets.Add($pwDup) } `
      -Inputs @($DA.path) -Expect "'Password'" -Want @("$($DA.path) — current_version=1 · delete_version_after=0s") -NotWant @('현재 버전 키 이름', '점검 끝') -Post {
        Check 'vault 호출 = metadata get 1 · kv get 1(그 밖 0)' (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:', [StringComparison]::Ordinal) }).Count -eq 2)
        Check "$($DA.path): 버전 불변(v1)" ((KvCur $DA.path) -eq 1) } }
  if ($gateR2) { Write-Host "관문 FAIL(R2): $gateR2 — GB 시나리오(② 삭제 블록 실행)를 돌리지 않는다" -ForegroundColor Red }
  else {
    # 공통 준비: dev 4경로 live(지울 수 있는 경로) + 7경로 밖 소비 중 경로(터널 토큰 · T056 · T054)
    foreach ($c in @(@('GB01', '7경로 밖(소비 중인 kv/platform/cloudflare/tunnel)', $TUN), @('GB02', '끝 공백이 붙은 경로', ($DI.path + ' ')), @('GB03', '대소문자가 다른 경로(Ordinal)', $DI.path.ToUpperInvariant()),
        @('GB03b', 'T056 경로(kv/prod/kafka/identity-admin — 다른 과제의 소비 중 경로)', $T056P), @('GB03c', 'T054 경로(kv/prod/db/identity_admin/owner — 다른 과제의 소비 중 경로)', $T054P))) {
      $script:gb1 = $c[2]
      Run-RbCase $c[0] "② 삭제: $($c[1]) → vault 호출 0 · 삭제 0 으로 중단" $MD -AllowDelete -Setup { Seed-Env 'dev'; Seed-Others } -Inputs @($script:gb1, $script:gb1) -Expect '7경로 밖이다' -Post {
          Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0); Check '입력 1(재입력을 묻지 않았다)' ($global:ReadLog.Count -eq 1)
          Others-Intact; foreach ($e in @($DA, $DI, $DS, $DACL)) { Check-Unchanged $e (Live-Data $e) } } }
    foreach ($c in @(@('GB04', '재입력이 다른 7경로(dev identity-admin → dev admin)', $DA.path), @('GB05', '재입력 빈 Enter', ''), @('GB06', '재입력 끝 공백', ($DI.path + ' ')),
        @('GB06b', '재입력 대문자(경로 전체 — 대소문자만 다르다 · Ordinal)', $DI.path.ToUpperInvariant()))) {
      $script:gb4 = $c[2]
      Run-RbCase $c[0] "② 삭제: 경로 입력 뒤 $($c[1]) → 삭제 0 으로 중단(재입력 Ordinal 일치만 통과)" $MD -AllowDelete -Setup { Seed-Env 'dev'; Seed-Others } -Inputs @($DI.path, $script:gb4) -Expect '입력이 경로와 다르다' -Post {
          Check 'metadata get 1 · delete 0' ((Ev-Index "vault:meta-get:$($DI.path)") -ge 0 -and (Ev-First 'vault:meta-delete:') -lt 0)
          Check '입력 2' ($global:ReadLog.Count -eq 2); foreach ($e in @($DA, $DI, $DS, $DACL)) { Check-Unchanged $e (Live-Data $e) } } }
    Run-RbCase 'GB07' '② 삭제: 정확한 재입력(dev identity-admin) → metadata get → delete → metadata get(No value found) → OK · 그 경로만 사라짐 · acl 도 지우라는 안내(B4)' $MD -AllowDelete -Setup { Seed-Env 'dev'; Seed-Others } -Inputs @($DI.path, $DI.path) `
      -Want @("OK   $($DI.path) — 모든 버전 · 메타데이터 삭제(No value found 확인)", '같은 env 의 acl 경로도 지운다', 'op1-seed-dragonfly.ps1 을 새 프로세스로 재실행한다') -Post {
        Check "$($DI.path) 가 kv 에서 사라졌다" (-not $global:Kv.ContainsKey($DI.path))
        foreach ($e in @($DA, $DS, $DACL)) { Check-Unchanged $e (Live-Data $e) }; Others-Intact
        $i1 = Ev-Index "vault:meta-get:$($DI.path)"; $id = Ev-Index "vault:meta-delete:$($DI.path)"; $i2 = Ev-Index "vault:meta-get:$($DI.path)" ($id + 1)
        Check '순서: metadata get → metadata delete → metadata get(삭제 확인) · vault 호출 3' ($i1 -ge 0 -and $id -gt $i1 -and $i2 -gt $id -and $global:ArgvLog.Count -eq 3) "get=$i1 del=$id get2=$i2 argv=$($global:ArgvLog.Count)"
        Check '둘째 프롬프트에 "되돌릴 수 없다" · current_version' ($global:Prompts.Count -eq 2 -and ([string]$global:Prompts[1]).Contains('되돌릴 수 없다') -and ([string]$global:Prompts[1]).Contains('current_version=1')) }
    Run-RbCase 'GB07b' '② 삭제: 정확한 재입력(dev acl) → 삭제 · No value found 확인 · OK · 사용자 경로 그대로' $MD -AllowDelete -Setup { Seed-Env 'dev'; Seed-Others } -Inputs @($DACL.path, $DACL.path) `
      -Want @("OK   $($DACL.path) — 모든 버전 · 메타데이터 삭제(No value found 확인)") -Post {
        Check "$($DACL.path) 가 kv 에서 사라졌다" (-not $global:Kv.ContainsKey($DACL.path))
        foreach ($e in @($DA, $DI, $DS)) { Check-Unchanged $e (Live-Data $e) }; Others-Intact }
    Run-RbCase 'GB08' '② 삭제: metadata 조회 실패(500) → 재입력을 묻지 않고 중단 · 삭제 0' $MD -AllowDelete -Setup { Seed-LiveOk $DA; $global:F['metaError'][$DA.path] = 1 } -Inputs @($DA.path, $DA.path) -Expect 'metadata 조회 실패(exit=2)' -Post {
        Check '입력 1 · delete 0' ($global:ReadLog.Count -eq 1 -and (Ev-First 'vault:meta-delete:') -lt 0); Check-Unchanged $DA (Live-Data $DA) }
    Run-RbCase 'GB09' '② 삭제: delete 가 비 0(권한 거부) → "삭제 실패" 로 중단 · 경로 그대로' $MD -AllowDelete -Setup { Seed-LiveOk $DA; $global:F['delFail'][$DA.path] = 1 } -Inputs @($DA.path, $DA.path) -Expect '삭제 실패(exit=2)' -NotWant @('OK   ') -Post {
        Check-Unchanged $DA (Live-Data $DA) }
    Run-RbCase 'GB10' '② 삭제: delete 는 exit 0 인데 경로가 남아 있다 → 삭제 뒤 확인(No value found 아님)으로 중단' $MD -AllowDelete -Setup { Seed-LiveOk $DA; $global:F['delNoop'][$DA.path] = 1 } -Inputs @($DA.path, $DA.path) -Expect '삭제 확인 실패(경로가 남았거나 조회 오류)' -NotWant @('OK   ') -Post {
        Check '경로가 남아 있다(모의 noop)' ($global:Kv.ContainsKey($DA.path)); Check 'metadata get 2(삭제 전 · 삭제 뒤 확인)' (@($global:Events | Where-Object { SEq $_ "vault:meta-get:$($DA.path)" }).Count -eq 2) }
    Run-RbCase 'GB11' '② 삭제: 경로가 이미 없다(absent) → "지울 것이 없다" 로 중단 · 재입력 없음 · delete 0' $MD -AllowDelete -Setup { Seed-LiveOk $DS } -Inputs @($DA.path, $DA.path) -Expect '이미 없다(absent)' -Post {
        Check '입력 1 · delete 0' ($global:ReadLog.Count -eq 1 -and (Ev-First 'vault:meta-delete:') -lt 0) }
    Run-RbCase 'GB12' '② 삭제: 삭제는 됐는데 삭제 뒤 확인 조회가 500 → "없어졌다" 로 보지 않고 삭제 확인 실패로 중단(OK 아님)' $MD -AllowDelete -Setup { Seed-LiveOk $DA; $global:F['postDelErr'][$DA.path] = 1 } -Inputs @($DA.path, $DA.path) -Expect '삭제 확인 실패(경로가 남았거나 조회 오류)' -NotWant @('OK   ') -Post {
        Check '삭제는 됐다(모의)' (-not $global:Kv.ContainsKey($DA.path) -and (Ev-Index "vault:meta-delete:$($DA.path)") -ge 0) } }
}
catch {
  # 관문 FAIL 로 멈춘 경우만 여기서 삼킨다(결과 표 · exit 1 은 아래) — 그 밖의 예외(하네스 결함)는 그대로 다시 던진다
  if (-not $GateMsg) { throw }
}
finally {
  # 세션 설정을 먼저 되돌린다(S10e 가 바꾼 WhatIf · 기본 매개변수 값이 남아 있으면 아래 Remove-Item 이 건너뛰어진다)
  $global:WhatIfPreference = $OrigWhatIf
  $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
  $env:PATH = $OrigPath
  if ($null -eq $OrigKubeconfig) { Remove-Item -LiteralPath Env:KUBECONFIG -ErrorAction SilentlyContinue } else { $env:KUBECONFIG = $OrigKubeconfig }
  Remove-Item -LiteralPath $TrapDir -Recurse -Force -ErrorAction SilentlyContinue
  foreach ($v in @(Get-ChildItem Env: | Where-Object { $_.Name.StartsWith('VAULT_', [StringComparison]::OrdinalIgnoreCase) })) { Remove-Item -LiteralPath ('Env:' + $v.Name) }
}

# ---------------------------------------------------------------- 결과
Write-Host "`n=== 결과 ==="
if ($GateMsg) { Write-Host "관문 FAIL(S12 정적 허용 목록) — 런타임 시나리오 0개 실행(블록 실행 0회): $GateMsg" }
foreach ($r in $Results) { Write-Host ("{0} {1,-5} ({2,3}/{3,3}) {4}{5}" -f $(if ($r.pass) { 'PASS' } else { 'FAIL' }), $r.id, ($r.total - $r.failed), $r.total, $r.desc, $(if ($r.pass) { '' } else { "`n        ↳ " + $r.detail })) }
$cases = $Results.Count
$casePass = @($Results | Where-Object { $_.pass }).Count
$checks = 0; $checkFail = 0; foreach ($r in $Results) { $checks += $r.total; $checkFail += $r.failed }
Write-Host ("시나리오 PASS {0} / {1}" -f $casePass, $cases)
Write-Host ("PASS {0} / {1}   (단언 수 — 시나리오 {2}개 · 정적 구조 검사 S12 · 런북 블록 R1 · R2 포함 · 실물 vault/kubectl 호출 0 가드)" -f ($checks - $checkFail), $checks, $cases)
Write-Host ("실행 시간 {0:N1}초" -f $Clock.Elapsed.TotalSeconds)
if ($GateMsg -or $casePass -ne $cases -or $checkFail -gt 0) { exit 1 }
exit 0
