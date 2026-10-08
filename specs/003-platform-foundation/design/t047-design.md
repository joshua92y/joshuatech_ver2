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
- **F19** `aggregationRule`을 가진 ClusterRole 0개. `aggregate-to-*` 라벨을 가진 ClusterRole **5개**(cert-manager 3 · external-secrets 2 — 내장 `view`·`edit`·`admin`·`reader`를 넓힌다). **정정(2026-09-29 저녁)**: 처음에는 "12개(7 + 5)"로 적었다 — 그것은 ClusterRole 수가 아니라 **라벨 수**였다. G4 지시서를 쓰며 다시 세어 찾았고 계약도 함께 고쳤다.
- **F22(추가 실측 · G4b 지시서 작성 중)** 첫 측정이 보지 않은 경로를 같은 렌더에서 다시 쟀다(`.superpowers/t047/measure_rbac2.py`):
  - 바인딩 40장의 주체 40개는 **전부 `ServiceAccount`**이고 `namespace`가 다 적혀 있다. `User`·`Group` 주체 0.
  - `roleRef`가 Role인데 같은 ns에 그 Role이 렌더되지 않은 바인딩 0. 같은 이름의 Role·ClusterRole이 두 렌더에 나타나는 경우 0.
  - 내장 역할의 이름(`cluster-admin`·`admin`·`edit`·`view`·`system:` 접두)으로 렌더된 ClusterRole 0.
  - `secrets` 생성 권한을 가진 규칙 8개(Argo CD 3 · cert-manager 4 · external-secrets 1) · `escalate`·`bind`·`impersonate`는 `argocd-application-controller`의 `*`뿐.
  - **첫 기준이 놓친 우회 경로 셋**: ①주체를 `User` `system:serviceaccount:reloader:reloader`로 적으면 그룹 넷만 보는 판정을 지나간다 ②RoleBinding의 ServiceAccount 주체는 `namespace`를 비우면 API 서버가 바인딩의 ns로 읽는다 ③내장 역할과 같은 이름의 ClusterRole을 함께 렌더하면 "렌더에 없는 역할" 판정을 지나간다. → 계약을 "주체는 이름을 다 적은 ServiceAccount뿐" · "내장 역할의 이름으로 정의 금지"로 고쳤다.
- **F20** 형식별 정책의 현재 위반 0: `kind: List` 0 · `kind: ApplicationSet` 0(파일 · 렌더) · `clusters/oci-k3s/apps`에는 `.yaml` 21개와 `.md` 1개뿐이고 하위 디렉터리 없음 · `helmGlobals`·레거시 생성기 0 · `argocd-cm`에 `kustomize.buildOptions: "--enable-helm"` 있음.
- 측정 스크립트: `.superpowers/t047/measure_rbac.py` · `measure_rbac2.py`(로컬 · gitignore). G4의 검사는 이 판정을 `validate.sh`(yq)로 옮긴 것이어야 하고, 같은 렌더에서 같은 결과가 나오는지로 대조한다.

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

- **G1 머지와 ruleset 적용(운영자 · 2026-09-29 17:07 KST)**: gitops PR #33 → main `fda5a72`(08:07:14Z). ruleset `main`(id 22066865) 갱신 — 규칙 5(`required_linear_history` 추가) · 머지 방식 `["squash"]` · 승인 0 · bypass 없음(현재 사용자 bypass `never`). ruleset `branches`(id **24166519**) 생성 — `creation`·`update`·`deletion` · bypass = 저장소 관리자 역할(현재 사용자 bypass `always`). **개인 계정 저장소에서도 관리자 역할 bypass가 API로 받아들여졌다**(미확인이던 항목 → 실측). 브랜치 이름별 적용 규칙(`/rules/branches/<이름>` 조회): `main` → main ruleset 5규칙뿐 · `bump/dev-…`와 `bump/x/y` → 규칙 없음 · `promote/…`·`renovate/…`·그 밖 → branches ruleset 3규칙. 관리자 자격의 새 브랜치 push 통과(G2 브랜치). **미실측**: App 토큰 push의 거부 · 머지 뒤 브랜치 자동 삭제가 삭제 제한 아래에서도 되는지(G1의 자동 삭제는 ruleset 적용 13초 전이었다 — G2 머지에서 본다).
- **G2 draft PR #34**(gitops `e055e94`) — **arm64 러너 첫 실측(F21)**:

  | 스텝 | 러너(ubuntu-24.04-arm) | 참고: Windows · Git Bash |
  |---|---|---|
  | 2 경로 lint | 1초 | — |
  | 3 도구 설치(5개 · sha256 대조) | 2초 | — |
  | 4 전체 검사 | **35초** | 약 10분 |
  | 5 자기검사(122 케이스) | **184초** | 약 1시간(107 케이스 기준) |
  | 6 gitleaks 히스토리 | 3초 | — |
  | job 전체 | **약 3분 48초** | — |

  전체 검사 PASS 26 · FAIL 0 · WARN 4(기존 system-upgrade digest 경고) · 자기검사 122 케이스 실패 0. 플랫폼 차이가 걱정되던 케이스(`author-only-no-tools` · `author-mergebase-criss-cross` · `-submodule-ignore` · `-no-textconv` · `-not-git` · helm 렌더 픽스처)도 Linux에서 통과했다. 스텝 2는 base 커밋 `fda5a72`의 스크립트로 돌았다. 설치한 도구 다섯 개가 `$RUNNER_TEMP/bin`에서 풀렸다(스텝 4의 경로 확인 통과).
  **뜻**: "전체 자기검사는 태스크 마무리에 한 번"이라는 규칙은 로컬의 1시간 비용 때문이었다. CI에서는 3분이므로 **PR마다 전체 실행이 가능**하다 — 로컬은 영향 받는 케이스만, 전체 판정은 CI가 맡는다.

