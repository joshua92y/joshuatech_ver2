# T076 설계 — US6 E2E(템플릿 로컬 경로 + identity-admin 라이브) · tester-m2m 자격(UD-15 · UD-16)

- 상태: **확정(2026-11-20 — 빌드 전)**. 과제가 닫힌 뒤에는 이 문서를 고치지 않는다(`.claude/rules/specs.md`). 실측과 다르면 끝의 「정정 노트」에 덧붙인다.
- 입력: 조사 R1 · R2 · R3(`.superpowers/t076/research/` — 사실 F1-n · F2-n · F3-n) · 비판 A(정합 · 실행) · B(자격 · 보안)(`.superpowers/t076/reviews/critique-{A,B}*.md` — 지적 A-1–A-14 · B-01–B-12) · 사용자 결정 UD-15 · UD-16 · 컨트롤러 실측 1건(§2 D10 — Traefik 기본 404).
- 과제(tasks.md :196, 문면 그대로): 「E2E: US6 AC1–AC6 — 템플릿으로 `tests/fixtures/generated/sample-pod`(gitignore) 생성 → 테스트 6종 + 마이그레이션 검사 PASS(증거: pytest 출력) → arm64 빌드 → 렌더 단언(securityContext·probe·`-migrate` 분리); `identity-m2m-dev.`·`identity-m2m-prod.joshuatech.dev/health` 200(Access 서비스 토큰 **`tester-m2m`** — T011), 헤더 없이 403, `/admin/` 404, **m2m 호스트로 `/webhooks/authentik`·`/healthz`·`/ready` → 404**(Ingress 경로 허용 목록 5개 밖 — T066에서 이관된 Ingress 층위 단언); ExternalSecret 2개(`-env`·`-migrate`) 주입 확인 — evidence recorded in the tester report」. E2E는 tester가 실행하고 구현자는 실행하지 않는다(tasks.md :374).

## 0. 사용자 결정

| 결정 | 내용 | 근거 |
|---|---|---|
| **UD-15**(2026-11-20) | tester-m2m 자격을 **tester에게 준다**. T077 몫이던 `kv/platform/access/tester-m2m` 시드를 앞당기고, Vault role `e2e-reader` 정책에 그 경로 읽기를 더하고, tester가 Vault에서 직접 꺼내 쓴다. | 계약 hostnames-and-access.md :80 · :82-84(「tester는 실행 시 env로만 받고 파일에 저장하지 않는다」 · 보관 `kv/platform/access/tester-m2m`) · 런북 vault-unseal.md §12 |
| **UD-16**(2026-11-20) | tester의 Vault 로그인 토큰 = **vault 전용 1시간 JWT**. 운영자가 라이브 창마다 한 번 `kubectl create token agent-view -n kube-system --audience vault --duration=1h`로 발급해 저장소 밖 DPAPI 파일에 둔다. O-8은 그 한 시간 안에서 몇 번이든 다시 돌 수 있다. 「읽고 바로 지우기(1회용)」로 조일지는 마무리 때 정한다. | 계약 :80(「--audience vault --duration=1h」)의 값 그대로라 문서 편차가 없다. 비판 A-3 · B-01(HIGH)이 기각한 「agent-view 8h kubeconfig에 audience vault를 더함」은 쓰지 않는다. |

컨트롤러 결정(비판 반영 — §9 표)은 아래 D1–D16에 녹였다.

## 1. AC 대응과 합격선

| AC · 문면 | 증거(누가 · 어디서) | 합격선 | 이연 · 편차 |
|---|---|---|---|
| AC1 생성 → `uv sync` → pytest → arm64 | tester 1차: 템플릿 하네스 전체(D9 ①) · 보존 트리 생성물 pytest(D9 ②) · arm64 이미지(D9 ③) | 하네스 failed 0 · error 0 · **skipped 0** · exit 0(총수는 실측 기록 — 918로 못 박지 않는다) · 생성물 pytest 같은 조건 + 수집 7파일 · 이미지 `linux/arm64` · `Config.User` = **`10001:10001`**(gen-33) | 생성 경로 = `tests/fixtures/generated/apps/sample-pod`(편차 후보 7) · spec :137 「compose.dev.yml에서 pytest」 ≠ testcontainers(후보 8) |
| AC2 RLS 0행 · 등급 B · owner bypass | 생성물 시험(하네스 안 · D9 ②) | 위와 같음 | — |
| AC3 outbox → Kafka(A · B 행) · attempts · DLQ | 생성물 `test_outbox`(하네스 안) | 위와 같음 | 「5초 내」를 직접 재는 시험이 없다(F8) → **대리 측정**: D9 ② `--durations=0`의 `test_relay_delivers_both_tenants_to_kafka` call 시간(relay_once 1회 + 실 Kafka 수신 + 컨슈머 합류 = 상한) + 구조 근거(릴레이 폴링 500 ms — contracts/events.md) = INFO · 편차 후보 9(직접 측정 · 소유 없음). T085는 폐기 반영(≤ 2 s · SC-003)을 재므로 이연처가 아니다(A-4). |
| AC4 인증 미들웨어(거부 목록 · iss/aud · act · 503) | 생성물 `test_auth*`(하네스 안) · identity-admin 스위트(D9 ④) | 위와 같음 | 라이브 Bearer 경로는 Authentik(T081) 뒤 — US4 E2E(T085) |
| AC5 JSON 로그 필드 · OTLP → Alloy | 생성물 `test_logging`(하네스 안) | 로그 필드 PASS | OTLP → Alloy = **SKIP**(Alloy 미배포 · `OTEL_EXPORTER_OTLP_ENDPOINT` 빈 값 · 소유 = 구현 T098 · 확인 T096 · T102) — 편차 후보 10 |
| AC6 overlays sync → m2m `/health` 200 · ES 2 주입 · 런타임 env에 owner 자격 없음 | L-8(tester 1차 — 사다리 ⓪–⑤ · D12) · O-7 출력(운영자 — ⑥) · O-8(tester 2차 — `/health` 200) | L-8 PASS · O-7 키 이름 `-env` 11 · `-migrate` 1(dev · prod) · O-8 dev · prod `/health` 판정 8 PASS | `/health` 200은 edge Access(tester-m2m include) · AOP · Traefik · Service · pod · 의존 셋을 증명한다. **AUD · CN · 팀 도메인은 증명하지 않는다**(pod에서 Access 단계 면제 — 양성은 T075 O-5c · 음성은 O-8 `/tenants/me` 403). Authentik 비밀은 US6 시점 일부 sentinel(api_token · openfga — C6 · C8 · 실값 T081–T083) = 설계대로 · 편차 후보 12 |
| (문면) 헤더 없이 403 | L-8(tester 무자격 curl) | m2m dev · prod `/health` → **401**(계약 C11 — hostnames-and-access.md :7 · :27) · Location 없음 | 문면 403 ≠ 실측 = **편차 후보 6**(T075에서 이어받음). admin 호스트 무자격 302는 INFO(US4 AC6 — T085) |
| (문면) `/admin/` · `/webhooks/authentik` · `/healthz` · `/ready` → 404(m2m 호스트) | O-8(tester-m2m 헤더) + C-8(Traefik · pod 로그 대조) | O-8: 404 · 미디어 타입 `text/plain` · 본문 정확히 한 줄 `404 page not found` · `size_download` 19 · `cf-cache-status` ≠ HIT. C-8: 그 요청의 Traefik 줄 `OriginStatus` 0 · RouterName 없음 · pod 로그 0줄 | — |
| (인계) VD-L9 · CN 음성 · 상류 X-Request-ID · 가짜 자격 | O-8 INFO · C-8 INFO | 합격선 아님 — VD-T076-3 · 4 · 5 · 8 | — |

**report.md 편차 후보**(마감 `/finish`가 report.md 「편차」 절로 옮긴다):

| 번호 | 내용 | 근거 |
|---|---|---|
| 6(이어받음) | m2m 무헤더 = Access **401**(text/html · redirect 없음) · admin 무자격 = **302** — 문면 · spec :109의 403과 다르다 | 계약 C11(T075 보정 2026-11-20) · access.tf `service_auth_401_redirect = true` |
| 7 | 생성 경로 `tests/fixtures/generated/apps/sample-pod`(문면 `…/generated/sample-pod`) — 템플릿 path 의존성 `../../packages/django-common`이 두 단계 위 형제를 요구 | t072-design.md 인계 · contracts/pod-template.md :7 |
| 8 | spec :137 「`compose.dev.yml`에서 `pytest`」 — 실제는 testcontainers(compose 불필요) | FR-035 · quickstart §US6 |
| 9 | SC-004 「outbox → Kafka 5초 내」를 직접 재는 시험 · 소유 과제가 없다 — 대리 측정 + 구조 근거로 둔다 | test_outbox.py.jinja(수신 상한 30 s) · events.md(폴링 500 ms) |
| 10 | AC5 「OTLP 트레이스가 Alloy로 전송」 SKIP — Alloy 미배포 | gitops `platform/monitoring` 빈 뼈대 · T096 · T098 · T102 |
| 11 | FR-044 · T044 문면 「e2e-reader 정책 = `kv/data/platform/authentik/e2e` read」 → 두 경로(UD-15) | D2-2 |
| 12 | AC6 「Authentik 비밀 주입」 — US6 시점 api_token · openfga는 sentinel(면제) | 계약 C6 · C8 · T081–T083 |

