# tests/platform/reboot.tests.ps1 — 노드 A 재부팅 후 자동 복구 단언 (T034, US2 AC4) + "실제로 재부팅됐는가" 가드(T048 선행)
# Run (평상시 — 러너 tests/platform/run-platform-tests.ps1이 인자 없이 호출):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1
#     → 전제(kubectl·KUBECONFIG·agent-view 신원)만 검사하고 reboot-1..4는 SKIP, exit 0. 재부팅 리허설이 아닐 때
#       다른 플랫폼 테스트를 막지 않기 위한 동작이며, 전제 실패(kubectl 부재·KUBECONFIG 부재·신원 불일치)는 여기서도 FAIL이다.
# Run (재부팅 리허설 — 운영자 수동 트리거, 세 단계):
#   ① 재부팅 전 — 노드 A의 부팅 ID를 적어 둔다(읽기 전용, 폴링 없음):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -Baseline
#     → 전제(kubectl·KUBECONFIG·agent-view 신원) 뒤 `kubectl get nodes -l role=platform -o json`을 한 번 읽고
#       'baseline: node=<이름> bootID=<status.nodeInfo.bootID> ready=<Ready 조건 status 또는 none>' 한 줄을 낸다(exit 0).
#       조회 실패 · 노드 수 ≠ 1 · bootID 부재/형식 불일치는 FAIL reboot-baseline(exit 1).
#   ② 하네스를 먼저 켠다 — ①의 bootID와 node 이름을 둘 다 넘긴다(둘 다 필수). 재부팅을 기다린다(armed, 아래):
#     pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -AfterReboot -BaselineBootId <①의 bootID> -BaselineNode <①의 node> [-ArmTimeoutMinutes 30]
#   ③ 운영자가 준비됐을 때 SSH(cloudflared 터널)로 노드 A를 재부팅한다(이 파일은 재부팅하지 않는다 — 관찰만 한다).
#     → 0초 기준점(H2): ②가 옛 부팅을 보는 동안 관측마다 기준점을 그 관측의 시작으로 옮긴다(armed — 'armed: …' 진행 줄은 최대 60초에 한 줄,
#       그동안 waiting 줄은 내지 않는다). "옛 부팅" = API 도달 + 신원 일치 + 같은 노드 + 기준값과 같은 bootID + 노드 A Ready 조건 status=True.
#       C — 옛 bootID인데 Ready≠True는 옛 부팅이 아니다: 재부팅 뒤 kubelet이 끝내 status를 못 올리면 저장돼 있던 옛 bootID가 계속 보이고 Ready는
#       유예 뒤 Unknown이 된다고 본다(실측 전). 그 관측은 미충족이고 기준점을 옮기지 않으며 연속 횟수는 0이다(detail 'node A ready=<값> with the
#       baseline bootID …') — 그래서 그 고장은 arm 시간 제한(기본 30분)이 아니라 마감(300 s)에 FAIL이다.
#       그 밖의 관측(API 불통 · 호출 실패 · 새 bootID …)에서는 기준점이 마지막으로 옛 부팅을 본 관측에 머물고
#       'zero point fixed at <UTC> (last observation of the old boot); …' 한 줄을 낸다(기준점 UTC는 밀리초까지).
#       J1 — 한 번 굳은 기준점은 옛 부팅을 연속 세 번 봐야 다시 움직인다(세 번째 관측의 시작으로): "옛 부팅이 아닌 관측"을 한 번이라도 본
#       뒤에는 옛 부팅 관측 한 번·두 번으로는 기준점이 그대로이고('old boot seen again after the zero point was fixed (1 of 3 needed to move it
#       again); zero point stays at <UTC>' — 구간마다 한 줄, 판정은 굳은 기준점에서 센 마감의 보통 미충족), 세 번째에서 다시 armed가 된다
#       ('note: the old boot was seen 3 times in a row …' + 'armed:' 줄). 연속 횟수는 옛 부팅이 아닌 관측이 끼면 0으로 돌아간다.
#       근거: 노드 A는 API 서버를 함께 돌리므로 재부팅 뒤 API가 먼저 돌아오고 kubelet이 첫 status를 올리기 전까지(수 초–십수 초로 추정 · 실측 전)는
#       get nodes가 저장돼 있던 옛 bootID를 돌려준다 — 그 관측을 "옛 부팅이 살아 있다"로 읽으면 기준점이 재부팅 뒤로 옮겨져 마감이 노드가 내려가
#       있던 시간만큼 느슨해진다. 연속 세 번은 폴링 간격 둘 이상(실제 경로에서 30초 이상)에 걸친 관측을 요구한다.
#       A — 재시도: 실제 경로의 호출은 가끔 실패한다(2026-10-01 실측: 여섯–여덟 번에 한 번 · 10초쯤 걸려 실패 — 관측 하나는 호출 둘이라 관측당
#       4분의 1 안팎). 연속 횟수는 실패가 낄 때마다 0으로 돌아가므로, 실패마다 기준점이 굳으면 대기 시간의 절반 이상이 굳은 상태가 된다. 그래서
#       reboot-0 관측 안에서 신원 호출이나 노드 조회가 "도달 실패"(kubectl이 0이 아닌 코드로 끝났고 401이 아님 — 전송 실패 · 시간 초과 등)로 끝났고
#       직전 관측이 옛 부팅이었으면(armed, 또는 굳은 뒤 옛 부팅을 다시 세는 중 — 연속 횟수 ≥ 1) 그 호출을 한 번만 바로 다시 한다(호출마다 한 번).
#       재시도한 관측은 다시 한 호출을 시작한 시각이 그 관측의 시작이다: 옛 부팅이면 기준점(옛 부팅이 그 뒤에 살아 있었다고 확인된 가장 늦은 시각),
#       충족이면 마감 판정(재시도가 마감 뒤에 시작해 충족을 보면 late — 마감 뒤에 모은 증거로 통과하지 않는다), 그리고 UTC 표기(E). 재시도도
#       실패하면 옛 부팅이 아닌 관측이다. 401 · 다른 신원 · 노드 수/이름/bootID 형식 같은 판정 결과는 다시 하지 않고, 신원 규칙(401 연속 두 번 ·
#       다른 신원 즉시 fatal)은 재시도의 최종 결과로 관측마다 한 번 센다. 굳어 있고 연속 횟수가 0이면(재부팅으로 내려가 있는 구간으로 본다) 다시 하지
#       않는다 — 내려가 있는 동안 관측이 길어지면 복구를 늦게 본다. 재시도한 관측의 detail은 'retried:'로 시작하고(진행 줄의 120자 안에 남는다),
#       'retried: …' 진행 줄은 구간(기준점 상태가 armed ↔ 굳음으로 바뀔 때까지)마다 첫 재시도에 한 줄, 그 뒤로는 최대 60초에 한 줄이다.
#       재시도는 굳는 빈도를 낮출 뿐이다: 재시도까지 실패하면 기준점은 굳고 연속 횟수는 0으로 돌아가며(세 번을 처음부터), 굳은 채 재부팅이 시작되면
#       모든 경과 초에 (재부팅 시작 − 굳은 기준점)이 더해진다 — 엄격한 쪽이고, 그 차이에는 마감 말고 상한이 없다(마감을 넘기면 재부팅 전에 reboot-0이
#       만료된다 — 아래 B). 재부팅 명령은 마지막 기준점 줄이 'armed:'일 때(그 뒤 'zero point fixed' 없이) 주는 것이 가장 덜 엄격하다.
#       그래서 기준점은 실제 재부팅보다 앞이다(마지막으로 옛 부팅을 본 관측과 실제 종료 사이 — 굳어 있었다면 그 굳은 시각) — 마감은 그만큼 엄격한
#       쪽으로 센다. 잔여(잘못된 PASS 쪽 · 실측 전): 재부팅 뒤 낡은 bootID(Ready=True) 창이 연속 세 관측(폴링 간격 둘 이상)을 채울 만큼 길면, 또는
#       재부팅의 불통 전체(내려감 → API 복귀)가 직전 옛 부팅 관측과 그다음 관측의 재시도 사이(폴링 간격 하나 + 실패한 첫 시도 — 시간 초과면 최대 30 s)에
#       들어가 재시도가 낡은 bootID를 보면, 기준점이 재부팅 뒤로 움직인다. 뒤의 경우에는 "옛 부팅이 아닌 관측"을 본 적이 없으므로 낡은 창이 이어지는
#       동안 관측마다 기준점이 더 뒤로 간다(느슨해지는 폭 = 불통 + 낡은 창이 끝날 때까지 — 코드에는 상한이 없다). 어느 경우든 출력만으로는 확정할 수
#       없다 — 운영자의 재부팅 명령 시각과 끝의 'zero point (UTC)' 줄을 대조한다(기준점이 명령보다 뒤면 그 차이를 더해 다시 판정한다). 굳은 뒤의
#       낡은 창에서는 재시도가 일시 실패로 연속 횟수가 끊기지 않게 할 뿐 창의 길이 조건(폴링 간격 둘 이상)은 그대로다.
#       B — 굳은 채 재부팅 전에 마감이 지나면(새 bootID를 한 번도 못 봤고 마지막 관측이 옛 부팅인 채 reboot-0 만료) FAIL 줄에 'zero point fixed at
#       <UTC> (…); the old boot kept being seen after that but never 3 times in a row -- no reboot was observed; restart the harness'를 덧붙인다
#       (판정 · 종료 코드는 그대로 — 재부팅 전이면 하네스를 다시 켠다).
#       armed 동안에는 reboot-0의 마감이 만료되지 않는다 — 스크립트 시작부터 arm 시간 제한(-ArmTimeoutMinutes, 기본 30, 1..120)이 지나도록
#       옛 부팅만 보이면 reboot-0은 FAIL('no reboot observed within …')이고 나머지는 not attempted다. F — arm 시간 제한은 기준점이 움직이는
#       관측에서만 판정된다: 굳어 있는 동안에는(옛 부팅을 다시 세는 중 포함) 판정하지 않고 굳은 기준점에서 센 마감이 흐른다 — 그래서 제한이 실제로
#       판정되는 시각은 제한보다 늦을 수 있다(다시 armed가 되는 관측에서).
#       재부팅 뒤에 켜도 동작한다: 옛 부팅을 한 번도 못 보면 기준점은 스크립트 시작이고('zero point = script start …' 줄) 재부팅부터
#       시작까지의 시간만큼 마감이 느슨하다. 끝의 요약 앞에 'zero point (UTC): <ISO> (<last observation of the old boot | script start>)'.
#     → 아래 계약을 한 루프에서 폴링해 조건별 통과 시각(기준점 뒤의 경과 초)을 기록한다 — 진행 줄·PASS/FAIL 줄의 경과 초는 전부 기준점 기준이다.
#       E — 'reboot-N met' 진행 줄과 관측이 있는 PASS/FAIL 줄에는 그 관측을 시작 · 끝낸 시각을 'observation UTC <시작> .. <끝>'(밀리초)으로 함께
#       적는다(경과 초 표기는 그대로 — 기준점이 운영자의 명령 시각보다 뒤일 때도 명령 기준으로 다시 셀 수 있게).
#       간격은 명목 10 s다(한 라운드가 kubectl 호출·port-forward 시간만큼 길어지면 그만큼 늘어난다). 조건마다 마감이 있고,
#       마감 판정은 관측을 "시작한" 시각 기준이다: 마감 안에 시작한 관측이 충족이면 통과(그 관측이 마감을 넘겨 끝났으면 PASS detail에
#       'observation started at Ns'), 마감 뒤에 시작한 관측의 충족은 FAIL("met late …"), 미충족 관측이 마감을 넘겨 끝나면 FAIL
#       ("not met within …"). 그래서 마감이 실제로 느슨해지는 폭은 한 번의 관측에 걸리는 시간이다(kubectl 호출마다 --request-timeout=30s,
#       Vault 확인은 수립·응답 대기 최대 45 s에 마지막 HTTP 질의(최대 5 s)와 port-forward 정리(최대 3 s)가 더해진다 — 마감을 넘겨 끝난
#       관측은 PASS 줄에 'observation started at …'로 드러난다; reboot-0 관측은 재시도(A)가 끼면 호출 하나만큼 더 길어질 수 있지만 그 관측의 시작은
#       다시 한 호출의 시작이다). 마감 직전의 대기는 마감 1초 전에 끝나 마지막 관측이 마감 안에서 시작한다. G — 이 보정은 라운드의 첫 조건에만
#       듣는다: 조건을 차례로 관측하므로 뒤 조건은 앞 조건의 관측 시간(Vault 확인 최대 약 53 s · 조회 최대 30 s)만큼 늦게 시작하고, 그 사이 마감이
#       지나면 late(충족) · expired(미충족)다 — 뒤 조건의 실질 마감은 최악 한 라운드만큼 앞이다(두 조건 이상이 마지막 1분에 걸릴 때만 영향).
# 왜 ①이 필요한가: 시작 시각만 기준으로 폴링하면, 재부팅 명령이 실제로 먹지 않았거나(SSH 세션 문제·종료 지연) 노드가 내려가기 전의
#   몇 초 사이에 하네스(②)가 돌기 시작했을 때 API가 아직 살아 있어 reboot-0이 통과하고, 재부팅 "전"의 건강한 상태(Vault unsealed·store Ready·
#   Application Healthy)를 보고 reboot-1..4까지 PASS한다 — 재부팅 없이 PASS가 나온다. status.nodeInfo.bootID는 부팅마다 새로 생기는
#   UUID이므로, ①의 값과 달라진 것을 관측해야만 reboot-0이 충족되고 reboot-1..4는 reboot-0 통과 뒤에만 평가된다. 그래서 -AfterReboot에는
#   -BaselineBootId와 -BaselineNode가 필수이고(없거나 형식이 틀리면 폴링 없이 FAIL reboot-pre-4), -Baseline과 -AfterReboot는 함께 쓸 수 없다.
#   새 bootID만으로는 부족하다: store·ExternalSecret의 status는 재부팅 중에 바뀌지 않을 수 있어(옛 Ready·옛 refreshTime이 그대로 남음)
#   재부팅 전의 낡은 값으로 reboot-2·4가 통과할 수 있다. 그래서 reboot-0은 노드 A Ready=True까지 요구하고, 새 bootID를 처음 본 관측의
#   Ready lastHeartbeatTime(재부팅 뒤 kubelet이 쓴 서버 시각)을 부팅 anchor로 남겨 reboot-4가 그 뒤의 refresh를 요구하게 한다.
#   -BaselineNode는 role=platform 라벨이 다른 노드로 옮겨 가 "다른 노드의 bootID"를 재부팅으로 오인하는 것을 막는다.
# 시험용 손잡이(tests/scripts/reboot-tests.tests.ps1 전용 — 줄이기만 가능, -AfterReboot에서만 읽는다): 환경 변수
#   REBOOT_TESTS_PHASE_DEADLINE_SEC · REBOOT_TESTS_ES_REFRESH_SEC · REBOOT_TESTS_POLL_INTERVAL_SEC · REBOOT_TESTS_ARM_TIMEOUT_SEC.
#   값이 정수이고 1 ≤ 값 ≤ 기본값(300 · 300 · 10 · -ArmTimeoutMinutes×60 = 기본 1800)일 때만 적용하고 'note: <이름>=<값> applied …' 줄을 낸다.
#   그 밖의 값은 'note: <이름> ignored …' 줄을 내고 기본값을 쓴다.
#   적용된 값은 'polling reboot-0..4 (…)' 줄에 그대로 보인다. 실제 리허설에서는 설정하지 않는다(설정돼 있으면 note 줄로 드러난다).
# Exit 0 = FAIL 0 (PASS/SKIP만), 1 = FAIL ≥ 1 (전제 실패 포함 — fail closed). 외부 프레임워크 없음(tests/infra/tofu.tests.ps1과 같은 구조).
#
# 계약(tasks.md T034 · spec.md US2 AC4 · quickstart.md "재부팅 시나리오"):
#   reboot-pre-4  인자 계약 — -AfterReboot에는 형식이 맞는 -BaselineBootId(8-4-4-4-12 16진 UUID)와 -BaselineNode(DNS-1123 서브도메인,
#             253자 이하)가 필수, -ArmTimeoutMinutes(선택)는 정수 1..120, -Baseline과 -AfterReboot 동시 사용 금지,
#             -BaselineBootId·-BaselineNode·-ArmTimeoutMinutes는 -AfterReboot와만, 알 수 없는 인자 금지. 위반이면 kubectl을 한 번도 부르지 않고
#             FAIL + exit 1(폴링 없음). PASS 줄에는 baseline bootID와 node를
#             전부 찍는다(부팅 ID는 비밀이 아니다 — 증거 대조용). 인자를 하나도 주지 않은 평상시 실행에는 이 줄이 없다(출력 불변).
#             사용자 입력을 출력할 때는 가린(<KUBECONFIG>) 뒤 자른다.
#   reboot-baseline  (-Baseline 전용) 위 ①의 조회 판정(노드가 정확히 1개가 아니면 0개 포함 FAIL). 신원 전제(reboot-pre-3)가 실패하면
#             노드를 조회하지 않고 not attempted로 FAIL.
#   reboot-0  API 서버 도달 + 컨텍스트 사용자 = system:serviceaccount:kube-system:agent-view 이고, 라벨 role=platform 노드가 정확히 1개이며
#             그 이름이 -BaselineNode와 같고 status.nodeInfo.bootID가 -BaselineBootId와 다르며(비교는 OrdinalIgnoreCase) Ready 조건
#             status=True이고 부팅 anchor가 정해져 있다(마감 300 s, 기준점 기준 — armed 동안에는 만료되지 않고 arm 시간 제한이 대신한다).
#             bootID가 기준값과 같고 Ready=True인 관측(옛 부팅)은 미충족이면서 기준점을 그 관측의 시작으로 옮긴다(위 ③ — 재시도한 관측은 다시 한
#             호출의 시작). 기준값과 같은 bootID인데 Ready≠True는 옛 부팅이 아닌 미충족이다(C). 직전 관측이 옛 부팅이었으면 도달 실패(exit≠0, 401 아님)한
#             신원 호출 · 노드 조회를 그 자리에서 한 번 더 한다(A — 위 ③). 부팅 anchor = 새 bootID를 처음 본 관측(그 관측에 Ready 조건
#             lastHeartbeatTime이 없거나 해석할 수 없으면 다음 관측)의 lastHeartbeatTime(서버 시각, UTC) — Ready 값과 무관하고 한 번 정하면
#             유지한다(새 bootID가 status에 있다 = 그 status를 재부팅 뒤의 kubelet이 썼다 — 워크스테이션 시계는 쓰지 않는다).
#             met·PASS 줄에는 노드 이름과 baseline·새 bootID 전체를 찍는다.
#             재부팅 직후에는 API 서버가 내려가 있으므로 도달 자체를 폴링한다. 도달했는데 다른 신원이면 즉시 FAIL하고 전체를 중단한다.
#             401 Unauthorized(토큰 만료·무효)는 연속 두 번 관측되면 FAIL·전체 중단이다(첫 번째는 미충족 — 'polling …' 진행 줄에
#             "401 (1 of 2 before fatal)"; 사이에 401이 아닌 관측이 끼면 횟수는 처음부터). 둘 다 300 s 재시도는 없다(러너와 같은 fail-closed
#             신원 게이트 — 401 · 다른 신원은 A의 재시도 대상도 아니고, 도달 실패를 다시 한 호출이 그것을 보면 그 관측 하나로 센다).
#             평상시 모드·-Baseline은 한 번의 조회라 401 한 번이면 FAIL이다.
#             bootID가 baseline과 같음(아직 재부팅 전) · Ready≠True(False·Unknown·없음) · 부팅 anchor 미정 · 노드 조회 실패(exit≠0 · JSON 아님) ·
#             노드 0개 · bootID 부재/형식 불일치는 미충족(계속 폴링, 마감까지 그대로면 FAIL). JSON은 정상인데 role=platform 노드가 2개 이상이거나
#             -BaselineNode와 이름이 다르면 더 폴링하지 않고 FAIL(fail closed — 개수/이름 명시).
#   reboot-1  Vault `GET /v1/sys/seal-status` → sealed=false 그리고 type=ocikms (마감 300 s). svc/vault port-forward 경유
#             (agent-view는 vault ns pods/portforward만 있고 exec는 없다 — quickstart 45–46행). 확인 1회마다 빈 로컬 포트를
#             새로 할당해 짧게 띄우고, port-forward stdout의 "Forwarding from 127.0.0.1:<port> ->" 줄을 본 뒤에만 질의하며,
#             응답 뒤 프로세스 생존을 재확인한다(죽어 있으면 타인 리스너의 응답으로 보고 불신). 종료는 프로세스 트리째(Kill(true)).
#             확인 1회의 상한은 45 s(Forwarding 줄 대기 + 응답 대기)다: 지금의 접속 경로(워크스테이션 cloudflared access tcp 리스너 →
#             터널 → API)에서는 port-forward 수립에만 10–23 s가 걸린다(2026-10-01 실측 8회, 전부 8 s 초과 — T034 때 정한 8 s로는
#             reboot-1이 복구와 무관하게 늘 미충족이었다). tests/platform/cluster.tests.ps1은 같은 확인에 30 s를 기다린다. 여유를 더해 45 s.
#             port-forward가 곧바로 죽으면(파드·엔드포인트 없음) 기다리지 않고 바로 미충족을 돌려준다(다음 폴링에서 다시 확인).
#             detail에 그 확인에 걸린 시간을 적는다: 'forward ready in N.Ns, answered in N.Ns' · 'port-forward exited after N.Ns' ·
#             "no 'Forwarding' line after N.Ns".
#   reboot-2  ClusterSecretStore가 정확히 5개(vault-platform·vault-dev·vault-prod·vault-data·k8s-data-ca; FR-049)이고 전부
#             조건 Ready=True (마감 300 s). 이름 집합이 다르면(누락·추가) 미충족. 통과 관측에서 Ready 조건 lastTransitionTime의
#             최대값(서버 시각, UTC)을 store anchor로 기록한다(reboot-4 기준의 한 축). store anchor가 부팅 anchor보다 앞이면(= store Ready가
#             재부팅 중에 전이하지 않았다) PASS detail에 'info: store Ready did not transition after the reboot (…)'를 덧붙인다 — 판정은
#             그대로다(계약은 "5개 Ready"). 그 경우 재부팅 뒤의 증거는 reboot-4가 부팅 anchor로 요구한다.
#   reboot-3  argocd 네임스페이스의 Application 전부 status.health.status=Healthy (마감 300 s; 0개면 미충족 — task 문면은 Healthy만,
#             Synced 여부는 정보로만 출력). API 복귀 직후의 health는 Argo가 다시 평가하기 전의 값일 수 있다 — 재조정 시각
#             (status.reconciledAt)은 리허설 절차의 사후 스냅샷에서 확인한다(여기서 요구하면 재조정 주기 때문에 정상 복구가 마감을 넘길 수 있다).
#   reboot-4  ExternalSecret(전 네임스페이스, 1개 이상) 전부 조건 Ready=True/reason=SecretSynced 이고 status.refreshTime ≥ anchor,
#             anchor = max(store anchor, 부팅 anchor) (= 재부팅 뒤, 그리고 store가 Ready로 돌아온 다음 실제 refresh가 일어났다는 전이 증거 —
#             store가 옛 Ready를 그대로 갖고 있거나 ESO가 아직 돌지 않아 refreshTime이 옛 값이면 통과하지 않는다). detail에
#             'storeAnchor=… bootAnchor=… using=…'를 찍는다. 마감 = reboot-2 통과 시각 + 300 s
#             (refreshInterval 5m 표준 = 다음 refresh; 문면 정본 — Argo 등 다른 조건의 지연으로 늘어나지 않는다). reboot-2 통과
#             직후부터 폴링한다(재부팅 직후 한 번의 조회로 판정하지 않는다). reboot-2가 최종 실패(마감 초과·late)면 not attempted.
#             refreshTime·lastTransitionTime 부재/파싱 불가, store/부팅 anchor 부재는 fail-closed(FAIL).
#
# 접근 경계: $env:KUBECONFIG(agent-view 토큰)로 `kubectl auth whoami`·`kubectl get`·`kubectl port-forward`(vault ns)만 쓴다.
#   클러스터를 바꾸는 동사는 하나도 쓰지 않는다(재부팅 자체는 운영자가 수행 — 이 파일은 관찰만 한다).
#   비밀·자격·개인 경로는 출력하지 않는다: KUBECONFIG 경로가 kubectl 오류 문구에 섞여 나오면 `<KUBECONFIG>`로 치환(ordinal)한다.
# 출력: `PASS|FAIL|SKIP <id>: …` 줄(폴링 진행 줄은 두 칸 들여쓰기), 마지막 줄 `N passed, N failed, N skipped`.
#   시간 계산은 [Diagnostics.Stopwatch]. 비교는 전부 ordinal(CLAUDE.md Known Issues).
param([switch]$AfterReboot, [string]$BaselineBootId, [switch]$Baseline, [string]$BaselineNode, [string]$ArmTimeoutMinutes)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다

