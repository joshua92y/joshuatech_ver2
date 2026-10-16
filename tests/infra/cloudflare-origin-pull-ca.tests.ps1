# tests/infra/cloudflare-origin-pull-ca.tests.ps1 — infra/bootstrap/cloudflare-origin-pull-ca.yaml 정적 검사 스위트 (T043)
# Run: pwsh -NoProfile -File tests/infra/cloudflare-origin-pull-ca.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크·모듈 없음(tests/infra/traefik-config.tests.ps1 과 같은 골격).
# 문자열 비교는 전부 Ordinal([string]::Equals / IndexOf) — PowerShell 의 -eq/-ceq 는 문화권 비교라 U+200B·U+FEFF 같은
# "무시 가능" 코드포인트를 건너뛴다(CLAUDE.md Known Issues). 목록 비교도 -ceq 대신 Eq 헬퍼를 쓴다. 허용 목록 조회도 Eq 로 한다.
#
# 이 스위트는 원문만 읽는다 · kubectl 없음 · SKIP 없이 fail closed — 파일이 없으면 전 단언 FAIL. 인증서 파싱은 .NET 의
# X509Certificate2Collection.ImportFromPem 으로 한다(외부 openssl 없음 · 블록 전부 읽음 — CreateFromPem 은 첫 블록만 돌려준다).
# 대상은 Cloudflare 가 공개 배포하는 Global AOP 루트 CA 이므로 이 스위트가 지키는 것은 "비밀 유출 없음"이 아니라
# "허용 목록 안의 공개 CA 만, 개인키 없이, 계약 지문·만료 그대로" 다. 회전 창(옛+새 병기)은 허용하되 모든 블록이 목록 안이어야 한다.
#
# 검사 계약(이 스위트가 곧 계약이다 — 지문·만료의 정본은 contracts/hostnames-and-access.md §오리진 보호 3중 2.):
#   F   f-1 존재  f-2 CR 바이트 0  f-3 끝 개행 정확히 1개  f-4 BOM 없음  f-5 탭 없음 · 행말 공백 0  f-6 첫 줄이 경로 주석
#   K   k-1 문서 1개(--- 없음) · apiVersion v1 · kind Secret · metadata: · name cloudflare-origin-pull-ca · namespace kube-system · type Opaque
#           (각 정확히 1줄)
#       k-2 stringData: 1줄 · 그 아래 2칸 키는 정확히 `ca.crt: |` 하나 · 최상위 data: 없음(VD-18 전환 전까지 stringData 고정)
#       k-3 owner 키 없음 · 본문(첫 apiVersion: 줄부터 끝까지)에 labels 키 없음 · 본문 텍스트에 'owner' 문자열 없음
#           — flow-style `labels: {owner: helm}` 도 차단(라벨 owner=helm 은 Traefik Secret informer 가 제외해 "없는 Secret" 이 된다)
#       k-4 최상위 키 집합·순서 고정: 주석·빈 줄 제외, 열 0 키가 순서대로 정확히 apiVersion,kind,metadata,type,stringData
#   P   p-1 인증서 블록 BEGIN ≥1 · BEGIN == END · 개인키 블록 0회 — 회전 창(옛+새 병기) 허용
#       p-2 ca.crt 블록(4칸 들여쓰기 제거)이 X509Certificate2Collection.ImportFromPem 으로 전부 파싱(개수 == BEGIN 수, ≥1)
#       p-3 모든 인증서: Subject 에 CN=origin-pull.cloudflare.net · 자기 서명(Subject == Issuer)
#       p-4 모든 인증서의 sha256 지문(콜론 없는 대문자)이 허용 목록 $allowed 의 키 안 · 현행 정본 지문 9A1A…A2B9 는 반드시 포함
#           (회전 창에도 현행 CA 는 남아 있어야 한다)
#       p-5 모든 인증서의 notAfter == $allowed[그 지문](현행: 2029-11-01T17:00:00Z)
#       p-6 단언 아님(합계 밖) — 'WARN remaining=<n>d' 한 줄(모든 블록 중 최소 잔여일, 오늘 UTC 기준). 180일 미만이면 교체 신호 문구를
#           덧붙인다. 시한 FAIL 없음. 그 줄은 WARN 으로 시작하고 passed/failed 낱말을 쓰지 않는다(run-all 의 요약 정규식과 충돌 방지).
#   D   d-1 머리 주석에 블록 특정 리터럴 전부: 원본 파일명 · 콜론형 전체 지문($expectedSha256 에서 파생 — 하드코딩 금지) · 2029-11-01 ·
#           origin-pull.cloudflare.net · 투입/제거 순서 문장 · tlsoption jsonpath 명령 · CAFiles is required · brokenTLSRouter · owner=helm ·
#           does not exist · Failed to extract CA · $allowed(회전 절차가 허용 목록을 가리키는지)
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
# $expectedSha256 = 현행 정본 지문(회전 창에도 반드시 남아 있어야 한다). $allowed = 허용 목록(지문 → notAfter UTC); 회전 시 새 항목을 추가한다.
$expectedSha256 = '9A1AC2B4BE15F9F27EEE20A734CBA4E9898F61001B3BD7C84B69B56A3E25A2B9'
# 허용 목록(지문 → notAfter, UTC). 키는 GetCertHashString 출력 그대로 **대문자**이고 대조는 Ordinal(대소문자 구분)이다 — PowerShell 해시테이블
# 인덱서는 대소문자를 무시하므로 조회는 Get-AllowedKey 로만 한다. 회전(옛+새 병기) 시 새 항목을 추가하고 옛 항목은 옛 블록을 제거할 때 같이 지운다.
$allowed = @{ '9A1AC2B4BE15F9F27EEE20A734CBA4E9898F61001B3BD7C84B69B56A3E25A2B9' = [datetime]::new(2029, 11, 1, 17, 0, 0, [DateTimeKind]::Utc) }
$expectedCn = 'CN=origin-pull.cloudflare.net'

