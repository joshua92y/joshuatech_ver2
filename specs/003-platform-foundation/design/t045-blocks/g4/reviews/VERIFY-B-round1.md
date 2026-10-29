CHANGES_REQUESTED

검증자 B(잠금·의미) 결과입니다. 파드 삭제로 가는 게이트에는 우회로가 없고, critical/high 신규 지적도 없으며, 원래 high였던 K8S-01은 해소됐습니다. CHANGES_REQUESTED인 이유는 값이 덮였을 때 나오는 복구 안내문이 사실과 다르고 없는 입력 경로를 가리키기 때문입니다(B-1·B-2). 둘 다 `g4-adopt.ps1` finally 절의 문면 수정과 최선 노력 조회 1건으로 끝나는 크기입니다.

검증 범위는 다음과 같습니다.
- 세 파일을 전부 읽었습니다.
- 원본 하네스를 재실행해 `PASS 67 / 67`, lint clean을 확인했습니다.
- 블록의 `-o` 템플릿 24개(서로 다른 식 15개)를 AST로 그대로 추출해 client-go v0.34.1 jsonpath(AllowMissingKeys=true)와 text/template 실물에 통과시켰습니다.
- 추가 모의 시나리오 VB-01~09를 돌렸습니다.
- 라이브 kubectl·vault·ssh·oci 호출은 0건이고, 저장소와 검수 대상 파일은 수정하지 않았습니다(mtime 16:00~16:28 그대로).

