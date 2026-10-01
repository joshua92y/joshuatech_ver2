# tests/platform/reboot.tests.ps1 — 노드 A 재부팅 후 자동 복구 단언 (T034, US2 AC4) + "실제로 재부팅됐는가" 가드(T048 선행)
# Run (평상시 — 러너 tests/platform/run-platform-tests.ps1이 인자 없이 호출):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1
#     → 전제(kubectl·KUBECONFIG·agent-view 신원)만 검사하고 reboot-1..4는 SKIP, exit 0. 재부팅 리허설이 아닐 때
#       다른 플랫폼 테스트를 막지 않기 위한 동작이며, 전제 실패(kubectl 부재·KUBECONFIG 부재·신원 불일치)는 여기서도 FAIL이다.
# Run (재부팅 리허설 — 운영자 수동 트리거, 세 단계):
#   ① 재부팅 전 — 노드 A의 부팅 ID를 적어 둔다(읽기 전용, 폴링 없음):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -Baseline
#     → 전제(kubectl·KUBECONFIG·agent-view 신원) 뒤 `kubectl get nodes -l role=platform -o json`을 한 번 읽고
#       'baseline: node=<이름> bootID=<status.nodeInfo.bootID> ready=<Ready 조건 status 또는 none>' 한 줄을 낸다(exit 0).
#       조회 실패 · 노드 수 ≠ 1 · bootID 부재/형식 불일치는 FAIL reboot-baseline(exit 1).
#   ② 운영자가 SSH(cloudflared 터널)로 노드 A를 재부팅한다(이 파일은 재부팅하지 않는다 — 관찰만 한다).
#   ③ 재부팅 직후 — ①의 bootID와 node 이름을 둘 다 넘겨 바로 실행한다(둘 다 필수):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -AfterReboot -BaselineBootId <①의 bootID> -BaselineNode <①의 node>
#     → 이 스크립트의 시작 시각을 0초로 잡고 아래 계약을 한 루프에서 폴링해 조건별 통과 시각(경과 초)을 기록한다.
#       간격은 명목 10 s다(한 라운드가 kubectl 호출·port-forward 시간만큼 길어지면 그만큼 늘어난다). 조건마다 마감이 있고,
#       마감 판정은 관측을 "시작한" 시각 기준이다: 마감 안에 시작한 관측이 충족이면 통과(그 관측이 마감을 넘겨 끝났으면 PASS detail에
#       'observation started at Ns'), 마감 뒤에 시작한 관측의 충족은 FAIL("met late …"), 미충족 관측이 마감을 넘겨 끝나면 FAIL
#       ("not met within …"). 그래서 마감이 실제로 느슨해지는 폭은 한 번의 관측에 걸리는 시간이다(kubectl 호출마다 --request-timeout=10s,
#       Vault 확인은 응답 대기 최대 8 s에 port-forward 정리(최대 3 s)가 더해진다). 마감 직전의 대기는 마감 1초 전에 끝나 마지막 관측이
#       마감 안에서 시작한다.
# 왜 ①이 필요한가: 시작 시각만 기준으로 폴링하면, 재부팅 명령이 실제로 먹지 않았거나(SSH 세션 문제·종료 지연) 노드가 내려가기 전의
#   몇 초 사이에 ③이 시작됐을 때 API가 아직 살아 있어 reboot-0이 통과하고, 재부팅 "전"의 건강한 상태(Vault unsealed·store Ready·
#   Application Healthy)를 보고 reboot-1..4까지 PASS한다 — 재부팅 없이 PASS가 나온다. status.nodeInfo.bootID는 부팅마다 새로 생기는
#   UUID이므로, ①의 값과 달라진 것을 관측해야만 reboot-0이 충족되고 reboot-1..4는 reboot-0 통과 뒤에만 평가된다. 그래서 -AfterReboot에는
#   -BaselineBootId와 -BaselineNode가 필수이고(없거나 형식이 틀리면 폴링 없이 FAIL reboot-pre-4), -Baseline과 -AfterReboot는 함께 쓸 수 없다.
#   새 bootID만으로는 부족하다: store·ExternalSecret의 status는 재부팅 중에 바뀌지 않을 수 있어(옛 Ready·옛 refreshTime이 그대로 남음)
#   재부팅 전의 낡은 값으로 reboot-2·4가 통과할 수 있다. 그래서 reboot-0은 노드 A Ready=True까지 요구하고, 새 bootID를 처음 본 관측의
#   Ready lastHeartbeatTime(재부팅 뒤 kubelet이 쓴 서버 시각)을 부팅 anchor로 남겨 reboot-4가 그 뒤의 refresh를 요구하게 한다.
#   -BaselineNode는 role=platform 라벨이 다른 노드로 옮겨 가 "다른 노드의 bootID"를 재부팅으로 오인하는 것을 막는다.
# 시험용 손잡이(tests/scripts/reboot-tests.tests.ps1 전용 — 줄이기만 가능, -AfterReboot에서만 읽는다): 환경 변수
#   REBOOT_TESTS_PHASE_DEADLINE_SEC · REBOOT_TESTS_ES_REFRESH_SEC · REBOOT_TESTS_POLL_INTERVAL_SEC. 값이 정수이고 1 ≤ 값 ≤ 기본값
#   (300 · 300 · 10)일 때만 적용하고 'note: <이름>=<값> applied …' 줄을 낸다. 그 밖의 값은 'note: <이름> ignored …' 줄을 내고 기본값을 쓴다.
#   적용된 값은 'polling reboot-0..4 (…)' 줄에 그대로 보인다. 실제 리허설에서는 설정하지 않는다(설정돼 있으면 note 줄로 드러난다).
# Exit 0 = FAIL 0 (PASS/SKIP만), 1 = FAIL ≥ 1 (전제 실패 포함 — fail closed). 외부 프레임워크 없음(tests/infra/tofu.tests.ps1과 같은 구조).
#
# 계약(tasks.md T034 · spec.md US2 AC4 · quickstart.md "재부팅 시나리오"):
#   reboot-pre-4  인자 계약 — -AfterReboot에는 형식이 맞는 -BaselineBootId(8-4-4-4-12 16진 UUID)와 -BaselineNode(DNS-1123 서브도메인,
#             253자 이하)가 필수, -Baseline과 -AfterReboot 동시 사용 금지, -BaselineBootId·-BaselineNode는 -AfterReboot와만,
#             알 수 없는 인자 금지. 위반이면 kubectl을 한 번도 부르지 않고 FAIL + exit 1(폴링 없음). PASS 줄에는 baseline bootID와 node를
#             전부 찍는다(부팅 ID는 비밀이 아니다 — 증거 대조용). 인자를 하나도 주지 않은 평상시 실행에는 이 줄이 없다(출력 불변).
#             사용자 입력을 출력할 때는 가린(<KUBECONFIG>) 뒤 자른다.
#   reboot-baseline  (-Baseline 전용) 위 ①의 조회 판정(노드가 정확히 1개가 아니면 0개 포함 FAIL). 신원 전제(reboot-pre-3)가 실패하면
#             노드를 조회하지 않고 not attempted로 FAIL.
#   reboot-0  API 서버 도달 + 컨텍스트 사용자 = system:serviceaccount:kube-system:agent-view 이고, 라벨 role=platform 노드가 정확히 1개이며
#             그 이름이 -BaselineNode와 같고 status.nodeInfo.bootID가 -BaselineBootId와 다르며(비교는 OrdinalIgnoreCase) Ready 조건
#             status=True이고 부팅 anchor가 정해져 있다(마감 300 s, 시작 기준). 부팅 anchor = 새 bootID를 처음 본 관측(그 관측에 Ready 조건
#             lastHeartbeatTime이 없거나 해석할 수 없으면 다음 관측)의 lastHeartbeatTime(서버 시각, UTC) — Ready 값과 무관하고 한 번 정하면
#             유지한다(새 bootID가 status에 있다 = 그 status를 재부팅 뒤의 kubelet이 썼다 — 워크스테이션 시계는 쓰지 않는다).
#             met·PASS 줄에는 노드 이름과 baseline·새 bootID 전체를 찍는다.
#             재부팅 직후에는 API 서버가 내려가 있으므로 도달 자체를 폴링한다. 도달했는데 다른 신원이면 즉시 FAIL하고 전체를 중단한다.
#             401 Unauthorized(토큰 만료·무효)는 연속 두 번 관측되면 FAIL·전체 중단이다(첫 번째는 미충족 — 'polling …' 진행 줄에
#             "401 (1 of 2 before fatal)"; 사이에 401이 아닌 관측이 끼면 횟수는 처음부터). 둘 다 300 s 재시도는 없다(러너와 같은 fail-closed
#             신원 게이트). 평상시 모드·-Baseline은 한 번의 조회라 401 한 번이면 FAIL이다.
#             bootID가 baseline과 같음(아직 재부팅 전) · Ready≠True(False·Unknown·없음) · 부팅 anchor 미정 · 노드 조회 실패(exit≠0 · JSON 아님) ·
#             노드 0개 · bootID 부재/형식 불일치는 미충족(계속 폴링, 마감까지 그대로면 FAIL). JSON은 정상인데 role=platform 노드가 2개 이상이거나
#             -BaselineNode와 이름이 다르면 더 폴링하지 않고 FAIL(fail closed — 개수/이름 명시).
#   reboot-1  Vault `GET /v1/sys/seal-status` → sealed=false 그리고 type=ocikms (마감 300 s). svc/vault port-forward 경유
#             (agent-view는 vault ns pods/portforward만 있고 exec는 없다 — quickstart 45–46행). 확인 1회마다 빈 로컬 포트를
#             새로 할당해 짧게 띄우고, port-forward stdout의 "Forwarding from 127.0.0.1:<port> ->" 줄을 본 뒤에만 질의하며,
#             응답 뒤 프로세스 생존을 재확인한다(죽어 있으면 타인 리스너의 응답으로 보고 불신). 종료는 프로세스 트리째(Kill(true)).
#   reboot-2  ClusterSecretStore가 정확히 5개(vault-platform·vault-dev·vault-prod·vault-data·k8s-data-ca; FR-049)이고 전부
#             조건 Ready=True (마감 300 s). 이름 집합이 다르면(누락·추가) 미충족. 통과 관측에서 Ready 조건 lastTransitionTime의
#             최대값(서버 시각, UTC)을 store anchor로 기록한다(reboot-4 기준의 한 축). store anchor가 부팅 anchor보다 앞이면(= store Ready가
#             재부팅 중에 전이하지 않았다) PASS detail에 'info: store Ready did not transition after the reboot (…)'를 덧붙인다 — 판정은
#             그대로다(계약은 "5개 Ready"). 그 경우 재부팅 뒤의 증거는 reboot-4가 부팅 anchor로 요구한다.
#   reboot-3  argocd 네임스페이스의 Application 전부 status.health.status=Healthy (마감 300 s; 0개면 미충족 — task 문면은 Healthy만,
#             Synced 여부는 정보로만 출력). API 복귀 직후의 health는 Argo가 다시 평가하기 전의 값일 수 있다 — 재조정 시각
#             (status.reconciledAt)은 리허설 절차의 사후 스냅샷에서 확인한다(여기서 요구하면 재조정 주기 때문에 정상 복구가 마감을 넘길 수 있다).
#   reboot-4  ExternalSecret(전 네임스페이스, 1개 이상) 전부 조건 Ready=True/reason=SecretSynced 이고 status.refreshTime ≥ anchor,
#             anchor = max(store anchor, 부팅 anchor) (= 재부팅 뒤, 그리고 store가 Ready로 돌아온 다음 실제 refresh가 일어났다는 전이 증거 —
#             store가 옛 Ready를 그대로 갖고 있거나 ESO가 아직 돌지 않아 refreshTime이 옛 값이면 통과하지 않는다). detail에
#             'storeAnchor=… bootAnchor=… using=…'를 찍는다. 마감 = reboot-2 통과 시각 + 300 s
#             (refreshInterval 5m 표준 = 다음 refresh; 문면 정본 — Argo 등 다른 조건의 지연으로 늘어나지 않는다). reboot-2 통과
#             직후부터 폴링한다(재부팅 직후 한 번의 조회로 판정하지 않는다). reboot-2가 최종 실패(마감 초과·late)면 not attempted.
#             refreshTime·lastTransitionTime 부재/파싱 불가, store/부팅 anchor 부재는 fail-closed(FAIL).
#
# 접근 경계: $env:KUBECONFIG(agent-view 토큰)로 `kubectl auth whoami`·`kubectl get`·`kubectl port-forward`(vault ns)만 쓴다.
#   클러스터를 바꾸는 동사는 하나도 쓰지 않는다(재부팅 자체는 운영자가 수행 — 이 파일은 관찰만 한다).
#   비밀·자격·개인 경로는 출력하지 않는다: KUBECONFIG 경로가 kubectl 오류 문구에 섞여 나오면 `<KUBECONFIG>`로 치환(ordinal)한다.
# 출력: `PASS|FAIL|SKIP <id>: …` 줄(폴링 진행 줄은 두 칸 들여쓰기), 마지막 줄 `N passed, N failed, N skipped`.
#   시간 계산은 [Diagnostics.Stopwatch]. 비교는 전부 ordinal(CLAUDE.md Known Issues).
param([switch]$AfterReboot, [string]$BaselineBootId, [switch]$Baseline, [string]$BaselineNode)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다

