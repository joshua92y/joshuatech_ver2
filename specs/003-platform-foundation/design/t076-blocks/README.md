# T076 블록 — 음성 대조(O-10) · tester-m2m 시드(W-7) · Vault 로그인 JWT(O-9) · tester 블록(L-8 · O-8 · C-8) · 모의 하네스 둘 · 끝 줄 정본 · 남은 위험

빌드 r0(2026-11-20 — 빌더 B1–B4: 조각 ① Vault 정책 · ② 운영자 블록 W-7 · O-9 · O-10 + `harness-op.ps1` · ③ tester 블록 O-8 · C-8 · L-8 + `harness-tester.ps1` · ④ 에이전트 층 · 문서) → 리뷰 r0 셋(**R-S** 자격 · 보안 11건 · **R-C** 설계 · 계약 정합 + 하네스 변이 15건 · **R-O** 운영 흐름 · 런북 12건 — 셋 다 `approve_with_fixes` · HIGH 1 = C-01/RO-01 같은 건) → 컨트롤러 결정(`.superpowers/t076/decisions-controller.md` 「## r0 리뷰 처리」 — 수정 지시의 정본) → **수정 라운드 r1**(2026-11-20 — F1 조각 ① 문서 · F2 조각 ② · F3 조각 ③ · F4 조각 ④ · §2a) → **컨트롤러 보정 일곱**(r1 뒤 · §2a 끝) → **확인 리뷰 rv2**(README 작성 + R-S · R-C · R-O 2차 — 판정 approve · approve · approve_with_fixes) → **수정 라운드 r2**(G1 · G2 — §2a 끝 「r2 대응」 · 결정 정본 `.superpowers/t076/decisions-controller.md` 「## rv2 확인 리뷰 처리」). 결정 정본은 `../t076-design.md`(D1–D16 · VD-T076-1–9 · 끝 「정정 노트」 23항목(r0 리뷰 1–20 · rv2 21–23) — VD-T076-10 포함 · 본문은 고치지 않고 정정 노트에만)다. 이 문서는 컨트롤러 결정 C-06에 따라 **블록 글자 · 끝 줄 · 하네스 결과의 정본**이다 — 런북 `docs/runbooks/bootstrap.md` §3 · §4 「T076」 표가 「정확한 글자는 블록 README」로 미룬 줄은 §5에 있다(§5.7 대조). **빌드 · 수정 동안 라이브 실행 0** — Vault · 클러스터 · Cloudflare · GitHub 호출 0이고, 블록은 모의 하네스와 로컬 실측(F3 실물 curl — 127.0.0.1 로컬 서버만 · B3 · R-O · F3 스레드 작업 실험 — 루프백)에서만 돌았다. 라이브 결과의 자리는 build-notes 「## T076」 · 런북 §3 · §4 T076 기록 칸 · tester 보고 `research/<라이브 날짜>-e2e-us6-t076.md`다. §4의 하네스 숫자는 r2(G1)가 블록 · 하네스를 고친 뒤 직접 두 번씩 돌린 값이다(첫 작성 때의 값 — 2026-11-20 22:39–22:41 KST — 은 §4 「r1 → r2」 줄에 남겼다).

## 1. 파일

| 파일 | 종류 | 줄 | 역할 |
|---|---|---|---|
| `o10-vault-audience-negative.ps1` | O(판정 · 운영자 · 창 D) | 253 | O-10 음성 대조(VD-T076-1) — 관리자 kubeconfig로 audience 없는 agent-view 10분 토큰을 변수로만 받아 클레임 판정 → 창 C(18200) 무자격 seal-status(200 · unsealed · `vault-cluster-d3b29227`) → e2e-reader 로그인 1회(본문 stdin) → 거부(4xx · auth 없음)면 PASS · 통과면 그 자리에서 revoke-self + FAIL. 쓰기 = 10분 토큰 발급 1회뿐 · vault CLI 0. T075 O-5 창 전제 · curl 가드 + W-2 Vault 판정에서 파생 |
| `w7-seed-tester-m2m.ps1` | W(쓰기 · 운영자 · 창 D) | 386 | W-7 `kv/platform/access/tester-m2m` 1회 시드 — tofu `infra/cloudflare` 출력 `service_tokens`의 tester-m2m 두 값만 → 꼴 판정 → `vault status`(+ `cluster_name`) → root 토큰 → 상태 판정(absent · live · dead) → absent일 때만 정지점 `seed` 뒤 `kv put "-cas=0"`(JSON stdin) → 되읽기 SHA-256 + current_version 1 · 마지막 줄 = 창 정리 안내 두 꼴(OK · SKIP = 창 C 종료 · 그 밖 = 유지 — r2 RO2-02). T075 `w2-kv-seed.ps1` 바이트 사본에서 파생(원칙 (a)–(h)) |
| `o9-issue-vault-jwt.ps1` | O(발급 · DPAPI 파일 · 운영자 · 창 D) | 221 | O-9 tester의 Vault 로그인 JWT(UD-16) — 정지점 `issue` = `kubectl create token agent-view -n kube-system --audience vault --duration=1h` → 클레임 판정 → DPAPI(CurrentUser) `%LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt`(덮어쓰기) → O-8 꼴로 되읽어 대조 · 정지점 `clear` = 그 파일 삭제 |
| `l8-live-identity-admin.ps1` | T(tester 1차 · 비밀 0) | 341 | L-8 identity-admin dev · prod 증거 사다리 ⓪–⑤(Application revision · ES Ready · ES 스펙 · 워크로드 · `startup_check: OK` · 무헤더 401) — env마다 12 = 24 · admin 무자격 302는 INFO · 읽기만 |
| `o8-probe-identity-m2m.ps1` | T(tester 2차 · 자격 블록) | 401 | O-8 — DPAPI JWT 읽기 → 블록 소유 port-forward(스레드 작업 · `--address 127.0.0.1 svc/vault :8200` · Forwarding 줄 ≤ 45 s — r2 RO2-01) → seal-status → e2e-reader 로그인 → `sys/capabilities-self` 관문 → tester-m2m 읽기 → identity-m2m dev → prod 판정 a(`/health`) + b–e(404 넷) · INFO → `finally` revoke-self · port-forward 종료. T075 `o5-probe-identity-m2m.ps1` 바이트 사본에서 파생 |
| `c8-correlate-logs.ps1` | T(tester 2차 · 비밀 0) | 197 | C-8 O-8 요청의 Traefik 액세스 로그(투영 필드만) · identity-admin web 로그(`request_id`) 대조 — env마다 404 넷 + pod 하나 = 10 |
| `harness-op.ps1` | 하네스(W-7 · O-9 · O-10) | 1464 | T075 `harness.ps1` B부(가드 · 모의 · 노출 바늘 · 공통 사후 · 정적 관문)에서 파생 — 174 시나리오(§4) |
| `harness-tester.ps1` | 하네스(O-8 · C-8 · L-8) | 1252 | T075 B부 모의 방식에서 파생 — Ingress 표 모형 HTTP · Vault HTTP · kubectl · 스레드 작업 모의 · 163 시나리오(§4) |
| `README.md` | — | — | 이 문서 |

줄 수는 `wc -l` 실측(2026-11-20 — r2 뒤 다시 잼 · 2026-11-21 컨트롤러 보정 r2 뒤 harness-tester만 1243 → 1252). 하네스 둘은 블록 규약 대상이 아니다(빈 줄 · 함수 정의가 있다).

### 블록 공통 규약(블록 글자에서 확인한 것 — 2026-11-20 측정 · 하네스 정적 관문과 같은 판정)

- **여섯 모두**: BOM · CR · TAB 0 · 빈 줄 0 · 끝 `}` + LF 1 · UTF-8 유효 · 파서 오류 0 · 최상위 문장 1개(`& { … }`) · 본문 첫 문장 `Set-PSDebug -Off`(1곳) · 세션 고정(`$ErrorActionPreference = 'Stop'` · `$WarningPreference = 'Continue'` · `$PSNativeCommandUseErrorActionPreference = $false` · `$WhatIfPreference = $false` · `$ConfirmPreference = 'High'` · `$PSDefaultParameterValues = @{}` · `Set-StrictMode -Version 3.0` — tester 셋은 `$PSNativeCommandArgumentPassing = 'Standard'`를 더한다) · pwsh 7.5 미만이면 멈춤 · 모듈 로깅 4키 가드(`HKLM` · `HKCU`의 `…\PowerShellCore\ModuleLogging` + 그 값 `UseWindowsPowerShellPolicySetting`=1이면 `…\Windows\PowerShell\ModuleLogging` 둘) + 실효 확인(`Import-Module` 세 모듈 · `Get-Module` Utility · Security · Management의 `LogPipelineExecutionDetails` · `Get-Command ForEach-Object -CommandType Cmdlet`의 Core 스냅인 · `powershell.config.json` 두 곳(`$PSHOME` · `$PROFILE.CurrentUserAllHosts`의 폴더)은 값과 무관하게 텍스트에 낱말 `ModuleLogging`(대소문자 무관)이나 역슬래시-u가 있으면 멈춤 · 확인하지 못하면 멈춤) — T075 KB-2 · KB2-1 꼴 글자 그대로이고 값이 오가는 첫 동작보다 먼저다 · 응답 · 로그에서 온 글자는 `\p{Cc}` → `?` · 160자 · 출력은 `Write-Host`(운영자 셋은 + `Write-Warning`)뿐(성공 스트림 0) · `$Error`는 이 실행분만 `finally`가 지운다(시작 때 `$errTop` 기준).
- **운영자 셋(O-10 · W-7 · O-9)**: 줄 1 = `& {` · param 0 · `try`/`finally` 하나(catch 0 — 멈춤은 throw로 밖에 나가고, 그 전에 `finally`가 머리 줄과 끝 줄을 낸다) · `Read-Host`는 정지점 헬퍼 안에서만(O-10 `$stop` 1 · W-7 `$stop` · `$readSecret` 2 · O-9 `$pick` 1)이고 바로 앞 직계 문장이 `$Host.UI.RawUI.FlushInputBuffer()` · 입력은 전부 가려진다(`-MaskInput` · root 토큰은 `-AsSecureString`) · **남는 인자** = `$nArg = @($script:args | Where-Object { $null -ne $_ }).Count` — 모듈 로깅 실효 확인 바로 뒤(W-7은 클립보드 기록 판정 · 모듈 로깅 뒤) · 첫 외부 이름 질의 앞 · 하나라도 있으면 외부 호출 0 · 정지점 0으로 멈춘다(값 미출력 · `$null`을 1로 세는 `@($script:args).Count` 꼴 0) · 관리자 kubeconfig = 블록 리터럴 `$kc = Join-Path $HOME '.kube\joshuatech-admin.yaml'`(O-10 · O-9 — 존재 확인 뒤 `kubectl @kargs` 한 곳의 `--kubeconfig $kc`) · `$env:` 대입은 W-7의 `VAULT_ADDR` · `VAULT_TOKEN`뿐(블록이 만든 것만 `finally` 첫 두 문장에서 지운다).
- **tester 셋(L-8 · O-8 · C-8)**: 줄 1 = `param(…)`(특성 · CmdletBinding 0 — 공통 매개변수 0) · 줄 2 = `& {` · `Read-Host` 0 · `$Host` 0 · 입력 판정 순서 = `$PSScriptRoot`(파일로만) → 남는 인자 `if (@($script:args).Count -gt 0) { throw "입력은 …" }` → 입력 꼴(정규식) — 모두 kubectl · 네트워크 호출 전 · `try`/`catch`(전부)/`finally` — 멈춤도 블록 안에서 잡아 `STOP <사유>` 줄 다음에 끝 줄을 낸다 · 본문 끝 두 문장 `if ($done -and $res.Count -eq <N> -and $nPass -eq <N>) { exit 0 }` · `exit 1` · `$env:` 대입 0 · kubeconfig = `$kc = Join-Path $HOME '.kube\agent-view.yaml'` 한 곳 · 모든 kubectl에 `--kubeconfig`(port-forward 밖은 `--request-timeout=20s` · `30s`).
- **첫 해석 판정(S-10 — 여섯 모두)**: 외부 명령마다 형식 필터 없는 `Get-Command <이름> -ErrorAction SilentlyContinue`의 첫 결과 `CommandType`이 `Application`이 아니면(같은 이름의 함수 · 별칭 · 프로필 정의 · ExternalScript) 그 명령의 첫 호출(버전 확인 포함) 전에 멈춘다 — O-10 `kubectl` · `curl.exe` / W-7 `tofu` · `vault` / O-9 `kubectl` / O-8 · L-8 `curl.exe` · `kubectl.exe` / C-8 `kubectl.exe`. 외부 이름에 `-CommandType` 질의 0(정적 관문 — 형식 필터는 가림을 건너뛴다).
- **환경 변수 판정(이름만 낸다 · 대소문자 무관)**: 여섯 모두 `SSL_CERT_FILE` · `SSL_CERT_DIR` · `CURL_CA_BUNDLE` · `SSLKEYLOGFILE` · `HTTP_PROXY` · `HTTPS_PROXY` · `ALL_PROXY`. W-7은 + `TF_WORKSPACE` · `TF_DATA_DIR` · `TF_LOG*` · `TF_CLI_ARGS*` · `VAULT_*`(`VAULT_ADDR=http://127.0.0.1:18200`만 허용) · `~/.vault-token` · 클립보드 기록. O-8은 + `VAULT_*`(전부) · Transcription 정책(레지스트리 · 설정 파일 낱말) · 실행 파일이 저장소 · TEMP · TMP 아래.

## 2. 설계 결정 대응

| 결정 | 어디서 지키나 | 하네스 근거 |
|---|---|---|
| D1 범위 · 산출물 — 닫힌 T075 블록 · 하네스 변경 0 | 블록 여섯 · 하네스 둘 · 이 문서(C-06) | `git diff --stat -- specs/003-platform-foundation/design/t075-blocks` 빈 출력(2026-11-20 재확인) · 닫힌 T075 하네스 359 / 359 · 11359(F2 r1 최종 재실행) |
| D2-1 W-7 — tofu 출력에서 tester-m2m 두 값만 · 꼴(`\A[0-9a-f]{32}\.access\z` · `\A[0-9A-Za-z_-]{54}\z` · `-cnotmatch`) · tofu 동안 `VAULT_*` 0 · 상태 기계(absent · live · dead) · absent만 `-cas=0` + JSON stdin · 되읽기 SHA-256 + current_version 1 · 응답 유실 재판정 | W-7 | ST-W7(tofu 호출 둘 · 환경 변수 → tofu → `VAULT_ADDR` → 토큰 순서 · put 1곳 · `kv/` 경로 상수 하나 · 정규식 글자 · live SHA 대조 · `seed`가 `& $write` 앞) · W7-01 · W7-02 · W7-03–12 · W7-13–20(꼴 → Vault 0) · W7-21–29 |
| D2-2 정책(e2e-reader +1 경로 · eso-platform deny 2줄) | 블록 밖(조각 ① — `infra/vault/policies.tf` · vt-14 · vt-14b · vt-16) | R-C 재실행 vt 18 / 18 · 정책 변이 11 모두 FAIL로 잡힘 · B1 vt 변이 13 matched · apply 뒤 판정은 O-8 ⑧(O8-24–27) |
| D2-3 O-9 — `--audience vault --duration=1h` · 클레임(aud · sub · 3600 ± 10 · iat ± 120) · DPAPI CurrentUser(`-Key` 0) · 덮어쓰기 · clear | O-9 | ST-O9(`$kargs` 글자 · DPAPI 한 곳 · `[System.IO.File]` 멤버 · 되읽기 = O-8 꼴 · 클레임 리터럴 · 판정이 쓰기 앞) · O9-01 · O9-02 · O9-03–12 · O9-05 · O9-05b–i · O9-13 · O9-14 · O9-15–20 · O9-21–23 |
| D2-4 O-10 — audience 없는 10분 토큰 · `cluster_name` 확인 뒤에만 전송 · 거부면 PASS · 통과면 revoke + FAIL | O-10 | ST-O10(`$kargs` audience 0 · curl 네 꼴 · `-w` 하나 · 주소 · 경로 · 클러스터 · role 리터럴 · JWT · 토큰 변수 즉시 지움 · 순서) · O10-01–06 · O10-07–10 · O10-11–18 · O10-19–25 |
| D2-5 · D2-6 규칙 · 에이전트 문서 · 컨트롤러 Vault 로그인 0 | 블록 밖(조각 ④) · 블록 쪽 = O-8만 e2e-reader로 로그인한다 | harness-tester 공통 사후 「자격의 길」 · harness-op 「W-7 밖 블록은 vault CLI 0 · `VAULT_*` 0」 |
| D3 블록 규약 | 여섯(§1 공통 규약) | ST-*(관문 5 + 구조 · 세션 고정 · finally · Read-Host · 모듈 로깅 문장 · 대입 제한) · 공통 사후(첫 동작 · 모듈 로깅 순서 · 제어 문자 0 · `$Error` 0) · 모듈 로깅 사례 W7-51–55 · O9-33–35 · O10-34–36 · O8-90–94 · C8-27 · L8-45 |
| D4 ① 입력 · ② 환경 변수 · `VAULT_*` · Transcription · ③ 실행 파일 · ④ whoami | O-8 | O8-80–84 · O8-84b · O8-60–70 · O8-71–74 · O8-73b · O8-73c · O8-75–77 |
| D4 ⑤ JWT(DPAPI 복호 · 꼴 · aud · sub · exp > 지금 + 60 · 수명 ≤ 3610) | O-8 | O8-40–48 · O8-42 · O8-42b–i |
| D4 ⑥ port-forward(정정 노트 10 — S-04 꼴 · 정정 노트 21 — Forwarding 줄 ≤ 45 s · 90회) | O-8 | O8-16 · O8-19 · O8-19b · O8-22 · O8-23 · O8-23b–i |
| D4 ⑦ 로그인 · ⑧ 권한 관문 · ⑨ kv 읽기 | O-8 | O8-49–51 · O8-24–27 · O8-28–35 |
| D4 ⑩ 탐침(판정 a · b–e · INFO · nonce 쿼리 · X-Request-ID) | O-8 | O8-01–15 · O8-14b · O8-17 · O8-18 |
| D4 ⑪ finally(revoke-self · port-forward 종료) · ⑫ 끝 줄 · exit | O-8 | 공통 사후(revoke 정확히 1 · 스레드 작업 Stop · Remove) · O8-52 · ST-O8(끝 줄 · exit 두 문장) |
| D5 C-8(투영 · 복제 1 · 404 넷 정확히 1줄 · pod 대조 — 정정 노트 12) | C-8 | C8-01–13 · C8-02b · C8-06b · C8-09b · C8-20–30 · C8-29b |
| D6 · D12 L-8 사다리 ⓪–⑤(정정 노트 14 — 리터럴은 gitops cb3ba13) | L-8 | L8-01–23 · L8-30 · L8-31 · L8-40–48 · L8-48b |
| D7 운영자 블록 파일(정정 노트 5 — 정지점 단어 · 창 D · 파일로만 · 정정 노트 22 — W-7 창 정리 줄 두 꼴) | O-10 · W-7 · O-9 | §5 · 남는 인자 사례 W7-59–62 · O9-38–42 · O10-42–45 · W-7 공통 사후(창 정리 줄) |
| D8 하네스 — Ingress 표 모형 · 반드시 넣을 사례 | 두 하네스 | O8-03(`/health` Prefix 변이) · 모의 변이 B-H01 · B-H02 잡힘 · R-C 대조표(D8 사례 전부 있음) |
| D10 404 기준값(404 · `text/plain` · 한 줄 · 19 B · ≠ HIT) | O-8 판정 b–e | O8-05 · O8-06 · O8-09 · O8-17(STALE → PASS · C-8이 원 서버 도달을 판정) |
| D13 · D14 디스패치 두 번 · 순서 · 창 | 런북 §3 T076(블록 밖) | — |
| D16 받아들인 위험 · 인계 | §8 | — |
| VD-T076-1–10 | §8 표 | — |

### 2a. 수정 라운드 r1 대응(리뷰 R-S · R-C · R-O r0 — 2026-11-20 · 결정 정본 `.superpowers/t076/decisions-controller.md` 「## r0 리뷰 처리」)

| 지적(심각도 · 리뷰) | 처리 · 고친 곳(담당) | 하네스 사례 | 죽인 변이(§4) |
|---|---|---|---|
| **C-01 · RO-01**(HIGH) Codex 경계 사본 미동기 → codex-parity 빨강 · 설계 §4 목록 누락 | `.claude` 원본을 `.agents/skills/approval-review/boundaries/k8s-security.md`로 바이트 복사(컨트롤러 보정 1) · 정정 노트 7 | — (codex-parity 12 passed, 0 failed) | — |
| **S-01**(MEDIUM) 규칙이 UD-16 로그인 자격을 다루지 않는다 | tester.md · infra.md(+ KR 미러) 「Credentials」 한 문장 — O-8 블록 밖에서는 로그인 자료를 열기 · 복호 · 복사 · 출력하지 않고 무자격 `GET /v1/sys/seal-status` 밖의 요청을 Vault에 보내지 않는다(F4) · port-forward 전면 금지 · settings deny 추가는 하지 않았다(플랫폼 하네스의 seal-status와 부딪힌다 · 인자 순서를 다 못 덮는 패턴 = 거짓 안심) · 정정 노트 6 | — | — |
| **S-02**(MEDIUM) 하네스 노출 단언이 헤더 이름 · 조각을 보지 않는다(r0 변이 M5 통과) | harness-tester 공통 사후 ① 요청별 헤더 이름 집합 ② 자격의 길 = 바늘 집합 ③ ST-O8 `& $get` 네 꼴 · `& $vreq` 다섯 꼴 고정(F3) · 정정 노트 17 | O-8 모든 사례(공통 사후) · ST-O8 | RS-M5 · MH1–MH4 |
| **S-03**(MEDIUM) 「1회용 = 읽고 바로 지우기」는 1회용이 아니다 | 「짧은 `--duration`(10–15분 · 2차 직전 발급) + 사용 뒤 운영자 clear — 사본은 exp까지 유효」로 정의 · `/finish` 차단 항목: vault-unseal §12(F1) · 계약 · 런북 기록 칸 UD-16 행 · 세션 끝 · 노출 의심 문구(F4) · 정정 노트 1 | — | — |
| **S-04**(LOW · 추론) O-8이 port-forward 소유를 확인하지 않는다(127.0.0.1을 남이 쥐면 중계) | `kubectl.exe --kubeconfig $k -n vault port-forward --address 127.0.0.1 svc/vault :8200`(포트는 kubectl이 고른다) · 작업 출력의 `Forwarding from 127.0.0.1:<n> -> 8200` 정확히 한 줄 · ≤ 15 s(r2에서 ≤ 45 s · 90회 — RO2-01 · 아래 「r2 대응」) · NotStarted 기다림 · 로그인 직전 재확인 · `TcpListener` 삭제(F3) · 정정 노트 10 | O8-19 · O8-23–23i | MF1–MF7 |
| **S-05**(LOW) tester.md가 블록 프로세스의 「환경」을 허용 | tester.md(+ KR) 「its variables only — never environment variables, which the port-forward `kubectl` and every `curl` it starts would inherit」(F4) · 정정 노트 6 | ST-O8(`$env:` 대입 0) · 공통 사후(모의 호출 시점 env 바늘 0) | RS-M9 |
| **S-06 · C-09**(LOW) Codex tester 범위 모순 | tester.md(+ KR) 「Only a Claude Code tester runs the O-8 block; a Codex tester never runs it and reports those scenarios SKIP …」 · infra.md(+ KR) 괄호 「Codex sessions, a Codex tester included」(F4) | — | — |
| **S-07 · C-02 · RO-02**(LOW · MEDIUM) 런북의 O-9 `-Clear`는 없는 스위치(조용히 무시) | 문서를 블록에 맞춤(정지점 단어 `issue` · `clear` · 끝 줄 넷 — F1 · F4) · **블록 셋에 남는 인자 판정**(F2) · 정정 노트 5 | W7-59–62 · O9-38–42(O9-41 = 기존 파일 + `-Clear` → 지우지 않는다) · O10-42–45 | MW17 · MW18 · MO16 · MO17 · MT16 · MT17 |
| **S-08**(NIT) 노출 바늘 문턱 8자 — 7자 조각은 잡히지 않는다 | **기록만** — 이 문서 §6에 범위를 적는다(54자 가운데 7자 · 위험 작음 — 결정 「기록만」) | — | RS-M4 생존(허용) |
| **S-09**(NIT) W-7이 root 토큰 전에 `cluster_name`을 보지 않는다 | W-7 — `vault status` 응답의 `cluster_name` = `vault-cluster-d3b29227`(Ordinal) · initialized · sealed · exit 판정 뒤 · root 토큰 정지점 앞 · 다르거나 없으면 멈춤(F2) · 정정 노트 16 | W7-66–68 | MW19 · MW20 |
| **S-10**(NIT · 확장) `curl.exe` · `kubectl.exe` 이름 가림 · `-NoProfile` 미확인 | 블록 여섯 첫 해석 판정(F2 · F3) · `-NoProfile` 판정은 하지 않음(첫 해석 판정은 외부 명령 이름의 함수 · 별칭 가림만 잡는다 — 프로필이 cmdlet 이름(Get-Command · ConvertFrom-Json 등)을 가리는 것은 실행 꼴 `pwsh -NoProfile`과 받아들인 위험 1(같은 사용자)에 기댄다) · 정정 노트 9 | W7-63–65 · O9-43–46 · O10-46–48 · O8-73b · O8-73c · C8-29 · C8-29b · L8-48 · L8-48b · harness-op 공통 사후(첫 해석 질의가 그 명령 첫 호출보다 앞) | MW21–MW24 · MO18 · MT18–MT21 · MS1–MS4 |
| **S-11**(NIT · 추론) AMSI 메서드 호출 기록 면 | **기록만** — 받아들인 위험 1 범위(같은 기계의 AV 공급자 · 이 PC pwsh 7.6.10 실험 기능 목록에 없음 · 미확인) · 정정 노트 20 · §8 | — | — |
| **C-03**(LOW) C-8 pod 판정이 설계 D5(경로의 nonce)와 다르다 | **블록 그대로**(설계 문면은 pod 로그에 쿼리가 없어 늘 빈 판정) — VD-T076-4가 어긋나면 c8 FAIL → tick 금지 · 사용자 결정: 정정 노트 12 · 런북 실패 갈래(F4) · §7 · §8 | C8-07 | B-M23 |
| **C-04**(LOW) AC6 「판정 8」 ↔ `o8=PASS 10/10` | **기록만** — 정정 노트 2(판정 a 2 + b–e 8 = 10 · 「판정 8」은 T075 O-5b 항목 수가 옮겨 온 글) | — | — |
| **C-05**(LOW) VD-T076-6 근거가 남지 않는다(STALE도 PASS) | O-8 요청별 INFO에 `code=` · `ct=` · `cfc=`(F3) · b–e 판정은 「≠ HIT」 그대로 — 캐시 응답은 C-8(Traefik 줄 정확히 1 · `request_id`)이 막는다(두 번 판정은 거짓 FAIL 위험만 더한다) · 정정 노트 11 | O8-14b · O8-17 | MN1 · MN2(정적만) |
| **C-06**(LOW) README 없음 | 이 문서(컨트롤러 · r1 뒤) | — | — |
| **C-07**(LOW) W-7 재실행 끝 줄 = `w7=SKIP live-same` | 런북(F4) · 정정 노트 16 | W7-02 · W7-29 | MW16 |
| **C-08 · RO-05**(LOW · MEDIUM) migrate Job TTL 7일 | 런북 §3 T076 기한 · ③-1 사전 확인 · 갈래(F4) · 정정 노트 15 · §8 | L8-19(prod Job 없음 → 셋 FAIL · `l8=FAIL 21/24`) | — |
| **C-10**(NIT) 설계 D6 리터럴 두 곳 ≠ gitops | **기록만** — 블록은 gitops cb3ba13대로 옳다(dev 원격 키 `dev/db/dev_identity_admin/owner` · Job CA 볼륨 `pg-main-ca`) · 정정 노트 14 | L8-01(24 / 24) · L8-16–18 | B-M33 |
| **C-11**(NIT) vt-14b · 단언 62 · FR-049 | **기록만** — 정정 노트 3 · 18(블록 밖) | — | — |
| **C-12**(NIT) 날짜 글자가 문화권 시간 구분자 · 달력을 따른다 | O-8 네 곳(`at` · jwt exp · nonce · start) · 하네스 고정 문자열 셋 → `InvariantCulture` + 따옴표 리터럴(F3) · 운영자 셋은 사용자 지정 꼴 0(O-9 끝 줄 = 표준 `'s'` — 다섯 문화권 불변 실측) → harness-op 정적 가드(F2) | O8-18 · C8-30(th-TH + 시간 구분자 「.」) · ST-O9 · ST-O10 · ST-W7 | MC12a · MC12b · MO25(정적만) |
| **C-13 · RO-12**(NIT) 붙여넣기 문구 · 「창 ②」 | O-9 · O-10 머리 실행 줄 = 「파일로만(런북 정본) — `pwsh -NoProfile -File '<이 파일의 절대 경로>'` · 인자 0」 · O-9 머리 「런북 §3 T076 ④-1(issue) · ④-3(clear) · 창 D」(F2) · O-10 머리 「창 D」(컨트롤러 보정 2) · 붙여넣기 사례는 안전성 증거로 남겼다 | W7-56 · O9-36 · O9-42 · O10-39 · O10-40 · O10-45 | — |
| **C-14 · RO-10 · RO-12**(NIT · LOW) 낡은 줄 번호 · 표식 · vault-unseal §0 · §13 · quickstart US4 | vault-unseal(F1) · bootstrap · quickstart · publish-pod 주석(F4) · pp-21 단언 이름(컨트롤러 보정 7) | — | — |
| **C-15 · RO-11 앞부분**(NIT · LOW) 사용자 문장(8시간) 재확인 | **처리 없음** — 결정 §0: 사용자가 표 질문에서 「vault 전용 1시간 (권장)」을 직접 골랐다 · 다시 여쭙지 않는다(UD-16 확정) · RO-11 뒷부분(1회용 결정 추적)은 런북 기록 칸 UD-16 행(F4) · build-notes 인계 | O9-08(8h → STOP) · O8-45(8h → 멈춤) | MO01 · MO02 · B-M11 · RS-M12 |
| **RO-03**(MEDIUM) W-7 끝 메시지가 흐름 중간에 터널 종료 · 창 닫기를 지시 | W-7 `finally` 마지막 줄을 결정 RO-03 글자 그대로(F2 — §5.2) · 런북 ①-5 · §4 3(F4) | 모든 W-7 사례(공통 사후 — 정확히 1회 · 옛 「창 종료 체크리스트」 0) · ST-W7 | MW25 |
| **RO-04**(MEDIUM) Git Bash 코드 페이지 949에서 한글 판정 줄이 깨진다 | tester 블록 머리 실행 줄 = `chcp.com 65001 >/dev/null; pwsh -NoProfile -File '<절대 경로>' <파라미터>; echo "exit=$?"`(F3) · 런북 · quickstart(F4) · 정정 노트 8 | F3 실물 실행(잘못된 입력 5회 — 한글 온전 · exit 1) | — |
| **RO-06 · RO-07 · RO-08 · RO-09**(LOW) 끝 줄 · 정지점 미기재 · 결정점 다섯 · Bash 시간 한도 · 1차 순서 | 런북 블록 표 정지점 열 · 끝 줄 전체 · 실패 표 · O-10 출력 관문 · 1차 FAIL 분류 · 같은 이미지 대조 · C-8 원인 · timeout 600000 · 세션 끝 `Get-Process kubectl` · 1차 순서(F4) · 정정 노트 8 · 12 · 19 · 이 문서 §5 | — | — |
| B2 우려(aud 직렬화 — 컨트롤러 결정) | O-9 · O-8은 `aud` = 문자열 `"vault"` 또는 원소 하나(문자열)인 배열 `["vault"]`를 받고 관찰한 꼴을 INFO로(F2 · F3) · VD-T076-10 · 정정 노트 4 · 13 · 런북 기록 칸 ④-1(컨트롤러 보정 5) | O9-05 · O9-05b–i · O8-42 · O8-42b–i | MO04 · MO19–MO24 · MA1–MA4 |
| B1 우려 2 · B4 우려 | vault-unseal §12 tester 읽기 줄 = O-8 실제 흐름(F1) · settings.json 변경 = deny 두 줄뿐(컨트롤러 diff 확인 · 사용자 알림) · gitops 문서의 eso-platform 요약 · web-bff 「ESO 밖」 관례는 **기록만**(D1 gitops 변경 0 — build-notes 후속) | — | — |

**컨트롤러 보정(r1 뒤 — 2026-11-20 · 이 문서를 쓸 때 반영을 다시 확인했다)**:

1. `.agents/skills/approval-review/boundaries/k8s-security.md` ← `.claude` 원본 바이트 복사(C-01 · RO-01) — `cmp` 동일 · `pwsh -NoProfile -File tests/agents/codex-parity.tests.ps1` → `12 passed, 0 failed`(재실행).
2. O-10 머리 주석 「(운영자 · 창 ①)」 → 「(운영자 · 런북 §3 T076 ①-2 · 창 D)」(F2 우려) — 블록 2행에 있음 · harness-op 174 / 174 · 5220 그대로(§4).
3. `docs/runbooks/vault-unseal.md` §12 로그인 토큰 줄의 「aud = 정확히 ["vault"]」 → 「`aud` = `vault` 하나 — 문자열 `"vault"` 또는 원소 하나인 배열 `["vault"]`, 관찰한 꼴은 INFO · VD-T076-10」(F1 우려) — 있음 · 「정확히 ["vault"]」 글자 0.
4. 런북 `bootstrap.md` · `quickstart.md` · 설계 정정 노트 8의 O-8 최악 515 s → 535 s(F3 우려 — Forwarding 줄 기다림 ≤ 15 s) — 세 파일에 535 s · 515 s 글자 0.
5. 런북 §3 T076 기록 칸 ④-1 행에 `INFO aud 꼴=` 줄(VD-T076-10)(F4 우려) — 있음.
6. 런북 §4 T076 실패 표: 남는 인자 행 · W-7 `cluster_name` 행을 끝 줄 꼴로 · 「보내기 전」 행과 `w7=STOP 미실행(…)` 행에 첫 해석 가림 — 있음(§5.7 대조).
7. `tests/scripts/publish-pod.tests.ps1` pp-21 단언 이름의 「validate.sh:232-233」 → 「tests/validate.sh BOT_AUTHORS / BOT_IDS」(F4 우려 · 66 passed 그대로 — 컨트롤러 실행 · 이 문서를 쓸 때는 돌리지 않았다) — 있음.

**r2 대응(확인 리뷰 rv2 — 2026-11-20 · 결정 정본 `.superpowers/t076/decisions-controller.md` 「## rv2 확인 리뷰 처리」 · 리뷰 `.superpowers/t076/reviews/R-{S,C,O}-rv2.md` · README 작성 보고 `.superpowers/t076/build/README-rv2-report.md`)**: 담당 G1 = 블록 · 하네스 · 이 문서 · 설계 정정 노트 / G2 = `docs/runbooks/bootstrap.md` · `specs/003-platform-foundation/quickstart.md` · `docs/runbooks/vault-unseal.md` / 컨트롤러 = build-notes. 아래 G2 칸은 결정 §2의 글자를 옮긴 것이다(G2 산출물과의 대조는 검증자 몫 · 줄 번호는 리뷰 시점) — **정본은 런북 최종 글자다**(r2 검증 V1-05: 몇 곳은 런북 글자와 Ordinal로 다르다 · 뜻은 같다 · G2가 결정 밖에서 더한 곳은 §5.7 끝).

| 지적(심각도 · 리뷰) | 처리 · 고친 곳(담당) | 하네스 사례 | 죽인 변이(§4) |
|---|---|---|---|
| **RO2-01**(MEDIUM · R-O) O-8이 Forwarding 줄을 15 s만 기다린다 — 같은 터널 경로의 `port-forward svc/vault` 수립 실측은 10–23 s | **S-04 결정 갱신**: Forwarding 줄 기다림 15 s · 30회 → **45 s · 90회**(첫 `$deadline = [DateTimeOffset]::UtcNow.AddSeconds(45)` · `for ($i = 0; $i -lt 90 …` · throw 「…을 45 s 안에 얻지 못했다(…)」 · 주석 ⑥ — 근거 T048 F19 · reboot-1 15.7 s · `tests/platform/reboot.tests.ps1` `$pfReadyWaitSec = 45`) · seal-status 기다림(15 s · 30회 · 「15 s 안에 응답하지 않았다」)은 그대로 · 최악 535 → 565 s(G1 — 블록 · §5.0 · §5.5 · §7 · §8 · 정정 노트 8 · 21) · G2가 런북 :1178 · :1205 · :1207 · quickstart :131의 535 s → 565 s(「Forwarding 줄 기다림 ≤ 45 s」) · vault-unseal §12의 「15 s 안에 안 나옴」 → 45 s · 런북 §3 ④-2 실패 갈래 한 줄(`STOP Vault port-forward 의 Forwarding 줄(…)을 45 s 안에 얻지 못했다(작업 Running · 출력 없음)` → 터널 경유 수립 지연(환경 — T048 F19) · JWT · 토큰 0 → 창 A 터널 확인 뒤 같은 1시간 안에서 다시 디스패치)을 고쳤다 | ST-O8(기다림 꼴 — 첫 for 90 · 둘째 for 30 · `AddSeconds(45)` 1 · `AddSeconds(15)` 1 · 각 deadline이 제 고리 앞 · 컨트롤러 보정 r2: 기다림 고리 단언 — 각 고리 바로 앞 문장 · 대기 `Start-Sleep -Milliseconds 500` 각 하나 · r2 검증 V1-01 · V1-02 · §3 35) · **O8-19b**(새 — Forwarding 줄이 출력 40회 늦게 → 기다림 40 · Receive-Job 42 · `o8=PASS 10/10`) · O8-23 · O8-23b · O8-23c(Receive-Job 90 · 기다림 90) · O8-22(seal 30회 그대로) | MR-a(런타임 O8-19b) · MR-b · MR-c · MR-k · MR-l · MR-n · V1 V-19 · V-20 · V-21(컨트롤러 보정 r2 — ST-O8) |
| **RO2-02**(LOW · R-O) W-7 창 정리 줄이 STOP에서도 「창 C 종료 — 뒤 단계는 18200 을 쓰지 않는다」 | **블록 고침**: `$winClose = $false`(`try` 앞 — 기본값 = 유지) · `finally`의 `w7=OK …` 두 갈래 · `w7=SKIP live-same` 갈래에서만 `$true` · 마지막 문장 = `if ($winClose) { <RO-03 닫기 줄> } else { <RO2-02 유지 줄> }`(G1 — §5.2) · G2가 런북 :1200(①-5) · :2194(§4 3)를 「`w7=OK …` · `w7=SKIP live-same`이면 끝 줄의 창 정리 안내(창 C만 닫는다)를 따른다 · `w7=STOP …`이면 창 C를 닫지 않는다(블록도 그 안내를 낸다 — 실패 표 조치에 18200이 필요하다)」로 · :1239 끝에 「창 C가 이미 닫혔으면 ①-1의 창 C 명령으로 다시 열어 `127.0.0.1` · `[::1]` 두 줄을 본 뒤 창 D에서 plan」 · 세션 끝 :1220의 창 C 전제를 「①-5에서 닫았거나 STOP 조치 중이었으면 지금 닫는다」로 고쳤다 | 공통 사후(모든 W-7 사례 — OK · SKIP 6 = 닫기 줄 1 · 유지 줄 0 / 그 밖 62 = 유지 줄 1 · 닫기 줄 0 · 둘 다 블록 출력의 마지막 줄 · 하네스 자체 전제 「OK · SKIP 사례 = 완주 사례」) · ST-W7(두 글자 · `Write-Host` 각 1곳) | MR-d · MR-e · MR-g · MR-h · MR-i · MR-m · MW25 |
| **RO2-03 · rv2C-01 · README 작성 우려 1–4**(NIT · LOW · R-O · R-C) 이 문서 §5.7이 짚은 런북 틈 | 런북(G2 — 결정 §2 ①–⑥): ① :1237 ④-1 「파일 쓰기 0」에 `o9=STOP 파일 쓰기 도중 중단(…)` 예외(파일이 바뀌었을 수 있다 → 인자 없이 다시 `issue` 또는 `clear`) ② 새 갈래 ④-3 `o9=STOP clear 도중 중단(…)` · `o9=STOP clear 실패(…)` → `Test-Path` → True면 clear 한 번 더 → 그래도 남으면 `Remove-Item -LiteralPath`(내용은 열지 않는다) → False 확인 · 기록 칸 ⑤ ③ :2201 출력 열 = 코드 5xx · 200(client_token 없음) · 4xx(auth 객체 있음) · 뜻 = 「거부(4xx · auth 없음)도 통과(client_token)도 아닌 응답 — VD-T076-1 미판정」 ④ :2200 조치 끝 = 클레임 사유가 `aud 에 vault 가 있다`면 다시 돌리지 않고 멈추고 보고(음성 대조 불성립 — 사람 판정) ⑤ :2208 출력 열에 `w7=STOP 쓰기 예정(…)`(정지점 seed 전에 끊김 · 쓰기 0 → 재실행) · :2214 출력 열에 `w7=STOP 기록됨 v1 — 되읽기 검증 전(…)` ⑥ :1183 O-10 행 「남는 인자 → STOP」 → `o10=FAIL 판정 불가(인자 <n>개 — …)` · §5.7 갱신(G1) | — | — |
| **RO2-04**(NIT · R-O · 추론) 1차 FAIL을 블록 단위로 가른다 | 런북 :1236(G2) — 1차 FAIL을 사유로 가른다: 환경 = 터널 · API 일시 오류(FAIL 사유가 `kubectl … 실패(exit=… · TLS handshake timeout · i/o timeout · Unable to connect …)`) · ③-1 뒤 gitops main 이동(⓪ revision만 다르고 나머지 PASS — 다시 fetch · rev-parse 뒤 L-8만) / 제품 · 구성 = 응답을 받았는데 값이 기대와 다르다 · ③-1에 「라이브 창 동안 gitops main 머지 0(머지가 끼면 ③-1을 다시)」 | — | — |
| **S2-01 · rv2C-02**(NIT · LOW · R-S · R-C) T077 · T085 인계가 S-01 문장과 어긋난다 | §8 「자격 범위」 · 정정 노트 23(G1 — 결정 글자) · build-notes 인계 한 줄(컨트롤러) | — | — |
| **S2-02**(NIT · R-S) S-10 「`-NoProfile` 판정 안 함」의 근거 글이 넓다 | §2a S-10 행 · §8 · 정정 노트 9의 괄호 = 결정 글자(G1) | — | — |
| **S2-03**(NIT · R-S) 노출 의심 갈래가 가장 파괴적인 수단(agent-view SA 재생성) 하나만 적는다 | 런북 :1242(G2) — Vault 쪽(role `e2e-reader` 일시 제거 또는 bound SA 변경 → 사본 JWT 로그인 차단 · 이미 나간 Vault 토큰은 운영자 revoke) / K8s 쪽(agent-view SA 재생성 — 모든 agent-view 토큰도 죽는다) · 추론 · 사용자 판정(사실은 `infra/vault/roles.tf`로 확인한 뒤 쓴다) | — | — |
| **S2-04**(NIT · R-S) O-8 남는 인자 런타임 사례가 인자 둘뿐 — 문턱 `-gt 1` 변이(rv2-S N08)를 정적만 잡았다 | harness-tester 사례 O8-84b(인자 1개 `extra` · 사유 글자 · 외부 호출 0)(G1) | O8-84b | MR-f(이제 ST-O8 + 런타임 O8-84b) |
| **rv2C-03**(NIT · R-C) O-10 결과 머리 줄이 「§3 T076 기록 칸」 | 블록 머리 줄 → 「런북 bootstrap.md §4 T076 기록 칸에 그대로 기록」 · §5.1(G1) · ST-O10에 그 글자 고정 단언 하나(G1 — §3 33) | ST-O10 | MR-j |
| **rv2C-04 · rv2C-05**(NIT · R-C) 런북 §3 머리 VD 범위 · ④-2 주체 | 런북 :1176 「(D1–D16 · VD-T076-1–9 + 정정 노트 13의 VD-T076-10 · 실행 순서 D14 · 끝 「정정 노트」)」 · :1207 「컨트롤러 → tester(Claude Code tester만 — Codex tester는 O-8을 SKIP으로 보고한다 · `.claude/agents/tester.md` 「Credentials」)」(G2) | — | — |
| README 작성 우려 5(O-10 로그인 Content-Type 미지정) | **기록만**(결정 §3 — 컨트롤러) — §7 · §8에 있다 | — | — |
| README 작성 우려 · 라이브 주의(O-10 PASS는 「4xx · auth 없음」만 본다) | 런북 §3 ①-2 판정 칸(G2 — 이미 있으면 그대로) · §8 「O-10 PASS의 뜻」 | — | — |

**r2 재확인(G1 — 모의 · 로컬 · 스크래치만 · 라이브 0)**: harness-op 174 / 174 · 단언 5289 · harness-tester 163 / 163 · 단언 4421(각 두 번 — §4) · 닫힌 T075 하네스 359 / 359 · 11359 · r2 변이 14 모두 잡힘 · r1 묶음을 r2 파일에 다시: F2 71 killed · F3 64 잡힘 + RS-M4 생존(허용)(§4 변이 표).

**r2 검증 → 컨트롤러 보정 r2(2026-11-21 — 결정 정본 `.superpowers/t076/decisions-controller.md` 「## r2 검증 처리」 · 검증 `.superpowers/t076/reviews/V{1,2}-r2.md`)**: V1(블록 · 하네스 렌즈) · V2(운영 문서 렌즈) 둘 다 approve — rv2 지적 14 모두 resolved · 새 지적 LOW 1 · NIT 8(V1-04 = V2-01 같은 건). 단언 하나와 글 몇 줄이라 수정 라운드 없이 컨트롤러가 고쳤다.

| 지적(심각도 · 검증) | 처리 · 고친 곳 | 죽인 변이(§4) |
|---|---|---|
| **V1-01**(LOW) O-8 기다림 고리의 대기 간격(0.5 s)을 하네스가 고정하지 않는다 · **V1-02**(NIT) 「각 deadline이 제 고리 바로 앞」이 상대 순서만 본다 | harness-tester ST-O8 기다림 고리 단언(§3 35 — 각 고리 바로 앞 문장 · 대기 `Start-Sleep -Milliseconds 500` 각 하나 · o8의 `Start-Sleep` 2곳뿐) · 기존 단언 이름 「앞(순서)」 · §4 · §7 | V1 V-19 · V-20 · V-21(ST-O8) |
| **V1-03**(NIT) 정정 노트 8의 r1 이력 구절이 565 s 뒤에 한정어 없이 이어진다 | 설계 정정 노트 8 — 괄호 한정어로 | — |
| **V1-04 = V2-01**(NIT) 런북 §4 실패 표 「끝 줄 위의 오류 줄이 원인이다」 — 던진 예외는 아래에 나온다 | 런북 §4 T076 실패 표 W-7 「그 밖」 행(원인 = 창 정리 줄 **아래**의 pwsh 오류 글자 · `쓰기 예정`은 오류 글자가 없을 수 있다) · §5.0 출력 순서 한 줄(블록 끝 줄의 「위 오류」 글자는 그대로 — T075 관례 · 기록만) | — |
| **V1-05**(NIT) §2a · §5.7 G2 칸의 「」 인용은 결정 글자다 | 위 머리 · §5.7 머리에 「정본은 런북 최종 글자」 · §5.7 끝에 G2 결정 밖 보강 목록 | — |
| **V2-02**(NIT) 세션 끝 창 C 문장이 ①-5 전에 멈춘 흐름을 빼고 열거한다 | 런북 세션 끝 — 「창 C(18200)가 아직 열려 있으면(…) 지금 닫는다 — 정상 흐름에서는 ①-5 W-7 뒤 창 정리 안내로 이미 닫혔다」 | — |
| **V2-03**(NIT) ④-3 직접 삭제에 `-Force`가 없다 · 그래도 남을 때의 행동이 없다 | 런북 ④-3 `Remove-Item -LiteralPath … -Force` · 「그래도 True면 멈추고 컨트롤러 · 사용자에게 보고」 · 세션 끝 `Test-Path` 주석 같은 꼴 | — |
| **V2-04**(NIT) 설계 정정 노트 19의 1차 FAIL 분류가 블록 단위로 남았다 | 설계 정정 노트 24(사유 단위 — RO2-04) | — |

**재확인(컨트롤러 — 모의 · 로컬 · 스크래치만 · 라이브 0)**: harness-tester 163 / 163 · 단언 4422(ST-O8 46 → 47 · 두 번) · harness-op 174 / 174 · 5289 · 닫힌 T075 하네스 359 / 359 · 11359(t075-blocks diff 0) · V1 변이 실행기 사본으로 21 / 21 잡힘 · 대조 3 / 3(§4 변이 표).

## 3. 설계와 다른 점 · 빌더 · 수정자가 정한 것(까닭)

**r0 빌더 B2(운영자 블록)**

1. **O-9 모드는 매개변수 `-Clear`가 아니라 가려진 정지점 단어 `issue` · `clear`다**(기본값 없음) — T075 운영자 블록 규약(최상위 `& { }` 한 문 · param 0 · 붙여넣기 안전). r1에서 문서를 블록에 맞췄고(S-07 · C-02 · RO-02) 남는 인자는 멈춘다.
2. **하네스는 자식 pwsh 대신 같은 프로세스에서 블록을 돌린다** · 시나리오마다 `LOCALAPPDATA`를 함정 디렉터리 아래 새 폴더로 바꾼다 — 자식 프로세스에서는 모의 함수가 보이지 않아 실물 kubectl과 관리자 kubeconfig 실물 `Test-Path`가 필요해진다(금지). DPAPI · 파일 I/O는 실물이고 복호는 O-8 꼴이다.
3. **O-10에 정지점 `probe`**(D3 — 사람이 관문) · 클레임 판정을 설계보다 넓혔다(aud 있음 · 문자열 또는 문자열 배열 · vault 없음(대소문자 무관) + sub · 수명 600 ± 10 · iat ± 120 — 하나라도 어긋나면 JWT 0).
4. **O-10 응답 판정은 fail-closed 상위 집합**: `auth.client_token`이 있으면 코드와 무관하게 통과(revoke + FAIL) · 4xx인데 auth 객체만 있으면 판정 불가 · 5xx · 000 · 해석 불가도 판정 불가.
5. **O-9 · O-10도 TLS · 프록시 환경 변수에서 멈춘다**(O-5 목록 − `TF_*` — kubectl(Go)이 `*_PROXY`를 따른다) · W-7은 O-5 목록 전체.
6. **O-9는 쓴 뒤 O-8 꼴로 되읽어 Ordinal 대조**하고 다르면 파일을 지운 뒤 멈춘다 · 쓰기 전 판정이 실패하면 기존 파일은 그대로 둔다.
7. **W-7 순서**: 가드 → tofu 추출 · 꼴 → `vault status`(여기서 `VAULT_ADDR`) → root 토큰 → 상태 판정 → (absent) `seed` → put → 되읽기 — tofu가 도는 동안 `VAULT_TOKEN` · `VAULT_ADDR` 0 · 파일로만(`$PSScriptRoot`로 `infra\cloudflare`를 찾는다 — 붙여 넣으면 첫 검사에서 멈춘다).
8. **실패 끝 줄 꼴**(`o9=STOP <사유>` · `o10=FAIL 판정 불가(<사유>)` · `w7=STOP <요약 행>`)은 지시에 없어 빌더가 정했다.

**r0 빌더 B3(tester 블록)**

9. **줄 1 = `param(…)` · 줄 2 = `& {`** — `pwsh -File`이 param에 묶으려면 스크립트 수준 param이 필요하다(T075 「첫 줄 = `& {`」를 tester 블록용으로 바꿨다).
10. **멈춤도 블록 안에서 잡는다**(try/catch(전부)/finally) — `STOP <사유>` 줄 다음 끝 줄 `<블록>=FAIL k/n` · exit 1(「끝 줄 = 판정」 계약 · T075 블록은 throw를 밖으로 냈다).
11. **세션 고정에 `$PSNativeCommandArgumentPassing = 'Standard'`** — O-8 capabilities-self 본문 JSON을 argv `--data`로 보낼 때 따옴표를 보존한다(실물 서버로 확인).
12. **port-forward = `Start-ThreadJob`**(같은 프로세스 스레드 작업 — kubectl은 pwsh 자식) — 정적 관문이 `Start-Process` · `[Diagnostics.Process]`를 막고 `Start-Job`(별도 pwsh)은 kubectl 손자를 고아로 남길 수 있다. `Stop-Job`이 자식을 끝내는 것은 로컬에서 ping.exe로 쟀다.
13. **X-Request-ID를 모든 Access 요청에 싣는다**(설계 D4 ⑩은 `/health`만) — pod 로그 `request` 필드에 쿼리가 없어(`format_request` = `<METHOD> <path>`) C-8은 `request_id`로 대조한다 · **C-8 pod 판정 = 404 넷의 pod 줄 0 + health 대조 키 줄 있음**(빈 PASS 방지 — VD-T076-4가 어긋나면 FAIL · C-03 · 정정 노트 11 · 12).
14. **C-8 Traefik 선택** = `RequestPath`가 `?t076=<Nonce>`로 끝나는 줄(설계 「든 줄」의 부분 집합 — O-8 요청은 늘 그 꼴) · 판정은 경로 정확 일치 · **`INFO o8 start` = 첫 요청 − 60 s**(노드 시계 여유 — C-8 `--since-time`).
15. **O-8 Transcription**: 설계의 레지스트리 키에 더해 설정 파일 두 곳의 낱말 `Transcription`(값 무관 — KB2-1과 같은 까닭) · **Vault 토큰 꼴 `\A[A-Za-z0-9._-]{20,256}\z`**(설계 밖 — 헤더 주입 방어) · seal-status 기다림 30회 × 0.5 s + 15 s 기한.
16. **C-8 · L-8에도 whoami 관문 · 프록시 · TLS 환경 변수 멈춤**(설계는 O-8만) · C-8 `-Since`는 꼴 + 날짜 + 범위(지금 + 5분 이전 · 24시간 안) · 모든 kubectl에 `--request-timeout`(port-forward 밖).
17. **L-8 리터럴은 gitops 원본**(cb3ba13): `-migrate` 원격 키 dev = `dev/db/dev_identity_admin/owner` · prod = `prod/db/identity_admin/owner` · Job 참조 = 자격 Secret `identity-admin-migrate`뿐 + 볼륨 Secret CA `pg-main-ca`뿐(설계 D6 문면과 다르다 — C-10 · 정정 노트 14) · **설계보다 엄격**: ② `-env` `data[]` 12줄 정확 대조 · ③ Deployment 둘의 참조 집합 정확 대조 · 프로브 web 셋 · relay `tcpSocket`(9464)만 · 그 밖 0 → env마다 12 → `l8=PASS 24/24` · admin 302는 env와 무관해 한 번만 INFO.

**r1 수정자 F2(운영자 블록 · harness-op)**

18. **O-9 aud 배열 갈래에 원소 형 판정**(`$audP.Value[0] -is [string]`) — r0 `& $eq $audP.Value[0] 'vault'`는 `[string]` 변환 때문에 겹 배열 `[["vault"]]`를 통과시켰다(r0 잠복 결함 — O9-05g · MO20). O-8도 같은 결함을 같은 판정으로 막았다(F3 — O8-42f · MA3).
19. **`INFO aud 꼴=` 출력 시점(O-9)** = aud 판정이 통과하면 — sub · 수명 · iat가 실패해 멈춰도 STOP 줄 앞에 나온다(VD-T076-10 첫 실행이 다른 이유로 멈춰도 직렬화 꼴이 남는다 — O9-07–12가 단언). O-8의 `INFO jwt aud 꼴=`는 JWT 판정이 전부 통과한 뒤에만 나온다(블록 글자 — VD-T076-10의 1차 근거는 O-9 기록).
20. **C-12는 표준 `'s'` 유지 + 정적 가드**: 운영자 셋에는 사용자 지정 날짜 꼴 `ToString`이 없다(grep) · O-9 끝 줄 시각은 표준 `'s'`이고 다섯 문화권(ko-KR · fi-FI · th-TH · ar-SA · fa-IR)에서 같은 값임을 실측했다 → 블록 글자는 그대로 두고 harness-op 공통 정적 가드(글자 꼴 `ToString` = `s` · `o` · `N` · `x2`이거나 `[Globalization.CultureInfo]::InvariantCulture`와 함께)를 더했다(MO25).
21. **남는 인자 사례는 같은 프로세스 `& <블록 경로> @ArgList`**(임시 사본 없음) — 실측: `$script:args` = 그 인자 = `pwsh -File` 꼴 · 모의 함수가 보인다 · W-7의 `$PSScriptRoot`가 실제 위치. `$null` 경로는 `-NullArgs` 붙여넣기 사례 셋(W7-62 · O9-42 · O10-45) · 하네스 자신의 남는 인자는 시작에서 거부한다(붙여넣기 사례의 블록이 하네스의 `$args`를 본다 — 실측).
22. **새 판정의 고유 끝 줄**(첫 해석 가림 · W-7 `cluster_name`)을 두었다 — 기록 칸에 사유가 남고 런북 §4 실패 표 행이 그 글자에 맞춰진다.
23. **W-7 창 정리 줄 · 첫 해석 순서는 공통 사후 조건**으로 넣었다(사례마다 Want 대신): 모든 W-7 사례에서 창 정리 줄 정확히 1회 · 옛 「창 종료 체크리스트」 0 / 모든 런타임 사례에서 `gc:<이름>` 질의가 그 명령의 첫 호출보다 앞.
24. **r0 변이 묶음을 재구성**했다 — B2 r0 변이 스크립트가 스크래치에 남지 않아 B2 r0 보고 §5 표 설명으로 46개를 다시 만들었다(같은 ID) · MO04(r0 「문자열 갈래 끔」)는 r1에서 문자열 `"vault"`가 정상 통과라 「aud 문자열 무조건 통과」로 옮겼다.

**r1 수정자 F3(tester 블록 · harness-tester)**

25. **Forwarding 기다림은 작업 상태 NotStarted를 「기다림」으로 다룬다** — 실측: `Start-ThreadJob` 직후 NotStarted(약 300 ms 뒤 Running). r0 seal 고리는 Running이 아니면 곧바로 멈추는 꼴이라 시작 직후 경합이 숨어 있었다(MF5가 막는다). 꼴이 틀린 Forwarding 줄 · 끝난 작업(Failed · Completed)은 기다림 상한(r1 15 s · r2부터 45 s — RO2-01)을 기다리지 않고 곧바로 멈춘다.
26. **로그인 직전 재확인 강화** — 결정 문구 「작업 Running 재확인」에 더해 Forwarding 줄이 여전히 정확히 한 줄 · 같은 포트인지 본다(O8-23i · MF4).
27. **C-12 표기** = `[System.Globalization.CultureInfo]::InvariantCulture`(결정 문서의 `[Globalization.CultureInfo]`와 같은 형 — C-8 `ParseExact`와 같은 표기) · 따옴표 리터럴 두 꼴 `yyyy-MM-dd'T'HH:mm:ss'Z'` · `yyyyMMdd'T'HHmmss'Z'`. C-05 「160자」는 값마다(`$clean`) 적용했다(실물 curl 출력으로 만든 줄 114자).
28. **하네스 모의의 문화권 버그를 고쳤다**: 헤더 파싱 · `Var-Name` · `Split-Native`의 문화권 의존 `String.IndexOf(string)` · `LastIndexOf` · `EndsWith(string)` → char · Ordinal — th-TH(ICU)에서 `"X-Vault-Token: …".IndexOf(":")` = 0(r0부터 잠복 · 블록은 영향 0 — `-like` · `-match` · `Contains` · `Split` · `Replace`를 th-TH에서 확인).
29. **결정 목록보다 넓힌 사례**: O8-14b · O8-17 · O8-18 · C8-30 · O8-19 · O8-23e · O8-23g · O8-23i · aud 경계 8(O8-42b–i) · 「O-9 -Clear」 글자 → 「O-9 의 정지점 단어 clear」(o8 머리 주석 · 하네스 JWT 파일 단언 이름) · 변이 묶음 조정(RS-M11 O-9 평문 JWT는 harness-op 몫이라 뺐다 · RS-M12는 O-8 부분만 · B3 M17(옛 aud 판정)은 MA1–MA4로 대체).

**r2 수정자 G1(블록 · 하네스 · 이 문서 · 설계 정정 노트)**

30. **W-7 창 정리 판정 변수 `$winClose`는 `try` 앞에서 `$false`(= 유지)로 시작하고 `finally`의 OK · SKIP 세 갈래만 `$true`로 바꾼다** — STOP 갈래(`else`)는 건드리지 않는다(`else`에서 다시 정하면 「기본값을 닫기로」 변이 MR-e가 관찰되지 않는다). 예외 · 정지점 중단 · 쓰기 도중 중단은 모두 STOP 요약 행으로 `else`에 닿으므로 기본값(유지)이 나온다.
31. **창 정리 줄의 기대는 블록 출력이 아니라 사례 선언에서 온다**: 하네스는 사례의 Want에 `w7=OK …` · `w7=SKIP live-same`이 있으면 닫기 줄, 그 밖이면 유지 줄을 기대한다(블록이 낸 끝 줄로 정하면 블록 결함을 따라간다) · 그 분류가 「완주 사례(Expect ok)」와 같은지를 사례마다 하네스 자체 전제로 단언한다(단언 +68) · 「마지막 줄」 = 블록이 낸 마지막 항목(하네스가 붙이는 `THROW:` 줄 앞 — 실물 `pwsh -File`에서는 그 뒤에 throw 오류 글자가 붙는다).
32. **O8-19b의 지연 = 출력 40회**(0.5 s × 40 = 20 s — T048 F19 범위 10–23 s 안 · 30회 상한이면 멈추는 값) · 기다림 40 · Receive-Job 42(고리 41 + 로그인 직전 1)와 Vault 순서를 단언한다.
33. **결정 밖으로 더한 정적 단언 둘**: ST-O10의 결과 머리 줄 글자(rv2C-03 — 결정은 「하네스 기대가 바뀌면 같이」 · 런타임은 머리 접두만 본다 — 고정 단언이 없으면 되돌림 변이 MR-j가 산다 · 단언 +1) · ST-O8 기다림 꼴의 순서 조건(각 `$deadline`이 제 고리 앞 — 상대 순서 · 「바로 앞」과 대기 간격은 35의 단언 · 두 deadline을 맞바꾸면 개수 조건은 그대로 통과하고 모의는 실시간 기한에 닿지 않아 런타임도 같다 — MR-n은 이 조건만 잡는다 · 같은 단언 안이라 수 그대로).
34. **O-8 주석 ⑥은 결정 글자 「≤ 45 s 안에 읽어(터널 경유 수립 10–23 s 실측 — T048 F19 · tests/platform/reboot.tests.ps1 $pfReadyWaitSec 45)」가 한 줄에 온전히 들도록 줄을 나눴다**(블록 400 → 401줄 · ⑥ 머리에 `RO2-01`).

**컨트롤러 보정 r2(r2 검증 V1 · V2 뒤 — 2026-11-21 · 결정 정본 `.superpowers/t076/decisions-controller.md` 「## r2 검증 처리」)**

35. **ST-O8 기다림 고리 단언(V1-01 · V1-02)**: 실효 기다림은 min(기한, 횟수 × 간격)이다. 33의 순서 조건은 상대 순서만 보고(V1 변이 V-20 — 45 s 기한 계산을 whoami 앞으로 옮겨도 통과), 모의 `Start-Sleep`은 지속 시간을 버려 런타임이 간격을 보지 못한다(V-19 · V-21 — 간격 500 → 100 ms면 실효 ≈ 9 s · ≈ 3 s). 그래서 try 본문 문장 목록(AST)에서 두 고리를 찾아 ① 각 고리 바로 앞 문장 = 제 `$deadline` 대입(`AddSeconds(45)` → 90회 고리 · `AddSeconds(15)` → 30회 고리) ② 고리 본문의 대기 = `Start-Sleep -Milliseconds 500` 정확히 하나 ③ o8 전체의 `Start-Sleep` = 그 둘뿐을 한 단언으로 본다(ST-O8 46 → 47). 모의가 지속 시간을 기록하게 바꾸는 길(V1-01 수정안 (a))은 쓰지 않았다 — 정적 단언 하나로 세 변이가 잡히고 런타임 사례의 기대를 건드리지 않는다. 33의 단언 이름도 「바로 앞」 → 「앞(순서)」으로 고쳤다.

## 4. 하네스(`harness-op.ps1` · `harness-tester.ps1`)

실행(Git Bash — `chcp.com 65001`이 없으면 한글 요약이 깨진다 · 판정은 끝 줄과 종료 코드):

- `chcp.com 65001 >/dev/null; pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-op.ps1'` [`-Only W7|O9|O10`] [`-Show 'W7-0*'`] [`-Dir <변이 사본 디렉터리>`]
- `chcp.com 65001 >/dev/null; pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\harness-tester.ps1'` [`-Only O8,C8,L8`] [`-Show 'O8-0*'`] [`-Dir <블록 변이 사본 디렉터리>`]
- 종료 코드 = 실패 시나리오(또는 관문 FAIL)가 있으면 1. harness-op은 자기 남는 인자를 시작에서 거부한다.

### 모의 · 가드

- **실물 차단(두 하네스 같다)**: `vault` · `kubectl` · `tofu`(+ `.exe`) 실물 디렉터리를 PATH에서 빼고 함정 `.cmd`를 맨 앞에(불리면 표식 파일 — 시나리오마다 0 단언) · `KUBECONFIG` = 없는 경로 · 블록이 멈추는 환경 변수(TLS · 프록시 · `TF_*`)를 하네스 동안 지우고 끝에 되돌린다(값 미출력) · `LOCALAPPDATA` = 함정 디렉터리 아래(시나리오마다 새 폴더 — 운영자의 실물 `%LOCALAPPDATA%\jt-e2e`를 건드리지 않는다) · `curl.exe`는 System32에 있어 PATH로 못 막는다 — 함수 가림 + 정적 관문(절대 경로 실행 파일 · `Start-Process` 0)이 막는다 · 시작 때 하네스 자체 전제(가짜 서비스 토큰 꼴 · SHA-256 표준 벡터 · 모의 JWT 클레임 — harness-op / 가짜 tester-m2m 꼴 · 바늘 배열 낱개 자체 확인 — harness-tester)가 어긋나면 하네스 결함으로 멈춘다.
- **harness-op 함수 가림**: `vault`(메모리 kv v2 + 결함 — version · status · token lookup · kv metadata get · kv get · kv put만, 그 밖 = 위반) · `kubectl`(create token 두 꼴 — `--audience vault --duration=1h` · `--duration=10m`만) · `tofu`(version · `"-chdir=<저장소>\infra\cloudflare" output -json service_tokens`만) · `curl.exe`(Vault HTTP API 셋 — seal-status GET · kubernetes/login POST 본문 stdin · revoke-self POST 헤더 stdin만 · 첫 인자 `-q` 아님 · 금지 플래그 · `-w` 다름 · 주소가 `http://127.0.0.1:18200/v1/…` 아님 · 본문 stdin과 헤더 stdin을 한 호출에 함께 = 위반) · `Read-Host` · `Set-Clipboard` · `Set-PSDebug` · `Get-ItemProperty` · `Test-Path`(관리자 kubeconfig · `~/.vault-token` · 설정 파일 · `infra\cloudflare\outputs.tf`는 실물을 건드리지 않고 답한다) · `Get-Content` · `Import-Module` · `Get-Module` · `Get-Command`(형식 필터 없는 질의 모의 — 기본 Application 꼴(`C:\jt-mock-bin\<이름>.exe`) · 사례가 Function · Alias · ExternalScript · missing으로 가린다 · 외부 이름에 `-CommandType` · `-All` = 위반). DPAPI는 실물(같은 Windows 사용자)이고 하네스가 O-8 꼴로 복호해 발급 모의 JWT와 대조한다.
- **harness-tester 함수 가림**: HTTP 모의는 **Ingress 표 모형**(F3-7 — 모델링하지 않은 경로를 404로 돌리면 거짓 PASS): m2m 호스트 = `/api` · `/session` · `/sessions` · `/tenants` Prefix(글자 접두 — VD-L9) · `/health` Exact · 그 밖 Traefik 404(`text/plain; charset=utf-8` · `404 page not found` + LF 19 B · DYNAMIC) · pod 규칙(헬스 셋 · 웹훅 = Access 면제 + HMAC 401 · CN 불일치 403 `problem+json` · 변이 꼴 pod 404 `problem+json`) · Access(무헤더 401 · 가짜 자격 401 · tester-m2m 통과) · admin 호스트 302(Location 쿼리의 meta 토큰 = 바늘). Vault HTTP 모의 = 127.0.0.1 리스너 모형(kubectl이 127.0.0.1에서 Running일 때만 그 포트가 답한다 · 끊긴 포트는 curl exit 7 · `[::1]`만 띄운 사례는 127.0.0.1의 같은 포트를 남이 쥐고 Vault로 중계하는 모형 — S-04). `kubectl.exe` 모의(`--kubeconfig` 리터럴 · whoami · port-forward(포트는 모의가 고른다 — 실행마다 다르다) · get 픽스처 · logs 픽스처 — 운영자 IP · UA · ClientHost가 든 Traefik 줄). `Start-ThreadJob` 모의(시작 직후 NotStarted · 출력이 한 번 늦게 보인다 · 연결마다 `Handling connection for <포트>` 줄) · `Receive-Job`(`-Keep` 필수) · `Stop-Job` · `Remove-Job` · `Start-Sleep`(기다리지 않는다). `Read-Host` · `Set-Clipboard` · `Start-Process` · `Start-Job` · `Invoke-WebRequest` · `Invoke-RestMethod` · `vault` · `tofu` 호출 = 위반. JWT 픽스처는 하네스가 `ConvertFrom-SecureString`으로 만든 DPAPI 파일로만 블록에 건넨다.

### 공통 사후 조건(모든 런타임 시나리오)

- **harness-op `Run-Case`**: 결과(완주 · 기대 throw) · Want · NotWant · 만든 파일 목록 = 기대와 정확히 같다(LOCALAPPDATA 아래 — W-7 · O-10 = 0 · O-9 = JWT 파일 하나 또는 0) · 노출 0(§6 — 화면 · 프롬프트 · argv · 클립보드 · `$Error` · 환경 변수 · 만든 파일 글자 · 새로 생기거나 바뀐 전역 변수 · 모의 호출 시점 env) · 모듈 로깅 실효 확인이 값이 오가는 첫 동작(vault · tofu output · curl GET/POST · kubectl create token · 보안 입력)보다 먼저 · 보안 입력 바로 다음 동작 = 클립보드 비움 · 화면 제어 문자 0(LF 밖) · `$Error`에 블록이 남긴 기록 0(throw 시나리오는 그 throw 1건만) · 외부 명령마다 첫 해석 질의(`gc:<이름>`)가 그 명령 첫 호출보다 앞 · W-7이면 창 정리 줄 = 사례가 기대하는 끝 줄로 가른 꼴(Want에 `w7=OK …` · `w7=SKIP live-same` → 닫기 줄(결정 RO-03 글자) · 그 밖 → 유지 줄(결정 RO2-02 글자)) 정확히 1 · 다른 꼴 0 · 블록 출력의 마지막 줄 · 옛 「창 종료 체크리스트」 0 + 하네스 자체 전제(OK · SKIP 사례 = 완주 사례) · (붙여넣기) 새 전역 · 스크립트 변수 0 · W-7은 `VAULT_TOKEN` · `VAULT_ADDR`가 끝에 없다(시작 전 값은 건드리지 않는다) · `INFO vault CLI` 줄이 첫 출력이고 root 토큰 입력보다 먼저 · W-7 밖은 vault CLI 0 · `VAULT_*` 0 · 위반 0 · 함정 표식 0 · 성공 스트림 0 · 클립보드에는 공백만 · 입력은 전부 가려진다 · 첫 동작 = `Set-PSDebug -Off` 1회 · 모듈 로깅 정책 확인이 첫 값 동작보다 먼저 · 완주면 입력 전부 소비.
- **harness-tester `Run-TCase`**: 블록이 예외를 밖으로 내지 않는다 · 끝 줄 정확히 · 종료 코드(0은 전부 PASS일 때만) · Want · NotWant · 노출 0(§6 — 화면 · argv · `$Error` · 환경 변수 · 모의 호출 시점 env · 새로 생기거나 바뀐 전역 변수 · 임시 LOCALAPPDATA 파일 — 블록이 만든 새 파일 0 · DPAPI 파일 = 평문 0) · tester 블록 파일 셋 변경 0 · JWT 파일을 지우지 않았다(UD-16) · 위반 0 · 함정 표식 0 · 성공 · 오류 스트림 0 · 첫 동작 = `Set-PSDebug -Off` 1회 · 모듈 로깅 정책 · 실효 확인이 값이 오가는 첫 동작(kubectl · curl · Vault · JWT 파일 · 작업)보다 먼저 · 화면 제어 문자 0 · `$Error` 0 · port-forward를 `finally`에서 끄고 지웠다 · Vault 토큰을 `finally`에서 revoke-self 정확히 1번 · **요청별 헤더 이름 집합 · 자격의 길**(S-02 — §6).

### 정적 관문(블록마다 — 관문 5(파서 · 명령 허용 목록 · 정적 .NET 형식 · `$Host` · 리다이렉트)가 FAIL이면 그 블록의 런타임 시나리오를 돌리지 않는다)

- **harness-op `Run-Static`**(ST-W7 37 · ST-O9 35 · ST-O10 37 단언): 파일 바이트 · 첫 줄 `& {` · 빈 줄 0 · 최상위 한 문 · param 0 · 첫 문장 · 세션 고정 3문장 · try/finally · finally 출력 규칙 · W-7 `VAULT_*` 제거가 finally 첫 두 문장 · `Read-Host` 수 · 소유 헬퍼 · 바로 앞 입력 버퍼 비움(AST) · 가림 · vault 호출 모양(`-field` 0) · curl 첫 인자 `-q` · 금지 플래그(대소문자 구분) · **글자 꼴 `ToString` 가드(C-12)** · 4키 가드 · `MOCK` · 비밀처럼 보이는 상수 · `hvs.` · `Start-Transcript` · `$env:KUBECONFIG` 참조 0 · 대입 제한(`$env:` = `VAULT_ADDR` · `VAULT_TOKEN`만 · `$script:` · `$global:` = `$global:LASTEXITCODE`만) · 실효 확인 문장 정확한 꼴. 블록별: **남는 인자 판정 꼴 · 위치 · 외부 이름 형식 필터 0**(셋) · W-7 tofu 호출 둘 · 순서 · 첫 해석 판정 위치 · `cluster_name` 판정 위치 · 창 정리 줄 두 꼴 글자(닫기 · 유지 — `Write-Host` 각 1곳) · put 1곳 · 경로 상수 · 정규식 · 쓸 값 · live 대조 · `seed` 앞 / O-9 `$kargs` · 파일 경로 · DPAPI · `[System.IO.File]` · 되읽기 · `[System.IO.Directory]` · 첫 해석 판정 위치 · aud 리터럴 · INFO · 정지점 단어 / O-10 `$kargs`(audience 0) · 첫 해석 판정 · `--audience` 0 · curl 네 꼴 · `-w` · 주소 · 경로 리터럴 · JWT · 토큰 즉시 지움 · 순서 · 환경 변수 판정 위치 · 결과 머리 줄의 기록 자리 = 「런북 bootstrap.md §4 T076 기록 칸」(r2 rv2C-03) · `probe` 위치.
- **harness-tester `Run-TStatic`**(ST-O8 47 · ST-C8 35 · ST-L8 36 단언): 파일 바이트 · 줄 1 = param 정확 · 줄 2 = `& {` · 빈 줄 0 · param 특성 0 · 세션 고정 7문장 · try/catch(전부)/finally · finally 출력 규칙 · 끝 줄 두 꼴 · exit 두 문장 · try 앞 대입만 · `Read-Host` 0 · 남는 인자 꼴 · `$PSScriptRoot` 판정이 먼저 · 모듈 로깅 문장 · 대입 제한(`$env:` 0) · `MOCK` 등 0 · kubeconfig 리터럴 1곳 · kubectl.exe 호출 = 정해진 꼴뿐 · curl.exe 호출 = 정해진 꼴뿐(첫 인자 `-q`) · 금지 플래그 0 · 리터럴 호스트 · URL · **첫 해석 판정이 첫 외부 호출보다 먼저(헬퍼 정의가 아니라 실제 호출 기준) · `-CommandType Application` 0** · **날짜 꼴 `ToString` = InvariantCulture + 따옴표 리터럴뿐(C-12)**. 블록별: O-8 port-forward 한 꼴 · Forwarding 판정 · 기다림 꼴(Forwarding 줄 90회 · 45 s · seal-status 30회 · 15 s · 각 deadline이 제 고리 바로 앞 문장(AST) · 고리 본문의 대기 = `Start-Sleep -Milliseconds 500` 각 하나 · o8의 `Start-Sleep` 2곳뿐 — r2 RO2-01 · 컨트롤러 보정 r2 V1-01 · V1-02) · 로그인 바로 앞 두 문장 = 재확인(AST) · `& $get` 네 꼴 · `& $vreq` 다섯 꼴 · `$note` 꼴 · JWT 파일 읽기 꼴 하나 · aud 두 갈래 · INFO aud · 로그인 본문 stdin · 권한 관문 다섯 경로 · kv 판정 · seal 순서 · `-w` 허용 목록 7 · 헤더 줄 stdin · 환경 변수 목록 · Transcription · 실행 파일 위치 · finally 순서 / C-8 투영 밖 필드 이름 0 · 투영 꼴 · 입력 판정 순서 · curl · Vault · JWT 0 / L-8 admin Location = `scheme://host/path`만 · `-w` · 기대 리터럴 · get 대상 여섯 · Vault · JWT · 자격 헤더 0.

### 결과(r2 — G1이 블록 · 하네스를 고친 뒤 직접 두 번씩 · 모의만 · 실물 호출 0 가드)

- **harness-op**: 시나리오 PASS **174 / 174** · 단언 PASS **5289 / 5289** · exit 0 · 두 번 같은 숫자 — 1회 19.0초(2026-11-20 14:51:44Z–14:52:03Z = 23:51:44–23:52:03 KST) · 2회 18.7초(15:10:40Z–15:10:59Z = 11-21 00:10:40–00:10:59 KST) — 정적 3(ST-W7 37 · ST-O9 35 · ST-O10 37) · W-7 68 · O-9 54 · O-10 49 · FAIL 줄 0.
- **harness-tester**: 시나리오 PASS **163 / 163** · 단언 PASS **4421 / 4421** · exit 0 · 두 번 같은 숫자 — 1회 33.6초(14:52:10Z–14:52:44Z = 23:52:10–23:52:44 KST) · 2회 30.7초(15:11:00Z–15:11:31Z = 11-21 00:11:00–00:11:31 KST) — 정적 3(ST-O8 46 · ST-C8 35 · ST-L8 36) · O-8 97 · C-8 28 · L-8 35 · FAIL 줄 0.
- 닫힌 T075 하네스(`../t075-blocks/harness.ps1`): 359 / 359 · 단언 11359 / 11359 · exit 0 · 46.9초(15:11:41Z–15:12:28Z) · `git diff --stat -- specs/003-platform-foundation/design/t075-blocks` 빈 출력.
- **컨트롤러 보정 r2 뒤(2026-11-21 — 바뀐 것은 harness-tester의 ST-O8 단언 하나 · 블록 글자 0)**: harness-tester 시나리오 PASS **163 / 163** · 단언 PASS **4422 / 4422** · exit 0 · 두 번 같은 숫자 — 1회 32초(2026-11-20 15:58:53Z–15:59:25Z = 11-21 00:58:53–00:59:25 KST) · 2회 31초(15:59:25Z–15:59:56Z) — 정적 ST-O8 **47** · ST-C8 35 · ST-L8 36 · FAIL 줄 0 · harness-op 174 / 174 · 5289 / 5289 · exit 0(19초 · 15:59:56Z–16:00:15Z) · 닫힌 T075 하네스 359 / 359 · 11359 / 11359 · exit 0(47초 · 16:03:41Z–16:04:28Z) · t075-blocks diff · status 빈 출력.
- 실행 뒤 TEMP 아래 `t075-*` · `t076-*` 하네스 디렉터리 남은 것 0 · 변이 사본은 세션 스크래치에만(저장소 밖).
- r1 → r2: harness-op 174 / 5220 → 174 / 5289(+69 단언 — W-7 사례 68개마다 창 정리 줄 분류의 하네스 자체 전제 1 · ST-O10 결과 머리 줄 1 · 사례 수 그대로) · harness-tester 161 / 4364 → 163 / 4421(+2 사례 O8-19b · O8-84b = +57 단언). r1 값은 이 문서를 처음 쓸 때(2026-11-20 13:39:53Z–13:40:51Z = 22:39:53–22:40:51 KST · 한 번씩) 잰 것이다 — harness-op 18.4초 · harness-tester 32.3초 · 그때 두 실행 전후 `git status --short --ignored` 같음.
- r0 → r1: harness-op 140 / 3963 → 174 / 5220(+34: W7-59–68 · O9-05b–i · O9-38–46 · O10-42–48) · harness-tester 134 / 3476 → 161 / 4364(+27: O-8 22 · C8-29 · C8-29b · C8-30 · L8-48 · L8-48b). 수정자 실행: F2 두 번(20.4초 · 18.7초) · F3 두 번(31.1초 · 30.3초) — 같은 숫자. 닫힌 T075 하네스 359 / 359 · 11359 / 11359(F2 최종 상태에서 재실행).
- **로컬 실물 확인(라이브 아님)**: F3 `realcurl\check.ps1` 25 / 25 × 2(Git mingw curl 8.4.0 · System32 curl 8.23.0 — 블록에서 AST로 뗀 `$get` · `$vreq` · `$desc` · `$note` · L-8 `$get` · O-8 `$pfRead` · Forwarding 기다림 고리를 127.0.0.1 로컬 서버 · 실물 `Start-ThreadJob` + python 자식으로 — 정상 0.62 s · `[::1]`만 0.51 s 멈춤 · 두 줄 멈춤 · 종료 코드 1 = Completed 0.52 s 멈춤 · 줄 없음 15.19 s 멈춤 · `Stop-Job` 뒤 자식 1 → 0) · 잘못된 입력 5회(STOP 줄 + `=FAIL 0/n` · exit 1 · 한글 온전) · PATH에서 curl · kubectl을 뺀 3회(같은 입력 STOP — 입력 판정이 해석 · 외부 호출보다 먼저). B3 r0 실물 curl 17 / 17 × 2.

### 변이 시험(스크래치 사본에 결함 하나씩 — 하네스가 실제로 잡는지)

| 묶음(세션 스크래치 — 저장소 밖) | 대상 | 변이 | 결과 |
|---|---|---|---|
| r0 빌더 B2(r1에서 재구성 — F2 묶음에 포함) | harness-op | MW01–16 · MO01–15 · MT01–15(46) | r0 46 / 46(첫 실행 MT13 생존 → 사례 O10-21b를 더해 잡음) · r1 재실행 46 / 46 |
| r0 빌더 B3(`t076c\mutate.ps1`) | harness-tester | M01–M18 · M21–M26 · M31–M36 · H01 · H02(32) | r0 32 / 32 · r1 재실행 31 / 31(M17은 aud 결정이 바뀌어 MA1–MA4로 대체) |
| r0 리뷰 R-S(`t076\rv-S\mk-mutants.ps1`) | 둘 | M1–M12 | r0: **M4 · M5 생존**(→ S-08 · S-02) · 나머지 잡힘 · r1 재실행(M11은 harness-op 몫이라 뺐다 · M12는 O-8 부분): M5 잡힘 · M4 생존(허용) |
| r0 리뷰 R-C(`t076\rv-C\tools\` · 모의 사본) | harness-tester · tofu.tests | 블록 변이 16 · 모의 변이 RV-01–10 · Vault 정책 변이 11 | 블록 16 잡힘 · 모의: cf-cache STALE만 `o8=PASS 10/10`(→ C-05 — tick은 C-8이 막는다) · 정책 11 잡힘 |
| r0 빌더 B1(`vt-mutation.ps1`) | tofu.tests vt-14 · vt-14b · vt-16 | 13 | 13 matched · 0 mismatched |
| **r1 F2**(`t076\r1-F2\run-mutants.ps1` → `mut-final.txt`) | harness-op | 71 = r0 재구성 46 + r1 새 25 | **killed 71 · survived 0 · apply-error 0** |
| **r1 F3**(`t076\r1-F3\mutate-r1.ps1` → `mutate-r1-final.txt`) | harness-tester | 65 = R-S 11 + B3 31 + r1 새 23 | **잡힘 64 · 생존 1(RS-M4 — 허용 · S-08) · 적용 오류 0 · 판정 불가 0** |
| **r2 G1**(`t076\r2-G1\run-r2-mut.ps1` → `r2-mut-final.txt`) | 둘 | 14 = 과제 (a)–(f) 6 + 경계 8 | **잡힘 14(변이마다 기대한 사례가 모두 FAIL) · 생존 0 · 적용 오류 0 · 판정 불가 0** |
| **r1 F2 묶음 재실행**(`t076\r2-G1\f2-rerun\run-mutants.ps1` → `mut-rerun.txt` — r2 블록 · 하네스) | harness-op | 71 | **killed 71 · survived 0 · apply-error 0** — 잡은 사례 수가 r1과 다른 것은 MW25 하나(69 → 7: STOP 사례는 이제 유지 줄을 내므로 닫기 줄을 옛 문구로 바꿔도 보이지 않는다 · ST-W7 + OK · SKIP 6이 잡는다) |
| **r1 F3 묶음 재실행**(`t076\r2-G1\f3-rerun\mutate-r1.ps1` → `mutate-r1-rerun.txt` — r2 블록 · 하네스) | harness-tester | 65 | **잡힘 64 · 생존 1(RS-M4 — 허용 · S-08) · 적용 오류 0 · 판정 불가 0** — 변이마다 잡은 사례는 r1과 같거나 1–2개 늘었다(새 O8-19b · O8-84b가 전 흐름 · 전 사례를 깨는 변이를 함께 잡는다) · 줄어든 변이 0 |
| **r2 검증 V1**(`t076\r2-V1\run-v1-mut.ps1` → `v1-mut-summary.txt` · `v1-mut-summary-extra.txt` — 검증자가 직접 만든 독립 변이) | 둘 | 18 + 추가 경계 3(V-19 · V-20 · V-21) · 대조 3 | 18 잡힘 · **추가 3 생존**(대기 간격 500 → 100 ms 둘 · 45 s 기한 계산을 whoami 앞으로) → V1-01 · V1-02 |
| **컨트롤러 보정 r2**(V1 실행기 사본 `t076\r2-C\run-v1-mut.ps1` → `v1-full-run.txt` — ST-O8 기다림 고리 단언 뒤) | 둘 | 21 · 대조 3 | **잡힘 21 · 생존 0 · 대조 통과 3 / 3 · 적용 오류 0**(V-19 · V-20 · V-21 = ST-O8) |

r1 결과 파일 두 개의 끝 줄은 이 문서를 쓸 때 다시 읽어 확인했다(`mutations: 71 · killed 71 · survived 0 · apply-error 0` · `변이 65 · 잡힘 64 · 생존 1(허용 1 · 허용 밖 0) · 적용 오류 0 · 판정 불가 0`). r2 결과 파일의 끝 줄: `r2 변이 14 · 잡힘(기대 사례 포함) 14 · 잡힘(기대 사례 빠짐) 0 · 생존 0 · 적용 오류 0 · 판정 불가 0`(2026-11-20 15:13:57Z–15:15:18Z) · 재실행 `mutations: 71 · killed 71 · survived 0 · apply-error 0` · `변이 65 · 잡힘 64 · 생존 1(허용 1 · 허용 밖 0) · 적용 오류 0 · 판정 불가 0`. 스크래치 경로의 뿌리는 `C:\Users\2401\AppData\Local\Temp\claude\8d04d95f15c3c8f9\e2749fad-6c31-4255-9e8b-25dbb3fad05e\scratchpad\`다(세션 임시 — 보존하려면 `.superpowers/t076/`로 옮긴다).

**r2 새 변이(14 — 사본에 넣고 저장소 하네스를 `-Dir <사본> -Only <블록>`으로)**

| ID | 변이 | 잡은 사례 |
|---|---|---|
| MR-a | (a) O-8 Forwarding 기다림을 r1 꼴 30회 · 15 s로 되돌림(throw 글자는 45 s 그대로) | ST-O8 · **O8-19b(런타임)** · O8-23c |
| MR-b | (b) Forwarding 상한 90 → 200 | ST-O8 · O8-23c |
| MR-c | (c) throw 글자를 15 s로(숫자는 45 · 90 그대로) | O8-23 · O8-23b · O8-23c |
| MR-d | (d) W-7 창 정리 줄을 무조건 닫기 줄로(`if ($winClose)` → `if ($true)` — 유지 줄 글자는 죽은 갈래로 남아 ST-W7은 통과) | W-7 STOP 사례 62 전부(런타임) |
| MR-e | (e) 판정 변수 기본값을 닫기로(`$winClose = $true`) | W-7 STOP 사례 62 전부 — 예외(W7-37 · W7-56 · W7-62 등) · 정지점 중단(W7-30) · 쓰기 도중 중단(W7-28) 포함 |
| MR-f | (f) O-8 남는 인자 문턱 `-gt 0` → `-gt 1` | ST-O8 · **O8-84b(런타임)** |
| MR-g | STOP 갈래(`else`)도 닫기로 | W-7 STOP 사례 62 전부 |
| MR-h | SKIP 갈래가 닫기로 바꾸지 않는다 | W7-02 · W7-29 |
| MR-i | 응답 유실 OK 갈래가 닫기로 바꾸지 않는다 | W7-21 |
| MR-m | 창 정리 줄이 마지막 줄이 아니다(`~/.vault-token` 경고를 그 뒤로 옮김) | W7-37(그 경고가 실제로 나오는 사례 — 「마지막 줄」 조건) |
| MR-j | O-10 결과 머리 줄의 기록 자리를 §3으로 되돌림(rv2C-03) | **ST-O10만** |
| MR-k | seal-status 기다림도 90회로(잘못 옮김 — seal은 30회 · 15 s) | ST-O8 · O8-22 |
| MR-l | Forwarding 상한 89(하나 모자람) | ST-O8 · O8-23c |
| MR-n | 두 deadline 맞바꿈(Forwarding 15 s · seal 45 s — 개수 1 · 1 그대로) | **ST-O8만**(순서 조건) |

**r1 새 변이(48)**

| ID | 변이 | 잡은 사례 |
|---|---|---|
| MW17 | W-7 남는 인자 판정 삭제(S-07) | ST-W7 · W7-59–61 |
| MW18 | W-7 인자 수 = `@($script:args).Count`(`$null`을 1로 센다) | ST-W7 · W7-62 |
| MW19 | W-7 `cluster_name` 판정 삭제(S-09) | ST-W7 · W7-66–68 |
| MW20 | W-7 `cluster_name` 다름에서 멈추지 않는다(throw 삭제 — 토큰을 묻는다) | W7-66–68 |
| MW21 · MW22 | W-7 tofu · vault Application 판정 삭제(S-10) | ST-W7 · W7-63 · W7-65 / ST-W7 · W7-64 · W7-65 |
| MW23 | W-7 가림 STOP 무시 | ST-W7 · W7-63–65 |
| MW24 | W-7 tofu 질의에 형식 필터(`-CommandType Application`) | ST-W7 외 43(44 사례) |
| MW25 | W-7 창 정리 줄을 옛 문구로(RO-03) | ST-W7 외 68(69 사례) |
| MO16 · MO17 | O-9 남는 인자 판정 삭제 · 인자 수 `@($script:args).Count` | ST-O9 · O9-38–41 / ST-O9 · O9-42 |
| MO18 | O-9 kubectl Application 판정 삭제 | ST-O9 · O9-43–45 |
| MO19 | O-9 aud 문자열 갈래 삭제(r0 동작 — 문자열 `"vault"`를 STOP) | ST-O9 · O9-05 |
| MO20 | O-9 aud 배열 원소 형 판정 삭제(겹 배열 함정) | ST-O9 · O9-05g |
| MO21 | O-9 aud 배열 원소 수 판정 삭제 | ST-O9 · O9-04 · O9-05c |
| MO22 | O-9 aud 문자열 비교 대소문자 무관 | ST-O9 · O9-05b |
| MO23 · MO24 | O-9 `INFO aud 꼴` 줄 삭제 · 배열 꼴을 문자열로 기록 | ST-O9 · O9-01 · O9-07–10 외(9 · 8 사례) |
| MO25 | O-9 끝 줄 시각을 사용자 지정 꼴로(C-12) | **ST-O9만** |
| MT16 · MT17 | O-10 남는 인자 판정 삭제 · 인자 수 `@($script:args).Count` | ST-O10 · O10-42–44 / ST-O10 · O10-45 |
| MT18 · MT19 | O-10 kubectl · curl.exe Application 판정 삭제 | ST-O10 · O10-46 · O10-48 / ST-O10 · O10-47 · O10-48 |
| MT20 | O-10 가림 STOP 무시 | ST-O10 · O10-46–48 |
| MT21 | O-10 curl.exe 질의에 형식 필터 | ST-O10 외 35(36 사례) |
| MF1 | Forwarding 줄 「정확히 한 줄」 판정 제거(첫 줄만 본다) | ST-O8 · O8-23e · O8-23i |
| MF2 | Forwarding 줄 꼴 느슨하게(주소 · 원격 포트 아무거나) | ST-O8 · O8-23d · O8-23f |
| MF3 | 꼴 아님에서 곧바로 멈추지 않고 15 s를 다 기다림 | ST-O8 · O8-23d–g |
| MF4 | 로그인 직전 재확인(Running · 같은 한 줄) 제거 | ST-O8 · O8-23h · O8-23i |
| MF5 | 기다림에서 NotStarted를 실패로(r0 꼴) | ST-O8 외(48 사례) |
| MF6 | port-forward `--address 127.0.0.1` 제거(localhost — `::1` 대체) | ST-O8 외(50 사례) |
| MF7 | 끝난 작업(Failed · Completed)을 무시하고 15 s를 기다림 | ST-O8 · O8-23 · O8-23b · O8-23c |
| MS1 · MS2 · MS3 | O-8 · C-8 · L-8 첫 해석 Application 판정 끔 | ST-O8 · O8-73b · O8-73c / ST-C8 · C8-29 · C8-29b / ST-L8 · L8-48 · L8-48b |
| MS4 | O-8 Get-Command에 `-CommandType Application` 다시(형식 필터 — 가림을 못 본다) | ST-O8 외(74 사례) |
| MA1 | aud 문자열이면 값 없이 무조건 통과 | ST-O8 · O8-42c · O8-42i |
| MA2 | aud 배열 원소 하나 판정 제거 | ST-O8 · O8-42b · O8-42g |
| MA3 | aud 배열 원소 형(문자열) 판정 제거 | ST-O8 · O8-42f |
| MA4 | aud 문자열 갈래 제거(r0 꼴) | ST-O8 · O8-42 |
| MC12a · MC12b | start · nonce를 문화권 꼴 `ToString`으로(r0 꼴) | ST-O8 · O8-18 |
| MN1 | 요청별 INFO에서 ct · cfc 뺌(C-05) | ST-O8 외(17 사례) |
| MN2 | 요청별 INFO의 ct 정제(`$clean`) 뺌 | **ST-O8만** |
| MH1 | 404 탐침에 비밀 아닌 여분 헤더(Accept) — 헤더 이름 집합만 잡을 꼴 | ST-O8 외(23 사례) |
| MH2 | kv 요청에 여분 헤더 | ST-O8 외(31 사례) |
| MH3 | Access URL 쿼리에 Vault 토큰 9자 조각 | O8-01 외(22 사례 — 자격의 길) |
| MH4 | `/health` X-Request-ID 값에 client_id 12자 조각 | ST-O8 외(23 사례) |

**r0 변이(r1 재실행 — 잡은 사례)**: harness-op — MW01 `\z`→`$` → ST-W7 · W7-15 · MW02 `-notmatch` → ST · W7-17 · MW03 `{54,64}` → ST · W7-13 · MW04 live 대조 끔 → W7-03 · 04 · MW05 `seed` 정지점 삭제 → ST 외 5 · MW06 `-cas` 뺌 → ST 외 4 · MW07 client_secret 화면 출력 → 32 사례 · MW08 쓸 키 여분 → ST 외 8 · MW09 dead 무시 → W7-07–09 · MW10 쓰기 비 0 재판정 끔 → W7-21–23 · MW11 finally `VAULT_TOKEN` 정리 끔 → ST 외 26 · MW12 `TF_*` 판정 삭제 → ST · W7-42–45 · MW13 `HTTPS_PROXY` 삭제 → ST · W7-46 · 47 · MW14 client_id `-notmatch` → ST · W7-18 · MW15 live client_secret 대조 삭제 → ST · W7-03 · 04 · MW16 SKIP 끝 줄 문구 → W7-02 · 29 / MO01 `--duration=8h` → 25 사례 · MO02 수명 28800 → 11 · MO03 aud 판정 끔 → 11 · MO04 aud 문자열 무조건 통과 → ST · O9-05b · 05i · MO05 sub 끔 → ST · O9-07 · 14 · MO06 iat 끔 → ST · O9-11 · MO07 판정 무시 쓰기 → 18 · MO08 `-Key` → 9 · MO09 평문 JWT 쓰기 → 9 · **MO10 되읽기 대조 끔 → ST-O9만** · MO11 JWT 화면 출력 → 25 · MO12 clear 삭제 뺌 → O9-21 · 23 · MO13 파일 경로 → 11 · MO14 `HTTPS_PROXY` → O9-30 · MO15 모드 대소문자 → O9-24 / MT01 `--audience vault` → 23 · MT02 `cluster_name` 끔 → ST · O10-07 · MT03 revoke 끔 → 6 · MT04 2xx를 PASS → O10-20 · MT05 로그인 본문 argv → 19 · MT06 `-q` 뺌 → 23 · MT07 `-v` → 23 · MT08 토큰 화면 출력 → 5 · MT09 aud 판정 끔 → O10-11 · 12 · MT10 seal 판정 끔 → 5 · MT11 revoke를 GET으로 → 6 · **MT12 본문 만든 뒤 JWT 지움 뺌 → ST-O10만** · MT13 PASS 조건에서 auth 없음 뺌 → O10-21b · MT14 수명 판정 끔 → O10-15 · MT15 `HTTPS_PROXY` → ST · O10-27 · 28. harness-tester — RS-M1 `%header{set-cookie}` → ST 외 22 · RS-M2 `$capBad` 제거 → O8-24–27 · RS-M3 토큰 9자 출력 → 34 · **RS-M4 client_secret 앞 7자 출력 → 생존(96 / 96 PASS — 허용)** · RS-M5 User-Agent에 secret 20자 → ST 외 22 · RS-M6 `cluster_name` 제거 → ST · O8-20 · RS-M7 C-8 투영에 운영자 IP → 13 · RS-M8 revoke 끔 → 36 · RS-M9 client_secret을 환경 변수에 → 96 전부 · RS-M10 C-8 원시 줄 INFO → 13 · RS-M12 수명 상한 28810 → ST · O8-45 / B-M01–B-M04(404 · `/health` cf-cache · size 19 · git_sha) → O8-05 · O8-06 · O8-09 · O8-10 · B-M05 권한 관문 → O8-24–27 · B-M06 secret `-notmatch` → ST · O8-33 · B-M07 Transcription → O8-68–70 · B-M08 실행 파일 위치 → ST · O8-71 · 72 · B-M09 revoke 제거 → ST 외 36 · B-M10 Stop-Job 제거 → ST 외 49 · B-M11 수명 상한 8h → ST · O8-45 · B-M12 `cluster_name` → ST · O8-20 · B-M13 로그인 OK 줄에 토큰 → 34 · B-M14 자격 헤더 argv → ST 외 22 · B-M15 JWT 파일 삭제 → 96 전부 · B-M16 `VAULT_*` 판정 → ST · O8-60 · 61 · B-M18 nonce 쿼리 뺌 → 15 · B-M21 OriginStatus → C8-02 · 03 · B-M22 RouterName → C8-02 · 02b · B-M23 대조 키 → C8-07 · B-M24 원시 줄 → 13 · B-M25 복제 = 1 → C8-10 · 11 · B-M26 줄 수 ≥ 1 → C8-04 · B-M31 ⑤ 401 → L8-21 · B-M32 Location 쿼리째 → L8-01 · 30 · 31 · B-M33 `-migrate` 분리 → L8-16 · B-M34 Location 판정 → L8-22 · B-M35 revision → L8-02 · B-M36 liveness → L8-13 · B-H01 모의 Ingress `/health` Prefix → 16 사례 · B-H02 모의 O-5 식(라우팅 표 없음) → O8-01 · O8-17.

**정적 관문으로만 잡히는 변이(여섯 — 런타임 관찰로는 차이가 없는 성질 · r1 넷 + r2 둘)**:
- **MO10**(O-9 되읽기 대조 끔): 하네스의 DPAPI 쓰기 · 읽기는 실물이라 되읽기가 늘 같다 — 불일치를 만드는 모의 사례가 없어 대조를 꺼도 관찰 결과가 같다(r0에서도 같았다).
- **MT12**(O-10 로그인 본문을 만든 뒤 `$jwt = $null` 뺌): JWT 변수는 블록 지역 범위에 남았다가 `finally`의 `Remove-Variable`로 지워진다 — 끝 시점의 면(화면 · 전역 · env · 파일)에는 차이가 없고 메모리에 남는 창만 길어진다(r0에서도 같았다).
- **MO25**(O-9 끝 줄 시각을 사용자 지정 꼴로): harness-op은 다른 문화권에서 블록을 돌리지 않는다(이 PC 문화권에서는 같은 글자) — 정적 가드(C-12)가 막는다.
- **MN2**(O-8 요청별 INFO의 ct 정제 뺌): `finally`가 INFO 줄 전체를 다시 `\p{Cc}` → `?`로 바꿔 화면은 안전하다(이중 정제) — 빠지는 것은 값마다의 160자 자름뿐이다.
- **MR-j**(r2 — O-10 결과 머리 줄을 「§3 T076 기록 칸」으로): 런타임 사례는 머리 접두(`--- T076 O-10 음성 대조 결과`)만 본다 — 글자는 기록 안내일 뿐 판정 · 동작이 같다(ST-O10 고정 단언 — §3 33).
- **MR-n**(r2 — 두 deadline 맞바꿈): 모의 `Start-Sleep`은 기다리지 않아 고리가 실시간 기한에 닿기 전에 횟수 상한(90 · 30)으로 끝난다 — 기한 값은 라이브에서만 효과가 있다(ST-O8 순서 조건 — §3 33 · §7).

**합계**: 생존은 RS-M4 하나(허용 — §6 범위 밖)뿐이다(r2 — 새 변이 14 · r1 묶음 재실행 136에서도 같다). r0의 생존(R-S M4 · M5 · B2 첫 실행 MT13 · R-C 모의 STALE)은 M4 밖 모두 r1에서 사례 · 판정이 더해져 죽었다(STALE은 판정을 바꾸지 않고 C-05 INFO + C-8로 처리 — O8-17이 「STALE → PASS」를 고정).

### 하네스 결함 · 고친 것(실행 기록)

- (r0 B2) 첫 변이 실행에서 MT13(PASS 조건에서 「auth 없음」 뺌)이 살아남았다 — 「403인데 auth 객체」 사례가 없었다 → O10-21b.
- (r0 B3) Git Bash 코드 페이지 949에서 `-File` 실행 출력이 깨졌다 — r0는 `iconv -f CP949` 우회를 권했고 r1에서 `chcp.com 65001` 실행 꼴로 정리했다(RO-04).
- (r1 F2) 붙여넣기 사례의 블록은 하네스 스크립트 범위의 `$args`를 `$script:args`로 본다(실측 pwsh 7.6.10) — 하네스 자신의 남는 인자를 시작에서 거부하고, `$null` 꼴은 `-NullArgs` 사례로 연다.
- (r1 F3) 하네스 모의의 문화권 의존 문자열 연산(§3 28) — th-TH에서 헤더를 잘못 읽었다(r0부터 잠복 · 블록 영향 0).
- (r1 F3) 중간 빌드에서 바늘 함수가 `, @(집합)`으로 돌려준 값을 호출 쪽이 `@()`로 감싸 바늘 전체가 한 문자열로 합쳐졌다 — 노출 · 자격의 길 검사가 한동안 비어 있었고 RS-M5 변이가 드러냈다 → 바늘을 낱개로 흘리고 자체 확인(10자 값 → 바늘 9개 · `cdefghij` 포함)을 시작에 두었다. 최종 결과는 고친 뒤 다시 돌린 것이다.
- (r1 F3) 모의 스레드 작업에 실측 상태를 넣었다 — 시작 직후 NotStarted · 출력 지연 · `Handling connection` 줄 · `Receive-Job -Keep` 필수 · 출력이 보인 뒤에는 NotStarted 아님 · 종료 코드 1 네이티브 작업 = Completed(Failed 아님).

## 5. 실행 꼴 · 정지점 · 끝 줄 전체(블록별 — 정본)

### 5.0 표기 · 공통

- 표기: `<…>` = 블록이 채우는 값(응답 · 로그에서 온 값은 `\p{Cc}` → `?` · 160자) · `[ · …]` = 조건에 따라 붙는 꼬리 · `~` = 사용자 홈(블록이 줄인다). 운영자 블록 끝 줄의 머리 · tester 블록의 `PASS ` · `FAIL ` · `INFO ` · `STOP ` 접두는 블록이 붙인다.
- **운영자 블록(O-10 · W-7 · O-9)** = 창 D · **파일로만 · 인자 0**(붙여 넣지 않는다 — 남는 인자가 있으면 외부 호출 0 · 정지점 0으로 멈춘다 · 모드 · 확인은 정지점에서 고른다):
  - `pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\o10-vault-audience-negative.ps1'`
  - `pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\w7-seed-tester-m2m.ps1'`
  - `pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\o9-issue-vault-jwt.ps1'`
  - **멈춤의 출력 순서(r2 검증 V1-04 · V2-01 — 로컬 실측 · 비밀 0)**: 운영자 블록은 catch 없이 throw로 멈춘다 — `finally`가 끝 줄(W-7은 + 창 정리 줄)을 먼저 내고, pwsh의 오류 글자(`Exception` · `Line |`)는 그 **아래**에 나온다. 끝 줄의 「위 오류」(O-10 · O-9 — r0부터 · 닫힌 T075 블록 o1 · o3 · o4 · o5 · o6과 같은 관례)는 이 오류 글자를 가리킨다 — 글자는 바꾸지 않았다(기록만 · 런북 §4 T076 실패 표가 「아래」로 안내한다). 정지점에서 Ctrl+C로 끊으면 오류 글자가 없을 수 있다. tester 블록(L-8 · O-8 · C-8)은 멈춤을 잡아 `STOP ` 줄을 끝 줄 위에 낸다.
  - **관리자 kubeconfig(런북 §4 T076 「사전」이 가리키는 「실행 꼴」)**: O-10 · O-9는 블록 리터럴 `$kc = Join-Path $HOME '.kube\joshuatech-admin.yaml'`을 존재 확인 뒤 `kubectl @kargs` 한 곳에 `--kubeconfig $kc`로 직접 준다(T075 W-6 LOAD 관례). 블록은 `$env:KUBECONFIG`를 읽지도 쓰지도 않는다(정적 관문 「`$env:KUBECONFIG` 참조 0」) — 창 D 창 시작 체크리스트의 `$env:KUBECONFIG` 줄은 블록과 무관하다. W-7은 kubectl 0 — Vault 주소는 블록이 tofu 다음에 `VAULT_ADDR=http://127.0.0.1:18200`(창 C)으로 정한다 · 창 D에 `VAULT_*`가 있으면(`VAULT_ADDR=http://127.0.0.1:18200` 밖) 멈춘다.
- **tester 블록(L-8 · O-8 · C-8)** = tester가 컨트롤러 지시문대로 · Git Bash · **Bash 도구 timeout 600000**:
  - `chcp.com 65001 >/dev/null; pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\l8-live-identity-admin.ps1' -ExpectedRevision <gitops main 40자 소문자 hex>; echo "exit=$?"`
  - `chcp.com 65001 >/dev/null; pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\o8-probe-identity-m2m.ps1' -ExpectedSha <배포 이미지를 만든 main 커밋 40자 소문자 hex>; echo "exit=$?"`
  - `chcp.com 65001 >/dev/null; pwsh -NoProfile -File 'D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t076-blocks\c8-correlate-logs.ps1' -Since <O-8 start> -Nonce <O-8 nonce>; echo "exit=$?"`
  - 판정 = 끝 줄 + 종료 코드(0은 전부 PASS일 때만) · 한글 줄은 증거 · `=FAIL <k>/n`의 `<k>`는 **PASS 줄 수**다. 최악 소요(추론 — 실측 없음): O-8 ≈ 565 s(whoami 20 + Forwarding 줄 기다림 ≤ 45 + seal ≈ 20 + 로그인 · capabilities · kv 60 + Access 20 × 20 = 400 + revoke 20 — r2 RO2-01 · Bash 도구 timeout 600 s 안 · 여유 35 s) · L-8 ≈ 500 s · C-8 ≈ 140 s. 기본 120 s에서 끊기면 `finally`(revoke · port-forward 정리)가 돌지 않는다.

### 5.1 O-10(`o10-vault-audience-negative.ps1`)

- **순서**: 가드(모듈 로깅 4키 + 실효 → 남는 인자 → curl · TLS · 프록시 환경 변수 → 관리자 kubeconfig → `kubectl` · `curl.exe` 첫 해석 → curl 7.84) → INFO → **정지점 `probe`**(하나 · 가려진 입력 · 대소문자 구분 · 그 외 = 중단) → `kubectl create token agent-view -n kube-system --duration=10m`(audience 0) → 클레임 → seal-status → 로그인 1회 → (통과면) revoke-self → `finally`.
- **화면 줄(순서)**:
  - `INFO curl <maj>.<min> · Application <~경로> · kubectl Application <~경로> · Vault http://127.0.0.1:18200(창 C) — 쓰기 = agent-view 10분 토큰 발급 1회뿐 · vault CLI 0`
  - 정지점: `o10 음성 대조: agent-view 10분 토큰(audience 없음)을 발급해 e2e-reader 로그인에 한 번 넣는다(거부돼야 PASS · 통과하면 받은 토큰을 바로 revoke) — 진행하려면 probe 입력 후 Enter(입력은 가려진다 · 그 외 입력 = 중단)`
  - `OK   agent-view 10분 토큰 — aud = [<aud 원소>](vault 없음) · sub = agent-view · 수명 600 s · iat = 지금(값 미출력)`
  - `OK   Vault seal-status 200 · sealed = false · cluster_name = vault-cluster-d3b29227(http://127.0.0.1:18200 — 창 C)`
  - (빈 줄) `--- T076 O-10 음성 대조 결과(JWT · Vault 토큰 없음 · 로그인 시도 <1회|0회> — 런북 bootstrap.md §4 T076 기록 칸에 그대로 기록) ---`(r2 rv2C-03 — O-10의 기록 자리는 런북 §4 T076 기록 칸 1)
  - 끝 줄(아래 하나)
- **끝 줄 — PASS**:
  - `o10=PASS 로그인 거부(코드 <4xx> · <errors 첫 줄>) — audience 없는 agent-view 토큰은 e2e-reader 자격이 아니다(VD-T076-1)` — errors 첫 줄 자리는 errors가 없으면 `(errors 없음)` · 본문이 JSON이 아니면 `(본문 해석 불가)`.
- **끝 줄 — 로그인 통과(FAIL · 정책 apply · W-7로 가지 않는다)**:
  - `o10=FAIL 로그인 통과(코드 <c> · 정책 [<정책 목록>] · lease <n> s) — audience 없는 agent-view 토큰이 e2e-reader 자격이다 · revoke-self <결과> — 정책 apply · W-7 시드로 넘어가지 않는다(멈추고 컨트롤러 · 사용자에게 보고)` — 결과 = `204(취소됨)` · `실패(코드 <c> — 토큰은 이 프로세스 메모리에만 있었고 버렸다 · lease 뒤 만료)` · `실패(curl exit=<rc> · <오류 첫 줄> — 토큰은 이 프로세스 메모리에만 있었고 버렸다 · lease 뒤 만료)`. 응답에 `auth.client_token`이 있으면 코드와 무관하게 이 줄이다(4xx여도 — O10-06).
- **끝 줄 — 판정 불가 · 보내기 전(JWT 전송 0)**:
  - `o10=FAIL 판정 불가(중단 — 위 오류 · JWT 전송 0)` — 가드 실패(모듈 로깅 · 환경 변수 · 관리자 kubeconfig 없음 · kubectl · curl.exe 없음 · curl 7.84 미만) · 정지점에 `probe`가 아닌 입력.
  - `o10=FAIL 판정 불가(인자 <n>개 — 값 미출력 · 이 블록은 인자를 받지 않는다(입력은 정지점 단어 probe 뿐) · 토큰 발급 0 · JWT 전송 0)` — **남는 인자**(외부 호출 0 · 정지점 0).
  - `o10=FAIL 판정 불가(첫 해석이 실행 파일이 아니다: <이름 → 형>[ · <이름 → 형>] — 같은 이름의 함수 · 별칭 · 프로필 정의 · 토큰 발급 0 · JWT 전송 0)` — **첫 해석 가림**(이름 = `kubectl` · `curl.exe` · 형 = `Function` · `Alias` · `ExternalScript` 등 · curl `--version`도 0).
  - `o10=FAIL 판정 불가(토큰 발급 도중 중단 — 위 오류 · JWT 전송 0)`
  - `o10=FAIL 판정 불가(kubectl create token exit=<rc> · 출력 <n> 줄 · <오류 첫 줄> — JWT 전송 0)`
  - `o10=FAIL 판정 불가(JWT 꼴이 아니다 — 점 둘 · base64url 세 조각 · payload JSON · 값 미출력 · JWT 전송 0)`
  - `o10=FAIL 판정 불가(클레임 — <사유>[ · <사유>] · JWT 전송 0)` — 사유: `aud 가 없거나 문자열(또는 문자열 배열)이 아니다` · `aud 에 vault 가 있다([<aud 원소>]) — 음성 대조가 성립하지 않는다` · `sub = <값>(system:serviceaccount:kube-system:agent-view 가 아니다)` · `exp · iat 가 정수가 아니다` · `수명 exp − iat = <n> s(기대 600 ± 10)` · `iat − 지금 = <n> s(기대 ± 120 — 이 PC 시계 · 클러스터 시계 확인)`.
  - `o10=FAIL 판정 불가(seal-status — <까닭> · 기대 200 · sealed false · vault-cluster-d3b29227 — 창 C · 클러스터 확인 · JWT 전송 0)` — 까닭 = `curl exit=<rc> · <오류 첫 줄>`(Vault 미도달) 또는 `코드 <c> · sealed = <값> · cluster_name = <값>`(sealed · 다른 Vault · 본문 해석 불가).
- **끝 줄 — 판정 불가 · 보낸 뒤(받은 토큰 0)**:
  - `o10=FAIL 판정 불가(로그인 도중 중단 — 토큰이 발급됐는지 모른다 · 받은 토큰 0 · TTL 뒤 만료)`
  - `o10=FAIL 판정 불가(로그인 응답 — 코드 <c> · <errors 첫 줄> · 받은 토큰 0)` — 5xx(O10-19) · 200인데 auth 없음(O10-20) · 200 · auth만 있고 client_token 없음(O10-21) · 4xx인데 auth 객체 있음(O10-21b).
  - `o10=FAIL 판정 불가(로그인 응답 — curl exit=<rc> · <오류 첫 줄> · 받은 토큰 0)` — 응답 유실 · 시간 초과(O10-22).

### 5.2 W-7(`w7-seed-tester-m2m.ps1`)

- **순서**: 가드(클립보드 기록 → 모듈 로깅 4키 + 실효 → 남는 인자 → `~/.vault-token` · `VAULT_*` → tofu · TLS · 프록시 환경 변수 → 파일 실행(`$PSScriptRoot`) · `infra\cloudflare\outputs.tf` → `tofu` · `vault` 첫 해석) → INFO → tofu output(꼴 판정 — Vault 토큰을 묻기 전) → `vault status`(initialized · sealed · exit · **`cluster_name`**) → **정지점 ① root 토큰**(보안 입력 · 붙인 직후 클립보드 비움) → `token lookup`(root 정책) → 상태 판정 → (absent일 때만) **정지점 ② `seed`**(가려진 입력 · 대소문자 구분) → `kv put "-cas=0"` → 되읽기 → 메타데이터 → `finally`.
- **화면 줄(순서)**:
  - `INFO vault CLI: <vault version 첫 줄> · Application <~경로> · tofu <tofu version 첫 줄> · Application <~경로> — 쓰기 = kv put -cas=0 한 번뿐(absent 일 때) · tofu 는 출력 읽기만`
  - `OK   tofu 출력 service_tokens → tester-m2m 의 client_id · client_secret 꼴 확인(값 미출력 · 나머지 토큰은 버렸다)`
  - `OK   Vault 도달 · 초기화됨 · unsealed · cluster_name = vault-cluster-d3b29227(seal type=<type> · server <version>)`
  - 정지점 ①: `root 토큰(PM 에서 복사 · 화면에 남지 않음 · 붙여넣은 직후 클립보드를 비운다)`
  - `OK   토큰 정책에 root 포함 — 쓰기 보호 판정(읽기 전용)을 시작한다`
  - 판정 줄 하나: `PLAN kv/platform/access/tester-m2m — absent → 생성 예정(키 client_id · client_secret · -cas=0) · 지금 v0` / `SKIP kv/platform/access/tester-m2m — 이미 있음 · 같음(v<n> · 키 client_id · client_secret = tofu 의 tester-m2m · 값 · 해시 미출력 · 덮어쓰지 않는다)` / `STOP kv/platform/access/tester-m2m — <판정 사유>`(아래 요약 행 `중단(…)`의 괄호 안과 같다)
  - (absent) 빈 줄 · `쓸 경로 1개: kv/platform/access/tester-m2m  (생성 · -cas=0 · 키 client_id · client_secret = tofu 출력의 tester-m2m — 값은 화면에 나오지 않는다)`
  - 정지점 ②: `쓰기 확인: kv/platform/access/tester-m2m 를 -cas=0 으로 만든다(그 사이 누가 만들었으면 거부 — 덮어쓰기 없음) — 진행하려면 seed 입력 후 Enter(입력은 가려진다 · 그 외 입력 = 중단)`
  - 쓰기 뒤: `OK   kv/platform/access/tester-m2m v1 — 생성 · 되읽기 해시 일치(client_id·client_secret)`(응답 유실 뒤 재판정이면 `생성` 자리가 `기록됨(응답 유실 — 이 실행의 값 · 쓰기 exit=<rc> 뒤 재판정)`) 또는 쓰기 단계 STOP 줄 하나: `STOP kv/platform/access/tester-m2m — 쓰기 거부(exit=<rc>) · 재판정 current_version 그대로 = 쓰지 않았다(권한 · 연결 · CAS · CLI 오류 — 같은 STOP 이 반복되면 토큰 정책 · 창 C 확인)` · `STOP kv/platform/access/tester-m2m — 쓰기 거부(exit=<rc>) · 재판정 <kind>(current_version=<n>[ · <사유>]): 이 실행의 값이 기록됐는지 확인하지 못했다 — 지우지 말고 재실행한다(같은 값이면 건너뛴다 · 다르면 멈춘다)` · `STOP kv/platform/access/tester-m2m — 되읽기 실패(exit=<rc>). 재실행한다(같은 값이면 건너뛴다 · 다르면 멈춘다)` · `STOP kv/platform/access/tester-m2m — 되읽기 응답을 해석하지 못했다(원문 미출력)` · `STOP kv/platform/access/tester-m2m — 쓰기 거부(exit=<rc>) · CAS 충돌(다른 값 — <사유> · 값 · 해시는 출력하지 않는다): kv 의 v1 은 다른 기록자의 값이다(사람 판단)` · `STOP kv/platform/access/tester-m2m — 되읽기 불일치(<사유> — 값 · 해시는 출력하지 않는다)` · `STOP kv/platform/access/tester-m2m — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(<kind> · current_version=<n>[ · <사유>])`
  - `finally`: 빈 줄 · `--- T076 W-7 tester-m2m kv 시드 결과(값 · 해시 없음 — 런북 bootstrap.md §4 T076 기록 칸에 그대로 기록) ---` · 요약 행(경로를 32칸 왼쪽 맞춤 + 빈칸 + 요약 행) · **끝 줄** · [`결과 미확인 = 쓰기 도중 중단 또는 비 0 뒤 재판정 불가 — kv 에 새 버전이 있을 수 있다. 지우지 말고 재실행한다(같은 값이면 건너뛴다 · 다르면 멈춘다)`(요약 행이 `결과 미확인`으로 시작할 때)] · [경고 `~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인`] · **창 정리 줄(늘 마지막 — 결과로 가르는 두 꼴 · r2 RO2-02)**:
  - 끝 줄이 `w7=OK absent→v1` · `w7=OK absent→v1 · 응답 유실 뒤 재판정(…)` · `w7=SKIP live-same`일 때만(닫기 — 결정 RO-03 글자): `창 정리(T076 — 런북 bootstrap.md §3 T076 ①-5): 창 C port-forward(18200) 종료(Ctrl+C — 뒤 단계는 18200 을 쓰지 않는다) · 창 A 터널 · 창 D 는 닫지 않는다(②-3 O-7 · ④-1 · ④-3 O-9 · ⑤ 세션 끝 정리까지)`
  - 그 밖 전부(`w7=STOP …` 모든 꼴 — 가드 · 판정 · 쓰기 단계 · 정지점 중단 · 쓰기 도중 중단 · 예외 = 기본값 · 유지 — 결정 RO2-02 글자): `창 정리(T076 — 런북 bootstrap.md §4 T076 실패 표): 창 C port-forward(18200) 는 닫지 않는다(실패 표 조치 — 재실행 · 버전 이력 · cluster_name 조사에 18200 이 필요하다) · 창 A 터널 · 창 D 도 닫지 않는다`
  - 실물 `pwsh -File`에서는 `w7=STOP …`이면(늘 throw로 멈춘다) 이 줄 아래에 pwsh의 오류 글자가 더 나온다 — 하네스의 「마지막 줄」은 블록이 낸 마지막 항목이다(§3 31).
- **끝 줄(요약 행 → 끝 줄)**:
  - `w7=OK absent→v1` ← 요약 행 `생성 v1 · 되읽기 해시 일치(client_id·client_secret)`
  - `w7=OK absent→v1 · 응답 유실 뒤 재판정(이 실행의 값 · 되읽기 해시 일치)` ← `기록됨(응답 유실 — 이 실행의 값 · 쓰기 exit=<rc> 뒤 재판정) v1 · 되읽기 해시 일치(client_id·client_secret)`
  - `w7=SKIP live-same`(재실행 기대) ← `건너뜀(이미 있음 · 같음 — v<n> · 키 client_id · client_secret · 덮어쓰지 않았다)`
  - 그 밖 = `w7=STOP <요약 행>`:
- **`w7=STOP` 요약 행 — 쓰기 전 · 미실행(쓰기 0)**:
  - `w7=STOP 미실행(판정 전 중단 — 쓰기 0)` — 기본값: 클립보드 기록 · 모듈 로깅 · `~/.vault-token` · `VAULT_*` · 환경 변수 · 파일 실행 · `infra/cloudflare` · CLI 없음 · Vault 도달 실패 · 미초기화 · sealed · status exit · root 토큰 꼴(`hvs.`로 시작하는 공백 없는 ASCII가 아님) · token lookup 실패 · root 아님.
  - `w7=STOP 인자 <n>개(값 미출력 — 이 블록은 인자를 받지 않는다 · 입력은 정지점 root 토큰 · seed 뿐) — 미실행(아무것도 묻지 · 읽지 않았다 · 쓰기 0)` — **남는 인자**(외부 호출 0).
  - `w7=STOP 미실행(첫 해석이 실행 파일이 아니다: <이름 → 형>[ · <이름 → 형>] — 같은 이름의 함수 · 별칭 · 프로필 정의 · 아무것도 읽지 않았다 · 쓰기 0)` — **첫 해석 가림**(이름 = `tofu` · `vault`).
  - `w7=STOP 미실행(자격 꼴 아님 — tofu 출력에서 tester-m2m 을 꺼내지 못했다 · Vault 토큰을 묻지 않았다 · 쓰기 0)`
  - `w7=STOP 미실행(Vault cluster_name = <값|(없음)> — 기대 vault-cluster-d3b29227 · 창 C 가 다른 Vault 를 가리킨다 · root 토큰을 묻지 않았다 · 쓰기 0)` — **`cluster_name` 다름 · 없음**(값은 제어 문자 → `?` · 160자 · 빈 값이면 `(없음)` · tofu output과 `vault status`는 이미 돌았다).
  - `w7=STOP 미실행(쓰기 확인 정지점에서 중단 — 쓰지 않았다)` — 정지점 ②에 `seed`가 아닌 입력.
  - `w7=STOP 쓰기 예정(판정 — absent → 생성 예정 · 쓰기 확인 전)` — 판정 뒤 · 정지점 ② 앞에서 끊긴 경우에만(쓰기 0).
- **`w7=STOP` 요약 행 — 판정 STOP(쓰기 0)**:
  - `w7=STOP 중단(live-different: <키> 가 tofu 의 tester-m2m 과 다르다(회전 = T084 — 덮어쓰지 않는다 · 값 · 해시 미출력))` — 키 = `client_id` · `client_secret` · `client_id·client_secret`.
  - `w7=STOP 중단(live-mismatch: 키 집합 불일치(누락: <키|없음> · 여분 <n>개)(값 미출력 · 사람 판단 — 덮어쓰지 않는다))` · `w7=STOP 중단(live-mismatch: <키> 값이 문자열이 아니다(값 미출력 · 사람 판단 — 덮어쓰지 않는다))`
  - `w7=STOP 중단(dead — <사유>(사람 판단 — 되살리거나 지우지 않는다))` — 사유 = `current_version=0(메타데이터만 있고 버전이 없다)` · `현재 버전 <n> 이 파기(destroy)됐다` · `현재 버전 <n> 에 deletion_time 이 있다(soft-delete 또는 삭제 예약)` · `현재 버전 <n> 항목이 versions 에 없다`.
  - `w7=STOP 중단(판정 불가 — <사유>)` — 사유 = `metadata 조회 exit=<rc> · <오류 첫 줄>` · `metadata 응답을 해석하지 못했다(JSON · data 없음)` · `current_version 이 정수가 아니다` · `versions.<n>.destroyed 형식이 기대와 다르다` · `kv get exit=<rc>(값을 읽지 못했다)` · `kv get 응답을 해석하지 못했다(원문 미출력)` · `현재 버전에 데이터가 없다(data.data 가 없거나 객체가 아니다)`.
- **`w7=STOP` 요약 행 — 쓰기 뒤(쓰기 거부 · 결과 미확인 · 기록됨)**:
  - `w7=STOP 중단(쓰기 거부 exit=<rc> — 재판정 current_version 그대로 · 쓰지 않았다)`
  - `w7=STOP 중단(쓰기 거부 exit=<rc> — 재판정 v1 · 되읽기 값이 이 실행의 것과 다르다 = CAS 충돌 · 덮어쓰지 않았다)`
  - `w7=STOP 결과 미확인(쓰기 exit=<rc> — 재판정 <kind> · current_version=<n> · 재실행이 판정한다)` — 그리고 도중에 끊긴 경우의 셋: `w7=STOP 결과 미확인(쓰기 진행 중 중단 — kv 에 새 버전이 있을 수 있다 · 재실행이 판정한다)` · `w7=STOP 결과 미확인(쓰기 exit=<rc> — 재판정 전 중단 · 재실행이 판정한다)` · `w7=STOP 결과 미확인(쓰기 exit=<rc> — 재판정 v1 · 되읽기 대조 전 중단)` — 넷 모두 다음 줄에 「결과 미확인 = …」 안내가 붙는다.
  - `w7=STOP 기록됨 — 되읽기 실패(exit=<rc> · 재실행이 판정한다)` · `w7=STOP 기록됨 — 되읽기 응답 해석 실패(재실행이 판정한다)` · `w7=STOP 기록됨 — 되읽기 불일치(<사유>) · 수동 확인` · `w7=STOP 기록됨 — 메타데이터 확인 실패(<kind> · current_version=<n> · 기대 1)` · `w7=STOP 기록됨 v1 — 되읽기 검증 전(아래 오류 확인)`(put 성공 직후 끊긴 경우).

### 5.3 O-9(`o9-issue-vault-jwt.ps1`)

- **순서**: 가드(모듈 로깅 4키 + 실효 → 남는 인자 → TLS · 프록시 환경 변수 → `LOCALAPPDATA`(절대 경로의 폴더) → 관리자 kubeconfig → `kubectl` 첫 해석) → INFO → **정지점(모드) 하나 — `issue` 또는 `clear`**(가려진 입력 · Ordinal — `Issue` · `clear ` · 빈 값 = 중단) → `clear` = 파일 삭제 / `issue` = `kubectl create token agent-view -n kube-system --audience vault --duration=1h` → 출력 한 줄 · 꼴 · 클레임(aud INFO) → DPAPI 쓰기 → O-8 꼴 되읽기 → `finally`.
- **화면 줄(순서)**:
  - `INFO kubectl Application <~경로> · kubeconfig ~\.kube\joshuatech-admin.yaml · JWT 파일 ~\AppData\Local\jt-e2e\vault-e2e-reader.jwt(있음 — issue 는 덮어쓰고 clear 는 지운다)`(파일이 없으면 괄호 안이 `없음` · 경로는 `LOCALAPPDATA`가 홈 아래 기본 위치일 때의 꼴)
  - 정지점: `o9 모드 — issue(vault 전용 1시간 JWT 발급 · 파일 덮어쓰기) 또는 clear(파일 삭제 — 세션 끝)를 그대로 입력(입력은 가려진다 · 그 외 = 중단)`
  - (issue) `INFO aud 꼴=<문자열|배열>(VD-T076-10 관찰 — K3s TokenRequest 의 단일 audience 직렬화 · 문자열 "vault" · ["vault"] 둘 다 오직 vault)` — aud 판정이 통과하면 나온다(sub · 수명 · iat가 실패해도 STOP 줄 앞에 나온다).
  - (issue) `OK   JWT 꼴 · aud = 오직 vault(문자열 "vault" 또는 원소 하나인 배열 ["vault"]) · sub = agent-view · 수명 3600 s · iat = 지금(값 미출력) — DPAPI 로 암호화해 파일에 쓴다`
  - (issue) `OK   새 파일 · 되읽기(O-8 꼴) 일치` 또는 `OK   기존 파일을 덮어썼다 · 되읽기(O-8 꼴) 일치`
  - (빈 줄) `--- T076 O-9 결과(모드=<issue|clear|선택 전> · JWT · 암호문 없음 — 런북 bootstrap.md §3 T076 기록 칸에 그대로 기록) ---`
  - 끝 줄 · (issued일 때) 다음 줄 `다음: 컨트롤러가 이 1시간 안에 tester 2차(O-8)를 디스패치한다 · 2차가 끝나면 이 블록을 clear 로 다시 돌린다(세션 끝)`
- **끝 줄 — 정상**:
  - `o9 issued exp=<yyyy-MM-ddTHH:mm:ss>Z file=~\AppData\Local\jt-e2e\vault-e2e-reader.jwt`(exp = UTC · 표준 `'s'` 꼴)
  - `o9 cleared`
  - `o9 nothing-to-clear`(파일이 이미 없다 — 정상)
- **끝 줄 — STOP(`[ · 기존 파일 그대로]` = 시작 때 파일이 있었으면 붙는다)**:
  - `o9=STOP 판정 전 중단(위 오류 — kubectl 0 · 파일 쓰기 0)` — 가드 실패 · 모드 단어가 `issue` · `clear`가 아님 · kubectl 없음(머리 줄 `모드=선택 전`).
  - `o9=STOP 인자 <n>개(모드는 정지점 단어 issue/clear — 인자를 받지 않는다 · 값 미출력) — kubectl 0 · 파일 그대로(쓰기 · 삭제 0) · 인자 없이 다시 실행해 정지점에 issue 또는 clear` — **남는 인자**(`-Clear` 포함 · 외부 호출 0 · 정지점 0).
  - `o9=STOP 첫 해석이 실행 파일이 아니다: kubectl → <형>(같은 이름의 함수 · 별칭 · 프로필 정의) — kubectl 0 · 파일 쓰기 0` — **첫 해석 가림**.
  - `o9=STOP 발급 도중 중단(위 오류 — 파일 쓰기 0)`
  - `o9=STOP kubectl create token 실패(exit=<rc> · <오류 첫 줄>) — 파일 쓰기 0[ · 기존 파일 그대로]`
  - `o9=STOP kubectl 출력이 한 줄이 아니다(<n> 줄 — 값 미출력) — 파일 쓰기 0[ · 기존 파일 그대로]`
  - `o9=STOP JWT 꼴이 아니다(점 둘 · base64url 세 조각 · payload JSON — 값 미출력) — 파일 쓰기 0[ · 기존 파일 그대로]`
  - `o9=STOP 클레임 판정 실패(<사유>[ · <사유>]) — 파일 쓰기 0[ · 기존 파일 그대로]` — 사유: `aud 없음` · `aud = <표시>(문자열 "vault" 또는 원소 하나인 배열 ["vault"] 가 아니다 — Ordinal · 대소문자 구분)`(표시 = 문자열이면 따옴표 친 값 · 배열이면 대괄호 안 원소 목록 · null이면 `null` · 그 밖의 형이면 꺾쇠 안 형 이름) · `sub = <값>(system:serviceaccount:kube-system:agent-view 가 아니다)` · `exp · iat 가 정수가 아니다` · `수명 exp − iat = <n> s(기대 3600 ± 10)` · `iat − 지금 = <n> s(기대 ± 120 — 이 PC 시계 · 클러스터 시계 확인)`.
  - `o9=STOP 파일 쓰기 도중 중단(파일이 바뀌었을 수 있다 — 다시 issue 또는 clear)`
  - `o9=STOP 되읽기 불일치(O-8 꼴로 복호한 값이 발급한 JWT 와 다르다 — 파일을 지웠다)`
  - `o9=STOP clear 도중 중단(파일이 남았을 수 있다 — 직접 확인)` · `o9=STOP clear 실패(파일이 남아 있다 — 직접 지운다)`

### 5.4 L-8(`l8-live-identity-admin.ps1` — tester 1차)

- **순서**: 모듈 로깅 → 입력(`$PSScriptRoot` → 남는 인자 → `-ExpectedRevision` `\A[0-9a-f]{40}\z`) → 환경 변수 → `curl.exe` · `kubectl.exe` 첫 해석 → curl 7.84 → INFO → agent-view kubeconfig · `auth whoami` → dev → prod 사다리(get · logs · 무자격 curl) → admin INFO → `finally`. 정지점 0(입력은 param뿐).
- **화면 줄**: `INFO curl <maj>.<min> · Application <~경로> · kubectl Application <~경로> — 읽기만 · 자격 0` · `OK   kubectl auth whoami = system:serviceaccount:kube-system:agent-view` · (빈 줄) `--- T076 L-8 라이브 사다리 결과(identity-admin dev · prod ⓪–⑤ · 비밀 0 — tester 보고에 그대로) ---` · 판정 24줄(`PASS <이름>` 또는 `FAIL <이름> — <사유>` · dev 12 → prod 12) · INFO 줄 · [`STOP <사유>`] · 끝 줄.
- **판정 이름(env마다 12 — `<env>` = dev · prod)**:
  - `l8 <env> ⓪ Application identity-admin-<env> — Synced · Healthy · revision = 입력 · operationState Succeeded`
  - `l8 <env> ① ES identity-admin-env Ready=True(SecretSynced)` · `l8 <env> ① ES identity-admin-migrate Ready=True(SecretSynced)`
  - `l8 <env> ② ES identity-admin-env 스펙 — ClusterSecretStore vault-<env> · 템플릿 키 정확히 11 · 원격 키 12줄 = gitops · /owner 0 · <env>/ 접두`
  - `l8 <env> ② ES identity-admin-migrate 스펙 — vault-<env> · 키 {DATABASE_OWNER_URL} · 원격 키 <env>/db/<role>/owner · PreSync · BeforeHookCreation · wave -1(Job 0 보다 앞)`(role = dev `dev_identity_admin` · prod `identity_admin`)
  - `l8 <env> ③ Deployment identity-admin — init startup-check · web · relay · runAsNonRoot · 10001 · RuntimeDefault · SA 토큰 0 · 권한 상승 0 · drop [ALL] · 읽기 전용 루트 · /tmp emptyDir`
  - `l8 <env> ③ Deployment identity-admin-celery — celery · 같은 보안 컨텍스트 · /tmp emptyDir`
  - `l8 <env> ③ Job identity-admin-migrate — migrate · 같은 보안 컨텍스트 · /tmp emptyDir · PreSync · BeforeHookCreation · wave 0`
  - `l8 <env> ③ 프로브 — web liveness /healthz 20 · readiness /ready 5 · startup /ready 30×5 · timeout 3 · relay tcpSocket 9464 만 · 그 밖 0 · /health 0`
  - `l8 <env> ③ -migrate 분리 — Deployment 둘 = identity-admin-config · identity-admin-env · CA 볼륨(-migrate 0) · Job 자격 Secret = identity-admin-migrate 뿐(볼륨은 CA pg-main-ca · ConfigMap 0)`
  - `l8 <env> ④ init startup-check 로그에 「startup_check: OK」`
  - `l8 <env> ⑤ 무자격 GET https://identity-m2m-<env>.joshuatech.dev/health → 401 · Location 없음(Access — 계약 C11 · 편차 후보 6)`
- **INFO(합격선 아님)**: `INFO l8 <env> ④ startup-check: startup_check: OK` · `INFO l8 <env> ⑤ 무자격 GET /health 미디어 타입 = <미디어 타입>` · `INFO l8 admin 무자격 GET https://admin.joshuatech.dev/identity-admin/admin/ → <코드> · Location <scheme://host/path> — Access 로그인 꼴(호스트 joshua-tech.cloudflareaccess.com · 경로 /cdn-cgi/access/login/) · US4 AC6 · 합격선 아님(T085)`(꼴이 아니면 꼬리가 ` — Access 로그인 꼴 아님 · US4 AC6 · 합격선 아님(T085)` · Location이 없으면 `(Location 없음)` · 해석 불가면 `(Location 해석 불가 — 값 미출력)` · 응답이 없으면 `INFO l8 admin 무자격 GET https://admin.joshuatech.dev/identity-admin/admin/ → 응답 없음(<curl exit=… · …>) — US4 AC6 · 합격선 아님`) — Location의 쿼리(meta 토큰)는 내지 않는다.
- **migrate Job이 없을 때**(TTL — §8): env마다 셋 FAIL — Job 줄 사유 `kubectl get jobs.batch identity-admin-migrate 실패(exit=<rc>[ · <오류 첫 줄>]) — ttlSecondsAfterFinished 7일이 지났거나 sync 전` · 프로브 · 분리 줄 사유 `워크로드 셋 중 읽지 못한 것이 있다(위 ③ 줄)` → 한 env면 `l8=FAIL 21/24`(L8-19) · 두 env면 `l8=FAIL 18/24`.
- **STOP(입력 · 가드 — 아무것도 부르지 않았다)**: `STOP 파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로> -ExpectedRevision <40자 hex>) — 아무것도 부르지 않았다` · `STOP 입력은 -ExpectedRevision 하나뿐이다 — 그 밖의 인자 <n>개(값 미출력) · 아무것도 부르지 않았다`(**남는 인자**) · `STOP 입력 -ExpectedRevision 이 40자 소문자 hex(gitops main 커밋)가 아니다(아무것도 부르지 않았다)` · `STOP 첫 해석이 실행 파일(Application)이 아니다: <이름 = 형>[ · <이름 = 형>] — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다. 그 정의가 없는 창(pwsh -NoProfile)에서 다시(아무것도 부르지 않았다)`(**첫 해석 가림**) · `STOP kubectl auth whoami 가 agent-view 가 아니다(exit=<rc> · 사용자 <사용자>[ · <오류>]) — agent-view kubeconfig 로만 실행한다(아무것도 판정하지 않았다)` · 그 밖(모듈 로깅 · 환경 변수 · 실행 파일 없음 · curl 7.84 · kubeconfig 없음)은 블록 throw 문 글자 그대로.
- **끝 줄**: `l8=PASS 24/24`(exit 0) · `l8=FAIL <k>/24`(exit 1).

### 5.5 O-8(`o8-probe-identity-m2m.ps1` — tester 2차 · 자격 블록)

- **순서**: 모듈 로깅 → 입력(`$PSScriptRoot` → 남는 인자 → `-ExpectedSha` `\A[0-9a-f]{40}\z`) → 환경 변수(+ `VAULT_*`) → Transcription → 실행 파일(첫 해석 · 저장소 · TEMP · TMP 아래) → curl 7.84 → INFO → agent-view whoami → JWT(DPAPI 복호 · 꼴 · 클레임) → port-forward(Forwarding 줄 정확히 한 줄 · ≤ 45 s · 0.5 s × 90 — r2 RO2-01 · 터널 경유 수립 10–23 s) → seal-status(≤ 15 s · 0.5 s × 30 · `cluster_name`) → 로그인 직전 재확인 → 로그인(본문 stdin) → capabilities-self 관문 → kv 읽기(키 둘 · 꼴) → 탐침 dev → prod(판정 a · b–e · INFO) → `finally`(revoke-self → port-forward 종료). 정지점 0.
- **화면 줄(즉시 · 순서)**:
  - `INFO curl <maj>.<min> · Application <~경로> · kubectl Application <~경로> — 쓰기 0 · 자격 · 토큰 · JWT 는 stdin 으로만`
  - `OK   kubectl auth whoami = system:serviceaccount:kube-system:agent-view`
  - `INFO jwt aud 꼴=<배열|문자열>(VD-T076-10 — 문자열 · 원소 하나 배열 둘 다 받는다)` — JWT 판정이 전부 통과한 뒤에만.
  - `INFO jwt exp=<UTC> 남은 <n>분(UD-16 — 같은 1시간 안 재사용 · 파일은 그대로 둔다)`
  - `OK   Vault seal-status: sealed=false · cluster_name=vault-cluster-d3b29227(port-forward 127.0.0.1:<n> — 블록 소유 · 포트는 kubectl 이 골랐다)`
  - `OK   Vault 로그인(role e2e-reader) · policies=<정책 목록> · lease_duration=<n> s — 토큰 값 미출력`
  - `OK   권한 관문(sys/capabilities-self): kv/data/platform/access/tester-m2m=[read] · kv/data/platform/access/tester-k8s=[deny] · kv/metadata/platform/access/tester-m2m=[deny] · kv/data/platform/authentik/e2e=[read] · kv/data/prod/db/identity_admin/app=[deny]`
  - `OK   tester-m2m 자격 = kv 키 둘(client_id · client_secret) · 꼴 일치(값 미출력)`
  - `INFO o8 start=<UTC> nonce=<nonce> — C-8 입력(-Since · -Nonce) · start 는 첫 요청보다 60 s 앞(노드 시계 차이 여유)` — start = `yyyy-MM-ddTHH:mm:ssZ` · nonce = `t076-<yyyyMMddTHHmmssZ>-<6 hex>`(둘 다 InvariantCulture — C-8 입력 정규식과 같은 꼴).
- **`finally` 줄**: (빈 줄) `--- T076 O-8 탐침 결과(identity-m2m dev → prod · 자격 · 토큰 · JWT · 쿠키 없음 — tester 보고에 그대로) ---` · 판정 10줄 · INFO 줄 · [`STOP <사유>`] · 끝 줄.
- **판정 이름(env마다 다섯 — dev → prod)**:
  - `o8 <env> a GET /health → 200 · status ok · checks {db, dragonfly, kafka_producer} 모두 ok · git_sha = 입력 · cf-cache-status ≠ HIT`
  - `o8 <env> <b|c|d|e> GET <경로> → 404 · text/plain · 본문 「404 page not found」 한 줄 · 19 B · cf-cache-status ≠ HIT(Traefik 라우터 없음 — D10)` — b `/admin/` · c `/webhooks/authentik` · d `/healthz` · e `/ready`.
  - FAIL 사유(a): `응답 <c>` · `status = <값>` · `checks 키 <n>개(<키 목록>)` · `checks.<이름> = <값>` · `git_sha = <값|(꼴 밖)>` · `cf-cache-status = <값>` · `curl exit=<rc> · <오류>` / (b–e): `응답 <c>` · `미디어 타입 = <값|(없음)>` · `본문 ≠ 「404 page not found」 한 줄(줄 <n>)` · `size_download = <값>` · `cf-cache-status = <값>`.
- **INFO(합격선 아님 · `finally`에서)**:
  - 요청마다(env마다 10 = 20): `INFO o8 <env> <id> at=<UTC> code=<코드> ct=<Content-Type> cfc=<cf-cache-status> cf-ray=<cf-ray>` — id = `health` · `admin` · `webhooks` · `healthz` · `ready` · `apix` · `sessionsx` · `healthslash` · `tenantsme` · `fake` · 값이 없으면 `(없음)`(C-05 · VD-T076-5 · 6).
  - `INFO o8 <env> health x-request-id = 보낸 값(VD-T076-4) · Cache-Control = <값>`(다르면 `x-request-id ≠ 보낸 값(<값|없음> — VD-T076-4)`)
  - `INFO o8 <env> INFO GET <경로> → <코드> · <미디어 타입>[ · type=<problem type>] · <크기> B · cf-cache-status=<값>[ · Traefik 404 꼴]` — 경로 = `/apix` · `/sessionsX` · `/health/` · `/tenants/me`(VD-L9 · CN 음성 — VD-T076-3).
  - `INFO o8 <env> INFO 가짜 자격(비밀 아닌 고정 값 — 0×32.access · A×54) GET /health → <같은 꼴>(VD-T076-8)`
  - `INFO vault token revoked(<코드>)`(응답이 없으면 괄호 안이 `응답 없음 · curl exit <rc>` · 예외면 `INFO vault token revoke 실패(예외 — 토큰은 lease 1시간 안에 만료된다)`) · `INFO port-forward 종료(블록 소유 kubectl 스레드 작업)`
- **STOP — 입력 · 가드(아무것도 보내지 않았다)**: `STOP 파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로> -ExpectedSha <40자 hex>) — 아무것도 보내지 않았다` · `STOP 입력은 -ExpectedSha 하나뿐이다 — 그 밖의 인자 <n>개(값 미출력) · 아무것도 보내지 않았다`(**남는 인자**) · `STOP 입력 -ExpectedSha 가 40자 소문자 hex 가 아니다(아무것도 보내지 않았다)` · `STOP 이 창에 curl · Vault 동작을 바꾸는 환경 변수가 있다: <이름> — 값은 내지 않는다. 그 변수가 없는 새 창에서 다시(아무것도 보내지 않았다)` · `STOP PowerShell Transcription 정책이 켜져 있다(레지스트리: <키> · 설정 파일(값 무관): <파일>) — 이 창의 출력이 파일로 남는다. 정책이 꺼진 창 · PC 에서 다시(아무것도 보내지 않았다)` · `STOP curl.exe · kubectl.exe 를 찾지 못했다(PATH · 함수 · 별칭 어디에도 — curl <n> · kubectl <n>) — 아무것도 보내지 않았다` · `STOP 첫 해석이 실행 파일(Application)이 아니다: <이름 = 형>[ · <이름 = 형>] — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다. 그 정의가 없는 창(pwsh -NoProfile)에서 다시(아무것도 보내지 않았다)`(**첫 해석 가림**) · `STOP 실행 파일이 저장소 아래이거나 TEMP · TMP 아래에 있다: <이름 경로> — 심어 둔 실행 파일일 수 있다. 시스템 설치본이 PATH 앞에 오는 창에서 다시(아무것도 보내지 않았다)` · `STOP curl 7.84 이상이 필요하다(-w %header{…}) — 아무것도 보내지 않았다` · `STOP agent-view kubeconfig 가 없다(~\.kube\agent-view.yaml) — 컨트롤러 · 운영자에게 알린다(아무것도 보내지 않았다)` · `STOP kubectl auth whoami 가 agent-view 가 아니다(exit=<rc> · 사용자 <사용자>[ · <오류>]) — agent-view kubeconfig 로만 실행한다(아무것도 보내지 않았다)` · 모듈 로깅 · pwsh 7.5는 블록 throw 문 글자 그대로.
- **STOP — JWT(Vault로 아무것도 보내지 않았다)**: `STOP LOCALAPPDATA 가 없다 — JWT 파일 자리를 정하지 못했다(아무것도 보내지 않았다)` · `STOP 운영자 O-9 필요 — JWT 파일이 없다(%LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt) · 운영자가 O-9 로 발급한 뒤 그 1시간 안에 다시(아무것도 보내지 않았다)` · `STOP JWT 파일을 복호하지 못했다(이 Windows 사용자의 DPAPI 가 아니거나 깨졌다 — 값 미출력) · 운영자 O-9 를 다시(아무것도 보내지 않았다)` · `STOP JWT 판정 실패: <사유>[ · <사유>] — Vault 로 아무것도 보내지 않았다` — 사유 = `JWT 꼴 아님(점 둘 · base64url · JSON 페이로드)` · `aud ≠ "vault" · ["vault"](문자열 또는 원소 하나 배열 — VD-T076-10)` · `sub ≠ system:serviceaccount:kube-system:agent-view` · `exp · iat 가 정수가 아니다` · `exp 가 지금 + 60 s 안이다(만료 · 곧 만료 — 운영자 O-9 다시)` · `수명 exp − iat = <n> s(0 초과 · 3610 이하여야 한다 — UD-16 1시간)`.
- **STOP — port-forward · seal-status(JWT를 보내지 않았다)**: `STOP Vault port-forward 의 Forwarding 줄(정확히 한 줄 127.0.0.1:<포트> -> 8200)을 45 s 안에 얻지 못했다(작업 <상태> · <까닭>) — JWT 를 보내지 않았다`(r2 RO2-01 — 꼴이 틀린 줄 · 끝난 작업은 45 s를 기다리지 않고 곧바로 이 줄) — 까닭 = `Forwarding 줄 <n>개(정확히 한 줄이어야 한다 — <줄>)` · `Forwarding 줄 꼴 아님(<줄> — 기대 127.0.0.1:<포트> -> 8200)` · `마지막 줄 <줄>` · `출력 없음` · `STOP Vault port-forward(127.0.0.1:<n>)가 15 s 안에 응답하지 않았다(작업 <상태>[ · 마지막 줄 <줄>]) — JWT 를 보내지 않았다` · `STOP Vault seal-status 가 기대와 다르다(응답 <코드> · sealed=<값> · cluster_name=<값>) — 다른 Vault 이거나 봉인돼 있다. JWT 를 보내지 않았다`(**`cluster_name`**) · `STOP 로그인 직전 port-forward 재확인 실패(작업 <상태> · <까닭>) — JWT 를 보내지 않았다`(까닭 = Forwarding 판정 사유 · `Forwarding 포트 <n> ≠ <m>` · `Forwarding 줄 그대로`).
- **STOP — 로그인 뒤(토큰은 `finally`에서 revoke)**: `STOP Vault 로그인 실패(role e2e-reader · 응답 <코드|없음>[ · 토큰 꼴 아님 — 값 미출력]) — 그 뒤 아무것도 읽지 않았다` · `STOP Vault 로그인 응답이 설계와 다르다(policies=<목록> · lease_duration=<n>) — 읽지 않았다(토큰은 finally 에서 revoke)` · `STOP 권한 관문 FAIL(sys/capabilities-self 응답 <코드|없음> · <경로=[능력] 다섯>) — 정책이 설계와 다르다(VD-T076-9). 읽지 않았다` · `STOP tester-m2m 자격을 꺼내지 못했다(kv 응답 <코드|없음> · 키 <n>개 · client_id ^[0-9a-f]{32}\.access$ · client_secret ^[0-9A-Za-z_-]{54}$ 꼴 아님 — 값 미출력) · Access 로 아무것도 보내지 않았다`. 멈춤 사유에 JWT · 토큰 · client_id · client_secret(8자 이상)이 끼면 `(값 가림)`으로 바꾸고 홈 경로는 `~`로 낸다.
- **끝 줄**: `o8=PASS 10/10`(exit 0) · `o8=FAIL <k>/10`(exit 1).

### 5.6 C-8(`c8-correlate-logs.ps1` — tester 2차 · 비밀 0)

- **순서**: 모듈 로깅 → 입력(`$PSScriptRoot` → 남는 인자 → `-Since` 꼴 `\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\z` · 날짜 · 범위(지금 + 5분 이전 · 24시간 안) → `-Nonce` 꼴 `\At076-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{6}\z`) → 환경 변수 → `kubectl.exe` 첫 해석 → INFO → whoami → Traefik 복제 = 1(spec · status) → `logs deploy/traefik --since-time=<Since>`(nonce 줄만 · 투영 필드만) → env마다 404 넷 판정 · Traefik INFO → pod 로그(`request_id`) 판정 → `finally`. 정지점 0.
- **화면 줄**: `INFO kubectl Application <~경로> — 읽기만 · 투영 필드만 낸다` · `OK   kubectl auth whoami = system:serviceaccount:kube-system:agent-view` · `OK   Traefik 로그(--since-time=<Since>): nonce 줄 <n>개 — 투영 필드만 남겼다` · (빈 줄) `--- T076 C-8 로그 대조 결과(Traefik · identity-admin web — 투영 필드만 · 운영자 IP · UA · ClientHost 없음 — tester 보고에 그대로) ---` · 판정 10줄 · INFO · [`STOP <사유>`] · 끝 줄.
- **판정 이름(env마다 다섯)**:
  - `c8 <env> <b|c|d|e> GET <경로> — Traefik 줄 정확히 1 · DownstreamStatus 404 · OriginStatus 0 · RouterName 없음(VD-T076-2)` — FAIL 사유 = `줄 <n>개(정확히 1 이어야 한다)` · `DownstreamStatus <값>` · `OriginStatus <값|(없음)>` · `RouterName 있음(라우터가 받았다)`.
  - `c8 <env> pod — 404 네 경로(request_id …-<env>-admin · webhooks · healthz · ready)의 web 로그 줄 0(pod 에 닿지 않았다) · 대조 키 줄(…-<env>-health) 있음` — FAIL 사유 = `pod 로그를 읽지 못했다(exit=<rc>[ · <오류>])` · `404 네 경로의 pod 줄 <n>개(<id 목록> — pod 에 닿았다)` · `대조 키 줄 없음 — /health 요청의 request_id <Nonce>-<env>-health 가 pod 로그에 없다(상류 X-Request-ID 미전달 · 다른 pod · 로그 소실 — 0줄 판정의 근거가 없다 · VD-T076-4)`.
- **INFO**: `INFO c8 <env> traefik StartUTC=<값> · <메서드> <호스트><경로> · DownstreamStatus=<값> · OriginStatus=<값|(없음)> · RouterName <있음|없음> · request_Cf-Ray=<값|(없음)>`(`/apix` · `/sessionsX` 줄에는 ` — VD-L9(RouterName 있음 · OriginStatus 403 이면 글자 접두 → pod)`) · `INFO c8 <env> pod request_id=<값> · <요청> · <코드>(<event>)`(health 줄에는 ` — 상류 X-Request-ID 가 그대로(VD-T076-4)`) — 운영자 IP(`Cf-Connecting-Ip`) · UA · ClientHost · ClientAddr · ClientUsername · ServiceAddr는 어디에도 나오지 않는다.
- **STOP(입력 · 가드 · 로그)**: `STOP 파일로만 실행한다(pwsh -NoProfile -File <이 파일의 절대 경로> -Since <UTC> -Nonce <nonce>) — 아무것도 부르지 않았다` · `STOP 입력은 -Since · -Nonce 둘뿐이다 — 그 밖의 인자 <n>개(값 미출력) · 아무것도 부르지 않았다`(**남는 인자**) · `STOP 입력 -Since 가 UTC ISO 8601(yyyy-MM-ddTHH:mm:ssZ — O-8 의 start) 꼴이 아니다(아무것도 부르지 않았다)` · `STOP 입력 -Since 가 날짜로 읽히지 않거나 범위 밖이다(지금 + 5분 이전 · 24시간 안 — O-8 의 start 를 그대로) · 아무것도 부르지 않았다` · `STOP 입력 -Nonce 가 O-8 의 nonce 꼴(t076-<yyyyMMddTHHmmssZ>-<6 hex>)이 아니다(아무것도 부르지 않았다)` · `STOP 첫 해석이 실행 파일(Application)이 아니다: kubectl.exe = <형> — 같은 이름 함수 · 별칭(프로필 정의 포함)이 가린다. 그 정의가 없는 창(pwsh -NoProfile)에서 다시(아무것도 부르지 않았다)`(**첫 해석 가림**) · `STOP kubectl auth whoami 가 agent-view 가 아니다(exit=<rc> · 사용자 <사용자>[ · <오류>]) — agent-view kubeconfig 로만 실행한다(아무것도 판정하지 않았다)` · `STOP Traefik Deployment 복제가 1 이 아니다(exit=<rc> · spec <n> · status <n>) — deploy/traefik 로그가 요청 전부를 담는다고 볼 수 없다(판정하지 않았다)` · `STOP Traefik 로그를 읽지 못했다(exit=<rc>[ · <오류>]) — 판정하지 않았다` · 그 밖(모듈 로깅 · 환경 변수 · kubectl 없음 · kubeconfig 없음)은 블록 throw 문 글자 그대로.
- **끝 줄**: `c8=PASS 10/10`(exit 0) · `c8=FAIL <k>/10`(exit 1).

### 5.7 런북 대조(2026-11-20 — `docs/runbooks/bootstrap.md` §3 · §4 「T076」이 이 문서로 미룬 줄 · r2 갱신 — 「r2에서 런북을 고쳤다(G2)」 칸은 결정 §2의 글자 기준이다 · 정본은 런북 최종 글자 — r2 검증 V1-05)

| 런북 자리 | 가리키는 줄 | 이 문서 | 대조 |
|---|---|---|---|
| §3 T076 블록 표 O-10 행 | `o10=PASS 로그인 거부(코드 · errors 첫 줄) …` · `o10=FAIL 로그인 통과(…) … revoke-self <결과> …` · `o10=FAIL 판정 불가(…)` · 남는 인자 → 멈춤(외부 호출 0) | §5.1 | r2에서 런북을 고쳤다(G2 — 결정 §2 ⑥: :1183 남는 인자 → `o10=FAIL 판정 불가(인자 <n>개 — …)`) — 그 전에는 「STOP」(뜻 = 멈춤)이라 적었다 |
| §3 블록 표 W-7 행 · ①-5 | `w7=OK absent→v1` · `…응답 유실 뒤 재판정(…)` · `w7=SKIP live-same` · `w7=STOP <요약 행>` · 남는 인자 · `cluster_name` 다름 · 끝 줄 다음 창 정리 안내 | §5.2 | 맞음(`결과 미확인`이면 끝 줄과 창 정리 줄 사이에 안내 줄 하나가 더 있다) · 창 정리 안내는 r2에서 두 꼴이 됐고(블록 — G1) 런북 ①-5도 r2에서 고쳤다(G2 — 결정 §2 RO2-02: `w7=OK …` · `w7=SKIP live-same`이면 끝 줄의 창 정리 안내(창 C만 닫는다)를 따른다 · `w7=STOP …`이면 창 C를 닫지 않는다 — 블록도 그 안내를 낸다) |
| §3 블록 표 O-9 행 · ④-1 · ④-3 | `o9 issued exp=<UTC> file=~\AppData\Local\jt-e2e\vault-e2e-reader.jwt` · `o9 cleared` · `o9 nothing-to-clear` · `o9=STOP <사유>` · 남는 인자 · 정지점 `issue` · `clear` | §5.3 | 맞음 |
| §3 블록 표 L-8 · O-8 · C-8 행 · ③-2 · ④-2 | `l8=PASS 24/24` · `o8=PASS 10/10` · `c8=PASS 10/10` · `=FAIL <k>/n` · exit 1 · `INFO o8 start=<UTC> nonce=<nonce>`(C-8 입력) | §5.4–§5.6 | 맞음 — `<k>`는 PASS 줄 수 · `INFO o8 start=` 줄에는 ` — C-8 입력(…)` 꼬리가 붙는다 |
| §3 ①-2 · ①-5 · ④-1 · ④-3 정지점 | O-10 `probe` · W-7 root 토큰 → `seed` · O-9 `issue` · `clear` | §5.1–§5.3 | 맞음 |
| §3 실패 갈래 ①-5 · ④-1 · ④-2 · ④-3 | W-7 STOP 갈래 · O-9 `o9=STOP …`(클레임 · kubectl 발급 오류 · 파일 쓰기 도중 중단 · clear 도중 중단 · clear 실패) · O-8 「운영자 O-9 필요」 · JWT 만료 · Forwarding 줄 45 s · capabilities-self · C-8 대조 키 | §5.2 · §5.3 · §5.5 · §5.6 | r2에서 런북을 고쳤다(G2 — 결정 §2 ① ②: ④-1 「파일 쓰기 0」에 `o9=STOP 파일 쓰기 도중 중단(…)` 예외(인자 없이 다시 `issue` 또는 `clear`) · 새 갈래 ④-3 `o9=STOP clear 도중 중단(…)` · `o9=STOP clear 실패(…)` → `Test-Path` → clear 한 번 더 → 그래도 남으면 `Remove-Item -LiteralPath` → False 확인 / RO2-01: ④-2 갈래 `STOP Vault port-forward 의 Forwarding 줄(…)을 45 s 안에 얻지 못했다(작업 Running · 출력 없음)` = 터널 경유 수립 지연(환경) / RO2-02: :1239 끝 「창 C가 이미 닫혔으면 ①-1의 창 C 명령으로 다시 열어 …」) — 그 전에는 ④-1 「파일 쓰기 0」이 `파일 쓰기 도중 중단`에 맞지 않았고 ④-3 clear 갈래가 없었다 |
| §3 기록 칸 ④-1 | `INFO aud 꼴=` 줄(VD-T076-10) | §5.3 | 맞음(컨트롤러 보정 5) |
| §4 T076 「사전」 | 관리자 kubeconfig 경로 = 블록 README 「실행 꼴」 | §5.0 | 맞음 — `Join-Path $HOME '.kube\joshuatech-admin.yaml'` · `--kubeconfig` 직접 · `$env:KUBECONFIG` 0 |
| §4 T076 1 · 3 | O-10 · W-7 기대 끝 줄 · 창 정리 안내 | §5.1 · §5.2 | 맞음 · r2: §4 3(:2194)의 창 정리 안내를 「`w7=OK …` · `w7=SKIP live-same`이면 창 C만 닫는다 · `w7=STOP …`이면 닫지 않는다」로 고쳤다(G2 — 결정 §2 RO2-02 · 블록 두 꼴과 같은 뜻) |
| §4 T076 실패 표 | 출력 열 = 끝 줄 꼴(남는 인자 · `cluster_name` · 첫 해석 가림 · dead · 판정 불가 · 쓰기 거부 · 결과 미확인 · 기록됨) | §5.1 · §5.2 | r2에서 런북을 고쳤다(G2 — 결정 §2 ③ ④ ⑤: :2201 출력 열 = 코드 5xx · 200(client_token 없음) · 4xx(auth 객체 있음) · 뜻 = 「거부(4xx · auth 없음)도 통과(client_token)도 아닌 응답 — VD-T076-1 미판정」 · :2200 조치 끝 = 클레임 사유가 `aud 에 vault 가 있다`면 다시 돌리지 않고 멈추고 보고 · :2208 출력 열에 `w7=STOP 쓰기 예정(…)` · :2214 출력 열에 `w7=STOP 기록됨 v1 — 되읽기 검증 전(…)`) — 그 전에는 `로그인 응답 — 코드 5xx` 행만 있었고 W-7 두 꼴이 표 밖이었다(컨트롤러 보정 6 뒤의 남은 틈) |

G2가 결정 밖에서 더한 곳(r2 — V2가 블록 · 결정과 맞는다고 판정 · 줄 번호는 G2 시점): §3 블록 표 W-7 행의 창 정리 두 꼴 · ④-3 행 `o9=STOP …` → 실패 갈래 ④-3 · 세션 끝 `Test-Path` 주석 · ①-2 실패 갈래(`o10=PASS`여도 errors 첫 줄이 audience 거부가 아니면 멈춤) · ①-5 실패 갈래(창 C 유지) · ④-2 Forwarding 갈래의 「괄호가 `작업 Running · 출력 없음`이 아니면 지연이 아니다」 · ③-1 재실행 범위(fetch · rev-parse origin/main · overlays digest 대조) · §3 기록 칸 ⑤ · §4 기록 칸 3 · §4 1(errors 첫 줄 판정은 §3 ①-2를 따른다). 컨트롤러 보정 r2(2026-11-21 — r2 검증): §4 실패 표 W-7 「그 밖」 행의 뜻 · 조치(원인 = 창 정리 줄 **아래**의 pwsh 오류 글자 — V1-04 = V2-01) · 세션 끝 창 C 문장(「아직 열려 있으면 지금 닫는다」 — V2-02) · ④-3 직접 삭제 `Remove-Item -LiteralPath … -Force` · 그래도 남으면 멈추고 보고(V2-03).

## 6. 「노출 0」의 범위(S-08 · S-02)

- **바늘**(두 하네스 같은 규칙 — harness-op `Build-Needles` · harness-tester `Needles-Of`): 비밀 값 하나마다 ① 전체 ② 표준 base64(전체 값의 UTF-8 바이트 — 조각의 base64는 보지 않는다) ③ **8자 이상 조각** = 길이 8 창 전부(8자 이상 조각은 모두 8자 창을 품는다) ④ SHA-256 hex(대 · 소문자 · 전체와 앞 16자). 8자 미만 값에는 바늘이 없다.
  - harness-op 비밀(① – ④): 가짜 root · 틀린 토큰 · Vault 토큰 · 네 토큰의 client_secret · kv에 쓴 값 · put 본문의 값 · JWT 서명 조각 · 사례별 추가 비밀. **전체 일치만**(8자 이상): client_id · JWT 전문 · JWT payload 조각 · 남는 인자 사례의 임의 값.
  - harness-tester 비밀(① – ④): JWT · Vault 토큰 · accessor · client_secret · 쿠키 · admin meta 토큰. **전체 일치만**(6자 이상): client_id · 운영자 IP · UA · ClientHost · ClientAddr · ClientUsername · ServiceAddr.
- **보는 면**:
  - harness-op: 화면(모든 스트림) · 프롬프트 · argv(vault · kubectl · tofu · curl) · 클립보드 · `$Error` · 환경 변수 · **모의 호출 시점 환경 변수**(vault는 `VAULT_TOKEN`만 예외 · kubectl · tofu · curl은 예외 없음) · 새로 생기거나 바뀐 전역 변수 · LOCALAPPDATA 아래 만든 파일의 글자(+ 파일 목록이 기대와 정확히 같다).
  - harness-tester: 화면(모든 스트림) · argv(curl · kubectl) · `$Error` · 환경 변수 · **모의 호출 시점 환경 변수**(curl · kubectl 자식 프로세스 env) · 새로 생기거나 바뀐 전역 변수 · 임시 LOCALAPPDATA의 파일(블록이 만든 새 파일 0 · DPAPI 파일 안 평문 0).
- **범위 밖(받아들인 한계)**: **7자 이하 조각** — 리뷰 R-S 변이 M4(client_secret 앞 7자를 화면에)는 r0 · r1 모두 살아남는다(RS-M4 · 96 / 96 PASS — S-08 「기록만」 · 54자 가운데 7자). 이 범위는 FAIL 사유 문구를 글자까지 단언한 사례로만 일부 잡힌다(T075 README §6과 같은 한계). 전체 일치만 보는 값(client_id · IP · UA 등)의 조각 · 조각의 base64도 범위 밖이다.
- **요청별 사후 조건(harness-tester — S-02)**:
  - **헤더 이름 집합**(stdin 헤더 이름 · argv `-H` 목록을 요청 종류마다 정확히): O-8 m2m 요청 = 정확히 {`CF-Access-Client-Id`, `CF-Access-Client-Secret`, `X-Request-ID`}(가짜 자격 요청도 같은 이름) · Vault seal-status · 로그인 = stdin 헤더 0(로그인 argv `-H`는 `Content-Type: application/json` 하나) · Vault 토큰 요청(capabilities-self · kv · revoke-self) = 정확히 {`X-Vault-Token`} · L-8 = 0 · 그 밖 헤더 0.
  - **자격의 길**(바늘 집합 — 위 ① – ④): client_id · client_secret = O-8 m2m 요청의 그 두 헤더 값에만 · JWT = 로그인 본문의 jwt 값에만(본문 = 정확히 {role: e2e-reader, jwt}) · Vault 토큰 = `X-Vault-Token` 값에만 — URL · argv · 다른 헤더 · 다른 본문 · `--data`에는 0.
  - **ST-O8 호출 꼴**: `& $get` 네 꼴 · `& $vreq` 다섯 꼴의 글자 고정(여분 헤더 · 다른 경로 · 다른 본문 0).
- harness-op의 curl 모의(O-10)도 요청 꼴을 본다: 첫 인자 `-q` · 로그인 본문은 `--data-binary @-`(stdin) · revoke 토큰 헤더는 `-H @-`(stdin) · 둘을 한 호출에 함께 쓰면 위반 · 주소 = `http://127.0.0.1:18200/v1/…`.

## 7. 하네스가 증명하지 못하는 것(라이브에서만 드러난다)

- **실물 kubectl port-forward 출력**: `Forwarding from 127.0.0.1:<n> -> 8200` 꼴은 런북 bootstrap.md 2026-10-22 기록(127.0.0.1:18200을 다른 앱이 쥐자 `Forwarding from [::1]:18200 -> 8200` 한 줄만 나온 실측 — S-04 위협의 선례)과 같은 꼴로 모형화했다 · 연결마다의 `Handling connection for <n>` 줄은 모형이다 · `svc/vault` 대상 포트가 어긋나면 fail-closed STOP(JWT 0).
- **터널 경유 port-forward 수립 10–23 s(T048 F19 · reboot-1 15.7 s) — 모의는 지연을 재현하지 않는다 · 45 s 상한의 여유는 라이브에서만 드러난다**(r2 RO2-01 — O8-19b의 「출력 40회 늦게」는 모의 횟수일 뿐 실시간이 아니고, 모의 `Start-Sleep`은 기다리지 않아 고리가 실시간 `$deadline`에 닿지 않는다 · 두 deadline 값 · 고리 바로 앞 위치 · 대기 간격 500 ms는 ST-O8 정적 단언으로만 지킨다 — 컨트롤러 보정 r2 · V1-01 · V1-02).
- **실물 스레드 작업 안의 kubectl**: `Stop-Job`이 네이티브 자식을 끝내는 것은 ping.exe(B3 · R-O) · python 자식(F3 실물 확인)으로만 쟀다.
- **K3s TokenRequest의 단일 audience 직렬화(VD-T076-10)** — 블록은 두 꼴을 다 받고 관찰한 꼴을 INFO로 낸다(O-9 첫 실행이 잰다) · `kubectl create token` 출력이 정확히 한 줄인지 · 오류 문구.
- **Vault 실응답**: O-10 거부의 실제 코드 · 문구(블록은 「4xx · auth 없음」만 본다 — §8) · curl 기본 Content-Type(form)으로 보낸 JSON 본문을 Vault가 JSON으로 읽는지(O-10 로그인 — B2 추론: Vault 문서의 예가 `curl --data @payload.json`) · 로그인 응답의 policies · lease 꼴 · capabilities-self 응답 꼴 · revoke-self 204.
- **`vault status -format=json`이 unsealed일 때 `cluster_name`을 내는지**(추론 — Vault API SealStatusResponse · T054–T075 모의 꼴 · O-10 · O-8이 HTTP seal-status에서 같은 값을 읽는다). 없으면 W-7은 `w7=STOP 미실행(Vault cluster_name = (없음) — …)`으로 fail-closed 멈추고 ①-5 첫 실행에서 드러난다.
- **Vault kv CLI 거동(W-7)**: `kv metadata get` · `kv get` · `kv put "-cas=0"` 응답 꼴 · `No value found at ` 문구 — 모의는 T075 하네스 모형이다(W-7 헬퍼는 T075 W-2 글자 그대로).
- **Access · Traefik**: Access 실응답(tester-m2m 통과 · 가짜 자격 응답 코드 — VD-T076-8) · `cf-cache-status` 실값(VD-T076-6) · Traefik 404 줄 필드(OriginStatus 0 · RouterName 없음 — F3-14 실측에 맞춘 모형 · VD-T076-2) · Traefik 헤더 필드 이름 대소문자(블록은 `request_Cf-Ray`를 대소문자 무관으로 찾는다) · **X-Request-ID 상류 전달(VD-T076-4)** · cf-ray 대조(VD-T076-5).
- **agent-view RBAC 실물**: get applications · externalsecrets · deployments · jobs · logs · vault ns `pods/portforward`(권한표 기준 모형).
- **DPAPI 실물 파일**: harness-op은 같은 Windows 사용자의 실물 DPAPI로 쓰고 O-8 꼴로 복호했다(R-C도 두 블록 문장을 글자 그대로 옮겨 왕복) — 라이브 창 D에서 O-9가 쓴 파일을 tester 프로세스가 읽는 경로(같은 사용자 · 같은 `LOCALAPPDATA`)는 라이브에서 확인된다.
- **문화권**: 런타임 확인은 th-TH(불기 달력 + 시간 구분자 「.」 — O8-18 · C8-30)뿐이다 · fa-IR · ar-SA 등 다른 달력은 정적 검사(InvariantCulture + 따옴표 리터럴)로만 덮는다 · harness-op은 문화권 런타임 사례 0(정적 가드 — MO25).
- **시간 예산**(O-8 ≈ 565 s — r2 RO2-01 · L-8 ≈ 500 s · C-8 ≈ 140 s)은 추론이다 — 실측 없음.
- 모의 호출 시점 env 검사는 모의를 거치는 호출만 본다(그 밖의 자식 프로세스 길은 정적 관문의 명령 허용 목록 · 절대 경로 실행 파일 0이 막는다) · 7자 이하 조각(§6) · AMSI 메서드 호출 기록(S-11 — §8).

## 8. 남은 위험(라이브 실행 시)

- **AMSI(S-11 · 받아들인 위험 1 범위 · 추론)**: PowerShell AMSI 메서드 호출 기록이 켜져 있으면 .NET 메서드 인자(JWT 꼴 판정 `[regex]::Match` · `.Split` · SHA-256 입력 `GetBytes` 등)가 같은 기계의 AV 공급자에게 넘어갈 수 있다 — 이 PC pwsh 7.6.10 실험 기능 목록에는 없다(정식화인지 제거인지 미확인) · 모듈 로깅 · Transcription 가드는 이 면을 보지 않는다(설계 정정 노트 20).
- **DPAPI 같은 사용자 복호(D16 ①)**: `%LOCALAPPDATA%\jt-e2e\vault-e2e-reader.jwt`는 같은 Windows 사용자로 도는 프로세스(에이전트 포함)가 복호할 수 있다 — vault audience 전용(K8s API 불가) · 1시간 · 정책 두 경로 · 규칙 문장(S-01) · settings deny · 세션 끝 clear로 줄인다. 파일을 지워도 이미 복사된 JWT 사본은 exp까지 유효하다(S-03).
- **S-10은 `CommandType`만 본다**: PATH 앞쪽의 같은 이름 `.cmd` · `.bat`은 Application이라 통과한다 · `-NoProfile` 판정은 하지 않는다(첫 해석 판정은 외부 명령 이름의 함수 · 별칭 가림만 잡는다 — 프로필이 cmdlet 이름(Get-Command · ConvertFrom-Json 등)을 가리는 것은 실행 꼴 `pwsh -NoProfile`과 받아들인 위험 1(같은 사용자)에 기댄다). 실행 파일 위치(저장소 · TEMP · TMP 아래) 판정은 O-8에만 있다(운영자 셋 · C-8 · L-8은 지시 범위 밖).
- **port-forward 고아**: O-8을 돌리는 pwsh가 밖에서 죽으면(Bash 도구 시간 초과 등) `finally`가 돌지 않아 port-forward kubectl이 127.0.0.1 리스너로 남고(agent-view 토큰 만료까지) Vault 토큰은 lease(≤ 3600 s) 동안 살아 있을 수 있다 → Bash 도구 timeout 600000(O-8 최악 ≈ 565 s — Forwarding 줄 기다림 ≤ 45 s · 여유 35 s · 추론 · r2 RO2-01) · 세션 끝 `Get-Process kubectl -ErrorAction SilentlyContinue`(창 C를 닫은 뒤 — 남은 것이 있으면 시작 시각 · 명령 줄 확인 뒤 끝낸다 · 런북 §3 T076 「세션 끝 정리」).
- **migrate Job TTL 기한(추론)**: L-8 ③(Job · 프로브 · `-migrate` 분리 — env마다 3줄)이 읽는 `identity-admin-migrate` Job은 끝난 뒤 `ttlSecondsAfterFinished` 604800 s가 지나면 지워진다 — **dev ≈ 2026-11-26 19:1x KST · prod ≈ 2026-11-27 12:3x KST**. 그 뒤면 `l8=FAIL 18/24`(tick 금지) → 런북 ③-1 사전 확인(agent-view `completionTime` dev · prod) · 없으면 디스패치 전에 사용자 결정(운영자 수동 Sync로 PreSync 재실행 = migrate 재실행 · 라이브 변경 / 또는 편차 + gitops 렌더).
- **UD-16 1회용 전환 결정(`/finish` 전 · 사용자)**: 「1회용」 = 짧은 `--duration`(예: 10–15분 · tester 2차 직전 발급) + 사용 뒤 운영자 clear(S-03). 바꾸면 O-9 `--duration` · O-9 수명 판정(3600 ± 10) · harness-op 기대(ST-O9 `$kargs` 글자 · O9-01 · O9-08 · O9-13 등) · 런북 ④-2 재디스패치 갈래(같은 1시간 안 재시도) · O-9 발급 횟수가 함께 바뀐다(O-8 상한 `exp − iat ≤ 3610`은 더 짧은 수명도 받는다).
- **O-10 PASS의 뜻**: 블록은 「로그인 응답 4xx · auth 없음」을 PASS로 본다 — 거부 사유(audience 불일치인지 본문 꼴 · 다른 오류인지)는 가리지 않는다. 끝 줄의 errors 첫 줄(정제)을 컨트롤러가 보고 VD-T076-1을 판정한다(런북 ①-2 — 컨트롤러는 `o10=` 줄을 본 뒤에만 plan을 확인한다). 5xx · 2xx(토큰 없음) · 4xx + auth 객체는 판정 불가다. O-10 로그인은 Content-Type을 주지 않는다(curl 기본 form — Vault는 Content-Type과 무관하게 본문을 JSON으로 읽는다고 추론 · 미측정 — §7) — 그 탓의 다른 거부 사유도 errors 첫 줄 판정이 걸러낸다(README 작성 우려 5 — 결정 「기록만」).
- **C-8은 VD-T076-4에 걸려 있다**: 상류 `X-Request-ID`가 pod `request_id`로 가지 않으면 c8 pod 두 줄 FAIL → tick 금지 · 사용자 결정(정정 노트 12). O-8과 C-8 사이 identity-admin pod 교체 · Traefik 재시작(UD-13 정비 — 액세스 로그 소실)도 FAIL 원인이다.
- **자격 범위**: e2e-reader 한 토큰이 `authentik/e2e`(T077 시드 뒤)와 tester-m2m을 함께 읽는다(D16 ②) · tester-m2m은 1년 토큰(2027-09-03 만료) — 노출되면 회전(T084를 앞당김 · D16 ③) · settings deny(`Bash(vault *)` · `PowerShell(vault *)`)는 Claude 세션에만 걸린다 — Codex tester는 O-8을 돌리지 않고 SKIP으로 보고한다(D16 ④ · S-06). **T077 · T085 인계(r2 S2-01 · rv2C-02 — 결정 글자)**: T077 · T085: S-01 문장(tester.md · infra.md 「Credentials」 + KR · k8s-security · infra-builder)은 T076 O-8 블록 하나만 지명하고 그 밖 Vault 요청을 무자격 seal-status로 한정한다 — Playwright의 `kv/platform/authentik/e2e` 읽기(T077) · T085 블록은 검토된 블록을 두고 그 블록을 예외에 더하는 문장 개정(UD-15 범위 확장 = 사용자 결정 · approval-review)이 먼저다. D16 인계의 「HTTP API(O-8 꼴) 또는 deny 재결정」만으로는 부족하다(설계 정정 노트 23).
- **VD-T076-1–10**(설계 §5 + 정정 노트 13):

| VD | 무엇 | 어디서 재나 | 어긋나면 |
|---|---|---|---|
| VD-T076-1 | audience 없는 agent-view 토큰은 e2e-reader 로그인이 거부된다 | O-10(창 D · ①-2) | 멈춤 · revoke · 사용자 보고(정책 · 시드 진행 안 함) |
| VD-T076-2 | 404 넷 = Traefik 라우터 없음(OriginStatus 0 · RouterName 없음 · pod 0줄) | C-8 | Ingress · 라우터 조사 · tick 금지 |
| VD-T076-3 | VD-L9: `/healthz` · `/health/` 404(Exact) · `/apix` · `/sessionsX` 403(글자 접두 → pod) | O-8 · C-8 INFO | 계약 · Ingress 재검토 |
| VD-T076-4 | 상류 X-Request-ID가 응답 · pod 로그 `request_id`에 그대로 | O-8 INFO · C-8 pod 판정 | **c8 FAIL → tick 금지 · 사용자 결정**(정정 노트 12 — 설계 표의 「기록만」보다 강하다) |
| VD-T076-5 | 응답 cf-ray = Traefik `request_Cf-Ray` | O-8 ↔ C-8 INFO | 기록만(상관은 nonce로 충분) |
| VD-T076-6 | m2m 호스트 Traefik 404 = D10 기준값 | O-8(판정 b–e · 요청별 INFO ct · cfc) | 기준을 실측 꼴로 정정(정정 노트) |
| VD-T076-7 | 저장소 안 루트에서 템플릿 하네스 전체가 돈다 | tester 1차(D9 ①) | 하네스는 고치지 않는다 · 루트를 저장소 밖으로 옮겨 다시 · 편차 |
| VD-T076-8 | 가짜 서비스 토큰 → Access 응답 코드 | O-8 INFO | 기록만 |
| VD-T076-9 | apply 뒤 capabilities = 설계(tester-m2m read · tester-k8s · metadata deny · prod deny) | O-8 ⑧ | 읽지 않고 멈춤 · 정책 조사 |
| VD-T076-10 | K3s TokenRequest가 단일 audience를 배열(`["vault"]`)로 내는가 문자열(`"vault"`)로 내는가 | O-9 첫 실행 `INFO aud 꼴=` · O-8 `INFO jwt aud 꼴=` | 기록만(블록이 두 꼴을 다 받는다) |
