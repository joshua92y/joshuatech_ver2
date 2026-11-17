# T057 운영자 블록 — Dragonfly ACL · 사용자 비밀번호 kv 7경로 시드 · 모의 하네스 · 남은 위험

빌더 작업(2026-10-22 — 컨트롤러 지시서 `.superpowers/t057/prompts/t057-brief-blocks.md` 의 결정 B1–B10 · `../build-notes.md` 「T057」 D6 · D9 · D11 · 「1차 자료 확인」). 산출물은 이 디렉터리 3파일과 런북 `docs/runbooks/bootstrap.md` §4 「T057 — Dragonfly ACL · 비밀번호 시드(kv 7경로 · 랜덤)」 소절뿐이다. 선례 `../t056-blocks/`(T056 Kafka SCRAM 시드 — 닫힌 과제 · 수정하지 않았다)를 복사·파생했고, url 대조는 `../t054-blocks/op1-seed-db.ps1` 의 접두 · 접미 · 가운데 대조 모양을 따랐다. 1차 시드는 2026-10-22 14:15–14:40 KST 에 운영자가 실행했다(런북 소절 「실행 기록」 — 7경로 생성 v1 · 되읽기 해시 일치).

**수정 라운드 r2(2026-10-22 — 지시서 `.superpowers/t057/prompts/t057-fix-r2-blocks.md` 의 B11–B14 · build-notes 「T057」 「VD-4 1차 실측」 · 결정 F12)**: VD-4 1차 실측(06:39:50Z)에서 옛 default 줄 `USER default OFF -@all` 이 **AUTH · HELLO 까지 막아 아무도 인증하지 못했다**(파일은 적재됐다 — Dragonfly 는 NOAUTH 관문을 지난 AUTH · HELLO 를 연결의 현재 사용자 default 의 ACL 로 검사한다). 렌더 default 줄을 `USER default OFF +auth +hello` 로 고치고(B11), 하네스 기대 바이트 · S12 default 줄 규칙 · 로더 모의의 `+cmd` 토큰 · 시나리오 S37a/S37b(B12), 이 README(B13), 런북 §4 T057 「ACL 파일 갱신」 절(B14)을 반영했다. kv 의 acl 2경로(1차 시드)는 옛 줄로 렌더된 채이며 런북 「ACL 파일 갱신」으로 다시 렌더한다(운영자 · 라이브 미실행).

| 파일 | 역할 |
|---|---|
| `op1-seed-dragonfly.ps1` | 운영자 블록(창 D · 475줄 — r2 에서도 줄 수 불변 · 렌더 default 줄 = `USER default OFF +auth +hello`(F12)) — 첫 문장 `Set-PSDebug -Off` → 세션 설정 고정 → 창 전제(클립보드 기록 · 모듈 로깅 정책 · `~/.vault-token` · `VAULT_*`) → Vault 도달(토큰 없이) → root 토큰(보안 입력) · token lookup(`root`) → kv 7경로 판정(읽기 전용 — 경로별 모양 · 의존 B4 · 쌍 판정 B5) → 쓰기 확인 정지점(`seed`) → `-cas=0` 생성(env 마다 사용자 경로 → acl · dev → prod) + JSON 되읽기 SHA-256 대조 + `current_version=1` 확인(put 비 0 은 값 없이 재판정) → finally 정리 · 요약 7행 |
| `harness.ps1` | 모의 실행 하네스(T056 하네스 파생) — 시나리오 152(시드 블록 119 = S12 정적 1 + 렌더 단위 시험 U01–U04 4 + 런타임 114 — r2 의 S37a · S37b 포함 · 런북 「정리 판단」 두 블록 33 = R1 · R2 정적 + GA 15 + GB 16) · 단언 4923 · S12 정적 관문을 맨 먼저(관문 FAIL = 블록 실행 0회) · 실물 `vault`/`kubectl` 차단 가드 3중 · 하네스 프로세스의 `KUBECONFIG` 를 없는 경로로 덮음 · 렌더 함수는 블록 AST 에서 떼어 내 고정 입력으로 시험 · 런북 두 블록은 `bootstrap.md` 코드 펜스에서 그대로 추출(표식 `[t057-cleanup-inspect]` · `[t057-cleanup-delete]`) |
| `README.md` | 이 문서 — 결정 대응 · T056 블록과 다른 점 · 하네스 결과 · 변이 시험 · 남은 위험 |

실행: `pwsh -NoProfile -File D:\code\joshuatech_ver2\specs\003-platform-foundation\design\t057-blocks\harness.ps1` → `PASS 4923 / 4923`(시나리오 152 / 152, exit 0 · r2 최종 실행 2026-10-22 16:31 KST · 실행 시간 14.2초 — 같은 날 실행마다 14–23초 · r1 최종 12:30 KST 는 `PASS 4798 / 4798` · 시나리오 150). 한 시나리오의 화면 출력은 `-Show 'S01'`, 변이 사본에 같은 시나리오를 돌리려면 `-Block <경로>`(시드 블록) · `-Runbook <경로>`(런북 사본 — 「정리 판단」 두 블록을 그 파일의 코드 펜스에서 추출한다).

---

## 1. 컨트롤러 결정(B1–B14) 대응

줄 번호는 r2 기준이다. 블록은 r2 에서 줄 수가 그대로라(:17 · :132 · :134–135 · :141 만 바뀜) r1 의 블록 줄 번호가 유효하고, 하네스 줄 번호는 r2 에서 다시 쟀다.

