# Main Project Changelog

## Merged Features Log

### specs 인덱스 재생성 스크립트 (smoke) — archived 2026-08-27
**Branch:** 002-smoke
**Spec:** [specs/002-smoke/spec.md](../../specs/002-smoke/spec.md)

**What was added:**
- US1 인덱스 한 번에 재생성: 저장소 운영자가 `spec.md` 헤더를 바꾼 뒤 `pwsh -NoProfile -File scripts/update-specs-index.ps1` 하나로 `specs/README.md`의 feature 인덱스 표(`| # | Feature | Status | 우선순위 | 링크 |`, 번호 오름차순, `plan.md`가 있으면 plan 링크)를 다시 만든다. 표 블록만 교체하고 머리말·후행 텍스트는 문자 단위로 보존, 같은 입력이면 파일을 쓰지 않으며(`(unchanged)`), 어느 작업 디렉터리에서든 저장소의 `specs/`를 대상으로 동작(`-Root` 기본값 = 스크립트 상위 디렉터리).
- US2 Status 값 정규화: `**Status**` 값의 첫 괄호 그룹에서 첫 쉼표 이후 주석을 제거해 `Approved (2026-08-26, 외부 리뷰 반영판)` → `Approved (2026-08-26)`; 날짜만 있거나 괄호가 없는 값은 그대로(구현은 문자열 시작에 앵커한 정규식 — converge에서 "첫 쉼표 있는 괄호" 결함 수정).
- US3 결측값과 예외 상황 처리: `**Priority**` 없으면 `—`, `plan.md` 없으면 spec 링크만, `NNN-slug` 형식이 아닌 항목은 조용히 무시, `spec.md` 없는 `NNN-slug` 디렉터리는 `warning:` 후 건너뜀(exit 0); H1/`**Status**` 결손·읽을 수 없는 입력(권한·잘못된 UTF-8)·쓸 수 없는 README(권한·잠금)·표 헤더 중복·`specs/` 부재는 `error:` 한 줄 + exit 1로 실패하고 README를 건드리지 않는다(fail-closed, 임시 파일 + 교체의 원자적 쓰기). BOM/CRLF 입력 정규화, `\`·`|` 이스케이프, feature 0개 빈 표, 번호 중복 ordinal 정렬, 출력 UTF-8(BOM 없음)·LF.
- 저장소 실물 적용: `specs/README.md`를 스크립트로 재생성(001 행 우선순위 `🔴` → `—` — 001 spec에 `**Priority**` 줄이 없어 의도된 결과; 002 행 추가; 머리말을 "스크립트로 재생성한다"로 갱신), `tests/run-all.ps1`에 `scripts`·`specs-index-fresh` 검사 추가, `AGENTS.md`·`docs/kr/AGENTS_kr.md` Commands 행에서 "(added by feature 002-smoke)" 제거 + 복구 힌트 추가, CLAUDE.md SPECKIT 블록이 `specs/002-smoke/plan.md`를 가리킴.
- SP-0 스모크 테스트(001 SC-003): specify → clarify(생략) → plan → checklist → tasks → 승인(approval-review: analyze 6건 CRITICAL 0 + 경계 5 리뷰 MEDIUM 4·LOW 15·nit 2 전부 반영) → SDD(batch 5 + Phase 7, 리뷰가 잡은 결함 3건) → converge 2회(✅ Converged) → tester E2E(US1 4·US2 3·US3 5·Edge 10 PASS, FAIL/SKIP 0) → finish 전체 사이클을 처음으로 실주행. 내구적 결정 없음. 헌법 I–VI PASS, Complexity Tracking 해당 없음(의존성 0, 단일 파일; 유일한 추가 표면은 테스트 격리용 `-Root`).
- 계약 외 동작 2건(converge T019, 정당화됨): 읽기 전용 README 사전 검사 메시지 `error: specs/README.md is read-only: <path>`; 빈 README(0바이트·공백뿐)는 선행 빈 줄 없이 표부터 기록. 계약 문서 갱신은 다음 feature.

**New Components:**
- `scripts/update-specs-index.ps1`(185줄, PowerShell 7.6.5+, 의존성 0; `-Root` 매개변수; 수집 → 엄격 UTF-8 파싱 → 정규화 → 표 조립 → README 표 블록 교체/덧붙임/생성 → 원자적 쓰기; 전역 try/catch, 헤더 주석에 복구 절차)
- `tests/scripts/update-specs-index.tests.ps1`(532줄; 프레임워크 없는 자체 하네스 `Assert`/`Test-Group`/`New-Fixture`/`Invoke-Script`/`Test-Same`/`Get-IndexRow`, 40 단언, 자식 pwsh 21회 ≈16초)
- `tests/run-all.ps1` 검사 항목 `scripts`(하네스 실행)·`specs-index-fresh`(실물 인덱스가 `(unchanged)`인지; 낡으면 재생성하는 부작용 명시) + `$PSNativeCommandUseErrorActionPreference = $false`
- 명령 계약 `specs/002-smoke/contracts/cli.md`(매개변수·메시지·종료 코드·표 스키마·안정성 약속) — 통합본 plan "Interfaces & Contracts" 절에 반영
- feature 산출물 `specs/002-smoke/{spec,plan,tasks,research,data-model,quickstart,report}.md`, `checklists/{requirements,requirements-quality}.md`, `reviews/2026-08-27-{approval,finish}.md`; 학습 노트 `content/study/002-smoke.mdx`; `CHANGELOG.md` 항목

**Tasks Completed:** 19/19 tasks

### Claude Code 기반 셋팅 (SP-0) — archived 2026-08-27
**Branch:** 001-claude-setup
**Spec:** [specs/001-claude-setup/spec.md](../../specs/001-claude-setup/spec.md)

**What was added:**
- US1 표준 feature 사이클: `/speckit-specify`(git 확장이 브랜치 `NNN-slug` 생성) → clarify → plan → checklist → tasks → 승인 → SDD 구현 → converge → E2E → `/finish` → finishing → 머지 → archive까지 한 흐름으로 끝나고 모든 산출물이 `specs/NNN-slug/`에 남는다. `002-smoke`로 12 Step 전부 실주행 검증(clarify는 마커 0으로 SKIP).
- US2 승인 전 경계별 리뷰: 사용자의 "승인" 키워드를 approval-review 훅이 잡아 `/approval-review`를 선행시키고, 보안·테넌트/데이터·운영성·트렌드·spec 정합성(analyze) 5개 경계를 별도 서브에이전트로 병렬 리뷰해 `reviews/YYYY-MM-DD-approval.md`를 남긴 뒤 사용자 확정 후에만 `**Status**: Approved`가 된다.
- US3 마감 게이트: finish 리뷰 `Status: Approved`, 비어 있지 않은 `report.md`, `content/study/<feature>*.mdx`가 없으면 finish-gate 훅이 `superpowers:finishing-a-development-branch`를 deny하고 `/finish`를 안내한다(부정·긍정 케이스 모두 002에서 확인). 활성 feature는 `SPECIFY_FEATURE_DIRECTORY` → 브랜치 → `feature.json` 순, 불일치는 fail-closed.
- US4 Tester 에이전트: User Story별 E2E를 사용자 관점으로 실행해 PASS/FAIL/SKIP을 보고하며, 테스트 경로(`tests/**`, `e2e/**`, `**/*.test.*`, `**/*.spec.*`, `**/__tests__/**`)에만 쓸 수 있다(tester-write-guard 훅, 저장소 밖·경로 순회·접두 충돌 차단).
- US5 학습 노트 초안: `/finish`가 `content/study/NNN-slug.mdx`를 frontmatter 계약(`.claude/rules/content.md`)에 맞춰 draft로 생성한다(001·002 노트 존재).
- US6 한국어 미러: 영어 에이전트 파일 9종(CLAUDE.md, AGENTS.md, 헌법, tester, 스킬 2, 규칙 3)의 `docs/kr/*_kr.md` 미러를 `/finish`가 best-effort로 동기화하고 `tests/run-all.ps1`이 커버리지를 검사한다.
- US7 머지 후 통합본: `archive` 확장 1.3.0(`/speckit-archive-run`)으로 `.specify/memory/{spec,plan,changelog}.md`에 feature 내용을 통합하는 경로를 마련했다(이 항목이 첫 실행).
- 문서 정책과 규율: 헌법 1.0.0(6원칙, Test-First NON-NEGOTIABLE), MADR 4.0 ADR(0000 MADR 채택, 0001 Spec Kit + superpowers + 저장소 게이트 채택), Spec Kit 업그레이드 런북·커스터마이즈 레지스터, Keep a Changelog CHANGELOG, `.gitattributes` LF 강제, Conventional Commits, `speckit-*` 17개 name-only(자동 트리거 차단, SKILL.md 무수정), Bash/PowerShell 파괴 명령 deny 27개, CLAUDE.md ≤ 200줄(현재 60줄).
- `002-smoke` 머지: 스모크 feature(`scripts/update-specs-index.ps1` — `specs/README.md` 인덱스 재생성)가 전체 사이클(승인 리뷰·게이트 deny/allow·SDD·converge 2회·tester 22 시나리오 PASS·finish 리뷰)을 통과하고 001 브랜치에 fast-forward 머지되었다.
- 계획 대비 변경: `selftest` 확장은 1.0.2 카탈로그에 없어 제외, `adrkit`은 `spec-kit <0.16` 버전 게이트로 설치 불가(Tier 2 이월, ADR 수작성), `skillOverrides`는 `user-invocable-only`가 스킬 연쇄 호출을 막아 `name-only`로 변경. ADR 0002(CI/CD 원칙)는 SP-1로 이월(연구 입력 `research/2026-08-26-cicd-policy-*.md`는 참고 자료로만 보존).

**New Components:**
- 훅 3종 `.claude/hooks/{approval-review,finish-gate,tester-write-guard}.ps1`(PowerShell; 입력 파싱 fail-open, 게이트·경로 판정 fail-closed)
- 프로젝트 스킬 2종 `.claude/skills/approval-review/`(SKILL.md + 경계 5: security, tenant-data, operability, trends, spec-consistency), `.claude/skills/finish/`(SKILL.md + 경계 4: report-vs-diff, e2e-evidence, study-contract, decisions)
- 에이전트 `.claude/agents/tester.md`(frontmatter 훅으로 쓰기 경로 가드)
- 규칙 3종 `.claude/rules/{specs,docs,content}.md`(`paths:` 경로 스코프)
- `.claude/settings.json`(deny 27, 훅 등록 `${CLAUDE_PROJECT_DIR}`, skillOverrides 17× name-only)
- Spec Kit 런타임 `.specify/`(1.0.2 init, integration=claude/script=ps; 확장 git·agent-context·archive; `extensions.yml` 훅 `before_specify`·`after_plan`; `git-config.yml` `commit_style: conventional`) + 생성 스킬 `.claude/skills/speckit-*/` 17개(무수정)
- `.specify/templates/overrides/tasks-template.md`(테스트 MANDATORY + 스토리별 E2E task) · `.specify/memory/constitution.md`(헌법 1.0.0)
- 문서: `CLAUDE.md`, `AGENTS.md`, `README.md`, `CHANGELOG.md`, `docs/README.md`, `docs/decisions/{0000-use-madr,0001-adopt-spec-kit-with-superpowers}.md`, `docs/runbooks/spec-kit-upgrade.md`, 한국어 미러 9종 `docs/kr/**`, `specs/README.md`
- 학습 노트 `content/study/{001-claude-setup,002-smoke}.mdx`
- 테스트 `tests/run-all.ps1`(저장소 검사 11절 12 Check), `tests/hooks/run-hook-tests.ps1`(훅 하네스 23 케이스), `tests/scripts/update-specs-index.tests.ps1`(002)
- 스크립트 `scripts/update-specs-index.ps1`(002-smoke 산출)
- 저장소 루트 `.gitattributes`(LF), `.gitignore`(`.specify/feature.json` 등), GitHub private 원격 `joshua92y/joshuatech_ver2`
