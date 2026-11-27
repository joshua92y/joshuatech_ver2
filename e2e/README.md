# e2e/

저장소 루트의 Playwright 시험 소스 디렉터리다. 워크스페이스 패키지가 아니다 — 루트 devDependency `@playwright/test`(1.65.1 정확 핀)와 루트 `playwright.config.ts`가 이 디렉터리를 읽는다(T077 보정 2026-11-23 · 설계 `specs/003-platform-foundation/design/t077-design.md` D2 · D3).

## 실행 — 런처만 쓴다

```
node e2e/lib/launch.mjs selftest           # 브라우저 0 · 네트워크 0 — 끝 줄 '<n> passed, <m> failed' (run-all e2e-selftest)
node e2e/lib/launch.mjs selftest-browser   # 로컬만 — page.setContent(secret-input · evidence mask 증명) + 127.0.0.1 흉내 서버(Authentik 흐름 · 로그아웃 · 잠금 표식)
node e2e/lib/launch.mjs needle             # 노출 바늘 시험 — 끝 줄 'needle=PASS|FAIL …'(면별 hits 수 · 경로별 대조 수)
node e2e/lib/launch.mjs list               # 프로젝트별 시험 수 (live · needle · site 각각 --list — site 대상은 런처 상수 http://127.0.0.1:9 · local)
node e2e/lib/launch.mjs live-red           # 공개 호스트 무자격 GET — 빨강 관찰(컨트롤러 몫 · 빌더 · tester 자동 실행 금지)
node e2e/lib/launch.mjs site               # T087 site 프로젝트 — 런처 env의 BASE_URL · JT_E2E_SITE_MODE(local | prod)를 대상으로
node e2e/lib/launch.mjs site-red           # T087 빨강 관찰 — 닫힌 루프백 포트를 local 대상으로(공개 호스트 0)
```

- `live-red` 끝 줄 = `live-red passed=<n> failed=<n> gate-reach=<n>/<live 시험 수> child-exit=<n> auth-residue=ok|missing root=removed|left`. `gate-reach`는 중계한 줄 가운데 `T07[79] reach(-auth)? FAIL [gate] authentik-absent until T080` 줄 수다 — 「올바른 이유의 빨강」은 이 값이 live 시험 수와 같을 때뿐이다(가드 · 브라우저 기동 실패 · 런처 오류도 exit 1이라 exit만으로는 가르지 못한다). exit 규약은 그대로(T077 보정 r1 — 리뷰 A-3).
- `site` 끝 줄 = `site passed=<n> failed=<n> skipped=<n> allowed-skip=<0|1> child-exit=<n> root=removed|left`. skip은 실패와 따로 센다. exit 0 = 자식 exit 0 · failed 0 · skipped = allowed-skip · passed ≥ 1 · 루트 삭제. `allowed-skip`은 local이고 `INFO T087 health skipped mode=local` 줄이 있을 때만 1이다(로컬 `next start`에는 상류 identity-admin이 없어 h-7만 건너뛴다 — 판정은 prod에서 T095). `BASE_URL` · `JT_E2E_SITE_MODE`가 런처 env에 없으면 이름만 내고 exit 2다. 꼴이 허용 목록 밖이면 자식을 띄우기 전에 `[guard] site-target-not-allowed — …`(값 0) · exit 2다 — 정본은 설정의 `validateSiteTarget`(아래 site 절)이고, 런처 사전 검사와 같은 판정인지는 selftest `launch`가 사례 표로 고정한다.
- `site-red` 끝 줄 = `site-red passed=<n> failed=<n> skipped=<n> gate-site=<g>/<failed> child-exit=<n> root=removed|left`. `gate-site`는 중계한 줄 가운데 `T087 reach FAIL [gate] site-absent until T091` 줄 수다 — 「올바른 이유의 빨강」은 g = failed일 때뿐이다(T091 전 기대 = `passed=0 failed=8 skipped=1 gate-site=8/8` · exit 1).

