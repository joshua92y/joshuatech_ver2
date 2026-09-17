# Runbook: vault-unseal

> **UI로 `vault operator init`을 하지 않는다.** 모든 Vault 운영 절차는 운영자 워크스테이션의 `vault` CLI + admin kubeconfig port-forward로만 수행한다.

이 문서는 Vault(ns `vault`, StatefulSet `vault`, Raft 1 replica, OCI KMS `ocikms` auto-unseal — ADR 0010, T044)의 **seal·초기화·복구·재기동·설정 변경** 절차 정본이다. 배포 정본은 platform-gitops `platform/vault/`(README 포함), 내부 설정(kv 마운트·kubernetes auth·정책 6·role 6)의 정본은 모노레포 `infra/vault/`(OpenTofu), 실행 기록은 `docs/runbooks/bootstrap.md` §3 T044 절·§4다. 이 문서는 절차와 판정 기준만 적고 값(토큰·recovery key)은 적지 않는다.

- 전제 도구(단계 0 실측 2026-09-14): 워크스테이션 `vault` CLI **v2.1.0**(winget 최신; 서버 2.0.4 — CLI가 최신이어도 HTTP 클라이언트라 호환. 설계 D3 확정: CLI 버전을 문서에 고정하지 않는다) · `kubectl` + admin kubeconfig(운영자 워크스테이션에만) · `age` · `oci` CLI(`svc-verify` 세션) · `tofu`.
- 창 표기(라이브 세션 2026-09-17과 동일): **창 A** = cloudflared 터널 · **창 B** = admin kubectl(운영) · **창 C** = port-forward · **창 D** = vault CLI(비밀 취급 — 창 시작/종료 체크리스트 필수).
- 절 구성 규약: 각 절은 목적·전제·절차·검증·되돌리기가 드러나게 쓴다(FR-041 런북 8종 · T114가 통일 형식으로 재정렬 예정). 절 번호 §0–§13은 gitops `platform/vault/README.md`·`kustomization.yaml`·`ingress.yaml`이 참조하므로 바꾸지 않는다.
- 문면 정정 3건(ADR 0010·tasks 본문은 편집하지 않고 여기에 정확한 문면을 둔다 — converge 인계, ADR 0011 예정): ① "KMS 일시 장애 = sealed 대기" → 살아 있는 프로세스는 계속 동작하고 **재시작 시 CrashLoopBackOff**(§2) ② "KMS 키 삭제 유예 30일" → **Pending Deletion 즉시 접근 불능**, 30일은 취소 창(§6) ③ "recovery key `generate-root`가 break-glass" → Vault 2.0부터 **유효 토큰이 추가로 필요**(§4·§5).
- 아직 실측되지 않은 값은 `[실측 후 채움: VD-NN]`으로 남긴다(설계 §7 VD 표 번호).

---

## §0 범위·전제 — 절대 규칙·창 체크리스트

**UI로 init 하지 않는다.** 브라우저 초기화 화면은 recovery key와 root 토큰을 화면·다운로드 파일로 남긴다. 초기화는 §4의 CLI 안전 블록 하나뿐이다.

- 목적: 비밀(recovery key 3조각·root 토큰·role 토큰)이 저장소·로그·히스토리·클립보드에 남지 않게 하는 규칙과, Vault API에 닿는 유일한 경로를 모든 절에 앞서 고정한다.
- 전제: PowerShell 7 워크스테이션. 비밀번호 관리자(PM)가 열려 있다. 컨테이너 `exec`는 쓰지 않는다(이미지에 `openssl`·`ps` 없음, PSA restricted) — 필요한 모든 확인은 port-forward + CLI/curl로 한다.

### 절대 규칙
1. `vault login`을 쓰지 않는다 — `~/.vault-token`을 만든다. 토큰은 **환경변수로만**, 입력은 마스킹으로:
   ```powershell
   $env:VAULT_ADDR  = 'http://127.0.0.1:18200'
   $env:VAULT_TOKEN = (Read-Host -AsSecureString 'VAULT_TOKEN' | ConvertFrom-SecureString -AsPlainText).TrimEnd("`r", "`n")   # PM에서 붙여넣기
   ```
2. `VAULT_ADDR`는 항상 `http://127.0.0.1:18200`을 **명시**한다(CLI 기본값은 `https://127.0.0.1:8200` — 리스너는 평문 8200, TLS 종단은 Traefik websecure + Cloudflare AOP).
3. PowerShell에서 `-flag=value` 형태 인자는 **따옴표**로 감싼다: `vault operator init "-status"` · `"-recovery-shares=3"` · `tofu plan "-out=t044.tfplan"`. 따옴표 없이 쓰면 인자가 분리되어 다른 동작을 한다(VD-03 실측: 따옴표 사용 시 `init "-status"` exit 2 정상 · `-out=` 분리 함정 실측 2026-09-17).
4. 비밀은 명령줄 리터럴·파일 리다이렉트로 다루지 않는다: 파이프 → 변수, `Read-Host -AsSecureString`, `Set-Clipboard`(클립보드 기록이 0일 때만).
5. `tofu plan` 파일(`t044.tfplan` 등)은 인가 지도라 창 종료 시 삭제하고 `%TEMP%`에 plan JSON을 쓰지 않는다.
6. Ingress `vault.joshuatech.dev`는 `/` Prefix라 Access를 통과한 브라우저 세션에 `/v1/*` API 전체가 열린다. **US4(Authentik OIDC) 전까지 Cloudflare Access(GitHub IdP) + AOP가 UI의 유일한 방어선**이다 — Access 앱 `vault` 존재(단계 0 실측).
7. 원격 명령(`ssh ssh-a "…"`)에 `$?`·`$p`를 넣지 않는다 — PowerShell이 먼저 치환한다(`echo exit=\$?` 실측). 원격 명령은 리터럴 here-string(`@'…'@`)으로.

### 비밀이 새는 5곳
| 곳 | 닫는 방법 |
|---|---|
| PSReadLine 히스토리 | 모든 새 창 첫 줄 `Set-PSReadLineOption -HistorySaveStyle SaveNothing` |
| `Start-Transcript` | `$Transcript`는 **자동 변수가 아니다**(비어 있다고 전사 없음이 아님) → `try { Stop-Transcript } catch {}`로 프로브하고 정책 전사 레지스트리를 읽는다(아래 체크리스트) |
| 클립보드 기록(Windows 클립보드 히스토리) | `EnableClipboardHistory`가 0이어야 `Set-Clipboard` 경로를 쓴다(단계 0 실측 ON → 2026-09-16 결정: **OFF로 바꾼 뒤** `Set-Clipboard` 경로; 단계 9 직전 0 재확인) |
| SSH 스크롤백(노드 A `ssh-a` 세션) | 노드에서는 비밀을 출력하지 않는다(init·토큰 작업은 노드 A가 아니라 워크스테이션) |
| 대화 로그(에이전트 세션) | 에이전트는 admin kubeconfig·root 토큰을 받지 않는다; 값을 채팅에 붙여 넣지 않는다 |

### 창 시작 체크리스트(창 B·C·D 첫 줄)
```powershell
Set-PSReadLineOption -HistorySaveStyle SaveNothing
try { Stop-Transcript } catch {}      # "현재 전사 중이 아닙니다" 오류가 정상. 경로가 출력되면 전사가 켜져 있던 것 → 그 파일 삭제 후 새 창
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription','HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -ErrorAction SilentlyContinue | ForEach-Object EnableTranscripting   # 값 없음/0
(Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory   # 0 이어야 비밀 취급 진행
$env:KUBECONFIG = "$HOME\.kube\joshuatech-admin.yaml"; kubectl config current-context                        # default (빈 컨텍스트면 create token이 localhost:8080 404)
```

### 창 종료 체크리스트(창 D)
```powershell
Remove-Item Env:VAULT_TOKEN, Env:VAULT_ADDR -ErrorAction SilentlyContinue
Remove-Item D:\code\joshuatech_ver2\infra\vault\t044.tfplan -ErrorAction SilentlyContinue
Test-Path "$env:USERPROFILE\.vault-token"    # False
# 창 C(port-forward) 종료 · 창 A 터널 리스너 종료 + ~/.cloudflared 캐시 토큰 삭제(.claude/rules/infra.md)
```

