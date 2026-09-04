# tests/platform/cluster.tests.ps1 — US2 클러스터·GitOps·PSA·NetworkPolicy·Vault seal·ESO·백업 단언 (T031, test-first)
# Run: $env:KUBECONFIG=<agent-view 토큰 kubeconfig>; pwsh -NoProfile -File tests/platform/cluster.tests.ps1
#      (보통은 tests/platform/run-platform-tests.ps1이 agent-view 신원 게이트를 지난 뒤 이 파일을 실행한다)
# Exit 0 = 실패 0(SKIP 허용), 1 = 실패 ≥ 1. 외부 프레임워크 없음(tests/infra/tofu.tests.ps1과 같은 자체 완결 구조).
# 출력: 항목별 `PASS|FAIL|SKIP <id>: …` 한 줄, 마지막 줄 `N passed, N failed, N skipped`.
#
# 접근 계약(contracts/hostnames-and-access.md §에이전트 자격):
#   - `$env:KUBECONFIG`(SA `agent-view` 8h 토큰)로만 접근한다. 미설정·파일 없음·kubectl 부재·whoami ≠ agent-view는 전부 FAIL(fail closed)
#     — 기본 kubeconfig(~/.kube/config, Docker Desktop 등)로 흘러가지 않도록 모든 kubectl 호출에 --kubeconfig를 명시한다.
#   - 사용하는 동사는 kubectl get / logs / port-forward / auth whoami / auth can-i 뿐이다(exec·생성·변경 동사 없음).
#   - Vault seal은 `kubectl -n vault port-forward svc/vault <로컬포트>:8200`(백그라운드) + `GET /v1/sys/seal-status`로 읽고 try/finally로 정리한다
#     (agent-view는 vault·data·identity ns의 pods/portforward만 가진다). 로컬 포트는 빈 포트를 동적으로 잡는다(운영자 port-forward와 충돌 방지).
#   - OCI는 읽기 전용 프로파일 `svc-verify`(세션 토큰 → `--auth security_token`; OCI_CLI_AUTH가 설정돼 있으면 그 값을 존중)로
#     `os object list`만 호출한다. 버킷 실명은 joshuatech-backup-platform(이름 예외 — 설계 문서의 jt-* 표기, docs/runbooks/bootstrap.md §0).
#     Windows의 oci.exe는 키 파일 권한 검사를 Windows PowerShell 5.1(`Get-Acl`)로 하는데 pwsh 7이 상속시킨 PSModulePath의 pwsh 7 모듈
#     경로($PSHOME) 때문에 5.1이 Microsoft.PowerShell.Security를 못 읽고 실패한다 — 호출 동안만 그 경로를 빼고 finally에서 복원한다.
#     stdin은 빈 파일로 리다이렉트한다: 세션 토큰이 만료되면 CLI가 "re-authenticate? [Y/n]"를 묻는데, EOF면 Abort(exit 1 → FAIL)로 끝나고
#     브라우저 재인증이 열리지 않는다(세션 갱신은 운영자가 `oci session authenticate --profile-name svc-verify`로 직접 한다).
#   - 비밀·토큰·kubeconfig 내용·개인 경로는 출력하지 않는다(실패 메시지는 리소스 이름·상태만 담는다). 네이티브 stdout/stderr는 반환 전에
#     kubeconfig 경로 → <KUBECONFIG>, 홈 디렉터리($HOME·USERPROFILE) → ~ 로 마스킹한다(Mask-Text, ordinal).
#   - 임시 파일(port-forward·oci 리다이렉트)은 프로세스 트리 kill + WaitForExit 뒤 재시도 삭제한다 — %TEMP%\cluster-tests-* 잔존 0.
#
# 단계별 SKIP(실패로 세지 않음 — T102 E2E에서 전체 재실행):
#   - ca-1      CA 미러 Secret(pg-main-ca, ns identity·jt-dev·jt-prod)이 셋 다 없으면 `SKIP ca-1: until T056`
#   - np-2-*    platform/policies/tests/ assert Job(data-assert·kafka-assert·authz-assert, ns jt-dev)이 없으면 `SKIP … until T041`
#   - limits-*  jt-dev·jt-prod에 Running pod가 하나도 없으면 `SKIP … until T075`
#   - mon-1     ns monitoring의 DaemonSet/StatefulSet/Deployment 중 이름이 alloy-metrics로 끝나거나 라벨 app.kubernetes.io/name=alloy-metrics인
#               워크로드가 0개면 `SKIP mon-1: until T098`(T098 실제 형상 = StatefulSet k8s-monitoring-alloy-metrics; 종류로 FAIL하지 않는다)
#   - np-2-manual · np-3-live · np-4-live · np-5-live · np-6-live: ns 내부 출발 프로브(agent-view에는 exec·pod 생성 권한이 없다) —
#     항상 `SKIP …: 운영자 수동`(명령 출력을 report에 첨부). 정적으로 증명 가능한 부분(np-3·np-4·np-5·np-6)은 클러스터에 적용된
#     NetworkPolicy 객체를 읽어 단언한다.
#   그 밖의 모든 항목은 클러스터·리소스가 없으면 FAIL이다(fail closed; JSON 파싱 실패·port-forward 실패·oci 실패 포함).
#
# 계약 요약(contracts/network-policy.md · gitops-repo.md · tasks.md T031 문면):
#   nodes-1..3  노드 정확히 2·전부 Ready, 라벨 role=platform / role=data 하나씩, svccontroller.k3s.cattle.io/enablelb=true는 platform 노드만
#   argo-1..4   applications 전부 Synced/Healthy($argoExcludedApps 제외), appproject default sourceRepos·destinations 빈 배열,
#               appproject dev·prod namespaceResourceBlacklist ⊇ {NetworkPolicy, ResourceQuota, LimitRange, Role, RoleBinding, ServiceAccount}
#               (group도 대조: networking.k8s.io / "" / rbac.authorization.k8s.io, '*' 허용),
#               Cluster pg-main · Kafka jt-kafka · KafkaNodePool · Vault/Dragonfly PVC · 오퍼레이터 CRD(그룹 접미 cnpg.io·strimzi.io·cert-manager.io·external-secrets.io)에
#               argocd.argoproj.io/sync-options = "Delete=false,Prune=false"(정확 일치)
#   vault-1..2  seal-status sealed=false · type=ocikms
#   eso-1..3    clustersecretstore 정확히 5개(vault-platform·vault-dev·vault-prod·vault-data·k8s-data-ca) Ready, externalsecret -A 전부
#               SecretSynced, secretStoreRef(kind ClusterSecretStore)가 ns scope·remoteRef.key 접두와 일치
#   ca-1        CA 미러 Secret 키 = ["ca.crt"](ca.key 있으면 FAIL). agent-view는 Secret get이 없으므로 `auth can-i`가 no면
#               같은 이름의 ExternalSecret spec(dataFrom 없음·remoteRef.property=ca.crt·secretKey=ca.crt·template data 키 없음·
#               templateFrom 없음·mergePolicy 미사용·store k8s-data-ca)으로 증명한다.
#   ns-1..2     네임스페이스 14개 전부 존재, observability 없음
#   psa-1..2    pod-security.kubernetes.io/enforce = 표(14, kube-system 포함), warn·audit = enforce와 같은 레벨
#   np-set-1..5 default-deny(13)·allow-dns(13)·allow-same-namespace(정확히 7)·allow-kube-api(정확히 10)·allow-apiserver-webhook(정확히 4, 포트)
#   np-cond-1..2 deny-imds는 kube-system 전용(클러스터 전체 1개), allow-imds는 vault 전용
#   np-1        kube-system의 NetworkPolicy 집합 = {deny-imds}(default-deny 없음)
#   np-2        ② 매트릭스 행 도달 — assert Job 성공(status.succeeded ≥ 1) + logs 읽기 가능; 나머지 행은 운영자 수동
#   np-3        ③ 표 밖 조합 차단 — 정적: jt-prod ingress가 jt-dev를, jt-dev ingress가 data를 허용하지 않음(+ live 수동)
#   np-4        ④ 정적: vault ingress 허용 ns ⊆ {kube-system, monitoring, external-secrets}(노드 A ipBlock은 별도; vault 자기 ns 불허)(+ live 수동)
#   np-5        ⑤ 정적: jt-dev egress ipBlock 규칙 전부 ports 있음 + 0.0.0.0/0 규칙은 except 4개(IMDS·RFC1918) + 그런 외부 443 규칙 ≥ 1(0개면 FAIL)
#               + RFC1918 대역을 cidr 자체로 쓴 규칙 0(+ live 수동)
#   np-6        ⑥ 정적: vault 이외 13 ns의 어떤 egress 규칙도 169.254.169.254를 허용하지 않음, kube-system deny-imds except에 IMDS(+ live 수동)
#   np-7        ⑦ 전 ns 이벤트에 "violates PodSecurity" 0 — K3s event TTL 1h: 배포 직후(1h 내) 실행해야 의미 있음(그 뒤엔 공허 PASS)
#   mon-1       alloy-metrics 워크로드(ds/sts/deploy, 이름 접미 또는 라벨) 각각 logs --tail=300 --all-containers에 connection refused ·
#               context deadline exceeded 0
#   limits-1..2 jt-dev·jt-prod Running pod 컨테이너: limits.cpu 없음 · limits.memory 있음
#   reloader-1  deployment reloader(ns reloader) Available=True
#   backup-1..3 joshuatech-backup-platform k3s/ · vault/ 에 24h 내 .age 오브젝트 ≥ 1, 비-.age(평문) 오브젝트 0
#
# 단언 수: 48 = gate 3 + nodes 3 + argo 4 + vault 2 + eso 3 + ca 1 + ns 2 + psa 2 + np-set 5 + np-cond 2 + np 14 + mon 1 + limits 2 +
#          reloader 1 + backup 3 (np 14 = np-1, np-2-data-assert, np-2-kafka-assert, np-2-authz-assert, np-2-manual, np-3, np-3-live,
#          np-4, np-4-live, np-5, np-5-live, np-6, np-6-live, np-7). live/manual 5개는 항상 SKIP이므로 PASS 후보는 43, 그중 단계별
#          SKIP 게이트는 ca-1 · np-2-* 3 · limits-* 2 · mon-1 의 7개.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다
$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:clusterReason = $null      # $null = 게이트 통과; 문자열이면 모든 클러스터 단언이 그 사유로 FAIL
$script:kubectl = $null            # kubectl 실행 파일 경로(게이트 1)
$script:kubeconfig = $null         # $env:KUBECONFIG(게이트 2)
$script:cache = @{}                # 리스트 조회 캐시(같은 리스트를 여러 단언이 쓴다)

