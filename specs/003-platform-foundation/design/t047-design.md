# T047 설계 — validate CI 배선 · 승격 워크플로 · PR 템플릿 (초안 2026-09-29)

> 내부 작업 자료. 상태: **조사 완료 · 결정 대기**. 결정이 나면 §3을 확정으로 바꾸고 계약(`contracts/gitops-repo.md`)을 먼저 고친다.

## 1. 과제가 요구하는 것

| # | 산출물 | 저장소 |
|---|---|---|
| a | `.github/workflows/validate.yml` 완성 — T033 스크립트 실행 · required check `validate` · 렌더링 diff PR 코멘트(`kustomize build` main ↔ PR) | gitops |
| b | ruleset 적용(`bypass_actors: []`) | gitops |
| c | `promote.yml` — `workflow_dispatch`(입력 `pod`) → dev digest 읽기 → `gh attestation verify` → prod PR(auto-merge 없음) | gitops |
| d | `.github/pull_request_template.md` — 비가역 파일 변경 시 스냅샷 3종 확인 체크박스 | gitops |
| e | `ci.yml`에 kubeconform(`templates/django-pod/deploy`) | 모노레포 |

## 2. 조사로 확정한 사실(2026-09-29)

### 2.1 현재 상태

- **F1** `validate.yml`은 T003 골격이다. 실제로 도는 것은 checkout과 gitleaks 액션뿐이고 검사 스텝 7개는 `echo`다. 실행 시간 약 15초. 권한 `contents: read`.
- **F2** **ruleset `main`은 2026-09-02에 이미 적용돼 있다**(id 22066865 · `enforcement: active`). 원격 값이 로컬 `.github/ruleset-main.json`과 같다: `deletion` · `non_fast_forward` · `pull_request`(approvals 0) · `required_status_checks`(`validate`, strict) · `bypass_actors: []` · 현재 사용자의 bypass `never`. → 산출물 b는 새로 만드는 일이 아니라 **대조 확인**이다.
- **F3** 저장소 설정: public · `allow_auto_merge: true` · `delete_branch_on_merge: true` · 병합 방식 3종 허용. Actions 기본 토큰 권한 `read` · 워크플로의 PR 승인 불가. `sha_pinning_required: false`(T116이 켠다).
- **F4** gitops 저장소에는 Actions 시크릿·변수가 **없다**. 모노레포에는 변수 `JOSHUATECH_CI_APP_CLIENT_ID`가 있다(시크릿 목록은 비어 있다).
- **F5** `promote.yml` · PR 템플릿은 없다. 모노레포 `ci.yml`에는 kubeconform 스텝이 없고, `templates/django-pod/`에는 `copier.yml`과 `template/`만 있다(`deploy/`는 아직 없다).

### 2.2 검사 스크립트의 실행 계약

- **F6** `validate.sh`는 `CI` 변수를 읽지 않는다. 도구가 없으면 기본이 FAIL이고 `VALIDATE_SKIP_TOOLS=1`일 때만 SKIP이다. helm은 `helmCharts`가 있는 kustomization에서만 요구한다(실제 트리에 4곳 — 없으면 FAIL).
- **F7** 종료 코드: 0 = FAIL 없음(WARN·SKIP은 영향 없음) · 1 = FAIL 있음 · 2 = 인자 오류. `set -euo pipefail`이라 SHA 객체가 없는 `git diff` 등은 요약 없이 git의 종료 코드로 끝난다.
- **F8** 검사 6(작성자 lint): `PR_AUTHOR`가 비면 PR 이벤트에서 FAIL, push 이벤트에서는 "대상 없음" PASS. 작성자가 봇 목록(`VALIDATE_BOT_AUTHORS`, 기본 `jt-ci[bot],joshuatech-gitapp-1[bot]`)에 없으면 diff를 보지 않고 PASS. 봇이면 변경 파일은 `^apps/[^/]+/overlays/dev/kustomization\.yaml$`뿐, 변경 줄은 `digest: sha256:<64hex>`뿐.
- **F9** SHA로 diff를 계산할 때 **두 점 diff**(`git diff BASE HEAD`)를 쓴다. base가 main 끝보다 뒤처지면 main 쪽 변경이 섞인다.
- **F10** `validate.sh`에는 **검사를 골라 돌리는 옵션이 없다**. `tests/README.md`의 「T047 필수 조건」(검사 6은 base ref의 스크립트로 돌린다)을 문면대로 하면 base 스크립트가 head 트리 **전체**를 검사한다 — 표와 트리를 함께 바꾸는 정상 PR(컴포넌트 추가 등)이 base 쪽 표에서 FAIL한다.
- **F11** `validate.tests.sh`: `CI=true`이면 도구 누락 시 exit 1, 부분 실행(`VALIDATE_TESTS_ONLY`) 거부. **도구 게이트에 helm이 없다** — helm이 없으면 `rel-scoped` 4개 케이스가 "도구 없음" 단언으로 바뀌어 통과한다. git 상태는 요구하지 않는다. 전체 69 케이스.
- **F12** 네트워크: kubeconform 스키마 2곳(버전 `master` · datree `main` — 고정 아님) · 차트 저장소 4곳 · `bootstrap/argocd`의 원격 `install.yaml`(커밋 SHA 고정).
- **F13** 검사 8(gitleaks 파일 스캔)은 `$ROOT` 전체를 본다 — helm이 풀어 놓은 `charts/`, 자기검사가 남긴 픽스처 쪽 `charts/`, `tests/validate.base.sh`까지 들어간다. 스텝 순서가 결과에 영향을 준다.
- **F14** 소요 시간(Windows · Git Bash 실측): 실제 트리 validate 약 10분 · 자기검사 전체 약 1시간. **Linux arm64 러너에서의 시간은 미실측**(프로세스 생성 비용이 달라 크게 줄 것으로 보이지만 추측이다).

