# T077–T079 설계 — US4 시험 먼저(Playwright 로그인 · 세션 폐기 · 플랫폼 신원 하네스) · 자격 없이 빨강(T077-a)

- 상태: **확정(2026-11-23 — 빌드 전)** = r2(r1 대조 검증 V-1–V-11 · A-2 · B-2 · B-14 반영 · 비판 A · B · 사용자 결정 T077-a–f) + 컨트롤러 보정(r2 재대조 N-1–N-5 — 「(컨트롤러 — N-n)」 표식). 경과: 초안 r0(`wf_62857a17-17f`) → r1(`wf_017fdc40-48a`) → r2(`wf_874c655b-42c` — 재대조 14/14 resolved · approve_with_fixes) — 보고 `.superpowers/t077/design/`. 과제가 닫힌 뒤에는 이 문서를 고치지 않는다(`.claude/rules/specs.md`). 빌드 리뷰 · 실측에서 달라진 점은 끝의 「정정 노트」에 덧붙인다.
- 입력: 조사 R1 · R2 · R3(`.superpowers/t077/research/{spec-contract,e2e-harness,cred-path}.md` — 인용 꼴 〔R1 ②-5〕) · 비판 A(정합 · 실행 — A-1–A-17) · B(자격 · 보안 — B-1–B-14)(`.superpowers/t077/design/critique-{A,B}-r0.md`) · r1 대조 검증(`.superpowers/t077/design/verify-r1.md` — V-1–V-11 · partial A-2 · B-2 · B-14)(r2) · 컨트롤러 결정 문서 `.superpowers/t077/decisions-controller.md` · 형식 선례 `design/t076-design.md`. 기준 = 모노레포 HEAD `f7ea46d`.
- 표기: 「추론」 = 실측 전 판단(§3 VD로 넘긴다) · 〔77-n〕 = report.md 편차 후보(§1-4) · 「(r1 — A-n · B-n)」 = 비판 반영 자리 · 「(r2 — V-n)」 = r1 대조 검증 반영 자리 · 「(T077-x)」 = 사용자 결정 반영 자리.
- 과제(tasks.md :210 · :211 · :212, 문면 그대로):
  - **T077**: 「`e2e/auth.spec.ts`(Playwright, 로컬 사용자 `e2e@joshuatech.dev` — 비밀번호·TOTP 시드는 Vault **`kv/platform/authentik/e2e`**(role `e2e-reader` — T044)에서 실행 직전 env로, GitHub 테스트 계정 없음·운영자 개인 자격 금지): `auth.joshuatech.dev` → 이메일/비밀번호 → TOTP → 사용자 설정 Sessions에 세션 1건; storageState `e2e/.auth/`(gitignore, 실행 후 삭제), trace `mask` — FAIL 확인; 소셜 로그인(US4 AC1)은 운영자가 브라우저로 1회 수동 검증하고 스크린샷을 tester 보고에 첨부」
  - **T078**: 「`tests/platform/identity.tests.ps1`: web-bff 토큰(`e2e/.auth/`의 Playwright 저장 토큰 — 로컬 사용자 `e2e@joshuatech.dev`, 실행 후 삭제)으로 RFC 8693 교환 → `aud=identity-admin`·`tenant_id`(uuid)·`exp-iat=300`(기본 = impersonation 교환이라 발급 토큰에 `act`가 없어도 PASS이고, `act.sub` 단언은 VD-1이 옵션 A로 확정된 경우에만 켠다 — T081); `audience=portfolio-core` → `invalid_target`; **OpenFGA 단언은 자격이 필요하므로 클러스터 안 Job 로그로 읽는다** — `kubectl -n jt-dev logs job/authz-assert`: `check user:<sub> member tenant:<uuid>` allowed, `check user:<sub> owner tenant:<uuid>` allowed(모델상 `owner` ⊂ `member`이므로 owner는 member 검사도 통과), **다른 테넌트 object에 대한 두 관계 모두 false**; `admin.` 헤더 없이 403; **Access 경계**: `auth.joshuatech.dev/if/admin/` 무헤더 302/403(Access 앱 `auth-admin`은 `/if/admin/*`만 보호), `/api/v3/flows/executor/<login-slug>/`·`/api/v3/root/config/` 무헤더 **200**(로그인 SPA가 브라우저에서 부르는 공개 경로 — 보상 통제는 `platform-admin` WebAuthn·서비스 계정 권한 한정·Reputation·Rate Limiting), `/application/o/*`·`/.well-known/*` 공개 200; `argocd --sso` 로그인과 Authentik 관리 API 접근 확인은 **운영자 수동 + 스크린샷**(tester 자격으로 자동화하지 않는다 — R30) — FAIL 확인」
  - **T079**: 「`e2e/revocation.spec.ts`: 로컬 사용자 `e2e@joshuatech.dev` 로그인 → access 토큰 확보 → `POST /api/auth/logout`(BFF 경유 — **T094 도메인 전환 이후 재실행하는 2단계 단언**) → 1초 후 identity-admin `/tenants/me` 401 `session_revoked`(m2m 호출은 Access 서비스 토큰 **`tester-m2m`** — T011); Authentik 관리 API로 세션 삭제 → 웹훅(svc DNS) → 2초 후 401 — **관리 API 호출·확인은 운영자가 수동으로 하고 스크린샷을 tester 보고에 첨부한다**(tester 자격에 Authentik 관리 토큰을 주지 않는다 — R30); identity-admin 로그에 reason; Access 경계 단언(`auth.joshuatech.dev/if/admin/` 무헤더 302/403, `/api/v3/flows/executor/<login-slug>/` 무헤더 200)은 T078이 담당하므로 여기서 중복하지 않는다; storageState `e2e/.auth/` 실행 후 삭제; 반복 호출 간격 ≥ 200 ms(VD-3 Rate Limiting에 스스로 걸리지 않게 — plan A32) — FAIL 확인」
- 규약: 「Tests for User Story 4 (MANDATORY — write first, verify they FAIL) ⚠️」(tasks.md:208) · 「Tests MUST be written and FAIL before implementation」 · 인프라 스토리 시험 = `tests/platform/*.tests.ps1` · 「E2E task … executed by the tester agent, never by the implementer」(tasks.md:371–:374) · 헌법 II. 이 셋을 실행하는 E2E는 T085다(tasks.md:224).

## 0. 사용자 결정

| 결정 | 상태 | 내용 | 이 과제에 주는 영향 |
|---|---|---|---|
| **T077-a** | 확정 2026-11-23 | S-01 문장 개정 시점 = 「첫 자격 실행 전에」. T077–T079는 자격 없이 시험 작성 + 빨강 확인만 한다(도달 확인 → 자격 순서 · 자격은 env 계약으로만 정의) | Vault · 정책 · 에이전트 층(S-01 9파일 · `.claude/settings.json`) 변경 0(D1). 「첫 자격 실행」의 정의 · 순서와 관문 G-1–G-7 = §5-1(r1 — B-2 · r2 — V-1) |
| **T077-b** | **미룸** | web-bff(-dev) 자격 경로(T078 교환 · T079 1단계) — S-01 개정과 한 묶음(T080–T081 무렵 · 첫 자격 실행 전) | 결정 전 자격 0. 권고 (a) 유지 · 비교 기준을 「tester 추가 자격」으로 고침(§0-2 — r1 — B-8) |
| **T077-c** | 확정 2026-11-23 | T079 측정 경로 = **(A) BFF 프록시** | D7. 문면과의 차이 = 〔77-1〕 · 〔77-7〕 |
| **T077-d** | 확정 2026-11-23 | Playwright = **루트 devDependency** — 루트 `package.json` devDependencies에 `@playwright/test` `1.65.1` 정확 핀. 브라우저 = `--only-shell chromium` · 기본 위치 · 받기 전 `--dry-run` · 해시 기록 | D2 · D3 · D11 전부 이 결정으로 다시 썼다(초안의 `e2e/` 워크스페이스 패키지 `@jt/e2e`는 기각). `pnpm-workspace.yaml` 변경 0 |
| **T077-e** | 확정 2026-11-23 | `tester-k8s` 시드 → **T084**(회전 매트릭스) | T077에서 다루지 않는다 〔77-10〕 |
| **T077-f** | 확정 2026-11-23 | 「면제 셋 밖 `PLACEHOLDER-` 0」 단언 → **T081** | T077에서 다루지 않는다 〔77-11〕 |
| UD-13b(이어받음) | 확정 | T080 · T084 시작 전 라이브 Traefik ≥ 3.7.18 관문 | T077–T079 초록은 T080에 묶여 빨강 기간이 길다(§5 위험 2). T078 빨강 관찰은 이 관문에 묶지 않는다(D9 — r1 — A-10) |
| UD-15 · UD-16(이어받음) | 확정 | tester-m2m은 O-8 블록 안에서만 · Vault 로그인 = O-9 1시간 JWT | 이 과제는 둘 다 쓰지 않는다 |
| UD-4 · UD-7(이어받음) | 대기 | UD-4 = SC-003 「Authentik 세션 삭제」 경로 정의(권고 B — t073-design.md:2493 · T081 전) · UD-7 = BFF 기본 로그아웃 범위(T089 전) | D7: UD-4는 결정 상수, UD-7은 `all_devices: true` 명시로 떼어 낸다(r1 — A-16 줄 번호 정정) |

### 0-1. T076 정정 노트 23과 순서가 다른 까닭 · 「자격 없이」의 범위
- 노트 23(t076-design.md:299)은 「Playwright의 `kv/platform/authentik/e2e` 읽기 전에 검토된 블록 + 문장 개정(UD-15 범위 확장 = 사용자 결정 · approval-review)」을 요구한다. 지키려는 순서는 「자격을 읽기 전에 개정한다」이고 T077-a는 이를 깨지 않는다 — T077–T079는 자격 값을 읽지 않고 빨강은 도달 단계에서 난다. 개정이 붙는 자리를 「T077 작성」에서 「첫 자격 실행」으로 옮겼을 뿐이다.
- 근거: ① 빨강은 자격 없이 관찰할 수 있다(Authentik 없음 · 경로 미시드 — vault-unseal.md:579 · 빌더 Vault 금지 — infra.md:39). ② approval-review는 실물 블록을 봐야 하고 그 블록은 T080–T081 사실(slug · TOTP 등록 · Sessions 화면 — VD-T081-a)에 기댄다 — 그래서 관문은 §5-1 순서(T081 배포 → 운영자 수동 단계 → G-1–G-7 → T081 첫 자동 로그인 확인)로 닫고, 운영자 수동 단계(VD-T081-a 관찰 · TOTP 등록 · 시드)는 「첫 자격 실행」에 들지 않는다(§5-1 정의)(r2 — V-1 · B-2). ③ 개정 대상 9파일(〔R3 ② A7〕)을 두 번 고치지 않는다.
- **「자격 없이」의 범위(r1 — B-14 · r2 — V-3 · B-14)**: Vault · e2e 사용자 · web-bff(-dev) 자격 0. T078 빨강 관찰이 쓰는 agent-view kubeconfig는 infra.md:38이 정한 고정 신원이라 기존 범위다. T077 · T079 빨강 관찰은 `KUBECONFIG`도 쓰지 않는다 — 런처 `live-red`가 자식을 D9 허용 목록 env(기본 이름 `SystemRoot` · `PATH` · `USERPROFILE` · `LOCALAPPDATA` · `TEMP` · `TMP` + 런처 공통 `JT_E2E_RUN_ID` · `JT_E2E_ROOT` · `JT_E2E_OUTPUT_DIR` · `JT_E2E_EVIDENCE_DIR` + `JT_E2E_LIVE=1`)로 띄우고, **`KUBECONFIG` · `JT_E2E_SECRET_*` · `JT_E2E_BLOCK` · `JT_E2E_NEEDLE_SET`은 0**이다. 그 env 이름 목록을 증거로 낸다(D9 — 목록은 허용 목록과 정확히 같다).
- 이 과제에서 바뀌지 않는 것: S-01 9파일 · `.claude/settings.json` · `infra/vault/*` · 계약의 자격 문장(§4 「나중」).

### 0-2. T077-b(미룸) — 비교표(r1 — B-8 · A-15)

| 선택지 | tester 추가 자격 | 내용 | 대가 · 판단 |
|---|---|---|---|
| **(a) 권고** | **공유 앱 비밀 1개**(`web-bff-dev` client secret — preview Worker · 로컬 `next dev`가 함께 쓴다: hostnames-and-access.md:24 · bff-api.md:11) | 검토된 tester 블록이 `kv/data/dev/authentik/web-bff` **하나만** 읽어 PKCE 코드 교환 · RFC 8693 교환 · 판정 · RFC 7009(값은 블록 메모리) | T078 교환 클레임(aud · tenant_id · exp−iat · act)을 tester가 직접 단언하는 유일한 길(교환은 client 인증 필요 — quickstart.md:84). 대가: 계약 「Workers Secrets에만」 예외(bff-api.md:13 · data-model.md:170) · 정책 · `tests/infra/tofu.tests.ps1` vt-16(「e2e-reader 경로 정확히 둘」) · FR-044 · FR-049 문면 · hostnames-and-access.md:80 · eso-dev deny · S-01 범위 확장 · 노출되면 dev 체인 전체 회전 · audience 분리 role(〔R3 R10〕 — 받아들인 위험 ② 확대 여부) |
| (b) | 0 — **최소 권한의 기준** | 운영자 블록이 교환하고 판정 줄만 낸다(T075 O-5 선례) | E2E 일부가 운영자 실행 → 편차 |
| (b′) | 0 | dev 체인 서버(`next dev` + `.dev.vars`)는 **운영자만** 띄운다 · tester는 브라우저만 · **tester는 `.dev.vars`를 열지 않는다**(S-01 묶음에 `Read(**/.dev.vars*)` deny) | T079 1단계만 해결 — T078 교환은 여전히 (a) 또는 (b). tester가 서버를 띄우면 `.dev.vars`(web-bff-dev secret · Access dev 토큰 · `SESSION_ENCRYPTION_KEY`)를 읽게 되어 뒷문으로 (B)가 된다 |
| (c) | 0 | BFF 간접 확인만(T094 뒤) | 교환 클레임 단언 불가 |
| (d) | — | tester 전용 provider | FR-022 위반(spec.md:262) — 기각 |

