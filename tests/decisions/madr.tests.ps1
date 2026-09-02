# tests/decisions/madr.tests.ps1 — ADR 0002–0010 MADR 검사 스위트 (T016, test-first)
# Run: pwsh -NoProfile -File tests/decisions/madr.tests.ps1
# Exit 0 = all pass 또는 아래 SKIP, 1 = failures. 외부 프레임워크 없음(tests/hooks·tests/scripts 하네스와 같은 구조).
#
# SKIP 의미론(tests/run-all.ps1 1e 'adr-madr' 슬롯과의 계약 — T004 platform 러너의 첫 줄 SKIP 마커 패턴과 같은 방식):
#   - 대상 집합 docs/decisions/00{02..10}-*.md(9개 ID)가 "전부" 없을 때만
#     첫 줄 'SKIP madr tests -- ' + exit 0 으로 끝난다(T018–T026 작성 전).
#   - ID가 하나라도 있으면 9개 전부에 대해 전체 단언을 실행한다(부분 존재 = fail closed FAIL).
#   - ADR 0000·0001(SP-0, 형식이 다를 수 있음)은 검사 대상이 아니다.
#
# 검사 계약(.claude/rules/docs.md MADR 4.0 minimal — T018–T026 작성자가 따라야 하는 형태):
#   단언 수: readme 1 + ID당 7 × 9 = 64
#   -1 docs/decisions/<ID>-*.md 정확히 1개(번호 재사용 금지)
#   -2 frontmatter status: accepted        -3 frontmatter date: YYYY-MM-DD
#   -4 frontmatter decision-makers 비어 있지 않음(인라인 값 또는 바로 아래 '- ' 목록 항목)
#   -5 절 4개: 'Context and Problem Statement' / 'Considered Options' / 'Decision Outcome' /
#      'Consequences' — 제목 줄 레벨 2–3 허용(rules/docs.md는 Consequences를 ###로 둔다);
#      제목은 ATX(`#`)만 인정 — setext(밑줄 제목) 금지
#   -6 Considered Options 제목 아래(다음 제목 전까지) 열 0의 목록 항목('- '/'* ') >= 3
#   -7 docs/README.md가 '](decisions/<name>.md)' 링크를 1회 이상 포함('./' 접두·'#앵커' 허용)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$decDir = Join-Path $repo 'docs/decisions'
$readmePath = Join-Path $repo 'docs/README.md'
$ids = @(2..10 | ForEach-Object { $_.ToString('0000') })   # 0002..0010