# 허용 목록 조회는 Ordinal 로만(PowerShell 해시테이블 키 조회는 대소문자 무시 비교라 쓰지 않는다).
function Get-AllowedKey([string]$fp) {
    foreach ($k in $allowed.Keys) { if (Eq $k $fp) { return $k } }
    return $null
}

$allNames = @('f-1', 'f-2', 'f-3', 'f-4', 'f-5', 'f-6',
    'k-1', 'k-2', 'k-3', 'k-4',
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
# 본문 = 첫 `apiVersion:` 줄부터 끝까지(k-3 의 labels/owner 검사 범위). apiVersion: 줄이 없으면 파일 전체를 본문으로 본다(fail closed).
$headerLines = @()
foreach ($l in $lines) { if ($l -cmatch '^\s*#' -or $l.Trim().Length -eq 0) { $headerLines += $l } else { break } }
$header = ($headerLines -join "`n")

$bodyStart = -1
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].StartsWith('apiVersion:', [StringComparison]::Ordinal)) { $bodyStart = $i; break } }
if ($bodyStart -lt 0) { $bodyStart = 0 }
$bodyLines = @($lines[$bodyStart..($lines.Count - 1)])
$bodyText = ($bodyLines -join "`n")   # 이름 주의: Test-Group 의 [scriptblock]$body 파라미터와 겹치지 않게 한다

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
    $nMeta = Count-Lines 'metadata:'
    $nName = Count-Lines '  name: cloudflare-origin-pull-ca'
    $nNs = Count-Lines '  namespace: kube-system'
    $nType = Count-Lines 'type: Opaque'
    Assert 'k-1: one document; apiVersion v1 / kind Secret / metadata: / name cloudflare-origin-pull-ca / namespace kube-system / type Opaque exactly once each' (
        $docSeparators -eq 0 -and $nApi -eq 1 -and $nKind -eq 1 -and $nMeta -eq 1 -and $nName -eq 1 -and $nNs -eq 1 -and $nType -eq 1
    ) "separators=$docSeparators apiVersion=$nApi kind=$nKind metadata=$nMeta name=$nName namespace=$nNs type=$nType"

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
    $labelsLines = @($bodyLines | Where-Object { $_ -cmatch '^\s*labels\s*:' }).Count
    # 'owner' 부분 문자열 검사는 PEM(4칸 들여쓰기 base64) 줄을 제외한 본문 줄만 본다 — base64 우연 일치로 인한 오탐 방지.
    $bodyHasOwner = (@($bodyLines | Where-Object { -not $_.StartsWith('    ', [StringComparison]::Ordinal) } | Where-Object { Has $_ 'owner' })).Count -gt 0
    Assert 'k-3: no owner key, no labels key in the body, and the body never contains "owner" (label owner=helm — flow style included — would make Traefik''s Secret informer skip this Secret)' (
        $ownerLines -eq 0 -and $labelsLines -eq 0 -and (-not $bodyHasOwner)
    ) "owner key lines = $ownerLines; labels lines in body = $labelsLines; body contains 'owner' = $bodyHasOwner"

    $topKeys = @()
    foreach ($l in $lines) {
        if ($l -cmatch '^\s*#' -or $l.Trim().Length -eq 0) { continue }
        $m = [regex]::Match($l, '^([A-Za-z][A-Za-z0-9.-]*):')
        if ($m.Success) { $topKeys += $m.Groups[1].Value }
    }
    $topKeyList = ($topKeys -join ',')
    Assert 'k-4: top-level keys are exactly apiVersion,kind,metadata,type,stringData in that order (no extra key, no reordering)' (
        Eq $topKeyList 'apiVersion,kind,metadata,type,stringData'
    ) "keys=[$topKeyList]"
}