### 2.3 렌더 대상

- **F15** kustomization 디렉터리 29개(`tests/`·`charts/` 제외). Application의 `spec.source.path` 22개 중 21개가 kustomization과 짝을 이루고, `clusters/oci-k3s/apps`는 directory source다. Application이 없는 kustomization 8개: `apps/identity-admin/*` 3 · `clusters/oci-k3s/projects` · `platform/argocd`(자리표시자) · `platform/policies/tests` · `secrets/*` 2.

### 2.4 실제 권한 경계(2026-09-29 · gitops main `82dd85e` · 전 렌더 29개 · 문서 325장)

- **F16** ServiceAccount 토큰을 만들 수 있는 규칙(명시 + 와일드카드)은 **2개**: ClusterRole `argocd-application-controller`(`*/*/*`) · Role `external-secrets/eso-token-create`(`resourceNames` 5개).
- **F17** `ServiceAccount reloader/reloader`(또는 그 계정을 포함하는 그룹)를 주체로 한 바인딩은 **5개**, 전부 `platform/reloader` 렌더 안이다. 그룹 주체(`system:serviceaccounts` · `system:authenticated` 등) 바인딩은 어느 렌더에도 없다.
- **F18** 렌더에 없는 ClusterRole을 가리키는 바인딩은 **2개**: `agent-view-view` → `view` · `vault-server-binding` → `system:auth-delegator`.
- **F19** `aggregationRule`을 가진 ClusterRole 0개. `aggregate-to-*` 라벨을 가진 ClusterRole 12개(cert-manager 7 · external-secrets 5 — 내장 `view`·`edit`·`admin`·`reader`를 넓힌다).
- **F20** 형식별 정책의 현재 위반 0: `kind: List` 0 · `kind: ApplicationSet` 0(파일 · 렌더) · `clusters/oci-k3s/apps`에는 `.yaml` 21개와 `.md` 1개뿐이고 하위 디렉터리 없음 · `helmGlobals`·레거시 생성기 0 · `argocd-cm`에 `kustomize.buildOptions: "--enable-helm"` 있음.
- 측정 스크립트: `.superpowers/t047/measure_rbac.py`(로컬 · gitignore). G4의 검사는 이 판정을 `validate.sh`(yq)로 옮긴 것이어야 하고, 같은 렌더에서 같은 결과가 나오는지로 대조한다.

### 2.5 러너에 설치할 도구(linux arm64 · 공식 릴리스의 체크섬 파일에서 옮김)

| 도구 | 버전 | 자산 | sha256 |
|---|---|---|---|
| kustomize | v5.8.1 | `kustomize_v5.8.1_linux_arm64.tar.gz` | `0953ea3e476f66d6ddfcd911d750f5167b9365aa9491b2326398e289fef2c142` |
| yq(mikefarah) | v4.53.6 | `yq_linux_arm64` | `88a1016bc1d657375a35864e4f44b6f333df8ff97b559f51bba0adcb2169df09` |
| gitleaks | 8.30.1 | `gitleaks_8.30.1_linux_arm64.tar.gz` | `e4a487ee7ccd7d3a7f7ec08657610aa3606637dab924210b3aee62570fb4b080` |
| kubeconform | v0.8.0 | `kubeconform-linux-arm64.tar.gz` | `1f53fc8e81258197a35e8603054162a5af1de8c5af13746c71ab680d9534ed87` |
| helm | v4.3.0 | `helm-v4.3.0-linux-arm64.tar.gz`(get.helm.sh) | `31c5794dd55c66a51e6b7d2e2ac7a114ae8b1de41ff1d9ba51748ac973b06a08` |

