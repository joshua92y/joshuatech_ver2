# tests/platform/ingress.tests.ps1 — US2 인그레스·Cloudflare Access·오리진 보호·와일드카드 인증서 단언 (T032, test-first)
# Run: pwsh -NoProfile -File tests/platform/ingress.tests.ps1
#      (보통은 tests/platform/run-platform-tests.ps1이 KUBECONFIG·agent-view 신원 게이트를 지난 뒤 호출한다)
# Exit 0 = 실패 0, 1 = 실패 ≥ 1. 출력: `PASS|FAIL|SKIP <id>: … [-- 근거]` 줄, 마지막 줄 `N passed, N failed, N skipped`.
# 외부 프레임워크 없음(tests/infra/tofu.tests.ps1과 같은 구조). 자체 완결 — 공용 헬퍼·하위 디렉터리 없음(러너는 flat 발견만).
#
# 계약 요약(specs/003-platform-foundation: spec US2 시나리오 3, quickstart §US2, contracts/hostnames-and-access.md):
#   - 모든 호스트는 Cloudflare proxied + SSL Full(strict). argo·vault·traefik 호스트는 Access 앱(GitHub IdP) 뒤 →
#     비인증 요청은 edge에서 302 → https://<team>.cloudflareaccess.com/cdn-cgi/access/login/<host>… (팀 도메인 joshua-tech).
#   - 오리진 보호 3중: NSG(443 ← Cloudflare IPv4만) · Authenticated Origin Pulls(Traefik TLSOption RequireAndVerifyClientCert) ·
#     앱 계층 JWT. 노드 A 공인 IP로 직접 TLS를 열면 실패해야 한다(성공 = FAIL).
#   - 오리진 인증서 = cert-manager 와일드카드 *.joshuatech.dev 1장: kube-system Secret wildcard-joshuatech-dev-tls(Traefik TLSStore default).
#   - Traefik(K3s 번들, kube-system)은 노드 A(라벨 role=platform)에서만 돈다(공개 443은 노드 A NSG만 연다).
#
# 게이트/전제(전부 fail-closed — SKIP 경로 없음; 요약 형식 호환을 위해 skipped 수는 항상 0으로 출력):
#   - curl.exe가 PATH에 있어야 한다(HTTP 단언 4개). 리다이렉트는 따라가지 않는다(-I만, -L 없음).
#   - kubectl이 PATH에 있고 $env:KUBECONFIG가 존재하는 파일(agent-view 8h 토큰 kubeconfig)이어야 한다. 모든 kubectl 호출은
#     `--kubeconfig=<그 파일>`을 명시해 기본 ~/.kube/config로 절대 떨어지지 않는다. 동사는 get뿐(변경 동사 없음).
#     신원(agent-view) 게이트는 러너가 담당한다 — 직접 실행할 때도 agent-view kubeconfig만 쓴다. kubeconfig 경로·내용은 출력하지 않는다.
#   - 노드 A 공인 IP는 파일 상단 상수($NodeAPublicIp)다. 출처: infra/oci output node_a_reserved_public_ip(T009 적용 2026-09-03,
#     docs/runbooks/bootstrap.md). 여기서 tofu output을 부르지 않는다(자격 필요). node-1이 kubelet의 ExternalIP(보고될 때)와 대조해
#     상수 표류를 잡는다 — 표류면 aop-1이 엉뚱한 IP를 두드리게 되므로 FAIL이고, platform 노드 집합도 확정하지 않으므로
#     traefik-2("platform node set unknown")·aop-1(전제 미충족)도 함께 FAIL한다.
#   - HTTP 302 단언은 edge(Access)에서 응답하므로 오리진·Ingress 없이도 통과할 수 있다(2026-09-04 실측: T011 Access 앱만으로 302).
#     Location은 팀 도메인 joshua-tech.cloudflareaccess.com(호스트 정확 일치, OrdinalIgnoreCase) + 경로 /cdn-cgi/access/login/ 접두여야 한다.
#     그래서 argo-2·vault-2가 Ingress(networking.k8s.io) 리소스 존재를 kubectl로 따로 요구한다(T044 전 vault-2는 FAIL이 정상 — SKIP 아님).
#     traefik 대시보드는 IngressRoute(api@internal)라 agent-view(view + agent-view-extra)로 읽을 수 없어 HTTP 단언(traefik-1)만 둔다.
#   - aop-1(직접 TLS 거부)은 traefik-2(Traefik Running on role=platform)·node-1이 통과했을 때만 증거로 인정한다 — 아무것도 없는
#     IP가 응답하지 않는 것은 AOP 증거가 아니다(fail closed). 운영자 PC는 Cloudflare 대역 밖이라 NSG 계층에서 먼저 막힐 수 있으며
#     (curl 28 timeout), 그 경우도 "직접 접속 거부"로 PASS하되 근거에 계층을 적는다. HTTP 상태가 하나라도 오면 FAIL.
#     "거부"로 인정하는 curl 종료 코드는 화이트리스트 7·28·35·52·55·56뿐이다 — 그 외(-1 실행 실패, 2 사용법, 3 URL, 6 DNS, 8 이상 응답 등)는
#     거부가 아니라 도구/호출 오류이므로 "unexpected curl exit N (not a refusal)"로 FAIL한다(공허한 PASS 방지).
#   - cert-1/cert-2: Secret 값은 읽지 않는다(계약 §에이전트 자격: agent-view는 Secret get이 없다 — contracts/hostnames-and-access.md).
#     대신 cert-manager Certificate(kube-system, spec.secretName = wildcard-joshuatech-dev-tls 정확히 1개)의 Ready=True·status.notAfter로
#     판정한다(cert-manager는 Secret이 있고 유효할 때만 Ready=True). cert-manager 차트 기본 `global.rbac.aggregateClusterRoles=true`로
#     `view`에 집계된 certificates get/list에 의존한다(T042가 값을 명시). cert-2는 남은 기간이 30일을 **초과**해야 한다(TotalDays > 30,
#     내림 없음). 근거에는 Certificate 이름·notAfter·남은 일수만 적는다.
#   - 문자열 판정은 전부 ordinal([string]::Equals/EndsWith/IndexOf + StringComparison; 호스트명만 OrdinalIgnoreCase).
#
# 단언 ↔ T032 항목:
#   tool-1/2   전제(curl.exe / kubectl + KUBECONFIG 파일)
#   argo-1/2   https://argo.joshuatech.dev → 302 Access 로그인 / Ingress rules[].host 존재
#   vault-1/2  https://vault.joshuatech.dev → 302 Access 로그인 / Ingress rules[].host 존재(T044)
#   traefik-1  traefik.joshuatech.dev 대시보드 Access 뒤(302)
#   node-1     role=platform 노드 존재 + ExternalIP(보고 시) = 상수
#   traefik-2  Traefik pod Running, 전부 role=platform 노드에 스케줄
#   aop-1      curl --resolve <노드 A IP> 직접 TLS 핸드셰이크 실패(성공하면 FAIL)
#   cert-1/2   kube-system/wildcard-joshuatech-dev-tls 존재(Certificate Ready=True로 판정) / 만료까지 30일 초과
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다 — $LASTEXITCODE로 판정

