param([string]$Show = '', [string]$Block = '', [string]$Runbook = '', [string]$Dir = '', [string]$Only = '')
# ===== T075 운영자 블록 모의 실행 하네스 — A부: W-6(w6-render-dragonfly-acl.ps1) + 런북 §4 T057 「정리 판단」 두 블록(① 점검 · ② 삭제 — T057 그대로 · 수정 라운드 1부터
#        UD-9 적용 순서 2단계는 B부의 acl 삭제 블록) · B부: O-1 · O-2 · W-2 · O-3 · O-4 · O-5 · O-6 사전 · O-6 사후 · W-6 ACL LOAD · W-6 acl 삭제(w6-acl-delete.ps1) =====
# 수정 라운드 1(2026-11-17–18 · 리뷰 KA · KB): 공통 사후 Check-R1(실효 모듈 로깅 순서 · 보안 입력 다음 = 클립보드 비움 · 모의 호출 시점 env · 화면 제어 문자 0) · Check-ErrClean($Error) ·
#   정적 Static-R1(대입 제한 · 실효 확인 꼴) · 모의(Import-Module · Get-Module · Get-Content · 설정 파일 Test-Path · curl 첫 인자 -q · 제어열 결함) · 붙여넣기 모드 · 새 사례 — README §2a · §4
# A부 선례: T057 하네스(../t057-blocks/harness.ps1 — 시나리오 152 · 단언 4923 · 닫힌 과제 문서 · 고치지 않는다)의 파생이다(설계 D20 — :103-105 · :896 의 규칙 상수를 B2 로).
#   가드 · 모의(vault · Read-Host · Set-Clipboard · Get-ItemProperty …) · 공통 사후 조건 · S12 정적 관문 · 런북 블록 추출(R1 · R2 → GA · GB) · 과도 상태 모의 · 경로 7 · url · 의존(B4) · 쌍 판정(B5)은
#   그대로이고, 규칙 상수(B2 꼬리) · 독립 구현 Acl-For(B2) · Acl-T057(옛 규칙 — 지금 라이브 kv acl 의 꼴) · W-6 판정(옛 규칙 acl STOP · $lint) · S12 정적 추가($lint 순수 함수 · 규칙 상수 · 쓰기 전 대조) ·
#   렌더 단위 시험 U05($lint) · 시나리오(S37a–c · S38 — 옛 규칙 acl STOP · ② 삭제 연쇄 · B2 꼬리 없는 렌더 FAIL(변이 사본))를 바꾸거나 더했다(README §4).
# B부: 같은 가드 · 모의 위에 kv patch · vault read · policy read · tofu · curl.exe · kubectl(exec → redis-cli --askpass 흉내) 모의와 블록별 정적 관문 · 공통 사후 조건(Run-OCase)을 더했다(README §4).
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
# acl 렌더(결정 B2): S12 가 블록의 $render 대입문을 AST 로 찾아 정적 규칙(순수 함수 · CR/NewLine 0 · -join 백틱 n · ToLowerInvariant · default 줄 정확히 $ACL_DEFAULT · 옛 줄 회귀 0 — F12)을 보고,
#   U01–U04 가 그 스크립트블록만 떼어 내 고정 입력(모의 비밀번호)으로 돌려 독립 구현 Acl-For(바이트마다 x2 hex)와 바이트 단위로 대조한다 · Dragonfly v1.40.1 aclfile 로더 모의(Test-AclLoader)를 통과하는지도 본다.
#   로더 모의는 파일 문법만 본다 — 인증 경로(AUTH · HELLO 가 default 의 ACL 로 검사된다)는 보지 못한다: 2026-10-22 VD-4 1차 실측 사고(default -@all = 아무도 인증 못 함)는 이 모의를 통과했고
#   로컬 Docker · 라이브 Job 실측이 잡았다(build-notes 「T057」 F12) → 옛 줄은 S12 의 default 줄 규칙이 정적으로 막는다.
# 런북 블록: docs/runbooks/bootstrap.md §4 T057 「정리 판단」의 ① 점검(읽기 전용) · ② 삭제 블록을 코드 펜스에서 그대로 추출해(표식 [t057-cleanup-inspect] · [t057-cleanup-delete])
#   같은 모의 vault/Read-Host 로 돌린다 — R1 · R2(정적 · 관문 6: 추출 · 파서 · 명령 · 정적 형식 · $Host · 리다이렉트) → GA01–GA09 · GA01b · GA03d · GA03e · GA08b(① 점검 — vault 쓰기 명령 0 단언) ·
#   GB01–GB12 · GB03b · GB03c · GB06b · GB07b(② 삭제 — 7경로 허용 목록 Ordinal · 경로 타자 재입력(Ordinal — 대소문자만 다른 재입력도 중단) · 삭제 뒤 No value found 확인 · 조회/삭제 실패 · 잔존 · 삭제 뒤 조회 오류 → 중단) ·
#   S37b(T075 — 옛 규칙 acl 2경로를 ② 삭제 블록으로 지운 뒤 W-6 재실행 — 설계 D20 적용 순서 2–3단계 연쇄).
#   관문이 FAIL 인 런북 블록은 런타임 시나리오에서 한 번도 실행하지 않는다. 두 블록은 첫 Read-Host 전에 클립보드를 공백으로 덮는다
#   (R1 · R2 가 문장을, Run-RbCase 공통 단언이 순서(clip:set < read:plain)와 값(공백만)을 고정한다). 두 블록은 T057 그대로다(이 과제는 펜스를 고치지 않는다 — T057 하네스가 같은 펜스를 시험한다).
# 사용: pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t075-blocks\harness.ps1
#       [-Show 'S01*'] 해당 시나리오의 화면 출력 표시 · [-Block <경로>] W-6 블록 파일(변이 사본)에 A부 시나리오를 돌린다 ·
#       [-Dir <디렉터리>] B부 블록들(변이 사본 — 같은 파일 이름)을 그 디렉터리에서 읽는다 · [-Runbook <경로>] 다른 런북 파일(변이 사본)에서 「정리 판단」 두 블록을 추출한다 ·
#       [-Only A|B] 한 부만 돌린다(반복 중 영향 사례만 — 마감에는 전체 1회)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
$Clock = [Diagnostics.Stopwatch]::StartNew()
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$BlockPath = if ([string]::IsNullOrEmpty($Block)) { Join-Path $here 'w6-render-dragonfly-acl.ps1' } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Block) }
$BlockDir = if ([string]::IsNullOrEmpty($Dir)) { $here } else { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Dir) }
$RunA = -not ([string]::Equals($Only, 'B', [StringComparison]::OrdinalIgnoreCase))
$RunB = -not ([string]::Equals($Only, 'A', [StringComparison]::OrdinalIgnoreCase))
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
$global:FAKE_ROOT = 'hvs.MOCK-ROOT-T075-dF5gH7jK9lM1nP3qR4sT'
$global:FAKE_PRE_TOKEN = 'hvs.MOCK-PREEXISTING-zY8xW6vU4tS2rQ0pO9n'
# 형식(hvs.)은 맞지만 root 토큰이 아닌 값 — 모의 Vault 는 FAKE_ROOT 가 아닌 토큰에 403(exit 2)으로 답한다(S14b · T056 리뷰 r1 H1 — token lookup 실패 분기)
$global:FAKE_WRONG_TOKEN = 'hvs.MOCK-WRONG-Ar9Ys3Fd5Tg7Uh2Jk4Il6Ox8'
$global:FAKE_SHARE = 'MOCK-recovery-share-Nl6Mi9Hg4Et1Bq3Rx8Fs'
# 경로 7(B1 — 배열 순서 = 블록의 판정 · 쓰기 순서: env 마다 사용자 → acl · dev → prod). keys = 키 집합(B3) · user = url · acl 의 사용자 이름 · use = 블록의 "쓸 경로" 목록 줄 괄호 안(값 없음 — 목록 줄 대조에만 쓴다)
$PATHS = @(
  [pscustomobject]@{ path = 'kv/dev/dragonfly/admin'; env = 'dev'; user = 'admin'; role = 'admin'; keys = @('password'); use = '키 password · 사용자 admin — 운영자 전용 · ESO 소비자 없음' }
  [pscustomobject]@{ path = 'kv/dev/dragonfly/identity-admin'; env = 'dev'; user = 'identity-admin'; role = 'pod'; keys = @('password', 'url'); use = '키 password · url · 사용자 identity-admin — vault-dev identity-admin-env(T075) · 검사 Job jt-dev/assert-data-env' }
  [pscustomobject]@{ path = 'kv/dev/dragonfly/sample-pod'; env = 'dev'; user = 'sample-pod'; role = 'pod'; keys = @('password', 'url'); use = '키 password · url · 사용자 sample-pod(검사 전용) — 검사 Job jt-dev/assert-data-env' }
  [pscustomobject]@{ path = 'kv/dev/dragonfly/acl'; env = 'dev'; user = ''; role = 'acl'; keys = @('users.acl'); use = '키 users.acl · dev 사용자 비밀번호의 SHA-256 으로 렌더(pod 사용자 줄 = B2 꼬리) — ExternalSecret data/dragonfly-dev-acl → Deployment dragonfly-dev' }
  [pscustomobject]@{ path = 'kv/prod/dragonfly/admin'; env = 'prod'; user = 'admin'; role = 'admin'; keys = @('password'); use = '키 password · 사용자 admin — 운영자 전용 · ESO 소비자 없음' }
  [pscustomobject]@{ path = 'kv/prod/dragonfly/identity-admin'; env = 'prod'; user = 'identity-admin'; role = 'pod'; keys = @('password', 'url'); use = '키 password · url · 사용자 identity-admin — vault-prod identity-admin-env(T075)' }
  [pscustomobject]@{ path = 'kv/prod/dragonfly/acl'; env = 'prod'; user = ''; role = 'acl'; keys = @('users.acl'); use = '키 users.acl · prod 사용자 비밀번호의 SHA-256 으로 렌더(pod 사용자 줄 = B2 꼬리 · sample-pod 없음) — ExternalSecret data/dragonfly-prod-acl → Deployment dragonfly-prod' })
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
$SUMMARY = '--- T075 W-6 Dragonfly ACL 렌더(B2) 결과 요약'
# pod 사용자 규칙(UD-9 = B2 · 설계 D20 — 계약 contracts/denylist.md §ACL) · 옛 규칙(T057 — 지금 라이브 kv acl 의 꼴 · W-6 이 STOP 으로 가려야 하는 꼴)
$B2TAIL = ' +@all -@admin -@dangerous -client'
$RULE_IA = '~revoked:* ~identity-admin:* +@all -@admin -@dangerous -client'
$RULE_SP = '%R~revoked:* ~sample-pod:* +@all -@admin -@dangerous -client'
$RULE_IA_T057 = '~revoked:* ~identity-admin:* +@all'
$RULE_SP_T057 = '%R~revoked:* ~sample-pod:* +@all'
# aclfile default 줄(결정 F12 — build-notes 「T057」 VD-4 1차 실측 · 2026-10-22): Dragonfly v1.40.1 은 NOAUTH 관문을 지난 AUTH · HELLO 를 연결의 현재 사용자(default)의 ACL 로 검사한다
#   (main_service.cc :1403–1407 → IsUserAllowedToInvokeCommand · kAuth/kHello = FAST|CONNECTION) — 옛 줄(-@all)이면 아무도 인증 못 한다. +auth +hello = 최소 권한(비인증 연결의 다른 명령은
#   NOAUTH 관문이 먼저 막는다). 옛 줄은 S12 가 회귀로 막는다(로더 모의는 옛 줄도 통과시킨다 — U04 가 그 한계를 고정한다)
$ACL_DEFAULT = 'USER default OFF +auth +hello'
$ACL_DEFAULT_OLD = 'USER default OFF -@all'
function SEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::Ordinal) }
function IEq { param($x, $y) [string]::Equals([string]$x, [string]$y, [StringComparison]::OrdinalIgnoreCase) }
function P { param([string]$path) foreach ($e in $PATHS) { if (SEq $e.path $path) { return $e } }; throw "하네스 결함: 경로 $path 없음" }
function Uniq { param($xs) $h = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal); foreach ($x in @($xs)) { [void]$h.Add([string]$x) }; $h.Count }
# ---- 독립 구현(블록의 $render · url 조립과 코드를 나누지 않는다): hex 는 바이트마다 ToString('x2') · 줄은 문자열 리터럴로 잇는다
function Hex-Lower { param([string]$s) -join @([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) }
function Url-For { param($e, [string]$pw) 'redis://' + $e.user + ':' + $pw + '@dragonfly-' + $e.env + '.data.svc:6379/0' }
function Acl-For { param([string]$ev, $pwMap, [string]$ruleIa = $RULE_IA, [string]$ruleSp = $RULE_SP)
  $t = $ACL_DEFAULT + "`n"
  $t += 'USER admin ON #' + (Hex-Lower ([string]$pwMap['admin'])) + ' ~* &* +@all' + "`n"
  $t += 'USER identity-admin ON #' + (Hex-Lower ([string]$pwMap['identity-admin'])) + ' ' + $ruleIa + "`n"
  if (SEq $ev 'dev') { $t += 'USER sample-pod ON #' + (Hex-Lower ([string]$pwMap['sample-pod'])) + ' ' + $ruleSp + "`n" }
  $t }
# 그 env 의 live 가짜 비밀번호 맵(사용자 → password)
function Live-Map { param([string]$ev) $m = @{}; foreach ($e in $USERS) { if (SEq $e.env $ev) { $m[$e.user] = [string]$LIVE_PW[$e.path] } }; $m }
# 옛 규칙 acl(T057 렌더 — UD-9 전 · 지금 라이브 kv 의 꼴): 그 env 의 live 가짜 비밀번호로 독립 렌더 · pod 사용자 줄 꼬리 = +@all(S37a · S37b — 설계 D20 적용 순서 1–3단계)
function Acl-T057 { param([string]$ev) Acl-For $ev (Live-Map $ev) $RULE_IA_T057 $RULE_SP_T057 }
# 더 옛 꼴(2026-10-22 1차 시드 — F12 전 default 줄 -@all + 옛 규칙): W-6 은 이것도 옛 규칙으로 가린다(S37c)
function Acl-Old { param([string]$ev) (Acl-T057 $ev).Replace(($ACL_DEFAULT + "`n"), ($ACL_DEFAULT_OLD + "`n")) }
# Dragonfly v1.40.1 aclfile 로더 모의(build-notes 「T057」 1차 자료 — acl_family.cc MaterializeFileContents :727–748 · ParseAclSetUser :1082– · user.cc SetPasswordHash :92–104):
#   LF 로 줄을 나누고 빈 줄은 건너뛴다 · 공백(' ')으로 토큰을 가른다(빈 토큰 버림) · 첫 토큰 USER(대소문자 무시) · 토큰 ≥ 4 · 나머지 토큰은 인식되는 종류여야 한다 · default 줄이 있어야 한다.
#   돌려주는 값 '' = 로드됨 · 그 밖 = 로드 실패 사유(실물은 실패하면 파일 전체를 버리고 default nopass 로 기동한다). # 뒤가 짝수 길이 hex 가 아니면 실물은 LOG(ERROR) 뒤
#   그 사용자를 비밀번호 없이 두는데, 이 모의는 더 엄격하게 실패로 본다.
#   +cmd · -cmd(명령 하나 — F12 의 default 줄 +auth +hello): 실물 MaybeParseAclCommand(acl_family.cc :1057–1078)는 대문자로 바꾼 이름을 명령 레지스트리에서 찾고, 없거나 별칭이면
#   Unrecognized parameter(:1173–1176) = 파일 전체 미적재 = 무인증 기동이다. 이 모의가 아는 명령은 렌더가 쓰는 AUTH · HELLO 뿐이다(실물은 등록된 명령 전부를 받는다 — 모의가 더 엄격하다).
#   이 모의는 문법만 본다 — default 줄이 AUTH · HELLO 를 막는지(인증 경로)는 보지 못한다(옛 줄 -@all 도 '' — U04 가 그 한계를 고정하고 S12 가 옛 줄을 막는다)
# T075: B2 꼬리의 -client(명령 하나 — Dragonfly 의 CLIENT 는 하위 명령 토큰이 없다 · UD-9 실측)를 더했다. cmd|sub(-client|kill)은 여전히 모르는 토큰 = 실물 Unrecognized parameter(UD-9 실측) ·
#   Redis 카테고리 이름(@hyperloglog)은 이 모의가 [+-]@이름 꼴로 받아 준다(실물은 거부 — 모의의 한계) → W-6 의 $lint 가 허용 카테고리 셋으로 막는다(U05)
$ACL_KNOWN_CMDS = @('AUTH', 'HELLO', 'CLIENT')
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
      if ($u.Length -gt 1 -and ($u.StartsWith('+', [StringComparison]::Ordinal) -or $u.StartsWith('-', [StringComparison]::Ordinal)) -and ($ACL_KNOWN_CMDS -ccontains $u.Substring(1))) { continue }
      return "Unrecognized parameter(토큰 $($i + 1)번째)" } }
  if (-not (@($users) -ccontains 'default')) { return 'default 줄 없음(로더가 nopass default 를 만든다 — 무인증)' }
  '' }