로컬 검증에 쓴 버전과 같다(kubeconform은 0.8.0). 서드파티 설치 액션을 쓰지 않고 내려받아 sha256을 대조한다 — 액션을 하나 더 믿지 않아도 되고, 버전 갱신은 Renovate의 정규식 관리자(T116)로 넘길 수 있다.

## 3. 발견한 문제와 결정 대기 항목

### P1. 계약 안의 충돌 — 승격 PR을 봇이 열면 required check를 통과할 수 없다

- 계약 §이미지·승격: `promote.yml`은 **App 토큰으로** `overlays/prod`를 바꾼 PR을 연다.
- 계약 §validate.yml 5 · F8: 작성자가 봇이면 변경 파일은 `overlays/dev/kustomization.yaml`뿐이어야 한다.
- 둘을 함께 만족하는 PR은 없다. App 토큰으로 연 승격 PR은 작성자가 봇이라 검사 6에서 FAIL하고, required check가 막아 머지할 수 없다.
- 봇 제한을 "prod digest도 허용"으로 넓히면 안 되는 이유: App은 자기 PR에 auto-merge를 걸 수 있고 ruleset의 승인 수가 0이다. 토큰이 탈취되면 **prod digest PR이 사람 없이 머지**된다 — 봇을 dev로 묶어 둔 이유가 바로 이것이다.

| 안 | 내용 | 봇 = dev 전용 불변식 | 운영자 수고 | 계약 변경 |
|---|---|---|---|---|
| **A(권장)** | `promote.yml`은 검증(attestation) 뒤 **브랜치만 만든다**(`GITHUB_TOKEN`). PR은 **운영자가 연다** → 작성자 = 사람 | 유지 | 승격마다 PR 열기 1회 | §이미지·승격 한 줄 |
| B | 봇 lint에 "승격 모드" 추가(브랜치 이름이 `promote/…`이면 prod digest 줄 허용) | **깨진다**(탈취 시 prod 자동 머지 가능) | 없음 | §validate.yml 5 |
| C | 승격 전용 App을 하나 더 만든다(봇 목록에 넣지 않음) | 그 App에는 경로 제한이 아예 없다 | App 생성·키 관리 | §변경 권한 |

A에서 PR을 `GITHUB_TOKEN`으로 열지 않는 이유: `GITHUB_TOKEN`이 만든 PR은 워크플로를 일으키지 않아 required check가 영영 보고되지 않는다.

**결정 D1(사용자 2026-09-29): A안.** `promote.yml`은 attestation 검증 뒤 브랜치만 만들고 PR 링크를 출력한다. PR은 운영자가 연다(작성자 = 사람). "봇은 dev digest만" 불변식을 그대로 둔다. 따르는 것: ①계약 §이미지·승격의 승격 문장을 고친다(M0) ②`promote.yml`에 App 토큰이 필요 없다 → **gitops 저장소에 App 시크릿을 등록하지 않는다**(F4 그대로) ③T115의 증거 항목 "PR의 merged_by가 사람"에 "PR 작성자도 사람"이 더해진다.

### P2. 봇이 검사를 스스로 끌 수 있는가 — 보증의 전제

`pull_request` 이벤트는 **PR 쪽의 워크플로 파일과 스크립트**로 돈다. 봇 PR이 `validate.yml`이나 `tests/validate.sh`를 고치면 검사가 무력해진다. 막는 장치 셋이 함께 있어야 한다.

1. **App에 `workflows` 권한이 없다** → GitHub이 워크플로 파일을 바꾸는 push를 거부한다(플랫폼 통제). App 설정은 운영자만 볼 수 있다 — **확인 필요(VD)**.
2. **검사 6은 base ref(main)의 스크립트로 돈다** → 봇이 같은 PR에서 스크립트를 고쳐도 main의 규칙으로 판정한다.
3. 검사 6이 변경 파일을 dev kustomization으로 제한한다 → 스크립트를 고친 PR 자체가 FAIL.

F10 때문에 2를 하려면 `validate.sh`에 **검사 6만 도는 옵션**(`--only-author`)이 필요하다. 이 옵션은 main에 먼저 들어가 있어야 워크플로가 base 스크립트로 부를 수 있다 → **PR을 둘로 나눈다**(§4 G1 → G2).

