# T045 G4 분리 독립 task review 1

검토일: 2026-09-22. 검토 기준: `.superpowers/sdd/tasks/g4-review1.diff`의 bc229cc 대비 본체·하네스 변경 및 신설 drill. 본체 동결 시점의 검토이며 진행 중인 mutants 전수 결과는 판정에 포함하지 않았다.

- **Spec compliance: Issues.** adopt 쓰기 0·단일 drill 분리 방향은 확정 설계와 맞지만 실제 drill 정상 경로를 막는 JSONPath 문법 오류, 분리 과정에서 끊긴 실패 복구 안내, 삭제 후 완료 판정 누락이 있다.
- **Task quality: Issues.** 기본 안전 구조는 보존됐으나 하네스의 문법 비검증이 실제 결함을 숨겼고, 최신 A5-3의 1파드 제한 회귀 검증은 아직 비어 있다. 현재 report의 114/114·lint 0은 구현자 증거이며 이 검토가 재실행한 결과가 아니다.

## 중요 findings

### G4-R1-01 — P1 / high: ES Ready 조회가 kubectl JSONPath에서 파싱되지 않는다

- 현재 위치: `specs/003-platform-foundation/design/t045-blocks/g4/g4-drill.ps1:182`.
- 실제 식은 `jsonpath={.status.conditions[?(@.type=="Ready" && @.status=="True")].reason}`이다. kubectl의 JSONPath 필터는 이 `&&` 논리 결합을 지원하지 않는다. 따라서 정상 ES에서도 조회가 문법 오류로 종료하고 `$kq`가 3회 재시도한 뒤 중단한다. 삭제 0으로 안전하게 멈추지만 승인된 독립 drill을 실제로 수행할 수 없다.
- 근거: 공식 [client-go JSONPath parser](https://raw.githubusercontent.com/kubernetes/client-go/master/util/jsonpath/parser.go)의 `parseFilter`는 단일 비교의 좌·우로 나누어 우측을 다시 `parseAction`에 전달한다(321–376). 이 식의 우측 `"Ready" && @.status=="True"`는 `parseInsideAction`의 허용 rune 밖인 `&`에서 오류가 된다(148–168). 공식 소스를 읽었으며 실제 kubectl이나 클러스터는 실행하지 않았다.
- 하네스가 놓친 이유: `harness-g4.ps1:278`의 conditions 모의는 JSONPath를 파싱하지 않고 문자열에 `@.status=="True"`가 있는지만 확인한다. 따라서 D-01과 D-22 모두 잘못된 문법을 정상인 것처럼 사용한다.
- 수정 방향: `Ready` 행의 status와 reason을 한 응답으로 받아 PowerShell에서 둘 다 Ordinal 비교하거나, JSON 전체를 받아 해당 조건 객체를 검사한다. 이 정확한 JSONPath에 대한 오프라인 parser 검사 또는 지원하는 문법을 고정한 검사를 추가한다. 실물 운영 호출을 할 필요는 없다.

### G4-R1-02 — P2 / medium: 삭제 전 값·UID 오류가 존재하지 않는 복구 안내를 가리킨다

- 현재 위치: `specs/003-platform-foundation/design/t045-blocks/g4/g4-drill.ps1:221`, `:226`, `:290`.
- 재현 조건: ES·hash·UID·2 Ready 파드를 먼저 통과한 뒤 이름/단어 정지점 동안 값 또는 UID가 변경된다. 기존 D-18/D-19가 만드는 바로 그 상태다.
- 해당 분기는 `$recover='value'/'uid'`, `$uidNow`, `$keysNow` 등을 세우고 “아래 복구 안내/아래 안내”를 지시한다. 그러나 drill의 finally는 `$recover`를 한 번도 읽지 않으며, 유일한 R1/R2/R3 연결 안내는 `$changes.Count -gt 0` 안에 있다. 이 거부는 삭제 전이라 0건이므로 그 안내조차 나오지 않는다. 첫 hash/UID 비교 거부(`:188`, `:190`)에도 명시적인 복구 인계가 없다.
- 기존 adopt에서 제공하던 UID만 변경이면 값 복구 금지·새 UID 조사, 값 변경이면 R1/R2/R3 및 컨테이너 재시작 노출 경고가 독립 drill의 이 경로에서 유실됐다. 남은 컨테이너의 자발적 재시작 가능성이 있으므로 “삭제하지 않았음”만으로 복구 지연이 안전하지 않다.
- 로컬 AST 확인: finally의 `recover` 변수 참조 **0**, 복구 안내 조건은 **`$changes.Count -gt 0` 하나**다. 원본 블록 실행 없이 diff에서 추출한 AST로 확인했다.
- 수정 방향: 삭제 여부와 무관하게 값·UID 실패의 후속 경로를 출력한다. UID만 다르면 kv/Secret 값을 덮지 말라는 안내와 새 UID를 보존하고, 값 오류에는 R1/R2/R3의 접근 가능한 위치를 명시한다. 완전 잠금에서는 adopt를 실행해 안내를 얻을 수 없으므로 정적 파일의 R3 절을 읽는 경로도 분명히 한다. D-18/D-19는 throw뿐 아니라 이 인계도 검사한다.

### G4-R1-03 — P2 / medium: 기존 삭제 대상이 남아 있는 3파드 상태를 드릴 완료로 판정한다

- 현재 위치: `specs/003-platform-foundation/design/t045-blocks/g4/g4-drill.ps1:253`.
- 재현 조건: 삭제가 수락되어 대상이 종료 중이지만 아직 목록에 남아 있고, ReplicaSet이 생성한 대체 파드가 Ready가 된다. 목록은 생존자 + 기존 대상 + 새 파드 3개다.
- 완료 조건은 “생존자도 대상도 아닌 Ready 파드가 정확히 1개”만 확인한다. 기존 대상 부재와 전체 2개를 검사하지 않아 3개 상태에서도 break한 뒤 `완료(삭제 target → 새 파드 Ready)`를 기록한다. 삭제가 끝났다는 운영 기록을 남기기에 증거가 부족하며 종료 지연/남은 대상의 연결을 감춘다. 이 검토는 이전 드릴 이력 사슬을 요구하지 않는다. 현재 실행의 삭제 후 상태를 정확히 판정하라는 지적이다.
- 로컬 모의 증거: diff에서 **300초 while문만** AST로 추출하고 `$pods`에 생존자(서명 불변·Ready), 기존 대상(Ready), 새 파드(Ready)를 넣었다. Get-Date/Start-Sleep도 가상 함수였다. 결과는 `newName=new-pod`, `podCount=3`, `deletedTargetStillPresent=true`, 가상 경과 **10초**다. kubectl·ssh·oci나 본체 전체는 실행하지 않았다.
- 수정 방향: 완료 조건에 기존 대상 부재와 정확히 2개를 포함한다. 기한까지 종료되지 않으면 “삭제 요청됨, 완료 미확인”으로 끝내며 추가 삭제는 하지 않는다. 하네스 delete 모의도 대상 제거와 새 파드 생성을 독립적으로 제어해야 이 과도 상태를 표현할 수 있다.

### G4-R1-04 — P2 / medium: A5-3의 R3 1파드 제한 회귀는 아직 고정되지 않았다

- 현재 위치: `specs/003-platform-foundation/design/t045-blocks/g4/harness-g4.ps1:648`, `:700`; 보호 대상은 `g4-adopt.ps1:450`.
- R3의 9개 실행 줄은 `$R3_SEQ`/`$R3_ORDER`가 전문과 순서를 비교하도록 바뀌었다. 이에 따라 base64 개행 방지·최소 길이·force-conflicts는 정적으로 보호된다.
- 하지만 “④ 위 sha256sum 대조로 값이 옳은 것을 확인한 뒤에만 파드를 **1개만** 지운다”는 그 9줄 밖이며, G4-06의 want/notWant에도 없다. 현재 하네스 전체에 `1개만` 또는 `④`를 검사하는 항목이 없다. `delete pod POD_NAME` 존재만 확인하므로 “해시 대조 뒤에만/1개만”의 제약 제거를 잡지 못한다.
- 재현 대상 변이: 이 문구만 `④ 파드를 지운다`로 바꾸기. 실행 9줄, 파서, 명령 허용 목록, 기존 want는 그대로다. 최신 A5-3이 명시한 A5-15와 동일한 미보호 표면이다. 진행 중 mutants에는 A5-15가 추가되어 있음을 검색으로 확인했으나 그 runner 또는 전수 하네스는 재실행하지 않았다. 따라서 여기서는 **ESCAPED 실측**이 아니라 **정확한 단언 누락**으로 보고한다.
- 수정 방향: ④ 전문도 R3 계약에 포함하고 A5-15가 의미 있는 실패를 내는지 확인한다. 아직 “A5-3 전체 해소”로 기록하면 안 된다.

### G4-R1-05 — P3 / low: 드릴 전제가 성공해도 단계 요약은 미실행이다

- 현재 위치: `specs/003-platform-foundation/design/t045-blocks/g4/g4-drill.ps1:21`, `:286`.
- `1) 드릴 전제`는 시작할 때 “미실행(이 실행에서 여기까지 오지 못했다)”으로 초기화되지만 이후 갱신이 없다. 정상 삭제·검증 완료 뒤에도 같은 문장이 런북용 요약에 남는다.
- 로컬 AST에서 해당 로그 키에 대한 후속 대입 **0개**를 확인했다. 게이트 실행 여부를 오기록하므로 요구된 단계별 사실 요약에 맞지 않는다.
- 수정 방향: ES·hash·UID·data-hash·2 Ready 검사 완료 시점을 기록하고 정상 경로 단언에 넣는다.

## 요구사항 및 안전장치 대조

| 영역 | 판정과 근거 |
|---|---|
| adopt 클러스터 쓰기 0 | 현 소스에서 kubectl은 `$kq` 한 곳이며 get/auth 런타임 허용 목록, 고정 네이티브 argv 및 helper 제한이 있다. 변경 helper·삭제 호출은 제거됐다. 모의는 get/auth/logs 이외를 기록한 뒤 adopt에서 즉시 throw하며, 모든 시나리오에 Mut.Count=0 사후조건이 있다. 새 `readOnlyAst` 한 검사만이 아니라 기존 lint와 합쳐 성립한다. |
| adopt의 캡처·판정 | 키 집합, ES 선존재, 단일 GET의 managed·값 검사, PM 출처 경고, 값·UID 감시, ownerRef/managed/data-hash/Argo 단일 소유가 유지됐다. resume은 파드 불변 미판정이라고 표시한다. 삭제한 이전 드릴 사슬을 다시 요구하지 않는다. |
| drill 삭제 전 | 신원·get/delete 권한과 namespace, break-glass 둘 다 실패 시 거부, hash/UID/data-hash, 정확히 2 Ready, 이름 입력, second 경고, 최후 hash/UID/양쪽 서명·Ready 재확인을 확인했다. ES Ready 게이트는 G4-R1-01 때문에 실제 사용 불가다. |
| 요청 1회와 응답 유실 | drill `$kdel`은 한 호출 지점이고 Add/log 기록이 네이티브보다 앞선다. 비0이면 수락 여부 불명으로 중단하며 자동 delete 재시도는 없다. restore도 apply 회계 선행, 실패/성공/되읽기 검증을 구분한다. |
| 삭제 후 | 생존 파드 존재·서명·Ready, 새 Ready, 유한 조회 대기, 로그 본문 비출력과 문구 존재, ssh/노드, 창 A 경고가 있다. 기존 대상 종료 조건은 G4-R1-03 참조. |
| restore 및 R2 | 기존 type 보존·기존 Secret만·PM 해시·stdin apply·SKIP·temporary·5분 뒤 재확인은 유지됐다. 머리글은 재인수→normal drill과 ES 없는 수동 R3를 구분한다. 마지막 출력 :220은 아직 일반적인 “드릴 규칙 그대로”여서 새 머리글의 분기를 출력에도 반영하면 인계가 더 명확하다. |
| R1/R2/R3 | adopt의 상세 안내와 R3 출력 전용 bash 조각은 유지됐다. apply 오류를 무조건 쓰기 0으로 부르던 문면도 결과 미확정으로 수정됐다. 독립 drill의 삭제 전 연결은 G4-R1-02로 손실됐다. |
| 비밀·Ordinal·EOF | 값은 base64 SHA-256로만 인계하고 문자열 판단은 Ordinal이다. SecureString 직후 클립보드 비움, finally 첫 정리, 비밀의 -match 금지가 유지된다. EOF 반환 모의와 adopt 3경로·drill 정지점 시험이 추가됐다. 실제 터미널/메모리 소거/clipboard/Ctrl+C 보장은 이번 검토 범위 밖이다. |

## round5 처리 판정

| ID | 독립 판정 |
|---|---|
| A5-1 / A5-2 / A5-6 | 이전 삭제 상태 사슬과 그 소비자 자체가 없어졌으므로 해당 원인은 구조적으로 소멸했다. adopt 쓰기 0 검증으로 대체한 방향이 맞다. |
| A5-3 | 실행 9줄은 개선됐으나 1파드 제한 단언은 남음(G4-R1-04). |
| A5-4 | D-01이 “방금 삭제한 커넥터” 경고를 want로 고정한다. 뒤쪽 창 A 최종 경고는 코드에 유지된다. |
| A5-5 | EOF 스위치와 정지점/해시/비밀 입력·빈 비밀 사례 추가로 대응됐다. NonInteractive의 PowerShell 자체 오류와 실제 stdin EOF가 같은 문면인 것은 아니며 live 재실측을 주장하지 않는다. |
| A5-7 | 런타임 동사 검사 전문 AST 고정과 namespace 인자 검사 추가. 이미 드릴 선언/접두어 경고 2개는 구조 제거 대상이라 복원 불필요. |
| A5-8 / B5-01 / B5-02 | 누계 1회 주장과 접두어 잠금이 없어졌다. 라벨+data-hash 없는 adopt 시나리오 G4-54, 라벨만 없는 G4-55와 공통 무쓰기 검사가 있다. 별도 drill 재실행을 전체 누계 1회로 보장한다고 해석하지 않는다. |
| A5-9 / B5-05 | 과거 실측 및 대화형 bash 회귀 산출물의 문서화 사항이다. 현 report는 이를 이번 live 실행으로 주장하지 않는다. NOTES는 컨트롤러 소유이며 해당 반영은 본 리뷰의 본체 합격 근거에 넣지 않았다. |
| B5-03 | restore 머리글의 data-hash 삭제 금지 및 normal drill/R3 분리 반영 확인. |
| B5-04 | drill 머리글이 최신 startTime 선정과 컨테이너 재시작 때의 값 재판독 한계를 함께 말한다. |

## 검토 방법·한계

- brief, 구현 report, 안전장치 지도, 확정 README, round5 findings를 읽고 diff와 대조했다. report는 주장으로 취급했다.
- 원본 추가 읽기는 diff에서 함수가 끊긴 세 구간으로 한정했다: adopt 231–302(감시 루프·인수 판정이 hunk 사이에 생략되어 복구 연결/ownerRef 보존 확인), restore 93–226(변경 diff가 머리글만 포함해 단일 쓰기·응답 유실·finally 의미 확인), harness 335–440(기존 Lint-Block의 시작과 네이티브/허용 목록 검사가 생략되어 새 AST 검사와 합쳐지는 보장 확인). 그 외에는 diff와 목적을 좁힌 rg/AST를 사용했다.
- 운영 API, 실제 kubectl/ssh/oci/Vault, 운영 자격, 본체 전체 실행, 전체 하네스 재실행, 커밋, 하위 에이전트 생성은 없었다. 로컬 검증은 diff에서 추출한 AST와 while문 1개의 가상 모의뿐이다. 외부 조회는 공개 client-go parser 원문 읽기였다.
- 본체/하네스/변이 소스 수정은 하지 않았다. 이 보고서만 작성했다. full mutation 및 run-all 결과를 독립 재검증한 것으로 표현하지 않는다. 알려진 budget_alert_email 환경 누락은 수정 범위 밖이다.
