# Main Project Changelog

## Merged Features Log

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
