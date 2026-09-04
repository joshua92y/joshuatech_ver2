# tests/infra/traefik-config.tests.ps1 — infra/bootstrap/traefik-config.yaml 정적 검사 스위트 (T038)
# Run: pwsh -NoProfile -File tests/infra/traefik-config.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크·모듈 없음(tests/infra/k3s-server.tests.ps1 과 같은 구조).
# 문자열 비교는 전부 Ordinal([string]::Equals / IndexOf) — PowerShell 의 -eq/-ceq 는 문화권 비교라 U+200B·U+FEFF 같은
# "무시 가능" 코드포인트를 건너뛴다(CLAUDE.md Known Issues). 목록 비교도 -ceq 대신 Eq 헬퍼를 쓴다.
#
# 이 스위트는 원문만 읽는다. 노드·kubectl·helm 실행 없음(적용은 운영자 절차, 파일 머리 주석). SKIP 없이 fail closed —
# 파일이 없으면 전 단언 FAIL. PowerShell 에 YAML 파서(ConvertFrom-Yaml)가 없으므로 들여쓰기 기반 소형 파서로 키 경로를 뽑아
# 값을 정확히 대조한다(파싱 불가 줄이 하나라도 있으면 parse-1 이 FAIL — 조용한 통과 금지).
#
# 검사 계약(이 스위트가 곧 계약이다):
#   FILE   file-1 존재  file-2 CR 없음  file-3 끝 개행  file-4 BOM 없음  file-5 탭 없음  file-6 첫 줄이 경로 주석
#   DOC    doc-1 정본 선언 + platform/traefik/ 는 Middleware·TLSOption·TLSStore 만  doc-2 traefik.yaml 편집 금지
#          doc-3 chart 40.1.x ↔ upstream 41.x 키 차이  doc-4 T043 에서 더할 clientAuth 조각 + Secret 선행
#          doc-5 T042 에서 더할 sniStrict + 동적 인증서 선행  doc-6 적용 순서(T042 → T043) + 문면과의 의도적 편차 명시
#          doc-7 설치 절차(scp + sudo install -m 644 -o root -g root → server/manifests/traefik-config.yaml)
#          doc-8 확인 명령(helmchartconfig · rollout status · pods -o wide · logs --tail=200 · 443 curl)
#          doc-9 되돌리기 2단계(파일 rm + kubectl delete helmchartconfig traefik — 파일 삭제만으로는 객체가 남는다)
#          doc-10 helm-install Job 실패 복구(immutable → delete job)  doc-11 자격(운영자 admin kubeconfig, agent-view 한계)
#          doc-12 롤아웃 순단 경고(replica 1, 443)  doc-13 HelmChart spec.set 우선 함정  doc-14 T084 forward-auth 재수정 예고
#          doc-15 klipper-lb 소스 IP 실측 방법(ClientHost ↔ request_CF-Connecting-IP)  doc-16 T098 전 tracing 잡음
#          doc-17 Cloudflare 목록 근거(data.cloudflare_ip_ranges + infra/oci/network.tf) + 드리프트 재검토 주기
#   K8S    k8s-1 문서 1개  k8s-2 apiVersion helm.cattle.io/v1  k8s-3 kind HelmChartConfig  k8s-4 metadata.name traefik
#          k8s-5 metadata.namespace kube-system  k8s-6 spec.valuesContent 블록 스칼라 '|-'
#   PARSE  parse-1 valuesContent 전 줄 파싱  parse-2 최상위 키 집합 정확히 6개
#   V      v-1..v-23 필수 키·정확한 값(chart 40.1.x 철자) — v-20 은 tlsOptions.default 가 minVersion 하나뿐임을 고정한다
#   X      x-1 10.42.0.0/16 없음(파일 전체)  x-2 accessLog: 없음  x-3 defaultMode 없음  x-4 최상위 log: 없음
#          x-5 RequireAndVerifyClientCert 없음  x-6 clientAuth 계열 키 없음(T043)  x-7 sniStrict 없음(T042)
#          x-8 비밀 패턴 없음  x-9 URL 스킴 없음  x-10 image 오버라이드 없음  x-11 insecure: true 는 tracing.otlp.grpc 하나뿐
#          x-12 proxyProtocol 경로 없음  x-13 모든 *.trustedIPs 에 사설·예약 대역 없음  x-14 제로폭·비가시 문자 없음
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$target = Join-Path $repo 'infra/bootstrap/traefik-config.yaml'

