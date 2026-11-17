# T075 운영자 블록 — UD-9 재렌더(W-6 · O-6 · acl 삭제 · ACL LOAD) · kv 시드(O-2 · W-2 · O-3 · O-4) · CF 값(O-1) · 탐침(O-5) · 모의 하네스 · 남은 위험

빌더 작업(2026-11-17 — T075 조각 ③의 블록 부분 + 조각 ④) · **수정 라운드 1**(2026-11-17–18 — 리뷰 A · B `approve_with_fixes`(high 0)의 KA-1–KA-13 · KB-1–KB-10 전부 · §2a) · **수정 라운드 2**(2026-11-18 — 재검토 approve의 low 2 · info 1 · KA-10 소유 정정 · §2b). 결정 정본은 `../t075-design.md`(D10 · D11 · D16 · D18 · D20 · D24 · CD-5 · CD-7 · CD-8 · CD-9 · CD-10 · CD-27 · VR-8 · VR-12). 산출물은 이 디렉터리의 블록 11개 · `harness.ps1` · 이 문서, 그리고 런북 `docs/runbooks/bootstrap.md`의 §3 「T075」(C24) · §4 「T075」(C25) · §4 T057 안내 줄(C26) · 옛 불변식 표식 둘(§3 T044 「git 밖 라이브 상태」 · §4 T044 요약 — 표식 「T075 보정 2026-11-17」) · `docs/runbooks/vault-unseal.md` §0 창 시작 체크리스트 한 줄(KB-2 — 같은 표식)이다. **라이브 실행 0** — Vault · 클러스터 · Cloudflare · GitHub 쓰기 0, 블록은 모의 하네스 · 로컬 Dragonfly 컨테이너(VD-T075-17) · 실물 cmdlet 확인(§5 — 외부 CLI는 가림)에서만 돌았다.

## 1. 파일

| 파일 | 종류 | 줄 | 역할 |
|---|---|---|---|
| `w6-render-dragonfly-acl.ps1` | W(창 D) | 544 | Dragonfly 7경로 시드 · acl 재렌더 · 회전의 정본 — T057 `op1-seed-dragonfly.ps1`의 바이트 사본에서 머리 주석 · 규칙 맵(B2) · 기대 줄 · W-6 판정(`$lint` 순수 함수 — 옛 규칙 acl STOP · put 전 B2 꼬리 단언 · 허용 토큰 대조) · 모듈 로깅 실효 확인 · 제어 문자 치환 · 쌍 판정 문구(KA-11)만 바꿨다(op1 대비 +110 / −41줄) |
| `o6-pre-dragonfly-acl.ps1` | O(창 D) | 235 | kv acl 2경로의 줄 꼴 · pod 사용자 줄 꼬리 분류(해시 · 내용 0) — `$lint`는 W-6과 글자까지 같다(ST-O6A) · 「옛 규칙」 판정은 옛 꼬리를 B2로 바꾼 글자에 `$lint`가 빈 값일 때만(KA-3) |
| `w6-acl-delete.ps1` | W(창 D) | 206 | (수정 라운드 1 · KB-3 · KA-5) T075 전용 acl 삭제 — 허용 목록 = `kv/dev/dragonfly/acl` · `kv/prod/dragonfly/acl` 둘뿐(Ordinal — 유니코드 꼴 경로도 밖이다 · KB2-3) · live · 키 집합 = {`users.acl`}(값 0) · 경로 재타자 Ordinal · 삭제 뒤 `No value found` 확인(응답 유실이어도 재판정 — KB2-3) · 성공 줄 = 다음 W-6 · 「머지 전에만」 예외 까닭 |
| `w6-acl-load.ps1` | W(창 D) | 204 | admin `ACL LOAD` 1회(재시작 0) — env · root 토큰 · `load-<env>` · kv 읽은 직후 `VAULT_TOKEN` 지움(KB-4) · kubectl 실패 = 결과 미확인(KB-10) |
| `o6-post-dragonfly-dryrun.ps1` | O(창 D) | 214 | admin `ACL DRYRUN` 표(dev 7행 · prod 5행) — 명령 실행 0 · kv 읽은 직후 `VAULT_TOKEN` 지움(KB-4) |
| `o1-cf-values.ps1` | O(운영자 · tofu 상태 자격) | 132 | AUD 셋(비민감 출력) · Client ID 둘(`service_tokens`의 `.client_id`만) — 키별 정규식 · PASS일 때만 값 · `TF_*` 환경 변수 있으면 멈춤(KB-8) · INFO 줄에 tofu 경로(홈 = `~` — KB2-2) |
| `o2-kv-judge.ps1` | O(창 D) | 302 | identity-admin 10경로 × dev · prod — 존재 · 버전 · 키 집합 · 키별 sentinel · W-2 전제(웹훅 서로 다른 글자 16 이상 — KB-9) |
| `w2-kv-seed.ps1` | W(창 D) | 436 | env 하나의 4경로 — authentik `jwks_url` · `issuer` patch · 웹훅 `secret`(32B → 43자 · 서로 다른 글자 16 이상) · `secret_key`(48B → 64자 · W009) · `{"dsn": ""}` |
| `o3-kv-gate.ps1` | O(창 D) | 304 | 게이트 1(키 단위) — dev 21 · prod 23 검사 · `gate=PASS n/n` · **US6(T075) 시점 게이트**(T081 · T082는 기대를 바꾼 판 — KA-8 · §6) |
| `o4-eso-prod-role.ps1` | O(창 D) | 192 | `auth/kubernetes/role/eso-prod` 투영 13 · `vault policy read eso-prod` — `o4=PASS 14/14`(KB-6) |
| `o5-probe-identity-m2m.ps1` | O(운영자 · tofu 상태 자격) | 212 | `/health`(a 배포 전 404 · b 게이트) · `/session/check`(c 양성 + UD-10 표본) — 자격은 stdin 헤더 · 허용 목록 헤더만 · curl 첫 인자 `-q` · curl · tofu 환경 변수 있으면 멈춤(KB-1 · KB-8 · `SSL_CERT_FILE` · `SSL_CERT_DIR` — KB2-2) · INFO 줄에 curl · tofu 경로(홈 = `~` — KB2-2) · git_sha 출처(KA-12) |
| `harness.ps1` | 모의 하네스 | 3226 | A부(W-6 — T057 하네스 파생) + B부(나머지 10블록) — §4 |
| `README.md` | — | — | 이 문서 |

모든 블록: 최상위 `& { }` 한 문 · 빈 줄 0 · BOM · CR · TAB 0 · 끝 `}` + LF 1 · 첫 문장 `Set-PSDebug -Off` · 세션 고정 3문장 · `try`/`finally` 하나 · 출력은 `Write-Host`/`Write-Warning`뿐 · 응답에서 온 문자열은 제어 문자를 `?`로 바꾼 뒤 낸다(KB-7) · 실행은 `pwsh -NoProfile -File <절대 경로>`(권장) 또는 새 창 붙여넣기. 하네스 자신은 블록 규약 대상이 아니다(빈 줄 · 함수 정의가 있다).

## 2. 설계 결정 대응