- UD-15와의 차이: UD-15는 **tester 전용 토큰**(따로 회전 · include 목록 관리)을 줬다. (a)는 **공유 앱 비밀**을 준다.
- 「dev 한정」은 **client 한정**일 뿐이다 — 교환 토큰 audience는 dev · prod 모두 `identity-admin`(gitops-repo.md:223)이고 env를 가르는 것은 CN 관문 `ACCESS_EXPECTED_CN` 하나다(:218).
- **(a)를 고를 때의 조건**(결정 문장에 박는다): ① 여는 경로는 `kv/data/dev/authentik/web-bff` 하나 · **`kv/*/access/web-bff`는 영구 제외**(초안의 「필요하면」 삭제 — T077-c (A)와 짝) ② prod 경로 deny를 `sys/capabilities-self`로 판정 ③ `offline_access` 없이 요청(refresh 0) · 얻은 토큰 전부 finally에서 RFC 7009 ④ code는 파이프로(stdout 0) ⑤ eso-dev deny 먼저(eso-dev는 `kv/data/dev/*`를 읽는다 — policies.tf:34–37 · 「ESO 밖」은 지금 관례일 뿐) ⑥ audience 분리 role은 비용 칸에서 정한다.
- **(b′)의 자리(r2 — V-11)**: (b′)는 T079 1단계 dev 서버의 기동 주체만 정하는 보조 선택지라 (a) · (b) 어느 쪽과도 함께 고를 수 있다. 권고 = **(b′) 병행**(G-6 · §4 「나중」의 `Read(**/.dev.vars*)` deny와 짝). T077-b가 정해지기 전까지 이 설계는 서버 기동 주체를 「T077-b 결정 — 권고 (b′) 병행」으로만 적는다(§1-1 T079 · §5-3 T085 · D7 reach-bff 사유 코드에서도 「operator-started」를 뺐다).
- 결정 전 동작: 자격 0 — T078 `xchg-1` · `xchg-2`는 「자격 블록 전용」 SKIP · T079 1단계(dev 체인)는 막힘.

### 0-3. 컨트롤러 기본값(이견이 있으면 사용자 결정으로 올린다)
- authz-assert 검사 id 확장 소유 = **T082** · 데이터 = 합성 주체(D8 ⑥).
- `e2e/**` 경로 규칙 행 = T087 때. 그때까지 D3 · D5 · D10이 그 자리의 규칙이다.
- approval-review 꼴 = **(i) 전체 또는 (ii) security · k8s-security 두 경계**뿐 — (iii) 「설계 비판만」은 T077-a 문장 · 노트 23과 어긋나 후보에서 뺀다(r1 — B-2).
- UD-1(Authentik ≥ 2026.8.2 — t073-design.md:2439)은 T080 착수 때 다시 여쭙는다(〔R1 ⑤-11〕).

## 1. AC 대응과 합격선

### 1-1. 과제 ↔ AC ↔ 합격선(과제마다 따로 — r1 — A-9)

| 과제 | AC · FR | 시험 | 이 과제의 합격선(시험 작성 + 올바른 이유의 빨강) | 초록 과제 · 조건 |
|---|---|---|---|---|
| T077 | AC1 tester 자동 몫(spec.md:104) · FR-022 · 023 · 026 · 044 | `e2e/auth.spec.ts` 1건(D6) | ① 기반 초록: 런처 `selftest` · `selftest-browser` 전부 PASS · 런처 `needle` 판정 `needle=PASS`(의도 실패 7 정확 일치 · 바늘 0(모든 면) · 양성 대조가 로그 면에서 잡힘 — D10 ⑧ · r2 — V-6) · 런처 `list`에 **live 1건**(auth) ② 라이브 빨강: 런처 `live-red`에서 `T077 reach FAIL [gate] …T080` · exit 1 ③ 잔여 0: `e2e/.auth/` 파일 0 · outputDir 삭제 · 잠금 표식 0 · `git status`에 지정 파일만 | §5-1 순서: T080(UD-13b 뒤) → T081 배포 → 운영자 수동 단계 → G-1–G-7 → T081 첫 자동 로그인 확인 → T085(r2 — V-1 · B-2) |
| T078 | AC2(spec.md:105) · AC5(:108) · AC6(:109) · FR-025 · 026 · VD-1 | `tests/platform/identity.tests.ps1` + 짝 하네스 `tests/scripts/identity-tests.tests.ps1` | ① 짝 하네스 `N passed, 0 failed` 두 번 ② 라이브 줄이 §1-2 「오늘 기대」와 하나하나 같다 | T080 · T081 · T082 · Job 렌더 · 자격 블록(T077-b · §5-1 관문 뒤 — r2 — V-1) |
| T079 | AC3(:106) · AC4(:107) · FR-024 · 027 · 036 · SC-003(시간 측정 = T085) | `e2e/revocation.spec.ts` 2건(D7) | ① T077 ①에 더해 `list`에 **live 3건** · BFF 분류 · 로그 선택 selftest 초록 ② 두 시험 모두 `reach-auth`에서 `[gate] …T080` ③ 잔여 0 | T080 · T081 · T083 · T092 · UD-4 상수 · 1단계 dev 체인(서버 기동 주체 = T077-b 결정 — 권고 (b′) 병행 — r2 — V-11) · 2단계 T094 뒤 · 자격 실행은 §5-1 관문 뒤(r2 — V-1) → T085 |

### 1-2. T078 id와 오늘 기대(올바른 이유의 빨강)

| id | 단언 | 오늘 기대 | 초록 |
|---|---|---|---|
| gate-1 · 2 · 3 | kubectl 있음 · KUBECONFIG 단일 파일 · whoami = agent-view | PASS(운영자 창) | — |
| tool-1 | curl 첫 해석이 Application이고 그 경로의 판 ≥ 7.84(`%header{}`) (r1 — A-5) | PASS | — |
| ing-1 | ns `identity` Ingress에 host `auth.joshuatech.dev` 규칙 | FAIL `until T080 (no Ingress for auth.joshuatech.dev in ns identity)` | T080 |
| acc-1 | `GET https://auth.joshuatech.dev/if/admin/` 무헤더 → **302 + Location = 팀 도메인 `joshua-tech.cloudflareaccess.com` · 경로 접두 `/cdn-cgi/access/login/`, 또는 403**(`text/html` · Location 없음 — 문면 「302/403」) **그리고** ing-1 PASS(r1 — A-8) | FAIL `302 is edge-only (Access app auth-admin — T011); origin route absent — until T080` | T080 |
| acc-2 | `GET https://admin.joshuatech.dev/identity-admin/admin/` 무헤더 → 302 + 같은 Location 꼴 | PASS(T075 L15 · 〔77-2〕) | — |
| acc-3 | `GET https://identity-m2m-prod.joshuatech.dev/health` 무헤더 → 401 · `text/html` · Location 없음(계약 C11) | PASS(〔77-2〕) | — |
| pub-1 | `/api/v3/root/config/` → 200 · `application/json` · 판정 키(VD-T080-a — 후보 `capabilities`, 추론) | FAIL `Traefik 404 (no router) — until T080` | T080 |
| pub-2 | `/api/v3/flows/executor/<login-slug>/` → 200 · JSON · `component` 키(slug 상수 `default-authentication-flow` — research.md:2308 · 추론) | FAIL 같음 | T080 · T081 |
| pub-3 | `/application/o/identity-admin/.well-known/openid-configuration` → 200 · JSON · `issuer` = `https://auth.joshuatech.dev/application/o/identity-admin/` · `jwks_uri` 있음 | FAIL 같음 | T080 · T081 |
| pub-4 | `/application/o/identity-admin/jwks/` → 200 · JSON `keys` ≥ 1 | FAIL 같음 | T081 |
| pub-5 | 루트 `/.well-known/` **후보 상수** `$WellKnownRootPath = '/.well-known/oauth-authorization-server/application/o/identity-admin'`(RFC 8414 §3 꼴 — issuer 끝 `/`를 떼고 호스트와 경로 사이에 끼운다 · 추론)(r2 — V-10) → 200 · `application/json` · `issuer` 키 (r1 — A-1 (가)) | FAIL `Traefik 404 (no router) — until T080` | T080(상수 확정 — VD-T080-a가 끝 `/` 없음 · 있음 두 꼴을 함께 잰다 · r2 — V-10). Authentik이 루트 `/.well-known/`에서 아무것도 내지 않으면 T080 정정 노트로 pub-5를 지우고 〔77-13〕(A-1 (나)) |
| xchg-0 | `GET /application/o/token/` → Authentik의 405 꼴(POST로 두드리지 않는다 — Reputation) | FAIL `Traefik 404 — until T080` | T080 |
| xchg-1 · 2 | 교환 판정 · `portfolio-core` 거부 | SKIP `자격 블록 전용 — T077-b · S-01 개정(T080–T081)` | 자격 블록 |
| fga-1–4 | Job 로그의 새 id 넷 `check-member-allowed` · `check-owner-allowed` · `cross-tenant-member-false` · `cross-tenant-owner-false` | FAIL `Job jt-dev/authz-assert absent — rendered with the tests Application after T082 (T085)` | T082 + 렌더 |
| man-1 · 2 | `argocd --sso` · Authentik 관리 API | SKIP `운영자 수동 + 스크린샷(R30)` | T084 · T085 |

- 기대 끝 줄(추론): `6 passed, 12 failed, 4 skipped` · exit 1. 12 FAIL은 전부 「until T0NN」 사유다(pub-5 포함 — r1 — A-1). 이 표와 다른 줄(예: gate 실패로 kubectl 단언이 `kubectl unavailable`)은 「잘못된 이유의 빨강」이라 증거로 쓰지 않는다(D9).

### 1-3. 초록이 되는 순서
- T077(§5-1 순서 — r2 — V-1 · B-2): T080 → T081 배포(사용자 · 흐름 · TOTP stage) → 운영자 수동 단계(브라우저 로그인 확인 · TOTP 등록 · VD-T081-a 관찰 · 시드: `password` 먼저 · `totp_seed`는 등록 뒤 · 자리는 시드 전 결정 — §5-3 T081 · r1 — B-9) → G-1–G-7(스펙 상수 커밋 · 실물 블록 · approval-review · 승인 커밋) → T081 첫 자동 로그인 확인 → T085. (r1의 「§5-2 T081」은 §5-3을 잘못 가리킨 인용이라 함께 고쳤다.)
- T078: T080 → T081 → T082 → Job 렌더 → 자격 블록(T077-b · 자격 실행이라 §5-1 관문 뒤 — r2 — V-1). T085 뒤 run-all `platform` 슬롯에서 exit 0이 될 수 있다(남는 SKIP = 자격 블록 전용 · 운영자 수동).
- T079: T080 · T081 · T083 · T092 뒤 1단계, T094 뒤 2단계(자격 실행은 §5-1 관문 뒤 — r2 — V-1) → US5 뒤에야 초록(tasks.md:366).

### 1-4. report 편차 후보(`/finish`가 report.md 「편차」로 옮긴다)

| 번호 | 내용 | 근거 |
|---|---|---|
| 77-1 | T079 「`tester-m2m`으로 `/tenants/me` 401」 → BFF 프록시 경로(T077-c (A) 확정). tester-m2m은 CN 관문에서 늘 403 `access_required` | identity-admin-api.md:21 · :36 · :97 · quickstart.md:90 · 〔T073 편차 27〕 |
| 77-2 | T078 「`admin.` 헤더 없이 403」 → 302 + Access Location · AC6 m2m 무헤더 = 401 | hostnames-and-access.md:7 · :27 · :30 · 〔T075 편차 6〕 |
| 77-3 | T079 「Authentik 관리 API로 세션 삭제 → 웹훅」 — 2026.8은 세션 삭제 이벤트가 없다 → 자동 시험은 UD-4 권고 B(로그아웃 이벤트 웹훅) · 관리 API 삭제는 운영자 수동 기록만 | identity-admin-api.md:59 · data-model.md:194 · t073-design.md:2493 · 〔T073 편차 25〕 |
| 77-4 | 「trace `mask`」 → trace · video · 자동 screenshot off · HTML 리포터 금지 · `preserveOutput: 'never'` · 증거 스크린샷만 `mask`(Playwright trace에는 가림 옵션이 없다) | 〔R2 2-8〕 · 〔R3 D1〕 · D3 |
| 77-5 | 「TOTP 시드 … env로」 → TOTP **코드 창**(시드는 블록 밖으로 안 나간다) — S-01 개정 때 확정 | 〔R3 ④ (a)⑤〕 · D5 |
| 77-6 | T078 교환 = 검토된 자격 블록(하네스 = 판정 함수 · 도달 · SKIP 줄). 「`e2e/.auth/`의 Playwright 저장 토큰」은 생기지 않는다. **test-first 예외: AC2 라이브 블록 = T080–T081 · 오늘 빨강 증거 = xchg-0 · 판정 함수는 짝 하네스로 검증**(r1 — A-15) | tester.md:33 · 〔R3 R7 · R9〕 · bff-api.md:21 · :24 |
| 77-7 | T079 「access 토큰 확보」 · 「같은 access 토큰」 → BFF 세션 + 기준선 200 · 401 층위(pod 중계 · BFF)는 INFO(AC4는 로그 시각 조건 — D7) | bff-api.md:24 · :36 · :90 |
| 77-8 | e2e 위치 · 도구 — 실물 = 루트 `e2e/` + **루트 devDependency · 루트 `playwright.config.ts`(T077-d)** ↔ plan.md:70(`apps/web/…/e2e/`) · :95(`tests/e2e/`) | tasks.md:27 · AGENTS.md:64 · D2 |
| 77-9 | spec Design §4 미들웨어 순서(spec.md:430) ↔ 계약 · 코드(Access → Bearer → 거부 목록) | identity-admin-api.md:21–25 · 〔R1 ②-5(g)〕 |
| 77-10 | `tester-k8s` 시드 「T077」 → T084(T077-e 확정) | hostnames-and-access.md:84 · data-model.md:172 · quickstart.md:14 |
| 77-11 | 「면제 셋 밖 `PLACEHOLDER-` 0」 T077 인계 → T081(T077-f 확정) | vault-unseal.md:344 |
| 77-12 | T078 OpenFGA `user:<sub>` → 합성 주체(seed 튜플 판정은 T085) | gitops `platform/policies/tests/README.md` 후속 결정 2 |
| 77-13 | T078 루트 `/.well-known/*`(글롭) → 후보 상수 · T080 실측. 서빙 대상이 없으면 pub-5 삭제(test-first 빨강 없음 — 그 사유 포함)(r1 — A-1) | 〔R1 ③-14〕 · hostnames-and-access.md:25 |
| 77-14 | 문면보다 엄격 · 구체화: T079 `all_devices: true` 명시(UD-7 분리) · T079 storageState 파일 0(쿠키 사본은 메모리) · T077은 **로그아웃 뒤 죽은 상태만** `e2e/.auth/`에 쓴다(r1 — A-17 · B-5) | denylist.md:23 · bff-api.md:32 · D6 · D7 |
| 77-15 | 「스크린샷을 tester 보고에 첨부」 → 파일은 저장소 밖 · 커밋 0 · 보고에는 파일 이름 · SHA-256 · 가린 칸 목록만 · 운영자 화면은 운영자가 가린 뒤 넘긴다(공개 저장소 · gitleaks는 이미지 글자를 못 본다)(r1 — B-4) | ci.yml:157 · D10 ⑨ |

## 2. 결정

