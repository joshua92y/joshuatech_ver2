# tests/platform/identity.tests.ps1 — US4 플랫폼 신원 단언: Authentik 공개 경로 · Access 경계 · RFC 8693 교환 판정 · OpenFGA 검사 Job 로그 (T078, test-first)
# Run: (Git Bash) chcp.com 65001 >/dev/null; KUBECONFIG=<agent-view 토큰 kubeconfig> pwsh -NoProfile -File tests/platform/identity.tests.ps1
#      (PowerShell) chcp.com 65001 > $null; $env:KUBECONFIG=<agent-view 토큰 kubeconfig>; pwsh -NoProfile -File tests/platform/identity.tests.ps1
#      (보통은 tests/platform/run-platform-tests.ps1이 agent-view 신원 게이트를 지난 뒤 이 파일을 실행한다. 라이브 빨강 관찰은 운영자 창에서 컨트롤러가 한다
#       — 설계 D9: 빌더는 오프라인 시험(짝 하네스 tests/scripts/identity-tests.tests.ps1)만 돌린다.)
# Exit 0 = 실패 0(SKIP 허용), 1 = 실패 ≥ 1. 외부 프레임워크 없음. 자체 완결(공용 헬퍼 없음 — 러너는 flat 발견): 헬퍼는
#   tests/platform/data.tests.ps1(Clip · ClusterAssert · Eq/SortOrd/Contains/StartsOrd/EndsOrd/IndexOrd · First-Line · Prop/PropPath/PropArr/Items/Name/Ns ·
#   Mask-Text · Remove-WithRetry · Invoke-Native · Invoke-Kubectl · ConvertFrom-JsonStrict · Get-KubeList · Get-KubeOne · Describe-LookupError ·
#   Get-ListCached · Test-JobLog · 게이트 gate-1..3)와 tests/platform/ingress.tests.ps1(Test-Group · Test-AccessLocation)에서 같은 이름 · 같은 동작으로
#   복사했다(임시 파일 접두만 identity-tests-). 바뀐 것 둘: Pass/Fail/Skip 줄 꼴이 설계 D8 꼴이고, FAIL 사유 앞에 D5 분류 접두를 붙인다(아래 「출력」).
#   stdout이 파이프 · 파일이면 콘솔 코드 페이지와 무관하게 UTF-8로 쓰고 종료 때 되돌린다(tests/platform/kafka.tests.ps1과 같은 방식 — SKIP 문구가 한국어다).
# 출력: 단언마다 `PASS|FAIL|SKIP <id> -- <근거>` 한 줄(기계 판독 부분 = ' -- ' 앞, ASCII — 설계 D5 경계), 마지막 줄 `N passed, N failed, N skipped`.
#   FAIL 근거는 D5 분류 접두로 시작한다: [gate] 구현 부재(Traefik 404 서명 전체 일치 · Ingress 부재 · Job 부재 · Job이 새 id를 아직 내지 않음 —
#   올바른 이유의 빨강) · [env] 실행 환경(클러스터 게이트 · curl 도구 · 네트워크 curl exit ≠ 0 · 오리진 5xx — 빨강 증거 아님) · [guard] 안전 장치(curl env
#   가드 — 아래 「HTTP」 · 빨강 증거 아님) · [product] 응답은 왔지만 계약과 다르다(빨강 단계에서 나오면 조사). SKIP 문구는 둘뿐이다: 「자격 블록 전용」
#   (xchg-1 · 2) · 「운영자 수동」(man-1 · 2). 소유 과제 게이트(tasks.md를 읽어 SKIP하는 길)는 없다(설계 D8 ⑦ — cluster.tests.ps1:25–27과 달리).
#
# 설계 정본: specs/003-platform-foundation/design/t077-design.md §1-2 · D5 · D8 · D9 · D10(T078 몫). tasks.md T078 문면과 다른 점은 report 편차 후보
#   〔77-2〕(admin. 무헤더 403 → 302 · m2m 무헤더 401) · 〔77-6〕(교환은 검토된 자격 블록 — 이 파일은 판정 함수 · 도달 · SKIP 줄) · 〔77-12〕(OpenFGA
#   user:<sub> → 합성 주체 — T082) · 〔77-13〕(루트 /.well-known/* 글롭 → 후보 상수 · T080 실측)이다.
#
# 접근 계약(contracts/hostnames-and-access.md §에이전트 자격 · .claude/rules/infra.md):
#   - 클러스터: `$env:KUBECONFIG`(SA agent-view 8h 토큰)로만. 모든 kubectl 호출에 --kubeconfig · --request-timeout=30s를 명시한다. 동사는 get · logs ·
#     auth whoami뿐이다. 게이트 gate-1..3이 실패하면 kubectl 단언(ing-1 · fga-1..4)만 그 사유로 [env] FAIL이고 HTTP 단언은 계속 돈다(acc-1은 ing-1 짝이라
#     그 경우 [env] — 아래). Secret · Vault · 자격 파일은 읽지 않는다. Job 로그의 EVIDENCE: 줄 · RESULT 근거 글자는 옮기지 않는다.
#   - HTTP: curl만 쓴다. 실행 파일 = `Get-Command curl -CommandType Application`의 첫 해석 경로(한 번 정한다). 형식 필터 없는 `Get-Command curl`의 첫 해석이
#     Application이 아니면(함수 · 별칭 · 스크립트 가림) tool-1 FAIL. 판 ≥ 7.84.0(%header{} write-out)이어야 한다(판 검사도 같은 경로). 호출 꼴(글자 고정):
#       <curl> -q -s -S --max-time 20 --proto =https -o <임시 본문> -w @<임시 형식 파일> <url>
#     형식 파일 = `%{http_code}\n%{content_type}\n%{size_download}\n%header{location}\n%header{cf-cache-status}\n`(argv에 %가 없다 — .cmd 심을 지나도
#     글자가 바뀌지 않는다). GET만 · 리다이렉트 미추적 · 자격 헤더 0(-H · -u · -b · -K 없음) · -q로 .curlrc 무시 · https만. Location은 scheme://host/path만
#     출력한다(쿼리 · 조각 0). 본문은 판정 키만 읽고 출력하지 않는다(값도 — issuer는 상수와 같은지만). 임시 파일(identity-tests-body-* · -fmt-* · -stderr-*)은
#     finally에서 지운다 — %TEMP%\identity-tests-* 잔존 0. curl 종료 코드 ≠ 0은 그 단언의 [env] FAIL(6 · 7 · 28 … 사유 표시). 출력은 Mask-Text로 가린다.
#   - curl env 가드(r1 — B-9 · T077 globalSetup ①과 같은 이름 · 같은 접두): 이름이 _PROXY로 끝나는 env(대소문자 무관 — http_proxy · HTTPS_PROXY · ALL_PROXY ·
#     NO_PROXY …) · SSLKEYLOGFILE · CURL_CA_BUNDLE · SSL_CERT_FILE · SSL_CERT_DIR가 하나라도 있으면 HTTP 단언은 curl을 부르지 않고 `[guard] curl-env-not-allowed
#     <정렬된 이름>`으로 FAIL한다(env 이름만 본다 — 값은 읽지도 출력하지도 않는다 · tool-1은 판 검사뿐이라 그대로 · argv 글자 고정도 그대로). 프록시 · CA 묶음 ·
#     세션 키 기록이 끼어든 응답은 증거가 아니고, 자격을 싣는 블록도 같은 규칙을 쓴다. 라이브 창에 이 이름이 있으면 지우고 다시 돈다.
#   - 교환(xchg-*): 자동 발견 하네스에는 agent-view 밖 자격이 없다(tester.md · 설계 D8 ⑤). xchg-0은 토큰 엔드포인트 도달만(무자격 GET — POST로 두드리지
#     않는다: Reputation). 판정 함수 Test-ExchangeClaims · Test-ExchangeRejection은 이 파일에 두고 라이브에서는 부르지 않는다(SKIP xchg-1 · 2) —
#     검토된 자격 블록(T077-b · S-01 개정 · 설계 §5-1 관문 뒤)이 이 함수의 바이트 사본으로 판정한다. JWT 값 · sub · tenant_id 값은 반환 문구에 싣지 않는다.
#
# 단언 ↔ T078 항목(§1-2 — 「오늘 기대」= 2026-11-23 설계 확정 시점, 라이브는 운영자 창에서 컨트롤러가 관찰 · 줄마다 대조):
#   id         단언                                                                        오늘 기대                                            초록
#   gate-1..3  kubectl 있음 · KUBECONFIG 단일 파일 · whoami = agent-view                    PASS                                                 —
#   tool-1     curl 첫 해석이 Application · 그 경로의 판 ≥ 7.84.0                           PASS                                                 —
#   ing-1      ns identity Ingress에 rules[].host auth.joshuatech.dev                       FAIL [gate] until T080 (no Ingress for …)            T080
#   acc-1      GET https://auth.joshuatech.dev/if/admin/ 무헤더 → 302 + Location(팀 도메인 joshua-tech.cloudflareaccess.com · 경로 접두 /cdn-cgi/access/login/)
#              또는 403 text/html · Location 없음, 그리고 ing-1 PASS(엣지 302만으로는 빈 PASS — ingress.tests.ps1:24–26)
#                                                                                           FAIL [gate] 302 is edge-only (Access app auth-admin — T011); origin route absent — until T080
#   acc-2      GET https://admin.joshuatech.dev/identity-admin/admin/ 무헤더 → 302 + 같은 Location 꼴   PASS(T075 L15 · 〔77-2〕)         —
#   acc-3      GET https://identity-m2m-prod.joshuatech.dev/health 무헤더 → 401 · text/html · Location 없음(계약 C11)   PASS(〔77-2〕)       —
#   pub-1      /api/v3/root/config/ → 200 · application/json · 판정 키 capabilities(추론 — VD-T080-a)   FAIL [gate] Traefik 404 (no router) — until T080   T080
#   pub-2      /api/v3/flows/executor/default-authentication-flow/ → 200 · JSON · component(slug 추론 — research.md AUTHENTIK-D6)   같음   T080 · T081
#   pub-3      /application/o/identity-admin/.well-known/openid-configuration → 200 · JSON · issuer = https://auth.joshuatech.dev/application/o/identity-admin/ ·
#              jwks_uri 있음                                                                같음                                                 T080 · T081
#   pub-4      /application/o/identity-admin/jwks/ → 200 · JSON keys ≥ 1                     같음                                                 T081
#   pub-5      루트 /.well-known/ 후보 상수 $WellKnownRootPath(RFC 8414 §3 꼴 — 추론 · VD-T080-a가 끝 / 없음 · 있음을 함께 잰다) → 200 · application/json · issuer
#                                                                                           같음                                                 T080(서빙 대상이 없으면 T080 정정 노트로 삭제 — 〔77-13〕)
#   xchg-0     GET /application/o/token/ → Authentik의 405 · Location 없음(POST 안 함)      FAIL [gate] Traefik 404 (no router) — until T080      T080
#   xchg-1     교환 판정(Test-ExchangeClaims)                                               SKIP 자격 블록 전용 — T077-b · S-01 개정(T080–T081)   자격 블록
#   xchg-2     audience=portfolio-core 거부(Test-ExchangeRejection · invalid_target — 실제 코드 VD-T081-d)   같음                         자격 블록
#   fga-1 · fga-2 · fga-3 · fga-4 = Job jt-dev/authz-assert 로그의 새 id 넷 check-member-allowed · check-owner-allowed · cross-tenant-member-false · cross-tenant-owner-false
#              (Test-JobLog 꼴: id마다 RESULT 정확히 1 · 전부 PASS · SUMMARY 수 일치 · 추적 밖 FAIL도 문제 · --tail=50 · EVIDENCE: 비전재 — 넷 중 하나라도 문제면
#              넷 다 FAIL이고 줄마다 자기 id 상태를 앞에 적는다; 합성 주체 · 튜플 = T082와의 계약 · VD-T082-a)
#                                                                                           FAIL [gate] Job jt-dev/authz-assert absent — rendered with the tests Application after T082 (T085)
#                                                                                                                                                T082 + 렌더
#   man-1      argocd --sso 로그인(R30 — tester 자격으로 자동화하지 않는다)                  SKIP 운영자 수동 + 스크린샷(R30)                     T084 · T085
#   man-2      Authentik 관리 API 접근(R30)                                                  같음                                                 T084 · T085
#   오늘 기대 끝 줄(추론): 6 passed, 12 failed, 4 skipped · exit 1. 이 표와 다른 줄(예: gate 실패로 ing-1이 [env] cluster unavailable · curl env 가드로 HTTP
#   9줄이 [guard])은 「잘못된 이유의 빨강」이라 증거로 쓰지 않는다(설계 D9). 단언 수 22 = gate 3 + tool 1 + ing 1 + acc 3 + pub 5 + xchg 3 + fga 4 + man 2.
#
# 판정 세부:
#   - [gate] Traefik 404는 서명 전체가 맞을 때만이다: 404 · content-type 정확히 `text/plain; charset=utf-8` · 본문 19 B(write-out size_download도 19) ·
#     본문 sha256 b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793(t076-design.md D10 기준값) · cf-cache-status ≠ HIT. 하나라도 어긋난 404는
#     [product](조사 — [gate] 아님). 5xx는 [env] origin(빨강 증거 아님). 공개 200은 미디어 타입(application/json) + 구조 키를 함께 본다 — text/html 200 ·
#     JSON 배열 루트 · 키 없음 · 빈 문자열은 FAIL. 3xx는 따라가지 않고 FAIL([product], Location은 안전 꼴).
#   - acc-1: ing-1을 읽지 못했으면(게이트 · 조회 실패) [env] — origin route unknown. ing-1 FAIL(Ingress 없음)이면 [gate] — 엣지 응답만으로는 빈 PASS다.
#   - fga: Job 없음 → [gate](T082 + 렌더). Job은 있는데 문제가 「$FgaPendingIds 가운데 RESULT 줄이 없는 id」뿐이면 [gate] until T082. 그 밖의 문제는
#     [product]. Job 조회 · 로그 조회 실패는 [env]. T082가 Job에 새 id를 더하면 $FgaPendingIds = @()로 비운다(data.tests.ps1 $jobPendingIds 선례).
#   - 교환 판정(라이브 미호출): aud = identity-admin(문자열 또는 원소 하나 배열) · tenant_id 정규 소문자 uuid · exp − iat = 300 · $Vd1Option 'B'(기본)면 act 유무
#     무관 · 'A'면 act.sub = web-bff client($ExchangeActSub — 추론, VD-1이 A로 확정되면 T081이 실측 값으로) · iss는 INFO. 거부 = 400 · error = invalid_target.
#
# 검증 후 결정(설계 §3) — 이 파일의 상수가 기대는 것: VD-T077-2(/if/admin/ 무헤더 302 또는 403 꼴) · VD-T080-a(root config 키 · executor JSON · issuer · JWKS ·
#   토큰 GET 코드 · 루트 /.well-known/ 후보) · VD-T081-a(login slug) · VD-T081-d(거부 오류 코드) · VD-T082-a(authz-assert 새 id 넷 · 50줄 안) · VD-1(act).
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다
# stdout이 파이프·파일이면(단위 테스트 · 러너) 콘솔 코드 페이지와 무관하게 UTF-8로 쓴다 — 한국어 SKIP 문구 · — 가 '?'로 깨지지 않는다(대화형 콘솔은 그대로 —
#   라이브는 chcp.com 65001로 돈다). .NET의 OutputEncoding 설정은 콘솔 자체의 출력 코드 페이지를 바꾸고 프로세스가 끝난 뒤에도 남으므로 종료 때 원래 값으로
#   되돌린다(PowerShell.Exiting — 이벤트 액션 블록에서는 $script: 변수가 보이지 않아 $global: 을 쓴다; kafka.tests.ps1과 같다).
if ([Console]::IsOutputRedirected) {
    try {
        $global:identityTestsPrevConsoleEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { try { [Console]::OutputEncoding = $global:identityTestsPrevConsoleEncoding } catch { } }
    } catch { }
}
$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:clusterReason = $null      # $null = 게이트 통과; 문자열이면 모든 클러스터 단언이 그 사유로 FAIL
$script:kubectl = $null            # kubectl 실행 파일 경로(게이트 1)
$script:kubeconfig = $null         # $env:KUBECONFIG(게이트 2)
$script:cache = @{}                # Get-KubeList 성공 캐시
$script:listCache = @{}            # Get-ListCached — 실패까지 캐시
$script:curl = $null               # curl 실행 파일 경로(tool-1이 한 번 정한다)
$script:curlReason = 'tool-1 not evaluated'   # $null = tool-1 통과; 문자열이면 모든 HTTP 단언이 그 사유로 [env] FAIL
$script:curlEnvReason = '[guard] curl-env-not-allowed (env guard not evaluated)'   # $null = curl env 가드 통과(1b); 문자열이면 모든 HTTP 단언이 그 줄로 FAIL

