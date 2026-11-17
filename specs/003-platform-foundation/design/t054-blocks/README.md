# T054 운영자 블록 — DB 자격 kv 6경로 시드 · 모의 하네스 · 남은 위험

빌더 작업(2026-10-14) · 수정 라운드 1(같은 날 — 리뷰 K5 · O1–O5 · O8 반영, §4 「수정 라운드 1」) · 수정 라운드 2(같은 날 — 리뷰 O1–O8 반영, §4 「수정 라운드 2」) · **수정 라운드 4(2026-10-15 — 컨트롤러 결정 C6 · C7 · C8 · C13 + 리뷰 r3 O1–O7 · r4 S1–S4 · O1 · O2 · O3 · O4 반영, §4 「수정 라운드 4」)** · **수정 라운드 6(2026-10-15 — 리뷰 r6 S1–S4 · O1–O5 반영 — r4 O5(정리 ①·② 블록 · §0 절대 규칙 1 의 클립보드 비우기)는 라운드 4 가 아니라 이 라운드에서 반영됐다, §4 「수정 라운드 6」)**. 산출물은 이 디렉터리 3파일과 런북 `docs/runbooks/bootstrap.md` §4 「T054 — DB 자격 시드(kv 6경로 · 랜덤)」 소절, 그리고 `docs/runbooks/vault-unseal.md` §0(C7 — 전사 정책 키 · 모듈 로깅 행 · 수정 라운드 6 — 절대 규칙 1 뒤 클립보드 비우기)뿐이다. **운영자 실행 전** 상태다(라이브 실행 기록 없음 — 실행 기록은 런북 소절 끝에 남긴다).

| 파일 | 역할 |
|---|---|
| `op1-seed-db.ps1` | 운영자 블록(창 D) — 첫 문장 `Set-PSDebug -Off` → 세션 설정 고정(`$WhatIfPreference` · `$ConfirmPreference` · `$PSDefaultParameterValues` — 수정 라운드 4) → 창 전제(클립보드 기록 · 모듈 로깅 정책 · `VAULT_*`) → kv 6경로 판정(읽기 전용) → 쓰기 확인 정지점(`seed`) → `-cas=0` 생성 + JSON 되읽기 SHA-256 대조 + `current_version=1` 확인(put 비 0 은 값 없이 재판정 — 수정 라운드 4) |
| `harness.ps1` | 모의 실행 하네스 — 시나리오 92(시드 블록 68 + 런북 「정리 판단」 두 블록 24: R1 · R2 정적 · GA01–GA08 · GB01–GB12) · 단언 2771 · S12 정적 관문을 맨 먼저(관문 FAIL = 블록 실행 0회) · 실물 `vault`/`kubectl` 차단 가드 3중 · 하네스 프로세스의 `KUBECONFIG` 를 없는 경로로 덮음 · 런북 두 블록은 `bootstrap.md` 코드 펜스에서 그대로 추출(표식 `[t054-cleanup-inspect]` · `[t054-cleanup-delete]`) |
| `README.md` | 이 문서 — 결정 대응 · T045 블록과 다른 점 · 메모리 규칙과의 관계(C6) · 하네스 결과 · 남은 위험 |

실행: `pwsh -NoProfile -File specs/003-platform-foundation/design/t054-blocks/harness.ps1` → `PASS 2771 / 2771`(시나리오 92 / 92, exit 0). 한 시나리오의 화면 출력은 `-Show 'S01'`, 변이 사본에 같은 시나리오를 돌리려면 `-Block <경로>`(시드 블록) · `-Runbook <경로>`(런북 사본 — 「정리 판단」 두 블록을 그 파일의 코드 펜스에서 추출한다).

---

## 1. 컨트롤러 결정(S1–S9) 대응

| ID | 블록에서 한 일 |
|---|---|
| S1 | 6경로 고정 표(경로 · username = PG role · db). 키 = `username` · `password` · `url`. 표 밖 경로는 다루지 않는다 |
| S2 | `[System.Security.Cryptography.RandomNumberGenerator]::GetBytes(32)` → base64url(`+/` → `-_`, `=` 제거) → `\A[A-Za-z0-9_-]{43}\z` 확인. 경로마다 독립 생성 · 쓰기 직전에 만든다 · 원본 바이트 배열은 `[Array]::Clear` |
| S3 | `url = postgresql://<username>:<password>@pg-main-rw.data.svc:5432/<db>?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt` — 문자열 이어 붙이기(보간 없음 — `"$k:"` 파스 함정 회피) |
| S4 | 창 C port-forward 전제 · 블록 안 `VAULT_ADDR=http://127.0.0.1:18200` · `vault status -format=json`(토큰 없이 도달 · 초기화 · unseal 판정) · root 토큰은 `Read-Host -AsSecureString` + 붙여넣은 직후 클립보드 비움(비우기가 실패하면 값 없는 경고 — finally 의 비우기도 같다 · 수정 라운드 2) · 클립보드 기록 점검과 **PowerShell 모듈 로깅 정책 점검**은 블록 첫 검사(토큰을 묻기 전) · PSReadLine 확인은 머리 주석 ⑤(블록 밖 1줄) |
| S5 | **판정 단계**(6경로 `kv metadata get` → live 면 `kv get` 으로 모양 판정 — 값은 출력하지 않는다) → STOP 이 하나라도 있으면 쓰기 0 으로 throw → **쓰기 확인 정지점**(쓸 경로 목록만 · 값은 아직 만들지도 않았다) → **쓰기 단계**. absent → 생성 / live-ok → SKIP / live-mismatch · dead · 판정 불가 → STOP |
| S6 | 쓰기 뒤 `vault kv get -format=json` 으로만 되읽어 세 키를 SHA-256 Ordinal 비교(값 · 해시 미출력) + `kv metadata get` 으로 `current_version=1` · 삭제/파기 없음 확인(마운트 `delete_version_after` 의 삭제 예약도 여기서 잡는다 — 하네스 S20a·b). 실패하면 STOP 줄 + throw — 다음 경로로 가지 않는다 |
| S7 | 경로별 `OK   … v1 — 생성 · 되읽기 해시 일치(username·password·url)` / `SKIP … live-ok(…)` / `STOP … — <사유>` + finally 요약 표(put 도중 중단 · put 비 0 뒤 재판정 불가는 `결과 미확인` · 응답 유실 뒤 재판정으로 검증된 경로는 `기록됨(응답 유실 — 이 실행의 값 …)` — 집계 줄에 따로 센다) · 쓴 경로 수 · 판정 줄 · 창 종료 체크리스트. **출력은 전부 `Write-Host`/`Write-Warning`**(성공 스트림 0) · 호스트 UI 직접 쓰기 0(S12) |
| S8 | 파일 첫 줄 `& {` · 전체가 한 문 · 빈 줄 0 · 끝 `}` + LF 1개(끝 3바이트 `0A 7D 0A`) · BOM/CR 0 · 본문 첫 문장 `Set-PSDebug -Off`(수정 라운드 2) · 정지점마다 `FlushInputBuffer()`(Read-Host 바로 앞 직계 문장 — 하네스가 AST 로 고정) + 단어(Ordinal — 대소문자 구분) · `seed` 입력은 `-MaskInput`(가려진다) |
| S9 | 6경로 시드만 한다(쓰기 명령은 `vault kv put "-cas=0" <path> -` 하나뿐 — delete · destroy · patch · metadata put 없음). ALTER ROLE 세션 기본값은 gitops PostSync Job 몫이고, 수동 대체 절차는 런북 소절에만 있다 |

### 원칙 (a)–(h)(블록 머리 주석과 같다)

(a) 사람 동작마다 정지점 — 입력 버퍼를 비운 뒤 단어 입력 · (b) 판정(읽기 전용)과 쓰기를 단계로 분리 · (c) 쓰기는 `-cas=0` + JSON stdin 뿐(live 판정 + CAS 이중으로 덮어쓰기 차단) · (d) 되읽기는 JSON + SHA-256 + `current_version=1`, 실패하면 다음 경로로 가지 않는다 · (e) 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드 · 전사에 나오지 않는다 · (f) 생성 값의 유일한 사본은 kv — 메모리 값은 되읽기 대조 뒤 버린다. **put 이 비 0 으로 끝나도 "쓰지 않았다"고 단정하지 않는다**(수정 라운드 4 · 리뷰 r3 O6): 응답 유실 뒤 CLI 자동 재시도(`VAULT_MAX_RETRIES` 기본 2)가 자기 기록과 CAS 충돌하면 서버에는 이 실행의 값이 v1 로 있는데 종료 코드 · 문구는 진짜 충돌과 같다 → 값을 출력하지 않고 다시 판정한다(absent = 쓰지 않았다 · live v1 + 되읽기 해시 일치 = `기록됨(응답 유실 — 이 실행의 값)` 으로 계속 · 다르면 CAS 충돌 STOP · 재판정 불가 = `결과 미확인`). 어느 분기도 메모리 값을 kv 밖에 두지 않으므로 T044 사고 유형 "저장 전 유일 사본 소거"는 생기지 않는다 · (g) 정리는 조건부 — 블록이 만든 `VAULT_TOKEN` 만 지우고, 시작 전에 있던 `VAULT_*` 는 건드리지 않은 채 중단 · (h) finally 가 성공 · 실패 · 중지 어느 쪽이든 env(`VAULT_TOKEN` 이 첫 문장) · 비밀 변수 · 클립보드 · `$Error`(이 실행분)를 먼저 정리하고 요약을 낸다(put 도중 중단 · 재판정 불가는 `결과 미확인`). 세션의 `$WhatIfPreference` · `$ConfirmPreference` · `$PSDefaultParameterValues`(-WhatIf)가 이 정리를 조용히 건너뛰게 하지 못하도록 블록 범위에서 셋을 고정한다(수정 라운드 4 · 리뷰 r3 O5).

---

## 2. T045 v2 블록(`../t045-blocks/op1-seed.ps1`)과 다른 점 — 의도