$script:pass = 0
$script:fail = 0

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Has([string]$hay, [string]$needle) { return $hay.IndexOf($needle, [StringComparison]::Ordinal) -ge 0 }
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }

$allNames = @('file-1', 'file-2', 'file-3', 'file-4', 'file-5', 'file-6',
    'doc-1', 'doc-2', 'doc-3', 'doc-4', 'doc-5', 'doc-6', 'doc-7', 'doc-8', 'doc-9',
    'doc-10', 'doc-11', 'doc-12', 'doc-13', 'doc-14', 'doc-15', 'doc-16', 'doc-17',
    'k8s-1', 'k8s-2', 'k8s-3', 'k8s-4', 'k8s-5', 'k8s-6',
    'parse-1', 'parse-2',
    'v-1', 'v-2', 'v-3', 'v-4', 'v-5', 'v-6', 'v-7', 'v-8', 'v-9', 'v-10', 'v-11', 'v-12',
    'v-13', 'v-14', 'v-15', 'v-16', 'v-17', 'v-18', 'v-19', 'v-20', 'v-21', 'v-22', 'v-23',
    'x-1', 'x-2', 'x-3', 'x-4', 'x-5', 'x-6', 'x-7', 'x-8', 'x-9', 'x-10', 'x-11', 'x-12', 'x-13', 'x-14')

if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    foreach ($n in $allNames) { Assert $n $false 'missing: infra/bootstrap/traefik-config.yaml' }
    Write-Host "`n$($script:pass) passed, $($script:fail) failed"
    exit 1
}

$rawBytes = [IO.File]::ReadAllBytes($target)
$raw = [Text.Encoding]::UTF8.GetString($rawBytes)
$hasBom = ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF)
if ($hasBom) { $raw = $raw.Substring(1) }
$lines = $raw -split "`n"

# ---------- 소형 YAML 파서(들여쓰기 기반) ----------
# 반환: @{ Scalars = {path -> raw value}; Seqs = {path -> string[]}; Keys = {path -> $true}; Bad = @(줄) }
# 지원 형태: 'key:' · 'key: value' · '- item' · 주석 줄 · 빈 줄. 그 밖의 줄은 Bad 로 모아 fail closed 한다.
function ConvertFrom-MiniYaml([string]$text) {
    # [ordered]@{} 는 대소문자를 무시하는 비교자를 쓴다 — 그러면 defaultMode/defaultmode 같은 세대 차이(chart 40.1.x ↔ 41.x)가
    # 조회에서 같은 키로 취급돼 조용히 통과한다. 그래서 세 사전 모두 Ordinal 비교자로 만든다.
    $scalars = New-Object 'System.Collections.Specialized.OrderedDictionary' ([StringComparer]::Ordinal)
    $seqs = New-Object 'System.Collections.Specialized.OrderedDictionary' ([StringComparer]::Ordinal)
    $keys = New-Object 'System.Collections.Specialized.OrderedDictionary' ([StringComparer]::Ordinal)
    $bad = @()
    $stack = New-Object System.Collections.ArrayList   # @{ Indent; Key }
    $lastPath = ''
    $lastIndent = -1
    foreach ($line0 in ($text -split "`n")) {
        $line = $line0.TrimEnd("`r")
        if ($line.Trim().Length -eq 0) { continue }
        if ($line -cmatch '^\s*#') { continue }
        $indent = $line.Length - $line.TrimStart(' ').Length
        if ($line -cmatch '^\s*-\s+(.+?)\s*$') {
            $item = $Matches[1]
            if ($lastPath.Length -eq 0 -or $indent -le $lastIndent) { $bad += "orphan sequence item: $line"; continue }
            if (-not $seqs.Contains($lastPath)) { $seqs[$lastPath] = @() }
            $seqs[$lastPath] += $item
            continue
        }
        if ($line -cmatch '^\s*([A-Za-z0-9_.\-]+):\s*(.*?)\s*$') {
            $key = $Matches[1]
            $value = $Matches[2]
            while ($stack.Count -gt 0 -and $stack[$stack.Count - 1].Indent -ge $indent) { $stack.RemoveAt($stack.Count - 1) }
            $parent = ''
            if ($stack.Count -gt 0) { $parent = (($stack | ForEach-Object { $_.Key }) -join '.') }
            $path = if ($parent.Length -gt 0) { "$parent.$key" } else { $key }
            [void]$stack.Add(@{ Indent = $indent; Key = $key })
            $keys[$path] = $true
            if ($value.Length -gt 0) { $scalars[$path] = $value }
            $lastPath = $path
            $lastIndent = $indent
            continue
        }
        $bad += "unparsed: $line"
    }
    return @{ Scalars = $scalars; Seqs = $seqs; Keys = $keys; Bad = $bad }
}

