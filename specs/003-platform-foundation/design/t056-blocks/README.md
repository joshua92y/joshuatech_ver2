# T056 운영자 블록 — Kafka SCRAM 비밀번호 kv 2경로 시드 · 모의 하네스 · 남은 위험

빌더 작업(2026-10-16 — 컨트롤러 지시서의 결정 B1–B8 · `../build-notes.md` 「T056」 D9 · D10) + 같은 날 수정 라운드 r1(리뷰 r1 렌즈 4 지적 H1 · H2 · H3 · R1 · R2 · D1 + 컨트롤러 결정 (b)의 C1 — §1 · §4 「수정 라운드 r1」). 산출물은 이 디렉터리 3파일과 런북 `docs/runbooks/bootstrap.md` §4 「T056 — Kafka SCRAM 비밀번호 시드(kv 2경로 · 랜덤)」 소절뿐이다. 선례 `../t054-blocks/`(T054 DB 자격 시드 — 닫힌 과제 · 수정하지 않았다)를 복사·파생했다. **운영자 실행 전** 상태다(라이브 실행 기록 없음 — 실행 기록은 런북 소절 끝에 남긴다).

| 파일 | 역할 |
|---|---|
| `op1-seed-kafka.ps1` | 운영자 블록(창 D) — 첫 문장 `Set-PSDebug -Off` → 세션 설정 고정(`$WhatIfPreference` · `$ConfirmPreference` · `$PSDefaultParameterValues`) → 창 전제(클립보드 기록 · 모듈 로깅 정책 · `~/.vault-token` · `VAULT_*`) → Vault 도달(토큰 없이) → root 토큰(보안 입력) · token lookup(`root`) → kv 2경로 판정(읽기 전용 — 경로별 모양 + 두 경로가 모두 live-ok 면 password 끼리 다른지(C1)) → 쓰기 확인 정지점(`seed`) → `-cas=0` 생성(키 `password` 하나) + JSON 되읽기 SHA-256 대조 + `current_version=1` 확인(put 비 0 은 값 없이 재판정) → finally 정리 · 요약 2행 |
| `harness.ps1` | 모의 실행 하네스(T054 하네스 파생) — 시나리오 100(시드 블록 72 + 런북 「정리 판단」 두 블록 28: R1 · R2 정적 · GA01–GA09 · GA03d · GB01–GB12 · GB03b · GB06b) · 단언 2608 · S12 정적 관문을 맨 먼저(관문 FAIL = 블록 실행 0회) · 실물 `vault`/`kubectl` 차단 가드 3중 · 하네스 프로세스의 `KUBECONFIG` 를 없는 경로로 덮음 · 런북 두 블록은 `bootstrap.md` 코드 펜스에서 그대로 추출(표식 `[t056-cleanup-inspect]` · `[t056-cleanup-delete]`) |
| `README.md` | 이 문서 — 결정 대응 · T054 블록과 다른 점 · 하네스 결과 · 남은 위험 |

실행: `pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t056-blocks\harness.ps1` → `PASS 2608 / 2608`(시나리오 100 / 100, exit 0 · 실행 시간 약 10초). 한 시나리오의 화면 출력은 `-Show 'S01'`, 변이 사본에 같은 시나리오를 돌리려면 `-Block <경로>`(시드 블록) · `-Runbook <경로>`(런북 사본 — 「정리 판단」 두 블록을 그 파일의 코드 펜스에서 추출한다).

---

## 1. 컨트롤러 결정(B1–B8 · 수정 라운드 r1 의 C1) 대응

| ID | 결정 | 한 일(파일:줄) |
|---|---|---|
| B1 | 경로 2 | 블록 `$paths`(op1-seed-kafka.ps1:61–63) — `kv/prod/kafka/identity-admin`(KafkaUser `identity-admin` · ExternalSecret `data/kafka-user-identity-admin` · 뒤에 `vault-prod` 의 `<pod>-env`) · `kv/dev/kafka/identity-admin`(KafkaUser `dev-identity-admin` · ExternalSecret `data/kafka-user-dev-identity-admin` · 검사 Job 의 `jt-dev/assert-env` 가 같은 경로 `property: password` 를 읽는다). 머리 주석 :7–9. 쓸 경로 목록 줄이 경로마다 KafkaUser · ExternalSecret 이름을 보인다(:355). 하네스 계약 `$PATHS`(harness.ps1:55–57 — S01 이 목록 줄을 대조) · 런북 소절 「경로·값」 표 |
| B2 | 키 `password` 하나 · `RandomNumberGenerator` 32바이트 → base64url 43자 | 블록 `$keys = @('password')`(:60) · 생성 :168–170(T054 와 같은 생성기 · 43자 자기 검사) · 쓰기 값 `[ordered]@{ password = $pw }`(:171) · `vault kv put "-cas=0" <경로> -`(:175 — JSON stdin). 하네스 S01(put 본문 키 = `password` 하나 · 저장 키 1 · 43자 · 경로마다 다른 값) |
| B3 | live 판정 | 블록 `$judge`(:136–160): 키 집합이 정확히 `{password}`(Ordinal — 여분 키 `username` 포함 불일치 = mismatch) · 값이 문자열 · `\A[A-Za-z0-9_-]{43}\z`(:157) → `ok` = `SKIP … live-ok`. 아니면 mismatch 사유를 값 없이 낸다(`password 길이가 43이 아니다(…)` · `password 에 base64url 밖의 문자가 있다(…)` · `키 집합 불일치(누락: … · 여분 N개)` · `password 값이 문자열이 아니다`). dead · error 는 `$state`(:111–133) · `$judge` 의 조회 · 해석 실패로 T054 와 같이 STOP(덮어쓰기 0 · 자동 교정 0). 하네스 S04a–i · S05a–c · S19 · S19b |
| B4 | 그 밖은 T054 블록과 동일 | 첫 문장 `Set-PSDebug -Off`(:45) · 세션 설정 고정(:48–57) · 창 전제(:243–259 — 클립보드 기록 · 모듈 로깅 정책 4키 · `~/.vault-token` · `VAULT_*`; HistorySaveStyle · 전사는 T054 와 같이 머리 주석 사전 ①과 런북 사전 1의 창 시작 체크리스트 몫) · `vault` 명령 종류 · 경로 `INFO` 줄(:260–270) · Vault 도달(:271–285) · root 토큰 보안 입력 + 클립보드 비우기(:84–89 · :287–291) · token lookup `root`(:293–301) · 판정 단계(:302–351 — 그 안의 쌍 판정 :334–344 는 C1 행) → `seed` 정지점(:352–359) → 쓰기 + 되읽기(:360–362 · `$write` :163–241 — put 비 0 재판정 · SHA-256 Ordinal · `current_version=1`) · finally(:364–391 — env(VAULT_TOKEN 부터) · 비밀 변수 · 클립보드 · `$Error` · 요약 2행 · 창 종료 체크리스트). 머리 주석은 Kafka 2경로 문구로 바꾸고 T054 블록을 선례로 가리킨다(:2–44 · :3–4). 하네스 경로 = `t056-blocks/harness.ps1`(:44). T054 블록과 다른 줄은 §2 |
| B5 | 하네스 | `harness.ps1` — §4. 기본 블록 `op1-seed-kafka.ps1` · 런북 표식 `[t056-cleanup-inspect]` · `[t056-cleanup-delete]` · `$PATHS` 2행 · `$LIVE_PW` 2개(`MOCK-` 가짜 43자) · DB 전용 헬퍼 삭제 · S12 관문 유지 · 추가 (ⅰ) S04b (ⅱ) S04d · S04e (ⅲ) S03 · S03b · 과도 상태 시나리오 전부 유지(B5 목록의 「token lookup 실패」는 T054 하네스에도 없던 공백이었다 — 수정 라운드 r1 에서 S14b 로 채웠다 · 리뷰 r1 H1) · GA · GB 는 T056 런북 소절에서 추출. 수정 라운드 r1 추가: S14b(H1) · S04f2 · S04f3 + `$LIVE_PW` prod 값의 `_`(H2 — B3 문자 집합 고정) · S09d · GB06b(H3 — 대소문자만 다른 변형) · S04j · S04k(C1) |
| B6 | README | 이 문서(§1–§6 — T054 README 구조) |
| B7 | 런북 §4 T056 소절 | `docs/runbooks/bootstrap.md` §4 `### T056 — Kafka SCRAM 비밀번호 시드(kv 2경로 · 랜덤)`(T054 소절 뒤 · `## §5` 앞): 목적 · 언제(머지 전 — gitops README §0 P1) · 경로·값 표 · 사전 · 실행(소요 · Vault 호출 수 = 하네스 S01 · S17 이 센 값) · 기대 출력(하네스 S01 화면 출력 기반) · 판정 · 실패 시 표 · 정리 판단 ① 점검 · ② 삭제(두 코드 펜스 — 하네스가 추출해 시험) · 머지 뒤 확인(ES 2 · KafkaUser 2) · 늦은 시드 · 회전은 범위 밖 · 실행 기록 자리. DB 전용 「수동 대체 ①②」는 넣지 않았다. §4 머리(소절 목록 · 안내 문장 없음 — T054 만 가리키는 문장이 없다)는 바꾸지 않았다 |
| B8 | 비밀 취급 | 블록 · 런북 두 블록: `MOCK` 0 · 비밀처럼 보이는 상수 0 · `hvs.<영숫자>` 0(S12 · R1 · R2). 하네스의 가짜 값은 전부 `MOCK-` 를 포함한다. 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드 · 전사 어디에도 나오지 않는다 — 하네스 공통 사후 조건(노출 0 · 8자 조각 · SHA-256 hex 바늘 · 성공 스트림 0 · 클립보드에는 공백만)이 런타임 시나리오 97개 전부(정적 S12 · R1 · R2 를 뺀 나머지)에서 단언한다 |
| C1 | (리뷰 r1 · 컨트롤러 결정 (b) — B3 밖의 새 기대) 두 경로가 모두 live-ok 면 password 가 서로 달라야 한다 — dev 값은 `jt-dev` 의 `assert-env` 로도 복사되므로 같으면 dev 노출이 곧 prod SCRAM 노출이다 | 블록 `$judge` 가 ok 일 때 password 의 SHA-256 hex `h` 를 함께 돌려준다(:160 · 주석 :134) → 판정 단계가 live-ok 경로의 `h` 를 모으고(:306 · :317) 루프 뒤 두 개가 Ordinal 로 같으면 두 경로를 모두 `STOP <경로> — prod 와 dev 의 password 가 같다 — …`(:334–342 — `$nSkip` → `$nStop` · 요약 행 `중단(prod 와 dev 의 password 가 같다 — 값 미출력 · 쓰기 0)`)로 바꾼다 → `판정 단계에서 중단`(쓰기 0). 비교에 쓴 해시는 비교 직후 버린다(`$okHash = $null` · `$j = $null` :343–344 · finally `Remove-Variable` 의 `okHash` :369 — 원칙 (e)(f)). 한쪽만 live-ok 거나 absent 가 섞이면 해당 없다(새로 만드는 값은 경로마다 독립 RNG — S01 · S03 · S03b). 머리 주석 :38. 하네스 S04j(같은 값 → 두 경로 STOP · 쓰기 0 · 노출 0) · S04k(대소문자 한 글자만 다른 두 값 → 둘 다 SKIP · 정상 종료 — Ordinal 비교 고정). 런북 실패 표 「prod 와 dev 의 password 가 같다」 행 · 「정리 판단」 예외 문구. STOP 뒤 조치 = **두 경로 모두** 지우고 재생성(머지 전 — 남기는 쪽도 블록 밖을 거친 값 · 리뷰 r2 R3 · K7 · 컨트롤러 정정) · 머지 뒤에는 회전(T084) |