| ID | 결정 | 한 일(파일:줄) |
|---|---|---|
| B1 | 경로 7(키 · 사용자 · env · 소비자 표) · prod 에 `sample-pod` 없음 | 블록 `$paths`(op1-seed-dragonfly.ps1:75–82 — 배열 순서 = 판정 · 쓰기 순서: env 마다 사용자 → acl · dev → prod · `role` = admin/pod/acl · `keys` 1/2/1 · `use` = 쓸 경로 목록 줄의 소비자 문구) · 머리 주석 표(:7–14). 하네스 계약 `$PATHS`(harness.ps1:60–67 — S01 이 목록 줄 7개를 글자 단위로 대조) · 런북 소절 「경로·값」 표(bootstrap.md:1232–1252) |
| B2 | 값 생성: password = RNG 32바이트 base64url 43자 · url = `redis://` + 사용자 + `:` + password + `@dragonfly-<env>.data.svc:6379/0` · `users.acl` = D6 렌더(LF · 끝 LF 1 · 소문자 hex 64) · 렌더 = 순수 함수 · 하네스가 기대 바이트열과 대조 | 생성기 :235–237(T054 · T056 과 같은 줄 — `else` 안으로 들여쓰기만 바뀜) · url 조립 :244(문자열 이어 붙이기) · `$render`(:136–148 — 입력 `$ev` · `$pwMap` · 바깥 변수 · 헬퍼 · 명령 0 · `[string]::Equals(…, Ordinal)` 로 env 를 고르고 잘못된 env · 누락 · 43자 아닌 비밀번호는 값 없는 문구로 throw · `[Convert]::ToHexString(SHA256(UTF-8)).ToLowerInvariant()` · 줄을 `-join` 백틱 n(LF)으로 잇고 끝에 LF 1개 · 첫 줄 default = `USER default OFF +auth +hello` :141 — r2 F12). 하네스: S12 정적 규칙(harness.ps1:1000–1019 — `$render` 1개 · 순수 함수 · CR/NewLine 0 · `-join` 백틱 n · `ToLowerInvariant` + r2 default 줄 규칙 :1013–1018) · U01–U04(:1224– · `Check-Render` :879–907 — 독립 구현 `Acl-For`(:101–106 · 바이트마다 `ToString('x2')`)와 Ordinal 대조 · 줄 수 · 순서 · 1줄 = `$ACL_DEFAULT`(:894) · 규칙 문자열 · 끝 LF 1 · CR/TAB/BOM/비 ASCII 0 · 토큰 ≥ 4 · 로더 모의 `Test-AclLoader`(:119–138)) |
| B3 | live 판정 ⓐ admin `{password}` · ⓑ pod `{password, url}` + url 정확히 · ⓒ acl `{users.acl}` + 렌더와 Ordinal 일치 · 아니면 mismatch STOP(분류만 · 값 0) · dead/error STOP | `$judge`(:178–223): 키 집합 정확히(:197–203 — T056 그대로 · `$keys = @($e.keys)` :179) · 문자열(:204) · ⓒ acl(:205–210 — 렌더 실패 = 판정 불가 · 다르면 `acl 내용 불일치(… — 내용 · 모양 미출력)`) · ⓐ password 모양(:211–214 — T056 그대로) · ⓑ url(:215–222 — 접두 `url 스킴 · 사용자 불일치` · 접미 `url 호스트 · 포트 · db 불일치` · 겹침 · 가운데 `url 비밀번호 불일치` = 정확 일치와 같은 조건을 분류해 낸다). dead · error 는 `$state`(:151–173 — T056 그대로). 하네스 S04a–i · S04c2 · S04f2/f3 · S04g2 · S04l–n3 · S04q–q11 · S05a–c · S19–S19d |
| B4 | 의존 ⓐ 사용자 absent + acl live → STOP ⓑ 사용자 전부 live-ok + acl absent → acl 만 생성 ⓒ 전부 absent → 7 생성 ⓓ 둘 다 live → 렌더 대조 · 쓰기 순서 사용자 → acl · dev → prod · 부분 실패 뒤 재실행은 acl 만 | `$judge` 앞머리(:180–185 — acl 경로는 같은 env 사용자 판정 뒤: `$creates` 에 그 env 사용자가 있으면 mismatch(ⓐ) · `$pwOf` 에 없으면(STOP) 판정 불가 — 둘 다 acl 값을 읽기 전) · 판정 단계가 live-ok 사용자 비밀번호를 `$pwOf` 에 둔다(:393–395) · 쓰기 단계는 되읽기까지 일치한 새 비밀번호를 넣는다(:314) · acl 쓰기 = `$render $e.env $pwOf[$e.env]`(:233) · 순서 = `$paths` 순서(:75–82). 하네스 S35a–c(ⓑ · 일부 absent + acl absent) · S36a–d(ⓐ · STOP 섞임 · env 독립) · S01(ⓒ · 쓰기 순서 단언 `Check-WriteOrder` :643–665) · S17 · S04q 계열(ⓓ) · S08f/S08g · S21b(부분 실패 뒤 재실행 — live 사용자로 다시 렌더) |
| B5 | 사용자 비밀번호 5개 전부 서로 다름(SHA-256 hex Ordinal) · 같으면 관련 경로 전부 STOP(판정 단계 · 쓰기 0 · 값 · 해시 미출력) | 판정 단계 쌍 판정(:412–427 — `$okHash` 의 경로별 해시를 쌍마다 비교 · 같은 값을 가진 경로마다 `STOP <경로> — password 가 <다른 경로들> 의 것과 같다 — …` · `$nSkip`→`$nStop` · 비교 뒤 해시 · 목록을 버린다). 「생성 예정」 몫은 판정 단계에 값이 없으므로 쓰기 단계에서 생성 직후 · put 전에 같은 비교(:238–242 — 아는 사용자 비밀번호 전부와 · 같으면 `생성 값 중복` STOP · 쓰기 0). 하네스 S04j(dev↔prod identity-admin) · S04j2(같은 env admin↔identity-admin) · S04j3(셋) · S04k(대소문자 한 글자만 다름 → SKIP) · S01(5개 고유 단언) · 변이 M05 · M12 · M13(§4) |
| B6 | 값 · 해시 · acl 내용 미출력 · `-cas=0` + JSON stdin · 되읽기 JSON + SHA-256 Ordinal + `current_version=1` | 새로 쓴 `Write-Host` · `throw` 문구의 보간은 경로 · 사용자 이름 · 키 이름 · 접미 상수 · 분류뿐(값 · 해시 · acl 0). put :248(T056 그대로) · 되읽기 :269–313(T056 그대로 — 키마다 SHA-256 Ordinal · `users.acl` 도 같은 대조). 하네스 공통 사후 조건 「노출 0」의 바늘에 url 전체 · url 안의 비밀번호 · acl 전문 · acl 안의 hex(대 · 소문자 · 앞 16자)를 더했다(`Add-SecretField` :516–531 · `Build-Needles` :532–) · S01 「put 본문에 날 LF 0」(users.acl 은 JSON `\n` 이스케이프) · 변이 M04 · M14 |
| B7 | 그 밖은 T056 블록과 동일 · 줄 단위 diff 로 확인 · 분류표 | §2 — (ⅲ) 그 밖 = **0** |
| B8 | 하네스(S12 유지 + 정적 추가 · 모의 7경로 · T056 시나리오 유지 + 추가 ①–⑨ · GA/GB · 변이 ≥ 3) | `harness.ps1` — §4 |
| B9 | README(§1–§6) | 이 문서 |
| B10 | 런북 §4 T057 소절 | `docs/runbooks/bootstrap.md` :1227–1472(r1 :1227–1426 + r2 B14 — T056 소절 뒤 · `## §5`(:1474) 앞 — §4 머리는 바꾸지 않았다): 목적 · **언제 = 머지 전(P1) · 머지 명령은 판정 출력을 컨트롤러에게 붙인 뒤에만** · 경로·값 표(값 0) · 렌더 줄 모양 · 사전 1–5 · 실행(절대 경로 · 소요 · Vault 호출 31/17 — 하네스 S01 · S17) · 기대 출력(S01 화면) · 판정 · 실패 시 표(url · acl · 의존 · 쌍 판정 · 생성 값 중복 행 포함) · 정리 판단 ①②(두 코드 펜스 — 하네스 R1 · R2 · GA · GB 가 추출해 시험 · ② 는 경로 재입력 · 삭제 뒤 `No value found` 확인 · 사용자 경로를 지우면 acl 도 지우라는 안내) · 머지 뒤 확인(ES 2 · Deployment 2 + aclfile 실림 판정은 로그 grep · `noauth`) · 늦은 시드(T056 절차 참조 · 이름 치환 · ⓐ/ⓑ · merge patch 금지 · `--kubeconfig`) · 회전 범위 밖(D9) · 실행 기록 자리 |
| B11(r2 · F12) | 렌더 default 줄 `USER default OFF -@all` → `USER default OFF +auth +hello`(dev · prod 공통 첫 줄 · 그 밖 3/2줄 불변 · LF · 토큰 ≥ 4) · 머리 주석 형식 설명 · D6 참조 문구 · 근거 주석 한 줄 | `$render` 의 `$lines = @('USER default OFF +auth +hello')`(op1-seed-dragonfly.ps1:141) · 머리 주석 형식 설명(:17 — "D6 — default 줄은 F12 정정") · 렌더 주석(:132 "D6 · default 줄 F12 정정" · :134 끝에 `#<hex>` 설명을 옮기고 :135 = 근거 한 줄 "default 줄 = USER default OFF +auth +hello(필수 …): Dragonfly 는 AUTH · HELLO 를 default 의 ACL 로 검사한다 — -@all 이면 아무도 인증 못 한다(2026-10-22 1차 실측 · build-notes F12)"). 줄 수 475 그대로 · T056 diff 통계 불변(§2) · 렌더 결과 dev 4줄 364바이트 · prod 3줄 246바이트 = Git Bash `printf` + `sha256sum` 독립 계산과 `cmp` 바이트 일치(r2 검증) |
| B12(r2) | 하네스: 렌더 기대 바이트(`Acl-For` · U01–U04 · 로더 모의)를 새 default 줄로 · 새 정적 규칙(default 줄 정확 일치 · `-@all` 회귀 금지) · 변이 1종 추가 · PASS n / n · 변이 ≥ 3 재확인(M02 · M03 · M10 포함) | 계약 상수 `$ACL_DEFAULT` · `$ACL_DEFAULT_OLD`(harness.ps1:89–93) · `Acl-For` 첫 줄 = `$ACL_DEFAULT`(:101–106) · `Acl-Old`(:110 — 1차 시드 모양) · `Check-Render` 1줄 단언(:894) · 로더 모의 `+cmd`/`-cmd`(주석 :115–117 · `$ACL_KNOWN_CMDS` :118 · 규칙 :135 — 아는 명령 AUTH · HELLO) · **S12 default 줄 규칙 3단언**(:1013–1018 — `$render` 안 'USER default' 문자열 상수 정확히 1개 = `$ACL_DEFAULT` · 그 상수에 `-@all` 0 · 블록 전체(주석 포함) 옛 줄 0) · U04 +3(:1255–1273 — 모르는 명령 토큰 · 하네스 자체 · 옛 줄 통과 = 한계 고정) · S02 검출기 자체 시험 문자열(:1315) · 시나리오 S37a · S37b(B14 연쇄 — :1463–1474 · :1880–1911) · 변이 M19(코드의 default 줄을 옛 줄로) · M20(머리 주석만 옛 줄로) — §4 |
| B13(r2) | README: B11/B12 반영 · 「증명 못 하는 것」에 1차 실측 사고 · 남은 위험 갱신 | 이 문서 — 머리 · 파일 표 · §1 · §4(모의 · S12 · 시나리오 · 결과 · r2 실행 기록 · 변이 22종 재측정) · §5 의 1 · 2 · §6 |
| B14(r2) | 런북 §4 T057: ① 「경로·값」 acl 줄 형식의 default 정정 ② 새 소절 「ACL 파일 갱신(acl 2경로 재렌더 — 2026-10-22 사고 복구 · 회전과 다르다)」 ③ 「실행 기록」 2차 자리 ④ 실패 표에 「사용자 SKIP · acl만 생성 예정 = 정상」 한 줄 · 두 코드 펜스(표식) 불변 | bootstrap.md ① :1244(머리 "default 줄은 F12 정정") · :1247(펜스 첫 줄) · :1253(근거 — AUTH · HELLO 는 default ACL 로 검사 · `ACL LIST` default 행) ② :1426–1468(언제 · 「정리 판단」 예외 · 7단계: 블록 확인(옛 줄 0) → ① 점검 · ② 삭제로 acl 2경로만 → 시드 재실행(SKIP 5 · 생성 2) → ES 갱신 확인(`force-sync` · `refreshTime` · `syncedResourceVersion` 의미 — ESO v2.10.0 소스) → pod 삭제(`--kubeconfig` · `ACL LOAD` 불가 · `rollout restart` 미사용) → 새 pod 로그 · 재시작 0 → 컨트롤러 VD-4 재실측) ③ :1472 ④ :1328 · 그 밖 「머지 뒤 확인」(:1412)에 인증 경로 판정 문장 · 로그 문구 4개로 통일. 두 표식 펜스(:1344–1371 · :1375–1402 — r1 대비 +1줄 이동만)는 R1 · R2 · GA · GB · S37b 가 추출해 시험 |