### D1 범위 · 산출물
- 모노레포만 바꾼다. **gitops 0 · 라이브 변경 0 · Vault 0 · 정책 0 · 에이전트 층(S-01 9파일 · `.claude/settings.json`) 0 · 계약 문장 0(§4 「나중」) · `pnpm-workspace.yaml` 0 · ci.yml 0**(T077-d).
- 산출물(r1 — T077-d로 다시 씀):
  - 루트: `package.json`(devDependencies `@playwright/test: "1.65.1"` 한 줄 · scripts 0) · `pnpm-lock.yaml`(루트 importer) · `playwright.config.ts`(루트 — D3) · `.gitignore`(D4).
  - T077: `e2e/global-setup.ts` · `e2e/global-teardown.ts` · `e2e/lib/{reach,env-contract,totp-window,secret-input,pace,auth-dir,http,login-lock,evidence,out}.ts`(`out` = 출력 통로 — D10 ⑤ · r2 — V-2) · `e2e/lib/{launch,scan-needle}.mjs`(Node 내장 모듈만) · `e2e/selftest/**` · `e2e/selftest-browser/**` · `e2e/needle/**` · `e2e/auth.spec.ts` · `e2e/README.md`(갱신).
  - T079: `e2e/revocation.spec.ts` · `e2e/lib/{bff,kubectl-log}.ts` · selftest 추가.
  - T078: `tests/platform/identity.tests.ps1` · `tests/scripts/identity-tests.tests.ps1`.
  - 컨트롤러: `tests/run-all.ps1` 슬롯 둘(`e2e-selftest` — D11 · `identity-harness` — D8 ⑧) (r1 — A-14 · A-7).
  - 기록: 이 설계 · build-notes 「## T077 · T078 · T079」 · 학습 로그 `content/tmp/003-t07{7,8,9}/` · tasks.md tick 셋.
- 네트워크: npm 레지스트리 · Playwright 브라우저 CDN(설치 1회) · 빨강 관찰의 공개 HTTPS GET(자격 헤더 0).

### D2 Playwright 설치 — 루트 devDependency(T077-d)
1. **위치 = 루트 `e2e/`(시험 소스) + 루트 의존성 · 루트 config**. 근거: tasks.md:27 · :210 · :212 · AGENTS.md:64 · `.gitignore:45` `e2e/.auth/`(루트 기준) · tester 쓰기 가드 `^e2e/`(tester-write-guard.ps1:40). `e2e/`는 워크스페이스 패키지가 아니다 — 루트 Playwright가 읽는 소스 디렉터리다.
2. **루트 devDependency의 결과**(T077-d):
   - 루트 importer가 `{}`(pnpm-lock.yaml:9)에서 `devDependencies: '@playwright/test': {specifier: 1.65.1, version: 1.65.1}`로 바뀐다. `packages/content` · `packages/events` importer와 기존 스냅숏은 **바이트 불변**이어야 한다 — vitest의 선택 peer는 `@vitest/browser-playwright`이지 `playwright`가 아니라(pnpm-lock.yaml:395 · :411) `vitest@5.0.5(vite@8.3.5)` 접미가 바뀌지 않는다(추론 → 설치 뒤 diff로 확인).
   - 루트 `package.json` · `pnpm-lock.yaml`과 루트 `playwright.config.ts`는 tester 쓰기 가드 밖이다 — 설정 약화는 리뷰된 커밋으로만 들어온다. 앞의 둘은 events-test 방어의 리뷰 대상 파일이다(ci.yml:63–70 — 리뷰 렌즈 C).
   - 워크스페이스 목록은 그대로다(R2 A1 장점). `--filter` 대상이 없으므로 명령은 루트에서 돈다(D9).
3. **판 = 1.65.1 정확 핀**(2026-11-13 발행 · 숙성 3일 통과 — pnpm-workspace.yaml:10). 판마다 브라우저 리비전이 묶인다(1.65.1 → chromium 1255 — 〔R2 2-4〕). **설치 시점에 1.65.1이 아닌 판이 필요해 보이면 빌더는 고르지 않고 멈춰 사용자에게 다시 여쭙는다**(초안의 「새 패치면 그 판」 삭제 — r1 — B-7 ⑤).
4. **브라우저 = chromium 헤드리스 셸만**(`--only-shell`) · 기본 위치 `%LOCALAPPDATA%\ms-playwright`(저장소 밖 · 기존 `chromium-1179`는 건드리지 않는다). `PLAYWRIGHT_BROWSERS_PATH=0`은 기각(작업 트리 안 실행 파일).
5. **설치 절차**(빌더 ①a가 실행하고 출력을 그대로 보고 — r1 — B-7 · A-17):
   0. env 가드 — 하나라도 있으면 멈춘다(이름만 출력): `PLAYWRIGHT_DOWNLOAD_HOST` · `PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST` · `PLAYWRIGHT_BROWSERS_PATH` · `HTTP(S)_PROXY` · `ALL_PROXY`(대소문자 무관) · `NODE_EXTRA_CA_CERTS` · `NODE_TLS_REJECT_UNAUTHORIZED` · `NODE_OPTIONS` · `npm_config_registry`(대소문자 무관). `pnpm config get registry` = `https://registry.npmjs.org/`.
   1. `pnpm add -D -w --save-exact --ignore-scripts @playwright/test@1.65.1`(워크스페이스 루트 추가는 `-w`가 필요하다 · 패키지 생성 · 워크스페이스 등록 단계 없음 — A-17 ①은 T077-d로 사라졌다). 숙성 창이 해석을 막으면 오류를 그대로 보고(우회 금지).
   2. `pnpm install --frozen-lockfile --ignore-scripts`(CI와 같은 꼴).
   3. lockfile 검사(리뷰 렌즈 C도 본다): 새 패키지 = 정확히 {`@playwright/test@1.65.1`, `playwright@1.65.1`, `playwright-core@1.65.1`} + `playwright`의 선택 의존성(있으면 `fsevents` — darwin 전용 · 설치 0 · 추론) · 모두 `integrity` 있음 · `tarball:` 항목 0(지금 0) · 루트 밖 importer · 기존 스냅숏 diff 0.
   4. `pnpm exec playwright install --dry-run --only-shell chromium` → 판 · 리비전 · 내려받기 URL 호스트(기본 CDN인지) · 설치 경로 · ffmpeg 포함 여부를 보고(VD-T077-3).
   5. 같은 명령에서 `--dry-run`을 빼고 설치.
   6. 헤드리스 셸 실행 파일의 SHA-256과 그 디렉터리 파일 목록(상대 경로 · 크기 · SHA-256)의 SHA-256을 build-notes에 적는다 — 나중 자격 블록이 대조한다(§5-1 G-3).
   7. `pnpm --filter @jt/events --fail-if-no-match test` 초록(events-test 방어 경로 영향 0).
6. TypeScript 의존성 · tsconfig는 두지 않는다 — Playwright가 TS를 변환하고 수집 검사는 `--list`로 대신한다(헌법 V).

### D3 루트 `playwright.config.ts`(T077-d)
- **자리 = 저장소 루트**(초안 `e2e/playwright.config.ts` → r1). 까닭: ① 루트에서 `pnpm exec playwright test`를 인자 없이 돌려도 늘 이 설정이 잡힌다 — 설정이 `e2e/`에 있으면 인자 없는 실행이 기본 설정으로 저장소 전체의 `*.test.*`(vitest 시험 포함)와 live 스펙을 집어 간다(추론) ② tester 쓰기 가드 밖 ③ `testDir` = `./e2e`.
- **프로젝트(조건부 — r1 — A-17 · B-6)**:
  - `selftest` — `e2e/selftest/**/*.test.ts` · 브라우저 0 · 네트워크 0(순수 함수 — reach · BFF 분류 표 사례 포함(r2 — A-2) · config-hygiene · static-gate · tracked-files · scan-needle 양성 대조). 늘 있음.
  - `selftest-browser` — `e2e/selftest-browser/**/*.test.ts` · 로컬 `page.setContent`만(secret-input · evidence mask 판정). 늘 있음. secret-input의 「칸을 비웠다」 확인은 `locator.evaluate(e => e.value.length)`로 길이만 받아 수를 비교한다(`inputValue(` · `toHaveValue(` 0 — 컨트롤러 — N-4).
  - `needle` · `needle-control` — `JT_E2E_NEEDLE=1`일 때만(D10 ⑧).
  - `live` — `JT_E2E_LIVE=1`일 때만 · `auth.spec.ts` · `revocation.spec.ts` · `use.baseURL` = `https://auth.joshuatech.dev`.
  - 두 플래그가 함께면 설정 로드에서 `[guard] needle-live-conflict — needle+live 동시 금지`로 멈춘다(바늘 값이 실제 IdP로 가지 않게)(r2 — V-9).
  - 그래서 인자 없는 실행 = selftest 둘뿐이다. 루트 `package.json`에 `test` 스크립트가 없음을 selftest가 고정한다.
- **기록**: 모든 프로젝트 `trace: 'off'` · `video: 'off'` · `screenshot: 'off'`. 증거는 명시적 `page.screenshot({ mask })`(evidence helper)만.
- **reporter**: `[['list', { printSteps: false }]]` 하나. HTML · blob · json · junit 금지. HTML 금지의 까닭(r1 — A-16 정정): 1.52+ step 제목에 `fill` 값이 평문(issue 36800 · 35848) · 기본 `open: 'on-failure'`의 리포트 서버 대기로 도구가 프로세스를 끊는다(초안의 「teardown이 돌지 않는다」는 근거가 약해 뺐다).
- **outputDir**: `JT_E2E_OUTPUT_DIR`(런처 · 블록이 준다) — 없으면 `os.tmpdir()/jt-e2e/<runId>`. **`preserveOutput: 'never'`**(초안 `failures-only` → r1 — B-4 (a)): 실패 산출물(1.60+ error-context 등)을 남기지 않는다. 실패 근거는 단계 줄로 충분하다.
- **실행**: `workers: 1` · `fullyParallel: false` · `retries: 0` · `forbidOnly: true` · `maxFailures: 0`. 같은 사용자 로그인은 직렬이어야 한다(TOTP `last_t` — 〔R3 C5〕 · Reputation).
- **시간**: 시험 120 s · expect 10 s · action 15 s · navigation 30 s · `globalTimeout` 540 s(Bash 도구 600 s 안).
- **use 그 밖**: `locale: 'en-US'`(선택자 고정 — 추론) · `timezoneId: 'UTC'` · `ignoreHTTPSErrors: false` · `acceptDownloads: false`. **`launchOptions.env` = 허용 목록**(`SystemRoot` · `TEMP` · `TMP` · `LOCALAPPDATA` · `USERPROFILE` — 최종 목록 VD-T077-3)으로만 준다(초안 「`process.env` − `JT_E2E_SECRET_*`」 → r1 — B-11). `executablePath` · `channel` 미설정 · `webServer` 0.
- **metadata**: `jtApprovedBlock: null` — 「검토된 자격 블록」 경로 상수(B-2 코드 관문). 루트 config에 둬 tester 쓰기 가드 밖에 있게 한다(r1 — B-2 · T077-d). T080–T081 승인 커밋이 경로를 넣는다. 해시가 아니라 경로다(블록이 e2e 파일 해시를 고정하므로 해시면 순환).
- **globalSetup**(r1 — B-3 ① · B-5 ② · B-6 ① · A-11) — 줄은 모두 `out.ts`로 낸다(D10 ⑤ · r2 — V-2):
  1. env 가드 — 이름만 출력하고 멈춤: `PWDEBUG` · `pw`가 든 `DEBUG` · `NODE_DEBUG` · `SSLKEYLOGFILE` · `NODE_EXTRA_CA_CERTS` · `NODE_TLS_REJECT_UNAUTHORIZED` · `PLAYWRIGHT_BROWSERS_PATH` · `PLAYWRIGHT_*_DOWNLOAD_HOST` · `*_PROXY`(대소문자 무관) · 디버그 · 진단 플래그가 든 `NODE_OPTIONS`(Playwright 자신이 넣는 값은 VD-T077-3에서 확인해 허용 — §3과 같은 번호 · r2 — V-8).
  2. 러너 argv 가드 — `--ui*` · `--debug` · `--headed` · `--trace` · `--reporter` · `--output` · `--workers`/`-j` · `--retries` · `--repeat-each` · `--tsconfig`가 있으면 멈춘다(CLI 덮기 — playwright.dev test-cli).
  3. FullConfig 재단언 — reporter = list 하나 · 모든 project `use.trace` · `video` · `screenshot` = off · `workers` 1 · 모든 project `retries` 0 · `preserveOutput` never · outputDir과 `JT_E2E_EVIDENCE_DIR`은 저장소 루트 밖이고 `os.tmpdir()`(또는 블록 소유 루트 `JT_E2E_ROOT`) 아래 · `executablePath` · `channel` 없음. 어느 값이 FullConfig에 드러나는지는 VD-T077-6.
  4. 로그인 잠금 표식(D10 ⑦)이 있으면 — **`JT_E2E_LIVE=1`인 실행**(`live` 프로젝트가 설정에 실린 실행)은 live를 시도하지 않고 `[guard] login-lock present — operator check`로 멈춘다(지우지 않는다). 그 밖 실행(selftest · selftest-browser · needle · run-all `e2e-selftest`)은 `INFO login-lock present` 한 줄만 내고 계속한다(r2 — V-7).
  5. `e2e/.auth/` 잔여 파일이 있으면 **모드와 무관하게 모든 실행에서**(잔여는 이전 live 실행의 흔적이라 어느 모드에서 발견돼도 노출 의심이다) 개수만 내고 지운 뒤 **멈춘다** — `[state] previous-run residue — server session invalidation unconfirmed`(노출 의심으로 보고 · tester.md:36 · 운영자가 Authentik에서 e2e 사용자 세션을 지운다 — R30). run-all `e2e-selftest`도 그 실행은 FAIL이다(r2 — V-7).
- **globalTeardown**: `e2e/.auth/` 전부 삭제 → `INFO auth-residue 0` 줄(`out.ts` — r2 — V-2 · ASCII 글자 고정 — 컨트롤러 — N-3).
- **`config-hygiene` selftest**: 해석된 설정의 **이름 붙은 필드만** 비교한다(객체 통째 비교 · diff 출력 0 — env가 찍히지 않게)(r1 — B-11).

### D4 `.gitignore` · 추적 파일
- 「# Test artifacts」 절에 더할 것: `test-results/` · `playwright-report/` · `blob-report/`(깊이 무관 — 루트 config의 기본 outputDir = 루트 `test-results/`) · `.dev.vars` · `.dev.vars.*`(사전 방어). 기존 `e2e/.auth/` 유지. 확인 = 패턴마다 `git check-ignore --no-index -v <경로>`.
- gitleaks git 모드는 압축 파일 내용을 못 본다(ci.yml:138–139) → 네 겹: 만들지 않음(trace off) · 저장소 밖 · 무시 패턴 · 파일 이름 스테이징(`git add -A` 0 · 커밋 전 `git diff --cached --stat`에 `e2e/` 바이너리 0).
- **`tracked-files` selftest = 정확한 파일 집합**: `git ls-files e2e`와 루트 4파일(`package.json` · `pnpm-lock.yaml` · `playwright.config.ts` · `.gitignore` 존재)이 D1 산출물 목록과 같아야 한다(확장자 허용 → 정확 집합 — r1 — B-12). 새 파일은 그 목록을 고치는 커밋으로만 들어온다. `e2e/.auth/` 추적 0.

### D5 env 계약 · 실패 분류

