# Spec Kit 업그레이드 런북 · 커스터마이즈 레지스터

## 설치 상태 (2026-09-04)
- CLI: `specify 1.0.2.dev0` — `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`(main `c58a848`, 2026-08-25). `uv 0.12.6`. 실행 파일 `~/.local/bin/specify.exe`(도구 셸에서는 PATH 앞에 추가).
- 프로젝트: 최초 `specify init --here --integration claude --script ps --non-interactive --force --ignore-agent-tools`; 이후 `specify integration install codex --script ps`로 Codex를 병행 설치. 설치 대상은 `claude`, `codex`이고 기본 통합은 `claude`.
- 확장: `git` 1.0.0(번들), `agent-context` 1.0.0(번들), `archive` 1.3.0(커뮤니티, https://github.com/stn1slv/spec-kit-archive — 아카이브 URL 검토 후 `--from` 설치)
- 미설치: `selftest`(1.0.2 카탈로그에 없음), `adrkit` 0.1.2(spec-kit >=0.13,<0.16 요구 → 1.0.x 호환 버전 출시 후 재검토; npm `@adrkit/cli` 필요; ADR 경로는 env `ADRKIT_DIR`)
- Claude와 Codex에 각각 설치된 `speckit-*` 스킬 17개: speckit-analyze, speckit-checklist, speckit-clarify, speckit-constitution, speckit-converge, speckit-implement, speckit-plan, speckit-specify, speckit-tasks, speckit-taskstoissues, speckit-git-commit, speckit-git-feature, speckit-git-initialize, speckit-git-remote, speckit-git-validate, speckit-agent-context-update, speckit-archive-run. Codex 위치는 `.agents/skills/`, Claude 위치는 `.claude/skills/`.
- Windows 훅 런타임 검증(2026-09-09): PATH의 Codex CLI 0.153.0과 전역 설치를 건드리지 않은 임시 0.153.4 실행에서 모두 native `command_execution`이 `PreToolUse`를 호출하지 않았다. handler 직접 테스트는 통과하지만 Windows 셸 차단의 E2E 증거는 아니다.

## 커스터마이즈 레지스터
Spec Kit이 관리하는 파일 중 프로젝트가 손댄 것과, 관리 파일 밖에서 Spec Kit 동작을 바꾸는 설정. 업그레이드 후 "재검증" 열을 전부 수행한다.

| 파일 | 원본 Spec Kit 버전 | 원본 경로 | 변경 이유 | 업그레이드 후 재검증 |
|---|---|---|---|---|
| `.specify/templates/overrides/tasks-template.md` | 1.0.2.dev0 | `templates/tasks-template.md` | 테스트 필수화 + 스토리별 E2E task(헌법 II) | `pwsh .specify/scripts/powershell/resolve-template.ps1 tasks-template` 출력에 `MANDATORY` 7건 이상, `OPTIONAL` 0건 |
| `.specify/memory/constitution.md` | 1.0.2.dev0 | `templates/constitution-template.md` | 프로젝트 헌법 본문 | 플레이스홀더 `[…]` 0건(`tests/run-all.ps1`) |
| `.specify/extensions/git/git-config.yml` | git ext 1.0.0 | `extensions/git/git-config.yml` | `commit_style: conventional` | `Select-String commit_style .specify/extensions/git/git-config.yml` → conventional |
| `.claude/settings.json` `skillOverrides` | — | (Claude Code 설정) | `speckit-*` 17개 name-only(설명 숨김, 자동 트리거 차단) | `tests/run-all.ps1`의 skillOverrides 검사 통과 |
| `.agents/skills/speckit-*` | 1.0.2.dev0 | Codex 통합 출력 | Claude 설정을 유지한 Codex 병행 통합 | `specify integration status`가 `claude, codex`와 오류 0건을 보고하고, `.agents/skills/`에 17개 디렉터리가 존재 |
| `.agents/skills/speckit-*/agents/openai.yaml` | — | (프로젝트 sidecar) | Codex에서도 Spec Kit 스킬을 명시적 `$speckit-*` 호출 전용으로 제한하며 관리 대상 `SKILL.md` 해시는 보존 | `pwsh -NoProfile -File scripts/sync-codex-skill-policies.ps1`; `pwsh -NoProfile -File tests/scripts/sync-codex-skill-policies.tests.ps1` |
| `.agents/skills/{approval-review,finish}/` | — | `.claude/skills/{approval-review,finish}/` 의미 대응 | Codex 네이티브 서브에이전트·사용자 확인·finish 게이트 어댑터; `boundaries/` 루브릭은 Claude 원본과 동일 | `pwsh -NoProfile -File tests/agents/codex-parity.tests.ps1` |
| `.codex/hooks.json`, `.codex/hooks/` | — | `.claude/settings.json`, `.claude/hooks/` 의미 대응 | Codex `UserPromptSubmit` 승인 안내, 전역 `PreToolUse` 파괴 명령 handler, `Stop` finish 게이트, tester `apply_patch` 쓰기 경계. Windows native shell dispatch 제한은 아래 주의사항 적용 | `pwsh -NoProfile -File tests/hooks/run-codex-hook-tests.ps1`; `pwsh -NoProfile -File tests/hooks/run-codex-command-policy-tests.ps1`; Codex에서 `/hooks`로 변경된 훅을 검토·신뢰 |
| `.codex/agents/*.toml`, `.codex/rules/*.rules` | — | `.claude/agents/*.md`, `.claude/settings.json` 의미 대응 | 공유 역할 본문을 읽는 Codex 서브에이전트와 직접 argv 위험 명령에 대한 심층 방어 | `pwsh -NoProfile -File tests/agents/codex-parity.tests.ps1`; `codex execpolicy check --pretty --rules .codex/rules/repository.rules git reset --hard HEAD~1` |
| `CLAUDE.md` `<!-- SPECKIT START/END -->` | agent-context ext 1.0.0 | — | plan 경로 관리 블록 | 마커 2개 존재, 블록 안에 최신 plan 경로 |
| `.specify/extensions/archive/` | archive 1.3.0 (community) | https://github.com/stn1slv/spec-kit-archive | 머지 후 `.specify/memory/{spec,plan,changelog}.md` 통합 | 스킬 `speckit-archive-run` 존재; Claude `/speckit-archive-run specs/<feature>`와 Codex `$speckit-archive-run specs/<feature>` 동작 |
| (보류) `adrkit` | 0.1.2 (community) | https://github.com/mbeacom/adrkit | ADR 컨텍스트·검토·초안 | 설치 시 `ADRKIT_DIR=docs/decisions` 환경 변수 규약 결정 후 레지스터 갱신 |

## 업그레이드 절차
1. `git status`가 깨끗한지 확인하고 브랜치 `chore/speckit-upgrade-<version>`을 만든다.
2. CLI: `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@<tag> --force` (또는 `uv tool upgrade specify-cli`).
3. 프로젝트: `specify upgrade` — **`--force`를 쓰지 않는다**(레지스터의 관리 파일이 덮인다). 충돌이 보고되면 `.specify/integrations/*.manifest.json` diff로 어떤 관리 파일이 바뀌었는지 확인한다.
4. 확장: `specify extension update`; adrkit 호환 버전이 나왔는지 `specify extension info adrkit`으로 확인한다. 확장 명령은 활성 통합에만 다시 렌더링되므로 `specify integration use codex` 후 `specify integration use claude`를 실행해 Codex 확장 스킬을 갱신하고 Claude를 기본 통합으로 복구한다. `switch`나 `--force`는 사용하지 않는다.
5. 렌더링이 끝난 뒤 `pwsh -NoProfile -File scripts/sync-codex-skill-policies.ps1`를 실행한다. 이 스크립트는 현재 발견되는 모든 `.agents/skills/speckit-*`에 명시 호출 정책 sidecar를 복원하며, Spec Kit이 관리하는 `SKILL.md`나 매니페스트는 수정하지 않는다.
6. 레지스터의 재검증 열을 모두 수행하고 `specify check`, Codex 훅·parity 테스트, `pwsh -NoProfile -File tests/run-all.ps1`을 통과시킨다. 전체 검사는 실제 OpenTofu/플랫폼 선행 조건을 요구할 수 있으므로 이 런북의 기존 운영 자격증명 절차 없이 우회하지 않는다.
7. `.codex/hooks.json` 또는 handler 내용이 바뀌었다면 trusted 프로젝트의 Codex 대화형 세션에서 `/hooks`를 열어 각 새 해시와 명령을 검토한 뒤 신뢰한다. 자동화에서만 `--dangerously-bypass-hook-trust`를 일회성으로 사용할 수 있으며, 이 옵션은 신뢰를 저장하지 않는다. 신뢰 승인은 훅 실행 허가일 뿐 이벤트 디스패치를 보장하지 않으므로, Windows에서는 아래 제한을 별도로 확인한다.
8. `CHANGELOG.md` Unreleased에 `Changed: Spec Kit <old> → <new>`를 적는다.
9. 커밋 `chore(speckit): <old> → <new> 업그레이드`, PR 또는 머지.

## Codex 병행 통합 빠른 검증

```powershell
specify integration status
pwsh -NoProfile -File scripts/sync-codex-skill-policies.ps1
pwsh -NoProfile -File tests/scripts/sync-codex-skill-policies.tests.ps1
pwsh -NoProfile -File tests/hooks/run-codex-hook-tests.ps1
pwsh -NoProfile -File tests/hooks/run-codex-command-policy-tests.ps1
pwsh -NoProfile -File tests/agents/codex-integration.tests.ps1
pwsh -NoProfile -File tests/agents/codex-parity.tests.ps1
codex execpolicy check --pretty --rules .codex/rules/repository.rules git reset --hard HEAD~1
```

마지막 명령의 `decision`은 `forbidden`이어야 한다. `.codex/rules`는 정확한 직접 argv prefix만 다루는 심층 방어다. command-policy handler는 compound command·래퍼·뒤쪽 force 옵션을 검사하지만, 위에서 기록한 Windows `command_execution` 경로에서는 Codex 0.153.4까지 `PreToolUse` 디스패치가 실측되지 않았으므로 강제 경계로 주장하지 않는다. 이 환경에서는 sandbox와 approvals를 유지하고 파괴 명령이나 중첩 셸을 Codex에 맡기지 않는다. Codex 훅은 프로젝트가 trusted여도 정의 해시별 신뢰가 별도이므로, 최초 설치와 훅 변경 뒤에는 대화형 `/hooks` 검토도 마친다.

## 롤백
`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@<old-ref> --force` 후 브랜치를 버린다(`.specify/`는 git이 추적하므로 체크아웃으로 복구된다).
