# tests/docs/restore-drill.tests.ps1 — 복구 런북 docs/runbooks/restore-drill.md 정적 계약 검사 (T058, test-first)
# 실행: pwsh -NoProfile -File tests/docs/restore-drill.tests.ps1
#
# 목적: 복구 런북이 과제 T058 문면과 설계(specs/003-platform-foundation/design/build-notes.md 「T058」 결정 D1–D14)의 계약 모양을
#   잃지 않게 고정한다 — 절 제목 · 필수 어구 · YAML 매니페스트 블록의 모양 · 비밀 모양 0 · docs/README.md 색인 · 상호 참조.
#   원문만 읽는다(kubectl · oci · 라이브 접근 없음). rd-8의 kubeconform은 로컬 스키마(CNPG 5종 + ObjectStore + batch Job — 출처·커밋은
#   build-notes 「T058」)를 1순위로 읽고 기본 위치(GitHub)는 폴백이다 — .superpowers/kc-cache가 있으면 받은 스키마를 재사용한다(오프라인 가능).
#   외부 프레임워크 없음 — tests/decisions/madr.tests.ps1과 같은 구조(Assert · Test-Group · 요약 줄 · exit 규율).
#
# SKIP 없음 · fail closed: 런북이 없으면 rd-1-exists와 함께 런북을 읽는 단언 전부가 FAIL이다(사유 = 선행 조건).
# run-all 슬롯(tests/run-all.ps1 1n 'restore-drill')과의 계약: 마지막 줄 '<N> passed, <M> failed' · exit 0 = FAIL 0, exit 1 = FAIL 1개 이상.
#   rd-8은 'INFO rd-8-kubeconform: …' 줄로 합계 밖이다. 단 도구와 스키마가 있는데 검증이 실패하면 FAIL로 합계에 넣는다.
#
# 단언(id):
#   rd-1-exists          런북 파일이 있다
#   rd-1-head            첫 줄 = '# Runbook: restore-drill'
#   rd-1-bom/crlf/tab-*  런북 · 이 테스트 파일 · docs/README.md 각각 UTF-8 BOM 0 · CR 0 · TAB 0(파일별 단언 9개)
#   rd-2-sections        코드 펜스 밖 ATX 제목에 어구 목적 · 전제 · 절차 · 검증 · 되돌리기 · §1 · §3 · §4 · §5 · §6 · §9 · §10 각각 ≥ 1
#                        (§n 바로 뒤에 숫자가 오면 다른 절이다 — §1은 §10 · §11로 채워지지 않는다) + 절에 묶인 어구:
#                        「절차」는 '## §3'–'## §6' 제목마다 · 「검증」은 '## §7' · 「되돌리기」는 '## §8'(다른 제목의 '되돌리기용'으로 채워지지 않는다)
#   rd-3-phrases         본문(코드 블록 포함)에 필수 어구 각각 ≥ 1
#   rd-3-prohibitions    'cnpg.io/skipEmptyWalArchiveCheck' · 'k3s server --cluster-reset'이 든 **코드 펜스 밖** 줄 가운데 적어도 하나에 '금지'
#                        (코드 블록 주석만으로는 통과하지 않는다)
#   rd-4-yaml-*          ```yaml 펜스 블록(블록 안 '---' 문서 분리 허용) — blocks(≥ 4) · docs(문서마다 apiVersion · kind · metadata.name) ·
#                        cluster(Cluster 공통) · cluster-pitr(isWALArchiver: true — serverName 값 2개 · 서로 다름) · cluster-side(isWALArchiver
#                        없음 — plugins: 0) · cluster-servername(serverName의 자리 — externalClusters 아래 = 'pg-main'(원천 세대) · 전체 PITR의
#                        plugins 아래 = 'pg-main-r<N>' 하나 · 그 밖의 자리 0) · job(barman-cloud-backup-list Job — 이미지 digest · 자격 secretKeyRef만 ·
#                        보안 필드 · command 첫 항목 고정 · hostPath · 삭제/복원 명령 · 인라인 자격 0) · backup(수동 Backup). 줄 단위 정규식(YAML 파서
#                        없음) — 주석 줄은 건너뛰고 값 뒤 ' #…' 주석은 떼고 본다. 들여쓰기는 metadata 블록 범위와 serverName의 소속(spec 바로 아래
#                        키 = 들여쓰기 2칸 이하의 마지막 키)만 본다.
#   rd-5-secrets-*       비밀 모양 0 — 런북 · 이 테스트 파일 · docs/README.md(패턴 원문이 자기 자신에 걸리지 않게 썼다). 이메일 일반형은
#                        허용 목록(대표 · E2E 주소)만 통과한다.
#   rd-6-index           docs/README.md에 '](runbooks/restore-drill.md)' 정확히 1회
#   rd-7-xref            같은 줄 상호 참조: vault-unseal.md+§7 · bootstrap.md+§2 · bootstrap.md+§7 · rollback.md · platform-backup.sh · backup-verify.ps1
#   rd-7-targets         참조 대상 실재: vault-unseal.md의 '## §7 ' 제목 · bootstrap.md의 '## §2 ' · '## §7 ' 제목 ·
#                        infra/bootstrap/platform-backup.sh · scripts/backup-verify.ps1
#   rd-8-kubeconform     (INFO · 합계 밖) .superpowers/bin/kubeconform.exe와 .superpowers/t058/schemas/가 둘 다 있을 때만: 추출한 YAML 블록을
#                        저장소 밖 임시 디렉터리에 써서 kubeconform -strict -summary를 돌린다 — 스키마 위치 순서 = 로컬(.superpowers/t058/schemas:
#                        CNPG v1.30.0 CRD 파생 5종 + ObjectStore + batch Job) 1순위 · 기본 위치(GitHub)는 폴백, .superpowers/kc-cache가 있으면
#                        -cache로 준다 → exit 0 · Invalid 0 · Errors 0 · Valid = 문서 수면 'INFO rd-8-kubeconform: Valid N', 아니면 FAIL(합계에 넣는다).
#                        도구나 스키마가 없으면 'INFO rd-8-kubeconform: skipped (tool or schemas absent)' 한 줄. 임시 디렉터리는 finally에서 지운다.
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$runbookPath = Join-Path $repo 'docs/runbooks/restore-drill.md'
$readmePath = Join-Path $repo 'docs/README.md'
$selfPath = $PSCommandPath
$utf8 = New-Object System.Text.UTF8Encoding($false)