# ---------- 상수(계약 값) ----------
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$expectedStores = @('vault-platform', 'vault-dev', 'vault-prod', 'vault-data', 'k8s-data-ca')
$nodeSelector = 'role=platform'   # 노드 A(K3s server) 라벨 — 정확히 1개여야 한다
# 부팅 ID(UUID 8-4-4-4-12). \z로 끝을 고정한다($는 끝의 개행 앞에서도 맞는다)
$bootIdPattern = '\A[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z'
# 노드 이름(DNS-1123 서브도메인: 소문자 영숫자 · '-' · '.', 라벨마다 영숫자로 시작·끝, 253자 이하)
$nodeNamePattern = '\A[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*\z'
$phaseDeadlineSec = 300        # reboot-0..3 마감(시작 시각 기준)
$esRefreshSec = 300            # ExternalSecret refreshInterval 5m 표준 — reboot-4 마감 = reboot-2 통과 시각 + 이 값
$pollIntervalSec = 10          # 명목 폴링 간격(라운드 길이만큼 늘어남)
$kubectlTimeout = '--request-timeout=10s'
$pfReadyWaitSec = 8            # port-forward 확인 1회당 상한(Forwarding 줄 대기 + 응답 대기)
$pfPostResponseWaitMs = 500    # 응답 뒤 port-forward 생존 재확인 유예