# ---------- 상수(계약 값) ----------
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$expectedStores = @('vault-platform', 'vault-dev', 'vault-prod', 'vault-data', 'k8s-data-ca')
$nodeSelector = 'role=platform'   # 노드 A(K3s server) 라벨 — 정확히 1개여야 한다
# 부팅 ID(UUID 8-4-4-4-12). \z로 끝을 고정한다($는 끝의 개행 앞에서도 맞는다)
$bootIdPattern = '\A[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}\z'
# 노드 이름(DNS-1123 서브도메인: 소문자 영숫자 · '-' · '.', 라벨마다 영숫자로 시작·끝, 253자 이하)
$nodeNamePattern = '\A[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*\z'
$phaseDeadlineSec = 300        # reboot-0..3 마감(시작 시각 기준)
$esRefreshSec = 300            # ExternalSecret refreshInterval 5m 표준 — reboot-4 마감 = reboot-2 통과 시각 + 이 값
$pollIntervalSec = 10          # 명목 폴링 간격(라운드 길이만큼 늘어남)
# kubectl 호출 1회 상한. 지금의 접속 경로(워크스테이션 cloudflared access tcp → 터널 → API)에서는 호출 한 번이 2–20 s 걸린다
#   (2026-10-01 실측: get applications 19.5 s(419 KB) · 10 s 근처의 실패는 TLS 핸드셰이크 시간 초과) — 10 s로는 정상 응답을 실패로 읽는다.
#   tests/platform/cluster.tests.ps1과 같은 30 s.
$kubectlTimeout = '--request-timeout=30s'
$armTimeoutMinutesDefault = 30   # -ArmTimeoutMinutes 기본값(1..120) — 하네스를 켠 뒤 재부팅을 기다리는 최대 시간(스크립트 시작 기준)
# J1: "옛 부팅이 아닌 관측"을 한 번이라도 본 뒤에는 옛 부팅을 연속 이만큼 봐야 기준점을 다시 옮긴다(재부팅 뒤 낡은 bootID 창 대비)
$rearmAfterOldBootStreak = 3
# port-forward 확인 1회당 상한(Forwarding 줄 대기 + 응답 대기). 지금의 접속 경로(워크스테이션 cloudflared access tcp → 터널 → API)에서는
#   port-forward 수립에만 10–23 s가 걸린다(2026-10-01 실측 8회, 전부 8 s 초과 — T034 때의 8 s로는 reboot-1이 복구와 무관하게 늘 미충족).
#   tests/platform/cluster.tests.ps1은 같은 확인에 30 s를 기다린다. 여유를 더해 45 s. port-forward가 곧바로 죽으면 기다리지 않는다.
$pfReadyWaitSec = 45
$pfPostResponseWaitMs = 500    # 응답 뒤 port-forward 생존 재확인 유예

