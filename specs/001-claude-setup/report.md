# Report 001-claude-setup

## Summary
SP-0 — 포트폴리오 v2 저장소의 에이전트 작업 뼈대를 세웠다. Spec Kit 1.0.2(claude/ps 통합, git·agent-context·archive 확장, tasks 템플릿 override로 테스트 필수화, 헌법 1.0.0)가 WHAT(constitution, `specs/NNN-slug/`, analyze·converge·archive)을, superpowers 5.1.0(brainstorming·TDD·subagent-driven-development·code review·finishing)이 HOW를 맡고, 저장소가 게이트(훅 3종: approval-review·finish-gate·tester-write-guard, 스킬 2종: `/approval-review`·`/finish`, `tester` 에이전트, 규칙 3종, `tests/run-all.ps1`)를 소유한다. 문서 정책(MADR ADR, 런북, 한국어 미러, 학습 노트 계약)과 CLAUDE.md/AGENTS.md를 정했고, 스모크 feature `002-smoke`(specs 인덱스 재생성 스크립트)로 전체 사이클을 실주행해 검증했다(이 브랜치에 머지됨). 내구적 결정은 [ADR-0000 MADR 채택](../../docs/decisions/0000-use-madr.md)과 [ADR-0001 Spec Kit + superpowers + 저장소 게이트](../../docs/decisions/0001-adopt-spec-kit-with-superpowers.md)에 기록했다. CI/CD 정책 원칙의 ADR 0002는 사용자 결정(2026-08-27)으로 SP-1에서 런타임 트랙과 함께 작성한다(연구 입력은 `research/2026-08-26-cicd-policy-*.md`). 계획 대비 변경 3건: selftest 확장은 카탈로그에 없어 제외, adrkit은 `spec-kit <0.16` 버전 게이트로 설치 불가(Tier 2 이월, ADR 수작성), `skillOverrides`는 user-invocable-only가 스킬 연쇄 호출(speckit-specify → speckit-git-feature)을 막는 것이 확인되어 name-only로 변경.

## Changes Made
기준: `git diff --stat $(git merge-base main HEAD)...HEAD` (merge-base 32c631c, 브랜치 `001-claude-setup` HEAD ea7c658) — **136 files changed, 20088 insertions(+), 0 deletions(-)**, 커밋 75개(chore 4 · docs 37 · feat 15 · fix 9 · test 10; Conventional Commits, `Co-Authored-By` 트레일러). `002-smoke`(859b321..ea7c658: 22 files, +1840/−4, 37 commits — finish 커밋 포함)가 이 브랜치에 fast-forward 머지되었으므로 그 파일들도 포함된다(상세는 [specs/002-smoke/report.md](../002-smoke/report.md)).

### Claude 레이어 (`.claude/`, 36)
- `.claude/agents/tester.md` (+49/-0) — E2E tester 에이전트(테스트 경로만 쓰기, PreToolUse 가드)
- `.claude/hooks/approval-review.ps1` (+29/-0) — UserPromptSubmit: 승인 키워드 → `/approval-review` 지시
- `.claude/hooks/finish-gate.ps1` (+102/-0) — PreToolUse(Skill): finish 산출물 없으면 finishing deny(env → 브랜치 → feature.json, fail-closed)
- `.claude/hooks/tester-write-guard.ps1` (+45/-0) — tester의 Write/Edit를 저장소 내 테스트 경로로 제한
- `.claude/rules/content.md` (+30/-0) · `.claude/rules/docs.md` (+26/-0) · `.claude/rules/specs.md` (+18/-0) — 경로 범위 규칙
- `.claude/settings.json` (+77/-0) — Bash+PowerShell deny 27, 훅 등록(`${CLAUDE_PROJECT_DIR}`), skillOverrides 17× name-only
- `.claude/skills/approval-review/SKILL.md` (+79/-0) + `boundaries/{operability,security,spec-consistency,tenant-data,trends}.md` (+14/+17/+15/+14/+14) — 승인 전 경계 5 리뷰
- `.claude/skills/finish/SKILL.md` (+63/-0) + `boundaries/{decisions,e2e-evidence,report-vs-diff,study-contract}.md` (+16/+15/+16/+15) — 마감 산출물 + 경계 4 리뷰
- `.claude/skills/speckit-{agent-context-update,analyze,archive-run,checklist,clarify,constitution,converge,git-commit,git-feature,git-initialize,git-remote,git-validate,implement,plan,specify,tasks,taskstoissues}/SKILL.md` (+32/+262/+934/+386/+294/+180/+279/+68/+87/+54/+50/+54/+229/+169/+348/+217/+112) — Spec Kit 생성 스킬 17(무수정)

