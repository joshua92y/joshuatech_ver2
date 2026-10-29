# Runbook: restore-drill

> PostgreSQL `pg-main`(CNPG · 버킷 `joshuatech-backup`의 베이스 백업 + WAL)과 플랫폼 백업(Vault 스냅샷 · K3s 번들)의 **복구 런북**이다 — PITR = **클러스터 전체 복원(재해 복구 전용, 모든 pod DB가 함께 되돌아감)** · 단일 DB 복구 = **side Cluster로 PITR → 해당 DB만 `pg_dump` → 운영 클러스터 복원** · Vault 스냅샷 · K3s 번들은 **age 복호화 후 복원**(여기는 입구만 — 정본 `vault-unseal.md` §7 · `bootstrap.md` §7 · `rollback.md`). 작성 근거 = 과제 T058(설계 정본 `specs/003-platform-foundation/design/build-notes.md` 「T058」). **복원 실연은 SP-3**(SC-011 — 수용 위험은 `report.md`)이므로 절차는 소스 · 문서 판독으로 썼고, 미실측 지점은 「VD-n」(§10)으로 표시한다.

## 문서 목적·전제

- **목적**: `pg-main`의 데이터가 사라지거나(노드 B 재이미지 · PVC 손실) 논리적으로 손상됐을 때 버킷의 베이스 백업 + WAL로 되살리는 절차(§3 · §4), 그 전에 복구 지점을 확인하는 절차(§1), Vault · K3s 백업의 복호화 입구(§5 · §6)를 사고 당일 이 문서 하나로 실행할 수 있게 한다.
- **전제 — 사람 · 자격**(운영자 워크스테이션 · PowerShell 7):
  - admin kubeconfig(운영자만 · 비밀번호 관리자 보관 — `bootstrap.md` §3 요약) · agent-view kubeconfig(조회 전용 · 8시간) · `oci` CLI `svc-verify` 세션(60분 · 읽기만 · 갱신 `oci session authenticate --profile-name svc-verify`) · `age` + 오프라인 age 개인키(§5 · §6) · cloudflared Access 경유 `ssh-a` · `ssh-b`(§4 디스크 점검 · §6).
  - gitops 저장소(platform-gitops) PR 작성 권한. **머지 · 승인은 운영자 전용**이다(`.claude/rules/infra.md` — 에이전트는 명령을 준비하고 결과를 읽는다).
- **전제 — 라이브 구성**: CNPG operator 1.30.0 · plugin-barman-cloud v0.14.0(ns `cnpg-system`) · ExternalSecret → Secret `data/oci-s3-backup` · ObjectStore `oci-backups` · ns `data` 정책 `allow-egress-external-443` · `allow-dns`. ns `data`의 정책은 전부 `podSelector: {}`라 이 문서가 만드는 임시 객체(Job · side Cluster · 복구 Job)도 같은 정책을 받는다 — 새 정책 0 · 계약 변경 0.
- **창 표기**(`vault-unseal.md` §0과 같다): **창 A** cloudflared 터널 · **창 B** admin kubectl(변경) · **창 C** port-forward(§5 · §6) · **창 D** vault CLI(§5 · 비밀 취급). 창 B · D의 첫 줄은 vault-unseal §0 「창 시작 체크리스트」다.
- **표기 규칙**:
  - `(agent-view 가능)` = 조회 전용 확인이다. agent-view는 `view` + `agent-view-extra`(노드 · CNPG `clusters` · `backups` · `scheduledbackups` · `databases` · `databaseroles` · ExternalSecret 읽기 — gitops `platform/policies/rbac-agent-view.yaml`)라 **Secret · PV · ObjectStore(`barmancloud.cnpg.io`) · `exec`는 못 한다** → 그런 확인은 운영자다.
  - `--kubeconfig <admin kubeconfig>`가 붙은 명령 = **운영자 전용**(변경 · exec). 에이전트는 실행하지 않는다.
  - 각 절은 목적 · 전제 · 명령 · 기대 출력 · 다음 단계를 가진다(T114 공통 요건 — 목적·전제·절차·검증·되돌리기). 소요 시간은 실측값이 없으면 「미실측」이다.
  - **gitops README** = platform-gitops `platform/cnpg-cluster/README.md`이고, gitops 문서를 가리키는 「§n」은 그 파일의 `## n.` 제목이다(다른 README는 경로를 함께 적는다 — 예: `platform/cnpg-databases/README.md` §5).
- **자리표시자**(뜻은 여기 한 곳에서만 정한다):

| 자리표시자 | 뜻 | 예 |
|---|---|---|
| `<admin kubeconfig>` | 운영자 admin kubeconfig 파일 경로(문서 · 저장소에 적지 않는다) | — |
| `<db>` | 복구할 DB 하나 | `identity_admin` |
| `<그 테이블>` | §4-5 멈춤 분기 오류 문구(`cannot drop … because other objects depend on it`)에 나온 테이블 이름 | — |
| `<side>` | side Cluster 이름 `pg-main-restore-<yyyymmdd>` | `pg-main-restore-20261029` |
| `<ts>` | UTC 시각 `yyyyMMddTHHmmssZ`(버킷 객체 · 파일 이름) | `20261028T173010Z` |
| `<backupId>` | barman 백업 ID `YYYYMMDDTHHMMSS`(UTC) | `20261013T094258` |
| `<N>` | serverName 세대 번호 — 전체 PITR마다 1 증가(`pg-main` = r0) | `1` → `pg-main-r1` |
| `<노드 B 이름>` | 노드 B의 Node 이름(`kubectl get nodes -l role=data`의 NAME) | — |
| `<PR>` · `<40자>` | gitops PR 번호 · 그 PR의 head 커밋 SHA(운영자가 PR 화면에서 읽는다) | — |
| `<오프라인 보관 경로>` | age 개인키가 있는 오프라인 위치(적지 않는다) | — |

- 따옴표 밖의 `<…>`는 PowerShell이 예약 연산자로 보고 그 줄을 거부한다(바꾸지 않은 채로는 실행되지 않는다). 따옴표 안의 자리표시자는 거부되지 않으므로 반드시 바꾼다. 원격 셸 명령(`ssh … "…"`)에는 자리표시자를 두지 않았다 — bash는 `<`를 리다이렉트로 읽는다.
- 매니페스트(yaml 코드 블록)에는 자리표시자를 두지 않았다 — 예시 값(`20261029` · `pg-main-r1` · `2026-10-29T03:00:00Z`)을 실제 값으로 바꾸고, 바꿀 자리는 주석으로 표시했다. §4는 PowerShell 변수(§4-0)로 값을 한 번만 정한다.
- **진입**(사고 당일 — 아래 경로로 바로 간다. 판정 근거 · 데이터 결과는 §2 표):

| 상황 | 경로 |
|---|---|
| 노드 B 재이미지 · 부트 볼륨 교체 · PVC `pg-main-1` 소실 | §1-2 판정(노드 B 없이 — API · svc-verify) → §3-1(2-b′ · 2-c는 해당 없음) |
| 클러스터 전체 논리 손상(여러 DB · 공유 DB 동시) | §1 → §3-1 + `targetTime`(2-b′ 수동 Backup → 2-c 아카이브 정지) |
| 한 DB만 손상 | §1 → §4 |
| Vault 데이터 손실 · 손상 | §5-1 → `vault-unseal.md` §7 |
| K3s 데이터스토어 손실 · 손상 · 롤백 | §5-1 → §6 |

## §0 범위·절대 규칙

- **목적**: 모든 절에 앞서 범위와 어기면 데이터를 잃는 규칙을 고정한다.
- **범위**:
  - **PITR = 클러스터 전체 복원(재해 복구 전용, 모든 pod DB가 함께 되돌아감)** — `pg-main` 안의 DB 전부(pod DB `identity_admin` · `dev_identity_admin` · 공유 DB `authentik` · `openfga` · 부트스트랩 DB `platform`)가 **같은 시점**으로 간다(FR-018 · FR-041). §3.
  - **단일 DB 복구 = side Cluster로 PITR → 해당 DB만 `pg_dump` → 운영 클러스터 복원**(`pg_restore`). 다른 DB는 그대로다. §4.
  - **Vault 스냅샷 · K3s 번들은 age 복호화 후 복원** — 입구(버킷 → 무결성 → 복호화)와 포인터만 둔다. Vault = `vault-unseal.md` §7(§5) · K3s = `bootstrap.md` §7(T114 작성 예정) · `rollback.md`(T106 작성 예정)(§6).
  - 범위 밖: 복원 실연(SP-3 · SC-011) · Kafka 토픽과 Dragonfly 데이터(되돌리지 않는다 — 발산의 뜻은 §4-9) · 알림(T098).
- **절대 규칙**:
  1. 복구는 **항상 새 Cluster 생성**이다 — CNPG에는 제자리(in-place) 복원이 없다(CNPG 1.30 문서 「Recovery」). 같은 이름으로 되살릴 때도 옛 객체를 지우고 다시 만든다(§3-1).
  2. **git이 먼저, 삭제가 그다음.** recovery spec 머지 없이 `kubectl delete cluster pg-main`부터 하면 Argo selfHeal이 initdb 클러스터(빈 DB)를 다시 만든다(gitops `platform/cnpg-cluster/README.md` §5).
  3. **`cnpg.io/skipEmptyWalArchiveCheck` 어노테이션은 금지**한다 — 빈 아카이브 검사를 끄면 다른 클러스터의 WAL 접두에 덮어쓸 수 있다(CNPG 문서의 심각한 데이터 손실 경고). 검사에 걸리면 새 세대 `serverName`으로 간다(§3-1 4단계).
  4. 같은 ObjectStore(`oci-backups`)를 쓰는 클러스터마다 `serverName`은 고유하다 — 아카이브를 쓰는 복구 클러스터는 새 세대 이름(`pg-main-r<N>`), 아카이브하지 않는 side Cluster는 `spec.plugins`를 두지 않는다.
  5. 파괴 단계(Cluster 삭제 · PV 패치 · REVOKE · `pg_restore --clean` · 덤프 · 번들 소거 · hibernation(§3-1 2-c) · DB 자격 Secret 삭제(§3-1 5-b 대안) · 옛 세대 Backup CR 삭제(§3-1 6-2) · PV 삭제(§3-1 6단계 5) · node-password Secret/Node 삭제(§3-1 전제) 등 — 변경 블록은 전부 이 모양)는 **직전 확인 출력 → `Read-Host` 정지점(`yes`가 아니면 `throw`) → 변경** 순서로만 한다. 판정 블록과 변경 블록은 다른 코드 블록이다(`vault-unseal.md` §7 4단계 선례 — 통째 붙여 넣기 사고 방지).
  6. **`k3s server --cluster-reset`은 실행 금지**다 — SQLite 구성에서 실행하면 embedded etcd 전용 명령이라 etcd로 비가역 전환된다(FR-041). §6.
  7. 단일 DB 복구에서 대상 DB(`Database` CR이 관리하는 DB)에 `ALTER DATABASE … ALLOW_CONNECTIONS false`와 `DROP DATABASE`를 쓰지 않는다 — 앞의 것은 superuser까지 막아 복원 자체가 안 되고, 뒤의 것은 `Database` CR(`ensure: present`)이 관리하는 DB를 지운다(gitops `platform/cnpg-databases/README.md` §5).
  8. 비밀 위생은 `vault-unseal.md` §0 「비밀이 새는 6곳」 그대로다. 값(비밀번호 · 토큰 · S3 키)을 화면 · 파일 · 명령줄에 두지 않는다 — 이 문서의 어떤 명령도 비밀 값을 출력하지 않는다. 에이전트는 admin kubeconfig · 운영자 자격을 받지 않는다(agent-view · `svc-verify`만 — `.claude/rules/infra.md`).
  9. `kubectl cnpg` 플러그인을 가정하지 않는다 — SQL은 `kubectl exec <파드> -c postgres -- psql`(파드 안 peer 인증 · 비밀 0)로 한다(T054 C13).
  10. 노드 B 재이미지 · 부트 볼륨 교체 · 인스턴스 재생성 전에는 `bootstrap.md` §2 머리의 선행 조건 ①②③(최신 completed 확인 · 버킷 확인 · 수동 Backup)을 지킨다 — 그 뒤의 PVC 손실은 §3-1로 복구한다.
- **권한 경계**:

| 주체 | 할 수 있는 것 | 이 문서에서 |
|---|---|---|
| 운영자(admin kubeconfig) | apply · create · delete · patch · exec(`psql` · `pg_dump` · `pg_restore`) | 모든 변경 단계 |
| 운영자(GitHub) | gitops PR 머지 · 승인 | §3 PR 머지(운영자 명령) |
| agent-view(에이전트 · 운영자) | get · describe · logs · wait · events · top | 판정 · 관찰 |
| `svc-verify` 세션 | 버킷 `os object list` · `get`(읽기) | §1 · §5 · §6 입구 |

- **다음 단계**: §1 → §2.

## §1 복구 지점 확인 — barman-cloud-backup-list · Backup CR · 버킷

- **목적**: 되돌릴 수 있는 범위 — 가장 오래된 · 최신 completed 베이스 백업과 아카이브된 WAL의 끝 — 를 복구 **전에** 확정한다. CNPG 시나리오(§3 · §4)의 첫 단계다 — Vault · K3s는 §5-1 입구가 복구 지점 확인이다. 클러스터 · 버킷을 바꾸지 않는다(Job 하나를 만들고 지울 뿐이다).
- **전제**: Secret `data/oci-s3-backup`이 있다(ExternalSecret `SecretSynced`) · 노드 B(`role=data`) Ready · 노드 B CPU 여유 ≥ 50m. 노드 B가 없으면(재이미지 중) §1-1 Job을 건너뛰고 §1-2(Backup CR · 버킷 목록 — API · svc-verify만)로 판정한다 · Job은 재조인 뒤(§3-1 6단계 1).
- **다음 단계**: §2 시나리오 선택표.

### §1-1 `barman-cloud-backup-list` Job(운영자 적용)

- **왜 Job인가**: 플러그인 사이드카 이미지는 distroless python3(nonroot) — **셸이 없고**, S3 자격은 컨테이너 env에 **없다**(사이드카가 런타임에 Secret을 API로 읽어 하위 프로세스에만 넘긴다) → `kubectl exec … sh -c 'barman-cloud-backup-list …'`는 할 수 없다(build-notes 「T058」 사실 4). 같은 이미지(digest 고정 — gitops `platform/cnpg/kustomization.yaml`의 `sidecarImage.tag`)로 Job을 띄우면 자격은 `secretKeyRef`로만 컨테이너에 들어가 **값이 운영자 터미널 · argv · 매니페스트를 지나지 않고**, 결과는 로그라 agent-view가 읽는다.
- **기각한 대안**: ⓐ 사이드카에 `kubectl exec`로 python을 띄워 stdin으로 자격 주입 — 비밀이 운영자 파이프를 지나고 재현성이 낮다 ⓑ 워크스테이션에 barman 설치 — S3 키를 클러스터 밖으로 반출한다.
- **인자**(barman 3.19.1 `cloud_cli.py` · `cloud_backup_list.py` 그대로): `--cloud-provider aws-s3 --endpoint-url <OCI S3 호환> --format console <source_url> <server_name>`. `source_url` = ObjectStore의 `destinationPath`(`s3://joshuatech-backup/pg-main/`), `server_name` = 현재 세대 serverName(처음은 `pg-main`). 엔드포인트의 Object Storage 네임스페이스는 비밀이 아니다(gitops ObjectStore · `infra/*/backend.tf`가 이미 쓰는 공개 값).

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pg-main-backup-list
  namespace: data
  labels:
    app.kubernetes.io/name: pg-main-backup-list
    app.kubernetes.io/part-of: restore-drill
spec:
  backoffLimit: 0
  activeDeadlineSeconds: 300
  ttlSecondsAfterFinished: 3600
  template:
    metadata:
      labels:
        app.kubernetes.io/name: pg-main-backup-list
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      nodeSelector:
        role: data
      securityContext:
        runAsNonRoot: true
        runAsUser: 26
        runAsGroup: 26
        fsGroup: 26
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: backup-list
          image: ghcr.io/cloudnative-pg/plugin-barman-cloud-sidecar:v0.14.0@sha256:9880817c285c7afa4d195da2145064d21907405489ed6ec39abe59b1feb558a4
          command:
            - /venv/bin/barman-cloud-backup-list
            - --cloud-provider
            - aws-s3
            - --endpoint-url
            - https://axvjykgvo2m1.compat.objectstorage.ap-chuncheon-1.oraclecloud.com
            - --format
            - console
            - s3://joshuatech-backup/pg-main/
            - pg-main
          env:
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: oci-s3-backup
                  key: ACCESS_KEY_ID
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: oci-s3-backup
                  key: ACCESS_SECRET_KEY
            - name: AWS_DEFAULT_REGION
              valueFrom:
                secretKeyRef:
                  name: oci-s3-backup
                  key: REGION
            - name: AWS_REQUEST_CHECKSUM_CALCULATION
              value: when_required
            - name: AWS_RESPONSE_CHECKSUM_VALIDATION
              value: when_required
            - name: HOME
              value: /tmp
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: [ALL]
          resources:
            requests:
              cpu: 50m
              memory: 128Mi
            limits:
              memory: 256Mi
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

**운영 순서** — ①③④는 판정(읽기) · ②⑥은 변경이다. 블록을 나눴다.

```powershell
# ① 판정(agent-view 가능) — Secret 원천과 노드
kubectl -n data get externalsecret oci-s3-backup        # READY True · STATUS SecretSynced
kubectl get nodes -l role=data                          # 노드 B Ready
```

```powershell
# ② 적용(운영자) — 위 yaml 블록을 $env:TEMP\pg-main-backup-list.yaml로 저장한다(비밀 없음 — Secret은 이름으로만 참조)
kubectl --kubeconfig <admin kubeconfig> apply -f "$env:TEMP\pg-main-backup-list.yaml"
#   job.batch/pg-main-backup-list created
#   같은 이름의 Job이 남아 있으면 새로 돌지 않는다(Job 템플릿은 불변) — ⑥으로 지운 뒤 다시 적용한다
```

```powershell
# ③ 완료 대기 · ④ 결과 읽기(agent-view 가능)
kubectl -n data get pod -l job-name=pg-main-backup-list
#   적용 뒤 30초 안에 Running · Completed가 아니면(Pending · CreateContainerConfigError · ImagePullBackOff) 아래 wait로 가지 말고 실패 분기 표
#   — wait는 실패한 Job에서도 300초를 다 채운 뒤에야 끝난다(Ctrl+C로 끊어도 된다 · 다른 창에서 같은 줄에 -w를 붙여 지켜봐도 된다)
kubectl -n data wait --for=condition=complete job/pg-main-backup-list --timeout=300s
#   job.batch/pg-main-backup-list condition met — timeout이면 아래 실패 분기 표
kubectl -n data logs job/pg-main-backup-list
#   ⑤ 기대 출력 — console 표(열 = Backup ID · End Time · Begin Wal · Archival Status · Name), backupId 오름차순:
#   Backup ID           End Time                 Begin Wal                     Archival Status  Name
#   20261013T094258     2026-10-13 09:43:01      000000010000000000000003                       backup-20261013094258
#   …(마지막 줄 = 최신 베이스 백업 · 30일 보존이 지난 백업은 목록에서 빠진다)
```

