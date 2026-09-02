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
#   - [tf-text] 표시 단언은 .tf 원문만 읽는다(plan JSON이 lifecycle prevent_destroy 등 일부 선언을 노출하지
#     않으므로 중괄호 균형 최소 파서로 리소스 블록을 추출해 검사한다). 자격 증명 불필요.
#
# 구성 계약(T007+ 구현자가 따라야 하는 형태 — 이 스위트가 곧 계약이다):
#   - 리소스는 루트 모듈에 평면 선언(모듈 호출 없음; 이 스위트는 root_module만 순회한다).
#   - 노드 리소스 이름 라벨은 (?i)node[-_]?a / (?i)node[-_]?b 패턴을 포함한다(NSG·인스턴스 공통).
#   - 버킷 이름은 정확히 jt-tfstate·jt-backup·jt-backup-platform (3개 전부, 그 외 없음).
#   - NSG 규칙 source는 리터럴 Cloudflare IPv4 CIDR이거나 data.cloudflare_ip_ranges 참조다(둘 다 허용).
#   - OBJECT_VERSION_DELETE 정책 단언은 선언 존재까지만이다 — 규칙이 실제로 이전 버전을 삭제하는지는
#     VD-6(T010 apply 후 첫 만료 관찰)에서 확인한다.
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

# tofu 실행(-chdir 방식). stderr는 임시 파일로 받아 문자열로 돌려준다.
function Invoke-Tofu([string]$dir, [string[]]$tofuArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('tofu-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        $out = & tofu "-chdir=$dir" @tofuArgs 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile) } else { '' }
    } finally { Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue }
    return @{ out = (@($out | ForEach-Object { "$_" }) -join "`n"); err = $err.Trim(); code = $code }
}

