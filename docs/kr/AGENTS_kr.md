> 번역본(편의용). 정본은 영어 원본 `AGENTS.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

# AGENTS.md — JoshuaTech v2

## Project
처음부터 다시 만든 개발자 포트폴리오 플랫폼(v1: `d:\code\joshuatech`). SaaS급 규율과 멀티테넌트 대응 가능한 경계를 갖추고 운영되며, 자신의 학습 노트를 직접 공개한다(learning in public). **현재 상태(SP-1 / feature 003): 플랫폼 기반 작업이 진행 중이며 애플리케이션·패키지·템플릿·인프라·E2E 트리가 존재한다. 스택은 ADR 0002–0010에 기록되어 있다.**

## Active agent integration
Spec Kit 통합 대상은 `claude`(`.claude/skills/speckit-*` 아래의 스킬)와 `codex`(`.agents/skills/speckit-*` 아래의 스킬)이며, 기본 통합은 계속 `claude`다. Codex는 이 파일, `.specify/memory/constitution.md`, `specs/<feature>/`를 읽는다. `.claude/settings.json`, 훅, 규칙, 에이전트를 자동으로 상속하지는 않으며, 아래 어댑터가 공유 Markdown 본문을 명시적으로 재사용하고 Claude 동작은 그대로 둔 채 Codex 고유 배선을 제공한다. 다른 에이전트(Gemini 등)는 워크플로우를 수동으로 따른다. 모든 에이전트는 승인된 `spec.md`, `plan.md`, `tasks.md`를 절대 수정해서는 안 된다.

## Adapter boundaries
- 기존 Claude 설정을 보존한다. `.claude/settings.json`, `.claude/hooks/`, Claude 스킬 override, Claude 플러그인 설정은 계속 Claude Code의 정본이며, Codex 어댑터는 이를 대체하거나 다시 쓰지 않고 보완한다.
- `.agents/skills/`에는 Codex가 발견하는 스킬을 둔다. `.codex/hooks.json`과 `.codex/hooks/`에는 Codex 훅 배선과 핸들러를, `.codex/agents/*.toml`에는 Codex 서브에이전트 어댑터를, `.codex/rules/*.rules`에는 명령 실행 정책만 둔다.
- `.claude/agents/*.md`에서는 frontmatter 아래의 Markdown 본문이 Claude와 Codex가 공유하는 역할 계약의 정본이다. YAML frontmatter(`tools`, `skills`, `hooks`)는 Claude 전용이다. `.codex/agents/*.toml`은 Claude 전용 YAML 동작을 그대로 복사하지 말고 본문과 의미상 동기화한다.
- Codex 훅과 에이전트는 Codex 고유 도구 이름과 payload를 사용한다. 승인 컨텍스트는 fail-open일 수 있지만, 파괴 명령 정책, finish 준비 게이트, tester 쓰기 가드는 디스패치된 경우 반드시 fail-closed여야 한다. 보호 대상 입력이 깨졌거나 모호한 경우, 경로를 해석할 수 없거나 저장소 밖인 경우, 테스트가 아닌 경로에 쓰려는 경우 모두 거부한다.
- tester의 강제 쓰기 가드는 `apply_patch` 대상만 다룬다. tester는 셸 명령이나 다른 도구로 파일을 쓰면 안 되며, agent-local 훅이 비활성 또는 미신뢰 상태이면 읽기 전용 검증만 수행하고 가드가 없음을 보고한다. finish `Stop` 훅은 `$finish` 준비 마커만 검사하며 직접 merge나 push를 가로채지 못하므로, 문서화된 branch-finishing 워크플로 밖의 직접 통합은 계속 금지한다.
- `.codex/rules/*.rules`는 직접 argv에 대한 심층 방어를 제공하고, 동기식 전역 `PreToolUse` `^Bash$` 핸들러는 복합 명령, 옵션 위치, 실행 파일 경로, 지원하는 셸 래퍼를 검사하도록 배선되어 있다. 어느 쪽도 산문 지침을 로드하거나 아래의 경로 라우터를 대체하지 않는다. 새 훅이나 변경된 훅은 `/hooks`에서 검토하고 신뢰하기 전까지 비활성이다.
- 2026-09-09에 확인한 Windows 제한: 훅 신뢰를 일회성으로 우회해도 Codex CLI 0.153.0과 임시 0.153.4 실행 모두에서 native `command_execution`이 `PreToolUse`를 디스패치하지 않았다. 따라서 command-policy 핸들러의 contract 테스트 통과와 `/hooks` 신뢰만으로 Windows 셸의 강제 경계가 생기지는 않는다. sandbox와 approvals를 계속 켜고, `.codex/rules`는 정확히 일치하는 직접 prefix에만 의존하며, 중첩 셸과 파괴 명령 형식을 사용하지 않는다. Codex 업데이트 후 이 제한을 지우기 전에 비파괴 runtime dispatch smoke test를 다시 수행한다.

## Codex skill argument binding
`$ARGUMENTS`가 있는 Codex 스킬은 triggering 사용자 메시지에서 값을 얻는다. 활성 `$speckit-*` 호출을 찾고 스킬 이름 뒤의 정확한 나머지를 바인딩하며, 따옴표와 flags를 입력 그대로 보존한다. 나머지가 없으면 빈 문자열을 바인딩한다. `$ARGUMENTS`라는 literal token 자체는 입력이 아니며 스크립트나 자식 스킬에 전달해서는 안 된다.

Nested Spec Kit hooks도 같은 바인딩 규칙을 따른다. 자식에게 명시적으로 준 인자가 우선하며(explicit child arguments win), 그렇지 않으면 자식은 상위 워크플로에 바인딩된 인자를 상속한다. 특히 `$speckit-specify`의 `before_specify`가 `$speckit-git-feature`를 호출하면서 별도 인자를 주지 않으면 상위 워크플로의 기능 설명과 flags를 상속한다.

`.specify/extensions.yml`에 `speckit.foo` 같은 dotted command가 있으면 점을 하이픈으로 바꿔 `$speckit-foo`(일반형 `$speckit-<name>`)로 매핑한다. 대응하는 `.agents/skills/speckit-foo/SKILL.md`를 끝까지 읽은 뒤 같은 턴에 실행한다. 호출 문자열만 표시한 것은 실행이 아니다. `/{command}`, bare `EXECUTE_COMMAND:` placeholder, `/skill:`은 legacy renderer 형식이므로 실행해서는 안 된다.

## Path-scoped rule routing
Codex는 `.claude/rules/*.md`의 `paths:` YAML을 해석하지 않는다. 경로를 편집하기 전에 아래에서 일치하는 모든 규칙 파일을 끝까지 읽고 전부 적용한다. 테스트 파일을 편집할 때는 테스트 경로 자체가 아래 glob과 일치하지 않더라도, 그 테스트가 검증하는 production 경로나 contract에 일치하는 규칙도 모두 읽는다.

| 정본 규칙 | 일치 경로 |
|---|---|
| `.claude/rules/content.md` | `content/**` |
| `.claude/rules/django-pod.md` | `apps/*/pyproject.toml`, `apps/*/*.py`, `apps/*/**/*.py`, `apps/*/Dockerfile`, `packages/django-common/**`, `templates/django-pod/**` |
| `.claude/rules/docs.md` | `docs/**` |
| `.claude/rules/events.md` | `packages/events/**` |
| `.claude/rules/fastapi-pod.md` | `templates/fastapi-pod/**`, `packages/fastapi-common/**` |
| `.claude/rules/infra.md` | `infra/**`, `scripts/**` |
| `.claude/rules/specs.md` | `specs/**` |
| `.claude/rules/web.md` | `apps/web/**`, `packages/content/**` |

## Commands
| 목적 | 명령어 |
|---|---|
| 기능 디렉터리 할당(브레인스토밍 경로) | `pwsh .specify/scripts/powershell/create-new-feature.ps1 -ShortName <slug> -Json` |
| 기능 경로 / 사전 조건 | `pwsh .specify/scripts/powershell/check-prerequisites.ps1 -Json` |
| Claude 훅 단위 테스트 | `pwsh -NoProfile -File tests/hooks/run-hook-tests.ps1` |
| Codex 훅 단위 테스트 | `pwsh -NoProfile -File tests/hooks/run-codex-hook-tests.ps1` |
| Codex 파괴 명령 핸들러 contract | `pwsh -NoProfile -File tests/hooks/run-codex-command-policy-tests.ps1` |
| Codex 어댑터 동등성 | `pwsh -NoProfile -File tests/agents/codex-parity.tests.ps1` |
| 전체 저장소 점검 | `pwsh -NoProfile -File tests/run-all.ps1` |
| `specs/README.md` 재생성 | `pwsh -NoProfile -File scripts/update-specs-index.ps1` — run-all `scripts`/`specs-index-fresh`가 FAIL이면 실행 후 `specs/README.md`를 커밋; `error: <dir>/spec.md: …`이면 해당 spec 헤더를 고치고 재실행 |
| Spec Kit CLI(초기화 / 업그레이드 / 확장) | `~/.local/bin`의 `specify`(`uv`로 설치); 절차는 `docs/runbooks/spec-kit-upgrade.md` |

## Layout
```
.specify/        Spec Kit 런타임: memory/constitution.md, templates/ (+overrides/), scripts/powershell/, extensions/, feature.json (로컬 전용)
.agents/         Codex 저장소 스킬(Spec Kit + 프로젝트 gate)
.claude/         Claude 레이어: settings.json, skills/, agents/tester.md, rules/, hooks/
.codex/          Codex 어댑터: hooks.json, hooks/, agents/*.toml, rules/*.rules (명령 정책 전용)
apps/            애플리케이션 코드: web(Next.js) + Django pod별 디렉터리 하나씩
packages/        공유 JS/Py 패키지: events(스키마), django-common, content
templates/       copier pod 템플릿(django-pod)
infra/           OpenTofu 모듈(oci·cloudflare·vault·grafana) + 부트스트랩 스크립트
e2e/             앱 경계를 가로지르는 엔드투엔드 테스트
specs/           기능(NNN-slug)마다 하나씩 존재하는 불변 디렉터리 + README.md 색인
docs/            README.md 색인, decisions/ (MADR), runbooks/, kr/ (한국어 미러)
content/study/   사이트가 사용하는 학습 노트(.mdx)
content/tmp/     task별 학습 로그(노트의 준비 단계; 게시하지 않으며 증류되면 삭제)
tests/           훅 테스트 및 저장소 점검
```

## Conventions
- 브랜치 = 기능 디렉터리 이름(`NNN-slug`), Spec Kit git 확장이 생성; `main`은 통합 전용; 워크트리는 `.worktrees/` 아래에 둔다.
- 커밋: Conventional Commits, 한국어 설명 허용(`feat(scope): 설명`); 태스크당 커밋 하나; 강제 푸시나 공유 이력 재작성 금지.
- 파일: UTF-8, LF, ASCII kebab-case 이름. spec, docs, 노트에는 한국어 산문; 에이전트 파일과 코드 식별자에는 영어.
- 테스트 우선(constitution II). 테스트 파일은 `tests/`, `e2e/`, `__tests__/` 아래에 두거나 `*.test.*` / `*.spec.*`로 명명한다.
- 비밀 정보(secrets)는 저장소에 절대 포함하지 않는다.
- 학습 로그: task가 닫힐 때(여러 날에 걸친 task는 세션이 끝날 때마다) `.claude/rules/content.md`에 따라 그날의 항목을 `content/tmp/<NNN>-t<NNN>/<YYYY-MM-DD>.md`에 덧붙인다; task 단위 설계 문서는 `specs/<feature>/design/` 아래에 보존한다.

## Workflow (short form)
specify → clarify → plan → checklist → tasks → approval-review → build (TDD, subagent-driven) → converge → E2E (tester) → finish → finishing branch → merge → archive. 세부 사항: `CLAUDE.md`와 constitution 참고.

Spec Kit은 WHAT, 즉 constitution, feature spec, plan, tasks, analyze, converge, archive를 소유한다. 활성 에이전트 워크플로는 HOW, 즉 TDD, 범위가 제한된 서브에이전트, 리뷰, 검증, worktree, branch finishing을 소유한다. 프로젝트 고유 approval, E2E, finish, 명령 정책, 쓰기 범위 gate는 런타임이 디스패치하는 범위에서 이 경계를 강제하며, 문서화한 Windows 셸 제한이 적용된다. `$speckit-implement`는 사용하지 않고 승인된 `tasks.md`를 TDD/subagent 워크플로로 실행한다. `superpowers:writing-plans`도 사용하지 않으며 `tasks.md`만 유일한 구현 계획이다. 승인된 `spec.md`, `plan.md`, `tasks.md`는 불변 입력이다.
