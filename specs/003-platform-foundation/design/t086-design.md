# T086–T089 설계: US5 시험 먼저 — 라이브 0 · 자격 0

대상은 콘텐츠 로더(T086) · hello E2E(T087) · 번들 예산(T088) · BFF gateway(T089)다. 사용자 결정(UD-7 · UD-7a · UD-8)의 BFF 시험 몫과 파드 조각 ⑤(UD-7a(ㄴ) — D15)를 함께 담는다.

- **상태**
  - **확정(2026-11-24) = r2 본문 + §7 확정 보정 N-1–N-19**(r2 검증 `verify-{A,B}-r2.md` — 둘 다 approve_with_fixes · HIGH 0 · 고칠 방향 전부 채택). 본문과 §7이 어긋나면 §7이 이긴다. 빌드는 아직이다.
  - r2가 반영한 것
    - r1 검증 새 결함 V-A-1–11 · V-B-1–13(`.superpowers/t086/design/verify-{A,B}-r1.md`) — 고칠 방향 전부 채택(decisions-controller.md:93–:99)
    - 컨트롤러 결정(r1 열린 항목 「컨트롤러가 정할 것」 1–8 전부 채택 — decisions-controller.md:87–:92)
    - 사용자 결정 T086-e 콘텐츠 로더 (A)(decisions-controller.md:104–:120) · B-6 쿠키 접두 채택(:122–:128)
  - 경과: 조사 3 → r0 → 비판 2렌즈 → UD-7 동향 조사 → 사용자 결정 → r1 → 검증 2렌즈 → 콘텐츠 로더 조사(`wf_565e05f3-de5`) → 사용자 결정(T086-e · B-6) → **r2** → 검증 → 확정
  - 과제가 닫힌 뒤에는 고치지 않는다(`.claude/rules/specs.md`). 달라진 점은 끝 「정정 노트」에 덧붙인다.
  - 표식: r2에서 바뀐 곳은 「(r2 — V-A-n · V-B-n · T086-e · B-6 · CD)」(CD = 컨트롤러 결정). r1 표식은 남긴다. 표식이 없는 문단은 r1(또는 r0) 그대로다.
- **입력**
  - 조사 R1 · R2 · R3(`.superpowers/t086/research/{spec-contract,tooling,bff-gateway}.md` — 인용 〔R1 3-2.5〕 꼴) · UD-7 동향(`research/ud7-trends/` — 〔U syn:51〕 꼴) · (r2) 콘텐츠 로더(`research/content-loader/{synthesis,mdx-safety,plugins-supply,content-layers}.md` — 〔CL syn §3〕 꼴)
  - 비판 r0 〔A-n〕 · 〔B-n〕 · (r2) 검증 r1 〔V-A-n〕 · 〔V-B-n〕
  - 컨트롤러 결정 문서 `.superpowers/t086/decisions-controller.md`(정본)
  - 선례: `design/t077-design.md` · 폐기 설계 `design/t073-design.md` D29(:1263–:1307) · §8(:2442 · :2488–:2547)
  - 기준: HEAD `88ba7bb`(브랜치 `003-platform-foundation`). §4 줄 번호는 r2에서 다시 확인했다.
- **표기**: 「추론」 = 실측 전 판단(§3 VD로 넘긴다) · 〔86-n〕 = report 편차 후보(§1-4) · 시험 id `ld-n`(T086) · `h-n`(T087) · `bb-n`(T088) · `G-n`(T089) · `O-n`(T089 도우미 자기 시험) · ⑤는 기존 id(`auth-n` · `ac-n` · `api-n` · `ia-n`) 개정 + 새 id `ac-25`~ · `ia-42`~
- **과제 문면**(tasks.md 그대로)
  - **T086**(:238): 「`packages/content/tests/loader.test.ts`(vitest): 001·002 노트 로드(제목·날짜·태그·slug·lang ko), `pubDate` 누락 fixture → 오류, `<slug>.en.mdx` → lang en + translations 연결, ko 파일 없음 → 오류, `draft:true`는 PROD에서 제외, `updatedDate < pubDate` → 오류, remark 헤딩 앵커·읽기 시간 — FAIL 확인」
  - **T087**(:239): 「`e2e/hello.spec.ts`(Playwright, `BASE_URL`): `/ko`·`/en`·`/ja` 200 + `data-note-slug` ≥ 2, `/` → 302 `/ko`(Accept-Language ko), `/ja`에서 번역 없는 노트 "번역 없음" 배지, **`/ko`·`/en`·`/ja` 응답에 `Set-Cookie` 헤더 없음**(contracts/bff-api.md 위생 규칙 — 쿠키는 `/api/auth/*`에서만 설정한다), **디자인 토큰 CSS 3계층 존재**(`primitive`→`semantic`→`component` 커스텀 속성이 계산 스타일에서 모두 해석됨), `/api/health` JSON `upstream: identity-admin`·`upstream_ms`(**CI의 로컬 `next start` 실행에서는 상류 identity-admin이 없으므로 이 케이스만 skip** — 판정은 prod 도메인에서 도는 T095), 응답 `x-request-id`, 페이지 로드 후 30초 내 `Next-Router-Prefetch: 1` 요청 ≤ 10(prefetch 폭주 가드); 반복 호출은 간격 ≥ 200 ms(VD-3 Rate Limiting에 스스로 걸리지 않게) — FAIL 확인」
  - **T088**(:240): 「`apps/web/scripts/bundle-budget.test.mjs`(vitest): dry-run outdir 픽스처의 gzip 합산 계산, 2,621,440 bytes 초과 시 exit 1, 이하 0 — FAIL 확인」
  - **T089**(:241): 「`apps/web/src/lib/gateway.test.ts`(vitest, fetch mock): PKCE 생성·state 검증, JWE 쿠키 암복호·버전 접두, 교환 캐시 TTL 5분(**기본 impersonation 교환** — 요청에 `actor_token`이 실리지 않음을 단언; VD-1이 옵션 A로 확정되면 그때 `actor_token` 케이스를 추가), `/session/check` 2 s 캐시·inactive → 쿠키 삭제·401 problem+json, 하류 헤더(Bearer·CF-Access-*·x-request-id·traceparent)는 정적 맵 대상에만, 상류 fetch 3 s AbortController 초과 → **503 `upstream_unavailable`**(RFC 9457 problem+json; 상류의 `denylist-unavailable` 503도 같은 코드로 중계, 쿠키는 유지), `/api/proxy`: **정적 맵에 없는 pod → 404 `not_found`(상류 호출 없음)**·허용 경로(`/tenants/me`·`/session/check`) 밖 → 404, `returnTo`는 `/`로 시작하고 `//`가 아닌 상대 경로만(절대 URL·`//evil` → 400 `invalid_return_to`), 이미지 로더(`src/lib/image-loader.ts`)가 `/cdn-cgi/image/…` 변환 오류(4xx/5xx)를 받으면 **원본 경로로 폴백**, 로그 JSON에 `request_id`·`upstream_ms`·`exchange_result` 있고 `Authorization`·`Cookie`·`CF-Access-*`·`code`·`state` 값 없음 — FAIL 확인」
- **규약**: 「Tests for User Story 5 (MANDATORY — write first, verify they FAIL)」(:236) · 「Tests MUST be written and FAIL before implementation」(:371) · 「E2E task … executed by the tester agent」(:374) · 「US5: T086–T089 병렬, T090 ∥ T091」(:381) · 「로컬 부분(T086–T093 작성)은 언제든」(:358) · 헌법 II(constitution.md:19). 초록 과제 = T090–T093(:245–:248), E2E 판정 = T095(:253). ⑤는 tasks.md에 없는 TDD 조각이다 — build-notes에 기록하고 converge가 대조한다(decisions-controller.md:53).

## 0. 사용자 · 컨트롤러 결정

| 결정 | 상태 | 내용 | 이 과제에 주는 영향 |
|---|---|---|---|
| **UD-7** 기본 로그아웃 범위 | 결정 2026-11-24 — (나) 그 기기만(r1) | 본문 생략 = `{all_devices:false, reason:"logout", sid}` · 「모든 기기」는 명시 `all_devices: true`만. 기준 조정 허용(§0-1) | C22 · C24 · C25 · G11 · 〔86-22〕 · 〔86-23〕 |
| **UD-7a** 결함 수정 | 결정 2026-11-24 — ① 둘 다(r1) | (ㄱ) 그 브라우저의 Authentik 세션 종료(RP-Initiated Logout) · (ㄴ) `revoked:sid` 값 = 폐기 시각(nbf) | (ㄱ) C23 · G11 · VD-T089-7–11 · (ㄴ) D15 ⑤ — T089 영향 0 |
| **UD-7c** end-session `logout` 이벤트가 사용자 단위 폐기로 번짐 | **사용자에게 여쭐 것 — T080 블루프린트 전 · UD-4와 함께**(r2 — V-B-3 · V-A-3 자료 보정) | §0-2-3 | T089 · T092 영향 0. T080 · T081 · identity-admin 후속 조각 |
| **UD-8** callback 입장 판정 | 결정 2026-11-24 — (나) 관례(r1) | callback은 identity-admin을 부르지 않는다(§0-3) | G3 · C29 |
| **T086-a** draft 노트 | 결정 2026-11-24 — A(r1) | 사용자 검토 · 승인 뒤 `draft: false`. 시점 = T091 첫 hello 렌더 전 ~ T093 전 | h-2 · h-5 초록 시점 |
| **T086-e** 콘텐츠 로더(r2) | **결정 2026-11-24 — (A) 자체 로더 + 순수 마크다운**(decisions-controller.md:109–:116) | ADR 0004 D19 그대로. `.mdx`를 순수 Markdown(+GFM · 프런트매터)으로 파싱하고 거부 플러그인이 위반을 빌드 실패로 만든다(§0-6) | D4 파이프라인 · 거부 규칙 · ld-13 · ld-14 · content.md 한 줄 · 〔86-28〕 · 〔86-29〕 · T090 설치 승인 지점 |
| **B-6** 쿠키 접두(r2) | **결정 2026-11-24 — 채택**(decisions-controller.md:122–:126) | `__Host-jt_session` · `__Host-jt_csrf` · `__Secure-jt_pkce`(§0-7) | C3–C5 · C28 · G1–G4 · G8 · G11 · G13 · 계약 · web.md · T079 상수 · 〔86-30〕 |
| T086-b · c · d | 컨트롤러 기본값(r1) | b: apps/web 최소 매니페스트 선행 · c: static-gate 예외를 `site-probe.ts` 한 파일 + 범위 규칙으로(r2 — V-B-6 규칙 둘 추가) · d: vitest 5.0.5 재사용 · 새 패키지 0 | D2-3 · D10-4 · D3 |
| **CD** 컨트롤러 결정(r2) | 결정 2026-11-24(decisions-controller.md:87–:99) | T-c(`revoked:sid` 330 s + `identity-admin:sid-floor:{sid}` 30 d · `/session/check`만) · L2(204/401/503 + `x-end-session-url`) · 슬러그 `invalid_request` · C24 `sid` 필수 · ⑤ 독립 TDD 조각 · 템플릿 jinja + 하네스 + recopy diff · t077 정정 노트 · `bff.ts:59` 주석 · V-A-4 · V-A-5/V-B-7 · V-A-6/V-B-13 · V-B-1 · V-B-2 · V-B-10의 선택 | 본문 전체(「권고 · 채택 시」 꼴은 지웠다) |

### 0-1. UD-7 = (나)(r1 — UD-7)

- **근거**: 표준은 범위를 앱에 맡긴다(RFC 10017 §6.1.2.1 — 〔U syn:26〕). ASVS 5.0 · NIST 800-63B-4 · OWASP CS 2026-11은 로그아웃 = 그 세션. 업계 예외는 Supabase 하나(〔U syn:7–16〕). 사용자 답 「관례대로 기기 단위로 하고 결함 고쳐 관례 기준으로 기준 조금 내려도 좋아」(decisions-controller.md:37).
- **하류 매핑**(C22)

  | logout 요청 본문 | 범위 | `/sessions/revoke` 본문(정확) |
  |---|---|---|
  | 없음 · `{}` · `{"all_devices": false}` | 이 기기 | `{"all_devices": false, "reason": "logout", "sid": "<쿠키 sid>"}` |
  | `{"all_devices": true}` | 모든 기기 | `{"all_devices": true, "reason": "logout_all"}`(`sid` 키 0) |
  | 그 밖 | 판정하지 않는다 | 400 `invalid_request` · 상류 0(C25) |

- **갈래**(C22 · C23): 쿠키를 지우는 응답과 쿠키 없는 401에는 `x-end-session-url`이 붙는다(r2 — V-B-10).
  - inactive: `/sessions/revoke` 0 → RFC 7009 → 삭제 → 이 기기 204 · 명시 `all_devices: true` 401 `session_revoked`(계약 :32 문면과 이미 맞는다).
  - 확인 503: RFC 7009만 → 삭제 → 503.
  - (r2 — V-B-1) 내부 refresh `invalid_grant`: **503**(쿠키 삭제 · 헤더 유지 · 기록 없음). r1의 「inactive와 같은 응답(204)」은 버린다 — 다른 isolate의 회전 경합이면 세션이 살아 있는데 성공으로 보였다(§5-1-14). VD-T089-12 뒤 다시 본다.
  - 그 밖의 실패: 삭제 → 503.
- **조용히 넓히지 않는다**: 이 기기 요청은 어떤 실패에서도 `all_devices: true`로 바꿔 보내지 않는다. 쿠키에 `sid`가 없는 경우는 C24(`sid` 필수)로 생기지 않는다.
- **기준 조정**(사용자 허용 — 〔86-22〕 · 〔86-23〕)
  - 이 기기: 복사 쿠키로 BFF를 거친 호출이 2 s 안에 401(SC-003의 2 s · 확인 캐시 2 s). pod 직접 즉시 거부는 없다(교환 토큰에 `sid` 없음 — denylist.md:23 · 토큰은 BFF 밖으로 나가지 않는다 · 확인 뒤에만 교환 캐시 사용 — bff-api.md:24 · :48). 교환 토큰 잔여 ≤ 330 s.
  - (r2 — V-B-2) 이 기준은 **`/sessions/revoke`가 202로 기록된 경우에만** 성립한다. 기록되지 못한 갈래(503 전부 · `invalid_grant` 503)와 시계 틈(≤ 60 s)은 §5-1-10.
  - 모든 기기: AC3(spec:106) 문면 그대로 — T079가 잰다(e2e/lib/bff.ts:59–60). AC3의 「로그아웃 → `revoked:sub`」는 이 경로에만 해당한다.
- **(r2 — V-A-11 · V-B-11) 결정이 바꾼 비용**
  - 이 기기 + (ㄱ): 그 브라우저의 Authentik 세션만 끝난다. 같은 브라우저의 관리 앱(Argo CD · Vault · admin)은 자기 세션이 끝났거나 SLO가 걸렸을 때만 재로그인한다(VD-T089-8 ①). r1의 「다시 로그인해야 한다」는 과장이었다. 다른 기기는 그대로다.
  - 모든 기기(명시): prod에서는 D16 위임이 그 사용자의 **모든** Authentik 세션을 지운다 — 운영자라면 모든 기기의 관리 SSO가 끊긴다. r1 §6의 「(가)의 비용은 생기지 않는다」는 기본 경로에만 맞다. T091 UI 인계(§5-2).

### 0-2. UD-7a = ①(r1 — UD-7a)

#### 0-2-1. (ㄱ) 로그아웃이 그 브라우저의 Authentik 세션을 끝낸다