# ---------- 계약 상수(contracts/hostnames-and-access.md · 설계 §1-2 · D8) ----------
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$AuthHost = 'auth.joshuatech.dev'
$AdminHost = 'admin.joshuatech.dev'
$M2mProdHost = 'identity-m2m-prod.joshuatech.dev'
$AccessLoginHost = 'joshua-tech.cloudflareaccess.com'   # Cloudflare Zero Trust 팀 도메인 — Location 호스트 정확 일치
$AccessLoginPathPrefix = '/cdn-cgi/access/login/'        # Access 로그인 경로 접두 — Location 경로 StartsWith(Ordinal)
$AuthAdminPath = '/if/admin/'                            # Access 앱 auth-admin은 /if/admin/*만 보호한다(T011)
$AdminPodPath = '/identity-admin/admin/'
$M2mHealthPath = '/health'
$RootConfigPath = '/api/v3/root/config/'
$RootConfigKey = 'capabilities'                          # 추론 — VD-T080-a
$LoginFlowSlug = 'default-authentication-flow'           # research.md AUTHENTIK-D6 · 추론 — VD-T081-a
$ExecutorPath = "/api/v3/flows/executor/$LoginFlowSlug/"
$OidcSlug = 'identity-admin'
$OidcConfigPath = "/application/o/$OidcSlug/.well-known/openid-configuration"
$JwksPath = "/application/o/$OidcSlug/jwks/"
$ExpectedIssuer = "https://$AuthHost/application/o/$OidcSlug/"
$WellKnownRootPath = '/.well-known/oauth-authorization-server/application/o/identity-admin'   # RFC 8414 §3 꼴 후보(issuer 끝 / 없음) — VD-T080-a
$TokenPath = '/application/o/token/'
$IdentityNs = 'identity'
$AssertJobNs = 'jt-dev'
$AssertJobName = 'authz-assert'
$FgaIds = @('check-member-allowed', 'check-owner-allowed', 'cross-tenant-member-false', 'cross-tenant-owner-false')
$FgaPendingIds = @($FgaIds)   # T082가 Job에 넷을 더하기 전 — T082가 비운다(머리 주석 「판정 세부」)
$FgaPendingNote = 'the Job does not emit this check id yet -- T082 adds the four check ids to the authz-assert Job'
$Traefik404Sha256 = 'b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793'   # '404 page not found' + LF (t076-design.md D10)
$Traefik404ContentType = 'text/plain; charset=utf-8'
$Traefik404Size = 19
$CurlMinVersion = [version]'7.84.0'                      # %header{} write-out
$CurlWriteOut = '%{http_code}\n%{content_type}\n%{size_download}\n%header{location}\n%header{cf-cache-status}\n'
$HttpTimeoutSec = 20
$CurlEnvGuardNames = @('SSLKEYLOGFILE', 'CURL_CA_BUNDLE', 'SSL_CERT_FILE', 'SSL_CERT_DIR')   # curl env 가드(r1 — B-9) — 이 넷 + 이름 끝 _PROXY(둘 다 대소문자 무관)
$Vd1Option = 'B'                                         # VD-1 — 'A'로 확정되면 act.sub 단언을 켠다(T081)
$ExchangeAudience = 'identity-admin'
$ExchangeLifetimeSec = 300
$ExchangeActSub = 'web-bff-dev'                          # 추론 — VD-1이 A로 확정되면 T081이 실측 값으로
$RejectedAudience = 'portfolio-core'
$RejectError = 'invalid_target'                          # RFC 8693 §2.2.2 — 실제 코드는 VD-T081-d
$AuthRouteTask = 'T080'
$AccessAppTask = 'T011'
$FgaJobTask = 'T082'
$FgaRenderTask = 'T085'
$SkipCredBlock = '자격 블록 전용 — T077-b · S-01 개정(T080–T081)'
$SkipManual = '운영자 수동 + 스크린샷(R30)'