$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$ociProfile = 'svc-verify'
$backupBucket = 'joshuatech-backup-platform'   # 이름 예외(2026-09-03): 설계 문서의 jt-backup-platform
$syncOptions = 'Delete=false,Prune=false'
$argoExcludedApps = @()   # "ES 제외 목록": Elasticsearch/ECK·Kibana(spec D11·D20, SP-3)는 SP-1에 배포하지 않으므로 현재 비어 있다.
                          # ES Application이 생기면 이름을 여기 등재한다(등재 이름은 Synced/Healthy 요구에서 제외).

# ---------- 계약 표(contracts/network-policy.md) ----------
$nsPsa = [ordered]@{
    'kube-system'      = 'privileged'
    'argocd'           = 'restricted'
    'vault'            = 'restricted'
    'external-secrets' = 'restricted'
    'cert-manager'     = 'baseline'
    'cnpg-system'      = 'baseline'
    'data'             = 'baseline'
    'identity'         = 'restricted'
    'jt-dev'           = 'restricted'
    'jt-prod'          = 'restricted'
    'monitoring'       = 'privileged'
    'system-upgrade'   = 'privileged'
    'cloudflared'      = 'restricted'
    'reloader'         = 'restricted'
}
$ns14 = @($nsPsa.Keys | ForEach-Object { "$_" })
$ns13 = @($ns14 | Where-Object { -not [string]::Equals($_, 'kube-system', [StringComparison]::Ordinal) })
$sameNs7 = @('argocd', 'data', 'cnpg-system', 'external-secrets', 'cert-manager', 'monitoring', 'identity')
$kubeApi10 = @('argocd', 'vault', 'external-secrets', 'cert-manager', 'cnpg-system', 'data', 'monitoring', 'system-upgrade', 'reloader', 'cloudflared')
$webhook4 = [ordered]@{ 'cert-manager' = 10250; 'external-secrets' = 10250; 'cnpg-system' = 9443; 'vault' = 8200 }
$imdsIp = '169.254.169.254'
$except4 = @('169.254.169.254/32', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')
$storeNames5 = @('vault-platform', 'vault-dev', 'vault-prod', 'vault-data', 'k8s-data-ca')
$caMirrorKeys = @('pg-main-ca', 'jt-kafka-cluster-ca-cert')
$blacklistKinds = @('NetworkPolicy', 'ResourceQuota', 'LimitRange', 'Role', 'RoleBinding', 'ServiceAccount')
# namespaceResourceBlacklist 항목의 group(정확 일치; '*'도 허용). core 그룹은 "" (JSON에 group 키가 없으면 ""로 본다)
$blacklistGroups = @{ 'NetworkPolicy' = 'networking.k8s.io'; 'ResourceQuota' = ''; 'LimitRange' = ''; 'ServiceAccount' = ''; 'Role' = 'rbac.authorization.k8s.io'; 'RoleBinding' = 'rbac.authorization.k8s.io' }
# 오퍼레이터 CRD 그룹: 정확 일치 또는 ".<접미>"로 끝남 — cnpg.io는 postgresql.cnpg.io·barmancloud.cnpg.io(플러그인) 둘 다 포함
$operatorCrdGroups = @('cnpg.io', 'strimzi.io', 'cert-manager.io', 'external-secrets.io')
$assertJobs = @('data-assert', 'kafka-assert', 'authz-assert')
# assert Job이 실제로 증명하는 매트릭스 범위(np-2-* PASS 문구)
$assertJobScope = @{ 'data-assert' = 'jt-dev -> data 5432 (pg-main) and 6379 (Dragonfly)'; 'kafka-assert' = 'jt-dev -> data 9093 (Kafka SCRAM/TLS)'; 'authz-assert' = 'jt-dev -> identity 8080 (OpenFGA)' }
$vaultIngressNs = @('kube-system', 'monitoring', 'external-secrets')   # 매트릭스의 vault 8200 도착 행(노드 A ipBlock은 별도) — vault 자기 ns 없음(allow-same-namespace 대상 아님)

# ---------- 결과 헬퍼 ----------
function Clip([string]$s, [int]$max = 400) {
    if ($null -eq $s) { return '' }
    $s = ($s -replace "`r`n", ' ') -replace "`n", ' '
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' } else { return $s }
}
function Pass([string]$id, [string]$detail) { $script:pass++; Write-Host "PASS ${id}: $(Clip $detail)" }
function Fail([string]$id, [string]$detail) { $script:fail++; Write-Host "FAIL ${id}: $(Clip $detail)" }
function Skip([string]$id, [string]$detail) { $script:skip++; Write-Host "SKIP ${id}: $(Clip $detail)" }

# 클러스터 단언 래퍼: 게이트 실패면 사유와 함께 FAIL(fail closed). $body는 @('PASS'|'FAIL'|'SKIP', detail)을 돌려준다.
# 예외(kubectl 실패·JSON 파싱 실패 등)는 FAIL이다.
function ClusterAssert([string]$id, [scriptblock]$body) {
    if ($null -ne $script:clusterReason) { Fail $id "cluster unavailable ($script:clusterReason)"; return }
    $status = 'FAIL'; $detail = ''
    try {
        $r = @(& $body)   # 마지막 두 원소가 (status, detail) — 본문의 우발적 파이프라인 출력이 앞에 섞여도 판정이 흔들리지 않는다
        if ($r.Count -lt 2) { throw "assertion body returned $($r.Count) value(s), expected (status, detail)" }
        $status = [string]$r[$r.Count - 2]; $detail = [string]$r[$r.Count - 1]
    }
    catch { $status = 'FAIL'; $detail = "unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    switch ($status) {
        'PASS' { Pass $id $detail }
        'SKIP' { Skip $id $detail }
        default { Fail $id $detail }
    }
}

# ---------- 문자열·집합 헬퍼(전부 ordinal) ----------
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function SortOrd($arr) {
    $l = [System.Collections.Generic.List[string]]::new()
    foreach ($x in @($arr)) { if ($null -ne $x) { $l.Add([string]$x) } }
    $l.Sort([StringComparer]::Ordinal)
    return @($l.ToArray())
}
function SetEq($a, $b) { return (Eq ((SortOrd $a) -join "`n") ((SortOrd $b) -join "`n")) }
function Contains($arr, [string]$v) { foreach ($x in @($arr)) { if (Eq "$x" $v) { return $true } }; return $false }
function Except($arr, $minus) { return @(@($arr) | Where-Object { -not (Contains $minus "$_") }) }
function StartsOrd([string]$s, [string]$prefix) { return ($null -ne $s) -and $s.StartsWith($prefix, [StringComparison]::Ordinal) }
function EndsOrd([string]$s, [string]$suffix) { return ($null -ne $s) -and $s.EndsWith($suffix, [StringComparison]::Ordinal) }
function IndexOrd([string]$s, [string]$sub) { if ($null -eq $s) { return -1 }; return $s.IndexOf($sub, [StringComparison]::Ordinal) }

# ---------- JSON 객체 접근(속성 이름 ordinal 정확 일치; 없으면 $null) ----------
function Prop($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) {
        foreach ($k in $obj.Keys) { if (Eq "$k" $name) { return $obj[$k] } }
        return $null
    }
    foreach ($p in $obj.PSObject.Properties) { if (Eq $p.Name $name) { return $p.Value } }
    return $null
}
function PropPath($obj, [string[]]$path) {
    $cur = $obj
    foreach ($n in $path) { $cur = Prop $cur $n; if ($null -eq $cur) { return $null } }
    return $cur
}
# 배열 필드용: 없으면 빈 배열(@($null)이 원소 1개로 세어지는 PowerShell 특성을 막는다). 호출 측은 @(PropArr …)로 감싼다.
function PropArr($obj, [string[]]$path) { $v = PropPath $obj $path; if ($null -eq $v) { return @() }; return @($v) }
function PropNames($obj) {
    if ($null -eq $obj) { return @() }
    if ($obj -is [System.Collections.IDictionary]) { return @($obj.Keys | ForEach-Object { "$_" }) }
    return @($obj.PSObject.Properties | ForEach-Object { $_.Name })
}
# 반환은 언래핑된 배열이다 — 호출 측은 반드시 @(Items …)로 감싼다(원소 1개가 스칼라로 풀리는 것을 막는다).
function Items($listObj) { $i = Prop $listObj 'items'; if ($null -eq $i) { return @() }; return @($i) }
function Name($obj) { return [string](PropPath $obj @('metadata', 'name')) }
function Ns($obj) { return [string](PropPath $obj @('metadata', 'namespace')) }
function Label($obj, [string]$key) { $v = PropPath $obj @('metadata', 'labels', $key); if ($null -eq $v) { return $null }; return [string]$v }
function Annotation($obj, [string]$key) { $v = PropPath $obj @('metadata', 'annotations', $key); if ($null -eq $v) { return $null }; return [string]$v }
function Condition($obj, [string]$type) {
    foreach ($c in @(PropArr $obj @('status', 'conditions'))) { if (Eq ([string](Prop $c 'type')) $type) { return $c } }
    return $null
}

