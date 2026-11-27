# T074 설계: .github/workflows/publish-pod.yml + VD-5(dev bump 자동 머지) 실측

2026-11-16 확정본 — 조사 4 · 초안 · 비판 2렌즈(74A 14건 · 74B 9건) 뒤 컨트롤러 결정을 반영했다. 수: 결정 D1–D19 · 보정 C1–C14(C8은 빈 번호 — 〈설계 커밋〉 9 · 〈조각 ④〉 1 · 〈실측 뒤〉 3) · 하네스 정적 단언 pp-1–pp-25 · 실행 사례 px-1–px-23 · VD 7(T074 안 — VD-5 + VD-T074-1–6) · 라이브로 넘김 5 · report 편차 후보 13 · 대기 사용자 결정 1(UD-1).

경과는 다음과 같다.
- 조사 R1 명세 · 계약 · 순서 / R2 모노레포 CI · 이미지 / R3 gitops · GitHub 설정 / R4 외부 사실 — `.superpowers/t074/research/{spec,ci,gitops,external}.md`
- 초안 `.superpowers/t074/design-draft.md`(D1–D18)
- 비판 A 계약 · 완전성(approve_with_fixes · high 1 · medium 6 · low 7) / B 보안 · 공급망(approve_with_fixes · high 1 · medium 4 · low 4) — `.superpowers/t074/reviews/critique-{A,B}.json`
- 컨트롤러 결정 CD-1–CD-23(비판 반영 — 처리는 §10)

본문은 반영 뒤 모양이다. 반영으로 바뀌거나 더해진 곳에 〔CD-n〕을 단다. 설계 작업은 읽기 전용이었고 GitHub에는 GET(이름 · 설정만)과 공개 소스 조회만 보냈다. 빌드 라운드의 결과와 정정은 bn 「## T074」 절에 적는다(이 문서는 과제가 닫히면 고치지 않는다 — 규칙 specs.md).

표기는 다음과 같다.
- 「확인」: 이 문서가 파일을 직접 읽었거나 GET · 공개 소스로 다시 확인한 것이다(2026-11-16).
- 〔R n §…〕: 조사 보고의 절 · 〔74A-n〕 · 〔74B-n〕: 비판 발견 · 〔CD-n〕: 컨트롤러 결정.
- 「추론」: 실측 전 판단이다(실측은 VD로 넘긴다) · 〔편차 n〕: report.md 편차 후보(§1 끝) · 〔UD-n〕: 사용자 결정(§8).
- 「컨트롤러 확인 필요」: CD가 전제한 사실이 원문과 다른 곳이다(§10 끝에 모은다).
- 줄 번호는 모노레포 HEAD `bb9faef`(미커밋 bn 포함)와 gitops main `87d223d`(GET 확인) 기준이고, §4 보정이 들어가기 전 번호다.

## 약어

- **tasks · spec · plan**: `specs/003-platform-foundation/`의 승인 고정 문서
- **gr** contracts/gitops-repo.md · **pt** contracts/pod-template.md · **bn** design/build-notes.md · **t047** design/t047-design.md · **rs** research.md
- **PP** `.github/workflows/publish-pod.yml` · **AS** `scripts/ci/publish-pod-assert-image.sh` · **BS** `scripts/ci/publish-pod-bump.sh` · **H** `tests/scripts/publish-pod.tests.ps1`(넷 다 새 파일) · **CI** `.github/workflows/ci.yml`
- **G/** gitops 공유 클론 `D:\code\platform-gitops` · **promote** G/.github/workflows/promote.yml · **vsh** G/tests/validate.sh
- **IA/** `apps/identity-admin/`
- **App** `joshuatech-gitapp-1` — 설계 이름 `jt-ci` · 봇 `joshuatech-gitapp-1[bot]` · 계정 ID 323873425(GET 확인) · App ID 4800793(bootstrap.md:23)
- **키**: Environment `production` 시크릿 `JOSHUATECH_CI_APP_PRIVATE_KEY` + 저장소 변수 `JOSHUATECH_CI_APP_CLIENT_ID`(이름 GET 확인). 문면의 `JT_CI_APP_*`가 이것이다.
- **통합**: 기능 브랜치의 커밋을 모노레포 main에 넣는 일 · **seed**: gitops dev overlay에 첫 `images` 항목을 넣는 사람 PR

---

## 1. 과제 문면과 계약 우선 원칙

### 문면 요약(tasks:191 — 확인)

- **실측(사용자 동석) VD-5**: 첫 dev bump PR에서 `gh pr merge --auto --squash`가 걸리고 required check `validate` 통과 뒤 자동 머지되는지, Environment `production` 시크릿이 public · Free 저장소에서 동작하는지 함께 본다. 동작하면 옵션 A, 아니면 옵션 B(dev bump도 사람 머지)로 정하고 결과 한 줄을 「이 체크박스 옆」과 report.md에 남긴다.
- **구현 PP**: paths `apps/<pod>/**` · `packages/django-common/**` · 러너 `ubuntu-24.04-arm` · setup-buildx v4 · login v4(GITHUB_TOKEN) · metadata v6(`type=sha,format=long`) · build-push v7(linux/arm64 · provenance false · cache gha) → digest → attest v4(push-to-registry · create-storage-record false) → create-github-app-token v3(platform-gitops · bump 단계에서만) · 「bump job과 promote job(T047)은 environment production」.
- **bump**: checkout gitops → 브랜치 `bump/dev-<pod>-<sha7>`에서 `kustomize edit set image ghcr.io/joshua92y/identity-admin@sha256:…` → push → `gh pr create`(`chore(<pod>): dev → <short-digest>`) → `gh pr merge --auto --squash`. 바뀌는 것은 dev overlay의 `images[].digest` 줄뿐이다. GHCR 패키지 Public 전환은 사용자가 한 번 한다.

### 계약 우선 원칙

T073 §1과 같다. 문면과 계약이 다르면 계약이 이긴다(infra.md:10 「the contracts prevail」 — 확인). 계약이 외부 실측과 다르면 실측을 따르고 계약을 고친다. tasks · spec · plan은 고정이므로 낡은 문장은 계약 · 규칙 · 런북 · bn · report에서 바로잡는다.

### 문면 · 계약 · 실물의 어긋남(따를 쪽)

| # | 문면 | 정본 · 실물 | 따를 것 |
|---|---|---|---|
| 1 | `kustomize edit set image <img>@sha256:…` | 탐침(v5.8.1)에서 `newName` 줄이 지워지고 파일 전체가 재서식된다 → vsh 검사 6 FAIL · promote ② 「항목 없음」〔R1 §3 · R3 §1 · R4 §4.1〕. gr:96 「값만 바꾸고 들여쓰기·공백을 건드리지 않는다」와도 어긋난다 | 계약 — promote ④ 꼴 제자리 hex 교체(D8 · C1) 〔편차 1〕 |
| 2 | promote job도 `environment: production` | gr:84 D8: promote는 GITHUB_TOKEN · environment 없음 · gitops에 키 없음 | 계약 — environment는 PP bump job만 〔편차 2 — t047:444가 이미 지정〕 |
| 3 | required check `validate` | gr:89: `validate` + `prod-approval` · 둘 다 strict(GET 확인) | 계약 — dev bump는 classify skip이라 prod-approval이 승인 없이 성공(gr:244) 〔편차 3〕 |
| 4 | `JT_CI_APP_*` · `jt-ci[bot]` | 실제 이름(bootstrap.md:23 이름 예외 · GET 확인) | 실물(이름 예외 — 편차 아님) |
| 5 | 트리거는 paths뿐 · 브랜치는 FR-037 「main」 | main에 PP가 없어 머지 전에는 첫 실행이 불가능하다(§2.1) | UD-1 · D2(PR 빌드 검사 · 한정된 dispatch) 〔편차 4〕 |
| 6 | cache gha | main 범위 gha 캐시는 main에서 도는 다른 워크플로가 쓸 수 있고 서명이 없다〔R4 §2.7〕 | 컨트롤러 결정 — 캐시 없음(D5)〔CD-22〕 〔편차 5〕 |
| 7 | 「이 워크플로가 여는 첫 dev bump PR」 · 순서 T074 → T075 | 봇은 제자리 교체만 하므로 항목이 먼저 있어야 한다(gr:83 · G/tests/README.md:25 · t047:223) | D9 seed PR(자리 값 digest) 〔편차 6〕 |
| 8 | 「GHCR 패키지 Public 전환(사용자 1회)」 | 워크플로가 발행한 패키지의 첫 가시성은 문서끼리 어긋난다(§2.5) | VD-T074-2로 잰다 — 생성 즉시 public이면 전환을 「확인」으로 기록〔CD-4〕 〔편차 10〕 |

### report.md 편차 후보

| # | 내용 |
|---|---|
| 1–6 | 위 표 1 · 2 · 3 · 5 · 6 · 7행 |
| 7 | 단계 통합 — 기능 머지 전에 main에 넣는다(UD-1 · CLAUDE.md:48 · 헌법 순서 6→7→8과의 편차) |
| 8 | App push 거부(`bump/**` · `promote/**` 밖)의 실측을 T115로 옮긴다(t047:441의 인계를 바꿈 · D15) |
| 9 | Application `source.path` 소문자 확인을 T075로 옮긴다(산출물 소속 · D15) |
| 10 | GHCR이 생성 즉시 public이면 문면의 「Public 전환」 대신 「확인」(조건부 · D10)〔CD-4〕 |
| 11 | 받아들인 위험: 옵션 A의 dev 배포 권한 = App 키 + 패키지 쓰기 주체 · 자동 머지 경로에 digest 출처 검증 없음(D11 · T115 필수)〔CD-16〕 |
| 12 | promote ③ `--owner`는 같은 워크플로 파일의 PR 실행이 만든 attestation을 거르지 못한다 — 목표 플래그는 T115(C13)〔CD-19〕 |
| 13 | (사용자가 VD-T074-6 탐침을 거절할 때만) Environment 보호 규칙의 거부 쪽은 설정 확인만〔CD-7〕 |

---

## 2. 소스로 확인한 사실(설계에 필요한 것만)

### 2.1 발행은 main에만 열려 있고, 기능의 Verify는 main 발행을 전제한다

**main에만 열려 있다**
- FR-037 `publish-pod.yml(main, paths 필터, …)`(spec:286) · ADR 0002 원칙 5 「발행(이미지 빌드·digest bump·deploy)은 main에서만 한다」(0002-deployment-principles.md:31)〔R1 §1〕.
- 모노레포 Environment `production`(GET 확인): 규칙 `branch_policy` 하나 · 배포 브랜치 `main`(type branch) 하나 · `can_admins_bypass: false` · 시크릿은 키 하나 · `deployments?environment=production` 0건.
- `workflow_dispatch`는 워크플로 파일이 기본 브랜치에 있어야 한다〔R4 §2.3〕. origin/main `93c7469`에는 `.github/workflows`가 없다〔R3 §3〕.
- PR #1(GET 확인): draft · open · head `bb9faef` · 377커밋 · 645파일.

**기능의 Verify가 main 발행을 전제한다**: US6 AC6(spec:146) · US5 AC1(spec:123) · T095(tasks:253) · T115(tasks:339) · 의존 사슬 US2 → US3 → US6 → US4 → US5 → US7 → US8(tasks:368).

**생명주기 규칙**
- CLAUDE.md:48 「do not merge outside `finishing-a-development-branch`」 · :31 · 헌법 Workflow 6 Verify → 7 Finish → 8 Integrate(constitution.md:44-46) · Governance — 위반은 Complexity Tracking에서 정당화하거나 거부하고 개정은 `/speckit-constitution`으로 한다(:49) — 모두 확인. finish-gate는 스킬 호출만 막는다(.claude/hooks/finish-gate.ps1:32).
- 결론: Verify → Finish → Integrate 순서와 「main 전용 발행」은 이 기능 안에서 구조적으로 부딪힌다. T074가 처음 부딪히는 자리이고 US5에서 다시 부딪힌다.

### 2.2 모노레포 설정(GET 2026-11-16 · 확인)

- 머지: `allow_merge_commit` · `allow_squash_merge` · `allow_rebase_merge` 모두 true · `allow_auto_merge` · `delete_branch_on_merge` · `allow_update_branch` 모두 false · public.
- ruleset은 `main`(24626551) 하나다: `deletion` · `non_fast_forward` · required check `gitleaks`(15368) · bypass 0 · PR 규칙 없음 · branches ruleset 없음. `identity-admin` check 추가는 운영자 단계로 남아 있다(bn T073 VD-T073-CI 결과 끝 줄).
- Actions(두 저장소 같다): `allowed_actions: all` · `sha_pinning_required: false`.
- App 설치는 모노레포 · gitops 두 저장소다(bootstrap.md:25 — 사용자 확인 2026-09-02). 모노레포에는 App을 쓰는 워크플로가 없다(CI에 create-github-app-token 0〔74B-1〕). App GET은 404라 설치 범위를 API로 대조하지 못한다〔R3 §2〕.

### 2.3 gitops(파일 · GET 확인)

- **overlay와 Application**: dev overlay는 머리 주석 4줄 + `apiVersion` · `kind` · `resources: []`이고 images가 없다(G/apps/identity-admin/overlays/dev/kustomization.yaml:1-7 — :3은 「dev digest bump는 joshuatech-gitapp-1[bot]의 auto-merge PR로만 바뀐다」). prod · base도 빈 뼈대이고 identity-admin Application이 없다〔R3 §1〕.
- **봇 규칙(vsh)**: `RE_DIGEST`(:557) · `RE_BOT_FILE`(:559) · `RE_BOT_LINE`(:560) · 봇 기본값 `jt-ci[bot],joshuatech-gitapp-1[bot]` · ID `323873425`(:232-233). 작성자나 발신자 중 하나가 봇이면 봇 규칙을 적용한다(gr:98).
- **promote ④ 제자리 교체**(promote:265-319): `grep -n -F` → 줄 형식 → 한 줄 `sed` → `--numstat` = `1\t1\t<path>`(:290-291) → -/+ 두 줄이 hex 밖에서 같다 → yq로 다시 읽기. yq v4.53.6 + sha256(:90-91) · `persist-credentials: true`(:83 · 근거 :42) · stop-commands(:252) · ⑦ 브랜치 끝 확인 · 닫기 · 삭제(:382-410) · ③ `--owner joshua92y`(:247).
- **원격 설정(GET)**: 저장소는 `allow_auto_merge` · `delete_branch_on_merge` true · `allow_update_branch` false · `pull_request_creation_policy: collaborators_only`. ruleset `main`(22066865)은 PR 필수 · 승인 0 · squash만 · `require_extra_approval_for_unattributed_changes: true` · required check `validate` · `prod-approval`(15368 · strict) · 선형 이력 · bypass 0. ruleset `branches`(24166519)는 제외 = 기본 브랜치 · `bump/*` · `bump/**/*` · `promote/*` · `promote/**/*` · bypass RepositoryRole 5. 열린 PR 0.
- **이력**: App이 연 PR과 auto-merge가 걸린 PR은 0건이다(58건 중 〔R3 §2〕). VD-5의 auto-merge 쪽은 한 번도 재지 않았다.

### 2.4 이미지

- Dockerfile(IA/Dockerfile:36-39): `ARG APP_VERSION=0.0.0+local` · `ARG APP_GIT_SHA=0000000` → `LABEL org.opencontainers.image.revision=$APP_GIT_SHA` + ENV 두 값 · `USER 10001:10001`〔R2 §2〕.
- **빌드 컨텍스트 거르기(확인)**: 루트 `.dockerignore`는 `*`다. `-f apps/identity-admin/Dockerfile` 빌드에서 BuildKit은 Dockerfile 옆 `Dockerfile.dockerignore`(허용 6 · 재제외 16)를 먼저 쓴다 — 두 파일의 머리 주석과 VD-T072-5 실측(bn:4443 「ignore가 Dockerfile과 함께 적재 · 컨텍스트 4.52 kB」)이 근거다. 그래서 루트 `.dockerignore`를 바꿔도 이 이미지 빌드는 바뀌지 않는다(D2 paths).
- README는 이미지의 `/src/apps/identity-admin` 최상위가 5개뿐이라고 적는다(IA/README.md:393-397)〔R2 §2〕.
- 기본값 `0000000`은 꼴 검사를 통과한다(conf.py:134 · observability.py:829-841). 값까지 대조하는 곳은 템플릿 하네스 sample-pod뿐이다(`_tree.py:1440-1468`)〔R2 §2〕.
- `--label`이 Dockerfile `LABEL`을 덮는다(탐침 〔R4 §4.2〕). metadata-action 기본 labels에는 revision = github.sha가 있다〔R4 §2.5〕. 그래서 그 labels를 넘기면 revision 단언이 빈 단언이 된다.
- `APP_VERSION`의 배포 값은 정해진 곳이 없다(IA/README.md:388-389 「배포 빌드는 `github.sha`」뿐). deploy/base의 image는 모두 `ghcr.io/joshua92y/identity-admin`이다〔R3 §1〕.
- GHCR: 익명 `ghcr.io/token?scope=repository:joshua92y/identity-admin:pull` → 403(확인 — 없음 또는 비공개).

### 2.5 액션 · 외부 동작

| 액션 | 최신(발행일) | 커밋 SHA〔R4 §1〕 |
|---|---|---|
| checkout | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1`(CI와 같다) |
| setup-buildx | v4.4.1(09-16) | `f87e5991a6d7451dcb8d9637bfbc97413f497069` |
| login | v4.8.0(11-05 — 발행 11일) | `8aa5831fb8d48d8f76594c7ddde61ae58019f550` |
| metadata | v6.2.0 | `dc802804100637a589fabce1cb79ff13a1411302` |
| build-push | v7.4.0 | `c3c9e263c25d99ce0380d002d59b67737d91b0dc` |
| attest | v4.2.2 | `1e69f48acb82d1966a394da916b4c1698aa569d6` |
| create-github-app-token | v3.3.0 | `64ab729a6294000f5aa4a4bc0b73d1f32bc45510` |

