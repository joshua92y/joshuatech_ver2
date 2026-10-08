param([string]$Only = '', [int]$Throttle = 6, [switch]$KeepDirs)
# ===== T045 G4 변이 시험 — "하네스가 정말로 결함을 잡는가" =====
# 블록 사본에 결함을 하나씩 심고 harness-g4.ps1 을 그 사본에 대해 돌린다. 모든 변이는 FAIL(exit 1)로 잡혀야 한다.
# 실행: pwsh -NoProfile -File mutants-g4.ps1   ·   하나만: -Only M07   ·   직렬: -Throttle 1
# 2라운드: 적대적 검증자 A 의 변이 39개(A**·B**)를 흡수했다. A 는 줄 번호로 앵커를 잡았지만 여기서는 전부
#   내용 앵커('text' = 파일 안에 정확히 1회 · 'line' = 그 문자열을 포함하는 occ 번째 줄)로 바꿨다 — 줄이 밀려도 살아남는다.
$ErrorActionPreference = 'Stop'
function Get-MutantClassification {
  param([int]$ExitCode, [string]$OutputText)
  $lintHits = @([regex]::Matches($OutputText, '(?m)^\s*g4-(?:adopt|drill|restore)\.ps1\s+LINT-FAIL: ([^\r\n]*)') | ForEach-Object { $_.Groups[1].Value })
  $caseHits = @([regex]::Matches($OutputText, '(?m)^(G4-\S+|R-\S+|D-\S+|R3-BASH(?:-\S+)?)\s+FAIL\b') | ForEach-Object { $_.Groups[1].Value })
  $by = @()
  if ($lintHits.Count) { $by += 'lint: ' + (($lintHits -join ' ; ').Substring(0, [Math]::Min(110, ($lintHits -join ' ; ').Length))) }
  if ($caseHits.Count) { $by += '시나리오: ' + (($caseHits | Select-Object -First 6) -join ',') + $(if ($caseHits.Count -gt 6) { " 외 $($caseHits.Count - 6)" } else { '' }) }
  $caught = if ($ExitCode -eq 0) { 'ESCAPED' }
    elseif ($ExitCode -eq 1 -and ($lintHits.Count -gt 0 -or $caseHits.Count -gt 0)) { 'CAUGHT' }
    else { 'RUNNER-ERROR' }
  if ([string]::Equals($caught, 'RUNNER-ERROR', [StringComparison]::Ordinal)) { $by += "exit=$ExitCode; 기대 exit 1 및 실제 lint/시나리오 실패 근거 필요" }
  [pscustomobject]@{ caught = $caught; by = ($by -join ' | '); exitCode = $ExitCode }
}
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Join-Path ([IO.Path]::GetTempPath()) ('t045-g4-mut-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = New-Item -ItemType Directory -Path $root -Force
$M = [System.Collections.ArrayList]::new()
function Mut { param($id, $file, $desc, $mode, $from, $to, $occ = 1, [bool]$lock = $false)
  [void]$script:M.Add([pscustomobject]@{ id = $id; file = $file; desc = $desc; mode = $mode; from = $from; to = $to; occ = $occ; lock = $lock }) }
$A = 'g4-adopt.ps1'
$R = 'g4-restore.ps1'
$DrillFile = 'g4-drill.ps1'
# 기존 ID는 전부 보존. 사슬 삭제 변이는 경로와 동사를 나눈 adopt 쓰기 금지 결함(보고서 ID 표 참조).
Mut 'M01' 'g4-adopt.ps1' '인수 후 값 해시 판정 제거' 'text' 'if (-not [string]::Equals($postHash, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M02' 'g4-adopt.ps1' '인수 후 UID 판정 제거' 'text' 'if (-not [string]::Equals($postUid, $preUid, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M03' 'g4-adopt.ps1' 'ownerReferences 판정 제거' 'text' 'if (-not [string]::IsNullOrWhiteSpace($own)) {' 'if ($false) {' 1 $false
Mut 'M04' 'g4-adopt.ps1' 'managed 라벨(양성 증거) 판정 제거' 'text' 'if (-not [string]::Equals($mg1, ''true'', [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $false
Mut 'M05' 'g4-adopt.ps1' 'data-hash 하드 판정 제거(ESO 쓰기 증거 없이 통과)' 'text' 'if ([string]::IsNullOrWhiteSpace($dh)) {' 'if ($false) {' 1 $false
Mut 'M06' 'g4-adopt.ps1' 'Secret 의 Argo tracking 복사 판정 제거' 'text' 'if (-not [string]::IsNullOrWhiteSpace($trkS)) {' 'if ($false) {' 1 $false
Mut 'M07' 'g4-adopt.ps1' 'ES tracking-id 소유 Application 판정 제거' 'text' 'if (-not [string]::Equals(([string]$trkE -split '':'')[0], $OWNER, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $false
Mut 'M08' 'g4-adopt.ps1' 'platform-cloudflared 의 external-secrets.io 소유 판정 제거' 'text' 'if ($res.Contains(''external-secrets.io/'')) {' 'if ($false) {' 1 $false
Mut 'M09' 'g4-adopt.ps1' '파드 불변 판정 제거' 'text' 'elseif (-not [string]::Equals($podPost, $podPre, [StringComparison]::Ordinal)) {' 'elseif ($false) {' 1 $true
Mut 'M10' 'g4-adopt.ps1' '키 집합(TUNNEL_TOKEN 하나) 검사 제거' 'text' 'if (-not [string]::Equals($keys0, $KEY, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M11' 'g4-adopt.ps1' 'SecretSyncedError 고착 판정 제거' 'text' 'if ($errN -ge 3) {' 'if ($false) {' 1 $false
Mut 'M12' 'g4-drill.ps1' '새 파드 Ready 타임아웃 단언 제거' 'text' 'if ([string]::IsNullOrWhiteSpace($newName)) {' 'if ($false) {' 1 $true
Mut 'M13' 'g4-drill.ps1' '삭제 전 양쪽 Ready 통합 게이트 제거(옛 남길 파드 게이트 이동)' 'text' 'if (-not [string]::Equals($p.ready, ''True'', [StringComparison]::Ordinal))' 'if ($false)' 1 $true
Mut 'M14' 'g4-drill.ps1' '삭제 직전 값 해시 재확인 제거(정지점 사이 변경을 놓친다)' 'text' 'if (-not [string]::Equals($hDel, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M15' 'g4-drill.ps1' '삭제 직전 UID 재확인 제거' 'text' 'if (-not [string]::Equals($uDel, $preUid, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M16' 'g4-drill.ps1' '삭제 직전 양쪽 서명·Ready 통합 재확인 제거' 'text' 'if (-not [string]::Equals($pd2.sig, $pd.sig, [StringComparison]::Ordinal) -or @($pd2.items | Where-Object { -not [string]::Equals($_.ready, ''True'', [StringComparison]::Ordinal) }).Count -gt 0)' 'if ($false)' 1 $true
Mut 'M17' 'g4-drill.ps1' '드릴 대기 중 남은 파드 서명 불변 검사 제거' 'text' 'if (-not [string]::Equals([string]$sv[0].sig, $survSig, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M18' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: nopods 실행에서도 파드를 삭제하도록(재실행 누적 삭제)' 'text' '    $resumed = $false' '    $resumed = $false
    & kubectl ''-n'' $NS ''delete'' ''pod'' ''cloudflared-6d4f7c9b8-bb22b'' | Out-Null' 1 $true
Mut 'M19' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 인수 뒤 시작한 Ready 파드가 있어도 또 드릴(두 번째 삭제)' 'text' '      $resumed = $true' '      $resumed = $true
    & kubectl ''-n'' $NS ''delete'' ''pod'' ''cloudflared-6d4f7c9b8-bb22b'' | Out-Null' 1 $true
Mut 'M20' 'g4-drill.ps1' '삭제 대상을 2개로(남은 커넥터까지 교체)' 'line' '& $kdel $target | Out-Null' '        & $kdel $target | Out-Null
        & $kdel $survivor | Out-Null' 1 $true
Mut 'M21' 'g4-drill.ps1' 'rollout restart 삽입(전면 재시작)' 'line' '& $kdel $target | Out-Null' '        & kubectl ''-n'' $NS ''rollout'' ''restart'' ''deploy/cloudflared'' | Out-Null' 1 $true
Mut 'M22' 'g4-drill.ps1' '조회 헬퍼로 삭제 우회($kq 에 delete 동사)' 'line' '& $kdel $target | Out-Null' '        & $kq ''드릴 삭제'' @(''-n'', $NS, ''delete'', ''pod'', $target) | Out-Null' 1 $true
Mut 'M23' 'g4-drill.ps1' '드릴 대상 선정을 이름 순으로 되돌림(옛 커넥터를 지울 수 있다)' 'text' '$ord = @($pd.items | ForEach-Object { "$($_.start)|$($_.name)" })' '$ord = @($pd.items | ForEach-Object { "$($_.name)|$($_.name)" })' 1 $true
Mut 'M24' 'g4-drill.ps1' '대상·생존 뒤바꿈(가장 이른 파드를 지운다)' 'text' '$survivor = [string](($ord[0] -split ''\|'')[1])' '$survivor = [string](($ord[1] -split ''\|'')[1])' 1 $true
Mut 'M25' 'g4-drill.ps1' '드릴 정지점 제거(사람 승인 없이 삭제)' 'line' '& $stop $m4 $w4' '        $null = 0' 1 $true
Mut 'M26' 'g4-adopt.ps1' '0) break-glass 정지점 제거' 'line' '& $stop $m0 $w0' '    $null = 0' 1 $true
Mut 'M27' 'g4-adopt.ps1' '정지점 단어 비교를 Ordinal → -eq(대소문자 무시)' 'text' 'if (-not [string]::Equals([string]$a, $word, [StringComparison]::Ordinal)) { throw "정지점에서 중단: $msg" } }' 'if (-not ([string]$a -eq $word)) { throw "정지점에서 중단: $msg" } }' 1 $false
Mut 'M28' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: resume 파드 서명의 빈 입력 거부 제거(빈 Enter 로 게이트 포기)' 'text' '    $judged = $true' '    $judged = $true
    & kubectl ''-n'' $NS ''delete'' ''pod'' ''cloudflared-6d4f7c9b8-bb22b'' | Out-Null' 1 $false
Mut 'M29' 'g4-adopt.ps1' '창 A boot_id 대조 제거(열린 세션을 확인하지 않는다)' 'text' 'if (-not [string]::Equals($typed, $bootPre, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M30' 'g4-adopt.ps1' '1P) PM 토큰 해시 검사 제거' 'text' 'if (-not [string]::Equals($pmHash, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $false
Mut 'M31' 'g4-adopt.ps1' '인수 전 값을 화면에 출력' 'line' '$preHash = & $sha ([string]$snap[3])' '      "인수 전 값: $([string]$snap[3])"
      $preHash = & $sha ([string]$snap[3])' 1 $false
Mut 'M32' 'g4-adopt.ps1' '해시 대신 평문을 기준값으로 보관(해시 비교 제거)' 'text' '$preHash = & $sha ([string]$snap[3])' '$preHash = [string]$snap[3]' 1 $false
Mut 'M33' 'g4-adopt.ps1' '1P) 토큰을 -AsSecureString 없이 평문으로 읽는다' 'text' '$ss = Read-Host $prompt -AsSecureString' '$ss = Read-Host $prompt' 1 $false
Mut 'M34' 'g4-restore.ps1' '복구 토큰을 -AsSecureString 없이 평문으로 읽는다' 'text' '$ss = Read-Host $prompt -AsSecureString' '$ss = Read-Host $prompt' 1 $false
Mut 'M35' 'g4-adopt.ps1' 'finally 의 정리(Remove-Variable) 제거' 'line' 'Remove-Variable snap, b64, hNow' '    $null = 0' 1 $false
Mut 'M36' 'g4-adopt.ps1' '조회 3회 실패를 빈 값으로 통과시킨다(실패를 없음으로 읽는다)' 'line' 'throw "kubectl 조회 실패(exit=$rc · 3회 시도): $desc' '          return '''' }' 1 $true
Mut 'M37' 'g4-adopt.ps1' '단일 GET 스냅샷의 managed 라벨 가드 제거(가짜 기준값)' 'text' 'if (-not [string]::IsNullOrWhiteSpace([string]$snap[1])) {' 'if ($false) {' 1 $true
Mut 'M38' 'g4-adopt.ps1' 'auth can-i 의 허용 종료 코드 제거(no 를 조회 실패로 읽는다)' 'text' '(@(''auth'', ''can-i'') + @($v -split '' '') + @(''-n'', $NS)) @(0, 1))).Trim()' '(@(''auth'', ''can-i'') + @($v -split '' '') + @(''-n'', $NS)))).Trim()' 1 $false
Mut 'M39' 'g4-drill.ps1' '드릴 대기 조회 실패를 즉시 throw(검증만 잃고 재실행을 부른다)' 'line' 'try { $pn = & $pods ''드릴 대기'' } catch' '          $pn = & $pods ''드릴 대기''' 1 $false
Mut 'M40' 'g4-adopt.ps1' '라벨 셀렉터 제거(무관한 파드를 커넥터로 센다)' 'text' '''get'', ''pods'', ''-l'', ''app=cloudflared'', ''-o''' '''get'', ''pods'', ''-o''' 1 $false
Mut 'M41' 'g4-adopt.ps1' 'oci 읽기 전용 프로파일 검사 제거' 'text' 'if ([string]::Equals($ociProf, ''svc-verify'', [StringComparison]::Ordinal) -or [string]::Equals([string]$env:OCI_CLI_AUTH, ''security_token'', [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $false
Mut 'M42' 'g4-drill.ps1' '변경 로그를 삭제 요청 뒤로(중단 시 "변경 0건" 거짓말)' 'line' '[void]$changes.Add("kubectl -n $NS delete pod' '      $null = 0' 1 $false
Mut 'M43' 'g4-drill.ps1' '삭제를 블로킹 대기로 되돌림(--wait=false 제거)' 'text' '''--wait=false'' ''--request-timeout=30s''' '''--timeout=90s''' 1 $false
Mut 'M44' 'g4-adopt.ps1' '조회 실패 문면을 "파드는 건드리지 않았다"로 고정(거짓 문장)' 'text' '$did = ''이 실행은 아직 아무것도 바꾸지 않았다''' '$did = ''파드는 건드리지 않았다''' 1 $false
Mut 'M45' 'g4-adopt.ps1' '판정하지 않은 항목도 합격 문면에 넣는다(resume·nopods 인데 "파드 불변")' 'text' '$podNote = ''파드 불변은 판정하지 않았다(resume · 현재 상태만 조회)''' '$podNote = ''파드 불변''' 1 $false
Mut 'M45b' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 판정하지 않은 항목도 합격 문면에(이전 드릴 결과인데 "파드 불변")' 'text' '      $preUid = [string]$snap[0]' '      $preUid = [string]$snap[0]
    & kubectl ''-n'' $NS ''delete'' ''pod'' ''cloudflared-6d4f7c9b8-bb22b'' | Out-Null' 1 $false
Mut 'M46' 'g4-adopt.ps1' '머지 입력 뒤 미판정 중단 경고 제거' 'line' 'if ($mergeAsked -and -not $judged' '    if ($false) {' 1 $false
Mut 'M47' 'g4-restore.ps1' 'PM 토큰 해시 게이트 제거(틀린 값을 자기 손으로 쓴다)' 'text' 'if (-not [string]::Equals((& $sha $b64), $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'M48' 'g4-restore.ps1' '토큰 형식(ASCII 인쇄 문자) 검사 제거' 'text' 'if (-not [regex]::IsMatch($tok, ''\A[\x21-\x7E]+\z'')) {' 'if ($false) {' 1 $false
Mut 'M49' 'g4-restore.ps1' '클립보드 기록 검사 제거' 'line' 'if ($ch -ne 0) { throw ''클립보드 기록이 켜져 있음' '    $null = $ch' 1 $false
Mut 'M50' 'g4-restore.ps1' 'apply 회계를 호출 뒤로(쓰기 시도를 숨긴다)' 'line' '[void]$changes.Add("kubectl apply --server-side secret/' '      $null = 0' 1 $false
Mut 'M51' 'g4-restore.ps1' 'Git 선언(selfHeal) 검사 제거 — ES 부재를 "개입 멈춤"으로 읽는다' 'text' '$gitLeft = ($argoOk -and $argoEs.Contains("$NS/$ESN=") -and -not $argoEs.Contains("$NS/$ESN=true"))' '$gitLeft = $false' 1 $true
Mut 'M52' 'g4-restore.ps1' '모호한 apply 실패를 "아무것도 쓰지 않았다"로 단정' 'text' 'elseif ($attempted -or $changes.Count -gt 0) {' 'elseif ($false) {' 1 $false
Mut 'M53' 'g4-restore.ps1' '토큰 검사를 -cnotmatch 로 되돌림($Matches 에 평문 잔류)' 'text' 'if (-not [regex]::IsMatch($tok, ''\A[\x21-\x7E]+\z'')) {' 'if ($tok -cnotmatch ''\A[\x21-\x7E]+\z'') {' 1 $false
Mut 'A01' 'g4-adopt.ps1' '3) 인수 판정의 값 변경 감지를 경고로 강등(덮인 채 드릴까지 진행)' 'line' 'throw ''⚠ 인수 뒤 터널 값이 바뀌었다' '      Write-Warning ''값이 바뀌었다(변이: 경고로 강등)'' }' 1 $true
Mut 'A02' 'g4-drill.ps1' '삭제 직전 값 재확인 실패를 경고로 강등(값이 덮인 채 파드 삭제)' 'line' 'throw ''⚠ 정지점에서 기다리는 사이에 터널 값이 바뀌었다' '          Write-Warning ''정지점 사이 값 변경(변이: 경고로 강등)'' }' 1 $true
Mut 'A03' 'g4-adopt.ps1' '2) 감시 루프의 값 해시 검사 제거(대기 중 감시 없음)' 'text' 'if (-not [string]::Equals($hNow, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'A04' 'g4-adopt.ps1' '2) 감시 루프의 UID 검사 제거' 'text' 'if (-not [string]::Equals($uNow, $preUid, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'A05' 'g4-adopt.ps1' '폴링 타임아웃을 PASS 로 처리' 'text' 'if (-not $synced) {' 'if ($false) {' 1 $true
Mut 'A06' 'g4-adopt.ps1' 'SecretSynced 비교를 StartsWith 로 느슨하게(SecretSyncedError 도 통과)' 'text' 'if ([string]::Equals($reason, ''SecretSynced'', [StringComparison]::Ordinal)) { $synced = $true; break }' 'if ($reason.StartsWith(''SecretSynced'')) { $synced = $true; break }' 1 $true
Mut 'A07' 'g4-adopt.ps1' 'ES SecretSyncedError 고착을 경고로 강등' 'line' 'throw ''ES 가 SecretSyncedError 로 굳었다' '            Write-Warning ''ES SecretSyncedError(변이: 경고로 강등)'' } }' 1 $true
Mut 'A08' 'g4-drill.ps1' '양쪽 Ready 통합 게이트가 삭제 대상만 본다' 'text' 'if (-not [string]::Equals($p.ready, ''True'', [StringComparison]::Ordinal))' 'if (-not [string]::Equals($pd.items[1].ready, ''True'', [StringComparison]::Ordinal))' 1 $true
Mut 'A09' 'g4-drill.ps1' '새 파드 Ready 조건 제거(대상 부재·2개 조건은 유지)' 'text' 'if (@($pn.items).Count -eq 2 -and @($pn.items | Where-Object { [string]::Equals($_.name, $target, [StringComparison]::Ordinal) }).Count -eq 0 -and $nw.Count -eq 1 -and [string]::Equals([string]$nw[0].ready, ''True'', [StringComparison]::Ordinal)) {' 'if (@($pn.items).Count -eq 2 -and @($pn.items | Where-Object { [string]::Equals($_.name, $target, [StringComparison]::Ordinal) }).Count -eq 0 -and $nw.Count -eq 1 ) {' 1 $true
Mut 'A10a' 'g4-drill.ps1' '삭제 셀렉터를 --all 로 넓힘(이름 없음)' 'text' '& kubectl ''-n'' $NS ''delete'' ''pod'' $pod ''--wait=false''' '& kubectl ''-n'' $NS ''delete'' ''pod'' ''--all'' ''--wait=false''' 1 $true
Mut 'A10b' 'g4-drill.ps1' '삭제 셀렉터를 -l app=cloudflared 로 넓힘' 'text' '& kubectl ''-n'' $NS ''delete'' ''pod'' $pod ''--wait=false''' '& kubectl ''-n'' $NS ''delete'' ''pod'' ''-l'' ''app=cloudflared'' ''--wait=false''' 1 $true
Mut 'A11' 'g4-drill.ps1' '삭제 인자에 이름 2개(대상 + 남길 파드)' 'text' '& kubectl ''-n'' $NS ''delete'' ''pod'' $pod ''--wait=false''' '& kubectl ''-n'' $NS ''delete'' ''pod'' $pod $survivor ''--wait=false''' 1 $true
Mut 'A12' 'g4-drill.ps1' '로그 헬퍼($klog) 안에 scale --replicas=0 삽입(헬퍼 안 kubectl 이라 lint 통과?)' 'line' '& kubectl ''-n'' $NS ''logs'' $pod' '      $null = & kubectl ''-n'' $NS ''scale'' ''deploy/cloudflared'' ''--replicas=0'' ''--request-timeout=15s''; $out = & kubectl ''-n'' $NS ''logs'' $pod ''--tail=120'' ''--request-timeout=15s''' 1 $true
Mut 'A13' 'g4-drill.ps1' 'ssh 원격 명령으로 전면 재시작(kubectl 밖 변경 경로)' 'text' '''ssh-a'' ''hostname''' '''ssh-a'' ''sudo k3s kubectl -n cloudflared rollout restart deploy/cloudflared; hostname''' 1 $true
Mut 'A13b' 'g4-adopt.ps1' 'oci 를 읽기 조회가 아닌 NSG 변경 호출로 바꾼다(kubectl 밖 변경 경로)' 'text' '& oci ''iam'' ''region'' ''list'' ''--query'' ''length(data)''' '& oci ''network'' ''nsg'' ''rules'' ''add'' ''--nsg-id'' ''ocid1.nsg.oc1..x''' 1 $true
Mut 'A14' 'g4-adopt.ps1' '파드 서명에서 restartCount 제외(in-place 재시작을 못 본다)' 'text' 'sig = "$([string]$p[0])|$([string]$p[1])|$([string]$p[2])"' 'sig = "$([string]$p[0])|0|$([string]$p[2])"' 1 $true
Mut 'A15' 'g4-adopt.ps1' 'resume: 운영자 입력 preHash 를 라이브 값 해시로 덮어씀(가짜 PASS)' 'text' 'if (-not [regex]::IsMatch($preHash, ''\A[0-9A-F]{64}\z'')) { throw ''preHash 형식이 아니다(64자리 대문자 16진수) — 중단'' }' 'if (-not [regex]::IsMatch($preHash, ''\A[0-9A-F]{64}\z'')) { throw ''preHash 형식이 아니다(64자리 대문자 16진수) — 중단'' }; $preHash = & $sha (& $txt (& $kq ''변이: 라이브 값으로 기준값 대체'' @(''-n'', $NS, ''get'', ''secret'', $SEC, ''-o'', "jsonpath={.data.$KEY}"))).Trim()' 1 $true
Mut 'A20' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 4) nopods 분기를 항상 타게 만든다(드릴 불가 · M18 의 반대 방향으로 같은 줄을 고정)' 'text' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''
    & kubectl ''-n'' $NS ''delete'' ''pod'' ''cloudflared-6d4f7c9b8-bb22b'' | Out-Null' 1 $true
Mut 'A22' 'g4-adopt.ps1' '파드 불변 실패를 경고로 강등' 'line' 'throw "파드가 바뀌었다(전= $podPre' '        Write-Warning ''파드가 바뀌었다(변이: 경고로 강등)'' } }' 1 $true
Mut 'A30' 'g4-drill.ps1' '5) 노드 Ready 2 실패를 경고로 강등' 'line' 'if ($ready2 -ne 2) {' '    if ($ready2 -ne 2) { Write-Warning "노드 Ready 아님(변이: 경고로 강등)" }' 1 $false
Mut 'A16' 'g4-adopt.ps1' '$stop 의 입력 버퍼 비움 제거(안전 규칙 1)' 'line' 'try { $Host.UI.RawUI.FlushInputBuffer() } catch { }' '      $null = 0' 1 $false
Mut 'A17' 'g4-adopt.ps1' '$kq 의 --request-timeout 제거(터널이 멎으면 무한 대기)' 'text' '$out = & kubectl @ka ''--request-timeout=10s''' '$out = & kubectl @ka' 1 $false
Mut 'A18' 'g4-adopt.ps1' '0) 클러스터 정체 확인 제거' 'text' 'if (-not (@($nodes) | Where-Object { [string]::Equals([string]$_, ''node/joshtech-api'', [StringComparison]::Ordinal) })) {' 'if ($false) {' 1 $false
Mut 'A19' 'g4-adopt.ps1' '1) 머지 전 파드 Ready 확인 제거' 'line' 'if (-not [string]::Equals($p.ready,' '        if ($false) { throw ''x'' } }' 1 $false
Mut 'A26' 'g4-adopt.ps1' '폴링의 ES 출현 조회 실패(exit 1)를 "아직 없음"으로 읽는다(fail-open)' 'text' '& $kq ''ES 출현 확인'' @(''-n'', $NS, ''get'', ''externalsecret'', $ESN, ''--ignore-not-found'', ''-o'', ''name'')' '& $kq ''ES 출현 확인'' @(''-n'', $NS, ''get'', ''externalsecret'', $ESN, ''--ignore-not-found'', ''-o'', ''name'') @(0, 1)' 1 $true
Mut 'A26b' 'g4-adopt.ps1' 'resume 의 ES 존재 확인 실패를 "ES 없음(인수 해제 상태)"으로 읽는다(fail-open · 2라운드에서 발견)' 'text' '& $kq ''ES 존재 확인(resume)'' @(''-n'', $NS, ''get'', ''externalsecret'', $ESN, ''--ignore-not-found'', ''-o'', ''name'')' '& $kq ''ES 존재 확인(resume)'' @(''-n'', $NS, ''get'', ''externalsecret'', $ESN, ''--ignore-not-found'', ''-o'', ''name'') @(0, 1)' 1 $false
Mut 'A28' 'g4-adopt.ps1' '1P) 비밀 입력 직후 클립보드 비움 제거(finally 의 1회만 남는다)' 'line' 'try { Set-Clipboard -Value '' '' } catch { Write-Warning ''클립보드 비우기 실패 — 토큰이' '      $null = 0' 1 $false
Mut 'A31' 'g4-adopt.ps1' 'finally 안의 요약 머리줄을 성공 스트림 출력으로(규칙 5 위반)' 'text' 'Write-Host ''--- G4 단계 요약(런북 §3 기록용) ---''' '''--- G4 단계 요약(런북 §3 기록용) ---''' 1 $false
Mut 'A32' 'g4-adopt.ps1' 'finally 의 정리를 출력 뒤로(규칙 5: 정리 먼저)' 'text' '    Remove-Variable snap, b64, hNow, uNow, hDel, uDel, postHash, postUid, own, trkS, trkE, res, dh, nd, so, sp, oo, out, raw, pmHash, tok -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value '' '' } catch { Write-Warning ''클립보드 비우기 실패 — 1P·1R 에서 토큰을 붙여 넣었다면 Win+V 로 확인하고 직접 비운다'' }
    Write-Host ''''' '    Write-Host ''''
    Remove-Variable snap, b64, hNow, uNow, hDel, uDel, postHash, postUid, own, trkS, trkE, res, dh, nd, so, sp, oo, out, raw, pmHash, tok -ErrorAction SilentlyContinue
    try { Set-Clipboard -Value '' '' } catch { Write-Warning ''클립보드 비우기 실패 — 1P·1R 에서 토큰을 붙여 넣었다면 Win+V 로 확인하고 직접 비운다'' }' 1 $false
Mut 'A33' 'g4-adopt.ps1' '$ErrorActionPreference = Stop 제거(비종료 오류가 다음 문으로 흘러간다)' 'line' '$ErrorActionPreference = ''Stop''' '  $null = 0' 1 $false
Mut 'A34' 'g4-adopt.ps1' '$PSNativeCommandUseErrorActionPreference 끄기 제거' 'line' '$PSNativeCommandUseErrorActionPreference = $false' '  $null = 0' 1 $false
Mut 'A37' 'g4-drill.ps1' '삭제 헬퍼에 --force --grace-period=0 추가(필수 플래그 lint 는 금지 플래그를 보지 않는다)' 'text' '& kubectl ''-n'' $NS ''delete'' ''pod'' $pod ''--wait=false''' '& kubectl ''-n'' $NS ''delete'' ''pod'' $pod ''--force'' ''--grace-period=0'' ''--wait=false''' 1 $false
Mut 'A38' 'g4-adopt.ps1' '인수 전 값의 앞 16자만 화면에 출력(부분 누출)' 'line' '$preHash = & $sha ([string]$snap[3])' '      "변이: 값 앞 16자 $(([string]$snap[3]).Substring(0, 16))"
      $preHash = & $sha ([string]$snap[3])' 1 $false
Mut 'B01' 'g4-restore.ps1' '(복구) 쓰기 뒤 값 되읽기 판정 제거' 'text' 'if (-not [string]::Equals($newHash, $preHash, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $true
Mut 'B02' 'g4-restore.ps1' '(복구) 쓰기 뒤 UID 불변 판정 제거' 'text' 'if (-not [string]::Equals($newUid, $curUid, [StringComparison]::Ordinal)) {' 'if ($false) {' 1 $false
Mut 'B03' 'g4-restore.ps1' '(복구) --force-conflicts 제거(ESO field manager 와 충돌하면 비상 복구가 실패)' 'text' '''apply'' ''--server-side'' ''--force-conflicts''' '''apply'' ''--server-side''' 1 $true
Mut 'B04' 'g4-restore.ps1' '(복구) 해시 게이트가 preHash 를 자기 자신과 비교' 'text' 'if (-not [string]::Equals((& $sha $b64), $preHash, [StringComparison]::Ordinal)) {' 'if (-not [string]::Equals($preHash, $preHash, [StringComparison]::Ordinal)) {' 1 $true
Mut 'B05' 'g4-restore.ps1' '(복구) ES 가 살아 있어도 단어가 restore' 'line' '$word = ''temporary'' }' '      $word = ''restore'' }' 1 $true
Mut 'B06' 'g4-restore.ps1' '(복구) 페이로드를 argv 로도 넘긴다' 'text' '''--request-timeout=30s'' ''-f'' ''-''' '''--request-timeout=30s'' ''-f'' ''-'' "--note=$json"' 1 $false
Mut 'B09' 'g4-restore.ps1' '(복구) UID 변경 정지점 제거' 'line' '& $stop ''3u) UID 가 달라진 것을 알고도' '        $null = 0 }' 1 $false
Mut 'B11' 'g4-restore.ps1' '(복구) 비밀 입력 직후 클립보드 비움 제거(finally 에만 남는다)' 'line' 'try { Set-Clipboard -Value '' '' } catch { Write-Warning ''클립보드 비우기 실패 — 토큰이' '      $null = 0' 1 $false
Mut 'N01' 'g4-drill.ps1' 'break-glass 둘 다 미확인 하드 거부 제거' 'text' 'if ($noGlass) { throw ''break-glass 1차·2차 모두 미확인 — 삭제 거부'' }' '$null = 0' 1 $true
Mut 'N02' 'g4-adopt.ps1' '둘 다 실패인데 단어를 no-oci 로 되돌림(문면과 단어가 갈리지 않는다)' 'text' 'if ($noGlass) { $w0 = ''no-breakglass'' }' 'if ($noGlass) { $w0 = ''no-oci'' }' 1 $true
Mut 'N03' 'g4-adopt.ps1' 'noGlass 판정을 항상 거짓으로(둘 다 실패해도 평소 경로)' 'text' '$noGlass = ((-not $sshPre) -and (-not $ociPre))' '$noGlass = $false' 1 $true
Mut 'N04' 'g4-drill.ps1' 'noGlass 정지점 문면을 평소 문면으로(삭제 거부를 알리지 않는다)' 'line' '$m0 = ''0) ⚠ break-glass' '      $m0 = ''0) 위 실측을 인수한다'' }' 1 $false
Mut 'N05' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: noGlass SKIP 의 단계 기록을 "완료"로(런북에 거짓 기록)' 'text' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {
    & kubectl ''-n'' $NS ''delete'' ''pod'' ''cloudflared-6d4f7c9b8-bb22b'' | Out-Null' 1 $false
Mut 'N06' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 이전 드릴 판정에서 "ES 생성 뒤 시작" 조건 제거(진짜 교체도 드릴 결과로 읽는다)' 'text' '    $resumed = $false' '    $resumed = $false
    & kubectl ''-n'' $NS ''rollout'' ''restart'' ''deploy/cloudflared'' | Out-Null' 1 $true
Mut 'N07' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 이전 드릴 판정에서 새 파드 Ready 조건 제거(NotReady 커넥터를 증명으로 읽는다)' 'text' '      $resumed = $true' '      $resumed = $true
    & kubectl ''-n'' $NS ''rollout'' ''restart'' ''deploy/cloudflared'' | Out-Null' 1 $true
Mut 'N08' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 이전 드릴 판정 조건을 fresh 하나로 축소(파드 수·kept 검사 제거)' 'text' '    $judged = $true' '    $judged = $true
    & kubectl ''-n'' $NS ''rollout'' ''restart'' ''deploy/cloudflared'' | Out-Null' 1 $true
Mut 'N09' 'g4-drill.ps1' 'ES 생성 시각 기준을 epoch 로(모든 새 파드가 "드릴 결과")' 'text' '$esAt = & $esAtGet' '$esAt = ''1970-01-01T00:00:00Z''' 1 $true
Mut 'N10' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 4) 의 이전 드릴 SKIP 분기 제거(드릴을 한 번 더 한다)' 'text' '      $preUid = [string]$snap[0]' '      $preUid = [string]$snap[0]
    & kubectl ''-n'' $NS ''rollout'' ''restart'' ''deploy/cloudflared'' | Out-Null' 1 $true
Mut 'N11' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: drilled: SKIP 에서 드릴 후 서명 기록 제거(다음 실행의 1R 입력이 사라진다)' 'text' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''
    & kubectl ''-n'' $NS ''rollout'' ''restart'' ''deploy/cloudflared'' | Out-Null' 1 $false
Mut 'N11b' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 이전 드릴 SKIP 에서 드릴 후 서명 기록 제거(같은 결함의 두 번째 갈래)' 'text' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {
    & kubectl ''-n'' $NS ''rollout'' ''restart'' ''deploy/cloudflared'' | Out-Null' 1 $false
Mut 'N12' 'g4-drill.ps1' '드릴 정지점 분기의 키 집합 조회 실패를 "정상"으로 읽는다(fail-open)' 'line' 'try { $keysNow = & $keyset } catch' '          try { $keysNow = & $keyset } catch { $keysNow = $KEY }' 2 $false
Mut 'N13' 'g4-adopt.ps1' '폴링 분기의 키 집합을 항상 정상으로 고정(매핑 오류를 kv 오류로 오도)' 'line' 'try { $keysNow = & $keyset } catch' '        $keysNow = $KEY' 1 $false
Mut 'N14' 'g4-adopt.ps1' '복구 안내의 "조회 실패" 분기를 항상 타게(정상 키를 미확인으로 오도)' 'text' 'elseif ([string]::Equals($keysNow, ''(조회 실패)'', [StringComparison]::Ordinal)) {' 'elseif ($true) {' 1 $false
Mut 'N15' 'g4-adopt.ps1' '복구 안내에서 키 집합 줄 자체를 제거(감별 근거 소실)' 'line' 'Write-Host "   지금 Secret 의 키 집합:' '      $null = 0' 1 $false
Mut 'N16' 'g4-adopt.ps1' '키 목록 조회를 키가 아니라 **값**으로(복구 안내에 토큰이 찍힌다)' 'line' '''go-template={{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}''' '      $k = @(@(& $kq ''키 목록'' @(''-n'', $NS, ''get'', ''secret'', $SEC, ''-o'', "jsonpath={.data.$KEY}")) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })' 1 $true
Mut 'N17' 'g4-restore.ps1' '(복구) Argo 조회 성공 판정을 무조건 참으로(빈 응답을 "선언 없음"으로 읽는다)' 'text' '$argoOk = $argoEs.Contains($CTRL)' '$argoOk = $true' 1 $true
Mut 'N18' 'g4-restore.ps1' '(복구) Argo 조회 실패를 "선언 없음"으로 읽는다(catch 에서 argoOk=true)' 'text' 'catch { $argoEs = ''''; $argoOk = $false }' 'catch { $argoEs = ''''; $argoOk = $true }' 1 $true
Mut 'N19' 'g4-restore.ps1' '(복구) 최선 노력을 되돌려 Argo 조회 실패가 복구를 막게 한다(B-3 회귀)' 'text' 'catch { $argoEs = ''''; $argoOk = $false }' 'catch { throw }' 1 $false
Mut 'N20' 'g4-restore.ps1' '(복구) 양성 대조 행을 빈 문자열로(무엇이 와도 "조회가 됐다")' 'text' '$CTRL = ''cert-manager/cloudflare-dns-token=''' '$CTRL = ''''' 1 $true
Mut 'N21' 'g4-adopt.ps1' '1R) pm 분기의 클립보드 기록 검사 제거' 'line' 'if ($null -eq $ch0 -or $ch0 -ne 0)' '        $null = 0' 1 $false
Mut 'N22' 'g4-adopt.ps1' '1R) pm 분기가 토큰을 평문 Read-Host 로 받는다' 'text' '(& $readSecret ''PM 의 터널 토큰 원본(화면에 남지 않는다 · 해시만 남긴다)'')' '(& $ask ''PM 의 터널 토큰 원본'')' 1 $true
Mut 'N23' 'g4-adopt.ps1' '1R) pm 분기가 base64 없이 해시를 유도(기준값이 어긋난다)' 'text' '$preHash = & $sha ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((& $readSecret ''PM 의 터널 토큰 원본(화면에 남지 않는다 · 해시만 남긴다)'').Trim())))' '$preHash = & $sha ((& $readSecret ''PM 의 터널 토큰 원본(화면에 남지 않는다 · 해시만 남긴다)'').Trim())' 1 $true
Mut 'N24' 'g4-adopt.ps1' '1R) pm 분기의 "미검증 전제" 경고 제거' 'line' 'Write-Warning ''preHash 를 PM 원본에서 유도했다' '        $null = 0 }' 1 $false
Mut 'N25' 'g4-restore.ps1' '(복구) 쓰기 성공을 곧 확인 성공으로(verified 를 apply 직후에 세운다)' 'text' '$wrote = $true' '$wrote = $true; $verified = $true' 1 $false
Mut 'P01' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: drilled: 접두어 인식 제거(운영자 선언이 무시된다 → 재인수에서 두 번째 삭제)' 'text' '    $resumed = $false' '    $resumed = $false
    & kubectl ''-n'' $NS ''scale'' ''deploy/cloudflared'' ''--replicas=0'' | Out-Null' 1 $true
Mut 'P02' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 4) 의 drilled: SKIP 분기 제거(3) 의 같은 조건과 구분하려고 줄 앵커를 쓴다)' 'text' '      $resumed = $true' '      $resumed = $true
    & kubectl ''-n'' $NS ''scale'' ''deploy/cloudflared'' ''--replicas=0'' | Out-Null' 1 $true
Mut 'P03' 'g4-drill.ps1' '"인수 뒤 시작한 파드" 조건을 다시 Ready 로 좁힘(NotReady 드릴 파드가 있어도 또 지운다)' 'text' 'if ($after.Count -gt 0)' 'if ($false)' 1 $true
Mut 'P04' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 인수 뒤 시작한 NotReady 파드 SKIP 분기 제거' 'text' '    $judged = $true' '    $judged = $true
    & kubectl ''-n'' $NS ''scale'' ''deploy/cloudflared'' ''--replicas=0'' | Out-Null' 1 $true
Mut 'P05' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: R2 뒤 재인수의 드릴 단어를 drill 로 되돌림(사람 확인이 사라진다)' 'text' '      $preUid = [string]$snap[0]' '      $preUid = [string]$snap[0]
    & kubectl ''-n'' $NS ''scale'' ''deploy/cloudflared'' ''--replicas=0'' | Out-Null' 1 $true
Mut 'P06' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 기준값을 이어받은 실행·재인수의 드릴 정지점 문면을 평소 문면으로(이미 드릴했는지 묻지 않는다)' 'text' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''
    & kubectl ''-n'' $NS ''scale'' ''deploy/cloudflared'' ''--replicas=0'' | Out-Null' 1 $true
Mut 'P07' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: SKIP 분기의 커넥터 Ready 경고 제거(한쪽이 NotReady 인데 OK 로 끝난다)' 'text' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {
    & kubectl ''-n'' $NS ''scale'' ''deploy/cloudflared'' ''--replicas=0'' | Out-Null' 1 $true
Mut 'P08' 'g4-adopt.ps1' '1P) 건너뛰기 제거(PM 유도 기준값을 같은 PM 값과 대조해 "검증했다"고 기록한다)' 'text' 'if ($preFromPm) { Write-Warning ''1P) PM 원본 대조를 건너뛴다' 'if ($false) { Write-Warning ''1P) PM 원본 대조를 건너뛴다' 1 $false
Mut 'P09' 'g4-adopt.ps1' 'PM 유도 표시($preFromPm) 자체를 세우지 않는다' 'text' '$preFromPm = $true
        $pmNote = '' (PM 유도 — 라이브로 검증된 적 없음)''' '        $null = 0' 1 $false
Mut 'P10' 'g4-adopt.ps1' '복구 안내의 "기준값이 PM 유도다" 경고 제거(kv 를 낡은 PM 값으로 정정하게 만든다)' 'line' 'if ($preFromPm) {' '      if ($false) {' 2 $true
Mut 'P11' 'g4-adopt.ps1' '기준값 출력(화면)의 PM 유도 꼬리표 제거(런북에 "검증된 기준값"으로 남는다)' 'line' '"기준값 preHash = $preHash$pmNote"' '    "기준값 preHash = $preHash"' 1 $false
Mut 'P11b' 'g4-adopt.ps1' '기준값 출력(요약)의 PM 유도 꼬리표 제거 — 같은 결함의 두 번째 갈래' 'line' '"기준값 preHash = $preHash$pmNote"' '      Write-Host "기준값 preHash = $preHash"' 2 $false
Mut 'P12' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 요약의 drilled: 접두어 제거(다음 실행이 접두어 없이 붙여 넣게 된다)' 'text' '    $resumed = $false' '    $resumed = $false
    & kubectl ''-n'' $NS ''patch'' ''secret'' ''cloudflared-tunnel'' ''-p'' ''{}'' | Out-Null' 1 $true
Mut 'P13' 'g4-adopt.ps1' 'R3 조각에서 히스토리 끄기 제거(개행 섞인 붙여넣기의 나머지가 히스토리로 간다)' 'line' 'Write-Host ''     set +o history''' '      $null = 0' 1 $false
Mut 'P14' 'g4-adopt.ps1' 'R3 조각에서 붙여넣기 형식·길이 검사 제거(빈 값·잘린 값을 그대로 쓴다)' 'line' 'Write-Host ''     case "$T" in' '      $null = 0' 1 $true
Mut 'P15' 'g4-adopt.ps1' 'R3 조각에서 쓰기 뒤 해시 되읽기 제거(잠긴 상태에서 확인 수단이 없어진다)' 'line' 'Write-Host ''     sudo k3s kubectl -n cloudflared get secret cloudflared-tunnel -o jsonpath=' '      $null = 0' 1 $true
Mut 'P16' 'g4-adopt.ps1' 'R3 ② 의 finalizer·webhook 단서 제거(delete 가 멎는 이유를 알 수 없다)' 'line' 'Write-Host ''   ② 노드 셸(bash)에서 Argo 반영을 확인하고 ES 를 지운다' '      $null = 0' 1 $false
Mut 'P17' 'g4-adopt.ps1' '0b 의 전제(클립보드·kubeconfig·권한 하드 검사) 문구 제거' 'line' 'Write-Host ''    ⚠ 전제: g4-restore 는 해시 대조에 닿기 전에' '      $null = 0' 1 $false
Mut 'V01' 'g4-adopt.ps1' 'noGlass 를 -and 에서 -or 로(한쪽만 실패해도 삭제 거부 · 단어가 갈리지 않는다)' 'text' '$noGlass = ((-not $sshPre) -and (-not $ociPre))' '$noGlass = ((-not $sshPre) -or (-not $ociPre))' 1 $false
Mut 'V02' 'g4-adopt.ps1' 'ssh 만 실패한 실행의 단어를 go 로 되돌림(창 A 미대조를 사람에게 알리지 않는다)' 'text' 'elseif (-not $sshPre) { $w0 = ''noglass'' }' 'elseif ($false) { $w0 = ''noglass'' }' 1 $true
Mut 'V03' 'g4-adopt.ps1' '창 A 대조의 boot_id 형식 검사 제거(ssh 가 무엇을 돌려주든 대조 상대로 삼는다)' 'text' '$sshPre = [regex]::IsMatch($bootPre, ''\A[0-9a-f]{8}\z'')' '$sshPre = (-not [string]::IsNullOrWhiteSpace($bootPre))' 1 $true
Mut 'V04' 'g4-adopt.ps1' 'oci 프로브의 빈 응답 검사 제거(exit 0 + 빈 출력을 2차 break-glass 로 센다)' 'text' '$ociPre = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace((& $txt $oo)))' '$ociPre = ($LASTEXITCODE -eq 0)' 1 $true
Mut 'V05' 'g4-drill.ps1' 'ES creationTimestamp 형식 검사 제거(형식이 다르면 시각 비교가 무의미해진다)' 'line' 'ES creationTimestamp 형식이 기대와 다르다' '      $null = 0' 1 $true
Mut 'V06' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: noGlass 거부 분기가 드릴 후 서명을 무조건 기록한다(하지도 않은 드릴을 요약이 drilled: 로 인쇄)' 'text' '      $resumed = $true' '      $resumed = $true
    & kubectl ''-n'' $NS ''patch'' ''secret'' ''cloudflared-tunnel'' ''-p'' ''{}'' | Out-Null' 1 $true
Mut 'V07' 'g4-adopt.ps1' '키 목록 조회를 fail-open 으로(조회 실패를 "키가 하나도 없다"로 읽어 매핑 오류로 오진)' 'line' '키 목록' '      $k = @(@(& $kq ''키 목록'' @(''-n'', $NS, ''get'', ''secret'', $SEC, ''-o'', ''go-template={{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}'') @(0, 1)) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_.Length -gt 0 })' 1 $false
Mut 'V08' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: SKIP 분기의 Ready 경고를 화면에서 지운다(요약 줄만 남는다)' 'text' '    $judged = $true' '    $judged = $true
    & kubectl ''-n'' $NS ''patch'' ''secret'' ''cloudflared-tunnel'' ''-p'' ''{}'' | Out-Null' 1 $false
Mut 'V09' 'g4-adopt.ps1' 'PM 유도 실행의 1P 기록을 일반 skip-pm 으로(자기 자신 대조였다는 사실이 기록에서 사라진다)' 'text' '$pmAns = ''pm-derived''' '$pmAns = ''skip-pm''' 1 $false
Mut 'V10' 'g4-restore.ps1' '(복구) Secret type 빈 응답 검사 제거(빈 type 을 그대로 apply 에 싣는다)' 'line' 'Secret 의 type 을 읽지 못했다' '    $null = 0' 1 $false
Mut 'V11' 'g4-restore.ps1' '(복구) Git 선언 판정에서 requiresPruning=true 예외를 뺀다(정상 순서인데 temporary 로 막는다)' 'text' '$gitLeft = ($argoOk -and $argoEs.Contains("$NS/$ESN=") -and -not $argoEs.Contains("$NS/$ESN=true"))' '$gitLeft = ($argoOk -and $argoEs.Contains("$NS/$ESN="))' 1 $false
Mut 'V12' 'g4-restore.ps1' '(복구) 조회 성공 판정을 "응답이 비어 있지 않다"로(양성 대조 행을 보지 않는다)' 'text' '$argoOk = $argoEs.Contains($CTRL)' '$argoOk = ($argoEs.Length -gt 0)' 1 $true
Mut 'V13' 'g4-adopt.ps1' '파드 행 형식 검사 제거(jsonpath 형식이 달라지면 오판으로 진행한다)' 'line' '파드 행 형식이 기대와 다르다' '        $null = 0' 1 $true
Mut 'V14' 'g4-adopt.ps1' '빈 파드 목록 검사 제거(빈 응답을 "파드 없음"으로 읽는다)' 'line' '파드 목록이 비었다' '      $null = 0' 1 $false
Mut 'V15' 'g4-drill.ps1' '0) 권한 확인에서 ''delete pods'' 를 뺀다(삭제 권한을 미리 확인하지 않는다)' 'text' 'foreach ($v in ''get secrets'', ''delete pods'') {' 'foreach ($v in ''get secrets'') {' 1 $false
Mut 'V16' 'g4-drill.ps1' '남길 파드의 기준 서명을 삭제 대상에서 뽑는다(드릴 대기 판정이 엉뚱한 파드를 본다)' 'text' '$survSig = [string]$sv0.sig' '$survSig = [string]$tg0.sig' 1 $true
Mut 'V17' 'g4-adopt.ps1' '폴링 진행 줄 제거(프롬프트가 약속한 "진행 줄이 보이면 머지" 신호가 사라진다)' 'line' '초 경과(ES=$nm reason=$reason' '      $null = 0' 1 $false
Mut 'V18' 'g4-restore.ps1' '(복구) 페이로드의 type 을 Opaque 로 하드코딩(실제 type 을 읽고도 쓰지 않는다)' 'text' 'kind = ''Secret''; type = $type' 'kind = ''Secret''; type = ''Opaque''' 1 $false
Mut 'V19' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 드릴 후 서명 줄을 언제나 인쇄(드릴하지 않은 실행도 drilled: 를 준다)' 'text' '      $preUid = [string]$snap[0]' '      $preUid = [string]$snap[0]
    & kubectl ''-n'' $NS ''patch'' ''secret'' ''cloudflared-tunnel'' ''-p'' ''{}'' | Out-Null' 1 $true
Mut 'V20' 'g4-adopt.ps1' '2) 단계 기록을 폴링 전에 남기지 않는다(폴링 중 중단하면 요약이 "미실행"이라고 말한다)' 'line' '$log[''2) 머지 대기''] = "$w2 입력됨' '    $null = 0' 1 $false
Mut 'V21' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: "인수 뒤 시작" 필터를 건너뛰고 Ready 파드만 보면 SKIP(드릴이 영영 일어나지 않는다)' 'text' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''
    & kubectl ''-n'' $NS ''patch'' ''secret'' ''cloudflared-tunnel'' ''-p'' ''{}'' | Out-Null' 1 $false
Mut 'V22' 'g4-drill.ps1' '드릴 대상 정렬 제거(목록 순서가 startTime 순서를 대신한다)' 'line' '[Array]::Sort($ord, [StringComparer]::Ordinal)' '        $null = 0' 1 $true
Mut 'R4-01' 'g4-adopt.ps1' 'R3 조각의 case 패턴을 히스토리 확장에 걸리는 `!!` 로 되돌림(정상 토큰도 늘 BROKEN-PASTE)' 'text' 'case "$T" in ''''''''|*[!''''!''''-~]*)' 'case "$T" in ''''''''|*[!!-~]*)' 1 $true
Mut 'R4-02' 'g4-adopt.ps1' 'R3 조각을 "첫 줄부터 실행한다"는 지시 제거(중간부터 재시도 → 히스토리 확장 덫)' 'line' '이 조각은 **첫 줄(set +o history)부터** 실행한다' '      $null = 0' 1 $true
Mut 'R4-03' 'g4-adopt.ps1' 'R3 의 갈래 판정을 옛 거짓 문면으로 되돌림("해시가 다르면 아무것도 쓰지 않은 것")' 'line' 'Write-Host ''     판정은 네 갈래다' '      Write-Host ''     BROKEN-PASTE·TOO-SHORT 가 찍혔거나 해시가 다르면 **아무것도 쓰지 않은 것**이다 — 다시 붙여 넣는다.''' 1 $true
Mut 'R4-04' 'g4-adopt.ps1' 'R3 의 화면 에코 경고 제거(스크롤백에 남은 토큰을 알리지 않는다)' 'line' '이 터미널 화면에 이미 에코됐다' '      $null = 0' 1 $false
Mut 'R4-05' 'g4-adopt.ps1' 'R3 ④ 의 자리표시자를 붙여 넣으면 bash 문법 오류가 나는 표기로 되돌림' 'text' 'delete pod POD_NAME     # POD_NAME' 'delete pod <이름 하나>     # POD_NAME' 1 $false
Mut 'R4-06' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 가드 ⓓ 제거(라벨이 지워진 재인수가 사람 확인 없이 정상 캡처 경로로 들어온다)' 'text' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {
    & kubectl ''-n'' $NS ''patch'' ''secret'' ''cloudflared-tunnel'' ''-p'' ''{}'' | Out-Null' 1 $true
Mut 'R4-07' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 1D) 의 잘못된 답을 first 로 처리(빈 Enter·오타가 드릴을 여는 쪽으로 간다)' 'text' '    $resumed = $false' '    $resumed = $false
    & kubectl ''-n'' $NS ''label'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R4-08' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 1D) 의 재인수 표시를 4) 단어에 반영하지 않는다(first-drill 로 갈리지 않는다)' 'text' '      $resumed = $true' '      $resumed = $true
    & kubectl ''-n'' $NS ''label'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R4-09' 'g4-adopt.ps1' '스냅샷 jsonpath 에서 data-hash 필드 제거(가드 ⓓ 의 근거가 사라진다)' 'text' '{.metadata.annotations.reconcile\.external-secrets\.io/data-hash}|{.data.$KEY}' '{.data.$KEY}' 1 $true
