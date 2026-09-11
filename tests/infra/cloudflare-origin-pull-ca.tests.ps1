# tests/infra/cloudflare-origin-pull-ca.tests.ps1 — infra/bootstrap/cloudflare-origin-pull-ca.yaml 정적 검사 스위트 (T043)
# Run: pwsh -NoProfile -File tests/infra/cloudflare-origin-pull-ca.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크·모듈 없음(tests/infra/traefik-config.tests.ps1 과 같은 골격).
# 문자열 비교는 전부 Ordinal([string]::Equals / IndexOf) — PowerShell 의 -eq/-ceq 는 문화권 비교라 U+200B·U+FEFF 같은
# "무시 가능" 코드포인트를 건너뛴다(CLAUDE.md Known Issues). 목록 비교도 -ceq 대신 Eq 헬퍼를 쓴다.
#
# 이 스위트는 원문만 읽는다 · kubectl 없음 · SKIP 없이 fail closed — 파일이 없으면 전 단언 FAIL. 인증서 파싱은 .NET 의
# X509Certificate2.CreateFromPem 으로 한다(외부 openssl 없음). 대상은 Cloudflare 가 공개 배포하는 Global AOP 루트 CA 이므로
# 이 스위트가 지키는 것은 "비밀 유출 없음"이 아니라 "정확히 그 공개 CA 하나만, 개인키 없이, 계약 지문 그대로" 다.
#
# 검사 계약(이 스위트가 곧 계약이다 — 지문·만료의 정본은 contracts/hostnames-and-access.md §오리진 보호 3중 2.):
#   F   f-1 존재  f-2 CR 바이트 0  f-3 끝 개행 정확히 1개  f-4 BOM 없음  f-5 탭 없음 · 행말 공백 0  f-6 첫 줄이 경로 주석
#   K   k-1 문서 1개(--- 없음) · apiVersion v1 · kind Secret · name cloudflare-origin-pull-ca · namespace kube-system · type Opaque(각 정확히 1줄)
#       k-2 stringData: 1줄 · 그 아래 2칸 키는 정확히 `ca.crt: |` 하나 · 최상위 data: 없음(VD-18 전환 전까지 stringData 고정)
#       k-3 owner 키 없음 — 라벨 owner=helm 은 Traefik Secret informer 가 제외해 "없는 Secret" 이 된다
#   P   p-1 인증서 블록 BEGIN/END 각 정확히 1회 · 개인키 블록 0회  p-2 ca.crt 블록(4칸 들여쓰기 제거)이 X509 로 파싱
#       p-3 Subject 에 CN=origin-pull.cloudflare.net · 자기 서명(Subject == Issuer)  p-4 sha256 지문 == 계약 값(콜론 없는 대문자)
#       p-5 notAfter == 2029-11-01T17:00:00Z
#       p-6 단언 아님(합계 밖) — 'WARN remaining=<n>d' 한 줄(오늘 UTC 기준 잔여일). 180일 미만이면 교체 신호 문구를 덧붙인다. 시한 FAIL 없음.
#           그 줄은 WARN 으로 시작하고 passed/failed 낱말을 쓰지 않는다(run-all 의 요약 정규식과 충돌 방지).
#   D   d-1 머리 주석에 원본 파일명 · 지문 앞자리 9A:1A:C2:B4 · 공개 · 순서 · clientAuth · 2029-11-01 · owner 언급
#       d-2 머리 주석(첫 apiVersion: 줄 이전)에 BEGIN CERTIFICATE / PRIVATE KEY 낱말 없음(p-1 과의 자기 충돌 방지)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$target = Join-Path $repo 'infra/bootstrap/cloudflare-origin-pull-ca.yaml'

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

# 계약 값(contracts/hostnames-and-access.md §오리진 보호 3중 2., 커밋 d9b5662). Cloudflare 가 CA 를 교체하면 계약을 먼저 고친 뒤 이 값을 갱신한다.
$expectedSha256 = '9A1AC2B4BE15F9F27EEE20A734CBA4E9898F61001B3BD7C84B69B56A3E25A2B9'
$expectedNotAfterUtc = [datetime]::new(2029, 11, 1, 17, 0, 0, [DateTimeKind]::Utc)
$expectedCn = 'CN=origin-pull.cloudflare.net'

$allNames = @('f-1', 'f-2', 'f-3', 'f-4', 'f-5', 'f-6',
    'k-1', 'k-2', 'k-3',
    'p-1', 'p-2', 'p-3', 'p-4', 'p-5',
    'd-1', 'd-2')

