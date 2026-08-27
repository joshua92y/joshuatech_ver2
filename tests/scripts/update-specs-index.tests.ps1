# scripts/update-specs-index.ps1 테스트. Run: pwsh -NoProfile -File tests/scripts/update-specs-index.tests.ps1
# Exit 0 = all pass, 1 = failures. 외부 테스트 프레임워크 없음(tests/hooks/run-hook-tests.ps1와 같은 구조).
# 픽스처는 임시 디렉터리(specidx-<guid>)에 만들고 끝나면 지운다. 계약: specs/002-smoke/contracts/cli.md
# 단언은 Test-Group으로 묶는다: 한 그룹에서 예외가 나도(파일 없음 등) 나머지 그룹은 계속 실행된다.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$scriptPath = Join-Path $repo 'scripts/update-specs-index.ps1'
$script:pass = 0
$script:fail = 0
$script:fixtures = @()
$script:runs = 0                                   # 자식 프로세스(pwsh) 실행 횟수 — 보고용
$harnessWatch = [Diagnostics.Stopwatch]::StartNew()

function Assert([string]$name, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS $name" }
    else { $script:fail++; Write-Host "FAIL $name -- $detail" }
}

# 단언 그룹 격리. 본문은 이 함수 스코프에 dot-source되므로 그룹 안에서 만든 변수는 그룹 밖으로 새지 않는다(공유는 $script: 로).
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

function Format-Result($r) { "out=[$($r.out)] err=[$($r.err)] [code=$($r.code)]" }

# 키 = 픽스처 루트 기준 상대 경로, 값 = 문자열(UTF-8, BOM 없음) 또는 [byte[]](원본 바이트 그대로)
function New-Fixture([hashtable]$files = @{}) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('specidx-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    $script:fixtures += $dir
    foreach ($rel in $files.Keys) {
        $p = Join-Path $dir $rel
        New-Item -ItemType Directory -Path (Split-Path $p -Parent) -Force | Out-Null
        if ($files[$rel] -is [byte[]]) { [IO.File]::WriteAllBytes($p, $files[$rel]) }
        elseif ($files[$rel] -is [string]) { [IO.File]::WriteAllText($p, [string]$files[$rel], [Text.UTF8Encoding]::new($false)) }
        else { throw "New-Fixture: value for '$rel' must be [string] or [byte[]]" }
    }
    return $dir
}

function Remove-Fixture {
    foreach ($f in $script:fixtures) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
    $script:fixtures = @()
}

# 스크립트를 실행해 stdout·stderr를 따로 캡처한다. 스크립트 파일이 없으면 code=127.
#   $root  -Root 값. 비어 있으면 -Root 없이 실행한다(기본값 = 스크립트 상위 디렉터리, FR-014).
#   $file  실행할 스크립트 경로(기본값 저장소의 scripts/update-specs-index.ps1). 픽스처에 복사한 사본을 지정할 수 있다.
#   $cwd   실행 중 작업 디렉터리. 비어 있으면 현재 위치 그대로.
# out/err는 줄을 LF로 잇고 끝 개행을 뗀 문자열. ms = 경과 밀리초(SC-005).
function Invoke-Script([string]$root, [string]$file = $scriptPath, [string]$cwd) {
    if (-not (Test-Path -LiteralPath $file)) { return @{ out = "<missing: $file>"; err = ''; code = 127; ms = 0 } }
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('specidx-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $file)
    if ($root) { $argv += @('-Root', $root) }
    if ($cwd) { Push-Location -LiteralPath $cwd }
    $script:runs++
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $out = & ([Environment]::ProcessPath) @argv 2> $errFile
        $code = $LASTEXITCODE
        $sw.Stop()
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile) } else { '' }
    } finally {
        if ($cwd) { Pop-Location }
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    }
    return @{
        out  = (@($out | ForEach-Object { "$_" }) -join "`n")
        err  = (($err -replace "`r`n", "`n").TrimEnd("`n"))
        code = $code
        ms   = $sw.ElapsedMilliseconds
    }
}

# 파일이 없으면 $null (README 미생성 단언을 예외 없이 쓰기 위해)
function Read-Text([string]$path) { if (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::ReadAllText($path) } else { $null } }
function Get-Stamp([string]$path) { (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks }

# 내용 비교는 ordinal로만 한다(-ceq는 문화권 비교라 무시 가능 문자를 건너뛴다).
function Test-Same([string]$a, [string]$b) { [string]::Equals($a, $b, [StringComparison]::Ordinal) }

# 파일 바이트의 BOM·CR 유무. 파일이 없으면 exists=$false(예외 없음).
function Get-ByteFacts([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @{ exists = $false; bytes = [byte[]]@(); bom = $false; cr = $false } }
    $b = [IO.File]::ReadAllBytes($path)
    return @{
        exists = $true
        bytes  = $b
        bom    = ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF)
        cr     = ([Array]::IndexOf($b, [byte]13) -ge 0)
    }
}

# stderr 줄 배열(빈 stderr → 빈 배열)
function Get-ErrLines($r) { if ([string]::IsNullOrEmpty($r.err)) { return , [string[]]@() } else { return , [string[]]($r.err -split "`n") } }

