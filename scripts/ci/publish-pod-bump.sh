#!/usr/bin/env bash
# publish-pod-bump.sh — gitops dev digest bump PR(T074 · .github/workflows/publish-pod.yml job bump)
#
# 목적
#   publish job이 발행 · 단언 · attest · 자기 검증한 digest를 platform-gitops의 dev overlay(apps/<pod>/overlays/dev/kustomization.yaml)
#   images 항목에 넣는 PR을 GitHub App 토큰으로 열고, auto-merge(squash)를 건 뒤 머지 결과까지 기다려 대조한다.
#   계약 contracts/gitops-repo.md §이미지·승격 「dev bump」(T074 보정 2026-11-16) · 설계 design/t074-design.md D8 · D16이 정본이다.
#
# 사용: exec bash scripts/ci/publish-pod-bump.sh(워크플로 run 줄 — exec라 러너의 취소 신호를 이 스크립트가 직접 받는다 · 작업 디렉터리 =
#   모노레포 체크아웃 · gitops 체크아웃은 그 아래 GITOPS_DIR)
#   환경 변수(워크플로 env: · 러너 기본 env)
#     GH_TOKEN        App 설치 토큰 — gh가 읽는다. 이 스크립트는 값을 찍지도 인자로 넘기지도 않는다
#     MONOREPO_TOKEN  모노레포 워크플로 토큰(github.token · contents read) — ⓪ 존재 확인 직후 내보내지 않는 변수로 옮기고 env에서 지운다(이
#                     뒤의 자식은 받지 않는다). ①′ 낡은 실행 가드의 모노레포 compare 조회 한 번에만 GH_TOKEN으로 준다
#     DIGEST          발행한 digest(sha256:<64hex> — publish job 출력)
#     APP_SLUG        토큰을 만든 App의 slug(create-github-app-token 출력)
#     BOT_SLUG · BOT_ID   봇 목록의 App 이름 · 계정 ID(워크플로 상수 — gitops tests/validate.sh의 VALIDATE_BOT_AUTHORS · VALIDATE_BOT_IDS 기본값)
#     POD · IMAGE     pod 이름 · 이미지(ghcr.io/joshua92y/<pod>) — 워크플로 env
#     GITOPS_DIR      gitops 체크아웃 디렉터리(ref main · persist-credentials true — git push · ls-remote · fetch가 그 자격을 쓴다)
#     GITHUB_REF · GITHUB_SHA · GITHUB_REPOSITORY · GITHUB_RUN_ID · GITHUB_SERVER_URL · RUNNER_TEMP · GITHUB_STEP_SUMMARY  러너 기본값
#
# 흐름(어느 단계든 실패하면 그 뒤를 하지 않는다 — ④에서 브랜치를 올린 뒤의 실패는 「정리」를 거친다)
#   ⓪ 조건 · 입력  GITHUB_REF = refs/heads/main(main 실행만 — 워크플로 if · Environment 정책에 더한 셋째 겹) · 입력 꼴 · yq =
#                   $RUNNER_TEMP/bin/yq이고 v4.53.6 · gh · git · gitops 작업 트리가 origin/main의 끝이고 깨끗하다 · dev overlay가 저장소 안의
#                   일반 파일(심볼릭 링크 아님)
#   ① 현재 값     yq로 dev overlay의 images 중 newName = IMAGE인 항목의 digest — 정확히 하나 · sha256:<64hex>. 0개면 실패한다(첫 항목은 사람
#                   seed PR이 넣는다 — 설계 D9). 이미 DIGEST와 같으면 notice와 함께 exit 0(브랜치 · PR 없음)
#   ①′ 낡은 실행  모노레포 REST compare <GITHUB_SHA>...refs/heads/main(모노레포 토큰으로 · 머리는 브랜치 ref — 같은 이름 태그로 풀리지 않게)을
#      가드        읽는다. files가 목록(!!seq)이 아니면(없음 · null · map) 실패(stale-check). identical → 계속. ahead이고 바뀐 파일(filename ·
#                   previous_filename)이 워크플로의 paths 네 줄에 하나도 걸리지 않으면 → 계속. 하나라도 걸리면 → 낡은 실행이다(원천 커밋 뒤의
#                   main 커밋이 발행 경로를 바꿨다): notice와 요약 한 줄(마지막 main 커밋 sha7 · 까닭 코드 stale) 뒤 exit 0(브랜치 · PR 없음).
#                   그 커밋에 publish-pod 실행이 있다고 가정하지 않는다([skip ci] · 3,000파일 넘는 push · 워크플로 비활성이면 없다 — 런북의
#                   「[stale]인데 실행이 없으면 dispatch」). behind · diverged · 파일 300개(응답 상한) · 조회 오류 → 실패(stale-check — 낡음을 판정할
#                   수 없으면 멈춘다). 옛 실행을 「Re-run」해 dev를 옛 digest로 되돌리는 경로를 막는다
#   ② 제자리 교체  sha256:<old>가 든 줄이 정확히 하나이고 봇 경로 lint의 digest 줄 꼴(gitops tests/validate.sh RE_BOT_LINE)이어야 한다 — 그
#                   줄의 64자리 hex만 sed로 바꾼다. 확인: (가) git diff --numstat = 그 파일 하나 1 1 (나) -/+ 두 줄이 hex 밖에서 같다 (다) yq로
#                   다시 읽은 digest = DIGEST 하나. 다른 도구로 images를 다시 쓰지 않는다 — 그 편집 명령은 newName 줄을 지우고 파일 전체를
#                   재서식한다(2026-11-16 탐침 · 계약 「값만 바꾸고 들여쓰기 · 공백을 건드리지 않는다」)
#   ③ 신원 · 커밋  APP_SLUG = BOT_SLUG이고 gh api users/<BOT_SLUG>[bot]의 login · id · type = <BOT_SLUG>[bot] · BOT_ID · Bot이어야 한다(다른
#                   App의 자격이면 PR이 사람 규칙으로 판정된다 — 커밋 전에 멈춘다). 작성자 · 커미터 = <BOT_SLUG>[bot]
#                   <<BOT_ID>+<BOT_SLUG>[bot]@users.noreply.github.com>, git add는 dev 파일 하나 · 부모 = origin/main의 끝 · numstat = 그 파일
#                   1 1. 제목(커밋 · PR) = chore(<pod>): dev → <새 hex 앞 12>
#   ④ 브랜치      bump/dev-<pod>-<GITHUB_SHA 앞 7>(모노레포 원천 커밋 기준 — 같은 커밋의 PR이 둘 생기지 않는다). 원격에 이미 있으면 실패한다(남의
#                   브랜치일 수 있어 정리하지 않는다 · 있음 판정은 ref 이름이 정확히 refs/heads/<브랜치>인 줄만 센다 — git ls-remote의 패턴은
#                   꼬리 일치라 refs/heads/x/refs/heads/<브랜치>도 돌려준다). 올리기는 HEAD:refs/heads/<브랜치> 한 줄뿐이다(강제 · + refspec · main 없음). 올리기가 실패로
#                   끝나도 원격이 받았을 수 있다 — git ls-remote로 원격 끝을 보고 자기 커밋이면 정리를 거쳐 실패한다. 올리기 창(git push 직전 ~
#                   성공 확인 · pushing=1)에서 취소 신호를 받아도 같은 원칙이다(원격 끝이 자기 커밋일 때만 정리 — 남의 브랜치는 지우지 않는다)
#   ⑤ PR          gh pr create(본문은 파일) → 출력의 마지막 줄이 https://github.com/joshua92y/platform-gitops/pull/<n> → 바로 git ls-remote로
#                   원격 브랜치 끝 = 자기 커밋인지 본다(다르면 정리 · 실패 — promote.yml ⑦ 꼴)
#   ⑥ auto-merge  gh pr merge <n> --auto --squash --match-head-commit <커밋>(gh는 바로 머지할 수 있으면 즉시 머지한다 — ⑦이 그것도 본다).
#                   auto-merge를 거는 순간의 head를 고정한다(`--match-head-commit`) — 그 뒤의 이동은 ⑦ 조회와 머지 결과 대조가 잡는다
#   ⑦ 기다림      REST gh api repos/joshua92y/platform-gitops/pulls/<n>만 쓴다(GraphQL 상태 필드 · check 조회는 App 권한 밖이라 쓰지 않는다 —
#                   check 세부는 운영자 · 컨트롤러가 GET으로 본다). 10초 간격(sleep & wait — 취소 신호가 바로 닿는다) · 최대 90회 또는 900초.
#                   조회마다 base.ref = main이어야 한다(아니면 base — 정리 · 실패). merged → 대조. closed 미머지 · open인데 auto_merge 없음 · open인데
#                   head가 자기 커밋이 아님 · gh 오류 · 시간 초과 → 정리 · 실패(시간 초과의 요약에는 mergeable_state만). 첫 조회의
#                   auto_merge.enabled_by · merge_method를 요약에 남긴다(VD-5 d의 보조 증거)
#   대조          merge_commit_sha를 가져와(--depth=2) 부모가 하나이고 부모 대비 numstat이 dev 파일 1 1 한 줄이며 그 커밋의 dev digest(yq) =
#                   DIGEST이고, 그 커밋이 gitops main에 있는지(App 토큰 REST compare <머지 커밋>...refs/heads/main = identical · ahead) 본다. 다르면 실패 —
#                   이미 머지된 뒤라 정리하지 않는다(되돌리기는 운영자의 revert PR — 런북). 성공 요약(PR · merged_at · merged_by · 머지 때의
#                   head = 자기 커밋 여부 · 경과 초 · 머지 커밋 · 대조 결과)이 VD-5 e의 원본이다
#   정리          ④ 뒤의 실패: PR이 있으면 gh pr close → 닫기가 실패하면 PR을 한 번 더 읽어 이미 머지됐으면 정리하지 않고 대조로 간다(요약에
#                   남긴다 · 대조를 통과하면 exit 0), 아니면 gh pr merge --disable-auto → 원격 브랜치 삭제 → git ls-remote로 없어졌는지 확인(ref
#                   이름이 정확히 같은 줄만 — 꼬리 일치를 쓰지 않는다) → 결과(닫기 · auto-merge 해제 · 삭제 · 확인)를 요약에 남긴다. 정리가 실패해도
#                   job은 원래의 실패로 끝난다. 정리 중에는 INT · TERM을 무시한다(실패 갈래의 정리 도중 취소가 와도 정리를 끝까지 하고 원래 실패로
#                   끝난다).
#   취소          워크플로 run 줄이 exec라 이 스크립트가 러너의 취소 신호를 직접 받는다(SIGINT → 7.5초 → SIGTERM → 2.5초 → SIGKILL — actions/runner
#                   src/Runner.Sdk/ProcessInvoker.cs SendSignal · CancelAndKillProcessTree · 2026-11-16 확인). 받으면 그 뒤의 신호는 무시하고(정리
#                   창 = SIGINT 뒤 10초 · SIGKILL이면 정리 요약 줄이 없다) 열린 stop-commands 구간이 있으면 먼저 닫고 ④ 뒤 · 머지 전이면 정리한 뒤
#                   exit 130으로 끝난다(cancel). 머지를 본 뒤(대조 중)의 취소는 정리하지 않고 요약에 「취소 중 머지 확인」을 남긴다. 그래서 pod마다
#                   열린 봇 PR은 많아야 하나이고(main 실행은 동시성 그룹으로 직렬) 재시도는 가장 새 실행의 「Re-run」이다 — 낡은 실행은 ①′ 가드가
#                   건너뛴다
#
# 출력 위생(설계 CD-21): gh · git · 저장소가 고른 글자(gh 출력과 오류 · 응답의 문자열 · 파일 이름 · git 오류)는 형식을 확인한 값만 찍거나
#   ::stop-commands::<구간마다 새 토큰> … ::<토큰>:: 구간 안에서만 찍는다(제어 문자는 지운다). 외부 명령의 stdout · stderr는 모두 파일로
#   받는다(GitHub 러너는 stderr의 워크플로 명령도 해석한다). 토큰은 찍지 않는다. 오류는 stdout의 '::error::publish-pod-bump [<까닭 코드>]
#   <설명>' 한 줄이다(까닭 코드: ref · input · tool · tree · entry · stale-check · line · replace · identity · commit · branch-exists ·
#   branch · push · pr-create · pr-url · pr-tip · auto-merge · api · base · closed · auto-off · head-moved · timeout · merge-check ·
#   cancel). 낡은 실행은 오류가 아니다(notice · 요약의 [stale] · exit 0).
# 종료 코드: 0 = 머지 확인(또는 할 일 없음 · 낡은 실행) · 1 = 실패 · 130 = 취소. 요구: bash 4 이상 · git · gh · yq v4.53.6 · coreutils
#   (mktemp · sed · grep · tr · realpath · date(GNU) · od) · awk. 작업 디렉터리는 $RUNNER_TEMP/publish-pod-bump.* 하나이고 EXIT trap이 지운다.
set -euo pipefail
export LC_ALL=C
# git이 replace ref로 바꾼 객체를 읽지 않고 pathspec을 글자 그대로 읽게 한다 — 첫 git 호출 전에
export GIT_NO_REPLACE_OBJECTS=1 GIT_LITERAL_PATHSPECS=1