# ---------------------------------------------------------------- 0) 실물 차단 가드(블록을 한 번이라도 돌리기 전에)
$TrapDir = Join-Path ([IO.Path]::GetTempPath()) ('t075-harness-trap-' + [guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $TrapDir)
# B부: tofu 도 함정에 넣는다(실물 tofu 는 운영자 상태 자격으로 Cloudflare 상태를 읽는다 — 하네스는 절대 부르지 않는다). curl.exe 는 System32 에 있어 PATH 에서 뺄 수 없다 —
#   함수 가림(curl.exe 모의) + 정적 관문(절대 경로 실행 파일 · Start-Process 0)이 막는다
foreach ($n in 'vault', 'kubectl', 'tofu') {
  [IO.File]::WriteAllText((Join-Path $TrapDir "$n.cmd"), "@echo off`r`necho TRAP>`"%~dp0CALLED-$n`"`r`nexit /b 97`r`n", [Text.UTF8Encoding]::new($false)) }
$RealDirs = @(Get-Command vault, kubectl, tofu, vault.exe, kubectl.exe, tofu.exe -CommandType Application -All -ErrorAction SilentlyContinue | ForEach-Object { (Split-Path -Parent $_.Source).TrimEnd('\') })
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
# 수정 라운드 1(KB-1 · KB-8): O-1 · O-5 는 curl · tofu 동작을 바꾸는 환경 변수가 있으면 멈춘다 — 이 PC 에 그런 변수가 있으면 정상 시나리오가 엉뚱하게 멈추므로 하네스 동안 지우고 끝에 되돌린다
#   (값은 출력하지 않는다 — 이름만 저장 목록에 둔다)
$NetEnvNames = @('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'TF_WORKSPACE', 'TF_DATA_DIR')
$global:FakeSrc = @{}
$NetEnvSaved = @{}
foreach ($v in @(Get-ChildItem Env: | Where-Object { $NetEnvNames -contains $_.Name -or $_.Name -like 'TF_LOG*' -or $_.Name -like 'TF_CLI_ARGS*' })) { $NetEnvSaved[$v.Name] = $v.Value; Remove-Item -LiteralPath ('Env:' + $v.Name) }

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
  # ctrl(수정 라운드 1 · KB-7): 서버가 보낸 문자열에 터미널 제어열(ESC [2J · OSC 52 클립보드 쓰기) — 블록은 출력 전에 제어 문자를 지워야 한다
  if (SEq $mode 'ctrl') { $o['type'] = 'ocikms' + [char]27 + '[2J'; $o['version'] = '2.0.4' + [char]27 + ']52;c;QUJD' + [char]7 }
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
  # metaCtrl(수정 라운드 1 · KB-7): 오류 문구에 터미널 제어열(OSC 52) — 블록의 firstErr 가 제어 문자를 지운 뒤 내야 한다
  if (Take-Fault 'metaCtrl' $path) {
    Mock-Stderr @("Error reading kv/metadata/${r}: Error making API request.", 'Code: 403. Errors:', ('* permission denied' + [char]27 + ']52;c;QUJD' + [char]7))
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
  # B부 putRace 결함(T075): 다른 기록자가 판정 뒤 · 이 put 앞에 그 경로를 썼다($global:RaceData[<경로>] — 새 버전) → 이 put 은 아래 CAS 로 거부된다(exit 2 · CAS 문구)
  if (Take-Fault 'putRace' $path) { $cur = Race-Write $path }
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
  # delLost(수정 라운드 2 · KB2-3): 서버는 지웠는데 응답이 유실됐다(종료 2) — 블록은 종료 코드를 믿지 않고 재판정(absent)으로 OK 를 내야 한다
  if ($global:F['delLost'].ContainsKey($path)) {
    [void]$global:Kv.Remove($path); $global:Deleted[$path] = $true
    Mock-Stderr @("Error deleting kv/metadata/${r}: Delete `"$($global:EXPECTED_ADDR)/v1/kv/metadata/$r`": context deadline exceeded (Client.Timeout exceeded while awaiting headers)"); $global:LASTEXITCODE = 2; return }
  if (-not $global:F['delNoop'].ContainsKey($path)) { [void]$global:Kv.Remove($path); $global:Deleted[$path] = $true }
  $global:LASTEXITCODE = 0
  "Success! Data deleted (if it existed) at: kv/metadata/$r" }
# 모의 호출 시점의 환경 변수(수정 라운드 1 · KB-4 · KB-5): 값은 그대로 목록에 두고 시나리오 끝에 바늘로 본다(출력하지 않는다). vault 호출은 VAULT_TOKEN(root 토큰 — 그 호출에 필요하다)을 뺀다 ·
#   kubectl · tofu · curl 호출은 아무것도 빼지 않는다(그 자식 프로세스에 비밀 · 토큰이 env 로 가면 안 된다)
function Snap-Env { param([string]$who)
  $skip = @(); if (SEq $who 'vault') { $skip = @('VAULT_TOKEN') }
  [void]$global:EnvAtCall.Add([pscustomobject]@{ who = $who; text = (Env-Text $skip) }) }
function vault {
  $stdin = @($input)
  $a = @($args | ForEach-Object { [string]$_ })
  $line = $a -join ' '
  [void]$global:ArgvLog.Add($line)
  Snap-Env 'vault'
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
    if ($isPut) { return (Mock-KvPut @($a | Select-Object -Skip 2) $stdin) }
    if (SEq (At $a 1) 'patch') { return (Mock-KvPatch @($a | Select-Object -Skip 2)) } }
  if (SEq (At $a 0) 'read') { return (Mock-VRead @($a | Select-Object -Skip 1)) }
  if ((SEq (At $a 0) 'policy') -and (SEq (At $a 1) 'read')) { return (Mock-PolicyRead @($a | Select-Object -Skip 2)) }
  Add-Violation "허용 목록 밖 vault 호출: $line"
  $global:LASTEXITCODE = 1 }
function vault.exe { Add-Violation ('vault.exe 직접 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
# ---- B부 모의(T075) — 허용 플래그($global:Allow)가 켜진 시나리오에서만 답하고, 그 밖에는 위반으로 기록한다(A부 · T057 동작 그대로)
# 다른 기록자의 쓰기(putRace · patchRace 결함): $global:RaceData[<경로>] 를 새 버전으로 커밋하고 그 버전 번호를 돌려준다
function Race-Write { param([string]$path)
  if (-not $global:Kv.ContainsKey($path)) { $global:Kv[$path] = @{ current = 0; created = $global:NowIso; versions = @{} } }
  $rn = [int]$global:Kv[$path]['current'] + 1
  $global:Kv[$path]['versions'][[string]$rn] = @{ data = $global:RaceData[$path]; deletion_time = ''; destroyed = $false; created_time = $global:NowIso }
  $global:Kv[$path]['current'] = $rn
  Add-Event "race:$path"
  $rn }
# vault kv patch "-cas=<n>" <path> k=v …(W-2 만): 키는 issuer · jwks_url 만 허용 · CAS · 결함 patchFail(거부 · 쓰기 0) · patchLost(커밋 뒤 응답 유실 — exit 2 · CAS 문구) · patchRace(다른 기록자 — CAS 충돌) ·
#   patchTamper(커밋하면서 다른 키 하나를 바꾼다 — 보존 대조가 잡아야 한다)
function Mock-KvPatch { param($rest)
  $p = Split-FlagsPath $rest
  $cas = $null
  foreach ($f in @($p.flags)) { if ($f.StartsWith('-cas=', [StringComparison]::Ordinal)) { $cas = [int]$f.Substring(5) } else { Add-Violation "kv patch 플래그: $f" } }
  [void]$global:PatchCalls.Add([pscustomobject]@{ path = [string]$p.path; cas = $cas; pairs = @($p.trailing) })
  Add-Event "vault:patch:$([string]$p.path)"
  if (-not $global:Allow['patch']) { Add-Violation "kv patch 호출(이 블록은 patch 하지 않는다): $($p.path)"; $global:LASTEXITCODE = 1; return }
  if ($null -eq $p.path -or $null -eq $cas) { Add-Violation 'kv patch 인자 형식(-cas · 경로)'; $global:LASTEXITCODE = 1; return }
  $pairs = [ordered]@{}
  foreach ($t in @($p.trailing)) {
    $i = ([string]$t).IndexOf('=')
    if ($i -lt 1) { Add-Violation "kv patch 인자가 k=v 가 아니다: $t"; $global:LASTEXITCODE = 1; return }
    $k = ([string]$t).Substring(0, $i)
    if (-not (@('issuer', 'jwks_url') -ccontains $k)) { Add-Violation "kv patch 키가 issuer · jwks_url 밖이다: $k" }
    $pairs[$k] = ([string]$t).Substring($i + 1) }
  $path = [string]$p.path
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  $r = KvRest $path
  if ($global:F['patchFail'].ContainsKey($path)) { Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', 'Code: 403. Errors:', '', '* permission denied'); $global:LASTEXITCODE = [int]$global:F['patchFail'][$path]; return }
  if (-not $global:Kv.ContainsKey($path)) { Mock-Stderr @("No value found at kv/data/$r"); $global:LASTEXITCODE = 2; return }
  $cur = [int]$global:Kv[$path]['current']
  if (Take-Fault 'patchRace' $path) { $cur = Race-Write $path }
  if ($cas -ne $cur) { Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version'); $global:LASTEXITCODE = 2; return }
  $old = $global:Kv[$path]['versions'][[string]$cur]['data']
  $data = [ordered]@{}
  foreach ($k in @($old.Keys)) { $data[[string]$k] = $old[$k] }
  foreach ($k in @($pairs.Keys)) { $data[$k] = $pairs[$k] }
  if (Take-Fault 'patchTamper' $path) { $data['client_id'] = 'MOCK-tampered-client-id' }
  $n = $cur + 1
  $global:Kv[$path]['versions'][[string]$n] = @{ data = $data; deletion_time = ''; destroyed = $false; created_time = $global:NowIso }
  $global:Kv[$path]['current'] = $n
  if (Take-Fault 'patchLost' $path) { Mock-Stderr @("Error writing data to kv/data/${r}: Error making API request.", '', 'Code: 400. Errors:', '', '* check-and-set parameter did not match the current version'); $global:LASTEXITCODE = 2; return }
  $global:LASTEXITCODE = 0
  @('====== Secret Path ======', "kv/data/$r", '', '======= Metadata =======', "version            $n") }
# vault read -format=json auth/kubernetes/role/eso-prod(O-4 만) · vault policy read eso-prod(O-4 만) — 값 = $global:Role · $global:PolicyText · 결함 roleFail · policyFail
function Mock-VRead { param($rest)
  $p = Split-FlagsPath $rest
  Add-Event "vault:read:$([string]$p.path)"
  if (-not $global:Allow['read']) { Add-Violation "vault read 호출(이 블록은 read 하지 않는다): $($p.path)"; $global:LASTEXITCODE = 1; return }
  if (-not (Has-Flag $p.flags '-format=json') -or -not (SEq $p.path 'auth/kubernetes/role/eso-prod') -or @($p.trailing).Count -gt 0) { Add-Violation "vault read 인자 형식: $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  if ($global:F['roleFail']) { Mock-Stderr @('Error reading auth/kubernetes/role/eso-prod: Error making API request.', '', 'Code: 500. Errors:', '', '* context deadline exceeded'); $global:LASTEXITCODE = 2; return }
  if ($null -eq $global:Role) { Mock-Stderr @('No value found at auth/kubernetes/role/eso-prod'); $global:LASTEXITCODE = 2; return }
  Json-Lines ([ordered]@{ request_id = 'mock-req'; data = $global:Role }) }
function Mock-PolicyRead { param($rest)
  Add-Event "vault:policy-read:$(@($rest) -join ' ')"
  if (-not $global:Allow['read']) { Add-Violation 'vault policy read 호출(이 블록은 read 하지 않는다)'; $global:LASTEXITCODE = 1; return }
  if (@($rest).Count -ne 1 -or -not (SEq (At $rest 0) 'eso-prod')) { Add-Violation "vault policy read 인자 형식: $(@($rest) -join ' ')"; $global:LASTEXITCODE = 1; return }
  if (Need-Auth) { $global:LASTEXITCODE = 2; return }
  if ($global:F['policyFail']) { Mock-Stderr @('Error reading policy named eso-prod: Error making API request.', '', 'Code: 500. Errors:'); $global:LASTEXITCODE = 2; return }
  $global:LASTEXITCODE = 0
  @($global:PolicyText) }
# kubectl(O-6 사후 · W-6 ACL LOAD 만): --kubeconfig <…joshuatech-admin.yaml> -n data exec -i deploy/dragonfly-<env> -c dragonfly -- redis-cli --user admin --askpass <명령…>
#   stdin = 파이프 객체들 — 실물(네이티브 kubectl)처럼 객체마다 CRLF 를 붙인 바이트로 보고 redis-cli(linenoise 비 TTY)처럼 첫 LF 까지를 비밀번호로 읽는다(CR 은 남는다 — VD-T075-17 실측).
#   그 비밀번호가 live admin 비밀번호와 Ordinal 로 같아야 AUTH 성공 — 아니면 stderr 'Warning: AUTH failed' + stdout NOAUTH(종료 0 — 실측). 명령 = ACL LOAD · ACL DRYRUN <사용자> <명령…>
#   라이브 규칙 모형 $global:DfRules[env] = 'b2' | 't057' — DRYRUN 응답은 실측 문구(OK · This user has no permissions to run the '<명령>' command · ERR User '<u>' not found)
#   결함: kexecFail(exit 1) · aclLoadFail(LOAD 오류 응답) · $global:DfPending[env](ACL LOAD 가 성공하면 그 규칙으로 바뀐다 — 마운트 파일 반영 모형)
function Mock-Kubectl { param($a, $stdin)
  $line = $a -join ' '
  [void]$global:XArgv.Add('kubectl ' + $line)
  $i = [array]::IndexOf([string[]]$a, '--')
  $want = @('--kubeconfig', '', '-n', 'data', 'exec', '-i', '', '-c', 'dragonfly', '--', 'redis-cli', '--user', 'admin', '--askpass')
  $ok = ($a.Count -ge 15 -and $i -eq 9)
  if ($ok) { for ($k = 0; $k -lt $want.Count; $k++) { if ($want[$k].Length -gt 0 -and -not (SEq $a[$k] $want[$k])) { $ok = $false } } }
  if ($ok -and -not ([string]$a[1]).EndsWith('joshuatech-admin.yaml', [StringComparison]::Ordinal)) { $ok = $false }
  $dep = [string](At $a 6)
  if ($ok -and $dep -cnotmatch '\Adeploy/dragonfly-(dev|prod)\z') { $ok = $false }
  if (-not $ok) { Add-Violation "kubectl 인자 꼴(--kubeconfig <관리자> -n data exec -i deploy/dragonfly-<env> -c dragonfly -- redis-cli --user admin --askpass …): $line"; $global:LASTEXITCODE = 1; return }
  $ev = $dep.Substring(17)
  $cmd = @($a | Select-Object -Skip 14)
  $bytes = (@($stdin | ForEach-Object { [string]$_ + "`r`n" }) -join '')
  $lf = $bytes.IndexOf("`n")
  $cand = $bytes; if ($lf -ge 0) { $cand = $bytes.Substring(0, $lf) }
  [void]$global:KubeCalls.Add([pscustomobject]@{ env = $ev; cmd = ($cmd -join ' '); stdinObjects = @($stdin).Count; pwOk = (SEq $cand $global:LiveAdminPw[$ev]) })
  Add-Event "kubectl:exec:${ev}:$($cmd -join ' ')"
  if ($global:F['kexecFail']) { Mock-Stderr @('error: unable to upgrade connection: container not found ("dragonfly")'); $global:LASTEXITCODE = 1; return }
  $global:LASTEXITCODE = 0
  if (-not (SEq $cand $global:LiveAdminPw[$ev])) { Mock-Stderr @('Warning: AUTH failed'); return @('NOAUTH Authentication required.', '') }
  if ((SEq (At $cmd 0) 'ACL') -and (SEq (At $cmd 1) 'LOAD') -and $cmd.Count -eq 2) {
    if ($global:F['aclLoadFail']) { return @('ERR Error loading: /etc/dragonfly/users.acl Unrecognized parameter -CLIENT|KILL') }
    [void]$global:AclLoads.Add($ev)
    if ($global:DfPending.ContainsKey($ev)) { $global:DfRules[$ev] = $global:DfPending[$ev] }
    return @('OK') }
  if ((SEq (At $cmd 0) 'ACL') -and (SEq (At $cmd 1) 'DRYRUN') -and $cmd.Count -ge 4) {
    $u = [string]$cmd[2]; $c = @($cmd | Select-Object -Skip 3); $c0 = ([string]$c[0]).ToUpperInvariant()
    $users = @('admin', 'identity-admin'); if (SEq $ev 'dev') { $users += 'sample-pod' }
    if (-not ($users -ccontains $u)) { return @("ERR User '$u' not found", '') }
    $rule = [string]$global:DfRules[$ev]
    $name = $c0; if ((SEq $c0 'ACL') -and $c.Count -ge 2) { $name = 'ACL ' + ([string]$c[1]).ToUpperInvariant() }
    $deny = $false
    $adminish = @('ACL', 'REPLICAOF', 'SLAVEOF', 'SAVE', 'CONFIG', 'FLUSHALL', 'SHUTDOWN', 'MONITOR', 'DEBUG')
    if (SEq $rule 'b2') { if (($adminish -ccontains $c0) -or (SEq $c0 'CLIENT')) { $deny = $true } }
    if ((SEq $u 'sample-pod') -and (SEq $c0 'SET') -and ([string]$c[1]).StartsWith('revoked:', [StringComparison]::Ordinal)) { $deny = $true }
    if ($deny) {
      # kctrl(수정 라운드 1 · KB-7): 응답 문구에 터미널 제어열 — 블록이 제어 문자를 지운 뒤 내야 한다
      if ($global:F['kctrl']) { return @("This user has no permissions to run the '$name' command" + [char]27 + ']52;c;QUJD' + [char]7) }
      return @("This user has no permissions to run the '$name' command") }
    return @('OK') }
  Add-Violation "kubectl exec 의 redis-cli 명령이 ACL LOAD · ACL DRYRUN 밖이다: $($cmd -join ' ')"
  @('ERR unknown') }
function kubectl {
  $stdin = @($input)
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  Snap-Env 'kubectl'
  if (-not $global:Allow['kubectl']) { Add-Violation ('kubectl 호출(이 블록은 클러스터에 닿지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  Mock-Kubectl $a $stdin }
function kubectl.exe { Add-Violation ('kubectl.exe 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
# tofu(O-1 · O-5 만): version · "-chdir=<저장소>\infra\cloudflare" output -json <이름> — 값 = $global:TofuOut[<이름>](JSON 문자열) · 결함 $global:F['tofuFail'][<이름>] = exit
function tofu {
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  [void]$global:XArgv.Add('tofu ' + ($a -join ' '))
  Snap-Env 'tofu'
  if (-not $global:Allow['tofu']) { Add-Violation ('tofu 호출(이 블록은 tofu 를 쓰지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  $global:LASTEXITCODE = 0
  if ($a.Count -eq 1 -and (SEq $a[0] 'version')) { Add-Event 'tofu:version'; return 'OpenTofu v0.0.0-MOCK' }
  if ($a.Count -eq 4 -and $a[0].StartsWith('-chdir=', [StringComparison]::Ordinal) -and (SEq $a[1] 'output') -and (SEq $a[2] '-json')) {
    [void]$global:TofuCalls.Add([pscustomobject]@{ chdir = $a[0].Substring(7); name = $a[3] })
    Add-Event "tofu:output:$($a[3])"
    if ($global:F['tofuFail'].ContainsKey($a[3])) { Mock-Stderr @('Error: No outputs found', '', 'The state file either has no outputs defined, or all the defined outputs are empty.'); $global:LASTEXITCODE = [int]$global:F['tofuFail'][$a[3]]; return }
    if (-not $global:TofuOut.ContainsKey($a[3])) { Mock-Stderr @("Error: Output `"$($a[3])`" not found"); $global:LASTEXITCODE = 1; return }
    return @(([string]$global:TofuOut[$a[3]]) -split "`n") }
  Add-Violation ('허용 목록 밖 tofu 호출: ' + ($a -join ' ')); $global:LASTEXITCODE = 1 }
function tofu.exe { Add-Violation ('tofu.exe 직접 호출: ' + (@($args) -join ' ')); $global:LASTEXITCODE = 1 }
function curl { Add-Violation 'curl 호출(curl.exe 를 써야 한다 — PowerShell 별칭 · 다른 판 회피)'; $global:LASTEXITCODE = 1 }
# curl.exe(O-5 만): -q --version · -q -sS --max-time 20 [-H '@-'] -w <형식> <url> — 응답 = & $global:HttpFn <요청>(code · xrid · cc · body · cookie). -w 의 \n · %{http_code} · %header{x-request-id} ·
#   %header{cache-control} 만 채운다(다른 %header 이름 · %{header_json} = 위반). 헤더를 통째로 내는 플래그(-i · -D · -v · --trace · -c · -b · -o …) = 위반 — Set-Cookie 는 그 플래그로만 나온다.
#   첫 인자는 반드시 -q(수정 라운드 1 · KB-1 — 실물 curl 은 -q 가 첫 인자일 때만 .curlrc 를 읽지 않는다 · 아니면 위반)
function curl.exe {
  $stdin = @($input)
  $a = @($args | ForEach-Object { $_ } | ForEach-Object { [string]$_ })
  [void]$global:XArgv.Add('curl.exe ' + ($a -join ' '))
  Snap-Env 'curl'
  if (-not $global:Allow['curl']) { Add-Violation ('curl.exe 호출(이 블록은 HTTP 를 쓰지 않는다): ' + ($a -join ' ')); $global:LASTEXITCODE = 1; return }
  if (-not (SEq (At $a 0) '-q')) { Add-Violation ('curl.exe 첫 인자가 -q 가 아니다(.curlrc 를 읽는다): ' + ($a -join ' ')) }
  $global:LASTEXITCODE = 0
  if ($a.Count -eq 2 -and (SEq $a[0] '-q') -and (SEq $a[1] '--version')) { Add-Event 'curl:version'; return @([string]$global:CurlVersion, 'Protocols: http https') }
  $bad = @($a | Where-Object { @('-i', '-I', '--include', '-D', '--dump-header', '-v', '--verbose', '--trace', '--trace-ascii', '-c', '--cookie-jar', '-b', '--cookie', '-o', '--output', '-O', '-k', '--insecure') -ccontains $_ })
  if ($bad.Count -gt 0) { Add-Violation "curl.exe 금지 플래그: $($bad -join ' ')" }
  $iw = [array]::IndexOf([string[]]$a, '-w')
  $fmt = ''; if ($iw -ge 0 -and $iw + 1 -lt $a.Count) { $fmt = $a[$iw + 1] }
  foreach ($m in [regex]::Matches($fmt, '%header\{([^}]*)\}')) { if (-not (@('x-request-id', 'cache-control') -ccontains $m.Groups[1].Value)) { Add-Violation "curl -w 허용 밖 헤더: $($m.Groups[1].Value)" } }
  if ($fmt.Contains('%{header_json}')) { Add-Violation 'curl -w %{header_json}' }
  $url = [string]$a[$a.Count - 1]
  $hasH = ([array]::IndexOf([string[]]$a, '-H') -ge 0)
  if ($hasH -and -not ($a -ccontains '@-')) { Add-Violation 'curl -H 가 @-(stdin) 가 아니다 — 헤더 값이 argv 에 나온다' }
  $hdr = @{}
  foreach ($l in @($stdin | ForEach-Object { [string]$_ })) { $j = $l.IndexOf(':'); if ($j -gt 0) { $hdr[$l.Substring(0, $j).Trim()] = $l.Substring($j + 1).Trim() } }
  $req = [pscustomobject]@{ url = $url; path = ([regex]::Match($url, '\Ahttps://[^/]+(/[^?]*)')).Groups[1].Value; query = ([regex]::Match($url, '\?(.*)\z')).Groups[1].Value; host = ([regex]::Match($url, '\Ahttps://([^/]+)')).Groups[1].Value
    id = [string]$hdr['CF-Access-Client-Id']; secret = [string]$hdr['CF-Access-Client-Secret']; stdinLines = @($stdin).Count }
  [void]$global:CurlCalls.Add($req)
  Add-Event "curl:get:$($req.path)"
  if ($global:F['curlFail']) { Mock-Stderr @('curl: (6) Could not resolve host: ' + $req.host); $global:LASTEXITCODE = 6; return }
  $resp = & $global:HttpFn $req
  $w = $fmt.Replace('\n', "`n").Replace('%{http_code}', [string]$resp.code).Replace('%header{x-request-id}', [string]$resp.xrid).Replace('%header{cache-control}', [string]$resp.cc)
  $text = [string]$resp.body + $w
  @($text -split "`n") }
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
# B부: -LiteralPath 도 받는다 · 관리자 kubeconfig 경로(…joshuatech-admin.yaml)는 실물 파일을 건드리지 않고 $global:AdminKc 로 답한다(하네스는 그 파일을 읽지도 확인하지도 않는다) ·
#   infra\cloudflare\outputs.tf 는 $global:InfraOk 로 답한다(변이 사본 디렉터리에서도 같은 판정 — 경로는 기록해 단언한다)
# 수정 라운드 1(KB-2): powershell.config.json 두 곳(시스템 = $PSHOME · 사용자 = $PROFILE.CurrentUserAllHosts 의 폴더) — 실물 파일을 읽지 않고 $global:CfgText[system|user] 로 답한다($null = 파일 없음)
function Cfg-Scope { param([string]$q) if ($q.StartsWith($PSHOME, [StringComparison]::OrdinalIgnoreCase)) { 'system' } else { 'user' } }
function Test-Path { param([Parameter(Position = 0)]$Path, [string]$LiteralPath = '')
  $q = [string]$Path; if ($LiteralPath.Length -gt 0) { $q = $LiteralPath }
  if ($q.EndsWith('.vault-token', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:vault-token'; return [bool]$global:VaultTokenFile }
  if ($q.EndsWith('powershell.config.json', [StringComparison]::OrdinalIgnoreCase)) { $sc = Cfg-Scope $q; Add-Event "cfg:test:$sc"; [void]$global:FsLog.Add($q); return ($null -ne $global:CfgText[$sc]) }
  if ($q.EndsWith('joshuatech-admin.yaml', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:admin-kubeconfig'; [void]$global:FsLog.Add($q); return [bool]$global:AdminKc }
  if ($q.EndsWith('\infra\cloudflare\outputs.tf', [StringComparison]::OrdinalIgnoreCase)) { Add-Event 'fs:infra-outputs'; [void]$global:FsLog.Add($q); return [bool]$global:InfraOk }
  Microsoft.PowerShell.Management\Test-Path -LiteralPath $q }
function Get-Content { param([Parameter(Position = 0)]$Path, [string]$LiteralPath = '', [switch]$Raw)
  $q = [string]$Path; if ($LiteralPath.Length -gt 0) { $q = $LiteralPath }
  if ($q.EndsWith('powershell.config.json', [StringComparison]::OrdinalIgnoreCase)) { $sc = Cfg-Scope $q; Add-Event "cfg:read:$sc"; if (-not $Raw) { Add-Violation 'Get-Content 에 -Raw 없음(설정 파일)' }; return $global:CfgText[$sc] }
  Add-Violation "Get-Content 다른 경로(블록은 설정 파일 둘만 읽는다): $q"; $null }
# 모듈 로깅 실효 상태 모의: Import-Module(Utility · Security · Management 만 — 이벤트만) · Get-Module(이름마다 LogPipelineExecutionDetails = $global:ModLog[이름] · $global:ModMissing 의 이름은 돌려주지 않는다)
function Import-Module { param([Parameter(Position = 0)][string[]]$Name)
  if (-not (SEq (@($Name) -join ',') 'Microsoft.PowerShell.Utility,Microsoft.PowerShell.Security,Microsoft.PowerShell.Management')) { Add-Violation "Import-Module 인자: $(@($Name) -join ',')" }
  Add-Event 'mod:import' }
function Get-Module { param([Parameter(Position = 0)][string[]]$Name)
  Add-Event 'mod:get'
  foreach ($n in @($Name)) { if ($global:ModLog.ContainsKey($n) -and -not ($global:ModMissing -ccontains $n)) { [pscustomobject]@{ Name = $n; LogPipelineExecutionDetails = [bool]$global:ModLog[$n] } } } }
# 수정 라운드 2(KB2-1 · KB2-2): Get-Command 가림 — 두 가지만 답하고 그 밖은 실물 Get-Command 에 그대로 넘긴다(가드 · 블록의 vault · kubectl · tofu · curl.exe 해석은 실물이 모의 함수로 푼다)
#   ① ForEach-Object(-CommandType Cmdlet 요구): Core 스냅인 실효 값 = $global:CoreLog · 결함 CoreNoSnap(PSSnapIn 없음) · CoreMissing(명령 없음) — -SettingsFile 로 Core 대상 정책을 켠 창의 모형
#      (블록은 -SettingsFile 로 준 파일을 읽을 수 없다 — 실측 r2/probe-core.ps1: Core 대상 정책이면 Core 스냅인 값만 True)
#   ② $global:FakeSrc[이름]: 실행 파일 경로 모의(Application · Source) — INFO 줄의 사용자 홈 ~ 줄임 단언용(호출 자체는 여전히 모의 함수가 받는다)
function Get-Command { [CmdletBinding()] param([Parameter(Position = 0)][string[]]$Name, [string[]]$CommandType, [switch]$All)
  $n0 = [string](@($Name)[0])
  if (@($Name).Count -eq 1 -and (SEq $n0 'ForEach-Object')) {
    Add-Event 'mod:core'
    if (-not (SEq (@($CommandType) -join ',') 'Cmdlet')) { Add-Violation 'Get-Command ForEach-Object 에 -CommandType Cmdlet 없음(같은 이름 함수 · 별칭에 가려질 수 있다)' }
    if ($global:CoreMissing) { return }
    $snap = $null
    if (-not $global:CoreNoSnap) { $snap = [pscustomobject]@{ Name = 'Microsoft.PowerShell.Core'; LogPipelineExecutionDetails = [bool]$global:CoreLog } }
    return [pscustomobject]@{ Name = 'ForEach-Object'; CommandType = 'Cmdlet'; PSSnapIn = $snap; Source = 'Microsoft.PowerShell.Core' } }
  if (@($Name).Count -eq 1 -and $null -ne $global:FakeSrc -and $global:FakeSrc.ContainsKey($n0)) { return [pscustomobject]@{ Name = $n0; CommandType = 'Application'; Source = [string]$global:FakeSrc[$n0] } }
  Microsoft.PowerShell.Core\Get-Command @PSBoundParameters }

# ---------------------------------------------------------------- 가드 확인 · 모의 상태
function Assert-Guard {
  # 실물 Get-Command 로 본다(모의 Get-Command 의 FakeSrc 가 앞 시나리오에서 남아 있어도 가드는 실제 해석을 본다 — 라운드 2 첫 실행의 거짓 가드 실패)
  foreach ($n in 'vault', 'kubectl', 'tofu', 'curl', 'vault.exe', 'kubectl.exe', 'tofu.exe', 'curl.exe', 'Set-PSDebug', 'Read-Host', 'Test-Path', 'Get-ItemProperty', 'Set-Clipboard', 'Get-Content', 'Import-Module', 'Get-Module', 'Get-Command') {
    $c = Microsoft.PowerShell.Core\Get-Command $n -ErrorAction SilentlyContinue
    if ($null -eq $c -or $c.CommandType -ne 'Function') { throw "가드 실패: $n 이 모의 함수로 풀리지 않는다 — 블록을 실행하지 않는다" } }
  foreach ($a in @(Get-Command vault, kubectl, tofu, vault.exe, kubectl.exe, tofu.exe -CommandType Application -All -ErrorAction SilentlyContinue)) {
    if (-not $a.Source.StartsWith($TrapDir, [StringComparison]::OrdinalIgnoreCase)) { throw "가드 실패: 실물 실행 파일이 PATH 에 남아 있다($($a.Source)) — 블록을 실행하지 않는다" } }
  if (-not (SEq $env:KUBECONFIG $FakeKubeconfig) -or (Microsoft.PowerShell.Management\Test-Path -LiteralPath $FakeKubeconfig)) { throw '가드 실패: KUBECONFIG 가 하네스의 없는 경로가 아니다 — 블록을 실행하지 않는다' } }
function Trap-Markers { @(Get-ChildItem -LiteralPath $TrapDir -Filter 'CALLED-*' -ErrorAction SilentlyContinue).Count }
function Reset-Mocks {
  # 세션 설정을 먼저 원래 값으로(S10e 가 WhatIf · 기본 매개변수 값을 바꾼다 — 아래 Remove-Item 이 그 설정에 걸리지 않게 맨 앞)
  $global:WhatIfPreference = $OrigWhatIf
  $global:PSDefaultParameterValues = $OrigPSDPV.Clone()
  $global:Kv = @{}
  $global:F = @{ status = 'ok'; metaFalseAbsent = @{}; metaEmpty = @{}; metaError = @{}; readFail = @{}; readGarbage = @{}; tamper = @{}; putFail = @{}; postMeta = @{}; putInterrupt = @{}; clipFail = $false
    putLost = @{}; delFail = @{}; delNoop = @{}; postDelErr = @{}; delLost = @{}
    patchFail = @{}; patchLost = @{}; patchTamper = @{}; patchRace = @{}; putRace = @{}; roleFail = $false; policyFail = $false; tofuFail = @{}; kexecFail = $false; aclLoadFail = $false; curlFail = $false
    metaCtrl = @{}; kctrl = $false }
  $global:RaceData = @{}
  # 수정 라운드 1(KB-2): 모듈 로깅 실효 상태(기본 = 꺼짐 · 두 모듈 있음) · 설정 파일(기본 = 시스템 파일은 로깅 키 없이 있다 · 사용자 파일 없음)
  $global:ModLog = @{ 'Microsoft.PowerShell.Utility' = $false; 'Microsoft.PowerShell.Security' = $false; 'Microsoft.PowerShell.Management' = $false }
  $global:ModMissing = @()
  # 수정 라운드 2(KB2-1 · KB2-2): Core 스냅인 실효 값 · 결함 · 실행 파일 경로 모의
  $global:CoreLog = $false; $global:CoreNoSnap = $false; $global:CoreMissing = $false
  $global:FakeSrc = @{}
  $global:CfgText = @{ system = '{"Microsoft.PowerShell:ExecutionPolicy":"RemoteSigned","WindowsPowerShellCompatibilityModuleDenyList":["PSScheduledJob"]}'; user = $null }
  $global:AllowDelete = $false
  $global:Deleted = @{}
  $global:ItemCount = 0
  $global:Policy = @{}
  $global:Inputs = [System.Collections.Queue]::new()
  foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls', 'PutBodies', 'Violations', 'ExtraSecrets', 'XArgv', 'PatchCalls', 'KubeCalls', 'CurlCalls', 'TofuCalls', 'FsLog', 'AclLoads', 'EnvAtCall') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
  # B부 모의 상태(A부 시나리오에서는 전부 꺼짐 — 블록이 부르면 위반)
  $global:Allow = @{ patch = $false; read = $false; kubectl = $false; tofu = $false; curl = $false }
  $global:Role = $null
  $global:PolicyText = @()
  $global:TofuOut = @{}
  $global:HttpFn = { param($req) [pscustomobject]@{ code = '000'; xrid = ''; cc = ''; body = ''; cookie = '' } }
  $global:CurlVersion = 'curl 8.22.0 (Windows) libcurl/8.22.0 Schannel'
  $global:DfRules = @{ dev = 'b2'; prod = 'b2' }
  $global:DfPending = @{}
  $global:LiveAdminPw = @{ dev = ''; prod = '' }
  $global:AdminKc = $true
  $global:InfraOk = $true
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
  # B부: T044 sentinel 은 비밀이 아니다(블록 코드에 상수로 있다 · 바늘로 쓰면 'PLACEHOLDER-' 같은 판정 문구가 거짓 양성이 된다)
  if (SEq $s 'PLACEHOLDER-T044-SENTINEL') { return }
  if (@('password', 'secret', 'secret_key', 'client_secret', 'api_token', 'key') -ccontains [string]$k) { $script:NSecrets.Add($s); return }
  # url · acl 은 8자 미만이면 바늘로 쓰지 않는다(숫자형 값 시나리오의 짧은 문자열이 환경 변수 · 경로에 우연히 걸리는 거짓 양성 — 비밀 모양이 아니다)
  if ($s.Length -lt 8) { return }
  if (SEq $k 'url') {
    $script:NFulls.Add($s)
    # 비밀번호 = <스킴>://<사용자>:<여기>@ — redis · postgresql 모두(사용자 이름은 비밀이 아니다 — 조각 바늘에 넣지 않는다)
    $um = [regex]::Match($s, '\A[a-z]+://[^:/@]+:([^@]+)@')
    if ($um.Success -and $um.Groups[1].Value.Length -ge 8) { $script:NSecrets.Add($um.Groups[1].Value) }
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
  # B부: 공개 상수(블록 판정 문구가 이름으로 부르는 접두 — 'PLACEHOLDER-' · 'django-insecure-')에 통째로 들어가는 조각 바늘은 뺀다. 그 조각은 비밀을 드러내지 않는다
  #   (가드 시나리오가 일부러 그 접두로 시작하는 가짜 비밀을 심는다 — 접두 밖 조각은 그대로 바늘이다)
  foreach ($n in @($set)) { foreach ($pub in @('PLACEHOLDER-', 'django-insecure-')) { if ($pub.Contains($n)) { [void]$set.Remove($n) } } }
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
  'RbCode', 'RbWhy', 'RenderSbx', 'RenderWhy', 'LintSbx', 'LintWhy',
  'XArgv', 'PatchCalls', 'KubeCalls', 'CurlCalls', 'TofuCalls', 'FsLog', 'AclLoads', 'Allow', 'Role', 'PolicyText', 'TofuOut', 'HttpFn', 'CurlVersion', 'DfRules', 'DfPending', 'LiveAdminPw', 'AdminKc', 'InfraOk',
  'O5Dep', 'O5Mut', 'DeploySha', 'BGate', 'RaceData', 'ModLog', 'ModMissing', 'CfgText', 'EnvAtCall', 'PasteNew', 'CoreLog', 'CoreNoSnap', 'CoreMissing', 'FakeSrc')
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
# ---- 수정 라운드 1 공통 사후 조건(A부 Run-Case · B부 Run-OCase 둘 다 — 리뷰 KB-2 · KB-4 · KB-5 · KB-7)
#   ① 모듈 로깅 실효 확인(Get-Module · 설정 파일 둘)이 값이 오가는 첫 동작보다 먼저 ② 보안 입력(root 토큰) 바로 다음 동작 = 클립보드 비움
#   ③ 모의 호출 시점 env 에 비밀 0(vault 는 VAULT_TOKEN 만 예외) ④ 화면에 제어 문자 0(LF 밖)
#   ⑤ $Error 정리(리뷰 B KM3 — round 0 생존): 블록 finally 가 이 실행분을 지운다 — 남아도 되는 것은 하네스 catch 가 다시 담은 그 throw 1건뿐
#      (실측 r1/probe-error.ps1: 2>&1 · 2>$null 로 돌린 오류도 $Error 에 들어간다 · throw 는 블록 finally 전에 담기고 정리로 지워진 뒤 바깥 catch 가 한 번 다시 담는다)
function Check-ErrClean { param([bool]$threw, [string]$errMsg)
  $left = @($global:Error | Where-Object { -not ($threw -and ($_ -is [System.Management.Automation.ErrorRecord]) -and (SEq ([string]$_.Exception.Message) $errMsg)) })
  Check '$Error 에 블록이 남긴 기록 0(finally 가 이 실행분을 지운다 — throw 시나리오는 그 throw 1건만 · KM3)' ($left.Count -eq 0) "남은 기록 $($left.Count)" }
function Check-R1 { param([string]$text, $needles)
  $iVal = -1
  foreach ($pfx in 'vault:status', 'vault:token-lookup', 'vault:kv-get:', 'vault:meta-get:', 'tofu:output:', 'curl:get:', 'kubectl:exec:', 'read:secure') { $j = Ev-First $pfx; if ($j -ge 0 -and ($iVal -lt 0 -or $j -lt $iVal)) { $iVal = $j } }
  if ($iVal -ge 0) {
    $iMod = Ev-First 'mod:get'; $iCs = Ev-First 'cfg:test:system'; $iCu = Ev-First 'cfg:test:user'; $iCore = Ev-First 'mod:core'
    Check '모듈 로깅 실효 확인(Utility · Security · Management 의 LogPipelineExecutionDetails · Core 스냅인(라운드 2) · 설정 파일 둘)이 값이 오가는 첫 동작보다 먼저(KB-2 · KB2-1)' ($iMod -ge 0 -and $iMod -lt $iVal -and $iCore -ge 0 -and $iCore -lt $iVal -and $iCs -ge 0 -and $iCs -lt $iVal -and $iCu -ge 0 -and $iCu -lt $iVal) "mod:get $iMod · mod:core $iCore · cfg $iCs/$iCu · 첫 값 동작 $iVal" }
  $badClip = @(); for ($i = 0; $i -lt $global:Events.Count; $i++) { if ((SEq $global:Events[$i] 'read:secure') -and -not ((($i + 1) -lt $global:Events.Count) -and (SEq $global:Events[$i + 1] 'clip:set'))) { $badClip += $i } }
  Check '보안 입력(root 토큰) 바로 다음 동작 = 클립보드 비움(KB-5 — finally 의 비움만으로는 늦다)' ($badClip.Count -eq 0) "어긋난 이벤트 위치 $($badClip -join ',')"
  $envHit = $null
  foreach ($s in $global:EnvAtCall) { $h = First-Needle ([string]$s.text) $needles; if ($null -ne $h) { $envHit = "$($s.who) 호출 시점(바늘 길이 $($h.Length))"; break } }
  Check '모의 호출 시점 env 에 비밀 0(vault 는 VAULT_TOKEN 만 예외 · kubectl · tofu · curl 은 예외 없음 — KB-4 · KB-5)' ($null -eq $envHit) ([string]$envHit)
  Check '화면에 제어 문자 0(LF 밖 — 응답 문자열의 터미널 제어열 · OSC 52 — KB-7)' (-not ($text -cmatch '[\p{Cc}-[\n]]')) }
# ---- 수정 라운드 1 정적 단언(A부 S12 · B부 Run-OStatic 둘 다)
#   KB-5: $env: 대입은 VAULT_ADDR · VAULT_TOKEN 만 · $script: · $global: 대입은 $global:LASTEXITCODE 만(붙여넣기 실행이면 $script: 가 전역이다)
#   KB-2: 모듈 로깅 실효 확인 문장(Import-Module 두 모듈 · Get-Module 두 모듈 · 설정 파일 둘을 텍스트로 -match) — 정확한 꼴
function Static-R1 { param($ast, [string]$text)
  $bad5 = @()
  foreach ($a5 in @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true))) {
    $lv = $a5.Left
    while ($lv -is [System.Management.Automation.Language.ConvertExpressionAst] -or $lv -is [System.Management.Automation.Language.AttributedExpressionAst]) { $lv = $lv.Child }
    while ($lv -is [System.Management.Automation.Language.MemberExpressionAst] -or $lv -is [System.Management.Automation.Language.IndexExpressionAst]) { if ($lv -is [System.Management.Automation.Language.IndexExpressionAst]) { $lv = $lv.Target } else { $lv = $lv.Expression } }
    if ($lv -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
    $vp = $lv.VariablePath
    $up = [string]$vp.UserPath
    if ($vp.IsDriveQualified -and [string]::Equals([string]$vp.DriveName, 'env', [StringComparison]::OrdinalIgnoreCase)) {
      $nm = $up.Substring($up.IndexOf(':') + 1)
      if (-not (@('VAULT_ADDR', 'VAULT_TOKEN') -ccontains $nm)) { $bad5 += "L$($a5.Extent.StartLineNumber) `$env:$nm 대입" } }
    elseif ($vp.IsScript -or $vp.IsGlobal) {
      if (-not ($vp.IsGlobal -and (SEq (Var-Name $lv) 'LASTEXITCODE') -and $a5.Left -is [System.Management.Automation.Language.VariableExpressionAst])) { $bad5 += "L$($a5.Extent.StartLineNumber) $($lv.Extent.Text) 대입" } } }
  Check '$env: 대입은 VAULT_ADDR · VAULT_TOKEN 만 · $script: · $global: 대입은 $global:LASTEXITCODE 만(KB-5 — 자식 프로세스 env · 붙여넣기 전역에 값이 남는 경로 0)' ($bad5.Count -eq 0) ($bad5 -join '; ')
  $im = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Import-Module', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ })
  $gm = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Get-Module', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ })
  $gc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Get-Content', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ })
  $gfe = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Get-Command', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { Cmd-Text $_ } | Where-Object { $_.Contains('ForEach-Object') })
  # 라운드 2(KB2-1): 넷(Core 스냅인 · Utility · Security · Management)의 실효 값 · 설정 파일은 값과 무관한 텍스트 판정(ModuleLogging 대소문자 무관 · 역슬래시-u) · 확인 못 하면 멈춤
  $gmWant = @('Get-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security', 'Get-Module Microsoft.PowerShell.Management')
  Check '모듈 로깅 실효 확인 문장(KB-2 · KB2-1): Import-Module = Utility · Security · Management 1곳 · Get-Module = (Utility · Security) · (Management) 각 1곳 · Get-Command ForEach-Object -CommandType Cmdlet 1곳(Core 스냅인) · Get-Content = 설정 파일 -Raw -LiteralPath 1곳 · 값 무관 텍스트 판정 · 확인 못 하면 멈춤 · $PSHOME · $PROFILE.CurrentUserAllHosts' ($im.Count -eq 1 -and (SEq $im[0] 'Import-Module Microsoft.PowerShell.Utility, Microsoft.PowerShell.Security, Microsoft.PowerShell.Management') -and $gm.Count -eq 2 -and @($gm | Where-Object { $gmWant -ccontains $_ } | Sort-Object -Unique).Count -eq 2 -and $gfe.Count -eq 1 -and (SEq $gfe[0] 'Get-Command ForEach-Object -CommandType Cmdlet') -and $text.Contains('{ $mlCore = $mlFe[0].PSSnapIn }') -and $text.Contains("if (`$null -ne `$mlCore -and `$mlCore.LogPipelineExecutionDetails) { `$mlEff += 'Microsoft.PowerShell.Core' }") -and $text.Contains('$mlEff = @(@($mlMods) + @($mlMgmt) | Where-Object { $_.LogPipelineExecutionDetails }') -and $gc.Count -eq 1 -and (SEq $gc[0] 'Get-Content -Raw -LiteralPath $_') -and $text.Contains("-cmatch '(?i:ModuleLogging)|\x5Cu'") -and -not $text.Contains('"EnableModuleLogging"\s*:') -and $text.Contains('if ($mlMods.Count -ne 2 -or $mlMgmt.Count -ne 1 -or $null -eq $mlCore -or $mlUser.Length -eq 0 -or $mlEff.Count -gt 0 -or $mlCfgOn.Count -gt 0) { throw') -and $text.Contains("(Join-Path `$PSHOME 'powershell.config.json')") -and $text.Contains('$PROFILE.CurrentUserAllHosts')) "Import-Module $($im.Count) · Get-Module $($gm.Count) · Get-Command ForEach-Object $($gfe.Count) · Get-Content $($gc.Count)" }
function Cmd-Text { param($c) (@($c.CommandElements) | ForEach-Object { $_.Extent.Text }) -join ' ' }

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
  Check-R1 $text $needles
  Check-ErrClean $threw $errMsg
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
  'Get-Command', 'ConvertFrom-Json', 'ConvertTo-Json', 'ConvertFrom-SecureString', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug',
  'Import-Module', 'Get-Module', 'Get-Content', 'Split-Path', 'Join-Path')
# 관문 단언 수(파서 오류 0 · 명령 · 정적 형식 · $Host · 파일 리다이렉트 허용 목록) — Static-Gate 는 이 수만큼 있고 전부 PASS 일 때만 통과다(빠진 관문 = FAIL)
$GateCount = 5
$AllowedHelpers = @('eq', 'has', 'sha', 'stop', 'readSecret', 'firstErr', 'parseJson', 'prop', 'render', 'lint', 'state', 'judge', 'write')
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
  Check "1줄 = $ACL_DEFAULT(없으면 로더가 nopass default 를 만든다 · -@all 이면 AUTH · HELLO 까지 NOPERM = 아무도 인증 못 한다 — F12)" ($lines.Count -gt 0 -and (SEq $lines[0] $ACL_DEFAULT))
  $order = @('admin', 'identity-admin'); if (SEq $ev 'dev') { $order += 'sample-pod' }
  $rule = @{ 'admin' = '~* &* +@all'; 'identity-admin' = $RULE_IA; 'sample-pod' = $RULE_SP }
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
    Check 'acl 렌더 = 순수 함수(명령 호출 0 · 바깥 변수 참조 0 — 입력은 param 둘뿐 · 헬퍼 $eq 등도 부르지 않는다)' ($imp.Count -eq 0) ($imp -join '; ')
    # default 줄(결정 F12 · 지시 B12 — 2026-10-22 VD-4 1차 실측: 옛 줄 USER default OFF -@all 은 파일은 적재됐지만 AUTH · HELLO 까지 NOPERM 이라 아무도 인증 못 했다):
    #   $render 안에서 'USER default' 로 시작하는 문자열 상수(대소문자 무시)가 정확히 1개이고 값이 $ACL_DEFAULT 와 Ordinal 일치 · 그 상수에 -@all 0(옛 형식 회귀 금지 — 대소문자 무시)
    $dl = @($global:RenderSbx.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and ([string]$n.Value).StartsWith('USER default', [StringComparison]::OrdinalIgnoreCase) }, $true) | ForEach-Object { [string]$_.Value })
    Check "default 줄 = 정확히 $ACL_DEFAULT(`$render 안 'USER default' 문자열 상수 정확히 1개 · Ordinal — F12: Dragonfly 는 AUTH · HELLO 를 default 의 ACL 로 검사한다)" ($dl.Count -eq 1 -and (SEq $dl[0] $ACL_DEFAULT)) ("상수 $($dl.Count)개: " + ($dl -join ' | '))
    Check 'default 줄에 -@all 0(옛 형식 회귀 금지 — -@all 이면 AUTH · HELLO 까지 NOPERM = 아무도 인증 못 한다 · 2026-10-22 1차 실측)' (@($dl | Where-Object { $_.IndexOf('-@all', [StringComparison]::OrdinalIgnoreCase) -ge 0 }).Count -eq 0) ($dl -join ' | ')
    # T075 · UD-9 = B2(설계 D20): $render 의 규칙 상수(~ 또는 %R~ 로 시작하는 문자열) = 정확히 admin · B2 두 개 · 옛 규칙(꼬리 없는 +@all) 상수 0
    $rc = @($global:RenderSbx.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and (([string]$n.Value).StartsWith('~', [StringComparison]::Ordinal) -or ([string]$n.Value).StartsWith('%R~', [StringComparison]::Ordinal)) }, $true) | ForEach-Object { [string]$_.Value } | Sort-Object)
    $rcWant = @('%R~revoked:* ~sample-pod:* +@all -@admin -@dangerous -client', '~* &* +@all', '~revoked:* ~identity-admin:* +@all -@admin -@dangerous -client' | Sort-Object)
    Check '$render 규칙 상수 = 정확히 admin(~* &* +@all) · identity-admin B2 · sample-pod B2(UD-9 — pod 사용자 줄 끝 = +@all -@admin -@dangerous -client)' ((SEq ($rc -join ' | ') ($rcWant -join ' | '))) ($rc -join ' | ')
    Check '$render 에 옛 규칙 상수 0(꼬리 없는 ~revoked:* ~identity-admin:* +@all · %R~revoked:* ~sample-pod:* +@all — T057 판)' (@($rc | Where-Object { (SEq $_ $RULE_IA_T057) -or (SEq $_ $RULE_SP_T057) }).Count -eq 0) }
  # T075 W-6 판정(설계 D20): $lint 대입문 정확히 1개 · 순수 함수 · $write 안에서 put 보다 먼저 & $lint · $judge 안에서도 & $lint(옛 규칙 acl 분류)
  $global:LintSbx = $null; $global:LintWhy = ''
  $las = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) 'lint') }, $true))
  if ($las.Count -eq 1 -and $las[0].Right -is [System.Management.Automation.Language.CommandExpressionAst] -and $las[0].Right.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { $global:LintSbx = $las[0].Right.Expression } else { $global:LintWhy = "`$lint 대입문 $($las.Count)개(기대 1 · 오른쪽 = 스크립트블록 리터럴)" }
  Check '$lint 대입문 정확히 1개 · 오른쪽 = 스크립트블록 리터럴(렌더 줄 대조 순수 함수 — 설계 D20)' ($null -ne $global:LintSbx) ([string]$global:LintWhy)
  if ($null -ne $global:LintSbx) {
    $limp = Render-Impurities $global:LintSbx
    Check '$lint = 순수 함수(명령 호출 0 · 바깥 변수 참조 0 — 입력은 param 둘뿐)' ($limp.Count -eq 0) ($limp -join '; ')
    $lt = $global:LintSbx.Extent.Text
    Check '$lint 가 B2 꼬리 · 금지 꼴 3종(세로 막대 · reset · 허용 밖 카테고리)을 본다' ($lt.Contains("' +@all -@admin -@dangerous -client'") -and $lt.Contains(".Contains('|')") -and $lt.Contains("StartsWith('reset'") -and $lt.Contains("@('+@all', '-@admin', '-@dangerous')")) }
  $wsb = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) 'write') }, $true))
  $jsb = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) 'judge') }, $true))
  $lintBeforePut = $false; $lintInJudge = $false
  if ($wsb.Count -eq 1) {
    $lc = @($wsb[0].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and $n.CommandElements[0] -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.CommandElements[0]) 'lint') }, $true))
    $pc = @($wsb[0].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) -and $n.Extent.Text.Contains(' put ') }, $true))
    $lintBeforePut = ($lc.Count -ge 1 -and $pc.Count -eq 1 -and $lc[0].Extent.StartOffset -lt $pc[0].Extent.StartOffset) }
  if ($jsb.Count -eq 1) { $lintInJudge = @($jsb[0].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.InvocationOperator -eq [System.Management.Automation.Language.TokenKind]::Ampersand -and $n.CommandElements[0] -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.CommandElements[0]) 'lint') }, $true)).Count -ge 1 }
  Check '$write 안에서 & $lint 가 vault kv put 보다 먼저다(렌더한 acl 대조 실패 = 쓰기 전 STOP — 설계 D20)' $lintBeforePut
  Check '$judge 안에서 & $lint 로 live acl 의 옛 규칙을 가린다(설계 D20 · CD-5)' $lintInJudge
  Check "블록 전체(주석 포함)에 옛 default 줄 $ACL_DEFAULT_OLD 0(머리 주석의 형식 설명까지 F12 로 맞춘다 — 옛 형식 회귀 금지)" (-not $text.Contains($ACL_DEFAULT_OLD))
  Check '블록 전체에 백틱 r 0(CR 을 만드는 표기 없음)' (-not $text.Contains('`r'))
  # 비밀처럼 보이는 상수 0(가짜 값은 하네스에만)
  Check 'MOCK 문자열 0(가짜 값은 하네스 파일에만)' (-not $text.Contains('MOCK'))
  $ent = Bad-Secrets $text
  Check '비밀처럼 보이는 상수 0(대·소문자·숫자 섞인 32자+ 연속)' ($ent.Count -eq 0) ($ent -join ', ')
  Check 'Vault 토큰 모양 상수 0(hvs.<영숫자>)' (-not ($text -cmatch 'hvs\.[A-Za-z0-9]'))
  Check 'Start-Transcript 0' (-not $text.Contains('Start-Transcript'))
  # 수정 라운드 1: $env: · $script: · $global: 대입(KB-5) · 모듈 로깅 실효 확인 문장(KB-2)
  Static-R1 $ast $text }

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
  Write-Host "=== T075 모의 하네스 — A부 블록: $BlockPath · B부 디렉터리: $BlockDir · 부: $(if ($RunA) { 'A' })$(if ($RunB) { 'B' }) ==="
  # 하네스 자체 전제(어긋나면 하네스 결함 → 예외 — 시나리오가 엉뚱한 이유로 FAIL 하지 않게): live 가짜 값 5개 = base64url 43자 · 서로 다르다 · '_' 가 든 값이 있다(B3 문자 집합
  #   고정 — T056 리뷰 r1 H2) · 독립 hex 도우미(Hex-Lower)가 SHA-256 표준 벡터("abc")와 맞는다 · 독립 렌더(Acl-For)가 로더 모의를 통과한다
  foreach ($e in $USERS) { if (-not (([string]$LIVE_PW[$e.path]) -cmatch $RE_PW)) { throw "하네스 결함: LIVE_PW[$($e.path)] 가 base64url 43자가 아니다" } }
  if ((Uniq @($USERS | ForEach-Object { $LIVE_PW[$_.path] })) -ne 5) { throw '하네스 결함: LIVE_PW 5개가 서로 다르지 않다' }
  if (@($USERS | Where-Object { ([string]$LIVE_PW[$_.path]).Contains('_') }).Count -eq 0) { throw "하네스 결함: LIVE_PW 에 '_' 가 든 값이 없다('_' 수용 고정 — T056 리뷰 r1 H2)" }
  if (-not (SEq (Hex-Lower 'abc') 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad')) { throw '하네스 결함: Hex-Lower 가 SHA-256 표준 벡터(abc)와 다르다' }
  foreach ($ev in 'dev', 'prod') { $w = Test-AclLoader (Acl-For $ev (Live-Map $ev)); if ($w) { throw "하네스 결함: Acl-For($ev) 가 로더 모의를 통과하지 못한다: $w" } }
  # 두 부가 함께 쓰는 이름(경로 행 · 기대 줄 조립)
  $ROOT = $global:FAKE_ROOT
  $OK2 = @($global:FAKE_ROOT, 'seed')
  $OKLINE = { param($e) "OK   $($e.path) v1 — 생성 · 되읽기 해시 일치($(@($e.keys) -join '·'))" }
  $SKIPLINE = { param($e) "SKIP $($e.path) — live-ok" }
  $PLANLINE = { param($e) "PLAN $($e.path) — absent → 생성 예정" }
  $DA = P 'kv/dev/dragonfly/admin'; $DI = P 'kv/dev/dragonfly/identity-admin'; $DS = P 'kv/dev/dragonfly/sample-pod'; $DACL = P 'kv/dev/dragonfly/acl'
  $PA = P 'kv/prod/dragonfly/admin'; $PI = P 'kv/prod/dragonfly/identity-admin'; $PACL = P 'kv/prod/dragonfly/acl'
  $pwA = [string]$LIVE_PW[$DA.path]; $pwI = [string]$LIVE_PW[$DI.path]; $pwS = [string]$LIVE_PW[$DS.path]; $pwPA = [string]$LIVE_PW[$PA.path]; $pwPI = [string]$LIVE_PW[$PI.path]
  # ===== A부(W-6 · T057 런북 두 블록) — -Only B 면 건너뛴다
  if ($RunA) {
  # ---- S12: 구조(정적 — 블록을 실행하지 않는다)를 맨 먼저 돌린다. 관문(파서 오류 0 · 명령 · 정적 형식 · $Host · 리다이렉트 허용 목록)이 하나라도
  #      FAIL 이면 런타임 시나리오를 하나도 돌리지 않는다 — 함수 가림 · PATH 함정은 절대 경로 실행 파일 · 프로세스 직접 기동을 막지 못한다(T054 리뷰 O8)
  Run-Static
  Finish-Case 'S12' '구조: & { 로 시작하는 한 문 · 빈 줄 0 · 끝 } + LF 1 · BOM/CR/TAB 0 · Start-Transcript 0 · 파서 오류 0 · 명령/형식/$Host/리다이렉트 허용 목록(관문) · 첫 문장 Set-PSDebug -Off · 세션 설정 고정 3문장 · finally 출력 규칙 + 첫 두 문장 = env 제거 · Read-Host 바로 앞 입력 버퍼 비움(AST) · vault 호출 모양 · MOCK/비밀 상수 0 + (B8) acl 렌더 정적 규칙: $render 대입문 1개 · 순수 함수(명령 0 · 바깥 변수 0) · CR(백틱 r · [char]13) · NewLine 0 · -join 백틱 n · ToLowerInvariant · 블록 전체 백틱 r 0 + (B12 · F12) default 줄 정확히 USER default OFF +auth +hello · default 줄에 -@all 0 · 블록 전체(주석 포함) 옛 줄 0' ''
  $GateMsg = Static-Gate
  if ($GateMsg) {
    Write-Host "관문 FAIL(S12): $GateMsg — 런타임 시나리오를 실행하지 않는다(블록 실행 0회)" -ForegroundColor Red
    throw 'S12 관문 FAIL' }
  Assert-Guard
  Write-Host ("가드: S12 관문 PASS(블록 실행 전) · vault·kubectl·tofu(.exe 포함) · curl.exe · Set-PSDebug = 모의 함수 · 실물 디렉터리 {0}개를 PATH 에서 뺌 · 함정 디렉터리 맨 앞(표식 0 단언) · KUBECONFIG = 없는 경로" -f $RealDirs.Count)

  # ---- U01–U04(⑨ · 결정 B2): acl 렌더 순수 함수 단위 시험 — 블록 파일의 $render 대입문을 AST 로 떼어 내(S12 가 찾은 것) 고정 입력(모의 비밀번호)을 넣고
  #      독립 계산(Acl-For — 바이트마다 x2 hex · 문자열 리터럴로 줄을 잇는다)과 바이트 단위로 대조한다. 블록 전체는 실행하지 않는다
  Run-Unit 'U01' '(⑨) 렌더 — dev: 모의 비밀번호 3개 → 독립 계산 기대 바이트열과 Ordinal 일치 · 4줄 · 줄 순서(default · admin · identity-admin · sample-pod) · USER default OFF +auth +hello(F12) · # 뒤 SHA-256 소문자 hex 64자 · 규칙 문자열(계약 §ACL 표) · 끝 LF 정확히 1 · CR/TAB/BOM/빈 줄/앞뒤·연속 공백 0 · ASCII · 토큰 ≥ 4 · 로더 모의 통과 · 평문 비밀번호 0' {
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
  Run-Unit 'U04' '(⑨) 로더 모의 자체 시험 — Dragonfly v1.40.1 MaterializeFileContents · 토큰 종류 규칙이 렌더 결과(+auth +hello 포함)는 통과시키고, 로드 실패를 만드는 바이트(CR · BOM · 탭 · 3토큰 줄 · 주석 줄 · default 없음 · 홀수 hex · 모르는 명령 토큰)는 잡는다 · 옛 default 줄(-@all)은 통과시킨다(문법만 본다 — 인증 경로는 S12 가 막는다 · F12)' {
    param($r)
    $good = [string](& $r 'dev' (Live-Map 'dev'))
    Check '렌더 결과 → 로더 모의 통과' ([string]::IsNullOrEmpty((Test-AclLoader $good))) (Test-AclLoader $good)
    $bad = [ordered]@{
      'CRLF(줄 끝 CR — +@all 뒤에 CR 이 붙는다)' = $good.Replace("`n", "`r`n")
      '마지막 줄에만 CR 1바이트' = ($good.Substring(0, $good.Length - 1) + "`r`n")
      'BOM(U+FEFF) 앞머리' = ([string][char]0xFEFF + $good)
      '탭으로 토큰 구분(한 곳)' = $good.Replace(' ~* &*', ([string][char]9 + '~* &*'))
      '3토큰 줄(USER default OFF)' = $good.Replace($ACL_DEFAULT, 'USER default OFF')
      '주석 줄(# …)' = ('# T057' + "`n" + $good)
      'default 줄 없음' = $good.Replace(($ACL_DEFAULT + "`n"), '')
      '홀수 길이 hex(# 뒤 63자)' = [regex]::Replace($good, '#([0-9a-f]{63})[0-9a-f]', '#$1', 'None', [TimeSpan]::FromSeconds(5))
      '모르는 명령 토큰(default 줄 +auth 오타 → +auht — 실물: 레지스트리에 없으면 Unrecognized parameter = 파일 전체 미적재 = 무인증 기동)' = $good.Replace('+auth +hello', '+auht +hello') }
    foreach ($k in $bad.Keys) { Check "로더 모의가 잡는다: $k" (-not [string]::IsNullOrEmpty((Test-AclLoader ([string]$bad[$k])))) }
    Check '하네스 자체: 렌더 결과에 새 default 줄이 있다(위 변형이 실제로 그 줄을 바꿨다)' ($good.StartsWith($ACL_DEFAULT + "`n", [StringComparison]::Ordinal))
    $old = $good.Replace($ACL_DEFAULT, $ACL_DEFAULT_OLD)
    Check '로더 모의의 한계 고정: 옛 default 줄(-@all)도 통과시킨다 — 파일 문법만 본다 · 인증 경로(AUTH · HELLO 가 default ACL 로 검사됨)는 보지 못한다 → 옛 줄은 S12 가 정적으로 막는다(F12 · 2026-10-22 1차 실측 사고는 이 모의를 통과했다)' ((-not (SEq $old $good)) -and [string]::IsNullOrEmpty((Test-AclLoader $old))) (Test-AclLoader $old)
    Check '로더 모의가 잡는다: cmd|sub 토큰(-client|kill — UD-9 실측: 실물 Unrecognized parameter = 기동 무인증)' (-not [string]::IsNullOrEmpty((Test-AclLoader $good.Replace(' -client', ' -client|kill')))) }

  # ---- U05(T075 · 설계 D20): $lint(렌더 줄 대조) 단위 시험 — 블록 파일의 $lint · $render 대입문을 AST 로 떼어 내 고정 입력으로 돌린다(블록 전체는 실행하지 않는다).
  #      렌더 결과 · 독립 계산은 통과 · 옛 규칙(T057 · F12 전)은 'B2 꼬리 없음' · 바이트 · 금지 꼴 3종 · 줄 수 · 토큰 어긋남은 각 분류로 잡는다 · 사유 문구에 해시 · 비밀번호 0
  Assert-Guard
  $global:CaseChecks = [System.Collections.ArrayList]::new()
  if ($null -eq $global:LintSbx -or $null -eq $global:RenderSbx) { Check '$lint · $render 스크립트블록 추출(S12)' $false ([string]$global:LintWhy) }
  else {
    try {
      $lintSb = $global:LintSbx.ScriptBlock.GetScriptBlock()
      $rndSb = $global:RenderSbx.ScriptBlock.GetScriptBlock()
      $gd = [string](& $rndSb 'dev' (Live-Map 'dev')); $gp = [string](& $rndSb 'prod' (Live-Map 'prod'))
      Check 'lint(블록 렌더 dev) = 통과(빈 문자열)' (SEq ([string](& $lintSb 'dev' $gd)) '') ([string](& $lintSb 'dev' $gd))
      Check 'lint(블록 렌더 prod) = 통과' (SEq ([string](& $lintSb 'prod' $gp)) '') ([string](& $lintSb 'prod' $gp))
      Check 'lint(독립 계산 Acl-For dev · prod) = 통과' ((SEq ([string](& $lintSb 'dev' (Acl-For 'dev' (Live-Map 'dev')))) '') -and (SEq ([string](& $lintSb 'prod' (Acl-For 'prod' (Live-Map 'prod')))) ''))
      $up = [regex]::Replace($gd, '#[0-9a-f]{64}', { param($m) $m.Value.ToUpperInvariant() })
      $cases = @(
        @('옛 규칙 dev(T057 렌더 — pod 사용자 줄 꼬리 +@all)', 'dev', (Acl-T057 'dev'), 'B2 꼬리 없음'),
        @('옛 규칙 prod(T057 렌더)', 'prod', (Acl-T057 'prod'), 'B2 꼬리 없음'),
        @('F12 전 옛 꼴(default -@all + 옛 규칙)', 'dev', (Acl-Old 'dev'), 'B2 꼬리 없음'),
        @('sample-pod 줄만 옛 꼬리', 'dev', $gd.Replace($RULE_SP, $RULE_SP_T057), 'B2 꼬리 없음(sample-pod'),
        @('CRLF', 'dev', $gd.Replace("`n", "`r`n"), '바이트: ASCII'),
        @('BOM 앞머리', 'dev', ([string][char]0xFEFF + $gd), '바이트: ASCII'),
        @('탭', 'dev', $gd.Replace(' ~* &*', ([string][char]9 + '~* &*')), '바이트: ASCII'),
        @('끝 LF 2개', 'dev', ($gd + "`n"), '바이트: 끝 LF'),
        @('끝 LF 없음', 'dev', $gd.TrimEnd("`n"), '바이트: 끝 LF'),
        @('cmd|sub 토큰(-client|kill 을 꼬리 앞에 끼움 — 기동 무인증 꼴)', 'dev', $gd.Replace($B2TAIL, (' -client|kill' + $B2TAIL)), '금지 꼴: 3줄에 세로 막대'),
        @('reset 토큰', 'dev', $gd.Replace('~identity-admin:* +@all', '~identity-admin:* reset +@all'), '금지 꼴: 3줄에 reset'),
        @('Redis 카테고리 이름(+@hyperloglog)', 'dev', $gd.Replace('~sample-pod:* +@all', '~sample-pod:* +@hyperloglog +@all'), '금지 꼴: 4줄에 허용 밖 카테고리'),
        @('허용 밖 키 패턴(~other:*)', 'dev', $gd.Replace('~identity-admin:* +@all', '~identity-admin:* ~other:* +@all'), '3줄 토큰이 허용 꼴과 다르다'),
        @('대문자 hex', 'dev', $up, '2줄 토큰이 허용 꼴과 다르다'),
        @('admin 줄 규칙이 다르다(-@admin 덧붙임)', 'dev', $gd.Replace(' ~* &* +@all', ' ~* &* +@all -@admin'), '2줄 토큰이 허용 꼴과 다르다'),
        @('default 줄이 다르다(+hello 없음)', 'dev', $gd.Replace($ACL_DEFAULT, 'USER default OFF +auth'), '1줄 토큰이 허용 꼴과 다르다'),
        @('prod 에 sample-pod 줄(dev 렌더를 prod 로)', 'prod', $gd, '줄 수 4(기대 3'),
        @('dev 에 sample-pod 줄 없음(prod 렌더를 dev 로)', 'dev', $gp, '줄 수 3(기대 4'),
        @('env staging', 'staging', $gd, 'env 가 dev · prod 가 아니다'))
      foreach ($c in $cases) {
        $got = [string](& $lintSb $c[1] $c[2])
        Check "lint 가 잡는다: $($c[0]) → '$($c[3])…'" ($got.StartsWith($c[3], [StringComparison]::Ordinal)) $got
        $leak = ($got -cmatch '#[0-9a-fA-F]{8,}') -or @($LIVE_PW.Values | Where-Object { $got.Contains($_) -or $got.Contains($_.Substring(0, 8)) }).Count -gt 0
        Check "lint 사유 문구에 해시 · 비밀번호 0: $($c[0])" (-not $leak) }
      $gotNum = [string](& $lintSb 'dev' 42)
      Check "lint 가 잡는다: 문자열 아님(숫자) → '바이트: 문자열이 아니다'" ($gotNum.StartsWith('바이트: 문자열이 아니다', [StringComparison]::Ordinal)) $gotNum }
    catch { Check 'U05 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
  Finish-Case 'U05' '(T075 · D20) $lint 단위 — 블록 렌더 · 독립 계산 통과 / 옛 규칙(T057 · F12 전 · sample-pod 만) = B2 꼬리 없음 / CRLF · BOM · 탭 · 끝 LF = 바이트 / cmd|sub · reset · 허용 밖 카테고리 = 금지 꼴 / 키 패턴 · 대문자 hex · admin 줄 · default 줄 = 토큰 어긋남 / 줄 수 · env · 문자열 아님 · 사유에 해시 · 비밀번호 0' ''

  # ---- S01 · S02: 정상 첫 시드(⑦) + 노출 검사
  Run-Case 'S01' '(⑦) 7경로 absent → 7개 생성(v1 · 키 집합 1/2/1 · password base64url 43자 · url 모양 · acl = 그 env 사용자 비밀번호로 독립 계산한 렌더 · 로더 모의 통과) · 쓰기 순서 env 마다 사용자 → acl · dev → prod · 사용자 비밀번호 5개 서로 다름 · 쓸 경로 목록 줄 · vault 호출 31회' -Inputs $OK2 `
    -Want (@($PATHS | ForEach-Object { & $OKLINE $_ }) + @($PATHS | ForEach-Object { & $PLANLINE $_ }) + @('OK   Vault 도달 · 초기화됨 · unsealed', 'OK   토큰 정책에 root 포함', '판정 결과: 생성 예정 7 · 건너뜀(live-ok) 0 · 중단 0', '쓸 경로 7개(이 순서로 쓴다)', '이 실행이 kv 에 새로 쓴 경로: 7건(생성·검증 완료 7 · 응답 유실 뒤 재판정으로 검증 완료 0 · 기록 후 검증 실패 0) · 결과 미확인 0 · 건너뜀 0 · 중단 0 · 미실행 0', '판정: kv 7경로 준비 완료(생성 또는 live-ok · acl = B2 렌더) — 이 출력을 컨트롤러에게 붙인다 · 다음 = 런북 bootstrap.md §4 T075 적용 순서 4단계(ESO 갱신 확인)')) `
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
      Check 'INFO 줄에 vault CLI 버전 · 명령 종류 · 경로(모의 = Function · 경로 없음) · LF 값 왕복 근거(T057 시드)' ($global:LastText.Contains('INFO vault CLI: Vault v0.0.0-MOCK (harness) · Function (경로 없음) — ') -and $global:LastText.Contains('줄바꿈(LF)이 든 값(users.acl)의 왕복은 T057 블록(2026-10-22 시드 · 「ACL 파일 갱신」)의 되읽기 해시 일치로'))
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
      Check '검출기 자체 시험: acl 규칙 문자열(비밀 아님)은 잡지 않는다' ($null -eq (First-Needle ($ACL_DEFAULT + ' ~revoked:* ~identity-admin:* +@all %R~revoked:* ~sample-pod:* +@all') $nd))
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

  # ---- S37a · S37c(T075 · 설계 D20 W-6 판정 — 적용 순서 1단계 상태): 지금 라이브 kv(사용자 5 live-ok · acl 2 = T057 옛 규칙 렌더)에서 W-6 을 그대로 돌리면 acl 2경로가
  #      「옛 규칙 acl — B2 꼬리 없음」 STOP(사유 = 적용 순서 2단계를 먼저) — 블록은 옛 acl 을 덮어쓰지 않는다(쓰기 0). 연쇄(② 삭제 블록 → 재실행)는 S37b(런북 블록 추출 뒤 — GB 묶음 끝)
  $OLDWHY = '옛 규칙 acl — pod 사용자 줄에 B2 꼬리(+@all -@admin -@dangerous -client)가 없다(UD-9 전 렌더 · 내용 미출력). 적용 순서 2단계를 먼저 한다'
  foreach ($c in @(@('S37a', '지금 라이브 상태(T057 렌더 · default 줄 F12 정정판 · pod 사용자 꼬리 +@all)', 'T057'), @('S37c', '더 옛 상태(F12 전 default 줄 -@all · 옛 규칙)', 'Old'))) {
    $script:s37k = $c[2]
    Run-Case $c[0] "(T075 · D20 W-6 판정) $($c[1]) → W-6 = 사용자 5 SKIP · acl 2경로 옛 규칙 acl STOP(B2 꼬리 없음 · 2단계 먼저) · 쓰기 0 · 덮어쓰기 0" `
      -Setup { foreach ($u in $USERS) { Seed-LiveOk $u }; foreach ($a in @($DACL, $PACL)) { $t = if ($script:s37k -ceq 'T057') { Acl-T057 $a.env } else { Acl-Old $a.env }; Seed-Path $a.path ([ordered]@{ 'users.acl' = $t }) } } -Inputs $OK2 -Expect '판정 단계에서 중단' `
      -Want (@($USERS | ForEach-Object { & $SKIPLINE $_ }) + @("STOP $($DACL.path) — live-mismatch: $OLDWHY", "STOP $($PACL.path) — live-mismatch: $OLDWHY", '런북 bootstrap.md §4 T057 「정리 판단」 ② 삭제 블록으로 이 acl 경로만 지운 뒤 재실행(설계 D20)', '판정 결과: 생성 예정 0 · 건너뜀(live-ok) 5 · 중단 2', '이 실행이 kv 에 새로 쓴 경로: 0건', '판정: 미완')) `
      -NotWant @("SKIP $($DACL.path)", "SKIP $($PACL.path)", 'INFO 쓸 경로 없음', $ACLWHY) -Post {
        $first = if ($script:s37k -ceq 'T057') { $ACL_DEFAULT } else { $ACL_DEFAULT_OLD }
        Check '하네스 자체: 심은 acl 2경로 = 옛 규칙(pod 사용자 줄 꼬리 +@all) · 첫 줄 = 그 상태의 default 줄' (@(@($DACL, $PACL) | Where-Object { $t = [string](KvData $_.path)['users.acl']; $t.StartsWith($first + "`n", [StringComparison]::Ordinal) -and $t.Contains($RULE_IA_T057 + "`n") -and -not $t.Contains($B2TAIL) }).Count -eq 2)
        Check 'put 0(쓰기 0)' ($global:PutCalls.Count -eq 0)
        Check '입력 1(토큰 — 쓰기 확인 정지점까지 가지 않았다)' ($global:ReadLog.Count -eq 1)
        foreach ($a in @($DACL, $PACL)) { $t = if ($script:s37k -ceq 'T057') { Acl-T057 $a.env } else { Acl-Old $a.env }; Check-Unchanged $a ([ordered]@{ 'users.acl' = $t }) }
        foreach ($u in $USERS) { Check-Unchanged $u (Live-Data $u) }
        Check 'vault 호출 17회(판정용 읽기만 — 3 + metadata get 7 + kv get 7)' ($global:ArgvLog.Count -eq 17) "vault 호출 $($global:ArgvLog.Count)" } }
  # ---- S38(T075 · 설계 D20 「렌더한 pod 사용자 줄마다 B2 꼬리를 단언 — 하나라도 없으면 쓰기 전 FAIL」): 렌더 규칙 상수만 옛 규칙으로 바꾼 변이 사본(하네스가 함정 디렉터리에 만든다 —
  #      S12 를 거치지 않는다)을 7경로 absent 에서 돌린다 → dev 사용자 3 생성 뒤 dev acl 은 $lint 가 put 전에 STOP(B2 꼬리 없음) · acl put 0 · prod 미실행
  $S38Path = Join-Path $TrapDir 'w6-mutant-no-b2-tail.ps1'
  [IO.File]::WriteAllText($S38Path, ([IO.File]::ReadAllText($BlockPath)).Replace("'identity-admin' = '$RULE_IA'", "'identity-admin' = '$RULE_IA_T057'"), [Text.UTF8Encoding]::new($false))
  $script:S38Mutated = -not (SEq ([IO.File]::ReadAllText($S38Path)) ([IO.File]::ReadAllText($BlockPath)))
  $keepBlock = $BlockPath
  $BlockPath = $S38Path
  Run-Case 'S38' '(T075 · D20) 변이 사본(identity-admin 규칙 = 옛 +@all) · 7경로 absent → dev 사용자 3 생성 뒤 dev acl 렌더 대조 실패 STOP(B2 꼬리 없음 · put 전) · acl put 0 · prod 미실행' `
    -Inputs $OK2 -Expect '렌더 대조 실패' `
    -Want @((& $OKLINE $DA), (& $OKLINE $DI), (& $OKLINE $DS), "STOP $($DACL.path) — 렌더한 acl 이 허용 꼴이 아니다(B2 꼬리 없음(identity-admin 줄", 'put 전 중단(쓰기 0)', '중단(렌더 대조 실패 — B2 꼬리 없음', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '판정: 미완') `
    -NotWant @("OK   $($DACL.path)") -Post {
      Check '하네스 자체: 변이 사본이 원본과 다르다(규칙 상수 치환이 일어났다)' $script:S38Mutated
      foreach ($e in @($DA, $DI, $DS)) { Check-Created $e }
      foreach ($e in @($DACL, $PA, $PI, $PACL)) { Check-Absent $e }
      Check 'put 3회(dev 사용자만 — acl put 0)' ($global:PutCalls.Count -eq 3 -and @($global:PutCalls | Where-Object { SEq $_.path $DACL.path }).Count -eq 0) }
  $BlockPath = $keepBlock

  # ---- S04j · S04k(⑧ · 결정 B5 — T056 C1 확장): 사용자 비밀번호 5개는 전부 서로 달라야 한다 — 같은 값을 가진 경로를 모두 STOP(판정 단계 · 쓰기 0 · 값 · 해시 미출력)
  $PAIRWHY = '사용자 비밀번호 5개는 전부 달라야 한다(dev 값은 jt-dev assert-data-env 로도 복사되고 admin 은 전권이다) · 값 미출력 · 쓰기 0'
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
  # 수정 라운드 1(KB-7): 서버가 보낸 문자열의 터미널 제어열(ESC [2J · OSC 52 클립보드 쓰기)은 출력 전에 ? 로 — 판정 · 흐름은 그대로
  Run-Case 'S08cc' '(KB-7) metadata 조회 403 의 오류 줄에 OSC 52 제어열(dev admin) → 판정 불가 줄은 제어 문자를 ? 로 · 화면 제어 문자 0 · 쓰기 0' `
    -Setup { $global:F['metaCtrl'][$DA.path] = 1 } -Inputs $OK2 -Expect '판정 단계에서 중단' -Want @("STOP $($DA.path) — 판정 불가: metadata 조회 exit=2 · * permission denied?]52;c;QUJD?") -Post {
      Check 'put 0' ($global:PutCalls.Count -eq 0) }
  Run-Case 'S10cc' '(KB-7) vault status 의 type · version 에 제어열(ESC [2J · OSC 52) → OK 줄은 ? 로 · 7경로 생성 정상' -Setup { $global:F['status'] = 'ctrl' } -Inputs $OK2 `
    -Want @('seal type=ocikms?[2J · server 2.0.4?]52;c;QUJD?)', '판정: kv 7경로 준비 완료') -Post { foreach ($e in $PATHS) { Check-Created $e } }
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
  # 수정 라운드 1(KB-2): 모듈 로깅 실효 상태 — 레지스트리 정책이 비어도 Utility · Security 의 LogPipelineExecutionDetails · powershell.config.json 이 켜져 있으면 시작 전 중단
  Run-Case 'S10m' '(KB-2) Utility LogPipelineExecutionDetails 켜짐(레지스트리 0 · -SettingsFile 꼴) → 시작 전 중단(입력 0 · vault 호출 0)' -Setup { $global:ModLog['Microsoft.PowerShell.Utility'] = $true } -Inputs $OK2 -Expect 'PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S10n' '(KB-2) 사용자 powershell.config.json 의 PowerShellPolicies.ModuleLogging.EnableModuleLogging = true → 시작 전 중단' -Setup { $global:CfgText['user'] = '{"PowerShellPolicies":{"ModuleLogging":{"EnableModuleLogging":true,"ModuleNames":["Microsoft.PowerShell.Utility"]}}}' } -Inputs $OK2 -Expect 'PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다' -Post {
      Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  # 수정 라운드 2(KB2-1): -SettingsFile 의 Core 대상 정책(설정 파일 깨끗 · 세 모듈 꺼짐 · Core 스냅인만 켜짐) · 설정 파일의 ModuleLogging 은 값과 무관하게 멈춘다
  Run-Case 'S10p' '(KB2-1 ③) -SettingsFile 의 Core 대상 정책 — 설정 파일 두 곳 깨끗 · Utility · Security · Management 꺼짐 · Core 스냅인만 켜짐 → 시작 전 중단(입력 0 · vault 호출 0)' -Setup { $global:CoreLog = $true } -Inputs $OK2 `
    -Expect 'PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐: Microsoft.PowerShell.Core ·' -Post { Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
  Run-Case 'S10q' '(KB2-1 ②) 사용자 설정 파일에 ModuleLogging 이 있다(값 false) → 값과 무관하게 시작 전 중단' -Setup { $global:CfgText['user'] = '{ "PowerShellPolicies": { "ModuleLogging": { "EnableModuleLogging": false } } }' } -Inputs $OK2 `
    -Expect 'PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다(실효 켜짐:  · 설정 파일 정책(값 무관): ' -Post { Check '입력 0' ($global:ReadLog.Count -eq 0); Check 'vault 호출 0' ($global:ArgvLog.Count -eq 0) }
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
        Check '삭제는 됐다(모의)' (-not $global:Kv.ContainsKey($DA.path) -and (Ev-Index "vault:meta-delete:$($DA.path)") -ge 0) }
    # ---- S37b(T075 · 설계 D20 적용 순서 2–3단계 연쇄): S37a 상태(옛 규칙 acl)에서 런북 §4 T057 의 ② 삭제 블록(코드 펜스에서 추출한 그대로 — R2 관문 통과분)으로
    #      acl 2경로를 한 번에 한 경로씩 지운 뒤(경로 재입력 · No value found 확인) W-6 을 재실행 → 사용자 5 SKIP · acl 2 absent → 생성(B2 꼬리 · live 비밀번호 — B4ⓑ).
    #      삭제 단계는 Setup 에서 돈다(창의 VAULT_ADDR · VAULT_TOKEN 을 넣었다가 지운다 · 위반 기록은 남겨 공통 단언이 본다) — 그 단계의 입력 · 이벤트 · 호출 기록은 재실행 전에 비운다
    function Invoke-RbDelete { param([string[]]$paths)
      $out = [System.Collections.ArrayList]::new()
      $global:AllowDelete = $true
      $env:VAULT_ADDR = $global:EXPECTED_ADDR; $env:VAULT_TOKEN = $global:FAKE_ROOT
      try {
        foreach ($p in $paths) {
          $global:Inputs.Enqueue($p); $global:Inputs.Enqueue($p)
          try { & ([scriptblock]::Create([string]$global:RbCode[$MD])) *>&1 | ForEach-Object { [void]$out.Add([string]$_) } } catch { [void]$out.Add('THROW: ' + [string]$_.Exception.Message) } } }
      finally {
        Remove-Item -LiteralPath Env:VAULT_ADDR, Env:VAULT_TOKEN -ErrorAction SilentlyContinue
        $global:AllowDelete = $false
        foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'Events', 'ClipValues', 'PutCalls') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
        $global:Inputs = [System.Collections.Queue]::new() }
      $out -join "`n" }
    Run-Case 'S37b' '(T075 · D20 적용 순서 2–3단계 연쇄) S37a 상태(옛 규칙 acl) → 런북 §4 T057 ② 삭제 블록(추출 그대로)으로 kv/dev/dragonfly/acl → kv/prod/dragonfly/acl 삭제(No value found 확인) → W-6 재실행 = 사용자 5 SKIP · acl 2 absent → 생성 v1(B2 꼬리 · live 비밀번호로 렌더 — 독립 계산과 바이트 일치) · 사용자 값 불변 · put 2 · vault 호출 21회' `
      -Setup { foreach ($u in $USERS) { Seed-LiveOk $u }; foreach ($a in @($DACL, $PACL)) { Seed-Path $a.path ([ordered]@{ 'users.acl' = (Acl-T057 $a.env) }) }; $script:rbDel = Invoke-RbDelete @($DACL.path, $PACL.path) } -Inputs $OK2 `
      -Want (@($USERS | ForEach-Object { & $SKIPLINE $_ }) + @((& $PLANLINE $DACL), (& $PLANLINE $PACL), (& $OKLINE $DACL), (& $OKLINE $PACL), '판정 결과: 생성 예정 2 · 건너뜀(live-ok) 5 · 중단 0', '쓸 경로 2개', '이 실행이 kv 에 새로 쓴 경로: 2건(생성·검증 완료 2 · 응답 유실 뒤 재판정으로 검증 완료 0 · 기록 후 검증 실패 0) · 결과 미확인 0 · 건너뜀 5 · 중단 0 · 미실행 0', '판정: kv 7경로 준비 완료')) `
      -NotWant @('STOP ') -Post {
        $rb = [string]$script:rbDel
        Check '사전 단계(런북 ② 삭제 블록 — 추출 그대로): acl 2경로 각각 OK(No value found 확인) · THROW 0 · 모의 삭제 기록 = acl 2경로 정확히' ($rb.Contains("OK   $($DACL.path) — 모든 버전 · 메타데이터 삭제(No value found 확인)") -and $rb.Contains("OK   $($PACL.path) — 모든 버전 · 메타데이터 삭제(No value found 확인)") -and -not $rb.Contains('THROW') -and $global:Deleted.Count -eq 2 -and $global:Deleted.ContainsKey($DACL.path) -and $global:Deleted.ContainsKey($PACL.path))
        Check 'put 2회 = dev acl → prod acl(사용자 경로 put 0)' ($global:PutCalls.Count -eq 2 -and (SEq $global:PutCalls[0].path $DACL.path) -and (SEq $global:PutCalls[1].path $PACL.path))
        foreach ($a in @($DACL, $PACL)) {
          Check-Created $a
          $acl = [string](KvData $a.path)['users.acl']
          Check "$($a.path): 첫 줄 = $ACL_DEFAULT · 옛 줄 0(F12)" ($acl.StartsWith($ACL_DEFAULT + "`n", [StringComparison]::Ordinal) -and -not $acl.Contains($ACL_DEFAULT_OLD))
          Check "$($a.path): pod 사용자 줄 = B2 꼬리 · 옛 규칙 줄 0(UD-9)" ($acl.Contains($RULE_IA + "`n") -and -not $acl.Contains($RULE_IA_T057 + "`n"))
          Check "$($a.path): = Acl-For($($a.env), 모의 live 비밀번호) 바이트열 일치(사용자 비밀번호 불변 — 회전 아님)" (SEq $acl (Acl-For $a.env (Live-Map $a.env))) }
        foreach ($u in $USERS) { Check-Unchanged $u (Live-Data $u) }
        Check-WriteOrder @($DACL, $PACL)
        Check 'vault 호출 21회(재실행만 — 3 + 판정 metadata get 7 + live 사용자 kv get 5 + 쓰기 3×2)' ($global:ArgvLog.Count -eq 21) "vault 호출 $($global:ArgvLog.Count)" } }
  }
  # ===== B부(T075 조각 ④ · ③ 사후) — O-1 · O-2 · W-2 · O-3 · O-4 · O-5 · O-6 사전 · O-6 사후 · W-6 ACL LOAD. -Only A 면 건너뛴다
  if ($RunB) {
  Write-Host '=== B부 — O-1 · O-2 · W-2 · O-3 · O-4 · O-5(a · b · c) · O-6 사전 · O-6 사후 · W-6 ACL LOAD ==='
  # ---- 계약(블록과 독립 — 설계 D10 · D11 · D16 · D20 · contracts/identity-admin-api.md · data-model §8 · infra/vault · infra/cloudflare)
  $SENT = 'PLACEHOLDER-T044-SENTINEL'
  $JWKS = 'http://authentik-server.identity.svc:9000/application/o/identity-admin/jwks/'
  $ISS = 'https://auth.joshuatech.dev/application/o/identity-admin/'
  $IAROLE = @{ dev = 'dev_identity_admin'; prod = 'identity_admin' }
  $IAKINDS = @('app', 'owner', 'kafka', 'dragonfly', 'authentik', 'webhook', 'django', 'sentry', 'store', 'preshared')
  function IaPath { param([string]$ev, [string]$k)
    $r = $IAROLE[$ev]
    @{ app = "kv/$ev/db/$r/app"; owner = "kv/$ev/db/$r/owner"; kafka = "kv/$ev/kafka/identity-admin"; dragonfly = "kv/$ev/dragonfly/identity-admin"; authentik = "kv/$ev/authentik/identity-admin"
      webhook = "kv/$ev/authentik/webhooks/identity-admin"; django = "kv/$ev/django/identity-admin"; sentry = "kv/$ev/sentry/identity-admin"; store = "kv/$ev/openfga/store_id"; preshared = "kv/$ev/openfga/preshared" }[$k] }
  # 가짜 값(전부 MOCK 접두 · base64url 문자만 — 이 파일에 긴 리터럴 0): 태그마다 SHA-256 hex 를 이어 붙여 길이를 맞춘다
  function MockStr { param([string]$tag, [int]$len) ('MOCK-' + $tag + '-' + (Hex-Lower $tag) + (Hex-Lower ($tag + '+'))).Substring(0, $len) }
  $IAPW = @{}
  foreach ($ev in 'dev', 'prod') { foreach ($k in 'app', 'owner', 'kafka', 'df', 'wh') { $IAPW["$ev-$k"] = MockStr "$ev-$k" 43 }; $IAPW["$ev-sk"] = MockStr "$ev-sk" 64 }
  function PgUrl { param([string]$ev, [string]$k) $u = "$($IAROLE[$ev])_$k"; 'postgresql://' + $u + ':' + $IAPW["$ev-$k"] + '@pg-main-rw.data.svc:5432/' + $IAROLE[$ev] + '?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt' }
  # W-2 전 상태(T054 · T056 · T057 시드 + T044 sentinel 5경로 · django · sentry 없음)
  function Seed-IaBase { param([string]$ev)
    foreach ($k in 'app', 'owner') { Seed-Path (IaPath $ev $k) ([ordered]@{ username = "$($IAROLE[$ev])_$k"; password = $IAPW["$ev-$k"]; url = (PgUrl $ev $k) }) }
    Seed-Path (IaPath $ev 'kafka') ([ordered]@{ password = $IAPW["$ev-kafka"] })
    Seed-Path (IaPath $ev 'dragonfly') ([ordered]@{ password = $IAPW["$ev-df"]; url = ('redis://identity-admin:' + $IAPW["$ev-df"] + '@dragonfly-' + $ev + '.data.svc:6379/0') })
    Seed-Path (IaPath $ev 'authentik') ([ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = $SENT; issuer = $SENT; api_token = $SENT })
    Seed-Path (IaPath $ev 'webhook') ([ordered]@{ secret = $SENT })
    Seed-Path (IaPath $ev 'store') ([ordered]@{ store_id = $SENT })
    Seed-Path (IaPath $ev 'preshared') ([ordered]@{ key = $SENT }) }
  # W-2 뒤 상태(authentik v2 = 계약 값 patch · webhook v2 = 43자 · django · sentry v1)
  function Seed-IaDone { param([string]$ev)
    Seed-IaBase $ev
    Seed-Path (IaPath $ev 'authentik') ([ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = $JWKS; issuer = $ISS; api_token = $SENT }) 2
    Seed-Path (IaPath $ev 'webhook') ([ordered]@{ secret = $IAPW["$ev-wh"] }) 2
    Seed-Path (IaPath $ev 'django') ([ordered]@{ secret_key = $IAPW["$ev-sk"] })
    Seed-Path (IaPath $ev 'sentry') ([ordered]@{ dsn = '' }) }
  # Cloudflare 출력(가짜): AUD = 소문자 hex 64 · Client ID = 소문자 hex 32 + .access · client_secret = 54자 [A-Za-z0-9_-](hex 밖 글자 포함 · 비밀 — 바늘)
  #   T075 보정 2026-11-19(L4 · d5 진단): client_secret 실측 꼴 = 토큰 넷 모두 54자 · 영숫자 · _ · -(hex 밖 글자 있음) — 64 hex 가 아니다(research.md R12 :4256 · :4633 —
  #   2026-08 이후 신규 발급 = cfast_[40자][8자 checksum] = 54자 · 옛 64 hex 도 유효 — 설계 D11 이 이 기록과 대조하지 않았다). 옛 모의(Hex-Lower = 소문자 hex 64)는
  #   블록과 같은 가정을 따라 하네스는 PASS · 라이브 O-5a 는 「자격을 꺼내지 못했다」였다 → 모의를 실측 꼴로 바꾼다('MOCK-' 5자 + SHA-512 base64url 49자 — 접두 cfast_ 는 재지 않았다)
  $AUDV = @{}
  foreach ($k in 'identity-m2m-dev', 'identity-m2m-prod', 'admin', 'argo', 'vault', 'traefik', 'preview', 'auth-admin', 'ssh', 'k8s') { $AUDV[$k] = Hex-Lower "aud-$k" }
  function Cf-Secret { param([string]$s) ('MOCK-' + [Convert]::ToBase64String([System.Security.Cryptography.SHA512]::HashData([Text.Encoding]::UTF8.GetBytes($s))).Replace('+', '-').Replace('/', '_')).Substring(0, 54) }
  $TOKV = [ordered]@{}
  foreach ($k in 'web-bff-dev', 'web-bff-prod', 'tester-m2m', 'tester-k8s') { $TOKV[$k] = [ordered]@{ client_id = ((Hex-Lower "cid-$k").Substring(0, 32) + '.access'); client_secret = (Cf-Secret "secret-$k"); expires_at = '2027-09-03T00:00:00Z' } }
  foreach ($k in @($TOKV.Keys)) { $sx = [string]$TOKV[$k]['client_secret']; if (-not [regex]::IsMatch($sx, '\A[0-9A-Za-z_-]{54}\z') -or [regex]::IsMatch($sx, '\A[0-9a-f]+\z')) { throw "하네스 결함: 가짜 client_secret 이 실측 꼴(54자 [A-Za-z0-9_-] · hex 밖 글자 포함)이 아니다($k)" } }
  function Seed-Tofu { param([hashtable]$aud = $AUDV, $tok = $TOKV)
    $global:TofuOut['access_app_aud'] = (ConvertTo-Json -InputObject $aud -Compress)
    $global:TofuOut['service_tokens'] = (ConvertTo-Json -InputObject $tok -Depth 5 -Compress)
    foreach ($k in @($TOKV.Keys)) { [void]$global:ExtraSecrets.Add([string]$TOKV[$k]['client_secret']) } }
  $INFRA = [IO.Path]::GetFullPath((Join-Path $BlockDir '..\..\..\..\infra\cloudflare'))
  # 응답 모형(O-5): Access 앞단 — 헤더 없으면 401 · 모르는 자격 403 · m2m 호스트의 env 와 자격 env 가 맞아야 /session/check 200(CN 판정) · /health 는 배포 뒤 200 · 배포 전 Traefik 404
  $global:DeploySha = (Hex-Lower 'git-sha-9fd9f2c').Substring(0, 40)
  function Http-Model { param($req, [hashtable]$opt = @{})
    $ev = ([regex]::Match($req.host, '\Aidentity-m2m-(dev|prod)\.joshuatech\.dev\z')).Groups[1].Value
    $who = ''
    foreach ($k in @($TOKV.Keys)) { if ((SEq $req.id $TOKV[$k]['client_id']) -and (SEq $req.secret $TOKV[$k]['client_secret'])) { $who = $k } }
    if ($req.id.Length -eq 0) { return [pscustomobject]@{ code = '401'; xrid = ''; cc = ''; body = 'Unauthorized'; cookie = '' } }
    if ($who.Length -eq 0 -or (SEq $who 'tester-k8s') -or ($who.StartsWith('web-bff-') -and -not (SEq $who "web-bff-$ev"))) { return [pscustomobject]@{ code = '403'; xrid = ''; cc = ''; body = 'Forbidden'; cookie = '' } }
    $cookie = 'CF_Authorization=' + (MockStr "cookie-$ev" 40)
    if (SEq $req.path '/health') {
      if (-not $opt['deployed']) { return [pscustomobject]@{ code = '404'; xrid = ''; cc = ''; body = '404 page not found'; cookie = $cookie } }
      $ck = [ordered]@{ db = [ordered]@{ status = 'ok'; latency_ms = 3 }; dragonfly = [ordered]@{ status = 'ok'; latency_ms = 1 }; kafka_producer = [ordered]@{ status = 'ok'; latency_ms = 9 } }
      $body = [ordered]@{ status = 'ok'; version = '0.1.0'; git_sha = $global:DeploySha; checks = $ck }
      return [pscustomobject]@{ code = '200'; xrid = 'req-mock-health-1'; cc = ''; body = (ConvertTo-Json -InputObject $body -Depth 5 -Compress); cookie = $cookie } }
    if (SEq $req.path '/session/check') {
      if (-not $who.StartsWith('web-bff-')) { return [pscustomobject]@{ code = '403'; xrid = 'req-mock-sc-0'; cc = 'no-store'; body = '{"type":"https://joshuatech.dev/problems/access-required","title":"Forbidden","status":403}'; cookie = $cookie } }
      if ($req.query.Contains('iat=x')) { return [pscustomobject]@{ code = '400'; xrid = 'req-mock-sc-400'; cc = ''; body = '{"type":"https://joshuatech.dev/problems/validation-error","title":"Bad Request","status":400}'; cookie = $cookie } }
      return [pscustomobject]@{ code = '200'; xrid = 'req-mock-sc-200'; cc = 'no-store'; body = '{"active": true}'; cookie = $cookie } }
    [pscustomobject]@{ code = '404'; xrid = ''; cc = ''; body = '404 page not found'; cookie = $cookie } }
  # ---- B부 정적 관문(블록마다): A부 S12 의 판정 함수(Bad-Cmds · Bad-Types · Bad-Host · Bad-Redir · Find-Inner · Finally-Emitters · Is-FlushOrTry · Bad-Secrets)를 그대로 쓰고 허용 목록만 블록별로 준다
  $BCmdsBase = @('Read-Host', 'Write-Host', 'Write-Warning', 'Set-Clipboard', 'Get-ItemProperty', 'Test-Path', 'Get-ChildItem', 'Remove-Item', 'Remove-Variable', 'Get-Command', 'ConvertFrom-Json', 'ConvertFrom-SecureString', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug',
    'Import-Module', 'Get-Module', 'Get-Content', 'Split-Path', 'Join-Path')
  $BCmdsTool = @('Write-Host', 'Get-ItemProperty', 'Test-Path', 'Get-ChildItem', 'Get-Command', 'ConvertFrom-Json', 'Where-Object', 'ForEach-Object', 'Set-StrictMode', 'Set-PSDebug', 'Remove-Variable',
    'Import-Module', 'Get-Module', 'Get-Content', 'Split-Path', 'Join-Path', 'tofu')
  $BTypes = @('string', 'System.String', 'Convert', 'System.Convert', 'StringComparison', 'System.StringComparison', 'object', 'System.Object', 'System.Security.Cryptography.SHA256', 'System.Text.Encoding',
    'Array', 'System.Array', 'System.Security.Cryptography.RandomNumberGenerator', 'System.Collections.Generic.HashSet[char]', 'regex', 'System.IO.Path', 'DateTimeOffset', 'System.Collections.Generic.List[string]')
  $VSigRO = @('version', 'status -format=json', 'token lookup -format=json', 'kv metadata get', 'kv get -format=json')
  function Sb-Names { param($ast)
    @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.Right -is [System.Management.Automation.Language.CommandExpressionAst] -and $n.Right.Expression -is [System.Management.Automation.Language.ScriptBlockExpressionAst] }, $true) | ForEach-Object { Var-Name $_.Left }) }
  function Get-SbText { param($ast, [string]$name)
    $as = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) $name) }, $true))
    if ($as.Count -ne 1) { return $null }
    $as[0].Right.Extent.Text }
  function Run-OStatic { param([string]$Id, [string]$File, [string[]]$Cmds, [string[]]$Owners, [string[]]$VSigs = @(), [int]$ReadHosts = 0, [switch]$VaultEnv, [scriptblock]$Extra = $null)
    $global:CaseChecks = [System.Collections.ArrayList]::new()
    $path = Join-Path $BlockDir $File
    $exists = Microsoft.PowerShell.Management\Test-Path -LiteralPath $path
    Check '블록 파일 존재' $exists
    $bytes = [byte[]]@(); if ($exists) { $bytes = [IO.File]::ReadAllBytes($path) }
    Check 'BOM 없음 · CR 0 · TAB 0' ($bytes.Length -gt 0 -and -not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB) -and @($bytes | Where-Object { $_ -eq 13 -or $_ -eq 9 }).Count -eq 0)
    $utf8ok = $true; try { [void][Text.UTF8Encoding]::new($false, $true).GetString($bytes) } catch { $utf8ok = $false }
    Check 'UTF-8 유효 · 끝 = } + LF 1개' ($utf8ok -and $bytes.Length -ge 2 -and $bytes[$bytes.Length - 2] -eq 0x7D -and $bytes[$bytes.Length - 1] -eq 0x0A)
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    $lines = $text.Split("`n")
    $blank = 0; for ($i = 0; $i -lt $lines.Count - 1; $i++) { if ($lines[$i].Trim().Length -eq 0) { $blank++ } }
    Check '첫 줄 = & { · 빈 줄 0(파일 전체 — 붙여넣기 안전)' ($lines.Count -gt 1 -and (SEq $lines[0] '& {') -and $blank -eq 0) "빈 줄 $blank"
    $tk = $null; $er = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tk, [ref]$er)
    Check '파서 오류 0' ($er.Count -eq 0) $(if ($er.Count) { "L$($er[0].Extent.StartLineNumber) $($er[0].Message)" } else { '' }) -Gate
    $inner = Find-Inner $ast
    Check '최상위 문장 1개 = & { … } · } 뒤 남는 문자 0' ($null -ne $inner -and $ast.EndBlock.Statements[0].Extent.EndOffset -eq $text.Length - 1)
    $helpers = Sb-Names $ast
    $badCmd = Bad-Cmds $ast $Cmds $helpers $inner
    Check "명령 허용 목록($($Cmds.Count)개 · 스크립트블록 헬퍼만 & 호출 — Start-Transcript · Out-File · Invoke-Expression · Start-Process · 절대 경로 실행 파일 등 0)" ($badCmd.Count -eq 0) ($badCmd -join '; ') -Gate
    $badType = Bad-Types $ast $BTypes
    Check '정적 .NET 호출 허용 목록([Console] · [IO.File] · [Environment] · [Diagnostics.Process] 등 0)' ($badType.Count -eq 0) ($badType -join '; ') -Gate
    $badHost = Bad-Host $ast
    Check '$Host · $ExecutionContext 는 $Host.UI.RawUI.FlushInputBuffer() 한 모양만' ($badHost.Count -eq 0) ($badHost -join '; ') -Gate
    $badRedir = Bad-Redir $ast
    Check '파일 리다이렉트 0($null 만)' ($badRedir.Count -eq 0) ($badRedir -join '; ') -Gate
    if ($null -ne $inner) {
      $b0 = @($inner.EndBlock.Statements)
      $psd = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Set-PSDebug', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
      Check '본문 첫 문장 = Set-PSDebug -Off · 그 1곳뿐' ($b0.Count -gt 0 -and (SEq $b0[0].Extent.Text 'Set-PSDebug -Off') -and $psd -eq 1)
      $pre0 = @($b0 | ForEach-Object { $_.Extent.Text })
      $fixMissing = @(@('$WhatIfPreference = $false', "`$ConfirmPreference = 'High'", '$PSDefaultParameterValues = @{}') | Where-Object { $f = $_; @($pre0 | Where-Object { SEq $_ $f }).Count -ne 1 })
      Check '본문 직계 문장으로 세션 설정 고정 3문장' ($fixMissing.Count -eq 0) ($fixMissing -join '; ')
      $tries = @($b0 | Where-Object { $_ -is [System.Management.Automation.Language.TryStatementAst] })
      Check '본문 try 1개 + finally' ($tries.Count -eq 1 -and $null -ne $tries[0].Finally)
      if ($tries.Count -eq 1 -and $null -ne $tries[0].Finally) {
        $fe = Finally-Emitters $tries[0].Finally.Statements
        Check 'finally 는 Write-Host/Write-Warning · Remove-* · Set-Clipboard · 대입만(성공 스트림 출력 없음)' ($fe.Count -eq 0) ($fe -join '; ')
        if ($VaultEnv) {
          $fs = @($tries[0].Finally.Statements | ForEach-Object { $_.Extent.Text })
          Check 'finally 첫 두 문장 = 블록이 만든 VAULT_TOKEN · VAULT_ADDR 제거' ($fs.Count -ge 2 -and $fs[0].StartsWith('if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN', [StringComparison]::Ordinal) -and $fs[1].StartsWith('if ($addrOwned) { Remove-Item Env:VAULT_ADDR', [StringComparison]::Ordinal)) } } }
    $badRead = @()
    $reads = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Read-Host', [StringComparison]::OrdinalIgnoreCase) }, $true))
    foreach ($c in $reads) {
      $p = $c.Parent; $owner = $null; $sbx = $null
      while ($null -ne $p -and $null -eq $sbx) { if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { $sbx = $p }; $p = $p.Parent }
      if ($null -ne $sbx) { $p = $sbx.Parent; while ($null -ne $p) { if ($p -is [System.Management.Automation.Language.AssignmentStatementAst] -and $p.Left -is [System.Management.Automation.Language.VariableExpressionAst]) { $owner = $p.Left.VariablePath.UserPath; break }; if ($p -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) { break }; $p = $p.Parent } }
      if (-not (@($Owners) -ccontains [string]$owner) -or $null -eq $sbx) { $badRead += "L$($c.Extent.StartLineNumber) 헬퍼 밖 Read-Host"; continue }
      $body = @($sbx.ScriptBlock.EndBlock.Statements)
      $iR = -1; for ($i = 0; $i -lt $body.Count; $i++) { if ($c.Extent.StartOffset -ge $body[$i].Extent.StartOffset -and $c.Extent.EndOffset -le $body[$i].Extent.EndOffset) { $iR = $i; break } }
      if ($iR -lt 1 -or -not (Is-FlushOrTry $body[$iR - 1])) { $badRead += "L$($c.Extent.StartLineNumber) 바로 앞 직계 문장이 입력 버퍼 비움이 아니다" } }
    Check "Read-Host $ReadHosts 곳 · 정지점 헬퍼($($Owners -join ' · ')) 안에서만 · 바로 앞 직계 문장 = 입력 버퍼 비움(AST)" ($badRead.Count -eq 0 -and $reads.Count -eq $ReadHosts) "$($badRead -join '; ') · Read-Host $($reads.Count) 곳"
    $badVault = @()
    foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) }, $true)) {
      $el = @($c.CommandElements | Select-Object -Skip 1 | ForEach-Object { if ($_ -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $_.Value } else { $_.Extent.Text } })
      $sig = ($el | Select-Object -First 3) -join ' '
      foreach ($x in $el) { if (([string]$x).StartsWith('-field', [StringComparison]::Ordinal)) { $badVault += "L$($c.Extent.StartLineNumber) -field" } }
      if (-not @($VSigs | Where-Object { $sig.StartsWith($_, [StringComparison]::Ordinal) }).Count) { $badVault += "L$($c.Extent.StartLineNumber) vault $sig" } }
    Check "vault 호출 모양(허용 접두: $(if ($VSigs.Count) { $VSigs -join ' / ' } else { '없음 — vault 0' }) · -field 0)" ($badVault.Count -eq 0) ($badVault -join '; ')
    Check '모듈 로깅 4키 가드 문장이 있다(PowerShellCore · UseWindowsPowerShellPolicySetting · Windows\PowerShell · EnableModuleLogging — 설계 D10 CD-8)' ($text.Contains('PowerShellCore\ModuleLogging') -and $text.Contains('UseWindowsPowerShellPolicySetting') -and $text.Contains('Windows\PowerShell\ModuleLogging') -and $text.Contains("'EnableModuleLogging') -eq 1"))
    $kcRef = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and [string]::Equals([string]$n.VariablePath.UserPath, 'env:KUBECONFIG', [StringComparison]::OrdinalIgnoreCase) }, $true)).Count
    Check 'MOCK 0 · 비밀처럼 보이는 상수 0 · hvs.<영숫자> 0 · Start-Transcript 0 · $env:KUBECONFIG 참조 0(AST — 주석 안 언급은 노드가 아니다)' (-not $text.Contains('MOCK') -and (Bad-Secrets $text).Count -eq 0 -and -not ($text -cmatch 'hvs\.[A-Za-z0-9]') -and -not $text.Contains('Start-Transcript') -and $kcRef -eq 0) "$((Bad-Secrets $text) -join ', ') · KUBECONFIG 참조 $kcRef"
    Static-R1 $ast $text
    if ($Extra) { try { & $Extra $ast $text } catch { Check '블록별 정적 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
    Finish-Case $Id "정적 — $File(관문 5: 파서 · 명령 · 형식 · `$Host · 리다이렉트 + 구조 · 세션 고정 · finally · Read-Host · vault 모양 · 모듈 로깅 가드 · 비밀 상수 0 · 블록별 단언)" ''
    Static-Gate -Expected 5 }
  # ---- B부 실행기 + 공통 사후 조건(A부 Run-Case 의 노출 · 위생 단언을 블록 종류에 맞춰 일반화)
  $global:BGate = @{}
  function Run-OCase {
    param([string]$Id, [string]$Desc, [string]$File, [hashtable]$Allow = @{}, [scriptblock]$Setup = $null, [string[]]$Inputs = @(), [string]$Expect = 'ok',
      [string[]]$Want = @(), [string[]]$NotWant = @(), [scriptblock]$Post = $null, [hashtable]$PreEnv = @{}, [string]$Summary = '', [switch]$Vault, [switch]$ReadOnly, [switch]$Paste)
    if ($global:BGate.ContainsKey($File) -and $global:BGate[$File]) {
      $global:CaseChecks = [System.Collections.ArrayList]::new()
      Check "정적 관문 통과(블록 $File)" $false ([string]$global:BGate[$File])
      Finish-Case $Id $Desc '(정적 관문 FAIL — 실행하지 않았다)'
      return }
    Assert-Guard
    Reset-Mocks
    foreach ($k in @($Allow.Keys)) { $global:Allow[$k] = [bool]$Allow[$k] }
    $global:CaseChecks = [System.Collections.ArrayList]::new()
    if ($Setup) { try { & $Setup } catch { Check 'setup 실행' $false ([string]$_.Exception.Message) } }
    # 하네스 자체 단언(라운드 2): 모의 상태 표가 그대로 표인가 — pwsh -File 에서는 $script: 가 전역이라 같은 이름(대소문자 무관)의 스크립트 변수가 모의 전역을 덮을 수 있다
    Check '하네스 자체: 모의 상태 표(CfgText · ModLog · FakeSrc · F)가 해시 테이블 그대로(스크립트 변수 이름 충돌 0)' ($global:CfgText -is [hashtable] -and $global:ModLog -is [hashtable] -and $global:FakeSrc -is [hashtable] -and $global:F -is [hashtable])
    foreach ($x in $Inputs) { $global:Inputs.Enqueue($x) }
    foreach ($k in @($PreEnv.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value ([string]$PreEnv[$k]) }
    $global:Error.Clear()
    $gvBefore = Snapshot-Globals
    $global:GvBefore = $gvBefore
    $items = [System.Collections.ArrayList]::new()
    $threw = $false; $errMsg = ''
    $path = Join-Path $BlockDir $File
    $global:ItemCount = 0
    # 붙여넣기 모드(수정 라운드 1 · KB-5): 파일 전문을 스크립트블록으로 만들어 돌린다 — 파일 실행과 달리 블록 안의 $script: 가 블록 밖(하네스 스크립트 · 전역) 범위로 풀린다.
    #   실행 전후로 전역 · 스크립트 범위의 변수 이름을 대조해 새 변수 0 을 본다(파일 실행에서는 블록 스크립트 범위가 실행과 함께 사라져 보이지 않는 길)
    $pBefore = @{}
    if ($Paste) { foreach ($v in @(Get-Variable -Scope Global)) { $pBefore['g:' + $v.Name] = $true }; foreach ($v in @(Get-Variable -Scope Script)) { $pBefore['s:' + $v.Name] = $true } }
    try {
      if ($Paste) { $psb = [scriptblock]::Create([IO.File]::ReadAllText($path)); & $psb *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } }
      else { & $path *>&1 | ForEach-Object { [void]$items.Add($_); $global:ItemCount++ } } }
    catch { $threw = $true; $errMsg = [string]$_.Exception.Message }
    $pNew = @()
    if ($Paste) {
      foreach ($v in @(Get-Variable -Scope Global)) { if (-not $pBefore.ContainsKey('g:' + $v.Name) -and -not (SEq $v.Name 'psb')) { $pNew += 'g:' + $v.Name } }
      foreach ($v in @(Get-Variable -Scope Script)) { if (-not $pBefore.ContainsKey('s:' + $v.Name)) { $pNew += 's:' + $v.Name } } }
    $lines = @($items | ForEach-Object { [string]$_ })
    if ($threw) { $lines += "THROW: $errMsg" }
    $text = $lines -join "`n"
    $global:LastText = $text
    $global:LastItems = $items
    if (SEq $Expect 'ok') { Check 'outcome: 완주(throw 없음)' (-not $threw) $errMsg } else { Check "outcome: throw '$Expect'" ($threw -and $errMsg.Contains($Expect)) $errMsg }
    foreach ($w in $Want) { Check "want: $w" $text.Contains($w) }
    foreach ($w in $NotWant) { Check "notwant: $w" (-not $text.Contains($w)) }
    # 노출 0(모든 면 — 화면 · 프롬프트 · argv(vault · kubectl · tofu · curl) · 클립보드 · $Error · 환경 변수 · 바뀐 전역)
    $needles = Build-Needles
    $skipEnv = @(); if ($PreEnv.ContainsKey('VAULT_TOKEN')) { $skipEnv += 'VAULT_TOKEN' }
    $surfaces = [ordered]@{ '화면(모든 스트림)' = $text; '프롬프트' = ($global:Prompts -join "`n"); 'argv' = (@($global:ArgvLog) + @($global:XArgv) -join "`n"); '클립보드' = ($global:ClipValues -join "`n")
      '$Error' = (Error-Text); '환경 변수' = (Env-Text $skipEnv) }
    foreach ($sn in $surfaces.Keys) { $hit = First-Needle ([string]$surfaces[$sn]) $needles; Check "노출 0: $sn" ($null -eq $hit) $(if ($null -ne $hit) { "바늘(길이 $($hit.Length)) 발견" } else { '' }) }
    $gHit = Globals-Hit $gvBefore $needles
    Check '노출 0: 전역 변수(이 시나리오에서 새로 생기거나 바뀐 것)' ($null -eq $gHit) ([string]$gHit)
    Check-R1 $text $needles
    Check-ErrClean $threw $errMsg
    if ($Paste) {
      $pNew = @($pNew | Where-Object { -not (@('g:StackTrace', 's:StackTrace') -ccontains $_) })
      Check '붙여넣기 실행 뒤 새 전역 · 스크립트 변수 0(블록 밖 범위에 값이 남는 길 0 — KB-5)' ($pNew.Count -eq 0) ($pNew -join ', ')
      foreach ($n in $pNew) { if ($n.StartsWith('g:', [StringComparison]::Ordinal)) { Remove-Variable -Scope Global -Name $n.Substring(2) -ErrorAction SilentlyContinue } else { Remove-Variable -Scope Script -Name $n.Substring(2) -ErrorAction SilentlyContinue } } }
    if ($Vault) {
      if ($PreEnv.ContainsKey('VAULT_TOKEN')) { Check 'env: 시작 전 VAULT_TOKEN 은 건드리지 않는다' (SEq $env:VAULT_TOKEN $PreEnv['VAULT_TOKEN']) }
      else { Check 'env: VAULT_TOKEN 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_TOKEN)) }
      if ($PreEnv.ContainsKey('VAULT_ADDR') -and -not (SEq $PreEnv['VAULT_ADDR'] $global:EXPECTED_ADDR)) { Check 'env: 시작 전 (다른 값의) VAULT_ADDR 은 건드리지 않는다' (SEq $env:VAULT_ADDR $PreEnv['VAULT_ADDR']) }
      else { Check 'env: VAULT_ADDR 없음' (-not (Microsoft.PowerShell.Management\Test-Path Env:VAULT_ADDR)) }
      # 운영자가 root 토큰을 붙이기 전에 화면의 INFO vault CLI 줄(실행 파일 종류 · 경로)을 본다 — 그 줄이 첫 출력이고 보안 입력보다 먼저다(T054 리뷰 r3 O2 · 런북 §4 T057 「실행」)
      $sec = @($global:ReadLog | Where-Object { $_.secure })
      if ($sec.Count -gt 0) { Check 'INFO vault CLI 줄이 첫 출력이고 root 토큰 보안 입력보다 먼저다' ($global:LastText.StartsWith('INFO vault CLI: ', [StringComparison]::Ordinal) -and $sec[0].items -ge 1) "보안 입력 시점의 출력 수 $($sec[0].items)" } }
    Check '위반 0(허용 목록 밖 vault · kubectl · tofu · curl 인자 · patch/read 밖 블록 · 금지 플래그)' ($global:Violations.Count -eq 0) $(if ($global:Violations.Count) { [string]$global:Violations[0] } else { '' })
    Check '함정 표식 0(실물 vault · kubectl · tofu 실행 파일이 불리지 않았다)' ((Trap-Markers) -eq 0)
    $succ = @($items | Where-Object { -not ($_ -is [System.Management.Automation.InformationRecord] -or $_ -is [System.Management.Automation.WarningRecord] -or $_ -is [System.Management.Automation.ErrorRecord] -or $_ -is [System.Management.Automation.VerboseRecord] -or $_ -is [System.Management.Automation.DebugRecord]) })
    Check '성공 스트림 0(출력은 Write-Host/Write-Warning 뿐)' ($succ.Count -eq 0) "성공 스트림 $($succ.Count)개"
    Check '클립보드에는 공백만 쓴다' (@($global:ClipValues | Where-Object { -not (SEq $_ ' ') }).Count -eq 0)
    Check '비밀(hvs. · MOCK) 입력은 전부 -AsSecureString · 입력은 전부 가려진다(-AsSecureString 또는 -MaskInput)' (@($global:ReadLog | Where-Object { (([string]$_.value).Contains('hvs.') -or ([string]$_.value).Contains('MOCK')) -and -not $_.secure }).Count -eq 0 -and @($global:ReadLog | Where-Object { -not $_.secure -and -not $_.masked }).Count -eq 0)
    Check '첫 동작 = Set-PSDebug -Off 1회' ((Ev-Index 'psdebug:off') -eq 0 -and @($global:Events | Where-Object { SEq $_ 'psdebug:off' }).Count -eq 1) $(if ($global:Events.Count) { "첫 이벤트 $($global:Events[0])" } else { '이벤트 0' })
    $iPol = Ev-First 'reg:policy:'
    $iVal = -1
    foreach ($pfx in 'vault:status', 'vault:token-lookup', 'vault:kv-get:', 'vault:meta-get:', 'tofu:output:', 'curl:get:', 'kubectl:exec:', 'read:secure') { $j = Ev-First $pfx; if ($j -ge 0 -and ($iVal -lt 0 -or $j -lt $iVal)) { $iVal = $j } }
    Check '모듈 로깅 정책 확인이 값이 오가는 첫 동작(vault status · token · kv · tofu output · curl · kubectl · 비밀 입력)보다 먼저(설계 D10 — 첫 단계)' ($iVal -lt 0 -or ($iPol -ge 0 -and $iPol -lt $iVal)) "정책 $iPol · 첫 값 동작 $iVal"
    if ($Summary) { Check "finally 요약 출력($Summary)" $text.Contains($Summary) }
    if ($ReadOnly) { Check '쓰기 0(kv put · patch · metadata delete 호출 0 — 판정 블록)' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0 -and (Ev-First 'vault:meta-delete:') -lt 0) }
    if (SEq $Expect 'ok') { Check '입력 전부 소비(정지점 누락 없음)' ($global:Inputs.Count -eq 0) "남은 입력 $($global:Inputs.Count)" }
    if ($Post) { try { & $Post } catch { Check 'post 단언 실행(예외 없음)' $false ([string]$_.Exception.Message) } }
    foreach ($k in @($PreEnv.Keys)) { if (Microsoft.PowerShell.Management\Test-Path -LiteralPath ('Env:' + $k)) { Remove-Item -LiteralPath ('Env:' + $k) } }
    # 라운드 2: 실행 파일 경로 · Core 스냅인 모의를 시나리오 밖으로 남기지 않는다(다음 시나리오의 정적 관문 · 가드가 실제 해석을 보게)
    $global:FakeSrc = @{}; $global:CoreLog = $false; $global:CoreNoSnap = $false; $global:CoreMissing = $false
    Finish-Case $Id $Desc $text }
  $TOK = $global:FAKE_ROOT
  $AV = @{ kubectl = $true }
  # ---- 정적 관문(블록마다 — FAIL 이면 그 블록의 런타임 시나리오는 실행하지 않는다)
  $kubectlShape = { param($ast, $text)
    $kc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'kubectl', [StringComparison]::Ordinal) }, $true))
    Check 'kubectl 호출 정확히 1곳 · 인자 = @kargs 하나(펼침 — 받는 쪽이 무엇이든 낱말이 따로 간다)' ($kc.Count -eq 1 -and $kc[0].CommandElements.Count -eq 2 -and $kc[0].CommandElements[1] -is [System.Management.Automation.Language.VariableExpressionAst] -and $kc[0].CommandElements[1].Splatted -and (SEq (Var-Name $kc[0].CommandElements[1]) 'kargs'))
    $pl = $null; if ($kc.Count -eq 1) { $pl = $kc[0].Parent }
    Check 'kubectl 의 stdin = ($pw + "`n") 한 식(비밀번호 뒤 LF — PowerShell 의 CRLF 를 redis-cli 가 비밀번호에 남기지 않게 · VD-T075-17 실측)' ($null -ne $pl -and $pl -is [System.Management.Automation.Language.PipelineAst] -and $pl.PipelineElements.Count -eq 2 -and (SEq $pl.PipelineElements[0].Extent.Text '($pw + "`n")'))
    $ka = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and (SEq (Var-Name $n.Left) 'kargs') }, $true))
    $kt = ''; if ($ka.Count -eq 1) { $kt = $ka[0].Right.Extent.Text }
    Check '$kargs = --kubeconfig $kc -n data exec -i deploy/dragonfly-<env> -c dragonfly -- redis-cli --user admin --askpass … · 비밀번호 · 토큰 변수 0 · -t 0' ($ka.Count -eq 1 -and $kt.StartsWith("@('--kubeconfig', `$kc, '-n', 'data', 'exec', '-i', `"deploy/dragonfly-`$envSel`", '-c', 'dragonfly', '--', 'redis-cli', '--user', 'admin', '--askpass'", [StringComparison]::Ordinal) -and -not $kt.Contains('$pw') -and -not $kt.Contains('$tok') -and -not $kt.Contains("'-t'") -and -not $kt.Contains("'-it'")) $kt
    # 수정 라운드 1(KB-4): kv 를 읽은 뒤 · kubectl 호출 전에 VAULT_TOKEN 을 지운다(AST 순서) · INFO 줄에 kubectl 경로($ksrc)
    $kOff = [int]::MaxValue; if ($kc.Count -eq 1) { $kOff = $kc[0].Extent.StartOffset }
    $ri = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'Remove-Item', [StringComparison]::OrdinalIgnoreCase) -and (SEq (Cmd-Text $n) 'Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue') }, $true) | Where-Object { $_.Extent.StartOffset -lt $kOff })
    Check 'kubectl 호출 앞에 Remove-Item Env:VAULT_TOKEN(KB-4 — 자식 프로세스 env 에 토큰 0) · INFO 줄에 kubectl 경로' ($kc.Count -eq 1 -and $ri.Count -ge 1 -and $text.Contains('· kubectl $([string]$kcs[0].CommandType) $ksrc —')) }
  $o6Lint = { param($ast, $text)
    $w6 = [IO.File]::ReadAllText($BlockPath)
    $tk2 = $null; $er2 = $null
    $wast = [System.Management.Automation.Language.Parser]::ParseInput($w6, [ref]$tk2, [ref]$er2)
    $a = Get-SbText $ast 'lint'; $b = Get-SbText $wast 'lint'
    Check 'O-6 사전의 $lint = W-6 의 $lint 와 글자까지 같다(설계 D20 「W-6 판정 = O-6 과 같은 판정 규칙」)' ($null -ne $a -and $null -ne $b -and (SEq $a $b))
    Check 'vault 호출 = 읽기 전용 5종뿐(kv put · patch · delete 0)' (-not $text.Contains('kv put') -and -not $text.Contains('kv patch') -and -not $text.Contains('metadata delete')) }
  $kvContract = { param($ast, $text)
    Check "계약 값 상수: sentinel · jwks_url · issuer 가 하네스 계약과 글자까지 같다(설계 D10 · ia:17)" ($text.Contains("`$sentinel = '$SENT'") -and $text.Contains("`$jwksWant = '$JWKS'") -and $text.Contains("`$issWant = '$ISS'")) }
  $w2Shape = { param($ast, $text)
    & $kvContract $ast $text
    $vc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) }, $true) | ForEach-Object { Cmd-Text $_ })
    Check 'kv put 1곳 = "-cas=$($p.cv)" $p.path -(JSON stdin · 값 argv 0)' (@($vc | Where-Object { SEq $_ 'vault kv put "-cas=$($p.cv)" $p.path -' }).Count -eq 1 -and @($vc | Where-Object { $_.Contains(' put ') }).Count -eq 1)
    Check 'kv patch 1곳 = "-cas=$($p.cv)" $p.path "issuer=$issWant" "jwks_url=$jwksWant"(비밀 아닌 두 값만 argv — 설계 D10)' (@($vc | Where-Object { SEq $_ 'vault kv patch "-cas=$($p.cv)" $p.path "issuer=$issWant" "jwks_url=$jwksWant"' }).Count -eq 1 -and @($vc | Where-Object { $_.Contains(' patch ') }).Count -eq 1)
    Check 'webhook secret = RNG 32바이트 · secret_key = RNG 48바이트(& $newB64 32 · 48 — base64url 43 · 64자)' ($text.Contains('$v = & $newB64 32') -and $text.Contains('$v = & $newB64 48')) }
  $tofuShape = { param($ast, $text)
    $tc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'tofu', [StringComparison]::Ordinal) }, $true) | ForEach-Object { Cmd-Text $_ })
    Check 'tofu 호출 = version · "-chdir=$infra" output -json <access_app_aud · service_tokens> 뿐(apply · state · show 0)' (@($tc | Where-Object { -not ((SEq $_ 'tofu version') -or $_.StartsWith('tofu "-chdir=$infra" output -json ', [StringComparison]::Ordinal)) }).Count -eq 0) ($tc -join ' | ')
    # 수정 라운드 1(KB-8 · KB-1): tofu · curl 동작을 바꾸는 환경 변수 판정이 첫 tofu 호출보다 먼저다(이름만 낸다)
    $iEnv = $text.IndexOf("`$_.Name -like 'TF_LOG*' -or", [StringComparison]::Ordinal); if ($iEnv -lt 0) { $iEnv = $text.IndexOf("-or `$_.Name -like 'TF_LOG*'", [StringComparison]::Ordinal) }
    $iTofu = $text.IndexOf('tofu "-chdir=$infra" output', [StringComparison]::Ordinal)
    Check '환경 변수 판정(TF_LOG* · TF_CLI_ARGS* · TF_WORKSPACE · TF_DATA_DIR — KB-8)이 첫 tofu output 보다 먼저 · 이름만 낸다' ($iEnv -ge 0 -and $iTofu -gt $iEnv -and $text.Contains("'TF_CLI_ARGS*'") -and $text.Contains("'TF_WORKSPACE'") -and $text.Contains("'TF_DATA_DIR'")) }
  $curlShape = { param($ast, $text)
    $cc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'curl.exe', [StringComparison]::Ordinal) }, $true) | ForEach-Object { Cmd-Text $_ })
    Check 'curl.exe 호출 = -q --version · -q -sS --max-time 20 -w $wfmt $url · -q -sS --max-time 20 -H ''@-'' -w $wfmt $url 셋뿐(첫 인자 -q — .curlrc 0 · KB-1 · -i · -D · -v · -c · -b · -o 0)' ($cc.Count -eq 3 -and @($cc | Where-Object { (SEq $_ 'curl.exe -q --version') -or (SEq $_ 'curl.exe -q -sS --max-time 20 -w $wfmt $url') -or (SEq $_ "curl.exe -q -sS --max-time 20 -H '@-' -w `$wfmt `$url") }).Count -eq 3) ($cc -join ' | ')
    Check '-w 형식 = http_code · %header{x-request-id} · %header{cache-control} 만(Set-Cookie 0 — VR-12)' ($text.Contains("`$wfmt = '\nT075-W code=%{http_code} xrid=%header{x-request-id} cc=%header{cache-control}\n'") -and -not ($text -match '(?i)set-cookie\}'))
    Check '헤더 줄 = CF-Access-Client-Id · CF-Access-Client-Secret 를 $hdr 에만(stdin) · $hdr | curl.exe 한 곳' ($text.Contains('$hdr = @("CF-Access-Client-Id: $cid", "CF-Access-Client-Secret: $csec")') -and $text.Contains("`$out = @(`$hdr | curl.exe")) }
  # 수정 라운드 1(KB-3 · KA-5): T075 acl 삭제 블록 — 허용 목록 = acl 두 경로뿐 · 그 밖의 kv 경로 상수 0 · 삭제 1곳 = kv metadata delete $path · 재타자 Ordinal · 성공 줄 = W-6(op1 안내 0)
  $delShape = { param($ast, $text)
    $kvc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -and ([string]$n.Value).StartsWith('kv/', [StringComparison]::Ordinal) }, $true) | ForEach-Object { [string]$_.Value } | Sort-Object -Unique)
    Check '허용 목록 = kv/dev/dragonfly/acl · kv/prod/dragonfly/acl 정확히 · 그 밖의 kv/ 경로 상수 0(사용자 · admin 경로를 지울 길 0)' ($text.Contains("`$allow = @('kv/dev/dragonfly/acl', 'kv/prod/dragonfly/acl')") -and (SEq ($kvc -join '|') 'kv/dev/dragonfly/acl|kv/prod/dragonfly/acl')) ($kvc -join ' | ')
    $vc = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and [string]::Equals([string]$n.GetCommandName(), 'vault', [StringComparison]::Ordinal) }, $true) | ForEach-Object { Cmd-Text $_ })
    Check '삭제 = vault kv metadata delete $path 1곳(put · patch 0)' (@($vc | Where-Object { $_.Contains(' delete ') }).Count -eq 1 -and @($vc | Where-Object { SEq $_ 'vault kv metadata delete $path' }).Count -eq 1 -and @($vc | Where-Object { $_.Contains(' put ') -or $_.Contains(' patch ') }).Count -eq 0) ($vc -join ' | ')
    Check '재타자 Ordinal 대조 · 성공 줄 = 다음 W-6 · op1 안내 0' ($text.Contains('if (-not (& $eq $again $path))') -and $text.Contains('다음 = W-6(w6-render-dragonfly-acl.ps1') -and -not $text.Contains('op1-seed-dragonfly.ps1 을')) }
  $BStat = @(
    @('ST-O1', 'o1-cf-values.ps1', $BCmdsTool, @(), @(), 0, $false, { param($a, $t) & $tofuShape $a $t
        Check 'INFO 줄에 tofu 실행 파일 경로 · 사용자 홈은 ~ 로(KB2-2)' ($t.Contains('Write-Host "INFO tofu CLI: $tvl · $([string]$tcs[0].CommandType) $tsrc —') -and $t.Contains("`$tsrc = '~' + `$tsrc.Substring(`$HOME.Length)")) }),
    @('ST-O2', 'o2-kv-judge.ps1', (@($BCmdsBase) + @('vault')), @('readSecret'), $VSigRO, 1, $true, $kvContract),
    @('ST-W2', 'w2-kv-seed.ps1', (@($BCmdsBase) + @('vault', 'ConvertTo-Json')), @('stop', 'pickEnv', 'readSecret'), (@($VSigRO) + @('kv put', 'kv patch')), 3, $true, $w2Shape),
    @('ST-O3', 'o3-kv-gate.ps1', (@($BCmdsBase) + @('vault')), @('pickEnv', 'readSecret'), $VSigRO, 2, $true, $kvContract),
    @('ST-O4', 'o4-eso-prod-role.ps1', (@($BCmdsBase) + @('vault')), @('readSecret'), (@('version', 'status -format=json', 'token lookup -format=json', 'read -format=json auth/kubernetes/role/eso-prod', 'policy read eso-prod')), 1, $true, $null),
    @('ST-O5', 'o5-probe-identity-m2m.ps1', (@($BCmdsTool) + @('Read-Host', 'curl.exe')), @('pick', 'readSha'), @(), 2, $false, { param($a, $t) & $tofuShape $a $t; & $curlShape $a $t
        Check '환경 변수 판정에 SSL_CERT_FILE · SSL_CERT_DIR(KB2-2) · CURL_CA_BUNDLE · SSLKEYLOGFILE · HTTP_PROXY · HTTPS_PROXY · ALL_PROXY(대소문자 무관 -contains) — KB-1' ($t.Contains("@('SSL_CERT_FILE', 'SSL_CERT_DIR', 'CURL_CA_BUNDLE', 'SSLKEYLOGFILE', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'TF_WORKSPACE', 'TF_DATA_DIR') -contains `$_.Name"))
        Check 'INFO 줄에 curl · tofu 실행 파일 경로 · 사용자 홈은 ~ 로(KB2-2)' ($t.Contains('Write-Host "INFO curl $($cm.Groups[1].Value).$($cm.Groups[2].Value) · $([string]$ccs[0].CommandType) $csrc · tofu $([string]$tcs[0].CommandType) $tsrc —') -and $t.Contains("return '~' + `$s.Substring(`$HOME.Length)") -and $t.Contains('$tsrc = & $tilde $tcs[0].Source') -and $t.Contains('$csrc = & $tilde $ccs[0].Source')) }),
    @('ST-O6A', 'o6-pre-dragonfly-acl.ps1', (@($BCmdsBase) + @('vault')), @('readSecret'), $VSigRO, 1, $true, $o6Lint),
    @('ST-O6B', 'o6-post-dragonfly-dryrun.ps1', (@($BCmdsBase) + @('vault', 'kubectl', 'Join-Path')), @('pickEnv', 'readSecret'), @('version', 'status -format=json', 'token lookup -format=json', 'kv get -format=json'), 2, $true, $kubectlShape),
    @('ST-WL', 'w6-acl-load.ps1', (@($BCmdsBase) + @('vault', 'kubectl', 'Join-Path')), @('stop', 'pickEnv', 'readSecret'), @('version', 'status -format=json', 'token lookup -format=json', 'kv get -format=json'), 3, $true, $kubectlShape),
    @('ST-DEL', 'w6-acl-delete.ps1', (@($BCmdsBase) + @('vault')), @('askPath', 'readSecret'), (@($VSigRO) + @('kv metadata delete')), 2, $true, $delShape))
  foreach ($s in $BStat) {
    $g = Run-OStatic -Id $s[0] -File $s[1] -Cmds $s[2] -Owners $s[3] -VSigs $s[4] -ReadHosts $s[5] -VaultEnv:([bool]$s[6]) -Extra $s[7]
    $global:BGate[$s[1]] = $g
    if ($g) { Write-Host "관문 FAIL($($s[0])): $g — 그 블록의 런타임 시나리오를 실행하지 않는다" -ForegroundColor Red } }

  # ---- O-1(설계 D11): CF 값 5 — 키별 정규식 · PASS 일 때만 값 · client_id 만 꺼낸다
  $O1S = '--- T075 O-1 Cloudflare 값'
  $o1Ok = @("aud identity-m2m-dev PASS $($AUDV['identity-m2m-dev'])", "aud identity-m2m-prod PASS $($AUDV['identity-m2m-prod'])", "aud admin PASS $($AUDV['admin'])", "cn web-bff-dev PASS $($TOKV['web-bff-dev']['client_id'])", "cn web-bff-prod PASS $($TOKV['web-bff-prod']['client_id'])", 'o1=PASS 5/5')
  Run-OCase 'O1-01' 'O-1 정상: AUD 셋 · Client ID 둘 = PASS 와 값 · o1=PASS 5/5 · client_secret 넷은 어디에도 0 · tofu 호출 = version + output 둘(-chdir = 저장소 infra\cloudflare)' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu } -Summary $O1S `
    -Want $o1Ok -NotWant @('FAIL') -Post {
      Check 'tofu output 호출 2(access_app_aud → service_tokens) · -chdir = 저장소 infra\cloudflare(블록 위치에서 찾음)' ($global:TofuCalls.Count -eq 2 -and (SEq $global:TofuCalls[0].name 'access_app_aud') -and (SEq $global:TofuCalls[1].name 'service_tokens') -and (IEq $global:TofuCalls[0].chdir $INFRA)) "$($global:TofuCalls.Count) · $(if ($global:TofuCalls.Count) { $global:TofuCalls[0].chdir })"
      Check 'tester 토큰 · 다른 AUD(argo 등)의 값은 화면에 0(쓰는 것만 낸다)' (-not $global:LastText.Contains($TOKV['tester-m2m']['client_id']) -and -not $global:LastText.Contains($AUDV['argo'])) }
  $bad = [ordered]@{}; foreach ($k in @($TOKV.Keys)) { $bad[$k] = [ordered]@{ client_id = $TOKV[$k]['client_id']; client_secret = $TOKV[$k]['client_secret'] } }
  $bad['web-bff-dev']['client_id'] = $TOKV['web-bff-dev']['client_secret']
  $script:o1bad = $bad
  Run-OCase 'O1-02' 'O-1 cn 자리에 client_secret(54자 [A-Za-z0-9_-] — 속성을 잘못 고른 경우) → cn web-bff-dev FAIL · 값 미출력 · o1=FAIL 4/5' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu -tok $script:o1bad } -Summary $O1S `
    -Want @('cn web-bff-dev FAIL(꼴이 ^[0-9a-f]{32}\.access$ 가 아니다(값 미출력))', 'o1=FAIL 4/5') -NotWant @('cn web-bff-dev PASS')
  # 리뷰 O5fix-r0 F2: 모의 client_secret 이 54자 꼴이 되자 O1-02 는 더는 cn 자리에 64 hex 를 넣지 않는다 — 옛 64 hex 꼴(research.md :4256 「기존 64자 hex도 유효」)을
  #   cn 자리에 넣는 사례를 따로 둔다(cn 정규식을 64 hex 도 받는 공통 꼴로 넓히는 변이를 잡는다)
  $hx = Hex-Lower 'MOCK-secret-hex64-o1'
  $bad2 = [ordered]@{}; foreach ($k in @($TOKV.Keys)) { $bad2[$k] = [ordered]@{ client_id = $TOKV[$k]['client_id']; client_secret = $TOKV[$k]['client_secret'] } }
  $bad2['web-bff-dev']['client_id'] = $hx
  $script:o1bad2 = $bad2; $script:o1hx = $hx
  Run-OCase 'O1-02b' 'O-1 cn 자리에 64 소문자 hex(옛 client_secret 꼴 — 속성을 잘못 고른 경우) → cn web-bff-dev FAIL · 값 미출력 · o1=FAIL 4/5' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu -tok $script:o1bad2; [void]$global:ExtraSecrets.Add($script:o1hx) } -Summary $O1S `
    -Want @('cn web-bff-dev FAIL(꼴이 ^[0-9a-f]{32}\.access$ 가 아니다(값 미출력))', 'o1=FAIL 4/5') -NotWant @('cn web-bff-dev PASS')
  $aud2 = @{}; foreach ($k in @($AUDV.Keys)) { $aud2[$k] = $AUDV[$k] }; $aud2['admin'] = $AUDV['admin'].ToUpperInvariant()
  $script:o1aud = $aud2
  Run-OCase 'O1-03' 'O-1 AUD 자리에 대문자 hex → aud admin FAIL · 값 미출력' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu -aud $script:o1aud } -Summary $O1S `
    -Want @('aud admin FAIL(꼴이 ^[0-9a-f]{64}$ 가 아니다(값 미출력))', 'o1=FAIL 4/5') -NotWant @($AUDV['admin'].ToUpperInvariant())
  $aud3 = @{}; foreach ($k in @($AUDV.Keys)) { if ($k -cne 'identity-m2m-prod') { $aud3[$k] = $AUDV[$k] } }
  $script:o1aud3 = $aud3
  Run-OCase 'O1-04' 'O-1 AUD 키 누락(identity-m2m-prod) → FAIL(키 없음)' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu -aud $script:o1aud3 } -Summary $O1S -Want @('aud identity-m2m-prod FAIL(키 없음)', 'o1=FAIL 4/5')
  $bad4 = [ordered]@{}; foreach ($k in @($TOKV.Keys)) { $bad4[$k] = [ordered]@{ client_id = $TOKV[$k]['client_id']; client_secret = $TOKV[$k]['client_secret'] } }
  $bad4['web-bff-prod'] = [ordered]@{ client_secret = $TOKV['web-bff-prod']['client_secret'] }
  $script:o1bad4 = $bad4
  Run-OCase 'O1-05' 'O-1 web-bff-prod 객체에 client_id 속성 없음 → FAIL(속성 단언) · client_secret 미출력' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu -tok $script:o1bad4 } -Summary $O1S -Want @('cn web-bff-prod FAIL(client_id 속성이 없거나 문자열이 아니다)', 'o1=FAIL 4/5')
  Run-OCase 'O1-06' 'O-1 service_tokens 출력 실패(exit 1) → cn 둘 FAIL(오류 문구 미출력) · AUD 셋은 PASS' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu; $global:F['tofuFail']['service_tokens'] = 1 } -Summary $O1S `
    -Want @('cn web-bff-dev FAIL(tofu output exit=1(오류 문구는 내지 않는다 — sensitive 출력))', "aud admin PASS $($AUDV['admin'])", 'o1=FAIL 3/5') -NotWant @('No outputs found')
  Run-OCase 'O1-07' 'O-1 모듈 로깅 정책 켜짐(HKLM PowerShellCore) → 아무것도 읽기 전에 중단(tofu 호출 0)' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Setup { Seed-Tofu; $global:Policy[$global:PolicyPaths[0]] = @{ EnableModuleLogging = 1 } } -Expect '모듈 로깅 정책이 켜져 있다' -Summary $O1S `
    -Want @('o1=판정 불가') -Post { Check 'tofu 호출 0' ($global:XArgv.Count -eq 0) }
  Run-OCase 'O1-08' 'O-1 service_tokens 출력이 깨진 JSON(안에 client_secret) → cn 둘 FAIL(해석 실패) · 비밀 노출 0($Error 포함)' 'o1-cf-values.ps1' -Allow @{ tofu = $true } `
    -Setup { Seed-Tofu; $global:TofuOut['service_tokens'] = '{"web-bff-dev":{"client_id":"x","client_secret":"' + $TOKV['web-bff-dev']['client_secret'] + '"' } -Summary $O1S -Want @('cn web-bff-dev FAIL(출력 JSON 을 해석하지 못했다)', 'o1=FAIL 3/5')

  # ---- O-2(설계 D10): 20경로 판정(쓰기 0)
  $O2S = '--- T075 O-2 kv 판정 요약'
  Run-OCase 'O2-01' 'O-2 W-2 전 상태(dev · prod) → 20 JUDGE 줄 · 전부 W-2 전제 OK · dev 10/10 · prod 10/10 · 판정 충족 · 쓰기 0 · 값 0' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod' } -Inputs @($TOK) `
    -Want @("JUDGE $(IaPath 'dev' 'authentik') — live v1 · 키 집합 일치 · client_id=sentinel · client_secret=sentinel · jwks_url=sentinel · issuer=sentinel · api_token=sentinel → W-2 전제 OK(jwks_url · issuer = sentinel → W-2 가 계약 값으로 patch)",
      "JUDGE $(IaPath 'dev' 'webhook') — live v1 · 키 집합 일치 · secret=sentinel → W-2 전제 OK(sentinel → W-2 가 CSPRNG 43자로 덮어쓴다)", "JUDGE $(IaPath 'prod' 'django') — absent(경로 없음) → W-2 전제 OK(absent — W-2 가 만든다)",
      "JUDGE $(IaPath 'dev' 'app') — live v1 · 키 집합 일치 · username=값 있음 · password=값 있음 · url=값 있음 → W-2 전제 OK(기존 경로 — 그대로 둔다)", "JUDGE $(IaPath 'prod' 'store') — live v1 · 키 집합 일치 · store_id=sentinel → W-2 전제 OK(sentinel 그대로 — 면제 · T082)",
      'o2 W-2 전제: dev 10/10 · prod 10/10', '판정: W-2 전제 충족(dev · prod)') -NotWant @('어긋남') `
    -Post { Check 'JUDGE 줄 20(dev 10 · prod 10)' (@([regex]::Matches($global:LastText, '(?m)^JUDGE ')).Count -eq 20) }
  Run-OCase 'O2-02' 'O-2 W-2 뒤 상태 → 전제 OK(건너뜀 갈래) · 20/20' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Setup { Seed-IaDone 'dev'; Seed-IaDone 'prod' } -Inputs @($TOK) `
    -Want @("jwks_url=계약 값 · issuer=계약 값", 'W-2 전제 OK(jwks_url · issuer = 계약 값 — W-2 는 건너뛴다)', 'OK(이미 실값 — W-2 는 건너뛴다 · 바꾸지 않는다)', '규칙 충족(W009 · 64자 base64url — W-2 꼴)', 'dsn=빈 값(Sentry 끔)', 'o2 W-2 전제: dev 10/10 · prod 10/10')
  Run-OCase 'O2-03' 'O-2 dev jwks_url 만 다른 값 · db app 키 누락 · prod sentry dsn 비지 않음 · prod store_id 실값 → 각 어긋남 · 미충족' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Inputs @($TOK) `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'
      Seed-Path (IaPath 'dev' 'authentik') ([ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = 'http://example.invalid/jwks/'; issuer = $SENT; api_token = $SENT })
      Seed-Path (IaPath 'dev' 'app') ([ordered]@{ username = 'dev_identity_admin_app'; password = $IAPW['dev-app'] })
      Seed-Path (IaPath 'prod' 'sentry') ([ordered]@{ dsn = 'https://key@sentry.example.invalid/1' })
      Seed-Path (IaPath 'prod' 'store') ([ordered]@{ store_id = 'store-real-value-01' }) } `
    -Want @('jwks_url=계약 값도 sentinel 도 아님', '어긋남(jwks_url = 계약 값도 sentinel 도 아님 · issuer = sentinel)', '키 집합 불일치(누락 1 · 여분 0)', '어긋남(키 집합 불일치)', '어긋남(dsn = 비지 않은 값(Sentry 켜짐', '어긋남(store_id = 실값(sentinel 아님) — US6 동안 sentinel 그대로 둔다)', 'o2 W-2 전제: dev 8/10 · prod 8/10', '판정: W-2 전제 미충족') -NotWant @('example.invalid', 'store-real-value-01')
  Run-OCase 'O2-04' 'O-2 과도 상태 — metadata 500(dev kafka) · kv get 깨진 JSON(안에 webhook 값 · prod webhook) → 판정 불가 · 어긋남 · 값 노출 0' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Inputs @($TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaDone 'prod'; $global:F['metaError'][(IaPath 'dev' 'kafka')] = 1; $global:F['readGarbage'][(IaPath 'prod' 'webhook')] = 1 } `
    -Want @("JUDGE $(IaPath 'dev' 'kafka') — error — metadata 조회 exit=2 · * context deadline exceeded → W-2 전제 어긋남(error — 판정 불가)", "JUDGE $(IaPath 'prod' 'webhook') — live v2 · kv get 응답을 해석하지 못했다(원문 미출력) → W-2 전제 어긋남(데이터를 읽지 못했다)", 'o2 W-2 전제: dev 9/10 · prod 9/10')
  Run-OCase 'O2-05' 'O-2 시작 전 VAULT_TOKEN → 토큰을 묻지 않고 중단 · 기존 값 그대로' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -PreEnv @{ VAULT_TOKEN = $global:FAKE_PRE_TOKEN } `
    -Setup { [void]$global:ExtraSecrets.Add($global:FAKE_PRE_TOKEN) } -Inputs @($TOK) -Expect 'VAULT_* 환경 변수가 이미 있다: VAULT_TOKEN' -Post { Check '입력 0 · vault 호출 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0) }
  Run-OCase 'O2-06' 'O-2 모듈 로깅(UseWindowsPowerShellPolicySetting=1 + Windows PowerShell HKCU 켜짐) → 아무것도 묻기 전에 중단' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Inputs @($TOK) `
    -Setup { $global:Policy[$global:PolicyPaths[1]] = @{ UseWindowsPowerShellPolicySetting = 1 }; $global:Policy[$global:PolicyPaths[3]] = @{ EnableModuleLogging = 1 } } -Expect '모듈 로깅 정책이 켜져 있다' -Post { Check '입력 0 · vault 호출 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0) }

  # ---- W-2(설계 D10 · CD-9 · VD-T075-11): env 하나씩 · 4경로 쓰기 · patch · CAS · 응답 유실 · 쌍 판정
  $W2S = '--- T075 W-2 kv 쓰기 결과 요약'
  function Check-W2Done { param([string]$ev, [hashtable]$ver = @{ authentik = 2; webhook = 2; django = 1; sentry = 1 })
    $a = KvData (IaPath $ev 'authentik')
    Check "$ev authentik: v$($ver['authentik']) · 키 5 · jwks_url · issuer = 계약 값 · 나머지 셋 sentinel 보존(VD-T075-11)" ((KvCur (IaPath $ev 'authentik')) -eq $ver['authentik'] -and $null -ne $a -and @($a.Keys).Count -eq 5 -and (SEq $a['jwks_url'] $JWKS) -and (SEq $a['issuer'] $ISS) -and (SEq $a['client_id'] $SENT) -and (SEq $a['client_secret'] $SENT) -and (SEq $a['api_token'] $SENT))
    $w = KvData (IaPath $ev 'webhook')
    Check "$ev webhook: v$($ver['webhook']) · {secret} · 43자 base64url · sentinel 아님" ((KvCur (IaPath $ev 'webhook')) -eq $ver['webhook'] -and $null -ne $w -and @($w.Keys).Count -eq 1 -and ([string]$w['secret'] -cmatch '\A[A-Za-z0-9_-]{43}\z') -and -not (SEq $w['secret'] $SENT))
    $d = KvData (IaPath $ev 'django')
    $sk = [string]$d['secret_key']
    Check "$ev django: v$($ver['django']) · {secret_key} · 64자 base64url · W009(50+ · 서로 다른 글자 5+ · django-insecure- 아님)" ((KvCur (IaPath $ev 'django')) -eq $ver['django'] -and $null -ne $d -and @($d.Keys).Count -eq 1 -and ($sk -cmatch '\A[A-Za-z0-9_-]{64}\z') -and [System.Collections.Generic.HashSet[char]]::new([char[]]$sk.ToCharArray()).Count -ge 5 -and -not $sk.StartsWith('django-insecure-'))
    $s = KvData (IaPath $ev 'sentry')
    Check "$ev sentry: v$($ver['sentry']) · {dsn: 빈 값}" ((KvCur (IaPath $ev 'sentry')) -eq $ver['sentry'] -and $null -ne $s -and @($s.Keys).Count -eq 1 -and (SEq $s['dsn'] '')) }
  Run-OCase 'W2-01' 'W-2 dev 처음(authentik · webhook sentinel v1 · django · sentry 없음) → 4경로 쓰기(patch -cas=1 · put -cas=1 · put -cas=0 ×2) · 되읽기 · 메타 · 요약 · 판정 준비 완료 · 값 0' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod' } -Inputs @('dev', $TOK, 'seed') `
    -Want @("PLAN $(IaPath 'dev' 'authentik') — jwks_url · issuer = sentinel → 계약 값 patch 예정(나머지 3키 보존) · 지금 v1", "OK   $(IaPath 'dev' 'authentik') v2 — patch · 되읽기 일치(jwks_url·issuer = 계약 값 · 보존 client_id·client_secret·api_token)",
      "OK   $(IaPath 'dev' 'webhook') v2 — 덮어씀 · 되읽기 해시 일치(secret)", "OK   $(IaPath 'dev' 'django') v1 — 생성 · 되읽기 해시 일치(secret_key)", "OK   $(IaPath 'dev' 'sentry') v1 — 생성 · 되읽기 해시 일치(dsn)",
      '판정 결과: 쓰기 예정 4 · 건너뜀 0 · 중단 0', '이 실행이 kv 에 쓴 경로: 4건(검증 완료 4 · 응답 유실 뒤 재판정으로 검증 완료 0 · 기록 후 검증 실패 0) · 결과 미확인 0 · 건너뜀 0 · 중단 0 · 미실행 0', '판정: dev 4경로 준비 완료') -NotWant @('STOP ') `
    -Post {
      Check-W2Done 'dev'
      foreach ($k in $IAKINDS) { if ($k -cnotin @('authentik', 'webhook', 'django', 'sentry')) { Check "dev $k 그대로(v1)" ((KvCur (IaPath 'dev' $k)) -eq 1) } }
      Check 'prod 경로 쓰기 0(이 실행은 dev 만)' (@($global:PutCalls | Where-Object { $_.path.StartsWith('kv/prod/') }).Count -eq 0 -and @($global:PatchCalls | Where-Object { $_.path.StartsWith('kv/prod/') }).Count -eq 0)
      Check 'patch 1회 = authentik · -cas=1 · 인자 = issuer=<계약> jwks_url=<계약>(argv 허용 — 비밀 아님)' ($global:PatchCalls.Count -eq 1 -and $global:PatchCalls[0].cas -eq 1 -and (SEq ($global:PatchCalls[0].pairs -join ' ') "issuer=$ISS jwks_url=$JWKS"))
      Check 'put 3회 = webhook(-cas=1) → django(-cas=0) → sentry(-cas=0) · 전부 stdin' ($global:PutCalls.Count -eq 3 -and (SEq $global:PutCalls[0].path (IaPath 'dev' 'webhook')) -and $global:PutCalls[0].cas -eq 1 -and $global:PutCalls[1].cas -eq 0 -and $global:PutCalls[2].cas -eq 0 -and @($global:PutCalls | Where-Object { -not $_.stdin }).Count -eq 0)
      Check '입력 3(env · root 토큰 보안 입력 · seed) · env 입력이 토큰보다 먼저' ($global:ReadLog.Count -eq 3 -and $global:ReadLog[0].masked -and $global:ReadLog[1].secure -and $global:ReadLog[2].masked)
      Check 'put 본문(JSON) 3 · 날 LF 0 · 키 = secret / secret_key / dsn' ((SEq (@($global:PutBodies | ForEach-Object { (@(($_ | ConvertFrom-Json -AsHashtable).Keys)) -join ',' }) -join '|') 'secret|secret_key|dsn') -and @($global:PutBodies | Where-Object { $_.Contains("`n") }).Count -eq 0) }
  Run-OCase 'W2-02' 'W-2 dev 재실행(W2-01 뒤 상태) → 4 SKIP · 쓰기 0 · seed 정지점 없음 · 회전 아님' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod' } -Inputs @('dev', $TOK) `
    -Want @("SKIP $(IaPath 'dev' 'authentik') — 키 5 · jwks_url · issuer = 계약 값(이미 썼다)", "SKIP $(IaPath 'dev' 'webhook') — secret = 43자 base64url 실값(바꾸지 않는다 — 회전이 아니다)", 'INFO 쓸 경로 없음 — dev 4경로 모두 이미 쓴 상태', '판정: dev 4경로 준비 완료') `
    -Post { Check '쓰기 0' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0); Check '입력 2(seed 없음)' ($global:ReadLog.Count -eq 2) }
  Run-OCase 'W2-03' 'W-2 prod 를 dev 보다 먼저 → dev 두 값이 없어 STOP(dev 먼저) · 쓰기 0' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod' } -Inputs @('prod', $TOK, 'seed') -Expect '판정 단계에서 중단' `
    -Want @("STOP kv/dev/authentik/webhooks/identity-admin — prod 차례인데 dev 의 secret 값이 W-2 꼴로 있지 않다(live) — dev 먼저", "STOP kv/dev/django/identity-admin — prod 차례인데 dev 의 secret_key 값이 W-2 꼴로 있지 않다(absent)", '판정: 미완') `
    -Post { Check '쓰기 0 · seed 정지점 전 중단(입력 2)' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0 -and $global:ReadLog.Count -eq 2) }
  Run-OCase 'W2-04' 'W-2 prod(dev 끝난 뒤) → 4경로 쓰기 · 새 webhook · secret_key 는 dev 값과 다르다(쌍 판정) · dev 값 불변' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod' } -Inputs @('prod', $TOK, 'seed') `
    -Want @("OK   $(IaPath 'prod' 'authentik') v2 — patch", "OK   $(IaPath 'prod' 'sentry') v1 — 생성", '판정: prod 4경로 준비 완료') -NotWant @('STOP ') `
    -Post {
      Check-W2Done 'prod'
      Check 'prod webhook · secret_key ≠ dev(Ordinal)' (-not (SEq (KvData (IaPath 'prod' 'webhook'))['secret'] $IAPW['dev-wh']) -and -not (SEq (KvData (IaPath 'prod' 'django'))['secret_key'] $IAPW['dev-sk']))
      Check 'dev 값 불변' ((SEq (KvData (IaPath 'dev' 'webhook'))['secret'] $IAPW['dev-wh']) -and (KvCur (IaPath 'dev' 'webhook')) -eq 2) }
  foreach ($c in @(@('W2-05', 'authentik jwks_url · issuer 가 섞였다(jwks_url 계약 · issuer sentinel)', { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'authentik') ([ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = $JWKS; issuer = $SENT; api_token = $SENT }) }, "STOP $(IaPath 'dev' 'authentik') — live-mismatch: jwks_url · issuer 가 둘 다 sentinel 도 둘 다 계약 값도 아니다"),
      @('W2-06', 'webhook 경로 없음(T044 sentinel 사라짐)', { Seed-IaBase 'dev'; Seed-IaBase 'prod'; [void]$global:Kv.Remove((IaPath 'dev' 'webhook')) }, "STOP $(IaPath 'dev' 'webhook') — absent — T044 sentinel 경로가 없다"),
      @('W2-07', 'sentry dsn 이 비지 않았다', { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'sentry') ([ordered]@{ dsn = 'https://key@sentry.example.invalid/1' }) }, "STOP $(IaPath 'dev' 'sentry') — live-mismatch: dsn 이 빈 값이 아니다"),
      @('W2-08', 'django secret_key 가 이 블록 꼴이 아니다(django-insecure- 접두 · 70자)', { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'django') ([ordered]@{ secret_key = ('django-insecure-' + (MockStr 'insecure' 54)) }) }, "STOP $(IaPath 'dev' 'django') — live-mismatch: secret_key 가 이 블록의 꼴"),
      @('W2-09', 'webhook 에 끝 줄바꿈이 든 값', { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = ($IAPW['dev-wh'] + "`n") }) }, "STOP $(IaPath 'dev' 'webhook') — live-mismatch: secret 이 sentinel 도 43자 base64url 도 아니다"),
      @('W2-10', '일시 403(metadata 조회 — dev django · 판정 불가 · fail-closed)', { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['metaError'][(IaPath 'dev' 'django')] = 1 }, "STOP $(IaPath 'dev' 'django') — error — metadata 조회 exit=2"),
      @('W2-11', 'dev webhook 실값이 prod 의 값과 같다(쌍 판정)', { Seed-IaDone 'prod'; Seed-IaBase 'dev'; Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = $IAPW['prod-wh'] }) 2 }, "STOP $(IaPath 'dev' 'webhook') — secret 이 prod 의 것과 같다 — dev ≠ prod 이어야 한다"))) {
    $script:w2set = $c[2]
    Run-OCase $c[0] "W-2 가드: $($c[1]) → 판정 STOP · 쓰기 0 · 값 미출력" 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { & $script:w2set } -Inputs @('dev', $TOK, 'seed') -Expect '판정 단계에서 중단' `
      -Want @($c[3], '판정: 미완') -NotWant @('example.invalid') -Post { Check '쓰기 0 · seed 정지점 전(입력 2)' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0 -and $global:ReadLog.Count -eq 2) } }
  Run-OCase 'W2-12' 'W-2 seed 대신 다른 단어 → 쓰기 0 · 요약 미실행(쓰기 확인 정지점)' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod' } -Inputs @('dev', $TOK, 'SEED') -Expect '정지점에서 중단' `
    -Want @('미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)') -Post { Check '쓰기 0' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0) }
  Run-OCase 'W2-13' 'W-2 env 입력이 dev · prod 가 아님(Dev) → 토큰을 묻기 전 중단 · vault 호출 = 도달 확인뿐' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { Seed-IaBase 'dev' } -Inputs @('Dev', $TOK) -Expect '정지점에서 중단: env 선택' `
    -Post { Check '보안 입력 0(토큰을 묻지 않았다)' (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0) }
  Run-OCase 'W2-14' 'W-2 patch 응답 유실(서버 커밋 · CLI exit 2) → 재판정 v2 · 되읽기 일치 = 기록됨(응답 유실 — 이 실행의 값) · 다음 경로 계속 · 4경로 완료' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['patchLost'][(IaPath 'dev' 'authentik')] = 1 } -Inputs @('dev', $TOK, 'seed') `
    -Want @("OK   $(IaPath 'dev' 'authentik') v2 — 기록됨(응답 유실 — 이 실행의 값 · 쓰기 exit=2 뒤 재판정)", '응답 유실 뒤 재판정으로 검증 완료 1', '판정: dev 4경로 준비 완료') -NotWant @('STOP ') -Post { Check-W2Done 'dev'; Check 'patch 1회(다시 보내지 않았다)' ($global:PatchCalls.Count -eq 1) }
  Run-OCase 'W2-15' 'W-2 put 응답 유실(django — 서버 커밋 · CLI exit 2 · 자기 CAS 충돌) → 재판정 live v1 · 해시 일치 = 기록됨(응답 유실)' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['putLost'][(IaPath 'dev' 'django')] = 1 } -Inputs @('dev', $TOK, 'seed') `
    -Want @("OK   $(IaPath 'dev' 'django') v1 — 기록됨(응답 유실 — 이 실행의 값", '판정: dev 4경로 준비 완료') -Post { Check-W2Done 'dev' }
  Run-OCase 'W2-16' 'W-2 put 거부(webhook · 권한 403 · 경로 그대로 v1) → 재판정 current_version 그대로 = 쓰지 않았다 · STOP · 뒤 경로 미실행 · authentik 은 이미 v2' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['putFail'][(IaPath 'dev' 'webhook')] = 2 } -Inputs @('dev', $TOK, 'seed') -Expect '쓰기 거부' `
    -Want @("STOP $(IaPath 'dev' 'webhook') — 쓰기 거부(exit=2) · 재판정 current_version 그대로 = 쓰지 않았다", '중단(쓰기 거부 exit=2 — 재판정 current_version 그대로 · 쓰지 않았다)', '미실행(앞 경로에서 중단 — 쓰지 않았다)', '판정: 미완') `
    -Post { Check 'authentik v2 · webhook v1 sentinel 그대로 · django · sentry 없음' ((KvCur (IaPath 'dev' 'authentik')) -eq 2 -and (KvCur (IaPath 'dev' 'webhook')) -eq 1 -and (SEq (KvData (IaPath 'dev' 'webhook'))['secret'] $SENT) -and -not $global:Kv.ContainsKey((IaPath 'dev' 'django'))) }
  Run-OCase 'W2-17' 'W-2 patch 가 다른 키를 바꿨다(client_id — 저장 변형) → 되읽기 보존 대조 실패 STOP(해시 불일치 client_id) · 뒤 경로 미실행' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['patchTamper'][(IaPath 'dev' 'authentik')] = 1; [void]$global:ExtraSecrets.Add('MOCK-tampered-client-id') } -Inputs @('dev', $TOK, 'seed') -Expect '되읽기 불일치' `
    -Want @("STOP $(IaPath 'dev' 'authentik') — 되읽기 불일치(해시 불일치(client_id)", '판정: 미완') -Post { Check '뒤 경로 put 0' ($global:PutCalls.Count -eq 0) }
  Run-OCase 'W2-18' 'W-2 저장 때 webhook 값 변형(tamper) → 되읽기 해시 불일치 STOP · 뒤 경로 미실행' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['tamper'][(IaPath 'dev' 'webhook')] = 'extraKey' } -Inputs @('dev', $TOK, 'seed') -Expect '되읽기 불일치' `
    -Want @("STOP $(IaPath 'dev' 'webhook') — 되읽기 불일치(키 집합 불일치(누락: 없음 · 여분 1개)", '판정: 미완') -Post { Check 'django · sentry 없음' (-not $global:Kv.ContainsKey((IaPath 'dev' 'django'))) }
  Run-OCase 'W2-19' 'W-2 쓰기 뒤 메타데이터가 current_version+1 이 아님(cv2 — 다른 기록자) → 메타데이터 확인 실패 STOP' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['postMeta'][(IaPath 'dev' 'django')] = 'cv2' } -Inputs @('dev', $TOK, 'seed') -Expect '메타데이터 확인 실패' `
    -Want @("STOP $(IaPath 'dev' 'django') — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(live · current_version=2", '기록됨 — 메타데이터 확인 실패') -Post { Check 'sentry 미실행' (-not $global:Kv.ContainsKey((IaPath 'dev' 'sentry'))) }
  Run-OCase 'W2-20' 'W-2 put 도중 중단(django — 서버 커밋 · Ctrl+C 대용) → 요약 = 결과 미확인 · 재실행 안내' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['putInterrupt'][(IaPath 'dev' 'django')] = 1 } -Inputs @('dev', $TOK, 'seed') -Expect '모의 중단' `
    -Want @('결과 미확인(쓰기 진행 중 중단', '결과 미확인 1', '지우지 말고 O-2 로 본 뒤 재실행한다', '판정: 미완')
  Run-OCase 'W2-21' 'W-2 재실행 복구: W2-20 뒤 상태(django v1 = 그 실행의 값) → django SKIP(이미 썼다) · sentry 만 쓰기' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'
      Seed-Path (IaPath 'dev' 'authentik') ([ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = $JWKS; issuer = $ISS; api_token = $SENT }) 2
      Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = $IAPW['dev-wh'] }) 2
      Seed-Path (IaPath 'dev' 'django') ([ordered]@{ secret_key = $IAPW['dev-sk'] }) } -Inputs @('dev', $TOK, 'seed') `
    -Want @("SKIP $(IaPath 'dev' 'django') — secret_key = 64자 base64url · W009 충족(이미 썼다)", "OK   $(IaPath 'dev' 'sentry') v1 — 생성", '판정: dev 4경로 준비 완료') -Post { Check 'put 1회(sentry)' ($global:PutCalls.Count -eq 1) }
  Run-OCase 'W2-22' 'W-2 클립보드 기록 켜짐 → 아무것도 묻기 전에 중단' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { Seed-IaBase 'dev'; $global:ClipHistory = 1 } -Inputs @('dev', $TOK, 'seed') -Expect '클립보드 기록이 켜져 있음' `
    -Post { Check '입력 0 · vault 호출 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0) }
  # CAS 충돌(진짜 — 다른 기록자): 판정 뒤 · 쓰기 앞에 다른 기록자가 그 경로를 썼다 → 쓰기 exit 2(CAS 문구 — 응답 유실과 같은 문구) → 재판정 v(cv+1) 인데 되읽기 값이 이 실행의 것과 다르다 → STOP(덮어쓰기 0)
  $raceWh = MockStr 'race-webhook' 43
  $script:raceWh = $raceWh
  Run-OCase 'W2-23' 'W-2 put CAS 충돌(webhook — 다른 기록자가 판정 뒤 v2 를 썼다) → 재판정 v2 · 되읽기 다른 값 = CAS 충돌 STOP · 다른 기록자의 값 그대로 · 뒤 경로 미실행' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:RaceData[(IaPath 'dev' 'webhook')] = [ordered]@{ secret = $script:raceWh }; $global:F['putRace'][(IaPath 'dev' 'webhook')] = 1 } -Inputs @('dev', $TOK, 'seed') -Expect 'CAS 충돌' `
    -Want @("STOP $(IaPath 'dev' 'webhook') — 쓰기 거부(exit=2) · CAS 충돌(다른 값 — 해시 불일치(secret) · 값 · 해시는 출력하지 않는다): kv 의 v2 은 다른 기록자의 값이다", '중단(쓰기 거부 exit=2 — 재판정 v2 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)', '판정: 미완') -NotWant @('기록됨(응답 유실') `
    -Post {
      Check '하네스 자체: 다른 기록자의 쓰기가 이 put 의 CAS 판정 앞에 일어났다(put 호출 안 — 이벤트 put 바로 다음이 race)' ((Ev-Index "vault:put:$(IaPath 'dev' 'webhook')") -ge 0 -and (Ev-Index "race:$(IaPath 'dev' 'webhook')") -eq (Ev-Index "vault:put:$(IaPath 'dev' 'webhook')") + 1)
      Check 'webhook = 다른 기록자의 값(v2 · 덮어쓰지 않았다) · authentik v2(앞 경로는 썼다) · django · sentry 없음' ((KvCur (IaPath 'dev' 'webhook')) -eq 2 -and (SEq (KvData (IaPath 'dev' 'webhook'))['secret'] $script:raceWh) -and (KvCur (IaPath 'dev' 'authentik')) -eq 2 -and -not $global:Kv.ContainsKey((IaPath 'dev' 'django')) -and -not $global:Kv.ContainsKey((IaPath 'dev' 'sentry')))
      Check 'put 1회(다시 보내지 않았다)' ($global:PutCalls.Count -eq 1) }
  Run-OCase 'W2-24' 'W-2 patch CAS 충돌(authentik — 다른 기록자가 issuer 를 다른 값으로 v2) → 재판정 v2 · 되읽기 issuer 불일치 = CAS 충돌 STOP · 쓰기 1(patch) 뒤 중단' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'
      $global:RaceData[(IaPath 'dev' 'authentik')] = [ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = $JWKS; issuer = 'https://auth.example.invalid/application/o/other/'; api_token = $SENT }
      $global:F['patchRace'][(IaPath 'dev' 'authentik')] = 1 } -Inputs @('dev', $TOK, 'seed') -Expect 'CAS 충돌' `
    -Want @("STOP $(IaPath 'dev' 'authentik') — 쓰기 거부(exit=2) · CAS 충돌(다른 값 — 해시 불일치(issuer) · 값 · 해시는 출력하지 않는다)", '판정: 미완') -NotWant @('example.invalid') `
    -Post { Check 'authentik = 다른 기록자의 v2 그대로 · webhook v1 sentinel(뒤 경로 미실행) · put 0' ((KvCur (IaPath 'dev' 'authentik')) -eq 2 -and (SEq (KvData (IaPath 'dev' 'authentik'))['issuer'] 'https://auth.example.invalid/application/o/other/') -and (KvCur (IaPath 'dev' 'webhook')) -eq 1 -and $global:PutCalls.Count -eq 0) }

  # ---- O-3(설계 D10 — 게이트 1 키 단위): dev 21 · prod 23
  $O3S = '--- T075 O-3 게이트 1'
  Run-OCase 'O3-01' 'O-3 dev(W-2 dev 뒤) → PASS 21 줄 · gate=PASS 21/21 · 값 0' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod' } -Inputs @('dev', $TOK) `
    -Want @('PASS authentik jwks_url = 계약 값(글자까지)', 'PASS webhooks secret: sentinel 아님 · 정확히 43자', 'PASS 면제 셋 · client_id · client_secret 밖의 PLACEHOLDER- 0(10경로 전체)', 'gate=PASS 21/21') -NotWant @('FAIL ')
  Run-OCase 'O3-02' 'O-3 dev 를 W-2 전에 → FAIL(jwks_url · issuer · webhook sentinel · django · sentry 없음) · gate=FAIL' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod' } -Inputs @('dev', $TOK) `
    -Want @('FAIL authentik jwks_url = 계약 값(글자까지) — FAIL(sentinel 그대로(W-2 미실행))', 'FAIL webhooks secret: sentinel 아님 · 정확히 43자 · ^[A-Za-z0-9_-]{43}$ · 끝 줄바꿈 없음 · 서로 다른 글자 16 이상 — FAIL(sentinel 그대로(W-2 미실행))', "FAIL django 키 집합 = secret_key($(IaPath 'dev' 'django')) — FAIL(읽지 못했다 — absent)", "FAIL sentry 키 집합 = dsn($(IaPath 'dev' 'sentry')) — FAIL(읽지 못했다 — absent)",
      'FAIL sentry dsn = 빈 값(Sentry 끔 — 실값은 T100) — FAIL(키 집합 판정 실패)', 'FAIL 면제 셋 · client_id · client_secret 밖의 PLACEHOLDER- 0(10경로 전체) — FAIL(읽지 못한 경로 2(django·sentry) — 판정 불가)', 'gate=FAIL 13/21') `
    -Post { Check 'FAIL 줄 8 · PASS 줄 13(합 21 — 게이트 검사 수)' (@([regex]::Matches($global:LastText, '(?m)^FAIL ')).Count -eq 8 -and @([regex]::Matches($global:LastText, '(?m)^PASS ')).Count -eq 13) }
  Run-OCase 'O3-03' 'O-3 prod(W-2 dev · prod 뒤) → dev 해시 ≠ prod 해시 둘 포함 gate=PASS 23/23' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Setup { Seed-IaDone 'dev'; Seed-IaDone 'prod' } -Inputs @('prod', $TOK) `
    -Want @('PASS webhooks secret: dev 해시 ≠ prod 해시', 'PASS django secret_key: dev 해시 ≠ prod 해시', 'gate=PASS 23/23') -NotWant @('FAIL ')
  Run-OCase 'O3-04' 'O-3 prod — webhook 이 dev 와 같다 → FAIL(dev 와 prod 가 같다) · gate=FAIL 22/23' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Setup { Seed-IaDone 'dev'; Seed-IaDone 'prod'; Seed-Path (IaPath 'prod' 'webhook') ([ordered]@{ secret = $IAPW['dev-wh'] }) 2 } -Inputs @('prod', $TOK) `
    -Want @('FAIL webhooks secret: dev 해시 ≠ prod 해시 — FAIL(dev 와 prod 가 같다(값 · 해시 미출력))', 'gate=FAIL 22/23')
  Run-OCase 'O3-05' 'O-3 dev — 면제 밖 PLACEHOLDER-(kafka password 자리값) · api_token 실값 · secret_key django-insecure- · webhook 끝 줄바꿈 → 각 FAIL · 위치(경로:키)만' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Inputs @('dev', $TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'
      Seed-Path (IaPath 'dev' 'kafka') ([ordered]@{ password = 'PLACEHOLDER-kafka-not-seeded' })
      Seed-Path (IaPath 'dev' 'authentik') ([ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = $JWKS; issuer = $ISS; api_token = (MockStr 'api-token-real' 40) }) 2
      Seed-Path (IaPath 'dev' 'django') ([ordered]@{ secret_key = ('django-insecure-' + (MockStr 'sk-insecure' 50)) })
      Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = ($IAPW['dev-wh'] + "`n") }) 2 } `
    -Want @("FAIL 면제 셋 · client_id · client_secret 밖의 PLACEHOLDER- 0(10경로 전체) — FAIL(1건 — $(IaPath 'dev' 'kafka'):password)", 'FAIL authentik api_token = sentinel(면제 — JT_PLACEHOLDER_EXEMPT) — FAIL(sentinel 이 아니다', 'FAIL django secret_key: 50자 이상 · 서로 다른 글자 5 이상 · django-insecure- 접두 아님(W009) — FAIL(django-insecure- 접두)', 'FAIL webhooks secret: sentinel 아님 · 정확히 43자 · ^[A-Za-z0-9_-]{43}$ · 끝 줄바꿈 없음 · 서로 다른 글자 16 이상 — FAIL(줄바꿈이 있다)', 'gate=FAIL 17/21') -NotWant @('PLACEHOLDER-kafka-not-seeded')
  Run-OCase 'O3-06' 'O-3 dev — 한 경로 metadata 500(일시 — dev dragonfly) → 그 키 집합 FAIL · PLACEHOLDER 판정 불가 FAIL · gate=FAIL' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'; $global:F['metaError'][(IaPath 'dev' 'dragonfly')] = 1 } -Inputs @('dev', $TOK) `
    -Want @("FAIL dragonfly 키 집합 = password · url($(IaPath 'dev' 'dragonfly')) — FAIL(읽지 못했다 — error", '판정 불가', 'gate=FAIL 19/21')
  Run-OCase 'O3-07' 'O-3 env 입력이 다른 단어 → 판정 불가(토큰을 묻기 전)' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Setup { Seed-IaDone 'dev' } -Inputs @('stage', $TOK) -Expect '정지점에서 중단: env 선택' -Want @('gate=판정 불가')
  # 수정 라운드 1(KA-1 · KB-9): W009 의 길이 · 서로 다른 글자 · dsn 빈 값 · prod django dev ≠ prod · 웹훅 서로 다른 글자 하한 — 조건마다 사례 하나(리뷰 변이 MX1 · MX1b · MX2 · MX3 이 잡힌다)
  $sk49 = (MockStr 'sk49' 49)
  $script:sk49 = $sk49
  Run-OCase 'O3-08' 'O-3 dev — secret_key 49자(base64url · 서로 다른 글자 충분) → W009 FAIL(길이 49) · gate=FAIL 20/21' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Inputs @('dev', $TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'django') ([ordered]@{ secret_key = $script:sk49 }) } `
    -Want @('FAIL django secret_key: 50자 이상 · 서로 다른 글자 5 이상 · django-insecure- 접두 아님(W009) — FAIL(길이 49(50 이상 기대))', 'gate=FAIL 20/21')
  $sk2 = ('aB' * 32)
  $script:sk2 = $sk2
  Run-OCase 'O3-09' 'O-3 dev — secret_key 64자인데 글자 둘(aB 반복) → W009 FAIL(서로 다른 글자 5 미만) · gate=FAIL 20/21' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Inputs @('dev', $TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'django') ([ordered]@{ secret_key = $script:sk2 }); [void]$global:ExtraSecrets.Add($script:sk2) } `
    -Want @('FAIL django secret_key: 50자 이상 · 서로 다른 글자 5 이상 · django-insecure- 접두 아님(W009) — FAIL(서로 다른 글자 5 미만)', 'gate=FAIL 20/21')
  Run-OCase 'O3-10' 'O-3 dev — sentry dsn 이 비지 않았다(키 집합은 맞다) → dsn FAIL · gate=FAIL 20/21' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Inputs @('dev', $TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'sentry') ([ordered]@{ dsn = 'https://k@sentry.example.invalid/1' }) } `
    -Want @('PASS sentry 키 집합 = dsn', 'FAIL sentry dsn = 빈 값(Sentry 끔 — 실값은 T100) — FAIL(빈 값이 아니다(값 미출력))', 'gate=FAIL 20/21') -NotWant @('example.invalid')
  Run-OCase 'O3-11' 'O-3 prod — django secret_key 가 dev 와 같다(웹훅은 다르다) → dev 해시 ≠ prod 해시 FAIL · gate=FAIL 22/23' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Inputs @('prod', $TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaDone 'prod'; Seed-Path (IaPath 'prod' 'django') ([ordered]@{ secret_key = $IAPW['dev-sk'] }) } `
    -Want @('PASS webhooks secret: dev 해시 ≠ prod 해시', 'FAIL django secret_key: dev 해시 ≠ prod 해시 — FAIL(dev 와 prod 가 같다(값 · 해시 미출력))', 'gate=FAIL 22/23')
  $wlo = ('Ab' * 21) + 'C'
  $script:wlo = $wlo
  Run-OCase 'O3-12' 'O-3 dev — 웹훅 secret 43자 base64url 인데 서로 다른 글자 3 → FAIL(서로 다른 글자 16 미만 · KB-9) · gate=FAIL 20/21' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Inputs @('dev', $TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = $script:wlo }) 2; [void]$global:ExtraSecrets.Add($script:wlo) } `
    -Want @('FAIL webhooks secret: sentinel 아님 · 정확히 43자 · ^[A-Za-z0-9_-]{43}$ · 끝 줄바꿈 없음 · 서로 다른 글자 16 이상 — FAIL(서로 다른 글자 16 미만(CSPRNG 값이 아니다 · 값 미출력))', 'gate=FAIL 20/21')
  Run-OCase 'O3-P1' 'O-3 dev 붙여넣기 모드(KB-5) — 파일 실행과 같은 결과 · 블록 밖 범위에 새 변수 0' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Paste -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod' } -Inputs @('dev', $TOK) `
    -Want @('gate=PASS 21/21') -NotWant @('FAIL ')

  # ---- O-4(설계 CD-27): eso-prod role 투영 + 정책
  $O4S = '--- T075 O-4 eso-prod role'
  # Vault 2.0 kubernetes auth role 읽기 응답의 필드(roles.tf 가 정한 값 + 기본값 — 수정 라운드 1 · KB-6)
  $ROLEOK = [ordered]@{ alias_name_source = 'serviceaccount_uid'; audience = 'vault'; bound_service_account_names = @('eso-prod'); bound_service_account_namespace_selector = ''; bound_service_account_namespaces = @('external-secrets')
    token_bound_cidrs = @(); token_explicit_max_ttl = 0; token_max_ttl = 14400; token_no_default_policy = $false; token_num_uses = 0; token_period = 0; token_policies = @('eso-prod'); token_ttl = 3600; token_type = 'service' }
  function Role-With { param([hashtable]$set = @{}, [string[]]$drop = @()) $r = [ordered]@{}; foreach ($k in @($ROLEOK.Keys)) { if (-not ($drop -ccontains $k)) { $r[$k] = $ROLEOK[$k] } }; foreach ($k in @($set.Keys)) { $r[$k] = $set[$k] }; $r }
  $POLOK = @('path "kv/data/prod/*" { capabilities = ["read"] }', 'path "kv/metadata/prod/*" { capabilities = ["read"] }', '')
  Run-OCase 'O4-01' 'O-4 선언과 같다 → PASS 14 · o4=PASS 14/14 · 값(비밀 아님) 출력 · 쓰기 0' 'o4-eso-prod-role.ps1' -Allow @{ read = $true } -Vault -ReadOnly -Summary $O4S -Setup { $global:Role = $ROLEOK; $global:PolicyText = $POLOK } -Inputs @($TOK) `
    -Want @('PASS bound_service_account_names = [eso-prod]', 'PASS bound_service_account_namespaces = [external-secrets]', 'PASS audience = vault', 'PASS token_ttl = 3600', 'PASS token_max_ttl = 14400', 'PASS policy eso-prod = path "kv/data/prod/*" { capabilities = ["read"] } / path "kv/metadata/prod/*" { capabilities = ["read"] }',
      'PASS token_type = service', 'PASS token_period = 0', 'PASS token_explicit_max_ttl = 0', 'PASS token_num_uses = 0', 'PASS token_bound_cidrs = []', 'PASS token_no_default_policy = False', 'PASS bound_service_account_namespace_selector = ""', 'o4=PASS 14/14')
  $script:o4r2 = Role-With @{ token_ttl = 2764800; bound_service_account_namespaces = @('external-secrets', 'jt-prod') }
  Run-OCase 'O4-02' 'O-4 token_ttl 32일 · 네임스페이스 둘 → FAIL 둘 · o4=FAIL 12/14' 'o4-eso-prod-role.ps1' -Allow @{ read = $true } -Vault -ReadOnly -Summary $O4S -Setup { $global:Role = $script:o4r2; $global:PolicyText = $POLOK } -Inputs @($TOK) `
    -Want @('FAIL token_ttl = 2764800(기대 3600)', 'FAIL bound_service_account_namespaces = [external-secrets, jt-prod](기대 [external-secrets])', 'o4=FAIL 12/14')
  Run-OCase 'O4-03' 'O-4 정책에 줄이 하나 더(kv/data/dev/*) → policy FAIL' 'o4-eso-prod-role.ps1' -Allow @{ read = $true } -Vault -ReadOnly -Summary $O4S -Setup { $global:Role = $ROLEOK; $global:PolicyText = @($POLOK) + @('path "kv/data/dev/*" { capabilities = ["read"] }') } -Inputs @($TOK) -Want @('FAIL policy eso-prod', 'o4=FAIL 13/14')
  Run-OCase 'O4-04' 'O-4 role 조회 500 → 판정 불가(중단)' 'o4-eso-prod-role.ps1' -Allow @{ read = $true } -Vault -ReadOnly -Summary $O4S -Setup { $global:F['roleFail'] = $true } -Inputs @($TOK) -Expect 'role 조회 실패' -Want @('o4=판정 불가')
  $script:o4r5 = Role-With -drop @('audience')
  Run-OCase 'O4-05' 'O-4 audience 없음 → FAIL' 'o4-eso-prod-role.ps1' -Allow @{ read = $true } -Vault -ReadOnly -Summary $O4S -Setup { $global:Role = $script:o4r5; $global:PolicyText = $POLOK } -Inputs @($TOK) -Want @('FAIL audience = (기대 vault)', 'o4=FAIL 13/14')
  # 수정 라운드 1(KB-6): 더한 필드마다 어긋난 값 → 그 줄 FAIL(값은 비밀 아님)
  foreach ($c in @(@('O4-06', 'token_type = default', @{ token_type = 'default' }, @(), 'FAIL token_type = default(기대 service)'),
      @('O4-07', 'token_period = 86400(주기 토큰)', @{ token_period = 86400 }, @(), 'FAIL token_period = 86400(기대 0)'),
      @('O4-08', 'token_bound_cidrs 있음', @{ token_bound_cidrs = @('10.0.0.0/8') }, @(), 'FAIL token_bound_cidrs = [10.0.0.0/8](기대 [])'),
      @('O4-09', 'namespace selector 있음', @{ bound_service_account_namespace_selector = '{"matchLabels":{"a":"b"}}' }, @(), 'FAIL bound_service_account_namespace_selector = "{"matchLabels":{"a":"b"}}"(기대 "")'),
      @('O4-10', 'token_no_default_policy 키 없음 · token_num_uses 키 없음', @{}, @('token_no_default_policy', 'token_num_uses'), 'FAIL token_no_default_policy = (기대 False)'))) {
    $script:o4rx = Role-With $c[2] $c[3]
    Run-OCase $c[0] "O-4 $($c[1]) → FAIL(KB-6)" 'o4-eso-prod-role.ps1' -Allow @{ read = $true } -Vault -ReadOnly -Summary $O4S -Setup { $global:Role = $script:o4rx; $global:PolicyText = $POLOK } -Inputs @($TOK) -Want @($c[4], 'o4=FAIL') -NotWant @('o4=PASS') }
  $script:o4cc = Role-With @{ audience = ('vault' + [char]27 + ']52;c;QUJD' + [char]7) }
  Run-OCase 'CC-O4' 'O-4 audience 에 터미널 제어열(OSC 52) → FAIL · 화면에 제어 문자 0(KB-7)' 'o4-eso-prod-role.ps1' -Allow @{ read = $true } -Vault -ReadOnly -Summary $O4S -Setup { $global:Role = $script:o4cc; $global:PolicyText = $POLOK } -Inputs @($TOK) `
    -Want @('FAIL audience = vault?]52;c;QUJD?(기대 vault)', 'o4=FAIL 13/14')

  # ---- O-5(설계 D16 · D18 · VR-12): a · b · c
  $O5S = '--- T075 O-5 탐침 결과'
  # HttpFn 은 블록의 호출 사슬 안(curl.exe 모의)에서 돈다 — $script: 는 블록 파일의 스크립트 범위로 풀린다(동적 범위). 그래서 전역으로 둔다
  $global:O5Dep = $false
  $o5Http = { param($req) Http-Model $req @{ deployed = $global:O5Dep } }
  $o5Post = { param([string]$tok)
    $sec = [string]$TOKV[$tok]['client_secret']; $cid = [string]$TOKV[$tok]['client_id']
    $auth = @($global:CurlCalls | Where-Object { $_.stdinLines -gt 0 })
    Check "자격($tok) = stdin 헤더로만 · argv 에 Client ID · secret 0" ($auth.Count -ge 1 -and @($auth | Where-Object { -not (SEq $_.id $cid) -or -not (SEq $_.secret $sec) }).Count -eq 0 -and -not (@($global:XArgv) -join ' ').Contains($sec) -and -not (@($global:XArgv) -join ' ').Contains($cid))
    $ck = @($global:CurlCalls | ForEach-Object { (Http-Model $_ @{ deployed = $global:O5Dep }).cookie } | Where-Object { $_ })
    Check 'Set-Cookie(CF_Authorization — 앱 범위 JWT) 값이 화면 · argv 에 0(헤더를 통째로 읽지 않는다 — VR-12)' (@($ck | Where-Object { $global:LastText.Contains($_) -or (@($global:XArgv) -join ' ').Contains($_) }).Count -eq 0) }
  Run-OCase 'O5a-01' 'O-5 a(배포 전) dev: 헤더 없음 → 401 기록 · tester-m2m → 404 PASS · 자격은 stdin 만' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:O5Dep = $false; $global:HttpFn = $o5Http } -Inputs @('dev', 'a') `
    -Want @('INFO o5a dev 헤더 없음 GET /health → 401(기록 — 합격선 없음 · C11)', 'PASS o5a dev tester-m2m GET /health → 404', 'o5a dev=PASS 1/1') -Post { & $o5Post 'tester-m2m'; Check 'curl GET 2회(헤더 없음 1 · 자격 1) · 호스트 identity-m2m-dev' ($global:CurlCalls.Count -eq 2 -and @($global:CurlCalls | Where-Object { SEq $_.host 'identity-m2m-dev.joshuatech.dev' }).Count -eq 2) }
  Run-OCase 'O5a-02' 'O-5 a — tester-m2m 이 403(정책 · 토큰 어긋남) → FAIL' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:HttpFn = { param($req) if ($req.id.Length) { [pscustomobject]@{ code = '403'; xrid = ''; cc = ''; body = 'Forbidden'; cookie = '' } } else { [pscustomobject]@{ code = '401'; xrid = ''; cc = ''; body = 'x'; cookie = '' } } } } -Inputs @('dev', 'a') `
    -Want @('FAIL o5a dev tester-m2m GET /health → 404', '응답 403', 'o5a dev=FAIL 0/1')
  Run-OCase 'O5b-01' 'O-5 b(배포 뒤 게이트) prod: 200 · ok · checks 셋 ok · git_sha = 입력 · x-request-id → gate=PASS 8/8 · Set-Cookie 0' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:O5Dep = $true; $global:HttpFn = $o5Http } -Inputs @('prod', 'b', $global:DeploySha) `
    -Want @('PASS o5b prod GET /health → 200', 'PASS o5b prod 본문 git_sha = 배포 이미지 revision(입력)', 'PASS o5b prod 응답 헤더 x-request-id 있음', 'INFO o5b prod 기록: version = 0.1.0 · Cache-Control = (없음) · x-request-id = req-mock-health-1', 'o5b prod=PASS 8/8') -NotWant @('FAIL ') `
    -Post { & $o5Post 'tester-m2m'; Check 'GET 1회 · 경로 /health · 호스트 prod' ($global:CurlCalls.Count -eq 1 -and (SEq $global:CurlCalls[0].path '/health') -and (SEq $global:CurlCalls[0].host 'identity-m2m-prod.joshuatech.dev')) }
  foreach ($c in @(@('O5b-02', 'status degraded', { param($b) $b['status'] = 'degraded' }, 'FAIL o5b dev 본문 status = ok — FAIL(status = degraded)', 7),
      @('O5b-03', 'checks.kafka_producer fail', { param($b) $b['checks']['kafka_producer']['status'] = 'fail' }, 'FAIL o5b dev checks.kafka_producer.status = ok', 7),
      @('O5b-04', 'git_sha 다름(옛 이미지)', { param($b) $b['git_sha'] = (Hex-Lower 'other').Substring(0, 40) }, 'FAIL o5b dev 본문 git_sha = 배포 이미지 revision(입력)', 7),
      @('O5b-05', 'checks 에 키 하나 더(openfga)', { param($b) $b['checks']['openfga'] = [ordered]@{ status = 'ok'; latency_ms = 1 } }, 'FAIL o5b dev 본문 checks = {db, dragonfly, kafka_producer}(정확히)', 7))) {
    $global:O5Mut = $c[2]
    Run-OCase $c[0] "O-5 b — $($c[1]) → FAIL · gate=FAIL" 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
      -Setup { Seed-Tofu; $global:HttpFn = { param($req)
          $ck = [ordered]@{ db = [ordered]@{ status = 'ok'; latency_ms = 3 }; dragonfly = [ordered]@{ status = 'ok'; latency_ms = 1 }; kafka_producer = [ordered]@{ status = 'ok'; latency_ms = 9 } }
          $b = [ordered]@{ status = 'ok'; version = '0.1.0'; git_sha = $global:DeploySha; checks = $ck }
          & $global:O5Mut $b
          [pscustomobject]@{ code = '200'; xrid = 'req-mock-health-2'; cc = ''; body = (ConvertTo-Json -InputObject $b -Depth 5 -Compress); cookie = '' } } } -Inputs @('dev', 'b', $global:DeploySha) `
      -Want @($c[3], "o5b dev=FAIL $($c[4])/8") }
  Run-OCase 'O5b-06' 'O-5 b — x-request-id 없음 → FAIL' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:HttpFn = { param($req) $r = Http-Model $req @{ deployed = $true }; $r.xrid = ''; $r } } -Inputs @('dev', 'b', $global:DeploySha) -Want @('FAIL o5b dev 응답 헤더 x-request-id 있음 — FAIL(x-request-id 없음)', 'o5b dev=FAIL 7/8')
  Run-OCase 'O5b-07' 'O-5 b — 배포 전(404) → FAIL(응답 404) · 본문 판정도 FAIL' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:O5Dep = $false; $global:HttpFn = $o5Http } -Inputs @('dev', 'b', $global:DeploySha) -Want @('FAIL o5b dev GET /health → 200 — FAIL(응답 404)', 'o5b dev=FAIL 0/8')
  Run-OCase 'O5c-01' 'O-5 c dev: web-bff-dev 자격 /session/check → 200 {"active": true} · no-store PASS · UD-10 표본(iat=x) → 400 validation-error PASS · 보낸 시각 · x-request-id INFO · 자격 stdin 만' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:O5Dep = $true; $global:HttpFn = $o5Http } -Inputs @('dev', 'c') `
    -Want @('PASS o5c dev GET /session/check(web-bff-dev · 가짜 sub · sid · iat=지금) → 200', 'PASS o5c dev 본문 = {"active": true}(nbf 없음)', 'PASS o5c dev 응답 헤더 Cache-Control 에 no-store', 'PASS o5c dev UD-10 표본 GET /session/check?…&iat=x → 400', 'PASS o5c dev UD-10 표본 본문 type = https://joshuatech.dev/problems/validation-error', 'INFO o5c dev UD-10 표본: 보낸 시각(UTC)', 'x-request-id = req-mock-sc-400', 'o5c dev=PASS 5/5') `
    -Post {
      & $o5Post 'web-bff-dev'
      $q = @($global:CurlCalls | ForEach-Object { $_.query })
      Check '질의 둘 = sub(고정 가짜 uuid) · iat(정수 epoch 초 · 지금) · sid(고정 가짜 64 hex) / 같은 sub · sid 로 iat=x' ($q.Count -eq 2 -and ($q[0] -cmatch '\Asub=7075c0de-7075-4075-8075-7075c0de7075&iat=[0-9]{10}&sid=(7075c0de){8}\z') -and (SEq $q[1] 'sub=7075c0de-7075-4075-8075-7075c0de7075&iat=x&sid=7075c0de7075c0de7075c0de7075c0de7075c0de7075c0de7075c0de7075c0de')) ($q -join ' | ') }
  Run-OCase 'O5c-02' 'O-5 c — 본문에 nbf · Cache-Control 없음 → FAIL 둘' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:HttpFn = { param($req) $r = Http-Model $req @{ deployed = $true }; if ($r.code -ceq '200') { $r.body = '{"active": true, "nbf": 1700000000}'; $r.cc = '' }; $r } } -Inputs @('dev', 'c') `
    -Want @('FAIL o5c dev 본문 = {"active": true}(nbf 없음) — FAIL(키 2개(active,nbf)', 'FAIL o5c dev 응답 헤더 Cache-Control 에 no-store', 'o5c dev=FAIL 3/5')
  Run-OCase 'O5c-03' 'O-5 c — web-bff-prod 자격이 dev 호스트에서 403 이 되는 꼴(CN 불일치) → FAIL' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:HttpFn = { param($req) Http-Model ([pscustomobject]@{ url = $req.url; path = $req.path; query = $req.query; host = 'identity-m2m-prod.joshuatech.dev'; id = $req.id; secret = $req.secret; stdinLines = $req.stdinLines }) @{ deployed = $true } } } -Inputs @('dev', 'c') `
    -Want @('FAIL o5c dev GET /session/check(web-bff-dev · 가짜 sub · sid · iat=지금) → 200 — FAIL(응답 403)', 'o5c dev=FAIL')
  Run-OCase 'O5-08' 'O-5 curl 7.83(%header 없음) → 아무것도 보내기 전에 중단(tofu output 0)' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu; $global:CurlVersion = 'curl 7.83.1 (x86_64-pc-win32)' } -Inputs @('dev', 'a') -Expect 'curl 7.84 이상이 필요하다' `
    -Post { Check 'tofu output 0 · curl GET 0' ($global:TofuCalls.Count -eq 0 -and $global:CurlCalls.Count -eq 0) }
  $b8 = [ordered]@{}; foreach ($k in @($TOKV.Keys)) { $b8[$k] = $TOKV[$k] }; $b8['tester-m2m'] = [ordered]@{ client_id = $TOKV['tester-m2m']['client_id']; client_secret = 'short' }
  $script:o5b8 = $b8
  Run-OCase 'O5-09' 'O-5 자격 꼴이 아니다(tester-m2m client_secret 이 54자 [A-Za-z0-9_-] 아님 — short) → 아무것도 보내지 않고 중단 · 값 미출력' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu -tok $script:o5b8 } -Inputs @('dev', 'a') -Expect '자격을 꺼내지 못했다' `
    -Post { Check 'curl GET 0' ($global:CurlCalls.Count -eq 0) }
  # T075 보정 2026-11-19(L4 d5 실측 — client_secret = 54자 [A-Za-z0-9_-] · research.md R12 :4256 cfast_[40자][8자 checksum] 꼴): 자격 꼴 판정의 성질 넷을 고정한다(리뷰 O5fix-r0 F1) —
  #   09b 옛 64 소문자 hex(Cloudflare 에서는 아직 유효한 옛 꼴 — 이 프로젝트 토큰 넷은 전부 새 꼴이라 일부러 거부) · 09c 맞는 54자 + 끝 LF(\z 고정 — curl 은 끝 LF 를 버려 주입은 아니다) ·
  #   09d 54자 안 가운데 CR(실해 주입 — curl -H @- 는 CR 에서 헤더를 나눈다 · 리뷰 루프백 탐침 · '\A.{54}\z' 변이를 잡는다) · 09e 맞는 53자 + U+212A(대소문자 무시 매치면 [A-Za-z]에 맞는다 — -c 고정)
  $okS = Cf-Secret 'secret-shape'
  foreach ($c in @(
      @('O5-09b', '64 소문자 hex(옛 꼴 — 일부러 거부)', (Hex-Lower 'MOCK-secret-hex64'), @((Hex-Lower 'MOCK-secret-hex64'))),
      @('O5-09c', '맞는 54자 + 끝 LF(\z 고정 — curl 은 끝 LF 를 버린다)', ($okS + "`n"), @($okS)),
      @('O5-09d', '54자 가운데 CR(헤더 주입 — 유효 26 + CR + 유효 27)', ($okS.Substring(0, 26) + "`r" + $okS.Substring(26, 27)), @($okS.Substring(0, 26), $okS.Substring(26, 27))),
      @('O5-09e', '맞는 53자 + U+212A(Kelvin — -c 고정)', ($okS.Substring(0, 53) + [string][char]0x212A), @($okS.Substring(0, 53))))) {
    $bx = [ordered]@{}; foreach ($k in @($TOKV.Keys)) { $bx[$k] = $TOKV[$k] }; $bx['tester-m2m'] = [ordered]@{ client_id = $TOKV['tester-m2m']['client_id']; client_secret = $c[2] }
    $script:o5bx = $bx; $script:o5bxs = @($c[3])
    Run-OCase $c[0] "O-5 자격 꼴이 아니다(tester-m2m client_secret = $($c[1])) → 아무것도 보내지 않고 중단 · 값 미출력" 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu -tok $script:o5bx; foreach ($x in $script:o5bxs) { [void]$global:ExtraSecrets.Add([string]$x) } } -Inputs @('dev', 'a') -Expect '자격을 꺼내지 못했다' `
      -Post { Check 'curl GET 0' ($global:CurlCalls.Count -eq 0) } }
  Run-OCase 'O5-10' 'O-5 모드 입력이 a · b · c 밖 → 중단(tofu 0)' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu } -Inputs @('dev', 'd') -Expect '정지점에서 중단' -Post { Check 'tofu output 0' ($global:TofuCalls.Count -eq 0) }
  Run-OCase 'O5-11' 'O-5 b 기대 git_sha 가 40자 hex 아님 → 중단' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu } -Inputs @('dev', 'b', '9fd9f2c') -Expect 'git_sha 가 40자 소문자 hex 가 아니다'
  Run-OCase 'O5-12' 'O-5 curl 실패(이름 풀이 — exit 6) → FAIL(curl exit=6) · 자격 노출 0' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu; $global:F['curlFail'] = $true } -Inputs @('dev', 'a') `
    -Want @('curl exit=6 · curl: (6) Could not resolve host', 'o5a dev=FAIL 0/1')

  # ---- O-6 사전(설계 D20): kv acl 줄 꼴 · 꼬리 분류 — dev · prod
  $O6AS = '--- T075 O-6 사전 요약'
  Run-OCase 'O6A-01' 'O-6 사전 — 적용 전(두 env 옛 규칙 · T057 렌더) → dev · prod FAIL(옛 규칙 — 기대한 FAIL) · 줄 꼴 분류 · 해시 · 내용 0' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'dev') }); Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'prod') }) } -Inputs @($TOK) `
    -Want @("O6PRE $($DACL.path) — live v1 · 키 users.acl · 4줄 · default 줄 정확 · admin 줄 꼴 정확 · identity-admin 꼬리 = 옛 규칙(+@all) · sample-pod 꼬리 = 옛 규칙(+@all) → FAIL(옛 규칙 — UD-9 적용 전이면 기대한 FAIL · 적용 뒤면 회귀)",
      "O6PRE $($PACL.path) — live v1 · 키 users.acl · 3줄 · default 줄 정확 · admin 줄 꼴 정확 · identity-admin 꼬리 = 옛 규칙(+@all) · sample-pod 줄 없음(prod — 계약)", 'o6-pre dev=FAIL(옛 규칙 — UD-9 적용 전이면 기대한 FAIL · 적용 뒤면 회귀) prod=FAIL(옛 규칙')
  Run-OCase 'O6A-02' 'O-6 사전 — dev 재렌더 뒤(dev B2 · prod 옛 규칙) → dev PASS(B2) · prod FAIL(옛 규칙)' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-For 'dev' (Live-Map 'dev')) }); Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'prod') }) } -Inputs @($TOK) `
    -Want @('identity-admin 꼬리 = B2 · sample-pod 꼬리 = B2 → PASS(B2)', 'o6-pre dev=PASS(B2) prod=FAIL(옛 규칙')
  Run-OCase 'O6A-03' 'O-6 사전 — 둘 다 B2 → PASS · PASS' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-For 'dev' (Live-Map 'dev')) }); Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-For 'prod' (Live-Map 'prod')) }) } -Inputs @($TOK) -Want @('o6-pre dev=PASS(B2) prod=PASS(B2)')
  Run-OCase 'O6A-04' 'O-6 사전 — dev CRLF(바이트) · prod 에 sample-pod 줄(B2) · → FAIL(바이트) · FAIL(줄 수)' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-For 'dev' (Live-Map 'dev')).Replace("`n", "`r`n") }); $m = Live-Map 'prod'; $m['sample-pod'] = $pwS; Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-For 'dev' $m) }) } -Inputs @($TOK) `
    -Want @("O6PRE $($DACL.path) — live v1 · 키 users.acl → FAIL(바이트: ASCII 인쇄 문자", 'sample-pod 줄 있음(prod 에는 없어야 한다)', 'prod=FAIL(줄 수 4(기대 3')
  Run-OCase 'O6A-05' 'O-6 사전 — dev 에 금지 꼴(-client|kill 끼움) · prod absent → FAIL(금지 꼴) · FAIL(판정 불가)' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-For 'dev' (Live-Map 'dev')).Replace($B2TAIL, (' -client|kill' + $B2TAIL)) }) } -Inputs @($TOK) `
    -Want @('dev=FAIL(금지 꼴: 3줄에 세로 막대', "O6PRE $($PACL.path) — FAIL(판정 불가 — metadata 조회 exit=2 · No value found")
  Run-OCase 'O6A-06' 'O-6 사전 — dev acl 키 이름 여분(note) → FAIL(키 집합) · 값 미출력' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-For 'dev' (Live-Map 'dev')); note = 'x' }); Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-For 'prod' (Live-Map 'prod')) }) } -Inputs @($TOK) `
    -Want @('dev=FAIL(키 집합이 users.acl 하나가 아니다 · 키 2개 — 값 미출력)', 'prod=PASS(B2)')

  # ---- O-6 사후(설계 D20 · VD-T075-17 실측 응답 꼴): admin ACL DRYRUN 표 — kubectl exec -i · --askpass stdin
  $O6BS = '--- T075 O-6 사후 요약'
  function Seed-Df { param([string]$dev = 'b2', [string]$prod = 'b2')
    foreach ($u in $USERS) { Seed-LiveOk $u }
    $global:LiveAdminPw = @{ dev = [string]$LIVE_PW[$DA.path]; prod = [string]$LIVE_PW[$PA.path] }
    $global:DfRules = @{ dev = $dev; prod = $prod } }
  $o6bPost = { param([string]$ev, [int]$n)
    Check "kubectl exec $n 회 · 전부 env $ev · stdin 의 첫 줄(LF 까지) = live admin 비밀번호(LF 를 먼저 붙였다 — CR 0) · 파이프 객체 1개" ($global:KubeCalls.Count -eq $n -and @($global:KubeCalls | Where-Object { -not (SEq $_.env $ev) -or -not $_.pwOk -or $_.stdinObjects -ne 1 }).Count -eq 0)
    Check 'kubectl argv 에 -- · --askpass · --kubeconfig …joshuatech-admin.yaml(관리자 kubeconfig 를 명령에 직접) · 비밀번호 0' (@($global:XArgv | Where-Object { $_.StartsWith('kubectl ') -and -not ($_.Contains(' -- redis-cli --user admin --askpass ') -and $_.Contains('joshuatech-admin.yaml')) }).Count -eq 0)
    Check '관리자 kubeconfig 는 Test-Path 로만 확인(실물 파일을 읽지 않는다 — 모의가 답했다)' (@($global:FsLog | Where-Object { $_.EndsWith('joshuatech-admin.yaml') }).Count -eq 1) }
  Run-OCase 'O6B-01' 'O-6 사후 dev(B2 라이브) → 표 7 PASS(ACL LIST · REPLICAOF · CLIENT 거부 / GET · SET 허용 / sample-pod SET revoked · CLIENT KILL 거부) · o6-post dev=PASS 7/7' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS `
    -Setup { Seed-Df } -Inputs @('dev', $TOK) `
    -Want @("PASS ACL DRYRUN identity-admin ACL LIST → 거부(This user has no permissions to run the 'ACL LIST' command) · 기대 거부", 'PASS ACL DRYRUN identity-admin GET revoked:sub:x → 허용(OK) · 기대 허용', "PASS ACL DRYRUN sample-pod CLIENT KILL ID 1 → 거부(This user has no permissions to run the 'CLIENT' command) · 기대 거부", 'o6-post dev=PASS 7/7') `
    -Post { & $o6bPost 'dev' 7 }
  Run-OCase 'O6B-02' 'O-6 사후 prod(B2) → 표 5(sample-pod 행 없음 — prod 에는 그 사용자가 없다) · PASS 5/5' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS -Setup { Seed-Df } -Inputs @('prod', $TOK) `
    -Want @('o6-post prod=PASS 5/5') -NotWant @('sample-pod') -Post { & $o6bPost 'prod' 5 }
  Run-OCase 'O6B-03' 'O-6 사후 dev(옛 규칙 라이브 — LOAD 전 · 5단계 미반영) → ACL LIST · REPLICAOF · CLIENT · CLIENT KILL 허용 = FAIL 4 · o6-post dev=FAIL 3/7' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS -Setup { Seed-Df 't057' } -Inputs @('dev', $TOK) `
    -Want @('FAIL ACL DRYRUN identity-admin ACL LIST → 허용(OK) · 기대 거부', 'FAIL ACL DRYRUN sample-pod CLIENT KILL ID 1 → 허용(OK) · 기대 거부', 'o6-post dev=FAIL 3/7 — ACL LOAD 가 OK 였다면 마운트 파일이 아직 옛 내용이었다(5단계 미반영)') -Post { & $o6bPost 'dev' 7 }
  Run-OCase 'O6B-04' 'O-6 사후 — kv admin 비밀번호 ≠ 라이브(회전 반쪽) → admin AUTH 실패 = 판정 불가(종료 0 이어도 응답 줄로 가린다)' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS `
    -Setup { Seed-Df; $global:LiveAdminPw['dev'] = $pwOther; [void]$global:ExtraSecrets.Add($pwOther) } -Inputs @('dev', $TOK) -Expect 'admin AUTH 실패' -Want @('o6-post dev=판정 불가')
  Run-OCase 'O6B-05' 'O-6 사후 — kubectl exec 실패(exit 1) → 판정 불가' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS -Setup { Seed-Df; $global:F['kexecFail'] = $true } -Inputs @('dev', $TOK) -Expect 'kubectl exec 실패(exit=1' -Want @('o6-post dev=판정 불가')
  Run-OCase 'O6B-06' 'O-6 사후 — 관리자 kubeconfig 없음 → 아무것도 묻기 전에 중단' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS -Setup { Seed-Df; $global:AdminKc = $false } -Inputs @('dev', $TOK) -Expect '관리자 kubeconfig 가' `
    -Post { Check '입력 0 · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:KubeCalls.Count -eq 0) }
  Run-OCase 'O6B-07' 'O-6 사후 — kv admin 경로 없음 → 판정 불가 · kubectl 0' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS -Setup { Seed-Df; [void]$global:Kv.Remove($DA.path) } -Inputs @('dev', $TOK) -Expect 'admin 비밀번호를 읽지 못했다' `
    -Post { Check 'kubectl 0' ($global:KubeCalls.Count -eq 0) }

  # ---- W-6 ACL LOAD(설계 D20 6단계): admin ACL LOAD 1회 · 재시작 0
  $WLS = '--- T075 W-6 ACL LOAD 결과'
  Run-OCase 'WL-01' 'ACL LOAD dev → OK · 라이브 규칙이 마운트 파일(B2)로 바뀐다 · kubectl 1회 · stdin 첫 줄 = admin 비밀번호' 'w6-acl-load.ps1' -Allow $AV -Vault -Summary $WLS `
    -Setup { Seed-Df 't057'; $global:DfPending['dev'] = 'b2' } -Inputs @('dev', $TOK, 'load-dev') `
    -Want @('OK   dragonfly-dev ACL LOAD — OK · 다음 = O-6 사후', 'acl-load dev = OK(admin ACL LOAD') -Post { & $o6bPost 'dev' 1; Check 'ACL LOAD 1회 · 라이브 규칙 = b2' ($global:AclLoads.Count -eq 1 -and (SEq $global:DfRules['dev'] 'b2')); Check 'kv 쓰기 0' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0) }
  Run-OCase 'WL-02' 'ACL LOAD dev — 오류 응답(Unrecognized parameter) → STOP · 옛 규칙 유지 · 재시작하지 않는다 안내' 'w6-acl-load.ps1' -Allow $AV -Vault -Summary $WLS `
    -Setup { Seed-Df 't057'; $global:DfPending['dev'] = 'b2'; $global:F['aclLoadFail'] = $true } -Inputs @('dev', $TOK, 'load-dev') `
    -Want @('STOP dragonfly-dev — ACL LOAD 실패(ERR Error loading: /etc/dragonfly/users.acl Unrecognized parameter -CLIENT|KILL) · 옛 규칙이 메모리에 남는다(안전) — 재시작하지 않는다', 'acl-load dev = 실패(ACL LOAD 응답 =') -Post { Check '라이브 규칙 그대로 t057' (SEq $global:DfRules['dev'] 't057') }
  Run-OCase 'WL-03' 'ACL LOAD — admin AUTH 실패 → STOP · LOAD 미실행' 'w6-acl-load.ps1' -Allow $AV -Vault -Summary $WLS `
    -Setup { Seed-Df 't057'; $global:DfPending['dev'] = 'b2'; $global:LiveAdminPw['dev'] = $pwOther; [void]$global:ExtraSecrets.Add($pwOther) } -Inputs @('dev', $TOK, 'load-dev') `
    -Want @('STOP dragonfly-dev — admin AUTH 실패(NOAUTH · AUTH failed) · ACL LOAD 는 실행되지 않았다', 'acl-load dev = 실패(admin AUTH 실패') -Post { Check 'ACL LOAD 0 · 규칙 그대로' ($global:AclLoads.Count -eq 0 -and (SEq $global:DfRules['dev'] 't057')) }
  Run-OCase 'WL-04' 'ACL LOAD — 확인 단어가 다른 env(load-prod) → 보내지 않는다(kubectl 0)' 'w6-acl-load.ps1' -Allow $AV -Vault -Summary $WLS -Setup { Seed-Df } -Inputs @('dev', $TOK, 'load-prod') -Expect '정지점에서 중단' `
    -Want @('acl-load dev = 보내지 않았다') -Post { Check 'kubectl 0' ($global:KubeCalls.Count -eq 0) }
  Run-OCase 'WL-05' 'ACL LOAD — kubectl exec 실패 → 결과 미확인(LOAD 가 닿았는지 모른다 — O-6 사후로 본다 · KB-10)' 'w6-acl-load.ps1' -Allow $AV -Vault -Summary $WLS -Setup { Seed-Df; $global:F['kexecFail'] = $true } -Inputs @('dev', $TOK, 'load-dev') -Expect 'kubectl exec 실패' `
    -Want @('acl-load dev = 결과 미확인(kubectl exec exit=1', 'O-6 사후로 라이브 규칙을 본다') -NotWant @('보내지 못했다')
  # ---- 연쇄(설계 D20 적용 순서 6–7): 옛 규칙 라이브 · 마운트 = B2 → ACL LOAD → O-6 사후 PASS
  Run-OCase 'CH-01' '연쇄 — W-6 ACL LOAD(dev) 뒤 O-6 사후(dev) = PASS 7/7(라이브 규칙 상태를 이어받는다)' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS `
    -Setup { Seed-Df 't057'; $global:DfPending['dev'] = 'b2'
      $global:Inputs.Enqueue('dev'); $global:Inputs.Enqueue($TOK); $global:Inputs.Enqueue('load-dev'); $global:Allow['kubectl'] = $true
      try { & (Join-Path $BlockDir 'w6-acl-load.ps1') *>&1 | Out-Null } catch { }
      foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'XArgv', 'Events', 'ClipValues', 'KubeCalls', 'FsLog') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
      $global:Inputs = [System.Collections.Queue]::new() } -Inputs @('dev', $TOK) `
    -Want @('o6-post dev=PASS 7/7') -Post { Check '사전 단계 ACL LOAD 1회 · 라이브 규칙 b2' ($global:AclLoads.Count -eq 1 -and (SEq $global:DfRules['dev'] 'b2')); & $o6bPost 'dev' 7 }

  # ===== 수정 라운드 1 — T075 acl 삭제 블록(KB-3 · KA-5): 허용 목록 = acl 두 경로 · 키 집합 {users.acl} · 재타자 Ordinal · No value found 확인 · 성공 줄 = W-6
  $DELS = '--- T075 acl 삭제 결과'
  function Seed-AclOld { foreach ($u in $USERS) { Seed-LiveOk $u }; foreach ($a in @($DACL, $PACL)) { Seed-Path $a.path ([ordered]@{ 'users.acl' = (Acl-T057 $a.env) }) }; $global:AllowDelete = $true }
  $delKeep = { param([string[]]$gone)
    foreach ($u in $USERS) { Check-Unchanged $u (Live-Data $u) }
    foreach ($a in @($DACL, $PACL)) { if ($gone -ccontains $a.path) { Check "$($a.path) 지워졌다(No value found)" (-not $global:Kv.ContainsKey($a.path) -and $global:Deleted.ContainsKey($a.path)) } else { Check "$($a.path) 그대로" ($global:Kv.ContainsKey($a.path) -and -not $global:Deleted.ContainsKey($a.path)) } }
    Check "metadata delete 호출 $($gone.Count)회 · 지운 경로 = 허용 목록 안" (@($global:Events | Where-Object { ([string]$_).StartsWith('vault:meta-delete:', [StringComparison]::Ordinal) }).Count -eq $gone.Count -and @($global:Deleted.Keys | Where-Object { -not (@($DACL.path, $PACL.path) -ccontains $_) }).Count -eq 0) }
  foreach ($c in @(@('DEL-01', $DACL.path), @('DEL-02', $PACL.path))) {
    $script:delP = $c[1]
    Run-OCase $c[0] "acl 삭제 정상 — $($c[1]) · 키 집합 {users.acl} · 재타자 같음 → 삭제 · No value found 확인 · 성공 줄 = 다음 W-6(op1 안내 0) · 다른 env acl · 사용자 경로 그대로" 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld } -Inputs @($c[1], $TOK, $c[1]) `
      -Want @("OK   $($c[1]) — 모든 버전 · 메타데이터 삭제(No value found 확인 · 삭제) · 다음 = W-6(w6-render-dragonfly-acl.ps1", "acl-delete $($c[1]) = OK(", '「머지 전에만 지운다」의 예외 까닭') -NotWant @('op1') -Post { & $delKeep @($script:delP) } }
  foreach ($c in @(@('DEL-03', 'kv/dev/dragonfly/identity-admin', '사용자 경로'), @('DEL-04', 'kv/prod/dragonfly/admin', 'admin 경로'), @('DEL-05', 'KV/dev/dragonfly/acl', '대소문자 다른 경로(Ordinal)'), @('DEL-06', 'kv/dev/dragonfly/acl ', '끝 공백'))) {
    Run-OCase $c[0] "acl 삭제 — 허용 목록 밖($($c[2])) → 토큰을 묻기 전에 중단 · 지우기 0" 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld } -Inputs @($c[1], $TOK, $c[1]) -Expect '허용 목록(kv/dev/dragonfly/acl · kv/prod/dragonfly/acl) 밖의 입력이다' `
      -Want @('acl-delete (경로 선택 전) = 지우지 않았다') -Post { Check '보안 입력 0(토큰을 묻지 않았다) · metadata get · delete 0' (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0 -and (Ev-First 'vault:meta-get:') -lt 0); & $delKeep @() } }
  Run-OCase 'DEL-07' 'acl 삭제 — 키 집합이 {users.acl} 이 아니다(note 여분) → STOP · 지우기 0' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Inputs @($DACL.path, $TOK, $DACL.path) -Expect '키 집합 불일치' `
    -Setup { Seed-AclOld; Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'dev'); note = 'x' }) } -Want @("STOP $($DACL.path) — 키 집합이 {users.acl} 이 아니다(키 2개 · 값 미출력)") -Post { Check '재타자 정지점 전(입력 2)' ($global:ReadLog.Count -eq 2); Check 'delete 0' ((Ev-First 'vault:meta-delete:') -lt 0) }
  Run-OCase 'DEL-08' 'acl 삭제 — 재타자가 경로와 다르다(prod 를 친다) → 정지점 중단 · 지우기 0' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld } -Inputs @($DACL.path, $TOK, $PACL.path) -Expect '정지점에서 중단: 재타자가 경로와 다르다' `
    -Want @("acl-delete $($DACL.path) = 지우지 않았다(재타자가 경로와 다르다)") -Post { & $delKeep @() }
  Run-OCase 'DEL-09' 'acl 삭제 — 이미 없다(absent) → 지울 것이 없다 · 다음 = W-6 · 재타자 정지점 없음' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld; [void]$global:Kv.Remove($DACL.path) } -Inputs @($DACL.path, $TOK) `
    -Want @("INFO $($DACL.path) — 이미 없다(absent) · 지울 것이 없다 — 다음 = W-6", "acl-delete $($DACL.path) = 이미 없음(absent") -Post { Check 'delete 0' ((Ev-First 'vault:meta-delete:') -lt 0) }
  Run-OCase 'DEL-10' 'acl 삭제 — 권한 거부(403 · 경로 그대로) → 재판정 live = 삭제되지 않았다 STOP' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld; $global:F['delFail'][$DACL.path] = 1 } -Inputs @($DACL.path, $TOK, $DACL.path) -Expect '삭제 실패' `
    -Want @("STOP $($DACL.path) — 삭제되지 않았다(삭제 exit=2 · 경로가 남아 있다 — live v1)", "acl-delete $($DACL.path) = 실패(삭제 exit=2") -Post { Check 'acl 그대로' ($global:Kv.ContainsKey($DACL.path)) }
  Run-OCase 'DEL-11' 'acl 삭제 — exit 0 인데 지워지지 않았다(delNoop) → 재판정 live = 삭제되지 않았다 STOP(종료 코드를 믿지 않는다)' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld; $global:F['delNoop'][$DACL.path] = 1 } -Inputs @($DACL.path, $TOK, $DACL.path) -Expect '삭제 실패' `
    -Want @("STOP $($DACL.path) — 삭제되지 않았다(삭제 exit=0 · 경로가 남아 있다 — live v1)")
  Run-OCase 'DEL-12' 'acl 삭제 — 지운 뒤 조회 500 → 삭제 확인 실패 STOP(없어졌다고 단정하지 않는다)' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld; $global:F['postDelErr'][$DACL.path] = 1 } -Inputs @($DACL.path, $TOK, $DACL.path) -Expect '삭제 확인 실패' `
    -Want @("STOP $($DACL.path) — 삭제 확인 실패(조회 오류", "acl-delete $($DACL.path) = 결과 미확인(삭제 exit=0 · 뒤 조회 오류") -NotWant @("OK   $($DACL.path)")
  Run-OCase 'DEL-13' 'acl 삭제 — 현재 버전이 soft-delete(dead) → 판정 dead STOP · 지우기 0' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Inputs @($DACL.path, $TOK, $DACL.path) -Expect '판정 dead' `
    -Setup { Seed-AclOld; Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'dev') }) 1 '2026-10-13T01:00:00Z' } -Post { Check 'delete 0' ((Ev-First 'vault:meta-delete:') -lt 0) }
  Run-OCase 'DEL-P1' 'acl 삭제 붙여넣기 모드(KB-5) — dev 정상 · 블록 밖 범위에 새 변수 0' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Paste -Setup { Seed-AclOld } -Inputs @($DACL.path, $TOK, $DACL.path) `
    -Want @("OK   $($DACL.path) — 모든 버전 · 메타데이터 삭제(No value found 확인") -Post { & $delKeep @($DACL.path) }
  # 연쇄(런북 §4 T075 B 2–3단계 — 새 삭제 블록): 옛 규칙 acl 2경로 → 삭제 블록 dev · prod → W-6 재실행 = 사용자 5 SKIP · acl 2 생성(B2) · 독립 계산과 바이트 일치
  Run-OCase 'CH-02' '연쇄 — acl 삭제 블록(dev · prod) 뒤 W-6 = 사용자 5 SKIP · acl 2 PLAN → seed → B2 acl 2 생성 · 사용자 값 불변' 'w6-render-dragonfly-acl.ps1' -Vault -Summary $SUMMARY `
    -Setup { Seed-AclOld
      foreach ($p in @($DACL.path, $PACL.path)) {
        foreach ($x in @($p, $TOK, $p)) { $global:Inputs.Enqueue($x) }
        try { & (Join-Path $BlockDir 'w6-acl-delete.ps1') *>&1 | Out-Null } catch { } }
      foreach ($n in 'Prompts', 'ReadLog', 'ArgvLog', 'XArgv', 'Events', 'ClipValues', 'FsLog', 'EnvAtCall') { Set-Variable -Scope Global -Name $n -Value ([System.Collections.ArrayList]::new()) }
      $global:Inputs = [System.Collections.Queue]::new(); $global:AllowDelete = $false } -Inputs @($TOK, 'seed') `
    -Want @((& $PLANLINE $DACL), (& $PLANLINE $PACL), (& $OKLINE $DACL), (& $OKLINE $PACL), '판정 결과: 생성 예정 2 · 건너뜀(live-ok) 5 · 중단 0', '판정: kv 7경로 준비 완료(생성 또는 live-ok · acl = B2 렌더)') -NotWant @('STOP ') `
    -Post {
      Check '사전 단계: 삭제 블록 두 번이 acl 2경로를 지웠다' ($global:Deleted.ContainsKey($DACL.path) -and $global:Deleted.ContainsKey($PACL.path) -and $global:Deleted.Count -eq 2)
      foreach ($a in @($DACL, $PACL)) { Check "$($a.path) = B2 렌더(독립 계산 Acl-For 와 바이트 일치)" (SEq ([string](KvData $a.path)['users.acl']) (Acl-For $a.env (Live-Map $a.env))) }
      foreach ($u in $USERS) { Check-Unchanged $u (Live-Data $u) } }

  # ===== 수정 라운드 1 — 모듈 로깅 실효 상태(KB-2): 블록마다 — 켜져 있으면 아무것도 묻기 · 부르기 전에 멈춘다
  $mlWhy = 'PowerShell 모듈 로깅이 실제로 켜져 있거나 확인하지 못했다'
  $mlCases = @(
    @('ML-O1', 'o1-cf-values.ps1', @{ tofu = $true }, { $global:ModLog['Microsoft.PowerShell.Utility'] = $true }, 'Utility LogPipelineExecutionDetails 켜짐(-SettingsFile 꼴)', @()),
    @('ML-O2', 'o2-kv-judge.ps1', @{}, { $global:ModLog['Microsoft.PowerShell.Security'] = $true }, 'Security LogPipelineExecutionDetails 켜짐', @($TOK)),
    @('ML-W2', 'w2-kv-seed.ps1', @{ patch = $true }, { $global:CfgText['system'] = '{"PowerShellPolicies":{"ModuleLogging":{"EnableModuleLogging":true,"ModuleNames":["*"]}}}' }, '시스템 powershell.config.json 켜짐', @('dev', $TOK, 'seed')),
    @('ML-O3', 'o3-kv-gate.ps1', @{}, { $global:CfgText['user'] = '{ "PowerShellPolicies": { "ModuleLogging": { "EnableModuleLogging" : true } } }' }, '사용자 powershell.config.json 켜짐(공백 꼴)', @('dev', $TOK)),
    @('ML-O4', 'o4-eso-prod-role.ps1', @{ read = $true }, { $global:ModMissing = @('Microsoft.PowerShell.Security') }, 'Security 모듈 확인 불가(1/2 — fail-closed)', @($TOK)),
    @('ML-O5', 'o5-probe-identity-m2m.ps1', @{ tofu = $true; curl = $true }, { $global:ModLog['Microsoft.PowerShell.Utility'] = $true }, 'Utility 켜짐', @('dev', 'a')),
    @('ML-O6A', 'o6-pre-dragonfly-acl.ps1', @{}, { $global:CfgText['user'] = '{"PowerShellPolicies":{"ModuleLogging":{"EnableModuleLogging":TRUE}}}' }, '사용자 설정 켜짐(대문자 TRUE — 판정은 대소문자 무관 · fail-closed)', @($TOK)),
    @('ML-O6B', 'o6-post-dragonfly-dryrun.ps1', $AV, { $global:ModLog['Microsoft.PowerShell.Utility'] = $true }, 'Utility 켜짐', @('dev', $TOK)),
    @('ML-WL', 'w6-acl-load.ps1', $AV, { $global:ModLog['Microsoft.PowerShell.Security'] = $true }, 'Security 켜짐', @('dev', $TOK, 'load-dev')),
    @('ML-DEL', 'w6-acl-delete.ps1', @{}, { $global:CfgText['system'] = '{"PowerShellPolicies":{"ModuleLogging":{"EnableModuleLogging":true}}}'; $global:AllowDelete = $true }, '시스템 설정 켜짐', @($DACL.path, $TOK, $DACL.path)))
  foreach ($c in $mlCases) {
    $script:mlSet = $c[3]
    Run-OCase $c[0] "$($c[1]) — 모듈 로깅 실효 상태: $($c[4]) → 아무것도 묻기 · 부르기 전에 중단(KB-2)" $c[1] -Allow $c[2] -Setup { Seed-Df; Seed-IaDone 'dev'; Seed-Tofu; & $script:mlSet } -Inputs $c[5] -Expect $mlWhy `
      -Post { Check '입력 0 · vault 호출 0 · tofu · curl · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0) "입력 $($global:ReadLog.Count) · vault $($global:ArgvLog.Count) · 그 밖 $($global:XArgv.Count)" } }
  # 라운드 2(KB2-1): 설정 파일은 값과 무관하게 판정한다 — ModuleLogging 이 없는 설정(경로 C:\\Users — 대문자 U 라 역슬래시-u 아님)은 멈추지 않는다
  $bs2 = [string][char]92
  $script:cfgPathOk = '{ "Microsoft.PowerShell:ExecutionPolicy": "RemoteSigned", "PSModulePath": "C:' + $bs2 + $bs2 + 'Users' + $bs2 + $bs2 + 'x' + $bs2 + $bs2 + 'Modules" }'
  Run-OCase 'ML-OK' 'o3 — 사용자 설정이 있지만 ModuleLogging · 역슬래시-u 0(ExecutionPolicy · PSModulePath C:\\Users) → 멈추지 않는다 · gate=PASS 21/21(KB2-1 — 값 무관 판정의 거짓 멈춤 0)' 'o3-kv-gate.ps1' -Vault -ReadOnly -Summary $O3S -Inputs @('dev', $TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'; $global:CfgText['user'] = $script:cfgPathOk } -Want @('gate=PASS 21/21') `
    -Post { Check '설정 파일 둘을 읽었다(텍스트 판정)' ((Ev-First 'cfg:read:system') -ge 0 -and (Ev-First 'cfg:read:user') -ge 0) }

  # ===== 수정 라운드 2(KB2-1) — 실효 값 넷(Core 스냅인 · Utility · Security · Management) · 설정 파일 값 무관 판정
  #   ③ -SettingsFile <Core 대상 정책> 으로 시작한 창: 블록은 그 파일을 읽을 수 없고(설정 파일 두 곳은 깨끗) Utility · Security · Management 도 꺼져 있다 — Core 스냅인 실효 값만 켜진다
  #      (실측 r2/probe-core.ps1 — Core 대상 정책이면 Core 값만 True) → 블록마다 아무것도 묻기 · 부르기 전에 멈춘다
  $ml2Post = { Check '입력 0 · vault 호출 0 · tofu · curl · kubectl 0' ($global:ReadLog.Count -eq 0 -and $global:ArgvLog.Count -eq 0 -and $global:XArgv.Count -eq 0) "입력 $($global:ReadLog.Count) · vault $($global:ArgvLog.Count) · 그 밖 $($global:XArgv.Count)" }
  $ml2Cases = @(
    @('ML2-O1', 'o1-cf-values.ps1', @{ tofu = $true }, @()),
    @('ML2-O2', 'o2-kv-judge.ps1', @{}, @($TOK)),
    @('ML2-W2', 'w2-kv-seed.ps1', @{ patch = $true }, @('dev', $TOK, 'seed')),
    @('ML2-O3', 'o3-kv-gate.ps1', @{}, @('dev', $TOK)),
    @('ML2-O4', 'o4-eso-prod-role.ps1', @{ read = $true }, @($TOK)),
    @('ML2-O5', 'o5-probe-identity-m2m.ps1', @{ tofu = $true; curl = $true }, @('dev', 'a')),
    @('ML2-O6A', 'o6-pre-dragonfly-acl.ps1', @{}, @($TOK)),
    @('ML2-O6B', 'o6-post-dragonfly-dryrun.ps1', $AV, @('dev', $TOK)),
    @('ML2-WL', 'w6-acl-load.ps1', $AV, @('dev', $TOK, 'load-dev')),
    @('ML2-DEL', 'w6-acl-delete.ps1', @{}, @($DACL.path, $TOK, $DACL.path)))
  foreach ($c in $ml2Cases) {
    Run-OCase $c[0] "$($c[1]) — -SettingsFile 의 Core 대상 정책(설정 파일 두 곳 깨끗 · Utility · Security · Management 꺼짐 · Core 스냅인만 켜짐) → 아무것도 묻기 · 부르기 전에 중단(KB2-1 ③)" $c[1] -Allow $c[2] `
      -Setup { Seed-Df; Seed-IaDone 'dev'; Seed-Tofu; $global:AllowDelete = $true; $global:CoreLog = $true } -Inputs $c[3] -Expect $mlWhy -Want @('실효 켜짐: Microsoft.PowerShell.Core ·') `
      -Post { & $ml2Post; Check '설정 파일 두 곳은 정책 텍스트 0 이었다(실효 값이 잡았다)' ($null -eq $global:CfgText['user'] -and -not ([string]$global:CfgText['system']).Contains('ModuleLogging')) } }
  foreach ($c in @(
      @('ML2-MGMT', 'o2-kv-judge.ps1', @{}, @($TOK), { $global:ModLog['Microsoft.PowerShell.Management'] = $true }, 'Management 실효 켜짐', '실효 켜짐: Microsoft.PowerShell.Management'),
      @('ML2-MGMTMISS', 'o6-pre-dragonfly-acl.ps1', @{}, @($TOK), { $global:ModMissing = @('Microsoft.PowerShell.Management') }, 'Management 모듈 확인 불가', 'Management 0/1'),
      @('ML2-NOSNAP', 'o4-eso-prod-role.ps1', @{ read = $true }, @($TOK), { $global:CoreNoSnap = $true }, 'ForEach-Object 의 PSSnapIn 없음(Core 확인 불가)', 'Core 스냅인 모름'),
      @('ML2-NOFE', 'w2-kv-seed.ps1', @{ patch = $true }, @('dev', $TOK, 'seed'), { $global:CoreMissing = $true }, 'ForEach-Object cmdlet 을 찾지 못함(Core 확인 불가)', 'Core 스냅인 모름'))) {
    $script:ml2Set = $c[4]
    Run-OCase $c[0] "$($c[1]) — $($c[5]) → 아무것도 묻기 · 부르기 전에 중단(KB2-1 ① — 확인하지 못하면 멈춘다)" $c[1] -Allow $c[2] -Setup { Seed-Df; Seed-IaDone 'dev'; Seed-Tofu; & $script:ml2Set } -Inputs $c[3] -Expect $mlWhy -Want @($c[6]) -Post $ml2Post }
  #   ② 설정 파일 값 무관 판정 — 리뷰 실측 놓침 꼴 여섯(문자열 "true" · 1 · 주석 · 작은따옴표 키 · 따옴표 없는 키 · 이스케이프 키) + 전부 이스케이프(낱말 ModuleLogging 0 — 역슬래시-u 만 잡는다) ·
  #      false(값 무관) · 소문자 섹션 — o3 에서 시스템 · 사용자 범위를 번갈아. 역슬래시-u 는 실행 중에 만든다(편집 도구가 역슬래시-u 를 글자로 바꾼다)
  $mn = '"ModuleNames": ["Microsoft.PowerShell.Utility"]'
  $sysCfg = Join-Path $PSHOME 'powershell.config.json'
  $usrCfg = Join-Path (Split-Path -Parent ([string]$PROFILE.CurrentUserAllHosts)) 'powershell.config.json'
  $cfgCases = @(
    @('CFG-1', 'user', ('{ "PowerShellPolicies": { "ModuleLogging": { "EnableModuleLogging": "true", ' + $mn + ' } } }'), '값이 문자열 "true"'),
    @('CFG-2', 'system', ('{ "PowerShellPolicies": { "ModuleLogging": { "EnableModuleLogging": 1, ' + $mn + ' } } }'), '값이 숫자 1'),
    @('CFG-3', 'user', ('{ "PowerShellPolicies": { "ModuleLogging": { "EnableModuleLogging": /* c */ true, ' + $mn + ' } } }'), '값 앞 /* */ 주석'),
    @('CFG-4', 'system', ("{ ""PowerShellPolicies"": { ""ModuleLogging"": { 'EnableModuleLogging': true, " + $mn + ' } } }'), '작은따옴표 키'),
    @('CFG-5', 'user', ('{ "PowerShellPolicies": { "ModuleLogging": { EnableModuleLogging: true, ' + $mn + ' } } }'), '따옴표 없는 키'),
    @('CFG-6', 'system', ('{ "PowerShellPolicies": { "ModuleLogging": { "Enable' + $bs2 + 'u004dodule' + $bs2 + 'u004cogging": true, ' + $mn + ' } } }'), '이스케이프 키(섹션 이름은 글자 그대로)'),
    @('CFG-7', 'user', ('{ "PowerShellPolicies": { "Module' + $bs2 + 'u004cogging": { "Enable' + $bs2 + 'u004dodule' + $bs2 + 'u004cogging": true, ' + $mn + ' } } }'), '전부 이스케이프(낱말 ModuleLogging 0 — 역슬래시-u 만 잡는다 · 실측: pwsh 는 이 꼴을 따른다)'),
    @('CFG-8', 'user', '{ "PowerShellPolicies": { "ModuleLogging": { "EnableModuleLogging": false } } }', '값 false(값과 무관하게 멈춘다)'),
    @('CFG-9', 'system', ('{ "powershellpolicies": { "modulelogging": { "enablemodulelogging": true, ' + $mn + ' } } }'), '소문자 섹션 · 키'))
  # 변수 이름 주의: pwsh -File 로 돌리면 이 스크립트 범위가 곧 전역이고 이름은 대소문자를 가리지 않는다 — $script:cfgText 는 모의 $global:CfgText 와 같은 변수가 된다
  #   (라운드 2 첫 판의 결함 — 리뷰어의 -File 실행에서 CFG-1–9 가 거짓 FAIL). 그래서 모의 전역과 겹치지 않는 이름을 쓴다
  foreach ($c in $cfgCases) {
    $script:cfgCaseScope = $c[1]; $script:cfgCaseText = $c[2]
    $want = $(if (SEq $c[1] 'system') { $sysCfg } else { $usrCfg })
    Run-OCase $c[0] "o3 — $($c[1]) 설정 파일: $($c[3]) → 값과 무관하게 멈춘다(KB2-1 ② — 실효 값은 전부 꺼짐)" 'o3-kv-gate.ps1' -Setup { Seed-IaDone 'dev'; Seed-IaBase 'prod'; $global:CfgText[$script:cfgCaseScope] = $script:cfgCaseText } -Inputs @('dev', $TOK) -Expect $mlWhy `
      -Want @("설정 파일 정책(값 무관): $want", '실효 켜짐:  ·') -Post { & $ml2Post
        Check '하네스 자체 시험: CFG-7 의 모의 설정 텍스트에는 낱말 ModuleLogging 이 없다(역슬래시-u 만 잡을 수 있는 꼴인지)' (-not (SEq $c[0] 'CFG-7') -or -not ($script:cfgCaseText -match 'ModuleLogging')) } }

  # ===== 수정 라운드 2(KB2-2) — INFO 줄 실행 파일 경로(사용자 홈 → ~) · SSL_CERT_FILE · SSL_CERT_DIR
  $script:homeTofu = Join-Path $HOME 'tools\tofu.exe'
  $script:homeCurl = Join-Path $HOME 'bin\curl.exe'
  Run-OCase 'O1-13' 'O-1 — tofu 가 사용자 홈 아래(Application) → INFO 줄 경로는 ~ 로 · 화면에 홈 경로 0(KB2-2)' 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Summary $O1S -Setup { Seed-Tofu; $global:FakeSrc['tofu'] = $script:homeTofu } `
    -Want @('INFO tofu CLI: OpenTofu v0.0.0-MOCK · Application ~\tools\tofu.exe —', 'o1=PASS 5/5') -NotWant @($HOME)
  Run-OCase 'O5-21' 'O-5 a — curl · tofu 가 사용자 홈 아래 → INFO 줄 두 경로 모두 ~ 로 · 화면에 홈 경로 0(KB2-2)' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:O5Dep = $false; $global:HttpFn = $o5Http; $global:FakeSrc['tofu'] = $script:homeTofu; $global:FakeSrc['curl.exe'] = $script:homeCurl } -Inputs @('dev', 'a') `
    -Want @('· Application ~\bin\curl.exe · tofu Application ~\tools\tofu.exe — 쓰기 0', 'o5a dev=PASS 1/1') -NotWant @($HOME)
  foreach ($c in @(@('O5-19', 'SSL_CERT_FILE', 'C:\other-ca.pem'), @('O5-20', 'ssl_cert_dir', 'C:\other-ca-dir'))) {
    Run-OCase $c[0] "O-5 — 환경 변수 $($c[1]) 있음(신뢰 앵커 교체) → 읽기 · 보내기 전에 중단 · 이름만 낸다(KB2-2 · 대소문자 무관)" 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu } -PreEnv @{ $c[1] = $c[2] } `
      -Expect "curl · tofu 동작을 바꾸는 환경 변수가 있다: $($c[1])" -NotWant @($c[2]) -Post { Check 'tofu · curl 호출 0' ($global:XArgv.Count -eq 0) } }

  # ===== 수정 라운드 2(KB2-3) — acl 삭제: 응답 유실(지웠는데 exit 2) → 재판정 absent → OK · 유니코드 꼴 경로 → 토큰을 묻기 전 중단 · 삭제 0
  Run-OCase 'DEL-18' 'acl 삭제 — 서버는 지웠는데 응답 유실(exit 2 · delLost) → 종료 코드를 믿지 않고 재판정 absent → OK(삭제 응답 exit=2 뒤 재판정)' 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld; $global:F['delLost'][$DACL.path] = 1 } -Inputs @($DACL.path, $TOK, $DACL.path) `
    -Want @("OK   $($DACL.path) — 모든 버전 · 메타데이터 삭제(No value found 확인 · 삭제 응답 exit=2 뒤 재판정) · 다음 = W-6(", "acl-delete $($DACL.path) = OK(모든 버전 · 메타데이터 삭제 — No value found 확인 · 삭제 응답 exit=2 뒤 재판정) · 다음 = W-6") -NotWant @('STOP ') -Post { & $delKeep @($DACL.path) }
  foreach ($c in @(@('DEL-19', ('kv/dev/dragonfly/' + [char]0x0430 + 'cl'), '키릴 а(U+0430)'), @('DEL-20', ('kv/dev/dragonfly/' + [char]0x200B + 'acl'), '폭 0 공백(U+200B)'),
      @('DEL-21', ('kv/dev' + [char]0xFF0F + 'dragonfly/acl'), '전각 /(U+FF0F)'), @('DEL-22', ('kv/dev/dragonfly/acl' + [char]0x0301), '끝 결합 부호(U+0301)'))) {
    Run-OCase $c[0] "acl 삭제 — 유니코드 꼴 경로($($c[2])) → Ordinal 대조로 허용 목록 밖 · 토큰을 묻기 전에 중단 · 지우기 0(KB2-3)" 'w6-acl-delete.ps1' -Vault -Summary $DELS -Setup { Seed-AclOld } -Inputs @($c[1], $TOK, $c[1]) -Expect '허용 목록(kv/dev/dragonfly/acl · kv/prod/dragonfly/acl) 밖의 입력이다' `
      -Want @('acl-delete (경로 선택 전) = 지우지 않았다') -Post { Check '보안 입력 0(토큰을 묻지 않았다) · metadata get · delete 0' (@($global:ReadLog | Where-Object { $_.secure }).Count -eq 0 -and (Ev-First 'vault:meta-get:') -lt 0); & $delKeep @() } }

  # ===== 수정 라운드 1 — 제어 문자(KB-7) · 환경 변수(KB-1 · KB-8) · 붙여넣기(KB-5) · 판정 사례(KA-1 · KA-2 · KA-3 · KB-9)
  Run-OCase 'CC-O2' 'O-2 — metadata 오류 문구에 터미널 제어열(OSC 52) → 판정 불가 줄은 제어 문자를 ? 로 · 화면 제어 문자 0(KB-7)' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Inputs @($TOK) `
    -Setup { Seed-IaDone 'dev'; Seed-IaDone 'prod'; $global:F['metaCtrl'][(IaPath 'dev' 'kafka')] = 1 } -Want @("JUDGE $(IaPath 'dev' 'kafka') — error — metadata 조회 exit=2 · * permission denied?]52;c;QUJD?")
  Run-OCase 'CC-W2' 'W-2 — Vault status 의 type · version 에 터미널 제어열 → OK 줄은 ? 로 · 쓰기는 정상(KB-7)' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; $global:F['status'] = 'ctrl' } -Inputs @('dev', $TOK, 'seed') `
    -Want @('OK   Vault 도달 · 초기화됨 · unsealed(seal type=ocikms?[2J · server 2.0.4?]52;c;QUJD?)', '판정: dev 4경로 준비 완료')
  Run-OCase 'CC-O6B' 'O-6 사후 — DRYRUN 거부 응답에 터미널 제어열 → 분류는 그대로(거부) · 출력은 ? 로 · PASS 7/7(KB-7)' 'o6-post-dragonfly-dryrun.ps1' -Allow $AV -Vault -ReadOnly -Summary $O6BS -Setup { Seed-Df; $global:F['kctrl'] = $true } -Inputs @('dev', $TOK) `
    -Want @("PASS ACL DRYRUN identity-admin ACL LIST → 거부(This user has no permissions to run the 'ACL LIST' command?]52;c;QUJD?) · 기대 거부", 'o6-post dev=PASS 7/7')
  Run-OCase 'CC-O5' 'O-5 b — x-request-id 에 터미널 제어열 → INFO 줄은 ? 로(KB-7)' 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S `
    -Setup { Seed-Tofu; $global:HttpFn = { param($req) $r = Http-Model $req @{ deployed = $true }; $r.xrid = 'req-x' + [char]27 + ']52;c;QUJD' + [char]7; $r } } -Inputs @('dev', 'b', $global:DeploySha) `
    -Want @('x-request-id = req-x?]52;c;QUJD?', 'o5b dev=PASS 8/8')
  foreach ($c in @(@('O1-09', 'TF_LOG', 'TRACE'), @('O1-10', 'TF_CLI_ARGS_output', '-no-color'), @('O1-11', 'TF_WORKSPACE', 'other'), @('O1-12', 'TF_DATA_DIR', 'C:\elsewhere'))) {
    Run-OCase $c[0] "O-1 — 환경 변수 $($c[1]) 있음 → tofu 를 부르기 전에 중단 · 이름만 낸다(KB-8)" 'o1-cf-values.ps1' -Allow @{ tofu = $true } -Summary $O1S -Setup { Seed-Tofu } -PreEnv @{ $c[1] = $c[2] } -Expect "tofu 동작을 바꾸는 환경 변수가 있다: $($c[1])" `
      -NotWant @($c[2]) -Post { Check 'tofu 호출 0' ($global:XArgv.Count -eq 0) } }
  foreach ($c in @(@('O5-13', 'HTTPS_PROXY', 'http://127.0.0.1:8888'), @('O5-14', 'https_proxy', 'http://127.0.0.1:8889'), @('O5-15', 'SSLKEYLOGFILE', 'C:\keylog.txt'), @('O5-16', 'CURL_CA_BUNDLE', 'C:\other-ca.pem'), @('O5-17', 'ALL_PROXY', 'socks5://127.0.0.1:1080'), @('O5-18', 'TF_LOG_PATH', 'C:\tf.log'))) {
    Run-OCase $c[0] "O-5 — 환경 변수 $($c[1]) 있음 → 읽기 · 보내기 전에 중단 · 이름만 낸다(KB-1 · KB-8)" 'o5-probe-identity-m2m.ps1' -Allow @{ tofu = $true; curl = $true } -Summary $O5S -Setup { Seed-Tofu } -PreEnv @{ $c[1] = $c[2] } -Expect "curl · tofu 동작을 바꾸는 환경 변수가 있다: $($c[1])" `
      -NotWant @($c[2]) -Post { Check 'tofu · curl 호출 0' ($global:XArgv.Count -eq 0) } }
  Run-OCase 'O2-07' 'O-2 — dev 웹훅 secret 42자(규칙 불충족) → W-2 전제 어긋남(KA-2 — 리뷰 변이 MX21 이 잡힌다)' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Inputs @($TOK) `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = $IAPW['dev-wh'].Substring(0, 42) }) 2 } `
    -Want @("JUDGE $(IaPath 'dev' 'webhook') — live v2 · 키 집합 일치 · secret=규칙 불충족(길이 42 — 43 기대) → W-2 전제 어긋남(secret = 규칙 불충족(길이 42 — 43 기대))", 'o2 W-2 전제: dev 9/10', '판정: W-2 전제 미충족')
  Run-OCase 'O2-08' 'O-2 — dev authentik jwks_url 만 계약 값 · issuer sentinel → W-2 전제 어긋남(KA-2 — MX22)' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Inputs @($TOK) `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'authentik') ([ordered]@{ client_id = $SENT; client_secret = $SENT; jwks_url = $JWKS; issuer = $SENT; api_token = $SENT }) 2 } `
    -Want @('W-2 전제 어긋남(jwks_url = 계약 값 · issuer = sentinel)', 'o2 W-2 전제: dev 9/10')
  Run-OCase 'O2-09' 'O-2 — dev 웹훅 secret 43자인데 서로 다른 글자 3 → 규칙 불충족 · 어긋남(KB-9)' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Inputs @($TOK) `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = $script:wlo }) 2; [void]$global:ExtraSecrets.Add($script:wlo) } `
    -Want @('W-2 전제 어긋남(secret = 규칙 불충족(서로 다른 글자 16 미만 — CSPRNG 값이 아니다))', 'o2 W-2 전제: dev 9/10')
  Run-OCase 'O2-P1' 'O-2 붙여넣기 모드(KB-5) — W-2 전 상태 20/20 · 블록 밖 범위에 새 변수 0(리뷰 변이 KM24 가 잡힌다)' 'o2-kv-judge.ps1' -Vault -ReadOnly -Summary $O2S -Paste -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod' } -Inputs @($TOK) `
    -Want @('o2 W-2 전제: dev 10/10 · prod 10/10')
  Run-OCase 'W2-25' 'W-2 dev — dev django secret_key(W009 꼴)가 prod 의 것과 같다 → 쌍 판정 STOP(KA-1 — 리뷰 변이 MX4 가 잡힌다)' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Inputs @('dev', $TOK, 'seed') -Expect '판정 단계에서 중단' `
    -Setup { Seed-IaDone 'prod'; Seed-IaBase 'dev'; Seed-Path (IaPath 'dev' 'django') ([ordered]@{ secret_key = $IAPW['prod-sk'] }) } `
    -Want @("STOP $(IaPath 'dev' 'django') — secret_key 가 prod 의 것과 같다 — dev ≠ prod 이어야 한다") -Post { Check '쓰기 0' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0) }
  Run-OCase 'W2-26' 'W-2 dev — 웹훅 secret 43자인데 서로 다른 글자 3 → live-mismatch STOP(KB-9) · 쓰기 0' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Inputs @('dev', $TOK, 'seed') -Expect '판정 단계에서 중단' `
    -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod'; Seed-Path (IaPath 'dev' 'webhook') ([ordered]@{ secret = $script:wlo }) 2; [void]$global:ExtraSecrets.Add($script:wlo) } `
    -Want @("STOP $(IaPath 'dev' 'webhook') — live-mismatch: secret 의 서로 다른 글자가 16 미만이다(CSPRNG 값이 아니다") -Post { Check '쓰기 0' ($global:PutCalls.Count -eq 0 -and $global:PatchCalls.Count -eq 0) }
  Run-OCase 'W2-P1' 'W-2 dev 붙여넣기 모드(KB-5) — 4경로 쓰기 · 블록 밖 범위에 새 변수 0' 'w2-kv-seed.ps1' -Allow @{ patch = $true } -Vault -Summary $W2S -Paste -Setup { Seed-IaBase 'dev'; Seed-IaBase 'prod' } -Inputs @('dev', $TOK, 'seed') `
    -Want @('판정: dev 4경로 준비 완료') -Post { Check-W2Done 'dev' }
  # KA-3: O-6 사전 「옛 규칙」은 옛 꼬리를 B2 로 바꾼 글자에 $lint = '' 일 때만 — 다른 결함이 함께면 그 사유로 FAIL · 기타 꼬리는 B2 꼬리 없음(리뷰 변이 MX5 가 잡힌다)
  $o6Cases = @(
    @('O6A-07', 'F12 전 default 줄(-@all) + 옛 꼬리', { Acl-Old 'dev' }, 'dev=FAIL(옛 규칙 꼬리 밖의 결함 — 금지 꼴: 1줄에 허용 밖 카테고리 토큰'),
    @('O6A-08', 'admin 줄에 허용 밖 카테고리(+@hyperloglog) + 옛 꼬리', { (Acl-T057 'dev').Replace(' ~* &* +@all', ' ~* &* +@all +@hyperloglog') }, 'dev=FAIL(옛 규칙 꼬리 밖의 결함 — 금지 꼴: 2줄에 허용 밖 카테고리 토큰'),
    @('O6A-09', 'admin 줄 없음 + 옛 꼬리', { $t = Acl-T057 'dev'; $ls = @($t.Substring(0, $t.Length - 1).Split("`n") | Where-Object { -not $_.StartsWith('USER admin ', [StringComparison]::Ordinal) }); ($ls -join "`n") + "`n" }, 'dev=FAIL(옛 규칙 꼬리 밖의 결함 — 줄 수 3(기대 4'),
    @('O6A-10', 'identity-admin 기타 꼬리(+@all -@admin) + sample-pod 옛 꼬리', { (Acl-T057 'dev').Replace($RULE_IA_T057 + "`n", $RULE_IA_T057 + ' -@admin' + "`n") }, 'dev=FAIL(B2 꼬리 없음(identity-admin 줄 — 옛 규칙 또는 다른 꼬리))'))
  foreach ($c in $o6Cases) {
    $script:o6t = & $c[2]
    Run-OCase $c[0] "O-6 사전 — $($c[1]) → 「옛 규칙」이 아니라 그 결함 사유로 FAIL(KA-3)" 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS -Inputs @($TOK) `
      -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = $script:o6t }); Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-For 'prod' (Live-Map 'prod')) }) } `
      -Want @($c[3], 'prod=PASS(B2)') -NotWant @('dev=FAIL(옛 규칙 — UD-9') }
  Run-OCase 'O6A-11' 'O-6 사전 — 기타 꼬리에 「옛 규칙 꼬리 밖의 결함」 문구가 붙지 않는다(MX5 표적 — 꼬리 분류 조건)' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS -Inputs @($TOK) `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'dev').Replace($RULE_IA_T057 + "`n", $RULE_IA_T057 + ' -@admin' + "`n") }); Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-For 'prod' (Live-Map 'prod')) }) } `
    -NotWant @('옛 규칙 꼬리 밖의 결함') -Want @('identity-admin 꼬리 = 기타 꼬리')
  Run-OCase 'O6A-P1' 'O-6 사전 붙여넣기 모드(KB-5) — 옛 규칙 dev · prod · 블록 밖 범위에 새 변수 0' 'o6-pre-dragonfly-acl.ps1' -Vault -ReadOnly -Summary $O6AS -Paste -Inputs @($TOK) `
    -Setup { Seed-Path $DACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'dev') }); Seed-Path $PACL.path ([ordered]@{ 'users.acl' = (Acl-T057 'prod') }) } -Want @('o6-pre dev=FAIL(옛 규칙 — UD-9 적용 전이면 기대한 FAIL')
  }
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
  foreach ($k in @($NetEnvSaved.Keys)) { Set-Item -LiteralPath ('Env:' + $k) -Value $NetEnvSaved[$k] }
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