function Scalar($parsed, [string]$path) {
    if ($parsed.Scalars.Contains($path)) { return [string]$parsed.Scalars[$path] }
    return $null
}
# 앞의 쉼표(단항 배열 연산자)가 필요하다: PowerShell 은 함수가 돌려주는 1원소 배열을 스칼라로 풀어버려
# ($seq.Count -eq 1 인데 $seq[0] 이 문자열의 첫 글자가 되는) 조용한 오판을 만든다.
function Seq($parsed, [string]$path) {
    if ($parsed.Seqs.Contains($path)) { return , @($parsed.Seqs[$path]) }
    return , @()
}
# CIDR 문자열이 사설·예약 대역인가(RFC 1918 · 루프백 · 링크로컬 · 0.0.0.0/x). 리터럴 문자열 비교가 아니라 옥텟 계산이라
# 10.42.0.0/15 같은 변형도 잡는다.
function Test-PrivateCidr([string]$cidr) {
    $ip = ($cidr -split '/')[0]
    $o = @($ip -split '\.')
    if ($o.Count -ne 4) { return $true }
    foreach ($p in $o) { if ($p -notmatch '^\d{1,3}$') { return $true } }
    $a = [int]$o[0]; $b = [int]$o[1]
    return ($a -eq 0 -or $a -eq 10 -or $a -eq 127 -or ($a -eq 172 -and $b -ge 16 -and $b -le 31) -or ($a -eq 192 -and $b -eq 168) -or ($a -eq 169 -and $b -eq 254))
}

# ---------- 문서 / valuesContent 분리 ----------
$headerLines = @()
foreach ($l in $lines) { if ($l -cmatch '^\s*#' -or $l.Trim().Length -eq 0) { $headerLines += $l } else { break } }
$header = ($headerLines -join "`n")

$vcIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -cmatch '^  valuesContent:') { $vcIndex = $i; break } }
$valuesRaw = @()
$valuesIndentOk = $true
if ($vcIndex -ge 0) {
    for ($i = $vcIndex + 1; $i -lt $lines.Count; $i++) {
        $l = $lines[$i].TrimEnd("`r")
        if ($l.Trim().Length -eq 0) { continue }
        if ($l.StartsWith('    ', [StringComparison]::Ordinal)) { $valuesRaw += $l.Substring(4) }
        else { $valuesIndentOk = $false; break }
    }
}
$valuesText = ($valuesRaw -join "`n")
$docText = if ($vcIndex -ge 0) { (($lines[0..$vcIndex]) -join "`n") } else { $raw }

$doc = ConvertFrom-MiniYaml (($docText -split "`n" | Where-Object { -not $_.StartsWith('    ', [StringComparison]::Ordinal) }) -join "`n")
$vals = ConvertFrom-MiniYaml $valuesText