# 줄 배열에 정확히(ordinal) 같은 줄이 있는지
function Test-HasLine([string[]]$lines, [string]$line) { foreach ($l in $lines) { if (Test-Same $l $line) { return $true } }; return $false }

# README 불변 검사용 스냅샷(내용 + LastWriteTime)
function Get-Snapshot([string]$path) { @{ text = (Read-Text $path); stamp = (Get-Stamp $path) } }
function Test-Snapshot([string]$path, $snap) { (Test-Same ([string](Read-Text $path)) ([string]$snap.text)) -and (Get-Stamp $path) -eq $snap.stamp }

# README 본문에서 `| <number> | …` 행을 찾아 셀 배열(번호·제목·Status·우선순위·링크)을 돌려준다. 없으면 빈 배열.
#   $nth  같은 번호의 행이 여러 개일 때 몇 번째(0부터) 행을 돌려줄지
function Get-IndexRow([string]$readmeText, [string]$number, [int]$nth = 0) {
    $seen = 0
    foreach ($line in ($readmeText -split "`n")) {
        if ($line.StartsWith("| $number | ", [StringComparison]::Ordinal) -and $line.EndsWith(' |', [StringComparison]::Ordinal)) {
            if ($seen -eq $nth) { return , [string[]]($line.Substring(2, $line.Length - 4) -split ' \| ') }
            $seen++
        }
    }
    return , [string[]]@()
}

$utf8 = [Text.UTF8Encoding]::new($false)
$bomBytes = [byte[]](0xEF, 0xBB, 0xBF)
$tableHeader = '| # | Feature | Status | 우선순위 | 링크 |'
$tableSep = '|---|---|---|---|---|'
# FR-011 기본 머리말(README 없을 때). 계약 문구 그대로.
$defaultPreamble = "# Feature 인덱스`n`n" + '각 feature의 `spec.md` 헤더에서 `scripts/update-specs-index.ps1`로 재생성한다. 디렉터리는 이동·삭제하지 않는다(불변 이력). 상태: Draft → Approved → Done.' + "`n`n"

# ---------- US1 기본 픽스처 ----------
# README = 머리말 2문단 + 기존 표(내용은 틀림: 교체되어야 함) + 후행 문단
$us1Pre = "# Feature 인덱스`n`n둘째 머리말 문단. 이 줄은 그대로 남아야 한다.`n`n"
$us1OldTable = "| # | Feature | Status | 우선순위 | 링크 |`n|---|---|---|---|---|`n| 999 | stale | Draft | — | x |`n"
$us1Post = "`n> 후행 텍스트`n"
$us1Files = @{
    'specs/README.md'        = $us1Pre + $us1OldTable + $us1Post
    'specs/001-alpha/spec.md' = "# Feature Specification: 알파 (SP-0)`n**Status**: Approved (2026-08-26)`n**Priority**: 🔴`n"
    'specs/001-alpha/plan.md' = "# Implementation Plan: 알파`n"
    'specs/002-beta/spec.md'  = "# Feature Specification: 베타`n`n**Status**: Draft`n"
}
$us1Table = @(
    $tableHeader
    $tableSep
    '| 001 | 알파 (SP-0) | Approved (2026-08-26) | 🔴 | [spec](001-alpha/spec.md) · [plan](001-alpha/plan.md) |'
    '| 002 | 베타 | Draft | — | [spec](002-beta/spec.md) |'
)
$us1Inputs = @('specs/001-alpha/spec.md', 'specs/001-alpha/plan.md', 'specs/002-beta/spec.md')
# US1 spec만(README 없음) — Edge 그룹에서 README 변형을 얹어 쓴다
$us1Specs = $us1Files.Clone(); $us1Specs.Remove('specs/README.md')

# 표 4줄이 이 순서로 연속해서 나오는지
function Test-TableLines([string[]]$lines, [string[]]$expected) {
    $i = [Array]::IndexOf($lines, $expected[0])
    if ($i -lt 0 -or $i + $expected.Count -gt $lines.Count) { return $false }
    for ($k = 0; $k -lt $expected.Count; $k++) { if (-not (Test-Same $lines[$i + $k] $expected[$k])) { return $false } }
    return $true
}

# ---------- US2 픽스처: Status 정규화 (FR-003, research R7) — README 없음(FR-011 기본 머리말) ----------
$us2Files = @{
    'specs/010-a/spec.md' = "# Feature Specification: a`n**Status**: Approved (2026-08-26, 외부 리뷰 반영판)`n"
    'specs/011-b/spec.md' = "# Feature Specification: b`n**Status**: Done (2026-08-27)`n"
    'specs/012-c/spec.md' = "# Feature Specification: c`n**Status**: Draft`n"
    'specs/013-d/spec.md' = "# Feature Specification: d`n**Status**: Approved (2026-08-26, 주석) (extra)`n"
    'specs/014-e/spec.md' = "# Feature Specification: e`n**Status**: Approved (2026-08-26,주석)`n"
    'specs/015-f/spec.md' = "# Feature Specification: f`n**Status**: Approved (2026-08-26) (note, x)`n"          # 첫 괄호에 쉼표 없음 → 원문 그대로 (T017)
    'specs/016-g/spec.md' = "# Feature Specification: g`n**Status**: Approved (2026-08-26, 주석) (extra, y)`n"    # 첫 괄호만 정규화, 뒤 괄호는 그대로 (T017)
}