Mut 'R4-10' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: $already SKIP 분기의 반대쪽 Ready 판정 제거(이중화 미성립이 조용히 넘어간다)' 'text' '    $judged = $true' '    $judged = $true
    & kubectl ''-n'' $NS ''label'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $false
Mut 'R4-10b' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: $after SKIP 분기의 반대쪽 Ready 판정 제거(같은 결함의 두 번째 갈래)' 'text' '      $preUid = [string]$snap[0]' '      $preUid = [string]$snap[0]
    & kubectl ''-n'' $NS ''label'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $false
Mut 'R4-11' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 요약의 쌍둥이 줄 차단 제거(접두어 없는 기준값 파드서명을 그대로 다시 인쇄)' 'text' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''
    & kubectl ''-n'' $NS ''label'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R4-12' 'g4-drill.ps1' '4) 정지점의 break-glass 재확인 문면 제거(0) 이후 창 A 가 끊겨도 묻지 않는다)' 'text' '창 A에서 Enter를 쳐 세션을 지금 다시 확인한다' '' 1 $true
Mut 'R4-13' 'g4-adopt.ps1' 'UID 안내에서 현재 UID 줄 제거(새 UID 를 찾을 방법을 주지 않는다)' 'line' 'Write-Host "   지금   UID    : $uidNow' '      $null = 0' 1 $false
Mut 'R4-14' 'g4-adopt.ps1' 'UID 안내용 $uidNow 를 3) 판정에서 세우지 않는다' 'line' '$uidNow = $postUid' '      $null = 0' 1 $false
Mut 'R4-14b' 'g4-adopt.ps1' 'UID 안내용 $uidNow 를 2) 감시 루프에서 세우지 않는다(같은 결함의 두 번째 갈래)' 'line' '$uidNow = $uNow' '        $null = 0' 1 $false
Mut 'R4-14c' 'g4-drill.ps1' 'UID 안내용 $uidNow 를 삭제 직전 재확인에서 세우지 않는다(세 번째 갈래)' 'line' '$uidNow = $uDel' '          $null = 0' 1 $false
Mut 'R4-15' 'g4-adopt.ps1' '라벨 삭제 안내에서 data-hash 경고 제거(지우면 잠금이 모두 풀린다는 사실을 숨긴다)' 'line' '**data-hash 어노테이션은 어떤 경우에도 지우지 않는다.**' '      $null = 0' 1 $true
Mut 'R5-01' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 드릴 단어 게이트를 4R 의 일시적 사실($esGone)로 되돌림(먼저 머지한 재인수에서 게이트가 사라진다 · B4-01)' 'text' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {
    & kubectl ''-n'' $NS ''label'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R5-02' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 드릴 단어 게이트에서 resume 을 통째로 뺀다(1R 로 이어 온 실행이 drill 하나로 지운다 · B4-01)' 'text' '    $resumed = $false' '    $resumed = $false
    & kubectl ''-n'' $NS ''annotate'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R5-03' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 요약의 쌍둥이 **값** 억제 분기 제거(접두어 없는 같은 값이 파드서명 줄로 다시 나간다 · B4-03)' 'text' '      $resumed = $true' '      $resumed = $true
    & kubectl ''-n'' $NS ''annotate'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R5-04' 'g4-adopt.ps1' 'R3 의 (0) apply 실패 갈래 제거(쓰기 0건인 실패를 "이미 썼을 수 있다"로 읽게 된다 · A4-1)' 'line' '(0) **apply 줄에 kubectl 오류가 찍혔다' '      $null = 0' 1 $true
