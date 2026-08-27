# Report 002-smoke

## Summary
`specs/README.md`의 feature 인덱스 표를 각 `specs/NNN-slug/spec.md` 헤더에서 재생성하는 개발 도구 `scripts/update-specs-index.ps1`(PowerShell 7, 의존성 0)을 추가했다. 표 블록만 교체하고 머리말·후행 텍스트는 보존하며, Status는 `Approved (2026-08-26, 주석)` → `Approved (2026-08-26)`으로 정규화하고, 헤더가 깨진 spec·읽을 수 없는 입력·쓸 수 없는 README·표 중복은 `error:` 한 줄 + 종료 코드 1로 실패하되 README를 건드리지 않는다(fail-closed). 임시 파일 + 교체로 원자적으로 쓰고, 변경이 없으면 쓰지 않는다(멱등). 검증은 프레임워크 없는 하네스(40 단언)와 `tests/run-all.ps1`의 `scripts`·`specs-index-fresh` 검사로 한다. 이 feature는 SP-0의 스모크 테스트로서 specify → clarify(생략) → plan → checklist → tasks → 승인(approval-review) → SDD(구현자 + spec/품질 2단계 리뷰) → converge(2회) → tester E2E → finish 전체 사이클을 처음으로 실주행했다(001 spec SC-003). **내구적 결정 없음(no durable decision)** — 도구 스크립트 하나를 추가했을 뿐 프레임워크·경계·데이터 소유·프로토콜·컨벤션을 새로 정하지 않았다.

## Changes Made
기준: `git diff --stat $(git merge-base 001-claude-setup HEAD)...HEAD` (merge-base 859b321; 이 브랜치는 `001-claude-setup`에서 분기했고 그리로 머지된다. `main` 기준 diff는 001 전체를 포함하므로 여기서는 001 기준을 쓴다.) 17 files changed, 1651 insertions(+), 4 deletions(-), 커밋 36개(Conventional Commits, task당 1개 + 리뷰 반영 fix 5개 + 완료 표시 docs 커밋).

