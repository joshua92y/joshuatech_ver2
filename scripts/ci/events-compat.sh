#!/usr/bin/env bash
# events-compat.sh — packages/events 스키마 호환성 게이트(T067 · .github/workflows/ci.yml job events-compat)
#
# 목적
#   변경 쪽(CI = HEAD 커밋 · 로컬 = 작업 트리)의 packages/events/schemas를 기준 커밋의 스키마와 비교해, 호환성 규칙(contracts/events.md
#   §호환성 규칙 — 필드 삭제 · 이름 변경 · 타입 변경 · required 추가 · 제거 · enum 값 삭제 · 스키마 파일 삭제 금지)을 어기면 실패한다.
#   판정은 packages/events/scripts/check-compat.mjs CLI가 하고, 이 스크립트는 기준을 정하고 기준 · 변경 쪽 스키마와 기준 쪽 검사기를
#   꺼내 돌린 뒤 종료 코드를 전한다. 판정 · 기준 규칙의 정본은 이 머리 주석이다(contracts/events.md §호환성 규칙 「CI 기준과 검사기」가
#   가리킨다).
#
# 사용
#   bash scripts/ci/events-compat.sh [--root <dir>] [--base <commit>]
#     --root <dir>     검사할 git 작업 트리의 최상위(기본: 이 스크립트에서 두 단계 위). 작업 트리가 아니거나 최상위가 아니면 2.
#     --base <commit>  기준 커밋을 직접 준다(로컬 확인용 — 예: --base origin/main). 주면 아래 이벤트 규칙을 쓰지 않는다.
#   환경 변수(--base가 없을 때 — GitHub Actions)
#     GITHUB_EVENT_NAME    pull_request · push만 받는다. 그 밖(없음 포함)은 2.
#     PR_HEAD_SHA          pull_request의 PR head 커밋(github.event.pull_request.head.sha) — 소문자 40/64-hex
#     PUSH_BEFORE          push의 이전 커밋(github.event.before) — 소문자 40/64-hex, 0만이면 새 브랜치
#   환경 변수(언제나)
#     GITHUB_ACTIONS · GITHUB_SHA  GITHUB_ACTIONS가 true이면(--base와 무관) CI 실행이다 — GITHUB_SHA가 소문자 40/64-hex이고 HEAD
#                          커밋과 같아야 하고(아니면 2 — 체크아웃이 이 이벤트의 커밋이 아니다 · ci.yml job gitleaks와 같은 확인), 변경
#                          쪽을 그 커밋 객체에서 읽는다(아래 「변경 쪽 스키마」).
#     GITHUB_STEP_SUMMARY  있으면 끝에 세 줄(기준 · 검사기 · 결과 · exit)을 덧붙인다 — 일찍 멈춰도 쓴다.
#     TMPDIR               작업 디렉터리(mktemp -d)를 만들 곳(없으면 /tmp).
#
# 기준(baseline) 규칙
#   pull_request  체크아웃 = GitHub의 PR merge 커밋. PR_HEAD_SHA가 소문자 40/64-hex이고 HEAD^2와 같아야 한다 — 다르거나 HEAD가 merge
#                 커밋이 아니면 2(전제: merge ref는 부모 둘 = 첫째 base 끝 · 둘째 PR head). 기준 = HEAD^1(base 브랜치 끝).
#   push          PUSH_BEFORE가 0만(40 · 64자)이면 빈 기준(새 브랜치 — 스키마는 전부 추가). 아니면 소문자 40/64-hex이고 이 저장소에
#                 있는 커밋이어야 한다(없으면 2 — checkout fetch-depth: 0 전제). 기준 = before.
#   --base        그 커밋(git rev-parse --verify --end-of-options <값>^{commit} — 커밋이 아니면 2).
#
# 커밋 트리 읽기 — 기준 커밋과 (CI의) HEAD 커밋을 같은 함수로 읽는다: git ls-tree + git cat-file blob만(사유에 쪽을 적는다)
#   커밋의 루트 트리(git rev-parse <커밋>^{tree})에서 경로 성분마다 git ls-tree <트리> -- <성분>으로 한 단계씩 내려간다. 성분의 결과는
#   없음 · 트리 · 일반 파일(blob 100644 · 100755) · 그 밖(120000 심볼릭 링크 · 160000 gitlink 등)이다. 중간 성분이 없으면 경로 전체가
#   없음, 중간 성분이 트리가 아니면 2(사유에 쪽 · 접두 · mode). git 명령이 실패하면(손상되었거나 없는 객체 포함) 언제나 2다 —
#   "없음"으로 보지 않는다. git archive는 쓰지 않는다(트리의 .gitattributes export-ignore 한 줄이 머지되면 이후 기준이 빈다 ·
#   export-subst · 필터도 내용을 바꾼다). git은 replace ref를 따르지 않고(GIT_NO_REPLACE_OBJECTS=1) pathspec을 글자 그대로
#   읽는다(GIT_LITERAL_PATHSPECS=1).
#   스키마 디렉터리  packages/events/schemas가 없음 → 빈 디렉터리 · 트리가 아님 → 2 · 트리 → git ls-tree -z로 나열한다. 이름이 .json으로
#                    끝나는 항목은 일반 파일 blob이고 이름이 ^[A-Za-z0-9_][A-Za-z0-9._-]*\.json$이어야 한다(아니면 2) — git cat-file
#                    blob으로 작업 디렉터리에 꺼낸다(실패하면 2). .json이 아닌 항목(.gitattributes · README 등)은 무시한다.
#
# 기준 스키마 · 검사기
#   기준 스키마  기준 커밋의 packages/events/schemas(위 「커밋 트리 읽기」 — 없으면 빈 디렉터리 · 전부 추가로 본다).
#   기준 검사기  기준 커밋의 packages/events/scripts/check-compat.mjs가 일반 파일 → 그 blob을 작업 디렉터리(패키지 밖 · node_modules
#                없음)에 꺼내 쓴다 — PR이 검사기를 약하게 고쳐 같은 PR의 스키마 변경을 통과시키지 못하게. 그 밖의 형식 → 2.
#                없음 → 부트스트랩 조건: 기준에 검사기도 스키마도 없을 때만(기준 스키마 .json 0개) 변경 쪽의 check-compat.mjs를 쓴다
#                (CI = HEAD 커밋의 blob을 같은 함수로 꺼낸다 · 로컬 = 작업 트리 — 경로의 모양은 아래 「다음 기준의 모양」이 먼저 본다 ·
#                변경 쪽에도 검사기가 없으면 2 · 출력에 부트스트랩이라고 적는다). 기준에 스키마가 있는데 검사기가 없으면 2(검사기를 지운
#                변경이 머지됐을 수 있다 — 다음 PR이 제 검사기로 돌게 두지 않는다). 그래서 검사기의 CLI 경로는 Node 내장 모듈만 쓴다.
#
# 변경 쪽 스키마
#   CI(GITHUB_ACTIONS=true)  HEAD 커밋(= GITHUB_SHA)의 트리에서 기준 쪽과 같은 함수로 꺼낸다(위 「커밋 트리 읽기」 — 없으면 빈 디렉터리).
#     작업 트리는 체크아웃이 PR의 .gitattributes(working-tree-encoding · ident · eol)로 바꾼 바이트일 수 있어 머지되는 blob과 다를 수
#     있다. 그래서 작업 트리의 스키마도 그 blob과 바이트가 같아야 한다: 작업 트리 packages/events/schemas 바로 아래에서 이름이 .json으로
#     끝나는 항목(일반 파일 · 링크 · 디렉터리 — 점으로 시작하는 이름 포함)의 집합이 HEAD 커밋의 .json 집합과 같고, 하나하나 심볼릭
#     링크가 아닌 일반 파일이며 git hash-object --no-filters(속성 · 필터를 거치지 않는다 · -w 없음)가 그 blob oid와 같아야 한다 —
#     아니면 2(소비자의 체크아웃이 검사한 것과 다른 내용을 읽는다 · 캐시 복원처럼 작업 트리만 바꾼 경로도 여기서 막힌다).
#   로컬(CI 밖)  작업 트리 packages/events/schemas를 그대로 읽는다. 이름이 .json으로 끝나는 항목은 이름이 위 꼴이고 심볼릭 링크가 아닌
#     일반 파일이어야 한다(아니면 2).
#   두 경우 모두 작업 트리의 packages · packages/events · packages/events/schemas 중 하나라도 심볼릭 링크면 2(따라가지 않는다), 있는데
#   디렉터리가 아니면 2. 없으면 빈 디렉터리 — 디렉터리 삭제는 기준 스키마 전부의 schema-removed(exit 1)이지 사용 오류가 아니다.
#
# 다음 기준의 모양
#   변경 쪽은 머지되면 다음 기준이 된다 — 그 트리가 기준 꺼내기에서 2가 되는 모양이면 머지 전에 2로 막는다(머지된 뒤에는 되돌리는 PR까지
#   2로 막힌다). 스키마 .json의 모양 · 이름은 위 「변경 쪽 스키마」가 본다(CI는 같은 함수가 강제한다). 변경 쪽 검사기 경로
#   packages/events/scripts/check-compat.mjs는 기준 쪽처럼 스키마 수와 상관없이 본다(CI = HEAD 트리에서 같은 함수로 · 로컬 = 작업 트리에서
#   심볼릭 링크를 따라가지 않고): 경로 성분이 디렉터리가 아니거나 검사기가 일반 파일이 아니면(심볼릭 링크 · gitlink) 2, 검사기가 없는 것은
#   변경 쪽에 스키마 .json이 하나라도 있을 때만 2다(스키마도 검사기도 없는 트리는 다음 기준에서 부트스트랩 조건을 만족한다). 기준 쪽
#   검사기를 쓰는 평소 경로에서도 검사기 실행 전에 본다.
#
# 신뢰 모델과 한계
#   job events-compat의 스텝은 Node 설치(체크아웃 전 · 빈 작업 공간) → 체크아웃 → 이 스크립트 순서이고, 체크아웃 뒤에 도는 것은 게이트
#   스크립트 하나뿐이다. PR 코드(의존성 설치 · vitest · 테스트가 import하는 PR의 검사기)는 job events-test에서 돈다 — 같은 러너에서
#   게이트보다 먼저 도는 PR 코드는 이 스크립트 · git 객체 · 속성 · 다음 스텝의 환경을 바꿀 수 있다. 예외는 부트스트랩뿐이다 — 이 스크립트
#   안에서 변경 쪽 검사기가 돌지만 기준이 비어 지킬 것이 없다.
#   Node 설치가 체크아웃보다 먼저인 까닭: setup-node(v6.5.0)는 설치 뒤 작업 공간을 cwd로 node · npm · yarn --version을 돌리고, 러너의
#   Yarn 1은 --version을 처리하기 전에 cwd와 그 위 디렉터리의 .yarnrc · .yarnrc.yml에 적힌 yarnPath를 실행한다 — 체크아웃 뒤라면 게이트
#   파일을 하나도 바꾸지 않은 PR(.yarnrc.yml + 스크립트 하나)이 게이트보다 먼저 같은 러너에서 코드를 돌린다. 그래서 Node 버전은 ci.yml의
#   고정값(node-version)이고 PR 내용에서 읽지 않는다. 그 값은 .node-version과 같아야 한다 — CI에서는 job events-test의 schemas.test.mjs
#   sch-23이, 로컬에서는 하네스 st-5 · st-15가 지킨다(둘이 갈라진 채 검사기가 새 판에만 있는 Node API를 쓰면 머지 뒤 게이트가 그 검사기를
#   옛 Node로 돌려 교착이 된다). 이 검사들은 줄 단위 드리프트 검사다 — 실수로 갈라진 값 · 옮겨진 핀 · 늘어난 setup-node 스텝을 잡는다.
#   YAML 이어짐 줄 · 이스케이프 · 별칭 · 가짜 job 블록처럼 ci.yml을 일부러 꼬아 쓰는 편집은 이 검사의 범위가 아니다 — ci.yml을 고치는 PR은
#   게이트를 통째로 바꿀 수도 있으므로, 그런 편집은 아래 「한계」대로 게이트 파일 리뷰(코드 소유자)가 막는다.
#   이 보호는 GitHub 호스티드 러너(job마다 새 VM — 체크아웃 전 작업 공간이 비어 있다)를 전제한다 — 작업
#   공간을 재사용하는 자체 호스티드 러너면 이전 job이 체크아웃한 PR 파일을 체크아웃 전 탐침이 실행할 수 있어 이 보호는 무효다. 캐시 없음:
#   setup-node에 cache 입력이 없고 package-manager-cache: false다(setup-node는 cache가 없어도 체크아웃의 package.json이 npm을 가리키면
#   자동 캐시를 켜고 복원 경로는 체크아웃의 .npmrc가 고른다 — 같은 PR의 이전 실행이 저장한 디렉터리가 게이트 앞에 풀린다 · 체크아웃 전이라
#   읽을 package.json이 없어도 심층 방어로 둔다).
#   GitHub의 pull_request는 PR 브랜치의 워크플로 정의로 돈다 — 같은 PR이 .github/workflows/ci.yml이나 이 스크립트를 바꾸면 그 PR에서는
#   바뀐 것이 돈다(이 스크립트는 체크아웃이 PR의 .gitattributes로 바꾼 바이트로 돈다 — 같은 한계). 게이트 job이 PR 내용에서 읽는 것은
#   이 둘뿐이고(Node 버전은 ci.yml의 고정값), 스키마 · 검사기는 커밋 객체에서 읽는다(작업 트리의 스키마는 바이트 대조에만 쓴다). 또 게이트
#   파일(ci.yml · 이 스크립트 · check-compat.mjs)의 변경은 머지되면 그 뒤 모든 PR의 게이트가 된다 — 기준 쪽 검사기 규칙은 같은 PR 안의
#   약화만 막는다(검사기를 약하게 고친 PR 자체는 스키마를 바꾸지 않으면 통과한다). 검사기를 더 엄격하게 하거나 잘못 고친 변경도 머지되면
#   그것이 기준 쪽 검사기가 되어 기준 스키마에서 2(또는 거짓 위반 1)로 끝나고, 되돌리는 PR까지 이후 모든 PR이 막힌다. 복구는 게이트
#   스크립트를 함께 고친 PR이 먼저다(그 PR에서는 그 PR의 스크립트가 돈다 — 코드 소유자 리뷰 · 뒤에 스크립트를 원래대로 돌리는 PR이 하나 더
#   필요). required check를 비켜 가는 운영자 머지는 같은 ruleset의 다른 required check까지 비켜 가므로 마지막 수단이다. 머지 전에는 job
#   events-test가 잡는다: 패키지 밖 검사기 사본으로 실제 스키마를 자기 자신 · 빈 기준과 비교(schemas.test.mjs sch-14 — 머지 뒤 게이트가
#   이 스크립트로 기준 쪽 사본을 돌리는 조건과 같다) · 요약 줄(sch-21) · CLI 경로의 Node 내장 모듈 자립(sch-9) · 게이트 Node 고정값 =
#   .node-version(sch-23). 패키지 밖 사본은 NODE_PATH · NODE_OPTIONS를 지운 env로 돌고, 그 env에서 사본 위치가 ajv를 해석하지 못함을
#   sch-24가 먼저 확인한다 — pnpm의 vitest 실행 shim이 NODE_PATH에 .pnpm/node_modules(ajv가 호이스트된 곳)를 넣어, 그대로 물려주면 사본이
#   ajv를 찾아 게이트 조건(node_modules 없음)을 재현하지 못한다. 단 events-test가 그 시험을 실제로 돌릴 때만이다 — 시험 실행 경로(시험
#   파일 · packages/events/package.json의 test 스크립트 · vitest 설정 · 루트 pnpm-workspace.yaml · package.json · pnpm-lock.yaml ·
#   .npmrc(pnpm node-options 등) · .pnpmfile.cjs 등 events-test가 읽는 pnpm · vitest 설정과 훅 파일 — events-test는 PR 코드를 도는 job이라
#   이 목록은 닫힌 목록이 아니다)를 바꾸는 변경(앞선 PR 포함)은 이 방어를 끌 수 있다. events-test 명령은 pnpm --filter @jt/events
#   --fail-if-no-match test다 — 걸러 낸 프로젝트가 없으면 pnpm이 exit 0으로 끝나므로, 워크스페이스에서 packages/events를 빼는 변경이 빈
#   통과가 되지 않게 한다. 그래서 이 파일들의 변경은 리뷰가 막는다 — 운영자 인계: packages/events/ · scripts/ci/ · .github/workflows/ ·
#   모든 깊이의 .gitattributes · 루트 pnpm-workspace.yaml · package.json · pnpm-lock.yaml · .npmrc · .pnpmfile.cjs(아직 없는 경로도 지정할
#   수 있다) · .github/CODEOWNERS 자신에 CODEOWNERS · 코드 소유자 리뷰 필수 · events-compat · events-test를 ruleset(main)의 required check로
#   지정(교착 방어가 events-test에 기댄다).
#
# 실행 · 종료 코드 · 검사기 출력 계약
#   node <검사기> --base <기준 dir> --head <변경 쪽 dir> — stdout은 작업 디렉터리의 out, stderr는 err로 받는다. 검사기 CLI 계약
#   (check-compat.mjs 머리 주석 · contracts/events.md 「검사기 출력 계약」): 0 · 1로 끝날 때 stderr에 요약 줄
#   "check-compat: checked N · added M · violations K"를 쓰고 stdout에는 위반 줄(위반 하나 = 한 줄)만 쓴다. 게이트는 요약 줄 정확히
#   하나 · K는 앞 0 없는 9자리 이하 십진수 · K가 종료 코드와 맞음(0 ⇔ K = 0) · stdout의 위반 줄 수 = K일 때만 그 종료 코드를 믿는다.
#     exit 0  요약 줄 정확히 하나 · K = 0 · 위반 줄 0 → 통과(0)
#     exit 1  요약 줄 정확히 하나 · K ≥ 1 · 위반 줄 수 = K → 위반(1)
#     0 · 1인데 위 계약과 다르면 2 — 검사기 적재 실패 · 진입점 가드 꺼짐 · 다른 검사기를 통과나 위반으로 잘못 읽지 않는다.
#     검사기가 2로 끝나면 2, 0 · 1 · 2 밖의 코드도 2(fail-closed).
#   이 스크립트의 사용법 오류 · 전제 위반 · 도구 없음(git · node · mktemp) · 작업 디렉터리를 만들지 못함도 2다 — 검사하지 못했으면
#   통과가 아니다.
#
# 출력
#   머리 다섯 줄(제목 · 기준 · 기준 스키마 · 변경 쪽 스키마 · 검사기) → 검사기 출력(stdout 다음 stderr — 줄마다) → "결과: …" 한 줄.
#   변경 쪽 스키마 줄은 CI면 "HEAD 커밋 <12자>:packages/events/schemas(.json N개 · 작업 트리 바이트 일치)", 로컬이면
#   "packages/events/schemas(.json N개)"다(없으면 둘 다 "없음 — …").
#   검사기 출력은 ::stop-commands::<실행마다 새 토큰> … ::<토큰>:: 사이에 둔다 — 파일 · 속성 이름은 PR이 고른 글자다(gitleaks job과
#   같은 방어 · 검사기도 제어 문자를 이스케이프해 찍는다). 전제 위반 · 사용법 오류는 stderr에 사유 한 줄(PR이 고른 이름은 printf %q).
#   이 스크립트가 찍는 문구에는 절대 경로가 없다 — node가 검사기를 적재하지 못할 때 찍는 오류 · 스택(stop-commands 구간 안)은 예외다.
# 원칙: 작업 트리와 .git을 바꾸지 않는다(읽기 명령만 — rev-parse · ls-tree · cat-file · hash-object --no-filters(-w 없음 — 쓰기 없음)).
#   작업 디렉터리는 mktemp -d로 만들고 EXIT trap이 지운다(이 스크립트가 만든 events-compat.* 디렉터리만). 네트워크를 쓰지 않는다.
# 요구: bash 4 이상 · git · node · mktemp(GNU coreutils). 토큰은 /proc의 uuid → od(/dev/urandom) → $RANDOM 순으로 만든다.
set -euo pipefail
export LC_ALL=C
# git이 replace ref(refs/replace/*)로 바꾼 객체를 읽지 않고 pathspec을 글자 그대로(와일드카드 · 마법 없음) 읽게 한다 — 첫 git 호출 전에
export GIT_NO_REPLACE_OBJECTS=1 GIT_LITERAL_PATHSPECS=1
shopt -s nullglob

