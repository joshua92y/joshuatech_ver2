# T075 설계: platform-gitops apps/identity-admin(base · overlays · Argo Application) + dev · prod 배포

2026-11-17 확정본(검증 반영)이다. 조사 다섯 · 초안 · 비판 두 렌즈(75A 15건 · 75B 14건) 뒤에 사용자 결정 넷(B1 — UD-9 · UD-12 · UD-13 · UD-14)과 컨트롤러 결정 CD-1–CD-30(B2)을 반영했다. 그 뒤 최종 설계 검증 두 렌즈(K1 10건 · K2 13건)를 컨트롤러 처리 VR-1–VR-16 · UD-14 보완(사용자 결정) · 작성자 확인 답(B4)대로 반영했다. 이어 UD-12 로컬 실 브로커 측정 결과(B5 — M1 성립)와 수정 라운드 1 집중 확인 여섯 건의 컨트롤러 처리 R-1–R-6(B6)을 반영했다. 결정과 초안 · 발견의 고침이 다른 곳은 결정을 따랐다.

| 항목 | 수 |
|---|---|
| 결정 | D1–D24(새로 D23 관문 넓힘 · D24 prod 노출 축소) |
| 보정 | C1–C31 — 〈설계 커밋〉 18(C1–C10 · C17–C23 · C31) · 〈조각 커밋〉 7(C24–C30) · 〈실측 뒤〉 6(C11–C16). C10은 UD-12 결과로 〈실측 뒤〉에서 당겼고, C31은 R-2로 더했다 |
| 새 gitops 검사 | validate.sh 12(3.9 · 7.5 · 13.7 · 14.0–14.8) · 고침 1(7.1 argocd 갈래 — R-2) · validate.yml classify 넓힘 1 |
| 모노레포 하네스 | 새 1(base 동기화) · 고침 3(cluster argo-3 · kafka job-d-2 · kafka-tests 픽스처) |
| VD | T075 안 17(VD-T075-1–17 — 14는 조각 ③′에서 끝남 · PASS) · 라이브로 넘김 12 |
| report 편차 후보 | 18 |
| 사용자 결정 | 4(UD-9 · UD-12 · UD-13 · UD-14 — 모두 2026-11-17 · UD-14는 보완 포함) · 다시 여쭐 조건 1(UD-1 — UD-12 결과로는 생기지 않았다) |
| 비판 처리 | 29(수용 26 · 부분 수용 2 · 소멸 1 · 기각 0) |
| 검증 처리 | 29(K1 10 · K2 13 — VR-1–VR-16 · 집중 확인 6 — R-1–R-6 · 반영 29 · 기각 0) |
| 컨트롤러 확인 필요 | 6(답 2026-11-17 — 받아들임 5 · UD-14 보완으로 해결 1) |

경과는 다음과 같다.
- 조사 R1 명세 · 계약 · 순서 / R2 deploy/base · env / R3 gitops 실물 / R4 외부 사실 / R5 UD-9 로컬 실측 — `.superpowers/t075/research/{spec,deploy,gitops,external,ud9}.md`
- 초안 `.superpowers/t075/design-draft.md`(D1–D22 · 835줄)
- 비판 A 계약 · 실행 가능성(approve_with_fixes · high 0 · medium 6 · low 9) / B k8s 보안(approve_with_fixes · high 3 · medium 7 · low 4) — `.superpowers/t075/reviews/critique-{A,B}.json`
- 결정 기록 `.superpowers/t075/decisions-controller.md`(B1 사용자 결정 · B2 CD-1–CD-30 · B4 VR · B5 UD-12 결과 · B6 R — 처리는 §10)
- 최종 설계 워크플로(작성자 · 보정자 · 검증 K1 결정 · 일관성 approve_with_fixes high 1 · medium 4 · low 5 / K2 사실 정확성 · 저장소 규칙 approve_with_fixes high 1 · medium 8 · low 4) — `.superpowers/t075/final/` · 처리 = 결정 기록 B4(§10 「검증 처리」 · 「컨트롤러 답」)
- UD-12 로컬 실 브로커 측정 · 독립 반증(`wf_32816872-6d6`) — `.superpowers/t075/ud12/{measure,refute}.md` · 처리 = 결정 기록 B5(D21)
- 수정 라운드 1(`wf_46ca062d-a40` — 수정자 · 집중 확인 approve_with_fixes high 0 · medium 3 · low 3) — `.superpowers/t075/final/{fixer-r1.md,recheck-r1.json}` · 처리 = 결정 기록 B6(§10 「검증 처리」 R-1–R-6)

본문은 반영 뒤 모양이다. 반영으로 바뀌거나 더해진 곳에 〔CD-n〕 · 〔UD-n〕 · 〔VR-n〕 · 〔R-n〕을 단다. 설계 작업은 읽기 전용이었다(저장소 두 곳 쓰기 0 · git 상태 변경 0 · 라이브 접근 0). 빌드 라운드의 결과와 정정은 bn 「## T075」 절에 적는다. 이 문서는 과제가 닫히면 고치지 않는다(specs.md).

표기는 다음과 같다.
- 「확인」: 이 문서가 파일을 직접 다시 읽은 것이다(2026-11-17).
- 〔Rn §x〕 조사 보고의 절 · 〔75A-n〕 · 〔75B-n〕 비판 발견 · 〔CD-n〕 컨트롤러 결정 · 〔UD-n〕 사용자 결정(§8) · 〔VR-n〕 검증 발견(K1-n · K2-n)의 컨트롤러 처리(§10 「검증 처리」) · 〔R-n〕 수정 라운드 1 집중 확인 발견의 컨트롤러 처리(결정 기록 B6 · §10 「검증 처리」 — 하이픈이 있다. 조사 보고 〔Rn §x〕와 다르다).
- 「추론」: 실측 전 판단이다(VD로 넘긴다) · 〔편차 n〕: report.md 편차 후보(§1 끝).
- 「컨트롤러 확인 필요」: 결정이 전제한 사실이 원문과 다르거나 결정이 비워 둔 자리를 이 문서가 채운 곳이다(§10 — 「컨트롤러 답(2026-11-17)」이 뒤따른다).
- 줄 번호는 모노레포 작업 트리(HEAD `4a40835`)와 gitops `origin/main`(`f920df6`) 기준이고, §4 보정 전 번호다.

## 약어

