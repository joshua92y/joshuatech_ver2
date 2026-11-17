# T045 G4 설계 스냅샷 (t045-design.md 발췌, 2026-09-21)

### 4.9 `secrets/cloudflared/` (G4 — ⚠ 잠금 위험 리소스)

```yaml
# secrets/cloudflared/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [externalsecret-cloudflared-tunnel.yaml]
```

```yaml
# ⚠⚠ 잠금 위험 리소스. 이 Secret은 **SSH(노드 A·B)와 K8s API의 유일한 경로**인 터널 커넥터의 자격이다(22 포트 닫힘).
# `creationPolicy: Orphan` — 계약 예시(Owner)의 **명시적 예외**(계약 §ExternalSecret 규약 각주 · 설계 D4):
#   Owner는 ownerReference를 심어 `kubectl delete externalsecret` 한 번·Application cascade 한 번으로 Secret이 GC된다
#   (`deletionPolicy: Retain`은 GC를 막지 못한다). Orphan은 ownerRef를 만들지 않는다. 대가: Argo 고아 경고에 계속 뜬다(드리프트 아님).
#   ⚠ Owner로 바꾸지 말 것 — 하네스 eso-4가 회귀를 잡는다.
# ⚠ Orphan이어도 **값은 kv에서 덮어쓴다**(D4-③). 복구의 1순위는 Secret 수동 복구가 아니라 **kv 값 정정**이다 — 수동 복구는 ≤5분 안에
#   ESO가 되돌린다. 컨트롤러 scale 0도 platform-external-secrets의 selfHeal이 되돌린다(런북 bootstrap.md §3 T045 되돌리기).
#   Secret이 삭제되면 **ESO·Vault가 정상일 때 다음 성공한 갱신에서** 재생성된다(즉시 재조정 여부는 미확인 — DR1 드릴 VD-20).
# ⚠ 콜드 부트스트랩(D3 조건 3): root는 wave 60의 cloudflared까지 가지 못한다 → 터널 Secret과 cloudflared는 **T039 절차대로 수동으로 먼저**
#   올리고, 이 ES에 의한 인수는 Vault init·시드가 끝난 뒤에 일어난다. 런북 §3 T045 절과 platform/cloudflared README에 같은 문장을 둔다.
# 인수 절차: 수동 Secret을 **지우지 않는다**(이 저장소 README ⑨의 옛 지시는 틀렸고 잠금 창을 스스로 만드는 지시였다).
# 값이 같으면 실행 중 파드 영향 0(env는 시작 시 1회) → `rollout restart`를 하지 않는다. 회전(T084) 때는 수동 재시작이 필요하다
#   (이 Deployment에는 reloader 어노테이션이 없고 T046 감시 대상에도 넣지 않는다 — 그 수동성이 안전장치다).
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: cloudflared-tunnel
  namespace: cloudflared
  annotations:
    # ⚠ 범위 한정(D4-⑤): 이 어노테이션은 **Argo가** 이 ExternalSecret 객체를 지우거나 prune 하지 못하게 할 뿐이다.
    #   `kubectl delete externalsecret`은 막지 못하고, ESO의 Secret 재기록 동작과도 무관하다.
    argocd.argoproj.io/sync-options: Delete=false,Prune=false
spec:
  refreshPolicy: Periodic      # D4-①
  refreshInterval: 5m
  secretStoreRef: { kind: ClusterSecretStore, name: vault-platform }
  target:
    name: cloudflared-tunnel
    creationPolicy: Orphan
    deletionPolicy: Retain
    template:
      metadata: {}
  data:
    - secretKey: TUNNEL_TOKEN
      remoteRef: { key: platform/cloudflare/tunnel, property: token }
```


### 단계 10 — G4: 터널 토큰 인수 🔒 ✋ (사용자 입회 필수. G3 게이트를 전부 PASS한 뒤에만)

**사전 조건 블록.** 하나라도 실패하면 머지하지 않습니다. 이 창은 G4가 끝날 때까지 닫지 않습니다.

