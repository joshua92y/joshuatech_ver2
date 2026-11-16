#!/usr/bin/env bash
# publish-pod-assert-image.sh — publish-pod 이미지 단언(T074 · .github/workflows/publish-pod.yml job build-check · publish)
#
# 목적
#   publish-pod가 만든 identity-admin 이미지가 배포 계약(contracts/pod-template.md 이미지 행 · 설계 design/t074-design.md D6)을 지키는지
#   push 전(적재 빌드 — local)과 push 뒤(레지스트리 — registry)에 같은 코드로 단언한다. 하나라도 어긋나면 exit 1이고, 워크플로는 그 뒤의
#   push · attest · gitops bump를 하지 않는다.
#
# 사용: bash scripts/ci/publish-pod-assert-image.sh(입력은 환경 변수뿐 — 워크플로가 env:로 넘긴다)
#   ASSERT_MODE  local     적재(load) 빌드가 로컬 docker에 남긴 이미지(IMAGE_REF = ghcr.io/joshua92y/identity-admin:<태그>)를 본다.
#                registry  push한 digest(IMAGE_REF = ghcr.io/joshua92y/identity-admin@sha256:<64hex>)를 본다 — 먼저 docker buildx imagetools
#                          inspect로 매니페스트가 단일 매니페스트(OCI image manifest 또는 Docker v2 schema 2)이고 index · list가 아님을 보고,
#                          docker pull(digest)을 한 뒤 아래 단언을 한다.
#   IMAGE_REF    위 꼴(그 밖은 사용 오류)
#   EXPECT_SHA   기대 커밋(github.sha — 소문자 40자리 hex)
#   RUNNER_TEMP · TMPDIR   작업 디렉터리를 만들 곳(RUNNER_TEMP → TMPDIR → /tmp)
#   GITHUB_STEP_SUMMARY    있으면 job 요약에 줄을 남긴다(끝의 시간 줄은 일찍 멈춰도 남는다 — promote.yml의 on_exit 꼴)
#
# 단언(두 모드 공통 — 같은 코드)
#   1. Os/Architecture = linux/arm64(Variant는 보지 않는다) · Config.User = 10001:10001(deploy/base securityContext와 같은 숫자 UID:GID)
#   2. 라벨 org.opencontainers.image.revision = EXPECT_SHA
#   3. Config.Env에 APP_GIT_SHA=<EXPECT_SHA>와 APP_VERSION=sha-<EXPECT_SHA>가 각각 정확히 하나(그 이름의 항목도 각각 하나). 라벨만 보면
#      metadata 라벨이 섞여도 통과하므로 값의 원천인 ENV까지 본다(둘 다 Dockerfile의 APP_GIT_SHA · APP_VERSION build-arg에서 온다).
#   4. 최상위 허용 목록: docker create → docker export | tar -tf - 로 /src의 자식 = {apps} · /src/apps의 자식 = {identity-admin} ·
#      /src/apps/identity-admin의 자식 = {.venv, identity_admin, manage.py, pyproject.toml, uv.lock}(apps/identity-admin/README.md 「이미지
#      최상위」의 주장을 실물에서 본다 · /src/apps 줄은 설계 D6에 더한 것이다). 만든 컨테이너는 EXIT trap이 지운다.
#   값은 docker의 --format 템플릿(Go text/template의 printf "%q" — 큰따옴표로 감싸고 줄바꿈 · 따옴표를 이스케이프한다)으로 읽는다(jq를 쓰지
#   않는다). %q 덕분에 값 안의 줄바꿈이 줄을 나누지 못한다(ENV 하나에 줄바꿈을 넣어 'APP_GIT_SHA=…' 줄을 만드는 꼴을 막는다).
#
# 출력 위생(설계 CD-21)
#   라벨 · Env · tar 이름 · docker 출력과 오류처럼 이미지 · 레지스트리가 고른 글자는 ::stop-commands::<실행마다 새 토큰> … ::<토큰>:: 구간
#   안에서만 찍는다(제어 문자는 지운다). docker · tar의 stdout · stderr는 모두 파일로 받는다(GitHub 러너는 stderr의 워크플로 명령도 해석한다).
#   구간 밖에는 이 스크립트가 만든 글자와 형식을 확인한 값(IMAGE_REF · EXPECT_SHA · 허용한 미디어 타입)만 찍는다. 오류는 stdout의
#   '::error::publish-pod-assert-image [<까닭 코드>] <설명>' 한 줄이다(까닭 코드: usage · tool · mediatype · pull · inspect · platform ·
#   user · label · env · export · tree).
# 종료 코드: 0 = 통과 · 1 = 단언 실패 · 사용 오류 · 도구 없음(검사하지 못했으면 통과가 아니다).
# 요구: bash 4 이상 · docker(registry 모드는 buildx 플러그인) · tar · mktemp · sort · awk · tr · date(GNU). 토큰은 /proc의 uuid →
#   od(/dev/urandom) → $RANDOM 순으로 만든다. 네트워크는 registry 모드의 docker(레지스트리 읽기)뿐이다.
set -euo pipefail
export LC_ALL=C