# ---------- 결과 헬퍼(data.tests.ps1 복사 — 줄 꼴만 설계 D8) ----------
function Clip([string]$s, [int]$max = 400) {
    if ($null -eq $s) { return '' }
    $s = ($s -replace "`r`n", ' ') -replace "`n", ' '
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' } else { return $s }
}
function Pass([string]$id, [string]$detail, [int]$max = 400) { $script:pass++; Write-Host "PASS $id -- $(Clip $detail $max)" }
function Fail([string]$id, [string]$detail, [int]$max = 400) { $script:fail++; Write-Host "FAIL $id -- $(Clip $detail $max)" }
function Skip([string]$id, [string]$detail, [int]$max = 400) { $script:skip++; Write-Host "SKIP $id -- $(Clip $detail $max)" }

# 단언 그룹 격리(ingress.tests.ps1 복사) — 한 그룹의 예외가 나머지를 막지 않는다.
function Test-Group([string]$name, [scriptblock]$body) {
    try { . $body }
    catch { $script:fail++; Write-Host "FAIL $name -- [env] unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
}

# 클러스터 단언 래퍼: 게이트 실패면 사유와 함께 FAIL(fail closed). $body는 @('PASS'|'FAIL', detail)을 돌려준다. 예외는 FAIL이다.
function ClusterAssert([string]$id, [scriptblock]$body, [int]$clip = 400) {
    if ($null -ne $script:clusterReason) { Fail $id "[env] cluster unavailable ($script:clusterReason)" $clip; return }
    $status = 'FAIL'; $detail = ''
    try {
        $r = @(& $body)   # 마지막 두 원소가 (status, detail) — 본문의 우발적 파이프라인 출력이 앞에 섞여도 판정이 흔들리지 않는다
        if ($r.Count -lt 2) { throw "assertion body returned $($r.Count) value(s), expected (status, detail)" }
        $status = [string]$r[$r.Count - 2]; $detail = [string]$r[$r.Count - 1]
    }
    catch { $status = 'FAIL'; $detail = "[env] unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    switch ($status) {
        'PASS' { Pass $id $detail $clip }
        'SKIP' { Skip $id $detail $clip }
        default { Fail $id $detail $clip }
    }
}
# HTTP 단언 래퍼: tool-1이 실패했으면 curl을 부르지 않고 그 사유로 [env] FAIL, curl env 가드(1b)에 걸렸으면 curl을 부르지 않고 그 [guard] 줄로 FAIL.
#   나머지는 ClusterAssert와 같다.
function HttpAssert([string]$id, [scriptblock]$body, [int]$clip = 400) {
    if ($null -ne $script:curlReason) { Fail $id "[env] curl unusable (tool-1: $script:curlReason)" $clip; return }
    if ($null -ne $script:curlEnvReason) { Fail $id $script:curlEnvReason $clip; return }
    $status = 'FAIL'; $detail = ''
    try {
        $r = @(& $body)
        if ($r.Count -lt 2) { throw "assertion body returned $($r.Count) value(s), expected (status, detail)" }
        $status = [string]$r[$r.Count - 2]; $detail = [string]$r[$r.Count - 1]
    }
    catch { $status = 'FAIL'; $detail = "[env] unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    switch ($status) {
        'PASS' { Pass $id $detail $clip }
        'SKIP' { Skip $id $detail $clip }
        default { Fail $id $detail $clip }
    }
}

# ---------- 문자열 헬퍼(전부 ordinal — data.tests.ps1 복사) ----------
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function SortOrd($arr) {
    $l = [System.Collections.Generic.List[string]]::new()
    foreach ($x in @($arr)) { if ($null -ne $x) { $l.Add([string]$x) } }
    $l.Sort([StringComparer]::Ordinal)
    return @($l.ToArray())
}
function Contains($arr, [string]$v) { foreach ($x in @($arr)) { if (Eq "$x" $v) { return $true } }; return $false }
function StartsOrd([string]$s, [string]$prefix) { return ($null -ne $s) -and $s.StartsWith($prefix, [StringComparison]::Ordinal) }
function EndsOrd([string]$s, [string]$suffix) { return ($null -ne $s) -and $s.EndsWith($suffix, [StringComparison]::Ordinal) }
function IndexOrd([string]$s, [string]$sub) { if ($null -eq $s) { return -1 }; return $s.IndexOf($sub, [StringComparison]::Ordinal) }
# 첫 번째 비어 있지 않은 줄(오류 메시지의 첫 줄만 사유에 쓴다)
function First-Line([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    foreach ($l in @($s -split "`r?`n")) { if (-not [string]::IsNullOrWhiteSpace($l)) { return $l.Trim() } }
    return ''
}

# ---------- JSON 객체 접근(속성 이름 ordinal 정확 일치; 없으면 $null — data.tests.ps1 복사) ----------
function Prop($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) {
        foreach ($k in $obj.Keys) { if (Eq "$k" $name) { return $obj[$k] } }
        return $null
    }
    foreach ($p in $obj.PSObject.Properties) { if (Eq $p.Name $name) { return $p.Value } }
    return $null
}
function PropPath($obj, [string[]]$path) {
    $cur = $obj
    foreach ($n in $path) { $cur = Prop $cur $n; if ($null -eq $cur) { return $null } }
    return $cur
}
function PropArr($obj, [string[]]$path) { $v = PropPath $obj $path; if ($null -eq $v) { return @() }; return @($v) }
# 목록 모양 검사(fail closed): kind가 'List'로 끝나고 items가 JSON 배열인 객체만 받는다(data.tests.ps1 복사 — 반환은 언래핑된 배열, 호출 측은 @(Items …))
function Items($listObj) {
    $kind = [string](Prop $listObj 'kind')
    $hasItems = $false; $raw = $null
    if ($null -ne $listObj) { foreach ($p in $listObj.PSObject.Properties) { if (Eq $p.Name 'items') { $hasItems = $true; $raw = $p.Value } } }
    if (-not (EndsOrd $kind 'List') -or -not $hasItems -or -not ($raw -is [System.Collections.IList])) { throw "expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='$kind' items=$(if (-not $hasItems) { 'missing' } elseif ($null -eq $raw) { 'null' } else { $raw.GetType().Name })" }
    return @($raw)
}
function Name($obj) { return [string](PropPath $obj @('metadata', 'name')) }
function Ns($obj) { return [string](PropPath $obj @('metadata', 'namespace')) }
# 본문 필드 접근(이 파일): 함수 반환 언래핑 없이(원소 하나 배열이 스칼라로, 빈 배열이 $null로 풀리지 않게) 해시 @{ present; value }로 돌려준다.
#   JSON 객체(PSCustomObject)만 본다 — 배열 · 문자열 · $null이면 present = $false. 이름은 ordinal.
function Get-JsonField($obj, [string]$name) {
    $res = @{ present = $false; value = $null }
    if ($null -eq $obj -or -not ($obj -is [System.Management.Automation.PSCustomObject])) { return $res }
    foreach ($p in $obj.PSObject.Properties) { if (Eq $p.Name $name) { $res.present = $true; $res.value = $p.Value; break } }
    return $res
}

# 출력 마스킹(data.tests.ps1 복사): kubeconfig 경로·홈 디렉터리를 <KUBECONFIG>/~로 치환(ordinal; \ 와 / 두 표기 모두) — 개인 경로가 리포트에 남지 않게.
function Mask-Text([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return $s }
    $pairs = @()
    foreach ($kc in @($script:kubeconfig, $env:KUBECONFIG)) { if (-not [string]::IsNullOrWhiteSpace($kc)) { $pairs += , @($kc, '<KUBECONFIG>') } }
    foreach ($h in @($HOME, $env:USERPROFILE)) { if (-not [string]::IsNullOrWhiteSpace($h)) { $pairs += , @($h, '~') } }
    foreach ($p in $pairs) {
        $s = $s.Replace([string]$p[0], [string]$p[1], [StringComparison]::Ordinal)
        $s = $s.Replace(([string]$p[0]).Replace('\', '/'), [string]$p[1], [StringComparison]::Ordinal)
    }
    return $s
}
# 임시 파일 삭제(자식 프로세스가 핸들을 늦게 놓을 수 있어 3회 재시도)
function Remove-WithRetry([string[]]$paths) {
    foreach ($p in $paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        for ($i = 1; $i -le 3; $i++) {
            if (-not (Test-Path -LiteralPath $p)) { break }
            try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 300 }
        }
    }
}

# ---------- 네이티브 실행(stdout UTF-8 디코드; stderr는 임시 파일; 반환 전 경로 마스킹 — data.tests.ps1 복사, 접두 identity-tests-) ----------
function Invoke-Native([string]$exe, [string[]]$nativeArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('identity-tests-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $out = @(); $code = -1; $err = ''
    $prevEncoding = [Console]::OutputEncoding
    try {
        try {
            [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            $out = & $exe @nativeArgs 2> $errFile
            $code = $LASTEXITCODE
        } finally { [Console]::OutputEncoding = $prevEncoding }
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) } else { '' }
    } finally { Remove-WithRetry @($errFile) }
    return @{ out = (Mask-Text (@($out | ForEach-Object { "$_" }) -join "`n")); err = (Mask-Text $err.Trim()); code = $code }
}
# kubectl — 항상 --kubeconfig 명시(기본 kubeconfig로 흘러가지 않게) + 요청 타임아웃.
function Invoke-Kubectl([string[]]$kArgs) {
    return Invoke-Native $script:kubectl (@("--kubeconfig=$script:kubeconfig", '--request-timeout=30s') + @($kArgs))
}
function ConvertFrom-JsonStrict([string]$text, [string]$what) {
    if ([string]::IsNullOrWhiteSpace($text)) { throw "empty output from $what (expected JSON)" }
    try { return ($text | ConvertFrom-Json -Depth 64) }
    catch { throw "JSON parse failed for ${what}: $($_.Exception.Message)" }
}
# 리스트 조회(-o json). 실패는 예외(= FAIL).
function Get-KubeList([string[]]$kArgs) {
    $key = ($kArgs -join ' ')
    if ($script:cache.ContainsKey($key)) { return $script:cache[$key] }
    $r = Invoke-Kubectl (@($kArgs) + @('-o', 'json'))
    if ($r.code -ne 0) { throw "kubectl $key failed (exit $($r.code)): $($r.err)" }
    $obj = ConvertFrom-JsonStrict $r.out "kubectl $key"
    $script:cache[$key] = $obj
    return $obj
}
# 단일 리소스 조회 — 없으면 $null(--ignore-not-found), 다른 오류는 예외. 응답 kind가 $expectedKind가 아니면 예외(fail closed).
function Get-KubeOne([string]$ns, [string]$kind, [string]$name, [string]$expectedKind) {
    $kArgs = @('get', $kind, $name, '--ignore-not-found', '-o', 'json')
    if (-not [string]::IsNullOrEmpty($ns)) { $kArgs = @('-n', $ns) + $kArgs }
    $r = Invoke-Kubectl $kArgs
    if ($r.code -ne 0) { throw "kubectl get $kind/$name (ns '$ns') failed (exit $($r.code)): $($r.err)" }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return $null }
    $obj = ConvertFrom-JsonStrict $r.out "kubectl get $kind/$name"
    $got = [string](Prop $obj 'kind')
    if (-not (Eq $got $expectedKind)) { throw "kubectl get $kind/$name returned kind '$got' (expected $expectedKind)" }
    return $obj
}
# 조회 오류 → 사유(data.tests.ps1 복사 — CRD 소유 과제가 없는 종류는 $crdTask = '')
function Describe-LookupError([string]$msg, [string]$what, [string]$crdTask) {
    if (-not [string]::IsNullOrEmpty($crdTask) -and (IndexOrd $msg "doesn't have a resource type") -ge 0) {
        return "$what lookup failed: CRD not installed ($crdTask deploys the CNPG operator and its CRDs) -- $(Clip (First-Line $msg) 200)"
    }
    return "$what lookup failed: $(Clip $msg 240)"
}
# 목록 조회(실패까지 캐시). 반환 @{ ok; items; reason }
function Get-ListCached([string[]]$kArgs, [string]$what, [string]$crdTask = '') {
    $key = ($kArgs -join ' ')
    if ($script:listCache.ContainsKey($key)) { return $script:listCache[$key] }
    $res = @{ ok = $false; items = @(); reason = '' }
    try { $res.items = @(Items (Get-KubeList $kArgs)); $res.ok = $true }
    catch { $res.reason = (Describe-LookupError $_.Exception.Message $what $crdTask) }
    $script:listCache[$key] = $res
    return $res
}

# ---------- 검사 Job 로그(data.tests.ps1 Test-JobLog 복사 + id 하나의 상태) ----------
# Job 로그 판정(순수 함수): `^RESULT: (PASS|FAIL) <id>` 줄에서 기대 id마다 정확히 1줄 · PASS, `SUMMARY: pass=<n> fail=<n>`(여럿이면 마지막) fail=0,
#   SUMMARY의 pass/fail 수 = RESULT 줄 수(PASS/FAIL 각각 — --tail=50 밖으로 밀린 줄을 잡는다), 추적 밖 id의 RESULT FAIL도 문제.
#   근거 텍스트는 옮기지 않는다(id와 PASS/FAIL만). 반환 @{ ok; problems; summary = @{ pass; fail } 또는 $null }
function Test-JobLog([string[]]$lines, [string[]]$ids, [string[]]$pendingIds, [string]$pendingNote) {
    $counts = [System.Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
    $last = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $failedIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $summary = $null; $passLines = 0; $failLines = 0
    foreach ($raw in @($lines)) {
        $l = [string]$raw
        $m = [regex]::Match($l, '\ARESULT: (PASS|FAIL) (\S+)')
        if ($m.Success) {
            $id = $m.Groups[2].Value
            if ($counts.ContainsKey($id)) { $counts[$id]++ } else { $counts[$id] = 1 }
            $last[$id] = $m.Groups[1].Value
            if (Eq $m.Groups[1].Value 'PASS') { $passLines++ } else { $failLines++; [void]$failedIds.Add($id) }
            continue
        }
        $s = [regex]::Match($l, '\ASUMMARY: pass=(\d+) fail=(\d+)\s*\z')
        if ($s.Success) { $summary = @{ pass = [int]$s.Groups[1].Value; fail = [int]$s.Groups[2].Value } }
    }
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($id in @($ids)) {
        if (-not $counts.ContainsKey($id)) {
            if (Contains $pendingIds $id) { $problems.Add("missing RESULT line for $id ($pendingNote)") } else { $problems.Add("missing RESULT line for $id") }
            continue
        }
        if ($counts[$id] -ne 1) { $problems.Add("$($counts[$id]) RESULT lines for $id (expected exactly 1)"); continue }
        if (-not (Eq $last[$id] 'PASS')) { $problems.Add("RESULT FAIL for $id") }
    }
    foreach ($id in @(SortOrd @($failedIds))) { if (-not (Contains $ids $id)) { $problems.Add("RESULT FAIL for $id (outside the tracked set)") } }
    if ($null -eq $summary) { $problems.Add('no SUMMARY line (expected "SUMMARY: pass=<n> fail=<n>")') }
    else {
        if ($summary.fail -ne 0) { $problems.Add("SUMMARY fail=$($summary.fail) (expected 0; pass=$($summary.pass))") }
        if ($summary.pass -ne $passLines -or $summary.fail -ne $failLines) { $problems.Add("SUMMARY pass=$($summary.pass) fail=$($summary.fail) does not match the RESULT lines (PASS $passLines, FAIL $failLines) -- output may be truncated by --tail=50") }
    }
    return @{ ok = ($problems.Count -eq 0); problems = @($problems); summary = $summary }
}
# id 하나의 RESULT 상태(순수 함수 — Test-JobLog와 같은 줄 규칙: 줄 맨 앞 · id 정확 일치). 반환 @{ count; last; text }
function Get-JobIdState([string[]]$lines, [string]$id) {
    $n = 0; $last = ''
    foreach ($raw in @($lines)) {
        $m = [regex]::Match([string]$raw, '\ARESULT: (PASS|FAIL) (\S+)')
        if ($m.Success -and (Eq $m.Groups[2].Value $id)) { $n++; $last = $m.Groups[1].Value }
    }
    $text = if ($n -eq 0) { 'no RESULT line' } elseif ($n -eq 1) { "RESULT $last" } else { "$n RESULT lines" }
    return @{ count = $n; last = $last; text = $text }
}
# authz-assert Job 조회 + 로그(한 번 — fga-1..4 공용; 실패까지 캐시). 반환 @{ state = 'present'|'absent'|'error'; reason; lines; verdict }
$script:authzLog = $null
function Get-AuthzJobLog {
    if ($null -ne $script:authzLog) { return $script:authzLog }
    $res = @{ state = 'error'; reason = ''; lines = @(); verdict = $null }
    $job = $null
    try { $job = Get-KubeOne $AssertJobNs 'jobs.batch' $AssertJobName 'Job' }
    catch { $res.reason = "[env] $(Describe-LookupError $_.Exception.Message "Job $AssertJobNs/$AssertJobName" '')"; $script:authzLog = $res; return $res }
    if ($null -eq $job) {
        $res.state = 'absent'; $res.reason = "[gate] Job $AssertJobNs/$AssertJobName absent — rendered with the tests Application after $FgaJobTask ($FgaRenderTask)"
        $script:authzLog = $res; return $res
    }
    $r = Invoke-Kubectl @('-n', $AssertJobNs, 'logs', "job/$AssertJobName", '--tail=50')
    if ($r.code -ne 0) { $res.reason = "[env] kubectl -n $AssertJobNs logs job/$AssertJobName --tail=50 failed (exit $($r.code)): $(Clip (First-Line $r.err) 240)"; $script:authzLog = $res; return $res }
    if ([string]::IsNullOrWhiteSpace($r.out)) { $res.reason = "[product] Job $AssertJobNs/$AssertJobName logs are empty (no RESULT/SUMMARY line)"; $script:authzLog = $res; return $res }
    $res.lines = @($r.out -split "`r?`n")
    $res.verdict = Test-JobLog $res.lines $FgaIds $FgaPendingIds $FgaPendingNote
    $res.state = 'present'
    $script:authzLog = $res
    return $res
}

# ---------- Ingress(순수 함수) ----------
# rules[].host가 $hostName과 같은(호스트명만 OrdinalIgnoreCase) Ingress의 ns/name 목록. 규칙 없음 · 다른 호스트는 세지 않는다.
function Find-IngressHost($items, [string]$hostName) {
    $found = [System.Collections.Generic.List[string]]::new()
    foreach ($i in @($items)) {
        if ($null -eq $i) { continue }
        foreach ($rule in @(PropArr $i @('spec', 'rules'))) {
            if ($null -ne $rule -and [string]::Equals([string](Prop $rule 'host'), $hostName, [StringComparison]::OrdinalIgnoreCase)) { $found.Add("$(Ns $i)/$(Name $i)"); break }
        }
    }
    return @($found.ToArray())
}

# ---------- HTTP 판정(순수 함수) ----------
# content-type의 미디어 타입(첫 ; 앞 · 앞뒤 공백 제거 · 소문자)
function Get-MediaType([string]$contentType) {
    if ([string]::IsNullOrEmpty($contentType)) { return '' }
    return $contentType.Split(';')[0].Trim().ToLowerInvariant()
}
# Location이 https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/… 인지 판정(ingress.tests.ps1 복사 — 호스트 정확 일치 + 경로 접두).
# 반환 @(ok, 출력용 문자열) — 쿼리(meta 토큰)는 출력하지 않는다.
function Test-AccessLocation([string]$location) {
    $uri = $null
    try { $uri = [Uri]::new($location) } catch { return @($false, 'unparseable Location header') }
    if (-not $uri.IsAbsoluteUri) { return @($false, 'relative Location header') }
    $safe = "$($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)"
    $ok = [string]::Equals($uri.Scheme, 'https', [StringComparison]::Ordinal) -and
    [string]::Equals($uri.Host, $AccessLoginHost, [StringComparison]::OrdinalIgnoreCase) -and
    $uri.AbsolutePath.StartsWith($AccessLoginPathPrefix, [StringComparison]::Ordinal)
    return @($ok, $safe)
}
# Location 출력용 안전 꼴: 절대 http(s) URL은 scheme://host/path, '/'로 시작하는 상대 경로는 그 경로만(쿼리 · 조각 · userinfo · 포트 0). 그 밖은 '(unparseable Location)'.
function ConvertTo-SafeUrl([string]$location) {
    if ([string]::IsNullOrEmpty($location)) { return '' }
    if ($location.StartsWith('/', [StringComparison]::Ordinal) -and -not $location.StartsWith('//', [StringComparison]::Ordinal)) {
        $cut = $location.IndexOfAny([char[]]@('?', '#'))
        $p = if ($cut -ge 0) { $location.Substring(0, $cut) } else { $location }
        if ([regex]::IsMatch($p, '\A/[\x21-\x7E]{0,200}\z')) { return $p }
        return '(unparseable Location)'
    }
    $u = $null
    if ([Uri]::TryCreate($location, [UriKind]::Absolute, [ref]$u) -and ((Eq $u.Scheme 'https') -or (Eq $u.Scheme 'http'))) { return "$($u.Scheme)://$($u.Host)$($u.AbsolutePath)" }
    return '(unparseable Location)'
}
# Traefik 「라우터 없음」 404 서명(t076-design.md D10 기준값)과 다른 점 목록 — 비면 서명 전체 일치. $h = Invoke-Curl 결과 모양.
function Get-Traefik404Mismatch($h) {
    $d = [System.Collections.Generic.List[string]]::new()
    if (-not (Eq ([string]$h.status) '404')) { $d.Add("status $($h.status) (expected 404)") }
    if (-not (Eq ([string]$h.ctype) $Traefik404ContentType)) { $d.Add("content-type '$($h.ctype)' (expected '$Traefik404ContentType')") }
    if ([int]$h.bodyLen -ne $Traefik404Size) { $d.Add("size $($h.bodyLen) B (expected $Traefik404Size B)") }
    elseif (-not (Eq ([string]$h.size) "$Traefik404Size")) { $d.Add("write-out size_download $($h.size) differs from the body file ($($h.bodyLen) B)") }
    if (-not (Eq ([string]$h.bodySha) $Traefik404Sha256)) { $d.Add('body sha256 differs') }
    if ([string]::Equals([string]$h.cf, 'HIT', [StringComparison]::OrdinalIgnoreCase)) { $d.Add('cf-cache-status HIT (a cached copy is not origin evidence)') }
    return @($d.ToArray())
}
function Test-Traefik404($h) { return (@(Get-Traefik404Mismatch $h).Count -eq 0) }
function Get-CurlExitLabel([int]$code) {
    switch ($code) {
        6 { return ' (could not resolve host)' }
        7 { return ' (failed to connect)' }
        28 { return ' (operation timed out)' }
        35 { return ' (TLS handshake failed)' }
        52 { return ' (empty reply from server)' }
        56 { return ' (failure receiving network data)' }
        60 { return ' (server certificate not trusted)' }
        default { return '' }
    }
}
# curl -w 출력(형식 $CurlWriteOut의 다섯 줄) → @{ ok; status; ctype; size; location; cf; error }. 뒤쪽 빈 줄이 빠져도 받는다(나머지는 '').
function ConvertFrom-CurlWriteOut([string]$text) {
    $lines = @(([string]$text) -split "`r?`n")
    if ($lines.Count -lt 3) { return @{ ok = $false; error = "unparseable curl write-out ($($lines.Count) line(s))" } }
    $f = @(for ($i = 0; $i -lt 5; $i++) { if ($i -lt $lines.Count) { ([string]$lines[$i]).Trim() } else { '' } })
    if (-not [regex]::IsMatch($f[0], '\A\d{3}\z')) { return @{ ok = $false; error = 'unparseable curl write-out (http_code)' } }
    if (-not [regex]::IsMatch($f[2], '\A\d+\z')) { return @{ ok = $false; error = 'unparseable curl write-out (size_download)' } }
    return @{ ok = $true; status = $f[0]; ctype = $f[1]; size = $f[2]; location = $f[3]; cf = $f[4]; error = '' }
}
# `curl -q --version` 첫 줄의 판 ≥ $CurlMinVersion(숫자 비교). 반환 @{ ok; version; reason }
function Test-CurlVersion([string]$text) {
    $m = [regex]::Match((First-Line $text), '\Acurl (\d+)\.(\d+)\.(\d+)(\s|\z)')
    if (-not $m.Success) { return @{ ok = $false; version = ''; reason = "could not read the curl version from 'curl -q --version'" } }
    $ver = "$($m.Groups[1].Value).$($m.Groups[2].Value).$($m.Groups[3].Value)"
    $v = [version]::new([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, [int]$m.Groups[3].Value)
    if ($v -lt $CurlMinVersion) { return @{ ok = $false; version = $ver; reason = "curl $ver is older than $CurlMinVersion (no %header{} write-out)" } }
    return @{ ok = $true; version = $ver; reason = '' }
}
# curl env 가드(r1 — B-9 — 순수 함수): env 이름 목록에서 curl이 물려받아 요청 경로(프록시) · TLS 신뢰(CA 묶음) · 세션 키 기록을 바꾸는 이름만 골라
#   ordinal 정렬 · 중복 없이 돌려준다. 대상 = 이름 끝 _PROXY · $CurlEnvGuardNames(둘 다 대소문자 무관). 이름만 받는다 — 값은 이 함수에 오지 않는다.
function Get-CurlEnvViolation([string[]]$names) {
    $hit = [System.Collections.Generic.List[string]]::new()
    foreach ($n in @($names)) {
        if ([string]::IsNullOrEmpty($n)) { continue }
        $bad = $n.EndsWith('_PROXY', [StringComparison]::OrdinalIgnoreCase)
        if (-not $bad) { foreach ($x in @($CurlEnvGuardNames)) { if ([string]::Equals($n, [string]$x, [StringComparison]::OrdinalIgnoreCase)) { $bad = $true; break } } }
        if ($bad -and -not $hit.Contains($n)) { $hit.Add($n) }
    }
    $hit.Sort([StringComparer]::Ordinal)
    return @($hit.ToArray())
}
function Format-ContentType([string]$ct) { if ([string]::IsNullOrEmpty($ct)) { return '(no content-type)' } else { return $ct } }
# 응답 요약(출력용): 상태 · content-type · 안전 꼴 Location
function Format-Response($h) {
    $s = "$($h.status) $(Format-ContentType $h.ctype)"
    if (-not [string]::IsNullOrEmpty($h.locSafe)) { $s += "; Location $($h.locSafe)" }
    return $s
}
# 302 Location 요약(출력용 — Test-AccessLocation의 안전 꼴)
function Format-AccessRedirect($h) {
    if ([string]::IsNullOrEmpty($h.location)) { return "$($h.status) without a Location header" }
    $t = @(Test-AccessLocation $h.location)
    return "$($h.status) -> $($t[1])"
}
function Format-CurlFailure($h, [string]$url) {
    if ($h.exit -eq 0 -and -not [string]::IsNullOrEmpty($h.parseError)) { return "[env] $($h.parseError) for GET $url" }
    $first = First-Line $h.err
    $tail = if ([string]::IsNullOrEmpty($first)) { '' } else { ': ' + (Clip $first 160) }
    return "[env] curl exit $($h.exit)$(Get-CurlExitLabel $h.exit) for GET $url$tail"
}
# 모든 HTTP 단언의 앞단: curl 실패 · write-out 파싱 실패 · 5xx는 [env]. 계속이면 $null.
function Get-HttpPrecheck($h, [string]$url) {
    if ($h.exit -ne 0 -or -not [string]::IsNullOrEmpty($h.parseError)) { return @('FAIL', (Format-CurlFailure $h $url)) }
    if ([int]$h.status -ge 500) { return @('FAIL', "[env] origin $($h.status) for GET $url ($(if ([string]::IsNullOrEmpty($h.ctype)) { 'no content-type' } else { $h.ctype }))") }
    return $null
}
# auth. 공개 경로의 앞단(pub-* · xchg-0): 위 + Traefik 404 서명 전체 일치 → [gate](구현 부재), 서명이 어긋난 404 → [product]. 계속이면 $null.
function Get-AuthRouteCheck($h, [string]$url) {
    $pre = Get-HttpPrecheck $h $url
    if ($null -ne $pre) { return $pre }
    if (Eq $h.status '404') {
        $mm = @(Get-Traefik404Mismatch $h)
        if ($mm.Count -eq 0) { return @('FAIL', "[gate] Traefik 404 (no router) — until $AuthRouteTask") }
        return @('FAIL', "[product] 404 for GET $url is not the Traefik no-router signature ($($mm -join '; '))")
    }
    return $null
}
# 공개 200 JSON 객체 앞단: 200(리다이렉트 미추적) · application/json · 본문이 JSON 객체. 계속이면 $null.
function Get-JsonObjectCheck($h, [string]$url) {
    if (-not (Eq $h.status '200')) { return @('FAIL', "[product] $(Format-Response $h) for GET $url (expected 200 application/json; redirects are not followed)") }
    if (-not (Eq (Get-MediaType $h.ctype) 'application/json')) { return @('FAIL', "[product] 200 $(Format-ContentType $h.ctype) for GET $url (expected application/json)") }
    if (-not ($h.json -is [System.Management.Automation.PSCustomObject])) { return @('FAIL', "[product] 200 application/json for GET $url but the body is not a JSON object") }
    return $null
}

# ---------- HTTP 호출(curl 한 번) ----------
# GET 1회 — 호출 꼴은 글자 고정(머리 주석). 반환 @{ exit; err; parseError; status; ctype; size; location(원문 — 판정에만 쓰고 출력 0); locSafe; cf; bodyLen;
#   bodySha; json; jsonError }. 본문은 해시 · 길이 · (application/json이면) 파싱 객체만 메모리에 두고 출력하지 않는다. 임시 파일은 finally에서 지운다.
function Invoke-Curl([string]$url) {
    $tmp = [IO.Path]::GetTempPath(); $tag = [guid]::NewGuid().ToString('N')
    $bodyFile = Join-Path $tmp "identity-tests-body-$tag.bin"
    $fmtFile = Join-Path $tmp "identity-tests-fmt-$tag.txt"
    $h = @{ exit = -1; err = ''; parseError = ''; status = ''; ctype = ''; size = ''; location = ''; locSafe = ''; cf = ''; bodyLen = 0; bodySha = ''; json = $null; jsonError = '' }
    try {
        [IO.File]::WriteAllText($fmtFile, $CurlWriteOut, [Text.UTF8Encoding]::new($false))
        $r = Invoke-Native $script:curl @('-q', '-s', '-S', '--max-time', "$HttpTimeoutSec", '--proto', '=https', '-o', $bodyFile, '-w', "@$fmtFile", $url)
        $h.exit = $r.code; $h.err = $r.err
        if ($r.code -ne 0) { return $h }
        $w = ConvertFrom-CurlWriteOut $r.out
        if (-not $w.ok) { $h.parseError = $w.error; return $h }
        $h.status = $w.status; $h.ctype = $w.ctype; $h.size = $w.size; $h.location = $w.location; $h.cf = $w.cf
        $h.locSafe = ConvertTo-SafeUrl $w.location
        $bytes = [byte[]]::new(0)
        if (Test-Path -LiteralPath $bodyFile -PathType Leaf) { $bytes = [IO.File]::ReadAllBytes($bodyFile) }   # 0바이트 본문이면 curl이 파일을 만들지 않을 수 있다
        $h.bodyLen = $bytes.Length
        $h.bodySha = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        if (Eq (Get-MediaType $h.ctype) 'application/json') {
            # -NoEnumerate: 원소 하나 배열 루트가 객체로 풀리지 않게(배열 루트는 객체가 아니다). 파싱 오류 메시지는 본문 조각을 담을 수 있어 옮기지 않는다.
            try { $h.json = [Text.UTF8Encoding]::new($false, $true).GetString($bytes) | ConvertFrom-Json -Depth 64 -NoEnumerate }
            catch { $h.json = $null; $h.jsonError = 'body is not UTF-8 JSON' }
        }
        return $h
    } finally { Remove-WithRetry @($bodyFile, $fmtFile) }
}

# ---------- RFC 8693 교환 판정(순수 함수 — 라이브에서는 부르지 않는다; 검토된 자격 블록이 바이트 사본으로 부른다) ----------
# base64url → 바이트. 반환 @{ ok; bytes }(배열 언래핑을 피해 해시로)
function ConvertFrom-Base64Url([string]$s) {
    if ($null -eq $s -or -not [regex]::IsMatch($s, '\A[A-Za-z0-9_-]+\z')) { return @{ ok = $false; bytes = $null } }
    $t = $s.Replace('-', '+').Replace('_', '/')
    switch ($t.Length % 4) {
        0 { }
        2 { $t += '==' }
        3 { $t += '=' }
        default { return @{ ok = $false; bytes = $null } }
    }
    try { return @{ ok = $true; bytes = [Convert]::FromBase64String($t) } } catch { return @{ ok = $false; bytes = $null } }
}
function Test-JsonNumber($v) { return ($v -is [int]) -or ($v -is [long]) -or ($v -is [double]) -or ($v -is [decimal]) -or ($v -is [System.Numerics.BigInteger]) }
# 출력해도 되는 짧은 토큰만(audience · 오류 코드 꼴) — 아니면 '(non-standard value)'
function Format-ClaimToken([string]$s) { if ($null -ne $s -and [regex]::IsMatch($s, '\A[A-Za-z0-9._:/-]{1,80}\z')) { return $s } else { return '(non-standard value)' } }
# 교환으로 받은 access token(compact JWS)의 클레임 판정. 서명은 검증하지 않는다(블록이 토큰 엔드포인트에서 TLS로 직접 받은 값).
#   aud = $ExchangeAudience(문자열 또는 원소 하나 배열) · tenant_id 정규 소문자 uuid · exp − iat = $ExchangeLifetimeSec ·
#   $vd1Option 'B'면 act 유무 무관(INFO) · 'A'면 act.sub = $expectedActSub · iss는 INFO(https://auth.joshuatech.dev/ 아래일 때만 값).
#   반환 @{ ok; problems; info } — JWT 값 · sub · tenant_id 값 · act.sub 값은 싣지 않는다.
function Test-ExchangeClaims([string]$jwt, [string]$vd1Option, [string]$expectedActSub) {
    $problems = [System.Collections.Generic.List[string]]::new()
    $info = [System.Collections.Generic.List[string]]::new()
    $parts = if ([string]::IsNullOrEmpty($jwt)) { @() } else { @($jwt.Split('.')) }
    if ($parts.Count -ne 3) { $problems.Add("not a compact JWS (expected 3 dot-separated parts, got $($parts.Count))"); return @{ ok = $false; problems = @($problems); info = @($info) } }
    $b = ConvertFrom-Base64Url $parts[1]
    if (-not $b.ok) { $problems.Add('JWT payload is not base64url'); return @{ ok = $false; problems = @($problems); info = @($info) } }
    $claims = $null
    try { $claims = [Text.UTF8Encoding]::new($false, $true).GetString($b.bytes) | ConvertFrom-Json -Depth 64 -NoEnumerate }
    catch { $problems.Add('JWT payload is not UTF-8 JSON'); return @{ ok = $false; problems = @($problems); info = @($info) } }
    if (-not ($claims -is [System.Management.Automation.PSCustomObject])) { $problems.Add('JWT payload is not a JSON object'); return @{ ok = $false; problems = @($problems); info = @($info) } }
    # aud
    $aud = Get-JsonField $claims 'aud'
    if (-not $aud.present -or $null -eq $aud.value) { $problems.Add("aud is absent (expected '$ExchangeAudience')") }
    elseif ($aud.value -is [string]) { if (-not (Eq $aud.value $ExchangeAudience)) { $problems.Add("aud is '$(Format-ClaimToken $aud.value)' (expected '$ExchangeAudience')") } }
    elseif ($aud.value -is [System.Collections.IList]) {
        $list = @($aud.value)
        if ($list.Count -ne 1) { $problems.Add("aud has $($list.Count) entries (expected exactly ['$ExchangeAudience'])") }
        elseif (-not ($list[0] -is [string]) -or -not (Eq $list[0] $ExchangeAudience)) { $problems.Add("aud is ['$(Format-ClaimToken ([string]$list[0]))'] (expected '$ExchangeAudience')") }
    } else { $problems.Add('aud is not a string or an array of one string') }
    # tenant_id
    $t = Get-JsonField $claims 'tenant_id'
    if (-not $t.present -or $null -eq $t.value) { $problems.Add('tenant_id is absent') }
    elseif (-not ($t.value -is [string]) -or -not [regex]::IsMatch($t.value, '\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z')) { $problems.Add('tenant_id is not a canonical lowercase UUID string') }
    # exp − iat
    $exp = Get-JsonField $claims 'exp'; $iat = Get-JsonField $claims 'iat'
    $expOk = $exp.present -and (Test-JsonNumber $exp.value); $iatOk = $iat.present -and (Test-JsonNumber $iat.value)
    if (-not $expOk) { $problems.Add('exp is absent or not a number') }
    if (-not $iatOk) { $problems.Add('iat is absent or not a number') }
    if ($expOk -and $iatOk) {
        $d = [decimal]$exp.value - [decimal]$iat.value
        if ($d -ne $ExchangeLifetimeSec) { $problems.Add("exp - iat = $($d.ToString([Globalization.CultureInfo]::InvariantCulture)) (expected $ExchangeLifetimeSec)") }
    }
    # act(VD-1)
    $act = Get-JsonField $claims 'act'
    if (Eq $vd1Option 'B') { if ($act.present) { $info.Add('act present (VD-1 option B: not asserted)') } else { $info.Add('act absent (VD-1 option B)') } }
    elseif (Eq $vd1Option 'A') {
        $sub = Get-JsonField $act.value 'sub'
        if (-not $act.present -or $null -eq $act.value) { $problems.Add("act is absent (VD-1 option A requires act.sub = '$expectedActSub')") }
        elseif (-not $sub.present -or -not ($sub.value -is [string]) -or -not (Eq $sub.value $expectedActSub)) { $problems.Add("act.sub differs from '$expectedActSub' (VD-1 option A)") }
        else { $info.Add('act.sub matches the web-bff client (VD-1 option A)') }
    } else { $problems.Add("unknown VD-1 option '$(if ([regex]::IsMatch([string]$vd1Option, '\A[A-Za-z]\z')) { $vd1Option } else { '?' })' (expected A or B)") }
    # iss(INFO)
    $iss = Get-JsonField $claims 'iss'
    if (-not $iss.present -or -not ($iss.value -is [string])) { $info.Add('iss absent') }
    elseif ($iss.value.StartsWith("https://$AuthHost/", [StringComparison]::Ordinal) -and [regex]::IsMatch($iss.value, '\A[A-Za-z0-9:/._-]{1,200}\z')) { $info.Add("iss=$($iss.value)") }
    else { $info.Add("iss not under https://$AuthHost/ (value not shown)") }
    return @{ ok = ($problems.Count -eq 0); problems = @($problems); info = @($info) }
}
# audience=portfolio-core 교환 거부 판정: 400 · JSON 객체 · error = $RejectError(ordinal) · access_token 없음. 오류 코드는 [a-z_]{1,40} 꼴일 때만 출력한다.
#   반환 @{ ok; problems; info }
function Test-ExchangeRejection([int]$status, [string]$body) {
    $problems = [System.Collections.Generic.List[string]]::new()
    $info = [System.Collections.Generic.List[string]]::new()
    if ($status -ne 400) { $problems.Add("status $status (expected 400)") }
    $obj = $null; $parsed = $false
    try { $obj = $body | ConvertFrom-Json -Depth 64 -NoEnumerate; $parsed = $true } catch { $problems.Add('body is not JSON') }
    if ($parsed) {
        if (-not ($obj -is [System.Management.Automation.PSCustomObject])) { $problems.Add('body is not a JSON object') }
        else {
            $e = Get-JsonField $obj 'error'
            if (-not $e.present -or -not ($e.value -is [string]) -or $e.value.Length -eq 0) { $problems.Add("error is absent (expected '$RejectError')") }
            elseif (-not [regex]::IsMatch($e.value, '\A[a-z_]{1,40}\z')) { $problems.Add("error is a non-standard value (not shown) (expected '$RejectError' -- RFC 8693 section 2.2.2; the real code is VD-T081-d)") }
            elseif (-not (Eq $e.value $RejectError)) { $problems.Add("error='$($e.value)' (expected '$RejectError' -- RFC 8693 section 2.2.2; the real code is VD-T081-d)") }
            else { $info.Add("error=$($e.value)") }
            if ((Get-JsonField $obj 'access_token').present) { $problems.Add('an access_token was issued (the exchange must be refused; token not shown)') }
        }
    }
    return @{ ok = ($problems.Count -eq 0); problems = @($problems); info = @($info) }
}

# ---------- 0. 게이트(fail closed — data.tests.ps1 복사, FAIL 사유에 [env]) ----------
$k = Get-Command kubectl -CommandType Application -ErrorAction SilentlyContinue
if ($null -ne $k) { $script:kubectl = @($k)[0].Source; Pass 'gate-1' 'kubectl found' }
else { Fail 'gate-1' '[env] kubectl not found on PATH -- no cluster access (cluster/kubectl unavailable)'; $script:clusterReason = 'kubectl missing' }

$kc = $env:KUBECONFIG
if ([string]::IsNullOrWhiteSpace($kc)) {
    Fail 'gate-2' '[env] KUBECONFIG is not set -- no cluster (agent-view token kubeconfig required; cluster unavailable)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG not set' }
} elseif ($kc.IndexOf([IO.Path]::PathSeparator) -ge 0) {
    Fail 'gate-2' '[env] KUBECONFIG must be a single file path (path list not supported)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG is a path list' }
} elseif (-not (Test-Path -LiteralPath $kc -PathType Leaf)) {
    Fail 'gate-2' '[env] KUBECONFIG file not found -- no cluster (cluster unavailable)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG file not found' }
} else { $script:kubeconfig = $kc; Pass 'gate-2' 'KUBECONFIG set (single existing file)' }

