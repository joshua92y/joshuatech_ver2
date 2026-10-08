# tests/platform/kafka.tests.ps1 — US3 Kafka(Strimzi) · Dragonfly · 검사 Job 로그 단언 (T051, test-first)
# Run: $env:KUBECONFIG=<agent-view 토큰 kubeconfig>; pwsh -NoProfile -File tests/platform/kafka.tests.ps1
#      (보통은 tests/platform/run-platform-tests.ps1이 agent-view 신원 게이트를 지난 뒤 tests/platform/*.tests.ps1을 차례로 실행한다)
# Exit 0 = 실패 0, 1 = 실패 ≥ 1. 외부 프레임워크 없음 — 자체 완결(헬퍼는 tests/platform/cluster.tests.ps1에서 필요한 것만 복사했고 절 머리에
#   출처를 적었다). 출력: 항목별 `PASS|FAIL <id>: …` 한 줄, 마지막 줄 `N passed, N failed, N skipped`.
#   이 파일에는 SKIP 경로가 없다(skipped는 항상 0 — 요약 줄 모양만 cluster.tests.ps1과 같게 둔다). 단언 본문이 'SKIP'을 돌려주면
#   하네스 버그로 보고 FAIL한다(fail closed).
#
# 지금 상태(T051 작성 시점 2026-10-07): Strimzi 오퍼레이터 · Kafka(T055), KafkaTopic · KafkaUser(T056), Dragonfly(T057)가 아직 없고
#   검사 Job(gitops platform/policies/tests — data-assert · kafka-assert)도 Argo CD Application이 없어 배포 전이다. 그래서 게이트 3개를 뺀
#   14개 단언은 전부 FAIL이 기대값이다(과제 줄 "FAIL 확인"). T055–T057이 끝나면 PASS 후보가 된다.
#   data-assert의 Dragonfly 검사 id 가운데 noauth · writer-set · reader-get · reader-set-denied · reader-cross-denied 다섯은 지금 Job에 없다
#   (Job에 더하는 것은 T057 슬라이스 — 컨트롤러 결정). Job이 배포된 뒤에도 그때까지 job-d-2는 "the Job does not emit these check ids yet"으로 FAIL한다.
#
# 접근 계약(contracts/hostnames-and-access.md §에이전트 자격 — cluster.tests.ps1과 같다):
#   - `$env:KUBECONFIG`(SA `agent-view` 8h 토큰)로만 접근한다. 미설정 · 파일 없음 · kubectl 부재 · whoami ≠ agent-view는 전부 FAIL(fail closed)
#     — 모든 kubectl 호출에 --kubeconfig를 명시한다(기본 kubeconfig로 흘러가지 않게).
#   - 사용하는 동사는 kubectl get / logs / auth whoami 뿐이다(exec · port-forward · 생성 · 변경 동사 없음).
#   - Secret 값은 읽지 않는다: KafkaUser의 비밀번호 Secret · Dragonfly aclfile Secret은 이름만 본다(status.secret). kcat · redis-cli처럼 자격이
#     필요한 검사는 클러스터 안 Job 로그로 읽는다(R30): `kubectl -n jt-dev logs job/kafka-assert` · `job/data-assert` --tail=50.
#   - 비밀 · 토큰 · kubeconfig 내용 · 개인 경로는 출력하지 않는다. 네이티브 stdout/stderr는 반환 전에 kubeconfig 경로 → <KUBECONFIG>, 홈 → ~ 로
#     마스킹한다(Mask-Text, ordinal). data-assert의 `EVIDENCE:` 줄(ACL LIST — 비밀번호 해시는 Job이 지운 뒤)은 읽기만 하고 내용은 출력하지 않는다
#     (job-d-2 사유에는 패턴 유무만 적는다).
#   - 임시 파일(stderr 리다이렉트)은 호출마다 재시도 삭제한다 — %TEMP%\kafka-tests-* 잔존 0.
#   - agent-view RBAC(라이브 전제): gitops platform/policies/rbac-agent-view.yaml의 ClusterRole agent-view-extra가 nodes와 kafka.strimzi.io resources "*"
#     (get/list/watch)를 주고, 기본 view ClusterRole(aggregate-to-view)이 pods · pods/log · services · deployments.apps · jobs.batch를 준다(준수 리뷰가
#     gitops main f1631d9 66–68 · 83–85행으로 확인, 2026-10-08) — 이 파일의 조회는 전부 덮인다(T055가 더할 리소스 없음). 라이브 ClusterRole이 main과
#     같은지는 T055 뒤 `kubectl auth can-i list kafkas.kafka.strimzi.io -n data`(agent-view)로 확인한다.
#
# 판정 규칙: 문자열 비교는 전부 ordinal. 조회마다 예외를 잡아 그 단언의 사유로 바꾼다(설계 D3) — Strimzi 리소스 타입이 없으면
#   "CRD <plural>.kafka.strimzi.io not installed (T055)", Deployment · Service 없음은 "(T057)", KafkaTopic · KafkaUser 없음은 "(T056)",
#   검사 Job 없음은 "platform/policies/tests not deployed yet (after T055-T057), or the Job was removed by ttlSecondsAfterFinished=7d -- re-run it"
#   (두 Job 모두 ttlSecondsAfterFinished=604800 이라 성공 7일 뒤 지워진다 — T059 뒤 재실행 전에는 '배포 전'이 아니라 'TTL로 삭제됨 · 재실행').
#   같은 조회를 여러 단언이 쓰므로 결과(오류 포함)를 캐시한다 — 조회 오류는 그 조회를 쓰는 단언마다 같은 사유로 보고된다.
#   사유는 한 줄에 전부 모은다(여러 항목을 보는 단언은 줄 상한 1000자, 나머지 400자).
#   조건(status.conditions[type=X])은 같은 type이 둘 이상이면 모호한 것으로 보고 FAIL한다(fail closed — Condition 함수가 status에
#   "ambiguous: <n> X conditions [a, b]"를 적어 호출 측이 FAIL한다; 배열 순서에 판정이 좌우되지 않는다).
#   표기 정확 일치(선언값 그대로): sync-options 순서 · auto.create.topics.enable "false" 소문자 · --maxmemory=768mb 소문자 등은 ordinal 정확 일치라
#   대소문자 · 순서가 다르면 FAIL — T055 · T057 구현자는 선언 표기를 그대로 쓴다. 숫자 필드(port · partitions · replicas · succeeded · grace ·
#   availableReplicas)는 숫자 문자열 표기도 받는다 — 스키마가 타입을 강제한다. kind 검사는 더하지 않는다(다른 kind의 객체는 필드 결손 사유로 FAIL한다).
#
# 단언 ↔ T051 과제 항목(tasks.md T051 원문 · 요구 원문 설계 D2):
#   gate-1..3  kubectl 존재 · KUBECONFIG 단일 파일 · `auth whoami` = agent-view (cluster.tests.ps1과 같은 fail-closed 게이트 — 게이트 실패면 나머지 전부 FAIL)
#   kafka-1    kafkas.kafka.strimzi.io data/jt-kafka 존재 · Ready=True · spec.kafka.version=4.3.1 · spec.kafka.config[auto.create.topics.enable]=false
#              (문자열 "false" 또는 불리언 false — 그 밖 · 없음(= 브로커 기본 true)은 FAIL) · 어노테이션 argocd.argoproj.io/sync-options=Delete=false,Prune=false(정확 일치)
#   kafka-2    spec.kafka.listeners[]에 name=tls 가 정확히 1개이고 port=9093 · tls=true · authentication.type=scram-sha-512 · spec.kafka.authorization.type=simple ·
#              그 밖의 listener도 전부 tls=true 이고 authentication.type 이 있다(인증 없는 listener는 FAIL — ACL 우회 경로) ·
#              spec.kafka.authorization.superUsers 에 identity-admin · dev-identity-admin(표기 'User:<name>' · '<name>' · 'CN=<name>' · 'User:CN=<name>[,…]')
#              이나 '*' 가 없다. 근거: T055 선언값에는 추가 listener도 superUsers도 없고, superUser는 ACL을 통째로 우회하므로 user-2의 의미를 지키려면
#              여기서 막아야 한다(적대 리뷰 F8 · 컨트롤러 결정 2026-10-08 — 요구 원문 D2보다 강한 판정).
#   pool-1     kafkanodepools(ns data, 라벨 strimzi.io/cluster=jt-kafka) 정확히 1개 · spec.replicas=1 · spec.roles={controller, broker}(집합 정확 일치) ·
#              Ready 조건이 있으면 True, 없으면 status.replicas=1 로 대체(아래 upstream 확인 — KafkaNodePool status에는 Ready 조건이 없다)
#   pool-2     Kafka 노드 pod(ns data, 라벨 strimzi.io/cluster=jt-kafka 이면서 strimzi.io/component-type=kafka 또는 strimzi.io/pool-name 있음) ≥ 1 ·
#              전부 status.phase=Running · 각 pod 조건 Ready=True(CrashLoopBackOff 중인 pod도 phase는 Running이다 — Ready=False가 잡는다) ·
#              각 pod의 spec.nodeName 노드 라벨 role=platform(노드 A). 엔티티 오퍼레이터 pod(component-type=entity-operator)는 대상이 아니다.
#   topic-1    kafkatopics(ns data, cluster jt-kafka)의 토픽 이름(spec.topicName, 없으면 metadata.name) 집합 ⊇ {identity-admin.session.revoked,
#              dev.identity-admin.session.revoked, identity-admin.dlq, dev.identity-admin.dlq} · 넷 다 Ready=True · spec.partitions=3 · spec.replicas=1 ·
#              spec.config[retention.ms]=604800000(문자열/숫자). 다른 토픽은 사유에 나열만(FAIL 아님) · 같은 토픽 이름을 두 KafkaTopic이 선언하면 FAIL
#   user-1     kafkausers(ns data, cluster jt-kafka) identity-admin · dev-identity-admin 각각 정확히 1개 · Ready=True · spec.authentication.type=scram-sha-512 ·
#              spec.authorization.type=simple · status.secret 비어 있지 않음(이름만)
#   user-2     ACL 교차 없음: identity-admin은 topic Write(또는 All) ACL이 identity-admin.* 를 덮고 dev.* 를 덮지 않는다, dev-identity-admin은
#              dev.identity-admin.* 를 덮고 identity-admin.* 를 덮지 않는다. literal(기본)은 이름이 그 접두로 시작할 때, prefix는 두 문자열이 서로 접두
#              관계일 때, literal '*'는 전부를 덮는다. type=deny 규칙은 세지 않는다(Test-AclWritesPrefix — 순수 함수)
#   df-1       deployments.apps data/dragonfly-dev · data/dragonfly-prod 존재 · Available=True · spec.replicas=1 · status.availableReplicas=1(Available=True는
#              replicas 0에서 공허하다 — K8s deployment 컨트롤러는 availableReplicas >= replicas - maxUnavailable 이면 True를 세우므로 0 >= 0 도 True) ·
#              컨테이너 정확히 1개 · command+args 토큰에 --maxmemory=768mb(또는 '--maxmemory' '768mb' 분리 표기) · --aclfile /etc/dragonfly/users.acl ·
#              --requirepass 없음(-requirepass 포함) · --flagfile · --fromenv · --tryfromenv 없음(absl 플래그 라이브러리의 간접 경로 — 파일 또는 FLAGS_<name> 환경변수에서
#              --requirepass 를 읽을 수 있다; T057 선언에는 없다 — 재검토 F4) · 컨테이너 env에 DFLY_requirepass · DFLY_PASSWORD 없음 · envFrom 없음(Dragonfly는 DFLY_<flag> 환경변수로도
#              플래그를 읽고 DFLY_PASSWORD는 requirepass의 별칭이다 — 비밀번호는 aclfile로만; env 값은 읽지 않고 이름만 본다) ·
#              spec.template.spec.terminationGracePeriodSeconds=60 · spec.strategy.type=Recreate · automountServiceAccountToken=false(없음 = 기본 true → FAIL)
#   df-2       services data/dragonfly-dev · data/dragonfly-prod 존재 · spec.ports[]에 6379
#   job-k-1    jobs.batch jt-dev/kafka-assert 존재 · status.succeeded ≥ 1
#   job-k-2    `logs job/kafka-assert --tail=50`에 roundtrip · cross-env-denied RESULT 줄이 각각 정확히 1개이고 PASS · SUMMARY 줄 정확히 1개이고 fail=0 ·
#              SUMMARY의 pass/fail 수가 보이는 RESULT 줄 수와 같다(다르면 --tail=50에 잘렸거나 Job 출력이 어긋난 것 → FAIL)
#   job-k-3    roundtrip RESULT PASS 줄의 근거에서 메시지 경로 지연 토큰 `latency=<n>ms`(Job이 더한다 — T056 몫)를 읽어 ≤ 5000 이면 PASS, 초과면 FAIL(값 표기),
#              토큰이 없거나 둘 이상이면 FAIL(정확히 1개만 판정 — 둘 이상은 모호, fail closed; 재검토 F2). 토큰 둘레: 앞은 문자열 시작 · 공백 · ( [ · 따옴표,
#              뒤는 끝 · 공백 · , ) ; . ] : · 따옴표(재검토 F3 — `(latency=120ms)` · `"latency=120ms"` 도 읽는다; 글자가 붙은 `xlatency=120ms` · `latency=120msx` 는 토큰이 아니다).
#              벽시계 `<n>s`(Job 형식 `produce→consume <n>s (상한 30s, JVM 기동 포함)`)는 판정에 쓰지 않는다 — Job 컨슈머가
#              --timeout-ms 20000(KAFKA_CONSUME_TIMEOUT_MS) 유휴 대기 뒤에야 끝나 JVM 2회 기동 + 20 s가 항상 포함되므로(≥ 20 s) spec US3 AC3의
#              5 s(메시지 경로)와 다른 양이다(적대 리뷰 F1). Get-ElapsedSeconds는 사유 표기용으로만 남긴다. Job 자체의 30 s 벽시계 판정은 별개다.
#   job-d-1    jobs.batch jt-dev/data-assert 존재 · status.succeeded ≥ 1 (T050 data.tests.ps1과 같은 Job — 각 파일이 자체 완결이라 중복 허용)
#   job-d-2    `logs job/data-assert --tail=50`에 Dragonfly 검사 id acl-list · noperm · noauth · writer-set · reader-get · reader-set-denied ·
#              reader-cross-denied 일곱이 각각 정확히 1개이고 전부 PASS · acl-list 근거 또는 `EVIDENCE:   user sample-pod …` 행에 %R~revoked:* 가 있다
#              (VD-4 — 유무만 적는다; 다른 사용자 행의 패턴은 세지 않는다) · SUMMARY 줄 정확히 1개이고 pass/fail 수가 보이는 RESULT 줄 수(pg 절 포함)와
#              같다(fail=0은 요구하지 않는다 — pg 절의 판정은 T050 data.tests.ps1 몫)
#   job-k-2 · job-k-3 · job-d-2는 Job 상태(succeeded)와 무관하게 로그만 본다 — Job 상태는 job-k-1 · job-d-1이 따로 판정한다(각 단언이 자기 증거만).
#   단언 수: 17 = gate 3 + kafka 2 + pool 2 + topic 1 + user 2 + df 2 + job-k 3 + job-d 2.
#
# 로그 계약(gitops platform/policies/tests/README.md §로그 계약): `RESULT: PASS|FAIL <id> <근거>` 검사당 정확히 1줄 · 마지막 `SUMMARY: pass=<n> fail=<n>` ·
#   보조 줄은 EVIDENCE: · NOTE: 뿐 · 전부 --tail=50 안. 파서(ConvertFrom-AssertLog)는 ^RESULT: · ^SUMMARY: · ^EVIDENCE: 만 본다.
#
# Strimzi 필드 출처(upstream 공개 자료 읽기 2026-10-07/08 — github.com/strimzi/strimzi-kafka-operator 태그 1.2.0 과 main; 요구 원문의 "0.50"은 존재하지
#   않는 버전이고 upstream 안정판은 1.2.0이다. kubectl은 <plural>.kafka.strimzi.io 로 조회하므로 API 버전(v1beta2 → 1.x는 v1만 served)은 이 파일에 영향이 없다):
#   URL(전부 https://raw.githubusercontent.com/strimzi/strimzi-kafka-operator/1.2.0/ 아래 — 읽은 날짜 2026-10-07/08):
#     install/cluster-operator/040-Crd-kafka.yaml · install/cluster-operator/043-Crd-kafkatopic.yaml · install/cluster-operator/044-Crd-kafkauser.yaml ·
#     install/cluster-operator/045-Crd-kafkanodepool.yaml · cluster-operator/src/main/java/io/strimzi/operator/cluster/model/KafkaPool.java ·
#     cluster-operator/src/main/java/io/strimzi/operator/cluster/model/EntityOperator.java ·
#     operator-common/src/main/java/io/strimzi/operator/common/model/Labels.java · operator-common/src/main/java/io/strimzi/operator/common/model/StatusUtils.java ·
#     kafka-versions.yaml · CHANGELOG.md
#   - Kafka:         install/cluster-operator/040-Crd-kafka.yaml — printer 열 Ready = .status.conditions[?(@.type=="Ready")].status;
#                    listeners[].authentication.type enum {tls, scram-sha-512, custom}; authorization.type enum {simple, custom} + superUsers[](무제한 권한 principal);
#                    spec.kafka.config는 자유 객체.
#   - KafkaNodePool: install/cluster-operator/045-Crd-kafkanodepool.yaml — status 속성 {conditions, observedGeneration, nodeIds, clusterId, roles, replicas,
#                    labelSelector}; printer 열에 Ready 없음. cluster-operator/…/model/KafkaPool.java generateNodePoolStatus(): conditions = 경고 조건뿐,
#                    replicas = 원하는 노드 id 수 → Ready 조건은 없다. 그래서 pool-1은 status.replicas=1 로 대체하고(원하는 수이지 기동 수가 아니다),
#                    실제 기동은 pool-2(pod Running)와 kafka-1(Kafka Ready)이 본다. 장래 Ready 조건이 생기면 그 값을 먼저 쓴다.
#   - KafkaTopic:    install/cluster-operator/043-Crd-kafkatopic.yaml — spec {topicName, partitions, replicas, config}; status {conditions(Ready), topicName, topicId, …}.
#   - KafkaUser:     install/cluster-operator/044-Crd-kafkauser.yaml — spec.authentication.type; spec.authorization {type, acls[]{type allow|deny(기본 allow),
#                    resource{type, name, patternType literal|prefix(기본 literal)}, operations[](필수: Read Write Create Delete Alter Describe ClusterAction
#                    AlterConfigs DescribeConfigs IdempotentWrite All), host}}; status {conditions, username, secret}. 예전 단수 `operation` 필드도 받아 둔다.
#   - pod 라벨:      operator-common/…/model/Labels.java — strimzi.io/cluster · kind · name · component-type · pool-name · broker-role · controller-role.
#                    component-type 값: Kafka 노드 pod = "kafka"(model/KafkaPool.java COMPONENT_TYPE), 엔티티 오퍼레이터 = "entity-operator"(model/EntityOperator.java).
#   라이브에서만 확인되는 것(미확인): Kafka NotReady 때 조건 모양(Ready 부재 + NotReady=True 로 가정해 사유에 reason/message를 싣는다) ·
#   Dragonfly 컨테이너의 args 표기(= 또는 분리 — 둘 다 받는다) · 검사 Job 로그의 실제 줄(파서는 README 계약만 전제한다) ·
#   roundtrip 근거의 `latency=<n>ms` 토큰(T056이 Job에 더한 뒤 T059에서 첫 실측).
param()
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다
# stdout이 파이프·파일이면(단위 테스트 · 러너) 콘솔 코드 페이지와 무관하게 UTF-8로 쓴다 — 한글 · → 가 든 사유가 '?'로 깨지지 않는다(대화형 콘솔은 그대로).
#   .NET의 OutputEncoding 설정은 콘솔 자체의 출력 코드 페이지를 바꾸고 프로세스가 끝난 뒤에도 남으므로(3라운드 실측 — 러너의 파이프 경유도 해당) 종료 때 원래 값으로
#   되돌린다(PowerShell.Exiting — 정상 exit · 처리되지 않은 오류 양쪽에서 복원 확인; 이벤트 액션 블록에서는 $script: 변수가 보이지 않아 $global: 을 쓴다).
if ([Console]::IsOutputRedirected) {
    try {
        $global:kafkaTestsPrevConsoleEncoding = [Console]::OutputEncoding
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        $null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { try { [Console]::OutputEncoding = $global:kafkaTestsPrevConsoleEncoding } catch { } }
    } catch { }
}
$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:clusterReason = $null      # $null = 게이트 통과; 문자열이면 모든 클러스터 단언이 그 사유로 FAIL
$script:kubectl = $null            # kubectl 실행 파일 경로(게이트 1)
$script:kubeconfig = $null         # $env:KUBECONFIG(게이트 2)
$script:cache = @{}                # 리스트 조회 캐시(Get-KubeList — 성공만)
$script:lookups = @{}              # 단언용 조회 캐시(Get-OneLookup · Get-ListLookup · Get-JobState — 오류도 기억)