### P3. 자기검사를 CI에서 언제 돌릴 것인가

F14가 미실측이라 지금 정할 수 없다. G2의 draft PR에서 러너 시간을 잰 뒤 결정한다(후보: 모든 PR · `tests/**`이 바뀐 PR만 · 야간).

### P4. 인계 항목의 범위

T045·T046과 각 README가 "T047" 또는 "T047 후보"로 넘긴 항목이 15개쯤 있다. 전부 넣으면 T047이 검사 확장 태스크가 된다.

| # | 항목 | 출처 | 성격 | 제안 |
|---|---|---|---|---|
| H1 | `validate.sh` CI 실행 · 도구 sha256 핀 설치(helm 포함) | tests/README | 과제 본문 | **포함** |
| H2 | 검사 6을 base ref 스크립트로(`--only-author`) · merge-base diff | tests/README 「T047 필수 조건」 | 보증의 전제 | **포함** |
| H3 | 자기검사 도구 게이트에 helm 추가 | 조사 F11 | CI의 가짜 통과 | **포함** |
| H4 | Application source 우회 경로 전수 열거(`kind: List` · `.json`/`.jsonnet` · ApplicationSet) | 계약 §validate.yml 4 | 계약이 T047로 명시 | **포함** |
| H5 | `helmCharts[].repo` 허용 목록 | AppProject·ESO·Vault README | AppProject `sourceRepos` 줄을 네 번 지운 대가 | **포함** |
| H6 | 7.4 `/charts/` 제외 범위 좁히기 | tests/README | 작은 수정 | **포함** |
| H7 | Reloader SA를 주체로 하는 RoleBinding 전 렌더 교차 검사 | tests/README | 작은 검사 | **포함** |
| H8 | 렌더의 `serviceaccounts/token` 1건 고정 | ESO README | 작은 검사 | **포함** |
| H9 | `helmCharts`를 쓰면 argocd-cm에 `--enable-helm` | argocd-cm 주석 | 작은 검사 | 포함 |
| H10 | `charts/` 캐시가 버전을 비교하지 않는 문제 | cert-manager README | CI는 매번 빈 작업 공간이라 해당 없음 | 문서만 |
| H11 | bootstrap 검사 공백 4(삭제 패치 target · 원격 base 태그 ref · digest · GOMEMLIMIT) | bootstrap README | "후보" | converge로 |
| H12 | traefik 단언 5(`ssl=strict` 드리프트 등) | traefik README | "T047/converge 후보" | converge로 |
| H13 | `validate.sh` 머리 주석과 코드의 불일치 2건 | 조사 | 문서 | 포함 |
| H14 | 검사 4a — `apps/*/overlays/*`의 `images` 항목마다 `digest` 필수(지금은 `newTag` 금지만 본다 — digest가 아예 없는 항목은 통과한다) | G1 리뷰 F4 | 계약 §이미지·승격 첫 줄("`digest`만")의 빈틈 | **포함(G4)** |

**결정 D2(사용자 2026-09-29): H1–H9 · H13을 T047에 넣는다.** 보강 조건:

- **H4는 형식별 정책으로 완료 범위를 한정한다** — "우회 경로를 전부 찾는다"가 아니라, Argo가 읽을 수 있는 형식마다 **검사한다 / 금지한다**를 정해 표로 닫는다. `.json`·`.jsonnet` 금지는 Argo가 디렉터리째 읽는 경로(directory source)로 한정한다(저장소 전체에 걸면 `.github/ruleset-main.json` 같은 정상 파일이 걸린다).
- **H7 · H8은 문자열이 아니라 실제 권한 경계를 본다** — 와일드카드 규칙과 그룹 주체(`system:serviceaccounts` 등)도 같은 권한을 준다. 기존의 넓은 역할은 사유를 붙인 허용 목록으로 둔다.
- **H10은 문서와 운영 후속 조건**으로 정리한다(CI는 빈 작업 공간이라 해당 없음).
- **H11 · H12는 converge로 넘기되 후속 위치와 완료 조건을 적는다**(§6).
- **순서**: G1 → G2로 CI 연결을 먼저 하고, 확장 검사까지 끝낸 뒤 T047을 닫는다.

## 4. PR 분할(제안)