- **결정 D5(사용자 2026-09-29): 자기검사는 main push에서 항상, PR에서는 `tests/` 또는 `.github/`가 바뀐 경우에만.** 봇 dev bump PR의 검사가 약 45초로 끝난다(SC-010). P3 해소.
- **G2 갱신(PR #34 head `3f144d7`)**: 스텝 2b(자기검사 대상 판정 · 워크플로 인라인 · PR 코드 실행 전 · 실패 시 실행 쪽) + 스텝 5 조건(`run != '0'`) + 스텝 2의 head 커밋 확인 + 발신자 입력(PR 이벤트에서만 — push 이벤트에도 `sender`가 있는데 작성자 없이 발신자만 가면 검사 6이 FAIL한다 · 컨트롤러가 스크립트로 확인) + gitleaks 액션 버전을 8.30.1로 맞춤. 판정 스텝을 실제 커밋 범위 8가지로 로컬 실행: 문서만 바꾼 범위 `run=0` · 검사를 바꾼 범위 `run=1` · push `run=1` · 짧은 SHA·없는 객체·빈 값 `run=1`. 러너 두 번째 실행: 판정 `run=1`(변경 3개) · 전체 검사 31초 PASS 26 · 자기검사 174초 122/0. **`run=0` 경로의 러너 실측은 아직 없다**(이 PR은 `.github/`를 바꾼다 — 문서만 바꾸는 다음 PR에서 본다).
- **브랜치 쓰기 제한의 증거 하나**: 관리자 자격의 push에 원격이 `Bypassed rule violations for refs/heads/t047-g2-validate-wiring: - Cannot update this protected ref.`를 돌려줬다 — ruleset이 이 브랜치에 걸려 있고, bypass가 없는 주체라면 같은 문구로 거부된다는 뜻이다(App 토큰으로의 실측은 여전히 T074 · T115).

- **G2 독립 리뷰(2026-09-29 저녁) — 판정 CHANGES_REQUIRED(F1 하나 때문)**:

  | # | 심각도 | 내용 | 조치 |
  |---|---|---|---|
  | F1 | critical | **PR의 base는 봇이 고른다.** 봇이 검사 스크립트를 무력화한 `bump/a`를 base로 잡은 PR(`bump/b → bump/a`)을 열면, 워크플로는 "base의 스크립트"로 봇의 스크립트를 실행해 통과한다. 성공한 check는 head 커밋에 붙으므로 그 PR의 base를 main으로 바꾸면(`edited`는 기본 활동 유형이 아니라 재실행이 없다) required check가 채워진 채로 머지할 수 있다. 컨트롤러가 실험 사본에서 재현(`ATTACKER BASE SCRIPT RAN` · exit 0) | 트리거를 main 대상 PR로 한정 · 스텝 2가 base ref와 base 커밋을 확인 · 스크립트와 diff 기준을 `origin/main`의 끝에서 |
  | F2 | low | required check에 출처(`integration_id`)가 없어 이름만 같으면 어떤 App의 check든 조건을 채운다 | ruleset 선언에 `integration_id: 15368`(GitHub Actions) |
  | F3 | low | 식에서 없는 출력(null)은 0으로 읽힌다 — `outputs.run != '0'`은 출력이 없을 때 거짓이 되어 자기검사가 조용히 꺼진다(주석은 반대로 적혀 있었다) | 출력을 `selftest=run|skip`으로 |
  | F4 | medium | 포크 PR은 워크플로 파일까지 PR 쪽 것으로 돈다. 외부 계정의 포크 PR + 봇 토큰의 머지 | 저장소 설정 둘(결정 D6) |
  | F5–F9 | low·info | 2b의 요약 줄 누락 · main push 실행이 서로 취소됨 · 제한 시간 45분 · lint 출력 안의 워크플로 명령 · 봇이 사람 PR을 닫았다 열어 실패시키는 것 | 전부 반영(마지막 것은 복구 방법을 문서에) |

  수정 뒤 실험 사본에서 11가지 시나리오 실행: 공격자 base ref → 실패 · 공격자 base 커밋 → 실패 · 빈 base ref · `refs/heads/main` 표기 → 실패 · 봇의 금지 변경 → main의 lint가 FAIL · 봇의 제자리 교체 → PASS(PR이 말하는 base가 뒤처져 있어도) · 사람 PR → PASS · 사람 PR에 봇 발신자 → FAIL. 러너 세 번째 실행(head `dcda3a9`) 통과 — 스텝 2가 `origin/main` 끝(`fda5a72`)의 스크립트로 돌았고 stop-commands 토큰은 로그에서 가려졌다.
  **리뷰어가 확인하지 못한 채 남긴 것 → T115 측정에 넣는다**: `workflows` 권한 없는 App이 워크플로를 옛 버전으로 되돌리는 **머지 커밋**이나 옛 커밋을 가리키는 새 브랜치를 push할 수 있는지(통과하면 전제 ①이 무너진다) · 같은 head 커밋의 check가 PR 사이에 공유되는지(수정으로 전제가 사라졌지만 기록용).
- **운영 조건 하나(시험 중 확인)**: main의 dev overlay는 빈 뼈대라 봇이 `images` 블록을 **처음 추가**하는 PR은 제자리 교체가 아니어서 FAIL한다(계약대로). **첫 digest는 pod overlay를 만드는 사람 PR이 넣는다** — T072 · T074의 조건.
- **결정 D6(사용자 2026-09-29): 외부 PR 정책 = 둘 다** — PR 생성은 협력자만(`pull_request_creation_policy: collaborators_only`) + 외부 기여자의 워크플로 실행은 항상 승인(`approval_policy: all_external_contributors`). 두 매개변수와 허용 값은 GitHub REST 문서로 확인했다. App의 PR 생성이 막히는지는 미실측(T074 — 막히면 앞의 설정만 되돌린다).
- **범위 밖 관찰(기록만 · T116 보안 마무리에서 다룬다)**: 모노레포(`joshuatech_ver2`)에는 ruleset도 브랜치 보호도 없다(조회 결과 0건). 명세는 gitops 저장소의 ruleset만 요구한다. 모노레포의 포크 PR 승인 정책도 "첫 기여자만"이다.

- **G2 머지와 설정 적용(운영자 · 2026-09-29 19:00 KST)**: gitops PR #34 → main `9181e4e`(09:59:48Z). 컨트롤러가 값으로 대조: ruleset `main` — required check `{context: validate, integration_id: 15368}` · 머지 방식 `["squash"]` · 규칙 5 · bypass 없음 / ruleset `branches` — 그대로 / 저장소 — `pull_request_creation_policy: collaborators_only` · 포크 PR 워크플로 승인 `all_external_contributors`. **머지된 브랜치가 자동 삭제됐다**(원격에 `main`만 남음) — 삭제 제한 아래에서도 머지한 사람이 관리자면 자동 삭제가 된다(미실측 항목 해소).
- **main push 실행(`9181e4e`)**: 스텝 2 건너뜀(push 이벤트) · 2b `run — PR 이벤트가 아님` · 전체 검사 33초 PASS 26 · 검사 6 "대상 없음" · 자기검사 178초 122/0 · job 약 3분 41초. 러너 실행 4회(PR 3 + push 1) 전부 통과.
- **G3 · G4 준비**: gitops 작업 트리 둘을 저장소 **밖**에 만들었다(`.superpowers/t047/wt/g3` = 브랜치 `t047-g3-render-diff` · `wt/g4` = `t047-g4-checks`, 둘 다 `9181e4e`에서). 저장소 안에 두면 `validate.sh`의 파일 열거가 작업 트리까지 훑는다. G3은 워크플로 파일만, G4는 `tests/`만 건드리므로 나란히 진행한다.
- **권한 경계 기준 보강(같은 날 저녁 · G4b 지시서를 쓰며)**: 기준을 빌더에게 넘기기 전에 같은 렌더에서 다시 쟀다(F22). 계약의 숫자 하나가 틀렸고(F19 — 라벨 수를 ClusterRole 수로 적었다) 기준을 지나가는 경로 셋을 찾아 계약을 먼저 고쳤다. `secrets` 생성 경로는 범위를 넓히지 않고 「보지 않는 것」과 §6 H8-1로 남겼다. 교훈: 기준선 숫자는 **무엇을 센 것인지**(객체 · 라벨 · 규칙)를 함께 적는다.
- **렌더 기반 검사의 전제 하나를 계약에 넣었다(`29e095e`)**: Argo가 렌더 없이 그대로 적용하는 경로(directory source — `clusters/oci-k3s/apps`)의 문서는 Application뿐이어야 한다. 리뷰 지시서에 "렌더만 보는 검사를 지나가는 입력"을 적다가 찾았다 — 그 경로에 둔 Role·바인딩은 어떤 렌더에도 나타나지 않는다.
- **G3 · G4 · M1 빌드 착수(19:32 · 19:38 KST)**: 워크플로 둘로 돌린다. G3 ∥ (G4a → G4b → G4c), 각 사슬 끝에 독립 리뷰어 둘(초점을 나눈다) · M1은 빌더 → 리뷰어. 빌더는 커밋하지 않는다.
- **승인 관문 실측 V1(20:02–20:21 KST)**: 동작한다 — §8.8. 시험 PR #35–#37은 닫았고 시험 브랜치는 지웠다. gitops의 Environment `production`은 남겨 둔다(관문을 넣으면 쓰고, 넣지 않기로 하면 운영자가 지운다).
- **결정 D7(사용자 2026-09-29): 승인 관문을 넣는다 — 범위는 운영 overlay(`apps/*/overlays/prod/**`)를 건드리는 PR.** 컨트롤러의 권장은 "dev digest 교체가 아닌 모든 PR"이었고 사용자는 좁은 쪽을 골랐다. 남는 것: 플랫폼 · 검사 변경 PR은 지금처럼 봇 토큰으로 머지될 수 있다 — `report.md`에 받아들인 위험으로 적는다. 범위는 판정 규칙만 바꾸면 넓힐 수 있다.
- **결정 D8(사용자 2026-09-29): 승격 PR은 `promote.yml`이 워크플로 토큰(`GITHUB_TOKEN`)으로 연다 — D1을 대체한다.** App은 계속 dev만 다루고(경로 lint를 고치지 않는다) gitops에 App 키를 두지 않는다. 운영자가 보는 승격 PR은 항상 attestation 검증을 거친 워크플로가 만든 것이다(작성자 `github-actions[bot]` — App 토큰으로는 이 작성자를 만들 수 없다). 사람이 하는 일: 승격 실행 · 검사 실행 승인 · 관문 승인 · 머지(FR-038 — auto-merge를 걸지 않는다).
- **1일차 종료(20:40 KST)**: 사용자가 작업을 마쳤다. G3 · G4 · M1 워크플로는 돌고 있다(G3 빌더 문서 단계 · G4a 변이 시험 · M1 리뷰 중). 세션이 닫히면 함께 끊긴다 — 재개는 §9.
- **2일차(2026-09-30) 재개**: 워크플로는 세션과 함께 끊겼다(G3 빌더는 마지막 검증 중 · G4a는 실제 트리 실행 중 · M1 리뷰어 진행 중). 작업 트리와 로그로 복구해 조각마다 이어 갔다.
  - **M1 완료 · 커밋 `332b9cc`**: 리뷰 APPROVED_WITH_FIXES(경보선 디렉터리 규칙을 경로 성분 일치로 · 요약 줄 분기 단언 · T072 안내) 반영 → 하네스 58/0 · 기존 job 셋 불변 · 컨트롤러 검증 뒤 커밋. 러너 실행은 피처 PR에서.
  - **G4a 완료(마무리 빌더)**: 검사 11 `FMT` · 12 `HELM` · 케이스 122 → 136 · 실제 트리 PASS 35. 빌더가 Argo CD v3.5.2 소스(`repository.go` `obj.IsList()`)로 확인해 11.1을 "최상위 `items` 목록은 kind 무관 금지"로 넓혔다 → 계약 표 정정 `bb22e99`. 실제 트리 실행이 한 번 Cygwin fork 고갈로 끊겼다(동시 프로세스가 많을 때).
  - **G3 완료 → gitops PR #38**: 리뷰 둘 APPROVED_WITH_FIXES(권한 분리·본문 주입 / 비교 정확성·명세·러너) → 수정 빌더가 11항목 반영(중간 심볼릭 링크는 `realpath`로 루트 밖이면 실패 · Secret 어노테이션 가림 · apiVersion으로 객체 구분 · 양쪽에 없는 경로 행 · 전환 경로 비교 · `yq -c` 제거 · 한도 60초/15분 · 문서). **러너 첫 실행(`36660577631`)**: validate 3분 47초(자기검사 122/0) · **render-diff 14초**(렌더·비교 스텝 8초 — 로컬 40–70초의 1/5) · render-comment 5초 · 코멘트 "렌더 변경 없음"(대상 30 · kustomization 29 · directory source 1). 
  - **G4b · G4c 완료**: 검사 13 `RBAC`(기준선 전 항목 일치 · 케이스 146) · 4a 보강(`IMG-name`·`IMG-digest`·`IMG-keys`·`IMG-shape`·`IMG-entry` · 케이스 154). G4b가 찾은 계약 빈틈 `*/token`(k8s RBAC는 `*`와 `*/<subresource>`만 와일드카드) → 계약 `cd8f69a` → G4c가 검사에 반영. G4b의 범위 밖 수정 `export -n TMP`(Windows에서 export된 `TMP`가 kustomize helm 인플레이트를 깨뜨림 — 받아들임). G4c의 yq 발견: `-`는 오른쪽부터 묶인다(`10 - 3 - 2` = 9).
  - **G4 독립 리뷰 둘**: 테스트 품질·명세 = APPROVED_WITH_FIXES(회귀 0 · 변이 8/8 · 실측 표 일치 · 계약에 "키 중복 금지" 추가 `0d27e3e`) / **우회 = CHANGES_REQUIRED** — 검사를 고치지 않고 통과하는 입력 둘을 실행으로 재현: **A1** YAML 별칭(`items: *anchor`)은 yq가 `alias`로 보고해 11.1·11.4를 지나가는데 Argo의 디코더는 목록으로 해소한다 · **A2** directory source 경로의 심볼릭 링크 Application은 11.4만 보고 파일 열거(`-type f`)가 빼서 2·7.1·7.4가 못 본다. 계약 표에 두 행 반영 `0ae4afb`(별칭도 풀어서 본다 · directory source 경로의 링크 금지) → 수정 빌더. 교훈: **파싱 도구의 "종류" 판정은 해소 뒤의 값으로 한다** · **열거 규칙이 다른 검사 둘 사이의 틈은 "한쪽만 보는 것"으로 나타난다** — 링크·별칭처럼 같은 파일이 다른 모양으로 읽히는 입력을 리뷰 목록에 고정한다.
  - **G5 완료 → gitops PR #41**(러너: classify 7초 · gate skipped · prod-approval 성공 · 코멘트 "렌더 변경 없음"): 리뷰 둘 APPROVED_WITH_FIXES(관문 우회 없음 · 승격 주입·검증·경쟁 없음) → 반영(⑦ 실패 시 브랜치 삭제 · 안내 · 한계 · README 10행 · 하네스에 원시 바이트 경로). 리뷰 권고 A2(Environment `can_admins_bypass: false`) → 계약 `2fde17b` + 운영자 UI. 실측 V3·V4 → `promote/**`는 ruleset 제외(App도 쓸 수 있음) — 남는 틈은 ⑦ + 발신자 판정 + 관문으로 좁힌다.
  - **자기검사 flaky 1건 발견·수정(`9bd1408`)**: PR #38 첫 실행에서 `author-mergebase-diff-fails`가 "객체를 지운 사본을 만들 수 없음"으로 실패 — 어제 같은 러너(git 2.55.0 · 이미지 20260828.587)에서 네 번 통과한 케이스. 원인 가설: 임시 저장소의 객체가 pack 안에 있으면 느슨한 파일을 지워도 남는다(로컬에서 `repack` 뒤 옛 코드로 같은 증상을 재현). 수정: pack을 밖으로 옮겨 풀어 놓은 뒤 지우고, 임시 저장소에 `gc.auto=0` · `maintenance.auto=false`. 남으면 객체 저장 상태를 로그에 남긴다. 교훈: 객체 저장 방식(느슨/pack)에 기대는 테스트 준비는 저장 방식을 먼저 고정한다.
  - **G4 수정 1차(14:22–17:17 KST · 빌더 둘 — 첫 빌더는 RED까지 간 뒤 API 사용량 한도로 끊겨, 둘째가 진행 로그를 읽고 이어 갔다)**: 리뷰가 재현한 넷을 닫았다. A1 — 문서를 읽는 yq 식 일곱 개가 판정 전에 `explode(.)`로 별칭을 푼다 + 풀지 못하는 문서와 별칭이 남은 문서는 새 검사 `11.0 FMT-alias`가 FAIL(fail-closed) · A2 — directory source 경로의 링크는 `11.3`이 FAIL하고 `11.4`는 `-type f`로 맞춤 · A3 — 레거시 생성기 탐색을 문서 전체(`..`)로 · B1 — `--enable-helm` 판정을 pflag의 뜻으로(마지막 값이 이긴다 · `=true` · `=false` · 낱말 경계는 유니코드 공백 전체). 케이스 154 → **161** · 변이 19개 중 18 검출(남은 하나는 동등 변이 — yq의 `explode`가 문서를 제자리에서 바꿔 뒤 가지도 푼 문서를 본다) · 리뷰어의 우회 입력만 든 트리가 수정 전 `[PASS] 11.1`·`[PASS] 11.4` → 수정 뒤 FAIL · 실제 트리 PASS 37 · 기존 검사 출력은 검사 11 머리줄 한 쌍 말고 diff 0.
  - **수정 빌더가 범위 밖에서 찾은 사각 → 계약 `60dee38`**: **컴포넌트 디렉터리 자체가 심볼릭 링크**면 파일 열거가 그 디렉터리를 건너뛰는데 kustomize는 링크를 따라 렌더한다. `platform/<컴포넌트>`를 저장소 안의 숨긴 디렉터리로 가리키는 링크로 바꾸고 그 안에 `cluster-admin` 바인딩을 두면 전체 검사가 exit 0이었다(대조군은 13.2 FAIL · 열거된 kustomization 27 → 26). 링크는 이 저장소에 쓸 일이 없으므로 **트리 어디든 금지**로 계약을 넓혔다 — 경로별 예외를 두는 것보다 전제 하나가 싸다.
  - **G4 수정 2차(17:22–18:26 KST)**: 검사 `11.5 FMT-symlink` — 작업 트리(`find`)와 git 인덱스(모드 120000) 둘 다에서 링크 0을 요구한다(Windows 체크아웃은 링크를 보통 파일로 풀 수 있어 인덱스도 본다). 도구가 없어 검사 11이 SKIP될 때도 11.5는 돈다 · `find` 실패는 FAIL. 케이스 161 → **164** · RED 6 → GREEN · 변이 6/6 검출 · 위 사각 입력이 exit 0 → exit 1(FAIL 줄은 11.5 하나) · 실제 트리 **PASS 38 · FAIL 0 · WARN 4**(11.5 — 작업 트리 항목 1329 · 인덱스 306 · 모드 120000 0).
  - **G4 → gitops PR #42 · 러너 첫 실행(18:33 KST · 실행 `36696860951`)**: 전체 검사(0–13) 37초 · 자기검사 **164 케이스 278초** 실패 0 · validate job 약 5분 20초 · render-diff 16초 · 코멘트 "렌더 변경 없음". 2일차는 여기서 끝났다(#41 · #42 둘 다 머지 대기).
- **3일차(2026-10-01) — 머지 · 관문 실측 · 종료**:
  - **G5 머지(운영자 10:04 KST)**: gitops #41 → main `ddb70c5`(01:04:39Z). 이어서 운영자가 ruleset `main`을 선언 파일로 PUT — 컨트롤러가 조회로 대조: required check `validate` · `prod-approval`(둘 다 `integration_id` 15368) · strict · squash 전용 · 선형 이력 · bypass 0.
  - **관문 실측(§8.11)**: 운영 overlay의 주석 한 줄을 바꾼 시험 PR #43 — 승인 전 머지 **거부**, 승인 뒤 머지 가능. 머지하지 않고 닫았고 브랜치를 지웠다.
  - **G4 머지(운영자 10:39 KST)**: #42에 main(#41)을 받아(충돌 하나 — `tests/README.md`의 러너 실측 줄. 두 쪽의 사실을 합쳤다) head `bb37f62` → 러너(실행 `36799489563`): classify 4초 · 전체 검사 39초 · 자기검사 164 케이스 292초 · validate job 5분 39초 · `gate` skipped → `prod-approval` success(승인 없이) · render-diff 14초 → main `e041f41`(01:39:59Z).
  - **main push 실행(`e041f41` · 실행 `36802183106`)**: 성공 — 전체 검사 37초 **PASS 38 · FAIL 0 · WARN 4 · SKIP 0** · 자기검사 283초 **164 케이스 실패 0** · gitleaks 히스토리 2초 · validate job 5분 28초. PR 전용 job 다섯(`classify` · `render-diff` · `render-comment` · `gate` · `prod-approval`)은 skipped. 이것이 이 태스크의 gitops 쪽 마무리 검사다(전체 판정은 CI — 로컬 전체 실행은 하지 않았다).
  - **정리**: gitops 작업 트리 둘(`wt/gate` · `wt/g4`)과 로컬 브랜치 삭제 · 원격 브랜치는 `main`뿐 · 열린 PR 0.
  - **모노레포 마무리 검사(한 번)**: `tests/run-all.ps1` exit 0 · **ALL PASS**(항목 `ci-kubeconform` 58/0 포함 · infra 61/0). 플랫폼 하네스의 클러스터 · ingress 검사는 `KUBECONFIG` 없이 SKIP — 이 태스크의 gitops 변경은 `.github/` · `tests/` · 문서뿐이라 렌더가 바뀌지 않았다(코멘트 job이 생긴 뒤의 PR 셋 #38 · #41 · #42의 렌더링 diff 코멘트가 전부 "렌더 변경 없음").
  - **원격 설정 대조(읽기 전용 명령 — 런북 §3 T047 「상시 점검 명령」)**: 13항목 중 12 OK · `can_admins_bypass` 1 FAIL(§8.11의 열린 조치).

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
| H8-1 | `secrets` 생성 권한을 통한 토큰 발급 경로 — `kubernetes.io/service-account-token` 형식의 Secret을 만들면 그 ns의 ServiceAccount 토큰을 얻는다. 오늘 그 권한을 가진 규칙은 8개(F22)이고 기준선으로 고정하지 않았다 | 계약 §validate.yml 4 권한 경계 「보지 않는 것」 · `tests/validate.sh` 검사 13 | 그 규칙을 가진 Role·ClusterRole의 집합을 기준선으로 고정할지 **결정**(차트 올림마다 계약을 고치는 비용과 맞바꾼다). 고정한다면 부정 픽스처 1개 + 단언, 아니면 「보지 않는 것」에 사유를 남기고 닫는다 |

출처의 원문: gitops `bootstrap/README.md` 「validate 공백 후보」 ①–④ · `platform/traefik/README.md` 「T047 / converge」 ①–④.

`/speckit-converge`가 이 표를 읽어 `tasks.md`에 Convergence 태스크로 붙인다(컨트롤러는 `tasks.md` 본문을 고치지 않는다).

## 7. 검증 후 결정(VD) 항목

- App의 권한 목록(특히 `workflows` 없음)과 실제 봇 로그인 이름 — **운영자 확인 완료(2026-09-29)**: gitops 저장소에 설치된 App은 `joshuatech-gitapp-1`(봇 로그인 `joshuatech-gitapp-1[bot]` — `VALIDATE_BOT_AUTHORS` 기본값에 있다) · Repository permissions의 `Workflows` = **No access**. 설정 화면으로 확인한 값이고, "워크플로 파일을 바꾸는 push가 실제로 거부된다"는 증거는 T115에서 남긴다. 계약의 `jt-ci[bot]`은 설계 이름이고 실제 App 이름은 `joshuatech-*` 명명 예외를 따른다 — 목록에 둘 다 두는 것은 무해하다(없는 이름은 제한을 더할 뿐이다).
- arm64 러너의 검사 시간 — G2 draft PR에서 실측.
- 포크 PR에서 코멘트 job이 실패하지 않고 건너뛰는지 — 포크가 없으면 조건식 검토로 대신하고 미실측으로 적는다.
- App 토큰의 워크플로 파일 push 거부 · main 직접 push 거부 — T115(승격·롤백 실연)에서 증거를 남긴다.

## 8. G5 설계 — 승격 워크플로와 승인 관문(초안 2026-09-29 저녁 · 결정 대기)

G3 · G4 빌드가 도는 동안 조사한 것이다. **결정은 아직 없다** — 아래 실측(V1)을 먼저 하고, 그 결과로 사용자에게 묻는다.

### 8.1 조사로 확정한 사실

- **F23 GitHub의 동작이 바뀌었다(2026-06-11 changelog "Bot-created pull requests can run workflows if approved" · 공식 문서 GITHUB_TOKEN 절)**: `github-actions[bot]`이 만든 PR의 `pull_request` 실행은 **승인 대기** 상태로 만들어지고, 쓰기 권한 사용자가 "Approve workflows to run"을 눌러야 돈다. 그 전에는 실행이 아예 만들어지지 않았다. → P1에 적은 "`GITHUB_TOKEN`이 만든 PR은 required check가 영영 보고되지 않는다"는 **지금은 사실이 아니다**(옛 동작을 근거로 썼다 — 계약을 정정했다).
- **F24 gitops 저장소의 현재 설정(2026-09-29 조회)**: Environment 0개 · `default_workflow_permissions: read` · `can_approve_pull_request_reviews: false`(워크플로는 PR을 만들 수 없다) · `allowed_actions: all` · `sha_pinning_required: false`(뒤의 둘은 T116의 몫).
- **F25 모노레포에는 Environment `production`이 이미 있다**(2026-09-02 · T003): 보호 규칙은 브랜치 정책 하나(선택 브랜치) · 필수 검토자 없음 · `can_admins_bypass: true`. App 키(`JT_CI_APP_PRIVATE_KEY`)는 이 Environment의 시크릿이다. **App 키는 이미 존재한다** — 없는 것은 gitops 쪽 등록이다(D1이 등록하지 않기로 했다).
- **F26 Environment 필수 검토자(공식 문서)**: 공개 저장소면 Free 플랜에서도 쓸 수 있다 · 검토자는 **사용자 또는 팀**(최대 6) — App은 검토자가 될 수 없다 · 승인 API는 "필수 검토자"만 쓸 수 있다 · `prevent_self_review`는 기본 꺼짐(켜면 실행을 일으킨 사람은 승인할 수 없다 — 운영자가 한 명이므로 끈 채로 둔다) · 기본값으로 **관리자는 보호 규칙을 우회할 수 있다** · 배포 브랜치 정책에서 `pull_request` 실행의 ref는 `refs/pull/*/merge`다.
- **F27 ruleset의 bypass 주체(REST 문서)**: 유형 `Integration`(App ID) · `RepositoryRole` · `User` · `DeployKey` · `Team` · `OrganizationAdmin`, 방식 `always` · `pull_request` · `exempt`. GitHub Actions(App ID 15368)를 bypass 주체로 넣을 수 있는지는 문서로 확정되지 않는다(V4).
- **F28 FR-038의 원문**: "`promote.yml`은 브랜치 + PR 생성까지만 하고 **prod 승격 PR은 사람이 머지한다** — auto-merge를 쓰지 않아야 prod 게이트가 남는다." 곧 원문의 관문은 **사람의 머지 행위**다. 그런데 App은 통과한 PR을 머지 API로 머지할 수 있고 승인 수가 0이다 — 원문의 관문은 App 토큰이 새면 서지 않는다.

### 8.2 무엇이 빠져 있는가

지금까지 닫은 것은 **봇이 만드는 변경의 범위**다(경로 lint — dev digest의 제자리 교체뿐 · PR base 조작 · 발신자 판정 · 브랜치 쓰기 제한). 닫지 못한 것은 **봇이 하는 머지**다: App 토큰을 가진 쪽은 `validate`를 통과한 **남의 PR**을 머지할 수 있다. 운영자가 검토하려고 열어 둔 PR(에이전트가 만든 플랫폼 변경 · 승격 PR)이 검토 전에 머지될 수 있다.

필요한 성질은 하나다: **dev digest 교체가 아닌 변경은, 봇이 줄 수 없는 사람의 승인 없이는 머지되지 않는다.**

### 8.3 승인 관문의 후보

| 안 | 방식 | 봇이 통과시킬 수 있는가 | 운영자 자신의 PR | 경로별 적용 | 비고 |
|---|---|---|---|---|---|
| **M-A(권장)** | required check 안의 job이 **Environment `production`**(필수 검토자 = 운영자)을 요구한다. 승인 전에는 그 job이 대기하고 required check가 보고되지 않아 머지가 막힌다 | 없다(검토자는 사용자·팀뿐) | 승인할 수 있다(`prevent_self_review` 끔) | 워크플로의 판정 job이 정한다 | 승인 이력이 Environment에 남는다. 공개 저장소 Free에서 되는지 실측 필요(V1) |
| M-B | `GITHUB_TOKEN`으로 PR을 열어 실행이 **승인 대기**가 되게 한다(F23) | 확인 필요(App에 `actions: write`가 있으면 실행 승인 API를 쓸 수 있는지) | 해당 없음 | PR을 누가 열었는가로만 갈린다 | 승인이 검사 **앞**에 온다 — 렌더 diff를 보기 전에 누르는 승인이라 "prod 승인"의 뜻이 아니다 |
| M-C | CODEOWNERS(`apps/*/overlays/prod/` = 운영자) + ruleset "code owner 리뷰 필수" | 없다 | **승인할 수 없다**(자기 PR은 승인 불가) → 관리자 bypass가 필요해진다 | CODEOWNERS 경로 | `bypass_actors: []`를 깨야 한다 |
| M-D | ruleset `required_deployments` | 없다 | 가능 | **불가**(모든 PR에 걸린다 — dev 자동 머지가 막힌다) | |

M-A가 서면 **누가 PR을 열고 누가 머지 버튼을 누르든** 성질이 지켜진다. D1(운영자가 PR을 연다)이 지키려던 것 — 토큰 탈취 시 prod가 사람 없이 바뀌지 않는다 — 을 관문이 대신 지킨다.

### 8.4 관문의 범위

| 안 | 승인이 필요한 PR | 막는 것 | 운영자 수고 |
|---|---|---|---|
| (a) prod 경로만 | `apps/*/overlays/prod/**`를 건드리는 PR | 승격의 사람 없는 머지 | 승격마다 승인 1회 |
| **(b) dev digest 교체가 아닌 모든 PR(권장)** | 변경이 "dev overlay의 digest 제자리 교체"가 **아닌** PR 전부 | (a) + 에이전트·사람이 연 플랫폼 PR이 검토 전에 봇에 의해 머지되는 것 | PR마다 승인 1회(머지 명령 대신 승인 — auto-merge를 걸어 두면 승인이 곧 머지다) |

(b)의 판정은 새로 만들 필요가 없다 — **main의 경로 lint를 "봇이 연 것으로 치고" 돌려 통과하면** dev digest 교체뿐인 PR이다(작성자가 누구든). 통과하지 못하면 승인이 필요하다.

### 8.5 승격 PR을 누가 여는가

관문(M-A)이 선 뒤의 선택이다. 어느 안에서도 **끝까지 돌려 보는 것은 첫 pod 이미지가 나온 뒤**(T074 · T115)다 — attestation 검증은 발행된 이미지가 있어야 통과한다.

| 안 | PR을 여는 쪽 | 사람이 하는 일 | 필요한 것 | 대가 |
|---|---|---|---|---|
| O-3(지금 · D1) | 운영자 | 실행 · PR 열기 · 승인 · (머지) | 없음 | 목표와 다르다(봇이 PR을 열지 않는다) |
| O-1 | `promote.yml`(`GITHUB_TOKEN`) | 실행 · 실행 승인 · 관문 승인 · (머지) | 저장소 설정 "Actions의 PR 생성 허용" 켜기 | 승인이 두 번 · 코멘트 job의 토큰도 PR을 만들 수 있게 된다 |
| **O-2(목표 형태)** | `promote.yml`(App 토큰) | 실행 · **관문 승인 1회**(auto-merge가 머지) | gitops에 App 키 등록(Environment 시크릿 · main에서만 읽히게) + 경로 lint가 봇의 prod digest 제자리 교체를 허용 | gitops 저장소가 App 키를 갖는다 |
| O-4 | 모노레포의 승격 워크플로(App 토큰 — 키가 이미 있다) | O-2와 같음 | 계약의 위치 변경(`promote.yml`이 모노레포로) + 같은 lint 변경 | gitops에는 키가 없다 · 승격 도구가 다른 저장소에 있다 |

### 8.6 실측 계획(VD-5의 나머지)

| # | 잴 것 | 방법 | 누가 |
|---|---|---|---|
| **V1** | Environment 필수 검토자가 이 저장소(공개 · Free · 개인 계정)에서 `pull_request` 실행의 job을 멈춰 세우는가 · 그동안 뒤 job의 check가 보고되지 않는가 | Environment 생성 → 시험 브랜치(임시 워크플로 + prod overlay의 주석 한 줄)로 draft PR → 대기 상태 조회 → 승인 → 통과 확인 → 거절도 1회 | Environment 생성 · 승인 = 운영자 / 브랜치 · PR · 조회 = 컨트롤러 |
| V2 | 배포 브랜치 정책이 `refs/pull/*/merge`를 받는가 | Environment에 시크릿을 둘 때만 필요(O-2) | 같음 |
| V3 | `GITHUB_TOKEN`이 연 PR의 실행이 승인 대기가 되는가 | O-1을 고를 때만 | — |
| V4 | ruleset bypass 주체로 GitHub Actions(15368)를 받는가 | `promote/**` 전용 ruleset을 만들 때(O-1 · O-3) | 운영자(ruleset 쓰기) |
| V5 | 관문 대기 중 App의 머지 시도가 거부되는가 | App 토큰이 필요하다 → T115 | — |
| V6 | `gh attestation verify`가 러너에서 요구하는 권한 | 발행된 이미지가 필요하다 → T074 | — |

### 8.7 T047에서 끝낼 수 있는 것과 없는 것

- **끝낼 수 있다**: PR 템플릿 · 관문(V1이 통과하면 — 워크플로 job + ruleset의 required check 추가) · `promote.yml`의 본체(입력 검증 · dev digest 읽기 · attestation 검증 먼저 · prod digest의 제자리 교체 · 브랜치).
- **끝낼 수 없다**: 승격을 끝까지 돌려 보는 것(이미지가 없다 — T074 · T115) · App이 관문을 통과시키지 못한다는 증거(V5 — T115).
- 그래서 O-2 · O-4를 고르더라도 **T047에서는 관문과 `promote.yml`의 본체까지** 만들고, App 토큰으로 PR을 여는 마지막 단계는 키를 다루는 T074와 함께 켠다. 그때까지 승격 PR은 O-3으로 연다(관문이 있으므로 성질은 이미 지켜진다).

### 8.8 V1 실측 결과(2026-09-29 20:02–20:21 KST) — **동작한다**

준비: 운영자가 gitops에 Environment `production`을 만들었다(필수 검토자 = 운영자 1명 · `prevent_self_review: false` · 배포 브랜치 정책 없음 · `can_admins_bypass: true` — 컨트롤러가 조회로 대조). 컨트롤러가 임시 워크플로(`detect` → `gate`(Environment 요구) → `prod-approval`(판정을 모으는 job, `if: always()`))를 담은 draft PR 셋을 열었다. 셋 다 머지하지 않고 닫았고 시험 브랜치도 지웠다.

| 경우 | PR · 실행 | 관찰 |
|---|---|---|
| prod overlay를 건드림 — **승인 전** | #35 · #36 | 실행 `waiting` · job `gate` `waiting` · **job `prod-approval`은 목록에 없고 check도 없다**(앞 job을 기다리는 job은 만들어지지 않는다) · 승인 대기 목록에 Environment `production`과 검토자 1명 |
| 운영자가 **거절** | #35 · 실행 `36559454829` | `gate` = `failure` → `prod-approval` = `failure`(로그 `detect=success need=need gate=failure`) · 실행 `failure` |
| 운영자가 **승인** | #36 · 실행 `36559677315` | `gate` = `success`(승인 뒤 3초 만에 끝남) → `prod-approval` = `success` · 실행 `success` |
| prod overlay를 건드리지 않음 | #37 · 실행 `36559680227` | `gate` = `skipped` → `prod-approval` = `success`(승인 없이 · 실행 시작부터 약 20초) |

- 승인 · 거절은 **이력으로 남는다**(실행의 approvals 조회 — 상태 · 코멘트 · 누가). 대기한 시간은 러너 시간을 쓰지 않는다(job이 시작되지 않은 채 기다린다).
- 기존 `validate` 검사는 세 PR에서 그대로 돌아 통과했다(관문 워크플로와 독립).
- **잰 것과 재지 않은 것**: 잰 것은 "승인 전에는 판정 job의 check가 보고되지 않는다"까지다. "그래서 머지가 막힌다"는 그 check를 ruleset의 required check로 등록해야 잴 수 있다 — 등록은 관문을 실제로 넣을 때(G5) 하고, 그때 승인 전 머지 시도가 거부되는지를 잰다. App이 승인 API를 쓸 수 없다는 것은 문서 근거뿐이다(V5 — T115).
- **에이전트의 자격에 대한 관찰**: 승인 대기 조회의 `current_user_can_approve`가 컨트롤러의 조회에서도 `true`였다 — 컨트롤러가 쓰는 `gh` 자격이 운영자 계정의 것이기 때문이다. 관문은 **봇 토큰**을 막는 장치이고, 운영자 자격을 쓰는 에이전트는 규칙으로 막는다: 승인 API(`…/pending_deployments` POST)는 `gh pr merge`와 같은 **운영자 전용 명령**이다. 관문을 넣을 때 에이전트 규칙(`.claude/rules/infra.md` 「Credentials」)에 적는다. 더 단단한 방법 — 에이전트에게 승인 · 머지 · 설정 쓰기 권한이 없는 전용 토큰을 주는 것 — 은 T116(보안 마무리)의 후보로 넘긴다.

### 8.9 결정 뒤의 G5 형태(D7 · D8)

```
승격 실행(운영자 · workflow_dispatch, 입력 pod)
  └─ promote.yml  [main에서 돈다 · 워크플로 토큰 · contents: write + pull-requests: write]
       ① 입력 검증  ② dev overlay의 digest 읽기  ③ attestation 검증(실패하면 여기서 끝)
       ④ prod overlay의 digest를 제자리 교체  ⑤ 브랜치 promote/prod-<pod>-<sha7> push
       ⑥ PR 생성(작성자 github-actions[bot] · auto-merge를 걸지 않는다)
PR의 검사
  ├─ (운영자) 검사 실행 승인 — 워크플로 토큰이 연 PR의 실행은 승인 대기로 만들어진다
  ├─ validate        [required]  경로 lint → 전체 검사 → (tests/·.github/가 바뀌면) 자기검사 → gitleaks
  ├─ render-diff → render-comment     렌더링 비교 코멘트(G3)
  └─ 관문: 판정(prod overlay를 건드렸는가) → gate(Environment production · 필수 검토자 = 운영자) → prod-approval [required]
(운영자) 코멘트 확인 → 관문 승인 → 머지
```

| 바꾸는 것 | 어디 | 누가 적용 |
|---|---|---|
| 관문 job 셋(판정 · gate · prod-approval) — `validate`가 성공한 뒤에 승인을 요청한다 | gitops `.github/workflows/validate.yml`(G3이 머지된 뒤에 얹는다) | PR |
| `promote.yml` · PR 템플릿 | gitops `.github/` | PR |
| required check에 `prod-approval` 추가 | `.github/ruleset-main.json` | PR 머지 뒤 운영자 |
| `promote/**`를 워크플로와 관리자만 쓰게 하는 ruleset `promote` + ruleset `branches`의 제외 목록에 `promote/**` 추가 | `.github/ruleset-promote.json`(새 파일) · `.github/ruleset-branches.json` | 운영자 |
| 저장소 설정 "Actions의 PR 생성 허용" | 저장소 설정 | 운영자 |
| 승인 API는 운영자 전용 명령 | 모노레포 `.claude/rules/infra.md` + 한국어 미러 | 모노레포 커밋 |
| 계약 §이미지·승격 · §validate.yml(D1 문단을 D7 · D8로) | 모노레포 `contracts/gitops-repo.md` | gitops PR보다 먼저 |

`promote/**`를 따로 막는 이유: 승격 브랜치를 App이 쓸 수 있는 이름(`bump/**`)에 두면, 워크플로가 브랜치를 올리고 PR을 열기까지의 짧은 틈에 App 토큰으로 커밋을 끼워 넣을 수 있다. 그 PR의 작성자는 `github-actions[bot]`이라 경로 lint가 제한하지 않고, 끼워 넣은 커밋이 운영 overlay 밖을 건드리면 관문(D7의 범위)도 보지 않는다.

**남은 실측(운영자와 함께)**: V4 · V3 — 결과는 §8.10.

### 8.10 V3 · V4 실측 결과(2026-09-30 11:50–11:56 KST)

| # | 잰 것 | 결과 |
|---|---|---|
| V4-a | ruleset의 bypass 주체로 GitHub Actions(App ID 15368)를 받는가 | **거부** — `POST …/rulesets` 422 `Actor GitHub Actions integration must be part of the ruleset source or owner organization`. 개인 계정 저장소에서는 GitHub Actions를 우회 주체로 넣을 수 없다 → 승격 브랜치 전용 ruleset은 만들 수 없다 |
| V4-b | 워크플로 토큰이 `promote/**` 브랜치를 만들 수 있는가 | **됨** — ruleset `branches`(24166519)의 제외 목록에 `refs/heads/promote/*` · `refs/heads/promote/**/*`를 더한 뒤(운영자 PUT · 11:50 KST). 시험 PR #39의 job이 `promote/vd5-test-<run id>`를 push(rc 0) |
| 설정 | "Actions의 PR 생성 허용" | 운영자 PUT → `can_approve_pull_request_reviews: true`(조회로 대조) |
| V3-a | 워크플로 토큰이 PR을 만들 수 있는가 | **됨** — PR #40, 작성자 `app/github-actions`(커밋 author·committer `github-actions[bot]` · 서명 없음) |
| V3-b | 그 PR의 검사 실행이 승인 대기로 만들어지는가 | **됨** — `validate` 실행이 `conclusion: action_required`로 만들어졌고 check는 0 · PR은 BLOCKED |
| V3-c | 운영자가 승인하면 도는가 | **됨** — `POST …/actions/runs/<id>/approve` → `{}` → 같은 실행의 attempt 2(`triggering_actor` = 운영자) → validate 41초 성공 · render-diff 13초 · render-comment 7초 · 코멘트 "렌더 변경 없음" · PR CLEAN |
| 덤 | 경로 lint의 작성자 판정 | `github-actions[bot]`(ID 41898282)은 봇 목록 밖 → "봇 아님 — 경로 제한 없음"(설계대로: 승격 PR의 내용은 main의 워크플로가 만든다) |
| 덤 | 자기검사 건너뜀 경로의 러너 실행 | 처음 재어졌다 — 2b `skip`(`tests/` · `.github/` 변경 없음) → validate job 41초(자기검사 없이) |

시험 PR #39 · #40은 닫았고 브랜치 둘은 지웠다. 저장소 설정 둘(PR 생성 허용 · `promote/**` 제외)은 D8의 형태에 필요하므로 **그대로 둔다** — 선언 파일(`.github/ruleset-branches.json`)은 G5 PR이 원격 값에 맞춘다.

**V4-a의 결과로 정해지는 것**: `promote/**`는 쓰기 권한이 있는 누구나(App 포함) 쓸 수 있는 이름 공간으로 남는다. 틈을 좁히는 것: ①`promote.yml`이 PR을 연 직후 브랜치 끝이 자기가 올린 커밋인지 확인하고 다르면 PR을 닫고 실패한다 ②PR이 열린 뒤 App이 push하면 발신자 판정(검사 6)이 봇 규칙으로 판정해 운영 overlay 변경을 FAIL시킨다 ③운영 overlay 변경은 관문 승인이 필요하다(D7). 남는 틈: 워크플로가 브랜치를 올리고 PR을 열기까지의 몇 초 사이에 App 토큰으로 커밋을 끼워 넣는 것(①이 잡는다 — ①의 확인과 App의 push가 교차하는 아주 짧은 순간만 남는다) → **받아들인 위험으로 `report.md`에 적는다.**

### 8.11 관문 실측 — required check로 등록한 뒤(2026-10-01 10:06–10:40 KST)

§8.8이 남긴 "그래서 머지가 막히는가"를 쟀다. 준비: #41 머지 뒤 운영자가 ruleset `main`에 `prod-approval`을 required check로 적용. 컨트롤러가 운영 overlay(`apps/identity-admin/overlays/prod/kustomization.yaml`)의 주석 한 줄을 바꾼 시험 PR #43을 열었다(실행 `36799512834`).

| 시점 | 관찰 |
|---|---|
| 승인 전(01:06:49Z 실행 시작) | `classify` 3초 → 판정 `need` · `validate` 48초 success · `render-diff` · `render-comment` success(코멘트 "렌더 변경 없음") · **`gate` 대기 · `prod-approval`은 check가 없다** · PR `BLOCKED` |
| 승인 전 머지 시도(운영자) | **거부** — `gh pr merge` → `Pull request … is not mergeable: the base branch policy prohibits the merge.` |
| 승인(운영자 · `pending_deployments` POST) | `gate` 01:21:06Z 시작 → 2초 success → `prod-approval` 01:21:19Z success · 실행 success · 승인 이력 1건(상태 · 코멘트 · 누가 · Environment `production`) |
| 승인 뒤 | 검사 전부 SUCCESS · `mergeStateStatus: CLEAN`(머지 가능) — **머지하지 않고 닫았다**(01:40:42Z) · 브랜치 삭제 |
| 운영 overlay를 건드리지 않는 PR(#42 · 같은 날) | `gate` skipped → `prod-approval` success(승인 없이) — 단 `prod-approval`은 `validate`를 기다리므로 `validate`가 끝난 뒤에 보고된다 |

- **잰 것**: 관문은 required check로서 머지를 막는다 — 운영자 자격의 머지 명령도 승인 전에는 거부된다(ruleset bypass 0).
- **재지 않은 것(T115)**: App 토큰의 승인 API · 실행 승인 API 호출이 거부되는가(문서 근거뿐) · 관문 대기 중 App의 머지 시도.
- **원격에 남은 차이 하나**: Environment `production`의 `can_admins_bypass`가 아직 `true`다(계약은 `false` — `2fde17b`). REST PUT으로는 바뀌지 않아 **운영자가 화면에서 끈다**(Settings → Environments → production → "Allow administrators to bypass configured protection rules" 해제). 켜져 있는 동안 저장소 관리자는 관문 대기를 건너뛰어 배포를 강제로 시작할 수 있다 — App은 관리자가 아니므로 봇 토큰에 대한 성질은 지금도 성립하고, 닫히지 않은 것은 운영자 자격(과 그 자격을 쓰는 에이전트)에 대한 한 겹이다.

## 9. 종료 상태(2026-10-01)

- **gitops 원격**: main `e041f41` · 열린 PR 0 · 브랜치 `main`뿐. 머지 순서 #33 `fda5a72`(G1) → #34 `9181e4e`(G2) → #38 `7675f5f`(G3) → #41 `ddb70c5`(G5) → #42 `e041f41`(G4). 머지하지 않고 닫은 시험 PR: #35–#37(관문 V1) · #39–#40(워크플로 토큰 PR V3) · #43(관문 실측).
- **설정(조회로 대조)**: ruleset `main`(22066865) — required check `validate` · `prod-approval`(출처 15368) · strict · squash 전용 · 선형 이력 · 삭제 · 강제 push 금지 · bypass 0 / ruleset `branches`(24166519) — `main` · `bump/**` · `promote/**` 밖의 브랜치 생성·갱신·삭제는 관리자 역할만 / 저장소 — PR 생성은 협력자만 · 외부 기여자 실행은 항상 승인 · Actions의 PR 생성 허용 / Environment `production` — 필수 검토자 1 · `prevent_self_review: false` · **`can_admins_bypass: true`(운영자 화면 조치 대기 — §8.11)**.
- **모노레포**: M1 `332b9cc`(ci `kubeconform` job) · 계약 파일을 고친 커밋 18개(`1892135` … `60dee38`) · 규칙 `73dca81`.
- **검사의 크기**: `tests/validate.sh` 검사 0–13 · 실제 트리 PASS 38 · FAIL 0 · WARN 4(기존 `platform/system-upgrade` digest 경고) · 자기검사 164 케이스(시작 69).
- **인계**:

  | 받는 쪽 | 항목 |
  |---|---|
  | 운영자(지금) | Environment `production`의 관리자 우회 끄기 → 조회로 `can_admins_bypass: false` 확인 |
  | converge | §6 표(H11-1–4 · H12-1–3 · H8-1) |
  | T072 | copier 생성물을 `scripts/ci/kubeconform-deploy.sh --generated`에 연결(경보선이 요구한다) · pod overlay의 첫 `images` 항목(name · digest)은 사람 PR이 넣는다 |
  | T074 | Application `source.path`는 소문자 `apps/<pod>/overlays/prod`(관문의 경로 판정과 같은 표기) · App의 PR 생성이 `collaborators_only` 아래에서 되는지 · App push 거부(`bump/**` · `promote/**` 밖)와 실제 이벤트의 `sender` 값 · `gh attestation verify`의 러너 권한 |
  | T115 | `promote.yml` 끝까지(⑦ 실패 때 워크플로 토큰의 브랜치 삭제 포함) · App의 승인 API · 실행 승인 API 거부 · 관문 대기 중 App 머지 거부 · App이 워크플로를 옛 버전으로 되돌리는 머지 커밋이나 브랜치를 push할 수 있는지 |
  | T116 | 모노레포 ruleset · `allowed_actions` · `sha_pinning_required` · 에이전트 전용 토큰(승인 · 머지 · 설정 쓰기 권한 없음) |
  | `report.md` | VD-5 결과(§8.8 · §8.10 · §8.11) · 편차: 승격 PR은 App 토큰이 아니라 워크플로 토큰이 연다(D8 — 과제 문구와 다르다) · 받아들인 위험 둘: 관문 범위 밖(플랫폼 · 검사 · 문서) PR은 봇 토큰으로 머지될 수 있다(D7) / `promote/**`는 App도 쓸 수 있어 브랜치 push와 ⑦ 확인 사이의 짧은 경쟁이 남는다(§8.10) |