```powershell
$ErrorActionPreference = 'Stop'
Read-Host '1) 별도 창에서 `ssh ssh-a` 대화형 세션을 열어 두었다(1차 break-glass = 그 세션의 sudo k3s kubectl; kubectl은 호출마다 새 dial이라 열어 둔 터널이 kubectl의 안전망은 아니다). Enter'
# 2) 2차 break-glass 자격 실측 — 잠긴 뒤에 확인하면 늦다. 운영자 프로파일로(읽기 전용 svc-verify 아님).
$NSG = tofu "-chdir=infra/oci" output -raw nsg_cluster_id
if ($LASTEXITCODE -ne 0 -or -not $NSG) { throw 'nsg_cluster_id 취득 실패' }
oci network nsg rules list --nsg-id $NSG --query 'length(data)' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'OCI 자격 사용 불가 — break-glass 경로 미확보, 중단' }
'참고: 임시 22 규칙의 실제 명령은 infra/oci/instances.tf 5·8단계(oci network nsg rules add/remove). list 성공은 자격 유효만 증명한다(add 권한은 별개).'
Read-Host '3) PM에 터널 토큰 항목이 있음을 육안 확인했다(값 출력 금지). Enter'
# 4) 인수 전 값 — 파일이 아니라 이 세션 변수에만 둔다(백업 3중: 이 변수 · PM · Vault kv)
$pre = kubectl -n cloudflared get secret cloudflared-tunnel -o "jsonpath={.data.TUNNEL_TOKEN}"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($pre)) { throw '인수 전 값 취득 실패 — 중단' }
$preUid = kubectl -n cloudflared get secret cloudflared-tunnel -o "jsonpath={.metadata.uid}"
if ([string]::IsNullOrWhiteSpace($preUid)) { throw '인수 전 UID 취득 실패 — 중단' }
$podsPre = kubectl -n cloudflared get pods -o "jsonpath={range .items[*]}{.metadata.name}/{.status.containerStatuses[0].restartCount} {end}"
"pods(pre) = $podsPre"
Read-Host '5) 이제 G4 PR을 머지한다. 머지하고 platform-secrets 가 Synced 가 된 뒤 Enter'

$r = kubectl -n cloudflared get externalsecret cloudflared-tunnel -o "jsonpath={.status.conditions[?(@.type=='Ready')].reason}"
if ($LASTEXITCODE -ne 0) { throw 'ES 상태 취득 실패 — 판정 불가' }
if (-not [string]::Equals($r, 'SecretSynced', [StringComparison]::Ordinal)) { throw "ES reason=$r — Secret은 손대지 않았을 가능성이 높다(provider 실패는 Secret 미변경). 파드 재시작 금지, 원인 확인" }
$post = kubectl -n cloudflared get secret cloudflared-tunnel -o "jsonpath={.data.TUNNEL_TOKEN}"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($post)) { throw '인수 후 상태 취득 실패 — 판정 불가' }
if (-not [string]::Equals($pre, $post, [StringComparison]::Ordinal)) { throw '⚠ 터널 값이 바뀌었다 — 파드를 재시작하지 말 것(실행 중 파드의 옛 값이 안전망). 되돌리기 R1 로' }
$postUid = kubectl -n cloudflared get secret cloudflared-tunnel -o "jsonpath={.metadata.uid}"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($postUid)) { throw '인수 후 상태 취득 실패 — 판정 불가' }
if (-not [string]::Equals($preUid, $postUid, [StringComparison]::Ordinal)) { throw '⚠ UID 가 바뀌었다 = 제자리 인수가 아니라 재생성이다 — 파드 재시작 금지, 되돌리기 R1/R2 로' }
$own = kubectl -n cloudflared get secret cloudflared-tunnel -o "jsonpath={.metadata.ownerReferences}"
if ($LASTEXITCODE -ne 0) { throw 'ownerReferences 조회 실패 — 판정 불가(빈 문자열을 "없음"으로 읽지 않는다)' }
if (-not [string]::IsNullOrWhiteSpace($own)) { throw 'ownerReferences 가 붙었다 — creationPolicy 가 Orphan 이 아니다. ES 를 지우지 말 것, 매니페스트 확인' }
# 단일 소유(D3 조건 2 · VD-21): 이 ES 를 관리하는 Application 이 platform-secrets 하나인지
kubectl -n cloudflared get externalsecret cloudflared-tunnel -o "jsonpath={.metadata.annotations.argocd\.argoproj\.io/tracking-id}"
kubectl -n argocd get app platform-cloudflared -o "jsonpath={range .status.resources[*]}{.group}/{.kind} {end}"   # external-secrets.io 0건
$podsPost = kubectl -n cloudflared get pods -o "jsonpath={range .items[*]}{.metadata.name}/{.status.containerStatuses[0].restartCount} {end}"
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($podsPost)) { throw '파드 상태 취득 실패 — 판정 불가' }
if (-not [string]::Equals($podsPost, $podsPre, [StringComparison]::Ordinal)) { throw "파드가 바뀌었다(pre=$podsPre post=$podsPost) — 원인 확인" }
'OK 값 불변 · UID 불변 · ownerRef 없음 · 파드 불변 — rollout restart 는 하지 않는다'

Read-Host '6) 드릴: 파드 **1개만** 삭제해 새 자격으로 뜨는지 본다(반대쪽 커넥터가 살아 있다). Enter'
$one = (kubectl -n cloudflared get pods -o "jsonpath={.items[0].metadata.name}")
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($one)) { throw '삭제 대상 파드 이름 취득 실패 — 중단' }
kubectl -n cloudflared delete pod $one
if ($LASTEXITCODE -ne 0) { throw '파드 삭제 실패 — 드릴 판정 불가, 원인 확인' }
kubectl -n cloudflared rollout status deploy/cloudflared "--timeout=180s"
if ($LASTEXITCODE -ne 0) { throw '새 파드가 Ready 가 되지 않는다 — 남은 파드가 살아 있는 동안 되돌리기 R1/R2' }
ssh ssh-a hostname;  if ($LASTEXITCODE -ne 0) { throw 'ssh ssh-a 실패' }
kubectl get nodes
Remove-Variable pre, post, preUid, postUid -ErrorAction SilentlyContinue   # ⚠ 되돌리기 R2 에서 $pre·$preUid 가 필요하다 — 복구가 끝난 뒤에만 지운다
```