산출물은 `C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-blocks\_verB-lock\` 에 있습니다(`extract.ps1`, `ast-names.ps1`, `jp\main.go`, `lens-scenarios.ps1`, `lens-out2.txt`).

## (1) `& $kdel`(g4-adopt L384)에 도달하는 필요조건

- **C1** L134-136: 노드 목록에 `node/joshtech-api`가 있어야 합니다.
- **C2** L137-140: `auth can-i get secrets`와 `delete pods`의 응답이 문자열 `yes`여야 합니다(허용 rc는 0,1).
- **C3** L164-168: ssh 새 연결이 되면 boot_id 8자 대조가 일치해야 합니다.
- **C4** L173: 단어 `go` / `no-oci` / `noglass` 중 실측에 맞는 것을 입력해야 합니다.
- **C5 신규 경로**:
  - L177: managed 라벨이 비어 있어야 합니다.
  - L195-198: 키 집합이 `TUNNEL_TOKEN` 하나여야 합니다.
  - L200-202: ES가 없어야 합니다.
  - L205-214: 단일 GET에서 uid·값이 비어 있지 않고 라벨이 비어 있어야 합니다.
  - L215-219: 파드가 2개이고 둘 다 Ready여야 합니다.
- **C5 resume 경로** L182-191: `resume` 입력 뒤 preHash·preUid·파드서명이 형식 검사를 통과해야 합니다. `nopods`면 L337에서 삭제하지 않습니다.
- **C6** L230-244: `pm`(해시 일치) 또는 `skip-pm`.
- **C7** L252: `merge` 또는 `continue`.
- **C8** L260-284: 매 회차 값 해시와 UID가 기준값과 같아야 하고, 900초 안에 ES reason이 `SecretSynced`여야 합니다.
- **C9** L287-326: 값·UID 불변, ownerRef 빈 값, managed가 `true`, Secret에 tracking-id 없음, ES tracking-id 첫 토막이 `platform-secrets`, `status.resources`가 비어 있지 않고 `external-secrets.io/`가 0건, data-hash 있음, 파드서명이 기준과 같아야 합니다.
- **C10** L337: 기준 파드서명이 있어야 합니다.
- **C11** L341-350: 파드 2개, ES creationTimestamp 형식 통과, 인수 뒤 시작한 Ready 파드가 없어야 합니다(있으면 SKIP이고 삭제는 0건).
- **C12** L360: 남길 파드가 Ready여야 합니다.
- **C13** L365: `drill`.
- **C14** L368-377: 값·UID를 다시 읽어 기준값과 같아야 합니다.
- **C15** L378-383: 남길 파드가 1개 존재하고 Ready이며 서명이 그대로여야 하고, 삭제 대상이 1개 존재해야 합니다.

조회 실패·빈 값·타임아웃으로 충족되는 조건은 없습니다.
- `$kq`는 비0 종료가 3번 이어지면 throw합니다.
- 타임아웃 두 곳은 모두 throw합니다.
- "빈 값 = 통과"로 읽는 곳은 ownerRef, Secret tracking-id, ES 부재 셋뿐이며 모두 exit 0이 전제입니다. tracking-id 식은 같은 식이 ES 쪽에서 비어 있지 않은 값으로 확인됩니다(양성 대조).
- 막지 않는 조건은 설계대로 C3·C4 둘뿐입니다(B-4 참고).
- try/catch가 예외를 삼키는 곳은 ssh·oci 프로브, `$podNow` 조회, 삭제 뒤 대기 루프뿐이고, 모두 삭제에 앞선 게이트가 아닙니다.

## (2) 클러스터 쓰기 호출 전수(AST)

- **adopt**: 네이티브 호출은 kubectl 3종(`$kq`, `$klog` logs, `$kdel` `delete pod … --wait=false`)과 ssh 2건(`cut …boot_id`, `hostname`), oci 1건(`iam region list`)입니다. `$kdel` 호출 지점은 L384 한 곳입니다. `& $kq` 23건은 L138의 `auth can-i`를 뺀 전부 `get`입니다.
- **restore**: kubectl 2종(`$kq` 9건은 get과 `auth can-i patch`, `$kapply`는 L155 한 곳)입니다.
- 요구 (h)는 성립합니다.

## (3) K8S-01 줄 단위 확인 — 해소

- 머리 주석 L3-8이 "컨테이너 시작 시마다"로 고쳐졌습니다.
- L53-55에 `$podNow`·`$recover`가 추가됐습니다.
- throw 직전의 파드서명 최선 노력 조회가 6곳(L263-265, 268-270, 289-291, 294-296, 371-373, 375-377)에 들어가 요청된 4곳보다 많습니다.
- finally 0번(L460-464)이 제안문과 일치합니다.
- `g4-restore.ps1` L14-17과 `NOTES.md` L44·L97·L218이 같은 문장으로 고쳐졌습니다.
- 시나리오 G4-06이 이 문구들을 단언하며 PASS입니다.
- 블록 밖에 잔여가 있습니다. 이번에 머지할 gitops 브랜치 `t045-g4-tunnel-secret`의 `D:\code\platform-gitops\secrets\cloudflared\externalsecret-cloudflared-tunnel.yaml` L5("env를 파드 시작 시 1회만 읽는다")와 `platform\secrets\README.md` §5-6에 같은 무기한 문장이 남아 있습니다. 머지 전에 같은 문장으로 고치기를 권합니다.

## (4) 실제 도구 의존부 — 문제 없음

- **jsonpath**:
  - 식 15개가 모두 파싱·실행됩니다.
  - 라벨·어노테이션 맵이 아예 없는 수동 Secret에서도 빈 문자열이 나옵니다.
  - 미배치 Pending 파드는 `name|||`로 나와 4토막 분리가 유지됩니다.
  - `requiresPruning`은 `=`, `=true`, 행 없음 세 경우가 구분됩니다.
  - `containerStatuses: []`만 EXEC-ERR입니다. omitempty라 실물에서는 나오지 않는 형태이고, 발생해도 조회 실패로 fail-closed입니다.
- **cloudflared 매니페스트(`platform\cloudflared\deployment.yaml`)와 블록 가정**이 일치합니다.
  - 라벨 `app: cloudflared`, replicas 2, required anti-affinity, maxSurge 0입니다.
  - env `TUNNEL_TOKEN`은 secretKeyRef `cloudflared-tunnel/TUNNEL_TOKEN`(optional 아님)입니다.
  - 단일 컨테이너라 `containerStatuses[0]`과 `logs`에 `-c`가 필요 없습니다.
  - liveness와 readiness가 `/ready`(등록된 edge 연결이 있을 때만 200)이므로 "새 파드 Ready"가 곧 토큰이 유효하다는 증거입니다. liveness는 10초×6, memory limit은 256Mi입니다.
- **ES 매니페스트(같은 브랜치)**: secretKey `TUNNEL_TOKEN`, key `platform/cloudflare/tunnel`, property `token`, Orphan / Retain / Periodic / 5m, `template.metadata: {}`.
- **Argo**:
  - `bootstrap\argocd\argocd-cm.yaml` L39에 `resourceTrackingMethod: annotation`이 있습니다.
  - tracking-id 형식 `app:group/Kind:ns/name`의 첫 토막이 앱 이름이라 L312 판정은 옳습니다.
  - `platform-secrets`는 `prune: false` + `selfHeal: true`라 R2 순서의 전제가 성립합니다.
- **모노레포**: `infra\cloudflare\outputs.tf`에 `tunnel_token` 출력이 있습니다. `tunnel.tf`에 `tunnel_secret` 지정이 없어 preHash를 화면에 출력해도 역산이 불가능하다는 NOTES §3 (e)의 근거가 성립합니다. `infra\oci\instances.tf` 5·8단계도 확인했습니다.
- **판단 (g)**: 드릴 뒤 ssh 실패를 경고로 두는 것에 동의합니다. 마지막 단계이고, 같은 터널의 권위 있는 검사(`kubectl get nodes`)는 throw합니다.

## (5)(6) 발견 목록

**B-1 · medium · 머지 전 수정** — `g4-adopt.ps1` L465 복구 안내가 원인을 "kv 값이다"로 단정하고, kv가 옳은 경우의 분기가 없습니다.
- ES의 secretKey 매핑이 틀리면 인수 순간 `TUNNEL_TOKEN` 키가 삭제됩니다(DR1 실측 동작). 블록은 이를 "값이 바뀌었다"로 옳게 잡습니다.
- 그런데 안내는 R1(kv 정정)로 보냅니다. kv-correct는 root 토큰과 port-forward까지 거친 뒤 SKIP으로 끝나고, 그동안 K8S-01의 노출 시간이 흐릅니다. 키가 없는 상태는 틀린 값보다 나쁩니다(컨테이너가 시작하면 CreateContainerConfigError).
- 재현: VB-02에서 안내에 `R1(1순위 · 원인은 kv 값이다)`가 나오고 키 집합 진단은 없습니다. 복구 블록 자체는 이 상태에서도 정상 동작합니다(VB-06).
- 세 경우의 올바른 순서는 다음과 같습니다.
  - kv가 틀린 경우: R1 → ESO refresh → resume.
  - 매핑이 틀린 경우: R1은 무의미하고 곧장 R2로 갑니다.
  - 둘 다 맞고 Secret만 틀어진 경우: ≤5분 기다리면 ESO가 되돌립니다. 또는 `g4-restore`를 `temporary`로 돌린 뒤 5분 후 재실행해 SKIP을 확인합니다.
- 수정안:
  - 값 분기의 throw 직전에 `$podNow`와 같은 방식으로 키 집합을 최선 노력으로 읽어(비밀 아님 · L195의 go-template 재사용) `지금 키 집합: …`을 출력합니다. `TUNNEL_TOKEN`이 없거나 다른 키가 있으면 "원인은 ES 매핑이다 — R1을 건너뛰고 R2"로 안내합니다.
  - R1 문면을 "kv 값이 틀린 경우 — 출처 c. **SKIP(현재 kv 값과 같다)이 나오면 kv는 옳다 = 원인은 ES 매핑/ESO 쪽 → 곧장 R2**"로 고칩니다.
  - 오경보 확인용으로 "g4-restore를 먼저 돌려 2)의 해시 대조가 SKIP이면 값은 옳다"를 추가합니다.
  - NOTES L219가 컨트롤러에 미룬 `temporary` 용도는 안내에 넣는 쪽을 권합니다. R1·R2가 끝날 때까지 노출 창을 줄이는 유일한 수단입니다.

**B-2 · medium · 머지 전 수정** — L466이 `kv-correct.ps1`에 없는 입력 경로를 가리킵니다.
- kv-correct의 출처는 a/b/c뿐입니다(`kv-correct.ps1` L74-88). stdin 경로는 없습니다.
- 출처 b(`$pre`)는 G4 v2가 세션 변수를 만들지 않으므로 죽은 경로입니다.
- "넷째 출처 = tofu output을 파이프로만"은 어디로 파이프할지가 없습니다. 비상 중의 운영자가 argv나 파일로 즉흥 처리하게 만듭니다.
- "라이브가 아직 옳으면 a"는 이 분기에서 정의상 거짓입니다. a는 덮인 값을 읽어 SKIP만 냅니다.
- 수정안: "출처는 c(PM)뿐이다. PM이 틀렸을 때만 `tofu -chdir=infra/cloudflare output -raw tunnel_token | Set-Clipboard` → 출처 c에 붙여넣기(블록이 즉시 클립보드를 비운다)."

**B-3 · medium-low · 권고** — `g4-restore.ps1` L111이 Argo Application 조회에 무조건 의존합니다.
- 조회가 실패하면(Application CR 부재 등) 값이 틀린 채로 유일한 복구 도구가 막다른 길이 됩니다(VB-09).
- ES가 살아 있는 분기에서는 이 조회 결과가 쓰이지도 않습니다.
- 응답이 빈 문자열이면 "더 이상 선언하지 않는다"로 읽습니다(VB-05, 안전 규칙 4 취지 위반). 항상 있어야 할 `cert-manager/cloudflare-dns-token=` 행으로 양성 대조를 할 수 있습니다.
- 수정안: 최선 노력으로 바꾸고, 실패하거나 대조 행이 없으면 경고와 함께 단어를 `temporary`로 둡니다. 더 신중한 단어가 되는 쪽이고 복구 자체는 막지 않습니다.

**B-4 · medium-low · 권고** — L170-173에서 두 break-glass 프로브가 모두 실패해도 단어가 `no-oci` 하나입니다.
- 문면이 OCI 절반만 설명하므로, 확인된 break-glass가 0인 상태로 머지와 파드 삭제까지 갑니다(VB-01).
- 수정안: 둘 다 실패일 때는 별도 단어(예: `no-breakglass`)와 "1차·2차 모두 미확인"을 명시합니다.
- 부수: 원 설계는 NSG OCID를 사전에 확보했는데(`tofu … output -raw nsg_cluster_id`) 새 블록에서는 빠졌습니다. 잠긴 뒤에 찾으면 늦으니 미리 확보하라는 안내 한 줄을 권합니다.

**B-5 · low** — L476 R3 "창 A의 ssh 세션에서 sudo k3s kubectl로 R1/R2"는 실행할 수 없는 지시입니다.
- kv-correct와 g4-restore는 Windows PowerShell 블록이고 터널을 전제로 합니다.
- 실제로 잠긴 상황에서 화면에 실행 가능한 절차가 없습니다.
- 노드 쪽 stdin 전용 한 줄을 넣거나 런북 절을 지정하고, "R3에서는 두 블록을 쓸 수 없다"를 명시하기를 권합니다.

**B-6 · low** — L182 "기록이 없으면 … PM 원본과 1P로 대조한다"는 도달할 수 없는 안내입니다.
- 라벨이 붙은 뒤에는 모든 실행이 1R로 강제되고, 1P는 그 뒤에만 나옵니다(VB-08).
- g4-restore도 preHash를 요구합니다.
- 1R에 "PM 토큰으로 preHash를 유도"하는 분기를 두거나 문구를 삭제하기를 권합니다.

**B-7 · low** — R2 뒤 재인수 흐름이 모순됩니다.
- 라벨이 남아 1R로 들어가고, 2) 문면은 "이미 머지된 상태다 — 새로 머지하지 않는다"인데 ES가 없습니다. 그대로 따르면 15분 타임아웃으로 끝납니다(VB-03).
- resume 경로에서 ES가 없으면 "인수 해제 상태 — 재인수라면 지금 머지"로 분기하기를 권합니다.
- L475의 "(라벨을 먼저 지운다)"에는 "g4-restore가 SKIP(해시 일치)을 낸 뒤에만"이라는 조건을 붙이기를 권합니다. 라벨을 지우면 가드 ⓐ가 풀립니다.

**B-8 · low** — L378-383의 삭제 직전 재확인이 파드 수 2를 다시 단언하지 않습니다.
- 3개인 상태로 삭제하면 `$nw.Count -eq 1`이 영원히 거짓이라 300초 타임아웃으로 끝납니다(VB-07).
- maxSurge 0이라 실제로는 드뭅니다. `@($pd2.items).Count -ne 2 → throw` 한 줄이면 됩니다.

**B-9 · low(문면)** — 세 곳입니다.
- L447의 미판정 경고에 K8S-01의 "미루지 않는다 · 재부팅·SUC·drain 금지"가 없습니다.
- L237의 "라이브가 옳고 PM이 낡았다는 뜻이다"는 과단정입니다. 실행 중 컨테이너는 시작 시점의 값을 쓰므로, Secret과 PM이 다르다는 사실만으로 어느 쪽이 옳은지 알 수 없습니다. "대시보드나 tofu output과 대조"가 정확한 문면입니다.
- `g4-restore.ps1` L183의 "파드를 1개씩 교체"는 adopt의 "두 번째는 교체하지 않는다"와 어긋납니다. "1개만, 드릴 규칙대로"로 고치기를 권합니다.

**B-10 · low** — `g4-restore.ps1` L123("Secret이 없으면 … 신규 생성 절차다")은 죽은 코드입니다. Secret이 없으면 L120의 `get secret`이 exit 1이라 `$kq`가 일반 문면으로 먼저 throw합니다.

## 확인만 하고 문제없음으로 닫은 것

- **오경보**: resume 입력 오타 같은 오경보는 가짜 FAIL만 낳습니다. 가짜 PASS는 구조상 나오지 않습니다.
- **startTime 동률**: 두 파드의 시작 시각이 같으면 이름 Ordinal 순으로 결정되고 삭제는 1건입니다(VB-04).
- **드릴 대상 선정**: startTime이 가장 늦은 파드를 고르므로, 운영자가 현재 서명을 넣어 재실행해도 옛 값을 든 커넥터는 삭제 대상이 되지 않습니다.
- **ESO의 Orphan 동작**: `isSecretValid`가 항상 true이므로 g4-restore의 `temporary`가 ≤5분 유효하다는 문면은 DR1 실측 302초와 맞습니다.
- **SSA `--force-conflicts`**: ESO의 Update 방식 쓰기와 충돌하지 않습니다.
- **PowerShell 파싱**: `& $sha (…).Trim()`이 멤버 접근으로 파싱됨을 실측했습니다.

## 운영 메모

- 검증 중 제 실수로 `python.exe -` 2개(PID 56996·53444, `D:\code\joshuatech_ver2\.venv\Scripts\python.exe`, 16:44:44 생성)가 stdin을 기다리며 유휴 상태로 떠 있습니다. 직접 종료하려 했으나 권한이 거부됐습니다. 제 턴이 끝날 때 백그라운드 명령과 함께 종료되도록 돼 있지만, 남아 있으면 수동으로 종료하셔도 됩니다. 다른 python 프로세스(pgAdmin)는 건드리지 않았습니다.
- `lens-out2.txt`의 VB-02·VB-07 'FAIL' 표기는 제 기대 문자열이 잘못된 탓입니다(`secretKey`가 `secretKeyRef`와 부분 일치했고, VB-07은 자리표시자였습니다). 관측된 블록 동작은 위 B-1·B-8에 적은 그대로입니다.