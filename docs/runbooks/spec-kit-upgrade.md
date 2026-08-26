# Spec Kit 업그레이드 런북 · 커스터마이즈 레지스터

## 설치 상태 (2026-08-26)
- CLI: `specify 1.0.2.dev0` — `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git`(main `c58a848`, 2026-08-25). `uv 0.12.6`. 실행 파일 `~/.local/bin/specify.exe`(도구 셸에서는 PATH 앞에 추가).
- 프로젝트: `specify init --here --integration claude --script ps --non-interactive --force --ignore-agent-tools`
- 확장: `git` 1.0.0(번들), `agent-context` 1.0.0(번들), `archive` 1.3.0(커뮤니티, https://github.com/stn1slv/spec-kit-archive — 아카이브 URL 검토 후 `--from` 설치)
- 미설치: `selftest`(1.0.2 카탈로그에 없음), `adrkit` 0.1.2(spec-kit >=0.13,<0.16 요구 → 1.0.x 호환 버전 출시 후 재검토; npm `@adrkit/cli` 필요; ADR 경로는 env `ADRKIT_DIR`)
- 설치된 `speckit-*` 스킬 17개: speckit-analyze, speckit-checklist, speckit-clarify, speckit-constitution, speckit-converge, speckit-implement, speckit-plan, speckit-specify, speckit-tasks, speckit-taskstoissues, speckit-git-commit, speckit-git-feature, speckit-git-initialize, speckit-git-remote, speckit-git-validate, speckit-agent-context-update, speckit-archive-run

## 커스터마이즈 레지스터
Spec Kit이 관리하는 파일 중 프로젝트가 손댄 것과, 관리 파일 밖에서 Spec Kit 동작을 바꾸는 설정. 업그레이드 후 "재검증" 열을 전부 수행한다.

| 파일 | 원본 Spec Kit 버전 | 원본 경로 | 변경 이유 | 업그레이드 후 재검증 |
|---|---|---|---|---|
| `.specify/templates/overrides/tasks-template.md` | 1.0.2.dev0 | `templates/tasks-template.md` | 테스트 필수화 + 스토리별 E2E task(헌법 II) | `pwsh .specify/scripts/powershell/resolve-template.ps1 tasks-template` 출력에 `MANDATORY` 7건 이상, `OPTIONAL` 0건 |
| `.specify/memory/constitution.md` | 1.0.2.dev0 | `templates/constitution-template.md` | 프로젝트 헌법 본문 | 플레이스홀더 `[…]` 0건(`tests/run-all.ps1`) |
| `.specify/extensions/git/git-config.yml` | git ext 1.0.0 | `extensions/git/git-config.yml` | `commit_style: conventional` | `Select-String commit_style .specify/extensions/git/git-config.yml` → conventional |
| `.claude/settings.json` `skillOverrides` | — | (Claude Code 설정) | `speckit-*` 17개 명시 호출 전용 | `tests/run-all.ps1`의 skillOverrides 검사 통과 |
| `CLAUDE.md` `<!-- SPECKIT START/END -->` | agent-context ext 1.0.0 | — | plan 경로 관리 블록 | 마커 2개 존재, 블록 안에 최신 plan 경로 |
| `.specify/extensions/archive/` | archive 1.3.0 (community) | https://github.com/stn1slv/spec-kit-archive | 머지 후 `.specify/memory/{spec,plan,changelog}.md` 통합 | 스킬 `speckit-archive-run` 존재; `/speckit-archive-run specs/<feature>` 동작 |
| (보류) `adrkit` | 0.1.2 (community) | https://github.com/mbeacom/adrkit | ADR 컨텍스트·검토·초안 | 설치 시 `ADRKIT_DIR=docs/decisions` 환경 변수 규약 결정 후 레지스터 갱신 |

## 업그레이드 절차
1. `git status`가 깨끗한지 확인하고 브랜치 `chore/speckit-upgrade-<version>`을 만든다.
2. CLI: `uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@<tag> --force` (또는 `uv tool upgrade specify-cli`).
3. 프로젝트: `specify upgrade` — **`--force`를 쓰지 않는다**(레지스터의 관리 파일이 덮인다). 충돌이 보고되면 `.specify/integrations/*.manifest.json` diff로 어떤 관리 파일이 바뀌었는지 확인한다.
4. 확장: `specify extension update`; adrkit 호환 버전이 나왔는지 `specify extension info adrkit`으로 확인한다.
5. 레지스터의 재검증 열을 모두 수행하고 `specify check`와 `pwsh -NoProfile -File tests/run-all.ps1`을 통과시킨다.
6. `CHANGELOG.md` Unreleased에 `Changed: Spec Kit <old> → <new>`를 적는다.
7. 커밋 `chore(speckit): <old> → <new> 업그레이드`, PR 또는 머지.

## 롤백
`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@<old-ref> --force` 후 브랜치를 버린다(`.specify/`는 git이 추적하므로 체크아웃으로 복구된다).
