# tests/platform/data.tests.ps1 — US3 데이터 플랫폼 단언: CNPG Cluster pg-main · Database 4 · DatabaseRole 6 · 백업(ScheduledBackup · Backup · 버킷) ·
#   data-assert Job 로그 · 런타임 Deployment의 -migrate 참조 0 (T050, test-first)
# Run: $env:KUBECONFIG=<agent-view 토큰 kubeconfig>; pwsh -NoProfile -File tests/platform/data.tests.ps1
#      (보통은 tests/platform/run-platform-tests.ps1이 agent-view 신원 게이트를 지난 뒤 이 파일을 실행한다)
# Exit 0 = 실패 0(SKIP 허용), 1 = 실패 ≥ 1. 외부 프레임워크 없음. 자체 완결(공용 헬퍼 없음 — 러너는 flat 발견): 헬퍼는
#   tests/platform/cluster.tests.ps1(Clip · Pass/Fail/Skip · ClusterAssert · Eq/SortOrd/Contains/Except/StartsOrd/EndsOrd/IndexOrd ·
#   Prop/PropPath/PropArr/Name/Ns/Label · Mask-Text · Remove-WithRetry · Invoke-Native · Invoke-Oci · Invoke-Kubectl ·
#   ConvertFrom-JsonStrict · Get-KubeList · Read-TasksMd · Get-TaskLineState · 게이트 gate-1..3)와
#   tests/platform/ingress.tests.ps1(ConvertTo-UtcInstant)에서 같은 이름 · 같은 동작으로 복사했다(임시 파일 접두만 data-tests-*).
#   Items · Get-KubeOne은 복사본에 모양 검사를 더했다(Items: kind가 List로 끝나고 items가 JSON 배열이어야 한다 — items가 null · 객체 · 문자열 ·
#   없음이면 throw = 그 단언의 FAIL; Get-KubeOne: 기대 kind 불일치는 throw). 쓰지 않는 SetEq · PropNames는 복사하지 않았다. 문자열 판정은 전부 ordinal.
# 출력: 항목별 `PASS|FAIL|SKIP <id>: …` 한 줄, 마지막 줄 `N passed, N failed, N skipped`.
#
# 현재 상태(T050 시점 — FAIL이 기대값): CNPG operator(T052) · Cluster pg-main + ObjectStore + ScheduledBackup(T053) · Database/DatabaseRole(T054) ·
#   data-assert Job의 Argo CD Application이 아직 없다. 그래서 pg/db/role/backup 단언은 "CRD not installed (T052 …)"로, bucket-1/2는
#   오브젝트 0으로, job-1/2는 Job 없음으로 FAIL하고, env-1만 D3 게이트로 SKIP한다. T052–T054가 끝나면 PASS 후보가 된다(이 하네스는 바뀌지 않는다).
#   소유 과제(tasks.md 문면): ScheduledBackup(immediate 첫 백업 포함) · ObjectStore · 버킷 오브젝트 = T053($scheduledBackupTask),
#   Database · DatabaseRole · Job 검사 id 2개 = T054($dataObjectsTask).
#   Job 검사 id role-attrs · app-session-timeouts 둘은 지금 Job(gitops platform/policies/tests/job-data-assert.yaml, T041)이 내지 않는다 —
#   Job에 더하는 것은 T054의 슬라이스(build-notes). 그때까지 job-2는 "missing RESULT line for role-attrs (…T054…)"로 FAIL한다.
#
# 접근 계약(contracts/hostnames-and-access.md §에이전트 자격):
#   - `$env:KUBECONFIG`(SA agent-view 8h 토큰)로만 접근한다. 미설정 · 파일 없음 · kubectl 부재 · whoami ≠ agent-view는 전부 FAIL(fail closed)
#     — 기본 kubeconfig(~/.kube/config)로 흘러가지 않도록 모든 kubectl 호출에 --kubeconfig를 명시한다. 동사는 get / logs / auth whoami 뿐이다.
#   - Secret 값은 읽지 않는다(agent-view는 Secret get 없음): DatabaseRole의 passwordSecret은 이름만 본다 · Job 로그의 EVIDENCE: 줄은 근거에 옮기지 않는다.
#     CNPG 종류(clusters · backups · scheduledbackups · databases · databaseroles)의 get/list는 agent-view-extra가 준다
#     (gitops platform/policies/rbac-agent-view.yaml — T052가 RBAC에 더할 것은 없다).
#   - OCI는 읽기 전용 프로파일 svc-verify(세션 토큰 → `--auth security_token`; OCI_CLI_AUTH가 설정돼 있으면 그 값을 존중)로 `os object list`만
#     호출한다. stdin은 빈 파일로 리다이렉트한다(세션 토큰이 만료되면 CLI가 "re-authenticate? [Y/n]"를 묻는데 EOF면 Abort → exit 1 → FAIL;
#     세션 갱신은 운영자가 `oci session authenticate --profile-name svc-verify`로 직접 한다). Windows oci.exe의 PSModulePath 처리는
#     cluster.tests.ps1 머리 주석과 같다(호출 동안만 pwsh 7 모듈 경로를 빼고 finally에서 복원).
#   - 버킷 실명은 joshuatech-backup이다(이름 예외 — 계약 · 설계 문서의 jt-backup; docs/runbooks/bootstrap.md §0: joshuatech-tfstate ·
#     joshuatech-backup · joshuatech-backup-platform, IAM 그룹 joshuatech-s3-backup(사용자 svc-s3-backup)이 joshuatech-backup만 접근).
#     pg-main은 그 버킷의 pg-main/ 접두다(플랫폼 백업 k3s/ · vault/는 joshuatech-backup-platform — cluster.tests.ps1 backup-1..3).
#   - 비밀 · 토큰 · kubeconfig 내용 · 개인 경로는 출력하지 않는다(Mask-Text). 근거는 이름 · 개수 · 상태 · UTC 시각뿐이고 오브젝트 이름은
#     pg-main/…/base/… 모양 80자까지만 적는다(D5).
#   - 임시 파일(stderr · oci 리다이렉트)은 finally에서 재시도 삭제한다 — %TEMP%\data-tests-* 잔존 0.
#
# 단계별 SKIP(D3 — 한 곳뿐): env-1의 입력(jt-dev · jt-prod의 Deployment)은 US6 T075 소유다. 두 ns 합쳐 Deployment 0개일 때 tasks.md
#   (기본 ../../specs/003-platform-foundation/tasks.md, -TasksMdPath로 덮어쓰기)에서 `- [ ] T075 ` 줄이 정확히 1개면
#   `SKIP env-1: until T075 deploys the first pod Deployment (no Deployment in jt-dev/jt-prod; T075 unchecked in tasks.md)`,
#   `- [X] T075 `/`- [x] T075 `면 FAIL(`T075 is checked in tasks.md but no Deployment in jt-dev/jt-prod`), tasks.md 오류 · 줄 ≠ 1은 FAIL(fail closed)
#   — cluster.tests.ps1의 Read-TasksMd · Get-TaskLineState와 같은 규칙. 그 밖의 단언에는 SKIP 경로가 없다: 리소스 타입 없음 · 권한 · 통신 ·
#   파싱 실패는 전부 그 단언의 FAIL 사유다(D4 예외 격리 — 단언마다 try/catch, 한 조회의 실패가 다른 단언을 가리지 않는다; 같은 목록은
#   실패까지 캐시해 되풀이 조회하지 않는다). "the server doesn't have a resource type"는 사유에 "CRD not installed (T052 …)"로 적는다.
#
# 단언 ↔ T050 항목(spec US3 수용 시나리오 1 · 2 · 5 · data-model §7 · research CNPG-D5/D10 · tasks.md T050 문면):
#   gate-1..3  kubectl 존재 · KUBECONFIG 단일 파일 · whoami = system:serviceaccount:kube-system:agent-view(fail closed)
#   pg-1       Cluster data/pg-main 존재 · status.phase = 'Cluster in healthy state' · spec.instances = 1 · status.readyInstances = 1
#   pg-2       인스턴스 pod(라벨 cnpg.io/cluster=pg-main,cnpg.io/podRole=instance — initdb/join Job pod는 같은 cluster 라벨을 갖지만 podRole이 없어
#              제외) 전부 Running · 스케줄된 노드의 라벨 role=data(노드 B). 노드 목록을 읽어 대조하되 노드 이름 · ExternalIP는 근거에 쓰지 않는다(라벨 값만)
#   db-1       databases.postgresql.cnpg.io(ns data, spec.cluster.name=pg-main)의 spec.name 집합 = 정확히 {identity_admin, dev_identity_admin,
#              authentik, openfga}(더 있으면 FAIL · 나열; 같은 이름 둘도 FAIL) · 각각 status.applied=true · metadata.generation = status.observedGeneration
#              (다르면 "status stale" FAIL — spec 변경 직후의 오래된 applied=true를 PASS로 세지 않는다). spec.ensure=absent는 존재로 세지 않는다
#              (집합에서 빼고 사유에 "declared absent: …" — CNPG 1.30은 absent를 drop한 뒤에도 status.applied=true를 쓴다). 기대 집합 밖 이름의
#              absent 객체도 db-1/role-1 FAIL이다(fail closed) — 운영 규칙: scratch DB를 drop하려고 gitops에 ensure=absent 객체를 남겨 두면 db-1이
#              계속 FAIL이다; drop이 끝나면 그 객체도 지운다.
#   db-2       spec.owner: identity_admin→identity_admin_owner · dev_identity_admin→dev_identity_admin_owner · authentik→authentik_owner · openfga→openfga_owner
#              (ensure=absent 객체는 후보에서 뺀다 → not found)
#   role-1     databaseroles.postgresql.cnpg.io(ns data, cluster pg-main) spec.name 집합 = 정확히 6개(app 2: identity_admin_app · dev_identity_admin_app +
#              pod owner 2: identity_admin_owner · dev_identity_admin_owner + 공유 owner 2: authentik_owner · openfga_owner) · 각각 status.applied=true ·
#              generation = observedGeneration · ensure=absent 제외(db-1과 같은 규칙)
#   role-2     선언 속성: app 둘 spec.login=true · bypassrls≠true · superuser≠true · createdb/createrole≠true(tasks.md T054 문면);
#              pod owner 둘 bypassrls=true · superuser≠true · createdb/createrole≠true; 공유 owner 둘 superuser≠true;
#              전부 spec.passwordSecret.name 비어 있지 않음(이름만, 값 조회 없음). ensure=absent 객체는 후보에서 뺀다
#   backup-1   scheduledbackups.postgresql.cnpg.io(ns data, cluster pg-main) 정확히 1개 · spec.schedule = '0 0 17 * * *'(02:00 KST) · spec.suspend ≠ true
#              (중지된 스케줄은 한 번도 실행되지 않으므로 백업 체계의 증거가 아니다)
#   backup-2   backups.postgresql.cnpg.io(ns data, cluster pg-main) status.phase=completed ≥ 1 · 가장 최근 completed(stoppedAt, 없으면 startedAt)가
#              지금(UTC)부터 ≤ 25 h(ScheduledBackup이 매일이라 1 h 여유; 둘 다 없으면 FAIL) — 근거: 그 startedAt/stoppedAt(UTC, 문자열 왕복 없음 — ConvertTo-UtcInstant)
#   bucket-1   oci os object list --bucket-name joshuatech-backup --prefix pg-main/ --all --fields name,size,timeCreated: 접두 pg-main/<serverName>/base/
#              (serverName = 클러스터 이름 pg-main — barman-cloud 플러그인 serverName 기본값; 다른 serverName의 오브젝트는 무시) 아래 오브젝트 ≥ 1,
#              그리고 가장 최근 completed Backup의 status.backupId로 시작하는 base 오브젝트 ≥ 1(backup-2 조회 재사용 — completed Backup이 없거나
#              조회가 실패하면 그 사유로 FAIL: "completed Backup ↔ 버킷의 그 백업"을 묶는다)
#   bucket-2   같은 목록에서 WAL 세그먼트만 센다: pg-main/<serverName>/wals/<16hex>/<24hex>[.gz|.bz2|.lz4|.zst|.snappy|.xz] (라벨 .backup · 타임라인
#              .history · .partial 은 제외 — Get-WalSegment). (b) 번호 내림차순 상위 3개의 (timeline, logno, segno)가 연속이면 아카이브 누락 없음
#              (wal_segment_size 16 MB = 로그당 256 세그먼트, FF→00 경계 — Test-WalContiguity; 상위 3개 표본 — endWal 이후 전 구간 연속성은 유휴 가지에서만
#              본다). (c) 신선도: 최신 세그먼트의 time-created 나이 ≤ 900 s
#              또는 (Cluster status.conditions[type=ContinuousArchiving].status=True 그리고 최신 세그먼트 ≥ 가장 최근 completed Backup의 status.endWal
#              그리고 endWal부터 최신까지의 세그먼트 전부가 연속 — Test-WalContiguity를 $floorHex=endWal로 한 번 더 호출; endWal 미만은 무시)
#              — 유휴 클러스터는 archive_timeout이 있어도 활동이 없으면 세그먼트를 전환하지 않으므로 시간 간격 규칙은 거짓 FAIL이 된다(PostgreSQL 문서
#              archive_timeout). 세그먼트 < 3 · 불연속 · 신선도 두 가지 다 아님 · (OR 가지에 필요할 때) Cluster/Backup 조회 실패 · OCI 실패(세션 만료 ·
#              명령 없음 · 파싱 실패)는 전부 FAIL(사유 구분 — Test-WalFreshness)
#   job-1      Job jt-dev/data-assert 존재 · status.failed ≥ 1이면 succeeded와 무관하게 FAIL(backoffLimit 0 — 실패는 대상 시스템의 증거) · 그 뒤
#              status.succeeded ≥ 1(진행 중 · 없음 = FAIL, 사유 구분)
#   job-2      kubectl -n jt-dev logs job/data-assert --tail=50 의 `^RESULT: (PASS|FAIL) <id>` 에서 id 6개(pg-cross-db-denied · catalog-connect-false ·
#              revoke-public · ssl-verify-full · role-attrs · app-session-timeouts)가 각각 정확히 한 줄 · 전부 PASS · `SUMMARY: pass=<n> fail=<n>` 줄 존재(여럿이면
#              마지막 것) · fail=0 · SUMMARY의 pass/fail 수 = RESULT 줄 수(PASS/FAIL 각각 — --tail=50 밖으로 밀린 줄을 잡는다) · 추적 밖 id(acl-list 등)의
#              RESULT FAIL도 문제. 빠진 id · FAIL id · 중복 id · SUMMARY 없음 · fail≠0 · 수 불일치는 FAIL(어떤 id가 어떻게). EVIDENCE: 내용은 근거에
#              옮기지 않는다(id 이름과 PASS/FAIL만). ssl-verify-full RESULT = "pg_stat_ssl 앱 세션 ssl=true"; 교차 DB · 교차 env 거부의 dev 방향 실접속 =
#              pg-cross-db-denied, prod role 방향 카탈로그 = catalog-connect-false, REVOKE CONNECT … FROM PUBLIC 효과 = revoke-public.
#              cluster.tests.ps1 np-2-data-assert(Job 존재 · succeeded · 로그 비어 있지 않음)와 겹치지 않는다(둘 다 읽기만).
#   env-1      ns jt-dev · jt-prod의 Deployment 전부에서 containers + initContainers의 envFrom[].secretRef.name · env[].valueFrom.secretKeyRef.name과
#              volumes[].secret.secretName · volumes[].projected.sources[].secret.name 가운데 -migrate로 끝나는 것 0개(있으면 FAIL · 나열).
#              Deployment 0개면 D3 게이트.
#
# CNPG 1.30 필드 출처(2026-10-07 확인 — release-1.30 브랜치 raw 파일):
#   https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.30/config/crd/bases/postgresql.cnpg.io_databases.yaml
#       status.applied(boolean) · status.observedGeneration · status.message · spec.name · spec.owner · spec.cluster.name · spec.ensure(present|absent, 기본 present)
#   …/config/crd/bases/postgresql.cnpg.io_databaseroles.yaml   status.applied(boolean) · status.observedGeneration · spec.{name, login, superuser, bypassrls,
#       createdb, createrole, passwordSecret.name, cluster.name, ensure}
#   …/config/crd/bases/postgresql.cnpg.io_backups.yaml         status.phase(string) · status.startedAt / stoppedAt(date-time) · status.backupId · status.endWal · spec.cluster.name
#   …/config/crd/bases/postgresql.cnpg.io_scheduledbackups.yaml spec.schedule · spec.suspend(boolean) · spec.cluster.name
#   …/config/crd/bases/postgresql.cnpg.io_clusters.yaml        status.phase(string) · status.readyInstances(integer) · spec.instances(integer, 기본 1) ·
#       status.conditions[](type · status)
#   …/api/v1/cluster_types.go  PhaseHealthy = "Cluster in healthy state" · ConditionContinuousArchiving = "ContinuousArchiving"
#   …/api/v1/backup_types.go  BackupPhaseCompleted = "completed"
#   …/internal/management/controller/database_controller.go  spec.ensure=absent → dropDatabase 뒤 markAsReady(status.applied=true) — db-1이 absent를 빼는 이유
#   …/pkg/utils/labels_annotations.go  라벨 cnpg.io/cluster · cnpg.io/podRole(값 instance)
#   검증 후 결정(T053에서 실측 — 이 하네스의 전제): ① barman-cloud 플러그인의 오브젝트 배치 <prefix><serverName>/{base/<backupId>/…, wals/<16hex>/<24hex>[.ext]}
#   (serverName 기본 = 클러스터 이름; 압축 확장자는 ObjectStore wal.compression 설정에 맞춘다) ② 플러그인 경로에서도 Cluster 조건 ContinuousArchiving이
#   갱신되는지(상수와 소비처만 확인 — bucket-2의 유휴 OR 가지가 기댄다) ③ wal_segment_size 16 MB(로그당 256 세그먼트).
#   미확인(라이브에서만 확인된다): OCI JSON 필드 time-created(cluster.tests.ps1 backup-1..3의 라이브 실측과 같은 이름) · Backup status.phase의 다른 값
#   (failed · running …)은 사유에 그대로 적는다.
#
# 단언 수: 16 = gate 3 + pg 2 + db 2 + role 2 + backup 2 + bucket 2 + job 2 + env 1. SKIP 게이트는 env-1 하나뿐이다.
#
# 매개변수: -TasksMdPath <파일> — env-1 게이트가 읽는 tasks.md를 바꾼다(단위 테스트 tests/scripts/data-tests.tests.ps1이 픽스처를 가리킬 때만 쓴다).
#   기본값은 이 파일 기준 ../../specs/003-platform-foundation/tasks.md이고, 러너(run-platform-tests.ps1)는 인자 없이 실행한다.
param([string]$TasksMdPath = '')
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false   # 자식 프로세스의 0이 아닌 종료 코드를 예외로 바꾸지 않는다
$script:pass = 0
$script:fail = 0
$script:skip = 0
$script:clusterReason = $null      # $null = 게이트 통과; 문자열이면 모든 클러스터 단언이 그 사유로 FAIL
$script:kubectl = $null            # kubectl 실행 파일 경로(게이트 1)
$script:kubeconfig = $null         # $env:KUBECONFIG(게이트 2)
$script:cache = @{}                # Get-KubeList 성공 캐시(cluster.tests.ps1과 같음)
$script:listCache = @{}            # Get-ListCached — 실패까지 캐시(같은 목록을 여러 단언이 쓴다; 실패도 되풀이 조회하지 않는다)