- `scripts/update-specs-index.ps1` (+185) — 신규. 수집(`^[0-9]{3,}-slug`, 정션 제외, ordinal 정렬) → 엄격 UTF-8 파싱(첫 H1·Status·Priority) → 정규화(첫 괄호 그룹 앵커) → 표 조립(`\`·`|` 이스케이프) → README 표 블록 교체/덧붙임/생성 → ordinal 비교 후 임시 파일 + `File.Move` 원자적 쓰기. 전역 try/catch, 경고·오류 계약, 읽기 전용 사전 검사, 헤더 주석에 복구 절차.
- `tests/scripts/update-specs-index.tests.ps1` (+532) — 신규. 자체 하네스: `Assert`/`Test-Group`(그룹 격리)/`New-Fixture`(문자열·바이트)/`Invoke-Script`(stdout·stderr 분리, `[Environment]::ProcessPath`)/`Test-Same`(ordinal)/`Get-IndexRow -nth`. 40 단언(T001 1, US1 7, US2 7, US3 8, Edge 17), 자식 프로세스 21회 ≈16초.
- `tests/run-all.ps1` (+9) — 검사 `scripts`(하네스 실행)·`specs-index-fresh`(실물 실행이 `(unchanged)`인지; 낡았으면 재생성하는 부작용을 주석과 FAIL 상세에 명시), `$PSNativeCommandUseErrorActionPreference = $false` 고정.
- `specs/README.md` (+3/−2) — 스크립트로 재생성: 001 행 우선순위 `🔴` → `—`(001 spec에 `**Priority**` 줄이 없음, spec Assumptions대로), 002 행 추가·Approved 갱신, 머리말 문구를 "스크립트로 재생성한다"로 갱신.
- `AGENTS.md` (+1/−1) · `docs/kr/AGENTS_kr.md` (+1/−1) — Commands 표 "Regenerate `specs/README.md`" 행: "(added by feature 002-smoke)" 제거, 복구 힌트 추가(converge F2).
- `CLAUDE.md` (+3) — agent-context 확장이 관리하는 `<!-- SPECKIT START/END -->` 블록에 `specs/002-smoke/plan.md` 경로(자동 갱신, 60줄 ≤ 200).
- `specs/002-smoke/spec.md` (+129) — `/speckit-specify` 산출(US 3·FR 15·SC 7·Edge Cases 15), 승인 전 리뷰 반영(Key Entities 소유 분리, Edge 보강), Status Approved (2026-08-27).
- `specs/002-smoke/plan.md` (+117) — `/speckit-plan` 산출 + 승인 리뷰 반영(pwsh 7.6.5, 원자적 쓰기, I/O 예외 계약, 건강 지표 2개, 런북 판단, 수용 리스크).
- `specs/002-smoke/research.md` (+54) — R1–R8 결정, converge 추기(앵커 정규식).
- `specs/002-smoke/data-model.md` (+47) — FeatureEntry·IndexDocument·진단 출력 표.
- `specs/002-smoke/contracts/cli.md` (+56) — 명령 계약(매개변수·메시지·종료 코드·표 스키마).
- `specs/002-smoke/quickstart.md` (+73) — 검증 절차 7단계 + `## 검증 기록 (2026-08-27)`.
- `specs/002-smoke/checklists/requirements.md` (+34) — 내장 spec 품질 체크리스트 16/16.
- `specs/002-smoke/checklists/requirements-quality.md` (+70) — 요구사항 품질 체크리스트 28항목(근거 있는 11개 체크).
- `specs/002-smoke/reviews/2026-08-27-approval.md` (+128) — 경계 5 리뷰(security·tenant-data·operability·trends·spec-consistency), 반영 표, 사용자 결정.
- `specs/002-smoke/tasks.md` (+209) — T001–T016 + Phase 7 Convergence T017–T019, 전부 `[X]`.
- (이 커밋에서 추가) `specs/002-smoke/report.md`, `specs/002-smoke/reviews/2026-08-27-finish.md`, `content/study/002-smoke.mdx`, `CHANGELOG.md` 항목, `docs/kr/CLAUDE_kr.md` SPECKIT 블록 동기화, `specs/002-smoke/tasks.md` T019 `[X]`.

### 계약 외 동작(converge T019, unrequested LOW 2건 — 정당화)
- (a) 읽기 전용 README를 쓰기 전에 검사해 `error: specs/README.md is read-only: <path>`로 실패한다. 계약(contracts/cli.md)의 "I/O 실패 → `error: <메시지>` 한 줄" 범주에 속하는 사용자 정의 문구이며, approval review(operability 2·security F6)가 요구한 것이다: Linux의 `rename(2)`는 읽기 전용 대상도 덮어쓰므로 플랫폼과 무관하게 같은 계약("오류 시 README 미변경")을 지키기 위한 사전 검사다. 스크립트 헤더에 문서화됨. 계약 문서 갱신은 승인 후 산출물이라 다음 feature에서 한다.
- (b) README가 0바이트이거나 공백뿐이면 선행 빈 줄 없이 표부터 쓴다(plan §5 공식대로면 파일이 `\n\n`으로 시작). approval review(operability Minor)를 반영한 합리적 특례이며 하네스 Edge-16이 고정한다.

## Validation
- 단위·계약 테스트: `pwsh -NoProfile -File tests/scripts/update-specs-index.tests.ps1` → `40 passed, 0 failed`, 종료 코드 0, `runs=21 elapsed≈16s`. TDD 증적: 각 스토리의 테스트 커밋이 RED(T001 0/1 → T003 1/6 → T007 10/3 → T010 19/19 → T017 39/1)로 시작해 구현 커밋에서 GREEN.
- 저장소 검사: `pwsh -NoProfile -File tests/run-all.ps1` → 12건 PASS(`hooks` 23/23, `scripts`, `specs-index-fresh`, CLAUDE.md 60줄, skillOverrides, hooks registered, kr mirrors 9, constitution placeholders 0, canonical headers 9, tasks-template override, specs index, mirrors headings) → `ALL PASS`, 약 37–41초.
- 실물 적용: `pwsh -NoProfile -File scripts/update-specs-index.ps1` → `specs/README.md: 2 features indexed (unchanged)`, `git status` 클린; 다른 cwd(`$env:TEMP`, `C:/`)에서 절대 경로 실행도 동일(FR-014). 100 feature 픽스처 ≈0.9초(SC-005 5초).
- 승인 리뷰(2026-08-27-approval.md): analyze 6건(CRITICAL 0) + 경계 5 리뷰 MEDIUM 4·LOW 15·nit 2 → 승인 전 전부 반영(원자적 쓰기, I/O 예외 계약, `specs-index-fresh`, ordinal 정렬, tester 쓰기 경계, pwsh 7.6.5 하한 등), 수용 리스크 2건(제목의 마크다운 전파, README 심볼릭 링크 미지원). 사용자 승인 후 Status Approved (2026-08-27).
- SDD 리뷰: batch 5개(T001–T002, T003–T005, T007–T008, T010–T011, T013–T016) + Phase 7, 각각 spec 준수 리뷰 → 품질 리뷰. 리뷰·converge 루프가 잡아 고친 실제 결함 3건(앞 둘은 SDD 리뷰, 셋째는 converge 1차 F1): 상대 `-Root`가 .NET cwd 기준으로 해석됨(daf7376, `GetUnresolvedProviderPathFromPSPath`), `-ceq` 문화권 비교가 BOM(U+FEFF)을 무시해 BOM-only README가 영구 `(unchanged)`(80377a8, ordinal `Equals` + US1-7), 정규화 정규식이 첫 괄호가 아닌 첫 "쉼표 있는 괄호"를 치환(e43bde4, `^` 앵커 + US2-6/7). 그 밖에 하네스 격리(`Test-Group`)·읽기 전용 명시 검사·엄격 UTF-8·CR 제거·run-all FAIL 상세 보강.
- converge: 1차 → LOW 4건(F1 정규식 앵커 contradicts, F2 AGENTS 복구 힌트 partial, F3/F4 unrequested) → Phase 7 T017–T019 append → 2차 → **✅ Converged**(49 요구사항·24 plan 결정·헌법 I–V PASS, 신규 갭 0).
- tester E2E(2026-08-27, HEAD bc299e1): **US1 4 PASS · US2 3 PASS · US3 5 PASS · Edge 10 PASS, FAIL 0, SKIP 0**. 예외 경로 포함(표 중복, feature 0개, BOM/CRLF, 읽기 전용, 잘못된 UTF-8, `-Root` 오류, 이스케이프, 동시 실행, 2000자 제목). 테스트 파일 추가 없음(기존 하네스가 동일 계약을 다룸), 픽스처는 `tests/scripts/fixtures/<guid>/`에서 실행 후 삭제, 종료 시 트리 클린.
- 운영상 교훈: Bash 도구가 큰 한국어 heredoc과 `\\`(백슬래시 접힘)를 다루지 못해 문서·정규식 편집은 Write/Edit 도구로 수행했다.
- 미실행·미검증: Linux/macOS pwsh에서의 실행(읽기 전용 사전 검사·문화권 비교는 코드로 대비했으나 실측하지 않음); CI 없음(SP-3에서 결정); PSScriptAnalyzer 미도입(함수명만 승인 동사로 맞춤).
- 미러 동기화: 이 feature에서 바뀐 에이전트 파일은 `AGENTS.md`(미러 동시 갱신, T015·T018)와 `CLAUDE.md`(agent-context 블록 — 이 커밋에서 `docs/kr/CLAUDE_kr.md`의 SPECKIT 블록을 같은 내용으로 동기화). 그 외 동기화 대상 없음.

### tester E2E 보고서 원문(2026-08-27)
**E2E Report — 002-smoke** (tester, 2026-08-27, HEAD bc299e1; 이후 커밋은 tasks.md 체크와 finish 산출물뿐)
Environment: available — pwsh 7.6.5, 하네스 40 passed / 0 failed, run-all ALL PASS(시작·종료 각 1회). 픽스처는 `tests/scripts/fixtures/<guid>/`에서 실행 후 삭제, 종료 시 `git status --short` 비어 있음.

| Story | Scenario | Result | Evidence |
|---|---|---|---|
| US1 | 1 (T006a 실저장소) | PASS | `(unchanged)`, exit 0, `git diff --exit-code` 0, 헤더 1개, 001·002 행이 각 spec.md 헤더와 일치 |
| US1 | 1 (T006d 픽스처) | PASS | 001/002 사본 → `2 features indexed`, 두 행이 실저장소 행과 바이트 동일, BOM/CR 없음 |
| US1 | 2 | PASS | 머리말·꼬리말 바이트 동일, stale 999 행 제거 |
| US1 | 3 | PASS | 2회 연속 `(unchanged)`, 트리 클린 |
| US1 | 4 (T006c) | PASS | `$env:TEMP`·`C:/`·`specs/001-claude-setup` cwd에서 동일, stray README 없음 |
| US2 | 1 (T009) | PASS | X=`Approved (2026-08-26, 외부 리뷰 반영판)` → `Approved (2026-08-26)`; 002 그대로 |
| US2 | 2 / 3 | PASS | `Done (2026-08-27)`·`Draft` 그대로; 첫 괄호만 정규화 |
| US3 | 1 / 2 / 3 | PASS | Priority 없음 → `—`; 🔴 바이트 f0 9f 94 b4; plan 없음 → spec 링크만 |
| US3 | 4 | PASS | 비-NNN 항목 조용히 무시, `020-empty` 경고 1줄, exit 0 |
| US3 | 5 (T012) | PASS | Status 없음 → `error: 002-y/spec.md: missing **Status** line`, exit 1, README 미생성; 수정 후 exit 0·README 생성; H1 없음·둘 다 없음·공백 H1 케이스 포함 |
| Edge | 표 헤더 2개 / feature 0개 / BOM+CRLF README·spec / 표 없는 README / 읽기 전용 README / 잘못된 UTF-8 / `-Root` 오류 / `\|` 이스케이프 / 동시 2회 / 2000자 제목 | PASS | 계약대로(오류 1줄·exit 1·README 불변 / 헤더+구분만 / 1회 재기록 후 unchanged / 덧붙임 / …) |

### Failures
- 없음. (관찰: 쉼표 앞 공백 `Approved (2026-08-26 , x)` → `Approved (2026-08-26 )` — spec 범위 밖.)

### Tests written
- 없음(임시 드라이버 `tests/scripts/fixtures/<guid>/driver.ps1`는 삭제). 기존 하네스 40 assertions가 동일 계약을 다룸.

## Next
- 계약 문서 정리(다음 feature): contracts/cli.md에 `error: specs/README.md is read-only: <path>` 명시, 번호 정렬 문구를 "(길이, 문자 코드)" 하나로 통일("정수 오름차순" 표현 제거), 기본 머리말 문구와 실물 README 머리말 문구 통일.
- AGENTS.md Layout 블록에 최상위 `scripts/` 디렉터리 추가(converge 관찰, 미러 포함).
- run-all 소요 ≈37초(하네스가 자식 pwsh 21회) — 자주 돌리게 되면 `-Quick` 분리 검토. GitHub 호스티드 러너로 옮길 때 Edge-7(5초) 여유 확인.
- 수용 리스크·범위 밖(변경 없음): spec 제목의 마크다운/HTML이 README에 전파(신뢰된 커미터), README 심볼릭 링크 미지원, 쉼표 앞 공백(`(2026-08-26 , x)` → `(2026-08-26 )`)·중첩 괄호는 정규화 범위 밖, 숨김 속성 디렉터리는 조용히 제외(run-all 검사 8과 일관).
- T018 힌트 문구 "run-all `scripts` FAIL → 스크립트 실행 후 커밋"은 승인 문안 그대로이나 `scripts`(하네스) 실패는 재실행으로 해결되지 않음 — 다음 feature에서 문구 다듬기.
- 머지 후 `/speckit-archive-run specs/002-smoke`, 002 Status를 Done으로 바꾼 뒤 이 스크립트로 인덱스를 재생성(specs 규칙 "헤더를 바꾸고 재생성"의 첫 도구 이행).