- **게이트(합격 문면):**
  - ES의 reason이 `SecretSynced`입니다.
  - `OK 값 불변 · UID 불변 · ownerRef 없음 · 파드 불변`이 출력됩니다.
  - ES의 tracking-id가 `platform-secrets`이고, `platform-cloudflared`의 `status.resources`에 `external-secrets.io` kind가 0건입니다(VD-21).
  - **VD-23(D3 조건 5 b) — 세 가지가 모두 성립해야 PASS입니다.**
    ① `kubectl get validatingwebhookconfiguration secretstore-validate externalsecret-validate -o jsonpath='{range .items[*]}{range .webhooks[*]}{.rules[*].resources}{"\n"}{end}{end}'` 출력이 `secretstores`·`clustersecretstores`·`externalsecrets`뿐입니다(다른 kind를 가로채지 않습니다).
    ② `platform-cloudflared`의 `status.resources`에 `external-secrets.io` 0건입니다(위 블록에서 이미 출력했습니다).
    ③ `kustomize build platform/cloudflared | kubectl apply --dry-run=server -f -`의 종료 코드가 0입니다.
    라이브 교란 드릴(webhook을 실제로 내리는 것)은 `selfHeal` 때문에 PR로만 가능하므로 T048의 선택 항목입니다(R-23).
  - 드릴 후 새 파드가 Ready입니다. 로그에 `Registered tunnel connection`이 찍힙니다(연결 수는 T039 기록과 대조합니다).
  - `ssh ssh-a hostname`이 성공합니다.
  - `kubectl get nodes`가 2 Ready입니다.