$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$syncOptions = 'Delete=false,Prune=false'

# ---------- 계약 값(tasks.md T051 과제 줄 · T055–T057 선언값 · contracts/denylist.md §ACL) ----------
$kafkaNs = 'data'
$kafkaCluster = 'jt-kafka'
$kafkaVersion = '4.3.1'
$listenerName = 'tls'; $listenerPort = '9093'; $listenerAuth = 'scram-sha-512'; $authorizationType = 'simple'
$poolRoles = @('controller', 'broker')
$poolNodeRole = 'platform'
$topicNames4 = @('identity-admin.session.revoked', 'dev.identity-admin.session.revoked', 'identity-admin.dlq', 'dev.identity-admin.dlq')
$topicPartitions = '3'; $topicReplicas = '1'; $topicRetentionMs = '604800000'
$userAuth = 'scram-sha-512'; $userAuthz = 'simple'
# 사용자 → write = topic Write ACL이 덮어야 하는 접두, deny = 덮으면 안 되는 접두(교차 env)
$userAcl = [ordered]@{
    'identity-admin'     = @{ write = 'identity-admin.'; deny = 'dev.' }
    'dev-identity-admin' = @{ write = 'dev.identity-admin.'; deny = 'identity-admin.' }
}
$dragonflyNs = 'data'; $dragonflyNames = @('dragonfly-dev', 'dragonfly-prod')
$dragonflyMaxMemory = '768mb'; $dragonflyAclFile = '/etc/dragonfly/users.acl'; $dragonflyGrace = '60'; $dragonflyStrategy = 'Recreate'; $dragonflyPort = '6379'
$dragonflyPasswordEnv = @('DFLY_requirepass', 'DFLY_PASSWORD')   # Dragonfly: DFLY_<flag> env = 플래그, DFLY_PASSWORD = requirepass 별칭(이름만 본다)
$assertNs = 'jt-dev'; $logTail = 50
$assertJobNote = 'platform/policies/tests not deployed yet (after T055-T057), or the Job was removed by ttlSecondsAfterFinished=7d -- re-run it'
$kafkaJob = 'kafka-assert'; $kafkaJobIds = @('roundtrip', 'cross-env-denied'); $roundtripMaxMs = 5000   # spec US3 AC3: 메시지 경로 왕복 ≤ 5 s(latency=<n>ms 토큰)
$dataJob = 'data-assert'
$dataJobIds = @('acl-list', 'noperm', 'noauth', 'writer-set', 'reader-get', 'reader-set-denied', 'reader-cross-denied')
$dataJobNewIds = @('noauth', 'writer-set', 'reader-get', 'reader-set-denied', 'reader-cross-denied')   # T057 슬라이스(지금 Job에 없음)
$aclReadOnlyPattern = '%R~revoked:*'
$sampleEvidenceRow = '\AEVIDENCE:\s+user sample-pod\s'   # data-assert EVIDENCE 블록의 sample-pod 행(`EVIDENCE:   user sample-pod on #<redacted> …`)만 VD-4 증거로 센다