# ---------- FILE ----------
Test-Group 'file' {
    Assert 'file-1: infra/bootstrap/traefik-config.yaml exists' $true ''
    Assert 'file-2: no CR (LF only — .gitattributes forces LF)' (-not (Has $raw "`r")) 'CR found'
    Assert 'file-3: ends with a newline' ($raw.EndsWith("`n", [StringComparison]::Ordinal)) 'no final newline'
    Assert 'file-4: no UTF-8 BOM' (-not $hasBom) 'BOM found'
    Assert 'file-5: no tab characters (YAML forbids tabs for indentation)' (-not (Has $raw "`t")) 'tab found'
    Assert 'file-6: first line names the file and the task' ($lines.Count -gt 0 -and (Has $lines[0] 'infra/bootstrap/traefik-config.yaml') -and (Has $lines[0] 'T038')) "first line: '$($lines[0])'"
}

# ---------- DOC (파일 머리 주석 = 운영 계약) ----------
Test-Group 'doc' {
    Assert 'doc-1: header declares this file the source of truth and limits platform/traefik/ to Middleware/TLSOption/TLSStore' (
        (Has $header '정본') -and (Has $header 'platform/traefik/') -and (Has $header 'Middleware') -and (Has $header 'TLSStore')
    ) 'header must state the source-of-truth split with the GitOps repo'
    Assert 'doc-2: header forbids editing the packaged traefik.yaml (K3s rewrites it)' (
        (Has $header 'traefik.yaml') -and (Has $header '편집 금지')
    ) 'header must warn that traefik.yaml is rewritten on every k3s start'
    Assert 'doc-3: header records the chart 40.1.x vs upstream 41.x key difference' (
        (Has $header '40.1.x') -and (Has $header '41.x') -and (Has $header 'defaultmode') -and (Has $header 'statuscodes')
    ) 'header must carry the 40.1.x/41.x key table'
    Assert 'doc-4: header carries the exact clientAuth block to add in T043 plus its Secret precondition' (
        (Has $header 'T043') -and (Has $header 'clientAuth:') -and (Has $header 'secretNames:') -and
        (Has $header 'cloudflare-origin-pull-ca') -and (Has $header 'clientAuthType: VerifyClientCertIfGiven') -and
        (Has $header 'CAFiles')
    ) 'header must show the T043 clientAuth snippet and why it cannot ship now (missing CA Secret breaks websecure)'
    Assert 'doc-5: header carries the sniStrict step for T042 plus the dynamic-certificate precondition' (
        (Has $header 'T042') -and (Has $header 'sniStrict: true') -and (Has $header '동적 인증서')
    ) 'header must show the T042 sniStrict snippet and the dynamic cert precondition'
    Assert 'doc-6: header pins the apply order T042 -> T043 and flags the deliberate deviation from the task line' (
        (Has $header 'T042(와일드카드 인증서) → T043(CA Secret)') -and (Has $header '의도적 편차')
    ) 'header must state the ordering and that this deviates from the T038 task line on purpose'
    Assert 'doc-7: header carries the operator install procedure (scp + install -m 644 root:root into the manifests dir)' (
        (Has $header 'scp ') -and
        (Has $header 'sudo install -m 644 -o root -g root') -and
        (Has $header '/var/lib/rancher/k3s/server/manifests/traefik-config.yaml')
    ) 'header must show scp then sudo install into /var/lib/rancher/k3s/server/manifests/'
    Assert 'doc-8: header carries verification that would actually fail on a broken rollout' (
        (Has $header 'kubectl -n kube-system get helmchartconfig traefik -o yaml') -and
        (Has $header 'kubectl -n kube-system rollout status deploy/traefik --timeout=120s') -and
        (Has $header 'kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik -o wide') -and
        (Has $header 'kubectl -n kube-system logs deploy/traefik --tail=200') -and
        (Has $header 'curl -sk --resolve traefik.joshuatech.dev:443:')
    ) 'header must include rollout status, error-grepped logs and a real 443 handshake check'
    Assert 'doc-9: header rollback deletes the file AND the HelmChartConfig object' (
        (Has $header '되돌리기') -and
        (Has $header 'sudo rm -f /var/lib/rancher/k3s/server/manifests/traefik-config.yaml') -and
        (Has $header 'kubectl -n kube-system delete helmchartconfig traefik')
    ) 'K3s does not delete applied objects when the manifest file disappears — both commands are required, in that order'
    Assert 'doc-10: header documents the helm-install Job recovery (immutable Job -> delete)' (
        (Has $header 'kubectl -n kube-system delete job helm-install-traefik') -and (Has $header 'immutable')
    ) 'header must say how to retry a failed helm-install-traefik Job'
    Assert 'doc-11: header states the credentials (operator admin kubeconfig; agent-view cannot read these CRs)' (
        (Has $header 'admin kubeconfig') -and (Has $header 'agent-view')
    ) 'header must correct who can run the verification commands'
    Assert 'doc-12: header warns that applying this file interrupts 443 (single replica rollout)' (
        (Has $header '순단') -and (Has $header 'replica 1')
    ) 'header must warn about the websecure outage during rollout'
    Assert 'doc-13: header records that HelmChart spec.set wins over valuesContent' (
        (Has $header 'spec.set') -and (Has $header '우선')
    ) 'header must carry the spec.set precedence trap'
    Assert 'doc-14: header lists T084 (Authentik forward-auth) as a later edit of this file' (
        (Has $header 'T084') -and (Has $header 'authentik-forwardauth')
    ) 'header must point at T084 for the dashboard forward-auth middleware'
    Assert 'doc-15: header gives the klipper-lb source-IP measurement' (
        (Has $header 'ClientHost') -and (Has $header 'request_CF-Connecting-IP')
    ) 'header must explain how to measure whether the client source IP survives svclb'
    Assert 'doc-16: header explains the tracing noise window before T098' (
        (Has $header 'T098') -and (Has $header 'tracing.otlp.enabled')
    ) 'header must state that OTLP errors are noise until Alloy exists and how to silence them'
    Assert 'doc-17: header records the Cloudflare list source and a drift review cadence' (
        (Has $header 'data.cloudflare_ip_ranges') -and (Has $header 'infra/oci/network.tf') -and
        (Has $header 'api.cloudflare.com/client/v4/ips') -and (Has $header '재검토 주기')
    ) 'header must name the data source, the compare command and how often the literal copy is re-checked'
}