| 이름 | 뜻 | 출처 예정 | 비밀 | 쓰는 시험 |
|---|---|---|---|---|
| `JT_E2E_SECRET_PASSWORD` | e2e 사용자 비밀번호 | Vault `kv/platform/authentik/e2e` `password` — 검토된 블록이 읽고 → revoke → port-forward 종료 → Playwright 자식 하나의 시작 env로만 · needle 실행에서는 **런처(needle)**가 바늘 값으로 준다(컨트롤러 — N-1) | 예 | T077 · T079 |
| `JT_E2E_SECRET_TOTP_CODES` | 연속 30 s 단계의 6자리 코드(쉼표) | 같은 블록이 `totp_seed`로 계산 · 시드는 넘기지 않는다 · needle 실행에서는 **런처(needle)**가 난수 코드로 준다(컨트롤러 — N-1) | 예(단기) | T077 · T079 |
| `JT_E2E_TOTP_STEP0` | 첫 코드의 단계 번호 | 같은 블록 · needle 실행에서는 **런처(needle)**(컨트롤러 — N-1) | 아니오 | T077 · T079 |
| `JT_E2E_BLOCK` | 실행한 블록의 저장소 상대 경로(r1 — B-2) | 블록 | 아니오 | T077 · T079 |
| `JT_E2E_LIVE` · `JT_E2E_NEEDLE` | 프로젝트 포함 플래그(D3) | 블록 · 런처 | 아니오 | 셋 |
| `JT_E2E_NEEDLE_SET` | needle 실행의 바늘 묶음(JSON — 비밀번호 · 코드 · 쿠키 · authorization · 쿼리 · 가짜 IP · UA · 대조 바늘). 비밀번호 · 코드 바늘은 `JT_E2E_SECRET_*` 이름으로도 준다(실제 읽기 경로를 지나게)(r2 — V-6) | 런처 `needle`이 실행마다 만든다(D10 ⑧) | 아니오(가짜 값) | needle · needle-control |
| `JT_E2E_CHAIN` | `dev`(`http://localhost:3000` · ns `jt-dev`) · `prod`(`https://joshuatech.dev` · ns `jt-prod`) | 디스패치 지시문 | 아니오 | T079 |
| `JT_E2E_RUN_ID` | `t07x-<yyyyMMddTHHmmssZ>-<6 hex>` | 블록 · 런처 | 아니오 | 셋 |
| `JT_E2E_ROOT` · `JT_E2E_OUTPUT_DIR` · `JT_E2E_EVIDENCE_DIR` | 블록 소유 루트와 그 아래 outputDir · 증거 자리(저장소 밖) | 블록 · 런처 | 아니오 | 셋 |
| `KUBECONFIG` | agent-view kubeconfig(T079 log-reason) | 디스패치(tester.md:29) | 기존 자격 | T079 |

- **읽는 자리**: 시험 본문에서 도달 단계가 통과한 뒤에만(`readSecretsOnce(testInfo)`). 모듈 · 설정 · `beforeAll` · globalSetup에서는 읽지 않는다. `process.env.JT_E2E_SECRET_`는 `env-contract.ts` 밖에서 0(static-gate). 바늘 묶음 `JT_E2E_NEEDLE_SET`도 `env-contract.ts`만 읽는다(r2 — V-6).
- **모드 판정(r1 — B-2 · B-6)** — 프로젝트 이름으로 가른다(env로 고를 수 없다):
  - `live`: `JT_E2E_BLOCK` = config `metadata.jtApprovedBlock`(지금 `null` → 늘 불일치)이 아니면 값을 읽지 않고 `[guard] outside-reviewed-block (T077-a)`. `JT_E2E_NEEDLE_SET`이 있거나 비밀번호가 바늘 꼴(접두 `JTNEEDLE-`)이면 `[guard] needle-shaped value in live`(r2 — V-6).
  - `needle`: 값이 **런처가 준 바늘**(`JT_E2E_NEEDLE_SET`)과 정확히 같고 비밀번호가 바늘 꼴이어야 한다 — 아니면 `[guard] non-needle value in needle`(실제 비밀이 바늘 실행에 흘러들지 않게 · r1의 「정확한 바늘 상수」 대조는 소스 리터럴을 없애며 바꿨다 — r2 — V-6).
  - `needle-control`: `JT_E2E_NEEDLE_SET`의 **대조 값만** 돌려준다(대조 접두 꼴 — 아니면 `[guard] non-control value in needle-control`). `JT_E2E_SECRET_*`는 읽지 않는다(컨트롤러 — N-1).
  - 그 밖 프로젝트: `[guard]`. 이 갈래 전부를 `selftest`가 표 시험한다(`needle-control` 행 포함 — 컨트롤러 — N-1).
- **한 번 읽고 지운다**: 모듈 변수로 옮기고 `process.env`에서 지운다 → 워커가 띄우는 자식(kubectl)은 물려받지 않는다. 러너 env에는 남는다(§5 위험 3).
- **없을 때** = 빠진 이름만 나열한 `[env]` FAIL(값 · 길이 0). SKIP이 아닌 까닭: 전부 SKIP이면 exit 0 = 빈 초록(취지는 run-all 양성 증거 규율과 같다 — run-all.ps1:44–45 · live는 run-all 밖)(r1 — A-16).
- **꼴 판정**: 비밀번호 비어 있지 않음 · 코드 `^\d{6}(,\d{6}){1,39}$` · step0 정수.
- **TOTP 코드 창**: 블록이 N단계(기본 20 = 10분)를 넘긴다. 스펙은 입력 직전 다음 30 s 경계 + 0.5 s까지 기다려 그 단계의 코드를 쓴다(로그인마다 새 단계 · `last_t` 재사용 거부 회피). 창이 바닥나면 시도 없이 `[env] totp-window-exhausted` 〔77-5〕.
- **고정 신원**: `e2e@joshuatech.dev` 상수(infra.md:38).
- **실패 분류 접두**(스펙 · 하네스 공통 · 기계 판독 부분 = 접두 · 단계 · PASS/FAIL · 사유 코드는 **ASCII** — 설명은 한국어 가능)(r1 — A-17). **경계(r2 — V-9)**: 기계 판독 부분은 구분자 앞까지다 — `out.ts` 줄은 첫 ` — ` 앞, 런처 줄과 T078 하네스 줄(D8 꼴 `PASS|FAIL|SKIP <id> -- <근거>`)은 ` -- ` 앞. 설명은 구분자 뒤에만 쓴다. `out.ts`는 그 앞이 ASCII가 아니면 throw한다(D10 ⑤). T078 하네스는 `chcp.com 65001`로 돈다(D9):

| 접두 | 뜻 | 빨강 증거로 쓰나 |
|---|---|---|
| `[gate]` | 구현 부재 — **Traefik 404 서명 전체 일치일 때만**(D6 reach) · Ingress · Job 부재 | 예 |
| `[product]` | 응답은 왔지만 계약과 다르다 | 빨강 단계에서 나오면 조사 |
| `[env]` | 실행 환경 부재(자격 env · 체인 · 네트워크 · **오리진 52x/5xx** · 도구) | 아니오 |
| `[decision]` | 사용자 결정 대기(UD-4) | 아니오 |
| `[guard]` | 안전 장치(잠금 표식 · 디버그 env · 블록 밖 실행 · CLI 덮기) | 아니오 |
| `[state]` | 이전 실행 잔여 | 아니오 |

### D6 T077 `e2e/auth.spec.ts` 흐름
단계마다 `out.ts`로 `T077 <step> PASS|FAIL <근거>` 한 줄을 낸다(비밀 0 · 기계 판독 부분 = 첫 ` — ` 앞 ASCII — D5 · r2 — V-2).

| 단계 | 하는 일 | 단언(비밀 0) | 실패 분류 |
|---|---|---|---|
| reach | `http.ts` 감싸개로 `GET https://auth.joshuatech.dev/`(`maxRedirects: 0` · 20 s) → `lib/reach` 분류 | Authentik 범주(같은 호스트 `/if/` · `/flows/`로 302 또는 200 HTML 표식 — VD-T080-a · VD-T081-a) | **`[gate] authentik-absent until T080`은 Traefik 404 서명이 다 맞을 때만**: 404 · `text/plain; charset=utf-8` · 19 B · 본문 sha256 `b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793`(T076 D10 기준값 — t076-design.md D10) · `cf-cache-status` ≠ HIT — 이 서명 자체가 오리진(노드 A Traefik) 도달 증거다. **52x(521 · 522 · 523 · 525 · 526)와 그 밖 5xx → `[env] origin`**(빨강 증거 아님). Access 302/401 → `[product]`. 서명이 하나라도 어긋난 404(18 B · 다른 sha256 · `text/html` · `cf-cache-status: HIT`) → `[product] reach-unexpected`(`[gate]` 아님 · 조사)(r2 — A-2). 대조 호스트 `identity-m2m-dev/health` 무자격 401은 엣지 응답이라 오리진을 증명하지 못한다 → **INFO**(네트워크 · 엣지 정상 여부만)(r1 — A-2). 분류 사례 = ①a selftest 표(D12 — r2 — A-2) |
| cred | D5(모드 판정 포함) | 이름 · 꼴 | `[env]` · `[guard]` |
| identify | `page.goto('/')`(감싸개) → 이메일 상수 → 제출 | 비밀번호 단계 표식 | `[product]` |
| password | `secret-input` → 제출 | TOTP 단계 표식 | 단계가 안 넘어가면 `[guard]` + 잠금 표식(D10 ⑦) |
| totp | 경계 대기 → 코드 → 제출 | 로그인 완료 | 같음 |
| landed | — | origin + pathname = `/if/user/`(쿼리 출력 0) | `[product]` |
| sessions | Sessions 화면(경로 · 선택자 — VD-T081-a) | **`const n = await rows.count()` → `expect(n, 'sessions rows').toBe(1)`** — 로케이터 단언 0(aria snapshot · 받은 텍스트가 실패 메시지에 실리지 않게 — r1 — B-4 (a)). 증거 스크린샷은 evidence helper(D10 ⑨) | n ≥ 2 → `[state] residual-sessions n=<n>` |
| state-mem | `context.storageState()`를 **메모리 객체로** 받는다(r1 — B-5 ①) | Authentik 세션 쿠키 이름이 있다(이름 = VD-T081-a) · 개수만 출력. 쿠키 도메인 집합 판정은 **INFO**(Cloudflare `__cf_bm` 등 — r1 — A-12) | `[product]` |
| logout | Authentik 무효화 흐름(VD-T081-a) | 로그인 화면으로 돌아옴 | `[product]` |
| state-dead | 메모리의 상태를 `e2e/.auth/<runId>-t077.json`에 쓴다(이제 죽은 세션) → 그 파일로 새 컨텍스트 → `/if/user/` | 로그인 흐름으로 돌려보내진다 | `[product]` |
| cleanup(fixture teardown · 늘) | 세션이 섰는데 logout에 못 갔으면 로그아웃 시도(실패해도 값 출력 0) · 파일 삭제 · 메모리 상태 버림 | 파일 없음 | — |

- 디스크에 살아 있는 세션이 한 번도 놓이지 않고 문면 「storageState `e2e/.auth/`」도 지킨다 〔77-14〕.
- 소셜 로그인(AC1)은 스펙 밖 — 운영자 1회 + 스크린샷(D10 ⑨ 규칙 · T085).
- 부수 효과(추론): logout은 웹훅으로 dev · prod에 e2e 사용자의 사용자 단위 폐기와 30일 하한을 남긴다(identity-admin-api.md:59 · :66). 그보다 먼저 시작한 BFF 세션은 inactive가 되므로 T079는 T077 뒤에 새 세션을 연다(파일 순서 · workers 1 · TOTP 경계 대기).

### D7 T079 `e2e/revocation.spec.ts` 흐름 — (A) BFF 프록시(T077-c 확정)
- 모든 `request` · 탐색 호출은 `http.ts` 감싸개 · `pace()`(앞 호출과 ≥ 200 ms — plan A32 · VD-3)를 지난다.
- **공통 단계**:
  1. reach-auth — D6 reach와 같다.
  2. chain — `JT_E2E_CHAIN` → base · ns.
  3. reach-bff — `GET <base>/api/health` → 200 JSON `upstream: identity-admin`(bff-api.md:35)이면 PASS. 분류(r2 — A-2 · V-9): dev 연결 거부 → `[env] dev-chain-server-absent — T092 · T085 · dev 서버 미기동` · 52x와 그 밖 5xx → `[env] origin`(D6 reach와 같다) · prod에서 그 밖 응답(apex가 아직 v1인 경우 포함) → `[env] prod-chain-not-bff — T094 전`(체인 부재) · dev에서 그 밖 응답 → `[product]`. **어느 갈래도 `[gate]`가 아니다** — D5 `[gate]`는 Traefik 404 서명 · Ingress · Job 부재뿐이고, T079의 빨강 증거는 reach-auth의 `[gate]`다(D9 ④). 사례는 ①b selftest(D12).
  4. cred — D5.
  5. bff-login — 브라우저 `<base>/api/auth/login` → Authentik 흐름(D6 identify–totp) → callback. callback URL의 `code` · `state`는 출력 0 · `waitForURL`은 감싸개(origin + pathname만).
  6. baseline — `GET <base>/api/session` 200 → `GET <base>/api/proxy/identity-admin/tenants/me` 200 + `role: "member"`(T083 seed_tenant — FR-036) 〔77-7〕.
  7. copy — `context.cookies()`에서 `jt_session` · `jt_csrf` 사본을 메모리에만(파일 0).
- **probe 꼴(r1 — A-17 · A-13 ⓑ)**: 호출마다 **새 요청 컨텍스트**를 만들고 사본 쿠키를 **명시 `Cookie` 헤더**로 싣는다(첫 401 응답의 쿠키 삭제가 사본을 비우지 않게 · `Secure` 쿠키의 jar 동작에 기대지 않게). 쓰고 나면 컨텍스트를 버린다.
- **probe 판정 글자(r1 — A-4)**: 401 · `content-type`이 `application/problem+json` · 본문 `type` **정확히** `https://joshuatech.dev/problems/session-revoked`(밑줄 → 하이픈 — bff-api.md:87 · pod-template.md:85). 밑줄 꼴 `session_revoked` 문자열 일치는 FAIL. 층위 INFO: 본문에 `request_id` 없음 = pod 401을 BFF가 중계(bff-api.md:90) · 있음 = BFF 자신의 401. BFF 실제 꼴은 VD-T092-a.
- **시험 1 · AC3**:
  - 창 시작 = **logout 요청 직전 UTC**(t0)(r1 — A-3 ①).
  - logout — `POST <base>/api/auth/logout` `{ "all_devices": true }` + `x-csrf-token`(bff-api.md:22 · :32) → 204. `all_devices: true`로 UD-7과 떼어 낸다(교환 토큰에 `sid` 없음 — denylist.md:23).
  - wait — 응답 시각 + 1000 ms → probe 1회 → 위 판정. 층위 둘 다 합격(같은 isolate = pod 401 중계 · 다른 isolate = BFF 폐기 확인 401 — 추론 · VD-T092-a).
  - 401이 아니면 FAIL + 진단 INFO: ≥ 500 ms 간격으로 10 s까지 다시 물어(호출마다 새 컨텍스트) 첫 401 시각을 기록(SC-003 자료 — 측정 합격선은 T085).
  - log-reason — `kubectl-log`(아래)로 `--since-time=<t0>` 읽기 → 판정: JSON 줄 중 `event` = `session_revocation.recorded` · **`source` = `revoke` · `reason` = `logout_all`** · `ts`(모든 줄의 ISO 8601 UTC — pod-template.md:81)가 [t0, t0 + 10 s + 시계 여유 2 s] 안인 줄 ≥ 1(identity-admin-api.md:140). 출력은 개수 · 시각뿐(원시 줄 · sub_hash · IP 0).
  - cleanup — Authentik 세션 로그아웃 · 사본 변수 지움.