- **까닭**: 앱에서 시작한 Authentik 로그아웃은 provider의 invalidation flow를 돈다. 기본 흐름에는 User Logout 단계가 없어 앱 세션만 끝난다(〔U ind:59〕 · https://docs.goauthentik.io/add-secure-apps/providers/single-logout/ — 2026-11-24 열람 · 동작은 VD-T089-7). 그대로면 공용 PC의 다음 사람이 비밀번호 없이 앞 사람으로 로그인된다.
- **응답 꼴 = L2(CD 결정)**: 상태 · 본문은 그대로(204 · 401 · 503 problem), BFF가 만든 헤더 `x-end-session-url`을 싣는다. 대안 L1(200 JSON — T079 `judgeLogout`(bff.ts:182–185) · selftest(bff.test.ts:285) · cleanup(revocation.spec.ts:265) 개정 · C16 예외) · L3(폼 POST 303 — CSRF 계약 변경 · `maxRedirects: 0` 깨짐) · L4(202 + `Location` — 의미 미정 · B-1 규칙 예외)는 기각했다. L2는 tick된 T079 코드 · RFC 9457 꼴 · 「응답 헤더는 BFF가 만든다」(bff-api.md:45)와 모두 맞는다.
- **주소 구성**(C23): `new URL('end-session/', AUTHENTIK_ISSUER)`(앱별 경로 `/application/o/<slug>/end-session/` — https://docs.goauthentik.io/add-secure-apps/providers/oauth2/ · VD-T089-4). 질의는 정확히 `client_id`(= `WEB_BFF_CLIENT_ID`) · `post_logout_redirect_uri`(= 요청 origin + `/`). `/`는 Accept-Language 302 Route Handler라 착지는 로케일과 무관하다.
  - **열린 리디렉션 금지**: 값은 설정과 `new URL(request.url).origin`에서만 온다(질의 · 본문 · `origin` · `referer` · `x-forwarded-host` 0). 등록(T080): web-bff `https://joshuatech.dev/` · web-bff-dev `https://preview.joshuatech.dev/` · `http://localhost:3000/`. `www`는 존 리디렉션이라 Worker에 닿지 않는다(tasks.md:249).
  - **`id_token_hint`는 싣지 않는다 — 규격상 귀결을 VD로 잰다**(r2 — V-A-1 · V-B-5: 근거를 규격 원문으로 바꿨다. r1이 인용한 〔U standards:37〕에는 RECOMMENDED · OPTIONAL 문장이 없다)
    - OIDC RP-Initiated Logout 1.0(https://openid.net/specs/openid-connect-rpinitiated-1_0.html — 2026-11-24 열람)
      - §2: `id_token_hint` 「RECOMMENDED」 · `client_id` 「OPTIONAL」. 「At the Logout Endpoint, the OP SHOULD ask the End-User whether to log out of the OP as well. Furthermore, the OP MUST ask the End-User this question if an id_token_hint was not provided …」
      - §3: `id_token_hint`가 없으면 「the OP MUST NOT perform post-logout redirection unless the OP has other means of confirming the legitimacy of the post-logout redirection target」 · 등록값과 정확히 같지 않은 `post_logout_redirect_uri`면 리디렉션 금지.
    - 귀결(추론): Authentik이 이 MUST를 따르면 end-session이 사용자 클릭에 달린다 — 공용 PC에서 확인 화면을 누르지 않고 떠나면 Authentik 세션이 남고(UD-7a(ㄱ) 목적 붕괴), 착지 리디렉션도 없을 수 있다. 우리 흐름 `web-bff-invalidation`은 User Logout 단계 하나라 확인 단계가 없지만, OP가 따로 끼우는지는 모른다.
    - 그래서 VD-T089-7 합격선에 「`x-end-session-url` 이동 뒤 **추가 클릭 0**으로 세션 종료 · 확인 화면 0」, VD-T089-10에 「착지 리디렉션 여부」를 둔다. 어긋나면 (a) 흐름 배치를 고친다(T080 — User Logout이 첫 단계 · 확인 단계 0) → (b) 그래도 확인 화면이면 사용자 결정(`id_token_hint` 싣기 vs 확인 단계 수용 + UI 안내 — §5-3).
    - 싣지 않는 까닭(그대로): ID 토큰(약 1 KB 추정 · `email` · `name` · `sid`)이 `__Host-jt_session`을 키우고(G4 < 4096 여유), 값이 URL 질의로 브라우저 기록 · Traefik 접근 로그 · Referer에 남는다(UD-10과 같은 범주 — 추론).
  - **`state`는 싣지 않는다**: 착지(`/`)는 상태를 바꾸지 않는 GET이고 검증할 처리기가 없다.
- **Authentik 쪽**(T080): web-bff · web-bff-dev provider `invalidation_flow` = 전용 흐름 `web-bff-invalidation`(User Logout 단계 하나 · 확인 단계 0). 공유 `default-provider-invalidation-flow`는 고치지 않는다(다른 provider 로그아웃이 바뀐다). 전용 흐름은 UD-7c 판별자이기도 하다(§0-2-3).
- **클라이언트 규약**(T091 · T092 인계 — r2 — V-B-2 · V-B-1)
  1. logout 전에 진행 중인 BFF fetch를 끝내거나 취소한다(직렬화 — 같은 탭의 회전 경합 축소).
  2. 응답에 `x-end-session-url`이 있으면 상태와 무관하게 top-level 이동(`location.assign`).
  3. **상태가 204가 아니면** 이동 전에 `sessionStorage`에 값 없는 표식(`jt-logout-result` = `401` | `503`)을 남기고, 착지 페이지가 읽어 「로그아웃이 완전하지 않습니다 — 다시 로그인해 '모든 기기에서 로그아웃'을 하세요」를 보인 뒤 지운다(쿠키 0 — 위생 규칙 유지).
  4. 「모든 기기」는 따로 둔 조작이 명시 본문을 보낸다. prod에서는 관리 SSO를 포함한 모든 Authentik 세션이 끝난다는 안내를 단다(V-B-11).
- **남는 틈**(§5-1-11 · 12): 그 주소에 닿지 못하면 Authentik 세션이 남는다(탐지 불가) · 상류 IdP(GitHub) 세션은 남는다 · SLO 부수 효과(VD-T089-8).

#### 0-2-2. (ㄴ) `revoked:sid` 값 = 폐기 시각 — 세부는 D15

- 사용자 결정: 값 = nbf(`revoked:sub`와 같은 꼴) · `/session/check`와 pod 미들웨어는 「값 > iat」(같으면 통과). W35(재로그인 = 같은 `sid` — t073-design.md:2532)를 고친다.
- 세부(D15): nbf = ⌊t⌋ + 1 유지 · 시계 영역(VD-T081-5) · **수명 구조 T-c(CD 결정)** — `revoked:sid` 330 s 그대로 + `identity-admin:sid-floor:{sid}` 30 d(`/session/check`만) · (r2 — V-A-6 · V-B-13) 두 값 모두 정규 꼴(ASCII 숫자 1–19자)로 판독 · 밖이면 503.
- 자리: US5 빌드 안 TDD 조각 ⑤(api-builder · 커밋 7). 배포 = 다음 main 발행(UD-1 재질문 — BFF가 처음 identity-admin을 부르기 전).
- BFF가 보는 의미(`sid` · `issued_at` → `active`)는 그대로라 T089 시험 영향 0.

#### 0-2-3. UD-7c — end-session의 `logout` 이벤트와 「늘 사용자 단위」 기록의 충돌(사용자에게 여쭐 것 — r2 — V-B-3 · V-A-3 자료 보정)

- **사실**
  1. User Logout 단계는 Django 로그아웃을 불러 Authentik `logout` 이벤트를 남긴다(추론 · VD-T089-8 ②).
  2. identity-admin은 `logout` 이벤트를 두 길로 받는다: 웹훅(UD-4 권고 B — T081 Notification Rule · t073-design.md:2493) · 일 1회 대조(UD-2 `view_event` 부여 시 — jobs.py:47–:59).
  3. 두 길 모두 **늘 사용자 단위**로 기록한다(`sid` NULL 행 + `revoked:sub` + 세션 하한 — identity-admin-api.md:59 · :65 · jobs.py:381).
  4. (r2 — V-B-3) **dev · prod identity-admin은 한 Authentik의 모든 `logout` 이벤트를 함께 받는다**(identity-admin-api.md:66 「dev · prod가 한 Authentik을 써 모든 logout이 두 env에 오므로」). 같은 사람의 `sub`는 두 env에서 같다.
- **결과**: 이 기기 로그아웃 하나가 수 초(웹훅) · 하루 안(대조)에 그 사용자의 모든 기기 로그아웃이 된다 — **그 env와 다른 env 모두에서**. 예: preview · 로컬 `next dev`(web-bff-dev) 로그아웃 → prod에 운영자 · e2e 사용자의 사용자 단위 폐기. UD-7 (나)가 늦게 오는 (가)가 된다.
- **선택지**(T089 · T092 영향은 어느 쪽이든 0)

  | 안 | 내용 | 교차 환경(V-B-3) | 대가 |
  |---|---|---|---|
  | **(가′) 전용 흐름으로 가른다(권고)** | `web-bff-invalidation`에서 생긴 `logout` 이벤트는 사용자 단위로 기록하지 않는다(그 세션은 BFF가 `sid`로 이미 기록했다). Authentik 화면에서 직접 한 로그아웃(brand 흐름 — e2e/lib/authentik-flow.ts:37 · T079 AC4)은 그대로 사용자 단위 | 성립 — 두 provider가 한 흐름을 쓰므로 두 env가 같은 판별자로 거른다 | 판별자가 이벤트 context에 남아야 한다(VD-T089-8 ③). 웹훅 · 대조 필터(코드 · 계약 · 시험) + 웹훅 매핑 |
  | (나′) 우리 데이터로 상관 | 이벤트 시각 c에 대해 같은 sub의 `sid` 행 nbf ∈ [c − W, c + 1]이면 건너뛴다 | **같은 env 안에서만** 성립 — 다른 env에는 `sid` 행이 없어 사용자 단위로 기록된다(닫힌 쪽 번짐) | 창 W 안의 진짜 Authentik 로그아웃을 놓친다(열린 쪽) · 시계 차 VD-T081-5 |
  | (다′) `logout` 이벤트를 폐기 기록에 쓰지 않는다 | UD-4 B 철회 · 대조 중단 | 해당 없음 | AC4 · SC-003 편차가 커진다 |
  | (라′) 받아들인다 | — | 두 env 번짐 | UD-7 (나)와 모순 — 비권고 |

- **VD 폴백과의 교차**(r2 — V-A-3)
  - VD-T089-7 폴백(end-session이 provider 흐름을 돌지 않아 C23 값을 brand 무효화 흐름 `/flows/-/default/invalidation/`으로 바꿈)이면 BFF 로그아웃 이벤트가 AC4 화면 로그아웃과 같은 흐름에서 나온다 → **(가′) 불가** → (나′)로 간다. 이때 교차 환경 번짐이 남으므로 사용자에게 「(나′) + 교차 환경 번짐 수용」 vs (다′)를 다시 여쭌다.
  - VD-T089-11 폴백(전용 흐름 끝 환경별 고정 Redirect 단계)이면 흐름이 provider마다 갈라져 판별자 slug가 둘이다(`web-bff-invalidation` · `web-bff-dev-invalidation`) → (가′) 필터는 닫힌 목록 둘을 본다.
  - VD-T089-8 ③에서 판별자가 이벤트에 남지 않으면 위 첫 항과 같은 갈래다.
- **권고**: (가′). 위 갈래가 생기면 다시 여쭌다.
- **순서 제약**(r2 — V-B-3로 넓힘 · decisions-controller.md:86): 해소 조각이 라이브에 들기 전에는, **어느 BFF(prod · preview · 로컬 `next dev`)든 end-session을 내거나 사람이 end-session으로 실측하는 동안** 웹훅 `logout` Rule(T081) · 대조 권한(UD-2)을 켜지 않는다. T081은 VD-T089-7–11을 Rule을 켜기 **전에** 잰다.

### 0-3. UD-8 = (나)(r1)

- 사용자 답 「관례에 따른다」(decisions-controller.md:59). callback은 identity-admin을 부르지 않는다(bff-api.md:31 · C29). 관례: 폐기 뒤 재로그인은 IdP 쪽 세션 종료로 막는다(Okta Universal Logout · Entra `revokeSignInSessions` · authentik Account Lockdown — 〔U ind:56–:61〕).
- 조건: 런북 T114 한계 문장 · T085에서 D16 위임 실패가 보이면 (가)를 다시 여쭌다.
- 남는 틈: D16 위임 실패 · dev(위임 없음) · end-session 끊김 · (r2 — V-A-1) OP 확인 화면을 누르지 않고 떠남(VD-T089-7). W35는 (ㄴ)으로 없다.

### 0-4. T086-a = A(r1)

- 「PROD에서 draft 제외」(spec:124 · data-model.md:241)와 「노트 2편」(SC-007 spec:332)이 001 · 002 `draft: true`(001-claude-setup.mdx:9 · 002-smoke.mdx:8) 동안 같은 프로덕션 빌드에서 함께 서지 않는다. 사용자가 공개 기준(content.md:30)으로 검토 · 승인하면 `draft: false`(content.md:20의 사람 몫). 시점 = T091 첫 렌더 전 ~ T093 전. ld-1은 draft 값을 단언하지 않는다.

### 0-5. 컨트롤러 기본값(r1)

- CI 배선 소유 = T093 한 번(content · web vitest · bundle-budget · Playwright `site` 로컬). T090 → T093 사이 CI는 content 시험을 돌지 않는다(§5-1-6).
- 설치 · 기반은 컨트롤러가 따로 커밋한다(D14) — 병렬 빌더의 lockfile 충돌 방지 · 렌즈 C가 lock 차이만 본다.
- `e2e/**` 경로 규칙은 T087 커밋에 넣는다(t077-design.md:50 · :392): `.claude/rules/e2e.md` + KR · AGENTS.md 행 · codex-parity `$ruleDocs`(고정 목록 — tests/agents/codex-parity.tests.ps1:180)에 `'e2e.md'` · web-builder.md :18 · :24 + KR(r1 — A-10).
- T092 몫 사례는 D7 끝 목록.
- (r2) T091 전 사용자 질문(곁가지 셋)은 §5-3.

### 0-6. T086-e = (A) 자체 로더 + 순수 마크다운(r2 — T086-e)

- **조사 결론**(〔CL syn §1–§5〕): 통째로 덮는 오픈 소스는 없고, MDX 실행 차단을 내장한 콘텐츠 레이어는 0이다. Fumadocs MDX 15.6.4도 읽기 시간 · 프로덕션 draft 제외 · 「번역만 있으면 오류」 · MDX 가드가 빠지고 의존이 약 2배 + 네이티브다. next-mdx-remote는 CVE-2026-0969 뒤 아카이브됐다.
- **결정 내용**(decisions-controller.md:109–:116): ADR 0004 D19 그대로(새 ADR 없음)
  - `.mdx`를 순수 Markdown으로 파싱: remark-parse + remark-gfm + remark-frontmatter(yaml). remark-mdx · rehype-raw 0.
  - 거부 플러그인이 `file.fail`(파일 · 줄 · 규칙 이름)로 빌드를 멈춘다: `html` 노드 · 줄 첫머리 `import`/`export` · `{}` · link · image · definition URL이 허용 목록(http · https · mailto · 상대 · `#`) 밖(규칙 표 = D4).
  - 프런트매터 = `yaml`(gray-matter 금지 — `---js` 프런트매터를 `eval`한다 〔CL mdx ①7〕) · `sources[].url` http(s) · `path` 저장소 상대.
  - 읽기 시간 = 자체 함수(`Intl.Segmenter` · 글자 수 — reading-time 1.5.0은 2021 정지) · TOC = rehype-slug 뒤 헤딩 수집(또는 mdast-util-toc) · 하이라이트 = @shikijs/rehype(쓰는 언어만) · 지우기형 도구(blockJS · remove-* · rehype-sanitize) 0.
  - 번들: 컴파일 코드는 Node 빌드 단계에서만 · 페이지는 결과만 import · 프로덕션 산출물에서 draft를 생성 단계에서 뺀다.
  - T086 시험에 금지 구문별 실패 픽스처(파일 · 규칙 이름 단언 — 아무것도 막지 않는 가드가 초록이 되지 않게).
  - content.md 한 줄 + KR(§4-2).
  - 다시 검토: 컴포넌트가 필요해지면 remark-mdx + 거부 플러그인(허용 목록) — 그때 새 ADR. TOC · 하이라이트 유지 비용이 커지면 Fumadocs 재평가.
- **설치**: T086 시험은 새 의존 0이다(vitest · `node:*` · `../src/index`만 — T086-d 그대로). 로더 의존(D4 「T090 의존 목록」)은 **T090 착수 때** 컨트롤러가 목록 · 판 · 전이 수 · lock 차이를 보이고 사용자 승인을 받아 기반 커밋으로 설치한다(§5-3).

### 0-7. B-6 = 쿠키 접두 채택(r2 — B-6)

- 이름: `__Host-jt_session` · `__Host-jt_csrf` · `__Secure-jt_pkce`(Path가 `/api/auth/callback`이라 `__Host-`가 아니다).
- 까닭: 형제 서브도메인(PR 코드가 도는 `preview.` 포함)이 apex에 같은 이름 쿠키를 심는 것(세션 고정 · 이중 제출 교란)을 브라우저가 막는다. 배포 전이라 옮기는 비용이 0이다. `Secure` · `Path=/` · Domain 없음은 이미 지킨다(C28).
- 함께 고칠 곳: bff-api.md :21–:22 · `jt_pkce` 행(새 행) · :67 · :96 · web.md · quickstart.md:90 · T079 상수(e2e/lib/bff.ts:56–57) · selftest(e2e/selftest/bff.test.ts) · e2e/README.md:61 — T079는 tick 뒤라 t077 정정 노트.
- BFF는 **접두 없는 옛 이름(`jt_session` · `jt_csrf`)을 읽지 않는다**(없는 것과 같다). 같은 이름이 둘 이상 오면 무효 쿠키(C5).
- pod 로그 마스킹은 `__Host-` · `__Secure-` 접두를 벗긴 이름으로 판정해 변경 0(django-pod.md §Logging · test_observability_contract.py:1185–:1187).
- localhost `Secure` · 접두 쿠키 동작 = 기존 VD-T085-b.
- G 사례는 이름 · 속성을 정확 비교한다(C28). 시험은 이름을 자기 상수로 둔다(gateway에서 가져오지 않는다 — 독립 기대값).

## 1. AC 대응과 합격선

### 1-1. 과제 ↔ AC ↔ 합격선

| 과제 | AC · FR | 시험 | 합격선(시험 작성 + 올바른 이유의 빨강) | 초록 |
|---|---|---|---|---|
| T086 | AC2(spec:124) · FR-029(:272) · Edge :221 · (r2 — T086-e) 본문 안전 규칙 | `packages/content/tests/loader.test.ts` + `tests/fixtures/**`(D4) | ① 빨강: 수집 실패 1 · 원인 `../src/index` 부재 ② 인프라 초록: `vitest --version` 5.0.5 · 임시 스모크 1 passed(삭제) ③ 공허 검사: 던지는 스텁 · 관대한 스텁 → passed 0 · (r2) 가드 없는 스텁 → ld-13 금지 사례 passed 0 · 과잉 가드 스텁 → ld-13 대조 사례 passed 0(D12) ④ frozen 설치 · `@jt/events` 초록 ⑤ 새 의존 0(r2) ⑥ `git status` = 지정 파일 | T090 |
| T087 | AC1 · AC2(목록 · 표시 필드) · AC3 일부 · AC5 · FR-023 · FR-027 · FR-031 · Edge :210 · SC-007 | `e2e/hello.spec.ts` 9건 + `e2e/lib/{site,site-probe}.ts` + selftest + 기반 갱신(D10) | ① 런처 `selftest` · `selftest-browser` 실패 0 · `needle=PASS` · `list` `site=9` ② `site-red` 끝 줄 `gate-site=8/8` · skipped 1(h-7) · passed 0 ③ 저장소 밖 계약 스텁 양성 8 PASS + 변이(D12) ④ 잔여 0 ⑤ (r2 — B-6) T079 상수 개정 뒤 `selftest` 초록 | T090 · T091 · T092 + T086-a → CI T093 → 판정 T095 |
| T088 | AC4(:126) · FR-028 · Edge :209 | `apps/web/scripts/bundle-budget.test.mjs`(D5) | ① 빨강: 수집 실패 1 · `./bundle-budget.mjs` 부재 ② 저장소 밖 참조 구현 전부 통과 + 변이 7 각각 검출 ③–⑤ T086과 같다 | T093 |
| T089 | FR-023 · FR-027 · FR-030 · VD-1 · Edge :202 · :207 · :212 · bff-api.md 전체 + UD-7 · UD-7a(ㄱ) · UD-8 · B-6(r2) | `apps/web/src/lib/gateway.test.ts`(D6–D9) + `src/lib/__tests__/oracles.test.ts` | ① 빨강: gateway 사례 전부 실패 · passed 0 · 원인 = `./gateway` · `./image-loader` 부재 **그리고** `oracles.test.ts` 전부 통과 ② 던지는 · 관대한 스텁 → passed 0 ③ 저장소 밖 부분 참조 gateway(G2 · G10 · G11-12 + 그 세 묶음 경로의 G13 사례 — r2 — V-A-10)에서 그 묶음 통과 + 누출 변이 7 각각 검출(D12) ④ CI 꼴 로컬 gitleaks 0 · 새 시험 파일 `gitleaks:allow` 0 ⑤ frozen · `@jt/events` 초록 ⑥ `git status` | image-loader T091 · gateway T092 |
| ⑤ UD-7a(ㄴ) | UD-7a(ㄴ) · denylist.md · identity-admin-api.md · W35 · E13 | django-common · identity-admin · 템플릿 시험(D15-6) | ① 시험 먼저 빨강 — 원인이 D15-6 표와 같다 ② 초록: django-common · identity-admin 스위트 · 템플릿 하네스 ③ identity-admin 렌더본 = 템플릿 렌더(recopy 뒤 `git diff`가 의도한 줄뿐) ④ 계약 · 규칙 정합(§4-2 ⑤ 전 줄 — 렌즈 D) ⑤ 라이브 변경 0 | 조각 안 — 배포는 UD-1 재질문 뒤 |

### 1-2. 오늘 기대(올바른 이유의 빨강)

- **T086** `pnpm --filter @jt/content --fail-if-no-match test` → `FAIL tests/loader.test.ts` · `Test Files 1 failed (1)` · exit 1. 메시지에 `../src/index`가 있으면 같은 원인(판에 따라 `Cannot find module` · `Failed to load url` — T064 K8). 에이전트 세션 리포터는 minimal이라 끝 요약 줄이 증거다(〔R2 2-2〕 · 추론).
- **T088** `pnpm --filter @jt/web exec vitest run scripts/bundle-budget.test.mjs` → 수집 실패 1 · `./bundle-budget.mjs` · exit 1.
- **T089** `pnpm --filter @jt/web exec vitest run src/lib/gateway.test.ts` → `Tests N failed (N)` · passed 0 · exit 1(실패 줄마다 `./gateway` · `./image-loader`). 수집 실패 1로 나오면(VD-T089-1) 빨강으로 받고 D9-1 갈라 두기를 한다. `… vitest run src/lib/__tests__/oracles.test.ts` → 전부 통과 · exit 0.
- **web 전부** `pnpm --filter @jt/web --fail-if-no-match test` → `Test Files 2 failed | 1 passed (3)` · exit 1.
- **T087** `node e2e/lib/launch.mjs site-red`(루프백만)

| id | 단언 | 오늘 기대 | 초록 |
|---|---|---|---|
| h-1 | `/ko` · `/en` · `/ja` 200 · `text/html` · v2 표식 | FAIL `[gate] site-absent until T091` | T091 |
| h-2 | `[data-note-slug]` ≥ 2 · 001 · 002 각 1 · 노트마다 제목 · 날짜 · 태그 표식 | 같음 | T090 · T091 · T086-a |
| h-3 | 세 로케일 + `/` `set-cookie` 0 · 브라우저 쿠키 0 | 같음 | T091 |
| h-4 | Accept-Language 사례 표 → 302 + Location | 같음 | T091 |
| h-5 | `/ja` 배지 각 1 · `data-note-lang="ko"` · `/ko` 배지 0 | 같음 | T090 · T091 · T086-a |
| h-6 | site-probe 판정 전부 참 | 같음 | T091 |
| h-7 | prod: 200 JSON 꼴 · `x-request-id` · Set-Cookie 0 | **SKIP**(local — reach 전) | T092 · T094 → T095 |
| h-8 | `/api/proxy/not-a-pod/x` → 404 problem · `x-request-id` · nosniff · Set-Cookie 0(env 0에서도 — C26) | FAIL gate | T092 |
| h-9 | `/ko` 로드 뒤 30 s n ≤ 10 · `INFO prefetch n=<n>` | FAIL gate | T091(판정 T093 · T095) |

- 끝 줄 `site-red passed=0 failed=8 skipped=1 gate-site=8/8 child-exit=1 root=removed` · exit 1. 첫 단계 줄 `T087 reach FAIL [gate] site-absent until T091 — loopback refused and apps/web scaffold absent (next.config.ts)`. 다른 줄(`[env]` · `[guard]` · `[product]`)은 잘못된 이유의 빨강이다.

### 1-3. 초록이 되는 순서

- T086 ← T090 · T088 ← T093 측정부(VD-2 동석과 한 과제라 tick 날짜가 다를 수 있다) · T089 image-loader ← T091, gateway ← T092 · T087 로컬 = T090 · T091 · T092 + T086-a, CI = T093, prod = T094 뒤 T095 · ⑤ ← 조각 안 구현(라이브 = UD-1 재질문 뒤 · BFF 첫 identity-admin 호출 전 — D15-8).

### 1-4. report 편차 후보(`/finish`가 report.md 「편차」로 옮긴다)

| 번호 | 내용 | 근거 |
|---|---|---|
| 86-1 | T087 「응답 `x-request-id`」 → BFF 응답에서만(h-8 프록시 404 — env 없이 · h-7 prod) | bff-api.md:3 · 〔R1 3-2.7〕 |
| 86-2 | T087 `/` 302 → 사례 표 7개 · 헤더 명시 | playwright.config.ts:80 · 〔R1 3-2.2〕 |
| 86-3 | T087 prefetch → `/ko` · ≤ 10 · 하한 없음 · `INFO` · 헤더 이름 양성 대조는 selftest-browser · VD-T087-3 | web.md:17 · 〔A-1〕 |
| 86-4 | 토큰 3계층 → 접두 `--jt-ref-` · `--jt-sys-` · `--jt-comp-` + 참조 방향 + 계산값 + dark에서 ref 불변 | web.md:53–:54 |
| 86-5 | Set-Cookie → local 0 · prod 앱 쿠키 0 · 엣지 이름 INFO(VD-T087-4) | 〔R1 3-2.4〕 |
| 86-6 | `/api/health` skip → 명시 모드 local일 때만 · reach 전 | t077-design.md:195 · 〔A-8〕 |
| 86-7 | 「번역 없음」 → `data-translation-missing` + `/ko` 음성 + `data-note-lang="ko"` | static-gate.test.ts:52–:58 |
| 86-8 | 「`data-note-slug` ≥ 2」 → + 001 · 002 각 1 + 제목 · `time[datetime]` · 태그 표식 | spec:124 · 〔R1 3-2.8〕 |
| 86-9 | 이미지 로더 폴백 → `onerror=redirect` + `fallbackSrc`(클라이언트 `onError`는 T091) · ADR 0004:28 `images.unoptimized`와의 어긋남 | 〔R3 ④ G〕 |
| 86-10 | T089 범위 = 문면 ∪ 계약 배정 ∪ D7 결정 ∪ 사용자 · 컨트롤러 결정의 BFF 몫 | bff-api.md:32 · :40 · :45 · :48 · :96 |
| 86-11 | `getCollection` 옵션 `root` 추가 · `includeDrafts` 기본 = `NODE_ENV !== 'production'` | tasks.md:245 |
| 86-12 | T086 문면보다 엄격(아래 목록) | data-model.md:231–:245 · content.md:27 |
| 86-13 | T088 픽스처 = 실행 중 임시 디렉터리 · 측정 CLI · 빈 디렉터리 exit 2 | 〔R2 ④ 결정 4〕 |
| 86-14 | `apps/web/package.json`을 T091보다 먼저 | tasks.md:246 |
| 86-15 | bff-api.md 계약 보정(D7 C1–C29 — 「T089 보정 2026-11-2x」). (r2) 더한 것: logout 판정 순서 · 쿠키 없는 401의 `x-end-session-url`(V-B-10) · 설정 무효에서도 logout 쿠키 삭제(V-A-4) · 내부 refresh `invalid_grant` 503(V-B-1) · `return_to` ASCII · 깨진 퍼센트 · 중복 · 바이트 상한 · Location 꼴(V-A-5 · V-B-7) · 쿠키 이름 접두 · `__Secure-jt_pkce` 행(B-6) · 프록시 `sid` 필수 문장(V-A-7) | web.md:10 「계약 우선」 |
| 86-16 | content.md `sources` 주석 → `path` 또는 `url` 하나 | 001-claude-setup.mdx:16–17 · data-model.md:243 |
| 86-17 | UD-7 · UD-7a · UD-8 결정이 계약의 「T089 전 사용자 결정」 문장을 닫는다 | decisions-controller.md:31–:67 |
| 86-18 | T086 밖 FR-029 항목(본문 5절 검증 · 하이라이트 · 1회 스캔 캐시 · JSON Schema export · 본문 산출 필드) → T090 TDD | 〔R1 2-2〕 |
| 86-19 | 교환 캐시 TTL 5분 → `min(expires_in, 300) − 30` s(270 s 경계) | tasks.md:241 · C13 |
| 86-20 | 「refresh 뒤 교환 캐시를 비운다」 → 그 세션 항목만 | bff-api.md:33 · tasks.md:247 |
| 86-21 | 「쿠키는 `/api/auth/*`에서만」 → 계약이 정한 자리에서만(프록시 회전 · inactive 삭제) | 〔B-8〕 · bff-api.md:48 |
| 86-22 | spec:100 · :106 · :328 「로그아웃 1 s · 2 s 뒤 같은 access 토큰 401」 → 이 기기 경로는 복사 쿠키 BFF 경유 2 s 401 · pod 즉시 거부 없음 · 교환 토큰 잔여 ≤ 330 s. (r2 — V-B-2) **202로 기록된 경우에만** — 기록되지 못한 갈래(503 · `invalid_grant` 503)와 시계 틈(≤ 60 s)은 §5-1-10 | 사용자 허용(decisions-controller.md:39–:42) |
| 86-23 | AC3 「`revoked:sub` 기록」 → 모든 기기(명시) 경로에만 | e2e/lib/bff.ts:59–60 |
| 86-24 | FR-024(spec:264) · spec:310 · plan:208 · (r2 — V-B-8) tasks.md:176(T062 「`revoked:sid:{sid}` 401」) · :180(T066 「`revoked:sid:{sid}`=1」) · :190(T073 「=1」) → 값 = nbf · 판정 값 > iat · 값 정규 꼴 밖 503. TTL 330 s 그대로 | UD-7a · D15 |
| 86-25 | (CD — T-c) 세션 단위 하한 키 `identity-admin:sid-floor:{sid}`(30 d · `/session/check`만) 추가 | D15-3 · t073-design.md:1303 |
| 86-26 | AC3 문면 밖 동작: ① 로그아웃이 그 브라우저의 Authentik 세션 종료(`x-end-session-url`) ② callback이 ID 토큰 `sid` 없이 세션을 만들지 않음 ③ (r2 — V-B-2) 204가 아닌 로그아웃 뒤 착지 안내(클라이언트 규약) | UD-7a · C23 · C24 |
| 86-27 | (UD-7c 결과에 따라) 웹훅 · 대조가 `web-bff-invalidation` 흐름 `logout` 이벤트를 사용자 단위로 기록하지 않음(identity-admin-api.md:59 · :65 예외) — 두 env 모두(r2 — V-B-3) | §0-2-3 |
| 86-28 | (r2 — T086-e) T090 문면 「remark(gfm·frontmatter·heading id·reading-time)」 → 읽기 시간 = 자체 함수(패키지 0) · 프런트매터 = `yaml`(gray-matter 금지) · 컴파일은 Node 생성 단계에서만 · 페이지는 산출물만 import | decisions-controller.md:112–:114 |
| 86-29 | (r2 — T086-e) D19 · FR-029 · ADR 0004 부록의 「MDX」 → 파일 확장자는 `.mdx` 그대로 · 문법은 Markdown + GFM(MDX ESM · 식 · JSX · 원시 HTML 0) · 위반 = 빌드 실패. ADR 0004 D19는 그대로(새 ADR 없음 — 컴포넌트 도입 때 새 ADR) | decisions-controller.md:109 · 〔CL syn §5〕 |
| 86-30 | (r2 — B-6) FR-023(spec:263) · spec:211(VD-2 임시 Cache Rule 조건) · tasks.md:247 「`jt_session`」 → `__Host-jt_session`(+ `__Host-jt_csrf` · `__Secure-jt_pkce`) | decisions-controller.md:122–:126 |

86-12 「문면보다 엄격」 목록: data-model §11 규칙(series 짝 · `change` 꼴 · `sources` path|url 하나 · 변형의 `pubDate` · `change` 같음) · study 파일 이름 규칙 · 모르는 키 거부 · 모아 던지기 · 정렬 · 검증 뒤 draft 거름 · `sources` 값 규칙(`url` http(s) · `path` 선행 `/` · `\` · `..` 금지) · root 또는 `study/` 부재 오류 · (r2 — T086-e) 본문 거부 규칙 넷(ld-13 · 모든 컬렉션) · 프런트매터 울타리 · YAML 엄격 · 엄격 UTF-8(ld-14).

## 2. 결정

### D1 범위 · 산출물

- **바꾸지 않는 것**: 모노레포만. gitops · 라이브 · 클러스터 · Vault · 자격 파일 · 공개 라이브 호스트 요청 0(빌더 · tester 포함). ⑤도 코드 · 시험 · 계약만(배포는 UD-1 뒤). `ci.yml` 0 · run-all 슬롯 0 · `pnpm-workspace.yaml` 0 · S-01 9파일 · `.claude/settings.json` 0.
- **산출물**
  - ⓪ 기반(컨트롤러): `packages/content/package.json`(`test` + devDependency vitest) · `apps/web/package.json`(새 — D2-3) · `pnpm-lock.yaml` importer 둘 · `.gitignore` `.next/`(build-notes.md:3)
  - T086: `packages/content/tests/loader.test.ts` · `tests/fixtures/<case>/{study,blog,projects}/*.mdx`(r2: 금지 구문 · 프런트매터 픽스처 포함 — D4)
  - T088: `apps/web/scripts/bundle-budget.test.mjs`
  - T089: `apps/web/src/lib/gateway.test.ts` · 도우미 `src/lib/__tests__/{fake-upstream,oracle-jwe,needles,cookies,headers,invariants}.ts`(수집되지 않음) · 자기 시험 `src/lib/__tests__/oracles.test.ts`
  - T087: 루트 `playwright.config.ts` · `e2e/hello.spec.ts` · `e2e/lib/{site,site-probe}.ts` · `e2e/lib/launch.mjs` · `e2e/selftest/{site,config-hygiene,static-gate,tracked-files,launch}.test.ts` · `e2e/selftest-browser/site-probe.test.ts` · `e2e/README.md` · `e2e/lib/bff.ts:59` 주석(r1) · (r2 — B-6) `e2e/lib/bff.ts:56–57` 쿠키 상수 · `e2e/selftest/bff.test.ts` 이름 기대값 · `e2e/revocation.spec.ts:158` 주석
  - ⑤(api-builder): D15-5 파일
  - 컨트롤러 문서(§4-1)
- **네트워크**: npm 레지스트리 메타데이터만(새 tarball 0 기대). ⑤는 기존 uv 환경 · Docker 이미지만.

### D2 시험 위치 · 실행 · 빨강 방법

1. **패키지별 vitest**: `scripts.test = "vitest run"` + `pnpm --filter <이름> --fail-if-no-match test`(T064 꼴). `--fail-if-no-match` 없으면 매치 0이 exit 0이다(ci.yml:623–:626 — r1 — 표식 보충 r2 — V-A-9). 설정 파일 0(기본 include · environment node · 루트 = 패키지). 타입 검사는 T091 · T093.
2. **루트 vitest 기각**: config-hygiene이 루트 devDependencies = `['@playwright/test']` · scripts 0을 고정(config-hygiene.test.ts:133–:137) · 루트 수집이 `e2e/**`를 집는다. events vitest를 `--root`로 빌리는 길도 기각.
3. **apps/web 최소 매니페스트(T086-b)** — `type` · next · react · tsconfig 0. T091이 더하기만 한다. `pnpm ls -r --depth -1`로 멤버 인식 확인(build-notes.md:8).

   ```json
   { "name": "@jt/web", "version": "0.0.0", "private": true,
     "description": "Next.js web app (US5) — test-first skeleton for T088 · T089; T091 scaffolds the app",
     "scripts": { "test": "vitest run" }, "devDependencies": { "vitest": "^5.0.5" } }
   ```
4. **빨강의 꼴**: T086 · T088 = 정적 import → 수집 실패 1(T060 · T064) + 공허 검사(D12). T089 = 사례마다 늦은 적재(`const loadGateway = once(() => import('./gateway'))` · `loadImageLoader`, 사례 첫 줄 · `expect` 밖 — 〔R2 ④ 결정 2〕). `oracles.test.ts`는 gateway를 적재하지 않아 처음부터 초록.
5. **T087** = Playwright `site` 프로젝트(D10). 빨강 서명 = 루프백 연결 거부 **그리고** `apps/web/next.config.ts` 부재. 스캐폴드 뒤 연결 거부는 `[env] site-server-not-running`. 공개 apex 대상 안은 기각.

### D3 vitest 판 · 설치 · lockfile(r1)

0. 컨트롤러가 돈다. env 가드: `HTTP(S)_PROXY` · `ALL_PROXY` · `NODE_OPTIONS` · `npm_config_registry`가 있으면 이름만 내고 멈춘다. registry = `https://registry.npmjs.org/`.
1. `apps/web/package.json`을 devDependencies 없이 먼저 → `pnpm ls -r --depth -1`.
2. 두 매니페스트에 `"vitest": "^5.0.5"`를 손으로 → `pnpm install --ignore-scripts`. 기대: 잠금의 `vitest@5.0.5(vite@8.3.5)` 재사용(pnpm-lock.yaml:28 · :693 · 추론 · VD-T086-1). 어긋나면 되돌리고 `pnpm add -D --ignore-scripts vitest@5.0.5 --filter @jt/content --filter @jt/web` → 저장 꼴을 `^5.0.5`로 → 재설치. 숙성 창(`minimumReleaseAge: 4320` — pnpm-workspace.yaml:10) 뒤 새 5.x가 들어올 수 있어 lock 검사가 관문이다.
3. `pnpm install --frozen-lockfile --ignore-scripts` 두 번(저장소 · 매니페스트와 lock만 복사한 빈 트리 — ci.yml:329 · :373 · :622 꼴).
4. lock 검사(렌즈 C): 차이 = importer `packages/content` + 새 importer `apps/web`뿐 · `packages:` · `snapshots:` 차이 0 · `tarball:` 0 · importer `@jt/*` specifier는 `link:` · `workspace:`만(지금 공허 — B-14). **조건이 깨지면 멈추고 여쭙는다**(T086-d).
5. `pnpm --filter @jt/events --fail-if-no-match test` 초록(ci.yml:595–:626 — r1 — 표식 보충 r2 — V-A-9).
6. `@types/node` · typescript · jose · zod · next · (r2) 로더 의존(D4)은 더하지 않는다 — T090 · T091 · T092 몫.

### D4 T086 — 로더 API · 파이프라인 · 거부 규칙 · 픽스처 · 사례(r2 — T086-e 전면 개정)

- **API**(시험 머리 주석이 정본 — T090은 이름 · 꼴 그대로 만족)

  ```
  // packages/content/src/index.ts (T090)
  getCollection(name: 'study'|'blog'|'projects',
                opts?: { lang?: 'ko'|'en'|'ja', includeDrafts?: boolean, root?: string }) => Promise<ContentItem[]>
  ContentItem = { collection, slug, lang, translations: string[] /* 같은 slug의 다른 lang · 정렬 */, data: Frontmatter,
                  readingTime: number /* 분 · 정수 ≥ 1 */, headings: { depth: 2|3, text: string, id: string }[] }
                  // (r2) 키 집합은 정확 단언하지 않는다 — 본문 산출 필드(html · hast 등)는 T090이 더한다(〔86-18〕)
  class ContentValidationError extends Error { name = 'ContentValidationError';
                  issues: { file: string /* root 상대 · '/' */, field: string, code: string, line?: number }[] }
                  // (r2) field 'body' · 'frontmatter' · 'file'이면 code = 규칙 이름(아래 표) · body는 line(파일 첫 줄 = 1) 필수
  ```

  - `root` = `study/` · `blog/` · `projects/`를 담는 디렉터리. 기본 = 저장소 `content/`(패키지 위치 기준 · cwd 무관) · env `JT_CONTENT_ROOT` 우선. root · `study/` 부재 = `ContentValidationError`(`(., root, missing)` · `(study/, collection, missing)`) — `[]`는 blog · projects 부재일 때만. 모르는 컬렉션 = `TypeError`.
  - `includeDrafts` 기본 = `process.env.NODE_ENV !== 'production'`. **모든 파일을 검증한 뒤 draft를 거른다.** 위반은 모아 하나로 던진다 — 메시지는 `<file>[:<line>]: <field> (<code>)` 줄들 · 값 0.
  - `lang` 미지정 = `ko` · 요청 로케일 변형이 없으면 ko 항목(`lang: 'ko'`) · `translations` = 같은 slug의 다른 lang(data-model.md:245) · 배지 판정 = `item.lang !== 요청 로케일`(T091).
  - 정렬: `pubDate` 내림차순, 같으면 slug 오름차순. 헤딩 id = github-slugger(rehype-slug — 한글 보존 · 공백 `-` · 중복 `-1` · VD-T086-4). `readingTime` 정확값은 고정하지 않는다.
- **파이프라인**(r2 — T086-e · 정본 decisions-controller.md:110–:114 · 구현 T090)
  1. 읽기: 엄격 UTF-8(`TextDecoder('utf-8', { fatal: true })`) — 실패 = `(file, file, encoding)`.
  2. 파싱: unified + remark-parse + remark-frontmatter(`yaml`만) + remark-gfm. **remark-mdx 0 · rehype-raw 0 · `allowDangerousHtml` 0.**
  3. 프런트매터: 첫 줄이 정확히 `---`(BOM · `---js` · `---yaml` · `+++` 아님)이고 닫는 `---`가 있어야 한다 — 아니면 `(file, frontmatter, fence)`. 값은 `yaml` 패키지로 읽는다(구문 오류 · 중복 키 · 모르는 태그 · 경고 = `(file, frontmatter, yaml)`). gray-matter 금지.
  4. 스키마: zod `.strict()`(아래). 위반 field = zod 경로를 `.`로 이은 것(`sources.0.url`) 또는 교차 규칙의 키.
  5. 거부 플러그인(remark 단계 · mdast): 위반마다 `file.message(…, node, 'jt-content:<rule>')` → 하나라도 있으면 `file.fail` — 빌드 실패 · 조용한 삭제 0. 한 파일의 위반은 문서 순서대로 **전부** 실린다.
  6. remark-rehype(기본값) → rehype-slug → 헤딩 수집(depth 2 · 3 — TOC · 또는 mdast-util-toc) → @shikijs/rehype(쓰는 언어만) → 출력(T090).
  7. 읽기 시간: 자체 함수(`Intl.Segmenter` — ko 어절 · ja 단어 · 또는 글자 수) · 패키지 0.
  8. 실행 자리: `getCollection`은 Node 생성 단계(T091 prebuild 스크립트)와 시험만 부른다. 페이지 · 레이아웃 모듈은 `packages/content`를 import하지 않고 산출물만 import한다. 프로덕션 산출물은 생성 단계에서 draft를 뺀다(VD-T086-6).
- **거부 규칙**(r2 — T086-e · 모든 컬렉션)

  | `code` | 잡는 것(mdast) | 까닭 |
  |---|---|---|
  | `raw-html` | `html` 노드 전부(흐름 · 글줄): `<script>` · `<iframe>` · `<Callout />` · `<br>` · `<!-- … -->` | remark-rehype 기본값은 html 노드를 **조용히** 버린다 — 실수가 숨는다 〔CL syn §3〕 |
  | `esm` | 문단 안 줄이 들여쓰기 0–3칸 뒤 `import` · `export` + 공백 · `{` · `*`로 시작 | MDX였다면 실행되는 ESM |
  | `expression` | `text` 노드의 `{` · `}`(인라인 코드 · 코드 블록 밖) | MDX 식의 자리 — 나중에 remark-mdx로 옮겨도 실행될 글자가 0이게 |
  | `unsafe-url` | `link` · `image` · `definition`의 `url`이 허용 밖. 허용 = 스킴 `http` · `https` · `mailto`(대소문자 무관)인 절대 URL · `#`로 시작 · 스킴 없는 상대 참조. 어디든 `\` · 공백 · 제어 문자가 있거나 `//`로 시작하면 위반. 자동 링크 `<javascript:…>` · 문자 참조로 만든 스킴은 해석 뒤 값으로 본다 | React 19는 `javascript:`만 막고 `data:`는 둔다 〔CL mdx ①5〕 |

- **스키마**(content.md:9–:25 + data-model.md:233–:245)
  - `title` · `description` 비지 않은 문자열 · `pubDate` · `updatedDate` 날짜(YAML 날짜 또는 `YYYY-MM-DD`) · `updatedDate ≥ pubDate` · `tags` 문자열 배열 · `series` · `seriesOrder` 함께(양의 정수) · `draft` 불리언(필수) · study `change` `^\d{3}-[a-z0-9-]+$` · `sources` 원소 = `{title, path}` 또는 `{title, url}` 정확히 하나 — `path` 저장소 상대(선행 `/` · `\` · `..` 0), `url` http(s)만(zod `httpUrl` 꼴 · `javascript:` · `data:` · `//host` 오류) · 모르는 키 오류.
  - study 파일 이름 `^\d{3}-[a-z0-9-]+(\.(en|ja))?\.mdx$`(어긋나는 `.mdx`는 오류 · `.mdx` 아닌 파일 무시) · 같은 slug 변형은 `pubDate` · `change` 같음 · ko 파일 필수.
- **픽스처**: `packages/content/tests/fixtures/<case>/{study,…}/*.mdx`(짧은 노트 · `content/`에 두지 않는다). (r2) BOM · 깨진 UTF-8 픽스처는 커밋하지 않고 실행 중 `mkdtemp` root에 만든다(eol · 편집기 영향 0).

| id | 사례 | 단언(값 출력 0 — 실패 메시지는 id · 파일 · 필드만) |
|---|---|---|
| ld-1 | 실제 노트(기본 root · `includeDrafts: true`) | slug ⊇ {`001-claude-setup`, `002-smoke`}(개수 단언 금지) · 각 `lang: 'ko'` · `translations: []` · `collection: 'study'` · `title` 비지 않음 · `pubDate` 2026-08-26 · 2026-08-27 · `change` = slug · `tags` ∋ `claude-code` · `readingTime` ≥ 1 · h2 5개 = content.md:28 순서 · id `문제` · `배운-개념` · `선택과-대안` · `결과와-검증` · `다음-학습` · 002가 001보다 앞. draft 값 단언 0. (r2) 두 노트가 거부 가드를 통과한다(002:30 코드 스팬 속 `{FEFF}` · 002:43 코드 스팬 속 `<!-- … -->` — VD-T086-3) |
| ld-2 | `pubDate` 누락 | 오류 · (그 파일, `pubDate`) |
| ld-3 | `<slug>.en.mdx` + ko | `lang:'en'` → `lang: 'en'` · `translations: ['ko']` / `lang:'ja'` → `lang: 'ko'` · `['en']` / `lang:'ko'` → `['en']` / ko만인 slug → 어느 로케일이든 `lang: 'ko'` · `[]` |
| ld-4 | en만 · ko 없음 | 오류 · 그 slug |
| ld-5 | draft | `includeDrafts: false` 제외 · `true` 포함 · 기본 + `vi.stubEnv('NODE_ENV','production')` 제외 · 기본(test) 포함(`vi.unstubAllEnvs()`) |
| ld-6 | draft인 위반 파일 | `includeDrafts: false`여도 오류 |
| ld-7 | `updatedDate < pubDate` | 오류 · `updatedDate` · 같은 날 통과 |
| ld-8 | 헤딩 | `## 같은 제목` ×2 · `### 하위` → `같은-제목` · `같은-제목-1` · depth 3 포함 |
| ld-9 | 읽기 시간 | 약 50단어 · ≥ 2,000단어 → 긴 것 > 짧은 것 · 정수 ≥ 1 |
| ld-10 | data-model 규칙 | 각각 오류(파일, 필드 정확): series만 · seriesOrder만 · `change: Bad_Change` · source path + url · 둘 다 없음 · 변형 `pubDate` 다름 · 변형 `change` 다름 · 모르는 키 `pubdate` · 번호 없는 파일 이름 · `url` `javascript:alert(1)` · `data:text/html,x` · `//host/x` · `path` `/x` · `a\b` · `../x` |
| ld-11 | 모아 던지기 | 위반 파일 2 → 오류 1 · 두 파일 |
| ld-12 | 컬렉션 | 없는 `blog/` → `[]` · 모르는 이름 → `TypeError` |
| ld-12b | root 부재 | `(., root, missing)` · `(study/, collection, missing)` |
| ld-13 | (r2 — T086-e) 본문 거부(파일마다 위반 하나 · 한 root에서 한 번 호출) | issues가 아래와 **정확히 같다**(`(file, 'body', code, line)` · 파일 이름순): `<script>x()</script>` → `raw-html` · `<iframe src="https://example.com"></iframe>` → `raw-html` · 문장 속 `<Callout />` → `raw-html` · `<!-- note -->` → `raw-html` · `import X from 'y'` 줄 → `esm` · `export const a = 1` 줄 → `esm` · 문장 속 `{1 + 1}` → `expression` · `[x](javascript:alert(1))` · `<javascript:alert(1)>` · `![x](data:text/html,x)` · `[r]: vbscript:x` + `[y][r]` · `[x](&#106;avascript:alert(1))` · `[x](//evil.invalid/x)` · `[x](/\evil.invalid)` → 각 `unsafe-url` · 한 파일에 `raw-html`(줄 a) + `unsafe-url`(줄 b) → 두 issue 문서 순 · **대조 파일은 issues에 없다**(코드 스팬 `` `<script>` `` · `` `{a}` `` · 펜스 코드 속 `import x from 'y'` · `{}` · `<div>` · `[a](https://example.com)` · `[b](mailto:a@example.com)` · `[c](./rel)` · `[d](#top)` · `[e](/ko)` · GFM 자동 링크 `https://example.com` · `&lt;b&gt;` · 표 · 각주) + 대조 파일만 둔 root는 항목을 돌려준다 |
| ld-14 | (r2 — T086-e) 프런트매터 · 인코딩 | `---js` 첫 줄 → `(file, frontmatter, fence)` · 중복 키 `title` → `(file, frontmatter, yaml)` · `title: !!js/function 'x'` → `(…, yaml)` · (실행 중 생성) BOM + `---` → `fence` · 깨진 UTF-8 바이트 → `(file, file, encoding)` |

### D5 T088 — `bundle-budget.mjs` API · 사례(r1)

- **API**(시험 머리 주석 정본 · T093 만족): ESM · Node 내장만. `LIMIT_BYTES = 2_621_440` · `MEASURED_EXTENSIONS = ['.js','.mjs','.wasm','.bin']`(research.md:2902 — `.map` 제외 · VD-T088-1) · `measureDir(dir) → { files, gzipBytes }`(재귀 · 정렬 · 링크 미추적 · 파일마다 `zlib.gzipSync(buf, { level: 9 })` 합) · `judge(gzipBytes, limit = LIMIT_BYTES) → boolean`(이하 통과) · `formatSummary(r)`.
- **CLI** `node bundle-budget.mjs --measure <dir> [--limit <bytes>]`: stdout 한 줄 `bundle-budget files=<n> gzip_bytes=<n> gzip_mib=<x.xx> limit_bytes=<n> result=pass|fail`(ASCII) · exit 0 / 1 / 2(인자 누락 · 디렉터리 없음 · 대상 0 · `--limit` 꼴 오류 — stderr `bundle-budget: error <code>`) · 인자 없음 = T093 빌드 경로(시험 밖) · import만으로는 돌지 않는다(`import.meta.main`).
- (r2) 한도 값은 tasks.md:240 문면 그대로다. 근거(ADR 0004:29 「Free 한도 3 MiB의 안전 마진」)는 Workers 압축 한도 폐지(2026-09-04)로 낡았다 — T091 전 사용자 질문(§5-3). 값이 바뀌면 새 ADR + bb-2 · bb-4 수치.
- **픽스처**: 커밋 0 · `mkdtempSync` · `crypto.randomBytes` · finally 삭제.

| id | 사례 | 단언 |
|---|---|---|
| bb-1 | `a.js` · `sub/b.mjs` · `c.wasm` · `d.bin` · `e.js.map` · `f.txt` | `files: 4` · `gzipBytes` = 독립 level 9 합 |
| bb-2 | 한도 | `=== 2.5 * 1024 * 1024 === 2_621_440` |
| bb-3 | 경계 | `judge(2_621_440)` 참 · `judge(2_621_441)` 거짓 |
| bb-4 | CLI 초과 | 2,700,000 B 무작위 `.bin` → exit 1 + `result=fail` · `gzip_bytes` = 독립값 · `limit_bytes=2621440` |
| bb-5 | CLI 통과 | exit 0 · `result=pass` · stderr 빈 값 |
| bb-6 | `--limit 100` | exit 1 · `limit_bytes=100` |
| bb-6b | CLI 경계 | 독립 합 S: `--limit S` → 0 · `S−1` → 1 |
| bb-7 | 사용 오류 | 디렉터리 없음 · `.map`만 · 값 없음 · `--limit abc` → exit 2 · stdout 0 · stderr 한 줄 |
| bb-8 | 출력 위생 | stdout 한 줄 · 인쇄 가능 ASCII |
| bb-9 | import 무실행 | 자식 `node --input-type=module -e "await import(<file URL>)"` → stdout 빈 값 · exit 0 |

### D6 T089 — gateway 표면

- 시험 머리 주석이 정본(T064 D2 꼴). route.ts(T092)는 env를 얻어 위임만 하는 어댑터(`getCloudflareContext`는 라우트에만).

  ```
  // apps/web/src/lib/gateway.ts (T092)
  createGateway(env: Readonly<Record<string, string | undefined>>, deps: GatewayDeps) => Gateway   // 던지지 않는다(C26)
  validateEnv(env) => readonly string[]   // 꼴이 틀리거나 없는 env 이름(정렬) — 값 0
  GatewayEnv  = { SESSION_ENCRYPTION_KEY, WEB_BFF_CLIENT_SECRET, CF_ACCESS_CLIENT_ID, CF_ACCESS_CLIENT_SECRET,   // Workers Secrets
                  IDENTITY_M2M_URL, AUTHENTIK_ISSUER, WEB_BFF_CLIENT_ID }                                         // vars(C1)
  GatewayDeps = { fetch(req: Request): Promise<Response>,   // 유일한 상류 통로
                  now(): number, randomBytes(n): Uint8Array /* PKCE · state · CSRF만 — IV는 JWE 층 */,
                  sample(): boolean, log(line: string): void }
  Gateway     = { login, callback, logout, refresh, session, health, proxy }  // (req: Request) => Promise<Response> · 어떤 상류 입력 · fetch 예외에도 reject 0
  export { createGateway, validateEnv, isSameOriginPath /* (decoded, origin) => boolean — C27 ① · ③의 디코딩 값 규칙 */,
           matchProxyRoute /* (rawUrl, method) => { pod, path } | null */, s256 /* (verifier) => Promise<string> */ }

  // apps/web/src/lib/image-loader.ts (T091)
  export default function imageLoader({ src, width, quality }): string
  export function fallbackSrc(url: string): string | null
  ```

- 캐시(교환 · 확인)는 인스턴스 안 — 시험마다 새 인스턴스. 응답은 표준 `Response`의 `Set-Cookie`(`cookies()` 0). 3 s = `AbortController` + `setTimeout`(`AbortSignal.timeout` 0 — 〔R3 ① 6〕). JWE IV는 주입하지 않는다(jose `setInitializationVector` 「Use only for testing」 — 〔B-7〕).
- (r2 — B-6) 쿠키 이름은 gateway 상수 · 시험 상수가 따로 있고 같아야 한다(`__Host-jt_session` · `__Host-jt_csrf` · `__Secure-jt_pkce`).

### D7 T089 — 계약 공백을 닫는 결정(bff-api.md 「T089 보정」)

| # | 공백 | 결정 | 근거 |
|---|---|---|---|
| C1 | Authentik 설정 | vars `AUTHENTIK_ISSUER`(끝 `/` — prod `…/application/o/web-bff/` · preview · 로컬 `…/web-bff-dev/`) · `WEB_BFF_CLIENT_ID`. 엔드포인트 = issuer origin + `/application/o/{authorize,token,revoke}/`(추론 · VD-T089-4) · end-session = issuer + `end-session/` · `redirect_uri` = 요청 origin + `/api/auth/callback` | bff-api.md:14 · 〔R3 2-4〕 |
| C2 | 키 | `SESSION_ENCRYPTION_KEY` = 16진 64자 → 32바이트, 아니면 설정 무효 · 생성 `openssl rand -hex 32`(T084) | data-model.md:177 |
| C3 | JWE | 「C3 세부」 | bff-api.md:21 · tasks.md:247 |
| C4 | 임시 쿠키 | 「C4 세부」 | bff-api.md:30 |
| C5 | 쿠키 없음 · 무효 | 401 `session_revoked`. 무효(복호 실패 · 모르는 접두 · `typ` · 키 집합 다름 · 필수 `sid` 없음 · (r2 — B-6) 같은 이름 둘 이상) = 두 쿠키 삭제. 없음 = `Set-Cookie` 0. (r2 — B-6) **접두 없는 옛 이름 `jt_session` · `jt_csrf`는 읽지 않는다**(없는 것과 같다). 상류 0 | bff-api.md:90 |
| C6 | CSRF · 판정 순서 | `__Host-jt_csrf` = 16진 32자 · 불일치 · 없음 → 403 `csrf_mismatch`(상류 0 · `Set-Cookie` 0). 순서(r2 — V-A-4 · V-B-10): **proxy** 맵 · 메서드 · 경로(404 — env 없이) → 설정(503) → 세션 쿠키(401) → 폐기 확인 → refresh · 교환 → 하류 / **session · refresh** 설정(503) → 세션 쿠키(401) → CSRF(refresh 403) → 폐기 확인 → … / **logout** 세션 쿠키 없음(401 · 헤더) → CSRF(403) → 본문(400 — C25) → 설정 무효(두 쿠키 삭제 + 503 — C26) → 쿠키 무효(삭제 + 401 — C5) → 폐기 확인 → C22 / **login · callback · health** 설정(503) → 각자 규칙 | bff-api.md:22 · :36 · :48 |
| C7 | client 인증 | `client_secret_post` · Authentik 호출 헤더 = 정확히 {`accept`, `content-type`} | 〔R3 3-1.5〕 |
| C8 | 하류 헤더 | 「C8 세부」 | bff-api.md:44 |
| C9 | traceparent | 요청마다 새 trace-id(16 B · 0 아님) · span-id(8 B) · sampled = `sample()` ? `01` : `00`(기본 10%) · 로그 `trace_id` = trace-id | spec:280 |
| C10 | 회전 뒤 응답 | 「C10 세부」 | bff-api.md:33 |
| C11 | 교환 오류 | 400 · 403 → 401 `exchange_denied`(삭제 0 · C10) · 401 · 그 밖 4xx · 3xx · 5xx · 시간 초과 → 503 | bff-api.md:46 |
| C12 | refresh 라우트 오류 | 400 `invalid_grant` → 두 쿠키 삭제 + 401 · 그 밖 → 503(쿠키 유지) · `refresh_token` 없으면 옛 값 유지. 프록시 내부 refresh `invalid_grant` = T092(권고 503 · 쿠키 유지) · logout 내부 refresh = C22 | bff-api.md:33 · :50 |
| C13 | 교환 캐시 | 키 `sub\|aud\|issued_at` · 유효 = 저장 + `min(expires_in, 300) − 30` s · `expires_in` 없음 · 꼴 오류면 캐시 0 · refresh 라우트 · logout은 그 세션(`sub` + `issued_at`) 항목(모든 aud)을 지운다 | bff-api.md:24 · :59 |
| C14 | 3 s 범위 | 헤더 + 본문 읽기까지 · 호출마다 · 재시도 0 | bff-api.md:56–:57 |
| C15 | 로그 | 「C15 세부」 | bff-api.md:95–:96 |
| C16 | 응답 공통 | 모든 BFF 응답에 `cache-control: no-store` · `x-request-id`(`crypto.randomUUID()`) · `x-content-type-options: nosniff` · ACAO 0 · 헤더 이름 집합 라우트 × 결과 정확(D9-4) · problem = `{type, title, status, detail?, instance, request_id}` 키 정확 · `type` = `https://joshuatech.dev/problems/<slug _→->` · `instance` = 라우트 경로 · `detail` 고정 문구 | bff-api.md:3 · :87 · :90 |
| C17 | `/api/health` 본문 | `{status, upstream:'identity-admin', upstream_ms, checks}` · `status` = 상류(`ok` · `degraded`, 그 밖 503) · `checks`는 이름 `^[a-z][a-z0-9_]{0,31}$` · 값 `{status, latency_ms}`만 | identity-admin-api.md:56 |
| C18 | `/api/session` 본문 | `{sub, tenant_id, email, name, exp}` · `email` · `name` 쿠키 값(없으면 `null`) · `exp = issued_at + 2592000` · 토큰 호출 0 | bff-api.md:34 |
| C19 | ID 토큰 | 「C19 세부」 | OIDC Core 3.1.3.7(추론) |
| C20 | 프록시 정확 일치 | 「C20 세부」 | bff-api.md:36 · web.md:22 · :24 |
| C21 | 이미지 로더 | 「C21 세부」 | FR-030 |
| C22 | logout 매핑 · 갈래 | 「C22 세부」(r2 — V-B-1) | UD-7 · bff-api.md:32 |
| C23 | Authentik 세션 종료 | 「C23 세부」(r2 — V-B-10 · V-A-4 · V-B-2) | UD-7a · §0-2-1 |
| C24 | `sid` 필수(CD) | callback C19에 `sid` 필수(출력 가능 ASCII 1–255자 — identity_api.py:107–:108). 없거나 꼴 밖 → 503 · 세션 쿠키 0 · `__Secure-jt_pkce` 삭제. 쿠키에 `sid`가 없으면 무효(C5). ID 토큰에 `sid`가 없으면 UD-7 재질문(VD-T089-4). (r2 — V-B-13) 모든 `/session/check` 질의에 원문 `sid`가 실려 UD-10 노출 면이 는다(§5-1-21) | bff-api.md:32 |
| C25 | logout 본문(CD) | 넷만: 없음(0바이트) · `{}` · `{"all_devices": false}` · `{"all_devices": true}`. 그 밖(JSON 아님 · 공백만 · 배열 · `null` · boolean 아님 · 모르는 키) → 400 `invalid_request` · 상류 0 · `Set-Cookie` 0 · 헤더 0. 까닭(추론 — r2 — V-A-9: r1의 〔U syn:78–:86〕 인용은 맥락이 반대라 뺐다): 모호한 범위를 이 기기로 접으면 「모든 기기」를 뜻한 결함이 조용히 좁아지고, 모든 기기로 접으면 조용히 넓어진다 | 추론 |
| C26 | 설정 유효성 | 「C26 세부」(r2 — V-A-4) | 〔A-2〕 · bff-api.md:3 · :36 |
| C27 | `return_to` | 「C27 세부」(r2 — V-A-5 · V-B-7) | 〔B-3〕 Node v24.11.1 실측 |
| C28 | 쿠키 속성 정확 | 「C28 세부」(r2 — B-6 · V-A-10). Max-Age는 계약 값 고정 | bff-api.md:21–:22 · :48 |
| C29 | callback 입장 판정 | 두지 않는다(identity-admin 호출 0 · 재인가 0 · `auth_time` 미사용) | UD-8 |

**C3 세부 — JWE**: 쿠키 값 = `v1.` + compact `<보호 헤더>..<iv>.<암호문>.<태그>` · 보호 헤더 정확히 `{alg:"dir", enc:"A256GCM", typ}`(`typ` ∈ {`jt-session`, `jt-pkce`} · AAD가 묶는다) · 복호 허용 = `dir` · `A256GCM`만 · IV는 봉인마다 JWE 층이 새로(12 B). `__Host-jt_session` 평문: 필수 `refresh_token` · `sub` · `sid` · `tenant_id`(uuid) · `issued_at`(정수), 선택 `email` · `name`(ID 토큰에 있을 때만).

**C4 세부 — 임시 쿠키**(r2 — B-6): `__Secure-jt_pkce` = 속성 C28 · 봉인(`typ` `jt-pkce`) `{state, verifier, return_to, created_at}` · callback은 성공 · 실패 모두 지운다(같은 Path) · `created_at + 300 s` 초과 = `invalid_state` · 여러 탭 로그인은 마지막만 유효(받아들인다).

**C8 세부 — 하류 헤더 정확 집합**

| 상류 | 헤더 |
|---|---|
| Authentik | {`accept`, `content-type`} |
| `/session/check` | {`accept`, `cf-access-client-id`, `cf-access-client-secret`, `x-request-id`, `traceparent`, `x-forwarded-user-sub`} — Bearer 0 |
| 프록시 GET | 위 + `authorization: Bearer <교환 토큰>` |
| `/sessions/revoke` | 프록시 + `content-type: application/json` |
| `/health` | {`accept`, `cf-access-client-id`, `cf-access-client-secret`, `x-request-id`, `traceparent`} |

- 클라이언트 요청 헤더는 옮기지 않는다(`cookie` · `authorization` · `cf-access-*` · `traceparent` · `tracestate` · `x-request-id` · `x-forwarded-user-sub`). end-session은 상류 호출이 아니라 브라우저 이동이다.

**C10 세부 — 회전 뒤 응답**: 내부 refresh가 성공한 요청의 응답(2xx · 4xx · 503 — 삭제 갈래 제외)에 새 `__Host-jt_session`(새 refresh · `issued_at` 그대로 · 새 IV)과 같은 값의 `__Host-jt_csrf`(Max-Age 갱신). 「쿠키 유지」 단언 = 삭제 0 + 회전이 있었으면 새 쿠키 있음. 프록시가 `/api/auth/*` 밖에서 `Set-Cookie`를 낸다 → 〔86-21〕.

**C15 세부 — 로그**: 요청마다 정확히 한 줄 · 키 9개 정확(`ts` · `level` · `request_id` · `route` · `status` · `upstream` · `upstream_ms` · `exchange_result` · `trace_id`) · `level` ≥ 500 `error` · 4xx `warn` · 그 밖 `info` · `route` = 라우트 템플릿 7개 중 하나 · `upstream` ∈ {`identity-admin`, `authentik`, `null`} · `upstream_ms` = 마지막 상류 정수 ms 또는 `null` · `exchange_result` ∈ {`cache_hit`, `exchanged`, `denied`, `error`, `null`} · `sub` 0 · `console.*` 0 · `x-end-session-url` 값 0.

**C19 세부 — ID 토큰 클레임**: `iss` = `AUTHENTIK_ISSUER` · `aud` ∋ `WEB_BFF_CLIENT_ID` · `exp` > now · `iat` 정수 → `issued_at` · `sub` · `sid` 출력 가능 ASCII 1–255자(필수) · `tenant_id` uuid. 어긋나면 503 · 세션 쿠키 0.

**C20 세부 — 프록시 정확 일치**: 원문 pathname이 `/api/proxy/identity-admin` + 상수(`/tenants/me` · `/session/check`)와 글자 그대로 같아야 한다(퍼센트 인코딩 하나라도 있으면 404 — 계약보다 엄격). 맵은 `Map` · `Object.hasOwn`. GET만(HEAD · OPTIONS 포함 그 밖 404 · 상류 0). `/tenants/me`는 질의를 버리고 `/session/check`는 세션 값(`sub` · `iat` = `issued_at` · `sid`)으로 다시 만든다. nosniff(C16).

**C21 세부 — 이미지 로더**: `https://cdn.joshuatech.dev/<path>` → `…/cdn-cgi/image/width=<w>,quality=<q ?? 75>,format=auto,onerror=redirect/<path>` · 루트 상대 경로는 그대로 · 그 밖 호스트 오류 · `fallbackSrc(변환 URL)` = 원본 · 변환 URL이 아니면 `null`.

**C22 세부 — logout 매핑 · 갈래**(r1 — UD-7 · r2 — V-B-1)
- 본문 → 범위: §0-1 표. 이 기기 요청은 어떤 실패에서도 `all_devices: true`로 바꿔 보내지 않는다.
- **active**: 폐기 확인 → (교환 캐시가 비면) refresh → 교환 → `/sessions/revoke`(본문 정확) → RFC 7009(회전이 있었으면 새 refresh) → 캐시 지움 → 두 쿠키 삭제 → 204.
- **inactive**: `/sessions/revoke` · refresh · 교환 0 · RFC 7009 1(실패해도 진행) → 삭제 → 이 기기 3꼴 204 · 명시 true 401 `session_revoked`.
- **확인 503 · 판정 아님**: RFC 7009만 → 삭제 → 503.
- **내부 refresh `invalid_grant`**(r2 — V-B-1): `/sessions/revoke` 0 · 교환 0 · RFC 7009 시도(옛 refresh) → 삭제 → **503 `upstream_unavailable`**(두 범위 모두). 까닭: `invalid_grant`의 대표 원인은 다른 isolate의 회전이다 — 그 세션은 살아 있고 기록도 없다(§5-1-14). 204면 조용한 실패가 된다. VD-T089-12가 「재사용 감지 = 토큰 가족 폐기」를 보이면 컨트롤러가 204 복귀를 정한다(남는 창 ≤ 교환 캐시 270 s — 기록).
- **실패 갈래**(RFC 7009 시도 → 삭제 → 503): `/sessions/revoke` 시간 초과 · 3xx · 2xx 아님 / 교환 거부 · 실패(시간 초과 · 302 포함 — r2 — V-B-4) / 내부 refresh 5xx · 3xx · 시간 초과 / 토큰 응답 200 + 깨진 본문(G17).
- **RFC 7009 실패**(active · 202 뒤): 삭제 → 503.
- **캐시**: 쿠키를 지우는 응답 직전에 그 isolate의 확인 캐시(그 세션 키)와 교환 캐시(`sub` + `issued_at` 모든 aud)를 지운다. 다른 isolate는 2 s까지 남는다(〔86-22〕).
- 헤더 규칙은 C23.

**C23 세부 — `x-end-session-url`**(r1 — UD-7a(ㄱ) · r2 — V-B-10 · V-A-4)
- **붙는 응답**: logout 라우트의 ① 세션 쿠키 없는 401(r2 — V-B-10: 앞선 inactive · 만료로 BFF 쿠키만 사라진 브라우저도 Authentik 세션을 끝내게 — 값은 공개 설정이라 비용 0) ② 두 쿠키 삭제 `Set-Cookie`를 싣는 응답 전부(204 · 401 · 503 — 설정 무효의 삭제 503 포함). **단 종료 설정(`AUTHENTIK_ISSUER` · `WEB_BFF_CLIENT_ID`)이 둘 다 유효할 때만.**
- **안 붙는 응답**: CSRF 403 · 본문 400 · 종료 설정이 무효인 모든 응답 · 다른 라우트 전부.
- **값**: `new URL('end-session/', AUTHENTIK_ISSUER)` + 질의 정확히 `client_id` · `post_logout_redirect_uri`(= `new URL(request.url).origin + '/'`) · `id_token_hint` · `state` · `ui_locales` 0. 원천은 설정과 요청 URL origin뿐. `Location` 0.
- 클라이언트 규약은 §0-2-1(204가 아니면 착지 뒤 안내 — r2 — V-B-2).

**C26 세부 — 설정 유효성**(r1 — A-2 · r2 — V-A-4)
- `createGateway`는 던지지 않는다. `validateEnv`가 비어 있지 않으면 proxy는 맵 · 메서드 · 경로 판정(404)을 env 없이 먼저 하고, 맵을 지나면 503. login · callback · refresh · session · health → 503 · 상류 0 · `Set-Cookie` 0 · 로그 1줄(`upstream: null`).
- (r2 — V-A-4) **logout**: C6 순서대로 쿠키 없음(401 · 헤더는 C23 조건) → CSRF(403) → 본문(400) → **설정 무효면 두 쿠키 삭제 + 503**(상류 0 · 헤더는 종료 설정이 유효할 때만). 까닭: 설정이 무효인 동안 공용 기기에서 누른 로그아웃이 쿠키를 남기면, 설정을 고친 뒤 그 세션이 되살아난다(계약 :32 「쿠키는 하류 결과와 무관하게 지운다」의 취지). 쿠키 삭제 · CSRF 대조에는 비밀이 필요 없다.
- 검사: 키 64 hex · `CF_ACCESS_CLIENT_ID` `^[0-9a-f]{32}\.access$` · 비밀 셋 비지 않은 출력 가능 ASCII · `IDENTITY_M2M_URL` = https origin(경로 · 끝 `/` · 사용자 정보 · 질의 · 조각 0) · `AUTHENTIK_ISSUER` = https · 경로 끝 `/` · 사용자 정보 · 질의 · 조각 0 · `WEB_BFF_CLIENT_ID` 비지 않음.

**C27 세부 — `return_to`**(r1 — B-3 · r2 — V-A-5 · V-B-7 · CD 선택)
- ① 「같은 origin 경로」(bff-api.md:40)에 더한다: WHATWG 해석 pathname이 `//`로 시작하면 400(`/..//evil.com` · `/.//evil.com` · `/a/..//evil.com` · 질의 디코딩 뒤 `/%2e%2e//evil.com`).
- ② 디코딩한 값 2,048자 초과 → 400.
- ③ (r2) **한 번 디코딩한 값은 출력 가능 ASCII(`!`–`~`)만**: 디코딩 = `URLSearchParams` 의미(`+`는 공백 → 공백 규칙으로 400). 비ASCII(퍼센트 인코딩된 UTF-8 `/ko/%ED%95%9C` 포함) · 공백 · 제어 문자 · DEL → 400.
- ④ (r2) **깨진 퍼센트 인코딩 400**: `return_to` 원문(디코딩 전)에 `%` 뒤 16진 두 글자가 아닌 곳(`/%` · `%E0%A4%A` · `%G1`)이 있으면 400. `return_to`가 둘 이상이면 400. 없으면 기본 `/` · 빈 값 400.
- ⑤ (r2) **Location 꼴**: 302 `Location`과 `__Secure-jt_pkce`에 봉인하는 값 = `new URL(decoded, origin)`의 pathname + search + hash(WHATWG 직렬화 — 출력 가능 ASCII · 점 세그먼트 접힘). 헤더 ByteString 예외(reject)가 생길 수 없다.
- ⑥ (r2) **바이트 상한**: 봉인한 `__Secure-jt_pkce`의 `이름=값`이 4,096바이트를 넘으면 400(`"`는 직렬화에서 `%22` 3바이트 — 글자 상한만으로는 4 KB를 보장하지 못한다 · 브라우저가 버리면 callback이 `invalid_state`가 된다).
- callback 재검증은 코드 교환 **앞**(400 `invalid_return_to` · 토큰 호출 0 · `__Secure-jt_pkce` 삭제).

**C28 세부 — 쿠키 × 동작 속성 맵**(정확 · 대소문자 무관 · r2 — B-6 · V-A-10)

| 쿠키 | 설정 | 삭제 |
|---|---|---|
| `__Host-jt_session` | `HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=2592000` | 같은 속성 · **빈 값** · `Max-Age=0` |
| `__Host-jt_csrf` | `Secure; SameSite=Lax; Path=/; Max-Age=2592000`(HttpOnly 없음 — 이중 제출) | 같은 속성 · **빈 값** · `Max-Age=0` |
| `__Secure-jt_pkce` | `HttpOnly; Secure; SameSite=Lax; Path=/api/auth/callback; Max-Age=300` | 같은 속성(같은 Path) · 빈 값 · `Max-Age=0` |

- 모든 꼴에서 `Domain` · `Partitioned` · `Expires` 0(`__Host-` 조건이기도 하다). C10 회전 쿠키는 「설정」 꼴.

**T089 밖 — T092 TDD가 먼저 쓴다**: 라우트 인벤토리 정확히 7 · 프록시 모듈 7 메서드 같은 핸들러 · `dynamic='force-dynamic'` · 코드 교환 4xx · callback `error=` 질의 · isolate 안 single-flight refresh(VD-T092-1) · 프록시 내부 refresh `invalid_grant`(권고 503 · 쿠키 유지) · 어댑터 env 원천 · 설정 오류 이름 isolate 1회 로그(VD-T092-2) · Workers 런타임 `redirect: 'manual'` · `cache: 'no-store'` 실측.

### D8 T089 사례(`it('G5-3 …')` 꼴)

- **Response를 내는** G 사례 끝에서 `assertResponseHeaders(route, outcome, res)`를 부른다(r2 — V-A-10: G0 · G14 · G16의 `validateEnv` 사례는 Response가 없다).
- 파일 수준 `afterEach`가 나가는 호출 불변식을 본다(D9-2).
- 쿠키 이름은 시험 상수(`__Host-jt_session` · `__Host-jt_csrf` · `__Secure-jt_pkce`)로 정확 비교한다(r2 — B-6).

| 묶음 | 핵심 단언 |
|---|---|
| G0 적재 | `createGateway` · `validateEnv` · `imageLoader` 함수 |
| G1 login · PKCE | verifier 43자 · challenge = node:crypto 독립 계산(RFC 7636 부록 B 벡터) · `S256` · state 43자 · 호출마다 다름 · authorize = issuer origin + `/application/o/authorize/` · 질의 키 정확 7개 · scope ⊇ {`openid`, `offline_access`} · URL에 verifier 0 · `__Secure-jt_pkce` 속성 정확(C28) · 오라클 복호 = state · verifier · return_to · `__Host-jt_session` 0 · 상류 0 |
| G2 return_to | 「G2 세부」 |
| G3 callback | 「G3 세부」 |
| G4 JWE | 「G4 세부」 |
| G5 `/session/check` | URL = `IDENTITY_M2M_URL/session/check` · 질의 키 정확 {`sub`, `iat`(= `issued_at`), `sid`} · `no-store` · `manual` · C8 · 캐시 1999 ms 적중 · 2000 ms 재조회 · `issued_at` · `sid` · `sub`만 다름 → 별도 키 · 판정 아님(400 · 403 · 401 `text/html` · 302 · 500 · 503 problem · 시간 초과 · 깨진 JSON · `{}` · `{"active":"false"}`) → 503 · `Set-Cookie` 0 · refresh · 교환 0 · 캐시 0 |
| G6 inactive | `/api/session` · refresh · 프록시: RFC 7009(`token` = 쿠키 refresh · `token_type_hint=refresh_token`) → 두 쿠키 삭제(C28) → 401 `session-revoked`. revoke 500 · 시간 초과여도 같다. active `/api/session` = C18 · 토큰 호출 0 |
| G7 교환 | 본문 키 정확(token-exchange URN · `subject_token` = refresh 응답 access · access_token URN · `audience=identity-admin` · `client_id` · `client_secret`) · `actor_token` 0 · 순서 확인 → refresh → 교환 → pod · 2 s 안 둘째 요청 확인 0 · 교환 0 · `cache_hit` / 2.5 s 확인 1 · 교환 0 · TTL `expires_in` 3600: 269 s 적중 · 270 s 미스 / 120: 89 · 90 · `issued_at` 다름 · refresh 라우트 뒤 미스 · sub A · B 같은 `issued_at` → 교환 2회 · 자기 토큰 · B `exchanged` · 400 · 403 → 401 `exchange-denied`(삭제 0 · C10) · 401 · 500 · 302 · 시간 초과 → 503(C10) |
| G8 하류 헤더 | C8 정확 · 클라이언트 헤더에 바늘을 하나씩 · 섞어서: `cookie`(`CF_Authorization=<바늘>` + `__Host-jt_*` + (r2 — B-6) 옛 이름 `jt_session=<바늘>`) · `authorization` · `cf-access-client-id` · `cf-access-client-secret` · `cf-access-jwt-assertion` · `cf-access-token` · `traceparent` · `tracestate` · `x-request-id` · `x-forwarded-user-sub` → 하류 · 로그 · 응답 0 |
| G9 3 s | 상류 종류마다 2999 ms 미결 · 3000 ms 503 · 호출 1 · 헤더 뒤 본문 정지도 3000 ms 503 |
| G10 프록시 | 「G10 세부」 |
| G11 logout · refresh · CSRF | 「G11 세부」(r2 개정) |
| G12 상관 · 공통 | `x-request-id` 꼴 · 요청마다 다름 · 클라이언트 값과 다름 · 하류 = 응답 헤더 = problem = 로그 · `traceparent` 꼴 · sampled · 로그 `trace_id` · `no-store` · nosniff · ACAO 0 · `instance` 질의 0 · 적대 헤더(D9-2)가 어느 응답에도 0 |
| G13 로그 | 「G13 세부」 |
| G14 이미지 로더 | C21 정확 문자열 · `fallbackSrc(imageLoader(x)) === x.src` · 루트 상대 그대로 · 다른 호스트 throw · 변환 URL이 아니면 `null` |
| G15 health | 확인 · 쿠키 0 · GET `/health` · C8 · `manual` · 3 s · 200 JSON → C17 키 정확 · `checks` 정화 · 302 · 403 `text/html` · 500 · 200 `text/html` · 깨진 JSON · `status` 이상 → 503 · 상류 `set-cookie` 0 |
| G16 env | 「G16 세부」(r2 — V-A-4 · V-B-13) |
| G17 깨진 200 · reject 0 | 「G17 세부」(r2 — V-B-4) |

**G2 세부 — return_to**(r2 — V-A-5 · V-B-7)
- 허용(302 · `Location` 정확): `/` · `/ko` · `/ko/notes?x=1#y` · 질의 `%252F` → `/%2F/evil.com` · `/` + `a`×2,047(2,048자) · 없음 → `/` · `/` + `"`×500 → `/` + `%22`×500(직렬화 — C27 ⑤)
- 400 `invalid-return-to`(`__Secure-jt_pkce` 0 · 상류 0)
  - r0: `https://evil.com` · `//evil.com` · `/%5Cevil.com` · `/%09/evil.com` · `/%0D%0A` · 앞 공백 · 중간 공백 · `/%7F` · `javascript:alert(1)` · 빈 값
  - r1: `/..//evil.com` · `/.//evil.com` · `/a/..//evil.com` · `/ko/..//evil.com` · `/%2e%2e//evil.com` · `%00` · 2,049자
  - (r2) 비ASCII `/ko/%ED%95%9C` · 깨진 `/ko/%E0%A4%A` · `/%` · `/%G1` · `+` 든 `/ko+x` · `return_to` 둘 · `/` + `"`×2,047(바이트 상한 — C27 ⑥)
- 모든 302에 대해 reject 0 · `Location`은 출력 가능 ASCII · `new URL(Location, origin + '/api/auth/callback').origin === origin` · 해석 pathname이 `//`로 시작하지 않음.
- callback 재검증: 오라클이 `return_to: '//evil.com'` · `'/..//evil.com'` · (r2) `'/ko/한'`을 봉인한 `__Secure-jt_pkce` → 400 · 토큰 호출 0 · 삭제.

**G3 세부 — callback**: G3-1 state 불일치 · 없음 · 쿠키 없음 · 만료(`created_at` + 301 s) → 400 `invalid-state` · 토큰 0 · `__Secure-jt_pkce` 삭제(Path 정확) / G3-2 성공: 교환 본문 키 정확 6개 · C7 · `manual` · `__Host-jt_session` 평문 = C3(`sid` 있음 · `email` · `name`은 있을 때만 · `issued_at` = `iat`) · `__Host-jt_csrf` 32 hex · 속성 정확 · `__Secure-jt_pkce` 삭제 · 302 Location = 봉인 값 · identity-admin 호출 0 · 재인가 0 / G3-3 교환 시간 초과 · 302 · 500 → 503 · 세션 쿠키 0 · 삭제 / G3-4 C19 위반(`aud` · `iss` · 지난 `exp` · 정수 아닌 `iat` · uuid 아닌 `tenant_id` · `sub` 빈 값 · 공백 · 256자 · `sid` 없음 · 빈 값 · 공백 · 256자) → 503 · 쿠키 0.

**G4 세부 — JWE**: 오라클(Web Crypto AES-GCM · AAD = 보호 헤더 b64url ASCII)이 G3 쿠키를 복호 · `v1.` · 5조각 · 둘째 빈 값 · 헤더 정확 · 같은 평문 두 봉인의 IV(16자) · 암호문 다름 · 회전 쿠키 IV ≠ 이전. 무효로 보는 쿠키 → `/api/session` 401 · 두 쿠키 삭제: 암호문 · 태그 · iv · 헤더 변조 · 다른 키 · 접두 없음 · `v2.` · `A256KW` · `A128GCM` · `typ` `jt-pkce` · 키 집합 다름(`sid` 없음 포함) · (r2 — B-6) 같은 이름 `__Host-jt_session` 둘. (r2 — B-6) **옛 이름만**(`jt_session=<유효 JWE>` · `jt_csrf`) → 쿠키 없음과 같다(401 · `Set-Cookie` 0 · 상류 0). 쿠키 값에 평문 `refresh_token` · `sub` · `sid` 바늘 0 · 쿠키 헤더 길이 < 4096.

**G10 세부 — 프록시**: 맵 밖 pod(`portfolio-core` · `constructor` · `__proto__` · `hasOwnProperty` · `toString` · `IDENTITY-ADMIN` · `identity-admin.`) → 404 · 상류 0 / 경로 변형(`/tenants/me/` · `//me` · `/Tenants/me` · `;x=1` · `%6De` · `%2F` · `%2f` · `%5C` · `/tenants/%2E%2E/health` · `/tenants` · `/tenants/me/x` · `/session/check/` · `/health` · `/sessions/revoke` · 빈 경로) → 404 · 0 / 메서드 POST · PUT · PATCH · DELETE · HEAD · OPTIONS → 404 · 0 / `/tenants/me?x=1` → 상류 질의 0 · `/session/check?sub=other&iat=1&sid=evil` → 세션 값으로 / 중계: 200 JSON 그대로 · 401 · 404 problem 그대로(삭제 0) · 200 `text/html` · 204 · 302 · 404 `text/html` · 530 · 503 problem → 503 / 응답 헤더 = 정확히 {`content-type`, `x-request-id`, nosniff, `cache-control`} + C10 회전 쿠키 · 상류 적대 헤더 0.

**G11 세부 — logout · refresh · CSRF**(r1 전면 개정 · r2 — V-B-1 · V-B-4 · V-B-9 · V-B-10 · V-A-4)

| id | 사례 | 단언 |
|---|---|---|
| G11-1 | CSRF 없음 · 불일치 — **{logout, refresh} 각각**(r2 — V-B-9) | 403 `csrf-mismatch` · 상류 0 · `Set-Cookie` 0 · (logout) 헤더 0 |
| G11-2 | 세션 쿠키 없음 — {logout, refresh}(r2 — V-B-9) | 401 · 상류 0 · `Set-Cookie` 0 · (r2 — V-B-10) logout은 `x-end-session-url` **있음**(G11-12 값) · refresh는 헤더 0 |
| G11-3 | 무효 쿠키(C5) + 유효 CSRF · 본문(r2 — C6 순서) | 401 `session-revoked` · 두 쿠키 삭제 · 헤더 있음 · 상류 0 |
| G11-4 | 본문 꼴 위반(C25): JSON 아님 · 공백만 · `[]` · `null` · `{"all_devices":"true"}` · `{"all_devices":1}` · `{"all_devices":true,"x":1}` | 400 `invalid-request` · 상류 0 · `Set-Cookie` 0 · 헤더 0 |
| G11-5 | 이 기기(본문 없음 · `{}` · `{"all_devices":false}`) + active | 순서 확인 → refresh → 교환 → `/sessions/revoke` → RFC 7009 · 본문 정확 `{"all_devices":false,"reason":"logout","sid":<쿠키 sid>}` · RFC 7009 `token` = 새 refresh · 삭제 · 204 · 헤더 있음 |
| G11-6 | 모든 기기 + active | 본문 정확 `{"all_devices":true,"reason":"logout_all"}`(`sid` 0) · 204 · 헤더 있음 |
| G11-7 | inactive | `/sessions/revoke` · refresh · 교환 0 · RFC 7009 1 → 삭제 → 이 기기 204 · 모든 기기 401 · 헤더 있음 · RFC 7009가 500 · 시간 초과여도 같다 |
| G11-8 | 확인 503(G5 판정 아님 표) | RFC 7009만 → 삭제 → 503 · 헤더 있음 |
| G11-9 | `/sessions/revoke` 시간 초과 · 302 · 500 · 400 / 교환 400 · 403 · 500 · (r2 — V-B-4) 시간 초과 · 302 / 내부 refresh 500 · 302 · 시간 초과 | RFC 7009 시도 → 삭제 → 503 · 헤더 있음 · 이 기기 요청을 `all_devices: true`로 바꾼 호출 0 |
| G11-10 | RFC 7009 실패(active · 202 뒤) | 삭제 → 503 · 헤더 있음 |
| G11-11 | 내부 refresh `invalid_grant`(r2 — V-B-1) | `/sessions/revoke` 0 · 교환 0 · RFC 7009 시도 → 삭제 → **503**(이 기기 · 모든 기기 모두) · 헤더 있음 |
| G11-12 | 헤더 값(C23) | origin + pathname = issuer + `end-session/` · 질의 키 정확 {`client_id`, `post_logout_redirect_uri`} · 값 = env · 요청 origin + `/` · `id_token_hint` · `state` 0 · 요청 질의(`?post_logout_redirect_uri=https://evil.invalid/x` · `?return_to=//evil.invalid`) · 헤더(`origin` · `referer` · `x-forwarded-host` = `https://evil.invalid`)가 값에 0 · `Location` 0 |
| G11-13 | 로그아웃 뒤 같은 isolate | 1 s 안 같은 쿠키 사본 `/api/session` → 확인 1회 다시(캐시 미사용) → inactive → 401 · 교환 캐시 미사용 |
| G11-14 | refresh 성공 | 새 쿠키(새 refresh · 나머지 그대로 · 새 IV) · `__Host-jt_csrf` 같은 값 다시 · 그 세션 교환 캐시 비움 · 204 |
| G11-15 | refresh `invalid_grant` | 삭제 + 401 |
| G11-16 | refresh 5xx · 3xx · 시간 초과 | 503 · `Set-Cookie` 0 |
| G11-17 | refresh inactive | RFC 7009 → 삭제 → 401 · 재발급 0 |

**G13 세부 — 로그**: `console` 다섯 메서드 호출 0 · `log` 요청마다 1줄 JSON · C15 키 · 값 꼴 · 경로별 `exchange_result` · `upstream`. **바늘**(원문 · base64url · 퍼센트 인코딩)이 로그 · problem `detail` · 응답 본문 · 응답 헤더(BFF 자신의 `Set-Cookie`는 그 면에서 제외)에 0: 들어온 `__Host-jt_session` · `__Host-jt_csrf` · 옛 이름 `jt_*` · `authorization` · `cf-access-*` · `CF_Authorization` 값 · `code` · `state` · env 비밀 넷 · refresh(옛 · 새) · access · `id_token` · 교환 토큰 · 상류 `Set-Cookie` · `Location` · `x-request-id` 값 · BFF 자신의 `Set-Cookie` 값(로그 · 본문 면) · 원문 sub · sid(예외: `/api/session` 본문 `sub` · 중계 pod 본문). 질의에 바늘을 담은 URL을 메시지에 실은 fetch `TypeError`도 0.

**G16 세부 — env**(r1 — A-2 · B-4 · r2 — V-A-4 · V-B-13)
- `validateEnv`가 각 경우 그 이름 하나만(정렬 · 값 바늘 0): 키 62 · 66자 · 16진 아님 · `CF_ACCESS_CLIENT_ID` 꼴 · 비밀 빈 값 · `IDENTITY_M2M_URL` 경로 · 끝 `/` · `http:` · 사용자 정보 · 질의 · `AUTHENTIK_ISSUER` `http:` · 사용자 정보 · `?x` · `#x` · 끝 `/` 없음 · `WEB_BFF_CLIENT_ID` 빈 값. (r2 — V-B-13) 사용자 정보 든 URL은 실행 중 조립한다(`'https://' + fake('u') + ':' + fake('p') + '@…'` — 리터럴 0 · GitGuardian URI 자격 오탐 예방).
- `createGateway({}, deps)`는 던지지 않는다.
- 설정 무효 인스턴스 둘 — (a) 키만 무효(종료 설정 유효) (b) `AUTHENTIK_ISSUER` 무효
  - `proxy(GET /api/proxy/not-a-pod/x)` → 404 problem · `x-request-id` · nosniff · 상류 0 / `…/identity-admin/tenants/me` → 503 · 상류 0
  - login · callback · refresh · session · health → 503 · `Set-Cookie` 0 · 헤더 0 · 상류 0 · 로그 1
  - (r2 — V-A-4) logout: 쿠키 없음 → 401 · (a) 헤더 있음 (b) 0 / 쿠키 + CSRF 불일치 → 403 · 0 / 쿠키 + CSRF + 유효 본문 → **두 쿠키 삭제(C28) · 503** · (a) 헤더 있음 (b) 0 · 상류 0 · 로그 1

**G17 세부 — 꼴이 깨진 200 · reject 0**(r1 — B-5 · r2 — V-B-4: 라우트 × 토큰 호출)

| 라우트 | 토큰 호출 | 기대(200 + 깨진 본문 · 필드 꼴 오류 각각) |
|---|---|---|
| callback | 코드 교환 | 503 · 세션 쿠키 0 · `__Secure-jt_pkce` 삭제 |
| refresh | refresh | 503 · 쿠키 유지(삭제 0 · 회전 0) |
| proxy | 내부 refresh | 503 · 쿠키 유지(삭제 0 · 회전 0) |
| proxy | 교환 | 503 · C10(앞선 회전의 새 쿠키) |
| logout | 내부 refresh | 두 쿠키 삭제 · 503 · 헤더 있음 · `/sessions/revoke` 0 · 넓힌 호출 0 · RFC 7009 시도 |
| logout | 교환 | 두 쿠키 삭제 · 503 · 헤더 있음 · `/sessions/revoke` 0 · RFC 7009 시도(새 refresh) |

- 깨진 본문 = 앞에 토큰 바늘을 담은 `text/html` · 깨진 JSON / 필드 꼴 오류 = `access_token` 숫자 · `id_token` 두 조각 · base64url 아님 · `expires_in` 문자열.
- 모두 로그 1줄 · `console` 0 · 바늘 0.
- **불변식**: 모든 호출은 `call()`을 지난다 — reject면 그 사례 실패. 주입 `fetch`가 `TypeError`를 던지는 사례도 둔다(→ 503).

### D9 T089 시험 기반

1. **적재**: 늦은 적재 · G0. VD-T089-1로 수집 실패가 되면 image-loader 사례만 `image-loader.test.ts`로 가른다(〔86-9〕).
2. **가짜 상류**(`__tests__/fake-upstream.ts`): 기록형 라우터(`vi.fn` — `{method, url, headers, body, cache, redirect}` · 매번 새 `Response` · 정하지 않은 경로 = 시험 실패) · 모든 응답에 적대 헤더 기본(`set-cookie: CF_Authorization=<바늘>` · `location: https://evil.invalid/<바늘>` · `cf-ray` · `x-request-id: <바늘>` · ACAO `*`) · RFC 2606 origin(issuer `https://auth.example.test/application/o/web-bff-test/` · m2m `https://m2m.example.test` · 사이트 `https://site.example.test`) · 전역 `fetch`는 `vi.stubGlobal`로 「불리면 실패」(`afterEach` `vi.unstubAllGlobals()`) · 시간 초과 = `req.signal` abort에서만 거부 · 본문 정지 = 헤더 뒤 스트림 정지. **파일 수준 `afterEach` 불변식**(`invariants.ts`): 기록된 모든 상류 호출 ① `redirect === 'manual'` ② origin ∈ {issuer origin, `IDENTITY_M2M_URL`} ③ `/session/check` `no-store` ④ C8 집합.
3. **시계**: `vi.useFakeTimers({ toFake: ['setTimeout', 'clearTimeout'] })` + `advanceTimersByTimeAsync` · TTL은 주입 `now()` · `afterEach` `useRealTimers`.
4. **오라클**: JWE 봉인 · 복호를 Web Crypto로 따로(`oracle-jwe.ts` — jose 0) · 쿠키 파서 `getSetCookie()` → (이름, 값, 속성 맵)(`cookies.ts`) · `assertResponseHeaders`(`headers.ts`) — `set-cookie`는 계약 이름(`__Host-jt_session` · `__Host-jt_csrf` · `__Secure-jt_pkce`)만 · `location`은 login · callback 302 기대값과 같을 때만.

   | 라우트 · 결과 | 헤더 이름 집합(B = {`x-request-id`, `cache-control`, `x-content-type-options`}) |
   |---|---|
   | 본문 있는 응답(200 JSON · problem) | B + `content-type` |
   | 204 | B |
   | login 302 | B + `location` + `set-cookie`(`__Secure-jt_pkce`) |
   | login 400 | B + `content-type` |
   | callback 302 | B + `location` + `set-cookie`(세션 둘 · `__Secure-jt_pkce` 삭제) |
   | callback 400 · 503 | B + `content-type` + `set-cookie`(`__Secure-jt_pkce` 삭제) |
   | (r2) logout 쿠키 없음 401 | B + `content-type` (+ `x-end-session-url` — C23 조건) |
   | logout 삭제 응답(204 · 401 · 503 · 설정 무효 503) | B (+ `content-type`) + `set-cookie`(두 삭제) (+ `x-end-session-url` — C23 조건) |
   | logout 403 · 400 | B + `content-type` |
   | inactive · 무효 쿠키 401(session · refresh · proxy) | B + `content-type` + `set-cookie`(두 삭제) |
   | 회전이 있었던 프록시 · refresh | 위 + `set-cookie`(새 두 쿠키) |

5. **가짜 비밀**: 비밀성 값은 전부 실행 중 생성(`fake(label) = \`${label}-${randomUUID()}\`` · 키 `randomBytes(32)` · JWT 꼴 실행 중 조립 · 사용자 정보 URL 조립 — r2) · 비밀 이름 옆 문자열 리터럴 0 · 스냅숏 0 · 바늘 단언은 불리언 꼴 · 출처 decisions-controller.md:136(r1의 :86은 문서가 늘어 낡았다 — r2 — V-A-9). **로컬 gitleaks는 CI 꼴**: 커밋 뒤 · push 전 · `[extend] useDefault = true` · `gitleaks git --no-banner --redact -v --config <tmp>/gitleaks.toml --ignore-gitleaks-allow --log-opts="origin/003-platform-foundation..HEAD" .`(ci.yml:223 · :260 꼴) · 기대 0 · 새 시험 파일 `gitleaks:allow` 0(grep).
6. **자기 시험 `oracles.test.ts`**(처음부터 초록): O1 JWE 왕복 · compact 꼴 · AAD 변조 실패 · O2 `hasNeedle` 세 인코딩 양성 · 음성 · O3 기록형 라우터 · O4 매달린 상류 · 본문 정지 abort · O5 쿠키 파서(대소문자 · 여러 `Set-Cookie` · (r2) 접두 이름) · O6 `assertResponseHeaders` 양성 · 음성.

### D10 T087 — Playwright 기반 통합(T077 인계)

1. **루트 `playwright.config.ts`**: `JT_E2E_SITE === '1'`일 때만 프로젝트 `{ name: 'site', testMatch: 'hello.spec.ts', use: { baseURL }, metadata: { jtSiteMode } }`. live · needle과 배타(`[guard] site-conflict`). 대상 검증 `validateSiteTarget(BASE_URL, JT_E2E_SITE_MODE)`(e2e/lib/site.ts): local = `http://127.0.0.1:<port>` · `http://localhost:<port>`(origin만) · prod = 정확히 `https://joshuatech.dev` · 그 밖 `[guard] site-target-not-allowed`(값 0). preview는 Access 뒤라 자동 대상 밖(infra/cloudflare/access.tf:106–131). 최상위 `use.baseURL` 0 · 인자 없는 실행은 selftest 둘 · `webServer` 0.
2. **env**: `JT_E2E_SITE` · `BASE_URL` · `JT_E2E_SITE_MODE`. 스펙은 env를 읽지 않는다(`metadata` · `baseURL` 픽스처). globalSetup 가드는 셋을 막지 않는다(global-setup.ts:19–41).
3. **런처 `e2e/lib/launch.mjs`**: 모드 `site`(자식 env = 기본 허용 + 공통 + 셋 · 끝 줄 `site passed=… failed=… skipped=… allowed-skip=<0|1> child-exit=… root=…` · exit 0 = 자식 0 · failed 0 · skipped = allowed-skip · root 삭제 · allowed-skip = local이고 `INFO T087 health skipped mode=local` 줄이 있을 때 1 — launch.mjs:222–224) · `site-red`(루프백 빈 포트 · `^T087 reach FAIL \[gate\] site-absent until T091( — |$)` 계수 · 끝 줄 `… gate-site=<g>/<failed> …`) · `list`에 site 실행(런처 상수 `BASE_URL=http://127.0.0.1:9` · `local` — launch.mjs:541–561). Windows 전용 유지(기본 env `SystemRoot` · `PATH` · `USERPROFILE` · `LOCALAPPDATA` — launch.mjs:169–186 — r1 — 표식 보충 r2 — V-A-9) · Linux CI는 T093.
4. **static-gate 개정**(T086-c · B-10 · A-12 · r2 — V-B-6)
   - 이름 붙은 예외: `listener` 정규식(:47)에서 `request` 이벤트만 빼 규칙 `listener-request`(허용 `e2e/lib/site-probe.ts`)로 · `evaluate` 허용(:103)에 `site-probe.ts`.
   - 범위 규칙 `site-probe-import`: import 가능 = `e2e/hello.spec.ts` · `e2e/selftest-browser/site-probe.test.ts`뿐.
   - 어디서나 0: `allHeaders(` · `headerValue(` · (r2 — V-B-6) `headerValues(` · `headersArray(`(Request · Response의 쿠키 포함 보기 — `headerValue(` 글자 규칙에 걸리지 않는다) · `postData` · `.response(`. 지금 `e2e/**` 쓰임 0(V-B-6 실측). `headers()`는 허용.
   - 범위 규칙 `expect-args`: `e2e/*.spec.ts`의 `expect(` 인자 코드에 `headers` · `.body` · `cookies(` → 위반(`argumentCode` :124 재사용 · 지금 spec의 `expect(`는 auth.spec.ts:119 하나).
   - 양성 대조: PLANTED `listener`(:244 `page.on("request", f)`)를 `page.on("response", f)`로 · 새 규칙마다 PLANTED(`listener-request` · `site-probe-import` · `all-headers` · `header-value` · `header-values` · `headers-array` · `post-data` · `response-call` · `expect-args`) · :300 키 집합 = RULES id.
   - 스캔 필수 목록(:221–:227)에 새 파일 넷 · `site-probe.ts` 리스너 매개변수 이름 ≠ `request` · `url()` 읽기 0 · 출력은 `out.ts` · `emit-args`.
5. **`e2e/lib/site-probe.ts`**(반환 = 수 · 불리언): `probeTokenLayers(page)`(같은 origin CSSOM · `:root` · `refCount` · `sysCount` · `compCount` · `allResolve`(계산값 비지 않고 `var(` 0 — VD-T087-2) · `sysRefsRefOrSys` · `sysChainExists` · `compAvoidsRef` · `compChainExists`) · `refStableUnderDark(page)` · `startPrefetchCounter(page)`(`request` 이벤트의 `next-router-prefetch: 1`만 계수 · 보관 0 · `page.requests()` 0).
6. **`e2e/lib/site.ts`**(순수 · 호출은 `http.ts`): `validateSiteTarget` · `classifySiteReach` · `scaffoldPresent()` · `cookieNames`(RFC 6265 token만 · 아니면 `unparsable=<n>`) · `EDGE_COOKIE_NAMES`(`__cf_bm` · `_cfuvid` · `cf_clearance` · `__cflb` — VD-T087-4) · `ROOT_CASES` · `REQUEST_ID_RE` · `PROBLEM_NOT_FOUND` · `judgeHealth` · `BFF_PATHS` 재사용.
7. **selftest**: `selftest/site.test.ts`(표 시험 · 실행 중 생성 픽스처) · `selftest-browser/site-probe.test.ts`(127.0.0.1 흉내 서버 — 토큰 정상 · ref 빠짐 · comp → ref · comp 0 · dark ref 변경 · prefetch 3 → 3 · 11 → 11 · 헤더 없음 0 · 창 밖 미계수 · 반환 꼴 · `freshGet`이 `accept-language`를 싣지 않음 — VD-T087-1) · 기존 갱신(`config-hygiene` · `tracked-files` 새 파일 5 · `static-gate` · `launch.test`) · (r2 — B-6) `selftest/bff.test.ts`의 쿠키 이름 기대값(:93 · :234–:266)을 새 이름으로.
8. **README**: `site` 행 · 런처 두 모드 · env 셋 · 「CI site job(T093)도 업로드 0」 · `next dev`는 대상 밖 · (r2 — B-6) :61 쿠키 이름.

### D11 T087 `e2e/hello.spec.ts` 흐름(r1)

- 모든 시험은 `lib/test-base`의 `test`. 첫 단계 `reach`(`freshGet(<base>/ko)` · `pace()` ≥ 200 ms) — 예외는 h-7 local(reach 전 INFO + skip). 단계마다 `T087 <step> PASS|FAIL <근거>`(값 0).

| mode | 관찰 | 분류 |
|---|---|---|
| local | 연결 거부 + 스캐폴드 없음 | **`[gate] site-absent until T091`** |
| local | 연결 거부 + 스캐폴드 있음 | `[env] site-server-not-running` |
| 둘 다 | 그 밖 네트워크 오류 | `[env] network (<code>)` |
| 둘 다 | 200 `text/html` + `data-jt-app="web"` | PASS `site-v2` |
| local | 그 밖 응답 | `[product] reach-unexpected status=<n>` |
| prod | 52x · 5xx | `[env] origin status=<n>` |
| prod | 그 밖(T094 전 v1) | `[env] prod-site-not-v2` → T094 뒤 `[product]` |

| id | 흐름 · 단언 |
|---|---|
| h-1 | `freshGet` 세 로케일 → 200 · `text/html` · 표식 |
| h-2 | `navigate` 세 로케일 → `[data-note-slug]` ≥ 2 · 001 · 002 각 1 · 노트마다 `[data-note-title]` 1 · `time[datetime="<pubDate>"]` 1 · `[data-note-tag="claude-code"]` 1(count만) |
| h-3 | 세 로케일 + `/`(`accept-language: ko`) → `set-cookie` 0(local) · prod는 엣지 밖 0 + INFO · 탐색 뒤 `context.cookies()` 0 |
| h-4 | `freshGet('/', {headers, maxRedirects: 0})` → 302 · Location 해석 origin + pathname = 기대 · `set-cookie` 0 |
| h-5 | `/ja` 001 · 002 배지 각 1 · `[data-note-lang="ko"]` · `/ko` 배지 0 · `/en` INFO |
| h-6 | `probeTokenLayers` 전부 참 · 수 ≥ 1 · `refStableUnderDark` 참 |
| h-7 | local → reach 전 `emitInfo('T087 health skipped mode=local')` + skip / prod → `/api/health` 200 · JSON · `judgeHealth` · `x-request-id` · `set-cookie` 0 |
| h-8 | `/api/proxy/not-a-pod/x` → 404 problem · `type` not-found · `request_id` = 헤더 · nosniff · `set-cookie` 0 · 설정 없이도(C26) |
| h-9 | 카운터 → `/ko` → 30 s → n ≤ 10 · `INFO prefetch n` · 초과 `[product] prefetch-storm` · 하한 없음 |

h-4 사례: `ko` → `/ko` · `ko-KR,ko;q=0.9,en;q=0.8` → `/ko` · `en-US,en;q=0.9` → `/en` · `ja,en;q=0.5` → `/ja` · 헤더 없음 → `/ko` · `fr-FR,fr;q=0.9` → `/ko` · `fr, en;q=0.5, ja;q=0.8` → `/ja`. `/`는 Route Handler라 web.md:49와 모순이 없다 · T091은 302를 명시한다(`NextResponse.redirect` 기본 307 — 추론).

### D12 빈 PASS 함정 방지

- **모든 vitest 과제**(저장소 밖 사본 기본): ⓐ 던지는 스텁 → passed 0(오류 사례는 클래스 · 메시지 · issues를 본다) ⓑ 관대한 스텁 → passed 0(통과가 있으면 사유 기록 · 단언 보강 — 「바늘 0」은 줄 ≥ 1 먼저 · 「상류 0」은 상태와 함께 · 「헤더 0」은 상태 · `Set-Cookie`와 함께).

| 과제 | 막을 함정 |
|---|---|
| T086 | 개수 · draft 값 단언 0 · 오류는 (파일, 필드)로 · root 부재는 오류. (r2 — T086-e) ⓒ **가드 없는 스텁**(프런트매터 · 스키마는 맞게 하고 본문 가드 0 — 「`'mdxEsm'` 오타」 꼴 무동작 가드) → ld-13 금지 사례 passed 0 · ⓓ **과잉 가드 스텁**(코드 안 `<` · `{` · `import`까지 거부) → ld-13 대조 · ld-1 passed 0 |
| T088 | 「초과 → exit 1」은 요약 줄과 함께 · 빈 디렉터리 exit 2 · 변이 7(exit 뒤바꿈 · `.map` 포함 · 재귀 없음 · 빈 디렉터리 0 · 요약 없음 · `<`/`<=`(judge · CLI) · `--limit` 무시) 각각 ≥ 1 사례가 잡는다 |
| T089 | 적재는 `expect` 밖 · 부재 단언은 양성 상태 단언과 짝. 저장소 밖 **부분 참조 gateway**(G2 · G10 · G11-12 + 그 세 묶음 경로의 G13 사례만 — r2 — V-A-10)에서 그 묶음 통과. 누출 변이 7 각각 ≥ 1 사례가 잡는다: `detail`에 code · 로그에 base64url refresh · 상류 `Set-Cookie` 중계 · `return_to` `startsWith('//')`만 · 해석 pathname `//` 미검사 · `x-end-session-url`을 요청 질의 · `origin`에서 · (r2 — V-A-5) 디코딩 값 ASCII 검사 생략(비ASCII → reject 또는 302) |
| T087 | 부재 단언은 도달(h-1 표식) 뒤에만 의미 → h-7 local 말고는 reach 먼저 · 헤더 이름 양성 대조는 selftest-browser |

**T087 계약 스텁**: 저장소 밖 `node:http` 루프백(표식 · 노트 둘 + 표시 표식 · ja 배지 · 토큰 CSS · 같은 origin 프리페치 3 · `/` 302 · 프록시 404 problem) → `site passed=8 failed=0 skipped=1 allowed-skip=1` · exit 0. 변이 — 각각 그 시험만 FAIL: `/ko` Set-Cookie → h-3 · 프리페치 11 → h-9 · ref 제거 → h-6 · 302 → 307 → h-4 · `x-request-id` 제거 → h-8 · 002 제거 → h-2 · h-5 · 002 `time` 제거 · 001 태그 제거 → h-2 · `/ko` 배지 → h-5 · 표식 제거 → reach `[product]`(h-7 local 제외).

### D13 CI · run-all(r1)

- ci.yml 0 · 새 시험은 CI가 돌지 않는다(JS job은 events-test 하나 — ci.yml:595–626). 깨는 길 셋: lockfile 불일치(D3 frozen 두 번) · 비밀 꼴(D9-5 CI 꼴 gitleaks) · events-test 방어 경로(렌즈 C + `@jt/events` 초록).
- ⑤ 파드 시험은 CI pod job이 돈다(ci.yml:417 · :425 · :546) → push 전 로컬 초록이 관문. push 뒤 PR #2 CI 확인(push는 사용자 확인 뒤). `publish-pod.yml`은 `apps/identity-admin/**` 등에만(PR은 build-check · 발행은 main — UD-1).
- run-all 새 슬롯 0 · T087은 `e2e-selftest` 슬롯(run-all.ps1:89–97)이 덮는다.

### D14 빌드 조각 · 담당 · TDD · 커밋 · tick

| 조각 | 담당 | 파일 | 시험 · 확인 |
|---|---|---|---|
| ⓪ 기반 | 컨트롤러 | 두 매니페스트 · lock · `.gitignore` | D3 0–5 |
| ① T086 + T088 | web-builder(opus) A | `packages/content/tests/**` · `apps/web/scripts/bundle-budget.test.mjs` | 시험 → 빨강 → 인프라 초록 → 공허 검사 · 참조 구현 · 변이 · (r2) 가드 없는 · 과잉 가드 스텁 |
| ② T089 | web-builder(opus) B | `gateway.test.ts` · `__tests__/**` | 위 + passed 0 · 자기 시험 초록 · 부분 참조 + 변이 7 · VD-T089-1–3 |
| ③ T087 | web-builder(opus) C | `playwright.config.ts`(영역 밖 — 지시문에 범위 명시) · `e2e/hello.spec.ts` · `e2e/lib/{site,site-probe,launch}` · `bff.ts:59` 주석 · (r2 — B-6) `bff.ts:56–57` · `selftest/bff.test.ts` 이름 · `revocation.spec.ts:158` 주석 · selftest 5 · selftest-browser 1 · README | selftest 먼저 빨강 → lib → 초록 → `needle` → `list` → `site-red` → 계약 스텁 + 변이 |
| ④ 문서 | 컨트롤러 | §4-1 「지금」 · build-notes · 학습 로그 · tick | — |
| ⑤ UD-7a(ㄴ) | api-builder(opus) | D15-5 | D15-6 시험 먼저 → 빨강 → 구현 → 초록 · 하네스 · recopy diff |

- 병렬: ① · ② · ③ · ⑤ 동시(⓪ 뒤) · ⑤ Docker 스위트는 동시에 둘 0(t073-design.md:2094).
- 지시문 절(전체 파일 0 — specs.md)
  - ①: tasks.md :238 · :240 · :245 · :248 · AC2 · AC4 · FR-028 · FR-029 · Edge :209 · :221 · data-model §11 · content.md(§4-2 새 줄 포함) · (r2) decisions-controller.md:109–:116(T086-e) · 〔CL syn §3〕 거부 대상 문단 · research.md:2756–:2761 · :2891–:2907 · D2–D5 · D12 · D14
  - ②: tasks.md :241 · :246(image-loader) · :247 · bff-api.md 전체 + §4-2 초안 · identity-admin-api.md :56–:58 · FR-023 · FR-027 · FR-030 · Edge · VD-1 · §0 · D6–D9 · D12
  - ③: tasks.md :239 · AC1–AC3 · AC5 · FR-023 · FR-027 · FR-031 · Edge :210 · bff-api.md :3 · :35 · :36 · :62–:67 · :87 · :90 · web.md :17 · :35 · :48–:54 · t077-design.md D3 · D5 · D10 + 정정 노트 7 · D10–D12 · README · (r2) §0-7(B-6 이름)
  - ⑤: decisions-controller.md:51–:56 · :88 · :96 · denylist.md §키 스키마 · §조회 규약 1 · 2 · 6 · 7 · §쓰기 규약 · identity-admin-api.md :25 · :57 · :58 · :84 · data-model.md :54–:76 · django-pod.md §Auth · §Tests · §Dragonfly · D15 · §4-2 ⑤ 행
- 빌더 규칙: 커밋 0 · 공개 호스트 0 · 설치 0. 컨트롤러가 파일 이름으로 스테이징 · push는 사용자 확인 뒤.
- **리뷰 렌즈 넷**: A 정합 · 문면(문면 ↔ 사례 · 계약 ↔ D7 · 결정 ↔ G3 · G11 · 편차 · 진짜 실패인지) / B 노출 · 비밀(가짜 비밀 · 바늘 · static-gate 범위 · site-probe 반환 · 아티팩트 0 · `x-end-session-url` 원천 · (r2) 쿠키 이름 · 옛 이름 무시 · 거부 규칙 표) / C 하네스 · lock · CI(공허 검사 · 변이 · lock · frozen · events-test · 끝 줄 · gitleaks) / D 파드 · 계약(⑤ — `DenylistRecord` · 정규 꼴 판독 · `read_floor` 서명 · 템플릿 하네스 · 렌더본 diff · §4-2 ⑤ 전 줄(V-A-2 · V-B-8) · 전환 창)
- **커밋**(과제마다 하나 + 기반 — decisions-controller.md:137)
  1. 설계 문서(이 r2 확정본)
  2. ⓪ 기반(tick 0)
  3. T086(+ content.md 두 곳 + KR · 학습 로그 · tick)
  4. T088(tick)
  5. T089(+ bff-api.md T089 보정(B-6 이름 포함) · web.md + KR · quickstart.md:90 · t077 정정 노트 UD-7 항목 · tick)
  6. T087(+ e2e 규칙 · AGENTS 행 · codex-parity · web-builder.md · KR · (r2 — B-6) e2e 상수 · selftest · README · t077 정정 노트 B-6 항목 · tick)
  7. ⑤ `fix(003-platform-foundation): UD-7a(ㄴ) — …`(tick 0 · 같은 커밋에 §4-2 ⑤ 계약 · 규칙 전부 · build-notes 「UD-7a(ㄴ)」)
- **tick 조건**: §1-1 합격선을 모두 채우고 컨트롤러가 빨강을 한 번 더 관찰(T060) · 명령과 끝 줄을 build-notes에 그대로. T089는 렌즈 A가 G3 · G11을 결정과 대조한 뒤. 표와 다른 FAIL이면 tick 0 · 새 편차는 사용자 결정. 학습 로그 `content/tmp/003-t08{6,7,8,9}/<날짜>.md`(⑤는 T089 로그의 한 절).

### D15 UD-7a(ㄴ) 파드 조각 ⑤ — `revoked:sid` 시각화 · 세션 단위 하한(r1 · r2 — CD T-c · V-A-2 · V-A-6 · V-A-8 · V-B-2 · V-B-8)

1. **결정**(decisions-controller.md:51–:56 · :88): `revoked:sid:{sid}` 값 = nbf · `/session/check`는 `issued_at < nbf`만 inactive · pod 미들웨어도 값 > 토큰 iat · 수명 구조 T-c.
2. **값 · 비교 · 경계**
   - 값 = 그 `sid` 행의 nbf = `/sessions/revoke` 처리 시각 ⌊t⌋ + 1(identity_api.py:231). 같은 초 재로그인은 한 번 튕긴다(닫힌 쪽 — t073-design.md:1305). (ㄱ)이 있으면 재로그인 `sid`가 새 값이다(VD-T089-9).
   - 비교 = 값 > iat(같으면 통과) — 미들웨어(토큰 iat)와 `/session/check`(세션 시작 시각) 모두.
   - 시계 영역: `issued_at` = Authentik 시계 · nbf = identity-admin 시계. Authentik이 δ초 앞서면 로그아웃 δ초 안에 시작한 그 `sid`의 세션이 비켜 간다(열림). 미래 iat 규칙(`iat > now + 60 s` → inactive) 때문에 δ의 실효 상한은 60 s다(r2 — V-B-2). 뒤처지면 재로그인이 |δ|초 inactive(닫힘). VD-T081-5.
   - **값 판독**(r2 — V-A-6 · V-B-13 · CD): `revoked:sid` · `identity-admin:sid-floor:{sid}` 값은 정규 꼴(ASCII 숫자 1–19자 — session_floor.py:57 `FLOOR_VALUE_PATTERN` fullmatch)만 받고, 밖(`-5` · ` 5` · `+7` · `1_000` · `x` · 20자리 · 빈 값)이면 조회 실패(503 `denylist_unavailable`). 까닭: 존재 판정은 어떤 값이든 닫혀 있었지만, `int()` 값 비교는 손상 값을 조용히 「폐기 아님」(열린 쪽)으로 읽는다. `revoked:sub`의 `int()` 판독은 이 조각 밖이다(T062 계약 — 열린 항목).
3. **수명 · 구조 = T-c(CD 결정)**

   | 안 | 내용 | 막는 것 | 대가 |
   |---|---|---|---|
   | T-a | 값만 nbf | W35 | E13(RFC 7009 실패 시 330 s 뒤 복사 쿠키 부활 — t073-design.md:1303)이 기본 경로의 열림 |
   | T-b | `revoked:sid` 30일 | W35 · E13 | pod가 읽는 `revoked:*`에 30일 키 · spec :264 · :310 · plan :208 · ADR 0006:29 TTL 편차 |
   | **T-c(결정)** | `revoked:sid` = nbf · `min(330, …)` + `identity-admin:sid-floor:{sid}` = nbf · 그 행 `expires_at + 30 d`까지(`/session/check`만) | W35 · E13 | 새 키 한 종류 · 재적용 SQL 하나 · 하한 조회 = 파이프라인 1회 GET 2 · 시험 증가 |

   - 사용자 단위와 같은 구조(`revoked:sub` 330 s + `session-floor:{sub}` 30 d) · 자기 접두라 ACL · aclfile · gitops 변경 0(denylist.md:48 · :57) · spec · plan 「TTL 330 s」 문장은 그대로 참(편차 = 〔86-24〕 · 〔86-25〕).
   - **최종성 논증**(r2 — V-B-2: 범위를 「202로 기록된 경우」로 한정): `/sessions/revoke`가 202로 기록한 이 기기 로그아웃에서, 세션 단위 하한 n(그 `sid` 행 nbf 최댓값) · 세션 시작 s < n · 확인 시각 t라 하자. 하한은 n + 330 s + 30 d까지 산다 — 그 안이면 하한이, 뒤면 t − s > 30 d라 나이 조건이 막는다. 그래서 **기록된** 이 기기 로그아웃의 최종성은 RFC 7009 성공에 기대지 않는다. 남는 것: Dragonfly 유실 ~ 재적용 복귀 창(denylist.md:37) · 시계 틈(≤ 60 s — 2) · **기록되지 못한 로그아웃**(503 갈래 · `invalid_grant` 503 — §5-1-10). 사용자 단위도 「기록되지 못한 폐기」 · 「시계 틈」을 남는 열림으로 적었다(t073-design.md:1299 · :1300) — r1의 「사용자 단위와 같다」는 이 둘을 빠뜨렸다.
4. **쓰기 규칙**
   - 자기 행 값으로 쓰고 DB를 읽지 않는다. 두 SET을 한 파이프라인으로. `sid` 행 nbf 원천은 `/sessions/revoke`뿐(웹훅 · 대조 · 관리 명령은 `sid=None` — identity_api.py:319 · jobs.py:381 · revoke_sessions.py:84) → 과거 값이 큰 값을 덮을 길이 없다. 같은 `sid` 두 폐기의 커밋 역순 ms 창은 재적용이 되돌린다.
   - TTL: `revoked:sid` = `min(330, ⌊expires_at − 프로세스 시각⌋)` · 하한 = `⌊expires_at + 30 d − 프로세스 시각⌋` · 1 미만인 키는 보내지 않는다.
   - (r2 — V-A-8) **결과 뜻**: 두 키 가운데 하나라도 보냈으면 `ok`(`skipped`는 둘 다 1 미만일 때만 — 하한이 사는 30 d 동안은 사실상 `ok`) · `denylist.set_skipped`는 `skipped`일 때만.
   - 재적용 셋째 SQL: `sid IS NOT NULL AND expires_at > now() − 30 d`를 `DISTINCT ON (sid)` · nbf 최대로(30 d는 `session_floor.REVOCATION_LOG_RETENTION` 매개변수). 새 인덱스 0 — `srl_expires_at_idx` 범위 스캔 + 정렬(SP-1 규모 · data-model.md:77 그대로 · 규모가 커지면 부분 인덱스 `(sid, nbf DESC) WHERE sid IS NOT NULL` = 새 마이그레이션 — §5-1-15).
   - 반환 `rows`의 뜻(첫 SQL 활성 행 수)은 그대로 · `floors` = 두 하한 SET 수 합(필드 추가 0).
5. **바뀌는 파일 · 함수**
   - `packages/django-common/src/django_common/auth.py`: `DenylistRecord`(:656–:666) `sid_revoked: bool` → `sid_nbf: int | None` · `revokes(iat)` = `(sub_nbf > iat) or (sid_nbf > iat)`(None이면 거짓) · `Denylist._query`(:710–:719) `pipe.exists` → `pipe.get(revoked:sid:…)` + 정규 꼴 판독(밖이면 조회 실패) · 지표 `result=revoked` = 키 존재(:698) · 독스트링 :86–:97. 소비자: identity-admin(`session_floor.is_active` · 시험 도우미 test_identity_contract.py:237).
   - `apps/identity-admin/identity_admin/denylist_writer.py`: `apply_sid(sid, nbf, expires_at)`(:229–:235) 두 SET · 결과 뜻(4) · `reapply()`(:238–:282) `revoked:sid` 값 `"1"` → `str(nbf)`(:252) + 셋째 SQL · 독스트링 :22–:23 · :35.
   - `revocation.py:284`: `apply_sid(sid, nbf, expires_at)`.
   - `session_floor.py`: `SID_FLOOR_KEY_PREFIX = "identity-admin:sid-floor:"` · `read_floor(sub, sid=None) -> tuple[int | None, int | None]`(파이프라인 1회 · 두 키 같은 정규 꼴 · 같은 실패) · `is_active(*, record, floor, sid_floor, iat, now)` · 독스트링 :17–:26.
   - `identity_api.py:184–:197`: 두 하한을 넘긴다 · 응답 `nbf`는 `revoked:sub` 값 그대로 · 이음매(모듈 속성 호출 — :13–:16) 유지.
   - `templates/django-pod/template/tests/test_auth_middleware.py.jinja:366–:387` · 렌더본 `apps/identity-admin/tests/test_auth_middleware.py:370–`: 값 iat + 60 → 401 · = iat → 200 · (r2) 값 `-5` → 503. 템플릿 소유 — `copier recopy` 뒤 `git diff`로 렌더본 확인(django-pod.md 「regenerate and diff」).
   - 계약 · 규칙: §4-2 ⑤ 행 전부(같은 커밋).
6. **시험(먼저 쓰고 빨강 → 구현)**

   | 시험 | 바뀌는 단언 | 오늘 코드의 빨강 원인 |
   |---|---|---|
   | `auth-15`(test_auth.py:465–:474) | 값 iat + 60 → 401 · = iat → 200 · = iat − 60 → 200 · `sid` 없는 토큰 무관 | 존재 판정이라 `= iat`가 401 |
   | `ac-12a` 확장 · `ac-25`(새 — r2 — V-A-6) | `revoked:sid` 값 정규 꼴 밖(`x` · `-5` · ` 5` · `+7` · `1_000` · 20자리 · 빈 값) → 503 `denylist_unavailable` | 존재 판정이라 401 |
   | `ac-13`(:2050–:2113) | `DenylistRecord(sub_nbf, sid_nbf)` · 명령 통계 `get` 2 · `exists` 0 · `revokes` 진리표 | 필드 없음 |
   | `ac-13b`(:2116–:2128) | sub iat − 60 + sid iat + 60 → 401 / sid iat − 60(재로그인 — W35) → 200 | 존재 판정 |
   | `ac-13c` · `ac-14` | 기록 꼴 · 지표 표본의 sid 값을 시각으로 | 필드 없음 |
   | 템플릿 · 렌더본 `test_revoked_subject_and_session_are_401` | auth-15 쌍 + 정규 꼴 밖 503 | `= iat`가 401 |
   | `api-7`(test_api.py:1261–:1271) | sid = iat + 1 → `{"active": false}` · = iat · = iat − 100 → active · sid 질의 없음 · 다른 sid → active | 존재 판정 |
   | `api-12` · `api-13` · 관리자 (b)(:1359–:1396 · :1477–:1494) | `revoked:sid:*` = `str(nbf)` · TTL ∈ [325, 330] · `identity-admin:sid-floor:*` = nbf · TTL ∈ [30 d + 320, 30 d + 330] | 값 `"1"` · 하한 없음 |
   | 재적용(test_api.py:1766–:1784) | `revoked:sid` 값 = nbf · 하한 복원 · sid별 최댓값 · TTL 비증가 | 값 `"1"` |
   | (r2 — V-A-8) `ia-9`(test_identity_jobs.py:501–:524 · :515) | sid 값 = `base − 20`(이전 `b"1"`) · `floors` 1 → 2 · 독스트링 「sid 행은 하한이 없다」 정정 | 값 · 하한 없음 |
   | (r2 — V-A-8) `ia-10`(:528–:551 · :544) | `rows` 뜻 유지 확인 · `skipped` 1 = `revoked:sid` · 세션 단위 하한은 쓰인다 | 하한 없음 |
   | `ia-25`(test_identity_contract.py:1345) | 한계 고정 사례의 sid 값을 시각으로 | 값 꼴 |
   | (r2 — V-A-8) `ia-28` (a)(:1414–:1435) | `sid` 폐기 → `revoked:sid` + `identity-admin:sid-floor` · `session-floor:{sub}` · `revoked:sub` 0 | 하한 없음 |
   | (r2 — V-A-8) `ia-28` ②(:1468–:1483) | 만료된 sid 행(nbf = 지금 − 400) → `revoked:sid` 0 · 세션 단위 하한 = nbf · 결과 `ok`(이전 `skipped`) · `set_skipped` 0줄 | 결과 · 하한 |
   | (r2 — V-A-8) `ia-30`(:1642–:1656) | `read_floor` 가로채기 · fake가 새 서명(`(sub, sid)` → 튜플)을 따른다 · 이음매 유지 | 서명 |
   | `ia-42`(새 — W35) | 이 기기 폐기(nbf n) 뒤 `iat=n−5&sid=S` → inactive · `iat=n` · `n+3` → active | 존재 판정 |
   | `ia-43`(새 — E13) | `revoked:sid` DEL 뒤에도 하한만으로 `iat < n` inactive · `≥ n` active | 하한 없음 |
   | `ia-44`(새) | 하한 값 정규 꼴 밖(`-5` · `x` · 20자리) → 503 · 첫 조회 실패면 하한 조회 0 | 하한 없음 |
   | `ia-45`(새) | purge 경계(`expires_at + 30 d`) = 하한 수명 끝 · 하한 TTL < 1 건너뜀 | 하한 없음 |

   - 명령: `uv run --directory packages/django-common --locked pytest -q` · identity-admin 스위트(build-notes 「T073」) · `uv run --directory templates/django-pod --locked pytest -q` · `copier recopy` diff.
7. **커밋 · 기록**: 커밋 7에 계약 · 규칙 전부(계약 초안 → 시험 → 구현 차례, 커밋 하나) · build-notes 「UD-7a(ㄴ)」(빨강 · 초록 · 하네스 끝 줄 · recopy diff 요약) · 〔86-24〕 · 〔86-25〕.
8. **배포 · 전환**: identity-admin 이미지 발행 = 다음 main 발행 → UD-1 재질문(memory 「identity-admin 변경의 dev 반영」). 시한 = BFF가 처음 identity-admin을 부르기 전(T093 프리뷰 · 로컬 `next dev` — bff-api.md:11). UD-7c 해소 조각과 같은 발행 권고. 전환 창: 라이브 `revoked:sid` 호출자 0(BFF 미배포) — 사실상 0. 새 워커 `beat_init` 재적용이 활성 `sid` 행을 nbf 값으로 다시 쓴다(옛 값 `1`도 정규 꼴이라 503이 아니고 `1 > iat`는 거짓 — 비폐기로 읽힌다 · 재적용이 30 s 안에 덮는다). VD-UD7a-1.
9. **남는 것**: pod 경계는 여전히 `sid`를 집행하지 않는다(ia-25 한계 고정) · 유실 창에는 키 없음 = 통과(재적용이 되살린다).

## 3. VD(검증 후 결정)

| VD | 무엇 | 언제 · 어디서 | 어긋나면 |
|---|---|---|---|
| VD-T086-1 | 손으로 쓴 `^5.0.5` + install이 잠금 스냅숏 재사용 · lock 차이 = importer뿐 | ⓪ | D3-2 정확 판 경로 · 그래도 새 패키지면 멈추고 여쭘 |
| VD-T086-2 | 상대 import 부재 빨강 문구 | ① | 원인이 같으면 받아들인다 |
| VD-T086-3 | (r2) 실제 노트 2편이 거부 가드를 통과하는가(002 코드 스팬 속 `{FEFF}` · `<!-- … -->`) | T090 | 노트 수정(사람) 또는 규칙 정정 |
| VD-T086-4 | 한국어 헤딩 id(rehype-slug · github-slugger) | T090 | 기대값 정정(정정 노트) |
| VD-T086-5 | (r2) 생성 단계(Node 스크립트)의 기본 root 해석 | T091 | `JT_CONTENT_ROOT` 기본 주입 등 |
| VD-T086-6 | (r2 — T086-e) Worker 번들에 콘텐츠 컴파일 코드(unified · shiki · yaml · zod) 0 · 프로덕션 산출물에 draft 0(`.open-next/server-functions/default/handler.mjs.meta.json` — 〔CL mdx ④7〕) | T091 · T093 | 페이지 import 경로 정정 · 생성 단계 분리 |
| VD-T088-1 | dry-run outdir 실물 파일 집합 · 우리 합계 대 wrangler gzip | T093 | `MEASURED_EXTENSIONS` |
| VD-T089-1 | 없는 모듈 동적 import가 사례마다 실패하는가 | ② | image-loader 사례 분리(D9-1) |
| VD-T089-2 | 가짜 타이머로 3 s가 2999/3000에서 갈리는가 | ② | 경계 판정 조정 |
| VD-T089-3 | vitest 안 `Request`가 `cache` · `redirect` · 헤더 · `signal` 보존 | ② | 기록 방식 |
| VD-T089-4 | Authentik revoke 경로 · `client_secret_post` · end-session 경로 · ID 토큰 `sid` 있음 · `sub` 꼴 · `email` · `name` · `tenant_id` scope | T081 | C1 · C7 · C19 정정 · **`sid`가 없으면 UD-7 재질문** |
| VD-T089-5 | jose 6 `CompactEncrypt` ↔ 오라클 · `workerd` 조건 주석 근거 | T092 · T091 | 오라클 · 주석 |
| VD-T089-6 | `onerror=redirect`가 치명 오류 · 9422에서 원본 | T093 | 클라이언트 `onError`만 |
| VD-T089-7 | end-session이 Authentik 세션을 끝내는가: 이동 → 그 브라우저 `/if/user/` 로그인 화면 · Sessions 0 · Authentik 세션 없는 브라우저도 오류 없이 착지 · (r2 — V-A-1 · V-B-5) **추가 클릭 0 · OP 확인 화면 0** | T081(T080 뒤 · **logout Rule 전** — V-B-3) · T085 | 확인 화면이면 (a) 흐름 배치 정정(T080) → (b) 사용자 결정(`id_token_hint` vs 확인 단계 수용 + UI 안내). provider 흐름을 돌지 않으면 C23을 brand 흐름으로 — (r2 — V-A-3) 그러면 UD-7c (가′) 불가 → (나′) · 사용자 재질문 |
| VD-T089-8 | User Logout 부수 효과: ① SLO로 같은 브라우저 다른 앱이 끝나는가 ② `logout` 이벤트 생성 ③ context에 흐름 판별자 ④ (r2 — V-B-3) dev · prod 두 identity-admin이 같은 이벤트를 받는지 · 판별자가 두 env에서 같은지 | T081(Rule 전) | ① 기록 ③ 판별자 없으면 UD-7c 재질문((나′) + 교차 환경 번짐 vs (다′)) |
| VD-T089-9 | end-session 뒤 재로그인 `sid`가 새 값 | T081 · T085 | 같으면 (ㄴ)만으로 막는다(기록) |
| VD-T089-10 | `post_logout_redirect_uri`가 `client_id`만으로 받아지는가 · (r2 — V-B-5) 착지 리디렉션 여부(§3 「MUST NOT … unless other means」) | T081 | 리디렉션 0 · 확인 화면이면 사용자 결정(§5-3) |
| VD-T089-11 | 등록값만 리디렉션 · 등록 밖(`https://evil.invalid/`) 0 · 어느 목록에 등록 | T081 | 등록 밖도 가면 전용 흐름 끝 환경별 고정 Redirect(C23 질의 축소) — (r2 — V-A-3) 판별자 slug 둘(UD-7c 필터 닫힌 목록 둘) |
| VD-T089-12 | refresh 회전 재사용 감지: 옛 refresh → `invalid_grant`만인가 · 가족 폐기인가 | T081 | 가족 폐기면 isolate 간 동시 refresh가 강제 로그아웃 → T092 직렬화 · (r2 — V-B-1) logout `invalid_grant` 갈래를 204로 되돌릴지 컨트롤러 결정 |
| VD-T092-1 | (r2 — V-A-9 정의 보충) 같은 isolate 안 동시 요청 둘이 같은 refresh를 두 번 회전하지 않는가(single-flight) — workerd 로컬 | T092 | single-flight 구현 · 직렬화 |
| VD-T092-2 | `next start` · OpenNext preview 어댑터 env 원천(`getCloudflareContext` 실패 → `process.env`) | T091 · T093 | 어댑터 정정 · h-8은 env 0에서도 404 |
| VD-T087-1 | 새 APIRequestContext가 `accept-language`를 싣지 않는가 | ③ | 「헤더 없음」 처리 |
| VD-T087-2 | chromium 1255 해석 불가 커스텀 속성 계산값 = 빈 문자열 | ③ | 판정식 |
| VD-T087-3 | Next 16.3 프로덕션이 프리페치 링크에 `Next-Router-Prefetch: 1` · 정상 수(1회 실측) | T091 · T093 | 헤더 이름 · 상한 = 사용자 결정 |
| VD-T087-4 | prod 엣지 쿠키 이름 | T095 | `EDGE_COOKIE_NAMES` |
| VD-T087-5 | `/` 302 Location 꼴 · `next start` 호스트 | T091 | 기록만 |
| VD-T085-b(기존) | (r2 — B-6) localhost `Secure` · `__Host-` · `__Secure-` 쿠키가 `http://localhost:3000`에서 저장 · 전송되는가 | T085 | 로컬 dev 체인 처리(T085 설계) |
| VD-UD7a-1 | 배포 직후 `revoked:sid:*` nbf 꼴 · `1` 키 0 · `identity-admin:sid-floor:*` 생성 · (r2) 정규 꼴 판독 503 0 | ⑤ 배포 | 재적용 성공 줄 · 신선도 키 확인 · 수동 재적용 |
| VD-T081-4 · 5(기존) | refresh가 세션 삭제 · end-session 뒤에도 남는가 · 시계 차(이제 `revoked:sid` · 세션 단위 하한 · UD-7c (나′) 창에도) | T081 · T085 | t073-design.md:2307–:2310 |

## 4. 문서 · 계약 · 규칙 보정 목록

### 4-1. 지금(표식 「T08x 보정 2026-11-2x」 · ⑤는 「UD-7a 보정 2026-11-2x」 — 줄 번호는 HEAD `88ba7bb` 실물로 다시 확인했다)

| 파일 | 고칠 것 | 커밋 |
|---|---|---|
| `contracts/bff-api.md` | D7 C1–C29 · §4-2(:21 · :22 · 새 `__Secure-jt_pkce` 행 · :24 · :30 · :31 · :32 · :33 · :36 · :40 · :45 · :48 · :67 · :90 · :96) | T089 |
| `.claude/rules/web.md` + `docs/kr/rules/web_kr.md` | :21 · :22 · :25 · :29 · :31 · :35 · :43(§4-2). KR은 이미 `translation-pending`(web_kr.md:1) — 해당 줄을 고치거나 첫 줄 메모에 이 보정을 더한다(docs.md) | T089 |
| `quickstart.md` | :90 | T089 |
| `design/t077-design.md` 「정정 노트」(:446 아래) | 항목 ① UD-7(T089 커밋) · 항목 ② B-6(T087 커밋) — §4-2 | T089 · T087 |
| `.claude/rules/content.md` + `docs/kr/rules/content_kr.md` | :22(KR :23) `sources` 주석 · :28(KR :29) 뒤 새 줄(T086-e) | T086 |
| `.gitignore` | `.next/` | ⓪ |
| `.claude/rules/e2e.md`(새) + KR | paths `e2e/**` · `playwright.config.ts` · 요지(T077 D3 · D5 · D10 + 정정 노트 7 + D10 · D11 · static-gate 예외와 범위 규칙 · 런처 모드 · `site` 대상 허용 목록 · 아티팩트 0) | T087 |
| `AGENTS.md` + KR | 경로 규칙 표 `e2e/**` 행 · Commands에 런처 두 모드 · vitest 두 명령 | T087 |
| `tests/agents/codex-parity.tests.ps1` | :180 `$ruleDocs`에 `'e2e.md'` | T087 |
| `.claude/agents/web-builder.md` + KR | :18 territory에 루트 `e2e/**` · `playwright.config.ts` · :24 → 루트 `e2e/` | T087 |
| `e2e/README.md` | D10-8 · (r2 — B-6) :61 이름 | T087 |
| (r2 — B-6) `e2e/lib/bff.ts:56–57` · `e2e/selftest/bff.test.ts`(:93 · :234–:266) · `e2e/revocation.spec.ts:158` | 새 이름(빌더 ③). 계약 이름을 단언하지 않는 자리값(`e2e/needle/*` · `selftest/http.test.ts` · `scan-needle.test.ts`의 `jt_session=`)은 그대로 둔다 | T087 |
| ⑤ `contracts/denylist.md` | :3 · :10 · :11 뒤 새 행 · :18 · :23 · :24 · :28 · :29 · :33 · :34 · (r2 — V-A-2 · V-B-8) :35 · :57 · :96 · :98 | ⑤ |
| ⑤ `contracts/identity-admin-api.md` | :25 · :57 · :58 · (r2) :84 · :97 | ⑤ |
| ⑤ `data-model.md` | (r2) :7 · :54 · :66 · :67 뒤 새 행 · :71 · :72 · (r2) :73 · :76 · :268 | ⑤ |
| ⑤ `contracts/pod-template.md` | :108 · (r2 — 새 발견) :117 `DenylistRecord`(`sub_nbf` · `sid_revoked`) | ⑤ |
| ⑤ `.claude/rules/django-pod.md` + `docs/kr/rules/django-pod_kr.md` | (r2 — V-A-2 · V-B-8) :45 §Auth 거부 목록 값 판독 · :84 §Dragonfly 자기 키 목록 · KR(:68 등)은 이미 `translation-pending`(django-pod_kr.md:1) — 해당 줄 또는 첫 줄 메모 | ⑤ |
| build-notes · 학습 로그 | 「## T086–T089」 · 「UD-7a(ㄴ)」 · `content/tmp/003-t08{6,7,8,9}/` | 각 tick · ⑤ |

### 4-2. 새 문장 원문 초안

**`contracts/bff-api.md`**(T089)
- **:21 `jt_session` 행** → 이름 칸 `__Host-jt_session`. 「내용」 칸 첫 문장 →
  > AES-256-GCM JWE compact(`v1.` 접두 · `dir` · `A256GCM` · `typ` `jt-session` · IV는 봉인마다 새로)로 암호화한 `{refresh_token, sub, sid, tenant_id, issued_at, email?, name?}`(키 = Workers Secret `SESSION_ENCRYPTION_KEY`, 32바이트 = 16진 64자). `sid`는 callback ID 토큰의 `sid`이며 필수다(없으면 세션을 만들지 않는다). `email` · `name`은 ID 토큰에 있을 때만 싣는다. 이름은 `__Host-` 접두다 — 형제 서브도메인이 같은 이름 쿠키를 심지 못한다. 접두 없는 `jt_session`은 읽지 않는다(B-6 · T089 보정 2026-11-2x).

  나머지(`issued_at` 설명)는 그대로. 「속성」 칸 끝에 「(`Domain` 없음 — `__Host-` 조건)」.
- **:22 `jt_csrf` 행** → 이름 `__Host-jt_csrf` · 내용 「랜덤 128비트(16진 32자)」 · 나머지 그대로(`jt_session` → `__Host-jt_session`).
- **:22 뒤 새 행**
  > `| __Secure-jt_pkce | 봉인(typ jt-pkce) {state, verifier, return_to, created_at} — login이 싣고 callback이 성공 · 실패 모두 지운다 · created_at + 300 s를 넘으면 invalid_state | HttpOnly; Secure; SameSite=Lax; Path=/api/auth/callback; Max-Age=300(Path가 /가 아니라 __Host-를 쓸 수 없다 · 지울 때도 같은 Path · B-6 · T089 보정 2026-11-2x) |`

  표 아래 덧붙임: 「세 쿠키 모두 `Domain` · `Partitioned` · `Expires`를 싣지 않는다. 삭제는 같은 속성 + 빈 값 + `Max-Age=0`이다. `Max-Age`는 남은 수명으로 줄이지 않는다. 같은 이름이 둘 이상 오면 무효 쿠키다(T089 보정 2026-11-2x).」
- **:24** 「(최대 5분)」 → 「(유효 = 저장 시각 + `min(expires_in, 300) − 30` s · `expires_in`이 없거나 꼴 오류면 캐시하지 않는다 · T089 보정 2026-11-2x)」
- **:30 login 행** 「임시 쿠키(5분)」 → 「임시 쿠키 `__Secure-jt_pkce`(5분 · 위 표)」. 「판정은 표 아래 「같은 origin 경로」다」 뒤에 「— `return_to`만의 규칙(원문 · 중복 · 직렬화 · 바이트 상한)도 거기에 있다(T089 보정 2026-11-2x)」.
- **:31 callback 행** 끝 괄호 →
  > (입장 판정은 두지 않는다 — UD-8 (나) 2026-11-24: 폐기 뒤 재로그인은 업계 관례대로 IdP 쪽 세션 종료로 막는다 — 로그아웃의 Authentik 세션 종료(logout 행) · prod 사용자 단위 폐기의 Authentik 세션 삭제 위임 · 계정 탈취는 Authentik 사용자 비활성화(런북 T114) · T089 보정 2026-11-2x)

  덧붙임: 「ID 토큰은 `iss` · `aud` · `exp` · `iat`(정수) · `sub` · `sid`(출력 가능 ASCII 1–255자) · `tenant_id`(UUID)를 검사하고, 어긋나면 세션 쿠키 없이 503 `upstream_unavailable`이다. `__Secure-jt_pkce`의 `return_to`는 코드 교환 **앞에서** 다시 검증한다(400 `invalid_return_to` · 토큰 호출 0).」
- **:32 logout 행** 「동작」 칸 전체 →
  > **판정 순서**: 세션 쿠키(`__Host-jt_session`) 없음 → 401 `session_revoked`(`Set-Cookie` 0) → CSRF 불일치 → 403 → body 꼴 → 400 → BFF 설정 무효 → 두 쿠키를 지운 503 `upstream_unavailable`(상류 0 — 설정이 무효인 동안에도 공용 기기의 로그아웃이 쿠키를 남기지 않는다) → 쿠키 무효 → 두 쿠키를 지운 401 → 아래.
  >
  > body는 없음 · `{}` · `{ "all_devices": false }` · `{ "all_devices": true }` 넷 가운데 하나다. 그 밖(JSON 아님 · 객체 아님 · `all_devices`가 boolean이 아님 · 모르는 키)은 400 `invalid_request`다(상류 0 · `Set-Cookie` 0 — 범위가 모호한 요청을 어느 쪽으로도 접지 않는다).
  >
  > **기본은 이 기기다**(UD-7 (나) 2026-11-24): `all_devices: true`를 명시했을 때만 모든 기기다. 하류 `/sessions/revoke` 본문은 이 기기 = `{ "all_devices": false, "reason": "logout", "sid": "<쿠키 sid>" }`, 모든 기기 = `{ "all_devices": true, "reason": "logout_all" }`다. 이 기기 요청은 어떤 실패에서도 모든 기기로 바꿔 보내지 않는다.
  >
  > 이 기기 로그아웃은 pod 경계에서 집행되지 않는다(교환 토큰에 `sid`가 없다). 집행은 BFF가 한다 — 폐기 확인(`sid` 질의)과 refresh 폐기, 교환 캐시를 확인 뒤에만 쓰는 규율이다. `/sessions/revoke`가 202로 기록했으면 복사된 쿠키는 BFF를 거치면 2 s 안에 401이고, 이미 나간 교환 토큰은 남은 수명(≤ 330 s)만큼 BFF 안에서만 쓰인다. 기록되지 못한 갈래(아래 503)에서는 이 성질이 없다.
  >
  > 먼저 폐기 확인을 한다. inactive면 `/sessions/revoke`를 부르지 않고 자기 refresh 토큰을 RFC 7009로 폐기한 뒤(실패해도 진행) 쿠키를 지운다. 응답은 본문이 `all_devices: true`를 명시했으면 401 `session_revoked`(아무 폐기도 기록되지 않았다), 그 밖은 204다. 확인이 503이면 Authentik refresh revoke만 시도하고 쿠키를 지운 503이다.
  >
  > active면 `/sessions/revoke`(교환 토큰 + 서비스 토큰) → Authentik refresh revoke(내부 refresh가 회전했으면 새 refresh) → 그 isolate의 폐기 확인 · 교환 캐시에서 이 세션 항목을 지움 → 쿠키 삭제 → 204다.
  >
  > 실패 갈래(쿠키 · CSRF · body 검사를 통과한 뒤): 쿠키(`__Host-jt_session` · `__Host-jt_csrf`)는 하류 결과와 무관하게 지운다(사용자의 뜻 — 공용 기기). Authentik refresh revoke는 `/sessions/revoke`가 실패해도 시도한다. 아래 가운데 하나라도 실패하면 쿠키를 지운 503 `upstream_unavailable`이다: `/sessions/revoke`(시간 초과 · 3xx · 2xx가 아닌 응답) · 교환(거부 포함) · 내부 refresh(`invalid_grant` 포함 — 다른 isolate의 회전 경합이면 세션이 살아 있고 아무것도 기록되지 않았다 · VD-T089-12 뒤 다시 본다) · 토큰 응답 꼴 오류 · Authentik refresh revoke.
  >
  > **Authentik 세션 종료**(RP-Initiated Logout — UD-7a 2026-11-24): 세션 쿠키가 없는 401과 두 쿠키 삭제 `Set-Cookie`를 싣는 logout 응답(204 · 401 · 503)은 헤더 `x-end-session-url`에 그 브라우저의 Authentik 세션을 끝낼 주소를 싣는다(`AUTHENTIK_ISSUER` · `WEB_BFF_CLIENT_ID`가 유효할 때만).
  > - 주소는 BFF가 설정으로만 만든다: `AUTHENTIK_ISSUER` + `end-session/`. 질의는 정확히 `client_id`(= `WEB_BFF_CLIENT_ID`)와 `post_logout_redirect_uri`(= 요청 origin + `/` — provider에 등록된 값만 · T080)다. 클라이언트 입력 · 요청 헤더 · 상류 응답 헤더에서 오지 않는다. `id_token_hint` · `state`는 싣지 않는다.
  > - CSRF 403 · body 400에는 싣지 않는다.
  > - 클라이언트는 응답 상태와 무관하게 그 주소로 이동한다(top-level navigation). 상태가 204가 아니면 이동 전에 값 없는 표식을 `sessionStorage`에 남기고, 착지 페이지가 로그아웃이 완전하지 않았음을 알린다.
  > - 그 브라우저가 이 주소에 닿지 못하거나 Authentik이 확인을 요구해 사용자가 누르지 않으면 Authentik 세션이 남는다(한계 — VD-T089-7).
  >
  > (T089 시험 = G11 · G16 · G17 · T089 보정 2026-11-2x — 이전 문구의 「기본 로그아웃 범위는 T089 전 사용자 결정」 · 「refresh가 이미 만료 · 폐기됐을 때의 응답은 T092가 정한다」를 닫는다)

  「응답」 칸 → `204 / 400 invalid_request / 401 session_revoked(쿠키 없음 · 무효 쿠키 · 이미 폐기된 세션의 all_devices: true 요청) / 403 csrf_mismatch / 503 upstream_unavailable`
- **:33 refresh 행** 「후 isolate 교환 캐시를 비운다」 → 「후 그 세션(`sub` + `issued_at`)의 isolate 교환 캐시 항목을 지운다(T089 보정 2026-11-2x)」
- **:36 proxy 행**(r2 — V-A-7) 「(`sub` · `iat` = 쿠키 `issued_at` · 쿠키에 `sid`가 있을 때만 `sid`)」 → 「(`sub` · `iat` = 쿠키 `issued_at` · `sid` — 쿠키의 필수 키 · T089 보정 2026-11-2x)」
- **:40 같은 origin 경로** → 첫 문장의 「`\` · 공백 · C0 제어 문자(탭 · CR · LF 포함) · DEL을 담지 않고」를 「출력 가능 ASCII(`!`–`~`)만 담고 `\`를 담지 않으며」로 바꾸고, 끝에 덧붙인다:
  > WHATWG 해석 결과의 pathname이 `//`로 시작하면(예: `/..//evil.com` · `/a/..//evil.com`) 같은 origin 경로가 아니다. 디코딩한 값이 2,048자를 넘어도 아니다(컨트롤러 Node v24.11.1 실측 〔B-3〕). **`return_to`만의 규칙**: 질의에 둘 이상이면 400 · 원문에 깨진 퍼센트 인코딩(`%` 뒤 16진 두 글자가 아님 — `/%` · `%E0%A4%A`)이 있으면 400 · 디코딩은 한 번(`URLSearchParams` — `+`는 공백) · 302 `Location`과 `__Secure-jt_pkce`에 싣는 값은 요청 origin 기준 WHATWG 해석 결과의 pathname + search + hash다 · 봉인한 `__Secure-jt_pkce`의 이름과 값이 4,096바이트를 넘으면 400이다(T089 보정 2026-11-2x).
- **:45 응답 헤더** 전체 →
  > - 응답 헤더: BFF 응답의 헤더는 BFF가 만든다. 어느 라우트에서도 하류(pod · Authentik) 응답 헤더(`set-cookie` · `location` · `cf-*` · `x-request-id` 포함)를 옮기지 않는다. 예외는 프록시가 옮기는 `content-type` 하나다.
  > - BFF가 만드는 헤더 가운데 다른 주소를 가리키는 것은 둘뿐이고, 설정과 검증된 값으로만 만든다: login · callback 302의 `Location` · logout의 `x-end-session-url`.
  > - 모든 BFF 응답에 `cache-control: no-store` · `x-content-type-options: nosniff`를 단다.
  > - T089가 응답 헤더 이름 집합을 라우트 × 결과마다 정확히 단언한다(T089 보정 2026-11-2x — 이전에는 프록시 응답만 nosniff)
- **:48 폐기 확인**: 「쿠키에 `sid`가 없으면 `sid`를 빼고 보낸다 — 빈 `sid=`는 400 · T070 r2」 → 「`sid`는 쿠키의 필수 키다(callback이 ID 토큰 `sid` 없이는 세션을 만들지 않는다 · T089 보정) · 빈 `sid=`는 400 · T070 r2」 / 「`jt_session` · `jt_csrf` 삭제」 → 「`__Host-jt_session` · `__Host-jt_csrf` 삭제」 / 「(쿠키 `Max-Age`를 남은 수명으로 줄이는 것은 T092 선택)」 → 「(쿠키 `Max-Age`는 계약 값 그대로다 · T089 보정)」 / 끝 괄호 「(callback 입장 판정의 채택 여부는 T089 전 사용자 결정 · …)」 → 「(callback 입장 판정은 두지 않는다 — UD-8 (나) 2026-11-24 · 그 브라우저의 Authentik 세션은 로그아웃의 end-session이 끝낸다(UD-7a) · 계정 탈취 대응의 완결은 Authentik 사용자 비활성화 — 런북 T114 · T089 보정 2026-11-2x)」
- **:67 위생 규칙** 전체 →
  > - **페이지(`app/[lang]`)와 `/` 응답에 `Set-Cookie`를 넣지 않는다**(위생 규칙). 언어 · 테마 선택은 URL 경로와 `prefers-color-scheme`으로 표현한다.
  > - BFF 라우트는 이 계약이 정한 쿠키(`__Host-jt_session` · `__Host-jt_csrf` · `__Secure-jt_pkce`)를 정한 자리에서만 설정 · 삭제한다: `/api/auth/*` · 내부 refresh가 회전한 프록시 응답의 새 두 쿠키 · 폐기 확인 inactive · 무효 쿠키의 삭제(`/api/session` · `/api/proxy/*`).
  > - T087이 `/ko` · `/en` · `/ja` 응답에 `Set-Cookie`가 없음을 단언한다(T089 보정 2026-11-2x — 이전 문구 「쿠키는 `/api/auth/*`에서만 설정한다」)
- **:90 슬러그** → 「`type` 슬러그: `invalid_state`, `invalid_return_to`, `invalid_request`(logout 본문 꼴 — T089 보정 2026-11-2x), `session_revoked`, `exchange_denied`, `upstream_unavailable`, `csrf_mismatch`, `not_found`.」
- **:96 마스킹** 「`Cookie`(`jt_session`·`jt_csrf`)」 → 「`Cookie`(`__Host-jt_session` · `__Host-jt_csrf` · `__Secure-jt_pkce` · 접두 없는 옛 이름 포함)」 · 「BFF 자신의 `jt_session` · `jt_csrf`」 → 「BFF 자신의 세 쿠키」.
- 그 밖 D7 항목(C1 · C2 · C3 · C5 · C6 · C7 · C8 · C9 · C10 · C11 · C12 · C14 · C15 · C16 · C17 · C18 · C20 · C21 · C26 · C28)은 같은 커밋에서 해당 절에 「T089 보정」으로 싣는다.

**`.claude/rules/web.md`**(T089 · KR 같은 뜻)
- :21 끝 「revocation is checked inside `/api/session` via the upstream `/session/check`」 → 「revocation is checked by every route that uses the session cookie (`/api/session`, `/api/auth/refresh`, `/api/proxy/*`, `/api/auth/logout`) via the upstream `/session/check` before any token-endpoint call or exchange-cache use」
- (r2 — V-A-7) :22 「(`sub`, `iat`, and `sid` only when the claim exists)」 → 「(`sub`, `iat`, and `sid` — a required key of the session cookie)」
- :25 → 「`return_to` (returnTo) and a framework-redirect `Location` must be a same-origin path: after one percent-decoding it consists of printable ASCII (`!` to `~`) only, starts with `/` but not `//`, contains no `\`, and resolving it with the WHATWG URL parser against the request origin yields that same origin with a pathname that does not start with `//` (`/..//evil.com` resolves to `//evil.com`) — a prefix-only check passes `/\evil.com` and `/<TAB>/evil.com`. A decoded value over 2,048 characters is not a same-origin path. For `return_to` only: more than one occurrence, or a raw value with a malformed percent escape (`%` not followed by two hex digits), is 400; decoding is `URLSearchParams` (`+` is a space); the `Location` and the sealed `__Secure-jt_pkce` carry the WHATWG serialization (pathname + search + hash) of the resolved URL; a sealed cookie whose name and value exceed 4,096 bytes is 400. Anything that fails → 400 `invalid_return_to`. Re-validate with the same rule on callback before the code exchange.」
- :29 → 「The revocation check in every session route treats only a 200 whose body has a boolean `active` as a verdict; anything else (4xx, 5xx, timeout, malformed body, missing `active`) → 503 `upstream_unavailable`, cookie kept (logout deletes cookies by its own rule).」
- :31 전체(r2 — V-B-12 · V-A-4 · V-B-10 · V-B-1) → 「Logout checks, in order: the session cookie (absent → 401), CSRF (→ 403), the body shape (anything but none, `{}`, `{"all_devices": false}` or `{"all_devices": true}` → 400 `invalid_request`, no cookie change), the BFF configuration (invalid → both cookies deleted, 503 `upstream_unavailable`, no upstream call) and the cookie's validity (invalid → both cookies deleted, 401). Once the session, CSRF and body-shape checks pass, logout deletes `__Host-jt_session` and `__Host-jt_csrf` whatever the downstream outcome (the user's intent — shared devices) and attempts the Authentik refresh revoke even when `/sessions/revoke` fails; when `/sessions/revoke`, the exchange, the internal refresh (an `invalid_grant` included — nothing was recorded) or the revoke fails, it answers 503 `upstream_unavailable` with the cookies already deleted. Logout defaults to this device: only an explicit `all_devices: true` revokes all devices, and a this-device request is never widened. The 401 for a request without a session cookie and every logout response that deletes the cookies carry `x-end-session-url` (only while `AUTHENTIK_ISSUER` and `WEB_BFF_CLIENT_ID` are valid): a BFF-built Authentik end-session URL (`AUTHENTIK_ISSUER` + `end-session/`, query exactly `client_id` and `post_logout_redirect_uri` = request origin + `/`), never derived from client input or an upstream header; the client navigates there whatever the status, first leaving a value-free `sessionStorage` marker when the status is not 204 so the landing page can say the logout was incomplete. A callback whose code exchange times out or gets a 3xx or 5xx answers 503 `upstream_unavailable` without setting a session cookie, and it requires the ID token `sid`.」
- :35 → 「MUST NOT set `Set-Cookie` on any `app/[lang]` or `/` response. BFF routes set or delete only the contract's cookies (`__Host-jt_session`, `__Host-jt_csrf`, `__Secure-jt_pkce`) at the contract's places: `/api/auth/*`, the rotated cookies on a proxy response whose internal refresh rotated the token, and the deletion on an inactive or invalid session. The BFF never reads the unprefixed names (`jt_session`, `jt_csrf`), and a duplicated cookie name is an invalid session. `__Host-jt_csrf` carries the same `Max-Age` as `__Host-jt_session` and is set wherever it is (callback, refresh), so a browser restart never leaves a session that cannot pass the CSRF check on logout or refresh. Language and theme are expressed by URL path and `prefers-color-scheme`, never by cookie.」
- :43 「`Cookie` (`jt_session`/`jt_csrf`)」 → 「`Cookie` (`__Host-jt_session`/`__Host-jt_csrf`/`__Secure-jt_pkce`)」 · 「the BFF's own `jt_session`/`jt_csrf`」 → 「the BFF's own cookies」

**`quickstart.md:90`**(T089) →
> 3. 폐기(모든 기기): `curl -X POST https://joshuatech.dev/api/auth/logout -H 'x-csrf-token: …' -H 'content-type: application/json' -d '{"all_devices":true}' -b '__Host-jt_session=…; __Host-jt_csrf=…'` → 1초 뒤 `curl -H "Authorization: Bearer $ACCESS" -H "CF-Access-Client-Id: …" https://identity-m2m-prod.joshuatech.dev/tenants/me` → 401 `session_revoked`.
>
> pod 경계의 이 401은 사용자 단위 폐기(모든 기기)에서만 난다(교환 토큰에 `sid`가 없다). 기본 로그아웃(본문 없음)은 이 기기만 끝낸다(UD-7 (나) 2026-11-24) — 확인은 복사한 쿠키로 BFF를 부르면 2 s 안에 401인지다. 응답의 `x-end-session-url`로 이동하면 그 브라우저의 Authentik 세션도 끝난다.
>
> pod는 Access `common_name`이 web-bff Client ID인 호출만 받는다. 이 curl의 Access 헤더가 `tester-m2m`이면 401이 아니라 403 `access_required`다. 측정 경로는 T079 · T085 설계가 정한다(T073 보정 2026-11-12 · T089 보정 2026-11-2x).
>
> (T076 보정 2026-11-20 · 리뷰 RO-10: 자격 헤더 탐침은 검토된 블록으로만 한다 — `.claude/agents/tester.md` 「Credentials」. 이 손 `curl` 꼴은 T085가 O-8 꼴로 바꾼다)

**`design/t077-design.md` 「정정 노트」**
- ①(T089 커밋): 「UD-7 = (나) 확정(2026-11-24) — T079의 명시 `all_devices: true`(e2e/lib/bff.ts:59–60)는 기본 범위와 떼어 낸 것에서 「모든 기기」 경로의 필수 본문이 됐다. 로그아웃 성공 응답은 204 그대로이고 헤더 `x-end-session-url`만 더해지므로 `judgeLogout`(:182–:185) 변경은 0이다(:440 인계를 닫는다).」
- ②(T087 커밋 · r2 — B-6): 「B-6 쿠키 접두 채택(2026-11-24) — `BFF_SESSION_COOKIE` · `BFF_CSRF_COOKIE`(e2e/lib/bff.ts:56–57)를 `__Host-jt_session` · `__Host-jt_csrf`로 바꿨다. selftest 기대값(selftest/bff.test.ts:93 · :234–:266) · README:61 · revocation.spec.ts:158 주석을 함께 고쳤다. `pickSessionCopies`의 도메인 판정은 host-only 쿠키와 그대로 맞는다. 판정 동작 변경 0.」

**`.claude/rules/content.md`**(T086 · KR 같은 뜻)
- :22 주석 → `# required; may be empty; each item has exactly one of path (repo-relative, no leading /, no \ or ..) or url (http/https)`
- (r2 — T086-e) :28 뒤 새 줄 →
  > - Bodies are Markdown + GFM even though the file is `.mdx`: no JSX or HTML tags (`<…>`, comments included), no `import`/`export` lines, no `{` or `}` outside code spans and fenced code, and link, image and definition URLs only `http`, `https`, `mailto`, relative paths or `#` fragments. Front matter is YAML between exact `---` lines (no `---js` or other languages). The loader parses notes as plain Markdown and fails the build on any violation (file, line, rule) — it never strips one silently.

**⑤ — `contracts/denylist.md`**
- :3 끝: 「세션 단위 폐기(`sid` 행)도 같은 로그 행에서 세션 단위 하한 키를 파생한다 — 두 하한 키는 identity-admin `/session/check`만 읽는다(UD-7a 보정 2026-11-2x).」
- :10 행 → `| revoked:sid:{sid} | nbf(epoch 초, ASCII 숫자 1–19자 — 그 sid 행의 nbf) | 330 s | identity-admin | iat < nbf인 그 세션(sid)의 토큰만 거부 — 이 기기 로그아웃(BFF 기본 로그아웃 · UD-7 (나))(pod 경계에서는 조회되지 않는다 — §조회 규약 1 · 집행은 BFF의 /session/check · UD-7a 보정 2026-11-2x — 이전 값 1: 시각이 아니어서 로그아웃 직후 같은 Authentik 세션의 재로그인까지 330 s 거부했다) |`
- :11 뒤 새 행 → `| identity-admin:sid-floor:{sid} | 그 sid 행 가운데 가장 큰 nbf(epoch 초, 정수) | 그 행의 expires_at + 30 d까지(= nbf + 330 s + 30 d) | identity-admin | 세션 단위 하한 — sid가 같고 BFF 세션 시작 시각 < 값인 세션은 inactive(/session/check만 읽는다 · UD-7a 보정 2026-11-2x) |`
- (r2 — V-A-2) :18 「그래서 사용자 단위 폐기는 30일짜리 하한 키를 함께 남기고 … 정본은 같은 `session_revocation_log`의 사용자 단위 행(`sid` NULL)이다(새 표 · 새 열 없음). `sid` 행은 하한을 만들지 않는다.」 →
  > 그래서 사용자 단위 폐기는 30일짜리 사용자 단위 하한(`identity-admin:session-floor:{sub}`)을, 세션 단위 폐기(`sid` 행)는 30일짜리 세션 단위 하한(`identity-admin:sid-floor:{sid}`)을 함께 남기고, `/session/check`가 「하한 > 세션 시작 시각」이면 inactive를 낸다. 정본은 같은 `session_revocation_log`의 행이다(사용자 단위 = `sid` NULL 행 · 세션 단위 = `sid` 행 · 새 표 · 새 열 없음). 이전 문구 「`sid` 행은 하한을 만들지 않는다」 — 그때는 RFC 7009가 실패한 단일 기기 로그아웃의 복사 쿠키가 330 s 뒤 살아났다(T073 E13 · UD-7a 보정 2026-11-2x).

  키 이름 문장(「키 이름에 epoch를 쓰지 않는다」)은 그대로.
- :23 「`EXISTS revoked:sid:{sid}`」 → 「`GET revoked:sid:{sid}`」
- :24 → 「2. `revoked:sub` 값(`nbf`) > 토큰 `iat` → 401 `session_revoked`. `revoked:sid` 값(`nbf`) > 토큰 `iat` → 401 `session_revoked`. 둘 다 값이 `iat`와 같으면 통과한다. `revoked:sid` 값은 ASCII 숫자 1–19자(정규 꼴)여야 하고 밖이면 조회 실패(503)다 — `int()`로 읽으면 음수 · 공백 같은 손상이 조용히 「폐기 아님」이 된다(UD-7a 보정 2026-11-2x — 이전 문구 「`revoked:sid` 존재 → 401」).」
- :28 「`DenylistRecord(sub_nbf, sid_revoked)`」 → 「`DenylistRecord(sub_nbf, sid_nbf)` · `revokes(iat)` = `sub_nbf > iat` 또는 `sid_nbf > iat`」 · 「값이 정수가 아니면 조회 실패(503)다」 → 「값이 정수가 아니면(`revoked:sid`는 정규 꼴이 아니면) 조회 실패(503)다(UD-7a 보정)」
- :29 첫 문장 → 「7. 두 하한(`identity-admin:session-floor:{sub}` · `sid`가 있으면 `identity-admin:sid-floor:{sid}`)은 identity-admin `/session/check`만 파이프라인 1회로 조회한다(거부 목록 조회 뒤의 둘째 왕복 · …」(이하 그대로 · 정규 꼴 규칙은 두 하한에 같다)
- :33 「`sid` 행은 `SET revoked:sid:{sid} 1 EX min(330, ⌊expires_at − 현재 시각⌋)`다」 →
  > `sid` 행은 자기 행 값으로 `SET revoked:sid:{sid} <nbf> EX min(330, ⌊expires_at − 현재 시각⌋)`과 `SET identity-admin:sid-floor:{sid} <nbf> EX ⌊expires_at + 30 d − 현재 시각⌋`을 한 파이프라인으로 보낸다. DB를 읽지 않는다 — `sid` 행의 `nbf` 원천은 `/sessions/revoke`의 ⌊처리 시각⌋ + 1뿐이라 과거 값이 큰 값을 덮을 길이 없다. 같은 `sid`의 두 폐기가 커밋 역순으로 끝나는 ms 창은 재적용이 되돌린다. 두 키 가운데 하나라도 보냈으면 그 쓰기는 `ok`다(UD-7a 보정 2026-11-2x).
- :34 끝: 「`revoked:sid` 값은 그 행의 `nbf`다. 같은 실행이 세션 단위 하한도 되살린다 — `sid`가 NULL이 아니고 `expires_at + 30 d > now()`인 행을 `sid`별로 묶어 `nbf`가 가장 큰 행으로 SET한다(TTL = 그 행 `expires_at + 30 d − now()` 초 내림 · UD-7a 보정 2026-11-2x).」
- (r2 — V-A-2 · V-B-8) :35 「세션 하한 대상은 최근 30일 + 330 s의 사용자 단위 행이다(… — 추론)」 → 「하한 대상은 최근 30일 + 330 s의 사용자 단위 행과 `sid` 행이다 — 기본 로그아웃(UD-7 (나))마다 `sid` 행이 하나씩 생겨 세션 단위 하한 키도 그 수만큼 30일을 산다(SP-1 규모에서 수백 행 · 키 수 = 그 기간의 로그아웃 수 · Dragonfly 메모리는 T097 감시 — 추론 · UD-7a 보정 2026-11-2x)」
- (r2 — V-A-2) :57 「Celery 키와는 하위 이름 `session-floor:` · `denylist:`로 가른다」 → 「… `session-floor:` · `sid-floor:` · `denylist:`로 가른다(UD-7a 보정)」
- :96 T062 「`revoked:sid` 401」 → 「`revoked:sid` 값 > iat 401 · 값 = iat 200 · 정규 꼴 밖 503(UD-7a 보정)」
- (r2 — V-A-2) :98 「`sid` 폐기는 하한 없음」 → 「`sid` 폐기는 사용자 단위 하한 없음(세션 단위 하한만 — UD-7a 보정)」 + 끝에 「· (UD-7a) `sid` 폐기의 `revoked:sid` 값 = nbf · 세션 단위 하한 값 · TTL · 로그아웃 직후 같은 `sid`의 새 세션(`iat` ≥ `nbf`)은 active(W35) · `revoked:sid`가 없어도 하한이 그 전 세션을 막음(E13) · 정규 꼴 밖 503」

**⑤ — `contracts/identity-admin-api.md`**
- :25 → 「4. Dragonfly 거부 목록: `revoked:sub:{sub}` 값 > `iat` 또는 `revoked:sid:{sid}` 값 > `iat` → 401 `session_revoked`(`revoked:sid` 값은 ASCII 숫자 1–19자 · 밖이면 조회 실패 — UD-7a 보정 2026-11-2x — 이전 문구 「`revoked:sid:{sid}` 존재」). …」(이하 그대로)
- :57 `/session/check` 행: 「세션 하한 조회(뷰 소유 클라이언트의 `GET identity-admin:session-floor:{sub}` 1회 · …)」 → 「세션 하한 조회(뷰 소유 클라이언트의 파이프라인 1회 — `GET identity-admin:session-floor:{sub}` + `GET identity-admin:sid-floor:{sid}` · …)」 · 「(선택 — `sid=` 빈 값은 400 · BFF는 `sid`가 없으면 쿼리에서 뺀다 · T070 r2)」 → 「(선택 — `sid=` 빈 값은 400 · BFF는 늘 싣는다 — contracts/bff-api.md 세션 쿠키 · T089 보정)」 · 「**`active` = 아래 넷이 모두 아닐 때**: ① … ② `sid`가 있고 `revoked:sid:{sid}`가 있음 ③ 세션 하한 값 > `iat` ④ …」 → 「**다섯이 모두 아닐 때**: ① `revoked:sub:{sub}` 값 > `iat` ② `sid`가 있고 `revoked:sid:{sid}` 값 > `iat` ③ 세션 하한 값 > `iat` ④ `sid`가 있고 세션 단위 하한 값 > `iat` ⑤ 나이 · 미래 값(그대로)」 · 「① · ③은 값이 `iat`와 같으면 active다」 → 「① – ④는 같으면 active다」 · 정규 꼴 규칙은 두 하한과 `revoked:sid`에 같다(UD-7a 보정 2026-11-2x).
- :58 `/sessions/revoke` 행: 「`false` → `sid` 행(…) + `revoked:sid:{sid}` = `1`」 → 「… + `revoked:sid:{sid}` = `nbf`(330 s) + 세션 단위 하한 `identity-admin:sid-floor:{sid}` = `nbf`(그 행 `expires_at + 30 d`까지)」 · 커밋 후 SET 문장의 `sid` 행 부분 → contracts/denylist.md §쓰기 규약 새 문장과 같다 · 「(BFF의 기본 로그아웃 범위는 T089 전 사용자 결정 · 실측 T081)」 → 「(BFF의 기본 로그아웃은 이 `sid` 단위다 — UD-7 (나) 2026-11-24 · contracts/bff-api.md logout 행 · 실측 T081)」 · 「그 세션이 330 s 안에 BFF에 닿지 않으면 효력이 없다」 → 「세션 단위 하한이 30일 동안 BFF 폐기 확인에서 그 세션을 막는다(UD-7a 보정 — 이전 문구 「330 s 안에 BFF에 닿지 않으면 효력이 없다」)」
- (r2 — V-A-2 · V-B-8) :84 `reconcile_denylist` 행: 「**세션 하한(T073 보정 2026-11-12)**: …」 뒤에 덧붙인다 — 「**세션 단위 하한(UD-7a 보정 2026-11-2x)**: 같은 실행에서 `sid`가 NULL이 아니고 `expires_at + 30 d > now()`인 행을 `sid`별로 묶어 `nbf`가 가장 큰 행으로 `identity-admin:sid-floor:{sid}` = 그 `nbf`를 다시 SET한다(TTL 같은 규칙 · 1 미만 건너뜀). `revoked:sid` 값은 그 행의 `nbf`다(이전 `1`).」 · 반환 설명 「`{ rows, keys, floors, skipped, failed }`」 뒤에 「(`floors` = 두 하한 SET 수의 합 · `rows` = 활성 행 수 — UD-7a 보정)」
- (r2 — V-A-2 · V-B-8) :97 `revoke_sessions` 행 「(단일 세션 폐기 인자는 두지 않는다 — `sid` 폐기는 330 s 차단뿐이고 refresh 폐기가 따르지 않아, 그 세션이 330 s 안에 BFF에 닿지 않으면 효력이 없다)」 → 「(단일 세션 폐기 인자는 두지 않는다 — 관리자의 `sid` 폐기에는 refresh 폐기가 따르지 않고 그 사용자의 다른 세션 · Authentik 로그인이 남는다. 대상 사용자를 끝내는 것은 사용자 단위 폐기다 · UD-7a 보정 2026-11-2x — 이전 근거 「330 s 차단뿐 … 효력이 없다」는 세션 단위 하한으로 낡았다)」

**⑤ — `data-model.md`**
- (r2) :7 「세션 하한 키는 §3 `SessionRevocation`(파생 캐시)의 키 한 줄이라」 → 「세션 하한 키 둘(사용자 단위 · 세션 단위 — UD-7a 보정 2026-11-2x)은 §3 `SessionRevocation`(파생 캐시)의 키 두 줄이라」
- (r2) :54 「값 = 세션 단위 폐기(`revoked:sid:{sid}`)」 → 「값 = 세션 단위 폐기(`revoked:sid:{sid}` + 세션 단위 하한 — UD-7a 보정)」
- :66 → `| revoked:sid:{sid} | epoch 초 nbf — iat < nbf인 그 세션 토큰 거부(단일 기기 · UD-7a 보정 2026-11-2x — 이전 값 1) | 330 s |`
- :67 뒤 새 행 → `| identity-admin:sid-floor:{sid} | 그 sid 행 가운데 가장 큰 nbf — 세션 시작 시각 < 값이고 sid가 같은 BFF 세션은 inactive(/session/check만 · UD-7a 보정) | 그 행 expires_at + 30 d까지 |`
- :71 「`sid`가 있는 행은 `revoked:sid:{sid}` = `1`」 → 「`sid`가 있는 행은 `revoked:sid:{sid}` = `nbf`와 세션 단위 하한 키(UD-7a 보정)」
- :72 「(TTL = `min(330, 남은 초)` …」 → 「(`revoked:*` TTL = `min(330, 남은 초)` · 하한 키 TTL = 그 행 `expires_at + 30 d`까지 …」
- (r2 — V-A-2 · V-B-8) :73 끝: 「같은 실행이 `sid`가 있고 `expires_at + 30 d > now()`인 행으로 세션 단위 하한 키를 되살린다 · `revoked:sid` 값은 행의 `nbf`(UD-7a 보정)」
- (r2 — V-B-8) :76 「`expired`(`revoked:*` TTL 만료 — 사용자 단위 행은 세션 하한 키만 남는다)」 → 「(… — 사용자 단위 행은 사용자 단위 하한, `sid` 행은 세션 단위 하한 키만 남는다 · UD-7a 보정)」
- :77 인덱스는 그대로(D15-4 — 새 인덱스 0).
- (r2) :268 「`identity-admin:session-floor ◀──조회── identity-admin /session/check`」 → 「`identity-admin:session-floor · identity-admin:sid-floor ◀──조회── identity-admin /session/check`」

**⑤ — `contracts/pod-template.md`**
- :108 「`revoked:sid` 401」 → 「`revoked:sid` 값 > iat 401(= iat 200 · 정규 꼴 밖 503 · UD-7a 보정)」
- (r2 — 새 발견) :117 「`DenylistRecord`(`sub_nbf` · `sid_revoked` · `revokes(iat)`)」 → 「`DenylistRecord`(`sub_nbf` · `sid_nbf` · `revokes(iat)` — UD-7a 보정)」

**⑤ — `.claude/rules/django-pod.md`**(KR은 `translation-pending` 메모로)
- (r2 — V-A-2 · V-B-8) :45 §Auth 「a non-integer denylist value is a lookup failure (503)」 → 「a non-integer denylist value — for `revoked:sid`, anything but 1–19 ASCII digits — is a lookup failure (503); a `revoked:sid` value greater than the token `iat` revokes it (equal passes)」
- (r2 — V-A-2 · V-B-8) :84 §Dragonfly 「(identity-admin: `identity-admin:session-floor:{sub}`, `identity-admin:denylist:reapplied-at`) (T073)」 → 「(identity-admin: `identity-admin:session-floor:{sub}`, `identity-admin:sid-floor:{sid}`, `identity-admin:denylist:reapplied-at`) (T073; UD-7a)」

### 4-3. 나중(그 과제와 함께)

| 시점 | 파일 | 고칠 것 |
|---|---|---|
| T080 | Authentik 블루프린트 | 전용 흐름 `web-bff-invalidation`(User Logout 하나 · 확인 단계 0) · 두 provider `invalidation_flow` · post-logout 등록 3 · UD-7c 답 반영 |
| T081 | 웹훅 매핑 · Rule · identity-admin 후속 조각 | UD-7c 답에 따른 필터(두 env) · VD-T089-4 · 7–12(Rule 전) |
| T090 | `packages/content` 의존 | (r2 — T086-e) 설치 승인 뒤 기반 커밋(§5-3) |
| T091 | `next.config.ts` 주석 · wrangler vars | jose 6 근거 · `AUTHENTIK_ISSUER` · `WEB_BFF_CLIENT_ID` · `workers_dev: false` · `preview_urls: false` |
| T084 | `docs/runbooks/secret-rotation.md` | 키 생성 · `v2.` 이중 키 창 |
| T093 | quickstart.md:100 · :102 | DOM 수 · `--measure` 꼴 |
| T093 | VD-2 임시 Cache Rule | (r2 — B-6) 조건 「`jt_session` 쿠키 없음」(spec:211 · :263)을 `__Host-jt_session`으로(〔86-30〕) |
| T094 | `classifySiteReach` | prod 비v2 갈래 → `[product]` |
| T098 | UD-10 질문 자료 | (r2 — V-B-13) C24로 모든 `/session/check` 질의에 원문 `sid`가 실린다 |
| T114 | 런북 | 계정 탈취 = Authentik 사용자 비활성화 + 한계 · 공용 PC 소셜 로그인 안내 · (r2) prod 「모든 기기」 = 관리 SSO 포함 종료 |
| `/finish` | CLAUDE.md · report | 규칙 목록에 e2e · 〔86-1〕–〔86-30〕 |
| 고칠 수 없음 | tasks · spec · plan · ADR 본문 | 〔86-n〕으로만(ADR 0006:29는 T-c에서 그대로 참 · ADR 0004 D19는 T086-e에서 그대로 · 0004:29 근거 낡음은 T091 전 질문) |

## 5. 위험 · 인계

### 5-1. 받아들인 위험

1. 빨강 기간이 길다(T087 로컬 = T090–T092 + T086-a · prod = T095 · T088 = T093).
2. 시험이 API를 고정한다 — 공개 표면을 최소로 했다(D4 · D5 · D6).
3. lockfile 변경이 events-test 방어 경로에 든다 — 렌즈 C · frozen 두 번 · `@jt/events` 초록.
4. static-gate 예외 2 — 한 파일 · import 범위 · 위험 메서드(r2: 여섯) · `expect` 인자 · 수 · 불리언 반환 · 양성 대조로 줄인다.
5. GitGuardian은 required가 아니다 — 리터럴 0으로 피하되 보장은 못 한다.
6. CI 공백 창(T090 → T093).
7. h-9 하한 없음 — INFO · selftest-browser · VD-T087-3으로 줄인다.
8. 계약 보정이 많다(C1–C29 · r2 추가) — 렌즈 A 대조.
9. T086-a로 두 노트 공개 — 사람 검토 전제.
10. **이 기기 로그아웃은 pod에서 집행되지 않는다**(교환 토큰 잔여 ≤ 330 s · 다른 isolate 확인 캐시 ≤ 2 s — 〔86-22〕). (r2 — V-B-2) **기록되지 못한 로그아웃**(확인 503 · `/sessions/revoke` · 교환 · 내부 refresh 실패 · `invalid_grant` — 전부 503)에서는 복사 쿠키가 `/api/session`(C18 — 토큰 호출 0)에서 최대 30 d 프로필을 받고, RFC 7009도 실패했으면 전부 쓸 수 있다. 503을 사용자에게 보여 「모든 기기」로 보완하게 한다(클라이언트 규약 3). 시계 틈(Authentik이 앞설 때 로그아웃 직전 ≤ 60 s에 시작한 그 `sid` 세션)도 남는다.
11. end-session 이동이 끊기거나 (r2 — V-A-1) OP 확인 화면을 누르지 않으면 Authentik 세션이 남는다(탐지 불가 — VD-T089-7).
12. 상류 IdP(GitHub) 세션은 남는다 — 런북 T114 · UI 안내 후보.
13. UD-7c 해소 전에는 이 기기 로그아웃이 모든 기기로 — (r2 — V-B-3) **dev · prod 교차로도** — 번질 수 있다. 순서 제약(§0-2-3)으로 막는다.
14. **isolate 간 동시 회전**: 다른 isolate 둘이 같은 refresh로 회전하면 둘째가 `invalid_grant`다(VD-T089-12 · T092). (r2 — V-B-1) logout 쪽 결과: 기록 없이 쿠키만 지우면 다른 isolate의 새 쿠키가 브라우저에 다시 서서 세션이 산다(최대 30 d) — r1의 204는 조용한 실패였다. r2는 503(보이는 실패) + 직렬화(클라이언트 규약 1)로 줄인다. 근본책(BFF가 Access 서비스 토큰만으로 `sid`를 폐기하는 경로 — 교환 토큰 불필요 · identity-admin 계약 변경)은 사용자 결정 후보다(§5-3).
15. ⑤ 템플릿 시험 변경 · 하네스 · 재렌더 비용 · django-common 공개 API 이름 변경(`sid_revoked` → `sid_nbf`) · (r2) 재적용 셋째 SQL은 새 인덱스 없이 범위 스캔 + 정렬(규모가 커지면 마이그레이션).
16. UD-8 남는 틈(D16 실패 · dev · end-session 끊김).
17. ID 토큰에 `sid`가 없으면 로그인 자체가 503 — VD-T089-4가 먼저 잰다.
18. 세션 단위 하한도 Dragonfly 유실 창에는 없다(재적용이 되살린다).
19. (r2 — T086-e) 노트 본문에 컴포넌트를 쓸 수 없다(필요해지면 remark-mdx + 거부 플러그인 + 새 ADR). 편집기의 MDX 확장이 `{` · `<`를 오류로 보일 수 있다(추론). 거부 규칙 · 픽스처를 우리가 유지한다.
20. (r2 — B-6) 옛 이름 쿠키(`jt_*`)는 무시된다 — 배포 전이라 사용자 영향 0. localhost 접두 쿠키 동작은 VD-T085-b.
21. (r2 — V-B-13) C24로 모든 `/session/check` 질의에 원문 `sid`가 실려 UD-10(Traefik 접근 로그) 노출 면이 는다 — T098 전 UD-10 결정 자료에 넣는다.
22. (r2 — V-A-4) 설정 무효 logout은 상류 0이라 RFC 7009 · 기록이 없다(쿠키 삭제 + 503 · 종료 설정이 유효하면 end-session) — 설정을 고친 뒤 그 refresh는 살아 있지만 브라우저 쿠키가 없다.
23. (r2 — V-A-6) `revoked:sub`의 `int()` 판독은 그대로라 손상 값(`-5`)이 열린 쪽으로 읽힌다(쓰는 쪽은 identity-admin뿐 — ACL). 열린 항목.

### 5-2. 인계

- **T080**: 전용 흐름 `web-bff-invalidation`(User Logout 첫 · 유일 단계 · 확인 단계 0 — V-A-1) · 두 provider · 공유 기본 흐름 불변 · post-logout 등록 3 · ID 토큰 `sid`(VD-T089-4와 함께) · UD-7c 답 뒤 확정.
- **T081**: VD-T089-4 · 7–12를 **logout Rule을 켜기 전에** 잰다(r2 — V-B-3) · UD-7c 답 반영(웹훅 매핑에 판별자 · 두 env 필터 — identity-admin-api.md :59 · :65 · 대조 행) · 순서 제약: 필터가 라이브에 들기 전에는 Rule · 대조 권한을 켜지 않거나 어느 BFF도 end-session을 내지 않는다 · VD-T089-12 뒤 logout `invalid_grant` 갈래 재검토(컨트롤러).
- **T084**: 키 생성 · `v2.` 키 고리.
- **T085**: 이 기기 — 복사 쿠키 BFF 경유 2 s 401 · 모든 기기 — T079 · end-session — `/if/user/` 로그인 화면 · 클릭 0 · 재로그인 새 `sid` · 다른 기기 세션이 이 기기 로그아웃 뒤(웹훅 지연 · 대조 · **다른 env** 포함) active로 남는지 · D16 실패 → UD-8 재질문 · ⑤ 뒤 W35 부재 · (r2) VD-T085-b 접두 쿠키.
- **T090**: D4 API · 파이프라인 · 거부 규칙 전부(머리 주석 정본) · 검증 → draft · 모아 던지기 · root 해석 · 정렬 · 헤딩 id · 하이라이트 · TOC · 1회 스캔 캐시(생성 단계 1회) · JSON Schema export · 본문 산출 필드는 자기 TDD로 먼저 · VD-T086-3 · 4. (r2 — T086-e) **새 의존**: yaml · zod · unified · remark-parse · remark-gfm · remark-frontmatter · remark-rehype · rehype-slug · @shikijs/rehype(+ shiki) · 출력용(rehype-stringify 또는 hast-util-to-html) · 직접 import하는 유틸(unist-util-visit · hast-util-to-string 등)은 선언 — 착수 때 사용자 승인 → 컨트롤러 기반 커밋 · lock에서 mdast-util-to-hast ≥ 13.2.1 · zod ≥ 4.6.6 확인 · Shiki는 Renovate 그룹 · gray-matter · reading-time · 지우기형 도구 0.
- **T091**: image-loader C21 + `onError` → `fallbackSrc` · hello 규약(`<html data-jt-app="web">` · 노트 요소 `data-note-slug` · `data-note-lang` · `[data-note-title]` · `time[datetime]` · `[data-note-tag]` · 배지 `data-translation-missing` · 토큰 접두 · comp → sys만 · dark는 sys만 · 프리페치 링크 요구 0) · `app/route.ts` 302 + 협상 · 페이지 · `/` `Set-Cookie` 0 · wrangler · next.config TDD(`run_worker_first` · `[cache]` · flags · `serverExternalPackages` 주석 · 최상위와 `env.preview` 모두 `workers_dev: false` · `preview_urls: false`) · `workspace:*` · create-next-app 수동 병합 · (r2 — T086-e) 생성 단계 prebuild(Node — 페이지는 산출물만 import · 프로덕션 draft 0 · VD-T086-5 · 6) · (r2) 로그인 UI logout 규약(§0-2-1 클라이언트 규약 1–4 · 「모든 기기」 prod 경고 — V-B-11) · OpenNext 판 · Next 판 · 번들 근거는 §5-3 질문 뒤 · VD-T087-3 · 5 · VD-T089-5 · VD-T092-2.
- **T092**: D6 · D7 전부 · D7 끝 목록 · VD-T092-1 · 2 · 프록시 내부 refresh `invalid_grant`(권고 503 · 쿠키 유지 — 회전 경합에서 먼저 온 새 쿠키를 지우지 않게) · (r2) logout 클라이언트 규약을 UI와 함께 · 계약 우선.
- **T093**: `bundle-budget.mjs` + 빌드 · dry-run · VD-T088-1 · CI web job(content · web vitest · bundle-budget · Playwright `site` local · Linux 판정 규율 = skipped == 1 · h-7 INFO 줄 · failed 0 또는 플랫폼별 런처 · `--only-shell chromium` · 업로드 0 정적 단언 · 빌드 env 비밀 0 · events-compat → events-test 사이에 끼우지 않음) · 전제 T086-a · `opennextjs-cloudflare preview` 검토 · VD-2 순서(T094와 묶을지 사용자에게) · (r2 — B-6) 임시 Cache Rule 조건 이름 · ⑤ dev 반영(UD-1) · UD-7c 순서 제약 · VD-T086-6.
- **T094**: preview 사전 E2E는 운영자 수동 · `[product]` 전환 · workers.dev 무응답.
- **T095**: `site` prod 9건(skip 0) · VD-T087-4 · `upstream_ms` 100회 · workers.dev 재확인 · 로그아웃은 T085.
- **T079 · T077**: T079 코드 동작 0 — 명시 본문이 「모든 기기」 필수 본문이 됐다 · (r2 — B-6) 쿠키 상수 · selftest 이름 개정(T087 커밋 · 정정 노트 ②) · T077 brand 흐름(authentik-flow.ts:37)은 provider 흐름과 무관 · AC4는 UD-7c (가′)에서도 사용자 단위.
- **T098**: UD-10 자료에 C24(V-B-13).
- **T114**: 계정 탈취 대응 + 한계 · 공용 PC 소셜 로그인 · prod 「모든 기기」 관리 SSO.
- **/finish**: 〔86-1〕–〔86-30〕 · CLAUDE.md 구조 문장 · KR 미러 동기화(web_kr · django-pod_kr pending).

### 5-3. 시점별 사용자 질문(r2)

| 시점 | 질문 | 자료 |
|---|---|---|
| T080 블루프린트 전(UD-4와 함께) | **UD-7c** (가′) 권고 vs (나′) · (다′) · (라′) | §0-2-3(교차 환경 · VD 폴백 교차) |
| T090 착수 | 로더 새 의존 설치 승인 | §5-2 T090 목록 · 판 · 전이 수 · lock 차이 |
| T091 전 | 곁가지 셋: ① @opennextjs/cloudflare 1.20.18 peer `next >=15.5.29 <16 \|\| >=16.4.5`가 plan · ADR 0004 · T091의 Next 16.3.4 고정과 맞지 않는다(2026-11-03 Next 보안 릴리스 반영) ② Workers 압축 크기 한도 폐지(2026-09-04 — 비압축 64 MiB만) → ADR 0004:29 「3 MiB 안전 마진」 근거가 낡았다 · 2.5 MiB 게이트는 시작 시간 예산으로 유지 권고 · 값을 바꾸면 새 ADR + T088 수치 ③ OpenNext #1334 수정판(1.20.7+) — plan 핀 1.20.5 | decisions-controller.md:117–:120 · 〔CL syn §6〕 · 〔R1 2-8〕 |
| T091 첫 렌더 전 ~ T093 전 | T086-a 노트 검토 실행 | §0-4 |
| ⑤ 발행(BFF 첫 identity-admin 호출 전) | UD-1 재질문 + T-c 계약 추가 한 줄 알림 | D15-8 |
| T081(VD 결과에 따라) | VD-T089-4 `sid` 없음 → UD-7 재질문 · VD-T089-7 · 10 확인 화면 · 리디렉션 0 → `id_token_hint` 싣기 vs 확인 단계 수용 + UI 안내 · VD-T089-8 판별자 없음 · VD-T089-7 폴백 → UD-7c 재질문((나′) + 교차 환경 번짐 vs (다′)) · VD-T089-12 가족 폐기 없음 → 근본책(BFF 서비스 토큰 `sid` 폐기 경로) 여부 | §3 |
| T085 | D16 위임 실패 → UD-8 (가) 재질문 | §0-3 |

## 6. 검증 반영표(r1 → r2)

- 정본 처리 표 = 별도 산출물 handling-r2(V-A-1–11 · V-B-1–13 · T086-e · B-6 자리). r0 비판 29건 처리는 handling-r1 그대로 유효하다(r1 검증 claim-false 0).
- 자리 요약: V-A-1 §0-2-1 · VD-T089-7 · 10 · V-A-2 §4-2 ⑤ · D15 · V-A-3 §0-2-3 · VD-T089-7 · 11 · V-A-4 C6 · C23 · C26 · G16 · §4-2 :32 · web :31 · V-A-5 C27 · G2 · V-A-6 D15-2 · ac-25 · V-A-7 §4-2 :36 · web :22 · V-A-8 D15-4 · D15-6 · V-A-9 C25 · D2 · D3 · D9-5 · D10-3 · VD-T092-1 · V-A-10 D8 머리 · C28 · D12 · V-A-11 §0-1 · C23 / V-B-1 C22 · G11-11 · §5-1-14 · VD-T089-12 · V-B-2 D15-3 · §5-1-10 · 〔86-22〕 · §0-2-1 규약 · V-B-3 §0-2-3 · §5-2 T081 · T085 · V-B-4 G17 · G11-9 · V-B-5 §0-2-1 · VD-T089-7 · 10 · V-B-6 D10-4 · V-B-7 C27 · G2 · V-B-8 §4-1 · §4-2 ⑤ · 〔86-24〕 · V-B-9 G11-1 · 2 · V-B-10 C23 · G11-2 · V-B-11 §0-1 · §0-2-1 · §5-2 T091 · V-B-12 web :31 · V-B-13 G16 · D15-2 · C24 · §5-1-21.

## 7. 확정 보정(컨트롤러 · 2026-11-24)

설계 r2 검증(`.superpowers/t086/design/verify-{A,B}-r2.md` — 둘 다 approve_with_fixes · HIGH 0 · MEDIUM 3)의 고칠 방향과 r2 열린 항목 「컨트롤러가 정할 것」 1–4를 컨트롤러가 채택했다. **확정 설계 = r2 본문 + 이 절.** 본문과 이 절이 어긋나면 이 절이 이긴다. 빌더 지시문에는 해당 조각의 N 항목을 함께 싣는다.

### N-1 draft 기본값은 닫힌 쪽(V-A2-1 · V-B2-1 · MEDIUM)
- D4 API: `includeDrafts` 기본값 = `NODE_ENV`가 정확히 `development` 또는 `test`일 때만 참이다. 미설정 · `production` · 그 밖(예: `staging`)이면 거짓(제외)이다.
  - 까닭: r2가 컴파일을 `next build` 밖의 Node 생성 단계(T091 prebuild)로 옮겨 r1의 전제(「`next build`는 production」)가 깨졌다. 미설정에서 draft가 프로덕션 산출물에 들어가면 사람 검토 관문(content.md:20)을 건너뛴다.
- 프로덕션 산출물을 만드는 생성 단계는 `includeDrafts: false`를 **명시**로 넘긴다. 빌드 모드는 명시 플래그로 받고 `NODE_ENV` 기본값에 기대지 않는다(§5-2 T091 인계).
- ld-5에 사례를 더한다: `NODE_ENV` 미설정 → 제외 · `staging` → 제외(기존 `production` · `test`와 함께).
- VD-T086-6을 바꾼다: 「draft 픽스처 root(`JT_CONTENT_ROOT`)로 생성 단계를 돌려 산출물에 그 slug가 0」(T093 CI 단언 후보). T086-a 뒤 실제 draft가 0편이어도 공허해지지 않게 심은 픽스처로 잰다.
- 〔86-11〕 문장을 이 기본값으로 고친다.

### N-2 ld-13은 허용 목록을 고정한다(V-B2-2 · MEDIUM)
- 위반 사례를 더한다(각각 `unsafe-url`): `[x](JaVaScRiPt:alert(1))` · `[x](ftp://example.com/x)`(무해하지만 허용 목록 밖) · `[x](<java script:alert(1)>)` · `[x](java&#9;script:alert(1))`.
- 대조(허용) 사례를 더한다: `[y](HTTPS://example.com)` · `[z](MAILTO:a@example.com)` — 대소문자 무관 허용 목록.
- D12에 ⓔ를 더한다: 「소문자 차단 목록 스텁 → ld-13 passed 0」.
- (V-B2-12) `ContentValidationError` 메시지와 issues에는 입력 값(위반 URL · 프런트매터 값)이 없다 — 파일 · 줄 · 규칙 이름만. ld-10 · ld-13에 「메시지에 입력 값 0」 단언을 둔다(CI 빌드 로그는 공개다).

### N-3 BOM은 남겨서 판정한다(V-A2-2 · V-B2-10)
- D4 파이프라인 1: `new TextDecoder('utf-8', { fatal: true, ignoreBOM: true })`. U+FEFF가 남아 3단계 「첫 줄이 정확히 `---`」가 BOM 파일을 `(file, frontmatter, fence)`로 거부한다. ld-14 BOM 사례는 그대로다.
- 근거: Node v24.11.1 실측 — 기본(`ignoreBOM: false`)은 BOM을 지워 `"---\n"`, `ignoreBOM: true`는 U+FEFF를 남긴다.

### N-4 ⑤ 시험 영향 표를 채운다(V-A2-3 · V-B2-8)
- D15-6에 행을 더한다
  - ia-32(test_identity_jobs.py:588 · `floors == 2` :626 — sid 하한 둘이 더해진다)
  - ia-38(:756 · `filled == actual` :787 — `floors`와 `session-floor:*` 스캔이 어긋난다)
  - ac-20(packages/django-common/tests/test_auth_contract.py:2328 · :2340–:2341 — 값 = iat + 60 → 401 · 판정 로그 0 유지)
  - ia-36 · ia-37(test_identity_contract.py:1887 · :1944 — `is_active` 서명). `sid_floor`에 기본값 `None`을 둔다.
- 「쓰기 0」 도우미 `_written`(test_identity_contract.py:252–:256)에 `identity-admin:sid-floor:*`를 더한다.
- 사소: ac-12a · ac-13의 파일 이름(test_auth_contract.py) · test_fixtures_dragonfly.py:42–:46 리더 파이프라인 표본(get + exists → get + get) · test_identity_jobs.py:272 주석.
- D15-5에 auth.py:258 `SessionRevoked` 독스트링(「revoked:sid 존재」)을 더한다.

### N-5 설정 무효 callback = 503 + pkce 삭제(V-A2-4)
- V-A-4와 같은 논리(쿠키 삭제에는 비밀이 필요 없다)로 정한다: 설정이 무효일 때 callback은 503이고 `__Host-jt_pkce`(N-9)를 지운다.
- C26 · G16에 callback 예외를 적는다. D9-4 표에 「설정 무효 503(login · refresh · session · health · proxy) — `Set-Cookie` 0」 행과 「callback — pkce 삭제」 행을 둔다.

### N-6 §4 보정 목록 누락(V-A2-5 · V-B2-9 · V-B2-12)
- §4-2에 bff-api.md :31(「→ `jt_session` 설정 →」 · 「`jt_session`의 `issued_at`」) · :33(「`jt_session`의 refresh 토큰」)의 이름 치환을 더한다(T089 커밋).
- ⑤ 행에 `contracts/pod-template.md:78`(런타임 계약 인증 행 ⑦ — `revoked:sid` · `revoked:sub` 정규 꼴)을 더한다.

### N-7 거부 규칙의 정밀도(V-A2-6)
- `expression` issue는 텍스트 노드마다 하나이고 `line` = 노드 시작 줄이다.
- issues 순서는 로더 계약이다: 파일 경로(Ordinal)순 → 문서 순.
- 울타리 · YAML 단계가 실패한 파일에는 본문 규칙을 돌리지 않는다(그 파일의 issue는 프런트매터 하나). `---js` 픽스처의 정확 비교가 흐름 매핑 `{ … }`으로 깨지지 않게 한다.
- `{` · `}` 검사는 `text` 노드에 더해 image `alt`와 link · image · definition `title` 문자열도 본다(「remark-mdx로 옮겨도 실행될 글자 0」과 맞춘다).
- §0-6의 `{}` 거부 근거 줄을 decisions-controller.md:115(content.md 한 줄)로 고친다.
- VD-T086-3 · ld-1의 코드 스팬 예시에 001:26 `{spec,plan,tasks}` · 002:29 `<메시지>` · 002:32 `<guid>` · 002:35 `{ . $body }`를 더한다(모두 코드 스팬 안 — 통과 기대).

### N-8 return_to 재검증과 ASCII 규칙의 자리(V-A2-7 · V-B2-11)
- C27: callback은 봉인 값을 다시 디코딩하지 않고 ① · ③ · ⑤로 판정한다. G3-2에 봉인 `/%2F/evil.com` → 302 같은 값 사례를 둔다.
- 출력 가능 ASCII 규칙은 return_to만의 규칙으로 옮긴다(공유 정의 「같은 origin 경로」 — bff-api.md :40 · web.md :25 — 에 넣지 않는다). 프레임워크 리디렉션 Location(프록시 끝 슬래시 308)은 이 규칙 밖이다.
- T091 · T092 인계: 클라이언트는 `encodeURIComponent(pathname + search + hash)`를 싣는다.

### N-9 pkce 쿠키 = `__Host-jt_pkce; Path=/`(V-A2-8 · V-B2-3 — B-6 정밀화 · 컨트롤러 결정)
- `__Secure-` 접두는 `Domain`을 막지 않는다. 형제 호스트(PR 코드가 도는 `preview.` 등)가 `Domain=joshuatech.dev; Path=/api/auth/callback`으로 같은 이름을 심으면 login CSRF · 세션 고정(공격자 봉인 쿠키 + 공격자 `code` → 피해자가 공격자 계정으로 로그인 — 추론 · 창 300 s)이 남는다.
- B-6 결정의 뜻(형제 서브도메인의 쿠키 끼워 넣기를 브라우저가 막는다)을 pkce 쿠키에도 지키려고 이름을 `__Host-jt_pkce`, 속성을 `Secure; HttpOnly; SameSite=Lax; Path=/; Max-Age=300`으로 한다.
  - 대가: 최대 300 s 동안 같은 origin 요청마다 실린다(HttpOnly · 봉인 · 로그 0 — D9 로그 규칙).
  - 사용자에게는 확정 보고에서 한 줄로 알린다.
- callback에 같은 이름 pkce 쿠키가 둘 이상 오면 `invalid_state` + 삭제다. G3-1에 사례를 둔다(C5 「같은 이름 둘 이상 = 무효」를 pkce에도).
- 본문의 `__Secure-jt_pkce` · `Path=/api/auth/callback`은 모두 이 꼴로 읽는다. §0-7 · C4 · C28 · G1–G4 · §4-1 · §4-2 · web.md 초안 · 〔86-30〕을 함께 고친다.

### N-10 클라이언트 규약 1 = 완료를 기다린다(V-A2-9)
- 「진행 중인 BFF fetch를 끝내거나 취소한다」를 「완료를 기다린다」로 좁힌다.
- 까닭: 응답 헤더 전에 취소하면 서버가 이미 회전한 새 쿠키가 버려진다. 그러면 logout 내부 refresh가 옛 refresh로 `invalid_grant` → 503(기록 0)이 된다.

### N-11 UD-7c 질문 자료 — (가′)의 대가 둘(V-B2-4)
- ① 기록되지 못한 로그아웃(503)의 안전망이 사라진다.
  - 필터가 없거나 (나′)이면 그 `logout` 이벤트가 사용자 단위로 기록돼 남은 복사 쿠키 세션까지 닫힌다.
  - (가′)는 그 이벤트를 거르므로 503 갈래의 세션이 기록 없이 30 d까지 남는다(§5-1-10). 이 갈래에서는 (나′)가 더 안전하다.
  - 보완: 규약 3 안내와 「모든 기기」.
- ② logout CSRF 증폭.
  - VD-T089-7 합격선 「확인 화면 0」은 OIDC RP-Initiated Logout §2의 「MUST ask」가 막는 원치 않는 로그아웃을 내려놓는 선택이다.
  - brand 무효화 흐름이 이미 GET 이동만으로 로그아웃하므로(e2e/README.md:60) 새 표면은 아니다.
  - 그러나 UD-4 B 웹훅이 켜지면, 아무 사이트가 유도한 로그아웃이 사용자 단위 폐기(모든 기기 · 두 env)로 커진다. (가′)는 end-session 쪽 증폭만 없앤다 — brand 흐름 쪽은 남는다.
- 권고 (가′)는 유지한다. ① · ②를 §0-2-3 표와 §5-1에 적고, UD-4와 함께 여쭐 자료로 쓴다.

### N-12 클라이언트 규약 3 = 이동 전 안내(V-B2-5)
- 「204가 아니면 이동 전에 안내하고, 사용자가 확인한 뒤 `x-end-session-url`로 이동한다. 착지 표식(`sessionStorage`)은 보조다.」
- VD-T089-10 「어긋나면」 칸에 「착지 리디렉션 0이면 안내는 이동 전 안내만으로 성립한다」를 더한다.

### N-13 `sources[].path`는 저장소 상대 경로 꼴만(V-B2-6)
- `path`는 `^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$` 꼴이고 `.` · `..` 세그먼트는 0이다(`:` 0 — 스킴 · 드라이브 문자 · 절대 URL이 통과하지 못한다).
- ld-10에 `javascript:alert(1)` · `https://evil.example/x` 경로 사례를 더한다.
- content.md 새 주석(:22)과 §4-2 초안을 이 꼴로 고친다.
- T091 인계: `path`는 고정 origin(GitHub blob) 링크나 글자로만 그린다.

### N-14 static-gate pull API(V-B2-7)
- ANYWHERE에 `requests(` · `consoleMessages(` · `pageErrors(` · `existingResponse(`를 더하고 PLANTED 넷을 둔다(키 집합 검사와 맞춘다).
- D10-5의 「`page.requests()` 0」을 이 규칙이 집행한다.
- 근거: Playwright 1.65.1 types.d.ts(리스너와 `response()`의 pull 꼴).

### N-15 문구 · 사례(V-B2-12)
- G3-4 「→ 503 · 쿠키 0」 → 「세션 쿠키 0 · pkce 삭제」.
- G11-12 적대 헤더에 `host` · `forwarded`를 더한다(「원천 = 요청 URL origin뿐」을 더 좁게 고정).

### N-16 `revoked:sub` 값도 정규 꼴로 판독(r2 열린 항목 1)
- ⑤ 조각에 함께 넣는다: `revoked:sub` · `revoked:sid` · sid 하한 값 모두 session_floor와 같은 정규 꼴(ASCII 숫자 1–19자)로 판독하고, 밖이면 503(닫힌 쪽).
  - 같은 함수 안의 판독 규칙이 하나가 된다.
  - 쓰는 쪽은 `str(nbf)`뿐이라 정상 경로 영향은 0이다.
- ac-25에 sub 사례(`-5` · 공백 · `1_000`)를 더한다. denylist.md:28 · django-pod.md:45(+ KR) · pod-template.md:78 문장을 함께 고친다.

### N-17 VD-T089-12 뒤 logout `invalid_grant` 갈래(r2 열린 항목 2)
- T081에서 재사용 감지가 토큰 가족 폐기로 확인되면 204로 되돌리고, 남는 창(≤ 교환 캐시 270 s)을 기록한다. 아니면 503을 유지한다.

### N-18 T086-e의 ADR 처리(r2 열린 항목 3)
- 새 ADR은 두지 않는다. ADR 0004 부록 D19는 「정본 = git MDX · 자체 로더 · zod · 다국어 · 캐시 · remark/rehype」를 정할 뿐 MDX 실행 기능을 요구하지 않는다.
- 순수 마크다운 파싱은 〔86-29〕(편차 후보)로만 기록한다.

### N-19 자리값 쿠키 이름(r2 열린 항목 4)
- `e2e/needle/*` · `e2e/selftest/http.test.ts` · `e2e/selftest/scan-needle.test.ts`의 `jt_session=`은 계약 이름을 단언하지 않는 자리값이라 그대로 둔다(바꾸면 needle 재실행 비용).
- 계약 이름을 쓰는 T079 상수(`e2e/lib/bff.ts:56–57` · `selftest/bff.test.ts`)는 B-6 · N-9 이름으로 바꾼다(빌더 ③ · T087 커밋).

### 확정 뒤 사용자 질문(시점) — §5-3 그대로
- UD-7c: T080 블루프린트 전 · UD-4와 함께 — N-11 자료 포함.
- T090 착수 때: 로더 새 의존 설치 승인.
- T091 전 곁가지 셋: Next · OpenNext 판(peer `>=16.4.5`) · Workers 압축 한도 폐지 · OpenNext #1334.
- T086-a 노트 검토(T091 ~ T093 전) · UD-1(⑤ 발행) · T081 VD 결과에 따른 것 · T085 D16.

## 정정 노트

### 2026-11-26 — 빌드 r0 · 수정 r1 · r2 반영
정본 = build-notes 「## T086 · T087 · T088 · T089」 · 보고 `.superpowers/t086/{build,reviews}/`(빌드 r0 `wf_af201538-c48` · 리뷰 A · B · C · D · 수정 r1 `wf_1ad3683a-0cd` → 재개 `wf_7d09bb68-946` · 검증 V1 · V2 · 수정 r2 G1 · G2) · 컨트롤러 결정 `.superpowers/t086/decisions-controller.md`. 결정 본문은 그대로이고, 실물과 다른 점과 인계만 적는다(설계 자리는 절 · 사례 id로 가리키고, 줄 번호는 이 확정본 기준 보조다).

1. **§1-4 〔86-18〕 — 「본문 5절 검증」은 T090 TDD에 넣지 않는다(T090 전 필수)**(리뷰 A-1 · F1 ④a · V1 참고)
   - 결정: `getCollection`은 본문 절(content.md:28의 다섯 절 · 순서 · 비어 있지 않음)을 검증하지 않는다. 다섯 절은 사람 검토와 /finish Study contract가 맡고, 실제 노트 2편은 ld-1(h2 다섯 · 순서 · id)이 지킨다. 정본 = `loader.test.ts` 머리 주석(본문 절 줄).
   - **T090은 이것을 로더에 넣지 않는다 — TDD 사례도 0.** T090 지시문에 이 항목을 싣는다(V1: 이 노트가 없으면 T090 빌더가 〔86-18〕 문구대로 절 검증을 TDD로 넣는다).
   - 까닭: 픽스처는 「짧은 노트」(D4)라 다섯 절을 가진 파일이 0이다. 로더 오류로 넣으면 issues 정확 비교 · 정상 반환 사례 대부분이 다른 이유로 빨강이 돼, T090이 승인된 T086 시험을 고치거나 요구를 버려야 한다(변이 `sections` — 로더가 절을 검증 — 가 T086 사례 대부분을 실패시킨다 · F1 실측). FR-029(spec:272)의 zod 항목과 tasks.md T090 문면에도 본문 절은 없다.
   - 〔86-18〕의 나머지(하이라이트 · 1회 스캔 캐시 · JSON Schema export · 본문 산출 필드)는 그대로 T090 TDD다. /finish가 〔86-18〕을 report 「편차」로 옮길 때 이 노트로 읽는다.
2. **D4 API · 스키마 · ld-4 · ld-10 — 날짜 = `'YYYY-MM-DD'` 문자열 하나 · `file` 갈래 code `name` · `ko-missing`**(리뷰 A-7 · F1 ④b · ④g · V1-2 → 수정 r2 G2)
   - `data.pubDate` · `data.updatedDate` = `'YYYY-MM-DD'` 문자열 하나(Date 0). 입력은 따옴표 없는 날짜와 따옴표 문자열을 모두 받고, 출력은 같은 문자열이다 — T091 `time[datetime]`과 h-2가 이 값을 그대로 쓴다. T090 인계: YAML 1.2 core 기본 스키마(따옴표 없는 날짜 = 문자열)로 읽고 Date로 바꾸지 않는다.
   - D4는 `file` 갈래 code로 `encoding`(파이프라인 1)만 정했다 → 둘을 더한다: `name` = study 파일 이름 규칙 위반 `(그 파일, file, name)`(ld-10 「번호 없는 파일 이름」) · `ko-missing` = ko 파일이 없는 slug의 **변형 파일마다** `(변형 파일, file, ko-missing)`. D4 ld-4 행 「오류 · 그 slug」(:326) → 이 정확 triple. 빌드 r0 참조 구현의 `(lang, ko_missing)`은 버렸다.
   - 리뷰는 「시험은 그대로 둬도 된다」였지만, 주석만 두면 변이(`date-object` · `ld4-lang` · `name-code`)가 살아남아 시험으로도 고정했다(ld-1 · ld-7 날짜 단언 · ld-4 정확 triple · ld-10 사례 +1). 빌드 r0 보고 ① ③-4 · ④a · ④d는 이것으로 닫힌다.
   - (수정 r2 G2 — V1-2) 「변형 파일마다」를 시험으로 고정했다: 파일 이름 규칙이 `(en|ja)`이므로 ld-4 픽스처에 `001-orphan.ja.mdx`를 더하고 en · ja 두 triple을 정확히 기대한다(주석을 좁히는 길은 버렸다). 픽스처 디렉터리 이름은 `en-only` → `ko-missing`(그 디렉터리를 쓰는 사례는 ld-4 하나 — 이름이 거짓이 됐다) · ld-4 바늘 넷(두 변형의 title · description). 변이 `v-komissing-per-slug`(첫 변형에만 issue)가 잡힌다. 검증 V3의 변이 `v3-name-no-ja`(파일 이름 규칙에서 ja를 뺌)도 이제 잡힌다 — r1 픽스처에는 `.ja.mdx`가 0이라 규칙의 ja 쪽은 이 픽스처가 처음 고정한다. 수치는 build-notes.
   - 시험 수 · 끝 줄 수치는 설계에 적지 않는다(D12에도 수치가 없다 — F1 ④g). 정본 = build-notes.
3. **§7 N-2 「입력 값 0」 — 범위 = 오류 객체 전체 · `cause` 0**(리뷰 B-1 · F1 ④c · ④f)
   - N-2 「`ContentValidationError` 메시지와 issues에는 입력 값이 없다 … ld-10 · ld-13에 단언」 → 「오류 객체 전체 — message · issues · `stack` · `util.inspect` 출력(`cause` · 자기 속성 포함) — 에 입력 값이 없다」. ld-10 · ld-13 · ld-14가 이 넷을 바늘 대상으로 보고, `cause === undefined`와 자기 속성 키 ⊆ {`issues`, `name`, `message`, `stack`}을 단언한다(같음이 아니라 부분 집합 — private 필드 + 접근자 같은 정상 구현은 막지 않는다). 정본 = 머리 주석(입력 값 0 줄).
   - 까닭: Node(잡히지 않은 오류)와 vitest 출력은 `[cause]` · `Caused by`를 찍는다. `new ContentValidationError(issues, { cause: yamlError })` 꼴이면 YAML 오류에 든 원문 줄이 공개 CI 로그로 나간다 — r0 시험은 이 변이를 전부 통과시켰다(리뷰 B 실측).
   - T090 인계: Error 생성자에 `{ cause }`를 넘기지 않는다 · YAML · TextDecoder 오류 객체를 싣지 않는다 · 자기 속성은 위 넷 안에서만.
   - 바늘 주의(F1 ④f): 바늘 대상에 stack · inspect 출력이 들어갔으므로, 새 바늘은 파일 경로 · 스택 프레임 글자와 겹치지 않는 값만 쓴다(겹치면 거짓 빨강).
4. **D4 ld-13 · D12 — 중첩 컨테이너 여섯 행 · 함정 ⓕ**(리뷰 B-4 · F1 ④d)
   - ld-13 금지 사례에 중첩 픽스처 여섯(`body-rules/study/022`–`027`)을 더한다: 목록 항목 `- [x](javascript:alert(1))` → `unsafe-url` · 인용 `> <b>x</b>` → `raw-html` 둘 · 표 칸 `| a | {x} |` → `expression` · 헤딩 `## {y}` → `expression` · 링크 글자 `[{z}](./a)` → `expression` · 각주 정의 `[^1]: <i>x</i>` → `raw-html` 둘. 거부 플러그인은 트리 전체를 돈다.
   - `raw-html`은 html 노드마다 하나다 — 글줄 안의 여는 · 닫는 태그는 각각 하나(`<b>x</b>` · `<i>x</i>`는 CommonMark 유형 7 html 블록 조건 — 여는 태그 뒤 공백만 — 을 채우지 않아 글줄 html 둘). 그래서 023 · 027은 issue가 둘씩이다.
   - D12 T086 행에 ⓕ를 더한다: 「최상위 children(+ 문단 글줄)만 도는 거부 플러그인 → ld-13 금지 passed 0」. 컨테이너를 하나씩 건너뛰는 변이 여섯도 각자 자기 픽스처 줄만 빠뜨려 잡힌다.
5. **§3 VD-T086-3 · 4 확장 — 실물 remark 대조는 T090 설치 직후 첫 단계**(리뷰 C-3 · F1 ④e)
   - ld-13(줄 · 개수 정확) · ld-8 · ld-1의 「참조 구현 통과」는 손으로 쓴 CommonMark 부분 모형으로만 증명됐다(저장소에 remark · micromark 0 · 설치 0). T090은 로더 의존 설치 직후 첫 단계로 이 셋을 실물 remark-parse · remark-gfm · remark-frontmatter 파이프라인에 돌린다.
   - VD-T086-3 · 4의 범위에 「ld-13 줄 · 개수」와 모형으로만 확인한 꼴을 더한다: html 블록 `<script>`(유형 1) · `<iframe>`(유형 6) · `<!-- -->`(유형 2) · 단독 `<br>`(유형 7) · `<Callout />` = 글줄 html 하나 · 줄바꿈 든 문단 = text 노드 하나(007 → 줄 13) · 정의 줄만 `unsafe-url`(013 → 15) · 문자 참조 · 탭은 해석 뒤 값 · (r1 중첩) 인용 · 각주 정의 > 문단 > html 둘(023 → 13 · 027 → 15) · 표 칸 text 줄 = 그 행(024 → 15) · 링크 글자 `{z}` = link의 text 자식(026 → 13) · 목록 둘째 항목의 링크(022 → 14).
   - line은 프런트매터를 포함한 파일 기준이다 — T090이 프런트매터를 잘라 내고 파싱하면 위치를 보정한다.
   - 기대값이 실물과 다르면 시험을 조용히 고치지 않고 이 「정정 노트」에 남긴다(VD-T086-4 「어긋나면」 칸과 같은 규율).
6. **§4-1 T086 행 밖 — data-model.md §11 `sources` 행 · 덩어리 단위 스테이징**(FD ④-a · 리뷰 A-9)
   - data-model.md :245 `sources` 행을 N-13 꼴(`path` = `^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$` · `.` · `..` 세그먼트 0 · `url` = http/https)로 고쳐 이 커밋에 넣는다(표식 「T086 보정 2026-11-24 · N-13」). §4-1 T086 행에는 content.md + KR만 있었다.
   - 같은 파일에 ⑤ 몫(:71 값 꼴 줄 — 리뷰 D-8 · r0 ⑤ 자리 아홉)이 함께 있어, 파일 이름 단위 스테이징(D14)이면 ⑤ 내용이 이 커밋에 딸려 든다 → 이 파일만 덩어리 단위로 나눈다: `git diff` → 덩어리를 거른 패치 → `git apply --cached`(대화형 `-p` 0). :245 = 이 커밋 · 나머지 = ⑤ 커밋.