- 런처는 실행마다 블록 소유 루트 `%TEMP%\jt-e2e\<runId>\`를 만들고 outputDir · 증거 · 로그 · 자식 `TEMP`/`TMP`(TS 변환 캐시 · 브라우저 임시 파일)를 그 아래에 둔다. 끝나면 루트를 지우고 존재 0을 확인한다.
- 자식 env = 허용 목록(`SystemRoot` · `PATH` · `USERPROFILE` · `LOCALAPPDATA` · `TEMP` · `TMP` + `JT_E2E_RUN_ID` · `JT_E2E_ROOT` · `JT_E2E_OUTPUT_DIR` · `JT_E2E_EVIDENCE_DIR` + 모드 값). `KUBECONFIG` · `JT_E2E_BLOCK`은 어느 모드에도 없다. 런처는 env 이름 · 판정 줄 · 수만 낸다.
- 인자 없는 `pnpm exec playwright test`는 selftest 두 프로젝트만 돈다. 루트 `package.json`에는 `test` 스크립트가 없다(selftest가 고정).

## 프로젝트 · 조건

| 프로젝트 | 파일 | 실리는 조건 |
|---|---|---|
| `selftest` | `selftest/**/*.test.ts` | 늘 |
| `selftest-browser` | `selftest-browser/**/*.test.ts` | 늘 |
| `needle` · `needle-control` | `needle/needle.test.ts` · `needle/needle-control.test.ts` | `JT_E2E_NEEDLE=1`(런처 `needle`만 준다) |
| `live` | `auth.spec.ts` · `revocation.spec.ts`(T079) | `JT_E2E_LIVE=1`(런처 `live-red` · 검토된 자격 블록) |
| `site` | `hello.spec.ts`(T087) | `JT_E2E_SITE=1` + 허용 대상 `BASE_URL` · `JT_E2E_SITE_MODE`(런처 `site` · `site-red` · `list`) |

`JT_E2E_NEEDLE=1`과 `JT_E2E_LIVE=1`이 함께면 설정 로드에서 `[guard] needle-live-conflict`로 멈춘다(바늘 값이 실제 IdP로 가지 않게). `site`는 둘 모두와 배타다(`[guard] site-conflict`).

## 산출물 정책

- trace · video · 자동 screenshot = off. 리포터는 `list` 하나(HTML · blob · json · junit 금지 — HTML step 제목에 `fill` 값이 평문으로 실린다). `preserveOutput: 'never'`(needle 실행만 `'always'` — 아래 바늘 시험). 실패 때 error-context의 페이지 스냅숏도 끈다(`PLAYWRIGHT_NO_COPY_PROMPT=1`).
- 스냅숏 기준 이미지는 쓰지 않는다(`updateSnapshots: 'none'` · `snapshotDir` = outputDir 아래 — 저장소 밖). `toHaveScreenshot` · `toMatchSnapshot`은 static-gate가 막는다.
- 기록 끄기는 globalSetup이 실행 때 다시 단언한다(디버그 · 프록시 env · CLI 덮기 `--trace` · `--reporter` · `--output` · `--workers` · `--retries` · `--update-snapshots` 등 → `[guard]`로 멈춤).
- 파일 단위 옵션 덮기(test 객체의 `use` 호출 · 옵션 픽스처 덮기)는 FullConfig에 드러나지 않는다. 그래서 spec · needle · selftest-browser는 test를 `lib/test-base.ts`에서만 가져오고(static-gate), 그 자동 픽스처가 시험마다 실제 옵션 픽스처 값(trace · video · screenshot · headless · channel · launchOptions · connectOptions · contextOptions · proxy · storageState · extraHTTPHeaders · httpCredentials · ignoreHTTPSErrors · acceptDownloads · baseURL)을 프로젝트 설정 값과 다시 맞춰 보고, 어긋나면 페이지를 만들기 전에 `[guard] fixture-override <이름>`으로 멈춘다. `selftest-browser/fixture-guard.test.ts`가 그 양성 대조다(실행마다 이 `[guard]` 줄을 한 번 낸다 — 기대한 실패).
- `test-results/` · `playwright-report/` · `blob-report/`는 gitignore 대상이다(깊이 무관). 파일은 이름으로만 스테이징한다(`git add -A` 금지).
- CI e2e job은 아직 없다(live는 공개 prod Authentik과 자격이 필요하다). T093이 여는 CI site job도 test-results · report · trace를 아티팩트로 올리지 않는다(업로드 0). 런처는 그때까지 Windows 전용이다(기본 env `SystemRoot` · `PATH` · `USERPROFILE` · `LOCALAPPDATA` — Linux 실행은 T093).

## env 계약(이름만 — 값은 저장소 · 로그 · 대화에 두지 않는다)

| 이름 | 뜻 |
|---|---|
| `JT_E2E_SECRET_PASSWORD` | e2e 사용자 비밀번호(검토된 블록이 Vault에서 읽어 Playwright 자식 하나의 시작 env로만 준다) |
| `JT_E2E_SECRET_TOTP_CODES` · `JT_E2E_TOTP_STEP0` | 연속 30 s 단계의 6자리 코드(쉼표) · 첫 단계 번호 — 시드는 블록 밖으로 나가지 않는다 |
| `JT_E2E_BLOCK` | 실행한 블록의 저장소 상대 경로 — 루트 config `metadata.jtApprovedBlock`과 같을 때만 live가 값을 읽는다(지금 `null` → 늘 `[guard] outside-reviewed-block (T077-a)`) |
| `JT_E2E_LIVE` · `JT_E2E_NEEDLE` · `JT_E2E_SITE` | 프로젝트 포함 플래그 |
| `BASE_URL` · `JT_E2E_SITE_MODE` | T087 site 대상 · 모드(`local` = `http://127.0.0.1:<port>` 또는 `http://localhost:<port>` origin · `prod` = 정확히 `https://joshuatech.dev`). 비밀 아님 — 그래도 런처 · 가드 줄은 값을 싣지 않는다 |
| `JT_E2E_NEEDLE_SET` | needle 실행의 바늘 묶음(런처가 실행마다 만든다 — 가짜 값) |
| `JT_E2E_RUN_ID` · `JT_E2E_ROOT` · `JT_E2E_OUTPUT_DIR` · `JT_E2E_EVIDENCE_DIR` | 실행 id · 블록 소유 루트 · outputDir · 증거 자리(저장소 밖) |
| `JT_E2E_CHAIN` | T079 체인 — `dev`(`http://localhost:3000` · ns `jt-dev` · 1단계) · `prod`(`https://joshuatech.dev` · ns `jt-prod` · 2단계 — T094 뒤). 디스패치 지시문이 준다(비밀 아님) |
| `KUBECONFIG` | T079 log-reason 전용 agent-view kubeconfig — 검토된 블록이 T079 실행에만 준다(런처는 어느 모드에서도 주지 않는다). kubectl 자식 env = `PATH` · `SystemRoot` · `KUBECONFIG` · `USERPROFILE` · `TEMP`. PATH에서 찾은 `kubectl.exe`가 저장소 · `os.tmpdir()` · 토큰 홈의 `AppData\Local\Temp` · `JT_E2E_ROOT` 아래면 `[guard] kubectl-location`(런처 · 블록 실행에서 자식 TEMP는 루트 아래라 실제 사용자 Temp를 따로 막는다) |