# ---------- US3 픽스처 A: 누락값·무시 항목·경고·같은 번호·이스케이프·BOM/CRLF·CR·중복 줄 — README 없음(FR-011) ----------
# 한 번 실행으로 T010 (1)(2)(3)(7)(8)(9)(10a)(12)와 리뷰 추가분 Edge-14·15·17을 모두 검사한다(T010 번호는 (1)–(16); Edge-13~17은 리뷰 추가).
# 표에 오르는 feature = 11개(020-empty는 경고 후 건너뜀).
$us3Files = @{
    'specs/notes/index.md'    = "# notes`n"                                                  # 비-NNN 디렉터리: 조용히 무시
    'specs/zz-x/spec.md'      = "# Feature Specification: zz`n**Status**: Draft`n"           # 비-NNN 디렉터리: 조용히 무시
    'specs/020-empty/plan.md' = "# plan only`n"                                              # spec.md 없음 → warning + skip
    'specs/001-p/spec.md'     = "# Feature Specification: 우선순위 있음`n**Status**: Draft`n**Priority**: 🔴`n"
    'specs/001-p/plan.md'     = "# plan`n"
    'specs/002-np/spec.md'    = "# Feature Specification: 우선순위 없음`n**Status**: Draft`n"   # Priority 줄 없음, plan.md 없음
    'specs/040-a-b/spec.md'   = "# Feature Specification: a-b`n**Status**: Draft`n"
    'specs/040-ab/spec.md'    = "# Feature Specification: ab`n**Status**: Draft`n"
    'specs/041-pipe/spec.md'  = "# A | B`n**Status**: Draft`n"
    'specs/042-esc/spec.md'   = "# A \| B`n**Status**: Draft`n"
    'specs/043-plain/spec.md' = "# 그냥 제목`n**Status**: Draft`n"
    'specs/044-bom/spec.md'   = [byte[]]($bomBytes + $utf8.GetBytes("# Feature Specification: 우선순위 있음`r`n**Status**: Draft`r`n**Priority**: 🔴`r`n"))
    'specs/045-wsp/spec.md'   = "# Feature Specification: 공백 우선순위`n**Status**: Draft`n**Priority**:   `n"
    'specs/046-cr/spec.md'    = [byte[]]$utf8.GetBytes("# A`rB`n**Status**: Draft`n")
    'specs/050-dup/spec.md'   = "# Feature Specification: 중복`n**Status**: Draft`n**Status**: Done (2026-01-01)`n**Priority**: 🔴`n**Priority**: 🟢`n"
}

# ---------- US3 픽스처 E: H1/Status 누락 오류(FR-009) — README 있음(불변이어야 함) ----------
$us3ErrFiles = @{
    'specs/README.md'         = $us1Pre + $us1OldTable + $us1Post
    'specs/001-alpha/spec.md' = $us1Files['specs/001-alpha/spec.md']
    'specs/030-bad/spec.md'   = "# Feature Specification: bad`n**Priority**: 🔴`n"     # Status 줄 없음
    'specs/031-noh1/spec.md'  = "**Status**: Draft`n"                                   # H1 없음
    'specs/070-ws/spec.md'    = "# Feature Specification: ws`n**Status**:   `n"        # 공백뿐인 Status → 누락 취급 (Edge-13, 리뷰 추가)
}

# ---------- Edge 픽스처: 100 feature(SC-005) ----------
$perfFiles = @{}
for ($i = 100; $i -lt 200; $i++) { $perfFiles["specs/${i}-f${i}/spec.md"] = "# Feature Specification: f${i}`n**Status**: Draft`n" }

