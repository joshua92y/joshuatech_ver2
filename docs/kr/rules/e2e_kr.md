> 번역본(편의용). 정본은 영어 원본 `.claude/rules/e2e.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "e2e/**"
  - "playwright.config.ts"
```

# Rules for `e2e/` and the root `playwright.config.ts`

기록 설계: `specs/003-platform-foundation/design/t077-design.md`(D3 · D5 · D10과 정정 노트 7 — 자격 없는 기반과 노출 통제)와 `specs/003-platform-foundation/design/t086-design.md`(D10 · D11 — T087 `site` 프로젝트). 운영 메모: `e2e/README.md`. 시험 대상의 동작은 `contracts/bff-api.md`와 `.claude/rules/web.md`가 정한다. 충돌 시 계약이 우선한다 — 계약을 먼저 개정한다.

## Layout and runs

- `e2e/`는 루트 Playwright 설치의 시험 소스 트리이고 워크스페이스 패키지가 아니다: `@playwright/test`(정확 핀 1.65.1)가 루트의 유일한 devDependency이고, 루트 `package.json`에는 스크립트가 없으며, 루트 `playwright.config.ts`(`testDir: './e2e'`)가 유일한 Playwright 설정이다. `config-hygiene` selftest는 해석된 설정의 이름 붙은 필드를, `tracked-files` selftest는 `e2e/` 아래의 정확한 파일 집합(`git ls-files --cached --others --exclude-standard -- e2e`)을 고정한다 — 새 파일은 그 목록을 고치는 변경과 함께만 들어온다(T077).
- Playwright는 런처로만 돌린다 — `node e2e/lib/launch.mjs <mode>`, 인자는 정확히 하나: `selftest`(브라우저 0 · 네트워크 0 — run-all `e2e-selftest` 슬롯) · `selftest-browser`(로컬 `page.setContent` 페이지와 127.0.0.1 흉내 서버만) · `needle`(노출 바늘 시험) · `list`(프로젝트별 시험 수) · `live-red`(공개 호스트 무자격 GET — 컨트롤러의 빨강 관찰. 빌더와 tester는 스스로 시작하지 않는다) · `site`(`BASE_URL`을 대상으로 한 T087 `site` 프로젝트 — `JT_E2E_SITE_MODE`는 `local` 또는 `prod`) · `site-red`(닫힌 루프백 포트 — 빨강 서명은 `[gate] site-absent until T091`). 인자 없는 `pnpm exec playwright test`는 selftest 두 프로젝트만 돈다.
- 런처는 실행마다 소유 루트 `%TEMP%\jt-e2e\<runId>\`(outputDir · 증거 · 로그 · 자식 `TEMP`/`TMP`)를 만들고 끝나면 지운다. 자식 env는 허용 목록(`SystemRoot` · `PATH` · `USERPROFILE` · `LOCALAPPDATA` · `TEMP` · `TMP` · 실행 변수 · 모드 고유 값)이고, 런처는 env 이름 · 판정 줄 · 수만 낸다. T093이 Linux CI job을 더하기 전까지 Windows 전용이다.
- 프로젝트는 자기 플래그가 있을 때만 실린다: `selftest` · `selftest-browser`는 늘 · `needle`/`needle-control`은 `JT_E2E_NEEDLE=1` · `live`는 `JT_E2E_LIVE=1` · `site`는 `JT_E2E_SITE=1`. `needle`과 `live`가 함께면 설정 로드에서 멈추고(`[guard] needle-live-conflict`), `site`는 둘과 배타다(`[guard] site-conflict`). `webServer` · 최상위 `use.baseURL` · `executablePath` · `channel`은 두지 않는다.
- 자격을 쓰는(live) 실행은 검토된 자격 블록 안에서만 한다: `JT_E2E_BLOCK`이 루트 설정의 `metadata.jtApprovedBlock`과 같아야 하고(지금은 `null`이라 live는 늘 `[guard] outside-reviewed-block (T077-a)`에서 멈춘다), tester의 Credentials 규칙(`.claude/agents/tester.md`)을 따른다.

## Artifacts: zero

- 모든 프로젝트는 `trace` · `video` · `screenshot`을 끄고 돈다. 리포터는 `list` 하나뿐이다(HTML · blob · json · junit 금지 — HTML step 제목에 `fill` 값이 평문으로 실린다). `preserveOutput: 'never'`이다(needle 실행만 `'always'` — 그 스캔이 실패 산출물을 보게). `PLAYWRIGHT_NO_COPY_PROMPT=1` · `captureGitInfo` 끔 · `updateSnapshots: 'none'` · `snapshotDir`는 outputDir 아래다. outputDir과 증거 디렉터리는 저장소 밖에 있다. `workers: 1` · `fullyParallel: false` · `retries: 0` · `forbidOnly: true`.
- globalSetup이 이것을 실행 때 다시 단언한다. 다른 어느 가드보다 먼저 `e2e/.auth/` 잔여를 센다(잔여 → 지운 뒤 `[state] previous-run residue count=<n>` — 노출 의심). 디버그 · 프록시 · TLS env(`PLAYWRIGHT_*` · `PW_*` · `PWTEST_*`도 — `PLAYWRIGHT_TEST=1` · `PLAYWRIGHT_NO_COPY_PROMPT=1`만 예외 · `NODE_OPTIONS`는 허용 목록)와 CLI 덮기(`--trace` · `--reporter` · `--output` · `--workers` · `--retries` · `--update-snapshots` 등)에서 멈추고, 해석된 FullConfig를 다시 본다. 파일 단위 옵션 덮기는 `e2e/lib/test-base.ts`의 자동 픽스처가 잡는다(`[guard] fixture-override <name>`). 그래서 spec · needle · selftest-browser는 `test`를 `e2e/lib/test-base.ts`에서만 가져온다 — `@playwright/test`에서 직접 가져오지 않는다.
- `test-results/` · `playwright-report/` · `blob-report/`는 깊이와 무관하게 gitignore 대상이다. 파일은 이름으로만 스테이징한다(`git add -A` 금지). CI site job(T093)은 test-results · report · trace 아티팩트를 올리지 않는다.
- 증거 스크린샷은 `e2e/lib/evidence.ts`만 찍고, 모든 mask 로케이터의 수가 기대 행 수와 같을 때만 찍는다(아니면 `[product] mask-target-missing`). 파일은 `JT_E2E_EVIDENCE_DIR`에만 두고 커밋하지 않으며, 보고에는 파일 이름 · SHA-256 · 가린 칸만 싣는다.

## Credentials and exposure

- 자격 env(`JT_E2E_SECRET_*`)와 바늘 묶음(`JT_E2E_NEEDLE_SET`)은 `e2e/lib/env-contract.ts`만 읽는다 — 도달 단계가 통과한 시험 본문 안에서 한 번 읽고 `process.env`에서 지운다. 값이 없으면 이름만 나열한 `[env]` FAIL이다(SKIP이 아니다). 모드는 env가 아니라 프로젝트 이름으로 정한다.
- 모든 요청과 탐색(`request.*` · `page.request` · `context.request` · `goto` · `waitForURL` · `waitForResponse`)은 `e2e/lib/http.ts`를 지난다. 이 감싸개는 `<METHOD> <origin+pathname> failed (<code|status>)`만 담은 새 오류를 `cause` 없이 다시 던진다. `response.status()`는 수로 비교한다(`toBeOK()` 금지). 비밀 칸은 `e2e/lib/secret-input.ts`로만 채운다. 단언은 URL에 origin + pathname, IP · UA 칸에 개수, problem 본문에 `type`/`request_id` 유무만 쓴다.
- static-gate selftest(`e2e/selftest/static-gate.test.ts`)가 `e2e/**`와 루트 설정에서 이 규칙을 집행한다: 그 규칙 목록이 정본 목록이고, 규칙마다 심은 양성 대조가 있으며, 심은 키 집합 = 규칙 id 집합이다. 개요: 기록 · HAR · 첨부 · `page.pause` · request/response/console 리스너 · 값을 싣는 매처와 추출(`toHaveURL(` · `toHaveValue(` · `inputValue(` · `textContent(` …) · 헤더 · 본문 · 로그를 꺼내는 pull API(`allHeaders(` · `headerValue(` · `headerValues(` · `headersArray(` · `postData` · `.response(` · `requests(` · `consoleMessages(` · `pageErrors(` · `existingResponse(`)는 어디서나 금지다(`headers()`는 허용). `console.` · `process.stdout` · `process.stderr`는 `e2e/lib/out.ts`와 이름 붙은 예외(`launch.mjs` · `scan-needle.mjs` · needle-control spec)의 것이고, `storageState({ path`는 `e2e/lib/auth-dir.ts`, `screenshot(`은 `e2e/lib/evidence.ts`의 것이다.
- T087 예외와 범위 규칙: `e2e/lib/site-probe.ts`만 `request` 리스너를 둘 수 있고(규칙 `listener-request`) `evaluate` 허용 목록에 있다. 이 파일은 수와 불리언만 돌려주고, 리스너 매개변수 이름을 `request`로 짓지 않으며, `url()`을 읽지 않고, `out.ts`로만 출력한다(`emit-args` 규칙 적용). 이 파일을 import할 수 있는 것은 `e2e/hello.spec.ts`와 `e2e/selftest-browser/site-probe.test.ts`뿐이다(`site-probe-import`). `e2e/*.spec.ts`에서 `expect(`의 인자 코드는 `headers` · `.body` · `cookies(`에 닿지 않는다(`expect-args`).
- 출력 줄은 `e2e/lib/out.ts`를 지난다: 기계 판독 부분(첫 ` — ` 앞 · 런처와 하네스 줄은 ` -- ` 앞)은 ASCII이고 값을 싣지 않는다. 실패 분류 접두: `[gate]`(구현 부재 — 유일한 빨강 증거) · `[product]` · `[env]` · `[decision]` · `[guard]` · `[state]`.
- 바늘 값은 런처가 실행마다 만들고, 소스 · 픽스처 · selftest 기대값에 리터럴로 두지 않는다. `needle=PASS`는 정확한 의도 실패 · 모든 면 hits 0 · 경로별 양성 대조가 모두 잡힘을 요구한다. `@playwright/test`가 바뀔 때마다 `selftest` · `selftest-browser` · `needle`을 다시 돈다.
- 로그인 잠금 표식(`<token home>\AppData\Local\jt-e2e-lock\e2e-login-lock.json`)은 운영자가 원인을 확인할 때까지 모든 live 실행을 멈춘다. `e2e/` 안의 어떤 코드도 이 표식을 지우지 않는다.

## The `site` project (T087)

- `validateSiteTarget(BASE_URL, JT_E2E_SITE_MODE)`(`e2e/lib/site.ts`)가 허용하는 것은 정확히 이것뿐이다: `local` = origin `http://127.0.0.1:<port>` 또는 `http://localhost:<port>` · `prod` = 정확히 `https://joshuatech.dev`. 그 밖은 값을 싣지 않은 `[guard] site-target-not-allowed`다. `preview.joshuatech.dev`는 Access 뒤에 있어 자동 대상이 아니고, `next dev`도 대상이 아니다.
- `prod` 모드는 공개 apex에 요청한다 — 컨트롤러의 과제 조각이 지정할 때만 돈다. 어느 모드든 호출 사이에 `pace()` ≥ 200 ms를 지킨다(Free Rate Limiting 규칙).
- spec은 env를 읽지 않는다: site 모드는 프로젝트 `metadata`와 `baseURL` 픽스처로 `e2e/hello.spec.ts`에 닿는다. 모든 시험은 어떤 부재 단언보다 먼저 `reach`(`freshGet(<base>/ko)`)를 통과한다 — 예외는 local의 `/api/health` 건너뜀 하나다. 단계 줄은 값 없는 `T087 <step> PASS|FAIL <reason>`이다.
- reach 분류: local 연결 거부 + 웹 스캐폴드 없음 → `[gate] site-absent until T091`(빨강 서명) · 스캐폴드 있음 → `[env] site-server-not-running` · 그 밖 네트워크 오류 → `[env] network (<code>)` · `data-jt-app="web"`을 담은 200 `text/html` → PASS · 그 밖의 local 응답 → `[product]` · prod 52x/5xx → `[env] origin status=<n>` · 그 밖의 prod 응답 → T094 전 `[env] prod-site-not-v2`, T094 뒤 `[product]`.
- 계약 쿠키 이름(`__Host-jt_session` · `__Host-jt_csrf`)은 시험 자신의 상수(`e2e/lib/bff.ts`)이고 gateway에서 가져오지 않는다. needle · selftest 픽스처의 자리값 `jt_session=` 문자열은 계약 이름을 단언하지 않으므로 그대로 둔다.