1. **kubectl 을 쓰지 않는다.** T045 는 라이브 K8s Secret 을 파이프 복사했지만 T054 는 값을 블록이 만든다 → 창 D 에 관리자 kubeconfig 가 필요 없다. 하네스는 `kubectl` 호출 자체를 위반으로 센다.
2. **VD-6 프로브 경로(`kv/platform/_probe`) 쓰기 · 삭제가 없다.** S9(6경로만)에 따라 JSON stdin 형식 실측은 T045 블록의 실측(2026-09-21, CLI v2.1.0)에 기대고, 블록은 시작할 때 `vault version` 줄을 `INFO` 로 남긴다. CLI 동작이 바뀌었다면 첫 경로의 되읽기 대조가 잡는다(§5 의 4).
3. **판정과 쓰기를 단계로 나눴다.** T045 는 경로마다 판정 → 쓰기를 섞었다. T054 는 6경로를 전부 판정한 뒤 문제가 하나라도 있으면 쓰기 0 으로 끝나고, 쓰기 직전 정지점 하나에서 쓸 경로 목록을 보여 준다.
4. **`No value found` 만 absent 다.** T045 `$state` 는 비 0 종료를 전부 absent 로 봤다(CAS 만이 안전망). T054 는 stderr 가 `No value found at …` 일 때만 absent, 그 밖의 비 0 은 **판정 불가 → 쓰기 0**(T045 → T084 인계 항목 "`No value found`와 조회 실패의 문면 구분"을 여기서 반영). CAS 안전망은 그대로 남아 "일시적으로 `No value found` 가 나온 실재 경로"(S08a)를 막는다.
5. **live 경로는 원본 대조가 아니라 모양으로 판정한다.** 값이 랜덤이라 대조할 원본이 없다 → 키 집합 · 문자열 · username · password 길이 ≥ 32 · URL 비예약 문자 · `url = 접두 + password + 접미` 를 값 출력 없이 본다.
6. **조건부 정리.** T045 는 finally 에서 `VAULT_TOKEN`·`VAULT_ADDR` 를 무조건 지웠다. T054 는 시작 전에 `VAULT_*`(기대값의 `VAULT_ADDR` 제외)가 있으면 아무것도 묻지 않고 중단하고 그 변수를 건드리지 않는다. 블록이 만든 것만 지운다(`$tokenOwned` · `$addrOwned`).
7. **`$Error` 정리.** 이 실행이 `$Error` 에 남긴 기록만 지운다(시작 시점의 맨 앞 기록을 기준점으로). `ConvertFrom-Json` 오류 문구는 값이 아니라 키 경로 · 위치만 싣는다는 것도 실측했다(2026-10-14) — 이중 방어다.
8. **성공 스트림 0.** T045 는 OK 줄을 성공 스트림으로 냈다. T054 는 전부 `Write-Host` — 돌려받지 않은 반환값(예: 비밀번호)이 화면에 찍히는 경로 자체를 없앴고, 하네스가 모든 시나리오에서 성공 스트림 0 을 단언한다.
9. **토큰 형식을 먼저 본다.** 붙여 넣은 값이 `hvs.` 로 시작하는 공백 없는 ASCII 가 아니면 Vault 로 보내지 않고 중단(복구 키 조각을 잘못 붙인 경우). `hvs.` 접두는 검증 전 가정이다(§5 의 8 — VD).
10. **도달 확인은 `vault status -format=json`(S4).** T045 는 `curl.exe … /v1/sys/seal-status` 였다. `initialized` · `sealed` 를 **bool 형식으로만** 받아들인다(문자열 `"false"` 는 해석 실패).
11. **`Set-StrictMode -Version 3.0` + `$PSNativeCommandUseErrorActionPreference = $false` 명시**, PowerShell 7.5 미만이면 시작 전 중단(`ConvertFrom-Json -DateKind` 필요).
12. **머리 주석이 `& {` 안에 있다** — 파일 첫 줄이 `& {` 다(S8 · 하네스 S12).
13. **PowerShell 모듈 로깅 정책을 본다(수정 라운드 1 · 리뷰 O5).** 블록은 `ConvertFrom-Json` 에 kv get 응답(password · url)과 token lookup 응답(`data.id` = root 토큰)을 문자열로 넘긴다 — 모듈 로깅이 켜져 있으면 이벤트 4103 ParameterBinding 에 그 원문이 남는다. 토큰을 묻기 전에 `HKLM`/`HKCU:\SOFTWARE\Policies\Microsoft\PowerShellCore\ModuleLogging` 의 `EnableModuleLogging` 을 보고, 그 키의 `UseWindowsPowerShellPolicySetting` 이 1 이면 Windows PowerShell 쪽 두 키도 본다. 하나라도 1 이면 중단(T045 블록 · `vault-unseal.md` §0 체크리스트에는 없던 검사).
14. **`seed` 정지점은 `-MaskInput`(리뷰 O3).** 토큰이 들어갔는지 불안해 PM 의 값을 두 번째 프롬프트에 다시 붙여도 화면 · 스크롤백에 남지 않는다(그 입력은 중단으로 끝난다). T045 의 단어 정지점은 평문 `Read-Host` 였다.
15. **finally 첫 두 문장 = 블록이 만든 `VAULT_TOKEN` · `VAULT_ADDR` 제거(리뷰 O4-a).** T045 와 라운드 0 은 `Remove-Variable` 뒤에 env 를 지웠다 — 붙여넣기 실행 중 Ctrl+C 를 거듭 눌러 finally 가 끊기면 root 토큰이 세션 env 에 남을 수 있었다.
16. **요약의 `결과 미확인` 범주(리뷰 O4-b).** put 직전에 그 경로의 요약을 `결과 미확인(put 진행 중 중단 — kv 에 v1 이 있을 수 있다 · 재실행이 판정한다)` 으로 바꿔 둔다 — put 도중 중지되면 서버는 이미 커밋했을 수 있는데 요약(런북 실행 기록에 옮겨 적는 영구 기록)이 "쓰지 않았다" 로 남던 문제. 집계 줄에 `결과 미확인 N` 이 생겼다.
17. **`INFO vault CLI` 줄에 명령 종류 · 경로(리뷰 O5).** `Get-Command vault` 의 `CommandType` 과 `Source` 를 남긴다(사용자 프로필 경로는 `~` 로 줄인다 — 실행 기록에 옮겨 적어도 계정 이름이 남지 않는다). 종류가 `Application` 이 아니면 함수 · 별칭이 `vault` 를 가리고 있다는 뜻이다 — 런북은 이 확인을 **root 토큰을 붙이기 전**(실행 절)에 둔다(수정 라운드 2 · 리뷰 O6).
18. **본문 첫 문장 = `Set-PSDebug -Off`(수정 라운드 2 · 리뷰 O6).** 붙여넣기 창에 `Set-PSDebug -Trace 2` 가 켜져 있으면 뒤의 모든 대입이 값과 함께 화면 · 스크롤백에 찍힌다. 실측(2026-10-14 · pwsh 7.6.6 · 값을 소스가 아닌 env 에서 읽는 모양): 대조군 `& { $tok = …; $x = $tok }` → `디버그:     ! SET $tok = 'MOCK-…'` · `! SET $x = 'MOCK-…'` 2줄 / 첫 문장 `Set-PSDebug -Off` → 추적이 그 문장에서 멈추고 값 줄 0. `Set-PSDebug` 는 세션 전체 설정이라 블록 안에서 꺼도 창 전체가 꺼진다. 부수 효과: `-Off` 는 **전역 strict 모드도 끈다**(같은 날 실측 — 자식 범위에서 불러도 전역이 꺼진다) → 붙여넣기 실행 뒤 그 창의 strict 모드가 꺼진다(블록 자신은 다음 문장에서 `Set-StrictMode -Version 3.0` 을 다시 건다 · 창은 끝나면 닫는다). 프로필이 정의한 함수 · 별칭 · 중단점은 블록이 막지 못한다 — 붙여넣기는 `pwsh -NoProfile` 로 새로 연 창에서만(런북 사전 5).
19. **클립보드 비우기 실패를 경고한다(수정 라운드 2 · 리뷰 O5).** 라운드 1 까지는 `try { Set-Clipboard -Value ' ' } catch { }` 로 실패를 삼켰다 — 다른 프로세스(`rdpclip` · 클립보드 관리자)가 클립보드를 잡고 있으면 root 토큰이 남는데 화면 어디에도 표시가 없었다. 이제 두 곳(토큰 입력 직후 · finally) 모두 `Write-Warning`(값 없음 — "PM 의 클립보드 지우기 또는 아무 텍스트 복사로 직접 비운다")을 낸다. 시드는 계속한다(멈춰도 클립보드의 토큰은 사라지지 않는다). 경고가 세션 설정으로 숨거나(`SilentlyContinue`) 예외가 되어 finally 를 끊지(`Stop`) 않도록 블록 범위에서 `$WarningPreference = 'Continue'` 로 고정한다.
20. **판정 단계의 kv get 응답 해석 실패 = 판정 불가(수정 라운드 2 · 리뷰 O4).** 라운드 1 은 JSON 해석 실패와 `data.data` 없음을 한 분기로 묶어 live-mismatch 로 보냈다 — 런북의 live-mismatch 조치는 되돌릴 수 없는 「정리 판단」이다. 이제 해석 실패는 `kind=error`(`kv get 응답을 해석하지 못했다(원문 미출력)` → `판정 불가` → 조치 = 재실행)이고, `data.data` 없음 · 객체 아님만 live-mismatch(`현재 버전에 데이터가 없다(…)`)다. 쓰기 경로의 같은 해석 실패가 "되읽기 실패 → 재실행이 복구" 인 것과 맞췄다.
21. **되읽기 키 집합 STOP 문구에 `누락: 없음`(수정 라운드 2 · 부수 정리).** 여분 키만 있을 때 라운드 1 은 `누락:  · 여분 1개`(빈 목록)를 냈다 — 판정 단계와 같은 표기로 맞췄다(하네스 S09e 가 고정).
22. **세션 설정 고정 `$WhatIfPreference = $false` · `$ConfirmPreference = 'High'` · `$PSDefaultParameterValues = @{}`(수정 라운드 4 · 리뷰 r3 O5 · 결정 C8).** 붙여넣기 창의 `$WhatIfPreference = $true`(또는 `$PSDefaultParameterValues['Set-Clipboard:WhatIf'] = $true`)는 finally 의 `Remove-Item Env:VAULT_TOKEN` 과 두 번의 `Set-Clipboard` 를 **예외 · 경고 없이** 건너뛰게 한다 — 'What if:' 한 줄은 호스트 UI 로 나가 `*>&1` 에도 잡히지 않는다(하네스 S10e 의 red 실측: 블록 고정 전에는 `VAULT_TOKEN` 이 env 에 남고 클립보드 쓰기 0 · `What if:` 18줄이 콘솔로). `$ConfirmPreference` Low/Medium 이면 finally 안에서 확인 프롬프트가 뜬다. 셋을 try 앞의 직계 문장으로 블록 범위에만 고정한다(자식 범위의 preference 변수는 그 범위와 자식에서만 유효 — 2026-10-15 실측: 전역 WhatIf = $true 인 세션에서 블록 안 `Remove-Item Env:` 가 실제로 지워지고, 바깥 전역 값은 그대로다). `-File` 권장 실행(새 프로세스)은 원래 면역이다. S12 가 세 문장의 존재를, S10e 가 동작을 고정한다.
23. **put 비 0 의 재판정(수정 라운드 4 · 리뷰 r3 O6 · 결정 C8).** 라운드 3 까지는 put 비 0 을 `중단(put 거부 … -cas=0 이라 덮어쓰지 않았다)` 로만 기록했다 — "덮어쓰지 않았다"는 참이지만 "쓰지 않았다"는 보장이 아니다(Vault CLI 는 연결 오류 · 5xx 를 자동 재시도하므로 port-forward 순단이 서버 커밋 뒤에 오면 재시도가 자기 기록과 `check-and-set parameter did not match` 로 충돌한다 — 진짜 충돌과 exit 2 · 문구가 같다). 이제 put 비 0 직후 `$state` 로 다시 판정한다: **absent** → `중단(put 거부 exit=N — 재판정 absent · 쓰지 않았다)`(S16) / **live v1** → 평소의 되읽기로 흘러가 해시가 일치하면 `OK … 기록됨(응답 유실 — 이 실행의 값 · put exit=N 뒤 재판정) · 되읽기 해시 일치(…)` 로 **다음 경로로 계속**하고 집계에 `응답 유실 뒤 재판정으로 검증 완료 N` 으로 따로 센다(S16d), 해시 · 키 집합이 다르면 `STOP … put 거부(exit=N) · CAS 충돌(다른 값)` · `중단(… = CAS 충돌 · 덮어쓰지 않았다)`(S08a — 판정 단계의 일시 `No value found` 오판이 이 경로다) / **그 밖(error · dead · cv≠1)** → `결과 미확인(put exit=N — 재판정 <종류> …)` 로 STOP(S16e — 지우지 말고 재실행). 요약 범주와 런북 실패 표 세 행(`재판정 absent` · `CAS 충돌(다른 값)` · `기록됨(응답 유실 …)`)이 같이 바뀌었다.

### 메모리 규칙 「판정과 변경을 한 블록에 섞지 않는다」와 이 블록(컨트롤러 결정 C6 · 2026-10-14)

- 규칙(2026-09-22 · T045 사고)이 겨냥한 실패는 **운영자가 옮겨 적는 문자열(또는 사람의 기억)로 실행 사이의 안전 상태를 잇는 설계**다 — 판정 블록의 출력을 보고 운영자가 "안전하다"고 판단한 뒤 변경 블록에 그 판단을 입력으로 넣으면, 그 사이에 바뀐 상태 · 옮겨 적기 실수가 변경에 그대로 들어간다.
- 시드 블록(`op1-seed-db.ps1`)은 **운영자 판단 단계가 아니라 쓰기 보호 가드**다(T045 v2 `../t045-blocks/op1-seed.ps1` 과 같은 구조): ① **실행 간 상태 인계 없음** — 블록 안의 판정(`kv metadata get` → live 면 `kv get` 모양 판정)은 같은 실행 안에서 즉시 쓰기 조건으로만 쓰이고, 운영자가 그 결과를 어디에도 옮겨 적지 않는다(재실행은 Vault 상태에서 판정을 다시 도출한다). ② **쓰기 전 단어 정지점** — 쓰기 직전에 쓸 경로 목록(값 없음)을 보이고 `seed` 를 요구하므로 운영자의 유일한 결정은 "이 경로들에 새 값을 만들어 넣는다/않는다" 이고, 그 결정은 되돌릴 수 있다(absent 경로에 새 값을 넣는 것 — 머지 전이면 「정리 판단」으로 지울 수 있다). ③ **`-cas=0` 이중 방어** — 판정이 틀려도(일시 `No value found` 오판 · S08a) 서버의 CAS 가 덮어쓰기를 거부하므로 판정 → 쓰기 사이의 상태 변화가 데이터를 깨뜨리는 경로가 없다. 즉 블록 안의 판정은 **운영자에게 판단을 묻는 단계가 아니라 쓰기를 막는 조건**이다 — 규칙이 금지하는 "판정 블록 → 사람 → 변경 블록" 의 인계가 생기지 않는다.
- 반대로 런북의 **「정리 판단」(`kv metadata delete` — 되돌릴 수 없다)은 운영자 판단이 들어가는 변경**이다(어느 경로가 "이 블록의 실패한 실행이 만든 것"인지는 사람이 판단한다). 그래서 규칙대로 **① 읽기 전용 점검 블록**(vault 쓰기 명령 0 · 상태 · 버전 이력 · 키 이름만)과 **② 삭제 블록**(6경로 허용 목록 Ordinal · 지울 경로를 다시 그대로 타자 · 삭제 뒤 `No value found` 확인 · 조회/삭제 실패 · 잔존 · 삭제 뒤 조회 오류 = 중단)으로 나눴다(수정 라운드 4 · 리뷰 r3 O7). 두 블록은 저장소 하네스가 런북 코드 펜스에서 그대로 추출해 시험한다(R1 · R2 · GA · GB).

---

## 3. 붙여넣기 · 중지 안전성