### 원칙 (a)–(h)(블록 머리 주석 :34–45 — T056 그대로 · (e)의 "값"에 url · users.acl 을 적었다)

(a) 사람 동작마다 정지점 — 입력 버퍼를 비운 뒤 단어 입력 · (b) 판정(읽기 전용)과 쓰기를 단계로 분리 — 판정에서 STOP 이 하나라도 나오면 kv 쓰기 0 · (c) 쓰기는 `-cas=0` + JSON stdin 뿐 · (d) 되읽기는 JSON + SHA-256 Ordinal + `current_version=1`, 실패하면 다음 경로로 가지 않는다 · (e) 값(password · url · users.acl) · 해시 · 토큰은 화면 · argv · 파일 · 클립보드 · 전사에 나오지 않는다 · (f) 생성 값의 유일한 사본은 kv — put 이 비 0 이어도 "쓰지 않았다"고 단정하지 않고 값 없이 재판정 · (g) 정리는 조건부 · (h) finally 가 env(`VAULT_TOKEN` 이 첫 문장) · 비밀 변수(`pwOf` 포함) · 클립보드 · `$Error`(이 실행분)를 먼저 정리하고 요약을 낸다 · 세션의 WhatIf · Confirm · 기본 매개변수 값을 블록 범위에서 고정한다.

---

## 2. T056 블록(`../t056-blocks/op1-seed-kafka.ps1`)과 다른 점 — 줄 단위 diff 분류

`git diff --no-index -U0 ../t056-blocks/op1-seed-kafka.ps1 op1-seed-dragonfly.ps1` = 136줄 추가 · 53줄 삭제 · 덩어리 28개. 덩어리마다 분류했다(줄 번호는 T057 쪽). r2(B11)의 변경 줄(:17 · :132 · :134–135 · :141)은 모두 아래 (ⅰ) · (ⅱ) 덩어리 안이라 통계 · 분류가 그대로다(r2 재측정 = 136 · 53 · 28).

| 분류 | 덩어리(T057 줄) | 내용 |
|---|---|---|
| (ⅰ) 경로 · 키 · 문구 치환 | :2–34 머리(제목 · 선례 · 목적 · 경로 표 · password 줄 · 사전 머리) · :38 원칙 (e) · :54–59 재실행 · 실행 뒤 확인 · 하네스 경로 · :60 `Set-PSDebug` 주석 · :74 `$keys` 전역 제거(경로별 `keys` 로) · :75–82 `$paths` 7행 · :84 `$okText`(SKIP 줄 문구 표) · :179 · :229 `$keys = @($e.keys)` · :311–312 · :316 요약 · OK 줄의 키 목록 · :323 모듈 로깅 주석 · :345 `INFO` 줄 출처(T056 실행 추가 · LF 값이 처음이라는 고지) · :397 SKIP 줄 · :431 · :433 · :437–438 · :458–459 · :470–471 문구(T057 · 7경로 · 요약 폭 `{0,-34}` · ES · Deployment 이름 · "이 출력을 컨트롤러에게 붙인 뒤에만 머지한다") | 동작 변화 없음(키 집합만 경로별) |
| (ⅱ) url · acl · 의존 B4 · 쌍 판정 B5 로직 추가 | :30–33 · :46–53 머리의 url · users.acl · B3–B5 설명 · :86 `$pwOf` · :132–148 `$render` · :174–177 `$judge` 주석 · :180–185 의존 · :205–210 acl 대조 · :215–223 url 대조 · ok 에 `pw` · :226 `$write` 주석 · :233–244 acl 값 · (생성기 3줄 들여쓰기) · B5 생성 몫 · url 조립 · :313–314 `$pwOf` 갱신 · :392–395 판정 단계 `$okHash` 경로 기록 · `$pwOf` · :412–426 쌍 판정 일반화(2개 → 5개 · 같은 값 경로 전부) · :452 `Remove-Variable` 에 `mine` · `same` · `pwOf` | B1–B5 의 의도된 변경 |
| (ⅲ) 그 밖 | **없음** | 헬퍼(`eq` · `has` · `sha` · `stop` · `readSecret` · `firstErr` · `parseJson` · `prop` · `state`) · 창 전제 · Vault 도달 · 토큰 형식 · token lookup · 판정 단계의 경로별 상태 기계 · 정지점 · put · put 비 0 재판정 · 되읽기 · 메타데이터 확인 · finally 정리 순서 · 요약 집계 범주는 줄 단위로 같다 |

의도 설명:

1. **경로 7 · 키 집합 1/2/1(B1).** `$paths` 열은 `path` · `env` · `user` · `role` · `keys` · `use` — `user` 는 url · acl 의 사용자 이름(경로 마지막 토큰)이고 kv 에 쓰는 것은 `keys` 뿐이다. T056 의 전역 `$keys = @('password')` 는 없애고 `$judge` · `$write` 첫 줄에서 `$keys = @($e.keys)` 로 받는다 — 그 아래 키 집합 · 문자열 · 되읽기 대조 줄은 T056 과 같은 텍스트다.
2. **url(B2 · B3ⓑ).** T054 의 접두 · 접미 · 가운데 대조를 그대로 쓰되 값은 Dragonfly 모양(`redis://` + 사용자 + `:` · `@dragonfly-<env>.data.svc:6379/0`). 세 검사가 모두 통과하면 url 은 정확히 기대 문자열과 같다(정확 일치와 동치) — 따로 두어 STOP 사유를 「스킴 · 사용자」 · 「호스트 · 포트 · db」 · 「비밀번호」로 분류해 낸다(값 0). 같은 길이의 다른 사용자 이름(S04l)은 접두 검사가 없으면 가운데 대조가 우연히 맞는다(T054 S04j 교훈 — 변이 M07 이 재확인).
3. **acl 렌더(B2 · D6).** `$render` 는 바깥 상태 없는 순수 함수다 — 하네스가 블록 AST 에서 이 대입문만 떼어 내(블록 전체는 실행하지 않고) 고정 입력으로 돌려 독립 구현과 바이트 단위로 대조한다(U01–U04). 입력 검증은 렌더 자신이 한다(env 는 `dev` · `prod` Ordinal · 사용자 비밀번호는 base64url 43자) — 그래서 판정 단계(live 비밀번호)와 쓰기 단계(새 비밀번호) 어디서 불러도 같은 규칙이다. Dragonfly v1.40.1 로더(build-notes 1차 자료): `MaterializeFileContents` 가 LF 로 줄을 나누고 공백으로 토큰을 가르며 토큰 4개 미만 · 첫 토큰이 `USER` 가 아닌 줄 · 인식 못 하는 토큰(CR 이 붙은 `+@all` 등)이 하나라도 있으면 파일 전체를 버리고 default nopass 로 기동한다 → 렌더는 CR · 탭 · 빈 줄 · 주석 줄 · 앞뒤 공백을 만들 길이 없고(S12 정적 · U01) default 줄을 반드시 넣는다(U04 의 로더 모의가 그 실패 모양을 잡는지 자체 시험).
4. **의존(B4).** acl 경로는 `$paths` 에서 그 env 의 사용자 경로 뒤에 있으므로, `$judge` 가 acl 을 볼 때는 그 env 사용자 판정이 끝나 있다. 사용자 경로 상태는 새 변수를 두지 않고 이미 있는 두 곳에서 읽는다 — absent = `$creates` 에 있음 · live-ok = `$pwOf` 에 있음 · 둘 다 아니면 STOP. 쓰기 단계는 `$creates` 를 경로 순서대로 쓰므로 acl 은 늘 그 env 사용자 뒤에 렌더되고, 사용자 쓰기가 실패하면 그 자리에서 throw 라 acl 에 닿지 않는다(S08f · S09b · S16e 등).
5. **쌍 판정(B5 · T056 C1 확장).** T056 은 "두 경로가 모두 live-ok 면 비교" 였다. T057 은 live-ok 사용자 경로마다 해시를 경로와 함께 모아 쌍마다 비교하고, 같은 값을 가진 경로를 모두 STOP 으로 바꾼다(각 STOP 줄이 짝 경로를 이름으로 가리킨다 — 비밀이 아니다). 생성 값은 판정 단계에 아직 없으므로 쓰기 단계에서 생성 직후 같은 비교를 한다 — 32바이트 RNG 에서는 일어나지 않는 경로라 생성기 회귀(변이 M12)만 잡고, 그 비교를 끈 변이(M13)는 하네스로 구별되지 않는다(등가 — §4).
6. **문구.** 요약 머리 `--- T057 Dragonfly ACL · 비밀번호 시드 결과 요약(…)` · 요약 폭 `{0,-34}`(가장 긴 경로 32자) · SKIP 줄 역할별(`$okText`) · OK 줄 `되읽기 해시 일치(password · url 또는 users.acl)` · 판정 줄에 "이 출력을 컨트롤러에게 붙인 뒤에만 머지한다"(2026-10-19 T056 사고의 교훈 — 런북 「판정」과 같은 문장) · `INFO vault CLI` 줄은 JSON stdin 근거에 T056 실행을 더하고 "줄바꿈(LF)이 든 값(users.acl)은 이 블록이 처음"이라고 알린다(§5 의 1).

### 메모리 규칙 「판정과 변경을 한 블록에 섞지 않는다」와 이 블록

T054 · T056 README §2 의 분석(결정 C6)이 그대로 적용된다 — 시드 블록 안의 판정은 운영자에게 판단을 묻는 단계가 아니라 쓰기 보호 가드다(① 실행 간 상태 인계 없음 — 재실행은 Vault 상태에서 판정을 다시 도출한다 · 판정 단계에서 읽은 live 비밀번호도 같은 실행 안에서만 쓰고 finally 가 버린다 ② 쓰기 직전 `seed` 정지점 — 쓸 경로 목록만 · 값은 아직 만들지도 않았다 ③ `-cas=0` 이중 방어). 되돌릴 수 없는 kv 삭제는 런북 「정리 판단」의 **① 점검 블록**(읽기 전용)과 **② 삭제 블록**(7경로 허용 목록 · 경로 재입력 · 삭제 뒤 `No value found` 확인)으로 나눴고, 두 블록은 하네스가 런북 코드 펜스에서 그대로 추출해 시험한다(R1 · R2 · GA · GB).

---

## 3. 붙여넣기 · 중지 안전성

T054 · T056 블록과 같은 규약이다(실측 근거는 T054 README §3).

- 전체가 최상위 문장 1개(`& { … }`) · 빈 줄 0 · TAB 0 · 끝 `}` + LF 1개(S12).
- 정지점 2개뿐: ① root 토큰(보안 입력 · 붙여넣은 직후 클립보드 비움 · `hvs.` 형식이 아니면 Vault 로 보내지 않는다) ② `seed`(`-MaskInput` · Ordinal 정확 일치 · 쓸 경로가 0 이면 나오지 않는다). 둘 다 바로 앞 직계 문장이 `$Host.UI.RawUI.FlushInputBuffer()`(S12 AST). 다른 단어 · 빈 Enter · `" seed"` · `SEED` = 쓰기 0(S06a–d).
- 권장 실행은 `pwsh -NoProfile -File '<절대 경로>'`. 붙여넣기는 `pwsh -NoProfile` 로 새로 연 창에서만.
- 중지(Ctrl+C): finally 첫 두 문장이 블록이 만든 `VAULT_TOKEN` · `VAULT_ADDR` 제거다(S12). put 도중 중지되면 그 경로의 요약은 `결과 미확인` 이고 재실행이 판정한다(S21a · S21b — 재실행은 그 경로를 live-ok 로 건너뛰고 acl 을 live 비밀번호로 렌더한다). 콘솔 Ctrl+C 자체는 모의할 수 없다(§5 의 4).

---

## 4. 하네스(`harness.ps1`)

### 모의 방식 · 가드(T056 하네스 그대로)

- PowerShell **함수가 native 명령보다 우선**하는 성질로 `vault`·`kubectl`(+ `.exe` · `curl` · `oci` · `gh`)을 가리고, `Read-Host` · `Set-Clipboard`(실패 결함 · ShouldProcess) · `Get-Clipboard` · `Get-ItemProperty`(클립보드 기록 + 모듈 로깅 정책 키 4) · `Test-Path`(`~/.vault-token`) · `Set-PSDebug`(`-Off` 만)를 모의한다.
- **S12 정적 관문이 맨 먼저**(관문 5단언 — 파서 오류 0 · 명령 · 정적 .NET 형식 · `$Host` · 리다이렉트 허용 목록 — 하나라도 FAIL 이면 블록 실행 0회 · exit 1). **실물 차단 가드 3중**(함수 가림 · PATH 함정 디렉터리 `%TEMP%\t057-harness-trap-<guid>` · `KUBECONFIG` 를 없는 경로로 · 시나리오마다 함정 표식 0 단언 · 끝나면 함정 디렉터리 삭제 — 잔여 0 확인).
- 가짜 Vault = 메모리 kv v2(버전 · 메타데이터 · soft-delete/destroy · CAS) · 허용 목록(`version` · `status` · `token lookup` · `kv metadata get` · `kv get` · `kv put`) 밖은 위반 · `kv metadata delete` 는 ② 삭제 블록 시나리오에서만.
- **과도 상태 모의(T054 · T056 그대로 전부)**: metadata 거짓 `No value found` · 빈 응답 · 500 · 되읽기 실패 · 깨진 JSON(안에 첫 키의 값 — password 또는 **acl 전문(줄바꿈 포함)**) · 저장 때 값 변형(tamper) · put 거부 · put 응답 유실 뒤 자기 CAS 충돌(`putLost`) · put 성공 뒤 metadata 만 바꾸기(`postMeta` cv2 · deletion · err) · put 도중 중단(`putInterrupt`) · 클립보드 비우기 실패 · 삭제 실패 · 삭제 noop · 삭제 뒤 조회 오류.
- **T057 에 맞춘 모의 · 계약**: `$PATHS` 7행(`env` · `user` · `role` · `keys` · `use`) · `$LIVE_PW` 5개(`MOCK-` 43자 · 서로 다름 · `_` 든 값 — 시작 전에 하네스가 스스로 확인) · **독립 구현** `Url-For`(문자열 이어 붙이기) · `Acl-For`(문자열 리터럴로 줄을 잇고 hex 는 바이트마다 `ToString('x2')` — 블록의 `$render` 와 코드를 나누지 않는다 · `Hex-Lower` 는 SHA-256 표준 벡터 "abc" 로 시작 전에 자기 확인) · **Dragonfly 로더 모의** `Test-AclLoader`(acl_family.cc `MaterializeFileContents` · `ParseAclSetUser` 토큰 종류 · default 줄 — `#` 뒤 홀수 길이 hex 는 실물보다 엄격하게 실패로 본다) · `Live-Data`/`Seed-Set`(사용자 비밀번호를 덮어쓴 맵으로 acl 까지 맞춰 심는다 — 쌍 판정만 걸리게) · tamper 모드 추가 `url`(url 의 비밀번호 마지막 글자) · `aclCrlf`(LF → CRLF) · `dropKey` 는 acl 경로면 `users.acl` 을 뺀다 · 노출 바늘 추가: url 전체 + url 안의 비밀번호(8자 조각 포함) · acl 전문 + acl 안의 `#` hex(대 · 소문자 전체 + 앞 16자) — url · acl 전문은 8자 조각을 만들지 않는다(호스트 · 규칙 문자열은 비밀이 아니다 · S02 자체 시험) · 8자 미만 값은 바늘로 쓰지 않는다(숫자형 값 시나리오의 거짓 양성 — 아래 실행 기록).
- **r2(F12) 추가**: 계약 상수 `$ACL_DEFAULT` = `USER default OFF +auth +hello` · `$ACL_DEFAULT_OLD` = 옛 줄(회귀 검사 · 1차 시드 모양 재현용 — `Acl-Old` 는 독립 렌더의 첫 줄만 옛 줄로 바꾼다) · `Acl-For` · `Check-Render` · U04 · S02 가 상수를 쓴다. **로더 모의 `+cmd`/`-cmd`**: 새 default 줄의 `+auth` · `+hello` 는 r1 로더 모의에서 `Unrecognized parameter` 였다(r1 렌더는 명령 토큰을 쓰지 않아 드러나지 않은 모의의 빈칸). 실물 `MaybeParseAclCommand`(acl_family.cc :1057–1078)는 대문자로 바꾼 이름을 명령 레지스트리에서 찾고 없거나 별칭이면 `Unrecognized parameter`(:1173–1176) = 파일 전체 미적재 = 무인증 기동이다 — 모의는 렌더가 쓰는 AUTH · HELLO 만 안다(등록된 다른 명령도 거부 = 실물보다 엄격). 로더 모의는 여전히 **문법만** 본다: 옛 default 줄도 통과시킨다(U04 가 그 한계를 단언으로 고정 — 인증 경로는 S12 의 default 줄 규칙이 막는다).
- **이 파일에 url 리터럴 · `#` 뒤 hex 리터럴 0** — url 은 이어 붙이기로만 만들고 hex 는 실행 중에 계산한다(지시서 §3 비밀 모양 grep 0).

