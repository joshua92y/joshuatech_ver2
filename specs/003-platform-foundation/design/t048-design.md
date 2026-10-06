# T048 설계 — 재부팅 리허설 · 백업 복원 가능성 검증 · SC-001 시각 기록

> 과제 수준 설계 문서(내부 작업 자료 — 과제를 닫은 뒤에는 고치지 않는다). 공개용 요약은 `content/tmp/003-t048/`.

## 1. 과제가 요구하는 것

1. 노드 A(K3s server · `role=platform`)를 재부팅하고 `tests/platform/reboot.tests.ps1 -AfterReboot`가 PASS한다 — Vault 자동 unseal · ESO ClusterSecretStore 5개 Ready · Argo Application 전부 Healthy · ExternalSecret이 다음 refresh에 `SecretSynced`(US2 AC4).
2. 최신 백업 `.age` 둘(`k3s/` 1 · `vault/` 1)을 내려받아 운영자 개인키로 복호화하고 무결성을 확인한다 — K3s는 `PRAGMA integrity_check` → `ok`, Vault는 `vault operator raft snapshot inspect` → 메타데이터. 두 출력과 실행 시각을 런북에 남긴다. **복원 리허설이 아니다**(Vault 스냅샷은 seal 래핑이라 복원에는 같은 KMS 키가 필요하다 — 복원 절차는 T114 · vault-unseal.md §7).
3. root app apply 시각과 전 Application Healthy 시각을 기록한다(SC-001 ≤ 30분의 근거 — T049 E2E가 인용).
4. `docs/runbooks/bootstrap.md` §3을 확정한다(전체 순서 · 시간 · 시크릿 취급).

누가 하는가: 재부팅 · SSH · 개인키를 쓰는 복호화 · OCI 세션 인증은 **운영자**. 에이전트는 조회 전용 자격(`agent-view` · `svc-verify`)으로 관찰과 하네스 실행, 블록 준비, 기록을 한다. 재부팅은 라이브 변경이므로 **단계마다 사용자 재확인**을 받는다.

## 2. 조사로 확정한 사실(2026-10-01)

- **F1 재부팅 리허설은 처음이다.** 노드 A의 마지막 부팅은 2026-09-04 16:24 KST(K3s 설치 당일 — K3s 시스템 파드의 재시작 수 1–2가 그 흔적)이고 그 뒤 27일간 없다(노드 B는 09-04 19:05 KST). Vault · ESO · Argo · 정책 · 터널 커넥터가 들어온 뒤로는 한 번도 재부팅되지 않았다. Vault 파드 재기동 드릴은 있었다(vault-unseal.md §1 — unseal 8초 · 드릴 전체 20초). 곧 이번이 "호스트가 꺼졌다 켜질 때 iptables 규칙 · k3s 서비스 · WireGuard · DNS 설정이 사람 없이 돌아오는가"의 첫 실측이다.
- **F2 터널 커넥터는 노드마다 하나다**(gitops `platform/cloudflared/deployment.yaml` — replicas 2 · required anti-affinity `kubernetes.io/hostname`). 노드 A가 내려가도 노드 B의 커넥터가 남는다. 터널 ingress 셋: `ssh-a` → 노드 A 22 · `ssh-b` → 노드 B 22 · `k8s` → svc `kubernetes.default` 443(→ 노드 A 6443). 곧 재부팅 중에도 `ssh ssh-b`는 되고, 노드 A의 sshd가 뜨면 `ssh ssh-a`가, k3s가 뜨면 kubectl이 돌아온다. **노드 B 커넥터가 Running이 아니면 재부팅하지 않는다**(유일한 접속 경로가 사라진다).
- **F3 Vault는 노드 A에 고정**(nodeSelector `role: platform` · Raft 1 replica · local-path PVC · OCI KMS auto-unseal은 인스턴스 주체 — 노드 A의 동적 그룹만 키를 쓸 수 있다). KMS 장애 중의 재시작은 CrashLoop이다(vault-unseal.md §2) — 사전 점검에 넣는다.
- **F4 ClusterSecretStore 5개**(`vault-platform` · `vault-dev` · `vault-prod` · `vault-data` · `k8s-data-ca`) · 실제 ExternalSecret 2개(`secrets/cert-manager` DNS 토큰 · `secrets/cloudflared` 터널 토큰), 둘 다 `refreshInterval: 5m`. 하네스 reboot-4의 마감(reboot-2 통과 + 300초)과 맞는다.
- **F5 하네스의 틈(P1)**: `-AfterReboot`는 스크립트 시작을 0초로 잡고 곧바로 폴링한다. 노드가 아직 내려가지 않았거나 재부팅이 먹지 않았으면 재부팅 **전의** 건강한 상태로 reboot-0..4가 전부 PASS한다.
- **F6 하네스가 보는 Argo 상태는 낡은 값일 수 있다.** API가 돌아온 직후의 `status.health`는 Argo가 다시 평가하기 전의 값이다(Argo 파드가 노드 B에 있으면 재시작하지 않는다 — 배치는 사전 관찰에서 확인). 계약(T034)은 "Healthy"만 요구하므로 하네스 판정은 그대로 두고, **사후 스냅샷**에서 `status.reconciledAt`이 부팅 뒤인지를 따로 기록한다(T046의 "판정의 유효성을 받치는 조회"와 같은 방식).
- **F7 백업 객체**: 버킷 `joshuatech-backup-platform` · `k3s/k3s-<UTC ts>.tar.age`(보존 7일) · `vault/vault-<UTC ts>.snap.age`(보존 30일). K3s 번들 tar의 항목: `server/db/state.db`(sqlite `.backup` 온라인 스냅샷 — 올리기 전에 노드에서 integrity_check를 이미 한 번 한다) · `server/token` · `server/cred/` · `server/tls/`. `svc-verify`는 이 버킷의 read objects(목록 + 내려받기)를 갖는다(`infra/oci/iam.tf`). 타이머는 매일 02:30 KST.
- **F8 평문의 민감도**: 번들 tar 전체에는 서버 토큰 · 인증서 개인키 · secrets-encryption 설정이 들어 있다. `state.db`만 꺼내면 K8s Secret 값은 secrets-encryption 키(같은 tar의 `server/cred/` — 꺼내지 않는다)로 암호화된 채다. Vault 스냅샷은 barrier 암호화 + seal 래핑이라 KMS 키 없이는 내용을 읽을 수 없다. → **디스크에 쓰는 평문은 `state.db`와 Vault 스냅샷 파일 둘로 한정**하고 tar 전체는 디스크에 풀지 않는다(파이프로 한 항목만 꺼낸다).
- **F9 워크스테이션 도구**: `age` 1.1.0 · `vault` 2.1.0 · bsdtar 3.8.8 · `oci` · PowerShell 7.6.6 있음. **`sqlite3` CLI 없음** — `python3` 표준 모듈 `sqlite3`(같은 SQLite 엔진의 같은 PRAGMA)이 있다. `vault operator raft snapshot inspect`는 로컬 파일만 읽는다(서버 · 토큰 불필요).
- **F10 지금 닫혀 있는 것**: 조회 전용 kubeconfig로의 조회가 시간 초과(터널 리스너 또는 Access 세션) · `svc-verify` 세션 만료. 둘 다 운영자가 여는 전제다(런북 §3 T045 절차 메모 4 — 조회 토큰 8시간 · OCI 세션 60분).
- **F11 SC-001의 문면**: "노드 2개 Ready, root app 하나의 수동 apply 뒤 30분 안에 플랫폼 Application 전부(ES 제외)가 Synced/Healthy". 실제 이력: root app은 2026-09-07(T040)에 빈 디렉터리를 가리키는 채로 적용됐고(20초 뒤 Synced/Healthy), 플랫폼 Application은 2026-09-08 ~ 09-28에 PR 단위로 하나씩 들어왔다(T041–T046). **"빈 클러스터에 root app을 적용해 전부가 한 번에 올라오는" 구간은 한 번도 없었다.**

## 3. 발견한 문제와 결정

### P1. 하네스가 재부팅 없이 PASS할 수 있다 — 코드로 닫는다(진행 중)

`reboot-0`의 충족 조건에 "노드 A의 `status.nodeInfo.bootID`가 기준값과 다르다"를 더한다. 기준값은 재부팅 전에 `-Baseline` 모드로 적어 두고 `-AfterReboot -BaselineBootId <값>`으로 넘긴다(없으면 폴링을 시작하지 않고 FAIL). 나머지 조건은 `reboot-0` 뒤에만 평가되므로 고치지 않는다. 가짜 kubectl(과도 상태 포함)로 도는 단위 테스트를 먼저 쓴다. 지시서 `.superpowers/t048/prompts/harness-build.md`.

대안으로 본 것: 절차로만 막기(재부팅 뒤 API가 내려간 것을 본 다음 하네스를 시작) — 사람의 순서에 기대고, T049 · 이후의 재실행에서 다시 같은 틈이 생긴다.

**빌더 결과(2026-10-01)**: 가드 구현 · 단위 테스트 105 단언 실패 0(약 100초) · 수정 전 스크립트는 "재부팅 없음" 시나리오에서 exit 0(틈의 재현) · 변이 셋 검출. 컨트롤러 독립 실행 105/0 · 평상시 모드 출력은 변경 전과 같음.

**독립 리뷰(APPROVED_WITH_FIXES) — 가짜 kubectl 실행으로 재현한 것과 조치**:

| # | 심각도 | 내용 | 조치 |
|---|---|---|---|
| 1 | high(이번 변경이 만든 것은 아님) | reboot-0 통과 뒤 reboot-2 · 4가 **재부팅 전의 낡은 상태**로 통과한다 — store의 Ready가 재부팅 중에 전이하지 않으면 anchor가 재부팅 전 시각이라 옛 `refreshTime`도 통과한다(ESO가 죽어 있어도 같다). 노드가 NotReady여도 reboot-0이 통과한다. 살아 있는 관측은 Vault 하나뿐이었다 | reboot-0에 노드 Ready=True를 더하고, 그 관측의 `lastHeartbeatTime`(서버 시각)을 **부팅 anchor**로 기록 → reboot-4의 anchor = max(store anchor, 부팅 anchor). 수용 기준의 문면("그다음 refresh")을 그대로 구현하는 것이다. Argo(reboot-3)는 재조정 주기 때문에 하네스에 넣지 않고 사후 스냅샷(§4 단계 5)이 맡는다 — F6 |
| 2 | medium | baseline 값이 틀리면(마지막 자리만 달라도) 재부팅 없이 PASS하고, 증거 줄이 8자만 보여 줘 사후 대조가 안 된다 | bootID 전체를 출력 · 런북 블록은 `baseline:` 줄에서 값을 변수로 받아 넘긴다(다시 타이핑하지 않는다) |
| 3 | low | 라벨이 다른 노드로 옮겨 가면 그 노드의 bootID로 통과한다 | 선택 인자 `-BaselineNode`(다르면 final FAIL) |
| 4 | low | 노드 0개가 final이라 API 복귀 직후 목록이 한 번 비어 보이면 2초 만에 끝난다 | 0개는 미충족(폴링), 2개 이상만 final |
| 5 | info(기존 규칙) | whoami의 401 한 번에 리허설 전체가 끝난다 | `-AfterReboot`에서는 연속 두 번일 때 fatal(다른 신원은 즉시 fatal 그대로) — 한 번뿐인 라이브 측정에서 일시 오류로 재부팅을 다시 해야 하는 비용이 더 크다 |
| 6–8 | low · info | 부하에서 흔들리는 마감 둘 · 단언 없는 분기 둘 · 인자 값을 가리기 전에 자름 | 테스트 보강 · 가린 뒤 자르기 |

수정 지시서 `.superpowers/t048/prompts/harness-fix.md` → 같은 빌더가 반영(단위 테스트 171 단언 · 변이 넷 검출).

**재리뷰(APPROVED_WITH_FIXES)** — 지난 발견은 닫혔고 수정이 만든 잘못된 PASS는 없다. 남은 것과 조치(지시서 `harness-fix2.md`):

| 재리뷰 | 내용 | 조치 |
|---|---|---|
| A · medium | 마감 0–5초 전에 충족된 상태가 late가 된다 — 판정 시각이 조회가 끝난 뒤라 마감에 맞춘 마지막 조회는 항상 마감 뒤에 끝난다(가짜 시나리오로 재현) | 충족의 마감 판정을 **조회를 시작한 시각**으로 · 마지막 대기는 마감 1초 전에 끝낸다. 느슨해지는 폭 = 한 번의 조회 시간(Vault 확인은 응답 대기 최대 8초) — 출력에 `observation started at …`로 드러난다 |
| B · low | 부팅 뒤에 성공했지만 anchor보다 앞선 refresh는 인정되지 않아 다음 refresh(5분 뒤)를 기다린다 | 부팅 anchor = **새 bootID를 처음 본 조회**의 heartbeat(Ready 값과 무관 · 유지) |
| C · low | `-BaselineNode`를 생략하면 라벨이 옮겨 간 경우가 통과한다 | `-AfterReboot`의 필수 인자로 |
| D · low | 틀린 baseline 값은 여전히 재부팅 없이 통과한다(두 값 전체가 찍혀 대조는 된다) | 코드로 막지 않는다 — 절차: `-Baseline`의 출력에서 값을 변수로 받아 넘기고, `baseline:` 줄과 `reboot-pre-4` 줄의 값이 같은지를 PASS의 조건으로 기록한다(§4 단계 4) |
| E · low | 테스트가 못 잡는 변이(401 "연속" · Ready=Unknown) | 케이스 추가 |

2차 수정 결과: 단위 테스트 181 단언 실패 0(약 4분 — 기본 간격 10초를 그대로 쓰는 경계 케이스 둘이 더해졌다) · 변이 넷 검출 · 평상시 모드 출력은 HEAD와 같음. 실제 클러스터에서만 확인되는 것(재부팅 뒤 첫 status의 heartbeat 모양 · ESO의 재시도 간격 · 조회 계정의 노드 조회 권한)은 사전 관찰과 리허설 자체가 잰다.

교훈: **"재부팅이 일어났는가"만 막으면 절반이다 — "지금 보는 상태가 재부팅 뒤에 만들어진 것인가"를 조건마다 물어야 한다.** 컨트롤러는 F6에서 Argo만 낡은 값 문제로 적었고 store · ExternalSecret은 놓쳤다.

### P2. SC-001의 근거를 무엇으로 남길 것인가 — **결정: 안 A(사용자 2026-10-01)**

재부팅 명령 시각 → 전 Application Synced/Healthy(부팅 뒤 `reconciledAt` 기준) 시각과 실제 이력을 기록하고, 문면 그대로의 구간(빈 클러스터에 root app 적용 → 전부 Healthy)은 재지 않았다는 한계를 `report.md`에 적는다. 재구축 리허설은 복원 런북(T058 · T114)이 생긴 뒤의 후속 후보로 남긴다.

| 안 | 기록하는 것 | 잰다고 말할 수 있는 것 | 비용 · 위험 |
|---|---|---|---|
| **A(권장)** | 재부팅 명령 시각 → 전 Application Synced/Healthy(부팅 뒤 `reconciledAt` 기준) 시각 + 실제 이력(root app 2026-09-07 · Application은 PR 단위로 3주) + **문면 그대로의 구간은 재지 않았다는 한계** | 노드 A가 통째로 꺼졌다 켜진 뒤 플랫폼이 사람 없이 수렴하는 시간(이미지 · PVC가 있는 상태) | 추가 작업 없음. SC-001 문면(빈 클러스터에서의 첫 수렴)은 미실측으로 남는다 → `report.md`에 적고 재구축 리허설을 후속 후보로 |
| B | A + 재부팅 뒤 운영자가 `root-app.yaml`을 다시 apply하고 전 Application을 hard refresh → 전부 Synced/Healthy까지의 시간 | "root app apply"라는 동작에서 시작한 시간. 다만 객체가 이미 있어 조정만 일어난다 — A보다 더 증명하는 것이 거의 없다 | 운영자 명령 2–3개 · 위험 낮음 |
| C | 실제 재구축: 두 노드 재이미지 → K3s → Argo → root app → 전부 Healthy | SC-001 문면 그대로 | 반나절 이상 · Vault 재초기화 또는 스냅샷 복원 · kv 재시드 · 인증서 재발급(LE 한도) · 터널 토큰 · 접속 경로 재구성. 복원 런북(T058 · T114)이 아직 없다 |
| D | T048에서는 재부팅만 기록하고 SC-001 근거는 T049(E2E) 또는 converge로 넘김 | — | 결정이 한 번 더 밀린다 |

### P3. `sqlite3` CLI가 워크스테이션에 없다

기본: `python3`의 표준 `sqlite3` 모듈로 `PRAGMA integrity_check`를 실행한다(설치 없음 · 같은 엔진 · SQLite 버전을 함께 출력). 과제 문구의 명령과 표기가 다르다는 점을 런북에 적는다. 운영자가 원하면 `winget install --id SQLite.SQLite -e`로 CLI를 설치해 문구 그대로 실행한다.

### P4. 전제 — 운영자가 여는 것

조회 경로(터널 리스너 + 조회 토큰 8시간) · `svc-verify` 세션(60분) · 노드 A · B SSH.

## 4. 절차(초안 — 블록은 하네스 수정과 독립 리뷰 뒤에 확정)

