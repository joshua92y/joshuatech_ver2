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