### 모든 시나리오의 공통 사후 조건(T056 그대로 + 바늘 확장)

1. **비밀 노출 0** — 바늘 = 비밀 전체 · base64 · 8자 조각 · SHA-256 hex(대 · 소문자 전체 + 앞 16자) + url · acl 전문 · acl 안의 hex. 면 = 화면(`*>&1`) · 프롬프트 · argv · 클립보드 · `$Error`(메시지 · 예외 전문 · TargetObject · ErrorDetails) · 바뀐 전역 변수 · 환경 변수.
2. `VAULT_TOKEN` · `VAULT_ADDR` 없음(시작 전에 있던 경우는 "건드리지 않음").
3. 위반 0 · 함정 표식 0 · 성공 스트림 0 · 클립보드에는 공백만 · 비밀 입력은 `-AsSecureString` · 입력은 전부 가려진다 · `kv put` 은 전부 `-cas=0` + stdin · `seed` 정지점 전 put 0 · finally 요약 · 창 종료 체크리스트 · 첫 동작 = `Set-PSDebug -Off` 1회 · `INFO vault CLI` 줄이 root 토큰 프롬프트보다 먼저 · (완주 시나리오) 입력 전부 소비.
4. 런북 블록(Run-RbCase): 창의 `VAULT_*` 그대로 · 평문 Read-Host · `kv put` 0 · ① 점검 블록은 삭제 · put 0 · 첫 Read-Host 전 클립보드 비움.

### S12 정적 추가(B8)

`$render` 대입문 정확히 1개(오른쪽 = 스크립트블록 리터럴) · 렌더 코드에 CR 표기(백틱 r · `[char]13` · `0x0D` · `\r`) 0 · `NewLine` 0 · `-join` 백틱 n(LF) 사용 · `.ToLowerInvariant()` 사용 · **순수 함수**(렌더 안의 명령 호출 0 — `& $eq` 같은 헬퍼 호출 포함 · param · 지역 대입 · foreach 변수 · `$null`/`$true`/`$false` 밖의 변수 참조 0) · 블록 전체 백틱 r 0. `$AllowedHelpers` 에 `render` 를 더했다(그 밖의 허용 목록 · 관문은 그대로 — 파일 쓰기 · `[Environment]` · 임시 파일 경로는 명령 · 형식 관문이 막는다).

**r2(B12 · F12) default 줄 규칙 3단언**(harness.ps1:1013–1018): ① `$render` 안에서 `USER default` 로 시작하는 문자열 상수(대소문자 무시)가 정확히 1개이고 값이 `USER default OFF +auth +hello` 와 Ordinal 일치 ② 그 상수에 `-@all` 0(대소문자 무시 — 옛 형식 회귀 금지) ③ 블록 전체(주석 포함)에 옛 줄 `USER default OFF -@all` 0(머리 주석의 형식 설명까지 맞춘다). 셋은 S12 의 **일반 단언**이다 — `-Gate`(관문 5단언: 블록을 실물에서 떼어 놓는 안전 관문)로 만들지 않았다: 옛 줄은 실물 탈출 위험이 아니라 행동 결함이므로 런타임 시나리오를 그대로 돌려 U01 · U02 · S01 · S37a … 가 함께 FAIL 하게 둔다(하네스 exit 1 은 같다 — 변이 M19 · M20).

### T056 하네스와 달라진 시나리오(T056 의 시나리오 ID 는 전부 남겼다 — 경로 · 기대 문구만 7경로로)