- **시험 2 · AC4**(UD-4 결정 상수 `AC4_PATH`):
  - `'undecided'`(기본)면 reach-auth · chain 뒤 `[decision] UD-4 undecided — AC4 path (user decision before T081)` FAIL. 권고 B(t073-design.md:2493 — r1 — A-16)로 정해지면 T081 커밋이 `'authentik-logout'`으로 바꾼다.
  - `'authentik-logout'` 흐름: 공통 단계 → **간격**: 시험 1 cleanup의 Authentik 로그아웃(이것도 `authentik_webhook` 기록을 만든다 — dev는 쓰기 비활성이라도 기록은 생긴다)과 이 시험의 로그아웃 사이를 웹훅 지연 상한보다 길게(기본 15 s · VD-T081-b로 보정)(r1 — A-3 ①) → 창 시작 t1 = Authentik 로그아웃 직전 UTC → 브라우저에서 e2e 사용자가 직접 로그아웃(관리 토큰 0) → 완료 시각 + 2000 ms → probe.
  - **AC4 PASS 조건(r1 — A-3 ②)**: probe 401(위 판정) **그리고** log-reason 줄 = `source` = `webhook` · `reason` = `authentik_webhook` · `ts` ∈ [t1, t1 + 2 s + 시계 여유 2 s]. BFF 층 401(`request_id` 있음)은 이 로그 시각 조건을 함께 만족할 때만 PASS다 — Authentik 로그아웃이 OAuth 토큰을 끝내면 웹훅 없이도 refresh 실패로 401이 날 수 있다(VD-T081-c).
  - 문면의 「Authentik 관리 API로 세션 삭제」는 스펙 밖 — 운영자 수동 + 스크린샷(R30) · UD-4 증거 기록만 〔77-3〕.
- **`kubectl-log`(r1 — B-11)**: `kubectl.exe`를 PATH에서 직접 찾는다(빈 · 상대 · `.` 항목 제외 · cwd 제외) → 절대 경로 · 저장소 루트나 `os.tmpdir()` 아래면 `[guard]`로 멈춤 → `shell: false`. 자식 env = 허용 목록(`PATH` · `SystemRoot` · `KUBECONFIG` · `USERPROFILE` · `TEMP`). 먼저 `kubectl auth whoami`가 agent-view가 아니면 멈춘다. 인자 = `--kubeconfig <KUBECONFIG> --request-timeout=20s -n jt-<env> logs deploy/identity-admin -c web --since-time=<창 시작>`. 파싱 예외는 원시 줄 없이 다시 던진다.
- **2단계 표기**: `INFO t079 chain=<dev|prod> stage=<1|2>`. T085가 둘 다 돈다.

### D8 T078 `tests/platform/identity.tests.ps1`
1. **관례**(〔R2 2-5〕): 머리 주석(경로 · US · 과제 · test-first · `Run:` · 러너 · exit 규약 · 출력 꼴 · 자체 완결 · §1-2 표) · `PASS|FAIL|SKIP <id> -- <근거>` · 끝 줄 `N passed, N failed, N skipped` · fail > 0이면 exit 1 · 단언 격리(`Test-Group`) · 헬퍼는 같은 이름 · 같은 동작으로 복사 · kubectl은 `--kubeconfig` · `--request-timeout` · get · logs · auth whoami만 · 출력 가림.
2. **게이트**: gate-1..3 실패 → kubectl 단언만 그 사유로 FAIL · HTTP 단언은 계속 돈다.
3. **curl 해석 · 호출(r1 — A-5)**:
   - 실행 파일 = `Get-Command curl -CommandType Application`의 첫 해석 경로를 한 번 정한다. 형식 필터 없는 `Get-Command curl` 첫 해석이 Application이 아니면(함수 · 별칭 가림) tool-1 FAIL. tool-1 판 검사도 같은 경로로 한다.
   - 호출 꼴(글자 고정): `<그 경로> -q -s -S --max-time 20 --proto =https -o <임시 본문> -w @<임시 형식 파일> <url>`. 형식 파일 = `%{http_code}\n%{content_type}\n%{size_download}\n%header{location}\n%header{cf-cache-status}\n`. **argv에 `%`가 없다** — `.cmd` 심을 지나도 글자가 바뀌지 않는다.
   - GET · 리다이렉트 미추적 · 자격 헤더 0 · Location은 `scheme://host/path`만 · 본문은 판정 키만 읽고 출력 0 · 임시 파일 finally 삭제(`%TEMP%\identity-tests-*` 잔존 0) · curl 종료 코드 ≠ 0은 그 단언의 FAIL.
4. **id 표 · 오늘 기대** = §1-2.
5. **교환(xchg-*)**: 자동 발견 하네스에는 agent-view 밖 자격이 없다(tester.md:33 · 〔R3 R9〕).
   - `xchg-0` = 토큰 엔드포인트 도달만(무자격 GET).
   - 판정 함수 `Test-ExchangeClaims` · `Test-ExchangeRejection`을 이 파일에 둔다: aud = `identity-admin`(문자열 또는 원소 하나 배열) · `tenant_id` 정규 uuid 꼴 · `exp − iat` = 300 · `$Vd1Option` `'B'`(기본)면 `act` 유무 무관 · `'A'`면 `act.sub` = web-bff client · `iss` INFO · 거부 = 400 · `error` = `invalid_target`(RFC 8693 §2.2.2 · **실제 코드는 VD-T081-d** — r1 — A-13 ⓐ). JWT 값 출력 0.
   - 라이브에서는 함수를 부르지 않고 `SKIP xchg-1` · `SKIP xchg-2`. 자격 블록은 이 함수의 바이트 사본으로 판정한다. 블록 설계에는 PKCE verifier를 블록이 쥐는 안을 권고한다(〔R3 ④ T78-B〕) 〔77-6〕.
6. **OpenFGA(fga-*)**: 지금 Job은 id 둘(`check-allowed` · `cross-tenant-false`) · 합성 · 렌더 밖. 새 id 넷을 단언한다(build-notes.md:337 선례 · T082와의 계약). 판정 = `Test-JobLog` 꼴(id마다 RESULT 정확히 1 · SUMMARY 수 일치 · 추적 밖 FAIL도 문제 · `--tail=50` · `EVIDENCE:` 비전재). 데이터 = 합성 owner 튜플을 쓰고 지움 〔77-12〕.
7. **빈 PASS 방지**: acc-1은 ing-1 짝 필수(엣지 302 — ingress.tests.ps1:24–26) · 공개 200은 미디어 타입 + 구조 키 · 리다이렉트 미추적 · SKIP 문구는 「자격 블록 전용」 · 「운영자 수동」 둘뿐 · 소유 과제 게이트 0(cluster.tests.ps1:25–27).
8. **러너 · 짝 하네스**:
   - CI 영향 0. run-all `platform`: KUBECONFIG 없으면 SKIP · 이 환경은 infra [plan]에서 먼저 멈춤(정정 노트 25) · KUBECONFIG + infra 통과 환경에서는 T085 전까지 FAIL(T050 선례 — §5 위험 1).
   - 짝 하네스 `tests/scripts/identity-tests.tests.ps1`: 가짜 kubectl(`.cmd` 심 + 응답표) · **가짜 curl = data-tests의 `FAKE_KUBECTL_ARGV` 꼴(`curl.cmd` 심 → `FAKE_CURL_ARGV`)** · 응답표(오늘 · T080 뒤 · 변이) · 형식 파일을 읽어 그 순서로 `-w` 결과를 낸다 · 실제 kubectl · curl 디렉터리는 PATH에서 뺀다 · 순수 함수는 AST로 표 시험 · env `IDENTITY_HARNESS_SCRIPT` · `IDENTITY_HARNESS_TESTS_ONLY` 접미(r1 — A-5).
   - **반드시 넣을 사례**: 처음 찾히는 curl · kubectl이 픽스처 심인지(아니면 실행 거부) · **argv 단언**(`-q` 첫 인자 · `--proto =https` · `-w @<파일>` · 금지 플래그 0: `-L` · `-k`/`--insecure` · `-H` · `-u` · `-b`/`--cookie` · `-x`/`--proxy` · `-K`/`--config` · `-d`/`--data*` · `-X`) · 오늘 상태 → §1-2(사유 글자까지) · T080 뒤 상태 → 해당 id PASS · acc-1: 302 + Ingress 없음 → FAIL · Location 다른 호스트 → FAIL · 쿼리 출력 0 · **403 + Ingress → PASS · 403 + Ingress 없음 → FAIL**(r1 — A-8) · 공개 200 `text/html` → FAIL · JSON인데 판정 키 없음 → FAIL · curl exit 6 · 7 · 28 → 사유 FAIL · Job: 없음 · 옛 id만 · 중복 · SUMMARY 불일치 · 추적 밖 FAIL → FAIL · 교환 판정 표(aud 배열 · 다른 aud · `tenant_id` 없음 · 꼴 아님 · 299/301 · B에서 `act` 있음 PASS · A에서 `act.sub` 다름 FAIL · 깨진 JWT · `invalid_target` 아님) · 노출 0(합성 토큰 바늘이 출력 · 임시 파일에 없음) · kubectl 게이트 실패 → kubectl 단언만 FAIL.
   - run-all 슬롯 `identity-harness`(kafka-harness 뒤 · 양성 증거 규율) — **컨트롤러가 등록**(r1 — A-14).
9. **운영자 수동**: man-1 · man-2 상시 SKIP.

### D9 빨강 확인 · tick
- **누가**: 빌더는 오프라인 시험만(selftest · selftest-browser · needle · list · 짝 하네스). **빌더의 공개 라이브 호스트 0은 이 설계의 결정이다**(web-builder.md에는 그 금지가 없다 — r1 — A-16). 라이브 빨강은 컨트롤러가 한 번 관찰한다(T060 선례 — build-notes.md:647 · :654).
- **런처 `e2e/lib/launch.mjs`(r1 — A-6 · B-14 · A-7 · r2 — V-2 · V-3 · V-4 · V-6)** — Node 내장 모듈만. 공통: runId · 블록 소유 루트 `os.tmpdir()/jt-e2e/<runId>`(outputDir · evidence · 로그 · **자식 `TEMP`/`TMP`**가 그 아래 — TS 변환 캐시 · 브라우저 임시 파일도 루트 안에 생겨 함께 지워진다 · G-3과 같은 꼴 · r2 — V-6) · 자식 env = 아래 허용 목록 + 모드 값 · 실행 파일 = `process.execPath` · 인자 = [`@playwright/test` CLI의 절대 경로(해석 방법 VD-T077-3), `test`, `--config`, <루트 `playwright.config.ts` 절대>, `--project=<p>`] · `shell: false` · stdout · stderr를 루트 안 파일로 받는다 · finally에서 루트 삭제 + 존재 0 확인 · 끝 줄 하나로 판정 · 종료 코드.
  - **자식 env 허용 목록(r2 — V-3 · V-4)**: 기본 이름 `SystemRoot` · `PATH` · `USERPROFILE` · `LOCALAPPDATA`(잠금 표식 자리 대조 — D10 ⑦) · `TEMP` · `TMP`(값 = 루트 아래) + 런처 공통 `JT_E2E_RUN_ID` · `JT_E2E_ROOT` · `JT_E2E_OUTPUT_DIR` · `JT_E2E_EVIDENCE_DIR` + 모드 값(아래). 최종 이름은 VD-T077-3(더하는 이름은 자격 · 프록시 · 디버그 꼴이 아닌 것만). **`KUBECONFIG` · `JT_E2E_BLOCK`은 어느 모드에서도 0**이고, `JT_E2E_SECRET_*` · `JT_E2E_NEEDLE_SET`은 `needle` 모드의 런처 생성 바늘로만 들어간다.
  - **출력(r2 — V-2)**: 런처는 static-gate의 이름 붙은 예외다(D10 ⑤). 판정 줄 · env 이름 · 수만 내고 값은 내지 않는다.
  - `selftest` → `--project=selftest`(브라우저 0). `@playwright/test`가 없으면 첫 줄 `SKIP e2e-selftest tests -- @playwright/test not installed` + exit 0. 끝 줄 `<n> passed, <m> failed`(list 리포터 요약을 파싱 · 파싱 실패 = exit 1).
  - `selftest-browser` → `--project=selftest-browser`.
  - `needle` → 바늘을 실행마다 만들어(D10 ⑧) `JT_E2E_NEEDLE=1`과 함께 자식 env로만 넘긴다 · D10 ⑧(두 실행 + 스캔) · 끝 줄 `needle=PASS|FAIL …`(면별 hits 수)(r2 — V-6).
  - `list` → `JT_E2E_LIVE=1` · `JT_E2E_NEEDLE=1`을 따로 준 `--list` 두 번(동시 금지 — D3) → 프로젝트별 수.
  - `live-red` → env = 허용 목록 + `JT_E2E_LIVE=1`(**`KUBECONFIG` · `JT_E2E_SECRET_*` · `JT_E2E_BLOCK` · `JT_E2E_NEEDLE_SET` 0**) · 시작 전에 자식 env **이름 목록**을 낸다(증거 — 위 허용 목록과 정확히 같아야 한다 · r2 — V-3) · `--project=live` · 단계 줄 · 요약 · `INFO auth-residue 0` 줄 확인(컨트롤러 — N-3).
- **T077 · T079**(공개 HTTP만 · 클러스터 0 · 자격 env 0):
  1. `node e2e/lib/launch.mjs selftest` · `selftest-browser` → 실패 0.
  2. `node e2e/lib/launch.mjs needle` → `needle=PASS`.
  3. `node e2e/lib/launch.mjs list` → T077: live 1 · T079: live 3(r1 — A-9).
  4. `node e2e/lib/launch.mjs live-red` → exit 1 · 모든 live 시험이 `reach`/`reach-auth`에서 `[gate] authentik-absent until T080`(서명 전체 일치).
  5. 뒤 확인 — `e2e/.auth/` 0 · 루트 삭제 · 잠금 표식 0 · `git status --porcelain`이 지정 파일뿐.