| 결정 | 어디서 지키나 | 하네스 근거 |
|---|---|---|
| D10 블록 규약 — 첫 단계 = 모듈 로깅 4키 가드(HKLM · HKCU `PowerShellCore` + `UseWindowsPowerShellPolicySetting`=1이면 Windows PowerShell 두 키) + 실효 상태 확인(KB-2 — §2a · 라운드 2 KB2-1 — §2b: Core 스냅인 · Utility · Security · Management 넷 · 설정 파일은 값과 무관) · 그 뒤에만 `ConvertFrom-Json` | 블록마다 창 전제 첫머리(O-1 · O-5 포함 11개 전부) | 정적: 4키 문장 · 실효 확인 문장의 정확한 꼴(ST-* · S12) · 런타임: 정책 확인 · `Get-Module` · `Get-Command ForEach-Object`(Core) · 설정 파일 두 곳이 값이 오가는 첫 동작(vault status · token · kv · tofu output · curl · kubectl · 보안 입력)보다 먼저(공통 사후) · O1-07 · O2-06 · ML-* · ML2-*(켜짐 · 확인 불가 → 묻기 전 중단) · CFG-1–9(설정 파일 값 무관) · ML-OK · S10m · S10n · S10p · S10q |
| D10 — 정지점 = 타자 단어 `Read-Host`(입력 버퍼 비움 직후) · 값 0(화면 · argv · 파일 · 클립보드) · SHA-256 Ordinal 되읽기 · fail-closed · 판정/쓰기 분리 · 과도 상태 · 응답 유실 재판정 · 조건부 정리 | W-2 `$write`(쓰기 → 비 0이면 값 없이 재판정: 버전 그대로 = 쓰지 않음 · +1 + 되읽기 일치 = 기록됨(응답 유실) · +1 + 다름 = CAS 충돌 · 그 밖 = 결과 미확인) · 판정 블록 O-2 · O-3 · O-4 · O-6은 쓰기 0 | ST-*(Read-Host 소유 헬퍼 · 바로 앞 비움 AST) · W2-14 · W2-15(응답 유실) · W2-16(거부) · W2-23 · W2-24(CAS 충돌) · W2-20 · W2-21(중단 · 재실행 복구) · W2-10(일시 403) · O2-04(500 · 깨진 JSON) · 공통 노출 단언 |
| D10 W-2 쓰기 표 — patch `-cas=<n>` issuer · jwks_url(나머지 3키 보존 · VD-T075-11) · webhook 32B → 43자 · django 48B → 64자 · sentry `{"dsn": ""}` · dev ≠ prod | W-2 판정 가드 · `$newB64 32` · `$newB64 48` · 쌍 판정(판정 단계 + put 직전) · prod 차례에 dev 값 존재 요구 | ST-W2(put · patch 모양 · RNG 크기) · W2-01 · W2-04(값 · 보존 키 · W009) · W2-03(dev 먼저) · W2-11(dev = prod 웹훅) · W2-25(dev = prod django — KA-1) · W2-17(patch가 보존 키를 바꿈 → STOP) |
| CD-9 — HMAC 키 = 43자 문자열의 ASCII 바이트(디코드 0 · 끝 줄바꿈 0) | W-2는 문자열 그대로 저장(머리 주석에 계약) · O-3 `^[A-Za-z0-9_-]{43}$`(`\z`) · 줄바꿈 FAIL | O3-05(끝 줄바꿈 → FAIL) · W2-09(줄바꿈 든 값 → STOP) |
| D10 O-3 PASS 조건 · C8(게이트 1 키 단위) | O-3 21 · 23 검사 · 면제 셋 · 판정 밖 키 밖의 `PLACEHOLDER-` 0 · dev 해시 ≠ prod 해시 | O3-01 · O3-03(PASS) · O3-02 · O3-04–O3-12(FAIL 분류 · 위치만) · O3-P1(붙여넣기) |
| D11 · CD-8 — AUD는 비민감 출력에서만 · Client ID는 `.client_id`만 · 키별 정규식 · PASS일 때만 값 | O-1 | O1-01–O1-08(64 hex를 cn 자리에 → FAIL · 대문자 hex · 키 누락 · 속성 없음 · 출력 실패 · 깨진 JSON — 전부 값 미출력) · O1-09–O1-12(`TF_*` → tofu 0) · O1-13(INFO 경로 `~`) |
| D16 · CD-7 · VR-12 — 허용 목록 헤더만(`x-request-id` · `Cache-Control`) · 본문 필드 판정 · `Set-Cookie` 0 · 자격은 stdin 헤더 | O-5 `curl.exe -q -sS --max-time 20 -H '@-' -w '…%{http_code}…%header{x-request-id}…%header{cache-control}…'` | ST-O5(curl 모양 · 첫 인자 `-q` · `-w` 형식) · curl 모의가 첫 인자 `-q` 아님 · 헤더 통째 플래그(`-i` · `-D` · `-v` · `-c` · `-b` · `-o`) · 허용 밖 `%header{}` · argv 헤더를 위반으로 기록 · O5*-*(쿠키 값 화면 · argv 0) |
| D16 · D18 — a 404 · b 게이트(200 · status · checks 셋 · git_sha · x-request-id) · c 200 `{"active": true}` · `no-store` · UD-10 400 표본(보낸 시각 · x-request-id INFO) | O-5 모드 a · b · c | O5a-01 · O5a-02 · O5b-01–07 · O5c-01–03 · O5-08–12 · O5-13–20(환경 변수 → 0 호출) · O5-21(INFO 경로 `~`) · CC-O5 |
| D20 W-6 판정 — 옛 규칙 acl STOP(2단계 먼저) · 렌더한 pod 사용자 줄마다 B2 꼬리 단언(없으면 쓰기 전 FAIL) · 허용 토큰 글자 대조(`cmd\|sub` · `reset` · 허용 밖 카테고리 금지) | W-6 `$lint`(순수) · `$judge` acl 갈래 · `$write` acl 갈래(put 전) | S12 · U05(42) · S37a · S37c(옛 규칙 → STOP · 쓰기 0) · S37b(T057 ② 펜스 추출 연쇄 — 라운드 0 근거) · **CH-02**(새 삭제 블록 ×2 → W-6 → B2 · 독립 계산과 바이트 일치 · 사용자 값 불변) · S38(B2 꼬리 없는 렌더 변이 → put 전 STOP) |
| D20 2단계 — acl 2경로 삭제(KB-3 · KA-5 — 새 블록) | `w6-acl-delete.ps1` | ST-DEL · DEL-01–22 · DEL-P1 · CH-02 · ML-DEL · ML2-DEL |
| D20 O-6 — 사전(줄 꼴 · 꼬리 분류 · B2 없으면 FAIL) · 사후(admin DRYRUN 표 · `--askpass`) | O-6 사전 · O-6 사후 | ST-O6A · O6A-01–11 · O6A-P1 · ST-O6B · O6B-01–07 · CC-O6B · CH-01 |
| D20 6단계 — admin `ACL LOAD` 먼저 · 재시작 0 | `w6-acl-load.ps1`(아래 편차 1) | ST-WL · WL-01–05 · CH-01(LOAD → O-6 사후 연쇄) |
| CD-27 — eso-prod role 투영 · 정책 | O-4(14 — KB-6) | O4-01–O4-10 · CC-O4 |
| D24 · D1 · IR:455-461 · 복구 | 런북 §3 T075 | — |
| C26 — op1 판별 줄 「op1 = 옛 판(`+@all`) — 실행하지 않는다(되돌림 갈래 제외 · 사용자 확인 뒤)」 | 런북 §4 T057 「실행」 앞 · 「ACL 파일 갱신」 1단계 · W-6 머리 주석 | — |

### 2a. 수정 라운드 1 대응(리뷰 A `review-K-A.md` · 리뷰 B `review-K-B.md` — 2026-11-17)

| 발견 | 고친 곳 | 하네스 근거 | 죽인 변이(§4) |
|---|---|---|---|
| **KB-3 · KA-5**(medium) — T057 ② 삭제 블록을 쓰면 사용자 · admin 경로를 지울 수 있고 OK 줄이 op1을 안내 | 새 블록 `w6-acl-delete.ps1` · 런북 §4 T075 B 2단계(「T057 ② 블록을 쓰지 않는다」 · 「머지 전에만」 예외 까닭) · 실패 갈래 ② · 표 · 기록 칸 | ST-DEL(허용 목록 상수 정확히 둘 · 그 밖의 `kv/` 경로 상수 0 · 삭제 1곳 · 재타자 Ordinal · 성공 줄 W-6) · DEL-01 · DEL-02(정상) · DEL-03–06(허용 밖 · admin · 대소문자 · 끝 공백 = 토큰을 묻기 전 중단 · 쓰기 0) · DEL-07(키 집합 다름) · DEL-08(재타자 다름) · DEL-09(이미 없음) · DEL-10–12(403 · exit 0 인데 남음 · 뒤 조회 500) · DEL-13(dead) · DEL-P1 · CH-02 · ML-DEL | M16 · M16b · M17 · M18 · M19 |
| **KB-1**(medium) — curl이 `.curlrc`를 읽는다 · 프록시 · 키 로그 환경 변수 | O-5 curl 세 곳 첫 인자 `-q` · `CURL_CA_BUNDLE` · `SSLKEYLOGFILE` · `HTTP(S)_PROXY` · `ALL_PROXY`(소문자 포함 — `-contains`는 대소문자 무관) 있으면 이름만 내고 멈춤 | ST-O5 · curl 모의 「첫 인자 = -q」 · O5-13–O5-17 | M06 · M20 · M21 |
| **KB-2**(medium) — 4키 가드가 설정 파일 · `-SettingsFile` 정책을 못 본다 | 블록 11개 — `Import-Module` 두 모듈 → `Get-Module`의 `LogPipelineExecutionDetails` · `powershell.config.json` 두 곳(`$PSHOME` · `$PROFILE.CurrentUserAllHosts`의 폴더)을 `Get-Content -Raw` + `-match`(텍스트 — `ConvertFrom-Json` 0) · 모듈 2개 · 사용자 위치를 확인 못 하면 멈춤 · `vault-unseal.md` §0 한 줄 · 런북 사전 | Static-R1(정확한 꼴 — S12 · ST-*) · 공통 사후(실효 확인이 값 동작보다 먼저) · ML-O1 · ML-O2 · ML-W2 · ML-O3 · ML-O4 · ML-O5 · ML-O6A · ML-O6B · ML-WL · ML-DEL · ML-OK · S10m · S10n · 실물 cmdlet 확인(§5) | M23 · M24 · M25 · A5 |
| **KA-1**(medium) — O-3 조건 넷 · W-2 django 쌍 무시험 | 하네스 사례 · 이 문서 §4 「생존 0」 문장 정정 | O3-08(49자) · O3-09(64자 2글자 반복) · O3-10(dsn 비지 않음) · O3-11(prod django = dev → 22/23) · W2-25 | MX1 · MX1b · MX2 · MX3 · MX4 |
| **KA-4**(medium) — L13 attestation 명령이 D4보다 약함 | 런북 §3 L13(D4 글자 그대로 · 결과를 GP-3 PR 본문에 · 기록 칸) | — (런북) | — |
| **KA-6**(medium) — data-assert Job 삭제 명령 없음 | 런북 §4 T075 B 8단계(`kubectl --kubeconfig $kc -n jt-dev delete job data-assert` → selfHeal ≤ 3분 → agent-view 로그 7 id) · §3 L6 · 기록 칸 | — | — |
| KA-2 — O-2 전제 판정 무시험 | 하네스 사례 | O2-07(웹훅 42자) · O2-08(jwks만 계약 값) | MX21 · MX22 |
| KA-3 — O-6 사전 「옛 규칙」이 다른 결함을 가림 | O-6 사전 `$toB2` · `$fx`(옛 꼬리를 B2로 바꾼 글자에 `$lint`) | O6A-07(F12 전 default 줄) · O6A-08(admin 허용 밖 카테고리) · O6A-09(admin 줄 없음) · O6A-10 · O6A-11(기타 꼬리) · O6A-P1 | MX5 · M36 |
| KA-7 — 편차 5의 남는 위험 | 런북 §4 T075 B 「규칙」(2단계부터 prod O-6 사후 PASS까지 두 env 재시작 요인 보류 · L6 전 SUC 일정 확인 · dev LOAD 뒤 GP-A 전 `acl-list` FAIL = 기대된 일시 상태) · §3 L6 · 기록 칸 | — | — |
| KA-8 — O-3을 T081에 다시 쓰면 구조적 FAIL | O-3 머리 주석 · 런북 A 4 · §6 | — | — |
| KA-9 — 시각 · `$kc` | 런북 B 3단계 끝 시각(UTC) · 4단계 기준 · 5단계 `$kc` · 기록 칸 | — | — |
| KA-10 — L11 선택 항목 · L15 | 런북 §3 L11(선택 항목 — 라운드 2에서 소유를 나눴다: m2m 404 넷 → T076 · 신선도 키 → T098 · §2b) · L15(admin static URL · 로그 문구 · 명령) · 기록 칸 | — | — |
| KA-11 — 문구 `assert-env` | W-6 두 곳 `assert-data-env` · 하네스 `$PAIRWHY` | S04j · S04j2 · S04j3 | A4 |
| KA-12 — O-5 b git_sha 출처 | O-5 머리 주석 · 프롬프트 · 런북 §3 O-5 | — | — |
| KA-13 — 표식 문장의 면제 셋 · 판정 밖 구분 | 런북 §4 T044 요약 표식 문장 | — | — |
| KB-4 — `VAULT_TOKEN`이 kubectl 자식 env에 남음 | O-6 사후 · LOAD — kv 읽은 직후 `Remove-Item Env:VAULT_TOKEN` · INFO 줄에 kubectl 경로 | 정적(kubectl 호출 앞 Remove-Item · INFO `$ksrc`) · 모의 호출 시점 env(kubectl 호출에 토큰 0) | M27 · M28 |
| KB-5 — 하네스가 끝 시점 · 파일 실행으로만 봄 | 하네스: 정적 `$env:` 대입 = VAULT_ADDR · VAULT_TOKEN만 · `$script:` · `$global:` 대입 = `$global:LASTEXITCODE`만 · 모의 호출 시점 env 바늘(vault는 VAULT_TOKEN만 예외) · 보안 입력 다음 동작 = 클립보드 비움 · 붙여넣기 모드 | Static-R1 · 공통 사후 · O2-P1 · W2-P1 · O3-P1 · O6A-P1 · DEL-P1 | KM1 · KM1b · KM2 · KM24 · M29 · M30 · A8 · A9 |
| KB-6 — O-4 기대값이 적다 | O-4에 `token_type` · `token_period` · `token_explicit_max_ttl` · `token_num_uses` · `token_bound_cidrs` · `token_no_default_policy` · `bound_service_account_namespace_selector`(14/14) | O4-01(14/14) · O4-06–O4-10 | M35(+ M09) |
| KB-7 — 응답 문자열의 제어 문자 | 블록 11개 — `$firstErr` · status 줄 · 버전 줄 · DRYRUN 응답 · O-4 값 · O-5 출력 전 `-replace '\p{Cc}', '?'`(연산자 — 형식 허용 목록 변경 0) | 모의 결함(status `ctrl` · `metaCtrl` · `kctrl` · x-request-id · role 필드) → CC-O2 · CC-W2 · CC-O6B · CC-O5 · CC-O4 · S08cc · S10cc · 공통 사후 「화면 제어 문자 0」 | M26 · M38–M41 · A6 · A7 |
| KB-8 — tofu 동작 환경 변수 | O-1 · O-5 — `TF_LOG*` · `TF_CLI_ARGS*` · `TF_WORKSPACE` · `TF_DATA_DIR` 있으면 이름만 내고 멈춤 | ST-O1 · ST-O5(판정이 첫 tofu output보다 먼저) · O1-09–O1-12 · O5-18 | M22 |
| KB-9 — 웹훅 secret의 손 값 | W-2 `$wh43`(판정 · 쌍 판정 · 생성 확인) · O-2 · O-3 — 서로 다른 글자 16 이상(값 · 글자 수 미출력 · 근거 아래) | W2-26 · O2-09 · O3-12 | M31 · M32 · M33 |
| KB-10 — LOAD kubectl 실패 문구 | LOAD — `결과 미확인(… ACL LOAD 가 Dragonfly 에 닿았는지 모른다 · O-6 사후로 라이브 규칙을 본다)` · 런북 실패 갈래 | WL-05 | M34 |
| (리뷰 B KM3 — 라운드 0 「무해」 생존) | 하네스 공통 사후 「`$Error`에 블록이 남긴 기록 0 — throw 시나리오는 그 throw 1건만」(A부 · B부) | 모든 런타임 시나리오 | KM3 · M37 · A10 |