- 전체가 최상위 문장 1개(`& { … }`) — PSReadLine 이 중괄호가 닫힐 때까지 입력을 모아 한 번에 파싱 · 실행한다. 빈 줄 0(기본 콘솔 호스트의 빈 줄 종료 대비) · 끝 `}` + LF 1개(남는 문자가 첫 `Read-Host` 로 흘러들지 않는다).
- 정지점 2개뿐: ① root 토큰(보안 입력 — 빈 입력 = 중단) ② `seed`(쓰기 확인 — 입력은 `-MaskInput` 으로 가려진다 · 쓸 경로가 0 이면 나오지 않는다). 둘 다 직전에 `$Host.UI.RawUI.FlushInputBuffer()`. `seed` 는 Ordinal 정확 일치(앞뒤 공백 · 빈 Enter · 다른 단어 · 대문자 `SEED` = 중단 — S06a–d).
- 권장 실행은 `pwsh -NoProfile -File '<절대 경로>'` — 새 프로세스라 env · 변수 · `$Error` 가 프로세스와 함께 사라지고 프로필(함수 · 별칭 · `Set-PSDebug` · 중단점)이 없다. 붙여넣기는 `pwsh -NoProfile` 로 **새로 연 창에서만** 안전하다(위 규약 + 첫 문장 `Set-PSDebug -Off` — 프로필이 정의한 함수 · 별칭 · 중단점은 블록이 막지 못한다 · 수정 라운드 2).
- **중지(Ctrl+C) 모의 실측(2026-10-14 · pwsh 7.6.6)**: 별도 runspace 에서 `PowerShell.Stop()`(Ctrl+C 와 같은 파이프라인 중지 경로)으로 `try { Start-Sleep }` 를 끊었을 때 finally 의 `Remove-Variable` · `Remove-Item Env:` · `Test-Path` 조건 · `ForEach-Object` · `Write-Host` 와 성공 출력 뒤 문장까지 **전부 실행**됐다(env 2개 제거 확인). 그래도 정리(자격 · 변수 · 클립보드 · `$Error`)를 요약보다 앞에 두고, 그중에서도 **블록이 만든 `VAULT_TOKEN` · `VAULT_ADDR` 제거를 finally 의 첫 두 문장**으로 둔다(수정 라운드 1 — 하네스 S12 가 문장 순서를 단언). env 제거에는 출력하는 명령을 쓰지 않는다(`if ($tokenOwned) { Remove-Item … -ErrorAction SilentlyContinue }`). put 도중 중지되면 그 경로의 요약은 `결과 미확인` 이다(S21a — 모의 put 이 커밋 뒤 예외를 던지는 것으로 대신 시험). 콘솔 Ctrl+C 자체는 모의할 수 없다(§5 의 5).

---

## 4. 하네스(`harness.ps1`)

### 모의 방식 · 가드

