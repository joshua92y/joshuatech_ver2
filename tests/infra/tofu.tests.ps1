# tests/infra/tofu.tests.ps1 — OpenTofu 인프라 단언 스위트 (T006, test-first)
# Run: pwsh -NoProfile -File tests/infra/tofu.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크 없음(tests/hooks·tests/scripts 하네스와 같은 구조).
#
# 게이트/전제(전부 fail-closed — SKIP 없음):
#   - `tofu`가 PATH에 있어야 한다(없으면 FAIL).
#   - infra/oci·infra/cloudflare 디렉터리에 *.tf가 있어야 한다(T007–T011에서 작성; 그 전에는 이 파일이 빨갛다).
#   - validate 단언은 자격 증명이 필요 없다(`tofu init -backend=false` 후 실행; 네트워크로 provider를 받는다).
#   - [plan] 표시 단언은 `tofu plan`이 성공해야 한다 — 유효한 OCI 자격 증명·변수(TF_VAR_*)가 필요하다.
#     plan이 실패하면 해당 단언은 전부 "plan JSON unavailable"로 FAIL한다(fail closed).
#     `tofu show -json` stdout은 콘솔 코드 페이지와 무관하게 UTF-8로 디코드한다(Invoke-NativeUtf8) — tofu는 항상
#     UTF-8을 내보내는데 CP949 콘솔에서 "Ampere® Altra™" 같은 비ASCII가 깨져 JSON 닫는 따옴표를 삼키던 결함의
#     수정이며, enc-1이 픽스처 왕복으로 회귀를 막는다(호출 전후로 콘솔을 Latin1로 강제·복원하므로 UTF-8 콘솔에서도
#     공허하지 않다).
#     backend 블록이 생기면(T007의 jt-tfstate) plan 전에 완전한 `tofu init`이 선행되어야 한다 —
#     이 스위트가 돌리는 `init -backend=false`는 backend 도입 전에만 충분하다.
#   - [tf-text] 표시 단언은 .tf 원문만 읽는다(plan JSON이 lifecycle prevent_destroy 등 일부 선언을 노출하지
#     않으므로 중괄호 균형 최소 파서로 리소스 블록을 추출해 검사한다). 자격 증명 불필요.
#     주석은 전체 행 `#`/`//`만 지원한다 — 검사 대상 리소스 블록 안에 블록 주석(/* */)이나 행 끝 주석을 두지 않는다.
#
# 구성 계약(T007+ 구현자가 따라야 하는 형태 — 이 스위트가 곧 계약이다):
#   - 리소스는 루트 모듈에 평면 선언(모듈 호출 없음; 이 스위트는 root_module만 순회한다).
#   - 인스턴스 리소스 이름 라벨은 (?i)node[-_]?a / (?i)node[-_]?b 패턴을 포함한다.
#   - NSG는 정확히 2개(T009 문면): platform NSG(라벨에 (?i)node[-_]?a 포함; nsg-node-a-platform) + cluster NSG(라벨에
#     (?i)cluster 포함; nsg-cluster, 두 노드 공유). 인스턴스 create_vnic_details.nsg_ids는 NSG 리소스를 직접 참조한다 —
#     노드 A = {platform, cluster}, 노드 B = {cluster}만(노드 B 전용 NSG 없음).
#   - NSG ingress 규칙은 두 부류뿐이다: platform NSG의 443/tcp ← Cloudflare IPv4 CIDR(source_type CIDR_BLOCK) / cluster NSG의
#     자기참조(source_type NETWORK_SECURITY_GROUP, source = 그 NSG 자신). 그 외 ingress(0.0.0.0/0·다른 포트·local/var 간접
#     배선)는 미분류 = FAIL. EGRESS 규칙은 분류 대상이 아니다(ingress 구멍을 만들 수 없음; 개수만 보고).
#   - platform 규칙의 source는 값과 출처를 둘 다 검사한다: planned 값이 알려져 있으면 0.0.0.0/0은 무조건 거부하고 Cloudflare
#     공표 CIDR 집합($cloudflareCidrs)에 있어야 한다; 표현식은 리터럴 CF CIDR / each.value·each.key(for_each가
#     data.cloudflare_ip_ranges 참조) / data.cloudflare_ip_ranges 직접 참조만 허용한다(var·local 출처는 값이 맞아도 거부).
#     Cloudflare 목록이 바뀌면 $cloudflareCidrs를 갱신해야 한다(그 전까지 새 CIDR 규칙은 FAIL — 의도된 fail closed).
#   - 보안 리스트(oci_core_security_list·oci_core_default_security_list)는 전부 ingress 0이다(egress-only; OCI는 SL ∪ NSG로
#     평가하므로 SL에 ingress가 남으면 NSG 경계가 무의미하다). 리소스 0개면 FAIL.
#   - 인스턴스 planned create_vnic_details[0].nsg_ids가 알려져 있으면(apply 후) 원소 수 = NSG 참조 라벨 수여야 한다
#     (리터럴 OCID 등 참조 없는 NSG가 섞이면 FAIL).
#   - 버킷 이름은 정확히 jt-tfstate·jt-backup·jt-backup-platform (3개 전부, 그 외 없음).
#   - OBJECT_VERSION_DELETE 정책 단언은 선언 존재까지만이다 — 규칙이 실제로 이전 버전을 삭제하는지는
#     VD-6(T010 apply 후 첫 만료 관찰)에서 확인한다.
#   - Cloudflare Access(T008/T011): cloudflare_zero_trust_access_application 블록이 1개 이상 있어야 하고,
#     application·policy 두 타입의 모든 블록이 각각 session_duration을 명시해야 한다(양측 무조건 검사).
#
# 단언 수: 34 (tool 1, enc 1, dir 2, validate 4, plan 2, nsg 4, sl 1, inst 3, bucket 4, iam 5, dg 2, kms 2, lc 2, access 1)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$ociDir = Join-Path $repo 'infra/oci'
$cfDir = Join-Path $repo 'infra/cloudflare'
$script:pass = 0
$script:fail = 0
$script:planJson = $null
$script:planReason = 'plan not attempted'

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 단언 그룹 격리 — 한 그룹의 예외가 나머지를 막지 않는다.
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Clip([string]$s, [int]$max = 400) {
    if ($null -eq $s) { return '' }
    $s = ($s -replace "`r`n", ' ') -replace "`n", ' '
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' } else { return $s }
}

# [plan] 단언: plan JSON이 없으면 사유와 함께 FAIL(fail closed). $body는 @($cond, $detail) 2요소 배열을 돌려준다.
function PlanAssert([string]$name, [scriptblock]$body) {
    if ($null -eq $script:planJson) {
        $script:fail++; Write-Host "FAIL $name -- plan JSON unavailable ($script:planReason)"; return
    }
    $ok = $false; $detail = ''
    try { $r = & $body; $ok = [bool]$r[0]; $detail = [string]$r[1] }
    catch { $ok = $false; $detail = "unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    if ($ok) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $(Clip $detail)" }
}