$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:pf = $null             # 살아 있는 port-forward 프로세스(스크립트 종료 시 반드시 정리)
$script:pfFiles = @()          # 그 리디렉션 파일
$script:redact = @()           # 출력에서 <KUBECONFIG>로 치환할 문자열들
$script:storeAnchor = $null    # reboot-2 통과 관측의 Ready lastTransitionTime 최대값(UTC DateTime)
$script:storeAnchorReason = 'reboot-2 has not passed yet'
$script:bootAnchor = $null     # reboot-0 통과 관측의 노드 A Ready lastHeartbeatTime(UTC DateTime) — 재부팅 뒤 kubelet이 쓴 서버 시각
$script:unauthStreak = 0       # -AfterReboot reboot-0 폴링에서 연속으로 관측한 401 횟수(2회째에 fatal)
$script:baselineNodeGiven = $false   # -BaselineNode가 명시됐는지(본체에서 $PSBoundParameters로 정한다)
$script:sw = [Diagnostics.Stopwatch]::StartNew()
$script:startUtc = [DateTime]::UtcNow   # 스크립트 시작(UTC) — 기준점의 UTC 표기에만 쓴다(경과 시간은 Stopwatch)
# 0초 기준점(H2): 스크립트 시작 뒤의 초. -AfterReboot에서 옛 부팅을 볼 때마다 그 관측의 시작으로 옮긴다(armed).
$script:zero = 0.0
$script:armed = $false             # 마지막 reboot-0 관측이 옛 부팅이었는가(= 기준점이 움직이는 중)
$script:armedEver = $false         # 옛 부팅을 한 번이라도 봤는가
$script:nonOldSeen = $false        # J1: "옛 부팅이 아닌" reboot-0 관측을 한 번이라도 봤는가(그 뒤로는 연속 세 번이어야 기준점이 움직인다)
$script:oldStreak = 0              # J1: 연속으로 본 옛 부팅 관측 수(옛 부팅이 아닌 관측이 끼면 0)
$script:lastArmedLineAbs = $null   # 마지막 armed 진행 줄을 낸 시각(스크립트 시작 뒤의 초) — 최대 60초에 한 줄
$script:zeroNoted = $false         # 첫 reboot-0 관측의 기준점 줄을 냈는가
$script:armTimeoutSec = $armTimeoutMinutesDefault * 60   # arm 시간 제한(초, 스크립트 시작 기준) — 본체에서 -ArmTimeoutMinutes·손잡이로 정한다
$script:newBootSeen = $false       # B: reboot-0 관측이 기준값과 다른(형식이 맞는) bootID를 한 번이라도 봤는가
$script:retryLineAbs = $null       # A: 지금 구간에서 마지막 'retried:' 줄을 낸 시각(스크립트 시작 뒤의 초) — 기준점 상태가 바뀌면 $null(구간마다 첫 재시도에 한 줄)
$script:retriesInStretch = 0       # A: 지금 구간(기준점 상태가 마지막으로 바뀐 뒤)에서 다시 한 호출 수

