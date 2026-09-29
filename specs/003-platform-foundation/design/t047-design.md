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

## 5. 검증 후 결정(VD) 항목

- App의 권한 목록(특히 `workflows` 없음)과 실제 봇 로그인 이름 — 운영자 확인.
- arm64 러너의 검사 시간 — G2 draft PR에서 실측.
- 포크 PR에서 코멘트 job이 실패하지 않고 건너뛰는지 — 포크가 없으면 조건식 검토로 대신하고 미실측으로 적는다.
- App 토큰의 워크플로 파일 push 거부 · main 직접 push 거부 — T115(승격·롤백 실연)에서 증거를 남긴다.