| 구분 | 시나리오 |
|---|---|
| ⑨ 렌더 단위 시험(추가) | **U01** dev(모의 비밀번호 3 → 독립 계산과 바이트 일치 · 4줄 · 순서 · default 줄 = `USER default OFF +auth +hello`(r2) · 소문자 hex 64 = SHA-256(UTF-8) · 규칙 문자열 · 끝 LF 1 · CR/TAB/BOM/비 ASCII 0 · 앞뒤 · 연속 공백 0 · 토큰 ≥ 4 · 로더 모의 통과 · 평문 0) · **U02** prod(3줄 · 맵에 sample-pod 가 있어도 줄 0 · 같은 입력 = 같은 출력) · **U03** 잘못된 입력 9종 → throw(값 미출력) · **U04** 로더 모의 자체 시험(CRLF · 마지막 줄 CR 1바이트 · BOM · 탭 · 3토큰 줄 · 주석 줄 · default 없음 · 홀수 hex · **모르는 명령 토큰 `+auht`**(r2) 를 잡는다 · **옛 default 줄 `-@all` 은 통과시킨다 = 문법만 본다는 한계 고정**(r2)) |
| ACL 파일 갱신(r2 추가 · B14 · F12) | **S37a** 1차 시드 상태(사용자 5 live-ok · acl 2 = 옛 default 줄 렌더) → 고친 블록 재실행 = 사용자 5 SKIP · acl 2경로 `acl 내용 불일치` STOP · 쓰기 0 · 덮어쓰기 0 · vault 호출 17(런북 「ACL 파일 갱신」이 acl 을 먼저 지우는 이유) · **S37b** 같은 상태 → 런북 ② 삭제 블록(코드 펜스 추출 그대로 · Setup 에서 acl 2경로를 한 번에 한 경로씩 — OK(No value found 확인) 2 · 모의 삭제 기록 = acl 2경로 정확히) → 시드 블록 재실행 = 사용자 5 SKIP · acl 2 absent → 생성 v1 · 첫 줄 새 default · `Acl-For`(live 비밀번호)와 바이트 일치 · 사용자 값 불변 · put 2(dev → prod) · vault 호출 21 — R2 관문을 통과해야 돈다 |
| ⑦ 7경로 absent | **S01** 7 생성 · 키 집합 · url · acl = 독립 렌더 · 5개 고유 · put 본문 키 집합(경로 순서) · 본문에 날 LF 0 · 목록 줄 7 · 쓰기 순서(put 순서 = 기대 순서 단언 추가) · vault 호출 31 · 요약 7행 |
| ⑥ acl 만 생성(B4ⓑ) | **S35a** dev acl 1경로만(기대 바이트열 = 모의 live 비밀번호 렌더 · vault 호출 19) · **S35b** prod acl · **S35c** 일부 live-ok + 일부 absent + acl absent → identity-admin 생성 → acl = live 2 + 새 1 로 렌더 |
| ⑤ 의존(B4ⓐ) | **S36a** dev 사용자 3 absent + acl live → STOP(acl kv get 0 · vault 호출 10) · **S36b** 하나만 absent · **S36c** 사용자 STOP + acl live → acl 판정 불가 STOP · **S36d** prod 만(env 독립) |
| ①②③ url | **S04l** 사용자 부분만 같은 길이로 다름 · **S04l2** 다른 사용자 이름 · **S04l3** `rediss` 스킴 / **S04m** prod 호스트 · **S04m2** 포트 · **S04m3** db · **S04m4** 끝 LF · **S04m5** 네임스페이스 / **S04n** 다른 43자 · **S04n2** prod 비밀번호 · **S04n3** 대소문자 한 글자(Ordinal) |
| ④ acl 내용 | **S04q** 마지막 줄 CR 1바이트 · **S04q1** CRLF · **S04q2** 대문자 hex · **S04q3** 끝 LF 없음 · **S04q4** 끝 LF 2개 · **S04q5** 낡은 비밀번호(회전 반쪽) · **S04q6** sample-pod 줄 없음 · **S04q7** BOM(U+FEFF — 문화권 비교 함정) · **S04q8** hex 한 글자 · **S04q9** 여분 키 · **S04q10** 숫자 · **S04q11** prod 에 sample-pod 줄 |
| ⑧ 쌍 판정(B5) | **S04j** dev↔prod identity-admin · **S04j2** dev admin↔identity-admin · **S04j3** 셋(각 STOP 줄이 나머지 둘을 가리킨다) · **S04k** 대소문자만 다른 두 값 → 7 SKIP |
| 그 밖 추가 | **S04c2** pod 경로에 T054 모양 3키 · **S04g2** url 숫자 · **S08f · S08g** dev 사용자 3 생성 뒤 acl put 거부 → 재실행이 acl 만 렌더해 쓴다(B4) · **S09e** url tamper · **S09f** acl CRLF tamper · **S09g** acl 키 누락 · **S19c · S19d** acl 판정 중 kv get 실패 · 깨진 JSON(acl 전문) · **GA01b** ① 점검 acl 경로(키 이름 `users.acl` 만) · **GA03e · GB03c** T054 경로 · **GA08b** ① 점검의 깨진 acl JSON · **GB07b** ② 삭제 acl 경로 |
| 수정 | **S04c** = identity-admin 에 url 없음(T056 S04c 의 T054 모양 3키는 S04c2 로) · **S03 · S03b** = 한 env 만 live-ok(4 · 3경로) · **S08a** = prod identity-admin 거짓 absent(앞 5경로 생성 뒤 CAS 충돌) · **S16d** putLost = dev acl(acl 도 응답 유실 재판정) · **S21a · S21b** = 둘째 경로 중단 → 재실행이 acl 을 live 2 + 새 1 로 렌더 · **GA03d · GB03b** = T056 경로(`kv/prod/kafka/identity-admin`) |

### 시나리오와 결과(r2 — 2026-10-22 16:31 KST 최종 실행 · `PASS 4923 / 4923` · 시나리오 152 / 152 · exit 0 · 14.2초 · 함정 디렉터리 잔여 0)

| 묶음 | 시나리오 | 결과 |
|---|---|---|
| 정적 | S12(관문 5 + 구조 · 위생 + B8 렌더 규칙 + r2 default 줄 규칙 3 — 단언 38) | PASS |
| 렌더 단위 | U01–U04 | PASS × 4 |
| 정상 · 노출 | S01 · S02 | PASS × 2 |
| 한쪽만 live-ok · acl 만 생성 | S03 · S03b · S35a–c | PASS × 5 |
| 사용자 경로 live-mismatch | S04a–i · S04c2 · S04f2 · S04f3 · S04g2 | PASS × 13 |
| url | S04l–l3 · S04m–m5 · S04n–n3 | PASS × 11 |
| acl 내용 | S04q · S04q1–q11 | PASS × 12 |
| 의존 B4 | S36a–d | PASS × 4 |
| 쌍 판정 B5 | S04j · S04j2 · S04j3 · S04k | PASS × 4 |
| dead · 정지점 · Vault 상태 | S05a–c · S06a–d · S07a–f | PASS × 13 |
| 과도 상태 · 부분 실패 재실행 | S08a–g | PASS × 7 |
| 되읽기 대조 | S09 · S09b–g | PASS × 7 |
| 클립보드 · 세션 · 환경 | S10a–e · S11a–f | PASS × 11 |
| 토큰 · put · 재실행 · 판정 실패 | S13a–b · S14 · S14b · S15 · S16 · S16d · S16e · S17 · S18 · S19 · S19b–d | PASS × 14 |
| 쓰기 뒤 metadata · put 중단 · 모듈 로깅 | S20a–c · S21a–b · S22a–d | PASS × 9 |
| 런북 정적 | R1 · R2(관문 6 · 허용 경로 = 계약 7경로 정확히) | PASS × 2 |
| ① 점검 | GA01 · GA01b · GA02 · GA03a–e · GA04–GA08 · GA08b · GA09 | PASS × 15 |
| ② 삭제 | GB01–GB03 · GB03b · GB03c · GB04–GB06 · GB06b · GB07 · GB07b · GB08–GB12 | PASS × 16 |
| ACL 파일 갱신(r2 · B14 · F12) | S37a(단언 52) · S37b(단언 67 — ② 삭제 블록 연쇄 · R2 관문 통과분) | PASS × 2 |

### 실행 기록 — 하네스 결함 · 변이 시험(2026-10-22 · r1 · r2)

- **1차 실행**(런북 소절을 쓰기 전): `시나리오 PASS 116 / 119` · `PASS 4133 / 4152` · exit 1. FAIL = R1 · R2(표식 펜스 0개 — 런북 소절 작성 전의 기대 red · 관문이라 GA · GB 는 돌지 않았다) + **하네스 결함 1**: S04q10(acl 값 = 숫자 `42`)의 「노출 0: 환경 변수」 — 2자 문자열 `42` 가 바늘이 되어 환경 변수 문자열에 우연히 걸렸다 → url · acl 바늘은 8자 이상만(`Add-SecretField`) · 시나리오 값을 고유한 14자리 숫자로. **블록 행동 결함 0**.
- 런북 소절 작성 뒤: `시나리오 PASS 150 / 150` · `PASS 4798 / 4798` · exit 0.
- **r2(2026-10-22 16:14–16:32 KST)**: ① B11 · B12(상수 · 렌더 기대 바이트 · S12 default 줄 규칙 · 로더 모의 `+cmd` · U04 +3) 반영 뒤(16:14) `PASS 4804 / 4804` · 시나리오 150 / 150 · exit 0 · 18.1초 — r1 대비 단언 수가 바뀐 시나리오는 S12(35 → 38) · U04(9 → 12)뿐(나머지 148 시나리오 단언 수 동일) ② 런북 B14 반영 뒤(16:19) `PASS 4804 / 4804` · 16.5초(R1 · R2 · GA · GB 그대로 PASS — 두 표식 펜스 불변) ③ S37a · S37b 추가 뒤(16:23) `PASS 4923 / 4923` · 시나리오 152 / 152 · exit 0 · 21.6초 ④ 변이 22종 뒤 최종 재실행(16:31) 같은 결과 · 14.2초. **하네스 결함 1(모의의 빈칸)**: r1 로더 모의는 `+cmd`/`-cmd` 토큰을 몰라 새 default 줄을 `Unrecognized parameter` 로 봤을 것이다(r1 렌더가 명령 토큰을 쓰지 않아 드러나지 않았다) → 실물 소스(acl_family.cc :1057–1078 · :1173–1176)대로 더했다(아는 명령 AUTH · HELLO). **블록 행동 결함 0** — 옛 default 줄은 설계 결정 D6 의 결함이었고(build-notes 「VD-4 1차 실측」 결함 1) 블록은 D6 를 그대로 렌더했다.
- **변이 시험**(세션 스크래치의 블록 · 런북 사본 · `-Block` / `-Runbook` · 변이 실행기 — 저장소 밖: r1 `t057-blocks-build/run-mutations.ps1` 20종 · r2 `t057-fix-r2-blocks/run-mutations.ps1` 22종 = r1 20종(M10 찾기 문자열만 새 default 줄로) + M19 · M20 — r2 는 전부 다시 쟀다 · 347.9초 · 함정 디렉터리 잔여 0) — r2 비등가 21종 전부 exit 1 · 등가 1종(M13)만 생존(r1 과 같다):