function AbsNow { return [double]$script:sw.Elapsed.TotalSeconds }   # 스크립트 시작 뒤의 초
function Now { return (AbsNow) - $script:zero }                      # 기준점 뒤의 초(진행 줄·마감 판정·PASS/FAIL 줄)
function Zero-Utc { return $script:startUtc.AddSeconds($script:zero) }
# 기준점 UTC 표기(밀리초 — 불통 구간·관측 시각과 대조할 수 있게)
function Fmt-UtcMs([DateTime]$d) { return $d.ToString("yyyy-MM-dd'T'HH:mm:ss.fff'Z'", [Globalization.CultureInfo]::InvariantCulture) }
# E: 조건 상태의 마지막 관측(시작 · 끝 — 스크립트 시작 뒤의 초) → 'observation UTC <시작> .. <끝>'(밀리초)
function Format-ObsUtc($s) {
    if ($null -eq $s.obsStart -or $null -eq $s.obsEnd) { return 'observation UTC unknown' }
    return "observation UTC $(Fmt-UtcMs ($script:startUtc.AddSeconds([double]$s.obsStart))) .. $(Fmt-UtcMs ($script:startUtc.AddSeconds([double]$s.obsEnd)))"
}
function Format-ArmTimeout([int]$sec) {
    if ($sec % 60 -eq 0) { $m = [int]($sec / 60); if ($m -eq 1) { return '1 minute' }; return "$m minutes" }
    return "${sec}s"
}
# -ArmTimeoutMinutes 값 → 정수 1..120 또는 $null(부호·공백·소수·지수 없이 숫자만)
function Get-ArmMinutes([string]$s) {
    $v = 0
    if ([int]::TryParse($s, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$v) -and $v -ge 1 -and $v -le 120) { return $v }
    return $null
}
function Sec([double]$t) { return [int][Math]::Round($t) }
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function Redact([string]$s) {
    if ($null -eq $s) { return '' }
    foreach ($x in $script:redact) { if (-not [string]::IsNullOrEmpty($x)) { $s = $s.Replace($x, '<KUBECONFIG>', [StringComparison]::Ordinal) } }
    return $s
}
function Assert([string]$id, [string]$label, [bool]$cond, [string]$detail) {
    if ($cond) { $script:pass++; Write-Host "PASS ${id}: $label -- $(Redact $detail)" }
    else { $script:fail++; Write-Host "FAIL ${id}: $label -- $(Redact $detail)" }
}
function Skip([string]$id, [string]$label) {
    $script:skip++
    Write-Host "SKIP ${id}: manual trigger only (-AfterReboot) -- $label"
}
function Finish {
    Write-Host ''
    Write-Host "$($script:pass) passed, $($script:fail) failed, $($script:skip) skipped"
    if ($script:fail -gt 0) { exit 1 } else { exit 0 }
}
function Clip([string]$s, [int]$max = 300) {
    $t = ((Redact "$s") -replace '\s+', ' ').Trim()   # 자르기 전에 마스킹 — 잘린 경로 조각이 치환을 비껴가지 않게
    if ($t.Length -le $max) { return $t }
    return $t.Substring(0, $max) + '...'   # ASCII만 — CP949 콘솔에서 U+2026이 깨지지 않게
}
# 중첩 해시테이블을 안전하게 걷는다(중간에 없으면 $null). ConvertFrom-Json -AsHashtable 결과 전용.
function Get-Path($o, [string[]]$keys) {
    foreach ($k in $keys) {
        if ($null -eq $o -or -not ($o -is [System.Collections.IDictionary])) { return $null }
        $o = $o[$k]
    }
    return $o
}
function Get-ReadyCondition($item) {
    $conds = @(Get-Path $item @('status', 'conditions'))
    foreach ($c in $conds) {
        if ($c -is [System.Collections.IDictionary] -and (Eq "$($c['type'])" 'Ready')) { return $c }
    }
    return $null
}
function Sort-Ordinal([string[]]$a) {
    $arr = @($a | ForEach-Object { "$_" })
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    return $arr
}
# RFC 3339(서버 시각) → UTC DateTime; 부재·파싱 불가면 $null
function Parse-Utc([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    $d = [DateTimeOffset]::MinValue
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    if ([DateTimeOffset]::TryParse($s, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$d)) { return $d.UtcDateTime }
    return $null
}
function Fmt-Utc([DateTime]$d) { return $d.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture) }
function Fmt-Sec([double]$s) { return $s.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) + 's' }   # 경과 초(소수 한 자리, ASCII)
# 자식이 아직 쓰고 있는 리디렉션 파일을 읽는다(FileShare.ReadWrite — ReadAllText는 공유 위반으로 실패한다)
function Read-SharedText([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
    try {
        $fs = [IO.FileStream]::new($path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try { $sr = [IO.StreamReader]::new($fs, [Text.Encoding]::UTF8); return $sr.ReadToEnd() } finally { $fs.Dispose() }
    } catch { return '' }
}
function Remove-TempFiles([string[]]$paths) {
    for ($i = 1; $i -le 3; $i++) {
        $left = @()
        foreach ($p in $paths) {
            if ([string]::IsNullOrEmpty($p)) { continue }
            Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
            if (Test-Path -LiteralPath $p) { $left += $p }
        }
        if ($left.Count -eq 0) { return }
        Start-Sleep -Milliseconds 300
    }
}
# port-forward 프로세스를 트리째 종료한다(cmd/래퍼가 끼어도 손자까지)
function Stop-Tree($p) {
    if ($null -eq $p) { return }
    try { if (-not $p.HasExited) { $p.Kill($true) } } catch { }
    try { $null = $p.WaitForExit(3000) } catch { }
}
function Get-FreeLocalPort {
    $l = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $l.Start(); $port = $l.LocalEndpoint.Port; $l.Stop(); return $port
}
# 사람이 넘긴 값을 출력용으로: 먼저 가리고(Redact — 잘린 경로 조각이 치환을 비껴가지 않게) 인쇄 가능한 ASCII 밖의 문자는 '?'로,
#   그다음 길이 제한(Clip과 달리 공백을 접거나 다듬지 않는다 — 앞뒤 공백이 보여야 한다)
function Show-Arg([string]$s, [int]$max = 60) {
    $sb = [Text.StringBuilder]::new()
    foreach ($ch in (Redact "$s").ToCharArray()) { if ([int]$ch -ge 0x20 -and [int]$ch -le 0x7E) { [void]$sb.Append($ch) } else { [void]$sb.Append('?') } }
    $t = $sb.ToString()
    if ($t.Length -gt $max) { $t = $t.Substring(0, $max) + '...' }
    return $t
}
function Test-BootIdFormat($s) { return (($s -is [string]) -and [regex]::IsMatch($s, $bootIdPattern)) }
function Test-NodeNameFormat($s) { return (($s -is [string]) -and $s.Length -le 253 -and [regex]::IsMatch($s, $nodeNamePattern)) }
# 시험용 손잡이: 정수이고 1 ≤ 값 ≤ 기본값일 때만 적용(줄이기만 가능). 미설정이면 조용히 기본값, 그 밖의 값은 무시 줄 + 기본값.
function Get-TestKnob([string]$name, [int]$default) {
    $raw = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrEmpty($raw)) { return $default }
    $v = 0
    if ([int]::TryParse($raw, [Globalization.NumberStyles]::None, [Globalization.CultureInfo]::InvariantCulture, [ref]$v) -and $v -ge 1 -and $v -le $default) {
        Write-Host "note: $name=$v applied (test override, shorten-only; default $default)"
        return $v
    }
    Write-Host "note: $name ignored (must be an integer 1..$default; using default $default)"
    return $default
}
# 인자 계약(reboot-pre-4) — kubectl을 부르기 전에 판정한다. 문제가 없으면 $null, 있으면 사유.
#   $extra = 스크립트의 $args(매개변수에 묶이지 않은 인자 — 오타 스위치 등), $idGiven/$nodeGiven/$armGiven = -BaselineBootId/-BaselineNode/
#   -ArmTimeoutMinutes가 명시됐는지
function Get-ArgumentProblem([object[]]$extra, [bool]$idGiven, [bool]$nodeGiven, [bool]$armGiven) {
    $how = "run 'pwsh -NoProfile -File tests/platform/reboot.tests.ps1 -Baseline' BEFORE rebooting node A, then start '-AfterReboot -BaselineBootId <that bootID> -BaselineNode <that node>' (it waits for the reboot) and reboot node A"
    if (@($extra).Count -gt 0) { return "unexpected argument(s) [$(Show-Arg (@($extra) -join ' ') 120)]; known: -Baseline | -AfterReboot -BaselineBootId <bootID> -BaselineNode <node> [-ArmTimeoutMinutes 1..120]; refusing to guess the mode (fail closed, no polling)" }
    if ($Baseline -and $AfterReboot) { return "-Baseline and -AfterReboot are mutually exclusive: $how (no polling)" }
    if ($AfterReboot) {
        if (-not $idGiven -or [string]::IsNullOrEmpty($BaselineBootId)) { return "-AfterReboot requires -BaselineBootId: $how. Without it a cluster that never rebooted would pass (no polling)" }
        if (-not (Test-BootIdFormat $BaselineBootId)) { return "-BaselineBootId '$(Show-Arg $BaselineBootId)' is not a boot ID (expected the 8-4-4-4-12 hex UUID printed by -Baseline); $how (no polling)" }
        if (-not $nodeGiven -or [string]::IsNullOrEmpty($BaselineNode)) { return "-AfterReboot requires -BaselineNode: $how. Without it a role=platform label that moved to another node would look like a reboot (no polling)" }
        if (-not (Test-NodeNameFormat $BaselineNode)) { return "-BaselineNode '$(Show-Arg $BaselineNode)' is not a node name (DNS-1123 subdomain: lowercase a-z 0-9 '-' '.', at most 253 chars, as printed by -Baseline) (no polling)" }
        if ($armGiven -and $null -eq (Get-ArmMinutes $ArmTimeoutMinutes)) { return "-ArmTimeoutMinutes '$(Show-Arg $ArmTimeoutMinutes)' is not an integer 1..120 (minutes to wait for the reboot, counted from the script start; default $armTimeoutMinutesDefault) (no polling)" }
        return $null
    }
    if ($idGiven) { return "-BaselineBootId is only used with -AfterReboot (given without it): $how (no polling)" }
    if ($nodeGiven) { return "-BaselineNode is only used with -AfterReboot (given without it): $how (no polling)" }
    if ($armGiven) { return "-ArmTimeoutMinutes is only used with -AfterReboot (given without it): $how (no polling)" }
    return $null
}

# kubectl 실행(읽기 전용 동사만 넘긴다). stderr는 임시 파일로 받아 detail에 쓴다(러너와 같은 방식).
function Invoke-Kubectl([string[]]$kubectlArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('reboot-kubectl-' + [guid]::NewGuid().ToString('N') + '.txt')
    try {
        $lines = & kubectl @kubectlArgs 2> $errFile
        $code = $LASTEXITCODE
        $err = if (Test-Path -LiteralPath $errFile) { ([IO.File]::ReadAllText($errFile)).Trim() } else { '' }
    } finally {
        Remove-TempFiles @($errFile)
    }
    return @{ code = $code; out = (@($lines | ForEach-Object { "$_" }) -join "`n"); err = $err; cmd = "kubectl $($kubectlArgs -join ' ')" }
}
# `kubectl get … -o json` → @{ ok; items(널 제거된 배열); reason; unreachable } — items 부재는 별도 reason(fail closed)
#   unreachable(A): kubectl이 0이 아닌 코드로 끝났고 401(Unauthorized)이 아니다(도달 실패 — reboot-0의 재시도 판단에만 쓴다)
function Get-KubeItems([string[]]$kubectlArgs) {
    $r = Invoke-Kubectl $kubectlArgs
    if ($r.code -ne 0) { return @{ ok = $false; items = @(); unreachable = ($r.err.IndexOf('Unauthorized', [StringComparison]::Ordinal) -lt 0); reason = "$($r.cmd) exit=$($r.code): $(Clip $r.err)" } }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return @{ ok = $false; items = @(); reason = "$($r.cmd) produced no output" } }
    try { $obj = $r.out | ConvertFrom-Json -AsHashtable } catch { return @{ ok = $false; items = @(); reason = "$($r.cmd) output is not JSON: $(Clip $_.Exception.Message)" } }
    if ($null -eq $obj -or -not ($obj -is [System.Collections.IDictionary])) { return @{ ok = $false; items = @(); reason = "$($r.cmd) JSON root is not an object" } }
    if (-not $obj.ContainsKey('items') -or $null -eq $obj['items']) { return @{ ok = $false; items = @(); reason = "$($r.cmd) JSON has no 'items' list" } }
    $items = @($obj['items'] | Where-Object { $null -ne $_ })
    return @{ ok = $true; items = $items; reason = '' }
}

# ---------- 조건 함수: 각각 @{ ok; detail; fatal; final } 를 돌려준다 ----------
#   fatal = 더 기다려도 소용없는 거부(전체 중단), final = 이 조건만 더 폴링하지 않고 FAIL 확정
function Test-Identity {
    $r = Invoke-Kubectl @('auth', 'whoami', '-o', 'json', $kubectlTimeout)
    if ($r.code -ne 0) {
        if ($r.err.IndexOf('Unauthorized', [StringComparison]::Ordinal) -ge 0) {
            # unauthorized/cmd/err: -AfterReboot의 reboot-0이 "연속 두 번"을 판정하는 데 쓴다(평상시·-Baseline은 이 fatal을 그대로 쓴다)
            return @{ ok = $false; fatal = $true; final = $false; unauthorized = $true; cmd = $r.cmd; err = $r.err; detail = "$($r.cmd): 401 Unauthorized -- the agent-view token is expired or invalid; refusing to retry for ${phaseDeadlineSec}s (fail closed): $(Clip $r.err)" }
        }
        # unreachable(A): 401이 아닌 도달 실패(전송 실패 · 시간 초과 등) — reboot-0이 직전 관측이 옛 부팅일 때 한 번 더 할지 정하는 데 쓴다
        return @{ ok = $false; fatal = $false; final = $false; unreachable = $true; detail = "$($r.cmd) exit=$($r.code): $(Clip $r.err)" }
    }
    $u = $null
    try {
        $j = $r.out | ConvertFrom-Json -AsHashtable
        $u = [string](Get-Path $j @('status', 'userInfo', 'username'))
    } catch { $u = $null }
    if ([string]::IsNullOrWhiteSpace($u)) { return @{ ok = $false; fatal = $false; final = $false; detail = "could not parse '$($r.cmd)' output" } }
    if (-not (Eq $u $expectedUser)) {
        return @{ ok = $false; fatal = $true; final = $false; detail = "context user is '$u', expected '$expectedUser'; refusing to run with non-agent-view credentials (fail closed)" }
    }
    return @{ ok = $true; fatal = $false; final = $false; detail = "context user $u" }
}

