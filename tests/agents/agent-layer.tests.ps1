# tests/agents/agent-layer.tests.ps1 — 에이전트 계층 검사 스위트 (T108, test-first)
# Run: pwsh -NoProfile -File tests/agents/agent-layer.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 프레임워크 없음(tests/decisions·tests/hooks 하네스와 같은 구조).
#
# fail closed: SKIP 없음 — 대상 파일이 없으면 그 파일의 단언 전부 FAIL이다
# (본체는 T109 rules 5·T110 builder 3·T112 kr 미러에서 작성; 그 전까지 이 스위트는 RED가 정상).
# 기존 .claude/rules/{specs,docs,content}.md는 검사 대상이 아니다.
#
# 검사 계약 — 단언 수: rules 4×5 + agents 6×3 + boundary 7 + mirrors 3×9 = 72
#   RULES  .claude/rules/{web,django-pod,fastapi-pod,infra,events}.md
#     -1 파일 존재  -2 닫힌 '---' frontmatter 블록
#     -3 최상위 paths: 키 1개 + 비어 있지 않은 glob 항목 >= 1(블록 목록 또는 인라인 flow 시퀀스)
#     -4 모든 glob이 저장소 상대 패턴으로 타당: 출력 가능 ASCII(공백 없음)·백슬래시 없음·
#        절대 경로 아님(선행 '/'·드라이브 문자 금지)·'..' 세그먼트 없음
#   AGENTS .claude/agents/{web,api,infra}-builder.md
#     -1 파일 존재  -2 frontmatter 블록  -3 name 비어 있지 않음  -4 description 비어 있지 않음
#     -5 tools 비어 있지 않음(인라인 값 또는 바로 아래 '- ' 목록 항목)  -6 skills 키 존재
#   BOUNDARY
#     -1 .claude/skills/approval-review/boundaries/k8s-security.md 존재 + 내용 비어 있지 않음
#     -2..-7 approval-review/SKILL.md가 경계 파일 6개 이름을 모두 언급
#        (security.md는 k8s-security.md의 부분 문자열이므로 앞 문자를 lookbehind로 배제)
#   MIRRORS docs/kr/rules/{web,django-pod,fastapi-pod,infra,events}_kr.md ·
#           docs/kr/agents/{web-builder,api-builder,infra-builder}_kr.md ·
#           docs/kr/skills/approval-review_kr.md (.claude/rules/docs.md 미러 규약)
#     -1 파일 존재
#     -2 첫 줄이 '> ' 노트: 정본 표시 노트('번역본'/'정본') 또는 '> translation-pending (YYYY-MM-DD)'
#     -3 열 0의 ATX H1 제목('# ') 존재
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

$script:pass = 0
$script:fail = 0

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 단언 그룹 격리 — 한 그룹의 예외가 나머지를 막지 않는다.
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

# UTF-8 읽기 + 잔존 U+FEFF 방어(비교는 전부 Ordinal).
function Read-Text([string]$path) {
    $raw = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }
    return $raw
}

# frontmatter: 첫 줄 '---'부터 닫는 '---' 전까지의 줄 배열. 형식이 어긋나면 $null(fail closed 단언용).
function Get-FrontMatter([string[]]$lines) {
    if ($lines.Count -lt 3 -or -not [string]::Equals($lines[0].Trim(), '---', [StringComparison]::Ordinal)) { return $null }
    $out = @()
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ([string]::Equals($lines[$i].Trim(), '---', [StringComparison]::Ordinal)) { return , $out }
        $out += $lines[$i]
    }
    return $null   # 닫는 '---' 없음
}

# 양끝의 같은 종류 따옴표 한 겹 제거.
function Remove-Quote([string]$s) {
    if ($s.Length -ge 2) {
        $q = $s[0]
        if (($q -eq [char]0x22 -or $q -eq [char]0x27) -and $s[$s.Length - 1] -eq $q) { return $s.Substring(1, $s.Length - 2) }
    }
    return $s
}

# 최상위 'paths:' 키의 glob 항목들. 키가 없거나 중복이면 $null; 키만 있고 항목이 없으면 빈 배열.
function Get-PathEntries([string[]]$fm) {
    $hits = @()
    for ($i = 0; $i -lt $fm.Count; $i++) { if ($fm[$i] -cmatch '^paths:') { $hits += $i } }
    if ($hits.Count -ne 1) { return $null }
    $entries = @()
    $inline = ($fm[$hits[0]].Substring('paths:'.Length)).Trim()
    if ($inline.Length -gt 0) {
        if ($inline.StartsWith('[', [StringComparison]::Ordinal) -and $inline.EndsWith(']', [StringComparison]::Ordinal)) {
            foreach ($p in ($inline.Substring(1, $inline.Length - 2) -split ',')) {
                $t = $p.Trim(); if ($t.Length -gt 0) { $entries += (Remove-Quote $t) }
            }
        } else { $entries += (Remove-Quote $inline) }
    } else {
        for ($j = $hits[0] + 1; $j -lt $fm.Count; $j++) {
            if ($fm[$j] -cmatch '^\s+-\s*(.*)$') { $entries += (Remove-Quote ($Matches[1].Trim())) }
            elseif ($fm[$j] -cmatch '^\s*$') { continue }
            else { break }   # 다음 최상위 키 또는 목록이 아닌 들여쓴 줄
        }
    }
    return , $entries
}