- ⑤ 읽는 법(barman 3.19.1 `cloud_backup_list.py`): **Archival Status가 빈 칸**이면 완료(DONE)된 백업 — 복구 기반으로 쓸 수 있다(`KEEP:…`도 완료). 상태 문자열(`STARTED` · `FAILED` 등)이 찍힌 줄은 완료되지 않은 백업이라 쓰지 않는다. End Time은 백업 종료 시각이다(실측(2026-10-29): End Time은 시간대 없는 UTC — Backup CR `stoppedAt`(Z)와 같은 값). 복구 목표 시각(`targetTime`)은 기반 백업의 종료 시각보다 뒤여야 한다.
- 로그에 자격은 찍히지 않는다 — 실패해도 `Barman cloud backup list exception: <메시지>` 한 줄(403 · `SignatureDoesNotMatch` 같은 서버 문구)뿐이다.

```powershell
# ⑥ 정리(운영자) — TTL(1시간)을 기다리지 않고 지운다. Argo 고아 경고의 Job · 파드 몫도 이때 빠진다(2026-10-29 실측 4 → 2)
kubectl --kubeconfig <admin kubeconfig> -n data delete job pg-main-backup-list
#   job.batch "pg-main-backup-list" deleted
kubectl -n data get job pg-main-backup-list              # (agent-view 가능) Error from server (NotFound)
```

- **변형**(매니페스트의 `command`만 바꾼다): `--format json` — `console` 줄을 `json`으로 → 로그 한 줄 `{"backups_list": […]}`(backup.info 필드 — 시작 · 종료 시각 · WAL · 상태) · `-t`(연결만 시험) — `--format` · `console` 두 줄을 `-t` 한 줄로 → 버킷 도달 · 자격이 맞으면 출력 없이 Complete · 다른 세대 — 마지막 줄 `pg-main`을 `pg-main-r<N>`으로(전체 PITR 뒤 — §3-1 6단계 1).
- **실패 분기**:

| 증상 | 먼저 볼 것(agent-view 가능) | 원인 · 조치 |
|---|---|---|
| Pod `CreateContainerConfigError` | `kubectl -n data describe pod -l job-name=pg-main-backup-list` | Secret `oci-s3-backup` 없음 · 키 이름 불일치 → ExternalSecret(gitops `secrets/data/externalsecret-oci-s3-backup.yaml`) |
| Pod `Pending` | 같은 describe의 Events | 노드 B CPU 여유(requests 50m) · `role=data` 라벨 |
| `ImagePullBackOff` | 같은 describe | digest 오타 — 이 이미지는 인스턴스 사이드카와 같은 digest라 노드 B에 이미 있다 |
| 로그 `SignatureDoesNotMatch` · `403` · `InvalidAccessKeyId` | `kubectl -n data logs job/pg-main-backup-list` | kv `platform/oci/s3` 키 쌍 불일치 → **kv를 정정**(Secret 수동 수정은 ≤ 5분에 kv 값으로 되돌아간다 — ES 머리 주석) |
| 로그에 연결 시간 초과 | 같은 로그 | egress 443 정책 · OCI 장애 |
| Job `Failed`(DeadlineExceeded) | `kubectl -n data describe job pg-main-backup-list` | 300초 초과 — `-t` 변형으로 연결부터 본다 |

- **Argo**: AppProject `platform`은 `orphanedResources.warn: true`다 → Job이 있는 동안 ns `data`를 대상으로 하는 Application(예: `platform-cnpg-cluster`)에 `OrphanedResourceWarning` 조건이 붙는다. health · sync 상태가 아니고 ⑥ 뒤 Job · 파드 몫이 빠진다(하네스 영향 0 · VD-8). 실측(2026-10-29): Job · 파드가 있는 동안 `platform-cnpg-cluster` 조건 `OrphanedResourceWarning: Application has 4 orphaned resources`(Synced/Healthy 유지) → ⑥ 삭제 뒤 `… 2 orphaned resources`(기존 ConfigMap 류 · T058 무관).
- **소요**: 3초(2026-10-29 실측 · 17행 · §9).

### §1-2 보조 확인 — Backup CR · Cluster 조건 · 버킷

```powershell
# 판정(agent-view 가능 — 마지막 줄만 svc-verify)
kubectl -n data get backup -o 'custom-columns=N:.metadata.name,P:.status.phase,ID:.status.backupId,BEGIN:.status.startedAt,END:.status.stoppedAt,ENDWAL:.status.endWal,M:.spec.method'
#   pg-main-daily-<YYYYMMDDHHMMSS> completed <backupId> … <endWal> plugin — 최신 completed가 25시간 안(매일 02:00 KST)
kubectl -n data get cluster pg-main -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
#   ContinuousArchiving=True ContinuousArchivingSuccess — False면 WAL 아카이브가 멈춘 것(그 뒤 시점으로는 복구할 수 없다)
oci --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup --prefix pg-main/ --all --fields name,size,timeCreated
#   pg-main/pg-main/base/<backupId>/{backup.info,data.tar.lz4} · pg-main/pg-main/wals/<16hex>/<24hex>.zst(+ .backup.zst 라벨)
#   전체 PITR 뒤에는 새 세대 접두 pg-main/pg-main-r<N>/도 보인다
```

- **복구 가능 판정**: 목표 시각 이전에 끝난 completed 베이스 백업이 하나 이상 있고, 그 백업부터 목표 시각까지 WAL 세그먼트가 끊기지 않았다(`wals/` 번호 연속). 유휴 구간에는 WAL이 늘지 않는 것이 정상이다(아래 §1-3).
- `status.firstRecoverabilityPoint` · `lastSuccessfulBackup`은 플러그인 경로에서 **빈 값**이다(T053 확정 — `bootstrap.md` §3 T053) → 복구 지점 판단에 쓰지 않는다. backup-list와 Backup CR로 본다.
- 전체 PITR 뒤에는 Backup CR에 **두 세대가 섞인다** — `status.pluginMetadata.clusterUID`(현재 Cluster UID와 같은가)와 그 backupId가 있는 접두(`pg-main/<serverName>/base/`)로 구분하고, 복구 기반은 현재 세대 backup-list(§1-1 — 마지막 인자 = 현재 serverName)로 고른다. 옛 세대 CR은 새 사이드카가 지우지 않는다(§3-1 6단계 2).

### §1-3 RPO · 보존(복구 창)

| 항목 | 값 | 근거 |
|---|---|---|
| RPO | ≤ 5분(`archive_timeout 300`) — 단 유휴 구간에는 WAL이 스위치되지 않으므로 "마지막 쓰기 뒤 ≤ 5분 안에 아카이브"로 읽는다 | gitops `cluster-pg-main.yaml` · `bootstrap.md` §3 T053(유휴 7시간 WAL 0개) |
| PITR 창 | 30일(`retentionPolicy 30d`) — 가장 오래된 completed 베이스 백업의 종료 시각부터 아카이브된 WAL 끝까지 | gitops `objectstore-oci-backups.yaml` |
| 베이스 백업 | 매일 17:00Z(02:00 KST) ScheduledBackup `pg-main-daily` + 수동 Backup(§1-4) | gitops `scheduledbackup-pg-main-daily.yaml` |
| 첫 백업 | 2026-10-13 `20261013T094258`(3초 · 빈 DB ≈ 6.3 MB) | `bootstrap.md` §3 T053 |
| 복구 지점 표시 | `firstRecoverabilityPoint`는 빈 값 → backup-list · Backup CR | T053 |
| 실수 삭제 창 | 버킷 versioning + 이전 버전 60일(키 유출 방어는 아니다) | gitops `platform/cnpg-cluster/README.md` §5 |

### §1-4 수동 Backup(공통 — §3-1 2-b′ · 5-a)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Backup
metadata:
  name: pg-main-manual-20261029-pre-drill   # 날짜 · 용도를 바꾼다(예: -pre-pitr · -post-pitr) — 이름이 같으면 새 백업이 생기지 않는다
  namespace: data