if ($null -eq $script:clusterReason) {
    try {
        $r = Invoke-Kubectl @('auth', 'whoami', '-o', 'json')
        if ($r.code -ne 0) { throw "kubectl auth whoami failed (exit $($r.code)): $($r.err)" }
        $who = ConvertFrom-JsonStrict $r.out 'kubectl auth whoami'
        $username = [string](PropPath $who @('status', 'userInfo', 'username'))
        if (Eq $username $expectedUser) { Pass 'gate-3' "context user is $expectedUser" }
        else { Fail 'gate-3' "[env] context user is '$username', expected $expectedUser (admin/other kubeconfig refused)"; $script:clusterReason = 'context user is not agent-view' }
    } catch {
        Fail 'gate-3' "[env] kubectl auth whoami unusable -- cluster unreachable or not agent-view: $($_.Exception.Message)"
        $script:clusterReason = 'cluster unreachable (whoami failed)'
    }
} else { Fail 'gate-3' "[env] cluster unavailable ($script:clusterReason)" }

# ---------- 1. tool-1: curl(첫 해석 = Application · 판 ≥ 7.84.0) ----------
try {
    $first = @(Get-Command curl -ErrorAction SilentlyContinue)
    if ($first.Count -eq 0) { $script:curlReason = 'curl not found on PATH' }
    elseif ($first[0].CommandType -ne [System.Management.Automation.CommandTypes]::Application) {
        $script:curlReason = "the first resolution of 'curl' has command type $($first[0].CommandType), not Application -- an alias, function or script shadows the curl application"
    } else {
        $app = @(Get-Command curl -CommandType Application -ErrorAction SilentlyContinue)
        $curlPath = if ($app.Count -gt 0) { [string]$app[0].Source } else { '' }
        if ($curlPath.Length -eq 0 -or -not [string]::Equals($curlPath, [string]$first[0].Source, [StringComparison]::OrdinalIgnoreCase)) {
            $script:curlReason = "the first curl application ($(Mask-Text $curlPath)) is not the first resolution ($(Mask-Text ([string]$first[0].Source)))"
        } else {
            $vr = Invoke-Native $curlPath @('-q', '--version')
            if ($vr.code -ne 0) { $script:curlReason = "curl -q --version failed (exit $($vr.code))" }
            else {
                $cv = Test-CurlVersion $vr.out
                if (-not $cv.ok) { $script:curlReason = $cv.reason }
                else { $script:curl = $curlPath; $script:curlReason = $null; Pass 'tool-1' "curl $($cv.version) ($(Mask-Text $curlPath)) supports %header{} write-out (>= $CurlMinVersion)" }
            }
        }
    }
} catch { $script:curlReason = "curl check failed: $($_.Exception.Message)" }
if ($null -ne $script:curlReason) { Fail 'tool-1' "[env] $script:curlReason" }