# ---------- P: PEM 내용(블록 전부) ----------
$script:certs = $null
$script:certError = ''
Test-Group 'pem' {
    $nBegin = ([regex]::Matches($raw, '-----BEGIN CERTIFICATE-----')).Count
    $nEnd = ([regex]::Matches($raw, '-----END CERTIFICATE-----')).Count
    $nKey = ([regex]::Matches($raw, '-----BEGIN [A-Z ]*PRIVATE KEY-----')).Count
    Assert 'p-1: one or more certificate blocks (BEGIN == END) and no private-key block — 회전 창(옛+새 병기) 허용' (
        ($nBegin -ge 1) -and ($nBegin -eq $nEnd) -and ($nKey -eq 0)
    ) "BEGIN CERTIFICATE=$nBegin END CERTIFICATE=$nEnd PRIVATE KEY=$nKey"

    $caIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if (Eq $lines[$i] '  ca.crt: |') { $caIndex = $i; break } }
    $pemLines = @()
    if ($caIndex -ge 0) {
        for ($i = $caIndex + 1; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            # 빈 줄은 블록 스칼라의 일부(옛+새 병기 사이의 빈 줄)이므로 종료 조건이 아니다 — k-2 루프와 같은 규칙. 최상위 키는 4칸 들여쓰기가 아니므로 종료는 그대로.
            if ($l.Trim().Length -eq 0) { continue }
            if ($l.StartsWith('    ', [StringComparison]::Ordinal)) { $pemLines += $l.Substring(4) } else { break }
        }
    }
    $pem = ($pemLines -join "`n")
    if ($pemLines.Count -gt 0) {
        try {
            $col = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
            $col.ImportFromPem($pem)
            $script:certs = $col
        }
        catch { $script:certError = "$($_.Exception.GetType().Name): $($_.Exception.Message)" }
    }
    else { $script:certError = 'no 4-space-indented block after `  ca.crt: |`' }
    $certs = $script:certs
    $nCerts = 0
    if ($null -ne $certs) { $nCerts = $certs.Count }
    Assert 'p-2: every ca.crt block parses as X.509 (X509Certificate2Collection.ImportFromPem; parsed count == BEGIN count, >= 1)' (
        ($nCerts -ge 1) -and ($nCerts -eq $nBegin)
    ) "parsed=$nCerts BEGIN=$nBegin $script:certError"

    if ($nCerts -lt 1) {
        Assert 'p-3: every certificate carries CN=origin-pull.cloudflare.net in Subject and Subject equals Issuer (self-signed root)' $false 'certificate not parsed'
        Assert 'p-4: every SHA-256 fingerprint is in the allow list $allowed and the current contract fingerprint is present' $false 'certificate not parsed'
        Assert 'p-5: every notAfter equals the allow-list value for its fingerprint (current: 2029-11-01T17:00:00Z)' $false 'certificate not parsed'
    }
    else {
        $badSubject = @()
        $fps = @()
        $notAllowed = @()
        $badExpiry = @()
        foreach ($c in $certs) {
            if (-not ((Has $c.Subject $expectedCn) -and (Eq $c.Subject $c.Issuer))) { $badSubject += "subject='$($c.Subject)' issuer='$($c.Issuer)'" }
            $fp = $c.GetCertHashString([System.Security.Cryptography.HashAlgorithmName]::SHA256)
            $fps += $fp
            $key = Get-AllowedKey $fp
            if ($null -eq $key) { $notAllowed += $fp }
            else {
                $notAfterUtc = $c.NotAfter.ToUniversalTime()
                if ($notAfterUtc.Ticks -ne $allowed[$key].Ticks) { $badExpiry += "$fp notAfter=$($notAfterUtc.ToString('o')) expected=$($allowed[$key].ToString('o'))" }
            }
        }
        $hasCurrent = @($fps | Where-Object { Eq $_ $expectedSha256 }).Count -ge 1
        Assert 'p-3: every certificate carries CN=origin-pull.cloudflare.net in Subject and Subject equals Issuer (self-signed root)' (
            $badSubject.Count -eq 0
        ) ("bad: " + ($badSubject -join ' ; '))
        Assert 'p-4: every SHA-256 fingerprint is in the allow list $allowed and the current contract fingerprint is present' (
            ($notAllowed.Count -eq 0) -and $hasCurrent
        ) "fingerprints=[$($fps -join ',')] notAllowed=[$($notAllowed -join ',')] hasCurrent=$hasCurrent expected=$expectedSha256 allowKeys=[$($allowed.Keys -join ',')] (대조는 Ordinal — 허용 목록 키는 대문자)"
        Assert 'p-5: every notAfter equals the allow-list value for its fingerprint (current: 2029-11-01T17:00:00Z)' (
            ($badExpiry.Count -eq 0) -and ($notAllowed.Count -eq 0)
        ) ("bad: " + (($badExpiry + ($notAllowed | ForEach-Object { "$_ not in allow list" })) -join ' ; '))
    }
}