## 2. 결정

### D1 범위 · 산출물
- 모노레포만 바꾼다. **gitops 변경 0**(라이브 대상은 #63 · #64가 배포했고 #65가 문서를 맞췄다).
- 산출물:
  - `infra/vault/policies.tf`(e2e-reader +1 경로 · eso-platform deny 2줄) · `tests/infra/tofu.tests.ps1`(vt-14 · vt-16 — 먼저 빨강) · 계약 · 규칙 · 런북 · quickstart 보정(§4).
  - `design/t076-blocks/`: 운영자 블록 W-7 · O-9 · O-10, tester 블록 L-8 · O-8 · C-8, 하네스 둘(`harness-op.ps1` · `harness-tester.ps1`), README.
  - 에이전트 층: `.claude/agents/tester.md` 「Credentials」 절 · `.claude/rules/infra.md` 금지 문장 · `k8s-security.md` · `infra-builder.md` 자격 범위 줄 · `.claude/settings.json` deny 2줄(+ parity 시험 개수) — 각 KR 미러.
  - tester 보고 `research/<라이브 날짜>-e2e-us6-t076.md`(tester가 글로 돌려주고 컨트롤러가 저장) · build-notes 「## T076」 · 런북 §3 · §4 「T076」 기록 칸 · 학습 로그 `content/tmp/003-t076/` · tick.
- 닫힌 T075 블록 · 하네스는 고치지 않는다. O-8 · W-7은 T075 블록의 **바이트 사본에서 파생**하고, 닫힌 T075 하네스를 다시 돌려 결과가 그대로(359/359 · 단언 11359)이고 `t075-blocks/` diff가 0임을 보인다(W-6/T057 선례).
- 함께 처리하는 작은 후속: `tests/scripts/publish-pod.tests.ps1:82` 주석 「gitops promote.yml:91」 → 줄 번호 없는 앵커(T075 문서 정합 리뷰 R-7) · gitops #65(cb3ba13) 기록(build-notes).

### D2 자격 경로(UD-15 · UD-16)
1. **시드 W-7(운영자 · 1회)**: tofu `infra/cloudflare` 출력 `service_tokens`의 `tester-m2m`에서 `client_id` · `client_secret` 둘만 변수로 받아 꼴을 판정한다(id `\A[0-9a-f]{32}\.access\z` · secret `\A[0-9A-Za-z_-]{54}\z` — T075 L4 실측 꼴). 그다음에 Vault 토큰을 묻는다(tofu 실행 중 `VAULT_TOKEN` 0). `kv/platform/access/tester-m2m`의 상태(absent · live · dead)를 판정해 absent면 `-cas=0`으로 쓰고(JSON stdin · 키 정확히 둘), live면 저장값과 SHA-256 Ordinal 비교 — 같으면 「이미 있음 · 같음」으로 건너뛰고 다르면 멈춘다(회전 = T084). 쓴 뒤 되읽어 `current_version` +1 · 키 집합 · 해시 일치를 판정한다(값 · 해시 출력 0). 응답 유실은 재판정한다. T075 `w2-kv-seed.ps1`의 원칙 (a)–(h)를 그대로 물려받는다(B-10).
2. **정책(운영자 apply)**: `infra/vault/policies.tf`
   - `e2e-reader`에 `path "kv/data/platform/access/tester-m2m" { capabilities = ["read"] }` 한 줄(정확한 경로 · 와일드카드 0 · metadata 경로 0).
   - `eso-platform`에 `path "kv/data/platform/access/*" { capabilities = ["deny"] }` · `path "kv/metadata/platform/access/*" { capabilities = ["deny"] }` 두 줄 — **「ESO 밖」을 관례가 아니라 Vault ACL로 강제한다**(B-06 · A-13③). eso-platform은 `kv/data/platform/*`를 읽고 store `vault-platform`은 플랫폼 ns 12곳에 열려 있어, 시드 뒤에는 ExternalSecret 하나로 tester-m2m이 K8s Secret이 될 수 있었다. 더 긴 경로의 규칙이 이기므로(Vault 정책 우선순위) 나머지 `platform/*` 읽기는 그대로다. 지금 `platform/access/*`를 읽는 ExternalSecret은 0이다.
   - 시험(TDD — 먼저 빨강): vt-16 = e2e-reader 경로 정확히 둘 {`kv/data/platform/authentik/e2e`, `kv/data/platform/access/tester-m2m`} · 와일드카드 0. vt-14 = 「capabilities 정확히 `["read"]`」 규칙에 예외 정확히 하나 — eso-platform의 deny 두 줄(경로 글자 정확히 그 둘). 다른 정책의 deny · 다른 deny 경로는 FAIL. 판정은 각 그룹의 `PASS vt-14:` · `PASS vt-16:` 줄로 한다(같은 스위트의 `[plan]` FAIL은 운영자 OCI 자격 몫 — 기대된 것 · A-14②).
   - 운영자: `tofu -chdir=infra/vault plan "-out=t076.tfplan"` → 컨트롤러가 요약을 확인(`vault_policy.this["e2e-reader"]` · `["eso-platform"]` in-place update 2 · 그 밖 0) → `tofu -chdir=infra/vault apply t076.tfplan` → plan 파일 삭제(B-10 · infra.md 「never apply an unreviewed plan」).
3. **Vault 로그인 토큰 O-9(운영자 · 라이브 창마다 1번 — UD-16)**: 관리자 kubeconfig로 `kubectl create token agent-view -n kube-system --audience vault --duration=1h`를 변수로만 받는다. 클레임을 판정한다: `aud` = 정확히 `["vault"]` · `sub` = `system:serviceaccount:kube-system:agent-view` · `exp − iat` = 3600 ± 10 · `iat`가 지금 ± 120 s. 통과하면 DPAPI(CurrentUser — `ConvertFrom-SecureString`)로 `%LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt`에 쓴다(덮어쓰기). 출력은 `exp`(UTC)와 `~`로 줄인 파일 경로뿐이다. `-Clear` 모드는 그 파일을 지운다(세션 끝). 이 JWT는 K8s API에 쓸 수 없고(audience 불일치) 1시간 뒤 무효다.
4. **음성 대조 O-10(운영자 · 정책 · 시드 전에 1회 — B-02)**: 관리자 kubeconfig로 audience를 주지 않은 agent-view 토큰(`--duration=10m`)을 발급해 e2e-reader 로그인(`POST /v1/auth/kubernetes/login`)에 넣는다. **거부돼야 PASS**다. 통과하면(= 지금 에이전트의 8h 토큰이 이미 Vault 자격) 받은 Vault 토큰을 그 자리에서 revoke하고 FAIL — 정책 · 시드로 넘어가지 않고 멈춰 보고한다. JWT 전송 전 `sys/seal-status`의 `cluster_name` = `vault-cluster-d3b29227`(bootstrap.md 「git 밖 라이브 상태」)을 확인한다.
5. **규칙 · 역할 문서(영문 정본 + KR 미러)**:
   - `.claude/agents/tester.md` 본문에 「## Credentials」 절(Claude · Codex가 함께 읽는 계약 — Codex `tester.toml`은 본문을 읽으라고만 하므로 바꾸지 않는다): 클러스터는 `agent-view` kubeconfig(읽기 · port-forward)만 · `tester-m2m`은 **검토된 `design/t076-blocks` O-8 블록 안에서만**, 컨트롤러 지시문이 그 블록을 지명할 때만 · 값은 그 블록 프로세스의 메모리(변수 또는 그 프로세스의 환경)에만 — 출력 · 파일 · argv · 보고 0 · 손으로 `vault` · `curl`에 자격 헤더 · kubeconfig나 토큰 출력 금지 · 블록이 실패하면 재시도 방식을 바꾸지 않고 FAIL로 보고 · 노출이 의심되면 멈추고 보고(회전은 운영자) · 관리자 kubeconfig · tofu · `~/.ssh` · `~/.oci` · age 키 금지.
   - `.claude/rules/infra.md` 「Credentials」에 금지 쪽 한 줄: 「Only the tester agent, and only inside the reviewed `design/t076-blocks` O-8 block, reads `kv/platform/access/tester-m2m` through role `e2e-reader`; no other agent (controller, builders, reviewers, Codex sessions) logs in to Vault or reads that path; values stay in the block process's memory — never in tool output, files, argv, or reports; on suspected exposure stop and report; any other Vault path or role means stop and ask (UD-15, 2026-11-20).」 획득 수단(audience · 파일)은 런북 §12와 블록에만 적는다(B-04).
   - `k8s-security.md`(approval-review 경계) · `infra-builder.md`의 「에이전트 자격 = agent-view · svc-verify」 줄에 UD-15 예외 한 줄(tester · O-8 블록 한정) — 뒤의 승인 · 마감 리뷰가 위반으로 오판하지 않게(A-6).
   - `.claude/settings.json` `permissions.deny`에 `Bash(vault *)` · `PowerShell(vault *)` 두 줄(심층 방어 — 블록은 vault CLI를 쓰지 않는다 · D4). `tests/agents/codex-parity.tests.ps1`의 deny 개수 단언 27 → 29.
6. **컨트롤러는 Vault에 로그인하지 않는다.** 값 읽기는 tester의 O-8 안에서만 한다. 정책이 설계대로인지는 O-8이 읽기 전에 `sys/capabilities-self`로 판정한다(D4 ⑧ — B-02).

### D3 블록 규약
- T075 블록 규약(README §1)을 물려받는다: 최상위 `& { }` 한 문 · 빈 줄 · BOM · CR · TAB 0 · `Set-PSDebug -Off` · 세션 고정 문장 · `try`/`finally` 하나 · 출력은 `Write-Host`/`Write-Warning`뿐 · 응답에서 온 문자열은 `\p{Cc}` → `?` · 160자 자름 · 판정 불가 = FAIL · 모듈 로깅 4키 가드 + 실효 상태 확인(KB-2 · KB2-1)이 첫 단계 · 자격이 든 값은 출력 · 파일 · argv · 클립보드 0.
- **운영자 블록(W-7 · O-9 · O-10)**: T075와 같이 가려진 `Read-Host` 정지점(타자 단어)으로 사람이 관문이다. 읽기 판정과 변경을 한 블록에 섞지 않는다(O-10은 판정만 · W-7은 상태 판정 뒤 정지점을 거쳐 쓴다).
- **tester 블록(L-8 · O-8 · C-8) — 에이전트 실행 계약(A-1 · B-03)**: 에이전트 셸은 비대화형이라 `Read-Host` **0**. 입력은 `param()`뿐(`-ExpectedSha` · `-ExpectedRevision` · `-Since` · `-Nonce` — 각각 정규식으로 네트워크 호출 전에 판정, 아니면 아무것도 보내지 않고 중단). 호스트 · 경로 · URL · kubeconfig 경로(`Join-Path $HOME '.kube\agent-view.yaml'`) · JWT 파일 경로는 블록 리터럴이고 정적 관문이 고정한다. 끝 줄 `<블록>=PASS n/n` 또는 `<블록>=FAIL k/n`, 종료 코드 0은 전부 PASS일 때만. 실행 꼴: `pwsh -NoProfile -File '<절대 경로>' <파라미터>`(Git Bash에서).

### D4 O-8 `o8-probe-identity-m2m.ps1`(tester 2차 · 자격 블록)
T075 `o5-probe-identity-m2m.ps1` 바이트 사본에서 파생한다. 바꾸는 것:
1. 입력: `-ExpectedSha`(`\A[0-9a-f]{40}\z`)뿐. 한 번 실행으로 **dev → prod 두 env**를 모두 판정한다(Vault 로그인 1회 · 자격 읽기 1회).
2. 가드: O-5의 모듈 로깅 · 실효 · 환경 변수 목록(`SSL_CERT_*` · `CURL_CA_BUNDLE` · `SSLKEYLOGFILE` · `*_PROXY` 대소문자 무관)에 더해 — `VAULT_*` 이름이 하나라도 있으면 멈춘다 · Transcription 정책(`…\PowerShellCore\Transcription` · `UseWindowsPowerShellPolicySetting`=1이면 Windows 쪽 둘)이 켜져 있으면 멈춘다 · `TF_*` 검사와 tofu 경로는 **뺀다**(tofu 호출 0 — infra.md의 유일한 예외 밖).
3. 실행 파일: `curl.exe` · `kubectl.exe`의 해석 경로가 저장소 아래이거나 `TEMP`/`TMP` 아래면 멈춘다(INFO가 아니라 판정 — B-03②). curl ≥ 7.84 · 모든 curl 첫 인자 `-q`.
4. kubeconfig: 리터럴 경로가 있고 `kubectl --kubeconfig <리터럴> auth whoami -o jsonpath='{.status.userInfo.username}'` = `system:serviceaccount:kube-system:agent-view`가 아니면 멈춘다.
5. JWT: 리터럴 파일이 없으면 「운영자 O-9 필요」로 멈춘다. `ConvertTo-SecureString`으로 복호해 변수에만 둔다. 꼴(점 둘 · base64url) · 클레임(`aud` = `["vault"]` · `sub` = agent-view · `exp`가 지금 + 60 s 뒤 · `exp − iat` ≤ 3610)을 판정하고 `INFO jwt exp=<UTC> 남은 <n>분`만 낸다.
6. port-forward: 빈 포트를 골라 `kubectl --kubeconfig <리터럴> -n vault port-forward svc/vault <port>:8200`을 백그라운드 프로세스로 띄우고 `finally`에서 끈다. 응답할 때까지(≤ 15 s) 무자격 `GET /v1/sys/seal-status`를 기다려 `sealed` = false · `cluster_name` = `vault-cluster-d3b29227`이 아니면 JWT를 보내지 않고 멈춘다(B-03⑤ · 운영자 창 C의 18200과 부딪히지 않는다 — A-9).
7. **Vault는 curl → HTTP API만**(vault CLI 0 — `~/.vault-token` · 토큰 도우미 · `VAULT_*` 면이 없다 · B-03④): 로그인 `POST /v1/auth/kubernetes/login` 본문 `{"role":"e2e-reader","jwt":…}`를 stdin(`--data-binary @-`)으로 — 응답의 `auth.client_token`은 변수로만, `auth.policies`에 `e2e-reader`가 있는지 · `lease_duration` ≤ 3600인지 판정. JWT 변수는 로그인 직후 지운다.
8. **권한 관문**: `POST /v1/sys/capabilities-self`(토큰 헤더는 stdin `-H @-` · 본문 경로 목록은 비밀 아님)로 — `kv/data/platform/access/tester-m2m` = `["read"]` · `kv/data/platform/access/tester-k8s` = `["deny"]` · `kv/metadata/platform/access/tester-m2m` = `["deny"]` · `kv/data/platform/authentik/e2e` = `["read"]` · `kv/data/prod/db/identity_admin/app` = `["deny"]`. 하나라도 다르면 **읽지 않고** 멈춘다(정책이 설계와 다르다 · VD-T076-9).
9. 읽기: `GET /v1/kv/data/platform/access/tester-m2m`(토큰 헤더 stdin) → `data.data` 키가 정확히 {`client_id`, `client_secret`} · 꼴(D2-1과 같은 정규식)이 아니면 Access로 아무것도 보내지 않고 멈춘다.
10. 탐침(env마다 — 호스트 `identity-m2m-<env>.joshuatech.dev` · 실행마다 nonce `t076-<yyyyMMddTHHmmssZ>-<6 hex>` · 모든 요청에 쿼리 `?t076=<nonce>`):
    - 판정 a `/health`: 자격 헤더 + 비밀 아닌 `X-Request-ID: <nonce>-<env>-health` → 200 · 본문 `status` ok · `checks` 정확히 {db, dragonfly, kafka_producer} 모두 ok · `git_sha` = `-ExpectedSha` · `cf-cache-status` ≠ HIT. 응답 `x-request-id`가 보낸 값과 같은지는 INFO(VD-T076-4).
    - 판정 b–e `/admin/` · `/webhooks/authentik` · `/healthz` · `/ready`: 자격 헤더 → 404 · 미디어 타입 `text/plain`(매개변수 앞 · 대소문자 무관) · 본문 정확히 한 줄 `404 page not found` · `size_download` = 19 · `cf-cache-status` ≠ HIT(D10 기준값).
    - INFO(합격선 아님): `/apix` · `/sessionsX` → 403 + `application/problem+json` `type`(VD-L9 글자 접두 → pod) · `/health/` → 404 Traefik 꼴(Exact) · `/tenants/me` → 403 `type`(CN 음성 — tester-m2m은 BFF CN이 아니다) · 가짜 자격(비밀 아닌 고정 값 `00000000000000000000000000000000.access` · 54자 `A`) `/health` → Access 응답 코드(VD-T076-8 — 예외 경로 · A-12).
    - 요청마다 `INFO <id> at=<UTC> cf-ray=<값>`(C-8 대조용).
    - `-w` 허용 목록: `%{http_code}` · `%{content_type}` · `%{size_download}` · `%header{x-request-id}` · `%header{cache-control}` · `%header{cf-cache-status}` · `%header{cf-ray}` — 모두 비밀이 아니다. `Set-Cookie`는 읽지도 내지도 않는다(VR-12 그대로 — CF_Authorization VD는 T092).
11. `finally`: 토큰이 있으면 `POST /v1/auth/token/revoke-self`(헤더 stdin) → `INFO vault token revoked(<코드>)` · port-forward 종료 · 자격 · JWT · 토큰 변수와 이 실행분 `$Error` 정리 · 네이티브 stderr는 정제해 160자 이하만.
12. 끝 줄 `o8=PASS 10/10`(env마다 a + b–e 다섯) · 첫 줄 근처에 `INFO o8 start=<UTC> nonce=<nonce>`(C-8 입력).

### D5 C-8 `c8-correlate-logs.ps1`(tester 2차 · 비밀 0)
- 입력: `-Since`(UTC ISO 8601 — O-8의 start) · `-Nonce`(O-8의 nonce 꼴 정규식).
- Traefik: `kubectl --kubeconfig <리터럴> -n kube-system logs deploy/traefik --since-time=<Since>`(Traefik 복제가 1이 아니면 멈춘다)의 JSON 줄 가운데 `RequestHost` ∈ {`identity-m2m-dev.joshuatech.dev`, `identity-m2m-prod.joshuatech.dev`} 이고 `RequestPath`에 `t076=<Nonce>`가 든 줄만 고른다. **투영 필드만 낸다**: `StartUTC` · `RequestHost` · `RequestMethod` · `RequestPath` · `DownstreamStatus` · `OriginStatus` · RouterName 유무(값 아님) · `request_Cf-Ray`. `request_Cf-Connecting-Ip`(운영자 공인 IP) · `request_User-Agent` · `ClientHost` · `ClientAddr` · `ClientUsername`은 어디에도 내지 않는다(B-08).
- 판정(env마다): 404 네 경로 각각 정확히 한 줄 · `DownstreamStatus` 404 · `OriginStatus` 0 · RouterName 없음 → PASS(VD-T076-2). `/apix` · `/sessionsX` 403 줄은 RouterName 있음 · `OriginStatus` 403이면 INFO(VD-L9). `request_Cf-Ray`는 O-8 INFO의 `cf-ray`와 tester가 대조한다(VD-T076-5).
- pod: `kubectl … -n jt-<env> logs deploy/identity-admin -c web --since-time=<Since>`에서 `request_id`가 `<Nonce>-<env>-health`인 줄의 `request_id` · 메서드 · 경로 · 상태 코드만(VD-T076-4) · 404 네 경로(`t076=<Nonce>`가 든 경로)의 pod 줄 0 → PASS(pod에 닿지 않았다).
- 끝 줄 `c8=PASS 10/10`(env마다 404 넷 + pod 0줄 하나).

### D6 L-8 `l8-live-identity-admin.ps1`(tester 1차 · 비밀 0)
입력 `-ExpectedRevision`(gitops main 40 hex — 컨트롤러가 디스패치 직전에 `git -C D:/code/platform-gitops fetch` 뒤 `rev-parse origin/main`으로 준다). 리터럴 kubeconfig · 무자격 curl만. dev · prod마다:
- ⓪ Application `identity-admin-<env>`: Synced · Healthy · `status.sync.revision` = 입력 · `operationState.phase` = Succeeded.
- ① ExternalSecret `identity-admin-env` · `identity-admin-migrate`: Ready=True(SecretSynced).
- ② ES 스펙: `-env` = store `vault-<env>` · template 키 정확히 11(목록은 gitops cb3ba13 base에서 빌더가 리터럴로 옮긴다) · 원격 키에 `/owner` 0 · 모든 원격 키가 `<env>/`로 시작(prod에 `dev/` 잔재 0). `-migrate` = template 키 정확히 {`DATABASE_OWNER_URL`} · 원격 키 `<env>/db/identity_admin/owner` · PreSync · `BeforeHookCreation` · wave가 Job보다 앞.
- ③ 워크로드(Deployment `identity-admin`(init `startup-check` · `web` · `relay`) · Deployment `identity-admin-celery` · Job `identity-admin-migrate`): pod `runAsNonRoot` true · `runAsUser`/`runAsGroup` 10001 · `seccompProfile` RuntimeDefault · `automountServiceAccountToken` false · init 포함 모든 컨테이너 `allowPrivilegeEscalation` false · `capabilities.drop` [ALL] · `readOnlyRootFilesystem` true · `/tmp` emptyDir 마운트 · web 프로브(liveness GET `/healthz` period 20 · readiness GET `/ready` period 5 · startup GET `/ready` 30 × 5 · 셋 다 timeout 3) · relay = liveness tcpSocket 9464만 · 어느 프로브도 `/health`를 쓰지 않는다 · **`-migrate` 분리**: Deployment 둘의 envFrom · secretKeyRef · volumes에 `identity-admin-migrate` 참조 0 · Job의 Secret 참조는 `identity-admin-migrate`뿐. (기대값은 gitops cb3ba13 base · 계약 pod-template.md에서 빌더가 확인해 옮긴다. 원본과 다르면 리터럴을 고치지 말고 보고한다.)
- ④ `kubectl logs deploy/identity-admin -c startup-check`에 `startup_check: OK` 줄(그 줄만 낸다 — 런타임에 `DATABASE_OWNER_URL`이 있으면 실패하는 장치의 증거).
- ⑤ 무자격 curl(`-q` · 리다이렉트 미추적): m2m `/health` → 401 · Location 없음(편차 6). admin `https://admin.joshuatech.dev/identity-admin/admin/` → 302 · Location 호스트 = `joshua-tech.cloudflareaccess.com` · 경로 접두 `/cdn-cgi/access/login/` — `scheme://host/path`만 내고 쿼리(meta 토큰)는 내지 않는다(ingress.tests.ps1 `Test-AccessLocation` 꼴 · B-09). admin은 INFO(US4 AC6).
- 끝 줄 `l8=PASS n/n`.

### D7 운영자 블록 파일
| 블록 | 파생 원본 | 창 · 자격 | 출력 |
|---|---|---|---|
| `o10-vault-audience-negative.ps1` | O-5 가드 · W-2 Vault 판정 | 창 ① · 관리자 kubeconfig · Vault port-forward(창 C 18200) | `o10=PASS`(로그인 거부) · 통과면 revoke 결과 + FAIL |
| `w7-seed-tester-m2m.ps1` | `w2-kv-seed.ps1` 바이트 사본 + O-1/O-5 tofu 추출 | 창 ① · tofu 상태 자격 + Vault root(→ T084 뒤 OIDC admin) | `w7=OK absent→v1` · `이미 있음 · 같음` · 멈춤 사유 |
| `o9-issue-vault-jwt.ps1` | O-5 가드 | 창 ② · 관리자 kubeconfig | `o9 issued exp=<UTC> file=~\AppData\Local\jt-e2e\vault-e2e-reader.jwt` · `-Clear` → `o9 cleared` |
- O-7(Secret 키 이름)은 새 블록을 만들지 않고 런북 §3 T075의 go-template 명령(quickstart §US6 ③)을 dev · prod 둘 다 돌린다 — T075에서 prod는 기록되지 않았다(F3-23).

### D8 하네스
- `harness-op.ps1`(W-7 · O-9 · O-10)과 `harness-tester.ps1`(L-8 · O-8 · C-8) — 빌더 둘이 병렬로 쓰므로 파일을 나눈다. T075 harness의 모의(tofu · vault · kubectl · curl · Read-Host)를 파생한다.
- **HTTP 모의는 Ingress 표를 모델로 갖는다**(F3-7 — O-5 모의는 모델링하지 않은 경로를 다 404로 돌려 거짓 PASS를 만든다): m2m 호스트 = `/api` · `/session` · `/sessions` · `/tenants` Prefix(글자 접두) · `/health` Exact · 그 밖 Traefik 404(`text/plain; charset=utf-8` · 19 B) · pod 규칙(헬스 셋 · 웹훅은 Access 면제 · CN 불일치 403 `problem+json` · 존재하지 않는 경로 pod 404 `problem+json`) · Access(무헤더 401 · 가짜 자격 401 · 유효 자격 통과).
- 반드시 넣을 사례: 정상 PASS · pod `problem+json` 404 → FAIL · `/healthz` 200(Prefix로 넓힌 변이) → FAIL · `/admin/` 403(경로가 열림) → FAIL · `cf-cache-status` HIT → FAIL · 자격 거부 401/403 → FAIL · 본문 20 B(줄바꿈 다름) → FAIL · Vault seal-status cluster_name 다름 → JWT 0 전송 · capabilities 다름(tester-k8s read) → 읽기 0 · kv 키 셋 · 꼴 아님 → Access 0 전송 · JWT 만료 · aud 다름 → 중단 · `VAULT_*`/프록시 환경 변수 → 중단 · 실행 파일이 저장소/TEMP 아래 → 중단 · 입력 꼴 아님 → 보낸 것 0 · 제어 문자 → `?` · 값 · 쿠키 · JWT · 토큰 노출 0(모든 사례에서 출력 · 파일 스캔) · finally revoke · port-forward 종료 · C-8 투영 밖 필드 출력 0(IP · UA 든 로그 사례) · O-10 로그인 통과 → revoke + FAIL · W-7 live 다름 → 멈춤 · 응답 유실 재판정.
- 정적 관문 ST-*: tester 블록 `Read-Host` 0 · `param` 집합 정확 · curl 호출 꼴 · `-w` 글자 고정 · curl 금지 플래그(`-v` · `-i` · `-D` · `-c` · `-b` · `--trace*` · `-L` · `--location*` · `-x` · `--proxy` · `-K` · `--config` · `-n` · `--netrc`) · vault CLI · tofu 0(O-8 · C-8 · L-8) · 리터럴 호스트 · 경로.
- 닫힌 T075 하네스 재실행 = 359/359 · 11359 그대로 · `git diff --stat specs/003-platform-foundation/design/t075-blocks` 빈 출력.

### D9 로컬 경로(tester 1차)
- 선행(컨트롤러 · 디스패치 직전): arm64 binfmt 등록 `docker run --privileged --rm tonistiigi/binfmt@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0 --install arm64` — 근거 줄 「installing: arm64 OK」 + emulators 목록의 `qemu-aarch64`(buildx Platforms 표시는 근거가 아니다 · build-notes T073 ⓪).
- ① 템플릿 하네스 전체: `JT_SAMPLE_POD_ROOT=tests/fixtures/generated` · `JT_KUSTOMIZE` · `JT_KUBECONFORM` = `D:/code/joshuatech_ver2/.superpowers/bin/*.exe` · `KUBECONFORM_CACHE` = 저장소 밖 · `uv run --directory templates/django-pod --locked pytest -v --junit-xml=<저장소 밖 경로>` — 다른 하네스 · pod 스위트와 동시에 돌리지 않는다. 증거 = 요약 줄 · gen-9 · 10 · 12 · 19 · 21 · 22 · 33 · 34 PASS 줄 · `tests/fixtures/generated/harness-stages.log`. 10분을 넘을 수 있으므로 백그라운드로 돌리고 출력은 하네스 루트 밖 파일로 받는다(하네스는 재실행 때 루트를 비운다 — A-12).
- ② 보존 트리 생성물 pytest: `uv run --directory tests/fixtures/generated/apps/sample-pod --locked pytest -v --durations=0` + `--co -q`(수집 목록) — 넓히는 옵션(`--tb` · `-l` · `--show-capture` · `PYTEST_ADDOPTS` · `-o`) 금지. AC3 대리 측정 = `test_relay_delivers_both_tenants_to_kafka` call 시간.
- ③ arm64 이미지: `docker buildx build --platform linux/arm64 --load -f tests/fixtures/generated/apps/sample-pod/Dockerfile -t sample-pod:t076 tests/fixtures/generated` → `docker image inspect sample-pod:t076 --format '{{.Os}}/{{.Architecture}} {{.Config.User}}'` = `linux/arm64 10001:10001`.
- ④ identity-admin 스위트(quickstart §US6): `uv run --directory apps/identity-admin --locked pytest -q` — AC6 「이 템플릿으로 생성된 pod」의 계약 시험.
- 표류: 생성할 때마다 `uv lock`이 「3 days」 숙성 창으로 다시 해석한다. 빨강이면 FAIL로 보고하고 고치지 않으며 판 차이(uv.lock)를 기록한다.
- 쓰기 범위: `tests/fixtures/generated/**`(gitignore) · 저장소 밖 임시. 무시 대상 캐시(`templates/django-pod/.venv` · `.pytest_cache`) · Docker 이미지 · 빌드 캐시는 시험 실행의 부산물이다. tester가 남길 파일은 `tests/fixtures/generated` 밖에 둔다.

### D10 404 판정 기준값(컨트롤러 실측 2026-11-20 09:43Z — 자격 0)
라우터 없는 공개 호스트 `api.joshuatech.dev`로 무자격 `curl -q` 3건(`/t076b094331` · `/healthz?t076=…` · `/health`): 셋 다 **404 · `text/plain; charset=utf-8` · 19 B · 본문 `404 page not found` + LF(sha256 `b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793`) · `cf-cache-status` DYNAMIC · `server` cloudflare**. m2m 호스트의 Traefik 404가 이와 같은지가 VD-T076-6이다(Access를 지난 뒤에도 같아야 한다).

### D11 무헤더 · admin — D6 ⑤.

### D12 ES 2 주입 · owner 자격 없음 — 증거 사다리
⓪ Application(revision) → ① ES Ready → ② ES 스펙(키 · 원격 키) → ③ 워크로드 참조 · 보안 컨텍스트 · 프로브 → ④ `startup_check: OK` → ⑤ data 하네스 env-1(`tests/platform/data.tests.ps1` — 판정은 env-1 줄. 다른 줄의 FAIL이 svc-verify 세션 만료 같은 환경 원인이면 범위 밖으로 적는다 · 운영자가 창 ②에서 세션을 갱신하면 전체 PASS를 기대) → ⑥ Secret 키 이름(운영자 O-7 · dev · prod — 출력을 컨트롤러가 tester에 넘긴다). ⓪–⑤는 tester 1차가 낸다.

### D13 tester 디스패치 두 번(B-07)
- **1차(Vault 능력 없음)**: D9 ①–④ · L-8 · `tests/platform/run-platform-tests.ps1`(cluster · ingress · data · kafka) · O-7 출력 확인 · 무헤더.
- 1차가 끝난 뒤 운영자 O-9(1시간 JWT).
- **2차(1시간 안)**: O-8 → C-8(`-Since` · `-Nonce` = O-8 출력). 실패하면 블록 출력 그대로 FAIL로 보고하고, 컨트롤러가 원인을 본 뒤 같은 시간 안에서 다시 디스패치한다. 끝나면 운영자 O-9 `-Clear`.
- 지시문 골격(§7)을 쓴다. tester는 보고를 글로 돌려주고 컨트롤러가 `research/<날짜>-e2e-us6-t076.md`에 저장한다.

### D14 실행 순서 · 창
1. 빌드(§6) → 리뷰 → 수정 → 컨트롤러 커밋 → push(사용자 확인).
2. **창 ①(운영자 · 라이브 변경)**: 터널 · Vault port-forward(창 C) → O-10(음성 대조 — FAIL이면 여기서 멈춤) → `tofu -chdir=infra/vault plan "-out=t076.tfplan"` → 컨트롤러 확인 → apply → plan 파일 삭제 → W-7.
3. **창 ②(관찰 준비)**: agent-view 8h 토큰 재발급(평소 꼴 그대로) · svc-verify 세션 · O-7 dev · prod 출력.
4. 컨트롤러: binfmt 등록 · gitops fetch → `-ExpectedRevision` · 기대 git_sha 확인 → tester 1차.
5. 운영자 O-9 → tester 2차 → 운영자 O-9 `-Clear`.
6. 기록 · tick(D15) → 세션 끝 jt-ops 정리(터널 멈춤 · `%USERPROFILE%\.cloudflared\*-token*` 삭제 · JWT 파일 없음 확인).
- 창은 UD-13 정비(Traefik 재시작 = 액세스 로그 소실)와 SUC 창(일요일 03:00–05:00 KST) 전에 연다. agent-view 토큰이 8h 안에 있고 운영자 터널이 붙어 있어야 C-8이 돈다.

### D15 기록 · tick 관문(A-14①)
- 런북 bootstrap.md §3 「T076」(창 · tester 1차 · 2차 · 관찰 · 기록 칸) · §4 「T076」(O-10 · plan/apply · W-7 기록 칸) · build-notes 「## T076」 · 학습 로그 `content/tmp/003-t076/<날짜>.md`(비밀 · 호스트명 밖 내부 정보 · IP · ID 0).
- **tick 조건**: §1 합격선이 전부 PASS이고, SKIP · 편차가 §1 표 그대로일 때 `- [X] T076`. 그 밖(FAIL · 새 편차)은 사용자 결정.

### D16 받아들인 위험 · 인계
- 받아들인 위험:
  1. 1시간 JWT 파일은 같은 Windows 사용자로 도는 프로세스(에이전트 포함)가 복호할 수 있다 — vault audience 전용(K8s API 불가) · 1시간 · 정책 두 경로 · 지시문 · deny 규칙 · 세션 끝 삭제로 줄인다. 1회용으로 조일지는 `/finish` 전에 사용자에게 여쭙는다(UD-16).
  2. e2e-reader 한 토큰이 e2e 사용자 자격(T077 시드 뒤)과 tester-m2m을 함께 읽는다(같은 SA에 묶인 별도 role로 나눠도 JWT 보유자에게는 차이가 없다 — B-05 · role 「합계 6」 유지).
  3. tester-m2m은 1년 토큰(2027-09-03 만료)이라 노출되면 회전(T084 절차를 앞당김)이 필요하다.
  4. settings.json deny는 Claude 세션에만 걸린다. Codex tester는 같은 tester.md 본문을 읽지만 Windows에서 훅이 디스패치되지 않는다(AGENTS.md 「Windows limitation」).
  5. VD-T071-2(Access가 서비스 토큰 헤더를 오리진까지 넘기는가) — `CF-Access-Client-Id`(비밀 아님)를 Traefik keep 목록에 더하면 잴 수 있으나 인프라 변경이라 범위 밖.
- 인계:
  - T077: tester-m2m은 T076이 시드했다 — tester-k8s만 남는다 · 에이전트에는 `vault` CLI deny가 걸려 있으므로 Playwright의 Vault 읽기는 HTTP API(O-8 꼴)로 하거나 deny를 다시 정한다 · e2e-reader 정책은 두 경로다.
  - T084: tester-m2m 회전 = Cloudflare(tofu) → Vault(`-cas=<n>`) 한 절차 · vault-unseal.md T045 표의 「Access 서비스 토큰 4경로 — 이연」 행.
  - T085: O-9 · O-8 꼴 재사용 · admin 무자격 302(US4 AC6) · `/session/check` 두 번 호출의 cf-cache-status(web-bff 자격).
  - T092: `Set-Cookie: CF_Authorization` 존재 · 수명 VD(쿠키 값 노출 0 설계 필요).
  - T096 · T098 · T102: AC5 OTLP.
  - `/finish`: 편차 후보 6–12 · UD-16 1회용 결정.
  - gitops: eso-platform 정책 글자를 그대로 옮겨 적은 gitops 문서가 있으면(빌더 grep) 문서 정합 후속.
  - 닫힌 t075-design.md의 「tester-m2m 시드 = T077」 문장은 고치지 않는다 — build-notes에 T076 시드를 적는다.

## 3. 블록 명세 요약
D4(O-8) · D5(C-8) · D6(L-8) · D7(W-7 · O-9 · O-10) · D8(하네스)이 정본이다. README(`design/t076-blocks/README.md`)는 파일 표 · 실행 꼴 · 결정 대응 · 하네스 사례 표 · 남은 위험을 T075 README 꼴로 적는다.

## 4. 보정 목록(표식 「T076 보정 2026-11-2x」 · 규칙 · 에이전트 파일은 `(UD-15, 2026-11-20)`)

**빌드 때**
| 파일 | 고칠 것 |
|---|---|
| `infra/vault/policies.tf` | D2-2 · 머리 주석의 「capabilities 정확히 `["read"]`」 규칙에 eso-platform deny 예외 · 「계약 gitops-repo.md:98-101」 줄 번호 → 앵커 |
| `infra/vault/roles.tf` | :4 「hostnames-and-access.md :79」 → 앵커 |
| `tests/infra/tofu.tests.ps1` | vt-14 · vt-16(D2-2) |
| `contracts/gitops-repo.md` | e2e-reader · eso-platform 정책 규약 줄(두 경로 · deny 예외) |
| `contracts/hostnames-and-access.md` | :43 「env로만」 → 「O-8 블록 프로세스 메모리에만」 · :80 e2e-reader 두 경로 · 「유일한 경로」 문장 · 로그인 토큰 = 운영자 O-9(vault 전용 1h · DPAPI 파일 — UD-16) · :82-84 tester-m2m 시드 = T076 W-7 · O-8 안에서만 |
| `data-model.md` | :172 「ESO 밖」 → eso-platform deny로 강제(T076) · 받는 쪽 = O-8 · :273 관계 줄(e2e-reader → tester: authentik/e2e · access/tester-m2m) |
| `quickstart.md` | :14 · :17(보관 · 정책 두 경로 · 토큰 꼴) · §US6 배포 확인 ①(`curl -q` · 기대 401) ②(O-8 블록 실행 꼴로 바꿈 — 손 curl에 자격 0) ③(dev · prod) · 하네스 줄 `-v` |
| `docs/runbooks/vault-unseal.md` | §12 목적 줄 :557 · 절차(O-9 · HTTP API — vault CLI는 운영자만) · 검증 줄 :576(tester-k8s · metadata = deny · 그 밖 403) · 역할 표 :272 · T045 표 :353 Access 행(tester-m2m = T076 W-7) |
| `docs/runbooks/bootstrap.md` | :118 tester-m2m 시드 T077 → T076 · :1067 「설계 :585」 → 앵커 · §3 · §4 새 절 「T076」(기록 칸 빈 채로) |
| `.claude/agents/tester.md` · `docs/kr/agents/tester_kr.md` | D2-5 「## Credentials」(미러는 영어 제목 유지) |
| `.claude/rules/infra.md` · `docs/kr/rules/infra_kr.md` | D2-5 금지 문장 |
| `.claude/skills/approval-review/boundaries/k8s-security.md` · `docs/kr/skills/approval-review_kr.md` | 자격 범위 줄에 UD-15 예외 |
| `.claude/agents/infra-builder.md` · `docs/kr/agents/infra-builder_kr.md` | 같음 |
| `.claude/settings.json` · `tests/agents/codex-parity.tests.ps1` | deny 2줄 · 개수 27 → 29 |
| `tests/scripts/publish-pod.tests.ps1` | :82 줄 번호 → 앵커(R-7) |

**실측 뒤**(라이브 결과를 받은 뒤 컨트롤러): 계약 hostnames-and-access.md(m2m 404 출처 · 무헤더 401 dev · prod 재확인) · identity-admin-api.md(Ingress 허용 목록 밖 404 라이브 확인 · VD-L9) · 런북 기록 칸 · quickstart 기대 출력 · build-notes VD 표.

## 5. VD(검증 후 결정)

| VD | 무엇 | 언제 · 어디서 | 어긋나면 |
|---|---|---|---|
| VD-T076-1 | audience 없는 agent-view 토큰은 e2e-reader 로그인이 거부된다 | 창 ① O-10 | 멈춤 · revoke · 사용자 보고(정책 · 시드 진행 안 함) |
| VD-T076-2 | 404 넷이 Traefik 라우터 없음(OriginStatus 0 · RouterName 없음 · pod 0줄) | C-8 | Ingress · 라우터 조사 · tick 금지 |
| VD-T076-3 | VD-L9: `/healthz` · `/health/` 404(Exact) · `/apix` · `/sessionsX` 403(글자 접두 → pod) | O-8 · C-8 INFO | 계약 · Ingress 재검토 |
| VD-T076-4 | 상류 `X-Request-ID`가 응답 · pod 로그 `request_id`에 그대로 | O-8 · C-8 INFO | 기록만 |
| VD-T076-5 | 응답 `cf-ray` = Traefik `request_Cf-Ray` | O-8 ↔ C-8 | 기록만(상관은 nonce로 충분) |
| VD-T076-6 | m2m 호스트 Traefik 404 = D10 기준값 | O-8 | 기준을 실측 꼴로 정정(정정 노트) |
| VD-T076-7 | 저장소 안 루트(`tests/fixtures/generated`)에서 하네스 전체가 돈다 | tester 1차 | 하네스는 고치지 않는다(T072 닫힘) · 루트를 저장소 밖으로 옮겨 다시 · 편차로 적음 |
| VD-T076-8 | 가짜 서비스 토큰 → Access 응답 코드 | O-8 INFO | 기록만 |
| VD-T076-9 | apply 뒤 capabilities = 설계(tester-m2m read · tester-k8s · metadata deny · prod deny) | O-8 ⑧ | 읽지 않고 멈춤 · 정책 조사 |

## 6. 빌드 조각(빌더 opus · 커밋 0 · 컨트롤러가 파일 이름으로 스테이징)

| 조각 | 빌더 | 파일(소유 — 다른 조각은 건드리지 않는다) | 시험 |
|---|---|---|---|
| ① Vault 정책 | infra-builder | `infra/vault/policies.tf` · `roles.tf` · `tests/infra/tofu.tests.ps1` · `contracts/gitops-repo.md` · `data-model.md` · `docs/runbooks/vault-unseal.md` | vt-14 · vt-16 빨강 → 초록(그 줄로 판정) · `tofu -chdir=infra/vault validate`(가능하면) |
| ② 운영자 블록 | infra-builder | `design/t076-blocks/{w7-seed-tester-m2m,o9-issue-vault-jwt,o10-vault-audience-negative}.ps1` · `harness-op.ps1` | `harness-op.ps1` 전부 PASS · 닫힌 T075 하네스 그대로 |
| ③ tester 블록 | infra-builder | `design/t076-blocks/{o8-probe-identity-m2m,c8-correlate-logs,l8-live-identity-admin}.ps1` · `harness-tester.ps1` | `harness-tester.ps1` 전부 PASS |
| ④ 에이전트 층 · 문서 | infra-builder | `.claude/agents/tester.md` · `.claude/rules/infra.md` · `k8s-security.md` · `infra-builder.md` · 각 KR 미러 · `.claude/settings.json` · `tests/agents/codex-parity.tests.ps1` · `contracts/hostnames-and-access.md` · `quickstart.md` · `docs/runbooks/bootstrap.md` · `tests/scripts/publish-pod.tests.ps1` | `tests/agents/codex-parity.tests.ps1` · agent-layer · hook 시험 · `publish-pod.tests.ps1` · run-all의 미러 검사 셋 |
- README · build-notes는 컨트롤러가 빌더 보고를 모아 쓴다. 리뷰는 세 렌즈(자격 · 보안 / 설계 · 계약 정합 + 하네스 변이 / 운영 흐름 · 런북).

## 7. tester 지시문 골격(컨트롤러가 디스패치 때 채운다 — T059 꼴 · A-6)
- §0 상태 · 자격: 피처 디렉터리 · 브랜치 · HEAD · agent-view kubeconfig 경로와 만료 · 쓸 수 있는 것(agent-view · 무자격 curl · 1차는 Vault 0 · 2차는 O-8 블록 안에서만) · 금지(손 `vault` · 자격 헤더를 든 손 `curl` · kubeconfig · 토큰 · JWT 출력 · 관리자 kubeconfig · tofu · `~/.ssh` · `~/.oci` · age 키 · 원시 Traefik 줄 붙여넣기 · 운영자 IP).
- §1 입력: spec US6 절 · 계약 C11 · 편차 후보 6–12 · 생성 경로 · AC3 대리 측정 · AC5 SKIP · AC6 한계 문장 · `-ExpectedRevision` · `-ExpectedSha` · O-7 출력.
- §2 시나리오 ↔ 증거 표(§1 표 그대로).
- §3 순서(1차 D9 → L-8 → 플랫폼 하네스 / 2차 O-8 → C-8) · 실패 시 재시도 방식 바꾸지 않음.
- §4 보고 꼴(tester.md 「Report format」 + 위생 목록: IP · client_id · Location 쿼리 · 원시 로그 줄 · JWT · 토큰 0).

## 8. 실행에서 바뀔 수 있는 것
- 라이브 전에 빌드 리뷰가 블록 명세를 바꾸면 이 문서가 아니라 README · build-notes에 적고, 이 문서에는 정정 노트만 단다.

## 9. 비판 반영표

| 지적 | 처리 | 자리 |
|---|---|---|
| A-1(HIGH) tester 블록 입력 계약 | 채택 — Read-Host 0 · param만 · 종료 코드 · 정적 관문 | D3 · D4 · D8 |
| A-2 VD-T076-1 시점 · 컨트롤러 값 읽기 | 채택 — 컨트롤러 로그인 0 · 권한 관문은 O-8 ⑧ · 음성 대조는 창 ① O-10(정책 · 시드 전) · 로그인 양성은 T044 VD-19 실측 | D2-4 · D2-6 · D4 |
| A-3 · B-01(HIGH) 8h 이중 audience | UD-16으로 해소 — vault 전용 1h JWT | §0 · D2-3 |
| A-4 AC3 이연처 | 채택 — 대리 측정 + 편차 후보 9 | §1 · D9 ② |
| A-5 렌더 단언 목록 | 채택(바꿈) — git archive 렌더 대신 **배포된 객체**를 L-8에서 단언 + 사다리 ⓪ revision. 템플릿 렌더 단언은 하네스 gen-* | D6 ③ · D12 |
| A-6 · B-04 자격 경계 문서 | 채택 — tester.md 본문 · infra.md 금지 쪽 · 리뷰어 범위 줄 · 지시문 §0 | D2-5 · §7 |
| A-7 증거 명령 | 채택 — `-v` · junit · `--co -q` · skipped 0 · `10001:10001` | §1 · D9 |
| A-8 보정 목록 | 채택 | §4 |
| A-9 토큰 수명 · port-forward | 채택 — finally revoke · 블록이 port-forward 소유 · vault CLI 0 | D4 ⑥ ⑦ ⑪ |
| A-10 404 본문 · 상관 키 | 채택 — 기준값 실측(D10) · 쿼리 nonce · cf-ray는 VD | D4 ⑩ · D5 · D10 |
| A-11 AC 표 누락 | 채택 — AC6 한계 문장 · ⓪ · AC5 소유 · env-1 판정 | §1 · D12 |
| A-12 예외 경로 · 표류 · 시간 · 루트 | 채택 — 가짜 자격 INFO · 표류 규칙 · 백그라운드 · 루트 밖 출력 | D4 ⑩ · D9 |
| A-13 문서 정밀도 | 채택 — binfmt 근거 · VD-T071-2 사유 · ESO 밖 강제(deny) · `/sessionsX` · 편차 후보 표 | D9 · D16 · D2-2 · D4 · §1 |
| A-14 절차 정밀도 | 채택 — tick 관문 · vt 판정 줄 · 「프로세스 메모리」 문구 | D15 · D2-2 · D2-5 |
| B-02 음성 대조 · 값 읽기 | 채택 | D2-4 · D2-6 · D4 ⑧ |
| B-03 tester 실행의 관문 · 블록 밖 유출 | 채택 — ①–⑦ · ⑨ · ⑩. ⑧은 settings deny(vault) 두 줄까지 · tester 전용 PreToolUse 훅은 이연(받아들인 위험 4 · T085에서 tester 자격이 넓어질 때 다시 본다) | D3 · D4 · D2-5 · D16 |
| B-05 편차 기록 · 문서 영향 | 채택 — 편차 후보 11 · 정책 확장 선택 근거(받아들인 위험 2) · UD-16으로 :59 · gitops 영향 0 | §1 · D16 |
| B-06 ESO 도달 범위 | 채택(강화) — gitops validate 검사 대신 **eso-platform deny**(Vault ACL) | D2-2 |
| B-07 순서 | 채택 — tester 두 번 · JWT는 1차 뒤 발급 | D13 |
| B-08 원시 로그 | 채택 — C-8 투영 | D5 |
| B-09 admin Location | 채택 — `Test-AccessLocation` 꼴 · quickstart `-q` | D6 ⑤ · §4 |
| B-10 W-7 장치 | 채택 — W-2 원칙 (a)–(h) · plan 파일 · T084 인계 | D2-1 · D2-2 · D16 |
| B-11 외부 동작 가정 | 채택 — 404 기준 실측(D10) · API audience는 UD-16으로 불필요 | D10 |
| B-12 보정 문장 | 채택 | §4 |

## 정정 노트
(과제가 닫힌 뒤 실측과 다른 점을 여기에 덧붙인다.)

### 2026-11-20 — 빌드 r0 리뷰 반영(라이브 전 · §8)
결정 정본 = `.superpowers/t076/decisions-controller.md` 「r0 리뷰 처리」(리뷰 R-S · R-C · R-O — `.superpowers/t076/reviews/R-{S,C,O}-r0.md`) · 블록 글자 · 끝 줄 · 하네스 결과의 정본 = `design/t076-blocks/README.md`. 위 본문은 고치지 않고 여기에만 적는다.
1. **§0 UD-16 · D16-1 「1회용(읽고 바로 지우기)」**: JWT 사본은 `exp`까지 유효하므로 파일 삭제만으로는 1회용이 아니다. 「1회용」 = 짧은 `--duration`(예: 10–15분 · tester 2차 직전 발급) + 사용 뒤 운영자 clear. 전환 여부는 그대로 `/finish` 전 사용자 결정(S-03).
2. **§1 AC6 합격선 「O-8 dev · prod `/health` 판정 8 PASS」**: 「O-8 판정 a dev · prod 2 PASS(200 · status ok · checks 셋 모두 ok · git_sha = 입력 · cf-cache-status ≠ HIT)」로 읽는다. 404 행 = 판정 b–e 8 PASS · 끝 줄 `o8=PASS 10/10`(C-04 — 「판정 8」은 T075 O-5b의 항목 수가 옮겨 온 글이다).
3. **§1 편차 후보 11**: FR-044 · T044에 더해 **FR-049**(eso-platform = `kv/data/platform/*` · `kv/metadata/platform/*` read — deny 두 줄로 좁힘)(C-11).
4. **D2-3 · D4 ⑤ `aud` = 정확히 `["vault"]`**: 문자열 `"vault"` 또는 원소 하나인 배열 `["vault"]`를 받는다(뜻이 같다 — 오직 vault). 관찰한 꼴을 INFO로 낸다 → **VD-T076-10**(아래 13).
5. **D2-3 · D7 · D13 · D14 O-9 `-Clear`**: 블록은 인자를 받지 않는다(최상위 `& { }` · param 0 — T075 운영자 블록 규약). 모드는 가려진 정지점 단어 `issue` · `clear`(끝 줄 `o9 cleared` · 이미 없으면 `o9 nothing-to-clear`)이고, 남는 인자는 아무것도 하지 않고 멈춘다(O-9 · O-10 · W-7 공통)(S-07 · C-02 · RO-02). D7 O-9의 「창 ②」 → 런북 §3 T076 ④-1 · ④-3 · 창 D(RO-12). 운영자 블록은 파일로만 실행한다(붙여넣기 문구 삭제 — C-13).
6. **D2-5**: tester 값 자리 「변수 또는 그 프로세스의 환경」 → **변수만**(환경 변수는 port-forward `kubectl` · `curl`이 물려받는다 — S-05). Credentials에 「O-8 블록 밖에서는 어떤 에이전트도 운영자 발급 Vault 로그인 자료를 열거나 복호 · 복사 · 출력하지 않고, 플랫폼 시험의 무자격 `GET /v1/sys/seal-status` 밖의 요청을 Vault에 보내지 않는다」(S-01 — port-forward 전면 금지는 플랫폼 하네스와 부딪혀 쓰지 않았다) · 「Codex tester는 O-8을 돌리지 않는다(SKIP)」(S-06 · C-09)를 더했다.
7. **D2-5 · §4 보정 목록 누락**: `.agents/skills/approval-review/boundaries/k8s-security.md`(Codex 사본 — codex-parity가 `.claude` 원본과 바이트 일치를 요구)를 빠뜨렸다 → 컨트롤러가 복사(C-01 · RO-01 — HIGH).
8. **D3 tester 실행 꼴**: Git Bash의 코드 페이지 949에서 블록의 한글 판정 · 사유가 깨진다(실측 — 끝 줄 · 종료 코드만 온전) → `chcp.com 65001 >/dev/null; pwsh -NoProfile -File '<절대 경로>' <파라미터>; echo "exit=$?"` · Bash 도구 timeout 600000(블록 최악 ≈ 565 s(rv2 RO2-01 — Forwarding 줄 기다림 ≤ 45 s · 이전 535 s — r1에서 Forwarding 줄 기다림 ≤ 15 s가 더해졌을 때) · 추론 · 끊기면 finally가 돌지 않는다) · 판정은 끝 줄과 종료 코드(RO-04 · RO-08).
9. **D4 ③ 실행 파일**: 경로 판정에 더해 형식 필터 없는 `Get-Command` 첫 해석이 Application이어야 한다(같은 이름 함수 · 별칭 · 프로필 정의 가림 → 멈춤) — 블록 여섯 모두(S-10 확장). `-NoProfile` 판정은 하지 않는다(첫 해석 판정은 외부 명령 이름의 함수 · 별칭 가림만 잡는다 — 프로필이 cmdlet 이름(Get-Command · ConvertFrom-Json 등)을 가리는 것은 실행 꼴 `pwsh -NoProfile`과 받아들인 위험 1(같은 사용자)에 기댄다).
10. **D4 ⑥ port-forward**: 빈 포트를 골랐다 놓고 kubectl이 잡는 사이의 경합과 `localhost`의 `::1` 대체를 없앤다 → `--address 127.0.0.1 svc/vault :8200`(kubectl이 포트를 고른다) · 작업 출력의 `Forwarding from 127.0.0.1:<n> -> 8200` 정확히 한 줄로 포트 확정 · 로그인 직전 작업 Running 재확인(S-04).
11. **D4 ⑩**: X-Request-ID를 모든 Access 요청에 싣는다(대조 키 — `/health`만이 아니다) · 요청별 INFO에 `code` · `ct` · `cfc` 원문(정제)을 더한다(VD-T076-6 근거 — C-05). b–e 판정은 「≠ HIT」 그대로 — STALE 등 캐시 응답은 C-8(Traefik 줄 정확히 1 · request_id)이 막는다.
12. **D5 pod 판정**: pod 로그 `request` 필드는 `<METHOD> <path>`라 쿼리가 없다 — 「`t076=<Nonce>`가 든 경로」로는 pod 줄을 고를 수 없어 늘 빈 판정이 된다. 블록은 `request_id`(`<Nonce>-<env>-<id>`)로 대조하고 **health 대조 키 줄이 있어야 PASS**다(C-03). 따라서 VD-T076-4(§5)가 어긋나면 「기록만」이 아니라 **c8 FAIL → tick 금지 · 사용자 결정**이다. C-8 실패 원인에는 O-8과 C-8 사이 pod 교체 · Traefik 재시작(로그 소실)도 든다(RO-07 e).
13. **§5 VD 표 추가 — VD-T076-10**: K3s TokenRequest가 audience 하나를 배열(`["vault"]`)로 내는가 문자열(`"vault"`)로 내는가(go-jose 직렬화) · O-9 첫 실행 INFO `aud 꼴=…` · 어긋나면 기록만(블록이 두 꼴을 다 받는다).
14. **D6 ② · ③ 리터럴**: `-migrate` 원격 키는 gitops 원본대로 dev = `dev/db/dev_identity_admin/owner` · prod = `prod/db/identity_admin/owner`(위 「`<env>/db/identity_admin/owner`」와 dev가 다르다). Job의 Secret 참조는 자격 Secret(envFrom · secretKeyRef) = `identity-admin-migrate`뿐 · 볼륨 Secret = CA `pg-main-ca`뿐으로 판정한다. 판정 수는 env마다 12 → `l8=PASS 24/24`(C-10).
15. **D6 ③ · D14 기한**: L-8 ③이 읽는 migrate Job은 `ttlSecondsAfterFinished` 604800 s로 지워진다 — 라이브 기한(추론: dev ≈ 2026-11-26 19:1x KST · prod ≈ 2026-11-27 12:3x KST) · 런북 ③-1에서 컨트롤러가 존재 · 완료 시각을 먼저 확인 · 없으면 디스패치 전에 사용자 결정(C-08 · RO-05).
16. **D7 W-7**: 재실행 끝 줄은 「이미 있음 · 같음」이 아니라 `w7=SKIP live-same`(요약 행 「건너뜀(이미 있음 · 같음 …)」)(C-07). root 토큰을 묻기 전에 `vault status`의 `cluster_name`도 판정한다(S-09). 끝의 창 정리 안내는 T076 흐름 — 창 C만 닫고 창 A 터널 · 창 D는 유지(RO-03).
17. **D8 하네스**: 공통 사후 조건에 요청별 헤더 이름 집합 · 바늘 기반 「자격의 길」 · ST-O8 호출 꼴 고정을 더했다(S-02 — r0에서는 비밀 조각을 다른 헤더에 실은 변이가 살아남았다). 「노출 0」의 바늘 = 전체 · base64 · 8자 이상 조각 · SHA-256(7자 이하 조각은 범위 밖 — S-08).
18. **D2-2 시험**: vt-14 · vt-16에 더해 vt-14b(eso-platform heredoc 정확히 4줄 — read 2 · deny 2)를 두었다 · 스위트 단언 61 → 62(C-11).
19. **D13 · §7 tester 1차**: 순서 = 플랫폼 하네스(②-2 svc-verify 1 h 안 — 맨 먼저) → L-8 → D9 ①–④(RO-09). 1차 FAIL은 분류한다 — 환경 원인(세션 만료 · 도구 시간 초과)이면 그 줄만 다시 돌리고 2차로, 제품 · 구성 FAIL(L-8 · D9 ①–④ 빨강)이면 O-9(자격 발급)로 가지 않고 사용자 결정(RO-07 c). `-ExpectedSha` 하나로 dev · prod를 판정하므로 ③-1에서 두 env의 배포 이미지가 같은지 대조한다(RO-07 d). O-10 끝 줄은 운영자가 컨트롤러에게 붙이고, 컨트롤러는 그 줄을 본 뒤에만 plan을 확인한다(RO-07 a).
20. **D16 받아들인 위험 추가**: PowerShell AMSI 메서드 호출 기록 — .NET 메서드 인자(JWT 꼴 판정 · SHA-256 입력 등)가 같은 기계의 AV 공급자에게 넘어갈 수 있다(추론 · 이 PC pwsh 7.6.10 실험 기능 목록에 없음 · 같은 사용자 범위 — S-11).

### 2026-11-20 — 확인 리뷰(rv2) 반영
결정 정본 = `.superpowers/t076/decisions-controller.md` 「rv2 확인 리뷰 처리」(리뷰 R-S · R-C · R-O 2차 — `.superpowers/t076/reviews/R-{S,C,O}-rv2.md` · 판정 approve · approve · approve_with_fixes) · 블록 글자 · 끝 줄 · 하네스 결과의 정본 = `design/t076-blocks/README.md`(§2a 「r2 대응」). 위 본문은 고치지 않고 여기에만 적는다 — 위 8 · 9도 이 리뷰에서 고쳐 썼다(8 = RO2-01 · 9 = S2-02).
21. **D4 ⑥ port-forward(정정 노트 10의 Forwarding 줄)**: Forwarding 줄 기다림 ≤ 15 s · 30회(결정 S-04) → **≤ 45 s · 90회**(0.5 s 간격). 근거: T048 F19(`t048-design.md`) — 워크스테이션 → cloudflared access tcp → 터널 → API 경로의 `port-forward svc/vault` 수립 10–23 s(8회 모두 8 s 초과) · reboot-1 15.7 s(bootstrap.md 재부팅 표) · 같은 경로의 플랫폼 하네스 `tests/platform/reboot.tests.ps1` `$pfReadyWaitSec = 45`(`cluster.tests.ps1` 30 s). 그 뒤의 무자격 seal-status 기다림(≤ 15 s · 30회 — 위 D4 ⑥ 본문의 「≤ 15 s」)은 그대로다. 블록 최악 ≈ 565 s(위 8) — Bash 도구 timeout 600000 안 · 여유 35 s(추론)(RO2-01).
22. **D7 W-7 끝 창 정리 안내(위 16 보완)**: 결과로 가른다 — `w7=OK …`(두 꼴) · `w7=SKIP live-same`일 때만 RO-03 글자(창 C 종료 · 창 A 터널 · 창 D 유지) · 그 밖 전부(`w7=STOP …` · 예외 · 중단 — 기본값)는 「창 정리(T076 — 런북 bootstrap.md §4 T076 실패 표): 창 C port-forward(18200) 는 닫지 않는다(실패 표 조치 — 재실행 · 버전 이력 · cluster_name 조사에 18200 이 필요하다) · 창 A 터널 · 창 D 도 닫지 않는다」. 둘 다 블록 출력의 마지막 줄이다(RO-03 보완 · RO2-02).
23. **D16 인계 T077 · T085(S2-01 · rv2C-02)**: T077 · T085: S-01 문장(tester.md · infra.md 「Credentials」 + KR · k8s-security · infra-builder)은 T076 O-8 블록 하나만 지명하고 그 밖 Vault 요청을 무자격 seal-status로 한정한다 — Playwright의 `kv/platform/authentik/e2e` 읽기(T077) · T085 블록은 검토된 블록을 두고 그 블록을 예외에 더하는 문장 개정(UD-15 범위 확장 = 사용자 결정 · approval-review)이 먼저다. D16 인계의 「HTTP API(O-8 꼴) 또는 deny 재결정」만으로는 부족하다.

### 2026-11-21 — r2 검증(V1 · V2) 반영
결정 정본 = `.superpowers/t076/decisions-controller.md` 「r2 검증 처리」(검증 V1 블록 렌즈 · V2 문서 렌즈 — `.superpowers/t076/reviews/V{1,2}-r2.md` · 둘 다 approve) · 고친 곳의 정본 = `design/t076-blocks/README.md`(§2a 「r2 대응」 · §3 35 · §5.0 · §5.7). 위 8의 이력 구절을 괄호 한정어로 옮겼다(V1-03). 하네스만 바꾼 것(ST-O8 기다림 고리 단언 — V1-01 · V1-02)은 설계와 다른 점이 아니라 README에만 적는다.
24. **D13 · §7 tester 1차 FAIL 분류(위 19 보완 — RO2-04 · V2-04)**: 블록 이름이 아니라 FAIL 사유로 가른다 — 환경 = 터널 · API 일시 오류(`kubectl get … 실패(exit=… · <오류 첫 줄>)`이고 오류 첫 줄이 TLS handshake timeout · i/o timeout · Unable to connect to the server 꼴) · ③-1 뒤 gitops main 이동(L-8 ⓪ revision만 다름 — ③-1을 다시 한 뒤 L-8만 다시) / 제품 · 구성 = 응답을 받았는데 값이 기대와 다르다. 라이브 창 동안 gitops main 머지 0(런북 §3 T076 ③-1 · 실패 갈래 ③-2).