- 자격 env는 `lib/env-contract.ts`만 읽는다(이름 글자는 런처도 쓰지만 `process.env` 읽기 꼴 · 동적 `process.env[` 읽기는 env-contract.ts뿐 — static-gate) — 시험 본문에서 도달 단계가 통과한 뒤에 한 번 읽고 `process.env`에서 지운다. 없으면 빠진 이름만 나열한 `[env]` FAIL(SKIP이 아니다).
- 실패 분류 접두: `[gate]`(구현 부재 — 빨강 증거) · `[product]` · `[env]` · `[decision]` · `[guard]` · `[state]`. 출력 줄은 `lib/out.ts`를 지나고 기계 판독 부분(첫 ` — ` 앞)은 ASCII다.

## `e2e/.auth/` 수명

- gitignore 대상 · 실행 뒤 0. T077은 로그아웃 뒤 **메모리 상태로 새 컨텍스트를 열어 로그인 화면으로 돌려보내지는 것(죽은 세션)을 먼저 확인한 뒤에만** `e2e/.auth/<runId>-t077.json`에 쓴다(살아 있는 세션은 디스크에 놓이지 않는다 · 확인 실패면 정리 단계가 다시 로그아웃하고 `server session may remain - operator check`). 삭제는 시험 teardown → globalTeardown(`INFO auth-residue 0`) → 블록 finally 세 겹이다.
- Authentik 로그아웃 완료 = **로그인 화면 표식(identify 칸)이 보일 때**다 — 무효화 흐름 페이지(`/if/flow/<무효화 slug>/`)에 도착한 것만으로는 완료가 아니다(실제 로그아웃은 그 페이지의 흐름 실행기가 load 뒤에 한다). T079 AC4의 완료 시각 · 정리 줄의 `done`도 그 뒤다(`lib/authentik-flow.ts` — 두 spec 공용 · selftest-browser가 로컬 흉내 서버로 시험한다).
- T079는 파일을 쓰지 않는다 — `__Host-jt_session` · `__Host-jt_csrf` 사본은 메모리에만 두고, 기준선 · logout · probe는 호출마다 새 요청 컨텍스트에 명시 Cookie 헤더로 싣는다(`lib/http.ts` `freshGet` · `freshPost`). 계약 쿠키 이름(B-6 — `__Host-` 접두)은 시험의 독립 상수(`lib/bff.ts`)다. needle · selftest 픽스처의 `jt_session=` 글자는 계약 이름을 단언하지 않는 자리값이라 그대로 둔다(N-19).
- **globalSetup은 다른 어느 가드보다 먼저 잔여를 센다** — 잔여가 있으면 어느 모드에서든(다른 가드가 함께 걸려도) 개수만 내고 지운 뒤 `[state] previous-run residue count=<n> — …`로 멈춘다 — 노출 의심이다. 운영자가 Authentik에서 e2e 사용자 세션을 지운다. globalTeardown도 지우기 전에 세어, 남아 있으면 `[state] auth-residue at teardown count=<n>`을 내고 실행을 실패로 끝낸다(T077 보정 r1 — 리뷰 A-2).