# 노드 A(라벨 role=platform) 한 번 조회 → @{ ok; final; detail; rawName; name; bootID; ready; heartbeat }
#   ok=$false·final=$false: 조회 실패(exit≠0·출력 없음·JSON 아님·items 없음) 또는 노드 0개 — 재부팅 중에는 API가 내려가 있거나
#                           목록이 잠깐 비어 있을 수 있으므로 계속 폴링한다(-Baseline은 한 번의 조회라 그대로 FAIL)
#   ok=$false·final=$true : JSON은 정상인데 노드가 2개 이상 — 어느 노드를 볼지 추측하지 않는다(fail closed)
function Get-PlatformNode {
    $r = Get-KubeItems @('get', 'nodes', '-l', $nodeSelector, '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; final = $false; unreachable = [bool]$r.unreachable; detail = $r.reason } }
    $items = @($r.items)
    if ($items.Count -eq 0) {
        return @{ ok = $false; final = $false; detail = "$nodeSelector nodes: 0 [] -- expected exactly 1 (node A); not met (the list may be briefly empty while the API server restarts)" }
    }
    if ($items.Count -gt 1) {
        $names = @($items | ForEach-Object { "$(Get-Path $_ @('metadata', 'name'))" })
        return @{ ok = $false; final = $true; detail = "$nodeSelector nodes: $($items.Count) [$((Sort-Ordinal $names) -join ', ')] -- expected exactly 1 (node A); refusing to guess which node to watch (fail closed)" }
    }
    $node = $items[0]
    $raw = "$(Get-Path $node @('metadata', 'name'))"
    $boot = Get-Path $node @('status', 'nodeInfo', 'bootID')
    $c = Get-ReadyCondition $node
    return @{
        ok        = $true; final = $false; detail = ''
        rawName   = $raw
        name      = (Show-Arg $raw 253)
        bootID    = $(if ($boot -is [string]) { $boot } else { $null })
        ready     = $(if ($null -ne $c) { Show-Arg "$($c['status'])" 20 } else { 'none' })
        heartbeat = $(if ($null -ne $c) { Parse-Utc "$($c['lastHeartbeatTime'])" } else { $null })
    }
}

# reboot-0: 신원 그리고 노드 A가 재부팅 뒤의 kubelet으로 Ready다(= 재부팅이 실제로 일어났고 노드가 돌아왔다).
#   신원: 다른 신원 = 즉시 fatal. 401 = 연속 두 번째 관측에서 fatal(첫 번째는 미충족 — API 서버가 막 올라오는 중일 수 있다).
#         도달 실패 = 미충족. 401이 아닌 관측이 끼면 연속 횟수는 0으로 돌아간다.
#   노드: 이름이 -BaselineNode와 같아야 한다(다르면 final — 라벨이 다른 노드로 옮겨 갔다) · bootID 형식 · baseline과 다름 ·
#         Ready 조건 status=True · 부팅 anchor가 정해져 있음(새 bootID를 처음 본 관측의 Ready lastHeartbeatTime — reboot-4가 쓴다).
#         하나라도 아니면 미충족. 옛 부팅(oldBoot) = 기준값과 같은 bootID이고 Ready=True(C — Ready≠True면 옛 부팅이 아닌 미충족).
#   A: 직전 reboot-0 관측이 옛 부팅이었으면(armed, 또는 굳은 뒤 옛 부팅을 다시 세는 중 — 연속 횟수 ≥ 1) 도달 실패한 호출을 한 번만 바로 다시 한다
#      (Invoke-ReachRetry — 호출마다 한 번). 재시도한 관측은 다시 한 호출을 시작한 시각이 그 관측의 시작이다(startAt — 폴링 엔진이 옛 부팅이면
#      기준점, 충족이면 마감 판정, 그리고 UTC 표기에 쓴다). detail은 'retried:'로 시작한다(진행 줄의 120자 안에 남게).
function Test-Rebooted {
    $mayRetry = $script:armed -or ($script:oldStreak -ge 1)
    $retry = @{ whats = @(); first = @(); startAt = $null; failedAgain = $false }
    $res = Test-RebootedOnce $mayRetry $retry
    if (@($retry.whats).Count -gt 0) {
        $res.retried = $true
        $res.retryWhats = @($retry.whats)
        $res.retryFailedAgain = [bool]$retry.failedAgain
        $res.startAt = [double]$retry.startAt
        $res.detail = "retried: $($res.detail) (first attempt did not reach the API -- $($retry.first -join '; '))"
    }
    return $res
}
# A: "도달 실패"(Test-Identity · Get-KubeItems의 unreachable — kubectl이 0이 아닌 코드로 끝났고 401이 아님)이고 $mayRetry이면 그 호출을 한 번만
#    바로 다시 하고, 다시 한 호출을 시작한 시각(스크립트 시작 뒤의 초)을 $retry.startAt에 남긴다. 401 · 다른 신원 · 노드 수/이름/bootID 형식 같은
#    판정 결과는 unreachable이 아니므로 다시 하지 않는다.
function Invoke-ReachRetry([scriptblock]$call, [string]$what, [bool]$mayRetry, [hashtable]$retry) {
    $res = & $call
    if (-not ($mayRetry -and [bool]$res.unreachable)) { return $res }
    $retry.whats += $what
    $retry.first += "${what}: $(Clip $res.detail 160)"
    $retry.startAt = AbsNow
    $res = & $call
    if ([bool]$res.unreachable) { $retry.failedAgain = $true }
    return $res
}
function Test-RebootedOnce([bool]$mayRetry, [hashtable]$retry) {
    $id = Invoke-ReachRetry { Test-Identity } 'auth whoami' $mayRetry $retry
    if ($id.unauthorized) {
        $script:unauthStreak++
        if ($script:unauthStreak -lt 2) {
            return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.cmd): 401 (1 of 2 before fatal) Unauthorized -- retrying once in case the API server is still coming up: $(Clip $id.err)" }
        }
        return @{ ok = $false; fatal = $true; final = $false; detail = "$($id.cmd): 401 (2 of 2) Unauthorized on two consecutive observations -- the agent-view token is expired or invalid; refusing to retry for ${phaseDeadlineSec}s (fail closed): $(Clip $id.err)" }
    }
    $script:unauthStreak = 0
    if (-not $id.ok) { return $id }   # 다른 신원 = fatal(전체 중단), 도달 실패·해석 불가 = 미충족(계속 폴링)
    $n = Invoke-ReachRetry { Get-PlatformNode } 'get nodes' $mayRetry $retry
    if (-not $n.ok) { return @{ ok = $false; fatal = $false; final = [bool]$n.final; detail = "$($id.detail); $($n.detail)" } }
    if ($script:baselineNodeGiven -and -not (Eq $n.rawName $BaselineNode)) {
        return @{ ok = $false; fatal = $false; final = $true; detail = "$($id.detail); the $nodeSelector node is '$($n.name)', not -BaselineNode '$(Show-Arg $BaselineNode)' -- the label moved to another node; refusing to treat a different node's boot ID as a reboot (fail closed)" }
    }
    if (-not (Test-BootIdFormat $n.bootID)) {
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node $($n.name) status.nodeInfo.bootID missing or not a boot ID ('$(Show-Arg "$($n.bootID)")') -- not met" }
    }
    # 옛 부팅이 아직 보인다(API 도달 + 신원 일치 + 같은 노드 + 기준값과 같은 bootID + Ready=True) → oldBoot: 폴링 엔진이 기준점을 옮길지 정한다(H2 · J1)
    if ([string]::Equals($n.bootID, $BaselineBootId, [StringComparison]::OrdinalIgnoreCase)) {
        if (Eq $n.ready 'True') {
            return @{ ok = $false; fatal = $false; final = $false; oldBoot = $true; detail = "$($id.detail); node A has not rebooted yet (bootID unchanged): node $($n.name) bootID $($n.bootID)" }
        }
        # C: 옛 bootID인데 Ready≠True — 옛 부팅이 살아 있다고 보지 않는다(재부팅 뒤 kubelet이 끝내 status를 못 올려 저장된 status가 남은 경우).
        #    미충족이고 기준점을 옮기지 않으며 연속 횟수는 0(폴링 엔진). 사유를 앞에 둔다(진행 줄은 120자로 잘린다).
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node A ready=$($n.ready) with the baseline bootID -- not counted as the old boot being up (only Ready=True is; the status may be stale after the reboot); not met: node $($n.name) bootID $($n.bootID)" }
    }
    $script:newBootSeen = $true   # B: 기준값과 다른(형식이 맞는) bootID를 봤다
    $change = "node $($n.name) bootID $BaselineBootId -> $($n.bootID)"
    # 부팅 anchor(F2): 새 bootID를 처음 본 관측(heartbeat가 있는 첫 관측)의 Ready lastHeartbeatTime — Ready 값과 무관하고 한 번 정하면 유지한다.
    #   새 bootID가 status에 있다 = 그 status를 재부팅 뒤의 kubelet이 썼다. anchor가 이를수록 "부팅 뒤·anchor 앞"에 끼는 정상 refresh가 줄어든다.
    if ($null -eq $script:bootAnchor -and $null -ne $n.heartbeat) { $script:bootAnchor = [DateTime]$n.heartbeat }
    $anchorNote = if ($null -ne $script:bootAnchor) { "bootAnchor=$(Fmt-Utc $script:bootAnchor)" } else { 'no boot anchor yet' }
    # 미충족 사유를 앞에 둔다(진행 줄은 120자로 잘린다 — 긴 bootID 두 개 뒤로 가면 사유가 잘린다)
    if (-not (Eq $n.ready 'True')) {
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node A ready=$($n.ready), not Ready=True yet -- not met: $change; $anchorNote" }
    }
    if ($null -eq $script:bootAnchor) {
        return @{ ok = $false; fatal = $false; final = $false; detail = "$($id.detail); node A Ready lastHeartbeatTime missing/unparseable, no boot anchor yet -- not met (fail closed): $change; ready=True" }
    }
    return @{ ok = $true; fatal = $false; final = $false; detail = "$($id.detail); $change; ready=True bootAnchor=$(Fmt-Utc $script:bootAnchor) (Ready lastHeartbeatTime of the first observation with the new bootID, server time)" }
}