### Spec Kit 런타임 (`.specify/`, 57)
- `.specify/.gitignore` (+9) · `.specify/init-options.json` (+9) · `.specify/integration.json` (+15) · `.specify/integrations/claude.manifest.json` (+17) · `.specify/integrations/speckit.manifest.json` (+19)
- `.specify/extensions.yml` (+185) · `.specify/extensions/.registry` (+51)
- `.specify/extensions/agent-context/{README.md,agent-context-config.yml,agent-context-defaults.json,extension.yml}` (+63/+24/+42/+34) · `commands/speckit.agent-context.update.md` (+27) · `scripts/bash/update-agent-context.sh` (+453) · `scripts/powershell/update-agent-context.ps1` (+509) · `scripts/python/update_agent_context.py` (+368)
- `.specify/extensions/archive/{CHANGELOG.md,LICENSE,README.md,extension.yml}` (+380/+21/+78/+24) · `commands/archive.md` (+933)
- `.specify/extensions/git/{README.md,config-template.yml,extension.yml,git-config.yml}` (+119/+79/+142/+79) · `commands/speckit.git.{commit,feature,initialize,remote,validate}.md` (+63/+82/+49/+45/+49) · `scripts/bash/{auto-commit.sh,create-new-feature-branch.sh,git-common.sh,initialize-repo.sh}` (+211/+626/+56/+54) · `scripts/powershell/{auto-commit.ps1,create-new-feature-branch.ps1,git-common.ps1,initialize-repo.ps1}` (+230/+592/+52/+69) · `scripts/python/{auto_commit.py,create_new_feature_branch.py,git_common.py,initialize_repo.py}` (+195/+634/+81/+89)
- `.specify/memory/constitution.md` (+51) — 헌법 1.0.0 · `.specify/memory/.constitution-template.json` (+4)
- `.specify/scripts/powershell/{check-prerequisites.ps1,common.ps1,create-new-feature.ps1,resolve-template.ps1,setup-plan.ps1,setup-tasks.ps1}` (+174/+796/+319/+38/+83/+93)
- `.specify/templates/{checklist-template.md,constitution-template.md,plan-template.md,spec-template.md,tasks-template.md}` (+45/+50/+113/+131/+252) · `.specify/templates/overrides/tasks-template.md` (+266) — 테스트 MANDATORY + 스토리별 E2E
- `.specify/workflows/speckit/workflow.yml` (+78) · `.specify/workflows/workflow-registry.json` (+13)

### 저장소 루트·문서
- `.gitattributes` (+11) — LF 강제 · `.gitignore` (+3) — `.specify/feature.json` 등
- `AGENTS.md` (+39) · `CLAUDE.md` (+60, SPECKIT 블록 포함) · `README.md` (+9) · `CHANGELOG.md` (+12)
- `docs/README.md` (+12) · `docs/decisions/0000-use-madr.md` (+21) · `docs/decisions/0001-adopt-spec-kit-with-superpowers.md` (+22) · `docs/runbooks/spec-kit-upgrade.md` (+33)
- `docs/kr/AGENTS_kr.md` (+39) · `docs/kr/CLAUDE_kr.md` (+59) · `docs/kr/agents/tester_kr.md` (+52) · `docs/kr/constitution_kr.md` (+43) · `docs/kr/rules/{content_kr,docs_kr,specs_kr}.md` (+31/+27/+19) · `docs/kr/skills/{approval-review_kr,finish_kr}.md` (+126/+72) — 미러 9종
- `content/study/001-claude-setup.mdx` (+48) — 학습 노트(draft; 이 커밋에서 "결과와 검증" 문단을 실제 결과로 갱신) · `content/study/002-smoke.mdx` (+65)
- `scripts/update-specs-index.ps1` (+185) — 002-smoke 산출