readonly PROG=events-compat
readonly SCHEMAS_REL=packages/events/schemas
readonly CHECKER_REL=packages/events/scripts/check-compat.mjs
readonly HEX_RE='^([0-9a-f]{40}|[0-9a-f]{64})$'
readonly ZERO_RE='^(0{40}|0{64})$'
# git ls-tree 한 항목의 머리 "<mode> <type> <oid>"
readonly LS_META_RE='^([0-7]{6}) (blob|tree|commit) ([0-9a-f]{40}|[0-9a-f]{64})$'
# 스키마 .json의 허용 이름(기준 · 변경 쪽 공통 — 변경 쪽은 다음 기준이다)
readonly JSON_NAME_RE='^[A-Za-z0-9_][A-Za-z0-9._-]*\.json$'
# 검사기 요약 줄(고정 CLI 계약 — check-compat.mjs 머리 주석). 0 · 1 종료와 함께 stderr에 정확히 하나
readonly SUMMARY_RE='^check-compat: checked [0-9]+ · added [0-9]+ · violations ([0-9]+)$'

# ---------- 상태(EXIT trap이 job 요약에 쓴다) ----------
work=''
sum_base='—'
sum_checker='—'
sum_result='오류 — 검사 전에 멈췄다(사유는 로그)'
# 함수가 채우는 결과(set -u — 처음부터 둔다)
ent_mode='' ent_type='' ent_oid=''
res_kind='' res_mode='' res_oid=''
ext_count=0 ext_names=() ext_oids=()
je_names=()
wk=''
hc_kind='' hc_detail='' hc_oid=''