Mut 'R5-05' 'g4-adopt.ps1' 'R3 의 (0) 에서 라이브 type 읽기 명령 제거(잠긴 운영자가 원인을 고칠 수단을 잃는다 · A4-1)' 'line' '{.type}' '      $null = 0' 1 $true
Mut 'R5-06' 'g4-adopt.ps1' 'R3 의 (3) 에서 "apply 줄의 오류는 (0) 이다" 구분 제거(두 갈래가 다시 섞인다 · A4-1)' 'line' '※ apply 줄의 오류는 (3) 이 아니라 (0) 이다.' '      Write-Host ''           (파이프라인 종료 코드는 0 이라 조용히 지나간다). 값은 옳게 복구됐을 수도 있다.''' 1 $true
Mut 'R5-07' 'g4-adopt.ps1' 'R3 조각에서 case 앞의 unset B 제거(앞선 시도의 B 가 남아 BROKEN-PASTE 인데도 틀린 값을 쓴다 · A4-2)' 'line' 'Write-Host ''     unset B''' '      $null = 0' 1 $true
Mut 'R5-07b' 'g4-adopt.ps1' 'R3 조각에서 apply 뒤의 unset B 제거(같은 줄의 두 번째 갈래 · A4-2)' 'line' 'Write-Host ''     unset B''' '      $null = 0' 2 $true
Mut 'R5-08' 'g4-adopt.ps1' 'R3 조각에서 unset T 제거(평문 토큰이 노드 셸 변수에 남는다 · A4-2)' 'line' 'Write-Host ''     unset T''' '      $null = 0' 1 $true
Mut 'R5-09' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: noGlass 거부 분기의 반대쪽 Ready 판정 제거(확인된 복구 경로 0 인 실행이 "OK"로 끝난다 · A4-3)' 'text' '    $judged = $true' '    $judged = $true
    & kubectl ''-n'' $NS ''annotate'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R5-09b' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: drilled: SKIP 분기의 반대쪽 Ready 판정 제거(A4-3)' 'text' '      $preUid = [string]$snap[0]' '      $preUid = [string]$snap[0]
    & kubectl ''-n'' $NS ''annotate'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $false