**KB-9 하한 16의 근거**: 웹훅 `secret` = 32바이트 CSPRNG → base64url 43자. 앞 42자는 6비트씩 균등이고 마지막 글자는 4비트(16기호)라 43자의 서로 다른 글자 수 D₄₃ ≥ D₄₂다. 점유 분포를 정확히 셌다(DP — 스크래치 `r1/distinct-dp.ps1`): D₄₂ 평균 30.97 · **P(D₄₂ < 16) = 2.2×10⁻¹³**(D₄₃의 상한) · P(< 20) = 5.9×10⁻⁸ · P(< 10) = 4.3×10⁻²⁶. 하한 16은 손으로 만든 값 · 반복 꼴(`AbAb…`처럼 3–10종)을 잡고, 진짜 CSPRNG 값을 STOP시킬 확률은 2.2×10⁻¹³ 이하다(그때도 사람 판정 STOP일 뿐 데이터 손실이 아니다). 20은 거짓 STOP이 10⁻⁷대라 택하지 않았다. 판정은 분류 문구만 내고 값 · 글자 수는 내지 않는다. (라운드 1 첫 계산은 43자 전부 균등으로 가정해 5.5×10⁻¹⁴였다 — 마지막 글자가 4비트라 상한 2.2×10⁻¹³으로 고쳐 블록 주석 · 런북에 적었다.) django `secret_key`(48바이트 → 64자 · 전부 균등)의 W009 하한 5는 P(< 5) = 5.5×10⁻⁷²다.

### 2b. 수정 라운드 2 대응(재검토 approve — low 2 · info 1 · 리뷰 B 증거 `review-K-B\r1\` — 2026-11-18)

| 발견 | 고친 곳 | 하네스 근거 | 죽인 변이(§4) |
|---|---|---|---|
| **KB2-1** ① 실효 확인이 Utility · Security만 본다(Core · Management 우회) | 블록 11개 — `Import-Module` 세 모듈 · `$mlMgmt = @(Get-Module Microsoft.PowerShell.Management)` · `$mlFe = @(Get-Command ForEach-Object -CommandType Cmdlet)` → `$mlCore = $mlFe[0].PSSnapIn` · Core · Management 실효 값을 `$mlEff`에 · Management 0/1 · Core 스냅인을 읽지 못하면 멈춤 | Static-R1(정확한 꼴) · 공통 사후(Core 확인이 값 동작보다 먼저) · ML2-MGMT · ML2-MGMTMISS · ML2-NOSNAP · ML2-NOFE | M42 · M45 · M46 · A11 |
| **KB2-1** ② 설정 파일 판정이 값 꼴로 우회된다(실측 여섯: 문자열 `"true"` · `1` · `/* */` · 작은따옴표 키 · 따옴표 없는 키 · 이스케이프 키) | 블록 11개 — 값과 무관하게 텍스트에 낱말 `ModuleLogging`(대소문자 무관) 또는 역슬래시-u가 있으면 멈춘다: `-cmatch '(?i:ModuleLogging)\|\x5Cu'`(소스에 역슬래시-u 글자를 쓰지 않는다 — 편집 도구가 바꾼다) | CFG-1–CFG-6(여섯 꼴) · **CFG-7**(전부 이스케이프 — 낱말 0 · 역슬래시-u만 잡는다 · 실측: pwsh가 이 꼴을 따른다) · CFG-8(값 false도 멈춤) · CFG-9(소문자) · ML-OK(정책 텍스트 없는 설정 · `C:\\Users` 경로 = 대문자 U라 통과 — 거짓 멈춤 0) · S10q | M43 · M44 · A12 |
| **KB2-1** ③ `pwsh -SettingsFile <파일>`로 시작한 창은 블록이 그 파일을 못 읽는다 | 실효 값이 잡는다(실측 `r2/probe-core.ps1`: Core 대상 정책이면 Core 스냅인 값만 True · Management 대상이면 Management만 · `*`면 넷 다) | ML2-O1 · ML2-O2 · ML2-W2 · ML2-O3 · ML2-O4 · ML2-O5 · ML2-O6A · ML2-O6B · ML2-WL · ML2-DEL · S10p(블록 11개 — 설정 파일 깨끗 · 세 모듈 꺼짐 · Core만 켜짐 → 묻기 전 중단) · 실물 확인(§5 — `-SettingsFile` Core · Management · Utility 창 11/11 중단) | M42 · A11 |
| **KB2-1** ④ 모의 · 체크리스트 | 하네스 모의 `Import-Module`(세 모듈) · `Get-Command`(ForEach-Object · 결함 셋) · `vault-unseal.md` §0 한 줄(4줄 = False · 「정책 있음」 0 — 실측 보통 · Core · Management 창) | 위와 같다 | — |
| **KB2-2** O-1 · O-5 INFO 줄에 실행 파일 경로 없음 · `SSL_CERT_FILE` · `SSL_CERT_DIR` | O-1 `$tsrc` · O-5 `$tilde` · `$tsrc` · `$csrc`(사용자 홈 → `~`) · O-5 멈춤 목록 맨 앞에 둘(대소문자 무관 `-contains` 그대로) | ST-O1 · ST-O5(INFO 꼴 · 목록) · O1-13 · O5-21(홈 아래 경로 → `~` · 화면에 홈 경로 0) · O5-19 · O5-20(`ssl_cert_dir` 소문자) | M47 · M48 · M51 |
| **KB2-3**(info) 삭제 응답 유실 · 유니코드 꼴 경로 무시험 | 블록 그대로(재판정 · Ordinal 대조가 이미 맞다) · 하네스 사례 · §6 받아들인 한계 한 줄 | DEL-18(지웠는데 exit 2 → 재판정 absent → OK) · DEL-19–22(키릴 а · 폭 0 공백 · 전각 / · 결합 부호 → 토큰을 묻기 전 중단 · 삭제 0) | M49 · M50 |
| **KA-10**(소유 정정 — 컨트롤러 결정) | 런북 §3 L11 — m2m 호스트 404 넷 → T076(설계 :585) · 신선도 키 35 s 관찰 → 신선도 경보와 함께 T098(설계 :536) | — | — |