- **T078**: 짝 하네스 두 번 `N passed, 0 failed` · 라이브 = 운영자 터널 + agent-view 8h 토큰이 있는 창(Vault 0)에서 컨트롤러가 `chcp.com 65001 >/dev/null; pwsh -NoProfile -File tests/platform/identity.tests.ps1`(T076 정정 노트 8) → 줄마다 §1-2와 대조. **창 = 가장 가까운 운영자 창(다음 터널 세션 또는 12-06 UD-13a 창)** — UD-13b 관문(K3s v1.36.7 미발행)에 묶지 않는다. T080 착수 전이면 test-first다(T080은 그 관문 뒤라 늘 성립). 관문 창에서는 필요하면 다시 관찰만 한다(r1 — A-10).
- **증거**(build-notes): 명령 · UTC · 판정 줄 그대로 · 수 · exit · 잔여 0 · needle 결과 · live-red env 이름 목록(= 런처 live-red 허용 목록과 정확히 같다 — r2 — V-3).
- **tick**: T077 · T079 — §1-1 셋을 채우면 각각. T078 — 짝 하네스 초록 + 라이브 줄이 §1-2와 같을 때. 다른 이유의 FAIL(`[env]` · `[guard]` · gate 실패)이거나 표와 다르면 tick하지 않고 원인을 본다. 새 편차는 사용자 결정(t076-design.md:161 꼴).

### D10 노출 0 · 정리 — 자격 실행 단계의 요구를 지금 코드에 박는다
1. **기록 끄기**: D3 + `config-hygiene` + globalSetup 재단언(런타임 덮기 — r1 — B-3 ①).
2. **http 감싸개 `e2e/lib/http.ts`(r1 — B-1)**: 모든 `request.*` · `page.request` · `context.request` · `goto` · `waitForURL` · `waitForResponse`가 이것을 지난다. 예외면 `<METHOD> <origin+pathname> failed (<오류 코드|status>)`만 담은 **새 오류**로 다시 던지고 `cause`를 잇지 않는다(call log = 요청 · 응답 헤더 · 쿠키 · 탐색 URL이 메시지에 실리지 않게 — playwright-core `server/fetch.ts`). `toBeOK()` 금지 — `response.status()`를 수로 비교한다.
3. **비밀 입력 `secret-input`**: `fill`을 감싸 예외면 칸을 비우고 값 없는 새 오류(원래 오류 객체 · message를 넘기지 않는다 — B-1 ①). step 제목 · `console` 0.
4. **단언 위생**: URL은 origin + pathname(`.url(` 읽기는 `http.ts`의 helper 하나만 — origin + pathname만 돌려준다 · ⑤의 「`http.ts` 전용」 목록에 `.url(`을 더한다 · 컨트롤러 — N-4) · IP · UA 칸은 개수 단언만(로케이터 단언 0 — D6) · problem 본문은 `type` · `request_id` 유무만. 집행 = ⑤ 「어디서나 0」의 단언 · 추출 목록(r2 — V-5).
5. **static-gate selftest(r1 — B-3 ② · r2 — V-2 · V-5 · V-6)**: `e2e/**` · 루트 config 소스를 본다.
   - **어디서나 0**: `tracing.` · `recordHar` · `routeFromHAR` · `recordVideo` · `.attach(` · `page.pause` · `on('request'` · `on('response'` · `on('console'` · `toBeOK(` · **값을 실패 메시지에 싣는 단언 · 값 추출(④ 집행 — r2 — V-5)**: `toHaveURL(` · `toHaveValue(` · `inputValue(` · `toHaveText(` · `toContainText(` · `toMatchAriaSnapshot(` · `textContent(` · `innerText(` · `allTextContents(` · `allInnerTexts(` · `waitForRequest(` · `waitForNavigation(` · `waitForEvent(`.
   - **이름 붙은 파일에서만**:
     - `console.` · `process.stdout` · `process.stderr` → **출력 통로 `e2e/lib/out.ts`**(미리 정한 꼴의 줄만 받는다 — 단계 줄 · INFO 줄 · 요약 줄 · 기계 판독 부분(첫 ` — ` 앞)이 ASCII가 아니거나 줄바꿈이 들면 throw — D5) + **이름 붙은 예외 셋** `e2e/lib/launch.mjs` · `e2e/lib/scan-needle.mjs` · needle-control 변이 스펙 1파일(경로는 ①a가 D4 정확 집합과 같은 글자로 적는다). 예외 셋의 출력은 판정 줄 · env 이름 · 수만이다(needle-control은 대조 바늘 한 줄 — 양성 대조의 목적 · ⑧)(r2 — V-2).
     - `storageState({ path` → `auth-dir` · `screenshot(` → evidence helper · `process.env.JT_E2E_SECRET_` · `process.env.JT_E2E_NEEDLE_SET` → `env-contract.ts` · `request.` · `goto(` · `waitForURL(` · `waitForResponse(` → `http.ts` · 바늘 접두 `JTNEEDLE-` → `launch.mjs` · `env-contract.ts`(꼴 상수뿐 — ⑧ · r2 — V-6).
   - r1의 「예외 목록은 정확히 이름 붙은 파일뿐(needle-control 1개)」은 위 이름 붙은 파일 목록으로 바뀐다(r2 — V-2). 검사기와 selftest는 패턴 · 접두를 조각으로 조립해 자기 매치를 피한다.
