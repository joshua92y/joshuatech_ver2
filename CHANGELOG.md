# Changelog

이 프로젝트의 주목할 변경 사항을 기록한다. 형식은 [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/), 버전은 [SemVer](https://semver.org/)를 따른다.

## [Unreleased]

### Added
- `scripts/update-specs-index.ps1` — `specs/README.md` feature 인덱스 표를 각 `spec.md` 헤더에서 재생성(Status 정규화, `—` 결측 표시, 표 블록만 교체, fail-closed, 원자적·멱등 쓰기) + 자체 테스트 하네스 40 단언 + `tests/run-all.ps1` 검사 `scripts`·`specs-index-fresh` ([specs/002-smoke](specs/002-smoke/))
- SP-0 Claude Code 기반 셋팅 — Spec Kit 1.0.2(+ git·agent-context·archive 확장), 헌법 1.0.0, tester 에이전트, approval-review/finish 스킬, 훅 3종, 규칙 3종, 문서 정책(ADR·런북·kr 미러), 학습 노트 계약 ([specs/001-claude-setup](specs/001-claude-setup/))

### Changed
- `specs/README.md`를 스크립트로 재생성 — 001 행 우선순위 `🔴` → `—`(spec 헤더에 `**Priority**` 줄이 없음), 002 행 추가, 머리말 문구 갱신; `AGENTS.md` Commands 표의 인덱스 재생성 행에 복구 힌트 ([specs/002-smoke](specs/002-smoke/))