Mut 'R5-09c' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 이전 드릴 SKIP 분기의 반대쪽 Ready 판정 제거(A4-3)' 'text' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''
    & kubectl ''-n'' $NS ''annotate'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $false
Mut 'R5-09d' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: nopods SKIP 분기의 반대쪽 Ready 판정 제거(A4-3)' 'text' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {' '    if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {
    & kubectl ''-n'' $NS ''annotate'' ''secret'' ''cloudflared-tunnel'' ''unsafe=true'' | Out-Null' 1 $true
Mut 'R5-10' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 요약의 기준값 파드서명 줄에서 "어느 줄을 넣어라" 단서만 뗀다(이름은 그대로 · A4-4)' 'text' '    $resumed = $false' '    $resumed = $false
    & kubectl ''-n'' $NS ''replace'' ''-f'' ''-'' | Out-Null' 1 $false
Mut 'R5-11' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 요약의 기준값 파드서명 줄을 통째로 제거(운영자가 이 실행의 입력을 되짚을 수 없다 · A4-4)' 'text' '      $resumed = $true' '      $resumed = $true
    & kubectl ''-n'' $NS ''replace'' ''-f'' ''-'' | Out-Null' 1 $false
Mut 'R5-11b' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 요약의 접두어 없는 기준값 파드서명 줄만 제거(같은 결함의 두 번째 갈래 · A4-4)' 'text' '    $judged = $true' '    $judged = $true
    & kubectl ''-n'' $NS ''replace'' ''-f'' ''-'' | Out-Null' 1 $false