6. **파일 · 서버 쪽 무효화**: storageState는 죽은 상태만(D6) · T079 파일 0 · 삭제 세 겹(시험 teardown → globalTeardown → 블록 finally `Test-Path`) · 파일 삭제는 세션을 끊지 않는다(〔R3 ① 7〕) → T077 Authentik 로그아웃 + state-dead · T079 `logout_all` + Authentik 로그아웃 · 블록이 얻은 토큰의 RFC 7009는 블록 몫.
7. **로그인 잠금 표식 `login-lock`(r1 — A-11 · B-6 ① · r2 — V-4)**: 비밀번호 · TOTP 단계가 안 넘어가면(자격 거부 표식 — VD-T081-a) 표식 파일(비밀 0 — 단계 · UTC · runId)을 남긴다.
   - **자리 = `<토큰 홈>\AppData\Local\jt-e2e-lock\e2e-login-lock.json`**. 토큰 홈 = `os.userInfo().homedir`(프로세스 토큰의 프로필 — env에 기대지 않는다 · `os.homedir()`는 `USERPROFILE` env를 먼저 본다 — 추론 → VD-T077-3). env `USERPROFILE` · `LOCALAPPDATA`가 있으면 각각 `<토큰 홈>` · `<토큰 홈>\AppData\Local`과 대조하고(정규화 · 대소문자 무관) 어긋나면 `[guard] profile-env-mismatch`(D3 ④와 같은 범위 — `JT_E2E_LIVE=1` 실행은 멈추고 그 밖은 INFO). 그래서 표식을 쓰는 실행과 확인하는 실행이 늘 같은 자리를 본다. r1의 「`LOCALAPPDATA` 기준 — env로 바꿀 수 없다」는 거짓이라 고쳤다.
   - O-9 DPAPI JWT 디렉터리(`%LOCALAPPDATA%\jt-e2e\` — t076-blocks/o9-issue-vault-jwt.ps1:119–120)와 **다른 디렉터리**다 — O-9 `clear`와 이 표식이 서로 닿지 않는다.
   - 저장소 밖 · `.auth/` 수명 밖. 실행을 넘어 남는다 — globalSetup · globalTeardown은 지우지 않고, 있으면 live를 시도하지 않는다(D3 ④). **운영자가 원인(Vault 값 · TOTP 재등록 · Reputation)을 확인한 뒤에만 지운다**.
   - 자리 규칙이 쓰는 env 이름(`USERPROFILE` · `LOCALAPPDATA`)은 런처 허용 목록(D9)과 블록 허용 목록(§5-1 G-3)에 있다. selftest는 (토큰 홈 · env 값 · 디렉터리)를 인자로 받는 순수 함수만 시험한다(어긋남 → `[guard]` 사례 포함).
8. **바늘 시험(r1 — A-6 · B-1 ⑤ · B-4 ③ · B-10 · r2 — V-6)** — 런처 `needle`:
   - **바늘은 런처가 실행마다 만든다(r2 — V-6)** — 꼴만 고정하고 값은 난수다: 비밀번호 `JTNEEDLE-pw-<12 hex>` · 코드 창 = 6자리 난수 N개 · 가짜 IP `203.0.113.<1–254 난수>`(RFC 5737 문서용 대역) · 가짜 UA `JTNEEDLE-UA/<hex>` · 바늘 쿠키 · 바늘 authorization · 바늘 쿼리 · 대조 바늘 `JTNEEDLE-ctl-<hex>`. 자식에게는 env로만 넘긴다(`JT_E2E_SECRET_*` · `JT_E2E_TOTP_STEP0` · `JT_E2E_NEEDLE_SET` — D5). 스캔에는 런처 메모리의 값을 함수 인자로 넘긴다(파일 · argv 0). **소스 · fixture · selftest 기대값에 바늘 값 리터럴 0** — 실패 출력의 코드 프레임과 Playwright TS 변환 캐시(추론 — 자식 `TEMP` 아래)에 바늘이 실리지 않게 한다. Sessions 꼴 표 · 로컬 서버 응답도 env 값으로 그린다. r1의 고정 바늘 상수(`JTNEEDLE-pw-7f3c…` · `918273,…` · `203.0.113.77` · `JTNEEDLE-UA/1.0`)는 지운다.
   - 실행 1 `--project=needle`(`JT_E2E_NEEDLE=1`) — 로컬 페이지 · 로컬 `node:http` 서버만. **의도 실패 정확히 7건**, 메시지는 런처의 기대 목록과 정확히 일치: nd-1 입력 자체 실패 · nd-2 제출 뒤 단계 전환 실패 · nd-3 연결 끊김(요청에 바늘 쿠키 · authorization) · nd-4 500(같음) · nd-5 바늘 쿼리 URL `waitForURL` 시간 초과 · nd-6 Sessions 꼴 표(가짜 IP · UA) 행 수 불일치 · nd-7 mask 대상 0 → 찍지 않음 `[product] mask-target-missing`. 브라우저 부재 같은 다른 실패는 메시지가 달라 FAIL로 판정된다.
   - 실행 2 `--project=needle-control` — 대조 바늘(`JT_E2E_NEEDLE_SET`의 대조 값)을 `console.log`로 일부러 내는 변이 스펙(static-gate 이름 붙은 예외 — ⑤). 스캔이 이것을 **로그 면에서** 잡아야 한다(양성 대조).
   - 스캔 `scan-needle.mjs`: 바늘 꼴 = 전체 · base64 · base64url · 8자 이상 조각(**난수 부분이 든 조각만** — 고정 접두 `JTNEEDLE-…`만으로 된 글자는 세지 않는다 · env-contract의 꼴 상수가 코드 프레임에 실려도 거짓 FAIL이 나지 않게 · r2 — V-6) · SHA-256 hex(대소문자) + **6자리 코드와 가짜 IP · UA는 전체 일치**(8자 규칙 밖). 검사 면 = 실행 stdout · stderr 로그 · 블록 루트 전체(자식 `TEMP` 포함 — D9) · 저장소 `test-results/` · `e2e/.auth/` · `%TEMP%\playwright*` · `git status --porcelain --ignored -- e2e test-results playwright-report blob-report`. 출력은 면별 hits 수뿐(일치한 글자 0).
   - 실행 1 판정의 바늘 묶음 = **대조 바늘을 뺀 묶음**(두 실행이 같은 루트에 로그를 남기므로 — 또는 실행마다 루트를 따로 만든다 · 빌더가 하나를 고르고 selftest로 고정 · 컨트롤러 — N-1).
   - 판정 `needle=PASS` = 실행 1이 exit 1 · failed 정확히 7 · 메시지 7 정확 일치 · 실행 1 hits 0(**모든 면**) · 실행 2 대조 hits ≥ 1 **로그 면(stdout · stderr)에서**. 대조가 다른 면에서만 잡히면 FAIL이다(빈 양성 대조)(r2 — V-6). 끝 줄에 면별 hits 수를 싣는다.
   - selftest `scan-needle`(브라우저 0): 인코딩마다 로그 · 파일에 심으면 hits ≥ 1 · 심지 않은 대조는 0 · 고정 접두만 든 글자는 0(r2 — V-6). 바늘은 시험 안에서 만든다(리터럴 0 · 접두는 조각 조립).
   - Playwright 판을 올릴 때마다 다시 돈다(README · §5-1 G-4).
9. **증거 스크린샷 규칙(r1 — B-4 ② ④)**: evidence helper는 mask 로케이터마다 `count()`가 표 행 수(≥ 1)와 같을 때만 찍고, 아니면 찍지 않고 `[product] mask-target-missing`. 파일은 `JT_E2E_EVIDENCE_DIR`(저장소 밖)에만 · 커밋 0 · 보고에는 파일 이름 · SHA-256 · 가린 칸 목록만. 운영자 스크린샷(AC1 소셜 · `argocd --sso` · 관리 API)은 운영자가 가린 뒤 넘기고 같은 규칙을 따른다 〔77-15〕.

### D11 CI · run-all
- **T077-d의 CI 영향**: 루트 의존성을 설치하는 job은 셋이다 — `lint`(ci.yml:329) · `test`(:373) · `events-test`(:622), 모두 `pnpm install --frozen-lockfile --ignore-scripts`. 셋 다 이제 `@playwright/test` · `playwright` · `playwright-core`를 설치한다(선택 의존성 `fsevents`는 linux에서 설치 0). **브라우저 0** — 설치 단계가 없고 `--ignore-scripts`(playwright 1.65.1에 설치 스크립트 없음 — registry). `setup-node` `cache: pnpm`은 lockfile 해시가 바뀌어 한 번 캐시 미스. events-test 명령 · peer 집합 불변(D2-2) · PR #2 CI 초록으로 확인.
- **e2e CI job은 더하지 않는다**: live는 공개 prod Authentik과 자격이 필요하고 SP-1 CI에는 자격이 없다(FR-044) · ci.yml은 게이트 파일이다 · 웹 CI E2E는 T087 · T093이 연다(`site` 프로젝트 · live 제외).
- **판 올림의 안전**: Renovate가 루트 `@playwright/test`를 올리는 PR(정확 핀 · 숙성 3일 · `automerge: false`)은 CI에서 Playwright를 돌리지 않는다. 대신 자격 블록이 `package.json` · lockfile · 브라우저 해시를 고정하므로 판이 바뀌면 블록이 비밀을 넘기지 않는다 → needle 재실행 · 브라우저 해시 재기록 · 블록 해시 갱신(리뷰) 뒤에만 자격 실행(§5-1 G-3 · G-4)(r1 — A-7).
- **run-all 슬롯 `e2e-selftest`(컨트롤러 등록 · r1 — A-7 선택안)**: `node e2e/lib/launch.mjs selftest` — 브라우저 0 selftest(config-hygiene · static-gate · tracked-files · 순수 함수 · scan-needle 양성 대조). 없으면 SKIP 허용(backup-verify 꼴 — run-all.ps1:83–92) · 그 밖에는 exit 0 + `^\d+ passed, 0 failed$`.
- **인계(r1 — B-4 (d))**: T087 · T093의 Playwright job은 test-results · report · trace를 **아티팩트로 올리지 않는다**(공개 저장소).

### D12 빌드 조각 · 담당 · TDD · 커밋

| 조각 | 빌더 | 파일(소유) | 시험(먼저) |
|---|---|---|---|
| ①a T077 기반 + 로그인 | web-builder(opus) | 루트 `package.json` · `pnpm-lock.yaml` · `playwright.config.ts` · `.gitignore`(**조각 범위로 명시 — web-builder 영역 밖이라 지시문에 적는다**) · `e2e/{global-setup,global-teardown}.ts` · `e2e/lib/**`(①a 몫) · `e2e/selftest/**` · `e2e/selftest-browser/**` · `e2e/needle/**` · `e2e/auth.spec.ts` · `e2e/README.md` | selftest 먼저 써서 빨강(헬퍼 없음) → 헬퍼 → 초록 · needle PASS · list · events-test 초록 · D2-5 출력 보고 · **selftest 필수 사례(r2 — A-2)**: reach 분류 표 = 서명 전체 일치 → `[gate]` · 522 · 525 · 503 → `[env] origin` · 404이지만 18 B · 다른 sha256 · `text/html` · `cf-cache-status: HIT` 중 하나 → `[product] reach-unexpected`(`[gate]` 0) · Access 302/401 → `[product]` · Authentik 범주 → PASS |
| ①b T079 | web-builder(①a 뒤 같은 빌더) | `e2e/revocation.spec.ts` · `e2e/lib/{bff,kubectl-log}.ts` · selftest 추가(BFF 분류 표 — 200 계약 꼴 → PASS · dev 연결 거부 → `[env] dev-chain-server-absent` · 52x/5xx → `[env] origin` · prod 비계약 → `[env] prod-chain-not-bff` · dev 비계약 → `[product]` · 어느 갈래도 `[gate]` 0(r2 — A-2) · problem `type` 밑줄 꼴 FAIL · 로그 선택: 창 · source · reason) | selftest 빨강 → 초록 · list |
| ② T078 | infra-builder(opus · ①과 병렬 · Playwright 설치와 독립) | `tests/platform/identity.tests.ps1` · `tests/scripts/identity-tests.tests.ps1` | 짝 하네스 먼저 빨강 → 하네스 → 두 번 초록 |

- run-all 슬롯 둘(`e2e-selftest` · `identity-harness`)은 **컨트롤러**가 등록한다(data-tests.tests.ps1:4–5 선례)(r1 — A-14).
- 지시문에 넣을 계약 절: ①b = bff-api.md §엔드포인트(logout · proxy · health) · §하류 호출 규약 · **§오류 형식** + pod-template.md 「오류」 행 · identity-admin-api.md 로그 이벤트(:140) · pod-template.md 「로그」 행(`ts`)(r1 — A-4 · A-3). web.md는 `e2e/**`에 걸리지 않으므로 D3 · D5 · D10을 넣는다.
- 빌더 커밋 0 · 컨트롤러가 파일 이름으로 스테이징 · push는 사용자 확인 뒤.
- 리뷰 세 렌즈: A 정합 · 문면 · B 노출 · 자격(D5 · D10 · Vault 0 · 에이전트 층 0 · needle 결과) · C 하네스 변이 · lockfile 변화 범위(D2-5 ③) · events-test 방어 · CI install.
- 커밋: 과제마다 하나 — T077(①a + 기록) · T079(①b) · T078(②). tick은 빨강 관찰 뒤 · T078은 운영자 창 뒤라 늦으면 tick만 담은 문서 커밋을 따로(T076 선례). 학습 로그는 tick 때.

## 3. VD(검증 후 결정)

| VD | 무엇 | 언제 · 어디서 | 어긋나면 |
|---|---|---|---|
| VD-T077-1 | 오늘 `auth.` 무자격 응답 = Traefik 404 서명 전체(D6 reach) | 이 과제 · 빨강 관찰 | 분류기 보정 · tick 보류 |
| VD-T077-2 | `/if/admin/` 무헤더 = 302(또는 403) 꼴 | T078 빨강 관찰 | 기대값을 실측 꼴로(정정 노트) |
| VD-T077-3 | 1.65.1 + `--only-shell` 설치 · 실행 · 리비전 · 크기 · 내려받기 호스트 · ffmpeg 여부 · 새 lockfile 항목 집합(fsevents 포함 여부) · CLI 절대 경로 해석 · 브라우저 env 허용 목록 최종 · **런처 자식 env 기본 이름 최종(r2 — V-3)** · Playwright가 넣는 `NODE_OPTIONS`(D3 globalSetup ①이 이 VD를 가리킨다 — r2 — V-8) · **`os.userInfo().homedir`가 토큰 프로필이고 `os.homedir()`가 `USERPROFILE`을 먼저 보는지(잠금 표식 자리 — r2 — V-4)** | 빌드 ①a | 판 · 플래그 · 가드 재조정 · 사용자 재승인 |
| VD-T077-4 | 노출 바늘 0 — **call log(요청 · 응답 헤더 · 쿠키 · 탐색 URL)** · fill 값 · 실패 산출물 · aria snapshot(r1 — B-1 ⑥ · B-4) · **코드 프레임 · TS 변환 캐시(바늘 리터럴 0 · 자식 `TEMP` = 런처 루트일 때 캐시가 루트 안에 생기는지) · 대조 바늘이 로그 면에서 잡히는지(r2 — V-6)** | 빌드 ①a needle | 감싸개 · 설정 수정 · 자격 실행 금지 |
| VD-T077-5 | 해석된 설정 = D3 | selftest | 설정 수정 |
| VD-T077-6 | CLI 덮기(`--trace` · `--reporter` · `--output` · `--workers` · `--retries`)가 FullConfig 어디에 드러나는가 · globalSetup에서 러너 argv를 읽을 수 있는가(r1 — B-3) | 빌드 ①a(덮기 플래그로 실험 실행 — 자격 0) | 재단언 방식 조정 |
| VD-T077-7 | `e2e\.auth`가 물려받는 ACL(`icacls`)(r1 — B-5 ④) | 첫 자격 실행 전(G-3) | 블록이 ACL을 좁힌 뒤 쓰기 |
| VD-T080-a | 공개 경로 실제 응답 — root config 키 · executor JSON · issuer · JWKS · 토큰 GET 코드 · **루트 `/.well-known/` 서빙 대상(pub-5 후보 — 끝 `/` 없음(RFC 8414 §3) · 있음 두 꼴을 함께 잰다 · r2 — V-10)** · 루트 `/` 리다이렉트 | T080 직후 | 상수 정정 · pub-5 삭제 + 〔77-13〕 |
| VD-T081-a | slug · `user_fields` · 장치 선택 · TOTP 등록 경로 · `totp_seed` 꼴 · Sessions 경로 · 선택자 · 무효화 흐름 · 자격 거부 표식 · 세션 쿠키 이름 · login stage 옵션 | T081 | 스펙 상수 · 블록 설계 |
| VD-T081-b | Authentik `logout` → 웹훅 → 기록 지연(AC4 2 s · 시험 사이 간격 보정) | T085 | UD-4 · SC-003 · 간격 |
| VD-T081-c | Authentik 로그아웃이 OAuth(refresh) 토큰을 끝내는가(r1 — A-3 · A-13 ⓒ) | T081 | AC4 판정 보강 |
| VD-T081-d | 교환 거부의 실제 오류 코드(`invalid_target` 기대)(r1 — A-13 ⓐ) | T081 | xchg-2 판정 함수 |
| VD-T082-a | authz-assert 새 id 넷 · 50줄 안 | T082 | id 표 |
| VD-T085-a | 연속 로그인 `last_t` 거부 0 · 코드 창 20단계 충분 | 첫 자격 실행 | 대기 · 창 |
| VD-T085-b | dev 체인 `http://localhost:3000`에서 브라우저가 `Secure` 쿠키를 받는가 · 명시 헤더 probe가 BFF에 닿는가(r1 — A-13 ⓑ) | T085(1단계) | probe 꼴 |
| VD-T092-a | BFF logout 204 · CSRF · proxy 401 본문(`type` URI · `request_id` 유무) · `/api/health` 꼴 | T092 | T079 상수 · 층위 |

## 4. 문서 · 계약 보정 목록

**지금(빌드 때 — 표식 「T077 보정 2026-11-2x」)**

| 파일 | 고칠 것 |
|---|---|
| `e2e/README.md` | 루트 devDependency · 루트 config · 프로젝트 조건 · 런처 명령 · 산출물 정책 · env 계약(이름만) · `.auth/` 수명(죽은 상태만) · 잠금 표식 · 바늘 · CI 제외 · 「판 올림 = needle 재실행 + 브라우저 해시 재기록」 · 증거 스크린샷 규칙 |
| `.gitignore` | D4 |
| 루트 `package.json` · `pnpm-lock.yaml` · `playwright.config.ts` | D2 · D3 |
| `tests/run-all.ps1` | `e2e-selftest` · `identity-harness` 슬롯 + 주석(컨트롤러) |
| build-notes · 학습 로그 | 「## T077 · T078 · T079」 · `content/tmp/003-t07{7,8,9}/` |

**나중(그 결정 · 과제와 함께)**

| 시점 | 파일 | 고칠 것 |
|---|---|---|
| S-01 개정(§5-1) | tester.md · infra.md · k8s-security.md(`.claude` · `.agents` 바이트 사본) · infra-builder.md · KR 미러 4 | 블록 지명 · 경로 · 「자기 Playwright 자식의 시작 env」 한 갈래 · trace off · finally 정리 · Codex tester 블록 SKIP |
| 같음 | `.claude/settings.json` | `Read(**/.dev.vars*)` · `e2e/.auth/**` 읽기 deny · tester 전용 훅 결정(G-6) |
| 같음 | vault-unseal.md:561 · :574 · hostnames-and-access.md:80 · data-model.md:159 · quickstart.md:81 · policies.tf:16–18 | 블록이 읽고 자식 env로만 · 코드 창 · 낡은 VD-19 주석 |
| T077-b 결정 뒤 | quickstart.md:90 · (a)면 bff-api.md:13 · data-model.md:170–171 · 정책 · vt-16 · eso-dev deny · FR-044 · FR-049 문면 · hostnames-and-access.md:80 | 결정 반영 |
| T081 · T084 | vault-unseal.md:344(PLACEHOLDER) · hostnames-and-access.md:84 · data-model.md:172 · quickstart.md:14(tester-k8s) | T077-e · f 이관 |
| T080 실측 뒤 | identity.tests.ps1 상수 · `lib/reach.ts` · quickstart.md:94 | VD-T080-a |
| T081 배포 · 운영자 수동 단계 뒤 · G-3 전(`totp_seed` 자리는 시드 전 — §5-1 · 컨트롤러 — N-2) | 스펙 상수 · `AC4_PATH` · `$Vd1Option` · `totp_seed` 자리(B-9) | VD-T081-a · UD-4 · VD-1 |
| T087 · `/finish` | AGENTS.md 경로 규칙 `e2e/**` 행 · Commands 표 e2e 줄(런처) + KR 미러 | 규칙 자리 |
| 고칠 수 없음 | plan.md:70 · :95 · spec.md:430 · tasks.md 문면 | 〔77-1〕–〔77-15〕 |

## 5. 첫 자격 실행 관문 · 받아들인 위험 · 인계

### 5-1. 첫 자격 실행 관문(r1 — B-2 · A-7 · B-5 · B-7 · r2 — V-1)
- **정의(r2 — V-1 · B-2)**: 「첫 자격 실행」 = e2e 자격(비밀번호 · TOTP 코드 · 시드)이 **에이전트가 띄우거나 스크립트로 도는 시험 프로세스**(Playwright · 자격 블록 · 하네스 · 에이전트 셸에 붙여 넣은 env)에 처음 들어가는 실행. T081 라이브의 「로그인 되는지 한번」을 Playwright · 블록으로 돌리는 것과, 운영자가 env를 손으로 넣어 스펙을 돌리는 것도 여기에 든다(아래 코드 관문이 막는다).
- **제외 = 운영자 수동 단계**: 브라우저 로그인 · 화면 확인 · TOTP 등록 · VD-T081-a 관찰 · Vault UI/CLI 시드. 값이 운영자 창 밖(에이전트 대화 · 시험 프로세스)으로 나가지 않는 동작이다. r1 정의(「어느 프로세스에든」 · 「T081 라이브 창 전에」)는 글자대로 읽으면 운영자의 TOTP 등록 · 시드도 첫 자격 실행이 되어 T081을 시작할 수 없는 순환이었다.
- **순서(하나로 고정 — §0-1 · §1-1 · §1-3 · §5-3이 같은 글자를 쓴다)**: T080 → T081 배포 → 운영자 수동 단계(VD-T081-a 관찰 · TOTP 등록 · 시드 — `password` 먼저 · `totp_seed`는 등록 뒤) → G-1–G-7(스펙 상수 커밋(VD-T081-a) → 실물 블록 · approval-review → 승인 커밋 `jtApprovedBlock`) → T081 첫 자동 로그인 확인(검토된 블록) → T085.
  - G-3(블록이 `e2e/**` 해시를 고정)과 G-5(TOTP 등록 · 시드 자리)가 T081 실측(VD-T081-a)에 기대므로 관문은 운영자 수동 단계 **뒤**에 닫힌다. 다만 G-5 가운데 `totp_seed` 자리는 **시드 전에** 정한다(B-9 · §5-3 T081).

| 관문 | 내용 |
|---|---|
| G-1 | S-01 9파일 개정 + `.agents` 바이트 사본(codex-parity 초록) |
| G-2 | approval-review 기록 `reviews/YYYY-MM-DD-approval.md` — 꼴 (i) 또는 (ii)만 |
| G-3 | 블록 + 모의 하네스: 자식 env 허용 목록(블록 env 상속 0 · 이름 = D9 기본 이름 `SystemRoot` · `PATH` · `USERPROFILE` · `LOCALAPPDATA` · `TEMP` · `TMP` + 블록이 주는 `JT_E2E_*` + T079면 `KUBECONFIG` — r2 — V-4) · argv 글자 고정(`<node 절대> <CLI 절대> test --config <루트 config 절대> --project=live` 밖 인자 0) · 해시 고정(`e2e/**` · 루트 config · `package.json` · lockfile · 헤드리스 셸 실행 파일 = D2-5 ⑥ 기록값) · 비밀 전에 `pnpm install --frozen-lockfile --offline --ignore-scripts`로 설치 트리 재정합 · 자식 `TEMP`/`TMP` · outputDir · evidence = 블록 소유 루트 · finally 루트 삭제 + `Test-Path` · `T077 state-dead PASS` 줄이 없으면 끝 줄 앞에 「세션 무효화 미확인」 · 비정상 종료면 「노출 의심」 줄 · `e2e\.auth` ACL 확인(VD-T077-7) · 자식 출력 바늘 검사 · 잠금 표식 있으면 시작 거부(자리 = D10 ⑦ 규칙 — 토큰 홈 기준 · env 대조 — r2 — V-4) |
| G-4 | 그 판에서 `selftest` · `selftest-browser` · `needle=PASS`(양성 대조 포함) |
| G-5 | 데이터 결정: e2e 사용자 · TOTP 등록 · `totp_seed` 자리(B-9) · login stage 세션 수명 · Reputation `check_ip` 범위(B-6) |
| G-6 | tester 전용 PreToolUse 훅 결정(t076-design.md:259 이연분) · deny 보강(`e2e/.auth/**` · `.dev.vars*` 읽기) |
| G-7 | T077-b 결정(§0-2) |

- 코드 관문: config `metadata.jtApprovedBlock`이 `null`인 동안 live는 자격 env가 있어도 값을 읽지 않는다(D5). G-1–G-7이 닫힌 승인 커밋만 이 상수를 바꾼다. Codex 실행에도 걸린다(Playwright 프로세스 안의 판정).

### 5-2. 받아들인 위험
1. US4 동안 identity.tests.ps1 FAIL → KUBECONFIG + infra 통과 환경에서 `platform` 슬롯 FAIL(T050 선례).
2. 빨강 기간이 길다 — T080은 UD-13b 뒤(K3s v1.36.7 미발행 — build-notes.md:5547) · T079는 US5 뒤.
3. env 채널: 러너 env에 자격이 남는다(같은 Windows 사용자 경계 — T076 위험 1과 같다).
4. Playwright 판 올림의 새 반향 경로 — needle 재실행(G-4)과 블록 해시 거부로 줄인다.
5. `e2e/**`는 tester가 고칠 수 있다 — 블록 해시 고정 · 루트 config(가드 밖) · static-gate.
6. 루트 `package.json` · lockfile 변경이 events-test 방어 경로에 든다 — 렌즈 C + CI 초록.
7. CI 세 job의 설치가 조금 는다(브라우저 0).
8. Job 합성 튜플 쓰기는 FR-025와 결이 다르다(기존 Job 설계가 받아들임).
9. 빨강 관찰 때 공개 prod 호스트에 무자격 GET 몇 건(Rate Limiting 대상 밖 — 추론).
10. 실행마다 e2e 사용자 로그아웃이 dev · prod에 폐기 기록을 쌓는다(실행이 드물다).
11. **(r1 — B-13)** 코드 창 방식에서 블록이 .NET HMAC에 시드 바이트를 넘긴다 — T076 S-11(AMSI 메서드 호출 기록)의 범위가 TOTP 시드까지 넓어진다(같은 사용자 범위).
12. **(r1 — B-7)** 브라우저는 npm `integrity` 같은 무결성 검증이 없고 TLS에 기댄다 · 기본 위치는 사용자 쓰기 가능한 공유 캐시다 — 설치 전 env 가드 · 내려받기 호스트 확인 · 해시 기록 · 블록 대조로 줄인다.
13. **(r1 — B-6)** Reputation이 IP를 보도록 바인딩되면 e2e 실패가 운영자 IP를 잠글 수 있다 — 잠금 표식 수명 연장 · live 옵트인 · G-5 `check_ip` 결정으로 줄인다.

### 5-3. 인계
- **T080**: UD-13b 관문 · VD-T080-a(pub-5 후보 포함) · UD-1 재확인.
- **T081**: VD-T081-a · c · d · 「세션 1건」 안정화(login stage 「Terminate other sessions」 여부) · UD-4 → `AC4_PATH` · VD-1 → `$Vd1Option` · PLACEHOLDER 단언(T077-f) · UD-11 · UD-2 · **`kv/platform/authentik/e2e` 시드 전 결정(r1 — B-9)**: `totp_seed`가 eso-platform이 읽는 경로(`kv/data/platform/*` · deny는 `platform/access/*`뿐 — policies.tf:27–32 · store `vault-platform`은 플랫폼 ns 12곳)에 남는다 → ① ESO deny 아래 별도 경로(예: `kv/platform/access/e2e-totp` · e2e-reader에 정확한 경로 하나 + vt-16 갱신) ② 같은 경로 + 받아들인 위험 — blueprint가 시드를 받는다고 실측되면(VD-T081-a) ② 근거가 생긴다. 시드 주체 · 순서(운영자 · `password` 먼저 · `totp_seed`는 등록 뒤). **Reputation `check_ip` 범위**(e2e 실행 IP와 운영자 관리 IP를 가를지 — r1 — B-6 ③). **라이브 순서 = §5-1 순서**(운영자 수동 단계는 관문 전에 할 수 있다 · T081 첫 자동 로그인 확인은 G-1–G-7 뒤 — r2 — V-1).
- **운영자 수동 단계 뒤 · T081 첫 자동 로그인 확인 전(= 첫 자격 실행 전 · §5-1 순서 — r2 — V-1)**: §5-1 G-1–G-7 · 블록(`design/t08x-blocks/`) 흐름 = Vault 읽기 → capabilities-self → revoke-self → port-forward 종료 → Playwright 자식 하나 · UD-16(1시간 재사용 대 블록마다 짧은 발급) · audience 분리 role.
- **T082**: authz-assert 새 id 넷 · `OPENFGA_URL` Service 이름 · 렌더 시점.
- **T083**: e2e 사용자 member 멤버십(T079 기준선 · T085 `role: "member"`).
- **T084(r1 — B-13)**: `tester-k8s` 시드(T077-e) · 회전 매트릭스에 **e2e 사용자 자격 행**(비밀번호 · TOTP 장치) · 노출 의심 순서 = Authentik 세션 삭제 → 비밀번호 교체 · TOTP 재등록 → Vault 갱신(→ 블록 재실행 전 잠금 표식 확인).
- **T085**: T077 · T078 · T079 실행 + SC-003 ≤ 2 s · SIGKILL ≤ 30 s · 관리자 폐기 · 웹훅 dev/prod 분리 · 1단계(dev 체인 — 서버 기동 주체 = T077-b 결정 — 권고 (b′) 병행 — r2 — V-11) · 2단계(T094 뒤) · `e2e/.auth/` 삭제 확인 · 운영자 스크린샷(D10 ⑨ 규칙) · 「Authentik 세션 삭제」 운영자 수동 기록 · authz seed 튜플 판정 · VD-T085-a · b.
- **T087 · T093**: CI e2e — `site` 프로젝트 · live 제외 · 브라우저 설치 단계 · **test-results · report · trace 아티팩트 업로드 0**(r1 — B-4) · e2e 경로 규칙.
- **T092**: VD-T092-a. **T094**: T079 2단계 재실행. T094 뒤에는 prod의 비계약 응답이 제품 결함이다 — reach-bff의 `[env] prod-chain-not-bff — T094 전` 갈래는 그때 `[product]`로 바꾼다(빨강 판별용 갈래였다 · 컨트롤러 — N-5).
- **UD-7**: T079는 `all_devices: true`로 떼었다 — 기본 범위의 시험은 T089 · T092 몫.
- **/finish**: report 편차 후보 〔77-1〕–〔77-15〕.