| 순서 | 저장소 | 내용 | 비고 |
|---|---|---|---|
| M0 | 모노레포 | 계약 수정(P1 결정 · 봇 보증의 전제 · 렌더 diff의 범위) | gitops보다 먼저 |
| G1 | gitops | `validate.sh --only-author` + 자기검사 · helm 게이트 · 머리 주석 정정 | 워크플로는 그대로 |
| G2 | gitops | `validate.yml` 배선(도구 설치 · base 스크립트 검사 6 · 전체 검사) — **draft로 열어 러너 시간 실측** → P3 결정 | G1 머지 뒤 |
| G3 | gitops | 렌더링 diff 코멘트 job(`pull-requests: write`는 이 job에만 · 포크 PR은 건너뜀) | |
| G4 | gitops | 검사 확장(H4–H9) + 픽스처 | 범위는 P4 결정에 따름 |
| G5 | gitops | `promote.yml` + PR 템플릿 | P1 결정에 따름 |
| M1 | 모노레포 | `ci.yml` kubeconform — `templates/django-pod/deploy`가 아직 없으므로(F5) 대상이 생길 때까지는 "대상 없음"으로 통과하는 스텝 | |

### 4.1 G2 워크플로의 스텝 순서와 그 이유

`workflows` 권한이 없는 App이 못 바꾸는 것은 **`.github/workflows/` 아래 파일뿐**이다. `.github/scripts/`나 `tests/`는 보호 밖이다. 그래서 같은 job 안에서 PR 쪽 파일을 **실행한 뒤에** 돌리는 검사는 봇이 미리 환경을 바꿔 둘 수 있다(PATH 앞에 가짜 `git`을 두는 식). 순서로 막는다.

| 순서 | 스텝 | 실행되는 코드의 출처 | 비고 |
|---|---|---|---|
| 1 | checkout(`fetch-depth: 0`) | 액션(SHA 고정) | PR 쪽 코드는 실행되지 않는다 |
| 2 | **경로 lint** — `git show "$BASE_SHA:tests/validate.sh" > tests/validate.base.sh` → `bash tests/validate.base.sh --only-author` → 사본 삭제 | **main의 스크립트** | 러너에 미리 있는 git · bash만 쓴다. **PR 쪽 코드를 실행하기 전에** 돈다 |
| 3 | 도구 설치(버전 고정 + sha256) | **워크플로 파일 안의 인라인 스크립트** | 저장소의 설치 스크립트를 부르지 않는다(보호 밖이라서) |
| 4 | 전체 검사 `bash tests/validate.sh` | PR 쪽 스크립트 | 사람 PR은 스크립트를 함께 고칠 수 있다 — 그 통제는 리뷰다 |
| 5 | 자기검사(실행 시점은 P3) | PR 쪽 스크립트 | 검사 8이 픽스처 쪽 `charts/`를 훑지 않도록 4 뒤에 둔다 |
| 6 | gitleaks 액션(히스토리) | 액션(SHA 고정) | 기존 그대로 |

- 값은 `${{ }}`를 스크립트 본문에 끼워 넣지 않고 **`env:`로 넘긴다**(PR 제목·브랜치 이름을 통한 스크립트 주입 방지). `PR_AUTHOR` = `github.event.pull_request.user.login` · `VALIDATE_BASE_SHA` = `github.event.pull_request.base.sha` · `VALIDATE_HEAD_SHA` = `github.event.pull_request.head.sha`.
- ruleset이 strict(브랜치가 최신이어야 머지)라 머지 시점의 `base.sha`는 main의 끝이다 — 봇이 옛 base를 골라 옛 스크립트로 판정받는 길이 없다.
- push 이벤트(main)에서는 2를 건너뛴다(`PR_AUTHOR`가 없어 검사 6은 "대상 없음"이다).
- `VALIDATE_SKIP_TOOLS` · `VALIDATE_BOT_AUTHORS` · `VALIDATE_TESTS_ONLY`는 어디에도 설정하지 않는다.

## 5. 진행 기록

- 2026-09-29: 조사(F1–F20) → 결정 D1·D2 → **M0 계약 `1892135`** → G1 빌드 착수(gitops 로컬 브랜치 `t047-g1-only-author`).
- 2026-09-29 12:48경 **Windows 업데이트 재부팅으로 G1 빌더가 끊겼다.** 커밋된 것은 전부 원격에 있었고(모노레포 `9485db0`), 빌더의 구현은 작업 트리에 남아 있었다(파일 4개 · 임시 파일 없음). 빌더의 로그로 진행 위치를 확인했다: 새 케이스 12개 RED → `--only-author` 구현 → merge-base 구현 → 12개 GREEN(12:38) → 회귀 확인 도중 중단. 빌더를 되살리지 않고 컨트롤러가 남은 완료 조건을 직접 돌렸다.
- G1 독립 검증(컨트롤러 · 13:14–13:36): 문법 검사 통과 · `^(author-|positive)` **23 케이스 실패 0**(기존 author 9 + positive 1 + 새 케이스 13 — 전체는 69 → 82) · **일반 모드 출력이 변경 전 스크립트와 바이트 동일**(긍정 픽스처) · `CI=true` + helm 없는 PATH → 케이스를 돌리기 전에 exit 1 · gitleaks 0 · CR 0 · 작업 트리에 의도한 파일 4개만. 이어서 독립 리뷰(명세 준수 · 검사 6 우회 경로 실험 · 코드 품질).