| 단계 | 누가 | 무엇 | 다음으로 가는 조건 |
|---|---|---|---|
| 0 | 운영자 | 터널 리스너 · 조회 토큰 · `svc-verify` 세션을 연다 | 에이전트의 `kubectl auth whoami` = `agent-view` |
| 1 | 에이전트(읽기) | **사전 관찰**: `-Baseline`(bootID) · 노드 2 Ready · Application 전부 Synced/Healthy · store 5 Ready · ExternalSecret 전부 `SecretSynced` · Vault `sealed=false type=ocikms` · 터널 커넥터 2개 Running(노드 A 1 · **노드 B 1**) · 노드 A의 파드 목록(시작 시각 · 재시작 수) · Argo · ESO 파드의 배치 | 전 항목 충족. 하나라도 아니면 재부팅하지 않고 원인부터 본다 |
| 1b | 운영자(읽기 · SSH) | 노드 A: `systemctl is-enabled k3s` · 진행 중인 apt/dpkg 없음 · `/var/run/reboot-required` 유무(있으면 새 커널로 부팅된다 — 기록) · `uname -r` · SUC 창(일요일 03–05시) · 백업 타이머(02:30) 밖 | `enabled` · 진행 중 작업 없음 |
| 2 | 에이전트(읽기) | **관찰을 먼저 시작**(10초 간격: API 도달 · 노드 A bootID · Ready · Vault 파드 상태 · Application Healthy 수) — 재부팅 전 표본이 대조군이 된다 | 표본 3개 이상이 정상 |
| 3 | **운영자(쓰기 — 사용자 재확인)** | `ssh ssh-a "sudo systemctl reboot"` — 명령 시각(UTC)을 적는다 | — |
| 4 | 에이전트(읽기) | `reboot.tests.ps1 -AfterReboot -BaselineBootId <1의 값> -BaselineNode <1의 노드>` — 두 값은 1의 `baseline:` 줄에서 변수로 받아 넘긴다(손으로 옮기지 않는다) | exit 0 **그리고** `reboot-pre-4` 줄의 baseline 값 = 1의 `baseline:` 줄의 값 = PASS. FAIL이면 §5 |
| 5 | 에이전트(읽기) | **사후 스냅샷**(하네스 뒤 · 그리고 10분 뒤 한 번 더): bootID · 커널 · 노드 2 Ready · Vault 컨테이너 시작 시각 > 재부팅 시각 · store 조건 · ExternalSecret refreshTime · Application 전부 Synced/Healthy이며 `reconciledAt` > 부팅 시각 · 노드 A 파드 재시작 수 · 터널 커넥터 2 Running | 전 항목 충족 → 재부팅 리허설 PASS |
| 6 | 운영자(개인키 · `svc-verify` 세션) | **백업 검증**(§6 스크립트 한 줄): 최신 객체 둘 내려받기 → 복호화 → K3s `state.db` integrity_check · 번들 항목 수 확인 / Vault 스냅샷 inspect → 평문 삭제. 재부팅과 독립이라 재부팅 앞이나 뒤 어느 쪽에 해도 된다 | exit 0 · `ok` · 메타데이터 출력 |
| 7 | 에이전트 | 기록: 런북 §3 T048 절(출력 · 시각) · §3 요약(전체 순서 · 시간 · 시크릿 취급) · 학습 로그 · `tasks.md` 체크 | — |

### 4.1 명령(운영자 것과 에이전트 것을 나눈다)

**운영자 — 단계 0(전제 열기)**
- 터널 리스너: `cloudflared access tcp --hostname k8s.joshuatech.dev --url 127.0.0.1:6443`(세션 동안 켜 둔다).
- 조회 토큰(8시간): gitops `platform/policies/README.md`의 조회 kubeconfig 절차(`kubectl create token agent-view -n kube-system --duration=8h` → 조회 전용 kubeconfig 파일 갱신).
- OCI 세션(60분): `oci session authenticate --profile-name svc-verify`.

**운영자 — 단계 1b(노드 A 읽기 점검 · 쓰기 없음)**

```powershell
$cmd = @'
hostname; uname -r; uptime -s
echo "k3s enabled=$(systemctl is-enabled k3s) active=$(systemctl is-active k3s)"
if [ -f /var/run/reboot-required ]; then echo "reboot-required: yes ($(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' '))"; else echo "reboot-required: no"; fi
pgrep -a 'apt|dpkg|unattended-upgr' || echo "apt/dpkg: none running"
systemctl list-jobs --no-pager | tail -n 1
systemctl list-timers platform-backup.timer --no-pager | sed -n '2p'
'@
ssh ssh-a $cmd
```

판정: `k3s enabled=enabled active=active` · apt/dpkg 없음 · `No jobs running.`. `reboot-required: yes`면 새 커널로 부팅된다 — 진행 여부를 다시 묻는다.

**운영자 — 단계 3(재부팅 · 사용자 재확인 뒤)**

```powershell
"reboot command at $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"; ssh ssh-a "sudo systemctl reboot"; "ssh exit=$LASTEXITCODE (연결이 끊기며 255가 나오는 것은 정상)"
```

**운영자 — 단계 6(백업 검증 · 읽기와 로컬 임시 파일뿐)**

```powershell
pwsh -NoProfile -File scripts/backup-verify.ps1 -AgeKeyFile "<개인키 파일 경로>"
```

출력 전체를 붙여 준다(개인키 경로 · 내용은 출력에 없다). 창을 강제로 닫았으면 임시 폴더의 `backup-verify-*`를 확인한다(다음 실행이 `bv-pre-3`으로 알려 준다).

**에이전트(조회 전용 · `.superpowers/t048/obs/`의 도구)**
- 단계 1: `snapshot.ps1 -Label pre`(관문 줄 전부 OK여야 한다) · `run-reboot-harness.ps1 -Mode baseline -BaselineOut <파일>`.
- 단계 2: `observe.ps1 -LogFile <파일>`(백그라운드 · 10초 간격).
- 단계 4: `run-reboot-harness.ps1 -Mode after -BaselineOut <파일> -LogFile <파일>` — 기준값을 파일에서 읽어 넘기고, 하네스의 `reboot-pre-4` 줄과 대조한 뒤 `VERDICT` 줄을 낸다.
- 단계 5: `snapshot.ps1 -Label post -Since <재부팅 명령 시각>` — Vault 컨테이너 시작 · ExternalSecret refreshTime · Application reconciledAt이 그 시각 뒤인지까지 관문으로 본다(하네스 직후 한 번 · 10분 뒤 한 번).

## 5. 위험과 대응

| 일어날 수 있는 일 | 알아채는 방법 | 대응(운영자) |
|---|---|---|
| 노드 A가 돌아오지 않는다(5분 넘게 API 불통) | 관찰 로그 · 하네스 reboot-0 미충족 | `ssh ssh-b`(노드 B 커넥터 경유)는 살아 있다 → `ssh ssh-a` 시도(sshd만 떠 있으면 된다) → `systemctl status k3s` · `journalctl -u k3s -b`. sshd도 안 뜨면 OCI 콘솔의 인스턴스 콘솔 연결 · 소프트 리셋. 최후: NSG 22 임시 규칙(런북 §3 T041 절차 메모의 2차 break-glass). 인스턴스는 종료하지 않는다 |
| k3s는 떴는데 노드 간 통신이 안 된다(iptables · WireGuard 51820/udp) | 노드 B NotReady · 파드 간 통신 실패 | 노드 A에서 `sudo iptables -S | head` · `/etc/iptables/rules.v4` 적재 여부(`netfilter-persistent`) · `host-prep.sh` 재실행(멱등) |
| Vault가 sealed/CrashLoop | 하네스 reboot-1 · `VaultSealed` | vault-unseal.md §3 진단 순서(로그 grep 먼저 — KMS · IMDS · 인스턴스 주체). 파드를 임의로 지우지 않는다(§2) |
| store가 Ready로 돌아오지 않는다 | reboot-2 | Vault 상태부터(위) → ESO 파드 로그. ExternalSecret은 마지막 Secret을 유지하므로 기존 파드는 계속 돈다 |
| Application이 Degraded/Progressing에 머문다 | reboot-3 · 사후 스냅샷 | 어떤 리소스가 원인인지 조회(에이전트) → 기다릴 것과 손댈 것을 나눠 사용자와 결정. 수동 sync는 마지막 |
| 하네스는 FAIL인데 시스템은 건강(마감 초과) | "met late" | 실측값으로 기록하고 판정은 FAIL — 마감(5분)을 넘긴 원인을 적는다. 재시도는 사용자 결정 |
| 터널 커넥터가 한쪽만 남는다 | 사후 스냅샷 | 노드 A 쪽 파드가 Running으로 돌아왔는지 · 아니면 이벤트 조회. 교체는 1개씩(`rollout restart` 금지 — T045 G4) |

되돌리기: 재부팅은 되돌리는 변경이 아니다(설정을 바꾸지 않는다). 새 커널로 부팅됐고 그 커널에서 문제가 나면 GRUB의 이전 커널 선택이 되돌리기다(콘솔 연결 필요) — 1b에서 `reboot-required`가 있으면 사용자에게 알리고 진행 여부를 다시 묻는다.

## 6. 백업 검증 — 붙여 넣는 블록이 아니라 스크립트로(`scripts/backup-verify.ps1`)

개인키와 평문을 다루는 절차라 **테스트가 있는 스크립트**로 만든다(지시서 `.superpowers/t048/prompts/backup-verify-build.md`). 운영자는 `pwsh -NoProfile -File scripts/backup-verify.ps1 -AgeKeyFile <개인키 경로>` 한 줄을 실행하고 출력만 붙여 준다. T114의 복원 런북과 이후의 정기 점검에서도 같은 스크립트를 쓴다.

설계 원칙:
- 읽기와 로컬 임시 파일뿐이다(버킷 · 클러스터를 바꾸지 않는다). 내려받기는 `svc-verify` 세션 — 암호문만 다룬다.
- 개인키 파일의 경로와 내용, 번들 항목의 내용을 출력하지 않는다. 자식 프로세스의 오류 문구에 섞인 경로는 가린다.
- K3s 번들은 **파이프로 `server/db/state.db`만** 꺼낸다. 평문 tar는 디스크에 쓰지 않는다. 항목은 개수만 확인한다(`server/token` 1 · `server/cred/` · `server/tls/` 각 1개 이상 — 복원에 필요한 것이 들어 있는가).
- 성공 · 실패 · 예외 어느 경로로 끝나든 `finally`에서 작업 디렉터리를 지운다(지워서 잃는 것이 없다 — 원본은 버킷에 있다).
- 최신 객체가 26시간보다 오래됐으면 FAIL(백업이 돌지 않는다는 뜻 — "최신" 백업을 검증한다는 과제의 전제).
- 하네스는 진짜 `age` · `tar` · `vault` · 파이썬으로 돌고 `oci`만 가짜다. 케이스: 다른 키 · 잘린 암호문 · 항목 누락 · 손상된 SQLite · 쓰레기 스냅샷 · 세션 만료 · 크기 불일치 · 도중 예외 · 공백 경로.

컨트롤러의 모의 실측(2026-10-01 · 일회용 키 · 가짜 번들 · 일회용 로컬 Vault):
- **F12** PowerShell 7.6의 네이티브 파이프와 `>` 리디렉션은 바이트를 보존한다 — `age -d | tar -xOf - server/db/state.db > 파일`의 SHA-256이 원본과 같다(`cmd /c` 파이프도 같다). 다만 파이프라인 뒤의 `$LASTEXITCODE`는 마지막 명령의 것이라 **age의 실패를 따로 봐야 한다**(전체를 한 번 복호화해 종료 코드를 확인 — age는 인증된 청크만 내보내므로 잘린 암호문은 앞부분이 정상으로 나온다).
- **F13** `vault operator raft snapshot inspect`: 정상이면 exit 0 + `ID` · `Size` · `Index` · `Term` · `Version` + 키 이름 표 + `Total Size`. 잘린 파일 · 쓰레기는 exit 1. 서버도 토큰도 필요 없다. 키 이름 표에는 마운트 식별자가 있어 기록에는 머리 다섯 줄과 합계만 옮긴다.
- **F14** 손상된 SQLite에 파이썬 `sqlite3`는 예외를 던진다(추적 출력) — 스크립트는 한 줄 사유로 바꿔 FAIL해야 한다.
- 일회용 Vault의 init 산출물과 데이터 디렉터리는 스냅샷을 뜬 직후 지웠다. 스냅샷 견본(키가 폐기된 일회용 Vault의 것 · 비밀 없음)만 하네스 픽스처로 남긴다.

빌더 결과(2026-10-01): 스크립트 543줄 · 하네스 61 단언 실패 0(약 70초 · GNU tar와 bsdtar 둘 다) · 변이 열 검출. 빌더가 더한 것 가운데 눈여겨볼 것: age → tar를 PowerShell 파이프라인이 아니라 프로세스 둘을 직접 이어 **두 종료 코드를 따로** 받는다 · `state.db`를 `mode=ro&immutable=1`로 연다(노드의 `.backup` 사본은 WAL 표시가 있어 `mode=ro`만으로 열면 `-wal`/`-shm`이 생긴다 — 실측) · 자식 프로세스의 임시 폴더를 작업 디렉터리 안으로 돌린다(**`vault` CLI 2.1.0은 실행할 때마다 임시 폴더에 DLL 디렉터리를 남긴다**).

**독립 리뷰(APPROVED_WITH_FIXES) — 비밀 누출은 찾지 못했다**(키 경로 · 토큰 · 인증서 표식 · 항목 이름이 출력에 없고 작업 디렉터리 밖에 남는 파일 0). 정상 백업의 잘못된 FAIL도 없다(GNU tar로 만든 92 MB 번들이 약 4초). 재현된 "복원할 수 없는데 exit 0"과 조치(지시서 `backup-verify-fix.md`):

| # | 심각도 | 내용 | 조치 |
|---|---|---|---|
| 1 | medium | 신선도 판정이 객체 **이름**의 시각만 본다 — 미래 시각의 이름이 통과하고 진짜 최신을 가린다 | `time-created`도 상한 안이어야 하고 · 미래 이름은 FAIL · 두 시각의 차이 1시간 초과는 FAIL |
| 2 | medium | `kine`이 비어 있어도 PASS | 행 수 1 이상 |
| 3 | medium | `./server/db/state.db` 같은 별칭 표기의 중복이 "정확히 1" 검사를 비껴간다(복원하면 뒤의 것이 덮어쓴다 · bsdtar는 둘을 이어 붙여 꺼낸다) | 모든 항목 이름이 정규 형태여야 한다 |
| 4 | low | 0바이트 · 끊긴 링크 항목이 개수에 들어간다 | 일반 파일이고 크기 > 0인 것만 센다 |
| 5 | low | `state.db` 쓰기가 실패하면 끝나지 않는다 | 자식 종료 + 대기마다 시간 제한 |
| 6 | low | 강제 종료하면 평문이 작업 디렉터리에 남고 다음 실행이 알리지 않는다 | 시작할 때 남은 작업 디렉터리가 있으면 FAIL(지우지 않는다) · 런북에 "창을 닫았으면 임시 폴더 확인" |
| 7–12 | low | 한국어 로캘의 예외 문구가 `?` · 정리 실패 줄의 경로 · oci 출력 원문 · 테스트의 빈 곳(공허한 사유 단언 셋 · 가림 미시험) | 반영 |

Vault 스냅샷 쪽은 절단 · 변조가 전부 FAIL했다(CLI가 해시를 검증한다). 실물로만 확인되는 것: 실제 `oci`의 출력 모양 · 노드가 만든 실제 번들 · OCI KMS로 seal된 실제 스냅샷의 inspect — 리허설의 단계 6이 잰다.

## 7. 진행 기록

- 2026-10-01: T047을 닫고 조사(F1–F11) → P1 하네스 가드 빌더 착수 → 이 문서 초안. 조회 경로와 OCI 세션이 닫혀 있어 사전 관찰은 운영자가 전제를 연 뒤에 한다.
- 2026-10-01 오후: 하네스 — 빌더 → 리뷰 → 수정 → 재리뷰 → 수정 2 → 컨트롤러 독립 실행 181/0 → 커밋 `56301c3`. 백업 검증 스크립트 — 빌더 → 리뷰 → 수정 → 컨트롤러 독립 실행 96/0 → 커밋 `2df4a3b`(run-all 항목 둘 포함). 관찰 도구 셋(`snapshot.ps1` · `observe.ps1` · `run-reboot-harness.ps1`)은 `.superpowers/t048/obs/`(gitignore) — 문법 검사와 닫힌 조회 경로에서의 실패 동작까지만 확인했다. **실제 클러스터에서는 아직 한 번도 돌지 않았다** — 사전 관찰(재부팅 전)이 첫 실행이고, 거기서 드러나는 결함은 재부팅 전에 고친다.
- 14:35 KST 조회 경로 상태: API에는 닿고(터널 리스너 열림) 조회 토큰은 만료(401). `svc-verify` 세션은 만료.
- **남은 것(전부 운영자 · 사용자가 있어야 한다)**: P2 결정(SC-001 근거) → 단계 0–7 → 런북 §3 T048 절과 §3 요약 → 모노레포 run-all 전체 한 번 → 체크(54/119).
- 빌더가 범위 밖에서 찾은 것: `vault` CLI 2.1.0은 Windows에서 실행할 때마다 임시 폴더에 `gosnowflake-cgo*` 디렉터리(DLL 한 개)를 남긴다 — 운영자의 평소 사용에서도 쌓인다. 스크립트는 자식의 임시 폴더를 작업 디렉터리로 돌려 피한다.
- 15:35–16:30 KST: 운영자가 OCI 세션 · 조회 토큰을 열었다 → 백업 검증 13항목 통과(실제 버킷) → 사전 관찰 전부 정상(관찰 도구 셋이 실제 클러스터에서 처음 돌았다) → 노드 A 읽기 점검에서 **대기 중인 커널 7.0**이 나왔다(§8.1 F15). 재부팅을 멈추고 선택지를 냈다 → 사용자 결정(§8.2) → 복구 경로 준비 착수(§8.3 — 빌더).
- 17:00 KST경: 실제 터널 너머 port-forward 수립 시간을 재어 하네스의 8초 상한 결함을 찾았다(§8.1 F19) → 수정 지시서 3. 관찰 도구 보강(스냅샷: 커널 기대값 관문 · `-Since` 관문 선택 · Vault 조회를 40초까지 / 표본: 두 노드의 bootID · 커널 / 자동 시작: 연속 다섯 번 실패 + 잘못된 시작이면 다시 대기).
- 교훈: **하네스는 실제 경로에서 한 번 돌려 봐야 한다.** 가짜 kubectl로 181개 단언을 통과한 하네스가, 실제 터널의 지연(port-forward 수립 10–23초) 앞에서는 한 조건이 항상 실패하게 돼 있었다. 사전 관찰을 리허설과 같은 경로 · 같은 도구로 미리 돌린 덕에 재부팅 전에 잡았다. 그리고 **"재부팅"이라는 한 단어 안에 다른 변경이 숨어 있을 수 있다** — 자동 재부팅을 꺼 둔 노드에서는 다음 재부팅이 곧 그동안 쌓인 커널 전환이다.