## 로그인 잠금 표식

- 비밀번호 · TOTP 값이 **칸에 들어간 뒤**(자동 제출로 칸이 사라진 경우 포함) 단계가 안 넘어가면 `<토큰 홈>\AppData\Local\jt-e2e-lock\e2e-login-lock.json`(단계 · UTC · runId만)을 남긴다. 값이 칸에 들어가지 못한 실패(칸 없음 · 비활성)는 `[product]` · `[env]`다. 토큰 홈 = `os.userInfo().homedir`(프로세스 토큰의 프로필 — env로 바꿀 수 없다). env `USERPROFILE` · `LOCALAPPDATA`가 이와 어긋나면 live는 `[guard] profile-env-mismatch`로 멈춘다. O-9 JWT 디렉터리(`%LOCALAPPDATA%\jt-e2e\`)와 다르다.
- 표식이 있으면 live 실행은 시도하지 않고 `[guard] login-lock present`로 멈춘다(그 밖 실행은 INFO). **같은 실행 안에서도** 두 spec의 cred 단계가 자격을 읽기 직전에 다시 본다 — 앞 시험이 표식을 남기면 뒤 시험은 같은 자격을 다시 제출하지 않는다. 표식을 못 쓰면 실행 범위 표식(`<JT_E2E_ROOT>\login-lock-write-failed`)을 남겨 남은 live 시험이 cred에서 `[guard] login-lock write-failed`로 멈춘다(T077 보정 r1 — 리뷰 B-4). 운영자가 원인(Vault 값 · TOTP 재등록 · Reputation)을 확인한 뒤에만 지운다.

## 바늘 시험(needle)

- 런처가 실행마다 난수 바늘(비밀번호 · 코드 · 쿠키 · authorization · 쿼리 · 가짜 IP · UA · 경로별 대조 7개)을 만들어 자식 env로만 넘긴다. 소스 · fixture에 바늘 값 리터럴은 없다.
- 실행 1(`needle`) = 감싸개를 지나는 의도 실패 정확히 9건(메시지 정확 일치 — nd-1 fill · nd-2 값이 칸에 남은 채 멈춤 · nd-3 요청 헤더 뒤 끊김 · nd-3b 응답 Set-Cookie 뒤 끊김 · nd-4 500 · nd-5 대기 중 쿼리 URL로 재탐색 · nd-6 Sessions 꼴 표 · nd-7 mask 대상 0 · nd-8 쿼리 URL 탐색 시간 초과) + 모든 면 hits 0 + 루트의 바이너리 산출물(zip · webm · png) 0. needle 실행만 `preserveOutput: 'always'`라 시험 끝에 지워지던 실패 산출물(error-context · trace · 영상)도 스캔 면에 남는다.
- 실행 2(`needle-control`) = **노출 경로마다 양성 대조**: 같은 경로를 감싸개 없이(원래 API) 밟아 그 경로 전용 대조 바늘이 실제로 새는지 시험 안에서 확인하고, 경로별로 정해진 면에서 잡혀야 한다(c-log · c-inp · c-req · c-sck · c-url · c-nav = 로그 면 · c-pgs = 실패 시험의 페이지 스냅숏이 보존된 루트 면 + 산출물 계수 대조 1개). 한 경로라도 더 새지 않으면(Playwright 판 변화) `needle=FAIL`이다 — 그 경로의 실행 1 「hits 0」이 공허해졌다는 뜻이다(T077 보정 r1 — 리뷰 B-1).
- 면 = 로그 · 블록 루트 · `test-results/` · `e2e/.auth/` · `%TEMP%\playwright*` · `git status --ignored`.
- **판 올림 = needle 재실행 + 브라우저 해시 재기록**: `@playwright/test`를 올리면 `selftest` · `selftest-browser` · `needle=PASS`를 그 판에서 다시 확인하고 헤드리스 셸 실행 파일 해시를 다시 적는다(자격 블록이 해시를 대조한다 — 설계 §5-1 G-3 · G-4).

## site 프로젝트(T087 — `hello.spec.ts`)

- 설계 = `specs/003-platform-foundation/design/t086-design.md` D10–D12. 시험 h-1–h-9: 세 로케일 200 + v2 표식(`data-jt-app="web"`) · 노트 001 · 002 표시 표식 · Set-Cookie 0(prod는 엣지 쿠키 이름만 INFO) · `/` 302 사례 7개 · `/ja` 번역 없음 배지(`data-translation-missing` · `data-note-lang="ko"`) · 토큰 3계층(`--jt-ref-` → `--jt-sys-` → `--jt-comp-` · dark에서 ref 불변) · `/api/health`(prod만 — local은 reach 전 INFO + skip · 계약상 유효한 `status` `ok` · `degraded`는 둘 다 PASS이고 degraded는 값 없는 `INFO health-status degraded` 한 줄로만 알린다) · 맵 밖 프록시 404 problem · 로드 뒤 30 s prefetch ≤ 10.
- 대상: `local` = `http://127.0.0.1:<port>` · `http://localhost:<port>`(origin만 — 프로덕션 빌드 `next start`) · `prod` = 정확히 `https://joshuatech.dev`. 그 밖은 설정 로드에서 `[guard] site-target-not-allowed`(값 0). `preview.joshuatech.dev`는 Access 뒤라 자동 대상이 아니고, `next dev`도 대상이 아니다(개발 서버의 prefetch · 응답 꼴은 판정 대상이 아니다). prod 모드는 공개 apex를 부른다 — 컨트롤러 지시가 있을 때만 돌린다.
- 스펙은 env를 읽지 않는다 — 모드는 프로젝트 `metadata.jtSiteMode`, 대상은 `baseURL` 픽스처로만 받고 시험마다 다시 검증한다. 시험마다 첫 단계는 `reach`(`freshGet <base>/ko`)다 — 부재 단언(Set-Cookie 0 · 배지 0 · 쿠키 0)은 도달(v2 표식) 뒤에만 뜻이 있다. reach 분류: local 거부 + `apps/web/next.config.ts` 없음 → `[gate] site-absent until T091`(빨강 증거) · 거부 + 스캐폴드 있음 → `[env] site-server-not-running` · 그 밖 네트워크 오류 → `[env] network (<code>)` · 200 `text/html` + 표식 → PASS · local 그 밖 응답 → `[product]` · prod 52x/5xx → `[env] origin` · prod 그 밖 → `[env] prod-site-not-v2`(T094 뒤 `[product]`).
- 페이지 탐침은 `lib/site-probe.ts`뿐이다(static-gate 이름 붙은 예외 — `evaluate` · `request` 이벤트 리스너 `listener-request`). 반환은 수 · 불리언뿐 · 리스너는 `next-router-prefetch: 1` 헤더 하나만 보고 수만 센다(요청 객체 보관 · URL 읽기 0). 가져올 수 있는 파일은 `hello.spec.ts`와 `selftest-browser/site-probe.test.ts`뿐(`site-probe-import`). spec의 `expect(` 인자(와 이어 붙은 매처 인자)에는 `headers` · `.body` · `cookies(`가 들 수 없다(`expect-args`). Request · Response의 쿠키 포함 헤더 보기 · 요청 본문 · 모아 둔 요청 · 콘솔 · 페이지 오류 목록을 꺼내는 API는 어디서나 0이다(헤더 객체 메서드 `headers()`는 허용).
- 헤더 이름 양성 대조(`Next-Router-Prefetch: 1`을 실제로 세는지) · 새 요청 컨텍스트에 `accept-language`가 없음(VD-T087-1) · 여러 Set-Cookie가 줄바꿈으로 이어짐은 `selftest-browser/site-probe.test.ts`가 127.0.0.1 흉내 서버로 고정한다.

## 증거 스크린샷

- `lib/evidence.ts`만 찍는다: mask 로케이터마다 개수가 표 행 수(≥ 1)와 같을 때만 찍고, 아니면 `[product] mask-target-missing`. 파일은 `JT_E2E_EVIDENCE_DIR`(저장소 밖)에만 · 커밋 0 · 보고에는 파일 이름 · SHA-256 · 가린 칸 목록만 싣는다.
- 운영자 스크린샷(AC1 소셜 로그인 · `argocd --sso` · Authentik 관리 API)은 운영자가 가린 뒤 넘기고 같은 규칙을 따른다(공개 저장소 · gitleaks는 이미지 글자를 못 본다).
- 시크릿 · 실제 자격 증명은 절대 커밋하지 않는다.