- **G1 독립 리뷰(2026-09-29 오후) — 판정 APPROVED_WITH_FIXES.** 리뷰어가 임시 저장소로 실험한 결과:

  | # | 심각도 | 내용 | 지금 막고 있는 것 | 조치 |
  |---|---|---|---|---|
  | F1 | medium | merge-base가 둘 이상(criss-cross)이면 git이 하나를 골라 준다. head를 "골라진 쪽 + digest 한 줄"로 만들면 검사 6은 PASS, 실제 머지 결과는 다른 파일을 바꾼다 | main 이력이 선형(33 커밋 중 머지 커밋 0)이고 ruleset이 strict — 둘 다 스크립트가 강제하는 것이 아니다 | `merge-base --all`이 1개가 아니면 FAIL(R1) |
  | F2 | low | 내용이 `++ `/`-- `로 시작하는 줄은 diff에서 파일 머리줄과 같은 모양이라 줄 검사를 빠져나간다(기존 코드 · 컨트롤러 재현 확인) | kustomize가 알 수 없는 필드로 빌드를 실패시킨다(전체 검사) | hunk 구간에서는 내용으로 검사(R2) |
  | F3 | low | `git diff`에 `--no-textconv` · `--ignore-submodules=none` 없음 | 저장소에 `.gitmodules`가 없다 | 옵션 추가(R3) |
  | F4 | low | digest 줄의 삭제·추가·이동이 형식만 맞으면 통과한다(기존 동작) — 한 항목의 digest를 지우면 그 이미지는 고정이 풀린다 | 범위는 dev overlay 안 | 제자리 교체 쌍만 허용(R4). "images 항목에 digest 필수"는 검사 4a의 몫 → **G4에 추가** |
  | F5–F7 | info | 단언이 없는 분기 5곳 · 부분 실행의 건너뜀 수가 7 모자람 · 문서가 코드보다 많이 말하는 곳 4 | — | 케이스·집계·문서 수정(R6–R8) |

  리뷰어가 "확인하지 못한 것"으로 남긴 **봇 로그인 표기** 문제에서 설계를 하나 더 고쳤다: 로그인(`<slug>[bot]`)만 보면 App 이름을 바꾼 순간 봇 PR이 사람 PR로 취급돼 제한이 조용히 풀린다 → **계정 ID(`323873425`)로도 판정**한다(R5). `jt-ci[bot]`이라는 계정은 GitHub에 없다(404) — 목록에 있어도 무해하다.
- 계약 보강 `866dccf`(판정 규칙 4 + 봇 ID) → 수정 빌더 착수(R1–R8 · 로그 `.superpowers/t047/g1r2/`).
- **리뷰어의 지시 이탈 1건(자진 보고)**: 수정안을 사본에서 확인하다 필터를 넓게 줘 긍정 픽스처의 전체 모드 실행이 돌았고, kubeconform이 공개 스키마를 내려받았다(저장소 밖 임시 캐시에 파일 12개). 추적 파일은 바뀌지 않았고 프로세스는 리뷰어가 정리했다. 비밀·자격과 무관한 공개 JSON이다.

