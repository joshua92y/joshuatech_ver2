# T045 G4 분리 구현 보고서

상태: 오프라인 구현·검증 완료. 수정 round2 본체·하네스 동결, 독립 검토 Approved/Approved 및 잔여 0건. 최종 하네스 **122/122 PASS, lint 0, bash 대화형 모의 3/3 PASS**. 변이 **223/223 CAUGHT, 잠금 127/127 CAUGHT, ESCAPED·ANCHOR-ERR·NO-OP 0**. 실패 근거 감사와 보강 분류 재평가 223/223 완료. 라이브 실행 없음.

## 수정 범위

- g4-adopt.ps1: 클러스터 쓰기 0, 캡처·PM·머지 감시·인수 판정·복구 안내 유지. 접두어/이전 드릴 상태 사슬 제거. 별도 drill로 hash·UID 인계.
- g4-drill.ps1: 독립 삭제 1 요청, 신원·권한·ES Ready=True/SecretSynced·hash·UID·data-hash·2 Ready 파드·break-glass·이름 타자·second·삭제 직전 재확인. 삭제 요청 전 회계. 남은 파드 상태와 새 파드 Ready 및 접근 경로 확인.
- g4-restore.ps1: R2 후 정규 재인수/drill와 ES 없는 비상 수동 R3를 구별. data-hash 보존 경고.
- harness-g4.ps1: 기존 RED 초안을 보존해 최종 122 시나리오와 세 블록 AST 검사로 재구성. 비밀 누출/클립보드/변경 argv 검사 유지. EOF, 런타임 허용 동사, namespace, R3 실행 줄 전문·순서 고정.
- mutants-g4.ps1: 기존 201개 ID 보존, 신규 22개. 임시 디렉터리 경계 확인과 하네스 snapshot으로 동일 판본 전수 실행.

## RED/GREEN 증거

명령은 모두 `pwsh -NoProfile -File specs/003-platform-foundation/design/t045-blocks/g4/harness-g4.ps1`이며 네이티브 kubectl/ssh/oci는 하네스 함수 모의다.

1. 기준 RED: PASS 99/142, lint 실패 2. adopt delete AST 금지, 모의 ADOPT-WRITE 및 공통 변경 0 위반, drill 파일 부재 확인. 로그: `%TEMP%/g4-red.txt`.
2. 분리 구현 추가 RED: PASS 110/114, lint 0. R3 오류=0건 단언 수정 요구, 빈 파드 시작시각, 빈 Secret 값/빈 해시 입력, 삭제 후 생존 파드 Ready 상실의 네 반례 실패 직접 관찰. 로그: `%TEMP%/g4-red-extra.txt`.
3. 최초 GREEN: PASS 114/114, lint 실패 0. 로그: `%TEMP%/g4-green.txt`. 해당 시점에 본체 리뷰를 요청했다.

## 변이 작업 완료

201개 기존 변이를 ID별로 유지/드릴 이동/사라진 사슬의 adopt 쓰기 금지 변이로 재구성했다. 신규 22개를 포함해 223/223 CAUGHT이며 ANCHOR-ERR/NO-OP는 0이다. 아래 ID 대응표와 마지막 실패 근거 감사에 최종 판정을 기록했다.

## 현재 제약

운영 API, Vault, SSH, OCI, 개인 자격 접근 없음. 실제 JSONPath/ESO/Argo/네트워크 단절/Ctrl+C/터미널/clipboard 동작은 미확인. 컨트롤러가 전체 저장소 검사를 맡고 있으며 infra 검사의 TF_VAR_budget_alert_email 미설정은 본 범위 밖이다.

## 기존 변이 201개 ID 대응표

전부 실제 변이 대상으로 보존한다. 재구성 항목은 예전 접두어 구현을 시험하지 않으며 그 구현 제거를 대체한 adopt 쓰기 금지 경계를 시험한다. 41개 ID가 여러 경로·동사의 동일 불변식을 반복하므로 41개 독립 위험 제거로 해석하지 않는다.

