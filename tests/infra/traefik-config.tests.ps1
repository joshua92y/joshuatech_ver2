# tests/infra/traefik-config.tests.ps1 — infra/bootstrap/traefik-config.yaml 정적 검사 스위트 (T038)
# Run: pwsh -NoProfile -File tests/infra/traefik-config.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크·모듈 없음(tests/infra/k3s-server.tests.ps1 과 같은 구조).
# 문자열 비교는 전부 Ordinal([string]::Equals / IndexOf) — PowerShell 의 -eq/-ceq 는 문화권 비교라 U+FEFF 같은 코드포인트를 무시한다.
#
# 이 스위트는 원문만 읽는다. 노드·kubectl·helm 실행 없음(적용은 운영자 절차, 파일 머리 주석). SKIP 없이 fail closed —
# 파일이 없으면 전 단언 FAIL. PowerShell 에 YAML 파서(ConvertFrom-Yaml)가 없으므로 들여쓰기 기반 소형 파서로 키 경로를 뽑아
# 값을 정확히 대조한다(파싱 불가 줄이 하나라도 있으면 parse-1 이 FAIL — 조용한 통과 금지).
#
# 검사 계약(이 스위트가 곧 계약이다):
#   FILE   file-1 파일 존재  file-2 CR 없음  file-3 끝 개행  file-4 BOM 없음  file-5 탭 문자 없음  file-6 첫 줄이 경로 주석
#   DOC    doc-1 정본 선언 + platform/traefik/ 는 Middleware·TLSOption·TLSStore 만  doc-2 traefik.yaml 편집 금지(K3s 가 재작성)
#          doc-3 chart 40.1.x ↔ upstream 41.x 키 차이  doc-4 T043 에서 RequireAndVerifyClientCert 로 승격
#          doc-5 운영자 절차: scp + sudo install -m 644 -o root -g root → server/manifests/traefik-config.yaml
#          doc-6 확인 명령 3종(helmchartconfig / pods -l app.kubernetes.io/name=traefik -o wide / logs deploy/traefik)
#          doc-7 되돌리기(파일 삭제 후 재조정)  doc-8 Cloudflare 대역 근거(data.cloudflare_ip_ranges + infra/oci/network.tf)
#   K8S    k8s-1 문서 1개(--- 로 나뉜 두 번째 문서 없음)  k8s-2 apiVersion helm.cattle.io/v1  k8s-3 kind HelmChartConfig
#          k8s-4 metadata.name traefik  k8s-5 metadata.namespace kube-system  k8s-6 spec.valuesContent 블록 스칼라 '|-'
#   PARSE  parse-1 valuesContent 전 줄이 파싱된다  parse-2 최상위 키 집합이 정확히 6개
#   V      v-1..v-22 필수 키·정확한 값(chart 40.1.x 철자) — 아래 각 단언 참조
#   X      x-1 10.42.0.0/16 없음  x-2 accessLog: 없음  x-3 defaultMode(대문자 M) 없음  x-4 최상위 log: 없음
#          x-5 RequireAndVerifyClientCert 가 values 에 없음(T043 몫; 헤더 설명은 doc-4 가 요구한다)  x-6 비밀·토큰 패턴 없음
#          x-7 values 에 URL(스킴) 없음 — 클러스터 안은 svc DNS 만  x-8 values 에 image 오버라이드 없음(번들 이미지 고정)
#          x-9 trustedIPs 에 사설·예약 대역 없음
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
    'doc-1', 'doc-2', 'doc-3', 'doc-4', 'doc-5', 'doc-6', 'doc-7', 'doc-8',
    'k8s-1', 'k8s-2', 'k8s-3', 'k8s-4', 'k8s-5', 'k8s-6',
    'parse-1', 'parse-2',
    'v-1', 'v-2', 'v-3', 'v-4', 'v-5', 'v-6', 'v-7', 'v-8', 'v-9', 'v-10', 'v-11',
    'v-12', 'v-13', 'v-14', 'v-15', 'v-16', 'v-17', 'v-18', 'v-19', 'v-20', 'v-21', 'v-22',
    'x-1', 'x-2', 'x-3', 'x-4', 'x-5', 'x-6', 'x-7', 'x-8', 'x-9')

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
# 반환: @{ Scalars = @{path -> raw value}; Seqs = @{path -> string[]}; Keys = @{path -> $true}; Bad = @(줄) }
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
    Assert 'doc-4: header states T043 raises clientAuth to RequireAndVerifyClientCert' (
        (Has $header 'T043') -and (Has $header 'RequireAndVerifyClientCert')
    ) 'header must point at T043 for the mTLS step-up'
    Assert 'doc-5: header carries the operator install procedure (scp + install -m 644 root:root to the manifests dir)' (
        (Has $header 'scp ') -and
        (Has $header 'sudo install -m 644 -o root -g root') -and
        (Has $header '/var/lib/rancher/k3s/server/manifests/traefik-config.yaml')
    ) 'header must show scp then sudo install into /var/lib/rancher/k3s/server/manifests/'
    Assert 'doc-6: header carries the three read-only verification commands' (
        (Has $header 'kubectl -n kube-system get helmchartconfig traefik -o yaml') -and
        (Has $header 'kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik -o wide') -and
        (Has $header 'kubectl -n kube-system logs deploy/traefik')
    ) 'header must show helmchartconfig / traefik pods -o wide / traefik logs'
    Assert 'doc-7: header documents the rollback (delete the file, K3s reconciles back)' (
        (Has $header '되돌리기') -and (Has $header 'sudo rm -f /var/lib/rancher/k3s/server/manifests/traefik-config.yaml')
    ) 'header must document deleting the manifest as the rollback'
    Assert 'doc-8: header records where the Cloudflare IPv4 list comes from' (
        (Has $header 'data.cloudflare_ip_ranges') -and (Has $header 'infra/oci/network.tf')
    ) 'header must name the OpenTofu data source and the NSG file that share the list'
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
        (($topKeys -join ',') -ceq ($wantTop -join ','))
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
    Assert 'v-7: tracing.otlp.enabled = true' (Eq (Scalar $vals 'tracing.otlp.enabled') 'true') "= '$(Scalar $vals 'tracing.otlp.enabled')'"
    Assert 'v-8: tracing.otlp.grpc.enabled = true' (Eq (Scalar $vals 'tracing.otlp.grpc.enabled') 'true') "= '$(Scalar $vals 'tracing.otlp.grpc.enabled')'"
    Assert 'v-9: tracing.otlp.grpc.endpoint = k8s-monitoring-alloy-metrics.monitoring.svc:4317 (service DNS, T098)' (Eq (Scalar $vals 'tracing.otlp.grpc.endpoint') 'k8s-monitoring-alloy-metrics.monitoring.svc:4317') "= '$(Scalar $vals 'tracing.otlp.grpc.endpoint')'"
    Assert 'v-10: tracing.otlp.grpc.insecure = true (plaintext in-cluster gRPC)' (Eq (Scalar $vals 'tracing.otlp.grpc.insecure') 'true') "= '$(Scalar $vals 'tracing.otlp.grpc.insecure')'"
    Assert 'v-11: tracing.sampleRate = 0.1' (Eq (Scalar $vals 'tracing.sampleRate') '0.1') "= '$(Scalar $vals 'tracing.sampleRate')'"
    Assert 'v-12: ports.web.http.redirections.entryPoint.to = websecure' (Eq (Scalar $vals 'ports.web.http.redirections.entryPoint.to') 'websecure') "= '$(Scalar $vals 'ports.web.http.redirections.entryPoint.to')'"
    Assert 'v-13: ports.web.http.redirections.entryPoint.scheme = https' (Eq (Scalar $vals 'ports.web.http.redirections.entryPoint.scheme') 'https') "= '$(Scalar $vals 'ports.web.http.redirections.entryPoint.scheme')'"
    Assert 'v-14: ports.web.http.redirections.entryPoint.permanent = true (301)' (Eq (Scalar $vals 'ports.web.http.redirections.entryPoint.permanent') 'true') "= '$(Scalar $vals 'ports.web.http.redirections.entryPoint.permanent')'"

    $want = @('173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22', '141.101.64.0/18',
        '108.162.192.0/18', '190.93.240.0/20', '188.114.96.0/20', '197.234.240.0/22', '198.41.128.0/17',
        '162.158.0.0/15', '104.16.0.0/13', '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22')
    $trusted = Seq $vals 'ports.websecure.forwardedHeaders.trustedIPs'
    Assert 'v-15: ports.websecure.forwardedHeaders.trustedIPs = the 15 Cloudflare IPv4 CIDRs (data.cloudflare_ip_ranges)' (
        ($trusted.Count -eq $want.Count) -and (($trusted -join ',') -ceq ($want -join ','))
    ) "got $($trusted.Count) entries: $($trusted -join ', ')"

    Assert 'v-16: tlsOptions.default.minVersion = VersionTLS12' (Eq (Scalar $vals 'tlsOptions.default.minVersion') 'VersionTLS12') "= '$(Scalar $vals 'tlsOptions.default.minVersion')'"
    Assert 'v-17: tlsOptions.default.sniStrict = true' (Eq (Scalar $vals 'tlsOptions.default.sniStrict') 'true') "= '$(Scalar $vals 'tlsOptions.default.sniStrict')'"
    Assert 'v-18: tlsOptions.default.clientAuth.clientAuthType = VerifyClientCertIfGiven (observation phase; T043 raises it)' (
        Eq (Scalar $vals 'tlsOptions.default.clientAuth.clientAuthType') 'VerifyClientCertIfGiven'
    ) "= '$(Scalar $vals 'tlsOptions.default.clientAuth.clientAuthType')'"
    $secretNames = Seq $vals 'tlsOptions.default.clientAuth.secretNames'
    Assert 'v-19: tlsOptions.default.clientAuth.secretNames = [cloudflare-origin-pull-ca] (kube-system Secret, key ca.crt)' (
        ($secretNames.Count -eq 1) -and (Eq $secretNames[0] 'cloudflare-origin-pull-ca')
    ) "= $($secretNames -join ', ')"
    Assert 'v-20: ingressRoute.dashboard.enabled = true' (Eq (Scalar $vals 'ingressRoute.dashboard.enabled') 'true') "= '$(Scalar $vals 'ingressRoute.dashboard.enabled')'"
    Assert 'v-21: ingressRoute.dashboard.matchRule pins the traefik.joshuatech.dev host' (
        Eq (Scalar $vals 'ingressRoute.dashboard.matchRule') 'Host(`traefik.joshuatech.dev`)'
    ) "= '$(Scalar $vals 'ingressRoute.dashboard.matchRule')'"
    $eps = Seq $vals 'ingressRoute.dashboard.entryPoints'
    Assert 'v-22: ingressRoute.dashboard.entryPoints = [websecure] (never the internal traefik entrypoint)' (
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
    Assert 'x-5: RequireAndVerifyClientCert is not in valuesContent yet (T043 owns the step-up)' (
        -not (Has $valuesText 'RequireAndVerifyClientCert')
    ) 'enforcing mTLS before the CA Secret exists locks out every TLS client'
    $secretPatterns = @('BEGIN [A-Z ]*PRIVATE KEY', 'BEGIN CERTIFICATE', '(?i)\bpassword\s*:', '(?i)\bapi[_-]?key\s*:', '(?i)\bsecret[_-]?key\s*:', '(?i)\btoken\s*:', 'eyJ[A-Za-z0-9_-]{10,}', '(?i)\bcloudflare_api_token\b')
    $hits = @()
    foreach ($p in $secretPatterns) { if ($raw -cmatch $p) { $hits += $p } }
    Assert 'x-6: no secret-shaped strings anywhere in the file' ($hits.Count -eq 0) ("matched: " + ($hits -join ' | '))
    Assert 'x-7: no URL scheme inside valuesContent (in-cluster targets are service DNS only)' (
        -not ($valuesText -cmatch '(?i)https?://')
    ) 'public hostnames must not be used from inside the cluster (FR-046)'
    Assert 'x-8: no image override in valuesContent (the bundled digest-pinned image stays)' (
        @($valuesRaw | Where-Object { $_ -cmatch '^\s*(image|repository|tag)\s*:' }).Count -eq 0
    ) 'image/tag overrides belong nowhere near a mutable tag'
    $trusted2 = Seq $vals 'ports.websecure.forwardedHeaders.trustedIPs'
    $private = @()
    foreach ($cidr in $trusted2) {
        $ip = ($cidr -split '/')[0]
        $o = @($ip -split '\.')
        if ($o.Count -ne 4) { $private += "$cidr (malformed)"; continue }
        $a = [int]$o[0]; $b = [int]$o[1]
        if ($a -eq 10 -or $a -eq 127 -or ($a -eq 172 -and $b -ge 16 -and $b -le 31) -or ($a -eq 192 -and $b -eq 168) -or ($a -eq 169 -and $b -eq 254) -or $a -eq 0) { $private += $cidr }
    }
    Assert 'x-9: trustedIPs contains no private/reserved range' ($private.Count -eq 0) ("private/reserved: " + ($private -join ', '))
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