- **결정 D3(사용자 2026-09-29): ruleset에 선형 이력 필수 + 머지 방식 squash 전용을 더한다.** F1의 전제(main에 머지 커밋이 들어올 수 있다)를 없앤다 — 스크립트의 merge-base 개수 검사(R1)와 이중 방어. 현재 원격 ruleset은 머지 방식 3종을 허용하고 `required_linear_history`가 없다. `.github/ruleset-main.json`을 G1 PR에서 고치고, 머지 뒤 운영자가 `gh api -X PUT …/rulesets/22066865 --input .github/ruleset-main.json`으로 적용한다(파일만 고쳐서는 적용되지 않는다).
- **수정 빌더 보고(R1–R8 · DONE_WITH_CONCERNS)**: 전부 반영. 케이스 82 → **107**. 새 케이스는 수정 전 실패(RED 18) → 수정 뒤 통과, 기존 분기를 지키는 케이스는 변이 시험 9/9로 고유성 확인. `^author-` 47 케이스 실패 0. 빌더가 지시에 없이 더한 판정 셋(전부 더 닫는 쪽)을 컨트롤러가 코드로 읽어 확인하고 받아들였다: ①쌍의 두 줄은 hex 값 밖이 같아야 한다(`    digest:` → `  - digest:`로 새 항목을 만드는 경로) ②`PR_AUTHOR` 없이 `PR_AUTHOR_ID`만 오면 FAIL ③머리 구간의 낯선 `+`/`-` 줄은 FAIL. ①은 계약에 반영했다.

- **G1 PR #33**(gitops `3267322` · 2026-09-29 15:3x KST): 컨트롤러 독립 검증 — 문법 검사 · 빠른 케이스 38(전부 `--only-author`) 실패 0 · 일반 모드 출력이 변경 전과 바이트 동일(긍정 픽스처) · gitleaks 0 · CR 0 · ruleset JSON 파싱. 파서(검사 6의 hunk 구간·쌍 판정)는 컨트롤러가 코드로 읽었다. CI 2건 통과. 머지와 ruleset 적용은 운영자.