# ---------- 1b. curl env 가드(r1 — B-9): env 이름만 본다 — 걸리면 HTTP 단언은 curl을 부르지 않고 [guard](머리 주석 「HTTP」) ----------
try {
    $guardedEnv = @(Get-CurlEnvViolation @([Environment]::GetEnvironmentVariables().Keys))
    if ($guardedEnv.Count -gt 0) { $script:curlEnvReason = "[guard] curl-env-not-allowed $($guardedEnv -join ',') (proxy, TLS key log or CA bundle variables would reach curl; values not shown -- unset them and rerun)" }
    else { $script:curlEnvReason = $null }
} catch { $script:curlEnvReason = "[guard] curl-env-not-allowed (environment names unreadable: $($_.Exception.GetType().Name))" }

# ---------- 2. ing-1: Authentik Ingress(ns identity) ----------
$script:ing = @{ known = $false; ok = $false; reason = 'ing-1 not evaluated'; names = @() }
Test-Group 'ingress' {
    if ($null -ne $script:clusterReason) { $script:ing.reason = "cluster unavailable ($script:clusterReason)" }
    ClusterAssert 'ing-1' {
        $l = Get-ListCached @('get', 'ingresses.networking.k8s.io', '-n', $IdentityNs) "Ingress list in ns $IdentityNs"
        if (-not $l.ok) { $script:ing.reason = $l.reason; return @('FAIL', "[env] $($l.reason)") }
        $m = @(Find-IngressHost $l.items $AuthHost)
        $script:ing.known = $true; $script:ing.ok = ($m.Count -gt 0); $script:ing.names = $m
        if ($m.Count -eq 0) { $script:ing.reason = "no Ingress for $AuthHost in ns $IdentityNs"; return @('FAIL', "[gate] until $AuthRouteTask (no Ingress for $AuthHost in ns $IdentityNs)") }
        return @('PASS', "Ingress $($m -join ', ') has rules[].host $AuthHost")
    }
}