| 변이 | r1(시나리오 150) | r2(시나리오 152 · 잡은 시나리오) |
|---|---|---|
| M01 put 에서 `-cas=0` 제거 | 115 / 150 · FAIL 35 | 116 / 152 — S12(정적 vault 호출 모양) + 쓰기가 있는 시나리오 전부(공통 단언 「kv put 은 전부 -cas=0」) · S37b · FAIL 36 |
| M02 렌더 줄 구분 CRLF | 123 / 150 · FAIL 27 | 124 / 152 — S12(렌더 CR 0 · `-join` 백틱 n) · U01 · U02 · U04 · S01 · S03 · S35a–c · S04q1 · S36d · S04j … · S37b · FAIL 28 |
| M03 렌더 `ToLowerInvariant` 제거(대문자 hex) | 123 / 150 · FAIL 27 | 124 / 152 — S12 · U01 · U02 · U04 · S01 · S04q2 … · S37b · FAIL 28 |
| M04 OK 줄에 `$pw` 보간 | 126 / 150 · FAIL 24 | 128 / 152 — 사용자 경로를 생성하는 시나리오 전부(노출 0: 화면) · FAIL 24 |
| M05 쌍 판정 비활성 | 147 / 150 | 149 / 152 — S04j · S04j2 · S04j3 |
| M06 의존 B4ⓐ 제거 | 147 / 150 | 149 / 152 — S36a · S36b · S36d(사유가 「판정 불가」로 바뀐다) |
| M07 url 접두(스킴 · 사용자) 검사 비활성 | 147 / 150 | 149 / 152 — S04l · S04l2 · S04l3 |
| M08 acl live 대조 비활성 | 140 / 150 | 141 / 152 — S04q · S04q1–q8 · S04q11 · **S37a**(옛 acl 이 live-ok 로 SKIP 된다) |
| M09 acl 대조를 문화권 `-eq` 로 | 148 / 150 | 150 / 152 — S04q2(대소문자) · S04q7(U+FEFF) |
| M10 렌더 default 줄 제거 | 125 / 150 · FAIL 25 | 125 / 152 — **S12(r2 default 줄 규칙 — 상수 0개)** · U01 · U02 · U04 · S01 … · S37b · FAIL 27 |
| M11 sample-pod 규칙에서 `%R` 제거(거부 목록 쓰기 허용) | 127 / 150 · FAIL 23 | 128 / 152 — U01 · S01 · S03 … · S37b · FAIL 24 |
| M12 생성기를 고정 32바이트로 | 127 / 150 · FAIL 23 | 129 / 152 — S01 등 23(쓰기 단계 B5 대조가 둘째 사용자에서 `생성 값 중복` STOP) |
| M13 쓰기 단계 B5 대조 비활성 | 150 / 150 생존 | **152 / 152 — 생존(등가)**: 32바이트 RNG 는 겹치지 않으므로 어떤 시나리오도 이 분기에 닿지 않는다. 대조 자체가 동작한다는 증거는 M12 다 |
| M14 acl 불일치 사유에 렌더 결과 보간 | 140 / 150 | 141 / 152 — S04q 계열 10 · S37a(노출 0: 화면 — acl 의 hex 바늘) |
| M15 url 조립 호스트 오타 | 133 / 150 · FAIL 17 | 135 / 152 — S01 등 17(생성 url 대조) |
| M16 prod 렌더에도 sample-pod | 125 / 150 · FAIL 25 | 125 / 152 — U02 · U03 · S01 … · S37a · S37b · FAIL 27 |
| M17 쓰기 뒤 `$pwOf` 갱신 제거 | 131 / 150 · FAIL 19 | 133 / 152 — acl 을 새로 렌더하는 시나리오 전부(렌더가 누락 사용자로 throw) · FAIL 19 |
| M18 url 비밀번호 부분 대조 비활성 | 147 / 150 | 149 / 152 — S04n · S04n2 · S04n3 |
| **M19(r2 신규)** 렌더 default 줄을 옛 줄 `USER default OFF -@all` 로(코드만 — 1차 실측 사고 회귀) | — | 124 / 152 — **S12(default 줄 규칙 3단언 전부: 상수 = 옛 줄 · `-@all` · 블록 전체 옛 줄)** · U01 · U02 · U04 · S01 · S03 · S03b · S35a–c · S36d · **S37a**(옛 acl 이 live-ok 로 SKIP) · S04j … · S37b · FAIL 28 |
| **M20(r2 신규)** 머리 주석의 형식 설명만 옛 줄로(코드는 새 줄) | — | 151 / 152 — **S12 하나**(블록 전체(주석 포함) 옛 줄 0 단언) — 주석까지 보는 규칙이 실제로 잡는다는 자체 시험 |
| R01 런북 ① 점검 허용 목록에 T056 경로 추가 | 148 / 150 | 150 / 152 — R1(허용 경로 상수) · GA03d |
| R02 런북 ② 삭제 재입력 비교 `OrdinalIgnoreCase` | 149 / 150 | 151 / 152 — GB06b |

- T054 · T056 하네스의 변이 표는 다시 재지 않았다 — 가드 · 공통 사후 조건 · 정적 관문 · 과도 상태 단언은 빼지 않고 옮겼다(바꾼 것은 위 「달라진 시나리오」 표뿐이다).

---

## 5. 하네스가 증명하지 못하는 것

모의는 **가정한 CLI 출력 형식**을 되돌려줄 뿐이다. T054(2026-10-15) · T056(2026-10-19) 블록이 같은 창 · 같은 CLI(v2.1.0 · 서버 2.0.4)로 라이브로 돌아 `status` JSON · `No value found` 문구 · `kv get`/`metadata get` JSON · `token lookup` 정책 · JSON stdin · `hvs.` 접두는 확인됐다. 여전히 증명하지 못하는 것:

1. **줄바꿈이 든 값의 JSON stdin 왕복(실물 Vault)** — `users.acl` 은 LF 를 담은 첫 kv 값이다. `ConvertTo-Json -Compress` 는 LF 를 `\n` 으로 이스케이프한 한 줄 JSON 을 만들고(pwsh 7.6.6 확인 · 하네스 S01 「본문에 날 LF 0」) 모의 Vault 는 그것을 되돌려 해시가 맞지만, 실물 CLI · 서버의 왕복은 라이브 미실측이다. 다르면 첫 acl 경로(dev acl)의 되읽기 해시 대조가 STOP 으로 잡는다 — 그때 dev 사용자 3경로는 이미 v1 이다(런북 실패 표 「되읽기 해시 불일치」 행 — 컨트롤러 보고 · 정리 판단). → **r2 시점: 라이브 확인됨**(2026-10-22 14:15–14:40 KST 1차 시드 — 런북 소절 실행 기록: acl 2경로 `생성 v1 · 되읽기 해시 일치(users.acl)` · CLI v2.1.0). 남는 것은 다른 CLI 버전뿐이다(실행 기록의 `INFO vault CLI` 줄과 대조).
2. **실제 Dragonfly 로더** — 렌더 규칙은 v1.40.1 소스(build-notes 1차 자료)와 하네스의 로더 모의(`Test-AclLoader`)로만 맞췄다. 실물이 이 aclfile 을 싣는지(무인증 기동이 아닌지)는 머지 뒤 pod 로그 grep(`could not load ACL file` · `Error while parsing aclfile` · `Error materializing acl file` · `Invalid password hash` 0줄 — 로그 문구 0 은 적재 증거가 아니다)과 VD-4 Job 의 `noauth` · `ACL LIST` · NOPERM 실측(build-notes D12 · D13)이 판정한다. ESO 가 `property: users.acl` 을 바이트 그대로 Secret 에 옮기는지 · kubelet 이 파일로 그대로 마운트하는지도 같은 실측 몫이다.
   **r2 — 2026-10-22 1차 실측 사고: 모의는 로더 문법만 보고 인증 경로는 보지 못했다 — 실측(로컬 Docker · 라이브 Job)이 잡았다.** 옛 default 줄 `USER default OFF -@all` 은 하네스 150 / 150 PASS · 로더 모의 통과 · 라이브 pod 로그 aclfile 오류 문구 0 · 확인 스크립트 post ALL PASS 였지만, Dragonfly 는 NOAUTH 관문을 지난 AUTH · HELLO 를 **연결의 현재 사용자(default)의 ACL** 로 검사하므로(main_service.cc :1403–1407 → `IsUserAllowedToInvokeCommand` · `kAuth`/`kHello` = FAST|CONNECTION) 모든 사용자의 AUTH 가 `NOPERM default has no ACL permissions` 였다(VD-4 Job `data-assert-8wzr2` 06:39:50Z — `reader-get` FAIL · NOPERM 을 기대하는 검사 3개는 AUTH 실패 문구로 거짓 PASS · 사고 로그 `.superpowers/t057/evidence/vd4-data-assert-log-2026-10-22.txt`). 로컬 Docker(같은 이미지 v1.40.1)가 옛 줄(변형 A)의 재현과 `+auth +hello`(변형 C)의 정상을 확인했다(build-notes F12). r2 는 default 줄을 S12 로 **정적으로 고정**할 뿐 인증 경로를 모의하지 않는다(U04 가 "옛 줄도 로더 모의 통과"를 단언으로 남긴다) — 인증 경로의 증거는 여전히 라이브 VD-4 의 `writer-set` · `reader-get` PASS 뿐이다.
