# T045 G4 분리 안전장치 대조표

작성: 2026-09-22. 목적은 분리 구현과 검증의 누락 방지다. 새 작업 트리의 adopt/drill/harness는 읽지 않았으므로 이 문서는 구현 합격 판정이 아니다.

근거: `AGENTS.md`, `.specify/memory/constitution.md`, `.claude/rules/specs.md`, `.claude/rules/infra.md`, 현행 `specs/003-platform-foundation/design/t045-blocks/g4/README.md`의 2026-09-22 사용자 확정 설계, `reviews/verify-r4-r5.json`의 `rounds[1].findings`, 그리고 `git show bc229cc:<경로>`로 읽은 기존 `g4-adopt.ps1`(742줄)·`g4-restore.ps1`(226줄). 아래 A/R 줄 번호는 각각 이 커밋의 adopt/restore다. README의 adopt 724줄 표기는 해당 기준 커밋과 다르므로 줄 번호는 커밋 기준으로만 해석한다.

실제 kubectl/ssh/oci/Vault 호출, 자격 접근, 원본 코드 수정, 커밋, 하위 에이전트 실행은 하지 않았다. 메모리 검색에는 G4 직접 근거가 없어 분석에 사용하지 않았다.

## 1. 확정 경계

| 블록 | 허용 효과 | 성공의 의미 | 재실행 의미 |
|---|---|---|---|
| adopt | 클러스터 쓰기 0; 캡처·머지 대기·인수 판정 | 읽은 값·UID·소유권 등의 판정 완료; 실제 교체 성공은 아님 | 중단·완주 뒤 반복해도 클러스터를 바꾸지 않는다 |
| drill | 명시적 이름의 파드 삭제 요청 최대 1건 | 교체된 새 파드 Ready, 남은 파드 미접촉, 경로 증거를 각각 확인 | 반복하면 새 삭제 요청이 생긴다. 멱등·전체 실행 누계 1건을 주장하지 않는다 |
| restore | 기존 Secret 한 필드의 apply 요청 최대 1건 | apply 응답과 값·UID 되읽기 검증은 별도 사실 | 현재 값 해시가 기준과 같으면 토큰 입력 없이 SKIP; 응답 유실도 재조회로 판별 |

README의 마지막 일반 규약인 ‘재실행 안전’은 drill에 기존의 멱등 의미로 적용할 수 없다. 첫 줄의 재실행 위험 경고, 새 삭제 대상 이름 확인, `second` 확인으로 위험을 명시하는 설계다. 이전 드릴 사실을 다음 실행의 사람이 옮기는 상태 사슬은 다시 만들지 않는다.

## 2. 없어지면 안 되는 기존 안전장치와 목적지