# ---------- p-6: 잔여일 WARN(단언 아님, 합계 밖) — 모든 블록 중 최소 잔여일 ----------
if ($null -ne $script:certs -and $script:certs.Count -ge 1) {
    $minCert = $null
    foreach ($c in $script:certs) {
        if ($null -eq $minCert -or $c.NotAfter.ToUniversalTime().Ticks -lt $minCert.NotAfter.ToUniversalTime().Ticks) { $minCert = $c }
    }
    $remaining = [int][math]::Floor(($minCert.NotAfter.ToUniversalTime() - [datetime]::UtcNow).TotalDays)
    $warn = "WARN remaining=${remaining}d (min of $($script:certs.Count) block(s); notAfter $($minCert.NotAfter.ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC)"
    if ($remaining -lt 180) { $warn += ' — 교체 신호(분기 지문 대조 절차)' }
    Write-Host $warn
}
else {
    Write-Host 'WARN remaining=unknown (certificate not parsed)'
}

# ---------- D: 머리 주석 = 운영 계약 ----------
Test-Group 'doc' {
    # 콜론형 지문은 $expectedSha256 에서 파생한다(리터럴 하드코딩 금지 — 계약 값이 바뀌면 여기도 같이 움직인다).
    $expectedColon = (($expectedSha256 -split '(..)') | Where-Object { $_ }) -join ':'
    $needles = @(
        'authenticated_origin_pull_ca.pem',
        $expectedColon,
        '2029-11-01',
        'origin-pull.cloudflare.net',
        '투입 = 이 Secret 먼저',
        '제거 = traefik-config.yaml 에서 clientAuth 블록 제거',
        'get tlsoption default -o jsonpath=''{.spec.clientAuth}''',
        'CAFiles is required',
        'brokenTLSRouter',
        'owner=helm',
        'does not exist',
        'Failed to extract CA',
        '$allowed'
    )
    $missing = @($needles | Where-Object { -not (Has $header $_) })
    Assert 'd-1: header carries every block-specific literal (source file, full colon fingerprint, expiry, CN, install/remove order sentences, tlsoption jsonpath check, CAFiles is required, brokenTLSRouter, owner=helm, does not exist, Failed to extract CA, $allowed)' (
        $missing.Count -eq 0
    ) ("missing: " + ($missing -join ', '))
    Assert 'd-2: header never spells BEGIN CERTIFICATE or PRIVATE KEY (keeps p-1 unambiguous)' (
        (-not (Has $header 'BEGIN CERTIFICATE')) -and (-not (Has $header 'PRIVATE KEY'))
    ) 'the header must describe the block without quoting PEM markers'
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