### specs·tests
- `specs/001-claude-setup/spec.md` (+392) · `specs/001-claude-setup/plan.md` (+2365; 이 커밋에서 Step 체크박스 표시) · `specs/001-claude-setup/research/2026-08-26-research-summary.md` (+70) · `research/2026-08-26-cicd-policy-external.md` (+374) · `research/2026-08-26-cicd-policy-review.md` (+313)
- `specs/002-smoke/{spec,plan,tasks,research,data-model,quickstart,report}.md` (+129/+117/+209/+54/+47/+73/+73) · `contracts/cli.md` (+56) · `checklists/{requirements,requirements-quality}.md` (+34/+70) · `reviews/2026-08-27-{approval,finish}.md` (+128/+44)
- `specs/README.md` (+8) — 인덱스(002부터 스크립트 재생성)
- `tests/run-all.ps1` (+80) — 저장소 검사 11절(12 Check) · `tests/hooks/run-hook-tests.ps1` (+160) — 훅 하네스 23 케이스 · `tests/scripts/update-specs-index.tests.ps1` (+532) — 002-smoke 산출
- (이 커밋에서 추가·수정) `specs/001-claude-setup/report.md`, `specs/001-claude-setup/reviews/2026-08-27-finish.md`, `specs/001-claude-setup/plan.md` Step 체크박스(Task 26 Step 3–6·adrkit 미설치 Step 제외), `content/study/001-claude-setup.mdx` 결과 문단·`updatedDate`, `docs/kr/CLAUDE_kr.md` 재동기화

## Validation
### Task 24 — 새 세션 등록 확인 (2026-08-27)
| 항목 | 결과 | 근거 |
|---|---|---|
| 새 세션에서 `using-superpowers` 주입 1회 (SC-007) | PASS | SessionStart 컨텍스트에 superpowers 블록 1개 |
| superpowers 플러그인 단일 활성 (Task 2, SC-007) | PASS | `~/.claude/settings.json` enabledPlugins: `superpowers@superpowers-dev: true`, `superpowers@claude-plugins-official: false`(캐시에는 5.1.0·6.3.0 둘 다 설치, 활성 1개) |
| `specify check` (specify 1.0.2.dev0) | PASS | "Claude Code (available)", "Specify CLI is ready to use!", 오류 없음; selftest 확장은 카탈로그에 없어 제외 |
| 등록 확인 (Task 14, SC-004) | PASS | 세션 도구 목록에 agent `tester`, skills `approval-review`·`finish`(설명 있음), `speckit-*` 17개 name-only(설명 숨김, settings skillOverrides 17건과 일치); settings hooks UserPromptSubmit 1(approval-review.ps1)·PreToolUse matcher Skill 1(finish-gate.ps1), 경로 `${CLAUDE_PROJECT_DIR}`. CLI `/hooks`·`/agents`·`/skills` 화면은 사용자 확인 사항 |
| 모델이 speckit-*를 자발 호출하지 않음 (SC-001) | PASS | 이 세션의 speckit-* 호출은 002 lifecycle 단계에서 명시적으로만 발생 |
| `tests/run-all.ps1` | PASS | 세션 시작 시 9/9(훅 23/23) → 002 머지 후 12 Check ALL PASS(≈37초) |