# ---------- 3. acc-1..3: Access 경계(무헤더) ----------
Test-Group 'access' {
    HttpAssert 'acc-1' {
        $url = "https://$AuthHost$AuthAdminPath"
        $h = Invoke-Curl $url
        $pre = Get-HttpPrecheck $h $url
        if ($null -ne $pre) { return $pre }
        $edge = $null
        if (Eq $h.status '302') {
            $t = @(Test-AccessLocation $h.location)
            if ([string]::IsNullOrEmpty($h.location) -or -not [bool]$t[0]) { return @('FAIL', "[product] $(Format-AccessRedirect $h) for GET $url is not the Cloudflare Access login (expected https://$AccessLoginHost$AccessLoginPathPrefix...)") }
            $edge = @{ status = '302'; text = "302 -> $($t[1]) (Access app auth-admin; query not shown)" }
        } elseif ((Eq $h.status '403') -and (Eq (Get-MediaType $h.ctype) 'text/html') -and [string]::IsNullOrEmpty($h.location)) {
            $edge = @{ status = '403'; text = '403 text/html without Location (Access app auth-admin)' }
        } else { return @('FAIL', "[product] $(Format-Response $h) for GET $url (expected 302 to the Cloudflare Access login or 403 text/html without Location)") }
        # 엣지 응답만으로는 빈 PASS다 — 오리진 경로(ing-1)와 짝이어야 한다
        if (-not $script:ing.known) { return @('FAIL', "[env] $($edge.status) at the edge but the origin route is unknown (ing-1: $($script:ing.reason))") }
        if (-not $script:ing.ok) { return @('FAIL', "[gate] $($edge.status) is edge-only (Access app auth-admin — $AccessAppTask); origin route absent — until $AuthRouteTask") }
        return @('PASS', "$($edge.text); origin route present (ing-1: Ingress $($script:ing.names -join ', '))")
    }
    HttpAssert 'acc-2' {
        $url = "https://$AdminHost$AdminPodPath"
        $h = Invoke-Curl $url
        $pre = Get-HttpPrecheck $h $url
        if ($null -ne $pre) { return $pre }
        if (-not (Eq $h.status '302')) { return @('FAIL', "[product] $(Format-Response $h) for GET $url (expected 302 to the Cloudflare Access login)") }
        $t = @(Test-AccessLocation $h.location)
        if ([string]::IsNullOrEmpty($h.location) -or -not [bool]$t[0]) { return @('FAIL', "[product] $(Format-AccessRedirect $h) for GET $url is not the Cloudflare Access login (expected https://$AccessLoginHost$AccessLoginPathPrefix...)") }
        return @('PASS', "302 -> $($t[1]) (Cloudflare Access login; query not shown)")
    }
    HttpAssert 'acc-3' {
        $url = "https://$M2mProdHost$M2mHealthPath"
        $h = Invoke-Curl $url
        $pre = Get-HttpPrecheck $h $url
        if ($null -ne $pre) { return $pre }
        if ((Eq $h.status '401') -and (Eq (Get-MediaType $h.ctype) 'text/html') -and [string]::IsNullOrEmpty($h.location)) { return @('PASS', '401 text/html without Location (Access service auth; contract C11)') }
        return @('FAIL', "[product] $(Format-Response $h) for GET $url (expected 401 text/html without Location -- Access service auth, contract C11)")
    }
}