- 17:40–19:00 KST: **하네스를 실제 경로에서 예행**(재부팅 없이 · 일부러 틀린 기준값) — 다섯 조건이 실제 응답 · 권한에서 전부 동작(Vault 확인 13.7초 · reboot-4는 부팅 anchor 뒤의 refresh를 기다려 155초에 충족). 같은 경로의 호출 시간 실측: 한 번에 2–20초 · 여섯–여덟 번에 한 번꼴로 실패(10초 근처 — TLS 핸드셰이크 시간 초과) · `get applications`는 419 KB로 한 번 19.5초 → 수정 4(조회 시간 제한 30초 · **0초 기준점 = 옛 부팅을 마지막으로 본 시각** — 하네스를 먼저 켜 두고 운영자가 준비됐을 때 재부팅한다) → 수정 5(재부팅 뒤 API가 먼저 돌아와 낡은 옛 bootID가 보이는 창에 대비해, 한 번 굳은 기준점은 옛 부팅을 연속 세 번 봐야 다시 움직인다). armed 경로도 실제 경로에서 예행했다(1분 제한 — armed → 일시 실패로 기준점이 굳음 → 세 번째 관측에서 다시 armed → "재부팅 없음" FAIL: 설계대로). 이 PC의 부하(빌더 · 리뷰어의 테스트 · 다른 세션이 남긴 `find` + sshfs)가 조회 경로를 느리게 했을 가능성이 있다 — 15:36에는 호출 넷이 12초였다. **리허설 동안에는 다른 작업을 돌리지 않는다.**
- `kernel-trial.sh`: 빌더 완료(모의 하네스 85 단언 · 컨트롤러 독립 실행 85/0 · 스크립트 전문을 컨트롤러가 읽음) → 독립 리뷰 중(GRUB 전제를 우분투 소스와 대조). 실행표 §8.7.

## 8. 커널 전환을 포함한 재부팅 — 복구 경로 준비와 단계(2026-10-01 오후)

### 8.1 사전 관찰과 노드 점검에서 나온 것