# ---------- K8S 문서 형태 ----------
Test-Group 'k8s' {
    $docSeparators = @($lines | Where-Object { $_.TrimEnd("`r").StartsWith('---', [StringComparison]::Ordinal) })
    Assert 'k8s-1: exactly one YAML document (no --- separators)' ($docSeparators.Count -eq 0) "found $($docSeparators.Count) document separator line(s)"
    Assert 'k8s-2: apiVersion is helm.cattle.io/v1' (Eq (Scalar $doc 'apiVersion') 'helm.cattle.io/v1') "apiVersion = '$(Scalar $doc 'apiVersion')'"
    Assert 'k8s-3: kind is HelmChartConfig' (Eq (Scalar $doc 'kind') 'HelmChartConfig') "kind = '$(Scalar $doc 'kind')'"
    Assert 'k8s-4: metadata.name is traefik (must match the packaged HelmChart name)' (Eq (Scalar $doc 'metadata.name') 'traefik') "metadata.name = '$(Scalar $doc 'metadata.name')'"
    Assert 'k8s-5: metadata.namespace is kube-system' (Eq (Scalar $doc 'metadata.namespace') 'kube-system') "metadata.namespace = '$(Scalar $doc 'metadata.namespace')'"
    Assert 'k8s-6: spec.valuesContent is a |- block scalar' ((Eq (Scalar $doc 'spec.valuesContent') '|-') -and $vcIndex -ge 0) "spec.valuesContent = '$(Scalar $doc 'spec.valuesContent')'"
}

# ---------- PARSE ----------
Test-Group 'parse' {
    $bad = @($doc.Bad) + @($vals.Bad)
    $parseDetail = ''
    if (-not $valuesIndentOk) { $parseDetail = 'valuesContent block is not indented by exactly 4 spaces' }
    elseif ($valuesRaw.Count -eq 0) { $parseDetail = 'valuesContent block is empty' }
    else { $parseDetail = ($bad -join ' | ') }
    Assert 'parse-1: every line of the document and valuesContent parses' (($bad.Count -eq 0) -and $valuesIndentOk -and ($valuesRaw.Count -gt 0)) $parseDetail
    $topKeys = @($vals.Keys.Keys | Where-Object { -not (Has $_ '.') }) | Sort-Object
    $wantTop = @('ingressRoute', 'logs', 'nodeSelector', 'ports', 'tlsOptions', 'tracing')
    Assert 'parse-2: valuesContent top-level keys are exactly the six expected ones' (
        Eq ($topKeys -join ',') ($wantTop -join ',')
    ) "top-level keys = $($topKeys -join ', ')"
}