# ---------- 계약 상수(data-model §7 · research CNPG-D5/D10 · 런북 §0) ----------
$expectedUser = 'system:serviceaccount:kube-system:agent-view'
$ociProfile = 'svc-verify'
$backupBucket = 'joshuatech-backup'   # 이름 예외: 계약 · 설계의 jt-backup(머리 주석 「접근 계약」 — 런북 bootstrap.md §0)
$bucketPrefix = 'pg-main/'
$dataNs = 'data'
$clusterName = 'pg-main'
$serverName = $clusterName                   # barman-cloud 플러그인 파라미터 serverName(기본 = 클러스터 이름; T053이 기본값을 바꾸면 여기도 바꾼다)
$basePrefixPath = "$bucketPrefix$serverName/base/"   # pg-main/pg-main/base/<backupId>/…
$walPrefixPath = "$bucketPrefix$serverName/wals/"    # pg-main/pg-main/wals/<16hex>/<24hex>[.ext]
$dataNodeRole = 'data'
$healthyPhase = 'Cluster in healthy state'   # CNPG api/v1 PhaseHealthy(머리 주석 「필드 출처」)
$completedPhase = 'completed'                # CNPG api/v1 BackupPhaseCompleted
$archivingCondition = 'ContinuousArchiving'  # CNPG api/v1 ConditionContinuousArchiving(Cluster status.conditions[].type)
$instancePodSelector = "cnpg.io/cluster=$clusterName,cnpg.io/podRole=instance"
$cnpgOperatorTask = 'T052'    # CNPG operator + CRD
$clusterTask = 'T053'         # Cluster pg-main
$scheduledBackupTask = 'T053' # ScheduledBackup(immediate 첫 백업 포함) · ObjectStore · 버킷 오브젝트 — tasks.md T053 문면
$dataObjectsTask = 'T054'     # Database · DatabaseRole · Job 검사 id 2개 추가
$expectedDbs = @('identity_admin', 'dev_identity_admin', 'authentik', 'openfga')
$expectedOwners = [ordered]@{ 'identity_admin' = 'identity_admin_owner'; 'dev_identity_admin' = 'dev_identity_admin_owner'; 'authentik' = 'authentik_owner'; 'openfga' = 'openfga_owner' }
$appRoles = @('identity_admin_app', 'dev_identity_admin_app')
$podOwnerRoles = @('identity_admin_owner', 'dev_identity_admin_owner')
$sharedOwnerRoles = @('authentik_owner', 'openfga_owner')
$expectedRoles = @($appRoles + $podOwnerRoles + $sharedOwnerRoles)
$expectedSchedule = '0 0 17 * * *'
$assertJobNs = 'jt-dev'
$assertJobName = 'data-assert'
$jobCheckIds = @('pg-cross-db-denied', 'catalog-connect-false', 'revoke-public', 'ssl-verify-full', 'role-attrs', 'app-session-timeouts')
$jobPendingIds = @('role-attrs', 'app-session-timeouts')   # 지금 Job이 내지 않는 id — T054가 더한다(사유에 적는다)
$jobPendingNote = "the Job does not emit this check id yet -- $dataObjectsTask adds role-attrs and app-session-timeouts to job-data-assert.yaml"
$runtimeNs = @('jt-dev', 'jt-prod')
$migrateSuffix = '-migrate'
$envGateTask = 'T075'
$walMinCount = 3             # 연속성을 보는 최신 세그먼트 수
$walFreshMaxSec = 15 * 60    # 최신 WAL 세그먼트가 지금(UTC)으로부터 15분 안이면 신선 — 아니면 유휴 OR 가지(ContinuousArchiving=True + endWal)
$backupMaxAgeSec = 25 * 3600 # ScheduledBackup 0 0 17 * * * = 매일 + 1 h 여유
# env-1 게이트가 읽는 tasks.md(머리 주석 「매개변수」). 사용자 제공 상대 경로는 PSPath로 해석한다(.NET cwd 아님 — CLAUDE.md Known Issues).
# 변수 이름을 매개변수와 다르게 둔다: PowerShell 변수 이름은 대소문자를 가리지 않아 $script:tasksMdPath는 매개변수 $TasksMdPath 그 자체다.
$script:tasksPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../specs/003-platform-foundation/tasks.md'))
if (-not [string]::IsNullOrEmpty($TasksMdPath)) { $script:tasksPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TasksMdPath) }