- PowerShell **함수가 native 명령보다 우선**하는 성질로 `vault`·`kubectl`(+ `vault.exe`·`kubectl.exe`·`curl`·`curl.exe`·`oci`·`gh`)을 가리고, `Read-Host`(`-AsSecureString` · `-MaskInput` 여부를 기록)·`Set-Clipboard`·`Get-Clipboard`·`Get-ItemProperty`(클립보드 기록 설정 + 모듈 로깅 정책 키 4개 — 값은 시나리오가 정한다)·`Test-Path`(`~/.vault-token`)·`Set-PSDebug`(`-Off` 만 이벤트 · 그 밖의 인자는 위반 — 실물을 부르지 않아 하네스 프로세스의 strict 설정을 건드리지 않는다)를 모의한다. 하네스는 실제 클립보드 · 레지스트리 · `~/.vault-token` 을 건드리지 않는다.
- **S12 정적 관문이 맨 먼저(수정 라운드 2 · 리뷰 O8)**: 가드 ①②는 함수 가림 + PATH 함정이라 **절대 경로 실행 파일 호출(`& 'C:\…\kubectl.exe'`) · 프로세스 직접 기동은 막지 못한다**. 라운드 1 은 S12(명령 · 형식 허용 목록)를 S01–S11f(런타임 시나리오 38개 — S08e 의 사전 실행까지 블록 실행 39번) **뒤**에 돌렸고 관문도 없어, 그런 블록이면 S12 가 잡기 전에 39번, 뒤의 16개까지 모두 56번 실행됐다(재현: 아래 「수정 라운드 2」 K1 · K5). 이제 S12 를 블록 실행 전에 돌리고, 관문 단언 5개(파서 오류 0 · 명령 · 정적 .NET 형식 · `$Host` · 파일 리다이렉트 허용 목록 — `$GateCount`)가 전부 있고 PASS 일 때만 런타임 시나리오를 돌린다. 하나라도 FAIL(또는 빠짐)이면 `관문 FAIL(S12): …` 를 내고 **블록을 한 번도 실행하지 않은 채** exit 1 이다. 관문 4종은 최상위가 `& { … }` 가 아니어도 파일 전체 AST 에서 잰다(라운드 1 은 그때 일찍 return 해 허용 목록 검사가 빠졌다).
- **실물 차단 가드 3중**: ① 위 함수 가림(+ `Set-PSDebug`) ② 실물 `vault`·`kubectl` 이 있는 디렉터리를 하네스 프로세스 PATH 에서 빼고 맨 앞에 함정 디렉터리(`vault.cmd`·`kubectl.cmd` — 불리면 표식 파일 + exit 97)를 둔다 · **하네스 프로세스의 `KUBECONFIG` 를 함정 디렉터리 안의 없는 경로로 덮는다**(운영자의 관리자 kubeconfig 를 상속하지 않는다 — 끝나면 원래 값으로, 없었으면 없음으로 되돌린다 · 수정 라운드 2) ③ 블록을 돌리기 직전마다 ①②(KUBECONFIG 포함)를 다시 확인(아니면 블록을 돌리지 않고 중단)하고 시나리오마다 "함정 표식 0" 을 단언한다. 함정 디렉터리는 끝나면 지운다.
- 가짜 Vault = 메모리 kv v2(경로 → 버전 · 메타데이터 · soft-delete/destroy · CAS). 모의 `vault` 는 **허용 목록**(`version` · `status` · `token lookup` · `kv metadata get` · `kv get` · `kv put`)만 답하고, 그 밖(delete · destroy · patch · `-field` · argv `k=v` · put 이 아닌 호출의 stdin)은 위반으로 기록한다. 플래그가 경로 뒤에 오면 실물 CLI 처럼 형식 위반이다. 실물처럼 `token lookup` 응답의 `data.id` 에 토큰 평문을 넣어 둔다(블록이 응답을 출력하면 노출 검사가 잡는다).
- **일시 상태(transient) 모의**: `metadata get` 의 거짓 `No value found` · 빈 응답(비 0 · 오류 문구 없음) · 500 오류, 되읽기 실패 · 깨진 JSON(안에 비밀번호 — 쓰기 뒤 되읽기와 **판정 단계** 둘 다), **저장 때 값 변형(키 지정형 `tamper` — `password` · `username` 마지막 글자 / `url` 비밀번호 부분 첫 글자 / `dropKey` url 키 제거 / `extraKey` 키 `note` 추가 · 수정 라운드 2)**, `status` 가 unsealed JSON 인데 exit 1(`okrc1`), **클립보드 비우기 실패(`clipFail` — 쓰려던 값을 기록한 뒤 예외)**, put 거부, **put 성공 뒤의 metadata 응답만 바꾸기**(`postMeta` — `cv2` = 다른 기록자의 v2 · `deletion` = 마운트 `delete_version_after` 의 삭제 예약), **put 도중 중단**(`putInterrupt` — 서버에 커밋한 뒤 예외를 던져 Ctrl+C 를 대신한다).
- **수정 라운드 4 의 모의 추가**: `putLost`(서버는 커밋했는데 CLI 자동 재시도가 자기 기록과 CAS 충돌 — exit 2 · 진짜 충돌과 같은 문구) · `postMeta 'err'`(그 경로에 put 이 한 번이라도 불린 뒤의 metadata 조회만 500 — 판정 단계는 정상) · `kv metadata delete`(런북 ② 삭제 블록 시나리오 `$AllowDelete` 에서만 답한다 — 시드 블록 · ① 점검 블록이 부르면 위반; 결함 `delFail` 권한 거부 · `delNoop` exit 0 인데 지우지 않음 · `postDelErr` 지운 뒤 조회만 500) · 모의 `Set-Clipboard` 가 실물처럼 `SupportsShouldProcess` 를 따른다(세션 `$WhatIfPreference` · `$PSDefaultParameterValues` 의 -WhatIf 가 살아 있으면 쓰지 않고 `clip:whatif` 이벤트만) · 모의 `Read-Host` 가 호출 시점까지 화면에 나온 출력 수를 남긴다(INFO 줄 순서 단언).
- **런북 두 블록의 추출**: `docs/runbooks/bootstrap.md`(또는 `-Runbook <사본>`)에서 표식 주석(`[t054-cleanup-inspect]` · `[t054-cleanup-delete]`)이 든 ```` ```powershell ```` 코드 펜스를 정확히 하나씩 찾아 펜스 들여쓰기를 뗀 본문을 `[scriptblock]::Create` 로 그대로 돌린다 — 운영자가 붙여 넣는 텍스트와 하네스가 시험하는 텍스트가 같다. 런북 블록의 공통 사후 조건은 시드 블록과 다르다(`Run-RbCase`): 창의 `VAULT_ADDR` · `VAULT_TOKEN` 은 하네스가 넣어 두고 블록이 건드리지 않았는지 본다 · Read-Host 는 평문(경로 · 재입력 — 비밀 아님) · `kv put` 0 · ① 점검 블록은 `kv metadata delete` 0 · 성공 스트림 0 · 노출 0(저장된 값 · 6경로 밖 소비 중 경로의 가짜 터널 토큰 · root 토큰) · **첫 Read-Host 전 클립보드 비움**(모의 `Set-Clipboard` 의 `clip:set` 이 모의 `Read-Host` 의 `read:plain` 보다 앞 · 기록된 값은 공백만 — 수정 라운드 6 · 리뷰 r6 S1: §0 절대 규칙 1 로 붙인 root 토큰이 클립보드에 남은 채 평문 프롬프트에 오붙임되는 경로를 막는다).
- 가짜 값은 전부 `MOCK` 이 들어간 누가 봐도 가짜인 문자열이고 이 하네스 파일에만 있다(블록 파일의 `MOCK` 0 은 S12 가 · 런북 두 블록의 `MOCK` 0 은 R1 · R2 가 검사).

### 모든 시나리오의 공통 사후 조건

1. **비밀 노출 0** — 바늘 = 가짜 Vault 에 저장된 모든 password(전체 · base64 · **8자 조각 전부**) · url(전체 + 그 안의 비밀번호 부분) + 블록이 put stdin 으로 보낸 값(거부 · 변형 전 값 포함) + 가짜 root 토큰 · 사전 env 토큰 · 복구 키 조각, 그리고 이 모든 비밀 · url 의 **SHA-256 hex(대문자 · 소문자 전체 + 앞 16자)**(수정 라운드 1 — 브리프 S6 "해시 출력 금지"). 면 = 화면(정보 · 경고 · 오류 · 성공 스트림 전부 — `*>&1`) · `Read-Host` 프롬프트 · 모의 명령 argv · 클립보드 기록 · `$Error`(메시지 · 예외 전문 · TargetObject) · 이 시나리오에서 생기거나 바뀐 전역 변수 · 환경 변수. **호스트 UI 직접 쓰기(`$Host.UI.WriteLine` 등)는 이 면들에 잡히지 않는다** — S12 정적 규칙이 막는다(§5 의 7).
2. `VAULT_TOKEN`·`VAULT_ADDR` 없음(시작 전에 있던 경우는 "건드리지 않음").
3. 위반 0 · 함정 표식 0 · **성공 스트림 0** · 클립보드에는 공백만 · 비밀 입력은 전부 `-AsSecureString` · **입력은 전부 가려진다**(비밀 = `-AsSecureString` · 정지점 단어 = `-MaskInput`) · `kv put` 은 전부 `-cas=0` + stdin · `seed` 정지점 전 put 0 · finally 요약 · 창 종료 체크리스트 출력 · **첫 동작 = `Set-PSDebug -Off` 1회**(모의 — `-Off` 밖의 인자는 위반 · 수정 라운드 2) · **root 토큰 프롬프트까지 간 시나리오는 `INFO vault CLI` 줄이 그 프롬프트보다 먼저 화면에 나온다**(수정 라운드 4 · 리뷰 r3 O2 — 런북의 "토큰을 붙이기 전에 종류가 Application 인지 본다"가 이 순서에 기댄다 · 변이 mB 는 51 시나리오에서 FAIL) · (완주 시나리오) 입력 전부 소비(정지점 누락 없음).

### 시나리오와 결과(2026-10-15 수정 라운드 6 · `PASS 2771 / 2771` · 시나리오 92 / 92 — 실행 순서는 S12 가 맨 먼저 · 런북 블록 R1 · R2 → GA · GB 는 맨 뒤)

| id | 시나리오(브리프 §3 번호) | 결과 |
|---|---|---|
| S01 | (1) 6경로 absent → 6개 생성 · v1 · 키 3 · username = role · password base64url 43자 · url 구성 · url 의 비밀번호 = password · 6개 고유 · 판정 → 정지점 → 경로마다 put → 되읽기 → metadata 순서 · `seed` 정지점 `-MaskInput` · `INFO` 줄에 명령 종류 · 경로 · 모듈 로깅 정책 키(PowerShellCore 2개)를 토큰 입력 전에 읽음 | PASS |
| S02 | (2) 노출 검사 + 검출기 자체 시험(비밀번호 앞 8자 · 가운데 8자 · 토큰 앞 8자를 잡고, url 의 비밀 아닌 부분은 잡지 않는다 · 비밀번호 · url · 토큰의 SHA-256 hex 대문자 · 소문자 · 앞 16자가 바늘에 있고 출력에 섞이면 잡는다) | PASS |
| S03 | (3) 2경로 live-ok → SKIP · 나머지 4 생성 · live 경로 버전 · 값 불변 · live 경로 put 0 | PASS |
| S04a–h | (4) live-mismatch: 키 누락 · username 다름 · url 비밀번호 ≠ password · 길이 < 32 · 여분 키 · url 접미(DB) 다름 · password 에 `@` · password 가 JSON 숫자 → 각각 쓰기 0 · 정지점까지 가지 않음 | PASS × 8 |
| S04i | (4 · 리뷰 O3) live password = 43자 + 끝 LF · url 도 같은 값 → `live-mismatch: password 에 URL 에 그대로 넣을 수 없는 문자` · 쓰기 0 — 판정 정규식의 `\z` 앵커 고정(`^…$` 는 끝 개행 앞에서도 맞아 live-ok 로 SKIP 된다 · CNPG 는 앞뒤 공백을 지운 값을 role 에 적용하므로 url 속 비밀번호와 어긋난다) | PASS |
| S04j | (4 · 리뷰 r3 O1 · 라운드 4) url 의 사용자 부분만 username 과 다른 **같은 길이**(`identity_admin_xyz`) · 비밀번호 부분은 일치 → `live-mismatch: url 접두가 postgresql://<username>: 과 다르다` · 쓰기 0 — 접두 검사를 지운 변이 mA 가 이전 하네스를 2017/2017 로 통과했다(길이가 같아 Substring 대조가 우연히 맞는다) | PASS |
| S05a–c | (5) dead: soft-delete · destroy · 메타데이터만(current_version 0) → 쓰기 0 | PASS × 3 |
| S06a–d | (6) 쓰기 확인 정지점에서 다른 단어 · 빈 Enter · `" seed"` · 대문자 `"SEED"`(Ordinal 대소문자 구분) → 쓰기 0 · finally 요약 · 창 종료 체크리스트 | PASS × 4 |
| S07a–f | (7) Vault 도달 실패 · sealed · 미초기화 · 응답이 JSON 아님 · `sealed` 가 문자열 · **unsealed JSON 인데 exit 1(리뷰 O3 — `판단 불가`)** → 토큰을 묻기 전에 중단 | PASS × 6 |
| S08a | (8) 일시 상태: 실재 경로를 `No value found` 로 오판 → `-cas=0` 거부 → **재판정 live v1 · 되읽기 해시 불일치 = `CAS 충돌(다른 값)`**(라운드 4 — 재판정 순서 put → metadata get → kv get 단언) → 그 자리 fail-closed(덮어쓰기 0 · live 값 불변 · 뒤 경로 미실행) | PASS |
| S08b–c | (8) 일시 상태: metadata 비 0 + 빈 출력 / 500 → absent 로 보지 않고 판정 불가 → 쓰기 0 | PASS × 2 |
| S08d–e | (8) 일시 상태: 되읽기 일시 실패 → 다음 경로로 가지 않음 / 그 상태에서 재실행 → 앞 2경로 SKIP · 나머지 4 생성(복구) | PASS × 2 |
| S09 | (9) 되읽기 해시 불일치(저장 때 password 변형 — `tamper='password'`) → `되읽기 해시 불일치(password)` · 값 미출력 · 뒤 경로 미실행 | PASS |
| S09b–e | (9 · 리뷰 O2) 되읽기 대조가 세 키와 키 집합을 모두 보는지 고정 — 2번째 경로 url 한 글자(비밀번호 부분) · 3번째 username 한 글자 · 4번째 url 키 누락 · 5번째 여분 키 → 각각 STOP(`되읽기 해시 불일치(url)` · `(username)` · `되읽기 키 집합 불일치(누락: url · 여분 0개)` · `(누락: 없음 · 여분 1개)`) · 그 경로의 요약 행 `기록됨 — 되읽기 …` · 앞 경로 생성 · 뒤 경로 put 0 · 쓴 경로 수 | PASS × 4 |
| S10a–c | (10) 클립보드 기록 켜짐 · 설정 키 없음 · 값 없음 → 시작 전 중단(입력 0 · vault 호출 0) | PASS × 3 |
| S10d | (리뷰 O5) 클립보드 비우기 실패(`Set-Clipboard` 예외 · 세션 `$WarningPreference = SilentlyContinue`) → `Write-Warning` 2개(토큰 확인 줄 앞 1 · 요약 머리 앞 1 — 값 없음) · 6개 생성 완주 · "클립보드에는 공백만" 유지 | PASS |
| S10e | (리뷰 r3 O5 · 라운드 4) 세션 `$WhatIfPreference = $true` + `$PSDefaultParameterValues['Set-Clipboard:WhatIf'] = $true`(제자리 변경 — 붙여넣기 창) → 블록이 자기 범위에서 셋을 고정 → 클립보드 비우기 2회 **실제 실행**(`clip:set` 2 · `clip:whatif` 0) · `VAULT_*` 0 · 6개 생성 완주 + 하네스 자체 단언(세션 값 복원 — Clone 저장 · Clone 교체 복원 뒤 `Set-Clipboard:WhatIf` 키 없음 · 리뷰 r4 O4) | PASS |
| S11a | (11) 정상 완주 뒤 `VAULT_*` 0 · 이 실행으로 생긴 전역에 url · 토큰 모양 0 · `$Error` 0 | PASS |
| S11b–e | (11) 시작 전 `VAULT_TOKEN` · 다른 `VAULT_*` · 다른 `VAULT_ADDR` → 묻지 않고 중단 · 기존 변수 그대로 / 기대값 `VAULT_ADDR` → 진행 후 제거 | PASS × 4 |
| S11f | (11) 되읽기 응답이 깨진 JSON(안에 비밀번호) → 고정 문구로 중단 · 화면 · `$Error` 에 값 없음 | PASS |
| S12 | (12) **맨 먼저 · 관문**(파서 오류 0 · 명령 · 정적 형식 · `$Host` · 리다이렉트 허용 목록 — 하나라도 FAIL 이면 런타임 시나리오 0개 · 수정 라운드 2) · 구조 · 정적 위생: 첫 줄 `& {` · 최상위 문장 1 · `}` 뒤 남는 문자 0 · 빈 줄 0 · 끝 `7D 0A` · BOM/CR 0 · UTF-8 · **본문 첫 문장 `Set-PSDebug -Off` · `Set-PSDebug` 1곳뿐** · try 1 + finally · **finally 는 Write-Host/Write-Warning · Remove-* · Set-Clipboard 만** · **finally 첫 두 문장 = `if ($tokenOwned) { Remove-Item Env:VAULT_TOKEN …` · `if ($addrOwned) { Remove-Item Env:VAULT_ADDR …`** · 명령 허용 목록 · 정적 .NET 형식 허용 목록 · **`$Host` · `$ExecutionContext` 는 `$Host.UI.RawUI.FlushInputBuffer()` 한 모양만**(호스트 UI 직접 쓰기 · `$h = $Host` 별칭 · `$ExecutionContext.Host.UI` 0 — 범위 접두 `$global:Host` · `${Host}` 포함) · 파일 리다이렉트 0 · `Read-Host` 는 정지점 헬퍼 2곳에서만 + **바로 앞 직계 문장이 입력 버퍼 비움(AST — `$Host.UI.RawUI.FlushInputBuffer()` 한 식 문장 또는 본문이 그것 하나뿐인 try. 주석 · 문자열 · `if` 안 · `throw` 뒤 · Read-Host 뒤 = 위반 · 리뷰 O1)** · vault 호출 모양(put = `"-cas=0"` … `-` · `-field` 0 · 하위 명령 허용 목록) · `MOCK` 0 · 비밀처럼 보이는 상수 0 · `hvs.<영숫자>` 0 · `Start-Transcript` 0 | PASS |
| S13a–b | root 토큰 빈 입력 → 중단(token lookup 0) / 앞뒤 공백 → Trim 후 완주 | PASS × 2 |
| S14 | 토큰 정책에 root 없음 → 판정 전 중단(metadata 조회 0) | PASS |
| S15 | `hvs.` 로 시작하지 않는 값(복구 키 조각) → Vault 로 보내기 전에 중단 | PASS |
| S16 | put 거부(권한 · 경로는 그대로 없음) → **재판정 absent = 쓰지 않았다**(`STOP … put 거부(exit=2) · 재판정 absent` · 요약 `중단(put 거부 exit=2 — 재판정 absent · 쓰지 않았다)` · 재판정 metadata get 1 · kv get 0) · 그 경로에서 중단 · 뒤 경로 미실행 | PASS |
| S16d | (리뷰 r3 O6 · 라운드 4) `putLost` — 서버는 커밋 · CLI exit 2(진짜 CAS 충돌과 같은 문구) → 재판정 live v1 → 되읽기 해시 일치 → `OK … 기록됨(응답 유실 — 이 실행의 값 · put exit=2 뒤 재판정) · 되읽기 해시 일치(…)` · cv=1 확인 · **뒤 경로 계속 · 6개 완주** · 집계 `응답 유실 뒤 재판정으로 검증 완료 1` · 재판정 순서 put → metadata get → kv get → metadata get → 다음 put · put 6회(유실 경로 재 put 0) | PASS |
| S16e | (리뷰 r3 O6 · 라운드 4) put 비 0 뒤 재판정 자체가 일시 오류(metadata 500) → `STOP … put 거부(exit=2) · 재판정 error(current_version=-1 · metadata 조회 exit=2 · * context deadline exceeded)` · 요약 `결과 미확인(put exit=2 — 재판정 error …)`("쓰지 않았다" 없음) · 집계 `결과 미확인 1` · `판정: 미완` · 뒤 경로 put 0 | PASS |
| S17 | 재실행 — 6경로 모두 live-ok → 6 SKIP · 쓰기 0 · 쓰기 확인 정지점 없음 | PASS |
| S18 | `~/.vault-token` 존재 → 시작 전 중단 | PASS |
| S19 | live 판정 중 `kv get` 실패 → 판정 불가 · 쓰기 0 | PASS |
| S19b | (리뷰 O4) live 판정 중 `kv get` 응답이 깨진 JSON(안에 비밀번호) → `판정 불가: kv get 응답을 해석하지 못했다(원문 미출력)`(live-mismatch 아님 — 조치 = 재실행) · 쓰기 0 · live 값 불변 · 화면 · `$Error` 에 값 없음 | PASS |
| S20a | (9 확장 · 리뷰 O2) put 성공 뒤 metadata 가 `current_version 2`(다른 기록자 — v2 도 live) → `STOP … — 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(live · current_version=2)` · 요약 `기록됨 — 메타데이터 확인 실패(…)` · 뒤 경로 put 0 | PASS |
| S20b | (9 확장 · 리뷰 O2) put 성공 뒤 현재 버전에 `deletion_time`(마운트 `delete_version_after` 의 삭제 예약) → dead 로 STOP · 뒤 경로 put 0 — 이 판정이 없으면 OK 를 낸 뒤 나중에 ES 가 깨진다 | PASS |
| S20c | (리뷰 r3 O3 · 라운드 4) put 성공 뒤 metadata 조회가 일시 오류(500 · kind=error) → `STOP … 쓰기 뒤 메타데이터가 current_version=1 · 삭제 없음이 아니다(error · current_version=-1 · metadata 조회 exit=2 · * context deadline exceeded)` · 요약 `기록됨 — 메타데이터 확인 실패(error · current_version=-1)` · 뒤 경로 put 0 — 조건을 dead · live∧cv≠1 로 좁힌 변이 mC 는 오류를 OK 로 통과시켰다 | PASS |
| S21a | (리뷰 O4) put 도중 중단(서버는 커밋) → 그 경로의 요약 행 = `결과 미확인(put 진행 중 중단 …)` · "쓰지 않았다" 없음 · 집계 `결과 미확인 1` · `판정: 미완` | PASS |
| S21b | (리뷰 O4) S21a 상태에서 재실행 → 결과 미확인 경로는 live-ok 로 SKIP(덮어쓰기 0) · 나머지 5 생성 | PASS |
| S22a–c | (리뷰 O5) 모듈 로깅 정책 켜짐 — PowerShellCore HKLM · PowerShellCore HKCU · `UseWindowsPowerShellPolicySetting` 1 + Windows PowerShell HKLM → 시작 전 중단(입력 0 · vault 호출 0) | PASS × 3 |
| S22d | (리뷰 O5) `UseWindowsPowerShellPolicySetting` 1 · 양쪽 `EnableModuleLogging` 0 → 그대로 진행(6개 생성) · 정책 키 4개를 모두 읽음 | PASS |
| R1 | (리뷰 r3 O7 · 결정 C6 · 라운드 4) 런북 ① 점검 블록 정적(**관문 6**: 코드 펜스 추출(표식 `[t054-cleanup-inspect]` 가 든 펜스 정확히 1개 · 들여쓰기 제거) · 파서 오류 0 · 명령/정적 형식/`$Host`/리다이렉트 허용 목록) + 첫 줄 `& {` · 표식 주석 · 끝 `}` · 빈 줄 0 · TAB 0 · CR 0 · 최상위 1문 · Read-Host 1곳 평문 + 바로 앞 비움(AST) · **첫 Read-Host 전 `Set-Clipboard -Value ' '` 문장 정확히 1개(try 안 · catch 의 `Write-Warning` 문구 — 수정 라운드 6 · 리뷰 r6 S1)** · vault = `kv metadata get -format=json` · `kv get -format=json` 만(put · delete 0) · MOCK · 비밀 상수 · `hvs.` · Start-Transcript · env 쓰기 0 — 관문 FAIL 이면 GA 를 돌리지 않는다 | PASS |
| R2 | 런북 ② 삭제 블록 정적(같은 검사 · Read-Host 2곳 · 첫 Read-Host 전 클립보드 비움 문장 · vault = `kv metadata get -format=json` · `kv metadata delete` 만(put · kv get 0)) — 관문 FAIL 이면 GB 를 돌리지 않는다 | PASS |
| GA01–GA08 | ① 점검 블록 런타임(vault 쓰기 명령 0 단언 · 성공 스트림 0 · 노출 0 · 창의 `VAULT_*` 그대로 · **첫 Read-Host 전 클립보드 비움(`clip:set` < `read:plain` · 값은 공백만 — 수정 라운드 6)**): live 경로 → `current_version=1 · delete_version_after=0s` · 버전 이력 1행 · `현재 버전 키 이름(값 미출력): password · url · username` · vault = metadata get 1 + kv get 1 / absent → `absent(메타데이터 없음 …)` · kv get 0 / 6경로 밖 · 끝 공백 · 대소문자 다름 → vault 호출 0 / dead(soft-delete) → `deletion_time=…` · `현재 버전 데이터: 없음` / metadata 500 → `metadata 조회 실패(exit=2)` · kv get 0 / kv get 비 0 → `현재 버전 데이터: 읽지 못했다` · 완주 / `current_version 0` → 이력 0행 / **GA08(수정 라운드 6 · 리뷰 r6 O5) metadata 는 live 인데 kv get 응답이 깨진 JSON(안에 비밀번호 — 과도기 상태) → `ConvertFrom-Json` 종료 오류(`Unexpected end when reading token. Path 'data.data'` — 키 경로 · 위치만)로 중단 · 화면 · `$Error`(메시지 · 예외 전문 · TargetObject) 에 값 없음 · 쓰기 0 · 값 불변 — 노출이 없어 ① 블록은 그대로** | PASS × 10 |
| GB01–GB12 | ② 삭제 블록 런타임(`$AllowDelete` · `kv put` 0 · 성공 스트림 0 · 노출 0 · 첫 Read-Host 전 클립보드 비움 — 수정 라운드 6): G1–G3 6경로 밖(소비 중 `kv/platform/cloudflare/tunnel`) · 끝 공백 · 대소문자 → vault 호출 0 · 재입력을 묻지 않음 / G4–G5 재입력 다른 6경로 · 빈 Enter · 끝 공백 → metadata get 1 · delete 0 / G6 정확한 재입력 → metadata get → delete → metadata get(`No value found`) · `OK …` · 그 경로만 사라짐 · 둘째 프롬프트에 `되돌릴 수 없다` + `current_version=1` / G7 metadata 500 → 재입력 없이 중단 / G8 delete exit 2 → `삭제 실패` / G9 delete exit 0 인데 잔존 → `삭제 확인 실패` / absent → `이미 없다(absent)` / 삭제 뒤 확인 조회 500 → `삭제 확인 실패`(OK 아님) — 설계 번호 ↔ 실제 ID: G1–G3 = GB01–GB03 · G4–G5 = GB04–GB06 · G6 = GB07 · G7–G9 = GB08–GB10 · absent = GB11 · 삭제 뒤 조회 500 = GB12(수정 라운드 6 · 리뷰 r6 S2 — 하네스의 괄호 라벨도 실제 ID 로 통일) | PASS × 12 |