### Task 25 — `002-smoke` 전체 사이클 실주행 (SC-003)
| Step | 결과 | 근거 |
|---|---|---|
| 1 시작 상태 | PASS | 클린 트리, 브랜치 001, feature.json 없음 |
| 2 `/speckit-specify` | PASS | before_specify 훅 `speckit.git.feature` 자동 실행 → 브랜치 `002-smoke`, `specs/002-smoke/spec.md`(US 3·FR 15·SC 7, 마커 0), feature.json → 002, 체크리스트 16/16 |
| 3 `/speckit-clarify` | SKIP | 마커 0개 → 계획대로 건너뜀 |
| 4 plan → agent-context(예) → checklist → tasks | PASS | Constitution Check 6/6, CLAUDE.md SPECKIT 블록 = 002 plan(60줄), `checklists/requirements-quality.md` 28항목, tasks.md 16 task(스토리별 테스트 선행 + E2E 3, `MANDATORY|E2E` 10줄) |
| 5 승인 훅 → `/approval-review` → 승인 | PASS | 사용자 "승인" 입력 → `/speckit-analyze`(6건, CRITICAL 0) + 경계 5 리뷰(MEDIUM 4·LOW 15·nit 2, 승인 전 반영) → AskUserQuestion "승인" → Status Approved (2026-08-27). 훅은 오프라인 실행(`prompt: "승인"`)으로 `[APPROVAL REVIEW HOOK]` systemMessage 출력 확인; 세션 내 주입은 컨텍스트에 별도 표시되지 않아 CLI 화면 확인은 사용자 몫 |
| 6 게이트 부정 케이스 (US3-1) | PASS | `finishing-a-development-branch` 호출 → finish-gate deny: "feature '002-smoke' is not ready to finish. Missing: newest reviews/YYYY-MM-DD-finish.md with 'Status: Approved', report.md (non-empty), content/study/002-smoke*.mdx (non-empty). Run /finish first." — 계획 문구 일치 |
| 7 SDD | PASS | batch 5 + Phase 7, 구현자마다 spec 준수 리뷰 → 품질 리뷰(재리뷰 2), 리뷰가 잡은 실제 결함 3건 수정, task마다 커밋·`[X]`, RED→GREEN 증적 |
| 8 `/speckit-converge` | PASS | 1차 LOW 4 → Phase 7 T017–T019 append → 2차 ✅ Converged |
| 9 tester (US4) | PASS | US1 4·US2 3·US3 5·Edge 10 시나리오 전부 PASS, FAIL/SKIP 0, 픽스처 `tests/scripts/fixtures/<guid>/` 정리 확인, 테스트 파일 추가 없음(가드 deny 발생 없음) |
| 10 `/finish` (US5·US6) | PASS | report.md, `content/study/002-smoke.mdx`(frontmatter 계약 충족, draft, change 002-smoke), CHANGELOG Unreleased 항목, kr 미러 동기화(AGENTS·CLAUDE 블록), 경계 4 리뷰 ✅ → `reviews/2026-08-27-finish.md` `Status: Approved` |
| 11 finishing 게이트 통과 → 001 머지 (US3-2) | PASS | finish-gate 출력 없음(허용) → 옵션 1: 002 → 001 fast-forward(ea7c658), 머지 결과 run-all ALL PASS, 브랜치 삭제 |
| 12 산출물 점검 + push | PASS | run-all ALL PASS(검사 8이 002 포함), 계획한 파일 전부 존재, `git push origin 001-claude-setup` 동기화 |

### Success Criteria
- SC-001 PASS — `specify check`·run-all 통과, `speckit-*` 17개(10 + 확장 7) 전부 `skillOverrides: name-only`(run-all 검사 3), 생성 SKILL.md 무수정(D13 — settings로만 통제; `git diff`에서 speckit-* 17개 모두 +N/−0).
- SC-002 PASS — 훅 하네스 23 케이스(approval 3, finish-gate 12, guard 8) GREEN.
- SC-003 PASS(archive 제외) — 002가 US1 시나리오 1~5 통과, `specs/002-smoke/`에 spec·plan·tasks·reviews(approval·finish)·report, `content/study/002-smoke.mdx`, CHANGELOG 항목 존재. `.specify/memory/` 통합은 Task 26 Step 4(archive)에서 수행.
- SC-004 PASS — CLAUDE.md 60줄 ≤ 200; 훅 2·tester·프로젝트 스킬 2 등록(세션 도구 목록·settings 기준).
- SC-005 PASS — kr 미러 9/9(run-all 검사 4·6·9).
- SC-006 PASS — ADR 0000/0001 MADR 형식; `specs/README.md`가 001(Approved)·002(Approved)를 스크립트 재생성으로 나열.
- SC-007 PASS — 위 Task 24.
- SC-008 PASS(Task 21 기준) — `docs/runbooks/spec-kit-upgrade.md` 존재; 내용은 이 세션에서 재검증하지 않음.
- SC-009 PASS — 원격에 `main`(Task 1)·`001-claude-setup`(ea7c658) push.