리뷰어 묶음 `review-K-B\r1\run-mutations-r1.ps1`의 **N2**(O-2 설정 파일 정규식의 공백 허용을 뺀다)는 KB2-1 ②가 그 정규식 자체를 없애 대상 문장이 0번 나온다(APPLY-ERROR — 생존 아님). 같은 뜻의 회귀(옛 정규식으로 되돌림 · 역슬래시-u 갈래 삭제)는 빌더 변이 M43 · M44 · A12가 대신 잰다. N8(Security 확인 삭제)의 앵커 셋은 일부러 남겼다(`Import-Module …Security` 접두 · `$mlMods` 줄 · `if ($mlMods.Count -ne 2 -or`).

## 3. 설계와 다른 점 · 빌더가 정한 것(까닭)

1. **`ACL LOAD`를 런북 명령 줄이 아니라 블록(`w6-acl-load.ps1`)으로 했다.** 설계 §5는 `kubectl … exec -it … redis-cli --user admin --askpass ACL LOAD`(운영자 프롬프트 입력)를 적었지만, admin 비밀번호는 `kv/<env>/dragonfly/admin`에만 있다(T057 생성 · 사본 없음) — 운영자가 `-it` 프롬프트에 칠 값을 화면 · 클립보드 없이 손에 넣을 길이 없다. D10이 「블록이 넘기는 꼴로 만들 때의 방법은 빌더가 정하고, 하네스가 argv 0을 단언한다」고 열어 둔 자리다. 블록은 kv에서 읽은 값을 `kubectl exec -i`(TTY 없음)의 stdin으로만 `redis-cli --askpass`에 준다.
2. **O-6을 두 파일로 나눴다**(사전 = kv만 · Vault 창 / 사후 = kubectl exec · 관리자 kubeconfig). 쓰는 자격과 적용 순서의 자리(1단계 · 7단계)가 다르다.
3. **stdin 꼴 `($pw + "`n") | kubectl @kargs`** — 실측(PowerShell 7.6.10 · redis-cli 6.0.16): PowerShell은 네이티브 명령 stdin 끝에 CRLF를 붙이고, redis-cli `--askpass`(linenoise 비 TTY)는 LF까지 읽고 CR을 비밀번호에 남겨 AUTH가 실패한다 → 값 뒤에 LF를 먼저 붙인다. 인자는 `@kargs` 펼침 — PowerShell **함수**는 `--`를 먹고 배열 인자를 한 객체로 받는다(실측) · 펼침은 네이티브와 함수에 같은 낱말을 준다. redis-cli는 AUTH 실패 · 오류 응답에도 종료 코드 0이라 응답 줄로 판정한다(`OK` · `This user has no permissions to run the '<명령>' command` · `NOAUTH`/`AUTH failed` · `ERR …`).
4. **W-2 가드를 설계보다 엄격하게 했다**: sentinel은 글자까지 같아야 한다 · 웹훅 경로 absent = STOP(만들지 않는다 — T044 투입 기록과 다르므로 사람 판정) · prod 차례에는 dev의 웹훅 `secret` · `secret_key`가 W-2 꼴로 있어야 한다(설계 「env 하나씩 · dev 먼저」를 기계적으로) · 쌍 판정(dev ≠ prod)을 판정 단계와 put 직전 두 번.
5. **런북 §4 T075 B 적용 순서의 2 · 3단계를 두 env 한 번에** 적었다. D20은 「env마다 dev 먼저 · 8. prod도 1–7」이지만, W-6은 op1 파생이라 7경로를 함께 판정한다 — dev acl만 지우면 prod의 옛 규칙 acl에서 STOP(쓰기 0)한다. 그래서 kv 단계(2 · 3)는 두 env를 한 번에 하고, 라이브 반영(4–7: ESO · kubelet · `ACL LOAD` · O-6 사후)은 env마다 dev 먼저다. 대가: 3단계 뒤 prod의 마운트 파일도 B2가 된다(메모리 규칙은 prod `ACL LOAD` 전까지 그대로). **리뷰 A가 받아들일 만하다고 봤다**(`$lint` · VD-17) — 남는 위험은 KA-7 규칙(2단계부터 prod O-6 사후 PASS까지 두 env 재시작 요인 보류 · L6 전 SUC 일정 확인)으로 런북 B 「규칙」에 적었다.
6. **VD-T075-17 측정 조건**: 운영 digest(`v1.40.1@sha256:ebf3c6…`) · 운영 인자(`--maxmemory=768mb --aclfile … --dir /data --snapshot_cron … --dbfilename=dump --primary_port_http_enabled=false`) 그대로에 컨테이너 `--cpus 2`(UD-9 실측의 `--proactor_threads=2` 대신 — 운영에 없는 인자를 더하지 않고 IO 스레드 2를 맞췄다).
7. **O-3 사유 문구**: 키 집합 판정이 실패한 경로의 값 검사는 「키 집합 판정 실패」로 적는다(sentry `dsn` · openfga 둘 · authentik sentinel 셋 — 「빈 값이 아니다」 같은 오해 문구를 피했다).
8. **하네스 구조**: 하나의 `harness.ps1`에 A부(W-6 — T057 하네스의 바이트 사본에서 파생: 경로 use 문구 · B2 규칙 상수 · `Acl-T057` · S12 추가 · U05 · S37a/b/c · S38 · 라운드 1의 S10m · S10n · S08cc · S10cc)와 B부(새로 — 블록별 정적 관문 `Run-OStatic` · 공통 실행기 `Run-OCase` · 모의 확장)를 둔다. A부의 런북 블록 R1 · R2(§4 T057 「정리 판단」 두 펜스)는 T057 그대로 추출해 쓴다(이 과제는 그 펜스를 고치지 않았다 — T075는 그 ② 블록을 더 쓰지 않는다).
9. **(라운드 1) 모듈 로깅 실효 확인의 꼴**: 리뷰 B의 실측(레지스트리 0인데 Utility `LogPipelineExecutionDetails` = True)을 이 PC에서 다시 쟀다 — `pwsh -SettingsFile <EnableModuleLogging true>` 창에서 Utility = True · 보통 창 False 둘. 이 프로세스의 실효 값(`Get-Module`)이 정본이고, 설정 파일 두 곳은 텍스트로만 판정한다(`ConvertFrom-Json`을 거치면 확인 자체가 4103에 남는다). **라운드 2(KB2-1)에서 넓혔다**: 실효 값은 블록의 값이 지나가는 cmdlet이 사는 넷(Core 스냅인 — `ForEach-Object` · `Where-Object` · `Utility` · `Security` · `Management` — `Get-ChildItem Env:` · `Get-Content`)을 다 본다 · 설정 파일은 값 꼴과 무관하게 낱말 `ModuleLogging`(대소문자 무관)이나 역슬래시-u가 보이면 멈춘다(라운드 1의 `"EnableModuleLogging"\s*:\s*true` 정규식은 실측 여섯 꼴을 놓쳤다 — 리뷰 B `review-K-B\r1\cfgvar\`).
10. **(라운드 1) `$Error` 정리 단언**: 실측(`r1/probe-error.ps1`) — `2>&1` · `2>$null`로 돌린 오류도 `$Error`에 들어간다 · throw는 블록 finally 전에 담기고 정리로 지워진 뒤 바깥 catch가 한 번 다시 담는다 → 단언 = 「그 throw 1건 밖 0」. 이 단언이 리뷰 B KM3(라운드 0 「무해」 판정 생존)을 죽인다.
11. **(라운드 1) 붙여넣기 모드**: `[scriptblock]::Create(파일 전문)`으로 돌려 블록의 `$script:`가 하네스 범위로 풀리게 하고(실제 붙여넣기에서는 전역), 전후 전역 · 스크립트 범위 변수 이름을 대조한다. 블록 다섯(O-2 · W-2 · O-3 · O-6 사전 · acl 삭제)에 한 사례씩.
12. **(라운드 1) 하네스 환경**: curl · tofu 동작 환경 변수(`SSL_CERT_FILE` · `SSL_CERT_DIR`(라운드 2) · `CURL_CA_BUNDLE` · `SSLKEYLOGFILE` · `*_PROXY` · `TF_*`)를 하네스 동안 지우고 끝에 되돌린다(이 PC에 있으면 정상 시나리오가 멈추므로 · 값은 출력하지 않는다). 모의 `Cmd-Text`를 최상위로 옮겼다(A부 S12의 Static-R1도 쓴다).
13. **(라운드 2) 값과 무관한 설정 파일 판정의 대가**: `ModuleLogging`이 있으면 값이 `false`여도 멈추고(CFG-8 — 정책 줄을 지운 창 · PC에서 다시), 역슬래시-u가 정책 밖(예: 소문자로 시작하는 경로 조각 `\\users`)에 있어도 멈춘다(거짓 멈춤 — fail-closed). 대문자로 시작하는 보통 경로(`C:\\Users`)는 소문자 u만 보는 `-cmatch` 갈래라 통과한다(ML-OK). JSON 이스케이프는 소문자 u뿐이다.
14. **(라운드 2) 하네스 `Get-Command` 모의**: 블록의 vault · kubectl · tofu · curl.exe 해석은 실물 `Get-Command`(모의 함수로 풀린다)에 그대로 넘기고, `ForEach-Object -CommandType Cmdlet`(Core 스냅인 · 결함 CoreNoSnap · CoreMissing)과 `$global:FakeSrc`(실행 파일 경로 모의 — `~` 줄임 단언)만 답한다. 가드(`Assert-Guard`)는 모듈 이름을 붙인 실물 `Get-Command`로 본다(첫 실행에서 앞 시나리오의 FakeSrc가 남아 가드가 거짓 실패했다 — 시나리오 끝에 모의 상태를 비우고 가드는 실물로).

## 4. 하네스(`harness.ps1`)

실행: `pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t075-blocks\harness.ps1` [`-Only A|B`] [`-Show 'S01*'`] [`-Block <W-6 변이 사본>`] [`-Dir <B부 변이 사본 디렉터리>`] [`-Runbook <런북 변이 사본>`]. 종료 코드 = 실패 시나리오가 있으면 1.

### 모의 · 가드
- PATH 함정: `vault` · `kubectl` · `tofu`(+ `.exe`) 실물 디렉터리를 PATH에서 빼고 함정 `.cmd`를 맨 앞에(불리면 표식 파일 — 시나리오마다 0 단언) · `KUBECONFIG` = 없는 경로 · curl · tofu 환경 변수는 하네스 동안 지운다. `curl.exe`는 System32에 있어 PATH로 못 막는다 — 함수 가림 + 정적 관문(절대 경로 실행 파일 · `Start-Process` 0)이 막는다.
- 함수 가림: `vault`(A부 모의 + `kv patch`(CAS · 결함 patchFail · patchLost · patchTamper · patchRace) · `read -format=json auth/kubernetes/role/eso-prod` · `policy read eso-prod` · `kv metadata delete`(허용 플래그 · delFail · delNoop · postDelErr · delLost(라운드 2 — 지웠는데 응답 유실 exit 2)) · 제어열 결함 status `ctrl` · `metaCtrl`) · `kubectl`(exec → redis-cli 흉내: stdin을 실물처럼 객체마다 CRLF를 붙인 바이트로 보고 첫 LF까지를 비밀번호로 읽는다(CR 유지) · 틀리면 `Warning: AUTH failed` + `NOAUTH`(종료 0) · `ACL LOAD`(대기 규칙 반영) · `ACL DRYRUN`(라이브 규칙 모형 b2 / t057 · 실측 응답 문구 · 제어열 결함 `kctrl`)) · `tofu`(`version` · `-chdir=… output -json <이름>`만) · `curl.exe`(첫 인자 `-q` · `-w`의 http_code · 허용 헤더 둘만 채운다 · 헤더 통째 플래그 · 허용 밖 `%header{}` · argv 헤더 = 위반) · `Test-Path`(`-LiteralPath` 포함 · 관리자 kubeconfig · 설정 파일 두 곳은 실물 파일을 건드리지 않고 답한다) · `Get-Content`(설정 파일 두 곳만 · `-Raw` 요구) · `Import-Module`(Utility · Security · Management 세 모듈 정확히) · `Get-Module`(모듈별 `LogPipelineExecutionDetails` · 빠진 모듈) · `Get-Command`(라운드 2 — `ForEach-Object -CommandType Cmdlet`의 Core 스냅인 실효 값 · 결함 CoreNoSnap · CoreMissing · 실행 파일 경로 모의 `$global:FakeSrc` · 그 밖은 실물 `Get-Command`에 넘긴다) · `Read-Host` · `Set-Clipboard` · `Get-ItemProperty` · `Set-PSDebug`. vault · kubectl · tofu · curl 모의는 호출 시점의 환경 변수를 남긴다(KB-4 · KB-5). B부 모의는 시나리오가 켠 것(`$global:Allow`)에만 답하고 그 밖의 호출은 위반이다.
- `putRace` · `patchRace` 결함: 판정 뒤 · 쓰기의 CAS 판정 앞에 다른 기록자가 그 경로를 쓴다(진짜 CAS 충돌 — 응답 유실과 같은 CLI 문구라 되읽기 값으로만 가른다).

### 공통 사후 조건(A부 `Run-Case` · B부 `Run-OCase` — 모든 런타임 시나리오)
노출 0(바늘 = 비밀 전체 · base64 · 8자 조각 · SHA-256 hex 대 · 소문자 전체와 앞 16자 · url 안의 비밀번호 · acl 전문과 그 안의 hex — 화면(모든 스트림) · 프롬프트 · argv(vault · kubectl · tofu · curl) · 클립보드 · `$Error` · 환경 변수 · **모의 호출 시점 환경 변수**(vault는 VAULT_TOKEN만 예외) · 새로 생기거나 바뀐 전역 변수 · 공개 상수 `PLACEHOLDER-` · `django-insecure-` 안에 통째로 드는 조각만 뺀다) · 위반 0 · 함정 표식 0 · 성공 스트림 0 · 클립보드에는 공백만 · **보안 입력 바로 다음 동작 = 클립보드 비움** · 입력은 전부 가려진다(`-AsSecureString` 또는 `-MaskInput`) · 첫 동작 = `Set-PSDebug -Off` 1회 · 모듈 로깅 정책 확인 · **실효 확인(`Get-Module` · `Get-Command ForEach-Object`(Core — 라운드 2) · 설정 파일 두 곳)**이 값이 오가는 첫 동작보다 먼저 · **화면 제어 문자 0(LF 밖)** · **`$Error`에 블록이 남긴 기록 0(throw는 1건)** · `INFO vault CLI` 줄이 첫 출력이고 root 토큰 보안 입력보다 먼저 · 판정 블록 쓰기 0 · 블록이 만든 `VAULT_*`만 지운다 · 완주면 입력 전부 소비 · (붙여넣기 모드) 새 전역 · 스크립트 변수 0.

### B부 정적 관문(`Run-OStatic` — 블록마다 · 관문 5가 FAIL이면 그 블록의 런타임 시나리오를 돌리지 않는다)
관문: 파서 오류 0 · 명령 허용 목록(블록별) · 정적 .NET 형식 허용 목록 · `$Host`는 `FlushInputBuffer()` 한 꼴 · 리다이렉트는 `$null`만. 그 밖: 파일 바이트 · 첫 줄 `& {` · 빈 줄 0 · 최상위 한 문 · 첫 문장 `Set-PSDebug -Off` · 세션 고정 3문장 · `try`/`finally` · finally 출력 규칙 · VAULT_* 제거가 finally 첫 두 문장 · `Read-Host` 수 · 소유 헬퍼 · 바로 앞 입력 버퍼 비움(AST) · vault 호출 모양(`-field` 0) · 4키 가드 문장 · **실효 확인 문장(정확한 꼴)** · **`$env:` · `$script:` · `$global:` 대입 제한** · `MOCK` · 비밀 상수 · `hvs.` · `Start-Transcript` · `$env:KUBECONFIG` 참조 0 · 블록별(O-6 사후 · LOAD: kubectl 1곳 · `@kargs` 펼침 · stdin = `($pw + "`n")` · `$kargs` 꼴(비밀번호 · 토큰 · `-t` 0) · kubectl 앞 `Remove-Item Env:VAULT_TOKEN` · INFO kubectl 경로 / O-6 사전: `$lint` = W-6 `$lint`(글자까지) / O-2 · W-2 · O-3: sentinel · jwks_url · issuer 상수 = 계약 / W-2: put · patch 모양 · RNG 크기 / O-1 · O-5: tofu 호출 모양 · 환경 변수 판정이 첫 tofu output보다 먼저 · INFO 줄 실행 파일 경로(홈 `~` — 라운드 2) / O-5: curl 호출 셋(첫 인자 `-q`) · `-w` 형식 · 헤더 줄 stdin · 환경 변수 목록(`SSL_CERT_FILE` · `SSL_CERT_DIR` 포함) / acl 삭제: 허용 목록 상수 정확히 둘 · 그 밖의 `kv/` 상수 0 · 삭제 1곳 · 재타자 Ordinal · 성공 줄 W-6). A부 S12도 Static-R1(대입 제한 · 실효 확인 꼴)을 단언한다.

### 결과(2026-11-18 라운드 2 최종 실행 — `-Only` 없이 한 번 · 런북 · 블록 마지막 편집 뒤)
- **전체**: 시나리오 PASS **354 / 354** · 단언 PASS **11241 / 11241** · exit 0 · 80–110초(병렬 변이 부하에 따라) · 실물 vault · kubectl · tofu 호출 0(함정 표식 0). **실행 꼴 둘 다**(문서의 `pwsh -NoProfile -File <harness>` · `pwsh -NoProfile -Command "& '<harness>'"`) 같은 결과다(라운드 2 — 아래 「하네스 결함」 끝 항목).
- 닫힌 T057 하네스(`../t057-blocks/harness.ps1`)를 라운드 2의 런북 편집 뒤에 다시 돌렸다 — `PASS 4923 / 4923` · 시나리오 152 / 152 · exit 0(「정리 판단」 두 펜스 추출 R1 · R2 그대로 · `t057-blocks/` 변경 0).
- **A부(W-6)**: 시나리오 161 · 단언 5837 — S12 47(T057 대비 +9: `$render` 규칙 상수 = admin · B2 둘 · 옛 규칙 상수 0 · `$lint` 대입 1 · 순수 · 금지 꼴 셋 · put 앞 `& $lint` · `$judge` 안 `& $lint` · 대입 제한 · 실효 확인 꼴) · U01–U04(B2 규칙 맵) · **U05 42** · **S37a · S37c**(옛 규칙 → STOP · 쓰기 0) · **S37b**(T057 ② 펜스 추출 → W-6 재실행 → B2) · **S38**(렌더 상수 변이 → put 전 STOP) · **S10m · S10n · S10p · S10q**(실효 상태 켜짐 · Core 대상 정책 · 설정 파일 값 무관 → 시작 전 중단) · **S08cc · S10cc**(제어열 → `?`) · R1 · R2 · GA · GB(T057 「정리 판단」 두 펜스 — 그대로).
- **B부**: 시나리오 193 · 단언 5404(런타임 183 시나리오마다 하네스 자체 단언 하나 — 모의 상태 표가 해시 테이블 그대로) — 정적 10(ST-O1 · ST-O2 · ST-W2 · ST-O3 · ST-O4 · ST-O5 · ST-O6A · ST-O6B · ST-WL · ST-DEL) · O-1 13 · O-2 10 · W-2 27 · O-3 13 · O-4 10 · O-5 26 · O-6 사전 12 · O-6 사후 7 · LOAD 5 · acl 삭제 19 · 연쇄 2 · 모듈 로깅 25(ML 11 · ML2 14) · 설정 파일 9(CFG) · 제어열 5.

### 변이 시험(스크래치에서 블록 사본에 변이 하나씩 — 하네스가 실제로 잡는지)

**라운드 2 재실행(2026-11-18 — 블록 11개 · 하네스가 바뀌어 다섯 묶음을 모두 다시 돌렸다 · 리뷰어 묶음은 하네스 `-File` 결함을 고친 뒤 한 번 더 — 아래 수치가 고친 뒤 것)**:

| 묶음(스크립트 — 스크래치 · 수정 없이 재실행) | 변이 | 결과 |
|---|---|---|
| 리뷰 B 라운드 1(`review-K-B/r1/run-mutations-r1.ps1`) | N1 · N1b · N1d · N1e · N2 · N3 · N4 · N5 · N8 | **8 / 8 잡힘 · N2 = APPLY-ERROR**(대상 정규식이 KB2-1 ②로 사라짐 — §2b · 같은 회귀는 M43 · M44 · A12) — N1 → ST-DEL · N1b → DEL-05 · N1d → DEL-07 · N1e → ST-DEL · DEL-08 · N3 → ST-O5 · O5 15개 · N4 → ST-WL · WL-01–03 · WL-05 · CH-01 · N5 → ST-O5 · O5-14 · O5-20(소문자 `ssl_cert_dir`) · N8 → ST-O3 · O-3 전부 |
| 리뷰 A(`review-K-A/mutate.ps1`) | MX1–MX9 · MX21 · MX22 | **12 / 12 잡힘** — 라운드 1과 같은 시나리오(MX1 → O3-08 · MX4 → W2-25 · MX5 → O6A-10 · O6A-11 · MX21 → O2-07 · O2-09 …) |
| 리뷰 B 라운드 0(`review-K-B/run-mutations.ps1`) | KM1 · KM1b · KM2 · KM3 · KM4 · KM5 · KM6 · KM7 · KM10 · KM24 | **10 / 10 잡힘** — KM1 → ST-WL · WL-01–03 · WL-05 · CH-01 · KM1b → ST-O5 · O5 15개(O5-21 포함) · KM2 → W-2 26개 · KM3 → O1-06–O1-12 · ML-O1 · ML2-O1 · KM4 → O1-01–O1-08 · O1-13 · KM5 → O3-05 · KM6 → KM1b와 같은 16개 · KM7 → O5a-01 · O5b-01 · O5b-06 · O5c-01 · O5c-02 · CC-O5 · KM10 → O1-02 · KM24 → ST-O2 · O2-P1 |
| 빌더 A부(`build-K/mutate-a.ps1`) | A1–A12 | **12 / 12 잡힘**(아래 표 — A11 · A12 새것) |
| 빌더 B부(`build-K/mutate-b.ps1`) | M00 · M01–M51 · M16b | **52 / 52 잡힘 · M00 exit 0 · FAIL 0**(아래 표 — M42–M51 새것) |

**라운드 0 문장 정정(KA-1)**: 라운드 0의 「모든 변이가 죽었다(살아남은 변이 0)」는 빌더 자신의 묶음(M00–M15 · A1–A3)에만 맞는 말이었다. 리뷰 A의 변이 12개 중 8개(MX1 · MX1b · MX2 · MX3 · MX4 · MX5 · MX21 · MX22)와 리뷰 B의 KM1 · KM1b · KM2 · KM24(+ KM3 — 「무해」 판정)가 살아남았다. 수정 라운드 1에서 사례 · 단언을 더하고 네 묶음을 모두 다시 돌린 결과가 아래다.

| 묶음(스크립트 — 스크래치) | 변이 | 결과 |
|---|---|---|
| 리뷰 A(`review-K-A/mutate.ps1` — 수정 없이 재실행) | MX1 · MX1b · MX2 · MX3 · MX4 · MX5 · MX6 · MX7 · MX8 · MX9 · MX21 · MX22 | **12 / 12 잡힘** — MX1 → O3-08 · MX1b → O3-09 · MX2 → O3-10 · MX3 → O3-11 · MX4 → W2-25 · MX5 → O6A-10 · O6A-11 · MX6 → O1-02 · MX7 → O5b-01–07 · CC-O5 · MX8 → O6B-01–03 · CH-01 · CC-O6B · MX9 → O3-05 · MX21 → O2-07 · O2-09 · MX22 → O2-08 |
| 리뷰 B(`review-K-B/run-mutations.ps1` — 수정 없이 재실행) | KM1 · KM1b · KM2 · KM3 · KM4 · KM5 · KM6 · KM7 · KM10 · KM24 | **10 / 10 잡힘** — KM1 → ST-WL(`$env:` 대입) · WL-01 · WL-02 · WL-03 · WL-05 · CH-01(모의 호출 시점 env 바늘) · KM1b → ST-O5(`$env:` 대입) · O5a-01 · O5a-02 · O5b-01–07 · O5c-01–03 · O5-12 · CC-O5 · KM2 → W-2 26개(W2-01–12 · 14–21 · 23–26 · CC-W2 · W2-P1 — 보안 입력 다음 동작 = 클립보드 비움) · KM3 → O1-06–O1-12 · ML-O1(`$Error` 정리) · KM4 → O1-01–O1-08 · KM5 → O3-05 · KM6 → ST-O5 · KM1b와 같은 15개 · KM7 → O5a-01 · O5b-01 · O5b-06 · O5c-01 · O5c-02 · CC-O5 · KM10 → O1-02 · KM24 → ST-O2 · O2-P1 |
| 빌더 A부(`build-K/mutate-a.ps1`) | A1–A10 | **10 / 10 잡힘**(아래 표) |
| 빌더 B부(`build-K/mutate-b.ps1`) | M00 · M01–M41 · M16b | (아래 표) |

| ID | 변이 | 잡은 시나리오 |
|---|---|---|
| A1 | W-6 `$write`의 `$lint` 대조를 끈다 | S12 · S38 |
| A2 | W-6 `$judge`의 옛 규칙 분기를 끈다 | S37a · S37c |
| A3 | W-6 `$lint` 꼬리에서 `-client`를 뺀다 | S12 · U05 · S01 외 27 |
| A4 | W-6 쌍 판정 문구 `assert-data-env` → `assert-env`(KA-11) | S04j · S04j2 · S04j3 |
| A5 | W-6 실효 판정에서 모듈 · 설정 파일 조건을 뺀다(KB-2) | S10m · S10n |
| A6 | W-6 `$firstErr`의 제어 문자 치환을 뺀다(KB-7) | S08cc |
| A7 | W-6 status 줄의 치환을 뺀다(KB-7) | S10cc |
| A8 | W-6에 `$script:` 대입을 넣는다(KB-5) | S12 |
| A9 | W-6 보안 입력 직후 클립보드 비움을 뺀다(KB-5) | S01 외 99 |
| A10 | W-6 finally의 `$Error` 정리를 뺀다(KM3 꼴) | S01 외 112(S08c · S11a 포함 — 라운드 2 재실행 115) |
| A11 | (라운드 2) W-6 Core 스냅인 확인을 뺀다(KB2-1) | S12 · S10p |
| A12 | (라운드 2) W-6 설정 파일 판정을 옛 정규식으로(KB2-1) | S12 · S10q |

빌더 B부(`build-K/mutate-b.ps1` — 41개 + M00 · **41 / 41 잡힘 · M00 exit 0 · FAIL 0**):

| ID | 변이 | 잡은 시나리오 |
|---|---|---|
| M00 | 없음(사본 그대로 — `-Dir` 경로 확인) | exit 0 · FAIL 0 · 4421 / 4421 |
| M01 · M02 | O-6 사후 · LOAD의 stdin에서 LF를 뺀다(`$pw \| kubectl …`) | ST-O6B · O6B-01–03 · CH-01 · CC-O6B / ST-WL · WL-01 · WL-02 · CH-01 |
| M03 | patch에서 `-cas`를 뺀다 | ST-W2 · W2-01 외 12 |
| M04 | 생성한 웹훅 값을 화면에 낸다 | W2-01 외 10(노출) |
| M05 | O-1 FAIL 사유에 값을 넣는다 | O1-02(노출) |
| M06 | O-5 자격 헤더를 argv로(`-H $hdr[1]`) | ST-O5 · O5a-01 외 13 |
| M07 | O-6 사전 `$lint`의 꼬리에서 `-client`를 뺀다 | ST-O6A · O6A-01–11 · O6A-P1 |
| M08 | O-3 dev ≠ prod 비교를 끈다 | O3-04 · O3-11 |
| M09 | O-4 `token_ttl` 기대를 32일로 | O4-01 · O4-02 · O4-03 · O4-05 · CC-O4 |
| M10 | LOAD의 `load-<env>` 정지점을 뺀다 | WL-01–04 |
| M11 | O-5 `no-store` 판정을 끈다 | O5c-02 |
| M12 | W-2 「dev 먼저」 가드를 끈다 | W2-03 |
| M13 | O-6 사후 `CLIENT LIST` 기대를 허용으로 | O6B-01–03 · CH-01 · CC-O6B |
| M14 | 응답 유실 표시(`$lost = $rc`)를 끈다 | W2-14 · W2-15 · W2-23 · W2-24 |
| M15 | O-6 사후 `--askpass` 대신 `-a $pw`(argv) | ST-O6B · O6B-01–05 · CH-01 · CC-O6B |
| M16 | acl 삭제 — 허용 목록 판정을 끈다(런타임) | DEL-03 · DEL-04 · DEL-05 · DEL-06 |
| M16b | acl 삭제 — 허용 목록 상수에 admin 경로를 더한다(정적) | ST-DEL · DEL-04 |
| M17 | acl 삭제 — 재타자 대조를 끈다 | ST-DEL · DEL-08 |
| M18 | acl 삭제 — 키 집합 판정을 끈다 | DEL-07 |
| M19 | acl 삭제 — 삭제 뒤 재판정 대신 「없음」으로 둔다 | DEL-10 · DEL-11 · DEL-12 |
| M20 | O-5 `curl.exe -q --version` → `--version`(KB-1) | ST-O5 · O5 18개 |
| M21 | O-5 환경 변수 판정을 끈다(KB-1) | O5-13–O5-18 |
| M22 | O-1 `TF_*` 판정을 끈다(KB-8) | O1-09–O1-12 |
| M23 | O-2 실효 판정에서 모듈 · 설정 파일 조건을 뺀다(KB-2) | ML-O2 |
| M24 | O-3 실효 판정에서 설정 파일 조건을 뺀다(KB-2) | ML-O3 |
| M25 | W-2 설정 파일 목록에서 사용자 범위를 뺀다(KB-2) | W2-01–21 · W2-23–26 · CC-W2 · W2-P1(27개 — 공통 사후의 설정 파일 두 곳 확인 순서) |
| M26 | O-4 값 출력의 제어 문자 치환을 뺀다(KB-7) | CC-O4 |
| M27 | O-6 사후 kubectl 앞 `Remove-Item Env:VAULT_TOKEN`을 뺀다(KB-4 · 정적) | ST-O6B · O6B-01–05 · CH-01 · CC-O6B |
| M28 | LOAD — 지운 토큰을 kubectl 직전에 되살린다(KB-4 · 정적은 통과) | WL-01 · WL-02 · WL-03 · WL-05 · CH-01(모의 호출 시점 env) |
| M29 | O-2에 `$global:` 대입을 넣는다(KB-5) | ST-O2 |
| M30 | O-3 보안 입력 직후 클립보드 비움을 뺀다(KB-5) | O3-01–06 · O3-08–12 · O3-P1 · ML-OK |
| M31 | O-3 웹훅 서로 다른 글자 하한을 끈다(KB-9) | O3-12 |
| M32 | W-2 `$wh43` 하한 16 → 1(KB-9) | W2-26 |
| M33 | O-2 하한 16 → 1(KB-9) | O2-09 |
| M34 | LOAD 실패 문구를 옛 판으로(KB-10) | WL-05 |
| M35 | O-4 `token_type` 판정을 끈다(KB-6) | O4-06 |
| M36 | O-6 사전 `$fx`를 늘 빈 값으로(KA-3) | O6A-07 · O6A-08 · O6A-09 |
| M37 | O-4 finally의 `$Error` 정리를 뺀다(KM3 꼴) | O4-04 · ML-O4 |
| M38 | O-2 `$firstErr` 치환을 뺀다(KB-7) | CC-O2 |
| M39 | W-2 status 줄 치환을 뺀다(KB-7) | CC-W2 |
| M40 | O-6 사후 DRYRUN 응답 치환을 뺀다(KB-7) | CC-O6B |
| M41 | O-5 INFO 줄 치환을 뺀다(KB-7) | CC-O5 |
| M42 | (라운드 2) O-3 Core 스냅인 확인을 뺀다(KB2-1 ①③) | ST-O3 · ML2-O3 |
| M43 | (라운드 2) O-3 설정 파일 판정을 옛 정규식(`"EnableModuleLogging"\s*:\s*true`)으로(KB2-1 ②) | ST-O3 · CFG-1–CFG-8(CFG-9 소문자는 옛 정규식도 잡는다) |
| M44 | (라운드 2) O-3 역슬래시-u 갈래를 뺀다(KB2-1 ②) | ST-O3 · CFG-7(전부 이스케이프 꼴) |
| M45 | (라운드 2) O-2 실효 목록에서 Management를 뺀다(KB2-1 ①) | ST-O2 · ML2-MGMT |
| M46 | (라운드 2) O-4 Core 스냅인을 읽지 못해도 멈추지 않는다(KB2-1 ①) | ST-O4 · ML2-NOSNAP |
| M47 | (라운드 2) O-5 멈춤 목록에서 `SSL_CERT_*`를 뺀다(KB2-2) | ST-O5 · O5-19 · O5-20 |
| M48 | (라운드 2) O-1 홈 `~` 줄임을 뺀다(KB2-2) | ST-O1 · O1-13 |
| M51 | (라운드 2) O-5 curl 경로의 `~` 줄임을 뺀다(KB2-2) | ST-O5 · O5-21 |
| M49 | (라운드 2) 삭제 블록이 입력의 비 ASCII를 지운다(정규화 — KB2-3) | DEL-06 · DEL-20 · DEL-22 |
| M50 | (라운드 2) 삭제 블록이 삭제 종료 코드를 믿는다(재판정 대신 — KB2-3) | DEL-18 |

**라운드 1 네 묶음 합계: 생존 0**(리뷰 A 12 · 리뷰 B 10 · 빌더 A부 10 · 빌더 B부 41 + M00 기준선). **라운드 2 다섯 묶음 합계: 생존 0**(리뷰 B 라운드 1 8 + N2 적용 불가 · 리뷰 A 12 · 리뷰 B 라운드 0 10 · 빌더 A부 12 · 빌더 B부 52 + M00 기준선). 변이 스크립트 · 출력은 스크래치(`…\scratchpad\t075\review-K-A\` · `review-K-B\` · `review-K-B\r1\` · `build-K\mutate-*.ps1` · `build-K\mut\` · `mut-a\` · `r1\` · `r2\`)에 있다.

### 하네스 결함 · 고친 것(실행 기록)
- B부 모의가 블록의 호출 사슬 안에서 `$script:`를 쓰면 블록 파일의 스크립트 범위로 풀린다(동적 범위) — HttpFn의 상태를 `$global:`로 옮겼다.
- 모양 단언이 `CommandAst.Extent`(리다이렉트 `2>$null` 포함)를 비교해 거짓 FAIL — 명령 낱말만 비교(`Cmd-Text`).
- `$env:KUBECONFIG` 금지를 글자 검색으로 하다 주석 속 언급에 걸렸다 — AST 변수 참조로 바꿨다.
- 가드 시나리오의 가짜 비밀이 공개 접두(`PLACEHOLDER-` · `django-insecure-`)로 시작해 판정 문구가 바늘에 걸렸다 — 공개 상수 안에 통째로 드는 조각만 바늘에서 뺀다.
- (라운드 1) 리뷰 B KM3이 「무해」로 살아남은 까닭 = B부에 `$Error` 정리 단언이 없었다(A부는 S11a 한 사례) — 공통 사후로 올렸다(§3 10).
- (라운드 1) 빌더 변이 스크립트의 결함: `@((P a b))`의 괄호가 쌍 하나를 `@(a, b)`로 풀어 첫 실행이 전부 「적용 실패」였다 — 쌍을 되감고 `-DryRun`(적용 · 파서 확인만)을 더한 뒤 다시 돌렸다(하네스 결함 아님 · 결과는 다시 돌린 것).
- (라운드 2) `Get-Command` 모의를 더한 첫 실행이 B부 중간에 「가드 실패: tofu 이 모의 함수로 풀리지 않는다」로 멈췄다 — O1-13이 넣은 `$global:FakeSrc['tofu']`가 다음 시나리오의 `Assert-Guard`(Reset-Mocks 앞)에 남아 가짜 Application을 돌려줬다. 가드는 모듈 이름을 붙인 실물 `Get-Command`로 보게 하고, 시나리오 끝에 FakeSrc · Core 결함을 비운다(§3 14).
- (라운드 2) **문서의 실행 꼴(`pwsh -NoProfile -File`)에서만 CFG-1–9가 거짓 FAIL**했다 — 리뷰어 변이 묶음(`-File`로 하네스를 부른다)이 드러냈다. `-File`로 돌리면 하네스 스크립트 범위가 곧 전역이고 PowerShell 변수 이름은 대소문자를 가리지 않아, 루프 변수 `$script:cfgText`가 모의 `$global:CfgText`(해시 테이블)와 **같은 변수**였다 → 시나리오가 표 대신 표 자신을 설정 텍스트로 넣어 블록이 정책을 보지 못했다. 빌더는 `-Command "& '<harness>'"`(UTF-8 출력용)로만 돌려 놓쳤다. 고친 것: 루프 변수 이름을 `$script:cfgCaseScope` · `$script:cfgCaseText`로 · B부 시나리오마다 「모의 상태 표(CfgText · ModLog · FakeSrc · F)가 해시 테이블 그대로」 자체 단언 · 최종 검증을 두 실행 꼴 모두로(354 / 354 둘 다). 이 결함은 거짓 FAIL(더 많이 잡는 쪽)이었다 — 블록 결함을 가린 적은 없다. 다만 고치기 전 `-File` 변이 실행의 「잡힘」에는 CFG 소음이 섞여 있어 리뷰어 묶음을 고친 뒤 다시 돌렸다(§4 변이 표).

## 5. VD-T075-17 — 최종 aclfile의 로컬 기동 · LOAD 시험(설계 D20 「조각 ③ 끝 조건」) · 실물 cmdlet 확인

조건: 운영 digest Dragonfly(`ghcr.io/dragonflydb/dragonfly:v1.40.1@sha256:ebf3c6c2…e29986`) · 운영 인자 그대로 · 가짜 비밀번호(RNG 32B → base64url 43 — 스크래치에만) · aclfile = W-6 블록의 `$render`로 렌더한 바이트 그대로(dev 420 B · prod 274 B · CR · TAB · BOM 0 · `$lint` 통과 · 렌더 당시 W-6 SHA-256 `52d96cdc…bf940`). 그 뒤 W-6은 머리 주석 · 모듈 로깅 실효 확인(라운드 1 · 라운드 2) · 제어 문자 치환 · 쌍 판정 문구(KA-11)만 바뀌었다(지금 `d3c35e70…9938`) — 같은 가짜 비밀번호로 지금 파일의 `$render`를 다시 돌린 바이트가 VD 때 파일과 dev · prod 모두 같다(2026-11-18 라운드 2 뒤 재확인 `r2/render-same-r2.txt` — `identical=True` 둘 · `$lint` 빈 값). 증거(세션 스크래치 — 저장소 밖 · 세션이 끝나면 사라질 수 있다 · 보존은 컨트롤러가 `.superpowers/t075/`로 옮긴다): `C:\Users\2401\AppData\Local\Temp\claude\8d04d95f15c3c8f9\e2749fad-6c31-4255-9e8b-25dbb3fad05e\scratchpad\t075\build-K\vd17\` · `…\build-K\r1\`(가짜 비밀번호 파일 `fake-pw.json`은 `vd17\`에만 있다 — 옮기지 않는다).

| 항목 | 기대 | 측정 | 증거 |
|---|---|---|---|
| 기동 로그 aclfile 오류(`could not load ACL file` · `Error while parsing aclfile` · `Error materializing acl file` · `Invalid password hash`) | 0 | dev 0 · prod 0 | `boot-dev.log` · `boot-prod.log` |
| 무인증 PING | `-NOAUTH` | dev · prod `-NOAUTH Authentication required.` | `probe-dev.txt` · `probe-prod.txt` |
| admin `ACL LOAD` | OK | dev · prod OK · `ACL LIST`의 pod 사용자 행 끝 `+@all -@admin -@dangerous -client $all` | 같은 파일 |
| pod 사용자(identity-admin · sample-pod)로 `REPLICAOF NO ONE` · `SLAVEOF NO ONE` · `SAVE` · `CLIENT KILL` | NOPERM | 전부 NOPERM(+ `CLIENT LIST` · `CLIENT PAUSE` · `ACL LIST` · `ACL SETUSER` · `CONFIG SET` · `FLUSHALL`도 NOPERM) · prod identity-admin 같음 | `probe-dev.txt` · `probe-prod.txt` |
| 앱 경로(R5 ②) | OK | health-ping · denylist-lookup · writer-user · writer-sid · floor-read · reapply OK · sample-pod reader-get OK · reader-set-denied NOPERM · cross-denied NOPERM · Celery(identity-admin `CELERY_CONFIG`) 마커 셋 OK · warm-shutdown 복원 · worker NOPERM 0줄 | `probe-dev.txt` · `celery-dev.txt` · `celery-worker.log` |
| admin `ACL DRYRUN` 표(O-6 사후의 실측 응답 문구) | 거부 5 · 허용 2 | 기대대로 · prod `sample-pod` = `ERR User 'sample-pod' not found` | `probe-dev.txt` · `probe-prod.txt` · `askpass-dev.txt` |
| 라운드 0 블록(O-6 사후 · LOAD)을 실물 redis-cli 6.0.16에 — 심(`kubectl` → `docker exec -i`)으로 | A dev PASS 7/7 · B LOAD OK · C prod PASS 5/5 · D 옛 규칙 컨테이너 FAIL · E · F 비밀번호 어긋남 = 판정 불가 · STOP · G 정지점 다른 단어 = kubectl 0 | 전부 기대대로 · argv · 화면의 비밀번호 0 · 끝난 뒤 `VAULT_*` 0(2026-11-17 — **라운드 0 블록**). 라운드 1은 두 블록의 kubectl argv · stdin 길을 바꾸지 않았다(`$kargs` · stdin 식 글자 그대로 — ST-O6B · ST-WL 단언) — 바뀐 것은 kv 뒤 `VAULT_TOKEN` 지움 · INFO 줄 · 출력 치환 · 실패 문구 · 모듈 로깅 실효 확인이고 하네스와 아래 실물 cmdlet 확인이 본다. 컨테이너를 다시 세우지 않았다 | `blockcheck.txt` |
| (라운드 1 · 2) 블록 11개의 모듈 로깅 실효 확인을 실물 cmdlet(`Import-Module` · `Get-Module` · `Get-Command ForEach-Object` · `Join-Path` · `Split-Path` · `Test-Path` · `Get-Content`)으로 — vault · tofu · kubectl · curl은 가림(출력 없음 · exit 1) · 첫 입력에서 멈춤 | 보통 창: 실효 확인을 지나 다음 단계 · `-SettingsFile` 켜짐 창: 아무것도 부르기 전 중단 | 라운드 2 블록(2026-11-18): 보통 창 11/11 통과(설정 파일 확인 2 · 첫 외부 호출 = vault version · tofu version · curl `-q --version` — 이 PC의 설정 파일은 값 무관 판정에도 걸리지 않았다) · `-SettingsFile` **Utility** 대상 창 11/11 · **Core** 대상 창 11/11(Utility · Security · Management = False · 블록은 그 파일을 못 읽는다 — Core 스냅인 실효 값이 잡았다 · KB2-1 ③) · **Management** 대상 창 11/11 — 전부 KB-2 문구로 중단 · 외부 호출 0. 실효 값 실측 `r2/probe-core.ps1`(대상별 · `*` = 넷 다) | `r2/realenv2-pass.txt` · `r2/realenv2-utility.txt` · `r2/realenv2-core.txt` · `r2/realenv2-management.txt` · `r2/probe-core.txt` · `r1/realenv-smoke.ps1` |
| 증거 파일의 비밀번호 · 해시 | 0 | 0(`#<hash>`로 가렸다) | `vd17-scan.ps1` |
| 정리 | 컨테이너 · 네트워크 0 | `t075-vd17-df` · `-dfp` · `-dfo` · `t075-vd17-net` 삭제 · 남은 것 0 | — |

## 6. 하네스가 증명하지 못하는 것
- 실물 Vault CLI의 `kv patch "-cas=<n>"` 거동(나머지 키 보존 · CAS 문구) · `kv metadata delete` 뒤 `No value found` 문구 — 모의가 모형이다. 블록은 되읽기(보존 키 해시 · 버전 +1) · 삭제 뒤 재판정으로 잡는다(VD-T075-11 — 첫 라이브 W-2 dev · 2단계가 측정이다).
- `kubectl exec -i`가 관리자 kubeconfig로 API 서버를 거쳐 stdin 바이트를 그대로 넘기는지 — 로컬 측정은 `docker exec -i`였다. 어긋나면 AUTH 실패 = O-6 사후 판정 불가 · LOAD STOP(fail-closed · LOAD 미실행)이다.
- Cloudflare Access 실응답(401/403 · `Set-Cookie` · 헤더 이름) · Traefik 액세스 로그 필드 · ESO 갱신 · kubelet 반영 시간.
- 운영자 PC의 모듈 로깅 정책 레지스트리 · `tofu output -json service_tokens`(sensitive) 출력 모양 — 블록은 해석 실패를 FAIL로 둔다. 모듈 로깅 실효 확인은 이 프로세스의 넷(Core 스냅인 · Utility · Security · Management — 라운드 2)을 본다. 블록의 명령 허용 목록에 든 cmdlet은 전부 이 넷에 산다(정적 관문) — 그 밖의 모듈에 대한 정책은 블록 값이 지나가지 않아 보지 않는다(받아들인 범위).
- **8자 미만 조각 노출은 정확한 사유 문구 단언으로만 잡힌다(받아들인 한계 — 라운드 2 KB2-3)**: 노출 바늘은 8자 이상 조각 · 해시 · base64 꼴이다. 그보다 짧은 조각이 화면에 나오면 공통 노출 단언은 못 잡고, 시나리오의 FAIL 사유 문구를 글자까지 단언한 사례(예: O1-02 · 리뷰 B KM10)만 잡는다.
- 모의 호출 시점 env 검사는 모의를 거치는 vault · kubectl · tofu · curl 호출만 본다(블록이 다른 자식 프로세스를 띄우는 길은 정적 관문의 명령 허용 목록 · 절대 경로 실행 파일 0이 막는다).
- **O-3은 US6(T075) 시점의 게이트다**(KA-8) — 면제 셋(`api_token` · `store_id` · `key`)과 판정 밖 키(`client_id` · `client_secret`)가 sentinel이어야 PASS라 T081(Authentik 실값) · T082(OpenFGA 실값) 뒤에는 그 행이 구조적으로 FAIL한다. 그때는 기대를 바꾼 판(T081 · T082가 만든다)을 쓰고 이 블록을 고쳐 돌리지 않는다.

## 7. 남은 위험(라이브 실행 시)
- **2 · 3단계가 두 env의 acl을 한 번에 쓴다**(§3 편차 5) — 렌더가 기동 무인증 꼴이면 두 env의 마운트 파일이 함께 그 꼴이 된다. 막는 것: W-6 `$lint`(허용 토큰 글자 대조 · put 전) · VD-T075-17(같은 렌더 함수의 실물 기동) · 런북 B 「규칙」의 재시작 요인 보류(2단계부터 prod O-6 사후 PASS까지 두 env · L6 전 SUC 일정 확인 — KA-7).
- 성공한 `ACL LOAD`는 그 Dragonfly의 모든 연결을 끊는다 — GP-2 전이라 소비자는 data-assert뿐이다(GP-2 뒤의 회전 · 재렌더는 T084가 순서를 정한다). dev LOAD 뒤 GP-A 전에 data-assert가 다시 돌면 `acl-list` FAIL은 기대된 일시 상태다(런북 B 「규칙」).
- redis-cli는 오류에도 종료 코드 0이다 — 응답 문구가 바뀌면(Dragonfly 판 올림) 분류가 `err`로 떨어져 FAIL(fail-closed)이다 — 판 올림 때 이 표를 다시 잰다.
- LOAD의 kubectl 실패는 「결과 미확인」이다(KB-10) — LOAD가 닿았는지 O-6 사후로 본 뒤에만 다시 보낸다.
- O-1 · O-5는 tofu 상태 자격(운영자 PC)이 필요하다 — 모듈 로깅 가드 · 실효 확인이 첫 단계다 · 출력은 PASS 줄의 비밀 아닌 값뿐이다. INFO 줄의 실행 파일 경로(홈 `~`)를 운영자가 자격을 넘기기 전에 본다(라운드 2 KB2-2).
- 설정 파일 판정은 값과 무관하다(라운드 2 KB2-1) — 운영자 PC의 `powershell.config.json`에 `ModuleLogging`(값 `false` 포함)이나 역슬래시-u가 있으면 블록이 멈춘다(거짓 멈춤 — 그 줄을 지운 창 · PC에서). 이 PC의 두 설정 파일은 걸리지 않았다(§5 실물 확인).
- W-2는 dev ≠ prod를 SHA-256으로만 비교한다(값 출력 0). 블록 밖에서 같은 값이 들어간 경우는 STOP(사람 판정)이다. 웹훅 하한 16은 진짜 CSPRNG 값을 2.2×10⁻¹³ 이하의 확률로 STOP시킨다(사람 판정 — 데이터 손실 아님).
- acl 삭제 블록은 「머지 전에만 지운다」의 예외다 — 지우는 동안 ES가 잠시 `SecretSyncedError`일 수 있다(Secret `Retain` · 돌고 있는 Dragonfly 영향 0). 사용자 경로는 허용 목록 밖이라 이 블록으로 지울 수 없다.