# ---------- SKIP 게이트: 대상 ID가 전부 없을 때만(그 외 어떤 경우에도 SKIP하지 않는다) ----------
$idRx = '^(' + (@($ids | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')-'   # $ids가 단일 원천
$present = @()
if (Test-Path -LiteralPath $decDir -PathType Container) {
    $present = @(Get-ChildItem -LiteralPath $decDir -File -Filter '*.md' | Where-Object { $_.Name -cmatch $idRx })
}
if ($present.Count -eq 0) {
    Write-Host 'SKIP madr tests -- no docs/decisions/00{02..10}-*.md yet (written in T018-T026)'
    exit 0
}

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

$readme = if (Test-Path -LiteralPath $readmePath -PathType Leaf) { [IO.File]::ReadAllText($readmePath) } else { $null }
Assert 'readme-1: docs/README.md exists' ($null -ne $readme) "missing: $readmePath"

$sections = @('Context and Problem Statement', 'Considered Options', 'Decision Outcome', 'Consequences')

foreach ($id in $ids) {
    Test-Group "adr-$id" {
        $names = @{
            2 = "adr-$id-2: frontmatter status: accepted"
            3 = "adr-$id-3: frontmatter date: YYYY-MM-DD"
            4 = "adr-$id-4: frontmatter decision-makers non-empty"
            5 = "adr-$id-5: 4 MADR sections present (Context and Problem Statement / Considered Options / Decision Outcome / Consequences)"
            6 = "adr-$id-6: Considered Options lists >= 3 options"
            7 = "adr-$id-7: linked at least once from docs/README.md"
        }
        $files = @($present | Where-Object { $_.Name.StartsWith("$id-", [StringComparison]::Ordinal) })
        Assert "adr-$id-1: exactly one docs/decisions/$id-*.md" ($files.Count -eq 1) "count=$($files.Count) ($(if ($files.Count -eq 0) { 'written in T018-T026' } else { (@($files | ForEach-Object Name) -join ', ') }))"
        if ($files.Count -ne 1) {
            foreach ($k in 2..7) { Assert $names[$k] $false 'precondition failed (needs exactly one file)' }
            return
        }
        $f = $files[0]
        $raw = [IO.File]::ReadAllText($f.FullName)
        if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }   # 잔존 U+FEFF 방어
        $lines = $raw -split "\r?\n"

        # ---------- -2..-4: frontmatter ----------
        $fm = Get-FrontMatter $lines
        if ($null -eq $fm) {
            foreach ($k in 2..4) { Assert $names[$k] $false "no closed '---' frontmatter block at top of $($f.Name)" }
        } else {
            $status = @($fm | Where-Object { $_ -cmatch '^status:' })
            $sv = if ($status.Count -eq 1) { ($status[0].Substring('status:'.Length)).Trim() } else { '' }
            Assert $names[2] ($status.Count -eq 1 -and [string]::Equals($sv, 'accepted', [StringComparison]::Ordinal)) "status lines=$($status.Count), value='$sv'"

            $date = @($fm | Where-Object { $_ -cmatch '^date:' })
            Assert $names[3] ($date.Count -eq 1 -and $date[0] -cmatch '^date:\s*\d{4}-\d{2}-\d{2}\s*$') "date lines: [$($date -join ' | ')]"

            $dmOk = $false; $dmDetail = 'no decision-makers: key in frontmatter'
            for ($i = 0; $i -lt $fm.Count; $i++) {
                if ($fm[$i] -cmatch '^decision-makers:') {
                    $v = ($fm[$i].Substring('decision-makers:'.Length)).Trim()
                    if ($v.Length -gt 0) { $dmOk = $true }
                    elseif ($i + 1 -lt $fm.Count -and $fm[$i + 1] -cmatch '^\s*-\s*\S') { $dmOk = $true }
                    else { $dmDetail = 'decision-makers: has no inline value and no list item on the next line' }
                    break
                }
            }
            Assert $names[4] $dmOk $dmDetail
        }

        # ---------- -5: 절 4개 ----------
        $missing = @()
        foreach ($n in $sections) {
            $hit = @($lines | Where-Object { $_ -cmatch ('^#{2,3}\s+' + [regex]::Escape($n) + '\s*$') })
            if ($hit.Count -eq 0) { $missing += $n }
        }
        Assert $names[5] ($missing.Count -eq 0) "missing sections: $($missing -join ', ')"

        # ---------- -6: Considered Options 목록 항목 >= 3 ----------
        $optCount = 0; $inOpt = $false
        foreach ($l in $lines) {
            if ($l -cmatch '^#{2,3}\s+Considered Options\s*$') { $inOpt = $true; continue }
            if ($inOpt -and $l -cmatch '^#{1,6}\s') { break }
            if ($inOpt -and $l -cmatch '^[-*]\s+\S') { $optCount++ }
        }
        Assert $names[6] ($optCount -ge 3) "top-level list items under 'Considered Options' = $optCount (missing heading counts as 0)"

        # ---------- -7: docs/README.md 링크 ----------
        if ($null -eq $readme) {
            Assert $names[7] $false 'docs/README.md missing'
        } else {
            $rx = '\]\((\./)?decisions/' + [regex]::Escape($f.Name) + '(#[^)]*)?\)'
            Assert $names[7] ($readme -cmatch $rx) "no markdown link to decisions/$($f.Name) in docs/README.md"
        }
    }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