usage() {
  printf '사용법: bash scripts/ci/events-compat.sh [--root <dir>] [--base <commit>]\n'
}

# die <사유> — stderr에 사유 한 줄, exit 2(검사하지 못했으면 통과가 아니다)
die() {
  printf '%s: %s — 검사하지 못했으므로 통과가 아니다(exit 2)\n' "$PROG" "$1" >&2
  sum_result="오류 — $1"
  exit 2
}

usage_error() {
  printf '%s: 사용법 오류 — %s\n' "$PROG" "$1" >&2
  usage >&2
  sum_result='오류 — 사용법'
  exit 2
}

# EXIT trap — 작업 디렉터리를 지우고(이 스크립트가 mktemp로 만든 events-compat.* 만) job 요약 세 줄을 남긴다. 종료 코드는 그대로 둔다.
# on_exit는 아래 trap on_exit EXIT로 불린다 — shellcheck는 trap 호출을 세지 않는다(SC2329)
# shellcheck disable=SC2329
on_exit() {
  local rc=$?
  if [[ -n $work && -d $work && ${work##*/} == events-compat.* ]]; then
    rm -rf -- "$work"
  fi
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    {
      printf -- '- **기준** · %s\n' "$sum_base"
      printf -- '- **검사기** · %s\n' "$sum_checker"
      printf -- '- **결과** · %s · exit %d\n' "$sum_result" "$rc"
    } >> "$GITHUB_STEP_SUMMARY" || true
  fi
  exit "$rc"
}
trap on_exit EXIT

# new_token — stop-commands 토큰(실행마다 새 값 · [A-Za-z0-9-] 16자 이상)
new_token() {
  local t=''
  if [[ -r /proc/sys/kernel/random/uuid ]]; then t=$(< /proc/sys/kernel/random/uuid) || t=''; fi
  if [[ ! $t =~ ^[A-Za-z0-9-]{16,}$ ]]; then t=$(od -An -N16 -tx1 /dev/urandom 2> /dev/null | tr -d ' \n') || t=''; fi
  if [[ ! $t =~ ^[A-Za-z0-9-]{16,}$ ]]; then t="stop-$$-$RANDOM$RANDOM$RANDOM$RANDOM"; fi
  printf '%s' "$t"
}

# ls_entry <트리 oid> <이름> <접두(사유용)> <쪽> — 그 트리 바로 아래 항목 하나를 ent_mode · ent_type · ent_oid에 둔다. 있으면 0 · 없으면 1.
# git이 실패하거나 출력 꼴이 예상과 다르거나 같은 이름이 둘 이상이면 2 — 실패를 "없음"으로 보지 않는다. if 조건 안에서 불리므로
# (set -e가 꺼진다) 명령마다 직접 확인한다. <쪽>은 사유 문구의 쪽 이름(기준 · 변경 쪽).
ls_entry() {
  local rec meta name n=0 tag=''
  if [[ $4 != 기준 ]]; then tag=" · $4"; fi
  ent_mode='' ent_type='' ent_oid=''
  if ! git ls-tree -z --full-tree "$1" -- "$2" > "$work/ls" 2> /dev/null; then
    die "${4} 트리를 읽지 못했다(git ls-tree ${1:0:12} — ${3}의 상위 트리 · 손상되었거나 없는 객체)"
  fi
  while IFS= read -r -d '' rec || [[ -n $rec ]]; do
    meta=${rec%%$'\t'*}
    name=${rec#*$'\t'}
    if [[ $name != "$2" || ! $meta =~ $LS_META_RE ]]; then die "git ls-tree 출력의 꼴이 예상과 다르다(${3}${tag})"; fi
    ent_mode=${BASH_REMATCH[1]}
    ent_type=${BASH_REMATCH[2]}
    ent_oid=${BASH_REMATCH[3]}
    n=$((n + 1))
  done < "$work/ls"
  if (( n > 1 )); then die "${4} 트리에 ${3} 항목이 ${n}개다(손상된 트리)"; fi
  if (( n == 1 )); then return 0; fi
  return 1
}

# resolve_path <루트 트리 oid> <쪽> <성분>... — 그 커밋 트리에서 성분마다 한 단계씩 내려간다. 결과 res_kind(absent · tree · file ·
# other) · res_mode · res_oid. 중간 성분이 없으면 absent, 중간 성분이 트리가 아니면 2(사유에 쪽 · 접두 · mode).
resolve_path() {
  local tree=$1 side=$2 prefix='' comp i=0
  shift 2
  res_kind='' res_mode='' res_oid=''
  for comp in "$@"; do
    i=$((i + 1))
    prefix=${prefix:+$prefix/}$comp
    if ! ls_entry "$tree" "$comp" "$prefix" "$side"; then
      res_kind=absent
      return 0
    fi
    if (( i < $# )); then
      if [[ $ent_mode == 040000 && $ent_type == tree ]]; then
        tree=$ent_oid
        continue
      fi
      die "${side} 커밋의 ${prefix}가 디렉터리(트리)가 아니다(mode ${ent_mode}) — 경로를 따라가지 않는다"
    fi
  done
  res_mode=$ent_mode
  res_oid=$ent_oid
  case $ent_mode:$ent_type in
    040000:tree) res_kind=tree ;;
    100644:blob | 100755:blob) res_kind=file ;;
    *) res_kind=other ;;
  esac
}

# extract_schemas <스키마 트리 oid> <대상 디렉터리> <쪽> — .json 항목을 대상 디렉터리에 꺼내 ext_count에 세고 이름 · blob oid를
# ext_names · ext_oids에 둔다(CI 변경 쪽의 작업 트리 대조용). .json이 아닌 항목은 무시한다.
extract_schemas() {
  local rec meta name mode type oid tag=''
  if [[ $3 != 기준 ]]; then tag=" · $3"; fi
  ext_count=0 ext_names=() ext_oids=()
  if ! git ls-tree -z --full-tree "$1" > "$work/ls" 2> /dev/null; then
    die "${3} 스키마 트리를 읽지 못했다(git ls-tree ${1:0:12} — 손상되었거나 없는 객체)"
  fi
  while IFS= read -r -d '' rec || [[ -n $rec ]]; do
    meta=${rec%%$'\t'*}
    name=${rec#*$'\t'}
    if [[ ! $meta =~ $LS_META_RE ]]; then die "git ls-tree 출력의 꼴이 예상과 다르다(${SCHEMAS_REL}${tag})"; fi
    mode=${BASH_REMATCH[1]}
    type=${BASH_REMATCH[2]}
    oid=${BASH_REMATCH[3]}
    if [[ $name != *.json ]]; then continue; fi
    if [[ ! $name =~ $JSON_NAME_RE ]]; then
      die "${3} 스키마 이름 $(printf '%q' "$name")이 허용 꼴(영숫자 · _ 로 시작 · 영숫자 . _ - 만 · .json)이 아니다"
    fi
    case $mode:$type in
      100644:blob | 100755:blob) ;;
      *) die "${3} 스키마 ${name}가 일반 파일이 아니다(mode ${mode}) — 꺼내지 않는다" ;;
    esac
    if [[ -e $2/$name || -L $2/$name ]]; then die "${3} 스키마 ${name}가 트리에 두 번 나온다(손상된 트리)"; fi
    if ! git cat-file blob "$oid" > "$2/$name" 2> /dev/null; then
      die "${3} 스키마 ${name}를 꺼내지 못했다(git cat-file blob ${oid:0:12})"
    fi
    ext_names+=("$name")
    ext_oids+=("$oid")
    ext_count=$((ext_count + 1))
  done < "$work/ls"
}

# wt_kind <루트 기준 상대 경로> — 작업 트리 항목의 종류를 wk에 둔다: link · absent · dir · file · other(심볼릭 링크는 따라가지 않는다)
wt_kind() {
  local p=$ROOT/$1
  if [[ -L $p ]]; then
    wk=link
  elif [[ ! -e $p ]]; then
    wk=absent
  elif [[ -d $p ]]; then
    wk=dir
  elif [[ -f $p ]]; then
    wk=file
  else
    wk=other
  fi
}

# kind_text <wk 값> — 사유 문구용 한국어
kind_text() {
  case $1 in
    link) printf '심볼릭 링크' ;;
    absent) printf '없음' ;;
    dir) printf '디렉터리' ;;
    file) printf '일반 파일' ;;
    *) printf '일반 파일 · 디렉터리 밖의 형식' ;;
  esac
}

