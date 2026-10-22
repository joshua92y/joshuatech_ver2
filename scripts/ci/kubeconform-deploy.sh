#!/usr/bin/env bash
# kubeconform-deploy.sh — pod 배포 매니페스트(deploy/base)의 Kubernetes 스키마 검사 (T047 M1)
#
# 목적
#   pod 템플릿(templates/django-pod)이 만드는 배포 매니페스트 — 생성물의 deploy/base/, gitops 저장소 apps/<pod>/base로
#   복사되는 kustomize base — 가 Kubernetes 스키마에 맞는지를 모노레포 CI(.github/workflows/ci.yml job kubeconform)에서
#   미리 본다. 대상이 생기면 곧바로 검사하고, 대상이 없는 동안은 조용히 통과하되("대상 없음" · exit 0), 템플릿에 배포
#   매니페스트가 생겼는데 검사가 연결되지 않은 상태는 실패시킨다(아래 「경보선」).
#
# 사용
#   bash scripts/ci/kubeconform-deploy.sh [--root <dir>] [--generated <dir>]...
#     --root <dir>        검사할 저장소 루트. 환경 변수 KUBECONFORM_ROOT로도 준다(인자가 앞선다). 기본: 이 스크립트에서 두 단계 위
#     --generated <dir>   copier 생성물의 루트(여러 번 가능). <dir>/deploy/base를 대상에 더한다 — 없으면 그 대상의 FAIL
#   환경 변수
#     KUBECONFORM_K8S_VERSION  kubeconform -kubernetes-version (기본 master)
#     KUBECONFORM_CACHE        스키마 캐시 디렉터리(없으면 만든다). 비면 캐시 없이 — 스키마를 실행마다 내려받는다
#     GITHUB_ACTIONS=true      "대상 없음"일 때 ::notice 한 줄을 더 찍는다
#
# 종료 코드
#   0  통과("대상 없음" 포함)
#   1  검사 실패(대상의 FAIL) 또는 경보선
#   2  사용법 오류 · 도구 없음(kustomize · kubeconform) · bash 4.3 미만 — 도구가 없으면 통과가 아니라 2다(fail-closed)
#
# 대상 규칙(루트 기준). 대상을 조용히 놓치지 않게, 규칙에서 벗어난 배치는 건너뛰지 않고 그 자리의 FAIL로 드러낸다.
#   A  apps/<pod>/deploy/base/ — kustomization 파일(kustomization.yaml · kustomization.yml · Kustomization — 글자 그대로)이
#      있는 디렉터리를 렌더한다. FAIL: deploy/base에 kustomization 파일이 없음 · deploy/는 있는데 deploy/base가 없음 ·
#      이름의 대소문자가 다름(Deploy/ · Base/ — Linux에서는 다른 경로라 검사와 gitops 복사에서 빠진다) · 경로의
#      디렉터리(apps · pod · deploy · base)가 심볼릭 링크(따라가지 않는다 — 루트 밖을 읽지 않게).
#   B  templates/django-pod/deploy/(과제 문면의 경로 — 지금은 없다) — 그 아래의 kustomization 디렉터리는 렌더하고,
#      어느 kustomization 디렉터리에도 속하지 않는 *.yaml · *.yml은 파일마다 그대로 검사한다. FAIL: 경로의 어느 단계든
#      심볼릭 링크 · 디렉터리가 있는데 검사할 것이 없음.
#   C  --generated로 받은 생성물의 deploy/base(루트 밖이어도 된다 — 그때는 이름표 "<생성물 N: 디렉터리 이름>"으로 찍는다).
#      A와 같은 디렉터리면 한 번만 검사한다.
#   pod 디렉터리 이름에 공백이 있어도 된다(경로는 모두 따옴표로 다룬다). glob은 nullglob — 맞는 것이 없으면 빈 목록이다.
#   대상 찾기는 셸 glob으로 한다(find를 쓰지 않는다 — 프로세스 치환 안에서 실패한 find는 빈 목록 = "대상 없음"이 된다).
#
# 판정(대상마다) — kustomization이 있으면 `kustomize build`의 출력을, 없으면 파일 내용을
#   kubeconform -strict -ignore-missing-schemas -summary -verbose -kubernetes-version <버전> [-cache <dir>]에 넣는다
#   (-verbose는 건너뛴 객체의 Kind/이름을 PASS 줄에 드러내려고 더했다).
#   FAIL: 렌더 실패 · kubeconform exit ≠ 0(스키마 위반 · 파싱 오류 · 스키마를 내려받지 못함) · kubeconform 요약 줄을
#   읽지 못함 · 빈 렌더(객체 0개 — 빈 입력은 kubeconform이 성공으로 끝나므로 여기서 막는다) · 검증된 객체 0개(객체가
#   모두 스키마 없음으로 건너뛰어짐 — apiVersion 오타, 스키마가 없는 KUBECONFORM_K8S_VERSION 등).
#   한계: -ignore-missing-schemas는 스키마가 없는 객체를 건너뛴다. CRD(ExternalSecret 등)는 의도대로 건너뛰지만
#   apiVersion 오타(apps/v11)도 같은 이유로 건너뛴다 — 다른 객체가 하나라도 검증되면 PASS이고, 건너뛴 객체는 PASS 줄에
#   "스키마 없어 건너뜀 N(Kind/이름, …)"으로 드러난다. kustomization이 가리키는 루트 밖 디렉터리 · 원격 base는
#   kustomize가 따라간다(kustomize의 기본 load restrictor는 파일에만 걸린다 — pod base는 제 디렉터리의 파일만 쓴다).
#
# 경보선(tripwire) — templates/django-pod/template/ 아래에 배포 매니페스트로 보이는 파일이 있는데 --generated가 없으면 FAIL
#   배포 매니페스트로 보이는 파일: 경로에 이름이 deploy인 디렉터리가 있는 파일(경로 성분 단위 일치 · 대소문자 무시 —
#   {{pod_snake}}/deploy/… · Deploy/…는 걸리고, 이름에 deploy가 들었을 뿐인 deployment_utils/ · redeploy/는 걸리지 않는다) ·
#   kustomization 파일 이름(.jinja 접미사 · 대소문자 무시) · 줄 머리에 apiVersion:과 kind:가 둘 다 있는 *.yaml · *.yml(.jinja).
#   심볼릭 링크는 따라가지도 읽지도 않는다 — 링크 자신의 이름을 디렉터리 이름처럼 본다(이름이 deploy인 링크 → 다른 곳이면 걸린다).
#   templates/django-pod/template 경로 자체에 심볼릭 링크가 있으면 훑지 않고 FAIL.
#   이유: 템플릿의 매니페스트는 jinja 템플릿이라 그대로는 kubeconform에 넣을 수 없어 생성물을 검사해야 한다. 생성 단계가
#   CI에 연결되기 전에 매니페스트가 들어오면 이 검사는 "대상 없음"으로 조용히 통과해 버린다 — 그 상태를 실패로 막는다.
#   T072가 생성 단계를 연결한다(T072가 해야 할 일): CI에서 copier copy --defaults --data pod_name=sample-pod
#   templates/django-pod <출력 디렉터리>로 생성하고 그 디렉터리를 --generated로 넘긴다(그러면 경보선은 꺼지고 생성물의
#   deploy/base가 검사된다).
#   - copier는 아직 저장소의 잠금 파일(uv.lock · pnpm-lock.yaml)에 없다 — 생성 단계를 만들 때 함께 들인다.
#   - copier copy --defaults는 copier.yml의 질문 7개 전부에 기본값이 있어야 한다 — 기본값이 없는 pod_name은
#     --data pod_name=…으로 준다.
#   막지 못하는 것: 경로에 이름이 deploy인 디렉터리가 없고(k8s-deploy/ 같은 이름은 디렉터리 규칙에 걸리지 않는다), 파일
#   이름이 kustomization이 아니고, apiVersion:/kind:가 줄 머리에 글자 그대로 없는 매니페스트(예: 키 이름을 jinja로 만드는 경우).
#
# 출력: 대상마다 "[PASS] <상대 경로> — 객체 N개" 또는 "[FAIL] <상대 경로> — <사유 요지>", 마지막에
#   "결과: PASS|FAIL · 대상 N · 실패 M"(대상 = PASS/FAIL 줄의 수 — 경보선 · 발견 규칙 위반 포함).
# 원칙: 루트 밖을 읽거나 쓰지 않는다(예외: 스키마 캐시 · --generated 경로). 임시 파일을 만들지 않는다(렌더 결과는 변수와
#   파이프로만 다룬다 — here-string도 쓰지 않는다). 같은 입력이면 출력이 같다(LC_ALL=C — kubeconform은 병렬로 검사해 줄
#   순서가 바뀌므로 정렬해 찍는다). 경로는 루트 기준 상대 경로 또는 생성물 이름표로만 찍는다 — 도구의 오류 문구에 든 절대
#   경로(POSIX · Windows 표기)도 지운다. 찍는 글자의 제어 문자는 ?로 바꾼다(한 항목 = 한 줄).
# 요구: bash 4.3 이상(globstar가 심볼릭 링크 디렉터리 안으로 내려가지 않는 동작) · kustomize · kubeconform.
#   그 밖의 외부 명령은 mkdir(스키마 캐시 디렉터리를 만들 때)과 cygpath(Windows Git Bash에서만 — 경로 표기 지우기)뿐이다.
set -euo pipefail
export LC_ALL=C