## 6. 비판 반영표
- 정본 = r1과 함께 컨트롤러에게 돌려준 처리 표(31행 — A-1–A-17 · B-1–B-14 · 심각도 · 처리 · r1 자리 · 설명)와 이 r2와 함께 돌려준 처리 표(14행 — V-1–V-11 · partial A-2 · B-2 · B-14 · 처리 · r2 자리 · 설명)(r2). 본문 반영 자리마다 「(r1 — …)」 · 「(r2 — …)」 표식을 달았다. 확정 때 컨트롤러가 이 절에 옮긴다.

## 정정 노트

### 2026-11-23 — 설치 · 빌드 r0 · 수정 r1 · 라이브 빨강 반영
정본 = build-notes 「## T077 · T078 · T079」 · 보고 `.superpowers/t077/{build,reviews}/`(빌드 r0 `wf_ebfd861d-425` · 리뷰 A · B · C · 수정 r1 `wf_92b7426c-261` · 검증 V1 · V2). 결정 본문은 그대로이고, 실물과 다른 점만 적는다.

1. **D2-4 · 사용자 안내 「기존 chromium-1179는 건드리지 않는다」**
   - `playwright install`이 미사용 브라우저를 자동으로 지웠다: chromium-1179 · chromium_headless_shell-1179 · ffmpeg-1011.
   - 설치 때 정리하는 기본 동작을 미리 확인하지 못했다.
2. **D12 커밋 단위**: T077 · T079를 한 커밋으로 묶는다(리뷰 A-6).
   - 까닭: r1에서 두 과제가 `e2e/lib/{test-base,authentik-flow}.ts` · tracked-files · static-gate를 함께 쓰게 됐다. 나누면 앞 커밋의 selftest가 빨강이다.
   - T078은 따로 커밋한다.
3. **D9 list 기대 「T077: live 1 · T079: live 3」은 누적 수다.** T079 자신은 live 2(AC3 · AC4) → 합 3.
4. **T077(A-7 · A-1 · A-2 · A-10 · B-5 · B-6)**
   - 로그아웃 완료 = 로그인 화면 표식(identify 칸 visible)이다. 두 스펙의 흐름은 새 lib `e2e/lib/authentik-flow.ts`로 모았다.
     - 무효화 페이지 접두만으로 끝을 판정하면 빈 PASS가 되기 때문이다 — Playwright `waitForURL`은 URL이 이미 맞으면 바로 돌아온다.
   - 잔여 검사 순서
     - 잔여 계수가 globalSetup 맨 앞이다: `[state] previous-run residue count=N`.
     - teardown도 지우기 전에 센다: `[state] auth-residue at teardown count=N` → 실패로 끝낸다.
   - `step-not-advanced` 판정 · 잠금 표식은 「값이 칸에 들어간 뒤」에 낸다(`AFTER_FILL_CODE`). fill 자체 실패는 `[product]`이고 잠금 0이다.
   - 죽은 상태 확인은 메모리 storageState로 먼저 하고, 그 뒤에만 파일을 쓴다.
   - runId 접두는 `t077-`다(T079도 쓴다).
5. **T079(A-7 · A-8 · A-9)**
   - 흐름 세부
     - copy → baseline 순서
     - baseline · logout의 probe 꼴
     - bff-login 줄 분할 · `status=N` 접미
     - 간격을 모를 때 15 s 대기 · 로그 재읽기
   - AC4 창 = [기준 − 2 s, 기준 + 폭 + 2 s] · `--since-time` = 아래 경계.
   - `diagnoseUntil`은 첫 재질문 전에 500 ms 기다린다.
6. **T078(A-7 · C-5 · B-9)**
   - 판정 줄 꼴 = `FAIL <id> -- [gate|env|product|guard] <§1-2 글자>`(D5 접두를 붙였다). xchg-0은 `[gate] Traefik 404 (no router) — until T080`이다(§1-2 원문 「Traefik 404 — until T080」).
   - fga `[gate] … until T082` 갈래와 T082 지시문 `$FgaPendingIds = @()` · acc-1 `[env]`(ing-1을 확인하지 못했을 때) · tool-1 실패면 curl 호출 0.
   - curl이 물려받는 프록시 · TLS env는 `[guard] curl-env-not-allowed <정렬된 이름>`이다(값을 읽지 않는다).
     - 이름 = `*_PROXY`(NO_PROXY 포함) · `SSLKEYLOGFILE` · `CURL_CA_BUNDLE` · `SSL_CERT_FILE` · `SSL_CERT_DIR`.
   - gate-3에 닮은 SA 이름 사례를 더했다.
7. **공통(D3 · D5 · D10)**
   - tracked-files = `git ls-files --cached --others --exclude-standard -- e2e`.
   - static-gate를 넓혔다(B-2 · C-1 · C-2 · C-4)
     - 자격 env 이름 글자 자체
     - 리스너 넷 + requestfinished · requestfailed
     - 값을 싣는 Playwright API 다수: 로케이터 매처 · 스냅숏 · ariaSnapshot · innerHTML · `.content()` · getAttribute · route · expose* · request 별칭 등
     - `emit-args`
     - `@playwright/test` 직접 import 금지 → `e2e/lib/test-base.ts` 필수 — 파일 단위 `test.use()` 우회 차단(B-3)
   - env 가드를 넓혔다: `PLAYWRIGHT_*` · `PW_*` · `PWTEST_*`는 전부 막는다(허용은 `PLAYWRIGHT_TEST=1` · `PLAYWRIGHT_NO_COPY_PROMPT=1`). `DEBUG`에 `*`가 들면 막고, `NODE_OPTIONS`는 허용 목록이다.
   - config: `PLAYWRIGHT_NO_COPY_PROMPT=1` · `captureGitInfo` off · `updateSnapshots: 'none'` · `snapshotDir` = outputDir 아래.
   - needle(B-1)
     - 실행 1 의도 실패 9 · needle-control 7(노출 경로마다 양성 대조 — log · inp · req · sck · url · nav · pgs).
     - 루트를 실행마다 따로 둔다 · 산출물 수 0 판정.
   - 잠금 관문은 cred 직전에 본다(B-4). 표식 쓰기가 실패하면 실행 범위 표식이 남은 live를 멈춘다.
8. **VD-T077-4 실측**: 1.65.1은 실패하면 outputDir에 `error-context.md`(오류 + 코드 프레임 + 페이지 aria snapshot)를 쓴다 → 위 config로 껐다. APIRequestContext 오류에는 cookie · authorization 헤더 원문이, fill 오류에는 값이 실린다(B-1 설계가 맞았다).
9. **발견(Node v24.11.1 · Windows)**: 비재귀 `fs.rmSync(<파일>)`은 경로에 한글이 있으면 오류 없이 파일을 남기거나 프로세스를 중단한다(0xC0000409). `auth-dir`는 `unlinkSync` + 지운 뒤 확인으로 바꿨다.
10. **라이브 빨강(2026-11-23T12:04:30Z · D9 ④)**
    - `live-red passed=0 failed=3 gate-reach=3/3 child-exit=1 auth-residue=ok root=removed` · 자식 env 이름 = 허용 목록 11개.
    - T077 `reach` · T079 `reach-auth` ×2 모두 `[gate] authentik-absent until T080 — Traefik 404 signature (T076 D10) matched` → §1-1 충족.
11. **인계 — G-4(첫 자격 실행) 전에 닫을 것**(검증 V1 · 리뷰 B)
    - V1 V-1: APIRequestContext 매개변수 · 대입 별칭이 static-gate를 비켜 간다.
    - V-2: cred 직전 lockGate 배선을 spec 시험으로 고정한다.
    - V-3: static-gate · emit-args에 남은 꼴(심은 12개 미탐지).
    - V-4: live-red 끝 줄 `auth-residue=ok`가 teardown 신호를 보지 않는다.
    - V-6: AC4 창 · probe 기준 시각 — T081.
    - B-8: `jtApprovedBlock` 관문은 자기 신고 문자열 대조일 뿐이다 → §5-1 G-3 설계에서 블록 일회 nonce · 해시 결속.
    - V2 NIT 셋(gate-3 접미 · 1b catch 갈래 · 문구).
    - 기록만: C-7(기존 `ci.yml:63–70` events-test 방어 · CODEOWNERS).

### 2026-11-24 — T086–T089 설계 확정 반영(design/t086-design.md §4-2)
정본 = design/t086-design.md(r2 본문 + §7 확정 보정). 결정 본문은 그대로이고, 이 설계의 전제가 바뀐 점만 적는다.

1. **UD-7 = (나) 확정(2026-11-24)** — T079의 명시 `all_devices: true`(e2e/lib/bff.ts:59–60)는 기본 범위와 떼어 낸 것에서 「모든 기기」 경로의 필수 본문이 됐다. 로그아웃 성공 응답은 204 그대로이고 헤더 `x-end-session-url`만 더해지므로 `judgeLogout`(e2e/lib/bff.ts:182–:185) 변경은 0이다(이 문서 :440 인계를 닫는다).