function Test-Vault {
    $kubectlExe = (Get-Command kubectl).Source
    $port = Get-FreeLocalPort
    $tmp = [IO.Path]::GetTempPath()
    $tag = [guid]::NewGuid().ToString('N')
    $outFile = Join-Path $tmp "reboot-pf-$tag.out.txt"
    $errFile = Join-Path $tmp "reboot-pf-$tag.err.txt"
    $marker = "Forwarding from 127.0.0.1:$port ->"
    $p = $null
    try {
        $pfArgs = @('-n', 'vault', 'port-forward', 'svc/vault', "${port}:8200", '--address', '127.0.0.1')
        try {
            $p = Start-Process -FilePath $kubectlExe -ArgumentList $pfArgs -NoNewWindow -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile
        } catch {
            return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward start failed: $(Clip $_.Exception.Message)" }
        }
        $script:pf = $p
        $script:pfFiles = @($outFile, $errFile)
        # 확인에 걸린 시간을 detail에 남긴다(G2): 느린 확인(터널 너머 수립 10–23 s)이 판정·마감과 섞여 보이지 않게
        $pfWatch = [Diagnostics.Stopwatch]::StartNew()
        $readyAt = $null
        $lastErr = 'no attempt yet'
        $forwarding = $false
        while ($pfWatch.Elapsed.TotalSeconds -lt $pfReadyWaitSec) {
            if ($p.HasExited) {
                # 곧바로 죽는 port-forward(파드·엔드포인트 없음 등)는 상한까지 기다리지 않고 바로 미충족을 돌려준다
                return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward exited after $(Fmt-Sec $pfWatch.Elapsed.TotalSeconds) (exit=$($p.ExitCode)): $(Clip (Read-SharedText $errFile))" }
            }
            if (-not $forwarding) {
                if ((Read-SharedText $outFile).IndexOf($marker, [StringComparison]::Ordinal) -ge 0) { $forwarding = $true; $readyAt = $pfWatch.Elapsed.TotalSeconds }
                else { $lastErr = "waiting for '$marker' on port-forward stdout"; Start-Sleep -Milliseconds 500; continue }
            }
            try {
                $j = Invoke-RestMethod -Uri "http://127.0.0.1:$port/v1/sys/seal-status" -Method Get -TimeoutSec 5 -NoProxy
            } catch {
                $lastErr = $_.Exception.Message
                Start-Sleep -Seconds 1
                continue
            }
            $answeredAt = $pfWatch.Elapsed.TotalSeconds
            $timing = "local port $port; forward ready in $(Fmt-Sec $readyAt), answered in $(Fmt-Sec $answeredAt)"
            # 응답 뒤 생존 재확인: 그 사이 죽었으면 응답은 우리 port-forward가 아니라 그 포트의 다른 리스너에서 온 것일 수 있다
            $null = $p.WaitForExit($pfPostResponseWaitMs)
            if ($p.HasExited) {
                return @{ ok = $false; fatal = $false; final = $false; detail = "port-forward exited right after responding (exit=$($p.ExitCode)); response on local port $port not trusted (foreign listener?) ($timing): $(Clip (Read-SharedText $errFile))" }
            }
            $sealed = $j.sealed
            $type = "$($j.type)"
            $ok = ($sealed -is [bool]) -and (-not $sealed) -and (Eq $type 'ocikms')
            return @{ ok = $ok; fatal = $false; final = $false; detail = "sealed=$sealed type=$type initialized=$($j.initialized) ($timing)" }
        }
        $why = if ($forwarding) { "forward ready in $(Fmt-Sec $readyAt), no answer by $(Fmt-Sec $pfWatch.Elapsed.TotalSeconds)" } else { "no 'Forwarding' line after $(Fmt-Sec $pfWatch.Elapsed.TotalSeconds)" }
        return @{ ok = $false; fatal = $false; final = $false; detail = "seal-status not answered within ${pfReadyWaitSec}s via port-forward (local port $port; $why): $(Clip $lastErr)" }
    } finally {
        Stop-Tree $p
        $script:pf = $null
        $script:pfFiles = @()
        Remove-TempFiles @($outFile, $errFile)
    }
}