# 네이티브 실행 — stdout을 콘솔 코드 페이지와 무관하게 UTF-8로 디코드한다. PowerShell은 네이티브 stdout을
# [Console]::OutputEncoding으로 디코드하므로 호출 동안만 UTF-8(BOM 없음)로 바꾸고 finally에서 복원한다
# (CP949 콘솔에서 tofu의 UTF-8 출력 "Ampere® Altra™"가 깨져 JSON 파싱이 실패하던 결함의 수정; enc-1이 회귀 가드).
# stderr는 임시 파일로 받아 UTF-8로 읽어 문자열로 돌려준다.
function Invoke-NativeUtf8([string]$exe, [string[]]$nativeArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('native-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $out = @(); $code = -1; $err = ''
    $prevEncoding = [Console]::OutputEncoding
    try {
        try {
            [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            $out = & $exe @nativeArgs 2> $errFile
            $code = $LASTEXITCODE
        } finally { [Console]::OutputEncoding = $prevEncoding }
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) } else { '' }
    } finally { Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue }
    return @{ out = (@($out | ForEach-Object { "$_" }) -join "`n"); err = $err.Trim(); code = $code }
}

# tofu 실행(-chdir 방식) — Invoke-NativeUtf8 경유.
function Invoke-Tofu([string]$dir, [string[]]$tofuArgs) {
    return Invoke-NativeUtf8 'tofu' (@("-chdir=$dir") + @($tofuArgs))
}

# ---------- plan JSON 순회 헬퍼(전부 방어적 — 키가 없으면 빈 배열/$null) ----------
# 반환은 `, $rs`(comma 래퍼)라 호출 결과를 변수에 받으면 원소 수와 무관하게 평면 배열이다. 단, `@(Get-X ...)`처럼
# 호출을 직접 @()로 감싸면 중첩 배열(Count 1, 원소 = 배열)이 되니 금지 — 변수에 받은 뒤 @($var)로 쓴다.
# `(Get-X ...) | Where-Object`·`foreach ($x in (Get-X ...))`는 괄호가 배열 객체를 평가하므로 안전하다.
function Get-Planned([string]$type) {
    $rs = @()
    $j = $script:planJson
    if ($j -and $j.planned_values -and $j.planned_values.root_module -and $j.planned_values.root_module.resources) {
        $rs = @($j.planned_values.root_module.resources | Where-Object { "$($_.type)" -eq $type })
    }
    return , $rs
}
function Get-Config([string]$type) {
    $rs = @()
    $j = $script:planJson
    if ($j -and $j.configuration -and $j.configuration.root_module -and $j.configuration.root_module.resources) {
        $rs = @($j.configuration.root_module.resources | Where-Object { "$($_.type)" -eq $type })
    }
    return , $rs
}
# configuration 표현식의 references 배열(없으면 빈 배열)
function Get-Refs($expr) {
    if ($null -eq $expr -or $null -eq $expr.references) { return , @() }
    return , @($expr.references | ForEach-Object { "$_" })
}
# 한 configuration 리소스 주소에 대응하는 planned 인스턴스들(count/for_each면 address[key] 꼴)
function Get-PlannedFor([string]$address) {
    $rs = @()
    $j = $script:planJson
    if ($j -and $j.planned_values -and $j.planned_values.root_module -and $j.planned_values.root_module.resources) {
        $rs = @($j.planned_values.root_module.resources | Where-Object {
                "$($_.address)" -eq $address -or "$($_.address)".StartsWith($address + '[', [StringComparison]::Ordinal)
            })
    }
    return , $rs
}

# ---------- [tf-text] 최소 파서: resource "<type>" "<name>" { ... } 블록을 중괄호 균형으로 추출 ----------
# 선언 존재 단언 전용(문자열 내부 중괄호는 따옴표 상태로 무시, 행 주석 제거). heredoc은 지원하지 않는다.
function Get-TfResourceBlocks([string]$dir, [string]$type) {
    $blocks = @()
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return , $blocks }
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -Filter '*.tf')) {
        $raw = [IO.File]::ReadAllText($f.FullName)
        $text = (($raw -split "`n") | ForEach-Object { $_ -replace '^\s*(#|//).*$', '' }) -join "`n"
        $rx = [regex]('resource\s+"' + [regex]::Escape($type) + '"\s+"([A-Za-z0-9_-]+)"\s*\{')
        foreach ($m in $rx.Matches($text)) {
            $i = $m.Index + $m.Length
            $depth = 1; $inStr = $false; $j = $i
            while ($j -lt $text.Length -and $depth -gt 0) {
                $ch = $text[$j]
                if ($inStr) {
                    if ($ch -eq '"') {
                        # 닫는 따옴표는 바로 앞 백슬래시 런이 짝수일 때만 유효하다("...\\" 같은 이스케이프 짝 처리)
                        $bs = 0; $k = $j - 1
                        while ($k -ge $i -and $text[$k] -eq '\') { $bs++; $k-- }
                        if ($bs % 2 -eq 0) { $inStr = $false }
                    }
                }
                elseif ($ch -eq '"') { $inStr = $true }
                elseif ($ch -eq '{') { $depth++ }
                elseif ($ch -eq '}') { $depth-- }
                $j++
            }
            $blocks += @{ name = $m.Groups[1].Value; body = $text.Substring($i, [Math]::Max(0, $j - $i - 1)); file = $f.Name }
        }
    }
    return , $blocks
}

# Cloudflare 공표 IPv4 CIDR(리터럴 source 대조용 — data.cloudflare_ip_ranges 참조가 우선이며 항상 허용된다)
# 출처: https://www.cloudflare.com/ips-v4 (2026-09-02 기준 — 목록이 바뀌면 이 배열을 갱신한다)
$cloudflareCidrs = @(
    '173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22', '141.101.64.0/18',
    '108.162.192.0/18', '190.93.240.0/20', '188.114.96.0/20', '197.234.240.0/22', '198.41.128.0/17',
    '162.158.0.0/15', '104.16.0.0/13', '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22'
)