try {
    # ---------- specs/ 없음 (FR-015, Edge Cases) ----------
    Test-Group 'root: specs/ missing' {
        $d = New-Fixture @{}
        $r = Invoke-Script $d
        Assert 'root: specs/ missing -> exit 1, stderr starts with "error: specs directory not found"' ($r.code -eq 1 -and ([string]$r.err).StartsWith('error: specs directory not found', [StringComparison]::Ordinal)) (Format-Result $r)
    }

    # ---------- US1: 표 생성·머리말 보존·멱등·LF/BOM·입력 불변 ----------
    Test-Group 'US1' {
        $repoReadme = Join-Path $repo 'specs/README.md'
        $repoStampBefore = Get-Stamp $repoReadme
        $d = New-Fixture $us1Files
        $readme = Join-Path $d 'specs/README.md'
        $inputBefore = @{}
        foreach ($rel in $us1Inputs) { $p = Join-Path $d $rel; $inputBefore[$rel] = @{ text = (Read-Text $p); stamp = (Get-Stamp $p) } }

        $r = Invoke-Script $d
        $after = Read-Text $readme
        $lines = $after -split "`n"
        $headerCount = @($lines | Where-Object { $_ -cmatch '^\| # \|' }).Count
        Assert 'US1-1: two features -> exit 0, "2 features indexed", table rows in order, single header (FR-005/006)' (
            $r.code -eq 0 -and (Test-Same $r.out 'specs/README.md: 2 features indexed') -and (Test-TableLines $lines $us1Table) -and $headerCount -eq 1
        ) ((Format-Result $r) + " headers=$headerCount readme=[$after]")
        Assert 'US1-2: preamble before and trailer after the table preserved verbatim (FR-007)' (
            $r.code -eq 0 -and $after.StartsWith($us1Pre, [StringComparison]::Ordinal) -and $after.EndsWith($us1Post, [StringComparison]::Ordinal)
        ) "readme=[$after]"
        $bytes = [IO.File]::ReadAllBytes($readme)
        $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
        $hasCr = [Array]::IndexOf($bytes, [byte]13) -ge 0
        Assert 'US1-5: output is UTF-8 without BOM and has no CR (FR-012)' ($r.code -eq 0 -and -not $hasBom -and -not $hasCr) "code=$($r.code) bom=$hasBom cr=$hasCr"

        $text1 = $after
        $stamp1 = Get-Stamp $readme
        $r2 = Invoke-Script $d
        $text2 = Read-Text $readme
        $stamp2 = Get-Stamp $readme
        Assert 'US1-3: second run -> "(unchanged)", content and LastWriteTime untouched (FR-008)' (
            $r2.code -eq 0 -and (Test-Same $r2.out 'specs/README.md: 2 features indexed (unchanged)') -and (Test-Same $text2 $text1) -and $stamp2 -eq $stamp1
        ) ((Format-Result $r2) + " stamp1=$stamp1 stamp2=$stamp2 same=$(Test-Same $text2 $text1)")

        $inputsIntact = $true
        foreach ($rel in $us1Inputs) {
            $p = Join-Path $d $rel
            if (-not (Test-Same (Read-Text $p) $inputBefore[$rel].text) -or (Get-Stamp $p) -ne $inputBefore[$rel].stamp) { $inputsIntact = $false }
        }
        $repoStampAfter = Get-Stamp $repoReadme
        Assert 'US1-6: spec.md/plan.md inputs and the real specs/README.md untouched (read-only inputs, isolation)' (
            $r.code -eq 0 -and $r2.code -eq 0 -and $inputsIntact -and $repoStampAfter -eq $repoStampBefore
        ) "codes=$($r.code)/$($r2.code) inputsIntact=$inputsIntact repoStamp=$repoStampBefore/$repoStampAfter"
    }

    # ---------- US1-4: cwd 무관 — 픽스처의 scripts/ 사본을 -Root 없이 다른 cwd에서 실행 (FR-014) ----------
    Test-Group 'US1-4' {
        $d = New-Fixture $us1Files
        New-Item -ItemType Directory -Path (Join-Path $d 'scripts') | Out-Null
        $copy = Join-Path $d 'scripts/update-specs-index.ps1'
        Copy-Item -LiteralPath $scriptPath -Destination $copy
        $tempRoot = [IO.Path]::GetTempPath()
        $strayReadme = Join-Path $tempRoot 'specs/README.md'
        $r = Invoke-Script '' $copy $tempRoot
        $after = Read-Text (Join-Path $d 'specs/README.md')
        Assert 'US1-4: no -Root from another cwd -> resolves root from script location, no README under cwd (FR-014)' (
            $r.code -eq 0 -and (Test-TableLines ($after -split "`n") $us1Table) -and -not (Test-Path -LiteralPath $strayReadme)
        ) ((Format-Result $r) + " stray=$(Test-Path -LiteralPath $strayReadme) readme=[$after]")
    }

    # ---------- US1-7: BOM만 있는 LF README(표는 이미 올바름) -> 1회 재기록(BOM 제거), 그 뒤 (unchanged) (FR-012) ----------
    Test-Group 'US1-7' {
        $expected = $us1Pre + ($us1Table -join "`n") + "`n" + $us1Post
        $expectedBytes = $utf8.GetBytes($expected)
        $bomFiles = $us1Files.Clone()
        $bomFiles['specs/README.md'] = [byte[]]($bomBytes + $expectedBytes)
        $d = New-Fixture $bomFiles
        $readme = Join-Path $d 'specs/README.md'
        $r = Invoke-Script $d
        $f = Get-ByteFacts $readme
        $sameBytes = [Linq.Enumerable]::SequenceEqual([byte[]]$f.bytes, [byte[]]$expectedBytes)
        $r2 = Invoke-Script $d
        Assert 'US1-7: BOM-only LF README with correct table -> rewritten once without BOM, then "(unchanged)" (FR-012)' (
            $r.code -eq 0 -and (Test-Same $r.out 'specs/README.md: 2 features indexed') -and -not $f.bom -and -not $f.cr -and $sameBytes -and
            $r2.code -eq 0 -and (Test-Same $r2.out 'specs/README.md: 2 features indexed (unchanged)')
        ) ((Format-Result $r) + ' / ' + (Format-Result $r2) + " bom=$($f.bom) cr=$($f.cr) sameBytes=$sameBytes")
    }

    # ---------- US2: Status 셀 정규화 — 첫 괄호 그룹의 첫 쉼표 이후만 제거 (FR-003, research R7) ----------
    Test-Group 'US2' {
        $d = New-Fixture $us2Files
        $r = Invoke-Script $d
        $after = Read-Text (Join-Path $d 'specs/README.md')
        $cells = Get-IndexRow $after '010'
        Assert 'US2-1: "Approved (2026-08-26, 외부 리뷰 반영판)" -> "Approved (2026-08-26)" (FR-003)' (
            $r.code -eq 0 -and $cells.Count -eq 5 -and (Test-Same $cells[2] 'Approved (2026-08-26)')
        ) ((Format-Result $r) + " cells=[$($cells -join ' / ')]")
        $cells = Get-IndexRow $after '011'
        Assert 'US2-2: "Done (2026-08-27)" (no comma) -> unchanged (FR-003)' (
            $r.code -eq 0 -and $cells.Count -eq 5 -and (Test-Same $cells[2] 'Done (2026-08-27)')
        ) ((Format-Result $r) + " cells=[$($cells -join ' / ')]")
        $cells = Get-IndexRow $after '012'
        Assert 'US2-3: "Draft" (no parenthesis) -> unchanged (FR-003)' (
            $r.code -eq 0 -and $cells.Count -eq 5 -and (Test-Same $cells[2] 'Draft')
        ) ((Format-Result $r) + " cells=[$($cells -join ' / ')]")
        $cells = Get-IndexRow $after '013'
        Assert 'US2-4: "Approved (2026-08-26, 주석) (extra)" -> only the first group replaced: "Approved (2026-08-26) (extra)" (R7)' (
            $r.code -eq 0 -and $cells.Count -eq 5 -and (Test-Same $cells[2] 'Approved (2026-08-26) (extra)')
        ) ((Format-Result $r) + " cells=[$($cells -join ' / ')]")
        $cells = Get-IndexRow $after '014'
        Assert 'US2-5: "Approved (2026-08-26,주석)" (no space after comma) -> "Approved (2026-08-26)" (FR-003)' (
            $r.code -eq 0 -and $cells.Count -eq 5 -and (Test-Same $cells[2] 'Approved (2026-08-26)')
        ) ((Format-Result $r) + " cells=[$($cells -join ' / ')]")
        $cells = Get-IndexRow $after '015'
        Assert 'US2-6: "Approved (2026-08-26) (note, x)" (first group has no comma) -> unchanged; later groups are never touched (FR-003, T017)' (
            $r.code -eq 0 -and $cells.Count -eq 5 -and (Test-Same $cells[2] 'Approved (2026-08-26) (note, x)')
        ) ((Format-Result $r) + " cells=[$($cells -join ' / ')]")
        $cells = Get-IndexRow $after '016'
        Assert 'US2-7: "Approved (2026-08-26, 주석) (extra, y)" -> only the first group normalised: "Approved (2026-08-26) (extra, y)" (FR-003, T017)' (
            $r.code -eq 0 -and $cells.Count -eq 5 -and (Test-Same $cells[2] 'Approved (2026-08-26) (extra, y)')
        ) ((Format-Result $r) + " cells=[$($cells -join ' / ')]")
    }

    # ---------- US3-A: 누락값·무시 항목·경고·같은 번호·이스케이프·BOM/CRLF·CR·중복 줄 — README 없음, 실행 1회 ----------
    Test-Group 'US3-A' {
        $d = New-Fixture $us3Files
        $readme = Join-Path $d 'specs/README.md'
        $r = Invoke-Script $d
        $text = [string](Read-Text $readme)
        $lines = $text -split "`n"
        $ok = ($r.code -eq 0 -and (Test-Same $r.out 'specs/README.md: 11 features indexed'))
        $c001 = Get-IndexRow $text '001'
        $c002 = Get-IndexRow $text '002'
        Assert 'US3-1: no **Priority** line -> "—" (FR-004)' (
            $ok -and $c002.Count -eq 5 -and (Test-Same $c002[3] '—')
        ) ((Format-Result $r) + " cells=[$($c002 -join ' / ')]")
        Assert 'US3-2: **Priority** present -> its value (FR-004)' (
            $ok -and $c001.Count -eq 5 -and (Test-Same $c001[3] '🔴')
        ) ((Format-Result $r) + " cells=[$($c001 -join ' / ')]")
        Assert 'US3-3: plan.md missing -> link cell "[spec](…)" only; present -> "[spec](…) · [plan](…)" (FR-005)' (
            $ok -and $c002.Count -eq 5 -and (Test-Same $c002[4] '[spec](002-np/spec.md)') -and $c001.Count -eq 5 -and (Test-Same $c001[4] '[spec](001-p/spec.md) · [plan](001-p/plan.md)')
        ) ((Format-Result $r) + " c001=[$($c001 -join ' / ')] c002=[$($c002 -join ' / ')]")
        $strayLines = @($lines | Where-Object { $_ -cmatch 'README|notes|zz-x|020-empty' }).Count
        Assert 'US3-4: README.md / notes/ / zz-x/ silently ignored (no row, no stderr); 020-empty without spec.md -> stderr exactly "warning: skip 020-empty: spec.md missing", exit 0 (FR-010)' (
            $ok -and $strayLines -eq 0 -and (Test-Same $r.err 'warning: skip 020-empty: spec.md missing')
        ) ((Format-Result $r) + " strayLines=$strayLines")
        $a0 = Get-IndexRow $text '040' 0; $a1 = Get-IndexRow $text '040' 1; $a2 = Get-IndexRow $text '040' 2
        Assert 'Edge-2: same number 040-a-b / 040-ab -> both rows, ordinal order (040-a-b first: "-" 0x2D < "a")' (
            $ok -and $a0.Count -eq 5 -and $a1.Count -eq 5 -and $a2.Count -eq 0 -and
            (Test-Same $a0[1] 'a-b') -and (Test-Same $a0[4] '[spec](040-a-b/spec.md)') -and (Test-Same $a1[1] 'ab') -and (Test-Same $a1[4] '[spec](040-ab/spec.md)')
        ) ((Format-Result $r) + " row0=[$($a0 -join ' / ')] row1=[$($a1 -join ' / ')] extra=$($a2.Count)")
        $p1 = Get-IndexRow $text '041'; $p2 = Get-IndexRow $text '042'; $p3 = Get-IndexRow $text '043'
        Assert 'Edge-3: title "A | B" -> cell "A \| B"; "A \| B" -> "A \\\| B"; "# 그냥 제목" (no prefix) -> "그냥 제목" (FR-002/013)' (
            $ok -and $p1.Count -eq 5 -and (Test-Same $p1[1] 'A \| B') -and $p2.Count -eq 5 -and (Test-Same $p2[1] 'A \\\| B') -and $p3.Count -eq 5 -and (Test-Same $p3[1] '그냥 제목')
        ) ((Format-Result $r) + " 041=[$($p1 -join ' / ')] 042=[$($p2 -join ' / ')] 043=[$($p3 -join ' / ')]")
        $b = Get-IndexRow $text '044'
        Assert 'Edge-4: BOM+CRLF spec.md -> same title/Status/Priority cells as its LF twin (001-p)' (
            $ok -and $b.Count -eq 5 -and $c001.Count -eq 5 -and (Test-Same $b[1] $c001[1]) -and (Test-Same $b[2] $c001[2]) -and (Test-Same $b[3] $c001[3]) -and (Test-Same $b[4] '[spec](044-bom/spec.md)')
        ) ((Format-Result $r) + " 044=[$($b -join ' / ')] 001=[$($c001 -join ' / ')]")
        $dup = Get-IndexRow $text '050'
        Assert 'Edge-8: duplicate **Status**/**Priority** lines -> first line wins ("Draft", "🔴")' (
            $ok -and $dup.Count -eq 5 -and (Test-Same $dup[2] 'Draft') -and (Test-Same $dup[3] '🔴')
        ) ((Format-Result $r) + " cells=[$($dup -join ' / ')]")
        $ws = Get-IndexRow $text '045'
        Assert 'Edge-14: "**Priority**:   " (spaces only) -> "—" (FR-004)' (
            $ok -and $ws.Count -eq 5 -and (Test-Same $ws[3] '—')
        ) ((Format-Result $r) + " cells=[$($ws -join ' / ')]")
        $cr = Get-IndexRow $text '046'
        $f = Get-ByteFacts $readme
        Assert 'Edge-15: lone CR inside the H1 -> cell without CR; README has no CR byte and no BOM (FR-012)' (
            $ok -and $cr.Count -eq 5 -and -not $cr[1].Contains("`r") -and $f.exists -and -not $f.cr -and -not $f.bom
        ) ((Format-Result $r) + " cells=[$(($cr -join ' / ').Replace("`r", '<CR>'))] cr=$($f.cr) bom=$($f.bom)")
        Assert 'Edge-5: README missing -> created, starts with "# Feature 인덱스", contains the table (FR-011)' (
            $ok -and $text.StartsWith("# Feature 인덱스`n", [StringComparison]::Ordinal) -and (Test-HasLine $lines $tableHeader) -and (Test-HasLine $lines $tableSep)
        ) ((Format-Result $r) + " head=[$($text.Substring(0, [Math]::Min(120, $text.Length)))]")
        $expectedStart = $defaultPreamble + $tableHeader + "`n" + $tableSep + "`n"
        Assert 'Edge-17: default preamble is exactly the FR-011 text, followed by a blank line and the table header' (
            $ok -and $text.StartsWith($expectedStart, [StringComparison]::Ordinal)
        ) ((Format-Result $r) + " head=[$($text.Substring(0, [Math]::Min($expectedStart.Length, $text.Length)))]")
    }

    # ---------- US3-B: H1/Status 누락 → 오류 수집·exit 1·README 불변 (FR-009), 실행 1회 ----------
    Test-Group 'US3-errors' {
        $d = New-Fixture $us3ErrFiles
        $readme = Join-Path $d 'specs/README.md'
        $snap = Get-Snapshot $readme
        $r = Invoke-Script $d
        $untouched = Test-Snapshot $readme $snap
        $errLines = Get-ErrLines $r
        Assert 'US3-5: missing **Status** line -> "error: 030-bad/spec.md: missing **Status** line", exit 1, README content and LastWriteTime untouched (FR-009)' (
            $r.code -eq 1 -and (Test-HasLine $errLines 'error: 030-bad/spec.md: missing **Status** line') -and $untouched
        ) ((Format-Result $r) + " untouched=$untouched")
        Assert 'US3-6: missing H1 -> "error: 031-noh1/spec.md: missing H1 title" (FR-009)' (
            $r.code -eq 1 -and (Test-HasLine $errLines 'error: 031-noh1/spec.md: missing H1 title')
        ) (Format-Result $r)
        Assert 'Edge-13: "**Status**:   " (spaces only) -> treated as missing: "error: 070-ws/spec.md: missing **Status** line", exit 1' (
            $r.code -eq 1 -and (Test-HasLine $errLines 'error: 070-ws/spec.md: missing **Status** line')
        ) (Format-Result $r)
        $onlyErrors = @($errLines | Where-Object { -not $_.StartsWith('error: ', [StringComparison]::Ordinal) }).Count -eq 0
        Assert 'US3-7: several broken specs -> every error printed (exactly 3 lines, all "error: …", no stack/dump)' (
            $r.code -eq 1 -and $errLines.Count -eq 3 -and $onlyErrors
        ) ((Format-Result $r) + " lines=$($errLines.Count)")
    }

    # ---------- US3-8: -Root에 specs/ 없음(존재하지 않는 경로) (FR-015; T001과 중복 허용) ----------
    Test-Group 'US3-8' {
        $d = New-Fixture @{}
        $r = Invoke-Script (Join-Path $d 'nope')
        Assert 'US3-8: -Root pointing to a nonexistent path -> stderr starts with "error: specs directory not found", exit 1 (FR-015)' (
            $r.code -eq 1 -and ([string]$r.err).StartsWith('error: specs directory not found', [StringComparison]::Ordinal)
        ) (Format-Result $r)
    }

    # ---------- Edge-1: feature 0개(빈 specs/) → 헤더+구분 행만 ----------
    Test-Group 'Edge-1' {
        $d = New-Fixture @{}
        New-Item -ItemType Directory -Path (Join-Path $d 'specs') | Out-Null
        $readme = Join-Path $d 'specs/README.md'
        $r = Invoke-Script $d
        $text = [string](Read-Text $readme)
        $tableLines = @(($text -split "`n") | Where-Object { $_.StartsWith('|', [StringComparison]::Ordinal) })
        Assert 'Edge-1: zero features (empty specs/) -> exit 0, "0 features indexed", README ends with header + separator rows only' (
            $r.code -eq 0 -and (Test-Same $r.out 'specs/README.md: 0 features indexed') -and $text.EndsWith("`n`n" + $tableHeader + "`n" + $tableSep + "`n", [StringComparison]::Ordinal) -and $tableLines.Count -eq 2
        ) ((Format-Result $r) + " tableLines=$($tableLines.Count) readme=[$text]")
    }

    # ---------- Edge-6: README에 표 없음(머리말만, 끝 개행 없음) → 머리말\n\n표\n, 2회차 (unchanged) ----------
    Test-Group 'Edge-6' {
        $files = $us1Specs.Clone(); $files['specs/README.md'] = "# 머리말`n`n설명 문단."
        $d = New-Fixture $files
        $readme = Join-Path $d 'specs/README.md'
        $r = Invoke-Script $d
        $after = [string](Read-Text $readme)
        $expected = "# 머리말`n`n설명 문단.`n`n" + ($us1Table -join "`n") + "`n"
        $r2 = Invoke-Script $d
        Assert 'Edge-6: README without a table (preamble only, no trailing newline) -> "preamble\n\ntable\n"; second run "(unchanged)" (FR-007/008)' (
            $r.code -eq 0 -and (Test-Same $after $expected) -and $r2.code -eq 0 -and (Test-Same $r2.out 'specs/README.md: 2 features indexed (unchanged)')
        ) ((Format-Result $r) + ' / ' + (Format-Result $r2) + " readme=[$after]")
    }

    # ---------- Edge-16: README가 0바이트 → 표가 1행부터(앞 빈 줄 없음), 2회차 (unchanged) ----------
    Test-Group 'Edge-16' {
        $files = $us1Specs.Clone(); $files['specs/README.md'] = ''
        $d = New-Fixture $files
        $readme = Join-Path $d 'specs/README.md'
        $r = Invoke-Script $d
        $after = [string](Read-Text $readme)
        $expected = ($us1Table -join "`n") + "`n"
        $r2 = Invoke-Script $d
        Assert 'Edge-16: empty (0-byte) README -> file starts with the table header on line 1 (no leading blank lines); second run "(unchanged)"' (
            $r.code -eq 0 -and (Test-Same $after $expected) -and $r2.code -eq 0 -and (Test-Same $r2.out 'specs/README.md: 2 features indexed (unchanged)')
        ) ((Format-Result $r) + ' / ' + (Format-Result $r2) + " readme=[$after]")
    }

    # ---------- Edge-11: README가 BOM+CRLF → 1회 재기록(BOM·CR 제거), 2회차 (unchanged) (FR-012) ----------
    Test-Group 'Edge-11' {
        $expected = $us1Pre + ($us1Table -join "`n") + "`n" + $us1Post
        $files = $us1Specs.Clone(); $files['specs/README.md'] = [byte[]]($bomBytes + $utf8.GetBytes($expected.Replace("`n", "`r`n")))
        $d = New-Fixture $files
        $readme = Join-Path $d 'specs/README.md'
        $r = Invoke-Script $d
        $f = Get-ByteFacts $readme
        $sameBytes = $f.exists -and [Linq.Enumerable]::SequenceEqual([byte[]]$f.bytes, [byte[]]$utf8.GetBytes($expected))
        $r2 = Invoke-Script $d
        Assert 'Edge-11: BOM+CRLF README -> rewritten once (no "(unchanged)") as UTF-8 without BOM and LF only; second run "(unchanged)" (FR-012)' (
            $r.code -eq 0 -and (Test-Same $r.out 'specs/README.md: 2 features indexed') -and -not $f.bom -and -not $f.cr -and $sameBytes -and
            $r2.code -eq 0 -and (Test-Same $r2.out 'specs/README.md: 2 features indexed (unchanged)')
        ) ((Format-Result $r) + ' / ' + (Format-Result $r2) + " bom=$($f.bom) cr=$($f.cr) sameBytes=$sameBytes")
    }

    # ---------- Edge-7: feature 100개 → exit 0, 5초 미만 (SC-005) ----------
    Test-Group 'Edge-7' {
        $d = New-Fixture $perfFiles
        $r = Invoke-Script $d
        $text = [string](Read-Text (Join-Path $d 'specs/README.md'))
        $rows = @(($text -split "`n") | Where-Object { $_ -cmatch '^\| [0-9]{3} \| ' }).Count
        Assert 'Edge-7: 100 features -> exit 0, "100 features indexed", 100 rows, elapsed < 5 s (SC-005)' (
            $r.code -eq 0 -and (Test-Same $r.out 'specs/README.md: 100 features indexed') -and $rows -eq 100 -and $r.ms -lt 5000
        ) ((Format-Result $r) + " rows=$rows ms=$($r.ms)")
    }

    # ---------- Edge-9: spec.md에 잘못된 UTF-8 바이트 → error: 한 줄, exit 1, README 불변 ----------
    Test-Group 'Edge-9' {
        $files = $us1Files.Clone()
        $files['specs/060-bin/spec.md'] = [byte[]]([byte[]](0x23, 0x20, 0xC3, 0x28, 0x0A) + $utf8.GetBytes("**Status**: Draft`n"))
        $d = New-Fixture $files
        $readme = Join-Path $d 'specs/README.md'
        $snap = Get-Snapshot $readme
        $r = Invoke-Script $d
        $untouched = Test-Snapshot $readme $snap
        $errLines = Get-ErrLines $r
        Assert 'Edge-9: invalid UTF-8 (0xC3 0x28) in spec.md -> stderr is exactly one line starting with "error:", exit 1, README untouched (decode failure contract)' (
            $r.code -eq 1 -and $errLines.Count -eq 1 -and $errLines[0].StartsWith('error:', [StringComparison]::Ordinal) -and $untouched
        ) ((Format-Result $r) + " lines=$($errLines.Count) untouched=$untouched")
    }

    # ---------- Edge-10: README 읽기 전용 + 재기록 필요 → error: 한 줄, exit 1, README 불변 (I/O 실패 계약) ----------
    Test-Group 'Edge-10' {
        $d = New-Fixture $us1Files                      # 기존 표가 틀려 재기록이 필요한 입력
        $readme = Join-Path $d 'specs/README.md'
        $snap = Get-Snapshot $readme
        (Get-Item -LiteralPath $readme).IsReadOnly = $true
        try {
            $r = Invoke-Script $d
            $untouched = Test-Snapshot $readme $snap
        } finally {
            (Get-Item -LiteralPath $readme).IsReadOnly = $false
        }
        $errLines = Get-ErrLines $r
        $leftovers = @(Get-ChildItem -LiteralPath (Join-Path $d 'specs') -File -Filter 'README.md.*.tmp').Count
        Assert 'Edge-10: read-only README that needs a rewrite -> exit 1, stderr exactly one "error:" line, README content and LastWriteTime untouched, no tmp left behind (I/O failure contract)' (
            $r.code -eq 1 -and $errLines.Count -eq 1 -and $errLines[0].StartsWith('error:', [StringComparison]::Ordinal) -and $untouched -and $leftovers -eq 0
        ) ((Format-Result $r) + " lines=$($errLines.Count) untouched=$untouched leftovers=$leftovers")
    }

    # ---------- Edge-12: README에 `| # |` 헤더 행 2개 → multiple index tables, exit 1, README 불변 ----------
    Test-Group 'Edge-12' {
        $files = $us1Specs.Clone(); $files['specs/README.md'] = $us1Pre + $us1OldTable + "`n" + $us1OldTable + $us1Post
        $d = New-Fixture $files
        $readme = Join-Path $d 'specs/README.md'
        $snap = Get-Snapshot $readme
        $r = Invoke-Script $d
        $untouched = Test-Snapshot $readme $snap
        Assert 'Edge-12: two "| # |" header rows -> "error: specs/README.md: multiple index tables", exit 1, README untouched' (
            $r.code -eq 1 -and (Test-Same $r.err 'error: specs/README.md: multiple index tables') -and $untouched
        ) ((Format-Result $r) + " untouched=$untouched")
    }
} finally {
    Remove-Fixture
}

$harnessWatch.Stop()
Write-Host "`nruns=$($script:runs) elapsed=$($harnessWatch.ElapsedMilliseconds)ms"
Write-Host "$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