readonly PROG=publish-pod-bump
readonly OWNER=joshua92y
readonly GITOPS_REPO=joshua92y/platform-gitops
readonly YQ_WANT=v4.53.6
readonly POLL_SECONDS=10
readonly POLL_LIMIT=90
readonly WAIT_LIMIT_SECONDS=900
readonly -a DIFF_OPTS=(--no-ext-diff --no-textconv --no-renames --ignore-submodules=none --no-color)
readonly RE_DIGEST='^sha256:[0-9a-f]{64}$'
readonly RE_SHA='^[0-9a-f]{40}$'
readonly RE_LOGIN='^[A-Za-z0-9][A-Za-z0-9-]{0,38}(\[bot\])?$'
readonly RE_COUNT='^(0|[1-9][0-9]{0,9})$'
readonly RE_PR_URL='^https://github\.com/joshua92y/platform-gitops/pull/[1-9][0-9]{0,9}$'

# ---------- 상태(EXIT · 신호 trap과 정리가 쓴다) ----------
step='dev bump'
t0=$(date -u +%s)
start=$SECONDS
w=''
branch=''          # ④에서 올린 브랜치(정리 대상)
branch_name=''     # ④에서 올릴 브랜치 이름
pr=''              # ⑤에서 형식을 확인한 PR 번호
url=''
commit=''
cleanup_on=0       # 1 = 이 뒤의 실패는 정리를 거친다(④ 올리기 성공 ~ 머지 확인 전)
pushing=0          # 1 = ④ 올리기 창(브랜치 올리기 직전 ~ 성공 확인 — 이때의 취소는 원격 끝이 자기 커밋일 때만 정리한다)
CLEANUP_MERGED=0   # 정리 중 다시 읽은 PR이 이미 머지됐다
SHOW_TOK=''        # 지금 열려 있는 stop-commands 구간의 토큰(show가 열고 닫는다 — 그 사이에 받은 신호는 on_signal이 먼저 닫는다)
DIGESTS=()
# PR 응답 필드(read_pr이 채운다 — on_signal이 머지를 이미 봤는지 P_MERGED로 가린다)
P_STATE='' P_MERGED='' P_MERGED_AT='' P_MERGED_BY='' P_MERGED_BY_ID='' P_AUTO_NULL='' P_ENABLED_BY='' P_METHOD='' P_MSTATE='' P_HEAD='' P_MSHA='' P_BASE=''