readonly PROG=publish-pod-assert-image
readonly IMAGE_REPO=ghcr.io/joshua92y/identity-admin
readonly IMAGE_REPO_RE='ghcr\.io/joshua92y/identity-admin'
readonly POD_DIR=identity-admin
readonly MT_OCI=application/vnd.oci.image.manifest.v1+json
readonly MT_DOCKER=application/vnd.docker.distribution.manifest.v2+json
# docker image inspect · buildx imagetools inspect의 --format 템플릿(값마다 한 번 — 줄 하나 = 값 하나)
readonly T_OS='{{printf "%q" .Os}}'
readonly T_ARCH='{{printf "%q" .Architecture}}'
readonly T_USER='{{printf "%q" .Config.User}}'
readonly T_LABEL='{{printf "%q" (index .Config.Labels "org.opencontainers.image.revision")}}'
readonly T_ENV='{{range .Config.Env}}{{printf "%q\n" .}}{{end}}'
# imagetools 템플릿은 {{.Manifest로 시작하지 않게 printf로 감싼다 — buildx v0.33.0 전(v0.31.1–v0.32.1 util/imagetools/printers.go:128
# `strings.HasPrefix(format, "{{.Manifest")`)은 그렇게 시작하는 템플릿을 무시하고 매니페스트 표 전체를 찍는다(v0.33.0부터 정확히 {{.Manifest}}만
# — isWholeManifestTemplate). 2026-11-16 이 PC의 buildx v0.37.2에서 {{.Manifest.MediaType}}와 같은 값을 냄을 index · 단일 매니페스트로 실측했다
readonly T_MEDIATYPE='{{printf "%s" .Manifest.MediaType}}'

# ---------- 상태(EXIT trap이 쓴다) ----------
mode=${ASSERT_MODE:-}
step='이미지 단언'
case $mode in
  local | registry) step="이미지 단언($mode)" ;;
esac
t0=$(date -u +%s)
w=''
cid=''