# ---------- 4. pub-1..5: Authentik 공개 경로(200 · application/json · 구조 키) ----------
Test-Group 'public' {
    HttpAssert 'pub-1' {
        $url = "https://$AuthHost$RootConfigPath"
        $h = Invoke-Curl $url
        $pre = Get-AuthRouteCheck $h $url; if ($null -ne $pre) { return $pre }
        $j = Get-JsonObjectCheck $h $url; if ($null -ne $j) { return $j }
        if (-not (Get-JsonField $h.json $RootConfigKey).present) { return @('FAIL', "[product] 200 application/json for GET $url but the body lacks key $RootConfigKey") }
        return @('PASS', "GET $url -> 200 application/json with key $RootConfigKey")
    }
    HttpAssert 'pub-2' {
        $url = "https://$AuthHost$ExecutorPath"
        $h = Invoke-Curl $url
        $pre = Get-AuthRouteCheck $h $url; if ($null -ne $pre) { return $pre }
        $j = Get-JsonObjectCheck $h $url; if ($null -ne $j) { return $j }
        $f = Get-JsonField $h.json 'component'
        if (-not $f.present -or -not ($f.value -is [string]) -or $f.value.Length -eq 0) { return @('FAIL', "[product] 200 application/json for GET $url but the body lacks key component") }
        return @('PASS', "GET $url -> 200 application/json with key component (login flow $LoginFlowSlug)")
    }
    HttpAssert 'pub-3' {
        $url = "https://$AuthHost$OidcConfigPath"
        $h = Invoke-Curl $url
        $pre = Get-AuthRouteCheck $h $url; if ($null -ne $pre) { return $pre }
        $j = Get-JsonObjectCheck $h $url; if ($null -ne $j) { return $j }
        $iss = Get-JsonField $h.json 'issuer'
        if (-not $iss.present) { return @('FAIL', "[product] 200 application/json for GET $url but the body lacks key issuer") }
        if (-not ($iss.value -is [string]) -or -not (Eq $iss.value $ExpectedIssuer)) { return @('FAIL', "[product] 200 application/json for GET $url but issuer is not $ExpectedIssuer") }
        $jw = Get-JsonField $h.json 'jwks_uri'
        if (-not $jw.present -or -not ($jw.value -is [string]) -or $jw.value.Length -eq 0) { return @('FAIL', "[product] 200 application/json for GET $url but the body lacks key jwks_uri") }
        return @('PASS', "GET $url -> 200 application/json; issuer = $ExpectedIssuer; jwks_uri present")
    }
    HttpAssert 'pub-4' {
        $url = "https://$AuthHost$JwksPath"
        $h = Invoke-Curl $url
        $pre = Get-AuthRouteCheck $h $url; if ($null -ne $pre) { return $pre }
        $j = Get-JsonObjectCheck $h $url; if ($null -ne $j) { return $j }
        $ks = Get-JsonField $h.json 'keys'
        if (-not $ks.present) { return @('FAIL', "[product] 200 application/json for GET $url but the body lacks key keys") }
        if (-not ($ks.value -is [System.Collections.IList]) -or $ks.value.Count -lt 1) { return @('FAIL', "[product] 200 application/json for GET $url but keys is not a non-empty array") }
        return @('PASS', "GET $url -> 200 application/json; keys[] has $($ks.value.Count) key(s)")
    }
    HttpAssert 'pub-5' {
        $url = "https://$AuthHost$WellKnownRootPath"
        $h = Invoke-Curl $url
        $pre = Get-AuthRouteCheck $h $url; if ($null -ne $pre) { return $pre }
        $j = Get-JsonObjectCheck $h $url; if ($null -ne $j) { return $j }
        $iss = Get-JsonField $h.json 'issuer'
        if (-not $iss.present -or -not ($iss.value -is [string]) -or $iss.value.Length -eq 0) { return @('FAIL', "[product] 200 application/json for GET $url but the body lacks key issuer") }
        return @('PASS', "GET $url -> 200 application/json with key issuer (RFC 8414 candidate path; VD-T080-a)")
    }
}