# ---------- V: 값 계약(chart 40.1.x 철자) ----------
Test-Group 'values' {
    Assert 'v-1: nodeSelector.role = platform (Traefik pins to node A)' (Eq (Scalar $vals 'nodeSelector.role') 'platform') "= '$(Scalar $vals 'nodeSelector.role')'"
    Assert 'v-2: logs.general.format = json' (Eq (Scalar $vals 'logs.general.format') 'json') "= '$(Scalar $vals 'logs.general.format')'"
    Assert 'v-3: logs.access.enabled = true' (Eq (Scalar $vals 'logs.access.enabled') 'true') "= '$(Scalar $vals 'logs.access.enabled')'"
    Assert 'v-4: logs.access.format = json' (Eq (Scalar $vals 'logs.access.format') 'json') "= '$(Scalar $vals 'logs.access.format')'"
    Assert 'v-5: logs.access.fields.headers.defaultmode = drop (chart 40.1.x spells it lowercase)' (Eq (Scalar $vals 'logs.access.fields.headers.defaultmode') 'drop') "= '$(Scalar $vals 'logs.access.fields.headers.defaultmode')'"
    Assert 'v-6: logs.access.filters.statuscodes = "400-599" (quoted string; 40.1.x schema is additionalProperties:false)' (Eq (Scalar $vals 'logs.access.filters.statuscodes') '"400-599"') "= '$(Scalar $vals 'logs.access.filters.statuscodes')'"
    Assert 'v-7: logs.access.fields.headers.names.CF-Connecting-IP = keep (the only real client identifier behind svclb)' (
        Eq (Scalar $vals 'logs.access.fields.headers.names.CF-Connecting-IP') 'keep'
    ) "= '$(Scalar $vals 'logs.access.fields.headers.names.CF-Connecting-IP')'"
    Assert 'v-8: logs.access.fields.headers.names.CF-Ray = keep' (Eq (Scalar $vals 'logs.access.fields.headers.names.CF-Ray') 'keep') "= '$(Scalar $vals 'logs.access.fields.headers.names.CF-Ray')'"
    Assert 'v-9: logs.access.fields.headers.names.User-Agent = keep' (Eq (Scalar $vals 'logs.access.fields.headers.names.User-Agent') 'keep') "= '$(Scalar $vals 'logs.access.fields.headers.names.User-Agent')'"
    Assert 'v-10: tracing.otlp.enabled = true' (Eq (Scalar $vals 'tracing.otlp.enabled') 'true') "= '$(Scalar $vals 'tracing.otlp.enabled')'"
    Assert 'v-11: tracing.otlp.grpc.enabled = true' (Eq (Scalar $vals 'tracing.otlp.grpc.enabled') 'true') "= '$(Scalar $vals 'tracing.otlp.grpc.enabled')'"
    Assert 'v-12: tracing.otlp.grpc.endpoint = k8s-monitoring-alloy-metrics.monitoring.svc:4317 (service DNS, T098)' (Eq (Scalar $vals 'tracing.otlp.grpc.endpoint') 'k8s-monitoring-alloy-metrics.monitoring.svc:4317') "= '$(Scalar $vals 'tracing.otlp.grpc.endpoint')'"
    Assert 'v-13: tracing.otlp.grpc.insecure = true (plaintext in-cluster gRPC)' (Eq (Scalar $vals 'tracing.otlp.grpc.insecure') 'true') "= '$(Scalar $vals 'tracing.otlp.grpc.insecure')'"
    Assert 'v-14: tracing.sampleRate = 0.1' (Eq (Scalar $vals 'tracing.sampleRate') '0.1') "= '$(Scalar $vals 'tracing.sampleRate')'"
    Assert 'v-15: ports.web.http.redirections.entryPoint.to = websecure' (Eq (Scalar $vals 'ports.web.http.redirections.entryPoint.to') 'websecure') "= '$(Scalar $vals 'ports.web.http.redirections.entryPoint.to')'"
    Assert 'v-16: ports.web.http.redirections.entryPoint.scheme = https' (Eq (Scalar $vals 'ports.web.http.redirections.entryPoint.scheme') 'https') "= '$(Scalar $vals 'ports.web.http.redirections.entryPoint.scheme')'"
    Assert 'v-17: ports.web.http.redirections.entryPoint.permanent = true (301)' (Eq (Scalar $vals 'ports.web.http.redirections.entryPoint.permanent') 'true') "= '$(Scalar $vals 'ports.web.http.redirections.entryPoint.permanent')'"

    $want = @('173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22', '141.101.64.0/18',
        '108.162.192.0/18', '190.93.240.0/20', '188.114.96.0/20', '197.234.240.0/22', '198.41.128.0/17',
        '162.158.0.0/15', '104.16.0.0/13', '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22')
    $trusted = Seq $vals 'ports.websecure.forwardedHeaders.trustedIPs'
    Assert 'v-18: ports.websecure.forwardedHeaders.trustedIPs = the 15 Cloudflare IPv4 CIDRs (data.cloudflare_ip_ranges)' (
        ($trusted.Count -eq $want.Count) -and (Eq ($trusted -join ',') ($want -join ','))
    ) "got $($trusted.Count) entries: $($trusted -join ', ')"

    Assert 'v-19: tlsOptions.default.minVersion = VersionTLS12' (Eq (Scalar $vals 'tlsOptions.default.minVersion') 'VersionTLS12') "= '$(Scalar $vals 'tlsOptions.default.minVersion')'"
    $tlsKeys = @($vals.Keys.Keys | Where-Object { $_.StartsWith('tlsOptions.', [StringComparison]::Ordinal) }) | Sort-Object
    $wantTls = @('tlsOptions.default', 'tlsOptions.default.minVersion')
    Assert 'v-20: tlsOptions.default carries minVersion only (sniStrict -> T042, clientAuth -> T043)' (
        Eq ($tlsKeys -join ',') ($wantTls -join ',')
    ) "tlsOptions keys = $($tlsKeys -join ', ')"
    Assert 'v-21: ingressRoute.dashboard.enabled = true' (Eq (Scalar $vals 'ingressRoute.dashboard.enabled') 'true') "= '$(Scalar $vals 'ingressRoute.dashboard.enabled')'"
    Assert 'v-22: ingressRoute.dashboard.matchRule pins the traefik.joshuatech.dev host' (
        Eq (Scalar $vals 'ingressRoute.dashboard.matchRule') 'Host(`traefik.joshuatech.dev`)'
    ) "= '$(Scalar $vals 'ingressRoute.dashboard.matchRule')'"
    $eps = Seq $vals 'ingressRoute.dashboard.entryPoints'
    Assert 'v-23: ingressRoute.dashboard.entryPoints = [websecure] (never the internal traefik entrypoint)' (
        ($eps.Count -eq 1) -and (Eq $eps[0] 'websecure')
    ) "= $($eps -join ', ')"
}

