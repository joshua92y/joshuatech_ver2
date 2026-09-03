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
#     backend 블록이 생기면(T007의 joshuatech-tfstate) plan 전에 완전한 `tofu init`이 선행되어야 한다 —
#     이 스위트가 돌리는 `init -backend=false`는 backend 도입 전에만 충분하다.
#     T010부터 plan은 변수 budget_alert_email(기본값 없음)을 요구한다 — 운영자 tfvars(.gitignore) 또는 TF_VAR_budget_alert_email.
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
#   - 이름 예외(사용자 결정 2026-09-03, docs/runbooks/bootstrap.md §0 — 구속력): 설계 문서의 jt-* 표기는 실명 joshuatech-* 로 읽는다.
#     버킷은 정확히 joshuatech-tfstate·joshuatech-backup·joshuatech-backup-platform(3개 전부, 그 외 없음; provider 속성은
#     access_type = NoPublicAccess — public_access_type이 아니다), 그룹 joshuatech-tfstate·joshuatech-s3-backup·joshuatech-verify,
#     동적 그룹 joshuatech-node-a, KMS 볼트 joshuatech-vault·키 joshuatech-key.
#   - IAM(T010): OCI 정책은 사용자(svc-*)가 아니라 그룹·동적 그룹·서비스 주체에 권한을 준다(사용자→그룹 가입은 tofu 밖 콘솔 단계).
#     문장은 `allow <kind> <name> to <verb> <resource> in <scope> [where …]`로 파싱하고 주체별로 분류한다. 버킷 접근 행렬은 소진적이다:
#       joshuatech-tfstate         ← group joshuatech-tfstate 만
#       joshuatech-backup          ← group joshuatech-s3-backup · group joshuatech-verify · service objectstorage[-region]
#       joshuatech-backup-platform ← dynamic-group joshuatech-node-a · group joshuatech-verify · service objectstorage[-region]
#     그 외 주체·버킷·any-user, 그리고 target.* '=' 조건 없는 manage/use 문장은 iam-6 위반이다. where 절은 리프(`key = 'v'`|`key != 'v'`)·
#     `all {…}`·`any {…}`(all 안의 any 한 단계까지)만 받고, any 안에 target.bucket.name '=' 이외의 리프(any {bucket, permission}은 OR라
#     권한이 넓어진다)·bucket '!='·더 깊은 중첩·파싱 불가는 전부 FAIL이다. 동적 그룹은 `use keys … where target.key.id`(이 스택의 KMS 키;
#     T010 문면) + joshuatech-backup-platform `manage objects` where all {bucket, request.permission = OBJECT_CREATE|OBJECT_INSPECT}만이다.
#     plan 시점 unknown 문장(키 OCID가 (known after apply)면 provider가 statements 전체를 unknown으로 낸다)은 같은 정책 블록의 .tf 원문
#     `statements = [ … ]` 문자열 리터럴(같은 인덱스; 순수 리터럴 목록일 때만 — concat/for 식·비문자열 원소가 섞이면 해석 불가 = FAIL)로
#     대체해 검사한다. `${…}` 치환: `<oci_type>.<label>.<attr>`는 그 리소스의 planned 값, 그 밖의 참조(local.* 등)는 같은 참조를 단독으로
#     쓰는 다른 리소스 속성의 planned 값(후보가 전부 같을 때만; 예 local.bucket_names.backup_platform ← 버킷 name), 해석 실패는 <expr>
#     마커(unknown 키 OCID는 <oci_kms_key.<label>.id> 마커로 이 스택의 키 라벨과 대조; 그 밖의 마커는 검사에서 걸린다 — fail closed).
#   - OBJECT_VERSION_DELETE(VD-6): Object Storage 서비스 주체 문장이 두 백업 버킷 각각에 `request.permission = 'OBJECT_VERSION_DELETE'`
#     (= 형, != 아님; 버킷은 그 문장의 bucket 리프 또는 all 안의 any {bucket…})을 담아야 한다 — T010은 정책을 `!=` 반쪽과 `=` 반쪽으로
#     나누므로 `=` 반쪽(VD-6 관찰 단계에서 떼는 쪽)을 빼면 FAIL. 단언은 선언 존재까지만이다 — 규칙이 실제로 이전 버전을 삭제하는지는
#     VD-6(T010 apply 후 첫 만료 관찰)에서 확인한다.
#   - lifecycle: 두 백업 버킷에 enabled previous-object-versions DELETE 60 DAYS 규칙이 있어야 하고, 현재 버전(target = objects) 규칙은
#     전부 inclusion prefix ≥ 1을 가져야 한다(접두사 없는 objects DELETE = 버킷 전체 만료). joshuatech-tfstate에는 규칙이 없다.
#   - KMS: 키는 protection_mode SOFTWARE + key_shape AES/32 + is_auto_rotation_enabled = false 명시 + display_name joshuatech-key(정확히 1);
#     볼트는 정확히 1, vault_type DEFAULT, display_name joshuatech-vault; 키·볼트 블록 모두 prevent_destroy [tf-text].
#   - Cloudflare Access(T008/T011): cloudflare_zero_trust_access_application 블록이 1개 이상 있어야 하고,
#     application·policy 두 타입의 모든 블록이 각각 session_duration을 명시해야 한다(양측 무조건 검사).
#
# 단언 수: 36 (tool 1, enc 1, dir 2, validate 4, plan 2, nsg 4, sl 1, inst 3, bucket 4, iam 6, dg 2, kms 3, lc 2, access 1)
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

    # ---------- 5. 버킷 [plan] — 이름 예외(joshuatech-*), versioning Enabled, access_type NoPublicAccess ----------
    $bucketTfstate = 'joshuatech-tfstate'; $bucketBackup = 'joshuatech-backup'; $bucketBackupPlatform = 'joshuatech-backup-platform'
    $bucketNames = @($bucketTfstate, $bucketBackup, $bucketBackupPlatform)
    $lcBuckets = @($bucketBackup, $bucketBackupPlatform)   # lifecycle 규칙·서비스 주체 정책·svc-verify 읽기의 대상(두 백업 버킷)
    # ordinal 집합 포함 여부(-contains는 대소문자 무시)
    function Test-InSet($set, [string]$v) { foreach ($x in @($set)) { if ([string]::Equals("$x", $v, [StringComparison]::Ordinal)) { return $true } }; return $false }
    for ($bi = 0; $bi -lt $bucketNames.Count; $bi++) {
        $bn = $bucketNames[$bi]
        PlanAssert "bucket-$($bi + 1): bucket '$bn' exists with versioning Enabled + access_type NoPublicAccess" {
            $bs = Get-Planned 'oci_objectstorage_bucket'
            $hit = @($bs | Where-Object { [string]::Equals("$($_.values.name)", $bn, [StringComparison]::Ordinal) })
            $ok = ($hit.Count -eq 1 -and [string]::Equals("$($hit[0].values.versioning)", 'Enabled', [StringComparison]::Ordinal) -and [string]::Equals("$($hit[0].values.access_type)", 'NoPublicAccess', [StringComparison]::Ordinal))
            $d = if ($hit.Count -ne 1) { "matching buckets=$($hit.Count)" } else { "versioning=$($hit[0].values.versioning), access_type=$($hit[0].values.access_type)" }
            , @($ok, $d)
        }
    }
    PlanAssert 'bucket-4: exactly 3 bucket resources (no extras)' {
        $bs = Get-Planned 'oci_objectstorage_bucket'
        , @(($bs.Count -eq 3), "bucket count=$($bs.Count): $((@($bs | ForEach-Object { $_.values.name })) -join ', ')")
    }

    # ---------- 6. IAM 정책 [plan + tf-text 대체] — 그룹·동적 그룹·서비스 주체 문장, 교차 버킷 접근 0 ----------
    # 문장 파싱·where 절 사실 추출·unknown 문장의 tf-text 대체 규칙은 머리 주석 "IAM(T010)" 항목이 계약이다. 주체 키는 "<kind> <name>"
    # (서비스 주체는 리전 접미를 뗀 'service objectstorage').
    $iamSubjectTfstate = 'group joshuatech-tfstate'; $iamSubjectS3Backup = 'group joshuatech-s3-backup'; $iamSubjectVerify = 'group joshuatech-verify'
    $iamSubjectNodeA = 'dynamic-group joshuatech-node-a'; $iamSubjectObjectStorage = 'service objectstorage'
    $knownSubjects = @($iamSubjectTfstate, $iamSubjectS3Backup, $iamSubjectVerify, $iamSubjectNodeA, $iamSubjectObjectStorage)
    # 버킷 접근 행렬(소진적) — 여기 없는 (버킷, 주체) 쌍은 iam-6 위반이다
    $bucketSubjects = @{
        $bucketTfstate        = @($iamSubjectTfstate)
        $bucketBackup         = @($iamSubjectS3Backup, $iamSubjectVerify, $iamSubjectObjectStorage)
        $bucketBackupPlatform = @($iamSubjectNodeA, $iamSubjectVerify, $iamSubjectObjectStorage)
    }

    # HCL 문자열 리터럴 스팬(선언 순서; start = 여는 따옴표 인덱스, end = 닫는 따옴표 다음 인덱스, value = 원문 그대로, 이스케이프 미해석) —
    # "${…}"/"%{…}" 템플릿 안의 따옴표·중괄호를 스택으로 추적한다(`${local.x["k"]}` 안전). Get-TfResourceBlocks가 전체 행 주석을 이미
    # 지운 블록 본문에 쓴다.
    function Get-HclStringSpans([string]$text) {
        $out = @(); $i = 0; $n = $text.Length
        while ($i -lt $n) {
            if ($text[$i] -ne '"') { $i++; continue }
            $start = $i + 1; $j = $start
            $stack = [System.Collections.Generic.List[string]]::new(); $stack.Add('str')
            while ($j -lt $n -and $stack.Count -gt 0) {
                $ch = $text[$j]; $top = $stack[$stack.Count - 1]
                if ($top -eq 'str') {
                    if ($ch -eq '\') { $j += 2; continue }
                    if (($ch -eq '$' -or $ch -eq '%') -and ($j + 1) -lt $n -and $text[$j + 1] -eq '{') { $stack.Add('tpl'); $j += 2; continue }
                    if ($ch -eq '"') { $stack.RemoveAt($stack.Count - 1); $j++; continue }
                }
                elseif ($ch -eq '"') { $stack.Add('str') }
                elseif ($ch -eq '{') { $stack.Add('tpl') }
                elseif ($ch -eq '}') { $stack.RemoveAt($stack.Count - 1) }
                $j++
            }
            $out += , @{ start = $i; end = [Math]::Min($j, $n); value = $text.Substring($start, [Math]::Max(0, $j - 1 - $start)) }
            $i = [Math]::Max($j, $i + 1)
        }
        return , $out
    }
    # 정책 블록의 `statements = [ … ]`가 순수 문자열 리터럴 목록일 때만 그 리터럴들(선언 순서)을 돌려준다 — 목록이 없거나(concat/for 식)
    # 문자열 외 원소·중첩 목록이 섞이면 $null(unknown 문장을 원문으로 해석할 수 없다 → 위반; 숨은 비리터럴 문장이 검사를 비껴가지 못한다).
    function Get-PolicyStatementLiterals([string]$body) {
        $m = [regex]::Match($body, 'statements\s*=\s*\[')
        if (-not $m.Success) { return $null }
        $byStart = @{}
        foreach ($sp in (Get-HclStringSpans $body)) { $byStart[[int]$sp.start] = $sp }
        $i = $m.Index + $m.Length; $depth = 1; $j = $i; $n = $body.Length; $inRegion = @()
        while ($j -lt $n -and $depth -gt 0) {
            if ($byStart.ContainsKey($j)) { $sp = $byStart[$j]; $inRegion += , $sp; $j = [int]$sp.end; continue }
            $ch = $body[$j]
            if ($ch -eq '[') { $depth++ } elseif ($ch -eq ']') { $depth-- }
            $j++
        }
        if ($depth -ne 0) { return $null }
        $residue = $body.Substring($i, $j - 1 - $i)
        foreach ($sp in @($inRegion | Sort-Object { [int]$_.start } -Descending)) { $residue = $residue.Remove([int]$sp.start - $i, [int]$sp.end - [int]$sp.start) }
        if ($residue -notmatch '^[\s,]*$') { return $null }
        return , @($inRegion | ForEach-Object { "$($_.value)" })
    }
    # `${expr}` 해석(unknown 문장의 tf-text 템플릿 전용):
    #   (1) <oci_type>.<label>.<attr> → 그 리소스의 planned 스칼라 값(알려진 경우; 예 oci_identity_dynamic_group.node_a.name)
    #   (2) 그 밖의 참조(local.* 등) → 같은 참조를 단독으로 쓰는(references가 그 참조와 조상뿐인) 다른 리소스 속성의 planned 스칼라 값 —
    #       후보 값이 전부 같을 때만(예 local.bucket_names.backup_platform ← oci_objectstorage_bucket.backup_platform.name)
    #   (3) 실패(unknown 포함) → <expr> 마커. iam-3의 target.key.id는 <oci_kms_key.<label>.id> 마커를 이 스택의 키 라벨로 대조한다.
    function Resolve-Expr([string]$e) {
        $m = [regex]::Match($e, '^([a-z][a-z0-9_]*\.[A-Za-z0-9_-]+)\.([a-z_]+)$')
        if ($m.Success -and -not ($e.StartsWith('local.') -or $e.StartsWith('var.') -or $e.StartsWith('data.') -or $e.StartsWith('each.'))) {
            $pl = Get-PlannedFor $m.Groups[1].Value; $pl = @($pl)
            if ($pl.Count -eq 1 -and $null -ne $pl[0].values) {
                $v = $pl[0].values.($m.Groups[2].Value)
                if ($v -is [string] -and $v -ne '') { return $v }
            }
            return "<$e>"
        }
        $cands = @{}
        $cfgAll = @(); $j = $script:planJson
        if ($j -and $j.configuration -and $j.configuration.root_module -and $j.configuration.root_module.resources) { $cfgAll = @($j.configuration.root_module.resources) }
        foreach ($c in $cfgAll) {
            if ($null -eq $c.expressions) { continue }
            foreach ($prop in @($c.expressions.PSObject.Properties)) {
                $refs = Get-Refs $prop.Value; $refs = @($refs)
                if ($refs.Count -eq 0 -or -not (Test-InSet $refs $e)) { continue }
                $exact = $true
                foreach ($r in $refs) { if (-not ([string]::Equals($r, $e, [StringComparison]::Ordinal) -or $e.StartsWith($r + '.', [StringComparison]::Ordinal) -or $e.StartsWith($r + '[', [StringComparison]::Ordinal))) { $exact = $false } }
                if (-not $exact) { continue }
                $pls = Get-PlannedFor "$($c.address)"; $pls = @($pls)
                foreach ($pi in $pls) {
                    if ($null -eq $pi.values) { continue }
                    $v = $pi.values.($prop.Name)
                    if ($v -is [string] -and $v -ne '') { $cands["$v"] = $true }
                }
            }
        }
        if ($cands.Count -eq 1) { return "$(@($cands.Keys)[0])" }
        return "<$e>"
    }
    function Resolve-StatementTemplate([string]$tpl) {
        return [regex]::Replace($tpl, '\$\{([^{}]*)\}', { param($m) Resolve-Expr $m.Groups[1].Value.Trim() })
    }
    # where 절 노드 파서: depth 0 = all|any {…} 또는 리프, depth 1(all 안) = any {…} 또는 리프, 그 밖의 중첩·형태는 err(fail closed).
    # 리프는 `key = 'v'` | `key != 'v'`(값은 작은따옴표)만.
    function Parse-WhereNode([string]$w, [int]$depth) {
        $w = $w.Trim()
        $g = [regex]::Match($w, '(?is)^(all|any)\s*\{(.*)\}$')
        if ($g.Success) {
            $op = $g.Groups[1].Value.ToLowerInvariant()
            if ($depth -ge 2 -or ($depth -eq 1 -and $op -ne 'any')) { return @{ op = 'err'; err = "'$op {...}' nested at depth $depth (only all {..., any {...}} is accepted)" } }
            $parts = @(); $cur = ''; $d = 0; $q = $false
            foreach ($ch in $g.Groups[2].Value.ToCharArray()) {
                if ($ch -eq "'") { $q = -not $q }
                elseif (-not $q -and $ch -eq '{') { $d++ }
                elseif (-not $q -and $ch -eq '}') { $d-- }
                if ($ch -eq ',' -and $d -eq 0 -and -not $q) { $parts += $cur; $cur = '' } else { $cur += $ch }
            }
            $parts += $cur
            $kids = @()
            foreach ($p in $parts) {
                if ($p.Trim() -eq '') { return @{ op = 'err'; err = "empty condition inside $op {}" } }
                $k = Parse-WhereNode $p ($depth + 1)
                if ($k.op -eq 'err') { return $k }
                $kids += , $k
            }
            return @{ op = $op; kids = $kids }
        }
        $l = [regex]::Match($w, "^([A-Za-z][A-Za-z0-9_.]*)\s*(=|!=)\s*'([^']*)'$")
        if ($l.Success) { return @{ op = 'leaf'; key = $l.Groups[1].Value.ToLowerInvariant(); cmp = $l.Groups[2].Value; val = $l.Groups[3].Value } }
        return @{ op = 'err'; err = "unparseable condition '$w'" }
    }
    # 리프 평면화 — 각 리프에 직접 감싼 결합자(under: all|any|single)를 붙인다
    function Get-WhereLeaves($node, [string]$under) {
        $out = @()
        if ($node.op -eq 'leaf') { $out += , @{ key = $node.key; cmp = $node.cmp; val = $node.val; under = $under } }
        else { foreach ($k in $node.kids) { $sub = Get-WhereLeaves $k $node.op; $out += @($sub) } }
        return , $out
    }
    # 문장 파서 → 해시(kind, name, verb, resource, scope, buckets/permEq/permNe/keyIds/targetEq, unsound, err). 파싱 불가면 err(fail closed).
    function Parse-Statement([string]$s) {
        $r = @{ text = $s; kind = ''; name = ''; verb = ''; resource = ''; scope = ''; buckets = @(); permEq = @(); permNe = @(); keyIds = @(); targetEq = 0; unsound = @(); err = '' }
        if ($s -match '(?i)^\s*allow\s+any-(user|group)\b') { $r.kind = 'any-' + $Matches[1].ToLowerInvariant(); $r.err = "subject $($r.kind) is forbidden"; return $r }
        $m = [regex]::Match($s, "(?i)^\s*allow\s+(group|dynamic-group|service)\s+(\S+)\s+to\s+(inspect|read|use|manage)\s+(\S+)\s+in\s+(tenancy|compartment\s+(?:id\s+)?\S+)(?:\s+where\s+(.+?))?\s*$")
        if (-not $m.Success) { $r.err = 'does not parse as allow <group|dynamic-group|service> <name> to <inspect|read|use|manage> <resource> in <tenancy|compartment ...> [where ...]'; return $r }
        $r.kind = $m.Groups[1].Value.ToLowerInvariant(); $r.name = $m.Groups[2].Value; $r.verb = $m.Groups[3].Value.ToLowerInvariant()
        $r.resource = $m.Groups[4].Value.ToLowerInvariant(); $r.scope = $m.Groups[5].Value
        if ($m.Groups[6].Success) {
            $node = Parse-WhereNode $m.Groups[6].Value 0
            if ($node.op -eq 'err') { $r.err = "where clause: $($node.err)"; return $r }
            foreach ($leaf in (Get-WhereLeaves $node 'single')) {
                if ($leaf.under -eq 'any' -and -not ($leaf.key -eq 'target.bucket.name' -and $leaf.cmp -eq '=')) { $r.unsound += "any {} contains '$($leaf.key) $($leaf.cmp)' (OR widens the grant)" }
                switch ($leaf.key) {
                    'target.bucket.name' { if ($leaf.cmp -eq '=') { $r.buckets += $leaf.val } else { $r.unsound += "target.bucket.name != '$($leaf.val)' (negated bucket = every other bucket)" } }
                    'request.permission' { if ($leaf.cmp -eq '=') { $r.permEq += $leaf.val } else { $r.permNe += $leaf.val } }
                    'target.key.id' { if ($leaf.cmp -eq '=') { $r.keyIds += $leaf.val } else { $r.unsound += 'target.key.id != (negated key = every other key)' } }
                }
                if ($leaf.key -like 'target.*' -and $leaf.cmp -eq '=') { $r.targetEq++ }
            }
        }
        return $r
    }
    function Get-SubjectKey($st) {
        if ($st.kind -eq 'service' -and $st.name -match '^objectstorage(-[a-z0-9-]+)?$') { return $iamSubjectObjectStorage }
        return "$($st.kind) $($st.name)"
    }

    # 모든 정책의 문장 해석 — planned 값이 알려진 문장은 그대로, unknown(null/키 없음)이면 같은 정책 블록의 tf-text statements 리터럴 목록
    # (같은 인덱스; 순수 문자열 리터럴 목록일 때만)을 Resolve-StatementTemplate로 해석한다. 해석 불가는 $stmtErrors(iam-6 위반).
    $stmts = @(); $stmtErrors = @()
    if ($script:planJson) {
        $policyBlocks = Get-TfResourceBlocks $ociDir 'oci_identity_policy'
        foreach ($p in (Get-Planned 'oci_identity_policy')) {
            $label = "$($p.name)"
            $known = @()
            if ($p.values -and (@($p.values.PSObject.Properties.Name) -contains 'statements') -and $null -ne $p.values.statements) { $known = @($p.values.statements) }
            $tpls = $null   # $null = 원문에 순수 리터럴 목록이 없다(블록 없음·중복·concat/for 식·비문자열 원소)
            $blocksFor = @($policyBlocks | Where-Object { [string]::Equals("$($_.name)", $label, [StringComparison]::Ordinal) })
            if ($blocksFor.Count -eq 1) { $tpls = Get-PolicyStatementLiterals "$($blocksFor[0].body)"; if ($null -ne $tpls) { $tpls = @($tpls) } }
            $count = $known.Count
            if ($count -eq 0) {
                if ($null -eq $tpls -or $tpls.Count -eq 0) { $stmtErrors += "$($p.address): statements unknown at plan time and its .tf block has no pure string-literal statements list (blocks=$($blocksFor.Count); concat/for or non-literal element?) -- cannot verify"; continue }
                $count = $tpls.Count
            }
            for ($si = 0; $si -lt $count; $si++) {
                $text = $null; $src = 'plan'
                if ($si -lt $known.Count -and $null -ne $known[$si] -and "$($known[$si])" -ne '') { $text = "$($known[$si])" }
                elseif ($null -ne $tpls -and $si -lt $tpls.Count) { $text = Resolve-StatementTemplate $tpls[$si]; $src = 'tf-text' }
                if ($null -eq $text) { $stmtErrors += "$($p.address)[$si]: statement unknown at plan time and no literal at that index in its .tf block (pure literal list required)"; continue }
                $st = Parse-Statement $text
                $st.policy = "$($p.address)"; $st.index = $si; $st.src = $src
                $stmts += , $st
            }
        }
    }

    # 서비스 사용자 그룹 문장 공통 검사 — 자원은 objects(manage|use|read|inspect)·buckets(read|inspect)만, 버킷 집합 == {$bucket} 정확히
    function Test-SvcGroupStatements([string]$subject, [string]$bucket) {
        $st = @($stmts | Where-Object { [string]::Equals((Get-SubjectKey $_), $subject, [StringComparison]::Ordinal) })
        $bad = @()
        foreach ($s in $st) {
            if ($s.err) { $bad += "$($s.err): $($s.text)"; continue }
            $vr = "$($s.verb) $($s.resource)"
            if ($vr -notmatch '^(manage|use|read|inspect) objects$' -and $vr -notmatch '^(read|inspect) buckets$') { $bad += "'$vr' outside {manage|use|read|inspect objects, read|inspect buckets}: $($s.text)" }
            if ($s.unsound.Count -gt 0) { $bad += "unsound where ($($s.unsound -join '; ')): $($s.text)" }
            $bs = @($s.buckets | Sort-Object -Unique)
            if ($bs.Count -ne 1 -or -not [string]::Equals("$($bs[0])", $bucket, [StringComparison]::Ordinal)) { $bad += "target.bucket.name set [$($bs -join ', ')] != {$bucket}: $($s.text)" }
        }
        return @{ n = $st.Count; bad = $bad }
    }
    PlanAssert 'iam-1: group joshuatech-tfstate (svc-tfstate) statements: >= 1, objects/buckets verbs only, target.bucket.name = joshuatech-tfstate exactly (no backup bucket, no unconditioned grant)' {
        $r = Test-SvcGroupStatements $iamSubjectTfstate $bucketTfstate
        , @(($r.n -ge 1 -and $r.bad.Count -eq 0), "statements=$($r.n); bad: $($r.bad -join ' | ')")
    }
    PlanAssert 'iam-2: group joshuatech-s3-backup (svc-s3-backup) statements: >= 1, objects/buckets verbs only, target.bucket.name = joshuatech-backup exactly (not -platform, not tfstate, no unconditioned grant)' {
        $r = Test-SvcGroupStatements $iamSubjectS3Backup $bucketBackup
        , @(($r.n -ge 1 -and $r.bad.Count -eq 0), "statements=$($r.n); bad: $($r.bad -join ' | ')")
    }
    PlanAssert 'iam-3: dynamic-group statements: subject joshuatech-node-a only; forms = use keys where target.key.id = <this stack KMS key> (>= 1) + manage objects where all {target.bucket.name = joshuatech-backup-platform, request.permission = OBJECT_CREATE|OBJECT_INSPECT} (both perms present, nothing else, no !=)' {
        $st = @($stmts | Where-Object { $_.kind -eq 'dynamic-group' })
        $kmsIds = @((Get-Planned 'oci_kms_key') | ForEach-Object { "$($_.values.id)" } | Where-Object { $_ -ne '' })
        $kmsLabels = @((Get-Config 'oci_kms_key') | ForEach-Object { "$($_.name)" })
        $bad = @(); $perms = @(); $keyStmts = 0
        foreach ($s in $st) {
            if ($s.err) { $bad += "$($s.err): $($s.text)"; continue }
            if (-not [string]::Equals("$($s.name)", 'joshuatech-node-a', [StringComparison]::Ordinal)) { $bad += "dynamic-group '$($s.name)' is not joshuatech-node-a: $($s.text)"; continue }
            if ($s.unsound.Count -gt 0) { $bad += "unsound where ($($s.unsound -join '; ')): $($s.text)" }
            if ($s.permNe.Count -gt 0) { $bad += "request.permission != (negation widens the grant): $($s.text)" }
            $vr = "$($s.verb) $($s.resource)"
            if ($vr -eq 'use keys') {
                $keyStmts++
                if ($s.buckets.Count -gt 0 -or $s.keyIds.Count -ne 1) { $bad += "use keys must carry exactly one target.key.id = condition and no bucket condition: $($s.text)"; continue }
                $kid = "$($s.keyIds[0])"
                $mk = [regex]::Match($kid, '^<oci_kms_key\.([A-Za-z0-9_-]+)\.id>$')
                $okKey = if ($mk.Success) { Test-InSet $kmsLabels $mk.Groups[1].Value } else { Test-InSet $kmsIds $kid }
                if (-not $okKey) { $bad += "target.key.id '$kid' is not a KMS key of this stack (planned ids [$($kmsIds -join ',')], config labels [$($kmsLabels -join ',')]): $($s.text)" }
            }
            elseif ($vr -eq 'manage objects') {
                $bs = @($s.buckets | Sort-Object -Unique)
                if ($bs.Count -ne 1 -or -not [string]::Equals("$($bs[0])", $bucketBackupPlatform, [StringComparison]::Ordinal)) { $bad += "target.bucket.name set [$($bs -join ', ')] != {$bucketBackupPlatform}: $($s.text)" }
                if ($s.permEq.Count -eq 0) { $bad += "no request.permission = restriction (unrestricted manage objects): $($s.text)" }
                foreach ($pm in $s.permEq) { $perms += $pm; if (-not (Test-InSet @('OBJECT_CREATE', 'OBJECT_INSPECT') $pm)) { $bad += "permission '$pm' not allowed (only OBJECT_CREATE, OBJECT_INSPECT): $($s.text)" } }
            }
            else { $bad += "'$vr' is not an allowed dynamic-group form (use keys | manage objects): $($s.text)" }
        }
        $ok = ($st.Count -ge 1 -and $bad.Count -eq 0 -and $keyStmts -ge 1 -and (Test-InSet $perms 'OBJECT_CREATE') -and (Test-InSet $perms 'OBJECT_INSPECT'))
        , @($ok, "statements=$($st.Count) (use keys=$keyStmts; sources=[$(@($st | ForEach-Object { "$($_.src)" } | Sort-Object -Unique) -join ',')]); perms=[$($perms -join ',')]; bad: $($bad -join ' | ')")
    }
    PlanAssert 'iam-4: group joshuatech-verify (svc-verify) statements: verbs inspect|read only (manage/use = 0), resources objects|usage-reports|usage-budgets|instance-family only, objects scoped to exactly the two backup buckets (no tfstate)' {
        $st = @($stmts | Where-Object { [string]::Equals((Get-SubjectKey $_), $iamSubjectVerify, [StringComparison]::Ordinal) })
        $bad = @(); $seenBuckets = @()
        foreach ($s in $st) {
            if ($s.err) { $bad += "$($s.err): $($s.text)"; continue }
            if ($s.verb -ne 'inspect' -and $s.verb -ne 'read') { $bad += "verb '$($s.verb)' (want inspect|read; manage/use = 0): $($s.text)"; continue }
            if (-not (Test-InSet @('objects', 'usage-reports', 'usage-budgets', 'instance-family') $s.resource)) { $bad += "resource '$($s.resource)' outside {objects, usage-reports, usage-budgets, instance-family}: $($s.text)" }
            if ($s.unsound.Count -gt 0) { $bad += "unsound where ($($s.unsound -join '; ')): $($s.text)" }
            if ($s.resource -eq 'objects') {
                if ($s.buckets.Count -eq 0) { $bad += "objects grant without target.bucket.name (every bucket): $($s.text)" }
                foreach ($b in $s.buckets) { $seenBuckets += $b; if (-not (Test-InSet $lcBuckets $b)) { $bad += "bucket '$b' outside {$($lcBuckets -join ', ')}: $($s.text)" } }
            }
        }
        $cover = @($lcBuckets | Where-Object { Test-InSet $seenBuckets $_ })
        , @(($st.Count -ge 1 -and $bad.Count -eq 0 -and $cover.Count -eq $lcBuckets.Count), "statements=$($st.Count); objects buckets=[$(@($seenBuckets | Sort-Object -Unique) -join ', ')] (want both $($lcBuckets -join ' + ')); bad: $($bad -join ' | ')")
    }
    PlanAssert "iam-5: Object Storage service principal statements (service objectstorage[-region]): objects|object-family on the two backup buckets only, and each of joshuatech-backup + joshuatech-backup-platform has a statement carrying request.permission = 'OBJECT_VERSION_DELETE' (= form, not !=; the VD-6 half) -- declaration only, actual expiry = VD-6 after apply" {
        $st = @($stmts | Where-Object { $_.kind -eq 'service' })
        $bad = @(); $ovd = @{}
        foreach ($s in $st) {
            if ($s.err) { $bad += "$($s.err): $($s.text)"; continue }
            if ($s.name -notmatch '^objectstorage(-[a-z0-9-]+)?$') { $bad += "service subject '$($s.name)' is not objectstorage[-region]: $($s.text)"; continue }
            if ($s.resource -ne 'objects' -and $s.resource -ne 'object-family') { $bad += "resource '$($s.resource)' (want objects|object-family): $($s.text)" }
            if ($s.unsound.Count -gt 0) { $bad += "unsound where ($($s.unsound -join '; ')): $($s.text)" }
            if ($s.buckets.Count -eq 0) { $bad += "no target.bucket.name condition (every bucket incl. tfstate): $($s.text)" }
            foreach ($b in $s.buckets) {
                if (-not (Test-InSet $lcBuckets $b)) { $bad += "bucket '$b' outside {$($lcBuckets -join ', ')}: $($s.text)" }
                elseif (Test-InSet $s.permEq 'OBJECT_VERSION_DELETE') { $ovd[$b] = $true }
            }
        }
        $missing = @($lcBuckets | Where-Object { -not $ovd.ContainsKey($_) })
        , @(($st.Count -ge 1 -and $bad.Count -eq 0 -and $missing.Count -eq 0), "statements=$($st.Count); request.permission = 'OBJECT_VERSION_DELETE' statement missing for: [$($missing -join ', ')]; bad: $($bad -join ' | ')")
    }
    PlanAssert 'iam-6: bucket access matrix is exhaustive -- every statement parses (no any-user), subject in the 5 known subjects, every manage/use carries a target.* = condition, every bucket named is one of the 3 buckets and its subject is on that bucket allowlist' {
        $bad = @($stmtErrors)
        foreach ($s in $stmts) {
            if ($s.err) { $bad += "$($s.err): $($s.text)"; continue }
            $subj = Get-SubjectKey $s
            if (-not (Test-InSet $knownSubjects $subj)) { $bad += "subject '$subj' is not a known subject [$($knownSubjects -join ', ')]: $($s.text)"; continue }
            if (($s.verb -eq 'manage' -or $s.verb -eq 'use') -and $s.targetEq -eq 0) { $bad += "unconditioned $($s.verb) in $($s.scope) (no target.* = condition): $($s.text)" }
            if ($s.unsound.Count -gt 0) { $bad += "unsound where ($($s.unsound -join '; ')): $($s.text)" }
            foreach ($b in $s.buckets) {
                if (-not (Test-InSet $bucketNames $b)) { $bad += "unknown bucket '$b': $($s.text)" }
                elseif (-not (Test-InSet $bucketSubjects[$b] $subj)) { $bad += "cross-bucket: '$subj' is not on the allowlist of '$b' [$($bucketSubjects[$b] -join ', ')]: $($s.text)" }
            }
        }
        $pols = Get-Planned 'oci_identity_policy'; $pols = @($pols)
        , @(($stmts.Count -ge 1 -and $bad.Count -eq 0), "statements=$($stmts.Count) across $($pols.Count) policies; bad: $($bad -join ' | ')")
    }

    # ---------- 7. 동적 그룹 [plan] — 이름 예외: joshuatech-node-a ----------
    PlanAssert 'dg-1: dynamic group joshuatech-node-a exists (exactly 1)' {
        $dg = @((Get-Planned 'oci_identity_dynamic_group') | Where-Object { [string]::Equals("$($_.values.name)", 'joshuatech-node-a', [StringComparison]::Ordinal) })
        , @(($dg.Count -eq 1), "matching dynamic groups=$($dg.Count)")
    }
    PlanAssert 'dg-2: joshuatech-node-a matching rule contains only the node A instance (no node B)' {
        $dg = @((Get-Planned 'oci_identity_dynamic_group') | Where-Object { [string]::Equals("$($_.values.name)", 'joshuatech-node-a', [StringComparison]::Ordinal) })
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

    # ---------- 8. KMS [plan + tf-text] — SOFTWARE + AES-256, 회전 off, DEFAULT 볼트, 이름 예외 joshuatech-key·joshuatech-vault ----------
    PlanAssert 'kms-1: every oci_kms_key is protection_mode SOFTWARE + key_shape AES/32 (AES-256) + is_auto_rotation_enabled = false (explicit); exactly one key is display_name joshuatech-key' {
        $ks = Get-Planned 'oci_kms_key'
        $bad = @(); $named = 0
        foreach ($k in $ks) {
            $v = $k.values
            if ([string]::Equals("$($v.display_name)", 'joshuatech-key', [StringComparison]::Ordinal)) { $named++ }
            if (-not [string]::Equals("$($v.protection_mode)", 'SOFTWARE', [StringComparison]::Ordinal)) { $bad += "$($k.address): protection_mode=$($v.protection_mode) (want SOFTWARE)" }
            $shape = $null; try { $shape = $v.key_shape[0] } catch { $shape = $null }
            $shapeTxt = if ($null -eq $shape) { 'n/a' } else { "$($shape.algorithm)/$($shape.length)" }
            if ($null -eq $shape -or -not [string]::Equals("$($shape.algorithm)", 'AES', [StringComparison]::Ordinal) -or "$($shape.length)" -ne '32') { $bad += "$($k.address): key_shape=$shapeTxt (want AES/32)" }
            if ($v.is_auto_rotation_enabled -ne $false) { $bad += "$($k.address): is_auto_rotation_enabled=$($v.is_auto_rotation_enabled) (want explicit false)" }
        }
        , @(($ks.Count -ge 1 -and $bad.Count -eq 0 -and $named -eq 1), "keys=$($ks.Count); display_name joshuatech-key=$named (want 1); bad: $($bad -join ' | ')")
    }
    Test-Group 'kms-2' {
        $blocks = @()
        foreach ($t in @('oci_kms_key', 'oci_kms_vault')) { $bl = Get-TfResourceBlocks $ociDir $t; $blocks += @($bl | ForEach-Object { $_.type = $t; $_ }) }
        $bad = @($blocks | Where-Object { $_.body -notmatch 'prevent_destroy\s*=\s*true' } | ForEach-Object { "$($_.file):$($_.type).$($_.name)" })
        $nKey = @($blocks | Where-Object { $_.type -eq 'oci_kms_key' }).Count
        Assert 'kms-2: every oci_kms_key AND oci_kms_vault block declares lifecycle prevent_destroy = true [tf-text] (>= 1 key block)' ($nKey -ge 1 -and $bad.Count -eq 0) "key blocks=$nKey, all blocks=$($blocks.Count); missing: $($bad -join ', ')"
    }
    PlanAssert 'kms-3: exactly one oci_kms_vault, vault_type DEFAULT, display_name joshuatech-vault' {
        $vs = Get-Planned 'oci_kms_vault'
        $ok = ($vs.Count -eq 1 -and [string]::Equals("$($vs[0].values.vault_type)", 'DEFAULT', [StringComparison]::Ordinal) -and [string]::Equals("$($vs[0].values.display_name)", 'joshuatech-vault', [StringComparison]::Ordinal))
        , @($ok, "vaults=$($vs.Count): $(@($vs | ForEach-Object { "$($_.address) type=$($_.values.vault_type) name=$($_.values.display_name)" }) -join ', ')")
    }

    # ---------- 9. Object Storage lifecycle [plan] — previous-object-versions DELETE 60일 + 현재 버전 규칙은 접두사 필수 ----------
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
    for ($li = 0; $li -lt $lcBuckets.Count; $li++) {
        $lb = $lcBuckets[$li]
        PlanAssert "lc-$($li + 1): bucket '$lb' has an enabled previous-object-versions DELETE 60 DAYS rule, and every current-version rule (target = objects) on it carries >= 1 inclusion prefix (declaration only; actual deletion = VD-6)" {
            $found = $false; $seen = @(); $bad = @()
            foreach ($p in (Get-Planned 'oci_objectstorage_object_lifecycle_policy')) {
                if (-not [string]::Equals("$(Resolve-LcBucket $p)", $lb, [StringComparison]::Ordinal)) { continue }
                $rules = @(); if ($p.values -and $p.values.rules) { $rules = @($p.values.rules) }
                foreach ($r in $rules) {
                    $seen += "target=$($r.target) action=$($r.action) $($r.time_amount) $($r.time_unit) enabled=$($r.is_enabled)"
                    if ("$($r.target)" -eq 'previous-object-versions' -and "$($r.action)" -match '(?i)^DELETE$' -and "$($r.time_amount)" -eq '60' -and "$($r.time_unit)" -match '(?i)^DAYS$' -and $r.is_enabled -ne $false) { $found = $true }
                    if ("$($r.target)" -eq 'objects') {
                        # 현재 버전 규칙은 접두사 필수 — 접두사 없는 objects DELETE는 버킷의 모든 현재 객체를 만료시킨다(백업 전멸 경로)
                        $prefixes = @(); try { $prefixes = @($r.object_name_filter[0].inclusion_prefixes | Where-Object { "$_" -ne '' }) } catch { $prefixes = @() }
                        if ($prefixes.Count -eq 0) { $bad += "rule '$($r.name)' targets current objects ($($r.action) $($r.time_amount) $($r.time_unit)) with no inclusion prefix" }
                    }
                }
            }
            , @(($found -and $bad.Count -eq 0), "previous-object-versions DELETE 60 DAYS enabled found=$found; rules seen: $($seen -join ' | '); bad: $($bad -join ' | ')")
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