readonly PROG=kubeconform-deploy

# ---------- 출력 도우미(셸 내장만 — 도구 확인 전에도 쓴다) ----------
# safe <글자> — 제어 문자(개행 · CR · 탭 · ESC …)를 ?로 바꾼다: 한 항목이 한 줄로 남고, 줄 머리에 워크플로 명령(::)이 끼어들지 않는다
safe() {
  local s=$1
  printf '%s' "${s//[[:cntrl:]]/?}"
}

usage() {
  printf '사용법: bash scripts/ci/kubeconform-deploy.sh [--root <dir>] [--generated <dir>]...\n'
}

# usage_error <메시지> — exit 2. 경로 값은 되풀이하지 않는다(절대 경로가 로그에 남지 않게)
usage_error() {
  printf '%s: 사용법 오류 — %s\n' "$PROG" "$1" >&2
  usage >&2
  exit 2
}

if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3) )); then
  printf '%s: bash 4.3 이상이 필요하다(지금 %s)\n' "$PROG" "$BASH_VERSION" >&2
  exit 2
fi
shopt -s nullglob dotglob globstar

# ---------- 인자 ----------
root_arg=${KUBECONFORM_ROOT:-}
root_from=KUBECONFORM_ROOT
gen_args=()
while (( $# > 0 )); do
  case $1 in
    --root)
      if (( $# < 2 )) || [[ -z $2 ]]; then usage_error '--root에 디렉터리를 준다'; fi
      root_arg=$2
      root_from=--root
      shift 2
      ;;
    --root=?*)
      root_arg=${1#--root=}
      root_from=--root
      shift
      ;;
    --generated)
      if (( $# < 2 )) || [[ -z $2 ]]; then usage_error '--generated에 디렉터리를 준다'; fi
      gen_args+=("$2")
      shift 2
      ;;
    --generated=?*)
      gen_args+=("${1#--generated=}")
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage_error "알 수 없는 인자: $(safe "$1")"
      ;;
  esac
done

# ---------- 도구(없으면 exit 2 — 통과로 넘어가지 않는다) ----------
missing=()
for t in kustomize kubeconform; do
  if ! command -v "$t" >/dev/null 2>&1; then missing+=("$t"); fi
done
if (( ${#missing[@]} > 0 )); then
  printf '%s: 도구 없음 — %s (PATH에 없다). 검사하지 못했으므로 통과가 아니다(exit 2)\n' "$PROG" "${missing[*]}" >&2
  exit 2
fi

# ---------- 루트 · 생성물 · 캐시 경로(루트로 들어가기 전에 절대 경로로 푼다) ----------
if [[ -z $root_arg ]]; then
  src=${BASH_SOURCE[0]}
  if [[ $src == */* ]]; then sdir=${src%/*}; else sdir=.; fi
  root_arg=$sdir/../..
  root_from='스크립트 위치'
fi
if [[ ! -d $root_arg ]]; then usage_error "루트 디렉터리가 없다($root_from)"; fi
if ! ROOT=$(cd -- "$root_arg" && pwd -P); then usage_error "루트 디렉터리로 들어갈 수 없다($root_from)"; fi

gen_abs=()    # 생성물 루트의 물리 경로(없는 디렉터리면 빈 값)
gen_name=()   # 이름표에 쓸 디렉터리 이름(경로의 마지막 부분 — 절대 경로를 찍지 않는다)
for g in ${gen_args[@]+"${gen_args[@]}"}; do
  name=$g
  while [[ $name == */ && $name != / ]]; do name=${name%/}; done
  name=${name##*/}
  if [[ -z $name ]]; then name=$g; fi
  gen_name+=("$name")
  if [[ -d $g ]] && abs=$(cd -- "$g" && pwd -P); then gen_abs+=("$abs"); else gen_abs+=(''); fi
done

K8S_VERSION=${KUBECONFORM_K8S_VERSION:-master}
KC_CACHE=''
cache_note='없음(스키마를 실행마다 내려받는다)'
if [[ -n ${KUBECONFORM_CACHE:-} ]]; then
  if mkdir -p -- "$KUBECONFORM_CACHE" 2>/dev/null && KC_CACHE=$(cd -- "$KUBECONFORM_CACHE" && pwd -P); then
    cache_note='사용'
  else
    KC_CACHE=''
    cache_note='디렉터리를 만들 수 없어 쓰지 않는다'
  fi
fi

# ---------- 도구 오류 문구의 절대 경로 지우기 ----------
# 등록 순서 = 바꾸는 순서. 긴(안쪽) 경로부터 등록한다: 생성물 → 루트 → 스키마 캐시 → 임시 디렉터리 → HOME.
SCRUB_FROM=()
SCRUB_TO=()
HAVE_CYGPATH=0
if command -v cygpath >/dev/null 2>&1; then HAVE_CYGPATH=1; fi

# add_scrub <절대 경로> <바꿀 글자> — 그 경로의 표기(그대로 · Windows의 \ 표기와 / 표기)를 등록한다
add_scrub() {
  local p=$1 w
  if [[ -z $p || $p == / ]]; then return 0; fi
  SCRUB_FROM+=("$p")
  SCRUB_TO+=("$2")
  if (( HAVE_CYGPATH )); then
    if w=$(cygpath -w -- "$p" 2>/dev/null) && [[ -n $w && $w != "$p" ]]; then SCRUB_FROM+=("$w"); SCRUB_TO+=("$2"); fi
    if w=$(cygpath -m -- "$p" 2>/dev/null) && [[ -n $w && $w != "$p" ]]; then SCRUB_FROM+=("$w"); SCRUB_TO+=("$2"); fi
  fi
}

# scrub <글자> — 등록한 절대 경로를 바꿔 찍는다(패턴 · 바꿀 글자 모두 글자 그대로 — 따옴표)
scrub() {
  local s=$1 i
  for i in ${SCRUB_FROM[@]+"${!SCRUB_FROM[@]}"}; do
    s=${s//"${SCRUB_FROM[i]}"/"${SCRUB_TO[i]}"}
  done
  printf '%s' "$s"
}

for i in ${gen_abs[@]+"${!gen_abs[@]}"}; do
  a=${gen_abs[i]}
  if [[ -n $a && $a != "$ROOT" && $a != "$ROOT"/* ]]; then add_scrub "$a" "<생성물 $((i + 1)): ${gen_name[i]}>"; fi
done
add_scrub "$ROOT" .
add_scrub "$KC_CACHE" '<스키마 캐시>'
add_scrub "${RUNNER_TEMP:-}" '<임시>'
add_scrub "${TMPDIR:-}" '<임시>'
add_scrub "${HOME:-}" '~'

cd -- "$ROOT"

# ---------- 검사 항목 목록(순서대로 찍는다) ----------
# kind: kust(디렉터리를 kustomize build) · file(파일을 그대로) · fail(발견 단계에서 정해진 FAIL — msg가 사유)
IT_KIND=()
IT_PATH=()
IT_LABEL=()
IT_MSG=()
add_item() {
  IT_KIND+=("$1")
  IT_PATH+=("$2")
  IT_LABEL+=("$3")
  IT_MSG+=("${4:-}")
}
declare -A SEEN=()   # 검사에 넣은 kustomization 디렉터리(물리 경로) — A와 C의 중복 방지
NOTES=()

readonly MSG_SYMLINK='심볼릭 링크 — 따라가지 않는다(루트 밖을 읽지 않게). 실제 디렉터리 · 파일로 둔다'
readonly MSG_CASE='디렉터리 이름의 대소문자가 규칙과 다르다(규칙: apps/<pod>/deploy/base) — Linux에서는 다른 경로라 검사와 gitops 복사에서 빠진다'
readonly MSG_NOKUST='kustomization 파일(kustomization.yaml · kustomization.yml · Kustomization)이 없다 — pod 배포 매니페스트는 kustomize base다'

# has_kust <디렉터리> — kustomize가 읽는 이름(글자 그대로 kustomization.yaml · kustomization.yml · Kustomization)의 파일이
#   있으면 0. 이름은 실제 디렉터리 항목과 글자 그대로 비교한다 — 대소문자를 가리지 않는 파일 시스템(Windows)에서
#   [[ -f dir/kustomization.yaml ]]는 KUSTOMIZATION.YAML에도 참이 되지만, Linux의 kustomize는 그 파일을 읽지 않는다.
has_kust() {
  local e
  for e in "$1"/*; do
    case ${e##*/} in
      kustomization.yaml | kustomization.yml | Kustomization)
        if [[ -f $e ]]; then return 0; fi
        ;;
    esac
  done
  return 1
}

# has_symlink_component <상대 경로> — 경로의 앞부분(a · a/b · a/b/c …) 가운데 심볼릭 링크가 하나라도 있으면 0
#   (glob은 경로 앞부분의 심볼릭 링크를 따라가므로, 대상 경로의 모든 단계를 본다)
has_symlink_component() {
  local rest=$1 acc=''
  while [[ -n $rest ]]; do
    if [[ $rest == */* ]]; then
      acc=${acc:+$acc/}${rest%%/*}
      rest=${rest#*/}
    else
      acc=${acc:+$acc/}$rest
      rest=''
    fi
    if [[ -L $acc ]]; then return 0; fi
  done
  return 1
}

# has_api_and_kind <파일> — 줄 머리에 apiVersion:과 kind:가 둘 다 있으면 0(경보선의 내용 규칙)
has_api_and_kind() {
  local line api=0 kind=0
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    case $line in
      apiVersion:*) api=1 ;;
      kind:*) kind=1 ;;
    esac
    if (( api && kind )); then return 0; fi
  done < "$1"
  return 1
}

# looks_like_manifest <template/ 기준 상대 경로> <파일> — 배포 매니페스트로 보이면 0(경보선 — 머리 주석의 세 규칙)
looks_like_manifest() {
  local rel=$1 f=$2 dirs='' lname
  if [[ $rel == */* ]]; then dirs=${rel%/*}; fi
  # 심볼릭 링크는 따라가지 않는다(globstar도 그 안으로 내려가지 않는다) — 링크 자신의 이름도 디렉터리 이름처럼 본다
  if [[ -L $f ]]; then dirs=$rel; fi
  dirs=${dirs,,}
  # 경로 성분 단위 일치: 이름이 deploy인 디렉터리만(deployment_utils/ · redeploy/는 아니다). 양끝에 /를 붙여 첫 · 끝 성분도 잡는다
  if [[ "/$dirs/" == */deploy/* ]]; then return 0; fi
  lname=${rel##*/}
  lname=${lname,,}
  lname=${lname%.jinja}
  case $lname in
    kustomization.yaml | kustomization.yml | kustomization) return 0 ;;
    *.yaml | *.yml) ;;
    *) return 1 ;;
  esac
  if [[ -L $f || ! -f $f ]]; then return 1; fi   # 심볼릭 링크는 읽지 않는다(루트 밖을 읽지 않게)
  has_api_and_kind "$f"
}

# ---------- 경보선 ----------
T=templates/django-pod/template
trip=()
if (( ${#gen_args[@]} == 0 )) && [[ -d $T ]]; then
  if has_symlink_component "$T"; then
    add_item fail '' "$T" "$MSG_SYMLINK"
  else
    for f in "$T"/**; do
      if [[ $f == "$T/" ]]; then continue; fi
      if [[ -d $f && ! -L $f ]]; then continue; fi   # 디렉터리는 그 안의 파일로 본다
      rel=${f#"$T"/}
      if looks_like_manifest "$rel" "$f"; then trip+=("$rel"); fi
    done
  fi
fi
if (( ${#trip[@]} > 0 )); then
  more=''
  if (( ${#trip[@]} > 1 )); then more=" 외 $(( ${#trip[@]} - 1 ))개"; fi
  add_item fail '' "$T" "경보선: 배포 매니페스트로 보이는 템플릿 파일 ${#trip[@]}개(예: ${trip[0]}${more})가 있는데 --generated가 없다. 템플릿의 매니페스트는 jinja 템플릿이라 그대로 검사할 수 없다 — CI에 생성 단계(copier copy --defaults --data pod_name=sample-pod templates/django-pod <출력 디렉터리>)를 더하고 그 결과 디렉터리를 --generated로 넘긴다(T072)"
fi

# ---------- A: apps/<pod>/deploy/base ----------
# deploy · base는 대소문자를 무시하고 찾는다(nocaseglob — glob 문자가 있어야 켜지므로 [d]eploy · [b]ase로 쓴다):
# 찾은 실제 이름이 규칙과 글자까지 같지 않으면 FAIL로 드러낸다.
for pod in apps/*; do
  if [[ ! -d $pod ]]; then continue; fi
  shopt -s nocaseglob
  deps=("$pod"/[d]eploy)
  shopt -u nocaseglob
  for dep in ${deps[@]+"${deps[@]}"}; do
    if [[ ${dep##*/} != deploy ]]; then add_item fail '' "$dep" "$MSG_CASE"; continue; fi
    if has_symlink_component "$dep"; then add_item fail '' "$dep" "$MSG_SYMLINK"; continue; fi   # apps · <pod> · deploy
    if [[ ! -d $dep ]]; then add_item fail '' "$dep" '디렉터리가 아니다'; continue; fi
    shopt -s nocaseglob
    bases=("$dep"/[b]ase)
    shopt -u nocaseglob
    if (( ${#bases[@]} == 0 )); then
      add_item fail '' "$dep" 'deploy/는 있는데 deploy/base가 없다(규칙: apps/<pod>/deploy/base)'
      continue
    fi
    for b in "${bases[@]}"; do
      if [[ ${b##*/} != base ]]; then add_item fail '' "$b" "$MSG_CASE"; continue; fi
      if [[ -L $b ]]; then add_item fail '' "$b" "$MSG_SYMLINK"; continue; fi
      if [[ ! -d $b ]]; then add_item fail '' "$b" '디렉터리가 아니다'; continue; fi
      if ! has_kust "$b"; then add_item fail '' "$b" "$MSG_NOKUST"; continue; fi
      add_item kust "$b" "$b"
      SEEN["$ROOT/$b"]=1
    done
  done
done

# ---------- B: templates/django-pod/deploy/ ----------
B=templates/django-pod/deploy
if [[ -e $B || -L $B ]]; then
  if has_symlink_component "$B"; then
    add_item fail '' "$B" "$MSG_SYMLINK"
  elif [[ ! -d $B ]]; then
    add_item fail '' "$B" '디렉터리가 아니다'
  else
    b_before=${#IT_KIND[@]}
    kdirs=()
    for d in "$B"/**/; do   # $B/ 자신과 모든 하위 디렉터리
      d=${d%/}
      if [[ -L $d ]]; then continue; fi   # 심볼릭 링크는 아래 항목 검사에서 FAIL로 드러난다
      if has_kust "$d"; then
        kdirs+=("$d")
        add_item kust "$d" "$d"
      fi
    done
    for f in "$B"/**; do
      if [[ $f == "$B/" ]]; then continue; fi
      if [[ -L $f ]]; then add_item fail '' "$f" "$MSG_SYMLINK"; continue; fi
      if [[ ! -f $f ]]; then continue; fi
      case ${f,,} in
        *.yaml | *.yml) ;;
        *) continue ;;
      esac
      covered=0
      for d in ${kdirs[@]+"${kdirs[@]}"}; do
        if [[ $f == "$d"/* ]]; then covered=1; break; fi
      done
      if (( covered == 0 )); then add_item file "$f" "$f"; fi
    done
    if (( ${#IT_KIND[@]} == b_before )); then
      add_item fail '' "$B" '디렉터리가 있는데 검사할 것이 없다(kustomization 디렉터리도 *.yaml · *.yml 파일도 없다)'
    fi
  fi
fi

# ---------- C: --generated ----------
for i in ${gen_args[@]+"${!gen_args[@]}"}; do
  n=$((i + 1))
  a=${gen_abs[i]}
  if [[ -z $a ]]; then
    add_item fail '' "<생성물 $n: ${gen_name[i]}>" '생성물 디렉터리가 없다(--generated)'
    continue
  fi
  if [[ $a == "$ROOT" ]]; then glabel=.
  elif [[ $a == "$ROOT"/* ]]; then glabel=${a#"$ROOT"/}
  else glabel="<생성물 $n: ${gen_name[i]}>"
  fi
  gb=$a/deploy/base
  label=$glabel/deploy/base
  if [[ -L $a/deploy || -L $gb ]]; then add_item fail '' "$label" "$MSG_SYMLINK"; continue; fi
  if [[ ! -d $gb ]]; then add_item fail '' "$label" 'deploy/base가 없다 — copier 생성물의 루트를 --generated로 넘겼는가'; continue; fi
  if ! has_kust "$gb"; then add_item fail '' "$label" "$MSG_NOKUST"; continue; fi
  if [[ -n ${SEEN["$gb"]+x} ]]; then
    NOTES+=("--generated $n은 규칙 A가 찾은 $label와 같은 디렉터리다 — 한 번만 검사한다")
    continue
  fi
  SEEN["$gb"]=1
  add_item kust "$gb" "$label"
done

# ---------- 판정 ----------
KC_ARGS=(-strict -ignore-missing-schemas -summary -verbose -kubernetes-version "$K8S_VERSION")
if [[ -n $KC_CACHE ]]; then KC_ARGS+=(-cache "$KC_CACHE"); fi
readonly RE_SUMMARY='^Summary: ([0-9]+) resources? found .* - Valid: ([0-9]+), Invalid: ([0-9]+), Errors: ([0-9]+), Skipped: ([0-9]+)$'
readonly RE_SKIP='^stdin - (.+) ([^ ]+) skipped$'   # kubeconform v0.8.0 -verbose: "stdin - <이름> <Kind> skipped"

N_ITEMS=0
N_FAIL=0
emit_pass() {
  N_ITEMS=$((N_ITEMS + 1))
  printf '[PASS] %s — %s\n' "$(safe "$(scrub "$1")")" "$(safe "$2")"
}
emit_fail() {
  N_ITEMS=$((N_ITEMS + 1))
  N_FAIL=$((N_FAIL + 1))
  printf '[FAIL] %s — %s\n' "$(safe "$(scrub "$1")")" "$(safe "$(scrub "$2")")"
}

# SORT_BUF를 바이트 순(LC_ALL=C)으로 제자리 정렬한다 — 외부 sort를 쓰지 않는다(Windows에서 PATH에 따라 sort.exe가 잡힌다)
SORT_BUF=()
sort_buf() {
  local i j tmp
  for ((i = 1; i < ${#SORT_BUF[@]}; i++)); do
    tmp=${SORT_BUF[i]}
    j=$((i - 1))
    while (( j >= 0 )) && [[ ${SORT_BUF[j]} > $tmp ]]; do
      SORT_BUF[j+1]=${SORT_BUF[j]}
      j=$((j - 1))
    done
    SORT_BUF[j+1]=$tmp
  done
}

# join_buf <구분자> <최대 개수> — SORT_BUF의 앞 원소를 잇는다(넘치면 " 외 N")
join_buf() {
  local sep=$1 max=$2 out='' i
  for ((i = 0; i < ${#SORT_BUF[@]} && i < max; i++)); do out+="${out:+$sep}${SORT_BUF[i]}"; done
  if (( ${#SORT_BUF[@]} > max )); then out+=" 외 $(( ${#SORT_BUF[@]} - max ))"; fi
  printf '%s' "$out"
}

# gist <글자> — 여러 줄 오류를 한 줄 요지로: CR을 지우고 빈 줄을 버린 뒤 앞의 3줄을 " | "로 잇는다
gist() {
  local rest=${1//$'\r'/} line out='' k=0
  while [[ -n $rest ]] && (( k < 3 )); do
    line=${rest%%$'\n'*}
    if [[ $rest == *$'\n'* ]]; then rest=${rest#*$'\n'}; else rest=''; fi
    if [[ -z ${line//[[:space:]]/} ]]; then continue; fi
    out+="${out:+ | }$line"
    k=$((k + 1))
  done
  printf '%s' "${out:-(메시지 없음)}"
}

# check_target <kust|file> <경로> <이름표>
check_target() {
  local kind=$1 path=$2 label=$3 rendered err out rc rest line summary=0 n=0 v=0 inv=0 er=0 sk=0
  local -a errs=() skips=()
  if [[ $kind == kust ]]; then
    if ! rendered=$(kustomize build "$path" 2>/dev/null); then
      # 실패는 이미 정해졌다. 사유만 한 번 더 받는다(stdout은 버린다) — 이 두 번째 실행의 종료 코드는 판정에 쓰지 않는다
      err=$(kustomize build "$path" 2>&1 >/dev/null) || true
      emit_fail "$label" "렌더 실패(kustomize build): $(gist "$err")"
      return 0
    fi
  else
    if ! rendered=$(< "$path"); then
      emit_fail "$label" '파일을 읽지 못했다'
      return 0
    fi
  fi

  # pipefail: 앞 단계(printf)가 실패해도 rc가 0이 아니다
  out=$(printf '%s\n' "$rendered" | kubeconform "${KC_ARGS[@]}" 2>&1) && rc=0 || rc=$?
  rest=${out//$'\r'/}
  while [[ -n $rest ]]; do
    line=${rest%%$'\n'*}
    if [[ $rest == *$'\n'* ]]; then rest=${rest#*$'\n'}; else rest=''; fi
    if [[ $line =~ $RE_SUMMARY ]]; then
      summary=1
      n=${BASH_REMATCH[1]} v=${BASH_REMATCH[2]} inv=${BASH_REMATCH[3]} er=${BASH_REMATCH[4]} sk=${BASH_REMATCH[5]}
    elif [[ $line =~ $RE_SKIP ]]; then
      skips+=("${BASH_REMATCH[2]}/${BASH_REMATCH[1]}")
    elif [[ $line == *' is valid' ]]; then
      :
    elif [[ -n ${line//[[:space:]]/} ]]; then
      errs+=("$line")
    fi
  done

  if (( summary == 0 )); then
    emit_fail "$label" "kubeconform의 요약 줄을 읽지 못했다(exit $rc): $(gist "$out")"
    return 0
  fi
  if (( rc != 0 || inv > 0 || er > 0 )); then
    SORT_BUF=(${errs[@]+"${errs[@]}"})
    sort_buf
    emit_fail "$label" "스키마 검사 실패(위반 ${inv} · 오류 ${er} · 객체 ${n}개 · kubeconform exit ${rc}): $(join_buf ' | ' 3)"
    return 0
  fi
  # 빈 렌더: 빈 출력 · 주석이나 문서 구분자뿐 — kubeconform은 이것을 "0 resource found"와 exit 0으로 끝낸다
  if (( n == 0 )); then
    emit_fail "$label" '빈 렌더 — 객체 0개(빈 입력은 kubeconform이 성공으로 끝나므로 실패로 본다)'
    return 0
  fi
  SORT_BUF=(${skips[@]+"${skips[@]}"})
  sort_buf
  # 전부 건너뜀: 스키마로 검증된 객체가 하나도 없다 — 이 PASS는 아무것도 검사하지 않은 PASS다
  if (( v == 0 )); then
    emit_fail "$label" "검증된 객체 0개 — 객체 ${n}개가 모두 스키마가 없어 건너뛰어졌다($(join_buf ', ' 5)). apiVersion 오타 · KUBECONFORM_K8S_VERSION · 스키마 위치를 확인한다"
    return 0
  fi
  local msg="객체 ${n}개"
  if (( sk > 0 )); then msg+=" · 스키마 없어 건너뜀 ${sk}($(join_buf ', ' 5))"; fi
  emit_pass "$label" "$msg"
}

kv=$(kustomize version 2>/dev/null) || kv='(버전 확인 실패)'
kv=${kv%%$'\n'*}
cv=$(kubeconform -v 2>/dev/null) || cv='(버전 확인 실패)'
cv=${cv%%$'\n'*}
printf '%s — pod 배포 매니페스트 스키마 검사(kustomize build → kubeconform -strict)\n' "$PROG"
printf '  도구: kustomize %s · kubeconform %s · 스키마 버전 %s · 스키마 캐시 %s\n' "$(safe "${kv//$'\r'/}")" "$(safe "${cv//$'\r'/}")" "$(safe "$K8S_VERSION")" "$cache_note"
for note in ${NOTES[@]+"${NOTES[@]}"}; do printf '  참고: %s\n' "$(safe "$(scrub "$note")")"; done

for i in ${IT_KIND[@]+"${!IT_KIND[@]}"}; do
  if [[ ${IT_KIND[i]} == fail ]]; then
    emit_fail "${IT_LABEL[i]}" "${IT_MSG[i]}"
  else
    check_target "${IT_KIND[i]}" "${IT_PATH[i]}" "${IT_LABEL[i]}"
  fi
done

if (( N_ITEMS == 0 )); then
  printf '대상 없음 — apps/<pod>/deploy/base · templates/django-pod/deploy/ · --generated가 모두 없고, 템플릿에 배포 매니페스트도 없다(경보선 해당 없음)\n'
  if [[ ${GITHUB_ACTIONS:-} == true ]]; then
    printf '::notice title=kubeconform-deploy::대상 없음 — 검사할 pod 배포 매니페스트가 아직 없다(T072가 템플릿 생성 단계를 연결하면 생성물을 검사한다)\n'
  fi
fi
if (( N_FAIL > 0 )); then result=FAIL; else result=PASS; fi
printf '결과: %s · 대상 %d · 실패 %d\n' "$result" "$N_ITEMS" "$N_FAIL"
if (( N_FAIL > 0 )); then exit 1; fi
exit 0