# ---------- 결과 헬퍼(출처: tests/platform/cluster.tests.ps1 §결과 헬퍼) ----------
function Clip([string]$s, [int]$max = 400) {
    if ($null -eq $s) { return '' }
    $s = ($s -replace "`r`n", ' ') -replace "`n", ' '
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' } else { return $s }
}
function Pass([string]$id, [string]$detail, [int]$max = 400) { $script:pass++; Write-Host "PASS ${id}: $(Clip $detail $max)" }
function Fail([string]$id, [string]$detail, [int]$max = 400) { $script:fail++; Write-Host "FAIL ${id}: $(Clip $detail $max)" }

# 클러스터 단언 래퍼(출처: cluster.tests.ps1 ClusterAssert — SKIP 분기만 다르다): 게이트 실패면 사유와 함께 FAIL(fail closed).
#   $body는 @('PASS'|'FAIL', detail)을 돌려준다(마지막 두 원소 — 본문의 우발적 파이프라인 출력이 앞에 섞여도 판정이 흔들리지 않는다).
#   예외(kubectl 실패 · JSON 파싱 실패 등)는 FAIL이다. 'SKIP'은 이 파일에 없는 상태라 하네스 버그로 보고 FAIL한다. $clip = 출력 줄 상한.
function ClusterAssert([string]$id, [scriptblock]$body, [int]$clip = 400) {
    if ($null -ne $script:clusterReason) { Fail $id "cluster unavailable ($script:clusterReason)" $clip; return }
    $status = 'FAIL'; $detail = ''
    try {
        $r = @(& $body)
        if ($r.Count -lt 2) { throw "assertion body returned $($r.Count) value(s), expected (status, detail)" }
        $status = [string]$r[$r.Count - 2]; $detail = [string]$r[$r.Count - 1]
    }
    catch { $status = 'FAIL'; $detail = "unhandled $($_.Exception.GetType().Name): $(Mask-Text $_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    if (Eq $status 'PASS') { Pass $id $detail $clip }
    elseif (Eq $status 'SKIP') { Fail $id "harness bug: SKIP is not a status in this file (fail closed) -- $detail" $clip }
    else { Fail $id $detail $clip }
}

# ---------- 문자열 · 집합 헬퍼(전부 ordinal — 출처: cluster.tests.ps1 §문자열·집합 헬퍼) ----------
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function SortOrd($arr) {
    $l = [System.Collections.Generic.List[string]]::new()
    foreach ($x in @($arr)) { if ($null -ne $x) { $l.Add([string]$x) } }
    $l.Sort([StringComparer]::Ordinal)
    return @($l.ToArray())
}
function SetEq($a, $b) { return (Eq ((SortOrd $a) -join "`n") ((SortOrd $b) -join "`n")) }
function Contains($arr, [string]$v) { foreach ($x in @($arr)) { if (Eq "$x" $v) { return $true } }; return $false }
function StartsOrd([string]$s, [string]$prefix) { return ($null -ne $s) -and $s.StartsWith($prefix, [StringComparison]::Ordinal) }
function IndexOrd([string]$s, [string]$sub) { if ($null -eq $s) { return -1 }; return $s.IndexOf($sub, [StringComparison]::Ordinal) }

# ---------- JSON 객체 접근(속성 이름 ordinal 정확 일치; 없으면 $null — 출처: cluster.tests.ps1 §JSON 객체 접근) ----------
function Prop($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    if ($obj -is [System.Collections.IDictionary]) {
        foreach ($k in $obj.Keys) { if (Eq "$k" $name) { return $obj[$k] } }
        return $null
    }
    foreach ($p in $obj.PSObject.Properties) { if (Eq $p.Name $name) { return $p.Value } }
    return $null
}
function PropPath($obj, [string[]]$path) {
    $cur = $obj
    foreach ($n in $path) { $cur = Prop $cur $n; if ($null -eq $cur) { return $null } }
    return $cur
}
# 배열 필드용: 없으면 빈 배열(@($null)이 원소 1개로 세어지는 PowerShell 특성을 막는다). 호출 측은 @(PropArr …)로 감싼다.
function PropArr($obj, [string[]]$path) { $v = PropPath $obj $path; if ($null -eq $v) { return @() }; return @($v) }
function PropNames($obj) {
    if ($null -eq $obj) { return @() }
    if ($obj -is [System.Collections.IDictionary]) { return @($obj.Keys | ForEach-Object { "$_" }) }
    return @($obj.PSObject.Properties | ForEach-Object { $_.Name })
}
# 반환은 언래핑된 배열이다 — 호출 측은 반드시 @(Items …)로 감싼다(원소 1개가 스칼라로 풀리는 것을 막는다).
function Items($listObj) { $i = Prop $listObj 'items'; if ($null -eq $i) { return @() }; return @($i) }
function Name($obj) { return [string](PropPath $obj @('metadata', 'name')) }
function Label($obj, [string]$key) { $v = PropPath $obj @('metadata', 'labels', $key); if ($null -eq $v) { return $null }; return [string]$v }
function Annotation($obj, [string]$key) { $v = PropPath $obj @('metadata', 'annotations', $key); if ($null -eq $v) { return $null }; return [string]$v }
# status.conditions[type=$type]: 없으면 $null, 하나면 그 조건. 같은 type이 둘 이상이면 모호하다 — 첫 항목을 믿지 않고 status에 그 사실을 적어
#   호출 측이 FAIL하게 한다(fail closed; [Ready=True, Ready=False]든 그 반대 순서든 똑같이 FAIL — 적대 리뷰 F4).
function Condition($obj, [string]$type) {
    $hits = @(@(PropArr $obj @('status', 'conditions')) | Where-Object { Eq ([string](Prop $_ 'type')) $type })
    if ($hits.Count -eq 0) { return $null }
    if ($hits.Count -eq 1) { return $hits[0] }
    return @{ type = $type; status = "ambiguous: $($hits.Count) $type conditions [$((@($hits | ForEach-Object { [string](Prop $_ 'status') })) -join ', ')]"; reason = 'DuplicateCondition' }
}
# 사유용 값 표기: 없음 = <absent>, 불리언은 소문자, 문자열은 따옴표, 배열은 [a, b], 숫자는 그대로(비밀이 아닌 설정값만 지나간다)
function Format-Value($v) {
    if ($null -eq $v) { return '<absent>' }
    if ($v -is [bool]) { if ($v) { return 'true' } else { return 'false' } }
    if ($v -is [string]) { return "'$v'" }
    if ($v -is [System.Collections.IList]) { return '[' + ((@($v | ForEach-Object { Format-Value $_ })) -join ', ') + ']' }
    return "$v"
}
function Format-Problems($bad) { $bad = @($bad); return "$($bad.Count) problem(s): $($bad -join '; ')" }

# 출력 마스킹(출처: cluster.tests.ps1 Mask-Text): kubeconfig 경로 · 홈 디렉터리를 <KUBECONFIG>/~로 치환(ordinal; \ 와 / 두 표기 모두).
# kubeconfig를 먼저 치환한다(보통 홈 아래에 있어 홈을 먼저 바꾸면 매치가 깨진다).
function Mask-Text([string]$s) {
    if ([string]::IsNullOrEmpty($s)) { return $s }
    $pairs = @()
    foreach ($kc in @($script:kubeconfig, $env:KUBECONFIG)) { if (-not [string]::IsNullOrWhiteSpace($kc)) { $pairs += , @($kc, '<KUBECONFIG>') } }
    foreach ($h in @($HOME, $env:USERPROFILE)) { if (-not [string]::IsNullOrWhiteSpace($h)) { $pairs += , @($h, '~') } }
    foreach ($p in $pairs) {
        $s = $s.Replace([string]$p[0], [string]$p[1], [StringComparison]::Ordinal)
        $s = $s.Replace(([string]$p[0]).Replace('\', '/'), [string]$p[1], [StringComparison]::Ordinal)
    }
    return $s
}
# 임시 파일 삭제(출처: cluster.tests.ps1 Remove-WithRetry — 자식 프로세스가 핸들을 늦게 놓을 수 있어 3회 재시도)
function Remove-WithRetry([string[]]$paths) {
    foreach ($p in $paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        for ($i = 1; $i -le 3; $i++) {
            if (-not (Test-Path -LiteralPath $p)) { break }
            try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 300 }
        }
    }
}

# ---------- 네이티브 실행(출처: cluster.tests.ps1 Invoke-Native — stdout UTF-8 디코드; stderr는 임시 파일; 반환 전 경로 마스킹) ----------
function Invoke-Native([string]$exe, [string[]]$nativeArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('kafka-tests-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
    $out = @(); $code = -1; $err = ''
    $prevEncoding = [Console]::OutputEncoding
    try {
        try {
            [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
            $out = & $exe @nativeArgs 2> $errFile
            $code = $LASTEXITCODE
        } finally { [Console]::OutputEncoding = $prevEncoding }
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) } else { '' }
    } finally { Remove-WithRetry @($errFile) }
    return @{ out = (Mask-Text (@($out | ForEach-Object { "$_" }) -join "`n")); err = (Mask-Text $err.Trim()); code = $code }
}
# kubectl — 항상 --kubeconfig 명시(기본 kubeconfig로 흘러가지 않게) + 요청 타임아웃(출처: cluster.tests.ps1).
function Invoke-Kubectl([string[]]$kArgs) {
    return Invoke-Native $script:kubectl (@("--kubeconfig=$script:kubeconfig", '--request-timeout=30s') + @($kArgs))
}
function ConvertFrom-JsonStrict([string]$text, [string]$what) {
    if ([string]::IsNullOrWhiteSpace($text)) { throw "empty output from $what (expected JSON)" }
    try { return ($text | ConvertFrom-Json -Depth 64) }
    catch { throw "JSON parse failed for ${what}: $($_.Exception.Message)" }
}
# 리스트 조회(-o json). 실패는 예외(출처: cluster.tests.ps1 Get-KubeList).
function Get-KubeList([string[]]$kArgs) {
    $key = ($kArgs -join ' ')
    if ($script:cache.ContainsKey($key)) { return $script:cache[$key] }
    $r = Invoke-Kubectl (@($kArgs) + @('-o', 'json'))
    if ($r.code -ne 0) { throw "kubectl $key failed (exit $($r.code)): $($r.err)" }
    $obj = ConvertFrom-JsonStrict $r.out "kubectl $key"
    $script:cache[$key] = $obj
    return $obj
}
# 단일 리소스 조회 — 없으면 $null(--ignore-not-found), 다른 오류는 예외(출처: cluster.tests.ps1 Get-KubeOne).
function Get-KubeOne([string]$ns, [string]$kind, [string]$name) {
    $kArgs = @('get', $kind, $name, '--ignore-not-found', '-o', 'json')
    if (-not [string]::IsNullOrEmpty($ns)) { $kArgs = @('-n', $ns) + $kArgs }
    $r = Invoke-Kubectl $kArgs
    if ($r.code -ne 0) { throw "kubectl get $kind/$name (ns '$ns') failed (exit $($r.code)): $($r.err)" }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return $null }
    return (ConvertFrom-JsonStrict $r.out "kubectl get $kind/$name")
}

# ---------- 단언용 조회 캐시(D3): 조회마다 예외를 잡아 error 문자열로 바꾼다. 같은 조회를 쓰는 단언마다 같은 사유가 나온다(재시도 없음). ----------
function Get-OneLookup([string]$key, [scriptblock]$fetch) {
    if ($script:lookups.ContainsKey($key)) { return $script:lookups[$key] }
    $res = @{ obj = $null; error = $null }
    try { $res.obj = & $fetch } catch { $res.error = (Mask-Text $_.Exception.Message) }
    $script:lookups[$key] = $res
    return $res
}
function Get-ListLookup([string]$key, [scriptblock]$fetch) {
    if ($script:lookups.ContainsKey($key)) { return $script:lookups[$key] }
    $res = @{ items = @(); error = $null }
    try { $res.items = @(& $fetch) } catch { $res.error = (Mask-Text $_.Exception.Message) }
    $script:lookups[$key] = $res
    return $res
}
# Strimzi 조회 오류 → 사유. 리소스 타입 없음(kubectl: the server doesn't have a resource type "<plural>") = CRD 미설치(T055 전)라 그 뜻을 적는다.
function Format-StrimziError([string]$what, [string]$plural, [string]$msg) {
    if ((IndexOrd $msg "doesn't have a resource type") -ge 0) { return "${what}: CRD $plural.kafka.strimzi.io not installed (T055) -- $(Clip $msg 160)" }
    return "${what}: lookup failed: $(Clip $msg 240)"
}
function Get-KafkaCr { return (Get-OneLookup 'kafka' { Get-KubeOne $kafkaNs 'kafkas.kafka.strimzi.io' $kafkaCluster }) }
function Get-NodePools { return (Get-ListLookup 'pools' { Items (Get-KubeList @('get', 'kafkanodepools.kafka.strimzi.io', '-n', $kafkaNs)) }) }
function Get-KafkaPods { return (Get-ListLookup 'pods' { Items (Get-KubeList @('get', 'pods', '-n', $kafkaNs, '-l', "strimzi.io/cluster=$kafkaCluster")) }) }
function Get-Nodes { return (Get-ListLookup 'nodes' { Items (Get-KubeList @('get', 'nodes')) }) }
function Get-Topics { return (Get-ListLookup 'topics' { Items (Get-KubeList @('get', 'kafkatopics.kafka.strimzi.io', '-n', $kafkaNs)) }) }
function Get-Users { return (Get-ListLookup 'users' { Items (Get-KubeList @('get', 'kafkausers.kafka.strimzi.io', '-n', $kafkaNs)) }) }
# 클러스터 라벨이 맞는 Strimzi 객체만(다른 클러스터의 객체는 세지 않는다)
function Select-Cluster($items) { return @(@($items) | Where-Object { Eq (Label $_ 'strimzi.io/cluster') $kafkaCluster }) }

# Strimzi 상태: Ready=True가 정상. Ready 조건이 없고 NotReady가 있으면 그 reason/message를 사유에 싣는다(설정값 · 오류 문구라 비밀이 아니다 — Clip).
function Format-ConditionNote($c) {
    $parts = @()
    $reason = [string](Prop $c 'reason'); $msg = [string](Prop $c 'message')
    if (-not [string]::IsNullOrEmpty($reason)) { $parts += $reason }
    if (-not [string]::IsNullOrEmpty($msg)) { $parts += (Clip $msg 120) }
    if ($parts.Count -eq 0) { return '' }
    return " [$($parts -join ': ')]"
}
function Get-ReadyState($obj) {
    $c = Condition $obj 'Ready'
    if ($null -ne $c) {
        $s = [string](Prop $c 'status')
        if (Eq $s 'True') { return @{ ok = $true; text = 'Ready=True' } }
        return @{ ok = $false; text = "Ready condition status=$(Format-Value $s) (expected True)$(Format-ConditionNote $c)" }
    }
    $nr = Condition $obj 'NotReady'
    if ($null -ne $nr) { return @{ ok = $false; text = "no Ready condition; NotReady=$(Prop $nr 'status')$(Format-ConditionNote $nr)" } }
    return @{ ok = $false; text = 'no Ready condition in status.conditions' }
}

# ---------- 순수 함수: KafkaUser ACL · 컨테이너 인자 · Job 로그(단위 테스트 tests/scripts/kafka-tests.tests.ps1이 모듈로 불러 표로 시험한다) ----------
# ACL 하나가 접두 $prefix(예: 'identity-admin.')의 토픽에 Write(또는 All)를 허용하는가.
#   resource.type=topic · type이 없거나 allow · operations[](또는 예전 단수 operation)에 Write 또는 All 이 있을 때만 후보다.
#   patternType=prefix: ACL 이름과 $prefix가 서로 접두 관계(어느 쪽이 길든)면 덮는다 — 'identity-admin.'은 'identity-admin.session.revoked'를,
#   빈 이름은 전부를 덮는다. literal(기본 — 없으면 literal): 이름이 $prefix로 시작하면 덮는다 · 이름 '*'는 Kafka 와일드카드라 전부를 덮는다.
#   $forCross = 교차(덮으면 안 되는 접두) 판정: deny 가 아니면 전부 "쓸 수 있음"으로 본다(fail closed — 'Allow' 같은 비정상 표기도 허용으로 센다).
#   자기 접두 판정($forCross=$false)은 type 이 없거나 정확히 allow 일 때만 후보다(CRD enum은 allow|deny, 기본 allow).
function Test-AclWritesPrefix($acl, [string]$prefix, [bool]$forCross = $false) {
    if (-not (Eq ([string](PropPath $acl @('resource', 'type'))) 'topic')) { return $false }
    $ruleType = Prop $acl 'type'
    if ($forCross) { if (Eq ([string]$ruleType) 'deny') { return $false } }
    elseif ($null -ne $ruleType -and -not (Eq ([string]$ruleType) 'allow')) { return $false }
    $ops = @(@(PropArr $acl @('operations')) | ForEach-Object { [string]$_ })
    $single = Prop $acl 'operation'
    if ($null -ne $single) { $ops += [string]$single }
    if (-not ((Contains $ops 'Write') -or (Contains $ops 'All'))) { return $false }
    $name = [string](PropPath $acl @('resource', 'name'))
    $pt = [string](PropPath $acl @('resource', 'patternType'))
    if ([string]::IsNullOrEmpty($pt)) { $pt = 'literal' }
    if (Eq $pt 'prefix') { return ((StartsOrd $name $prefix) -or (StartsOrd $prefix $name)) }
    if (Eq $name '*') { return $true }
    return (StartsOrd $name $prefix)
}
function Format-Acl($acl) {
    $pt = [string](PropPath $acl @('resource', 'patternType')); if ([string]::IsNullOrEmpty($pt)) { $pt = 'literal' }
    return "${pt}:'$([string](PropPath $acl @('resource', 'name')))'"
}
# 컨테이너 인자 토큰(command + args)에서 플래그 값을 모은다: '--flag=value' · '-flag=value' 또는 '--flag' 'value'(다음 토큰). 없으면 빈 배열.
function Get-FlagValues($tokens, [string]$flag) {
    $tokens = @(@($tokens) | ForEach-Object { [string]$_ })
    $vals = @()
    for ($i = 0; $i -lt $tokens.Count; $i++) {
        foreach ($dash in @('--', '-')) {
            $t = $tokens[$i]
            if (StartsOrd $t "$dash$flag=") { $vals += $t.Substring(("$dash$flag=").Length); break }
            if (Eq $t "$dash$flag") { if ($i + 1 -lt $tokens.Count) { $vals += $tokens[$i + 1] } else { $vals += '' }; break }
        }
    }
    return @($vals)
}
# 플래그가 정확히 그 값으로 있는가: 한 번 이상 나오고 모든 값이 $value(두 번 다른 값이면 FAIL — 뒤 값이 이기는 gflags 규칙에 기대지 않는다)
function Test-FlagValue($tokens, [string]$flag, [string]$value) {
    $vals = @(Get-FlagValues $tokens $flag)
    if ($vals.Count -eq 0) { return $false }
    foreach ($v in $vals) { if (-not (Eq $v $value)) { return $false } }
    return $true
}
function Test-FlagPresent($tokens, [string]$flag) { return (@(Get-FlagValues $tokens $flag).Count -gt 0) }

# 검사 Job 로그 파서(README §로그 계약): 반환 @{ results = @(@{ id; status; evidence }); summaries = @(@{ pass; fail; line }); evidence = @('EVIDENCE: …') }
#   줄 끝 공백 · CRLF는 무시한다. 그 밖의 줄(NOTE: · 도구 출력)은 보지 않는다.
function ConvertFrom-AssertLog([string]$text) {
    $results = [System.Collections.Generic.List[object]]::new()
    $summaries = [System.Collections.Generic.List[object]]::new()
    $evidence = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $text) { $text = '' }
    foreach ($raw in @(($text -replace "`r`n", "`n") -split "`n")) {
        $l = ([string]$raw).TrimEnd()
        $m = [regex]::Match($l, '\ARESULT: (PASS|FAIL) (\S+)(?: (.*))?\z')
        if ($m.Success) { $results.Add(@{ id = $m.Groups[2].Value; status = $m.Groups[1].Value; evidence = $m.Groups[3].Value }); continue }
        $m = [regex]::Match($l, '\ASUMMARY: pass=(\d+) fail=(\d+)\z')
        if ($m.Success) { $summaries.Add(@{ pass = [int]$m.Groups[1].Value; fail = [int]$m.Groups[2].Value; line = $l }); continue }
        if (StartsOrd $l 'EVIDENCE:') { $evidence.Add($l) }
    }
    return @{ results = @($results.ToArray()); summaries = @($summaries.ToArray()); evidence = @($evidence.ToArray()) }
}
# roundtrip 근거의 벽시계 경과 초(사유 표기용 — 판정에는 쓰지 않는다): 먼저 Job 형식의 앵커 `produce→consume <n>s`, 없으면 첫 `<n>s` 토큰 — 앞은
#   문자열 시작 또는 공백, 뒤는 끝 · 공백 · 구두점(, ) ; .)만 허용한다(`topic2s` · `v4.3.1s` 같은 이름 조각은 토큰이 아니다). 자릿수 상한 9(10자리 이상은
#   [int] 변환 예외 대신 토큰 아님 → $null — 적대 리뷰 F5). 없으면 $null.
function Get-ElapsedSeconds([string]$evidence) {
    if ($null -eq $evidence) { return $null }
    $m = [regex]::Match($evidence, 'produce→consume (\d{1,9})s(?![^\s,);.])')
    if (-not $m.Success) { $m = [regex]::Match($evidence, '(?<!\S)(\d{1,9})s(?![^\s,);.])') }
    if (-not $m.Success) { return $null }
    return [int]$m.Groups[1].Value
}
# roundtrip 근거의 메시지 경로 지연 `latency=<n>ms`(T056이 Job에 더한다 — 마커 수신 시각 − CreateTime). 벽시계 `<n>s`는 JVM 2회 기동 + 컨슈머 --timeout-ms 유휴
#   대기(20 s)를 포함해 5 s 기준의 측정값이 아니다(적대 리뷰 F1).
# 근거 안의 latency=<n>ms 토큰 전부(자릿수 상한 9). 앞: 문자열 시작 · 공백 · 여는 괄호 ( [ · 따옴표, 뒤: 끝 · 공백 · , ) ; . ] : · 따옴표
#   (`latency=7s` · `xlatency=120ms` · `latency=120msx`는 토큰이 아니다 — 재검토 F3)
function Get-LatencyTokens([string]$evidence) {
    if ($null -eq $evidence) { return @() }
    return @([regex]::Matches($evidence, '(?<![^\s(\["''])latency=(\d{1,9})ms(?![^\s,);.\]"'':])') | ForEach-Object { [int]$_.Groups[1].Value })
}
# 토큰이 정확히 1개일 때만 그 값. 0개(없음) · 2개 이상(모호 — fail closed)은 $null (호출 측 job-k-3이 개수로 사유를 가른다; 재검토 F2)
function Get-LatencyMs([string]$evidence) {
    $t = @(Get-LatencyTokens $evidence)
    if ($t.Count -ne 1) { return $null }
    return [int]$t[0]
}
# Kafka superUsers 항목이 두 KafkaUser($users) 가운데 하나 또는 와일드카드를 가리키는가: 'User:<name>' · '<name>' · 'CN=<name>' · 'User:CN=<name>[,…]' · '*' · 'User:*'
function Test-ForbiddenSuperUser([string]$principal, [string[]]$users) {
    $p = [string]$principal
    if (StartsOrd $p 'User:') { $p = $p.Substring(5) }
    if (Eq $p '*') { return $true }
    foreach ($u in @($users)) { if ((Eq $p $u) -or (Eq $p "CN=$u") -or (StartsOrd $p "CN=$u,")) { return $true } }
    return $false
}
# SUMMARY 줄 판정 → 문제 문자열 배열(없으면 빈 배열): 정확히 1줄 · ($requireZeroFail이면) fail=0 · pass/fail 수가 파싱된 RESULT 줄 수와 같다
#   (--tail=$tail 에 잘린 로그 · Job 출력 불일치 → FAIL; 적대 리뷰 F7).
function Test-SummaryLine($parsed, [int]$tail, [bool]$requireZeroFail) {
    $sums = @($parsed.summaries)
    if ($sums.Count -ne 1) { return @("$($sums.Count) SUMMARY line(s) in the last $tail log lines (expected exactly 1)") }
    $bad = @()
    if ($requireZeroFail -and [int]$sums[0].fail -ne 0) { $bad += "SUMMARY fail=$($sums[0].fail) (expected 0): $($sums[0].line)" }
    $nPass = @(@($parsed.results) | Where-Object { Eq ([string]$_.status) 'PASS' }).Count
    $nFail = @(@($parsed.results) | Where-Object { Eq ([string]$_.status) 'FAIL' }).Count
    if ($nPass -ne [int]$sums[0].pass -or $nFail -ne [int]$sums[0].fail) { $bad += "SUMMARY pass=$($sums[0].pass) fail=$($sums[0].fail) does not match the RESULT lines seen ($nPass PASS, $nFail FAIL) -- log truncated by --tail=$tail or inconsistent Job output" }
    return @($bad)
}
# id 하나의 RESULT 줄 판정 → 문제 문자열 또는 $null(정확히 1줄이고 PASS). $hideEvidence = FAIL 근거를 사유에 싣지 않는다(acl-list — ACL 행이 들어 있을 수 있다).
function Test-ResultId($parsed, [string]$id, [bool]$hideEvidence = $false) {
    $hits = @(@($parsed.results) | Where-Object { Eq ([string]$_.id) $id })
    if ($hits.Count -eq 0) { return "no RESULT line for $id" }
    if ($hits.Count -gt 1) { return "$($hits.Count) RESULT lines for $id (expected exactly 1)" }
    if (-not (Eq ([string]$hits[0].status) 'PASS')) {
        if ($hideEvidence) { return "${id}: RESULT FAIL" }
        return "${id}: RESULT FAIL -- $(Clip ([string]$hits[0].evidence) 120)"
    }
    return $null
}
# 검사 Job 조회 + 로그(--tail=50) — 캐시. 반환 @{ obj; error; logs; logsError }. Job이 없으면 logs를 부르지 않는다(error에 사유).
#   Job이 있으면 succeeded와 무관하게 로그를 읽는다(실패한 Job의 RESULT 줄도 증거다 — 상태는 job-*-1이 따로 본다).
function Get-JobState([string]$job) {
    $key = "job/$job"
    if ($script:lookups.ContainsKey($key)) { return $script:lookups[$key] }
    $st = @{ obj = $null; error = $null; logs = $null; logsError = $null }
    try { $st.obj = Get-KubeOne $assertNs 'jobs.batch' $job } catch { $st.error = "Job $assertNs/${job}: lookup failed: $(Clip (Mask-Text $_.Exception.Message) 200)" }
    if ($null -eq $st.error -and $null -eq $st.obj) { $st.error = "Job $assertNs/$job not found ($assertJobNote)" }
    if ($null -eq $st.error) {
        try {
            $r = Invoke-Kubectl @('-n', $assertNs, 'logs', "job/$job", "--tail=$logTail")
            if ($r.code -ne 0) { $st.logsError = "kubectl logs job/$job --tail=$logTail failed (exit $($r.code)): $(Clip $r.err 200)" }
            elseif ([string]::IsNullOrWhiteSpace($r.out)) { $st.logsError = "Job $assertNs/$job logs are empty" }
            else { $st.logs = $r.out }
        } catch { $st.logsError = "kubectl logs job/${job}: $(Clip (Mask-Text $_.Exception.Message) 200)" }
    }
    $script:lookups[$key] = $st
    return $st
}
function Test-JobSucceeded([string]$job) {
    $st = Get-JobState $job
    if ($null -ne $st.error) { return @('FAIL', $st.error) }
    $s = PropPath $st.obj @('status', 'succeeded'); $f = PropPath $st.obj @('status', 'failed')
    if ($null -eq $s -or [int]$s -lt 1) { return @('FAIL', "Job $assertNs/$job has not succeeded (status.succeeded=$(Format-Value $s), status.failed=$(Format-Value $f))") }
    return @('PASS', "Job $assertNs/$job succeeded=$s")
}
# 로그가 있으면 파싱 결과, 없으면 @('FAIL', 사유)를 돌려준다
function Get-ParsedJobLog([string]$job) {
    $st = Get-JobState $job
    if ($null -ne $st.error) { return @{ fail = $st.error } }
    if ($null -ne $st.logsError) { return @{ fail = $st.logsError } }
    return @{ fail = $null; parsed = (ConvertFrom-AssertLog $st.logs) }
}