### 원칙 (a)–(h)(블록 머리 주석 :25–36 과 같다 — T054 그대로)

(a) 사람 동작마다 정지점 — 입력 버퍼를 비운 뒤 단어 입력 · (b) 판정(읽기 전용)과 쓰기를 단계로 분리 — 판정에서 STOP 이 하나라도 나오면 kv 쓰기 0 · (c) 쓰기는 `-cas=0` + JSON stdin 뿐(live 판정 + CAS 이중으로 덮어쓰기 차단) · (d) 되읽기는 JSON + SHA-256 Ordinal + `current_version=1`, 실패하면 다음 경로로 가지 않는다 · (e) 값 · 해시 · 토큰은 화면 · argv · 파일 · 클립보드 · 전사에 나오지 않는다(출력은 `Write-Host`/`Write-Warning` 뿐) · (f) 생성 값의 유일한 사본은 kv — put 이 비 0 이어도 "쓰지 않았다"고 단정하지 않고 값 없이 재판정한다(absent = 쓰지 않았다 · live v1 + 해시 일치 = `기록됨(응답 유실 — 이 실행의 값)` · 다르면 CAS 충돌 STOP · 재판정 불가 = `결과 미확인`) · (g) 정리는 조건부 — 블록이 만든 `VAULT_TOKEN` 만 지우고, 시작 전에 있던 `VAULT_*` 는 건드리지 않은 채 중단 · (h) finally 가 성공 · 실패 · 중지 어느 쪽이든 env(`VAULT_TOKEN` 이 첫 문장) · 비밀 변수 · 클립보드 · `$Error`(이 실행분)를 먼저 정리하고 요약을 낸다. 세션의 `$WhatIfPreference` · `$ConfirmPreference` · `$PSDefaultParameterValues`(-WhatIf)가 이 정리를 조용히 건너뛰게 하지 못하도록 블록 범위에서 셋을 고정한다.

---

## 2. T054 블록(`../t054-blocks/op1-seed-db.ps1`)과 다른 점 — 의도

`git diff --no-index` 로 두 블록을 대조하면(수정 라운드 r1 뒤 — 블록 392줄) 다른 줄은 머리 주석 · 본문 주석 3줄(:46 · :53 · :248 — 의미 변화 없음) · 상수와 경로 표(:60 · :62–63) · `$judge` 의 주석과 끝부분(:134–135 · :157–160 — username/url 대조 삭제 · B3 규칙 · ok 면 해시 `h`) · `$write` · `INFO` 줄 출처 문구(:270) · 판정 단계의 쌍 판정(:306 · :317 · :334–344 — 아래 7 · C1) · finally `Remove-Variable` 목록의 `okHash`(:369) · 출력 문구뿐이다. `$write` 는 값 조립(:171) · 변수 초기화와 정리(:165 · :241) · OK/요약 문구(:238–240)만 다르다. 헬퍼(`eq` · `has` · `sha` · `stop` · `readSecret` · `firstErr` · `parseJson` · `prop` · `state`) · 창 전제 · 토큰 형식 · 판정 단계의 경로별 상태 기계 · 쓰기 단계 · put 비 0 재판정 · finally 의 정리 순서 · 요약 집계 범주는 줄 단위로 같다.