### TDD 기록 — 라운드 0(2026-10-14 · 그때 하네스 46 시나리오 기준)

- **red**: 하네스를 먼저 쓰고 블록을 0바이트로 둔 채 실행 → `시나리오 PASS 0 / 46` · `PASS 883 / 1176` · exit 1(`pwsh -File` · `pwsh -Command` 두 방식 같은 값). 단언 수가 green(1301)과 다른 것은 S12 가 파싱할 수 없는 파일에서 일찍 끝나고, 경로별 단언 일부가 데이터가 있을 때만 생기기 때문이다.
- red 에서 **하네스 결함 1건**을 찾았다: `pwsh -File` 로 돌리면 스크립트 범위가 곧 전역 범위라, 하네스 자신의 바늘 목록(`$NSecrets`)이 "시나리오 도중 바뀐 전역 변수"로 잡혔다(두 실행 방식의 단언 수가 837 대 883 으로 갈렸다) → 하네스 내부 상태를 제외 목록에 넣고, 노출 점검 결과에 **변수 이름만**(값 없이) 내도록 고쳤다.
- **green**: 블록 작성 뒤 1차 실행에서 실패 3건은 전부 하네스 쪽 오류였다(블록 출력 원문으로 확인): S04g 기대 문구에 `password 에` 접두 누락 · 끝 바이트 검사가 `}` 앞의 LF 까지 금지(T045 정본 끝 3바이트는 `0A 7D 0A`) · `Read-Host` 소유 헬퍼 탐색이 안쪽 `$ans = Read-Host` 대입에서 멈춤 → 하네스를 고친 뒤 `PASS 1301 / 1301` · exit 0.
- **변이 시험(저장소 밖 스크래치 사본 25개, `-Block` 으로 실행)** — 전부 잡혔다(exit 1):

| 변이 | 잡은 시나리오(수 · 목록) |
|---|---|
| put 에서 `-cas=0` 제거 | 13 — S01 · S02 · S03 · S08a · S08d · S08e · S09 · S11a · S11c · S11f · S12 · S13b · S16 |
| 비밀번호 전체 출력 / **앞 8자만** 출력 | 각 12 — S01 · S02 · S03 · S08a · S08d · S08e · S09 · S11a · S11c · S11f · S13b · S16(노출 검사) |
| 되읽기 해시 대조 생략 | 1 — S09 |
| T045 식 분류(비 0 = absent) | 2 — S08b · S08c |
| `$stop` 의 `FlushInputBuffer` 제거 | 1 — S12 |
| live-ok 에서 url 비밀번호 비교 생략 | 1 — S04c |
| 첫 쓰기를 `seed` 정지점 앞으로 | 15 — S01 · S02 · S03 · S06a–c · S08a · S08d · S08e · S09 · S11a · S11c · S11f · S13b · S16 |
| 되읽기를 `-field` 로 | 12 — S01 · S02 · S03 · S08a · S08d · S08e · S09 · S11a · S11c · S11f · S12 · S13b(위반 + 정적 검사) |
| 사전 `VAULT_*` 검사 제거 | 3 — S11b · S11d · S11e |
| 성공 스트림으로 한 줄 출력 | 29 |
| token lookup 원문 출력 | 31(토큰 노출) |
| `VAULT_TOKEN` 무조건 제거 | 1 — S11b |
| 보안 입력 직후 클립보드 비우기 제거 | 1 — S01 |
| `$Error` 정리 제거 | 1 — S11a |
| 모든 경로에 같은 비밀번호 | 2 — S01 · S02 |
| 정지점이 아무 입력이나 통과 | 3 — S06a–c |
| username 판정 생략 | 1 — S04b |
| live 판정 자체 생략(읽지 않고 OK) | 9 — S04a–h · S19 |
| 되읽기 실패 뒤 throw 없이 계속 | 2 — S08d · S08e |
| destroy 를 absent 로 | 1 — S05b |
| 토큰을 평문 `Read-Host` 로 | 34 |
| `Start-Transcript` 추가 | 24(S12 정적 검사 포함) |
| 블록 안 빈 줄 | 1 — S12 |
| put 값을 argv(`k=v`)로 | 13 — S01 · S02 · S03 · S08a · S08d · S08e · S09 · S11a · S11c · S11f · S12 · S13b · S16 |

변이 스크립트와 사본은 저장소 밖(세션 스크래치)에 있다 — 재현은 이 표의 변이를 블록 사본에 한 줄씩 넣고 `-Block <사본>` 으로 하네스를 돌리면 된다. `Start-Transcript` 변이는 실제로 `%TEMP%` 에 전사 파일을 만들었으므로(가짜 값뿐) 실행 뒤 지웠다.

### 수정 라운드 1(2026-10-14 — 리뷰 K5 · O1–O5 · O8)

- **재현(하네스의 red)**: 라운드 0 블록 사본에 리뷰 변이 ①–⑥ 을 넣고 라운드 0 하네스로 돌리면 6개 모두 `시나리오 PASS 46 / 46` · `PASS 1301 / 1301` · exit 0 — 리뷰 O1 · O2 그대로 재현(① 은 생성 비밀번호 줄 48개, ② 는 가짜 root 토큰 줄 32개를 호스트 UI 로 찍고도 통과).
- **하네스를 먼저 고쳐** 라운드 0 블록에 돌림: `시나리오 PASS 30 / 55` · `PASS 1609 / 1650` · exit 1. 실패는 전부 새 단언이다 — 가려진 입력(정지점에 도달하는 시나리오 전부) · S01 의 `INFO` 줄 · 정책 키 읽기 · S12 finally 첫 문장(`Remove-Variable …`) · S21a 요약 행(서버는 커밋했는데 `중단(쓰기 시작 직후 — … 쓰지 않았다)`) · S22a–d. 새 `$Host` 규칙 · S06d · S20a·b 의 행동 단언은 라운드 0 블록에서도 통과했다(블록 동작은 맞았고, 빠져 있던 것은 단언이었다).
- 그 사이 **하네스 결함 1건**: `$Host` 규칙이 `VariablePath.UnqualifiedPath` 를 읽었는데 공개 속성이 아니라 StrictMode 에서 S12 가 예외로 죽었다(결과 표도 못 냈다) → 공개 `UserPath` 에서 범위 · 드라이브 접두를 떼는 `Var-Name` 으로 고쳤다.
- **블록 수정 뒤 1차**: `PASS 1649 / 1650` — S12 "비밀처럼 보이는 상수" 가 이번에 쓴 주석 `UseWindowsPowerShellPolicySetting=1`(대 · 소문자 + `=1`, 35자 연속)을 잡았다 → 검사를 약하게 하지 않고 주석 표기를 `… 값이 1 이면` 으로 바꿨다. **green**: `시나리오 PASS 55 / 55` · `PASS 1650 / 1650` · exit 0.
- **변이 시험(최종 블록의 저장소 밖 스크래치 사본 16개 · 전부 파서 오류 0 · `-Block` 으로 실행)** — 전부 잡혔다(exit 1):

| 변이 | 잡은 시나리오(수 · 목록) · 잡은 단언 |
|---|---|
| ① `$write` 의 url 조립 앞에 `$Host.UI.WriteLine('dbg ' + $pw)` | 1 — S12(`$Host` 규칙) |
| ② `$env:VAULT_TOKEN = $tok` 뒤에 `$Host.UI.WriteErrorLine('t=' + $tok)` | 1 — S12(`$Host` 규칙) |
| ③ OK 줄 직전에 `Write-Host ('H ' + (& $sha $pw))` | 12 — S01 · S02 · S03 · S08a · S08d · S08e · S11a · S11c · S13b · S20a · S21b · S22d(노출 0: 화면 — 해시 바늘) |
| ④ 메타데이터 판정 `-ne 1` → `-lt 1` | 1 — S20a |
| ⑤ 메타데이터 판정 조건 → `$false`(metadata 호출은 남김) | 2 — S20a · S20b |
| ⑥ `$stop` 비교를 `OrdinalIgnoreCase` 로 | 1 — S06d |
| `seed` 정지점의 `-MaskInput` 제거 | 21 — 정지점에 도달하는 시나리오 전부(입력은 전부 가려진다) |
| finally 순서를 라운드 0 으로(env 제거를 `Remove-Variable` 뒤로) | 1 — S12(finally 첫 두 문장) |
| put 직전 `결과 미확인` 갱신 제거 | 1 — S21a(요약 행 · 집계) |
| 모듈 로깅 throw 무력화 | 3 — S22a · S22b · S22c |
| `UseWindowsPowerShellPolicySetting` 무시 | 2 — S22c · S22d |
| `$h = $Host; $h.UI.WriteLine(…)`(별칭) | 1 — S12 |
| `$ExecutionContext.Host.UI.WriteLine(…)` | 1 — S12 |
| 해시 앞 16자만 `Write-Host` | 12 — ③ 과 같은 목록 |
| 해시 소문자 `Write-Host` | 12 — ③ 과 같은 목록 |
| url 의 해시 `Write-Host` | 12 — ③ 과 같은 목록 |

- 위 라운드 0 변이 표는 그때 하네스(46 시나리오)로 잰 기록이다. 이번에 다시 재지 않았다 — 하네스는 단언과 시나리오를 더했을 뿐 기존 단언을 빼지 않았으므로 그 변이들도 계속 잡힐 것으로 보지만, 이번 라운드의 실측은 위 16개뿐이다.
- **런북 가드 블록(리뷰 O8) 모의 시험**: `bootstrap.md` §4 T054 「정리 판단」 가드 블록을 런북에서 그대로 뽑아(21줄 · 빈 줄 0 · 파서 오류 0 · 최상위 문장 1) 모의 `vault`/`Read-Host` 로 9경우 `PASS 9 / 9` — 6경로 밖(소비 중인 `kv/platform/cloudflare/tunnel`) · 끝 공백 · 대소문자 다른 경로 → vault 호출 0 / 재입력 불일치 · 빈 Enter → 삭제 0(버전 이력은 먼저 보임) / 정확한 재입력 → get → delete → get(`No value found`) · OK / metadata 조회 실패 · 삭제 실패(exit 2) · 삭제 뒤 경로 잔존 → 중단. 늦은 시드(K5)의 명령 블록은 파싱만 확인했다(문장 2 · 파서 오류 0 — 실행하지 않았다). 시험 스크립트 · 변이 생성기는 세션 스크래치에 있다(저장소 밖).

