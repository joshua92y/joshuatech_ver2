> 번역본(편의용). 정본은 영어 원본 `.claude/rules/specs.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "specs/**"
```

# `specs/` 규칙

- 기능 하나 = 불변 디렉터리 하나 `specs/NNN-slug/`, Spec Kit로 생성한다 (`/speckit-specify`, 또는 브레인스토밍이 스펙을 작성할 때는 `.specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json`). 기능 디렉터리는 절대 이름을 바꾸거나, 옮기거나, 삭제하지 않는다; 의도가 바뀌면 새 기능이다.
- `spec.md` 헤더의 `**Status**` 값: `Draft` → `Approved (YYYY-MM-DD)` → `Done (YYYY-MM-DD)`. `/approval-review`만 (사람이 확인한 뒤) Approved로 설정하고, 병합 후 아카이브 단계만 Done으로 설정한다.
- Spec Kit 파일들(`spec.md`, `plan.md`, `tasks.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/`, `checklists/`)은 Spec Kit 템플릿 제목 구조를 유지한다. 기능별 프로젝트 추가 파일:
  - `reviews/YYYY-MM-DD-approval.md` — 경계마다 한 섹션, `## 종합 의견`, `## 사용자 결정`.
  - `reviews/YYYY-MM-DD-finish.md` — 2번째 줄에 `Status: Approved | Issues`, 경계마다 한 섹션, `## Issues`.
  - `report.md` — `# Report NNN-slug` / `## Summary` / `## Changes Made` / `## Validation` / `## Next`.
- `specs/README.md`는 각 `spec.md` 헤더로부터 재생성되는 색인 표(번호, 기능, Status, 우선순위, 링크)다. 헤더를 바꾼 다음 재생성한다; 표만 편집하지 않는다.
- 승인 후 `spec.md`, `plan.md`, `tasks.md`는 구현자에게 읽기 전용 입력이다. 허용되는 편집: `tasks.md`의 체크박스(`[X]`)와 `/speckit-converge`가 추가하는 단계.
- 서브에이전트에 작업을 위임할 때는 해당 작업 줄과 관련된 spec/plan 섹션만 전달한다 — 기능 디렉터리 전체를 전달하지 않는다.
- 산문은 한국어로; 식별자, 슬러그, 파일명은 영어/ASCII로.