$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:pf = $null             # 살아 있는 port-forward 프로세스(스크립트 종료 시 반드시 정리)
$script:pfFiles = @()          # 그 리디렉션 파일
$script:redact = @()           # 출력에서 <KUBECONFIG>로 치환할 문자열들
$script:storeAnchor = $null    # reboot-2 통과 관측의 Ready lastTransitionTime 최대값(UTC DateTime)
$script:storeAnchorReason = 'reboot-2 has not passed yet'
$script:bootAnchor = $null     # reboot-0 통과 관측의 노드 A Ready lastHeartbeatTime(UTC DateTime) — 재부팅 뒤 kubelet이 쓴 서버 시각
$script:unauthStreak = 0       # -AfterReboot reboot-0 폴링에서 연속으로 관측한 401 횟수(2회째에 fatal)
$script:baselineNodeGiven = $false   # -BaselineNode가 명시됐는지(본체에서 $PSBoundParameters로 정한다)
$script:sw = [Diagnostics.Stopwatch]::StartNew()

function Now { return [double]$script:sw.Elapsed.TotalSeconds }
function Sec([double]$t) { return [int][Math]::Round($t) }
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Redact([string]$s) {
    if ($null -eq $s) { return '' }
    foreach ($x in $script:redact) { if (-not [string]::IsNullOrEmpty($x)) { $s = $s.Replace($x, '<KUBECONFIG>', [StringComparison]::Ordinal) } }
    return $s
}
function Assert([string]$id, [string]$label, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS ${id}: $label -- $(Redact $detail)" }
    else { $script:fail++; Write-Host "FAIL ${id}: $label -- $(Redact $detail)" }
}
function Skip([string]$id, [string]$label) {
    $script:skip++
    Write-Host "SKIP ${id}: manual trigger only (-AfterReboot) -- $label"
}
function Finish {
    Write-Host ''
    Write-Host "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
    if ($script:fail -gt 0) { exit 1 } else { exit 0 }
}
function Clip([string]$s, [int]$max = 300) {
    $t = ((Redact "$s") -replace '\s+', ' ').Trim()   # 자르기 전에 마스킹 — 잘린 경로 조각이 치환을 비껴가지 않게
    if ($t.Length -le $max) { return $t }
    return $t.Substring(0, $max) + '...'   # ASCII만 — CP949 콘솔에서 U+2026이 깨지지 않게
}
# 중첩 해시테이블을 안전하게 걷는다(중간에 없으면 $null). ConvertFrom-Json -AsHashtable 결과 전용.
function Get-Path($o, [string[]]$keys) {
    foreach ($k in $keys) {
        if ($null -eq $o -or -not ($o -is [System.Collections.IDictionary])) { return $null }
        $o = $o[$k]
    }
    return $o
}
function Get-ReadyCondition($item) {
    $conds = @(Get-Path $item @('status', 'conditions'))
    foreach ($c in $conds) {
        if ($c -is [System.Collections.IDictionary] -and (Eq "$($c['type'])" 'Ready')) { return $c }
    }
    return $null
}
function Sort-Ordinal([string[]]$a) {
    $arr = @($a | ForEach-Object { "$_" })
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return $arr
}
# RFC 3339(서버 시각) → UTC DateTime; 부재·파싱 불가면 $null
function Parse-Utc([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $d = [DateTimeOffset]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    if ([DateTimeOffset]::TryParse($s, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$d)) { return $d.UtcDateTime }
    return $null
}
function Fmt-Utc([DateTime]$d) { return $d.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture) }
# 자식이 아직 쓰고 있는 리디렉션 파일을 읽는다(FileShare.ReadWrite — ReadAllText는 공유 위반으로 실패한다)
function Read-SharedText([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    try {
        $fs = [IO.FileStream]::new($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try { $sr = [IO.StreamReader]::new($fs, [Text.Encoding]::UTF8); return $sr.ReadToEnd() } finally { $fs.Dispose() }
    } catch { return '' }
}
function Remove-TempFiles([string[]]$paths) {
    for ($i = 1; $i -le 3; $i++) {
        $left = @()
        foreach ($p in $paths) {
            if ([string]::IsNullOrEmpty($p)) { continue }
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $p) { $left += $p }
        }
        if ($left.Count -eq 0) { return }
        Start-Sleep -Milliseconds 300
    }
}
# port-forward 프로세스를 트리째 종료한다(cmd/래퍼가 끼어도 손자까지)
function Stop-Tree($p) {
    if ($null -eq $p) { return }
    try { if (-not $p.HasExited) { $p.Kill($true) } } catch { }
    try { $null = $p.WaitForExit(3000) } catch { }
}
function Get-FreeLocalPort {
    $l = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $l.Start(); $port = $l.LocalEndpoint.Port; $l.Stop(); return $port
}
# 사람이 넘긴 값을 출력용으로: 먼저 가리고(Redact — 잘린 경로 조각이 치환을 비껴가지 않게) 인쇄 가능한 ASCII 밖의 문자는 '?'로,
#   그다음 길이 제한(Clip과 달리 공백을 접거나 다듬지 않는다 — 앞뒤 공백이 보여야 한다)
function Show-Arg([string]$s, [int]$max = 60) {
    $sb = [Text.StringBuilder]::new()
    foreach ($ch in (Redact "$s").ToCharArray()) { if ([int]$ch -ge 0x20 -and [int]$ch -le 0x7E) { [void]$sb.Append($ch) } else { [void]$sb.Append('?') } }
    $t = $sb.ToString()
    if ($t.Length -gt $max) { $t = $t.Substring(0, $max) + '...' }
    return $t
}
function Test-BootIdFormat($s) { return (($s -is [string]) -and [regex]::IsMatch($s, $bootIdPattern)) }
function Test-NodeNameFormat($s) { return (($s -is [string]) -and $s.Length -le 253 -and [regex]::IsMatch($s, $nodeNamePattern)) }
# 시험용 손잡이: 정수이고 1 ≤ 값 ≤ 기본값일 때만 적용(줄이기만 가능). 미설정이면 조용히 기본값, 그 밖의 값은 무시 줄 + 기본값.
function Get-TestKnob([string]$name, [int]$default) {
    $raw = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrEmpty($raw)) { return $default }
    $v = 0
    if ([int]::TryParse($raw, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$v) -and $v -ge 1 -and $v -le $default) {
        Write-Host "note: $name=$v applied (test override, shorten-only; default $default)"
        return $v
    }
    Write-Host "note: $name ignored (must be an integer 1..$default; using default $default)"
    return $default
}
# 인자 계약(reboot-pre-4) — kubectl을 부르기 전에 판정한다. 문제가 없으면 $null, 있으면 사유.
#   $extra = 스크립트의 $args(매개변수에 묶이지 않은 인자 — 오타 스위치 등), $idGiven/$nodeGiven = -BaselineBootId/-BaselineNode가 명시됐는지
function Get-ArgumentProblem([object[]]$extra, [bool]$idGiven, [bool]$nodeGiven) {
    $how = "run 'pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -Baseline' BEFORE rebooting node A, then '-AfterReboot -BaselineBootId <that bootID> -BaselineNode <that node>' after the reboot"
    if (@($extra).Count -gt 0) { return "unexpected argument(s) [$(Show-Arg (@($extra) -join ' ') 120)]; known: -Baseline | -AfterReboot -BaselineBootId <bootID> -BaselineNode <node>; refusing to guess the mode (fail closed, no polling)" }
    if ($Baseline -and $AfterReboot) { return "-Baseline and -AfterReboot are mutually exclusive: $how (no polling)" }
    if ($AfterReboot) {
        if (-not $idGiven -or [string]::IsNullOrEmpty($BaselineBootId)) { return "-AfterReboot requires -BaselineBootId: $how. Without it a cluster that never rebooted would pass (no polling)" }
        if (-not (Test-BootIdFormat $BaselineBootId)) { return "-BaselineBootId '$(Show-Arg $BaselineBootId)' is not a boot ID (expected the 8-4-4-4-12 hex UUID printed by -Baseline); $how (no polling)" }
        if (-not $nodeGiven -or [string]::IsNullOrEmpty($BaselineNode)) { return "-AfterReboot requires -BaselineNode: $how. Without it a role=platform label that moved to another node would look like a reboot (no polling)" }
        if (-not (Test-NodeNameFormat $BaselineNode)) { return "-BaselineNode '$(Show-Arg $BaselineNode)' is not a node name (DNS-1123 subdomain: lowercase a-z 0-9 '-' '.', at most 253 chars, as printed by -Baseline) (no polling)" }
        return $null
    }
    if ($idGiven) { return "-BaselineBootId is only used with -AfterReboot (given without it): $how (no polling)" }
    if ($nodeGiven) { return "-BaselineNode is only used with -AfterReboot (given without it): $how (no polling)" }
    return $null
}