function Test-Stores {
    $r = Get-KubeItems @('get', 'clustersecretstores.external-secrets.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $names = @()
    $ready = @()
    $notReady = @()
    $noLtt = @()
    $anchor = $null
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $names += $n
        $c = Get-ReadyCondition $it
        if ($null -ne $c -and (Eq "$($c['status'])" 'True')) {
            $ready += $n
            $ltt = Parse-Utc "$($c['lastTransitionTime'])"
            if ($null -eq $ltt) { $noLtt += $n } elseif ($null -eq $anchor -or $ltt -gt $anchor) { $anchor = $ltt }
        } else {
            $notReady += "$n(status=$(if ($null -ne $c) { "$($c['status'])" } else { 'none' }) reason=$(if ($null -ne $c) { "$($c['reason'])" } else { '-' }))"
        }
    }
    $missing = @($expectedStores | Where-Object { $e = $_; -not ($names | Where-Object { Eq $_ $e }) })
    $extra = @($names | Where-Object { $n = $_; -not ($expectedStores | Where-Object { Eq $_ $n }) })
    $ok = ($items.Count -eq $expectedStores.Count -and $missing.Count -eq 0 -and $extra.Count -eq 0 -and $notReady.Count -eq 0)
    $detail = "ready $($ready.Count)/$($expectedStores.Count) [$((Sort-Ordinal $ready) -join ', ')]"
    if ($notReady.Count -gt 0) { $detail += " notReady [$((Sort-Ordinal $notReady) -join ', ')]" }
    if ($missing.Count -gt 0) { $detail += " missing [$((Sort-Ordinal $missing) -join ', ')]" }
    if ($extra.Count -gt 0) { $detail += " unexpected [$((Sort-Ordinal $extra) -join ', ')]" }
    if ($ok) {
        if ($noLtt.Count -gt 0) {
            $script:storeAnchor = $null
            $script:storeAnchorReason = "Ready condition lastTransitionTime missing/unparseable for [$((Sort-Ordinal $noLtt) -join ', ')]"
            $detail += " readyAnchor=unavailable ($($script:storeAnchorReason))"
        } else {
            $script:storeAnchor = $anchor
            $script:storeAnchorReason = ''
            $detail += " readyAnchor=$(Fmt-Utc $anchor) (max Ready lastTransitionTime, server time)"
            # 정보만(판정 불변 — reboot-2의 계약은 "5개 Ready"): store Ready가 재부팅 중에 전이하지 않았으면 reboot-4는 부팅 anchor를 쓴다
            if ($null -ne $script:bootAnchor -and $anchor -lt [DateTime]$script:bootAnchor) {
                $detail += " info: store Ready did not transition after the reboot (readyAnchor $(Fmt-Utc $anchor) < bootAnchor $(Fmt-Utc $script:bootAnchor))"
            }
        }
    }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

function Test-Argo {
    $r = Get-KubeItems @('-n', 'argocd', 'get', 'applications.argoproj.io', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $unhealthy = @()
    $outOfSync = @()
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'name'))"
        $h = "$(Get-Path $it @('status', 'health', 'status'))"
        $s = "$(Get-Path $it @('status', 'sync', 'status'))"
        if (-not (Eq $h 'Healthy')) { $unhealthy += "$n=$(if ($h) { $h } else { 'none' })" }
        if (-not (Eq $s 'Synced')) { $outOfSync += "$n=$(if ($s) { $s } else { 'none' })" }
    }
    $ok = ($items.Count -ge 1 -and $unhealthy.Count -eq 0)
    $detail = "applications $($items.Count), healthy $($items.Count - $unhealthy.Count)"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($unhealthy.Count -gt 0) { $detail += " notHealthy [$((Sort-Ordinal $unhealthy) -join ', ')]" }
    if ($outOfSync.Count -gt 0) { $detail += " info: notSynced [$((Sort-Ordinal $outOfSync) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

function Test-ExternalSecrets {
    if ($null -eq $script:storeAnchor) {
        return @{ ok = $false; fatal = $false; final = $true; detail = "store Ready anchor unavailable ($($script:storeAnchorReason)); cannot prove a post-reboot refresh (fail closed)" }
    }
    if ($null -eq $script:bootAnchor) {
        return @{ ok = $false; fatal = $false; final = $true; detail = 'boot anchor unavailable (reboot-0 did not record node A Ready lastHeartbeatTime); cannot prove a post-reboot refresh (fail closed)' }
    }
    # anchor = max(store anchor, 부팅 anchor): store Ready가 재부팅 중에 전이하지 않았어도(옛 Ready가 남음) 재부팅 뒤의 refresh를 요구한다
    $storeA = [DateTime]$script:storeAnchor
    $bootA = [DateTime]$script:bootAnchor
    if ($bootA -gt $storeA) { $anchor = $bootA; $using = 'bootAnchor' } else { $anchor = $storeA; $using = 'storeAnchor' }
    $anchors = "storeAnchor=$(Fmt-Utc $storeA) bootAnchor=$(Fmt-Utc $bootA) using=$using"
    $r = Get-KubeItems @('get', 'externalsecrets.external-secrets.io', '-A', '-o', 'json', $kubectlTimeout)
    if (-not $r.ok) { return @{ ok = $false; fatal = $false; final = $false; detail = $r.reason } }
    $items = @($r.items)
    $notSynced = @()
    $noRefresh = @()
    $stale = @()
    $fresh = 0
    foreach ($it in $items) {
        $n = "$(Get-Path $it @('metadata', 'namespace'))/$(Get-Path $it @('metadata', 'name'))"
        $c = Get-ReadyCondition $it
        $synced = ($null -ne $c -and (Eq "$($c['status'])" 'True') -and (Eq "$($c['reason'])" 'SecretSynced'))
        if (-not $synced) { $notSynced += "$n=$(if ($null -ne $c) { "$($c['reason'])/$($c['status'])" } else { 'none' })"; continue }
        $rt = Parse-Utc "$(Get-Path $it @('status', 'refreshTime'))"
        if ($null -eq $rt) { $noRefresh += $n }
        elseif ($rt -lt $anchor) { $stale += "$n=refreshTime $(Fmt-Utc $rt)" }
        else { $fresh++ }
    }
    $ok = ($items.Count -ge 1 -and $notSynced.Count -eq 0 -and $noRefresh.Count -eq 0 -and $stale.Count -eq 0)
    $detail = "externalsecrets $($items.Count), SecretSynced $($items.Count - $notSynced.Count), refreshed since anchor $(Fmt-Utc $anchor): $fresh ($anchors)"
    if ($items.Count -eq 0) { $detail += ' (none found -- not met)' }
    if ($notSynced.Count -gt 0) { $detail += " notSynced [$((Sort-Ordinal $notSynced) -join ', ')]" }
    if ($noRefresh.Count -gt 0) { $detail += " refreshTime missing/unparseable [$((Sort-Ordinal $noRefresh) -join ', ')]" }
    if ($stale.Count -gt 0) { $detail += " refreshTime before anchor [$((Sort-Ordinal $stale) -join ', ')]" }
    return @{ ok = $ok; fatal = $false; final = $false; detail = $detail }
}

# A: 기준점 상태(armed ↔ 굳음)가 바뀌면 'retried:' 줄의 절제를 처음부터 센다(구간마다 첫 재시도에 한 줄)
function Reset-RetryStretch { $script:retryLineAbs = $null; $script:retriesInStretch = 0 }
# A: 재시도한 관측 → 구간마다 첫 재시도에 한 줄, 그 뒤로는 최대 60초에 한 줄(armed 줄과 같은 절제 — 재시도마다 찍지 않는다)
function Write-RetryLine($r, [double]$abs) {
    $script:retriesInStretch += @($r.retryWhats).Count
    if ($null -ne $script:retryLineAbs -and ($abs - $script:retryLineAbs) -lt 60) { return }
    $outcome = if ($r.oldBoot) { 'the retry saw the old boot' } elseif ($r.retryFailedAgain) { 'the retry did not reach the API either' } else { 'the retry reached the API' }
    Write-Host "  retried: $(@($r.retryWhats) -join ' and ') did not reach the API right after an old-boot observation -- retried once at once; $outcome (retried calls in this stretch: $($script:retriesInStretch))"
    $script:retryLineAbs = $abs
}

# ---------- 폴링 엔진(조건별 마감) ----------
# $conds 원소: @{ id; label; test=[scriptblock] → @{ok; detail; fatal; final}; after=<선행 id 또는 $null>; deadline=[scriptblock]($state) → 초 }
# 반환: id → @{ verdict; at(관측이 끝난 시각); startedAt(그 관측을 시작한 시각); deadline; detail; checks;
#   obsStart · obsEnd(마지막 관측의 시작 · 끝 — 스크립트 시작 뒤의 초, E); lastOldBoot(reboot-0의 마지막 관측이 옛 부팅이었는가 — B) }
#   verdict: pending | ok | late(마감 뒤에 시작한 관측의 충족) | expired(마감까지 미충족) | final(재폴링 무의미한 FAIL) | fatal | not-attempted
#   마감 판정(F1): 충족은 관측을 "시작한" 시각으로, 미충족은 관측이 "끝난" 시각으로 본다 — 마감 안에 시작한 관측이 충족이면 통과다
#   (kubectl 호출이 끝나는 시각으로 보면 마감에 맞춰 줄인 마지막 관측은 늘 마감 뒤에 끝나 정상 복구가 late가 된다).
#   재시도한 reboot-0 관측(A)은 다시 한 호출을 시작한 시각($r.startAt)이 그 관측의 시작이다 — 기준점 · 충족의 마감 판정 · UTC 표기가 같은 시각을 쓴다
#   (재시도가 마감 뒤에 시작해 충족을 보면 late다 — 첫 시도 앞의 시각으로 보면 마감 뒤에 모은 증거로 통과하게 된다).
function Invoke-PollLoop([object[]]$conds) {
    $state = @{}
    foreach ($c in $conds) { $state[$c.id] = @{ verdict = 'pending'; at = $null; startedAt = $null; deadline = $null; detail = 'not checked'; checks = 0; obsStart = $null; obsEnd = $null; lastOldBoot = $false } }
    while ($true) {
        foreach ($c in $conds) {
            $s = $state[$c.id]
            if (-not (Eq $s.verdict 'pending')) { continue }
            if ($null -ne $c.after) {
                $a = $state[$c.after]
                if (Eq $a.verdict 'pending') { continue }                                   # 선행 조건 대기(마감도 아직 미정)
                if (-not (Eq $a.verdict 'ok')) { $s.verdict = 'not-attempted'; $s.detail = "$($c.after) $($a.verdict)"; continue }
            }
            if ($null -eq $s.deadline) { $s.deadline = [double](& $c.deadline $state) }
            $a0 = AbsNow                                                                      # 관측 시작(스크립트 시작 뒤의 초)
            $r = & $c.test
            $aEnd = AbsNow                                                                    # 관측이 끝난 시각(스크립트 시작 뒤의 초)
            # 관측의 시작: 보통은 a0, 재시도한 reboot-0 관측은 다시 한 호출의 시작(A)
            $aStart = if ($null -ne $r.startAt) { [double]$r.startAt } else { $a0 }
            $t0 = $aStart - $script:zero                                                      # 관측 시작(기준점 뒤의 초 — 충족의 마감 판정 기준)
            $s.checks++
            $s.detail = [string]$r.detail
            $s.obsStart = $aStart                                                             # E: 마지막 관측의 시작 · 끝(줄에는 UTC 밀리초로)
            $s.obsEnd = $aEnd
            if (Eq $c.id 'reboot-0') { $s.lastOldBoot = [bool]$r.oldBoot }                    # B: 마지막 관측이 옛 부팅이었는가
            if ($r.retried) { Write-RetryLine $r $aEnd }                                      # A: 구간마다 첫 재시도에 한 줄(그 뒤 최대 60초에 한 줄)
            # J1: 옛 부팅 관측이 기준점을 옮기는가 — "옛 부팅이 아닌 관측"을 한 번도 못 봤으면 매번, 본 뒤에는 연속 세 번째부터
            $movesZero = $false
            if ($r.oldBoot) {
                $script:oldStreak++
                $movesZero = (-not $script:nonOldSeen) -or ($script:oldStreak -ge $rearmAfterOldBootStreak)
            }
            if ($movesZero) {
                # H2: 옛 부팅이 아직 살아 있다 → 기준점을 이 관측의 시작으로 옮긴다(armed — 재시도한 관측이면 다시 한 호출의 시작, A). armed 동안에는
                #     reboot-0의 마감이 만료되지 않는다(기준점이 계속 움직인다) — 스크립트 시작 기준의 arm 시간 제한이 그 자리를 맡는다(F: 기준점이
                #     움직이는 이 자리에서만 판정한다 — 굳어 있는 동안에는 판정하지 않는다).
                $wasArmed = $script:armed
                $script:zero = $aStart
                $script:armed = $true
                $script:armedEver = $true
                if (-not $wasArmed) { Reset-RetryStretch }                                    # A: 구간이 바뀐다(굳음 → armed)
                $abs = AbsNow
                if ($abs -ge $script:armTimeoutSec) {
                    $s.verdict = 'final'
                    $s.at = Now
                    $s.detail = "no reboot observed within $(Format-ArmTimeout $script:armTimeoutSec) (node A kept reporting the baseline bootID $BaselineBootId; $(Fmt-Sec $abs) after the script start)"
                    continue
                }
                if (-not $wasArmed -and $script:nonOldSeen) {
                    # J1: 굳었던 기준점이 연속 세 번째 옛 부팅 관측에서 다시 움직인다 — 일시적인 호출 실패로 본다(재부팅 뒤의 낡은 bootID 창은
                    #     폴링 간격 둘 이상에 걸친 연속 세 번을 채우지 못한다고 본다 — 머리 주석 ③)
                    Write-Host "  note: the old boot was seen $rearmAfterOldBootStreak times in a row after the zero point had been fixed -- the zero point moves again (treated as a transient call failure, not a reboot)"
                }
                if (-not $wasArmed -or $null -eq $script:lastArmedLineAbs -or ($abs - $script:lastArmedLineAbs) -ge 60) {
                    $rem = $script:armTimeoutSec - $abs
                    $remText = if ($rem -ge 60) { "$([int][Math]::Ceiling($rem / 60))m" } else { "$([int][Math]::Ceiling($rem))s" }
                    Write-Host "  armed: old boot still up (bootID unchanged) -- zero point moves with each observation; waiting for the reboot (arm timeout in $remText)"
                    $script:lastArmedLineAbs = $abs
                }
                continue
            }
            if ($r.oldBoot) {
                # J1: 옛 부팅이지만 아직 연속 세 번이 아니다 — 기준점은 그대로(재부팅 뒤 API가 먼저 돌아와 낡은 bootID를 보여 주는 창일 수 있다).
                #     구간마다 한 줄만 내고, 판정은 굳은 기준점에서 센 마감으로 하는 보통의 미충족 관측이다.
                if ($script:oldStreak -eq 1) {
                    Write-Host "  old boot seen again after the zero point was fixed (1 of $rearmAfterOldBootStreak needed to move it again); zero point stays at $(Fmt-UtcMs (Zero-Utc))"
                }
            } elseif (Eq $c.id 'reboot-0') {
                # 옛 부팅이 아닌 관측(API 불통 · 호출 실패 · 새 bootID · 그 밖의 미충족): 연속 횟수는 0, 이후의 재무장은 연속 세 번부터
                $script:nonOldSeen = $true
                $script:oldStreak = 0
                if ($script:armed) {
                    # armed 뒤 첫 "옛 부팅이 아닌" 관측: 기준점이 마지막으로 옛 부팅을 본 관측에 굳는다
                    $script:armed = $false
                    Reset-RetryStretch                                                        # A: 구간이 바뀐다(armed → 굳음)
                    Write-Host "  zero point fixed at $(Fmt-UtcMs (Zero-Utc)) (last observation of the old boot); deadlines count from here"
                } elseif (-not $script:armedEver -and -not $script:zeroNoted) {
                    Write-Host '  zero point = script start (the old boot was never observed)'
                }
                $script:zeroNoted = $true
            }
            $t = $aEnd - $script:zero                                                         # 관측이 끝난 시각(기록·미충족의 마감 판정 기준)
            if ($r.fatal) { $s.verdict = 'fatal'; $s.at = $t; return $state }
            if ($r.ok) {
                $s.at = $t
                $s.startedAt = $t0
                # E: met 진행 줄에 그 관측의 시작 · 끝 UTC(밀리초)를 함께 적는다(경과 초 표기는 그대로)
                if ($t0 -le $s.deadline) { $s.verdict = 'ok'; Write-Host "  [$(Sec $t)s] $($c.id) met -- $(Format-ObsUtc $s); $(Redact (Clip $r.detail 200))" }
                else { $s.verdict = 'late'; Write-Host "  [$(Sec $t)s] $($c.id) observed met by an observation that started AFTER its deadline ($(Sec $t0)s > $(Sec $s.deadline)s) -- $(Format-ObsUtc $s); $(Redact (Clip $r.detail 200))" }
            } elseif ($r.final) { $s.verdict = 'final'; $s.at = $t }
            elseif ($t -gt $s.deadline) { $s.verdict = 'expired'; $s.at = $t }
        }
        $pending = @($conds | Where-Object { Eq $state[$_.id].verdict 'pending' })
        if ($pending.Count -eq 0) { return $state }
        $now = Now
        $nextDeadline = $null
        $parts = @()
        foreach ($c in $pending) {
            $s = $state[$c.id]
            if ($null -eq $s.deadline) { $parts += "$($c.id)(blocked by $($c.after))"; continue }
            if ($null -eq $nextDeadline -or $s.deadline -lt $nextDeadline) { $nextDeadline = $s.deadline }
            $parts += "$($c.id)(deadline $(Sec $s.deadline)s: $(Redact (Clip $s.detail 120)))"
        }
        if (-not $script:armed) { Write-Host "  [$(Sec $now)s] waiting: $($parts -join '; ')" }   # armed 동안은 armed 줄(최대 60초에 한 줄)이 대신한다
        $sleep = [double]$pollIntervalSec
        # 마감 직전의 대기는 마감 1초 전에 끝낸다(마지막 관측이 마감 안에서 시작하게). 1초도 안 남았으면 자지 않고 바로 관측한다.
        if ($null -ne $nextDeadline) { $sleep = [Math]::Min($sleep, [Math]::Max(0.0, $nextDeadline - $now - 1.0)) }
        if ($sleep -gt 0) { Start-Sleep -Milliseconds ([int][Math]::Ceiling($sleep * 1000)) }
    }
}

# ---------- 본체 ----------
try {
    $mode = 'normal (runner path; reboot-1..4 skipped)'
    if ($Baseline -and $AfterReboot) { $mode = 'invalid (-Baseline with -AfterReboot)' }
    elseif ($Baseline) { $mode = 'baseline (record node A bootID before the reboot; read-only, no polling)' }
    elseif ($AfterReboot) { $mode = 'after-reboot (manual trigger)' }
    Write-Host "reboot.tests.ps1: mode=$mode start=$([DateTime]::Now.ToString('yyyy-MM-ddTHH:mm:sszzz'))"

    # 전제(항상, fail-closed): kubectl · KUBECONFIG(단일 파일 경로; 상대 경로는 PSPath로 해석 — CLAUDE.md Known Issues)
    $hasKubectl = $null -ne (Get-Command kubectl -ErrorAction SilentlyContinue)
    Assert 'reboot-pre-1' 'kubectl on PATH' $hasKubectl $(if ($hasKubectl) { 'found' } else { 'kubectl not found on PATH; cannot observe the cluster (fail closed)' })
    $kubeconfigOk = $false
    $kubeconfigWhy = 'found'
    if ([string]::IsNullOrWhiteSpace($env:KUBECONFIG)) { $kubeconfigWhy = 'KUBECONFIG is not set; an agent-view kubeconfig is required (fail closed)' }
    else {
        $kubeconfigPath = $null
        try { $kubeconfigPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($env:KUBECONFIG) } catch { $kubeconfigPath = $null }
        if ($kubeconfigPath -and (Test-Path -LiteralPath $kubeconfigPath -PathType Leaf)) { $kubeconfigOk = $true }
        else { $kubeconfigWhy = 'KUBECONFIG file not found (path not printed; single file path only)' }
        # 출력 마스킹 대상: 원문·해석 경로와 슬래시 방향 변형
        foreach ($v in @($env:KUBECONFIG, $kubeconfigPath)) {
            if ([string]::IsNullOrWhiteSpace($v)) { continue }
            $script:redact += $v
            $script:redact += $v.Replace('\', '/')
            $script:redact += $v.Replace('/', '\')
        }
    }
    Assert 'reboot-pre-2' 'KUBECONFIG set and file exists' $kubeconfigOk $kubeconfigWhy
    # reboot-pre-4: 인자 계약 — kubectl을 한 번도 부르기 전에 판정한다. 인자 없는 평상시 실행에는 이 줄을 내지 않는다(출력 불변).
    $script:baselineNodeGiven = $PSBoundParameters.ContainsKey('BaselineNode')
    $armGiven = $PSBoundParameters.ContainsKey('ArmTimeoutMinutes')
    $argProblem = Get-ArgumentProblem $args $PSBoundParameters.ContainsKey('BaselineBootId') $script:baselineNodeGiven $armGiven
    $armMinutes = $armTimeoutMinutesDefault
    if ($armGiven -and $null -eq $argProblem) { $armMinutes = Get-ArmMinutes $ArmTimeoutMinutes }
    if ($AfterReboot -or $null -ne $argProblem) {
        $argDetail = $argProblem
        if ($null -eq $argProblem) {
            $argDetail = "baseline bootID $BaselineBootId; node A must report a different one"
            if ($script:baselineNodeGiven) { $argDetail += "; baseline node $BaselineNode (the $nodeSelector node must be this one)" }
            # F: arm 시간 제한은 기준점이 움직이는 관측에서만 판정된다(굳어 있는 동안에는 판정하지 않는다 — 머리 주석 ③)
            $argDetail += "; waits up to $(Format-ArmTimeout ($armMinutes * 60)) for the reboot (-ArmTimeoutMinutes; judged only on observations that move the zero point, not while it is fixed)"
        }
        Assert 'reboot-pre-4' 'arguments (-Baseline | -AfterReboot -BaselineBootId <bootID> -BaselineNode <node>, both recorded by -Baseline)' ($null -eq $argProblem) $argDetail
    }
    if ($script:fail -gt 0) { Finish }

    if ($Baseline) {
        # ① 재부팅 전 기준값: 신원 1회 + 노드 A 1회 조회(폴링 없음). 성공 시 'baseline: …' 한 줄.
        $blLabel = "node A ($nodeSelector) bootID recorded"
        $idr = Test-Identity
        Assert 'reboot-pre-3' "context user is $expectedUser" ([bool]$idr.ok) $idr.detail
        if (-not $idr.ok) { Assert 'reboot-baseline' $blLabel $false 'not attempted (reboot-pre-3 failed; the identity precondition is fail closed)'; Finish }
        $n = Get-PlatformNode
        if (-not $n.ok) { Assert 'reboot-baseline' $blLabel $false $n.detail; Finish }
        if (-not (Test-BootIdFormat $n.bootID)) { Assert 'reboot-baseline' $blLabel $false "node $($n.name) status.nodeInfo.bootID missing or not a boot ID ('$(Show-Arg "$($n.bootID)")')"; Finish }
        Write-Host "baseline: node=$($n.name) bootID=$($n.bootID) ready=$($n.ready)"
        Finish
    }

    if ($AfterReboot) {
        # 시험용 손잡이(줄이기만 가능) — 적용·무시 모두 note 줄로 드러나고, 적용 값은 아래 polling 줄과 라벨에 그대로 보인다
        $phaseDeadlineSec = Get-TestKnob 'REBOOT_TESTS_PHASE_DEADLINE_SEC' $phaseDeadlineSec
        $esRefreshSec = Get-TestKnob 'REBOOT_TESTS_ES_REFRESH_SEC' $esRefreshSec
        $pollIntervalSec = Get-TestKnob 'REBOOT_TESTS_POLL_INTERVAL_SEC' $pollIntervalSec
        $script:armTimeoutSec = Get-TestKnob 'REBOOT_TESTS_ARM_TIMEOUT_SEC' ($armMinutes * 60)
    }

    $fixed = { param($st) $phaseDeadlineSec }
    # reboot-4 라벨: 평상시 SKIP 줄은 그대로(출력 불변), -AfterReboot에서는 실제 기준(max(store, 부팅 anchor))을 적는다
    $r4Label = "externalsecrets all SecretSynced with refreshTime >= store Ready anchor, within ${esRefreshSec}s after reboot-2"
    if ($AfterReboot) { $r4Label = "externalsecrets all SecretSynced with refreshTime >= max(store Ready anchor, boot anchor), within ${esRefreshSec}s after reboot-2" }
    $conds = @(
        @{ id = 'reboot-0'; label = "API reachable, context user is $expectedUser, node A ($nodeSelector) bootID differs from -BaselineBootId and node A Ready=True"; test = { Test-Rebooted }; after = $null; deadline = $fixed },
        @{ id = 'reboot-1'; label = 'vault seal-status sealed=false type=ocikms (port-forward svc/vault)'; test = { Test-Vault }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-2'; label = "clustersecretstores exactly 5 and all Ready [$($expectedStores -join ', ')]"; test = { Test-Stores }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-3'; label = 'argocd applications all Healthy'; test = { Test-Argo }; after = 'reboot-0'; deadline = $fixed },
        @{ id = 'reboot-4'; label = $r4Label; test = { Test-ExternalSecrets }; after = 'reboot-2'; deadline = { param($st) $st['reboot-2'].at + $esRefreshSec } }
    )

    if (-not $AfterReboot) {
        # 평상시: 신원은 한 번만 확인(러너가 이미 통과시켰지만 단독 실행도 같은 경계를 지킨다), 재부팅 단언은 SKIP.
        $idr = Test-Identity
        Assert 'reboot-pre-3' "context user is $expectedUser" ([bool]$idr.ok) $idr.detail
        foreach ($c in $conds) { if (-not (Eq $c.id 'reboot-0')) { Skip $c.id $c.label } }
        Finish
    }

    Write-Host "polling reboot-0..4 (nominal interval ${pollIntervalSec}s; reboot-0..3 deadline ${phaseDeadlineSec}s from the zero point; reboot-4 deadline = reboot-2 pass + ${esRefreshSec}s; arm timeout $(Format-ArmTimeout $script:armTimeoutSec))"
    $st = Invoke-PollLoop $conds
    $fatalId = $null
    foreach ($c in $conds) { if (Eq $st[$c.id].verdict 'fatal') { $fatalId = $c.id } }
    # 0초 기준점의 근거(H2) — 끝의 요약 줄과 B의 FAIL 문구에 쓴다
    $zeroWhy = if ($script:armedEver) { 'last observation of the old boot' } else { 'script start' }
    foreach ($c in $conds) {
        $s = $st[$c.id]
        $rel = ''
        if ($null -ne $c.after -and $null -ne $s.at -and (Eq $st[$c.after].verdict 'ok')) { $rel = " (+$(Sec ($s.at - $st[$c.after].at))s after $($c.after))" }
        # E: 관측이 있는 PASS/FAIL 줄에는 그 관측의 시작 · 끝 UTC(밀리초)를 함께 적는다(경과 초 표기는 그대로)
        switch ($s.verdict) {
            'ok' {
                # 마감 안에 시작해 마감을 넘겨 끝난 관측이면 그 사실을 드러낸다
                $when = if ($s.at -gt $s.deadline) { "met at $(Sec $s.at)s (observation started at $(Sec $s.startedAt)s, deadline $(Sec $s.deadline)s)" } else { "met at $(Sec $s.at)s (deadline $(Sec $s.deadline)s)" }
                Assert $c.id $c.label $true "$when$rel; $(Format-ObsUtc $s); $($s.detail)"
            }
            'late' { Assert $c.id $c.label $false "met late at $(Sec $s.at)s (observation started at $(Sec $s.startedAt)s, after the deadline $(Sec $s.deadline)s)$rel; $(Format-ObsUtc $s); $($s.detail)" }
            'expired' {
                $why = "not met within $(Sec $s.deadline)s (last observation at $(Sec $s.at)s, $(Format-ObsUtc $s): $($s.detail))"
                # B: 새 bootID를 한 번도 못 봤고 마지막 관측이 옛 부팅 — 굳은 기준점이 연속 세 번을 채우지 못한 채 재부팅 전에 마감이 지났다(판정 · 종료 코드는 그대로)
                if ((Eq $c.id 'reboot-0') -and -not $script:newBootSeen -and [bool]$s.lastOldBoot) {
                    $why += "; zero point fixed at $(Fmt-UtcMs (Zero-Utc)) ($zeroWhy); the old boot kept being seen after that but never $rearmAfterOldBootStreak times in a row -- no reboot was observed; restart the harness"
                }
                Assert $c.id $c.label $false $why
            }
            'final' { Assert $c.id $c.label $false "$($s.detail) (at $(Sec $s.at)s; $(Format-ObsUtc $s))" }
            'fatal' { Assert $c.id $c.label $false "$($s.detail) ($(Format-ObsUtc $s))" }
            'not-attempted' { Assert $c.id $c.label $false "not attempted ($($s.detail))" }
            default { Assert $c.id $c.label $false "not attempted (aborted by $fatalId)" }
        }
    }
    Write-Host "polling ended at $(Sec (Now))s"
    # 0초 기준점을 끝에 한 번 더 적는다(H2 — 경과 초는 전부 이 시각 기준이다)
    Write-Host "zero point (UTC): $(Fmt-UtcMs (Zero-Utc)) ($zeroWhy)"
    Finish
} finally {
    if ($null -ne $script:pf) {
        Stop-Tree $script:pf
        Remove-TempFiles $script:pfFiles
    }
}
