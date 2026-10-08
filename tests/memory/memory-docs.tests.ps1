# tests/memory/memory-docs.tests.ps1 — .specify/memory/product.md·architecture.md 검사 스위트 (T017, test-first)
# Run: pwsh -NoProfile -File tests/memory/memory-docs.tests.ps1
# Exit 0 = all pass 또는 아래 SKIP, 1 = failures. 외부 프레임워크 없음(tests/hooks·tests/scripts 하네스와 같은 구조).
#
# SKIP 의미론(tests/run-all.ps1 1e 'adr-madr' 슬롯과의 계약 — T004 platform 러너의 첫 줄 SKIP 마커 패턴과 같은 방식):
#   - 두 파일이 "모두" 없을 때만 첫 줄 'SKIP memory-docs tests -- ' + exit 0 (T027–T028 작성 전).
#   - 하나라도 있으면 두 파일 전부에 대해 전체 단언을 실행한다(부분 존재 = fail closed FAIL).
#
# 검사 계약(FR-002 — T027–T028 작성자가 따라야 하는 형태):
#   - 검사 본문은 <!-- SPECKIT ... --> 관리 블록(START…END) 밖의 줄만 본다(두 문서는 agent-context
#     블록·archive 통합본과 별개다). START만 있고 END가 없으면 그 뒤 전체를 블록 안으로 간주한다(fail closed).
#   - product.md 절 제목 토큰: 목표 / 도메인 / pod 목록 / 로드맵
#     architecture.md 절 제목 토큰: 토폴로지 / 경계 / 계약 / 운영 원칙
#     (마크다운 제목 줄(#{1,6})에 토큰 포함, 대소문자 무시 — 예: '## 제품 목표', '## Pod 목록')
#   단언 수: 파일당 6(존재 1 + 블록 밖 내용 비어 있지 않음 1 + 절 4) × 2 = 12
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

$targets = @(
    @{ n = 'product'; path = (Join-Path $repo '.specify/memory/product.md'); sections = @('목표', '도메인', 'pod 목록', '로드맵') },
    @{ n = 'architecture'; path = (Join-Path $repo '.specify/memory/architecture.md'); sections = @('토폴로지', '경계', '계약', '운영 원칙') }
)

# ---------- SKIP 게이트: 두 파일이 모두 없을 때만(그 외 어떤 경우에도 SKIP하지 않는다) ----------
$existing = @($targets | Where-Object { Test-Path -LiteralPath $_.path -PathType Leaf })
if ($existing.Count -eq 0) {
    Write-Host 'SKIP memory-docs tests -- .specify/memory/product.md and architecture.md not written yet (T027-T028)'
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

# <!-- SPECKIT ... --> 블록 밖의 줄만 돌려준다. 마커 줄 자체도 블록 안으로 취급하고,
# END 없는 START는 파일 끝까지 블록으로 본다(fail closed). END 단독 줄은 무시한다(블록을 열지 않는다).
function Get-OutsideLines([string[]]$lines) {
    $out = @(); $inBlock = $false
    foreach ($l in $lines) {
        if ($inBlock) {
            if ($l -cmatch '<!--\s*SPECKIT\s+END\s*-->') { $inBlock = $false }
            continue
        }
        if ($l -cmatch '<!--\s*SPECKIT') {
            if (-not ($l -cmatch '<!--\s*SPECKIT\s+END\s*-->')) { $inBlock = $true }
            continue
        }
        $out += $l
    }
    return , $out
}

foreach ($t in $targets) {
    Test-Group "memory-$($t.n)" {
        $blankName = "memory-$($t.n)-2: non-blank content outside the <!-- SPECKIT --> block"
        $exists = Test-Path -LiteralPath $t.path -PathType Leaf
        Assert "memory-$($t.n)-1: .specify/memory/$($t.n).md exists" $exists "missing: $($t.path) (written in T027-T028)"
        if (-not $exists) {
            Assert $blankName $false 'precondition failed (file missing)'
            for ($si = 0; $si -lt $t.sections.Count; $si++) {
                Assert "memory-$($t.n)-$(3 + $si): heading contains '$($t.sections[$si])' outside the SPECKIT block" $false 'precondition failed (file missing)'
            }
            return
        }
        $raw = [IO.File]::ReadAllText($t.path)
        if ($raw.Length -gt 0 -and $raw[0] -eq [char]0xFEFF) { $raw = $raw.Substring(1) }   # 잔존 U+FEFF 방어
        $outside = Get-OutsideLines ($raw -split "\r?\n")
        Assert $blankName (($outside -join "`n") -match '\S') "all content is empty or inside a SPECKIT block ($($t.path))"
        for ($si = 0; $si -lt $t.sections.Count; $si++) {
            $tok = $t.sections[$si]
            $hit = @($outside | Where-Object { $_ -match ('^#{1,6}\s.*' + [regex]::Escape($tok)) })
            Assert "memory-$($t.n)-$(3 + $si): heading contains '$tok' outside the SPECKIT block" ($hit.Count -gt 0) "no markdown heading line containing '$tok' outside the SPECKIT block"
        }
    }
}

Write-Host "`n$($script:pass) passed, $($script:fail) failed"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