if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    foreach ($n in $allNames) { Assert $n $false 'missing: infra/bootstrap/cloudflare-origin-pull-ca.yaml' }
    Write-Host "`n$($script:pass) passed, $($script:fail) failed"
    exit 1
}

$rawBytes = [IO.File]::ReadAllBytes($target)
$raw = [Text.Encoding]::UTF8.GetString($rawBytes)
$hasBom = ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF)
if ($hasBom) { $raw = $raw.Substring(1) }
$lines = $raw -split "`n"

# ---------- 머리 주석 / 본문 분리 ----------
# 머리 주석 = 첫 비주석·비공백 줄(apiVersion:) 이전의 줄 전부. d-1/d-2 는 이 문자열만 본다.
$headerLines = @()
foreach ($l in $lines) { if ($l -cmatch '^\s*#' -or $l.Trim().Length -eq 0) { $headerLines += $l } else { break } }
$header = ($headerLines -join "`n")

function Count-Lines([string]$exact) { return @($lines | Where-Object { Eq $_ $exact }).Count }

# ---------- F ----------
Test-Group 'file' {
    Assert 'f-1: infra/bootstrap/cloudflare-origin-pull-ca.yaml exists' $true ''
    $crCount = @($rawBytes | Where-Object { $_ -eq 0x0D }).Count
    Assert 'f-2: zero CR (0x0D) bytes (LF only — .gitattributes forces LF)' ($crCount -eq 0) "CR bytes = $crCount"
    Assert 'f-3: ends with exactly one newline (last byte 0x0A, the byte before it not 0x0A)' (
        $rawBytes.Length -ge 2 -and $rawBytes[$rawBytes.Length - 1] -eq 0x0A -and $rawBytes[$rawBytes.Length - 2] -ne 0x0A
    ) 'no final newline or more than one'
    Assert 'f-4: no UTF-8 BOM' (-not $hasBom) 'BOM found'
    $trailing = @($lines | Where-Object { $_ -cmatch '[ \t]+$' }).Count
    Assert 'f-5: no tab characters and no trailing whitespace' ((-not (Has $raw "`t")) -and $trailing -eq 0) "tab=$(Has $raw "`t"); lines with trailing whitespace = $trailing"
    Assert 'f-6: first line names the file' ($lines.Count -gt 0 -and $lines[0].StartsWith('# infra/bootstrap/cloudflare-origin-pull-ca.yaml', [StringComparison]::Ordinal)) "first line: '$($lines[0])'"
}

# ---------- K: Secret 형태(줄 단위 Ordinal) ----------
Test-Group 'k8s' {
    $docSeparators = @($lines | Where-Object { $_.StartsWith('---', [StringComparison]::Ordinal) }).Count
    $nApi = Count-Lines 'apiVersion: v1'
    $nKind = Count-Lines 'kind: Secret'
    $nName = Count-Lines '  name: cloudflare-origin-pull-ca'
    $nNs = Count-Lines '  namespace: kube-system'
    $nType = Count-Lines 'type: Opaque'
    Assert 'k-1: one document; apiVersion v1 / kind Secret / name cloudflare-origin-pull-ca / namespace kube-system / type Opaque exactly once each' (
        $docSeparators -eq 0 -and $nApi -eq 1 -and $nKind -eq 1 -and $nName -eq 1 -and $nNs -eq 1 -and $nType -eq 1
    ) "separators=$docSeparators apiVersion=$nApi kind=$nKind name=$nName namespace=$nNs type=$nType"

    $sdIndex = -1
    $nStringData = 0
    for ($i = 0; $i -lt $lines.Count; $i++) { if (Eq $lines[$i] 'stringData:') { $nStringData++; if ($sdIndex -lt 0) { $sdIndex = $i } } }
    $sdKeys = @()
    if ($sdIndex -ge 0) {
        for ($i = $sdIndex + 1; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            if ($l.Trim().Length -eq 0) { continue }
            if (-not $l.StartsWith('  ', [StringComparison]::Ordinal)) { break }
            if ($l -cmatch '^  \S') { $sdKeys += $l }
        }
    }
    $nData = @($lines | Where-Object { $_ -cmatch '^data\s*:' }).Count
    Assert 'k-2: stringData: once, its only key is `ca.crt: |`, and no top-level data: key' (
        $nStringData -eq 1 -and $sdKeys.Count -eq 1 -and (Eq $sdKeys[0] '  ca.crt: |') -and $nData -eq 0
    ) "stringData=$nStringData keys=[$($sdKeys -join ' | ')] data=$nData"

    $ownerLines = @($lines | Where-Object { $_ -cmatch '^\s*owner\s*:' }).Count
    Assert 'k-3: no owner key (label owner=helm would make Traefik''s Secret informer skip this Secret)' ($ownerLines -eq 0) "owner key lines = $ownerLines"
}

# ---------- P: PEM 내용 ----------
$cert = $null
$certError = ''
Test-Group 'pem' {
    $nBegin = ([regex]::Matches($raw, '-----BEGIN CERTIFICATE-----')).Count
    $nEnd = ([regex]::Matches($raw, '-----END CERTIFICATE-----')).Count
    $nKey = ([regex]::Matches($raw, '-----BEGIN [A-Z ]*PRIVATE KEY-----')).Count
    Assert 'p-1: exactly one certificate block and no private-key block' ($nBegin -eq 1 -and $nEnd -eq 1 -and $nKey -eq 0) "BEGIN CERTIFICATE=$nBegin END CERTIFICATE=$nEnd PRIVATE KEY=$nKey"

    $caIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if (Eq $lines[$i] '  ca.crt: |') { $caIndex = $i; break } }
    $pemLines = @()
    if ($caIndex -ge 0) {
        for ($i = $caIndex + 1; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            if ($l.StartsWith('    ', [StringComparison]::Ordinal)) { $pemLines += $l.Substring(4) } else { break }
        }
    }
    $pem = ($pemLines -join "`n")
    if ($pemLines.Count -gt 0) {
        try { $script:cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($pem) }
        catch { $script:certError = "$($_.Exception.GetType().Name): $($_.Exception.Message)" }
    }
    else { $script:certError = 'no 4-space-indented block after `  ca.crt: |`' }
    $cert = $script:cert
    Assert 'p-2: the ca.crt block parses as an X.509 certificate (X509Certificate2.CreateFromPem)' ($null -ne $cert) $script:certError

    if ($null -eq $cert) {
        Assert 'p-3: Subject carries CN=origin-pull.cloudflare.net and equals Issuer (self-signed root)' $false 'certificate not parsed'
        Assert 'p-4: SHA-256 fingerprint equals the contract value' $false 'certificate not parsed'
        Assert 'p-5: notAfter equals 2029-11-01T17:00:00Z' $false 'certificate not parsed'
    }
    else {
        Assert 'p-3: Subject carries CN=origin-pull.cloudflare.net and equals Issuer (self-signed root)' (
            (Has $cert.Subject $expectedCn) -and (Eq $cert.Subject $cert.Issuer)
        ) "subject='$($cert.Subject)' issuer='$($cert.Issuer)'"
        $fp = $cert.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256)
        Assert 'p-4: SHA-256 fingerprint equals the contract value' (Eq $fp $expectedSha256) "fingerprint=$fp expected=$expectedSha256"
        $notAfterUtc = $cert.NotAfter.ToUniversalTime()
        Assert 'p-5: notAfter equals 2029-11-01T17:00:00Z' ($notAfterUtc.Ticks -eq $expectedNotAfterUtc.Ticks) "notAfter=$($notAfterUtc.ToString('o'))"
    }
}