# ---------- 0. 게이트(fail closed — 출처: cluster.tests.ps1 §0. 게이트) ----------
$k = Get-Command kubectl -CommandType Application -ErrorAction SilentlyContinue
if ($null -ne $k) { $script:kubectl = @($k)[0].Source; Pass 'gate-1' "kubectl found" }
else { Fail 'gate-1' 'kubectl not found on PATH -- no cluster access (cluster/kubectl unavailable)'; $script:clusterReason = 'kubectl missing' }

$kc = $env:KUBECONFIG
if ([string]::IsNullOrWhiteSpace($kc)) {
    Fail 'gate-2' 'KUBECONFIG is not set -- no cluster (agent-view token kubeconfig required; cluster unavailable)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG not set' }
} elseif ($kc.IndexOf([IO.Path]::PathSeparator) -ge 0) {
    Fail 'gate-2' 'KUBECONFIG must be a single file path (path list not supported)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG is a path list' }
} elseif (-not (Test-Path -LiteralPath $kc -PathType Leaf)) {
    Fail 'gate-2' 'KUBECONFIG file not found -- no cluster (cluster unavailable)'
    if ($null -eq $script:clusterReason) { $script:clusterReason = 'KUBECONFIG file not found' }
} else { $script:kubeconfig = $kc; Pass 'gate-2' 'KUBECONFIG set (single existing file)' }