3. **url · 비밀번호의 소비 쪽** — `assert-env` · `<pod>-env` 가 `url` 로 실제 인증되는지는 VD-4 Job · T059 · T072 몫이다(이 블록이 보장하는 것은 "kv 에 정확한 모양의 값이 v1 으로 있다" 까지).
4. **콘솔 고유 동작 · 클립보드 · 레지스트리 · 전사 정책 · 붙여넣기 창의 호스트 상태 · 호스트 UI 직접 쓰기** — T056 README §5 의 1–5 그대로(정적 규칙 · 창 체크리스트로만 방어).
5. **쓰기 단계 B5 대조(생성 몫)** — RNG 를 모의할 수 없어(정적 .NET 메서드) 시나리오로는 닿지 않는다. 동작은 변이 M12(고정 생성기 → `생성 값 중복` STOP)로만 확인했다.
6. **런북 「ACL 파일 갱신」 4–7단계(r2)** — 하네스는 2–3단계(② 삭제 블록 → 시드 재실행 — S37b)만 시험한다. ESO 의 Secret 갱신(`refreshTime` · `syncedResourceVersion` 의 뜻은 ESO v2.10.0 소스로 확인했다) · pod 삭제 뒤 ReplicaSet 재생성 · 새 pod 의 aclfile 적재 · Argo `Synced` 유지 · VD-4 재실측은 라이브 몫이다(런북 실행 기록 2차 자리).

## 6. 남은 위험(라이브 실행 시)

- **aclfile 파싱 오류 = 무인증 기동(조용한 실패)** — 렌더 · 하네스가 막는 것은 이 블록이 만드는 값이다. 블록 밖에서 acl 을 고친 값(손으로 `vault kv put` 등)은 다음 실행의 판정이 「acl 내용 불일치」로 잡지만, 그 전까지 ESO 가 그 값을 Secret 에 옮기고 Dragonfly 가 다음 기동에서 무인증으로 뜰 수 있다 — 탐지는 로그 grep · `noauth`(위 §5 의 2). r2: 모르는 명령 토큰(예: `+auth` 오타)도 파싱 오류다(실물 `Unrecognized parameter` — U04).
- **default 줄의 인증 경로(r2 · F12)** — 블록은 이제 `USER default OFF +auth +hello` 를 렌더하고 S12 가 그 줄을 정적으로 고정한다. 그러나 모의는 인증 경로를 재현하지 않는다(§5 의 2 — 1차 실측 사고는 하네스 전부 PASS 였다) — 라이브 증거는 VD-4 `writer-set` · `reader-get` PASS 뿐이다(`noauth` PASS 는 적재만 · NOPERM 기대 검사는 AUTH 실패 문구로 거짓 PASS 가 될 수 있다). 이 줄을 다시 바꾸는 변경(예: 등가 상위집합 `+@connection`)은 하네스 상수 · S12 와 함께 로컬 Docker 또는 라이브 VD-4 로 다시 잰다.
- **kv 의 옛 acl(1차 시드 — r2 시점 그대로)** — 고친 블록의 재실행은 옛 acl 을 「acl 내용 불일치」로 멈출 뿐 덮어쓰지 않는다(S37a — 안전 쪽 실패). 복구는 런북 「ACL 파일 갱신」(acl 2경로만 ② 삭제 → 재실행 → ES 갱신 확인 → pod 삭제 → 컨트롤러 VD-4)이고, 「정리 판단」의 "머지 뒤에는 지우지 않는다"에 대한 이 절만의 예외다 — 사용자 경로를 잘못 지우면 재실행이 새 비밀번호를 만들어 회전이 된다(런북 3단계: 사용자 경로가 `PLAN` 이면 `seed` 를 입력하지 않는다 · 실패 표 「정상이다」 행). 삭제 ~ 재시드 사이에 ESO 주기가 끼면 ES 가 잠시 `SecretSyncedError`(Secret 은 옛 내용 유지 · 돌고 있는 pod 무영향 — ESO v2.10.0 · `deletionPolicy` 기본 Retain) · pod 삭제 뒤 옛 · 새 pod 가 같은 PVC 를 잠시 함께 쓸 수 있다(지금은 쓰기 0 — 무해).
- **판정 단계에서 읽은 live 비밀번호를 쓰기 단계까지 메모리에 둔다**(acl 렌더 — B4) — `seed` 정지점에서 기다리는 동안에도 프로세스 메모리에 있다(.NET 문자열은 지울 수 없다 · finally 가 참조를 끊는다). `-File` 권장 실행은 프로세스 종료로 끝낸다. 그 사이 다른 기록자가 사용자 경로를 바꾸면(v2) acl 이 옛 비밀번호로 렌더된다 — `-cas=0` 은 acl 경로만 지킨다. 실행 창은 블록 전용이고 시드는 운영자 한 사람이 한다(창 D).
- **회전 반쪽**(사용자 경로만 바꾸고 acl 은 그대로) — Dragonfly 는 옛 비밀번호를 계속 받고 소비자는 새 url 로 실패한다. 이 블록의 재실행은 「acl 내용 불일치」로 멈출 뿐 고치지 않는다(회전은 T084 — 런북 「회전」 문단: `<user>` 와 `acl` 을 함께).
- **같은 비밀번호(B5)는 블록이 돌 때만 잡는다** — 시드 뒤 블록 밖에서 한쪽을 다른 쪽 값으로 바꾸면 다음 실행 전까지 보이지 않는다. 같음만 본다(대소문자 한 글자만 다른 쌍은 SKIP — S04k).
- **사용자 경로 정리 뒤 acl 을 남기면** 재실행이 「absent 인데 acl 이 이미 있다」로 멈춘다(B4ⓐ — 안전 쪽 실패). 런북 정리 판단 · ② 삭제 블록의 OK 줄이 acl 도 지우라고 안내한다.
- **admin 비밀번호는 ESO 소비자가 없다** — 운영자가 `ACL LOAD` · VD-4 대체 조회에 쓸 때 kv 에서 직접 읽어야 한다(값을 화면에 내지 않는 절차는 T084 · VD-4 런북 몫 — 이 블록은 넣기만 한다).
- **그 밖(T056 README §6 그대로)**: 자식 프로세스의 `VAULT_TOKEN` 상속 · 생성 값의 유일한 사본은 kv(Raft 스냅샷 전 유실이면 재시드) · root 토큰 사용(revoke 는 T084 뒤) · 클립보드 기록 점검은 사용자 키만 · 클립보드 비우기 실패는 경고만 · 붙여넣기 실행의 부수 효과(전역 strict 모드 끔) · 머지가 먼저 되면 저절로 회복하지 않는다(런북 「늦은 시드」) · kv 정리는 되돌릴 수 없다(두 블록만 · 머지 뒤 금지) · put 비 0 재판정의 `기록됨(응답 유실 …)` 은 창 C 순단 신호.