1. **경로 2(B1).** `$paths` 의 열은 `path` · `user`(KafkaUser 이름) · `es`(ExternalSecret 이름)다 — T054 의 `db` 열은 없다. `user` 는 kv 에 쓰지 않고 쓸 경로 목록 줄(`(KafkaUser=… · ExternalSecret=…)`)에만 쓴다.
2. **키 1(B2).** `$keys = @('password')` · 쓰기 값 `{password}`. SCRAM 사용자 이름은 KafkaUser 이름이라 비밀이 아니고(data-model §8 `kv/{env}/kafka/<pod>` 키 `password`), Kafka 클라이언트 설정에는 url 이 없다.
3. **live 판정 규칙(B3).** T054: 키 3 · username = role 이름 · password 길이 ≥ 32 + URL 비예약 문자 · url = 접두 + password + 접미. T056: 키 집합 **정확히** `{password}` · 문자열 · base64url **정확히 43자**(`\A…\z` — 앞뒤 공백 · 끝 개행 불가). 여분 키 `username`(누가 T054 모양으로 넣은 경우 포함)은 mismatch 다 — 블록은 지우지도 고치지도 않는다. 길이와 문자를 따로 알린다(`password 길이가 43이 아니다(…)` / `password 에 base64url 밖의 문자가 있다(…)`) — 표준 base64(`+` `/` · 패딩 `=`)로 넣은 값이 흔한 실수다.
4. **삭제된 DB 헬퍼 · 상수.** 블록: `$pgHostPort` · `$pgQuery` · url 조립 · url 접두/접미/비밀번호 부분 대조 · username = role 대조. 하네스: `Url-For` · `$URL_HOST` · `$URL_QUERY` · url 바늘(`NFulls` — url 전체 + 그 안의 비밀번호) · tamper `username` · `url` 모드 · username/url 전용 시나리오(§4).
5. **문구.** 요약 머리 `--- T056 Kafka SCRAM 비밀번호 시드 결과 요약(값 없음 — 런북 bootstrap.md §4 T056 소절에 그대로 기록) ---` · 요약 행 폭 `{0,-30}`(T054 `{0,-36}` — 경로가 짧다) · SKIP 줄 `live-ok(키 1 = password · base64url 43자 형식 확인 — …)` · OK 줄 `되읽기 해시 일치(password)` · 판정 줄 `kv 2경로 준비 완료 … ExternalSecret 2장 … SecretSynced 와 KafkaUser 2 Ready` · 실패 안내의 런북 소절 = §4 T056. `INFO vault CLI` 줄의 JSON stdin 근거 = T045 블록(2026-09-21 · VD-6 실측) + T054 블록 첫 실행(2026-10-15 · 6경로 되읽기 해시 일치 · CLI v2.1.0).
6. **머리 주석의 실행 뒤 확인.** ES 2장 `SecretSynced` + KafkaUser 2 `Ready`. 머지가 먼저 된 경우(늦은 시드)에는 wave 0 ExternalSecret 이 Degraded 인 채 operation 이 wave 1(KafkaUser)을 적용하지 못하므로, force-sync 뒤 재시도가 끝났으면 수동 전체 Sync 가 필요하다는 것까지 적었다(런북 「늦은 시드」 4 · 5).
7. **prod/dev 쌍 판정(C1 — 수정 라운드 r1 · 컨트롤러 결정 (b) · T054 에는 없다).** 판정 단계의 경로 루프는 T054 와 같고, 루프 뒤에 한 단계를 더했다: 두 경로가 모두 live-ok 면 `$judge` 가 돌려준 password 의 SHA-256 hex 둘을 Ordinal 로 비교해 같을 때 두 경로를 모두 STOP 으로 바꾼다(`판정 결과: 생성 예정 0 · 건너뜀(live-ok) 0 · 중단 2` · 요약 2행 `중단(prod 와 dev 의 password 가 같다 — 값 미출력 · 쓰기 0)`). 화면에는 경로별 `SKIP … live-ok` 2줄(모양 판정)이 먼저 나오고 쌍 판정 `STOP` 2줄이 뒤에 나온다 — 경로 루프의 출력 순서를 T054 와 같게 두려고 STOP 을 루프 뒤에 따로 냈다. 값 · 해시는 출력하지 않고, 비교에 쓴 해시는 비교 직후 버린다(원칙 (e)(f)).

### 메모리 규칙 「판정과 변경을 한 블록에 섞지 않는다」와 이 블록

T054 README §2 의 분석(컨트롤러 결정 C6 · 2026-10-14)이 그대로 적용된다. 시드 블록 안의 판정(`kv metadata get` → live 면 `kv get` 모양 판정)은 **운영자에게 판단을 묻는 단계가 아니라 쓰기 보호 가드**다 — ① 실행 간 상태 인계 없음(판정 결과를 운영자가 어디에도 옮겨 적지 않고, 재실행은 Vault 상태에서 판정을 다시 도출한다) ② 쓰기 직전 단어 정지점(`seed` — 쓸 경로 목록만 · 운영자의 결정은 "absent 경로에 새 값을 넣는다/않는다" 하나이고 머지 전이면 「정리 판단」으로 되돌릴 수 있다) ③ `-cas=0` 이중 방어(판정이 틀려도 서버 CAS 가 덮어쓰기를 거부한다 — S08a). 되돌릴 수 없는 kv 삭제는 운영자 판단이 들어가는 변경이라 런북 「정리 판단」의 **① 점검 블록**(읽기 전용)과 **② 삭제 블록**(2경로 허용 목록 · 경로 재입력 · 삭제 뒤 `No value found` 확인)으로 나눴고, 두 블록은 하네스가 런북 코드 펜스에서 그대로 추출해 시험한다(R1 · R2 · GA · GB).

---

## 3. 붙여넣기 · 중지 안전성

T054 블록과 같은 규약이다(실측 근거는 T054 README §3 · §2 의 18 · 22).

- 전체가 최상위 문장 1개(`& { … }`) — PSReadLine 이 중괄호가 닫힐 때까지 입력을 모아 한 번에 파싱 · 실행한다. 빈 줄 0 · TAB 0 · 끝 `}` + LF 1개(S12).
- 정지점 2개뿐: ① root 토큰(보안 입력 — 빈 입력 = 중단 · 붙여넣은 직후 클립보드를 비운다 · `hvs.` 형식이 아니면 Vault 로 보내지 않는다) ② `seed`(쓰기 확인 — `-MaskInput` · Ordinal 정확 일치 · 쓸 경로가 0 이면 나오지 않는다). 둘 다 바로 앞 직계 문장이 `$Host.UI.RawUI.FlushInputBuffer()`(S12 가 AST 로 고정). 다른 단어 · 빈 Enter · `" seed"` · `SEED` = 쓰기 0 으로 중단(S06a–d).
- 권장 실행은 `pwsh -NoProfile -File '<절대 경로>'`(새 프로세스 — env · 변수 · `$Error` 가 프로세스와 함께 사라지고 프로필이 없다). 붙여넣기는 `pwsh -NoProfile` 로 새로 연 창에서만 안전하다(첫 문장 `Set-PSDebug -Off` · 세션 설정 고정 3문장 — 프로필이 정의한 함수 · 별칭 · 중단점은 블록이 막지 못한다).
- 중지(Ctrl+C): finally 첫 두 문장이 블록이 만든 `VAULT_TOKEN` · `VAULT_ADDR` 제거다(S12). put 도중 중지되면 그 경로의 요약은 `결과 미확인` 이고 재실행이 판정한다(S21a · S21b — 모의 put 이 커밋 뒤 예외를 던지는 것으로 대신 시험). 콘솔 Ctrl+C 자체는 모의할 수 없다(§5 의 5).

---

## 4. 하네스(`harness.ps1`)

### 모의 방식 · 가드(T054 하네스 그대로)