Mut 'R5-12' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 화면의 "이미 드릴했다고 선언됐다" 단서 제거(그 실행이 삭제 0 이라는 사실이 화면에서 사라진다 · A4-4)' 'text' '      $preUid = [string]$snap[0]' '      $preUid = [string]$snap[0]
    & kubectl ''-n'' $NS ''replace'' ''-f'' ''-'' | Out-Null' 1 $false
Mut 'R5-13' 'g4-adopt.ps1' 'adopt 쓰기 금지 대체: 1D) 오답 안내에서 "모르겠으면 drilled" 제거(안전한 쪽을 알려 주지 않는다 · A4-4)' 'text' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''' '    Write-Host ''이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).''
    & kubectl ''-n'' $NS ''replace'' ''-f'' ''-'' | Out-Null' 1 $false
Mut 'R5-14' 'g4-adopt.ps1' 'R3 의 case 줄 따옴표 근거 주석 제거(다음 편집자가 B3-01 을 되돌린다 · A4-4)' 'line' 'case 줄의' '      Write-Host ''       재시도할 때도 반드시 첫 줄부터다.''' 1 $true
Mut 'R5-15' 'g4-adopt.ps1' 'B4-02 로 바로잡은 히스토리 확장 기전 설명 제거(다음 편집자가 "[ 뒤면 안전하다"를 믿는다)' 'line' '보호하는 것은 여는 대괄호가 아니라' '      $null = 0' 1 $false
Mut 'R5-16' 'g4-drill.ps1' '1D) 의 단어 비교를 Ordinal → -eq(컬처 민감 · 안전 규칙 8)' 'text' '[string]::Equals([string]$a, $word, [StringComparison]::Ordinal)' '([string]$a -eq $word)' 1 $false
Mut 'R5-17' 'g4-drill.ps1' '$nrWarn 의 Ready 비교를 Ordinal → -ne(컬처 민감 · 안전 규칙 8)' 'text' '-not [string]::Equals($_.ready, ''True'', [StringComparison]::Ordinal)' '($_.ready -ne ''True'')' 1 $true
Mut 'A5-12' 'g4-adopt.ps1' 'R3 base64 개행 방지 제거' 'text' 'base64 -w0' 'base64' 1 $true
Mut 'A5-13' 'g4-adopt.ps1' 'R3 최소 길이 제거' 'text' '"${#T}" -ge 32' '"${#T}" -ge 1' 1 $true
Mut 'A5-14' 'g4-adopt.ps1' 'R3 field-manager 충돌 플래그 제거' 'text' 'apply --server-side --force-conflicts --field-manager=t045-restore' 'apply --server-side --field-manager=t045-restore' 1 $true
Mut 'A5-15' 'g4-adopt.ps1' 'R3 1개만 삭제 안내 제거' 'text' '④ 위 sha256sum 대조로 값이 옳은 것을 확인한 뒤에만 파드를 **1개만** 지운다' '④ 파드를 지운다' 1 $true
Mut 'A5-17' 'g4-adopt.ps1' 'EOF 진단 제거' 'text' 'if ($null -eq $a)' 'if ($false)' 1 $true
Mut 'A5-18' 'g4-adopt.ps1' 'EOF 진단 제거' 'text' 'if ($null -eq $v)' 'if ($false)' 1 $true
Mut 'A5-19' 'g4-adopt.ps1' '비밀 EOF 진단 제거' 'text' 'if ($null -eq $ss -or $ss.Length -eq 0)' 'if ($false)' 1 $true
Mut 'A5-20' 'g4-adopt.ps1' '런타임 동사 허용 목록 제거' 'text' 'if (-not ([string]::Equals([string]$ka[$vi], ''get'', [StringComparison]::Ordinal) -or [string]::Equals([string]$ka[$vi], ''auth'', [StringComparison]::Ordinal)))' 'if ($false)' 1 $true
Mut 'A5-21' 'g4-adopt.ps1' '권한 namespace 제거' 'text' ' + @(''-n'', $NS)' '' 1 $true
Mut 'A5-23' 'g4-drill.ps1' '드릴 직후 창A 재접속 안내 제거' 'line' 'Write-Warning ''창 A 의 ssh 세션이 방금 삭제한 커넥터' '        $null = 0' 1 $true
Mut 'D01' 'g4-drill.ps1' 'ES Ready 상태 필터 제거' 'text' '-not [string]::Equals([string]$esState[0], ''True'', [StringComparison]::Ordinal)' '$false' 1 $true
Mut 'D02' 'g4-drill.ps1' '해시 게이트 제거' 'text' 'if (-not [string]::Equals($postHash, $preHash, [StringComparison]::Ordinal))' 'if ($false)' 1 $true
Mut 'D03' 'g4-drill.ps1' 'UID 게이트 제거' 'text' 'if (-not [string]::Equals($postUid, $preUid, [StringComparison]::Ordinal))' 'if ($false)' 1 $true
Mut 'D04' 'g4-drill.ps1' 'data-hash 게이트 제거' 'text' 'if ([string]::IsNullOrWhiteSpace($dh))' 'if ($false)' 1 $true
Mut 'D05' 'g4-drill.ps1' '이름 타자 제거' 'line' '& $stop "지울 파드 이름' '    $null = 0' 1 $true
Mut 'D06' 'g4-drill.ps1' '삭제 대상 변동 재확인 제거' 'text' 'if (-not [string]::Equals($pd2.sig, $pd.sig, [StringComparison]::Ordinal)' 'if ($false' 1 $true
Mut 'D07' 'g4-drill.ps1' '빈 Secret 거부 제거' 'text' 'if ([string]::IsNullOrWhiteSpace($b64))' 'if ($false)' 1 $true
Mut 'D08' 'g4-drill.ps1' '삭제 뒤 생존 Ready 확인 제거' 'line' 'if (-not [string]::Equals($sv[0].ready' '          $null = 0' 1 $true
Mut 'R3-UNCERTAIN' 'g4-adopt.ps1' 'R3 결과 불명 오도' 'text' '결과 미확정이다.' '쓰기는 0건이다.' 1 $true
Mut 'R1-03' 'g4-drill.ps1' '삭제 대상 잔존·3파드 상태도 완료로 판정' 'text' '@($pn.items).Count -eq 2 -and @($pn.items | Where-Object { [string]::Equals($_.name, $target, [StringComparison]::Ordinal) }).Count -eq 0 -and ' '' 1 $true
Mut 'R1-05' 'g4-drill.ps1' '전제 통과 요약 누락' 'line' '$log[''1) 드릴 전제''] = ''PASS' '    $null = 0' 1 $false
Mut 'R2-02' 'g4-drill.ps1' '삭제 후 완전 단절 R3 파일 인계 제거' 'line' "Write-Warning 'kubectl·SSH가 막혔으면" '      $null = 0' 1 $true
# ---------------------------------------------------------------- 사본 생성
$sel = @($M | Where-Object { [string]::IsNullOrWhiteSpace($Only) -or [string]::Equals($_.id, $Only, [StringComparison]::Ordinal) })
$jobs = [System.Collections.ArrayList]::new()
$rows = [System.Collections.ArrayList]::new()
foreach ($m in $sel) {
  $d = Join-Path $root $m.id
  $null = New-Item -ItemType Directory -Path $d -Force
  Copy-Item (Join-Path $here $A) (Join-Path $d $A)
  Copy-Item (Join-Path $here $R) (Join-Path $d $R)
  Copy-Item (Join-Path $here $DrillFile) (Join-Path $d $DrillFile)
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
$harness = Join-Path $root 'harness-g4.ps1'
Copy-Item -LiteralPath (Join-Path $here 'harness-g4.ps1') -Destination $harness
$classifierText = ${function:Get-MutantClassification}.ToString()
$res = $jobs | ForEach-Object -ThrottleLimit $Throttle -Parallel {
  $j = $_
  $o = & pwsh -NoProfile -File $using:harness -BlockDir $j.dir 2>&1
  $rc = $LASTEXITCODE
  $txt = ($o | ForEach-Object { [string]$_ }) -join "`n"
  [IO.File]::WriteAllText((Join-Path $j.dir 'harness.out.txt'), $txt, (New-Object Text.UTF8Encoding $false))
  [IO.File]::WriteAllText((Join-Path $j.dir 'harness.exit.txt'), [string]$rc, (New-Object Text.UTF8Encoding $false))
  $classification = & ([scriptblock]::Create($using:classifierText)) -ExitCode $rc -OutputText $txt
  [pscustomobject]@{ id = $j.m.id; file = $j.m.file; lock = $j.m.lock; caught = $classification.caught; by = $classification.by; exitCode = $rc; desc = $j.m.desc } }
foreach ($r in $res) { [void]$rows.Add($r) }
$sorted = @($rows | Sort-Object id)
$sorted | Format-Table -AutoSize -Wrap -Property id, file, lock, caught, desc, by | Out-String -Width 300 | Write-Host
$caught = @($sorted | Where-Object { [string]::Equals($_.caught, 'CAUGHT', [StringComparison]::Ordinal) }).Count
$esc = @($sorted | Where-Object { [string]::Equals($_.caught, 'ESCAPED', [StringComparison]::Ordinal) })
$anch = @($sorted | Where-Object { [string]::Equals($_.caught, 'ANCHOR-ERR', [StringComparison]::Ordinal) -or [string]::Equals($_.caught, 'NO-OP', [StringComparison]::Ordinal) })
$runnerErrors = @($sorted | Where-Object { [string]::Equals($_.caught, 'RUNNER-ERROR', [StringComparison]::Ordinal) })
Write-Host ("변이 {0} 개 중 하네스가 잡은 것 {1} 개 · 빠져나간 것 {2} 개 · 앵커/무효 {3} 개" -f $sorted.Count, $caught, $esc.Count, $anch.Count)
Write-Host ('ESCAPED: ' + (($esc | ForEach-Object { $_.id + $(if ($_.lock) { '(잠금)' } else { '' }) }) -join ' '))
Write-Host ('ANCHOR-ERR/NO-OP: ' + (($anch | ForEach-Object { $_.id }) -join ' '))
Write-Host ('RUNNER-ERROR: ' + (($runnerErrors | ForEach-Object { $_.id }) -join ' '))
Write-Host ("잠금으로 이어지는 변이 {0} 개 중 CAUGHT {1} 개" -f @($sorted | Where-Object { $_.lock }).Count,
  @($sorted | Where-Object { $_.lock -and [string]::Equals($_.caught, 'CAUGHT', [StringComparison]::Ordinal) }).Count)
if (-not $KeepDirs) {
  $resolvedRoot = (Resolve-Path -LiteralPath $root -ErrorAction Stop).ProviderPath
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $resolvedRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetFileName($resolvedRoot)).StartsWith('t045-g4-mut-', [StringComparison]::Ordinal)) { throw '임시 변이 디렉터리 경계 오류 — 삭제하지 않는다' }
  Remove-Item -LiteralPath $resolvedRoot -Recurse -Force }
else { Write-Host "사본 위치: $root" }
if ($caught -ne $sorted.Count) { exit 1 }