### 수정 라운드 2(2026-10-14 — 리뷰 O1–O8)

| id | 처리 | 한 일 |
|---|---|---|
| O1 (medium) | 고침 | S12 의 입력 버퍼 비움 검사를 텍스트 검색(`IndexOf('FlushInputBuffer()')` — 주석 · 문자열도 맞았다)에서 **AST** 로 바꿨다. Read-Host 를 감싼 헬퍼 본문에서 Read-Host 를 담은 직계 문장의 **바로 앞** 직계 문장이 `$Host.UI.RawUI.FlushInputBuffer()` 한 식 문장(`Is-FlushStmt` — `$Host` 규칙의 `Is-Member` 재사용)이거나 본문이 그 문장 하나뿐인 try 여야 한다. 지적의 "앞에 있고 · 조건문 안이 아닌 같은 블록 문장(또는 직계 try)" 을 "바로 앞" 으로 한 단계 좁혔다(비움과 읽기 사이에 다른 문장이 끼면 type-ahead 가 다시 쌓일 수 있다 — 지금 블록은 두 곳 모두 바로 앞이다) |
| O2 (medium) | 고침 | 모의 `tamper` 를 키 지정형(`password` · `username` · `url` · `dropKey` · `extraKey`)으로 바꾸고 S09b–e 를 더했다. 부수로 블록의 되읽기 키 집합 STOP 문구를 판정 단계와 같은 `누락: 없음` 표기로 맞췄다(§2 의 21) |
| O3 (low) | 고침 | S04i(43자 + 끝 LF) · S07f(모의 status `okrc1` — unsealed JSON + exit 1) |
| O4 (low) | 고침 | 블록 `$judge`: 해석 실패 = `kind=error`(판정 불가 · 재실행), `data.data` 없음 · 비객체만 mismatch(§2 의 20). S19b |
| O5 (low) | 고침 | 두 catch 에 `Write-Warning $clipWarn`(값 없음) + 블록 범위 `$WarningPreference = 'Continue'`(§2 의 19). 모의 `clipFail` + S10d(세션 `$WarningPreference` 를 `SilentlyContinue` 로 두고 돌려 그 고정까지 확인) |
| O6 (low) | 1 · 2 고침, 3(선택)은 하지 않음 | 1) 본문 첫 문장 `Set-PSDebug -Off`(§2 의 18) — 하네스 `$AllowedCmds` 에 추가 · S12 가 "첫 문장 + 1곳뿐" 을, 모의 `Set-PSDebug` 가 모든 런타임 시나리오에서 "첫 동작" 을 단언. 2) 런북: 사전 5 = 붙여넣기는 `pwsh -NoProfile` 로 새로 연 창에서만 · INFO 줄 종류 확인을 「판정」에서 「실행」(root 토큰을 붙이기 전 — 아니면 Ctrl+C)으로 옮겼다. 3) CommandType ≠ Application 단어 정지점은 넣지 않았다: 하네스에서 `vault` 는 반드시 모의 함수(`Function`)라, 넣으면 모든 시나리오에 입력이 하나 더 들거나 `Get-Command` 까지 모의해 INFO 줄의 사실성(지금은 하네스가 "Function (경로 없음)" 을 그대로 단언한다)을 잃는다. `-File -NoProfile`(권장)과 `-NoProfile` 새 창에는 프로필 함수 · 별칭이 없고, 남는 경우는 런북의 "토큰을 붙이기 전 확인" 이 막는다 |
| O7 (low) | 고침 | 런북 실패 표: ① `판정 불가` 행 — kv get 쪽 변형의 값 없는 진단 `vault kv get "-format=json" <경로> > $null; "exit=$LASTEXITCODE"` + 표 형식 `vault kv get` 금지 ② `put 거부` 행 — "같은 경로에서 반복되면 CAS 가 아니다 — 토큰 정책 · 창 C" ③ `메타데이터 확인 실패` 를 별도 행으로: error → 재실행 · `current_version=2` → 재실행(+ 다른 기록자 확인) · dead → 키 metadata 와 `kv/config` 의 `delete_version_after`(값 없음) 확인, `0s` 로 고치기 전에는 정리하지 않는다(`infra/vault` 는 이 설정을 선언하지 않는다 — OpenTofu plan 에도 안 보인다). 덧붙여 `vault status 가 unsealed 인데 exit=…` 를 Vault 행에, 클립보드 경고를 새 행에 넣었다 |
| O8 (low) | 고침 | S12 를 맨 먼저 · 관문 5단언 FAIL(또는 빠짐) = 런타임 0개 · exit 1(§4 「모의 방식 · 가드」). 하네스 프로세스 `KUBECONFIG` 를 없는 경로로 덮고 finally 에서 복원 · `Assert-Guard` 가 블록 실행 전마다 확인 |

- **재현(하네스 결함의 red — 라운드 1 하네스 · 라운드 1 블록의 스크래치 사본에 변이)**: A(되읽기 대조 키 → `@('password')`) · B(판정 정규식 `\A…\z` → `^…$`) · C(`$stop` 비움 줄 주석 처리) · D(`$readSecret` 같은 처리) · E(`if ($rc -ne 0) { throw … }` 줄 삭제) → 다섯 다 `시나리오 PASS 55 / 55` · `PASS 1650 / 1650` · exit 0(지적 그대로). 지적 밖 같은 유형 C2(비움을 `if ($false) { … }` 안으로 — `$Host` 규칙은 통과하는 모양) · C3(비움 대신 문자열 `'FlushInputBuffer()'`) · C5(`try { throw 'x'; …비움… }` — 도달 불가)도 셋 다 통과. 텍스트 검사가 잡은 것은 C0(줄 통째 삭제 — 라운드 0 표의 "`$stop` 의 `FlushInputBuffer` 제거" 는 이 경우에만 성립했다)과 C4(비움을 Read-Host 뒤로)뿐. K1(`& 'C:\nonexistent-t054\kubectl.exe' version` — 없는 경로라 실행돼도 무해) → 블록이 런타임 시나리오에서 실행됨(`시나리오 PASS 10 / 55` — 런타임 실패 44 + S12) · K5(`$d0 = Get-Date`) → S12 만 FAIL, 즉 허용 목록 밖 명령이 든 블록이 런타임 시나리오 54개 전부에서 실행됐다(O8).
- **하네스 먼저(새 하네스 · 라운드 1 블록 사본)**: `시나리오 PASS 0 / 63` · `PASS 1947 / 2017` · exit 1. 실패 70 = 공통 단언 "첫 동작 = Set-PSDebug -Off" 62(런타임 전부) + S12 "본문 첫 문장 = Set-PSDebug -Off" 1 + S10d 3(경고 없음) + S19b 3(live-mismatch 로 분류) + S09e 1(문구 `누락:  ·`). S04i · S07f · S09b–d 의 행동 단언과 S12 의 새 AST 비움 규칙 · 관문은 라운드 1 블록에서도 통과했다(블록 동작은 맞았고 빠진 것은 단언 — 새 규칙의 거짓 양성 0).
- **블록 수정 뒤 green**: `시나리오 PASS 63 / 63` · `PASS 2017 / 2017` · exit 0.
- **변이 시험(최종 블록의 스크래치 사본 21개 · 전부 파서 오류 0 · `-Block`)** — 전부 잡혔다(exit 1):

| 변이 | 잡은 시나리오 · 잡은 단언 |
|---|---|
| A 되읽기 대조 키 `@('password')` | S09b · S09c — throw 없음 · 변조된 경로에 `OK … 되읽기 해시 일치(username·password·url)` 가 찍힘(거짓 검증) |
| A2 쓰기 경로의 키 집합 검사 무력화 | S09d(키 집합 대신 해시 불일치로 멈춤 — 문구 · 결과 다름) · S09e(멈추지 않고 OK) |
| B 판정 정규식 `^…$` | S04i — live-ok 로 SKIP 되어 throw 없음 · 쓰기 발생 |
| C · D(주석 처리) · C0(삭제) · C2(`if` 안) · C3(문자열) · C4(Read-Host 뒤) · C5(`throw` 뒤) | S12 — `Read-Host 바로 앞 직계 문장이 입력 버퍼 비움이 아니다`(관문 단언은 아니라 런타임은 돌고 S12 만 FAIL) |
| E status 비 0 throw 줄 삭제 | S07f — throw 없음 · 토큰을 물음 · status 뒤 vault 호출 |
| F 판정 해석 실패 → mismatch(O4 되돌림) | S19b — `판정 불가` 문구 없음 · `live-mismatch` 출력 |
| G1 · G2 클립보드 catch 를 다시 조용히(두 곳 각각) | S10d — 경고 1개 |
| W `$WarningPreference = 'Continue'` 삭제 | S10d — 세션 `SilentlyContinue` 에서 경고 0개 |
| H `Set-PSDebug -Off` 삭제(O6 되돌림) | S12 + 런타임 62개 전부(공통 단언) |
| K1 절대 경로 `kubectl.exe` · K2 `[Environment]::MachineName` · K3 `$Host.UI.WriteLine` · K4 `Write-Host 'x' 6> "$env:TEMP\…"` · K5 `Get-Date` | **관문 FAIL — 런타임 시나리오 0개**(`시나리오 PASS 0 / 1` · `관문 FAIL(S12): <해당 허용 목록> [L254 …]`). K4 의 리다이렉트 대상 파일은 실행 전후 모두 없었다 = 블록이 한 번도 실행되지 않았다 |

- **O8 KUBECONFIG 복원 실측**: 하네스를 한 pwsh 프로세스 안에서 `&` 로 두 번 돌렸다 — `KUBECONFIG` 를 표식 값으로 둔 경우 끝난 뒤 같은 값, 없앤 경우 끝난 뒤에도 없음(둘 다 rc 0).
- 라운드 0 · 1 변이 표의 나머지는 이번에 다시 재지 않았다(이번에 바꾼 단언은 S12 의 비움 규칙 · 관문 순서 · `Set-PSDebug` 공통 단언 · 새 시나리오이고, 기존 단언은 빼지 않았다). 변이 생성기 · 실행기 · 사본은 세션 스크래치(저장소 밖)에 있다.

### 수정 라운드 4(2026-10-15 — 컨트롤러 결정 C6 · C7 · C8 · C13 · 리뷰 r3 O1–O7 · r4 S1–S4 · O1 · O2 · O3 · O4)

라운드 3 리뷰 뒤 컨트롤러 결정(`.superpowers/t054/prompts/t054-decisions-r4.md`)을 반영한 라운드. 10-14 16:36 의 1차 시도(Opus 주간 한도로 중단)는 `harness.ps1` 에 O2 순서 단언 · `postMeta 'err'` · `putLost` · `kv metadata delete` 모의 · `Set-Clipboard` ShouldProcess · 정적 판정 함수 분리만 남겼고 시나리오 · 블록 · 문서는 바꾸지 못했다(r4 리뷰 S4 · O1 · O4 "서술이 코드보다 앞선 상태") — 이번 라운드가 그 위에서 끝까지 갔다.