if ($null -eq $script:clusterReason) {
    try {
        $r = Invoke-Kubectl @('auth', 'whoami', '-o', 'json')
        if ($r.code -ne 0) { throw "kubectl auth whoami failed (exit $($r.code)): $($r.err)" }
        $who = ConvertFrom-JsonStrict $r.out 'kubectl auth whoami'
        $username = [string](PropPath $who @('status', 'userInfo', 'username'))
        if (Eq $username $expectedUser) { Pass 'gate-3' "context user is $expectedUser" }
        else { Fail 'gate-3' "context user is '$username', expected $expectedUser (admin/other kubeconfig refused)"; $script:clusterReason = 'context user is not agent-view' }
    } catch {
        Fail 'gate-3' "kubectl auth whoami unusable -- cluster unreachable or not agent-view: $(Mask-Text $_.Exception.Message)"
        $script:clusterReason = 'cluster unreachable (whoami failed)'
    }
} else { Fail 'gate-3' "cluster unavailable ($script:clusterReason)" }

# ---------- 1. Kafka(Strimzi) — T055 ----------
ClusterAssert 'kafka-1' {
    $k = Get-KafkaCr
    if ($null -ne $k.error) { return @('FAIL', (Format-StrimziError "Kafka $kafkaNs/$kafkaCluster" 'kafkas' $k.error)) }
    if ($null -eq $k.obj) { return @('FAIL', "Kafka $kafkaNs/$kafkaCluster not found (T055)") }
    $o = $k.obj; $bad = @()
    $rs = Get-ReadyState $o
    if (-not $rs.ok) { $bad += $rs.text }
    $ver = [string](PropPath $o @('spec', 'kafka', 'version'))
    if (-not (Eq $ver $kafkaVersion)) { $bad += "spec.kafka.version=$(Format-Value $ver) (expected $kafkaVersion)" }
    $auto = Prop (PropPath $o @('spec', 'kafka', 'config')) 'auto.create.topics.enable'
    $autoOk = ($auto -is [bool] -and -not $auto) -or ($auto -is [string] -and (Eq $auto 'false'))
    if (-not $autoOk) { $bad += "spec.kafka.config[auto.create.topics.enable]=$(Format-Value $auto) (expected false; absent = broker default true)" }
    $so = Annotation $o 'argocd.argoproj.io/sync-options'
    if (-not (Eq $so $syncOptions)) { $bad += "annotation argocd.argoproj.io/sync-options=$(Format-Value $so) (expected exactly '$syncOptions')" }
    if ($bad.Count -gt 0) { return @('FAIL', "Kafka $kafkaNs/${kafkaCluster}: $(Format-Problems $bad)") }
    return @('PASS', "Kafka $kafkaNs/$kafkaCluster Ready=True, spec.kafka.version=$kafkaVersion, auto.create.topics.enable=false, sync-options=$syncOptions")
}
ClusterAssert 'kafka-2' {
    $k = Get-KafkaCr
    if ($null -ne $k.error) { return @('FAIL', (Format-StrimziError "Kafka $kafkaNs/$kafkaCluster" 'kafkas' $k.error)) }
    if ($null -eq $k.obj) { return @('FAIL', "Kafka $kafkaNs/$kafkaCluster not found (T055)") }
    $o = $k.obj; $bad = @()
    $listeners = @(PropArr $o @('spec', 'kafka', 'listeners'))
    $hit = @($listeners | Where-Object { Eq ([string](Prop $_ 'name')) $listenerName })
    if ($hit.Count -ne 1) {
        $bad += "listener named $listenerName x$($hit.Count) (expected exactly 1; listeners: [$((@($listeners | ForEach-Object { [string](Prop $_ 'name') })) -join ', ')])"
    } else {
        $l = $hit[0]
        $port = Prop $l 'port'
        if (-not (Eq "$port" $listenerPort)) { $bad += "listener ${listenerName}: port=$(Format-Value $port) (expected $listenerPort)" }
        $tls = Prop $l 'tls'
        if (-not ($tls -is [bool] -and $tls)) { $bad += "listener ${listenerName}: tls=$(Format-Value $tls) (expected true)" }
        $auth = PropPath $l @('authentication', 'type')
        if (-not (Eq ([string]$auth) $listenerAuth)) { $bad += "listener ${listenerName}: authentication.type=$(Format-Value $auth) (expected $listenerAuth)" }
    }
    # 이름이 tls 가 아닌 listener도 전부 TLS + 인증이어야 한다(인증 없는 listener는 ACL 우회 경로 — T055 선언값에는 listener가 tls 하나뿐)
    foreach ($l in @($listeners | Where-Object { -not (Eq ([string](Prop $_ 'name')) $listenerName) })) {
        $ln = [string](Prop $l 'name'); $ltls = Prop $l 'tls'; $lauth = PropPath $l @('authentication', 'type')
        if (-not ($ltls -is [bool] -and $ltls) -or [string]::IsNullOrEmpty([string]$lauth)) { $bad += "listener ${ln}: tls=$(Format-Value $ltls), authentication.type=$(Format-Value $lauth) (every declared listener must be TLS with authentication)" }
    }
    $authz = PropPath $o @('spec', 'kafka', 'authorization', 'type')
    if (-not (Eq ([string]$authz) $authorizationType)) { $bad += "spec.kafka.authorization.type=$(Format-Value $authz) (expected $authorizationType)" }
    # superUsers 는 ACL을 통째로 우회한다 — 두 KafkaUser(또는 '*')가 들어 있으면 user-2 의 판정이 무의미해지므로 FAIL(T055 선언값에는 superUsers 없음)
    $userNames = @($userAcl.Keys | ForEach-Object { "$_" })
    $supers = @(@(PropArr $o @('spec', 'kafka', 'authorization', 'superUsers')) | ForEach-Object { [string]$_ })
    $badSupers = @($supers | Where-Object { Test-ForbiddenSuperUser $_ $userNames })
    if ($badSupers.Count -gt 0) { $bad += "spec.kafka.authorization.superUsers grants unlimited access to $((@($badSupers | ForEach-Object { "'$_'" })) -join ', ') (the user-2 ACL check would be bypassed; T055 declares no superUsers)" }
    if ($bad.Count -gt 0) { return @('FAIL', "Kafka $kafkaNs/${kafkaCluster}: $(Format-Problems $bad)") }
    return @('PASS', "Kafka $kafkaNs/$kafkaCluster listener ${listenerName}: port $listenerPort, tls=true, authentication $listenerAuth; authorization $authorizationType; $($listeners.Count) listener(s), all TLS with authentication; $($supers.Count) superUser(s) (none for $($userNames -join ', ') or '*')")
}

