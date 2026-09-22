param([string]$Only = '', [int]$Throttle = 6, [switch]$KeepDirs)
# ===== T045 G4 변이 시험 — "하네스가 정말로 결함을 잡는가" =====
# 블록 사본에 결함을 하나씩 심고 harness-g4.ps1 을 그 사본에 대해 돌린다. 모든 변이는 FAIL(exit 1)로 잡혀야 한다.
# 실행: pwsh -NoProfile -File mutants-g4.ps1   ·   하나만: -Only M07   ·   직렬: -Throttle 1
# 2라운드: 적대적 검증자 A 의 변이 39개(A**·B**)를 흡수했다. A 는 줄 번호로 앵커를 잡았지만 여기서는 전부
#   내용 앵커('text' = 파일 안에 정확히 1회 · 'line' = 그 문자열을 포함하는 occ 번째 줄)로 바꿨다 — 줄이 밀려도 살아남는다.
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Join-Path ([IO.Path]::GetTempPath()) ('t045-g4-mut-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $root -Force
$M = [System.Collections.ArrayList]::new()
function Mut { param($id, $file, $desc, $mode, $from, $to, $occ = 1, [bool]$lock = $false)
  [void]$script:M.Add([pscustomobject]@{ id = $id; file = $file; desc = $desc; mode = $mode; from = $from; to = $to; occ = $occ; lock = $lock }) }
$A = 'g4-adopt.ps1'
$R = 'g4-restore.ps1'
# ---- 판정 단언 제거(가짜 PASS 를 만드는 변이)
Mut 'M01' $A '인수 후 값 해시 판정 제거' 'text' 'if (-not [string]::Equals($postHash, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M02' $A '인수 후 UID 판정 제거' 'text' 'if (-not [string]::Equals($postUid, $preUid, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M03' $A 'ownerReferences 판정 제거' 'text' 'if (-not [string]::IsNullOrWhiteSpace($own)) {' 'if ($false) {'
Mut 'M04' $A 'managed 라벨(양성 증거) 판정 제거' 'text' "if (-not [string]::Equals(`$mg1, 'true', [StringComparison]::Ordinal)) {" 'if ($false) {'
Mut 'M05' $A 'data-hash 하드 판정 제거(ESO 쓰기 증거 없이 통과)' 'text' 'if ([string]::IsNullOrWhiteSpace($dh)) {' 'if ($false) {'
Mut 'M06' $A 'Secret 의 Argo tracking 복사 판정 제거' 'text' 'if (-not [string]::IsNullOrWhiteSpace($trkS)) {' 'if ($false) {'
Mut 'M07' $A 'ES tracking-id 소유 Application 판정 제거' 'text' "if (-not [string]::Equals(([string]`$trkE -split ':')[0], `$OWNER, [StringComparison]::Ordinal)) {" 'if ($false) {'
Mut 'M08' $A 'platform-cloudflared 의 external-secrets.io 소유 판정 제거' 'text' "if (`$res.Contains('external-secrets.io/')) {" 'if ($false) {'
Mut 'M09' $A '파드 불변 판정 제거' 'text' 'elseif (-not [string]::Equals($podPost, $podPre, [StringComparison]::Ordinal)) {' 'elseif ($false) {' 1 $true
Mut 'M10' $A '키 집합(TUNNEL_TOKEN 하나) 검사 제거' 'text' "if (-not [string]::Equals(`$keys0, `$KEY, [StringComparison]::Ordinal)) {" 'if ($false) {' 1 $true
Mut 'M11' $A 'SecretSyncedError 고착 판정 제거' 'text' 'if ($errN -ge 3) {' 'if ($false) {'
Mut 'M12' $A '새 파드 Ready 타임아웃 단언 제거' 'text' 'if ([string]::IsNullOrWhiteSpace($newName)) {' 'if ($false) {' 1 $true
# ---- 파드 삭제 가드 제거
Mut 'M13' $A '남길 파드 Ready 가드 제거(양쪽 커넥터를 잃을 수 있다)' 'text' "if (-not [string]::Equals(`$sv0.ready, 'True', [StringComparison]::Ordinal)) {" 'if ($false) {' 1 $true
Mut 'M14' $A '삭제 직전 값 해시 재확인 제거(정지점 사이 변경을 놓친다)' 'text' 'if (-not [string]::Equals($hDel, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M15' $A '삭제 직전 UID 재확인 제거' 'text' 'if (-not [string]::Equals($uDel, $preUid, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M16' $A '삭제 직전 남길 파드 재확인 제거' 'text' "if (`$sv1.Count -ne 1 -or -not [string]::Equals(`$sv1[0].ready, 'True', [StringComparison]::Ordinal) -or -not [string]::Equals([string]`$sv1[0].sig, `$survSig, [StringComparison]::Ordinal)) {" 'if ($false) {' 1 $true
Mut 'M17' $A '드릴 대기 중 남은 파드 서명 불변 검사 제거' 'text' 'if (-not [string]::Equals([string]$sv[0].sig, $survSig, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
# M18 앵커 정정(1라운드는 occ=2 로 3) 의 nopods 경고 줄을 맞혀 "삭제 금지 가드"를 시험하지 못했다 — 4) 의 elseif 가 대상이다.
Mut 'M18' $A 'nopods 실행에서도 파드를 삭제하도록(재실행 누적 삭제)' 'text' 'elseif ([string]::IsNullOrWhiteSpace($podPre)) {' 'elseif ($false) {' 1 $true
Mut 'M19' $A '인수 뒤 시작한 Ready 파드가 있어도 또 드릴(두 번째 삭제)' 'text' 'if ($already.Count -ge 1) {' 'if ($false) {' 1 $true
Mut 'M20' $A '삭제 대상을 2개로(남은 커넥터까지 교체)' 'line' '& $kdel $target | Out-Null' "        & `$kdel `$target | Out-Null`n        & `$kdel `$survivor | Out-Null" 1 $true
Mut 'M21' $A 'rollout restart 삽입(전면 재시작)' 'line' '& $kdel $target | Out-Null' "        & kubectl '-n' `$NS 'rollout' 'restart' 'deploy/cloudflared' | Out-Null" 1 $true
Mut 'M22' $A '조회 헬퍼로 삭제 우회($kq 에 delete 동사)' 'line' '& $kdel $target | Out-Null' "        & `$kq '드릴 삭제' @('-n', `$NS, 'delete', 'pod', `$target) | Out-Null" 1 $true
Mut 'M23' $A '드릴 대상 선정을 이름 순으로 되돌림(옛 커넥터를 지울 수 있다)' 'text' '$ord = @($pd.items | ForEach-Object { "$($_.start)|$($_.name)" })' '$ord = @($pd.items | ForEach-Object { "$($_.name)|$($_.name)" })' 1 $true
Mut 'M24' $A '대상·생존 뒤바꿈(가장 이른 파드를 지운다)' 'text' "`$survivor = [string]((`$ord[0] -split '\|')[1])" "`$survivor = [string]((`$ord[1] -split '\|')[1])" 1 $true
# ---- 정지점·입력 방어 제거
Mut 'M25' $A '드릴 정지점 제거(사람 승인 없이 삭제)' 'line' '& $stop $m4 $w4' '        $null = 0' 1 $true
Mut 'M26' $A '0) break-glass 정지점 제거' 'line' '& $stop $m0 $w0' '    $null = 0' 1 $true
Mut 'M27' $A '정지점 단어 비교를 Ordinal → -eq(대소문자 무시)' 'text' 'if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }' 'if (-not ([string]$a -eq $word)) { throw "정지점에서 중단: $msg" } }'
Mut 'M28' $A 'resume 파드 서명의 빈 입력 거부 제거(빈 Enter 로 게이트 포기)' 'text' "if ([string]::IsNullOrWhiteSpace(`$podPre)) { throw '빈 입력 — 중단(파드 서명이 없으면 nopods 를 입력한다)' }" '$null = 0'
Mut 'M29' $A '창 A boot_id 대조 제거(열린 세션을 확인하지 않는다)' 'text' 'if (-not [string]::Equals($typed, $bootPre, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M30' $A '1P) PM 토큰 해시 검사 제거' 'text' 'if (-not [string]::Equals($pmHash, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {'
# ---- 비밀 취급 결함
Mut 'M31' $A '인수 전 값을 화면에 출력' 'line' '$preHash = & $sha ([string]$snap[3])' "      `"인수 전 값: `$([string]`$snap[3])`"`n      `$preHash = & `$sha ([string]`$snap[3])"
Mut 'M32' $A '해시 대신 평문을 기준값으로 보관(해시 비교 제거)' 'text' '$preHash = & $sha ([string]$snap[3])' '$preHash = [string]$snap[3]'
Mut 'M33' $A '1P) 토큰을 -AsSecureString 없이 평문으로 읽는다' 'text' '$ss = Read-Host $prompt -AsSecureString' '$ss = Read-Host $prompt'
Mut 'M34' $R '복구 토큰을 -AsSecureString 없이 평문으로 읽는다' 'text' '$ss = Read-Host $prompt -AsSecureString' '$ss = Read-Host $prompt'
Mut 'M35' $A 'finally 의 정리(Remove-Variable) 제거' 'line' 'Remove-Variable snap, b64, hNow' '    $null = 0'
# ---- fail-closed 무력화
Mut 'M36' $A '조회 3회 실패를 빈 값으로 통과시킨다(실패를 없음으로 읽는다)' 'line' 'throw "kubectl 조회 실패(exit=$rc · 3회 시도): $desc' "          return '' }" 1 $true
Mut 'M37' $A '단일 GET 스냅샷의 managed 라벨 가드 제거(가짜 기준값)' 'text' 'if (-not [string]::IsNullOrWhiteSpace([string]$snap[1])) {' 'if ($false) {' 1 $true
Mut 'M38' $A 'auth can-i 의 허용 종료 코드 제거(no 를 조회 실패로 읽는다)' 'text' "(@('auth', 'can-i') + @(`$v -split ' ') + @('-n', `$NS)) @(0, 1))).Trim()" "(@('auth', 'can-i') + @(`$v -split ' ') + @('-n', `$NS)))).Trim()"
Mut 'M39' $A '드릴 대기 조회 실패를 즉시 throw(검증만 잃고 재실행을 부른다)' 'line' "try { `$pn = & `$pods '드릴 대기' } catch" "          `$pn = & `$pods '드릴 대기'"
Mut 'M40' $A '라벨 셀렉터 제거(무관한 파드를 커넥터로 센다)' 'text' "'get', 'pods', '-l', 'app=cloudflared', '-o'" "'get', 'pods', '-o'"
Mut 'M41' $A 'oci 읽기 전용 프로파일 검사 제거' 'text' "if ([string]::Equals(`$ociProf, 'svc-verify', [StringComparison]::Ordinal) -or [string]::Equals([string]`$env:OCI_CLI_AUTH, 'security_token', [StringComparison]::Ordinal)) {" 'if ($false) {'
# ---- 회계·문면 결함(운영자 오도)
Mut 'M42' $A '변경 로그를 삭제 요청 뒤로(중단 시 "변경 0건" 거짓말)' 'line' '[void]$changes.Add("kubectl -n $NS delete pod' '      $null = 0'
Mut 'M43' $A '삭제를 블로킹 대기로 되돌림(--wait=false 제거)' 'text' "'--wait=false' '--request-timeout=30s'" "'--timeout=90s'"
Mut 'M44' $A '조회 실패 문면을 "파드는 건드리지 않았다"로 고정(거짓 문장)' 'text' "`$did = '이 실행은 아직 아무것도 바꾸지 않았다'" "`$did = '파드는 건드리지 않았다'"
Mut 'M45' $A '판정하지 않은 항목도 합격 문면에 넣는다(resume·nopods 인데 "파드 불변")' 'text' "`$podNote = '파드 불변은 판정하지 않았다(resume · 기준 서명 없음)' }" "`$podNote = '파드 불변' }"
Mut 'M45b' $A '판정하지 않은 항목도 합격 문면에(이전 드릴 결과인데 "파드 불변")' 'text' "`$podNote = '파드 불변은 판정하지 않았다(이전 실행의 드릴 결과 — 기준 1개 유지 · 새 파드 Ready)' }" "`$podNote = '파드 불변' }"
Mut 'M46' $A '머지 입력 뒤 미판정 중단 경고 제거' 'line' 'if ($mergeAsked -and -not $judged' '    if ($false) {'
# ---- 복구 블록
Mut 'M47' $R 'PM 토큰 해시 게이트 제거(틀린 값을 자기 손으로 쓴다)' 'text' 'if (-not [string]::Equals((& $sha $b64), $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M48' $R '토큰 형식(ASCII 인쇄 문자) 검사 제거' 'text' "if (-not [regex]::IsMatch(`$tok, '\A[\x21-\x7E]+\z')) {" 'if ($false) {'
Mut 'M49' $R '클립보드 기록 검사 제거' 'line' "if (`$ch -ne 0) { throw '클립보드 기록이 켜져 있음" '    $null = $ch'
Mut 'M50' $R 'apply 회계를 호출 뒤로(쓰기 시도를 숨긴다)' 'line' '[void]$changes.Add("kubectl apply --server-side secret/' '      $null = 0'
Mut 'M51' $R 'Git 선언(selfHeal) 검사 제거 — ES 부재를 "개입 멈춤"으로 읽는다' 'text' "`$gitLeft = (`$argoOk -and `$argoEs.Contains(`"`$NS/`$ESN=`") -and -not `$argoEs.Contains(`"`$NS/`$ESN=true`"))" '$gitLeft = $false' 1 $true
Mut 'M52' $R '모호한 apply 실패를 "아무것도 쓰지 않았다"로 단정' 'text' 'elseif ($attempted -or $changes.Count -gt 0) {' 'elseif ($false) {'
Mut 'M53' $R '토큰 검사를 -cnotmatch 로 되돌림($Matches 에 평문 잔류)' 'text' "if (-not [regex]::IsMatch(`$tok, '\A[\x21-\x7E]+\z')) {" "if (`$tok -cnotmatch '\A[\x21-\x7E]+\z') {"
# ================================================================ 검증자 A 의 변이 39개(2라운드 흡수)
# ---- 잠금으로 이어지는 변이(adopt)
Mut 'A01' $A '3) 인수 판정의 값 변경 감지를 경고로 강등(덮인 채 드릴까지 진행)' 'line' 'throw ''⚠ 인수 뒤 터널 값이 바뀌었다' "      Write-Warning '값이 바뀌었다(변이: 경고로 강등)' }" 1 $true
Mut 'A02' $A '삭제 직전 값 재확인 실패를 경고로 강등(값이 덮인 채 파드 삭제)' 'line' 'throw ''⚠ 정지점에서 기다리는 사이에 터널 값이 바뀌었다' "          Write-Warning '정지점 사이 값 변경(변이: 경고로 강등)' }" 1 $true
Mut 'A03' $A '2) 감시 루프의 값 해시 검사 제거(대기 중 감시 없음)' 'text' 'if (-not [string]::Equals($hNow, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'A04' $A '2) 감시 루프의 UID 검사 제거' 'text' 'if (-not [string]::Equals($uNow, $preUid, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'A05' $A '폴링 타임아웃을 PASS 로 처리' 'text' 'if (-not $synced) {' 'if ($false) {' 1 $true
Mut 'A06' $A 'SecretSynced 비교를 StartsWith 로 느슨하게(SecretSyncedError 도 통과)' 'text' "if ([string]::Equals(`$reason, 'SecretSynced', [StringComparison]::Ordinal)) { `$synced = `$true; break }" "if (`$reason.StartsWith('SecretSynced')) { `$synced = `$true; break }" 1 $true
Mut 'A07' $A 'ES SecretSyncedError 고착을 경고로 강등' 'line' "throw 'ES 가 SecretSyncedError 로 굳었다" "            Write-Warning 'ES SecretSyncedError(변이: 경고로 강등)' } }" 1 $true
Mut 'A08' $A '남길 파드 Ready 가드가 삭제 대상 쪽을 본다(엉뚱한 파드 확인)' 'text' "if (-not [string]::Equals(`$sv0.ready, 'True', [StringComparison]::Ordinal)) {" "if (-not [string]::Equals(`$tg0.ready, 'True', [StringComparison]::Ordinal)) {" 1 $true
Mut 'A09' $A '새 파드 Ready 조건 제거(뜨기만 하면 OK)' 'text' "if (`$nw.Count -eq 1 -and [string]::Equals([string]`$nw[0].ready, 'True', [StringComparison]::Ordinal)) {" "if (`$nw.Count -eq 1) {" 1 $true
Mut 'A10a' $A '삭제 셀렉터를 --all 로 넓힘(이름 없음)' 'text' "& kubectl '-n' `$NS 'delete' 'pod' `$pod '--wait=false'" "& kubectl '-n' `$NS 'delete' 'pod' '--all' '--wait=false'" 1 $true
Mut 'A10b' $A '삭제 셀렉터를 -l app=cloudflared 로 넓힘' 'text' "& kubectl '-n' `$NS 'delete' 'pod' `$pod '--wait=false'" "& kubectl '-n' `$NS 'delete' 'pod' '-l' 'app=cloudflared' '--wait=false'" 1 $true
Mut 'A11' $A '삭제 인자에 이름 2개(대상 + 남길 파드)' 'text' "& kubectl '-n' `$NS 'delete' 'pod' `$pod '--wait=false'" "& kubectl '-n' `$NS 'delete' 'pod' `$pod `$survivor '--wait=false'" 1 $true
Mut 'A12' $A '로그 헬퍼($klog) 안에 scale --replicas=0 삽입(헬퍼 안 kubectl 이라 lint 통과?)' 'line' "& kubectl '-n' `$NS 'logs' `$pod" "      `$null = & kubectl '-n' `$NS 'scale' 'deploy/cloudflared' '--replicas=0' '--request-timeout=15s'; `$out = & kubectl '-n' `$NS 'logs' `$pod '--tail=120' '--request-timeout=15s'" 1 $true
Mut 'A13' $A 'ssh 원격 명령으로 전면 재시작(kubectl 밖 변경 경로)' 'text' "'ssh-a' 'hostname'" "'ssh-a' 'sudo k3s kubectl -n cloudflared rollout restart deploy/cloudflared; hostname'" 1 $true
Mut 'A13b' $A 'oci 를 읽기 조회가 아닌 NSG 변경 호출로 바꾼다(kubectl 밖 변경 경로)' 'text' "& oci 'iam' 'region' 'list' '--query' 'length(data)'" "& oci 'network' 'nsg' 'rules' 'add' '--nsg-id' 'ocid1.nsg.oc1..x'" 1 $true
Mut 'A14' $A '파드 서명에서 restartCount 제외(in-place 재시작을 못 본다)' 'text' 'sig = "$([string]$p[0])|$([string]$p[1])|$([string]$p[2])"' 'sig = "$([string]$p[0])|0|$([string]$p[2])"' 1 $true
Mut 'A15' $A 'resume: 운영자 입력 preHash 를 라이브 값 해시로 덮어씀(가짜 PASS)' 'text' "if (-not [regex]::IsMatch(`$preHash, '\A[0-9A-F]{64}\z')) { throw 'preHash 형식이 아니다(64자리 대문자 16진수) — 중단' }" "if (-not [regex]::IsMatch(`$preHash, '\A[0-9A-F]{64}\z')) { throw 'preHash 형식이 아니다(64자리 대문자 16진수) — 중단' }; `$preHash = & `$sha (& `$txt (& `$kq '변이: 라이브 값으로 기준값 대체' @('-n', `$NS, 'get', 'secret', `$SEC, '-o', `"jsonpath={.data.`$KEY}`"))).Trim()" 1 $true
# 검증자 A 의 A20 과 정정된 M18 은 **같은 줄**을 겨눈다(A 의 지적 8 이 옳았다). 위험한 방향(가드 무력화 → 누적 삭제)은
# M18 이 맡고, 여기서는 반대 방향(가드가 항상 참 → 드릴이 영영 일어나지 않는다)을 시험해 그 줄의 양쪽을 모두 고정한다.
Mut 'A20' $A '4) nopods 분기를 항상 타게 만든다(드릴 불가 · M18 의 반대 방향으로 같은 줄을 고정)' 'text' 'elseif ([string]::IsNullOrWhiteSpace($podPre)) {' 'elseif ($true) {' 1 $true
Mut 'A22' $A '파드 불변 실패를 경고로 강등' 'line' 'throw "파드가 바뀌었다(전= $podPre' "        Write-Warning '파드가 바뀌었다(변이: 경고로 강등)' } }" 1 $true
Mut 'A30' $A '5) 노드 Ready 2 실패를 경고로 강등' 'line' 'if ($ready2 -ne 2) {' '    if ($ready2 -ne 2) { Write-Warning "노드 Ready 아님(변이: 경고로 강등)" }'
# ---- fail-closed · 정지점 · 비밀 취급(adopt)
Mut 'A16' $A '$stop 의 입력 버퍼 비움 제거(안전 규칙 1)' 'line' 'try { $Host.UI.RawUI.FlushInputBuffer() } catch { }' '      $null = 0'
Mut 'A17' $A '$kq 의 --request-timeout 제거(터널이 멎으면 무한 대기)' 'text' "`$out = & kubectl @ka '--request-timeout=10s'" '$out = & kubectl @ka'
Mut 'A18' $A '0) 클러스터 정체 확인 제거' 'text' "if (-not (@(`$nodes) | Where-Object { [string]::Equals([string]`$_, 'node/joshtech-api', [StringComparison]::Ordinal) })) {" 'if ($false) {'
Mut 'A19' $A '1) 머지 전 파드 Ready 확인 제거' 'line' 'if (-not [string]::Equals($p.ready,' "        if (`$false) { throw 'x' } }"
Mut 'A26' $A '폴링의 ES 출현 조회 실패(exit 1)를 "아직 없음"으로 읽는다(fail-open)' 'text' "& `$kq 'ES 출현 확인' @('-n', `$NS, 'get', 'externalsecret', `$ESN, '--ignore-not-found', '-o', 'name')" "& `$kq 'ES 출현 확인' @('-n', `$NS, 'get', 'externalsecret', `$ESN, '--ignore-not-found', '-o', 'name') @(0, 1)" 1 $true
Mut 'A26b' $A 'resume 의 ES 존재 확인 실패를 "ES 없음(인수 해제 상태)"으로 읽는다(fail-open · 2라운드에서 발견)' 'text' "& `$kq 'ES 존재 확인(resume)' @('-n', `$NS, 'get', 'externalsecret', `$ESN, '--ignore-not-found', '-o', 'name')" "& `$kq 'ES 존재 확인(resume)' @('-n', `$NS, 'get', 'externalsecret', `$ESN, '--ignore-not-found', '-o', 'name') @(0, 1)"
Mut 'A28' $A '1P) 비밀 입력 직후 클립보드 비움 제거(finally 의 1회만 남는다)' 'line' "try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 토큰이" '      $null = 0'
# ---- 규약(규칙 4·5) 회귀
Mut 'A31' $A 'finally 안의 요약 머리줄을 성공 스트림 출력으로(규칙 5 위반)' 'text' "Write-Host '--- G4 단계 요약(런북 §3 기록용) ---'" "'--- G4 단계 요약(런북 §3 기록용) ---'"
Mut 'A32' $A 'finally 의 정리를 출력 뒤로(규칙 5: 정리 먼저)' 'text' "    Remove-Variable snap, b64, hNow, uNow, hDel, uDel, postHash, postUid, own, trkS, trkE, res, dh, nd, so, sp, oo, out, raw, pmHash, tok -ErrorAction SilentlyContinue`n    try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 1P·1R 에서 토큰을 붙여 넣었다면 Win+V 로 확인하고 직접 비운다' }`n    Write-Host ''" "    Write-Host ''`n    Remove-Variable snap, b64, hNow, uNow, hDel, uDel, postHash, postUid, own, trkS, trkE, res, dh, nd, so, sp, oo, out, raw, pmHash, tok -ErrorAction SilentlyContinue`n    try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 1P·1R 에서 토큰을 붙여 넣었다면 Win+V 로 확인하고 직접 비운다' }"
Mut 'A33' $A '$ErrorActionPreference = Stop 제거(비종료 오류가 다음 문으로 흘러간다)' 'line' "`$ErrorActionPreference = 'Stop'" '  $null = 0'
Mut 'A34' $A '$PSNativeCommandUseErrorActionPreference 끄기 제거' 'line' '$PSNativeCommandUseErrorActionPreference = $false' '  $null = 0'
Mut 'A37' $A '삭제 헬퍼에 --force --grace-period=0 추가(필수 플래그 lint 는 금지 플래그를 보지 않는다)' 'text' "& kubectl '-n' `$NS 'delete' 'pod' `$pod '--wait=false'" "& kubectl '-n' `$NS 'delete' 'pod' `$pod '--force' '--grace-period=0' '--wait=false'"
Mut 'A38' $A '인수 전 값의 앞 16자만 화면에 출력(부분 누출)' 'line' '$preHash = & $sha ([string]$snap[3])' "      `"변이: 값 앞 16자 `$(([string]`$snap[3]).Substring(0, 16))`"`n      `$preHash = & `$sha ([string]`$snap[3])"
# ---- 복구 블록
Mut 'B01' $R '(복구) 쓰기 뒤 값 되읽기 판정 제거' 'text' 'if (-not [string]::Equals($newHash, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'B02' $R '(복구) 쓰기 뒤 UID 불변 판정 제거' 'text' 'if (-not [string]::Equals($newUid, $curUid, [StringComparison]::Ordinal)) {' 'if ($false) {'
Mut 'B03' $R '(복구) --force-conflicts 제거(ESO field manager 와 충돌하면 비상 복구가 실패)' 'text' "'apply' '--server-side' '--force-conflicts'" "'apply' '--server-side'" 1 $true
Mut 'B04' $R '(복구) 해시 게이트가 preHash 를 자기 자신과 비교' 'text' 'if (-not [string]::Equals((& $sha $b64), $preHash, [StringComparison]::Ordinal)) {' 'if (-not [string]::Equals($preHash, $preHash, [StringComparison]::Ordinal)) {' 1 $true
Mut 'B05' $R '(복구) ES 가 살아 있어도 단어가 restore' 'line' "`$word = 'temporary' }" "      `$word = 'restore' }" 1 $true
Mut 'B06' $R '(복구) 페이로드를 argv 로도 넘긴다' 'text' "'--request-timeout=30s' '-f' '-'" "'--request-timeout=30s' '-f' '-' `"--note=`$json`""
Mut 'B09' $R '(복구) UID 변경 정지점 제거' 'line' "& `$stop '3u) UID 가 달라진 것을 알고도" '        $null = 0 }'
Mut 'B11' $R '(복구) 비밀 입력 직후 클립보드 비움 제거(finally 에만 남는다)' 'line' "try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드 비우기 실패 — 토큰이" '      $null = 0'
# ================================================================ 검증자 A 3라운드의 변이 25개(N**) — 2라운드에 새로 생긴 코드를 겨눈다
# (no-breakglass 분기 · 이전 드릴 감지 · 키 집합 진단 · restore 의 최선 노력 Argo 조회 · 1R 의 PM 유도 preHash).
# 그중 7개(N07·N08·N12·N21∼N24)가 3라운드 검증에서 ESCAPED 였다 — 시나리오 G4-38∼G4-41 이 그 구멍을 메운다.
Mut 'N01' $A '4) 의 noGlass 삭제 거부 제거(확인된 복구 경로 0 인데 파드를 지운다)' 'line' 'if ($noGlass) {' '    if ($false) {' 4 $true
Mut 'N02' $A '둘 다 실패인데 단어를 no-oci 로 되돌림(문면과 단어가 갈리지 않는다)' 'text' "if (`$noGlass) { `$w0 = 'no-breakglass' }" "if (`$noGlass) { `$w0 = 'no-oci' }" 1 $true
Mut 'N03' $A 'noGlass 판정을 항상 거짓으로(둘 다 실패해도 평소 경로)' 'text' '$noGlass = ((-not $sshPre) -and (-not $ociPre))' '$noGlass = $false' 1 $true
Mut 'N04' $A 'noGlass 정지점 문면을 평소 문면으로(삭제 거부를 알리지 않는다)' 'line' "`$m0 = '0) ⚠ break-glass" "      `$m0 = '0) 위 실측을 인수한다' }"
Mut 'N05' $A 'noGlass SKIP 의 단계 기록을 "완료"로(런북에 거짓 기록)' 'line' '$log[''4) 파드 1개 드릴''] = "거부(break-glass' '      $log[''4) 파드 1개 드릴''] = "완료 — 현재 파드: $podPost" }'
Mut 'N06' $A '이전 드릴 판정에서 "ES 생성 뒤 시작" 조건 제거(진짜 교체도 드릴 결과로 읽는다)' 'text' '[string]::CompareOrdinal([string]$_.start, $esAt0) -gt 0 -and ' '' 1 $true
Mut 'N07' $A '이전 드릴 판정에서 새 파드 Ready 조건 제거(NotReady 커넥터를 증명으로 읽는다)' 'text' "-and [string]::Equals([string]`$_.ready, 'True', [StringComparison]::Ordinal) })" ' })' 1 $true
Mut 'N08' $A '이전 드릴 판정 조건을 fresh 하나로 축소(파드 수·kept 검사 제거)' 'text' 'if (@($pq.items).Count -eq 2 -and $kept.Count -eq 1 -and $fresh.Count -eq 1) {' 'if ($fresh.Count -ge 1) {' 1 $true
Mut 'N09' $A 'ES 생성 시각 기준을 epoch 로(모든 새 파드가 "드릴 결과")' 'text' '$esAt0 = & $esAtGet' "`$esAt0 = '1970-01-01T00:00:00Z'" 1 $true
Mut 'N10' $A '4) 의 이전 드릴 SKIP 분기 제거(드릴을 한 번 더 한다)' 'line' 'elseif ($drilled) {' '    elseif ($false) {' 2 $true
# occ 를 하나씩 민다 — 4라운드에서 noGlass 분기에 `if ($preDrilled -or $drilled) { $podDrill = $podPost }` 가 생겨 occ 1 을 차지한다(B3-05).
Mut 'N11' $A 'drilled: SKIP 에서 드릴 후 서명 기록 제거(다음 실행의 1R 입력이 사라진다)' 'line' '$podDrill = $podPost' '      $null = 0' 2
Mut 'N11b' $A '이전 드릴 SKIP 에서 드릴 후 서명 기록 제거(같은 결함의 두 번째 갈래)' 'line' '$podDrill = $podPost' '      $null = 0' 3
Mut 'N12' $A '드릴 정지점 분기의 키 집합 조회 실패를 "정상"으로 읽는다(fail-open)' 'line' 'try { $keysNow = & $keyset } catch' "          try { `$keysNow = & `$keyset } catch { `$keysNow = `$KEY }" 3
Mut 'N13' $A '폴링 분기의 키 집합을 항상 정상으로 고정(매핑 오류를 kv 오류로 오도)' 'line' 'try { $keysNow = & $keyset } catch' "        `$keysNow = `$KEY" 1
Mut 'N14' $A '복구 안내의 "조회 실패" 분기를 항상 타게(정상 키를 미확인으로 오도)' 'text' "elseif ([string]::Equals(`$keysNow, '(조회 실패)', [StringComparison]::Ordinal)) {" 'elseif ($true) {'
Mut 'N15' $A '복구 안내에서 키 집합 줄 자체를 제거(감별 근거 소실)' 'line' 'Write-Host "   지금 Secret 의 키 집합:' '      $null = 0'
Mut 'N16' $A '키 목록 조회를 키가 아니라 **값**으로(복구 안내에 토큰이 찍힌다)' 'line' "'go-template={{range `$k,`$v := .data}}{{`$k}}{{`"\n`"}}{{end}}'" "      `$k = @(@(& `$kq '키 목록' @('-n', `$NS, 'get', 'secret', `$SEC, '-o', `"jsonpath={.data.`$KEY}`")) | ForEach-Object { ([string]`$_).Trim() } | Where-Object { `$_.Length -gt 0 })" 1 $true
Mut 'N17' $R '(복구) Argo 조회 성공 판정을 무조건 참으로(빈 응답을 "선언 없음"으로 읽는다)' 'text' '$argoOk = $argoEs.Contains($CTRL)' '$argoOk = $true' 1 $true
Mut 'N18' $R '(복구) Argo 조회 실패를 "선언 없음"으로 읽는다(catch 에서 argoOk=true)' 'text' "catch { `$argoEs = ''; `$argoOk = `$false }" "catch { `$argoEs = ''; `$argoOk = `$true }" 1 $true
Mut 'N19' $R '(복구) 최선 노력을 되돌려 Argo 조회 실패가 복구를 막게 한다(B-3 회귀)' 'text' "catch { `$argoEs = ''; `$argoOk = `$false }" 'catch { throw }'
Mut 'N20' $R '(복구) 양성 대조 행을 빈 문자열로(무엇이 와도 "조회가 됐다")' 'text' "`$CTRL = 'cert-manager/cloudflare-dns-token='" "`$CTRL = ''" 1 $true
Mut 'N21' $A '1R) pm 분기의 클립보드 기록 검사 제거' 'line' 'if ($null -eq $ch0 -or $ch0 -ne 0)' '        $null = 0'
Mut 'N22' $A '1R) pm 분기가 토큰을 평문 Read-Host 로 받는다' 'text' "(& `$readSecret 'PM 의 터널 토큰 원본(화면에 남지 않는다 · 해시만 남긴다)')" "(& `$ask 'PM 의 터널 토큰 원본')" 1 $true
Mut 'N23' $A '1R) pm 분기가 base64 없이 해시를 유도(기준값이 어긋난다)' 'text' "`$preHash = & `$sha ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((& `$readSecret 'PM 의 터널 토큰 원본(화면에 남지 않는다 · 해시만 남긴다)').Trim())))" "`$preHash = & `$sha ((& `$readSecret 'PM 의 터널 토큰 원본(화면에 남지 않는다 · 해시만 남긴다)').Trim())" 1 $true
Mut 'N24' $A '1R) pm 분기의 "미검증 전제" 경고 제거' 'line' "Write-Warning 'preHash 를 PM 원본에서 유도했다" '        $null = 0 }'
Mut 'N25' $R '(복구) 쓰기 성공을 곧 확인 성공으로(verified 를 apply 직후에 세운다)' 'text' '$wrote = $true' '$wrote = $true; $verified = $true'
# ================================================================ 3라운드에 새로 생긴 가드의 변이(P**)
# drilled: 접두어 · 인수 뒤 시작한 파드 SKIP(Ready 무관) · first-drill 단어 · SKIP 분기의 Ready 경고 · PM 유도 기준값 표기.
Mut 'P01' $A 'drilled: 접두어 인식 제거(운영자 선언이 무시된다 → 재인수에서 두 번째 삭제)' 'text' "if (`$podPre.StartsWith('drilled:', [StringComparison]::Ordinal)) {" 'if ($false) {' 1 $true
Mut 'P02' $A '4) 의 drilled: SKIP 분기 제거(3) 의 같은 조건과 구분하려고 줄 앵커를 쓴다)' 'line' 'elseif ($preDrilled) {' '    elseif ($false) {' 2 $true
Mut 'P03' $A '"인수 뒤 시작한 파드" 조건을 다시 Ready 로 좁힘(NotReady 드릴 파드가 있어도 또 지운다)' 'text' '$after = @($pd.items | Where-Object { [string]::CompareOrdinal([string]$_.start, $esAt) -gt 0 })' "`$after = @(`$pd.items | Where-Object { [string]::CompareOrdinal([string]`$_.start, `$esAt) -gt 0 -and [string]::Equals(`$_.ready, 'True', [StringComparison]::Ordinal) })" 1 $true
Mut 'P04' $A '인수 뒤 시작한 NotReady 파드 SKIP 분기 제거' 'text' 'elseif ($after.Count -ge 1) {' 'elseif ($false) {' 1 $true
Mut 'P05' $A 'R2 뒤 재인수의 드릴 단어를 drill 로 되돌림(사람 확인이 사라진다)' 'text' "`$w4 = 'first-drill'" "`$w4 = 'drill'" 1 $true
Mut 'P06' $A '기준값을 이어받은 실행·재인수의 드릴 정지점 문면을 평소 문면으로(이미 드릴했는지 묻지 않는다)' 'line' "`$m4 = `"4) ⚠ 이 실행은 `$(if (`$esGone)" '          $m4 = "4) 드릴: $target 하나만 삭제한다" }' 1 $true
Mut 'P07' $A 'SKIP 분기의 커넥터 Ready 경고 제거(한쪽이 NotReady 인데 OK 로 끝난다)' 'text' 'if ($nr.Count -eq 0) { return '''' }' "if (`$nr.Count -ge 0) { return '' }" 1 $true
Mut 'P08' $A '1P) 건너뛰기 제거(PM 유도 기준값을 같은 PM 값과 대조해 "검증했다"고 기록한다)' 'text' 'if ($preFromPm) { Write-Warning ''1P) PM 원본 대조를 건너뛴다' 'if ($false) { Write-Warning ''1P) PM 원본 대조를 건너뛴다'
Mut 'P09' $A 'PM 유도 표시($preFromPm) 자체를 세우지 않는다' 'text' "`$preFromPm = `$true`n        `$pmNote = ' (PM 유도 — 라이브로 검증된 적 없음)'" '        $null = 0'
Mut 'P10' $A '복구 안내의 "기준값이 PM 유도다" 경고 제거(kv 를 낡은 PM 값으로 정정하게 만든다)' 'line' 'if ($preFromPm) {' '      if ($false) {' 3 $true
Mut 'P11' $A '기준값 출력(화면)의 PM 유도 꼬리표 제거(런북에 "검증된 기준값"으로 남는다)' 'line' '"기준값 preHash = $preHash$pmNote"' '    "기준값 preHash = $preHash"' 1
Mut 'P11b' $A '기준값 출력(요약)의 PM 유도 꼬리표 제거 — 같은 결함의 두 번째 갈래' 'line' '"기준값 preHash = $preHash$pmNote"' '      Write-Host "기준값 preHash = $preHash"' 2
Mut 'P12' $A '요약의 drilled: 접두어 제거(다음 실행이 접두어 없이 붙여 넣게 된다)' 'text' 'Write-Host "드릴 후 파드서명 = drilled:$podDrill"' 'Write-Host "드릴 후 파드서명 = $podDrill"' 1 $true
Mut 'P13' $A 'R3 조각에서 히스토리 끄기 제거(개행 섞인 붙여넣기의 나머지가 히스토리로 간다)' 'line' "Write-Host '     set +o history'" '      $null = 0'
Mut 'P14' $A 'R3 조각에서 붙여넣기 형식·길이 검사 제거(빈 값·잘린 값을 그대로 쓴다)' 'line' 'Write-Host ''     case "$T" in' '      $null = 0' 1 $true
Mut 'P15' $A 'R3 조각에서 쓰기 뒤 해시 되읽기 제거(잠긴 상태에서 확인 수단이 없어진다)' 'line' "Write-Host '     sudo k3s kubectl -n cloudflared get secret cloudflared-tunnel -o jsonpath=" '      $null = 0' 1 $true
Mut 'P16' $A 'R3 ② 의 finalizer·webhook 단서 제거(delete 가 멎는 이유를 알 수 없다)' 'line' "Write-Host '   ② 노드 셸(bash)에서 Argo 반영을 확인하고 ES 를 지운다" '      $null = 0'
Mut 'P17' $A '0b 의 전제(클립보드·kubeconfig·권한 하드 검사) 문구 제거' 'line' "Write-Host '    ⚠ 전제: g4-restore 는 해시 대조에 닿기 전에" '      $null = 0'
# ================================================================ 3라운드 검증자 A 의 변이 22개(V**) — 4라운드에 그대로 흡수
# 출처: _verA3/mutants-v.ps1. 그때 CAUGHT 10 · ESCAPED 12 였고, ESCAPED 12 개를 겨냥해 하네스에
# G4-45∼G4-50b · R-16 · R-17 시나리오와 결함 스위치(OciEmpty·BadPodRow·NoPodRows·EmptyType·CanIDeny·AppliedType)를 넣었다.
# V06 만 치환 대상 줄이 4라운드에 바뀌어(noGlass 분기의 조건부 $podDrill) 같은 뜻으로 다시 썼다.
Mut 'V01' $A 'noGlass 를 -and 에서 -or 로(한쪽만 실패해도 삭제 거부 · 단어가 갈리지 않는다)' 'text' '$noGlass = ((-not $sshPre) -and (-not $ociPre))' '$noGlass = ((-not $sshPre) -or (-not $ociPre))'
Mut 'V02' $A 'ssh 만 실패한 실행의 단어를 go 로 되돌림(창 A 미대조를 사람에게 알리지 않는다)' 'text' "elseif (-not `$sshPre) { `$w0 = 'noglass' }" "elseif (`$false) { `$w0 = 'noglass' }" 1 $true
Mut 'V03' $A '창 A 대조의 boot_id 형식 검사 제거(ssh 가 무엇을 돌려주든 대조 상대로 삼는다)' 'text' "`$sshPre = [regex]::IsMatch(`$bootPre, '\A[0-9a-f]{8}\z')" '$sshPre = (-not [string]::IsNullOrWhiteSpace($bootPre))' 1 $true
Mut 'V04' $A 'oci 프로브의 빈 응답 검사 제거(exit 0 + 빈 출력을 2차 break-glass 로 센다)' 'text' '$ociPre = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace((& $txt $oo)))' '$ociPre = ($LASTEXITCODE -eq 0)' 1 $true
Mut 'V05' $A 'ES creationTimestamp 형식 검사 제거(형식이 다르면 시각 비교가 무의미해진다)' 'line' 'ES creationTimestamp 형식이 기대와 다르다' '      $null = 0' 1 $true
Mut 'V06' $A 'noGlass 거부 분기가 드릴 후 서명을 무조건 기록한다(하지도 않은 드릴을 요약이 drilled: 로 인쇄)' 'line' 'if ($preDrilled -or $drilled) { $podDrill = $podPost }' '      $podDrill = $podPost' 1 $true
Mut 'V07' $A '키 목록 조회를 fail-open 으로(조회 실패를 "키가 하나도 없다"로 읽어 매핑 오류로 오진)' 'line' '키 목록' '      $k = @(@(& $kq ''키 목록'' @(''-n'', $NS, ''get'', ''secret'', $SEC, ''-o'', ''go-template={{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}'') @(0, 1)) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })'
Mut 'V08' $A 'SKIP 분기의 Ready 경고를 화면에서 지운다(요약 줄만 남는다)' 'line' 'Write-Warning "⚠ 커넥터 $nm 이 Ready 가 아니다' '      $null = 0'
Mut 'V09' $A 'PM 유도 실행의 1P 기록을 일반 skip-pm 으로(자기 자신 대조였다는 사실이 기록에서 사라진다)' 'text' "`$pmAns = 'pm-derived'" "`$pmAns = 'skip-pm'"
Mut 'V10' $R '(복구) Secret type 빈 응답 검사 제거(빈 type 을 그대로 apply 에 싣는다)' 'line' 'Secret 의 type 을 읽지 못했다' '    $null = 0'
Mut 'V11' $R '(복구) Git 선언 판정에서 requiresPruning=true 예외를 뺀다(정상 순서인데 temporary 로 막는다)' 'text' '$gitLeft = ($argoOk -and $argoEs.Contains("$NS/$ESN=") -and -not $argoEs.Contains("$NS/$ESN=true"))' '$gitLeft = ($argoOk -and $argoEs.Contains("$NS/$ESN="))'
Mut 'V12' $R '(복구) 조회 성공 판정을 "응답이 비어 있지 않다"로(양성 대조 행을 보지 않는다)' 'text' '$argoOk = $argoEs.Contains($CTRL)' '$argoOk = ($argoEs.Length -gt 0)' 1 $true
Mut 'V13' $A '파드 행 형식 검사 제거(jsonpath 형식이 달라지면 오판으로 진행한다)' 'line' '파드 행 형식이 기대와 다르다' '        $null = 0' 1 $true
Mut 'V14' $A '빈 파드 목록 검사 제거(빈 응답을 "파드 없음"으로 읽는다)' 'line' '파드 목록이 비었다' '      $null = 0'
Mut 'V15' $A "0) 권한 확인에서 'delete pods' 를 뺀다(삭제 권한을 미리 확인하지 않는다)" 'text' "foreach (`$v in 'get secrets', 'delete pods') {" "foreach (`$v in 'get secrets') {"
Mut 'V16' $A '남길 파드의 기준 서명을 삭제 대상에서 뽑는다(드릴 대기 판정이 엉뚱한 파드를 본다)' 'text' '$survSig = [string]$sv0.sig' '$survSig = [string]$tg0.sig' 1 $true
Mut 'V17' $A '폴링 진행 줄 제거(프롬프트가 약속한 "진행 줄이 보이면 머지" 신호가 사라진다)' 'line' '초 경과(ES=$nm reason=$reason' '      $null = 0'
Mut 'V18' $R '(복구) 페이로드의 type 을 Opaque 로 하드코딩(실제 type 을 읽고도 쓰지 않는다)' 'text' "kind = 'Secret'; type = `$type" "kind = 'Secret'; type = 'Opaque'"
Mut 'V19' $A '드릴 후 서명 줄을 언제나 인쇄(드릴하지 않은 실행도 drilled: 를 준다)' 'text' 'if (-not [string]::IsNullOrWhiteSpace($podDrill)) {' 'if ($true) {' 1 $true
Mut 'V20' $A '2) 단계 기록을 폴링 전에 남기지 않는다(폴링 중 중단하면 요약이 "미실행"이라고 말한다)' 'line' '$log[''2) 머지 대기''] = "$w2 입력됨' '    $null = 0'
Mut 'V21' $A '"인수 뒤 시작" 필터를 건너뛰고 Ready 파드만 보면 SKIP(드릴이 영영 일어나지 않는다)' 'text' '$already = @($after | Where-Object { [string]::Equals($_.ready, ''True'', [StringComparison]::Ordinal) })' '$already = @($pd.items | Where-Object { [string]::Equals($_.ready, ''True'', [StringComparison]::Ordinal) })'
Mut 'V22' $A '드릴 대상 정렬 제거(목록 순서가 startTime 순서를 대신한다)' 'line' '[Array]::Sort($ord, [StringComparer]::Ordinal)' '        $null = 0' 1 $true
# ================================================================ 4라운드에 새로 생긴 가드의 변이(R4**)
# 가드 ⓓ(data-hash 재인수 탐지 · 1D 정지점) · 요약의 쌍둥이 줄 차단 · 삭제 직전 break-glass 재확인 문면 ·
# UID 안내의 현재 UID · R3 조각(히스토리 확장 · 세 갈래 판정 · 에코 경고 · POD_NAME).
Mut 'R4-01' $A 'R3 조각의 case 패턴을 히스토리 확장에 걸리는 `!!` 로 되돌림(정상 토큰도 늘 BROKEN-PASTE)' 'text' "case `"`$T`" in ''''|*[!''!''-~]*)" "case `"`$T`" in ''''|*[!!-~]*)" 1 $true
Mut 'R4-02' $A 'R3 조각을 "첫 줄부터 실행한다"는 지시 제거(중간부터 재시도 → 히스토리 확장 덫)' 'line' '이 조각은 **첫 줄(set +o history)부터** 실행한다' '      $null = 0' 1 $true
Mut 'R4-03' $A 'R3 의 갈래 판정을 옛 거짓 문면으로 되돌림("해시가 다르면 아무것도 쓰지 않은 것")' 'line' "Write-Host '     판정은 네 갈래다" "      Write-Host '     BROKEN-PASTE·TOO-SHORT 가 찍혔거나 해시가 다르면 **아무것도 쓰지 않은 것**이다 — 다시 붙여 넣는다.'" 1 $true
Mut 'R4-04' $A 'R3 의 화면 에코 경고 제거(스크롤백에 남은 토큰을 알리지 않는다)' 'line' '이 터미널 화면에 이미 에코됐다' '      $null = 0'
Mut 'R4-05' $A 'R3 ④ 의 자리표시자를 붙여 넣으면 bash 문법 오류가 나는 표기로 되돌림' 'text' 'delete pod POD_NAME     # POD_NAME' 'delete pod <이름 하나>     # POD_NAME'
Mut 'R4-06' $A '가드 ⓓ 제거(라벨이 지워진 재인수가 사람 확인 없이 정상 캡처 경로로 들어온다)' 'text' 'if (-not [string]::IsNullOrWhiteSpace($dhPre)) {' 'if ($false) {' 1 $true
Mut 'R4-07' $A '1D) 의 잘못된 답을 first 로 처리(빈 Enter·오타가 드릴을 여는 쪽으로 간다)' 'line' "else { throw '1D) 에서 중단" '        else { $reAdopt = $true } }' 1 $true
Mut 'R4-08' $A '1D) 의 재인수 표시를 4) 단어에 반영하지 않는다(first-drill 로 갈리지 않는다)' 'text' 'if ($resumed -or $reAdopt) {' 'if ($resumed) {' 1 $true
Mut 'R4-09' $A '스냅샷 jsonpath 에서 data-hash 필드 제거(가드 ⓓ 의 근거가 사라진다)' 'text' '{.metadata.annotations.reconcile\.external-secrets\.io/data-hash}|{.data.$KEY}' '{.data.$KEY}' 1 $true
Mut 'R4-10' $A '$already SKIP 분기의 반대쪽 Ready 판정 제거(이중화 미성립이 조용히 넘어간다)' 'line' '$nrNote = & $nrWarn $pd.items' '        $null = 0' 1
Mut 'R4-10b' $A '$after SKIP 분기의 반대쪽 Ready 판정 제거(같은 결함의 두 번째 갈래)' 'line' '$nrNote = & $nrWarn $pd.items' '        $null = 0' 2
Mut 'R4-11' $A '요약의 쌍둥이 줄 차단 제거(접두어 없는 기준값 파드서명을 그대로 다시 인쇄)' 'text' "if ([string]::IsNullOrWhiteSpace(`$podDrill)) { Write-Host `"기준값 파드서명 = `$podPre`" }" "if (`$true) { Write-Host `"기준값 파드서명 = `$podPre`" }" 1 $true
Mut 'R4-12' $A '4) 정지점의 break-glass 재확인 문면 제거(0) 이후 창 A 가 끊겨도 묻지 않는다)' 'line' '$bg4 = ' "        `$bg4 = ''" 1 $true
Mut 'R4-13' $A 'UID 안내에서 현재 UID 줄 제거(새 UID 를 찾을 방법을 주지 않는다)' 'line' 'Write-Host "   지금   UID    : $uidNow' '      $null = 0'
Mut 'R4-14' $A 'UID 안내용 $uidNow 를 3) 판정에서 세우지 않는다' 'line' '$uidNow = $postUid' '      $null = 0'
Mut 'R4-14b' $A 'UID 안내용 $uidNow 를 2) 감시 루프에서 세우지 않는다(같은 결함의 두 번째 갈래)' 'line' '$uidNow = $uNow' '        $null = 0'
Mut 'R4-14c' $A 'UID 안내용 $uidNow 를 삭제 직전 재확인에서 세우지 않는다(세 번째 갈래)' 'line' '$uidNow = $uDel' '          $null = 0'
Mut 'R4-15' $A '라벨 삭제 안내에서 data-hash 경고 제거(지우면 잠금이 모두 풀린다는 사실을 숨긴다)' 'line' '**data-hash 어노테이션은 어떤 경우에도 지우지 않는다.**' '      $null = 0' 1 $true
# ================================================================ 5라운드에 새로 생긴 가드·문면의 변이(R5**)
# B4-01(드릴 단어 게이트를 구조적 사실로) · B4-03(요약의 쌍둥이 **값** 제거) · A4-1(R3 의 apply 실패 갈래) ·
# A4-2(R3 조각의 unset B/unset T) · A4-3($nrWarn 호출 6곳) · A4-4(운영자에게 어느 줄을 넣으라고 말해 주는 문면) · A4-5(Ordinal 비교).
Mut 'R5-01' $A '드릴 단어 게이트를 4R 의 일시적 사실($esGone)로 되돌림(먼저 머지한 재인수에서 게이트가 사라진다 · B4-01)' 'text' 'if ($resumed -or $reAdopt) {' 'if ($esGone -or $reAdopt) {' 1 $true
Mut 'R5-02' $A '드릴 단어 게이트에서 resume 을 통째로 뺀다(1R 로 이어 온 실행이 drill 하나로 지운다 · B4-01)' 'text' 'if ($resumed -or $reAdopt) {' 'if ($reAdopt) {' 1 $true
Mut 'R5-03' $A '요약의 쌍둥이 **값** 억제 분기 제거(접두어 없는 같은 값이 파드서명 줄로 다시 나간다 · B4-03)' 'text' 'elseif ([string]::Equals($podDrill, $podPre, [StringComparison]::Ordinal)) {' 'elseif ($false) {' 1 $true
Mut 'R5-04' $A 'R3 의 (0) apply 실패 갈래 제거(쓰기 0건인 실패를 "이미 썼을 수 있다"로 읽게 된다 · A4-1)' 'line' '(0) **apply 줄에 kubectl 오류가 찍혔다' '      $null = 0' 1 $true
Mut 'R5-05' $A 'R3 의 (0) 에서 라이브 type 읽기 명령 제거(잠긴 운영자가 원인을 고칠 수단을 잃는다 · A4-1)' 'line' '{.type}' '      $null = 0' 1 $true
Mut 'R5-06' $A 'R3 의 (3) 에서 "apply 줄의 오류는 (0) 이다" 구분 제거(두 갈래가 다시 섞인다 · A4-1)' 'line' '※ apply 줄의 오류는 (3) 이 아니라 (0) 이다.' "      Write-Host '           (파이프라인 종료 코드는 0 이라 조용히 지나간다). 값은 옳게 복구됐을 수도 있다.'" 1 $true
Mut 'R5-07' $A 'R3 조각에서 case 앞의 unset B 제거(앞선 시도의 B 가 남아 BROKEN-PASTE 인데도 틀린 값을 쓴다 · A4-2)' 'line' "Write-Host '     unset B'" '      $null = 0' 1 $true
Mut 'R5-07b' $A 'R3 조각에서 apply 뒤의 unset B 제거(같은 줄의 두 번째 갈래 · A4-2)' 'line' "Write-Host '     unset B'" '      $null = 0' 2 $true
Mut 'R5-08' $A 'R3 조각에서 unset T 제거(평문 토큰이 노드 셸 변수에 남는다 · A4-2)' 'line' "Write-Host '     unset T'" '      $null = 0' 1 $true
Mut 'R5-09' $A 'noGlass 거부 분기의 반대쪽 Ready 판정 제거(확인된 복구 경로 0 인 실행이 "OK"로 끝난다 · A4-3)' 'line' '$nrNote = & $nrWarn $pq.items' '      $null = 0' 1 $true
Mut 'R5-09b' $A 'drilled: SKIP 분기의 반대쪽 Ready 판정 제거(A4-3)' 'line' '$nrNote = & $nrWarn $pq.items' '      $null = 0' 2
Mut 'R5-09c' $A '이전 드릴 SKIP 분기의 반대쪽 Ready 판정 제거(A4-3)' 'line' '$nrNote = & $nrWarn $pq.items' '      $null = 0' 3
Mut 'R5-09d' $A 'nopods SKIP 분기의 반대쪽 Ready 판정 제거(A4-3)' 'line' '$nrNote = & $nrWarn $pq.items' '      $null = 0' 4 $true
Mut 'R5-10' $A '요약의 기준값 파드서명 줄에서 "어느 줄을 넣어라" 단서만 뗀다(이름은 그대로 · A4-4)' 'text' '기준값 파드서명(이 실행의 입력 · 다음 실행에는 이 줄이 아니라 아래 drilled: 줄을 넣는다) = $podPre' '기준값 파드서명(이 실행의 입력) = $podPre'
Mut 'R5-11' $A '요약의 기준값 파드서명 줄을 통째로 제거(운영자가 이 실행의 입력을 되짚을 수 없다 · A4-4)' 'text' 'if (-not [string]::IsNullOrWhiteSpace($podPre)) {' 'if ($false) {'
Mut 'R5-11b' $A '요약의 접두어 없는 기준값 파드서명 줄만 제거(같은 결함의 두 번째 갈래 · A4-4)' 'text' "if ([string]::IsNullOrWhiteSpace(`$podDrill)) { Write-Host `"기준값 파드서명 = `$podPre`" }" 'if ($false) { $null = 0 }'
Mut 'R5-12' $A '화면의 "이미 드릴했다고 선언됐다" 단서 제거(그 실행이 삭제 0 이라는 사실이 화면에서 사라진다 · A4-4)' 'text' "' (이미 드릴했다고 선언됐다 — 이 실행은 파드를 삭제하지 않는다)'" "''"
Mut 'R5-13' $A '1D) 오답 안내에서 "모르겠으면 drilled" 제거(안전한 쪽을 알려 주지 않는다 · A4-4)' 'text' '(모르겠으면 drilled 를 넣는다: 삭제 0 이 안전한 쪽이다)' ''
Mut 'R5-14' $A 'R3 의 case 줄 따옴표 근거 주석 제거(다음 편집자가 B3-01 을 되돌린다 · A4-4)' 'line' 'case 줄의' "      Write-Host '       재시도할 때도 반드시 첫 줄부터다.'" 1 $true
Mut 'R5-15' $A 'B4-02 로 바로잡은 히스토리 확장 기전 설명 제거(다음 편집자가 "[ 뒤면 안전하다"를 믿는다)' 'line' '보호하는 것은 여는 대괄호가 아니라' '      $null = 0'
Mut 'R5-16' $A '1D) 의 단어 비교를 Ordinal → -eq(컬처 민감 · 안전 규칙 8)' 'text' "[string]::Equals(`$rd, 'drilled', [StringComparison]::Ordinal)" "`$rd -eq 'drilled'"
Mut 'R5-17' $A '$nrWarn 의 Ready 비교를 Ordinal → -ne(컬처 민감 · 안전 규칙 8)' 'text' "-not [string]::Equals([string]`$_.ready, 'True', [StringComparison]::Ordinal) })" "([string]`$_.ready -ne 'True') })" 1 $true
# ---------------------------------------------------------------- 사본 생성
$sel = @($M | Where-Object { [string]::IsNullOrWhiteSpace($Only) -or [string]::Equals($_.id, $Only, [StringComparison]::Ordinal) })
$jobs = [System.Collections.ArrayList]::new()
$rows = [System.Collections.ArrayList]::new()
foreach ($m in $sel) {
  $d = Join-Path $root $m.id
  $null = New-Item -ItemType Directory -Path $d -Force
  Copy-Item (Join-Path $here $A) (Join-Path $d $A)
  Copy-Item (Join-Path $here $R) (Join-Path $d $R)
  $p = Join-Path $d $m.file
  $applied = $true
  $why = ''
  if ([string]::Equals($m.mode, 'line', [StringComparison]::Ordinal)) {
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($l in [IO.File]::ReadAllLines($p)) { $lines.Add($l) }
    $hit = @(0..($lines.Count - 1) | Where-Object { $lines[$_].Contains($m.from) })
    if ($hit.Count -lt $m.occ) { $applied = $false; $why = "앵커 미발견(줄 $($hit.Count) 개)" }
    else { $lines[$hit[$m.occ - 1]] = [string]$m.to }
    if ($applied) { [IO.File]::WriteAllText($p, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false)) } }
  else {
    $t = [IO.File]::ReadAllText($p)
    $c = 0; $i = 0
    while (($i = $t.IndexOf([string]$m.from, $i)) -ge 0) { $c++; $i++ }
    if ($c -ne 1) { $applied = $false; $why = "앵커가 $c 회(1 이어야 한다)" }
    else { [IO.File]::WriteAllText($p, $t.Replace([string]$m.from, [string]$m.to), (New-Object Text.UTF8Encoding $false)) } }
  if (-not $applied) {
    [void]$rows.Add([pscustomobject]@{ id = $m.id; file = $m.file; lock = $m.lock; caught = 'ANCHOR-ERR'; by = $why; desc = $m.desc })
    continue }
  # 치환이 실제로 파일을 바꿨는지 확인한다(3라운드 검증자 A 가 넣은 검사를 흡수했다) —
  # 같은 문자열로 바꾸면 "변이 없음"인데 CAUGHT/ESCAPED 로 읽혀 수치가 거짓이 된다.
  if ([string]::Equals([IO.File]::ReadAllText($p), [IO.File]::ReadAllText((Join-Path $here $m.file)), [StringComparison]::Ordinal)) {
    [void]$rows.Add([pscustomobject]@{ id = $m.id; file = $m.file; lock = $m.lock; caught = 'NO-OP'; by = '치환 뒤 파일이 원본과 같다'; desc = $m.desc })
    continue }
  [void]$jobs.Add([pscustomobject]@{ m = $m; dir = $d }) }
# ---------------------------------------------------------------- 실행(병렬)
$harness = Join-Path $here 'harness-g4.ps1'
$res = $jobs | ForEach-Object -ThrottleLimit $Throttle -Parallel {
  $j = $_
  $o = & pwsh -NoProfile -File $using:harness -BlockDir $j.dir 2>&1
  $rc = $LASTEXITCODE
  $txt = ($o | ForEach-Object { [string]$_ }) -join "`n"
  [IO.File]::WriteAllText((Join-Path $j.dir 'harness.out.txt'), $txt, (New-Object Text.UTF8Encoding $false))
  $lintHits = @([regex]::Matches($txt, 'LINT-FAIL: ([^\r\n]*)') | ForEach-Object { $_.Groups[1].Value })
  $caseHits = @([regex]::Matches($txt, '(?m)^(G4-\S+|R-\S+)\s+FAIL') | ForEach-Object { $_.Groups[1].Value })
  $by = @()
  if ($lintHits.Count) { $by += 'lint: ' + (($lintHits -join ' ; ').Substring(0, [Math]::Min(110, ($lintHits -join ' ; ').Length))) }
  if ($caseHits.Count) { $by += '시나리오: ' + (($caseHits | Select-Object -First 6) -join ',') + $(if ($caseHits.Count -gt 6) { " 외 $($caseHits.Count - 6)" } else { '' }) }
  if (-not $by.Count -and $rc -ne 0) { $by += "exit=$rc" }
  [pscustomobject]@{ id = $j.m.id; file = $j.m.file; lock = $j.m.lock; caught = $(if ($rc -ne 0) { 'CAUGHT' } else { 'ESCAPED' }); by = ($by -join ' | '); desc = $j.m.desc } }
foreach ($r in $res) { [void]$rows.Add($r) }
$sorted = @($rows | Sort-Object id)
$sorted | Format-Table -AutoSize -Wrap -Property id, file, lock, caught, desc, by | Out-String -Width 300 | Write-Host
$caught = @($sorted | Where-Object { [string]::Equals($_.caught, 'CAUGHT', [StringComparison]::Ordinal) }).Count
$esc = @($sorted | Where-Object { [string]::Equals($_.caught, 'ESCAPED', [StringComparison]::Ordinal) })
$anch = @($sorted | Where-Object { [string]::Equals($_.caught, 'ANCHOR-ERR', [StringComparison]::Ordinal) -or [string]::Equals($_.caught, 'NO-OP', [StringComparison]::Ordinal) })
Write-Host ("변이 {0} 개 중 하네스가 잡은 것 {1} 개 · 빠져나간 것 {2} 개 · 앵커/무효 {3} 개" -f $sorted.Count, $caught, $esc.Count, $anch.Count)
Write-Host ('ESCAPED: ' + (($esc | ForEach-Object { $_.id + $(if ($_.lock) { '(잠금)' } else { '' }) }) -join ' '))
Write-Host ('ANCHOR-ERR/NO-OP: ' + (($anch | ForEach-Object { $_.id }) -join ' '))
Write-Host ("잠금으로 이어지는 변이 {0} 개 중 CAUGHT {1} 개" -f @($sorted | Where-Object { $_.lock }).Count,
  @($sorted | Where-Object { $_.lock -and [string]::Equals($_.caught, 'CAUGHT', [StringComparison]::Ordinal) }).Count)
if (-not $KeepDirs) { Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue }
else { Write-Host "사본 위치: $root" }
if ($caught -ne $sorted.Count) { exit 1 }