# EXIT trap — 만든 컨테이너와 작업 디렉터리(이 스크립트가 mktemp로 만든 publish-pod-assert.* 만)를 지우고 job 요약에 시간 줄을 남긴다.
# on_exit는 아래 trap on_exit EXIT로 불린다 — shellcheck는 trap 호출을 세지 않는다(SC2329)
# shellcheck disable=SC2329
on_exit() {
  local rc=$? t1
  if [[ -n $cid ]]; then docker rm -f "$cid" > /dev/null 2>&1 || true; fi
  if [[ -n $w && -d $w && ${w##*/} == publish-pod-assert.* ]]; then rm -rf -- "$w"; fi
  t1=$(date -u +%s)
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then
    printf -- '- **%s** · 시작 %s · 종료 %s · %d초 · exit %d\n' "$step" \
      "$(date -u -d "@$t0" +%FT%TZ)" "$(date -u -d "@$t1" +%FT%TZ)" "$((t1 - t0))" "$rc" >> "$GITHUB_STEP_SUMMARY" || true
  fi
  exit "$rc"
}
trap on_exit EXIT

# note <글자> — job 요약에 한 줄(이 스크립트가 만든 글자와 형식을 확인한 값만 넣는다)
note() {
  if [[ -n ${GITHUB_STEP_SUMMARY:-} ]]; then printf -- '- %s\n' "$1" >> "$GITHUB_STEP_SUMMARY" || true; fi
}
# re <글자> <정규식> — 바이트 단위(LC_ALL=C) 정규식 비교
re() {
  local LC_ALL=C
  [[ $1 =~ $2 ]]
}
# new_token — stop-commands 토큰(실행 · 구간마다 새 값 · [A-Za-z0-9-] 16자 이상)
new_token() {
  local t=''
  if [[ -r /proc/sys/kernel/random/uuid ]]; then t=$(< /proc/sys/kernel/random/uuid) || t=''; fi
  if [[ ! $t =~ ^[A-Za-z0-9-]{16,}$ ]]; then t=$(od -An -N16 -tx1 /dev/urandom 2> /dev/null | tr -d ' \n') || t=''; fi
  if [[ ! $t =~ ^[A-Za-z0-9-]{16,}$ ]]; then t="stop-$$-$RANDOM-$RANDOM-$RANDOM-$RANDOM"; fi
  printf '%s' "$t"
}
# show <제목> <파일…> — 파일 내용(제어 문자 제거 · 파일마다 앞 200줄 · 줄 끝 보장)을 stop-commands 구간 안에 찍는다. 제목은 이 스크립트의 글자다
show() {
  local tok f
  tok=$(new_token)
  printf '%s — 아래 구간은 이미지 · 레지스트리가 고른 글자다(워크플로 명령으로 해석하지 않는다):\n' "$1"
  shift
  printf '::stop-commands::%s\n' "$tok"
  for f in "$@"; do
    if [[ -f $f ]]; then { LC_ALL=C tr -d '\000-\010\013-\037\177' < "$f" | head -n 200 | awk '{ print }'; } || true; fi
  done
  printf '::%s::\n' "$tok"
}
# fail <까닭 코드> <설명> — 오류 줄 · 요약 한 줄 · exit 1(EXIT trap이 시간 줄을 남긴다). 명령 치환(서브셸) 안에서 부르지 않는다
fail() {
  printf '::error::%s [%s] %s\n' "$PROG" "$1" "$2"
  note "**실패** [$1] — $2"
  exit 1
}
# inspect <이름> <템플릿> — docker image inspect --format의 출력을 $w/<이름>에 둔다(실패하면 오류를 구간 안에 찍고 exit 1)
inspect() {
  if ! docker image inspect --format "$2" "$ref" > "$w/$1" 2> "$w/$1.err"; then
    show "docker image inspect 오류($1)" "$w/$1.err" "$w/$1"
    fail inspect "docker image inspect가 실패했다($1)"
  fi
}
# value <이름> — $w/<이름>의 빈 줄이 아닌 줄이 정확히 하나면 그 줄, 아니면 빈 글자
value() {
  local -a v=()
  mapfile -t v < <(tr -d '\r' < "$w/$1" | awk 'NF')
  if (( ${#v[@]} == 1 )); then printf '%s' "${v[0]}"; fi
}
# children <접두> — 파일 목록($w/names)에서 접두 바로 아래 이름(중복 없이 · C 정렬). 이름 앞의 ./ · / 는 떼고 본다
children() {
  local p=$1 n rest c
  while IFS= read -r n || [[ -n $n ]]; do
    n=${n#./}
    n=${n#/}
    if [[ $n != "$p"* ]]; then continue; fi
    rest=${n#"$p"}
    c=${rest%%/*}
    if [[ -n $c ]]; then printf '%s\n' "$c"; fi
  done < "$w/names" | LC_ALL=C sort -u
}

# ---------- 입력 ----------
case $mode in
  local | registry) ;;
  *) fail usage 'ASSERT_MODE는 local · registry 중 하나다' ;;
esac
sha=${EXPECT_SHA:-}
re "$sha" '^[0-9a-f]{40}$' || fail usage 'EXPECT_SHA가 소문자 40자리 hex가 아니다'
ref=${IMAGE_REF:-}
if [[ $mode == registry ]]; then
  re "$ref" "^${IMAGE_REPO_RE}@sha256:[0-9a-f]{64}\$" || fail usage "registry 모드의 IMAGE_REF는 ${IMAGE_REPO}@sha256:<64자리 hex>여야 한다"
else
  re "$ref" "^${IMAGE_REPO_RE}:[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}\$" || fail usage "local 모드의 IMAGE_REF는 ${IMAGE_REPO}:<태그>여야 한다"
fi
for t in docker tar mktemp sort awk; do
  command -v "$t" > /dev/null 2>&1 || fail tool "$t 이(가) PATH에 없다"
done
w=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/publish-pod-assert.XXXXXXXXXX") || fail tool '작업 디렉터리를 만들지 못했다'

printf '%s — %s 모드 · 이미지 %s · 기대 커밋 %s\n' "$PROG" "$mode" "$ref" "$sha"

# ---------- registry: 단일 매니페스트 → digest pull ----------
if [[ $mode == registry ]]; then
  if ! docker buildx imagetools inspect "$ref" --format "$T_MEDIATYPE" > "$w/mediatype" 2> "$w/mediatype.err"; then
    show 'docker buildx imagetools inspect 오류' "$w/mediatype.err" "$w/mediatype"
    fail mediatype '레지스트리에서 매니페스트를 읽지 못했다'
  fi
  mt=$(value mediatype)
  if [[ $mt != "$MT_OCI" && $mt != "$MT_DOCKER" ]]; then
    show '매니페스트 미디어 타입' "$w/mediatype"
    fail mediatype '단일 매니페스트(OCI image manifest · Docker v2 schema 2)가 아니다 — index · list이거나 다른 형식이다(provenance · sbom이 꺼져 있는지 본다)'
  fi
  printf '  매니페스트: %s(단일)\n' "$mt"
  if ! docker pull --quiet "$ref" > "$w/pull.out" 2>&1; then
    show 'docker pull 출력' "$w/pull.out"
    fail pull 'digest로 pull하지 못했다'
  fi
  printf '  pull: digest로 받았다\n'
fi

# ---------- 1. 플랫폼 · 사용자 ----------
inspect os "$T_OS"
inspect arch "$T_ARCH"
if [[ $(value os) != '"linux"' || $(value arch) != '"arm64"' ]]; then
  show '실제 Os · Architecture(%q 꼴)' "$w/os" "$w/arch"
  fail platform '이미지가 linux/arm64가 아니다'
fi
inspect user "$T_USER"
if [[ $(value user) != '"10001:10001"' ]]; then
  show '실제 Config.User(%q 꼴)' "$w/user"
  fail user 'Config.User가 10001:10001이 아니다(deploy/base securityContext의 숫자 UID:GID)'
fi
printf '  플랫폼 · 사용자: linux/arm64 · 10001:10001\n'

# ---------- 2. revision 라벨 ----------
inspect label "$T_LABEL"
if [[ $(value label) != "\"$sha\"" ]]; then
  show '실제 라벨 org.opencontainers.image.revision(%q 꼴)' "$w/label"
  fail label "라벨 org.opencontainers.image.revision이 기대 커밋 $sha 이(가) 아니다 — build-arg APP_GIT_SHA가 빠졌거나(Dockerfile 기본값 0000000) 다른 라벨이 덮었다"
fi
printf '  revision 라벨: %s\n' "$sha"

# ---------- 3. Env(값의 원천) ----------
inspect env "$T_ENV"
n_sha=0
n_sha_name=0
n_ver=0
n_ver_name=0
while IFS= read -r l || [[ -n $l ]]; do
  l=${l%$'\r'}
  if [[ $l == '"APP_GIT_SHA='* ]]; then n_sha_name=$((n_sha_name + 1)); fi
  if [[ $l == "\"APP_GIT_SHA=$sha\"" ]]; then n_sha=$((n_sha + 1)); fi
  if [[ $l == '"APP_VERSION='* ]]; then n_ver_name=$((n_ver_name + 1)); fi
  if [[ $l == "\"APP_VERSION=sha-$sha\"" ]]; then n_ver=$((n_ver + 1)); fi
done < "$w/env"
if (( n_sha != 1 || n_sha_name != 1 || n_ver != 1 || n_ver_name != 1 )); then
  { grep -a -E '^"APP_(GIT_SHA|VERSION)=' -- "$w/env" || true; } > "$w/env.app"
  show 'Config.Env의 APP_GIT_SHA · APP_VERSION 항목(%q 꼴)' "$w/env.app"
  fail env "Config.Env에 APP_GIT_SHA=$sha 와 APP_VERSION=sha-$sha 가 각각 정확히 하나가 아니다(APP_GIT_SHA 항목 ${n_sha_name}개 중 일치 ${n_sha} · APP_VERSION 항목 ${n_ver_name}개 중 일치 ${n_ver})"
fi
printf '  Env: APP_GIT_SHA=%s · APP_VERSION=sha-%s(각각 하나)\n' "$sha" "$sha"

# ---------- 4. 최상위 허용 목록 ----------
if ! docker create "$ref" > "$w/cid" 2> "$w/cid.err"; then
  show 'docker create 오류' "$w/cid.err" "$w/cid"
  fail export 'docker create가 실패했다'
fi
cid_out=$(tr -d '\r\n' < "$w/cid")
if ! re "$cid_out" '^[0-9a-f]{64}$'; then
  show 'docker create 출력' "$w/cid"
  fail export 'docker create의 출력이 컨테이너 ID(64자리 hex)가 아니다'
fi
cid=$cid_out
if ! docker export "$cid" 2> "$w/export.err" | tar -tf - > "$w/names" 2> "$w/tar.err"; then
  show 'docker export | tar -tf - 오류' "$w/export.err" "$w/tar.err"
  fail export '컨테이너 파일 목록을 읽지 못했다'
fi
got_src=$(children 'src/')
got_apps=$(children 'src/apps/')
got_pod=$(children "src/apps/$POD_DIR/")
want_pod=$(printf '%s\n' .venv identity_admin manage.py pyproject.toml uv.lock | LC_ALL=C sort)
if [[ $got_src != apps || $got_apps != "$POD_DIR" || $got_pod != "$want_pod" ]]; then
  printf '/src의 자식:\n%s\n/src/apps의 자식:\n%s\n/src/apps/%s의 자식:\n%s\n' "$got_src" "$got_apps" "$POD_DIR" "$got_pod" > "$w/tree"
  show '실제 최상위(이미지가 고른 이름)' "$w/tree"
  fail tree "최상위가 허용 목록과 다르다 — /src = {apps} · /src/apps = {$POD_DIR} · /src/apps/$POD_DIR = {.venv, identity_admin, manage.py, pyproject.toml, uv.lock}"
fi
printf '  최상위: /src = {apps} · /src/apps = {%s} · /src/apps/%s = {.venv, identity_admin, manage.py, pyproject.toml, uv.lock}\n' "$POD_DIR" "$POD_DIR"

note "이미지 단언($mode) 통과 — \`$ref\` · linux/arm64 · 10001:10001 · revision = Env APP_GIT_SHA = \`$sha\` · APP_VERSION = \`sha-$sha\` · /src 허용 목록"
printf '결과: 통과 — %s 모드 이미지 단언(exit 0)\n' "$mode"