# ---------- 2. KafkaNodePool · Kafka 노드 pod — T055 ----------
ClusterAssert 'pool-1' {
    $p = Get-NodePools
    if ($null -ne $p.error) { return @('FAIL', (Format-StrimziError "KafkaNodePool ns $kafkaNs" 'kafkanodepools' $p.error)) }
    $pools = @(Select-Cluster $p.items)
    if ($pools.Count -ne 1) {
        $names = @($pools | ForEach-Object { Name $_ })
        $tail = if ($pools.Count -gt 0) { ": $($names -join ', ')" } elseif (@($p.items).Count -eq 0) { ' (T055)' } else { " (pools with another cluster label: $(@(@($p.items) | ForEach-Object { "$(Name $_)=$(Format-Value (Label $_ 'strimzi.io/cluster'))" }) -join ', '))" }
        return @('FAIL', "expected exactly 1 KafkaNodePool labelled strimzi.io/cluster=$kafkaCluster in ns $kafkaNs, got $($pools.Count)$tail")
    }
    $pool = $pools[0]; $bad = @()
    $rep = PropPath $pool @('spec', 'replicas')
    if (-not (Eq "$rep" '1')) { $bad += "spec.replicas=$(Format-Value $rep) (expected 1)" }
    $roles = @(@(PropArr $pool @('spec', 'roles')) | ForEach-Object { [string]$_ })
    if (-not (SetEq $roles $poolRoles)) { $bad += "spec.roles=[$((SortOrd $roles) -join ', ')] (expected exactly {broker, controller})" }
    # Ready 조건이 있으면 그 값(장래 대비), 없으면 status.replicas=1(upstream 1.2.0: KafkaNodePool status에는 경고 조건만 있다 — 머리 주석)
    $c = Condition $pool 'Ready'
    if ($null -ne $c) {
        $s = [string](Prop $c 'status')
        if (-not (Eq $s 'True')) { $bad += "Ready condition status=$(Format-Value $s) (expected True)$(Format-ConditionNote $c)" }
        $readyText = 'Ready=True'
    } else {
        $sr = PropPath $pool @('status', 'replicas')
        if ($null -eq $sr) { $bad += 'no Ready condition and status.replicas absent (the operator has not reconciled this pool)' }
        elseif (-not (Eq "$sr" '1')) { $bad += "no Ready condition and status.replicas=$(Format-Value $sr) (expected 1)" }
        $readyText = 'status.replicas=1 (no Ready condition -- KafkaNodePool status carries none upstream)'
    }
    if ($bad.Count -gt 0) { return @('FAIL', "KafkaNodePool $kafkaNs/$(Name $pool): $(Format-Problems $bad)") }
    return @('PASS', "KafkaNodePool $kafkaNs/$(Name $pool) (cluster $kafkaCluster): replicas 1, roles {broker, controller}, $readyText")
}
ClusterAssert 'pool-2' {
    $pp = Get-KafkaPods
    if ($null -ne $pp.error) { return @('FAIL', "Kafka pods ns ${kafkaNs}: lookup failed: $(Clip $pp.error 240)") }
    $all = @($pp.items)
    $nodePods = @($all | Where-Object { (Eq (Label $_ 'strimzi.io/component-type') 'kafka') -or ($null -ne (Label $_ 'strimzi.io/pool-name')) })
    if ($nodePods.Count -eq 0) {
        $seen = if ($all.Count -eq 0) { '' } else { " [$((@($all | ForEach-Object { "$(Name $_) component-type=$(Format-Value (Label $_ 'strimzi.io/component-type')) pool-name=$(Format-Value (Label $_ 'strimzi.io/pool-name'))" })) -join ', ')]" }
        return @('FAIL', "no Kafka node pod in ns $kafkaNs (label strimzi.io/cluster=$kafkaCluster plus strimzi.io/component-type=kafka or strimzi.io/pool-name); pods with the cluster label: $($all.Count)$seen (T055)")
    }
    $nn = Get-Nodes
    if ($null -ne $nn.error) { return @('FAIL', "nodes: lookup failed: $(Clip $nn.error 240)") }
    # 값 타입은 object — role 라벨이 없는 노드는 $null 로 남겨 사유가 role=<absent> 로 찍힌다([string] 캐스팅도, [string, string] 사전도 $null 을 '' 로 바꾼다; 재검토 F6)
    $nodeRole = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($n in @($nn.items)) { $nodeRole[(Name $n)] = (Label $n 'role') }
    $bad = @(); $placed = @()
    foreach ($pod in $nodePods) {
        $phase = [string](PropPath $pod @('status', 'phase')); $node = [string](PropPath $pod @('spec', 'nodeName'))
        if (-not (Eq $phase 'Running')) { $bad += "$(Name $pod): phase=$(Format-Value $phase) (expected Running)" }
        # CrashLoopBackOff 중인 pod도 phase 는 Running 이다(K8s: 컨테이너 하나라도 실행 · 기동 · 재시작 중이면 Running) — Ready 조건이 잡는다(적대 리뷰 F2)
        $pr = Condition $pod 'Ready'
        $prs = if ($null -ne $pr) { [string](Prop $pr 'status') } else { $null }
        if (-not (Eq $prs 'True')) { $bad += "$(Name $pod): pod condition Ready=$(Format-Value $prs) (expected True; phase Running alone also matches CrashLoopBackOff)$(if ($null -ne $pr) { Format-ConditionNote $pr })" }
        if ([string]::IsNullOrEmpty($node)) { $bad += "$(Name $pod): not scheduled (spec.nodeName empty)" }
        elseif (-not $nodeRole.ContainsKey($node)) { $bad += "$(Name $pod): node '$node' is not in the node list" }
        elseif (-not (Eq $nodeRole[$node] $poolNodeRole)) { $bad += "$(Name $pod): node '$node' has role=$(Format-Value $nodeRole[$node]) (expected $poolNodeRole)" }
        $placed += "$(Name $pod)@$node"
    }
    if ($bad.Count -gt 0) { return @('FAIL', "Kafka node pods: $(Format-Problems $bad)") }
    return @('PASS', "$($nodePods.Count) Kafka node pod(s) Running and Ready on role=$poolNodeRole node(s): $($placed -join ', ') (pods with label strimzi.io/cluster=${kafkaCluster}: $($all.Count))")
} 1000