# ---------- X: 금지 ----------
Test-Group 'forbidden' {
    # 파일 전체를 본다(주석 포함) — 리뷰어의 단순 grep 이 값과 설명을 구분할 수 없기 때문. 헤더는 '10.42/16' 로 적는다.
    Assert 'x-1: the pod CIDR 10.42.0.0/16 appears nowhere in the file' (
        -not (Has $raw '10.42.0.0/16')
    ) 'pod CIDR as a trusted IP would let any pod spoof X-Forwarded-*'
    Assert 'x-2: no upstream 41.x key accessLog:' (@($valuesRaw | Where-Object { $_ -cmatch '^\s*accessLog\s*:' }).Count -eq 0) 'chart 40.1.x uses logs.access'
    Assert 'x-3: no upstream 41.x spelling defaultMode (capital M)' (-not (Has $valuesText 'defaultMode')) 'chart 40.1.x uses defaultmode'
    Assert 'x-4: no top-level log: key (upstream 41.x)' (@($valuesRaw | Where-Object { $_ -cmatch '^log\s*:' }).Count -eq 0) 'chart 40.1.x uses logs.general'
    Assert 'x-5: RequireAndVerifyClientCert is not in valuesContent (T043 owns the step-up)' (
        -not (Has $valuesText 'RequireAndVerifyClientCert')
    ) 'enforcing mTLS before the CA Secret exists locks out every TLS client'
    Assert 'x-6: no clientAuth keys in valuesContent yet (the CA Secret arrives in T043)' (
        (-not (Has $valuesText 'clientAuth')) -and (-not (Has $valuesText 'secretNames'))
    ) 'a clientAuth block without its Secret registers a TLSOption without CAFiles and breaks every websecure handshake'
    Assert 'x-7: no sniStrict in valuesContent yet (the wildcard becomes a dynamic cert in T042)' (
        -not (Has $valuesText 'sniStrict')
    ) 'sniStrict skips the default-certificate fallback, so it must wait for a dynamic certificate'
    $secretPatterns = @('BEGIN [A-Z ]*PRIVATE KEY', 'BEGIN CERTIFICATE', '(?i)\bpassword\s*:', '(?i)\bapi[_-]?key\s*:', '(?i)\bsecret[_-]?key\s*:', '(?i)\btoken\s*:', 'eyJ[A-Za-z0-9_-]{10,}', '(?i)\bcloudflare_api_token\b')
    $hits = @()
    foreach ($p in $secretPatterns) { if ($raw -cmatch $p) { $hits += $p } }
    Assert 'x-8: no secret-shaped strings anywhere in the file' ($hits.Count -eq 0) ("matched: " + ($hits -join ' | '))
    Assert 'x-9: no URL scheme inside valuesContent (in-cluster targets are service DNS only)' (
        -not ($valuesText -cmatch '(?i)https?://')
    ) 'public hostnames must not be used from inside the cluster (FR-046)'
    Assert 'x-10: no image override in valuesContent (the bundled digest-pinned image stays)' (
        @($valuesRaw | Where-Object { $_ -cmatch '^\s*(image|repository|tag)\s*:' }).Count -eq 0
    ) 'image/tag overrides belong nowhere near a mutable tag'
    $insecureTrue = @($vals.Scalars.Keys | Where-Object {
        ((Eq $_ 'insecure') -or $_.EndsWith('.insecure', [StringComparison]::Ordinal)) -and (Eq ([string]$vals.Scalars[$_]) 'true')
    }) | Sort-Object
    Assert 'x-11: insecure: true only on tracing.otlp.grpc (never on forwardedHeaders/proxyProtocol)' (
        Eq ($insecureTrue -join ',') 'tracing.otlp.grpc.insecure'
    ) "insecure:true at: $($insecureTrue -join ', ')"
    Assert 'x-12: no proxyProtocol anywhere in valuesContent (nothing in front speaks PROXY protocol)' (
        -not (Has $valuesText 'proxyProtocol')
    ) 'a trusted proxyProtocol source would let the peer dictate the client IP'
    $trustedPaths = @($vals.Seqs.Keys | Where-Object { $_.EndsWith('trustedIPs', [StringComparison]::Ordinal) })
    $privateHits = @()
    foreach ($p in $trustedPaths) {
        foreach ($cidr in @($vals.Seqs[$p])) { if (Test-PrivateCidr $cidr) { $privateHits += "$p -> $cidr" } }
    }
    Assert 'x-13: no private/reserved range in any trustedIPs list' ($privateHits.Count -eq 0) ("private/reserved: " + ($privateHits -join ', '))
    $invisible = @()
    foreach ($cp in @(0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF, 0x00A0)) {
        if (Has $valuesText ([string][char]$cp)) { $invisible += ('U+{0:X4}' -f $cp) }
    }
    Assert 'x-14: no zero-width or non-breaking characters in valuesContent' ($invisible.Count -eq 0) (
        "found: " + ($invisible -join ', ') + " (they survive culture-sensitive comparisons and would silently corrupt a value)")
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