| ID | 처리 | 한 일 |
|---|---|---|
| C8 · r3 O5 (`$WhatIfPreference`) | 고침 | 블록 try 앞 직계 문장 `$WhatIfPreference = $false` · `$ConfirmPreference = 'High'` · `$PSDefaultParameterValues = @{}`(§2 의 22). S12 가 세 문장을, S10e 가 동작(세션 WhatIf + 기본 매개변수 -WhatIf 제자리 변경 → 클립보드 쓰기 2 · `VAULT_*` 0 · 6개 완주)을 고정 |
| C8 · r3 O6 (put 비 0 재판정) | 고침 | 블록 `$write` put 비 0 분기 → `$state` 재판정: absent = `중단(… 재판정 absent · 쓰지 않았다)` / live v1 → 되읽기 해시 대조로 `기록됨(응답 유실 — 이 실행의 값)` 계속 또는 `CAS 충돌(다른 값)` STOP / 그 밖 = `결과 미확인`. 요약 집계에 `응답 유실 뒤 재판정으로 검증 완료 N` 범주 · 원칙 (f) · (h) · 재실행 주석 · 런북 실패 표 3행 · 기대 출력 집계 줄 · S08a · S16 기대 문구 · 새 S16d · S16e(§2 의 23) |
| C8 · r3 O1 (S04j) | 고침 | url 사용자 부분 ≠ username(같은 길이) · 변이 mA → S04j 만 FAIL |
| C8 · r3 O2 (INFO 순서) | 고침(1차 시도 반영 확인) | 공통 사후 조건 "INFO vault CLI 줄 < root 토큰 프롬프트 시점 출력 수" · 변이 mB → 51 시나리오 FAIL |
| C8 · r3 O3 (S20c) | 고침 | `postMeta 'err'`(put 뒤에만 500) → S20c · 변이 mC → S20c 만 FAIL |
| C8 · r3 O4 (TAB 0) | 고침 | S12 `TAB 0` + R1 · R2 같은 규칙 · 변이 mD → S12 만 FAIL · 런북 변이 rb2 → R2 만 FAIL |
| C6 · r3 O7 (정리 판단 분할 + 저장소 하네스) | 고침 | 런북 「정리 판단」을 ① 점검(표식 `[t054-cleanup-inspect]` — 쓰기 명령 0 · 상태 · 버전 이력 · 키 이름만) · ② 삭제(표식 `[t054-cleanup-delete]` — 허용 목록 · 재입력 · `No value found` 확인 · absent · 조회/삭제 실패 · 잔존 · 삭제 뒤 조회 오류 = 중단)로 나눴다. 하네스 `Get-RbBlock` 이 코드 펜스에서 추출 → R1 · R2(관문 6) → GA01–GA07 · GB01–GB12. README §2 에 C6 근거 문단(쓰기 보호 가드 · 실행 간 상태 인계 없음 · 쓰기 전 단어 정지점 · `-cas=0` 이중 방어). 런북 변이 rb1(점검 블록이 delete 호출) → R1 + GA01 · GA04 FAIL / rb3(재입력 검사 제거) → GB04–GB06 FAIL / rb4(점검 블록이 값 출력) → GA01 노출 FAIL / rb5(비움 없는 Read-Host) → R1 FAIL |
| C7 · r2 O10(= r4 O3 "C7 미반영" — 이전 표기 O5 는 오기 · 라운드 6 에서 정정) | 고침 | `vault-unseal.md` §0: 창 시작 체크리스트의 전사 확인을 PowerShellCore 두 키(Transcription · ModuleLogging · ScriptBlockLogging) + `UseWindowsPowerShellPolicySetting`=1 분기(Windows PowerShell 키)로 · 「비밀이 새는 6곳」(5 → 6)에 모듈 로깅(이벤트 4103) 행 — 블록이 정책 키 4개를 스스로 검사해 켜져 있으면 토큰을 묻기 전에 멈춘다는 사실과 함께. 런북 §4 T054 사전 1 문구를 맞췼다 |
| C13 | 고침 | 런북 수동 대체를 ① app role 세션 기본값 ② pod DB CONNECT 제한(REVOKE/GRANT 한 트랜잭션 + `datacl` · `has_database_privilege` 확인) 둘로, 둘 다 `kubectl -n data exec pg-main-1 -c postgres -- psql -X …` 1순위(파드 안 로컬 소켓 peer 인증 — superuser 비밀번호 불필요) · `kubectl cnpg psql` 은 대안. "sync마다" → "전체 sync마다(selfHeal 부분 sync · 리소스 선택 Sync · Apply only 는 hook 을 건너뛴다)" |
| r4 O4 (하네스 정합성) | 고침 | `$OrigPSDPV` 를 `.Clone()` 으로 저장 · Clone 교체 복원(Reset-Mocks · 최종 finally) + S10e 자체 단언(복원 뒤 키 없음) · `Find-Inner` · `Bad-Secrets` 를 S12 와 R1 · R2 에서 실제 호출 · 헤더 서술과 등록 시나리오 일치 · README · 런북 수치 = 실측 |
| r2 · r3 low 나머지 | 해당 없음 | r2 O3–O8 은 라운드 2 에서 고쳤고(위 표), r2 O9 · spec/security r2·r3 의 monorepo 밖 low(gitops · controller target)는 이 슬라이스 몫이 아니다. r3 O1–O7 은 전부 위 C8 · C6 행 |

- **red(하네스 먼저 — 블록 · 런북 수정 전)**: `시나리오 PASS 62 / 70` · `PASS 2279 / 2335` · exit 1. FAIL = S12(세션 설정 고정 3문장 없음) · S10e(`VAULT_TOKEN` 이 env 에 남음 · 클립보드 쓰기 0 · `What if:` 18줄 콘솔 출력) · S08a · S16 · S16d · S16e(O6 문구 · 재판정 없음 — S16d 는 `put 거부` throw 로 완주 실패) · R1 · R2(표식 펜스 0개 — GA · GB 미실행). S04j · S20c · TAB 0 은 현재 블록에서 이미 PASS(블록 동작은 맞았고 빠진 것은 단언 — 변이로 red 를 실측).
- **green(블록 · 런북 수정 뒤)**: `시나리오 PASS 91 / 91` · `PASS 2726 / 2726` · exit 0 · `%TEMP%` 함정 디렉터리 잔여 0. 중간에 하네스 쪽 정정 1건: 집계 줄이 늘 `응답 유실 뒤 재판정으로 검증 완료 0` 을 내므로 S08a · S16 · S16e 의 `notwant: 응답 유실` 을 `기록됨(응답 유실` 로 좁혔다(88/91 → 91/91).
- **변이 시험(현재 블록 · 런북에서 새로 만든 사본 9개 · `-Block` / `-Runbook`)** — 전부 exit 1 · 의도한 시나리오에서만 FAIL:

| 변이 | 잡은 시나리오 |
|---|---|
| mA 블록: url 접두 검사 `if ($false)` | S04j(1) |
| mB 블록: `INFO vault CLI` 줄을 토큰 정책 OK 줄 뒤로 | 51(공통 순서 단언 — root 토큰 프롬프트에 도달하는 시나리오 전부) |
| mC 블록: 쓰기 뒤 metadata 조건을 dead · live∧cv≠1 로 좁힘 | S20c(1) |
| mD 블록: `$creates = @()` 들여쓰기를 TAB 하나로 | S12(1 — `TAB 0`) |
| rb1 런북: ① 점검 블록에 `vault kv metadata delete $p` 한 줄 | R1(vault 호출 모양) + GA01 · GA04(위반 — 점검 블록의 delete) |
| rb2 런북: ② 삭제 블록 한 줄을 TAB 들여쓰기 | R2(`TAB 0`) |
| rb3 런북: ② 삭제 블록의 재입력 검사를 `if ($false)` | GB04 · GB05 · GB06 |
| rb4 런북: ① 점검 블록이 `$dd.password` 를 Write-Host | GA01(노출 0: 화면 — 바늘 길이 42) |
| rb5 런북: ① 점검 블록의 첫 Read-Host 앞 비움 삭제 | R1(Read-Host 바로 앞 직계 문장이 입력 버퍼 비움이 아니다) |

- **세션 설정 고정 실측(pwsh 7.6.6 · 라이브 아님)**: 전역 `$WhatIfPreference = $true` · `$PSDefaultParameterValues['Set-Content:WhatIf'] = $true` 인 세션에서 `& { $WhatIfPreference = $false; $ConfirmPreference = 'High'; $PSDefaultParameterValues = @{}; Remove-Item Env:T054_PROBE … }` → 블록 안에서 env 가 실제로 지워지고, 블록 밖 전역 값은 그대로(`WhatIfPreference = True` · 키 유지). `$PSDefaultParameterValues.Clone()` 은 `Hashtable`, 그것을 다시 대입하면 `DefaultParameterDictionary` 로 들어간다(하네스의 Clone 저장 · 교체 복원 근거).
- 변이 생성기(`make-mutants.ps1`) · 사본 · 실행 결과는 세션 스크래치 `r4/`(저장소 밖)에 있다 — 재현은 위 표의 변이를 사본에 넣고 `-Block`/`-Runbook` 으로 돌리면 된다.

### 수정 라운드 6(2026-10-15 — 리뷰 r6 spec S1–S4 · 운영자 O1–O5 + 컨트롤러 결정 — 지시문 `.superpowers/t054/prompts/t054-fix-r6-seed.md`)

r6 리뷰(spec · 운영자 두 렌즈 — 둘 다 approve_with_fixes · medium 은 S1 하나)를 반영한 라운드. 핵심은 **r4 O5(운영자 리뷰 번호로는 r5 O5 — 같은 항목)의 미닫힘**: 정리 ①·② 블록과 `vault-unseal.md` §0 절대 규칙 1 에 클립보드 비우기가 없는데 라운드 4 보고와 이 README 는 O5 를 "반영"으로 적었다(C7 미반영 = r4 O3 와 혼동 — 위 라운드 4 절 제목 · :3 정정). 시드 블록 `op1-seed-db.ps1` 은 바꾸지 않았다(지적 0 — S12 의 해시 · 정적 검사 그대로).

| ID | 처리 | 한 일 |
|---|---|---|
| S1 = O1 (medium) r4 O5 미닫힘 — 클립보드 비우기 | 고침 | (a) 런북 ① 점검 · ② 삭제 블록: `$PSNativeCommandUseErrorActionPreference = $false` 다음 줄에 `try { Set-Clipboard -Value ' ' } catch { Write-Warning '클립보드를 비우지 못했다 — root 토큰이 클립보드에 남아 있을 수 있다. 직접 비운 뒤 계속한다' }` 한 문장 + 머리 주석에 "첫 Read-Host 전 클립보드 비움(§0 규칙 1로 붙인 토큰 잔류 방어)". 재입력 프롬프트는 그대로 평문(R2 가 `-MaskInput 0` 을 요구 — 비우기가 있으면 오붙임은 공백 → 불일치 → 중단). (b) 하네스: `$RbAllowedCmds` 에 `Set-Clipboard` · `Write-Warning` · R1 · R2 정적 단언(`Set-Clipboard -Value ' '` 문장 정확히 1개 · 첫 Read-Host 앞 · try 안 · catch 의 `Write-Warning` 문구 — 비관문이라 red 에서 GA · GB 도 돈다) · `Run-RbCase` 공통 단언 「첫 Read-Host 전 클립보드 비움(clip:set ≥ 1 · 값은 공백만)」(모의 `Set-Clipboard` 의 `clip:set` 이 모의 `Read-Host` 의 `read:plain` 보다 앞 · 기록 값 전부 `' '` SEq Ordinal — 기존 모의 함수 재사용 · 실물 클립보드 0). (c) `vault-unseal.md` §0 절대 규칙 1 코드 블록의 토큰 줄 다음에 `Set-Clipboard -Value ' '` 한 줄 + 「비밀이 새는 6곳」 클립보드 행에 "규칙 1 뒤 · 정리 블록 첫머리에서도 비운다". (d) 변이 rb6(아래 표). (e) README :3 · 라운드 4 절 제목 · 표 ID 의 O5 → O3 정정 |
| S2 (low) GB 시나리오 ID 라벨 | 고침 | 하네스 :1282 주석(`G1–G9 = GB01–GB10 + GB11 · GB12`) · GB11/GB12 괄호 라벨 · `postDelErr` 주석(GB11 → GB12) = 실제 ID. README GB 행에 설계 번호 ↔ 실제 ID 대응 한 줄 |
| S3 = O2 (low) 「수동 대체 ②」 공유 DB | 고침 | ② 절 **안** 두 번째 문단(제목은 그대로 — gitops `platform/cnpg-databases/README.md` 3곳이 글자 단위로 인용 · 새 제목 ③ 안 만듦) + 펜스 1개(REVOKE/GRANT 네 문장 한 트랜잭션 · `datacl` 확인 두 명령) + 기대 `{=T/<db>_owner,<db>_owner=CTc/<db>_owner}`(PUBLIC 에 `c` 없음 · `<db>_app` 항목 없음 — Job init 컨테이너 ① SQL 과 같은 문장). 표식 없는 펜스라 하네스는 추출하지 않는다(R1 · R2 "펜스 정확히 1개" PASS 로 확인) |
| S4 (controller) 수치 확정 | 고침 | README :8 · :11 · :97 · 런북 :781 = 실측 시나리오 92 · 단언 2771. 91 → 92 는 O5 의 GA08 등록 때문(변이 rb6 은 등록 수에 들어가지 않는다) |
| O3 (low) 창 D 체크리스트 마지막 줄 | 고침 | 런북 사전 1 끝: 창 D 에서는 `$env:KUBECONFIG` 설정 · `kubectl config current-context` 줄을 건너뛴다(시드 블록 · 「정리 판단」 두 블록은 kubectl 0 — 사전 2). `vault-unseal.md` §0 :54 는 그대로(다른 절차의 전제) |
| O4 (low) 첫 실행 운영자 문구 | 고침(블록 변경 없음) | (a) 「실행」: 소요 ≈ 1분 미만 · Vault 호출 ≈ 27회(`version` 1 · `status` 1 · `token lookup` 1 · 판정 `metadata get` 6 · 경로마다 put · 되읽기 · metadata 3×6 — 재실행(전부 live-ok)은 15회; 지시문의 "≈ 20회" 분해 1+1+6+18 = 26 에 `vault version` 1 을 더해 블록 실측 수로 적었다) · 한 줄에서 1분 넘게 멈추면 창 C → 끊겼으면 연결 거부 · CLI 타임아웃 뒤 STOP(재실행 안전) (b) 재실행 문단: `Remove-Item Env:VAULT_TOKEN, Env:VAULT_ADDR` 만 · 창 C · 창 A 유지 · 전체 창 종료 체크리스트는 재실행 뒤 (c) 실패 표에 `요약 행 생성 예정(판정 absent — 쓰기 확인 전) · STOP 줄 없음` 행(정지점 ② 중지 · 쓰기 0 · 값을 만들지도 않았다 → 재실행) — 블록 :324 문구 그대로 (d) `INFO` 줄 확인에 "경로가 `vault.exe` 로 끝나는지(`.cmd`/`.bat` 래퍼도 `Application`)" |
| O5 (low) GA08 — ① 점검 블록의 과도기 상태 | 고침(하네스만) | GA08 등록(`Seed-LiveOk $P0; Seed-Tunnel; readGarbage` — metadata live · kv get 응답이 잘린 JSON 안에 비밀번호). 실측: ① 블록은 `ConvertFrom-Json` 종료 오류 `다음 오류로 JSON 변환에 실패했습니다. Unexpected end when reading token. Path 'data.data'.` 로 중단(앞의 상태 · 버전 이력 줄은 나온 뒤) — 화면 · `$Error`(메시지 · 예외 전문 · TargetObject) · 전역 · env 어디에도 값 없음(노출 0 단언 전부 PASS · 바늘 = 비밀번호 전체 · 8자 조각 · 해시) → **① 블록은 그대로**(try/catch 로 감싸지 않았다). Expect 는 로캘에 흔들리지 않는 Newtonsoft 부분 `Unexpected end when reading token` 으로 고정 |