### 실행하지 않은 것
- `/speckit-converge`: 001은 `tasks.md`가 없는 부트스트랩 예외라 실행 불가 — plan `## 자기 검토`의 FR/SC/US → task 전수 매핑으로 대체(002는 converge 2회 실행).
- US4 AC3(환경 부재 → SKIP 보고)·AC4(FAIL → SDD 되돌림)는 002 E2E가 FAIL 0·SKIP 0이라 발동하지 않음(정적 근거: `tester.md` SKIP 규칙, plan Step 9). tester-write-guard의 세션 내 실제 deny도 발생하지 않음(tester가 파일을 쓰지 않음) — 하네스 8케이스·오프라인 실행으로 대체.
- CLI 화면 `/hooks`·`/agents`·`/skills`·`/plugin`의 육안 확인(설정·도구 목록으로 대체).
- `.specify/memory/` 통합(archive)과 main 머지·Done 표시는 Task 26 Step 3–6에서.
- 미러 동기화(US6): 001에서 변경된 에이전트 파일은 모두 미러가 있음(9/9). finish 리뷰(decisions)가 `docs/kr/CLAUDE_kr.md`에 `> translation-pending (2026-08-26)`가 남아 있고 Tool boundaries 문단이 name-only 이전 문구임을 발견 → 이 커밋에서 CLAUDE.md 현행(60줄)으로 미러를 재동기화하고 pending 표시를 제거. 002 머지분(AGENTS.md 행, CLAUDE.md SPECKIT 블록)은 이미 동기화됨. 그 외 동기화 대상 없음.
- 학습 노트: Task 22의 `content/study/001-claude-setup.mdx`를 그대로 인정하되 "결과와 검증" 문단을 실제 결과로 갱신(노트 자체가 예고한 갱신). CHANGELOG는 Task 21 항목 유지.

## Next
- Task 26 Step 3–6: `finishing-a-development-branch` 옵션 1(main 머지) → `git push origin main`, 원격 `001-claude-setup` 삭제 → `/speckit-archive-run` 001·002 → 두 spec Status `Done (2026-08-27)` → `scripts/update-specs-index.ps1` 재생성 → run-all → 커밋·push.
- SP-1: 스택 결정(Cloudflare 네이티브 / Python MSA / 하이브리드), ADR 0002(CI/CD 원칙 — 불변 아티팩트·Git 정본·pull 기반·CI 무자격증명·rollback=revert)를 런타임 트랙과 함께 작성; 연구 입력 `research/2026-08-26-cicd-policy-review.md` §7(테넌시 할당 확인 → repo 공개 여부 → 런타임 트랙 → web 호스팅 → DB).
- 이월(Tier 2): adrkit(spec-kit 버전 게이트 해제 시), selftest(카탈로그 등재 시); PSScriptAnalyzer 도입; run-all 소요 ≈37초(하네스 자식 pwsh 21회) — `-Quick` 분리 검토.
- 002 Next 이월: contracts/cli.md 문구(읽기 전용 메시지·정렬 문구), AGENTS.md Layout에 `scripts/`, T018 힌트 문구, pwsh 7.6.5 하한을 CLAUDE.md Prerequisites에 기재할지.
- 리스크: 게이트는 산출물 존재·경로 형태만 검사하므로 `finishing-a-development-branch` 밖의 수동 머지는 우회 가능(CLAUDE.md에 명시); `feature.json`은 체크아웃별 편의 파일이라 브랜치와 어긋나면 finish-gate가 deny한다(Task 26 Step 1에서 제거로 해결).