| 기존 장치·의미 | 기준 근거 | 목적지 | 분리 후 확인 항목 |
|---|---|---|---|
| 단일 자식 스코프 `& {}`; 파일 실행만; stdin 주입·dot-source 피하기 | A9–13,47–53; R21–36 | 세 블록 | 세션에 비밀·설정이 남지 않음; 빈 줄/CR/TAB/끝 바이트 규약; 네이티브 비0을 직접 처리하도록 로컬 preference 고정 |
| 단계 표를 전부 미실행으로 초기화하고 finally에서 사실만 보고 | A60–84,604–634; R44–52,201–224 | 세 블록 | adopt 판정과 drill·restore 완료를 혼합하지 않음; 중단 때 성공을 인쇄하지 않음 |
| FlushInputBuffer + Ordinal 단어 확인 + 빈 Enter·EOF 거부 | A91–111; R56–74 | 세 블록 | 실제 null을 반환하는 모의 EOF 시험; 비밀 빈 값과 비대화형 PowerShell 자체 오류 구별 |
| 조회 전용 helper 런타임 동사 허용 목록 | A112–133; R75–94 | 세 블록 | adopt AST와 모의 실행 양쪽에 get/auth/logs 이외 동사 거부; restore/drill도 조회 helper로 쓰기 우회 불가 |
| 조회 요청 timeout 10s, 최대 3회, 5초 간격, exit 검사 | A121–133; R82–94 | 세 블록 | 일시 실패 후 회복·지속 실패 모두 검사; 조회 실패를 값 동일·리소스 없음으로 바꾸지 않음; auth의 rc=1은 'no' 판정으로 처리 |
| 클러스터 노드 신원과 namespace 범위 권한 확인 | A187–193; R111–117 | 세 블록 | adopt get secrets, drill get secrets/delete pods, restore patch secrets 등 각 효과에 맞춤; `-n cloudflared`를 잃지 않음 |
| SSH 새 연결과 이미 열린 창 A 세션을 boot_id 대조로 구별 | A194–222 | drill 필수; adopt의 운영 준비 안내는 유지 가능 | 새 ssh 성공만으로 창 A가 살아 있다고 주장하지 않음; BatchMode/timeout 유지, 호스트 키 무인 수락 추가 금지 |
| OCI 프로브의 한계와 읽기 전용 자격 제외 | A203–216 | drill | svc-verify/security_token 성공을 복구 능력으로 계산하지 않음; region 조회 성공은 NSG 쓰기 권한 증명이 아님을 명시 |
| 둘 다 실패하면 no-breakglass 확인을 받아도 삭제 거부 | A223–233,462–469 | drill | 입력 단어가 위험 승인으로 변하여 삭제가 허용되지 않음; 삭제 0건 확인 |
| 인수 뒤 라이브 값을 기준으로 다시 잡지 않음 | A235–253,264–300 | adopt | managed 라벨 감지 시 보존된 hash/UID 또는 명시적 PM 기준 출처; ES 선존재·캡처 중 ESO 변경 시 가짜 PASS 거부 |
| 키 집합은 TUNNEL_TOKEN 1개; ES 부재; UID/managed/data-hash/value 단일 GET 스냅샷 | A270–293 | adopt | 매핑 밖 키 유실과 GET 사이 인수 경쟁을 막음; 스냅샷 필드 누락/빈 값 거부; 사용 후 snap 즉시 제거 |
| PM 기준 유도는 라이브 검증이 아니며 자기 비교를 검증이라고 부르지 않음 | A244–250,313–337,650–655 | adopt 및 복구 인계 문면 | PM 유도 경고를 정상·중단·복구 안내에 유지; 오래된 PM으로 정상 라이브를 덮지 않도록 출처 검증 안내 |
| PM 원본 사전 대조, skip-pm의 복구 제약 | A313–337 | adopt | PM 불일치면 머지 중단; 동일 출처끼리 비교 생략; skip-pm을 완료로 적지 않음 |
| 비밀 입력 전 clipboard history 꺼짐 확인; SecureString 입력 직후 clipboard 비움 | A104–111,245–247,325–327; R67–74,108–110 | adopt/restore | 설정 조회 실패도 거부; clipboard 비우기 실패는 경고; 비밀을 argv·화면·파일·전역 변수·히스토리에 전달하지 않음 |
| SHA-256 대상은 Secret의 base64 문자열, Ordinal 비교 | A89,280–293; R54,155,177–181 | 세 블록 | drill 입력도 같은 해시 정의; raw token 해시와 혼동 금지; 비밀 아님인 hash/UID만 블록 사이 전달 |
| 먼저 감시를 시작하고 다른 창에서 머지; 최대 15분 폴링 중 값·UID 감시 | A338–382 | adopt | merge 정지점 취소 때 머지 유도하지 않음; ES 없는 재인수는 merge, 살아 있는 resume은 continue; 지속 오류/timeout은 판정 미완 |
| 값 변경과 UID만 변경의 원인·복구 분리 | A356–367,384–395,635–646 | adopt; drill의 직전 검증 실패 안내 | UID만 바뀌면 kv/Secret 값을 덮지 않음; 새 UID와 조사 안내; 값 변경이면 복구 안내로 이동 |
| Orphan 증명(ownerRef 없음), managed=true, data-hash 존재 | A396–403,417–419 | adopt; drill의 data-hash 독립 검사 | ownerRef가 있으면 ES 삭제 안내로 바로 보내지 않음(GC 위험); managed만으로 실제 ESO 쓰기를 증명했다고 하지 않음 |
| Secret에 Argo tracking 미복사; ES 단일 Application 소유 | A404–416 | adopt | tracking 누락·잘못된 OWNER·platform-cloudflared의 external-secrets 소유·빈 resources 응답 각각 실패 |
| 파드 이름/restartCount/startTime 서명, Ready 별도 판정, selector 고정 | A153–166,301–306,420–444 | adopt의 관측 및 drill | 기존 파드 불변 관측을 지울 경우 성공 문면에서도 제거; drill에서는 정확히 2개 모두 Ready 하드 게이트; 이름만 같아도 restartCount 변화 감지 |
| 가장 늦은 startTime, 동률 이름 Ordinal로 삭제 대상 결정 | A508–520 | drill | 배열 입력 순서에 무관한 결정; 사람이 입력한 이름과 완전 일치; 잘못된/빈 startTime을 정렬에 맡겨 정상 판정하지 않음 |
| 사람 대기 뒤 값·UID·파드 재확인 | A523–557 | drill | 대상/생존 파드가 유지되고 양쪽 Ready인지 확인; 생존 서명뿐 아니라 대상 서명/상태 변경도 다룸; 이전 판정만 믿고 삭제 금지 |
| 요청 전에 회계 기록, 단일 이름 delete, wait=false, 30s timeout | A141–152,558 | drill | 네이티브 호출 중 Ctrl+C·비0·응답 유실에서도 ‘시도 1건/결과 불명’; 자동 delete 재시도·selector 삭제·restart·scale 없음 |
| 삭제 후 최대 300초 Ready 대기; 조회 실패는 남은 기한까지 재조회 | A560–578 | drill | 매 반복에 기한 확인; 지속 조회 실패도 유한 종료; 이미 삭제한 뒤 새 삭제로 복구하려 하지 않음 |
| 남은 파드 존재·서명 불변, 새 이름 Ready | A568–584 | drill | 생존 파드 사라짐/재시작 시 중단; 생존 Ready도 성공 시점에 확인하는 편이 안전; 원래 대상이 아직 남은 과도기 3개 상태를 완전 완료로 오인하지 않음 |
| 로그 본문 비출력, Registered tunnel connection 존재만 확인 | A134–140,581–585 | drill | 로그 오류/문구 없음은 경고·증거 미확인; 이를 조용한 PASS로 흡수하지 않음 |
| 삭제 직후 창 A 재연결 안내, 최종 ssh hostname·nodes Ready2 확인 | A580,586–602 | drill | A5-4 문면 변이 고정; 전/후 ssh 실패 의미 구별; 창 A 세션과 새 ssh 연결 별도 사실 |
| 비밀을 거친 변수와 clipboard 정리를 finally 첫머리에 수행 | A604–608; R201–204 | 세 블록의 해당 변수 | 출력보다 먼저 정리; 이후 Write-Host/Write-Warning만; 예외·중단 경로도 정리; `-match`로 $Matches에 비밀을 남기지 않음 |
| 미판정·값 변경 중 컨테이너 재시작의 위험과 복구 지연 금지 | A1–8,632–634,656–660; R17–20 | adopt/drill/restore 안내 | 같은 파드 이름/UID도 env가 다시 로드될 수 있음; 노드 재부팅·SUC·drain·Deployment 수정 금지 안내 보존 |
| restore는 기존 Secret의 현재 type을 보존하고 값 1개만 SSA | R147–155,171–196 | restore | Secret 부재는 생성하지 않고 중단; type/UID 빈 값 거부; force-conflicts/field-manager/timeout/stdin 유지 |
| restore hash 일치면 쓰기·토큰 입력 없이 SKIP | R155–161 | restore | 사전 clipboard/권한 검사는 여전히 적용됨을 안내; 응답 유실 뒤 재실행도 SKIP로 해결; UID가 다르다는 이유만으로 쓰지 않음 |
| restore Git 소유 중단 증거와 temporary 분기 | R125–146 | restore | ES 부재만으로 안전 판정 금지; Argo 양성 대조 행 필수; Argo 조회 실패는 복구 막지 않고 temporary로 격하 |
| restore 승인과 newuid 확인은 토큰을 꺼내기 전에 | R163–181 | restore | 승인 대기 중 평문 보관 없음; 길이≥32·ASCII 전체 일치·PM hash 일치 후에만 payload 생성 |
| 쓰기 시도/응답 성공/되읽기 검증 세 상태 분리 | R95–105,185–199,212–223 | restore; drill에도 같은 의미 적용 | 응답 성공을 검증 성공으로 기록하지 않음; 실패·중단 후 파드 먼저 건드리지 말고 재조회 |
| 복구 후 refresh 1주기 뒤 다시 SKIP 확인, field-manager 잔류 기록 | R212–220 | restore 인계 | 즉시 해시 일치가 영구 복구를 증명하지 않음; 다음 파드 교체는 ES 상태에 맞는 경로로 안내 |