# ---------- p-6: 잔여일 WARN(단언 아님, 합계 밖) ----------
if ($null -ne $cert) {
    $remaining = [int][math]::Floor(($cert.NotAfter.ToUniversalTime() - [datetime]::UtcNow).TotalDays)
    $warn = "WARN remaining=${remaining}d (notAfter $($cert.NotAfter.ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC)"
    if ($remaining -lt 180) { $warn += ' — 교체 신호(분기 지문 대조 절차)' }
    Write-Host $warn
}
else {
    Write-Host 'WARN remaining=unknown (certificate not parsed)'
}

# ---------- D: 머리 주석 = 운영 계약 ----------
Test-Group 'doc' {
    $needles = @('authenticated_origin_pull_ca.pem', '9A:1A:C2:B4', '공개', '순서', 'clientAuth', '2029-11-01', 'owner')
    $missing = @($needles | Where-Object { -not (Has $header $_) })
    Assert 'd-1: header names the source file, fingerprint prefix, public nature, ordering rule, clientAuth, expiry and the owner label' (
        $missing.Count -eq 0
    ) ("missing: " + ($missing -join ', '))
    Assert 'd-2: header never spells BEGIN CERTIFICATE or PRIVATE KEY (keeps p-1 unambiguous)' (
        (-not (Has $header 'BEGIN CERTIFICATE')) -and (-not (Has $header 'PRIVATE KEY'))
    ) 'the header must describe the block without quoting PEM markers'
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