$script:pass = 0
$script:fail = 0

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 단언 그룹 격리 — 한 그룹의 예외가 나머지를 막지 않는다(madr.tests.ps1과 같다).
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

# 파일 → 바이트 + 텍스트(UTF-8, BOM 제거 — BOM은 rd-1-bom이 따로 본다). 없으면 $null.
function Read-Doc([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $bytes = [IO.File]::ReadAllBytes($path)
    $text = $utf8.GetString($bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    return [pscustomobject]@{ Bytes = $bytes; Text = $text; Lines = @($text -split "\r?\n") }
}

# 줄 분류: 코드 펜스(앞 공백 허용 · ``` 또는 ~~~ 3개 이상)를 열고 닫으며 prose / code / fence-open / fence-close로 나눈다.
# 닫는 펜스는 여는 펜스와 같은 글자 · 같거나 긴 길이 · 뒤에 정보 문자열 없음(CommonMark).
function Get-LineInfo([string[]]$lines) {
    $out = New-Object System.Collections.Generic.List[object]
    $inFence = $false; $fenceChar = [char]0; $fenceLen = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        $m = [regex]::Match($l, '^(\s*)(`{3,}|~{3,})(.*)$')
        if (-not $inFence -and $m.Success) {
            $inFence = $true; $fenceChar = $m.Groups[2].Value[0]; $fenceLen = $m.Groups[2].Value.Length
            $out.Add([pscustomobject]@{ Index = $i; Text = $l; Kind = 'fence-open'; Info = $m.Groups[3].Value.Trim(); Indent = $m.Groups[1].Value.Length })
            continue
        }
        if ($inFence -and $m.Success -and $m.Groups[2].Value[0] -eq $fenceChar -and $m.Groups[2].Value.Length -ge $fenceLen -and $m.Groups[3].Value.Trim().Length -eq 0) {
            $inFence = $false
            $out.Add([pscustomobject]@{ Index = $i; Text = $l; Kind = 'fence-close'; Info = ''; Indent = 0 })
            continue
        }
        $kind = if ($inFence) { 'code' } else { 'prose' }
        $out.Add([pscustomobject]@{ Index = $i; Text = $l; Kind = $kind; Info = ''; Indent = 0 })
    }
    return , $out
}

# ```yaml 블록 → 블록 목록(각 블록 = 펜스 들여쓰기만큼 내어 쓴 줄 배열). 닫히지 않은 블록도 끝까지 하나로 센다(펜스 오류는 rd-4가 드러낸다).
function Get-YamlBlocks($info) {
    $blocks = New-Object System.Collections.Generic.List[object]
    $cur = $null; $indent = 0
    foreach ($e in $info) {
        if ($e.Kind -eq 'fence-open') {
            if ($e.Info -match '^yaml\s*$') { $cur = New-Object System.Collections.Generic.List[string]; $indent = $e.Indent }
            else { $cur = $null }
            continue
        }
        if ($e.Kind -eq 'fence-close') { if ($null -ne $cur) { $blocks.Add($cur.ToArray()) }; $cur = $null; continue }
        if ($e.Kind -eq 'code' -and $null -ne $cur) {
            $t = $e.Text
            $n = 0
            while ($n -lt $indent -and $n -lt $t.Length -and $t[$n] -eq ' ') { $n++ }
            $cur.Add($t.Substring($n))
        }
    }
    if ($null -ne $cur) { $blocks.Add($cur.ToArray()) }
    return , $blocks
}

# 블록 → 문서('---' 줄로 나눔 · 주석/빈 줄만 있는 조각은 버린다)
function Split-YamlDocs([string[]]$lines) {
    $docs = New-Object System.Collections.Generic.List[object]
    $cur = New-Object System.Collections.Generic.List[string]
    foreach ($l in $lines + @('---')) {
        if ($l -match '^---\s*$') {
            $meaningful = @($cur | Where-Object { $_.Trim().Length -gt 0 -and -not $_.TrimStart().StartsWith('#') })
            if ($meaningful.Count -gt 0) { $docs.Add($cur.ToArray()) }
            $cur = New-Object System.Collections.Generic.List[string]
            continue
        }
        $cur.Add($l)
    }
    return , $docs
}

# 주석 줄은 버리고 값 뒤 ' #…' 주석을 뗀 줄들(키 판정용)
function Get-KeyLines([string[]]$doc) {
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($l in $doc) {
        if ($l.TrimStart().StartsWith('#')) { continue }
        $out.Add(($l -replace '\s+#.*$', '').TrimEnd())
    }
    return , $out.ToArray()
}

# 키 값 목록(따옴표 제거) — '- key: v' 형태 포함. 원소를 하나씩 내보낸다(호출하는 쪽이 @(…)로 받는다)
function Get-Values([string[]]$keyLines, [string]$key) {
    $rx = '^\s*(?:-\s+)?' + [regex]::Escape($key) + ':\s*(.*?)\s*$'
    foreach ($l in $keyLines) {
        $m = [regex]::Match($l, $rx)
        if ($m.Success) { $m.Groups[1].Value.Trim('"', "'") }
    }
}

function Test-Line([string[]]$keyLines, [string]$pattern) { return (@($keyLines | Where-Object { $_ -cmatch $pattern }).Count -gt 0) }

# 키 값 + 소속(Section = 들여쓰기 2칸 이하인 마지막 키 — Cluster 문서에서는 spec 바로 아래 키: externalClusters · plugins …).
# 그 키 줄 자체가 들여쓰기 2칸 이하면 소속은 자기 자신이 된다(그 밖의 자리로 드러난다). 원소를 하나씩 내보낸다.
function Get-SectionValues([string[]]$keyLines, [string]$key) {
    $section = ''
    $rx = '^\s*(?:-\s+)?' + [regex]::Escape($key) + ':\s*(.*?)\s*$'
    foreach ($l in $keyLines) {
        $h = [regex]::Match($l, '^ {0,2}([A-Za-z][\w.-]*):')
        if ($h.Success) { $section = $h.Groups[1].Value }
        $m = [regex]::Match($l, $rx)
        if ($m.Success) { [pscustomobject]@{ Section = $section; Value = $m.Groups[1].Value.Trim('"', "'") } }
    }
}

# 다음 비어 있지 않은 줄(없으면 '')
function Get-NextLine([string[]]$keyLines, [int]$index) {
    for ($n = $index + 1; $n -lt $keyLines.Count; $n++) { if ($keyLines[$n].Trim().Length -gt 0) { return $keyLines[$n] } }
    return ''
}

$runbook = Read-Doc $runbookPath
$readme = Read-Doc $readmePath
$self = Read-Doc $selfPath
$missingRunbook = 'precondition failed: docs/runbooks/restore-drill.md missing'

# ---------- rd-1: 존재 · 첫 줄 · 바이트 위생 ----------
Test-Group 'rd-1' {
    Assert 'rd-1-exists: docs/runbooks/restore-drill.md exists' ($null -ne $runbook) "missing: $runbookPath"
    if ($null -eq $runbook) { Assert 'rd-1-head: first line is # Runbook: restore-drill' $false $missingRunbook }
    else {
        $first = $runbook.Lines[0]
        Assert 'rd-1-head: first line is # Runbook: restore-drill' ([string]::Equals($first, '# Runbook: restore-drill', [StringComparison]::Ordinal)) "first line = '$first'"
    }
    $targets = [ordered]@{ 'runbook' = $runbook; 'test' = $self; 'readme' = $readme }
    foreach ($k in $targets.Keys) {
        $d = $targets[$k]
        if ($null -eq $d) {
            foreach ($c in 'bom', 'crlf', 'tab') { Assert "rd-1-$c-${k}: byte hygiene" $false "precondition failed: $k file missing" }
            continue
        }
        $b = $d.Bytes
        $hasBom = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
        $cr = [regex]::Matches($d.Text, '\r').Count     # CR · TAB은 ASCII라 UTF-8 디코딩 뒤에도 바이트 수와 같다
        $tab = [regex]::Matches($d.Text, '\t').Count
        Assert "rd-1-bom-${k}: no UTF-8 BOM" (-not $hasBom) 'file starts with EF BB BF'
        Assert "rd-1-crlf-${k}: no CR bytes (LF only)" ($cr -eq 0) "CR bytes = $cr"
        Assert "rd-1-tab-${k}: no TAB bytes" ($tab -eq 0) "TAB bytes = $tab"
    }
}

# 런북 파생 정보(없으면 빈 값 — 아래 그룹들은 $runbook을 먼저 본다)
$info = if ($null -ne $runbook) { Get-LineInfo $runbook.Lines } else { $null }
$yamlBlocks = if ($null -ne $info) { Get-YamlBlocks $info } else { New-Object System.Collections.Generic.List[object] }
$yamlDocs = New-Object System.Collections.Generic.List[object]
foreach ($blk in $yamlBlocks) { foreach ($d in (Split-YamlDocs $blk)) { $yamlDocs.Add($d) } }

# ---------- rd-2: 절 제목(ATX · 코드 펜스 밖) ----------
Test-Group 'rd-2' {
    if ($null -eq $runbook) { Assert 'rd-2-sections: ATX headings carry the required phrases' $false $missingRunbook; return }
    $headings = @($info | Where-Object { $_.Kind -eq 'prose' -and $_.Text -cmatch '^ {0,3}#{1,6}(\s|$)' } | ForEach-Object { $_.Text })
    $missing = @()
    foreach ($p in '목적', '전제', '절차', '검증', '되돌리기') {
        if (@($headings | Where-Object { $_.Contains($p) }).Count -eq 0) { $missing += $p }
    }
    foreach ($s in '§1', '§3', '§4', '§5', '§6', '§9', '§10') {
        $rx = [regex]::Escape($s) + '(?!\d)'
        if (@($headings | Where-Object { $_ -cmatch $rx }).Count -eq 0) { $missing += $s }
    }
    # 절 번호에 묶인 어구(설계 D2): 「절차」는 §3–§6의 '## ' 제목 · 「검증」은 §7 · 「되돌리기」는 §8
    $bound = [ordered]@{ '§3' = '절차'; '§4' = '절차'; '§5' = '절차'; '§6' = '절차'; '§7' = '검증'; '§8' = '되돌리기' }
    foreach ($s in $bound.Keys) {
        $h = @($headings | Where-Object { $_ -cmatch ('^## ' + [regex]::Escape($s) + '(?!\d)') })
        if (@($h | Where-Object { $_.Contains($bound[$s]) }).Count -eq 0) { $missing += "$($bound[$s]) in '## $s'" }
    }
    Assert 'rd-2-sections: ATX headings carry the required phrases' ($missing.Count -eq 0) "headings=$($headings.Count); missing: $($missing -join ', ')"
}

# ---------- rd-3: 필수 어구 · 금지 문맥 ----------
Test-Group 'rd-3' {
    if ($null -eq $runbook) {
        Assert 'rd-3-phrases: required phrases present' $false $missingRunbook
        Assert 'rd-3-prohibitions: prose lines state the prohibitions' $false $missingRunbook
        return
    }
    $phrases = @('bootstrap.recovery', 'externalClusters', 'recoveryTarget', 'targetTime', 'serverName', 'barman-cloud-backup-list',
        'pg_dump', 'pg_restore', '--single-transaction', 'age -d', 'svc-verify', 'Read-Host',
        'cnpg.io/skipEmptyWalArchiveCheck', '--cluster-reset')
    $absent = @($phrases | Where-Object { -not $runbook.Text.Contains($_) })
    Assert 'rd-3-phrases: required phrases present' ($absent.Count -eq 0) "absent: $($absent -join ' | ')"

    $prose = @($info | Where-Object { $_.Kind -eq 'prose' } | ForEach-Object { $_.Text })
    $bad = @()
    foreach ($p in 'cnpg.io/skipEmptyWalArchiveCheck', 'k3s server --cluster-reset') {
        $withPhrase = @($prose | Where-Object { $_.Contains($p) })
        if (@($withPhrase | Where-Object { $_.Contains('금지') }).Count -eq 0) { $bad += "$p (prose lines with phrase = $($withPhrase.Count), none says 금지)" }
    }
    Assert 'rd-3-prohibitions: prose lines state the prohibitions' ($bad.Count -eq 0) ($bad -join '; ')
}

# ---------- rd-4: YAML 매니페스트 블록 ----------
Test-Group 'rd-4' {
    $names = [ordered]@{
        blocks         = 'rd-4-yaml-blocks: >= 4 fenced yaml blocks'
        docs           = 'rd-4-yaml-docs: every document has apiVersion, kind, metadata.name'
        cluster        = 'rd-4-yaml-cluster: recovery Cluster documents share the contract'
        'cluster-pitr' = 'rd-4-yaml-cluster-pitr: full-PITR Cluster archives under a second, different serverName'
        'cluster-side' = 'rd-4-yaml-cluster-side: side Cluster has no spec.plugins (no archiving)'
        'cluster-servername' = 'rd-4-yaml-cluster-servername: serverName placement (externalClusters = pg-main, plugins = pg-main-r<N>)'
        job            = 'rd-4-yaml-job: barman-cloud-backup-list Job shape'
        backup         = 'rd-4-yaml-backup: manual Backup uses the plugin method'
    }
    if ($null -eq $runbook) { foreach ($k in $names.Keys) { Assert $names[$k] $false $missingRunbook }; return }

    Assert $names['blocks'] ($yamlBlocks.Count -ge 4) "yaml blocks = $($yamlBlocks.Count), documents = $($yamlDocs.Count)"

    $docProblems = @(); $clusters = @(); $jobs = @(); $backups = @()
    $i = 0
    foreach ($doc in $yamlDocs) {
        $i++
        $kl = Get-KeyLines $doc
        $kind = ''
        $km = @($kl | Where-Object { $_ -cmatch '^kind:\s*\S' })
        if ($km.Count -gt 0) { $kind = ($km[0] -replace '^kind:\s*', '').Trim() }
        $hasApi = Test-Line $kl '^apiVersion:\s*\S'
        $metaName = $false
        for ($j = 0; $j -lt $kl.Count; $j++) {
            if ($kl[$j] -cmatch '^metadata:\s*$') {
                for ($k2 = $j + 1; $k2 -lt $kl.Count; $k2++) {
                    if ($kl[$k2] -cmatch '^\S') { break }
                    if ($kl[$k2] -cmatch '^\s+name:\s*\S') { $metaName = $true; break }
                }
                break
            }
        }
        if (-not ($hasApi -and $kind.Length -gt 0 -and $metaName)) { $docProblems += "doc#$i(kind='$kind' apiVersion=$hasApi metadata.name=$metaName)" }
        $entry = [pscustomobject]@{ No = $i; Raw = $doc; Keys = $kl }
        switch -CaseSensitive ($kind) {
            'Cluster' { $clusters += $entry }
            'Job' { $jobs += $entry }
            'Backup' { $backups += $entry }
        }
    }
    Assert $names['docs'] ($yamlDocs.Count -gt 0 -and $docProblems.Count -eq 0) "documents=$($yamlDocs.Count); problems: $($docProblems -join '; ')"

    # Cluster 공통 + 갈래
    $common = @(); $pitr = 0; $side = 0; $pitrProblems = @(); $sideProblems = @(); $snProblems = @()
    foreach ($c in $clusters) {
        $kl = $c.Keys; $p = @()
        $sources = @(Get-Values $kl 'source')
        $dashNames = @($kl | ForEach-Object { $m = [regex]::Match($_, '^\s*-\s+name:\s*(\S+)\s*$'); if ($m.Success) { $m.Groups[1].Value.Trim('"', "'") } })
        if ($sources.Count -eq 0) { $p += 'no source:' }
        foreach ($s in $sources) { if ($dashNames -cnotcontains $s) { $p += "source '$s' is not an externalClusters '- name:'" } }
        if (-not (Test-Line $kl '^\s*bootstrap:\s*$')) { $p += 'no bootstrap:' }
        if (-not (Test-Line $kl '^\s*recovery:\s*$')) { $p += 'no recovery:' }
        if (Test-Line $kl '^\s*initdb:') { $p += 'initdb: present (only one bootstrap method)' }
        if (-not (Test-Line $kl '^\s*externalClusters:\s*$')) { $p += 'no externalClusters:' }
        if (-not (Test-Line $kl '^\s*(-\s+)?name:\s*barman-cloud\.cloudnative-pg\.io$')) { $p += 'no name: barman-cloud.cloudnative-pg.io' }
        if (-not (Test-Line $kl '^\s*barmanObjectName:\s*oci-backups$')) { $p += 'no barmanObjectName: oci-backups' }
        if (-not (Test-Line $kl '^\s*serverName:\s*pg-main$')) { $p += 'no serverName: pg-main (origin)' }
        if (Test-Line $kl '^\s*imageName:') { $p += 'imageName: present' }
        if ((($c.Raw) -join "`n").Contains('skipEmptyWalArchiveCheck')) { $p += 'skipEmptyWalArchiveCheck present' }
        if (-not (Test-Line $kl '^\s*enableSuperuserAccess:\s*false$')) { $p += 'no enableSuperuserAccess: false' }
        if (-not (Test-Line $kl '^\s*major:\s*18$')) { $p += 'no major: 18' }
        if ($p.Count -gt 0) { $common += "Cluster doc#$($c.No): $($p -join ', ')" }

        $isPitr = Test-Line $kl '^\s*isWALArchiver:\s*true$'
        if ($isPitr) {
            $pitr++
            $sn = @(Get-Values $kl 'serverName')
            $distinct = @($sn | Sort-Object -Unique)
            if (-not ($sn.Count -eq 2 -and $distinct.Count -eq 2)) { $pitrProblems += "doc#$($c.No) serverName values = [$($sn -join ', ')]" }
        } else {
            $side++
            if (Test-Line $kl '^\s*plugins:') { $sideProblems += "doc#$($c.No) has plugins:" }
        }

        # serverName의 자리(리뷰 A4): 원천 = externalClusters 아래 'pg-main'(예시의 원천 세대 r0) · 새 세대 = plugins 아래 'pg-main-r<N>'
        #   — 두 값을 맞바꾼 매니페스트(원천 = 새 세대 · 아카이브 = pg-main)는 빈 아카이브 검사에 걸리므로 여기서 잡는다
        $sv = @(Get-SectionValues $kl 'serverName')
        $ec = @($sv | Where-Object { $_.Section -ceq 'externalClusters' })
        $pl = @($sv | Where-Object { $_.Section -ceq 'plugins' })
        $elsewhere = @($sv | Where-Object { $_.Section -cne 'externalClusters' -and $_.Section -cne 'plugins' })
        $q = @()
        if ($ec.Count -eq 0) { $q += 'no serverName under externalClusters' }
        foreach ($v in $ec) { if ($v.Value -cne 'pg-main') { $q += "externalClusters serverName = '$($v.Value)' (want pg-main)" } }
        foreach ($v in $elsewhere) { $q += "serverName '$($v.Value)' under '$($v.Section)' (want externalClusters or plugins only)" }
        if ($isPitr) {
            if ($pl.Count -ne 1) { $q += "plugins serverName count = $($pl.Count) (want 1)" }
            foreach ($v in $pl) { if ($v.Value -cnotmatch '^pg-main-r\d+$') { $q += "plugins serverName = '$($v.Value)' (want pg-main-r<N>)" } }
        } elseif ($pl.Count -gt 0) { $q += "plugins serverName in a non-archiving Cluster: $(($pl | ForEach-Object { $_.Value }) -join ', ')" }
        if ($q.Count -gt 0) { $snProblems += "Cluster doc#$($c.No): $($q -join ', ')" }
    }
    Assert $names['cluster'] ($clusters.Count -ge 2 -and $common.Count -eq 0) "Cluster docs=$($clusters.Count); $($common -join '; ')"
    Assert $names['cluster-pitr'] ($pitr -ge 1 -and $pitrProblems.Count -eq 0) "full-PITR Cluster docs=$pitr; $($pitrProblems -join '; ')"
    Assert $names['cluster-side'] ($side -ge 1 -and $sideProblems.Count -eq 0) "side Cluster docs=$side; $($sideProblems -join '; ')"
    Assert $names['cluster-servername'] ($clusters.Count -ge 2 -and $snProblems.Count -eq 0) "Cluster docs=$($clusters.Count); $($snProblems -join '; ')"

    # Job
    $jobProblems = @()
    if ($jobs.Count -eq 0) { $jobProblems += 'no Job document' }
    foreach ($jb in $jobs) {
        $kl = $jb.Keys; $raw = ($kl -join "`n"); $p = @()
        $images = @(Get-Values $kl 'image')
        if ($images.Count -eq 0) { $p += 'no image:' }
        foreach ($img in $images) {
            if ($img -cnotmatch '^ghcr\.io/cloudnative-pg/plugin-barman-cloud-sidecar:v0\.14\.0@sha256:[0-9a-f]{64}$') { $p += "image not digest-pinned sidecar v0.14.0: '$img'" }
        }
        $skr = @($kl | Where-Object { $_ -cmatch '^\s*secretKeyRef:\s*$' }).Count
        $sn = @($kl | Where-Object { $_ -cmatch '^\s*name:\s*oci-s3-backup$' }).Count
        if ($skr -ne 3 -or $sn -ne 3) { $p += "secretKeyRef=$skr, name: oci-s3-backup=$sn (want 3 and 3)" }
        $keys = @(@(Get-Values $kl 'key') | Sort-Object)
        $want = @('ACCESS_KEY_ID', 'ACCESS_SECRET_KEY', 'REGION')
        if (($keys -join ',') -cne ($want -join ',')) { $p += "key: values = [$($keys -join ', ')]" }
        foreach ($rx in '^\s*runAsNonRoot:\s*true$', '^\s*runAsUser:\s*26$', '^\s*restartPolicy:\s*Never$', '^\s*ttlSecondsAfterFinished:\s*\d+$',
            '^\s*readOnlyRootFilesystem:\s*true$', '^\s*automountServiceAccountToken:\s*false$', '^\s*allowPrivilegeEscalation:\s*false$',
            '^\s*drop:\s*\[ALL\]$', '^\s*type:\s*RuntimeDefault$') {
            if (-not (Test-Line $kl $rx)) { $p += "missing line /$rx/" }
        }
        foreach ($lit in 'barman-cloud-backup-list', 's3://joshuatech-backup/pg-main/') {
            if (-not $raw.Contains($lit)) { $p += "missing '$lit'" }
        }
        # 이 Job의 키는 사이드카와 같은 쓰기 · 삭제 권한 키다(리뷰 B6) → 명령 고정 · 다른 barman 명령 0 · hostPath 0 · 자격은 secretKeyRef로만
        $ci = -1
        for ($j = 0; $j -lt $kl.Count; $j++) { if ($kl[$j] -cmatch '^\s*command:\s*$') { $ci = $j; break } }
        $first = if ($ci -ge 0) { Get-NextLine $kl $ci } else { '' }
        if ($first -cnotmatch '^\s*-\s+/venv/bin/barman-cloud-backup-list$') { $p += "command first item = '$($first.Trim())' (want - /venv/bin/barman-cloud-backup-list)" }
        if (Test-Line $kl 'barman-cloud-(backup-delete|restore|wal-restore)') { $p += 'other barman-cloud command (delete/restore) present' }
        if (Test-Line $kl '^\s*(-\s+)?hostPath:') { $p += 'hostPath: present' }
        $credEnv = 0
        for ($j = 0; $j -lt $kl.Count; $j++) {
            if ($kl[$j] -cmatch '^\s*-\s+name:\s*(AWS_ACCESS_KEY_ID|AWS_SECRET_ACCESS_KEY)$') {
                $credEnv++
                $envName = $Matches[1]
                $next = Get-NextLine $kl $j
                if ($next -cnotmatch '^\s*valueFrom:\s*$') { $p += "$envName is not followed by valueFrom: (inline credential?) -- next line '$($next.Trim())'" }
            }
        }
        if ($credEnv -ne 2) { $p += "credential env entries AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY = $credEnv (want 2)" }
        if ($p.Count -gt 0) { $jobProblems += "Job doc#$($jb.No): $($p -join ', ')" }
    }
    Assert $names['job'] ($jobProblems.Count -eq 0) ($jobProblems -join '; ')

    # Backup
    $bkProblems = @()
    if ($backups.Count -eq 0) { $bkProblems += 'no Backup document' }
    foreach ($bk in $backups) {
        $kl = $bk.Keys; $p = @()
        if (-not (Test-Line $kl '^\s*method:\s*plugin$')) { $p += 'no method: plugin' }
        if (-not (Test-Line $kl '^\s*(-\s+)?name:\s*barman-cloud\.cloudnative-pg\.io$')) { $p += 'no name: barman-cloud.cloudnative-pg.io' }
        if ($p.Count -gt 0) { $bkProblems += "Backup doc#$($bk.No): $($p -join ', ')" }
    }
    Assert $names['backup'] ($bkProblems.Count -eq 0) ($bkProblems -join '; ')
}

# ---------- rd-5: 비밀 모양 0 ----------
# 패턴 원문은 자기 자신에 걸리지 않게 썼다(글자 집합 [Y] · [i] · [bsr] · 이스케이프 — 패턴 글자 바로 뒤가 '[' · '\'라 원문은 일치하지 않는다)
#   — 이 파일도 같은 검사를 받는다. 이메일 일반형은 허용 목록($secretAllow — 대표 주소 · E2E 주소, .claude/rules/infra.md)만 통과한다.
$secretPatterns = [ordered]@{
    'age-secret-key'    = 'AGE-SECRET-KE[Y]'
    'pem-private-key'   = 'BEGIN [A-Z ]*PRIVATE KEY'
    'jwt'               = 'eyJhbGciO[i]'
    'hash-hex16'        = '#[0-9a-f]{16,}'
    'cred-url'          = '(redis|postgresql)://[^\s/]+:[^\s/]+@'
    'cred-url-wide'     = '(redis|postgresql)://[^ ]+:[^ ]+@'
    'ip-10'             = '\b10\.\d+\.\d+\.\d+\b'
    'ip-192-168'        = '\b192\.168\.'
    'ip-172-16-31'      = '172\.(1[6-9]|2\d|3[01])\.'
    'ip-any-nonloopback' = '\b(?!127\.)(?!0\.0\.0\.0\b)\d{1,3}(\.\d{1,3}){3}\b'
    'ocid'              = 'ocid1\.'
    'ssh-dir'           = 'C:\\\.ssh'
    'ssh-dir-any'       = '[\\/]\.ssh[\\/]'
    'gmail'             = '@gmail\.com'
    'email'             = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
    'hex40'             = '\b[0-9a-f]{40}\b'
    'vault-token'       = 'hv[bsr]\.[A-Za-z0-9_-]{20,}'
    'github-token'      = 'gh[pousr]_[A-Za-z0-9]{30,}'
    'github-pat'        = 'github_pat_[A-Za-z0-9_]{20,}'
    'pgpassword'        = 'PGPASSWORD\s*='
    'aws-akid'          = '\bAKIA[0-9A-Z]{16}\b'
    'windows-user-path' = '[A-Za-z]:\\Users\\'
}
$secretAllow = @{ 'email' = @('contact@joshuatech.dev', 'e2e@joshuatech.dev') }
Test-Group 'rd-5' {
    $targets = [ordered]@{ 'runbook' = $runbook; 'test' = $self; 'readme' = $readme }
    foreach ($k in $targets.Keys) {
        $d = $targets[$k]
        if ($null -eq $d) { Assert "rd-5-secrets-${k}: no secret-shaped strings" $false "precondition failed: $k file missing"; continue }
        $hits = @()
        foreach ($pn in $secretPatterns.Keys) {
            $allow = if ($secretAllow.ContainsKey($pn)) { $secretAllow[$pn] } else { @() }
            $n = @([regex]::Matches($d.Text, $secretPatterns[$pn]) | Where-Object { $allow -cnotcontains $_.Value }).Count
            if ($n -gt 0) { $hits += "$pn x$n" }
        }
        Assert "rd-5-secrets-${k}: no secret-shaped strings" ($hits.Count -eq 0) "matches: $($hits -join ', ')"
    }
}

# ---------- rd-6: docs/README.md 색인 ----------
Test-Group 'rd-6' {
    if ($null -eq $readme) { Assert 'rd-6-index: docs/README.md links runbooks/restore-drill.md exactly once' $false "missing: $readmePath"; return }
    $n = [regex]::Matches($readme.Text, [regex]::Escape('](runbooks/restore-drill.md)')).Count
    Assert 'rd-6-index: docs/README.md links runbooks/restore-drill.md exactly once' ($n -eq 1) "occurrences = $n"
}

# ---------- rd-7: 상호 참조 ----------
Test-Group 'rd-7' {
    if ($null -eq $runbook) { Assert 'rd-7-xref: cross references on one line' $false $missingRunbook }
    else {
        $req = @(
            @('vault-unseal.md', '§7(?!\d)'),
            @('bootstrap.md', '§2(?!\d)'),
            @('bootstrap.md', '§7(?!\d)'),
            @('rollback.md', ''),
            @('platform-backup.sh', ''),
            @('backup-verify.ps1', '')
        )
        $miss = @()
        foreach ($r in $req) {
            $hit = @($runbook.Lines | Where-Object { $_.Contains($r[0]) -and ($r[1].Length -eq 0 -or $_ -cmatch $r[1]) })
            if ($hit.Count -eq 0) { $miss += $(if ($r[1].Length -gt 0) { "$($r[0]) + $($r[1] -replace '\(\?!\\d\)', '')" } else { $r[0] }) }
        }
        Assert 'rd-7-xref: cross references on one line' ($miss.Count -eq 0) "missing: $($miss -join ' | ')"
    }
    $vu = Read-Doc (Join-Path $repo 'docs/runbooks/vault-unseal.md')
    $bs = Read-Doc (Join-Path $repo 'docs/runbooks/bootstrap.md')
    $t = @()
    if ($null -eq $vu -or @($vu.Lines | Where-Object { $_ -cmatch '^## §7\s' }).Count -eq 0) { $t += "vault-unseal.md '## §7 '" }
    if ($null -eq $bs -or @($bs.Lines | Where-Object { $_ -cmatch '^## §2\s' }).Count -eq 0) { $t += "bootstrap.md '## §2 '" }
    if ($null -eq $bs -or @($bs.Lines | Where-Object { $_ -cmatch '^## §7\s' }).Count -eq 0) { $t += "bootstrap.md '## §7 '" }
    foreach ($f in 'infra/bootstrap/platform-backup.sh', 'scripts/backup-verify.ps1') {
        if (-not (Test-Path -LiteralPath (Join-Path $repo $f) -PathType Leaf)) { $t += $f }
    }
    Assert 'rd-7-targets: referenced sections and files exist' ($t.Count -eq 0) "missing: $($t -join ' | ')"
}

# ---------- rd-8: kubeconform(INFO · 도구가 있을 때만) ----------
function Invoke-Tool([string]$exe, [string[]]$argv, [int]$timeoutSec) {
    $psi = [Diagnostics.ProcessStartInfo]::new($exe)
    foreach ($a in $argv) { $psi.ArgumentList.Add($a) }
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($psi)
    $so = $p.StandardOutput.ReadToEndAsync(); $se = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($timeoutSec * 1000)) {
        try { $p.Kill($true) } catch { }
        return [pscustomobject]@{ TimedOut = $true; ExitCode = -1; Out = ''; Err = '' }
    }
    $p.WaitForExit()
    return [pscustomobject]@{ TimedOut = $false; ExitCode = $p.ExitCode; Out = $so.Result; Err = $se.Result }
}
Test-Group 'rd-8' {
    $kc = Join-Path $repo '.superpowers/bin/kubeconform.exe'
    $schemaDir = Join-Path $repo '.superpowers/t058/schemas'
    if (-not ((Test-Path -LiteralPath $kc -PathType Leaf) -and (Test-Path -LiteralPath $schemaDir -PathType Container))) {
        Write-Host 'INFO rd-8-kubeconform: skipped (tool or schemas absent)'
        return
    }
    if ($yamlDocs.Count -eq 0) { Assert 'rd-8-kubeconform: extracted yaml validates' $false 'no yaml documents extracted (see rd-4)'; return }
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('restore-drill-kc-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $tmp | Out-Null
        $n = 0
        foreach ($blk in $yamlBlocks) {
            $n++
            [IO.File]::WriteAllText((Join-Path $tmp ('block-{0:D2}.yaml' -f $n)), (($blk -join "`n") + "`n"), $utf8)
        }
        # 스키마 위치 순서: 로컬(CNPG 5종 + ObjectStore + batch/job_v1.json) 1순위 → 기본 위치(GitHub)는 로컬에 없는 종류의 폴백.
        # kubeconform 캐시(.superpowers/kc-cache — 받은 스키마)가 있으면 재사용한다 → 지금의 문서 4종은 네트워크 없이 검증된다.
        $loc = ($schemaDir -replace '\\', '/') + '/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
        $cache = Join-Path $repo '.superpowers/kc-cache'
        $files = @(Get-ChildItem -LiteralPath $tmp -Filter '*.yaml' | Sort-Object Name | ForEach-Object { $_.FullName })
        $kcArgs = @('-strict', '-summary', '-schema-location', $loc, '-schema-location', 'default')
        if (Test-Path -LiteralPath $cache -PathType Container) { $kcArgs += @('-cache', $cache) }
        $r = Invoke-Tool $kc ($kcArgs + $files) 180
        $all = ($r.Out + "`n" + $r.Err).Replace($tmp, '<tmp>')
        $m = [regex]::Match($all, 'Valid:\s*(\d+),\s*Invalid:\s*(\d+),\s*Errors:\s*(\d+),\s*Skipped:\s*(\d+)')
        if (-not $r.TimedOut -and $r.ExitCode -eq 0 -and $m.Success -and [int]$m.Groups[2].Value -eq 0 -and [int]$m.Groups[3].Value -eq 0 -and [int]$m.Groups[1].Value -eq $yamlDocs.Count) {
            Write-Host "INFO rd-8-kubeconform: Valid $($m.Groups[1].Value) (documents $($yamlDocs.Count), blocks $($yamlBlocks.Count))"
        } else {
            $detail = ($all -replace '\s+', ' ').Trim()
            if ($detail.Length -gt 600) { $detail = $detail.Substring(0, 600) + '…' }
            Assert 'rd-8-kubeconform: extracted yaml validates' $false "timedOut=$($r.TimedOut) exit=$($r.ExitCode) documents=$($yamlDocs.Count) -- $detail"
        }
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    if (Test-Path -LiteralPath $tmp) { Assert 'rd-8-kubeconform: temp directory removed' $false "left behind: $tmp" }
}

Write-Host "$script:pass passed, $script:fail failed"
exit ($script:fail -gt 0 ? 1 : 0)