# ---------- 상수(계약값) ----------
$Zone = 'joshuatech.dev'
$ArgoHost = "argo.$Zone"
$VaultHost = "vault.$Zone"
$TraefikHost = "traefik.$Zone"
$AccessLoginHost = 'joshua-tech.cloudflareaccess.com'   # Cloudflare Zero Trust 팀 도메인(계약) — Location 호스트 정확 일치
$AccessLoginPathPrefix = '/cdn-cgi/access/login/'        # Access 로그인 경로 접두 — Location 경로 StartsWith(Ordinal)
# 노드 A reserved 공인 IP — 출처: infra/oci output node_a_reserved_public_ip (T009 적용 2026-09-03). tofu output 호출 없음(자격 필요).
# 값이 바뀌면 이 상수를 갱신한다(node-1이 kubelet ExternalIP와 대조해 표류를 FAIL로 드러낸다).
$NodeAPublicIp = '144.24.85.118'
$PlatformNodeSelector = 'role=platform'
$TraefikNamespace = 'kube-system'                  # K3s 번들 Traefik
$TraefikPodSelector = 'app.kubernetes.io/name=traefik'
$WildcardSecretNamespace = 'kube-system'
$WildcardSecretName = 'wildcard-joshuatech-dev-tls'
$MinCertDaysLeft = 30
$HttpTimeoutSec = 20
$KubectlRequestTimeout = '30s'