### 도달 경로(유일)
```powershell
# 창 C(admin kubeconfig): 세션 동안 열어 둔다 — pod 교체(§1 드릴·§10·§11-b) 뒤에는 끊기므로 재수립
kubectl -n vault port-forward svc/vault 18200:8200

# 창 D(창 시작 체크리스트 뒤)
$env:VAULT_ADDR = 'http://127.0.0.1:18200'
curl.exe -s -o NUL -w "%{http_code}`n" http://127.0.0.1:18200/v1/sys/seal-status   # 200 (VD-11 실측 200, 2026-09-17)
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status                            # 해석은 §1
vault status; $LASTEXITCODE                                                      # 0 unsealed · 2 sealed · 1 오류
```

- Service `vault`는 `publishNotReadyAddresses: true`라 **미초기화·봉인 중(파드 NotReady, `Running 0/1`)에도 엔드포인트가 남는다** — port-forward와 Ingress가 장애 시점에 끊기지 않는 근거. `vault-active`/`vault-standby` Service는 만들지 않는다(봉인 중 엔드포인트 0).
- **agent-view는 seal-status 읽기만**: 같은 port-forward(agent-view kubeconfig — ns `vault` `pods/portforward` 허용, hostnames-and-access.md :59)로 `GET /v1/sys/seal-status`(인증 불요). `exec`·Secret get·`serviceaccounts/token` create 없음(§12).
- `platform-backup.sh`(노드 A)는 자체 port-forward(18200–18299 중 빈 포트)로만 Vault에 닿는다 — 공개 호스트·파드 IP 금지(`.claude/rules/infra.md`).
- 계약 :59의 `port-forward svc/vault 8200`(로컬 8200)과 이 문서의 `18200:8200`은 로컬 포트만 다르다. 이 문서는 18200으로 통일한다(워크스테이션의 다른 도구와 8200 충돌 회피 — converge에서 계약 :59 표기 정합 후보).
- 검증: seal-status HTTP **200**. `400`이면 XFF 스탠자(`x_forwarded_for_*`)가 들어간 설계 위반(설계 D9 — 헤더 없는 경로 readinessProbe·port-forward·백업·ESO·metrics가 전부 거절) → 즉시 중단하고 gitops values를 대조한다.
- 되돌리기: 해당 없음(규칙). 규칙을 어긴 값(히스토리·파일에 남은 토큰)은 **폐기 대상**으로 간주하고 회전한다(`secret-rotation.md`, T084). port-forward 종료는 라이브 영향 없음(CRI 스트리밍 loopback — NetworkPolicy 미경유).

---

## §1 정상 상태와 판정

- 목적: `GET /v1/sys/seal-status` 필드 조합으로 정상/장애/사고를 즉시 판정하고, 파드 재생성 뒤 무인 unseal(무인 복구의 최소 단위)을 같은 게이트로 증명한다.
- 전제: §0 port-forward.

### 해석표
| `initialized` | `sealed` | `type` | 의미 | 조치 |
|---|---|---|---|---|
| `false` | `true` | `ocikms` | 미초기화. 첫 배포(G1 머지 직후) 또는 **PVC `data-vault-0`이 사라진 뒤 재생성**된 상태(§11-b) | 첫 배포·의도한 재init이면 §4 안전 블록. 의도하지 않았는데 보이면 데이터 소실 사고 — §11 → §7 복원 |
| `true` | `false` | `ocikms` | **정상**(auto-unseal 완료) | 없음 |
| `true` | `true` | `ocikms` | 비정상. auto-unseal은 기동 직후 수 초 외에 이 상태에 머물지 않는다 | 60초 뒤 재조회 → 지속이면 §3. §8 마이그레이션 진행 중이면 정상(`-migrate` 대기) |
| 연결 거부 / 파드 `CrashLoopBackOff` | — | — | **seal 설정 실패 = 프로세스 즉사**(KMS 도달·인가·값 오류) | §3 진단 순서. init·kv 작업으로 넘어가지 않는다 |
| any | any | `shamir` 또는 다른 값 | seal 스탠자가 렌더되지 않았거나(HCL 오타·values 키 오타는 스키마가 잡지 못한다) §8 이후 | 중단. `kustomize build --enable-helm platform/vault` 렌더와 ConfigMap `vault-config` 대조 |

### T044 실측(2026-09-17, init 뒤 — cluster `vault-cluster-d3b29227`)
- `initialized:true` · `sealed:false` · `type:"ocikms"` · `t:2` · `n:3` · `recovery_seal:true` · `recovery_seal_type:"shamir"` · `storage_type:"raft"`(VD-14). init 전(단계 8)은 `initialized:false` · `sealed:true` · `type:"ocikms"` · `recovery_seal:true` · `storage_type:"raft"`.
- `vault status` exit 코드(readinessProbe가 쓰는 값): 0 = unsealed, 2 = sealed, 1 = 오류. 미초기화·봉인 중 파드가 `Running 0/1`(NotReady)인 것은 **정상**이고 Argo Application `platform-vault`는 `Progressing`(Degraded 아님)이다. 그 창 동안 cluster.tests argo-1이 FAIL하고 root app-of-apps가 Healthy를 잃는다 — 이 창에서는 `clusters/oci-k3s/apps/` PR을 머지하지 않는다.
- **2.0.4 기동 배너에는 `Seal Type` 줄이 없다**(2026-09-17 실측 — 설계·초안의 "`Seal Type: ocikms` 1회" 기대는 오류). seal 종류는 seal-status의 `type`으로 본다. 미초기화 상태에서는 5초마다 `stored unseal keys are supported, but none were found` WARN이 정상(= auto-unseal seal 구성됨 + init 전)이고 error는 0행이다(VD-10).
- 지표: `VaultSealed` = `vault_core_unsealed == 0`(전제: HCL `telemetry { disable_hostname = true }` — 없으면 지표명에 호스트 접두가 붙어 규칙이 성립하지 않는다). CrashLoop처럼 지표 자체가 사라지는 경우는 FR-040 13번째 `MetricsAbsent`(`absent(vault_core_unsealed)` 30m)가 덮는다(T098 등록 확인). 지표 실측(VD-16 — `curl …/v1/sys/metrics?format=prometheus | Select-String '^vault_core_unsealed'` 60s×5 → `1` 5/5, 1m 보존에서 결측 없음)은 **T044에서 실행하지 않았다** — 스크레이프 주기 ≤30s 확정과 함께 T098로 인계한다.

### 재기동·auto-unseal 드릴(단계 11 · §10 설정 변경마다 같은 게이트)
- 전제: 위 정상 상태 · KMS 장애 창이 아님(§2 — 장애 중 재시작은 CrashLoop) · SUC 창 밖 · admin kubeconfig(`delete pod`는 운영자만).
```powershell
kubectl -n vault delete pod vault-0; $t1 = Get-Date                                       # 운영자(admin), 기본 grace — 강제 종료 금지
kubectl -n vault get pod vault-0 -w                                                       # ContainerCreating → Running 0/1 → 1/1 (Ctrl+C)
"재기동 소요 $((Get-Date) - $t1)"
# 창 C 재수립 후
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status                                    # sealed:false · type:ocikms · initialized:true
kubectl -n vault get events --field-selector involvedObject.name=vault-0 | Select-String 'FailedPreStopHook|Unhealthy|BackOff|Error'
kubectl -n vault get pod vault-0 -o jsonpath='{.spec.nodeName} {.spec.volumes[?(@.name=="data")].persistentVolumeClaim.claimName}{"\n"}'   # 노드 A · data-vault-0
```
- 게이트: 90–180초 안에 `sealed:false` · 파드 `1/1 Running` · 같은 PVC `data-vault-0` 재부착 · 노드 A. **T044 실측(VD-17 PASS, 2026-09-17)**: 파드 삭제 → **8초** 만에 `1/1`(드릴 총 **20초**) · 같은 PVC · `FailedPreStopHook` 없음(`Killing`·readiness 취소 이벤트만).
- `FailedPreStopHook`이 보이면 **무해**하다(차트 기본 preStop이 `pidof vault`를 부르는데 이미지에 `pidof`가 없을 수 있어 훅이 실패하고 SIGKILL로 종료 — Raft는 크래시 세이프). 다만 기록하고 `server.preStop` 대체를 검토한다.
- sealed 유지·CrashLoop이면 **즉시 중단** → §3. 백업·kv·T045로 진행하지 않는다.
- 되돌리기: 없음(파드 재생성). 라이브 영향: 재기동 동안 Vault 무응답(실측 8초 만에 Ready · 드릴 총 20초; 설계 가정 30–90초) — ESO는 마지막 Secret 유지(T045 이후).

---

## §2 KMS 일시 장애 — 살아 있으면 그대로 둔다

- 목적: KMS(crypto/management 엔드포인트·IAM·IMDS) 일시 장애 창에서 Vault를 **더 나쁘게 만들지 않는** 규율을 고정한다.
- 전제: §1 정상 상태였다가 KMS 경로 알림(`VaultSealed`는 발화하지 않을 수 있다 — 아래)이 왔거나, OCI 상태 페이지·콘솔에서 KMS 장애가 확인됐다.

### 정정 문면(ADR 0010 §4·tasks "KMS 일시 장애 = sealed 대기"는 부정확 — 이 문면이 정본)
- **살아 있는 Vault는 그대로 둔다.** unseal된 프로세스는 루트 키를 메모리에 갖고 있어 KMS 장애 중에도 계속 서비스한다(설계 §3.2 — KMS 장애 리허설은 없으므로 미실측). ESO는 마지막 Secret을 유지해 기존 파드는 정상이고 **신규 기동·갱신만 멈춘다**(T045 이후).
- **재시작·재기동 = seal 설정 실패 = CrashLoopBackOff**(seal-status는 연결 거부). "sealed 대기"가 아니다 — Vault는 seal 설정 실패 시 시작 자체를 중단한다.
- 알림: `VaultSealed`(`vault_core_unsealed == 0`)는 프로세스가 살아 있는 한 발화하지 않는다. 재시작 실패는 지표 결측이므로 FR-040 `MetricsAbsent`(`absent(vault_core_unsealed)` 30m)가 잡는다(T098 등록 확인).

### 창 동안 하지 말 것
- `kubectl -n vault delete pod vault-0`(§1 드릴·§10 절차·§11-b 재init 전부 금지).
- Shamir 전환(§8) — 이행에도 기존 seal(KMS) 도달이 필요하다.
- 재init — 데이터가 살아 있다.
- SUC 창(일 03:00–05:00 Asia/Seoul, Plan `k3s-server`/`k3s-agent`) 진입 전이면 노드 라벨로 Plan 비활성: `kubectl label node joshtech-api joshtech-cache plan.upgrade.cattle.io/k3s-server=disabled plan.upgrade.cattle.io/k3s-agent=disabled --overwrite`(창이 끝나면 라벨 제거 — bootstrap.md §6).

- 검증: 장애 해소 뒤 §1 해석표 정상 행. 장애 중 `sealed:false`가 유지되는 것은 정상이다.
- 되돌리기: 해당 없음(무개입이 절차다). 장애 중 재기동이 일어났으면 CrashLoop이 기대 동작이다 — 데이터는 PVC에 있으므로 재init하지 말고 KMS 복귀 뒤 §3 → §1 게이트로 확인한다(KMS 장애 리허설 없음 — 미실측).

---

## §3 sealed/CrashLoop 진단 순서

- 목적: `CrashLoopBackOff`/연결 거부를 원인별로 **순서대로** 좁힌다. 순서를 건너뛰지 않는다 — 앞 항목이 뒤 항목의 증상을 만든다.
- 전제: agent-view로 로그·이벤트를 읽을 수 있다(`pods/log` get). 변경은 전부 gitops PR 또는 운영자 `tofu apply`(`infra/oci`)다.

### 로그 grep(먼저)
```powershell
kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault get pod vault-0 -o wide          # 노드 · 상태 · 재시작 수
kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault logs vault-0 --previous --tail=200 |
  Select-String 'none were found|ocikms|error parsing Seal|failed key_id validation|x509|IMDS|instance principal|NotAuthorizedOrNotFound|no such host|timeout|error'
kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault get events --field-selector involvedObject.name=vault-0 --sort-by=.lastTimestamp | Select-Object -Last 20
```
정상 기동 로그는 error 0줄이다(2.0.4는 `Seal Type` 배너 줄이 없다 — §1). init 전이면 `stored unseal keys are supported, but none were found` WARN이 5초마다 반복되는 것이 정상(VD-10 실측 2026-09-17).

### 판별 순서
| # | 원인 | 증상(로그) | 확인 | 조치 |
|---|---|---|---|---|
| 1 | **seal 3값 오타**(`key_id`·`crypto_endpoint`·`management_endpoint`) | `error parsing Seal configuration` · `failed key_id validation` · 404 | ConfigMap 대조: `kubectl -n vault get cm vault-config -o yaml`의 seal 스탠자 ↔ 운영자 `tofu -chdir=infra/oci output -raw kms_key_id` / `kms_crypto_endpoint` / `kms_management_endpoint`(운영자만 읽는다). key OCID의 5번째 세그먼트가 두 엔드포인트 호스트 접두와 같아야 한다(같은 볼트). `auth_type_api_key = "false"`(인스턴스 프린시펄)인지 함께 본다 | gitops PR로 값 수정 → 머지 → §10(파드 삭제). HCL은 `tpl` 렌더라 `{{ }}` 금지 |
| 2 | **IMDS 미도달**(`169.254.169.254:80` `/opc/v2`) | `x509`·`instance principal`·`federation` 실패, 169.254.169.254 timeout | ns `vault` NetworkPolicy `allow-imds`(vault 전용) 존재: `kubectl -n vault get networkpolicy` · 노드 A에서 `ssh ssh-a "curl -s --max-time 3 -o /dev/null -w '%{http_code}' -H 'Authorization: Bearer Oracle' http://169.254.169.254/opc/v2/instance/"` = 200(IMDSv2, v1은 비활성) | NetworkPolicy는 `platform/policies` 소유 — 계약 `network-policy.md` 개정 뒤 PR |
| 3 | **DNS**(KMS crypto/management 엔드포인트 · `auth.ap-chuncheon-1.oraclecloud.com`) | `no such host` · NXDOMAIN | `ssh ssh-a "nslookup <엔드포인트 호스트>"` · CoreDNS 로그. 선례: T010 NXDOMAIN **부정 캐시**(TTL 만료 대기 또는 CoreDNS 재시작 — 운영자). 단계 0 실측(2026-09-14): 엔드포인트 3종 모두 **공인 IP**(crypto 140.204.52.131 · management 140.204.52.195 · auth 140.204.52.181/.165 — 사설 대역 0, `allow-egress-external-443`의 RFC1918 except에 걸리지 않는다) | 부정 캐시면 대기 · 사설 대역으로 바뀌면 network-policy.md 개정 선행 |
| 4 | **IAM**(동적 그룹 `joshuatech-node-a` = 노드 A 인스턴스 OCID **1개** · 정책 `use keys` + `target.key.id`) | `NotAuthorizedOrNotFound`(Encrypt/Decrypt/GetKey) | OCI 콘솔(운영자): 동적 그룹 matching_rule의 OCID = 현재 노드 A 인스턴스 OCID인가(노드 A **재생성**은 OCID가 바뀐다) · KMS 키 상태 **Enabled**(Pending Deletion이면 §6) · `svc-verify`는 KMS·동적 그룹 읽기 권한이 없다 — 콘솔로 | 노드 재생성이면 `tofu -chdir=infra/oci plan`(0 destroy) → 운영자 apply **선행** |
| 5 | **노드 B 스케줄** | 파드 노드가 `joshtech-cache`(role≠platform) → 4와 같은 오류 | `get pod -o wide` · STS `nodeSelector: role=platform` 존재 | values 수정 PR. 노드 B에는 KMS 권한이 구조적으로 없다(동적 그룹 밖) — nodeSelector는 편의가 아니라 **가용성 조건** |

### 되돌리기(순서 고정 — gitops README §5 · §11-a와 동일)
revert 머지 → 렌더 0(Application은 `prune: false`라 객체가 남는다) → ① `kubectl -n vault delete ingress vault`(**G2 머지 이후에만 해당** — 공개 진입점 먼저) → ② `kubectl -n vault delete sts vault --cascade=orphan` → ③ `kubectl -n vault delete pod vault-0` → ④ Service·ConfigMap·SA·RBAC 수동 정리 → ⑤ **PVC `data-vault-0`과 PV는 절대 지우지 않는다**(§11).

- 검증: 원인 제거 뒤 §1 재기동 게이트(`sealed:false` 90–180초 내).
- 라이브 영향: 진단은 읽기 전용. 조치는 전부 PR/tofu 경유.

---

## §4 root 토큰·init 취급

- 목적: `vault operator init`을 **출력 유실 없이** 수행하고 recovery key 3/2와 root 토큰을 오프라인(PM)에 보관하며, root의 사용 범위·보관·revoke 시점과 정례 확인 방법을 고정한다.
- 전제: vault-0이 노드 A에서 `Running 0/1`(§1 첫 행, `initialized:false`) · 사용자 입회 · 창 D 창 시작 체크리스트 · PM 열림 · **클립보드 기록 0**. init은 **불가역**이다(되돌리기 = PVC 삭제 = §11-b 재init = 시드 전부 재투입).
- ADR 0010 §6 ③에 해당. 순서: ② helm(G1 머지) → **③ init** → ④′ audit(§9, CLI 1회) → ④ `infra/vault` apply → ⑤ ESO(T045).

### 사전 점검(단계 8)
```powershell
# 창 C: kubectl -n vault port-forward svc/vault 18200:8200
$env:VAULT_ADDR = 'http://127.0.0.1:18200'
curl.exe -s -o NUL -w "%{http_code}`n" http://127.0.0.1:18200/v1/sys/seal-status      # 200 (VD-11)
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status; ''                              # initialized:false · sealed:true · type:"ocikms"
vault operator init "-status"; "exit=$LASTEXITCODE"                                     # 2 기대 (VD-03)
"$(Get-Date -Format o) initialized:false 확인"                                          # 경과 시간 산출용 — bootstrap.md에 기록
```
- `init "-status"` exit 의미: **2 = 미초기화(정상, 인자 전달도 정상)** · **0 = 이미 초기화됨 → 중단, 아래 '이미 초기화됨'** · 1 = 오류(주소·연결). `-recovery-shares/-threshold`는 auto-unseal에서만 유효하므로 인자가 먹혔다는 사실이 seal=ocikms의 간접 증거다.

### 이미 초기화됨(`init "-status"` exit 0 · 또는 init이 "already initialized"로 거부)
1. 즉시 중단. 아무것도 쓰지 않는다.
2. 정상 케이스 구분: 이전 init의 PVC `data-vault-0`이 되돌리기(§11-a ⑤)에서 살아남아 재부착된 경우 — PM에 그 init의 항목 4개가 있어야 한다. 있으면 그 root 토큰으로 `vault token lookup`이 성공하는지 확인하고 다음 단계로 진행한다.
3. PM에 항목이 없으면 두 갈래: (a) **직전 init의 산출물을 잃은 것**(아래 사고 기록) — 마운트·정책·시드가 0이면 복구는 §11-b 재init뿐이다. (b) **제3자 init 사고** — D7 B에서 Ingress는 G2(init 뒤)라 브라우저 경로는 없고, 남는 경로는 클러스터 내부 8200(NetworkPolicy 허용 ns = kube-system·external-secrets·monitoring)뿐이다 — 해당 ns 파드·Argo 감사 로그·`kubectl get events -n vault`를 조사하고 §11-b로 복구한다. 조사 결과는 bootstrap.md §3에 남긴다.

### 사고 기록(2026-09-17 10:27–10:31 KST) — 이 절의 안전 블록이 존재하는 이유
- G1 머지 10:18:34 KST → 단계 8 PASS → 10:27:42 init **성공**(t:2 n:3 · `recovery_seal_type:"shamir"` · cluster `vault-cluster-832ae26d`). 그러나 운영자가 초안의 3단 블록을 **통째로 실행**했다: PM 붙여넣기 지점이 주석으로만 표시돼 멈추지 않았고, 해시 검증 3건이 False로 흘러갔으며, `Read-Host`가 빈 입력을 받은 채 (3) 소거가 **무조건** 실행되어 `$init`이 삭제되고 클립보드가 `' '`로 덮였다. 재실행은 "already initialized" → `$init` null.
- 결과: **recovery key 3조각·root 토큰 영구 유실**(클립보드 기록 OFF·전사 없음·SaveNothing이라 어디에도 사본이 없다 — 비밀 취급 규칙이 잘 지켜진 만큼 복구 경로도 0). 마운트·정책·시드가 0이었으므로 복구 = Raft 스토리지 초기화(§11-b: PVC 삭제 + pod 재생성) → 재init(11:09:13 KST, cluster `vault-cluster-d3b29227`).
- 근본 원인 3가지: (a) 사람 동작(PM 저장)이 주석으로만 표시됨 (b) 소거가 검증 결과에 조건부가 아님 (c) 한 블록에 담겨 통째 실행이 가능함. 개선 = 아래 안전 블록(Read-Host 강제 정지 + 항목별 되가져오기 해시 반복 + 조건부 소거). 교훈의 선례: bootstrap.md §3 T040 ⑥ argocd 비밀번호 유실.

### init 안전 블록(정본 — 통째로 붙여 넣어도 안전; 단계 9′에서 실측 4/4)
3단 게이트 원리: **(a)** 사람 동작마다 `Read-Host`로 멈춘다 **(b)** 항목마다 PM에서 되가져온 값의 SHA-256이 원본과 같을 때까지 반복한다 **(c)** 4/4 일치 + PM 사본 root 토큰으로 `lookup` 성공일 때만 소거한다 — 아니면 변수를 남기고 멈춘다 **(d)** 값은 화면에 출력하지 않는다.
```powershell
# ===== T044 단계 9 (재init) 안전 블록 — 통째로 붙여 넣어도 안전 =====
# 원칙: (a) 사람 동작(PM 저장)마다 Read-Host로 멈춘다 (b) 항목마다 PM에서 되가져온 값의 SHA-256이 원본과 같을 때까지 반복한다
#       (c) 4/4 일치 + PM 사본 root 토큰으로 lookup 성공일 때만 소거한다 — 아니면 변수를 남기고 멈춘다 (d) 값은 화면에 출력하지 않는다
# 전제: 창 D · VAULT_ADDR=http://127.0.0.1:18200 · 창 C port-forward · 클립보드 기록 0 · seal-status initialized:false
if ((Get-ItemProperty HKCU:\Software\Microsoft\Clipboard).EnableClipboardHistory -ne 0) { throw '클립보드 기록이 켜져 있음 — 끄고 다시' }
$pre = curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status | ConvertFrom-Json
if ($pre.initialized) { throw "이미 initialized:true — init 하지 않는다(사고 처리)" }