# ---------- 3. KafkaTopic · KafkaUser — T056 ----------
ClusterAssert 'topic-1' {
    $t = Get-Topics
    if ($null -ne $t.error) { return @('FAIL', (Format-StrimziError "KafkaTopic ns $kafkaNs" 'kafkatopics' $t.error)) }
    $topics = @(Select-Cluster $t.items)
    # 토픽 이름 → KafkaTopic 객체들(spec.topicName, 없으면 metadata.name)
    $byName = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal)
    foreach ($x in $topics) {
        $tn = [string](PropPath $x @('spec', 'topicName'))
        if ([string]::IsNullOrEmpty($tn)) { $tn = Name $x }
        if (-not $byName.ContainsKey($tn)) { $byName[$tn] = [System.Collections.Generic.List[object]]::new() }
        $byName[$tn].Add($x)
    }
    $bad = @()
    $missing = @($topicNames4 | Where-Object { -not $byName.ContainsKey($_) })
    if ($missing.Count -gt 0) { $bad += "missing KafkaTopic(s) for cluster ${kafkaCluster}: $($missing -join ', ') (T056)" }
    foreach ($want in $topicNames4) {
        if (-not $byName.ContainsKey($want)) { continue }
        $objs = @($byName[$want].ToArray())
        if ($objs.Count -gt 1) { $bad += "${want}: declared by $($objs.Count) KafkaTopics ($((@($objs | ForEach-Object { Name $_ })) -join ', '))"; continue }
        $o = $objs[0]
        $rs = Get-ReadyState $o
        if (-not $rs.ok) { $bad += "${want}: $($rs.text)" }
        $parts = PropPath $o @('spec', 'partitions')
        if (-not (Eq "$parts" $topicPartitions)) { $bad += "${want}: spec.partitions=$(Format-Value $parts) (expected $topicPartitions)" }
        $reps = PropPath $o @('spec', 'replicas')
        if (-not (Eq "$reps" $topicReplicas)) { $bad += "${want}: spec.replicas=$(Format-Value $reps) (expected $topicReplicas)" }
        $ret = Prop (PropPath $o @('spec', 'config')) 'retention.ms'
        if ($null -eq $ret -or -not (Eq "$ret" $topicRetentionMs)) { $bad += "${want}: spec.config[retention.ms]=$(Format-Value $ret) (expected $topicRetentionMs)" }
    }
    $extra = @(SortOrd @($byName.Keys | Where-Object { -not (Contains $topicNames4 $_) }))
    if ($bad.Count -gt 0) { return @('FAIL', "KafkaTopics (cluster $kafkaCluster, $($topics.Count) object(s)): $(Format-Problems $bad)") }
    $extraText = if ($extra.Count -eq 0) { '0' } else { "$($extra.Count) ($($extra -join ', '))" }
    return @('PASS', "$($topicNames4.Count) KafkaTopics Ready (partitions $topicPartitions, replicas $topicReplicas, retention.ms $topicRetentionMs): $($topicNames4 -join ', '); other topics in ${kafkaCluster}: $extraText")
} 1000
ClusterAssert 'user-1' {
    $u = Get-Users
    if ($null -ne $u.error) { return @('FAIL', (Format-StrimziError "KafkaUser ns $kafkaNs" 'kafkausers' $u.error)) }
    $users = @(Select-Cluster $u.items)
    $bad = @(); $secrets = @()
    foreach ($name in @($userAcl.Keys | ForEach-Object { "$_" })) {
        $hit = @($users | Where-Object { Eq (Name $_) $name })
        if ($hit.Count -ne 1) { $bad += "KafkaUser ${name}: $($hit.Count) object(s) with label strimzi.io/cluster=$kafkaCluster (expected exactly 1) (T056)"; continue }
        $o = $hit[0]
        $rs = Get-ReadyState $o
        if (-not $rs.ok) { $bad += "${name}: $($rs.text)" }
        $at = PropPath $o @('spec', 'authentication', 'type')
        if (-not (Eq ([string]$at) $userAuth)) { $bad += "${name}: spec.authentication.type=$(Format-Value $at) (expected $userAuth)" }
        $zt = PropPath $o @('spec', 'authorization', 'type')
        if (-not (Eq ([string]$zt) $userAuthz)) { $bad += "${name}: spec.authorization.type=$(Format-Value $zt) (expected $userAuthz)" }
        $sec = [string](PropPath $o @('status', 'secret'))
        if ([string]::IsNullOrEmpty($sec)) { $bad += "${name}: status.secret empty (no credential Secret name yet)" } else { $secrets += $sec }
    }
    if ($bad.Count -gt 0) { return @('FAIL', "KafkaUsers (cluster $kafkaCluster, $($users.Count) object(s)): $(Format-Problems $bad)") }
    return @('PASS', "KafkaUsers $(@($userAcl.Keys) -join ', ') Ready=True, authentication $userAuth, authorization $userAuthz, status.secret set ($($secrets -join ', '))")
}
ClusterAssert 'user-2' {
    $u = Get-Users
    if ($null -ne $u.error) { return @('FAIL', (Format-StrimziError "KafkaUser ns $kafkaNs" 'kafkausers' $u.error)) }
    $users = @(Select-Cluster $u.items)
    $bad = @(); $ok = @()
    foreach ($name in @($userAcl.Keys | ForEach-Object { "$_" })) {
        $want = $userAcl[$name]
        $hit = @($users | Where-Object { Eq (Name $_) $name })
        if ($hit.Count -ne 1) { $bad += "KafkaUser ${name}: $($hit.Count) object(s) (expected exactly 1) (T056)"; continue }
        $acls = @(PropArr $hit[0] @('spec', 'authorization', 'acls'))
        $own = @($acls | Where-Object { Test-AclWritesPrefix $_ ([string]$want.write) })
        $cross = @($acls | Where-Object { Test-AclWritesPrefix $_ ([string]$want.deny) $true })   # 교차 판정은 fail closed(deny 만 제외)
        if ($own.Count -eq 0) { $bad += "${name}: no topic Write ACL covering $($want.write)* (literal or prefix) among $($acls.Count) ACL(s)" }
        if ($cross.Count -gt 0) { $bad += "${name}: topic Write ACL also covers $($want.deny)* (cross-env): $((@($cross | ForEach-Object { Format-Acl $_ })) -join ', ')" }
        if ($own.Count -gt 0 -and $cross.Count -eq 0) { $ok += "${name}: topic Write on $($want.write)* only ($($own.Count) of $($acls.Count) ACLs)" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', "KafkaUser ACLs: $(Format-Problems $bad)") }
    return @('PASS', "$($ok -join '; ') -- no cross-env Write")
} 1000

# ---------- 4. Dragonfly — T057 ----------
ClusterAssert 'df-1' {
    $bad = @()
    foreach ($name in $dragonflyNames) {
        $d = Get-OneLookup "deploy/$name" { Get-KubeOne $dragonflyNs 'deployments.apps' $name }
        if ($null -ne $d.error) { $bad += "Deployment $dragonflyNs/${name}: lookup failed: $(Clip $d.error 200)"; continue }
        if ($null -eq $d.obj) { $bad += "Deployment $dragonflyNs/$name not found (T057)"; continue }
        $o = $d.obj; $p = @()
        $c = Condition $o 'Available'
        if ($null -eq $c -or -not (Eq ([string](Prop $c 'status')) 'True')) { $p += "not Available (readyReplicas=$(Format-Value (PropPath $o @('status', 'readyReplicas'))))$(if ($null -ne $c) { Format-ConditionNote $c })" }
        # Available=True 는 replicas 0 에서 공허하다(컨트롤러: availableReplicas >= replicas - maxUnavailable) — 선언 형상은 단일 replica(RWO PVC + Recreate; 적대 리뷰 F3)
        $want = PropPath $o @('spec', 'replicas'); $avail = PropPath $o @('status', 'availableReplicas')
        if (-not (Eq "$want" '1')) { $p += "spec.replicas=$(Format-Value $want) (expected 1)" }
        if ($null -eq $avail -or -not (Eq "$avail" '1')) { $p += "status.availableReplicas=$(Format-Value $avail) (expected 1; Available=True is vacuous at 0 replicas)" }
        $containers = @(PropArr $o @('spec', 'template', 'spec', 'containers'))
        if ($containers.Count -ne 1) { $p += "$($containers.Count) containers (expected exactly 1: $((@($containers | ForEach-Object { [string](Prop $_ 'name') })) -join ', '))" }
        else {
            $c0 = $containers[0]
            $tokens = @(@(PropArr $c0 @('command')) + @(PropArr $c0 @('args')) | ForEach-Object { [string]$_ })
            if (-not (Test-FlagValue $tokens 'maxmemory' $dragonflyMaxMemory)) { $p += "args lack --maxmemory=$dragonflyMaxMemory (got $(Format-Value @(Get-FlagValues $tokens 'maxmemory')))" }
            if (-not (Test-FlagValue $tokens 'aclfile' $dragonflyAclFile)) { $p += "args lack --aclfile $dragonflyAclFile (got $(Format-Value @(Get-FlagValues $tokens 'aclfile')))" }
            if (Test-FlagPresent $tokens 'requirepass') { $p += 'args carry --requirepass (passwords must come from the aclfile only)' }
            # absl 플래그 라이브러리의 간접 경로: --flagfile(파일에서 플래그 읽기) · --fromenv/--tryfromenv(FLAGS_<name> 환경변수에서 읽기)로 --requirepass가 숨을 수 있다(재검토 F4)
            foreach ($f in @('flagfile', 'fromenv', 'tryfromenv')) { if (Test-FlagPresent $tokens $f) { $p += "args carry --$f (absl flags can import --requirepass from a file or from FLAGS_* environment variables; T057 declares none)" } }
            # 환경변수 경로(DFLY_requirepass · DFLY_PASSWORD · envFrom)로 들어오는 비밀번호 — 이름만 보고 값은 읽지 않는다(적대 리뷰 F6)
            $envNames = @(@(PropArr $c0 @('env')) | ForEach-Object { [string](Prop $_ 'name') })
            foreach ($n in $dragonflyPasswordEnv) { if (Contains $envNames $n) { $p += "env $n set (requirepass via the environment; passwords must come from the aclfile only)" } }
            if (@(PropArr $c0 @('envFrom')).Count -gt 0) { $p += "envFrom present ($($dragonflyPasswordEnv -join '/') cannot be ruled out without reading the referenced Secret/ConfigMap; T057 declares no envFrom)" }
        }
        $grace = PropPath $o @('spec', 'template', 'spec', 'terminationGracePeriodSeconds')
        if (-not (Eq "$grace" $dragonflyGrace)) { $p += "terminationGracePeriodSeconds=$(Format-Value $grace) (expected $dragonflyGrace)" }
        $strategy = PropPath $o @('spec', 'strategy', 'type')
        if (-not (Eq ([string]$strategy) $dragonflyStrategy)) { $p += "strategy.type=$(Format-Value $strategy) (expected $dragonflyStrategy)" }
        $am = PropPath $o @('spec', 'template', 'spec', 'automountServiceAccountToken')
        if (-not ($am -is [bool] -and -not $am)) { $p += "automountServiceAccountToken=$(Format-Value $am) (expected false; absent = default true)" }
        if ($p.Count -gt 0) { $bad += "Deployment $dragonflyNs/${name}: $($p -join '; ')" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', (Format-Problems $bad)) }
    return @('PASS', "Deployments $((@($dragonflyNames | ForEach-Object { "$dragonflyNs/$_" })) -join ', '): Available, replicas 1/1, 1 container, --maxmemory=$dragonflyMaxMemory, --aclfile $dragonflyAclFile, no --requirepass (args, env, envFrom), terminationGracePeriodSeconds=$dragonflyGrace, strategy $dragonflyStrategy, automountServiceAccountToken=false")
} 1000
ClusterAssert 'df-2' {
    $bad = @()
    foreach ($name in $dragonflyNames) {
        $s = Get-OneLookup "svc/$name" { Get-KubeOne $dragonflyNs 'services' $name }
        if ($null -ne $s.error) { $bad += "Service $dragonflyNs/${name}: lookup failed: $(Clip $s.error 200)"; continue }
        if ($null -eq $s.obj) { $bad += "Service $dragonflyNs/$name not found (T057)"; continue }
        $ports = @(@(PropArr $s.obj @('spec', 'ports')) | ForEach-Object { "$(Prop $_ 'port')" })
        if (-not (Contains $ports $dragonflyPort)) { $bad += "Service $dragonflyNs/${name}: ports [$($ports -join ', ')] lack $dragonflyPort" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', (Format-Problems $bad)) }
    return @('PASS', "Services $((@($dragonflyNames | ForEach-Object { "$dragonflyNs/$_" })) -join ', ') expose port $dragonflyPort")
}

# ---------- 5. 검사 Job 로그 — kafka-assert(R30: kcat 대신 클러스터 안 Job) ----------
ClusterAssert 'job-k-1' { return (Test-JobSucceeded $kafkaJob) }
ClusterAssert 'job-k-2' {
    $g = Get-ParsedJobLog $kafkaJob
    if ($null -ne $g.fail) { return @('FAIL', $g.fail) }
    $parsed = $g.parsed; $bad = @()
    foreach ($id in $kafkaJobIds) { $x = Test-ResultId $parsed $id; if ($null -ne $x) { $bad += $x } }
    $bad += @(Test-SummaryLine $parsed $logTail $true)
    if ($bad.Count -gt 0) { return @('FAIL', "Job $assertNs/$kafkaJob log: $(Format-Problems $bad)") }
    $sums = @($parsed.summaries)
    return @('PASS', "$((@($kafkaJobIds | ForEach-Object { "$_ PASS" })) -join ', '), SUMMARY pass=$($sums[0].pass) fail=0 matches $(@($parsed.results).Count) RESULT line(s) (last $logTail log lines)")
} 1000
# spec US3 AC3(produce→consume 왕복 5초 내)는 메시지 경로 기준이다. Job의 벽시계 `<n>s`는 JVM 2회 기동 + 컨슈머 --timeout-ms 20000 유휴 대기를 포함해
#   항상 ≥ 20 s 이므로 판정값이 아니다 — Job이 찍는 `latency=<n>ms`(마커 수신 시각 − CreateTime; T056)로 판정하고 벽시계는 사유에만 적는다.
ClusterAssert 'job-k-3' {
    $g = Get-ParsedJobLog $kafkaJob
    if ($null -ne $g.fail) { return @('FAIL', $g.fail) }
    $hits = @(@($g.parsed.results) | Where-Object { Eq ([string]$_.id) 'roundtrip' })
    if ($hits.Count -ne 1) { return @('FAIL', "roundtrip: $($hits.Count) RESULT line(s) (expected exactly 1) -- no latency to read") }
    $ev = [string]$hits[0].evidence
    if (-not (Eq ([string]$hits[0].status) 'PASS')) { return @('FAIL', "roundtrip: RESULT FAIL -- $(Clip $ev 120) (no PASS evidence to read the latency from)") }
    $sec = Get-ElapsedSeconds $ev
    $wall = if ($null -ne $sec) { " ${sec}s" } else { '' }
    $toks = @(Get-LatencyTokens $ev)
    if ($toks.Count -gt 1) { return @('FAIL', "roundtrip evidence has $($toks.Count) latency=<n>ms tokens (expected exactly 1; ambiguous, fail closed): $(Clip $ev 120)") }
    $ms = Get-LatencyMs $ev
    if ($null -eq $ms) { return @('FAIL', "roundtrip evidence has no latency=<n>ms token (the Job does not emit it yet -- T056 adds it; wall-clock${wall} includes JVM startup and the consumer idle wait): $(Clip $ev 120)") }
    if ($ms -gt $roundtripMaxMs) { return @('FAIL', "roundtrip latency ${ms}ms > ${roundtripMaxMs}ms (spec US3 AC3: produce->consume within 5 s; the Job's own 30 s wall-clock deadline is a separate check)") }
    return @('PASS', "roundtrip latency ${ms}ms <= ${roundtripMaxMs}ms (message path, spec US3 AC3; the Job's wall clock${wall} includes JVM startup and the consumer idle wait)")
}

# ---------- 6. 검사 Job 로그 — data-assert Dragonfly 절(redis-cli 대신 클러스터 안 Job; VD-4) ----------
ClusterAssert 'job-d-1' { return (Test-JobSucceeded $dataJob) }
ClusterAssert 'job-d-2' {
    $g = Get-ParsedJobLog $dataJob
    if ($null -ne $g.fail) { return @('FAIL', $g.fail) }
    $parsed = $g.parsed; $bad = @()
    # T057이 더할 다섯 id가 통째로 없으면 한 문제로 모은다(지금 Job 모양 = acl-list · noperm 뿐)
    $missingNew = @($dataJobNewIds | Where-Object { $id = $_; @(@($parsed.results) | Where-Object { Eq ([string]$_.id) $id }).Count -eq 0 })
    if ($missingNew.Count -gt 0) { $bad += "no RESULT line for $($missingNew -join ', ') (the Job does not emit these check ids yet; T057 adds them)" }
    foreach ($id in $dataJobIds) {
        if (Contains $missingNew $id) { continue }
        $x = Test-ResultId $parsed $id (Eq $id 'acl-list')
        if ($null -ne $x) { $bad += $x }
    }
    # SUMMARY 1줄 · pass/fail 수 = 보이는 RESULT 줄 수(pg 절 포함; fail=0 은 pg 절의 몫이라 요구하지 않는다)
    $bad += @(Test-SummaryLine $parsed $logTail $false)
    # VD-4: 패턴 유무만 적는다 — acl-list 근거 또는 EVIDENCE: 블록의 sample-pod 행(다른 사용자 행은 세지 않는다; 내용은 출력하지 않는다)
    $present = $false
    foreach ($h in @(@($parsed.results) | Where-Object { Eq ([string]$_.id) 'acl-list' })) { if ((IndexOrd ([string]$h.evidence) $aclReadOnlyPattern) -ge 0) { $present = $true } }
    foreach ($e in @($parsed.evidence)) { if ([regex]::IsMatch($e, $sampleEvidenceRow) -and (IndexOrd $e $aclReadOnlyPattern) -ge 0) { $present = $true } }
    if (-not $present) { $bad += "pattern $aclReadOnlyPattern absent from the acl-list evidence and from the EVIDENCE: lines on the sample-pod row ($(@($parsed.evidence).Count) EVIDENCE: line(s); other users' rows do not count) (VD-4)" }
    if ($bad.Count -gt 0) { return @('FAIL', "Job $assertNs/$dataJob log (Dragonfly section): $(Format-Problems $bad)") }
    $sums = @($parsed.summaries)
    return @('PASS', "$($dataJobIds -join ', ') PASS; pattern $aclReadOnlyPattern present on the sample-pod row (VD-4); SUMMARY pass=$($sums[0].pass) fail=$($sums[0].fail) matches $(@($parsed.results).Count) RESULT line(s)")
} 1000

# ---------- 요약 ----------
Write-Host ''
Write-Host "$script:pass passed, $script:fail failed, $script:skip skipped"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