# kubectl 실행(읽기 전용 동사만 넘긴다). stderr는 임시 파일로 받아 detail에 쓴다(러너와 같은 방식).
function Invoke-Kubectl([string[]]$kubectlArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('reboot-kubectl-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        $lines = & kubectl @kubectlArgs 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { ([IO.File]::ReadAllText($errFile)).Trim() } else { '' }
    } finally {
        Remove-TempFiles @($errFile)
    }
    return @{ code = $code; out = (@($lines | ForEach-Object { "$_" }) -join "`n"); err = $err; cmd = "kubectl $($kubectlArgs -join ' ')" }
}
# `kubectl get … -o json` → @{ ok; items(널 제거된 배열); reason } — items 부재는 별도 reason(fail closed)
function Get-KubeItems([string[]]$kubectlArgs) {
    $r = Invoke-Kubectl $kubectlArgs
    if ($r.code -ne 0) { return @{ ok = $false; items = @(); reason = "$($r.cmd) exit=$($r.code): $(Clip $r.err)" } }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return @{ ok = $false; items = @(); reason = "$($r.cmd) produced no output" } }
    try { $obj = $r.out | ConvertFrom-Json -AsHashtable } catch { return @{ ok = $false; items = @(); reason = "$($r.cmd) output is not JSON: $(Clip $_.Exception.Message)" } }
    if ($null -eq $obj -or -not ($obj -is [System.Collections.IDictionary])) { return @{ ok = $false; items = @(); reason = "$($r.cmd) JSON root is not an object" } }
    if (-not $obj.ContainsKey('items') -or $null -eq $obj['items']) { return @{ ok = $false; items = @(); reason = "$($r.cmd) JSON has no 'items' list" } }
    $items = @($obj['items'] | Where-Object { $null -ne $_ })
    return @{ ok = $true; items = $items; reason = '' }
}

# ---------- 조건 함수: 각각 @{ ok; detail; fatal; final } 를 돌려준다 ----------
#   fatal = 더 기다려도 소용없는 거부(전체 중단), final = 이 조건만 더 폴링하지 않고 FAIL 확정
function Test-Identity {
    $r = Invoke-Kubectl @('auth', 'whoami', '-o', 'json', $kubectlTimeout)
    if ($r.code -ne 0) {
        if ($r.err.IndexOf('Unauthorized', [StringComparison]::Ordinal) -ge 0) {
            # unauthorized/cmd/err: -AfterReboot의 reboot-0이 "연속 두 번"을 판정하는 데 쓴다(평상시·-Baseline은 이 fatal을 그대로 쓴다)
            return @{ ok = $false; fatal = $true; final = $false; unauthorized = $true; cmd = $r.cmd; err = $r.err; detail = "$($r.cmd): 401 Unauthorized -- the agent-view token is expired or invalid; refusing to retry for ${phaseDeadlineSec}s (fail closed): $(Clip $r.err)" }
        }
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($r.cmd) exit=$($r.code): $(Clip $r.err)" }
    }
    $u = $null
    try {
        $j = $r.out | ConvertFrom-Json -AsHashtable
        $u = [string](Get-Path $j @('status', 'userInfo', 'username'))
    } catch { $u = $null }
    if ([string]::IsNullOrWhiteSpace($u)) { return @{ ok = $false; fatal = $false; final = $false; detail = "could not parse '$($r.cmd)' output" } }
    if (-not (Eq $u $expectedUser)) {
        return @{ ok = $false; fatal = $true; final = $false; detail = "context user is '$u', expected '$expectedUser'; refusing to run with non-agent-view credentials (fail closed)" }
    }
    return @{ ok = $true; fatal = $false; final = $false; detail = "context user $u" }
}