- **red(하네스 먼저 — 런북 ①·② · §0 수정 전)**: `시나리오 PASS 68 / 92` · `PASS 2746 / 2771` · exit 1. FAIL = R1 · R2(`Set-Clipboard 0 곳 · Write-Warning 0 곳`) + GA01–GA08 · GB01–GB12(공통 단언 `clip:set=-1 · read:plain=0`) = 22 — 새 단언만 실패(GA08 은 Expect 문구 1건 추가 — 첫 실측 뒤 고정).
- **green(런북 ①·② + `vault-unseal.md` §0 수정 뒤)**: `시나리오 PASS 92 / 92` · `PASS 2771 / 2771` · exit 0 · `%TEMP%` 함정 디렉터리 잔여 0.
- **변이 시험(런북 사본 1개 · 세션 스크래치 `r6/` · `-Runbook`)** — 의도한 시나리오에서만 FAIL:

| 변이 | 잡은 시나리오 |
|---|---|
| rb6 런북: ① 점검 블록의 `try { Set-Clipboard -Value ' ' } catch { … }` 줄 삭제(② 는 그대로) | R1(정적 — `Set-Clipboard 0 곳 · Write-Warning 0 곳`) + GA01–GA08(공통 단언 `clip:set=-1`) = 11 · R2 · GB01–GB12 는 PASS — `시나리오 PASS 81 / 92` · `PASS 2760 / 2771` · exit 1 |

- 라운드 4 변이 표(mA–mD · rb1–rb5)는 다시 재지 않았다(기존 단언을 빼지 않았고, 이번에 더한 것은 R1 · R2 정적 1건 · 공통 단언 1건 · GA08 뿐이다).

---

## 5. 하네스가 증명하지 못하는 것

모의는 **가정한 CLI 출력 형식**을 되돌려줄 뿐이다. 첫 라이브 실행에서 확인한다 — 어긋나면 대부분 fail-closed(쓰기 0 또는 첫 경로에서 STOP)다.

1. **`vault status -format=json` 의 최상위 `initialized` · `sealed`(bool)** — T045 는 `curl … seal-status` 를 썼으므로 이 형식은 이 저장소에서 아직 라이브로 본 적이 없다(형식이 다르면 "도달 실패 또는 status 응답 해석 실패"로 토큰 전에 멈춘다). `vault status` 의 종료 코드 0 · 2 · 1 은 `vault-unseal.md` §0 문면.
2. **`kv metadata get` 이 없는 경로에서 내는 stderr `No value found at …`** — T044 VD-19 에서 `vault kv get` 의 `No value found`(exit 2)는 실측됐고 metadata get 은 같은 CLI 경로라는 가정이다. 문구가 다르면 6경로 전부 "판정 불가"로 멈춘다(쓰기 0).
3. `kv get -format=json` 의 `data.data` · `kv metadata get -format=json` 의 `current_version` · `versions.<n>.{destroyed,deletion_time}` · `token lookup -format=json` 의 `data.policies` 는 T045 라이브(2026-09-21)에서 쓰였던 형식이다. 삭제된 현재 버전에 대한 `kv get` 응답(모의는 data = null)은 블록이 쓰지 않는 경로라 확인 대상이 아니다.
4. **JSON stdin(VD-6)** — T045 블록이 2026-09-21 CLI v2.1.0 으로 실측했다. 블록은 `INFO vault CLI:` 줄로 현재 CLI 버전을 남긴다. 다르면 첫 경로의 되읽기 해시 대조가 잡지만, 그 경로에는 이미 v1 이 기록된 뒤다(런북 실패 시 표 — 머지 전이면 운영자 판단으로 정리 후 재실행).
5. **콘솔 고유 동작** — Ctrl+C 의 finally 절단(§3 의 `PowerShell.Stop()` 모의만 실측) · `FlushInputBuffer` 의 실제 type-ahead 소비 · 기본 콘솔 호스트의 빈 줄 종료. 방어만 했다. 비움 호출의 **위치**(Read-Host 바로 앞 직계 문장)는 수정 라운드 2 부터 S12 가 AST 로 고정하지만, 실제 콘솔에서 그 호출이 type-ahead 를 얼마나 지우는지는 재지 않았다.
6. **클립보드 · 레지스트리 · 전사 정책** — 하네스는 실제 `Set-Clipboard`/레지스트리를 부르지 않는다(호출 · 값만 센다).
7. **호스트 UI 직접 쓰기는 정적 규칙(S12)으로만 막는다.** 런타임 노출 검사의 화면 면은 `*>&1` 로 잡히는 스트림만 본다 — `$Host.UI.WriteLine` · `WriteErrorLine` 처럼 호스트 UI 에 직접 쓰는 출력은 스트림 밖이라 보지 못한다(리뷰 O1 변이 ①② 가 라운드 0 하네스를 46/46 으로 통과). S12 는 `$Host` · `$ExecutionContext` 를 `$Host.UI.RawUI.FlushInputBuffer()` 한 모양으로만 허용한다. 정적 규칙들(명령 · 정적 형식 · `$Host` 허용 목록)은 **실수로 생기는 회귀**를 막는 것이지, 일부러 우회하는 코드(형식 리터럴을 변수에 담아 `$c::WriteLine(…)` · 리플렉션 등)까지 막지는 못한다 — 블록 변경은 리뷰를 거친다. 수정 라운드 2 부터 이 규칙들은 런타임 시나리오보다 **먼저** 도는 관문이라 위반 블록은 하네스 안에서 한 번도 실행되지 않는다. 관문이 정적 규칙이라는 한계는 같으므로, 규칙을 비껴간 코드가 실행되더라도 운영자 자격에 닿지 않게 하네스 프로세스의 `KUBECONFIG` 는 없는 경로다(PATH 함정 · 함수 가림과 함께 — 절대 경로 호출 자체는 명령 규칙이 잡는다).
8. **VD — root 토큰이 `hvs.` 접두라는 가정.** Vault 1.10 이후 서비스 토큰(init 이 만드는 root 토큰 포함)의 형식으로 알고 있지만, T044 init 의 root 토큰은 에이전트가 본 적이 없다(PM 에만 있다). 가정이 틀리면 블록은 토큰을 Vault 로 보내기 **전에** 멈추고(fail-closed — 쓰기 0), 중단 문구가 "PM 의 다른 항목" 과 "형식 가정이 다르다" 를 함께 적는다(런북 실패 시 표 — 맞는 항목인데도 같은 줄이면 더 시도하지 않고 멈춘 뒤 보고). 첫 라이브 실행에서 확인한다.
9. **모듈 로깅 정책 검사의 범위.** 그룹 정책 레지스트리 키(PowerShellCore 2개 + 그 키의 `UseWindowsPowerShellPolicySetting` 이 1 일 때 Windows PowerShell 2개)만 본다. `powershell.config.json` 의 `PowerShellPolicies`(Windows 에서는 정책 키가 없을 때 쓰인다)는 보지 않는다 — 이 PC 는 2026-10-14 에 정책 키 12개(ModuleLogging · ScriptBlockLogging · Transcription × PowerShellCore · Windows PowerShell × HKLM · HKCU)가 모두 없고, `$PSHOME\powershell.config.json` 에 `PowerShellPolicies` 가 없으며, 사용자 `powershell.config.json` 이 없음을 읽기 전용으로 확인했다. 스크립트 블록 로깅(블록 원문에는 비밀이 없다)과 전사 정책(화면 출력에는 비밀이 없다 — 다만 정지점 입력이 전사에 어떻게 남는지는 확인하지 않았다)은 블록이 보지 않는다 — 창 시작 체크리스트 몫이다. 수정 라운드 4(결정 C7)에서 `vault-unseal.md` §0 의 체크리스트가 PowerShellCore 두 키(Transcription · ModuleLogging · ScriptBlockLogging)와 `UseWindowsPowerShellPolicySetting` 분기를 보게 고쳤고, 「비밀이 새는 6곳」에 모듈 로깅(이벤트 4103) 행을 더했다 — 그래도 `-MaskInput` 입력이 전사에 남는지는 여전히 미실측이다(전사 정책이 꺼져 있음을 체크리스트로 확인하는 것이 방어다).
10. **붙여넣기 창의 호스트 상태(수정 라운드 2 · 리뷰 O6).** 블록은 `Set-PSDebug` 만 끈다(§2 의 18 실측). 프로필이 정의한 함수 · 별칭(`vault` · `Read-Host` · `ConvertFrom-Json` 등)과 중단점(`Set-PSBreakpoint -Variable …`)은 블록이 감지하거나 막지 못하고(INFO 줄은 `vault` 의 종류만 보인다), 하네스도 이 경로를 재현하지 않는다. `-File -NoProfile`(권장)은 둘 다에 면역이고, 붙여넣기는 `-NoProfile` 로 새로 연 창에서만 한다(런북 사전 5).

## 6. 남은 위험(라이브 실행 시)

- **자식 프로세스의 `VAULT_TOKEN` 상속** — 블록이 부르는 `vault.exe` 는 env 의 root 토큰을 쓴다(설계상 필요). 실행하는 동안 같은 사용자의 프로세스 조사로 보일 수 있다. 실행 창은 블록 전용으로 쓰고 끝나면 닫는다.
- **메모리의 .NET 문자열**(비밀번호 · url · 토큰)은 0 으로 지울 수 없다 — 변수 참조만 끊는다. `pwsh -File` 권장 실행은 프로세스 종료로 끝낸다.
- **live-ok 는 "모양이 맞다"는 뜻이지 "PG role 의 실제 비밀번호와 같다"는 뜻이 아니다.** T054 이전에는 role 이 없으므로(DatabaseRole 이 kv 값으로 role 을 만든다) 지금은 문제가 없지만, 재실행 의미를 회전으로 오해하지 않게 런북에 적었다.
- **생성 값의 유일한 사본은 kv 다.** Vault 데이터 유실은 Raft 스냅샷(매일 02:30 KST · `platform-backup.sh`)으로만 복구된다 — 시드 직후 스냅샷 전 유실이면 재시드(경로 정리 후)가 복구다(소비자는 같은 값을 다시 받는다).
- **root 토큰 사용**(T044 D4) — revoke 는 T084 OIDC admin 실증 + break-glass 드릴 뒤. 이 블록은 root 를 요구한다(정책 목록에 `root`).
- 클립보드 기록 점검은 사용자 키 `HKCU\Software\Microsoft\Clipboard\EnableClipboardHistory` 만 본다(그룹 정책 · 클라우드 클립보드 동기화는 보지 않는다 — 창 시작 체크리스트 몫).
- **클립보드 비우기 실패는 경고만 한다**(수정 라운드 2) — 블록은 멈추지 않는다(멈춰도 클립보드의 토큰은 사라지지 않는다). 경고를 보면 그 자리에서 직접 비운다(런북 실패 표의 경고 행).
- **붙여넣기 실행의 부수 효과** — 첫 문장 `Set-PSDebug -Off` 가 그 창의 `Set-PSDebug` 추적과 **전역 strict 모드**를 끈다(세션 전체 설정 — 실측). 창은 끝나면 닫는다(창 종료 체크리스트).
- **머지가 먼저 되면 retry 가 저절로 회복시키지 않는다**(리뷰 K5) — Argo retry 는 ES 회복을 다시 기다리지 않고 ESO 재조정은 지수 백오프로 벌어진다. 원칙은 머지 전 시드이고, 늦었다면 런북 「늦은 시드」(ES 6장 `force-sync` 어노테이션 → `SecretSynced` 확인 → retry 를 다 썼으면 수동 Sync).
- **kv 경로 정리는 되돌릴 수 없다**(리뷰 O8 · r3 O7 · 결정 C6) — 런북 「정리 판단」의 두 블록(① 읽기 전용 점검 → 운영자 판단 → ② 삭제: 6경로 허용 목록 · 경로 재입력 Ordinal 일치 · 삭제 뒤 `No value found` 확인 · 실패 · 잔존 · 조회 오류 = 중단)만 쓰고, 머지 뒤에는 지우지 않는다. 두 블록은 하네스 R1 · R2 · GA · GB 가 런북 코드 펜스에서 그대로 추출해 시험한다 — 펜스 안을 고치면 하네스를 다시 돌린다.
- **put 비 0 의 재판정은 Vault 상태만 본다**(수정 라운드 4) — `기록됨(응답 유실 — 이 실행의 값)` 은 되읽기 해시가 메모리의 값과 일치했다는 뜻이라 정상 완료와 같지만, 그 줄이 나왔다는 것은 창 C port-forward 가 그 순간 끊겼다는 신호다(실행 기록에 남기고, 반복되면 port-forward 를 다시 세운다).