- **되돌리기(ESO 재기록을 전제로 한 순서).** Secret을 수동으로 복구하기만 하면 **5분 안에 ESO가 되돌립니다.** 아래 순서를 따릅니다.
  - **R1(값 문제, 1순위).** 원인은 kv 값입니다.
    1. 파드 재시작을 금지합니다.
    2. **§5 단계 8의 "정정 블록"으로 kv를 정정합니다.** OP1의 `$seed`로는 할 수 없습니다 — `$seed`는 값이 이미 있으면 중단하고 최초 쓰기가 `-cas=0`이라 덮어쓰기를 거부하는 것이 설계입니다. 정정 블록은 `current_version`을 읽어 `-cas=<N>`으로 쓰고 되읽기 해시를 비교합니다.
       - 값의 출처: (a) 라이브가 아직 옳으면 라이브에서 다시 읽습니다 (b) 라이브가 이미 덮였으면 `$pre`를 base64 디코드합니다 (c) PM 값을 `Read-Host -AsSecureString`으로 넣습니다.
    3. 다음 refresh(5분 이내)까지 기다립니다. VD-15의 force-sync로 앞당길 수도 있습니다.
    4. 값이 `$pre`와 같은지 다시 비교합니다.
  - **R2(ESO 개입 자체를 멈춰야 할 때 — 두 ES 공통 절차, D4-④).**
    1. revert PR을 머지합니다. 이것을 먼저 하지 않으면 `selfHeal`이 ES를 다시 만듭니다.
    2. **Git 제거가 Argo에 반영됐는지 확인합니다.** `platform-secrets`의 `status.sync.revision`이 revert 커밋이고, 해당 ExternalSecret이 `requiresPruning`으로 표시되어야 합니다(`prune: false`라 표시만 되고 지워지지는 않습니다). 이 확인 없이 다음 단계로 가면 삭제한 ES가 곧바로 되살아납니다.
       ```
       kubectl -n argocd get app platform-secrets -o "jsonpath={.status.sync.revision}"
       kubectl -n argocd get app platform-secrets -o "jsonpath={range .status.resources[?(@.kind=='ExternalSecret')]}{.name}/{.requiresPruning}{'\n'}{end}"
       ```
    3. `kubectl -n cloudflared delete externalsecret cloudflared-tunnel`을 실행합니다.
       - Orphan이므로 Secret은 남습니다.
       - **평시에는 금지, 이 비상 시에만 허용**입니다.
       - webhook이 죽어 DELETE가 거부되면 `kubectl delete validatingwebhookconfiguration externalsecret-validate`를 실행한 뒤 다시 시도합니다.
    4. **Secret 잔존·UID·값을 확인합니다**(`$preUid`·`$pre`와 대조).
    5. 값이 깨졌으면 stdin JSON으로 복구합니다.
       ```
       (@{apiVersion='v1';kind='Secret';type='Opaque';metadata=@{name='cloudflared-tunnel';namespace='cloudflared'};data=@{TUNNEL_TOKEN=$pre}} | ConvertTo-Json -Compress -Depth 5) | kubectl apply --server-side --force-conflicts "--field-manager=t045-restore" -f -
       ```
    6. 파드를 1개씩 교체합니다.
    7. ⚠ 컨트롤러를 `scale --replicas=0`으로 내리는 것은 `platform-external-secrets`의 selfHeal이 되돌립니다. 수 분짜리 임시 수단일 뿐입니다.
    - 같은 절차를 DNS ES(`cert-manager/cloudflare-dns-token`)에도 그대로 씁니다 — 두 ES 모두 `Orphan`이라 4)의 "Secret 잔존"이 성립합니다.
  - **R3(이미 잠김).**
    1. 열어 둔 노드 A SSH 세션에서 `sudo k3s kubectl`로 R1 또는 R2를 수행합니다.
    2. 그 세션이 없으면 OCI CLI로 임시 22 규칙을 넣습니다(`instances.tf` 5단계).
    3. 복구합니다.
    4. 8단계의 방법으로 규칙을 제거합니다.
- **라이브 영향:** **높음.**
  - 값이 같으면 실행 중인 파드에 영향이 없습니다.
  - 값이 달랐다면 증상은 다음 전면 파드 교체에서 나타납니다. 그래서 값 불변 확인과 드릴이 통과 조건입니다.
  - **T045가 완료되기 전에 T048을 하지 않습니다.**