## 3. 복구 흐름의 보존 위치

| 흐름 | 유지할 의미 | 위치 및 연결 |
|---|---|---|
| UID만 변경 | 값 정상인 상태에서 kv-correct/restore 쓰기 금지; 삭제 주체와 재생성 원인 조사 | adopt 중단 안내와 drill 입력/직전 검증 실패 안내 |
| R1: Vault 값 오류 | kv-correct의 PM 직접 입력 경로; 덮인 라이브나 존재하지 않는 세션 백업을 원본으로 쓰지 않음; refreshTime 갱신 뒤 재판정 | adopt의 복구 안내 유지; drill은 이를 즉시 찾을 수 있게 연결 |
| R2: 매핑 오류·R1 불가 | revert PR → Argo 반영 → ES 삭제 → restore; controller/webhook/finalizer 조건; ownerRef GC 위험 구별 | adopt의 상세 안내와 restore 머리글/요약; ES 삭제나 Git 조작은 자동 실행하지 않음 |
| temporary | ESO/Git가 남았거나 상태 불명일 때 재덮어쓰기 위험을 수용하는 제한적 값 복구; 근본 해결과 분리 | restore의 확인 단어 및 요약 |
| R3: 터널 완전 잠금 | PowerShell 블록은 터널을 전제로 하므로 사용할 수 없음; 열린 창 A 또는 OCI 운영자 NSG 임시 경로로 노드 셸 진입; 복구 뒤 임시 규칙 제거 | adopt의 출력 전용 R3 안내 유지, drill/restore에서 경로 명시. 에이전트 실행 권한으로 해석하지 않음 |
| R3 비밀 취급 | history off → secure read → B 초기화 → ASCII/길이 검사 → base64 -w0 → T 제거 → stdin SSA → B 제거 → hash 되읽기 → history on; 중간부터 재시도 금지 | R3 안내 전문/순서 고정 시험(A5-3); 과거 대화형 Bash 실측은 모의 시험과 별도 증거(B5-05) |
| R3 이후 1파드 교체 | 해시 검증 전 교체 금지; 1개 명시 이름만; 화면 에코/스크롤백 잔여 주의 | R3 문면 자체와 변이 시험에 보존; normal drill의 ES 필수 게이트와 혼동 금지 |