# ---------- 결과 헬퍼(cluster.tests.ps1 복사) ----------
function Clip([string]$s, [int]$max = 400) {
    if ($null -eq $s) { return '' }
    $s = ($s -replace "`r`n", ' ') -replace "`n", ' '
    if ($s.Length -gt $max) { return $s.Substring(0, $max) + '...' } else { return $s }
}
function Pass([string]$id, [string]$detail, [int]$max = 400) { $script:pass++; Write-Host "PASS ${id}: $(Clip $detail $max)" }
function Fail([string]$id, [string]$detail, [int]$max = 400) { $script:fail++; Write-Host "FAIL ${id}: $(Clip $detail $max)" }
function Skip([string]$id, [string]$detail, [int]$max = 400) { $script:skip++; Write-Host "SKIP ${id}: $(Clip $detail $max)" }

# 클러스터 단언 래퍼: 게이트 실패면 사유와 함께 FAIL(fail closed). $body는 @('PASS'|'FAIL'|'SKIP', detail)을 돌려준다.
# 예외(kubectl 실패·JSON 파싱 실패 등)는 FAIL이다. $clip = 출력 줄 상한(기본 400 — 목록을 나열하는 단언만 1200).
function ClusterAssert([string]$id, [scriptblock]$body, [int]$clip = 400) {
    if ($null -ne $script:clusterReason) { Fail $id "cluster unavailable ($script:clusterReason)" $clip; return }
    $status = 'FAIL'; $detail = ''
    try {
        $r = @(& $body)   # 마지막 두 원소가 (status, detail) — 본문의 우발적 파이프라인 출력이 앞에 섞여도 판정이 흔들리지 않는다
        if ($r.Count -lt 2) { throw "assertion body returned $($r.Count) value(s), expected (status, detail)" }
        $status = [string]$r[$r.Count - 2]; $detail = [string]$r[$r.Count - 1]
    }
    catch { $status = 'FAIL'; $detail = "unhandled $($_.Exception.GetType().Name): $($_.Exception.Message) (line $($_.InvocationInfo.ScriptLineNumber))" }
    switch ($status) {
        'PASS' { Pass $id $detail $clip }
        'SKIP' { Skip $id $detail $clip }
        default { Fail $id $detail $clip }
    }
}

# ---------- 문자열·집합 헬퍼(전부 ordinal — cluster.tests.ps1 복사) ----------
function Eq([string]$a, [string]$b) { return [string]::Equals($a, $b, [StringComparison]::Ordinal) }
function SortOrd($arr) {
    $l = [System.Collections.Generic.List[string]]::new()
    foreach ($x in @($arr)) { if ($null -ne $x) { $l.Add([string]$x) } }
    $l.Sort([StringComparer]::Ordinal)
    return @($l.ToArray())
}
function Contains($arr, [string]$v) { foreach ($x in @($arr)) { if (Eq "$x" $v) { return $true } }; return $false }
function Except($arr, $minus) { return @(@($arr) | Where-Object { -not (Contains $minus "$_") }) }
function StartsOrd([string]$s, [string]$prefix) { return ($null -ne $s) -and $s.StartsWith($prefix, [StringComparison]::Ordinal) }
function EndsOrd([string]$s, [string]$suffix) { return ($null -ne $s) -and $s.EndsWith($suffix, [StringComparison]::Ordinal) }
function IndexOrd([string]$s, [string]$sub) { if ($null -eq $s) { return -1 }; return $s.IndexOf($sub, [StringComparison]::Ordinal) }
# 첫 번째 비어 있지 않은 줄(오류 메시지의 첫 줄만 사유에 쓴다)
function First-Line([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    foreach ($l in @($s -split "`r?`n")) { if (-not [string]::IsNullOrWhiteSpace($l)) { return $l.Trim() } }
    return ''
}
# JSON boolean true 판정: [bool] $true 또는 문자열 'true'/'True'(ordinal). $null · 그 밖의 값은 false.
#   문자열 표기도 받는다 — CRD 스키마(boolean)가 API 경로에서 문자열을 막으므로 거짓 PASS 경로가 아니다(관용 비교는 pg-1의 instances 비교도 같다).
function Test-True($v) {
    if ($null -eq $v) { return $false }
    if ($v -is [bool]) { return [bool]$v }
    return (Eq ([string]$v) 'true') -or (Eq ([string]$v) 'True')
}
function Format-Utc([DateTime]$d) { return $d.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture) }

# ---------- JSON 객체 접근(속성 이름 ordinal 정확 일치; 없으면 $null — cluster.tests.ps1 복사) ----------
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
# 목록 모양 검사(fail closed): kind가 'List'로 끝나고 items가 JSON 배열인 객체만 받는다 — Status 객체 · 단일 객체 · items 없는 List · items가 null/객체/문자열인
#   List는 throw(호출한 단언의 FAIL 사유; kubectl은 빈 목록을 항상 items: []로 낸다). items 값은 PSObject.Properties에서 직접 읽는다(함수 반환 언래핑을
#   거치면 빈 []가 $null이 되어 빈 목록과 null을 구분하지 못한다). 반환은 언래핑된 배열이다 — 호출 측은 반드시 @(Items …)로 감싼다(원소 1개가 스칼라로 풀리는 것을 막는다).
function Items($listObj) {
    $kind = [string](Prop $listObj 'kind')
    $hasItems = $false; $raw = $null
    if ($null -ne $listObj) { foreach ($p in $listObj.PSObject.Properties) { if (Eq $p.Name 'items') { $hasItems = $true; $raw = $p.Value } } }
    if (-not (EndsOrd $kind 'List') -or -not $hasItems -or -not ($raw -is [System.Collections.IList])) { throw "expected a Kubernetes List (kind ending in 'List' with an items[] array), got kind='$kind' items=$(if (-not $hasItems) { 'missing' } elseif ($null -eq $raw) { 'null' } else { $raw.GetType().Name })" }
    return @($raw)
}
function Name($obj) { return [string](PropPath $obj @('metadata', 'name')) }
function Ns($obj) { return [string](PropPath $obj @('metadata', 'namespace')) }
function Label($obj, [string]$key) { $v = PropPath $obj @('metadata', 'labels', $key); if ($null -eq $v) { return $null }; return [string]$v }

# 출력 마스킹: kubeconfig 경로·홈 디렉터리를 <KUBECONFIG>/~로 치환(ordinal; \ 와 / 두 표기 모두) — 개인 경로가 리포트에 남지 않게.
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
# 임시 파일 삭제(자식 프로세스가 핸들을 늦게 놓을 수 있어 3회 재시도)
function Remove-WithRetry([string[]]$paths) {
    foreach ($p in $paths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        for ($i = 1; $i -le 3; $i++) {
            if (-not (Test-Path -LiteralPath $p)) { break }
            try { Remove-Item -LiteralPath $p -Force -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 300 }
        }
    }
}