# 저장소 상대 glob 타당성(계약 -4).
function Test-GlobPlausible([string]$g) {
    if ([string]::IsNullOrWhiteSpace($g)) { return $false }
    if ($g -cnotmatch '^[\x21-\x7E]+$') { return $false }        # 출력 가능 ASCII만, 공백·비ASCII 금지
    if ($g.Contains('\')) { return $false }                       # 백슬래시 금지
    if ($g.StartsWith('/', [StringComparison]::Ordinal)) { return $false }
    if ($g -cmatch '^[A-Za-z]:') { return $false }                # 드라이브 문자 절대 경로 금지
    if ($g -cmatch '(^|/)\.\.(/|$)') { return $false }            # '..' 세그먼트 금지
    return $true
}

# 최상위 '<key>:' 값 검사. 반환: Present / NonEmpty(인라인 값 또는 바로 아래 '- ' 목록 항목) / Detail.
function Get-KeyValue([string[]]$fm, [string]$key) {
    $hits = @()
    $rx = '^' + [regex]::Escape($key) + ':'
    for ($i = 0; $i -lt $fm.Count; $i++) { if ($fm[$i] -cmatch $rx) { $hits += $i } }
    if ($hits.Count -eq 0) { return @{ Present = $false; NonEmpty = $false; Detail = "no top-level '${key}:' key in frontmatter" } }
    if ($hits.Count -gt 1) { return @{ Present = $false; NonEmpty = $false; Detail = "'${key}:' appears $($hits.Count) times" } }
    $i = $hits[0]
    $v = ($fm[$i].Substring(($key + ':').Length)).Trim()
    if ($v.Length -gt 0) { return @{ Present = $true; NonEmpty = $true; Detail = '' } }
    if ($i + 1 -lt $fm.Count -and $fm[$i + 1] -cmatch '^\s*-\s*\S') { return @{ Present = $true; NonEmpty = $true; Detail = '' } }
    return @{ Present = $true; NonEmpty = $false; Detail = "'${key}:' has no inline value and no list item on the next line" }
}

# ---------- RULES: .claude/rules/{web,django-pod,fastapi-pod,infra,events}.md ----------
foreach ($r in @('web', 'django-pod', 'fastapi-pod', 'infra', 'events')) {
    Test-Group "rule-$r" {
        $rel = ".claude/rules/$r.md"
        $path = Join-Path $repo $rel
        $names = @{
            2 = "rule-$r-2: closed '---' frontmatter block"
            3 = "rule-$r-3: frontmatter paths: with >= 1 non-empty glob"
            4 = "rule-$r-4: every paths glob is a plausible repo-relative pattern"
        }
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        Assert "rule-$r-1: $rel exists" $exists "missing: $rel (written in T109)"
        if (-not $exists) {
            foreach ($k in 2..4) { Assert $names[$k] $false 'precondition failed (file missing)' }
            return
        }
        $lines = (Read-Text $path) -split "\r?\n"
        $fm = Get-FrontMatter $lines
        Assert $names[2] ($null -ne $fm) "no closed '---' frontmatter block at top of $rel"
        if ($null -eq $fm) {
            foreach ($k in 3..4) { Assert $names[$k] $false 'precondition failed (no frontmatter)' }
            return
        }
        $globs = Get-PathEntries $fm
        if ($null -eq $globs) {
            Assert $names[3] $false "top-level 'paths:' key missing or duplicated in $rel"
            Assert $names[4] $false 'precondition failed (no paths: key)'
            return
        }
        $empty = @($globs | Where-Object { $_.Length -eq 0 })
        Assert $names[3] ($globs.Count -ge 1 -and $empty.Count -eq 0) "entries=$($globs.Count), empty entries=$($empty.Count)"
        if ($globs.Count -eq 0) {
            Assert $names[4] $false 'precondition failed (no glob entries)'
        } else {
            $bad = @($globs | Where-Object { -not (Test-GlobPlausible $_) })
            Assert $names[4] ($bad.Count -eq 0) "implausible globs: $($bad -join ', ')"
        }
    }
}

# ---------- AGENTS: .claude/agents/{web,api,infra}-builder.md ----------
foreach ($a in @('web-builder', 'api-builder', 'infra-builder')) {
    Test-Group "agent-$a" {
        $rel = ".claude/agents/$a.md"
        $path = Join-Path $repo $rel
        $names = @{
            2 = "agent-$a-2: closed '---' frontmatter block"
            3 = "agent-$a-3: frontmatter name non-empty"
            4 = "agent-$a-4: frontmatter description non-empty"
            5 = "agent-$a-5: frontmatter tools non-empty"
            6 = "agent-$a-6: frontmatter skills key present"
        }
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        Assert "agent-$a-1: $rel exists" $exists "missing: $rel (written in T110)"
        if (-not $exists) {
            foreach ($k in 2..6) { Assert $names[$k] $false 'precondition failed (file missing)' }
            return
        }
        $lines = (Read-Text $path) -split "\r?\n"
        $fm = Get-FrontMatter $lines
        Assert $names[2] ($null -ne $fm) "no closed '---' frontmatter block at top of $rel"
        if ($null -eq $fm) {
            foreach ($k in 3..6) { Assert $names[$k] $false 'precondition failed (no frontmatter)' }
            return
        }
        foreach ($pair in @(@(3, 'name'), @(4, 'description'), @(5, 'tools'))) {
            $kv = Get-KeyValue $fm $pair[1]
            Assert $names[$pair[0]] $kv.NonEmpty $kv.Detail
        }
        $kv = Get-KeyValue $fm 'skills'
        Assert $names[6] $kv.Present $kv.Detail
    }
}

# ---------- BOUNDARY: k8s-security.md + approval-review/SKILL.md의 경계 6개 나열 ----------
Test-Group 'boundary' {
    $kbRel = '.claude/skills/approval-review/boundaries/k8s-security.md'
    $kbPath = Join-Path $repo $kbRel
    $kbOk = $false; $kbDetail = "missing: $kbRel"
    if (Test-Path -LiteralPath $kbPath -PathType Leaf) {
        if ((Read-Text $kbPath).Trim().Length -gt 0) { $kbOk = $true } else { $kbDetail = "empty file: $kbRel" }
    }
    Assert "boundary-1: $kbRel exists and is non-empty" $kbOk $kbDetail

    $spRel = '.claude/skills/approval-review/SKILL.md'
    $spPath = Join-Path $repo $spRel
    $skill = if (Test-Path -LiteralPath $spPath -PathType Leaf) { Read-Text $spPath } else { $null }
    $i = 2
    foreach ($b in @('security.md', 'tenant-data.md', 'operability.md', 'trends.md', 'spec-consistency.md', 'k8s-security.md')) {
        $name = "boundary-${i}: SKILL.md names $b"
        if ($null -eq $skill) {
            Assert $name $false "missing: $spRel"
        } else {
            # 이름 앞에 단어 문자·하이픈이 붙은 매치는 배제(security.md ⊄ k8s-security.md).
            $rx = '(?<![A-Za-z0-9_-])' + [regex]::Escape($b)
            Assert $name ([regex]::IsMatch($skill, $rx)) "no mention of '$b' in $spRel"
        }
        $i++
    }
}

# ---------- MIRRORS: docs/kr/ 미러 9개 ----------
$mirrors = @(
    @{ Id = 'rules-web';               Rel = 'docs/kr/rules/web_kr.md';                 Task = 'T112' }
    @{ Id = 'rules-django-pod';        Rel = 'docs/kr/rules/django-pod_kr.md';          Task = 'T112' }
    @{ Id = 'rules-fastapi-pod';       Rel = 'docs/kr/rules/fastapi-pod_kr.md';         Task = 'T112' }
    @{ Id = 'rules-infra';             Rel = 'docs/kr/rules/infra_kr.md';               Task = 'T112' }
    @{ Id = 'rules-events';            Rel = 'docs/kr/rules/events_kr.md';              Task = 'T112' }
    @{ Id = 'agents-web-builder';      Rel = 'docs/kr/agents/web-builder_kr.md';        Task = 'T112' }
    @{ Id = 'agents-api-builder';      Rel = 'docs/kr/agents/api-builder_kr.md';        Task = 'T112' }
    @{ Id = 'agents-infra-builder';    Rel = 'docs/kr/agents/infra-builder_kr.md';      Task = 'T112' }
    @{ Id = 'skills-approval-review';  Rel = 'docs/kr/skills/approval-review_kr.md';    Task = 'T112' }
)
foreach ($m in $mirrors) {
    Test-Group "mirror-$($m.Id)" {
        $path = Join-Path $repo $m.Rel
        $names = @{
            2 = "mirror-$($m.Id)-2: first line is a canonical-language note or translation-pending"
            3 = "mirror-$($m.Id)-3: ATX H1 heading present"
        }
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        Assert "mirror-$($m.Id)-1: $($m.Rel) exists" $exists "missing: $($m.Rel) (written in $($m.Task))"
        if (-not $exists) {
            foreach ($k in 2..3) { Assert $names[$k] $false 'precondition failed (file missing)' }
            return
        }
        $lines = (Read-Text $path) -split "\r?\n"
        $first = if ($lines.Count -gt 0) { $lines[0] } else { '' }
        $noteOk = $false
        if ($first -cmatch '^>\s*\S') {
            if ($first -cmatch 'translation-pending \(\d{4}-\d{2}-\d{2}\)') { $noteOk = $true }
            elseif ($first.Contains('번역본') -or $first.Contains('정본')) { $noteOk = $true }
        }
        Assert $names[2] $noteOk "first line: '$first'"
        $h1 = @($lines | Where-Object { $_ -cmatch '^#\s+\S' })
        Assert $names[3] ($h1.Count -ge 1) "no column-0 '# ' heading in $($m.Rel)"
    }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