## 4. 의도적으로 삭제하는 구조

| 삭제 대상 | 삭제 이유 | 대신 남기는 계약 |
|---|---|---|
| adopt의 `$kdel`, 삭제 호출 및 드릴 완료/접근 확인 단계 | adopt 쓰기 0이라는 구조적 보장 | AST 허용 동사 검사 + 모의 쓰기 즉시 실패 + 모든 adopt 시나리오 공통 mutation log 빈 값 |
| `drilled:` 입력/출력 사슬, `$preDrilled`, `$podDrill` 및 쌍둥이 출력 억제 | A5-1/2/6 및 중단 시 잠금 유실의 원인 | hash/UID 인계만으로 adopt 완료; 다음 실행의 안전성을 출력 접두어에 의존하지 않음 |
| `first-drill`, `nopods`, 라벨 기반 이전 드릴 판별과 1D drilled/first 분기 | 파드 삭제를 판정 스크립트에 묶는 역사 추론 제거 | drill에서 현재 상태를 독립 조회; 별도 이름 확인과 `second` 경고 |
| 이전 실행 드릴 결과를 서명/ES 시각으로 추론하여 adopt 판정을 예외 통과시키는 체인 | 여러 실행 누계의 파드 삭제 잠금을 없애는 결정 | 현재 관측한 파드 변경을 거짓 불변으로 기록하지 않음; 필요하면 관측 시점/판정 한계를 표시 |
| ES 생성 뒤 시작한 파드의 존재를 무조건 SKIP로 쓰는 하드 잠금 | 확정 설계가 경고 + `second`로 변경 | `second`는 이름 확인을 대체하지 않음. 모두 Ready 조건이 실패하면 `second`도 삭제 허용 못 함 |
| 체인 전용 변이/문면 단언 | 존재하지 않는 구조를 되살리지 않음 | 제거 ID와 대체 불변식을 명시; 공통 잠금·비밀·회계·복구 규약 변이는 유지 |