# ---------- 집계·헬퍼 ----------
$script:pass = 0
$script:fail = 0
$script:skip = 0   # 이 스위트에 SKIP 경로는 없다(전부 fail-closed) — 요약 형식 호환용

function Clip([string]$s, [int]$max = 400) {
    if ($null -eq $s) { return '' }
    $s = ($s -replace "`r`n", ' ') -replace "`n", ' '
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' } else { return $s }
}

# PASS에도 근거(detail)를 남긴다 — tester 보고서가 그대로 인용할 수 있게.
function Assert([string]$id, [bool]$cond, [string]$detail) {
    $suffix = if ([string]::IsNullOrEmpty($detail)) { '' } else { " -- $(Clip $detail)" }
    if ($cond) { $script:pass++; Write-Host "PASS $id$suffix" }
    else { $script:fail++; Write-Host "FAIL $id$suffix" }
}

# 단언 그룹 격리 — 한 그룹의 예외가 나머지를 막지 않는다.
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Test-InSet([string]$value, [string[]]$set) {
    foreach ($s in @($set)) { if ([string]::Equals($s, $value, [StringComparison]::Ordinal)) { return $true } }
    return $false
}

# 네이티브 실행 — stdout은 콘솔 코드 페이지와 무관하게 UTF-8로 디코드(tests/infra/tofu.tests.ps1과 같은 방식), stderr는
# 임시 파일로 받아 문자열로 돌려준다. 실행 파일 부재 등 호출 자체의 실패는 code -1 + err 메시지(fail closed).
function Invoke-Native([string]$exe, [string[]]$nativeArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('ingress-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $out = @(); $code = -1; $err = ''
    $prevEncoding = [Console]::OutputEncoding
    try {
        try {
            [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            $out = & $exe @nativeArgs 2> $errFile
            $code = $LASTEXITCODE
        } catch { $err = "invoke failed: $($_.Exception.Message)"; $code = -1 }
        finally { [Console]::OutputEncoding = $prevEncoding }
        if ([string]::IsNullOrEmpty($err) -and (Test-Path -LiteralPath $errFile)) { $err = [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) }
    } finally { Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue }
    return @{ out = (@($out | ForEach-Object { "$_" }) -join "`n"); err = $err.Trim(); code = $code }
}

# HTTP HEAD 1회 — 리다이렉트를 따라가지 않는다(-L 없음). 상태 코드·Location 헤더만 파싱한다(첫 응답 블록).
function Invoke-CurlHead([string]$url, [string[]]$extraArgs) {
    $curlArgs = @('-s', '-S', '-I', '--max-time', "$HttpTimeoutSec", '--proto', '=https') + @($extraArgs) + @($url)
    $r = Invoke-Native 'curl.exe' $curlArgs
    $status = ''; $location = ''
    foreach ($line in ($r.out -split "`n")) {
        $t = $line.TrimEnd("`r")
        if ([string]::IsNullOrEmpty($status) -and $t -match '^HTTP/[0-9.]+\s+(\d{3})') { $status = $Matches[1]; continue }
        if ([string]::IsNullOrEmpty($location) -and $t -match '^Location:\s*(\S+)') { $location = $Matches[1] }   # -match는 대소문자 무시
    }
    return @{ code = $r.code; status = $status; location = $location; err = $r.err }
}

# Location이 https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/… 인지 판정(호스트 정확 일치 + 경로 접두).
# 반환 @(ok, 출력용 문자열) — 쿼리(meta 토큰)는 출력하지 않는다.
function Test-AccessLocation([string]$location) {
    $uri = $null
    try { $uri = [Uri]::new($location) } catch { return @($false, 'unparseable Location header') }
    if (-not $uri.IsAbsoluteUri) { return @($false, 'relative Location header') }
    $safe = "$($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)"
    $ok = [string]::Equals($uri.Scheme, 'https', [StringComparison]::Ordinal) -and
    [string]::Equals($uri.Host, $AccessLoginHost, [StringComparison]::OrdinalIgnoreCase) -and
    $uri.AbsolutePath.StartsWith($AccessLoginPathPrefix, [StringComparison]::Ordinal)
    return @($ok, $safe)
}

# 호스트 1개 → 302 + Access 로그인 Location 단언(리다이렉트 미추적, 상태 코드 ordinal 비교).
function Assert-AccessRedirect([string]$id, [string]$hostName) {
    if (-not $script:curlOk) { Assert $id $false 'curl.exe unavailable (tool-1)'; return }
    $r = Invoke-CurlHead "https://$hostName/" @()
    if ($r.code -ne 0) { Assert $id $false "curl exit=$($r.code) err=$($r.err)"; return }
    if (-not [string]::Equals($r.status, '302', [StringComparison]::Ordinal)) { Assert $id $false "status=[$($r.status)] (expected 302)"; return }
    if ([string]::IsNullOrEmpty($r.location)) { Assert $id $false 'status=302 but no Location header'; return }
    $t = Test-AccessLocation $r.location
    Assert $id ([bool]$t[0]) "status=302 Location=$($t[1])"
}

# ---------- kubectl(읽기 전용, get만) ----------
$script:kubeReady = $false
$script:kubeReason = 'tool-2 not evaluated'
$script:kubeconfigPath = $null

# stderr에 kubeconfig 경로가 섞여 나올 수 있으므로(kubectl 오류 문구) 근거로 쓰기 전에 <KUBECONFIG>로 가린다(ordinal Replace).
function Invoke-Kubectl([string[]]$kubectlArgs) {
    $r = Invoke-Native 'kubectl' (@("--kubeconfig=$script:kubeconfigPath", "--request-timeout=$KubectlRequestTimeout") + @($kubectlArgs))
    if (-not [string]::IsNullOrEmpty($script:kubeconfigPath) -and -not [string]::IsNullOrEmpty($r.err)) {
        $r.err = $r.err.Replace($script:kubeconfigPath, '<KUBECONFIG>', [StringComparison]::Ordinal)
    }
    return $r
}

# kubectl 의존 단언: 전제가 없으면 사유와 함께 FAIL(fail closed). $body는 @($cond, $detail) 2요소 배열을 돌려준다.
function KubeAssert([string]$id, [scriptblock]$body) {
    if (-not $script:kubeReady) { Assert $id $false "kubectl unavailable ($script:kubeReason)"; return }
    $ok = $false; $detail = ''
    try { $r = & $body; $ok = [bool]$r[0]; $detail = [string]$r[1] }
    catch { $ok = $false; $detail = "unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    Assert $id $ok $detail
}

# kubectl get … -o json → 객체. 실패·파싱 불가면 obj $null + 사유.
function Get-KubeJson([string[]]$getArgs) {
    $r = Invoke-Kubectl (@('get') + @($getArgs) + @('-o', 'json'))
    if ($r.code -ne 0) { return @{ obj = $null; reason = "kubectl get $($getArgs -join ' ') exit=$($r.code) err=$($r.err)" } }
    try { return @{ obj = ($r.out | ConvertFrom-Json); reason = '' } }
    catch { return @{ obj = $null; reason = "kubectl get $($getArgs -join ' ') output did not parse: $($_.Exception.Message)" } }
}

# Ingress 목록(-A JSON)에서 rules[].host가 hostName인 항목의 ns/name 목록.
function Get-IngressMatches($ingObj, [string]$hostName) {
    $found = @()
    foreach ($i in @($ingObj.items)) {
        if ($null -eq $i) { continue }
        foreach ($rule in @($i.spec.rules)) {
            if ($null -ne $rule -and [string]::Equals("$($rule.host)", $hostName, [StringComparison]::OrdinalIgnoreCase)) {
                $found += "$($i.metadata.namespace)/$($i.metadata.name)"; break
            }
        }
    }
    return , $found
}

# ---------- tool: 전제 ----------
$script:curlOk = $false
Test-Group 'tool' {
    $script:curlOk = $null -ne (Get-Command 'curl.exe' -ErrorAction SilentlyContinue)
    Assert 'tool-1: curl.exe on PATH' $script:curlOk $(if ($script:curlOk) { '' } else { 'curl.exe not found on PATH -- HTTP assertions fail closed' })

    $reason = ''
    if ($null -eq (Get-Command 'kubectl' -ErrorAction SilentlyContinue)) { $reason = 'kubectl not on PATH' }
    elseif ([string]::IsNullOrWhiteSpace($env:KUBECONFIG)) { $reason = 'KUBECONFIG is not set (agent-view kubeconfig required)' }
    else {
        # 사용자 제공 상대 경로는 PSPath로 해석한다(.NET cwd 아님 — CLAUDE.md Known Issues). 경로는 출력하지 않는다.
        $p = $null
        try { $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:KUBECONFIG) } catch { $p = $null }
        if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { $reason = 'KUBECONFIG file not found' }
        else { $script:kubeconfigPath = $p }
    }
    $script:kubeReady = [string]::IsNullOrEmpty($reason)
    if (-not $script:kubeReady) { $script:kubeReason = $reason }
    Assert 'tool-2: kubectl on PATH + KUBECONFIG file present (agent-view token kubeconfig)' $script:kubeReady $reason
}

# ---------- access: 세 호스트 → 302 Cloudflare Access 로그인 (T032: argo 302 · vault 302 · traefik 대시보드 Access 뒤) ----------
Test-Group 'access' {
    Assert-AccessRedirect "argo-1: https://$ArgoHost -> 302 Cloudflare Access login (Location https://$AccessLoginHost$AccessLoginPathPrefix...)" $ArgoHost
    Assert-AccessRedirect "vault-1: https://$VaultHost -> 302 Cloudflare Access login (Location https://$AccessLoginHost$AccessLoginPathPrefix...)" $VaultHost
    Assert-AccessRedirect "traefik-1: https://$TraefikHost dashboard behind Access -> 302 (Location https://$AccessLoginHost$AccessLoginPathPrefix...)" $TraefikHost
}

# ---------- cluster: 노드 A(role=platform)·Traefik 배치·Ingress 존재 (T032: Traefik pod가 노드 A; argo/vault Ingress) ----------
$script:platformNodeNames = @()
$script:nodeIpOk = $false
$script:traefikObserved = $false
$script:ingress = @{ obj = $null; reason = 'not fetched' }
Test-Group 'cluster' {
    KubeAssert "node-1: node with label $PlatformNodeSelector exists; kubelet ExternalIP (when reported) == $NodeAPublicIp" {
        $g = Get-KubeJson @('nodes', '-l', $PlatformNodeSelector)
        if ($null -eq $g.obj) { return @($false, $g.reason) }
        $items = @($g.obj.items | Where-Object { $null -ne $_ })
        if ($items.Count -lt 1) { return @($false, "no node carries label $PlatformNodeSelector") }
        $names = @($items | ForEach-Object { "$($_.metadata.name)" })
        $ext = @()
        foreach ($n in $items) {
            foreach ($a in @($n.status.addresses)) {
                if ($null -ne $a -and [string]::Equals("$($a.type)", 'ExternalIP', [StringComparison]::Ordinal)) { $ext += "$($a.address)" }
            }
        }
        $drift = @($ext | Where-Object { -not [string]::Equals($_, $NodeAPublicIp, [StringComparison]::Ordinal) })
        if ($drift.Count -gt 0) { return @($false, "platform node ExternalIP [$($drift -join ',')] != constant $NodeAPublicIp -- update the constant (source: infra/oci output node_a_reserved_public_ip)") }
        # 표류 검사를 지난 뒤에만 platform 노드 집합을 확정한다 — node-1 FAIL이면 traefik-2·aop-1도 전제 미충족으로 FAIL.
        $script:platformNodeNames = $names
        $script:nodeIpOk = $true
        $note = if ($ext.Count -eq 0) { 'kubelet reports no ExternalIP; constant used' } else { 'kubelet ExternalIP matches constant' }
        return @($true, "nodes=[$($names -join ',')] $note")
    }

    KubeAssert "traefik-2: Traefik pod(s) Running in $TraefikNamespace (-l $TraefikPodSelector), all scheduled on $PlatformNodeSelector node(s)" {
        if ($script:platformNodeNames.Count -eq 0) { return @($false, 'platform node set unknown (node-1 failed)') }
        $g = Get-KubeJson @('pods', '-n', $TraefikNamespace, '-l', $TraefikPodSelector)
        if ($null -eq $g.obj) { return @($false, $g.reason) }
        $running = @($g.obj.items | Where-Object {
                $null -ne $_ -and [string]::Equals("$($_.status.phase)", 'Running', [StringComparison]::Ordinal) -and
                -not "$($_.metadata.name)".StartsWith('helm-install-', [StringComparison]::Ordinal)
            })
        if ($running.Count -lt 1) { return @($false, "no Running pod matches -l $TraefikPodSelector in $TraefikNamespace") }
        $placed = @($running | ForEach-Object { "$($_.metadata.name)@$($_.spec.nodeName)" })
        $off = @($running | Where-Object { -not (Test-InSet "$($_.spec.nodeName)" $script:platformNodeNames) })
        if ($off.Count -gt 0) {
            $offList = @($off | ForEach-Object { "$($_.metadata.name)@$($_.spec.nodeName)" })
            return @($false, "Traefik pod(s) not on a $PlatformNodeSelector node: [$($offList -join ',')] (platform nodes=[$($script:platformNodeNames -join ',')])")
        }
        $script:traefikObserved = $true
        return @($true, "running=[$($placed -join ',')]")
    }

    # Ingress 존재: HTTP 302는 edge(Access)에서 나므로 리소스 존재를 따로 요구한다(T044 전 vault-2 FAIL이 정상).
    if ($script:kubeReady) { $script:ingress = Get-KubeJson @('ingress', '-A') }
    KubeAssert "argo-2: Ingress (networking.k8s.io) with rules[].host == $ArgoHost exists" {
        if ($null -eq $script:ingress.obj) { return @($false, $script:ingress.reason) }
        $m = Get-IngressMatches $script:ingress.obj $ArgoHost
        if (@($m).Count -lt 1) { return @($false, "no Ingress has rules[].host == $ArgoHost") }
        return @($true, "ingress=[$(@($m) -join ',')]")
    }
    KubeAssert "vault-2: Ingress (networking.k8s.io) with rules[].host == $VaultHost exists (T044)" {
        if ($null -eq $script:ingress.obj) { return @($false, $script:ingress.reason) }
        $m = Get-IngressMatches $script:ingress.obj $VaultHost
        if (@($m).Count -lt 1) { return @($false, "no Ingress has rules[].host == $VaultHost (expected after T044)") }
        return @($true, "ingress=[$(@($m) -join ',')]")
    }
}

# ---------- aop: 노드 A IP로 직접 TLS → 실패해야 한다 (T032: curl --resolve <A IP> 직접 TLS 핸드셰이크 실패; 성공 = FAIL) ----------
Test-Group 'aop' {
    $id = "aop-1: direct TLS to node A ($NodeAPublicIp) via --resolve $ArgoHost is refused (AOP/NSG; any HTTP status = FAIL)"
    if (-not $script:curlOk) { Assert $id $false 'curl.exe unavailable (tool-1)'; return }
    if (-not ($script:traefikObserved -and $script:nodeIpOk)) {
        Assert $id $false 'precondition unmet: node-1 and traefik-2 must pass first -- an unanswered IP is not evidence of AOP (fail closed)'
        return
    }
    $r = Invoke-CurlHead "https://$ArgoHost/" @('-k', '--resolve', "${ArgoHost}:443:$NodeAPublicIp")
    if ($r.code -eq 0 -or -not [string]::IsNullOrEmpty($r.status)) {
        Assert $id $false "direct origin access SUCCEEDED: curl exit=$($r.code) status=[$($r.status)] -- Authenticated Origin Pulls / NSG not enforced"
        return
    }
    # 거부로 인정하는 curl 종료 코드 화이트리스트 — 그 외는 거부가 아니라 도구/호출 오류(-1 실행 실패, 2 사용법, 3 URL, 6 DNS, 8 이상 응답 등)이므로 FAIL.
    $refusalLabels = @{
        7  = 'failed to connect (refused/unreachable)'
        28 = 'timeout -- blocked before TLS (NSG/network layer; operator host is outside Cloudflare ranges)'
        35 = 'TLS handshake failure (AOP client-certificate rejection)'
        52 = 'empty reply from server (connection closed without a response)'
        55 = 'send failure during TLS'
        56 = 'receive failure during TLS (AOP rejection alert)'
    }
    $code = [int]$r.code
    if (-not $refusalLabels.ContainsKey($code)) {
        Assert $id $false "unexpected curl exit $code (not a refusal); err=$($r.err)"
        return
    }
    Assert $id $true "refused: curl exit $code = $($refusalLabels[$code]); err=$($r.err)"
}

# ---------- cert: 와일드카드 인증서 Secret 존재·만료 (T032: kube-system/wildcard-joshuatech-dev-tls 존재·만료 > 30일) ----------
# Secret 값은 읽지 않는다(계약 §에이전트 자격) — cert-manager Certificate(spec.secretName = 그 Secret)의 Ready·status.notAfter로만 판정한다.
Test-Group 'cert' {
    $id1 = "cert-1: Secret $WildcardSecretNamespace/$WildcardSecretName exists (cert-manager Certificate spec.secretName match, Ready=True)"
    $id2 = "cert-2: wildcard certificate status.notAfter is more than $MinCertDaysLeft days away (TotalDays > $MinCertDaysLeft)"
    if (-not $script:kubeReady) {
        Assert $id1 $false "kubectl unavailable ($script:kubeReason)"
        Assert $id2 $false "kubectl unavailable ($script:kubeReason)"
        return
    }
    $g = Get-KubeJson @('certificates.cert-manager.io', '-n', $WildcardSecretNamespace)
    if ($null -eq $g.obj) { Assert $id1 $false "cert-manager Certificate list failed: $($g.reason)"; Assert $id2 $false 'no certificate source'; return }
    $c = @($g.obj.items | Where-Object { $null -ne $_ -and [string]::Equals("$($_.spec.secretName)", $WildcardSecretName, [StringComparison]::Ordinal) })
    if ($c.Count -ne 1) { Assert $id1 $false "expected exactly 1 cert-manager Certificate in $WildcardSecretNamespace with spec.secretName=$WildcardSecretName, found $($c.Count)"; Assert $id2 $false 'no certificate source'; return }
    $cname = "$($c[0].metadata.name)"
    $ready = @($c[0].status.conditions | Where-Object { $null -ne $_ -and [string]::Equals("$($_.type)", 'Ready', [StringComparison]::Ordinal) })
    $isReady = ($ready.Count -eq 1) -and [string]::Equals("$($ready[0].status)", 'True', [StringComparison]::Ordinal)
    if (-not $isReady) {
        $reasons = @($ready | ForEach-Object { "$($_.reason)" })
        Assert $id1 $false "Certificate $cname Ready != True (reason=[$($reasons -join ',')]) -- cert-manager sets Ready=True only when the Secret exists and is valid"
        Assert $id2 $false 'certificate not Ready'
        return
    }
    Assert $id1 $true "Certificate $cname Ready=True (Secret value never read; agent-view has no Secret get)"
    $na = "$($c[0].status.notAfter)"
    $parsed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse($na, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) {
        Assert $id2 $false "Certificate $cname status.notAfter unparseable: [$na]"
        return
    }
    $notAfterUtc = $parsed.UtcDateTime
    $daysLeft = ($notAfterUtc - [DateTime]::UtcNow).TotalDays   # 내림 없음 — 30일을 초과해야 PASS
    $naText = $notAfterUtc.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
    Assert $id2 ($daysLeft -gt $MinCertDaysLeft) "notAfter=$naText daysLeft=$($daysLeft.ToString('0.00', [Globalization.CultureInfo]::InvariantCulture)) (must exceed $MinCertDaysLeft)"
}

# ---------- 요약 ----------
Write-Host ''
Write-Host "$script:pass passed, $script:fail failed, $script:skip skipped"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