# json_entries <디렉터리> — 그 디렉터리 바로 아래에서 이름이 .json으로 끝나는 항목(일반 파일 · 링크 · 디렉터리 — 점으로 시작하는 이름
# 포함)의 이름을 je_names에 둔다. 디렉터리가 없으면 빈 목록.
json_entries() {
  local f had_dotglob=0
  je_names=()
  if [[ ! -d $1 ]]; then return 0; fi
  if shopt -q dotglob; then had_dotglob=1; fi
  shopt -s dotglob
  for f in "$1"/*.json; do je_names+=("${f##*/}"); done
  if (( had_dotglob == 0 )); then shopt -u dotglob; fi
}

# verify_worktree_bytes — CI: 작업 트리 packages/events/schemas의 .json 항목이 방금 HEAD 커밋에서 꺼낸 것(ext_names · ext_oids)과 같은
# 집합이고, 하나하나 심볼릭 링크가 아닌 일반 파일이며 git hash-object --no-filters(-w 없음 — 쓰기 없음)가 그 blob oid와 같아야 한다 —
# 아니면 2(체크아웃이 속성으로 바꾼 바이트 · 캐시 복원 · 커밋하지 않은 수정은 소비자 체크아웃이 검사한 것과 다른 내용을 읽게 한다).
verify_worktree_bytes() {
  local i j name found got
  json_entries "$ROOT/$SCHEMAS_REL"
  for (( i = 0; i < ${#je_names[@]}; i++ )); do
    name=${je_names[i]}
    found=0
    for (( j = 0; j < ${#ext_names[@]}; j++ )); do
      if [[ ${ext_names[j]} == "$name" ]]; then
        found=1
        break
      fi
    done
    if (( found == 0 )); then
      die "작업 트리의 $(printf '%q' "$name")이 HEAD 커밋에 없다(추적하지 않는 파일 · 캐시 복원 등 — 소비자 체크아웃이 검사한 것과 다른 내용을 읽는다)"
    fi
  done
  for (( j = 0; j < ${#ext_names[@]}; j++ )); do
    name=${ext_names[j]}
    wt_kind "$SCHEMAS_REL/$name"
    if [[ $wk != file ]]; then
      die "작업 트리의 $(printf '%q' "$name")이 일반 파일이 아니다($(kind_text "$wk") — HEAD 커밋에는 일반 파일이다)"
    fi
    got=$(git hash-object --no-filters -- "$SCHEMAS_REL/$name" 2> /dev/null) \
      || die "작업 트리의 $(printf '%q' "$name")을 읽지 못했다(git hash-object --no-filters)"
    if [[ $got != "${ext_oids[j]}" ]]; then
      die "작업 트리의 $(printf '%q' "$name")이 커밋 blob과 바이트가 다르다(.gitattributes 변환 · 캐시 복원 등 — 소비자 체크아웃이 검사한 것과 다른 내용을 읽는다)"
    fi
  done
}

# head_checker — 변경 쪽 검사기(packages/events/scripts/check-compat.mjs)의 모양. 결과 hc_kind(file · absent · other) · hc_detail(사유용)
# · hc_oid(CI). CI = HEAD 커밋 트리에서 resolve_path(경로 성분이 트리가 아니면 그 자리에서 2) · 로컬 = 작업 트리(경로 성분은 심볼릭
# 링크가 아닌 디렉터리, 검사기는 심볼릭 링크가 아닌 일반 파일).
head_checker() {
  local item rel want
  hc_kind='' hc_detail='' hc_oid=''
  if (( ci )); then
    resolve_path "$head_tree" '변경 쪽' packages events scripts check-compat.mjs
    hc_oid=$res_oid
    case $res_kind in
      file) hc_kind=file ;;
      absent) hc_kind=absent hc_detail='HEAD 커밋에 없음' ;;
      *) hc_kind=other hc_detail="HEAD 커밋의 mode ${res_mode}" ;;
    esac
    return 0
  fi
  for item in packages:dir packages/events:dir packages/events/scripts:dir "${CHECKER_REL}:file"; do
    rel=${item%:*}
    want=${item##*:}
    wt_kind "$rel"
    if [[ $wk == "$want" ]]; then continue; fi
    if [[ $wk == absent ]]; then hc_kind=absent; else hc_kind=other; fi
    hc_detail="작업 트리의 ${rel}: $(kind_text "$wk")"
    return 0
  done
  hc_kind=file
}

# print_lines <파일> — 줄마다 찍는다(마지막 줄에 줄바꿈이 없어도 줄로 끝낸다 — 토큰 줄이 언제나 줄 머리에 온다)
print_lines() {
  local line
  while IFS= read -r line || [[ -n $line ]]; do
    printf '%s\n' "$line"
  done < "$1"
}

# count_lines <파일> — 줄 수(마지막 줄에 줄바꿈이 없어도 센다)
count_lines() {
  local line n=0
  while IFS= read -r line || [[ -n $line ]]; do n=$((n + 1)); done < "$1"
  printf '%d' "$n"
}

# ---------- 인자 ----------
root_arg=''
base_arg=''
have_base=0
while (( $# > 0 )); do
  case $1 in
    --root)
      if (( $# < 2 )) || [[ -z $2 ]]; then usage_error '--root에 디렉터리를 준다'; fi
      root_arg=$2
      shift 2
      ;;
    --root=?*)
      root_arg=${1#--root=}
      shift
      ;;
    --base)
      if (( $# < 2 )) || [[ -z $2 ]]; then usage_error '--base에 커밋을 준다'; fi
      base_arg=$2
      have_base=1
      shift 2
      ;;
    --base=?*)
      base_arg=${1#--base=}
      have_base=1
      shift
      ;;
    -h | --help)
      usage
      sum_result='도움말만 찍었다'
      exit 0
      ;;
    *)
      usage_error "알 수 없는 인자: $(printf '%q' "$1")"
      ;;
  esac
done

# ---------- 도구(없으면 exit 2 — 통과로 넘어가지 않는다) ----------
missing=()
for t in git node mktemp; do
  if ! command -v "$t" > /dev/null 2>&1; then missing+=("$t"); fi
done
if (( ${#missing[@]} > 0 )); then die "도구 없음 — ${missing[*]}(PATH)"; fi

# ---------- 루트: git 작업 트리의 최상위 ----------
if [[ -z $root_arg ]]; then
  src=${BASH_SOURCE[0]}
  if [[ $src == */* ]]; then sdir=${src%/*}; else sdir=.; fi
  root_arg=$sdir/../..
fi
if [[ ! -d $root_arg ]]; then die '루트 디렉터리가 없다(--root)'; fi
ROOT=$(cd -- "$root_arg" && pwd -P) || die '루트 디렉터리로 들어갈 수 없다(--root)'
cd -- "$ROOT"
if [[ $(git rev-parse --is-inside-work-tree 2> /dev/null || true) != true ]]; then die '루트가 git 작업 트리가 아니다(--root)'; fi
prefix=$(git rev-parse --show-prefix 2> /dev/null) || die '루트의 git 위치를 읽지 못했다(--root)'
if [[ -n $prefix ]]; then die '루트가 git 작업 트리의 최상위가 아니다(--root)'; fi

# ---------- GitHub Actions: 체크아웃이 이 이벤트의 커밋인가(--base와 무관) · CI면 변경 쪽을 그 커밋 객체에서 읽는다 ----------
ci=0
head_sha=''
head_tree=''
if [[ ${GITHUB_ACTIONS:-} == true ]]; then
  ci=1
  event_sha=${GITHUB_SHA:-}
  if [[ ! $event_sha =~ $HEX_RE ]]; then die "GITHUB_SHA $(printf '%q' "$event_sha")가 전체 커밋 ID(소문자 40/64-hex)가 아니다"; fi
  head_sha=$(git rev-parse --verify --quiet 'HEAD^{commit}' 2> /dev/null) || die 'HEAD 커밋을 읽지 못했다'
  if [[ $head_sha != "$event_sha" ]]; then
    die "HEAD ${head_sha:0:12}가 이벤트 커밋(GITHUB_SHA ${event_sha:0:12})이 아니다 — 체크아웃이 이 이벤트의 커밋이 아니다"
  fi
fi

# ---------- 기준 커밋(빈 값 = 빈 기준) ----------
base=''
if (( have_base )); then
  base=$(git rev-parse --verify --quiet --end-of-options "${base_arg}^{commit}" 2> /dev/null) \
    || die "--base $(printf '%q' "$base_arg")가 이 저장소의 커밋이 아니다"
  base_label="지정 커밋(--base) ${base:0:12}"
else
  event=${GITHUB_EVENT_NAME:-}
  case $event in
    pull_request)
      pr_head=${PR_HEAD_SHA:-}
      if [[ ! $pr_head =~ $HEX_RE ]]; then die "PR_HEAD_SHA $(printf '%q' "$pr_head")가 전체 커밋 ID(소문자 40/64-hex)가 아니다"; fi
      head2=$(git rev-parse --verify --quiet 'HEAD^2^{commit}' 2> /dev/null || true)
      if [[ $head2 != "$pr_head" ]]; then
        die "PR head ${pr_head:0:12}가 HEAD(merge 커밋)의 둘째 부모가 아니다 — 전제: GitHub의 merge ref는 부모 둘(base 끝 · PR head)"
      fi
      base=$(git rev-parse --verify --quiet 'HEAD^1^{commit}' 2> /dev/null) || die 'HEAD^1(base 브랜치 끝)을 읽지 못했다'
      base_label="PR merge 커밋의 첫째 부모 ${base:0:12}(둘째 부모 = PR head ${pr_head:0:12} 확인)"
      ;;
    push)
      before=${PUSH_BEFORE:-}
      if [[ $before =~ $ZERO_RE ]]; then
        base_label='빈 기준 — push before가 0(새 브랜치)이라 모든 스키마를 추가로 본다'
      elif [[ ! $before =~ $HEX_RE ]]; then
        die "PUSH_BEFORE $(printf '%q' "$before")가 전체 커밋 ID(소문자 40/64-hex)가 아니다"
      else
        base=$(git rev-parse --verify --quiet "${before}^{commit}" 2> /dev/null) \
          || die "push before ${before:0:12}가 이 저장소에 없다(checkout fetch-depth: 0 필요 · 강제 push로 사라진 커밋일 수 있다)"
        base_label="push 이전 커밋(before) ${base:0:12}"
      fi
      ;;
    '')
      die 'GITHUB_EVENT_NAME이 없다 — pull_request · push 밖에서는 --base <commit>로 기준을 준다'
      ;;
    *)
      die "이벤트 $(printf '%q' "$event")에는 기준 규칙이 없다(pull_request · push만)"
      ;;
  esac
fi
sum_base=$base_label

# ---------- 작업 디렉터리 ----------
# mktemp의 오류 문구는 버린다(TMPDIR 절대 경로가 찍힌다) — 사유는 die가 찍는다
work=$(mktemp -d -t events-compat.XXXXXXXX 2> /dev/null) || die '작업 디렉터리를 만들지 못했다(mktemp -d — TMPDIR 확인)'
mkdir -- "$work/base" "$work/head" "$work/checker" "$work/empty"

# ---------- 기준 스키마(ls-tree + cat-file blob — 속성 · 필터 · replace ref를 거치지 않는다) ----------
base_json=0
base_tree=''
if [[ -z $base ]]; then
  base_schemas_label='없음(빈 기준)'
else
  base_tree=$(git rev-parse --verify --quiet "${base}^{tree}" 2> /dev/null) || die "기준 커밋 ${base:0:12}의 트리를 읽지 못했다"
  resolve_path "$base_tree" 기준 packages events schemas
  case $res_kind in
    absent)
      base_schemas_label="없음 — 기준 커밋에 ${SCHEMAS_REL}가 없다(전부 추가로 본다)"
      ;;
    tree)
      extract_schemas "$res_oid" "$work/base" 기준
      base_json=$ext_count
      base_schemas_label="${base:0:12}:${SCHEMAS_REL}(.json ${base_json}개)"
      ;;
    *)
      die "기준 커밋의 ${SCHEMAS_REL}가 디렉터리(트리)가 아니다(mode ${res_mode})"
      ;;
  esac
fi

# ---------- 변경 쪽 스키마(CI = HEAD 커밋 객체 + 작업 트리 바이트 일치 · 로컬 = 작업 트리) ----------
# 작업 트리의 경로 성분(두 경우 공통) — 심볼릭 링크는 따라가지 않는다
wt_present=1
for rel in packages packages/events "$SCHEMAS_REL"; do
  wt_kind "$rel"
  case $wk in
    dir) ;;
    link) die "변경 쪽 ${rel}가 심볼릭 링크다 — 따라가지 않는다" ;;
    absent)
      wt_present=0
      break
      ;;
    *) die "변경 쪽 ${rel}가 디렉터리가 아니다" ;;
  esac
done
head_json=0
if (( ci )); then
  head_tree=$(git rev-parse --verify --quiet "${head_sha}^{tree}" 2> /dev/null) || die "HEAD 커밋 ${head_sha:0:12}의 트리를 읽지 못했다"
  resolve_path "$head_tree" '변경 쪽' packages events schemas
  head_kind=$res_kind
  case $head_kind in
    absent) ext_count=0 ext_names=() ext_oids=() ;;
    tree) extract_schemas "$res_oid" "$work/head" '변경 쪽' ;;
    *) die "변경 쪽 커밋의 ${SCHEMAS_REL}가 디렉터리(트리)가 아니다(mode ${res_mode})" ;;
  esac
  head_json=$ext_count
  verify_worktree_bytes
  head_dir=$work/head
  if [[ $head_kind == absent ]]; then
    head_label="없음 — HEAD 커밋 ${head_sha:0:12}에 ${SCHEMAS_REL}가 없다(기준의 스키마는 전부 삭제로 본다 · 작업 트리에도 .json이 없다)"
  else
    head_label="HEAD 커밋 ${head_sha:0:12}:${SCHEMAS_REL}(.json ${head_json}개 · 작업 트리 바이트 일치)"
  fi
elif (( wt_present )); then
  json_entries "$ROOT/$SCHEMAS_REL"
  for (( i = 0; i < ${#je_names[@]}; i++ )); do
    name=${je_names[i]}
    if [[ ! $name =~ $JSON_NAME_RE ]]; then
      die "변경 쪽 스키마 이름 $(printf '%q' "$name")이 허용 꼴(영숫자 · _ 로 시작 · 영숫자 . _ - 만 · .json)이 아니다"
    fi
    wt_kind "$SCHEMAS_REL/$name"
    if [[ $wk != file ]]; then die "변경 쪽 스키마 ${name}가 일반 파일이 아니다($(kind_text "$wk")) — 따라가지 않는다"; fi
  done
  head_json=${#je_names[@]}
  head_dir=$ROOT/$SCHEMAS_REL
  head_label="${SCHEMAS_REL}(.json ${head_json}개)"
else
  head_dir=$work/empty
  head_label="없음 — ${SCHEMAS_REL}가 없다(기준의 스키마는 전부 삭제로 본다)"
fi

# ---------- 다음 기준의 모양: 변경 쪽 검사기 경로(스키마 수와 상관없이 — 기준 쪽 해석과 같은 조건 · 검사기 실행 전) ----------
# 경로 성분이 디렉터리가 아니거나 검사기가 일반 파일이 아니면(링크 · gitlink) 언제나 2(CI는 성분이 트리가 아니면 resolve_path가 그 자리에서
# 2), 검사기가 없는 것은 변경 쪽에 스키마가 있을 때만 2다(스키마도 검사기도 없는 트리는 다음 기준에서 부트스트랩 조건을 만족한다).
head_checker
case $hc_kind in
  file) ;;
  absent)
    if (( head_json > 0 )); then
      die "변경 쪽에 스키마(.json ${head_json}개)가 있는데 검사기(${CHECKER_REL})가 일반 파일로 없다(${hc_detail}) — 머지되면 다음 기준이 2가 된다(되돌리는 PR까지 막힌다)"
    fi
    ;;
  *)
    die "변경 쪽 검사기 경로(${CHECKER_REL})가 다음 기준의 모양이 아니다(${hc_detail}) — 머지되면 다음 기준이 2가 된다(되돌리는 PR까지 막힌다)"
    ;;
esac

# ---------- 검사기: 기준 쪽 사본 · 기준에 검사기도 스키마도 없을 때만 변경 쪽의 것(부트스트랩) ----------
checker_kind=absent
if [[ -n $base ]]; then
  resolve_path "$base_tree" 기준 packages events scripts check-compat.mjs
  checker_kind=$res_kind
fi
case $checker_kind in
  file)
    checker=$work/checker/check-compat.mjs
    git cat-file blob "$res_oid" > "$checker" 2> /dev/null || die "기준 검사기를 꺼내지 못했다(git cat-file blob ${res_oid:0:12})"
    checker_label="기준 커밋 ${base:0:12}의 ${CHECKER_REL}(패키지 밖 임시 사본 — 이 체크아웃의 검사기는 쓰지 않는다)"
    sum_checker="기준 커밋 ${base:0:12}의 check-compat.mjs"
    ;;
  absent)
    if (( base_json > 0 )); then
      die "기준에 스키마(.json ${base_json}개)가 있는데 검사기(${CHECKER_REL})가 없다 — 검사기를 지운 변경이 머지됐을 수 있다(부트스트랩은 기준에 검사기도 스키마도 없을 때만)"
    fi
    if [[ -z $hc_kind ]]; then head_checker; fi # 위 모양 확인이 이미 채운다 — 순서가 바뀌어도 비지 않게 남긴다
    if (( ci )); then
      case $hc_kind in
        file) ;;
        absent) die "검사기가 없다 — 기준에도 HEAD 커밋에도 ${CHECKER_REL}(일반 파일)가 없다" ;;
        *) die "부트스트랩 검사기(HEAD 커밋의 ${CHECKER_REL})가 일반 파일이 아니다(${hc_detail}) — 꺼내지 않는다" ;; # 도달 불가 — 위 모양 확인이 먼저 2
      esac
      checker=$work/checker/check-compat.mjs
      git cat-file blob "$hc_oid" > "$checker" 2> /dev/null || die "부트스트랩 검사기를 꺼내지 못했다(git cat-file blob ${hc_oid:0:12})"
      checker_label="부트스트랩 — 기준에 검사기도 스키마도 없어 HEAD 커밋 ${head_sha:0:12}의 ${CHECKER_REL}를 쓴다(패키지 밖 임시 사본)"
      sum_checker="부트스트랩 — HEAD 커밋 ${head_sha:0:12}의 check-compat.mjs"
    else
      case $hc_kind in
        file) ;;
        absent) die "검사기가 없다 — 기준에도 이 체크아웃에도 ${CHECKER_REL}(일반 파일)가 없다" ;;
        *) die "부트스트랩 검사기(${CHECKER_REL}) 경로가 심볼릭 링크이거나 일반 파일이 아니다(${hc_detail}) — 따라가지 않는다" ;; # 도달 불가 — 위 모양 확인이 먼저 2
      esac
      checker=$ROOT/$CHECKER_REL
      checker_label="부트스트랩 — 기준에 검사기도 스키마도 없어 이 체크아웃의 ${CHECKER_REL}를 쓴다"
      sum_checker='부트스트랩 — 이 체크아웃의 check-compat.mjs'
    fi
    ;;
  *)
    die "기준 커밋의 ${CHECKER_REL}가 일반 파일이 아니다(mode ${res_mode}) — 꺼내지 않는다"
    ;;
esac

# ---------- 실행 ----------
printf '%s — packages/events 스키마 호환성 검사(기준 커밋 ↔ 이 체크아웃)\n' "$PROG"
printf '  기준: %s\n' "$base_label"
printf '  기준 스키마: %s\n' "$base_schemas_label"
printf '  변경 쪽 스키마: %s\n' "$head_label"
printf '  검사기: %s\n' "$checker_label"
rc=0
node "$checker" --base "$work/base" --head "$head_dir" > "$work/out" 2> "$work/err" || rc=$?
token=$(new_token)
printf '::stop-commands::%s\n' "$token"
print_lines "$work/out"
print_lines "$work/err"
printf '::%s::\n' "$token"

# ---------- 판정: 종료 코드 + 요약 줄(검사기 출력 계약) ----------
summary_n=0
summary_k=''
while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line =~ $SUMMARY_RE ]]; then
    summary_n=$((summary_n + 1))
    summary_k=${BASH_REMATCH[1]}
  fi
done < "$work/err"
out_n=$(count_lines "$work/out")
contract=''
if (( rc == 0 || rc == 1 )); then
  if (( summary_n != 1 )); then
    contract="요약 줄 ${summary_n}개(정확히 1개여야 한다)"
  elif [[ ! $summary_k =~ ^(0|[1-9][0-9]{0,8})$ ]]; then
    contract="요약 줄의 violations 값 ${summary_k}를 셀 수 없다"
  elif (( rc == 0 && summary_k != 0 )); then
    contract="exit 0인데 violations ${summary_k}"
  elif (( rc == 1 && summary_k == 0 )); then
    contract='exit 1인데 violations 0'
  elif (( out_n != summary_k )); then
    contract="위반 줄 ${out_n}개 ≠ violations ${summary_k}"
  fi
fi

if [[ -n $contract ]]; then
  sum_result="오류 — 검사기 출력이 CLI 계약과 다르다(${contract} · 검사기 exit ${rc})"
  printf '결과: 오류 — 검사기 출력이 CLI 계약과 다르다 — %s · 검사기 exit %d(exit 2 — 검사기 적재 실패이거나 다른 검사기일 수 있다)\n' "$contract" "$rc"
  rc=2
else
  case $rc in
    0)
      sum_result='통과 — 호환성 위반 없음'
      printf '결과: 통과 — 호환성 위반 없음(exit 0)\n'
      ;;
    1)
      sum_result="위반 ${summary_k}건 — 위 검사기 출력의 위반 줄(파일 · JSON 포인터 · 종류)"
      printf '결과: 실패 — 호환성 위반 %s건(exit 1 — 위 검사기 출력의 위반 줄)\n' "$summary_k"
      ;;
    2)
      sum_result='오류 — 검사기가 사용 · 입출력 오류로 끝났다'
      printf '결과: 오류 — 검사기가 사용 · 입출력 오류로 끝났다(exit 2 — 위 검사기 출력)\n'
      ;;
    *)
      sum_result="오류 — 검사기가 예상 밖의 종료 코드 ${rc}로 끝났다"
      printf '결과: 오류 — 검사기가 예상 밖의 종료 코드 %d로 끝났다(exit 2 — fail-closed)\n' "$rc"
      rc=2
      ;;
  esac
fi
exit "$rc"