# 노드 A(라벨 role=platform) 한 번 조회 → @{ ok; final; detail; rawName; name; bootID; ready; heartbeat }
#   ok=$false·final=$false: 조회 실패(exit≠0·출력 없음·JSON 아님·items 없음) 또는 노드 0개 — 재부팅 중에는 API가 내려가 있거나
#                           목록이 잠깐 비어 있을 수 있으므로 계속 폴링한다(-Baseline은 한 번의 조회라 그대로 FAIL)
#   ok=$false·final=$true : JSON은 정상인데 노드가 2개 이상 — 어느 노드를 볼지 추측하지 않는다(fail closed)
function Get-PlatformNode {
    $r = Get-KubeItems @('get', 'nodes', '-l', $nodeSelector, '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    if ($items.Count -eq 0) {
        return @{ ok = $false; final = $false; detail = "$nodeSelector nodes: 0 [] -- expected exactly 1 (node A); not met (the list may be briefly empty while the API server restarts)" }
    }
    if ($items.Count -gt 1) {
        $names = @($items | ForEach-Object { "$(Get-Path $_ @('metadata', 'name'))" })
        return @{ ok = $false; final = $true; detail = "$nodeSelector nodes: $($items.Count) [$((Sort-Ordinal $names) -join ', ')] -- expected exactly 1 (node A); refusing to guess which node to watch (fail closed)" }
    }
    $node = $items[0]
    $raw = "$(Get-Path $node @('metadata', 'name'))"
    $boot = Get-Path $node @('status', 'nodeInfo', 'bootID')
    $c = Get-ReadyCondition $node
    return @{
        ok        = $true; final = $false; detail = ''
        rawName   = $raw
        name      = (Show-Arg $raw 253)
        bootID    = $(if ($boot -is [string]) { $boot } else { $null })
        ready     = $(if ($null -ne $c) { Show-Arg "$($c['status'])" 20 } else { 'none' })
        heartbeat = $(if ($null -ne $c) { Parse-Utc "$($c['lastHeartbeatTime'])" } else { $null })
    }
}

# reboot-0: 신원 그리고 노드 A가 재부팅 뒤의 kubelet으로 Ready다(= 재부팅이 실제로 일어났고 노드가 돌아왔다).
#   신원: 다른 신원 = 즉시 fatal. 401 = 연속 두 번째 관측에서 fatal(첫 번째는 미충족 — API 서버가 막 올라오는 중일 수 있다).
#         도달 실패 = 미충족. 401이 아닌 관측이 끼면 연속 횟수는 0으로 돌아간다.
#   노드: 이름이 -BaselineNode와 같아야 한다(다르면 final — 라벨이 다른 노드로 옮겨 갔다) · bootID 형식 · baseline과 다름 ·
#         Ready 조건 status=True · 부팅 anchor가 정해져 있음(새 bootID를 처음 본 관측의 Ready lastHeartbeatTime — reboot-4가 쓴다).
#         하나라도 아니면 미충족.
function Test-Rebooted {
    $id = Test-Identity
    if ($id.unauthorized) {
        $script:unauthStreak++
        if ($script:unauthStreak -lt 2) {
            return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.cmd): 401 (1 of 2 before fatal) Unauthorized -- retrying once in case the API server is still coming up: $(Clip $id.err)" }
        }
        return @{ ok = $false; fatal = $true; final = $false; detail = "$($id.cmd): 401 (2 of 2) Unauthorized on two consecutive observations -- the agent-view token is expired or invalid; refusing to retry for ${phaseDeadlineSec}s (fail closed): $(Clip $id.err)" }
    }
    $script:unauthStreak = 0
    if (-not $id.ok) { return $id }   # 다른 신원 = fatal(전체 중단), 도달 실패·해석 불가 = 미충족(계속 폴링)
    $n = Get-PlatformNode
    if (-not $n.ok) { return @{ ok = $false; fatal = $false; final = [bool]$n.final; detail = "$($id.detail); $($n.detail)" } }
    if ($script:baselineNodeGiven -and -not (Eq $n.rawName $BaselineNode)) {
        return @{ ok = $false; fatal = $false; final = $true; detail = "$($id.detail); the $nodeSelector node is '$($n.name)', not -BaselineNode '$(Show-Arg $BaselineNode)' -- the label moved to another node; refusing to treat a different node's boot ID as a reboot (fail closed)" }
    }
    if (-not (Test-BootIdFormat $n.bootID)) {
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node $($n.name) status.nodeInfo.bootID missing or not a boot ID ('$(Show-Arg "$($n.bootID)")') -- not met" }
    }
    if ([string]::Equals($n.bootID, $BaselineBootId, [StringComparison]::OrdinalIgnoreCase)) {
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node A has not rebooted yet (bootID unchanged): node $($n.name) bootID $($n.bootID)" }
    }
    $change = "node $($n.name) bootID $BaselineBootId -> $($n.bootID)"
    # 부팅 anchor(F2): 새 bootID를 처음 본 관측(heartbeat가 있는 첫 관측)의 Ready lastHeartbeatTime — Ready 값과 무관하고 한 번 정하면 유지한다.
    #   새 bootID가 status에 있다 = 그 status를 재부팅 뒤의 kubelet이 썼다. anchor가 이를수록 "부팅 뒤·anchor 앞"에 끼는 정상 refresh가 줄어든다.
    if ($null -eq $script:bootAnchor -and $null -ne $n.heartbeat) { $script:bootAnchor = [DateTime]$n.heartbeat }
    $anchorNote = if ($null -ne $script:bootAnchor) { "bootAnchor=$(Fmt-Utc $script:bootAnchor)" } else { 'no boot anchor yet' }
    # 미충족 사유를 앞에 둔다(진행 줄은 120자로 잘린다 — 긴 bootID 두 개 뒤로 가면 사유가 잘린다)
    if (-not (Eq $n.ready 'True')) {
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node A ready=$($n.ready), not Ready=True yet -- not met: $change; $anchorNote" }
    }
    if ($null -eq $script:bootAnchor) {
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node A Ready lastHeartbeatTime missing/unparseable, no boot anchor yet -- not met (fail closed): $change; ready=True" }
    }
    return @{ ok = $true; fatal = $false; final = $false; detail = "$($id.detail); $change; ready=True bootAnchor=$(Fmt-Utc $script:bootAnchor) (Ready lastHeartbeatTime of the first observation with the new bootID, server time)" }
}

function Test-Vault {
    $kubectlExe = (Get-Command kubectl).Source
    $port = Get-FreeLocalPort
    $tmp = [IO.Path]::GetTempPath()
    $tag = [guid]::NewGuid().ToString('N')
    $outFile = Join-Path $tmp "reboot-pf-$tag.out.txt"
    $errFile = Join-Path $tmp "reboot-pf-$tag.err.txt"
    $marker = "Forwarding from 127.0.0.1:$port ->"
    $p = $null
    try {
        $pfArgs = @('-n', 'vault', 'port-forward', 'svc/vault', "${port}:8200", '--address', '127.0.0.1')
        try {
            $p = Start-Process -FilePath $kubectlExe -ArgumentList $pfArgs -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        } catch {
            return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward start failed: $(Clip $_.Exception.Message)" }
        }
        $script:pf = $p
        $script:pfFiles = @($outFile, $errFile)
        $until = [DateTime]::UtcNow.AddSeconds($pfReadyWaitSec)
        $lastErr = 'no attempt yet'
        $forwarding = $false
        while ([DateTime]::UtcNow -lt $until) {
            if ($p.HasExited) {
                return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward exited (exit=$($p.ExitCode)): $(Clip (Read-SharedText $errFile))" }
            }
            if (-not $forwarding) {
                if ((Read-SharedText $outFile).IndexOf($marker, [StringComparison]::Ordinal) -ge 0) { $forwarding = $true }
                else { $lastErr = "waiting for '$marker' on port-forward stdout"; Start-Sleep -Milliseconds 500; continue }
            }
            try {
                $j = Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/sys/seal-status" -Method Get -TimeoutSec 5 -NoProxy
            } catch {
                $lastErr = $_.Exception.Message
                Start-Sleep -Seconds 1
                continue
            }
            # 응답 뒤 생존 재확인: 그 사이 죽었으면 응답은 우리 port-forward가 아니라 그 포트의 다른 리스너에서 온 것일 수 있다
            $null = $p.WaitForExit($pfPostResponseWaitMs)
            if ($p.HasExited) {
                return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward exited right after responding (exit=$($p.ExitCode)); response on local port $port not trusted (foreign listener?): $(Clip (Read-SharedText $errFile))" }
            }
            $sealed = $j.sealed
            $type = "$($j.type)"
            $ok = ($sealed -is [bool]) -and (-not $sealed) -and (Eq $type 'ocikms')
            return @{ ok = $ok; fatal = $false; final = $false; detail = "sealed=$sealed type=$type initialized=$($j.initialized) (local port $port)" }
        }
        return @{ ok = $false; fatal = $false; final = $false; detail = "seal-status not answered within ${pfReadyWaitSec}s via port-forward (local port $port): $(Clip $lastErr)" }
    } finally {
        Stop-Tree $p
        $script:pf = $null
        $script:pfFiles = @()
        Remove-TempFiles @($outFile, $errFile)
    }
}