spec:
  cluster:
    name: pg-main
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
```

```powershell
# 운영자 — 위 블록을 이름만 바꿔 $env:TEMP\pg-main-manual-backup.yaml로 저장. create = 같은 이름이 있으면 거부된다(apply는 조용히 아무것도 안 한다)
kubectl --kubeconfig <admin kubeconfig> create -f "$env:TEMP\pg-main-manual-backup.yaml"
#   backup.postgresql.cnpg.io/pg-main-manual-<yyyymmdd>-<용도> created
$bk = 'pg-main-manual-20261029-pre-drill'                # 저장한 metadata.name과 같게(용도 접미를 바꿨으면 여기도)
kubectl -n data get backup $bk -o jsonpath='{.status.phase} {.status.backupId} {.status.endWal}'   # (agent-view 가능) completed <backupId> <endWal>
```

- 이 Backup은 ScheduledBackup 소유가 아니다(owner 없음) — 보존 만료 뒤 사이드카가 카탈로그 기준으로 지운다(gitops README §5). 단 **같은 Cluster UID의 것만**이다: 전체 PITR 전에 만든 Backup(예: `-pre-pitr`)은 재생성된 Cluster의 사이드카가 지우지 않는다(§3-1 6단계 2). Cluster가 Ready가 아니면 `pending`으로 기다렸다가 시작한다.

## §2 시나리오 선택표

- **목적**: 증상에서 절차로 바로 간다. 판단이 서지 않으면 아무것도 지우지 않고 §1부터 한다.
- **전제**: CNPG 시나리오면 §1을 마쳤다(복구 지점 확인 — 노드 B가 없으면 §1-2만).
- 문면(FR-018 · FR-041): **PITR = 클러스터 전체 복원(재해 복구 전용, 모든 pod DB가 함께 되돌아감)** — 한 DB만의 문제는 **side Cluster로 PITR → 해당 DB만 `pg_dump` → 운영 클러스터 복원**(§4)으로 간다. Vault 스냅샷 · K3s 번들은 **age 복호화 후 복원**한다(§5 · §6).

| 상황 | 판정(무엇이 보이나) | 절차 | 데이터 결과 |
|---|---|---|---|
| 노드 B 재부팅 · 파드 재시작 | PVC `pg-main-1` Bound · 파드가 다시 뜬다 | **복구 불필요** — 재부팅 → PVC에서 CNPG 재기동(spec Edge Case 노드 B 장애) | 손실 0 |
| 노드 B 재이미지 · 부트 볼륨 교체 · PVC `pg-main-1` 손실 | 재이미지 · 부트 볼륨 교체: PVC `pg-main-1`은 Bound로 남지만 파드가 뜨지 않는다(PGDATA 없음 · CrashLoop) — 객체는 있고 데이터만 없다(VD-11) · PVC가 지워졌으면 PVC 없음. 노드 B가 없으면(재조인 전) §1-1 Job을 건너뛰고 §1-2로 판정한다 · Job은 재조인 뒤(§3-1 6단계 1) | §3-1(경로 A · `recoveryTarget` 생략 · 2-b′ · 2-c는 해당 없음) | 모든 DB가 아카이브된 WAL 끝까지 — RPO ≤ 5분 |
| 클러스터 전체 논리 손상(여러 DB · 공유 DB 동시) | 업무 데이터 오류 · 대량 삭제 | §3-1 + `targetTime`(손상 직전) — 2-b′ 수동 Backup → 2-c 아카이브 정지가 3단계 머지보다 먼저다 | 모든 DB가 그 시점 — 그 뒤 쓰기 전부 손실 |
| 옛 클러스터를 살려 둔 채 복구본과 비교해야 함 | — | §3-2(경로 B — 예외) | 경로 A와 같고 전환 비용이 크다 |
| 한 DB만 잘못된 쓰기 · 삭제 | 그 DB의 데이터 오류 | §4 | 그 DB만 targetTime · 다른 DB 그대로 |
| Vault 데이터 손실 · 손상 | seal-status는 정상인데 kv · 정책이 없다 등 | §5 → `vault-unseal.md` §7 | 스냅샷 시점(일 1회 02:30 KST · 업그레이드 직전) |
| K3s 데이터스토어 손실 · 손상 · 롤백 | 노드 A API 불통 · `state.db` 손상 | §6 | 번들 시점(일 1회 · 업그레이드 직전) |
| 복구 지점만 확인 | — | §1 | 변화 없음 |

- **다음 단계**: 표의 절.

## §3 절차 A — 클러스터 전체 PITR(재해 복구 전용)

**PITR = 클러스터 전체 복원(재해 복구 전용, 모든 pod DB가 함께 되돌아감)**(FR-018 · FR-041). `pg-main`의 DB 전부 — pod DB `identity_admin` · `dev_identity_admin` · 공유 DB `authentik` · `openfga` · 부트스트랩 DB `platform` — 가 같은 시점으로 간다. 복구 지점 뒤의 쓰기는 **모든 DB에서** 사라지고, Kafka 토픽 · Dragonfly는 되돌아가지 않는다(발산의 뜻은 §4-9와 같고, 모든 pod에 생긴다). **승격 ~ 첫 `pg-main-r<N>` Backup completed 사이의 쓰기는 두 번째 장애(PVC 손실) 때 복구할 수 없다**(r<N> 접두에 base가 없다) — 그래서 §3-1 5-a 수동 Backup이 승격 직후의 첫 조치다.

- **복구 방식**(CNPG v1.30.0 CRD · build-notes 「T058」 사실 1–3): 새 Cluster를 `bootstrap.recovery`(`source` = `externalClusters` 항목 이름) + `externalClusters[].plugin`(`barmanObjectName: oci-backups` · `serverName` = 원천 접두)으로 만든다. `recoveryTarget.targetTime`(RFC3339 — 시간대가 없으면 UTC로 해석하므로 **항상 `Z`를 적는다**)을 주면 그 시각 이전의 가장 가까운 completed 백업을 자동으로 골라 그 시각까지 WAL을 재생하고, 생략하면 최신 백업 + 아카이브된 WAL 끝까지 간다. 복구는 Job `<cluster>-1-full-recovery`(플러그인 사이드카 주입)가 한다(plugin v0.14.0).
- 복구 클러스터가 WAL을 아카이브하려면 `spec.plugins`가 있어야 하고(복구 설정만으로는 아카이브가 켜지지 않는다 — plugin-barman-cloud 문서 「Usage」), 그 `serverName`은 같은 ObjectStore 안에서 고유해야 한다 → 새 세대 이름 `pg-main-r<N>`. 같은 접두가 비어 있지 않으면 빈 아카이브 검사가 실패해 `Setting up primary`에 멈춘다(로그 `WAL archive check failed … Expected empty archive` — CNPG 1.30 문서 「Recovery」).
- **경로 선택**: §3-1(권장 · 같은 이름 재생성) — 이름에 걸린 참조가 그대로 맞는다. §3-2(새 이름)는 옛 클러스터를 살려 둔 채 비교해야 할 때만이다.

### §3-1 경로 A(권장) — 같은 이름 `pg-main` 재생성

- **목적**: 이름 `pg-main`을 그대로 둔 채 데이터를 백업 시점으로 되살린다. `Database` 4 · `DatabaseRole` 6 CR(`cluster.name: pg-main` — 생성 뒤 불변) · Service `pg-main-rw` · CA 미러 ExternalSecret(`remoteRef.key: pg-main-ca`) · kv `url`의 호스트 · ScheduledBackup `pg-main-daily` · 하네스 상수가 **전부 그대로 맞는다** → 과제 문면의 「앱 Secret/Service 교체」가 필요 없다(교체는 §3-2뿐). 「PVC 보존」은 2단계 PV Retain(선택)이다.
- **전제**: 모든 DB를 함께 되돌려도 되는 **재해 복구**다 · 노드 B Ready + 라벨 `role=data`(재이미지 뒤라면 `bootstrap.md` §2 순서로 `host-prep.sh` → `k3s-agent.sh` 재조인 — 라벨은 `k3s-agent.sh`가 등록 때 붙인다 · 확인 `kubectl get nodes -L role`) · CNPG operator · plugin · ESO · Secret `oci-s3-backup` · ObjectStore `oci-backups`가 라이브 · 버킷 도달(§1 통과) · gitops PR · CI · 운영자 머지 가능.
  - 재이미지한 노드 B를 **같은 이름**으로 재조인하려면 `k3s-agent.sh` 전에 운영자가 node-password Secret(`kube-system/<노드 B 이름>.node-password.k3s`)을 지운다 — 아래 **1순위** 블록. 지우지 않으면 agent가 `Node password rejected, duplicate hostname`으로 거부된다. Node 객체 삭제(그 Secret도 함께 지워진다)는 **2순위**다 — 1순위 뒤에도 거부 문구가 계속될 때만 아래 2순위 블록으로 한다. 근거 = K3s 문서 「Architecture」 Node-password secrets(같은 비밀번호 요구 · Node 삭제 권고) · 거부 문구 `Node password rejected, duplicate hostname`은 k3s 서버 로그 메시지(소스) · 라이브 미실측 — VD-14. 그 뒤 `k3s-agent.sh`가 라벨 `role=data`를 붙인다(`node-label`).

```powershell
# 1순위(운영자) — 노드 B 재조인(k3s-agent.sh) 전에 node-password Secret을 지운다(이름만 다룬다 — 값은 출력하지 않는다)
kubectl get nodes -l role=data                           # (agent-view 가능) 직전 확인 — 노드 B 한 행 · STATUS NotReady(재이미지 전의 Node 객체)
$nodeB = kubectl get nodes -l role=data -o jsonpath='{.items[0].metadata.name}'
if (-not $nodeB) { throw 'role=data Node 없음 — kubectl get nodes -L role로 노드 B를 확인한다(Node가 이미 지워졌으면 그 Secret도 함께 지워졌다 · 할 일 없음 · 재조인으로)' }
kubectl --kubeconfig <admin kubeconfig> -n kube-system get secret "$nodeB.node-password.k3s"
#   그 이름의 한 행 — NotFound면 지울 것이 없다(재조인으로)
if ((Read-Host "노드 B = $nodeB (NotReady) · Secret $nodeB.node-password.k3s 있음? 그 Secret 삭제 yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n kube-system delete secret "$nodeB.node-password.k3s"
#   secret "….node-password.k3s" deleted → bootstrap.md §2 순서로 k3s-agent.sh 재조인
```

```powershell
# 2순위(운영자) — 1순위 뒤 재조인이 같은 거부 문구(Node password rejected, duplicate hostname)로 계속될 때만: Node 객체를 지운다(그 Secret도 함께 지워진다)
if (-not $nodeB) { throw '$nodeB 비었음 — 1순위 블록의 $nodeB 줄부터' }
kubectl get node $nodeB                                  # (agent-view 가능) 직전 확인 — 1순위 · 재조인 뒤에도 NotReady
if ((Read-Host "1순위 뒤에도 거부 문구 계속 · $nodeB NotReady? Node $nodeB 삭제(재조인이 다시 등록하고 라벨은 k3s-agent.sh가 다시 붙인다) yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> delete node $nodeB
#   node "…" deleted → k3s-agent.sh 재조인
```

- **서비스 중단**: 2-c 아카이브 정지(논리 손상 갈래) 또는 4단계 삭제부터 5단계 healthy까지 모든 DB 접속 불가 — 소요 미실측(VD-3).
- **다음 단계**: 6단계 후속 → §7 「전체 PITR」 → §9 기록.

**1. 판정 · 기록**(agent-view 가능 — 결정은 운영자가 기록한다)

```powershell
kubectl -n data get cluster pg-main -o jsonpath='{.status.phase}|{.status.readyInstances}|{.spec.instances}'
#   장애면 healthy가 아니다(예: readyInstances 0) — 보인 그대로 기록한다
kubectl -n data get pod,pvc -l cnpg.io/cluster=pg-main -o wide
#   재이미지 뒤면 PVC pg-main-1은 Bound로 남고 파드가 뜨지 않는다(PGDATA 없음 · CrashLoop — 데이터만 없다 · VD-11) · PVC가 지워졌으면 PVC 없음 · 파드 Pending
#   논리 손상이면 파드 Running — 2-b′ · 2-c 대상
kubectl -n data get cluster pg-main -o jsonpath='{.spec.plugins[0].parameters.serverName}'
#   빈 값 = 현재 세대 r0(serverName pg-main · 접두 pg-main/pg-main/) → 새 세대 pg-main-r1
#   pg-main-r1이면 새 세대 pg-main-r2 · externalClusters의 serverName = pg-main-r1(원천은 항상 직전 세대)
```

- **복구 목표**: 재해(노드 B · PVC 손실) = `recoveryTarget` 생략(아카이브된 WAL 끝까지) · 논리 손상 = `targetTime`(손상 직전 · UTC `Z` — KST − 9시간, 예: KST 12:00 = `03:00:00Z`). targetTime은 가장 오래된 completed 백업의 종료 시각보다 뒤, 아카이브된 WAL 끝보다 앞이어야 한다(§1).
- **기록**: 시작 시각(UTC · KST) · 세대 `<N>`과 원천 serverName · 복구 목표 — §9와 `bootstrap.md` §3에 옮긴다.

**2. 보존 · 아카이브 정지(운영자)** — 옛 Cluster가 아직 있을 때만. 순서: 2-a · 2-b PV Retain(선택) → 2-b′ 수동 Backup → 2-c 아카이브 정지. 2-b′ · 2-c는 옛 클러스터가 **돌고 있을 때**(논리 손상 갈래)만이고, 노드 B 소실 갈래(PG가 돌지 않는다)는 둘 다 해당 없음이다. 논리 손상 갈래는 3-a(PR 열기 · CI 통과)를 2-c **전에** 미리 해 두고, 2-c 확인 뒤에는 3-b 머지만 한다 — 중단 창 = hibernation → 머지 → Argo 감지(≤ 5분) → 삭제 → 복구(순서 규칙은 그대로: **머지는 파드 0 뒤**).

- ⓐ **PV Retain**(2-a · 2-b): Cluster를 지우면 local-path PVC(reclaim Delete)와 노드 B의 데이터 디렉터리가 함께 사라진다(gitops `platform/cnpg-cluster/README.md` §5). PV를 Retain으로 바꾸면 노드 B `/var/lib/rancher/k3s/storage/` 아래 그 PV의 디렉터리가 남는다 — **포렌식 전용**이다(복구본에 다시 붙이는 경로는 VD-11 · 쓰지 않는다). 남은 디렉터리는 복구본과 함께 노드 B 부트 볼륨(100 GB)을 쓴다. 재이미지 뒤에도 PVC · PV 객체는 남는다(데이터 없음 — VD-11) → PV Retain은 옛 데이터가 디스크에 있을 때(논리 손상)만 하고, 재이미지면 건너뛴다.
- ⓑ **수동 Backup**(2-b′): 옛 클러스터가 **돌고 있으면**(논리 손상) 지금 상태를 직전 세대 접두에 한 번 더 남긴다 — §1-4 매니페스트(이름 `pg-main-manual-<yyyymmdd>-pre-pitr`) → `completed`와 backupId를 기록한다(4-b 정지점이 묻는다). 되돌리기(§8)의 "PITR 직전" 지점이고, 그때까지의 WAL을 직전 세대 접두로 밀어 넣는다. 2-c 앞에 끝낸다 — hibernation 뒤에는 파드가 없어 Backup이 돌지 않는다.
- ⓒ **아카이브 정지 — hibernation**(2-c): 3단계 PR의 `plugins[].parameters.serverName` 변경은 bootstrap과 달리 **라이브 효과가 있다**(3단계 ⚠). 그래서 머지 **전에** 옛 클러스터를 CNPG 1.30 선언적 hibernation으로 멈춘다 — operator가 인스턴스 파드를 지우고 PVC는 남긴다(CNPG 1.30 문서 「Declarative hibernation」 · v1.30.0 `pkg/reconciler/hibernation`). 파드가 없으면 플러그인 사이드카도 없어 어떤 WAL도 새 접두로 갈 수 없다. 이 순간부터 모든 DB 접속이 끊긴다(서비스 중단 시작). hibernation은 Cluster가 healthy일 때만 시작한다(아니면 조건 `False WaitingForHealthy` — `pkg/reconciler/hibernation/status.go`). 어노테이션은 kubectl로 단 live 키라 Argo desired에 없다 — selfHeal이 되돌리지 않을 것으로 본다(desired에 없는 live 키는 diff 대상이 아니다 · 라이브 미실측 — VD-13 · 3-c에서 파드 0을 다시 본다). 노드 B 소실 갈래(파드 0 · Pending · CrashLoopBackOff — PG가 돌지 않는다)는 2-c 판정 출력으로 그것을 보이고 **건너뛴다**.

```powershell
# 2-a 판정(운영자 — PV는 agent-view가 읽지 못한다)
$pv = kubectl --kubeconfig <admin kubeconfig> -n data get pvc pg-main-1 -o jsonpath='{.spec.volumeName}'
"pv=$pv"                                                 # pvc-<uid>. 빈 값 = PVC가 지워졌다 → ⓐ를 건너뛴다(재이미지 뒤에는 PVC가 남아 값이 있다 — 그때도 ⓐ는 건너뛴다)
if ($pv) { kubectl --kubeconfig <admin kubeconfig> get pv $pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy} {.spec.claimRef.name}' }
#   Delete pg-main-1
```

```powershell
# 2-b 변경(운영자) — 2-a 출력을 본 뒤에만
if (-not $pv) { throw '$pv 비었음 — 2-a부터' }
if ((Read-Host "2-a 출력 = Delete pg-main-1? PV $pv 의 reclaimPolicy를 Retain으로 바꾼다 yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> patch pv $pv -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
#   persistentvolume/pvc-<uid> patched
kubectl --kubeconfig <admin kubeconfig> get pv $pv -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'
#   Retain
```

```powershell
# 2-b′ 수동 Backup(운영자 — 논리 손상 갈래만) — §1-4 yaml의 metadata.name을 pg-main-manual-<yyyymmdd>-pre-pitr로 바꿔 $env:TEMP\pg-main-manual-backup.yaml로 저장한 뒤
kubectl --kubeconfig <admin kubeconfig> create -f "$env:TEMP\pg-main-manual-backup.yaml"
#   backup.postgresql.cnpg.io/pg-main-manual-<yyyymmdd>-pre-pitr created
$bk = 'pg-main-manual-20261029-pre-pitr'                 # 저장한 metadata.name과 같게
kubectl -n data get backup $bk -o jsonpath='{.status.phase} {.status.backupId} {.status.endWal}'   # (agent-view 가능) completed <backupId> <endWal> — backupId를 기록한다(running이면 다시 본다)
```

```powershell
# 2-c 판정(agent-view 가능) — PG가 도는가 · 2-b′가 끝났는가
kubectl -n data get pod -l cnpg.io/cluster=pg-main
#   pg-main-1 Running = 논리 손상 갈래 → 2-c 변경으로
#   No resources found · Pending · CrashLoopBackOff = 노드 B 소실 갈래(PG가 돌지 않는다) → 2-c를 건너뛰고 3단계로
kubectl -n data get backup $bk -o jsonpath='{.status.phase} {.status.backupId}'
#   completed <backupId> — 2-b′의 수동 Backup(running이면 끝날 때까지 기다린다)
```

```powershell
# 2-c 변경(운영자) — 판정 출력(파드 Running · 2-b′ completed)을 본 뒤에만
if ((Read-Host '2-c 판정 = pg-main-1 Running · 2-b′ 수동 Backup completed(backupId 기록)? pg-main hibernation(파드 삭제 · PVC 유지 — 모든 DB 접속 중단 시작) yes') -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data annotate cluster pg-main --overwrite cnpg.io/hibernation=on
#   cluster.postgresql.cnpg.io/pg-main annotated
```

```powershell
# 2-c 확인(agent-view 가능) — 둘 다 맞을 때만 3단계 머지로 간다
kubectl -n data get cluster pg-main -o jsonpath='{range .status.conditions[?(@.type=="cnpg.io/hibernation")]}{.status} {.reason} {.message}{end}'
#   True Hibernated Cluster has been hibernated
#   진행 중이면 False DeletingPods · False WaitingPodsDeletion(몇 초 뒤 다시 본다)
#   False WaitingForHealthy면 Cluster가 healthy가 아니라 시작하지 않았다 — 1단계 판정부터 다시 보고, 그동안 3단계로 가지 않는다.
#   10분이 지나도 WaitingForHealthy면 둘 중 하나: ⓐ 운영자가 아래 「2-c ⓐ 재기동」 블록(delete pod pg-main-1 · Read-Host 정지점 · PVC 유지)으로
#   인스턴스를 재기동한 뒤 healthy → 이 확인 블록을 다시 본다 ⓑ 2-c 없이 3단계로 간다 — 그때는 3단계 ⚠의 보조 ①–④만으로 막고 4단계
#   Expected empty archive면 r<N+1>로 재실행(세대 1개 비용 수용 · VD-13). 어노테이션은 그대로 둬도 된다(healthy가 되는 순간 hibernation이
#   시작되므로 4-b 전 파드 상태를 다시 본다)
kubectl -n data get pod -l cnpg.io/cluster=pg-main
#   No resources found in data namespace.(0행)
```

```powershell
# 2-c ⓐ 재기동(운영자) — 2-c 확인이 10분 넘게 False WaitingForHealthy일 때만. 인스턴스 파드만 지운다(PVC 유지 — operator가 같은 PVC로 다시 만든다)
kubectl -n data get cluster pg-main -o jsonpath='{range .status.conditions[?(@.type=="cnpg.io/hibernation")]}{.status} {.reason} {.message}{end}'   # (agent-view 가능) 직전 확인 — False WaitingForHealthy …
kubectl -n data get pod -l cnpg.io/cluster=pg-main       # (agent-view 가능) pg-main-1 한 행
if ((Read-Host '2-c 확인 = 10분 넘게 False WaitingForHealthy? 인스턴스 파드 pg-main-1 삭제 → 같은 PVC로 재기동(그동안 모든 DB 접속 끊김) yes') -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data delete pod pg-main-1
#   pod "pg-main-1" deleted — healthy가 되는 순간 어노테이션대로 hibernation이 시작된다 → 위 2-c 확인 블록을 다시 본다(True Hibernated · 0행)
```

**3. gitops PR — recovery spec을 먼저 머지한다**(머지는 운영자 · 논리 손상 갈래는 2-c 확인(파드 0) 뒤에만 — 예외는 2-c 확인의 WaitingForHealthy ⓑ) — gitops README §5 「git을 되돌리지 않은 채 `kubectl delete`부터 하면 selfHeal이 즉시 재생성한다(새 initdb = 빈 DB)」의 역이다: recovery spec이 git에 먼저 있어야 selfHeal이 **복구**로 다시 만든다. 논리 손상 갈래는 3-a(PR 열기 · CI 통과)를 2-c **전에** 미리 해 두고, 2-c 확인 뒤에는 3-b 머지만 한다 — 중단 창 = hibernation → 머지 → Argo 감지(≤ 5분) → 삭제 → 복구(순서 규칙은 그대로: **머지는 파드 0 뒤**).

- 대상: platform-gitops `platform/cnpg-cluster/cluster-pg-main.yaml` **한 파일**(그 Application의 한 장 변경 = `ApplyOutOfSyncOnly`로 단일 step). 바꾸는 곳은 **세 군데**(아래 표)이고, 그 밖의 줄(머리 주석 · 어노테이션 `Delete=false,Prune=false` · wave · imageCatalogRef · resources · affinity · parameters 8 · enableSuperuserAccess)은 바꾸지 않는다. 결과의 YAML 본문(주석은 줄였다):

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-main
  namespace: data
  annotations:
    argocd.argoproj.io/sync-options: Delete=false,Prune=false   # 하네스 argo-4-pg-main — 글자 그대로(불변)
    argocd.argoproj.io/sync-wave: "1"
spec:
  instances: 1
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: postgresql-standard-trixie
    major: 18
  enableSuperuserAccess: false
  storage:
    storageClass: local-path
    size: 40Gi
  resources:
    requests:
      cpu: "1"
      memory: 2Gi
    limits:
      cpu: "1"
      memory: 2Gi
  affinity:
    enablePodAntiAffinity: false
    nodeSelector:
      role: data
  postgresql:
    parameters:
      shared_buffers: 512MB
      max_parallel_workers: "2"
      max_connections: "100"
      archive_timeout: "300"
      effective_cache_size: 1536MB
      work_mem: 8MB
      maintenance_work_mem: 128MB
      wal_compression: zstd
  bootstrap:                                  # 바뀐 곳 1 — initdb 블록 → recovery
    recovery:
      source: origin
      database: platform                      # initdb와 같게 — 비우면 CNPG 기본 app DB · role이 생긴다(cluster_defaults.go defaultRecovery)
      owner: platform_owner
      # recoveryTarget:                       # 논리 손상 복구일 때만 — 생략 = 아카이브된 WAL 끝까지(재해 복구 기본)
      #   targetTime: "2026-10-29T03:00:00Z"  # RFC3339 · 시간대 명시(Z) — KST 12:00 = 03:00Z
  externalClusters:                           # 바뀐 곳 2 — 추가
    - name: origin
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: oci-backups
          serverName: pg-main                 # 원천 = 직전 세대 접두(처음 r0 = pg-main → pg-main/pg-main/). 다음 복구에서는 pg-main-r1
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      enabled: true
      isWALArchiver: true
      parameters:
        barmanObjectName: oci-backups
        serverName: pg-main-r1                # 바뀐 곳 3 — 새 세대(같은 ObjectStore의 다른 접두 · 빈 아카이브 검사 통과 · 옛 WAL 덮어쓰기 0)
```

| # | 키 | 지금 | PR 뒤 |
|---|---|---|---|
| 1 | `spec.bootstrap` | `initdb`(database `platform` · owner `platform_owner` · `dataChecksums: true`) | `recovery`(source `origin` · database `platform` · owner `platform_owner`) — 논리 손상이면 `recoveryTarget.targetTime` 추가 |
| 2 | `spec.externalClusters` | 없음 | `origin` 하나 — `plugin.name: barman-cloud.cloudnative-pg.io` · `barmanObjectName: oci-backups` · `serverName: <직전 세대>` |
| 3 | `spec.plugins[0].parameters.serverName` | 없음(= 클러스터 이름 `pg-main`) | `pg-main-r<N>`(새 세대) |

- `database: platform` · `owner: platform_owner`를 적는 이유: 비우면 CNPG가 `app` DB · role을 만든다(`cluster_defaults.go` `defaultRecovery` — database가 비면 `app`, owner가 비면 database). 복구 뒤 operator는 그 owner의 비밀번호를 Secret `pg-main-app`으로 갱신한다(`platform_owner`는 소비자 0).
- `dataChecksums`는 initdb 전용이다 — 복구한 데이터 디렉터리는 원본의 체크섬 설정을 그대로 가진다.
- 다음 전체 PITR에서는 2의 `serverName`을 그때의 직전 세대로, 3을 다음 세대로 바꾼다(예: 원천 `pg-main-r1` · 새 `pg-main-r2`).

```powershell
# 3-a PR — gitops 작업 사본에서(브랜치 예: restore-pg-main-r1) 위 세 곳만 바꿔 PR을 연 뒤 CI(validate) 통과를 본다. 실패하면 머지하지 않는다
gh pr checks <PR>
# 3-b 머지(운영자 전용 — GitHub에서 결정하는 동작)
gh pr merge <PR> --squash --delete-branch --match-head-commit <40자>
```

```powershell
# 3-c 확인(agent-view 가능) — 머지 뒤 2–5분(리비전 감지)
kubectl -n argocd get app platform-cnpg-cluster -o jsonpath='{.status.sync.status} {.status.sync.revision} {.status.operationState.phase}'
#   Synced <머지 커밋> Succeeded
kubectl -n data get cluster pg-main -o jsonpath='{.spec.bootstrap}'
#   recovery(source origin · database platform · owner platform_owner)만 보이고 initdb가 없다 — VD-1 기록
kubectl -n data get cluster pg-main -o jsonpath='{.spec.plugins[0].parameters.serverName} {.status.phase}'
#   pg-main-r1 <2-c 뒤와 같은 phase> — bootstrap · externalClusters는 생성 때만 쓰인다 · plugins serverName은 라이브 효과가 있으므로
#   2-c로 파드를 0으로 만든 뒤 머지한다(노드 B 소실 갈래는 PG가 이미 돌지 않는다)
kubectl -n data get pod -l cnpg.io/cluster=pg-main
#   논리 손상 갈래 = 0행 그대로(2-c hibernation 유지 — VD-13) · 노드 B 소실 갈래 = 2-c 판정 때와 같다(PG가 돌지 않는다)
#   · 2-c 확인의 WaitingForHealthy ⓑ로 왔으면 Running 그대로일 수 있다(healthy가 되면 hibernation으로 0행) — 그 갈래는 다음 줄 없이 4단계로
#   Running 파드가 다시 떴으면 4단계로 가지 말고 2-c부터 다시 한다(그 사이 WAL이 새 접두로 갔을 수 있다 — 4단계에서 Expected empty archive면 다음 세대로 3–4단계)
#   두 번째도 되살아나면(selfHeal이 어노테이션을 되돌리는 경우 — VD-13 부정) 어노테이션 cnpg.io/hibernation: "on"을 PR로 cluster-pg-main.yaml의
#   metadata.annotations에 넣어 선언적으로 둔다(머지 1회 더 · 파드 0을 본 뒤 4단계) — 재생성 PR에서는 그 어노테이션을 뺀다(남기면 새 클러스터가
#   곧바로 hibernation된다). 빼는 머지는 4-b 삭제 뒤(재생성 중)에 한다 — 4-b 전에 빼면 옛 클러스터가 깨어나 새 접두에 WAL을 쓴다
```

- webhook(`cluster_webhook.go` v1.30.0): `ValidateUpdate` = 새 객체 전체 검증 + `validateClusterChanges`(image · configuration · storage · walStorage · tablespaces · unix 권한 · replication slots · wal_level · replica)라 `bootstrap` · `externalClusters` 변경은 업데이트 거부 대상이 아니다(라이브 미실측 — VD-1).
- **VD-1이 거부로 나오면**(Application `OutOfSync` · operation `Failed` — 라이브 Cluster는 바뀌지 않은 채다) **거부 메시지로 가른다**(4-a에서 `operationState.message`를 본다):
  - ⓐ `Only one bootstrap method can be specified at a time`(서버 사이드 적용 병합 뒤 initdb 잔재가 남은 경우 · `validateBootstrapMethod`)**일 때만** 4단계로 간다 — 삭제 뒤에는 git 매니페스트 그대로 **생성** 경로를 타 잔재가 없다(4-a 서버 dry-run이 그 생성 경로를 미리 검증한다). 단 자동 sync는 Failed로 끝난 리비전을 다시 시도하지 않으므로(gitops `platform/cnpg-cluster/README.md` 5절 · Application `platform-cnpg-cluster.yaml` 머리 주석) 4단계에서 운영자 수동 Sync가 필요하다.
  - ⓑ **그 밖의 webhook 메시지**(예: `recovery.source` 이름이 `externalClusters`에 없다 — `validateBootstrapRecoverySource` · `targetTime` 형식 · 오타)는 생성에서도 같은 사유로 거부된다(`ValidateCreate`도 같은 `validate`) → **삭제하지 않는다**. PR을 고쳐 3-a부터 다시 한다(삭제했다면 Cluster `Missing`이 길어지고 수동 Sync도 실패한다).
- ⚠ **옛 클러스터가 돌고 있을 때**(논리 손상): 3의 `plugins[].parameters.serverName` 변경은 bootstrap과 달리 **라이브 효과가 있다** — 플러그인은 아카이브 · 백업 요청 때의 Cluster spec에서 serverName을 읽는다(plugin v0.14.0 `config.go` `NewFromCluster`). 머지가 적용된 뒤 옛 클러스터가 WAL 세그먼트를 마치면 그 세그먼트가 **새 세대 접두로** 가고, 재생성된 클러스터가 빈 아카이브 검사에 걸린다(멈출 뿐 덮어쓰지 않는다). **막는 방법은 2-c 아카이브 정지**(hibernation — 파드 0 = 사이드카 0)다. 아래는 2-c의 보조다: ① 2-b′ 수동 Backup으로 그때까지의 WAL을 직전 세대 접두에 넣는다 ② 소비자 쓰기를 멈춘다 — **쓰기 정지만으로는 부족하다**(autovacuum · 카탈로그 활동도 WAL을 만들고 `archive_timeout 300`이 세그먼트를 넘긴다) ③ 3-c에서 Synced를 보자마자 4단계로 간다 ④ 예약 백업 시각(02:00 KST) 앞뒤 20분은 피한다. 그래도 4단계에서 `Expected empty archive`로 멈추면 다음 세대(`r<N+1>`)로 3–4단계를 다시 한다(VD-13). 목표 시각이 과거라 이 창의 WAL은 복구에 필요 없다.

**4. 삭제 → 재생성**(운영자 · 정지점) — 판정 블록과 변경 블록을 나눈다.

```powershell
# 4-a 판정(agent-view 가능) — 3단계 결과 · 2단계 상태를 다시 본다
kubectl -n argocd get app platform-cnpg-cluster -o jsonpath='{.status.sync.status} {.status.operationState.phase}'
#   Synced Succeeded(VD-1 거부 갈래면 OutOfSync Failed — 다음 줄로 사유를 본다)
kubectl -n argocd get app platform-cnpg-cluster -o jsonpath='{.status.operationState.message}'
#   거부 갈래면 webhook 메시지 — `Only one bootstrap method …`일 때만 4단계로 간다(3단계 VD-1 분기 ⓐ). 그 밖이면 삭제하지 않는다(ⓑ)
kubectl -n data get cluster pg-main -o jsonpath='{.spec.bootstrap.recovery.source} {.spec.plugins[0].parameters.serverName}'
#   origin pg-main-r1(VD-1 거부 갈래면 빈 값)
kubectl -n data get backup -o 'custom-columns=N:.metadata.name,P:.status.phase,ID:.status.backupId'
#   2-b′의 -pre-pitr 행 completed <backupId>(노드 B 소실 갈래는 해당 없음)
kubectl -n data get pod -l cnpg.io/cluster=pg-main
#   0행(2-c Hibernated) · 노드 B 소실 갈래면 Running이 아니다(Pending · CrashLoopBackOff) — Running이면 2-c부터
#   (2-c 확인의 WaitingForHealthy ⓑ로 왔으면 Running이어도 4-b로 간다 — 4-c에서 Expected empty archive면 r<N+1>로 3–4단계)
```

```powershell
# 4-a 판정(운영자 — 비파괴 서버 dry-run · CNPG webhook은 sideEffects None): 생성 경로를 삭제 전에 검증한다.
#   3단계 결과 YAML 본문(PR의 cluster-pg-main.yaml)을 metadata.name만 pg-main-dryrun으로 바꿔 $env:TEMP\pg-main-dryrun.yaml로 저장한 뒤
kubectl --kubeconfig <admin kubeconfig> create --dry-run=server -f "$env:TEMP\pg-main-dryrun.yaml"
#   cluster.postgresql.cnpg.io/pg-main-dryrun created (server dry run) — 이름만 다르므로 bootstrap · externalClusters 검증은 재생성과 같다
#   거부면 그 메시지를 기록하고 삭제하지 않는다 — PR을 고쳐 3-a부터(VD-1 분기 ⓑ와 같다)
kubectl -n data get cluster pg-main-dryrun   # (agent-view 가능) Error from server (NotFound)여야 한다 — 객체가 보이면 --dry-run이 빠진 것: 즉시 운영자 delete(hibernation이 비운 자원으로 클론이 뜨고 pg-main-r<N> 접두에 WAL을 쓴다)
```

```powershell
# 4-b 삭제(운영자) — 4-a 두 블록의 출력과 2단계 결정을 확인한 뒤에만
if ((Read-Host '4-a = Synced + recovery(또는 Only one bootstrap method 거부 갈래) · dry-run created(pg-main-dryrun NotFound) · 2-b′ 수동 Backup completed(backupId 기록) 또는 해당 없음(PVC 손실) · 파드 0(2-c Hibernated) 또는 노드 B 소실 또는 2-c 확인 WaitingForHealthy ⓑ · 2단계 PV Retain 결정 끝? pg-main 삭제(모든 DB 접속 중단) yes') -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data delete cluster pg-main
#   cluster.postgresql.cnpg.io "pg-main" deleted — operator가 Pod · PVC · Service · Secret 4장 · Job을 정리한다. 객체의 Delete=false는 Argo 경로만 막는다
```

```powershell
# 4-c 관찰(agent-view 가능) — selfHeal이 git의 recovery spec으로 다시 만든다(대기 상한 3분 · VD-2)
kubectl -n data get cluster -w
#   ns 전체를 본다(이름을 주면 재생성 전에는 NotFound로 끝난다) — pg-main이 다시 생긴다 → Setting up primary → … → Cluster in healthy state(Ctrl+C로 끝낸다)
kubectl -n data get job
#   pg-main-1-full-recovery(플러그인 사이드카 포함) → COMPLETIONS 1/1 — 끝나면 정리될 수 있으니(initdb Job 선례) 도는 동안 본다
kubectl -n data logs job/pg-main-1-full-recovery -c full-recovery --tail=50
#   컨테이너 이름은 VD-3 — 다르면 --all-containers 또는 kubectl -n data describe job pg-main-1-full-recovery
kubectl -n data describe cluster pg-main
kubectl -n data get events --sort-by=.lastTimestamp | Select-Object -Last 30
kubectl -n data get events --sort-by=.lastTimestamp -o json | Set-Content "$env:TEMP\restore-events-pg-main.json"
#   Events는 1시간 뒤 사라진다 — 삭제 뒤 60분 안에 저장(VD-2 · VD-3 증거)
```

- 3분 안에 Cluster가 다시 생기지 않으면(Application `OutOfSync` · 리소스 `Missing`): 운영자 **전체 수동 Sync** — 방법은 `bootstrap.md` §4 T056 「늦은 시드」 4단계와 같다(UI SYNC → `argocd app sync platform-cnpg-cluster` 플래그 없이 → JSON patch · `.operation`만 넣는 merge patch 금지).
- **멈춤 분기**:

| 증상 | 먼저 볼 것(agent-view 가능) | 원인 · 조치 |
|---|---|---|
| `Setting up primary` 고착 · 로그 `WAL archive check failed … Expected empty archive` | `kubectl -n data describe cluster pg-main` · 인스턴스 · 복구 Job 로그 | 새 serverName 접두가 비어 있지 않다(세대 재사용 · 옛 클러스터가 쓴 세그먼트) → 다음 세대로 3–4단계. 어노테이션으로 우회하지 않는다(§0 규칙 3) |
| 복구 Job `Failed` · 로그 `recovery ended before configured recovery target was reached` | 복구 Job 로그 | targetTime이 아카이브된 WAL 끝보다 뒤(PostgreSQL 13+ 동작) → §1로 끝을 다시 보고 targetTime을 앞당겨 3–4단계(PR 수정) |
| 복구 Job `Failed` · 기반 백업 없음 | 복구 Job 로그 · §1 | targetTime이 가장 오래된 completed 백업보다 앞(30일 창 밖) — 문구는 VD-3 |
| 로그 `SignatureDoesNotMatch` · `403` | 복구 Job · 사이드카 로그 | S3 키 쌍 → kv `platform/oci/s3` 정정(§1-1 실패 분기와 같다) |
| Pod `Pending` | `kubectl -n data describe pod -l cnpg.io/cluster=pg-main` | 노드 B 자원 · `role=data` 라벨 · PVC 바인딩 |

- **부수 안전망**: recovery 머지 **없이** 삭제해도 selfHeal이 만든 initdb 클러스터(serverName `pg-main`)는 빈 아카이브 검사에 걸려 `Setting up primary`에서 멈추고 옛 아카이브를 덮어쓰지 않는다(CNPG 1.30 문서 「Recovery」). 그때도 3 → 4 순서로 간다(멈춘 Cluster는 3단계 머지 뒤 4-b로 지운다 — 그 사이 그 빈 DB에 들어간 쓰기는 버려진다). `cnpg.io/skipEmptyWalArchiveCheck`는 이때도 금지다.

**5. 첫 조치 → 검증** — P1(`Cluster in healthy state`)을 본 **직후** 5-a · 5-b를 먼저(나란히) 하고, 그 뒤 5-c로 §7 「전체 PITR」 행을 전부 본다.

- **5-a 수동 Backup(첫 항목)**: 승격 ~ 첫 `pg-main-r<N>` Backup completed 사이의 쓰기는 두 번째 장애(PVC 손실) 때 복구할 수 없다 — 새 세대 접두에 base가 없고, 복구는 `externalClusters[].serverName` 접두 하나에서만 WAL을 읽는다(build-notes 「T058」 사실 3). 소비자는 `pg-main-rw`가 서는 즉시 다시 붙어 쓰기 시작하므로 이 창을 가장 짧게 둔다(빈 DB 수준은 수 초 — T053 첫 백업 3초). ScheduledBackup `pg-main-daily`는 Cluster 삭제에 살아남아 다음 17:00Z(02:00 KST)부터 새 접두로 백업하지만 `immediate`는 다시 돌지 않는다(CNPG v1.30.0 `scheduledbackup_controller.go` — `status.lastCheckTime`이 있으면 immediate 없음).

```powershell
# 5-a(운영자) — §1-4 yaml의 metadata.name을 pg-main-manual-<yyyymmdd>-post-pitr로 바꿔 $env:TEMP\pg-main-manual-backup.yaml로 저장한 뒤
kubectl -n data get cluster pg-main -o jsonpath='{.status.phase}'                      # (agent-view 가능) Cluster in healthy state — 아니면 기다린다(Backup은 pending으로 남는다)
kubectl --kubeconfig <admin kubeconfig> create -f "$env:TEMP\pg-main-manual-backup.yaml"
#   backup.postgresql.cnpg.io/pg-main-manual-<yyyymmdd>-post-pitr created
$bk = 'pg-main-manual-20261029-post-pitr'                # 저장한 metadata.name과 같게 — §7 P8이 이 변수를 쓴다
kubectl -n data get backup $bk -o jsonpath='{.status.phase} {.status.backupId} {.status.endWal}'   # (agent-view 가능) completed <backupId> <endWal> — 새 세대의 첫 복구 지점
```

- **5-b 비밀번호 재적용(필수 · 6 role 전부)**: 복구 직후 role과 비밀번호는 **복구 시점의 카탈로그 그대로**다. 인스턴스 매니저는 generation과 Secret resourceVersion이 바뀌지 않은 DatabaseRole을 다시 ALTER하지 않는다(CNPG v1.30.0 `databaserole_controller.go` `isAlreadyReconciled` — generation = observedGeneration이고 `status.secretResourceVersion` = `PasswordSecretChange` 조건 값이면 건너뛴다). 전체 PITR은 CR도 Secret도 바꾸지 않으므로 **저절로 재적용되지 않는다**(build-notes 「T058」 D5 ②의 전제를 정정한다) → 복구 시점 뒤의 회전 이력을 따지지 않고 **항상 6개 전부** 다시 적용시킨다(멱등 · 싸다 · 재적용 소요와 CR 생존은 VD-6).
  - ⚠ **보안**: 회전 사유가 유출이었다면 복구 직후에는 **옛 비밀번호가 다시 유효하다** → 이 단계를 P1 직후 첫 조치로(5-a와 나란히) 한다.
  - **1순위(선언적)**: gitops PR — `platform/cnpg-databases/databaseroles.yaml`의 DatabaseRole 6개 `comment` 끝에 ` - reapplied <yyyymmdd>`를 붙인다(예: `"… - platform-gitops T054 - reapplied 20261029"` · ASCII). generation이 1 늘고 인스턴스 매니저가 `ALTER ROLE … PASSWORD …` 전체를 다시 낸다. CI → 운영자 머지(3-b와 같은 명령).
  - **대안(PR을 기다릴 수 없을 때 · PR 경로가 실패했을 때 — 아래 5-b 실패 분기 · 운영자)**: Secret 6장을 지워 ESO가 다시 만들게 한다(≤ 5분 · 새 resourceVersion → `cnpg.io/reload` 라벨 → `PasswordSecretChange` → 재적용). 아래 대안 블록.
  - **확인**: 6행 전부 `APPLIED` true · GEN = OBS(PR 경로면 GEN이 PR 전보다 1 크다) + 로그인 성공 — US6 전에는 PostSync Job 재실행(`platform-cnpg-databases` 전체 수동 Sync — `bootstrap.md` §4 T056 「늦은 시드」 4단계 방법)의 로그 마지막 줄 `SUMMARY: pass=6 fail=0`. 머지 직후 자동 sync의 PostSync Job은 인스턴스 매니저의 ALTER 전에 돌아 fail로 찍힐 수 있다(그 Failed 리비전은 재시도되지 않는다) — GEN = OBS를 본 뒤 **전체 수동 Sync**로 다시 돈다.

```powershell
# 5-b 대안(운영자) — PR 경로를 쓰지 않을 때 또는 PR 경로가 실패했을 때(5-b 실패 분기). 이름 = passwordSecret 이름(값은 출력하지 않는다)
kubectl -n data get externalsecret -o 'custom-columns=N:.metadata.name,T:.spec.target.name'   # (agent-view 가능) 직전 확인 — pg-main-* 6행 · T(Secret 이름) = N(ES 이름) = 아래 6이름(그 밖의 행은 대상 아님)
if ((Read-Host '5-b 대안: ES 6행 확인? ns data의 DB 자격 Secret 6장 삭제 → ESO 재생성(≤ 5분 — 그 사이 그 Secret을 읽는 재조정 · Job은 실패할 수 있다) yes') -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data delete secret pg-main-identity-admin-owner pg-main-identity-admin-app pg-main-dev-identity-admin-owner pg-main-dev-identity-admin-app pg-main-authentik-owner pg-main-openfga-owner
#   secret "…" deleted × 6
```

```powershell
# 5-b 확인(agent-view 가능)
kubectl -n data get externalsecret -o 'custom-columns=N:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason'
#   pg-main-* 6장 True SecretSynced(대안 경로면 재생성 뒤)
kubectl -n data get databaserole -o 'custom-columns=N:.metadata.name,APPLIED:.status.applied,GEN:.metadata.generation,OBS:.status.observedGeneration,SRV:.status.secretResourceVersion'
#   6행 전부 APPLIED true · GEN = OBS
```

- **5-b 실패 분기**: APPLIED false 또는 GEN ≠ OBS가 5분 넘게 남거나 전체 수동 Sync(GEN = OBS 뒤)의 PostSync `SUMMARY`에 fail > 0이면: PR 경로를 썼으면 5-b 대안 블록(Secret 6장 삭제)으로 → ≤ 5분 뒤 같은 확인 블록 · 대안도 실패하면 그 role의 kv 경로와 Secret 키를 대조한다(§1-1 실패 분기의 kv 정정 경로와 같다) — 복구 자체는 되돌리지 않는다(데이터는 맞고 자격만 틀린 상태).

- **5-c 검증** — §7 「전체 PITR」 P2–P11. 핵심:

```powershell
kubectl -n data get cluster pg-main -o jsonpath='{.status.phase}|{.status.readyInstances}'          # (agent-view 가능) Cluster in healthy state|1
kubectl -n data get cluster pg-main -o jsonpath='{.status.conditions[?(@.type=="ContinuousArchiving")].status}'   # (agent-view 가능) True
kubectl -n data get database -o 'custom-columns=N:.metadata.name,DB:.spec.name,APPLIED:.status.applied,MSG:.status.message'         # (agent-view 가능) applied true × 4
kubectl -n data get databaserole -o 'custom-columns=N:.metadata.name,ROLE:.spec.name,APPLIED:.status.applied,MSG:.status.message'   # (agent-view 가능) applied true × 6
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tAc "SELECT datname FROM pg_database ORDER BY 1"
#   authentik · dev_identity_admin · identity_admin · openfga · platform · postgres · template0 · template1 — app은 없어야 한다
oci --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup --prefix pg-main/pg-main-r1/ --all --fields name,size,timeCreated
#   pg-main/pg-main-r1/wals/… — 첫 세그먼트는 활동 뒤 300초 안(archive_timeout) · base/는 5-a 수동 Backup 뒤
```

- **CA**: `pg-main-ca`는 새 클러스터가 새로 만든다 → CA 미러 ExternalSecret(T056 · 갱신 주기 5분)이 앱 ns로 옮긴 뒤, TLS 검증을 하는 소비자 pod를 재시작한다(US6 뒤 · VD-7). PostSync Job은 `pg-main-ca`를 직접 마운트하므로 다음 실행부터 새 CA다.
- CONNECT 제한(`datacl`)은 DB 카탈로그와 함께 복구 시점 값으로 돌아온다(PostSync Job ⓪①이 다음 전체 sync에서 다시 낸다 — 멱등).

**6. 후속**(운영자 · 같은 날)

1. **새 세대 카탈로그 확인**: 노드 B 재조인 뒤 §1-1 Job의 `command` 마지막 줄 `pg-main`을 `pg-main-r<N>`으로 바꿔 ②–⑥을 한다 → 5-a의 backupId가 Archival Status 빈 칸(DONE)으로 보인다(출력 모양은 VD-12).
2. **옛 세대 Backup CR은 새 사이드카가 지우지 않는다**(plugin v0.14.0 `retention.go` `useSameBackupLocation` — `status.pluginMetadata.clusterUID`가 새 Cluster UID와 다르면 건너뛴다 · 같은 이름으로 재생성해도 UID는 바뀐다). 운영자가 아래 판정 → 정지점 → 삭제로 지운다(Backup CR 삭제는 버킷 오브젝트를 지우지 않는다 — gitops README §5 · 옛 세대 백업은 버킷 접두와 §1-1 Job(옛 serverName)으로 계속 보인다). 지우기 전까지 하네스 backup-2(최신 completed ≤ 25시간)는 옛 세대 completed로 PASS할 수 있다(거짓 안심) — 새 세대의 복구 지점은 5-a 수동 Backup으로 판단한다.

```powershell
# 6-2 판정(agent-view 가능) — 지금 Cluster의 UID와 Backup CR마다의 Cluster 이름 · UID
kubectl -n data get cluster pg-main -o jsonpath='{.metadata.uid}'
kubectl -n data get backup -o 'custom-columns=N:.metadata.name,C:.spec.cluster.name,UID:.status.pluginMetadata.clusterUID,ID:.status.backupId,P:.status.phase'
#   C = pg-main이고 UID가 위 값과 다른 행 = 옛 세대(2-b′ -pre-pitr 포함) · UID가 빈 행(<none> — running · pending · failed)과
#   C가 pg-main이 아닌 행(다른 Cluster의 Backup)은 고르지 않는다
```

```powershell
# 6-2 삭제(운영자) — 판정의 C = pg-main · 옛 UID 행만 이름으로 지운다(라벨 셀렉터 · --all 금지)
$uid = kubectl -n data get cluster pg-main -o jsonpath='{.metadata.uid}'
if (-not $uid) { throw 'Cluster UID 비었음 — 판정부터' }
$rows = kubectl -n data get backup -o jsonpath='{range .items[*]}{.metadata.name}{"|"}{.spec.cluster.name}{"|"}{.status.pluginMetadata.clusterUID}{"\n"}{end}'
$old = @($rows | Where-Object { $_ -cmatch '^([^|]+)\|pg-main\|(.+)$' -and -not [string]::Equals($Matches[2], $uid, [StringComparison]::Ordinal) } | ForEach-Object { ($_ -split '\|')[0] })
$old                                                      # 지울 이름 — 판정 출력의 C = pg-main · 옛 UID 행과 같은지 눈으로 대조한다
if ($old.Count -eq 0) { throw '옛 세대 Backup CR 없음 — 지울 것이 없다' }
if ((Read-Host "위 $($old.Count)개 = 판정의 C = pg-main · 옛 UID 행? 옛 세대 Backup CR 삭제(버킷 오브젝트는 그대로) yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data delete backup $old
#   backup.postgresql.cnpg.io "…" deleted × $old.Count
```

3. 모노레포 `tests/platform/data.tests.ps1`의 `$serverName`을 새 세대로 바꾼다(별도 커밋) — 그 전에는 bucket-1 · bucket-2가 옛 접두를 보므로 FAIL이 정상이다.
4. 옛 접두 `pg-main/<직전 세대>/` 오브젝트는 새 사이드카의 보존 정리 대상이 아니다(serverName이 다르다) → **30일 뒤**(직전 세대에서 다시 복구할 창을 지킨 뒤) 운영자가 수동 정리한다. versioning이 지운 객체를 이전 버전으로 60일 더 남긴다(gitops README §5).
5. PV Retain을 했다면 포렌식이 끝난 뒤 PV를 지우고 노드 B의 그 디렉터리를 정리한다(VD-11 — 디렉터리 이름은 `ssh ssh-b "sudo ls -d /var/lib/rancher/k3s/storage/$pv*"`로 먼저 확인한다. 삭제 명령에 자리표시자를 쓰지 않는다):

```powershell
if (-not $pv) { throw '$pv 비었음 — 2-a의 PV 이름' }
if ((Read-Host "포렌식 끝? PV $pv 삭제(노드 B 디렉터리는 확인한 정확한 경로로 따로 지운다) yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> delete pv $pv
```

6. `bootstrap.md` §3에 실행 기록(시각 · 세대 · 목표 시각 · 소요 · VD-1 · 2 · 3 · 6 · 9 · 13 관찰)을, 이 문서 §9에 한 행을 남긴다.

### §3-2 경로 B — 새 이름 + 참조 교체(옛 클러스터를 살려 둘 때만)

- **목적**: 옛 클러스터 `pg-main`을 지우지 않은 채 복구본 `pg-main-restored`를 만들어 비교하고, 검증 뒤 **앱 Secret/Service 참조를 교체**한 다음 옛 Cluster를 지운다(**PVC 보존**은 §3-1 2단계와 같은 PV Retain). research CNPG-D8의 원래 모양이다.
- **전제**: §3-1의 전제 + 노드 B에 둘째 클러스터를 띄울 자원. 노드 B CPU 여유는 ≈ 165m(10-13 `describe node` 실측 1635m + T057 Dragonfly 200m를 더한 추정 — build-notes 「T058」 사실 6)라 **운영 자원 그대로(1 CPU)의 둘째 클러스터는 스케줄되지 않는다** → 복구본은 축소 자원으로만 뜨고, 옛 클러스터를 지운 뒤 자원을 되돌리는 PR(재시작 동반)이 하나 더 든다.
- **비용 · 권고**: 바꿀 곳이 10여 곳이고 그 사이 두 클러스터가 공존한다 → **경로 A(§3-1)를 권장**한다. 아래 표는 경로 B를 고를 때의 체크리스트다(각 줄이 gitops PR 또는 운영자 kv 변경 하나).

| 대상 | 경로 B에서 하는 일 | 이유 |
|---|---|---|
| Cluster | 새 파일 — §3-1 매니페스트에서 `metadata.name: pg-main-restored` · `plugins[].parameters.serverName: pg-main-restored` · resources 축소(삭제 보호 어노테이션 유지) | 같은 ObjectStore에서 serverName 고유 |
| `DatabaseRole` 6 · `Database` 4 | `cluster.name: pg-main-restored`인 **새 객체**(새 metadata.name) → 옛 객체 삭제(`retain`이라 옛 클러스터의 role · DB는 그대로 남는다) | `cluster.name`은 생성 뒤 불변(CEL) |
| CA 미러 ExternalSecret 5 | `remoteRef.key: pg-main-ca` → `pg-main-restored-ca` | CA는 클러스터마다 새로 생긴다 |
| kv DB 자격 6경로의 `url` | 호스트 `pg-main-rw` → `pg-main-restored-rw` → ESO ≤ 5분 → 소비자 pod 재시작 | Service 이름이 클러스터 이름을 따른다 |
| PostSync Job `cnpg-databases-access` | 접속 호스트 · CA Secret 이름 | 같은 이유 |
| data-assert Job ConfigMap · 하네스 상수(`$clusterName` · `$serverName` · argo-4-pg-main) | 새 이름 | 검사 대상 이름 |
| ScheduledBackup | `cluster.name: pg-main-restored`인 새 객체 | `cluster.name` 불변 |
| 옛 Cluster `pg-main` | git에서 제거 → `Delete=false,Prune=false`라 Argo는 지우지 않으므로 운영자가 `kubectl --kubeconfig <admin kubeconfig> -n data delete cluster pg-main`(§3-1 4-b와 같은 정지점 · PVC 보존이면 PV Retain 먼저) | 삭제 보호는 Argo 경로만 막는다 |

- **다음 단계**: 교체가 끝나면 §3-1 5 · 6단계와 같은 검증 · 후속(세대 이름만 `pg-main-restored`).

## §4 절차 B — 단일 DB 복구(side Cluster PITR → pg_dump → 운영 복원)

**단일 DB 복구 = side Cluster로 PITR → 해당 DB만 `pg_dump` → 운영 클러스터 복원**(FR-018 · FR-041 · 과제 T058 문면). PITR은 클러스터 전체 복원이라 운영 클러스터에서 한 DB만 되돌릴 수 없다 → 임시 **side Cluster**를 목표 시각으로 복구하고, 그 DB 하나만 `pg_dump`해 운영 `pg-main`의 같은 DB에 `pg_restore`한다. 다른 DB는 손대지 않는다.

- **목적**: 한 DB의 잘못된 쓰기 · 삭제를 그 DB만 targetTime 상태로 되돌린다.
- **전제**: 대상 DB와 targetTime(UTC `Z`)이 정해졌다 · §1에서 targetTime 이전 completed 백업과 그 구간 WAL을 확인했다 · §4-1 점검 통과 · 그 DB의 소비자(pod · Authentik · OpenFGA)가 §4-4부터 §4-6까지 접속하지 못한다 = **그 DB의 서비스 중단**을 알렸다 · 창 동안 gitops `platform/cnpg-databases/`와 그 pod의 배포를 머지하지 않는다(PostSync Job ⓪①과 migrate Job이 CONNECT를 다시 준다).
- **방법의 근거**: CNPG 기본 pg_hba `local all all peer map=local`(CNPG `pkg/postgres/configuration.go`) → 파드 안 OS 사용자 `postgres`(uid 26)가 `psql` · `pg_dump` · `pg_restore -U postgres`로 **비밀 없이** superuser로 붙는다(`kubectl cnpg psql`과 같은 경로 · 라이브 미실측 — VD-4). 운영 이미지의 `/usr/lib/postgresql/18/bin`(`psql` · `pg_dump` · `pg_restore` · `createdb` · `dropdb`)이 PATH에 있고 `/bin/sh`는 dash다. 워크스테이션을 거치는 파드 → 파드 파이프는 pwsh 7.4 이상에서 바이트를 보존한다(pwsh 7.6.9 실측 — build-notes 「T058」 사실 7 · 큰 DB는 §4-5 sha256 대조 변형 · VD-5).
- **소요**: 미실측(side 복구 = 베이스 백업 크기 + WAL 재생 · dump/restore = DB 크기 — VD-3).
- **다음 단계**: §4-0부터 차례로 → §7 「단일 DB」 → §9 기록.

### §4-0 변수

```powershell
# §4-0(창 B · 운영자) — 아래 블록이 전부 쓴다. 값은 예시다 — 바꾼다. 새 창에서 이어 할 때는 기록한 값으로 다시 정한다
$db      = 'identity_admin'                              # 복구할 DB 하나: identity_admin · dev_identity_admin · authentik · openfga
$roles   = 'identity_admin_app, identity_admin_owner'    # CONNECT를 막고 되돌릴 role — pod DB = '<db>_app, <db>_owner' · 공유 DB(authentik · openfga) = '<db>_owner'
$owner   = 'identity_admin_owner'                        # pg_restore --role = 객체 소유자 '<db>_owner'
$side    = 'pg-main-restore-20261029'                    # §4-2 매니페스트의 metadata.name과 같게
$sidePod = "$side-1"
$ts      = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$pre     = "/var/lib/postgresql/data/$db-pre-restore-$ts.pgc"   # 되돌리기용 dump(§4-3) — pg-main-1 PVC, PGDATA(…/pgdata) 밖
# 행 수 대조 질의(§4-5 임시 DB · §4-7) — 테이블마다 정확한 count(*)를 'schema.table=N' 한 줄로
$q = "SELECT table_schema || '.' || table_name || '=' || (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM %I.%I', table_schema, table_name), false, true, '')))[1]::text FROM information_schema.tables WHERE table_type = 'BASE TABLE' AND table_schema NOT IN ('pg_catalog', 'information_schema') ORDER BY 1"
if (-not ($db -and $roles -and $owner -and $side)) { throw '§4-0 변수 누락' }
"db=$db roles=$roles owner=$owner side=$side pre=$pre"   # 실행 기록에 적는다
```

### §4-1 사전 점검

```powershell
# 판정(agent-view 가능) — 노드 B 여유: side 인스턴스 requests 100m + 복구 Job 사이드카 50m = 150m
kubectl describe node -l role=data | Select-String -Pattern '^Allocated resources' -Context 0,6
#   cpu Requests 합 — 아래 할당 가능 값에서 뺀 여유가 150m 이상이면 매니페스트 그대로, 100–149m면 requests.cpu를 50m로 고쳐 적용, 100m 미만이면 진행하지 않는다
kubectl get node -l role=data -o jsonpath='{.items[0].status.allocatable.cpu} {.items[0].status.allocatable.memory}'
#   할당 가능 총량(10-13 기준 cpu ≈ 2 · memory ≈ 12.9 GiB — build-notes 「T058」 사실 6)
kubectl -n data get backup -o 'custom-columns=N:.metadata.name,P:.status.phase,ID:.status.backupId,END:.status.stoppedAt'
#   targetTime 이전에 끝난 completed 백업이 있다(§1)
```

```powershell
# 판정(운영자) — 디스크: side는 클러스터 전체(모든 DB)를 복구한다
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tAc "SELECT pg_size_pretty(sum(pg_database_size(datname))::bigint) FROM pg_database"
ssh ssh-b "df -h /var/lib/rancher/k3s/storage"
#   Avail이 위 크기 + WAL 재생분보다 넉넉해야 한다(local-path는 용량을 강제하지 않는다 — 40Gi는 명목값)
```

### §4-2 side Cluster 생성(복구)

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-main-restore-20261029        # 날짜 접미 — 하네스 · Argo가 보는 pg-main과 다른 이름 · 임시 객체(삭제 보호 어노테이션 없음)
  namespace: data
  labels:
    app.kubernetes.io/part-of: restore-drill
spec:
  instances: 1
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: postgresql-standard-trixie
    major: 18                           # 원본과 같은 major(PITR 전제) · 같은 digest → zstd WAL 재생 가능
  enableSuperuserAccess: false
  storage:
    storageClass: local-path
    size: 40Gi
  resources:
    requests:
      cpu: 100m                         # 노드 B CPU 여유 ≈ 165m(사실 6) — §4-1 점검 · 모자라면 50m
      memory: 1Gi
    limits:
      memory: 1536Mi
  affinity:
    enablePodAntiAffinity: false
    nodeSelector:
      role: data
  postgresql:
    parameters:
      max_connections: "100"            # 복구(hot_standby) 제약 — 원본 값 이상
      shared_buffers: 128MB
      max_parallel_workers: "2"
  bootstrap:
    recovery:
      source: origin
      database: platform
      owner: platform_owner
      recoveryTarget:
        targetTime: "2026-10-29T03:00:00Z"   # RFC3339 · 시간대 명시(Z) — 복구하려는 시점(KST − 9h)
  externalClusters:
    - name: origin
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: oci-backups
          serverName: pg-main             # 현재 세대의 아카이브 접두(전체 PITR 뒤에는 pg-main-r<N>)
  # spec.plugins 없음 = 이 클러스터는 WAL을 아카이브하지 않는다(버킷 쓰기 0 · serverName 충돌 0 · 플러그인 문서)
```

- 바꿀 곳은 셋이다: `metadata.name`(§4-0 `$side`) · `targetTime` · `externalClusters`의 `serverName`(현재 세대).
- `spec.plugins`가 없다 = 아카이브하지 않는다 → 버킷에 쓰지 않고 serverName이 충돌하지 않는다. 삭제 보호 어노테이션이 없는 임시 객체이고(§4-8에서 지운다), 이름이 `pg-main`과 달라 하네스(라벨 · 이름 정확 일치)와 argo-4-pg-main에 보이지 않는다(build-notes 「T058」 사실 8).
- 같은 카탈로그 major 18(같은 digest)이라 노드 B에서 이미지를 새로 받지 않는다. 원본과 같은 major가 PITR의 전제다.
- **노출**: side는 운영과 같은 소비자 경로(5432)에 열려 있다 — ns `data` 정책 `allow-from-apps` · `allow-from-identity`(gitops `platform/policies/policies-matrix.yaml`)가 `podSelector: {}`라 jt-dev · jt-prod · identity 파드가 side `-rw:5432`에 닿고, side는 백업 시점의 role 비밀번호 · `datacl`을 그대로 가진다(승격 뒤 쓰기 가능). → §4-8까지 수명을 짧게 둔다.
- **자원 · QoS**: memory limit 1536Mi · CPU limit 없음(Burstable) — 운영 `pg-main`은 requests(1 CPU)로 CFS 가중치가 보호되고 노드 B memory 여유가 커(≈ 9 GiB — build-notes 「T058」 사실 6) eviction 위험은 낮다(VD-3에서 실측).

```powershell
# 적용(운영자) — 위 yaml 블록을 고쳐 $env:TEMP\pg-main-restore.yaml로 저장한 뒤
kubectl --kubeconfig <admin kubeconfig> apply -f "$env:TEMP\pg-main-restore.yaml"
#   cluster.postgresql.cnpg.io/pg-main-restore-20261029 created
```

```powershell
# 관찰(agent-view 가능)
kubectl -n data get cluster $side -w
#   Setting up primary → … → Cluster in healthy state(Ctrl+C)
kubectl -n data get job
#   <side>-1-full-recovery → COMPLETIONS 1/1 — 끝나면 정리될 수 있으니 도는 동안 아래 로그를 본다
kubectl -n data logs "job/$side-1-full-recovery" -c full-recovery --tail=200 | Select-String 'recovery stopping|last completed transaction|recovery ended'
#   PostgreSQL 복구 종료 줄 — 'recovery stopping before commit … time <시각>' = 목표 시각에서 멈췄다(컨테이너 이름은 VD-3)
kubectl -n data describe cluster $side
#   멈추면 Events부터
```

```powershell
# 확인(운영자) — 승격 · 시점
kubectl -n data get cluster $side -o jsonpath='{.status.phase}|{.status.readyInstances}'   # (agent-view 가능) Cluster in healthy state|1
kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- psql -X -tAc "SELECT now(), pg_is_in_recovery()"
#   <지금 시각>|f — 복구가 끝나고 승격했다
kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- psql -X -d $db -c '\dt'
#   목표 시각의 테이블 — 시점 대조는 업무 테이블의 시각 열로 한다(예: 그 열의 max가 목표 시각 이하)
```

- **멈춤 분기**: Pod `Pending`(Insufficient cpu) → requests.cpu 50m로 고쳐 지우고 다시 적용 · 복구 Job 로그 `recovery ended before configured recovery target was reached` → targetTime이 WAL 끝보다 뒤(§1) · 기반 백업 없음 → targetTime이 30일 창 밖 · `SignatureDoesNotMatch` · 403 → §1-1 실패 분기.
- **Argo**: side Cluster는 Argo가 모르는 객체라 `OrphanedResourceWarning` 조건이 붙는다(무해 · VD-8).

### §4-3 되돌리기용 현재 상태 dump

- **목적**: 복원이 틀렸을 때 지금 상태로 돌아갈 파일(§8). 복원과 **같은 옵션**(`--exclude-extension='*'`)으로 떠야 §8에서 같은 `pg_restore` 명령으로 되돌릴 수 있다(확장은 superuser 소유라 owner role로는 `DROP EXTENSION` · `CREATE EXTENSION`을 할 수 없다 — §4-5 근거).
- 파일은 `pg-main-1` PVC(`/var/lib/postgresql/data/` — PGDATA `…/pgdata` 밖)에 둔다. 워크스테이션의 PowerShell 리다이렉트(`>`)로 받지 않는다 — PowerShell 버전에 따라 바이트가 바뀔 수 있어(이 저장소에서 미실측) 그 경로를 피한다. PVC가 빠듯하면 side 파드로 보낼 수 있지만(`… | kubectl --kubeconfig <admin kubeconfig> -n data exec -i $sidePod -c postgres -- sh -c "cat > …"`) 그때는 §8이 끝날 때까지 side를 지우지 않는다.

```powershell
# 운영자 — 파드 안에서 파일로 · 해시와 크기를 실행 기록에 적는다(비밀 아님 — §8 되돌리기가 이 해시로 파일을 다시 대조한다)
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- sh -c "pg_dump -U postgres -Fc --exclude-extension='*' $db > $pre && ls -l $pre"
#   /var/lib/postgresql/data/<db>-pre-restore-<ts>.pgc · 크기 > 0
$preHash = ((kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- sha256sum $pre) -split '\s+')[0]
if ($preHash -notmatch '^[0-9a-f]{64}$') { throw "pre-restore dump 해시를 얻지 못했다('$preHash') — 덤프부터 다시" }
"preHash=$preHash"                                       # 실행 기록에 적는다 — 새 창이면 §8 전에 기록 값으로 $preHash를 다시 정한다
```

### §4-4 쓰기 정지

```powershell
# 판정(운영자) — 지금 붙어 있는 소비자와 지금의 CONNECT 권한(§4-6에서 같은 값으로 돌아와야 한다)
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tAc "SELECT usename, application_name, count(*) FROM pg_stat_activity WHERE datname = '$db' GROUP BY 1, 2 ORDER BY 1, 2"
#   이 세션들이 끊긴다(서비스 중단 시작)
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tAc "SELECT datacl FROM pg_database WHERE datname = '$db'"
#   pod DB {=T/<db>_owner,<db>_owner=CTc/<db>_owner,<db>_app=c/<db>_owner} · 공유 DB {=T/<db>_owner,<db>_owner=CTc/<db>_owner}
```

```powershell
# 변경(운영자) — 판정 출력과 §4-3 해시 기록을 본 뒤에만
if (-not ($db -and $roles)) { throw '§4-0 변수부터' }
if ((Read-Host "§4-2 side healthy · §4-3 덤프 해시 기록 끝? $db 접속 차단(REVOKE CONNECT + 세션 종료 — 서비스 중단 시작) yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -v ON_ERROR_STOP=1 -c "REVOKE CONNECT ON DATABASE $db FROM $roles" -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db' AND pid <> pg_backend_pid()"
#   REVOKE · 끊은 세션마다 t
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tAc "SELECT count(*) FROM pg_stat_activity WHERE datname = '$db'"
#   0 — 남아 있으면 위 pg_terminate_backend 줄을 한 번 더
```

- 쓰기 정지는 CR 밖 SQL로 한다: `Database` CR의 `allowConnections`는 비어 있으면 인스턴스 매니저가 ALTER하지 않는다(CNPG `database_controller_sql.go`) → CR이 되돌리지 않는다. `ALTER DATABASE … ALLOW_CONNECTIONS false`는 superuser까지 막아 복원이 안 되므로 쓰지 않는다(§0 규칙 7). superuser `postgres`는 CONNECT 권한과 무관하게 붙는다.
- REVOKE 대상: pod DB = `<db>_app, <db>_owner` · 공유 DB(`authentik` · `openfga`) = `<db>_owner`(app role이 없다). PUBLIC은 이미 닫혀 있다(PostSync Job ⓪①).

### §4-5 복원

- **선택 — 검증용 임시 DB 먼저**: 운영 DB를 바꾸기 전에 같은 파이프가 끝까지 도는지 임시 DB `<db>_restore`로 본다(운영 DB에 닿지 않으므로 §4-4 전에 해도 된다).

```powershell
# 선택(운영자) — 임시 DB: owner로 만들고 PUBLIC CONNECT를 닫는다(다른 앱 role이 붙지 못하게)
$tmpdb = "${db}_restore"
if ($tmpdb -notlike '*_restore') { throw '임시 DB 이름 확인' }
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- createdb -U postgres -O $owner $tmpdb
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -v ON_ERROR_STOP=1 -c "REVOKE CONNECT ON DATABASE $tmpdb FROM PUBLIC"
#   pod DB(identity_admin · dev_identity_admin)는 확장 vector를 쓴다 — dump에서 확장을 뺐으므로 임시 DB에 superuser로 먼저 만든다(공유 DB는 이 줄을 건너뛴다)
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -v ON_ERROR_STOP=1 -d $tmpdb -c "CREATE EXTENSION IF NOT EXISTS vector"
kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- pg_dump -U postgres -Fc --exclude-extension='*' $db |
  kubectl --kubeconfig <admin kubeconfig> -n data exec -i pg-main-1 -c postgres -- pg_restore -U postgres -d $tmpdb --no-owner --role=$owner --single-transaction --exit-on-error
"exit=$LASTEXITCODE"
#   exit=0이면 아래 대조 블록으로
```

```powershell
# 선택(운영자) — 임시 DB와 side의 행 수 대조($q는 §4-0) → 같으면 임시 DB를 지운다
$a = kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- psql -X -tA -d $db -c $q
$t = kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tA -d $tmpdb -c $q
[string]::Equals(($a -join "`n"), ($t -join "`n"), [StringComparison]::Ordinal)
#   True = 파이프 · 옵션이 이 DB에서 끝까지 돈다 → 운영 복원(다음 블록)으로
if ($tmpdb -notlike '*_restore') { throw '임시 DB 이름 확인' }
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- dropdb -U postgres $tmpdb
```

```powershell
# 복원(운영자) — §4-4 판정(접속 0) 뒤에만. 끝의 |가 다음 줄로 잇는 한 줄 파이프다
if (-not ($db -and $owner -and $sidePod)) { throw '§4-0 변수부터' }
if ((Read-Host "§4-4 접속 0 확인? $db 를 $side 의 $db 로 교체(pg_restore --clean · 한 트랜잭션) yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- pg_dump -U postgres -Fc --exclude-extension='*' $db |
  kubectl --kubeconfig <admin kubeconfig> -n data exec -i pg-main-1 -c postgres -- pg_restore -U postgres -d $db --clean --if-exists --no-owner --role=$owner --single-transaction --exit-on-error
"exit=$LASTEXITCODE"
#   exit=0 · 오류 줄 없음 = 성공. 오류면 한 트랜잭션이라 $db는 바뀌지 않았다(원자적) → 오류 첫 줄을 기록하고(아래 멈춤 분기) §4-6으로 가서 접속부터 되돌린다
```

- **옵션의 근거**:
  - `-U postgres` = 파드 안 peer 인증(비밀 0).
  - `--exclude-extension='*'`(PostgreSQL 17부터의 `pg_dump` 옵션 — 18 문서): 확장(`vector` 등)은 `Database` CR이 superuser로 만들어 소유한다 → owner role로는 `--clean`의 `DROP EXTENSION`과 `CREATE EXTENSION`이 실패하므로 dump에서 뺀다. 대상 DB에는 이미 있으므로 벡터 열 같은 종속 객체는 그대로 만들어진다.
  - `--no-owner --role=<db>_owner`: 접속 뒤 `SET ROLE <db>_owner` → 만든 객체의 소유자 = owner(마이그레이션이 만든 원래 소유자와 같다).
  - `--clean --if-exists`: dump에 든 객체를 먼저 지우고 다시 만든다(없는 객체는 건너뛴다). **dump에 없는 객체(targetTime 뒤에 새로 만든 테이블 · 스키마)는 지우지 않는다** → §4-7 대조에서 보이면 운영자가 판단한다(§4-9).
  - `--single-transaction --exit-on-error`: 전부 아니면 전무다 — 중간 오류 · 잘린 입력이면 롤백된다(pg_restore 문서: single-transaction은 exit-on-error를 함의한다 · 병렬 `-j`와 함께 쓸 수 없고 `-j`는 파이프 입력도 받지 않는다). 객체가 아주 많으면 lock table이 모자라 실패할 수 있다(PostgreSQL `max_locks_per_transaction` — 공유 잠금 테이블의 크기를 정한다 · 넘치면 `out of shared memory`) — 그때도 바뀐 것은 없다(원인 기록).
  - PostgreSQL 18 `pg_dump`는 통계를 기본으로 빼므로(`--no-statistics`가 기본값) 복원 뒤 `ANALYZE`가 필요하다(§4-6).
- **멈춤 분기**(복원 블록 `exit≠0` — 한 트랜잭션이라 `$db`는 바뀌지 않았다 · 그다음은 언제나 §4-6 접속 복귀):
  - `cannot drop … because other objects depend on it` = targetTime 뒤에 만든 객체가 dump의 객체에 의존한다(예: 새 테이블의 외래 키가 dump의 테이블을 가리킨다 — `--clean`은 dump 객체마다 `DROP … IF EXISTS`를 낸다 · PostgreSQL 18 `pg_restore` 문서). 의존 객체는 운영 `$db`에만 있다(임시 DB는 side dump라 없다) → 운영 `$db`에서 `kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -d $db -c '\d+ <그 테이블>'`의 `Referenced by`로 찾아 운영자가 판단한다 — 그 객체를 먼저 백업한 뒤 DROP하고 다시 하거나, 복원을 멈춘다. 자동 CASCADE는 쓰지 않는다.
  - `out of shared memory`(HINT `max_locks_per_transaction`) = 위 옵션 근거의 잠금 한도 — 바뀐 것은 없다(원인 기록 · 큰 DB면 운영자 판단).
  - 그 밖: 오류 첫 줄을 기록하고 원인을 본다(§4-5 임시 DB로 같은 파이프를 먼저 돌려 재현할 수 있다).

큰 DB · 바이트 의심(VD-5) 변형(운영자 · 위 파이프 대신) — ① 준비 · 기계 대조 → ② 정지점 · 복원 → ③ 정리를 다른 블록으로 나눈다:

```powershell
# ① 준비 · 대조(운영자 — 운영 DB는 바뀌지 않는다): side에서 파일로 dump → 운영 파드로 복사 → 두 sha256을 기계로 대조
if (-not ($db -and $owner -and $sidePod -and $ts)) { throw '§4-0 변수부터' }
$xfer = "/var/lib/postgresql/data/$db-xfer-$ts.pgc"
kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- sh -c "pg_dump -U postgres -Fc --exclude-extension='*' $db > $xfer && ls -l $xfer"
kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- cat $xfer |
  kubectl --kubeconfig <admin kubeconfig> -n data exec -i pg-main-1 -c postgres -- sh -c "cat > $xfer"
$h1 = ((kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- sha256sum $xfer) -split '\s+')[0]
$h2 = ((kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- sha256sum $xfer) -split '\s+')[0]
"side=$h1 target=$h2"
if ($h1 -notmatch '^[0-9a-f]{64}$' -or -not [string]::Equals($h1, $h2, [StringComparison]::Ordinal)) { throw 'sha256 불일치 또는 빈 값 — 복원하지 않는다(③ 정리로 두 파일을 지운다)' }
'sha256 일치 — ② 복원으로'
```

```powershell
# ② 복원(운영자) — ①이 'sha256 일치'로 끝난 뒤에만
if (-not ($db -and $owner -and $xfer -and $h1) -or -not [string]::Equals($h1, $h2, [StringComparison]::Ordinal)) { throw '① 대조부터' }
if ((Read-Host "① sha256 일치 · §4-4 접속 0 확인? $db 를 $xfer 로 교체(pg_restore --clean · 한 트랜잭션) yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- pg_restore -U postgres -d $db --clean --if-exists --no-owner --role=$owner --single-transaction --exit-on-error $xfer
"exit=$LASTEXITCODE"
#   exit=0 = 성공 · 아니면 위 멈춤 분기 → §4-6
```

```powershell
# ③ 정리(운영자) — 복원 여부와 무관하게 두 파일을 지운다
if (-not ($xfer -and $sidePod)) { throw '$xfer · $sidePod 비었음 — ①의 값으로' }
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- rm -f $xfer
kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- rm -f $xfer
```

### §4-6 접속 복귀 · 통계

```powershell
# 운영자 — §4-5가 실패했어도 여기로 와서 접속을 되돌린다(그때 DB는 그대로다)
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -v ON_ERROR_STOP=1 -d $db -c "GRANT CONNECT ON DATABASE $db TO $roles" -c "ANALYZE"
#   GRANT · ANALYZE
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tAc "SELECT datacl FROM pg_database WHERE datname = '$db'"
#   §4-4 판정 블록에서 본 값과 같다(PUBLIC 항목 =T/…에 c 없음 · <db>_app · <db>_owner에 c)
```

- GRANT 문장은 PostSync Job `cnpg-databases-access`의 ⓪(pod DB — `GRANT CONNECT ON DATABASE <db> TO <db>_app, <db>_owner`) · ①(공유 DB — `… TO <db>_owner`)과 같은 모양이다 — 다음 전체 sync에서 같은 문장이 멱등으로 다시 나간다.
- 단일 DB dump에는 DB 수준 ACL이 들어 있지 않아(`pg_dump`는 `-C` 없이 DB 속성을 쓰지 않는다) `datacl`은 복원과 무관하게 §4-4 전의 값 그대로다 — PUBLIC CONNECT가 다시 열리지 않는다.

### §4-7 검증

```powershell
# 운영자 — 테이블별 정확한 행 수(count(*) · $q는 §4-0)를 side와 대조한다(ANALYZE 추정치가 아니다)
if (-not $q) { throw '$q 비었음 — §4-0 블록부터' }
$a = kubectl --kubeconfig <admin kubeconfig> -n data exec $sidePod -c postgres -- psql -X -tA -d $db -c $q
$b = kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tA -d $db -c $q
[string]::Equals(($a -join "`n"), ($b -join "`n"), [StringComparison]::Ordinal)
#   True = 모든 테이블의 행 수가 side와 같다
@($b | Where-Object { $a -cnotcontains $_ })              # 운영에만 있는 줄 — dump에 없던 객체(targetTime 뒤 생성) 또는 행 수 차이
@($a | Where-Object { $b -cnotcontains $_ })              # side에만 있는 줄
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -d $db -c '\dt'
#   테이블 목록 · 소유자 = <db>_owner
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -d $db -c "SELECT schemaname, relname, n_live_tup FROM pg_stat_user_tables ORDER BY 1, 2"
#   ANALYZE 뒤 추정치 — 표본 확인용
```

- 접속 복귀: `SELECT usename, count(*) FROM pg_stat_activity WHERE datname = '<db>' GROUP BY 1`에 소비자 세션이 다시 보인다 · 소비자 `/ready`(US6 뒤).
- 다음 단계: §4-8 정리 → §7 「단일 DB」.

### §4-8 정리

```powershell
# side Cluster 삭제(운영자) — §4-7 통과 뒤에만. 이름을 정확히 적는다(라벨 셀렉터로 지우지 않는다 — pg-main과 섞일 수 있다)
if (-not $side) { throw '§4-0 변수부터' }
if ((Read-Host "§4-7 검증 통과? side Cluster $side 삭제(PVC 함께 삭제) yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data delete cluster $side
#   cluster.postgresql.cnpg.io "pg-main-restore-20261029" deleted
kubectl -n data get cluster,pvc                           # (agent-view 가능) pg-main · pg-main-1만 남는다(side PVC는 reclaim Delete — VD-10)
```

```powershell
# 되돌리기용 dump 소거(운영자) — §8 단일 DB 되돌리기가 필요 없다고 판단한 뒤(소비자 확인 · 하루 정도의 창)
if (-not $pre) { throw '$pre 비었음 — §4-0 기록 값으로' }
if ((Read-Host "되돌리기 창 종료? $pre 삭제 yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- rm -f $pre
```

### §4-9 결과의 뜻

- 그 DB만 targetTime 상태다. 다른 DB · Kafka 토픽 · Dragonfly는 그대로다.
- **outbox**: targetTime 전에 들어갔지만 그 뒤에 발행된 outbox 행은 다시 미발행으로 보여 재발행된다 → 소비자는 `(consumer_group, id)`를 저장해 멱등 처리한다(`contracts/events.md` :26). targetTime 뒤에 생긴 행의 이벤트는 **Kafka에만 남는다** — 원천 DB에서 사라진 상태의 재투영은 소비자 몫이다(`contracts/events.md` :7 — 원천은 각 pod DB).
- **세션 거부 목록**(`identity_admin`): 30초 beat가 DB 정본의 `expires_at > now()` 행을 다시 SET한다(data-model §3). targetTime 뒤의 거부 기록은 DB에서 사라지므로 beat가 다시 쓰지 않는다 — Dragonfly에 남은 그 키는 TTL까지만 유효하다 → 그 구간에 회수한 세션은 확인하고 필요하면 다시 회수한다.
- **마이그레이션**: 마이그레이션 기록 테이블도 targetTime으로 돌아간다. targetTime 뒤의 마이그레이션이 만든 객체가 dump에 없으면 그대로 남아 있어(§4-5 `--clean` 범위) 다음 migrate Job이 같은 마이그레이션을 다시 적용하다 충돌할 수 있다 → §4-7 대조 결과와 함께 판단한다(US6 뒤 실측).

## §5 절차 C — Vault Raft 스냅샷(→ vault-unseal.md §7)

Vault 스냅샷은 **age 복호화 후 복원**한다(FR-047). 복원 절차의 정본은 `vault-unseal.md` §7 「Raft 스냅샷 복원」이고 여기서 복제하지 않는다 — 이 절은 전제 체크리스트 · 공통 입구(§5-1 — §6도 쓴다) · 복원 뒤 ESO 확인 · 평문 소거만 둔다.

- **목적**: Vault 데이터(kv · 정책 · auth · 토큰 저장소)를 일 1회 스냅샷 시점으로 되살린다.
- **전제**(하나라도 아니면 멈춘다):
  - [ ] 같은 OCI KMS 키(`key_id`)가 살아 있다 — 스냅샷은 seal(KMS) 래핑이다. 키 삭제 · 분실 = 복구 불능(`vault-unseal.md` §6).
  - [ ] 대상 Vault가 같은 `ocikms` seal로 기동 · 초기화 · unseal됐다(PVC 소실 뒤면 `vault-unseal.md` §4 안전 블록 init이 먼저다).
  - [ ] 토큰: `vault operator raft snapshot restore -force`는 `sys/storage/raft/snapshot-force`(update)를 부른다 — root(T084 뒤 OIDC admin)만 된다. `vault-backup` role은 안 된다.
  - [ ] 창 C(port-forward) · 창 D(vault CLI · 창 시작 체크리스트 · 토큰은 환경변수로만 — vault-unseal §0 절대 규칙).
  - [ ] 복원 직전 현재 상태를 `snapshot save`로 떠 둔다(vault-unseal §7 4단계 — 되돌리기 §8).
  - [ ] 복원은 토큰 저장소와 kv(ESO 원천)도 스냅샷 시점으로 되감는다 → 그 뒤 회전한 값은 `secret-rotation.md` 매트릭스로 다시 넣는다(T084).
  - [ ] ⚠ **보안**: 복원 시점 이후 폐기(revoke)한 토큰 · 리스도 되살아난다 → 복원 직후 `vault list auth/token/accessors`를 복원 전 목록(또는 폐기 기록)과 대조해 불필요한 토큰을 revoke한다 — secret-rotation 매트릭스 항목(T084).
  - [ ] 운영자 복호화는 vault 줄만 — `backup-verify.ps1`은 두 암호문을 자기 작업 디렉터리에서 잠시 풀고 finally로 지운다(평문을 남기지 않는다) · k3s 복호화는 §6 ①.
- **명령**: §5-1 입구 → `vault-unseal.md` §7 3–6단계(대상 확인 → 정지점 → `snapshot save` → `restore -force` → 확인 → 산출물 소거는 별도 블록) → §5-1 끝의 「§5 소거」 블록(§5-1이 남긴 평문 · 암호문 전부).
- **기대 출력 · 다음 단계**: vault-unseal §7 5단계 판정 + 아래 ESO 회복 → §7 「Vault」 → §5 소거 → §9 기록.

### §5-1 공통 입구 — 버킷 → 무결성 → age 복호화(§5 · §6)

```powershell
# 창 B · svc-verify 세션(60분 · read objects만) — 재인증이 passphrase를 물으면 N/A(vault-unseal §7 1단계)
oci session authenticate --profile-name svc-verify
oci --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup-platform --prefix vault/ --query 'data[].{name:name,size:size}' --output table
oci --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup-platform --prefix k3s/ --query 'data[].{name:name,size:size}' --output table
#   vault/vault-<ts>.snap.age · k3s/k3s-<ts>.tar.age — 이름의 UTC ts가 시각이다. 한 번의 백업 실행이 같은 ts의 쌍을 만든다(매일 02:30 KST · SUC 업그레이드 직전)
#   보존 vault 30일 · k3s 7일(버킷 lifecycle)
$bts = '20261028T173010Z'                                # 고른 쌍의 ts(예시)
oci --profile svc-verify --auth security_token os object get --bucket-name joshuatech-backup-platform --name "vault/vault-$bts.snap.age" --file "$env:TEMP\vault-$bts.snap.age"
oci --profile svc-verify --auth security_token os object get --bucket-name joshuatech-backup-platform --name "k3s/k3s-$bts.tar.age" --file "$env:TEMP\k3s-$bts.tar.age"
```

```powershell
# 무결성(저장소 루트에서 — T048 백업 검증 · 복원 리허설이 아니다). 로컬 파일 모드는 두 파일을 함께 준다. 최신 쌍이면 -K3sAge · -VaultAge 없이 내려받기 모드
pwsh -NoProfile -File scripts\backup-verify.ps1 -AgeKeyFile '<오프라인 보관 경로>\joshuatech-age.key' -K3sAge "$env:TEMP\k3s-$bts.tar.age" -VaultAge "$env:TEMP\vault-$bts.snap.age"
#   마지막 줄 'N passed, 0 failed' — bv-k3s-4(state.db integrity_check ok) · bv-vault-3(raft snapshot inspect) PASS
```

- 복호화는 **시나리오의 컴포넌트 하나만** 한다 — Vault는 아래 블록(vault 줄 하나), K3s는 §6 ① 블록(k3s 줄 하나). 시나리오 밖 평문을 만들지 않는다(K3s 평문 tar = 서버 토큰 · TLS 개인키 · cred). 무결성 검사(`backup-verify.ps1`)는 두 암호문을 받으므로 내려받기는 위처럼 둘 다 한다.

```powershell
# §5 Vault 복호화(Vault 시나리오만 — age 개인키는 오프라인 보관 경로에서 직접 읽는다 · 복사하지 않는다 · 경로를 기록하지 않는다)
age -d -i '<오프라인 보관 경로>\joshuatech-age.key' -o "$env:TEMP\vault-$bts.snap" "$env:TEMP\vault-$bts.snap.age"   # vault-unseal §7 2단계와 같다
```

```powershell
# 복원 뒤 ESO 회복(agent-view 가능)
kubectl get clustersecretstore
#   5개 READY True — 아니면 vault-unseal §7 5단계(토큰 · auth 경로)부터
kubectl get externalsecret -A -o 'custom-columns=NS:.metadata.namespace,N:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason'
#   전부 True SecretSynced(갱신 주기 5분 — 복원 뒤 한 주기 안)
```

```powershell
# §5 소거(운영자 · Vault 시나리오 — §7 「Vault」 V1–V3 통과 뒤 · 별도 블록). vault-pre-restore.snap(되돌리기 재료)은 vault-unseal §7 6단계가 다룬다
if (-not $bts) { throw '$bts 비었음 — §5-1 값으로' }
if ((Read-Host '§7 Vault(V1–V3) 통과? 워크스테이션 TEMP의 이 백업 쌍 파일 전부(vault · k3s 평문 · 암호문) 소거 yes') -ne 'yes') { throw 'NOT REMOVED — 평문(비밀)이 남아 있을 수 있다 · 판단 뒤 이 블록을 다시' }
Remove-Item "$env:TEMP\vault-$bts.snap", "$env:TEMP\vault-$bts.snap.age", "$env:TEMP\k3s-$bts.tar", "$env:TEMP\k3s-$bts.tar.age" -Force -ErrorAction SilentlyContinue
foreach ($p in @("$env:TEMP\vault-$bts.snap", "$env:TEMP\vault-$bts.snap.age", "$env:TEMP\k3s-$bts.tar", "$env:TEMP\k3s-$bts.tar.age")) { if (Test-Path $p) { throw "NOT REMOVED — $p 가 남아 있다(다른 창이 쓰고 있는가) · 그 창을 닫고 이 블록을 다시" } }; 'REMOVED 4/4'
#   REMOVED 4/4
```

## §6 절차 D — K3s 번들(age 복호화 → 복원 · `--cluster-reset` 금지)

K3s 번들은 **age 복호화 후 복원**한다(FR-041 · FR-047). 정본은 `bootstrap.md` §7 「K3s 번들 복원」(T114가 작성 — 지금은 자리표시자)과 `rollback.md`(T106이 작성 — 아직 없다)이고, 그때까지 이 절이 FR-041의 순서를 안내한다. **`k3s server --cluster-reset`은 실행 금지**다 — 이 클러스터는 SQLite(kine) 데이터스토어이고 그 명령은 embedded etcd 전용이라 실행하면 etcd로 비가역 전환된다(FR-041).

- **목적**: 노드 A의 K3s 데이터스토어(`server/db/state.db`)와 서버 신원(`server/token` · `server/cred/` · `server/tls/`)을 번들 시점으로 되돌린다 — 노드 A 디스크 손실 · 데이터스토어 손상 · 롤백.
- **전제**:
  - 번들 레이아웃은 `infra/bootstrap/platform-backup.sh` 머리 주석 「번들 레이아웃」대로 `server/` 접두 그대로다(`server/db/state.db` · `server/token` · `server/cred/` · `server/tls/` — T048 실측 항목 67 = `state.db` 1 · `token` 1 · `cred` 10 · `tls` 47) → 경로 이동 없이 `tar -C /var/lib/rancher/k3s -xf` 한 번이다. `server/token` · `server/tls/`를 함께 되돌려야 서버 인증서 · SA 서명 키가 같아 노드 B가 재조인한다(FR-047).
  - **계획 다운타임**: 단일 서버라 정지 → 기동 동안 API · 스케줄링 · 조정이 멈춘다. 파드는 계속 돌 수 있다(`k3s.service` 정지에도 containerd-shim이 살아남았다 — `bootstrap.md` §6 2026-10-04 실행 기록). 소요 미실측.
  - 데이터스토어를 되돌리면 git에 없는 클러스터 객체(operator가 만든 Secret · CR status · 수동 객체)도 번들 시점으로 돌아간다. Argo가 git으로 다시 맞추지만 PVC 안의 상태(CNPG · Vault)는 되돌아가지 않는다 → §7 「K3s」로 정합을 보고, 어긋나면 `rollback.md`(T106) · `incident-response.md`(T114).
  - 평문 번들은 비밀이다(서버 토큰 · TLS 개인키 · 암호화 설정) — 워크스테이션 `$env:TEMP`와 노드 `/root`(0600)에만 두고 ⑩에서 소거한다(별도 블록).
- **다음 단계**: §7 「K3s」 → ⑩ 소거 → §9 기록.

**① 번들 선택 · 무결성 · 복호화** — §5-1 입구(`k3s/` 접두). 노드 A가 살아 있고 데이터스토어가 읽힌다면 먼저 지금 상태의 번들을 하나 더 올린다(되돌리기 §8 — 멱등 · 새 ts의 객체가 하나 더 생길 뿐): `ssh ssh-a "sudo /usr/local/bin/platform-backup.sh --components k3s"`. 번들 시점의 K3s 버전도 여기서 정한다 — 번들 ts를 `bootstrap.md` §6 업그레이드 실행 기록과 대조한다(예: 2026-10-04 03:01 KST 전 번들 = `v1.36.4+k3s1`, 뒤 = `v1.36.5+k3s1` — SUC가 채널 `v1.36`로 올린다). 지금 버전은 `kubectl get nodes -o wide`의 VERSION 또는 `ssh ssh-a "k3s --version"`.

```powershell
# ① K3s 복호화(K3s 시나리오만 — §5-1의 내려받기 · 무결성 뒤). 평문 tar = 서버 토큰 · TLS 개인키 · cred(비밀) — ⑩에서 소거한다
age -d -i '<오프라인 보관 경로>\joshuatech-age.key' -o "$env:TEMP\k3s-$bts.tar" "$env:TEMP\k3s-$bts.tar.age"
```

**② 노드 A로 반입**(0600):

```powershell
scp "$env:TEMP\k3s-$bts.tar" "ssh-a:/home/ubuntu/k3s-$bts.tar"
ssh ssh-a "sudo install -m 600 -o root -g root /home/ubuntu/k3s-$bts.tar /root/k3s-$bts.tar && shred -u /home/ubuntu/k3s-$bts.tar && sudo tar -tf /root/k3s-$bts.tar | head -n 5"
#   server/… 로 시작하는 이름만 보인다(내용은 출력하지 않는다)
```

**③ 같은 K3s 버전 핀 재설치**(노드 A가 새 디스크이거나 버전이 다를 때만 — 같으면 건너뛴다): `infra/bootstrap/k3s-server.sh`를 `K3S_VERSION=<번들 시점 버전>`으로 돌린다(스크립트가 설치 스크립트에 `INSTALL_K3S_VERSION`으로 넘긴다 — `bootstrap.md` §3 T035). 이 스크립트는 **다른 버전이 이미 설치돼 있으면 중단**한다(머리 주석) — 같은 노드의 다운그레이드 절차는 `rollback.md`(T106)가 정한다(미정). 번들 시점 버전이 채널보다 낮으면 다음 창(일요일 03:00 KST)에 SUC가 다시 올린다(`bootstrap.md` §6).

- 노드 A가 **새 디스크**면 먼저 `bootstrap.md` §2 host-prep → `k3s-server.sh` 머리 주석 절차 1–3(서버 토큰 파일 `/etc/rancher/k3s/token` root 0600 · 검토한 설치 스크립트 사본 `/tmp/install-k3s.sh` — `K3S_TOKEN_FILE` · `INSTALL_SCRIPT` 기본 경로 · `bootstrap.md` §3 T035 사전 준비) — 그 뒤 `sudo K3S_VERSION=<번들 시점 버전> bash k3s-server.sh`. fresh install이 만든 노드 A `agent/` 인증서와 복원한 `server/tls` CA의 불일치(agent 재등록 필요 여부)는 미확인 — T114(bootstrap §7) 인계.
- 단 절차 1의 토큰은 **새로 만들지 않는다** — 비밀번호 관리자의 원래 서버 토큰(짧은 형식 · T035)을 둔다. config의 `token-file`이 번들의 `server/token`과 같은 값이어야 복원한 데이터스토어를 쓸 수 있다(K3s 문서 「Backup and Restore」: 토큰이 데이터스토어 안의 기밀 데이터를 암호화하므로 같은 토큰 값이 아니면 스냅샷을 쓸 수 없다 · 라이브 미실측 — VD-15). ④–⑦이 `server/token`을 번들 값으로 덮어써도 config의 `token-file`은 그대로다.

**④–⑦ 정지 → 전개 → 잔재 제거 → 기동**(노드 A · 운영자 · 정지점) — `ssh ssh-a`로 들어가 아래 블록을 그대로 붙여 넣는다. `{ … }` 한 덩어리라 bash가 블록 전체를 읽은 뒤에 `read`가 입력을 기다린다 — `yes`를 직접 입력하기 전에는 아무것도 바뀌지 않는다. 정지가 확인되지 않으면 전개하지 않고, 앞 단계가 실패하면 뒤 단계로 가지 않는다.

```bash
{
  BTS=20261028T173010Z      # §5-1의 $bts와 같은 값으로 바꾼다
  read -r -p "노드 A: k3s 정지 → /root/k3s-$BTS.tar 전개 → state.db-wal · -shm 제거 → 기동(API 불통 시작). yes 입력: " ans
  if [ "$ans" = yes ]; then
    if sudo systemctl stop k3s && ! systemctl is-active --quiet k3s; then     # ④ 정지 — inactive일 때만 다음으로
      sudo tar -C /var/lib/rancher/k3s -xf "/root/k3s-$BTS.tar" &&            # ⑤ 전개 — 번들은 server/ 접두 그대로(경로 이동 없음)
        sudo rm -f /var/lib/rancher/k3s/server/db/state.db-wal /var/lib/rancher/k3s/server/db/state.db-shm &&   # ⑥ 옛 DB의 WAL 잔재 제거(FR-041)
        sudo systemctl start k3s &&                                            # ⑦ 기동
        systemctl is-active k3s                                                #    active
    else
      echo 'k3s가 멈추지 않았다 — 전개하지 않았다'
    fi
  else
    echo '중단 — 아무것도 바꾸지 않았다'
  fi
}
```

- ⑥의 이유: 남은 `state.db-wal` · `state.db-shm`은 옛 DB의 것이다 — 두면 SQLite가 그 WAL을 복원한 `state.db`에 적용하려 한다(FR-041이 제거를 요구한다).

**⑧ 노드 B 재조인 · ⑨ 플랫폼 기동 확인**:

```powershell
# 확인(agent-view 가능 — 안 되면 운영자 admin kubeconfig)
kubectl get nodes -L role -o wide
#   ⑧ 두 노드 Ready · role platform/data · 같은 VERSION — 같은 server/token · server/tls/라 노드 B는 손대지 않아도 다시 붙는다
kubectl -n argocd get applications -o 'custom-columns=N:.metadata.name,S:.status.sync.status,H:.status.health.status'
#   ⑨ 전부 Synced Healthy — 재조정에 수 분(T048 재부팅 실측: 전부 Healthy 78초 · 전부 재조정 6분 9초)
kubectl get clustersecretstore
#   5개 READY True(Vault가 먼저 unseal돼야 한다 — 아래)
# Vault: 창 C에서 kubectl -n vault port-forward svc/vault 18200:8200(agent-view 가능 — ns vault portforward 허용) → 다른 창에서
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status
#   "sealed":false · "type":"ocikms" — 확인 순서는 T048 재부팅 순서(Vault unseal → ClusterSecretStore → Application → ExternalSecret 갱신)
```

- 노드 B가 NotReady로 남으면 `ssh ssh-b "sudo systemctl status k3s-agent --no-pager"`와 그 로그부터 본다 — 조치는 `rollback.md`(T106).

**⑩ 평문 소거**(운영자 · §7 「K3s」 통과 뒤 · 별도 블록 — 통째 실행으로 되돌리기 재료가 먼저 지워지지 않게: vault-unseal §7 6단계 선례 · 정지점 모양은 §0 규칙 5). 워크스테이션 TEMP에 있는 이 백업 쌍의 파일 **전부**(k3s · vault 평문 · 암호문)와 노드 A의 평문 번들을 지운다:

```powershell
if (-not $bts) { throw '$bts 비었음 — §5-1 값으로' }
if ((Read-Host '§7 K3s(K1–K4) 통과? 평문 소거(워크스테이션 TEMP의 이 백업 쌍 파일 전부 + 노드 A /root 번들) yes') -ne 'yes') { throw 'NOT REMOVED — 평문 번들(비밀)이 남아 있다 · 판단 뒤 이 블록을 다시' }
Remove-Item "$env:TEMP\k3s-$bts.tar", "$env:TEMP\k3s-$bts.tar.age", "$env:TEMP\vault-$bts.snap", "$env:TEMP\vault-$bts.snap.age" -Force -ErrorAction SilentlyContinue
ssh ssh-a "sudo shred -u /root/k3s-$bts.tar"
foreach ($p in @("$env:TEMP\k3s-$bts.tar", "$env:TEMP\k3s-$bts.tar.age", "$env:TEMP\vault-$bts.snap", "$env:TEMP\vault-$bts.snap.age")) { if (Test-Path $p) { throw "NOT REMOVED — $p 가 남아 있다(다른 창이 쓰고 있는가) · 그 창을 닫고 이 블록을 다시" } }; 'REMOVED 4/4'
#   REMOVED 4/4 — 노드 A의 shred는 오류 없이 끝난다
```

## §7 검증 체크리스트

- **목적**: 시나리오별로 "끝났다"를 판정한다 — 명령 · 기대값 · 누가 볼 수 있는가.
- **전제**: 해당 절차를 마쳤다.
- **다음 단계**: 전부 통과면 §9에 한 행 · `bootstrap.md` §3에 실행 기록. 하나라도 아니면 해당 절의 멈춤 분기 또는 §8.

**전체 PITR(§3)** — 순서: P1 → **P8(5-a) · P6(5-b)를 먼저** → 나머지.

| # | 확인 | 명령 | 기대 | agent-view |
|---|---|---|---|---|
| P1 | 상태 | `kubectl -n data get cluster pg-main -o jsonpath='{.status.phase} {.status.readyInstances}'` | `Cluster in healthy state 1` | 가능 |
| P2 | 복구 spec · 세대 | `kubectl -n data get cluster pg-main -o jsonpath='{.spec.bootstrap.recovery.source} {.spec.plugins[0].parameters.serverName}'` | `origin pg-main-r<N>` | 가능 |
| P3 | WAL 아카이브 | `kubectl -n data get cluster pg-main -o jsonpath='{.status.conditions[?(@.type=="ContinuousArchiving")].status}'` | `True` | 가능 |
| P4 | DB 목록 | `kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- psql -X -tAc "SELECT datname FROM pg_database ORDER BY 1"` | `platform` + pod/공유 DB 4 + 시스템 DB 3 · `app` 없음 | 운영자 |
| P5 | CR 재조정 | §3-1 5-c의 `database` · `databaserole` 목록 | `applied` true × 4 · × 6 | 가능 |
| P6 | 비밀번호 재적용 · 로그인 | §3-1 5-b 확인 블록 · PostSync Job 로그(US6 뒤는 소비자 `/ready`) | 6행 `APPLIED` true · GEN = OBS · `SUMMARY: pass=6 fail=0` — P1 직후(5-b) | 가능(Job 로그) |
| P7 | 새 접두 | §3-1 5-c의 `oci … --prefix pg-main/pg-main-r<N>/` | `wals/` ≥ 1(활동 뒤 ≤ 5분) · 5-a 뒤 `base/` ≥ 1 | svc-verify |
| P8 | 첫 복구 지점(5단계 첫 항목) | `kubectl -n data get backup $bk -o jsonpath='{.status.phase} {.status.backupId}'`(`$bk` = §3-1 5-a에서 정한 이름) | `completed <backupId>` — P1 직후 가장 먼저(5-a) | 가능 |
| P9 | CA 재생성 | `kubectl --kubeconfig <admin kubeconfig> -n data get secret pg-main-ca -o jsonpath='{.metadata.creationTimestamp}'` | 복구 시각 뒤(값은 출력하지 않는다) | 운영자 |
| P10 | Argo | `kubectl -n argocd get app platform-cnpg-cluster -o jsonpath='{.status.sync.status} {.status.health.status}'` | `Synced Healthy` | 가능 |
| P11 | 복구 지점 표시 | `kubectl -n data get cluster pg-main -o jsonpath='{.status.firstRecoverabilityPoint}'` | 기록만(플러그인 경로 빈 값 — VD-9) | 가능 |

**단일 DB(§4)**

| # | 확인 | 명령 | 기대 | agent-view |
|---|---|---|---|---|
| S1 | side 복구 · 승격 | §4-2 확인 블록 | `Cluster in healthy state` · `pg_is_in_recovery()` = `f` | 가능 · 운영자 |
| S2 | 복원 | §4-5 `exit=$LASTEXITCODE` | `exit=0` | 운영자 |
| S3 | 행 수 | §4-7 대조 | `True`(차이 줄은 설명된 것만) | 운영자 |
| S4 | CONNECT | §4-6 `datacl` | §4-4 판정 값과 같다 | 운영자 |
| S5 | 접속 복귀 | §4-7 `pg_stat_activity` · 소비자 `/ready` | 소비자 세션이 다시 보인다 | 운영자 |
| S6 | 정리 | `kubectl -n data get cluster,pvc` | side Cluster · `<side>-1` PVC 없음 | 가능 |

**Vault(§5)**

| # | 확인 | 명령 | 기대 | agent-view |
|---|---|---|---|---|
| V1 | seal | `curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status`(창 C port-forward) | `sealed` false · `type` ocikms | 가능(ns `vault` portforward 허용) |
| V2 | 내용 | `vault secrets list` · `vault auth list` · `vault policy list` | 스냅샷 시점과 같다 | 운영자(root · OIDC admin) |
| V3 | ESO | §5-1의 「복원 뒤 ESO 회복」 블록 | 전부 `SecretSynced` | 가능 |
| V4 | 평문 소거 | §5-1의 「§5 소거」 블록 | `REMOVED 4/4` | 운영자 |

**K3s(§6)**

| # | 확인 | 명령 | 기대 | agent-view |
|---|---|---|---|---|
| K1 | 노드 | `kubectl get nodes -L role -o wide` | 두 노드 Ready · 같은 버전 | 가능 |
| K2 | Argo | `kubectl -n argocd get applications` | 전부 Synced Healthy | 가능 |
| K3 | Vault · ESO | V1 · V3 | 같다 | 가능 |
| K4 | CNPG | P1 · P3 | 같다(PVC 안의 데이터는 되감기지 않는다) | 가능 |
| K5 | 평문 소거 | §6 ⑩ | 워크스테이션 `REMOVED 4/4` · 노드 A `shred` 오류 없음 | 운영자 |

**하네스**(agent-view · svc-verify 세션 · 한 번에 하나만 — 동시 실행은 거짓 FAIL):

```powershell
pwsh -NoProfile -File tests/platform/data.tests.ps1      # 2026-10-29 실측 13 PASS / 2 FAIL / 1 SKIP — FAIL = job-1 · job-2(검사 Job jt-dev/data-assert 없음 — T059가 배포하면 PASS)
pwsh -NoProfile -File tests/platform/kafka.tests.ps1     # 2026-10-29 실측 12 PASS / 5 FAIL / 0 SKIP — FAIL = job-k-1–3 · job-d-1–2(검사 Job jt-dev/kafka-assert · data-assert 없음)
pwsh -NoProfile -File tests/platform/cluster.tests.ps1   # 2026-10-29 실측 43 PASS / 0 FAIL / 11 SKIP(svc-verify 세션이 유효할 때)
#   기준선 = 2026-10-29 라이브 실측(컨트롤러 · agent-view + svc-verify 세션 갱신 뒤 — 증거 .superpowers/t058/evidence/의
#   cluster-tests-2026-10-29T044257Z-rerun.log · data-tests-2026-10-29T044257Z-rerun.log · kafka-tests-2026-10-29T043813Z.log)
#   전체 PITR 뒤에는 data.tests.ps1의 $serverName을 새 세대로 바꾸기 전까지 bucket-1 · bucket-2 FAIL이 정상이다(§3-1 6단계 3)
#   §3-1 6단계 2(옛 세대 Backup CR 삭제) 전에는 backup-2가 옛 세대 completed로 PASS할 수 있다(거짓 안심)
```

- 과제 문면의 「T050 · T051 PASS」는 위 두 하네스(`data.tests.ps1` = T050 · `kafka.tests.ps1` = T051)가 기준선대로 도는 것이다 — T058 라이브 판정은 컨트롤러가 `bootstrap.md` §3과 §9에 기록한다.

## §8 되돌리기

- **목적**: 각 절차를 실행한 뒤 결과가 틀렸을 때 돌아가는 길. 되돌릴 재료(덤프 · 스냅샷 · 번들 · 직전 세대 접두)는 소거 블록 전까지 남겨 둔다.
- **전제**: 되돌리기도 같은 정지점 규칙(§0 규칙 5)을 따른다.

| 절차 | 되돌리기 | 비고 |
|---|---|---|
| §1 backup-list Job | `kubectl --kubeconfig <admin kubeconfig> -n data delete job pg-main-backup-list` | 데이터 변화 없음 |
| §1-4 수동 Backup | 되돌리지 않는다 — 보존 만료 뒤 사이드카가 정리한다(같은 Cluster UID의 것만 — 전체 PITR 전 것은 §3-1 6단계 2에서 수동) | 버킷의 백업 = 복구 지점 |
| §3-1 2-c hibernation | 4-b 삭제 **전에만** 의미가 있다: `kubectl --kubeconfig <admin kubeconfig> -n data annotate cluster pg-main --overwrite cnpg.io/hibernation=off` → operator가 파드를 다시 만들고 PVC 그대로 다시 돈다(CNPG 1.30 문서 「Declarative hibernation」 Rehydration). 3단계 PR이 이미 머지됐다면 **먼저** 그 PR을 revert 머지해 serverName을 직전 세대로 되돌린 뒤 off — 아니면 깨어난 옛 클러스터가 새 세대 접두에 WAL을 쓴다 | 4-b 삭제 뒤에는 되돌릴 옛 PVC가 없다 |
| §3-1 경로 A | **제자리로 되돌릴 옛 데이터는 없다** — Cluster 삭제 = 옛 PVC 삭제. PV Retain 디렉터리는 포렌식 전용이지 되돌리기 경로가 아니다(VD-11). 다른 시점이 필요하면 §3-1을 다시 한다: 원천 = 원하는 세대 접두(직전 세대 접두는 30일 동안 남는다 · 2-b′ 수동 Backup이 "PITR 직전" 지점) · 새 세대 `r<N+1>`. 그 사이 새 클러스터에 쓴 데이터는 잃는다. **승격 ~ 첫 `pg-main-r<N>` Backup completed 사이의 쓰기는 두 번째 장애 때 복구 불능**(r<N> 접두에 base 없음 — 5-a가 그 창을 닫는다) | 직전 세대 접두를 30일 전에 지우지 않는다 |
| §3-2 경로 B | 참조 교체 PR을 역순으로 revert → 복구본 Cluster 삭제 | 옛 클러스터가 살아 있는 동안만 |
| §4 단일 DB | §4-3 pre-restore dump로 같은 절차를 거꾸로 — §4-4 쓰기 정지 → 아래 블록 → §4-6 GRANT · ANALYZE → §4-7 | 덤프는 §4-8 소거 전까지만 |
| §4 side Cluster | `kubectl --kubeconfig <admin kubeconfig> -n data delete cluster <side>` | PVC 함께 삭제 |
| §5 Vault | `vault-unseal.md` §7 되돌리기 — 4단계에서 떠 둔 `vault-pre-restore.snap`을 같은 명령으로 복원 | 토큰도 그 시점으로 |
| §6 K3s | 복원 전 번들(§6 ①에서 올린 최신 `.age` — 없으면 그다음 최신)로 §6을 같은 순서로 | `--cluster-reset` 금지는 그대로 |

```powershell
# §4 되돌리기(운영자) — §4-4 쓰기 정지(REVOKE · 세션 종료)를 다시 한 뒤에만. 파드 안 파일에서 복원(파이프 없음)
if (-not ($db -and $owner -and $pre -and $preHash)) { throw '§4-0 · §4-3 기록 값으로 $db · $owner · $pre · $preHash를 다시 정한다' }
$h = ((kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- sha256sum $pre) -split '\s+')[0]
if (-not [string]::Equals($h, $preHash, [StringComparison]::Ordinal)) { throw "pre-restore dump의 sha256이 §4-3 기록과 다르다('$h') — 되돌리지 않는다" }
if ((Read-Host "되돌리기: $db 를 pre-restore dump($pre · sha256 일치)로 교체 yes") -ne 'yes') { throw '중단' }
kubectl --kubeconfig <admin kubeconfig> -n data exec pg-main-1 -c postgres -- pg_restore -U postgres -d $db --clean --if-exists --no-owner --role=$owner --single-transaction --exit-on-error $pre
"exit=$LASTEXITCODE"
#   exit=0 → §4-6(GRANT · ANALYZE) → §4-7
```

- **다음 단계**: 되돌린 뒤 §7의 같은 시나리오 행을 다시 본다.

## §9 드릴·실측 기록

- **목적**: 이 런북을 실제로 쓴 기록(드릴 · 사고)과 실측값의 자리다. 상세 실행 기록의 정본은 `bootstrap.md` §3이고 여기는 한 행 요약이다.
- **전제**: 실행이 끝났다. 소요는 실측값만 적는다.

| 날짜 | 시나리오 | 수행자 | 소요 | 결과 | 증거 경로 |
|---|---|---|---|---|---|
| 2026-10-29 | §1-1 backup-list Job(복원 없음 · VD-12 · VD-8) | 운영자(apply · delete) + 컨트롤러(agent-view 관찰) | 3초(05:36:11→14Z) | PASS — 17행 · Begin Wal = Backup CR endWal · End Time UTC · 자격 0 · Argo 경고 4 → 2 | `.superpowers/t058/evidence/backup-list-job-*2026-10-29.*` · `bucket-objects-2026-10-29.json` · 하네스 로그 `{cluster,data}-tests-2026-10-29T044257Z-rerun.log` |

- 복원 실연(§3 · §4 · §5 · §6) 행은 **SP-3**에서 채운다 — SC-011 수용 위험(`report.md`). 그때 §10의 VD를 닫는다.
- **다음 단계**: 새 행을 쓸 때 §10의 해당 VD 판정을 같이 갱신한다.

## §10 VD(검증 후 결정 — 미실측)

- **목적**: 소스 · 문서 판독으로 쓴 단정 가운데 라이브로 확인하지 않은 것의 목록. 절차 안의 「VD-n」 표시가 여기를 가리킨다.
- **전제**: 닫는 곳은 SP-3 복구 드릴(SC-011)이다 — VD-8 · VD-12만 T058 라이브(§1 Job)에서 관찰할 수 있다.

| ID | 질문 | 근거(소스) | 닫는 곳 |
|---|---|---|---|
| VD-1 | 라이브 Cluster의 `bootstrap.initdb` → `recovery` 변경을 webhook이 받는가(서버 사이드 적용 병합 뒤 initdb 잔재 → `Only one bootstrap method` 거부 여부 — 거부면 사유로 가른다: §3-1 3단계 VD-1 분기 ⓐ/ⓑ · 4-a 서버 dry-run) | `cluster_webhook.go` v1.30.0 — `ValidateUpdate` = `validate(new)` + `validateClusterChanges`(bootstrap 없음) · `ValidateCreate` = 같은 `validate` | SP-3 |
| VD-2 | 삭제 뒤 selfHeal 재생성이 recovery spec으로 가는가 · 걸린 시간 · Failed 경로 · 수동 Sync 필요 여부 | gitops README §5 · Application syncPolicy(selfHeal · ApplyOutOfSyncOnly · retry) | SP-3 |
| VD-3 | 복구 Job(`<cluster>-1-full-recovery`)의 컨테이너 이름 · 자원(side 100m) · 소요(RTO) · 인스턴스 파드의 사이드카 주입 여부 · 실패 문구 | plugin v0.14.0 `lifecycle.go` | SP-3 |
| VD-4 | `pg_dump -U postgres` 파드 안 peer 접속(side · 운영) | CNPG pg_hba `local all all peer map=local` | SP-3 |
| VD-5 | 파드 → 워크스테이션 → 파드 파이프의 바이트 보존(sha256 대조) | pwsh 7.6.9 실측(build-notes 「T058」 사실 7) | SP-3 |
| VD-6 | Database · DatabaseRole CR이 Cluster 삭제를 견디는가(ownerReference 없음 — 소스 판독) · 5-b 재적용 소요(PR 경로 · Secret 삭제 경로) · PR 경로(generation bump)가 실제로 `ALTER ROLE … PASSWORD`를 다시 내는가(= P6 `pass=6`) | CNPG v1.30.0 `database_controller.go`(ownerReference 설정 없음 · finalizer) · `databaserole_controller.go` `isAlreadyReconciled`(재적용 조건 — 저절로 재적용되지 않으므로 5-b가 강제한다 · build-notes 「T058」 D5 ② 정정) | SP-3 |
| VD-7 | `pg-main-ca` 교체 전파(CA 미러 5분) · 소비자 영향 | T056 CA 미러 ExternalSecret | SP-3(US6 뒤) |
| VD-8 | Argo `OrphanedResourceWarning`의 모양(어느 Application · 문구) | AppProject `platform` `orphanedResources.warn: true` | T058 라이브 일부 닫힘: 문구 `OrphanedResourceWarning: Application has N orphaned resources`(Application `platform-cnpg-cluster` · Job+파드 동안 4 → 삭제 뒤 2) · side Cluster 모양은 SP-3 |
| VD-9 | 복구 뒤 `status.firstRecoverabilityPoint` | T053: 플러그인 경로 빈 값 | SP-3 |
| VD-10 | side Cluster 삭제 뒤 PVC · PV 정리(reclaim Delete) | local-path 기본 동작 | SP-3 |
| VD-11 | 재이미지 뒤 local-path PV · PVC의 모습(객체는 Bound로 남고 디렉터리는 비어 파드가 CrashLoop — 소스 판독) · PV Retain 데이터 디렉터리의 재사용 가능성과 디렉터리 이름 — 포렌식 전용으로 둔다 | local-path(hostPath `DirectoryOrCreate` + nodeAffinity) | SP-3(또는 첫 재이미지) |
| VD-12 | backup-list Job 실행 시간 · 출력 모양 · End Time 시간대 | barman 3.19.1 `cloud_backup_list.py` | **닫힘 2026-10-29**(3초 · console 5열 · UTC · 17행) |
| VD-13 | 2-c hibernation 뒤 새 접두에 WAL 0인가 · Argo selfHeal이 kubectl로 단 `cnpg.io/hibernation` 어노테이션을 되돌리지 않는가(desired에 없는 live 키는 diff 대상이 아니다 — 라이브 미실측) · 그래도 `Expected empty archive`로 멈추면 다음 세대로 3–4단계 재실행 | plugin v0.14.0 `config.go` `NewFromCluster`(serverName은 호출 때의 Cluster spec) · CNPG v1.30.0 `pkg/reconciler/hibernation` | SP-3 |
| VD-14 | 재이미지한 노드 B의 같은 이름 재조인 — `kube-system/<노드 B 이름>.node-password.k3s` Secret 삭제(1순위)로 충분한가 · Node 객체 삭제(2순위)가 필요한 경우 · 거부 문구(`Node password rejected, duplicate hostname`) | K3s 문서 「Architecture」 Node-password secrets(같은 비밀번호 요구 · Node 삭제 권고) · 거부 문구 `Node password rejected, duplicate hostname`은 k3s 서버 로그 메시지(소스) | SP-3(또는 첫 재이미지) |
| VD-15 | 새 디스크 노드 A의 번들 복원 — config `token-file`에 원래 서버 토큰을 둬야 복원한 데이터스토어로 기동하는가(다른 토큰이면 기동 실패) · fresh install이 만든 노드 A `agent/` 인증서와 복원한 `server/tls` CA의 불일치(agent 재등록 필요 여부)는 미확인 — T114(bootstrap §7) 인계 | K3s 문서 「Backup and Restore」(토큰이 데이터스토어의 기밀 데이터를 암호화) · `k3s-server.sh` config `token-file` | SP-3 · T114 |

- **다음 단계**: 닫은 VD는 판정과 날짜를 이 표에 적고, 절차 문장을 실측에 맞게 고친다.

## §11 관련 문서

- **목적**: 이 런북이 기대는 정본과 선례의 위치.

| 문서 | 내용 |
|---|---|
| `docs/runbooks/bootstrap.md` §2 | 노드 B 재이미지 선행 조건 · host-prep · 재조인 |
| `docs/runbooks/bootstrap.md` §3 T048 · T053 | 백업 검증 13항목(`scripts/backup-verify.ps1`) · 첫 백업 · 오브젝트 배치 · WAL 유휴 특성 · 실행 기록의 정본(T058 기록도 §3) |
| `docs/runbooks/bootstrap.md` §4 T056 「늦은 시드」 | 운영자 전체 수동 Sync 방법(4단계) |
| `docs/runbooks/bootstrap.md` §6 · §7 | 업그레이드 창 · K3s 버전 이력 · 롤백 불가(SUC) / K3s 번들 복원 정본(T114 작성 예정) |
| `docs/runbooks/vault-unseal.md` §0 · §7 | 절대 규칙 · 창 A–D · 비밀이 새는 6곳 / Raft 스냅샷 복원 · 되돌리기 |
| `docs/runbooks/rollback.md`(T106 예정) · `incident-response.md`(T114 예정) · `secret-rotation.md`(T084 예정) | K3s 롤백 · 사고 대응 · 복원 뒤 재투입 매트릭스 |
| gitops `platform/cnpg-cluster/README.md` §1 · §2 · §5 · §6 | 증상표 · 확인 명령 · 위험 · 되돌리기 순서 · T058 인계 |
| gitops `platform/cnpg-databases/README.md` · `job-postsync-db-access.yaml` | Database · DatabaseRole · DROP 경로 · PostSync Job ⓪①②(CONNECT · 세션 기본값) |
| gitops `clusters/oci-k3s/apps/platform-cnpg-cluster.yaml` | selfHeal · `ApplyOutOfSyncOnly` · retry(전체 PITR의 Argo 동작 근거) |
| gitops `platform/policies/rbac-agent-view.yaml` | agent-view 권한 범위 |
| `infra/bootstrap/platform-backup.sh` · `infra/bootstrap/k3s-server.sh` | 번들 레이아웃 · 복원 순서 · Vault 스냅샷 경로 / K3s 버전 핀 설치 |
| `scripts/backup-verify.ps1` | 백업 무결성 검증(복원 리허설 아님) |
| `specs/003-platform-foundation/contracts/gitops-repo.md` §삭제 보호 · `contracts/events.md` | 삭제 보호 목록 · outbox 멱등(:26) · 보존과 재투영(:7) |
| `specs/003-platform-foundation/research.md` CNPG-D8 · `design/build-notes.md` 「T058」 | 복구 클러스터 원안 · 이 런북의 사실 1–8과 결정 D1–D14 |
| CloudNativePG 1.30 「Recovery」(https://cloudnative-pg.io/docs/1.30/recovery/) | in-place 없음 · serverName 고유 · 빈 아카이브 검사 · `skipEmptyWalArchiveCheck` 경고 · 시간대 명시 |
| plugin-barman-cloud 「Usage」(https://cloudnative-pg.io/plugin-barman-cloud/docs/usage/) | 플러그인 복구 · 복구 설정만으로는 아카이브가 켜지지 않는다 |
| CloudNativePG 1.30 「Declarative hibernation」(https://cloudnative-pg.io/docs/1.30/declarative_hibernation/) | §3-1 2-c 아카이브 정지(파드 삭제 · PVC 유지) · Rehydration(§8 되돌리기) |
| K3s 문서 「Backup and Restore」(https://docs.k3s.io/datastore/backup-restore) · 「Architecture」 Node-password secrets(https://docs.k3s.io/architecture) | 복원 때 같은 토큰 값(VD-15) · 같은 이름 재조인(VD-14) |
| PostgreSQL 18 `pg_dump` · `pg_restore` 문서 | `--exclude-extension` · `--no-statistics` 기본 · `--single-transaction`(exit-on-error 함의 · `-j` 배타) |