$init = vault operator init "-recovery-shares=3" "-recovery-threshold=2" "-format=json" | ConvertFrom-Json
if (-not $init -or [string]::IsNullOrEmpty($init.root_token) -or @($init.recovery_keys_b64).Count -ne 3) { throw 'init 출력이 비정상 — 변수 유지, 진행 중단' }
"$(Get-Date -Format o) init 완료 · recovery_keys=$(@($init.recovery_keys_b64).Count) · root_token_len=$($init.root_token.Length)"
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status; ''

$sha = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes(([string]$s).TrimEnd("`r", "`n")))) }
$items = @(
  @{ name = 'T044 vault recovery 1/3 (threshold 2)'; value = [string]$init.recovery_keys_b64[0] },
  @{ name = 'T044 vault recovery 2/3 (threshold 2)'; value = [string]$init.recovery_keys_b64[1] },
  @{ name = 'T044 vault recovery 3/3 (threshold 2)'; value = [string]$init.recovery_keys_b64[2] },
  @{ name = 'T044 vault root token (revoke: T084 OIDC admin + break-glass 드릴 뒤, D4)'; value = [string]$init.root_token }
)
$ok = 0
foreach ($it in $items) {
  $matched = $false
  do {
    Set-Clipboard -Value $it.value
    $ans = Read-Host "[$($it.name)] 가 클립보드에 있음 → PM에 새 항목으로 붙여넣고 저장 → PM을 닫았다 다시 열어 그 항목을 '복사'한 뒤 Enter (중단하려면 q)"
    if ($ans -eq 'q') { throw '사용자 중단 — 변수 유지(소거 안 함)' }
    $back = (Get-Clipboard -Raw) -as [string]
    $matched = ((& $sha $it.value) -eq (& $sha $back))
    if ($matched) { $ok++; "OK   $($it.name)" } else { "FAIL $($it.name) — PM에서 복사한 값이 원본과 다름(길이 원본 $($it.value.Length) / 클립보드 $(([string]$back).Length)). 다시 시도" }
  } until ($matched)
}
"저장·되가져오기 일치: $ok/4"

Remove-Item Env:VAULT_TOKEN -ErrorAction SilentlyContinue
$env:VAULT_TOKEN = (Read-Host -AsSecureString 'PM의 root token 항목을 복사해 붙여넣기' | ConvertFrom-SecureString -AsPlainText).TrimEnd("`r", "`n")
$lk = vault token lookup -format=json | ConvertFrom-Json
$rootOk = ($lk -and ($lk.data.policies -contains 'root'))
"lookup: policies=$($lk.data.policies -join ',') display_name=$($lk.data.display_name) rootOk=$rootOk"