# ---------- 네이티브 실행(stdout UTF-8 디코드; stderr는 임시 파일; 반환 전 경로 마스킹 — cluster.tests.ps1 복사, 접두 data-tests-) ----------
function Invoke-Native([string]$exe, [string[]]$nativeArgs) {
    $errFile = Join-Path ([IO.Path]::GetTempPath()) ('data-tests-stderr-' + [guid]::NewGuid().ToString('N') + '.txt')
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
# oci — stdin을 빈 파일로(대화형 프롬프트 차단), PSModulePath에서 pwsh 7 모듈 경로($PSHOME)를 호출 동안만 제거(머리 주석 참조).
# 경로 비교는 Windows 파일 시스템이라 OrdinalIgnoreCase.
function Invoke-Oci([string]$exe, [string[]]$ociArgs) {
    $tmp = [IO.Path]::GetTempPath(); $tag = [guid]::NewGuid().ToString('N')
    $inFile = Join-Path $tmp "data-tests-oci-in-$tag.txt"; $outFile = Join-Path $tmp "data-tests-oci-out-$tag.txt"; $errFile = Join-Path $tmp "data-tests-oci-err-$tag.txt"
    $prevModulePath = $env:PSModulePath
    $out = ''; $err = ''; $code = -1
    try {
        [IO.File]::WriteAllText($inFile, '')
        $env:PSModulePath = (@($prevModulePath -split [IO.Path]::PathSeparator) | Where-Object { -not $_.StartsWith($PSHOME, [StringComparison]::OrdinalIgnoreCase) }) -join [IO.Path]::PathSeparator
        $p = Start-Process -FilePath $exe -ArgumentList @($ociArgs | ForEach-Object { if ($_.IndexOf(' ') -ge 0) { "`"$_`"" } else { $_ } }) `
            -RedirectStandardInput $inFile -RedirectStandardOutput $outFile -RedirectStandardError $errFile -NoNewWindow -PassThru
        $timedOut = $false
        if (-not $p.WaitForExit(120000)) {   # 120s 상한 — 초과 시 프로세스 트리 kill + FAIL
            $timedOut = $true
            try { $p.Kill($true) } catch { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
            [void]$p.WaitForExit(5000)
        }
        $code = if ($timedOut) { -1 } else { $p.ExitCode }
        $out = if (Test-Path -LiteralPath $outFile) { [IO.File]::ReadAllText($outFile, [Text.Encoding]::UTF8) } else { '' }
        $err = if (Test-Path -LiteralPath $errFile) { [IO.File]::ReadAllText($errFile, [Text.Encoding]::UTF8) } else { '' }
        if ($timedOut) { $err = "oci timed out after 120s (killed). $err" }
    } finally {
        $env:PSModulePath = $prevModulePath
        Remove-WithRetry @($inFile, $outFile, $errFile)
    }
    return @{ out = (Mask-Text $out); err = (Mask-Text $err.Trim()); code = $code }
}
# kubectl — 항상 --kubeconfig 명시(기본 kubeconfig로 흘러가지 않게) + 요청 타임아웃.
function Invoke-Kubectl([string[]]$kArgs) {
    return Invoke-Native $script:kubectl (@("--kubeconfig=$script:kubeconfig", '--request-timeout=30s') + @($kArgs))
}
function ConvertFrom-JsonStrict([string]$text, [string]$what) {
    if ([string]::IsNullOrWhiteSpace($text)) { throw "empty output from $what (expected JSON)" }
    try { return ($text | ConvertFrom-Json -Depth 64) }
    catch { throw "JSON parse failed for ${what}: $($_.Exception.Message)" }
}
# 리스트 조회(-o json). $kArgs 예: @('get','databases.postgresql.cnpg.io','-n','data'). 실패는 예외(= FAIL).
function Get-KubeList([string[]]$kArgs) {
    $key = ($kArgs -join ' ')
    if ($script:cache.ContainsKey($key)) { return $script:cache[$key] }
    $r = Invoke-Kubectl (@($kArgs) + @('-o', 'json'))
    if ($r.code -ne 0) { throw "kubectl $key failed (exit $($r.code)): $($r.err)" }
    $obj = ConvertFrom-JsonStrict $r.out "kubectl $key"
    $script:cache[$key] = $obj
    return $obj
}
# 단일 리소스 조회 — 없으면 $null(--ignore-not-found), 다른 오류는 예외. 응답 kind가 $expectedKind가 아니면 예외(List · Status 등 다른 모양 — fail closed).
function Get-KubeOne([string]$ns, [string]$kind, [string]$name, [string]$expectedKind) {
    $kArgs = @('get', $kind, $name, '--ignore-not-found', '-o', 'json')
    if (-not [string]::IsNullOrEmpty($ns)) { $kArgs = @('-n', $ns) + $kArgs }
    $r = Invoke-Kubectl $kArgs
    if ($r.code -ne 0) { throw "kubectl get $kind/$name (ns '$ns') failed (exit $($r.code)): $($r.err)" }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return $null }
    $obj = ConvertFrom-JsonStrict $r.out "kubectl get $kind/$name"
    $got = [string](Prop $obj 'kind')
    if (-not (Eq $got $expectedKind)) { throw "kubectl get $kind/$name returned kind '$got' (expected $expectedKind)" }
    return $obj
}

# ---------- 시각(ingress.tests.ps1 복사) ----------
# Kubernetes metav1.Time · OCI time-created → UTC [DateTime](Kind=Utc). 반환 @{ utc = [DateTime] 또는 $null; error = 사유 }
# 문자열로 왕복하지 않는다(T049 테스터 발견 2026-10-07): ConvertFrom-Json(기본 DateKind)은 ISO 8601 문자열을 [DateTime]으로 바꾼다 —
#   'Z'는 Kind=Utc, 오프셋이 있으면 그 시각을 로컬 시각으로 바꾼 Kind=Local, 오프셋이 없으면 Kind=Unspecified. 이 값을 "$x"로 문자열화해
#   RoundtripKind로 다시 읽으면 오프셋이 사라져 로컬로 읽히므로 Kind=Utc 값이 로컬 오프셋만큼 틀린다(+09:00 머신에서 9시간).
#   [DateTime]: Utc = 그대로 · Local = ToUniversalTime() · Unspecified = UTC로 간주한다(Kubernetes는 metav1.Time을 RFC 3339 UTC('Z')로 직렬화한다).
#   [DateTimeOffset]: UtcDateTime. 문자열: InvariantCulture + AssumeUniversal|AdjustToUniversal(오프셋이 있으면 그 오프셋으로, 없으면 UTC로).
function ConvertTo-UtcInstant($value) {
    if ($null -eq $value) { return @{ utc = $null; error = 'is absent' } }
    if ($value -is [DateTimeOffset]) { return @{ utc = $value.UtcDateTime; error = $null } }
    if ($value -is [DateTime]) {
        if ($value.Kind -eq [DateTimeKind]::Utc) { return @{ utc = $value; error = $null } }
        if ($value.Kind -eq [DateTimeKind]::Local) { return @{ utc = $value.ToUniversalTime(); error = $null } }
        return @{ utc = [DateTime]::SpecifyKind($value, [DateTimeKind]::Utc); error = $null }   # Unspecified = UTC(위 근거)
    }
    if ($value -is [string]) {
        $d = [DateTime]::MinValue
        $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
        if ([DateTime]::TryParse($value, [Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$d)) { return @{ utc = $d; error = $null } }
        return @{ utc = $null; error = "unparseable: [$value]" }
    }
    return @{ utc = $null; error = "has unexpected type $($value.GetType().FullName)" }
}

# ---------- tasks.md 게이트(cluster.tests.ps1 복사 — env-1 D3가 쓴다) ----------
# tasks.md는 한 번만 읽는다 — 게이트가 필요할 때만(Deployment가 있으면 과제 상태를 보지 않는다). 실패는 error 문자열(fail closed).
$script:tasksRead = $null
function Read-TasksMd {
    if ($null -ne $script:tasksRead) { return $script:tasksRead }
    $shown = Mask-Text $script:tasksPath
    $res = @{ lines = @(); error = $null }
    try {
        if (-not (Test-Path -LiteralPath $script:tasksPath -PathType Leaf)) { $res.error = "tasks.md is not a readable file: $shown" }
        else { $res.lines = @([IO.File]::ReadAllText($script:tasksPath, [Text.Encoding]::UTF8) -split "`r?`n") }
    } catch { $res.error = "tasks.md unreadable ($shown): $(Clip (Mask-Text $_.Exception.Message) 200)" }
    $script:tasksRead = $res
    return $res
}
# 소유 과제 줄 판정(순수 함수): 줄 맨 앞의 '- [ ] T0NN ' · '- [X] T0NN ' · '- [x] T0NN ' 모양만 센다(ordinal — 들여쓴 줄 · '* [ ]' · 공백 둘 ·
#   더 긴 번호(T0NN0) · 뒤 공백 없는 줄 끝의 T0NN은 세지 않는다). [X]와 [x]는 같다(둘 다 체크됨 — FAIL로 가는 방향).
#   정확히 1줄이어야 한다 — 0줄 · 2줄 이상은 error(fail closed). 반환 @{ state = 'unchecked' | 'checked' | $null; error }
function Get-TaskLineState($lines, [string]$task) {
    $unchecked = 0; $checked = 0
    foreach ($l in @($lines)) {
        $s = [string]$l
        if (StartsOrd $s "- [ ] $task ") { $unchecked++ }
        elseif ((StartsOrd $s "- [X] $task ") -or (StartsOrd $s "- [x] $task ")) { $checked++ }
    }
    $n = $unchecked + $checked
    if ($n -ne 1) { return @{ state = $null; error = "tasks.md has $n task line(s) for $task (expected exactly 1 line starting with '- [ ] $task ', '- [X] $task ' or '- [x] $task ')" } }
    if ($checked -eq 1) { return @{ state = 'checked'; error = $null } }
    return @{ state = 'unchecked'; error = $null }
}

# ---------- 조회 오류 → 사유(D4) ----------
# "the server doesn't have a resource type"는 CRD 미설치다 — $crdTask가 비어 있지 않으면 소유 과제를 적는다(CNPG 종류만 T052; Job · Deployment · pod · node는 '').
function Describe-LookupError([string]$msg, [string]$what, [string]$crdTask) {
    if (-not [string]::IsNullOrEmpty($crdTask) -and (IndexOrd $msg "doesn't have a resource type") -ge 0) {
        return "$what lookup failed: CRD not installed ($crdTask deploys the CNPG operator and its CRDs) -- $(Clip (First-Line $msg) 200)"
    }
    return "$what lookup failed: $(Clip $msg 240)"
}
# 목록 조회(실패까지 캐시). 반환 @{ ok; items; reason }
function Get-ListCached([string[]]$kArgs, [string]$what, [string]$crdTask = '') {
    $key = ($kArgs -join ' ')
    if ($script:listCache.ContainsKey($key)) { return $script:listCache[$key] }
    $res = @{ ok = $false; items = @(); reason = '' }
    try { $res.items = @(Items (Get-KubeList $kArgs)); $res.ok = $true }
    catch { $res.reason = (Describe-LookupError $_.Exception.Message $what $crdTask) }
    $script:listCache[$key] = $res
    return $res
}
# ns data의 CNPG 하위 객체(Database · DatabaseRole · Backup · ScheduledBackup) 가운데 spec.cluster.name = pg-main인 것. 반환 @{ ok; items; reason }
function Get-PgChildren([string]$plural, [string]$what) {
    $r = Get-ListCached @('get', "$plural.postgresql.cnpg.io", '-n', $dataNs) "$what list in ns $dataNs" $cnpgOperatorTask
    if (-not $r.ok) { return $r }
    return @{ ok = $true; items = @($r.items | Where-Object { Eq ([string](PropPath $_ @('spec', 'cluster', 'name'))) $clusterName }); reason = '' }
}
# Cluster pg-main 조회(한 번만 — pg-1과 bucket-2의 유휴 OR 가지가 같은 객체를 쓴다; 실패까지 캐시). 반환 @{ ok; obj($null = 없음); reason }
$script:clusterLookup = $null
function Get-ClusterCached {
    if ($null -ne $script:clusterLookup) { return $script:clusterLookup }
    $res = @{ ok = $false; obj = $null; reason = '' }
    try { $res.obj = Get-KubeOne $dataNs 'clusters.postgresql.cnpg.io' $clusterName 'Cluster'; $res.ok = $true }
    catch { $res.reason = (Describe-LookupError $_.Exception.Message "Cluster $dataNs/$clusterName" $cnpgOperatorTask) }
    $script:clusterLookup = $res
    return $res
}
# 가장 최근 completed Backup(backup-2 · bucket-1의 backupId 교차 확인 · bucket-2의 endWal이 같은 것을 쓴다 — 한 번만 고른다).
#   최근 = stoppedAt(없으면 startedAt) UTC 내림차순 — 문자열 왕복 없이(ConvertTo-UtcInstant). 반환 @{ ok; backup; name; started; stopped; key; completedCount; reason }
$script:latestBackup = $null
function Get-LatestCompletedBackup {
    if ($null -ne $script:latestBackup) { return $script:latestBackup }
    $res = @{ ok = $false; backup = $null; name = ''; started = $null; stopped = $null; key = [DateTime]::MinValue; completedCount = 0; reason = '' }
    $r = Get-PgChildren 'backups' 'Backup'
    if (-not $r.ok) { $res.reason = $r.reason; $script:latestBackup = $res; return $res }
    $completed = @($r.items | Where-Object { Eq ([string](PropPath $_ @('status', 'phase'))) $completedPhase })
    $res.completedCount = $completed.Count
    if ($completed.Count -eq 0) {
        if ($r.items.Count -eq 0) { $res.reason = "no Backup for cluster $clusterName in ns $dataNs (the first ScheduledBackup run has not happened; $scheduledBackupTask)" }
        else {
            $phases = @($r.items | ForEach-Object { "$(Name $_)=$([string](PropPath $_ @('status', 'phase')))" })
            $res.reason = "0 completed Backup(s) for cluster $clusterName ($($r.items.Count) Backup objects: $($phases -join ', '))"
        }
        $script:latestBackup = $res; return $res
    }
    $rows = @(foreach ($b in $completed) {
            $st = ConvertTo-UtcInstant (PropPath $b @('status', 'startedAt')); $sp = ConvertTo-UtcInstant (PropPath $b @('status', 'stoppedAt'))
            $key = if ($null -ne $sp.utc) { $sp.utc } elseif ($null -ne $st.utc) { $st.utc } else { [DateTime]::MinValue }
            @{ obj = $b; name = (Name $b); started = $st; stopped = $sp; key = $key }
        })
    $latest = @($rows | Sort-Object -Property @{ Expression = { $_.key }; Descending = $true })[0]
    $res.backup = $latest.obj; $res.name = $latest.name; $res.started = $latest.started; $res.stopped = $latest.stopped; $res.key = $latest.key; $res.ok = $true
    $script:latestBackup = $res
    return $res
}
# spec.name 집합 비교(db-1 · role-1 공용, 순수 함수): spec.ensure=absent는 존재로 세지 않는다(집합에서 빼고 사유 "declared absent" — CNPG 1.30은 absent를
#   drop한 뒤에도 status.applied=true를 쓴다). 남은 것으로 정확 일치 + 같은 이름 둘 금지 + 기대 이름마다 status.applied=true +
#   metadata.generation = status.observedGeneration(다르면 "status stale" — spec 변경 직후의 오래된 applied=true). 반환 @{ ok; problems; names }
function Test-NamedSet($objs, [string[]]$expected, [string]$kind) {
    $objs = @($objs)
    $problems = [System.Collections.Generic.List[string]]::new()
    $absent = @($objs | Where-Object { Eq ([string](PropPath $_ @('spec', 'ensure'))) 'absent' } | ForEach-Object { [string](PropPath $_ @('spec', 'name')) })
    $objs = @($objs | Where-Object { -not (Eq ([string](PropPath $_ @('spec', 'ensure'))) 'absent') })
    if ($absent.Count -gt 0) { $problems.Add("declared absent (spec.ensure=absent): $((SortOrd $absent) -join ', ')") }
    $names = @($objs | ForEach-Object { [string](PropPath $_ @('spec', 'name')) })
    if ($objs.Count -eq 0) { $problems.Add("no $kind for cluster $clusterName in ns $dataNs ($dataObjectsTask deploys them)"); return @{ ok = $false; problems = @($problems); names = @() } }
    $missing = @(Except $expected $names); $extra = @(Except $names $expected)
    if ($missing.Count -gt 0) { $problems.Add("missing: $((SortOrd $missing) -join ', ')") }
    if ($extra.Count -gt 0) { $problems.Add("unexpected (not in the SP-1 set): $((SortOrd $extra) -join ', ')") }
    $counts = [System.Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
    foreach ($n in $names) { if ($counts.ContainsKey($n)) { $counts[$n]++ } else { $counts[$n] = 1 } }
    $dups = @($counts.Keys | Where-Object { $counts[$_] -gt 1 })
    if ($dups.Count -gt 0) { $problems.Add("duplicate spec.name: $((SortOrd $dups) -join ', ')") }
    $notApplied = @(); $stale = @()
    foreach ($o in $objs) {
        $n = [string](PropPath $o @('spec', 'name'))
        if (-not (Contains $expected $n)) { continue }
        $applied = PropPath $o @('status', 'applied')
        if (-not (Test-True $applied)) { $notApplied += "$n(status.applied='$applied')" }
        $gen = PropPath $o @('metadata', 'generation'); $og = PropPath $o @('status', 'observedGeneration')
        if ($null -ne $gen -and -not (Eq "$og" "$gen")) { $stale += "$n(generation=$gen observedGeneration='$og')" }
    }
    if ($notApplied.Count -gt 0) { $problems.Add("not applied: $((SortOrd $notApplied) -join ', ')") }
    if ($stale.Count -gt 0) { $problems.Add("status stale: $((SortOrd $stale) -join ', ')") }
    return @{ ok = ($problems.Count -eq 0); problems = @($problems); names = @($names) }
}
# Job 로그 판정(순수 함수): `^RESULT: (PASS|FAIL) <id>` 줄에서 기대 id마다 정확히 1줄 · PASS, `SUMMARY: pass=<n> fail=<n>`(여럿이면 마지막) fail=0,
#   SUMMARY의 pass/fail 수 = RESULT 줄 수(PASS/FAIL 각각 — 스크립트 교체 · --tail=50 밖으로 밀린 줄을 잡는다), 추적 밖 id의 RESULT FAIL도 문제.
#   근거 텍스트는 옮기지 않는다(id와 PASS/FAIL만). 반환 @{ ok; problems; summary = @{ pass; fail } 또는 $null }
function Test-JobLog([string[]]$lines, [string[]]$ids, [string[]]$pendingIds, [string]$pendingNote) {
    $counts = [System.Collections.Generic.Dictionary[string, int]]::new([StringComparer]::Ordinal)
    $last = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    $failedIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $summary = $null; $passLines = 0; $failLines = 0
    foreach ($raw in @($lines)) {
        $l = [string]$raw
        $m = [regex]::Match($l, '\ARESULT: (PASS|FAIL) (\S+)')
        if ($m.Success) {
            $id = $m.Groups[2].Value
            if ($counts.ContainsKey($id)) { $counts[$id]++ } else { $counts[$id] = 1 }
            $last[$id] = $m.Groups[1].Value
            if (Eq $m.Groups[1].Value 'PASS') { $passLines++ } else { $failLines++; [void]$failedIds.Add($id) }
            continue
        }
        $s = [regex]::Match($l, '\ASUMMARY: pass=(\d+) fail=(\d+)\s*\z')
        if ($s.Success) { $summary = @{ pass = [int]$s.Groups[1].Value; fail = [int]$s.Groups[2].Value } }
    }
    $problems = [System.Collections.Generic.List[string]]::new()
    foreach ($id in @($ids)) {
        if (-not $counts.ContainsKey($id)) {
            if (Contains $pendingIds $id) { $problems.Add("missing RESULT line for $id ($pendingNote)") } else { $problems.Add("missing RESULT line for $id") }
            continue
        }
        if ($counts[$id] -ne 1) { $problems.Add("$($counts[$id]) RESULT lines for $id (expected exactly 1)"); continue }
        if (-not (Eq $last[$id] 'PASS')) { $problems.Add("RESULT FAIL for $id") }
    }
    foreach ($id in @(SortOrd @($failedIds))) { if (-not (Contains $ids $id)) { $problems.Add("RESULT FAIL for $id (outside the tracked set)") } }
    if ($null -eq $summary) { $problems.Add('no SUMMARY line (expected "SUMMARY: pass=<n> fail=<n>")') }
    else {
        if ($summary.fail -ne 0) { $problems.Add("SUMMARY fail=$($summary.fail) (expected 0; pass=$($summary.pass))") }
        if ($summary.pass -ne $passLines -or $summary.fail -ne $failLines) { $problems.Add("SUMMARY pass=$($summary.pass) fail=$($summary.fail) does not match the RESULT lines (PASS $passLines, FAIL $failLines) -- output may be truncated by --tail=50") }
    }
    return @{ ok = ($problems.Count -eq 0); problems = @($problems); summary = $summary }
}
# ---------- WAL 세그먼트(순수 함수 — 지금 시각 · 유휴 근거를 주입한다) ----------
# PostgreSQL WAL 파일 이름 24 hex(대문자) = timeline 8 + logno 8 + segno 8. 반환 @{ hex; timeline; logno; segno } 또는 $null(모양이 아님)
function ConvertTo-WalTuple([string]$walName) {
    if ($null -eq $walName) { return $null }
    $m = [regex]::Match($walName, '\A([0-9A-F]{8})([0-9A-F]{8})([0-9A-F]{8})\z')
    if (-not $m.Success) { return $null }
    return @{ hex = $walName; timeline = [Convert]::ToUInt32($m.Groups[1].Value, 16); logno = [Convert]::ToUInt32($m.Groups[2].Value, 16); segno = [Convert]::ToUInt32($m.Groups[3].Value, 16) }
}
# 오브젝트 이름 → WAL 세그먼트 레코드. <walPrefixPath><16hex>/<24hex>[.gz|.bz2|.lz4|.zst|.snappy|.xz]만 세그먼트다 — 라벨 파일(<seg>.<off>.backup[.ext]) ·
#   타임라인 히스토리(<n>.history) · .partial · 다른 serverName · base/ 는 $null. 반환 @{ name; file; hex; timeline; logno; segno; utc; error }
function Get-WalSegment([string]$name, [string]$walPrefixPath) {
    if (-not (StartsOrd $name $walPrefixPath)) { return $null }
    $m = [regex]::Match($name.Substring($walPrefixPath.Length), '\A[0-9A-F]{16}/([0-9A-F]{24})(\.(gz|bz2|lz4|zst|snappy|xz))?\z')
    if (-not $m.Success) { return $null }
    $t = ConvertTo-WalTuple $m.Groups[1].Value
    if ($null -eq $t) { return $null }
    return @{ name = $name; file = ($m.Groups[1].Value + $m.Groups[2].Value); hex = $t.hex; timeline = $t.timeline; logno = $t.logno; segno = $t.segno; utc = $null; error = $null }
}
function Format-WalHex([uint32]$timeline, [uint32]$logno, [uint32]$segno) { return ($timeline.ToString('X8') + $logno.ToString('X8') + $segno.ToString('X8')) }
# 연속성 판정: 번호(hex 문자열 ordinal = 숫자 순) 내림차순 상위 $minCount의 (timeline, logno, segno)가 빈틈없이 이어지면 아카이브 누락 없음.
#   wal_segment_size 16 MB = 로그당 256 세그먼트(segno 00..FF; FF→00 경계는 logno+1). $floorHex(가장 최근 completed Backup의 status.endWal)가 비어 있지
#   않으면 상위 $minCount 대신 hex ≥ $floorHex인 세그먼트 전부를 내림차순으로 보고, 가장 낮은 것이 $floorHex 자신이어야 한다(endWal 미만은 무시) —
#   bucket-2의 유휴 가지가 두 번째 호출로 쓴다(상위 3개 표본은 endWal과 그 사이의 누락을 보지 못한다). 반환 @{ ok; detail; newest(상위 1) }
function Test-WalContiguity($segs, [int]$minCount, [string]$floorHex = '') {
    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($s in @($segs)) { if ($null -ne $s) { $list.Add($s) } }
    if ($list.Count -lt $minCount) { return @{ ok = $false; detail = "only $($list.Count) WAL segment object(s) (<16hex>/<24hex>[.gz|.bz2|.lz4|.zst|.snappy|.xz] under the wals/ prefix; .backup/.history/.partial files excluded); need >= $minCount to check archive contiguity"; newest = $null } }
    $list.Sort([Comparison[object]] { param($a, $b) [string]::CompareOrdinal([string]$b.hex, [string]$a.hex) })
    $floor = -not [string]::IsNullOrEmpty($floorHex)
    if ($floor) {
        if ($null -eq (ConvertTo-WalTuple $floorHex)) { return @{ ok = $false; detail = "WAL archive floor '$floorHex' is not a WAL segment name"; newest = $list[0] } }
        $top = @($list | Where-Object { [string]::CompareOrdinal([string]$_.hex, $floorHex) -ge 0 })
        if ($top.Count -eq 0) { return @{ ok = $false; detail = "WAL archive gap: no WAL segment object >= endWal $floorHex"; newest = $list[0] } }
        $lowest = $top[$top.Count - 1]
        if (-not (Eq ([string]$lowest.hex) $floorHex)) { return @{ ok = $false; detail = "WAL archive gap: endWal $floorHex of the latest completed Backup is not in the archive (lowest segment >= endWal is $($lowest.file))"; newest = $top[0] } }
        $where = "WAL archive gap between endWal $floorHex and the newest segment"
    } else { $top = @($list.GetRange(0, $minCount).ToArray()); $where = 'WAL archive gap' }
    for ($i = 0; $i -lt $top.Count - 1; $i++) {
        $a = $top[$i]; $b = $top[$i + 1]
        if ($a.segno -gt 0) { $expTl = [uint32]$a.timeline; $expLog = [uint32]$a.logno; $expSeg = [uint32]($a.segno - 1) }
        elseif ($a.logno -gt 0) { $expTl = [uint32]$a.timeline; $expLog = [uint32]($a.logno - 1); $expSeg = [uint32]0xFF }
        else { return @{ ok = $false; detail = "${where}: $($a.file) is the first segment of timeline $($a.timeline); cannot check contiguity across timelines"; newest = $top[0] } }
        $expected = Format-WalHex $expTl $expLog $expSeg
        if (-not (Eq ([string]$b.hex) $expected)) { return @{ ok = $false; detail = "${where}: $($a.file) is not immediately preceded by $($b.file) (expected $expected)"; newest = $top[0] } }
    }
    if ($floor) { return @{ ok = $true; detail = "all $($top.Count) WAL segment(s) from endWal $floorHex to $($top[0].hex) contiguous (timeline $($top[0].timeline))"; newest = $top[0] } }
    return @{ ok = $true; detail = "newest $minCount WAL segments contiguous (timeline $($top[0].timeline)): $((@($top | ForEach-Object { $_.file })) -join ', ')"; newest = $top[0] }
}
# 신선도 판정: 최신 세그먼트의 time-created 나이 ≤ $freshMaxSec 이면 OK. 아니면 유휴 근거 $evidence(@{ clusterError; archiving; backupError; backupName; endWal })로
#   Cluster 조건 ContinuousArchiving=True 그리고 최신 세그먼트 ≥ 가장 최근 completed Backup의 status.endWal 이어야 OK(유휴면 아카이버가 건강하고
#   마지막 베이스 백업을 덮는 WAL이 있다는 증명). 근거 조회 실패 · 조건 없음/False · endWal 없음/모양 아님/최신보다 큼은 전부 FAIL(사유 구분). 반환 @{ ok; detail }
function Test-WalFreshness($newest, [DateTime]$nowUtc, [int]$freshMaxSec, $evidence) {
    if ($null -eq $newest.utc) { return @{ ok = $false; detail = "newest WAL segment $($newest.file) time-created unusable: $($newest.error)" } }
    $age = ($nowUtc - $newest.utc).TotalSeconds
    $ageText = "$([int][Math]::Round($age))s"
    if ($age -le $freshMaxSec) { return @{ ok = $true; detail = "newest segment $($newest.file) is $ageText old (<= ${freshMaxSec}s)" } }
    $head = "newest WAL segment $($newest.file) is $ageText old (> ${freshMaxSec}s) and the idle-safe evidence does not hold"
    if ($null -eq $evidence) { return @{ ok = $false; detail = "${head}: no idle evidence gathered" } }
    if (-not [string]::IsNullOrEmpty([string]$evidence.clusterError)) { return @{ ok = $false; detail = "${head}: $($evidence.clusterError)" } }
    if ($null -eq $evidence.archiving) { return @{ ok = $false; detail = "${head}: Cluster $dataNs/$clusterName has no $archivingCondition condition" } }
    if (-not (Eq ([string]$evidence.archiving) 'True')) { return @{ ok = $false; detail = "${head}: Cluster condition $archivingCondition is '$($evidence.archiving)' (expected True)" } }
    if (-not [string]::IsNullOrEmpty([string]$evidence.backupError)) { return @{ ok = $false; detail = "${head}: $($evidence.backupError)" } }
    $endWal = [string]$evidence.endWal
    if ([string]::IsNullOrEmpty($endWal)) { return @{ ok = $false; detail = "${head}: latest completed Backup $($evidence.backupName) has no status.endWal" } }
    $ew = ConvertTo-WalTuple $endWal
    if ($null -eq $ew) { return @{ ok = $false; detail = "${head}: status.endWal='$endWal' of Backup $($evidence.backupName) is not a WAL segment name" } }
    if ([string]::CompareOrdinal([string]$newest.hex, $endWal) -lt 0) { return @{ ok = $false; detail = "${head}: newest segment $($newest.file) < status.endWal=$endWal of Backup $($evidence.backupName) (the archive does not cover the latest base backup)" } }
    return @{ ok = $true; detail = "newest segment $($newest.file) is $ageText old (> ${freshMaxSec}s) but idle-safe: $archivingCondition=True and $($newest.hex) >= endWal $endWal of Backup $($evidence.backupName)" }
}
# 유휴 OR 가지의 근거 수집(최신 세그먼트가 신선하지 않을 때만 호출): Cluster 조건(캐시) + 가장 최근 completed Backup(캐시). 조회 실패는 사유 문자열로 둔다.
function Get-IdleArchiveEvidence {
    $ev = @{ clusterError = $null; archiving = $null; backupError = $null; backupName = $null; endWal = $null }
    $c = Get-ClusterCached
    if (-not $c.ok) { $ev.clusterError = $c.reason }
    elseif ($null -eq $c.obj) { $ev.clusterError = "Cluster $dataNs/$clusterName not found ($clusterTask deploys it)" }
    else {
        $cond = @(@(PropArr $c.obj @('status', 'conditions')) | Where-Object { Eq ([string](Prop $_ 'type')) $archivingCondition })
        if ($cond.Count -gt 0) { $ev.archiving = [string](Prop $cond[0] 'status') }
    }
    $lb = Get-LatestCompletedBackup
    if (-not $lb.ok) { $ev.backupError = $lb.reason }
    else { $ev.backupName = $lb.name; $ev.endWal = [string](PropPath $lb.backup @('status', 'endWal')) }
    return $ev
}
# Deployment들의 -migrate Secret 참조(순수 함수): containers + initContainers의 envFrom[].secretRef.name · env[].valueFrom.secretKeyRef.name,
#   그리고 volumes[].secret.secretName · volumes[].projected.sources[].secret.name(마운트 채널 — gitops validate 3.5-⑤와 같은 범위)
function Find-MigrateRefs($deployments, [string]$suffix) {
    $hits = [System.Collections.Generic.List[string]]::new()
    foreach ($d in @($deployments)) {
        $label = "$(Ns $d)/$(Name $d)"
        $podSpec = PropPath $d @('spec', 'template', 'spec')
        foreach ($field in @('initContainers', 'containers')) {
            foreach ($c in @(PropArr $podSpec @($field))) {
                $cn = [string](Prop $c 'name')
                foreach ($ef in @(PropArr $c @('envFrom'))) {
                    $s = [string](PropPath $ef @('secretRef', 'name'))
                    if (EndsOrd $s $suffix) { $hits.Add("$label $field[$cn] envFrom.secretRef=$s") }
                }
                foreach ($e in @(PropArr $c @('env'))) {
                    $s = [string](PropPath $e @('valueFrom', 'secretKeyRef', 'name'))
                    if (EndsOrd $s $suffix) { $hits.Add("$label $field[$cn] env[$([string](Prop $e 'name'))].valueFrom.secretKeyRef=$s") }
                }
            }
        }
        foreach ($v in @(PropArr $podSpec @('volumes'))) {
            $vn = [string](Prop $v 'name')
            $s = [string](PropPath $v @('secret', 'secretName'))
            if (EndsOrd $s $suffix) { $hits.Add("$label volumes[$vn].secret.secretName=$s") }
            foreach ($src in @(PropArr $v @('projected', 'sources'))) {
                $s = [string](PropPath $src @('secret', 'name'))
                if (EndsOrd $s $suffix) { $hits.Add("$label volumes[$vn].projected.secret=$s") }
            }
        }
    }
    return @($hits.ToArray())
}
# OCI 버킷 목록(한 번만 — bucket-1 · bucket-2가 같은 목록을 쓴다). 반환 @{ ok; objects; error }
$script:bucket = $null
function Get-BucketObjects {
    if ($null -ne $script:bucket) { return $script:bucket }
    $res = @{ ok = $false; objects = @(); error = '' }
    $oci = Get-Command oci -CommandType Application -ErrorAction SilentlyContinue
    if ($null -eq $oci) { $res.error = 'oci CLI not found on PATH'; $script:bucket = $res; return $res }
    $auth = if ([string]::IsNullOrWhiteSpace($env:OCI_CLI_AUTH)) { @('--auth', 'security_token') } else { @() }
    $r = Invoke-Oci (@($oci)[0].Source) (@('--profile', $ociProfile) + $auth + @('os', 'object', 'list', '--bucket-name', $backupBucket, '--prefix', $bucketPrefix, '--all', '--fields', 'name,size,timeCreated', '--output', 'json'))
    if ($r.code -ne 0) {
        $first = First-Line $r.err; if ([string]::IsNullOrEmpty($first)) { $first = First-Line $r.out }
        $res.error = "oci os object list --bucket-name $backupBucket --prefix $bucketPrefix failed (exit $($r.code)): $(Clip $first 240)"
        $script:bucket = $res; return $res
    }
    # exit 0 + 빈 stdout = 오브젝트 0(일부 CLI 버전은 빈 목록에 아무것도 찍지 않는다 — 미확인, 라이브에서 확인) → bucket-1/2가 "0 objects"로 FAIL한다
    if ([string]::IsNullOrWhiteSpace($r.out)) { $res.objects = @(); $res.ok = $true; $script:bucket = $res; return $res }
    try { $obj = ConvertFrom-JsonStrict $r.out "oci os object list --prefix $bucketPrefix" } catch { $res.error = $_.Exception.Message; $script:bucket = $res; return $res }
    $res.objects = @(PropArr $obj @('data')); $res.ok = $true
    $script:bucket = $res
    return $res
}

# ---------- 0. 게이트(fail closed — cluster.tests.ps1 복사) ----------
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
        Fail 'gate-3' "kubectl auth whoami unusable -- cluster unreachable or not agent-view: $($_.Exception.Message)"
        $script:clusterReason = 'cluster unreachable (whoami failed)'
    }
} else { Fail 'gate-3' "cluster unavailable ($script:clusterReason)" }

# ---------- 1. Cluster pg-main ----------
ClusterAssert 'pg-1' {
    $cl = Get-ClusterCached
    if (-not $cl.ok) { return @('FAIL', $cl.reason) }
    $c = $cl.obj
    if ($null -eq $c) { return @('FAIL', "Cluster $dataNs/$clusterName not found ($clusterTask deploys it)") }
    $phase = [string](PropPath $c @('status', 'phase')); $inst = PropPath $c @('spec', 'instances'); $ready = PropPath $c @('status', 'readyInstances')
    $bad = @()
    if (-not (Eq $phase $healthyPhase)) { $bad += "status.phase='$phase' (expected '$healthyPhase')" }
    if (-not (Eq "$inst" '1')) { $bad += "spec.instances='$inst' (expected 1)" }
    if (-not (Eq "$ready" '1')) { $bad += "status.readyInstances='$ready' (expected 1)" }
    if ($bad.Count -gt 0) { return @('FAIL', "Cluster $dataNs/${clusterName}: $($bad -join '; ')") }
    return @('PASS', "Cluster $dataNs/${clusterName}: status.phase='$healthyPhase', spec.instances=1, status.readyInstances=1")
}
ClusterAssert 'pg-2' {
    $pods = Get-ListCached @('get', 'pods', '-n', $dataNs, '-l', $instancePodSelector) "instance pods of Cluster $dataNs/$clusterName"
    if (-not $pods.ok) { return @('FAIL', $pods.reason) }
    if ($pods.items.Count -eq 0) { return @('FAIL', "no instance pod with labels $instancePodSelector in ns $dataNs ($clusterTask deploys Cluster $clusterName)") }
    $nodes = Get-ListCached @('get', 'nodes') 'node list'
    if (-not $nodes.ok) { return @('FAIL', $nodes.reason) }
    $roleOf = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
    foreach ($n in $nodes.items) { $roleOf[(Name $n)] = [string](Label $n 'role') }
    $bad = @(); $names = @()
    foreach ($p in $pods.items) {
        $pn = Name $p; $names += $pn
        $phase = [string](PropPath $p @('status', 'phase'))
        if (-not (Eq $phase 'Running')) { $bad += "pod ${pn}: phase '$phase' (expected Running)" }
        $nodeName = [string](PropPath $p @('spec', 'nodeName'))
        if ([string]::IsNullOrEmpty($nodeName)) { $bad += "pod ${pn}: not scheduled (spec.nodeName empty)"; continue }
        if (-not $roleOf.ContainsKey($nodeName)) { $bad += "pod ${pn}: scheduled on a node that is not in the node list"; continue }
        $role = $roleOf[$nodeName]
        if (-not (Eq $role $dataNodeRole)) { $bad += "pod ${pn}: node label role='$role' (expected '$dataNodeRole')" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', ($bad -join '; ')) }
    return @('PASS', "$($pods.items.Count) instance pod(s) Running on role=$dataNodeRole node(s): $((SortOrd $names) -join ', ')")
}

# ---------- 2. Database 4 ----------
ClusterAssert 'db-1' {
    $r = Get-PgChildren 'databases' 'Database'
    if (-not $r.ok) { return @('FAIL', $r.reason) }
    $v = Test-NamedSet $r.items $expectedDbs 'Database'
    if (-not $v.ok) { return @('FAIL', "Database set for cluster ${clusterName}: $($v.problems -join '; ')") }
    return @('PASS', "$($r.items.Count) Database objects for cluster ${clusterName}: $($expectedDbs -join ', ') (all status.applied=true at the current generation)")
} 1200
ClusterAssert 'db-2' {
    $r = Get-PgChildren 'databases' 'Database'
    if (-not $r.ok) { return @('FAIL', $r.reason) }
    $bad = @(); $ok = @()
    foreach ($db in @($expectedOwners.Keys | ForEach-Object { "$_" })) {
        $want = [string]$expectedOwners[$db]
        # spec.ensure=absent 객체는 후보가 아니다(db-1과 같은 규칙 — 삭제 선언된 DB의 owner는 근거가 아니다)
        $hit = @($r.items | Where-Object { (Eq ([string](PropPath $_ @('spec', 'name'))) $db) -and -not (Eq ([string](PropPath $_ @('spec', 'ensure'))) 'absent') })
        if ($hit.Count -eq 0) { $bad += "${db}: not found"; continue }
        $owner = [string](PropPath $hit[0] @('spec', 'owner'))
        if (Eq $owner $want) { $ok += "$db=$owner" } else { $bad += "${db}: spec.owner='$owner' (expected '$want')" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', "Database owners: $($bad -join '; ')") }
    return @('PASS', "Database owners: $($ok -join ', ')")
} 1200

# ---------- 3. DatabaseRole 6 ----------
ClusterAssert 'role-1' {
    $r = Get-PgChildren 'databaseroles' 'DatabaseRole'
    if (-not $r.ok) { return @('FAIL', $r.reason) }
    $v = Test-NamedSet $r.items $expectedRoles 'DatabaseRole'
    if (-not $v.ok) { return @('FAIL', "DatabaseRole set for cluster ${clusterName}: $($v.problems -join '; ')") }
    return @('PASS', "$($r.items.Count) DatabaseRole objects for cluster ${clusterName}: $($expectedRoles -join ', ') (all status.applied=true at the current generation)")
} 1200
ClusterAssert 'role-2' {
    $r = Get-PgChildren 'databaseroles' 'DatabaseRole'
    if (-not $r.ok) { return @('FAIL', $r.reason) }
    $bad = @()
    foreach ($name in $expectedRoles) {
        $hit = @($r.items | Where-Object { (Eq ([string](PropPath $_ @('spec', 'name'))) $name) -and -not (Eq ([string](PropPath $_ @('spec', 'ensure'))) 'absent') })
        if ($hit.Count -eq 0) { $bad += "${name}: not found"; continue }
        $spec = Prop $hit[0] 'spec'
        $p = @()
        if (Contains $appRoles $name) {
            if (-not (Test-True (Prop $spec 'login'))) { $p += 'login must be true' }
            if (Test-True (Prop $spec 'bypassrls')) { $p += 'bypassrls must not be true' }
            if (Test-True (Prop $spec 'superuser')) { $p += 'superuser must not be true' }
            if (Test-True (Prop $spec 'createdb')) { $p += 'createdb must not be true' }       # tasks.md T054 문면: app role도 createdb/createrole false
            if (Test-True (Prop $spec 'createrole')) { $p += 'createrole must not be true' }
        } elseif (Contains $podOwnerRoles $name) {
            if (-not (Test-True (Prop $spec 'bypassrls'))) { $p += 'bypassrls must be true' }
            if (Test-True (Prop $spec 'superuser')) { $p += 'superuser must not be true' }
            if (Test-True (Prop $spec 'createdb')) { $p += 'createdb must not be true' }
            if (Test-True (Prop $spec 'createrole')) { $p += 'createrole must not be true' }
        } else {
            if (Test-True (Prop $spec 'superuser')) { $p += 'superuser must not be true' }
        }
        if ([string]::IsNullOrEmpty([string](PropPath $spec @('passwordSecret', 'name')))) { $p += 'passwordSecret.name is empty' }
        if ($p.Count -gt 0) { $bad += "${name}: $($p -join ', ')" }
    }
    if ($bad.Count -gt 0) { return @('FAIL', "DatabaseRole attributes: $($bad -join '; ')") }
    return @('PASS', "DatabaseRole attributes: app roles ($($appRoles -join ', ')) login=true bypassrls!=true superuser!=true createdb/createrole!=true; pod owners ($($podOwnerRoles -join ', ')) bypassrls=true superuser!=true createdb/createrole!=true; shared owners ($($sharedOwnerRoles -join ', ')) superuser!=true; all 6 name a passwordSecret (value never read)")
} 1200

# ---------- 4. 백업(ScheduledBackup · Backup) ----------
ClusterAssert 'backup-1' {
    $r = Get-PgChildren 'scheduledbackups' 'ScheduledBackup'
    if (-not $r.ok) { return @('FAIL', $r.reason) }
    if ($r.items.Count -ne 1) {
        if ($r.items.Count -eq 0) { return @('FAIL', "no ScheduledBackup for cluster $clusterName in ns $dataNs ($scheduledBackupTask deploys it)") }
        return @('FAIL', "expected exactly 1 ScheduledBackup for cluster $clusterName, got $($r.items.Count): $((@($r.items | ForEach-Object { Name $_ })) -join ', ')")
    }
    $sb = $r.items[0]; $schedule = [string](PropPath $sb @('spec', 'schedule'))
    if (-not (Eq $schedule $expectedSchedule)) { return @('FAIL', "ScheduledBackup $(Name $sb): spec.schedule='$schedule' (expected '$expectedSchedule')") }
    if (Test-True (PropPath $sb @('spec', 'suspend'))) { return @('FAIL', "ScheduledBackup $(Name $sb): spec.suspend=true (the schedule never fires)") }
    return @('PASS', "ScheduledBackup $(Name $sb) for cluster ${clusterName}: spec.schedule='$expectedSchedule' (02:00 KST), not suspended")
}
ClusterAssert 'backup-2' {
    $lb = Get-LatestCompletedBackup
    if (-not $lb.ok) { return @('FAIL', $lb.reason) }
    $startedText = if ($null -ne $lb.started.utc) { Format-Utc $lb.started.utc } else { "($($lb.started.error))" }
    $stoppedText = if ($null -ne $lb.stopped.utc) { Format-Utc $lb.stopped.utc } else { "($($lb.stopped.error))" }
    # 신선도: 가장 최근 completed가 25 h보다 오래되면 백업 체계가 죽은 것이다(ScheduledBackup 매일 + 1 h 여유) — 시각이 둘 다 없으면 판정 불가 = FAIL
    if ($lb.key -eq [DateTime]::MinValue) { return @('FAIL', "latest completed Backup $($lb.name) has neither stoppedAt nor startedAt (startedAt $($lb.started.error); stoppedAt $($lb.stopped.error))") }
    $ageSec = ([DateTime]::UtcNow - $lb.key).TotalSeconds
    if ($ageSec -gt $backupMaxAgeSec) { return @('FAIL', "latest completed Backup $($lb.name) stoppedAt=$stoppedText is $([Math]::Round($ageSec / 3600, 1).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture))h old (> $([int]($backupMaxAgeSec / 3600))h; ScheduledBackup is daily)") }
    return @('PASS', "$($lb.completedCount) completed Backup(s) for cluster $clusterName; latest $($lb.name) startedAt=$startedText stoppedAt=$stoppedText (UTC; latest within $([int]($backupMaxAgeSec / 3600))h)")
}

# ---------- 5. OCI 버킷(svc-verify 읽기 전용) ----------
ClusterAssert 'bucket-1' {
    $b = Get-BucketObjects
    if (-not $b.ok) { return @('FAIL', $b.error) }
    $names = @($b.objects | ForEach-Object { [string](Prop $_ 'name') })
    if ($names.Count -eq 0) { return @('FAIL', "0 objects under $backupBucket/$bucketPrefix (empty listing is not evidence; the first ScheduledBackup run fills it -- $scheduledBackupTask)") }
    $base = @($names | Where-Object { StartsOrd $_ $basePrefixPath })   # serverName 고정 — 다른 serverName(복구 드릴 · 이전 세대)의 오브젝트는 근거가 아니다
    if ($base.Count -eq 0) { return @('FAIL', "no object under $backupBucket/$basePrefixPath ($($names.Count) objects total)") }
    $first = (@(SortOrd $base))[0]   # 원소 1개 배열이 스칼라로 풀려 [0]이 첫 글자가 되지 않도록 @()로 감싼다
    # 교차 확인: 가장 최근 completed Backup의 status.backupId로 시작하는 base 오브젝트 ≥ 1 — "completed Backup ↔ 버킷의 그 백업"
    $lb = Get-LatestCompletedBackup
    if (-not $lb.ok) { return @('FAIL', "$($base.Count) base backup object(s) under $backupBucket/$basePrefixPath (e.g. $(Clip $first 80)) but the completed Backup cross-check is impossible: $($lb.reason)") }
    $backupId = [string](PropPath $lb.backup @('status', 'backupId'))
    if ([string]::IsNullOrEmpty($backupId)) { return @('FAIL', "$($base.Count) base backup object(s) under $backupBucket/$basePrefixPath but the latest completed Backup $($lb.name) has no status.backupId to cross-check") }
    $mine = @($base | Where-Object { StartsOrd $_ "$basePrefixPath$backupId/" })
    if ($mine.Count -eq 0) { return @('FAIL', "$($base.Count) base backup object(s) under $backupBucket/$basePrefixPath but none under $basePrefixPath$backupId/ for the latest completed Backup $($lb.name) (status.backupId=$backupId; e.g. $(Clip $first 80))") }
    return @('PASS', "$($base.Count) base backup object(s) under $backupBucket/$basePrefixPath (e.g. $(Clip $first 80); $($names.Count) objects total); latest completed Backup $($lb.name) backupId=$backupId has $($mine.Count) object(s)")
}
ClusterAssert 'bucket-2' {
    $b = Get-BucketObjects
    if (-not $b.ok) { return @('FAIL', $b.error) }
    $segs = @(foreach ($o in $b.objects) {
            $seg = Get-WalSegment ([string](Prop $o 'name')) $walPrefixPath
            if ($null -eq $seg) { continue }
            $conv = ConvertTo-UtcInstant (Prop $o 'time-created')
            $seg.utc = $conv.utc; $seg.error = $conv.error
            $seg
        })
    $v = Test-WalContiguity $segs $walMinCount
    if (-not $v.ok) { return @('FAIL', "$backupBucket/${walPrefixPath}: $($v.detail)") }
    $now = [DateTime]::UtcNow
    # 유휴 근거는 최신 세그먼트가 신선하지 않을 때만 모은다(둘 다 캐시된 조회라 kubectl 추가 호출은 없다)
    $fresh = ($null -ne $v.newest.utc) -and (($now - $v.newest.utc).TotalSeconds -le $walFreshMaxSec)
    $ev = if ($fresh) { $null } else { Get-IdleArchiveEvidence }
    $f = Test-WalFreshness $v.newest $now $walFreshMaxSec $ev
    if (-not $f.ok) { return @('FAIL', "$backupBucket/${walPrefixPath}: $($f.detail)") }
    if ($fresh) { return @('PASS', "$backupBucket/${walPrefixPath}: $($segs.Count) WAL segment object(s); $($v.detail); $($f.detail)") }
    # 유휴 가지: 상위 3개 표본은 endWal과 그 사이의 누락을 보지 못한다 — endWal부터 최신까지 전 구간이 연속이어야 마지막 베이스 백업부터 빈틈없는 PITR 보장이 선다
    $c = Test-WalContiguity $segs $walMinCount ([string]$ev.endWal)
    if (-not $c.ok) { return @('FAIL', "$backupBucket/${walPrefixPath}: $($c.detail) (idle-safe branch: newest segment $($v.newest.file) is not fresh, so every segment from endWal $($ev.endWal) of Backup $($ev.backupName) up to the newest must be archived)") }
    return @('PASS', "$backupBucket/${walPrefixPath}: $($segs.Count) WAL segment object(s); $($v.detail); $($f.detail); $($c.detail)")
} 1200

# ---------- 6. data-assert Job(자격이 필요한 psql 단언은 Job이 실행 — 로그만 읽는다) ----------
ClusterAssert 'job-1' {
    $j = $null
    try { $j = Get-KubeOne $assertJobNs 'jobs.batch' $assertJobName 'Job' }
    catch { return @('FAIL', (Describe-LookupError $_.Exception.Message "Job $assertJobNs/$assertJobName" '')) }
    if ($null -eq $j) { return @('FAIL', "Job $assertJobNs/$assertJobName not found (assert Job from platform/policies/tests is not deployed yet)") }
    $s = PropPath $j @('status', 'succeeded'); $f = PropPath $j @('status', 'failed'); $a = PropPath $j @('status', 'active')
    $s = if ($null -eq $s) { 0 } else { [int]$s }; $f = if ($null -eq $f) { 0 } else { [int]$f }; $a = if ($null -eq $a) { 0 } else { [int]$a }
    # failed ≥ 1은 succeeded와 무관하게 FAIL: Job 매니페스트가 backoffLimit 0이라 실패는 대상 시스템의 증거이고, 재시도가 통과해도 가려지지 않는다
    if ($f -ge 1) { return @('FAIL', "Job $assertJobNs/$assertJobName has a failed attempt (status.failed=$f, succeeded=$s; backoffLimit 0 means a failure is evidence) -- read its RESULT lines in job-2") }
    if ($s -ge 1) { return @('PASS', "Job $assertJobNs/$assertJobName succeeded (status.succeeded=$s, failed=0)") }
    if ($a -ge 1) { return @('FAIL', "Job $assertJobNs/$assertJobName still running (status.active=$a, succeeded=$s)") }
    return @('FAIL', "Job $assertJobNs/$assertJobName has not succeeded (status.succeeded=$s failed=$f active=$a)")
}
ClusterAssert 'job-2' {
    $r = Invoke-Kubectl @('-n', $assertJobNs, 'logs', "job/$assertJobName", '--tail=50')
    if ($r.code -ne 0) { return @('FAIL', "kubectl -n $assertJobNs logs job/$assertJobName --tail=50 failed (exit $($r.code)): $(Clip (First-Line $r.err) 240)") }
    if ([string]::IsNullOrWhiteSpace($r.out)) { return @('FAIL', "Job $assertJobNs/$assertJobName logs are empty (no RESULT/SUMMARY line)") }
    $v = Test-JobLog @($r.out -split "`r?`n") $jobCheckIds $jobPendingIds $jobPendingNote
    if (-not $v.ok) { return @('FAIL', "Job $assertJobNs/$assertJobName log: $($v.problems.Count) problem(s): $($v.problems -join '; ')") }
    return @('PASS', "Job $assertJobNs/$assertJobName log: RESULT PASS for all $($jobCheckIds.Count) check ids ($($jobCheckIds -join ', ')); SUMMARY pass=$($v.summary.pass) fail=0 (EVIDENCE lines not copied)")
} 1200

# ---------- 7. 런타임 Deployment의 owner 비밀번호 부재(-migrate 참조 0) — D3 게이트 ----------
ClusterAssert 'env-1' {
    $deps = @(); $errs = @()
    foreach ($ns in $runtimeNs) {
        $r = Get-ListCached @('get', 'deployments.apps', '-n', $ns) "Deployment list in ns $ns"
        if (-not $r.ok) { $errs += $r.reason } else { $deps += $r.items }
    }
    if ($errs.Count -gt 0) { return @('FAIL', ($errs -join '; ')) }
    if ($deps.Count -eq 0) {
        $t = Read-TasksMd
        if ($null -ne $t.error) { return @('FAIL', "no Deployment in jt-dev/jt-prod and the state of $envGateTask is unknown: $($t.error)") }
        $st = Get-TaskLineState $t.lines $envGateTask
        if ($null -ne $st.error) { return @('FAIL', "no Deployment in jt-dev/jt-prod and $($st.error)") }
        if (Eq ([string]$st.state) 'checked') { return @('FAIL', "$envGateTask is checked in tasks.md but no Deployment in jt-dev/jt-prod") }
        return @('SKIP', "until $envGateTask deploys the first pod Deployment (no Deployment in jt-dev/jt-prod; $envGateTask unchecked in tasks.md)")
    }
    $refs = @(Find-MigrateRefs $deps $migrateSuffix)
    if ($refs.Count -gt 0) { return @('FAIL', "$($refs.Count) Secret reference(s) ending in '$migrateSuffix' in runtime Deployments (owner credentials belong to the PreSync migrate Job only): $($refs -join '; ')") }
    $names = @($deps | ForEach-Object { "$(Ns $_)/$(Name $_)" })
    return @('PASS', "$($deps.Count) Deployment(s) in jt-dev/jt-prod reference no '*$migrateSuffix' Secret (envFrom.secretRef, env.valueFrom.secretKeyRef, volumes.secret/projected; containers and initContainers): $((SortOrd $names) -join ', ')")
} 1200

# ---------- 요약 ----------
Write-Host ''
Write-Host "$script:pass passed, $script:fail failed, $script:skip skipped"
if ($script:fail -gt 0) { exit 1 } else { exit 0 }