# 출력 마스킹: kubeconfig 경로·홈 디렉터리를 <KUBECONFIG>/~로 치환(ordinal; \ 와 / 두 표기 모두) — 개인 경로가 리포트에 남지 않게.
# kubeconfig를 먼저 치환한다(보통 홈 아래에 있어 홈을 먼저 바꾸면 매치가 깨진다).
function Mask-Text([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return $s }
    $pairs = @()
    foreach ($kc in @($script:kubeconfig, $env:KUBECONFIG)) { if (-not [string]::IsNullOrWhiteSpace($kc)) { $pairs += , @($kc, '<KUBECONFIG>') } }
    foreach ($h in @($HOME, $env:USERPROFILE)) { if (-not [string]::IsNullOrWhiteSpace($h)) { $pairs += , @($h, '~') } }
    foreach ($p in $pairs) {
        $s = $s.Replace([string]$p[0], [string]$p[1], [StringComparison]::Ordinal)
        $s = $s.Replace(([string]$p[0]).Replace('\', '/'), [string]$p[1], [StringComparison]::Ordinal)
    }
    return $s
}
# 임시 파일 삭제(자식 프로세스가 핸들을 늦게 놓을 수 있어 3회 재시도)
function Remove-WithRetry([string[]]$paths) {
    foreach ($p in $paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        for ($i = 1; $i -le 3; $i++) {
            if (-not (Test-Path -LiteralPath $p)) { break }
            try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 300 }
        }
    }
}

# ---------- 네이티브 실행(stdout UTF-8 디코드; stderr는 임시 파일; 반환 전 경로 마스킹) ----------
function Invoke-Native([string]$exe, [string[]]$nativeArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('cluster-tests-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $out = @(); $code = -1; $err = ''
    $prevEncoding = [Console]::OutputEncoding
    try {
        try {
            [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            $out = & $exe @nativeArgs 2> $errFile
            $code = $LASTEXITCODE
        } finally { [Console]::OutputEncoding = $prevEncoding }
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) } else { '' }
    } finally { Remove-WithRetry @($errFile) }
    return @{ out = (Mask-Text (@($out | ForEach-Object { "$_" }) -join "`n")); err = (Mask-Text $err.Trim()); code = $code }
}
# oci — stdin을 빈 파일로(대화형 프롬프트 차단), PSModulePath에서 pwsh 7 모듈 경로($PSHOME)를 호출 동안만 제거(헤더 참조).
# 경로 비교는 Windows 파일 시스템이라 OrdinalIgnoreCase.
function Invoke-Oci([string]$exe, [string[]]$ociArgs) {
    $tmp = [IO.Path]::GetTempPath(); $tag = [guid]::NewGuid().ToString('N')
    $inFile = Join-Path $tmp "cluster-tests-oci-in-$tag.txt"; $outFile = Join-Path $tmp "cluster-tests-oci-out-$tag.txt"; $errFile = Join-Path $tmp "cluster-tests-oci-err-$tag.txt"
    $prevModulePath = $env:PSModulePath
    $out = ''; $err = ''; $code = -1
    try {
        [IO.File]::WriteAllText($inFile, '')
        $env:PSModulePath = (@($prevModulePath -split [IO.Path]::PathSeparator) | Where-Object { -not $_.StartsWith($PSHOME, [StringComparison]::OrdinalIgnoreCase) }) -join [IO.Path]::PathSeparator
        $p = Start-Process -FilePath $exe -ArgumentList @($ociArgs | ForEach-Object { if ($_.IndexOf(' ') -ge 0) { "`"$_`"" } else { $_ } }) `
            -RedirectStandardInput $inFile -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
        $timedOut = $false
        if (-not $p.WaitForExit(120000)) {   # 120s 상한 — 초과 시 프로세스 트리 kill + FAIL
            $timedOut = $true
            try { $p.Kill($true) } catch { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
            [void]$p.WaitForExit(5000)
        }
        $code = if ($timedOut) { -1 } else { $p.ExitCode }
        $out = if (Test-Path -LiteralPath $outFile) { [IO.File]::ReadAllText($outFile, [Text.Encoding]::UTF8) } else { '' }
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) } else { '' }
        if ($timedOut) { $err = "oci timed out after 120s (killed). $err" }
    } finally {
        $env:PSModulePath = $prevModulePath
        Remove-WithRetry @($inFile, $outFile, $errFile)
    }
    return @{ out = (Mask-Text $out); err = (Mask-Text $err.Trim()); code = $code }
}
# kubectl — 항상 --kubeconfig 명시(기본 kubeconfig로 흘러가지 않게) + 요청 타임아웃.
function Invoke-Kubectl([string[]]$kArgs) {
    return Invoke-Native $script:kubectl (@("--kubeconfig=$script:kubeconfig", '--request-timeout=30s') + @($kArgs))
}
function ConvertFrom-JsonStrict([string]$text, [string]$what) {
    if ([string]::IsNullOrWhiteSpace($text)) { throw "empty output from $what (expected JSON)" }
    try { return ($text | ConvertFrom-Json -Depth 64) }
    catch { throw "JSON parse failed for ${what}: $($_.Exception.Message)" }
}
# 리스트 조회(-o json). $kArgs 예: @('get','networkpolicies.networking.k8s.io','-A'). 실패는 예외(= FAIL).
function Get-KubeList([string[]]$kArgs) {
    $key = ($kArgs -join ' ')
    if ($script:cache.ContainsKey($key)) { return $script:cache[$key] }
    $r = Invoke-Kubectl (@($kArgs) + @('-o', 'json'))
    if ($r.code -ne 0) { throw "kubectl $key failed (exit $($r.code)): $($r.err)" }
    $obj = ConvertFrom-JsonStrict $r.out "kubectl $key"
    $script:cache[$key] = $obj
    return $obj
}
# 단일 리소스 조회 — 없으면 $null(--ignore-not-found), 다른 오류는 예외.
function Get-KubeOne([string]$ns, [string]$kind, [string]$name) {
    $kArgs = @('get', $kind, $name, '--ignore-not-found', '-o', 'json')
    if (-not [string]::IsNullOrEmpty($ns)) { $kArgs = @('-n', $ns) + $kArgs }
    $r = Invoke-Kubectl $kArgs
    if ($r.code -ne 0) { throw "kubectl get $kind/$name (ns '$ns') failed (exit $($r.code)): $($r.err)" }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return $null }
    return (ConvertFrom-JsonStrict $r.out "kubectl get $kind/$name")
}
function Get-Namespaces { return @(Items (Get-KubeList @('get', 'namespaces'))) }
function Get-NetworkPolicies { return @(Items (Get-KubeList @('get', 'networkpolicies.networking.k8s.io', '-A'))) }
function Get-PoliciesIn([string]$ns) { return @(Get-NetworkPolicies | Where-Object { Eq (Ns $_) $ns }) }
function Get-PolicyNamesIn([string]$ns) { return @(Get-PoliciesIn $ns | ForEach-Object { Name $_ }) }
function Get-Policy([string]$ns, [string]$name) { foreach ($p in @(Get-PoliciesIn $ns)) { if (Eq (Name $p) $name) { return $p } }; return $null }
function Test-PolicyType($pol, [string]$type) {
    $types = @(PropArr $pol @('spec', 'policyTypes'))
    if ($types.Count -eq 0) {
        # policyTypes 생략: Ingress는 항상, Egress는 egress 규칙이 있을 때만(K8s 기본 규칙)
        if (Eq $type 'Ingress') { return $true }
        return ($null -ne (PropPath $pol @('spec', 'egress')))
    }
    return (Contains $types $type)
}

# ---------- IPv4 CIDR ----------
function ConvertTo-IpUInt([string]$ip) {
    $addr = $null
    if (-not [Net.IPAddress]::TryParse($ip, [ref]$addr)) { return $null }
    if ($addr.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { return $null }
    $b = $addr.GetAddressBytes()
    return ([uint64]$b[0] * 16777216) + ([uint64]$b[1] * 65536) + ([uint64]$b[2] * 256) + [uint64]$b[3]
}
# $cidr가 $ip를 포함하면 $true; 파싱 불가(IPv6 등)는 $null(호출 측이 fail closed로 다룬다)
function Test-CidrContains([string]$cidr, [string]$ip) {
    if ([string]::IsNullOrWhiteSpace($cidr)) { return $null }
    $parts = $cidr.Split('/')
    if ($parts.Count -ne 2) { return $null }
    $net = ConvertTo-IpUInt $parts[0]; $target = ConvertTo-IpUInt $ip
    $bits = 0
    if ($null -eq $net -or $null -eq $target -or -not [int]::TryParse($parts[1], [ref]$bits) -or $bits -lt 0 -or $bits -gt 32) { return $null }
    if ($bits -eq 0) { return $true }
    # 0xFFFFFFFF 리터럴은 PowerShell에서 int32 -1로 파싱되므로 10진수로 쓴다
    $mask = ([uint64]4294967295 -shl (32 - $bits)) -band [uint64]4294967295
    return (($net -band $mask) -eq ($target -band $mask))
}
# ipBlock이 $ip를 실제로 허용하는가(cidr 포함 && except가 덮지 않음). 평가 불가는 $null.
function Test-IpBlockAllows($ipBlock, [string]$ip) {
    $in = Test-CidrContains ([string](Prop $ipBlock 'cidr')) $ip
    if ($null -eq $in) { return $null }
    if (-not $in) { return $false }
    foreach ($e in @(PropArr $ipBlock @('except'))) {
        $covered = Test-CidrContains ([string]$e) $ip
        if ($null -eq $covered) { return $null }
        if ($covered) { return $false }
    }
    return $true
}

# ---------- NetworkPolicy 정적 평가 ----------
# 대상 ns의 ingress가 허용하는 출발 ns 집합. anyAll = 출발 제한 없는 규칙(from 없음 / namespaceSelector {}) 존재,
# unevaluable = 평가할 수 없는 selector(matchExpressions·metadata.name 이외 라벨) 존재. default-deny(Ingress) 부재도 anyAll.
function Get-IngressSources([string]$ns) {
    $sources = [System.Collections.Generic.List[string]]::new()
    $anyAll = $false; $unevaluable = @()
    $deny = Get-Policy $ns 'default-deny'
    if ($null -eq $deny -or -not (Test-PolicyType $deny 'Ingress')) { $anyAll = $true }
    foreach ($pol in @(Get-PoliciesIn $ns)) {
        if (-not (Test-PolicyType $pol 'Ingress')) { continue }
        foreach ($rule in @(PropArr $pol @('spec', 'ingress'))) {
            $from = @(PropArr $rule @('from'))
            if ($from.Count -eq 0) { $anyAll = $true; continue }
            foreach ($peer in $from) {
                $nsSel = Prop $peer 'namespaceSelector'
                if ($null -ne $nsSel) {
                    if ($null -ne (Prop $nsSel 'matchExpressions')) { $unevaluable += "$(Name $pol): matchExpressions"; continue }
                    $ml = Prop $nsSel 'matchLabels'
                    $names = @(PropNames $ml)
                    if ($names.Count -eq 0) { $anyAll = $true; continue }
                    $v = Prop $ml 'kubernetes.io/metadata.name'
                    if ($null -eq $v) { $unevaluable += "$(Name $pol): namespaceSelector without kubernetes.io/metadata.name"; continue }
                    $sources.Add([string]$v)
                } elseif ($null -ne (Prop $peer 'podSelector')) {
                    $sources.Add($ns)   # podSelector만 = 같은 ns
                }
                # ipBlock만 있는 peer는 노드 IP(네임스페이스 아님) — 집합에 넣지 않는다
            }
        }
    }
    return @{ sources = @(SortOrd $sources.ToArray()); anyAll = $anyAll; unevaluable = @($unevaluable) }
}

# ---------- 0. 게이트(fail closed) ----------
$k = Get-Command kubectl -CommandType Application -ErrorAction SilentlyContinue
if ($null -ne $k) { $script:kubectl = @($k)[0].Source; Pass 'gate-1' "kubectl found" }
else { Fail 'gate-1' 'kubectl not found on PATH -- no cluster access (cluster/kubectl unavailable)'; $script:clusterReason = 'kubectl missing' }

$kc = $env:KUBECONFIG
if ([string]::IsNullOrWhiteSpace($kc)) {
    Fail 'gate-2' 'KUBECONFIG is not set -- no cluster (agent-view token kubeconfig required; cluster unavailable)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG not set' }
} elseif ($kc.IndexOf([IO.Path]::PathSeparator) -ge 0) {
    Fail 'gate-2' 'KUBECONFIG must be a single file path (path list not supported)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG is a path list' }
} elseif (-not (Test-Path -LiteralPath $kc -PathType Leaf)) {
    Fail 'gate-2' 'KUBECONFIG file not found -- no cluster (cluster unavailable)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG file not found' }
} else { $script:kubeconfig = $kc; Pass 'gate-2' 'KUBECONFIG set (single existing file)' }