이전 드릴 감지 삭제는 인수 전 기준값 오염 방지나 data-hash 실제 쓰기 증거까지 삭제하라는 뜻이 아니다. 과거 라벨/data-hash 재인수 판정의 ‘두 번째 삭제 잠금’ 기능은 폐기하되, 인수 상태와 캡처 출처의 정직한 설명은 남긴다.

## 5. 최신 잔여 지적 처리 지도

| 지적 | 분리 후 처리 |
|---|---|
| A5-1 high, A5-2 medium, A5-6 low | 체인 삭제로 해당 원인은 구조적으로 소멸. 새 adopt 무쓰기/중단 경로 시험으로 대체하며 ‘기존 테스트가 사라져서 해결’이라고 하지 않음 |
| A5-3 medium | R3 조각 전문 고정; base64 -w0, 최소 길이 32, force-conflicts, 1파드 제한을 각각 깨뜨린 변이를 검출 |
| A5-4 medium | drill 삭제 직후 창 A 경고와 최종 세션 확인을 독립 단언 |
| A5-5 low | 정지점/비밀 아닌 입력/비밀 입력 EOF 시나리오 추가; 빈 문자열과 null 구별 |
| A5-7 low | 런타임 허용 동사와 namespace 권한 검사 보존·시험. 이미 드릴 선언/접두어 경고 두 항목은 구조 삭제 |
| A5-8 low, B5-01 medium, B5-02 low | 누계 1회·두 사람 실수 외 경로 없음 주장을 삭제. 라벨+data-hash 동시 삭제 상태에서도 adopt 쓰기 0을 시험; drill 재실행의 위험은 명시 |
| A5-9 info | 과거 실측은 제공된 근거의 범위만 기록. 이번 보고서는 그 실측 재실행을 수행하지 않음 |
| B5-03 low | restore 머리글의 재인수·drill 참조를 새 구조로 고침. 폐기한 접두어 잠금을 새로 적지 않되 data-hash의 증거 의미와 삭제 금지 안내는 유지 |
| B5-04 info | 처음부터 있던 커넥터를 삭제 대상으로 삼지 않는 선정 기준과, 컨테이너가 재시작하면 값이 바뀔 수 있다는 한계를 함께 설명 |
| B5-05 info | 대화형 Bash 회귀 증거가 정적/모의 검사와 다름을 문서화; 실제 토큰/클러스터 없이 동작을 검증하는 별도 범위 유지 |

