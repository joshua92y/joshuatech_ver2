# T048 설계 — 재부팅 리허설 · 백업 복원 가능성 검증 · SC-001 시각 기록

> 과제 수준 설계 문서(내부 작업 자료 — 과제를 닫은 뒤에는 고치지 않는다). 공개용 요약은 `content/tmp/003-t048/`.

## 1. 과제가 요구하는 것

1. 노드 A(K3s server · `role=platform`)를 재부팅하고 `tests/platform/reboot.tests.ps1 -AfterReboot`가 PASS한다 — Vault 자동 unseal · ESO ClusterSecretStore 5개 Ready · Argo Application 전부 Healthy · ExternalSecret이 다음 refresh에 `SecretSynced`(US2 AC4).
2. 최신 백업 `.age` 둘(`k3s/` 1 · `vault/` 1)을 내려받아 운영자 개인키로 복호화하고 무결성을 확인한다 — K3s는 `PRAGMA integrity_check` → `ok`, Vault는 `vault operator raft snapshot inspect` → 메타데이터. 두 출력과 실행 시각을 런북에 남긴다. **복원 리허설이 아니다**(Vault 스냅샷은 seal 래핑이라 복원에는 같은 KMS 키가 필요하다 — 복원 절차는 T114 · vault-unseal.md §7).
3. root app apply 시각과 전 Application Healthy 시각을 기록한다(SC-001 ≤ 30분의 근거 — T049 E2E가 인용).
4. `docs/runbooks/bootstrap.md` §3을 확정한다(전체 순서 · 시간 · 시크릿 취급).

누가 하는가: 재부팅 · SSH · 개인키를 쓰는 복호화 · OCI 세션 인증은 **운영자**. 에이전트는 조회 전용 자격(`agent-view` · `svc-verify`)으로 관찰과 하네스 실행, 블록 준비, 기록을 한다. 재부팅은 라이브 변경이므로 **단계마다 사용자 재확인**을 받는다.

## 2. 조사로 확정한 사실(2026-10-01)

- **F1 재부팅 리허설은 처음이다.** 노드 A는 2026-09-04 재이미지 · K3s 설치 뒤 재부팅 기록이 없다(런북 §2 · §3). Vault 파드 재기동 드릴은 있었다(vault-unseal.md §1 — unseal 8초 · 드릴 전체 20초). 곧 이번이 "호스트가 꺼졌다 켜질 때 iptables 규칙 · k3s 서비스 · WireGuard · DNS 설정이 사람 없이 돌아오는가"의 첫 실측이다.
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

### P2. SC-001의 근거를 무엇으로 남길 것인가 — **사용자 결정 대기**

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