- 보안 권고는 0건이다〔R4 §1〕.
- **create-github-app-token**: `client-id`는 v3.1+이고 `app-id`는 deprecated다. `permission-*`가 0개면 설치 권한 전부를 받는다. post 단계가 토큰을 폐기한다. `owner`가 비면 현재 저장소 소유자다〔R4 §1〕.
- **attest**: storage record는 조직 저장소 전용이다(개인 계정이면 건너뛴다). 권한은 `id-token` · `attestations` · `packages: write`. 공개 저장소는 public-good Sigstore로 서명한다〔R4 §2.6〕.
- **setup-buildx v4.4.1(확인 — `src/context.ts:11 · 62-66` @f87e599)**: `buildkitd-flags`가 비면 플래그를 받는 드라이버(기본 docker-container)에 `--allow-insecure-entitlement security.insecure --allow-insecure-entitlement network.host`를 넣는다〔74B-4〕.
- **gh 2.103.3 `pr merge`(확인 — cli/cli 소스)**: 바로 머지 가능(CLEAN · HAS_HOOKS · UNSTABLE)이면 즉시 머지하고 아니면 auto-merge를 건다(merge.go:593 · :826). PR 조회 필드에 `statusCheckRollup`이 없다(merge.go:571 · `lastCommit` = `commits(last:1){nodes{commit{oid}}}` — query_builder.go:434-435). `--match-head-commit`은 `expectedHeadOid`로 간다(merge.go:184 · :294).
- **`gh pr view --json statusCheckRollup`**은 Checks · Commit statuses 읽기가 없는 토큰에서 `Resource not accessible`로 실패한 사례가 있다〔74A-1〕. 그래서 ⑦은 REST만 쓴다(D8).
- **PR 실행 승인**: App 설치 토큰이 연 PR의 `pull_request` 실행은 승인 없이 돈다(문서). GITHUB_TOKEN이 연 PR은 승인 대기가 된다(T047 실측 PR #40)〔R4 §2.2〕.
- **unattributed 설정**: Copilot PR 전용이고 승인 수가 0이면 효과가 없다(문서)〔R4 §2.1〕.
- **GHCR**
  - 첫 가시성은 문서끼리 어긋난다. 「When you first publish a package, the default visibility is private」〔R4 §2.5〕와 「(GITHUB_TOKEN으로 만든 패키지는) inherits the visibility and permissions model of the repository」〔74A-4〕가 함께 있다. 모노레포는 public이다 → VD-T074-2. Public은 되돌릴 수 없다〔R4 §2.5〕.
  - GITHUB_TOKEN 발행은 저장소에 자동 연결되고, 연결 저장소는 admin 권한을 받는다〔R4 §2.5 · 74B-7〕. 그래서 패키지 쓰기 주체는 `packages: write`를 요청한 모노레포 워크플로 전부다(같은 저장소 PR 실행 포함 · 포크는 읽기 전용)〔74B-7〕.
- **build-push v7**: 공개 저장소에서는 provenance mode=max가 기본이고, `DOCKER_BUILD_RECORD_UPLOAD` 기본값은 true다〔R4 §2.7〕.
- **paths 필터 한도(확인 — 현행 workflow-syntax 문서)**: 「more than 3,000 files … not in the first 3,000 … will not run」. 통합 diff는 645파일이다.
- **러너 ubuntu-24.04-arm 20261111**: buildx 0.38.2 · gh 2.103.3 · yq 4.54.3 · kustomize 5.8.3〔R4 §2.4〕.

### 2.6 하네스 관례

- ci-gitleaks.tests.ps1(180줄): 외부 도구 0 · SKIP 없음 · fail closed · YAML 파서 없이 줄 단위 · 도우미 `Get-JobBlock` · `Get-RunBodies` · 대상 바꾸기 env · 요약 `N passed, M failed`〔R2 §3〕.
- **events-compat(확인)**: 스크립트 `scripts/ci/events-compat.sh`와 실행 하네스 `tests/scripts/events-compat.tests.ps1`의 짝이 모노레포 CI 로직의 선례다. 도구(bash · git · node)가 없으면 파일 전체를 SKIP하고 정적 단언도 돌리지 않는다(하네스 머리 주석). 단언 하나의 능력 부족(심볼릭 링크)은 `SKIP ec-26b …` 줄과 `N skipped` 줄로 드러나고 통과로 세지 않는다(run-all.ps1:112-122). 사본 env를 주면 요약 줄에 ` (override: …)`가 붙는다.
- run-all 판정식은 「exit 0 + `^\d+ passed, 0 failed$`」다(확인).
- **규칙 적재(확인)**: `.claude/rules/infra.md`의 paths는 `infra/**` · `scripts/**`다 → AS · BS에 적용된다. `.github/**`에는 경로 규칙이 없다(AGENTS.md 라우팅 표)〔74A-12〕.
- 도구: actionlint 1.7.12 · yq v4.53.6 · kustomize v5.8.1은 `.superpowers/bin`에만 있다. shellcheck · zizmor는 없다〔R2 §5〕.

### 2.7 T047이 T074에 넘긴 것(t047:441)

① Application `source.path` 소문자 ② `collaborators_only` 아래에서 App이 PR을 만들 수 있는가 ③ App push 거부(bump/promote 밖)와 실제 `sender` ④ `gh attestation verify`의 러너 권한(t047 §8.6 V6 — G/tests/README.md:80은 T115로 적는다 · 확인).

### 2.8 「결과 한 줄을 체크박스 옆에」

- 규칙: 승인된 tasks.md에서 허용되는 편집은 체크박스와 converge 단계뿐이다(.claude/rules/specs.md:17 확인). AGENTS.md:9 「No agent may edit an approved …」(확인).
- 승인 문서의 지시: spec:355(확인) · plan:47 · A29(사용자 결정 2026-09-01).
- 선례 T057: 과제 줄 끝에 「**VD-4 결과(2026-10-22): 옵션 A 확정** — …」를 덧붙였고(tasks:155), report.md 줄은 /finish로 미뤘다(bn:541)〔R1 §6〕.
- 이 규칙을 강제하는 훅은 없다.

---

## 3. 결정

### D1 범위 · 파일 〔CD-5 · CD-8 · CD-12〕

**새로 만든다(모노레포)**: PP · AS · BS · H · `tests/run-all.ps1` 슬롯 1b6 `ci-publish-pod` · 런북 bootstrap.md §3 「T074」 절(조각 ④ — C9).

**로직 자리**〔CD-5〕: 워크플로에는 배선만 두고 로직은 스크립트 둘로 옮긴다(선례 events-compat). 워크플로는 env로만 값을 넘기고 `bash scripts/ci/<이름>.sh`로 부른다(run 본문 `${{ }}` 0). 스크립트에는 `.claude/rules/infra.md`가 적용된다(paths `scripts/**` — 확인 · 계약 gr이 이긴다).

**PP의 불변식 자리**: `.github/**`에는 경로 규칙이 없다. 그래서 revision 라벨의 원천 · labels 금지 · 단언 · 순서는 PP 머리 주석 · H · pt(C5)에 두고, 규칙에는 Dockerfile 쪽 문장만 둔다(C6)〔CD-12〕.

**고친다**: §4의 〈설계 커밋〉 보정(C1–C7 · C13 · C14).

**gitops**: seed PR 하나(D9 — 컨트롤러가 준비하고 운영자가 머지한다).

**고치지 않는다**: CI · promote · validate · IA/Dockerfile(VD-T074-2가 연결 대안을 요구할 때만 — D10) · IA/README.md(C8을 뺐다 — 배포 빌드 값의 정본은 pt(C5) · PP 머리 주석 · 런북)〔CD-8〕.

**pod는 하나**: `identity-admin`을 상수로 둔다. 일반화(matrix · 변경 pod 판정)는 SP-2로 넘긴다(§7).

### D2 트리거 · 실행 조건 · 동시성 〔편차 4〕

```
on:
  push:          { branches: [main], paths: [<네 줄>] }
  pull_request:  { paths: [<같은 네 줄>] }
  workflow_dispatch:            # 입력 없음
```

**paths 네 줄**〔CD-5〕
- `apps/identity-admin/**` · `packages/django-common/**` · `.github/workflows/publish-pod.yml` · `scripts/ci/publish-pod-*.sh`.
- 루트 `.dockerignore`는 넣지 않는다. 이 빌드는 첫 줄 범위의 `apps/identity-admin/Dockerfile.dockerignore`를 쓰고 루트 파일을 읽지 않는다(§2.4 확인).

**job 조건**
- `build-check`: `if: github.event_name == 'pull_request'`. 빌드와 단언만 하고 push · attest · 키는 없다. ADR 0002 원칙 5의 「PR 검증」이고 rs:4767-4815 원안의 꼴이다.
- `publish` · `bump`: `if: github.event_name != 'pull_request' && github.ref == 'refs/heads/main'`. 기능 브랜치 ref의 dispatch도 건너뛴다. BS ⓪이 `GITHUB_REF`를 다시 보고, Environment 정책이 셋째 겹이다.

**PR 빌드 검사를 두는 까닭**: 통합 전에 빌드 경로를 러너에서 실증한다(VD-T074-1). main 첫 실행이 실패하면 고칠 때마다 재통합이 필요하다.

**재시도 · dispatch**〔CD-2 · CD-9〕
- 재시도의 기본은 실패한 실행의 「Re-run failed jobs」다. bump만 다시 돌고 publish 출력을 재사용한다. BS가 실패할 때 자기 브랜치를 지우므로 이름이 겹치지 않는다.
- `workflow_dispatch`는 「그 main 커밋에 publish-pod 실행이 하나도 없을 때(paths 필터가 놓쳤을 때)」만 쓴다(런북 C9). 같은 커밋을 다시 발행하면 태그가 옮겨 간다(D5).

**동시성**: `group: publish-pod-${{ github.ref }}` · `cancel-in-progress: ${{ github.event_name == 'pull_request' }}`. PR은 옛 실행을 취소하고, main은 직렬로 돌며 서로 취소하지 않는다(promote:64 · gr:257과 같은 원칙). 기다리는 실행은 하나까지다.

**만들지 않는 것**: `build-check`를 required check로 만들지 않는다. paths 필터 워크플로라 해당하지 않는 PR에서 check가 보고되지 않아 머지가 멈춘다(T116).

### D3 job 경계 · 권한 · 비밀 노출

| job | needs | 권한(job 수준) | environment | 비밀 |
|---|---|---|---|---|
| `build-check` | — | `contents: read` | 없음 | 없음 |
| `publish` | — | `contents: read` · `packages: write` · `id-token: write` · `attestations: write` | 없음 | GITHUB_TOKEN만 |
| `bump` | `publish` | `contents: read`(초안 `{}`에서 바뀜 — 모노레포 sparse checkout)〔CD-5〕 | **`production`**(파일 안 유일) | 키(App 토큰 스텝 하나) |

- **최상위**: `permissions: {}`(zizmor excessive-permissions 기준) · `env`: `POD: identity-admin` · `IMAGE: ghcr.io/joshua92y/identity-admin` · `DOCKER_BUILD_RECORD_UPLOAD: "false"`(빌드 기록 아티팩트 0).
- **bump job의 스텝 순서**〔CD-5〕: 모노레포 checkout(`sparse-checkout: scripts/ci` · `persist-credentials: false`) → yq 설치 → **App 토큰** → gitops checkout(`path: gitops`) → BS. 토큰이 생긴 뒤에 도는 것은 gitops checkout(`token:`)과 BS(env `GH_TOKEN`) 둘뿐이고, job이 끝나면 post 단계가 토큰을 폐기한다(`skip-token-revoke`는 두지 않는다).
- **bump job env 상수**〔CD-17〕: `BOT_SLUG: joshuatech-gitapp-1` · `BOT_ID: "323873425"`. vsh:232-233 기본값과 같은지 H가 대조한다(pp-21 · px-23).
- **공통 규약**: run 본문 `${{ }}` 0(gitleaks g-9 · promote:45 관례) · job `defaults.run.shell: bash` · 스크립트 `set -euo pipefail` · 스텝마다 job 요약에 시각 · 초 · exit 줄(promote의 `on_exit` 꼴) · 실행 주소는 러너 기본 env(`GITHUB_SERVER_URL` · `GITHUB_REPOSITORY` · `GITHUB_RUN_ID`)로 만든다.
- **들여쓰기 규약**(H 전제): 최상위 0칸 · job 2칸 · job 키 4칸 · 스텝 `- ` 6칸. job 블록 안의 주석은 4칸 이상이다(0–2칸 주석은 블록을 끝낸다 〔R2 §3〕).

### D4 액션 핀

- 모든 `uses:`는 `<owner>/<repo>@<40hex> # vX.Y.Z` 꼴이다. 같은 액션은 job이 달라도 같은 SHA를 쓰고, checkout은 CI와 같은 SHA다. 메이저는 문면대로 둔다(v4 · v4 · v6 · v7 · v4 · v3 — 전부 현재 최신 메이저 〔R4 §1〕).
- 판은 §2.5의 최신을 기본으로 하고, 조각 ②에서 `git ls-remote --tags`로 SHA와 판을 다시 대조한다(경량 태그라 태그 SHA가 곧 커밋 SHA다). 그때 발행 14일이 안 된 판(오늘 기준 login v4.8.0)은 직전 판을 쓴다 — 공급망 보수 원칙이고 근거를 bn에 남긴다.
- 이후 갱신은 Renovate `pinGitHubActionDigests`가 맡는다(renovate.json:9-11). 14일 규칙의 Renovate 쪽은 T116이다〔CD-20〕.

### D5 빌드 입력 〔CD-2 · CD-18 · CD-22〕

**with 키 허용 목록**〔CD-18〕
- setup-buildx는 정확히 {`driver-opts`, `buildkitd-flags`}다.
  - `driver-opts: image=moby/buildkit:<판>@sha256:<64hex>` — BuildKit 데몬을 digest로 고정한다(기본은 이동 태그).
  - `buildkitd-flags`는 insecure entitlement가 없는 값으로 **명시**한다. 비우면 위 기본값이 들어간다(§2.5 확인). 구체 값은 조각 ②가 BuildKit `buildkitd` 소스에서 효과 없는 플래그를 골라 정하고 bn에 근거를 남긴다.
  - `version` · `driver` · `endpoint` · `buildkitd-config*`는 두지 않는다. 러너의 buildx와 기본 docker-container 드라이버를 쓰므로 내려받기와 cache-binary 캐시가 없다.
- build-push는 정확히 {`context`, `file`, `platforms`, `provenance`, `sbom`, `build-args`, `tags`, `push`}이고, 적재 빌드에서만 `load`가 더해진다.
  - 값: `context: .`(경로 컨텍스트 — Dockerfile 옆 ignore 적용 · django-pod.md:21) · `file: apps/identity-admin/Dockerfile` · `platforms: linux/arm64` · `provenance: false` · `sbom: false`(끄지 않으면 결과가 인덱스 digest — A18).
  - `build-args`는 정확히 두 줄이다: `APP_VERSION=${{ steps.meta.outputs.version }}` · `APP_GIT_SHA=${{ github.sha }}`. `tags: ${{ steps.meta.outputs.tags }}`.
  - 적재 빌드는 `push: false` + `load: true`, push 빌드는 `push: true`(`load` 없음)다.
- 목록 밖 입력은 H가 FAIL시킨다. 예: `labels` · `annotations` · `cache-*` · `secrets` · `secret-envs` · `secret-files` · `build-contexts` · `allow` · `network` · `outputs` · `builder` · `ssh` · `attests` · `github-token` · `call`. 신뢰 경계를 바꾸는 입력이다 — `build-contexts`는 FROM을 바꿔도 D6를 통과하고, `secret-envs`는 토큰을 층에 남길 수 있다〔74B-4〕.

**캐시 없음**〔CD-22〕
- 컨트롤러 결정이다(편차 5 · 뒤집기 쉬움 · 사용자 결정 대기에서 뺐다).
- main 범위 gha 캐시는 main에서 도는 다른 워크플로가 쓸 수 있고 서명이 없다〔R4 §2.7〕. registry 캐시도 패키지 쓰기 주체 전체가 쓸 수 있다〔74B-7〕.

**metadata**
- `images: ${{ env.IMAGE }}` · `tags: type=sha,format=long` · `flavor: latest=false` → 태그 `sha-<40hex>` 하나. 이동 태그(`main` · `latest`)는 두지 않는다(rs:4789의 `type=raw,value=main` 불채택).
- 같은 커밋을 다시 발행하면(dispatch) 이 태그가 새 digest로 옮겨 간다. 빌드는 재현되지 않는다. 배포는 digest 고정이라 무해하고, 가드는 두지 않는다〔CD-2〕.

**`APP_VERSION`** = `steps.meta.outputs.version` = `sha-<github.sha>`. `/health`의 `version`이 GHCR 태그와 같아진다. Sentry release는 git sha를 쓴다(observability.py:950). 바꾸기 쉬운 값이다.

**login**: publish job에만 둔다 — `registry: ghcr.io` · `username: ${{ github.actor }}` · `password: ${{ github.token }}`.

### D6 이미지 단언 · 발행 순서 — revision 인계(bn:4488 · t073:2325)의 이행 〔CD-4 · CD-5 · CD-21〕

**AS** — env `IMAGE_REF` · `EXPECT_SHA` · `ASSERT_MODE`(`local` 또는 `registry`)
- `registry` 모드에서 먼저 하는 것: `docker buildx imagetools inspect`의 `--format` 템플릿으로 mediaType을 읽어 단일 매니페스트(OCI image manifest 또는 Docker v2 schema 2)이고 index · list가 아님을 본다. 그다음 `docker pull "$IMAGE_REF"`(by digest)를 한다.
- 두 모드에 공통인 단언(같은 코드)
  1. `Os/Architecture == linux/arm64` · `Config.User == 10001:10001`.
  2. 라벨 `org.opencontainers.image.revision == EXPECT_SHA`.
  3. `Config.Env`에 `APP_GIT_SHA=<EXPECT_SHA>`와 `APP_VERSION=sha-<EXPECT_SHA>`가 각각 정확히 하나 있다. 라벨만 보면 metadata 라벨이 섞여도 통과하므로 **값의 원천인 ENV까지 본다**.
  4. 최상위 허용 목록: `docker create` → `docker export | tar -tf -`로 `src/`의 자식 = {`apps`}, `src/apps/identity-admin/`의 자식 = {`.venv`, `identity_admin`, `manage.py`, `pyproject.toml`, `uv.lock`}(README:393-397의 주장을 실물에서 본다).
- 도구는 `docker` · coreutils · `tar`뿐이다(jq 없음 — `--format` 템플릿). 만든 컨테이너는 끝에 지운다.
- **출력 위생**〔CD-21〕: 라벨 · Env · tar 이름처럼 이미지가 고른 글자는 형식을 확인한 값만 찍거나 `::stop-commands::<무작위>` 구간 안에서만 찍는다(promote:252 꼴).

**발행 순서**〔CD-4 — 74B-6의 (가)안〕
- publish: checkout → setup-buildx → login → metadata → 빌드(load) → AS `local` → 빌드(push · 같은 builder · 캐시 적중) → AS `registry`(매니페스트 꼴 → pull → 같은 단언) → attest → verify → `outputs.digest`.
- build-check: checkout → setup-buildx → metadata → 빌드(load) → AS `local`.
- 정상 경로에서 잘못 만든 이미지는 push되지 않는다.
- 남는 틈: push 빌드가 적재 빌드와 다른 결과를 내면(캐시가 빗나가는 등) push 뒤의 `registry` 단언이 잡는다. 그때는 이미 push됐지만 attest와 bump는 없다. 노출 방어는 dockerignore 허용 목록과 T072 gen-33이 맡는다(§9).
- 단언이 실패하면 attest와 bump를 하지 않는다.

### D7 attestation · 자기 검증

- `actions/attest`: `subject-name: ${{ env.IMAGE }}`(태그 없음) · `subject-digest: ${{ steps.push.outputs.digest }}` · `push-to-registry: true` · `create-storage-record: false`.
- 바로 뒤에 자기 검증 한 줄을 둔다(env `GH_TOKEN: ${{ github.token }}`): `gh attestation verify "oci://$IMAGE@$DIGEST" --repo "$GITHUB_REPOSITORY" --signer-workflow "$GITHUB_REPOSITORY/.github/workflows/publish-pod.yml" --source-ref refs/heads/main --deny-self-hosted-runners`. 「attest는 성공했는데 검증할 수 없다」를 승격 때가 아니라 발행 때 잡는다. `--repo` 경로는 개인 저장소에서도 확실한 엔드포인트다〔R4 §2.6〕. 이 네 플래그가 promote ③의 목표 플래그다(C13 · T115).
- job 출력은 digest 하나다.

### D8 bump(BS): 제자리 hex 교체 · PR · 기다림 · 정리 〔편차 1 · CD-1 · CD-2 · CD-17 · CD-21〕

env: `GH_TOKEN`(App) · `DIGEST`(`needs.publish.outputs.digest`) · `APP_SLUG`(`steps.app.outputs.app-slug`) · `BOT_SLUG` · `BOT_ID` · `POD` · `IMAGE` · `GITOPS_DIR`(`gitops`) · 러너 기본 env(`GITHUB_SHA` · `GITHUB_REF` · `RUNNER_TEMP` · `GITHUB_STEP_SUMMARY` …).

- **⓪ 조건과 입력**: `GITHUB_REF == refs/heads/main` · 꼴 `POD` `^[a-z][a-z0-9-]{0,62}$` · `DIGEST` `^sha256:[0-9a-f]{64}$` · `GITHUB_SHA` `^[0-9a-f]{40}$` · `APP_SLUG` · `BOT_SLUG` · `BOT_ID`(숫자) · `command -v yq`가 `$RUNNER_TEMP/bin/yq`이고 판이 v4.53.6 · gitops 작업 트리는 `origin/main`의 끝이고 깨끗하다.
- **① 현재 값**: yq로 dev overlay에서 `newName == $IMAGE`인 항목의 digest를 읽는다(정확히 하나 · `sha256:<64hex>` 꼴).
  - **0개면 실패한다**: 「첫 항목은 사람 seed PR이 넣는다(T074 D9)」. 조용히 건너뛰지 않는다.
  - **같은 값이면** notice를 남기고 exit 0으로 끝낸다. 브랜치와 PR은 만들지 않는다.
- **② 교체**
  - `digest: sha256:<old>`가 든 줄이 정확히 하나이고 `RE_BOT_LINE` 꼴이어야 한다. 그 줄 하나에 `sed -i "${ln}s/sha256:${old}/sha256:${new}/"`.
  - 확인: (가) `--numstat` = `1\t1\t<dev>` (나) -/+ 두 줄이 hex 밖에서 같다 (다) yq로 다시 읽으면 새 digest 하나다. diff 옵션은 promote와 같다(`--no-ext-diff --no-textconv --no-renames --ignore-submodules=none --no-color`).
- **③ 신원 · 커밋**〔CD-17〕
  - `APP_SLUG == BOT_SLUG`이고 `gh api "users/${BOT_SLUG}[bot]" --jq .id` == `BOT_ID`여야 한다. 다르면 커밋 전에 실패한다 — 다른 App의 자격이면 PR이 사람 규칙으로 판정되기 때문이다〔74B-3〕.
  - 작성자 · 커미터는 `${BOT_SLUG}[bot] <${BOT_ID}+${BOT_SLUG}[bot]@users.noreply.github.com>`이다. `git add -- "$dev"`만 하고, 커밋의 부모 == `origin/main` 끝 · `git diff --numstat <main> HEAD` == `1\t1\t$dev`여야 한다.
  - 제목은 `chore(identity-admin): dev → <new hex 앞 12>`이다. 본문은 전체 digest · 원천 커밋 주소 · 실행 주소 · 「attestation 자기 검증 성공」이다.
- **④ 브랜치**: 이름은 `bump/dev-identity-admin-${GITHUB_SHA:0:7}`이다(모노레포 커밋 기준 — 같은 커밋의 PR이 둘 생기지 않는다). `git ls-remote --exit-code`로 이미 있으면 실패한다(남의 브랜치이므로 정리하지 않는다). push는 `git push origin "HEAD:refs/heads/$branch"` 한 줄뿐이다(force · `+` refspec · main 없음). **이 push가 성공한 뒤의 모든 실패는 아래 정리를 거친다.**
- **⑤ PR**: `gh pr create --repo joshua92y/platform-gitops --base main --head "$branch" --title <제목> --body-file <파일>` → 출력이 `^https://github\.com/joshua92y/platform-gitops/pull/[0-9]+$`인지 본다 → 바로 뒤 `git ls-remote`로 원격 브랜치 끝 == 자기 커밋인지 본다. 다르면 정리하고 실패한다(promote ⑦ 꼴)〔CD-17〕.
- **⑥ auto-merge**: `gh pr merge "$n" --repo joshua92y/platform-gitops --auto --squash --match-head-commit "$commit"`〔CD-17〕.
- **⑦ 기다림**〔CD-1〕
  - 10초 간격 · 최대 15분이다(폴링 90회 또는 경과 900초 중 먼저 닿는 쪽).
  - **REST만 쓴다**: `gh api repos/joshua92y/platform-gitops/pulls/<n>`의 `state` · `merged` · `merged_at` · `merged_by.login/id` · `auto_merge`(`enabled_by.login` · `merge_method`) · `mergeable_state` · `head.sha` · `merge_commit_sha`. GraphQL · `statusCheckRollup` · checks API는 쓰지 않는다(App 권한 밖 — §2.5).
  - 판정: `merged` → 머지 결과 대조로 간다. `closed` 미머지 → 실패. `open`인데 `auto_merge` null → 실패. `open`인데 `head.sha` ≠ 자기 커밋 → 실패. 시간 초과 → 실패(요약에는 `mergeable_state`만). `gh api` 오류 → 실패.
  - check 세부는 운영자 · 컨트롤러 GET 몫이다.
  - 첫 조회의 `auto_merge.enabled_by.login` · `merge_method`를 요약에 남긴다(VD-5 d 보조 증거)〔CD-10〕.
- **머지 결과 대조**〔CD-17〕: `merge_commit_sha`를 fetch해, 부모 대비 numstat이 `1\t1\t$dev` 한 줄이고 그 커밋의 dev digest(yq) == `DIGEST`인지 본다. 다르면 실패한다 — 이미 머지된 뒤이므로 되돌리기는 운영자의 revert PR이다(런북). 성공 요약(PR · enabled_by · merge_method · merged_at · merged_by · 경과 초 · 머지 커밋 · 대조 결과)이 VD-5 e의 원본이다.
- **정리**〔CD-2〕: ④ push 뒤의 실패 갈래에서 PR이 있으면 `gh pr close`(실패하면 `gh pr merge --disable-auto`) → `git push origin --delete "$branch"` → `git ls-remote`로 없어졌음을 확인한다. PR을 만들기 전에 실패했으면 브랜치만 지운다. 결과(닫기 · auto-merge 해제 · 삭제 · 확인)를 요약에 남기고, 정리가 실패해도 job은 원래의 실패로 끝난다.
- **출력 위생**〔CD-21〕: gh 출력과 저장소의 값은 형식을 확인한 값만 찍거나 stop-commands 구간 안에서만 찍는다. 토큰은 찍지 않는다.
- **쓰지 않는 것**: `kustomize`(설치도 호출도). 들여쓰기 · 키 순서 · `newName`에 의존하지 않으므로 T075가 overlay를 어떤 꼴로 쓰든 상관없다.
- **gitops checkout**: `repository: joshua92y/platform-gitops` · `ref: main` · `token: ${{ steps.app.outputs.token }}` · `persist-credentials: true` · `path: gitops`. promote:42와 같은 근거다 — 이 job은 gitops의 코드를 실행하지 않고 yq · grep · sed · git만 쓴다.
- `<sha7>` · `<short-digest>`의 정의는 계약에 적었다(C1).
- **수정 라운드 1 보정(2026-11-16 · 리뷰 RA · RB → 컨트롤러 결정 B4 · B5)**
  - **①′ 낡은 실행 가드**(① 뒤 · ② 전): 모노레포 REST `compare/<GITHUB_SHA>...main`을 워크플로 토큰으로 읽는다(BS env `MONOREPO_TOKEN: ${{ github.token }}` — 이 조회 한 번에만 쓴다). `identical`이면 계속한다. `ahead`여도 바뀐 파일(`filename` · `previous_filename`)이 paths 네 줄(D2)에 걸리지 않으면 계속한다. 걸리면 낡은 실행이다 — notice와 요약 `[stale]`(마지막 main 커밋 sha7)만 남기고 exit 0으로 끝낸다(브랜치 · PR 없음). `behind` · `diverged` · 바뀐 파일 300개 이상(응답 상한) · 조회 오류 · 응답 꼴 오류는 실패(`stale-check`)다. 경로 판정은 GitHub 필터와 같다(`*`는 `/`를 넘지 않는다). 같은 digest면 ①이 가드보다 먼저 끝낸다.
  - **⑦ base**: 조회마다 `base.ref == main`이어야 한다(아니면 `base` — 정리 · 실패).
  - **대조 더하기**: 머지 커밋의 부모가 하나(squash)여야 하고, App 토큰 REST `compare/<머지 커밋>...main`이 `identical` · `ahead`여야 한다(gitops main에 들어갔다). 요약에는 머지 때 head가 이 실행의 커밋인지 남긴다.
  - **④ push 실패**: `git push`가 실패로 끝나도 `git ls-remote`로 본 원격 끝이 이 실행의 커밋이면 정리를 거쳐 실패한다. 아니면 정리하지 않는다(남의 브랜치일 수 있다).
  - **정리 · 닫기 실패**: `gh pr close`가 실패하면 PR을 다시 읽는다. 이미 머지됐으면 정리를 멈추고 머지 결과 대조로 간다 — 통과하면 exit 0(종료 코드 0 = 머지 확인)이고, 요약에는 `**정리 중단**`과 `**머지 확인** — [<코드>] 판정 뒤 …`가 남는다. 머지되지 않았으면 `--disable-auto`로 간다.
  - **취소**: run 줄은 `exec bash scripts/ci/publish-pod-bump.sh`다. 러너는 취소 · job 시간 초과 때 스텝 프로세스의 PID에만 SIGINT → 7.5초 → SIGTERM → 2.5초 → SIGKILL을 보낸다(actions/runner `src/Runner.Sdk/ProcessInvoker.cs` — 2026-11-16 컨트롤러 확인: `kill(_proc.Id, …)` · `NixKillProcessTree`는 `_proc.Kill()`뿐). `bash <스크립트>`였다면 신호가 부모 셸에만 가서 스크립트가 고아로 남는다 — 그러면 post 단계가 App 토큰을 폐기한 뒤라 정리도 실패한다.
    - 스크립트는 INT · TERM trap으로, ④ 뒤 · 머지 전이면 정리하고 exit 130(`cancel`)으로 끝난다.
    - 정리 중의 신호는 무시한다. 그래서 정리 창은 SIGINT부터 10초이고, 실패 갈래의 정리 도중에 취소가 와도 정리를 마친다.
    - push 도중의 신호는 원격 끝이 자기 커밋일 때만 정리한다.
    - 정리 중 머지를 보면 대조하지 않고 메모만 남긴다(취소 중이다 — 운영자가 확인한다).
    - SIGKILL까지 가면 요약에 정리 줄이 없다 — 런북 §3 T074의 운영자 GET으로 남은 PR · 브랜치를 본다.
  - **까닭 코드 추가**: `stale-check` · `base` · `cancel`. 정본 목록은 BS 머리 주석이다.
- **수정 라운드 2 보정(2026-11-16 · 재검토 A RN-2–4 · B L1–L8 → 컨트롤러 결정 B6)**
  - ①′: compare 응답의 `files`가 목록이 아니면(`(.files | tag)` ≠ `!!seq` — 없음 · null · map) `stale-check`. identical도 빈 목록이 온다(2026-11-16 컨트롤러 GET — 두 저장소).
  - 두 compare의 머리 = `refs/heads/main`(모노레포 `<원천 커밋>...refs/heads/main` · gitops `<머지 커밋>...refs/heads/main`).
  - 모노레포 토큰: ⓪ 존재 확인 직후 `declare +x mono="$MONOREPO_TOKEN"` · `unset MONOREPO_TOKEN` → compare 한 줄만 `GH_TOKEN="$mono"` → 바로 `unset mono`. 다른 자식의 env에 남지 않는다.
  - 원격 브랜치 있음 · 없음(④ branch-exists · 정리 확인): `remote_state` — ref 이름이 정확히 `refs/heads/<b>`인 줄만 센다(present · absent · error). `git ls-remote --exit-code`는 쓰지 않는다(패턴이 꼬리 일치라 `refs/heads/x/refs/heads/<b>`도 맞는다).
  - 취소: stop-commands 구간 안에서 신호를 받으면 그 구간부터 닫는다(`SHOW_TOK`). 머지를 본 뒤(대조 중) 받으면 정리하지 않고 요약에 「취소 중 머지 확인」을 남긴다.
  - 문장: 「그 커밋의 실행이 bump한다」를 사실대로 고쳤다 — 실행이 없을 수 있다(런북: `[stale]`인데 그 커밋에 실행이 없으면 U-d).

### D9 gitops seed PR(사람 · 자리 값 digest) 〔편차 6〕

**변경**: dev overlay에 `images:` 블록 하나를 넣는다(사람이 읽기 좋은 꼴 — D8은 꼴에 무관하다).
```
images:
  - name: ghcr.io/joshua92y/identity-admin
    newName: ghcr.io/joshua92y/identity-admin
    digest: sha256:0000000000000000000000000000000000000000000000000000000000000000
```
- 블록 위 주석: 「자리 값 — 어떤 이미지도 가리키지 않는다. publish-pod 첫 실행의 봇 PR이 바꾼다(T074). Application은 T075」.
- 머리 주석의 「빈 뼈대(T003)」 줄을 고친다. `resources: []`는 T075까지 그대로 둔다.

**자리 값을 쓰는 까닭**: 첫 PP 실행의 bump PR이 곧 「이 워크플로가 여는 첫 dev bump PR」이 된다(문면 그대로). 실제 digest로 seed하려면 「실행 #1(bump 실패) → seed → 실행 #2」가 되어 운영자 단계가 늘어난다.

**안전**
- vsh 4a는 꼴만 본다(`RE_DIGEST` — vsh:557 확인). 사람 PR이므로 검사 6 대상이 아니고, classify skip이라 승인 없이 prod-approval이 통과한다.
- 그 overlay를 끌어오는 Application이 없으므로(T075 전) 아무도 pull하지 않는다.
- promote ②가 자리 값을 읽으면 ③ verify에서 실패한다(닫힌 쪽).
- **T075 Application은 봇 PR이 실제 digest를 넣은 뒤에 만든다**(§7).

**절차**: UD-1 결정 뒤(조각 ⑥) 컨트롤러가 gitops 브랜치 `t074-seed`와 PR을 연다(관리자 계정 — 선례 `t057-dragonfly`) → validate 초록 · 렌더 코멘트 「렌더 변경 없음」 확인 → 운영자가 squash로 머지한다(통합 U1b보다 **먼저**).

### D10 GHCR 공개 〔CD-4〕

**첫 가시성은 VD-T074-2에서 잰다**(문서 어긋남 — §2.5)
- 생성 즉시 public이면 UD-2는 사라지고, 문면의 「Public 전환」은 「확인」으로 기록한다〔편차 10〕.
- private이면 세션 안에서 첫 실행 초록(D6 · D7) 직후 사용자가 전환한다(U3 — 컨트롤러 기본값이라 따로 여쭙지 않는다 · §8). 전환을 미루면 T074 체크를 보류한다(D13).

**저장소 연결**
- 워크플로(GITHUB_TOKEN) 발행은 자동 연결된다는 문서를 VD-T074-2에서 확인한다.
- 연결되지 않을 때만 대안을 쓴다: IA/Dockerfile에 `LABEL org.opencontainers.image.source=https://github.com/joshua92y/joshuatech_ver2` 한 줄(템플릿 소유 파일 → 표식 `# identity-admin(T074)` · README 손 수정 표). revision 단언과는 무관하다(다른 키). 미리 적용하지 않는다.

**투명성 로그**: 공개 저장소의 attest는 public-good Sigstore로 서명한다. 그래서 첫 실행부터 이미지 이름 · digest · 워크플로 · 커밋이 공개 투명성 로그에 영구히 남는다. 저장소가 공개라 새로 드러나는 내용은 없다〔74B-7〕.

**쓰기 주체**: 연결 저장소의 워크플로는 패키지 admin 권한을 받는다. publish job만이 아니라 `packages: write`를 요청한 모노레포 워크플로 전부가 쓸 수 있다(같은 저장소 PR 실행 포함 · 포크는 읽기 전용) → T116(패키지 「Manage Actions access」 점검 · `.github/workflows/` 변경 리뷰).

**절차**
- 통합 전 관찰(O1): 사용자가 패키지 목록에 같은 이름이 없음을 UI로 확인한다. 연결 없이 먼저 push한 같은 이름이 있으면 GITHUB_TOKEN이 push하지 못한다〔R4 §2.5〕.
- 전환(U3 — private일 때만): Package settings → Change visibility → Public · 「Inherit access from source repository」 · 연결 저장소가 joshuatech_ver2인지 본다.
- 확인(O3 · 컨트롤러 · 익명): 토큰 요청이 200이고 그 토큰으로 매니페스트(by digest)가 200이다(VD-T074-4 · 지금은 403 — §2.4).

### D11 VD-5 측정 · 판정 〔CD-10 · CD-14 · CD-15 · CD-16〕

**판정 기준**: 아래 a–g 전부가 사람의 행동 없이 성립하면 **옵션 A**다.

| # | 볼 것 | 증거(컨트롤러 GET · 조회) |
|---|---|---|
| a | bump job이 Environment `production`에서 대기 · 거부 없이 시작했고 App 토큰 스텝이 성공했다 → **Environment 시크릿 동작** · gitops 단독 설치에서도 토큰 발급(D19) | 실행 jobs · 모노레포 `deployments?environment=production` 1건 |
| b | PR 작성자가 `joshuatech-gitapp-1[bot]`(323873425)다 → `collaborators_only` 아래 생성 성공 | `pulls/<n>` user |
| c | validate 실행이 `action_required` 없이 돌았다(`run_attempt` 1) · `validate` 성공 · classify skip · gate skipped · `prod-approval` 성공 | `actions/runs?head_sha=` · jobs |
| d | auto-merge를 App이 squash로 걸었다 | GraphQL 읽기 query `timelineItems(itemTypes:[AUTO_SQUASH_ENABLED_EVENT, AUTO_MERGE_ENABLED_EVENT])`의 actor login · 보조: BS ⑦ 첫 조회의 `auto_merge.enabled_by` 스냅숏〔CD-10〕 |
| e | 자동 머지 · merged_by 봇 · 브랜치 자동 삭제 · gitops main push validate 실행 · 머지 결과 대조(한 줄 · digest == `DIGEST`) | `pulls/<n>` · `branches/<b>` 404 · runs · BS 요약 |
| f | 발신자(T047 ③의 절반): PR 이벤트의 `sender` · `triggering_actor` · 검사 6의 「봇 판정」 줄 | run · job log |
| g | `require_extra_approval_for_unattributed_changes`(지금 true) 아래에서 auto-merge가 막히지 않았다〔CD-14〕 | ruleset GET · e |

**옵션 B**: b–e 가운데 하나라도 사람의 행동이 필요하면 B다(PR 생성 대신 · 실행 승인 · 머지). 원인별 B-merge · B-run은 D12.
- b가 막히면 계약이 미리 정한 대로(gr:259) 운영자가 `pull_request_creation_policy`만 `all`로 바꾸고(U-a) 「Re-run failed jobs」로 한 번 다시 잰다. BS가 브랜치를 지웠으므로 겹치지 않는다. 그래도 막히면 B다.

**판정이 아닌 것**: a가 실패하면(시크릿 이름 · 형식 · 브랜치 정책 · 설치 범위) 설치 결함이다. A/B를 정하지 않고 고친 뒤 다시 잰다.

**세션 약속**: 측정하는 동안 gitops에 다른 머지를 하지 않는다(strict 정책의 BEHIND 방지).

**받아들인 위험(옵션 A)**〔CD-16〕
- dev 배포 권한 = App 키 + 패키지 쓰기 주체다.
- 자동 머지 경로에는 새 digest의 출처 검증이 없다. 경로 lint는 64자리 hex 꼴만 보고, PP의 자기 검증은 같은 신뢰 영역이며, dev와 prod는 같은 클러스터다.
- C2 · §9 · 〔편차 11〕에 적는다. 출처 검증은 T115 필수 인계다(§7).

### D12 옵션 B로 정해질 때 〔CD-3 · CD-11〕

| 원인 | 모습 | PP · 운영 |
|---|---|---|
| **B-merge** | check는 통과하나 auto-merge가 끝나지 않는다 | bump PR마다 사람이 머지한다. PP는 ⑥ · ⑦을 빼고 「PR을 열고 링크를 요약」하면 성공으로 바꾼다(다음 통합에 넣는다). 그 전까지는 운영자가 ⑦ 창 안에서 머지한다(창이 지나면 BS가 정리 → Re-run) |
| **B-run** | 봇 PR의 validate 실행이 `action_required` | bump마다 운영자가 실행을 승인한다(infra.md:39 — 운영자 전용). auto-merge는 유지할 수 있다 — PP를 바꾸지 않고 운영자가 ⑦ 창 안에서 승인하면 자동 머지된다(놓치면 정리 → Re-run) |

- 세션의 U-b: c가 `action_required`면 운영자가 기다림 창 안에서 대기 실행을 승인해 d–e를 마저 잴 수 있다. 판정은 B-run 그대로다. 승인하지 않으면 시간 초과 → BS가 정리한다.
- 문장 보정: gr:82-83 · :264의 「App이 auto-merge」 문장을 원인에 맞춘 B 문장으로 바꾼다(C11). T115 문면(「VD-5가 B면 같은 PR을 사람이 머지」)은 B-merge에 맞고, B-run이면 「실행 승인 뒤 자동 머지」를 런북 · C11에 적는다.
- **B로 정해질 때 고칠 gitops 문서 · 주석(줄 확인)**: G/README.md:11(「dev bump는 App auto-merge」) · :26(「Allow auto-merge 활성 — dev bump PR의 auto-merge 전제」) · G/.github/workflows/validate.yml:28 · :35 · :74 주석(자동 머지) · G/tests/README.md:84 · dev overlay 머리 주석 :3(「auto-merge PR로만 바뀐다」).

### D13 체크박스 · 결과 한 줄 〔CD-12 · CD-13〕

**[X] 조건**: 아래가 모두 끝나면 T074 줄을 [X]로 켜고 같은 편집에서 줄 끝에 결과를 덧붙인다(T057 선례 tasks:155).
- 통합: PP · AS · BS · H 초록이 main에 들어갔다.
- VD-5 판정: A 또는 B-merge · B-run.
- GHCR 공개: 생성 즉시 public(「확인」) 또는 전환. 전환을 미루면 체크를 보류한다.

**덧붙이는 꼴**: ` — **VD-5 결과(YYYY-MM-DD): 옵션 A 확정** — bump PR #n · 사람 행동 0 · validate+prod-approval 자동 실행(승인 대기 없음) · auto-merge squash · merged_by joshuatech-gitapp-1[bot] · Environment production 시크릿 동작(App 토큰 발급 · gitops 단독 설치) · GHCR Public(확인 또는 전환)`

**근거**
- 승인된 spec:355 · plan:47 · A29가 이 편집을 직접 지시한다. specs.md:17과의 충돌은 C7로 규칙을 고쳐 없앤다.
- AGENTS.md는 고치지 않는다. 그 문장(AGENTS.md:9 「No agent may edit …」)은 이미 체크박스 편집과 공존하고, 허용 편집을 열거하는 곳은 specs.md다〔CD-12〕.

**report.md**: 아직 없다. T117 초안 · /finish 때 넣고(bn:541 선례), bn에 「report 한 줄 대기」를 적는다.

**통합하지 않을 때(UD-1 = C)**: 체크하지 않는다. bn에 「T074 구현 완료 · 실측 대기(머지 뒤)」로 남기고, T075 이하 배포 과제는 막힌다.

### D14 test-first · 하네스 · run-all 〔CD-5 · CD-21〕

**H의 두 계층**
- **정적 계층(pp-\*)**: PP와 두 스크립트의 원문을 줄 단위로 읽는다. 외부 도구 0 · SKIP 없음 · fail closed(파일이 없으면 해당 단언 전부 FAIL). 도우미는 ci-gitleaks의 `Get-JobBlock` · `Get-RunBodies`와 events-compat의 `Get-StepMap`을 복사한다.
- **실행 계층(px-\*)**: 두 스크립트를 Git Bash에서 실제로 돌린다.
  - PATH 앞에 가짜 `gh` · `docker` · `sleep` 심을 두고, bare git 원격 픽스처(가짜 gitops)와 실제 git · yq를 쓴다.
  - yq는 env `PUBLISH_POD_YQ` → PATH → `.superpowers/bin/yq` 순으로 찾고 `$RUNNER_TEMP/bin/yq`로 감싼다.
  - 가짜 gh는 호출을 기록한다. 머지 응답 전에는 bare 원격 main에 squash 커밋을 만들어 그 sha를 `merge_commit_sha`로 준다(대조가 실제 git 객체로 돈다).
  - 실행마다 임시 디렉터리를 쓰고, git은 사용자 설정과 떨어져 돈다(events-compat 꼴).
- **SKIP 규율**: bash · git · yq 가운데 없는 것이 있으면 실행 계층만 `SKIP px-n -- not found: <도구>` 줄과 `N skipped` 줄로 드러내고 통과 수에 넣지 않는다. 정적 계층은 그대로 판정한다(run-all 1b5 주석의 ec-26b 꼴). 파일 전체 SKIP 줄은 두지 않는다(1b5와 다르다 — §10 「컨트롤러 확인 필요」 ①).
- **사본 env**: `PUBLISH_POD_WORKFLOW` · `PUBLISH_POD_ASSERT_SCRIPT` · `PUBLISH_POD_BUMP_SCRIPT`를 주면 요약 줄 끝에 ` (override: …)`가 붙어 run-all 판정을 통과하지 못한다. `PUBLISH_POD_YQ`는 도구 위치라 접미가 없다.
- **요약**: `N passed, M failed`. 실패가 있으면 그 바로 앞에 `failed: <id>, …` 한 줄을 둔다.

**정적 단언 pp-1–pp-28**(pp-26–pp-28과 맵 단언의 정확 비교는 수정 라운드 1에서 더했다 — 리뷰어가 변이 사본으로 정적 계층의 거짓 통과를 실측했다. 맵 단언은 모두 「판독하지 못한 줄 0 · 더 깊은 줄 0」까지 본다. job 키 집합(pp-8 · 9 · 10) · 최상위 env(pp-4) · job env(bump만 {BOT_SLUG, BOT_ID} — pp-21)도 정확히 맞춘다)

| id | 단언 |
|---|---|
| pp-1 | 파일이 있다 · `name: publish-pod` · 최상위 키 = {name, on, permissions, concurrency, env, jobs} |
| pp-2 | `on` = {push, pull_request, workflow_dispatch} · push.branches = [main] · 두 paths 목록이 같고 정확히 네 줄(D2) · dispatch 입력 없음 · `pull_request_target` · `workflow_run` · `schedule` 0 |
| pp-3 | `permissions: {}` · concurrency group · cancel 식이 글자 그대로 |
| pp-4 | env `POD` · `IMAGE` · `DOCKER_BUILD_RECORD_UPLOAD` · `IMAGE == ghcr.io/joshua92y/$POD` == IA/deploy/base의 모든 `image:` 값 |
| pp-5 | jobs = {build-check, publish, bump} · job 수준 `name:` 0 · 모두 `ubuntu-24.04-arm` · timeout 30 · 30 · 20 이하 |
| pp-6 | 모든 `uses:`가 `<owner>/<repo>@<40hex> # vX.Y.Z`이고 리뷰한 핀 표(일곱 액션 — 판 · SHA 글자 그대로 · checkout은 ci.yml과 같다)와 같다 |
| pp-7 | run 본문 `${{` 0 · `toJSON(` 0 · `secrets.` 정확히 1(bump `private-key`) · `vars.` 정확히 1(`client-id`) |
| pp-8 | build-check: if 식 · 권한 = `contents: read`만 · 스텝 = checkout → setup-buildx → metadata → 빌드(load) → AS(`local`) · login · attest · app-token · environment 0 |
| pp-9 | publish: if 식 · 권한 네 줄 정확 · environment 0 · 스텝 순서(D6) · `outputs.digest` == push 빌드 스텝의 `outputs.digest` |
| pp-10 | bump: `needs: publish` · 같은 if · `environment: production`(파일 전체에서 유일) · 권한 = `contents: read`만 · 스텝 순서 = 모노레포 checkout → yq → 토큰 → gitops checkout → BS |
| pp-11 | 모노레포 checkout 셋: `persist-credentials: false` · ref · repository · token 없음 · bump의 것은 `sparse-checkout: scripts/ci`뿐 |
| pp-12 | setup-buildx 둘: 블록이 같다 · with 키 = 정확히 {driver-opts, buildkitd-flags} · `image=moby/buildkit:<판>@sha256:<64>` · `buildkitd-flags` = `--debug=false` 글자 그대로(수정 라운드 1 — 거부 목록 비교를 정확 비교로) |
| pp-13 | metadata 둘: images = env.IMAGE · tags = `type=sha,format=long` 한 줄 · `flavor: latest=false` |
| pp-14 | build-push 셋: with 키 = 정확히 8개 + `load`(적재 빌드에만) · 값(context · file · platforms · provenance false · sbom false · build-args 정확히 두 줄 · tags) · 적재 = `push: false` + `load: true` · push = `push: true` |
| pp-15 | AS 호출 셋: run 본문 = `bash scripts/ci/publish-pod-assert-image.sh` 한 줄 · env = 정확히 {IMAGE_REF, EXPECT_SHA, ASSERT_MODE} · 모드가 자리(local · local · registry)와 맞다 |
| pp-16 | attest 입력 넷 정확 · verify run 본문 = D7 줄과 글자 그대로 같다(`--repo` · `--signer-workflow` · `--source-ref refs/heads/main` · `--deny-self-hosted-runners` — 수정 라운드 1에서 부분 문자열 비교를 정확 비교로) |
| pp-17 | App 토큰: bump에만 · `client-id` · `private-key` 이름 · `repositories: platform-gitops` · `permission-*` = 정확히 contents · pull-requests write · `skip-token-revoke` · `owner` 없음 |
| pp-18 | App 토큰 참조(점 · 괄호 꼴 모두 — `steps.app` · `steps['app']`)는 정확히 셋: App 스텝 출력을 쓰는 gitops checkout `token:` · BS env `GH_TOKEN` · `APP_SLUG`의 자리뿐(수정 라운드 2) |
| pp-19 | gitops checkout: repository · `ref: main` · `persist-credentials: true` + 근거 주석 · `path: gitops` |
| pp-20 | yq: `YQ_VERSION: v4.53.6` + 64hex 짝 · run 본문 전체 = H 상수(들여쓰기 정규화 뒤 글자 그대로 — fetch · `sha256sum -c` · 버전 대조 · `$RUNNER_TEMP/bin` · 수정 라운드 1에서 부분 문자열 비교를 정확 비교로) |
| pp-21 | BS 호출: run 본문 = `exec bash scripts/ci/publish-pod-bump.sh` 한 줄(수정 라운드 1b — D8 「취소」) · env 키 집합 정확 · `BOT_SLUG` == `joshuatech-gitapp-1` · `BOT_ID` == `323873425`(H 상수 — vsh:232-233에서 옮김) |
| pp-22 | AS 원문: `set -euo pipefail` · jq 0 · `--format` 템플릿 · 허용 목록 다섯 이름 · `::stop-commands::` + 무작위 토큰 + 재개 줄 |
| pp-23 | BS 원문: `set -euo pipefail` · `kustomize` 0 · `git add -- "$dev"` 꼴뿐(`-A` · `.` 0) · push 꼴 하나(force · `+` · main 0) · `--auto --squash --match-head-commit` · REST `pulls/` 조회 · `statusCheckRollup` · `gh pr view` · `graphql` · `check-runs` 0 · 상한 15분 이하 · 정리(`gh pr close` · `--disable-auto` · `push origin --delete` · `ls-remote`) · stop-commands · `MONOREPO_TOKEN`은 존재 확인 · 옮기기 · `unset` 세 줄에만 · `$mono`는 ①′ compare 한 줄에만(다른 `GH_TOKEN=` 대입 0) · compare 머리 `...refs/heads/main`(`...main"` 꼴 금지) · `ls-remote --exit-code` 금지 · `trap on_signal INT TERM` · on_signal이 열린 stop-commands 구간을 닫는 줄(수정 라운드 1 · 2) |
| pp-24 | PP 머리 주석: job 셋 항목 · VD-5 · 편차(kustomize 미사용 · 캐시 없음 · PR build-check · dispatch 한정) · 불변식(revision은 `APP_GIT_SHA`에서만 · labels 금지 · push 전 단언) · 들여쓰기 규약 |
| pp-25 | 로직 자리: PP의 run 스텝은 yq 설치 · 자기 검증 한 줄 · 스크립트 호출 넷(AS 셋 · BS 하나)뿐이다(run 스텝 수 정확) |
| pp-26 | 문법: 블록 스칼라 머리는 정확히 `|`만(`>` · `>-` · `>+` · `|-` · `|+` · 들여쓰기 지시자 FAIL — 수정 라운드 2 · 스크립트 호출 · 자기 검증은 한 줄 run만). 블록 스칼라 밖의 코드 줄은 따옴표 없는 `[A-Za-z0-9_-]+:` 키 줄(값이 흐름 · 앵커 · 별칭 · 태그 · 주석 · 지시자로 시작하지 않는다)과 한 줄 스칼라 목록 항목뿐이다(예외 최상위 `permissions: {}`). 값 있는 줄보다 깊은 이음 줄 · 한 줄에서 닫히지 않은 따옴표 · 블록 밖 탭 · 파일 어디든 제어 · 서식 문자와 NEL · LS · PS 0 |
| pp-27 | 경계: 머리 주석 뒤의 0칸 줄은 최상위 키 여섯뿐이다(0칸 주석 0). `on:` · `jobs:` 아래에서 4칸보다 얕은 줄은 트리거 셋 · job 셋의 머리(각각 한 번)뿐이다(얕은 주석 0) |
| pp-28 | 스텝 키 집합 정확: uses 스텝 = {uses, with} 또는 {id, uses, with} · run 스텝 = {name, env, run} · 스텝 `name:` 값에 `${{` 없음(수정 라운드 2) |

**실행 사례 px-1–px-38**(px-24–px-37은 수정 라운드 1 · 1b · px-38과 px-26 · px-29의 추가 사례는 라운드 2)

| id | 대상 | 사례 → 기대 |
|---|---|---|
| px-1 | AS(가짜 docker) | 정상 → 0 |
| px-2 | AS | 라벨 `0000000` → 실패 |
| px-3 | AS | Env `APP_GIT_SHA` 없음(라벨만 맞음) · `APP_VERSION` 둘 → 각각 실패 |
| px-4 | AS | `linux/amd64` · User `0` → 각각 실패 |
| px-5 | AS | 최상위에 `.env` · `src/packages`가 더 있음 → 각각 실패 |
| px-6 | AS `registry` | 매니페스트가 index · list → 실패 / 단일 → pull 뒤 같은 단언 → 0 |
| px-7 | AS | 라벨 · Env · tar 이름에 `::warning::…` 글자 → 실패하고, 그 글자가 stop-commands 구간 밖에 나오지 않는다〔CD-21〕 |
| px-8 | BS(bare 원격 · 가짜 gh · 실제 git · yq) | 자리 값 → 교체 · push · pr create · merge(`--auto --squash --match-head-commit <커밋>`) · MERGED · 머지 결과 대조 → 0 · diff 1쌍 · 커밋 신원 · 부모 · numstat · 커밋 파일 하나 |
| px-9 | BS | 같은 digest → 0 · push · `gh pr` 호출 0 |
| px-10 | BS | 항목 없음(뼈대) → 실패 · push 0 |
| px-11 | BS | 항목 둘 · digest 줄 둘 → 각각 실패 |
| px-12 | BS | 줄 꼴 어긋남(줄 끝 주석) → 실패 |
| px-13 | BS | 브랜치가 이미 있음 → 실패 · 그 브랜치를 지우지 않는다 |
| px-14 | BS | `GITHUB_REF`가 main이 아님 → 실패 |
| px-15 | BS ⑦ | closed 미머지 · open + `auto_merge` null · open + head 이동 · 시간 초과(가짜 sleep · 폴링 90회) · `gh api` 오류 → 각각 실패 + 정리 · 시간 초과 요약에는 `mergeable_state`만〔CD-1〕 |
| px-16 | BS 정리 | PR 생성 실패 → 브랜치 삭제 + `ls-remote` 확인 · 닫기 실패 → `--disable-auto` 시도 · 요약 기록〔CD-2〕 |
| px-17 | BS ③ | 봇 신원 불일치(`APP_SLUG` 다름 · `users/<slug>[bot]` id 다름) → 커밋 · push 전에 각각 실패〔CD-17〕 |
| px-18 | BS ⑤ | PR 생성 뒤 원격 브랜치 끝 ≠ 자기 커밋 → 정리 · 실패〔CD-17〕 |
| px-19 | BS 대조 | 머지 커밋의 digest · numstat 불일치 → 실패(이미 머지 — 정리 없음)〔CD-17〕 |
| px-20 | BS ⓪ | gitops 작업 트리가 더럽다 → 실패 |
| px-21 | BS | gh 출력(머지 상태 · 주소)에 명령 글자 → stop-commands 구간 밖에 나오지 않는다〔CD-21〕 |
| px-22 | BS 전 실행 | 가짜 gh 기록에 `pr view` · `api graphql` · `check-runs` · `statuses` 호출 0〔CD-1〕 |
| px-23 | PP 대조 | PP의 `BOT_SLUG` · `BOT_ID`가 형제 클론 `../platform-gitops/tests/validate.sh`의 `VALIDATE_BOT_AUTHORS` · `VALIDATE_BOT_IDS` 기본값에 든다 — 클론이 없으면 SKIP〔CD-17〕 |
| px-24 | BS ①′ | ahead + 발행 경로 변경(rename의 `previous_filename` 포함) → exit 0 · notice · 요약 `[stale]` + 마지막 main 커밋 sha7 · gh 호출은 compare 하나 |
| px-25 | BS ①′ | ahead + 발행 경로 밖 변경뿐 → 계속해 머지 확인까지 |
| px-26 | BS ①′ | behind · diverged · 바뀐 파일 300 · 조회 오류 · `files` 없음 · null · map → 각각 `stale-check` 실패(오류 글자는 stop-commands 구간 안에만) |
| px-27 | BS 토큰 | 모노레포 compare는 `MONOREPO_TOKEN`으로, 나머지 gh 호출은 App 토큰으로 간다(가짜 gh는 값이 아니라 표지만 기록) · 두 토큰 값은 출력 · 요약 · PR 본문 · 호출 기록 · 커밋(클론 · 원격 `--all`)에 0번 |
| px-28 | BS ④ | push 실패 + 원격이 받음 → 정리(삭제 push 1 · 원격에 없음) · push 실패 + 원격이 안 받음 → 정리 없음(삭제 push 0) |
| px-29 | BS 취소 | (o) ⑦ 기다림 중 SIGTERM → 정리 · exit 130 · 요약 시간 줄 `exit 130` / (i) 실패 갈래 정리 도중 신호 → 정리를 마치고 원래 실패(exit 1) / (ii)(iii) push 도중 신호 → 원격 끝이 자기 커밋이면 정리 · 남의 커밋이면 삭제 0(둘 다 exit 130) / (iv) 대조 도중 신호 → 정리 없음 · 요약 「취소 중 머지 확인」 / (v) ⑦ 기다림 중 SIGINT → 정리 · exit 130 / (vi) stop-commands 구간 출력 도중 신호 → 구간을 닫고 `[cancel]`이 구간 밖 · 정리 |
| px-30 | BS 정리 | 닫기 실패 → 다시 읽어 머지됨 → 정리 중단 · 대조 통과 → exit 0 · 요약 `**정리 중단**` · `**머지 확인** — [<코드>] 판정 뒤 …` |
| px-31 | BS ⑦ · 대조 | base가 main이 아님 → `base` · 머지 커밋이 gitops main에 없음(compare diverged) → `merge-check`(정리 없음) |
| px-32 | AS | `/src/apps` 아래에 `<pod>` 밖의 디렉터리 → `tree` |
| px-33 | AS | docker inspect · imagetools · pull · create 실패 → 각각 `inspect` · `mediatype` · `pull` · `export`(오류 글자는 구간 안에만 · stderr 비어 있음) |
| px-34 | AS | `ASSERT_MODE` 값 밖 · `EXPECT_SHA` 꼴 · registry 모드의 태그 참조 → 각각 `usage` · docker 호출 0 |
| px-35 | BS ③ | users 응답의 login만 다름 → `identity` · 커밋 · push 전에 멈춘다 |
| px-36 | BS 대조 | 부모가 둘인 머지 커밋 → `merge-check`(정리 없음) |
| px-37 | BS ①′ | `scripts/ci/publish-pod-x/y.sh`만 바뀐 ahead → 낡음 아님(계속) · `scripts/ci/publish-pod-bump.sh` → 낡음 |
| px-38 | BS ④ · 정리 | 원격에 꼬리만 같은 ref(`refs/heads/x/refs/heads/<b>`)가 있어도 branch-exists가 아니다(머지까지) · 정리 확인이 그 ref를 「남아 있음」으로 보지 않는다 |

**선택 실행**: env `PUBLISH_POD_TESTS_ONLY`(빌더가 더함)를 주면 요약 줄 끝에 ` (filtered: …)`가 붙어 run-all 1b6이 FAIL로 닫는다. 집계 단언(px-7 · 21 · 22 · 27)의 실행 수 하한은 전체 실행 때만 본다.

**run-all 슬롯 1b6**: 1b5 뒤에 `# 1b6. ci-publish-pod (T074)`를 둔다. 판정은 exit 0 + `^\d+ passed, 0 failed$`(1b5의 양성 증거 규율)이고, 파일 전체 SKIP 갈래는 없다. 하네스 출력에 `N skipped` 줄이 있으면(N > 0) 슬롯이 판정 줄과 별도로 `NOTE ci-publish-pod -- N execution cases skipped (see SKIP lines above)` 한 줄을 찍는다 — 정적 계층만의 PASS가 실행 계층의 부재를 가리지 않게 한다(1b5가 파일 전체 SKIP으로 막는 것을 여기서는 이 줄로 드러낸다 · §10 ① 컨트롤러 답).

**RED 먼저(조각 ①)**: 파일 셋이 없을 때 정적 25 FAIL · 실행 px-1–px-22 FAIL · px-23 FAIL(형제 클론이 없으면 SKIP) · exit 1을 bn에 남긴다.

**하네스 밖 검증(조각 ③)**
- actionlint 0.
- 변이 사본 8개 이상이 각각 해당 단언을 FAIL시킨다. 〔CD-18〕의 넷(`build-contexts` · `allow` · `secret-envs` · setup-buildx `driver: remote` + `endpoint`)을 포함한다.
- 선택: zizmor 1.32.0(`uvx` · offline) · shellcheck(있으면 두 스크립트에).

### D15 T047 인계 넷의 처리 〔CD-14〕

| # | 인계 | 처리 |
|---|---|---|
| ① | Application `source.path` 소문자 | Application은 T075의 산출물이므로 T075로 넘긴다 〔편차 9〕 |
| ② | `collaborators_only` 아래 App PR 생성 | VD-5 b(D11) |
| ③ | `sender` 값과 App push 거부 | `sender`는 VD-5 f에서 관찰한다. 거부는 **T115**로 옮긴다 〔편차 8〕 |
| ④ | V6 `gh attestation verify` 러너 권한 | VD-T074-5(선택)로 이른 측정을 하고, 못 하면 T115(G/tests/README.md:80과 일치) |

- **③의 거부를 옮기는 까닭**: 거부를 재려면 App 토큰으로 일부러 금지된 push를 하는 탐침이 필요한데, 운영 워크플로에 실패하라고 넣는 탐침은 둘 수 없다. T115에는 같은 부류(main 직접 push 거부 · 승인 API 거부)가 이미 있다.
- **T115의 탐침 수단**: 키는 모노레포 Environment(main 전용)에만 있다. 그래서 운영자가 App 임시 개인 키를 만들어 로컬에서 토큰을 받고, 탐침한 뒤 키를 지운다. 다른 수단은 main 워크플로뿐이다.
- **④의 이른 측정**: seed가 dev에만 있고 prod 항목이 없으면, 운영자가 promote를 dispatch할 때 ② → ③ verify까지 돌고 ④에서 「prod 항목 없음」으로 멈춘다. 브랜치 · PR이 0이므로 부작용 없이 V6을 잴 수 있다(Public 전환 뒤).

### D16 직렬화 · 실패한 bump PR 〔CD-2〕

- main 실행은 동시성 그룹으로 직렬로 돌고, bump는 자기 PR의 머지 결과(⑦)까지 기다린다. 실패한 실행은 자기 PR과 브랜치를 정리하고 끝난다. 그래서 pod마다 열린 봇 PR은 언제나 많아야 하나이고 낡은 PR이 남지 않는다(초안의 「운영자가 닫고 지운다」 런북 규칙을 대신한다).
- 재시도는 **가장 새** 실행의 「Re-run failed jobs」다(D2). 낡은 실행을 다시 돌리면 D8 ①′ 가드가 bump를 건너뛴다 — 옛 digest로 되돌리지 않는다(수정 라운드 1). 같은 줄을 바꾼 두 PR은 서로 충돌한다(추론 — 동시에 둘이 열리지 않으므로 드물다).
- strict 정책에서 gitops main이 검사 중에 움직이면 BEHIND가 된다. `allow_update_branch`가 false이고 merge queue가 없으므로 ⑦ 시간 초과 → 정리 → Re-run이다.

### D17 단계 통합의 실행 세부(UD-1 = A) 〔CD-6 · CD-13〕

**머지 방식**: merge commit만 쓴다. squash와 rebase는 SHA를 바꿔 기능 브랜치의 연속성을 깬다.
- 모노레포는 셋 다 허용하므로(§2.2) U1b는 UI 「Create a merge commit」 또는 운영자가 `gh pr merge 1 --merge`로 방식을 고정한다.
- `delete_branch_on_merge`가 false다. 「Delete branch」를 누르지 않는다.

**머지 전에**: U0(App 범위 — D19) · U1a(운영자가 ruleset main에 `identity-admin` required check(15368)를 더하고 되읽는다 — T073이 남긴 단계) · PR #1 Ready for review.

**머지 뒤에**
- 남은 과제는 같은 브랜치에서 이어 간다. main에서 CI 전체가 한 번 돈다(push 트리거).
- 재통합에는 새 PR이 필요하다(PR #1은 첫 머지로 닫힌다). 컨트롤러가 사용자 확인 뒤 열고 → CI 초록(gitleaks · identity-admin) → 사용자가 merge commit으로 머지한다.
- events-compat 게이트가 실제로 작동하기 시작한다. 그때부터 main에 들어간 스키마의 필수 집합은 추가도 제거도 금지다(bn:833-834 확인 — 안 A의 대가 ①).

**기록**: bn 「T074」 절과 런북 §3 T074에 「UD-1 단계 통합 · 일시 · 머지 커밋」 · report 〔편차 7〕 · T118에 헌법 개정 제안과 CLAUDE.md Known Issues 후보(「main 전용 발행 ↔ finish 뒤 통합」).

### D18 그 밖

- CI · promote · validate는 바꾸지 않는다.
- 모노레포 Deployments 탭에 bump마다 「production」 배포 기록이 하나씩 쌓인다. 이름은 시크릿이 있는 Environment가 T003에서 정했다.
  - `deployment: false`(2026-03 기능)는 배포 브랜치 정책과의 관계가 문서에 없어 쓰지 않는다〔R4 §2.3〕.
  - App 키 전용 Environment 분리는 T116 후보다(T092가 같은 Environment에 prod Cloudflare 토큰을 더하기 전에).

### D19 App 설치 범위를 platform-gitops 하나로 〔CD-15〕

- **무엇**: 사용자가 UI로 한 번 줄인다 — GitHub Settings → Applications → Installed GitHub Apps → `joshuatech-gitapp-1` → Configure → Repository access → Only select repositories: `platform-gitops`. 되돌리기 쉽다. 운영자 블록 U0이고, 통합 전 go 조건(O1)이다.
- **까닭**
  - 모노레포에는 App을 쓰는 곳이 없다(§2.2). PP는 `repositories: platform-gitops`로 gitops 설치에서 토큰을 받는다.
  - 모노레포 설치가 남아 있으면, 키 하나로 기능 브랜치(보호 없음)와 main(PR 규칙 없음)에 코드를 넣을 수 있다. 그 코드는 main의 PP가 정상 서명된 이미지로 만들고 dev에 자동 반영된다〔74B-1〕.
- **증명**: VD-5 a가 gitops 단독 설치에서 토큰 발급이 됨을 함께 증명한다(추론 — create-github-app-token은 `repositories`의 저장소에서 설치를 찾는다 〔R4 §1〕).
- **기록**: bootstrap.md:25의 「두 저장소 설치」 문장에 표식 보정(C14) · gr §변경 권한에 설치 범위 문장(C4 — §10 「컨트롤러 확인 필요」 ③). 모노레포 설치가 필요해지면 계약 변경으로 시작한다.

---

## 4. 계약 · 규칙 보정 목록(표식 「T074 보정 2026-11-16」)

읽는 법은 다음과 같다.
- 〈설계 커밋〉 보정의 확정 문면은 해당 파일에 이미 들어갔다(이 문서와 함께 커밋한다).
- 계약 · 런북에는 「T074 보정 2026-11-16」을 단다. 규칙 파일(영어 정본 · 미러)은 앞선 관례대로 `(T074)`를 단다.
- 줄 번호는 보정 전 번호다.

| C | 파일 · 자리 | 보정 | 근거 |
|---|---|---|---|
| C1 | gr:82 dev bump — 새 하위 항목 | 정의(`<sha7>` = `github.sha` 앞 7 · 메시지 = 커밋 · PR 제목 · `<short-digest>` = hex 앞 12) · 제자리 hex 교체(kustomize 미사용 까닭) · 머지 조건 validate + prod-approval · 항목 없음 = 실패 · seed는 사람 PR · 같은 digest면 PR 없음 · 봇 신원 · 브랜치 끝 · head 고정 · 15분 기다림(REST) · 머지 결과 대조 · 실패 정리 · 직렬 | D8 · D16 |
| C2 | gr:83 VD-5 — 새 하위 항목 | 측정 전제(단계 통합 · UD-1) · 판정 기준 ⓐ–ⓔ 요약 · B-merge · B-run · 기록처 · 보호 규칙 거부 쪽(탐침 또는 「설정 확인만」) · 받아들인 위험(CD-16) | D11 · D12 |
| C3 | gr:101 실측 범위 | push 거부 증거 「T074 · T115」 → 「T115」 · T074는 발신자만 · 탐침 수단(임시 키) | D15 |
| C4 | gr:264 변경 권한 | 머지 조건 · seed는 사람 PR · App 설치 범위 = gitops 하나(D19) | D9 · D19 |
| C5 | pt:86 이미지 행 | 배포 빌드 값 · 태그(이동 없음 · 재발행 시 이동) · 단일 매니페스트 · 단언 · push 전 단언 | D5 · D6 |
| C6 | django-pod.md :21 뒤 새 항목 / 미러 :20 뒤 | revision 라벨은 `APP_GIT_SHA` 빌드 인자에서만 · 파이프라인은 metadata `labels` · `annotations`를 넘기지 않는다 · 배포 값과 단언은 pt | D1 · CD-12 |
| C7 | specs.md:17 / 미러 :18 | Allowed edits에 VD 과제의 결과 한 줄(체크박스를 켜는 같은 편집 · T057 선례) | D13 |
| C8 | — | 빈 번호(IA README 보정을 뺐다)〔CD-8〕 | — |
| C13 | gr:84 promote — 새 하위 항목 | ③의 목표 플래그 넷(구현 T115) · 그때까지 `--owner`는 같은 파일의 PR 실행 attestation을 거르지 못한다 → report | CD-19 |
| C14 | bootstrap.md:25 | 「두 저장소 설치」에 표식 — T074 U0에서 줄인다(완료 기록 아님) · 모노레포 설치가 필요하면 계약 변경 | D19 |

〈조각 ④〉
- C9: bootstrap.md §3 새 절 「T074 — publish-pod · VD-5 · GHCR 공개」. §5의 O · J · U 블록 · 실패 갈래 · 재시도 규칙(Re-run · dispatch 한정) · B-merge · B-run 운영 · 머지 결과 불일치의 revert 절차 · 기록 칸.

〈실측 뒤〉 마감 커밋
- C10: tasks:191 [X] + 결과 한 줄(D13).
- C11: gr:83 · :259 · :101 — VD-5 결과(원인 · unattributed 관찰 g 포함) · App PR 생성 결과(설정을 바꿨으면 그 사실) · 발신자 값.
- C12: 런북 §3 T074 · bn 실행 기록(실행 · PR 번호 · 시각 · 판정).

〈인계로 고칠 것〉은 §7 T075 행에 있다.

---

## 5. 빌드 조각

| 조각 | 누가 | 내용 | 끝 조건 |
|---|---|---|---|
| ⓪ | 컨트롤러 | 이 설계 + 〈설계 커밋〉 보정 → 커밋 `docs(003-platform-foundation): T074 설계 + 계약 보정` | 커밋 |
| ① | 빌더(opus) | H(정적 25 + 실행 23) + run-all 1b6 → 실행 | **RED**: 정적 25 FAIL · 실행 FAIL(px-23은 SKIP일 수 있다) · exit 1 — bn에 |
| ② | 빌더 | PP · AS · BS(D2–D8 · D14 머리 주석). `buildkitd-flags` 값 · BuildKit 판과 digest · 액션 판(14일 원칙)을 소스 · `ls-remote`로 정하고 bn에 근거를 남긴다 | H 전부 PASS(이 PC — Git Bash · yq가 있으므로 SKIP 0) |
| ③ | 빌더 | 하네스 밖 검증(D14) | actionlint 0 · 변이 ≥ 8 포착 · (zizmor · shellcheck) |
| ④ | 빌더 | 런북 §3 T074 초안(C9) | 리뷰 통과 |
| ⑤ | 컨트롤러 | 리뷰(렌즈: 보안 · 계약 정합 · 빌드 가능성) → 파일 이름으로 스테이징 → 커밋 `feat(ci): T074 …` → **사용자 확인 뒤 push** | PR #1 CI 초록 + **build-check 초록 = VD-T074-1** |
| ⑥ | 컨트롤러 준비 · 운영자 머지 | **UD-1 결정 뒤** gitops seed PR(D9) | validate 초록 · 머지 |
| ⑦ | 사용자 동석 | 통합 · 실측 세션(아래 블록) | VD-5 판정 · GHCR 공개 |
| ⑧ | 컨트롤러 | 마감: C10–C12 · 학습 로그 `content/tmp/003-t074/<날짜>.md` · 메모리 · (재통합이 필요하면) 새 PR(사용자 확인) | 커밋 |

- UD-1은 조각 ⑥ 전에 여쭙는 유일한 대기 결정이다. ①–⑤는 UD-1과 무관하게 진행한다(B 외 모든 안에서 PP는 main 전용이다)〔CD-6〕.
- VD-T074-6(음성 탐침)은 UD-1과 무관하게 언제든 할 수 있다(사용자 확인 뒤 컨트롤러 push — §6).
- 옵션 B-merge로 정해지면 ⑦b를 둔다: PP를 D12대로 바꾸고 H를 갱신한 뒤 다음 통합에 넣는다.
- 이 PC의 Docker Desktop은 arm64 binfmt가 꺼져 있다(메모리 tool-gotchas). 그래서 실제 이미지 단언은 러너(VD-T074-1)에서 처음 본다.

### 조각 ⑦: 통합 · 실측 세션

블록을 나눈다.
- **O** = 관찰. 컨트롤러가 GET만 한다(`gh run view` · `gh api` GET · 읽기 query · 익명 curl).
- **J** = 판단. 사용자와 함께 한다.
- **U** = 변경. 사용자나 운영자가 한다. 블록 하나에 목적 하나다.
- 변경과 관찰을 한 블록에 섞지 않는다.

| 블록 | 내용 |
|---|---|
| U0 | 사용자: App 설치 범위를 `platform-gitops` 하나로(D19) |
| O1 | 시작 전 점검표: PR #1 head의 CI 전부 초록(build-check 포함) · gitops main에 seed가 들어감 · 열려 있는 gitops PR 0 · 모노레포 Environment `production` 그대로(정책 main · 시크릿 이름) · 사용자 UI 확인 둘(GHCR에 `identity-admin` 패키지 없음 · App 설치 = gitops 하나) → go/no-go |
| U1a | 운영자: ruleset main에 `identity-admin` required check 추가 · 되읽기 |
| U1b | 사용자: PR #1 Ready for review → **Create a merge commit**(또는 운영자 `gh pr merge 1 --merge`) · 메시지에 「T074 단계 통합(UD-1)」 · 브랜치 삭제 버튼을 누르지 않는다 |
| O2 | 머지 커밋의 publish-pod 실행을 찾는다(없으면 VD-T074-3 기록 → U-d). publish: 두 빌드 · AS 두 번 · attest · verify · 패키지 가시성 · 연결(VD-T074-2). bump: D11 a–g 증거를 표로 모은다. 기다림이 끝날 때까지 바꾸지 않는다 |
| J1 | D11 표로 A / B-merge / B-run을 판정한다. 막힌 갈래가 있으면 해당 U로 간다 |
| U-a | (b가 막혔을 때만) 운영자: gitops `pull_request_creation_policy` → `all`(gr:259) · 되읽기 → 운영자 「Re-run failed jobs」 → O2 |
| U-b | (c가 `action_required`일 때) 운영자가 기다림 창 안에서 대기 실행을 승인할 수 있다(d–e 측정 · 판정은 B-run). 승인하지 않으면 시간 초과 → BS 정리 |
| U-c | (두 check 성공 뒤 5분이 지나도 머지되지 않을 때) 운영자가 창 안에서 PR을 머지한다 → B-merge(⑦이 머지를 보고 대조한다) |
| U-d | (그 커밋에 publish-pod 실행이 없을 때만) 운영자: `gh workflow run publish-pod.yml --ref main` → O2 |
| U3 | (VD-T074-2가 private일 때만) 사용자: GHCR Public 전환 |
| O3 | 익명 토큰 · 매니페스트 200(VD-T074-4) |
| U4 | (선택) 운영자: `gh workflow run promote.yml -R joshua92y/platform-gitops -f pod=identity-admin` → O4: ③ verify 결과(V6)와 ④ 「prod 항목 없음」 실패(브랜치 · PR 0)를 읽는다 |

첫 실행이 PP 버그로 실패하면 기능 브랜치에서 고친 뒤 UD-1 범위 안에서 재통합한다(새 PR — D17). paths에 워크플로 · 스크립트가 들어 있으므로 그 머지 push가 PP를 부른다.

---

## 6. VD 목록

### T074 안에서 실측

| VD | 무엇 | 언제 | 통과 |
|---|---|---|---|
| VD-T074-1 | PR #1의 build-check: arm64 러너 적재 빌드(캐시 없음 소요 시간) · AS `local` | ⑤ push 뒤 | job 초록 · 시간 기록 |
| VD-T074-2 | 통합 publish: 적재 빌드 + AS · push 빌드(캐시 적중 — 적재 이미지 ID와 push config digest가 같은지는 관찰만) · 단일 매니페스트 · AS `registry` · attest(public-good) · 자기 검증 네 플래그가 gh 2.103.3에서 받아들여짐 · **패키지 첫 가시성** · **모노레포 자동 연결**〔CD-4〕 | ⑦ O2 | 스텝 전부 초록 · 가시성 · 연결 기록 |
| **VD-5** | D11 a–g | ⑦ O2 · J1 | A · B-merge · B-run 판정 |
| VD-T074-3 | 통합 push(645파일)가 paths 필터로 PP를 불렀는가(관찰만 — 645 < 3,000)〔CD-9〕 | ⑦ O2 | 불렀음(못 불렀으면 U-d로 대신하고 기록) |
| VD-T074-4 | Public 뒤 익명 pull | ⑦ O3 | 200 |
| VD-T074-5(선택) | promote ③ verify의 러너 권한(V6) | ⑦ O4 | 성공 또는 실패 원인 기록(실패면 T115) |
| VD-T074-6 | Environment `production` 보호 규칙의 거부 쪽(음성 탐침)〔CD-7〕 | 언제든(UD-1 무관) | main이 아닌 ref의 job이 거부된다 |

**VD-T074-6 절차**
- origin/main에서 임시 브랜치 `t074-env-probe`를 만들고 `.github/workflows/t074-env-probe.yml` 하나만 넣는다. 그 브랜치 push 트리거 · job 하나 `environment: production` · 스텝은 `echo`만 · secrets · vars 참조 0이다.
- push는 사용자 확인 뒤 컨트롤러가 한다(외부 행동).
- 기대: 배포 브랜치 정책으로 job이 거부된다. 판정은 GET(run · job 결론 · 주석)으로 한다.
- 기록 뒤 원격 브랜치를 지운다. 실행과 거부 기록은 남는다(배포 기록이 생기는지도 함께 본다).
- 사용자가 거절하면 C2 · report에 「보호 규칙은 설정 확인만」으로 남긴다〔편차 13〕.

### 라이브로 넘김

- App push 거부(bump/promote 밖 · main) → T115(D15 — 임시 키 탐침).
- 봇 경로의 digest 출처 검증(CD-16)과 promote ③ 목표 플래그(C13) → T115.
- dev bump → Argo sync ≤ 5분(SC-010) → T115. T075 전에는 Application이 없다.
- Application `source.path` 소문자 → T075.
- strict BEHIND · 실패한 bump의 실제 빈도 → 운영 중 관찰(T098 알림 후보: publish-pod 실패).

---

## 7. 인계

| 받는 쪽 | 항목 |
|---|---|
| T075 | dev overlay의 `images` 항목(`name` · `newName` · digest 줄)을 지우거나 옮기지 않는다 · **Application은 자리 값이 실제 digest로 바뀐 뒤에 만든다** · prod의 첫 항목은 사람 PR이 실제 digest로 넣는다(promote ④ 전제) · `source.path` 소문자 · gitops 문서 정정〔CD-11〕: G/tests/README.md:66(「T074에서 생긴다」 → T075) · :220(빠진 `promote/**` · 「T074·T115에서 실측」 → T115) · G/README.md:36(「첫 dev bump(T074)와 승격 실연(T115)」 → T115) |
| T115(필수) | ① 봇 경로 출처 검증〔CD-16〕: gitops validate 봇 경로의 신뢰 스텝(PR 코드 실행 전 — 스텝 2 자리)에 `gh attestation verify oci://ghcr.io/joshua92y/<pod>@<new> --repo joshua92y/joshuatech_ver2 --signer-workflow joshua92y/joshuatech_ver2/.github/workflows/publish-pod.yml --source-ref refs/heads/main --deny-self-hosted-runners`(Public 뒤) 또는 클러스터 admission — 계약 문장으로 ② promote ③을 같은 네 플래그로(C13)〔CD-19〕 ③ App 토큰 탐침(금지 push · main push · 승인 API) — 수단은 운영자의 App 임시 개인 키 → 로컬 토큰 → 탐침 → 키 삭제〔CD-14〕 ④ V6을 못 쟀으면 V6 ⑤ SC-010 ⑥ VD-5가 B면 원인별 문면(D12) ⑦ dev bump 실연은 main에 새 변경이 들어가야 publish-pod가 돈다 — UD-1이 「T074 한정」이므로 그 통합 전에 같은 결정을 다시 여쭌다(§8) |
| T116 | 모노레포 ruleset(PR 규칙 · `.github/workflows/` CODEOWNERS — 이제 App 키를 읽는 워크플로가 생겼다 · ci.yml:68-70 인계와 같은 무게) · GHCR 패키지 「Manage Actions access」 점검(연결 저장소 하나 · 역할 최소)과 `.github/workflows/` 변경 리뷰〔CD-4〕 · 두 저장소 `sha_pinning_required: true`(합성 액션 내부 핀 먼저 확인) · Renovate github-actions `minimumReleaseAge: "14 days"`〔CD-20〕 · BuildKit digest 갱신 수단(Renovate regex) · App 키 전용 Environment 분리 검토 · paths 필터 워크플로를 required로 넣지 않는다 |
| T117 · /finish | report 편차 1–13 · VD-5 결과 한 줄 · 단계 통합 기록 |
| T118 | 헌법 개정 제안 — 단계 통합을 정식 절차로(`/speckit-constitution` · CLAUDE.md:48 · finish-gate)〔CD-6〕 · CLAUDE.md Known Issues 후보: 「main 전용 발행 ↔ finish 뒤 통합」 · `kustomize edit set image`가 `newName`을 지운다 |
| T098 | publish-pod · bump 실패 알림(⑦ 시간 초과 · 머지 결과 불일치 포함) |
| US5(T092–T095) | prod Worker deploy도 main 전용이다. UD-1이 A-기능 전체면 같은 절차를 따르고, A-T074 한정이면 그때 다시 여쭌다 |
| SP-2 | pod가 둘 이상일 때: 변경 pod 판정 · matrix · `APP_VERSION` 체계 |

---

## 8. 사용자 결정

### 현재 상태(2026-11-16 · 마감 2026-11-17)

- **마감(2026-11-17)**: VD-5 = **옵션 A**(사용자 확정 · bump PR #60 · 사람 행동 0). GHCR은 생성 즉시 Public이라 UD-2는 사라졌다(D10 「확인」). U1b(통합 머지)는 사용자의 1회 예외 결정으로 컨트롤러가 실행했다 — infra.md의 운영자 전용 규칙은 그대로다(build-notes 「T074 결과」).
- **대기는 UD-1 하나였고, 2026-11-16 「단계 통합 · T074 한정」으로 정해졌다**(아래 UD-1 절)〔CD-23〕.
  - 초안의 UD-2(GHCR 전환 시점)는 VD-T074-2 결과에 따른 조건부 기본값이 되었다(D10).
  - 초안의 UD-3(빌드 캐시)은 컨트롤러 결정(캐시 없음 — D5)이 되었다.
- 계약이 미리 정한 것(새 결정 아님): `collaborators_only`가 막히면 `all`로 바꾼다(gr:259 — 운영자).
- 컨트롤러 기본값(사용자가 뒤집을 수 있다): D9 seed 자리 값 · D13 결과 한 줄 위치 · D5 `APP_VERSION` · 캐시 없음(CD-22) · GHCR이 private로 생기면 세션 안 첫 실행 초록 직후 전환(CD-4 — 따로 여쭙지 않는다) · D19 App 설치 범위 축소(실행은 사용자 UI).
- **알림**: 공개 저장소의 attest는 첫 실행부터 이미지 이름 · digest · 워크플로 · 커밋을 공개 투명성 로그(public-good Sigstore)에 영구히 남긴다. 되돌릴 수 없지만, 저장소가 공개라 새로 드러나는 내용은 없다〔CD-4〕.
- **운영자 · 사용자 단계(차례대로)**〔CD-23〕: U0(App 범위 — 사용자) · U1a(required check — 운영자) · seed 머지(운영자) · U1b(통합 머지 — 사용자) · (필요할 때) U-a · U-b · U-c · U-d · U3(Public — 사용자) · VD-T074-6 push 확인(사용자).

### UD-1 머지 전 VD-5를 어떻게 재는가(결정 2026-11-16)

**사용자 결정(2026-11-16 · AskUserQuestion): 「단계 통합 · T074 한정」(아래 표의 A-T074 한정).** 이 예외는 T074 세션의 통합과 그 안의 고침 재통합에만 쓴다. T074 뒤에 main 발행이 다시 필요한 지점 — US5 Worker deploy(T092–T095)만이 아니라 T115 dev bump 실연(main에 새 변경이 들어가야 publish-pod가 돈다) · identity-admin 수정을 dev에 반영해야 하는 과제 — 마다 같은 결정을 다시 여쭌다. 질문할 때 보인 미리보기의 「T075 · T076 · US4 · T115는 문서대로 진행」은 이 점을 빠뜨린 문장이었다(사용자에게 정정해 알렸다 — bn 「T074」).

| 안 | 무엇 | VD-5 시점 | 규칙 · 문서 충돌 | 보안 | 대가 · 남은 과제 영향 |
|---|---|---|---|---|---|
| **A-기능 전체(권장)** | 이 기능의 main 전용 발행 지점 전부(T074 · US5 Worker deploy 등)에 같은 예외를 둔다: 통합은 매번 사용자가 직접 머지 · 과제 경계(과제 커밋 뒤)에서만 · CI 초록(gitleaks · identity-admin) · merge commit만 · 매번 bn · report 편차 기록 · T118에서 헌법 개정 제안 | 통합 직후 한 번 | CLAUDE.md:48 · 헌법 6→7→8(절차 편차 — 사용자 예외로 기록). FR-037 · ADR 0002 · Environment 정책은 그대로 | 설정을 넓히지 않는다 · 키는 main에서만 | ① events-compat 필수 집합 고정(bn:833-834 — main에 들어간 스키마는 필수 집합 추가 · 제거 금지 → US4 등에서 고칠 창이 닫힌다) ② 머지 방식 오클릭(squash · rebase도 허용 — U1b에서 방식 고정) ③ 미완성 기능이 main에 들어간다(Status Approved 그대로). T075–T076 · US4 · T115는 문서대로 진행된다 |
| A-T074 한정 | 같은 절차를 T074 세션(고침 재통합 포함)에만 쓴다 | 같다 | 같다 | 같다 | ①–③ + US5에서 같은 질문을 다시 여쭌다 |
| 부분 통합(기각) | PP · IA · django-common만 main에 넣는다 | 통합 직후 | 같은 파일이 두 경로로 main에 들어간다(이중화 → 기능 머지 때 충돌) | — | 기각: ci.yml의 required check gitleaks가 PR 쪽 워크플로를 요구해 ci.yml도 함께 넣어야 하고, IA의 트리 의존(django-common · templates · 하네스)이 넓어 실익이 없다 |
| 헌법 · CLAUDE.md 개정 | `/speckit-constitution`으로 Workflow에 단계 통합을 정식 절차로 넣는다(+ CLAUDE.md:48 · finish-gate) | 개정 뒤 | 정식 경로(헌법 Governance) | — | 무겁다(MINOR 개정 · Sync Impact Report · 훅 · 문서) — T074를 막는다. T118 후속으로 권한다(A의 기록이 근거가 된다) |
| B 기능 브랜치 발행 | PP 트리거 · job 조건에 기능 브랜치를 더하고, 운영자가 Environment 배포 브랜치에 그 브랜치를 임시로 더한다 | 바로 | FR-037 · ADR 0002 원칙 5 위반 → 새 ADR(docs.md) · 머지 뒤 원복 | 키 노출 범위가 넓어진다 · 머지되지 않은 코드의 이미지가 dev(→ T075 prod)로 간다 | 머지 뒤 main에서 다시 발행하면 digest가 바뀐다 · ①–⑤의 PP를 바꿔야 한다 |
| C 배포를 머지 뒤로 | T074는 구현만 하고 체크하지 않는다. T075 · T076 · US4 · US5 배포 · T115를 기능 머지 뒤로 미룬다 | 기능 머지 뒤 | 헌법 6(모든 스토리 E2E)이 7(Finish)보다 앞이라 **교착**이다(US6 AC6 · US5 AC1 · T095가 main 발행을 전제) | 영향 없음 | 남은 40과제 중 배포 사슬 전부가 막힌다 |
| D 기능 분할 | 003을 로컬 부분까지로 닫고 배포를 새 기능으로 옮긴다 | 새 기능에서 | 승인 tasks 불변 · 범위 변경 = 새 기능(specs.md:9) → spec · plan · approval을 다시 | 영향 없음 | 비용이 가장 크다 |
| E PR에서 이미지 push | PR 실행이 GHCR에 push · attest하고, bump만 머지 뒤 | 머지 뒤(VD-5 자체는 여전히 막힘) | ADR 0002 원칙 5 위반 | attestation의 source ref가 `refs/pull/1/merge`다. promote ③은 `--owner`만 보므로 그 이미지가 prod로 오를 수 있다(C13 — T115 전까지) | VD-5는 풀리지 않는다 |

**권장 = A-기능 전체.** 까닭은 넷이다.
- ① 이 기능의 Verify가 이미 main 발행을 전제한다(§2.1). 그래서 생명주기 충돌은 어느 안을 고르든 남는다. 숨기지 않고 사용자 예외 하나로 드러내는 편이 가장 작다.
- ② 보안 설정과 원칙 문서(FR-037 · ADR 0002 · Environment)를 하나도 넓히지 않는다.
- ③ VD-5를 문면 그대로 「이 워크플로가 연 첫 dev bump PR」로 잰다.
- ④ 같은 충돌이 US5에서 반복된다. 범위를 한 번 정해 두면 같은 질문을 되풀이하지 않는다. 대신 매번의 통합은 사용자가 직접 하고, 경계 · 초록 · 방식 · 기록 조건을 지킨다.

---

## 9. 위험 · 확인하지 못한 것

### 위험

- **생명주기 예외(UD-1 A)**: 남발하지 않도록 조건(과제 경계 · CI 초록 · merge commit · 기록)을 매번 지킨다. 통합은 사용자가 한다 — 에이전트는 머지하지 않는다(CLAUDE.md:48 · infra.md:39).
- **첫 main 실행 실패의 비용**: 고칠 때마다 재통합(새 PR)이 필요하다. 완화책은 PR build-check(VD-T074-1) · H 실행 계층 · 「Re-run failed jobs」다.
- **공개 이미지 노출**: 정상 경로는 push 전에 단언한다(D6). 남는 틈은 push 빌드가 적재 빌드와 다를 때다 — push 뒤 단언이 잡지만 이미 push됐고, Public 뒤에는 push가 곧 공개다. 노출 방어는 Dockerfile.dockerignore 허용 목록과 T072 gen-33이 맡는다(패키지 디렉터리 안에 비밀을 두지 않는다 — README:397).
- **받아들인 위험(옵션 A — CD-16)**: dev 배포 권한 = App 키 + 패키지 쓰기 주체 · 자동 머지 경로에 출처 검증 없음 · dev와 prod는 같은 클러스터 → T115 필수.
- **promote ③ `--owner`(CD-19)**: T115 전까지는 같은 워크플로 파일의 PR 실행이 만든 attestation도 통과한다(C13 · 편차 12).
- **패키지 쓰기 주체**: `packages: write`를 요청한 모노레포 워크플로 전부(같은 저장소 PR 실행 포함)가 쓴다. 모노레포 main과 기능 브랜치에는 PR 규칙 · 브랜치 보호가 없어, 운영자 계정(그리고 그 계정을 쓰는 에이전트)이 워크플로를 바꿀 수 있다 → T116. App 쪽 경로는 D19가 닫는다.
- **App 키**: Environment에 시크릿이 더해지면(T092) bump job이 이론상 그것도 참조할 수 있다 → T116(App 키 전용 Environment).
- **strict BEHIND**: 측정 세션 중 gitops 머지를 멈추는 것은 운영자 약속에 기댄다.
- **자리 값 seed**: T075가 순서를 어기면(Application이 먼저 생기면) ImagePullBackOff가 난다(§7).
- **BuildKit digest 핀**: 수동 갱신이라 오래되면 보안 수정이 늦는다(T116).
- **⑦의 느린 실패**: required check가 실패해도 auto-merge가 걸린 채 PR이 열려 있으므로, 시간 초과(15분)까지 기다린 뒤 정리한다. 판정에 check를 쓰지 않는 대가다(CD-1).
- **머지 결과 불일치**: 이미 머지된 뒤에 드러난다. 되돌리기는 운영자 revert PR이다(런북 · T098 알림).
- **gh 동작 차이**: `--auto`가 「바로 머지 가능」 상태에서 즉시 머지로 바뀌는 분기가 있다. 생성 직후라 일어나지 않을 것으로 본다(추론). 일어나도 사람 행동은 0이고 ⑦이 머지를 본다.
- **낡은 실행 가드의 대가(수정 라운드 1 · 재검토 B L4 — 받아들임)**: ① 발행 경로를 바꾼 더 새 main 커밋에 실행이 없으면(`[skip ci]` · 3,000파일 넘는 push · 워크플로 비활성) 낡은 실행은 건너뛰고 아무도 bump하지 않는다 — dev가 멈출 뿐 되돌리지 않는다(런북: `[stale]`인데 그 커밋에 실행이 없으면 U-d). ② 「변경 뒤 되돌림」 쌍(순 diff 0)은 낡음으로 세지 않는다 — 옛 실행이 같은 소스의 다른 빌드 digest를 올릴 수 있으나 Dockerfile digest 고정 · `uv sync --locked`라 사실상 등가다. ③ GitHub paths 필터가 rename의 옛 이름을 보는지 확인하지 못했다(가드는 `previous_filename`도 센다) — 틀려도 bump를 거를 뿐이다.
- **취소의 정리 창**: 러너는 첫 신호부터 10초 뒤 SIGKILL한다. gh · git 호출 하나가 그보다 오래 멈추면 정리 줄 없이 끝난다(bash는 전경 명령이 끝난 뒤 trap을 돌린다) — 런북의 운영자 GET이 받는다.

### 확인하지 못한 것

- App이 연 PR에 대한 넷(`collaborators_only` 아래 생성 · 실행 승인 없음 · ruleset만 있는 저장소의 auto-merge · unattributed 무관) → VD-5.
- `gh pr create` · `gh pr merge --auto` · `gh pr close`가 App 권한(contents · pull-requests)만으로 GraphQL 조회 · 변이를 마치는지. `pr merge`의 조회 필드에는 `statusCheckRollup`이 없지만(§2.5 확인) 라이브는 VD-5 b · d다.
- VD-T074-2로: GHCR 첫 가시성 · 자동 연결 · `--signer-workflow` 값 꼴과 `--source-ref`가 gh 2.103.3에서 받아들여지는지 · push 빌드가 적재 빌드와 같은 config를 내는지(관찰).
- `docker buildx imagetools inspect`의 기본 mediaType(OCI인지 Docker v2인지) — 단언은 둘 다 받는다. (수정 라운드 1 리뷰 A — 소스로 좁힘) BuildKit v0.34.1은 attestation 없이도 OCI 타입을 쓴다(compat 기본값 — `exporter/containerimage/export.go:576-581` · `solver/llbsolver/solver.go:261-264`)고 buildx는 compat 값을 넘기지 않으므로 OCI일 것이다 — 런북 O3의 HEAD는 두 타입을 다 Accept에 넣는다(GHCR은 digest 조회에도 Accept를 강제한다 — 공개 이미지 실측: OCI 매니페스트를 Docker v2 Accept로 HEAD하면 404). 「Re-run failed jobs」가 publish 출력을 재사용하는지(문서 · 추론) — 쓰게 되면 기록한다.
- 조각 ② · ③으로: BuildKit 판 · digest · `buildkitd-flags` 값 · login v4.8.0(발행 11일 — 14일 원칙) · actionlint 1.7.12가 새 입력(`client-id` · `create-storage-record`)을 거짓 오류로 보는지 · 이 PC에서 shellcheck와 zizmor를 돌릴 수 있는지(`uvx` 경로).
- O1 · U0 UI로: GHCR에 같은 이름의 연결 없는 옛 패키지가 있는지(토큰에 `read:packages` 없음) · App 설치 범위의 현재 값(App GET 404).
- 같은 줄을 바꾼 두 bump PR이 정말 충돌로 멈추는지(D16 추론).
- 캐시 없는 arm64 빌드의 실제 시간 → VD-T074-1.
- Environment 정책이 거부한 job이 배포 기록을 남기는지 → VD-T074-6.

---

## 10. 비판 처리

판정은 컨트롤러 결정(CD)을 따랐다. 「수용」은 지적과 고침을 받아들였다는 뜻이고, 「부분 수용」은 일부 수단을 쓰지 않았다는 뜻이다. 기각한 발견은 없다(기각된 하위 수단만 칸에 적는다).

| 비판 | 심각도 | 판정 | 반영 자리 · 까닭 |
|---|---|---|---|
| 74A-1 ⑦의 `statusCheckRollup`이 App 권한 밖 | high | 수용 | CD-1 — D8 ⑦ REST만 · pp-23 · px-15 · px-22 · §2.5. check 세부를 요약용으로 따로 읽는 안은 두지 않는다(운영자 · 컨트롤러 GET 몫) |
| 74A-2 재측정이 남은 브랜치에 막힘 | medium | 수용 | CD-2 — D8 정리 · D2 재시도(Re-run 기본 · dispatch 한정) · D5 태그 이동 기록 · D16 · px-16. 「태그가 있으면 push를 건너뛴다」 가드는 두지 않는다(배포는 digest 고정) |
| 74A-3 U-b 실행 불가 · B의 원인 | medium | 수용 | CD-3 — D12 B-merge · B-run · U-b · U-c · C2 · §7 T115 ⑥ |
| 74A-4 「첫 push는 private」 전제 | medium | 수용 | CD-4 — D10 · VD-T074-2 · D6(적재 → 단언 → push) · §8 · 편차 10. Dockerfile LABEL은 연결 대안으로만 적고 미리 적용하지 않는다 |
| 74A-5 동작 시험이 커밋되지 않음 | medium | 수용 | CD-5 — D1 · D14(두 계층) · AS · BS · run-all 1b6 · 조각 ① |
| 74A-6 UD-1 표의 대가 · 빠진 안 | medium | 수용 | CD-6 — §8 UD-1(대가 ① ② · 부분 통합(기각) · 헌법 개정 행 · A-기능 전체 권장 · A-T074 한정) · D17(방식 고정). 「squash · rebase 허용을 잠시 끈다」는 쓰지 않는다(UI 버튼 또는 `gh pr merge 1 --merge`로 충분) |
| 74A-7 보호 규칙 거부 쪽 미측정 | medium | 수용 | CD-7 — VD-T074-6 · C2 · 편차 13 |
| 74A-8 C8이 템플릿 소유 절을 고침 | low | 수용(다른 수단) | CD-8 — C8을 뺐다(빈 번호). 정본은 pt C5 · PP 머리 주석 · 런북 |
| 74A-9 paths 한도 300 → 3,000 | low | 부분 수용 | CD-9 — 바이트 순 분석 삭제 · VD-T074-3 관찰로 축소 · §2.5(현행 문서 3,000 확인). 「컨트롤러 확인 필요」 ② |
| 74A-10 auto-merge 증거의 이벤트 · API | low | 수용 | CD-10 — D11 d · D8 ⑦ 첫 조회 스냅숏 |
| 74A-11 gitops 문서 보정 누락 | low | 수용 | CD-11 — §7 T075 · D12 목록(줄 확인) |
| 74A-12 C6 · C7의 자리 | low | 부분 수용 | CD-12 — C6을 Dockerfile 쪽으로 좁히고 PP 불변식은 머리 주석 · H · pt에 둔다 · C7은 specs.md(+미러)만. 쓰지 않은 수단: AGENTS.md · AGENTS_kr 예외 추가(그 문장은 체크박스 편집과 이미 공존하고 열거는 specs.md에 있다) · CI 워크플로용 규칙 경로 신설(불변식은 H가 지킨다) |
| 74A-13 D13 · U1 · 재통합 정합 | low | 수용 | CD-13 — D13(체크 조건 · 보류) · U1a · U1b · D17(재통합 = 새 PR) |
| 74A-14 관찰 · 인계 누락 | low | 수용 | CD-14 — D11 g · C11 · D15 ③ · §7 T115 ③ |
| 74B-1 App이 모노레포에도 설치됨 | high | 수용 | CD-15 — D19 · U0 · O1 · C14 · C4(설치 범위 문장 — 「컨트롤러 확인 필요」 ③) |
| 74B-2 자동 머지 경로에 출처 검증 없음 | medium | 수용 | CD-16 — D11 받아들인 위험 · C2 · §9 · 편차 11 · §7 T115 ①(필수) |
| 74B-3 bump의 자기 PR 무결성 | medium | 수용 | CD-17(+CD-2) — D8 ③ ⑤ ⑥ ⑦ · 정리 · pp-21 · pp-23 · px-17–px-19 · px-23. 실패 갈래의 auto-merge 해제는 닫기가 실패할 때의 대안으로 둔다(CD-2) |
| 74B-4 빌드 입력이 거부 목록 | medium | 수용 | CD-18 — D5 허용 목록 · `buildkitd-flags` 명시 · pp-12 · pp-14 · 변이 넷(D14) |
| 74B-5 promote ③ `--owner` | medium | 수용 | CD-19 — C13 · 편차 12 · §7 T115 ②(필수) |
| 74B-6 단언이 push 뒤 | low | 수용((가)안) | CD-4 — D6 발행 순서. 「D6 실패 판의 삭제 가능 여부」 VD는 두지 않는다(정상 경로는 push 전에 막는다) |
| 74B-7 쓰기 주체 · 공개 시점 사실 | low | 수용 | CD-4 · CD-22 — D10(쓰기 주체 · 투명성 로그) · §8 알림 · §7 T116. UD-3 registry 행은 UD-3과 함께 빠졌다 |
| 74B-8 SHA 핀 강제 · 14일 규칙 | low | 부분 수용 | CD-20 — §7 T116 인계만. 통합 전 운영자 단계로 당기지 않는다 |
| 74B-9 workflow command 차단 | low | 수용 | CD-21 — D6 · D8 출력 위생 · pp-22 · pp-23 · px-7 · px-21 |

### 컨트롤러 확인 필요

- ① **CD-5 · run-all 1b6의 「1b5 규율」**: 1b5(events-compat)는 도구가 없을 때 파일 전체를 SKIP하고 정적 단언도 돌리지 않는다(「정적 단언만의 PASS가 실행 단언의 부재를 가리지 않게」 — 하네스 머리 주석 확인). CD-5가 선례로 든 ec-26b는 단언 하나의 능력 부족(심볼릭 링크)에 쓰는 꼴이다. 이 설계는 CD-5대로 정적 계층은 늘 판정하고 실행 계층만 SKIP 줄로 드러내며, 1b6는 파일 전체 SKIP을 받지 않는다. 이 차이가 의도인지 확인이 필요하다.
- ② **CD-9의 「300 vs 3,000」**: 조사 네 보고(R1–R4)에는 300도 3,000도 없다(grep 0). 300은 초안 §2.2가 〔R4〕를 근거로 적은 진술인데 R4에 그 문장이 없다. 현행 workflow-syntax 문서는 3,000이다(WebFetch 2026-11-16). CD-9의 처리(분석 삭제 · 관찰로 축소)는 그대로 따랐지만, 「문서끼리 어긋난다」는 전제는 원문으로 뒷받침되지 않는다.
- ③ **CD-15 · gr의 설치 범위 문장**: gr에는 App 설치 범위 문장이 없다(gr:101은 설치된 App의 이름만 적는다). 그래서 CD-15의 조건부 보정은 해당이 없다. 다만 런북 표식(C14)이 「모노레포 설치가 필요해지면 계약 변경으로 시작」을 말하므로, 이 설계는 gr §변경 권한(C4)에 설치 범위 문장을 하나 더했다. 원치 않으면 그 문장만 뺀다.
- ④ **CD-1의 「GraphQL … (App 권한 밖)」**: 권한 밖인 것은 필드(`statusCheckRollup` 등)이지 GraphQL 전체가 아니다. ⑤ `gh pr create`와 ⑥ `gh pr merge`(CD-17이 정한 명령)도 GraphQL로 돈다. 이 설계는 ⑦만 REST로 두고 ⑤ · ⑥은 gh 명령 그대로 둔다. `pr merge`의 조회 필드에는 `statusCheckRollup`이 없음을 소스로 확인했다(§2.5).

**컨트롤러 답(2026-11-16)**
- ① 의도한 차이다. 정적 계층은 도구와 무관하게 늘 판정하고, 실행 계층의 부재는 run-all 1b6의 `NOTE … skipped` 줄로 드러낸다(D14). 이 PC와 빌드 조각에서는 SKIP 0이 끝 조건이다(§5 조각 ②).
- ② 받아들인다. 현행 문서의 3,000이 기준이다. 300은 초안의 근거 없는 진술이었다 — VD-T074-3은 관찰만이다.
- ③ 유지한다. 계약이 설치 범위를 말해야 런북 표식의 「계약 변경으로 시작」이 가리킬 문장이 생긴다.
- ④ 맞다. ⑦만 REST이고 ⑤ · ⑥은 gh 명령이다. 그 둘의 App 권한 동작은 VD-5 b · d가 라이브로 본다(§9).