if ($null -eq $script:clusterReason) {
    try {
        $r = Invoke-Kubectl @('auth', 'whoami', '-o', 'json')
        if ($r.code -ne 0) { throw "kubectl auth whoami failed (exit $($r.code)): $($r.err)" }
        $who = ConvertFrom-JsonStrict $r.out 'kubectl auth whoami'
        $username = [string](PropPath $who @('status', 'userInfo', 'username'))
        if (Eq $username $expectedUser) { Pass 'gate-3' "context user is $expectedUser" }
        else { Fail 'gate-3' "context user is '$username', expected $expectedUser (admin/other kubeconfig refused)"; $script:clusterReason = 'context user is not agent-view' }
    } catch {
        Fail 'gate-3' "kubectl auth whoami unusable -- cluster unreachable or not agent-view: $($_.Exception.Message)"
        $script:clusterReason = 'cluster unreachable (whoami failed)'
    }
} else { Fail 'gate-3' "cluster unavailable ($script:clusterReason)" }

# ---------- 1. 노드 ----------
ClusterAssert 'nodes-1' {
    $nodes = @(Items (Get-KubeList @('get', 'nodes')))
    if ($nodes.Count -ne 2) { return @('FAIL', "expected exactly 2 nodes, got $($nodes.Count)") }
    $notReady = @()
    foreach ($n in $nodes) {
        $c = Condition $n 'Ready'
        if ($null -eq $c -or -not (Eq ([string](Prop $c 'status')) 'True')) { $notReady += (Name $n) }
    }
    if ($notReady.Count -gt 0) { return @('FAIL', "not Ready: $($notReady -join ', ')") }
    return @('PASS', "2 nodes Ready: $((@($nodes | ForEach-Object { Name $_ })) -join ', ')")
}
ClusterAssert 'nodes-2' {
    $nodes = @(Items (Get-KubeList @('get', 'nodes')))
    $roles = @($nodes | ForEach-Object { [string](Label $_ 'role') })
    if (SetEq $roles @('platform', 'data')) { return @('PASS', 'labels role=platform / role=data (one each)') }
    return @('FAIL', "role labels are [$($roles -join ', ')], expected exactly {platform, data}")
}
ClusterAssert 'nodes-3' {
    $nodes = @(Items (Get-KubeList @('get', 'nodes')))
    $bad = @()
    foreach ($n in $nodes) {
        $role = Label $n 'role'; $lb = Label $n 'svccontroller.k3s.cattle.io/enablelb'
        if (Eq $role 'platform') { if (-not (Eq $lb 'true')) { $bad += "$(Name $n): enablelb='$lb' (expected 'true')" } }
        elseif ($null -ne $lb -and -not (Eq $lb 'false')) { $bad += "$(Name $n): enablelb='$lb' (expected absent or 'false' on non-platform node)" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'svccontroller.k3s.cattle.io/enablelb=true on the platform node only')
}

# ---------- 2. Argo CD ----------
ClusterAssert 'argo-1' {
    $apps = @(Items (Get-KubeList @('get', 'applications.argoproj.io', '-n', 'argocd')))
    if ($apps.Count -eq 0) { return @('FAIL', 'no Argo CD Applications in ns argocd') }
    $bad = @(); $checked = 0
    foreach ($a in $apps) {
        if (Contains $argoExcludedApps (Name $a)) { continue }
        $checked++
        $sync = [string](PropPath $a @('status', 'sync', 'status')); $health = [string](PropPath $a @('status', 'health', 'status'))
        if (-not (Eq $sync 'Synced') -or -not (Eq $health 'Healthy')) { $bad += "$(Name $a)=$sync/$health" }
    }
    if ($checked -eq 0) { return @('FAIL', 'every Application is on the exclusion list -- nothing checked') }
    if ($bad.Count -gt 0) { return @('FAIL', "not Synced/Healthy: $($bad -join ', ')") }
    return @('PASS', "$checked Applications Synced/Healthy (excluded: $($argoExcludedApps.Count))")
}
ClusterAssert 'argo-2' {
    $p = Get-KubeOne 'argocd' 'appprojects.argoproj.io' 'default'
    if ($null -eq $p) { return @('FAIL', 'AppProject default not found') }
    $repos = @(PropArr $p @('spec', 'sourceRepos')); $dests = @(PropArr $p @('spec', 'destinations'))
    if ($repos.Count -eq 0 -and $dests.Count -eq 0) { return @('PASS', 'AppProject default: sourceRepos=[] destinations=[]') }
    return @('FAIL', "AppProject default not neutralized: sourceRepos=$($repos.Count) destinations=$($dests.Count)")
}
ClusterAssert 'argo-3' {
    $bad = @()
    foreach ($name in @('dev', 'prod')) {
        $p = Get-KubeOne 'argocd' 'appprojects.argoproj.io' $name
        if ($null -eq $p) { $bad += "AppProject $name not found"; continue }
        $entries = @(PropArr $p @('spec', 'namespaceResourceBlacklist'))
        $missing = @()
        foreach ($kind in $blacklistKinds) {
            $wantGroup = [string]$blacklistGroups[$kind]
            $hit = @($entries | Where-Object {
                    $g = Prop $_ 'group'; $gs = if ($null -eq $g) { '' } else { [string]$g }
                    (Eq ([string](Prop $_ 'kind')) $kind) -and ((Eq $gs $wantGroup) -or (Eq $gs '*')) })
            if ($hit.Count -eq 0) { $missing += "$kind(group '$wantGroup' or '*')" }
        }
        if ($missing.Count -gt 0) { $bad += "AppProject ${name}: namespaceResourceBlacklist missing $($missing -join ', ')" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', "AppProject dev/prod namespaceResourceBlacklist covers $($blacklistKinds -join ', ') with matching group")
}
ClusterAssert 'argo-4' {
    $bad = @(); $ok = 0
    $check = { param($obj, [string]$label)
        $v = Annotation $obj 'argocd.argoproj.io/sync-options'
        if (Eq $v $syncOptions) { $script:tmpOk++ } else { $script:tmpBad += "${label}: sync-options='$v'" } }
    $script:tmpOk = 0; $script:tmpBad = @()
    $pg = Get-KubeOne 'data' 'clusters.postgresql.cnpg.io' 'pg-main'
    if ($null -eq $pg) { $script:tmpBad += 'Cluster pg-main (ns data) not found' } else { & $check $pg 'Cluster pg-main' }
    $kafka = Get-KubeOne 'data' 'kafkas.kafka.strimzi.io' 'jt-kafka'
    if ($null -eq $kafka) { $script:tmpBad += 'Kafka jt-kafka (ns data) not found' } else { & $check $kafka 'Kafka jt-kafka' }
    $pools = @(Items (Get-KubeList @('get', 'kafkanodepools.kafka.strimzi.io', '-n', 'data')))
    if ($pools.Count -eq 0) { $script:tmpBad += 'no KafkaNodePool in ns data' }
    foreach ($x in $pools) { & $check $x "KafkaNodePool $(Name $x)" }
    $vaultPvc = @(Items (Get-KubeList @('get', 'persistentvolumeclaims', '-n', 'vault')))
    if ($vaultPvc.Count -eq 0) { $script:tmpBad += 'no PVC in ns vault' }
    foreach ($x in $vaultPvc) { & $check $x "PVC vault/$(Name $x)" }
    $dfPvc = @(Items (Get-KubeList @('get', 'persistentvolumeclaims', '-n', 'data')) | Where-Object {
            (IndexOrd (Name $_) 'dragonfly') -ge 0 -or (Eq (Label $_ 'app.kubernetes.io/name') 'dragonfly') })
    if ($dfPvc.Count -eq 0) { $script:tmpBad += 'no Dragonfly PVC in ns data (name contains "dragonfly" or label app.kubernetes.io/name=dragonfly)' }
    foreach ($x in $dfPvc) { & $check $x "PVC data/$(Name $x)" }
    $crds = @(Items (Get-KubeList @('get', 'customresourcedefinitions.apiextensions.k8s.io')))
    foreach ($g in $operatorCrdGroups) {
        $mine = @($crds | Where-Object { $grp = [string](PropPath $_ @('spec', 'group')); (Eq $grp $g) -or (EndsOrd $grp ".$g") })
        if ($mine.Count -eq 0) { $script:tmpBad += "no CRD for operator group $g" }
        foreach ($x in $mine) { & $check $x "CRD $(Name $x)" }
    }
    $bad = @($script:tmpBad); $ok = $script:tmpOk
    if ($bad.Count -gt 0) { return @('FAIL', "sync-options '$syncOptions' missing/mismatch: $($bad -join '; ')") }
    return @('PASS', "$ok resources carry argocd.argoproj.io/sync-options=$syncOptions")
}

# ---------- 3. Vault seal(port-forward + GET /v1/sys/seal-status, exec 미사용) ----------
function Get-FreeLocalPort {
    $l = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $l.Start(); $p = $l.LocalEndpoint.Port; $l.Stop(); return $p
}
$script:sealStatus = $null; $script:sealError = $null
if ($null -eq $script:clusterReason) {
    $localPort = Get-FreeLocalPort
    $pfOut = Join-Path ([IO.Path]::GetTempPath()) ('cluster-tests-pf-out-' + [guid]::NewGuid().ToString('N') + '.txt')
    $pfErr = Join-Path ([IO.Path]::GetTempPath()) ('cluster-tests-pf-err-' + [guid]::NewGuid().ToString('N') + '.txt')
    $pf = $null
    try {
        $pf = Start-Process -FilePath $script:kubectl -ArgumentList @("--kubeconfig=`"$script:kubeconfig`"", '-n', 'vault', 'port-forward', 'svc/vault', "${localPort}:8200", '--address', '127.0.0.1') `
            -PassThru -NoNewWindow -RedirectStandardOutput $pfOut -RedirectStandardError $pfErr
        $deadline = [DateTime]::UtcNow.AddSeconds(30)
        while ($null -eq $script:sealStatus -and [DateTime]::UtcNow -lt $deadline) {
            if ($pf.HasExited) { break }
            try { $script:sealStatus = Invoke-RestMethod -Uri "http://127.0.0.1:$localPort/v1/sys/seal-status" -Method Get -TimeoutSec 5 -NoProxy }
            catch { Start-Sleep -Milliseconds 500 }
        }
        if ($null -eq $script:sealStatus) {
            $errText = if (Test-Path -LiteralPath $pfErr) { Mask-Text ([IO.File]::ReadAllText($pfErr, [Text.Encoding]::UTF8).Trim()) } else { '' }
            $script:sealError = if ($pf.HasExited) { "port-forward exited (code $($pf.ExitCode)): $errText" } else { "seal-status not reachable within 30s via port-forward: $errText" }
        }
    } catch { $script:sealError = "port-forward start failed: $(Mask-Text $_.Exception.Message)" }
    finally {
        # 프로세스 트리 kill(래퍼 .cmd 뒤의 자식까지) → 종료 대기 → 리다이렉트 파일 삭제(핸들 해제 지연 대비 재시도)
        if ($null -ne $pf) {
            if (-not $pf.HasExited) { try { $pf.Kill($true) } catch { Stop-Process -Id $pf.Id -Force -ErrorAction SilentlyContinue } }
            [void]$pf.WaitForExit(5000)
        }
        Remove-WithRetry @($pfOut, $pfErr)
    }
}
ClusterAssert 'vault-1' {
    if ($null -eq $script:sealStatus) { return @('FAIL', "seal-status unavailable: $script:sealError") }
    $sealed = Prop $script:sealStatus 'sealed'
    if ($sealed -is [bool] -and -not $sealed) { return @('PASS', 'seal-status sealed=false') }
    return @('FAIL', "seal-status sealed='$sealed' (expected false)")
}
ClusterAssert 'vault-2' {
    if ($null -eq $script:sealStatus) { return @('FAIL', "seal-status unavailable: $script:sealError") }
    $type = [string](Prop $script:sealStatus 'type')
    if (Eq $type 'ocikms') { return @('PASS', 'seal-status type=ocikms') }
    return @('FAIL', "seal-status type='$type' (expected ocikms)")
}

# ---------- 4. ESO ----------
ClusterAssert 'eso-1' {
    $stores = @(Items (Get-KubeList @('get', 'clustersecretstores.external-secrets.io')))
    $names = @($stores | ForEach-Object { Name $_ })
    if (-not (SetEq $names $storeNames5)) { return @('FAIL', "ClusterSecretStore set is [$((SortOrd $names) -join ', ')], expected exactly [$((SortOrd $storeNames5) -join ', ')]") }
    $notReady = @()
    foreach ($s in $stores) {
        $c = Condition $s 'Ready'
        if ($null -eq $c -or -not (Eq ([string](Prop $c 'status')) 'True')) { $notReady += (Name $s) }
    }
    if ($notReady.Count -gt 0) { return @('FAIL', "not Ready: $($notReady -join ', ')") }
    return @('PASS', '5 ClusterSecretStores present and Ready')
}
ClusterAssert 'eso-2' {
    $ess = @(Items (Get-KubeList @('get', 'externalsecrets.external-secrets.io', '-A')))
    if ($ess.Count -eq 0) { return @('FAIL', 'no ExternalSecret in the cluster') }
    $bad = @()
    foreach ($e in $ess) {
        $c = Condition $e 'Ready'
        $status = if ($null -ne $c) { [string](Prop $c 'status') } else { '' }
        $reason = if ($null -ne $c) { [string](Prop $c 'reason') } else { '' }
        if (-not (Eq $status 'True') -or -not (Eq $reason 'SecretSynced')) { $bad += "$(Ns $e)/$(Name $e)=$status/$reason" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', "not SecretSynced: $($bad -join ', ')") }
    return @('PASS', "$($ess.Count) ExternalSecrets SecretSynced")
}
ClusterAssert 'eso-3' {
    $ess = @(Items (Get-KubeList @('get', 'externalsecrets.external-secrets.io', '-A')))
    if ($ess.Count -eq 0) { return @('FAIL', 'no ExternalSecret in the cluster') }
    $bad = @()
    foreach ($e in $ess) {
        $ns = Ns $e; $id = "$ns/$(Name $e)"
        $store = [string](PropPath $e @('spec', 'secretStoreRef', 'name')); $kind = [string](PropPath $e @('spec', 'secretStoreRef', 'kind'))
        if (-not (Eq $kind 'ClusterSecretStore')) { $bad += "${id}: secretStoreRef.kind='$kind'"; continue }
        $allowed = switch -CaseSensitive ($ns) {
            'jt-dev' { @('vault-dev', 'k8s-data-ca') }
            'jt-prod' { @('vault-prod', 'k8s-data-ca') }
            'data' { @('vault-data', 'vault-platform') }
            'identity' { @('vault-data', 'vault-platform', 'k8s-data-ca') }
            default { if (Contains $ns14 $ns) { @('vault-platform') } else { @() } }
        }
        if (-not (Contains $allowed $store)) { $bad += "${id}: store '$store' not allowed in ns $ns (allowed: $($allowed -join ','))"; continue }
        $keys = @()
        foreach ($d in @(PropArr $e @('spec', 'data'))) { $keys += [string](PropPath $d @('remoteRef', 'key')) }
        foreach ($d in @(PropArr $e @('spec', 'dataFrom'))) { $keys += [string](PropPath $d @('extract', 'key')) }
        if ($keys.Count -eq 0) { $bad += "${id}: no remoteRef keys"; continue }
        foreach ($key in $keys) {
            $want = if (Eq $store 'k8s-data-ca') { if (Contains $caMirrorKeys $key) { @('k8s-data-ca') } else { @() } }
            elseif (StartsOrd $key 'dev/') { @('vault-dev', 'vault-data') }
            elseif (StartsOrd $key 'prod/') { @('vault-prod', 'vault-data') }
            elseif (StartsOrd $key 'platform/') { @('vault-platform') }
            else { @() }
            if (-not (Contains $want $store)) { $bad += "${id}: key '$key' vs store '$store'" }
        }
    }
    if ($bad.Count -gt 0) { return @('FAIL', "store/scope mismatch: $($bad -join '; ')") }
    return @('PASS', "$($ess.Count) ExternalSecrets: secretStoreRef matches namespace scope and key prefix")
}
ClusterAssert 'ca-1' {
    $nsList = @('identity', 'jt-dev', 'jt-prod')
    $present = @(); $missing = @(); $bad = @()
    foreach ($ns in $nsList) {
        $r = Invoke-Kubectl @('auth', 'can-i', 'get', 'secrets', '-n', $ns)
        $canI = Eq $r.out.Trim() 'yes'
        if ($canI) {
            $sec = Get-KubeOne $ns 'secrets' 'pg-main-ca'
            if ($null -eq $sec) { $missing += $ns; continue }
            $present += $ns
            $keys = @(SortOrd (PropNames (Prop $sec 'data')))
            if (-not (SetEq $keys @('ca.crt'))) { $bad += "${ns}: secret keys [$($keys -join ',')] (ca.key must be absent)" }
        } else {
            # agent-view는 Secret get이 없다 — 같은 이름의 ExternalSecret spec으로 증명(dataFrom 없음·property/secretKey=ca.crt·template 키 없음)
            $es = Get-KubeOne $ns 'externalsecrets.external-secrets.io' 'pg-main-ca'
            if ($null -eq $es) { $missing += $ns; continue }
            $present += $ns
            if (@(PropArr $es @('spec', 'dataFrom')).Count -gt 0) { $bad += "${ns}: ExternalSecret uses dataFrom (would mirror ca.key)" }
            $data = @(PropArr $es @('spec', 'data'))
            if ($data.Count -eq 0) { $bad += "${ns}: ExternalSecret has no data entries" }
            foreach ($d in $data) {
                $sk = [string](Prop $d 'secretKey'); $prop = [string](PropPath $d @('remoteRef', 'property')); $key = [string](PropPath $d @('remoteRef', 'key'))
                if (-not (Eq $sk 'ca.crt') -or -not (Eq $prop 'ca.crt') -or -not (Contains $caMirrorKeys $key)) { $bad += "${ns}: data entry secretKey='$sk' property='$prop' key='$key'" }
            }
            $tmplKeys = @(PropNames (PropPath $es @('spec', 'target', 'template', 'data')))
            foreach ($tk in $tmplKeys) { if (-not (Eq $tk 'ca.crt')) { $bad += "${ns}: template adds key '$tk'" } }
            if (@(PropArr $es @('spec', 'target', 'template', 'templateFrom')).Count -gt 0) { $bad += "${ns}: template uses templateFrom (could inject keys)" }
            if ($null -ne (PropPath $es @('spec', 'target', 'template', 'mergePolicy'))) { $bad += "${ns}: template sets mergePolicy (must be unused)" }
            if (-not (Eq ([string](PropPath $es @('spec', 'secretStoreRef', 'name'))) 'k8s-data-ca')) { $bad += "${ns}: store is not k8s-data-ca" }
        }
    }
    if ($present.Count -eq 0) { return @('SKIP', 'until T056 (CA mirror pg-main-ca not present in identity/jt-dev/jt-prod)') }
    if ($missing.Count -gt 0) { $bad += "missing in ns: $($missing -join ', ')" }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', "pg-main-ca mirror keys == [ca.crt] in $($present -join ', ') (no ca.key)")
}

# ---------- 5. 네임스페이스 · PSA ----------
ClusterAssert 'ns-1' {
    $names = @(Get-Namespaces | ForEach-Object { Name $_ })
    $missing = @(Except $ns14 $names)
    if ($missing.Count -gt 0) { return @('FAIL', "missing namespaces: $($missing -join ', ')") }
    return @('PASS', 'all 14 contract namespaces exist')
}
ClusterAssert 'ns-2' {
    $names = @(Get-Namespaces | ForEach-Object { Name $_ })
    if (Contains $names 'observability') { return @('FAIL', 'namespace observability exists (contract: monitoring only)') }
    return @('PASS', 'no observability namespace')
}
ClusterAssert 'psa-1' {
    $nss = @(Get-Namespaces); $bad = @()
    foreach ($n in $ns14) {
        $obj = $nss | Where-Object { Eq (Name $_) $n } | Select-Object -First 1
        if ($null -eq $obj) { $bad += "${n}: missing"; continue }
        $v = Label $obj 'pod-security.kubernetes.io/enforce'
        if (-not (Eq $v ([string]$nsPsa[$n]))) { $bad += "${n}: enforce='$v' (expected $($nsPsa[$n]))" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'PSA enforce labels match the contract table (14 ns incl. kube-system)')
}
ClusterAssert 'psa-2' {
    $nss = @(Get-Namespaces); $bad = @()
    foreach ($n in $ns14) {
        $obj = $nss | Where-Object { Eq (Name $_) $n } | Select-Object -First 1
        if ($null -eq $obj) { $bad += "${n}: missing"; continue }
        foreach ($mode in @('warn', 'audit')) {
            $v = Label $obj "pod-security.kubernetes.io/$mode"
            if (-not (Eq $v ([string]$nsPsa[$n]))) { $bad += "${n}: $mode='$v' (expected $($nsPsa[$n]))" }
        }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'PSA warn/audit labels equal enforce level in all 14 ns')
}

# ---------- 6. NetworkPolicy 정책 세트 ----------
function Get-NsWithPolicy([string]$name) { return @(Get-NetworkPolicies | Where-Object { Eq (Name $_) $name } | ForEach-Object { Ns $_ }) }
ClusterAssert 'np-set-1' {
    $have = @(Get-NsWithPolicy 'default-deny'); $missing = @(Except $ns13 $have); $bad = @()
    if ($missing.Count -gt 0) { $bad += "missing in: $($missing -join ', ')" }
    foreach ($ns in @(Except $ns13 $missing)) {
        $p = Get-Policy $ns 'default-deny'
        $types = @(PropArr $p @('spec', 'policyTypes'))
        $selKeys = @(PropNames (PropPath $p @('spec', 'podSelector')))
        if (-not (SetEq $types @('Ingress', 'Egress')) -or $selKeys.Count -gt 0 -or @(PropArr $p @('spec', 'ingress')).Count -gt 0 -or @(PropArr $p @('spec', 'egress')).Count -gt 0) { $bad += "${ns}: default-deny shape (policyTypes/podSelector/rules)" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'default-deny (Ingress+Egress, podSelector {}, no rules) in the 13 non-kube-system ns')
}
ClusterAssert 'np-set-2' {
    $have = @(Get-NsWithPolicy 'allow-dns'); $missing = @(Except $ns13 $have); $bad = @()
    if ($missing.Count -gt 0) { $bad += "missing in: $($missing -join ', ')" }
    foreach ($ns in @(Except $ns13 $missing)) {
        $p = Get-Policy $ns 'allow-dns'
        $udp = $false; $tcp = $false; $sel = $false
        foreach ($rule in @(PropArr $p @('spec', 'egress'))) {
            foreach ($peer in @(PropArr $rule @('to'))) {
                # 도착 = kube-system ns 셀렉터 + kube-dns pod 셀렉터(둘 다 한 peer 안에)
                $nsName = [string](PropPath $peer @('namespaceSelector', 'matchLabels', 'kubernetes.io/metadata.name'))
                $app = [string](PropPath $peer @('podSelector', 'matchLabels', 'k8s-app'))
                if ((Eq $nsName 'kube-system') -and (Eq $app 'kube-dns')) { $sel = $true }
            }
            foreach ($port in @(PropArr $rule @('ports'))) {
                if (Eq "$(Prop $port 'port')" '53') { if (Eq ([string](Prop $port 'protocol')) 'UDP') { $udp = $true }; if (Eq ([string](Prop $port 'protocol')) 'TCP') { $tcp = $true } }
            }
        }
        if (-not $sel) { $bad += "${ns}: allow-dns egress 'to' lacks namespaceSelector kubernetes.io/metadata.name=kube-system + podSelector k8s-app=kube-dns" }
        if (-not ($udp -and $tcp)) { $bad += "${ns}: allow-dns egress ports must include 53/UDP and 53/TCP" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'allow-dns (egress to kube-system/k8s-app=kube-dns, 53/UDP+TCP) in the 13 non-kube-system ns')
}
ClusterAssert 'np-set-3' {
    $have = @(Get-NsWithPolicy 'allow-same-namespace')
    if (SetEq $have $sameNs7) { return @('PASS', 'allow-same-namespace in exactly the 7 contract ns') }
    return @('FAIL', "allow-same-namespace in [$((SortOrd $have) -join ', ')], expected exactly [$((SortOrd $sameNs7) -join ', ')]")
}
ClusterAssert 'np-set-4' {
    $have = @(Get-NsWithPolicy 'allow-kube-api')
    if (-not (SetEq $have $kubeApi10)) { return @('FAIL', "allow-kube-api in [$((SortOrd $have) -join ', ')], expected exactly [$((SortOrd $kubeApi10) -join ', ')]") }
    $bad = @()
    foreach ($ns in $kubeApi10) {
        $p = Get-Policy $ns 'allow-kube-api'; $ok = $false
        foreach ($rule in @(PropArr $p @('spec', 'egress'))) {
            $has6443 = @(PropArr $rule @('ports') | Where-Object { Eq "$(Prop $_ 'port')" '6443' }).Count -gt 0
            $has32 = @(PropArr $rule @('to') | Where-Object { EndsOrd ([string](PropPath $_ @('ipBlock', 'cidr'))) '/32' }).Count -gt 0
            if ($has6443 -and $has32) { $ok = $true }
        }
        if (-not $ok) { $bad += "${ns}: no egress rule to <node A>/32 :6443" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'allow-kube-api (egress <node A>/32:6443) in exactly the 10 contract ns')
}
ClusterAssert 'np-set-5' {
    $have = @(Get-NsWithPolicy 'allow-apiserver-webhook'); $want = @($webhook4.Keys | ForEach-Object { "$_" })
    if (-not (SetEq $have $want)) { return @('FAIL', "allow-apiserver-webhook in [$((SortOrd $have) -join ', ')], expected exactly [$((SortOrd $want) -join ', ')]") }
    $bad = @()
    foreach ($ns in $want) {
        $p = Get-Policy $ns 'allow-apiserver-webhook'; $ok = $false; $port = "$($webhook4[$ns])"
        foreach ($rule in @(PropArr $p @('spec', 'ingress'))) {
            $hasPort = @(PropArr $rule @('ports') | Where-Object { Eq "$(Prop $_ 'port')" $port }).Count -gt 0
            $has32 = @(PropArr $rule @('from') | Where-Object { EndsOrd ([string](PropPath $_ @('ipBlock', 'cidr'))) '/32' }).Count -gt 0
            if ($hasPort -and $has32) { $ok = $true }
        }
        if (-not $ok) { $bad += "${ns}: no ingress rule from <node A>/32 :$port" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'allow-apiserver-webhook (ingress <node A>/32, ports 10250/10250/9443/8200) in exactly the 4 contract ns')
}
ClusterAssert 'np-cond-1' {
    $have = @(Get-NsWithPolicy 'deny-imds')
    if (SetEq $have @('kube-system')) { return @('PASS', 'deny-imds exists in kube-system only') }
    return @('FAIL', "deny-imds in [$((SortOrd $have) -join ', ')], expected exactly [kube-system]")
}
ClusterAssert 'np-cond-2' {
    $have = @(Get-NsWithPolicy 'allow-imds')
    if (-not (SetEq $have @('vault'))) { return @('FAIL', "allow-imds in [$((SortOrd $have) -join ', ')], expected exactly [vault]") }
    $p = Get-Policy 'vault' 'allow-imds'; $ok = $false
    foreach ($rule in @(PropArr $p @('spec', 'egress'))) {
        $has80 = @(PropArr $rule @('ports') | Where-Object { Eq "$(Prop $_ 'port')" '80' }).Count -gt 0
        $hasImds = @(PropArr $rule @('to') | Where-Object { Eq ([string](PropPath $_ @('ipBlock', 'cidr'))) "$imdsIp/32" }).Count -gt 0
        if ($has80 -and $hasImds) { $ok = $true }
    }
    if (-not $ok) { return @('FAIL', "vault/allow-imds lacks egress to $imdsIp/32 :80") }
    return @('PASS', "allow-imds exists in vault only (egress $imdsIp/32:80)")
}

# ---------- 7. NetworkPolicy 양방향 단언 7항목(계약 §검증) ----------
ClusterAssert 'np-1' {
    $have = @(Get-PolicyNamesIn 'kube-system')
    if (SetEq $have @('deny-imds')) { return @('PASS', 'kube-system policies == {deny-imds} (PSA label checked in psa-1)') }
    return @('FAIL', "kube-system policies are [$((SortOrd $have) -join ', ')], expected exactly [deny-imds]")
}
foreach ($job in $assertJobs) {
    # 본문은 루프 안에서 즉시 실행되므로 $job은 동적 스코프로 보인다(클로저 불필요)
    ClusterAssert "np-2-$job" {
        $j = Get-KubeOne 'jt-dev' 'jobs.batch' $job
        if ($null -eq $j) { return @('SKIP', "until T041 (assert Job jt-dev/$job from platform/policies/tests not present)") }
        $succeeded = PropPath $j @('status', 'succeeded')
        if ($null -eq $succeeded -or [int]$succeeded -lt 1) { return @('FAIL', "Job jt-dev/$job has not succeeded (status.succeeded='$succeeded')") }
        $r = Invoke-Kubectl @('-n', 'jt-dev', 'logs', "job/$job", '--tail=50')
        if ($r.code -ne 0) { return @('FAIL', "kubectl logs job/$job failed (exit $($r.code)): $($r.err)") }
        if ([string]::IsNullOrWhiteSpace($r.out)) { return @('FAIL', "Job jt-dev/$job logs are empty") }
        return @('PASS', "Job jt-dev/$job succeeded and logs readable — proves only $($assertJobScope[$job])")
    }
}
Skip 'np-2-manual' '운영자 수동 — assert Job이 증명하지 못하는 매트릭스 행: jt-dev → identity 9000(Authentik JWKS/revoke) · jt-dev·jt-prod → monitoring 4317·4318(OTLP) · jt-prod 출발 행 전부(data 5432·9093·6379, identity 9000·8080, monitoring 4317·4318) · kube-system(traefik) → argocd 8080/vault 8200/identity 9000/jt-dev·jt-prod 8000/monitoring 4317 · identity → data 5432, jt-dev 8000, jt-prod 8000 · external-secrets → vault 8200 · monitoring → scrape 대상(argocd 8082-8084, vault 8200, external-secrets 8080, cert-manager 9402, cnpg-system 8080, data 9187·9404, jt-* 9100·9464). ns 내부 출발 프로브 필요(agent-view에 exec·pod 생성 권한 없음), 명령 출력을 report에 첨부'
ClusterAssert 'np-3' {
    $bad = @()
    foreach ($pair in @(@('jt-prod', 'jt-dev'), @('jt-dev', 'data'))) {
        $target = $pair[0]; $src = $pair[1]
        $ev = Get-IngressSources $target
        if ($ev.unevaluable.Count -gt 0) { $bad += "${target}: unevaluable selector(s): $($ev.unevaluable -join '; ')"; continue }
        if ($ev.anyAll) { $bad += "${target}: an ingress rule admits any source (or default-deny missing)"; continue }
        if (Contains $ev.sources $src) { $bad += "${target}: ingress admits $src" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', 'static: jt-prod ingress does not admit jt-dev; jt-dev ingress does not admit data')
}
Skip 'np-3-live' '운영자 수동 — jt-dev pod → jt-prod svc, data pod → jt-dev svc 연결 실패를 실제 프로브로 확인(출력을 report에 첨부)'
ClusterAssert 'np-4' {
    $ev = Get-IngressSources 'vault'
    if ($ev.unevaluable.Count -gt 0) { return @('FAIL', "vault: unevaluable selector(s): $($ev.unevaluable -join '; ')") }
    if ($ev.anyAll) { return @('FAIL', 'vault: an ingress rule admits any source (or default-deny missing)') }
    $extra = @(Except $ev.sources $vaultIngressNs)
    if ($extra.Count -gt 0) { return @('FAIL', "vault ingress admits non-matrix ns: $($extra -join ', ')") }
    return @('PASS', "static: vault ingress sources [$($ev.sources -join ', ')] are within {$($vaultIngressNs -join ', ')} (node A ipBlock aside)")
}
Skip 'np-4-live' '운영자 수동 — monitoring 아닌 ns(예: jt-dev) pod에서 vault.vault.svc:8200 연결 거부를 실제 프로브로 확인'
ClusterAssert 'np-5' {
    # 공허 PASS 방지: 매트릭스 행 jt-dev -> 외부 443(0.0.0.0/0 + except 4 + ports 443/TCP) 규칙이 1개 이상 있어야 한다.
    # 추가로 jt-dev의 어떤 ipBlock도 RFC1918 대역을 cidr 자체로 쓰지 않는다(except 우회 금지; jt-dev는 allow-kube-api 대상이 아니다).
    $bad = @(); $checked = 0; $external443 = 0
    foreach ($pol in @(Get-PoliciesIn 'jt-dev')) {
        if (-not (Test-PolicyType $pol 'Egress')) { continue }
        foreach ($rule in @(PropArr $pol @('spec', 'egress'))) {
            $to = @(PropArr $rule @('to'))
            if ($to.Count -eq 0) { $bad += "$(Name $pol): egress rule without 'to' (allows everything)"; continue }
            $ports = @(PropArr $rule @('ports'))
            $has443 = @($ports | Where-Object { (Eq "$(Prop $_ 'port')" '443') -and (($null -eq (Prop $_ 'protocol')) -or (Eq ([string](Prop $_ 'protocol')) 'TCP')) }).Count -gt 0
            foreach ($peer in $to) {
                $ib = Prop $peer 'ipBlock'
                if ($null -eq $ib) { continue }
                $checked++
                $cidr = [string](Prop $ib 'cidr')
                if ($ports.Count -eq 0) { $bad += "$(Name $pol): ipBlock '$cidr' rule without ports" }
                if (Eq $cidr '0.0.0.0/0') {
                    $missing = @(Except $except4 @(PropArr $ib @('except')))
                    if ($missing.Count -gt 0) { $bad += "$(Name $pol): 0.0.0.0/0 rule missing except $($missing -join ', ')" }
                    elseif ($has443 -and $ports.Count -gt 0) { $external443++ }
                } else {
                    $netIp = ($cidr.Split('/'))[0]
                    foreach ($priv in @('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')) {
                        $in = Test-CidrContains $priv $netIp
                        if ($null -eq $in) { $bad += "$(Name $pol): unevaluable ipBlock '$cidr'"; break }
                        if ($in) { $bad += "$(Name $pol): ipBlock '$cidr' allows RFC1918 range $priv"; break }
                    }
                }
            }
        }
    }
    if ($external443 -eq 0) { $bad += 'no jt-dev egress rule 0.0.0.0/0 (with the 4 except entries) and ports 443/TCP (matrix row jt-dev -> external 443 missing)' }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', "static: $checked jt-dev egress ipBlock rule(s) carry ports; $external443 external-443 rule(s) carry the 4 except entries; no RFC1918 cidr rule")
}
Skip 'np-5-live' '운영자 수동 — jt-dev pod에서 1.1.1.1:443 연결 실패를 실제 프로브로 확인(외부 443 규칙의 except·ports 범위)'
ClusterAssert 'np-6' {
    $bad = @()
    foreach ($ns in @(Except $ns13 @('vault'))) {
        foreach ($pol in @(Get-PoliciesIn $ns)) {
            if (-not (Test-PolicyType $pol 'Egress')) { continue }
            foreach ($rule in @(PropArr $pol @('spec', 'egress'))) {
                $to = @(PropArr $rule @('to'))
                if ($to.Count -eq 0) { $bad += "$ns/$(Name $pol): egress rule without 'to' (reaches IMDS)"; continue }
                foreach ($peer in $to) {
                    $ib = Prop $peer 'ipBlock'
                    if ($null -eq $ib) { continue }
                    $allows = Test-IpBlockAllows $ib $imdsIp
                    if ($null -eq $allows) { $bad += "$ns/$(Name $pol): unevaluable ipBlock '$(Prop $ib 'cidr')'" }
                    elseif ($allows) { $bad += "$ns/$(Name $pol): ipBlock '$(Prop $ib 'cidr')' allows $imdsIp" }
                }
            }
        }
    }
    $deny = Get-Policy 'kube-system' 'deny-imds'
    if ($null -eq $deny) { $bad += 'kube-system/deny-imds missing' }
    else {
        $ok = $false
        foreach ($rule in @(PropArr $deny @('spec', 'egress'))) {
            foreach ($peer in @(PropArr $rule @('to'))) {
                $ib = Prop $peer 'ipBlock'
                if ($null -ne $ib -and (Eq ([string](Prop $ib 'cidr')) '0.0.0.0/0') -and (Test-IpBlockAllows $ib $imdsIp) -eq $false) { $ok = $true }
            }
        }
        if (-not $ok) { $bad += "kube-system/deny-imds: no egress 0.0.0.0/0 rule with except covering $imdsIp" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', "static: no egress rule outside vault allows $imdsIp; kube-system deny-imds excepts IMDS (allow-imds vault-only in np-cond-2)")
}
Skip 'np-6-live' '운영자 수동 — vault pod에서만 169.254.169.254:80 도달, 다른 ns pod에서는 실패를 실제 프로브로 확인'
ClusterAssert 'np-7' {
    $events = @(Items (Get-KubeList @('get', 'events', '-A')))
    $viol = @($events | Where-Object { (IndexOrd ([string](Prop $_ 'message')) 'violates PodSecurity') -ge 0 })
    if ($viol.Count -gt 0) {
        $sample = @($viol | Select-Object -First 3 | ForEach-Object { "$(Ns $_)/$(PropPath $_ @('involvedObject', 'name'))" })
        return @('FAIL', "$($viol.Count) PSA violation event(s) (e.g. $($sample -join ', '))")
    }
    return @('PASS', "0 PSA violation events across $($events.Count) events (K3s event TTL 1h — meaningful only when run within 1h of deployment)")
}

# ---------- 8. monitoring scrape 도달 ----------
ClusterAssert 'mon-1' {
    # T098 실제 형상은 StatefulSet k8s-monitoring-alloy-metrics(k8s-monitoring 차트) — 종류를 고정하지 않고 ns monitoring의
    # DaemonSet/StatefulSet/Deployment 중 이름이 alloy-metrics로 끝나거나 라벨 app.kubernetes.io/name=alloy-metrics인 워크로드를 전부 찾아
    # 각각 logs --tail=300 --all-containers(config-reloader 사이드카 포함)로 읽는다. 워크로드 0개일 때만 SKIP.
    $kindRef = [ordered]@{ 'daemonsets.apps' = 'daemonset'; 'statefulsets.apps' = 'statefulset'; 'deployments.apps' = 'deployment' }
    $found = @()
    foreach ($k in @($kindRef.Keys | ForEach-Object { "$_" })) {
        foreach ($w in @(Items (Get-KubeList @('get', $k, '-n', 'monitoring')))) {
            if ((EndsOrd (Name $w) 'alloy-metrics') -or (Eq (Label $w 'app.kubernetes.io/name') 'alloy-metrics')) { $found += "$($kindRef[$k])/$(Name $w)" }
        }
    }
    if ($found.Count -eq 0) { return @('SKIP', 'until T098 (no alloy-metrics DaemonSet/StatefulSet/Deployment in ns monitoring)') }
    $rx = [regex]::new('connection refused|context deadline exceeded', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::CultureInvariant)
    $hits = @(); $total = 0
    foreach ($ref in $found) {
        $r = Invoke-Kubectl @('-n', 'monitoring', 'logs', $ref, '--tail=300', '--all-containers')
        if ($r.code -ne 0) { return @('FAIL', "kubectl logs $ref failed (exit $($r.code)): $($r.err)") }
        $lines = @($r.out -split "`n"); $total += $lines.Count
        $hits += @($lines | Where-Object { $rx.IsMatch($_) })
    }
    if ($hits.Count -gt 0) { return @('FAIL', "$($hits.Count) scrape error line(s) in last 300 of $($found -join ', '): $(Clip $hits[0] 160)") }
    return @('PASS', "0 'connection refused'/'context deadline exceeded' lines in $($found -join ', ') --tail=300 --all-containers ($total lines)")
}

# ---------- 9. jt-dev·jt-prod pod 리소스 limit ----------
function Get-RunningAppPods {
    $pods = @()
    foreach ($ns in @('jt-dev', 'jt-prod')) { $pods += @(Items (Get-KubeList @('get', 'pods', '-n', $ns, '--field-selector=status.phase=Running'))) }
    return @($pods)
}
ClusterAssert 'limits-1' {
    $pods = @(Get-RunningAppPods)
    if ($pods.Count -eq 0) { return @('SKIP', 'until T075 (no Running pod in jt-dev/jt-prod)') }
    $bad = @()
    foreach ($p in $pods) { foreach ($c in @(PropArr $p @('spec', 'containers'))) {
            if ($null -ne (PropPath $c @('resources', 'limits', 'cpu'))) { $bad += "$(Ns $p)/$(Name $p):$(Prop $c 'name')" } } }
    if ($bad.Count -gt 0) { return @('FAIL', "containers with limits.cpu (LimitRange must not set default.cpu/max.cpu): $($bad -join ', ')") }
    return @('PASS', "no limits.cpu on $($pods.Count) Running pod(s) in jt-dev/jt-prod")
}
ClusterAssert 'limits-2' {
    $pods = @(Get-RunningAppPods)
    if ($pods.Count -eq 0) { return @('SKIP', 'until T075 (no Running pod in jt-dev/jt-prod)') }
    $bad = @()
    foreach ($p in $pods) { foreach ($c in @(PropArr $p @('spec', 'containers'))) {
            if ($null -eq (PropPath $c @('resources', 'limits', 'memory'))) { $bad += "$(Ns $p)/$(Name $p):$(Prop $c 'name')" } } }
    if ($bad.Count -gt 0) { return @('FAIL', "containers without limits.memory: $($bad -join ', ')") }
    return @('PASS', "limits.memory present on every container of $($pods.Count) Running pod(s)")
}

# ---------- 10. Reloader ----------
ClusterAssert 'reloader-1' {
    $d = Get-KubeOne 'reloader' 'deployments.apps' 'reloader'
    if ($null -eq $d) { return @('FAIL', 'deployment reloader (ns reloader) not found') }
    $c = Condition $d 'Available'
    $ready = PropPath $d @('status', 'readyReplicas')
    if ($null -ne $c -and (Eq ([string](Prop $c 'status')) 'True') -and $null -ne $ready -and [int]$ready -ge 1) { return @('PASS', "deployment reloader Available (readyReplicas=$ready)") }
    return @('FAIL', "deployment reloader not Available (readyReplicas='$ready')")
}

# ---------- 11. OCI 백업 오브젝트(svc-verify 읽기 전용) ----------
$script:ociObjects = @{}   # prefix -> @{ ok; objects; error }
function Get-BackupObjects([string]$prefix) {
    if ($script:ociObjects.ContainsKey($prefix)) { return $script:ociObjects[$prefix] }
    $res = @{ ok = $false; objects = @(); error = '' }
    $oci = Get-Command oci -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $oci) { $res.error = 'oci CLI not found on PATH'; $script:ociObjects[$prefix] = $res; return $res }
    $auth = if ([string]::IsNullOrWhiteSpace($env:OCI_CLI_AUTH)) { @('--auth', 'security_token') } else { @() }
    $r = Invoke-Oci (@($oci)[0].Source) (@('--profile', $ociProfile) + $auth + @('os', 'object', 'list', '--bucket-name', $backupBucket, '--prefix', $prefix, '--all', '--fields', 'name,size,timeCreated', '--output', 'json'))
    if ($r.code -ne 0) { $res.error = "oci os object list --prefix $prefix failed (exit $($r.code)): $(Clip (($r.out + ' ' + $r.err).Trim()) 240)"; $script:ociObjects[$prefix] = $res; return $res }
    try { $obj = ConvertFrom-JsonStrict $r.out "oci os object list --prefix $prefix" } catch { $res.error = $_.Exception.Message; $script:ociObjects[$prefix] = $res; return $res }
    $res.objects = @(PropArr $obj @('data')); $res.ok = $true
    $script:ociObjects[$prefix] = $res
    return $res
}
function Test-RecentAge([string]$prefix) {
    $res = Get-BackupObjects $prefix
    if (-not $res.ok) { return @('FAIL', $res.error) }
    $now = [DateTimeOffset]::UtcNow; $recent = 0; $ageCount = 0
    foreach ($o in $res.objects) {
        $name = [string](Prop $o 'name')
        if (-not (EndsOrd $name '.age')) { continue }
        $ageCount++
        $t = $null
        try { $t = [DateTimeOffset]::Parse([string](Prop $o 'time-created'), [Globalization.CultureInfo]::InvariantCulture) } catch { continue }
        if (($now - $t) -le [TimeSpan]::FromHours(24)) { $recent++ }
    }
    if ($recent -ge 1) { return @('PASS', "$backupBucket/$prefix has $recent .age object(s) within 24h ($ageCount .age total)") }
    return @('FAIL', "$backupBucket/$prefix has no .age object within 24h ($ageCount .age objects, $($res.objects.Count) total)")
}
$b1 = Test-RecentAge 'k3s/'
if (Eq $b1[0] 'PASS') { Pass 'backup-1' $b1[1] } else { Fail 'backup-1' $b1[1] }
$b2 = Test-RecentAge 'vault/'
if (Eq $b2[0] 'PASS') { Pass 'backup-2' $b2[1] } else { Fail 'backup-2' $b2[1] }
$plain = @(); $ociErr = @(); $total = 0
foreach ($prefix in @('k3s/', 'vault/')) {
    $res = Get-BackupObjects $prefix
    if (-not $res.ok) { $ociErr += $res.error; continue }
    foreach ($o in $res.objects) { $total++; $name = [string](Prop $o 'name'); if (-not (EndsOrd $name '.age')) { $plain += $name } }
}
if ($ociErr.Count -gt 0) { Fail 'backup-3' ($ociErr -join '; ') }
elseif ($total -eq 0) { Fail 'backup-3' "no objects under ${backupBucket}/k3s/ and vault/ (empty listing is not evidence)" }
elseif ($plain.Count -gt 0) { Fail 'backup-3' "plaintext (non-.age) object(s) in ${backupBucket}: $($plain -join ', ')" }
else { Pass 'backup-3' "0 non-.age objects under k3s/ and vault/ ($total objects, all .age)" }

# ---------- 요약 ----------
Write-Host ''
Write-Host "$script:pass passed, $script:fail failed, $script:skip skipped"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