- **tasks · spec · plan**: `specs/003-platform-foundation/`의 승인 고정 문서
- **gr · ia · ha · pt · dl · np · ev**: contracts/{gitops-repo, identity-admin-api, hostnames-and-access, pod-template, denylist, network-policy, events}.md
- **dm** data-model.md · **qs** quickstart.md · **bn** design/build-notes.md · **t057 · t072 · t073 · t074** design/tNNN-design.md · **t057-blocks** design/t057-blocks/
- **vu · bs**: docs/runbooks/{vault-unseal, bootstrap}.md · **IR** apps/identity-admin/README.md · **B/** apps/identity-admin/deploy/base/
- **dp**: `.claude/rules/django-pod.md`(+ 미러 `docs/kr/rules/django-pod_kr.md`)
- **G/**: gitops `origin/main`(f920df6) · **공유 클론**: `D:\code\platform-gitops`(작업 트리 87d223d — 브랜치를 바꾸지 않는다 · 설계 단계에서는 fetch하지 않았다)
- **vsh · vts · vyml**: G/tests/validate.sh · G/tests/validate.tests.sh · G/.github/workflows/validate.yml
- **GP-1 · GP-A · GP-2 · GP-3**: 이 과제의 gitops PR(D1)
- **O-n / W-n**: 블록(O = 관찰 · 쓰기 0 / W = 변경 — D10 · D20) · **L-n**: 라이브 단계(§5)
- **CF 값**: Access AUD 셋(`identity-m2m-dev` · `identity-m2m-prod` · `admin`)과 서비스 토큰 Client ID 둘(`web-bff-dev` · `web-bff-prod`). 비밀이 아니다(ia:16 · ha:41).
- **pod 표**: 3.9 · 14.1–14.4가 읽는 pod별 표 — 이름 · 경로 · ConfigMap 키 · 값 · ES · `envFrom` · `env[]`(정본 = gr §validate.yml 3 「(T075 보정 2026-11-17)」 줄 · vsh는 사본 — D9)
- **B2 꼬리**: pod 사용자 ACL 규칙 끝의 `-@admin -@dangerous -client`(UD-9)

---

## 1. 과제 문면과 계약 우선 원칙

### 문면 요약(tasks:192 — 확인)

- **gitops 경로**: `apps/identity-admin/{base,overlays/dev,overlays/prod}`.
- **base**: 템플릿 deploy/base를 복사한다. probe 3종 · RollingUpdate · 노드 A 선호 · CPU limit 없음 · requests · securityContext · automount false · `pg-main-ca` · Reloader를 그대로 둔다.
- **overlays**
  - namespace jt-dev/jt-prod · images digest
  - m2m Ingress host JSON6902(경로 5개만)
  - admin Ingress는 prod만(`admin.joshuatech.dev` `PathPrefix(/identity-admin)` · `FORCE_SCRIPT_NAME` · `ADMIN_HOST`)
  - replicas 1
  - ES 2개: `-env` ← db app · kafka · dragonfly · authentik · webhooks · openfga · sentry / `-migrate` ← db owner(migrate Job만)
  - 「US4 이후 키 플레이스홀더 절차」
  - ConfigMap: ACCESS_* · ADMIN_HOST · ALLOWED_HOSTS · `AUTH_ACTOR_SUB`(VD-1이 A일 때만)
- **Argo Application**: `identity-admin-dev`(auto-sync + selfHeal) · `identity-admin-prod` → dev 배포 → `/health` 200 via Access 서비스 토큰(Authentik 값 전까지 JWT 경로 미사용).
- **뒤 과제 T076**(tasks:196 — 확인): dev · prod `/health` 200(tester-m2m) · 헤더 없이 403 · `/admin/` 404 · m2m 호스트의 `/webhooks/authentik` · `/healthz` · `/ready` 404 · ES 2개 주입. spec AC6(spec:146)도 `overlays/{dev,prod}` sync를 요구한다.

### 계약 우선 원칙

T073 · T074와 같다.
- 문면과 계약이 다르면 계약이 이긴다(infra.md:10).
- 계약이 실측과 다르면 실측을 따르고 계약을 고친다.
- tasks · spec · plan은 고정이므로, 낡은 문장은 계약 · 규칙 · 런북 · bn · report에서 바로잡는다.

### 문면 · 계약 · 실물의 어긋남(따를 쪽)

| # | 문면 | 정본 · 실물 | 따를 것 |
|---|---|---|---|
| 1 | `ACCESS_EXPECTED_CN` = `web-bff-dev` / `web-bff-prod` | 서비스 토큰의 **Client ID** `<32 hex>.access`(ia:35 · ha:106). Cloudflare가 JWT `common_name`에 넣는 값이다 〔R4 §5.5〕 | 계약 〔편차 1〕 |
| 2 | 「US6에 운영자가 플레이스홀더를 `vault kv put`으로 투입 → US4에서 교체」 | T044가 8경로에 sentinel을 이미 넣었다(vu:294-308). `jwks_url` · `issuer`는 계약 값으로, 웹훅 비밀은 실값으로 덮어쓴다(dm:168-169). 나가는 쪽 셋은 sentinel + `JT_PLACEHOLDER_EXEMPT`(t073:2330) | 계약 · 실물(D10) 〔편차 2〕 |
| 3 | `-env` 출처 목록 | `kv/{env}/django/identity-admin`(B/externalsecret-env.yaml data[7] · gr:177 · dm:176)이 빠졌다. `sentry`는 목록에 있지만 시드 과제가 없다(t072:1229) | 실물 — 두 경로를 새로 시드한다(D10) 〔편차 3〕 |
| 4 | admin `PathPrefix(/identity-admin)` + 「`FORCE_SCRIPT_NAME`」 | pod에 `/admin/…`이 닿으려면 Traefik `stripPrefix` Middleware가 있어야 한다. `FORCE_SCRIPT_NAME`은 env 이름이고 Django 전역 설정이 아니다(pt:19 · ha:8 · ia:10 · ia:14) | 계약 + D6(경로 둘 — CD-29 확정) 〔편차 4〕 |
| 5 | 「`AUTH_ACTOR_SUB`는 VD-1이 A일 때만 넣는다」 | base ConfigMap에 키가 빈 값으로 있다(B/configmap.yaml:18 — 빈 값 = 검사 안 함) | 실물(뜻이 같다 · 값은 T081) 〔편차 5〕 |
| 6 | overlay에 replicas 1 | base Deployment 둘이 이미 `replicas: 1`이다 | 실물 — overlay에 다시 적지 않는다(편차 아님) |
| 7 | ConfigMap 키 다섯 | base 키 16 + overlay `JT_PLACEHOLDER_EXEMPT`(pt:84 · IR:416-421) | 계약 |
| 8 | 확인 = 「dev 배포 → `/health` 200」 | AC6 · T076은 dev · prod 둘 다 200을 요구한다 | T075가 prod도 배포한다(D1 — CD-29 확정) |
| 9 | T076 · spec:109 「헤더 없이 403」 | m2m Access 앱이 `service_auth_401_redirect = true`다(infra/cloudflare/access.tf:173 — 확인). 문서상 401이다 〔R4 §5.3〕. bn:35 ③은 「/finish 때 계약 문구 401로」라고 적었다 | T075가 실측(L4)해 ha:26을 고친다(C11) 〔편차 6 — 실측이 401일 때〕 |

### report.md 편차 후보

| # | 내용 |
|---|---|
| 1–6 | 위 표 1–5 · 9행 |
| 7 | UD-9 = B2: 운영 ACL이 승인 문서(spec:257 · tasks:146 · :155 · plan:208)의 `+@all` 문자열과 달라진다 — 계약 보정(C9 · C20)으로 기록하고 고정 문서는 고치지 않는다 〔UD-9〕 |
| 8 | UD-12: relay ACL VD(T069 M6)를 클러스터가 아니라 운영 판의 로컬 실 브로커에서 쟀다(bn:1984 r5 인계 · ev:127 옛 문장과 다르다) — 결과 M1 성립 · relay 수정 없음(D21) 〔UD-12〕 |
| 9 | T068 라이브 잔여 셋을 이연한다 — pgvector 제외 양성 · 멤버십 양성 · BYPASSRLS 무소유 role 판별(D19) |
| 10 | celery 생존 프로브를 두지 않는다. 그래서 T098 전에는 beat 사망을 탐지하지 못한다(알려진 한계 · D13) |
| 11 | VD-L8 · L10 · L17 · L19 등을 뒤 과제로 옮긴다(§6) |
| 12 | 받아들인 위험: Argo CD v3.5.2는 v3.5.4가 고친 critical 넷(GHSA-fmxq · -m3vr · -fw5c · -9v9p)과 high 둘(GHSA-j6cw · -4439)의 영향 범위다. T075는 14.5(hook 허용 목록) · 14.0(앱 렌더 cluster 객체 0) · 14.8(원격 ref 금지 · 경로 가둠) + 기존 11.3(jsonnet 금지) · 12.3(helmGlobals 금지)으로 좁히고, 판 올림(v3.5.7)은 T075 뒤 · US4 전 정비 단계(tasks.md 밖 운영 단계)에서 한다. 남는 길 = `manifestsWithFiles` API(Application get 권한 — 운영자뿐) 〔CD-17 · CD-24 · UD-13〕 |
| 13 | 받아들인 위험: owner Secret(`<pod>-migrate`)이 sync 사이에도 상주한다 — Reloader SA 토큰 탈취 = 두 env의 owner 자격(BYPASSRLS + DDL)(D14) 〔CD-20〕 |
| 14 | 받아들인 위험(UD-14 · 보완 뒤 — T047 D7 문장을 대신한다): 남는 관문 밖: `platform/**` · `platform-*` Application · `tests/` · `.github/` · 문서 · dev overlay · dev Application 변경 PR(받아들인 위험). `platform/**` · `platform-*` Application은 admin 등가다(argocd ns · AppProject · ClusterRoleBinding · jt-prod) — D7로 관문 밖이다. 이 길을 좁히는 검사(7.1 · 7.5 · 13.7 · 14.0 파일 결합)는 PR 코드라, 같은 PR에서 검사 코드를 고치면 지나간다(`tests/` · `.github/` 관문 밖). 이 PR들은 봇 토큰으로 머지될 수 있다 — 예: 14.0 파일 결합을 끄고 prod Application을 `-prod`가 아닌 파일에 두는 PR. 관문 밖 dev overlay는 dev 자격 범위의 임의 실행이다(command · args · 볼륨) — 14.x가 지키는 것은 env 경계 · 호스트 · Vault 경로 · ES template · kind · 이미지 저장소다 〔UD-14 · VR-4 · VR-7 · R-2 · R-6〕 |
| 15 | 받아들인 위험: `eso-dev` · `eso-prod` 정책이 `kv/data/{env}/*` 전체라 Workers 전용 경로(`access/*` · `web/*`)와 운영자 전용 `dragonfly/admin`도 읽는다 — 막는 것은 vsh 3.7(apps/**) · 3.9 ES 표(pod 표 — 경로 정확 일치)다 → T116 deny 후보 〔CD-27 · VR-11〕 |
| 16 | 받아들인 위험: data ns `allow-egress-external-443`이 `podSelector: {}`라 Dragonfly pod도 외부 443으로 나간다 — B2가 pod 자격의 `REPLICAOF`를 막는다 · 좁힘은 T097/T116 후보 〔CD-22〕 |
| 17 | 받아들인 위험: B2가 남기는 것(모든 pod의 키 이름 열람 `SCAN` · `DBSIZE` · Lua · `SCRIPT FLUSH` · `FUNCTION FLUSH` · 자기 패턴 안의 쓰기 · 삭제 — 30 s 재적용이 복구하는 것은 identity-admin의 `revoked:*` · 세션 하한 키뿐 · 자기 접두 메모리 고갈 — dl §ACL ②) · Traefik ≤ 3.7.17 권고(GHSA-cp28 등 — 3.7.18은 다음 K3s 패치 · T084 전제) 〔UD-9 · UD-13 · VR-9〕 |
| 18 | 범위: 문면 밖에 더한 것 — AppProject 허용 목록 · 관문 넓힘 · validate 검사 12 · 고침 1(7.1 argocd 갈래 — R-2) · UD-9 적용(새 렌더 블록 포함) · prod 배포(문면의 확인 기준은 dev뿐 — AC6 · T076 근거) |

---

## 2. 소스로 확인한 사실

### 2.1 gitops(G/ — 확인)

**지금 파일 모양**
- base `kustomization.yaml`은 `resources: []` 뼈대다(:1-6 — 머리 주석 「T003 · T031+」 · deployment-celery 없음).
- dev overlay는 `resources: []` + images 1항목이다(:10-13).
  - name = newName = `ghcr.io/joshua92y/identity-admin` · digest `sha256:faf55a57…57dd`(T074 봇 bump #60).
  - 주석 :4 「resources · namespace · Ingress · replicas는 T075에서 작성한다」 · :8-9 「자리 값 — 어떤 이미지도 가리키지 않는다 … name · newName · digest 줄을 지우거나 옮기지 않는다」(자리 값 문장은 낡았다 — 이제 실제 digest다).
- prod overlay도 `resources: []`이고 images가 없다(:1-7).
- `clusters/oci-k3s/apps/`에는 `platform-*` 22개와 README뿐이다(앱 행은 README:58 「후속 PR」).
- 긍정 픽스처 `tests/fixtures/positive/clusters/oci-k3s/apps/identity-admin.yaml`(:1-28): 한 파일 두 문서 · dev `automated {prune: true, selfHeal: true}` · prod `prune: false` · `syncOptions: [ServerSideApply=true]` · wave "100" · **finalizer 없음**(14.0을 넣으면 고친다). 14.0 파일 결합(파일마다 문서 하나 · 이름 = 파일 이름)에 따라 `identity-admin-dev.yaml` · `identity-admin-prod.yaml`로 나눈다(D9 〔VR-4〕). 실트리의 `platform-*.yaml` 22개는 모두 문서 하나 · kind Application · 이름 = 파일 이름이다(확인).
  - 긍정 픽스처의 `platform-apps.yaml`은 한 파일에 Application 22문서(`platform-argocd` … `platform-reloader`)다(확인) — 같은 커밋에서 `platform-<c>.yaml` 22파일로 나눈다 〔R-3〕.
  - 긍정 픽스처 `apps/identity-admin/base`는 4파일이다(deployment · externalsecrets · kustomization · migrate-job — 확인). `externalsecrets.yaml`이 `-env` 3 · `-migrate` 1 항목이고 `target.template` · `refreshPolicy`가 없어 3.9 · 14.1 ④ · 14.2 · 14.4의 pod 표 정확 일치에 걸린다 → B/ 9파일 사본으로 바꾼다 〔R-3〕.

**AppProject와 그 반영 경로**
- dev/prod(projects/dev.yaml:21-41 · prod.yaml:18-38): destination은 자기 ns 하나 · `clusterResourceWhitelist: []` · `namespaceResourceBlacklist` 6종(NP · RQ · LR · SA · Role · RoleBinding)뿐이다. 그래서 traefik.io TLSOption · TLSStore · IngressRoute · Secret · PVC · LoadBalancer Service가 허용된다 〔75B-1〕.
- `platform`(projects/platform.yaml)의 destination에 `jt-dev` · `jt-prod`가, `tests`의 destination에 `jt-dev`가 있다. 그래서 Application의 `project` 한 줄로 dev/prod 경계(금지 목록 · cluster 리소스 금지)가 풀린다 〔75A-2 · 75B-3〕.
- AppProject 5개는 `bootstrap/argocd/kustomization.yaml`이 `../../clusters/oci-k3s/projects`를 base로 포함해 **`platform-argocd`가 소유**한다(:29-35 · :59 — 확인). `projects/kustomization.yaml`이 다섯 파일을 나열하고, 파일마다 `Delete=false,Prune=false`다. 잘못된 AppProject 커밋은 root · platform-argocd를 잠글 수 있다(같은 주석 :34-35 — 비파괴 복구는 G/bootstrap/README.md ⑧(:173 · 복구 명령 :207) 〔VR-13〕).
- `platform-argocd`의 경로 검사(확인): 7.1은 컴포넌트 `argocd`에 한해 `source.path`로 `platform/argocd`와 `bootstrap/argocd`를 둘 다 받는다(vsh:2091-2092 · 같은 내용의 주석 G/clusters/oci-k3s/apps/platform-argocd.yaml:16-17 · G/platform/argocd/kustomization.yaml:9-11). `platform/argocd/kustomization.yaml`은 `resources: []` 자리표시(:17)인데 내용을 막는 검사가 없고, vsh에는 AppProject 내용 검사가 없다(grep — 주석 :474뿐). 두 파일 모두 관문 밖이라(D23) 검사 코드를 고치지 않고도 AppProject · Argo CD 본체를 바꾸는 길이었다 — GP-1이 7.1 고침 · 7.5 · 13.7로 닫는다(D9) 〔R-2〕.
- 모노레포 하네스 `tests/platform/cluster.tests.ps1` argo-3이 dev/prod 금지 목록 ⊇ 6종을 group까지 본다(:534-552 · 상수 :165-167 — 확인).

**검사가 거는 것과 안 거는 것** — vsh는 3,427줄이고 검사 그룹은 0–13이다(3.8 = CNPG-retain).
- apps에 거는 것: 1 KUST(CRD 파생 스키마) · 2 SSA · 3.0–3.7(3.2는 overlay 렌더만 — base 원본은 대상 밖) · 4a images · 5.0 · 6 봇 경로 · 7.1(`<pod>-<env>` ↔ path · wave) · 7.4(source 키) · 8 gitleaks · 11.x · 12.3(helmGlobals 금지) · 13 RBAC.
- 안 거는 것(grep 0 〔R2 §4.3 · R3 §7.2〕): env 위생 · ConfigMap 값 · Ingress 모양 · ES refresh/creation 값 · hook 종류 · project · destination · syncPolicy(SSA 밖) · finalizer · 렌더 이미지 · 렌더 kind · 원격 ref(vsh는 원격 base를 건너뛴다 — :932 · :2162 확인).
- `platform/policies/tests/**`(project `tests`)에는 hook 어노테이션이 0개다(확인 — 검사 Job 셋은 일반 리소스다).

**운영 규칙**
- 승인 관문 classify는 `apps/*/overlays/prod/**`만 본다(vyml :1366-1370 `is_prod` — 확인). `clusters/oci-k3s/apps/<pod>-prod.yaml` · `apps/<pod>/base/**` 변경은 관문 밖이다(tests/README.md:66). classify의 자기 시험은 vts에 없다(grep 0).
- 검사를 더하면 부정 픽스처 + vts 단언 + positive 통과를 함께 고친다(:120). 부분 실행은 `VALIDATE_TESTS_ONLY`다(:103). CI 자기검사는 `tests/` · `.github/` 변경 PR에서만 돈다(gr:256 — job 전체 3분 48초(2026-09-29 실측) · 지금 사례 수로는 더 길다 — 추론 〔VR-6〕).
- wave · destination 값을 README · 주석 · PR 본문에 옮겨 적지 않는다(clusters/oci-k3s/apps/README.md:154).
- `platform-tests` 머리 주석(clusters/oci-k3s/apps/platform-tests.yaml:13-27): root 콜드 재구축에서 앱 행은 그 health를 기다린 뒤 온다. Job 스펙을 바꾸는 PR은 완료된 Job이 남아 있으면 sync가 실패한다(운영자가 Job을 지운다).

**data-assert와 하네스**
- data-assert ② `acl-list`는 **identity-admin 자격**으로 `ACL LIST`를 보내고 sample-pod 행의 `%R~`를 찾는다(platform/policies/tests/job-data-assert.yaml:131-141). FAIL이 하나라도 있으면 Job이 exit 1이다(:378-379).
- 모노레포 하네스 kafka job-d-2가 그 근거를 VD-4로 읽는다(tests/platform/kafka.tests.ps1:82-85 · :845-849). 픽스처 하네스가 같은 EVIDENCE 행을 만든다(tests/scripts/kafka-tests.tests.ps1:378-380).

### 2.2 모노레포 deploy/base와 기동 규칙(확인)

**파일과 리소스**
- 9파일(리소스 8): configmap · ES `-env` · ES `-migrate` · migrate Job · deployment(web + relay + init) · deployment-celery · service · ingress(B/kustomization.yaml:5-13).
- 모노레포 `origin/main` = `9fd9f2c`(T074 통합 머지 커밋)이고, 작업 트리의 B/와 바이트가 같다(`git diff --stat origin/main HEAD -- apps/identity-admin/deploy/base` 0). blob(앞 12자): configmap `66feebf5eeac` · deployment-celery `2264619ba8fd` · deployment `5338f01a49b0` · externalsecret-env `7bb6223263c1` · externalsecret-migrate `0454011e860c` · ingress `af8748305de5` · kustomization `a7c40064a196` · migrate-job `1383a6c95157` · service `41f729f78437`.
- ConfigMap 16키(B/configmap.yaml:11-30): `ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN` = `PLACEHOLDER-SET-IN-OVERLAY`(기동 게이트 2) · `ALLOWED_HOSTS: identity-admin.jt-dev.svc` · `ENV: dev` · `KAFKA_USERNAME: dev-identity-admin` · `AUTHENTIK_WRITES_ENABLED: "false"`. `JT_PLACEHOLDER_EXEMPT`는 없다.
- ES `-env`(B/externalsecret-env.yaml:16-39): vault-dev · 5m · Periodic · Owner · v2 Replace · template 키 11개(`DATABASE_URL`은 `trimSuffix "_app"`로 조립) · data 0–11의 순번이 overlay 인덱스 패치의 인터페이스다(IR:429-445).
- ES `-migrate`(B/externalsecret-migrate.yaml:14-31): PreSync hook · wave -1 · BeforeHookCreation · `DATABASE_OWNER_URL` 한 키.
- 단계 · wave(IR:446-453): `-migrate` ES(PreSync -1) → Job(PreSync 0) → ConfigMap · `-env` ES(Sync -1) → Deployment 둘 · Service · Ingress(Sync 0). hook 운영 성질 넷은 IR:455-461에 있다.
- Ingress(B/ingress.yaml): traefik · websecure · `router.tls: "true"` · `spec.tls` 없음 · host `PLACEHOLDER.joshuatech.dev` · `/health`만 Exact이고 `/api` · `/session` · `/sessions` · `/tenants`는 Prefix다.
- 모든 컨테이너 image는 태그 · digest 없는 `ghcr.io/joshua92y/identity-admin`이다 — overlay images 변환이 없으면 암묵 `latest`다 〔75B-9〕.

**기동 규칙**(IR:25-54 · :261-299 · dp §Settings)
- 게이트 2: 값에 `PLACEHOLDER-`가 있으면 실패한다. 면제 = env `JT_PLACEHOLDER_EXEMPT` ∩ 코드 상수 셋. `jwks_url` · `issuer` · 웹훅 비밀은 면제할 수 없다.
- 비밀 셋은 `[!-~]+`이어야 하고 웹훅 비밀은 32자 이상이다. `SECRET_KEY`는 W009를 지켜야 한다. 빈 `SENTRY_DSN`은 Sentry 끔이다.
- 교차 규칙: `POD_NAMESPACE` = `jt-<ENV>` · KAFKA_USERNAME · DB 사용자 · ALLOWED_HOSTS의 svc DNS.
- 자리값 자격이면 Authentik · OpenFGA를 부르지 않는다. `/health`는 늘 200이고 checks는 db · dragonfly(PING) · kafka_producer다(응답에 version · git_sha).
- 웹훅 HMAC 키 = `secret.encode()` — kv 문자열의 바이트 그대로다(packages/django-common/src/django_common/auth.py:862 — 확인) 〔75A-9〕.
- Access 검증은 aud · 서명 · `common_name` 불일치를 모두 같은 `AccessRequired`로 낸다(auth.py:526-552 — 확인). 그래서 tester-m2m의 403은 CN의 뜻을 증명하지 못한다 〔75A-4〕.
- env 위생 목록의 정본은 templates/django-pod/tests/_render.py:198-228이다(이름 · 접두 `PG` · 접미 `_PROXY`). bn:4431 · :4489는 gitops 거울에 `FORWARDED_ALLOW_IPS` · `SCRIPT_NAME`(gunicorn이 process env에서 읽는다)을 더할 후보로 적었다.

### 2.3 Vault · Access · 클러스터 선언 · 권한

**Vault kv**(기록 기준 — 라이브 미확인)

| 경로 | 상태 |
|---|---|
| db app/owner · kafka · dragonfly identity-admin | 있음(bs §4 T054 · T056 · T057) |
| authentik/identity-admin(5키) · webhooks(1) · openfga(2) — env마다 | sentinel(vu:294-308) |
| `django` · `sentry` | 없음 |

**Access**(확인)
- 서비스 토큰 넷(infra/cloudflare/access.tf:24-30) · svc-auth-dev/prod 정책 = `web-bff-<env>` + `tester-m2m`(:35-58).
- m2m 앱 둘은 `service_auth_401_redirect = true`(:162-179), admin 앱은 GitHub IdP(:108-133).
- 출력(outputs.tf:19-43): `access_app_aud`는 비밀이 아니고 키가 `identity-m2m-dev|prod` · `admin`이다. `service_tokens`는 sensitive(`client_id` · `client_secret` · `expires_at`)이고 토큰 넷의 비밀이 모두 든다.
- tester 토큰은 Vault에 없다(vu:339 — T077 · T092로 이연).

**권한 사실**(확인)
- Reloader Role은 감시 ns(identity · jt-dev · jt-prod)의 secrets를 get/list/watch한다 — 「그 ns의 Secret 전부 읽기」(G/platform/reloader/kustomization.yaml:30) 〔75B-5〕.
- `eso-prod` 정책 = `kv/data/prod/*` · `kv/metadata/prod/*` read(infra/vault/policies.tf:31-34) · role TTL 1h/4h(roles.tf:36-37) 〔75B-13〕.
- data ns `allow-egress-external-443`은 `podSelector: {}`다(G/platform/policies/policies-external.yaml:148-156 — 목적은 barman-cloud뿐 · np:119) 〔75B-7〕.
- agent-view는 pods · logs를 읽지만 traefik.io CR은 못 읽는다(infra/bootstrap/traefik-config.yaml:94-95).

**클러스터 선언** 〔R3 §5 · §6〕
- 이미 있는 것: DB role · DB · KafkaUser · 토픽 · Dragonfly 사용자 · CA 미러(jt-dev · jt-prod) · NP 행 전부 · 쿼터(dev 2Gi/4Gi/20 · prod 3Gi/6Gi/30) · CSS 5.
- vault-prod는 소비자가 0이다. T075의 prod ES가 첫 로그인 실증이 된다 〔R3 §3.1〕.

**dev bump**: bump 스크립트는 `sha256:<old>`가 든 줄 하나만 찾는다(scripts/ci/publish-pod-bump.sh:498-507 — 확인). 그래서 overlay에 AUD(64 hex) 줄을 더해도 bump는 깨지지 않는다.

### 2.4 실측 · 외부 사실

- **gitleaks 8.30.1**(억제 주석 없는 재현 〔75A-15〕): `ACCESS_AUD_M2M: <64hex>` 한 줄 꼴은 `generic-api-key`로 leaks 1이다. JSON6902 두 줄 꼴(`path:` 다음 `value:`)과 flow 꼴은 no leaks다. `<32hex>.access`는 통과한다. R3 탐침의 「8 LEAK PASS」는 AUD 줄에 `# gitleaks:allow`가 붙은 상태였다 — 근거로 쓰지 않는다.
- **부분 트리 validate 탐침**(base 9 + 최소 dev overlay + dev Application): 관련 검사가 PASS였고 렌더 8객체 · 컨테이너 5개 모두 digest가 붙었다 〔R3 §7.4①〕. 비판 A의 스크래치 dev · prod 빌드도 8 · 10객체였다.
- **Argo CD**(GitHub GET 2026-11-17 — 결정 기록)
  - v3.5.4(10-06)가 critical 넷(fmxq · m3vr · fw5c · 9v9p)과 high 둘(j6cw · 4439)을 고쳤다. 최신 3.5.x = v3.5.7(11-02 · 15일) · 3.6.1(11-04 · 13일).
  - auto-sync는 리비전마다 한 번이다. 기본 retry 5(≈ 5분)를 다 쓰면 같은 리비전은 멈춘다. selfHeal은 부분 sync라 hook을 건너뛴다. operation 시간 제한이 없다 〔R4 §1〕.
  - v3.5.2 hook.go는 `argocd.argoproj.io/hook`을 쉼표 목록(공백 제거)으로 읽고, 인식된 Argo 타입이 0개면 `helm.sh/hook`으로 내려간다(`pre-delete` → PreDelete · `post-delete` → PostDelete) 〔75B-2〕.
  - HookSucceeded hook은 operation 전체가 성공으로 끝날 때 지운다(gitops-engine sync_context.go:611-657 · :703-712 — 소스 판독) 〔75B-5 · CD-20〕.
- **ESO 2.10**: 경로 · property가 있으면 값과 무관하게 SecretSynced다 · template이 있으면 ES 메타데이터를 Secret에 복사하지 않는다 · `kv put`은 통째로 바꾼다(일부 키는 `kv patch`) · Replace는 template 키만 둔다 〔R4 §2〕.
- **kustomize 5.8.1**: `patches`가 namespace 변환보다 먼저 돈다 · JSON6902 `test` 지원 · images 기본 대상에 initContainers와 Job이 든다 · **최상위 namespace 변환은 cluster 범위 객체에도 `metadata.namespace`를 찍는다**(R4 §6.6 — 그래서 cluster 범위 판정은 ns가 아니라 kind로 한다).
- **Traefik · K3s**
  - Ingress `Prefix`는 글자 단위 PathPrefix다(strictPrefixMatching 기본 false). CRD Middleware 참조 꼴은 `<ns>-<name>@kubernetescrd`이고 같은 ns면 cross-namespace 설정이 필요 없다 〔R4 §4〕.
  - 이름이 `default`인 TLSOption이 둘이면 통째로 폐기되어 sniStrict · clientAuth(AOP)가 사라진다(traefik-config.yaml:129-131).
  - 액세스 로그는 **상태 400–599만** 남긴다(traefik-config.yaml:188-189 — 확인). 헤더는 기본 drop이다.
  - 번들: K3s v1.36.4 = 3.7.8 · v1.36.5 = 3.7.13 · v1.36.6+k3s1(11-03 · 14일) = 3.7.15. Traefik v3.7.18(11-10 · cp28 · p956 · x5pf …) · v3.7.19(11-13). SUC Plan은 채널 v1.36이라 창(window)에서 패치를 자동으로 올린다(G/platform/system-upgrade/plan-k3s-server.yaml:58).
- **Dragonfly**: 문서는 `CLIENT KILL`을 `@admin @dangerous`로 적지만 v1.40.1 실측은 `CLIENT` = CONNECTION|SLOW 한 명령이다(R5 — 문서 ≠ 실측).

### 2.5 UD-9 실측(R5 요지)

- **(a) 지금 규칙** `~revoked:* ~identity-admin:* +@all`에서 pod 자격으로 다음이 전부 OK였다: 자기 키 패턴 넓히기 · 사용자 생성 · CONFIG SET · FLUSHALL · MONITOR(다른 사용자의 `HELLO … AUTH` 비밀번호 평문) · `SORT … GET`(남의 값 읽기) · `RM 0 MATCH`(남의 키 삭제) · CLIENT KILL/PAUSE · 템플릿 pod의 `%R~` 자가 해제. `ACL DRYRUN`으로 본 SHUTDOWN · DEBUG RELOAD · SAVE · BGSAVE · REPLICAOF · DFLY는 「허용」이었다.
- **(b)** `-@admin -@dangerous`는 위를 막지만(DRYRUN의 REPLICAOF · SAVE도 거부) CLIENT KILL/PAUSE가 남는다.
- **(b2)** = (b) + `-client`: CLIENT 계열까지 막고 앱 · Celery · 시험이 통과한다(4파일 127 · C 전체 521과 포함 관계).
- **(c)** 허용 목록은 가장 좁지만 명령 하나만 빠져도 워커가 `auth:NoPermissionError`로 죽는다.
- 앱과 Celery가 쓰는 명령에 채널(PUBLISH · SUBSCRIBE)은 0개였다.
- aclfile 토큰 오류: `ACL LOAD` 중이면 옛 규칙이 남는다(안전). **기동 중이면 무인증(+PONG)**이 된다. 그런 토큰 꼴 = `cmd|sub` · `reset` · Redis 카테고리 이름(`@hyperloglog`).

---

## 3. 결정

### D1 범위 · PR 넷 · 순서 · 관문 〔CD-14 · CD-16 · CD-19 · CD-29 · CD-30 · UD-14〕

- T075는 dev와 prod를 **모두 배포한다**(CD-29 확정). 문면의 `overlays/prod` · `identity-admin-prod`, AC6, T076이 그것을 요구한다. 확인 기준은 dev(문면) + prod(D16)다.
- gitops PR은 사람 PR이다. 머지와 관문 승인은 운영자가 한다(infra.md:39).

| PR | 내용 | 관문(UD-14) | 머지 선행 |
|---|---|---|---|
| GP-1 검사 · 경계 | vsh 3.9 · 7.5 · 13.7 · 14.0–14.8 · 7.1 고침(argocd 갈래 = `bootstrap/argocd` 하나 〔R-2〕) + vts 사례 · 부정 픽스처 · positive 확장 · 재배치(R-3) · AppProject dev/prod 허용 목록(projects/dev.yaml · prod.yaml — D8) · vyml classify 넓힘 + 자기 시험(D23) · 계약 거울 · 렌더와 무관한 문서 정정(C27) | **need** — `clusters/oci-k3s/projects/**`(dev.yaml · prod.yaml)를 바꾼다(`pull_request` 실행은 PR 쪽 워크플로 파일로 돈다 — gr:98 · 넓힌 규칙이 이 PR 자신을 판정한다) | 없음 — dev/prod 프로젝트의 소비자가 0이라 운영 영향 0 · CI 자기검사 전체 초록 |
| GP-A UD-9 | data-assert `acl-list` 새 뜻(job-data-assert.yaml:131-141) · 머리 주석 둘 · policies/tests/README.md:86 · platform/dragonfly/README.md(C28) | skip | L6 끝 — dev · prod W-6 + `ACL LOAD` + O-6 사후 PASS(D20) |
| GP-2 dev | base 9 바이트 사본 · overlays/dev · Application 둘(`identity-admin-dev.yaml` · `identity-admin-prod.yaml` — prod는 빈 overlay를 가리킨다) · README 행(C29) | **need** — `apps/*/base/**` · `*-prod.yaml` | GP-1 · GP-A 머지 · **L6(UD-9 적용) 완료 · data-assert 7 id PASS(acl-list = NOPERM)** · dev W-2 · O-3 dev `gate=PASS` 출력 〔CD-14〕 |
| GP-3 prod | overlays/prod(kustomization · `ingress-admin.yaml` · `middleware-admin.yaml`) + 머리 주석(C30) | **need** | dev 확인 통과 · prod W-2 · O-3 prod `gate=PASS` · attestation 확인(D4) |

- 운영자 승인 셋(GP-1 · GP-2 · GP-3) · 머지 넷.
- **순서와 이유**
  - ① GP-1이 먼저 머지돼야 GP-2 · GP-3의 실제 렌더가 새 검사를 받는다(test-first). AppProject 허용 목록도 첫 앱 Application보다 먼저 선다.
  - ② GP-A는 L6(라이브 ACL 적용) 뒤에만 머지한다. 새 `acl-list`는 NOPERM을 기대하므로, 먼저 머지하면 다음 data-assert가 FAIL한다.
  - ③ prod Application을 GP-2에서 빈 overlay로 만든다. 관문은 UD-14로 그 파일도 덮으므로 이제 까닭은 관문이 아니다 — GP-3의 관문 diff가 prod 객체뿐이 되고(렌더 코멘트가 깨끗하다), 빈 Application의 Synced/Healthy를 먼저 본다(VD-T075-12 — 같은 꼴의 `platform-openfga` · `-authentik` · `-monitoring`이 오늘 Synced/Healthy · 추론).
  - ④ prod seed digest는 dev 확인 뒤에 고른다.
- **작업 자리**: 공유 클론의 브랜치를 바꾸지 않는다. T074 seed 선례대로 모노레포 무시 폴더의 worktree(`.superpowers/t075/gitops-<PR>`)에서 origin/main으로부터 브랜치를 만든다. push와 PR 생성은 사용자 확인 뒤에 한다.

### D2 base 정본과 동기화 〔CD-3〕

- **정본 = 모노레포 `apps/identity-admin/deploy/base`**다. 시험이 이 파일을 읽는다(ia-18 · test_migrations · kubeconform-deploy).
- **gitops base = 파일 이름 1:1 바이트 사본**이다. 출처는 모노레포 `origin/main` `9fd9f2c`이고 blob 9개(§2.2)를 GP-2 본문과 bn에 적는다. base에 gitops 전용 수정을 두지 않는다.
- **변경 흐름**(UD-1)
  - 모노레포가 먼저다(시험 · 리뷰).
  - gitops base 사본 PR은 **그 base를 담은 모노레포 main 발행 뒤**에 낸다 — 이미지(모노레포 main) → 매니페스트(gitops) 순서다. 기능 브랜치의 base 변경을 먼저 사본으로 보내면 dev 이미지에 없는 코드를 전제한 매니페스트가 dev에 auto-sync된다.
  - UD-14로 base 사본 PR은 관문 대상(need)이다.
  - gitops에서 먼저 고친 것(긴급)은 같은 과제 안에서 모노레포로 되옮긴다.
- **동기화 하네스**(모노레포 · 자리 후보 `tests/scripts/gitops-base-sync.tests.ps1` · run-all 새 슬롯)
  - 기준: 모노레포 `origin/main`의 `apps/<pod>/deploy/base` blob(`git ls-tree`) ↔ 형제 클론 gitops `origin/main`의 `apps/<pod>/base` blob(`git --no-optional-locks ls-tree`). 이름 집합과 blob id가 정확히 같아야 PASS다.
  - 모노레포 작업 트리 ≠ 모노레포 `origin/main`의 차이는 INFO 「발행 대기」 줄로만 낸다(FAIL 아님).
  - 대조한 두 커밋(모노레포 · gitops `origin/main`)을 출력한다. fetch하지 않는다(낡았으면 컨트롤러가 fetch한다).
  - 동기화 표(지금은 identity-admin 한 줄)의 pod마다 본다. 형제 클론이 없을 때만 SKIP이다(px-23 선례 — tests/scripts/publish-pod.tests.ps1:2093).
  - 모노레포 PR CI에 두지 않는다: 순서가 이미지 → 매니페스트라서 PR 단계에서 강제하면 순서가 꼬인다. 과제 마감(run-all)에서 강제한다.

### D3 dev overlay(GP-2)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: jt-dev
resources:
  - ../../base
images:   # 세 줄 그대로 — 봇이 digest 줄만 제자리에서 바꾼다(T074)
  - name: ghcr.io/joshua92y/identity-admin
    newName: ghcr.io/joshua92y/identity-admin
    digest: sha256:<지금 값 그대로>
patches:
  - target: {group: networking.k8s.io, version: v1, kind: Ingress, name: identity-admin}
    patch: |-
      - op: test
        path: /spec/rules/0/host
        value: PLACEHOLDER.joshuatech.dev
      - op: replace
        path: /spec/rules/0/host
        value: identity-m2m-dev.joshuatech.dev
  - target: {version: v1, kind: ConfigMap, name: identity-admin-config}
    patch: |-
      - op: replace
        path: /data/ACCESS_AUD_M2M
        value: <AUD identity-m2m-dev>
      # D5 표 dev 열의 나머지 replace · JT_PLACEHOLDER_EXEMPT add
```

- 대상 선택자에 namespace를 쓰지 않는다(patch가 namespace 변환보다 먼저 돈다).
- ES는 base(dev) 그대로 두고, replicas와 admin Ingress는 두지 않는다.
- images 세 줄을 지우거나 옮기지 않는다. 주석에 digest hex를 다시 쓰지 않는다(bump는 `sha256:<old>` 줄이 하나여야 한다). 머리 주석 :4와 자리 값 주석 :8-9는 지금 사실로 고친다(C29).

### D4 prod overlay(GP-3)

- **기본**: `resources: [../../base, middleware-admin.yaml, ingress-admin.yaml]` · `namespace: jt-prod`.
- **images 첫 항목(사람 seed)**
  - promote ④의 전제다(gr:88 — 항목은 정확히 하나 · 봇 줄 꼴). 첫 승격 실연은 T115다.
  - digest는 GP-3을 쓰는 시점의 dev digest다(지금 `faf55a57…`).
  - 사람 seed는 promote ③(attestation 검증)을 거치지 않는다. 그래서 컨트롤러가 T115 목표 플래그(gr:89)로 다음 GET을 돌리고 결과를 PR 본문에 남긴다:
    `gh attestation verify oci://ghcr.io/joshua92y/identity-admin@<digest> --repo joshua92y/joshuatech_ver2 --signer-workflow joshua92y/joshuatech_ver2/.github/workflows/publish-pod.yml --source-ref refs/heads/main --deny-self-hosted-runners`
- **patches**
  - Ingress host: `test` PLACEHOLDER → `replace` `identity-m2m-prod.joshuatech.dev`.
  - ConfigMap: D5 표의 prod 열.
  - ES `identity-admin-env`: `/spec/secretStoreRef/name` → `vault-prod`. 인덱스 0–11마다 `op: test` `/spec/data/N/secretKey` = 이름을 두고, 그다음 `replace` `/spec/data/N/remoteRef/key` = `prod/…`.
  - ES `identity-admin-migrate`: store와 인덱스 0–1을 같은 꼴로 바꾼다(→ `prod/db/identity_admin/owner`).
- **prod 키**(IR:429-445 순번 — 3.9가 pod 표 ES 표로 순서 · 개수 · `secretKey` · key · `property`를 정확히 본다 〔VR-11〕)

| 인덱스 | prod key |
|---|---|
| 0 · 1 | `prod/db/identity_admin/app` |
| 2 | `prod/kafka/identity-admin` |
| 3 | `prod/dragonfly/identity-admin` |
| 4 · 5 · 8 | `prod/authentik/identity-admin` |
| 6 | `prod/sentry/identity-admin` |
| 7 | `prod/django/identity-admin` |
| 9 | `prod/authentik/webhooks/identity-admin` |
| 10 | `prod/openfga/store_id` |
| 11 | `prod/openfga/preshared` |

### D5 ConfigMap 값과 패치 꼴 〔CD-25 · CD-28〕

- **꼴**: overlay마다 키별 JSON6902 `replace`를 쓴다. 키가 base에서 사라지면 렌더가 실패하므로 base 드리프트를 잡는다. `JT_PLACEHOLDER_EXEMPT`만 `add`다(base에 없다).
- `키: 값` 한 줄 꼴(전략 병합 · configMapGenerator literals)은 쓰지 않는다 — AUD 줄을 gitleaks가 비밀로 잡는다(§2.4). `# gitleaks:allow` 억제 주석도 늘리지 않는다.
- 이 꼴은 진짜 비밀도 지나간다. 그래서 대신 **값 꼴을 단언한다**: 14.2(`ACCESS_AUD_*` = `^$|^[0-9a-f]{64}$` · `ACCESS_EXPECTED_CN` = `^[0-9a-f]{32}\.access$` · 키 집합 정확 일치) · 14.4(pod · env별 정확한 값 · dev ≠ prod) · 14.7(앱 렌더 kind Secret 0) 〔CD-25〕.
- 같은 값이 다른 길로 들어오는 것도 막는다: 14.1 ④(컨테이너 `envFrom` · `env[]`를 base 그대로 고정 — `env[]` 리터럴 · 둘째 ConfigMap · ES template 키가 이 표의 키를 덮지 못한다) · 3.9(ES store · `data[]`를 pod 표로 고정) 〔VR-10 · VR-11〕.

| 키 | dev | prod | 근거 |
|---|---|---|---|
| ACCESS_AUD_M2M | AUD(identity-m2m-dev) | AUD(identity-m2m-prod) | O-1 · ia:16 |
| ACCESS_EXPECTED_CN | web-bff-dev Client ID | web-bff-prod Client ID | O-1 · ia:35 |
| ACCESS_AUD_ADMIN | (base `""`) | AUD(admin) — 계약대로 〔CD-28〕 | O-1 · ha:29 |
| ALLOWED_HOSTS | `identity-admin.jt-dev.svc,identity-m2m-dev.joshuatech.dev` | `identity-admin.jt-prod.svc,identity-m2m-prod.joshuatech.dev,admin.joshuatech.dev` | ia:15 · pt:84 |
| ENV · KAFKA_USERNAME | (base) | `prod` · `identity-admin` | 교차 규칙(dp §Settings) |
| ADMIN_HOST · FORCE_SCRIPT_NAME | (base `""`) | `admin.joshuatech.dev` · `/identity-admin` | ia:14 |
| AUTHENTIK_WRITES_ENABLED | (base `"false"`) | `"true"` | IR:33 · t073 D18 |
| JT_PLACEHOLDER_EXEMPT(add) | `AUTHENTIK_API_TOKEN,OPENFGA_STORE_ID,OPENFGA_PRESHARED_KEY` | 같음 | t073:2330 |
| AUTH_ACTOR_SUB · OTEL_EXPORTER_OTLP_ENDPOINT | (base `""`) | (base `""`) | T081 · T098 |
| ACCESS_TEAM_DOMAIN · AUTHENTIK_AUDIENCE · KAFKA_BOOTSTRAP · OTEL_TRACES_SAMPLER · OTEL_TRACES_SAMPLER_ARG | (base) `joshua-tech.cloudflareaccess.com` · `identity-admin` · `jt-kafka-kafka-bootstrap.data.svc:9093` · `parentbased_traceidratio` · `"0.1"` | 같음 | B/configmap.yaml:15 · :19 · :26 · :29-30 — 14.4가 글자 그대로 본다 〔VR-10〕 |

- 키 집합 = base 16 + `JT_PLACEHOLDER_EXEMPT` = 17이다. 14.2가 정확히 보고(더한 키 · 빠진 키 = FAIL), 이 표 전체가 pod 표의 ConfigMap 표(계약 C4 정본)다 〔VR-10〕.
- **prod `ACCESS_AUD_ADMIN`**: aud 검사는 호스트에 묶이지 않는다(aud ∈ {M2M, ADMIN}). 지금은 GitHub IdP JWT에 `common_name`이 없어 CN 검사가 admin 앱 JWT를 막으므로 넓힘 효과는 0이다. T084 조건은 D6 · C23 · §7이다 〔CD-28〕.

### D6 prod admin Ingress · Middleware 〔CD-13 · CD-28 · CD-29〕

- **`middleware-admin.yaml`**: `traefik.io/v1alpha1` Middleware `identity-admin-strip`(ns는 overlay 변환으로 jt-prod) · `spec.stripPrefix.prefixes: [/identity-admin]` · 라벨 `app.kubernetes.io/name: identity-admin`.
- **`ingress-admin.yaml`**: Ingress `identity-admin-admin` · `ingressClassName: traefik` · host `admin.joshuatech.dev` · backend `identity-admin:http`.
  - 어노테이션: `traefik.ingress.kubernetes.io/router.entrypoints: websecure` · `router.tls: "true"` · `router.middlewares: jt-prod-identity-admin-strip@kubernetescrd`.
  - `spec.tls` · `router.tls.options` · `router.priority`는 두지 않는다. TLSOption default의 AOP와 와일드카드를 그대로 쓴다. 같은 호스트에 다른 option이 생기면 TLS option 충돌 권고(GHSA-j994)에 닿는다 〔R4 §4.5〕.
- **경로 = `/identity-admin/admin` · `/identity-admin/static` 두 Prefix**(CD-29 확정).
  - `/identity-admin` 하나로 두면 admin 호스트로 `/webhooks/authentik`(HMAC만) · `/healthz` · `/ready` · `/api`가 열린다. ia:13 · ha:7의 「웹훅은 svc DNS 전용」 취지와 어긋난다.
  - Django admin의 리다이렉트와 정적 경로는 두 접두 안에 있다(pt:19 — `STATIC_URL = <ADMIN_SCRIPT_NAME>/static/`). forward-auth 경로는 T084가 더한다.
- 14.3이 이 모양을 허용 목록으로 고정한다(D9) 〔CD-13〕. Ingress는 이름으로 나눈다(`<pod>` = m2m · `<pod>-admin` = admin(prod만) · 그 밖 이름 FAIL). `ingressClassName` · `router.entrypoints` · `router.tls` · backend · 금지 넷은 두 Ingress에 공통으로 걸고, host · 경로 · `router.middlewares`만 admin 고유다(C5와 같다) 〔VR-2〕.
- T084 전에는 사람이 Access를 지나도 admin 페이지는 pod에서 403이다(GitHub IdP JWT에 `common_name`이 없다 — bn VD-T066-5). 정적 경로(`/static/…`)는 AdminHostMiddleware가 JwtAuth 앞에서 서빙한다(pt:19) — 그래서 운영자 브라우저의 정적 파일 GET 200이 router · stripPrefix · ADMIN_HOST를 함께 증명한다(VD-T075-12) 〔75A-13〕.
- **T084 인계 조건**(CD-28): CN 요구를 푸는 것은 host = `ADMIN_HOST`이고 aud = `ACCESS_AUD_ADMIN`일 때만이다. m2m 호스트는 aud = `ACCESS_AUD_M2M`만 받는다(C23).

### D7 Application 둘(GP-2) 〔CD-2 · CD-18 · CD-29〕

- **파일**: `clusters/oci-k3s/apps/identity-admin-dev.yaml` · `identity-admin-prod.yaml`. 한 파일에 Application 하나다. 14.0이 이것을 강제한다 — `clusters/oci-k3s/apps/` 바로 아래 `*.yaml` · `*.yml`마다 문서 정확히 1개 · kind Application · `metadata.name` = 파일 이름(확장자 뺀). 관문(D23)이 파일 이름으로 prod Application을 알아보기 때문이다 〔VR-4〕.
- **정확한 꼴**(gr:46 · :48 보정 C2가 먼저 — 14.0 APP-app이 본다)
  - `metadata.namespace: argocd` · `metadata.finalizers` = 정확히 `[resources-finalizer.argocd.argoproj.io]`(지우면 cascade로 리소스가 지워진다 — 상태 없는 앱이고 DB는 data ns의 CNPG에 있다).
  - wave 어노테이션 = gr:71 표 앱 행의 값. gitops 문서와 주석에는 옮겨 적지 않는다.
  - `spec` 키 = 정확히 {project, source, destination, syncPolicy}. `spec.project` = env(`dev` / `prod` — `platform` · `tests` 금지).
  - `spec.source` = {repoURL, `targetRevision: main`, path 소문자 `apps/identity-admin/overlays/<env>`}.
  - destination = {server `https://kubernetes.default.svc`, namespace `jt-dev` / `jt-prod`} — `destination.name` 금지.
- **syncPolicy**(CD-29 확정): dev `automated {prune: true, selfHeal: true}` · prod `automated {prune: false, selfHeal: true}` · `syncOptions: [ServerSideApply=true]`만 둔다. 긍정 픽스처와 같은 꼴이다.
  - `CreateNamespace` · `managedNamespaceMetadata`를 두지 않는다. ns 소유는 platform-policies이고 프로젝트가 Namespace 생성을 막는다.
  - `retry` · `ApplyOutOfSyncOnly` · `Prune=confirm`(dev prune과 충돌) · `Delete=confirm` 예외를 두지 않는다.
    - 이 앱이 Degraded가 되는 경로는 hook ES(kv 누락)다. 그것은 「머지 전 시드 + 게이트 출력 확인 뒤에만 머지 명령」(D10 · T056 교훈)이 막는다.
    - 뚫렸을 때 복구는 원인 해소 → 전체 수동 Sync다(IR:455-461).
    - `ApplyOutOfSyncOnly`는 재시도에서 wave 순서를 잃는다(gr:48). 이 앱에서는 얻을 것이 없다.
  - `ignoreDifferences`를 두지 않는다(Reloader annotations 전략 · Server-Side Diff — T046 VD-9가 Synced 유지를 쟀다).
- **14.0 APP-app이 위를 고정한다**: Application 파일은 관문 대상이 되었지만(UD-14 — prod만), dev Application과 project 한 줄의 경계 우회는 관문이 아니라 검사가 막는다 〔75A-2 · 75B-3〕.
- **머리 주석**: 역할 · overlay · syncPolicy 근거 · 첫 배포 선행 조건(kv 목록) · hook ES 운영 성질 넷의 요약과 런북 자리(bs §3 T075) · finalizer의 뜻 · (prod) 노출 축소 규칙(D24). wave 숫자는 적지 않는다.

### D8 AppProject 허용 목록 · NetworkPolicy · 쿼터 · RBAC 〔CD-16 · R-2〕

- **AppProject dev/prod → `namespaceResourceWhitelist`**(GP-1 · 계약 gr:49 보정 C17이 먼저)
  - 목록 = 정확히 `""/ConfigMap` · `""/Service` · `apps/Deployment` · `batch/Job` · `batch/CronJob` · `networking.k8s.io/Ingress` · `external-secrets.io/ExternalSecret` · `traefik.io/Middleware`(group까지 정확).
  - 목록 밖 kind는 sync가 실패한다 — traefik.io TLSOption · TLSStore · IngressRoute · ServersTransport · TraefikService · Secret · PVC 등. dev overlay가 TLSOption/TLSStore `default`를 중복시키거나(AOP · sniStrict 소실 · 443 중단) 남의 호스트를 점유하는 경로가 닫힌다 〔75B-1〕.
  - 기존 `namespaceResourceBlacklist` 6종은 **그대로 둔다**(둘째 겹 — 허용 목록에 와일드카드가 들어오는 실수도 금지 목록이 막는다 · 「컨트롤러 확인 필요」 ⑤). `clusterResourceWhitelist: []`도 그대로다.
  - 반영 경로: GP-1 머지 → root 폴링 → `platform-argocd`(bootstrap/argocd가 projects를 base로 포함)가 SSA로 AppProject를 갱신한다. 지금 dev/prod 프로젝트의 소비자는 0이라 즉시 영향은 없다(첫 소비자 = GP-2).
  - 모노레포 `tests/platform/cluster.tests.ps1` argo-3을 함께 고친다: 허용 목록 정확 일치(group 포함) + 금지 목록 ⊇ 6종(조각 ① — 라이브 RED → GP-1 머지 뒤 GREEN · VD-T075-16).
  - 14.7 APP-kinds가 같은 목록을 렌더에서 본다(머지 전에 잡는다). 13.7 RBAC-appproject는 AppProject 정의 자체를 렌더에서 본다 — 나오는 자리(`clusters/oci-k3s/projects` · `bootstrap/argocd` 렌더뿐)와 `dev`/`prod`의 꼴(허용 목록 정확 · 금지 ⊇ 6 · destination 하나 · `clusterResourceWhitelist: []`) 〔R-2〕.
  - 운영자 관찰(L10 · L15 — 관리자 kubeconfig): `kubectl get tlsoption,tlsstore -A`에서 `default`가 각각 정확히 1개. 컨트롤러(agent-view): Traefik 로그 `Default TLS Options defined in multiple` 0줄.
- **NP**: platform/policies에만 둘 수 있고(vsh 5.0) 프로젝트도 막는다. 계약 행(np:85-113)과 선언(G/platform/policies/policies-matrix.yaml)이 이미 같다 〔R3 §6〕. 더하지 않는다.
- **ServiceAccount**: 만들지 않는다(default SA · automount false).
- **쿼터**(추론): 평상시 requests 544Mi · limits 1216Mi, 두 Deployment가 동시에 surge하면 1088Mi / 2432Mi다. dev 한도 2Gi / 4Gi 안이다. 실제 사용량은 O-0에서 본다.

### D9 시험(test-first) — 무엇을 먼저 빨강으로 보나 〔CD-1 · CD-2 · CD-13 · CD-16 · CD-17 · CD-20 · CD-23 · CD-24 · CD-25 · CD-29 · VR-1 · VR-2 · VR-4 · VR-5 · VR-6 · VR-9 · VR-10 · VR-11 · VR-14 · R-1 · R-2 · R-3 · R-4 · R-5 · R-6〕

**1. GP-1 검사(gitops)**

vts 사례를 먼저 써서 RED(코드 없음)를 보고, vsh를 구현해 GREEN을 본다. 계약이 먼저다: gr §validate.yml 3 아래 「(T075 보정 2026-11-17)」 줄(C4)과 pod 표를 쓰고, vsh는 그 코드 사본이다. **검사 번호 · 이름은 이 D9 표가 정본이다** — 빌더가 바꾸지 않는다(14.0은 7.1 확장이 아니라 새 검사다). 계약 C1 · C2 · C3 · C4 · C5 · C17 · C18 · C31의 「validate …」 문장이 이 번호를 쓴다 〔VR-6〕. 7.1 고침 · 7.5 · 13.7의 계약 자리는 gr §validate.yml 6 · 4(C31)다 — 7.5는 검사 7(sync-wave · `platform/<component>/` 디렉터리)의 무리, 13.7은 검사 13(전 렌더 합산 권한 경계)의 무리에 든다. 7.1은 argocd 갈래만 고친다(FAIL 코드 `7.1 WAVE-path` 그대로) 〔R-2〕.

**대상 없음 규칙 — 14.2 · 14.4에만**〔CD-1 · VR-1〕
- 그 overlay 렌더에 pod 템플릿 객체(Deployment · Job · CronJob · Pod · StatefulSet · DaemonSet)가 하나도 없으면 14.2 · 14.4는 「대상 없음 PASS」이고 PASS 줄에 대상 0을 적는다. pod 템플릿 객체가 하나라도 있는데 ConfigMap · 키 · 값이 없거나 다르면 FAIL이다.
- 3.9 · 14.0 · 14.1 · 14.3 · 14.5–14.8은 렌더에 있는 객체에 늘 적용한다. Ingress만 있는 overlay도 14.3을, 컨테이너가 있으면 14.1 · 14.6을 받는다. 대상 0은 해당 객체가 0개일 때뿐이다.
- pod 표에 없는 `<pod>`(overlay 경로 `apps/<pod>/`)의 overlay 렌더가 객체를 하나라도 가지면 FAIL이다(새 pod는 표에 행을 더하는 계약 변경으로 시작한다).
- 까닭(검증 K1-1 · K2-1): 이전 규칙(「Deployment가 없으면 14.1–14.4 · 14.6 PASS」)에서는 관문 밖 dev overlay가 base Deployment를 빼고 같은 디렉터리의 CronJob(외부 이미지 · owner Secret projected) · Ingress(남의 호스트)를 렌더하면 14.1 · 14.3 · 14.6이 모두 「대상 0」으로 꺼졌다. 뼈대 · 빈 prod overlay는 렌더가 0객체라 고친 뒤에도 PASS다(CD-1의 목적 유지).

**pod 표**(identity-admin 행 — 정본 = 계약 C4의 pod 표와 딸린 세 표)

| 칸 | 값 |
|---|---|
| 별칭 · has_admin | `identity`(ha:12) · 예 |
| Ingress 이름(14.3) | m2m `identity-admin`(dev · prod) · admin `identity-admin-admin`(prod만) 〔VR-2〕 |
| m2m 경로(14.3) | `/health` Exact · `/api` · `/session` · `/sessions` · `/tenants` Prefix |
| ConfigMap(14.2 · 14.4) | `identity-admin-config` 하나 · 키 17(base 16 + `JT_PLACEHOLDER_EXEMPT`) · env별 값 = D5 표(AUD 셋 · CN은 꼴만 · 나머지는 글자 그대로 — `ACCESS_TEAM_DOMAIN` · `AUTHENTIK_AUDIENCE` · `KAFKA_BOOTSTRAP` · `OTEL_*` 포함) 〔VR-10〕 |
| ES(3.9) | `identity-admin-env`(data 12) · `identity-admin-migrate`(data 2)만 · store `vault-<env>` · `data[]` = B/externalsecret-env.yaml:40-90 · -migrate.yaml:32-40(dev) · D4 표(prod — 키 접두 `<env>/`) 〔VR-11〕 |
| `envFrom` · `env[]`(14.1 ④) | `envFrom` — Job `identity-admin-migrate` 안의 모든 컨테이너(init 포함) = 정확히 [Secret `identity-admin-migrate`] · 그 밖의 모든 컨테이너(init 포함 · 표에 없는 컨테이너도) = 정확히 [ConfigMap `identity-admin-config`, Secret `identity-admin-env`](이 순서 · `prefix` 없음 — 판정 단위는 컨테이너가 든 워크로드) / `env[]` 이름 — web {`POD_IP`, `POD_NAMESPACE`} · init `startup-check` · relay · celery {`POD_NAMESPACE`} · migrate {`JT_SETTINGS_PROFILE`} · **표에 없는 (워크로드, 컨테이너)는 ∅**(사이드카 · 새 CronJob · migrate Job 안의 다른 컨테이너가 `env[]`를 가지면 FAIL)(B/deployment.yaml:59-68 · :96-109 · :163-172 · deployment-celery.yaml:65-74 · migrate-job.yaml:92-97 — 빌더가 GP-1에서 base와 다시 대조한다 · 문구는 gr pod 표와 같다) 〔VR-10 · R-4〕 |
| 면제 상한 | `JT_PLACEHOLDER_EXEMPT` 원소 ⊆ {`AUTHENTIK_API_TOKEN`, `OPENFGA_STORE_ID`, `OPENFGA_PRESHARED_KEY`}(코드 상수) — 지금 값은 셋 다(D5 · T082 · T083이 거둔다) |

**새 검사 12 · 고침 1**(표 순서 = 번호 순서)

| 코드 | 대상 | FAIL 조건 | 부정 픽스처(후보) |
|---|---|---|---|
| 3.9 ES-app 〔VR-11 · R-6〕 | `apps/**` ExternalSecret(원본 + overlay 렌더) | `dataFrom` · `templateFrom`(어느 자리든) 있음 · `target.template` 없음 · `mergePolicy: Merge` · `refreshInterval` ≠ `5m` · `refreshPolicy` ≠ `Periodic` · `creationPolicy` ≠ `Owner` / (overlay 렌더의 ES마다 — pod 표 ES 표) 이름 ∉ {`<pod>-env`, `<pod>-migrate`} · `secretStoreRef` ≠ {`ClusterSecretStore`, `vault-<env>`} · `data[]` ≠ 표(순서 · 개수 · `secretKey` · `remoteRef.key` · `property` — `<env>/dragonfly/admin` · 다른 pod 경로 · 순번 바꿔치기가 FAIL) · `target.template` ≠ 같은 트리 `apps/<pod>/base`의 같은 이름 ES의 것(키 집합 · 값 글자 그대로 — `engineVersion` · `mergePolicy` · `data`의 키와 값 · base에 그 ES가 없으면 FAIL) · `data[]` 항목의 키 집합 ≠ {`secretKey`, `remoteRef`} · `remoteRef`의 키 집합 ≠ {`key`, `property`} 〔R-6〕 | es-app-datafrom · es-app-merge · es-app-refresh · es-app-admin-key(dev `data[3]` → `dev/dragonfly/admin`) · es-app-other-pod · es-app-extra-es · es-app-template-host(dev overlay가 `DATABASE_URL`의 호스트를 바꿈) · es-app-item-sourceref(`data[]` 항목에 `sourceRef`) |
| 7.1 고침 · 7.5 WAVE-argocd-placeholder 〔R-2〕 | `platform-argocd` Application(7.1의 열거 — 파일 + 렌더) · `platform/argocd/kustomization.yaml` | (7.1 — 기존 코드의 argocd 갈래만 고친다 · FAIL 코드 `7.1 WAVE-path` 그대로) `platform-argocd`의 `source.path` ≠ `bootstrap/argocd`(지금은 `platform/argocd`도 받는다 — vsh:2091-2092) / (7.5) `platform/argocd/kustomization.yaml`이 자리표시가 아님 — 최상위 키 ≠ 정확히 {`apiVersion`, `kind`, `resources`} · `resources` ≠ `[]` | argocd-path-platform(`platform-argocd`의 path `platform/argocd`) · argocd-placeholder-projects(`resources: [../../clusters/oci-k3s/projects]`) · argocd-placeholder-patch(`resources: []` + `patches`) |
| 13.7 RBAC-appproject 〔R-2〕 | 모든 렌더(kustomization 디렉터리 · directory source 파일 — 13.x와 같은 전 렌더 합산) | kind AppProject가 `clusters/oci-k3s/projects` 렌더와 그것을 base로 포함하는 `bootstrap/argocd` 렌더 밖에서 나옴 / (그 두 렌더의 AppProject `dev` · `prod`) `namespaceResourceWhitelist` ≠ D8의 8종(group · kind 정확 · 순서 무관 · 중복 없음) · `namespaceResourceBlacklist` ⊉ 6종(group 포함) · `destinations` ≠ 정확히 하나 {server `https://kubernetes.default.svc`, namespace `jt-<env>`}(`name` 금지) · `clusterResourceWhitelist` ≠ `[]`. AppProject가 하나도 없는 부분 트리는 대상 0 PASS | proj-in-platform(`platform/<c>` 렌더에 AppProject `prod`) · proj-prod-whitelist-extra(`traefik.io/TLSOption` 추가) · proj-prod-dest-two(destination `jt-dev` 추가) · proj-prod-blacklist-short(금지 5종) |
| 14.0 APP-app 〔CD-2 · VR-4 · VR-9〕 | `clusters/oci-k3s/apps/` 바로 아래 `*.yaml` · `*.yml` 파일 전부(directory source가 읽는 꼴 — 11.4와 같은 열거) + 그중 이름 `^(.+)-(dev\|prod)$` Application과 그 source.path 렌더 | (파일마다) 문서 ≠ 정확히 1개 · kind ≠ Application · `metadata.name` ≠ 파일 이름(확장자 뺀) / (앱 Application) `metadata.namespace` ≠ `argocd` · `spec.project` ≠ env · destination ≠ {server `https://kubernetes.default.svc`, namespace `jt-<env>`} · `destination.name` 있음 · `spec` 키 ≠ {project, source, destination, syncPolicy} · syncPolicy ≠ D7(키와 값 정확 — `automated` 두 키 · `syncOptions` 정확히 `[ServerSideApply=true]`) · `managedNamespaceMetadata` · `CreateNamespace` · `retry` 있음 · finalizers ≠ `[resources-finalizer.argocd.argoproj.io]` · 렌더의 namespaced 객체 ns ≠ `jt-<env>` · 렌더에 cluster 범위 객체(판정은 kind 표 — 내장 cluster kind + 저장소 렌더 CRD의 `spec.scope: Cluster`. ns로는 판정하지 않는다 — §2.4 · 「컨트롤러 확인 필요」 ④) | app-project-platform · app-dest-crossenv(dev → jt-prod) · app-overlay-clusterkind · app-file-name-mismatch(`blog.yaml`에 `blog-prod`) · app-file-two-docs(한 파일 dev · prod) · app-ns-not-argocd |
| 14.1 APP-env 〔CD-20 · VR-10 · R-4〕 | `apps/*/overlays/*` 렌더의 모든 pod 템플릿 컨테이너(init 포함) | ① 실효 env 이름(`env[].name` ∪ envFrom 접두 + 키 — ConfigMap은 렌더된 data 키, Secret은 렌더된 ES의 target 키 = `template.data` 키 · Merge면 `data[].secretKey`도)이 금지 목록에 걸림(_render.py:198-228 거울 + `FORWARDED_ALLOW_IPS` · `SCRIPT_NAME` · 대소문자 무시 · 접두 `PG` · 접미 `_PROXY`) ② envFrom · valueFrom이 같은 렌더 밖 ConfigMap · Secret을 가리킴(`fieldRef` · `resourceFieldRef` 예외) ③ Secret `<pod>-migrate` 참조(envFrom `secretRef` · `secretKeyRef` · `volumes[].secret` · `volumes[].projected.sources[].secret`)가 PreSync hook Job `<pod>-migrate` 밖에 있음 — kind 무관(Pod · Deployment · StatefulSet · DaemonSet · CronJob · 다른 Job) ④ 덮어쓰기 금지(pod 표): `envFrom` ≠ 표(Job `<pod>-migrate` 안 = [Secret `<pod>-migrate`] · 밖 = [ConfigMap `<pod>-config`, Secret `<pod>-env`] — 출처 · 순서 · `prefix` 없음) · `env[].name` ∉ 표(그 (워크로드, 컨테이너)의 이름 — 표에 없는 컨테이너는 ∅) · `env[].name`이 그 pod ConfigMap 키 · ES `template.data` 키와 겹침 · ConfigMap 키와 ES `template.data` 키가 겹침(뒤 `envFrom` 출처가 앞 출처를 덮는다) 〔R-4〕 | env-forbidden(`NETRC`) · env-proxy(소문자 `https_proxy`) · env-outside-ref · migrate-ref-projected · migrate-ref-pod · env-literal-override(`env[]`에 `ACCESS_EXPECTED_CN`) · envfrom-extra-cm(둘째 ConfigMap) · es-template-overrides-cm(ES template에 `ACCESS_AUD_M2M`) · env-sidecar-extra(표에 없는 사이드카 컨테이너 + `env[]`) |
| 14.2 APP-cm 〔CD-1 · CD-25 · VR-1 · VR-10〕 | overlay 렌더의 ConfigMap(대상 없음 규칙 — pod 템플릿 객체가 있을 때) | 렌더의 ConfigMap ≠ 정확히 `<pod>-config` 하나(없음 · 다른 이름 · 둘 이상) · 키 집합 ≠ pod 표 ConfigMap 표(정확 일치) · 값에 `PLACEHOLDER-` · `ENV` ≠ env · `ALLOWED_HOSTS` 원소에 `*` · `.`로 시작하는 원소 · `<pod>.jt-<env>.svc` 없음 · `KAFKA_USERNAME` ≠ (dev면 `dev-`) + pod · dev인데 `ADMIN_HOST` · `FORCE_SCRIPT_NAME`이 빈 값 아님 · `ACCESS_AUD_*` ∉ `^$\|^[0-9a-f]{64}$` · `ACCESS_EXPECTED_CN` ∉ `^[0-9a-f]{32}\.access$` | cm-missing · cm-placeholder · cm-aud-form(63자) · cm-cn-form(토큰 이름 `web-bff-dev`) · cm-extra-key · cm-second-configmap |
| 14.3 APP-ingress 〔CD-13 · VR-1 · VR-2〕 | overlay 렌더의 Ingress · traefik.io Middleware(있는 객체마다 — pod 표) | **분류 = 이름**: m2m = `<pod>` · admin = `<pod>-admin`(prod · has_admin일 때만) · 그 밖 이름 · dev의 `<pod>-admin` = FAIL / **모든 Ingress(둘 다)**: `ingressClassName` ≠ `traefik` · `router.entrypoints` ≠ `websecure` · `router.tls` ≠ `"true"` · backend ≠ Service `<pod>` 포트 `http` · host 없는 rule · `spec.defaultBackend` · `spec.tls` · `router.tls.options` · `router.priority` 있음 · host ⊄ 그 pod ConfigMap `ALLOWED_HOSTS`(ConfigMap이 없으면 Ingress가 하나라도 있을 때 FAIL) / **m2m**: host ≠ `<별칭>-m2m-<env>.joshuatech.dev` · 경로 집합 ≠ pod 표(꼴 포함) / **admin**: host ≠ `admin.joshuatech.dev` · 경로 ⊄ {`/<pod>/admin`, `/<pod>/static`}(Prefix) · `router.middlewares` ≠ 정확히 `jt-prod-<pod>-strip@kubernetescrd` · 같은 렌더에 Middleware `<pod>-strip` 없음 / **Middleware**: 이름 ≠ `<pod>-strip` · dev 렌더에 있음 · 둘 이상 · spec 키 ≠ {stripPrefix} · `stripPrefix.prefixes` ≠ `[/<pod>]` | ing-host-alias(다른 pod 별칭) · ing-extra-path(`/webhooks` 덧붙임) · ing-admin-in-dev · ing-priority · mw-extra-prefix · ing-third-name(이름 `<pod>-x` · m2m 호스트 `/webhooks`) · ing-admin-entrypoint-web · ing-only-foreign-host(pod 템플릿 객체 없는 overlay + host `vault.joshuatech.dev`) |
| 14.4 APP-values 〔CD-1 · CD-25 · VR-1 · VR-10 · R-5〕 | pod 표 ConfigMap 표의 env별 값(대상 없음 규칙 — pod 템플릿 객체가 있을 때) | 값 ≠ 표(빠뜨림 포함 — 「꼴」 칸은 빈 값 아님 + 그 꼴 · 그 밖 키는 글자 그대로: `ACCESS_TEAM_DOMAIN` · `AUTHENTIK_AUDIENCE` · `KAFKA_BOOTSTRAP` · `OTEL_*` 포함) · 두 overlay가 모두 렌더될 때 dev = prod(`ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN` — 같은 값 복사. 맞바꿈(dev ↔ prod)은 꼴이 같아 이 검사가 잡지 못하고 O-5c가 잡는다 — D16) | val-writes-prod-false · val-hosts-domain(`.joshuatech.dev`) · val-exempt-extra · val-env-same(두 overlay에 같은 AUD) · val-team-domain · val-kafka-bootstrap |
| 14.5 APP-hook 〔CD-17〕 | 원본 + 렌더 · `apps/**` + `platform/policies/tests/**` | 어노테이션 키가 `helm.sh/hook`으로 시작 · `argocd.argoproj.io/hook`의 쉼표 토큰(공백 제거) 집합 ≠ 정확히 {`PreSync`} · `PreSync`인 객체가 ExternalSecret `<pod>-migrate` · Job `<pod>-migrate`가 아님 · tests 경로의 hook(지금 실물 0 — 허용 0) · 빈 토큰 · 다른 값 · 대소문자 변형 | hook-presync-postdelete(`PreSync,PostDelete`) · hook-x-helm-postdelete(`X` + `helm.sh/hook: post-delete`) · hook-helm-predelete(`helm.sh/hook: pre-delete` 단독) |
| 14.6 APP-image 〔CD-23 · VR-1〕 | `apps/*/overlays/*` 렌더의 모든 pod 템플릿 객체(Deployment · Job · CronJob · Pod · StatefulSet · DaemonSet)의 containers · initContainers — 있는 객체마다(대상 없음 규칙 밖) | image ≠ 정확히 `ghcr.io/joshua92y/<pod>@sha256:<64 소문자 hex>`(태그 병기 · 다른 저장소 · 이름만) | img-no-entry(images 항목 없는 overlay) · img-foreign(외부 이미지 컨테이너) · img-cronjob-no-deploy(Deployment 없는 overlay + 같은 디렉터리 CronJob 외부 이미지) |
| 14.7 APP-kinds 〔CD-16 · CD-25〕 | 같은 렌더 | kind ∉ D8 허용 목록(group 포함) · kind Secret · Service `type` ≠ ClusterIP(빈 값 = ClusterIP) · `externalIPs` · `loadBalancerIP` · `nodePort` 있음 | kind-tlsoption(`default`) · kind-secret · svc-nodeport |
| 14.8 APP-remote 〔CD-24 · VR-5 · R-1〕 | `apps/**` · `platform/policies/tests/**`의 모든 kustomization(원본) | (모두 — 원격 ref 금지) 경로를 받는 필드(`resources` · `components` · `bases` · `patches[].path` · `patchesStrategicMerge` · `patchesJson6902[].path` · `configMapGenerator[].files` · `.envs` · `.env` · `replacements[].path` · `crds` · `generators` · `transformers` · `validators` · `openapi.path`)의 항목에 URL · 스킴(`://`) · `git@` · `github.com/` 꼴 · 절대 경로 / (`apps/**` — **경로 가둠** · UD-14 관문 완결) 그 항목이 `apps/<pod>/` 밖으로 풀림 · overlay(`apps/<pod>/overlays/<env>/kustomization.yaml`)의 항목이 같은 디렉터리의 파일도 정확히 `../../base`도 아님 · base(`apps/<pod>/base/kustomization.yaml`)의 항목이 같은 디렉터리의 파일이 아님(둘 다 **하위 디렉터리 금지** — 디렉터리를 가리키는 항목은 overlay의 `../../base` 하나뿐 〔R-1〕) · `helmCharts` · `secretGenerator` 있음 / (`platform/policies/tests/**`) 원격 ref 금지만 | remote-resource-https · remote-git-ssh · overlay-extra-dir · prod-patch-from-dev(`patches: - path: ../dev/p.yaml`) · prod-cmgen-from-dev(`configMapGenerator` files가 `../dev/`) · base-component-outside(`components: [../shared]`) · app-helmcharts · prod-nested-component-from-dev(prod overlay `components: [sub]` + `sub/kustomization.yaml`(kind Component)의 `components: [../../dev/x]`) · base-nested-from-overlay(base `resources: [sub]` + `sub/`가 `../../overlays/dev/x`를 끌어옴) |

**진행 방식**
- 사례마다 부정 픽스처와, 그 코드에만 있는 `+[FAIL] <코드>` · `-[PASS] <코드>` 단언을 둔다(tests/README.md:121-122).
- vts에 대상 없음 사례를 둔다 〔CD-1 · VR-1〕
  - 「뼈대 overlay(images만 — 렌더 0객체) → 14.x PASS(14.2 · 14.4 대상 0)」 · 「pod 템플릿 객체 있음 + ConfigMap 없음 → 14.2 FAIL」.
  - 「pod 템플릿 객체 없는 dev overlay(base 뺌) + 같은 디렉터리 Ingress(host `vault.joshuatech.dev`) → 14.3 FAIL」 · 「Deployment 없는 dev overlay + 같은 디렉터리 CronJob(외부 이미지) → 14.6 FAIL」(검증 K1-1 · K2-1의 우회 둘).
  - 「pod 표에 없는 `apps/<x>/overlays/dev`가 객체를 렌더 → FAIL」.
- positive 트리를 넓힌다 — ConfigMap · ES · Ingress · Middleware가 있는 dev/prod overlay와 finalizer가 있는 Application을 넣어 통과 갈래가 실제로 돌게 한다.
  - Application 픽스처는 `identity-admin.yaml`(두 문서)을 `identity-admin-dev.yaml` · `identity-admin-prod.yaml`로 나눈다(14.0 파일 결합) 〔VR-4〕. **같은 커밋에서 `platform-apps.yaml`(22문서)도 Application마다 `platform-<c>.yaml` 22파일로 나눈다** — 나누지 않으면 14.0이 positive를 FAIL로 만들어, positive 트리에서 exit 0을 기대하는 사례(positive · author-bot-ok · author-bot-alt-login-ok · author-human-unrestricted · author-push-event-ok)가 빨갛다 〔R-3〕.
  - positive `apps/identity-admin/base`(지금 4파일 — §2.1)를 **B/ 9파일 사본**으로 바꾼다. pod 표 정확 일치(3.9 `data[]` 14 · template · `refreshPolicy` · 14.1 ④ `envFrom` · `env[]` · 14.2 키 17)를 맞추는 가장 짧은 길이다 〔R-3〕.
  - 13.7 통과 갈래: positive에 `clusters/oci-k3s/projects/{kustomization,dev,prod}.yaml`(계약 꼴 — 허용 목록 8 · 금지 6 · destination 하나 · `clusterResourceWhitelist: []`)을 더한다. positive `bootstrap/argocd`는 `resources: []`라 지금은 AppProject 렌더가 없다(확인) 〔R-2〕.
  - 기존 사례의 기대 exit 코드와 FAIL 코드 단언은 그대로다. positive의 수 단언 두 줄만 재배치에 맞춰 고친다 — vts:187 「YAML 파일 2개 · 문서 24개」 → 「YAML 파일 24개 · 문서 24개」(Application 파일 분리), vts:204 「렌더 27개 합산」 → 「렌더 28개 합산」(positive projects 추가)(VD-T075-3 · 마지막 확인 S-1). 다른 부정 픽스처가 새 검사에도 걸리는 경우(`fmt/dirsource`의 `platform-apps.yaml` → 14.0 · `fmt/appset`의 `platform/argocd` → 7.5 — 확인)는 그 사례의 단언(자기 코드의 줄)이 그대로라 픽스처를 고치지 않는다. 빌더가 영향 사례를 돌려 확인한다 〔R-3〕.
  - 값은 꼴만 맞는 저엔트로피 자리 값이고 **dev와 prod를 다르게** 둔다(14.4의 dev ≠ prod 단언 — 같으면 positive가 FAIL한다): `ACCESS_AUD_M2M` dev `0`×64 · prod `1`×64 · `ACCESS_EXPECTED_CN` dev `0`×32 + `.access` · prod `1`×32 + `.access` · prod `ACCESS_AUD_ADMIN` `2`×64 · digest `sha256:` + `0`×64. gitleaks와 「비밀처럼 보이는 값은 넣지 않는다」 규약을 함께 지킨다 — 조각 ①에서 positive 트리에 gitleaks를 돌려 no leaks를 확인하고 bn에 적는다 〔VR-14〕.
- gitleaks 부정 픽스처는 두지 않는다(tests/README 규약 — C3의 문서 단언만) 〔CD-15〕.
- 반복 중에는 `VALIDATE_TESTS_ONLY`로 영향 사례만 돌린다. 전체 판정은 CI다(tests/ 변경 PR · main push).
- **로컬 PASS 기록**〔CD-1〕: GP-1 실트리(gitops base · overlays가 뼈대)와 GP-2 트리(빈 prod)에서 vsh가 PASS이고 14.x PASS 줄이 대상 0을 적는지 bn에 남긴다. 7.1 · 7.5 · 13.7도 같은 두 트리에서 PASS여야 한다 — 13.7은 지금 main 트리(AppProject에 허용 목록 없음)에서 RED이고 GP-1의 projects 변경 뒤 GREEN이다(test-first) 〔R-2〕.
- 넣지 않는 것: probe · securityContext의 거울. base는 바이트 사본이고(D2), 그 모양은 모노레포 쪽(템플릿 렌더 단언 · kubeconform-deploy · ia 시험)이 지킨다. overlay 패치로 바뀌는 command · args · 볼륨 · securityContext도 검사 밖이다 — prod overlay는 관문 안(운영자 승인)이고, 관문 밖 dev overlay는 dev 자격 범위의 임의 실행이라 받아들인 위험이다(편차 14 · §9 — jt-dev · jt-prod의 PSA enforce restricted가 securityContext 일부를 막는다: G/platform/policies/namespaces.yaml:112 · :123) 〔R-6〕.
- 템플릿 렌더 단언 목록(_render.py)에 두 이름을 더하는 것은 후속(T116 — CD-29)이다. 목록이 갈라진다는 사실은 C4에 적는다.

**2. 관문 넓힘(GP-1 · D23)** — vyml classify 판정 함수의 자기 시험(경로 표 사례)을 먼저 쓴다.

**3. 동기화 하네스(모노레포)** — 지금(gitops base가 빈 뼈대) RED, GP-2 머지 + fetch 뒤 GREEN.

**4. GP-2 · GP-3 실제 렌더**
- worktree에서 vsh 전체를 돌린다(`--root` = worktree).
- 변이 셋이 잡혀야 한다: ConfigMap 패치 하나를 뺀다 → 14.4 FAIL · prod WRITES를 `"false"`로 바꾼다 → 14.4 FAIL · ES 순번 하나를 바꾼다 → 렌더 실패(`op: test`).
- kubeconform은 vsh 1이 한다(ES = CRD 파생 스키마 · Middleware = 카탈로그 폴백 — 추론).
- 렌더 diff는 CI render-diff 코멘트(운영자가 확인 — PR 템플릿)와 로컬 렌더 사본(`.superpowers/t075/render/`)에서 본다.

**5. UD-9 모노레포**(D20) — 시험 상수 · conftest · compose(ia-24가 셋을 함께 대조한다)와 하네스(kafka job-d-2 · kafka-tests 픽스처)를 새 규칙 · 새 판정으로 먼저 고쳐 빨강을 본다.

**6. 기존 라이브 하네스** — 배포 뒤 data env-1(SKIP → PASS) · cluster limits-1/2 · argo-1(새 Application 둘 포함) · argo-3(고친 단언) · kafka job-d-2(새 VD-4 근거)를 본다.

### D10 Vault(운영자) — 경로 · 값 · 순서 · 블록 규약 〔CD-8 · CD-9 · CD-10 · CD-21〕

| 경로(env마다) | 지금(기록) | T075가 할 일 | 꼴 |
|---|---|---|---|
| `db/<role>/{app,owner}` · `kafka/identity-admin` · `dragonfly/identity-admin` | 있음 | 없음(O-2가 키 집합만 본다) | — |
| `authentik/identity-admin` | sentinel 5키 | `jwks_url` · `issuer`만 계약 값으로 바꾼다(ia:17). `api_token` · `client_id` · `client_secret`은 sentinel 그대로 | `vault kv patch "-cas=<n>" <path> issuer=<값> jwks_url=<값>`(비밀 아님 — key=value 인자 허용 · 나머지 키 보존 · VD-T075-11) |
| `authentik/webhooks/identity-admin` | sentinel | CSPRNG 32바이트 → base64url(패딩 없음 · 43자)로 덮어쓴다 · **HMAC 키 = 그 43자 문자열의 ASCII 바이트**(디코드하지 않는다 · 끝 줄바꿈 없음 — auth.py:862 `secret.encode()`) · dev ≠ prod · US4에서도 바꾸지 않는다(dm:169) 〔CD-9〕 | `vault kv put "-cas=<n>" <path> -` JSON stdin |
| `django/identity-admin` | 없음 | CSPRNG 48바이트 → base64url 64자 · W009 · dev ≠ prod(dm:176) | `-cas=0` JSON stdin |
| `sentry/identity-admin` | 없음 | `{"dsn": ""}` — Sentry 끔. 경로가 없으면 ES가 실패한다 | `-cas=0` JSON stdin |
| `openfga/{store_id,preshared}` | sentinel | 그대로 두고 면제한다(D5). 교체는 T082 | — |

**블록 규약**(`specs/003-platform-foundation/design/t075-blocks/` — t045 · t054 · t056 · t057 꼴)
- **첫 단계 = 모듈 로깅 4키 가드**〔CD-8〕: `HKLM` · `HKCU`의 `SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging` `EnableModuleLogging` + (`UseWindowsPowerShellPolicySetting` = 1이면) `…\Windows\PowerShell\ModuleLogging` HKLM · HKCU(vu:41 · t057-blocks/op1-seed-dragonfly.ps1:325-329 꼴). 켜져 있으면 값을 읽기 전에 멈춘다. 그 뒤에만 `ConvertFrom-Json`을 쓴다(jq 의존 없음 — O-4도 ConvertFrom-Json). 적용 = 모든 블록(O-1 · O-2 · W-2 · O-3 · O-4 · O-5 · O-6 · W-6).
- 최상위 `& { }` 한 문 · 파일로만 실행(`pwsh -NoProfile -File`) · 정지점은 `Read-Host` 타자 단어.
- 값은 화면 · argv · 파일 · 클립보드에 0 · 되읽기는 SHA-256 Ordinal · fail-closed.
- 판정과 쓰기를 다른 블록으로 나눈다(O-2 · O-3 / W-2). W-6만 T057 op1 파생이라 블록 안에서 판정 → 정지점(`seed` 타자) → 쓰기이고, 독립 판정 O-6이 앞뒤에 선다(CD-5). 모의 하네스에 과도 상태(응답 유실 · CAS 충돌 · 일시 403)를 넣는다.
- 출력은 PASS일 때만 값(비밀 아닌 값만 — O-1), FAIL은 키 이름 + FAIL만이다.
- Dragonfly admin 비밀번호(O-6 사후 탐침 · `ACL LOAD`)는 argv · env · 화면 · 파일에 0이다 — `redis-cli --askpass`(stdin) 또는 운영자 프롬프트 입력. 블록이 넘기는 꼴로 만들 때의 방법은 빌더가 정하고, 하네스가 argv 0을 단언한다.

| 블록 | 하는 일 |
|---|---|
| O-1 | CF 값 5(D11) |
| O-2 판정(쓰기 0) | 경로마다 존재 · 버전 · 키 집합 · 키별 sentinel 여부 · 값 규칙 충족 여부만 출력한다 |
| W-2 쓰기(env 하나씩 · dev 먼저) | 위 표의 넷을 쓴다. 응답이 유실되면 다시 판정하고, 정리는 조건부로 한다 |
| O-3 게이트(쓰기 0 — vu 게이트 1의 **키 단위** 개정, C8) | 아래 PASS 조건을 본다. 컨트롤러에는 `gate=PASS n/n` 한 줄만 붙인다 |
| O-4 | vault-prod 첫 로그인 전 점검 — `auth/kubernetes/role/eso-prod` 투영(bound_service_account_names · namespaces · audience · token_policies · token_ttl · token_max_ttl) · `vault policy read eso-prod`(§5 명령 후보) 〔CD-27〕 |
| O-5 | `/health` · `/session/check` 탐침(D16) |
| O-6 · W-6 | Dragonfly acl 판정 · 새 렌더(D20) |

O-3 PASS 조건:
- `jwks_url` · `issuer`가 계약 값과 글자까지 같다.
- 웹훅 `secret`: sentinel 아님 · 정확히 43자 · `^[A-Za-z0-9_-]{43}$` · 끝 줄바꿈 없음 · (prod 차례에) dev 해시 ≠ prod 해시.
- `secret_key`: 50자 이상 · 서로 다른 글자 5개 이상 · `django-insecure-` 접두 아님 · dev ≠ prod.
- `dsn` 키가 있다(빈 값).
- 면제 셋(`api_token` · `store_id` · `key`)과 `client_id` · `client_secret`만 sentinel이다.
- 기존 경로의 키 집합이 맞다.

**순서**
1. O-2 → W-2 dev → O-3 dev.
2. **O-3 dev 출력 · L6(UD-9) 완료 · data-assert 7 PASS를 받은 뒤에만** GP-2 머지 명령을 준다. 메시지 첫 줄에 「선행 조건 충족 확인됨(O-3 dev PASS · L6 · data-assert 7 PASS)」을 적는다.
3. 머지 뒤 기동 사슬: root 폴링 → PreSync `-migrate` ES SecretSynced → migrate Job → Sync ConfigMap · `-env` SecretSynced → Deployment(init `startup_check` → web · relay) · celery.
4. W-2 prod → O-3 prod → GP-3 관문 승인 · 머지.
- 머지가 먼저 되면: hook ES Degraded → 재시도 소진 → 늦은 시드 → 전체 수동 Sync — bs §4 T056(:1379) · §4 T054(:1187) 「늦은 시드」와 같은 꼴(force-sync 어노테이션 → 전체 수동 Sync)이다 〔CD-10〕.
- 시드 기록(버전 · 시각 — 값은 0)은 bs §4 T075와 bn에 남긴다(C25 · C13 〔VR-9〕).

### D11 CF 값 확보(운영자 O-1) 〔CD-8 · CD-21〕

- 첫 단계는 모듈 로깅 4키 가드다(D10).
- **AUD 셋**은 비민감 출력 `tofu -chdir=infra/cloudflare output -json access_app_aud`에서**만** 읽는다(키 `identity-m2m-dev` · `identity-m2m-prod` · `admin`).
- **Client ID 둘**은 `output -json service_tokens`(sensitive)에서 `web-bff-dev` · `web-bff-prod`의 `.client_id`**만** 읽는다. 속성 이름을 단언한다(객체에 `client_id` 문자열이 있다). 나머지(`client_secret` · tester 둘)는 변수 밖으로 내지 않고 바로 버린다(`Remove-Variable`).
- **키별 정규식**(`-cmatch`): AUD 셋 `^[0-9a-f]{64}$` · cn 둘 `^[0-9a-f]{32}\.access$`. 공통 정규식은 쓰지 않는다 — 서비스 토큰 `client_secret`도 64 hex 꼴이라 속성을 잘못 고르면 비밀이 「형식 PASS」로 보인다 〔75A-8 · 75B-6〕.
- **출력**: PASS일 때만 `<키> PASS <값>`, FAIL이면 `<키> FAIL`만(값 없음).
- 하네스 사례: cn 자리에 64 hex → FAIL · 값 미출력 / AUD 자리에 대문자 hex → FAIL / 키 누락 → FAIL.
- 출력 값은 비밀이 아니다(공개 저장소의 overlay에 들어간다). 운영자가 컨트롤러에 붙이고 bn에 적는다.

### D12 운영 문서의 자리

- 정본은 모노레포 bs다. pt:87이 말하는 「T075 런북」이 이것이다.
  - §3 「T075」(C24): PR 순서 · 머지 선행 조건 · hook ES 운영 성질 넷 · 복구(늦은 시드 꼴 · 전체 수동 Sync · terminate) · prod 노출 축소 규칙(D24) · 확인 · 기록 칸.
  - §4 「T075」(C25): kv 시드 블록(O-2 · W-2 · O-3) · 게이트 · Dragonfly ACL 재렌더(UD-9 — W-6 · O-6 · `ACL LOAD` · 실패 갈래) · 기록 칸.
- gitops Application 머리 주석은 요약을 담고 그 절을 가리킨다.
- vu §US6 게이트 1은 키 단위로 고친다(C8).

### D13 celery 생존 프로브 — T075에서 두지 않는다(CD-29 확정)

- 이유
  - ① 프로브를 두려면 모노레포 B/(정본) · README · 계약 · 시험을 함께 바꿔야 한다. 사본 규칙상 그 변경이 main 발행(UD-1) 뒤 GP-2보다 먼저라서 설계 · 시험 조각이 하나 더 든다.
  - ② US6 동안에는 폐기가 없다(Authentik 미배포 · 시드 없음). 재적용이 멈춰도 실해가 없다.
  - ③ VD-T066-3(신선도 값 전진)이 기준선을 준다.
- 대가(받아들임 · report 편차 10): T098 전에는 beat 사망을 탐지하지 못한다.
- 인계: T083(시드 = 첫 실제 폐기가 가능해지는 시점) 전에 다시 정한다. 경보(신선도 키 · 재적용 성공 줄)는 T098이 둔다.

### D14 owner Secret 상주 — 지금대로 두고 위험을 적는다 〔CD-20〕

- **사실**: `-migrate` ES는 BeforeHookCreation만 가진다. 그래서 sync 사이에도 owner Secret(`identity-admin-migrate` — `DATABASE_OWNER_URL`)이 jt-dev · jt-prod에 남는다.
- **읽는 주체(정확히)**: Reloader SA(감시 ns secrets get/list/watch — G/platform/reloader/kustomization.yaml:30) · Argo CD application-controller · ESO 컨트롤러 · 관리자. owner role은 BYPASSRLS + DDL이다(dp §Roles).
- **대안 `BeforeHookCreation,HookSucceeded`**: 소스 판독상 HookSucceeded는 operation 전체 성공 뒤 지우므로(gitops-engine sync_context.go:611-657 · :703-712) 같은 operation의 Job보다 ES가 먼저 지워지지 않는다. 그러나 deploy/base(정본) 변경이라 D2 순서상 모노레포 main 통합(UD-1 재질문)이 필요하다 → T075에서는 지금대로 둔다.
- **받아들인 위험**(report 편차 13): 「Reloader SA 토큰 탈취 = 두 env의 owner 자격」.
- **검사**: 14.1 ③(참조 주체 = PreSync Job `<pod>-migrate`만 · projected 볼륨 · Pod kind 포함 — 번호는 D9 정본 〔VR-6〕).
- **실측**: VD-T075-5에서 Secret 수명(생성 · 재생성 시각)과 hook 삭제 시점을 기록한다.
- **인계**: 다음 deploy/base 변경 지점(UD-1 재질문 때 함께) + T084 회전 매트릭스(owner 자격 회전).

### D15 그대로 두는 값

- `AUTH_ACTOR_SUB` `""`(T081이 정한다) · `OTEL_EXPORTER_OTLP_ENDPOINT` `""`(Alloy 미배포 — T098) · replicas(base 1).
- 서비스 기준 URL 키는 두지 않는다(기본 svc DNS — Authentik 포트 9000은 T080).
- ES 순번(새 항목은 12번부터).

### D16 /health 게이트와 양성 탐침 〔CD-4 · CD-7〕

- **배포 전(L4 · O-5a)**: tester-m2m 헤더로 `/health`를 부르면 Traefik 404여야 한다(라우터가 없다 — 토큰 · DNS · AOP는 정상이라는 뜻). 헤더 없는 요청의 Access 응답 코드를 기록한다(자격이 필요 없어 컨트롤러도 할 수 있다 · C11).
- **배포 뒤 게이트(O-5b — dev L11 · prod L15)**
  - 운영자가 tester-m2m 자격을 tofu 출력에서 변수로만 받아 stdin 헤더(`-H @-`)로 `https://identity-m2m-<env>.joshuatech.dev/health`를 부른다.
  - 블록은 **상태 코드 · 허용 목록 헤더(`x-request-id` 유무 · `Cache-Control`) · 본문 필드(status · checks 셋 · git_sha)**만 읽어 블록 안에서 판정하고 PASS/FAIL 줄을 낸다〔CD-7〕. 응답 헤더를 통째로 읽거나 내지 않는다 — Access가 서비스 토큰으로 인증된 응답에 실을 수 있는 `Set-Cookie: CF_Authorization`(앱 범위 JWT · m2m 앱 `session_duration` 24h — bn:2899 · infra/cloudflare/access.tf:172)은 자격이다(읽지도 내지도 않는다) 〔VR-12〕.
  - 합격 = **200 · `status: ok` · checks 셋(db · dragonfly · kafka_producer) 모두 ok · `git_sha` = 배포 이미지의 revision(블록 인자 — 지금 main `9fd9f2c7…`) · 응답 헤더 `x-request-id` 있음**.
  - 하네스 사례: 정상 → PASS · status degraded · checks 하나 fail · git_sha 다름 · `x-request-id` 없음 · 404 → 각각 FAIL · 응답에 `Set-Cookie`가 있음 → 판정은 그대로이고 그 값은 출력 · 파일에 0 〔VR-12〕 · 자격 값은 출력 · argv에 0.
- **`/health` 200이 증명하지 않는 것**: `/health`는 pod에서 Access 단계 면제다(ia:21). 그래서 edge Access · AOP · Traefik · Service · pod · 의존 셋은 증명하지만 **ACCESS_AUD_M2M · ACCESS_EXPECTED_CN · ACCESS_TEAM_DOMAIN은 증명하지 않는다**(dev/prod AUD를 서로 바꿔 넣어도 통과한다) 〔75A-4〕.
- **양성 탐침 O-5c(dev L11 · prod L15 — 운영자)**〔CD-4〕
  - 자격: `web-bff-<env>`(tofu `service_tokens` — 변수만 · stdin 헤더 · 4키 가드 첫 단계 · 끝에 `Remove-Variable`).
  - 요청: `GET /session/check?sub=<고정 uuid>&iat=<지금 epoch 초>&sid=<고정 가짜 64 hex>`(값은 블록 상수 — 실제 사용자와 무관).
  - 합격 = 200 · 본문 `{"active": true}`(`nbf` 없음) · 헤더 `Cache-Control: no-store`(O-5b와 같은 허용 목록 헤더만 읽는다 — `Set-Cookie` 0 〔VR-12〕).
  - 증명: `/session/check`는 Access 전용 경로라(ia:27 · :56) 1단계(aud ∈ {M2M, ADMIN} · `common_name` = `ACCESS_EXPECTED_CN`)만 거친다 — 그래서 200 = AUD_M2M · CN = Client ID · 팀 도메인(certs · iss) · B2 ACL 아래 Dragonfly 읽기(GET · EXISTS · 하한 GET)를 한 번에 증명한다. Bearer는 필요 없다.
  - 같은 블록에서 UD-10 표본 하나를 만든다(D18 — 「컨트롤러 확인 필요」 ①).

| 탐침 | 증명하는 것 |
|---|---|
| O-5b `/health` 200(tester-m2m) | edge Access(tester-m2m 정책) · AOP · Traefik 라우터 · Service · pod · 의존 셋 · 이미지 revision |
| O-5c `/session/check` 200 active(web-bff-<env>) | 위 경로 + `ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN` = Client ID · `ACCESS_TEAM_DOMAIN` · B2 아래 Dragonfly 읽기 |
| tester-m2m의 업무 경로 403(T076) | CN 불일치 음성만(사유 로그 없음 — aud · 서명 · CN이 같은 `AccessRequired`) |

### D17 tick 시점

- dev와 prod를 둘 다 확인한 뒤 tasks:192를 [X]로 한다. 결과 줄은 없다(VD 과제가 아니다).
- 그 전에 tick하면 data env-1이 FAIL한다(tests/platform/data.tests.ps1:40-43).

### D18 관측 측정 셋 〔CD-4〕

- **UD-10**(bn:4635): O-5c 블록이 같은 web-bff-<env> 자격 · 같은 가짜 `sub` · `sid`로 `iat`만 깨뜨린 요청(`iat=x`) 하나를 더 보낸다 → 400 `validation_error`(뷰가 조회 앞에서 쿼리를 검증한다 — ia:56). 컨트롤러가 Traefik 액세스 로그(kube-system — agent-view로 읽는다)에서 그 400 줄의 요청 경로에 쿼리(`sub` · `sid` 가짜 값)가 실리는지 기록한다.
  - 까닭: 액세스 로그는 400–599만 남긴다(traefik-config.yaml:188-189). 200 양성 요청은 로그에 남지 않는다 — 「컨트롤러 확인 필요」 ①.
  - tester-m2m 요청은 무헤더 확인 · m2m 호스트 404 확인(`/healthz` · `/ready` · `/webhooks/authentik` · `/admin/` — 선택 · T076이 정식으로 단언)에만 쓴다.
- **exec 출력**(bn:4740 · ia:140): 운영자가 `kubectl exec … -- python -c "print('t075-exec-probe')"`를 돌리고, 컨트롤러가 `kubectl logs`에 그 줄이 0개인지 본다(C16).
- **무헤더 응답 코드**: D16(C11).

### D19 T068 라이브 잔여(CD-29 확정)

- `check_rls --require-rls-role`(app role · 카탈로그 읽기)은 web initContainer의 `startup_check: OK`가 기동마다 증명한다(VD-L6).
- 나머지 셋은 T075에서 하지 않고 report 이연으로 둔다(편차 9):
  - pgvector 멤버 제외 양성: 두 DB에 `vector`가 선언돼 있지만(G/platform/cnpg-databases/databases.yaml:41-42 · :59-60), 확장이 판정 대상을 만들지 않으면 양성이 아니다.
  - 멤버십 양성(임시 LOGIN role + `GRANT <pod>_owner`) — pg-main superuser 작업이다.
  - BYPASSRLS 무소유 role 판별 — 역시 superuser 작업이다.

### D20 UD-9 = B2 실행 — GP-2 전에 끝낸다 〔UD-9 · CD-5 · CD-11 · CD-22 · UD-12 결과(독스트링)〕

- **규칙 문자열**
  - identity-admin: `~revoked:* ~identity-admin:* +@all -@admin -@dangerous -client`
  - `<pod>` · sample-pod: `%R~revoked:* ~<pod>:* +@all -@admin -@dangerous -client`
  - admin은 그대로 `~* &* +@all`이다. `-scan -dbsize`는 넣지 않는다(미실측 · `RANDOMKEY` 등 다른 열람 경로 미측정 → T116 후보).
- **모노레포(조각 ③ — 계약 · 규칙 문장은 ⓪ 〈설계 커밋〉 C9 · C20 · C21)**
  - 템플릿: `templates/django-pod/template/compose/dragonfly-dev.acl.jinja:3` · `tests/conftest.py.jinja:20` · `:303` · `tests/test_outbox.py.jinja:27` 독스트링(「운영 규칙 resetchannels %R~revoked:* ~<pod>:* +@all」) · `{{ pod_snake }}/…celery.py….jinja:7` 독스트링.
  - identity-admin: `compose/dragonfly-dev.acl:3` · `tests/conftest.py:21` · `:307` · `tests/test_api.py:115` · `:241` · `:996` · `tests/test_identity_infra.py:200`(ia-24가 compose · conftest · 상수를 함께 대조) · `tests/test_outbox.py:26` 독스트링 · `identity_admin/celery.py:7` 독스트링 · IR 표식 편집 표(④ · ⑩ · ⑪ — :575 · :581 · :582 — ⑪은 compose 행 `USER identity-admin ON nopass ~revoked:* ~identity-admin:* +@all`) 〔VR-15〕.
  - django-common: `tests/conftest.py:317-320`(identity-admin · test-pod · noperm-pod에 B2 꼬리 — admin 그대로) · `tests/test_fixtures_dragonfly.py:6-8` 독스트링.
  - 하네스: `tests/platform/kafka.tests.ps1` job-d-2(:82-85 · :845-849 — VD-4 근거를 `reader-get` · `reader-set-denied` PASS로 · `acl-list`는 NOPERM PASS를 본다) · `tests/scripts/kafka-tests.tests.ps1:378-380`(EVIDENCE 행 · acl-list 근거를 새 꼴로).
  - UD-12 결과(D21 — UD-9와 무관하지만 같은 조각의 모노레포 빌더가 고친다 · 이 설계 라운드에서는 고치지 않는다): `packages/django-common/src/django_common/management/commands/outbox_relay.py:30` 독스트링 「재생성 간격이 약 1.5 · 3 · 6 · 12 … s」 → 「약 2 · 3 · 6 · 12 … s」(첫 간격 약 2 s) · :33-34(가정 문장 :32-34) 「(T075 VD가 잰다)」 → 결과(T075 로컬 실 브로커 — 생성 → 치명 0.52–0.55 s · relay ↔ 브로커 왕복 지연 약 30 ms 경계). 동작 · 시험과 무관하다.
  - **이미지 문장**〔CD-11〕: 배포 이미지는 다음 main 발행 전까지 바뀌지 않는다(독스트링 · 시험 · compose · README 표 — `celery.py` · `outbox_relay.py` 독스트링은 이미지에 들어가지만 다음 발행까지 기다린다 · UD-1 재질문 거리가 아니다).
- **새 렌더 블록 W-6**(`design/t075-blocks/` — 재렌더 정본)〔CD-5〕
  - T057 op1(`design/t057-blocks/op1-seed-dragonfly.ps1`)의 파생이다. 규칙 맵(:137) · 머리 주석(:17-18) · 기대 줄만 다르고, 하네스도 T057 harness.ps1에서 파생한다(:103-105 · :896의 규칙 상수).
  - 시드(경로 absent → 생성) · 「ACL 파일 갱신」(사용자 경로 live-ok → acl만 live 비밀번호로 재렌더) · 회전(T084)의 정본이다. T057 블록은 `+@all`을 글자로 박았고 닫힌 과제 문서라 고칠 수 없다.
  - 렌더한 줄은 허용 토큰 목록과 글자 단위로 대조한다(`cmd|sub` · `reset` · Redis 카테고리 이름 금지 — 기동 무인증 꼴).
  - **W-6 판정**(블록 안 · 정지점 앞 — O-6과 같은 판정 규칙)〔CD-5 · VR-8〕
    - kv `acl`이 있고 pod 사용자 줄에 B2 꼬리가 없으면(옛 규칙 acl) STOP한다 — 적용 순서 2단계(acl 경로 삭제)를 먼저 한다. op1 파생 블록이 기존 acl 앞에서 멈추는 자리(bs:1667 「acl live-mismatch」)에 그 까닭을 B2 꼬리로 적는다.
    - 렌더한 pod 사용자 줄마다 B2 꼬리(`+@all -@admin -@dangerous -client`로 끝남)를 단언한다. 하나라도 없으면 쓰기 전에 FAIL이다.
- **O-6 판정**(쓰기 0)
  - 사전: kv `acl`의 줄 꼴(dev 4줄 · prod 3줄 · default 줄 정확 · admin 줄)과 pod 사용자 줄의 꼬리를 분류해 출력한다(해시 · 내용 0). **pod 사용자 줄에 B2 꼬리가 없으면 FAIL**이다(적용 전에는 「옛 규칙」으로 기대한 FAIL — 적용 뒤에는 회귀) 〔CD-5〕.
  - 사후(admin — `--askpass`): `ACL DRYRUN identity-admin ACL LIST` · `ACL DRYRUN identity-admin REPLICAOF NO ONE` · `ACL DRYRUN identity-admin CLIENT LIST` → 거부 · `ACL DRYRUN identity-admin GET revoked:sub:x` · `ACL DRYRUN identity-admin SET identity-admin:x 1` → OK · (dev) `ACL DRYRUN sample-pod SET revoked:sub:x 1` · `ACL DRYRUN sample-pod CLIENT KILL ID 1` → 거부. DRYRUN은 실행하지 않고 비밀을 내지 않는다(`ACL GETUSER`는 해시를 보이므로 쓰지 않는다). 라이브에서 `REPLICAOF`를 실제로 보내지 않는다.
- **적용 순서(L6 — 「ACL 파일 갱신」 꼴 · env마다 dev 먼저 · 단계마다 재확인)**
  1. O-6 사전 → 기대 = 옛 규칙.
  2. acl 경로 삭제(bs §4 T057 「정리 판단」 ② 삭제 블록 — 한 번에 한 경로 · `metadata delete`). 삭제와 재렌더 사이에 ESO 갱신이 끼면 ES가 잠시 SecretSyncedError다(Secret은 Retain — 유지).
  3. W-6 재실행 → 기대 = 사용자 경로 `SKIP … live-ok` · acl `PLAN … absent → 생성 예정` → `seed` → 되읽기 해시 일치.
  4. ESO 갱신 — `force-sync` 어노테이션(관리자) 또는 5분 · agent-view로 ES `refreshTime`이 쓰기 뒤인지 본다.
  5. kubelet 반영 — 마운트 디렉터리의 `..data` 링크 대상 이름(갱신 시각)이 쓰기 뒤인지 본다(이미지에 `ls`가 없으면 `refreshTime` 뒤 2분 이상 기다린다).
  6. admin `ACL LOAD`를 **먼저** 한다(`kubectl --kubeconfig <관리자 kubeconfig> -n data exec -it deploy/dragonfly-<env> -- redis-cli --user admin --askpass ACL LOAD` — G/platform/dragonfly/README.md §5 :327 꼴). **재시작은 하지 않는다.**
  7. O-6 사후 PASS.
  8. prod도 1–7. 그다음 GP-A 머지 → 완료된 data-assert Job 삭제(G/platform/policies/tests/README.md §재실행 모델) → 7 id PASS(acl-list = NOPERM).
  - 성공한 LOAD는 연결을 끊는다. 지금 소비자는 data-assert뿐이라(identity-admin 배포 전) 영향이 0이다. GP-2 전에 하는 까닭이 이것이다.
- **실패 갈래**
  - `ACL LOAD` 실패 → 옛 규칙이 메모리에 남는다(안전). **재시작하지 않는다.** 마운트 파일은 다음 기동에서 무인증이 되는 상태이므로 그 env의 Dragonfly 재시작 요인을 멈춘다(SUC 창 · 노드 작업 보류).
    - ① W-6 정정 → 하네스 → 재렌더 → LOAD.
    - ② 그것이 늦으면 **사용자 확인 뒤에만** acl을 T057 op1(옛 판 · 라이브에서 형식이 검증된 판)로 되돌린다(「컨트롤러 확인 필요」 ⑥ — 답: op1 = 되돌림 갈래 전용 · 사용자 확인 뒤). 단계: acl 경로 삭제(적용 순서 2단계의 블록 — kv에는 W-6이 쓴 acl이 있어 op1이 그대로는 live-mismatch로 멈춘다 · bs:1526 · :1667) → op1 실행(사용자 경로 `SKIP … live-ok` · acl `absent → 생성`) → 4 · 5단계 반영 확인 → admin `ACL LOAD` → O-6 사전 판정(기대 = 「옛 규칙」 FAIL · 사후 DRYRUN은 B2 기대가 아니므로 돌리지 않는다) 〔VR-8〕.
    - `metadata delete` 뒤라 `kv rollback`은 쓸 수 없다.
  - O-6 사후 FAIL(LOAD는 OK) → 파일이 아직 옛 내용이었다(5단계 미반영) → 기다린 뒤 6–7을 다시 한다.
- **gitops GP-A**: data-assert ② `acl-list`의 뜻을 「identity-admin 자격의 `ACL LIST` → `NOPERM identity-admin `」으로 바꾼다. id 일곱은 그대로라 하네스의 id 집합이 같다. 이 검사는 B2 꼬리가 빠지면 FAIL하는 **회귀 탐지기**다. 문서 · 주석은 C28이다.
- **안내 돌리기**: bs §4 T057 「ACL 파일 갱신」 · :1461 · :1526 · :1624-1628 · :1667(C26)과 gitops dragonfly README §0 · §1 · §5 · §6(C28)이 새 블록을 가리키게 한다. op1 판별 줄 문구는 하나다: 「op1 = 옛 판(`+@all`) — 실행하지 않는다(되돌림 갈래 제외 · 사용자 확인 뒤)」(C26 · 「컨트롤러 확인 필요」 ⑥과 같다) 〔VR-8〕.
- **조각 ③ 끝 조건**〔CD-11 · CD-22〕
  - 영향 시험(IA · django-common 부분 실행) 초록 + **템플릿 하네스 전체 1회**(dp 「Template changes must keep the generated output green」).
  - **최종 aclfile의 로컬 기동 · LOAD 시험**(운영 digest Dragonfly 컨테이너 · 가짜 비밀번호 · W-6이 렌더한 꼴 그대로): 기동 로그 aclfile 오류 0 · 무인증 PING `-NOAUTH` · `ACL LOAD` OK · pod 사용자로 `REPLICAOF NO ONE` · `SLAVEOF NO ONE` · `SAVE` · `CLIENT KILL` → NOPERM · 앱 경로(R5 ②) OK(VD-T075-17).
  - 블록 하네스 초록 · 리뷰.

### D21 UD-12 = 로컬 실 브로커로 relay ACL VD를 쟀다 — M1 성립(조각 ③′ 끝 · 2026-11-17) 〔UD-12 · CD-6 · 결정 기록 B5〕

- **무엇**: T069 M6(bn:1984-1992)의 relay 외부 거동을 운영 판의 로컬 실 브로커에서 쟀다. 라이브 변경 0 · dev 데이터 쓰기 0 · 운영자 일 0이다(초안 D21의 라이브 「가」 · 「나」를 대신했다). 워크플로 `wf_32816872-6d6`(측정 08:47–09:24Z + 독립 반증 09:42–10:11Z) — 보고 `.superpowers/t075/ud12/{measure,refute}.md` · 결정 기록 B5 · bn 「T075 UD-12 결과」(컨트롤러 기록).
- **구성**(리눅스 컨테이너 — 스크래치 · 가짜 자격 · 정리 뒤 남은 컨테이너 · 네트워크 · 볼륨 0)
  - `apache/kafka:4.3.1`(commitId = 태그 4.3.1) 단일 노드 KRaft(metadata 4.3-IV0) · SASL_SSL(로컬 CA) · SCRAM-SHA-512 · StandardAuthorizer DefaultDeny — Strimzi 1.2.0 simple 인가와 같다(소스 대조 · gitops Kafka CR에 `allow.everyone.if.no.acl.found` 없음).
  - 사용자: KafkaUser `dev-identity-admin`의 ACL 거울(topic 접두 `dev.identity-admin.` RWD · group `dev-identity-admin-` R) + 변형(topic Write 전부 없음 · 일부 토픽만 Write 없음).
  - relay: HEAD `4a40835`를 실제 `apps/identity-admin/Dockerfile`로 빌드한 이미지(amd64 · confluent-kafka 2.16.1 · 번들 librdkafka 2.16.0)의 인자 없는 `manage.py outbox_relay`.
  - 로컬 Postgres 18.6(TLS verify-full)에 migrate Job 스크립트로 마이그레이션 · pending 행은 앱 경로(`publish_owned` → `django_common.outbox.publish` · `transaction.atomic()` · `tenant_context`). 비판 75A-6의 「dev pending 행 경로 없음」은 이 결정으로 소멸했다.
- **기준(측정 전)**: 갈래와 간격이 bn:1985-1987의 기준(L ≈ 0.5 s면 약 2 · 3 · 6 · 12 s)과 맞으면 M1 가정이 선다. 간격이 자라지 않고 일정하면(약 1 s + L을 폴링 단위로 올린 값) M1이 깨진 것이고, 그러면 relay 수정(모노레포 · TDD) → 새 이미지 → **UD-1 재질문**이었다.
- **결과 = M1 가정 성립 · relay 수정 불필요 · UD-1 재질문 없음**(측정과 반증이 같다)
  - **갈래 (i) 치명**: Write가 하나도 없으면 InitProducerId가 `CLUSTER_AUTHORIZATION_FAILED`(브로커 errorCode 31)로 거부되어 치명이다 — stderr `%0|…|FATAL|identity-admin#producer-N| [thrd:main]: Fatal error: Broker: Cluster authorization failed: Failed to acquire idempotence PID …` + `outbox_relay.producer_fatal KafkaException kafka_error=CLUSTER_AUTHORIZATION_FAILED published=0 failed=0 dead=0`. 갈래 (ii)(`GETPID … retrying`)는 0줄이었다 — 소스로도 결정적이다(Kafka 4.3.1은 인가 검사가 코디네이터보다 먼저 · librdkafka 2.16.0은 이 코드를 강제로 치명 처리).
  - **L과 간격**: L(생성 → 치명) = 0.517–0.554 s(서로 다른 시계 셋이 1–10 ms 안에서 일치) · 유휴 재생성 간격 **2.007 · 3.007 · 6.015 · 12.009 s** → 24 · 48 · 96 · 192 · 384 · 556 · 600 s(반증 재현 2.014 · 3.013 · 6.002 · 12.013 s · 유지 대기 1 · 2 · 4 · 8 … 256 s). 첫 간격은 1.5 s가 아니라 **2.0 s**다 — L = T_boot + 0.500 s(부트스트랩 Metadata 뒤 PID 타이머가 다시 켜진다) + T_b1 + 2 RTT라 구조적으로 0.5 s를 넘는다.
  - **행 있음**: `producer_fatal ProducerFatalError kafka_error=CLUSTER_AUTHORIZATION_FAILED published=0 failed=N dead=0` · last_error `_PURGE_QUEUE` · attempts > 10이어도 DLQ로 가지 않는다(dead_at NULL) · 생성 간격은 유지 없이 1.5 · 2.5 · 4.6 · 8.5 … 300 s.
  - **회복 두 꼴**: (a) pending 행을 둔 채 Write 복구 → `pass published=3`까지 수정부터 291.9 s(반증 294.9 s) — 마지막 치명 패스부터 300.06–300.07 s(치명 백오프 300 s + 패스 처리 약 0.07 s) · (b) 상한에서 유휴 relay를 고친 뒤 행 투입 → 행 커밋부터 592.0 s(공식 = 남은 유지 대기 + 치명 백오프 · 반증은 한 단계 앞 변형 551.9 s를 예측 ±0.05 s로 맞혔다). ev:127의 「≤ 300 s」 · 「≈ 600 s」와 맞는다.
  - **일부 토픽만 Write 없음**: 행마다 `TOPIC_AUTHORIZATION_FAILED`(29 · 비치명 · `producer_fatal` 없음) · DLQ Write가 있으면 10번째 패스에 `dead=1`(DLQ 메시지에 `error` 헤더) · DLQ도 막히면 `failed=1` · dead_at NULL(DLQ 시도는 브로커 거부 기록으로 확인).
  - **예외 꼴**(호출 자리별 — relay 판정은 모두 기대대로): poll 첫 호출 = `KafkaException`(31 · fatal True) · 같은 인스턴스 둘째 poll = 예외 없음 · 메시지 대기 중 flush = `SystemError`(`__cause__` = 그 `KafkaException`) · DR = `_PURGE_QUEUE`(fatal False — 치명 순간 librdkafka가 대기열을 스스로 비운다) · 치명 뒤 produce = `_FATAL`(fatal False — relay가 코드로 판정) · error_cb 0회.
- **경계와 뒤집히는 조건**
  - **M1이 깨지는 경계**: relay ↔ 브로커 왕복 지연이 꾸준히 약 31–35 ms 넘게 늘면 L ≥ 1.0 s가 되어 간격이 약 2.5 s로 고정된다(지연 주입 실측 — 한쪽 20 ms(왕복 +40 ms)에서 2.508–2.522 s 고정 · 한쪽 10 ms(+20 ms)에서 2 · 3 · 6 · 12 s 유지 · L은 왕복 증가분의 약 13배로 선형). +20 ms면 L 0.8 s = SP-2 검토 기준(bn:2064 「첫 유지 대기 하한」)이다. 클러스터 안 왕복은 1 ms 미만이라 결론이 유지되고, 일시 지연(DNS 타임아웃 · CPU 고갈 · 브로커 GC)은 그 주기만 사다리를 되돌린다.
  - **운영과 다르면 뒤집히는 조건**: `allow.everyone.if.no.acl.found=true` 또는 어느 토픽이든 Write(`User:*` 포함 — KIP-679: Write가 하나라도 있으면 없는 리터럴 토픽이어도 InitProducerId 허용) → 갈래 (i)이 아니라 행마다 `TOPIC_AUTHORIZATION_FAILED`다. 지금 gitops에는 둘 다 없다.
- **진단 사실**(인계 — §7 T114 · T071 · T097 · SP-2)
  - InitProducerId 거부는 브로커 authorizer 로그에 남지 않는다(0줄 — Produce 거부만 `Denied operation = WRITE …`로 남는다). 진단은 클라이언트 stderr FATAL 줄이고, 필요할 때만 브로커 `kafka.request.logger=DEBUG`(25분에 약 690 KB — 상시 부적합)다.
  - 고친 뒤에도 `producer_fatal` 한 줄이 더 나올 수 있다(고치기 전에 만든 프로듀서가 유지 대기를 마칠 때 · `published=0`) — 「아직 고장」이 아니다.
  - 부분 ACL에서는 패스마다 stderr NOTICE `%5|…|PARTCNT|identity-admin#producer-N| [thrd:…]: Topic … partition count changed from 3 to 0`이 나온다.
  - 행이 있을 때 L이 0.05–0.13 s로 짧아지는 갈래는 produce 시점(부트스트랩 Metadata 뒤)에 따른 경합이다(유인은 `CONN_MAX_AGE` 60 s 뒤 DB 재연결 — 정황). 유휴 경로가 아니라 M1과 무관하다.
- **「추론」으로 남은 것**: arm64 실행 · 실 Strimzi · 클러스터 RTT는 재지 않았다(라이브 금지 · 이 PC는 arm64 에뮬레이션이 꺼져 있다). 판정 코드(브로커 인가 · librdkafka FSM과 타이머)는 아키텍처 · 리스너와 무관하고, arm64 wheel의 번들 librdkafka도 2.16.0이다(`uv.lock` 해시 · .so 문자열 — 반증). 회복 (b)의 상한(약 600 s)은 측정자가 한 번만 쟀다.
- **반영**
  - 이 라운드(〈설계 커밋〉): ev:127 · dp:39(+ 미러 translation-pending 목록) — C10을 〈실측 뒤〉에서 당겼다 · VD-T075-14(§6) · §7 인계 · §8.
  - 조각 ③(모노레포 빌더 — 코드라 이 라운드에서는 고치지 않는다): 독스트링 `packages/django-common/src/django_common/management/commands/outbox_relay.py:30` 「약 1.5 · 3 · 6 · 12 … s」 → 「약 2 · 3 · 6 · 12 … s」 · :33-34(가정 문장 :32-34) 「(T075 VD가 잰다)」 → 결과(D20 모노레포 목록 · 이미지 문장과 같이 다음 main 발행 때 실린다 — 동작 무관 · UD-1 재질문 없음).
  - bn 정정: 닫힌 T069 절의 「약 1.5 · 3 · 6 · 12 s」(bn:1939 · :1996)는 고치지 않고, 정정 줄은 컨트롤러가 bn 「T075 UD-12 결과」에 적는다(컨트롤러 몫 — 작업 트리의 그 절 「새 사실 · 정정」에 「2.0 · 3 · 6 · 12 s로 읽는다」 줄이 이미 있다 · 확인).

### D22 UD-13 = T075 뒤 · US4 전 정비 단계(T075 안에서는 하지 않는다) 〔UD-13 · CD-24〕

- **무엇**: tasks.md 밖 운영 단계다. bn과 report에 기록한다.
  - **Argo CD v3.5.2 → v3.5.7**(11-02 · 14일 원칙 충족): bootstrap/argocd의 raw URL SHA + images digest 둘을 바꾸는 PR 하나(k8s-security 경계 · `bootstrap/argocd`를 바꾸므로 승인 관문 대상 — UD-14 보완). v3.5.4의 critical 넷(GHSA-fmxq · -m3vr · -fw5c · -9v9p) · high 둘(GHSA-j6cw · -4439) · v3.5.6 SSD 오탐 · v3.5.7 hook 파이널라이저 누수(#29464)를 고친다. 3.6.1(11-04 · 13일)은 고르지 않는다(마이너 · 14일 미달).
  - **K3s v1.36.6+k3s1**(11-03 · 14일 · 번들 Traefik v3.7.15 — GHSA-j994 · -g55h · -2272 · -f52w · -fh26 수정): SUC 채널 v1.36이 창에서 패치를 자동으로 올린다(plan-k3s-server.yaml:58) — 정비 단계는 O-0의 라이브 판 기록 → 아직이면 스냅샷 3종(Vault raft · CNPG 백업 · K3s SQLite)을 먼저 확인하고 창에서의 적용 · 노드 순차를 본다(「컨트롤러 확인 필요」 ②).
- **Traefik ≥ 3.7.18**(11-10 — GHSA-cp28 · -p956 · -x5pf …)은 다음 K3s 패치에서 온다. **T084(ForwardAuth 첫 사용)의 전제 조건**으로 기록한다(ForwardAuth 권고 GHSA-rf44 · -hrpp · -p956).
- **T075가 기대는 완화**: 14.5 hook 허용 목록(fmxq) · 14.8 원격 ref 금지 · 경로 가둠(9v9p — apps · tests의 Git 경로) · 기존 11.3 jsonnet 금지(m3vr) · 12.3 helmGlobals 금지(fw5c) · 14.0 앱 렌더 cluster 객체 0(둘째 겹). 남는 길 = `manifestsWithFiles` API(Application get 권한 — 운영자뿐 · 편차 12).

### D23 UD-14 = 승인 관문 넓힘(D7 재확인 · 보완 2026-11-17) 〔UD-14 · CD-19 · VR-4 · VR-7 · R-2〕

- **규칙**: classify의 `need` = 변경 경로에 다음이 하나라도 있을 때다(경로 성분 단위). 없으면 `skip`, 판정 실패는 `need` 그대로다.
  - `apps/<pod>/overlays/prod` 자체와 그 아래
  - `apps/<pod>/base` 자체와 그 아래
  - `clusters/oci-k3s/apps/<이름>-prod.yaml`(`.yml` 포함 — directory source가 읽는 꼴. 파일 이름 = Application 이름은 14.0이 강제한다 〔VR-4〕)
  - `clusters/oci-k3s/projects` 자체와 그 아래(다섯 AppProject 파일 · `kustomization.yaml` — **보완**: 이전 `projects/prod.yaml` 하나)
  - `bootstrap/argocd` 자체와 그 아래(projects를 base로 포함해 AppProject를 적용한다 — **보완**)
- **보완의 까닭**(사용자 결정 2026-11-17 — 「컨트롤러 확인 필요」 ③의 답): `projects/kustomization.yaml`의 patch · 다른 프로젝트 파일 · `bootstrap/argocd`가 `projects/prod.yaml`을 건드리지 않고 prod AppProject를 바꿀 수 있었다.
- **자리**: vyml classify 스텝의 판정 함수(지금 `is_prod` — :1366-1370)를 넓힌다. 사람 PR이고 `.github/` 변경이라 CI 자기검사 대상이다.
- **자기 시험**: 경로 표 사례 — need 다섯(깊은 경로 포함 — `clusters/oci-k3s/projects/dev.yaml` · `projects/kustomization.yaml` · `bootstrap/argocd/argocd-cm.yaml` 포함) · skip(dev overlay · `<pod>-dev.yaml` · `platform-*.yaml` · `platform/**` · `tests/**` · `.github/**` · 문서 · 성분이 다른 이름 `clusters/oci-k3s/projects-x/…` · `bootstrap/argocd-x/…`) · 판정 실패 need. 자리는 빌더가 정한다(vts 사례가 vyml 인라인 함수를 뽑아 대조하는 꼴 등).
- **계약 먼저**: gr §validate.yml 8(:246 제목 · ① · :249 · :251 PR 템플릿 확인 항목 — C18). 거울: G/tests/README.md:52 · :66 · vyml 머리 주석 :69-89 · G/README.md:21 · G/.github/pull_request_template.md:7(C27) 〔VR-7〕.
- **효과**: GP-1(`projects/**`) · GP-2(base · prod Application) · GP-3(overlays/prod)이 운영자 승인 대상이 된다. 정비 단계의 Argo CD PR(`bootstrap/argocd` — D22)도 그렇다. 봇 dev bump는 dev overlay 한 파일이라 그대로 skip이다(VD-5 옵션 A 유지). 대가: base 사본 · 프로젝트 · Argo CD 부트스트랩 PR마다 승인 한 번.
- **남는 관문 밖**(report 편차 14 — 관문 범위는 그대로다 〔R-2〕): 남는 관문 밖: `platform/**` · `platform-*` Application · `tests/` · `.github/` · 문서 · dev overlay · dev Application 변경 PR(받아들인 위험). `platform/**` · `platform-*` Application은 admin 등가다(argocd ns · AppProject · ClusterRoleBinding · jt-prod) — D7로 관문 밖이다. 이 길을 좁히는 검사(7.1 · 7.5 · 13.7 · 14.0 파일 결합)는 PR 코드라, 같은 PR에서 검사 코드를 고치면 지나간다(`tests/` · `.github/` 관문 밖).
  - 예: 14.0 파일 결합을 끄고 prod Application을 `-prod`가 아닌 파일에 두는 PR · 7.1 · 7.5 · 13.7을 끄고 `platform-argocd`의 path를 `platform/argocd`로 돌리는 PR 〔VR-4 · R-2 · S-5〕.
  - **7.1 정정**〔R-2〕: 7.1은 지금(origin/main) 컴포넌트 `argocd`에 한해 `source.path`로 `platform/argocd`도 받는다(validate.sh:2091-2092 — 이전 판의 「7.1 = `platform-argocd` 경로 고정」은 틀렸다). 그래서 검사 코드를 고치지 않고도 `platform-argocd.yaml` · `platform/argocd/**`(둘 다 관문 밖)만 바꾼 PR이 AppProject · Argo CD 본체를 승인 없이 바꿀 수 있었다(`platform/argocd/kustomization.yaml`이 `../../clusters/oci-k3s/projects` 또는 `../../bootstrap/argocd` + AppProject patch를 끌어오는 꼴). GP-1이 7.1의 argocd 갈래를 `bootstrap/argocd` 하나로 좁히고 7.5(자리표시) · 13.7(AppProject 렌더)을 더해 이 길을 검사로 닫는다(D9 · C31). 남는 것은 위 문장의 「같은 PR에서 검사 코드를 고치는」 길이다.

### D24 prod 노출 축소 규칙 〔CD-26〕

- prod Application은 `prune: false`다. 그래서 Git에서 지운 객체(admin Ingress · Middleware 등)는 OutOfSync(requires pruning)로 남고 계속 서비스된다.
- **규칙**: prod에서 노출 축소는 **객체 수정**으로 한다(경로 줄 삭제 등 — SSA로 반영된다). 객체 삭제가 필요하면 PR 머지 뒤 운영자가 그 객체만 수동 prune하고 `kubectl get ingress,middlewares.traefik.io -n jt-prod`로 사라졌는지 확인한다.
- prune 정책은 바꾸지 않는다.
- 자리: bs §3 T075(C24) · prod Application 머리 주석 · gr:48(C2) · overlays/prod 머리 주석(C30).

---

## 4. 계약 · 규칙 보정 목록(표식 「T075 보정 2026-11-17」)

읽는 법은 다음과 같다.
- 세 묶음이다: 〈설계 커밋〉(⓪ — 이 문서와 함께 컨트롤러가 커밋) · 〈조각 커밋〉(그 조각 · GP PR과 함께) · 〈실측 뒤〉(마감 커밋).
- 계약 · 데이터 모델 · quickstart · 런북에는 「T075 보정 2026-11-17」을 단다. 규칙 파일(영어 정본 · 미러)은 관례대로 `(T075)`를 단다.
- 줄 번호는 보정 전 번호다. C11–C16은 〈실측 뒤〉 몫이라 번호가 건너뛴다. C10은 UD-12 결과(D21)가 나와 〈실측 뒤〉에서 〈설계 커밋〉으로 당겼고, C31은 R-2(수정 라운드 확인)로 더했다.

### 〈설계 커밋〉 — C1–C10 · C17–C23 · C31

| C | 파일:줄 | 고칠 것(새 문장의 요지) |
|---|---|---|
| C1 | gr:25 · :26(§디렉터리 `apps/<pod>/`) | :25 아래 주석 세 줄 — base는 모노레포 `apps/<pod>/deploy/base`의 **바이트 사본**이고 정본은 모노레포다 · gitops에서 base만 고치지 않는다(긴급 수정은 같은 과제 안에서 되옮긴다) · 동기화 기준 = 모노레포 `origin/main`의 `apps/<pod>/deploy/base` blob ↔ 이 저장소 `origin/main`의 `apps/<pod>/base` blob(이름 집합 · blob id 정확 일치 · 작업 트리 차이는 INFO 「발행 대기」 · fetch하지 않고 두 커밋 출력 — 모노레포 하네스) · 사본 PR은 그 base를 담은 모노레포 main 발행 뒤(UD-1) · 승인 관문 대상(§validate.yml 8). :26 — overlays 목록에서 「replicas」를 뺀다(replicas = base 1과 어긋난다 · 표식에 이전 문구 〔VR-6〕) · 그 아래 주석 두 줄: overlays/prod = `kustomization.yaml` + `ingress-admin.yaml`(Ingress `<pod>-admin`) + `middleware-admin.yaml`(traefik.io/v1alpha1 Middleware `<pod>-strip` · 같은 ns) · ConfigMap 값 · ES store/key는 JSON6902 · replicas는 base 1 · 앱 Application 파일 = `clusters/oci-k3s/apps/<pod>-<env>.yaml`(파일 하나에 문서 하나 · kind Application · `metadata.name` = 파일 이름 — validate 14.0 · 관문이 파일 이름으로 prod Application을 알아본다 〔VR-4〕) |
| C2 | gr:46(project 행) · :48(syncPolicy 행) | :46 끝 — 이름 `^(.+)-(dev\|prod)$`인 Application의 project는 정확히 env(`platform` · `tests` 금지 — 두 프로젝트가 `jt-*`를 destination으로 가진다 · validate 14.0). :48의 「prod 앱: automated이되 변경은 PR로만.」 뒤 — 앱 Application의 정확한 꼴(D7): `metadata.namespace: argocd` · finalizers = 정확히 `[resources-finalizer.argocd.argoproj.io]` · `spec` 키 = {project, source, destination, syncPolicy} · destination = {server `https://kubernetes.default.svc`, namespace `jt-<env>`}(`destination.name` 금지) · syncPolicy = 정확히 {automated, syncOptions}: dev `{prune: true, selfHeal: true}` · prod `{prune: false, selfHeal: true}` · `syncOptions: [ServerSideApply=true]`. 두지 않는 것과 근거: `CreateNamespace` · `managedNamespaceMetadata`(ns 소유 = platform-policies) · `retry` · `ApplyOutOfSyncOnly`(재시도에서 wave 순서를 잃는다) · `Prune=confirm` · `Delete=confirm` · `ignoreDifferences` — Degraded 경로(hook ES kv 누락)는 머지 전 시드 + 게이트 출력 뒤 머지로 막고 뚫리면 전체 수동 Sync(bs §3 T075). prod Application은 빈 prod overlay를 가리키는 꼴로 먼저 만들 수 있다. prod 노출 축소 규칙(D24 문장 그대로). validate 14.0이 이 꼴을 본다. 런북 참조 「`bootstrap.md` §3 T075」에는 「T075 조각 ④에서 생긴다」를 붙인다(아직 없는 절 〔VR-16〕) |
| C3 | gr:178(비밀 아닌 값 → ConfigMap) | :178 아래 새 하위 항목 〔VR-6〕 — overlay ConfigMap 값은 키별 JSON6902 `op: replace`(`JT_PLACEHOLDER_EXEMPT`만 `op: add`) · `키: 값` 한 줄 꼴(전략 병합 · configMapGenerator literals) 금지: gitleaks 8.30.1 `generic-api-key`가 `ACCESS_AUD_*: <64 hex>` 한 줄을 잡는다(억제 없는 재현 2026-11-17 — JSON6902 두 줄 꼴 · flow 꼴 no leaks · 한 줄 꼴 leaks 1) · `# gitleaks:allow`를 늘리지 않는다 · 이 꼴은 진짜 비밀도 지나가므로 값 꼴을 단언한다(14.2 `ACCESS_AUD_*` = `^$\|^[0-9a-f]{64}$` · `ACCESS_EXPECTED_CN` = `^[0-9a-f]{32}\.access$` · 키 집합 정확 일치 · 14.4 pod · env 정확 값 · 14.7 kind Secret 0) · 같은 값이 다른 길로 들어오는 것도 막는다 — 14.1 ④(`envFrom` · `env[]` 고정 — 덮어쓰기 금지) · 3.9(ES store · `data[]` 고정) 〔VR-10 · VR-11〕 · `JT_PLACEHOLDER_EXEMPT`는 overlay가 둔다(identity-admin = `AUTHENTIK_API_TOKEN,OPENFGA_STORE_ID,OPENFGA_PRESHARED_KEY`) |
| C4 | gr §validate.yml 3(:195) — 항목 3의 마지막 하위 항목 :196(2026-10-14 T054) 뒤(:197은 항목 4 「정책 검사」다) 〔VR-6〕 | 새 하위 항목 「(T075 보정 2026-11-17) 앱 렌더 검사 — 3.9 · 14.0–14.8」(번호 · 이름은 D9 정본): 대상(`apps/**` 원본 + overlay 렌더 · 14.0은 `clusters/oci-k3s/apps/` 바로 아래 `*.yaml` · `*.yml` 전부 · 14.5 · 14.8은 `platform/policies/tests/**`도) · 대상 없음 규칙(14.2 · 14.4에만 — pod 템플릿 객체 6종이 0개일 때 · 나머지 검사는 있는 객체에 늘 · 표에 없는 pod의 비어 있지 않은 overlay 렌더는 FAIL 〔VR-1〕) · pod 표(이 줄이 정본 · vsh는 사본)와 딸린 세 표 — ConfigMap 키 17과 env별 값(14.2 · 14.4 〔VR-10〕) · ExternalSecret `-env` 12 · `-migrate` 2의 dev · prod 키(3.9 〔VR-11〕) · 컨테이너 `envFrom` · `env[]`(14.1 ④ 〔VR-10〕 — `envFrom`은 Job `<pod>-migrate` 안/밖으로 · 표에 없는 (워크로드, 컨테이너)의 `env[]` 이름 = ∅ 〔R-4〕) · 3.9 · 14.0–14.8의 FAIL 조건(D9 표에서 픽스처 칸만 뺀 것 — 3.9 `target.template` = base 그대로 · `data[]` 항목 키 〔R-6〕 · 14.0 파일 결합 · `metadata.namespace` 〔VR-4 · VR-9〕 · 14.3 이름 분류 · 공통 조건 〔VR-2〕 · 14.4 dev = prod는 같은 값 복사만(맞바꿈은 O-5c) 〔R-5〕 · 14.8 경로 가둠 — 같은 디렉터리 파일(overlay는 + 정확히 `../../base`) · 하위 디렉터리 금지 〔VR-5 · R-1〕) · 금지 env 목록 = 템플릿 `_render.py` 목록 + `FORWARDED_ALLOW_IPS` · `SCRIPT_NAME`(두 목록이 갈라진다 — 템플릿 쪽은 T116 후보) |
| C5 | ha:8 · ia:10 · pt:19(admin Ingress) | 자리 〔VR-6〕: ha:8 아래 새 하위 항목 · ia:10 첫 칸(「PathPrefix `/identity-admin`」 → 경로 둘) · 둘째 칸에 `/identity-admin/static/…`(pod에는 `/static/…` — `AdminHostMiddleware` 서빙)을 더함 〔VR-16〕 · 마지막 칸 끝(identity-admin 실명) · pt:19 앞부분(「`PathPrefix(/<pod>)`」 → 둘)과 칸 끝. 문장 — admin Ingress = prod overlay의 Ingress `<pod>-admin`: host `admin.joshuatech.dev` · 경로 Prefix `/<pod>/admin` · `/<pod>/static` 둘만(`/<pod>` 하나면 admin 호스트로 `/webhooks/authentik` · `/healthz` · `/ready` · `/api`가 열린다) · `ingressClassName: traefik` · 어노테이션 `router.entrypoints: websecure` · `router.tls: "true"` · `router.middlewares: jt-prod-<pod>-strip@kubernetescrd` · `spec.tls` · `router.tls.options` · `router.priority` 없음 · stripPrefix Middleware = 같은 ns(jt-prod)의 traefik.io/v1alpha1 `<pod>-strip`(`stripPrefix.prefixes: [/<pod>]`) — 다른 ns면 CRD provider `allowCrossNamespace`(기본 false)가 필요 · forward-auth는 T084 · validate 14.3 |
| C6 | dm:168 | 「…을 US6 동안 어떻게 둘지는 T075가 T044 게이트 1 · 2와 함께 정한다.」 → US6 동안 `api_token` · `kv/{env}/openfga/{store_id,preshared}`는 T044 sentinel 그대로 + 두 overlay ConfigMap `JT_PLACEHOLDER_EXEMPT=AUTHENTIK_API_TOKEN,OPENFGA_STORE_ID,OPENFGA_PRESHARED_KEY` · `client_id` · `client_secret`은 sentinel 그대로(매핑하지 않는다) · `jwks_url` · `issuer`는 `vault kv patch "-cas=<n>"`로 계약 값(비밀 아님 — key=value 허용 · 나머지 키 보존) · 게이트 1은 키 단위(vu §US6 · T075 블록 O-3 — 블록은 조각 ④에서 생긴다 〔VR-16〕). 같은 칸 괄호 「`preshared`는 T044 런북의 US6 교체 규칙도 함께」 → 「`preshared`를 platform 값으로 바꾸는 것은 T082 — vu §US6」(C8이 그 규칙을 없앤다 〔VR-6〕) |
| C7 | dm:175(sentry 행 소비자 칸) | 끝 — US6 = env마다 빈 `dsn`(`{"dsn": ""}` — T075 시드 · 빈 값 = Sentry 끔 · 경로가 없으면 `<pod>-env`가 SecretSyncedError) · 실값은 T100 |
| C8 | vu:309 · :310 · :311(아래 새 하위 항목 — 코드 블록 :312-328은 그대로) · :329(게이트 2 〔VR-3〕) · :330 | :309 「불변식: sentinel 잔존 0 = consumer 활성화 전제.」 → 「면제 셋 밖 sentinel 0 = consumer 활성화 전제」(면제 셋 = `api_token` · `openfga/store_id` · `openfga/preshared` — 게이트 2 면제 + overlay `JT_PLACEHOLDER_EXEMPT` · `client_id` · `client_secret`은 pod에 매핑하지 않아 판정 밖) · `preshared`의 platform 값 교체 = T082(US6에서 바꾸지 않는다). :310 → 비밀은 JSON stdin만(`vault kv put "-cas=<n>" <path> -`) · 비밀 아닌 계약 값(`jwks_url` · `issuer`)은 `vault kv patch "-cas=<n>" <path> issuer=<값> jwks_url=<값>` 허용 · 일부 키만 바꿀 때는 `kv patch`(`kv put`은 경로를 통째로 바꾼다). :311 아래 — 게이트 1 → 키 단위(정본 블록 `design/t075-blocks/` O-3 — 조각 ④에서 생긴다 〔VR-16〕): PASS = `jwks_url` · `issuer` 계약 값 글자 일치 · 웹훅 `secret` sentinel 아님 · 정확히 43자 `^[A-Za-z0-9_-]{43}$` · 끝 줄바꿈 없음 · dev 해시 ≠ prod 해시 · 면제 셋 + `client_id` · `client_secret`만 sentinel · 그 밖 `PLACEHOLDER-` 0 · 출력 `gate=PASS n/n`(값 · 해시 0) — 경로 단위 블록(`read=8/8 hits=0`)은 T044 판정 기록으로 남긴다. :329 게이트 2 — 「T077 tester 단언 `PLACEHOLDER-` 0」 → 「면제 셋 밖 `PLACEHOLDER-` 0」 · 「`preshared`는 위 US6 교체 규칙」 → 「`preshared`의 platform 값 교체는 T082」 · 끝 문장 「…sentinel로 둘지 … 는 T075가 T072와 함께 정한다」 → 정했다: sentinel로 둔다 — 면제 셋은 overlay `JT_PLACEHOLDER_EXEMPT`로 게이트 2에서 빼고, 게이트 1은 키 단위로 그 consumer 활성화(T081 · T082 · T083) 앞에 둔다 · `client_id` · `client_secret`은 판정 밖(:309가 그 규칙을 없앴고 결정은 이미 났다 — 검증 K1-3 · K2-6). :330 「게이트 1 = `read=8/8 hits=0`」 → 「게이트 1 = `gate=PASS n/n`」 |
| C9 | dl:48 · :49 · :50 · :57 뒤 · pt:40 · pt:79 · dp:84(§Dragonfly) + 미러 django-pod_kr.md:68 | dl:48 → `~revoked:* ~identity-admin:* +@all -@admin -@dangerous -client` · dl:49 → `%R~revoked:* ~<pod>:* +@all -@admin -@dangerous -client` · dl:50 → `%R~revoked:* ~sample-pod:* +@all -@admin -@dangerous -client`(admin 행 :47 그대로). :57 뒤 새 항목(UD-9 B2 — Dragonfly v1.40.1 실측 2026-11-17): ① `-@admin -@dangerous`가 `ACL SETUSER`(자기 패턴 넓히기 · `%R~` 자가 해제 · 사용자 생성) · `CONFIG` · `FLUSHALL` · `FLUSHDB` · `MONITOR` · `SORT … GET` · `RM` · `KEYS` · `INFO` · `ACL LIST` · `REPLICAOF` · `SLAVEOF` · `SAVE` · `SHUTDOWN`을, `-client`가 `CLIENT KILL` · `CLIENT PAUSE`를 막는다(Dragonfly `CLIENT`는 CONNECTION\|SLOW 한 명령 · 하위 명령 토큰 없음) · redis-py 8.1의 `CLIENT SETINFO` · `CLIENT MAINT_NOTIFICATIONS` NOPERM은 라이브러리가 삼킨다 ② 남는 것(받아들인 위험): 키 이름 열람(`SCAN` · `DBSIZE`) · Lua(안의 명령은 다시 검사) · `SCRIPT FLUSH` · `FUNCTION FLUSH` · 자기 패턴 안 쓰기 · 삭제(30 s 재적용이 복구하는 것은 identity-admin의 `revoked:*` · 세션 하한 키뿐 — 그 밖 자기 접두 키(캐시 · 큐) 삭제는 복구되지 않는다 〔VR-16〕) · 메모리 고갈(T097) · `-scan -dbsize`는 미실측이라 두지 않는다(T116) ③ aclfile에 쓰면 무인증 기동이 되는 토큰 꼴: `cmd\|sub`(예 `-client\|kill`) · `reset` · Redis 카테고리 이름(`@hyperloglog` — Dragonfly는 `@hyperlog`) · 근거 문장(실행 중 `ACL LOAD`가 실패하면 옛 규칙이 남지만 같은 파일로 기동하면 무인증 〔VR-6〕) → 규칙 변경은 `ACL LOAD` 먼저 · 재시작 금지 ④ 운영자는 `MONITOR`를 쓰지 않는다(`HELLO … AUTH` 비밀번호 평문). pt:40 `(resetchannels %R~revoked:* ~<pod>:* +@all)` → `… +@all -@admin -@dangerous -client)`. pt:79 두 규칙에 같은 꼬리(T075 보정 — UD-9). dp:84 「Exception: identity-admin … uses `~revoked:* ~identity-admin:* +@all`」 → `… +@all -@admin -@dangerous -client`, and every pod user (template `<pod>`, sample-pod) ends with the same tail (T075 — UD-9: Dragonfly's `CLIENT` is one CONNECTION\|SLOW command, so `-client` is needed on top of `-@admin -@dangerous`); never write `cmd\|sub`, `reset` or Redis category names (`@hyperloglog`) in an aclfile (one bad token boots Dragonfly without authentication); operators never run `MONITOR` (Dragonfly shows `HELLO … AUTH` passwords in clear) — 미러 :68 같은 뜻 |
| C10 | ev:127(같은 줄 「약 1.5 · 3 · 6 · 12 … s」 · C22와 같은 괄호) · dp:39(「about 1.5, 3, 6 … s … (T075 measures it)」) · 미러 django-pod_kr.md:1(translation-pending 목록) 〔UD-12 결과 — 〈실측 뒤〉에서 당겼다〕 | UD-12 결과(D21 · 결정 기록 B5). ev:127 「재생성 간격이 약 1.5 · 3 · 6 · 12 … s」 → 「약 2 · 3 · 6 · 12 … s」(첫 간격은 생성 → 치명 시간이 0.5 s를 조금 넘어 약 2 s — 이전 문구 표식) · 괄호의 측정 자리(C22) 뒤에 결과 요지: 갈래 (i) 치명(재시도 갈래 없음) · L 0.517–0.554 s · 유휴 간격 2.0 · 3.0 · 6.0 · 12.0 s … 상한 600 s · 회복 = 행을 둔 채면 마지막 치명 패스 + 약 300 s(실측 300.07 s) · 상한에서 고친 뒤 넣은 행 592 s · 가정 성립(relay 수정 없음) · relay ↔ 브로커 왕복 지연 약 30 ms 경계(꾸준히 약 31–35 ms 넘게 늘면 주기 약 2.5 s) · 일부 토픽 = 행마다 `TOPIC_AUTHORIZATION_FAILED`(비치명) · Write가 하나라도 있으면 InitProducerId 허용. dp:39 「about 1.5, 3, 6 … s … assuming … (T075 measures it)」 → 「about 2, 3, 6, 12 … s (first interval about 2 s) … holds while the relay↔broker round trip stays well under about 30 ms (T075 — local real-broker measurement …)」. 미러에는 T069 relay 문장 자체가 없다(translation-pending 2026-11-03) — 그래서 :1 목록에 같은 뜻 항목을 더했다(번역은 /finish) |
| C17 | gr:49(AppProject 행) | 끝 — `dev`/`prod`의 `namespaceResourceWhitelist` = 정확히 `""/ConfigMap` · `""/Service` · `apps/Deployment` · `batch/Job` · `batch/CronJob` · `networking.k8s.io/Ingress` · `external-secrets.io/ExternalSecret` · `traefik.io/Middleware`(group까지 정확 · 목록 밖 kind = sync 실패 — TLSOption · TLSStore · IngressRoute · Secret · PVC 등) · `namespaceResourceBlacklist` 6종은 둘째 겹으로 그대로 · `clusterResourceWhitelist: []` 그대로 · 반영 = `platform-argocd`(bootstrap/argocd가 projects를 base로 포함) · 하네스 argo-3이 허용 목록 정확 일치(group 포함)와 금지 목록 ⊇ 6종을 함께 본다 · validate 14.7이 같은 목록을 렌더에서 본다 · validate 13.7이 AppProject 정의 자체를 렌더에서 본다(나오는 자리 · `dev`/`prod` 꼴 — C31 〔R-2〕) |
| C18 | gr §validate.yml 8(:246 제목 · ① classify 판정 · :249 · :251 PR 템플릿 확인 항목) | :246 제목 「`apps/*/overlays/prod/**`를 건드린 PR은 …」 → 「운영 렌더(prod overlay · base · prod Application · AppProject 정의 · Argo CD 부트스트랩)를 건드린 PR은 …」 · ① 「변경 경로에 `apps/*/overlays/prod/`가 있으면 `need`」 → (사용자 결정 UD-14 2026-11-17과 그 보완) 변경 경로에 `apps/<pod>/overlays/prod`(자체 · 아래) · `apps/<pod>/base`(자체 · 아래) · `clusters/oci-k3s/apps/<이름>-prod.yaml`(`.yml` 포함 — 파일 이름 = Application 이름은 14.0) · `clusters/oci-k3s/projects`(자체 · 아래) · `bootstrap/argocd`(자체 · 아래) 중 하나가 있으면 `need`(경로 성분 단위 · 없으면 `skip` · 판정 실패 `need`). :249 「범위를 운영 overlay로 좁힌 대가(사용자 결정 D7) … 넓힐 수 있다.」 → T075부터 base 사본 · prod Application이 운영 렌더를 바꾸므로 넓혔다(UD-14 — D7 재확인) · 보완 = `projects` 전체와 `bootstrap/argocd`(prod AppProject를 바꾸는 다른 길) · 대가 = base 사본 · 프로젝트 · Argo CD 부트스트랩 PR마다 승인 한 번 · 봇 dev bump는 그대로 `skip`(VD-5 옵션 A 유지) · 받아들인 위험(report) — D23 · 편차 14와 같은 글: 「남는 관문 밖: `platform/**` · `platform-*` Application · `tests/` · `.github/` · 문서 · dev overlay · dev Application 변경 PR(받아들인 위험). `platform/**` · `platform-*` Application은 admin 등가다(argocd ns · AppProject · ClusterRoleBinding · jt-prod) — D7로 관문 밖이다. 이 길을 좁히는 검사(7.1 · 7.5 · 13.7 · 14.0 파일 결합)는 PR 코드라, 같은 PR에서 검사 코드를 고치면 지나간다(`tests/` · `.github/` 관문 밖).」 + 봇 토큰 머지 · 14.0 파일 결합을 끄는 예 〔VR-4 · R-2〕. :251 PR 템플릿 확인 항목 「운영 overlay를 건드렸으면 승인 관문을 승인했다」 → 「운영 렌더(①의 다섯 경로)를 건드렸으면 …」 〔VR-7〕 |
| C19 | dm:169 | 「판정 블록과 쓰기 블록의 분리 · `-cas` · JSON stdin · 인코딩 단위는 T075 운영자 블록이 정한다」 → 값 = CSPRNG 32바이트 → base64url(패딩 없음 · 43자 · `[A-Za-z0-9_-]`) · **HMAC 키 = 그 43자 문자열의 ASCII 바이트**(base64url을 디코드하지 않는다 · 끝 줄바꿈 없음 — django-common `auth.py` `hmac.new(secret.encode(), …)`) · T081 NotificationTransport도 같은 문자열을 디코드 없이 키로 쓴다 · 쓰기 = T075 W-2(`vault kv put "-cas=<n>" <path> -` · JSON stdin) · 판정 = O-3(다른 블록 — 두 블록은 조각 ④에서 생긴다 〔VR-16〕) |
| C20 | dl:59-65(VD-4 절) 끝 · dl:89(T051 줄) | :65 뒤 — UD-9 뒤 VD-4 근거는 행동 단언이다: data-assert `reader-get`(sample-pod `GET revoked:sub:assert-probe` → `probe` = `%R~` 키 패턴 적재) · `reader-set-denied`(→ `NOPERM sample-pod `) · identity-admin은 `ACL LIST`를 쓸 수 없다(@admin · @dangerous) · `acl-list`의 뜻 = 「identity-admin `ACL LIST` → `NOPERM identity-admin `」(id 유지 · B2 꼬리가 빠지면 FAIL하는 회귀 탐지기). :89 「`ACL LIST` 출력에 `%R~revoked:*` 존재(VD-4)」 → 「identity-admin `ACL LIST` → NOPERM(`acl-list` — 회귀 탐지기) · VD-4 = `reader-get` · `reader-set-denied`」 |
| C21 | qs:74 · :77 · §US6 끝(:124 「기대 테스트」와 빈 줄 :125 뒤 — §US7 머리 앞) | :74 `grep -A5 'ACL LIST'   # VD-4: …` → `grep -E 'acl-list\|reader-get\|reader-set-denied'   # acl-list = identity-admin ACL LIST → NOPERM(UD-9 회귀 탐지기) · VD-4 근거 = reader-get(probe) · reader-set-denied(NOPERM)` · :77 VD-4 문단 끝 — UD-9 뒤 판정 근거는 reader-get · reader-set-denied다. §US6 끝 새 블록 「배포 확인(T075 — dev · prod)」: ① 무헤더 `curl -s -o /dev/null -w '%{http_code}\n' https://identity-m2m-dev.joshuatech.dev/health` → Access 응답 코드(T075 실측값 — C11) ② tester-m2m 자격(env에서 stdin 헤더 `-H @-`로만)으로 `/health` → 출력은 본문 JSON(status ok · checks 셋 ok · `git_sha` = 배포 이미지 revision)과 끝 줄 `http=<코드> x-request-id=<값>`(curl `-w` · `%header` — 7.84 이상)뿐이다 · 응답 헤더를 통째로 내지 않는다(`-D` · `-i` · `-v` 금지 — `Set-Cookie: CF_Authorization`은 24h 자격 〔VR-12〕) ③ Secret `identity-admin-env` · `identity-admin-migrate`의 키 이름(관리자 kubeconfig · go-template 키 이름만 — `-env` 11 · `-migrate` 1 · 값 0). prod는 호스트만 `identity-m2m-prod` |
| C22 | ev:127 | 「(T075 VD가 클러스터 안에서 잰다 · T069 r5)」의 측정 자리 → 「T075가 운영 판의 로컬 실 브로커 — Kafka 4.3.1 KRaft · SASL_SSL SCRAM-SHA-512 · StandardAuthorizer ACL · 리눅스 컨테이너의 실제 relay 코드와 번들 librdkafka — 에서 쟀다(사용자 결정 UD-12)」(이전 문구 표식 · T069 r5 그대로). 같은 괄호의 결과 문장은 C10이다 |
| C23 | ia:21(1단계 Access) | :21 아래 새 하위 항목 〔VR-6〕 — (T084 인계 조건) aud는 호스트에 묶이지 않는다(aud ∈ {M2M, ADMIN}는 경로 · 호스트와 무관). 지금은 `common_name` 일치가 admin 앱 JWT(GitHub IdP — `common_name` 없음)를 막는다. T084가 admin 사람 경로에서 CN 요구를 풀 때는 host = `ADMIN_HOST`이고 aud = `ACCESS_AUD_ADMIN`일 때만 풀고, m2m 호스트는 aud = `ACCESS_AUD_M2M`만 받는다 |
| C31 | gr:234 뒤(§validate.yml 4 「(T047) 권한 경계」 목록 — 「역할 집계」 다음 · :235 「완전성은 저장소 루트에서만」 앞) · gr:239 아래(§validate.yml 6 sync-wave 검사) 〔R-2〕 | :234 뒤 새 항목 「AppProject」(validate 13.7): kind AppProject는 `clusters/oci-k3s/projects` 렌더와 그것을 base로 포함하는 `bootstrap/argocd` 렌더에만 나온다 — 다른 렌더면 실패(`platform` 프로젝트가 argocd ns에 쓸 수 있어 `platform/**` 렌더의 AppProject가 관문 밖에서 dev/prod 경계를 바꿀 수 있다) · 그 두 렌더의 `dev` · `prod` = §Application 규약 AppProject 행 그대로(`namespaceResourceWhitelist` 정확히 8종 · `namespaceResourceBlacklist` ⊇ 6종 · `destinations` 정확히 하나 · `clusterResourceWhitelist: []` · 허용 목록 중복 없음) · 이 항목은 부분 트리에서도 그대로 본다(:235 「완전성은 저장소 루트에서만」의 예외 〔S-2〕) · AppProject 없는 부분 트리만 대상 0. :239 아래 새 하위 항목 「Argo CD 자기 관리 경로」: `platform-argocd`의 `source.path` = `bootstrap/argocd` 하나(validate 7.1 — 이전에는 `platform/argocd`도 받았다) · `platform/argocd/kustomization.yaml` = 자리표시(최상위 키 정확히 {apiVersion, kind, resources} · `resources: []` — validate 7.5) · 까닭(두 파일 모두 관문 밖 — 검사 코드 변경 없이 AppProject · Argo CD 본체를 바꾸는 길이었다) · 이 검사도 같은 PR에서 고치면 지나간다(§validate.yml 8). D9 「계약이 먼저」에 따라 7.1 고침 · 7.5 · 13.7의 정본 문장을 둔다 |

### 〈조각 커밋〉 — C24–C30

| C | 파일:줄 | 고칠 것 | 조각 |
|---|---|---|---|
| C24 | bs §3 새 절 「T075」(T074 절 뒤 — §4 머리 :1035 앞) | PR 넷의 순서 · 관문 · 머지 선행(D1) · hook ES 운영 성질 넷(IR:455-461 요약) · 복구(늦은 시드 꼴 — §4 T056 :1379 · T054 :1187 · 전체 수동 Sync · terminate) · prod 노출 축소 규칙(D24) · 확인(D16 · D18) · 기록 칸. 그리고 bs:405(§3 T044 「git 밖 라이브 상태」의 옛 불변식 「sentinel 잔존 0」)에 표식 「T075 보정 — 지금 불변식은 vault-unseal §US6(면제 셋 밖 sentinel 0)」(검증 K2-6 〔VR-3〕) | ④ |
| C25 | bs §4 새 절 「T075」(T057 절 뒤 — §5 머리 :1673 앞) | kv 시드(O-2 · W-2 · O-3 — 「사전」 · 「실행」 · 「기대 출력」 · STOP 표 · 기록 칸) · Dragonfly ACL 재렌더(UD-9 — D20 적용 순서 · O-6 · W-6 · `ACL LOAD` · 실패 갈래 · 기록 칸). 그리고 bs:1037(§4 T044 요약의 옛 불변식 「sentinel 잔존 0」 · `preshared` US6 교체)에 C24와 같은 표식(검증 K2-6 〔VR-3〕) | ③ · ④ |
| C26 | bs:1444-1449 · :1461 · :1526 · :1624-1628 · :1667(§4 T057) | :1449 뒤 — 지금 규칙은 pod 사용자 줄에 B2 꼬리가 붙는다(렌더 정본 = T075 블록 · §4 T075). :1461 앞 — 이 블록은 옛 규칙(`+@all`)을 렌더한다 · UD-9 뒤 시드 · 재렌더 · 회전은 T075 블록 · 평시 실행하지 않는다(UD-9 되돌림 갈래만 · 사용자 확인 뒤). :1526 행 — 같은 꼴은 T075 블록에서 나온다. :1624-1628 「ACL 파일 갱신」 → 블록 = T075 블록 · 1단계 판별 줄 = 「op1 = 옛 판(`+@all`) — 실행하지 않는다(되돌림 갈래 제외 · 사용자 확인 뒤)」(D20과 같은 문구 〔VR-8〕) · 5단계 pod 삭제는 F12처럼 아무도 AUTH하지 못할 때만 — 규칙 변경은 admin `ACL LOAD` 먼저 · 재시작 금지(§4 T075). :1667 회전 → acl 재렌더는 T075 블록(T084 secret-rotation.md) | ③ |
| C27 | GP-1 gitops 문서 | G/tests/README.md: 3.9 · 7.5 · 13.7 · 14.0–14.8 설명 · 7.1 argocd 갈래(`bootstrap/argocd` 하나 〔R-2〕) · :52 · :66(관문 범위 = 넓힌 다섯(UD-14 · 보완) · 남는 관문 밖 = gr §validate.yml 8과 같은 글(목록 · admin 등가 문장 · 같은 PR의 검사 코드 변경 〔R-2〕) · 「T074에서 생긴다」 → T075가 만든다 · 소문자는 7.1 · 14.0이 본다) · :92(positive = Application 파일마다 하나 · identity-admin base = 모노레포 B/ 사본 — 14.0 · pod 표 〔R-3〕) · G/README.md:21(ruleset `prod-approval` 행의 「운영 overlay(`apps/*/overlays/prod/**`)」 · 「범위는 운영 overlay뿐이다」 → 넓힌 다섯 · 남는 관문 밖 = 같은 글) · G/clusters/oci-k3s/apps/platform-argocd.yaml:16-17 · G/platform/argocd/kustomization.yaml:9-11 · :14(「7.1은 … `platform/argocd`와 `bootstrap/argocd`를 모두 인정한다」 → `bootstrap/argocd` 하나 · 자리표시는 7.5가 본다 · 이 디렉터리를 쓰려면 계약(§validate.yml 6)을 먼저 고친다 〔R-2〕) · G/.github/pull_request_template.md:7(「운영 overlay를 건드렸으면」 → 「운영 렌더(prod overlay · base · prod Application · `clusters/oci-k3s/projects` · `bootstrap/argocd`)를 건드렸으면」 — gr:251과 같은 문구 〔VR-7〕) · :220(「T074·T115에서 실측」 → T115 · 브랜치 목록에 `promote/**`) · vsh 머리 주석(검사 목록) · vyml 머리 주석 :69-89 · classify 스텝 주석 · projects/dev.yaml:1-13 · prod.yaml:1-10(허용 목록 · argo-3 · 13.7 · 「T075가 만든다」) · G/README.md:36(T074 → T115) · :38-40(「뼈대 상태(T003)」 → 지금 상태) · platform/cnpg-databases/README.md:364-366(「+ app role 테이블 GRANT」 → pod 마이그레이션 `core/0001_app_role_grants`) · :376(`url` → username · password + 템플릿 조립) | ① |
| C28 | GP-A gitops 문서 · 검사 | platform/policies/tests/job-data-assert.yaml:131-141(② 판정) · README.md:86(acl-list 새 뜻 = 회귀 탐지기 · VD-4 = reader-get · reader-set-denied) · externalsecret-assert-data-env.yaml:30(「`ACL LIST` 조회용 — `+@all` 사용자」 → NOPERM 확인용 · B2 꼬리 사용자) · platform/dragonfly/externalsecrets-acl.yaml:16(형식 설명의 `+@all` → pod 사용자는 B2 꼬리) · platform/dragonfly/README.md §0 :92-93(규칙 줄) · :106(채널 — 실측 0 · `resetchannels`로 충분) · :107(「시드 블록이 렌더한다」 → T075 블록) · §1 :147 · :148 · :149(조치 열 → T075 블록 · admin `ACL LOAD` 먼저) · :152(dump 삭제는 재적용이 살아 있을 때만 — 신선도 값이 35 s 간격 두 번 전진) · §4 :263-266(B2 남는 위험 · 무인증 토큰 꼴 · 운영자 `MONITOR` 금지) · §5 :325(회전 → T075 블록) · §6 :354(채널 0 실측 — 인계 닫음 · 새 pod 줄도 B2 꼬리) | ③ |
| C29 | GP-2 gitops 문서 | apps/README.md:3(「실제 매니페스트는 T031+」 → identity-admin · base = 모노레포 사본 · 동기화 하네스 · 관문 대상) · overlays/dev 머리 주석 :1-4 · :8-9(자리 값 문장 → 실제 digest · 봇 bump · Application `identity-admin-dev`) · clusters/oci-k3s/apps/README.md:58(앱 행 표 — 파일 · 이름 · 경로 · project · 관문) · Application 머리 주석 둘(D7) | ⑤ |
| C30 | GP-3 gitops 문서 | overlays/prod 머리 주석 :1-4(사람 seed · promote ④ 전제 · admin Ingress · Middleware · 노출 축소 규칙 D24) | ⑥ |

### 〈실측 뒤〉 — C11–C16(마감 커밋)

C10(UD-12 결과)은 결과가 나와 〈설계 커밋〉으로 옮겼다(위 표).

| C | 파일:줄 | 고칠 것 |
|---|---|---|
| C11 | ha:26 · ha:7 | Access 무헤더 응답 = 실측 코드(401이면 「Access 401」) · T076 문면(403)과 다르면 report 편차 6 |
| C12 | gr:133 | 「`trimSuffix` — T075 라이브 확인」 → 결과(VD-T075-6) |
| C13 | dm:169 · :176 | 시드 기록(T075 · env별 버전 · O-3 PASS — 값 0) |
| C14 | IR:455-461 | hook 순서 · owner Secret 수명 · hook 삭제 시점(VD-T075-5)이 문장과 다를 때만 |
| C15 | vu:294-308 표 아래 | T075 덮어쓰기 기록(남은 sentinel 키 = 면제 셋 + `client_id` · `client_secret`) |
| C16 | ia:140 · ia:35 | ia:140 「(쿠버네티스 동작 — 실측 T075)」 → exec 탐침 결과(로그 0줄 · 시각) 〔CD-12〕 · ia:35 「T076 E2E 실측」 → CN = Client ID 첫 양성 = T075 O-5c(dev · prod `/session/check` 200) · T076은 음성(tester-m2m 403) |

---

## 5. 빌드 조각과 라이브 절차

### 조각

| 조각 | 내용 | 주체 | 끝 조건 |
|---|---|---|---|
| ⓪ | 설계 확정 · 〈설계 커밋〉 C1–C10 · C17–C23 · C31 · 검증 비판 → 이 문서와 함께 커밋(파일 이름 스테이징) | 컨트롤러 | 로컬 커밋. push는 사용자 확인 |
| ① | GP-1: vts RED → vsh GREEN(영향 사례만 반복 — 3.9 · 7.1 고침 · 7.5 · 13.7 · 14.0–14.8 · D9) · positive 재배치(Application 파일 분리 · base B/ 사본 · projects — R-3 · R-2) · AppProject 허용 목록 · classify + 자기 시험 · 문서 C27 · 리뷰 2렌즈 + 모노레포 argo-3 단언(라이브 RED 기록) | infra-builder(opus · 커밋 없음) | 로컬 vsh: GP-1 실트리 · GP-2 트리 PASS(대상 0 줄) · positive 트리 gitleaks no leaks(VR-14) · CI 자기검사 전체 초록 → 운영자 승인 · 머지(L5) |
| ② | 동기화 하네스 + run-all 슬롯 | 빌더 | RED 기록(지금 — gitops base 뼈대) |
| ③ | UD-9 모노레포(D20 목록 · 하네스 둘) + 독스트링 `outbox_relay.py:30` · :33-34(UD-12 결과 — D21 · 「약 1.5」 → 「약 2」) + W-6 · O-6 · 파생 하네스 + GP-A(C28) + C26 · C25의 UD-9 절 | 빌더 둘(모노레포 / 블록 · gitops) | D20 「조각 ③ 끝 조건」(VD-T075-17 포함) |
| ③′ | UD-12 로컬 실 브로커 측정(D21) — **끝 2026-11-17**(`wf_32816872-6d6` 측정 + 독립 반증) | 에이전트 둘(측정 · 반증) | 끝: M6 항목 기록 · M1 성립(relay 수정 · UD-1 재질문 없음) · bn 「T075 UD-12 결과」(컨트롤러) · C10을 〈설계 커밋〉으로 당겼다 |
| ④ | O-1 · O-2 · W-2 · O-3 · O-4 · O-5(a · b · c) + 모의 하네스 · C24 · C25 초안 | 빌더 · 컨트롤러 | 하네스 초록 · 리뷰 |
| ⑤ | GP-2 작성 · worktree 렌더 · vsh · 변이 · gitleaks → PR → CI · 렌더 코멘트 → (L6 · L7 · L8) → 승인 · 머지 → dev 확인 | 빌더 · 컨트롤러 · 운영자 | dev 게이트(VD-T075-5–11 · 15) |
| ⑥ | GP-3 작성 · attestation → PR → CI → W-2/O-3 prod → 승인 · 머지 → prod 확인 | 같음 | VD-T075-12 · 15(prod) |
| ⑦ | bn 「T075 결과」 · 런북 기록 칸 · 〈실측 뒤〉 C11–C16 · 동기화 하네스 GREEN(fetch 뒤) · run-all 1회 · tick · 학습 로그 `content/tmp/003-t075/<날짜>.md` · 커밋 · push(사용자 확인) | 컨트롤러 | — |

SP-1 절차 규칙을 따른다:
- 빌더는 opus로 고정하고, 빌더는 커밋하지 않는다. 컨트롤러가 파일 이름으로 스테이징한다.
- 머지 · 관문 승인 · 실행 승인은 운영자 전용이다.
- 머지 명령은 선행 조건의 출력을 받은 뒤에만 준다.
- 반복 중에는 영향 받는 사례만 돌리고, 전체 검사는 과제 마감에 한 번이다(종료 코드로 판정).

### 라이브 절차(관찰과 변경을 섞지 않는다 · 변경 단계마다 재확인)

| 단계 | 종류 | 주체(자격) | 내용 | 다음으로 가는 조건 |
|---|---|---|---|---|
| L0 | 준비 | 운영자 | 터널 · agent-view 토큰 · 창 규약(vu §0 — 모듈 로깅 · 클립보드 · 전사) | — |
| L1 | 관찰 O-0 | 컨트롤러(agent-view · GitHub GET) | 아래 목록 | 기대값 |
| L2 | 관찰 O-1 | 운영자(tofu 상태 자격) | CF 5값(D11) | 키별 PASS |
| L3 | 관찰 O-2 · O-4 | 운영자(Vault root · port-forward) | kv 판정 · `eso-prod` role · 정책(TTL 포함) | 기록과 일치 |
| L4 | 관찰 O-5a | 운영자(tester-m2m) · 컨트롤러(무헤더) | 배포 전 404 · 무헤더 코드(D16) | 기록 |
| L5 | 변경 → 관찰 | 운영자 → 컨트롤러 | GP-1 관문 승인 · 머지 → AppProject 허용 목록 라이브 · platform-argocd · root · argo-3(VD-T075-16) | PASS |
| L6 | 관찰 → 변경 → 관찰(dev → prod) → 변경 → 관찰 | 운영자 · 컨트롤러 | UD-9(D20 1–8): O-6 사전 → acl 삭제 · W-6 → ESO · kubelet → `ACL LOAD` → O-6 사후 → GP-A 머지 · Job 삭제 → data-assert | 7 id PASS(VD-T075-13) |
| L7 | 변경 W-2 dev | 운영자 | 쓰기 넷 | 되읽기 일치 |
| L8 | 관찰 O-3 dev | 운영자 | 게이트 | `gate=PASS`를 붙인다 |
| L9 | 변경 | 운영자 | GP-2 관문 승인 · 머지(L6 · L8 확인 뒤에 명령을 준다) | — |
| L10 | 관찰 | 컨트롤러(agent-view) · 운영자(traefik.io) | 아래 목록 + `tlsoption` · `tlsstore` default 각 1 · Traefik 로그 0줄 | VD 표 |
| L11 | 관찰 O-5b · O-5c · O-7 | 운영자 · 컨트롤러 | `/health` 게이트 · 양성 탐침 · UD-10 표본 · exec 탐침 · Secret 키 이름(값 0) · (선택) 신선도 키 35 s 간격 두 번 · (선택) m2m 호스트 404 넷 | 게이트 |
| L12 | 변경 W-2 prod → 관찰 O-3 prod | 운영자 | — | `gate=PASS` |
| L13 | 관찰 | 컨트롤러 | attestation verify(GET) · GP-3 렌더 코멘트 | 통과 |
| L14 | 변경 | 운영자 | GP-3 관문 승인 → 머지 | — |
| L15 | 관찰 | 컨트롤러 · 운영자 | prod VD · O-5b · O-5c prod · admin 정적 파일 200(운영자 브라우저) · 익명 → Access 리다이렉트 · `tlsoption` · `tlsstore` · Traefik 로그 | 게이트 |
| L16 | 관찰 | 컨트롤러 | 하네스(env-1 · limits · argo-1/3 · job-d-2) · 동기화 하네스(fetch 뒤) | PASS |

L1(O-0) 관찰 목록:
- Applications 22개 Synced/Healthy · AppProject dev/prod(허용 목록 없음 · 금지 6) · CSS 5
- jt-dev · jt-prod의 ES(CA 미러) · NP · RQ · LR · data의 DatabaseRole · Database · KafkaUser
- 라이브 판: K3s(노드 kubeletVersion) · Argo CD(application-controller 이미지) · Traefik 이미지 · 인자(`allowCrossNamespace` 유무) · Reloader 인자
- data-assert 최근 로그(7 PASS — 옛 꼴) · gitops 열린 봇 PR 0

L10 관찰 목록:
- root 폴링(≤ 180 s) → Application 둘 생성
- dev operation · hook 결과 · ES 2개 Ready · Job 성공 · pods Ready · 로그 · Synced/Healthy
- prod: 리소스 0개로 Synced/Healthy

블록과 명령의 자리:
- 블록은 `specs/003-platform-foundation/design/t075-blocks/`에 둔다: O-1 · O-2 · W-2 · O-3 · O-4 · O-5 · O-6 · W-6 + `harness.ps1` + README.
- O-7 · `ACL LOAD` · Job 삭제 · exec는 런북 명령 줄이다(관리자 kubeconfig를 명령에 직접 적는다 — IR:101-102). O-6 사후 DRYRUN은 런북 명령 줄 또는 블록이다(빌더가 정한다 — admin 비밀번호 argv 0 · D10).
- 쓰는 동작은 표의 「변경」 단계뿐이다. `rollout restart` · force-sync 어노테이션 · 수동 Sync는 실패 갈래(bs §3 T075 복구)에서만, 사용자 확인 뒤에 쓴다(D20 4단계의 `force-sync`는 예외 — ES 갱신 확인용).

관찰 명령 후보(모두 쓰기 0 · 값 비출력):

```powershell
# O-0 컨트롤러(agent-view · GitHub GET)
kubectl -n argocd get applications.argoproj.io -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status'
kubectl -n argocd get appproject dev prod -o custom-columns='NAME:.metadata.name,DEST:.spec.destinations[*].namespace,WL:.spec.namespaceResourceWhitelist[*].kind,BL:.spec.namespaceResourceBlacklist[*].kind'
kubectl get clustersecretstore -o custom-columns='NAME:.metadata.name,READY:.status.conditions[0].status'
kubectl -n jt-dev get externalsecret,networkpolicy,resourcequota,limitrange; kubectl -n jt-prod get externalsecret,networkpolicy,resourcequota
kubectl -n data get databaserole,database,kafkauser
kubectl get nodes -o custom-columns='NAME:.metadata.name,K3S:.status.nodeInfo.kubeletVersion'
kubectl -n argocd get sts argocd-application-controller -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}{.spec.template.spec.containers[0].args}{"\n"}'
kubectl -n reloader get deploy reloader -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}'
kubectl -n jt-dev logs job/data-assert --tail=50
gh pr list -R joshua92y/platform-gitops --state open --json number,author,headRefName
# O-4 운영자(Vault root · port-forward · 4키 가드 뒤 — 비밀 아닌 값)
$r = vault read -format=json auth/kubernetes/role/eso-prod | ConvertFrom-Json
$r.data | Select-Object bound_service_account_names, bound_service_account_namespaces, audience, token_policies, token_ttl, token_max_ttl
vault policy read eso-prod
# O-7 운영자(관리자 kubeconfig · 키 이름만)
kubectl --kubeconfig <관리자 kubeconfig> -n jt-dev get secret identity-admin-env identity-admin-migrate -o go-template='{{range .items}}{{.metadata.name}}:{{range $k,$v := .data}} {{$k}}{{end}}{{"\n"}}{{end}}'
kubectl --kubeconfig <관리자 kubeconfig> get middlewares.traefik.io,tlsoptions.traefik.io,tlsstores.traefik.io -A
```

O-1 · O-5는 명령 후보를 두지 않는다 — 비밀 경계(4키 가드 · 키별 정규식 · PASS만 출력 · stdin 헤더)를 블록과 하네스로 지킨다(D11 · D16). 초안의 O-1 후보(값을 판정과 무관하게 출력)와 O-5 후보(상태 코드만)는 버렸다 〔75A-7 · 75A-8 · 75B-6〕.

---

## 6. VD 목록

### T075 안에서 실측

| VD | 무엇 | 방법 · 주체 · 단계 | 합격선 | 어긋나면 |
|---|---|---|---|---|
| VD-T075-1 | 렌더 단언(VD-L15 — JSON6902 `op: test`) | 로컬 kustomize 5.8.1(dev · prod — 조각 ⑤ · ⑥) | dev 8 · prod 10 객체 · 전부 그 ns · 컨테이너 5개 `ghcr.io/joshua92y/identity-admin@sha256:` · prod ES 키 14개 `prod/` + store 둘 · ConfigMap = D5 표 · admin Ingress · Middleware는 prod만 · `op: test` 변이에서 렌더 실패 | 빌드 수정 |
| VD-T075-2 | vsh 전체 + 변이 셋 + gitleaks | worktree | PASS · 변이 셋 FAIL | 검사 · 패치 수정 |
| VD-T075-3 | GP-1 RED → GREEN · 실트리 | vts 영향 사례 → CI 전체 · 로컬 vsh(GP-1 실트리 · GP-2 트리) 〔CD-1〕 | 새 사례 FAIL → PASS · 기존 사례의 exit 코드 · FAIL 코드 단언 불변(픽스처 재배치 — positive Application 파일 분리 · base B/ 사본 〔R-3〕 · positive 수 단언 vts:187 · :204 두 줄만 고침 〔S-1〕) · 두 트리 PASS(14.x 대상 0 줄 · 7.1 · 7.5 · 13.7 PASS) | 검사 정정 |
| VD-T075-4 | 동기화 하네스 RED → GREEN | ② · ⑦ | GP-2 전 FAIL · 머지 · fetch 뒤 PASS · 두 커밋 출력 | 사본 재작성 |
| VD-T075-5 | hook 순서 · owner Secret 수명 · hook 삭제 시점(VD-L1 · D14) | Argo `operationState` · ES · Job · Secret 생성 시각(agent-view — 이름 · 시각만) | `-migrate` ES Healthy → Job Succeeded → Sync 단계 순서 · 재생성 · 상주 시간 기록 | C14 |
| VD-T075-6 | ES 2개 SecretSynced · `trimSuffix`(VD-L4) · 빈 dsn | ES Ready · migrate Job 성공 · `startup_check: OK` · O-7 키 이름 | 둘 다 Ready · `-env` 키 11 · `-migrate` 키 1 · `SENTRY_DSN` 키 있음 | gr:133의 대체안 |
| VD-T075-7 | 기동(VD-L2 · L3 · L5 · L6 · L12 GHCR pull · L18 · VD-T066-4 · VD-T071-3) | pods Ready · init 로그 retry 줄 수 · web 로그 `invalid_host` 0 · PSA 경고 0 | 전부 | 원인별 |
| VD-T075-8 | Kafka · relay 정상 경로(VD-L13 일부) · VD-L7(실제 Dragonfly의 Celery) · VD-T066-3(B2 아래) | `/health` kafka_producer ok · relay FATAL 0 · celery NOPERM 0 · 재적용 성공 줄 30 s마다 · (선택) 신선도 값 전진 | 전부 | ACL · transport |
| VD-T075-9 | `/health` 게이트 dev(D16) | O-5b(L11) — 블록의 PASS 줄 | D16 합격선 | — |
| VD-T075-10 | 무헤더 코드 · exec 로그(D18) | L4 · L11 | 기록(합격선 없음 — 결정 입력) | C11 · C16 |
| VD-T075-11 | `vault kv patch` 꼴 | W-2 실행(L7) | 되읽기 키 집합 5 · 두 값 글자 일치 · 나머지 셋 sentinel 보존 | 블록 정정 |
| VD-T075-12 | prod | L13–L15 | vault-prod 첫 로그인(ES 2개 SecretSynced) · 빈 prod Application → 배포 · O-5b PASS · **admin 라우터 양성**(운영자 브라우저 GitHub IdP `https://admin.joshuatech.dev/identity-admin/static/admin/css/base.css` → 200)〔CD-13〕 · 익명 → Access 리다이렉트 · `tlsoption` · `tlsstore` default 각 1(운영자) · Traefik 로그 `Default TLS Options defined in multiple` · middleware 오류 0줄(컨트롤러)〔CD-16〕 | role · 정책 · Middleware 이름 |
| VD-T075-13 | UD-9 B2 라이브(dev · prod) | L6 | `ACL LOAD` OK · O-6 사후 DRYRUN 표(D20) · data-assert 7 PASS(acl-list = NOPERM) · VD-T075-8의 NOPERM 0 | D20 실패 갈래 |
| VD-T075-14 | relay ACL(T069 M6) — 로컬 실 브로커(초안의 라이브 「가」 행을 대신했다)〔UD-12〕 | 조각 ③′ — **끝 2026-11-17**(측정 + 독립 반증 · D21) | (i)/(ii) · L · 간격 넷 · 회복 두 꼴 · 일부 토픽 변형 · 예외 꼴 기록 · M1 판정 → **결과 PASS(M1 성립)**: 갈래 (i)(`CLUSTER_AUTHORIZATION_FAILED` · GETPID 0줄) · L 0.517–0.554 s · 간격 2.0 · 3.0 · 6.0 · 12.0 s → … 600 s · 회복 (a) 마지막 치명 패스 + 300.07 s · (b) 592.0 s · 일부 토픽 = 행마다 `TOPIC_AUTHORIZATION_FAILED`(비치명) · 예외 꼴 표(D21) | 해당 없음 — relay 수정 · UD-1 재질문 없음. 경계(relay ↔ 브로커 왕복 +31–35 ms → 주기 약 2.5 s)는 §7 T097 |
| VD-T075-15 | O-5c 양성 탐침 · UD-10(dev · prod)〔CD-4〕 | L11 · L15 | 200 `{"active": true}` · `Cache-Control: no-store` · 400 표본 줄의 쿼리 유무 기록 | AUD · CN 값 · 팀 도메인 · ACL 원인별 |
| VD-T075-16 | AppProject 허용 목록 라이브〔CD-16〕 | L5(agent-view) | dev/prod 허용 목록 8 · 금지 6 유지 · platform-argocd Synced/Healthy · root 정상 · argo-3(고친 단언) PASS | GP-1 revert(G/bootstrap/README.md ⑧ 비파괴 복구 — 복구 명령 :207 〔VR-13〕) |
| VD-T075-17 | UD-9 최종 aclfile 로컬〔CD-22〕 | 조각 ③(운영 digest Dragonfly 컨테이너 · 가짜 비밀번호) | 기동 aclfile 오류 0 · 무인증 PING `-NOAUTH` · `ACL LOAD` OK · pod 사용자 `REPLICAOF NO ONE` · `SLAVEOF NO ONE` · `SAVE` · `CLIENT KILL` → NOPERM · 앱 경로 OK | W-6 정정 |

### 라이브로 넘김

| 항목 | 받는 곳 |
|---|---|
| VD-L8(keepalive · tcp_user_timeout) | T097 · T114 장애 드릴 |
| VD-L9(`/health` Exact · 글자 접두) | T076 |
| VD-L10(Reloader 실소비자) | T082 · T083의 첫 실제 Secret 교체 |
| VD-L11(Alloy 두 포트) | T098 |
| VD-L14(CSRF · 사람 admin) | T084 |
| VD-L17 · L19(preStop · 롤링 중 502 · SIGTERM) | T097 |
| VD-L16 · T068 잔여 셋 | report 이연(D19) |
| Dragonfly 재시작 뒤 로그아웃 로그(bn:4692) | T085 |
| Traefik ≥ 3.7.18 · ForwardAuth 권고 | T084 전제(D22) |
| aud ↔ host 결합(CN 완화 조건) | T084(C23) |
| data ns 외부 443 좁힘(barman-cloud 실행 주체 실측 먼저 · np:119 함께) | T097 / T116 |
| `-scan -dbsize` 실측(+ `RANDOMKEY` 등 다른 열람 경로) | T116 |

- VD-L7(실제 Dragonfly의 Celery — VD-T075-8) · L12(GHCR pull — VD-T075-7) · L15(JSON6902 `op: test` — VD-T075-1) · L18(VD-T075-7)은 위 표에서 닫는다(정의 t072-design.md:1193 · :1198 · :1201 〔VR-9〕).
- ESO Merge 소스 대조(bn:4261)는 R4 §2.3으로 닫았다(14.1 규칙에 반영).

---

## 7. 인계

| 받는 과제 | 넘기는 것 |
|---|---|
| T071(닫힘 — tasks:188 [X] · librdkafka stderr 원문 줄 결정 2026-11-05) | 줄 꼴 기록(UD-12 — D21): 부분 ACL에서는 패스마다 stderr NOTICE `%5\|<초>.<ms>\|PARTCNT\|identity-admin#producer-N\| [thrd:…]: Topic <토픽> (id …) partition count changed from 3 to 0`이 나온다 — T071 결정의 원문 줄 꼴(`%<수준>\|<초>.<ms>\|<fac>\|<이름>\| <메시지>`)과 같다. 닫힌 과제라 실제로 반영할 자리는 T098(Alloy 원문 수집) · T114(런북)다 |
| T076 | dev · prod가 떠 있다 · 무헤더 실측 코드(C11) · tester-m2m 자격 전달 경로(지금 Vault 미시드 — T077 시드를 앞당길지 T076 설계가 정한다) · **정정된 사실**〔CD-4〕: `/apix` · `/sessionsX`는 tester-m2m으로 **403 `access_required`**(미들웨어가 URL 해석 전에 판정 — dp §Auth)다 · Traefik 404는 m2m 호스트의 `/healthz` · `/ready` · `/webhooks/authentik` · `/admin/`다 · CN = Client ID의 양성은 T075 O-5c가 증명했다(T076의 tester-m2m 403은 음성일 뿐 — 초안의 「근거 L10의 403」은 지웠다) · `/session/check` 두 번 호출의 `cf-cache-status`(bn:4638) · `Set-Cookie: CF_Authorization`(bn:3196) · 생성 경로 편차(t072:1233) |
| T077 | `kv/platform/access/tester-m2m` 시드(이연을 풀 때) |
| T080 | `server.service.servicePortHttp: 9000` · identity → jt-* 8000(웹훅 svc DNS) |
| T081 | `AUTH_ACTOR_SUB`(VD-1) = overlay ConfigMap 패치(prod는 관문 · 14.4 표) · 웹훅 비밀은 판정만 하고 바꾸지 않는다 · **HMAC 키 = kv `secret` 43자 base64url 문자열의 ASCII 바이트 — 디코드하지 않는다 · 끝 줄바꿈 없음**(NotificationTransport 헤더 매핑이 디코드하면 모든 웹훅이 401)〔CD-9〕 |
| T082 | openfga 두 경로에 실값 → 두 overlay `JT_PLACEHOLDER_EXEMPT`에서 둘을 거둔다(prod 관문 · 14.4 표도 함께) · `preshared` = platform 값 · Reloader 롤아웃 첫 실측 |
| T083 | `api_token` 실값 → 면제에서 거둔다 · celery 생존 프로브 재결정(D13) |
| T084 | admin Ingress에 forward-auth Middleware(14.3 표의 `router.middlewares`도 함께) · CSRF · 사람 admin 경로 · admin 경로 둘(D6)을 넓힐지 · **CN 완화 조건**(host = `ADMIN_HOST`이고 aud = `ACCESS_AUD_ADMIN`일 때만 · m2m 호스트는 aud = `ACCESS_AUD_M2M`만 — C23)〔CD-28〕 · **Traefik ≥ 3.7.18 전제**(D22) · **회전 = 새 렌더 블록**(secret-rotation.md의 Dragonfly acl 재렌더는 T075 블록 — T057 op1이 아니다)〔CD-5〕 · owner 자격 회전(D14) |
| T085 | 끝 상태(값에 `PLACEHOLDER-` 0 · 면제 빈 값 — 키를 지울지 빈 값으로 둘지 · 14.4 표) · Dragonfly 재시작 뒤 로그아웃 로그 |
| T089 · T092 | BFF → m2m-dev: CN = web-bff-dev Client ID · AUD(O-5c가 증명) |
| T097 | 쿼터 실사용 · 롤링 502 · preStop · SIGTERM · keepalive · data ns 외부 443을 CNPG 인스턴스로 좁히는 platform PR 후보(barman-cloud 실행 주체 실측 먼저 · np:119 함께)〔CD-22〕 · 자기 접두 메모리 고갈(B2 남는 것) · **relay ↔ 브로커 왕복 지연 경계**(UD-12 — D21): 노드 간 배치 · 브로커 이전 때 왕복이 약 30 ms(실측 경계 31–35 ms)보다 충분히 작은지 본다 — 꾸준히 넘으면 지속 치명의 재생성이 약 2.5 s 주기에 머문다(M1 깨짐 · 분당 약 24회) |
| T098 | OTEL 엔드포인트 overlay 패치 · UD-10 결정(측정값) · celery 경보 · 운영자 `MONITOR` 금지(평문 비밀번호) · Traefik 액세스 로그 수집 · librdkafka stderr NOTICE `%5\|…\|PARTCNT\|…\| … partition count changed from 3 to 0` 줄 꼴(UD-12 — §7 T071 행 · 원문 수집 대상 〔S-3〕) |
| T114 | hook ES 운영 성질(bs §3 T075 → incident-response) · aclfile 기동 무인증 토큰 꼴 · **relay ACL 두 갈래**(UD-12 결과 — D21 · bn:1996의 「약 1.5」를 대신한다): ① Write 전무 = 치명 — 줄 꼴 stderr `%0\|…\|FATAL\|identity-admin#producer-N\| [thrd:main]: Fatal error: Broker: Cluster authorization failed: Failed to acquire idempotence PID …` + `outbox_relay.producer_fatal KafkaException kafka_error=CLUSTER_AUTHORIZATION_FAILED published=0 failed=0 dead=0`(행이 있으면 `ProducerFatalError … failed=N` · last_error `_PURGE_QUEUE`) · 유휴 재생성 약 2 · 3 · 6 · 12 … s → 상한 약 600 s ② 일부 토픽 = 행마다 `TOPIC_AUTHORIZATION_FAILED`(비치명) · 10회 뒤 DLQ(DLQ도 막히면 행이 남는다) · 패스마다 stderr NOTICE `PARTCNT … partition count changed from 3 to 0` 한 줄 〔S-3〕 · **InitProducerId 거부는 브로커 authorizer 로그에 0줄** — 진단 근거는 클라이언트 stderr FATAL 줄 · 필요할 때만 브로커 `kafka.request.logger=DEBUG`(진단 로거 — 25분에 약 690 KB · 상시 부적합) · **고친 뒤에도 `producer_fatal` 한 줄이 더 나올 수 있다**(고치기 전 프로듀서가 유지 대기를 마칠 때 · `published=0` — 「아직 고장」이 아니다) |
| T115 | prod 첫 항목(GP-3 seed) 위에서 promote 실연 · 봇 경로 출처 검증 |
| T116 | Renovate가 Dragonfly · kombu · redis-py · celery를 올릴 때 ACL 재측정(R5 §8 — `ACL CAT` diff + 탐침) · 템플릿 env 목록에 두 이름 추가(D9) · `-scan -dbsize` 후보(실측 먼저) · `eso-dev` · `eso-prod`에 `kv/data/{env}/access/*` · `kv/data/{env}/web/*` · `kv/data/{env}/dragonfly/admin`(+ metadata) deny 후보〔CD-27 · VR-11〕 · **SUC 채널은 14일 원칙을 지키지 않는다** — Plan `k3s-server`가 채널 v1.36으로 창에서 패치를 자동으로 올린다(G/platform/system-upgrade/plan-k3s-server.yaml:58 · 「컨트롤러 확인 필요」 ② 답): 채널 대신 판 고정(14일 지난 판을 PR로 올림) 등 갱신 규율을 정한다 · data ns 외부 443 좁힘(T097과 함께) · strictPrefixMatching · ESO 2.15 · Reloader v2 |
| SP-2 후보(bn:2064 — 「첫 유지 대기 하한(T075의 L이 0.8 s를 넘으면)」) | 검토 기준 판정(UD-12 — D21): T075 실측 L 0.517–0.554 s라 지금은 조건 밖이다. relay ↔ 브로커 왕복 지연이 약 +20 ms면 L 0.8 s에 닿는다(지연 주입 실측) — T097의 왕복 경계와 같은 측정으로 다시 본다 |
| 정비 단계(UD-13 — tasks.md 밖 · T075 뒤 · US4 전) | Argo CD v3.5.7 · K3s v1.36.6(Traefik 3.7.15) — 14일 원칙 · 스냅샷 3종 · 노드 순차 · bn · report 기록(D22). Argo CD PR은 `bootstrap/argocd`를 바꾸므로 승인 관문 대상이다(UD-14 보완). K3s 판은 O-0에서 먼저 기록한다(SUC가 이미 올렸을 수 있다) |
| UD-1 재질문 지점 | identity-admin 결함으로 이미지를 다시 발행해야 할 때 · D14 대안(deploy/base 변경)을 할 때. UD-12 결과로는 relay를 고치지 않는다(M1 성립 — D21) — 이 지점은 닫혔고, 독스트링 정정(조각 ③)은 다음 main 발행 때 실린다 |
| /finish | report 편차 후보 18 · 받아들인 위험 · 정비 단계 기록 · 학습 노트 증류 때 `content/tmp/003-t069/2026-11-05.md:28`의 「1.5 · 3 · 6 · 12초」는 UD-12 실측값 「2 · 3 · 6 · 12초」로 바로잡는다(학습 로그 자체는 그날의 기록이라 고치지 않는다 〔S-6〕) |

---

## 8. 사용자 결정

### 결과(2026-11-17)

| UD | 결정 | 반영 |
|---|---|---|
| UD-9 Dragonfly pod 사용자 ACL | **B2** — identity-admin `~revoked:* ~identity-admin:* +@all -@admin -@dangerous -client` · `<pod>` · sample-pod `%R~revoked:* ~<pod>:* +@all -@admin -@dangerous -client` | D20 · C9 · C20 · C21 · C26 · C28 |
| UD-12 relay ACL 실측 | **로컬 실 브로커**(Kafka 4.3.1 KRaft · SCRAM-SHA-512 · StandardAuthorizer ACL + 실제 relay 코드 · 번들 librdkafka + 로컬 Postgres) → 결과(2026-11-17 · 결정 기록 B5): 갈래 (i) · 간격 2 · 3 · 6 · 12 s · M1 성립 · relay 수정 · UD-1 재질문 없음 | D21 · C10 · C22 · VD-T075-14 |
| UD-13 Argo CD · Traefik 갱신 창 | **T075 뒤 · US4 전 정비 단계**(Argo CD v3.5.7 + K3s v1.36.6) · Traefik ≥ 3.7.18 = T084 전제 · T075는 GP-1 완화책으로 진행 | D22 · 편차 12 · 17 |
| UD-14 승인 관문 범위 | **넓힘**(D7 재확인) — need = prod overlay ∪ base ∪ `*-prod.yaml` ∪ `clusters/oci-k3s/projects/**` ∪ `bootstrap/argocd/**`(보완 2026-11-17 — 처음 결정의 `projects/prod.yaml`을 projects 전체로 넓히고 `bootstrap/argocd`를 더했다 · 「컨트롤러 확인 필요」 ③). R-2 뒤에도 범위는 그대로이고, 관문 밖 `platform-argocd` 경로는 검사로 좁혔다(7.1 고침 · 7.5 · 13.7) | D23 · C18 · C27 · C31 · 편차 14 |

**UD-9 함께 정한 것**
- ① 시점 = dev 첫 배포(GP-2) 전. LOAD가 끊을 연결이 0이고, VD-T066-3을 최종 ACL에서 한 번만 잰다.
- ② 범위 = 템플릿 `<pod>` · sample-pod · django-common conftest도 함께 바꾼다.
- ③ data-assert `acl-list` = 「identity-admin `ACL LIST` → NOPERM」(id 7 유지 · 회귀 탐지기). VD-4 근거는 행동 단언(reader-get · reader-set-denied)이다.
- ④ 새 렌더 블록 = aclfile 재렌더 정본(T057 블록은 `+@all` 고정 · 닫힌 과제 문서). 런북 · gitops README의 복구 · 회전 안내를 돌린다.
- ⑤ 계약 보정 + report 편차(spec:257 · tasks:146 · :155 · plan:208의 `+@all` 문자열).
- `-scan -dbsize`는 넣지 않는다(미실측 · `RANDOMKEY` 등 다른 열람 경로 미측정 → T116 후보).

| 안 | identity-admin 규칙 | 막는 것(실측) | 남는 것 |
|---|---|---|---|
| A 그대로 | `… +@all` | 없음 | 자기 패턴 넓히기 · 사용자 생성 · CONFIG SET · FLUSHALL · MONITOR 평문 비밀번호 · SORT GET · RM · CLIENT KILL/PAUSE · `%R~` 자가 해제 |
| B | `+@all -@admin -@dangerous` | 위 상승 전부(DRYRUN REPLICAOF · SAVE 포함) | CLIENT KILL · PAUSE · 키 이름 열람 |
| **B2(결정)** | B + `-client` | B + CLIENT 계열 | 키 이름 열람 · Lua(안의 명령은 다시 검사) · `SCRIPT FLUSH` · `FUNCTION FLUSH` · 자기 패턴 안 쓰기 · 삭제(30 s 재적용이 복구하는 것은 identity-admin의 `revoked:*` · 세션 하한 키뿐) · 메모리 고갈(dl §ACL ②와 같다 〔VR-9〕) |
| C | `-@all` + 명령 19개 + `@transaction` | 가장 많다 | — (명령 하나만 빠져도 워커 사망 — 판 올림마다 재측정 관문 필요) |

**UD-12**: 초안의 「가」(T075 dev 마지막 단계에서 KafkaUser Write 제거 PR → 측정 → 복구 PR)와 「나」(T114 이연) 대신 정했다. 라이브 변경 0 · dev 데이터 쓰기 0 · 운영자 일 0이고, 가정이 틀리면 relay 수정 → UD-1 재질문이다. 비판 75A-6은 이 결정으로 소멸했다. **결과(2026-11-17)**: 가정이 맞았다 — 갈래 (i) 치명 · 유휴 간격 2 · 3 · 6 · 12 s · M1 성립이라 relay를 고치지 않고 UD-1도 다시 여쭐 조건이 생기지 않았다(D21 · VD-T075-14). 경계는 relay ↔ 브로커 왕복 지연 약 31–35 ms다(§7 T097).

**UD-14**: 대안은 「D7 범위 유지 + T075부터 실효가 된 관문 밖 경로를 report 받아들인 위험에 적는다」였다. 넓힘을 골랐고, 봇 dev bump에는 영향이 없다. **보완(2026-11-17)**: 최종 설계가 올린 틈(「컨트롤러 확인 필요」 ③ — `projects/kustomization.yaml` patch · 다른 프로젝트 파일 · `bootstrap/argocd`가 prod AppProject를 바꿀 수 있다)을 보고 `clusters/oci-k3s/projects/**` · `bootstrap/argocd/**`를 더했다. 수정 라운드 확인 R-2 뒤에도 관문 범위는 그대로다(결정 기록 B6). 남는 관문 밖: `platform/**` · `platform-*` Application · `tests/` · `.github/` · 문서 · dev overlay · dev Application 변경 PR(받아들인 위험). `platform/**` · `platform-*` Application은 admin 등가다(argocd ns · AppProject · ClusterRoleBinding · jt-prod) — D7로 관문 밖이다. 이 길을 좁히는 검사(7.1 · 7.5 · 13.7 · 14.0 파일 결합)는 PR 코드라, 같은 PR에서 검사 코드를 고치면 지나간다(`tests/` · `.github/` 관문 밖).

### 다시 여쭐 것 · 운영자 전용 동작

- **UD-1 재질문**(bn:5125): T075에서 identity-admin 결함이 나와 이미지를 다시 발행해야 할 때 · D14 대안을 할 때. UD-12 결과(M1 성립 — D21)로는 relay를 고치지 않으므로 그 조건은 생기지 않았다. 지금 계획에는 main 발행이 필요 없다(이미지 `faf55a57…`가 있다 · 독스트링 정정은 다음 발행 때 실린다).
- **UD-10**(T098 전): 측정은 T075(D18)다. 결정은 T098 전에 여쭌다. **UD-11**(T081 전)은 T075 밖이다.
- **운영자 전용**(infra.md:39 · Credentials):
  - GP 머지 넷 · 관문 승인 셋(GP-1 · GP-2 · GP-3)
  - Vault 쓰기(W-2 · W-6 · acl 삭제) · tofu output · tester-m2m · web-bff curl
  - `ACL LOAD` · `ACL DRYRUN`(admin) · Job 삭제 · `kubectl exec` · traefik.io 조회 · admin 브라우저 확인

### 초안의 「컨트롤러 확인」 일곱 — 확정(CD-29)

D1(prod도 T075에서 배포) · D6(admin 경로 둘) · D7(예외 없음 · finalizer · prod prune false) · D9(+ CD-1 · 2 · 13 · 16 · 17 · 23 · 24 · 25로 확장) · D13(celery 프로브 없음 → T083) · D14(CD-20) · D19(T068 잔여 셋 report 이연).

---

## 9. 위험 · 확인하지 못한 것

### 위험

- **머지 순서 사고**(시드 전 머지 — T056 사례): 게이트 출력을 받은 뒤에만 머지 명령을 준다. 복구는 늦은 시드(bs §4 T056 :1379 · T054 :1187 꼴) + 전체 수동 Sync다.
- **vault-prod 첫 소비자**: 로그인이 실패하면 prod PreSync에서 멈춘다(dev와 무관). O-4(role · 정책 · TTL 읽기)로 가능성을 좁힌다.
- **hook ES가 Progressing에 갇힘**(ESO 정지): operation이 무기한 Running이다(시간 제한 0). terminate → ESO 복구 → 전체 수동 Sync로 푼다.
- **AppProject 변경의 자기 참조**: AppProject는 `platform-argocd`가 소유한다. 허용 목록의 오타는 앱 sync를 막을 뿐이지만, AppProject 스펙 자체가 깨지면 root · platform-argocd가 잠길 수 있다(bootstrap/argocd 머리 주석 :34-35) — GP-1 렌더 코멘트 · VD-T075-16 · 비파괴 복구(G/bootstrap/README.md ⑧ — 복구 명령 :207 〔VR-13〕).
- **비밀 탐지**
  - JSON6902 꼴은 gitleaks를 지나지만 GitGuardian(PR 검사 — required 아님)의 반응은 확인하지 않았다. 걸리면 오탐 처리는 운영자가 한다.
  - 같은 꼴로 들어온 진짜 비밀도 gitleaks를 지난다 — 14.2 · 14.4 · 14.7이 값 꼴과 kind Secret 0을 본다.
- **글자 접두 라우팅**: `/apix` 같은 경로가 pod까지 간다(마지막 방어 = Access JWT 403 · Django 404).
- **UD-9 적용 실패**: aclfile 토큰 오류가 있는 채로 재시작하면 기동이 무인증이 된다. LOAD를 먼저 하고, 재시작하지 않고, 줄을 허용 토큰과 글자 단위로 대조하고, 같은 렌더 꼴을 로컬에서 기동 · LOAD로 먼저 본다(VD-T075-17). `metadata delete` 뒤라 kv rollback은 없다(D20 실패 갈래).
- **운영자 `MONITOR`**: 모든 사용자의 비밀번호가 평문으로 흐른다.
- **celery beat 사망 무탐지**(D13) — T083 전에 다시 정한다.
- **dev 자동 배포**: T075 뒤로는 모노레포 main 발행마다 dev가 자동으로 바뀐다(VD-5 A). 기능 머지(/finish) 때 새 digest가 dev로 간다.
- **관문 밖 경로**(D23 · 편차 14): UD-14 보완으로 `clusters/oci-k3s/projects/**` · `bootstrap/argocd/**`는 관문 안에 들었다(「컨트롤러 확인 필요」 ③ 답). 관문 범위는 그대로다(R-2).
  - 남는 관문 밖: `platform/**` · `platform-*` Application · `tests/` · `.github/` · 문서 · dev overlay · dev Application 변경 PR(받아들인 위험). `platform/**` · `platform-*` Application은 admin 등가다(argocd ns · AppProject · ClusterRoleBinding · jt-prod) — D7로 관문 밖이다. 이 길을 좁히는 검사(7.1 · 7.5 · 13.7 · 14.0 파일 결합)는 PR 코드라, 같은 PR에서 검사 코드를 고치면 지나간다(`tests/` · `.github/` 관문 밖) 〔R-2〕.
  - 7.1 정정: 7.1은 지금 `platform-argocd`의 path로 `platform/argocd`도 받는다(validate.sh:2091-2092). 그래서 검사 코드를 고치지 않고도 `platform-argocd.yaml` · `platform/argocd/**`만 바꾼 PR이 AppProject · Argo CD 본체를 승인 없이 바꿀 수 있었다 — GP-1의 7.1 고침 · 7.5 · 13.7이 닫는다. 남는 예: 14.0 파일 결합을 끄고 prod Application을 `-prod`가 아닌 파일에 두는 PR · 같은 PR에서 7.1 · 7.5 · 13.7을 끄는 PR은 승인 없이 지난다 〔VR-4 · R-2 · S-5〕.
  - 관문 밖 dev overlay는 dev 자격 범위의 임의 실행이다(command · args · 볼륨) — 14.x가 지키는 것은 env 경계 · 호스트 · Vault 경로 · ES template · kind · 이미지 저장소다 〔R-6〕.
- **owner Secret 상주**(D14 · 편차 13) · **eso 정책 범위**(편차 15) · **data ns 외부 443**(편차 16) · **B2 남는 것**(편차 17).
- **범위 밖 권고**(D22): Argo CD v3.5.2의 critical 넷 · high 둘 · Traefik ≤ 3.7.17 권고 — 정비 단계 · T084 전제까지.
- **relay M1 경계**(D21): relay ↔ 브로커 왕복 지연이 꾸준히 약 31–35 ms 넘게 늘면(노드 간 배치 · 브로커 이전) 지속 치명의 재생성이 약 2.5 s 주기에 머문다(분당 약 24회). 지금은 클러스터 안 왕복이 1 ms 미만이라 해당하지 않는다 — T097이 배치를 바꿀 때 본다.
- **O-5c 자격**: 운영자 PC에서 prod BFF 서비스 토큰(`web-bff-prod`)을 쓴다 — 4키 가드 · stdin 헤더 · 변수 즉시 제거. Traefik 액세스 로그는 헤더를 버린다(defaultmode drop).
- **쿼터 surge**(추론): 두 Deployment가 함께 굴러도 한도 안이지만 실측 전이다.
- **공유 클론**: 작업 트리(87d223d)가 낡았다. 동기화 하네스는 `origin/main`만 보므로 컨트롤러의 fetch가 필요하다.

### 확인하지 못한 것

- 라이브 전부 — kv 상태는 기록 기준이다.
- 라이브 판(K3s · Traefik · Argo CD — SUC 채널이 이미 v1.36.6으로 올렸을 수 있다)과 Traefik `safeNaming` · `allowCrossNamespace` 인자.
- Cloudflare 조직의 strict service token 설정 · 무헤더 응답 코드.
- Traefik 액세스 로그의 요청 경로에 쿼리가 실리는지(UD-10 — bn:4635는 소스 기억이다).
- ESO가 빈 문자열을 그대로 전달하는지(추론: 전달한다).
- `vault kv patch` CLI 꼴(`-cas` · key=value · PATCH 방식).
- 빈 overlay Application이 Healthy인지(선례로 추론).
- `HookSucceeded` 삭제 시점의 라이브 동작(소스 판독만).
- Dragonfly 이미지에 `ls`가 있는지(D20 5단계).
- relay ACL 거동의 arm64 실행 · 실 Strimzi · 클러스터 왕복 지연(D21 「추론으로 남은 것」 — 판정 코드는 아키텍처 · 리스너와 무관 · Strimzi 1.2.0 인가 = 로컬 StandardAuthorizer DefaultDeny(소스 대조) · arm64 wheel의 librdkafka도 2.16.0).
- GitGuardian 반응 · kubeconform이 Middleware 스키마를 카탈로그에서 찾는지(추론).

---

## 10. 비판 처리

판정은 컨트롤러 결정(CD)과 사용자 결정(UD)을 따랐다. 「수용」은 지적과 고침을 받아들였다는 뜻이고, 「부분 수용」은 일부 수단을 쓰지 않았다는 뜻이다. 기각한 발견은 없다.

| 비판 | 심각도 | 판정 | 반영 자리 |
|---|---|---|---|
| 75A-1 14.x가 빈 · 뼈대 overlay에서 판정 미정 | medium | 수용 | CD-1 — D9 대상 없음 규칙 · vts 두 사례 · 로컬 PASS 기록 · VD-T075-3 |
| 75A-2 `<pod>-<env>` project · destination 무검사 | medium | 수용 | CD-2 — D7 · D9 14.0 APP-app · C2 |
| 75A-3 동기화 기준이 작업 트리 | medium | 수용 | CD-3 — D2(모노레포 origin/main blob · INFO 「발행 대기」 · 두 커밋 출력 · 흐름 UD-1) · C1 |
| 75A-4 T076 인계 오류 · AUD/CN 무검증 | medium | 수용 | CD-4 — D16(O-5c) · D18 · VD-T075-15 · §7 T076 · C16. UD-10 표본 자리는 「컨트롤러 확인 필요」 ① |
| 75A-5 UD-9 재렌더 · 회전 경로 누락 | medium | 수용 | CD-5 — D20(새 렌더 블록) · C20 · C21 · C26 · C28 · §7 T084 |
| 75A-6 dev pending 행 경로 없음 | medium | 소멸 | CD-6 — UD-12 = 로컬 실 브로커(D21) |
| 75A-7 O-5가 본문 · 헤더를 버림 | low | 수용 | CD-7 — D16 블록 안 판정 · 하네스 사례 · §5 |
| 75A-8 O-1 값 출력 · 정규식 | low | 수용 | CD-8 — D10 4키 가드 · D11 키별 정규식 · PASS만 출력 · 속성 단언 |
| 75A-9 HMAC 인코딩 단위 | low | 수용 | CD-9 — D10 · C19 · §7 T081 |
| 75A-10 「늦은 시드」 참조 | low | 수용 | CD-10 — D10(bs §4 T056 :1379 · T054 :1187) |
| 75A-11 독스트링 · 템플릿 하네스 | low | 수용 | CD-11 — D20 이미지 문장 · 조각 ③ 끝 조건 |
| 75A-12 ia:140 보정 누락 | low | 수용 | CD-12 — C16 |
| 75A-13 경로 허용 목록 · admin 양성 | low | 수용 | CD-13 — D6 · D9 14.3 · VD-T075-12 |
| 75A-14 GP-2 선행 · quickstart | low | 수용 | CD-14 — D1 · D10 순서 · C21 |
| 75A-15 gitleaks 근거 | low | 부분 수용 | CD-15 — §2.4 · C3(억제 없는 재현). gitleaks 부정 픽스처는 두지 않는다(tests/README 「비밀처럼 보이는 값」) |
| 75B-1 AppProject 금지 목록 6종뿐 | high | 수용 | CD-16 · CD-13 — D8 · C17 · D9 14.3 · 14.7 · argo-3 · VD-T075-12 · 16 |
| 75B-2 14.5가 helm · 쉼표 hook으로 우회 | high | 수용 | CD-17 — D9 14.5 허용 목록 · 14.0 둘째 겹 · 편차 12 |
| 75B-3 project · destination · overlay ns 무고정 | high | 수용 | CD-2 · CD-18 — D7 · D9 14.0 · C2 |
| 75B-4 관문 밖 경로가 실효 | medium | 수용 | CD-19 · UD-14 — D23 · C18 · C27 · 편차 14 |
| 75B-5 D14 근거(Reloader SA · 삭제 시점) | medium | 부분 수용 | CD-20 — D14(읽는 주체 · 소스 판독 · 받아들인 위험 · 14.1 ③ · VD-T075-5 · 인계). HookSucceeded 대안은 deploy/base 변경 = UD-1이라 보류 |
| 75B-6 O-1 · O-5 비밀 경계 | medium | 수용 | CD-8 · CD-21 — D10 · D11 · D16 · §5(명령 후보 버림) |
| 75B-7 REPLICAOF · data 외부 443 | medium | 수용(사실 정정) | CD-22 — D20 · VD-T075-13 · 17 · §7 T097/T116 · 편차 16. R5 표에 REPLICAOF(DRYRUN 「허용 → 거부」)가 있었다 — 「실측 목록에 없다」는 틀렸고, data ns 외부 443과 묶은 영향 분석은 새것이다 |
| 75B-8 재렌더 경로가 `+@all`을 되살림 | medium | 수용 | CD-5 — D20 · C26 · C28 |
| 75B-9 렌더 이미지 무검사 | medium | 수용 | CD-23 — D9 14.6 |
| 75B-10 권고 수 · 판 · 갱신 창 | medium | 수용 | CD-24 · UD-13 — D22 · D9 14.8 · 편차 12 · 17 |
| 75B-11 값 꼴 · Secret kind 0 | low | 수용 | CD-25 — D5 · D9 14.2 · 14.4 · 14.7 · C3 |
| 75B-12 prod prune false의 삭제 | low | 수용 | CD-26 — D24 · C2 · C24 · C30. prune 정책을 사용자 결정으로 올리는 안은 쓰지 않는다 |
| 75B-13 eso-prod 범위 · TTL | low | 수용 | CD-27 — O-4 투영 · 편차 15 · §7 T116 |
| 75B-14 aud ↔ host 결합 | low | 수용 | CD-28 — D5 · D6 · C23 · §7 T084. prod `ACCESS_AUD_ADMIN` 빈 값 안(편차)은 쓰지 않는다 |

### 컨트롤러 확인 필요

- ① **CD-4 「같은 요청으로 UD-10 측정」 — 전제가 원문과 다르다**: Traefik 액세스 로그는 상태 400–599만 남긴다(infra/bootstrap/traefik-config.yaml:188-189 `statuscodes: "400-599"` — 확인). 200 양성 요청은 로그에 남지 않으므로 그것만으로는 UD-10(4xx · 5xx 줄의 쿼리)을 잴 수 없다. 이 설계는 O-5c 블록에 같은 자격 · 같은 가짜 `sub` · `sid`로 `iat`만 깨뜨린 요청 하나(→ 400 `validation_error`)를 더해 UD-10 표본으로 쓴다(D18). tester-m2m 요청은 CD-4대로 무헤더 · 404 확인에만 쓴다.
- ② **UD-13의 K3s 단계와 SUC 자동 패치**: SUC Plan `k3s-server`는 채널 v1.36으로 창에서 패치를 자동으로 올린다(G/platform/system-upgrade/plan-k3s-server.yaml:58 — 확인). 라이브가 이미 v1.36.6일 수 있다. 이 설계는 정비 단계의 K3s 몫을 「O-0 판 기록 → 아직이면 스냅샷 3종 확인 뒤 창에서의 적용 · 노드 순차 확인」으로 적었다(D22). 14일 원칙은 SUC 채널이 지키지 않는다.
- ③ **UD-14 범위의 틈**: `clusters/oci-k3s/projects/kustomization.yaml`(다섯 파일을 나열 — patches를 더하면 prod 프로젝트가 바뀐다)과 `bootstrap/argocd/**`(projects를 base로 포함)는 `projects/prod.yaml`을 건드리지 않고 prod AppProject를 바꿀 수 있다. 또 `platform` 프로젝트의 destination에 `jt-prod`가 있어 관문 밖의 `platform-*` Application이 jt-prod에 쓸 수 있다(이미 알려진 converge 인계와 같은 뿌리). 이 설계는 UD-14의 집합을 그대로 두고 편차 14 · §9에 적었다. 넓힐지(`clusters/oci-k3s/projects/**` · `bootstrap/argocd/**`)는 사용자 재질문 거리다. 14.8의 경로 가둠(관문 디렉터리 최상위 kustomization 둘 — prod overlay · base — 의 경로 필드 전부: overlay = 같은 디렉터리 파일 + 정확히 `../../base` · base = 같은 디렉터리 파일 · 하위 디렉터리 금지 — 검증 뒤 VR-5로 넓히고 R-1로 하위 디렉터리를 닫음)은 앱 쪽 틈(관문 밖 디렉터리 · 파일을 끌어오는 overlay · base)만 닫는다.
- ④ **CD-2 「cluster-scoped 객체 0」의 판정 수단**: kustomize의 최상위 namespace 변환은 cluster 범위 객체에도 `metadata.namespace`를 찍는다(R4 §6.6). 그래서 ns 값으로는 판정할 수 없고 kind 표(내장 cluster kind + 저장소 렌더 CRD의 `spec.scope: Cluster`)로 판정해야 한다(D9 14.0). 14.7의 허용 목록도 같은 것을 막는다(둘째 겹).
- ⑤ **CD-16 「블랙리스트를 남길지는 빌더가 계약대로」**: 계약 문장(C17)을 이 설계가 쓰므로 여기서 정했다 — 금지 목록 6종을 둘째 겹으로 남긴다(허용 목록에 와일드카드가 들어오는 실수를 막고, argo-3은 단언 하나를 더하기만 한다). 지우려면 C17 · argo-3 문장만 바꾼다.
- ⑥ **D20 실패 갈래의 T057 op1**: CD-5는 op1에 「옛 판 — 실행하지 않는다」 판별 줄을 둔다. 이 설계는 `ACL LOAD`가 실패하고 W-6 정정이 늦을 때만 op1(라이브에서 형식이 검증된 옛 규칙 렌더)을 되돌림 수단으로 허용했다(`metadata delete` 뒤라 kv rollback이 없다). 판별 줄 문구에 「되돌림 갈래 제외」가 붙는다(C26). 원치 않으면 그 갈래를 「W-6 정정까지 재시작 요인 보류」 하나로 줄인다.

**컨트롤러 답(2026-11-17)**(결정 기록 B4)
- ① 받아들인다. Traefik 액세스 로그는 400–599만 남긴다(traefik-config.yaml:188-189). 그래서 UD-10 표본은 O-5c의 `iat`를 깨뜨린 400 요청이다(D18 · VD-T075-15).
- ② 받아들인다. SUC Plan 채널 v1.36이 창에서 패치를 자동으로 올리므로 K3s 판은 O-0에서 먼저 기록한다(D22). 14일 원칙은 SUC 채널이 지키지 않는다 — T116에 넘긴다(§7 T116).
- ③ UD-14 보완(사용자 결정 2026-11-17)으로 해결했다. classify `need`에 `clusters/oci-k3s/projects/**` · `bootstrap/argocd/**`를 더했다(D23 · C18 · C27 · §8). 남는 관문 밖: `platform/**` · `platform-*` Application · `tests/` · `.github/` · 문서 · dev overlay · dev Application 변경 PR(받아들인 위험). `platform/**` · `platform-*` Application은 admin 등가다(argocd ns · AppProject · ClusterRoleBinding · jt-prod) — D7로 관문 밖이다. 이 길을 좁히는 검사(7.1 · 7.5 · 13.7 · 14.0 파일 결합)는 PR 코드라, 같은 PR에서 검사 코드를 고치면 지나간다(`tests/` · `.github/` 관문 밖). (편차 14 · §9 · R-2 — 관문 범위는 그대로다)
- ④ 받아들인다. cluster 범위 판정은 kind 표다(D9 14.0 · 14.7 둘째 겹).
- ⑤ 받아들인다. 금지 목록 6종을 둘째 겹으로 남긴다(C17 · argo-3).
- ⑥ 받아들인다. op1은 되돌림 갈래 전용이고 사용자 확인 뒤에만 돈다. 판별 줄 문구는 「op1 = 옛 판(`+@all`) — 실행하지 않는다(되돌림 갈래 제외 · 사용자 확인 뒤)」 하나다(D20 · C26 — 되돌림 단계는 D20 실패 갈래 ②).

### 검증 처리(K1 · K2 → VR-1–VR-16 · 집중 확인 → R-1–R-6 · 2026-11-17)

판정은 결정 기록 B4(VR-1–VR-16)와 B6(R-1–R-6 — 수정 라운드 1 집중 확인 `recheck-r1.json`)을 따랐다. 반영 자리의 계약 줄은 작업 트리 기준이고, 모든 반영에 「T075 보정 2026-11-17」 표식이 있다. 결정과 발견의 고침이 다른 곳은 결정을 따랐고, 결정이 원문과 다른 곳 · 결정 밖에서 좁게 더한 곳은 행 끝에 적었다.

| 발견 | 심각도 | VR · R | 반영 자리 |
|---|---|---|---|
| K1-1 「대상 없음」이 14.1 · 14.3 · 14.6까지 꺼짐 | high | VR-1 | D9 대상 없음 규칙(14.2 · 14.4에만 · pod 템플릿 객체 6종 · 표 밖 pod의 비어 있지 않은 렌더 FAIL) · D9 14.2 · 14.3 · 14.4 · 14.6 행 · vts 사례 셋 · gr §validate.yml 3 「대상 없음」 · 14.x 행 · C4. 14.3에 「ConfigMap이 없는데 Ingress가 있으면 FAIL」을 더했다. 14.6 대상은 VR-1의 정의에 맞춰 6종으로 넓혔다 |
| K1-2 14.3 admin에 class · entrypoints · tls · backend 없음 | medium | VR-2 | D9 14.3(이름 분류 · 공통 조건 · admin 고유) · D6 · gr 14.3 행 · C4 · 픽스처 ing-admin-entrypoint-web. 옛 「prod에서 `<pod>-strip` 하나가 아님」(존재 요구)은 「admin Ingress가 있는데 같은 렌더에 Middleware가 없음 · 이름 · 둘 이상」으로 바꿨다(빈 prod overlay PASS 유지) |
| K1-3 vu 게이트 2 줄이 C8 뒤 낡음 | medium | VR-3 | vu:335(보정 전 :329) · §4 C8. bs:405 · :1037 표식은 C24 · C25 |
| K1-4 관문이 파일 이름에 기대는데 결합 검사 없음 | medium | VR-4 | D9 14.0(파일마다 문서 1 · kind Application · 이름 = 파일 이름 · `*.yaml` · `*.yml`) · positive 분리(identity-admin 둘 — R-3에서 `platform-apps.yaml` 22파일 분리 · base B/ 사본을 더했다) · 픽스처 둘 · D7 · D23 · gr:31(C1) · gr 14.0 행 · 편차 14 · §9(같은 PR의 검사 코드 변경 = D7 받아들인 위험) |
| K1-5 14.8이 patches path 등을 묶지 않음 | medium | VR-5 | D9 14.8(경로 받는 필드 전부 · overlay = 같은 디렉터리 파일 + 정확히 `../../base` · base = 같은 디렉터리 파일 — R-1에서 「그 아래 포함」을 지워 하위 디렉터리를 금지했다 · helmCharts · secretGenerator 금지 · tests는 원격 ref 금지만) · gr 14.8 행 · D22 · 편차 12 · §10 ③ 끝 문장 |
| K1-6 §4 자리 · 범위가 diff와 다름 | low | VR-6 | §4 C1(replicas 뺌) · C4(:196 뒤 · 제목) · C5(ha:8 아래 · ia:10 · pt:19 앞부분) · C6(preshared 괄호) · C9(③ 근거 문장) |
| K1-7 UD-14 문구가 남은 곳 셋 | low | VR-7 | C18(gr:251 PR 템플릿 확인 항목 — 작업 트리에서 고침) · C27(G/README.md:21 · G/.github/pull_request_template.md:7) · D23 |
| K1-8 번호 재량 문장 ↔ 계약 「D9의 것」 | low | VR-6 | D9 머리(번호 · 이름 = D9 정본 · 재량 문장 삭제) · D14(「3.5 보강으로 구현해도 된다」 삭제) |
| K1-9 op1 판별 문구 · 되돌림 절차 · W-6 판정 | low | VR-8 | D20 W-6 판정(B2 꼬리 없으면 STOP · 렌더 줄 단언) · 실패 갈래 ②(단계 · 사용자 확인 뒤) · 안내 돌리기 문구 · C26 · 위 답 ⑥ |
| K1-10 교차 참조 · 목록 누락 넷 | low | VR-9 | ① §6 VD-T075-1(L15) · 7(L12) · 8(L7) · 닫는 줄 ② §8 B2 행 · 편차 17 ③ D10 「(C25 · C13)」 ④ D9 14.0 · gr 14.0 행 `metadata.namespace` |
| K2-1 대상 없음 범위로 호스트 점유 · 외부 이미지 우회 | high | VR-1 | K1-1과 같다. 쓰지 않은 수단: 14.0 「`<pod>` ∈ pod 표」(표 밖 pod의 렌더 FAIL과 7.1 이름 ↔ 경로로 같은 효과) · 14.8 「`../../base` 정확히 한 번 포함」(결정 밖) |
| K2-2 값 꼴 단언이 일부 키뿐 — env[] · 둘째 ConfigMap · 키 집합 | medium | VR-10 | D9 14.1 ④ · 14.2 · 14.4 · pod 표(ConfigMap · `envFrom` · `env[]`) · D5(나머지 키 정확 값 · 키 17) · gr pod 표의 ConfigMap 표 · `envFrom` · `env[]` 표 · gr:184(C3) · C4. 결정 문면 「migrate Job은 + `<pod>-migrate`」는 base(migrate-job.yaml:92-94 — `envFrom` = Secret `-migrate` 하나)와 달라 base를 따랐다. 덮어쓰기 금지에 「ConfigMap 키 ∩ ES template 키 = ∅」를 더했다(뒤 `envFrom` 출처가 앞을 덮는 같은 길) |
| K2-3 ES `remoteRef` 무고정 | medium | VR-11 | D9 3.9(렌더 ES 이름 ∈ 둘 · store · `data[]` 정확 일치) · pod 표 ES · D4 · gr ES 표 · gr:184(C3) · 편차 15 · §7 T116(`dragonfly/admin` deny 후보). 3.9를 골랐다 — 대상 없음 규칙 밖이라 pod 템플릿 객체가 없어도 본다 |
| K2-4 qs ②가 응답 헤더 전부 출력 | medium | VR-12 | qs ②(`-w` · `%header` · 헤더 통째 출력 금지) · D16(허용 목록 헤더 · Set-Cookie = 자격 · 하네스 사례) · C21 |
| K2-5 「G/README.md ⑧」 오기 | medium | VR-13 | §2.1 · VD-T075-16 · §9 → G/bootstrap/README.md ⑧(:173 · :207) |
| K2-6 vu 게이트 2 줄 · bs 옛 불변식 | medium | VR-3 | K1-3과 같다 + C24(bs:405) · C25(bs:1037) 표식 |
| K2-7 positive 0 값이 dev = prod | medium | VR-14 | D9 진행 방식(dev `0`… · prod `1`… · prod AUD_ADMIN `2`… · gitleaks 확인) |
| K2-8 「파일 하나 = Application 하나」 무검사 | medium | VR-4 | K1-4와 같다 |
| K2-9 14.3 분류 기준 없음 · admin 조건 | medium | VR-2 | K1-2와 같다 + 픽스처 ing-third-name. 쓰지 않은 수단: 어노테이션 키 집합 닫기(결정 밖) |
| K2-10 C4 자리 · 번호 재량 · gr:256 소요 시간 | low | VR-6 | §4 C4 · D9 머리 · §2.1(3분 48초 · 추론) |
| K2-11 14.8 base components · bases 열림 | low | VR-5 | K1-5와 같다(base도 자기 디렉터리로 가둔다) |
| K2-12 D20 목록의 `+@all` 문장 셋 누락 | low | VR-15 | D20(템플릿 `test_outbox.py.jinja:27` · identity-admin `tests/test_outbox.py:26` · IR ⑪ :582) · 이미지 문장에 README 표 |
| K2-13 보정 문장의 작은 부정확 셋 | low | VR-16 | dl:60(재적용 복구 범위) · ia:10 둘째 칸(`/identity-admin/static/…`) · gr:53 · vu:312 · dm:168 · :169(아직 없는 대상에 「T075 조각 ④에서 생긴다」) · §4 C2 · C5 · C6 · C8 · C9 · C19 |
| R-1 14.8 「자기 디렉터리(그 아래 포함)」이 하위 디렉터리의 중첩 kustomization · Component로 관문 밖 `overlays/dev/**`를 끌어오게 둠(VR-5 부분) | medium | R-1(가) | D9 14.8(overlay = 같은 디렉터리 파일 + 정확히 `../../base` · base = 같은 디렉터리 파일 · 하위 디렉터리 금지) · 픽스처 prod-nested-component-from-dev · base-nested-from-overlay · gr 14.8 행(끝 문장도 실제 규칙과 같게 — 「prod overlay · base의 렌더가 관문 안 파일로만」) · C4 · §10 ③ 끝 문장 · VR-5 행. 「나」(하위 kustomization까지 가둠)는 쓰지 않았다 — GP-3 · base 9파일에 하위 디렉터리가 필요 없다 |
| R-2 「7.1 = `platform-argocd` 경로 고정」은 틀림 — 7.1이 `platform/argocd`도 받아 관문 밖 두 파일만으로 AppProject · Argo CD 본체를 바꿀 수 있음 · 받아들인 위험 문장이 좁고 문서마다 목록이 다름 | medium | R-2 | 관문 범위는 그대로(UD-14 + 보완 — recheck의 재질문 후보 ① classify 넓힘은 쓰지 않았다). GP-1 검사 둘: 7.1 고침(argocd 갈래 = `bootstrap/argocd` 하나) + 7.5 WAVE-argocd-placeholder · 13.7 RBAC-appproject(D9 표 · D9 머리 · D1 GP-1 행 · 계약 C31 — D9 「계약이 먼저」 · C17 줄 끝). 받아들인 위험 문장 · 남는 관문 밖 목록을 같은 글로: D23 · 편차 14 · §8 UD-14 · 답 ③ · §9 · gr §validate.yml 8(C18) · C27. 7.1 틀린 문장 정정(D23 · §9) · §2.1 사실 줄. 결정 밖에서 좁게 더한 것: 13.7의 `clusterResourceWhitelist: []`(계약 「cluster 리소스 금지」를 「계약과 정확히 같다」의 일부로 읽었다) · positive 트리의 projects(통과 갈래) · C27의 `platform-argocd.yaml:16-17` · `platform/argocd/kustomization.yaml:9-11` · `:14` 주석 정정. 닫지 않은 것: AppProject의 다른 키(`sourceNamespaces` · `roles` 등)는 정확 일치 밖이다(결정 밖) |
| R-3 14.0 파일 결합이 positive `platform-apps.yaml`(22문서)도 FAIL — positive base도 pod 표 정확 일치에 걸림(VR-4 부분) | medium | R-3 | §2.1 · D9 진행 방식(positive `platform-apps.yaml` → `platform-<c>.yaml` 22파일 — identity-admin 분리와 같은 커밋 · positive `apps/identity-admin/base` = B/ 9파일 사본) · VD-T075-3(「기존 사례 불변」 → 「exit 코드 · FAIL 코드 단언 불변(픽스처 재배치)」 — positive 수 단언 vts:187 · :204 두 줄은 고친다 〔S-1〕) · VR-4 행 · C27(G/tests/README.md:92 positive 설명). 새 검사에도 걸리는 다른 부정 픽스처(`fmt/dirsource`의 `platform-apps.yaml` → 14.0 · `fmt/appset`의 `platform/argocd` → 7.5)는 단언이 자기 코드 줄만 보므로 고치지 않는다 — 빌더가 영향 사례로 확인 |
| R-4 14.1 ④가 표에 없는 컨테이너의 기준을 정하지 않음 · D9 ↔ gr 문구 다름 | low | R-4 | D9 pod 표 `envFrom` · `env[]` 행 · 14.1 ④(표에 없는 (워크로드, 컨테이너)의 `env[]` 이름 = ∅ · `envFrom` = Job `<pod>-migrate` 안이면 [Secret `<pod>-migrate`] · 밖이면 [ConfigMap `<pod>-config`, Secret `<pod>-env`]) · gr pod 표 `envFrom` · `env[]` 줄 · gr 14.1 행 · C4 · 픽스처 env-sidecar-extra |
| R-5 14.4 「dev = prod — env 맞바꿈」은 맞바꿈을 잡지 못함 | low | R-5 | D9 14.4 · gr 14.4 행(「dev = prod(같은 값 복사) — 맞바꿈은 O-5c가 잡는다」) · C4 · 픽스처 val-env-swap → val-env-same |
| R-6 3.9가 ES `target.template` · `data[]` 항목의 다른 키를 고정하지 않음 · 관문 밖 dev overlay의 임의 실행 범위가 기록되지 않음 | low | R-6 | 둘 다: D9 3.9 · gr 3.9 행(`target.template` = 같은 트리 base 그대로 — 키 집합 · 값 글자 · `data[]` 항목 키 = {`secretKey`, `remoteRef`{`key`, `property`}}) · 픽스처 es-app-template-host · es-app-item-sourceref · C4 · 편차 14 · §9(「관문 밖 dev overlay = dev 자격 범위의 임의 실행(command · args · 볼륨) — 14.x가 지키는 것은 env 경계 · 호스트 · Vault 경로 · ES template · kind · 이미지 저장소」) · D9 「넣지 않는 것」에 overlay 패치 한 줄(PSA restricted) |

**마지막 확인(수정 라운드 2 뒤 · low 6 — 컨트롤러가 직접 고침 · 2026-11-17)**

| 발견 | 처리 |
|---|---|
| S-1 「기존 사례 기대값 불변」이 positive 수 단언 두 줄과 어긋남 | D9 진행 방식 · VD-T075-3 · R-3 행 — exit 코드 · FAIL 코드 단언은 그대로 · vts:187 · :204 두 줄만 고친다 |
| S-2 gr 13.7 항목이 「완전성은 저장소 루트에서만」에 묶여 부분 트리에서 느슨하게 읽힘 | gr AppProject 항목 · C31 — 부분 트리에서도 그대로 본다(예외) · 허용 목록 중복 없음 |
| S-3 PARTCNT 줄 꼴 인계가 받는 행에 없음 | §7 T098 · T114 행에 더함 |
| S-4 독스트링 줄 번호 오기(:32-33) | D20 · D21 · §5 ③ — :33-34(가정 문장 :32-34) |
| S-5 남는 예시가 7.5를 빠뜨림 | D23 · §9 예시 — 7.1 · 7.5 · 13.7 |
| S-6 T069 학습 로그의 「1.5 · 3 · 6 · 12초」 | §7 /finish 행 — 노트 증류 때 정정(학습 로그는 고치지 않는다) |