- **백업 검증(단계 6)은 끝났다** — 운영자 실행 15:35 KST · 13항목 통과 · 16초. K3s 번들 `k3s/k3s-20260930T173010Z.tar.age`(항목 67 · `state.db` 1 · `token` 1 · `cred` 10 · `tls` 47 · `kine` 1,867행) · Vault 스냅샷 `vault/vault-20260930T173010Z.snap.age`(Index 187495 · Term 4 · 키 28). 출력 사본 `.superpowers/t048/restore/real-run-2026-10-01.txt`.
- **사전 관찰(15:36–15:39 KST)**: 노드 2 Ready · Application 22 Synced/Healthy · store 5 Ready · ExternalSecret 2 동기화 · Vault unsealed · 터널 커넥터는 노드마다 하나 · 기준값 `joshtech-api` / bootID `a8d06ef9-…`. 조회 계정의 노드 조회 권한과 `role=platform` 라벨 1개도 확인됐다. 노드 A의 실행 중 파드 11개(Vault · ESO 3 · Traefik · svclb · 터널 커넥터 1 · Reloader · SUC 컨트롤러 · metrics-server · local-path) — Argo 5개와 CoreDNS는 노드 B.
- **F15 재부팅하면 커널이 바뀐다(두 노드 동일)**: 실행 중 `6.17.0-1020-oracle` · 설치만 된 채 대기 중 `7.0.0-1012-oracle` + `libc6`(`reboot-required`). `unattended-upgrades`는 보안 패치만 받고 자동 재부팅은 꺼져 있다(host-prep) — "재부팅은 업그레이드 창"이라는 주석은 있으나 **OS 패치 재부팅 절차는 런북에 없다**(§6은 K3s 업그레이드만).
- **F16 GRUB(두 노드 동일)**: `GRUB_DEFAULT=0` · 메뉴 숨김 · 대기 0초 · recordfail 대기 0초 → 새 커널이 부팅에 실패하면 콘솔에서 옛 커널을 고를 수 없다. grub.cfg에 우분투의 1회용 논리가 있다(`next_entry`가 있으면 그 항목을 한 번 부팅하고 지운다). grubenv는 `/boot/grub/grubenv`(별도 ext4 `/boot`). 항목 ID: 하위 메뉴 `gnulinux-advanced-<uuid>` · 커널 `gnulinux-<kver>-advanced-<uuid>`.
- **F17 새 커널의 사전 점검(읽기)**: initrd 있음 · WireGuard 모듈 있음 · K3s 관련 커널 설정 40여 개에 두 커널 사이 차이 없음 · `k3s check-config`(새 커널 설정 대상) `STATUS: pass`(선택 항목 둘만 missing) · `kernel.panic=10`(패닉 10초 뒤 재부팅). `linux-modules-extra`가 7.0에는 설치돼 있지 않다 — 지금 적재된 모듈이 새 커널에 다 있는지는 도구의 `status`가 대조한다.
- **F18 위험이 몰린 곳**: 계획 단계 조사(`research.md`)는 커널 6.17과 AppArmor · containerd 조합의 문제를 짚었고 exec 관련 건(containerd#12886)은 미해결이었다. 지금 커널에서 AppArmor 거부는 0건이다. 클러스터에서 **exec 프로브는 Vault의 readiness 프로브 하나뿐**이고 전 컨테이너가 기본 AppArmor 프로파일이다 — 커널 7.0은 조사된 적이 없다.
- **F19 조회 경로의 지연(실측)**: kubectl 한 번에 2–6초 · `port-forward svc/vault`의 수립에 **10–23초**(8회 전부 8초 초과). 하네스의 Vault 확인 1회 상한이 8초라 **지금 코드로는 reboot-1이 복구와 무관하게 항상 실패한다**(`cluster.tests.ps1`은 30초를 기다린다) → 수정 지시서 3(`harness-fix3.md` — 45초). 하네스가 실제 클러스터에서 `-AfterReboot`로 돈 적이 없어서 드러나지 않았던 결함이다. 터널의 일시 오류(TLS handshake timeout)도 한 번 관측됐다 → 하네스 자동 시작 도구는 연속 다섯 번 실패로 판정하고, 잘못 시작됐으면(실패로 끝났는데 bootID가 그대로) 다시 기다린다.

### 8.2 결정

커널을 어떻게 다룰지 네 안(①이번만 현재 커널로 부팅 ②노드 B 먼저 새 커널 → A ③그대로 새 커널 ④보류)을 냈고 컨트롤러의 권장은 ①이었다. **사용자 답(2026-10-01 · 원문)**: "커널 전환까지 이번에 처리하려면 2번을 선택하되, B의 실제 exec probe 검증과 완전 복구를 A 진행 조건으로 둔다. A에서는 T048 전체 검증을 수행한다. 부팅 실패 시 사용할 복구 경로가 준비되지 않았다면 4번으로 먼저 준비한다. T048의 원인 분리 자체가 우선이면 1번을 선택한다."

컨트롤러의 판단: **부팅 실패 시의 복구 경로는 준비돼 있지 않다**(F16 — 메뉴 숨김 · 시험해 본 콘솔 절차 없음 · 런북의 비상 경로는 sshd가 떠야 한다). 그래서 **먼저 준비하고**(아래 8.3), 준비와 리뷰가 끝난 뒤 ②를 주신 조건대로 진행한다. 원인 분리는 복구 경로가 겸한다 — 노드 A가 새 커널에서 실패하면 재부팅 한 번으로 옛 커널로 돌아오므로 그 시점에 같은 하네스로 다시 잴 수 있다.

### 8.3 복구 경로 — 기본값을 검증된 커널로 고정하고 새 커널은 한 번만

`infra/bootstrap/kernel-trial.sh`(가드와 모의 하네스가 있는 스크립트 — 지시서 `kernel-trial-build.md`). 운영자가 `Get-Content -Raw infra/bootstrap/kernel-trial.sh | ssh <노드> "sudo bash -s -- <하위 명령>"`으로 실행한다(노드에 파일을 남기지 않는다).

| 하위 명령 | 하는 일 | 핵심 가드 |
|---|---|---|
| `status` | 읽기 전용 — 커널 · GRUB 기본값 · 고정 · 1회용 선택 · 적재된 모듈이 각 커널에 있는가 | 상태가 어긋나면 exit 1 |
| `pin` | **지금 돌고 있는 커널**을 GRUB 기본값으로 고정(드롭인 `99-kernel-trial-pin.cfg` + `update-grub`) | 항목 ID가 정확히 하나 · 쓴 뒤 grub.cfg를 읽어 검증 · 실패하면 되돌림 |
| `trial <kver>` | grubenv에 `next_entry`만 쓴다 — 다음 한 번만 그 커널 | **고정이 있고 일관될 때만**(복구 경로 없이는 거부) · 적재된 모듈이 대상 커널에 다 있을 때만 |
| `cancel-trial` | `next_entry`를 지운다 | — |
| `unpin` | 고정을 풀어 기본값을 가장 새 커널로 | 실행 중 커널이 가장 새 커널일 때만(아니면 다음 부팅이 검증 안 된 커널이 된다) |

이렇게 하면 시험 커널이 어떤 식으로 실패하든 복구가 같다: **재부팅 한 번**(패닉이면 10초 뒤 저절로 · 부팅이 멈추면 OCI 콘솔의 강제 재시작)으로 고정된 커널로 올라온다. GRUB 메뉴를 만질 일이 없다. `grub-reboot`은 판에 따라 쓰는 변수가 달라(`next_entry` / `saved_entry`) 쓰지 않고, 노드의 grub.cfg에서 확인한 논리에 맞는 `next_entry`를 직접 쓴다.

### 8.4 단계와 관문

| # | 단계 | 누가 | 다음으로 가는 조건 |
|---|---|---|---|
| K0 | `status`(두 노드 · 읽기) | 운영자 | 일관 · 적재된 모듈이 7.0에 다 있다 |
| B0 | 노드 B `pin` | 운영자(쓰기) | `RESULT: OK` · grub.cfg 기본값 = 6.17 항목 |
| B1 | exec 프로브 시험 파드 적용(§8.5) → 지금 커널에서 Ready(대조군) | 운영자(쓰기) · 에이전트(관찰) | 파드 Ready · 프로브 실패 이벤트 0 |
| B2 | 노드 B **그냥 재부팅** — 고정이 먹는지(복구 경로의 실증) | 운영자(쓰기) | 6.17로 올라옴 · 스냅샷 관문 전부 OK · 시험 파드 다시 Ready |
| B3 | 노드 B `trial 7.0.0-1012-oracle` → 재부팅 | 운영자(쓰기) | **A 진행 조건**: 커널 7.0 · 노드 Ready · 파드 전부 Running/Ready · Application 22 Synced/Healthy(부팅 뒤 재조정) · ExternalSecret 부팅 뒤 갱신(= 노드 A 파드 → 노드 B CoreDNS, 노드 간 WireGuard) · 터널 커넥터 둘 · **시험 파드의 exec 프로브 Ready** · AppArmor 거부 0 · `next_entry` 비워짐 |
| A0 | 노드 A `pin` | 운영자(쓰기) | B0과 같음(값이 노드 B의 것과 같다) |
| A1 | 노드 A `trial 7.0.0-1012-oracle` → **T048의 측정 재부팅**(§4 단계 2–5 그대로: 관찰 먼저 → 재부팅 → 하네스 → 사후 스냅샷) | 운영자(쓰기) · 에이전트 | 하네스 PASS + 사후 스냅샷 관문(커널 7.0 포함) |
| F | 두 노드 `unpin` · 시험 파드 삭제 | 운영자(쓰기) | 기본값 = 가장 새 커널 · `next_entry` 없음 |

어느 단계에서든 멈출 수 있다 — 고정만 한 상태(B0 · A0)는 "재부팅해도 지금 커널"이라 지금보다 안전하다. B3이 실패하면 노드 B를 재부팅해 6.17로 돌리고 A는 건드리지 않는다(이 경우 T048을 6.17에서 잴지는 다시 묻는다). A1이 실패하면 노드 A를 재부팅해 6.17로 돌린 뒤 같은 하네스로 다시 잰다(원인 분리).

### 8.5 exec 프로브 시험 파드

`.superpowers/t048/canary/kernel-canary.yaml` — ns `jt-dev`(PSA restricted · 쿼터 안) · `nodeSelector: role=data` · Vault와 **같은 이미지(digest 고정) · 같은 securityContext** · 명령은 대기 루프 · readiness 프로브 `exec: /bin/sh -ec "vault version"`(Vault의 프로브와 같은 모양 — 셸을 거쳐 Go 바이너리를 exec). GitOps 밖의 일회용 수동 객체다(전례: T041의 `np-probe`) — 끝나면 지우고 삭제를 확인한다. 어느 Application에도 속하지 않아 sync 상태에는 영향이 없다.

### 8.6 남는 위험

- 1회용 선택이 지워지지 않는 경우(GRUB의 `save_env` 실패) — 그러면 시험 커널이 계속 선택된다. 노드 B의 B3에서 `next_entry`가 비워졌는지로 확인하고, 안 비워졌으면 A로 가지 않는다.
- 우분투 클라우드 이미지의 initrd 없는 부팅 시도 → 실패 시 initrd로 재시도하는 논리가 grub.cfg에 있다 — 시험 커널의 부팅이 두 번에 걸쳐 일어날 수 있다(부팅 시간이 늘어난다). B3에서 본다.
- 노드 B가 내려가 있는 동안의 접속 경로는 노드 A의 커넥터 하나다(9월 7일부터 돌던 파드). 노드 B의 재부팅은 접속 경로에 의존하지 않는다(스스로 올라온다).
- 커널 7.0에서 K3s server · Vault(raft · KMS unseal)는 노드 A에서 처음 돈다 — 노드 B의 관문이 덮지 못하는 부분이다. 그래서 A1의 실패 대응(재부팅 → 6.17)을 먼저 준비했다.

### 8.7 실행표(명령 · 단계마다 운영자 실행 → 출력 확인 → 다음 단계)

스크립트는 표준 입력으로 넘긴다(노드에 파일을 남기지 않는다). 아래에서 `KT` = `Get-Content -Raw D:\code\joshuatech_ver2\infra\bootstrap\kernel-trial.sh`.

| 단계 | 운영자 명령(PowerShell) | 통과 기준 |
|---|---|---|
| K0 읽기 | `foreach ($h in 'ssh-b','ssh-a') { "===== $h"; KT \| ssh $h "sudo bash -s -- status" }` | 두 노드 `RESULT: OK status` · 두 커널 모두 `menu-entry-ids=1` · 7.0의 `missing-loaded-modules=0` · `next_entry logic: present` · 기본값 `"0"` · grubenv 비어 있음 |
| B0 고정 | `KT \| ssh ssh-b "sudo bash -s -- pin"` | `RESULT: OK pin` · `later boots: 6.17.0-1020-oracle` |
| B1 시험 파드 | `kubectl --kubeconfig "$HOME\.kube\joshuatech-admin.yaml" apply --dry-run=server -f <kernel-canary.yaml>` → 같은 명령에서 `--dry-run=server`를 뺀 것 | 에이전트 조회: 파드 Ready · `Unhealthy` 이벤트 0 |
| B2 그냥 재부팅 | `"node B reboot command at $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"; ssh ssh-b "sudo systemctl reboot"` | 에이전트 스냅샷: 노드 B 커널 **6.17**(고정이 먹었다) · 관문 전부 OK · 시험 파드 Ready. 운영자 `status`(ssh-b): 고정 그대로 |
| B3 새 커널 1회 | `KT \| ssh ssh-b "sudo bash -s -- trial 7.0.0-1012-oracle"` → `RESULT: OK trial` 확인 뒤 B2와 같은 재부팅 명령 | **A 진행 조건**(§8.4) — 에이전트 스냅샷(노드 B 커널 7.0 · `-Since` 관문 es · apps) + 운영자 `status`(ssh-b: `running 7.0` · `next_entry` 없음 · AppArmor 거부 0) + 운영자 exec 시험 `kubectl --kubeconfig <admin> -n jt-dev exec kernel-canary -- vault version` |
| A0 고정 | `KT \| ssh ssh-a "sudo bash -s -- pin"` | B0과 같음 |
| A1 측정 재부팅 | 에이전트가 관찰 · 하네스를 먼저 켠다 → `KT \| ssh ssh-a "sudo bash -s -- trial 7.0.0-1012-oracle"` → `RESULT: OK trial` 확인 뒤 `"node A reboot command at …"; ssh ssh-a "sudo systemctl reboot"` | 하네스 `VERDICT: PASS` · 사후 스냅샷(두 노드 커널 7.0 · `-Since` 관문 전부) · 운영자 `status`(ssh-a) |
| F 고정 해제 | `foreach ($h in 'ssh-b','ssh-a') { KT \| ssh $h "sudo bash -s -- unpin" }` → `kubectl --kubeconfig <admin> -n jt-dev delete pod kernel-canary` | `RESULT: OK unpin` 둘 · 기본값 `"0"` → 7.0 · 시험 파드 없음 |

실패 때: B3이 관문을 못 넘으면 `ssh ssh-b "sudo systemctl reboot"` 한 번으로 6.17로 돌린다(부팅이 멈췄으면 OCI 콘솔에서 인스턴스 강제 재시작). A1이 실패하면 같은 방법으로 노드 A를 6.17로 돌리고, 같은 하네스로 다시 잰다. 시험을 접으려면 재부팅 전에 `cancel-trial`.

에이전트 쪽(조회 전용): 단계마다 `observe.ps1`(fast · full 둘)을 먼저 켜고, 재부팅 뒤 `snapshot.ps1 -Label <단계> -Since <명령 시각> -SinceGates <…> -ExpectKernel <노드=커널,…>`으로 관문을 본다. 노드 A의 측정 재부팅은 `run-reboot-harness.ps1 -Mode after`를 **재부팅 전에** 켠다 — 하네스가 옛 부팅을 마지막으로 본 시각을 0초로 잡는다. 리허설 동안 이 PC에서 다른 무거운 작업을 돌리지 않는다(조회 경로가 느려지고 실패가 늘어난다 — 실측).

### 8.8 `kernel-trial.sh` 독립 리뷰(2026-10-01 저녁) — APPROVED_WITH_FIXES

리뷰어는 Docker의 Ubuntu 24.04와 **실제 grub 도구**(grub-common · grub2-common · grub-emu 2.12-1ubuntu7.3 — x86_64 에뮬레이션, 같은 소스 판)로 돌렸다. 그 환경의 실제 `update-grub`이 만든 grub.cfg의 줄 번호가 노드에서 본 것과 전부 일치했다. 확인된 것: ID 경로 기본값(`<하위 메뉴 ID>><항목 ID>`)이 드롭인에서 이기고 실제 GRUB에서 6.17로 부팅한다 · `next_entry`는 한 번 쓰이고 빈 값으로 남는다(우분투의 `grub-reboot`과 같은 변수) · ID가 메뉴에 없으면 첫 항목(가장 새 커널)으로 간다 · 표준 입력 실행에서 스크립트를 삼키는 명령이 없다 · 실제 `update-grub` · `grub-editenv` · mawk와의 결합(status → pin → trial → 1회 부팅 흉내 → unpin)이 정상이다. 리뷰 실험물은 `.superpowers/t048/kernel-review/`(gitignore — `out/*.log` · `docker/*.sh` · `src/`에 소스 원문).

| # | 심각도 | 내용 | 조치(내일) |
|---|---|---|---|
| 1 | medium | 다른 `update-grub`(커널 · grub 패키지 훅 · 수동 apt)과 겹치면 **메뉴 항목이 0개인 grub.cfg**가 남는다(grub-mkconfig에 잠금이 없다). 도구는 FAIL · INCONSISTENT로 알리지만 그 상태로 재부팅하면 부팅 불가 | 쓰기 전 가드: `dpkg` · `apt` · `unattended-upgr` · `grub-mkconfig`가 돌고 있거나 `/boot/grub/grub.cfg.new`가 있으면 거부. 쓰기 단계 직전마다 apt 활동 없음 확인. 수동 복구(`sudo update-grub` → `status`)를 실행표에 |
| 2 | medium | §8.6의 "initrd 없이 시도 → 실패하면 initrd로 재시도"는 고정 · 시험 경로에서 일어나지 않는다. `set partuuid=`가 없으면 그 논리는 죽은 코드이고, 있으면 **하위 메뉴 안의 항목은 항상 initrd 없이 부팅하고 재시도가 없다**(변수가 하위 메뉴 컨텍스트에 export되지 않는다) — 그 경우 시험 결과가 평소 부팅(최상위 항목)과 같지 않다 | K0 관문에 `grep -c 'set partuuid=' /boot/grub/grub.cfg` = 0 추가 · `status`도 한 줄로 낸다. 0이 아니면 진행 전에 다시 판단. §8.6 둘째 항목은 이 내용으로 읽는다 |
| 3 | medium | 쓰기 도중 SSH가 끊기면 bash가 다음 출력에서 죽어 과도 상태가 남고(전부 부팅 가능), 그 상태에서는 도구의 쓰기 명령이 모두 거부한다 | 머리에 `trap '' HUP PIPE`(끝까지 · 실패면 되돌리기까지 실행됨을 리뷰어가 확인) · `pin`이 "같은 값의 고정 파일 + 옛 grub.cfg"에서 이어 끝내게 하거나 수동 복구를 실행표에 |
| 4 | medium | 절차: 노드 A의 고정(A0)이 B3 뒤다 — B 단계 동안, 그리고 B3 실패 분기에서는 계속, A의 다음 재부팅이 7.0이다 | **A0를 K0 직후(B0와 함께)로 옮긴다.** B3 실패 분기: 두 노드 모두 고정 유지 · 7.0 처리는 따로 결정 |
| 5 | medium | 절차: 노드 A의 복구 경로는 A1이 실패할 때 처음 실행된다 — "값이 B와 같다"뿐이고 동일성 관문이 없다. A의 6.17 initrd가 마지막 부팅 뒤에 다시 만들어졌다면 부팅해 본 적 없는 initrd다 | A0 관문에 읽기 전용 대조(아래 명령 2 · 3). initrd가 부팅 뒤에 바뀌었으면 A를 먼저 그냥 재부팅할지 사용자에게 묻는다 |
| 6 | low | `trial`과 `status`가 복구용(고정된) 커널의 파일 유무와 항목 종류를 다시 보지 않는다 | `trial` · 판정에서 고정 값 = 실행 중 커널의 `-advanced-` 경로 + 그 커널 파일 확인 |
| 7 | low | 시험 커널로 도는 동안 더 새 커널이 설치되면 고정된 6.17이 자동 제거될 수 있다(`Remove-Unused-Kernel-Packages`) → GRUB은 조용히 가장 새 커널로 간다 | **F(고정 해제)를 같은 날 끝낸다**(apt 일일 실행 전). 날을 넘기면 `status` 재확인. 관문에 `apt list --upgradable` · `apt-get -s autoremove` |
| 8 | low | "패닉이면 10초 뒤 저절로"는 `kernel.panic=10`이 적용된 뒤의 패닉에만 맞을 가능성이 크다 — 초기 부팅 패닉 · GRUB 단계 실패는 자동 재부팅이 없다 | A1 전 관문: 운영자가 OCI 강제 재시작을 바로 실행할 수 있는 상태. §8.3의 그 문장은 이 한계와 함께 읽는다 |
| 9 | low | `status`의 "next boot"가 grubenv의 `initrdfail` · `prev_entry`를 보지 않는다(#2의 partuuid 경우에만 생긴다) | 두 변수가 있으면 INCONSISTENT |
| 10 | low | 테스트의 빈 곳 — 변이 여섯 생존(unpin 사후 검증 · unset 뒤 읽어 보기 · 고정 파일의 모르는 줄 · ASCII 치환 · `trial`/`unpin`의 root 가드) · 가짜 부팅이 grubenv를 "변수 없음"으로 만든다(실제는 `next_entry=` 빈 값) | 케이스 추가 |
| 11 | info | 죽은 실행의 잔여 파일을 `status`가 말하지 않는다 · 전송이 마지막 줄 앞에서 잘리면 exit 0 · 출력 없음 → **RESULT 줄이 없으면 실패**로 본다 | 절차에 명시 |

실행표 문구 정정: B3의 "`next_entry` 없음"은 실제로 `INFO grubenv: next_entry=`(빈 값)로 보인다 — 기준은 `INFO next boot: 6.17… (default)`.

**재부팅 전에 두 노드에서 읽기 전용으로 확인할 것(리뷰어 제안 — K0에 넣는다)**

```bash
# 1) initrd 없는 부팅 폴백이 켜져 있는가 — 기대: 0, 항목은 linux + initrd
sudo grep -c 'set partuuid=' /boot/grub/grub.cfg
sudo grep -nE '^\s*(linux|initrd)\s|panic=-1|^\s*initrdfail$' /boot/grub/grub.cfg | head -20
ls -la /etc/default/grub.d/ /etc/grub.d/
grep -rnE 'GRUB_(FORCE_PARTUUID|DEFAULT|SAVEDEFAULT|DISABLE_SUBMENU|TOP_LEVEL|FLAVOUR_ORDER)' /etc/default/grub /etc/default/grub.d/
cat /proc/cmdline
# 2) 두 노드의 부팅 구성이 같은가
sudo sha256sum /boot/grub/grub.cfg /boot/efi/EFI/ubuntu/grub.cfg /boot/efi/EFI/ubuntu/grubaa64.efi /boot/vmlinuz-6.17.0-1020-oracle /boot/vmlinuz-7.0.0-1012-oracle
dpkg-query -W -f '${db:Status-Abbrev} ${Package} ${Version}\n' 'grub*' 'shim*' 'linux-image-*' 'linux-modules-*' initramfs-tools
# 3) 복구용 initrd가 이번 부팅에 쓰인 그 파일인가(mtime < 부팅 시각이면 그렇다)
uptime -s; stat -c '%y %s %n' /boot/initrd.img-* /boot/vmlinuz-*
grep -hE ' (install|upgrade) (grub|shim|linux-image|linux-modules|initramfs-tools)' /var/log/dpkg.log /var/log/dpkg.log.1 2>/dev/null | tail -20
lsinitramfs /boot/initrd.img-7.0.0-1012-oracle | wc -l
# 4) GRUB이 grubenv를 쓸 수 있는 모양인가, 비어 있는가
sudo grub-editenv /boot/grub/grubenv list; stat -c '%s bytes, %b blocks' /boot/grub/grubenv; sudo filefrag -v /boot/grub/grubenv | tail -n 3
findmnt -no SOURCE,FSTYPE,OPTIONS /boot; df -h /boot
systemctl is-enabled grub-common.service grub-initrd-fallback.service
# 5) 패닉 · 멈춤 때 자동 재부팅이 되는 구간
sysctl kernel.panic kernel.panic_on_oops; grep -rn 'kernel.panic' /etc/sysctl.conf /etc/sysctl.d /usr/lib/sysctl.d 2>/dev/null
grep CONFIG_PANIC_TIMEOUT /boot/config-6.17.0-1020-oracle /boot/config-7.0.0-1012-oracle
# 6) 패키지 작업이 끼어들 여지(쓰기 단계 직전마다)
pgrep -a 'apt|dpkg|unattended-upgr|grub-mkconfig' || echo none
systemctl list-timers 'apt-daily*' --all --no-pager
apt list --upgradable 2>/dev/null | grep -E '^linux-|^grub|^shim' || echo "no kernel/grub upgrades pending"
apt-get -s autoremove 2>/dev/null | grep -E '^Remv linux-' || echo "no kernel autoremove pending"
ls -la /boot/grub/grub.cfg.new 2>/dev/null || echo "no grub.cfg.new"
```

## 9. 재개 지점(2026-10-01 19:00 KST — 사용자가 여기서 멈췄다)

- **노드 · 클러스터**: 아무것도 바꾸지 않았다. 두 노드 모두 실행 중 6.17.0-1020 · 대기 중 7.0.0-1012 · GRUB 기본값 0 · 고정 없음. gitops Environment의 관리자 우회는 꺼졌다(T047의 열린 조치 닫힘).
- **끝난 것**: 백업 검증(단계 6 — 실제 저장소 13항목 통과 · 출력 사본 `.superpowers/t048/restore/real-run-2026-10-01.txt`) · 사전 관찰 · SC-001 근거 결정(안 A) · 커널 처리 결정(§8.2).
- **작업 트리에 커밋 전으로 남은 것**(리뷰 반영 전이라 커밋하지 않았다 — 파일 이름으로 스테이징할 것):
  - 재부팅 하네스 수정 3 · 4 · 5: `tests/platform/reboot.tests.ps1` · `tests/scripts/reboot-tests.tests.ps1`(빌더 전체 실행 245/0 · 그 뒤 컨트롤러가 S1의 arm 제한을 16초로 넓힘 — S1 3회 통과 · 대상 케이스 독립 실행 통과). 재리뷰 3(수정 3–5 집중 — 기준점 논리의 잘못된 PASS/FAIL · 기록의 충분성 · 테스트)은 **코드 읽기까지만** 하고 멈췄다: 잠정 판정 APPROVED_WITH_FIXES · 실행 재현 · 테스트 파일 변경분 검토 · 변이는 미완(§9.1). 중간 보고 원문과 이어서 할 계획(시나리오 · 변이 · 명령)은 `.superpowers/t048/harness-review/re3/REPORT.md`.
  - 커널 도구: `infra/bootstrap/kernel-trial.sh` · `tests/infra/kernel-trial.tests.ps1` · `tests/run-all.ps1`(항목 `kernel-trial`) — 빌더 85/0 · 컨트롤러 독립 실행 85/0 · 리뷰 §8.8(보고 원문 `.superpowers/t048/kernel-review/REPORT.md` — 근거 로그 `out/` · 다시 돌릴 명령 · 생존 변이 표가 거기 있다).
- **내일의 순서**:
  1. 하네스 재리뷰 3을 이어서 끝낸다(보고 원문 §5 — 가짜 시나리오 재현 · 전체 테스트 · 변이 · 테스트 검토) → §9.1의 발견 반영 → 전체 단위 테스트 1회 → 커밋.
  2. `kernel-trial.sh` 수정(§8.8 #1 · #2 · #3 · #6 · #9 · #10) → 모의 하네스 → 커밋. 절차 수정(#4 A0를 앞으로 · #5 A의 동일성 대조 · #7 같은 날 끝내기 · #8 강제 재시작 준비 · #11 RESULT 줄)은 §8.4 · §8.7에 반영.
  3. 운영자 전제: 터널 리스너 · 조회 토큰(8시간) 재발급 · 필요하면 `svc-verify` 세션. 이 PC에서 다른 무거운 작업을 멈추고 조회 지연을 다시 잰다.
  4. K0(두 노드 `status` + 위 읽기 전용 확인) → 두 노드 고정(B0 · A0) → 시험 파드 → B2(그냥 재부팅) → B3(새 커널 1회) → A 진행 조건 → A1(T048 측정 — 하네스를 먼저 켜고, 하네스의 마지막 기준점 줄이 `armed:`일 때만 재부팅 신호를 준다 — §9.1 A) → F(고정 해제 · 시험 파드 삭제). 단계마다 사용자 재확인.
  5. 기록: 런북 §3 T048 절 · §3 요약(전체 순서 · 시간 · 시크릿 취급) · §6에 OS 패치 재부팅 절차 · `report.md`에 올릴 것(SC-001 한계 · 커널 전환) · 학습 로그 · 모노레포 run-all 전체 1회 · 체크(54/119).
- **에이전트 도구(gitignore)**: `.superpowers/t048/obs/`(`snapshot.ps1` · `observe.ps1` · `run-reboot-harness.ps1` · `pf-timing.ps1` · 기준값 `baseline.txt`(bootID는 재부팅 전까지 유효)) · `.superpowers/t048/canary/kernel-canary.yaml` · 지시서 `.superpowers/t048/prompts/`.
- **리뷰 보고 파일**: 두 리뷰어 모두 보고 파일을 직접 쓰지 못했다(하위 에이전트는 결과를 글로 돌려주게 돼 있다) — 돌려받은 글을 컨트롤러가 그대로 저장했다. 다음부터 리뷰 지시서는 "보고는 글로 돌려준다"로 쓴다.
- **커널 도구 리뷰어가 확인하지 못한 것**: 실제 arm64 UEFI GRUB의 `save_env`와 숨김 메뉴 동작(같은 소스 판의 x86_64 에뮬레이션으로만 확인) — 노드 B의 B2(고정 실증) · B3(1회용 선택 실증)가 실기 확인이다.

### 9.1 하네스 재리뷰 3 — 중간 결과(코드 읽기와 손 계산 · 가짜 시나리오 재현 전)

리뷰어는 수정 지시서 2–5와 하네스 본체 전문을 읽었고, 테스트 파일의 변경분(새 케이스 S34–S41 · 가짜의 수립 지연)은 보지 못했으며 아무것도 실행하지 않았다. 아래 수치는 "관측마다 독립 · 관측당 실패율 23–31%(호출당 1/6–1/8 × 호출 둘)" 가정의 손 계산이다.

| # | 심각도(잠정) | 내용 | 조치(내일 — 재현 뒤 확정) |
|---|---|---|---|
| A | high · 잘못된 FAIL | **굳은 기준점이 재부팅 전에 오래 남는다.** 연속 횟수는 일시 실패가 낄 때마다 0으로 돌아간다 — 머리 주석의 "최대 두 라운드 · 세 라운드 이내"는 실패가 한 번뿐일 때만 맞다. 조회가 가끔 실패하는 실제 경로에서는 다시 armed가 되기까지 평균 5–6.5 관측(80–130초)이고 대기 시간의 55–65%가 굳은 상태다. 그 상태에서 재부팅이 시작되면 모든 경과 초에 (재부팅 시작 − 기준점)이 더해진다. 예행의 "1분 제한이 139.6초에 판정"과 맞는다 | **절차: 마지막 기준점 줄이 `armed:`일 때만 재부팅 신호를 준다**(그 전에 `zero point fixed`가 나오면 다음 `armed:`까지 기다린다). 코드: armed 중의 호출 실패는 그 자리에서 한 번 더 시도하고, 다시 실패할 때만 기준점을 굳힌다 · 주석 수정 |
| B | medium · 잘못된 FAIL | 굳은 상태에서는 옛 부팅이 살아 있어도 300초 마감이 굳은 기준점에서 흐른다 — 연속 세 번이 300초 안에 안 나오면 **재부팅 전에** `FAIL reboot-0 … not met within 300s`다(arm 제한과 무관 · 첫 관측이 실패해도 같은 상태로 시작한다). 30분 대기면 누적 10–40% | A의 재시도로 드물게 만든다 · 이 경우의 FAIL 문구를 구분한다 · 런북: 재부팅 명령 전의 이 FAIL은 하네스를 다시 켠다 |
| C | low–medium · 오진 | 재부팅 뒤 kubelet이 끝내 status를 못 올리면 낡은 옛 bootID가 계속 보여 다시 armed가 되고, 300초가 아니라 arm 제한(30분)에서 `no reboot observed`로 끝난다(판정은 FAIL — 원인 표시가 틀린다) | "옛 부팅" 판정에 Ready=True를 더한다(낡은 status가 Unknown으로 바뀌는 시점은 실측 전) · 런북: 재부팅 명령 뒤에 `armed:`가 다시 나오면 노드 A의 kubelet을 본다 |
| D | low · 잘못된 PASS(하네스 머리 주석에 적어 둔 잔여) | 낡은 bootID가 연속 세 관측을 채우면 기준점이 재부팅 뒤로 간다(실제 경로에서 그 창이 30–50초 이상이어야 한다) | 기록 규칙: `zero point (UTC)`가 재부팅 명령 시각보다 뒤이면 그 차이를 각 PASS의 초에 더해 다시 판정한다 |
| E | low · 기록 | PASS 줄에는 기준점 기준의 정수 초만 있고 절대 시각이 없다 | `met` 줄이나 PASS 줄에 UTC와 관측 시작 초를 항상 찍는다 |
| F | info | arm 제한은 기준점이 움직이는 관측에서만 판정된다(굳은 상태에서는 판정되지 않는다 — 설계대로이고 판정을 뒤집지 않는다) | 출력과 주석에 적는다 |
| G | low | 마감 1초 전 논리는 라운드의 첫 조건에만 듣는다 — 뒤 조건은 앞 조건의 관측 시간만큼 늦게 시작해, 실질 마감이 최악 한 주기(40–70초)만큼 앞이다. 두 조건 이상이 마지막 1분에 걸릴 때만 영향 | 런북: 복구가 약 230초를 넘기면 판정이 흔들릴 수 있다 · 또는 마감이 가까운 라운드는 짧은 조회부터 |
| H | info | 위치 인자가 셋이 됐다 — 남는 정수 토큰이 `-ArmTimeoutMinutes`로 묶인다(pre-4 줄에 드러난다) | 조치 없음 |

읽기 기준의 답: 새 잘못된 PASS 경로는 D 말고 찾지 못했다 · reboot-4의 마감은 기준점 이동의 영향을 받지 않는다 · 기록은 다시 계산할 수 있다 — 명령 기준 경과 = (`zero point (UTC)` − 운영자의 명령 시각) + 각 PASS의 초, 기준점이 명령보다 앞이면 하네스의 PASS는 명령 기준으로도 PASS다.

## 10. 2일차(2026-10-02) — 리뷰 반영과 확정 절차

### 10.1 순서를 바꾼 것

§9의 1번(재리뷰 3을 마저 끝낸 뒤 수정)을 **"빌더가 발견을 가짜 시나리오로 먼저 재현(RED)하고 고친다 → 수정 3–6을 한 번에 독립 리뷰"** 로 바꿨다 — 재리뷰 3의 발견은 코드 읽기였고, 재현은 어차피 테스트로 남겨야 하며, 리뷰 회차가 하나 줄어든다. 커널 도구 수정과 하네스 수정은 파일이 겹치지 않아 빌더 둘이 나란히 했다(지시서 `kernel-trial-fix.md` · `harness-fix6.md`).

### 10.2 재부팅 하네스 — 수정 6(빌더 결과)

- **재현**: §9.1의 A · B · C가 셋 다 수정 전 하네스에서 재현됐다. A — 신원 호출 한 번의 시간 초과로 기준점이 굳고, 이어진 한 번의 실패로 연속 횟수가 0으로 돌아가 기준점이 불통까지 그 자리에 머물렀다. B — 재부팅이 없었는데 설명 없이 `not met within …`. C — Ready=Unknown인 낡은 관측이 옛 부팅으로 세어져 마감이 아니라 arm 제한에서 끝났다.
- **수정**: A — 직전 reboot-0 관측이 옛 부팅이었을 때(armed, 또는 굳은 뒤 연속 횟수 ≥ 1)만, 도달 실패(kubectl 종료 코드 ≠ 0 · 401 아님)한 호출을 그 자리에서 한 번 다시 한다(신원 · 노드 조회 각각). 재시도한 관측의 "시작"은 다시 한 호출의 시작이고, 기준점 · 충족의 마감 판정 · UTC 표기가 같은 시각을 쓴다(마감 뒤에 시작한 재시도가 모은 증거로는 통과하지 못한다). B — 굳은 채 만료된 FAIL 줄에 "재부팅은 관측되지 않았다 · 하네스를 다시 켠다"를 덧붙인다. C — 옛 부팅 = 기준 bootID **그리고 Ready=True**. E — met · PASS/FAIL 줄에 관측의 시작 · 끝 UTC(밀리초). F · G — 문구와 주석.
- **검증**: 단위 테스트 325 단언 실패 0(12분 17초 — 새 케이스 12개) · 변이 열(a–j) 전부 검출 · 평상시 모드와 `-Baseline` 출력은 `56301c3`과 글자 단위로 같다. 컨트롤러 독립 실행(새 케이스 S42–S48 · S53) 58/0.
- **빌더가 남긴 우려**: 재시도가 기존 잔여(낡은 bootID로 기준점이 재부팅 뒤로 가는 경우)의 창을 조금 넓힌다 — armed 상태에서 **불통 전체가 "직전 옛 부팅 관측"과 "재시도" 사이에 들어갈 때**(불통이 실패한 호출 하나의 길이, 최악 30초보다 짧아야 한다). 노드 재부팅의 불통이 그보다 짧은지는 실측 전이다 → 기록 규칙(§10.5 R6)으로 덮는다: `zero point (UTC)`가 재부팅 명령 시각보다 뒤이면 그 차이를 더해 다시 판정한다.
- **독립 리뷰(수정 3–6 · 지시서 `harness-review4.md`) — APPROVED_WITH_FIXES**: 판정을 뒤집는 결함은 찾지 못했다(시나리오 실행 49건 · 무작위 실패를 넣은 장시간 실행 12회는 재부팅 없이 전부 FAIL · 전체 325/0 · 변이 43개 가운데 36개 검출 · 6개 · 12개 동시 실행에서 흔들리는 단언 없음 · 평상시와 `-Baseline` 출력은 `56301c3`과 같음). 코드 수정은 필수가 아니고, 조건은 절차 · 기록 규칙을 오늘 절차에 넣는 것이다(§10.4 R8).
  - 남는 잔여 ① **굳은 기준점(잘못된 FAIL 쪽)**: 재시도가 막는 것은 한 번 실패뿐이다. 호출과 재시도가 둘 다 실패하면 기준점이 굳고, 그 상태에서 재부팅이 시작되면 "굳은 기준점 + 300초"에 reboot-0이 만료되어 관측이 멈춘다(복구 증거가 남지 않는다). 계산(호출당 1/7 실패 · 30분 대기): 굳은 시간이 수정 5의 58.8%에서 11.8%(독립 가정) · 25–30%(실패가 묶여 올 때)로 줄었다. **마지막 기준점 줄이 `armed:`인 순간에만 재부팅하면** 60초 넘게 깎이는 경우가 모든 가정에서 0.00%다.
  - 남는 잔여 ② **낡은 status로 기준점이 재부팅 뒤로 가는 경로(잘못된 PASS 쪽)**: 낡은 bootID(Ready=True) 창이 연속 세 관측을 채우는 경우(기본 간격과 실제 지연에서 창이 약 43–63초 이상) · armed에서 재시도가 낡은 status를 보는 경우(불통 전체가 약 40초 안에 끝나야 한다 — 수정 6이 넓힌 창이고, 그 뒤 낡은 관측마다 기준점이 더 간다) · 낡은 창 안에서 하네스를 시작한 경우. 하네스 출력만으로는 확정하지 못한다 — **운영자의 명령 시각과 `zero point (UTC)`의 대조**가 충분한 규칙이다(`rejudge.ps1`이 리뷰어의 재현 로그에서 "기준점이 명령 119초 뒤"를 잡고 명령 기준으로 다시 셌다).
  - 그 밖: 시험용 손잡이(폴링 간격)가 연속 세 번의 보호를 약하게 한다(→ 실행 전 환경 변수 확인) · 마감 안에 **시작한** 관측이면 통과라 복구가 마감 뒤에 끝나도 PASS가 난다(Vault 확인 최대 약 45초 — 그 PASS 줄에는 `observation started at`이 찍힌다) · 같은 라운드에서 앞 조건의 관측이 길면 뒤 조건이 late가 된다 · 못 잡는 변이 여섯(테스트 보강 — 측정과 무관, 뒤에 한다).
  - 리뷰가 짚은 머리 주석 한 곳("느슨해지는 폭은 그 사이 길이 이내" — 틀렸다)을 정정했다.
- **커밋 `1cb32f3`**(수정 3–6 · run-all 주석의 소요 시간 12분). 전체 단위 테스트를 줄이는 안(케이스 묶음 병렬 실행으로 200–250초 추정)은 뒤로 미룬다.

### 10.3 커널 도구 — 리뷰 반영(빌더 결과)

- **반영**: #1 쓰기 전과 `update-grub` 직전에 패키지 작업(`dpkg` · `apt` · `apt-get` · `unattended-upgr` · `grub-mkconfig` · `update-grub` 프로세스 · `grub.cfg.new`)을 보고 거부 · #2 `set partuuid=`가 있으면 `status` FAIL, `pin` · `trial` 거부 · #3 `trap '' HUP PIPE`(출력이 닫혀도 쓰기와 되돌리기가 끝까지 간다) + 과도 상태의 수동 복구 한 줄(`sudo update-grub` 한 번 → `status`) + 잔여 파일 표시 · #6 `trial`은 고정 값이 "`pin`이 지금 쓸 값"과 같고 복구용 커널 파일이 비어 있지 않을 때만 · #9 grubenv의 `initrdfail` · `prev_entry`에 값이 있으면 INCONSISTENT · #10 생존 변이 여섯 검출 · #11 shellcheck가 끝까지 파싱.
- **검증**: 모의 하네스 160 단언 실패 0(약 2.5분) · 변이 39개 전부 검출 · 컨트롤러 독립 실행 160/0. 실제 도구(우분투 24.04 컨테이너 · grub 2.12-1ubuntu7.3 · 리눅스 bash 5.2)로: 전 과정(status → pin → pin 멱등 → trial → 부팅 흉내 → unpin) · 출력을 닫은 채 실행해도 pin이 끝까지 끝남 · `dpkg` / `grub-mkconfig` 이름의 프로세스가 있으면 쓰기 0으로 거부.
- **지시서 밖의 판정(빌더)**: 우분투는 `unattended-upgrades.service`가 종료 대기 도우미(`unattended-upgrade-shutdown --wait-for-signal`)를 늘 띄워 두고, 그 프로세스 이름이 `unattended-upgr`라 그대로면 쓰기 명령이 **항상** 거부된다(컨테이너 실측). 명령 줄이 정확히 그 도우미일 때만 작업에서 빼고 `INFO package activity ignored` 줄로 드러낸다 — 명령 줄이 다르면 거부한다. 노드의 명령 줄이 같은지는 K0의 읽기 전용 확인이 보여 준다.
- **가드로 닫을 수 없는 창**: 우리 `update-grub`이 시작된 **뒤에** 패키지 훅의 `update-grub`이 시작되면 겹친다 — 메뉴 항목 0개의 grub.cfg가 남고 도구는 FAIL · INCONSISTENT · 수동 복구 줄을 낸다(실제 도구로 재현 · 적힌 대로 `sudo update-grub` 한 번이면 돌아온다). 절차 규칙으로 덮는다(§10.5 R2 · R3).
- **재리뷰(어제의 리뷰어가 이어서) — APPROVED_WITH_FIXES**: 어제의 발견 일곱은 전부 닫혔고(실제 도구 · 실제 `pgrep`으로 다시 실행), 수정이 만든 "말하지 않는 부팅 불가" 경로는 찾지 못했다. 출력 실패가 흐름을 바꾸지 않는다(출력 함수가 k번째부터 실패하도록 계측한 사본 · 닫힌 파이프 · 닫힌 fd로 쓰기 · 되돌리기 경로 12가지 — 398회 비교에서 끝 상태 · 쓰기 호출 순서 · 종료 코드 차이 0). 종료 대기 도우미 예외는 안전하다(패키지 소스: 도우미는 종료 신호만 기다리고 `InstallOnShutdown` 기본값 false · 실제 실행 모양의 명령 줄은 거부). 변이 20개 가운데 19개 검출. 남은 것(낮은 등급 — **오늘의 노드 작업은 이 판 그대로 쓰고 §10.4의 규칙으로 덮는다. 노드 작업 뒤에 반영한다**):
  - ① 닫을 수 없는 창의 한 순서에서 도구가 `RESULT: OK`를 낸다 — 훅의 `update-grub`이 우리 것보다 늦게 시작해 쓰다 멈춘 파일이 grub.cfg로 설치되면 꼬리 섹션 넷이 빠진다(부팅과 기본값은 정상 · `status`도 OK · 훅은 exit 1). 조치: `update-grub` 직후에 패키지 프로세스를 한 번 더 보고 FAIL(리뷰어가 사본에서 두 줄로 확인).
  - ② 직전 재확인에서 되돌린 뒤 "nothing changed"라고 하지만, 이미 고정 파일을 읽은 훅이 끝나면서 기본값을 고정 ID로 쓸 수 있다(부팅은 6.17이라 안전 · 다음 `status`가 INCONSISTENT로 잡는다). 조치: undo 줄에 "패키지 작업이 끝난 뒤 status를 다시 본다".
  - ③ 수동 복구 줄이 없는 거부 상태 둘(메뉴 0개 + 기본값 0 + 고정 없음 · grubenv `initrdfail`/`prev_entry`) — 문구 보강.
  - ④ 도우미 예외의 "명령 줄이 정확히 같을 때만"을 지키는 테스트가 없다(부분 문자열로 넓힌 변이 생존 · 스크립트 동작은 맞다) — 케이스 하나.
- **커밋 `540998d`**(스크립트 sha256 `29155c4a…dc37` — 리뷰한 판 그대로 · 테스트의 픽스처 식별자만 가짜 값으로 바꿔 전체 160/0 재확인 · run-all 항목 `kernel-trial`).

### 10.4 확정 절차의 규칙(§8.4 · §8.7에 더한다 — 두 리뷰의 권고)

- **R1 K0**: 두 노드의 읽기 전용 확인(§8.8의 블록)과 `status`. `RESULT: OK status` · `OK initrdless-boot fallback: off` · `INFO package activity: none` · `INFO leftovers: none` · grubenv 비어 있음 · 두 커널 `menu-entry-ids=1` · 7.0의 `missing-loaded-modules=0`. `INFO package activity ignored: unattended-upgr(PID)` 줄은 정상이다(종료 대기 도우미). 한가한데 `unattended-upgr(PID)`가 작업으로 나오면 멈춘다(노드의 명령 줄이 예외와 다르다). `initrdless-boot fallback: on`이면 계획 전체를 멈춘다. 노드 A의 6.17 initrd가 마지막 부팅 **뒤에** 다시 만들어졌으면(mtime > 부팅 시각) A를 먼저 그냥 재부팅할지 사용자에게 묻는다(§8.8 #5).
- **R2 쓰기 단계(pin · trial · unpin) 직전**: apt 타이머의 다음 실행 시각을 본다 — 06:00–07:10 KST에는 하지 않는다. 절차 동안 노드에서 apt를 손으로 돌리지 않는다.
- **R3 쓰기 단계가 FAIL · INCONSISTENT를 내거나 `RESULT:` 줄이 없으면 재부팅하지 않는다.** 다시 접속해 `status` → 패키지 프로세스가 없을 때 `sudo update-grub` 한 번 → `status`가 `RESULT: OK`로 기대 상태를 보일 때만 그 단계를 다시 한다.
- **R4 재부팅 명령 직전마다 `status`를 한 번 더** 돌린다: `RESULT: OK` · `package activity: none` · `leftovers: none` · 기대한 `next boot` · `later boots` · `pin` 줄.
- **R5** 쓰기 단계에서 패키지 작업이 한 번이라도 보였으면, 그 뒤의 시도가 OK여도 작업이 끝난 다음 `sudo update-grub` → `status` → `dpkg --audit`(빈 출력)를 본다.
- **R6** 세션이 끊기면 명령은 노드에서 끝까지 돈다 — 30초쯤 뒤 다시 접속해 `status`부터 본다(`package activity: update-grub/grub-mkconfig`가 보이면 우리 실행이 아직 도는 것이다).
- **R7 순서와 준비**: 두 노드의 고정을 K0 직후에 한다(B → A — §8.8 #4). B3이 실패하면 두 노드 모두 고정을 유지하고 7.0 처리는 따로 정한다. F(고정 해제)는 같은 날 끝낸다 — 날을 넘기면 두 노드 `status`부터 다시 본다. B3 · A1 전에 운영자가 OCI 콘솔에서 인스턴스 강제 재시작을 바로 할 수 있는 상태여야 한다(초기 부팅 패닉 · GRUB 단계 실패는 저절로 재부팅되지 않는다). B3 뒤의 `INFO grubenv: next_entry=`(빈 값)는 정상이다 — 기준은 `INFO next boot: 6.17… (default)`.
- **스크립트를 넘기는 방법(§8.7의 `KT`를 바꾼다)**: 작업 트리의 파일이 아니라 **커밋된 blob**을 그대로 넘긴다 — `git -C D:\code\joshuatech_ver2 cat-file blob 42b7e49ab5c17deb2d02a1dd131a23a8aff8f7d2 | ssh <노드> "sudo bash -s -- <하위 명령>"`. blob ID가 곧 내용의 무결성이고(리뷰한 판 `29155c4a…` — 커밋 `540998d`), 절차 도중 작업 트리가 바뀌어도 영향을 받지 않는다. PowerShell 7.4 이상의 네이티브 → 네이티브 파이프는 바이트를 그대로 넘긴다(7.6.6에서 sha256 일치 확인 · `Get-Content -Raw | …`는 끝에 CRLF 한 줄을 덧붙인다 — 스크립트가 견디지만 쓰지 않는다).
- **R8 측정 재부팅(A1)의 하네스**(하네스 리뷰의 규칙 아홉 — 래퍼 `.superpowers/t048/obs/run-reboot-harness.ps1`이 1 · 6의 기계적인 부분을 검사한다):
  1. 시작 전 `REBOOT_TESTS_*` 환경 변수가 없다(래퍼가 있으면 거부한다). 로그에 `note: REBOOT_TESTS_` 줄이 있거나 polling 줄이 기본값(간격 10초 · 마감 300초 · reboot-2 통과 + 300초)이 아니면 증거로 쓰지 않는다.
  2. 하네스는 재부팅 전에 켠다(`trial` 뒤 · 재부팅 직전). 첫 `armed:` 줄을 본다. 명령 전에 `zero point = script start`나 `reboot-0 met`이 나오면 중단한다.
  3. **재부팅 신호는 마지막 기준점 줄이 `armed:`일 때만 준다**(그 뒤에 `zero point fixed at`이 없어야 한다). 굳어 있으면 `note: … 3 times in a row`와 `armed:`까지 기다린다(평균 1–2분). 켠 뒤 10분 안에 준다.
  4. 재부팅 블록이 같은 PC의 시계로 명령 시각(UTC)을 출력하고 파일로 남긴다.
  5. 명령 **전에** 하네스가 FAIL로 끝나면(`restart the harness` · `no reboot observed` · `not met within 300s`) 재부팅하지 않고 다시 켠다.
  6. **수용 판정 = 하네스 exit 0 + `rejudge.ps1` PASS(명령 시각 기준) + 요약 줄이 `(last observation of the old boot)`.** 기록하는 초는 rejudge의 명령 기준 값이다. `zero point (UTC)`가 명령 시각보다 뒤면 하네스의 초는 쓰지 않는다. rejudge는 하네스의 PASS를 FAIL로 뒤집을 수는 있어도 FAIL을 PASS로 만들지 않는다.
  7. PASS 줄에 `observation started at`이 있으면(마감 안에 시작해 마감을 넘겨 끝난 관측) 그 조건의 증거 시각은 관측의 끝(UTC)으로 적는다.
  8. FAIL이 `met late`이거나 (명령 − 기준점)이 60초를 넘으면 하네스 판정은 그대로 두고, 관측 UTC와 `observe.ps1` 표본으로 명령 기준 경과를 따로 적어 사용자 판단에 올린다.
  9. 측정 동안 이 PC에서 다른 작업을 돌리지 않는다(빌더 · 리뷰어 · 테스트 없음).
- 리뷰가 실측 전이라고 남긴 것(A1이 처음 잰다): 낡은 bootID(Ready=True) 창의 길이 · Ready가 Unknown이 되는 시점 · 종료 직전 NotReady 여부 · 불통의 길이 · 불통 중 kubectl의 문구와 소요 시간 · **API 복귀 직후 401이 두 관측 이상 이어지는가**(이어지면 `56301c3`부터의 규칙으로 fatal이다 — 오늘 측정의 위험으로 적어 둔다: 그 경우 하네스는 FAIL로 끝나고, `observe.ps1` 표본으로 복구 시각을 따로 적는다).

### 10.5 K0 결과 · 두 노드 고정(2026-10-02 14:48–15:02 KST)

출력 사본은 `.superpowers/t048/k0/`(읽기 전용 확인 · `status` · 모듈 확인 · `pin` — 노드마다).

- **읽기 전용 확인(두 노드 동일)**: `set partuuid=` 0줄 · 메뉴 항목마다 `linux` + `initrd` · 드롭인은 `50-cloudimg-settings.cfg`뿐 · `GRUB_DEFAULT=0` · grubenv 변수 없음(1024바이트 · 1 extent · `/boot`는 ext4 rw) · grub 2.12-1ubuntu7.3(리뷰어의 컨테이너와 같은 판) · grub.cfg · EFI 바이너리 · 두 커널 이미지의 sha256이 두 노드에서 같다(initrd는 노드마다 다르다 — 정상) · **지금 커널(6.17)의 initrd는 마지막 부팅 전에 쓰인 그 파일**(A 16:18:53 < 16:24:09 · B 19:05:22 < 19:05:59 — §8.8 #5 충족) · 패키지 작업 없음(종료 대기 도우미의 명령 줄 = 도구의 예외와 글자 그대로 일치) · `grub.cfg.new` 없음 · 커널 autoremove 대기 없음.
- **apt**: 타이머의 다음 실행은 A 10-03 00:14(목록 갱신) · 06:28(설치), B 05:01 · 06:53. **`linux-image-oracle 7.0.0-1013`이 이미 올라와 있다**(noble-updates — noble-security로 복사되면 그다음 설치 실행이 받는다).
- **패닉**: `kernel.panic=10` · `panic_on_oops=1`은 sysctl 파일에 없다 — kubelet이 시작하면서 쓰는 값이다(소스로 확인). 두 커널 모두 `CONFIG_PANIC_TIMEOUT=0` → **K3s가 뜨기 전의 패닉 · 멈춤은 저절로 재부팅되지 않는다**(§8.3의 "패닉이면 10초 뒤 저절로"는 K3s가 뜬 뒤에만 맞다 — OCI 강제 재시작이 유일한 수단).
- **`status`**: 두 노드 `RESULT: OK` · 두 커널 `menu-entry-ids=1` · partuuid off · 잔여 없음. **단, 7.0의 `missing-loaded-modules=4`**(`libcurve25519_generic` · `blake2b_generic` · `polyval_ce` · `aes_ce_cipher`) — R1의 "0"을 못 채웠다 → §10.6.
- **고정(15:02)**: 노드 B → 노드 A 순으로 `pin` — 둘 다 `RESULT: OK pin -- default boot pinned to the running kernel 6.17.0-1020-oracle`(update-grub exit 0 · grub.cfg 기본값 = 6.17 항목의 ID 경로 · ID 유일). 고정은 모듈 문제와 무관하다(지금 커널에 대한 것).

### 10.6 "새 커널에 없는 모듈 넷" — 이름이 바뀐 것(노드 증거 + 상류 소스 조사)

도구의 검사는 "지금 적재된 모듈의 **이름**이 새 커널의 모듈 트리에 있는가"다. 6.18–7.0 사이에 상류가 아키텍처별 암호화 코드를 `lib/crypto`로 통합하면서 이름이 없어졌다.

| 6.17의 이름(지금 쓰는 곳) | 바뀐 판 · 상류 커밋 | 7.0에서 | 노드 증거(두 노드 동일) |
|---|---|---|---|
| `libcurve25519_generic`(WireGuard) | v6.18 · `68546e5632c0` "curve25519: Consolidate into single module" | 모듈 `libcurve25519` 하나(같은 generic 코드 — `CRYPTO_LIB_CURVE25519_GENERIC=y`) | `modprobe -S 7.0… --show-depends wireguard` = `udp_tunnel` → `ip6_udp_tunnel` → `libcurve25519` → `wireguard` |
| `blake2b_generic`(btrfs의 부속 · 사용 0) | v6.19 · `fa3ca9bfe3f0` | `blake2b` + `libblake2b` | btrfs 의존성 목록이 `libblake2b`로 풀림 |
| `polyval_ce`(CPU 기능으로 자동 적재 · 사용 0) | v6.19 · `37919e239ebb` | `libpolyval`(arch 코드 포함 — `CRYPTO_LIB_POLYVAL_ARCH=y`) | `libpolyval.ko.zst` 있음 |
| `aes_ce_cipher`(`aes_ce_blk`가 사용) | v7.0 · `2b1ef7aeeb18` | 커널 이미지에 내장된 `libaes`(`CRYPTO_LIB_AES_ARCH=y`) | `aes_ce_blk` · `aes_ce_ccm`은 7.0에도 있음 · `libaes` (builtin) |

- **패키징**: 7.0에는 `linux-modules-extra` 바이너리 패키지가 없다(Launchpad 게시 0건 · `linux-image-7.0.0-1012-oracle`은 `linux-modules-…`에만 의존). 모듈 8,608개가 전부 이미 설치된 `linux-modules-7.0.0-1012-oracle` 하나에 있다(6.17은 base 967 + extra 7,366 = 8,333). K3s가 쓰는 netfilter · overlay · bridge · vxlan · ip_vs · iSCSI 모듈과 OCI 부팅 경로(virtio · ext4 · PL011 — 내장)도 확인.
- **조사 방법**(워크플로 — 조사 6 + 반박 검증 4 · 에이전트 10 · 오류 0): 조사 에이전트들이 노드에 설치된 것과 같은 `.deb`(아카이브 색인의 sha256과 대조)를 내려받아 풀어 대조했고, 반박 검증자가 따로 다시 유도했다 — 넷 다 **반박되지 않음**. WireGuard 검증자는 `linux-image-7.0.0-1012-oracle` 바이너리를 QEMU(neoverse-n1)에서 부팅해 WireGuard 적재 · Curve25519 시험 벡터 · 핸드셰이크 · flannel v0.28.4의 netlink 호출 모양(K3s v1.36.4의 wgctrl 판)까지 확인했다(1013도 같음). 전체 결과 `.superpowers/t048/b/module-research-result.json`.
- **결정**: `trial`에 `--ignore-missing-modules`를 쓴다. 조건 — 그 옵션은 그 순간 빠진 것을 전부 받아들이므로 **출력의 이름이 정확히 이 넷**이어야 한다. 실제 동작은 B3의 관문(노드 간 통신)이 본다.
- **도구의 한계(뒤에 반영)**: 이름 대조는 "다른 모듈 · 커널 이미지로 합쳐진 것"을 없는 것으로 본다. 더 튼튼한 기준은 소비자(예: wireguard)의 의존성 닫힘을 새 커널에서 푸는 것(`modprobe -S <새 커널> --show-depends`)이다.

### 10.7 조사에서 새로 나온 것 — 7.0 자체의 성질과 커널 수명 주기

- **KHO(Kexec HandOver)가 기본으로 켜져 있다**(`CONFIG_KEXEC_HANDOVER_ENABLE_DEFAULT=y` — 7.0 설정에 새로 생김). 부팅 때 초기 커널 할당의 배수만큼을 "옮길 수 있는 페이지 전용"으로 예약한다 — 12 GB 노드에서 약 1 GB로 추정(미실측). 다른 환경에서 "메모리가 남는데 OOM kill" 보고가 있고(LP #2163395 등), 캐노니컬이 일부 커널에서 기본값을 끄는 변경을 진행 중이다(LP #2168816). `kho=off`로 끌 수 있다. 재는 법: `CmaTotal`은 그대로(32768 kB)이고 `CmaFree`가 그보다 훨씬 크면 켜진 것 · `/sys/kernel/debug/kho/out/scratch_len`.
- **메모리 한도가 빡빡한 컨테이너의 OOM kill**: 같은 커널 전환(6.17.0-1020-oracle → 7.0.0-1012-oracle)을 한 다른 프로젝트의 CI(x86-64)에서, 한도 50Mi 컨테이너가 7.0에서만 노드마다 1–6회 OOM kill됐다는 보고(원인 미상). 우리 기준선(10-02 16:15): OOM 이력 0 · 한도 대비 사용량이 가장 높은 것은 cert-manager-webhook(80Mi 중 50Mi · 노드 B), 나머지는 50% 아래.
- **WireGuard netlink 검증 강화**(v6.19) — flannel의 호출 모양은 에뮬레이션에서 통과. 실기 확인은 B3의 `wg show flannel-wg`(peer · 최근 핸드셰이크 · 전송량).
- 그 밖: 선점 모델이 PREEMPT_NONE → PREEMPT_LAZY · `sbsa_gwdt`가 7.0 패키지에서는 블랙리스트에서 빠졌다(장치가 있으면 자동 적재 — 무해) · AppArmor의 exec 라벨 문제(containerd #12886)는 `kernel.apparmor_restrict_unprivileged_unconfined=1`일 때의 것이고 세 커널 모두 컴파일 기본값 0 · noble의 apparmor는 그 값을 켜지 않는다.
- **커널이 자동으로 들어오고 나가는 규칙**(apt 2.7.14 · unattended-upgrades · 노드의 삭제 이력으로 확인): 설치 실행(06:00–07:10)은 보안 포켓의 새 커널을 받고, **부팅된 커널 + 그 밖의 가장 새 커널** 둘만 남긴다. 그래서 —
  - 6.17로 도는 고정 노드에 1013이 오면: 6.17 · 1013이 남고 **1012가 지워진다**(시험 대상이 바뀐다 · 고정은 유효).
  - **1012로 도는 노드에 6.17 고정이 남은 채 1013이 오면: 고정된 6.17이 지워진다** → 고정이 허공을 가리키고 GRUB은 말없이 첫 항목(가장 새 커널 = 부팅해 본 적 없는 1013)으로 간다. 그 상태에서는 도구의 어떤 명령도 거부한다(수동 복구: 고정 파일 삭제 → `update-grub` → `pin`).
  - 고정을 풀기만 해서는 6.17이 남지 않는다(고정을 지킬 뿐 커널을 지키지 않는다). 커널 집합을 그대로 두려면 메타패키지를 hold한다.
  - 두 노드의 목록 갱신 시각이 다르다(A 00:14 · B 05:01) — 1013이 그 사이에 보안 포켓에 들어오면 두 노드의 커널 집합이 달라진다.
- **끝 상태에 대한 제안(사용자 결정 대기)**: 시험이 끝난 노드는 `unpin`으로 끝내지 않고 **검증된 커널에 다시 고정**해 둔다(`unpin` → `pin` — 실행 중 = 검증된 커널). 부팅된 커널은 apt가 지우지 않으므로 고정이 허공을 가리킬 일이 없고, 새 커널이 들어와도 계획하지 않은 재부팅이 검증 안 된 커널로 가지 않는다. 이것을 OS 패치 재부팅 절차의 정상 상태로 삼을지는 런북 §6을 쓸 때 정한다.

### 10.8 노드 B — 시험 파드 · 그냥 재부팅(B2) · 시험 파드의 결함과 대조(15:05–16:17 KST)

- **B1**: 시험 파드 v1 적용(15:05) — 6.17에서 바로 Ready.
- **B2**(15:22:19 `systemctl reboot`): 약 70초 뒤 **6.17로 복귀**(bootID `7579c90a…` → `2387abd7…`) — **고정이 실제 arm64 장비에서 먹는다는 실증**(기본값이 0이었다면 7.0으로 올라왔을 것이다). 노드 B의 파드(Argo CD 5 · CoreDNS · cert-manager 3 · 터널 커넥터) 전부 Ready · Application 22 재부팅 뒤 재수렴(가장 이른 것 15:26:57) · ExternalSecret 2 재부팅 뒤 갱신 · 스냅샷 관문 11 가운데 10 OK.
  - 조회 경로는 노드 B가 내려가 있던 약 60초 동안 불통이었다(CoreDNS가 노드 B에만 있다). 노드 B의 Ready `lastTransitionTime`은 재부팅을 지나도 그대로였다(70초는 노드 컨트롤러의 유예보다 짧다).
- **시험 파드 v1의 결함**(관문 1 FAIL의 원인): 재부팅 뒤 exec 프로브가 계속 5초 시간 초과(240회) — **같은 6.17 커널에서**. 진단(운영자 exec · 읽기): 단순 exec는 성공 · cgroup `memory.max` 64Mi에 `memory.current` 63Mi · `memory.events max 14` · `workingset_refault_file` 947만 · OOM 0 · AppArmor 거부 0 · `/bin/vault`는 485 MB. 재부팅 전에는 이미지를 막 풀어 놓아 파일 페이지가 노드의 페이지 캐시에 있었고(컨테이너의 cgroup에 잡히지 않는다), 재부팅 뒤에는 읽는 페이지가 전부 64Mi cgroup에 잡혀 버리고-다시-읽기가 반복됐다. **컨트롤러가 시험 파드의 한도를 잘못 잡은 것이고 커널 · exec 경로와 무관하다.** B2(같은 커널로의 재부팅)를 B3 앞에 둔 덕에 이것을 새 커널 탓으로 읽지 않았다.
- **v2**(16:02): 한도 512Mi(Vault와 같게) · 프로브 시간 설정도 Vault의 것 그대로(initialDelay 5 · period 5 · timeout 3 · failureThreshold 2) — 시작 8초 만에 Ready · 실패 0 · 작업 집합 203–253Mi(`vault version` 한 번이 그만큼의 파일 페이지를 건드린다).
- **대조(6.17 · 차가운 캐시 — 16:12:46 노드 B에서 `drop_caches`)**: 프로브 시간 초과 **1회** 뒤 바로 통과 · 파드는 계속 Ready. → B3의 기준: 부팅 직후의 프로브 실패 한두 번은 정상, 이어지면 이상.
- **검토 워크플로(진단 반박 · 설계 검토 · 대조와 통과 기준 + 종합) — 넷 다 "동의하되 고칠 것 있음"**. 진단은 확정됐다(같은 6.17 부팅에서 한도만 512Mi로 바꾼 v2가 8초 만에 Ready — 리뷰어 셋이 요구한 바로 그 시험). 결과는 B3을 실행한 **뒤에** 도착했다 — 컨트롤러가 검토를 기다리지 않고 진행한 것이고, 그래서 아래의 권고 가운데 대조 방법은 반영하지 못했다.
  - `drop_caches`는 대조 도구로 맞지 않는다(노드 전체를 비우고, 한가한 노드에서의 1회와 부팅 직후의 4회는 같은 조건이 아니다) → **"6.17에서 1회 · 7.0에서 4회"를 커널 비교로 인용하지 않는다.** 같은 조건의 대조는 v2를 둔 채 6.17로 그냥 재부팅하는 것인데, 종합 검토는 "7.0 부팅의 결과가 세 리뷰어의 절대 기준(컨테이너 시작 뒤 60–180초 안에 Ready) 안에 들어왔으므로 통과 판정에는 기준선이 필요 없다"고 봤다 — 노드 B에서 추가 대조는 하지 않았다. **B2의 관문 하나(시험 파드 다시 Ready)는 충족되지 않은 채 넘어갔다**(면제 — 원인이 시험 파드 자체로 확정됐고 v2가 같은 부팅에서 통과).
  - 시험 파드는 CPU 요청이 10m라 Vault(100m)보다 CPU 가중치가 낮다(cgroup `cpu.weight` 1 대 4) — 7.0 부팅 직후의 시간 초과 4회는 불리한 조건에서 나온 상한으로 읽는다(Vault의 프로브가 그만큼 느리다는 뜻이 아니다). 다음에 쓸 판은 CPU 요청 100m · 메모리 요청 256Mi.
  - 세 리뷰가 모두 놓친 것(종합 검토가 찾음): Vault에는 exec 경로가 하나 더 있다 — `preStop` 훅이 exec 세션에서 Vault 프로세스에 신호를 보낸다. → 시험 파드(7.0)와 vault-0(6.17 · 7.0)에서 신호 전달을 따로 확인했다(§10.9 · §10.11).
  - "vault-0은 지금 자기 실행 파일의 페이지 캐시를 소유하지 않는다"는 그때까지 미확인이었다 → A1 전의 관문으로 쟀다(§10.11).
  - 증거의 수명: 이벤트는 1시간 뒤 사라진다 → 시험 파드의 이벤트와 파드 객체를 그때그때 저장했다(`.superpowers/t048/b/canary-events.json` 등).

### 10.9 B3 — 노드 B를 새 커널로 한 번 부팅(16:16–16:35 KST)

- **시험 설정**: `trial 7.0.0-1012-oracle --ignore-missing-modules` — 빠진 이름이 정확히 그 넷(적재된 98개 가운데) · `next boot: 7.0.0-1012-oracle (one-shot next_entry)` · `later boots: 6.17.0-1020-oracle` · `RESULT: OK trial`.
- **재부팅**(명령 16:21:30): 16:21:47에 7.0.0-1012로 부팅(bootID `2387abd7…` → `67dd8b17…`). 조회 불통은 표본 넷(약 40초). **1회용 선택이 실제 arm64 장비에서 먹었고, 한 번 쓰인 뒤 비워졌다**(`INFO grubenv: next_entry=` · `next boot: 6.17.0-1020-oracle (default)`) — §8.8에서 에뮬레이션으로만 확인했던 GRUB `save_env` 동작의 실기 확인이다.
- **A 진행 조건(§8.4)**: 사후 스냅샷(명령 5분 43초 뒤) 관문 11개 전부 OK — 노드 B 커널 7.0 · 파드 전부 Running/Ready · Application 22 Synced/Healthy이며 전부 재부팅 뒤 재조정(`reconciledAt`의 가장 이른 값이 명령 3분 54초 뒤) · ExternalSecret 2 재부팅 뒤 갱신(노드 A의 ESO → 노드 B의 CoreDNS — 노드 간 WireGuard가 일한다는 뜻) · 터널 커넥터 둘.
- **노드 확인(16:30 · 읽기)**: `tainted=0` · 실패한 유닛 0 · `wireguard`가 `libcurve25519`를, `btrfs`가 `libblake2b`를 쓴다(§10.6의 예측 그대로 · `libcurve25519_generic`은 없다) · `flannel-wg` 피어 핸드셰이크 9초 전 · 송수신 오류 0 · AppArmor 거부 0 · memcg OOM 0 · `kernel.apparmor_restrict_unprivileged_unconfined = 0` · k3s-agent 로그의 flannel/wireguard 오류 0 · 커널 autoremove 대기 없음.
- **KHO 실측**: scratch 영역 셋 = 192 MiB + 520 MiB + 470 MiB = **1,182 MiB(약 1.15 GiB)** — `CmaTotal`은 32,768 kB인데 `CmaFree`가 1,230,848 kB다(§10.7의 판별법대로 켜져 있다). `MemAvailable` 약 11.5 GiB — 지금 부하에서는 여유가 크다.
- **시험 파드(v2)**: 컨테이너가 다시 시작한 뒤 프로브 시간 초과 4회(16초 동안) → **시작 26초 뒤 Ready**, 그 뒤 실패 0. 손으로 한 첫 exec(`vault version`)는 5.3초(차가운 캐시). exec한 프로세스의 AppArmor 라벨은 PID 1과 같은 `cri-containerd.apparmor.d (enforce)`(겹친 라벨 `//&` 없음 — containerd #12886의 증상 없음) · 신호 시험(exec 세션의 자식에 TERM → 종료 코드 143) 통과.

### 10.10 A1 사전 검토(워크플로 — 순서와 관문 · 실패와 되돌리기 · 측정의 유효성) — 셋 다 "고치고 진행"

실행 순서 초안(`.superpowers/t048/a1/a1-runbook.md`)에 대한 검토다. 막는 발견은 없었고, 고친 것은 전부 절차의 문구와 읽기 전용 확인이다 — 반영은 운영자에게 준 블록에서 했다(초안 파일은 그대로 뒀다).

| 발견(심각도) | 반영 |
|---|---|
| armed 확인이 "마지막 기준점 줄"만 본다 — 끝났거나 죽은 하네스도 armed로 읽힌다(high · 셋 공통) | 운영자가 하네스 로그를 **실시간 tail**로 보다가 재부팅 블록을 실행한다 · 재부팅 블록은 미리 입력해 둔다 |
| 재부팅 블록이 초안에 적혀 있지 않다 — 시각 파일은 이 PC에서 ssh **전에** 쓰여야 한다(medium) | 블록 확정: 절대 경로에 UTC를 쓰고 출력 → `ssh ssh-a "sudo systemctl reboot"` → ssh가 돌아온 시각과 종료 코드 출력 |
| 하네스는 새 bootID만 증명한다 — 7.0이 스스로 재부팅해 6.17로 돌아와도 PASS일 수 있다(high) | **수용 판정 = 래퍼 `VERDICT: PASS` + 사후 스냅샷 관문 전부 OK(노드 A 커널 7.0 포함) + 스냅샷의 bootID = 하네스 PASS 줄의 새 bootID** |
| 재부팅 명령 뒤에는 "중립적인 재부팅"이 없다 — 어떤 재부팅이든 6.17로의 되돌리기다(high) | 실패 분기의 맨 위 규칙으로: 하네스 FAIL만으로는 재부팅하지 않는다 · 증거(커널 로그 · 컨테이너 상태)부터 · 되돌리기 전 `status` |
| 강제 재시작의 전제가 틀릴 수 있다 — 옛 부팅이 종료 중에 멈추면 GRUB이 아직 안 돌았으므로 강제 재시작은 7.0으로 간다(high) | 3분 · 5분 시점의 읽기 전용 확인을 먼저(ssh 응답 → 노드 B에서 노드 A로 ping · 22번 포트) · 노드 A의 내부 주소를 미리 적어 둔다(로컬에만) |
| `trial` 뒤의 중단 경로에 `cancel-trial`이 선택 사항으로 적혀 있다(high) | "기준 미충족 · 중단이면 곧바로 `cancel-trial`"로 |
| hold가 성공 경로에만 있다 — 노드 B는 16:21부터 "7.0 실행 · 6.17 고정 · hold 없음"이다(high) | 모든 종료 경로의 끝 점검으로 올렸다(→ §10.13) |
| 조회 토큰 · Access 세션의 남은 수명을 보는 관문이 없다(medium) | 토큰 만료 시각을 로컬에서 디코드해 확인(값은 출력하지 않는다) · 재부팅 직전에 ssh 예열 |
| 래퍼의 판정 줄이 파일로 남지 않는다 · 다시 시도하면 증거가 덮인다(medium) | 래퍼 출력을 `a1-wrapper.log`로 · 원본 조회 결과를 재부팅 직후 `raw/`에 저장 |
| 사후 스냅샷이 너무 이르면 재조정 관문이 잘못 FAIL한다(medium) | 명령 6분 뒤에 찍고, 한참 뒤에 한 번 더 |
| A1은 노드 A의 "첫 재부팅"이자 "첫 7.0 부팅"이다 — 실패하면 원인이 갈리지 않는다(low) | 받아들였다: 원인 분리 = 되돌린 뒤 6.17에서 다시 재는 것(§8.4). 성공했으므로 쓰이지 않았다 — **대신 "재부팅 뒤에 달라진 것"이 커널 때문인지 재부팅 때문인지는 노드 A만으로는 갈리지 않는다**(§10.12) |

### 10.11 A1 — 노드 A 측정 재부팅(T048의 측정 · 16:46–17:30 KST) — 합격

- **관문 G2(Vault 메모리 · 6.17 · 파드 가동 15일째)**: 서버 프로세스 RssAnon 62 MiB + RssFile 186 MiB = 248 MiB ≤ 384 MiB → 진행. 그런데 Vault의 cgroup에 잡힌 것은 154 MiB(`memory.current` · 파일 39 MiB)뿐이었다 — **실행 파일 페이지의 대부분이 Vault의 cgroup 밖에 잡혀 있었다**는 뜻이고, 재부팅 뒤에는 전부 자기 한도(512Mi) 안으로 들어온다는 예측의 근거였다. exec 라벨은 겹치지 않음 · `vault status` 0.06초.
- **시험 설정**: 노드 A `trial 7.0.0-1012-oracle --ignore-missing-modules` — 빠진 이름 넷(적재된 101개 가운데) · `RESULT: OK trial`.
- **측정**: 하네스를 먼저 켜고(17:00:56) 운영자가 17:06:18(UTC 08:06:18)에 재부팅 명령. 하네스의 0초 기준점은 명령 10.8초 **전**(옛 부팅의 마지막 관측 — 하네스가 그만큼 엄격하게 셌다). 하네스 8 passed / 0 failed · 명령 시각 기준 재판정 PASS · 래퍼 `VERDICT: PASS`. 낡은 bootID가 다시 보인 줄 0 · 401 0.

| 명령 뒤 | 일어난 것 | 근거 |
|---|---|---|
| +9초 | 조회 불통 시작 | 관찰 표본 |
| +16초 | 노드 A 부팅 시작(7.0.0-1012) | 노드의 `uptime -s` |
| +39초 | API가 다시 답한다(불통 약 30초) — 첫 응답 한 번은 낡은 옛 bootID | 관찰 표본 |
| +45초 | k3s 유닛 active | 노드의 유닛 시각 |
| +46.3–54.0초 | **reboot-0** 새 bootID(`a8d06ef9…` → `ab7f6098…`) + Ready | 하네스 · 재판정 |
| +53초 → +69초 | Vault 컨테이너 시작 → 파드 Ready(16초 — exec 프로브 시간 초과 1회 · 연결 거부 1회 뒤) | 파드 상태 · 이벤트 |
| +54.0–71.6초 | **reboot-1** Vault `sealed=false type=ocikms`(port-forward 수립에 15.7초 — 실제 unseal은 더 이르다) | 하네스 · 재판정 |
| +71.6–74.7초 | **reboot-2** ClusterSecretStore 5개 Ready | 하네스 · 재판정 |
| +74.7–78.4초 | **reboot-3** Application 22개 Healthy | 하네스 · 재판정 |
| +187.8–192.3초 | **reboot-4** ExternalSecret 2개가 부팅 뒤에 갱신(reboot-2 관측이 끝난 뒤 113.2초 — 갱신 주기 5분의 다음 차례) | 하네스 · 재판정 |
| +4분 15초 | Application 22개 가운데 19개가 재부팅 뒤 재조정(나머지 셋은 명령 58–81초 전의 값) | 저장한 원본 조회 |
| **+6분 9초** | **Application 22개 전부 Synced/Healthy이며 `reconciledAt`이 전부 명령 뒤**(사후 스냅샷 1 — 관문 12개 전부 OK · 스냅샷의 bootID = 하네스의 새 bootID) | 스냅샷 |
| +1시간 45분 | 사후 스냅샷 2 — 관문 12개 전부 OK · bootID 그대로 | 스냅샷 |

- **SC-001 근거(안 A)로 남기는 수치**: 재부팅 명령 → 전 Application Healthy 관측 **78초** · 전 Application이 재부팅 뒤 재조정까지 마친 것을 확인한 시각 **6분 9초**(4분 15초에는 19/22 — 실제 완료는 그 사이). 문면 그대로의 구간(빈 클러스터에 root app 적용)은 재지 않았다(§3 P2).
- **노드 A 확인(17:16 · 읽기)**: `tainted=0` · 실패한 유닛 0 · `wireguard` + `libcurve25519` · 핸드셰이크 141초 전 · KHO 예약은 노드 B와 같은 세 영역(1.15 GiB) · AppArmor 거부 0 · memcg OOM 0 · `status`: `next_entry=` 빈 값 · `next boot: 6.17.0-1020-oracle (default)` · 고정 그대로.
- **K3s 로그의 flannel/wireguard 오류 4줄은 한 사건**이다 — 17:07:08에 Reloader 파드의 샌드박스 네트워크 설정이 한 번 실패(K3s 시작 5초 뒤 · flannel 준비 전) → 다시 시도해 17:07:16에 컨테이너 시작. 직전 부팅과 노드 B에는 같은 줄이 없다.
- **복구 중의 경고 이벤트**(1시간 뒤 사라지므로 저장해 둔 것): metrics-server · Traefik · Vault의 시작 중 프로브 실패뿐. 노드 B의 cert-manager 컨트롤러가 17:07:04에 한 번 재시작했다(종료 코드 1 — API 불통이 리더 선출 갱신 기한을 넘긴 것으로 추정 · 로그는 보지 않았다).
- **vault-0(재부팅 10분 뒤 · 7.0)**: `memory.current` 353 MiB · 최고 373 MiB / 한도 512 MiB(재부팅 전 154 MiB) · `memory.events` 전부 0 · 다시 읽기 0 · 압박 0 · RssAnon 50 MiB · RssFile 180 MiB · exec 라벨 겹치지 않음 · 신호 0 전달 OK · `vault status` 0.06초. **예측대로다 — 실행 파일의 페이지가 처음으로 Vault 자신의 한도 안에 잡혔고(파일 299 MiB), 한도의 69–73%다.**

### 10.12 재부팅 뒤 90분 — 관찰 표본 · 컨테이너 메모리 · 조회 경로

- **관찰 표본(10초 · 30초 간격 · 17:00–18:33)**: 조회에 성공한 표본은 17:07:50부터 끝까지 전부 Application 22/22 Healthy · Synced, store 5/5, 노드 2/2 Ready, vault-0 재시작 1 그대로. 마지막 1시간의 경고 이벤트 0건. 시험 파드는 7.0에서 16:22:36부터 계속 Ready(재시작은 B3의 1회뿐).
- **컨테이너 메모리(17:28 · 두 노드의 cgroup을 직접 읽음)**: 전 컨테이너에서 한도 도달(`memory.events max`) 0 · OOM kill 0 · 파일 다시 읽기 0 · 회수 스캔 0 — 메모리 압박은 어디에도 없다.
- **그런데 사용량 자체는 재부팅 뒤에 크게 늘었다**(`kubectl top` — 노드 A의 재부팅 전 값은 16:16 · 6.17 · 28일 가동, 뒤 값은 19:02 · 7.0):

  | 컨테이너(노드 A) | 재부팅 전 | 재부팅 뒤 | 한도 |
  |---|---|---|---|
  | vault | 146Mi | 359Mi | 512Mi |
  | ESO cert-controller | 53Mi | 107Mi(17:17에는 121Mi) | 128Mi |
  | ESO webhook | 28Mi | 92Mi | 128Mi |
  | ESO controller | 32Mi | 58Mi | 192Mi |
  | Traefik | 23Mi | 157Mi | 없음 |
  | Reloader | 11Mi | 55Mi | 128Mi |
  | SUC | 15Mi | 60Mi | 128Mi |
  | cloudflared | 19Mi | 41Mi | 256Mi |

  늘어난 것은 거의 전부 파일 페이지다(cgroup의 `active_file`). 설명: 처음 설치할 때는 이미지를 푼 쪽(containerd)의 cgroup에 실행 파일의 페이지가 잡혔고 컨테이너는 그 페이지를 "공짜로" 썼다. 재부팅하면 캐시가 비고, 그 뒤로는 각 컨테이너가 읽은 페이지가 **자기 한도 안에** 잡힌다. 이것은 커널 판과 무관한 cgroup v2의 규칙이고 6.17에서의 B2가 같은 현상을 보였다(시험 파드 v1). 다만 **노드 A에서는 "첫 재부팅"과 "첫 7.0 부팅"이 같은 사건이라 커널의 몫이 0이라고 재서 말할 수는 없다**(§10.10 마지막 행). 노드 B의 "전" 값은 `drop_caches` 3분 뒤라 비교에 쓰지 않는다.
- **운영에 남는 뜻**: 한도는 **재부팅 뒤의 수치**로 잡아야 한다. 지금 가장 빡빡한 것은 ESO cert-controller(128Mi 중 107–121Mi) · cert-manager-webhook(80Mi 중 67Mi · 노드 B) · ESO webhook(128Mi 중 92Mi) · Vault(512Mi 중 359Mi). 파일 페이지는 회수할 수 있어 곧바로 OOM으로 가지는 않지만, 익명 메모리가 늘면 회수와 다시 읽기가 시작된다(시험 파드 v1이 그 끝 모습이다). 한도 조정은 gitops 변경이므로 후속으로 남긴다(§10.14).
- **조회 경로의 일시 실패**(이 PC → 터널 → API): 재부팅 전의 관찰 구간(15:07–17:06 사이 · 재부팅 창 제외)은 표본 약 430개 가운데 3개(0.7%), 재부팅 뒤 90분은 약 660개 가운데 13개(2.0% — 연속 두 표본이 실패한 묶음이 두 번: 17:44 · 17:53, 각 20–30초). 관찰기는 오류 문구를 남기지 않는다 — 같은 시간대에 손으로 한 조회에서 본 것은 TLS 핸드셰이크 시간 초과다. **이 차이를 커널 탓으로 읽을 근거는 없다** — 뒤 구간은 관찰기 둘(무거운 Application 조회 포함)을 동시에 돌려 조건이 다르고, 클러스터 안쪽의 지표(이벤트 · 재시작 · 압박)는 전부 0이며, 터널 커넥터 파드의 판(ReplicaSet)도 그대로다. 그렇다고 아니라고 잰 것도 아니다 → 다음 근무일에 관찰기 하나로 15분 재서 가린다(도구 `.superpowers/t048/obs/latency.ps1`).

### 10.13 2일차 종료 — 끝 상태와 재개 지점(2026-10-02 19:10 KST — 사용자가 여기서 닫았다)

- **사용자 결정**: 끝 상태를 물었고(세 안 — 6.17 고정 유지 + hold / 7.0으로 다시 고정 + hold / 고정만 해제) 답은 **"고정만 해제(원래 계획)"** 였다. 컨트롤러가 F의 절차 초안(`.superpowers/t048/f/f-runbook.md`)을 쓰고 독립 검토를 돌리는 사이 사용자가 "오늘 작업 여기서 마무리"라고 했다 → **F(두 노드 `unpin` · 시험 파드 삭제)는 다음 근무일**로 넘긴다. R7("F는 같은 날 끝낸다")을 지키지 못했으므로 그 규칙의 뒷부분대로 다음 근무일은 두 노드 `status`부터 본다.
- **주말 동안의 노드**: 두 노드 모두 `7.0.0-1012-oracle`로 실행 중 · GRUB 기본값은 `6.17.0-1020-oracle`에 고정 · `next_entry=` 빈 값 → **재부팅되면 6.17로 돌아온다**(계획하지 않은 재부팅의 안전한 쪽 — 다음 근무일에 노드가 6.17로 돌고 있으면 그사이 재부팅이 있었다는 신호다). 시험 파드 `jt-dev/kernel-canary`(v2)는 그대로 둔다 — 7.0에서 exec 프로브가 계속 통과하는지의 주말 관찰.
- **hold(19:08–19:09 · 운영자 실행)**: 두 노드에서 `sudo apt-mark hold linux-oracle linux-image-oracle linux-headers-oracle` — 노드마다 `set on hold` 세 줄 + `apt-mark showhold`에 세 이름(출력 사본 `.superpowers/t048/f/f1-hold.txt`). 이것으로 §10.7의 위험(1012로 도는 노드에 1013이 들어오면서 고정된 6.17이 지워지는 것)을 주말 동안 닫는다. 되돌리기는 `apt-mark unhold` 같은 세 이름. **이 블록은 F 절차 검토가 끝나기 전에 줬다** — 사용자가 자리를 뜨는 시점이었고, 패키지의 보류 표시만 바꾸는 명령이라 해가 될 경로가 없다고 판단했다(검토 결과는 §10.15). 모의 업그레이드로 "1013이 실제로 막히는가"를 읽어 보는 확인(F0 · F4)은 하지 못했다 — 다음 근무일 3번에서 본다.
- **접속 세션**: 운영자가 캐시된 토큰 파일을 지웠다(0개 확인). 터널 리스너 창은 닫아 달라고 요청한 상태로 끝났다.
- **다음 근무일의 순서**:
  1. 운영자 전제: 터널 리스너 · 조회 토큰(8시간).
  2. 에이전트(읽기): 스냅샷 — **노드별 커널** · 파드 재시작 수 · 시험 파드 상태. 이어서 관찰기 하나로 15분(`latency.ps1`) — §10.12의 조회 실패율을 가린다.
  3. 운영자(읽기 · 두 노드): F0 블록(커널 패키지 · hold · 포켓별 후보 · 모의 업그레이드 · autoremove · 타이머 · `status`) + 컨테이너 메모리 cgroup(주말 동안의 한도 도달 · 다시 읽기) + KHO 수치.
  4. 운영자(쓰기 · 단계마다 재확인): (hold가 없으면 hold) → 노드 B `unpin` → 노드 A `unpin` → F4 읽기 → 시험 파드 삭제 → 에이전트 스냅샷.
  5. 사용자 결정(한 번에 하나): 커널 hold를 언제 풀지(= 런북 §6의 OS 패치 재부팅 절차 — 자동으로 받고 계획된 재부팅 전에 고정 → 1회 시험 → 해제를 할지, 평소에 보류해 두고 창을 잡아 올릴지) · `kho=off` 여부 · 메모리 한도 조정(gitops).
  6. 기록: 런북 `bootstrap.md` §3 T048 절(백업 검증 출력과 시각 · 재부팅 표 · SC-001 근거와 한계) · §3 요약(전체 순서 · 시간 · 시크릿 취급) · §6 OS 패치 재부팅 절차 · `report.md`에 올릴 것(§10.14) · 모노레포 run-all 전체 1회 · `tasks.md` 체크(54/119).
- **증거(로컬 · gitignore)**: `.superpowers/t048/k0/`(두 노드 읽기 전용 확인 · 고정) · `b/`(노드 B — B2 · 시험 파드 진단 · B3) · `a1/`(노드 A — 기준값 · Vault 전후 · 하네스 · 래퍼 판정 · 관찰 표본 · 원본 조회 `raw/` · 사후 스냅샷 둘 · 노드 확인 · 컨테이너 메모리) · `f/`(F 절차 초안과 그 검토) · 도구 `obs/` · 지시서 `prompts/`.

### 10.14 후속으로 남긴 것

| 갈래 | 내용 | 어디서 |
|---|---|---|
| 도구 | `kernel-trial.sh` 낮은 등급 넷(§10.3 ①–④) + 모듈 검사를 이름 대조에서 의존성 풀이(`modprobe -S <새 커널> --show-depends`)로 | 노드 작업(F)이 끝난 뒤 빌더 한 회차 — **F 전에는 스크립트를 고치지 않는다**(운영자가 리뷰한 판의 blob을 쓴다) |
| 도구 | 재부팅 하네스: 못 잡는 변이 여섯의 테스트 보강 · 단위 테스트 12분 줄이기 | 같은 회차 |
| 운영 | 메모리 한도를 재부팅 뒤 수치로: ESO cert-controller(128Mi 중 107–121Mi) · cert-manager-webhook(80Mi 중 67Mi) · ESO webhook(128Mi 중 92Mi) · Vault(512Mi 중 359Mi) | 사용자 결정 뒤 gitops PR |
| 운영 | KHO(1.15 GiB 예약)를 끌지(`kho=off`) | 사용자 결정 — 런북 §6 |
| 운영 | 커널 hold의 해제와 정책 — hold는 host-prep 스크립트가 모르는 수동 상태다(선언과 어긋남) | 사용자 결정 — 런북 §6 · 필요하면 host-prep에 반영 |
| 운영 | CoreDNS가 노드 B에 하나뿐이다 — 노드 B가 내려가 있는 동안 조회 경로가 약 60초 끊겼다(B2 실측) | `report.md` — 받아들일지, replica를 늘릴지 |
| 운영 | apparmor 패키지 `…24.04.7` — 새 커널 관련 수정은 `.8`에 있다(보안 포켓으로 오면 자동 설치) | 다음 근무일의 F0에서 판 확인 |
| 확인 | cert-manager 컨트롤러가 노드 A 재부팅 중 한 번 재시작한 원인(리더 선출 갱신 기한으로 추정) | 로그 확인(운영자 읽기) — 필요하면 |
| 확인 | 조회 경로의 일시 실패율(§10.12) | 다음 근무일 2번 |
| 보고 | SC-001 한계(문면 그대로는 미실측 · 근거 수치 78초 / 6분 9초) · 커널 전환(6.17 → 7.0)과 그 발견들 · 재부팅 뒤 사용량 증가 · T047의 D8 편차 등 | `report.md`(`/finish`) |

### 10.15 F 절차 초안의 독립 검토(워크플로 — `unpin` 경로 추적 · hold의 소스 검증 · hold 재현 · 블록 문법 · 주말 무인 위험)

결과는 이 절에 덧붙인다(2일차 종료 시점에는 진행 중). 금요일의 실행은 세션이 닫히며 결과 없이 끊겨, 화요일(10-06) 아침에 같은 다섯 관점으로 다시 띄웠다(문맥만 "hold는 금요일에 실행됨 · 오늘은 그 뒤"로 고침).

### 10.16 3일차(2026-10-06 화요일) 아침 — 금–화 무인 상태와 K3s 자동 업그레이드의 첫 실행

- **노드(F0 · 운영자 읽기 10:30 KST)**: 두 노드 모두 `7.0.0-1012-oracle` 실행 중이고 부팅 시각이 금요일 그대로다(**금 저녁–화 아침 재부팅 없음**). hold가 먹었다 — 메타패키지 셋이 `hi` · 모의 업그레이드가 `The following packages have been kept back: linux-headers-oracle linux-image-oracle linux-oracle`(1013은 아직 noble-updates에만 있고 noble-security의 후보는 1012) · 커널 autoremove 대기 없음 · unattended-upgrades는 토·일·월·화 네 번(10-03 · 04 · 05 · 06) 모두 "No packages found that can be upgraded unattended" · `reboot-required` 없음. `status`는 두 노드 `RESULT: OK status -- pin present -> 6.17.0-1020-oracle; next boot 6.17.0-1020-oracle (default)` · `next_entry=` 빈 값 · 잔여 없음. 출력 사본 `.superpowers/t048/f/f0-readonly.txt`.
- **클러스터(에이전트 스냅샷 10:32)**: 관문 9/9 · Application 22 Synced/Healthy · store 5 · ES 2 · Vault unsealed(컨테이너는 금요일 17:07 시작 그대로) · 경고 이벤트 0 · 시험 파드는 금요일 16:22:36부터 계속 Ready(재시작은 B3의 1회뿐) — **7.0에서 exec 프로브 3일 반 통과**. 사본 `f/cluster-check-monday.txt` · `f/snapshot-f-monday.txt`.
- **K3s가 v1.36.4 → v1.36.5로 올라가 있었다(두 노드 · `v1.36.5+k3s1` · 커밋 3dd98cc5)**. system-upgrade-controller의 **첫 실제 실행**이다 — T037의 "첫 일요일 창은 리허설(채널 해석값 = 클러스터 버전)"이라는 예상은 빗나갔다(채널 `v1.36`이 그 사이 1.36.5를 해석). 일요일 2026-10-04 **03:00–03:02 KST**(창 03:00–05:00 Asia/Seoul 안): 03:00:11 노드 B의 agent Job 파드가 뜨고(서버 완료 대기) · 03:00:57 노드 A의 server Job 파드(prepare = `platform-backup.sh --pre-upgrade`) · 03:01 두 노드의 `/usr/local/bin/k3s` 교체 · 03:01:28 노드 A `k3s.service` 정지(systemd 로그: containerd-shim들은 "remains running after unit stopped" — **파드는 살아남았다**, 재시작 수 금요일 그대로) · Plan `k3s-server` Complete 03:02:13 · 03:01:57 노드 B `k3s-agent.service` 정지 · `k3s-agent` Complete 03:02:44. 노드 라벨 `plan.upgrade.cattle.io/k3s-server` · `k3s-agent` = `98199dce…`. 두 Plan 모두 `latestVersion v1.36.5-k3s1` · `applying` 빈 값. 업그레이드 Job은 TTL로 지워져 남아 있지 않다.
  - **K3s가 번들로 관리하는 것이 함께 바뀌었다**: Traefik 차트 `40.1.4` → `40.1.5+up40.1.0`(이미지 `3.7.8` → `3.7.13` · 새 파드 03:02:30 · `helm-install-traefik` Job 03:01:52–03:02:33, 그 파드는 성공 전 2회 재시작 — CRD Job을 기다리는 통상의 순서 문제) · CoreDNS `1.14.7` 새 파드 03:01:50. **우리 설정은 살아 있다**(운영자 읽기 10:41): HelmChartConfig의 값이 라이브 TLSOption `default`(resourceVersion 2862022)에 그대로 — `sniStrict: true` · `clientAuthType: RequireAndVerifyClientCert` · `secretNames: [cloudflare-origin-pull-ca]` · `minVersion: VersionTLS12`; TLSStore `default`(2026-09-10) 그대로; 엣지 `auth` 404 · `argo` 302. 단일 replica라 교체 순간 443이 잠깐 끊겼을 것이다(측정 없음 · 사이트는 아직 공개 전).
  - 업그레이드 직전 백업(prepare)의 객체 확인은 `svc-verify` 세션이 필요하다(§10.17에 적는다).
  - 저장소 쪽 영향: 부트스트랩 스크립트의 설치 핀은 `v1.36.4+k3s1` 그대로다(`infra/bootstrap/k3s-{server,agent}.sh` · 테스트 `ver-1`) — 노드를 다시 만들면 1.36.4로 설치되고 다음 창에 SUC가 올린다(의도된 분업). `CLAUDE.md` · `plan.md`의 "K3s v1.36.4" 문구는 기록이다(갱신은 /finish 때). 런북 §6에 "첫 실행 기록"을 더한다(§10.14 표에 추가).
- **사용량(10:33)**: 노드 A 3,660Mi(금요일 19:02 3,108Mi) · vault 377Mi(359) · ESO cert-controller 58Mi(107–121 → 내려감) · 새 Traefik 20Mi(옛 파드 157Mi) · 새 CoreDNS 14Mi · 시험 파드 279Mi. 전부 압박 없음(경고 이벤트 0). K3s 바이너리가 바뀌어 노드 합계의 비교는 의미가 약하다 — 기록만.

### 10.17 3일차 — F 실행 · K3s 업그레이드 사후 확인 · 결정 셋 · 종료(2026-10-06 화)

- **F 절차 검토(§10.15) 결과**: 다섯 관점 가운데 셋이 끝났다(`unpin` 경로 추적 · 블록 문법 · 주말과 그 뒤의 위험 — 셋 다 "고치고 진행" · 막는 것 없음). 둘(apt hold의 소스 검증 · 컨테이너 재현)은 모델 사용량 한도로 실패했고, hold의 효과는 F0의 실측(메타 셋 kept back · unattended-upgrades 4회 "설치할 것 없음")으로 대신했다. 반영한 것: F0 · F4의 기준 문구(hold는 있는 것이 정상) · apt 모의 실행의 fail-open(`2>/dev/null` → `2>&1` · 요약 줄 · `E:` 줄) · pgrep에서 종료 대기 도우미 거르기 · **GRUB 설정 지문**(기본값 줄을 뺀 sha256 · linux/initrd 줄 수 · 마지막 줄) · 부팅 파일 시각과 부팅 시각 비교 · `/boot` 여유 · 10-02 뒤 apt 이력 · 컨테이너 메모리 cgroup · 실패 분기 행 여섯(복원 실패면 같은 노드에서 다시 · cleanup만 실패 · 섞인 상태 · 전송 끊김 · reboot-required · 예정 없던 재부팅) · 블록의 읽기 파일은 `-Append`.
- **실행**: F0 10:30(읽기) · F0b 10:51(지문 — 두 노드 같은 값 `1e34f3b1…` · 10줄 · 마지막 줄 `### END /etc/grub.d/41_custom ###`) · F2 노드 B `unpin` 10:51:53 · F3 노드 A 11:22:59(둘 다 `Sourcing file`에 고정 파일 없음 · `OK verify: grub.cfg default is "0" -> 7.0.0-1012-oracle` · `OK cleanup` · `RESULT: OK unpin`) · F4 11:23(지문이 F0b와 같음 · 다음 부팅의 커널 · initrd 시각 < 부팅 시각 · `/boot` 22% · apt 이력 없음 · 커널 OOM 0 · needrestart 설치됨 · GRUB 대기 0초) · F5 11:53 시험 파드 삭제 · F7 11:53 hold 해제(사용자 결정 ①) · F8 확인(메타 셋 `ii` · 보안 포켓 후보 1012 → 그날 밤 커널 설치 없음) · 마지막 스냅샷 11:54 관문 9/9.
- **컨테이너 메모리(F4 10번 — 각 컨테이너 시작 뒤 누적)**: 노드 A의 ESO cert-controller만 회수가 있었다 — 123/128Mi · 최고 128 · 다시 읽기 708 · 회수 스캔 1,691 · `max_events` 0(컨테이너 cgroup의 `max`가 0인 것은 한도가 파드 cgroup에서 먼저 걸리기 때문으로 본다 — 미확인). 나머지 전부 회수 0. Vault 379/512Mi(최고 402) · cert-manager-webhook 68/80Mi(85%).
- **K3s 자동 업그레이드의 사후 확인**: 런북 §6 「실행 기록」에 적은 대로 ①–⑥ 전부 통과. 업그레이드 직전 백업은 두 쌍(작업 파드가 K3s 재시작에 걸려 다시 만들어지며 prepare가 한 번 더 돌았다).
- **플랫폼 하네스(11:27–11:31)**: infra 61/0 · cluster 39 통과 · 1 실패 · 10 건너뜀(`argo-4` — T056 전 통과 불가) · ingress 12/0 · reboot(평상시) 3/0/4. 백업 단언 셋은 `svc-verify` 세션이 열려 있어 통과.
- **조회 경로 15분(관찰기 하나 · 5초 간격)**: 180/180 성공 · 중앙값 2.2초 · p99 4.2초 → §10.12의 2%는 관찰기 둘을 함께 돌린 조건 탓으로 본다.
- **결정(사용자 · 한 번에 하나씩)**:
  1. **커널 정책 = hold 해제(우분투 기본)** — 컨트롤러의 권장(hold 유지 + 창을 잡아 올림)과 다르다. 받아들인 위험: 보안 커널이 자동 설치된 뒤의 계획 없는 재부팅은 검증되지 않은 커널로 간다(6.17은 그때 apt가 지운다 · 직전 커널은 부팅된 적이 있어 남는다). 런북 §6 「커널(OS 패치) 재부팅」에 주간 확인 · 계획 재부팅 절차(시험 동안만 hold) · 부팅 실패 복구 경로를 적었다.
  2. **KHO = 켜 둔 채 관찰** — §6 주간 확인에 `CmaFree` · 커널 OOM 줄.
  3. **컨테이너 메모리 한도 = T048 뒤 별도 gitops PR(T049 전)** — ESO cert-controller 128 → 256Mi · cert-manager-webhook 80 → 128Mi · Vault 512Mi 유지(T098 경보 뒤 재검토).
- **런북**: §3 요약(전체 순서 · 시간 · 시크릿 취급) · §3 T048 절 · §6 실행 기록(K3s 첫 실행) · §6 커널(OS 패치) 재부팅.
- **남은 것**: §10.14 표(도구 수정은 노드 작업이 끝났으므로 이제 해도 된다) · 결정 3의 PR · `report.md` 항목.