$planFile = Join-Path ([IO.Path]::GetTempPath()) ('tofu-plan-' + [guid]::NewGuid().ToString('N') + '.tfplan')
try {
    # ---------- 0. 도구·디렉터리 게이트 ----------
    $tofuOk = $null -ne (Get-Command tofu -ErrorAction SilentlyContinue)
    Assert 'tool-1: tofu on PATH' $tofuOk 'tofu not found on PATH -- install OpenTofu (fail closed; this suite never SKIPs)'

    # ---------- 0b. stdout 디코드 회귀 가드(자격 증명·tofu 불필요) ----------
    # 자식 pwsh가 UTF-8 픽스처의 바이트를 인코딩 변환 없이 stdout에 그대로 쓴다(tofu가 UTF-8 JSON을 내보내는 상황의 재현).
    # 그 출력이 [plan] JSON과 같은 디코드 경로(Invoke-NativeUtf8)를 거쳐 파싱되고 "Ampere® Altra™"가 원문 그대로여야 한다.
    # 픽스처에 비ASCII 바이트가 없거나 BOM이 있으면 가드가 공허해지므로 FAIL(fail closed).
    # 호출 전후로 콘솔 OutputEncoding을 Latin1(비UTF-8)로 강제·복원한다 — UTF-8(65001) 콘솔에서는 스왑이 빠져도 통과하는
    # 공허함을 막는다. 호출 뒤 인코딩이 강제값 그대로인지도 검사한다(Invoke-NativeUtf8의 finally 복원 검증).
    Test-Group 'enc-1' {
        $encName = 'enc-1: native stdout decodes as UTF-8 regardless of console code page (fixture JSON round-trip via Invoke-NativeUtf8)'
        $fixture = Join-Path $PSScriptRoot 'fixtures/show-json-utf8.json'
        $expected = "3.0 GHz Ampere`u{00AE} Altra`u{2122} processor"
        if (-not (Test-Path -LiteralPath $fixture -PathType Leaf)) { Assert $encName $false "fixture missing: $fixture"; return }
        $bytes = [IO.File]::ReadAllBytes($fixture)
        $nonAscii = 0; foreach ($b in $bytes) { if ($b -ge 0x80) { $nonAscii++ } }
        if ($nonAscii -eq 0) { Assert $encName $false "fixture $fixture has no non-ASCII bytes -- the guard would be vacuous (fail closed)"; return }
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { Assert $encName $false "fixture $fixture must be UTF-8 without BOM"; return }
        $fixtureLit = "'" + $fixture.Replace("'", "''") + "'"
        $child = "`$s = [Console]::OpenStandardOutput(); `$b = [IO.File]::ReadAllBytes($fixtureLit); `$s.Write(`$b, 0, `$b.Length); `$s.Flush()"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($child))
        $forced = [Text.Encoding]::Latin1
        $before = [Console]::OutputEncoding
        $r = $null; $afterCall = $null
        try {
            [Console]::OutputEncoding = $forced
            $r = Invoke-NativeUtf8 'pwsh' @('-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded)
            $afterCall = [Console]::OutputEncoding
        } finally { [Console]::OutputEncoding = $before }
        $got = $null; $parseErr = ''
        try { $fj = $r.out | ConvertFrom-Json; $got = "$($fj.planned_values.root_module.resources[0].values.shape_config[0].processor_description)" } catch { $parseErr = $_.Exception.Message }
        $restoreOk = ($null -ne $afterCall -and $afterCall.CodePage -eq $forced.CodePage)
        $ok = ($r.code -eq 0 -and $parseErr -eq '' -and [string]::Equals($got, $expected, [StringComparison]::Ordinal) -and $restoreOk)
        $afterTxt = if ($null -eq $afterCall) { 'n/a' } else { "$($afterCall.CodePage)" }
        Assert $encName $ok (Clip "console before=$($before.CodePage) forced=$($forced.CodePage) after-call=$afterTxt (restore ok=$restoreOk); exit=$($r.code) non-ascii bytes=$nonAscii parse=[$parseErr] got=[$got] expected=[$expected] err=$($r.err)")
    }

    $ociTf = if (Test-Path -LiteralPath $ociDir -PathType Container) { @(Get-ChildItem -LiteralPath $ociDir -File -Filter '*.tf').Count } else { 0 }
    $cfTf = if (Test-Path -LiteralPath $cfDir -PathType Container) { @(Get-ChildItem -LiteralPath $cfDir -File -Filter '*.tf').Count } else { 0 }
    Assert 'dir-1: infra/oci contains *.tf' ($ociTf -gt 0) "missing or empty: $ociDir (written in T007+)"
    Assert 'dir-2: infra/cloudflare contains *.tf' ($cfTf -gt 0) "missing or empty: $cfDir (written in T008+)"

    # ---------- 1. validate (자격 증명 불필요; init -backend=false 선행) ----------
    foreach ($t in @(@{ n = 'oci'; path = $ociDir; ok = ($ociTf -gt 0) }, @{ n = 'cloudflare'; path = $cfDir; ok = ($cfTf -gt 0) })) {
        $initName = "validate-$($t.n)-1: tofu init -backend=false succeeds"
        $valName = "validate-$($t.n)-2: tofu validate -json reports valid"
        if (-not $tofuOk -or -not $t.ok) {
            Assert $initName $false 'precondition failed (needs tofu on PATH + *.tf present)'
            Assert $valName $false 'precondition failed (needs tofu on PATH + *.tf present)'
            continue
        }
        Test-Group $initName {
            $r = Invoke-Tofu $t.path @('init', '-backend=false', '-input=false', '-no-color')
            Assert $initName ($r.code -eq 0) (Clip "exit=$($r.code) err=$($r.err)")
            $v = Invoke-Tofu $t.path @('validate', '-json', '-no-color')
            $valid = $false
            try { $vj = $v.out | ConvertFrom-Json; $valid = ($v.code -eq 0 -and $vj.valid -eq $true) } catch { $valid = $false }
            Assert $valName $valid (Clip "exit=$($v.code) out=$($v.out) err=$($v.err)")
        }
    }

    # ---------- 2. plan [plan 게이트: 여기 실패하면 아래 [plan] 단언은 전부 fail-closed FAIL] ----------
    if (-not $tofuOk -or $ociTf -eq 0) {
        $script:planReason = 'preconditions unmet: tofu on PATH + infra/oci/*.tf required'
        Assert 'plan-1: tofu plan -detailed-exitcode succeeds (needs OCI credentials/TF_VAR_*)' $false $script:planReason
    } else {
        Test-Group 'plan-1' {
            $r = Invoke-Tofu $ociDir @('plan', '-detailed-exitcode', '-input=false', '-lock=false', '-no-color', "-out=$planFile")
            if ($r.code -eq 0 -or $r.code -eq 2) {
                Assert 'plan-1: tofu plan -detailed-exitcode succeeds (needs OCI credentials/TF_VAR_*)' $true ''
                $s = Invoke-Tofu $ociDir @('show', '-json', $planFile)
                if ($s.code -eq 0) {
                    try { $script:planJson = $s.out | ConvertFrom-Json } catch { $script:planReason = "tofu show -json output did not parse: $($_.Exception.Message)" }
                } else { $script:planReason = (Clip "tofu show -json failed: exit=$($s.code) err=$($s.err)") }
            } else {
                Assert 'plan-1: tofu plan -detailed-exitcode succeeds (needs OCI credentials/TF_VAR_*)' $false (Clip "exit=$($r.code) err=$($r.err) -- run with valid OCI credentials and TF_VAR_*; all [plan] assertions below fail closed")
                $script:planReason = "tofu plan failed (exit=$($r.code))"
            }
        }
    }

    # plan-2 [plan]: destroy/replace 0 — resource_changes에 delete 액션이 하나도 없어야 한다
    PlanAssert 'plan-2: no destroy/replace actions in resource_changes' {
        # 키 자체가 없으면 공허한 통과가 아니라 FAIL이다(fail closed)
        if (-not (@($script:planJson.PSObject.Properties.Name) -contains 'resource_changes')) {
            return , @($false, "plan JSON has no 'resource_changes' key (fail closed -- unexpected show -json shape)")
        }
        $rc = @(); if ($script:planJson.resource_changes) { $rc = @($script:planJson.resource_changes) }
        $bad = @($rc | Where-Object { $_.change -and $_.change.actions -and (@($_.change.actions) -contains 'delete') } |
                ForEach-Object { "$($_.address) [$(@($_.change.actions) -join ',')]" })
        , @(($bad.Count -eq 0), ($bad -join '; '))
    }

    # ---------- 3. NSG [plan] — T009 문면: nsg-node-a-platform(443/tcp ← Cloudflare IPv4, for_each) + nsg-cluster(자기참조 all, 두 노드 공유) ----------
    # plan 시점엔 NSG id가 unknown이라 planned 값의 nsg_ids·(자기참조) source가 비어 있다 — NSG 소속·자기참조·VNIC 배선은
    # configuration의 참조(references)로 판정하고, direction·protocol·port·source_type·CIDR source는 planned 값으로 판정한다.
    $nsgAll = @(); $nsgPlatform = @(); $nsgCluster = @()
    if ($script:planJson) {
        $nsgAll = Get-Config 'oci_core_network_security_group'
        $nsgPlatform = @($nsgAll | Where-Object { "$($_.name)" -match '(?i)node[-_]?a' })
        $nsgCluster = @($nsgAll | Where-Object { "$($_.name)" -match '(?i)cluster' -and "$($_.name)" -notmatch '(?i)node[-_]?[ab]' })
    }
    # NSG 집합 게이트: 정확히 2개(platform 1 + cluster 1). nsg-1..4 전부 이 게이트를 먼저 통과해야 한다 — NSG가 0개일 때
    # "위반 규칙 0개"로 공허하게 PASS하는 일을 막는다(fail closed).
    $nsgSetOk = ($nsgAll.Count -eq 2 -and $nsgPlatform.Count -eq 1 -and $nsgCluster.Count -eq 1)
    $nsgSetDetail = "NSG resources=$($nsgAll.Count) [$(@($nsgAll | ForEach-Object { "$($_.name)" }) -join ', ')] (want exactly 2: platform label ~ node[-_]a, cluster label ~ cluster); platform=$($nsgPlatform.Count), cluster=$($nsgCluster.Count)"

    # 참조 문자열이 NSG 리소스 <label>을 가리키는가 — 정확히 그 주소이거나 그 속성('cluster'가 'cluster_x'에 걸리지 않게 ordinal)
    function Test-NsgRef([string]$ref, [string]$label) {
        $addr = "oci_core_network_security_group.$label"
        return ([string]::Equals($ref, $addr, [StringComparison]::Ordinal) -or $ref.StartsWith($addr + '.', [StringComparison]::Ordinal))
    }
    # Cloudflare 공표 IPv4 CIDR 집합 포함 여부(ordinal)
    function Test-CfCidr([string]$s) {
        foreach ($c in $cloudflareCidrs) { if ([string]::Equals($s, $c, [StringComparison]::Ordinal)) { return $true } }
        return $false
    }
    # 인스턴스 planned create_vnic_details[0].nsg_ids의 원소 수 — 키가 없으면(plan 시점 unknown) $null, null이면 0
    function Get-PlannedVnicNsgCount([string]$address) {
        $pl = Get-PlannedFor $address; $pl = @($pl)
        if ($pl.Count -ne 1) { return $null }
        $v = $null; try { $v = $pl[0].values.create_vnic_details[0] } catch { $v = $null }
        if ($null -eq $v -or -not (@($v.PSObject.Properties.Name) -contains 'nsg_ids')) { return $null }
        if ($null -eq $v.nsg_ids) { return 0 }
        return @($v.nsg_ids).Count
    }
    # 인스턴스 구성의 create_vnic_details[*].nsg_ids가 직접 참조하는 NSG 라벨 집합(정렬; 간접 배선은 빈 집합 = 뒤에서 FAIL)
    function Get-VnicNsgLabels($instCfg) {
        $labels = @{}
        $vnics = $null; try { $vnics = $instCfg.expressions.create_vnic_details } catch { $vnics = $null }
        foreach ($v in @($vnics)) {
            if ($null -eq $v) { continue }
            foreach ($r in (Get-Refs $v.nsg_ids)) {
                $m = [regex]::Match($r, '^oci_core_network_security_group\.([A-Za-z0-9_-]+)')
                if ($m.Success) { $labels[$m.Groups[1].Value] = $true }
            }
        }
        return , @($labels.Keys | Sort-Object)
    }
    # 규칙 리소스가 속한 NSG(구성의 network_security_group_id 직접 참조) → 'platform' | 'cluster' | $null
    function Get-RuleNsg($cfg) {
        $refs = Get-Refs $cfg.expressions.network_security_group_id
        foreach ($n in $nsgPlatform) { foreach ($r in $refs) { if (Test-NsgRef $r "$($n.name)") { return 'platform' } } }
        foreach ($n in $nsgCluster) { foreach ($r in $refs) { if (Test-NsgRef $r "$($n.name)") { return 'cluster' } } }
        return $null
    }
    # ingress 규칙 planned 인스턴스 1개를 분류: 'platform-443-cf' | 'cluster-self' | $null(사유는 $why.Value에 나열)
    function Get-RuleClass($cfg, $pi, [ref]$why) {
        $why.Value = @()
        $nsg = Get-RuleNsg $cfg
        $w = @()
        if ($nsg -eq 'platform') {
            if ("$($pi.values.direction)" -ne 'INGRESS') { $w += "direction='$($pi.values.direction)' (want INGRESS)" }
            if ("$($pi.values.protocol)" -ne '6') { $w += "protocol=$($pi.values.protocol) (want '6'/tcp)" }
            $port = $null
            try { $port = $pi.values.tcp_options[0].destination_port_range[0] } catch { $port = $null }
            if ($null -eq $port -or "$($port.min)" -ne '443' -or "$($port.max)" -ne '443') { $w += 'destination port range != 443..443' }
            if ("$($pi.values.source_type)" -ne 'CIDR_BLOCK') { $w += "source_type=$($pi.values.source_type) (want CIDR_BLOCK)" }
            # source — 값과 출처를 둘 다 검사한다(한쪽이 다른 쪽을 구제하지 않는다).
            # (값) planned 값이 알려져 있으면 0.0.0.0/0은 무조건 거부, 그 외는 Cloudflare 공표 CIDR 집합 포함이어야 한다 —
            #      for_each가 CF data를 참조해도 each.value 누락·concat 등으로 다른 값이 섞이면 여기서 잡힌다.
            # (출처) 표현식은 리터럴 CF CIDR / 참조 없음(정적; 값 검사가 덮는다, 단 값 unknown이면 FAIL) /
            #      data.cloudflare_ip_ranges 직접 참조 / each.value·each.key + for_each가 data.cloudflare_ip_ranges 참조 — 이 넷뿐이다.
            $src = "$($pi.values.source)"
            $known = ($src -ne '')
            if ($known) {
                if ([string]::Equals($src, '0.0.0.0/0', [StringComparison]::Ordinal)) { $w += 'source=0.0.0.0/0 is never allowed' }
                elseif (-not (Test-CfCidr $src)) { $w += "source='$src' (planned value) is not a published Cloudflare IPv4 CIDR" }
            }
            $srcExpr = $null; try { $srcExpr = $cfg.expressions.source } catch { $srcExpr = $null }
            $srcRefs = Get-Refs $srcExpr; $srcRefs = @($srcRefs)
            $feRefs = Get-Refs $cfg.for_each_expression; $feRefs = @($feRefs)
            $srcConst = $null
            if ($null -ne $srcExpr -and (@($srcExpr.PSObject.Properties.Name) -contains 'constant_value')) { $srcConst = "$($srcExpr.constant_value)" }
            $dataDirect = (@($srcRefs | Where-Object { $_ -match '^data\.cloudflare_ip_ranges\.' }).Count -gt 0)
            $viaEach = ((@($srcRefs | Where-Object { $_ -match '^each\.(value|key)$' }).Count -gt 0) -and (@($feRefs | Where-Object { $_ -match '^data\.cloudflare_ip_ranges\.' }).Count -gt 0))
            if ($null -ne $srcConst) {
                if (-not (Test-CfCidr $srcConst)) { $w += "source literal '$srcConst' is not a published Cloudflare IPv4 CIDR" }
            }
            elseif ($srcRefs.Count -eq 0) {
                if (-not $known) { $w += 'source has no references and no known planned value -- fail closed' }
            }
            elseif (-not ($dataDirect -or $viaEach)) {
                $w += "source expression refs [$($srcRefs -join ',')] (for_each refs [$($feRefs -join ',')]) are not an allowed form: literal Cloudflare CIDR | each.value/each.key over a data.cloudflare_ip_ranges for_each | direct data.cloudflare_ip_ranges reference"
            }
            if ($w.Count -eq 0) { return 'platform-443-cf' }
        }
        elseif ($nsg -eq 'cluster') {
            if ("$($pi.values.direction)" -ne 'INGRESS') { $w += "direction='$($pi.values.direction)' (want INGRESS)" }
            if ("$($pi.values.source_type)" -ne 'NETWORK_SECURITY_GROUP') { $w += "source_type=$($pi.values.source_type) (want NETWORK_SECURITY_GROUP self-reference)" }
            $selfRef = $false
            foreach ($r in (Get-Refs $cfg.expressions.source)) { foreach ($n in $nsgCluster) { if (Test-NsgRef $r "$($n.name)") { $selfRef = $true } } }
            if (-not $selfRef) { $w += 'source does not reference the cluster NSG itself (not a self-reference)' }
            if ($w.Count -eq 0) { return 'cluster-self' }
        }
        else { $w += 'network_security_group_id does not reference the platform or cluster NSG directly (locals/vars indirection or an unexpected NSG)' }
        $why.Value = $w
        return $null
    }

    PlanAssert 'nsg-1: exactly 2 NSGs (platform + cluster); node A VNIC nsg_ids = {platform, cluster}; node B VNIC nsg_ids = {cluster} only (no platform NSG, no node-B-only NSG)' {
        if (-not $nsgSetOk) { return , @($false, $nsgSetDetail) }
        $ic = Get-Config 'oci_core_instance'
        $ia = @($ic | Where-Object { "$($_.name)" -match '(?i)node[-_]?a' })
        $ib = @($ic | Where-Object { "$($_.name)" -match '(?i)node[-_]?b' })
        if ($ia.Count -ne 1 -or $ib.Count -ne 1) { return , @($false, "instance configs: nodeA=$($ia.Count), nodeB=$($ib.Count) (want exactly 1 each)") }
        $pl = "$($nsgPlatform[0].name)"; $cl = "$($nsgCluster[0].name)"
        $wantA = @(@($pl, $cl) | Sort-Object)
        $la = Get-VnicNsgLabels $ia[0]; $lb = Get-VnicNsgLabels $ib[0]
        $aOk = [string]::Equals(($la -join ','), ($wantA -join ','), [StringComparison]::Ordinal)
        $bOk = [string]::Equals(($lb -join ','), $cl, [StringComparison]::Ordinal)
        # planned nsg_ids가 알려져 있으면(apply 후) 원소 수 = 참조 라벨 수 — 리터럴 OCID 등 참조 없는 NSG가 섞이면 여기서 잡힌다.
        # unknown(plan 시점, 키 없음)이면 구성 참조만으로 판정한다.
        $xa = Get-PlannedVnicNsgCount "$($ia[0].address)"; $xb = Get-PlannedVnicNsgCount "$($ib[0].address)"
        $xaOk = ($null -eq $xa -or $xa -eq $la.Count); $xbOk = ($null -eq $xb -or $xb -eq $lb.Count)
        $xaTxt = if ($null -eq $xa) { 'unknown' } else { "$xa" }; $xbTxt = if ($null -eq $xb) { 'unknown' } else { "$xb" }
        , @(($aOk -and $bOk -and $xaOk -and $xbOk), "nodeA nsg_ids -> [$($la -join ', ')] (want [$($wantA -join ', ')]), planned elements=$xaTxt (want $($la.Count) or unknown); nodeB nsg_ids -> [$($lb -join ', ')] (want [$cl]), planned elements=$xbTxt (want $($lb.Count) or unknown)")
    }

    PlanAssert 'nsg-2: platform NSG ingress rules are only 443/tcp from Cloudflare IPv4 CIDRs (CIDR_BLOCK; literal set or data.cloudflare_ip_ranges ref), >= 1 rule' {
        if (-not $nsgSetOk) { return , @($false, $nsgSetDetail) }
        $ruleCfg = Get-Config 'oci_core_network_security_group_security_rule'
        $n = 0; $egress = 0; $bad = @()
        foreach ($rc in @($ruleCfg | Where-Object { (Get-RuleNsg $_) -eq 'platform' })) {
            $insts = Get-PlannedFor $rc.address
            if ($insts.Count -eq 0) { $bad += "$($rc.address): no planned instance (unknown count/for_each?) -- fail closed"; continue }
            foreach ($pi in $insts) {
                if ("$($pi.values.direction)" -eq 'EGRESS') { $egress++; continue }
                $n++
                $why = @()
                if ((Get-RuleClass $rc $pi ([ref]$why)) -ne 'platform-443-cf') { $bad += "$($pi.address): $($why -join '; ')" }
            }
        }
        , @(($n -ge 1 -and $bad.Count -eq 0), "platform ingress rules=$n (egress skipped=$egress); $($bad -join ' | ')")
    }

    # 노드 B에 붙은 NSG(nsg-1이 {cluster}만이라고 단언)의 모든 ingress 규칙이 cluster 자기참조여야 한다 — CIDR 출처 ingress 0.
    PlanAssert 'nsg-3: node B has no CIDR-sourced ingress -- every ingress rule on every NSG attached to node B is the cluster NSG self-reference' {
        if (-not $nsgSetOk) { return , @($false, $nsgSetDetail) }
        $ib = @((Get-Config 'oci_core_instance') | Where-Object { "$($_.name)" -match '(?i)node[-_]?b' })
        if ($ib.Count -ne 1) { return , @($false, "node B instance configs=$($ib.Count) (want exactly 1)") }
        $lb = Get-VnicNsgLabels $ib[0]
        if ($lb.Count -eq 0) { return , @($false, 'node B VNIC references no NSG resource directly (nsg_ids empty or indirect) -- fail closed') }
        $ruleCfg = Get-Config 'oci_core_network_security_group_security_rule'
        $n = 0; $egress = 0; $bad = @()
        foreach ($rc in $ruleCfg) {
            $attached = $false
            foreach ($r in (Get-Refs $rc.expressions.network_security_group_id)) { foreach ($l in $lb) { if (Test-NsgRef $r $l) { $attached = $true } } }
            if (-not $attached) { continue }
            $insts = Get-PlannedFor $rc.address
            if ($insts.Count -eq 0) { $bad += "$($rc.address): no planned instance (unknown count/for_each?) -- fail closed"; continue }
            foreach ($pi in $insts) {
                if ("$($pi.values.direction)" -eq 'EGRESS') { $egress++; continue }
                $n++
                $why = @()
                if ((Get-RuleClass $rc $pi ([ref]$why)) -ne 'cluster-self') { $bad += "$($pi.address): source_type=$($pi.values.source_type) source='$($pi.values.source)' -- $($why -join '; ')" }
            }
        }
        , @(($bad.Count -eq 0), "node B NSGs=[$($lb -join ', ')]; ingress rules on them=$n (egress skipped=$egress); $($bad -join ' | ')")
    }

    # 분류 사각지대 차단: 모든 NSG ingress 규칙은 두 부류 중 하나여야 하고(0.0.0.0/0·다른 포트·local/var 간접 배선 = 미분류)
    # 두 부류 모두 1개 이상이어야 한다(규칙 0개로 공허하게 PASS 금지).
    PlanAssert 'nsg-4: every NSG ingress rule classifies as platform-443-from-Cloudflare-CIDR or cluster-self-reference (>= 1 each; unclassified = 0: no 0.0.0.0/0, no other ports, no indirect NSG refs)' {
        if (-not $nsgSetOk) { return , @($false, $nsgSetDetail) }
        $ruleCfg = Get-Config 'oci_core_network_security_group_security_rule'
        $nPlatform = 0; $nCluster = 0; $egress = 0; $bad = @()
        foreach ($rc in $ruleCfg) {
            $insts = Get-PlannedFor $rc.address
            if ($insts.Count -eq 0) { $bad += "$($rc.address): no planned instance (unknown count/for_each?) -- fail closed"; continue }
            foreach ($pi in $insts) {
                if ("$($pi.values.direction)" -eq 'EGRESS') { $egress++; continue }
                $why = @()
                $cls = Get-RuleClass $rc $pi ([ref]$why)
                if ($cls -eq 'platform-443-cf') { $nPlatform++ }
                elseif ($cls -eq 'cluster-self') { $nCluster++ }
                else { $bad += "$($pi.address): $($why -join '; ')" }
            }
        }
        $ok = ($bad.Count -eq 0 -and $nPlatform -ge 1 -and $nCluster -ge 1)
        , @($ok, "platform-443-cf=$nPlatform, cluster-self=$nCluster, egress(skipped)=$egress; unclassified: $($bad -join ' | ')")
    }

    # ---------- 3b. 보안 리스트 [plan] — OCI는 SL ∪ NSG로 평가하므로 SL에 ingress가 남으면 NSG 경계가 무의미하다(T009 "SL egress-only") ----------
    PlanAssert 'sl-1: every security list (oci_core_security_list + oci_core_default_security_list) has zero ingress rules (>= 1 list required; ingress belongs to NSGs only)' {
        $slA = Get-Planned 'oci_core_security_list'; $slB = Get-Planned 'oci_core_default_security_list'
        $sls = @($slA) + @($slB)
        if ($sls.Count -eq 0) { return , @($false, 'no security list resources in planned_values (fail closed -- T008 imported 3: default + api + cache)') }
        $bad = @(); $seen = @()
        foreach ($sl in $sls) {
            $keys = @(); if ($sl.values) { $keys = @($sl.values.PSObject.Properties.Name) }
            if (-not ($keys -contains 'ingress_security_rules')) { $bad += "$($sl.address): ingress_security_rules unknown at plan time -- fail closed"; continue }
            $ing = $sl.values.ingress_security_rules
            $n = if ($null -eq $ing) { 0 } else { @($ing).Count }
            $seen += "$($sl.address)=$n"
            if ($n -gt 0) { $bad += "$($sl.address): $n ingress rule(s): " + (Clip (@($ing) | ConvertTo-Json -Compress -Depth 4) 200) }
        }
        , @(($bad.Count -eq 0), "security lists=$($sls.Count) [$($seen -join ', ')]; $($bad -join ' | ')")
    }

    # ---------- 4. 인스턴스 [plan + tf-text] ----------
    PlanAssert 'inst-1: exactly two oci_core_instance resources, one node A and one node B' {
        $c = Get-Config 'oci_core_instance'
        $a = @($c | Where-Object { "$($_.name)" -match '(?i)node[-_]?a' })
        $b = @($c | Where-Object { "$($_.name)" -match '(?i)node[-_]?b' })
        , @(($c.Count -eq 2 -and $a.Count -eq 1 -and $b.Count -eq 1), "total=$($c.Count), nodeA=$($a.Count), nodeB=$($b.Count)")
    }
    PlanAssert 'inst-2: every instance disables IMDSv1 (instance_options.are_legacy_imds_endpoints_disabled = true)' {
        $ps = Get-Planned 'oci_core_instance'
        $bad = @()
        foreach ($p in $ps) {
            $flag = $null
            try { $flag = $p.values.instance_options[0].are_legacy_imds_endpoints_disabled } catch { $flag = $null }
            if ($flag -ne $true) { $bad += "$($p.address): are_legacy_imds_endpoints_disabled=$flag" }
        }
        , @(($ps.Count -ge 1 -and $bad.Count -eq 0), "instances=$($ps.Count); $($bad -join '; ')")
    }
    Test-Group 'inst-3' {
        # [tf-text] prevent_destroy는 plan JSON에 노출되지 않으므로 원문에서 검사한다
        $blocks = Get-TfResourceBlocks $ociDir 'oci_core_instance'
        $bad = @($blocks | Where-Object { $_.body -notmatch 'prevent_destroy\s*=\s*true' } | ForEach-Object { "$($_.file):$($_.name)" })
        Assert 'inst-3: every oci_core_instance block declares lifecycle prevent_destroy = true [tf-text]' ($blocks.Count -ge 1 -and $bad.Count -eq 0) "blocks=$($blocks.Count); missing: $($bad -join ', ')"
    }

    # ---------- 5. 버킷 [plan] ----------
    $bucketNames = @('jt-tfstate', 'jt-backup', 'jt-backup-platform')
    for ($bi = 0; $bi -lt $bucketNames.Count; $bi++) {
        $bn = $bucketNames[$bi]
        PlanAssert "bucket-$($bi + 1): bucket '$bn' exists with versioning Enabled + NoPublicAccess" {
            $bs = Get-Planned 'oci_objectstorage_bucket'
            $hit = @($bs | Where-Object { [string]::Equals("$($_.values.name)", $bn, [StringComparison]::Ordinal) })
            $ok = ($hit.Count -eq 1 -and "$($hit[0].values.versioning)" -eq 'Enabled' -and "$($hit[0].values.public_access_type)" -eq 'NoPublicAccess')
            $d = if ($hit.Count -ne 1) { "matching buckets=$($hit.Count)" } else { "versioning=$($hit[0].values.versioning), public_access_type=$($hit[0].values.public_access_type)" }
            , @($ok, $d)
        }
    }
    PlanAssert 'bucket-4: exactly 3 bucket resources (no extras)' {
        $bs = Get-Planned 'oci_objectstorage_bucket'
        , @(($bs.Count -eq 3), "bucket count=$($bs.Count): $((@($bs | ForEach-Object { $_.values.name })) -join ', ')")
    }

    # ---------- 6. IAM 정책 [plan] — 교차 버킷 접근 0 ----------
    $allStatements = @()
    if ($script:planJson) {
        foreach ($p in (Get-Planned 'oci_identity_policy')) {
            if ($p.values -and $p.values.statements) { $allStatements += @($p.values.statements | ForEach-Object { "$_" }) }
        }
    }
    PlanAssert 'iam-1: svc-tfstate statements target only jt-tfstate (no jt-backup*)' {
        $st = @($allStatements | Where-Object { $_ -match '(?i)\bsvc-tfstate\b' })
        $bad = @($st | Where-Object { $_ -notmatch '(?i)jt-tfstate' -or $_ -match '(?i)jt-backup' })
        , @(($st.Count -ge 1 -and $bad.Count -eq 0), "statements=$($st.Count); bad: $($bad -join ' | ')")
    }
    PlanAssert 'iam-2: svc-s3-backup statements target only jt-backup (not -platform, not jt-tfstate)' {
        $st = @($allStatements | Where-Object { $_ -match '(?i)\bsvc-s3-backup\b' })
        $bad = @($st | Where-Object { $_ -match '(?i)jt-backup-platform' -or $_ -match '(?i)jt-tfstate' -or $_ -notmatch '(?i)jt-backup' })
        , @(($st.Count -ge 1 -and $bad.Count -eq 0), "statements=$($st.Count); bad: $($bad -join ' | ')")
    }
    PlanAssert 'iam-3: dynamic-group statements: jt-node-a -> jt-backup-platform with only OBJECT_CREATE + OBJECT_INSPECT' {
        $st = @($allStatements | Where-Object { $_ -match '(?i)\bdynamic-group\b' })
        $bad = @(); $perms = @()
        foreach ($s in $st) {
            if ($s -notmatch '(?i)\bjt-node-a\b') { $bad += "not jt-node-a: $s"; continue }
            if ($s -notmatch '(?i)jt-backup-platform') { $bad += "does not target jt-backup-platform: $s" }
            if (($s -replace '(?i)jt-backup-platform', '') -match '(?i)jt-backup|jt-tfstate') { $bad += "cross-bucket reference: $s" }
            $toks = @([regex]::Matches($s, 'OBJECT_[A-Z_]+') | ForEach-Object { $_.Value })
            # 무제한 manage 문장이 다른 문장의 허용 토큰 뒤에 숨지 못하게: 토큰 0개인 문장은 그 자체로 위반이다
            if ($toks.Count -eq 0) { $bad += "no request.permission restriction: $s" }
            foreach ($tok in $toks) {
                $perms += $tok
                if ($tok -ne 'OBJECT_CREATE' -and $tok -ne 'OBJECT_INSPECT') { $bad += "permission $tok not allowed: $s" }
            }
        }
        $ok = ($st.Count -ge 1 -and $bad.Count -eq 0 -and ($perms -contains 'OBJECT_CREATE') -and ($perms -contains 'OBJECT_INSPECT'))
        , @($ok, "statements=$($st.Count); perms=[$($perms -join ',')]; bad: $($bad -join ' | ')")
    }
    PlanAssert 'iam-4: svc-verify statements have zero manage verbs, only inspect/read of objects|usage-reports|budgets|instance-family' {
        $st = @($allStatements | Where-Object { $_ -match '(?i)\bsvc-verify\b' })
        $bad = @()
        foreach ($s in $st) {
            if ($s -match '(?i)\bmanage\b') { $bad += "manage verb: $s"; continue }
            if ($s -notmatch '(?i)\bto\s+(inspect|read)\s+(objects|usage-reports|budgets|instance-family)\b') { $bad += "verb/target outside allowed set: $s" }
        }
        , @(($st.Count -ge 1 -and $bad.Count -eq 0), "statements=$($st.Count); bad: $($bad -join ' | ')")
    }
    PlanAssert 'iam-5: a policy grants the Object Storage service principal OBJECT_VERSION_DELETE (declaration only; actual expiry = VD-6 after T010 apply)' {
        $hit = @($allStatements | Where-Object { $_ -match '(?i)\ballow\s+service\s+objectstorage' -and $_ -match 'OBJECT_VERSION_DELETE' })
        , @(($hit.Count -ge 1), "no statement matched 'allow service objectstorage...' + OBJECT_VERSION_DELETE among $($allStatements.Count) statements")
    }

    # ---------- 7. 동적 그룹 [plan] ----------
    PlanAssert 'dg-1: dynamic group jt-node-a exists' {
        $dg = @((Get-Planned 'oci_identity_dynamic_group') | Where-Object { [string]::Equals("$($_.values.name)", 'jt-node-a', [StringComparison]::Ordinal) })
        , @(($dg.Count -eq 1), "matching dynamic groups=$($dg.Count)")
    }
    PlanAssert 'dg-2: jt-node-a matching rule contains only the node A instance (no node B)' {
        $dg = @((Get-Planned 'oci_identity_dynamic_group') | Where-Object { [string]::Equals("$($_.values.name)", 'jt-node-a', [StringComparison]::Ordinal) })
        if ($dg.Count -ne 1) { return , @($false, "matching dynamic groups=$($dg.Count)") }
        $rule = "$($dg[0].values.matching_rule)"
        if ($rule -match 'ocid1\.instance\.') {
            # 리터럴 OCID 경로: 인스턴스 OCID가 정확히 1개
            $n = [regex]::Matches($rule, 'ocid1\.instance\.').Count
            return , @(($n -eq 1), "literal rule has $n instance OCIDs: $rule")
        }
        # 참조 경로: configuration의 matching_rule 참조가 노드 A 인스턴스 1개뿐이어야 한다
        $cfg = @((Get-Config 'oci_identity_dynamic_group') | Where-Object { "$($_.address)" -eq "$($dg[0].address)" })
        if ($cfg.Count -ne 1) { return , @($false, "config resource for $($dg[0].address) not found") }
        $labels = @{}
        foreach ($r in (Get-Refs $cfg[0].expressions.matching_rule)) {
            $m = [regex]::Match($r, '^oci_core_instance\.([A-Za-z0-9_-]+)')
            if ($m.Success) { $labels[$m.Groups[1].Value] = $true }
        }
        $ls = @($labels.Keys)
        $ok = ($ls.Count -eq 1 -and $ls[0] -match '(?i)node[-_]?a' -and -not ($ls[0] -match '(?i)node[-_]?b'))
        , @($ok, "instance references in matching_rule: [$($ls -join ', ')]")
    }

    # ---------- 8. KMS [plan + tf-text] ----------
    PlanAssert 'kms-1: every oci_kms_key uses protection_mode SOFTWARE' {
        $ks = Get-Planned 'oci_kms_key'
        $bad = @($ks | Where-Object { -not [string]::Equals("$($_.values.protection_mode)", 'SOFTWARE', [StringComparison]::Ordinal) } | ForEach-Object { "$($_.address)=$($_.values.protection_mode)" })
        , @(($ks.Count -ge 1 -and $bad.Count -eq 0), "keys=$($ks.Count); bad: $($bad -join ', ')")
    }
    Test-Group 'kms-2' {
        $blocks = Get-TfResourceBlocks $ociDir 'oci_kms_key'
        $bad = @($blocks | Where-Object { $_.body -notmatch 'prevent_destroy\s*=\s*true' } | ForEach-Object { "$($_.file):$($_.name)" })
        Assert 'kms-2: every oci_kms_key block declares lifecycle prevent_destroy = true [tf-text]' ($blocks.Count -ge 1 -and $bad.Count -eq 0) "blocks=$($blocks.Count); missing: $($bad -join ', ')"
    }

    # ---------- 9. Object Storage lifecycle [plan] — previous-object-versions DELETE 60일 ----------
    function Resolve-LcBucket($p) {
        $b = $null; try { $b = $p.values.bucket } catch { $b = $null }
        if ($b) { return "$b" }
        $cfg = @((Get-Config 'oci_objectstorage_object_lifecycle_policy') | Where-Object { "$($_.address)" -eq "$($p.address)" })
        if ($cfg.Count -eq 1) {
            foreach ($r in (Get-Refs $cfg[0].expressions.bucket)) {
                $m = [regex]::Match($r, '^(oci_objectstorage_bucket\.[A-Za-z0-9_-]+)')
                if ($m.Success) {
                    $bp = @((Get-Planned 'oci_objectstorage_bucket') | Where-Object { "$($_.address)" -eq $m.Groups[1].Value })
                    if ($bp.Count -eq 1) { return "$($bp[0].values.name)" }
                }
            }
        }
        return $null
    }
    $lcTargets = @('jt-backup', 'jt-backup-platform')
    for ($li = 0; $li -lt $lcTargets.Count; $li++) {
        $lb = $lcTargets[$li]
        PlanAssert "lc-$($li + 1): bucket '$lb' has a previous-object-versions DELETE 60 DAYS lifecycle rule (declaration only; actual deletion = VD-6)" {
            $found = $false; $seen = @()
            foreach ($p in (Get-Planned 'oci_objectstorage_object_lifecycle_policy')) {
                if ((Resolve-LcBucket $p) -ne $lb) { continue }
                $rules = @(); if ($p.values -and $p.values.rules) { $rules = @($p.values.rules) }
                foreach ($r in $rules) {
                    $seen += "target=$($r.target) action=$($r.action) $($r.time_amount) $($r.time_unit)"
                    if ("$($r.target)" -eq 'previous-object-versions' -and "$($r.action)" -match '(?i)^DELETE$' -and "$($r.time_amount)" -eq '60' -and "$($r.time_unit)" -match '(?i)^DAYS$' -and $r.is_enabled -ne $false) { $found = $true }
                }
            }
            , @($found, "no matching rule for bucket '$lb'; rules seen: $($seen -join ' | ')")
        }
    }

    # ---------- 10. Cloudflare Access [tf-text] — 정책 전부 session_duration 명시 ----------
    Test-Group 'access-1' {
        # 양측 무조건 검사: application 블록 1개 이상 필수(fail closed), application·policy 모든 블록이 session_duration 명시
        $apps = Get-TfResourceBlocks $cfDir 'cloudflare_zero_trust_access_application'
        $pols = Get-TfResourceBlocks $cfDir 'cloudflare_zero_trust_access_policy'
        $bad = @(@($apps) + @($pols) | Where-Object { $_.body -notmatch 'session_duration\s*=' } | ForEach-Object { "$($_.file):$($_.name)" })
        Assert 'access-1: >=1 Access application block; every application AND policy block sets session_duration [tf-text]' ($apps.Count -ge 1 -and $bad.Count -eq 0) "app blocks=$($apps.Count), policy blocks=$($pols.Count); missing session_duration: $($bad -join ', ')"
    }
} finally {
    Remove-Item -LiteralPath $planFile -Force -ErrorAction SilentlyContinue
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