if ($ok -eq 4 -and $rootOk) {
  Set-Clipboard -Value ' '; Remove-Variable init, items, back, it -ErrorAction SilentlyContinue
  "WIPED — 메모리·클립보드 소거 완료 · .vault-token=$(Test-Path "$env:USERPROFILE\.vault-token")"
} else {
  "NOT WIPED — 검증 미통과(ok=$ok rootOk=$rootOk). `$init 은 이 창에 남아 있다. 창을 닫지 말고 보고할 것"
}
```
- PM 항목 4개는 각각 별도 항목이다(이름은 블록의 `$items`). `recovery_keys_b64`는 base64 문자열 3개(`recovery_keys_hex`는 같은 조각의 hex 표기 — 하나만 보관), `root_token`은 토큰 문자열 1개. 값은 이 문서·기록·채팅 어디에도 적지 않는다.
- 게이트: `initialized:true` · `sealed:false` · `type:"ocikms"` · 되가져오기 일치 **4/4** · PM 사본 root로 `lookup` policies=root · `WIPED` 출력 · `.vault-token` False · 사용자가 항목 4개 저장을 구두 확인. **경과 시간**(`initialized:false` 확인 → init)을 bootstrap.md에 기록. `NOT WIPED`면 창을 닫지 않고 `$init`을 유지한 채 원인을 본다.
- 라이브 영향: vault-0 Ready → Application Healthy → argo-1 적색 창 종료.
- 되돌리기: **없음**(불가역). 실패(sealed 유지·CrashLoop)면 §3으로 가고 뒤 절차로 진행하지 않는다.

### recovery key와 root 토큰의 의미(정정 문면 포함)
- recovery key 3/2는 **unseal 수단이 아니다**. auto-unseal에서 봉인 해제는 KMS가 한다. recovery key의 용도는 `generate-root`·rekey이며, **Vault 2.0부터 `sys/generate-root`·`sys/rekey`는 recovery key 조각과 함께 유효한 Vault 토큰을 추가로 요구한다**(§5). 따라서 root를 revoke하고 다른 관리 경로(OIDC admin·break-glass role)가 없으면 recovery key만으로는 아무것도 할 수 없다 — ADR 0010 §6 "recovery key generate-root뿐"·FR-041 break-glass 정의는 2.0에서 성립하지 않는다(정정 후보, ADR 0011 예정).
- root 사용 범위: audit enable(§9) · `infra/vault` 최초 apply(마운트·auth enable은 sudo) · kv 시드(T045)와 플레이스홀더 투입 · 스냅샷 복원(§7) · 스모크 토큰 revoke. 그 밖의 일상 작업(정례 plan·kv 읽기 게이트)은 read 전용 정책 토큰 또는 T084 뒤 OIDC admin으로.
- 보관·revoke(D4 확정): **T044에서 revoke하지 않는다.** T045 시드도 root로 하되 revoke하지 않는다. revoke 시점 = **T084**(Vault OIDC auth role `admin` + 실제 관리 작업 실증) + break-glass 드릴(예정 role `vault-break-glass`, §5) **뒤**. 그때까지 PM 오프라인 보관, PM 항목 이름에 revoke 조건이 적혀 있다. 감수 위험: 초기 root의 유효 창이 길어진다(설계 §2.10 D4). bootstrap.md §0 토큰 표 ⑥ "부트스트랩 직후 revoke"는 이 결정으로 **정정 대상**이다(converge → ADR 0011).
- revoke 절차(시점이 오면): 대체 경로로 `vault token lookup` 성공을 먼저 확인 → root 창에서 `vault token revoke -self` → PM 항목은 삭제하지 않고 `revoked YYYY-MM-DD`로 표기 → 그 뒤 root 사본으로 `vault token lookup`이 403인지 확인.

### 토큰 표(누가 어떤 토큰으로 무엇을 하는가 — 상시 토큰 0 원칙과 D4 예외)
| 신원 | 종류 | 발급 | 정책(요지) | TTL | 보관·폐기 |
|---|---|---|---|---|---|
| **root** | init 산출 | 이 절 1회 | 전권. 사용 범위는 위 | 없음 | PM 오프라인. revoke = T084 + break-glass 드릴 뒤(D4). 사용은 항상 `Read-Host -AsSecureString` → env |
| `eso-platform` · `eso-dev` · `eso-prod` · `eso-data` | K8s auth role | ESO 컨트롤러가 TokenRequest(T045) | 각 scope의 `kv/data/<scope>/…` + `kv/metadata/<scope>/…` **read만**(eso-data는 열거 접두 20개 `…/<component>/*` — env·세그먼트 와일드카드 `kv/data/dev/*`·`kv/data/+/db/*`는 없음) | token 1h / max 4h · `service` | 저장 없음. bound SA = `external-secrets/<role 이름>` · audience `vault` |
| `vault-backup` | K8s auth role | 노드 A `platform-backup.sh`: `k3s kubectl -n vault create token vault-backup --audience vault --duration=10m` → `auth/kubernetes/login` | `sys/storage/raft/snapshot` **read**(= `snapshot save`) · `snapshot-force` deny · 복원 불가(VD-18 실측 read/deny) | 1h / 4h | 스크립트가 `revoke -self`. bound SA = `vault/vault-backup`(K8s RBAC 0) |
| `e2e-reader` | K8s auth role | 운영자 `kubectl create token agent-view -n kube-system --audience vault --duration=1h`(§12) | `kv/data/platform/authentik/e2e` read 1줄 | 1h / 4h | tester env로만. bound SA = `kube-system/agent-view` |
| (예정) OIDC `admin` | Authentik OIDC auth | T084(US4 뒤) | 관리 경로(정례 plan·kv 실값 교체·게이트 1) | 단기(기본 1h) | 상시 토큰 없음 — 토큰 표 ⑥ 원칙의 본 모습 |
| (예정) `vault-break-glass` | K8s auth role(7번째 — **converge 추가 task**, 아직 없음) | admin kubeconfig `kubectl create token vault-break-glass -n vault --audience vault` | `sys/generate-root/*` · `sys/rekey/*` update만 | 단기 | 저장 토큰 0(비root 토큰은 max TTL 32일이라 오프라인 보관 불가). quorum 드릴은 §5 |

- 원칙: 사람 상시 토큰 0(토큰 표 ⑥). 초기 root는 D4에 따른 **한시 예외**다. 어떤 role에도 `token_no_default_policy`를 걸지 않는다(ESO의 lookup-self/revoke-self·백업의 revoke-self가 내장 `default`에만 있다).
- 실측(2026-09-17 단계 12): `vault list auth/kubernetes/role` = 6 · `vault policy list` = 정책 6 + 내장 `default`·`default-ceiling`·`root` · `vault secrets list`에 2.0.4 기본 `agent-registry/`가 있다(우리 것이 아니다 — 지우지 않는다).

### 정례 드리프트 확인(`infra/vault`) — sudo 불요
```powershell
# 창 C port-forward · 창 D 창 시작 체크리스트 · VAULT_ADDR/VAULT_TOKEN env(§0)
$env:AWS_REQUEST_CHECKSUM_CALCULATION = 'when_required'
tofu -chdir=D:/code/joshuatech_ver2/infra/vault init
tofu -chdir=D:/code/joshuatech_ver2/infra/vault plan          # 기대: No changes
```
- `vault_auth_backend` refresh는 `sys/mounts/auth/<path>`(+`/tune`) **읽기**라 Vault 2.0.4에서 sudo가 필요 없다(vault/api sys_auth.go — `infra/vault/main.tf` 주석). enable/disable(`sys/auth/<path>` POST·DELETE)만 sudo이고, 감사 장치(`sys/audit`)는 read도 sudo라 tofu 밖(§9)이다. 따라서 정례 plan은 **read 전용 정책 토큰**으로 돈다 — 경로 목록은 `infra/vault/main.tf`의 주석(`sys/mounts/auth/kubernetes{,/tune}` · `sys/mounts/kv{,/tune}` · `auth/kubernetes/config` · `auth/kubernetes/role/*` · `sys/policies/acl/*` + child 토큰용 `auth/token/create`). 그 정책·role은 아직 없다(T084 OIDC admin 또는 converge 추가) — 그 전까지는 root로 돈다. 이것이 `infra/vault`의 **유일한 드리프트 그물**이다(하네스는 무자격 `validate`까지만). Vault main이 `sys/mounts/auth/+/tune`을 root-protected로 승격했으므로 업그레이드 시 재확인.
- 상태 파일에 비밀이 없어야 한다(문자 클래스는 이 문서가 비밀 패턴 게이트에 걸리지 않게 한 표기 — 정규식 의미는 같다):
  ```powershell
  tofu -chdir=D:/code/joshuatech_ver2/infra/vault state pull | Select-String 'BEGIN (RSA |EC |)PRIVATE[ ]KEY|eyJhbGciOi|AGE-SECRE[T]-KEY' | Measure-Object   # Count 0
  ```
  실측(2026-09-17, VD-23): **0행**. apply는 `plan "-out=t044.tfplan"` → **15 add / 0 change / 0 destroy** → `apply t044.tfplan` 15 added(accessor `kv_49afbd61` · `auth_kubernetes_1812c21e`) → plan 파일 삭제.
- 부분 적용 복구(`backend.tf` 3b): 재apply가 "path is already in use at kv/ | kubernetes/"로 실패하면(마운트·auth 2개는 upsert가 아니다; config·policy·role 13개는 재apply로 수렴) `tofu -chdir=infra/vault import vault_mount.kv kv` · `tofu -chdir=infra/vault import vault_auth_backend.kubernetes kubernetes` → plan이 0 destroy인지 확인한 뒤 apply. `vault secrets disable`로 "정리"하지 않는다.
- 로그인 스모크(부트스트랩 1회, 실측 2026-09-17): vault-backup 로그인 성공 + `token capabilities … sys/storage/raft/snapshot` = read / `snapshot-force` = deny(VD-18) · e2e-reader `kv/data/platform/authentik/e2e` = read, `vault read`·`vault kv get` 둘 다 정책 통과(VD-19 — §12) · agent-view `auth can-i create serviceaccounts/token -n kube-system` = no(VD-20). 스모크 토큰은 root 창에서 `vault token revoke <토큰변수>`로 폐기하고 변수를 지운다(`revoke -self`는 현재 `VAULT_TOKEN`(root)을 대상으로 하므로 쓰지 않는다).

### US6 플레이스홀더 8경로와 게이트 1(D8′)
- T044가 kv 경로·키 스키마를 선점한다. 값은 **단일 sentinel 리터럴 `PLACEHOLDER-T044-SENTINEL`**(credential이 아니다). 투입 실측 2026-09-17 11:19:26 KST. 실값 교체는 T075·T081·T082.
- 8경로(data-model §8, ESO 소비분만 — `kv/{env}/authentik/web-bff`·`kv/{env}/access/web-bff`는 Workers 전용이라 제외):

| 경로 | 키 |
|---|---|
| `kv/dev/authentik/identity-admin` | `client_id` `client_secret` `jwks_url` `issuer` `api_token` |
| `kv/prod/authentik/identity-admin` | 같음 |
| `kv/dev/authentik/webhooks/identity-admin` | `secret` |
| `kv/prod/authentik/webhooks/identity-admin` | `secret` |
| `kv/dev/openfga/store_id` | `store_id` |
| `kv/prod/openfga/store_id` | `store_id` |
| `kv/dev/openfga/preshared` | `key` |
| `kv/prod/openfga/preshared` | `key` |

- **불변식: sentinel 잔존 0 = consumer 활성화 전제.** `kv/{env}/openfga/preshared`는 US6에서 `kv/platform/openfga/preshared`와 같은 값으로 교체하고 회전은 둘을 함께 한다.
- 실값 투입 형식: 키당 1회 호출 또는 JSON stdin(`… | vault kv put <path> -`) — `key=-` 다중 사용 금지(stdin은 한 키만 받는다 → 나머지가 빈 값). 실값을 명령줄 리터럴로 적지 않는다.
- **게이트 1(운영자 — 실값 주입 뒤·consumer 활성화 전, 실행은 T075·T081)**: 토큰 = T084 뒤 OIDC admin, 그 전 root(e2e-reader 정책은 `kv/data/platform/authentik/e2e` 1줄이라 8경로를 읽을 수 없다).
```powershell
$paths = @(
  'kv/dev/authentik/identity-admin',           'kv/prod/authentik/identity-admin',
  'kv/dev/authentik/webhooks/identity-admin',  'kv/prod/authentik/webhooks/identity-admin',
  'kv/dev/openfga/store_id',                   'kv/prod/openfga/store_id',
  'kv/dev/openfga/preshared',                  'kv/prod/openfga/preshared'
)
$read = 0; $hits = 0
foreach ($p in $paths) {
  $j = vault kv get "-format=json" $p                       # 값은 변수에만 — 화면에 찍지 않는다
  if ($LASTEXITCODE -ne 0 -or -not $j) { "READ FAIL $p"; continue }   # 토큰 만료·403·port-forward 끊김·경로 오타
  $read++
  if ($j | Select-String 'PLACEHOLDER-' -Quiet) { $hits++; "SENTINEL $p" }
}
Remove-Variable j
"read=$read/8 hits=$hits"    # PASS = read 8/8 **그리고** hits 0 (fail-closed: 하나라도 못 읽으면 FAIL). hits ≥ 1이면 그 경로의 consumer를 켜지 않는다
```
- 게이트 2(consumer 자체, 무토큰 — T072·T075·T077 인계): django-pod 템플릿 pydantic-settings 검증기가 `PLACEHOLDER-`로 시작하는 값에서 기동 실패(fail-closed) + T077 tester 단언 `PLACEHOLDER-` 0.
- 검증: role 6 = `vault list auth/kubernetes/role` · 정책 6(+내장) = `vault policy list` · 정례 plan `No changes` · 게이트 1 = `read=8/8 hits=0`.
- 되돌리기: 잘못된 role/정책은 코드 수정 → 재apply(0 destroy 원칙). kv 마운트 삭제 금지. 플레이스홀더 경로 되돌리기 = `vault kv metadata delete kv/<path>`.

---

## §5 break-glass

- 목적: 관리 토큰을 전부 잃었을 때의 복구 경로와 그 **전제**를 정확히 적는다 — 2.0에서는 recovery key만으로는 성립하지 않는다.
- 전제: recovery key 3/2 조각이 PM에 있다(§4). 그리고 **유효한 Vault 토큰이 하나 있어야 한다**(아래).

### 정정 문면(ADR 0010 §6 · spec FR-041 — converge → ADR 0011)
- **Vault 2.0부터 `sys/generate-root/*`·`sys/rekey/*`는 recovery key 조각과 함께 유효한 Vault 토큰을 요구한다**(설계 §3.2 V). "recovery key `generate-root`가 break-glass"·"OIDC 전 Vault 변경은 generate-root뿐"은 2.0에서 성립하지 않는다. root를 revoke한 뒤 다른 관리 경로가 없으면 recovery key는 아무 권한도 만들지 못한다 — 그래서 D4는 root revoke를 T084 + 드릴 **뒤**로 미뤘다.
- 채택하지 않은 대안: `enable_unauthenticated_access`(generate-root/rekey 엔드포인트를 무인증으로 여는 옵션)는 DoS·보안 후퇴라 채택하지 않는다.

### 예정 경로(converge 추가 task — 아직 없다)
- 7번째 K8s auth role **`vault-break-glass`**(SA `vault/vault-break-glass`, K8s RBAC 0, 정책 `sys/generate-root/*`·`sys/rekey/*` update만). 토큰은 admin kubeconfig `kubectl create token vault-break-glass -n vault --audience vault`로만 — 저장 토큰 0(비root 토큰은 max TTL 32일이라 오프라인 보관 불가). tasks:123 "합계 6" 개정 포함.
- **quorum 드릴(초기 root revoke 전에 1회, 미검증)**: `vault operator generate-root -init`(OTP 생성) → recovery key 조각 2/3을 프롬프트로 입력(명령줄 인자 금지) → 인코딩된 토큰을 `generate-root -decode -otp`로 디코드 → 드릴 root로 `vault token lookup` → 드릴 root `vault token revoke -self`. 드릴이 성공한 뒤에야 초기 root를 revoke한다(§4). 실측값 없음(T084/converge).
- 인증 방식(auth method) 변경은 **OpenTofu(`infra/vault`)로만** — CLI `vault auth disable`로 K8s auth를 끄면 ESO·백업·e2e가 동시에 끊긴다.

- 검증: (드릴 시) `token lookup` policies=root · 드릴 root revoke 뒤 403.
- 되돌리기: generate-root는 새 토큰을 만들 뿐 기존 것을 바꾸지 않는다 — 만든 토큰을 revoke하면 원상.

---

## §6 KMS 키 삭제/분실 = 복구 불능

- 목적: KMS 키 상태가 백업·라이브 데이터 전체의 생사임을 고정하고, "삭제 유예"라는 오해를 없앤다.
- 전제: `infra/oci` `kms.tf`의 키 `prevent_destroy`(볼트 `joshuatech-vault` · 키 `joshuatech-key`, SOFTWARE).

### 정정 문면(ADR 0010 §4·tasks "삭제 유예 30일" — converge → ADR 0011)
- OCI에서 키 **삭제를 예약(Pending Deletion)하는 즉시** 그 키로 래핑된 모든 것(라이브 Raft 데이터·모든 스냅샷)에 접근할 수 없다. 30일(7–30일 설정)은 "유예"가 아니라 **취소 창**이다. Pending Deletion을 발견하면 즉시 **삭제 취소**(운영자 콘솔)가 유일한 조치다 — 취소 뒤 Vault 재기동은 §1 드릴.
- `infra/oci`의 `prevent_destroy`가 백업 유효성의 전제다(정례 plan에 KMS destroy가 보이면 중단 — `.claude/rules/infra.md` 0 destroy 규칙).
- 키 **회전**은 이전 버전으로 계속 복호화되므로 재래핑을 강제하지 않는다(안전). Community 2.0.4에는 `operator seal-rewrap`이 없다.
- 키가 정말 사라졌으면: 복원 경로 없음 → §11-b(PVC 삭제) + 새 KMS 키(tofu, 노드 A 동적 그룹 정책 갱신) + §4 재init + 전 시드 재투입(모든 비밀 회전 — `secret-rotation.md`).

- 검증: OCI 콘솔 키 상태 **Enabled** · `tofu -chdir=infra/oci plan` 0 destroy.
- 되돌리기: Pending Deletion 취소(콘솔) — 그 밖에 없다.

---

## §7 Raft 스냅샷 복원

- 목적: 일 1회 스냅샷(`platform-backup.sh`, 02:30 KST 타이머 + SUC `--pre-upgrade` 게이트)에서 Vault 데이터를 되살린다. **같은 KMS 키가 살아 있을 때만** 가능하다(§6).
- 전제: 스냅샷은 seal(KMS) 래핑이다 → 복원 대상 Vault는 **같은 `key_id`**의 ocikms seal로 기동·초기화·unseal된 상태여야 한다. 토큰: `vault operator raft snapshot restore -force`는 `sys/storage/raft/snapshot-force`(update)를 부른다 — `vault-backup` role은 `snapshot` read뿐이고 `snapshot-force`는 deny(VD-18 실측) → **root**(T084 뒤 OIDC admin). 오프라인 age 개인키(`joshuatech-age.key`, bootstrap.md §0 키쌍 — 노드·저장소·클라우드에 없음).
- 버킷: `joshuatech-backup-platform`(설계 표기 `jt-backup-platform` 이름 예외), 접두 `vault/`, 오브젝트 키 `vault/vault-<UTC ts>.snap.age`, lifecycle 30일. **첫 스냅샷 실측(2026-09-17 단계 14)**: `vault/vault-20260917T022021Z.snap.age` 36,642B · textfile `platform_backup_last_success_timestamp{component="vault"}` 1789611628 · `--pre-upgrade` gate PASS(k3s + vault) exit 0 · 타이머 다음 실행 09-18 02:30 KST. `svc-verify` 버킷 확인(VD-22, 2026-09-17 세션 재인증 뒤): cluster.tests `backup-2` PASS — `vault/`에 24h 내 `.age` **2건**(`…022021Z` 수동 · `…022039Z` pre-upgrade), `backup-3` PASS — 비-`.age` 0(11 객체). 첫 시도는 세션 키 passphrase 오류였다 — `oci session authenticate`를 다시 하면 풀린다(bootstrap.md §3 T044 절차 메모 7).

### 절차
```powershell
# 1. 스냅샷 선택·내려받기 (svc-verify 세션 1h — read objects만; 재인증이 passphrase를 물으면 `N/A`를 입력하고 config에 저장하지 않는다)
oci session authenticate --profile-name svc-verify
oci --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup-platform --prefix vault/ --query 'data[].{name:name,size:size}' --output table   # 키 이름의 UTC ts가 시각이다(하이픈 키 time-created는 PowerShell 이스케이프가 까다로워 쓰지 않는다 — 2026-09-17 실측)
oci --profile svc-verify --auth security_token os object get --bucket-name joshuatech-backup-platform --name 'vault/vault-<ts>.snap.age' --file "$env:TEMP\vault-<ts>.snap.age"

# 2. 복호화 (age 개인키는 오프라인 보관 경로에서 직접 읽는다 — 복사하지 않는다)
age -d -i '<오프라인 보관 경로>\joshuatech-age.key' -o "$env:TEMP\vault-<ts>.snap" "$env:TEMP\vault-<ts>.snap.age"

# 3. 대상 Vault 상태 확인 (§0 port-forward · root env)
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status      # initialized:true · sealed:false · type:ocikms — PVC 소실 뒤라면 새 PVC에서 §4 안전 블록 init이 선행된다(§11-b는 데이터·스냅샷 0일 때만 쓰는 경로라 여기에 해당하지 않는다)
vault token capabilities sys/storage/raft/snapshot-force  # root 토큰이면 `root`, T084 뒤 OIDC admin 토큰이면 `update` 포함. `deny`면 중단

# 4. 복원 직전 현재 상태를 먼저 떠 둔다(되돌리기용) → 복원 — 3의 확인을 건너뛰지 못하게 사람 입력으로 멈춘다
if ((Read-Host '3단계 확인(seal-status 정상 · capabilities root/update) 통과? 복원 진행 yes') -ne 'yes') { throw '복원 중단' }
vault operator raft snapshot save "$env:TEMP\vault-pre-restore.snap"
vault operator raft snapshot restore -force "$env:TEMP\vault-<ts>.snap"

# 5. 복원 뒤 확인 — 명령 반환 ≠ 완료. seal-status와 실제 읽기로 판정
#    ⚠ 복원은 토큰 저장소도 스냅샷 시점으로 되돌린다(업스트림 동작, T044 미실측 — VD-24와 함께 확인): 직전 init의 root 토큰은 사라질 수 있다.
#      403이 나면 VAULT_TOKEN을 **스냅샷 시점의 root**(PM의 그 시점 항목)로 바꿔 다시 확인한다.
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status
vault secrets list; vault auth list; vault policy list; vault list auth/kubernetes/role
vault kv list kv/dev/authentik                            # 시드·sentinel 경로가 보여야 한다
```

5의 판정이 PASS일 때만 **별도 블록**으로 로컬 산출물을 소거한다(통째 실행으로 되돌리기용 스냅샷이 먼저 지워지지 않게 — 2026-09-17 사고와 같은 계열):
```powershell
# 6. 로컬 산출물 소거 — 5 판정 PASS 뒤에만
if ((Read-Host '복원 검증(5) 통과? 산출물 소거 yes') -eq 'yes') {
  Remove-Item "$env:TEMP\vault-<ts>.snap", "$env:TEMP\vault-<ts>.snap.age", "$env:TEMP\vault-pre-restore.snap" -Force
} else { 'NOT REMOVED — 되돌리기용 vault-pre-restore.snap 유지' }
```

### `-force`의 의미
- 스냅샷의 클러스터/seal 정합성 검사를 **우회**할 뿐이다(새로 init한 클러스터에 되살릴 때 필요). **다른 KMS 키로 암호화된 스냅샷을 복호화하지 못한다** — 같은 KMS 키 필수.
- 복원 뒤 recovery key가 "스냅샷 시점의 조각"으로 되돌아가는지, 현재 PM 조각이 유효한지는 **미검증** `[실측 후 채움: VD-24 — T048 이후 비운영/계획 창: 새 init → restore -force → generate-root -status 3/2 보고 확인; T044에서 실행하지 않는다]`. 그때까지 복원 뒤에는 PM의 init 시점 항목 + 스냅샷 시점 항목을 모두 보존한다(**root 토큰도 같다** — 어느 시점의 토큰이 유효한지는 복원 뒤 `token lookup`으로 가린다).
- 복원은 ESO Secret을 되감을 수 있다(T045 이후): 복원 시점 이후 회전된 값이 있으면 `secret-rotation.md` 매트릭스로 재투입한다.

- 검증: seal-status 정상 · role/정책/kv 경로가 스냅샷 시점과 일치 · ESO(T045 이후) `SecretSynced` 회복.
- 되돌리기: 4에서 떠 둔 `vault-pre-restore.snap`을 같은 명령으로 복원(이때도 토큰은 그 스냅샷 시점의 root로 되돌아간다).

---

## §8 Shamir 비상 마이그레이션

- 목적: KMS를 더 쓸 수 없게 될 것이 **예고**된 상황(계정·과금·리전 이슈)에서 auto-unseal을 Shamir로 옮겨 Vault를 살려 둔다(research VAULT-D10).
- 전제: 단일 노드 = **계획 다운타임**. recovery key 3/2 조각이 PM에 있고(§4), 유효 토큰(root)이 있다. 리허설한 적 없다 — 절차는 설계 문면과 HashiCorp seal migration 문서 기준이며 **미검증**이다. §2의 KMS 장애 창(살아 있는 프로세스)에서 즉흥적으로 시도하지 않는다.
- 주의(research VAULT-D10 — 문서 근거 검증됨, 라이브 리허설 없음): auto-unseal → Shamir 이행은 기존 루트 키를 **기존 seal(KMS)로 복호화**해야 하므로 마이그레이션 시점에 **신·구 seal이 동시에 가용**해야 한다. KMS 키가 이미 삭제·불능이면 이 절은 복구 경로가 아니다(§6).

### 절차(개요)
1. gitops PR: `platform/vault/kustomization.yaml` valuesInline HCL의 `seal "ocikms" { … }` 블록에 `disabled = "true"` 한 줄 추가 → 머지(§10 규율).
2. `kubectl -n vault delete pod vault-0` → 파드가 **sealed** 상태로 기동(마이그레이션 대기; `vault status`에 migration 표시).
3. 워크스테이션(§0 port-forward): `vault operator unseal -migrate`를 threshold(2)만큼 실행, 각 회에 recovery key 조각을 프롬프트로 입력(명령줄 인자 금지). 완료 시 **recovery key 조각이 unseal key**가 된다.
4. 이후 매 재기동은 수동 `vault operator unseal`(2조각) — 무인 복구(reboot-1·§1 드릴)가 성립하지 않는다. `VaultSealed` 알림이 재기동마다 발화한다.
5. 되돌리기(Shamir → ocikms): HCL에서 `disabled` 줄 제거 PR → 파드 삭제 → `vault operator unseal -migrate`를 unseal key 조각으로 다시 실행 → seal-status `type:"ocikms"` 확인.

- 검증: 마이그레이션 뒤 seal-status `type:"shamir"` · `sealed:false` · 데이터 읽기 정상. 실측값 없음(비상 절차).
- 라이브 영향: 2–5 사이 Vault 무응답. ESO는 마지막 Secret 유지.

---

## §9 감사 장치 장애(fail-closed)

- 목적: 모든 요청이 감사에 남게 하고, 단일 stdout 장치의 **fail-closed** 성질을 운영자가 알고 있게 한다.
- 전제: init 직후 · root 토큰(`sys/audit`는 list/enable/disable 전부 sudo) · **`infra/vault` apply보다 먼저**(tofu write 15건이 전부 감사에 남게).
- 소유: privileged bootstrap(이 절, CLI 1회 — 설계 D5 A′). tofu·gitops 미소유(tofu가 소유하면 매 plan refresh가 sudo 요구). 드리프트 감지는 T098 메트릭으로.

### 활성화(1회) — 실측 2026-09-17 02:11Z(11:11 KST)
```powershell
vault audit enable file file_path=stdout        # 1회. 파일 아님 — 컨테이너 stdout → alloy-logs → Loki
vault audit list -detailed                      # file/ 1개 · options file_path=stdout · log_raw false(값은 HMAC-SHA256)
kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault logs vault-0 --tail=20 | Select-String '"type":"request"'   # ≥1행 (VD-15 실측 ≥1행)
```
- 검증: `audit list -detailed`에 `file/` 1개. agent-view `pods/log`로 감사 JSON ≥1행. 두 번째 장치를 만들지 않았다.

### fail-closed와 조기 경보
- 감사 장치가 **하나(stdout)뿐**이므로 stdout 쓰기 실패(노드 A 디스크 포화 → 컨테이너 런타임 로그 파일 쓰기 실패) = Vault가 **모든 API 요청을 거부**한다. 증상: 전 요청 실패 · ESO 갱신 정지 · `platform-backup.sh` vault 컴포넌트 실패 · UI 오류. seal-status는 정상(`sealed:false`)이라 §1 표로는 잡히지 않는다.
- 확인: `ssh ssh-a "df -h / /var/lib/rancher; sudo journalctl -u k3s --since -30min | grep -i 'no space\|log'"`. 조치: 디스크 확보(운영자) → 요청이 즉시 회복(재시작 불필요). 감사 로그를 끄는 것으로 "복구"하지 않는다.
- 조기 경보: `NodeDiskLow`(FR-040) · **T098 인계** audit-health = 카운터 `vault_audit_log_request_failure`·`vault_audit_log_response_failure` + Loki 감사 스트림 존재(결측 = 장치 제거·드리프트). `VaultAuditFailure` 규칙 추가는 FR-040 알림 13개 동결이라 converge 항목.
- 두 번째 독립 sink(후보 `socket` → Alloy)는 후속 hardening 인계. 임시 FS의 파일 장치는 감사 유실 경로라 채택하지 않는다.

- 되돌리기: `vault audit disable file/` — 단, 감사 없이 다음 단계로 진행하지 않는다. 장치 제거는 sudo(root)에서만 가능.

---

## §10 설정 변경 규율(OnDelete)

- 목적: HCL·values·이미지 변경이 "PR 머지만으로는 반영되지 않는다"는 사실을 절차로 고정하고, 뒤처진 파드를 식별한다.
- 전제: STS `updateStrategyType: OnDelete`(차트 기본 유지 — "KMS 장애 중 재시작 금지" 규율과 맞다) · `includeConfigAnnotation: true`(파드 템플릿에 config 체크섬 어노테이션).

### 절차
1. gitops PR(`platform/vault/kustomization.yaml`) → 리뷰 → 머지 → Argo sync: ConfigMap `vault-config`와 STS 템플릿이 갱신되지만 **파드는 그대로**(Application은 `Synced/Healthy`로 보인다 — 조용한 드리프트). 이미지 bump도 같다(gitops README §2 단계 6).
2. 렌더 대조(스키마가 키 오타를 잡지 못한다 — `values.schema.json`에 `additionalProperties: false` 0곳): `kustomize build --enable-helm platform/vault | Select-String '<바꾼 키>'`로 실제 렌더에 들어갔는지 확인. 실측(VD-08): 렌더 G1 **9장** · G2 **10장**(`helmCharts[].skipTests: true`로 test hook Pod 제외 — kind/name 목록과 grep 기대값 `image:` 1줄 · `Delete=false` 1줄 · `namespaceSelector` 0줄은 gitops README §6).
3. 뒤처진 파드 식별(어노테이션 이름 `vault.hashicorp.com/config-checksum` — 차트 0.34.1 `_helpers.tpl`; 로컬 렌더 실측 2026-09-14 = `c6d7b923d44ef485…704960aa`(seal 3값 투입 뒤, G1·G2 동일); 라이브 파드 어노테이션과의 대조는 다음 설정 변경 때 수행):
   ```powershell
   kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault get sts vault -o jsonpath='{.spec.template.metadata.annotations}{"\n"}'
   kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault get pod vault-0 -o jsonpath='{.metadata.annotations}{"\n"}'
   kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault get sts vault -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
   kubectl --kubeconfig "$HOME\.kube\agent-view.yaml" -n vault get pod vault-0 -o jsonpath='{.status.containerStatuses[0].imageID}{"\n"}'
   ```
   두 출력의 config 체크섬(또는 image digest)이 다르면 파드가 옛 설정·옛 바이너리로 돌고 있다.
4. 반영: **KMS 장애 창이 아님을 §2로 확인한 뒤** `kubectl -n vault delete pod vault-0`(운영자) → §1 드릴 게이트(실측 8초 · 드릴 총 20초).
5. seal 스탠자를 건드리는 변경(`key_id`·엔드포인트·`disabled`)은 §3 1행·§8의 영역이다 — 값이 틀리면 CrashLoop이므로 되돌릴 PR을 미리 준비한다.

- 검증: 3의 어노테이션·digest 일치 · §1 게이트 통과 · Argo `Synced/Healthy`.
- 되돌리기: revert PR 머지 → 파드 삭제(같은 규율). 이미지 bump 실패(`ImagePullBackOff`/`InvalidImageName`)는 `server.image.tag`를 `"2.0.4"`(digest 없음)로 폴백 PR(D6 — 2026-09-17 실측은 `tag@digest` 수용, VD-12 PASS).
- 금지: KMS 장애 중 파드 삭제 · `kubectl edit/patch sts`(정본은 git) · `helm upgrade`(helm 릴리스가 아니다 — `helm list -n vault` 비어 있음이 정상).

---

## §11 PVC·PV·되돌리기

- 목적: Vault 데이터가 어디에 있고 무엇을 지우면 사라지는지, (a) 코드 제거 되돌리기 순서와 (b) 데이터 초기화(재init) 경로를 고정한다.
- 전제(단계 0 실측): StorageClass `local-path` = reclaimPolicy **`Delete`** · `WaitForFirstConsumer` · setup `mkdir -m 0777`. PVC `data-vault-0`(5 Gi)은 STS `volumeClaimTemplates`가 만들고 **Argo 트리 밖**이다.

### 사실
- Argo UI 고아 리소스 경고 `vault/PersistentVolumeClaim data-vault-0` **1건은 정상**이다 — 지우지 않는다.
- 어노테이션 `argocd.argoproj.io/sync-options: Delete=false,Prune=false`(values `dataStorage.annotations` → volumeClaimTemplates → PVC 전파)는 계약 §삭제 보호의 **표식**이며 Argo 관리 밖 PVC를 실제로 보호하지 않는다(재init 실측: `kubectl delete pvc`가 그대로 통했다). volumeClaimTemplates는 불변이라 첫 apply에 있어야 한다(cluster.tests argo-4).
- **PVC 삭제 = local-path PV 데이터 소멸**(reclaimPolicy Delete — 2026-09-17 재init에서 옛 PV 소멸 실측). 복구 = §7 스냅샷 + **같은 KMS 키**뿐. STS 삭제는 PVC를 지우지 않는다(K8s 기본 `persistentVolumeClaimRetentionPolicy` Retain/Retain — values에 적지 않았고 동작은 같다).
- PDB 없음(`ha.disruptionBudget.enabled: false` — replicas=1이면 차트가 `maxUnavailable: 0`을 고정해 `kubectl drain`이 영구 대기한다). 노드 A drain은 가능하나 Vault는 노드 A에만 뜰 수 있으므로(§3 5행) drain = Vault 다운타임이다. SUC Plan은 cordon만 쓴다.

### (a) 코드 제거 되돌리기 순서(gitops README §5 · kustomization 머리 주석과 동일)
revert 머지 → 렌더 0(`prune: false`라 객체가 남는다) →
① `kubectl -n vault delete ingress vault`(**G2 이후에만**; 공개 진입점 먼저) →
② `kubectl -n vault delete sts vault --cascade=orphan`(파드 유지) →
③ `kubectl -n vault delete pod vault-0` →
④ Service `vault`·`vault-internal` · ConfigMap `vault-config` · SA `vault`·`vault-backup` · Role/RoleBinding(`vault-discovery-*`) · ClusterRoleBinding `vault-server-binding`(`system:auth-delegator`) 수동 정리 →
⑤ **PVC `data-vault-0`과 PV는 제외**(다음 배포가 같은 PVC를 재부착 → §4 "이미 초기화됨" 정상 케이스).
- 검증: ⑤ 뒤 `kubectl -n vault get pvc data-vault-0`이 `Bound`로 남아 있다.
- 되돌리기의 되돌리기: 원 PR 재머지 → STS가 기존 PVC를 재부착 → §1 드릴 게이트.

### (b) 데이터 초기화(재init) 경로 — 2026-09-17 실행 기록
README §5 ⑤ "PVC/PV는 지우지 않는다"의 **1회 예외**는 다음 조건이 **전부** 성립할 때만이다: auth·정책·마운트(우리 것)·시드·스냅샷·Ingress가 전부 0 — 즉 지울 데이터가 없다. 하나라도 있으면 (a)로 가고 데이터는 §7로 다룬다.
- **R0 게이트(전부 확인·기록)**: Ingress 0(`get ingress -n vault`) · 버킷 `vault/` 오브젝트 0 · PM에 이 클러스터의 init 항목 0(= 잃은 산출물이 유일한 산출물) · local-path provisioner 파드 1 Running · SUC Plan `status.applying` 비어 있음(창 밖) · 현재 PVC uid 기록(실측 `65c4d83d`).
- **R1(운영자, admin)**: 순서는 **PVC → pod**.
  ```powershell
  kubectl -n vault delete pvc data-vault-0 --wait=false     # 파드가 쓰는 동안 Terminating으로 대기(finalizer)
  kubectl -n vault delete pod vault-0                        # 기본 grace — 강제 종료(--force/--grace-period=0) 금지
  kubectl -n vault get pvc -w                                # watch는 종류 하나만(pvc,pod 병기 불가) — 새 PVC Bound까지
  kubectl -n vault get pod vault-0 -o wide                   # Running 0/1 (미초기화)
  kubectl -n vault get pvc data-vault-0 -o jsonpath='{.metadata.uid} {.metadata.annotations}{"\n"}'   # uid 변경 · 어노테이션 유지
  ```
  실측: 새 PVC(uid `671c6607`, 어노테이션 유지) Bound까지 **1분 44초** · 옛 PV 소멸 · local-path helper 파드 종료 · vault-0 `Running 0/1` · Application `Synced Progressing` · port-forward는 끊기므로 창 C 재수립.
- **R2**: seal-status `initialized:false` · `sealed:true` · `type:"ocikms"` 확인 → §4 안전 블록(실측 11:09:13 KST init, 되가져오기 4/4, WIPED).
- 검증: §4 게이트 + 이후 단계(§9 audit → `infra/vault` apply → sentinel → 백업 1회)를 같은 세션에서 끝낸다(SUC `--pre-upgrade` 게이트 창 — gitops README §4).
- 되돌리기: 없음(데이터가 없었다는 R0 조건이 곧 되돌릴 것이 없다는 뜻이다). R0가 하나라도 성립하지 않으면 이 경로를 쓰지 않는다.

---

## §12 e2e-reader 토큰(T077)

- 목적: tester(Playwright)가 E2E 사용자 비밀번호·TOTP 시드(`kv/platform/authentik/e2e`)를 읽는 유일한 경로를 고정한다.
- 전제: role `e2e-reader`(bound SA `kube-system/agent-view`, audience `vault`, 정책 `kv/data/platform/authentik/e2e` read 1줄). `agent-view` ClusterRole에는 `serviceaccounts/token` create가 **없다**(쓰기 동사는 `pods/portforward` create뿐) → tester는 토큰을 **자급할 수 없다**. 실측(VD-20, 2026-09-17): `kubectl --kubeconfig agent-view.yaml auth can-i create serviceaccounts/token -n kube-system` → **`no`**.

### 절차
```powershell
# 운영자(admin kubeconfig) — E2E 세션 직전, 값은 env로만 tester에 전달(파일 저장 금지)
$env:E2E_VAULT_JWT = (kubectl create token agent-view -n kube-system --audience vault --duration=1h)

# tester 세션(agent-view kubeconfig로 port-forward svc/vault 18200:8200 — ns vault pods/portforward 허용)
$env:VAULT_ADDR  = 'http://127.0.0.1:18200'
$env:VAULT_TOKEN = ($env:E2E_VAULT_JWT | vault write -field=token auth/kubernetes/login role=e2e-reader jwt=-)
# 문서화된 읽기 명령은 `vault read kv/data/platform/authentik/e2e`로 고정한다. ⚠ 원시 JSON을 콘솔에 출력하지 않는다(에이전트 대화 로그에 남는다) —
#   변수로만 받고 키 이름만 확인한다. Playwright는 프로세스 내부에서 같은 경로를 읽는다.
$e2e = vault read "-format=json" kv/data/platform/authentik/e2e | ConvertFrom-Json
"exit=$LASTEXITCODE keys=$($e2e.data.data.PSObject.Properties.Name -join ',')"
Remove-Variable e2e
```
- **VD-19 실측(2026-09-17)**: e2e-reader 토큰으로 `vault read kv/data/platform/authentik/e2e`와 `vault kv get kv/platform/authentik/e2e` **둘 다 정책을 통과**한다(경로가 아직 없어 `No value found` exit 2 — 403 아님). kv v2 preflight(`sys/internal/ui/mounts/kv`)는 마운트 하위 접근 유무만 보므로 최소권한 토큰도 통과한다 — 초안·계약 :79의 "preflight 403" 단정은 오류였고 계약 괄호절은 T044 M2에서 정정했다. 문서화된 명령은 그래도 `vault read`로 고정한다(정책 경로와 1:1 대응, preflight 의존 없음).
- SA 토큰(JWT)은 1h, Vault 토큰은 1h/4h·`service`. 세션 종료 시 `vault token revoke -self`(default 정책에 있음) → `Remove-Item Env:VAULT_TOKEN, Env:E2E_VAULT_JWT`.

- 검증: `vault read` JSON에 `data.data` 키가 있고 값은 출력·기록하지 않는다(T045 시드 뒤). 다른 경로(`kv/data/platform/access/*` 등)는 403.
- 되돌리기: 토큰 revoke. role/정책 변경은 `infra/vault` PR.

---

## §13 관련 문서

| 문서 | 내용 |
|---|---|
| `docs/runbooks/bootstrap.md` §3 T044 · §4 | T044 실행 기록(시각·실측값·게이트·사고·재초기화) · §4 플레이스홀더 8경로·revoke 보류 · §0 토큰 표 ⑥(D4로 정정 대상) · §3 T043(AOP·오리진 판별 절차 — Ingress 확인에 재사용) · §6 SUC 창·disabled 라벨 |
| gitops `platform/vault/README.md` | 소유/비소유 · 인플레이트·bump 규칙 · values 근거 · 되돌리기 순서(§5) · 배포 뒤 확인 명령(§6) · 수용 위험(§7) · T045 인계(§8). 이 런북의 §0·§9·§10·§11을 참조한다 |
| gitops `platform/policies/` | ns `vault` PSA restricted · NetworkPolicy(`allow-imds`·`allow-egress-external-443`·`allow-dns`·`allow-kube-api`·`allow-from-traefik` 등 9장) |
| `infra/vault/` (모노레포) | kv v2 마운트 · kubernetes auth · 정책 6 · role 6 · `main.tf` 주석(sudo 경계·read 전용 정책 경로) · `backend.tf` 헤더의 운영자 전용 절차(3b 부분 적용 복구) |
| `infra/bootstrap/platform-backup.sh` | Raft 스냅샷(role `vault-backup` · `vault/vault-<UTC>.snap.age`) · `--pre-upgrade` 게이트(Service `vault` 감지 시 vault 스냅샷 필수) · 스킴 http 고정(T044 확정) |
| `docs/decisions/0010-secrets.md` | 결정과 불변식. §4 "sealed 대기"·"삭제 유예 30일", §6 "generate-root뿐"·⑥ revoke 시점은 이 런북(§2·§5·§6·§4)이 정정(ADR 0011 예정 — supersede) |
| `specs/003-platform-foundation/contracts/hostnames-and-access.md` | :31 `vault.joshuatech.dev` Access 앱 · :59 seal 확인 = port-forward(로컬 8200 표기 — 이 문서는 18200) · :79 e2e-reader 발급 절차 + VD-19 정정 |
| `docs/runbooks/secret-rotation.md` · `incident-response.md` · `break-glass.md` (T084·T114) | 회전 매트릭스(root 보관·revoke 시점 등재) · 사고 대응 · break-glass 절차(`vault-break-glass` role + quorum 드릴) |