# ---------- 5. xchg-0..2: 토큰 엔드포인트 도달 · 교환 판정(자격 블록 전용) ----------
Test-Group 'exchange' {
    HttpAssert 'xchg-0' {
        $url = "https://$AuthHost$TokenPath"
        $h = Invoke-Curl $url
        $pre = Get-AuthRouteCheck $h $url; if ($null -ne $pre) { return $pre }
        if ((Eq $h.status '405') -and [string]::IsNullOrEmpty($h.location)) { return @('PASS', "GET $url -> 405 (token endpoint reached; never probed with POST)") }
        return @('FAIL', "[product] $(Format-Response $h) for GET $url (expected 405 without Location -- the Authentik token endpoint refuses GET)")
    }
    # 교환 판정 · portfolio-core 거부는 web-bff(-dev) 자격이 필요하다 — 이 하네스는 판정 함수만 두고 부르지 않는다(머리 주석 「교환」)
    Skip 'xchg-1' $SkipCredBlock
    Skip 'xchg-2' $SkipCredBlock
}

# ---------- 6. fga-1..4: OpenFGA 검사 Job 로그(자격이 필요한 check는 클러스터 안 Job이 실행 — 로그만 읽는다) ----------
Test-Group 'openfga' {
    for ($i = 0; $i -lt $FgaIds.Count; $i++) {
        $fid = "fga-$($i + 1)"; $cid = $FgaIds[$i]
        ClusterAssert $fid {
            $jl = Get-AuthzJobLog
            if (-not (Eq $jl.state 'present')) { return @('FAIL', $jl.reason) }
            $v = $jl.verdict
            $own = Get-JobIdState $jl.lines $cid
            if ($v.ok) { return @('PASS', "Job $AssertJobNs/$AssertJobName log: RESULT PASS $cid; all $($FgaIds.Count) tracked check ids PASS exactly once; SUMMARY pass=$($v.summary.pass) fail=0 (EVIDENCE lines not copied)") }
            # 문제가 「아직 내지 않는 새 id」뿐이면 구현 부재(T082) — 그 밖은 계약 위반
            $missingPending = @($FgaIds | Where-Object { (Contains $FgaPendingIds $_) -and (Get-JobIdState $jl.lines $_).count -eq 0 })
            if ($missingPending.Count -gt 0 -and $v.problems.Count -eq $missingPending.Count) { return @('FAIL', "[gate] until $FgaJobTask (Job $AssertJobNs/$AssertJobName does not emit the new check id(s) yet: $($missingPending -join ', '); ${cid}: $($own.text))") }
            return @('FAIL', "[product] Job $AssertJobNs/$AssertJobName log: $cid $($own.text); $($v.problems.Count) problem(s): $($v.problems -join '; ')")
        } 1200
    }
}

# ---------- 7. man-1 · 2: 운영자 수동(R30 — tester 자격으로 자동화하지 않는다) ----------
Test-Group 'manual' {
    Skip 'man-1' $SkipManual   # argocd --sso 로그인
    Skip 'man-2' $SkipManual   # Authentik 관리 API 접근
}

# ---------- 요약 ----------
Write-Host ''
Write-Host "$script:pass passed, $script:fail failed, $script:skip skipped"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