- **G2 빌더 보고(DONE_WITH_CONCERNS)**: `validate.yml` 배선 구현 · 완료 조건 A–F 통과(actionlint · shellcheck 포함). 지시에 더한 것 — `persist-credentials: false` · 스텝 2 강화(전체 SHA 요구 · 사본 자리에 심어 둔 심볼릭 링크 대응 · noclobber) · 스텝 4의 도구 경로 확인. 빌더가 범위 밖에서 찾은 것 → 아래 P5.
- **P5. 봇이 사람의 PR을 가로챌 수 있다(G2 빌더 발견 · G1 리뷰어의 "확인하지 못한 것"과 같은 경로 · 컨트롤러 검토로 성립 확인)**: 검사 6은 PR을 연 계정으로 봇을 판정한다. App은 쓰기 권한이 있어 ①사람이 연 PR의 브랜치에 커밋을 push하고 ②머지 API 또는 auto-merge로 머지할 수 있다(승인 수 0). 작성자가 사람이라 검사 6은 제한 없이 통과하고, 전체 검사는 봇이 고친 PR 쪽 스크립트로 돈다. 운영자 머지는 `--match-head-commit`으로 커밋을 고정해 왔지만 봇이 직접 하는 머지는 그 통제를 지나친다.
- **결정 D4(사용자 2026-09-29): 브랜치 쓰기 제한 + 발신자 판정 둘 다.** ①ruleset `branches` — main과 `bump/**`를 뺀 모든 브랜치의 생성·갱신·삭제를 관리자 역할만(선언 `.github/ruleset-branches.json` · 적용은 운영자) ②검사 6이 `pull_request.user`와 `sender` 둘 다로 봇을 판정(입력 `PR_SENDER` · `PR_SENDER_ID` — PR 이벤트에서 비면 FAIL). 둘 다 G1 PR(#33)에 더한다 — 워크플로가 넘기는 입력을 main의 스크립트가 먼저 알아야 한다.
- **목표 운영 모델(사용자 2026-09-29)**: "봇이 안전하게 승격 PR을 만들고, 검증을 모두 자동화하며, 사람은 prod 승인 또는 예외 처리만 담당한다." 이것은 FR-038의 문면과 같고, D1(운영자가 PR을 연다)은 거기서 한 걸음 물러난 **임시 형태**다 — 봇이 연 PR은 봇이 머지할 수도 있는데(승인 수 0) 사람만 통과시킬 수 있는 관문이 아직 없기 때문이다. **G5에서 승인 관문(GitHub Environment 필수 검토자를 required check 안에 넣는 방식)을 실측**해, 되면 목표 형태로 구현하고 D1을 되돌리며, 안 되면 D1을 유지하고 편차로 기록한다. D1 외의 결정(D2–D4 · 검사 6의 규칙)은 목표 형태에서도 그대로다.

- **G1 갱신(PR #33 head `7f6f68a` · 2026-09-29 17:0x KST)**: 발신자 판정(`PR_SENDER`·`PR_SENDER_ID`) + `.github/ruleset-branches.json` + README 근거. 빌더: 케이스 107 → **122**(`author-only-sender-*` 15) · RED 15 → GREEN · 한 줄 변이 15/15 검출 · `^author-` 62 케이스 실패 0. 컨트롤러 독립 검증: 빠른 케이스 53 실패 0 · 일반 모드 출력이 main(`82dd85e`)의 스크립트와 바이트 동일(긍정 픽스처) · gitleaks 0 · CR 0 · ruleset JSON 둘 파싱. CI 통과. **미실측으로 남긴 것**: App 토큰 push의 실제 거부 · 실제 이벤트의 `sender` 값(둘 다 App 키가 있어야 한다 → T074 · T115).

## 6. converge로 넘기는 것(후속 위치와 완료 조건)

| # | 항목 | 후속 위치 | 완료 조건 |
|---|---|---|---|
| H11-1 | 삭제 패치(`$patch: delete`)의 target이 실제로 렌더에서 사라지는지 | gitops `bootstrap/README.md` 검사 공백 목록 · `tests/validate.sh` 검사 1 | 삭제 패치가 가리키는 객체가 base에 없을 때 FAIL하는 픽스처 1개 + 단언 |
| H11-2 | 원격 base의 태그·브랜치 ref 금지(커밋 SHA만) | 같음 | `resources`의 원격 URL에 40자 SHA가 없으면 FAIL하는 픽스처 1개 + 단언 |
| H11-3 | `bootstrap/**` 이미지 digest 병기 | 같음 · 검사 4b의 범위 | 4b의 대상 경로에 `bootstrap/`을 더하고 기존 WARN/FAIL 규칙을 그대로 적용 |
| H11-4 | `GOMEMLIMIT` ≤ 메모리 limit | 같음 | 컨테이너 env `GOMEMLIMIT`이 같은 컨테이너의 `resources.limits.memory`를 넘으면 FAIL하는 픽스처 1개 + 단언 |
| H12-1 | Cloudflare `ssl=strict` 드리프트 단언 | gitops `platform/traefik/README.md` §6 · 모노레포 `tests/infra/tofu.tests.ps1` | 계획 출력에서 영역 설정 `ssl`이 `strict`임을 단언(이미 있으면 "있음"으로 닫는다) |
| H12-2 | 계약 §디렉터리에 소유권 한 문장(TLSOption 정본 = 모노레포 HelmChartConfig · TLSStore 정본 = `platform/traefik/`) · 설계 문면의 edge 검증 호스트 교체 | 모노레포 `contracts/gitops-repo.md` · T042 설계 | 문장 반영(검사 아님) |
| H12-3 | `validate.sh` 교차 파일 단언 — `platform/traefik/`의 TLSStore는 `default`/`kube-system` 1개 · `spec.certificates[].secretName` = `platform/cert-manager-issuers/` Certificate의 `spec.secretName` · `spec.defaultCertificate` 금지 · `platform/traefik/`에 kind `TLSOption`·`Secret` 금지 | `tests/validate.sh` 새 검사 | 다섯 조건마다 부정 픽스처 1개 + 고유 단언, 긍정 픽스처 통과 |

출처의 원문: gitops `bootstrap/README.md` 「validate 공백 후보」 ①–④ · `platform/traefik/README.md` 「T047 / converge」 ①–④.

`/speckit-converge`가 이 표를 읽어 `tasks.md`에 Convergence 태스크로 붙인다(컨트롤러는 `tasks.md` 본문을 고치지 않는다).

## 7. 검증 후 결정(VD) 항목

- App의 권한 목록(특히 `workflows` 없음)과 실제 봇 로그인 이름 — **운영자 확인 완료(2026-09-29)**: gitops 저장소에 설치된 App은 `joshuatech-gitapp-1`(봇 로그인 `joshuatech-gitapp-1[bot]` — `VALIDATE_BOT_AUTHORS` 기본값에 있다) · Repository permissions의 `Workflows` = **No access**. 설정 화면으로 확인한 값이고, "워크플로 파일을 바꾸는 push가 실제로 거부된다"는 증거는 T115에서 남긴다. 계약의 `jt-ci[bot]`은 설계 이름이고 실제 App 이름은 `joshuatech-*` 명명 예외를 따른다 — 목록에 둘 다 두는 것은 무해하다(없는 이름은 제한을 더할 뿐이다).
- arm64 러너의 검사 시간 — G2 draft PR에서 실측.
- 포크 PR에서 코멘트 job이 실패하지 않고 건너뛰는지 — 포크가 없으면 조건식 검토로 대신하고 미실측으로 적는다.
- App 토큰의 워크플로 파일 push 거부 · main 직접 push 거부 — T115(승격·롤백 실연)에서 증거를 남긴다.