| ID | 처리 | 현재 파일 | 이전 목적과 대응 근거 |
|---|---|---|---|
| M01 | 유지 | g4-adopt.ps1 | 인수 후 값 해시 판정 제거 → 동일 결함/동일 블록 |
| M02 | 유지 | g4-adopt.ps1 | 인수 후 UID 판정 제거 → 동일 결함/동일 블록 |
| M03 | 유지 | g4-adopt.ps1 | ownerReferences 판정 제거 → 동일 결함/동일 블록 |
| M04 | 유지 | g4-adopt.ps1 | managed 라벨(양성 증거) 판정 제거 → 동일 결함/동일 블록 |
| M05 | 유지 | g4-adopt.ps1 | data-hash 하드 판정 제거(ESO 쓰기 증거 없이 통과) → 동일 결함/동일 블록 |
| M06 | 유지 | g4-adopt.ps1 | Secret 의 Argo tracking 복사 판정 제거 → 동일 결함/동일 블록 |
| M07 | 유지 | g4-adopt.ps1 | ES tracking-id 소유 Application 판정 제거 → 동일 결함/동일 블록 |
| M08 | 유지 | g4-adopt.ps1 | platform-cloudflared 의 external-secrets.io 소유 판정 제거 → 동일 결함/동일 블록 |
| M09 | 유지 | g4-adopt.ps1 | 파드 불변 판정 제거 → 동일 결함/동일 블록 |
| M10 | 유지 | g4-adopt.ps1 | 키 집합(TUNNEL_TOKEN 하나) 검사 제거 → 동일 결함/동일 블록 |
| M11 | 유지 | g4-adopt.ps1 | SecretSyncedError 고착 판정 제거 → 동일 결함/동일 블록 |
| M12 | drill 이동 | g4-drill.ps1 | 새 파드 Ready 타임아웃 단언 제거 → 삭제/접근 경로 기능의 소유 블록 이동 |
| M13 | drill 이동 | g4-drill.ps1 | 남길 파드 Ready 가드 제거(양쪽 커넥터를 잃을 수 있다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M14 | drill 이동 | g4-drill.ps1 | 삭제 직전 값 해시 재확인 제거(정지점 사이 변경을 놓친다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M15 | drill 이동 | g4-drill.ps1 | 삭제 직전 UID 재확인 제거 → 삭제/접근 경로 기능의 소유 블록 이동 |
| M16 | drill 이동 | g4-drill.ps1 | 삭제 직전 남길 파드 재확인 제거 → 삭제/접근 경로 기능의 소유 블록 이동 |
| M17 | drill 이동 | g4-drill.ps1 | 드릴 대기 중 남은 파드 서명 불변 검사 제거 → 삭제/접근 경로 기능의 소유 블록 이동 |
| M18 | 사슬 제거/재구성 | g4-adopt.ps1 | nopods 실행에서도 파드를 삭제하도록(재실행 누적 삭제) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| M19 | 사슬 제거/재구성 | g4-adopt.ps1 | 인수 뒤 시작한 Ready 파드가 있어도 또 드릴(두 번째 삭제) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| M20 | drill 이동 | g4-drill.ps1 | 삭제 대상을 2개로(남은 커넥터까지 교체) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M21 | drill 이동 | g4-drill.ps1 | rollout restart 삽입(전면 재시작) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M22 | drill 이동 | g4-drill.ps1 | 조회 헬퍼로 삭제 우회($kq 에 delete 동사) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M23 | drill 이동 | g4-drill.ps1 | 드릴 대상 선정을 이름 순으로 되돌림(옛 커넥터를 지울 수 있다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M24 | drill 이동 | g4-drill.ps1 | 대상·생존 뒤바꿈(가장 이른 파드를 지운다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M25 | drill 이동 | g4-drill.ps1 | 드릴 정지점 제거(사람 승인 없이 삭제) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M26 | 유지 | g4-adopt.ps1 | 0) break-glass 정지점 제거 → 동일 결함/동일 블록 |
| M27 | 유지 | g4-adopt.ps1 | 정지점 단어 비교를 Ordinal → -eq(대소문자 무시) → 동일 결함/동일 블록 |
| M28 | 사슬 제거/재구성 | g4-adopt.ps1 | resume 파드 서명의 빈 입력 거부 제거(빈 Enter 로 게이트 포기) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| M29 | 유지 | g4-adopt.ps1 | 창 A boot_id 대조 제거(열린 세션을 확인하지 않는다) → 동일 결함/동일 블록 |
| M30 | 유지 | g4-adopt.ps1 | 1P) PM 토큰 해시 검사 제거 → 동일 결함/동일 블록 |
| M31 | 유지 | g4-adopt.ps1 | 인수 전 값을 화면에 출력 → 동일 결함/동일 블록 |
| M32 | 유지 | g4-adopt.ps1 | 해시 대신 평문을 기준값으로 보관(해시 비교 제거) → 동일 결함/동일 블록 |
| M33 | 유지 | g4-adopt.ps1 | 1P) 토큰을 -AsSecureString 없이 평문으로 읽는다 → 동일 결함/동일 블록 |
| M34 | 유지 | g4-restore.ps1 | 복구 토큰을 -AsSecureString 없이 평문으로 읽는다 → 동일 결함/동일 블록 |
| M35 | 유지 | g4-adopt.ps1 | finally 의 정리(Remove-Variable) 제거 → 동일 결함/동일 블록 |
| M36 | 유지 | g4-adopt.ps1 | 조회 3회 실패를 빈 값으로 통과시킨다(실패를 없음으로 읽는다) → 동일 결함/동일 블록 |
| M37 | 유지 | g4-adopt.ps1 | 단일 GET 스냅샷의 managed 라벨 가드 제거(가짜 기준값) → 동일 결함/동일 블록 |
| M38 | 유지 | g4-adopt.ps1 | auth can-i 의 허용 종료 코드 제거(no 를 조회 실패로 읽는다) → 동일 결함/동일 블록 |
| M39 | drill 이동 | g4-drill.ps1 | 드릴 대기 조회 실패를 즉시 throw(검증만 잃고 재실행을 부른다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M40 | 유지 | g4-adopt.ps1 | 라벨 셀렉터 제거(무관한 파드를 커넥터로 센다) → 동일 결함/동일 블록 |
| M41 | 유지 | g4-adopt.ps1 | oci 읽기 전용 프로파일 검사 제거 → 동일 결함/동일 블록 |
| M42 | drill 이동 | g4-drill.ps1 | 변경 로그를 삭제 요청 뒤로(중단 시 "변경 0건" 거짓말) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M43 | drill 이동 | g4-drill.ps1 | 삭제를 블로킹 대기로 되돌림(--wait=false 제거) → 삭제/접근 경로 기능의 소유 블록 이동 |
| M44 | 유지 | g4-adopt.ps1 | 조회 실패 문면을 "파드는 건드리지 않았다"로 고정(거짓 문장) → 동일 결함/동일 블록 |
| M45 | 앵커 갱신 | g4-adopt.ps1 | 판정하지 않은 항목도 합격 문면에 넣는다(resume·nopods 인데 "파드 불변") → 동일 결함/동일 블록 |
| M45b | 사슬 제거/재구성 | g4-adopt.ps1 | 판정하지 않은 항목도 합격 문면에(이전 드릴 결과인데 "파드 불변") → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| M46 | 유지 | g4-adopt.ps1 | 머지 입력 뒤 미판정 중단 경고 제거 → 동일 결함/동일 블록 |
| M47 | 유지 | g4-restore.ps1 | PM 토큰 해시 게이트 제거(틀린 값을 자기 손으로 쓴다) → 동일 결함/동일 블록 |
| M48 | 유지 | g4-restore.ps1 | 토큰 형식(ASCII 인쇄 문자) 검사 제거 → 동일 결함/동일 블록 |
| M49 | 유지 | g4-restore.ps1 | 클립보드 기록 검사 제거 → 동일 결함/동일 블록 |
| M50 | 유지 | g4-restore.ps1 | apply 회계를 호출 뒤로(쓰기 시도를 숨긴다) → 동일 결함/동일 블록 |
| M51 | 유지 | g4-restore.ps1 | Git 선언(selfHeal) 검사 제거 — ES 부재를 "개입 멈춤"으로 읽는다 → 동일 결함/동일 블록 |
| M52 | 유지 | g4-restore.ps1 | 모호한 apply 실패를 "아무것도 쓰지 않았다"로 단정 → 동일 결함/동일 블록 |
| M53 | 유지 | g4-restore.ps1 | 토큰 검사를 -cnotmatch 로 되돌림($Matches 에 평문 잔류) → 동일 결함/동일 블록 |
| A01 | 유지 | g4-adopt.ps1 | 3) 인수 판정의 값 변경 감지를 경고로 강등(덮인 채 드릴까지 진행) → 동일 결함/동일 블록 |
| A02 | drill 이동 | g4-drill.ps1 | 삭제 직전 값 재확인 실패를 경고로 강등(값이 덮인 채 파드 삭제) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A03 | 유지 | g4-adopt.ps1 | 2) 감시 루프의 값 해시 검사 제거(대기 중 감시 없음) → 동일 결함/동일 블록 |
| A04 | 유지 | g4-adopt.ps1 | 2) 감시 루프의 UID 검사 제거 → 동일 결함/동일 블록 |
| A05 | 유지 | g4-adopt.ps1 | 폴링 타임아웃을 PASS 로 처리 → 동일 결함/동일 블록 |
| A06 | 유지 | g4-adopt.ps1 | SecretSynced 비교를 StartsWith 로 느슨하게(SecretSyncedError 도 통과) → 동일 결함/동일 블록 |
| A07 | 유지 | g4-adopt.ps1 | ES SecretSyncedError 고착을 경고로 강등 → 동일 결함/동일 블록 |
| A08 | drill 이동 | g4-drill.ps1 | 남길 파드 Ready 가드가 삭제 대상 쪽을 본다(엉뚱한 파드 확인) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A09 | drill 이동 | g4-drill.ps1 | 새 파드 Ready 조건 제거(뜨기만 하면 OK) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A10a | drill 이동 | g4-drill.ps1 | 삭제 셀렉터를 --all 로 넓힘(이름 없음) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A10b | drill 이동 | g4-drill.ps1 | 삭제 셀렉터를 -l app=cloudflared 로 넓힘 → 삭제/접근 경로 기능의 소유 블록 이동 |
| A11 | drill 이동 | g4-drill.ps1 | 삭제 인자에 이름 2개(대상 + 남길 파드) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A12 | drill 이동 | g4-drill.ps1 | 로그 헬퍼($klog) 안에 scale --replicas=0 삽입(헬퍼 안 kubectl 이라 lint 통과?) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A13 | drill 이동 | g4-drill.ps1 | ssh 원격 명령으로 전면 재시작(kubectl 밖 변경 경로) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A13b | 유지 | g4-adopt.ps1 | oci 를 읽기 조회가 아닌 NSG 변경 호출로 바꾼다(kubectl 밖 변경 경로) → 동일 결함/동일 블록 |
| A14 | 유지 | g4-adopt.ps1 | 파드 서명에서 restartCount 제외(in-place 재시작을 못 본다) → 동일 결함/동일 블록 |
| A15 | 유지 | g4-adopt.ps1 | resume: 운영자 입력 preHash 를 라이브 값 해시로 덮어씀(가짜 PASS) → 동일 결함/동일 블록 |
| A20 | 사슬 제거/재구성 | g4-adopt.ps1 | 4) nopods 분기를 항상 타게 만든다(드릴 불가 · M18 의 반대 방향으로 같은 줄을 고정) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| A22 | 유지 | g4-adopt.ps1 | 파드 불변 실패를 경고로 강등 → 동일 결함/동일 블록 |
| A30 | drill 이동 | g4-drill.ps1 | 5) 노드 Ready 2 실패를 경고로 강등 → 삭제/접근 경로 기능의 소유 블록 이동 |
| A16 | 유지 | g4-adopt.ps1 | $stop 의 입력 버퍼 비움 제거(안전 규칙 1) → 동일 결함/동일 블록 |
| A17 | 유지 | g4-adopt.ps1 | $kq 의 --request-timeout 제거(터널이 멎으면 무한 대기) → 동일 결함/동일 블록 |
| A18 | 유지 | g4-adopt.ps1 | 0) 클러스터 정체 확인 제거 → 동일 결함/동일 블록 |
| A19 | 유지 | g4-adopt.ps1 | 1) 머지 전 파드 Ready 확인 제거 → 동일 결함/동일 블록 |
| A26 | 유지 | g4-adopt.ps1 | 폴링의 ES 출현 조회 실패(exit 1)를 "아직 없음"으로 읽는다(fail-open) → 동일 결함/동일 블록 |
| A26b | 유지 | g4-adopt.ps1 | resume 의 ES 존재 확인 실패를 "ES 없음(인수 해제 상태)"으로 읽는다(fail-open · 2라운드에서 발견) → 동일 결함/동일 블록 |
| A28 | 유지 | g4-adopt.ps1 | 1P) 비밀 입력 직후 클립보드 비움 제거(finally 의 1회만 남는다) → 동일 결함/동일 블록 |
| A31 | 유지 | g4-adopt.ps1 | finally 안의 요약 머리줄을 성공 스트림 출력으로(규칙 5 위반) → 동일 결함/동일 블록 |
| A32 | 유지 | g4-adopt.ps1 | finally 의 정리를 출력 뒤로(규칙 5: 정리 먼저) → 동일 결함/동일 블록 |
| A33 | 유지 | g4-adopt.ps1 | $ErrorActionPreference = Stop 제거(비종료 오류가 다음 문으로 흘러간다) → 동일 결함/동일 블록 |
| A34 | 유지 | g4-adopt.ps1 | $PSNativeCommandUseErrorActionPreference 끄기 제거 → 동일 결함/동일 블록 |
| A37 | drill 이동 | g4-drill.ps1 | 삭제 헬퍼에 --force --grace-period=0 추가(필수 플래그 lint 는 금지 플래그를 보지 않는다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| A38 | 유지 | g4-adopt.ps1 | 인수 전 값의 앞 16자만 화면에 출력(부분 누출) → 동일 결함/동일 블록 |
| B01 | 유지 | g4-restore.ps1 | (복구) 쓰기 뒤 값 되읽기 판정 제거 → 동일 결함/동일 블록 |
| B02 | 유지 | g4-restore.ps1 | (복구) 쓰기 뒤 UID 불변 판정 제거 → 동일 결함/동일 블록 |
| B03 | 유지 | g4-restore.ps1 | (복구) --force-conflicts 제거(ESO field manager 와 충돌하면 비상 복구가 실패) → 동일 결함/동일 블록 |
| B04 | 유지 | g4-restore.ps1 | (복구) 해시 게이트가 preHash 를 자기 자신과 비교 → 동일 결함/동일 블록 |
| B05 | 유지 | g4-restore.ps1 | (복구) ES 가 살아 있어도 단어가 restore → 동일 결함/동일 블록 |
| B06 | 유지 | g4-restore.ps1 | (복구) 페이로드를 argv 로도 넘긴다 → 동일 결함/동일 블록 |
| B09 | 유지 | g4-restore.ps1 | (복구) UID 변경 정지점 제거 → 동일 결함/동일 블록 |
| B11 | 유지 | g4-restore.ps1 | (복구) 비밀 입력 직후 클립보드 비움 제거(finally 에만 남는다) → 동일 결함/동일 블록 |
| N01 | drill 이동 | g4-drill.ps1 | 4) 의 noGlass 삭제 거부 제거(확인된 복구 경로 0 인데 파드를 지운다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| N02 | 유지 | g4-adopt.ps1 | 둘 다 실패인데 단어를 no-oci 로 되돌림(문면과 단어가 갈리지 않는다) → 동일 결함/동일 블록 |
| N03 | 유지 | g4-adopt.ps1 | noGlass 판정을 항상 거짓으로(둘 다 실패해도 평소 경로) → 동일 결함/동일 블록 |
| N04 | 유지 | g4-adopt.ps1 | noGlass 정지점 문면을 평소 문면으로(삭제 거부를 알리지 않는다) → 동일 결함/동일 블록 |
| N05 | 사슬 제거/재구성 | g4-adopt.ps1 | noGlass SKIP 의 단계 기록을 "완료"로(런북에 거짓 기록) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| N06 | 사슬 제거/재구성 | g4-adopt.ps1 | 이전 드릴 판정에서 "ES 생성 뒤 시작" 조건 제거(진짜 교체도 드릴 결과로 읽는다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| N07 | 사슬 제거/재구성 | g4-adopt.ps1 | 이전 드릴 판정에서 새 파드 Ready 조건 제거(NotReady 커넥터를 증명으로 읽는다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| N08 | 사슬 제거/재구성 | g4-adopt.ps1 | 이전 드릴 판정 조건을 fresh 하나로 축소(파드 수·kept 검사 제거) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| N09 | drill 이동 | g4-drill.ps1 | ES 생성 시각 기준을 epoch 로(모든 새 파드가 "드릴 결과") → 동일 결함/동일 블록 |
| N10 | 사슬 제거/재구성 | g4-adopt.ps1 | 4) 의 이전 드릴 SKIP 분기 제거(드릴을 한 번 더 한다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| N11 | 사슬 제거/재구성 | g4-adopt.ps1 | drilled: SKIP 에서 드릴 후 서명 기록 제거(다음 실행의 1R 입력이 사라진다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| N11b | 사슬 제거/재구성 | g4-adopt.ps1 | 이전 드릴 SKIP 에서 드릴 후 서명 기록 제거(같은 결함의 두 번째 갈래) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| N12 | drill 이동 | g4-drill.ps1 | 드릴 정지점 분기의 키 집합 조회 실패를 "정상"으로 읽는다(fail-open) → 동일 결함/동일 블록 |
| N13 | 유지 | g4-adopt.ps1 | 폴링 분기의 키 집합을 항상 정상으로 고정(매핑 오류를 kv 오류로 오도) → 동일 결함/동일 블록 |
| N14 | 유지 | g4-adopt.ps1 | 복구 안내의 "조회 실패" 분기를 항상 타게(정상 키를 미확인으로 오도) → 동일 결함/동일 블록 |
| N15 | 유지 | g4-adopt.ps1 | 복구 안내에서 키 집합 줄 자체를 제거(감별 근거 소실) → 동일 결함/동일 블록 |
| N16 | 유지 | g4-adopt.ps1 | 키 목록 조회를 키가 아니라 **값**으로(복구 안내에 토큰이 찍힌다) → 동일 결함/동일 블록 |
| N17 | 유지 | g4-restore.ps1 | (복구) Argo 조회 성공 판정을 무조건 참으로(빈 응답을 "선언 없음"으로 읽는다) → 동일 결함/동일 블록 |
| N18 | 유지 | g4-restore.ps1 | (복구) Argo 조회 실패를 "선언 없음"으로 읽는다(catch 에서 argoOk=true) → 동일 결함/동일 블록 |
| N19 | 유지 | g4-restore.ps1 | (복구) 최선 노력을 되돌려 Argo 조회 실패가 복구를 막게 한다(B-3 회귀) → 동일 결함/동일 블록 |
| N20 | 유지 | g4-restore.ps1 | (복구) 양성 대조 행을 빈 문자열로(무엇이 와도 "조회가 됐다") → 동일 결함/동일 블록 |
| N21 | 유지 | g4-adopt.ps1 | 1R) pm 분기의 클립보드 기록 검사 제거 → 동일 결함/동일 블록 |
| N22 | 유지 | g4-adopt.ps1 | 1R) pm 분기가 토큰을 평문 Read-Host 로 받는다 → 동일 결함/동일 블록 |
| N23 | 유지 | g4-adopt.ps1 | 1R) pm 분기가 base64 없이 해시를 유도(기준값이 어긋난다) → 동일 결함/동일 블록 |
| N24 | 유지 | g4-adopt.ps1 | 1R) pm 분기의 "미검증 전제" 경고 제거 → 동일 결함/동일 블록 |
| N25 | 유지 | g4-restore.ps1 | (복구) 쓰기 성공을 곧 확인 성공으로(verified 를 apply 직후에 세운다) → 동일 결함/동일 블록 |
| P01 | 사슬 제거/재구성 | g4-adopt.ps1 | drilled: 접두어 인식 제거(운영자 선언이 무시된다 → 재인수에서 두 번째 삭제) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| P02 | 사슬 제거/재구성 | g4-adopt.ps1 | 4) 의 drilled: SKIP 분기 제거(3) 의 같은 조건과 구분하려고 줄 앵커를 쓴다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| P03 | second 경고 게이트 | g4-drill.ps1 | "인수 뒤 시작한 파드" 조건을 다시 Ready 로 좁힘(NotReady 드릴 파드가 있어도 또 지운다) → Ready 여부와 무관한 과거 드릴 흔적은 second 경고로 변경됨 |
| P04 | 사슬 제거/재구성 | g4-adopt.ps1 | 인수 뒤 시작한 NotReady 파드 SKIP 분기 제거 → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| P05 | 사슬 제거/재구성 | g4-adopt.ps1 | R2 뒤 재인수의 드릴 단어를 drill 로 되돌림(사람 확인이 사라진다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| P06 | 사슬 제거/재구성 | g4-adopt.ps1 | 기준값을 이어받은 실행·재인수의 드릴 정지점 문면을 평소 문면으로(이미 드릴했는지 묻지 않는다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| P07 | 사슬 제거/재구성 | g4-adopt.ps1 | SKIP 분기의 커넥터 Ready 경고 제거(한쪽이 NotReady 인데 OK 로 끝난다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| P08 | 유지 | g4-adopt.ps1 | 1P) 건너뛰기 제거(PM 유도 기준값을 같은 PM 값과 대조해 "검증했다"고 기록한다) → 동일 결함/동일 블록 |
| P09 | 유지 | g4-adopt.ps1 | PM 유도 표시($preFromPm) 자체를 세우지 않는다 → 동일 결함/동일 블록 |
| P10 | 앵커 갱신 | g4-adopt.ps1 | 복구 안내의 "기준값이 PM 유도다" 경고 제거(kv 를 낡은 PM 값으로 정정하게 만든다) → 동일 결함/동일 블록 |
| P11 | 유지 | g4-adopt.ps1 | 기준값 출력(화면)의 PM 유도 꼬리표 제거(런북에 "검증된 기준값"으로 남는다) → 동일 결함/동일 블록 |
| P11b | 유지 | g4-adopt.ps1 | 기준값 출력(요약)의 PM 유도 꼬리표 제거 — 같은 결함의 두 번째 갈래 → 동일 결함/동일 블록 |
| P12 | 사슬 제거/재구성 | g4-adopt.ps1 | 요약의 drilled: 접두어 제거(다음 실행이 접두어 없이 붙여 넣게 된다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| P13 | 유지 | g4-adopt.ps1 | R3 조각에서 히스토리 끄기 제거(개행 섞인 붙여넣기의 나머지가 히스토리로 간다) → 동일 결함/동일 블록 |
| P14 | 유지 | g4-adopt.ps1 | R3 조각에서 붙여넣기 형식·길이 검사 제거(빈 값·잘린 값을 그대로 쓴다) → 동일 결함/동일 블록 |
| P15 | 유지 | g4-adopt.ps1 | R3 조각에서 쓰기 뒤 해시 되읽기 제거(잠긴 상태에서 확인 수단이 없어진다) → 동일 결함/동일 블록 |
| P16 | 유지 | g4-adopt.ps1 | R3 ② 의 finalizer·webhook 단서 제거(delete 가 멎는 이유를 알 수 없다) → 동일 결함/동일 블록 |
| P17 | 유지 | g4-adopt.ps1 | 0b 의 전제(클립보드·kubeconfig·권한 하드 검사) 문구 제거 → 동일 결함/동일 블록 |
| V01 | 유지 | g4-adopt.ps1 | noGlass 를 -and 에서 -or 로(한쪽만 실패해도 삭제 거부 · 단어가 갈리지 않는다) → 동일 결함/동일 블록 |
| V02 | 유지 | g4-adopt.ps1 | ssh 만 실패한 실행의 단어를 go 로 되돌림(창 A 미대조를 사람에게 알리지 않는다) → 동일 결함/동일 블록 |
| V03 | 유지 | g4-adopt.ps1 | 창 A 대조의 boot_id 형식 검사 제거(ssh 가 무엇을 돌려주든 대조 상대로 삼는다) → 동일 결함/동일 블록 |
| V04 | 유지 | g4-adopt.ps1 | oci 프로브의 빈 응답 검사 제거(exit 0 + 빈 출력을 2차 break-glass 로 센다) → 동일 결함/동일 블록 |
| V05 | drill 이동 | g4-drill.ps1 | ES creationTimestamp 형식 검사 제거(형식이 다르면 시각 비교가 무의미해진다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| V06 | 사슬 제거/재구성 | g4-adopt.ps1 | noGlass 거부 분기가 드릴 후 서명을 무조건 기록한다(하지도 않은 드릴을 요약이 drilled: 로 인쇄) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| V07 | 유지 | g4-adopt.ps1 | 키 목록 조회를 fail-open 으로(조회 실패를 "키가 하나도 없다"로 읽어 매핑 오류로 오진) → 동일 결함/동일 블록 |
| V08 | 사슬 제거/재구성 | g4-adopt.ps1 | SKIP 분기의 Ready 경고를 화면에서 지운다(요약 줄만 남는다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| V09 | 유지 | g4-adopt.ps1 | PM 유도 실행의 1P 기록을 일반 skip-pm 으로(자기 자신 대조였다는 사실이 기록에서 사라진다) → 동일 결함/동일 블록 |
| V10 | 유지 | g4-restore.ps1 | (복구) Secret type 빈 응답 검사 제거(빈 type 을 그대로 apply 에 싣는다) → 동일 결함/동일 블록 |
| V11 | 유지 | g4-restore.ps1 | (복구) Git 선언 판정에서 requiresPruning=true 예외를 뺀다(정상 순서인데 temporary 로 막는다) → 동일 결함/동일 블록 |
| V12 | 유지 | g4-restore.ps1 | (복구) 조회 성공 판정을 "응답이 비어 있지 않다"로(양성 대조 행을 보지 않는다) → 동일 결함/동일 블록 |
| V13 | 유지 | g4-adopt.ps1 | 파드 행 형식 검사 제거(jsonpath 형식이 달라지면 오판으로 진행한다) → 동일 결함/동일 블록 |
| V14 | 유지 | g4-adopt.ps1 | 빈 파드 목록 검사 제거(빈 응답을 "파드 없음"으로 읽는다) → 동일 결함/동일 블록 |
| V15 | drill 이동 | g4-drill.ps1 | 0) 권한 확인에서 'delete pods' 를 뺀다(삭제 권한을 미리 확인하지 않는다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| V16 | drill 이동 | g4-drill.ps1 | 남길 파드의 기준 서명을 삭제 대상에서 뽑는다(드릴 대기 판정이 엉뚱한 파드를 본다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| V17 | 유지 | g4-adopt.ps1 | 폴링 진행 줄 제거(프롬프트가 약속한 "진행 줄이 보이면 머지" 신호가 사라진다) → 동일 결함/동일 블록 |
| V18 | 유지 | g4-restore.ps1 | (복구) 페이로드의 type 을 Opaque 로 하드코딩(실제 type 을 읽고도 쓰지 않는다) → 동일 결함/동일 블록 |
| V19 | 사슬 제거/재구성 | g4-adopt.ps1 | 드릴 후 서명 줄을 언제나 인쇄(드릴하지 않은 실행도 drilled: 를 준다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| V20 | 유지 | g4-adopt.ps1 | 2) 단계 기록을 폴링 전에 남기지 않는다(폴링 중 중단하면 요약이 "미실행"이라고 말한다) → 동일 결함/동일 블록 |
| V21 | 사슬 제거/재구성 | g4-adopt.ps1 | "인수 뒤 시작" 필터를 건너뛰고 Ready 파드만 보면 SKIP(드릴이 영영 일어나지 않는다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| V22 | drill 이동 | g4-drill.ps1 | 드릴 대상 정렬 제거(목록 순서가 startTime 순서를 대신한다) → 삭제/접근 경로 기능의 소유 블록 이동 |
| R4-01 | 유지 | g4-adopt.ps1 | R3 조각의 case 패턴을 히스토리 확장에 걸리는 `!!` 로 되돌림(정상 토큰도 늘 BROKEN-PASTE) → 동일 결함/동일 블록 |
| R4-02 | 유지 | g4-adopt.ps1 | R3 조각을 "첫 줄부터 실행한다"는 지시 제거(중간부터 재시도 → 히스토리 확장 덫) → 동일 결함/동일 블록 |
| R4-03 | 유지 | g4-adopt.ps1 | R3 의 갈래 판정을 옛 거짓 문면으로 되돌림("해시가 다르면 아무것도 쓰지 않은 것") → 동일 결함/동일 블록 |
| R4-04 | 유지 | g4-adopt.ps1 | R3 의 화면 에코 경고 제거(스크롤백에 남은 토큰을 알리지 않는다) → 동일 결함/동일 블록 |
| R4-05 | 유지 | g4-adopt.ps1 | R3 ④ 의 자리표시자를 붙여 넣으면 bash 문법 오류가 나는 표기로 되돌림 → 동일 결함/동일 블록 |
| R4-06 | 사슬 제거/재구성 | g4-adopt.ps1 | 가드 ⓓ 제거(라벨이 지워진 재인수가 사람 확인 없이 정상 캡처 경로로 들어온다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R4-07 | 사슬 제거/재구성 | g4-adopt.ps1 | 1D) 의 잘못된 답을 first 로 처리(빈 Enter·오타가 드릴을 여는 쪽으로 간다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R4-08 | 사슬 제거/재구성 | g4-adopt.ps1 | 1D) 의 재인수 표시를 4) 단어에 반영하지 않는다(first-drill 로 갈리지 않는다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R4-09 | 유지 | g4-adopt.ps1 | 스냅샷 jsonpath 에서 data-hash 필드 제거(가드 ⓓ 의 근거가 사라진다) → 동일 결함/동일 블록 |
| R4-10 | 사슬 제거/재구성 | g4-adopt.ps1 | $already SKIP 분기의 반대쪽 Ready 판정 제거(이중화 미성립이 조용히 넘어간다) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R4-10b | 사슬 제거/재구성 | g4-adopt.ps1 | $after SKIP 분기의 반대쪽 Ready 판정 제거(같은 결함의 두 번째 갈래) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R4-11 | 사슬 제거/재구성 | g4-adopt.ps1 | 요약의 쌍둥이 줄 차단 제거(접두어 없는 기준값 파드서명을 그대로 다시 인쇄) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R4-12 | drill 이동 | g4-drill.ps1 | 4) 정지점의 break-glass 재확인 문면 제거(0) 이후 창 A 가 끊겨도 묻지 않는다) → 동일 결함/동일 블록 |
| R4-13 | 유지 | g4-adopt.ps1 | UID 안내에서 현재 UID 줄 제거(새 UID 를 찾을 방법을 주지 않는다) → 동일 결함/동일 블록 |
| R4-14 | 유지 | g4-adopt.ps1 | UID 안내용 $uidNow 를 3) 판정에서 세우지 않는다 → 동일 결함/동일 블록 |
| R4-14b | 유지 | g4-adopt.ps1 | UID 안내용 $uidNow 를 2) 감시 루프에서 세우지 않는다(같은 결함의 두 번째 갈래) → 동일 결함/동일 블록 |
| R4-14c | drill 이동 | g4-drill.ps1 | UID 안내용 $uidNow 를 삭제 직전 재확인에서 세우지 않는다(세 번째 갈래) → 삭제/접근 경로 기능의 소유 블록 이동 |
| R4-15 | 유지 | g4-adopt.ps1 | 라벨 삭제 안내에서 data-hash 경고 제거(지우면 잠금이 모두 풀린다는 사실을 숨긴다) → 동일 결함/동일 블록 |
| R5-01 | 사슬 제거/재구성 | g4-adopt.ps1 | 드릴 단어 게이트를 4R 의 일시적 사실($esGone)로 되돌림(먼저 머지한 재인수에서 게이트가 사라진다 · B4-01) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-02 | 사슬 제거/재구성 | g4-adopt.ps1 | 드릴 단어 게이트에서 resume 을 통째로 뺀다(1R 로 이어 온 실행이 drill 하나로 지운다 · B4-01) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-03 | 사슬 제거/재구성 | g4-adopt.ps1 | 요약의 쌍둥이 **값** 억제 분기 제거(접두어 없는 같은 값이 파드서명 줄로 다시 나간다 · B4-03) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-04 | 유지 | g4-adopt.ps1 | R3 의 (0) apply 실패 갈래 제거(쓰기 0건인 실패를 "이미 썼을 수 있다"로 읽게 된다 · A4-1) → 동일 결함/동일 블록 |
| R5-05 | 유지 | g4-adopt.ps1 | R3 의 (0) 에서 라이브 type 읽기 명령 제거(잠긴 운영자가 원인을 고칠 수단을 잃는다 · A4-1) → 동일 결함/동일 블록 |
| R5-06 | 유지 | g4-adopt.ps1 | R3 의 (3) 에서 "apply 줄의 오류는 (0) 이다" 구분 제거(두 갈래가 다시 섞인다 · A4-1) → 동일 결함/동일 블록 |
| R5-07 | 유지 | g4-adopt.ps1 | R3 조각에서 case 앞의 unset B 제거(앞선 시도의 B 가 남아 BROKEN-PASTE 인데도 틀린 값을 쓴다 · A4-2) → 동일 결함/동일 블록 |
| R5-07b | 유지 | g4-adopt.ps1 | R3 조각에서 apply 뒤의 unset B 제거(같은 줄의 두 번째 갈래 · A4-2) → 동일 결함/동일 블록 |
| R5-08 | 유지 | g4-adopt.ps1 | R3 조각에서 unset T 제거(평문 토큰이 노드 셸 변수에 남는다 · A4-2) → 동일 결함/동일 블록 |
| R5-09 | 사슬 제거/재구성 | g4-adopt.ps1 | noGlass 거부 분기의 반대쪽 Ready 판정 제거(확인된 복구 경로 0 인 실행이 "OK"로 끝난다 · A4-3) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-09b | 사슬 제거/재구성 | g4-adopt.ps1 | drilled: SKIP 분기의 반대쪽 Ready 판정 제거(A4-3) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-09c | 사슬 제거/재구성 | g4-adopt.ps1 | 이전 드릴 SKIP 분기의 반대쪽 Ready 판정 제거(A4-3) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-09d | 사슬 제거/재구성 | g4-adopt.ps1 | nopods SKIP 분기의 반대쪽 Ready 판정 제거(A4-3) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-10 | 사슬 제거/재구성 | g4-adopt.ps1 | 요약의 기준값 파드서명 줄에서 "어느 줄을 넣어라" 단서만 뗀다(이름은 그대로 · A4-4) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-11 | 사슬 제거/재구성 | g4-adopt.ps1 | 요약의 기준값 파드서명 줄을 통째로 제거(운영자가 이 실행의 입력을 되짚을 수 없다 · A4-4) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-11b | 사슬 제거/재구성 | g4-adopt.ps1 | 요약의 접두어 없는 기준값 파드서명 줄만 제거(같은 결함의 두 번째 갈래 · A4-4) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-12 | 사슬 제거/재구성 | g4-adopt.ps1 | 화면의 "이미 드릴했다고 선언됐다" 단서 제거(그 실행이 삭제 0 이라는 사실이 화면에서 사라진다 · A4-4) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-13 | 사슬 제거/재구성 | g4-adopt.ps1 | 1D) 오답 안내에서 "모르겠으면 drilled" 제거(안전한 쪽을 알려 주지 않는다 · A4-4) → 이전 드릴 상태 사슬 폐기. 같은 실패 계열의 adopt 경로에 실제 변경 호출을 주입해 AST·모의·공통 쓰기 0으로 차단 |
| R5-14 | 유지 | g4-adopt.ps1 | R3 의 case 줄 따옴표 근거 주석 제거(다음 편집자가 B3-01 을 되돌린다 · A4-4) → 동일 결함/동일 블록 |
| R5-15 | 유지 | g4-adopt.ps1 | B4-02 로 바로잡은 히스토리 확장 기전 설명 제거(다음 편집자가 "[ 뒤면 안전하다"를 믿는다) → 동일 결함/동일 블록 |
| R5-16 | 규약 이동 | g4-drill.ps1 | 1D) 의 단어 비교를 Ordinal → -eq(컬처 민감 · 안전 규칙 8) → 폐기한 1D 대신 독립 drill 정지점 Ordinal 규약 |
| R5-17 | 규약 이동 | g4-drill.ps1 | $nrWarn 의 Ready 비교를 Ordinal → -ne(컬처 민감 · 안전 규칙 8) → 폐기한 nrWarn 대신 삭제 직전 양쪽 Ready Ordinal 규약 |

## 5라운드 지적별 처리

| ID | 처리와 증거 |
|---|---|
| A5-1 | adopt에서 이전 드릴 선언·삭제 자체 제거. 중단한 resume G4-53도 쓰기 0. |
| A5-2 | 체인 대입 다섯 분기 제거. 이전 분기의 변이는 ID별 쓰기 금지로 재구성. |
| A5-3 | R3 9개 실행 줄 전문·순서 Ordinal 대조. base64 -w0, 길이 32, force-conflicts, 수동 1개 삭제 변이 추가. |
| A5-4 | drill 직후 창 A 재확인 경고를 D-01 및 A5-23 변이로 고정. |
| A5-5 | EofAfter가 실제 null 반환. G4-EOF1/2/3과 비밀 빈 입력 G4-EMPTY, drill EOF D-21. |
| A5-6 | 접두어·쌍둥이 서명 사슬 자체를 제거하여 자동 해소. 새로운 hash/UID 인계는 삭제권한이 아니며 drill이 현재 값을 다시 대조. |
| A5-7 | kq 런타임 허용 조건 AST와 auth namespace 검사 추가. 과거 선언/접두어 문구는 제거. |
| A5-8 | 사람 확인 두 개면 모든 경로를 막는다는 허위 단언 제거. 실행 횟수 전체의 멱등 삭제를 주장하지 않음. |
| A5-9 | 과거 실측은 NOTES 담당 컨트롤러가 출처와 함께 정리. 이번 실행 증거와 라이브 미확인을 분리. |
| B5-01 | 라벨/data-hash로 과거 드릴을 추론하는 잠금 제거. adopt는 항상 쓰기 0, drill은 독립 요청. |
| B5-02 | G4-54/55가 라벨+data-hash 모두 제거 및 라벨만 제거 재인수에서 변경 0을 검사. |
| B5-03 | restore 헤더에 data-hash 보존 및 정규 drill/ES 없는 비상 R3 구분. 폐기 접두어 경고는 새로 추가하지 않음. |
| B5-04 | 최신 startTime 대상 선정과 재시작 시 env 재판독을 drill 머리글에 명시. 옛 값 영구 유지 주장 제거. |
| B5-05 | 실제 R3 출력 9줄을 추출해 Git Bash --noprofile --norc -i, set -H에서 로컬 모의 실행. 정상 32자: MOCK-APPLY-OK, 짧음: TOO-SHORT/쓰기 없음, 공백 손상: BROKEN-PASTE/쓰기 없음. 모든 sudo/kubectl/ssh/oci는 셸 함수 모의이며 실제 외부 명령 금지. 최종 하네스 안에 보존했다. 임시 단독 실측과 별도로 R3-BASH-GOOD/SHORT/BROKEN 세 사례가 최종 122개 중 3개다. Git Bash가 없는 환경에서는 명시적으로 SKIP하며 그 환경의 동작을 이번 PASS로 주장하지 않는다. |

## 안전장치 이동 및 폐기 경계

- 단일 GET 캡처, PM 사전 대조/PM 유도 출처, ES 감시 중 hash·UID 변화, ownerRef/managed/data-hash/Argo 단일 소유 판정은 adopt 유지.
- boot_id·OCI 프로브·확인된 복구 경로, 삭제 요청의 단일 호출/정확 argv/회계 선행, 최신 startTime 선정, 삭제 직전 전제 재확인, 삭제 뒤 생존 파드 서명·Ready/새 파드 Ready/로그/접근 경로는 drill 담당.
- 접두어·nopods·first-drill·사전 서명·이전 드릴 결과 판정·체인 요약은 사용자 결정대로 제거. 그 장치가 보장하던 adopt 누적 삭제 0은 이제 실행별 구조적 읽기 전용으로 강해짐. drill을 반복 실행하는 위험은 첫 줄과 second 경고로 전달하며 실행 이력 잠금은 재도입하지 않음.
- restore는 Secret type 보존·PM hash·UID·ES/Git 개입·1회 apply/회계 선행·되읽기·재실행 SKIP 유지.
- 생존 파드의 옛 값은 컨테이너가 재시작되기 전까지만 유지. 조회 성공/소스 검사/모의 PASS는 라이브 연결 증명이 아님.

## 리뷰 1 발견 당시 기록 — 후속 수정 완료

컨트롤러가 drill JSONPath의 && 문법 미지원, 삭제 뒤 3개 파드 상태에서 완료 가능, 삭제 전 hash/UID 거부 시 안내 부재를 통보했다. 첫 220개 변이 실행은 수정 전 기준판으로 보존했고 후속 RED·수정·최종 검토로 전부 닫았다.

## 수정 round1 검증

기준판 변이: 220개 중 CAUGHT 204 / ESCAPED 16 / ANCHOR-ERR·NO-OP 0. 잠금 표식 125 중 CAUGHT 119. 이 결과는 결함 발견용이며 최종 통과가 아니다.

- R1-01: JSONPath &&를 모의에서 거부하게 하여 RED 83/114 확인. Ready status와 reason을 지원되는 단일 응답의 두 필드로 받고 Ordinal 비교하도록 수정 후 114/114.
- R1-02·03·05: 최초/삭제직전 hash·UID 인계, 조회 실패 키 진단, 기존 삭제 대상+새 파드 3개, 전제 요약 단언 RED 112/119 확인 후 119/119.
- R1-04: R3 ④ 전문 단언 추가. 기준판 A5-15 ESCAPED를 최종 변이에서 CAUGHT로 검증했다.
- 대화형 R3 실제 출력 9줄 AST 추출/전문 검증 후에만 bash -i 실행, 3개 로컬 모의(GOOD/SHORT/BROKEN) 하네스에 보존. 총 **122/122, lint 0**.
- restore 끝 출력도 재인수 PASS 뒤 정규 drill와 ES 없는 비상 수동 R3를 구별.
- M13/A08/M16은 기존 개별 가드와 새 통합 가드가 중복되어 제거 변이가 무효였다. 중복 개별 조건을 정리하고 양쪽 Ready 및 최후 전체 파드 서명·Ready 조건에 같은 의미로 이동했다.
- A19는 후단 Ready 오류로도 통과하던 약한 시험을 머지 프롬프트 미도달로 강화. D03도 초기 UID 거부가 이름 정지점 이전인지 검사. P11/P11b는 정상 PM resume의 출처 꼬리표 두 군데를 모두 세는 원래 단언을 복원. V17은 머지 전 폴링 진행 신호를 정상 경로에서 고정.

## 사슬 변이의 실제 대체 주입 위치

아래 41개는 폐기 구현에 대한 실패를 CAUGHT로 세지 않는다. 동일 ID로 구조적 읽기 전용 경계의 서로 다른 경로/동사 우회를 주입한다. 반복 검사는 41개 독립 취약점이라는 뜻이 아니다.

| ID | 주입 위치 | 실제 변경 명령 |
|---|---|---|
| M18 | `$resumed = $false` | `& kubectl '-n' $NS 'delete' 'pod' 'cloudflared-6d4f7c9b8-bb22b' / Out-Null` |
| M19 | `$resumed = $true` | `& kubectl '-n' $NS 'delete' 'pod' 'cloudflared-6d4f7c9b8-bb22b' / Out-Null` |
| M28 | `$judged = $true` | `& kubectl '-n' $NS 'delete' 'pod' 'cloudflared-6d4f7c9b8-bb22b' / Out-Null` |
| M45b | `$preUid = [string]$snap[0]` | `& kubectl '-n' $NS 'delete' 'pod' 'cloudflared-6d4f7c9b8-bb22b' / Out-Null` |
| A20 | `Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).'` | `& kubectl '-n' $NS 'delete' 'pod' 'cloudflared-6d4f7c9b8-bb22b' / Out-Null` |
| N05 | `if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {` | `& kubectl '-n' $NS 'delete' 'pod' 'cloudflared-6d4f7c9b8-bb22b' / Out-Null` |
| N06 | `$resumed = $false` | `& kubectl '-n' $NS 'rollout' 'restart' 'deploy/cloudflared' / Out-Null` |
| N07 | `$resumed = $true` | `& kubectl '-n' $NS 'rollout' 'restart' 'deploy/cloudflared' / Out-Null` |
| N08 | `$judged = $true` | `& kubectl '-n' $NS 'rollout' 'restart' 'deploy/cloudflared' / Out-Null` |
| N10 | `$preUid = [string]$snap[0]` | `& kubectl '-n' $NS 'rollout' 'restart' 'deploy/cloudflared' / Out-Null` |
| N11 | `Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).'` | `& kubectl '-n' $NS 'rollout' 'restart' 'deploy/cloudflared' / Out-Null` |
| N11b | `if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {` | `& kubectl '-n' $NS 'rollout' 'restart' 'deploy/cloudflared' / Out-Null` |
| P01 | `$resumed = $false` | `& kubectl '-n' $NS 'scale' 'deploy/cloudflared' '--replicas=0' / Out-Null` |
| P02 | `$resumed = $true` | `& kubectl '-n' $NS 'scale' 'deploy/cloudflared' '--replicas=0' / Out-Null` |
| P04 | `$judged = $true` | `& kubectl '-n' $NS 'scale' 'deploy/cloudflared' '--replicas=0' / Out-Null` |
| P05 | `$preUid = [string]$snap[0]` | `& kubectl '-n' $NS 'scale' 'deploy/cloudflared' '--replicas=0' / Out-Null` |
| P06 | `Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).'` | `& kubectl '-n' $NS 'scale' 'deploy/cloudflared' '--replicas=0' / Out-Null` |
| P07 | `if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {` | `& kubectl '-n' $NS 'scale' 'deploy/cloudflared' '--replicas=0' / Out-Null` |
| P12 | `$resumed = $false` | `& kubectl '-n' $NS 'patch' 'secret' 'cloudflared-tunnel' '-p' '{}' / Out-Null` |
| V06 | `$resumed = $true` | `& kubectl '-n' $NS 'patch' 'secret' 'cloudflared-tunnel' '-p' '{}' / Out-Null` |
| V08 | `$judged = $true` | `& kubectl '-n' $NS 'patch' 'secret' 'cloudflared-tunnel' '-p' '{}' / Out-Null` |
| V19 | `$preUid = [string]$snap[0]` | `& kubectl '-n' $NS 'patch' 'secret' 'cloudflared-tunnel' '-p' '{}' / Out-Null` |
| V21 | `Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).'` | `& kubectl '-n' $NS 'patch' 'secret' 'cloudflared-tunnel' '-p' '{}' / Out-Null` |
| R4-06 | `if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {` | `& kubectl '-n' $NS 'patch' 'secret' 'cloudflared-tunnel' '-p' '{}' / Out-Null` |
| R4-07 | `$resumed = $false` | `& kubectl '-n' $NS 'label' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R4-08 | `$resumed = $true` | `& kubectl '-n' $NS 'label' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R4-10 | `$judged = $true` | `& kubectl '-n' $NS 'label' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R4-10b | `$preUid = [string]$snap[0]` | `& kubectl '-n' $NS 'label' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R4-11 | `Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).'` | `& kubectl '-n' $NS 'label' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-01 | `if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {` | `& kubectl '-n' $NS 'label' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-02 | `$resumed = $false` | `& kubectl '-n' $NS 'annotate' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-03 | `$resumed = $true` | `& kubectl '-n' $NS 'annotate' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-09 | `$judged = $true` | `& kubectl '-n' $NS 'annotate' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-09b | `$preUid = [string]$snap[0]` | `& kubectl '-n' $NS 'annotate' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-09c | `Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).'` | `& kubectl '-n' $NS 'annotate' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-09d | `if ($mergeAsked -and -not $judged -and [string]::IsNullOrWhiteSpace($recover)) {` | `& kubectl '-n' $NS 'annotate' 'secret' 'cloudflared-tunnel' 'unsafe=true' / Out-Null` |
| R5-10 | `$resumed = $false` | `& kubectl '-n' $NS 'replace' '-f' '-' / Out-Null` |
| R5-11 | `$resumed = $true` | `& kubectl '-n' $NS 'replace' '-f' '-' / Out-Null` |
| R5-11b | `$judged = $true` | `& kubectl '-n' $NS 'replace' '-f' '-' / Out-Null` |
| R5-12 | `$preUid = [string]$snap[0]` | `& kubectl '-n' $NS 'replace' '-f' '-' / Out-Null` |
| R5-13 | `Write-Host '이 실행이 클러스터에 가한 변경: 0 건(조회만 했다).'` | `& kubectl '-n' $NS 'replace' '-f' '-' / Out-Null` |

## 수정 round2 및 최종 검증 판본

- `g4-review2.md`의 유일 잔여(G4-R1-02 사후 완전 단절): D-16에 정적 R3 인계를 추가하여 **121/122 RED, lint 0** 확인. `%TEMP%/g4-review2-red.txt`.
- 변경 후 공통 안내는 API 접근 가능할 때 readonly adopt 판정, kubectl·SSH 차단일 때 adopt 파일을 실행하지 않고 R3를 읽는 두 갈래를 명시한다. **122/122 GREEN, lint 0**. `%TEMP%/g4-final-green.txt`.
- 추가 삭제가 없다는 조건은 D-16의 정확한 단일 DELETE argv와 모든 시나리오의 최대 요청 1 공통 조건으로 계속 검증한다.
- 최종 변이 `R2-02`는 사후 공통 R3 안내를 제거한다. `R1-03`은 전체2개·기존대상부재 완료 조건을 제거하고, `R1-05`는 전제 통과 요약을 제거하며, `D01`은 Ready 상태 검사 제거다. JSONPath `&&` 재등장은 모의 쿼리 거부로 잡힌다.
- A5-15 단독 재검증: **1/1 CAUGHT, ESCAPED 0, ANCHOR-ERR/NO-OP 0**, `%TEMP%/g4-a5-15.txt`.
- 최종 변이 runner는 하네스 자체를 실행별 임시 루트에 snapshot한다. `-KeepDirs`로 증거를 보존한 이번 전수 실행에서는 삭제를 수행하지 않는다. 정리 모드는 `Resolve-Path -LiteralPath`로 최종 절대경로를 검증하고 OS temp 하위와 `t045-g4-mut-` 이름을 함께 확인한 뒤 해당 디렉터리만 지운다.
- 중간에 시작했다가 리뷰/앵커 갱신으로 중단한 전수 실행 두 번은 수치에서 제외한다. 최종 증거는 동결된 수정 round2 본체와 하네스에서 실행한 `%TEMP%/g4-mutants-final.txt` 하나로 구분한다.

## 독립 검토와 범위별 증거

- 독립 검토3 `reviews/split-review3.md`: Spec compliance Approved / Task quality Approved, 잔여 0건. 검토1 다섯 항목 모두 Closed. 이 판정은 오프라인 코드/추출 모의 범위다.
- 컨트롤러 독립 하네스 로그 `reviews/split-harness.txt`: 122/122 PASS, lint 0. 구현자 로그 `%TEMP%/g4-final-green.txt`와 일치한다.
- 전체 저장소 검사는 컨트롤러가 맡았다. TF_VAR_budget_alert_email 미설정으로 infra 종속 단언 실패가 있다는 통보를 받았으며, 이 작업에서 운영 자격/환경을 추가하거나 live plan을 실행하지 않았다.

## 최종 검증 소스 지문

전수 동작 검증을 시작할 때 기록한 SHA-256이며 비밀 해시가 아니라 공개 소스 파일 해시다. 본체 3개와 하네스는 최종 감사 뒤에도 불변을 확인했다. mutants의 아래 해시는 전수 실행 판본이며, 이후 분류 보강 판본은 별도로 기록한다.

| 파일 | SHA-256 |
|---|---|
| g4-adopt.ps1 | `0BDE38C1249E74A399897007D3B208E0DFF918F8B42BAB26FA7355B9960CFE6A` |
| g4-drill.ps1 | `55E20D66694D5EF19525DE3A79E0B3F027E97A03D754E6B60DC96EE66F955150` |
| g4-restore.ps1 | `8418D72839789FE6ED8A3E8C66B2213E4ECF80E64AA7B834CEC433536FAABBF2` |
| harness-g4.ps1 | `2BDDA72A144B2A1D1191582E3BB23FFB7C5564E8169C196E538672AC0BA93ABC` |
| mutants-g4.ps1 | `73A56F7E6E947E45A3B2556EE0CFD47EEB21421C3A81A497A5BABF05174FCD63` |

## 최종 실패 근거 감사와 분류 보강

- 최종 전수 동작 결과는 223/223 CAUGHT, 잠금 표식 127/127 CAUGHT, ESCAPED 0, ANCHOR-ERR/NO-OP 0이다. 기존 41개 사슬 대체는 앞 표의 경로·동사 조합이며 41개의 독립 취약점으로 주장하지 않는다.
- 각 ID의 보존된 `harness.out.txt`를 감사했다. 실제 lint와 시나리오 실패가 함께 있는 경우 57개, lint만 12개, 시나리오만 154개로 **223개 모두 실제 실패 근거가 있다**. 근거 없는 프로세스 오류를 CAUGHT에 포함하지 않았다.
- 전수 실행 뒤 mutants의 결과 분류만 보강했다. `Get-MutantClassification`은 **exit 1 + 실제 LINT-FAIL 또는 시나리오 FAIL**일 때만 CAUGHT, exit 0은 ESCAPED, 나머지는 RUNNER-ERROR로 처리한다. R3-BASH와 R3-BASH-GOOD/SHORT/BROKEN 형식을 모두 포함한다. RUNNER-ERROR는 전체 실행 실패로 이어진다. 향후 실행은 `harness.exit.txt`에 원시 종료 코드도 저장한다.
- 함수 부재 RED를 관찰한 뒤, exit 1/실패 근거 없음, exit 2/실패 근거 있음, exit 0, 일반 시나리오 실패, lint 실패, bash 실패의 6개 대조를 통과했다. 실제 runner와 동일한 병렬 함수 전달 방식에서도 6/6 통과했다. 원본 동작 223개를 중복 실행하지 않았다.
- 보존된 223개 로그 모두 마지막의 완전한 FAIL 요약과 실제 실패 줄을 확인하고 같은 함수로 재평가했다: **CAUGHT 223, RUNNER-ERROR 0**. R3 출력 계약이 손상되면 실행 거부 1개 결과로 합쳐져 총 120개, 정상 조각은 총 122개로 끝나는 하네스 구조를 반영했다. 전수 실행 당시 원시 rc를 별도 저장하지 않았으므로, 종료 코드 1은 마지막 실패 요약과 동결 하네스의 exit 1 계약에서 추론한 것이다. 새로 rc를 수집했다고 주장하지 않는다.
- 분류 보강 판본 `mutants-g4.ps1` SHA-256: `551B2E25CBD1A09C36BDA36E2F250BDC5A99567EEDE7F3F1B2A79B3A5329D706`. 위 전수 실행 판본과 구별하며, 본체·하네스 네 파일 지문은 동일하다.
- 직접 시작한 최종 runner는 exit 0으로 종료했다. 마지막 프로세스 확인에서 이번 작업의 변이 runner·하네스·R3 bash 백그라운드 프로세스는 0개였다.

최종 공개 증거:

- [컨트롤러 독립 하네스 122/122](split-harness.txt)
- [변이 전수 223개 결과](split-mutants.txt)
- [223개 실제 실패 근거 및 재분류 요약](split-mutant-audit.json)
- [분류 함수 순차·병렬 대조](split-classifier.txt)
- [GitOps 부정 사례 44개](split-gitops-fixtures.txt)
- [독립 코드 검토 1](split-review1.md) · [검토 2](split-review2.md) · [최종 검토 3](split-review3.md)

ID별 실행 사본과 원본 로그는 작업 임시 디렉터리에 보관했다. 공개 감사 JSON은 로컬 경로와 중복 오류 전문을 제외하고 ID·실패 수·실패 사례 ID·완전한 종료 요약·재분류 출처를 보존한 사본이다.

기준 RED·중간 실패·중단된 전수 실행은 역사적 결함 발견 기록이며 위 최종 증거에 섞지 않는다. 이 결과는 오프라인 계약 검증으로 한정한다.

## 컨트롤러의 저장소 검증과 인계

- GitOps `bash tests/validate.sh`: PASS 24 / FAIL 0 / WARN 4 / SKIP 0. WARN은 기존 system-upgrade 이미지 digest 누락 항목이다.
- GitOps `VALIDATE_TESTS_REQUIRE_TOOLS=1 bash tests/validate.tests.sh`: 44개 사례, 실패 0. kustomize 5.8.1·kubeconform 0.8.0·yq 4.53.6·gitleaks 8.30.1을 준비해 실제 로컬 검증기를 실행했다.
- 모노레포 `pwsh -NoProfile -File tests/run-all.ps1`: exit 1, platform 슬롯 실패. `TF_VAR_budget_alert_email` 미설정으로 OpenTofu plan 결과를 얻지 못한 것이 원인이며 다른 슬롯은 통과했다. 이 환경 제약은 G5 확인 항목으로 남긴다.
- 세 운영자 블록의 CR·TAB은 모두 0, 마지막 3바이트는 모두 `0A 7D 0A`다. Git의 해당 파일 eol 속성도 `lf`다.
- 공개 산출물은 비밀 검사와 `git diff --check`를 거쳤다. 운영 API·SSH·Vault 로그인·개인 kubeconfig 사용은 없었다. 운영자 블록 실행은 전부 모의 함수 아래에서만 이뤄졌다.
- GitOps 변경은 README 3곳뿐이다. 매니페스트와 동결된 spec/plan/tasks는 변경하지 않았다. PR #29의 머지와 라이브 인수·별도 드릴은 사용자 입회에 남긴다. 아직 T045를 체크하지 않았고 50/119다.