- PowerShell **함수가 native 명령보다 우선**하는 성질로 `vault`·`kubectl`(+ `vault.exe`·`kubectl.exe`·`curl`·`curl.exe`·`oci`·`gh`)을 가리고, `Read-Host`(`-AsSecureString` · `-MaskInput` 여부 · 호출 시점의 화면 출력 수) · `Set-Clipboard`(실패 결함 · 실물처럼 ShouldProcess) · `Get-Clipboard` · `Get-ItemProperty`(클립보드 기록 설정 + 모듈 로깅 정책 키 4개) · `Test-Path`(`~/.vault-token`) · `Set-PSDebug`(`-Off` 만 이벤트 · 그 밖은 위반)를 모의한다. 실제 클립보드 · 레지스트리 · `~/.vault-token` 은 건드리지 않는다.
- **S12 정적 관문이 맨 먼저**: 관문 단언 5개(파서 오류 0 · 명령 · 정적 .NET 형식 · `$Host` · 파일 리다이렉트 허용 목록)가 전부 PASS 일 때만 런타임 시나리오를 돌린다 — 하나라도 FAIL 이면 블록을 한 번도 실행하지 않고 exit 1.
- **실물 차단 가드 3중**: ① 함수 가림 ② 실물 `vault`·`kubectl` 디렉터리를 하네스 프로세스 PATH 에서 빼고 맨 앞에 함정 디렉터리(`vault.cmd` · `kubectl.cmd` — 불리면 표식 파일 + exit 97) · `KUBECONFIG` 를 함정 디렉터리 안의 없는 경로로 덮음(끝나면 복원) ③ 블록을 돌리기 직전마다 ①②를 다시 확인 · 시나리오마다 함정 표식 0 단언. 함정 디렉터리(`%TEMP%\t056-harness-trap-<guid>`)는 끝나면 지운다.
- 가짜 Vault = 메모리 kv v2(버전 · 메타데이터 · soft-delete/destroy · CAS). 모의 `vault` 는 허용 목록(`version` · `status` · `token lookup` · `kv metadata get` · `kv get` · `kv put`)만 답하고 그 밖(delete · destroy · patch · `-field` · argv `k=v` · put 이 아닌 호출의 stdin)은 위반이다. `kv metadata delete` 는 런북 ② 삭제 블록 시나리오에서만 답한다.
- **과도 상태 모의(T054 그대로 전부 유지)**: metadata 거짓 `No value found` · 빈 응답 · 500 · 되읽기 실패 · 깨진 JSON(안에 비밀번호 — 판정 단계 · 쓰기 뒤 되읽기 · ① 점검 블록) · 저장 때 값 변형(`tamper`) · put 거부 · put 응답 유실 뒤 자기 CAS 충돌(`putLost`) · put 성공 뒤 metadata 만 바꾸기(`postMeta` `cv2` · `deletion` · `err`) · put 도중 중단(`putInterrupt`) · 클립보드 비우기 실패 · 삭제 실패 · 삭제 noop · 삭제 뒤 조회 오류.
- **T056 에 맞춘 모의 · 계약**: `$PATHS` 2행(`path` · `ku` = KafkaUser · `es` = ExternalSecret — 쓸 경로 목록 줄 대조용) · `$RE_PW` · `$LIVE_PW` 2개(`MOCK-live…` 43자 — prod 값에 `_`(리뷰 r1 H2) · 시나리오 시작 전에 하네스가 base64url 43자인지와 `_` 가 든 값이 있는지를 스스로 확인) · `FAKE_WRONG_TOKEN`(형식(`hvs.`)은 맞는 root 아닌 토큰 — 모의 Vault 가 403 · S14b) · `Live-Data` = `{password}` · `tamper` 모드 = `password`(마지막 글자) · `passwordCase`(첫 영문자의 대소문자만 — 리뷰 r1 H3 · 영문자가 없으면 위반) · `dropKey`(password 키 제거) · `extraKey`(`note` 추가) · 깨진 JSON 은 password 값을 담은 채 잘린다 · 노출 바늘 = kv 의 `password` 값(키 이름 Ordinal) + put stdin 의 `password` + root 토큰 + 시나리오가 더한 값(대소문자가 다른 키 `Password` 의 값 · 터널 토큰 등) — `username`(KafkaUser 이름) · `note` 같은 비밀 아닌 값은 바늘이 아니다(경로 · 이름 출력이 거짓 양성이 되지 않게 · S02 자체 시험).
- **런북 두 블록의 추출**: `docs/runbooks/bootstrap.md`(또는 `-Runbook <사본>`)에서 표식 주석(`[t056-cleanup-inspect]` · `[t056-cleanup-delete]`)이 든 ```` ```powershell ```` 코드 펜스를 정확히 하나씩 찾아 펜스 들여쓰기를 뗀 본문을 `[scriptblock]::Create` 로 그대로 돌린다 — 운영자가 붙여 넣는 텍스트와 하네스가 시험하는 텍스트가 같다. 가짜 kv 에는 2경로 밖의 소비 중 경로(`kv/platform/cloudflare/tunnel` · T054 의 `kv/prod/db/identity_admin/owner` — 가짜 값)도 둔다.
- 가짜 값은 전부 `MOCK-` 이 들어간 누가 봐도 가짜인 문자열이고 이 하네스 파일에만 있다.

### 모든 시나리오의 공통 사후 조건(T054 그대로)

1. **비밀 노출 0** — 바늘 = 비밀 전체 · base64 · 8자 조각 전부 · SHA-256 hex(대문자 · 소문자 전체 + 앞 16자). 면 = 화면(`*>&1` — 모든 스트림) · `Read-Host` 프롬프트 · 모의 명령 argv · 클립보드 기록 · `$Error`(메시지 · 예외 전문 · TargetObject · ErrorDetails) · 이 시나리오에서 생기거나 바뀐 전역 변수 · 환경 변수. 호스트 UI 직접 쓰기는 S12 정적 규칙이 막는다(§5 의 7).
2. `VAULT_TOKEN` · `VAULT_ADDR` 없음(시작 전에 있던 경우는 "건드리지 않음").
3. 위반 0 · 함정 표식 0 · 성공 스트림 0 · 클립보드에는 공백만 · 비밀 입력은 전부 `-AsSecureString` · 입력은 전부 가려진다 · `kv put` 은 전부 `-cas=0` + stdin · `seed` 정지점 전 put 0 · finally 요약 · 창 종료 체크리스트 · 첫 동작 = `Set-PSDebug -Off` 1회 · root 토큰 프롬프트까지 간 시나리오는 `INFO vault CLI` 줄이 그 프롬프트보다 먼저 · (완주 시나리오) 입력 전부 소비.
4. 런북 블록(Run-RbCase): 창의 `VAULT_ADDR` · `VAULT_TOKEN` 그대로 · Read-Host 평문(보안 입력 0) · `kv put` 0 · ① 점검 블록은 `kv metadata delete` · put 0 · 성공 스트림 0 · 노출 0 · 첫 Read-Host 전 클립보드 비움(`clip:set` < `read:plain` · 값은 공백만).

### T054 하네스와 달라진 시나리오

| 구분 | T054 | T056 |
|---|---|---|
| 삭제(username/url 전용) | S04b username ≠ role · S04c url 의 비밀번호 ≠ password · S04f url 접미(DB) 다름 · S04j url 사용자 부분 ≠ username · S09b url 한 글자 변형 · S09c username 한 글자 변형 | 없음(키가 없다) |
| 추가 — B5 (ⅰ) | — | **S04b** live 경로에 형식이 맞는 `password` + 여분 키 `username`(KafkaUser 이름) → `live-mismatch: 키 집합 불일치(누락: 없음 · 여분 1개)` · 쓰기 0 |
| 추가 — B5 (ⅱ) | (S04d 길이 < 32) | **S04d** 길이 42 · **S04e** 길이 44(base64url 문자뿐) → `password 길이가 43이 아니다` · 쓰기 0 |
| 추가 — B5 (ⅲ) | (S03 2경로 live-ok · 4 생성) | **S03** prod 만 live-ok · dev absent / **S03b** 역순 → SKIP 1 · 생성 1 · 요약 2행(건너뜀 · 생성) · live 경로 버전 · 값 불변 · vault 호출 9 |
| 추가 — 그 밖 | — | **S04c** T054 모양(username · password · url 3키)이 Kafka 경로에 있다 → 여분 2 · **S04i** `password` 와 대소문자만 다른 `Password` 가 함께 있다 → PowerShell JSON 해석 거부 = `판정 불가` STOP(live-ok 아님 · 값 미출력) · **GA09** 같은 값을 ① 점검 블록이 만나면 키 이름만 담은 JSON 변환 오류로 끝난다(값 0) · **GA03d · GB03b** T054 경로(`kv/prod/db/identity_admin/owner`)는 2경로 밖 → vault 호출 0 · R1 · R2 정적 단언 「허용 경로 상수 = 계약 2경로 정확히(Ordinal 집합)」 |
| 수정 | S04a 키 누락(url) · S04e 여분 키(note) · S04g password 에 `@` · S04h 숫자 · S04i 43자 + LF(url 도 같은 값) | S04a 키 이름 대소문자 다름(`Password` 하나 — 누락 password · 여분 1) · (S04b 로 흡수) · S04f 43자에 표준 base64 `+` `/` → `base64url 밖의 문자` · S04g 숫자 그대로 · S04h 43자 + LF → `길이가 43이 아니다`(`\z` 앵커 고정) |
| 수정 — 되읽기 대조 | S09 password · S09d dropKey(url) · S09e extraKey(note) | S09 password 변형(prod — 다음 경로 dev 미실행 단언) · S09b dropKey(password · dev — prod 생성 뒤) · S09c extraKey(prod — dev put 0) |
| 수정 — 2경로 재배치 | 6경로 기준(앞 경로 생성 · 뒤 경로 미실행) | 실패 위치를 prod(다음 경로 미실행 단언 — S08d · S09 · S09c · S16 · S20b · S20c · S21a) 또는 dev(앞 경로 생성 단언 — S08a · S09b · S16e · S20a)로 나눠 둘 다 고정 · S01 put 2 · vault 호출 11 · 요약 2행 · S17 2 SKIP · vault 호출 7 · S08e · S21b 재실행 복구 put 1 |
| 수정 — 단언 추가 | — | S01: put 본문(stdin JSON) 키 = `password` 하나 · 쓸 경로 목록 줄의 KafkaUser · ExternalSecret 이름 · vault 호출 11 · 요약 2행 / S02: 경로 · KafkaUser · ExternalSecret 이름은 바늘이 아니다 · 끝 8자 조각 / S11a: 전역 변수에 put 본문(`"password"`) · 토큰 모양 0 |
| 그대로(과도 상태 · 창 전제 · 정적) | S05a–c · S06a–d · S07a–f · S08a–e · S10a–e · S11a–f · S12 · S13a–b · S14 · S15 · S16 · S16d · S16e · S17–S19b · S20a–c · S21a–b · S22a–d · R1 · R2 · GA01–GA08 · GB01–GB12 | 같은 시나리오(경로 · 기대 문구만 2경로 · 키 1 로) |
| 추가 — 수정 라운드 r1(리뷰 r1 · 2026-10-16) | (T054 하네스에도 없다) | **S14b**(H1 — B5 유지 목록의 「token lookup 실패」): 형식은 맞지만 root 가 아닌 토큰(`FAKE_WRONG_TOKEN`) → 모의 403 · exit 2 → `root 토큰 확인 실패(token lookup exit=2)` · token lookup 1 · metadata get 0 · put 0 · `VAULT_TOKEN` 제거 · 노출 0 / **S04f2** 43자에 `=`(base64url 42자 + 패딩) · **S04f3** 43자에 `.` · `~`(T054 판정 문자 집합) → `password 에 base64url 밖의 문자가 있다` · 쓰기 0 + `$LIVE_PW` prod 값에 `_`(H2 — `_` 수용을 S03 · S17 이 결정적으로 고정) / **S09d** tamper `passwordCase` → `되읽기 해시 불일치(password)` · dev 미실행 · **GB06b** ② 삭제 재입력을 경로 전체 대문자로 → `입력이 경로와 다르다` · 삭제 0(H3 — 대소문자만 다른 변형) / **S04j** 두 경로에 같은 43자 값 → 경로별 SKIP 2줄 뒤 쌍 판정 STOP 2줄 · `판정 결과: … 건너뜀(live-ok) 0 · 중단 2` · 쓰기 0 · 정지점 없음 · 노출 0 · **S04k** 대소문자 한 글자만 다른 live-ok 두 값 → 둘 다 SKIP · 쓰기 0 · 정상 종료(C1 — Ordinal 비교 고정) |

시나리오 수: 시드 블록 68 → 66(삭제 6 · 추가 4: S03b · S04c · S04e · S04i) → 수정 라운드 r1 에서 72(추가 6: S04f2 · S04f3 · S04j · S04k · S09d · S14b) · 런북 두 블록 24 → 27(추가 GA03d · GA09 · GB03b) → r1 에서 28(추가 GB06b) · 합계 92 → 93 → 100.

### 시나리오와 결과(2026-10-16 수정 라운드 r1 · `PASS 2608 / 2608` · 시나리오 100 / 100 · exit 0 · 실행 시간 약 10초 — S12 가 맨 먼저 · 런북 블록 R1 · R2 → GA · GB 는 맨 뒤)

| id | 시나리오 | 결과 |
|---|---|---|
| S12 | **맨 먼저 · 관문**(파서 오류 0 · 명령 · 정적 형식 · `$Host` · 리다이렉트 허용 목록) · 첫 줄 `& {` · 최상위 문장 1 · 빈 줄 0 · 끝 `7D 0A` · BOM/CR/TAB 0 · UTF-8 · 본문 첫 문장 `Set-PSDebug -Off`(1곳뿐) · 세션 설정 고정 3문장 · try 1 + finally · finally 출력 규칙 · finally 첫 두 문장 = env 제거 · Read-Host 는 정지점 헬퍼 2곳 + 바로 앞 입력 버퍼 비움(AST) · vault 호출 모양(put = `"-cas=0"` … `-` · `-field` 0) · `MOCK` 0 · 비밀처럼 보이는 상수 0 · `hvs.<영숫자>` 0 · `Start-Transcript` 0 | PASS |
| S01 | 2경로 absent → 2개 생성(v1 · 키 1 = password · base64url 43자 · 경로마다 다른 값) · put 본문 키 = password 하나 · 쓸 경로 목록 줄(KafkaUser · ExternalSecret 이름) · 판정 → 정지점 → 경로마다 put → 되읽기 → metadata 순서 · `seed` `-MaskInput` · `INFO` 줄 · 모듈 로깅 정책 키(PowerShellCore 2)를 토큰 입력 전에 읽음 · vault 호출 11 · 요약 2행 | PASS |
| S02 | 노출 검사 + 검출기 자체 시험(비밀번호 앞 · 가운데 · 끝 8자 · 토큰 앞 8자를 잡고, 경로 · KafkaUser · ExternalSecret 이름은 잡지 않는다 · 비밀번호 · 토큰의 SHA-256 hex 대문자 · 소문자 · 앞 16자) | PASS |
| S03 · S03b | (B5 ⅲ) 한 경로만 live-ok(prod / dev) · 나머지 absent → SKIP 1 · 생성 1 · 요약 2행 · live 경로 버전 · 값 불변 · put 1(live 경로 0) · vault 호출 9 | PASS × 2 |
| S04a–i · S04f2 · S04f3 | live-mismatch(쓰기 0 · 정지점까지 가지 않음 · live 경로 버전 불변 · 다른 경로 absent): 키 이름 `Password` · (B5 ⅰ) 여분 키 `username` · T054 모양 3키 · (B5 ⅱ) 길이 42 · 길이 44 · 표준 base64 `+` `/` · (r1 H2) 43자에 `=` · 43자에 `.` `~` · 숫자 · 43자 + LF(`\z`) / S04i `password` + `Password` 공존 → `판정 불가`(JSON 해석 거부 · 값 미출력) | PASS × 11 |
| S04j · S04k | (r1 C1) 두 경로 모두 live-ok: 같은 값 → 경로별 SKIP 2줄 뒤 `STOP <경로> — prod 와 dev 의 password 가 같다 — …` 2줄 · `판정 결과: 생성 예정 0 · 건너뜀(live-ok) 0 · 중단 2` · 요약 2행 `중단(prod 와 dev 의 password 가 같다 …)` · 쓰기 0 · 정지점 없음 · vault 호출 7 / 대소문자 한 글자만 다른 두 값 → 둘 다 SKIP · 쓰기 0 · 정상 종료 | PASS × 2 |
| S05a–c | dead: soft-delete · destroy · 메타데이터만(current_version 0) → 쓰기 0 | PASS × 3 |
| S06a–d | 쓰기 확인 정지점에서 다른 단어 · 빈 Enter · `" seed"` · `"SEED"` → 쓰기 0 · finally 요약 · 창 종료 체크리스트 | PASS × 4 |
| S07a–f | Vault 도달 실패 · sealed · 미초기화 · 응답이 JSON 아님 · `sealed` 가 문자열 · unsealed JSON 인데 exit 1 → 토큰을 묻기 전에 중단 | PASS × 6 |
| S08a | 실재 경로(dev · live-ok)를 `No value found` 로 오판 → prod 생성 뒤 dev `-cas=0` 거부 → 재판정 live v1 · 되읽기 해시 불일치 = `CAS 충돌(다른 값)` · 덮어쓰기 0 · 재판정 순서 put → metadata get → kv get | PASS |
| S08b–c | metadata 비 0 + 빈 출력 / 500 → absent 로 보지 않고 판정 불가 → 쓰기 0 | PASS × 2 |
| S08d–e | 되읽기 일시 실패(prod) → 다음 경로(dev)로 가지 않음 / 그 상태에서 재실행 → prod SKIP · dev 생성 | PASS × 2 |
| S09 · S09b · S09c · S09d | 되읽기 대조: prod password 한 글자 변형 → `되읽기 해시 불일치(password)` · dev 미실행 / dev password 키 누락(prod 생성 뒤) → `되읽기 키 집합 불일치(누락: password · 여분 0개)` / prod 여분 키 → `(누락: 없음 · 여분 1개)` · dev put 0 / (r1 H3) prod password 첫 영문자의 대소문자만 변형 → `되읽기 해시 불일치(password)` · dev 미실행 · 각 요약 행 `기록됨 — 되읽기 …` | PASS × 4 |
| S10a–c | 클립보드 기록 켜짐 · 설정 키 없음 · 값 없음 → 시작 전 중단(입력 0 · vault 호출 0) | PASS × 3 |
| S10d | 클립보드 비우기 실패(세션 `$WarningPreference = SilentlyContinue`) → `Write-Warning` 2개(토큰 확인 줄 앞 · 요약 머리 앞) · 2개 생성 완주 | PASS |
| S10e | 세션 `$WhatIfPreference = $true` + `$PSDefaultParameterValues['Set-Clipboard:WhatIf']` → 블록이 자기 범위에서 고정 → 클립보드 비우기 2회 실제 실행 · `VAULT_*` 0 · 2개 생성 + 하네스 자체 복원 단언 | PASS |
| S11a | 정상 완주 뒤 `VAULT_*` 0 · 이 실행으로 생긴 전역에 put 본문 · 토큰 모양 0 · `$Error` 0 | PASS |
| S11b–e | 시작 전 `VAULT_TOKEN` · 다른 `VAULT_*` · 다른 `VAULT_ADDR` → 묻지 않고 중단 · 기존 변수 그대로 / 기대값 `VAULT_ADDR` → 진행 후 제거 | PASS × 4 |
| S11f | 되읽기 응답이 깨진 JSON(안에 비밀번호) → 고정 문구로 중단 · 화면 · `$Error` 에 값 없음 · dev 미실행 | PASS |
| S13a–b | root 토큰 빈 입력 → 중단 / 앞뒤 공백 → Trim 후 완주 | PASS × 2 |
| S14 · S14b · S15 | 토큰 정책에 root 없음 → 판정 전 중단 / (r1 H1) 형식은 맞지만 root 가 아닌 토큰 → token lookup 403(exit 2) → `root 토큰 확인 실패(token lookup exit=2)` · metadata get 0 · put 0 · `VAULT_TOKEN` 제거 / `hvs.` 아닌 값 → Vault 로 보내기 전에 중단 | PASS × 3 |
| S16 · S16d · S16e | put 거부(prod · 경로 없음) → 재판정 absent = 쓰지 않았다 · dev 미실행 / put 응답 유실 → 재판정 live v1 · 해시 일치 → `기록됨(응답 유실 — 이 실행의 값 …)` · 다음 경로 계속 · 2개 완주 · put 2 / put 비 0 뒤 재판정 500(dev) → `결과 미확인` · `판정: 미완` | PASS × 3 |
| S17 | 재실행 — 2경로 모두 live-ok → 2 SKIP · 쓰기 0 · 정지점 없음 · vault 호출 7 | PASS |
| S18 · S19 · S19b | `~/.vault-token` 존재 → 시작 전 중단 / live 판정 중 kv get 실패 → 판정 불가 / 깨진 JSON → 판정 불가(live-mismatch 아님) | PASS × 3 |
| S20a–c | put 성공 뒤 metadata: `current_version 2`(dev) · `deletion_time`(prod) · 500(prod) → `메타데이터 확인 실패` · 요약 `기록됨 — 메타데이터 확인 실패(…)` · 뒤 경로 put 0 | PASS × 3 |
| S21a–b | put 도중 중단(prod — 서버 커밋) → 요약 `결과 미확인` · `판정: 미완` / 재실행 → prod SKIP · dev 생성 | PASS × 2 |
| S22a–d | 모듈 로깅 정책 켜짐(PowerShellCore HKLM · HKCU · Windows PowerShell 분기) → 시작 전 중단 / 양쪽 0 → 진행 · 정책 키 4개를 모두 읽음 | PASS × 4 |
| R1 · R2 | 런북 ① 점검 · ② 삭제 블록 정적(관문 6: 추출 · 파서 · 명령 · 정적 형식 · `$Host` · 리다이렉트) + 첫 줄 `& {` · 표식 주석 · 끝 `}` · 빈 줄 · TAB · CR 0 · 최상위 1문 · Read-Host 1곳 / 2곳 평문 + 바로 앞 비움(AST) · 첫 Read-Host 전 `Set-Clipboard -Value ' '` · vault 호출 모양(① = `kv metadata get` · `kv get` / ② = `kv metadata get` · `kv metadata delete`) · **허용 경로 상수 = 계약 2경로 정확히** · `MOCK` · 비밀 상수 · `hvs.` · env 쓰기 0 | PASS × 2 |
| GA01–GA09 · GA03d | ① 점검 블록(vault 쓰기 명령 0 · 노출 0 · 창의 `VAULT_*` 그대로 · 첫 Read-Host 전 클립보드 비움): live → `current_version=1 · delete_version_after=0s` · 이력 1행 · `현재 버전 키 이름(값 미출력): password` / absent / 2경로 밖(터널) · 끝 공백 · 대소문자 · **T054 경로** → vault 호출 0 / dead / metadata 500 / kv get 비 0 / current_version 0 / 깨진 JSON → `Unexpected end when reading token`(값 없음) / **`password` + `Password` 공존 → 키 이름만 담은 JSON 변환 오류(값 없음)** | PASS × 12 |
| GB01–GB12 · GB03b · GB06b | ② 삭제 블록(`kv put` 0 · 노출 0 · 첫 Read-Host 전 클립보드 비움): 2경로 밖(터널) · 끝 공백 · 대소문자 · **T054 경로** → vault 호출 0 · 재입력 없음 / 재입력 다른 2경로 · 빈 Enter · 끝 공백 · (r1 H3) 경로 전체 대문자 → delete 0 / 정확한 재입력 → get → delete → get(`No value found`) · OK · 그 경로만 사라짐 · 2경로 밖 경로 그대로 / metadata 500 · delete 비 0 · delete noop · absent · 삭제 뒤 조회 500 → 중단(OK 아님) | PASS × 14 |

### 실행 기록 — 하네스 결함 · 변이 시험(2026-10-16)

- **1차 실행**(하네스 작성 직후 — 이어받은 초안 블록 · 런북 소절 없음): `시나리오 PASS 58 / 68` · `PASS 1890 / 1918` · exit 1. FAIL 10 = R1 · R2(표식 펜스 0개 — 런북 소절을 쓰기 전의 기대 red · 관문이라 GA · GB 는 돌지 않았다) + **하네스 결함 8**: `Summary-Row` 가 `@(Summary-Rows)` 로 반복해 `, $rows` 배열을 원소 1개로 한 겹 더 감쌌다(행 비교가 늘 거짓 — S03 · S03b · S09 · S09b · S09c · S16d · S16e · S21a) · S03 · S03b 의 vault 호출 수 기대값을 10 으로 잘못 셌다(실제 9 — version · status · token lookup 3 + 판정 metadata get 2 + live 경로 kv get 1 + 쓰기 3). **블록 행동 결함 0**(실패 단언의 세부에 찍힌 실제 출력 = 기대 문구).
- 하네스 수정(대입으로 한 겹 벗긴 뒤 반복 · 기대값 9) · GA09 추가 · 런북 소절 작성 뒤: `시나리오 PASS 93 / 93` · `PASS 2396 / 2396` · exit 0. 초안 블록 문구 2건 수정(아래 「초안에서 바꾼 것」) 뒤 재실행도 같은 수 · exit 0 · `%TEMP%` 함정 디렉터리 잔여 0.
- **변이 시험**(세션 스크래치의 블록 · 런북 사본 8개 · `-Block` / `-Runbook`) — 전부 exit 1 · 의도한 시나리오에서만 FAIL:

| 변이 | 잡은 시나리오 |
|---|---|
| mK1 블록: live 판정 정규식 `\A…\z` → `^…$` | S04h(1) — 43자 + 끝 LF 가 live-ok 로 SKIP 된다 |
| mK2 블록: live 판정에서 여분 키 무시(`$extra = 0`) | S04a · S04b · S04c(3) |
| mK3 블록: 쓰기 값에 `username` 키 추가(T054 모양) | 21 — 생성하는 시나리오 전부(되읽기 키 집합 불일치로 STOP) |
| mK4 블록: live 판정 길이 `{43}` → `{32,}` | S04d · S04e(2) |
| mK5 블록: live 판정의 문자열 형식 검사 제거 | S04g(1) — 숫자 값이 `문자열이 아니다` 대신 길이 사유로 잡힌다 |
| mK6 블록: ExternalSecret 이름 오타(dev) | S01(1) — 쓸 경로 목록 줄 대조 |
| rbK1 런북: ① 점검 허용 목록에 T054 경로 추가 | R1(허용 경로 상수) · GA03d(2) |
| rbK2 런북: ② 삭제 허용 목록 비교를 `OrdinalIgnoreCase` 로 | GB03(1) |

- T054 하네스의 변이 표(라운드 0–6)는 다시 재지 않았다 — 가드 · 공통 사후 조건 · 정적 관문 · 과도 상태 단언은 T054 하네스에서 빼지 않고 옮겼다(바꾼 것은 위 「달라진 시나리오」 표뿐이다). 변이 실행기 · 사본은 세션 스크래치(저장소 밖)에 있다 — 재현은 위 표의 변이를 사본에 넣고 `-Block`/`-Runbook` 으로 돌리면 된다.

### 수정 라운드 r1(리뷰 r1 렌즈 4 — `approve_with_fixes` · high 0 · 2026-10-16)

| ID | 지적 | 반영 |
|---|---|---|
| H1 (medium) | B5 유지 목록의 「token lookup 실패」 시나리오가 없다(블록 :299 미시험 — T054 하네스에도 없던 공백) | 하네스 `FAKE_WRONG_TOKEN` · S14b — 원래 블록 그대로 PASS |
| H2 (low) | B3 문자 집합이 일부만 고정(`=` · `.`/`~` 허용 회귀 생존 · `_` 거부는 무작위로만 잡힘) | 하네스 S04f2 · S04f3 · `$LIVE_PW` prod 값에 `_` + 시작 전 자기 확인 — 원래 블록 그대로 PASS |
| H3 (low · 채택) | 대소문자만 다른 변형을 하네스가 구분하지 않는다 | 하네스 tamper `passwordCase` · S09d · GB06b — 원래 블록 · 런북 그대로 PASS |
| R1 (low) | 런북 「실행」 명령이 상대 경로 | 런북 「실행」 = 절대 경로(「저장소 루트에서」 삭제) · 하네스 실행 명령도 절대 경로로(블록 머리 주석 :44 · 하네스 머리 「사용」 · 이 문서 머리) |
| R2 (low) | 「늦은 시드」 5 에 UO 주기 숫자가 없다 | 「UO의 다음 주기 조정(기본 120초 — Strimzi 1.2.0 `UserOperatorConfig` 기본 120000 ms · gitops `platform/kafka-topics/README.md` §1 · 이 클러스터 미실측)」 |
| D1 (low) | §2 첫 문단이 `write` 를 「줄 단위로 같은」 헬퍼에 넣었다 | §2 첫 문단을 최종 줄 번호로 다시 썼다 |
| C1 (low → 컨트롤러 결정 (b)) | live-ok 판정이 prod 와 dev 의 비밀번호가 서로 다른지 보지 않는다 | 블록 쌍 판정(§1 C1 행 · §2 의 7) · 하네스 S04j · S04k · §6 · 런북 실패 표 행 · 「정리 판단」 예외 문구 |

- **TDD 순서**: 하네스를 먼저 고쳐 원래 블록 · 런북에 돌렸다 → `시나리오 PASS 99 / 100` · `PASS 2597 / 2608` · exit 1 — FAIL 은 S04j 하나(블록에 쌍 판정이 없다 — 기대한 red). 새 시나리오 S14b · S04f2 · S04f3 · S09d · S04k · GB06b 는 원래 블록 · 런북 그대로 PASS 했다(블록 판정 규칙은 바꾸지 않았다). 블록에 C1 을 넣은 뒤 `시나리오 PASS 100 / 100` · `PASS 2608 / 2608` · exit 0 · 함정 디렉터리 잔여 0.
- **변이 재시험**(리뷰어의 변이 실행기 `run-mutations.ps1` 그대로 + 새 변이용 `run-mutations-fix-r1.ps1` — 세션 스크래치 · 사본은 실행 시점의 블록 · 런북에서 만든다 · 순차 실행 331초 · 함정 잔여 0): 비등가 변이 23종 전부 잡힘 · 등가 변이 2종(M02b · C1d)만 생존.

| 변이 | r1 전(리뷰 r1) | r1 뒤 |
|---|---|---|
| M05 판정 문자 집합에 `=` 허용 | 생존 | **잡힘** S04f2 |
| M06 판정 문자 집합 `[A-Za-z0-9_.~-]`(T054 판) | 생존 | **잡힘** S04f3 |
| M07 판정이 `_` 거부 | 6회 중 5회(S08e · S21b — 무작위 값에 `_` 가 들어갈 때만) | **4회 중 4회** — S03 · S17 이 매번(결정적) · S08e · S21b 는 여전히 무작위 |
| M02 되읽기를 원값 `-eq`(대소문자 무시) | 생존 | **잡힘** S09d |
| R01 ② 삭제 재입력 비교 `OrdinalIgnoreCase` | 생존 | **잡힘** GB06b |
| C1 쌍 판정 비교 제거(`if ($false)`) | — | **잡힘** S04j |
| C1b 해시 대신 원값을 `-eq`(대소문자 무시)로 비교 | — | **잡힘** S04k |
| C1c 비교 반전(다르면 STOP) | — | **잡힘** S04j · S04k · S17 |
| H1 token lookup 비 0 분기 제거 | — | **잡힘** S14b(정책 목록이 비어 `토큰 정책에 root 가 없다` 로 끝난다) |
| 그 밖의 리뷰 변이 | M01 · M02c · M03 · M03b · M04 · M04b · M08 · M09 · mK1 · mK5 · rbK2 · R02 · R03 · R04 잡힘 | 같은 시나리오에서 전부 잡힘(새 시나리오만큼 수만 늘었다 — M01 26 → 27 · M02c + S09d · M03 48 → 54 · M03b 47 → 53 · M04 · M04b 25 → 26) |
| 등가(생존이 정상) | M02b 해시끼리 `-eq` | M02b · C1d 해시끼리 `-eq`(두 쪽 모두 같은 함수가 낸 대문자 hex — 어떤 입력으로도 구분되지 않는다) |

### 초안에서 바꾼 것(이어받은 `op1-seed-kafka.ps1` — 2026-10-16 17:59 중단본 · 379줄 · 39,924 B · sha256 `28197ffd…57f63`)

검토 기준은 결정 B1–B8 과 T054 블록과의 줄 단위 diff 다. 초안은 B1–B8 을 모두 지켰고 하네스의 블록 행동 단언을 처음부터 전부 통과했다 — 바꾼 것은 문구 2줄뿐이다(줄 수 그대로).

1. 머리 주석 :43(늦은 시드) — "ES 2장 force-sync 어노테이션 · KafkaUser 는 UO 의 다음 조정에서 Ready" → "… · 재시도가 끝났으면 수동 전체 Sync(wave 1 의 KafkaUser 는 그때 적용된다) · 그 뒤 KafkaUser 2 Ready". 머지가 먼저 되면 operation 이 wave 0 Degraded 에서 멈춰 KafkaUser(wave 1)가 아직 없다 — T054 머리 주석의 "필요하면 수동 Sync" 가 초안에서 빠져 있었다(런북 「늦은 시드」 4 · 5 와 맞춤).
2. `INFO vault CLI` 줄 :270 — "JSON stdin 형식 실측(VD-6)은 T045 블록(2026-09-21) · T054 블록(2026-10-15)이 CLI v2.1.0 으로 했다" → "JSON stdin 형식은 T045 블록(2026-09-21 · VD-6 실측)과 T054 블록(2026-10-15 · 6경로 되읽기 해시 일치)이 CLI v2.1.0 으로 확인했다". VD-6 프로브는 T045 만 했고, T054 는 첫 실행의 되읽기 해시 일치가 근거다(T054 README §2 의 2 · 런북 §4 T054 실행 기록) — 실행 기록에 옮겨 적는 줄이라 출처를 갈랐다.

---

## 5. 하네스가 증명하지 못하는 것

모의는 **가정한 CLI 출력 형식**을 되돌려줄 뿐이다. 다만 T054 블록이 같은 창 · 같은 CLI 로 2026-10-15 에 라이브로 돌았으므로(런북 §4 T054 실행 기록 — Vault v2.1.0 CLI · 서버 2.0.4), T054 README §5 의 미확인 항목 중 다음은 그 실행으로 닫혔다: ① `vault status -format=json` 의 `initialized` · `sealed` bool(`OK Vault 도달 …` 줄) ② 없는 경로의 `kv metadata get` stderr `No value found at …`(6경로 `PLAN … absent`) ③ `kv get -format=json` 의 `data.data` · `kv metadata get` 의 `current_version` · `versions` · `token lookup` 의 `data.policies`(`OK 토큰 정책에 root 포함` · 6경로 되읽기 해시 일치 · `current_version=1` 확인) ④ JSON stdin(VD-6 — T045 실측 + T054 되읽기 일치) ⑤ root 토큰의 `hvs.` 접두 가정(형식 검사를 통과했다). 경로가 같은 `kv` 마운트 아래이고 블록 코드가 같으므로 T056 에서도 같다고 본다 — 다르면 대부분 fail-closed(토큰 전 · 판정 단계 · 첫 경로 되읽기에서 STOP)다.

여전히 증명하지 못하는 것:

1. **콘솔 고유 동작** — Ctrl+C 의 finally 절단(T054 README §3 의 `PowerShell.Stop()` 모의만 실측) · `FlushInputBuffer` 의 실제 type-ahead 소비 · 기본 콘솔 호스트의 빈 줄 종료. 방어만 했다.
2. **클립보드 · 레지스트리 · 전사 정책** — 하네스는 실제 `Set-Clipboard`/레지스트리를 부르지 않는다(호출 · 값만 센다). `-MaskInput` 입력이 전사에 어떻게 남는지는 미실측(전사 정책이 꺼져 있음을 창 시작 체크리스트로 확인하는 것이 방어다).
3. **호스트 UI 직접 쓰기는 정적 규칙(S12)으로만 막는다** — 런타임 노출 검사는 `*>&1` 스트림만 본다. 정적 규칙은 실수로 생기는 회귀를 막는 것이지 일부러 우회하는 코드(리플렉션 등)까지 막지는 못한다 — 블록 변경은 리뷰를 거친다.
4. **모듈 로깅 정책 검사의 범위** — 그룹 정책 레지스트리 키(PowerShellCore 2 + `UseWindowsPowerShellPolicySetting` 이 1 일 때 Windows PowerShell 2)만 본다(`powershell.config.json` 의 `PowerShellPolicies` 는 보지 않는다 — T054 README §5 의 9).
5. **붙여넣기 창의 호스트 상태** — 프로필이 정의한 함수 · 별칭 · 중단점은 블록이 감지하거나 막지 못한다(INFO 줄은 `vault` 의 종류만 보인다). `-File -NoProfile`(권장)과 `-NoProfile` 새 창이 방어다.
6. **Kafka · ESO 쪽 동작(T056 고유)** — 블록이 보장하는 것은 "kv 2경로에 `{password: base64url 43자}` v1 이 있다" 까지다. ESO 가 `property: password` 를 그대로 Secret 키 `password` 로 옮기는지, UO 가 `valueFrom.secretKeyRef` 의 43자 값을 받아 SCRAM-SHA-512 자격을 만드는지(KafkaUser `Ready`), 브로커가 그 자격으로 인증하는지는 머지 뒤 확인(런북 「머지 뒤 확인」)과 gitops README §3 VD · T059 kafka-assert Job 몫이다.
7. **대소문자만 다른 키(S04i · GA09)의 처리는 PowerShell 7.6 의 `ConvertFrom-Json` 동작에 기댄다** — `-AsHashtable` 없이 대소문자만 다른 키를 만나면 변환을 거부한다(2026-10-16 · pwsh 7.6.6 실측 · 오류 문구는 키 이름만 싣는다). 이 동작이 바뀌어 두 키를 받아들이면 블록 판정은 여분 키로 `live-mismatch`(여전히 STOP · 쓰기 0)가 된다 — 어느 쪽이든 fail-closed 다.

## 6. 남은 위험(라이브 실행 시)

- **자식 프로세스의 `VAULT_TOKEN` 상속** — 블록이 부르는 `vault.exe` 는 env 의 root 토큰을 쓴다(설계상 필요). 실행 창은 블록 전용으로 쓰고 끝나면 닫는다.
- **메모리의 .NET 문자열**(비밀번호 · 토큰)은 0 으로 지울 수 없다 — 변수 참조만 끊는다. `pwsh -File` 권장 실행은 프로세스 종료로 끝낸다.
- **live-ok 는 "모양이 맞다"는 뜻이지 "Kafka 의 SCRAM 자격과 같다"는 뜻이 아니다.** T056 머지 전에는 KafkaUser 가 없어(UO 가 kv 값으로 자격을 만든다) 지금은 문제가 없지만, 재실행 의미를 회전으로 오해하지 않게 런북에 적었다.
- **생성 값의 유일한 사본은 kv 다.** Vault 데이터 유실은 Raft 스냅샷(매일 02:30 KST · `platform-backup.sh`)으로만 복구된다 — 시드 직후 스냅샷 전 유실이면 재시드(경로 정리 후)가 복구다(KafkaUser 는 같은 ES 로 새 값을 받고 UO 가 자격을 바꾼다).
- **dev 경로는 두 소비자가 같은 값을 읽는다** — `data` 의 `kafka-user-dev-identity-admin`(KafkaUser) 과 `jt-dev` 의 `assert-env`(T059 검사 Job). 한쪽만 바꾸는 방법은 없다 — 회전은 둘을 함께 움직인다(secret-rotation.md · T084).
- **prod 와 dev 에 같은 password — 수정 라운드 r1 에서 막았다(C1 · 리뷰 r1 지적)** — dev 값은 `jt-dev` 의 `assert-env` 로도 복사되므로 두 경로가 같은 값이면 dev 쪽 노출이 곧 prod SCRAM 자격 노출이다(사용자 이름은 비밀이 아니다). 블록은 경로마다 독립 RNG 로 만들어 이 상태를 스스로 만들지 않고, 블록 밖에서 두 경로에 같은 값이 들어간 경우는 판정 단계가 SHA-256 Ordinal 비교로 잡아 두 경로를 STOP 한다(쓰기 0 · 하네스 S04j · 런북 실패 표 「prod 와 dev 의 password 가 같다」 행). STOP 뒤 조치는 **두 경로 모두** 지우고 재생성한다(머지 전 — 같은 값은 블록 밖을 거쳤다는 뜻이라 남기는 쪽도 노출로 본다 · 리뷰 r2 R3 · K7). 남는 것: ① 블록이 돌 때만 잡는다 — 시드 뒤 블록 밖에서 한쪽을 다른 쪽 값으로 바꾸면(회전 실수 등) 다음 실행 전까지 보이지 않는다(회전 절차 `secret-rotation.md` · T084 가 두 값을 따로 만들어야 한다) ② 같음만 본다 — 대소문자 한 글자만 다른 값 같은 "거의 같은" 쌍은 STOP 하지 않는다(S04k 가 Ordinal 비교를 고정하려고 바로 그 쌍을 SKIP 으로 단언한다 · 블록이 만든 값끼리는 생기지 않는다).
- **root 토큰 사용**(T044 D4) — revoke 는 T084 OIDC admin 실증 + break-glass 드릴 뒤. 이 블록은 root 를 요구한다(정책 목록에 `root`).
- **클립보드 기록 점검**은 사용자 키 `HKCU\Software\Microsoft\Clipboard\EnableClipboardHistory` 만 본다(그룹 정책 · 클라우드 클립보드 동기화는 창 시작 체크리스트 몫). **클립보드 비우기 실패는 경고만 한다** — 보면 그 자리에서 직접 비운다(런북 실패 표의 경고 행).
- **붙여넣기 실행의 부수 효과** — 첫 문장 `Set-PSDebug -Off` 가 그 창의 `Set-PSDebug` 추적과 전역 strict 모드를 끈다. 창은 끝나면 닫는다.
- **머지가 먼저 되면 저절로 회복하지 않는다** — wave 0 ExternalSecret 이 Degraded 인 채 operation 이 wave 1(KafkaUser · KafkaTopic · CA 미러)을 적용하지 못하고 Failed 로 닫히며, 표준 syncPolicy 의 기본 재시도가 끝나면 더 시도하지 않는다. 원칙은 머지 전 시드이고, 늦었다면 런북 「늦은 시드」(ES 2장 `force-sync` → `SecretSynced` 확인 → 재시도가 끝났으면 수동 전체 Sync → KafkaUser 2 `Ready`).
- **kv 경로 정리는 되돌릴 수 없다** — 런북 「정리 판단」의 두 블록(① 읽기 전용 점검 → 운영자 판단 → ② 삭제: 2경로 허용 목록 · 경로 재입력 Ordinal 일치 · 삭제 뒤 `No value found` 확인)만 쓰고, 머지 뒤에는 지우지 않는다. 두 블록은 하네스가 런북 코드 펜스에서 그대로 추출해 시험한다 — 펜스 안을 고치면 하네스를 다시 돌린다.
- **put 비 0 의 재판정은 Vault 상태만 본다** — `기록됨(응답 유실 — 이 실행의 값)` 은 정상 완료와 같지만, 그 줄이 나왔다는 것은 창 C port-forward 가 그 순간 끊겼다는 신호다(실행 기록에 남기고, 반복되면 port-forward 를 다시 세운다).