## 6. 새 설계의 구체적 위험과 확인 항목

| 위험 | 반례·확인 항목 | 판단 |
|---|---|---|
| R2 뒤 normal drill로 갈 수 없는 안내 | R2는 ES를 삭제하지만 drill은 ES Ready=True/SecretSynced 필수. ‘restore 후 바로 g4-drill’ 문구는 실행 불가능한 인계다. 재인수 완료 후 normal drill과, ES를 제거한 채의 비상 수동 1파드 교체를 명확히 나눈다 | 가장 먼저 문면·시나리오로 고정할 연결 문제 |
| 읽기 전용 adopt가 가짜 기준값을 만드는 문제 | 읽기 전용은 쓰기 피해만 제거한다. managed/data-hash가 소실된 뒤 잘못된 라이브를 새 기준으로 잡으면 drill이 잘못된 hash를 정상으로 받는다. 인수 전 스냅샷·PM 출처·매핑·ownerRef/tracking 검사를 보존하고 판정 완료 시에만 drill 다음 단계로 표시 | 구조 분리만으로 소멸하지 않음 |
| 삭제 직전 입력·상태 대기 경쟁 | 사용자가 이름을 입력하는 동안 값, UID, 대상 restartCount, Ready, 파드 수가 바뀜. 재확인에서 모두 실패 시 삭제 0; 인수 뒤 시작 경고가 새로 필요해지면 경고 없이 삭제하지 않음. 파드 시간 필드가 빈 값/잘못된 형식/동률인 사례 포함 | fail-closed 게이트 회귀 시험 필요 |
| 요청 실패를 쓰기 0으로 오기록 | drill/restore 네이티브 호출이 서버 수락 후 응답 유실. 회계는 선행하고 재시도는 조회만. 특히 기존 R3 A723–726의 ‘apply 오류면 쓰기 0건’은 모든 오류에 일반화할 수 없음: 확정 validation 거절과 결과 불명 통신 실패를 나누어 안내 | 기존 문면 결함을 이식하지 말 것 |
| 반복 drill·불완전 회복을 자동 안전으로 오인 | 최신 startTime 선택은 의도한 생존자를 보존할 가능성을 높이지만 전체 재실행 멱등 보장은 아님. `second`는 경고이지 잠금이 아니다. 새 파드 Ready 뒤 로그 없음/생존 Ready 아님/ssh 실패/창 A 단절을 완료와 구별하고 두 번째 교체를 유도하지 않음 | 첫 줄 경고·후속 단계 요약·거부 시나리오 필요 |

추가 확인: 조회 실패/빈 값의 해시를 정상 값처럼 비교하지 않도록 drill에는 입력 hash 형식과 실제 Secret 값 비어 있음 검사를 둔다. 시간 문자열은 유효 형식일 때만 Ordinal 시각 비교한다. 조회는 재시도하되 delete/apply를 helper retry에 섞지 않는다. 인수 판정과 drill 삭제 사이 간격 때문에 drill은 adopt가 통과했다는 사실을 권한·값·UID·ES 상태의 현재 증거로 대체하지 않는다.

## 7. 증거 한계

이 보고서는 기존 소스의 안전장치와 확정 설계 사이 대응표다. 실제 JSONPath 형식, ESO data-hash 관측, Argo Missing 리소스 목록, 네트워크 단절/Ctrl+C, 클립보드/터미널 입력 버퍼의 실제 동작은 이번 작업에서 검증하지 않았다. 모의 시험 통과나 AST 무쓰기 검사는 운영 자격·break-glass 쓰기 권한·실제 복구 성공을 증명하지 않는다.