# EXIT trap — 작업 디렉터리(이 스크립트가 mktemp로 만든 publish-pod-bump.* 만)를 지우고 job 요약에 시간 줄을 남긴다. 종료 코드는 그대로 둔다.
# on_exit · on_signal은 아래 trap으로 불린다 — shellcheck는 trap 호출을 세지 않는다(SC2329)
# shellcheck disable=SC2329
on_exit() {
  local rc=$? t1
  if [[ -n $w && -d $w && ${w##*/} == publish-pod-bump.* ]]; then rm -rf -- "$w"; fi
  t1=$(date -u +%s)
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    printf -- '- **%s** · 시작 %s · 종료 %s · %d초 · exit %d\n' "$step" \
      "$(date -u -d "@$t0" +%FT%TZ)" "$(date -u -d "@$t1" +%FT%TZ)" "$((t1 - t0))" "$rc" >> "$GITHUB_STEP_SUMMARY" || true
  fi
  exit "$rc"
}
trap on_exit EXIT

# 취소 — 워크플로 run 줄이 exec라 이 스크립트가 러너의 취소 신호(운영자 취소 · job 시간 초과)를 직접 받는다: SIGINT → 7.5초 → SIGTERM →
# 2.5초 → SIGKILL(actions/runner main 83982d9 src/Runner.Sdk/ProcessInvoker.cs SendSignal = kill(PID) · CancelAndKillProcessTree —
# 2026-11-16 소스 확인). 받으면 그 뒤의 INT · TERM은 무시한다 — 정리 창은 SIGINT 뒤 10초이고 SIGKILL이면 정리 요약 줄이 없다(그때는 운영자가
# 남은 bump PR · 브랜치를 GET으로 본다 — 런북 §3 T074). ④ 뒤 · 머지 전이면 자기 PR · 브랜치를 정리하고, 올리기 창(pushing=1)이면 원격 끝이
# 이 실행의 커밋일 때만 그 브랜치를 정리한 뒤(남의 브랜치는 지우지 않는다) exit 130(cancel)으로 끝낸다. 정리 중 PR이 이미 머지된 것을 보거나
# 머지를 본 뒤(대조 중 — P_MERGED = true) 받았으면 대조하지 않고 그 사실만 요약에 남긴다(취소 중이다 — 운영자가 머지 커밋을 확인한다). show의
# stop-commands 구간 안에서 받았으면 그 구간부터 닫는다(닫지 않으면 아래 ::error:: 줄이 워크플로 명령으로 읽히지 않는다). bash는 전경 명령이
# 끝난 뒤에 trap을 돌린다 — ⑦은 sleep & wait라 바로 닿고, gh · git 호출 중이면 그 호출이 끝난 뒤 닿는다
# shellcheck disable=SC2329
on_signal() {
  trap '' INT TERM
  if [[ -n ${SHOW_TOK:-} ]]; then printf '::%s::\n' "$SHOW_TOK"; SHOW_TOK=''; fi
  printf '::error::%s [cancel] 실행이 취소됐다(신호)\n' "$PROG"
  note '**실패** [cancel] — 실행이 취소됐다(신호)'
  if (( ! cleanup_on && pushing )) && [[ $(remote_tip "$branch_name") == "$commit" ]]; then
    branch=$branch_name
    cleanup_on=1
    printf '관찰: 올리기 창에서 취소됐고 원격 브랜치 %s 의 끝이 이 실행의 커밋이다 — 정리한다\n' "$branch_name"
  fi
  if (( cleanup_on )); then
    CLEANUP_MERGED=0
    cleanup
    if (( CLEANUP_MERGED )); then note '**취소 중 머지 확인** — 머지 결과 대조는 하지 않았다(취소) — 운영자가 머지 커밋을 확인한다'; fi
  elif [[ ${P_MERGED:-} == true ]]; then
    note '**취소 중 머지 확인** — 머지를 본 뒤 대조를 마치지 못했다(취소) — 운영자가 머지 커밋을 확인한다'
  fi
  exit 130
}
trap on_signal INT TERM

# note <글자> — job 요약에 한 줄(이 스크립트가 만든 글자와 형식을 확인한 값만 넣는다)
note() {
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then printf -- '- %s\n' "$1" >> "$GITHUB_STEP_SUMMARY" || true; fi
}
# re <글자> <정규식> — 바이트 단위(LC_ALL=C) 정규식 비교
re() {
  local LC_ALL=C
  [[ $1 =~ $2 ]]
}
# shown <값> <정규식> — 형식에 맞으면 그 값, 아니면 '형식 밖'(로그 · 요약에는 이것만 싣는다)
shown() {
  if re "$1" "$2"; then printf '%s' "$1"; else printf '형식 밖'; fi
}
# new_token — stop-commands 토큰(구간마다 새 값 · [A-Za-z0-9-] 16자 이상)
new_token() {
  local t=''
  if [[ -r /proc/sys/kernel/random/uuid ]]; then t=$(< /proc/sys/kernel/random/uuid) || t=''; fi
  if [[ ! $t =~ ^[A-Za-z0-9-]{16,}$ ]]; then t=$(od -An -N16 -tx1 /dev/urandom 2> /dev/null | tr -d ' \n') || t=''; fi
  if [[ ! $t =~ ^[A-Za-z0-9-]{16,}$ ]]; then t="stop-$$-$RANDOM-$RANDOM-$RANDOM-$RANDOM"; fi
  printf '%s' "$t"
}
# show <제목> <파일…> — 파일 내용(제어 문자 제거 · 파일마다 앞 200줄 · 줄 끝 보장)을 stop-commands 구간 안에 찍는다. 제목은 이 스크립트의 글자다.
# 여는 토큰을 SHOW_TOK에 두고 재개 줄을 찍은 뒤 비운다 — 그 사이에 받은 취소 신호는 on_signal이 이 구간부터 닫는다
show() {
  local f
  SHOW_TOK=$(new_token)
  printf '%s — 아래 구간은 gh · git · 저장소가 고른 글자다(워크플로 명령으로 해석하지 않는다):\n' "$1"
  shift
  printf '::stop-commands::%s\n' "$SHOW_TOK"
  for f in "$@"; do
    if [[ -f $f ]]; then { LC_ALL=C tr -d '\000-\010\013-\037\177' < "$f" | head -n 200 | awk '{ print }'; } || true; fi
  done
  printf '::%s::\n' "$SHOW_TOK"
  SHOW_TOK=''
}
# fail <까닭 코드> <설명> — 오류 줄 · 요약 한 줄 · (④ 올리기 뒤 · 머지 전이면) 정리 · exit 1. 정리 중 PR이 이미 머지된 것을 보면 대조로 간다
# (통과하면 exit 0). 명령 치환(서브셸) 안에서 부르지 않는다
fail() {
  printf '::error::%s [%s] %s\n' "$PROG" "$1" "$2"
  note "**실패** [$1] — $2"
  if (( cleanup_on )); then
    CLEANUP_MERGED=0
    cleanup
    if (( CLEANUP_MERGED )); then
      printf '::notice::앞의 실패 판정([%s]) 뒤 PR #%s 이(가) 이미 머지된 것을 확인했다 — 머지 결과를 대조한다\n' "$1" "$pr"
      verify_merge " — [$1] 판정 뒤 닫기가 실패해 다시 읽어 머지를 확인했다"
    fi
  fi
  exit 1
}
# remote_tip <브랜치> — 원격 refs/heads/<브랜치>의 끝 커밋(그 ref 줄이 정확히 하나일 때만 · 아니면 빈 글자). 찍기만 하고 실패하지 않는다
remote_tip() {
  local s r tip='' n=0
  if git ls-remote origin "refs/heads/$1" > "$w/tip.out" 2> "$w/tip.err"; then
    while IFS=$'\t' read -r s r; do
      if [[ $r == "refs/heads/$1" ]]; then
        tip=$s
        n=$((n + 1))
      fi
    done < "$w/tip.out"
  fi
  if (( n == 1 )); then printf '%s' "$tip"; fi
}
# remote_state <브랜치> — 원격 refs/heads/<브랜치>가 있으면 present · 없으면 absent · 조회 실패면 error를 찍는다. git ls-remote의 패턴은 꼬리
# 일치라(refs/heads/x/refs/heads/<브랜치>도 돌려준다) ref 이름이 정확히 같은 줄만 센다. 오류 글자는 $w/state.err에 남긴다
remote_state() {
  local s r n=0
  if ! git ls-remote origin "refs/heads/$1" > "$w/state.out" 2> "$w/state.err"; then
    printf 'error'
    return 0
  fi
  while IFS=$'\t' read -r s r; do
    if [[ $r == "refs/heads/$1" ]]; then n=$((n + 1)); fi
  done < "$w/state.out"
  if (( n > 0 )); then printf 'present'; else printf 'absent'; fi
}
# cleanup — 자기 PR 닫기(실패하면 PR을 다시 읽어 이미 머지됐으면 CLEANUP_MERGED=1로 멈춘다 · 아니면 auto-merge 끄기) → 원격 브랜치 삭제 →
# 없어졌는지 확인 → 결과를 로그 · 요약에. 어느 단계가 실패해도 계속한다. 첫 줄에서 INT · TERM을 무시한다 — 실패 갈래의 정리 도중 취소가 와도
# 정리를 끝까지 하고 원래 실패로 끝난다(정리 뒤에는 끝나는 일만 남으므로 trap을 되돌리지 않는다)
cleanup() {
  trap '' INT TERM
  local closed='해당 없음(PR 없음)' disabled='시도하지 않음' deleted confirm rstate
  cleanup_on=0
  if [[ -n $pr ]]; then
    if gh pr close "$pr" --repo "$GITOPS_REPO" > "$w/close.out" 2>&1; then
      closed='닫았다'
    else
      closed='실패'
      show 'gh pr close 출력' "$w/close.out"
      # 닫지 못한 까닭이 그사이의 머지일 수 있다 — PR을 한 번 더 읽어 머지됐으면 정리하지 않고 머지 결과 대조로 간다
      if gh api "repos/$GITOPS_REPO/pulls/$pr" > "$w/pr.json" 2> "$w/pr.err" && read_pr "$w/pr.json" && [[ $P_MERGED == true ]]; then
        CLEANUP_MERGED=1
        printf '정리 중단: PR %s 이(가) 이미 머지됐다 — 정리하지 않고 머지 결과를 대조한다\n' "$pr"
        note "**정리 중단** — PR #$pr 을(를) 닫지 못해 다시 읽으니 이미 머지됐다 — 정리하지 않는다"
        return 0
      fi
      if gh pr merge "$pr" --repo "$GITOPS_REPO" --disable-auto > "$w/disable.out" 2>&1; then
        disabled='해제했다'
      else
        disabled='실패 — 운영자가 끈다'
        show 'gh pr merge --disable-auto 출력' "$w/disable.out"
      fi
    fi
  fi
  if git push --quiet origin --delete "refs/heads/$branch" > "$w/delete.out" 2>&1; then
    deleted='지웠다'
  else
    deleted='실패'
    show '원격 브랜치 삭제 출력' "$w/delete.out"
  fi
  rstate=$(remote_state "$branch")
  case $rstate in
    absent) confirm='원격에 없음' ;;
    present) confirm='남아 있음 — 운영자가 지운다' ;;
    *) confirm='확인하지 못했다(git ls-remote 오류) — 운영자가 확인한다' ;;
  esac
  printf '정리: PR %s 닫기 %s · auto-merge 해제 %s · 브랜치 %s 삭제 %s · 확인 %s\n' "${pr:-없음}" "$closed" "$disabled" "$branch" "$deleted" "$confirm"
  note "**정리** — PR ${pr:+#$pr }닫기: $closed · auto-merge 해제: $disabled · 브랜치 \`$branch\` 삭제: $deleted · 확인: $confirm"
}
# digests_of <파일> — DIGESTS에 images 중 newName = IMAGE인 항목의 digest(줄마다 하나 — digest가 없는 항목은 null · 여러 문서면 --- 줄도
# 한 줄로 센다). yq가 파일을 읽지 못하면 1
digests_of() {
  local out
  DIGESTS=()
  out=$(IMG=$IMAGE yq -r '.images[] | select(.newName == strenv(IMG)) | .digest' "$1" 2> "$w/yq.err") || return 1
  if [[ -n $out ]]; then mapfile -t DIGESTS <<< "$out"; fi
}
# read_pr <파일> — PR 응답(REST pulls/<n>)에서 필드 12개를 P_*에 둔다(yq 한 번 · 줄마다 하나). 줄 수가 다르면(문자열 안의 줄바꿈 포함) 1
read_pr() {
  local -a f=()
  if ! yq -p json -o yaml -r '.state, .merged, .merged_at, .merged_by.login, .merged_by.id, (.auto_merge == null), .auto_merge.enabled_by.login, .auto_merge.merge_method, .mergeable_state, .head.sha, .merge_commit_sha, .base.ref' "$1" > "$w/pr.fields" 2> "$w/yq.err"; then
    return 1
  fi
  mapfile -t f < "$w/pr.fields"
  if (( ${#f[@]} != 12 )); then return 1; fi
  P_STATE=${f[0]}
  P_MERGED=${f[1]}
  P_MERGED_AT=${f[2]}
  P_MERGED_BY=${f[3]}
  P_MERGED_BY_ID=${f[4]}
  P_AUTO_NULL=${f[5]}
  P_ENABLED_BY=${f[6]}
  P_METHOD=${f[7]}
  P_MSTATE=${f[8]}
  P_HEAD=${f[9]}
  P_MSHA=${f[10]}
  P_BASE=${f[11]}
}
# path_hit <경로> — publish-pod.yml의 paths 네 줄(apps/identity-admin/** · packages/django-common/** · .github/workflows/publish-pod.yml ·
# scripts/ci/publish-pod-*.sh) 가운데 하나에 걸리면 0. GitHub 필터와 같게 맞춘다 — **는 /를 넘고 *는 넘지 않는다. case의 *는 /도 맞추므로
# 넷째 줄은 scripts/ci/ 뒤에 /가 없을 때(scripts/ci/ 바로 아래 파일)만 맞춘다
path_hit() {
  case $1 in
    "apps/$POD/"*) return 0 ;;
    packages/django-common/*) return 0 ;;
    .github/workflows/publish-pod.yml) return 0 ;;
    scripts/ci/publish-pod-*.sh) [[ ${1#scripts/ci/} != */* ]] && return 0 ;;
  esac
  return 1
}
# verify_merge <맥락> — 머지된 PR(P_*)의 머지 결과를 대조한다. 통과하면 요약을 남기고 exit 0. 어긋나면 fail merge-check(정리 없음 — 이미
# 머지됐다 · 되돌리기는 운영자의 revert PR). <맥락>은 요약에 덧붙이는 이 스크립트의 글자다
verify_merge() {
  local ctx=$1 msha parents ns ms_status head_note elapsed
  local -a pa=()
  cleanup_on=0
  elapsed=$((SECONDS - start))
  re "$P_MSHA" "$RE_SHA" || fail merge-check "PR #$pr 은(는) 머지됐지만 merge_commit_sha의 형식이 틀렸다 — 운영자가 머지 결과를 확인한다"
  msha=$P_MSHA
  if ! git fetch --quiet --no-tags --depth=2 origin "$msha" > "$w/fetch.out" 2>&1; then
    show '머지 커밋 가져오기 출력' "$w/fetch.out"
    fail merge-check "머지 커밋 $msha 을(를) 가져오지 못했다 — 운영자가 머지 결과를 확인한다"
  fi
  parents=$(git rev-list --parents -n 1 "$msha" 2> /dev/null) || fail merge-check "머지 커밋 $msha 을(를) 읽지 못했다"
  read -r -a pa <<< "$parents"
  if (( ${#pa[@]} != 2 )) || [[ ${pa[0]} != "$msha" ]]; then fail merge-check "머지 커밋 $msha 의 부모가 하나가 아니다(squash 머지가 아니다) — 운영자가 확인한다"; fi
  ns=$(git diff "${DIFF_OPTS[@]}" --numstat "${pa[1]}" "$msha" 2> /dev/null) || fail merge-check "머지 커밋 $msha 의 diff를 읽지 못했다"
  if [[ $ns != $'1\t1\t'"$dev" ]]; then fail merge-check "머지 커밋 $msha 이(가) $dev 의 한 줄 교체가 아니다(부모 대비 git diff --numstat) — 운영자가 revert PR로 되돌린다"; fi
  if ! git show "$msha:$dev" > "$w/merged.yaml" 2> /dev/null; then fail merge-check "머지 커밋 $msha 의 $dev 을(를) 읽지 못했다"; fi
  digests_of "$w/merged.yaml" || fail merge-check "머지 커밋 $msha 의 $dev 을(를) YAML로 읽지 못했다"
  if (( ${#DIGESTS[@]} != 1 )) || [[ ${DIGESTS[0]} != "$DIGEST" ]]; then fail merge-check "머지 커밋 $msha 의 dev digest가 발행한 digest가 아니다 — 운영자가 revert PR로 되돌린다"; fi
  # 머지 커밋이 gitops main에 들어갔는가(App 토큰 REST compare — base...head = 머지 커밋...refs/heads/main · identical 또는 ahead여야 한다 ·
  # 머리를 브랜치 ref로 적는다 — main이라는 이름의 태그로 풀리지 않게)
  if ! gh api "repos/$GITOPS_REPO/compare/$msha...refs/heads/main" > "$w/main-compare.json" 2> "$w/main-compare.err"; then
    show 'gh api compare(gitops) 오류' "$w/main-compare.err"
    fail merge-check "머지 커밋 $msha 이(가) gitops main에 있는지 확인하지 못했다 — 운영자가 확인한다"
  fi
  if ! ms_status=$(yq -p json -o yaml -r '.status' "$w/main-compare.json" 2> "$w/yq.err"); then
    fail merge-check "gitops compare 응답을 읽지 못했다 — 운영자가 머지 커밋 $msha 을(를) 확인한다"
  fi
  case $ms_status in
    identical | ahead) ;;
    *) fail merge-check "머지 커밋 $msha 이(가) gitops main에 없다(compare $(shown "$ms_status" '^[a-z]{1,16}$')) — 운영자가 확인한다" ;;
  esac
  if [[ $P_HEAD == "$commit" ]]; then
    head_note="이 실행의 커밋 \`$commit\`"
  else
    head_note="이 실행의 커밋이 아니다(\`$(shown "$P_HEAD" "$RE_SHA")\` — 대조는 통과했다)"
  fi
  note "**머지 확인**$ctx — PR #$pr · merged_at \`$(shown "$P_MERGED_AT" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$')\` · merged_by \`$(shown "$P_MERGED_BY" "$RE_LOGIN")\`(id $(shown "$P_MERGED_BY_ID" '^[1-9][0-9]{0,19}$')) · 머지 때 head: $head_note · 경과 ${elapsed}초 · 머지 커밋 \`$msha\`(gitops main에 있다 — compare $ms_status) · 대조 통과(dev 한 줄 · digest 일치)"
  printf '결과: 통과 — dev bump PR %s 머지 확인 · 머지 커밋 %s · %s\n' "$url" "$msha" "$DIGEST"
  exit 0
}

# ---------- ⓪ 실행 조건 · 입력 · 도구 ----------
if [[ ${GITHUB_REF:-} != refs/heads/main ]]; then
  fail ref 'main 실행만 bump한다(GITHUB_REF가 refs/heads/main이 아니다)'
fi
re "${POD:-}" '^[a-z][a-z0-9-]{0,62}$' || fail input 'POD의 형식이 틀렸다(^[a-z][a-z0-9-]{0,62}$)'
[[ ${IMAGE:-} == "ghcr.io/$OWNER/$POD" ]] || fail input "IMAGE가 ghcr.io/$OWNER/$POD 이(가) 아니다"
re "${DIGEST:-}" "$RE_DIGEST" || fail input 'DIGEST가 sha256:<64자리 hex>가 아니다'
re "${GITHUB_SHA:-}" "$RE_SHA" || fail input 'GITHUB_SHA가 소문자 40자리 hex가 아니다'
re "${APP_SLUG:-}" '^[a-z0-9][a-z0-9-]{0,62}$' || fail input 'APP_SLUG의 형식이 틀렸다'
re "${BOT_SLUG:-}" '^[a-z0-9][a-z0-9-]{0,62}$' || fail input 'BOT_SLUG의 형식이 틀렸다'
re "${BOT_ID:-}" '^[1-9][0-9]{0,19}$' || fail input 'BOT_ID가 숫자가 아니다'
re "${GITHUB_REPOSITORY:-}" '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' || fail input 'GITHUB_REPOSITORY의 형식이 틀렸다'
re "${GITHUB_RUN_ID:-}" '^[1-9][0-9]{0,19}$' || fail input 'GITHUB_RUN_ID가 숫자가 아니다'
re "${GITHUB_SERVER_URL:-}" '^https://[A-Za-z0-9.-]+$' || fail input 'GITHUB_SERVER_URL의 형식이 틀렸다'
[[ -n ${GH_TOKEN:-} ]] || fail input 'GH_TOKEN이 없다(App 토큰 스텝의 출력)'
[[ -n ${MONOREPO_TOKEN:-} ]] || fail input 'MONOREPO_TOKEN이 없다(①′ 모노레포 compare 조회용 워크플로 토큰)'
# 모노레포 토큰을 내보내지 않는 변수로 옮기고 env에서 지운다 — 이 뒤의 자식(gh · git · yq …)은 env로 받지 않는다(①′ compare 한 줄에만 GH_TOKEN으로
# 준다). declare +x — 같은 이름이 env에서 왔어도 내보내기 속성을 뗀다
declare +x mono="$MONOREPO_TOKEN"
unset MONOREPO_TOKEN
[[ -n ${RUNNER_TEMP:-} && -d $RUNNER_TEMP ]] || fail input 'RUNNER_TEMP가 디렉터리가 아니다'
[[ -n ${GITOPS_DIR:-} && -d $GITOPS_DIR ]] || fail input 'GITOPS_DIR가 디렉터리가 아니다'
p=$(command -v yq || true)
[[ $p == "$RUNNER_TEMP/bin/yq" ]] || fail tool 'yq가 $RUNNER_TEMP/bin/yq(이 job의 yq 설치 스텝이 둔 것)가 아니다'
yq_out=$(yq --version 2> /dev/null || true)
[[ $yq_out == *mikefarah* && ${yq_out##* } == "$YQ_WANT" ]] || fail tool "yq가 mikefarah yq $YQ_WANT 이(가) 아니다"
command -v gh > /dev/null 2>&1 || fail tool 'gh가 PATH에 없다'
command -v git > /dev/null 2>&1 || fail tool 'git이 PATH에 없다'
w=$(mktemp -d "$RUNNER_TEMP/publish-pod-bump.XXXXXXXXXX") || fail tool '작업 디렉터리를 만들지 못했다'

image=$IMAGE
dev="apps/$POD/overlays/dev/kustomization.yaml"
run_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID"
src_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY/commit/$GITHUB_SHA"
printf '%s — %s · digest %s · 원천 커밋 %s\n' "$PROG" "$POD" "$DIGEST" "$GITHUB_SHA"

# gitops 작업 트리: 최상위 · HEAD = 가져온 origin/main의 끝 · 깨끗함 — bump 커밋은 main의 끝 위에 하나만 올린다
cd -- "$GITOPS_DIR" || fail tree 'GITOPS_DIR로 옮겨 가지 못했다'
inside=$(git rev-parse --is-inside-work-tree 2> /dev/null || true)
cdup=$(git rev-parse --show-cdup 2> /dev/null || printf 'x')
[[ $inside == true && -z $cdup ]] || fail tree 'GITOPS_DIR가 git 작업 트리의 최상위가 아니다'
main_tip=$(git rev-parse --verify --quiet 'refs/remotes/origin/main^{commit}') || fail tree 'refs/remotes/origin/main이 커밋으로 풀리지 않는다'
head_sha=$(git rev-parse --verify --quiet 'HEAD^{commit}') || fail tree 'HEAD가 커밋으로 풀리지 않는다'
[[ $head_sha == "$main_tip" ]] || fail tree 'gitops HEAD가 origin/main의 끝이 아니다'
status=$(git status --porcelain --untracked-files=no 2> /dev/null) || fail tree 'git status를 읽지 못했다'
[[ -z $status ]] || fail tree 'gitops 작업 트리에 커밋하지 않은 변경이 있다'
root=$(pwd -P)
if [[ -L $dev || ! -f $dev ]]; then fail tree "$dev 이(가) 일반 파일이 아니다(없음 · 심볼릭 링크 포함)"; fi
# 경로 중간의 심볼릭 링크로 다른 곳의 파일을 읽거나 고치지 않게 실제 경로를 대조한다
real=$(realpath -e -- "$dev") || fail tree "$dev 의 실제 경로를 구하지 못했다"
[[ $real == "$root/$dev" ]] || fail tree "$dev 의 실제 경로가 저장소 안의 그 경로가 아니다(경로의 심볼릭 링크)"

# ---------- ① 현재 값 ----------
digests_of "$dev" || { show 'yq 오류' "$w/yq.err"; fail entry "$dev 을(를) YAML로 읽지 못했다"; }
if (( ${#DIGESTS[@]} == 0 )); then
  fail entry "$dev 에 newName이 $image 인 images 항목이 없다 — 첫 항목은 사람 seed PR이 넣는다(T074 D9 · 봇은 제자리 교체만 한다)"
fi
if (( ${#DIGESTS[@]} != 1 )); then fail entry "$dev 에서 newName이 $image 인 images 항목의 digest가 하나가 아니다(${#DIGESTS[@]}줄)"; fi
cur_digest=${DIGESTS[0]}
re "$cur_digest" "$RE_DIGEST" || fail entry "$dev 의 $image digest가 sha256:<64자리 hex> 형식이 아니다"
old=${cur_digest#sha256:}
new=${DIGEST#sha256:}
if [[ $old == "$new" ]]; then
  printf '::notice::dev의 %s digest가 이미 발행한 digest와 같다(%s) — 할 일 없음(브랜치 · PR 없음)\n' "$POD" "$DIGEST"
  note "dev digest가 이미 \`$DIGEST\` — 할 일 없음(브랜치 · PR 없음)"
  printf '결과: 할 일 없음 — dev digest가 이미 같다(exit 0)\n'
  exit 0
fi

# ---------- ①′ 낡은 실행 가드 — 원천 커밋 뒤에 발행 경로를 바꾼 모노레포 main 커밋이 있으면 이 실행은 bump하지 않는다 ----------
# 모노레포 REST compare(base...head = 원천 커밋...refs/heads/main — 머리를 브랜치 ref로 적는다: main이라는 이름의 태그로 풀리지 않게) — 이 조회에만
# 모노레포 워크플로 토큰을 쓴다(App 토큰은 gitops 설치에서만 받는다). 응답의 files는 첫 쪽에만 오고 300개가 상한이다(그 이상이면 판정하지
# 않는다) · files가 목록(!!seq)이 아니면(없음 · null · map — yq에서 (.files | length)가 0 · .files[]가 빈 출력이라 「경로 밖 변경뿐」으로
# 읽힌다) 판정하지 않는다. 쪽 인자 없이 부르면 commits는 250개까지이고 마지막이 가장 새 커밋이다(요약의 sha7 — 표시용이라 꼴을 강제하지 않는다).
# 받아들인 대가: files는 원천 커밋과 main 사이의 순 변경이라 「바꿨다가 되돌린」 쌍(순 diff 0)은 낡음으로 세지 않는다 — 그때 옛 실행의 digest는
# 같은 발행 경로 내용으로 지은 이미지다
if ! GH_TOKEN="$mono" gh api "repos/$GITHUB_REPOSITORY/compare/$GITHUB_SHA...refs/heads/main" > "$w/compare.json" 2> "$w/compare.err"; then
  show 'gh api compare(모노레포) 오류' "$w/compare.err"
  fail stale-check '모노레포 main과 이 실행의 원천 커밋을 비교하지 못했다 — 낡은 실행인지 알 수 없어 멈춘다'
fi
unset mono
# 마지막 커밋은 reverse | .[0]으로 읽는다 — yq v4.53.6의 .[-1]은 빈 배열에서 오류다(identical의 commits는 [] — 2026-11-16 탐침)
if ! yq -p json -o yaml -r '.status, .ahead_by, (.files | tag), (.files | length), ((.commits // []) | reverse | .[0].sha // "")' "$w/compare.json" > "$w/compare.fields" 2> "$w/yq.err"; then
  show 'yq 오류' "$w/yq.err"
  fail stale-check '모노레포 compare 응답을 읽지 못했다 — 낡은 실행인지 알 수 없어 멈춘다'
fi
mapfile -t cf < "$w/compare.fields"
if (( ${#cf[@]} != 5 )) || ! re "${cf[1]}" "$RE_COUNT" || ! re "${cf[3]}" "$RE_COUNT"; then
  fail stale-check '모노레포 compare 응답의 꼴이 예상과 다르다 — 낡은 실행인지 알 수 없어 멈춘다'
fi
if [[ ${cf[2]} != '!!seq' ]]; then
  fail stale-check "모노레포 compare 응답의 files가 목록이 아니다($(shown "${cf[2]}" '^!![a-z]{1,8}$')) — 바뀐 파일을 알 수 없어 멈춘다"
fi
c_status=${cf[0]}
c_ahead=${cf[1]}
c_files=${cf[3]}
c_last=${cf[4]}
case $c_status in
  identical)
    printf '  낡음 가드: 모노레포 main = 원천 커밋(identical) — 계속한다\n'
    ;;
  ahead)
    if (( c_files >= 300 )); then
      fail stale-check "모노레포 compare의 바뀐 파일이 ${c_files}개다 — 응답 상한(300)에 닿아 낡음을 판정할 수 없어 멈춘다(운영자가 가장 새 실행을 본다)"
    fi
    if ! yq -p json -o yaml -r '.files[] | (.filename, (.previous_filename // ""))' "$w/compare.json" > "$w/compare.paths" 2> "$w/yq.err"; then
      fail stale-check '모노레포 compare 응답의 파일 목록을 읽지 못했다 — 낡은 실행인지 알 수 없어 멈춘다'
    fi
    stale=0
    while IFS= read -r f || [[ -n $f ]]; do
      if [[ -n $f ]] && path_hit "$f"; then
        stale=1
        break
      fi
    done < "$w/compare.paths"
    if (( stale )); then
      # 앞 7자는 형식을 확인한 sha에서만 자른다(LC_ALL=C의 자르기는 바이트 단위다)
      if re "$c_last" "$RE_SHA"; then newest7=${c_last:0:7}; else newest7='형식 밖'; fi
      printf '::notice::낡은 실행이다 — 원천 커밋 뒤의 모노레포 main 커밋(%s개 · 마지막 %s)이 발행 경로를 바꿨다 — bump하지 않는다(브랜치 · PR 없음 · 그 커밋의 publish-pod 실행을 확인한다 — 없으면 dispatch)\n' "$c_ahead" "$newest7"
      note "[stale] 낡은 실행 — 모노레포 main이 원천 커밋보다 ${c_ahead}커밋 앞서고 발행 경로(paths 네 줄)를 바꿨다(마지막 main 커밋 \`$newest7\`) — bump하지 않는다(브랜치 · PR 없음). 그 커밋에 publish-pod 실행이 없으면([skip ci] · 3,000파일 넘는 push · 워크플로 비활성) 운영자가 dispatch한다(런북 U-d)"
      printf '결과: 할 일 없음 — 낡은 실행(exit 0)\n'
      exit 0
    fi
    printf '  낡음 가드: 모노레포 main이 %s커밋 앞서지만 발행 경로 밖의 변경뿐이다 — 계속한다\n' "$c_ahead"
    ;;
  *)
    fail stale-check "모노레포 main이 원천 커밋을 포함하지 않는다(compare $(shown "$c_status" '^[a-z]{1,16}$') — behind · diverged) — 멈춘다"
    ;;
esac

# ---------- ② 제자리 교체 ----------
# sha256:<old>가 든 줄이 정확히 하나이고, 그 줄이 봇 경로 lint의 digest 줄 꼴(들여쓰기 · '- ' · 공백만)이어야 한다
mapfile -t hit < <(LC_ALL=C grep -n -F -e "sha256:$old" -- "$dev" || true)
if (( ${#hit[@]} != 1 )); then fail line "$dev 에서 sha256:${old:0:12}…가 든 줄이 ${#hit[@]}개다(정확히 하나여야 한다)"; fi
ln=${hit[0]%%:*}
cur=${hit[0]#*:}
re "$ln" '^[1-9][0-9]{0,6}$' || fail line '교체할 줄의 번호를 읽지 못했다'
re "$cur" "^[[:space:]]*(-[[:space:]]*)?digest:[[:space:]]*sha256:${old}[[:space:]]*\$" \
  || fail line "$dev 의 ${ln}번째 줄이 봇 경로 lint의 digest 줄 꼴이 아니다(값 밖에 다른 글자 — 줄 끝 주석 등) — 64자리 hex만 바꾸는 제자리 교체만 한다"
# 그 줄의 hex만 바꾼다(old · new는 64자리 hex로 확인한 값이다 — sed 식에 그대로 넣어도 된다)
sed -i -e "${ln}s/sha256:${old}/sha256:${new}/" -- "$dev"
# (가) 바뀐 것은 그 파일 하나 · 1줄 삭제 1줄 추가
ns=$(git diff "${DIFF_OPTS[@]}" --numstat 2> /dev/null) || fail replace 'git diff를 읽지 못했다'
[[ $ns == $'1\t1\t'"$dev" ]] || fail replace "교체 결과가 $dev 의 한 줄 교체가 아니다(git diff --numstat)"
# (나) -/+ 두 줄이 64자리 hex 밖에서 글자 단위로 같다(hunk 머리 뒤의 줄만 내용으로 본다)
mapfile -t dl < <(git diff "${DIFF_OPTS[@]}" -U0 -- "$dev" 2> /dev/null || true)
minus=()
plus=()
inhunk=0
for l in "${dl[@]}"; do
  if (( ! inhunk )); then
    if [[ $l == @@* ]]; then inhunk=1; fi
    continue
  fi
  case $l in
    @@*) fail replace '교체 결과의 diff에 hunk가 둘 이상이다' ;;
    -*) minus+=("${l:1}") ;;
    +*) plus+=("${l:1}") ;;
    \\*) ;;
    *) fail replace '교체 결과의 diff에 예상하지 못한 줄이 있다' ;;
  esac
done
if (( ${#minus[@]} != 1 || ${#plus[@]} != 1 )); then fail replace "교체 결과의 diff가 - 한 줄 · + 한 줄이 아니다(- ${#minus[@]} · + ${#plus[@]})"; fi
a=${minus[0]}
b=${plus[0]}
if [[ $a != *"$old"* || $b != *"$new"* || ${a/"$old"/} != "${b/"$new"/}" ]]; then fail replace '교체 결과의 -/+ 줄이 64자리 hex 밖에서 같지 않다'; fi
# (다) 여전히 YAML로 읽히고, 이 이미지의 images 항목 digest가 새 값 하나다
digests_of "$dev" || fail replace "교체한 $dev 을(를) YAML로 읽지 못했다"
if (( ${#DIGESTS[@]} != 1 )) || [[ ${DIGESTS[0]} != "$DIGEST" ]]; then fail replace "교체한 $dev 에서 읽은 digest가 발행한 digest 하나가 아니다"; fi
printf '  교체: %s %s줄 — sha256:%s… → sha256:%s…(한 줄 · hex만)\n' "$dev" "$ln" "${old:0:12}" "${new:0:12}"

# ---------- ③ 신원 · 커밋 ----------
[[ $APP_SLUG == "$BOT_SLUG" ]] || fail identity "App 토큰의 App($APP_SLUG)이 봇 목록의 App($BOT_SLUG)이 아니다 — 다른 App의 자격이면 PR이 사람 규칙으로 판정된다(커밋 전에 멈춘다)"
if ! gh api "users/${BOT_SLUG}[bot]" > "$w/user.json" 2> "$w/user.err"; then
  show 'gh api users 오류' "$w/user.err"
  fail identity "봇 계정 ${BOT_SLUG}[bot]을(를) 조회하지 못했다"
fi
if ! yq -p json -o yaml -r '.login, .id, .type' "$w/user.json" > "$w/user.fields" 2> "$w/yq.err"; then
  show 'gh api users 응답' "$w/user.json"
  fail identity '봇 계정 응답을 읽지 못했다'
fi
mapfile -t uf < "$w/user.fields"
if (( ${#uf[@]} != 3 )) || [[ ${uf[0]} != "${BOT_SLUG}[bot]" || ${uf[1]} != "$BOT_ID" || ${uf[2]} != Bot ]]; then
  printf '관찰: login %s · id %s · type %s\n' "$(shown "${uf[0]:-}" "$RE_LOGIN")" "$(shown "${uf[1]:-}" '^[1-9][0-9]{0,19}$')" "$(shown "${uf[2]:-}" '^[A-Za-z]{1,32}$')"
  fail identity "봇 계정 ${BOT_SLUG}[bot]의 login · id · type이 봇 목록(${BOT_SLUG}[bot] · $BOT_ID · Bot)과 다르다"
fi
subject="chore($POD): dev → ${new:0:12}"
msg=$w/commit-message.txt
{
  printf '%s\n\n' "$subject"
  printf 'digest: %s\n' "$DIGEST"
  printf '이전 digest: %s\n' "$cur_digest"
  printf '원천 커밋: %s\n' "$src_url"
  printf '실행 기록: %s\n' "$run_url"
  printf 'attestation: 같은 실행의 publish job이 자기 검증했다(gh attestation verify --repo · --signer-workflow · --source-ref refs/heads/main · --deny-self-hosted-runners) — 성공\n'
} > "$msg"
git add -- "$dev"
bot_name="${BOT_SLUG}[bot]"
bot_mail="${BOT_ID}+${BOT_SLUG}[bot]@users.noreply.github.com"
# 작성자 · 커미터 = 봇. 환경 변수로 준다 — git은 GIT_AUTHOR_* · GIT_COMMITTER_*를 user.name · user.email 설정보다 먼저 쓴다
if ! GIT_AUTHOR_NAME=$bot_name GIT_AUTHOR_EMAIL=$bot_mail GIT_COMMITTER_NAME=$bot_name GIT_COMMITTER_EMAIL=$bot_mail \
  git -c commit.gpgsign=false commit --quiet --no-verify --file="$msg" > "$w/commit.out" 2>&1; then
  show 'git commit 출력' "$w/commit.out"
  fail commit 'bump 커밋을 만들지 못했다'
fi
commit=$(git rev-parse --verify --quiet 'HEAD^{commit}') || fail commit 'bump 커밋을 읽지 못했다'
parent=$(git rev-parse --verify --quiet 'HEAD^1^{commit}') || fail commit 'bump 커밋의 부모를 읽지 못했다'
[[ $parent == "$main_tip" ]] || fail commit 'bump 커밋의 부모가 origin/main의 끝이 아니다'
ns=$(git diff "${DIFF_OPTS[@]}" --numstat "$main_tip" HEAD 2> /dev/null) || fail commit 'git diff를 읽지 못했다'
[[ $ns == $'1\t1\t'"$dev" ]] || fail commit "bump 커밋이 $dev 의 한 줄 교체가 아니다(git diff --numstat origin/main HEAD)"

# ---------- ④ 브랜치 ----------
branch_name="bump/dev-$POD-${GITHUB_SHA:0:7}"
# 있음 · 없음 · 조회 오류를 가른다 — ref 이름이 정확히 refs/heads/<브랜치>인 줄만 센다(remote_state · 꼬리 일치를 쓰지 않는다)
rstate=$(remote_state "$branch_name")
case $rstate in
  absent) ;;
  present) fail branch-exists "브랜치 $branch_name 이(가) 원격에 이미 있다 — 같은 원천 커밋의 bump PR이 열려 있거나 남은 브랜치다(남의 브랜치일 수 있어 지우지 않는다 — 운영자가 확인한다)" ;;
  *)
    show 'git ls-remote 오류' "$w/state.err"
    fail branch '원격 브랜치를 확인하지 못했다(git ls-remote 오류)'
    ;;
esac
# 올리기 창 — 여기서 받은 취소 신호는 on_signal이 원격 끝을 보고(자기 커밋일 때만) 정리한다. branch를 cleanup_on보다 먼저 둔다
pushing=1
if ! git push --quiet origin "HEAD:refs/heads/$branch_name" > "$w/push.out" 2>&1; then
  show '브랜치 올리기 출력' "$w/push.out"
  # 올리기가 실패로 끝나도 원격이 받았을 수 있다(연결이 끊긴 응답 등) — 원격 끝이 이 실행의 커밋이면 정리를 거쳐 실패한다
  if [[ $(remote_tip "$branch_name") == "$commit" ]]; then
    branch=$branch_name
    cleanup_on=1
    printf '관찰: 올리기는 실패로 끝났지만 원격 브랜치 %s 의 끝이 이 실행의 커밋이다 — 정리한다\n' "$branch_name"
  fi
  pushing=0
  fail push "브랜치 $branch_name 을(를) 올리지 못했다"
fi
branch=$branch_name
cleanup_on=1
pushing=0
printf '  브랜치: %s · 커밋 %s(origin/main %s 위에 하나)\n' "$branch" "$commit" "$main_tip"
note "브랜치 \`$branch\` · 커밋 \`$commit\`(origin/main \`$main_tip\` 위에 하나)"

# ---------- ⑤ PR · 브랜치 끝 확인 ----------
body=$w/pr-body.md
{
  printf '`%s` dev digest bump — `publish-pod.yml`(job bump)이 GitHub App 토큰으로 연 PR이다(T074 · 계약 gitops-repo.md §이미지·승격 「dev bump」).\n\n' "$POD"
  printf -- '- 이미지: `%s`\n' "$image"
  printf -- '- 새 digest: `%s`\n' "$DIGEST"
  printf -- '- 이전 digest: `%s`\n' "$cur_digest"
  printf -- '- 바뀐 것: `%s`의 digest 줄 하나(64자리 hex만 — 제자리 교체)\n' "$dev"
  printf -- '- 원천 커밋: %s\n' "$src_url"
  printf -- '- 실행 기록: %s\n' "$run_url"
  printf -- '- attestation: 같은 실행의 publish job이 `gh attestation verify --repo --signer-workflow --source-ref refs/heads/main --deny-self-hosted-runners`로 자기 검증했다 — 성공\n\n'
  printf 'required check `validate` · `prod-approval`이 통과하면 auto-merge(squash)로 머지된다(VD-5). auto-merge는 거는 순간의 head 커밋으로 고정했다(--match-head-commit) — 그 뒤의 이동은 워크플로의 조회와 머지 결과 대조가 잡는다. 워크플로가 머지 결과까지 기다려 대조하고, 실패하면 이 PR을 닫고 브랜치를 지운다.\n'
} > "$body"
if ! gh pr create --repo "$GITOPS_REPO" --base main --head "$branch" --title "$subject" --body-file "$body" > "$w/create.out" 2> "$w/create.err"; then
  show 'gh pr create 출력' "$w/create.out" "$w/create.err"
  fail pr-create "PR을 만들지 못했다(브랜치 $branch)"
fi
url=$({ LC_ALL=C grep -v '^[[:space:]]*$' -- "$w/create.out" || true; } | LC_ALL=C tail -n 1 | LC_ALL=C tr -d '\r')
if ! re "$url" "$RE_PR_URL"; then
  show 'gh pr create 출력' "$w/create.out" "$w/create.err"
  url=''
  fail pr-url "gh pr create의 출력이 platform-gitops PR 주소가 아니다 — PR이 만들어졌는지 운영자가 확인한다(브랜치 $branch 은(는) 지운다)"
fi
pr=${url##*/}
# PR을 연 직후 원격 브랜치의 끝이 ④에서 올린 커밋인가(promote.yml ⑦ 꼴)
tip=$(remote_tip "$branch")
if [[ $tip != "$commit" ]]; then
  printf '관찰: 브랜치 끝 %s\n' "$(shown "$tip" "$RE_SHA")"
  fail pr-tip "PR #$pr 을(를) 연 직후 원격 브랜치 $branch 의 끝이 이 실행의 커밋 $commit 이(가) 아니다 — 이 PR을 다시 열지 말고 대기 중인 검사 실행을 승인하지 않는다"
fi
printf '  PR: %s(브랜치 끝 확인 통과)\n' "$url"
note "PR $url · 브랜치 끝 확인 통과"

# ---------- ⑥ auto-merge(squash) ----------
# auto-merge를 거는 순간의 head를 고정한다(`--match-head-commit`) — 그 뒤의 이동은 ⑦ 조회와 머지 결과 대조가 잡는다
if ! gh pr merge "$pr" --repo "$GITOPS_REPO" --auto --squash --match-head-commit "$commit" > "$w/merge.out" 2> "$w/merge.err"; then
  show 'gh pr merge --auto 출력' "$w/merge.out" "$w/merge.err"
  fail auto-merge "PR #$pr 에 auto-merge를 걸지 못했다"
fi
printf '  auto-merge: 걸었다(squash · 거는 순간의 head %s 고정)\n' "$commit"

# ---------- ⑦ 머지까지 기다림(REST pulls/<n>만) ----------
polls=0
start=$SECONDS
first=1
while :; do
  polls=$((polls + 1))
  if ! gh api "repos/$GITOPS_REPO/pulls/$pr" > "$w/pr.json" 2> "$w/pr.err"; then
    show 'gh api pulls 오류' "$w/pr.err"
    fail api "PR #$pr 상태를 읽지 못했다(gh api · ${polls}번째 조회)"
  fi
  if ! read_pr "$w/pr.json"; then
    show 'PR 응답' "$w/pr.json"
    fail api "PR #$pr 응답을 읽지 못했다(JSON · 필드 수)"
  fi
  if (( first )); then
    first=0
    if [[ $P_AUTO_NULL == false ]]; then
      note "auto-merge(첫 조회) — enabled_by \`$(shown "$P_ENABLED_BY" "$RE_LOGIN")\` · merge_method \`$(shown "$P_METHOD" '^(merge|squash|rebase)$')\`"
    else
      note 'auto-merge(첫 조회) — 꺼져 있다(auto_merge null)'
    fi
  fi
  ms=$(shown "$P_MSTATE" '^[a-z_]{1,32}$')
  observed="state $(shown "$P_STATE" '^(open|closed)$') · merged $(shown "$P_MERGED" '^(true|false)$') · base $(shown "$P_BASE" '^[A-Za-z0-9._/-]{1,100}$') · mergeable_state $ms"
  if [[ $P_BASE != main ]]; then
    printf '관찰: %s\n' "$observed"
    fail base "PR #$pr 의 base가 main이 아니다 — 다른 브랜치로 머지되면 dev에 반영되지 않는다"
  fi
  if [[ $P_MERGED == true ]]; then verify_merge ''; fi
  if [[ $P_STATE == closed ]]; then
    printf '관찰: %s\n' "$observed"
    fail closed "PR #$pr 이(가) 머지되지 않은 채 닫혔다"
  fi
  if [[ $P_STATE != open ]]; then
    printf '관찰: %s\n' "$observed"
    fail api "PR #$pr 의 state가 open · closed가 아니다"
  fi
  if [[ $P_AUTO_NULL != false ]]; then
    printf '관찰: %s\n' "$observed"
    fail auto-off "PR #$pr 이(가) 열려 있는데 auto-merge가 꺼져 있다"
  fi
  if [[ $P_HEAD != "$commit" ]]; then
    printf '관찰: %s · head %s\n' "$observed" "$(shown "$P_HEAD" "$RE_SHA")"
    fail head-moved "PR #$pr 의 head가 이 실행의 커밋 $commit 이(가) 아니다"
  fi
  if (( polls >= POLL_LIMIT || SECONDS - start >= WAIT_LIMIT_SECONDS )); then
    printf '관찰: %s\n' "$observed"
    fail timeout "PR #$pr 이(가) $((SECONDS - start))초 · ${polls}회 조회 안에 머지되지 않았다 — 마지막 mergeable_state \`$ms\`(check 세부는 운영자 · 컨트롤러가 GET으로 본다)"
  fi
  # sleep을 뒤에 두고 wait로 받는다 — 취소 신호가 오면 wait가 바로 끝나고 on_signal이 정리한다
  sleep "$POLL_SECONDS" &
  wait "$!"
done