# ---------- plan JSON 순회 헬퍼(전부 방어적 — 키가 없으면 빈 배열/$null) ----------
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
                if ($inStr) { if ($ch -eq '"' -and $text[$j - 1] -ne '\') { $inStr = $false } }
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
        $rc = @(); if ($script:planJson.resource_changes) { $rc = @($script:planJson.resource_changes) }
        $bad = @($rc | Where-Object { $_.change -and $_.change.actions -and (@($_.change.actions) -contains 'delete') } |
                ForEach-Object { "$($_.address) [$(@($_.change.actions) -join ',')]" })
        , @(($bad.Count -eq 0), ($bad -join '; '))
    }

    # ---------- 3. NSG [plan] ----------
    $nsgA = @(); $nsgB = @()
    if ($script:planJson) {
        $nsgCfg = Get-Config 'oci_core_network_security_group'
        $nsgA = @($nsgCfg | Where-Object { "$($_.name)" -match '(?i)node[-_]?a' })
        $nsgB = @($nsgCfg | Where-Object { "$($_.name)" -match '(?i)node[-_]?b' })
    }
    PlanAssert 'nsg-1: NSG resources exist for node A and node B (name label node[-_]a / node[-_]b)' {
        , @(($nsgA.Count -eq 1 -and $nsgB.Count -eq 1), "nodeA NSG count=$($nsgA.Count), nodeB NSG count=$($nsgB.Count)")
    }

    # 규칙 리소스를 NSG A/B로 분류(구성의 network_security_group_id 참조로)
    function Get-RuleNsg($cfg) {
        $refs = Get-Refs $cfg.expressions.network_security_group_id
        foreach ($n in $nsgA) { foreach ($r in $refs) { if ($r.StartsWith("oci_core_network_security_group.$($n.name)", [StringComparison]::Ordinal)) { return 'A' } } }
        foreach ($n in $nsgB) { foreach ($r in $refs) { if ($r.StartsWith("oci_core_network_security_group.$($n.name)", [StringComparison]::Ordinal)) { return 'B' } } }
        return $null
    }

    PlanAssert 'nsg-2: node A ingress rules are only 443/tcp from Cloudflare CIDRs (literal set or data.cloudflare_ip_ranges ref)' {
        $ruleCfg = Get-Config 'oci_core_network_security_group_security_rule'
        $aIngress = @(); $bad = @()
        foreach ($rc in @($ruleCfg | Where-Object { (Get-RuleNsg $_) -eq 'A' })) {
            $insts = Get-PlannedFor $rc.address
            if ($insts.Count -eq 0) { $bad += "$($rc.address): no planned instance (unknown count/for_each?) -- fail closed"; continue }
            foreach ($pi in $insts) {
                if ("$($pi.values.direction)" -ne 'INGRESS') { continue }
                $aIngress += $pi
                $why = @()
                if ("$($pi.values.protocol)" -ne '6') { $why += "protocol=$($pi.values.protocol) (want '6'/tcp)" }
                $port = $null
                try { $port = $pi.values.tcp_options[0].destination_port_range[0] } catch { $port = $null }
                if ($null -eq $port -or "$($port.min)" -ne '443' -or "$($port.max)" -ne '443') { $why += 'destination port range != 443..443' }
                $src = "$($pi.values.source)"
                $srcOk = ($src -and ($cloudflareCidrs -contains $src))
                if (-not $srcOk) {
                    $refs = @(Get-Refs $rc.expressions.source) + @(Get-Refs $rc.for_each_expression)
                    foreach ($r in $refs) { if ($r.IndexOf('cloudflare_ip_ranges', [StringComparison]::Ordinal) -ge 0) { $srcOk = $true } }
                }
                if (-not $srcOk) { $why += "source='$src' is neither a published Cloudflare IPv4 CIDR nor a data.cloudflare_ip_ranges reference" }
                if ($why.Count -gt 0) { $bad += "$($pi.address): $($why -join '; ')" }
            }
        }
        , @(($aIngress.Count -ge 1 -and $bad.Count -eq 0), "ingress rules=$($aIngress.Count); $($bad -join ' | ')")
    }

    PlanAssert 'nsg-3: node B NSG has zero ingress rules' {
        $ruleCfg = Get-Config 'oci_core_network_security_group_security_rule'
        $bIngress = @()
        foreach ($rc in @($ruleCfg | Where-Object { (Get-RuleNsg $_) -eq 'B' })) {
            $insts = Get-PlannedFor $rc.address
            if ($insts.Count -eq 0) {
                $d = $null; try { $d = $rc.expressions.direction.constant_value } catch { $d = $null }
                if ("$d" -ne 'EGRESS') { $bIngress += "$($rc.address) (direction unknown -- fail closed)" }   # 방향 불명은 INGRESS로 취급
            } else {
                foreach ($pi in $insts) { if ("$($pi.values.direction)" -eq 'INGRESS') { $bIngress += "$($pi.address)" } }
            }
        }
        , @(($bIngress.Count -eq 0), ($bIngress -join '; '))
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
            foreach ($m in [regex]::Matches($s, 'OBJECT_[A-Z_]+')) {
                $perms += $m.Value
                if ($m.Value -ne 'OBJECT_CREATE' -and $m.Value -ne 'OBJECT_INSPECT') { $bad += "permission $($m.Value) not allowed: $s" }
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
        $blocks = Get-TfResourceBlocks $cfDir 'cloudflare_zero_trust_access_policy'
        if ($blocks.Count -eq 0) { $blocks = Get-TfResourceBlocks $cfDir 'cloudflare_zero_trust_access_application' }
        $bad = @($blocks | Where-Object { $_.body -notmatch 'session_duration\s*=' } | ForEach-Object { "$($_.file):$($_.name)" })
        Assert 'access-1: every Zero Trust Access policy (or app) sets session_duration [tf-text]' ($blocks.Count -ge 1 -and $bad.Count -eq 0) "blocks=$($blocks.Count); missing session_duration: $($bad -join ', ')"
    }
} finally {
    Remove-Item -LiteralPath $planFile -Force -ErrorAction SilentlyContinue
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