function Test-Stores {
    $r = Get-KubeItems @('get', 'clustersecretstores.external-secrets.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $names = @()
    $ready = @()
    $notReady = @()
    $noLtt = @()
    $anchor = $null
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $names += $n
        $c = Get-ReadyCondition $it
        if ($null -ne $c -and (Eq "$($c['status'])" 'True')) {
            $ready += $n
            $ltt = Parse-Utc "$($c['lastTransitionTime'])"
            if ($null -eq $ltt) { $noLtt += $n } elseif ($null -eq $anchor -or $ltt -gt $anchor) { $anchor = $ltt }
        } else {
            $notReady += "$n(status=$(if ($null -ne $c) { "$($c['status'])" } else { 'none' }) reason=$(if ($null -ne $c) { "$($c['reason'])" } else { '-' }))"
        }
    }
    $missing = @($expectedStores | Where-Object { $e = $_; -not ($names | Where-Object { Eq $_ $e }) })
    $extra = @($names | Where-Object { $n = $_; -not ($expectedStores | Where-Object { Eq $_ $n }) })
    $ok = ($items.Count -eq $expectedStores.Count -and $missing.Count -eq 0 -and $extra.Count -eq 0 -and $notReady.Count -eq 0)
    $detail = "ready $($ready.Count)/$($expectedStores.Count) [$((Sort-Ordinal $ready) -join ', ')]"
    if ($notReady.Count -gt 0) { $detail += " notReady [$((Sort-Ordinal $notReady) -join ', ')]" }
    if ($missing.Count -gt 0) { $detail += " missing [$((Sort-Ordinal $missing) -join ', ')]" }
    if ($extra.Count -gt 0) { $detail += " unexpected [$((Sort-Ordinal $extra) -join ', ')]" }
    if ($ok) {
        if ($noLtt.Count -gt 0) {
            $script:storeAnchor = $null
            $script:storeAnchorReason = "Ready condition lastTransitionTime missing/unparseable for [$((Sort-Ordinal $noLtt) -join ', ')]"
            $detail += " readyAnchor=unavailable ($($script:storeAnchorReason))"
        } else {
            $script:storeAnchor = $anchor
            $script:storeAnchorReason = ''
            $detail += " readyAnchor=$(Fmt-Utc $anchor) (max Ready lastTransitionTime, server time)"
            # 정보만(판정 불변 — reboot-2의 계약은 "5개 Ready"): store Ready가 재부팅 중에 전이하지 않았으면 reboot-4는 부팅 anchor를 쓴다
            if ($null -ne $script:bootAnchor -and $anchor -lt [DateTime]$script:bootAnchor) {
                $detail += " info: store Ready did not transition after the reboot (readyAnchor $(Fmt-Utc $anchor) < bootAnchor $(Fmt-Utc $script:bootAnchor))"
            }
        }
    }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

function Test-Argo {
    $r = Get-KubeItems @('-n', 'argocd', 'get', 'applications.argoproj.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $unhealthy = @()
    $outOfSync = @()
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $h = "$(Get-Path $it @('status', 'health', 'status'))"
        $s = "$(Get-Path $it @('status', 'sync', 'status'))"
        if (-not (Eq $h 'Healthy')) { $unhealthy += "$n=$(if ($h) { $h } else { 'none' })" }
        if (-not (Eq $s 'Synced')) { $outOfSync += "$n=$(if ($s) { $s } else { 'none' })" }
    }
    $ok = ($items.Count -ge 1 -and $unhealthy.Count -eq 0)
    $detail = "applications $($items.Count), healthy $($items.Count - $unhealthy.Count)"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($unhealthy.Count -gt 0) { $detail += " notHealthy [$((Sort-Ordinal $unhealthy) -join ', ')]" }
    if ($outOfSync.Count -gt 0) { $detail += " info: notSynced [$((Sort-Ordinal $outOfSync) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

function Test-ExternalSecrets {
    if ($null -eq $script:storeAnchor) {
        return @{ ok = $false; fatal = $false; final = $true; detail = "store Ready anchor unavailable ($($script:storeAnchorReason)); cannot prove a post-reboot refresh (fail closed)" }
    }
    if ($null -eq $script:bootAnchor) {
        return @{ ok = $false; fatal = $false; final = $true; detail = 'boot anchor unavailable (reboot-0 did not record node A Ready lastHeartbeatTime); cannot prove a post-reboot refresh (fail closed)' }
    }
    # anchor = max(store anchor, 부팅 anchor): store Ready가 재부팅 중에 전이하지 않았어도(옛 Ready가 남음) 재부팅 뒤의 refresh를 요구한다
    $storeA = [DateTime]$script:storeAnchor
    $bootA = [DateTime]$script:bootAnchor
    if ($bootA -gt $storeA) { $anchor = $bootA; $using = 'bootAnchor' } else { $anchor = $storeA; $using = 'storeAnchor' }
    $anchors = "storeAnchor=$(Fmt-Utc $storeA) bootAnchor=$(Fmt-Utc $bootA) using=$using"
    $r = Get-KubeItems @('get', 'externalsecrets.external-secrets.io', '-A', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $notSynced = @()
    $noRefresh = @()
    $stale = @()
    $fresh = 0
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'namespace'))/$(Get-Path $it @('metadata', 'name'))"
        $c = Get-ReadyCondition $it
        $synced = ($null -ne $c -and (Eq "$($c['status'])" 'True') -and (Eq "$($c['reason'])" 'SecretSynced'))
        if (-not $synced) { $notSynced += "$n=$(if ($null -ne $c) { "$($c['reason'])/$($c['status'])" } else { 'none' })"; continue }
        $rt = Parse-Utc "$(Get-Path $it @('status', 'refreshTime'))"
        if ($null -eq $rt) { $noRefresh += $n }
        elseif ($rt -lt $anchor) { $stale += "$n=refreshTime $(Fmt-Utc $rt)" }
        else { $fresh++ }
    }
    $ok = ($items.Count -ge 1 -and $notSynced.Count -eq 0 -and $noRefresh.Count -eq 0 -and $stale.Count -eq 0)
    $detail = "externalsecrets $($items.Count), SecretSynced $($items.Count - $notSynced.Count), refreshed since anchor $(Fmt-Utc $anchor): $fresh ($anchors)"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($notSynced.Count -gt 0) { $detail += " notSynced [$((Sort-Ordinal $notSynced) -join ', ')]" }
    if ($noRefresh.Count -gt 0) { $detail += " refreshTime missing/unparseable [$((Sort-Ordinal $noRefresh) -join ', ')]" }
    if ($stale.Count -gt 0) { $detail += " refreshTime before anchor [$((Sort-Ordinal $stale) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

# ---------- 폴링 엔진(조건별 마감) ----------
# $conds 원소: @{ id; label; test=[scriptblock] → @{ok; detail; fatal; final}; after=<선행 id 또는 $null>; deadline=[scriptblock]($state) → 초 }
# 반환: id → @{ verdict; at(관측이 끝난 시각); startedAt(그 관측을 시작한 시각); deadline; detail; checks }
#   verdict: pending | ok | late(마감 뒤에 시작한 관측의 충족) | expired(마감까지 미충족) | final(재폴링 무의미한 FAIL) | fatal | not-attempted
#   마감 판정(F1): 충족은 관측을 "시작한" 시각으로, 미충족은 관측이 "끝난" 시각으로 본다 — 마감 안에 시작한 관측이 충족이면 통과다
#   (kubectl 호출이 끝나는 시각으로 보면 마감에 맞춰 줄인 마지막 관측은 늘 마감 뒤에 끝나 정상 복구가 late가 된다).
function Invoke-PollLoop([object[]]$conds) {
    $state = @{}
    foreach ($c in $conds) { $state[$c.id] = @{ verdict = 'pending'; at = $null; startedAt = $null; deadline = $null; detail = 'not checked'; checks = 0 } }
    while ($true) {
        foreach ($c in $conds) {
            $s = $state[$c.id]
            if (-not (Eq $s.verdict 'pending')) { continue }
            if ($null -ne $c.after) {
                $a = $state[$c.after]
                if (Eq $a.verdict 'pending') { continue }                                   # 선행 조건 대기(마감도 아직 미정)
                if (-not (Eq $a.verdict 'ok')) { $s.verdict = 'not-attempted'; $s.detail = "$($c.after) $($a.verdict)"; continue }
            }
            if ($null -eq $s.deadline) { $s.deadline = [double](& $c.deadline $state) }
            $t0 = Now                                                                         # 관측 시작 시각(충족의 마감 판정 기준)
            $r = & $c.test
            $t = Now                                                                          # 관측이 끝난 시각(기록·미충족의 마감 판정 기준)
            $s.checks++
            $s.detail = [string]$r.detail
            if ($r.fatal) { $s.verdict = 'fatal'; $s.at = $t; return $state }
            if ($r.ok) {
                $s.at = $t
                $s.startedAt = $t0
                if ($t0 -le $s.deadline) { $s.verdict = 'ok'; Write-Host "  [$(Sec $t)s] $($c.id) met -- $(Redact (Clip $r.detail 200))" }
                else { $s.verdict = 'late'; Write-Host "  [$(Sec $t)s] $($c.id) observed met by an observation that started AFTER its deadline ($(Sec $t0)s > $(Sec $s.deadline)s) -- $(Redact (Clip $r.detail 200))" }
            } elseif ($r.final) { $s.verdict = 'final'; $s.at = $t }
            elseif ($t -gt $s.deadline) { $s.verdict = 'expired'; $s.at = $t }
        }
        $pending = @($conds | Where-Object { Eq $state[$_.id].verdict 'pending' })
        if ($pending.Count -eq 0) { return $state }
        $now = Now
        $nextDeadline = $null
        $parts = @()
        foreach ($c in $pending) {
            $s = $state[$c.id]
            if ($null -eq $s.deadline) { $parts += "$($c.id)(blocked by $($c.after))"; continue }
            if ($null -eq $nextDeadline -or $s.deadline -lt $nextDeadline) { $nextDeadline = $s.deadline }
            $parts += "$($c.id)(deadline $(Sec $s.deadline)s: $(Redact (Clip $s.detail 120)))"
        }
        Write-Host "  [$(Sec $now)s] waiting: $($parts -join '; ')"
        $sleep = [double]$pollIntervalSec
        # 마감 직전의 대기는 마감 1초 전에 끝낸다(마지막 관측이 마감 안에서 시작하게). 1초도 안 남았으면 자지 않고 바로 관측한다.
        if ($null -ne $nextDeadline) { $sleep = [Math]::Min($sleep, [Math]::Max(0.0, $nextDeadline - $now - 1.0)) }
        if ($sleep -gt 0) { Start-Sleep -Milliseconds ([int][Math]::Ceiling($sleep * 1000)) }
    }
}

# ---------- 본체 ----------
try {
    $mode = 'normal (runner path; reboot-1..4 skipped)'
    if ($Baseline -and $AfterReboot) { $mode = 'invalid (-Baseline with -AfterReboot)' }
    elseif ($Baseline) { $mode = 'baseline (record node A bootID before the reboot; read-only, no polling)' }
    elseif ($AfterReboot) { $mode = 'after-reboot (manual trigger)' }
    Write-Host "reboot.tests.ps1: mode=$mode start=$([DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz'))"

    # 전제(항상, fail-closed): kubectl · KUBECONFIG(단일 파일 경로; 상대 경로는 PSPath로 해석 — CLAUDE.md Known Issues)
    $hasKubectl = $null -ne (Get-Command kubectl -ErrorAction SilentlyContinue)
    Assert 'reboot-pre-1' 'kubectl on PATH' $hasKubectl $(if ($hasKubectl) { 'found' } else { 'kubectl not found on PATH; cannot observe the cluster (fail closed)' })
    $kubeconfigOk = $false
    $kubeconfigWhy = 'found'
    if ([string]::IsNullOrWhiteSpace($env:KUBECONFIG)) { $kubeconfigWhy = 'KUBECONFIG is not set; an agent-view kubeconfig is required (fail closed)' }
    else {
        $kubeconfigPath = $null
        try { $kubeconfigPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:KUBECONFIG) } catch { $kubeconfigPath = $null }
        if ($kubeconfigPath -and (Test-Path -LiteralPath $kubeconfigPath -PathType Leaf)) { $kubeconfigOk = $true }
        else { $kubeconfigWhy = 'KUBECONFIG file not found (path not printed; single file path only)' }
        # 출력 마스킹 대상: 원문·해석 경로와 슬래시 방향 변형
        foreach ($v in @($env:KUBECONFIG, $kubeconfigPath)) {
            if ([string]::IsNullOrWhiteSpace($v)) { continue }
            $script:redact += $v
            $script:redact += $v.Replace('\', '/')
            $script:redact += $v.Replace('/', '\')
        }
    }
    Assert 'reboot-pre-2' 'KUBECONFIG set and file exists' $kubeconfigOk $kubeconfigWhy
    # reboot-pre-4: 인자 계약 — kubectl을 한 번도 부르기 전에 판정한다. 인자 없는 평상시 실행에는 이 줄을 내지 않는다(출력 불변).
    $script:baselineNodeGiven = $PSBoundParameters.ContainsKey('BaselineNode')
    $argProblem = Get-ArgumentProblem $args $PSBoundParameters.ContainsKey('BaselineBootId') $script:baselineNodeGiven
    if ($AfterReboot -or $null -ne $argProblem) {
        $argDetail = $argProblem
        if ($null -eq $argProblem) {
            $argDetail = "baseline bootID $BaselineBootId; node A must report a different one"
            if ($script:baselineNodeGiven) { $argDetail += "; baseline node $BaselineNode (the $nodeSelector node must be this one)" }
        }
        Assert 'reboot-pre-4' 'arguments (-Baseline | -AfterReboot -BaselineBootId <bootID> -BaselineNode <node>, both recorded by -Baseline)' ($null -eq $argProblem) $argDetail
    }
    if ($script:fail -gt 0) { Finish }

    if ($Baseline) {
        # ① 재부팅 전 기준값: 신원 1회 + 노드 A 1회 조회(폴링 없음). 성공 시 'baseline: …' 한 줄.
        $blLabel = "node A ($nodeSelector) bootID recorded"
        $idr = Test-Identity
        Assert 'reboot-pre-3' "context user is $expectedUser" ([bool]$idr.ok) $idr.detail
        if (-not $idr.ok) { Assert 'reboot-baseline' $blLabel $false 'not attempted (reboot-pre-3 failed; the identity precondition is fail closed)'; Finish }
        $n = Get-PlatformNode
        if (-not $n.ok) { Assert 'reboot-baseline' $blLabel $false $n.detail; Finish }
        if (-not (Test-BootIdFormat $n.bootID)) { Assert 'reboot-baseline' $blLabel $false "node $($n.name) status.nodeInfo.bootID missing or not a boot ID ('$(Show-Arg "$($n.bootID)")')"; Finish }
        Write-Host "baseline: node=$($n.name) bootID=$($n.bootID) ready=$($n.ready)"
        Finish
    }

    if ($AfterReboot) {
        # 시험용 손잡이(줄이기만 가능) — 적용·무시 모두 note 줄로 드러나고, 적용 값은 아래 polling 줄과 라벨에 그대로 보인다
        $phaseDeadlineSec = Get-TestKnob 'REBOOT_TESTS_PHASE_DEADLINE_SEC' $phaseDeadlineSec
        $esRefreshSec = Get-TestKnob 'REBOOT_TESTS_ES_REFRESH_SEC' $esRefreshSec
        $pollIntervalSec = Get-TestKnob 'REBOOT_TESTS_POLL_INTERVAL_SEC' $pollIntervalSec
    }

    $fixed = { param($st) $phaseDeadlineSec }
    # reboot-4 라벨: 평상시 SKIP 줄은 그대로(출력 불변), -AfterReboot에서는 실제 기준(max(store, 부팅 anchor))을 적는다
    $r4Label = "externalsecrets all SecretSynced with refreshTime >= store Ready anchor, within ${esRefreshSec}s after reboot-2"
    if ($AfterReboot) { $r4Label = "externalsecrets all SecretSynced with refreshTime >= max(store Ready anchor, boot anchor), within ${esRefreshSec}s after reboot-2" }
    $conds = @(
        @{ id = 'reboot-0'; label = "API reachable, context user is $expectedUser, node A ($nodeSelector) bootID differs from -BaselineBootId and node A Ready=True"; test = { Test-Rebooted }; after = $null; deadline = $fixed },
        @{ id = 'reboot-1'; label = 'vault seal-status sealed=false type=ocikms (port-forward svc/vault)'; test = { Test-Vault }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-2'; label = "clustersecretstores exactly 5 and all Ready [$($expectedStores -join ', ')]"; test = { Test-Stores }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-3'; label = 'argocd applications all Healthy'; test = { Test-Argo }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-4'; label = $r4Label; test = { Test-ExternalSecrets }; after = 'reboot-2'; deadline = { param($st) $st['reboot-2'].at + $esRefreshSec } }
    )

    if (-not $AfterReboot) {
        # 평상시: 신원은 한 번만 확인(러너가 이미 통과시켰지만 단독 실행도 같은 경계를 지킨다), 재부팅 단언은 SKIP.
        $idr = Test-Identity
        Assert 'reboot-pre-3' "context user is $expectedUser" ([bool]$idr.ok) $idr.detail
        foreach ($c in $conds) { if (-not (Eq $c.id 'reboot-0')) { Skip $c.id $c.label } }
        Finish
    }

    Write-Host "polling reboot-0..4 (nominal interval ${pollIntervalSec}s; reboot-0..3 deadline ${phaseDeadlineSec}s from start; reboot-4 deadline = reboot-2 pass + ${esRefreshSec}s)"
    $st = Invoke-PollLoop $conds
    $fatalId = $null
    foreach ($c in $conds) { if (Eq $st[$c.id].verdict 'fatal') { $fatalId = $c.id } }
    foreach ($c in $conds) {
        $s = $st[$c.id]
        $rel = ''
        if ($null -ne $c.after -and $null -ne $s.at -and (Eq $st[$c.after].verdict 'ok')) { $rel = " (+$(Sec ($s.at - $st[$c.after].at))s after $($c.after))" }
        switch ($s.verdict) {
            'ok' {
                # 마감 안에 시작해 마감을 넘겨 끝난 관측이면 그 사실을 드러낸다
                $when = if ($s.at -gt $s.deadline) { "met at $(Sec $s.at)s (observation started at $(Sec $s.startedAt)s, deadline $(Sec $s.deadline)s)" } else { "met at $(Sec $s.at)s (deadline $(Sec $s.deadline)s)" }
                Assert $c.id $c.label $true "$when$rel; $($s.detail)"
            }
            'late' { Assert $c.id $c.label $false "met late at $(Sec $s.at)s (observation started at $(Sec $s.startedAt)s, after the deadline $(Sec $s.deadline)s)$rel; $($s.detail)" }
            'expired' { Assert $c.id $c.label $false "not met within $(Sec $s.deadline)s (last observation at $(Sec $s.at)s: $($s.detail))" }
            'final' { Assert $c.id $c.label $false "$($s.detail) (at $(Sec $s.at)s)" }
            'fatal' { Assert $c.id $c.label $false $s.detail }
            'not-attempted' { Assert $c.id $c.label $false "not attempted ($($s.detail))" }
            default { Assert $c.id $c.label $false "not attempted (aborted by $fatalId)" }
        }
    }
    Write-Host "polling ended at $(Sec (Now))s"
    Finish
} finally {
    if ($null -ne $script:pf) {
        Stop-Tree $script:pf
        Remove-TempFiles $script:pfFiles
    }
}
