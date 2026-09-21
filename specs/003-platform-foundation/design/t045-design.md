# T045 최종 설계 — External Secrets Operator 2.10.0 · ClusterSecretStore 5 · kv 시드 · 수동 Secret 2장 ExternalSecret 인수

> 상태: 설계 종합본입니다(사실 렌즈 6개, 설계안 2개, 비평 2건을 합쳤습니다). 작성일 2026-09-17.
> **개정 2026-09-17: §2.14의 사용자 확정(D2 · D3 · D4 = B′ · D6 = A · D10)을 본문 전체에 반영했습니다.** 확정 내용의 정본은 §2.14이고, 본문과 어긋나면 §2.14가 이깁니다. 확정 이전의 권고 문면은 판단 근거로 남겨 두되, 각 결정 절 끝의 "→ 확정" 줄이 실제 채택안입니다.
> 범위는 `tasks.md:124` T045입니다. 문면은 동결이며 체크박스만 수정합니다.
> 이 문서에는 비밀 값이 없습니다. digest, 이름, 경로, 숫자는 사실 수집에서 확인된 것만 적었습니다. 확인하지 못한 것은 §7의 VD 번호로 넘겼습니다.
> sync-wave 숫자의 정본은 계약 `gitops-repo.md` §sync-wave 단일 표 하나입니다. 이 문서의 `15`와 `18`은 M0 계약 커밋에 넣을 제안값이고, 다른 README나 주석에 다시 적지 않습니다.

---

## 1. 결론 요약

### 1.1 T045의 실제 모양

T045에서 ESO 설치 자체는 부차적입니다. 실제 위험은 세 가지입니다.

- **잠금.** `cloudflared-tunnel` Secret은 SSH(노드 A·B)와 K8s API의 유일한 경로입니다(22 포트가 닫혀 있습니다). 이 Secret의 소유권을 ESO로 넘기는 동안 값이 바뀌면, 증상은 그 순간이 아니라 **다음 컨테이너 시작 때** 나타납니다 — 파드 교체(T048 재부팅, SUC, drain)뿐 아니라 **제자리 재시작**(liveness 실패 · OOMKill · 노드 재부팅)도 포함입니다(2026-09-21 정정, §2.2 표). 그래서 안전망에는 시한이 있고, 값이 틀린 상태는 **시한 상태**입니다.
- **조용한 실패.** dns 토큰이 틀려도 와일드카드 첫 갱신(≈2026-11-08)까지 약 7주 동안 증상이 없습니다.
- **오늘은 보이지 않는 순서 결함.** ClusterSecretStore를 wave 0 Application에 두면 Vault(wave 10)가 불가한 동안 그 Application이 Degraded가 됩니다. 이 상태가 root로 전파되어 뒤 wave 전체가 멈춥니다.

### 1.2 채택한 설계안과 이유

**설계 B(최소 단계)를 뼈대로 하고, 설계 A의 store 분리(D2)와 비평의 blocker·major 수정을 이식한 혼합안**을 택했습니다.

- **B에서 가져온 것 — 시드 방식.** 라이브 Secret을 Vault로 파이프 복사합니다(D5). 잠금 위험을 결정하는 변수는 "kv 값이 지금 돌아가는 값과 바이트 단위로 같은가" 하나입니다. 파이프 복사는 이 동일성을 구성으로 보장합니다. A는 이를 증명하려고 두 장치를 붙였고, 둘 다 새 노출을 만듭니다.
  - 카나리아 ExternalSecret(PR 2건): `prune: false` 때문에 라이브에서 지워지지 않고 터널 토큰 사본을 하나 더 남깁니다.
  - PM 해시 눈 대조: PM의 평문을 다시 클립보드로 꺼내게 합니다.
  - 그래서 둘 다 뺐습니다.
- **A에서 가져온 것 — store 5개의 별도 Application.** `platform/secret-stores/`를 Vault 뒤 wave에 둡니다. B의 "리소스 레벨 sync-wave + 런북 1줄"은 webhook 순서만 해결합니다. `argocd-cm`의 Application health Lua(:45-57)가 child 건강을 root로 전파하는 경로는 막지 못합니다. B대로면 Vault가 잠깐 불가해도 wave 0 Application이 Degraded가 되고 root sync가 그 자리에서 멈춥니다.
- **A에서 가져온 것 — D7 규칙 준수와 문면 유지.** RBAC 축소는 컴포넌트 PR과 같은 머지에 묶지 않습니다(T042 PR-5, T044 G0 `b490f18` 선례). 동결 문면의 `selfsubjectrulesreviews create`도 그대로 남깁니다.
- **두 설계 모두에 없던 것(비평 반영).**
  - 시드 블록을 fail-closed로 바꿉니다. 빈 값, 0이 아닌 exit, 해시 불일치에서 `throw`합니다.
  - 되돌리기 절차는 ESO가 Secret을 다시 덮어쓴다는 사실을 전제로 다시 썼습니다.
  - `secrets/`는 전용 컴포넌트 `platform/secrets/`가 배달합니다(**소비자 배포와 ExternalSecret 적용 작업의 분리** — 소비자 Application의 sync가 ESO admission에 묶이지 않습니다. Vault·ESO 장애 시의 Degraded와 root wave 대기가 없어지는 것은 **아닙니다**).
  - flannel `/32` 정책 PR을 넣습니다(현 상태가 이미 계약 위반입니다). 추가할 주소는 **머지 전 노드 A 실측으로 확정**하고, 그 머지는 자동 동기화라 **머지 = 적용**입니다.
  - break-glass 계약 문면을 M0에서 정정합니다.
  - 파일 리다이렉트 백업을 없앴습니다.
  - port-forward를 블록 밖으로 뺐습니다.
- **사용자 확정으로 더해진 것(§2.14).**
  - 두 ExternalSecret을 `Orphan`으로 통일하고 `refreshPolicy: Periodic`을 명시합니다(D4 = B′). 인수 해제 절차가 두 ES 공통이 됩니다.
  - `platform/secrets`의 **단일 소유**를 정적 검사 + 라이브 확인으로 강제합니다(D3 조건 2).
  - `Orphan`의 삭제·재생성 동작은 터널이 아니라 **테스트용 ES/Secret 드릴(DR1)**로 먼저 실측합니다(D4-⑤).
  - 시드 범위를 줄입니다 — Access 4경로와 `grafana-cloud`는 이연하고, `oci/s3`는 조건부입니다(D10).
  - 시드 블록에 `try/finally` 정리, 최초 쓰기 `-cas=0`, 재실행 해시 비교, 경로별 요약을 넣습니다(D10-⑤).

### 1.3 순서(요약)

```
M0   모노레포 contracts 단독 커밋(gitops-repo.md · hostnames-and-access.md)
G0   gitops: AppProject sourceRepos에서 ESO 줄 삭제 + cloudflared README ⑨의 "수동 Secret을 지운다" 즉시 정정(docs)
G1   gitops: platform/external-secrets = 차트 2.10.0 + SA 5 + eso-ca-reader Role (차트 기본 RBAC)
       └ VD-5 · VD-7 · VD-9 · VD-18  (VD-1은 G1 직후와 G1p 직후 두 번)
M1   모노레포: np-set-5 강화 커밋(G1p 머지 **전** — 머지 전에는 external-secrets 행이 FAIL, 머지 후 PASS가 기대 동작)
G1p  gitops: policies — external-secrets allow-apiserver-webhook에 노드 A flannel 출발 주소 /32 add-only (D6 = A 확정)
       └ 머지 전: 노드 A 실측(`ip -4 -o addr show flannel-wg` · `ip route get <노드 B 파드 IP>`의 src = 노드 간 경로의 출발 주소 · 가능하면 conntrack)으로
         추가할 /32를 확정 · 비상 접속 확인 · `kustomize build platform/policies | kubectl diff -f -`로 전체 대기 diff 확인
       └ ⚠ platform-policies는 automated(selfHeal) — **머지 = 자동 적용**이다(운영자 트리거 sync가 아니다)
G2   gitops: platform/secret-stores(store 5) + Application platform-secret-stores
       └ 게이트: 5장 Ready=True 그리고 reason=Valid
G2r  gitops: rbac.serviceAccountTokenCreate false + resourceNames Role (D7 — 단독 PR)
OP1  운영자 창: kv 시드(라이브 Secret 2건 파이프 복사 + 드릴용 비밀 아닌 kv 1건) — 사용자 입회
       └ 이번 범위 = dns-token · tunnel (+ oci/s3는 완전한 키 쌍 확인 시에만) · platform/test/t045-probe
       └ 이연 = Access 4경로(T077·T092) · grafana-cloud(T098)
DR1  운영자 창: 테스트용 ExternalSecret/Secret 드릴(ns external-secrets · kv platform/test/t045-probe · kubectl 직접, git 미경유)
       └ 실측: Orphan 인수 시 UID·값·ownerRef · ES 삭제 뒤 Secret 잔존 · Secret 삭제 뒤 재생성 시점 · 정리
G3   gitops: platform/secrets + Application platform-secrets + secrets/cert-manager ES (저위험, VD-3)
G4   gitops: secrets/cloudflared ES  ⚠ 잠금 위험 단계 — 사용자 입회
G5   gitops: docs 정정(README 4건) / 모노레포: 하네스(eso-1 강화 · eso-4 신설 — np-set-5 강화는 M1) · 런북 · 설계 보존 · 체크박스
```

**선행조건(D6-⑤ 확정):** `G1 → G1p → admission PASS → G2`. G1은 ESO CR을 만들지 않으므로 webhook 없이도 적용되지만, G2(store 5장)는 webhook을 통과해야 하므로 G1p 반영과 admission 검증(유효한 ESO CR의 `kubectl apply --dry-run=server`가 **종료 코드 0 + `created (server dry run)`** 출력)이 필수 선행조건입니다.

gitops PR은 8건, 운영자 창은 3회(OP1 · DR1 · G4)입니다. OP1과 DR1은 같은 창에서 이어서 해도 되지만, OP1 블록의 `finally`가 `VAULT_TOKEN`·`VAULT_ADDR`를 이미 지우므로 **DR1 뒤 kv 정리 블록에서 root 토큰을 한 번 더 입력합니다**(창 C의 port-forward는 그대로 유지합니다). G4는 G3의 VD-3이 PASS한 뒤에만 엽니다.

### 1.4 결정 목록

확정 결과의 정본은 §2.14입니다. 아래 "권고안 → 확정" 열은 그 표를 읽기 쉽게 옮긴 것이고, 충돌하면 §2.14가 이깁니다.

| ID | 결정 | 권고안 → 확정 | 사용자 확인 |
|---|---|---|---|
| D1 | ESO 설치 형태·values | kustomize `helmCharts` 인플레이트. 3개 트리 명시. `installCRDs`와 `crds.create*`는 적지 않음 **→ 확정: 권고대로(A)** | 불필요(선례) |
| D2 | store 5개 배치 | 별도 컴포넌트 `platform/secret-stores/` + Application(Vault 뒤 wave) **→ 확정: B(§2.14)** | 확인 완료 |
| D3 | `secrets/<ns>/` 적용 주체 | 전용 컴포넌트 `platform/secrets/`가 `../../secrets/<ns>`를 base로 포함 + Application `platform-secrets` **→ 확정: B + 조건 5(범위 = ES 2장 · 단일 소유 · 효과 표현 정정 · 인수 해제 절차 · 검증 2종, §2.14)** | 확인 완료 |
| D4 | 인수 정책 | dns = `Owner`/`Retain`, 터널 = `Orphan`/`Retain` **→ 확정: B′ — 둘 다 `Orphan`/`Retain` + `refreshPolicy: Periodic`·`refreshInterval: 5m` + 조건 5(§2.14)** | 확인 완료 |
| D5 | 시드 출처·검증 | 라이브 Secret → Vault 파이프 복사. fail-closed 블록. 카나리아 없음 **→ 확정: 권고대로(A)** | 불필요 |
| D6 | webhook dial 정책 | flannel `10.42.0.0/32` add-only 정책 PR(계약 준수) **→ 확정: A + 조건 5(머지 전 실측으로 `/32` 확정 · platform-policies는 자동 동기화라 머지 = 적용 · np-set-5·validate 강화 · VD-1 판정 교체 · 노드 간 경로 미실측 한계, §2.14)** | 확인 완료 |
| D7 | RBAC 축소 시점 | G2 게이트 직후 단독 PR(G2r) **→ 확정: 권고대로(B)** | 불필요(D7 규칙) |
| D8 | ignoreDifferences | 넣지 않음. 실측 후 판단 **→ 확정: 권고대로(A)** | 불필요 |
| D9 | 토큰 캐시·refresh | 캐시 off. 모든 ES에 `refreshInterval: 5m` 명시 **→ 확정: 권고대로(A). D4-①로 `refreshPolicy: Periodic`이 함께 명시됨** | 불필요 |
| D10 | 시드 범위 | 필수 2 + `oci/s3` + Access 4경로. `grafana-cloud`는 보류 **→ 확정: 축소 — 필수 2 + (조건부) `oci/s3` + 드릴용 비밀 아닌 kv 1건. Access 4경로는 T077·T092로, `grafana-cloud`는 T098로 이연(§2.14)** | 확인 완료 |
| D11 | digest 병기 | 3개 트리 `tag`에 인덱스 digest. 렌더 grep은 3이어야 함 **→ 확정: 권고대로** | 불필요 |
| D12 | 문면의 무효 규칙·하네스 강화 | Role 문면 유지 + 무효 주석. eso-1 강화는 편차로 선언 **→ 확정: 권고대로** | 불필요(보고만) |
| D13 | PR 분할 | §1.3 **→ 확정: 권고대로 + 운영자 창에 DR1(테스트 ES 드릴) 추가** | 불필요 |

### 1.5 최대 차단 위험

1. **fail-open 시드.** `kubectl get secret … jsonpath`가 실패하면 빈 문자열이 나옵니다. `FromBase64String('')`은 예외 없이 빈 값을 돌려주고, 그 빈 토큰이 kv에 기록됩니다. 되읽기 비교는 빈 값끼리 같아서 통과합니다. 그러면 ESO가 라이브 터널 Secret을 빈 값으로 덮고, 다음 파드 교체에서 잠깁니다. 그래서 §5 OP1 블록의 모든 취득, put, 비교가 `throw`합니다.
2. **복구가 5분 안에 되돌려집니다.** `prune: false`이므로 revert 뒤에도 ES 객체가 남습니다. ESO는 kv 값으로 Secret을 다시 씁니다. `Orphan`은 GC만 없앨 뿐 데이터 덮어쓰기는 그대로입니다(D4-③). 컨트롤러를 `scale 0`으로 내려도 `platform-external-secrets`의 `selfHeal: true`가 곧 되돌립니다. 그래서 복구의 1순위는 kv 값 정정이고, ESO 개입 자체를 멈추려면 **revert 머지 → Argo 반영 확인 → `kubectl delete externalsecret`** 순서를 지켜야 합니다(D4-④ · §5 G4 되돌리기). 이 절차는 두 ES 공통입니다.
3. **webhook 전면 거부.** `failurePolicy: Fail`이고 `scope: Cluster`이며 CREATE·UPDATE·**DELETE**를 모두 가로챕니다. dial이 막히면 store와 ES의 적용은 물론 삭제도 막힙니다. ns `external-secrets` 정책에 flannel 주소가 없는 것은 T041이 T045로 미룬 미결 항목이고 계약 위반입니다(D6 = A 확정). 그래서 G1p 반영과 admission dry-run PASS가 G2의 선행조건입니다.
4. **가짜 PASS.** `serviceAccountRef.namespace`를 빠뜨린 store는 Vault에 한 번도 로그인하지 않았는데 Ready=True가 됩니다. **정정(2026-09-18 G2 리뷰, ESO 2.10.0 소스)**: 그때의 reason은 `ValidationUnknown`이 아니라 **`Valid`**(message `store validated`)라서 상태로는 구분할 수 없습니다. 판정 기준은 `Ready=True` 그리고 `reason=Valid`(k8s-data-ca의 SSRR 실패 = `ValidationUnknown`을 잡는다) **에 더해** vault store 4장의 spec `serviceAccountRef.namespace == external-secrets` 전수 확인입니다. 같은 성격의 가짜 PASS가 admission 검증에도 있습니다 — "오류 문자열이 없다"가 아니라 `--dry-run=server`의 **종료 코드 0 + `created (server dry run)`**이 판정 기준입니다(D6-③).
5. **자동 적용되는 정책 머지.** `platform-policies` Application은 `automated: {prune: false, selfHeal: true}`입니다. G1p는 "운영자가 따로 sync를 트리거하는" 단계가 아니라 **머지하는 순간 적용되는** 단계입니다(D6-②). 그래서 비상 접속 확인과 전체 대기 diff 확인이 머지 **전에** 끝나야 합니다.

---

## 2. 사용자 결정 목록

결정은 서로 독립적입니다. 한 번에 하나씩 물을 수 있습니다.

### D1 — ESO 설치 형태·values

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A. kustomize `helmCharts` 인플레이트** | cert-manager(T042)·vault(T044) 선례와 같습니다. source가 gitops 한 곳이라 sourceRepos 줄을 지울 수 있습니다. 로컬 렌더가 곧 적용 대상입니다. `crds.annotations` 한 줄로 CRD 25장에 sync-options가 붙습니다 | 렌더가 약 1.99 MB입니다. `charts/<name>-<version>` 캐시가 있으면 pull을 건너뜁니다 | 중간 — `values.schema.json`에 `additionalProperties`가 0곳이라 오타가 조용히 통과합니다 |
| B. Application `source.helm` | repo-server 안에서만 렌더합니다 | sourceRepos를 유지해야 합니다. 로컬 재현이 달라질 수 있습니다. 선례가 없습니다 | 중간 |

**권고: A.** 확정값은 다음과 같습니다.

- replicas는 3개 트리 모두 1입니다. `nodeSelector role: platform`도 3개 모두에 둡니다.
- securityContext는 계약의 4항목을 3개 트리에 명시합니다. 이 차트는 부분 지정 시 기본값과 깊은 병합을 합니다(실측). 그래서 `readOnlyRootFilesystem`과 `runAsUser 1000`은 유지됩니다.
- `webhook.port: 10250`과 `metrics.listen.port: 8080`을 명시합니다. 명시해야 validate 5.4b가 실제로 대조합니다.
- `metrics.service.enabled`는 기본 false로 둡니다(T098 인계).
- `rbac.servicebindings.create: false`로 둡니다.
- `crds.annotations`로 sync-options를 넣습니다.

**적지 않는 것**은 다음과 같습니다.

- `skipTests`: 이 차트에는 `templates/tests`가 없습니다.
- `installCRDs`와 `crds.create*`: 구 키와 신 키를 함께 썼을 때의 동작이 미검증입니다. `crds.createSecretStore`는 템플릿 참조가 0건인 죽은 키입니다.
- `scopedRBAC`: ClusterSecretStore와 충돌합니다.
- `processClusterExternalSecret`와 `tls.minVersion`: 문면 밖이고 라이브 검증을 하지 못했습니다. 후속 하드닝 후보로 report에 기록합니다.

**근거:** 이 차트는 오타에 대한 방어선이 렌더 grep뿐입니다. 그래서 로컬 렌더와 적용 대상이 같은 방식이어야 합니다.

→ 확정: **A(권고대로)** — 사용자 확인 불필요 항목으로 이견 없이 확정되었습니다(§2.14).

### D2 — ClusterSecretStore 5개의 배치 (사용자 확인 필요)

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A. `platform/external-secrets/`(wave 0)에 두고 리소스 레벨 wave "1" | 계약 표와 Application에 변경이 없습니다. webhook 순서 문제는 해결됩니다 | Vault가 불가한 동안 store Ready=False → Degraded → wave 0 Application Degraded → root sync 정지. 콜드 부트스트랩뿐 아니라 평시 Vault 재시작이나 KMS 장애에서도 같습니다 | 높음 — 오늘은 증상이 없습니다 |
| **B. `platform/secret-stores/` + Application `platform-secret-stores`(Vault 뒤, 제안 wave 15)** | 순서가 ESO(0) → Vault(10) → store로 자연스럽게 정렬됩니다. webhook 순환도 함께 해소됩니다. store만 단독으로 revert할 수 있습니다. ESO Application은 항상 Healthy로 남습니다 | 계약 §sync-wave 표에 한 줄, §디렉터리 열거 갱신, WAVE_TABLE에 한 줄, Application 1장이 늘어납니다 | 낮음 — validate 7.1·7.2의 정상 경로("표를 먼저 고친다")입니다 |
| C. `platform/vault/`에 같이 둠 | 표 변경이 없습니다 | 소유권이 흐려집니다. 되돌릴 때 Vault Application을 건드려야 합니다. `k8s-data-ca`는 Vault와 무관합니다 | 중간 |

**권고: B.** SA 5개와 `eso-ca-reader` Role은 `platform/external-secrets/`(wave 0)에 남깁니다. store 검증이 SA TokenRequest를 필요로 하고, ns `data`는 policies wave에서 이미 만들어지기 때문입니다.

**근거:** task 문면의 `platform/external-secrets/`는 ESO Application의 경로 지정으로 읽었습니다. store 5개는 `+`로 병렬 나열된 산출물입니다. 계약 표를 고치는 결정이므로 사용자 확인 대상입니다.

**남는 한계:** 콜드 부트스트랩에서는 Vault가 init과 시드를 마칠 때까지 이 Application이 Degraded입니다. **정정(2026-09-18 G2 리뷰, Argo CD v3.5.2 소스 판독)**: root는 이 wave에서 **기다리지 않습니다** — 첫 sync operation에서만 실패하고 retry부터 `ApplyOutOfSyncOnly`가 이미 만들어진 CR을 건너뛰어 진행하며 root health만 Degraded로 남습니다. 실제 대기 지점은 wave 10(Vault init 전 Progressing)이고, 시드 순서는 Argo가 아니라 런북 절차가 보장합니다(VD-11 · R-21).

→ 확정: **B**(§2.14) — `platform/secret-stores/` + Application `platform-secret-stores`(Vault 뒤 wave). 계약 §sync-wave 표와 `tests/validate.sh` WAVE_TABLE에 각각 한 줄을 추가하며, M0 계약 커밋이 선행입니다. 설계 대비 변경은 없습니다.

### D3 — `secrets/<ns>/`의 적용 주체 (사용자 확인 필요 — 두 비평의 의견이 갈린 항목)

전제: `clusters/oci-k3s/apps/`에 `secrets` 경로를 가리키는 Application은 0건입니다. 파일만 두면 클러스터에 도달하지 않습니다.

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A. 소비자 컴포넌트 kustomization이 base로 포함(`platform/cert-manager-issuers`, `platform/cloudflared`) | Application 0개, 계약 표 변경 없음. wave가 소비자와 자동 정렬됩니다. 교차 디렉터리 base는 실측(rc=0)했습니다. 검사 3.2가 유지됩니다 | **터널 Application의 sync가 ESO webhook 가용성에 묶입니다.** `failurePolicy: Fail`이고 child Application에는 `retry`가 없습니다(`retry:`는 root 1건뿐). webhook 장애 중에는 cloudflared Deployment 수정도 Argo로 밀 수 없습니다. issuers(ClusterIssuer, 와일드카드)에도 같은 결합이 생깁니다 | 중간 — 장애 대응 경로가 좁아집니다 |
| **B. 전용 컴포넌트 `platform/secrets/`(kustomization이 `../../secrets/<ns>`를 base로 포함) + Application `platform-secrets`(store 뒤·issuers 앞, 제안 wave 18)** | 원본 파일이 `secrets/`에 남아 검사 3.2(`RE_LOC_SECRETS='^secrets/'`)가 유지됩니다. 7.1의 `platform-<comp>` ↔ `platform/<comp>` 규칙을 특례 없이 만족합니다. **소비자 배포(cloudflared·issuers)와 ExternalSecret 적용이 분리**되어, 소비자 Application의 sync가 ESO admission에 묶이지 않습니다. ES만 단독으로 revert할 수 있습니다 | 계약 표 한 줄, WAVE_TABLE 한 줄(`secrets 18 -`, `policies`와 같은 `-` 형식), Application 1장. D2로 이미 표를 고치므로 늘어나는 비용은 작습니다. ⚠ Vault·ESO 장애 시 store(15)·secrets(18) Application의 Degraded와 root wave 대기는 **없어지지 않습니다** | 낮음 |
| C. ES를 `platform/<comp>/`로 옮김 | 눈에 잘 보입니다 | **검사 3.2가 조용히 꺼집니다**(경로 트리거가 `^secrets/`입니다) | 높음 |

**권고: B.** `platform/secrets`에서 base 2개를 끄는 렌더는 아직 실측하지 못했습니다(VD-13). 같은 메커니즘(`platform/external-secrets` → `../../secrets/cert-manager`)은 rc=0으로 확인했습니다.

**A를 택하는 경우의 조건:** 런북에 다음을 명시합니다. "ESO webhook 장애 시 `platform-cloudflared`는 sync가 불가하다. 비상 경로는 노드 A에서 `sudo k3s kubectl`이다."

**근거:** 검사를 살리는 선택지는 A와 B뿐입니다. 잠금 관점에서는 터널 컴포넌트가 다른 오퍼레이터의 admission에 의존하지 않는 쪽이 낫습니다.

→ 확정: **B + 사용자 조건 5개**(§2.14). 본문 전체에 다음과 같이 반영했습니다.

1. **범위.** `platform/secrets`는 이번에 DNS 토큰·터널 토큰 ES **2장만** 담습니다. CA 미러 ES는 원본(CNPG·Strimzi CA) 생성 이후인 계약 §sync-wave 표 40번 행(`cnpg-databases`·`kafka-topics`) 소유로 남깁니다(T056). `platform/secrets/README.md`에 범위와 "새 ES를 추가할 때는 원본·소비자 wave를 먼저 확인한다"를 적습니다(§4.7 · §4.10 · §9 T056).
2. **단일 소유.** 각 ES는 `platform-secrets`만 관리합니다. 소비자 컴포넌트(`platform/cert-manager-issuers` · `platform/cloudflared`)의 kustomization은 `secrets/<ns>`를 base로 포함하지 않습니다. 정적 검사(`../../secrets/*`를 base로 가지는 kustomization은 `platform/secrets` 하나뿐 — validate 신설 검사 7.3 + 긍정·부정 픽스처, G3에 포함)와 라이브 확인(각 ES의 Argo tracking 어노테이션 = `platform-secrets`, 다른 Application의 `status.resources`에 `external-secrets.io` ExternalSecret 0건)을 둡니다(§5 단계 9 · VD-21).
3. **효과의 표현.** B의 효과는 "**소비자 배포와 ExternalSecret 적용 작업의 분리**"입니다. Vault·ESO 장애 시 store(15)·secrets(18) Application의 Degraded와 root wave 대기는 제거되지 않습니다(WAVE_TABLE 실측: issuers 20 · cloudflared 60). 파생 결과: **콜드 부트스트랩에서는 root가 wave 60의 cloudflared까지 가지 못하므로, 터널 Secret과 cloudflared는 T039 절차대로 수동으로 먼저 올리고 ESO 인수(Orphan)는 Vault init·시드 뒤에 일어납니다.** 런북 §3 T045 절과 `platform/secrets`·`platform/cloudflared` README에 명시합니다(R-21 · VD-11).
4. **인수 해제 절차.** `prune: false`라 파일 revert만으로는 ES가 남아 인수가 해제되지 않습니다. 기존 Secret을 보존한 채 조정을 멈추는 절차를 터널뿐 아니라 **DNS ES에도** 둡니다 → 그래서 DNS ES의 정책을 D4에서 `Orphan`으로 다시 정했습니다(B′).
5. **검증 추가.** (a) 조건 2의 정적·라이브 단일 소유 확인. (b) "ESO webhook 장애 중에도 터널 Deployment를 독립적으로 변경할 수 있다"는 **구조 검증 2건 + server-side dry-run**으로 판정합니다 — `platform-cloudflared`의 `status.resources`에 `external-secrets.io` kind 0건, `ValidatingWebhookConfiguration`의 `rules`가 `secretstores`·`clustersecretstores`·`externalsecrets`만, 그리고 cloudflared Deployment의 `kubectl apply --dry-run=server` 통과. webhook을 실제로 내리는 **라이브 드릴은 selfHeal 때문에 PR로만 가능**하므로 T048(계획된 교란 창)의 선택 항목으로 인계합니다(§9 T048 · R-23).

### D4 — 수동 Secret 2장의 인수 정책 (사용자 확인 필요 — 계약 예시의 예외)

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A. 둘 다 `Owner`/`Retain` | 계약 예시와 같습니다 | Owner는 controller ownerReference를 심습니다. 그러면 `kubectl delete externalsecret cloudflared-tunnel` 한 번으로 Secret이 GC됩니다. `Retain`은 이것을 막지 못합니다(공식 매트릭스 "No (GC via ownerRef)") | 터널에 높음 |
| **B. dns = `Owner`, 터널 = `Orphan`(둘 다 `Retain`)** → 확정은 이 행의 변형 **B′(둘 다 `Orphan`)** | 터널 Secret에 ownerRef가 없으므로 ES 삭제나 cascade로 사라지지 않습니다. Secret이 지워져도 ESO·Vault가 정상이면 다음 성공한 갱신에서 재생성됩니다. `Orphan`은 구 버전부터 있던 값입니다 | (B 원안은) 정책이 두 가지가 됩니다 → B′는 둘 다 Orphan이라 이 단점이 없습니다. 두 Secret 모두 Argo 고아 경고에 계속 뜹니다 | 낮음 |
| C. 터널 = `CreateOrMerge` | 즉시 재생성합니다 | v2 신규 값입니다. 키가 1개라 병합의 이점이 없습니다 | 중간 |

**권고: B.**

- 키 매핑은 template 없이 `secretKey` + `remoteRef.property`로 합니다.
  - `{secretKey: api-token, property: token}`
  - `{secretKey: TUNNEL_TOKEN, property: token}`
- kv 필드 이름의 정본은 data-model §8의 `token`입니다. gitops issuers README §11의 `property: api-token`이 오기이며 G5에서 정정합니다.
- `target.template.metadata: {}`만 선언합니다. template이 없으면 ESO가 ES의 라벨과 어노테이션을 Secret에 전부 복사합니다(Argo tracking-id 포함).
- `template.type`은 적지 않습니다. `target.immutable`도 쓰지 않습니다.
- 터널 ES에는 `argocd.argoproj.io/sync-options: Delete=false,Prune=false`를 붙입니다.
- 순서는 cert-manager 먼저, cloudflared 마지막입니다.

**근거:** 인수는 삭제 없이 됩니다. v2.10.0 `applyOwnership`은 다른 ExternalSecret이 소유자일 때만 거부합니다(소스 확인). 다만 **⚠ `Orphan`이어도 인수 시 `secret.Data`가 비워졌다가 다시 채워집니다.** 값 동일성이 필요한 이유입니다(D5).

→ 확정: **B′ — DNS·터널 둘 다 `creationPolicy: Orphan` / `deletionPolicy: Retain`**(§2.14). 원안 B에서 DNS를 `Owner` → `Orphan`으로 바꾼 이유는 D3 조건 4입니다. 인수 해제 절차를 두 ES에 공통으로 두려면 `Owner`(ES 삭제 시 Secret GC)로는 성립하지 않습니다. 사용자 조건 5개를 다음과 같이 반영했습니다.

- **D4-①** 두 ES에 `refreshPolicy: Periodic` · `refreshInterval: 5m`를 명시합니다(2.10.0 CRD enum = `CreatedOnce`·`Periodic`·`OnChange`). Secret이 지워졌을 때의 재생성은 "**ESO·Vault가 정상일 때 다음 성공한 갱신에서** 수행된다"로만 적습니다 — "`Owner`와 복구 시점이 같다"는 문구는 삭제했습니다(§4.8·§4.10·§5). 실제 시점(관리 Secret의 `reconcile.external-secrets.io/managed` 라벨 watch로 즉시 재조정되는지)은 **미확인**이며 D4-⑤ 드릴에서 실측합니다(VD-20).
- **D4-②** 두 Secret 모두 인수 전후 **UID 불변 · 값(해시) 불변 · `metadata.ownerReferences` 부재**를 확인합니다. G3(DNS) 게이트 블록을 G4(터널)와 같은 세 검사로 맞추고, §4.8의 YAML·주석(`Owner — GC 감수`)·검증·복구 설명을 Orphan 기준으로 고쳤습니다.
- **D4-③** `Retain`은 **잘못된 값의 덮어쓰기를 막지 않습니다** → 시드 fail-closed · 되읽기 비교 · 인수 전후 동일성 비교를 그대로 유지합니다.
- **D4-④** 인수 해제 절차(두 ES 공통): revert PR 머지 → **Git 제거가 Argo에 반영됐음을 확인**(Application 리비전 = revert 커밋 · 해당 ES가 `requiresPruning` 표시) → `kubectl delete externalsecret <name>` → **Secret 잔존·UID·값 불변 확인** → 필요 시 stdin JSON 복구 → 소비자 파드 1개씩 교체.
- **D4-⑤** `argocd.argoproj.io/sync-options: Delete=false,Prune=false`는 **Argo의 삭제·prune 방지 범위**로만 설명합니다(kubectl 삭제·ESO 동작과 무관). 정책의 삭제·재생성 검증은 **테스트용 ExternalSecret/Secret**으로 합니다 — ns `external-secrets`, kv `platform/test/t045-probe`(비밀 아닌 값), 운영자가 kubectl로 직접 적용·제거(git 미경유라 `prune:false` 잔존이 없습니다), 시점은 G2r 뒤·G3 앞(§5 단계 8b DR1).

**남는 대가:** 두 Secret 모두 ownerReference가 없으므로 Argo의 고아(orphaned) 리소스 목록에 계속 뜹니다. 드리프트가 아니며, `platform/secrets/README.md`에 그 사실을 적습니다.

### D5 — kv 시드의 출처와 검증

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A. 라이브 Secret → Vault 파이프 복사(dns·터널 2건)** | 동일성이 구성으로 보장됩니다. 사람이 값을 만지지 않습니다. 화면 출력이 0입니다. 카나리아가 필요 없습니다 | 라이브 값이 정본이 됩니다. PM 사본이 구식일 수 있습니다 | 낮음 — 터널과 rev 2 발급으로 운영 검증된 값입니다 |
| B. PM 재입력 + 해시 눈 대조 | PM이 정본으로 남습니다 | PM 평문을 다시 클립보드로 꺼내야 합니다. hex 눈 대조는 오판 여지가 있습니다. 개행이 섞일 수 있습니다 | 중간 |
| C. 카나리아 ES로 선증명 | 원본을 건드리지 않습니다 | PR이 2건 늘어납니다. `prune:false`로 라이브에 남습니다(토큰 사본 추가, eso-2가 카나리아 상태에 종속) | 중간 |

**권고: A.** 라이브에 없는 값(`oci/s3`, Access)은 `Read-Host -AsSecureString`으로 받습니다. 공통 규칙은 다음과 같습니다.

- 모든 put은 `… | vault kv put <path> -`(JSON stdin) 한 형식으로 합니다.
- `key=-`는 쓰지 않습니다. stdin을 한 번만 소비하고 개행까지 값으로 저장합니다.
- 값은 JSON **문자열**로만 넣습니다. 비문자열은 감사 로그에 평문으로 남습니다.
- 취득, put, 되읽기가 모두 `throw`하는 fail-closed 구조입니다.
- port-forward는 블록 밖에서 띄웁니다.
- PM과 라이브의 동일성은 T084에서 점검합니다. T045 이후 PM은 백업입니다.

→ 확정: **A(권고대로)**. 다만 시드 **범위**는 D10 확정으로 줄었고(라이브에 없는 값 중 이번에 받는 것은 `oci/s3`뿐, Access 4경로는 이연), 블록 구조는 D10-⑤로 보강됩니다(`try/finally` 정리 · 최초 쓰기 `-cas=0` · 재실행 시 해시 비교 · 경로별 요약).

### D6 — apiserver→webhook dial 정책 (사용자 확인 필요)

현 상태: 계약 `network-policy.md:37`과 `:126`은 webhook 행 3개 ns 모두에 flannel 터널 주소 `/32`를 요구합니다. 라이브 정책(`policies-common.yaml:722-729`)의 external-secrets 규칙에는 `10.0.7.78/32`뿐입니다. 어떤 검사도 이 편차를 잡지 못합니다(포트와 존재만 봅니다).

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A. 노드 A flannel 출발 주소 `/32` add-only 정책 PR(G1p)** | 계약을 준수합니다. cert-manager·cnpg-system 선례와 같습니다(두 ns에는 이미 `10.42.0.0/32`가 들어 있습니다). 허용 대상이 podCIDR 네트워크 주소라 실질 범위는 노드 A의 호스트 netns뿐입니다. `nodeSelector`라는 단일 전제에 기대지 않게 됩니다 | `platform-policies`는 **automated(selfHeal)**라 머지 = 자동 적용입니다(라이브 위험 구간). 그래서 확인은 전부 머지 **전**에 끝나야 합니다 | 낮음(add-only) |
| B. 실측에서 통과하면 정책은 그대로 두고 계약을 ns별로 수정 | 정책 변경이 0입니다 | M0에 `network-policy.md` 편집이 추가됩니다. "노드 A 고정 + LOCAL 예외"가 영구 전제가 됩니다. 파드가 노드 B로 가면 전면 거부됩니다 | 중간 |

**권고: A.** VD-1은 G1 직후와 G1p 직후에 두 번 기록합니다. 머지 전에 `kubectl get node <A> -o jsonpath='{.spec.podCIDR}'`로 `10.42.0.0/24`인지 다시 대조합니다(VD-19).

→ 확정: **A + 사용자 조건 5개**(§2.14). 반영 내용은 다음과 같습니다.

- **D6-①** 머지 전에 운영자가 노드 A에서 `ip -4 -o addr show flannel-wg`(장치 주소)와 `ip route get <webhook 파드 IP>`의 `src`(라우팅 출발 주소)를 재실측하고, 가능하면 conntrack으로 실제 dial 출발 주소까지 확인해 **추가할 `/32`를 그 값으로 확정**합니다. podCIDR 대조(VD-19)만으로 끝내지 않습니다. T042 기록으로는 `flannel-wg` 장치 주소가 노드 A podCIDR의 네트워크 주소(`10.42.0.0`)였으므로 같은 값이 나올 것으로 예상하지만, **확정값은 실측 결과입니다**(§5 단계 5 · VD-19).
- **D6-②** **설계 전제 정정.** `platform-policies` Application은 `automated: {prune: false, selfHeal: true}`입니다 — 이 문서의 이전 문면("운영자 트리거 sync 1회")은 틀렸습니다. 자동 동기화는 그대로 두고, 머지를 운영자 창에서 (a) 비상 접속 경로 확인 (b) `kustomize build platform/policies | kubectl diff -f -`로 **전체 적용 대기 diff가 "external-secrets `allow-apiserver-webhook`에 ipBlock 1줄 추가"뿐임을 확인**한 뒤에만 합니다.
- **D6-③** 검증 보강. 모노레포 `tests/platform/cluster.tests.ps1`의 `np-set-5`를 webhook 3개 ns(`cert-manager`·`external-secrets`·`cnpg-system`)에 대해 **정확한 두 출발 주소(노드 A private IP `/32` · 노드 A flannel 출발 주소 `/32`)와 포트**를 요구하도록 강화합니다(현재는 "아무 `/32` + 포트"만 봅니다). `vault` 8200 행은 private IP만 요구합니다(webhook이 아니라 port-forward 도착 경로). gitops `tests/validate.sh` 5.x에도 같은 정적 검사를 둡니다. admission 검증의 판정 기준은 "오류 문자열 부재"가 아니라 **유효한 ESO CR의 `kubectl apply --dry-run=server` 종료 코드 0 + `created (server dry run)` 출력**으로 교체합니다(VD-1).
- **D6-④** 노드 A에서의 성공을 **노드 간 통신 검증으로 기록하지 않습니다.** ESO의 Deployment 3개(`role=platform`)와 API 서버가 모두 노드 A라, 실측되는 것은 동일 노드 경로뿐입니다. 런북 §3 T045 절과 `platform/external-secrets/README.md`에 "ESO의 노드 간 webhook 경로는 미실측"이라는 한계를 명시합니다.
- **D6-⑤** 정책 반영(G1p)과 admission 검증(D6-③의 dry-run PASS)은 **G2의 필수 선행조건**입니다: `G1 → G1p → admission PASS → G2`. G1 자체는 ESO CR이 없어 webhook 없이도 적용됩니다.

### D7 — RBAC 축소 시점

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A. G1에 같이 넣음 | 전역 `serviceaccounts/token create`의 노출 창이 0입니다 | **표준 제약 D7을 위반합니다**(권한 축소와 컴포넌트를 한 머지에 묶음). store 실패의 원인이 섞입니다 | 규약 위반 |
| **B. G2 게이트(`reason=Valid`) 직후 단독 PR(G2r)** | 규칙을 지킵니다. "원래 안 되던 것"과 "축소가 깨뜨린 것"을 분리할 수 있습니다. 노출 창이 G1~G2r로 짧습니다 | PR이 1건 늘어납니다 | 낮음 |
| C. T045 끝 또는 후속 task로 미룸 | — | 노출 창이 깁니다(임의 SA 사칭 = Vault 인증 우회 경로) | 중간 |

**권고: B.** 노출 창은 report.md에 기록합니다. `scopedRBAC`는 쓸 수 없습니다.

→ 확정: **B(권고대로)** — G2 게이트 직후 단독 PR(G2r).

### D8 — ignoreDifferences

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A. 넣지 않고 실측** | 렌더된 webhook 설정에 `caBundle` 필드가 없습니다. Secret `external-secrets-webhook`에는 `data`가 없습니다. 희망 상태에 없는 필드입니다. 저장소 전체에서 실사용 0건이라는 점도 유지됩니다 | 미검증입니다 | 낮음 — VD-5(15분 간격 2회) |
| B. 선제적으로 추가 | 드리프트를 원천 차단합니다 | 근거 없이 첫 선례를 만듭니다. 진짜 드리프트를 가립니다 | 중간 |

**권고: A.** `webhook.certManager.enabled`로 바꾸는 방법(cert-controller의 전역 secrets read 제거)은 계약 변경이 필요하므로 범위 밖입니다. report의 "잔여 권한"에 기록합니다.

→ 확정: **A(권고대로)** — 넣지 않고 VD-5로 실측합니다.

### D9 — 토큰 캐시·refreshInterval

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A. 캐시 off + 모든 ES에 `5m` 명시** | 계약 §공통 규칙과 reboot-4(마감이 reboot-2 + 300s)에 맞습니다. 토큰이 메모리에 상주하지 않습니다 | 로그인이 시간당 약 72회(모델 추정)이고, 감사 로그(file+stdout)에 3종 이벤트가 남습니다 | 낮음 — VD-8 |
| B. `--enable-vault-token-cache` | 부하가 크게 줄어듭니다 | 토큰이 최대 1시간 상주합니다. 감사 흔적이 줄어듭니다 | 중간 |

**권고: A.** CRD 기본값 `1h`를 쓰면 T048이 확정적으로 FAIL합니다.

→ 확정: **A(권고대로)**. D4-①에 따라 두 ES에 `refreshPolicy: Periodic`을 **함께** 명시합니다(`refreshInterval`만으로는 정책 필드가 기본값에 의존합니다).

### D10 — 시드 범위 (사용자 확인 필요)

| 경로 | 값 소재 | 소비자 | 권고 → 확정 |
|---|---|---|---|
| `kv/platform/cloudflare/dns-token` {token} | 라이브 Secret + PM | G3 ES | **시드(필수)** → 확정: 시드 |
| `kv/platform/cloudflare/tunnel` {token} | 라이브 Secret + PM + tofu data source | G4 ES | **시드(필수)** → 확정: 시드 |
| `kv/platform/oci/s3` {access_key, secret_key} | PM(Secret 절반이 있는지는 창 전에 확인) | 후속(CNPG barman-cloud) | 시드. 절반이 없으면 재발급 후 시드 → **확정: 조건부 시드** — `svc-s3-backup`의 **완전한 기존 키 쌍(두 절반 모두)**이 PM에서 확인될 때만. 없으면 **자동 재발급하지 않고** 별도 발급·교체 작업으로 분리 |
| `kv/{dev,prod}/access/web-bff`, `kv/platform/access/tester-{m2m,k8s}` {client_id, client_secret} | PM에만 있음(T011) | T092·T077. ESO 밖 경로 | 시드 권고 → **확정: T077·T092로 이연** — `eso-platform`(`kv/data/platform/*`)·`eso-dev`/`eso-prod`(`kv/data/{env}/*`) role의 읽기 범위에 들어가고 tester의 취득·전달 경로도 미확정이므로, 권한과 전달 절차를 먼저 확정한 뒤 시드합니다. PM 복구 사본은 유지합니다 |
| `kv/platform/grafana-cloud` | URL과 instance id가 저장소에 없음 | T098 | **보류**(sentinel 금지) → 확정: 실제 소비자(T098 Alloy) 기준으로 키 집합을 확정한 뒤 **T098 전에** 시드 |
| `kv/platform/test/t045-probe` (신규, 비밀 아닌 값) | 드릴용으로 이 창에서 생성 | DR1 테스트 ES(§5 단계 8b) | — → **확정: 시드**(드릴이 끝나면 kv 경로까지 삭제) |

**grafana-cloud 키 집합:** data-model §8의 4키는 T098 소비자(research R10의 `*_instance_id`)와 어긋납니다. 그런데 `data-model.md`는 plan 산출물이고, 이 task가 편집을 허용한 것은 `contracts/`뿐입니다. 그래서 **T045는 data-model.md를 고치지 않습니다.** 불일치는 T098 인계와 converge에 기록합니다. 사용자가 data-model 편집을 승인하면 contracts 커밋과 분리된 별도 커밋으로 처리합니다.

**sentinel을 넣지 않는 이유:** 소비자가 없으므로 이득이 없습니다. kv v2는 구 버전을 기본 10개 보존합니다.

→ 확정: **시드 범위 축소 + 사용자 조건**(§2.14). 위 표의 "확정" 열이 결과이고, 절차에는 다음이 더해집니다.

- **D10-④** T045 **완료 보고(report · 런북 · 체크박스 커밋)에 이연 범위를 명시**합니다 — Access 4경로, `grafana-cloud`, 그리고 해당 시 `oci/s3`. `data-model.md`는 고치지 않습니다(불일치는 T098 인계 + converge).
- **D10-③** OCI 키 쌍이 없으면 **"T053 백업 구성 전 완료"** 인계 항목으로 남깁니다(§9 T053).
- **D10-⑤** OP1 시드 블록을 다음과 같이 보강합니다(§5 단계 8).
  - `try { … } finally { … }` — 실패해도 `VAULT_TOKEN`·중간 변수·클립보드 상태를 정리합니다.
  - 최초 쓰기는 `vault kv put "-cas=0" <path> -` — 경로에 이미 값이 있으면 거부됩니다.
  - 재실행 시 기존 버전이 있으면 덮어쓰지 않고 해시를 비교해 **"이미 시드됨(동일)" / "존재하지만 다름 → 중단"**으로 가릅니다.
  - **경로별 완료·보류·실패 요약**(블록 끝 표 + 런북 기록)과 **재실행 절차**(실패 경로만 다시, 성공 경로는 CAS가 보호)를 둡니다.
  - 기존 fail-closed 규칙(빈 값·비0 exit·해시 불일치 `throw`, JSON stdin, port-forward는 블록 밖)은 그대로입니다.

### D11 — 이미지 digest

권고는 3개 트리 `tag`에 `"v2.10.0@sha256:814117b0fd6d121b03e8ba3b6db1cecbe7449a354fc0fc9c4faf73a37aa221b1"`을 넣는 것입니다. 이 값은 멀티아치 인덱스 digest이고 arm64를 포함합니다.

이 차트에는 `image.digest` 키가 없습니다. validate 4b는 helm 블록 표기를 보지 못하므로 자동 검사가 0입니다. G1 게이트의 렌더 grep이 **3**이어야 한다는 조건이 유일한 방어선입니다. `InvalidImageName`이 나면 태그만 쓰는 폴백으로 갑니다(vault D6 선례).

→ 확정: **권고대로**.

### D12 — 문면의 무효 규칙과 하네스 강화(보고 사항)

`eso-ca-reader` Role에는 실효가 없는 규칙이 있습니다.

- `list`·`watch`: `resourceNames`와 양립하지 않습니다.
- `selfsubjectrulesreviews create`: 클러스터 스코프 리소스이고, `system:basic-user`가 이미 부여합니다.

이 규칙들은 **문면대로 유지하고 무효 근거를 주석으로 답니다.** 계약에는 각주를 추가합니다. 삭제는 VD-7의 결과를 보고한 뒤 converge에서 편차로 처리합니다.

eso-1을 `reason=Valid`로 강화하는 것은 T031 문면("Ready")보다 엄격합니다. report.md에 편차로 선언합니다.

→ 확정: **권고대로**. 하네스 강화 범위는 D6-③(`np-set-5`)과 D4(`eso-4`가 두 ES 모두의 `creationPolicy == 'Orphan'`을 검사)로 넓어집니다. 두 건 모두 report.md의 편차 항목에 함께 적습니다.

### D13 — PR 분할

§1.3과 같습니다. 각 PR은 다음 단계의 선행조건을 실측으로 확인합니다.

G0에 README ⑨ 정정을 앞당겨 넣은 이유는 다음과 같습니다. "수동 Secret을 먼저 지우라"는 문장이 남은 채로 운영자 블록이 통째로 실행되는 것이 단일 잠금 경로 중 가장 큽니다. 이 정정은 docs만 바꾸므로 라이브 영향이 0입니다.

→ 확정: **권고대로**. 운영자 창에 **DR1(테스트 ES 드릴, D4-⑤)**이 OP1 뒤·G3 앞으로 추가되어 창이 3회가 됩니다. DR1은 git을 거치지 않으므로 PR 수(8건)는 그대로입니다.

### 2.14 사용자 확정 기록 (2026-09-17 ~)

| 결정 | 확정 | 설계 대비 변경·조건 |
|---|---|---|
| D2 | **B** — `platform/secret-stores/` + Application `platform-secret-stores`(Vault 뒤 wave, 계약 §sync-wave 표·WAVE_TABLE 한 줄씩 — M0 계약 커밋 선행) | 없음 |
| D3 | **B** — 전용 컴포넌트 `platform/secrets/` + Application `platform-secrets`(store 뒤·issuers 앞 wave) + **사용자 조건 5개** | 아래 |

**D3 사용자 조건(전부 계약·라이브 사실과 대조해 적용 가능 판정):**

1. **범위 제한**: `platform-secrets`는 현재 DNS 토큰·터널 토큰 ExternalSecret 2장만 담는다. CA 미러 ExternalSecret은 원본(CNPG·Strimzi CA) 생성 이후인 계약 §sync-wave 표 40번 행(`cnpg-databases`·`kafka-topics`) 소유로 유지한다(T056). `platform/secrets/` README에 범위와 "새 ES를 추가할 때는 원본·소비자 wave를 먼저 확인한다"를 명시한다.
2. **단일 소유**: 각 ExternalSecret은 전용 Application(`platform-secrets`)만 관리한다. 소비자 컴포넌트(`platform/cert-manager-issuers`·`platform/cloudflared`)의 kustomization은 `secrets/<ns>`를 base로 포함하지 않는다. 정적 검사(`../../secrets/*` base를 포함하는 kustomization은 `platform/secrets` 하나뿐 — validate.sh 검사 + 픽스처, G3)와 라이브 확인(각 ES의 Argo tracking = `platform-secrets`, 다른 Application의 `status.resources`에 ExternalSecret 0건)을 둔다.
3. **효과의 표현**: B의 효과는 "소비자 배포와 ExternalSecret 적용 작업의 분리"다. Vault·ESO 장애 시 store(15)·secrets(18) Application의 Degraded와 root wave 대기는 **제거되지 않는다**(WAVE_TABLE 실측: issuers 20 · cloudflared 60). 파생: **콜드 부트스트랩에서는 root가 wave 60의 cloudflared까지 가지 못하므로 터널 Secret과 cloudflared는 T039 절차대로 수동으로 먼저 올리고, ESO 인수(Orphan)는 Vault init·시드 뒤에 일어난다** — 런북 §3 T045 절과 `platform/secrets`·`platform/cloudflared` README에 명시(R-21·VD-11 보강).
4. **인수 해제 절차**: `prune: false`라 파일 revert만으로는 ES가 남아 인수가 해제되지 않는다. 기존 Secret을 보존한 채 해당 ES의 조정을 멈추는 절차(revert PR 머지 → `kubectl delete externalsecret` → Secret 잔존 확인 → 필요 시 stdin JSON 복구 → 파드 1개씩 교체; 컨트롤러 scale 0은 selfHeal이 되돌리는 임시 수단)를 터널(G4 R2)뿐 아니라 **DNS ES에도** 명시한다. `Owner`는 ES 삭제 시 Secret이 GC되므로 DNS ES의 정책은 D4에서 이 조건을 기준으로 다시 정한다.
5. **검증 추가**: (a) Application별 단일 소유 확인(조건 2의 정적·라이브 검사) (b) "ESO webhook 장애 중에도 터널 Deployment를 독립적으로 변경할 수 있다"의 확인 — 게이트 = 구조 검증 2건(`platform-cloudflared`의 `status.resources`에 `external-secrets.io` kind 0건 · `ValidatingWebhookConfiguration`의 `rules`가 `secretstores`·`clustersecretstores`·`externalsecrets`만) + cloudflared Deployment server-side dry-run 통과. webhook을 실제로 내리는 라이브 드릴은 selfHeal 때문에 PR로만 가능하므로 T048(계획된 교란 창)의 선택 항목으로 인계한다.

- **실행 메모(2026-09-18, G2 리뷰에서 발견 — D2·D3의 전제 정정)**: 확정 조건에 적힌 "Vault·ESO가 불가하면 Degraded → root는 이 wave에서 기다린다"는 Argo CD v3.5.2 소스 판독으로 **틀렸다**. root sync는 이 Application CR을 처음 만드는 operation에서만 실패하고 retry부터는 `ApplyOutOfSyncOnly`가 이미 만들어진 CR을 건너뛰어 다음 wave로 진행하며, root **health**만 Degraded로 남는다. D2(store 분리)의 근거는 그대로 성립한다 — 분리하지 않으면 ESO Application 자체가 Degraded가 되고, 분리하면 Healthy로 남는다(health 격리). D3 조건 ③의 "Degraded·root 대기는 남는다"는 "Degraded·root health Degraded는 남는다"로 읽는다. 시드 순서는 Argo가 아니라 런북 절차가 보장한다. 계약 §sync-wave 15행은 `contracts/` 별도 커밋으로 정정했다. 또 D3 게이트 "Ready=True AND reason=Valid"는 유지하되, namespace 생략 store는 `Valid`로 나오므로 vault store 4장의 spec `serviceAccountRef.namespace` 전수 확인을 더한다(ESO 2.10.0 소스).

**D4 = B′ — DNS·터널 모두 `creationPolicy: Orphan` / `deletionPolicy: Retain`**(설계 원안 B에서 변경 — D3 조건 4 때문) **+ 사용자 조건 5개(ESO 2.10.0 CRD·소스와 대조해 적용 가능 판정):**

- **D4-①** 두 ES에 `refreshPolicy: Periodic` · `refreshInterval: 5m`를 명시한다(2.10.0 CRD enum = CreatedOnce·Periodic·OnChange). Secret이 지워졌을 때의 재생성은 "**ESO·Vault가 정상일 때 다음 성공한 갱신에서** 수행된다"로만 적는다 — "Owner와 복구 시점이 같다"는 문구는 삭제한다. 실제 시점(즉시 재조정 여부 — 관리 Secret의 `reconcile.external-secrets.io/managed` 라벨 watch)은 D4-⑤ 드릴로 실측한다(VD 추가).
- **D4-②** 두 Secret 모두 인수 전후 **UID 불변 · 값(해시) 불변 · `metadata.ownerReferences` 부재**를 확인한다. G3(DNS) 게이트 블록을 G4(터널)와 같은 세 검사로 맞추고, §4.8 DNS ES의 YAML·주석(`Owner — GC 감수`)·검증·복구 설명을 Orphan 기준으로 고친다.
- **D4-③** `Retain`은 잘못된 값의 덮어쓰기를 막지 않는다 → 시드 fail-closed · 되읽기 비교 · 인수 전후 동일성 비교를 그대로 유지한다.
- **D4-④** 인수 해제 절차(두 ES 공통): revert PR 머지 → **Git 제거가 Argo에 반영됐음을 확인**(Application 리비전 = revert 커밋 · 해당 ES가 `requiresPruning`으로 표시) → `kubectl delete externalsecret <name>` → **Secret 잔존·UID·값 불변 확인** → 필요 시 stdin JSON 복구 → 소비자 파드 1개씩 교체.
- **D4-⑤** `argocd.argoproj.io/sync-options: Delete=false,Prune=false`는 **Argo의 삭제·prune 방지 범위**로만 설명한다(kubectl 삭제·ESO 동작과 무관). 정책의 삭제·재생성 검증은 **테스트용 ExternalSecret/Secret**으로 한다: ns `external-secrets`, kv `platform/test/t045-probe`(비밀 아닌 값), 운영자가 kubectl로 직접 적용·제거(git 미경유 — `prune:false` 잔존 없음), 시점 = G2r 뒤·G3 앞. 실측 항목: Orphan 인수 시 기존 Secret UID·값·ownerRef · ES 삭제 뒤 Secret 잔존 · Secret 삭제 뒤 재생성 시점 · 정리(ES·Secret·kv 경로 삭제).

**D6 = A — 기존 private IP `/32` + TCP 10250 유지, 노드 A의 실제 flannel 출발 주소 `/32`를 add-only로 추가(G1p) + 사용자 조건 5개(저장소 현 상태와 대조해 적용 가능 판정):**

- **D6-①** 머지 전 운영자가 노드 A에서 `ip -4 -o addr show flannel-wg`(장치 주소)와 `ip route get <webhook 파드 IP>`의 `src`(라우팅 출발 주소)를 재실측하고(conntrack이 있으면 실제 dial 출발 주소도), 추가할 `/32`를 그 값으로 확정한다 — podCIDR 대조(VD-19)만으로 끝내지 않는다. T042 기록 = `flannel-wg` 장치 주소가 노드 A podCIDR의 네트워크 주소.
  - **실행 메모(2026-09-17, G1p 리뷰에서 발견)**: 위 문면의 "`<webhook 파드 IP>`"를 ESO webhook 파드로 읽으면 안 된다. ESO webhook은 API 서버와 **같은 노드 A**에 있어 그 경로는 flannel 터널 장치를 타지 않는다(같은 노드 경로의 `src`는 실측 전까지 단정하지 않는다). 정책의 flannel `/32`가 대표하는 것은 **노드 간** 경로의 출발 주소이므로, 값 확정용 `ip route get`의 대상은 **노드 B에 있는 파드**(cert-manager webhook — T042 VD-W와 같은 대상)다. ESO webhook 파드 쪽 `ip route get`과 파드 방화벽 체인의 `--src-type LOCAL` 행은 "왜 G1p 없이도 동일 노드 admission이 PASS했는가"의 참고 기록으로만 함께 측정한다. 사용자 조건의 취지(실제 flannel 장치·라우트 출발 주소 비교)는 그대로다.
- **D6-②** **설계 전제 정정**: `platform-policies` Application은 `automated: {prune: false, selfHeal: true}`다 — "운영자 트리거 sync 1회"가 아니라 **머지 = 자동 적용**이다. 자동 동기화는 유지하고, 머지는 운영자 창에서 (a) 비상 접속 경로 확인 (b) `kustomize build platform/policies | kubectl diff -f -`로 전체 적용 대기 diff가 "external-secrets `allow-apiserver-webhook`에 ipBlock 1줄 추가"뿐임을 확인한 뒤에만 한다.
- **D6-③** 검증 보강: 모노레포 `tests/platform/cluster.tests.ps1` `np-set-5`를 webhook 3개 ns(cert-manager·external-secrets·cnpg-system)에 대해 **정확한 두 출발 주소(노드 A private IP `/32` · 노드 A podCIDR 네트워크 주소 `/32`)와 포트**를 요구하도록 강화한다(현재는 "아무 `/32` + 포트"만 검사; vault 8200 행은 private IP만). gitops validate 5.x에도 같은 정적 검사를 둔다. webhook admission 검사는 "오류 문자열 부재"가 아니라 **유효한 ESO CR의 `kubectl apply --dry-run=server` 종료 코드 0 + `created (server dry run)` 출력**을 요구한다(VD-1 판정 기준 교체).
- **D6-④** 노드 A에서의 성공을 노드 간 통신 검증으로 기록하지 않는다. ESO 3개 Deployment(`role=platform`)와 API 서버가 모두 노드 A라 실측되는 것은 동일 노드 경로뿐이다 — 런북 §3 T045 절과 `platform/external-secrets/README.md`에 "ESO의 노드 간 webhook 경로는 미실측" 한계를 명시한다.
- **D6-⑤** 정책 반영(G1p)과 admission 검증(D6-③의 dry-run PASS)은 **G2(store 적용)의 필수 선행조건**이다: G1 → G1p → admission PASS → G2. (G1은 ESO CR이 없어 webhook 없이도 적용된다.)

**D10 = 두 번째 옵션 기반 — 시드 범위 축소 + 사용자 조건(현 정책·문면과 대조해 적용 가능 판정):**

- **D10-①** 이번에 시드: `kv/platform/cloudflare/dns-token`{token} · `kv/platform/cloudflare/tunnel`{token}(라이브 Secret → Vault 파이프 복사). `kv/platform/oci/s3`{access_key, secret_key}는 **`svc-s3-backup`의 완전한 기존 키 쌍(두 절반 모두)이 PM에서 확인되는 경우에만** 시드한다.
- **D10-②** Access 4경로(`kv/{dev,prod}/access/web-bff` · `kv/platform/access/tester-{m2m,k8s}`)는 **T077·T092로 이연**한다 — 현재 `eso-platform`(`kv/data/platform/*`)·`eso-dev`/`eso-prod`(`kv/data/{env}/*`) role의 읽기 범위에 들어가고 tester의 취득·전달 경로도 확정되지 않았으므로, 권한과 전달 절차를 먼저 확정한 뒤 시드한다. 독립적인 PM 복구 사본은 유지한다.
- **D10-③** OCI 키 쌍이 없으면 **자동 재발급하지 않는다** — 별도 발급·교체 작업으로 분리해 "T053 백업 구성 전 완료" 인계 항목으로 남긴다.
- **D10-④** `kv/platform/grafana-cloud`는 실제 소비자(T098 Alloy) 기준으로 키 집합을 확정한 뒤 T098 전에 시드한다. 임시 값·sentinel을 넣지 않는다. `data-model.md`는 고치지 않는다(불일치는 T098 인계 + converge). **T045 완료 보고(report·런북·체크박스 커밋)에 이연 범위(Access 4경로 · grafana-cloud · (해당 시) oci/s3)를 명시한다.**
- **D10-⑤** 시드 블록 보강: (a) **`try { … } finally { … }`** — 실패해도 `VAULT_TOKEN`·중간 변수·클립보드를 정리한다 (b) **최초 쓰기의 CAS 보호** — `vault kv put "-cas=0" <path> -`(경로에 값이 이미 있으면 거부) (c) 재실행 시 기존 버전이 있으면 덮어쓰지 않고 해시를 비교해 "이미 시드됨(동일)" / "존재하지만 다름 → 중단"으로 가른다 (d) **경로별 완료·보류·실패 기록**(블록 끝 요약 표 + 런북 기록)과 **재실행 절차**(실패 경로만 다시, 성공 경로는 CAS가 보호)를 둔다. 기존 fail-closed 규칙(빈 값·비0 exit·해시 불일치 `throw`, JSON stdin, port-forward는 블록 밖)은 유지한다.

**나머지(D1·D5·D7·D8·D9·D11·D12·D13)는 설계 권고대로 확정**(사용자 확인 불필요 항목 — 이견 없음).

---

## 3. 사실 근거

### 3.1 ESO 차트 2.10.0

| 사실 | 신뢰 | VD |
|---|---|---|
| chart 2.10.0 = appVersion v2.10.0입니다. HTTPS repo(`oci://` 금지)입니다. bitwarden 서브차트는 tarball에 동봉되어 있고 기본 disabled입니다 | verified | — |
| CRD 25장이 `templates/crds/`에 있고 `installCRDs` 기본값은 true입니다. `clustersecretstores`와 `secretstores` CRD가 각각 약 699 KB(YAML)로 262,144 B 한도를 넘습니다. 그래서 SSA가 필수인데, Application에 `ServerSideApply=true`가 이미 있습니다 | verified | — |
| `v1`이 served·storage이고 `v1beta1`은 `served:false`입니다. `crds.conversion.enabled`는 기본 false라 CRD에 conversion 스탠자가 없습니다 | verified | — |
| `crds.createSecretStore`는 죽은 키입니다(템플릿 참조 0건) | verified | — |
| `webhook.port 10250`, `metrics.listen.port 8080`입니다. webhook Service는 443 → targetPort 10250입니다 | verified | — |
| 3개 컴포넌트의 컨테이너 securityContext 기본값이 PSA restricted를 통과합니다. 부분 지정 시 깊은 병합을 합니다 | verified | VD-18 |
| `values.schema.json`에 `additionalProperties`가 0곳입니다. 오타가 exit 0으로 통과합니다 | verified | VD-12 |
| 이미지 3개 트리가 별개입니다. `image.tag`만 적으면 나머지 두 Deployment는 태그 pin으로 남습니다 | verified | VD-12 |
| 인덱스 digest는 `sha256:814117b0…221b1`이고 arm64를 포함합니다 | verified | VD-12(bump 시 재조회) |
| helm test hook이 0건입니다(`templates/tests` 없음) | verified | — |
| webhook 인증서: 빈 Secret `external-secrets-webhook`과 caBundle 필드가 없는 webhook 설정 2장을 cert-controller가 런타임에 채웁니다 | verified(렌더) / 드리프트 여부는 likely | VD-5 |
| `failurePolicy: Fail`입니다. rules는 `secretstores`·`clustersecretstores`·`externalsecrets`의 CREATE·UPDATE·DELETE입니다. core Secret은 가로채지 않습니다 | verified | VD-1 |
| webhook·cert-controller의 readinessProbe는 8081입니다(정책에 없음). controller에는 probe가 없습니다 | likely | VD-9 |
| 컨트롤러 ClusterRole 기본값은 전역 secrets CRUD와 `serviceaccounts/token create`입니다. `serviceAccountTokenCreate:false`로 렌더하면 ClusterRole에서 해당 규칙이 0건이 됩니다 | verified | VD-16 |
| 최상위 `namespace:` 변환기를 쓰면 ClusterSecretStore에 `metadata.namespace`가 찍힙니다 | verified | — |
| 인플레이트가 로컬에서 재현됩니다(kustomize 5.8.1 + helm 4.3.0). 차트 단독 43문서, kubeconform Invalid 0, CRD 25장은 Skipped입니다 | verified | VD-12 |

### 3.2 store ↔ Vault K8s auth 흐름(v2.10.0 소스)

| 사실 | 신뢰 | VD |
|---|---|---|
| `serviceAccountRef.namespace`를 생략하면 webhook은 통과시킵니다. store는 referent auth가 되어 로그인을 하지 않고 **`Ready=True/Valid`(message `store validated`)** 가 됩니다 — `ValidationUnknown`이 아닙니다(정정 2026-09-18: vault provider의 validate는 referent에 `(Unknown, nil)`을 돌려주고 컨트롤러는 err=nil이면 Valid로 찍는다. `ValidationUnknown`은 kubernetes provider의 SSRR/SSAR 호출 실패 때만) | verified(소스) | VD-2 |
| namespace를 명시한 store는 검증 시 실제 로그인을 합니다(TokenRequest → `auth/kubernetes/login` → `lookup-self`). `reason=Valid`가 실동작의 증거입니다 | verified | VD-2 |
| TokenRequest의 audience는 `audiences` 값 그대로이고 만료는 600초입니다. Vault role의 `audience="vault"`와 일치해야 합니다 | verified | VD-2 |
| TokenReview는 Vault 파드 SA가 수행합니다. `authDelegator.enabled: true`는 이미 라이브입니다 | verified | — |
| `conditions.namespaces`는 Ready와 무관합니다. ES 쪽에서만 평가됩니다(`denied by spec.condition`) | verified | — |
| store 재검증 주기는 기본 5분입니다. 캐시가 off면 Close마다 `revoke-self`를 합니다. 로그인은 시간당 약 72회입니다(모델 추정) | likely | VD-8 |
| role의 `token_type=service`가 필수입니다(batch면 매번 재로그인합니다) | verified | — |
| `path: kv` + `version: v2`면 경로가 `kv/data/<key>`가 됩니다. key에 `kv/` 접두를 붙이면 안 됩니다 | verified | — |
| kubernetes provider: `remoteNamespace`의 기본값은 `default`, `server.url`의 기본값은 `kubernetes.default`입니다. CA는 기본값이 없습니다. CSS에서는 `caProvider.namespace`가 필수입니다. audiences를 넣으면 401입니다 | verified | VD-10 |
| kubernetes provider의 Ready 판정은 SelfSubjectRulesReview 1회입니다. ResourceNames를 보지 않습니다. 대상 Secret이 없어도 Ready가 됩니다 | verified | VD-10 |
| `selfsubjectrulesreviews`는 클러스터 스코프입니다. `system:basic-user`가 기본 부여합니다 | verified(k8s 소스) | VD-7 |
| 네트워크 경로(egress → vault 8200, kube-api 6443, vault ingress ← external-secrets)가 이미 선언되어 있습니다 | likely | VD-2(로그 grep) |

### 3.3 수동 Secret 인수

| 사실 | 신뢰 | VD |
|---|---|---|
| `Owner`는 ownerReference가 없는 기존 Secret을 제자리에서 인수합니다. `ErrSecretIsOwned`는 다른 ES가 소유자일 때만 납니다 | verified(소스·문서) | VD-3 |
| Merge·CreateOrMerge가 아닌 정책은 `secret.Data`를 비우고 다시 채웁니다. 우리 Secret은 각각 키가 1개입니다 | verified | VD-3·4 |
| Owner는 ES 삭제 시 Secret이 GC됩니다. `Retain`은 이를 막지 못합니다 | verified | — |
| Orphan은 ownerRef가 없고, Secret이 삭제되면 ESO·Vault가 정상일 때 다음 성공한 갱신에서 재생성합니다(문서 매트릭스: Orphan·Periodic = at interval) | verified(문서 매트릭스) | VD-20 |
| provider 조회가 실패하면 Secret을 변경하지 않습니다(`SecretSyncedError` 후 return) | verified | — |
| template이 없으면 ES의 라벨·어노테이션이 전부 복사됩니다. Argo 3.5.2의 self-ref 가드 때문에 sync·prune에는 영향이 없습니다 | verified | — |
| 인수는 첫 조정에서 즉시 일어납니다(managed 라벨과 data-hash가 없기 때문입니다) | verified | VD-3 |
| cert-manager는 챌린지 순간에만 Secret을 읽습니다. cloudflared는 env를 시작 시 1회만 읽습니다 | ~~verified~~ **정정 2026-09-21(G4 리뷰 ML-3)** — env(`secretKeyRef`)는 파드가 아니라 **컨테이너가 시작할 때마다** kubelet이 다시 읽습니다. 파드 교체뿐 아니라 제자리 재시작(liveness 실패 · OOMKill · 크래시 · 노드 재부팅 = 파드 이름·UID 그대로, `restartCount`만 증가)도 포함입니다. cloudflared의 liveness는 `/ready` 10s × 6이라 **edge 단절이 약 60초 이어지면 두 커넥터가 파드 교체 없이 거의 동시에 재시작**할 수 있습니다. | — |
| **따라서 "실행 중 파드가 옛 값을 들고 있다"는 안전망은 컨테이너가 재시작되지 않는 동안만 유효합니다** — 값이 틀린 상태는 안전 상태가 아니라 **시한 상태**입니다(복구를 미루지 않고, 그동안 노드 재부팅·SUC Plan·drain을 하지 않습니다). 아래 §의 "증상은 다음 파드 교체 때 나타난다"류 서술은 전부 이 문장으로 읽습니다 | 정정 2026-09-21 | — |
| cloudflared는 `maxSurge 0`, `maxUnavailable 1`, required antiAffinity, replicas 2입니다. 그래서 파드 1개를 교체해도 안전합니다 | verified | VD-4 |
| break-glass의 실체는 OCI CLI 수동 NSG 규칙입니다(`infra/oci/instances.tf`의 5·8단계). tofu 변수가 아닙니다 | verified | — |
| gitops `platform/cloudflared/README.md` ⑨ 2단계의 "수동 Secret을 지운다"는 사실과 반대입니다 | verified | — |
| 재기록: 다음 갱신 주기(≤5분)에 ESO가 Secret을 kv 값으로 되돌립니다. 문서 매트릭스상 `Orphan`은 Secret 변경마다가 아니라 refresh 시점에만 재동기화합니다(관리 Secret watch에 의한 즉시 재조정 여부는 미확인 — VD-20) | verified(문서) / 즉시 여부 unverified | VD-20 |
| `force-sync` 어노테이션으로 즉시 refresh가 됩니다 | unverified | VD-15 |

### 3.4 계약·테스트·validate 정합

| 사실 | 신뢰 | VD |
|---|---|---|
| `secrets/`를 동기화하는 Application이 0건입니다. 계약 §sync-wave 표와 WAVE_TABLE에 해당 행이 없습니다 | verified | — |
| validate 7.1은 `platform-<comp>` → `platform/<comp>`를 강제합니다. 7.2는 `platform/*/` 디렉터리가 표에 있는지만 봅니다(표→디렉터리 역방향 검사는 없음) | verified(validate.sh:837-880) | — |
| WAVE_TABLE의 셋째 열(ns)은 helm 컴포넌트의 포트 경고에만 쓰입니다. `-`가 허용됩니다(`policies -10 -`) | verified(:735) | — |
| 검사 3.2의 트리거는 파일 경로 `^secrets/`입니다. `platform/` 아래로 옮기면 검사가 꺼집니다 | verified | — |
| validate는 `creationPolicy`·`deletionPolicy`·`refreshInterval`을 검사하지 않습니다(0건) | verified | T047 인계 |
| argo-4는 ESO 그룹 CRD 25장 전부에 `Delete=false,Prune=false`를 요구합니다 | verified | VD-12 |
| eso-1은 status만 봅니다. eso-2는 모든 ES가 SecretSynced여야 하고 0개면 FAIL입니다. eso-3은 cert-manager·cloudflared에 대해 `vault-platform` + `platform/`을 요구합니다 | verified | — |
| reboot-4의 마감은 reboot-2 + 300s입니다. CRD 기본값 1h면 FAIL합니다 | verified | — |
| store 이름은 정확히 5개입니다(SetEq). 6번째를 임시로 만들어도 안 됩니다 | verified | — |
| 계약 network-policy.md:37·:126은 external-secrets에도 flannel /32를 요구합니다. 라이브 정책에는 없습니다 | verified | VD-1·19 |
| 계약 §디렉터리는 "19개"를 열거하고 있습니다. §워크로드 강화의 helm 목록에 external-secrets가 없습니다 | verified | M0 |
| AppProject whitelist가 ESO 렌더의 모든 kind를 덮습니다. destinations 14개에 external-secrets·data·cert-manager·cloudflared가 들어 있습니다 | verified | — |
| datree 카탈로그에 CSS·ES v1 스키마가 있어 kubeconform `-strict`가 오타를 잡습니다 | verified | — |

### 3.5 gitops 배치·Argo 동작

| 사실 | 신뢰 | VD |
|---|---|---|
| Argo 3.5.2에 CSS·ES 내장 health Lua가 있습니다. `Ready=False`면 Degraded입니다. argocd-cm에는 이에 대한 커스텀이 없습니다 | verified | — |
| Application health Lua가 child 건강을 root로 전파합니다(wave 대기) | verified | VD-11 |
| child Application에는 `retry`가 없습니다(root만 있음). 실패한 revision은 auto-sync가 멈출 수 있습니다 | verified(grep) | — |
| `platform-external-secrets`는 `selfHeal:true`, `prune:false`입니다. 수동 scale은 되돌려집니다 | verified(매니페스트) / 되돌림 속도는 likely | — |
| 교차 디렉터리 base가 kustomize 5.8.1 RootOnly에서 rc=0입니다 | verified | VD-13(2-base 형상) |
| required check `validate`는 뼈대 상태입니다(T047). 로컬 `bash tests/validate.sh`가 유일한 증명입니다 | verified | — |

### 3.6 kv 시드·비밀 취급

| 사실 | 신뢰 | VD |
|---|---|---|
| 시드 토큰은 root입니다. T045에서 revoke하지 않습니다(D4, T084 이후) | verified | — |
| Access 서비스 토큰 4쌍과 터널 토큰은 PM과 `infra/cloudflare` state에 있습니다. T011의 "Vault 투입은 T043"은 오표기입니다 | verified | — |
| `vault kv put <path> -`의 JSON stdin은 go-secure-stdlib의 addReader로 확인했습니다. CLI 문서는 `vault write` 쪽에만 명시합니다 | likely | VD-6 |
| 감사 로그는 문자열만 HMAC 처리합니다. 장치가 1개이고 fail-closed입니다 | verified | — |
| kv v2는 기본 10버전을 보존합니다. `custom_metadata`는 metadata read 권한이 없어도 응답에 실립니다 | likely / verified | VD-14 |
| 안전 블록의 정본은 런북 §4입니다(Read-Host로 정지, 조건부 진행, 값 미출력, 클립보드 기록 `throw`) | verified | — |
| agent-view는 Secret get이 불가합니다. 그래서 값 대조는 운영자만 할 수 있습니다 | verified | — |
| `secret-rotation.md`는 없습니다(T084 산출물) | verified | — |

---

## 4. 파일 트리·매니페스트

```
platform-gitops/
├── clusters/oci-k3s/
│   ├── projects/platform.yaml                      # G0: sourceRepos 1줄 삭제
│   └── apps/
│       ├── platform-secret-stores.yaml             # G2 신규
│       └── platform-secrets.yaml                   # G3 신규
├── platform/
│   ├── external-secrets/
│   │   ├── kustomization.yaml                      # G1 (G2r에서 values 1줄 + resources 1줄)
│   │   ├── serviceaccounts.yaml                    # G1
│   │   ├── rbac-eso-ca-reader.yaml                 # G1
│   │   ├── rbac-token-create.yaml                  # G2r
│   │   └── README.md                               # G1
│   ├── secret-stores/                              # G2 신규 컴포넌트
│   │   ├── kustomization.yaml
│   │   ├── clustersecretstore-vault-{platform,dev,prod,data}.yaml
│   │   ├── clustersecretstore-k8s-data-ca.yaml
│   │   └── README.md
│   ├── secrets/                                    # G3 신규 컴포넌트(배달자 — 원본은 secrets/에 있음)
│   │   ├── kustomization.yaml
│   │   └── README.md                               # G3: 범위(ES 2장) · 단일 소유 · 콜드 부트스트랩 · 고아 경고
│   ├── policies/policies-common.yaml               # G1p: ipBlock 1줄 add-only(값은 D6-① 실측으로 확정)
│   ├── cloudflared/README.md                       # G0(⑨ 즉시 정정) · G5(확정값 · 콜드 부트스트랩 수동 선행)
│   └── cert-manager-issuers/README.md              # G5
├── secrets/
│   ├── README.md                                   # G3
│   ├── cert-manager/{kustomization.yaml, externalsecret-cloudflare-dns-token.yaml}   # G3
│   └── cloudflared/{kustomization.yaml, externalsecret-cloudflared-tunnel.yaml}      # G4
├── tests/validate.sh                               # G1p: 5.x webhook 출발 주소 정적 검사 / G2: WAVE_TABLE +secret-stores
│                                                   # G3: WAVE_TABLE +secrets · 7.3 `../../secrets/*` 단일 소유 검사
└── tests/fixtures/{pol-webhook-src, secrets-base-owner}/   # 위 두 검사의 긍정·부정 픽스처

joshuatech_ver2/
├── specs/003-platform-foundation/contracts/{gitops-repo.md, hostnames-and-access.md}  # M0
├── tests/platform/cluster.tests.ps1                # np-set-5 강화 = M1(G1p 머지 전) · eso-1 강화 · eso-4 신설(두 ES) = G5
├── docs/runbooks/{bootstrap.md, vault-unseal.md}
├── specs/003-platform-foundation/design/{t045-design.md, build-notes.md}
└── content/tmp/003-t045/<YYYY-MM-DD>.md
```

### 4.1 `platform/external-secrets/kustomization.yaml` (G1)

> **G1 리뷰 반영(2026-09-17):** 아래 블록은 4렌즈 리뷰 + 재검수 뒤의 최종 파일과 동일하다(주석 정정: `charts/` 캐시 키 = `<name>-<version>` · tgz sha256 대조 기록 · 전역 token create = 클러스터 admin 등가와 G2r의 범위 · cert-controller leases). 렌더는 설계 초안과 바이트 동일하다.

```yaml
# platform/external-secrets/ — External Secrets Operator 2.10.0 (chart 2.10.0 · appVersion v2.10.0) + eso-* SA 5 + eso-ca-reader RBAC (T045 G1)
#
# 정본 계약(모노레포 specs/003-platform-foundation/contracts/):
#   - gitops-repo.md §sync-wave 단일 표(wave 번호는 그 표에만 — 여기 다시 적지 않는다) · §ClusterSecretStore 5개 표 · §이름·인증 규약
#     · §삭제 보호(오퍼레이터 CRD 전부 `Delete=false,Prune=false` → 아래 `crds.annotations` 한 줄이 CRD 25장에 붙인다)
#     · §이미지(태그에 `@sha256` 병기) · §워크로드 강화(helm 컴포넌트는 values에 securityContext 4항목 명시)
#   - network-policy.md(ns `external-secrets` = PSA restricted · allow-apiserver-webhook 10250 · metrics 8080 ← monitoring ·
#     egress → vault 8200 · kube-api 6443)
#
# 설치 방식 = kustomize `helmCharts` 인플레이트(cert-manager T042 · vault T044 선례). 전제: argocd-cm `kustomize.buildOptions: --enable-helm`.
#   로컬 재현: `kustomize build --enable-helm platform/external-secrets`(helm 필요). 인플레이트는 helm 릴리스가 아니다.
#   ⚠ 이 차트는 **HTTPS helm repo**다 — `repo:`에 `oci://`를 붙이지 않는다(vault와 같고 cert-manager와 반대).
#   ⚠ `values.schema.json`에 `additionalProperties`가 **0곳**이다 — 키 오타는 조용히 무시되고 렌더는 성공한다.
#     유일한 방어는 렌더 결과 대조다(README §2: digest 3줄 · `role: platform` 3건 · CRD 어노테이션 25건 · kubeconform Invalid 0).
#   ⚠ 최상위 `namespace:` 변환기를 두지 않는다 — 두면 클러스터 범위 CR에도 metadata.namespace가 찍힌다(2026-09-17 스크래치 실측).
#   ⚠ `skipTests` 불필요(이 차트에는 templates/tests가 없다). `installCRDs`·`crds.create*`는 적지 않는다(기본값 사용;
#     `crds.createSecretStore`는 템플릿 참조 0건인 **죽은 키**라 699 KB secretstores CRD를 줄이지 못한다).
#
# 이 디렉터리가 만들지 "않는" 것:
#   1) Namespace·PSA 라벨·NetworkPolicy → `platform/policies/`(차트의 networkPolicy 3종은 기본 false).
#   2) ClusterSecretStore 5개 → `platform/secret-stores/`. 이유: Argo 내장 health Lua가 store Ready=False를 Degraded로 보고
#      argocd-cm의 Application health Lua가 그것을 root로 전파한다. store는 Vault가 살아 있어야 Ready인데 Vault는 이 컴포넌트보다
#      뒤 wave다 → 한 Application에 두면 Vault가 불가한 동안 이 Application이 Degraded가 되어 root sync가 여기서 멈춘다.
#   3) ExternalSecret → 원본 `secrets/<ns>/`, 배달 `platform/secrets/`.
#   4) 시크릿 값: 없다.
#
# 되돌리기(순서 고정 — README §6): revert 머지 → 렌더 0(`prune: false`라 객체가 남는다) →
#   ① Deployment 3 삭제 → ② ValidatingWebhookConfiguration 2 삭제 → ③ **CRD 25장은 남긴다**(지우면 모든 CR cascade 삭제).
#   ⚠ store·ES를 먼저 지워야 한다면 webhook이 Ready인 동안에 한다 — `failurePolicy: Fail`이 DELETE도 가로챈다.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - serviceaccounts.yaml
  - rbac-eso-ca-reader.yaml
  # - rbac-token-create.yaml        # G2r에서 추가(아래 rbac.serviceAccountTokenCreate와 한 쌍 — 설계 D7)

helmCharts:
  - name: external-secrets
    repo: https://charts.external-secrets.io   # HTTPS helm repo — `oci://` 금지
    version: 2.10.0                            # 대조용 실측(값 고정 아님): index.yaml tgz sha256
                                               #   b96e948fff3674638b5d3f9e43886f3796e04739c4b4127929aed2ddac7d1418 (2026-09-17)
                                               # ⚠ `charts/` 캐시 키에는 **버전이 들어간다**(`charts/external-secrets-2.10.0/`) →
                                               #   version bump는 캐시 미스라 즉시 새로 pull된다(2026-09-17 스크래치 실측: 2.9.0 → 2.10.0에서
                                               #   디렉터리가 새로 생기고 렌더 `helm.sh/chart` 라벨이 바뀐다).
                                               #   가려지는 것은 **같은 버전의 재푸시**뿐이고, 그때는 repo-server 재시작(또는 그 `charts/`
                                               #   제거) 전까지 옛 사본이 계속 쓰인다(repo-server 쪽은 소스 문면 확인 · 라이브 미확인
                                               #   — README §2 단계 5) → 위 tgz sha256이 그 경우의 유일한 대조 수단.
    releaseName: external-secrets              # Deployment external-secrets / -webhook / -cert-controller · Service·Secret external-secrets-webhook
    namespace: external-secrets
    valuesInline:
      crds:
        annotations:
          # 계약 §삭제 보호 + 하네스 argo-4(그룹이 external-secrets.io이거나 그것으로 끝나는 CRD 전부 = 25장, 정확 일치)
          argocd.argoproj.io/sync-options: Delete=false,Prune=false
        # `unsafeServeV1Beta1` 기본 false → v1beta1은 served:false라 계약의 'v1beta1 금지'를 CRD가 직접 강제한다.
        # `conversion.enabled` 기본 false → CRD에 caBundle 주입 대상이 없다(= Argo 드리프트 없음).

      # ── controller ───────────────────────────────────────────────────────────
      replicaCount: 1
      nodeSelector:
        role: platform
      image:
        # 이 차트에는 `image.digest` 키가 없다 → 태그 문자열에 병기(vault 선례). digest = 멀티아치 **인덱스** digest(노드 2대 arm64).
        # ⚠ image / webhook.image / certController.image는 **별개 트리**다 — 하나라도 빠뜨리면 그 Deployment만 태그 pin으로 남고
        #   자동 검사가 없다(validate 4b는 helm 블록 표기를 보지 않는다). README §2의 grep = 3이 유일한 그물.
        tag: "v2.10.0@sha256:814117b0fd6d121b03e8ba3b6db1cecbe7449a354fc0fc9c4faf73a37aa221b1"
      securityContext:
        # ns가 PSA restricted. 차트 기본값이 이미 통과하지만 계약 §워크로드 강화가 values 명시를 요구한다.
        # 이 차트는 부분 지정 시 기본값과 **깊은 병합**이라(실측) readOnlyRootFilesystem·runAsUser 1000은 유지된다(vault 차트와 반대).
        allowPrivilegeEscalation: false
        runAsNonRoot: true
        capabilities:
          drop: [ALL]
        seccompProfile:
          type: RuntimeDefault
      resources:                     # 차트 기본 `{}`. 값은 초기 추정 — plan A14 예산 대조용, T097 실측으로 교정(VD-18).
        requests: { cpu: 20m, memory: 96Mi }
        limits: { memory: 192Mi }    # CPU limit은 두지 않는다(저장소 관례)
      rbac:
        servicebindings:
          create: false              # 미사용 ClusterRole 1장 제거
        serviceAccountTokenCreate: true   # 차트 기본값 그대로 = G1은 차트 기본 RBAC를 유지한다
        # ⚠ 전역 `serviceaccounts/token create` = ESO가 **임의 ns의 임의 SA** 토큰을 발급할 수 있다 — 여기에는
        #   `argocd/argocd-application-controller`(`*/*/*`)도 포함되므로 **클러스터 admin 등가**다(README §5).
        #   Vault role은 SA 이름·ns에 더해 audience `vault`를 바인드하지만, TokenRequest 호출자가 audience를 지정하므로 막지 못한다.
        #   **G2r에서 축소**: 단독 PR에서 이 값을 false로 내리고 rbac-token-create.yaml(resourceNames 5개)을 함께 넣는다.
        #   ⚠ G2r이 닫는 것은 **TokenRequest 경로**뿐이다 — 전역 `secrets` create+get으로 임의 SA의 레거시 토큰을 얻는 경로는 남는다(README §5).
        #   여기서 함께 내리지 않는 이유 = 설계 D7(권한 축소와 컴포넌트를 한 머지에 묶지 않는다 — store Ready 실패 원인 분리).
      metrics:
        listen:
          port: 8080                 # 명시해야 validate 5.4b(HELM_PORT_KEYS)가 실제로 대조한다(미설정이면 조용히 skip)
        service:
          enabled: false             # 차트 기본. T098(Alloy)이 Service discovery를 쓰면 그때 켠다.

      # ── webhook ─────────────────────────────────────────────────────────────
      webhook:
        replicaCount: 1
        port: 10250                  # 계약 §포트 각주 · PORT_TABLE · 정책 allow-apiserver-webhook과 3중 일치(Service는 443 → targetPort 10250)
        failurePolicy: Fail          # 기본값 명시. ⚠ webhook이 죽으면 store·ES의 CREATE·UPDATE·**DELETE**가 전부 거부된다.
        nodeSelector:
          role: platform
        image:
          tag: "v2.10.0@sha256:814117b0fd6d121b03e8ba3b6db1cecbe7449a354fc0fc9c4faf73a37aa221b1"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop: [ALL]
          seccompProfile:
            type: RuntimeDefault
        resources:
          requests: { cpu: 10m, memory: 48Mi }
          limits: { memory: 128Mi }
        # readinessProbe는 차트 기본 활성(8081 /readyz). ns 정책에 8081이 없다 — kubelet 프로브가 통과하는지는 VD-9.

      # ── cert-controller ─────────────────────────────────────────────────────
      certController:
        replicaCount: 1
        nodeSelector:
          role: platform
        image:
          tag: "v2.10.0@sha256:814117b0fd6d121b03e8ba3b6db1cecbe7449a354fc0fc9c4faf73a37aa221b1"
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          capabilities:
            drop: [ALL]
          seccompProfile:
            type: RuntimeDefault
        resources:
          requests: { cpu: 10m, memory: 48Mi }
          limits: { memory: 128Mi }
        # 빈 Secret `external-secrets-webhook`과 webhook 설정 2장의 caBundle을 런타임에 채운다. 희망 상태에 그 필드가 없으므로
        # ignoreDifferences를 넣지 않는다(설계 D8 · VD-5). `enablePartialCache`(기본 true)는 `external-secrets.io/component` 라벨에
        # 의존한다 — 라벨을 깎는 kustomize 변환을 넣지 않는다.
        # 잔여 권한: 이 컴포넌트의 ClusterRole은 전역 secrets get/list/watch와 전역 `coordination.k8s.io/leases`
        #   get·create·update·patch(이름 제한 없음 — 전 ns의 Lease에 쓰기 가능. `leaderElect` 기본 false라 이 렌더에서는 미사용)를
        #   갖는다. 규칙 하나만 values로 뺄 수는 없다 — ClusterRole을 통째로 없애는 길이 `webhook.certManager` 전환(계약 변경,
        #   범위 밖) 또는 `certController.rbac.create: false` + 수기 RBAC(미검증)다(README §5).
```

### 4.2 `platform/external-secrets/serviceaccounts.yaml` (G1)

```yaml
# eso-* ServiceAccount 5개 — ClusterSecretStore의 인증 주체(계약 §ClusterSecretStore 표 · §이름·인증 규약). Vault role 이름 = SA 이름(T044).
# ESO 컨트롤러가 이 SA들의 TokenRequest를 만든다(vault: audience `vault`·600초 / kubernetes provider: audience 없음·3600초).
# 이 SA로 도는 파드는 없다 → automount false. 차트가 만드는 SA 3개(external-secrets·-webhook·-cert-controller)와는 별개다.
apiVersion: v1
kind: ServiceAccount
metadata: { name: eso-platform, namespace: external-secrets }
automountServiceAccountToken: false
---
apiVersion: v1
kind: ServiceAccount
metadata: { name: eso-dev, namespace: external-secrets }
automountServiceAccountToken: false
---
apiVersion: v1
kind: ServiceAccount
metadata: { name: eso-prod, namespace: external-secrets }
automountServiceAccountToken: false
---
apiVersion: v1
kind: ServiceAccount
metadata: { name: eso-data, namespace: external-secrets }
automountServiceAccountToken: false
---
# k8s-data-ca(kubernetes provider) 전용 — Vault role이 없다. 토큰은 kube-apiserver에 bearer로 제시된다.
apiVersion: v1
kind: ServiceAccount
metadata: { name: eso-ca-reader, namespace: external-secrets }
automountServiceAccountToken: false
```

### 4.3 `platform/external-secrets/rbac-eso-ca-reader.yaml` (G1)

> **G1 리뷰 반영(2026-09-17):** 머리 주석을 정정했다 — RBAC는 Secret 객체 단위라 이 Role은 이미 `pg-main-ca` 전체(ca.key 포함)를 get할 수 있다. ca.key 복제를 막는 것은 ExternalSecret 쪽 검사(validate 3.4 · T031)와 store `conditions.namespaces`다. 규칙 문면은 D12대로 그대로다.

```yaml
# store `k8s-data-ca`가 ns `data`에서 읽을 수 있는 범위(계약 §ClusterSecretStore 표 k8s-data-ca 행 · tasks.md T045 문면 그대로).
# ⚠ RBAC는 Secret **객체 단위**다 — 키 단위로는 제한하지 못한다. 그래서 이 Role만으로도 CNPG `pg-main-ca` 전체(**ca.key 포함**)가
#   SA `eso-ca-reader` 신원으로 이미 읽힌다. ca.key가 앱 ns로 복제되지 않게 막는 것은 이 파일이 아니라 ExternalSecret 쪽
#   (validate 3.4: `property: ca.crt`만 · `dataFrom` 금지 · 하네스 T031)과 store `k8s-data-ca`의 `conditions.namespaces`뿐이다.
#   ca.key가 새면 서버·streaming_replica 인증서 위조가 가능해 `sslmode=verify-full`이 무력화된다.
#   이 파일의 리뷰가 막는 것은 **resourceNames 밖으로 범위가 넓어지는 것**이다 — `resourceNames`를 빼거나 이름을 늘리면
#   ns `data`의 다른 Secret(DB·Kafka 자격, pg-main-server/replication의 tls.key 등)까지 열린다.
#   RBAC 범위에는 자동 검사가 없다(validate 3.4는 ES 쪽만 본다) → 이 파일의 리뷰가 그 경계의 방어선이다.
# ⚠ 문면 유지 + 실효 없음(설계 D12 · 계약 각주):
#   · `list`·`watch`: resourceNames가 붙은 규칙은 이름 없는 요청을 인가하지 못한다. ESO kubernetes provider는 Get만 쓴다.
#   · `selfsubjectrulesreviews create`: 클러스터 스코프 리소스라 Role로는 부여되지 않고, 기본 ClusterRole `system:basic-user`가
#     `system:authenticated` 전원에게 이미 준다(VD-7로 실측). store Ready 판정이 이 리뷰 1회이므로 동작에는 지장이 없다.
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: eso-ca-reader, namespace: data }
rules:
  - apiGroups: [""]
    resources: [secrets]
    verbs: [get, list, watch]
    resourceNames: [pg-main-ca, jt-kafka-cluster-ca-cert]
  - apiGroups: [authorization.k8s.io]
    resources: [selfsubjectrulesreviews]
    verbs: [create]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: eso-ca-reader, namespace: data }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: Role, name: eso-ca-reader }
subjects:
  - { kind: ServiceAccount, name: eso-ca-reader, namespace: external-secrets }
```

### 4.4 `platform/external-secrets/rbac-token-create.yaml` (G2r)

```yaml
# values `rbac.serviceAccountTokenCreate: false`의 짝(설계 D7). 전역 `serviceaccounts/token create`를 eso-* 5개로 좁힌다.
# SA를 추가하면 resourceNames도 함께 — 빠뜨리면 그 store가 Ready=False(`cannot create … serviceaccounts/token`)로 즉시 드러난다.
# 머지 후 5분 내 store 5장 reason=Valid를 확인하고 아니면 이 PR을 revert한다(VD-16).
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: eso-token-create, namespace: external-secrets }
rules:
  - apiGroups: [""]
    resources: [serviceaccounts/token]
    verbs: [create]
    resourceNames: [eso-platform, eso-dev, eso-prod, eso-data, eso-ca-reader]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: eso-token-create, namespace: external-secrets }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: Role, name: eso-token-create }
subjects:
  - { kind: ServiceAccount, name: external-secrets, namespace: external-secrets }   # 차트의 컨트롤러 SA
```

### 4.5 `platform/secret-stores/` (G2)

```yaml
# platform/secret-stores/kustomization.yaml — ClusterSecretStore 5개 (T045 G2)
# 왜 별도 컴포넌트인가: platform/external-secrets/kustomization.yaml 머리 주석 2) + 설계 D2.
#   부가 효과: ESO Application이 Healthy(= webhook Ready)가 된 뒤에 적용되므로 첫 sync의 admission 거부도 사라진다.
# ⚠ 최상위 `namespace:` 변환기 금지(클러스터 범위 CR에 namespace가 찍혀 영구 OutOfSync).
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - clustersecretstore-vault-platform.yaml
  - clustersecretstore-vault-dev.yaml
  - clustersecretstore-vault-prod.yaml
  - clustersecretstore-vault-data.yaml
  - clustersecretstore-k8s-data-ca.yaml
```

```yaml
# clustersecretstore-vault-platform.yaml — 플랫폼 ns 12개(network-policy.md 표 14개 − jt-dev − jt-prod, kube-system 포함)
# ⚠ `serviceAccountRef.namespace`를 **반드시** 적는다. 생략해도 스키마·webhook은 통과하지만 'referent auth'가 되어 ESO가 로그인을
#   한 번도 하지 않은 채 Ready=True / reason=`Valid` / message `store validated`가 된다(가짜 PASS — 상태로는 구분 불가; 정정 2026-09-18).
#   판정 기준은 `Ready=True` + `reason=Valid`(k8s-data-ca의 ValidationUnknown을 잡는다) + spec의 `serviceAccountRef.namespace == external-secrets` 4장 전수.
# ⚠ `audiences: [vault]` = Vault role `audience="vault"`(infra/vault/roles.tf). 불일치 시 'jwt valid for audience(s) … but wanted …'.
# `path: kv` + `version: v2` → `kv/data/<remoteRef.key>`. ES의 key에 `kv/` 접두를 붙이지 않는다(validate 3.1).
# `conditions.namespaces`는 Ready 판정과 무관하다 — ES가 store를 쓸 때만 평가된다('denied by spec.condition').
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata: { name: vault-platform }
spec:
  conditions:
    - namespaces: [kube-system, argocd, vault, external-secrets, cert-manager, cnpg-system, data, identity, monitoring, system-upgrade, cloudflared, reloader]
  provider:
    vault:
      server: http://vault.vault.svc:8200     # 평문 8200(T044 `global.tlsDisable: true`)
      path: kv
      version: v2
      auth:
        kubernetes:
          mountPath: kubernetes
          role: eso-platform
          serviceAccountRef: { name: eso-platform, namespace: external-secrets, audiences: [vault] }
```

`vault-dev`, `vault-prod`, `vault-data`는 같은 형식이고 아래 값만 다릅니다. store 1장 단위로 revert할 수 있도록 파일을 분리합니다.

| 파일 | `metadata.name` | `role` · `serviceAccountRef.name` | `conditions.namespaces` |
|---|---|---|---|
| `clustersecretstore-vault-dev.yaml` | `vault-dev` | `eso-dev` | `[jt-dev]` |
| `clustersecretstore-vault-prod.yaml` | `vault-prod` | `eso-prod` | `[jt-prod]` |
| `clustersecretstore-vault-data.yaml` | `vault-data` | `eso-data` | `[data, identity]` |

`vault-data` 파일의 머리 주석에는 다음을 적습니다. "role `eso-data`는 열거 접두 20개만 읽는다. `data`와 `identity`에는 vault-platform도 함께 걸린다."

```yaml
# clustersecretstore-k8s-data-ca.yaml — 유일한 kubernetes provider. 미러 ExternalSecret 자체는 T056.
# ⚠ CRD 기본값 함정: `remoteNamespace` 기본 = `default` · `server.url` 기본 = `kubernetes.default`(스킴·포트 없음) → 둘 다 명시.
# ⚠ CA 기본값 없음 — 비우면 시스템 루트로 떨어져 x509 실패(webhook은 경고만). CSS에서는 `caProvider.namespace` 필수.
# ⚠ `auth`는 cert|serviceAccount|token 중 정확히 하나. 이 토큰은 apiserver에 bearer로 제시되므로 **audiences를 넣지 않는다**(401).
# Ready 판정 = SelfSubjectRulesReview(ns data) 1회, ESO는 resourceNames를 보지 않는다 → 대상 Secret이 없어도(T056 전) Valid다.
#   즉 이 store의 Ready는 'CA 미러 동작'의 증거가 아니다. 하네스 ca-1은 T056까지 SKIP(`until T056` — 세 ns에 pg-main-ca가 없으면 SKIP을 돌려준다; 2026-09-18 G2 빌더가 실제 코드로 확인)이 정상.
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata: { name: k8s-data-ca }
spec:
  conditions:
    - namespaces: [identity, jt-dev, jt-prod]
  provider:
    kubernetes:
      remoteNamespace: data
      server:
        url: https://kubernetes.default.svc:443
        caProvider: { type: ConfigMap, name: kube-root-ca.crt, key: ca.crt, namespace: external-secrets }
      auth:
        serviceAccount: { name: eso-ca-reader, namespace: external-secrets }
```

### 4.6 Application 2장 (G2 · G3)

기존 `platform-external-secrets.yaml`의 `project`, `repoURL`, `syncPolicy`를 그대로 복사합니다(실물 대조 완료). 달라지는 것은 아래 세 값뿐입니다.

```yaml
# clusters/oci-k3s/apps/platform-secret-stores.yaml — sync-wave·경로의 정본은 계약 §sync-wave 단일 표(코드 사본은 validate.sh WAVE_TABLE 하나).
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-secret-stores
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "15"      # 표에서 기계적으로 읽은 값(M0 제안값) — README·PR 본문에 다시 적지 않는다
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: platform
  source:
    repoURL: https://github.com/joshua92y/platform-gitops.git
    targetRevision: main
    path: platform/secret-stores
  destination:
    server: https://kubernetes.default.svc
    namespace: external-secrets             # 형식상 값 — ClusterSecretStore는 클러스터 범위다
  syncPolicy:
    automated: { prune: false, selfHeal: true }
    syncOptions: [ServerSideApply=true, CreateNamespace=true, Prune=confirm, Delete=confirm, SkipDryRunOnMissingResource=true]
    # ⚠ SkipDryRunOnMissingResource는 dry-run만 건너뛴다 — admission webhook 거부는 우회하지 못한다.
```

`platform-secrets.yaml`은 같은 형식입니다. 다른 값은 다음과 같습니다.

- `name: platform-secrets`
- `path: platform/secrets`
- `destination.namespace: kube-system` — **정정(2026-09-21 G3 빌드)**: 저장소 관례는 "`WAVE_TABLE` 3열이 `-`이면 destination은 `kube-system`"이다(`platform-policies.yaml` 머리 주석 · `clusters/oci-k3s/apps/README.md` 「Application 추가 절차」). 초안의 `external-secrets`가 아니다. validate는 이 필드를 검사하지 않고, ES는 전부 자기 `metadata.namespace`를 명시하므로 동작 차이는 없다.
- `sync-wave: "18"` (표의 값)
- `destination.namespace: external-secrets` (형식상의 값입니다. ES는 각자 `metadata.namespace`를 명시합니다. AppProject destinations에 `cert-manager`와 `cloudflared`가 들어 있습니다.)

### 4.7 `platform/secrets/kustomization.yaml` (G3, G4에서 1줄 추가)

```yaml
# platform/secrets/ — `secrets/<ns>/`의 **배달자**(T045 G3). ExternalSecret 원본은 여기가 아니라 저장소 루트 `secrets/<ns>/`에 있다.
# 왜 이런 모양인가(설계 D3 = B 확정):
#   · validate 3.2(scope↔위치: store `vault-platform` + key 접두 `platform/`)의 트리거가 파일 경로 `^secrets/`다 —
#     원본을 이 디렉터리로 옮기면 검사가 **조용히 꺼진다**. 옮기지 말 것.
#   · validate 7.1은 Application `platform-<comp>` ↔ `platform/<comp>`만 허용한다 → `secrets/`를 직접 가리키는 Application은 만들 수 없다.
#   · 소비자 컴포넌트(cloudflared·cert-manager-issuers)가 base로 끌어가지 않는 이유: ESO webhook은 `failurePolicy: Fail`이라
#     webhook 장애 시 그 Application의 sync 전체가 실패한다 — 터널 컴포넌트가 다른 오퍼레이터의 admission에 묶이면 안 된다.
# ⚠ **단일 소유(D3 조건 2)**: `../../secrets/*`를 base로 포함하는 kustomization은 이 파일 **하나뿐**이다. 소비자 kustomization에
#   같은 base를 넣으면 한 ExternalSecret을 두 Application이 각자 적용해 소유권이 갈린다. validate 7.3이 정적으로 막고,
#   라이브에서는 각 ES의 Argo tracking 어노테이션이 `platform-secrets`인지로 확인한다(§5 단계 9 · VD-21).
# ⚠ **범위(D3 조건 1)**: 지금은 DNS 토큰·터널 토큰 ES 2장만 담는다. CA 미러 ES는 원본(CNPG·Strimzi CA)이 생긴 뒤인
#   계약 §sync-wave 표 40번 행(`cnpg-databases`·`kafka-topics`) 소유다(T056). 새 ES를 추가할 때는 **원본과 소비자의 wave를 먼저 확인**한다.
# ⚠ 이 컴포넌트의 효과는 "소비자 배포와 ExternalSecret 적용 작업의 분리"다. Vault·ESO 장애 시 이 Application과
#   `platform-secret-stores`가 Degraded가 되고 root가 그 wave에서 기다리는 것은 **그대로다**(D3 조건 3).
# ⚠ 최상위 `namespace:` 변환기를 두지 않는다(ns가 둘이다). 각 ExternalSecret이 metadata.namespace를 명시한다.
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../secrets/cert-manager
  # - ../../secrets/cloudflared     # G4(잠금 위험 단계)에서 추가
```

### 4.8 `secrets/cert-manager/` (G3)

```yaml
# secrets/cert-manager/kustomization.yaml — `platform/secrets/`가 base로 끌어간다(secrets/README.md)
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources: [externalsecret-cloudflare-dns-token.yaml]
```

```yaml
# T042에서 운영자가 만든 수동 Secret `cloudflare-dns-token`(key `api-token`)을 인수한다(T045 G3).
# 인수는 **삭제 없이** 된다(ESO v2.10.0 소스: applyOwnership은 **다른 ExternalSecret**이 controller owner일 때만 거부).
#   첫 조정에서 즉시 일어난다(managed 라벨·data-hash 부재). ⚠ 인수 시 secret.Data가 비워졌다가 다시 채워진다 — kv 값 = 라이브 값이 전제(T045 OP1).
# 키 매핑: Vault 필드 = `token`(정본 data-model §8), K8s Secret 키 = ClusterIssuer가 참조하는 `api-token`.
# `Orphan`(설계 D4 = B′ 확정 · 계약 예시 `Owner`의 명시적 예외): ownerReference를 만들지 않는다.
#   `Owner`였다면 `kubectl delete externalsecret` 한 번·Application cascade 한 번으로 Secret이 GC된다(`Retain`은 GC를 막지 못한다).
#   두 ES에 **같은 인수 해제 절차**(revert 머지 → Argo 반영 확인 → ES 삭제 → Secret 잔존 확인)를 쓰기 위해 DNS도 Orphan으로 통일했다.
#   대가: ownerRef가 없으므로 Argo 고아(orphaned) 리소스 목록에 계속 뜬다 — 드리프트가 아니다.
# ⚠ Orphan이어도 **값은 kv에서 덮어쓴다**(`Retain`은 잘못된 값의 덮어쓰기를 막지 않는다 — D4-③). 값 문제의 복구 1순위는 kv 정정이다.
#   Secret이 삭제되면 **ESO·Vault가 정상일 때 다음 성공한 갱신에서** 재생성된다(즉시 재조정 여부는 미확인 — DR1 드릴 VD-20).
# `refreshPolicy: Periodic`을 함께 명시한다(2.10.0 CRD enum = CreatedOnce·Periodic·OnChange). 정책 필드를 기본값에 맡기지 않는다.
# `template.metadata`: template이 없으면 ESO가 이 ES의 라벨·어노테이션(Argo tracking-id 포함)을 전부 Secret에 복사한다.
#   `template.data`가 비면 키 매핑 동작은 그대로다. `template.type`은 적지 않는다(Secret type 불변). `target.immutable` 금지.
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: cloudflare-dns-token, namespace: cert-manager }
spec:
  refreshPolicy: Periodic      # D4-① — 기본값에 의존하지 않는다
  refreshInterval: 5m          # 계약 §공통 규칙. ⚠ CRD 기본값은 1h — reboot-4(마감 300초)가 확정 FAIL한다.
  secretStoreRef: { kind: ClusterSecretStore, name: vault-platform }
  target:
    name: cloudflare-dns-token
    creationPolicy: Orphan
    deletionPolicy: Retain
    template:
      metadata: {}
  data:
    - secretKey: api-token
      remoteRef: { key: platform/cloudflare/dns-token, property: token }
```

**G3 게이트(D4-②)는 G4와 같은 세 검사입니다** — 인수 전후 **UID 불변 · 값(해시) 불변 · `metadata.ownerReferences` 부재**. 검사 명령은 §5 단계 10의 블록과 같은 형식이고, `ownerReferences`가 비어 있지 않으면 `creationPolicy`가 Orphan이 아니라는 뜻이므로 **ES를 지우지 말고** 매니페스트를 확인합니다.

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

### 4.10 `secrets/README.md` (G3 — 전문 교체)

```markdown
# secrets/ — 플랫폼 네임스페이스별 ExternalSecret (계약 gitops-repo.md §디렉터리·§ExternalSecret 규약)

`secrets/<ns>/` — `platform/` 경로만, store `vault-platform`. 시크릿 값은 절대 커밋하지 않는다(`ExternalSecret`만).

**누가 이 디렉터리를 클러스터에 적용하는가**: `platform/secrets/kustomization.yaml`이 `../../secrets/<ns>`를 base로 끌어가고
Application `platform-secrets`가 그것을 동기화한다. 새 ns를 추가하면 그 kustomization에 한 줄을 넣는다.
**그 kustomization이 `../../secrets/*`를 base로 가지는 유일한 파일이다**(단일 소유 — 소비자 컴포넌트에 같은 base를 넣지 않는다.
validate 7.3이 정적으로 막는다). 파일을 `platform/` 아래로 옮기지 않는다 — validate 3.2의 위치 판정이 `^secrets/`라
옮기는 순간 scope↔위치 검사가 **조용히 꺼진다**.

| ns | 파일 | 소비자 | creationPolicy / deletionPolicy | refresh |
|---|---|---|---|---|
| `cert-manager` | `externalsecret-cloudflare-dns-token.yaml` | ClusterIssuer letsencrypt-{staging,prod} (DNS-01) | `Orphan` / `Retain` | `Periodic` · `5m` |
| `cloudflared` | `externalsecret-cloudflared-tunnel.yaml` | Deployment cloudflared (`TUNNEL_TOKEN`) | `Orphan` / `Retain`(잠금 경로) | `Periodic` · `5m` |

⚠ 둘 다 `Orphan`이다 — ownerReference를 만들지 않으므로 ExternalSecret을 지워도 Secret은 남는다. 대신 Argo의 고아 리소스
목록에 계속 뜬다(드리프트가 아니다). `Owner`로 바꾸면 ExternalSecret 삭제·Application cascade로 Secret이 GC된다
(`deletionPolicy: Retain`은 못 막는다) — 하네스 eso-4가 이 회귀를 잡는다.
⚠ 어느 정책이든 값은 Vault kv에서 덮어쓴다(`Retain`은 잘못된 값의 덮어쓰기를 막지 않는다) — 값 문제의 복구는 kv 정정이 먼저다.
⚠ Secret이 지워졌을 때의 재생성은 **ESO·Vault가 정상일 때 다음 성공한 갱신에서** 일어난다.
⚠ **인수를 해제하려면**(ES는 지우고 Secret은 남기려면) 순서가 있다: revert PR 머지 → Argo에 반영됐는지 확인(Application 리비전 =
revert 커밋, 해당 ES가 `requiresPruning`) → `kubectl delete externalsecret <name>` → Secret 잔존·UID·값 확인 → 필요 시 복구 →
소비자 파드 1개씩 교체. `prune: false`라 파일만 revert하면 ES 객체가 남아 조정이 계속된다.
```

### 4.11 그 밖의 변경(한 줄짜리)

- **G0 `clusters/oci-k3s/projects/platform.yaml`**: `- https://charts.external-secrets.io  # external-secrets` 줄을 삭제합니다. jetstack(T042), hashicorp(T044) 문단과 같은 형식으로 삭제 근거 주석을 남깁니다.
- **G0 `platform/cloudflared/README.md` ⑨ 2단계**: "수동 Secret을 지운다 …" 문장을 다음으로 교체합니다. "**지우지 않는다.** ESO v2.10.0은 ownerReference 없는 Secret을 제자리에서 인수한다. 확정 절차는 T045 G4."
- **G1p `platform/policies/policies-common.yaml`**: external-secrets `allow-apiserver-webhook`의 `from`에 `- ipBlock: {cidr: <D6-① 실측으로 확정한 노드 A flannel 출발 주소>/32}`를 추가합니다(T042 기록대로면 `10.42.0.0/32`이고, cert-manager·cnpg-system 행에 이미 같은 값이 있습니다 — 그래도 **머지 전 실측값이 정본**입니다). 「잔여 1건 — `external-secrets`」 미결 주석은 결정 결과(D6 = A)와 이번 실측 기록(장치 주소 · `ip route get`의 `src` · conntrack 여부 · 노드 간 경로는 미실측이라는 한계)으로 교체합니다.
- **G1p `tests/validate.sh` 5.x 신설**(예: `5.6 POL-webhook-src`): `allow-apiserver-webhook`을 가진 webhook 3개 ns(`cert-manager`·`external-secrets`·`cnpg-system`)의 ingress `from`이 **정확히 두 출발 주소**(노드 A private IP `/32` · 노드 A flannel 출발 주소 `/32`)이고 ns별 포트가 각주와 같은지 정적으로 검사합니다. `vault` 8200 행은 private IP만 요구합니다. 긍정·부정 픽스처(`tests/fixtures/pol-webhook-src/`)를 함께 넣습니다.
- **G2·G3 `tests/validate.sh` WAVE_TABLE**: `secret-stores 15 external-secrets`와 `secrets 18 -`를 추가합니다.
- **G3 `tests/validate.sh` 7.3 신설**(`WAVE-secrets-base`, D3 조건 2): `../../secrets/*`를 `resources`에 포함하는 kustomization이 `platform/secrets/kustomization.yaml` **하나뿐**임을 검사합니다. 픽스처는 `tests/fixtures/secrets-base-owner/`(부정 = 소비자 컴포넌트가 같은 base를 포함). 검사 3 그룹에 넣지 않는 이유는 계약 §ExternalSecret 규약의 "7항목" 문면과 번호가 충돌하기 때문입니다(R-12).
- **신규 README 3종**(`platform/external-secrets` = G1 · `platform/secret-stores` = G2 · `platform/secrets` = G3)의 목차는 다음과 같습니다. 콜드 부트스트랩 문장은 신규가 아닌 `platform/cloudflared/README.md`(G5)에도 같은 문면으로 둡니다.
  - 역할과 하지 않는 일 (`platform/secrets`는 여기에 **범위 = ES 2장 · 새 ES 추가 전 원본·소비자 wave 확인**을 적습니다)
  - values 근거 (store·secrets README에서는 생략)
  - **렌더 grep 체크리스트**
  - 되돌리기 순서 (`platform/secrets`는 **인수 해제 절차**를 그대로 적습니다)
  - store 판정 기준(`reason=Valid`)과 실패 메시지별 원인
  - provider별 함정
  - 단일 소유와 Argo 고아 경고(`platform/secrets`)
  - 콜드 부트스트랩 수동 선행(`platform/secrets`(G3) · `platform/cloudflared`(G5) — 같은 문면)
  - 노드 간 webhook 경로 미실측 한계(`platform/external-secrets`, D6-④)
  - 잔여 항목(cert-controller 전역 secrets read, metrics Service off, 토큰 캐시 off)

---

## 5. 운영자 적용 순서

표기: 🔒은 잠금 위험 단계, ✋은 실행 전에 사용자 재확인이 필요한 단계입니다. 에이전트는 agent-view(읽기)와 정적 검사만 수행합니다. kubectl-write, SSH, Vault, OCI 작업은 운영자가 합니다.

### 단계 1 — M0: 모노레포 contracts 단독 커밋

- **누가:** controller. **라이브 영향:** 없음.
- **편집(`contracts/gitops-repo.md`):**
  1. §sync-wave 표에 `15 | secret-stores`와 `18 | secrets` 행을 추가합니다.
  2. §디렉터리의 `# 19개`를 `# 21개`로 바꾸고 `secret-stores secrets`를 추가합니다.
  3. `secrets/<ns>/` 줄에 "적용 주체 = `platform/secrets`가 base로 포함, Application `platform-secrets`" 각주를 답니다.
  4. §ClusterSecretStore 표의 k8s-data-ca 행에 무효 규칙 각주를 답니다.
  5. §ExternalSecret 규약에 다섯 가지를 추가합니다.
     - creationPolicy 기본값은 Owner이고, **수동으로 먼저 만든 Secret을 인수하는 경우와 소비자 중단이 운영자 잠금으로 이어지는 Secret은 Orphan을 쓴다**(T045의 두 ES가 모두 여기에 해당한다).
     - Retain은 GC를 막지 못하고, 잘못된 값의 덮어쓰기도 막지 못한다.
     - `target.template.metadata`를 선언한다.
     - `refreshPolicy`를 기본값에 맡기지 않고 명시한다(`refreshInterval`과 한 쌍).
     - 인수 해제는 revert 머지 → Argo 반영 확인 → `kubectl delete externalsecret` 순서다(파일 revert만으로는 해제되지 않는다).
  6. §워크로드 강화의 helm 목록에 External Secrets를 추가합니다.
  7. `secrets/<ns>/`의 **단일 소유**를 규약으로 적습니다(소비자 kustomization은 `secrets/<ns>`를 base로 포함하지 않는다 — validate 7.3).
- **편집(`contracts/hostnames-and-access.md:93`):** break-glass 문면을 다음으로 고칩니다. "OCI CLI로 `nsg-cluster`에 운영자 `<ip>/32` 22/tcp 규칙을 추가·제거한다(`infra/oci/instances.tf` 5·8단계). tofu 코드에는 두지 않는다 — nsg-3/nsg-4가 fail-closed다. 읽기 전용 `svc-verify` 프로파일로는 불가."
- **`network-policy.md`는 고치지 않습니다.** D6이 A로 확정되었으므로 계약(webhook 행 3개 ns 모두에 flannel `/32`)이 그대로 정본이고, 매니페스트를 계약에 맞춥니다(G1p).
- **게이트:** `pwsh -NoProfile -File tests/run-all.ps1`이 PASS하고, `git show --stat`에 contracts 2개 파일만 나옵니다.
- **되돌리기:** `git revert`.

### 단계 2 — G0: sourceRepos 1줄 삭제 + README ⑨ 즉시 정정

- **누가:** controller가 PR을 만들고 사용자가 머지합니다.
- **명령:** `bash tests/validate.sh`를 실행한 뒤 `gh pr create`.
- **게이트(agent-view):** 아래 명령에서 20개 Application이 모두 Synced/Healthy를 유지해야 합니다.
  ```
  kubectl -n argocd get app -o custom-columns=N:.metadata.name,S:.status.sync.status,H:.status.health.status
  ```
- **되돌리기:** revert. **라이브 영향:** AppProject 1장이 SSA로 갱신됩니다. 삭제한 repo를 source로 쓰는 Application은 0건입니다.

### 단계 3 — G1 빌드(builder, 커밋하지 않음)

```bash
kustomize build --enable-helm platform/external-secrets > "$SCRATCH/t045-g1.yaml"
grep -c 'ghcr.io/external-secrets/external-secrets:v2.10.0@sha256:814117b0' "$SCRATCH/t045-g1.yaml"   # = 3
grep -c 'role: platform' "$SCRATCH/t045-g1.yaml"                                                        # = 3
grep -c 'argocd.argoproj.io/sync-options: Delete=false,Prune=false' "$SCRATCH/t045-g1.yaml"             # = 25
grep -c 'kind: CustomResourceDefinition' "$SCRATCH/t045-g1.yaml"                                        # = 25
kubeconform -strict -ignore-missing-schemas -summary -kubernetes-version 1.32.0 "$SCRATCH/t045-g1.yaml" # Invalid 0 · Skipped 25
bash tests/validate.sh
```

- **게이트:**
  - 위 기대값이 모두 일치해야 합니다.
  - validate 전 검사가 PASS해야 합니다.
  - 문서 장수(기대: 차트 43 + SA 5 + Role/RoleBinding 2 = 50)를 실측해 README §2에 고정합니다.
  - 하나라도 어긋나면 머지하지 않습니다.

### 단계 4 — G1 머지 ✋

- **누가:** 사용자가 머지하고 에이전트가 agent-view로 확인합니다.
- **대기:** Argo sync와 파드 3개의 Ready(webhook `initialDelay`는 20s).
- **게이트:**
  ```powershell
  kubectl -n argocd get app platform-external-secrets -o jsonpath='{.status.sync.status} {.status.health.status}'   # Synced Healthy
  kubectl -n external-secrets get deploy -o custom-columns=N:.metadata.name,R:.status.readyReplicas                # 3행 모두 1
  kubectl -n external-secrets get pod -o wide                                                                      # 3개 모두 노드 A
  (kubectl get validatingwebhookconfiguration secretstore-validate -o jsonpath='{.webhooks[0].clientConfig.caBundle}').Length  # > 0
  ```
  - 추가로 VD-1(dry-run 프로브, 운영자 — 판정 기준은 **종료 코드 0 + `created (server dry run)`**), VD-7(`can-i`), VD-9를 기록합니다.
  - 15분 간격으로 2회 VD-5를 확인합니다.
- **되돌리기:** revert 후 Deployment 3, webhook 설정 2의 순서로 정리합니다. **CRD는 남깁니다.**
- **라이브 영향:** 중간.
  - 약 2 MB가 SSA로 적용되고 파드 3개가 뜹니다.
  - 이 시점부터 ESO CR에 대한 admission이 `Fail`로 동작합니다.
  - **G2r까지 컨트롤러가 전역 `serviceaccounts/token create` 권한을 가집니다.** 이 노출 창을 report에 기록합니다.

### 단계 5 — G1p: 노드 A flannel 출발 주소 `/32` 정책 PR 🔒 ✋ (D6 = A 확정)

⚠ **`platform-policies` Application은 `automated: {prune: false, selfHeal: true}`입니다 — 머지가 곧 적용입니다.** "운영자가 나중에 sync를 트리거한다"는 단계가 없습니다. 그래서 아래 사전 항목은 전부 **머지 전에** 끝나야 합니다.

- **사전 ①(값 확정 — 운영자, 노드 A):** 추가할 `/32`를 **실측으로** 정합니다. podCIDR 대조만으로 끝내지 않습니다.
  ```
  ip -4 -o addr show flannel-wg                      # 장치 주소
  ip route get <노드 B의 파드 IP>                     # 출력의 `src` = **노드 간** 경로에서 라우팅이 고른 출발 주소(대상 = cert-manager webhook 파드, T042 VD-W와 동일)
  ip route get <ESO webhook 파드 IP>                  # 참고 기록: 같은 노드 경로의 src(flannel 터널을 타지 않는다 — 값 확정에 쓰지 않는다)
  sudo iptables -S | grep -- '--src-type LOCAL' | grep <ESO webhook 파드 IP>   # 참고 기록: 동일 노드 예외 행 실물
  sudo conntrack -L 2>/dev/null | grep <ESO webhook 파드 IP>   # (있으면) 실제 dial의 출발 주소
  kubectl get node <A> -o jsonpath='{.spec.podCIDR}'  # VD-19 보조 대조(기대 10.42.0.0/24)
  ```
  - `flannel-wg` 장치 주소와 **노드 B 파드로 가는** `ip route get`의 `src` **두 값**이 일치하면 그 주소로 확정합니다. conntrack 사용 여부를 기록합니다. 엇갈리면 **중단하고 사용자에게 보고**합니다.
  - ESO webhook 파드(같은 노드) 쪽 `src`와 conntrack 값은 flannel 주소와 **다를 수 있고 그것은 중단 사유가 아닙니다** — 같은 노드 경로는 터널을 타지 않습니다. 이 값들은 "G1p 이전에도 동일 노드 admission이 PASS한 이유"의 기록입니다(2026-09-17 G1p 리뷰에서 정정: 원래 문면은 ESO webhook 파드 IP로 값을 확정하게 돼 있어 가짜 중단이 날 수 있었다).
  - T042 기록(`flannel-wg` 장치 주소 = 노드 A podCIDR의 네트워크 주소 `10.42.0.0`)은 기대값일 뿐이고, 정본은 이번 실측입니다.
- **사전 ②(비상 접속):** 노드 A 대화형 SSH 세션을 열어 유지합니다(1차 break-glass = 그 세션의 `sudo k3s kubectl`). OCI 자격도 사용 가능해야 합니다(§5 단계 10의 2번 블록과 같은 확인).
- **사전 ③(대기 diff 전체 확인):** 이 PR 하나만 들어가는지 확인합니다. 정책 컴포넌트에는 **다른 미적용 변경이 함께 밀려 들어갈 수 있습니다.**
  ```
  kustomize build platform/policies | kubectl diff -f -
  ```
  - 결과가 **"external-secrets `allow-apiserver-webhook`의 `from`에 ipBlock 1줄 추가"뿐**이어야 합니다.
  - 다른 diff가 보이면 머지하지 않고 원인을 먼저 처리합니다.
- **사전 ④(하네스 M1 — 머지 전 커밋):** 모노레포 `tests/platform/cluster.tests.ps1`의 `np-set-5` 강화판(webhook 3개 ns에 대해 **정확한 두 출발 주소와 포트**, D6-③)을 **G1p 머지 전에** 커밋합니다(§1.3의 M1). 이 시점에는 `external-secrets` 행만 FAIL하고 나머지 두 ns는 PASS해야 합니다 — 그것이 강화판이 실제로 무엇을 보는지의 증거이고, 머지 후 PASS로 바뀌는 것이 기대 동작입니다. 사전 ①의 실측값이 강화판의 주소 상수와 같은지도 여기서 대조합니다.
- **게이트(머지 후):**
  - **admission PASS(VD-1).** 유효한 ESO CR(§4.5의 store 1장)로 `kubectl apply --dry-run=server -f …`를 실행해 **종료 코드 0 + `created (server dry run)`** 출력을 확인합니다. "오류 문자열이 없다"는 판정 기준이 아닙니다.
  - `np-set-5`(사전 ④/M1에서 커밋한 강화판)가 PASS해야 합니다 — webhook 3개 ns에 **정확한 두 출발 주소와 포트**. 머지 전 FAIL → 머지 후 PASS로 바뀌는 것이 판정입니다.
  - `bash tests/validate.sh`의 5.x(신설 webhook 출발 주소 검사)가 PASS해야 합니다.
  - 20개 Application이 Healthy여야 합니다.
  - 열어 둔 SSH 세션과 새 터널 세션(`ssh ssh-a hostname`)이 모두 살아 있어야 합니다.
- **되돌리기:** revert(역시 자동 적용). add-only ingress 허용 추가는 기존 경로를 막을 수 없으므로 이 PR로 SSH·터널이 잠기지는 않습니다. admission이 FAIL이면 **정책을 지우지 않습니다** — NetworkPolicy는 허용 목록이라 default-deny가 있는 ns에서 allow 정책을 삭제하면 webhook ingress가 전면 차단되고(store·ES의 CREATE·UPDATE·DELETE가 모두 거부됩니다), `platform-policies`는 `selfHeal`이라 삭제가 곧 되돌아옵니다(D6-②). 열어 둔 세션에서 `sudo k3s kubectl -n external-secrets get networkpolicy allow-apiserver-webhook -o yaml`로 적용 상태를 확인한 뒤 revert PR(자동 적용) 또는 실측값 재확인으로 갑니다. **G2는 열지 않습니다.**
- **한계(D6-④):** ESO의 Deployment 3개와 API 서버가 모두 노드 A이므로, 이 단계가 증명하는 것은 **동일 노드 경로뿐**입니다. 노드 간 webhook 경로는 미실측이며 런북과 `platform/external-secrets/README.md`에 그대로 적습니다.
- **다음 단계의 선행조건:** 이 단계의 admission PASS가 G2의 필수 선행조건입니다(`G1 → G1p → admission PASS → G2`).

### 단계 6 — G2: store 5 + Application ✋

- **선행조건(D6-⑤):** 단계 5의 G1p가 반영되어 있고 admission dry-run이 **종료 코드 0 + `created (server dry run)`**으로 PASS해야 합니다. 이 확인 없이 store를 머지하면 webhook 거부로 Application이 실패합니다.
- **빌드 게이트:**
  ```bash
  kustomize build platform/secret-stores | yq -N '[select(.kind=="ClusterSecretStore")] | length'      # 문서 5장
  kustomize build platform/secret-stores | yq -N 'select(.kind=="ClusterSecretStore") | .metadata.namespace'   # 전부 null
  kustomize build platform/secret-stores | yq -N 'select(.spec.provider.vault != null) | .metadata.name + " " + .spec.provider.vault.auth.kubernetes.serviceAccountRef.namespace + " " + (.spec.provider.vault.auth.kubernetes.serviceAccountRef.audiences | join(","))'   # 4행 "… external-secrets vault"
  bash tests/validate.sh      # 7.1 platform-secret-stores ↔ platform/secret-stores ↔ 표
  ```
- **머지 후 게이트(합격 문면):**
  ```powershell
  kubectl get clustersecretstore -o custom-columns=N:.metadata.name,R:'.status.conditions[?(@.type=="Ready")].status',RE:'.status.conditions[?(@.type=="Ready")].reason',M:'.status.conditions[?(@.type=="Ready")].message'
  ```
  - **5행 모두 `True Valid`**여야 합니다.
  - `ValidationUnknown`은 불합격입니다(k8s-data-ca의 SSRR/SSAR 호출 실패 신호). 그리고 vault store 4장의 spec `serviceAccountRef.namespace`가 `external-secrets`인지 라이브에서 확인합니다(namespace 생략 store는 `Valid`로 나와 reason으로는 못 잡는다 — 정정 2026-09-18).
  - `platform-secret-stores`가 Synced/Healthy여야 합니다.
  - 아래 명령의 결과가 0행이어야 합니다.
    ```
    kubectl -n external-secrets logs deploy/external-secrets --since=10m | Select-String 'connection refused|i/o timeout|context deadline|Unauthorized|permission denied'
    ```
- **되돌리기:**
  - revert 후 `kubectl delete clustersecretstore <name>`을 실행합니다. webhook이 Ready여야 통과합니다.
  - ES가 아직 없으므로 무해합니다.
- **라이브 영향:** 중간. Vault 로그인이 시작되고 감사 로그가 늘어납니다.

### 단계 7 — G2r: RBAC 축소 ✋

- **빌드:**
  - values `rbac.serviceAccountTokenCreate: false`
  - resources에 `rbac-token-create.yaml` 추가
  - 렌더에서 `serviceaccounts/token`은 **1건**(우리 Role)이어야 합니다.
- **게이트:**
  - 머지 후 5분 안에 store 5장이 `True Valid`를 유지해야 합니다(VD-16).
  - `cannot create … serviceaccounts/token`이 보이면 즉시 revert합니다.
- **라이브 영향:** 중간.
  - 잘못 좁히면 vault store 4개가 동시에 NotReady가 됩니다.
  - 기존 Secret의 값은 유지됩니다.

### 단계 8 — OP1: kv 시드 ✋ (사용자 입회)

**이번 창의 시드 범위(D10 확정):**

| 경로 | 이번 창 | 비고 |
|---|---|---|
| `kv/platform/cloudflare/dns-token` {token} | **시드** | 라이브 Secret 파이프 복사 |
| `kv/platform/cloudflare/tunnel` {token} | **시드** | 라이브 Secret 파이프 복사 |
| `kv/platform/oci/s3` {access_key, secret_key} | **조건부** | `svc-s3-backup`의 **완전한 기존 키 쌍**이 PM에서 확인될 때만. 없으면 건너뛰고 **자동 재발급하지 않습니다**(T053 인계) |
| `kv/platform/test/t045-probe` {value} | **시드** | 비밀 아닌 값. DR1 드릴 전용이며 드릴이 끝나면 경로째 삭제 |
| `kv/{dev,prod}/access/web-bff`, `kv/platform/access/tester-{m2m,k8s}` | **이연** | T077·T092(읽기 권한 범위·전달 절차 확정 후). PM 사본 유지 |
| `kv/platform/grafana-cloud` | **이연** | T098(소비자 기준 키 집합 확정 후). 임시 값·sentinel 금지 |

**사전(블록 밖에서 수행):**

- 런북 `vault-unseal.md` §0의 창 시작 체크리스트를 진행합니다.
  - PSReadLine SaveNothing
  - Stop-Transcript 프로브
  - 전사 정책 0
  - KUBECONFIG = admin
- **창 C**에서 `kubectl -n vault port-forward svc/vault 18200:8200 --address 127.0.0.1`을 띄워 유지합니다. 이 명령은 블로킹입니다. **아래 블록에 넣지 않습니다.**
- PM을 육안으로 확인합니다(값을 출력하지 않습니다).
  - root 토큰
  - `svc-s3-backup` Customer Secret Key의 **두 절반이 모두 있는지**(하나라도 없으면 C) 단계를 건너뜁니다)
  - Access 서비스 토큰 4쌍은 **이번 창에서 다루지 않습니다**(이연).

```powershell
# ===== T045 OP1 시드 블록 — 통째로 붙여 넣어도 안전(창 D) =====
# 원칙: (a) 사람 동작마다 Read-Host로 멈춘다 (b) 취득·put·되읽기는 전부 fail-closed(throw) — 출력만 하고 계속 가는 비교는 없다
#       (c) 검증 통과 전에는 원본(라이브 Secret·PM·변수)을 아무것도 지우지 않는다 (d) 값은 화면·argv·파일에 나오지 않는다
#       (e) 최초 쓰기는 `-cas=0`(이미 값이 있으면 거부), 재실행은 해시 비교로 "동일이면 통과 / 다르면 중단"(D10-⑤)
#       (f) 성공·실패 어느 쪽이든 finally가 토큰·변수·클립보드를 정리하고 경로별 요약을 낸다
$ErrorActionPreference = 'Stop'
$seedLog = [ordered]@{}   # 경로 → 완료(신규) / 이미 시드됨(동일) / 보류(사유) / 중단(사유)
try {
  if ((Get-ItemProperty HKCU:\Software\Microsoft\Clipboard).EnableClipboardHistory -ne 0) { throw '클립보드 기록이 켜져 있음 — 끄고 다시' }
  if (Test-Path "$HOME/.vault-token") { throw '~/.vault-token 존재 — vault login 흔적. 원인 확인 후 다시' }
  $env:VAULT_ADDR = 'http://127.0.0.1:18200'
  $st = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status | ConvertFrom-Json
  if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 도달 실패 또는 sealed — 창 C port-forward 확인' }

  $env:VAULT_TOKEN = (Read-Host 'root 토큰(PM에서 복사 · 화면에 남지 않음)' -AsSecureString | ConvertFrom-SecureString -AsPlainText)
  if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
  $tl = vault token lookup "-format=json" | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0 -or $tl.data.policies -notcontains 'root') { throw 'root 토큰 확인 실패 — 중단' }

  $sha = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
  $getLive = { param($ns, $name, $key)
    $b64 = kubectl -n $ns get secret $name -o "jsonpath={.data.$key}"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($b64)) { throw "라이브 Secret 취득 실패: $ns/$name .$key — 시드 중단" }
    $v = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
    if ($v.Length -lt 32) { throw "라이브 값이 비정상적으로 짧다($($v.Length)) — 시드 중단" }
    if (-not [string]::Equals($v, $v.Trim(), [StringComparison]::Ordinal)) { throw "라이브 값 앞뒤에 공백/개행 — 그대로 복사하면 안 된다. 중단(사용자 결정)" }   # ⚠ `-cne`는 문화권 비교라 U+FEFF 같은 무시 가능 코드포인트를 놓친다
    $v }
  $exists = { param($path)                        # 경로에 현재 버전이 있는가(없으면 vault가 비0으로 끝난다)
    $j = $null
    try { $j = vault kv get "-format=json" $path 2>$null } catch { $j = $null }
    $ok = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$j))
    $global:LASTEXITCODE = 0
    $ok }
  $readField = { param($path, $field)
    $v = [string](vault kv get "-field=$field" $path)
    if ($LASTEXITCODE -ne 0) { throw "되읽기 실패: $path .$field" }
    $v }
  # 경로 1개 시드. 이미 값이 있으면 **덮어쓰지 않고** 해시로 가른다(재실행 안전).
  $seed = { param($path, [hashtable]$map)
    foreach ($k in $map.Keys) { if ($map[$k] -isnot [string] -or [string]::IsNullOrWhiteSpace($map[$k])) { throw "$path .$k 가 빈 값이거나 문자열이 아니다 — 중단" } }
    if (& $exists $path) {
      foreach ($k in $map.Keys) {
        $back = & $readField $path $k
        if (-not [string]::Equals((& $sha $back), (& $sha $map[$k]), [StringComparison]::Ordinal)) {
          $seedLog[$path] = '중단(존재하지만 값이 다름)'
          throw "$path .$k: 이미 다른 값이 있다 — 덮어쓰지 않고 중단(값 교체는 T084 회전 절차)" } }
      $seedLog[$path] = '이미 시드됨(동일)'
      return "SKIP $path — 이미 시드됨(값 동일)" }
    ($map | ConvertTo-Json -Compress) | vault kv put "-cas=0" $path -   # JSON stdin 한 형식. `key=-` 금지(stdin 1회·개행 포함). 값은 JSON 문자열만.
    if ($LASTEXITCODE -ne 0) { $seedLog[$path] = '중단(put 실패 — CAS 충돌이면 이미 값이 있다)'; throw "vault kv put 실패: $path" }
    foreach ($k in $map.Keys) {
      $back = & $readField $path $k
      if (-not [string]::Equals((& $sha $back), (& $sha $map[$k]), [StringComparison]::Ordinal)) {
        $seedLog[$path] = '중단(되읽기 불일치)'
        throw "kv 값 불일치: $path .$k — 중단(원본 유지)" } }
    $seedLog[$path] = '완료(신규)'
    "OK   $path ($((($map.Keys) | Sort-Object) -join ', '))" }

  Read-Host 'A) 폐기 경로로 JSON stdin 형식을 1회 실측한다(VD-6). Enter'
  ('{"a":"x","b":"y"}') | vault kv put "-cas=0" kv/platform/_probe -
  if ($LASTEXITCODE -ne 0) { throw '프로브 put 실패 — 경로가 이미 있거나 권한 문제. 확인 후 다시' }
  $pk = ((vault kv get "-format=json" kv/platform/_probe | ConvertFrom-Json).data.data.PSObject.Properties.Name | Sort-Object) -join ','
  if (-not [string]::Equals($pk, 'a,b', [StringComparison]::Ordinal)) { throw "JSON stdin 형식이 기대와 다르다(keys=$pk) — 중단, 설계 VD-6 폴백 검토" }
  vault kv metadata delete kv/platform/_probe | Out-Null
  if ($LASTEXITCODE -ne 0) { throw '프로브 경로 삭제 실패 — 수동 확인 후 다시(경로가 남으면 재실행 시 A)의 `-cas=0`이 막힌다)' }

  Read-Host 'B) 라이브 Secret 2건 → Vault 파이프 복사(값 비노출). Enter'
  $v1 = & $getLive 'cert-manager' 'cloudflare-dns-token' 'api-token'
  & $seed 'kv/platform/cloudflare/dns-token' @{ token = $v1 }
  $v2 = & $getLive 'cloudflared' 'cloudflared-tunnel' 'TUNNEL_TOKEN'
  & $seed 'kv/platform/cloudflare/tunnel' @{ token = $v2 }

  $ans = Read-Host 'C) kv/platform/oci/s3 — PM에 svc-s3-backup 키 쌍의 **두 절반이 모두** 있음을 확인했으면 y, 없으면 Enter(건너뜀 · 재발급하지 않음)'
  if ($ans -eq 'y') {
    $ak = (Read-Host 'access_key' -AsSecureString | ConvertFrom-SecureString -AsPlainText).Trim()
    $sk = (Read-Host 'secret_key' -AsSecureString | ConvertFrom-SecureString -AsPlainText).Trim()
    & $seed 'kv/platform/oci/s3' @{ access_key = $ak; secret_key = $sk }
  } else {
    $seedLog['kv/platform/oci/s3'] = '보류(키 쌍 미확인 — 자동 재발급 금지 · T053 전 별도 발급·교체 작업)'
  }

  Read-Host 'D) DR1 드릴용 비밀 아닌 값 1건(kv/platform/test/t045-probe). Enter'
  & $seed 'kv/platform/test/t045-probe' @{ value = 't045-drill-not-a-secret' }

  # 이연(D10): kv/{dev,prod}/access/web-bff · kv/platform/access/tester-{m2m,k8s} → T077·T092
  #            kv/platform/grafana-cloud → T098(임시 값·sentinel 금지)
  $seedLog['kv/{dev,prod}/access/web-bff']            = '이연(T092 — 읽기 권한 범위·전달 절차 확정 후)'
  $seedLog['kv/platform/access/tester-{m2m,k8s}']     = '이연(T077 — 동일)'
  $seedLog['kv/platform/grafana-cloud']               = '이연(T098 — 소비자 기준 키 집합 확정 후)'

  vault kv metadata get kv/platform/cloudflare/dns-token | Select-String 'current_version|created_time'
  vault kv metadata get kv/platform/cloudflare/tunnel    | Select-String 'current_version|created_time'
  vault kv list kv/platform;  vault kv list kv/platform/cloudflare

  Read-Host 'E) 위 OK/SKIP 줄과 version 을 런북 §4 기록용으로 확인했으면 Enter — 정리로 넘어간다(라이브 Secret·PM 은 건드리지 않는다)'
}
finally {
  Remove-Variable v1, v2, ak, sk, pk, tl, st -ErrorAction SilentlyContinue
  if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
  if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
  try { Set-Clipboard -Value ' ' } catch { }
  ''
  '--- 시드 결과 요약(런북 §4에 그대로 기록) ---'
  $seedLog.GetEnumerator() | ForEach-Object { '{0,-46} {1}' -f $_.Key, $_.Value }
  if (Test-Path "$HOME/.vault-token") { Write-Warning '~/.vault-token 이 생겼다 — 즉시 삭제하고 원인 확인' }
  '창 종료 체크리스트(런북 §0): 창 C port-forward 종료 · cloudflared access 캐시 토큰 삭제'
}
```

- **게이트(합격 문면):**
  - 시드 대상 경로마다 `OK`(신규) 또는 `SKIP …(값 동일)` 줄이 나와야 합니다.
  - dns-token과 tunnel의 `current_version`이 확인되어야 합니다.
  - 블록이 `throw` 없이 E)까지 도달해야 합니다.
  - 요약 표에 **중단** 항목이 없어야 하고, **보류·이연** 항목은 그대로 런북과 완료 보고에 옮겨 적어야 합니다(D10-④).
- **재실행 절차(D10-⑤ d):**
  - 블록을 처음부터 다시 붙여 넣습니다. 성공한 경로는 `-cas=0`과 해시 비교가 보호하므로 `SKIP …(값 동일)`로 지나갑니다.
  - "존재하지만 값이 다름"으로 중단되면 **덮어쓰지 않습니다.** 원인을 먼저 가립니다(오투입인지, 라이브가 이미 회전됐는지). 오투입이 확인된 경우에만 아래 되돌리기로 정정합니다.
  - 경로 단위로 골라 실행하는 분기는 없습니다. 블록 전체를 다시 붙여 넣으면 성공한 경로는 `SKIP …(값 동일)`로 지나가므로 따로 건너뛸 필요가 없습니다(A)·B)·D)·E)의 Read-Host는 Enter로 진행만 하는 정지점이고, 건너뛰기 분기가 있는 것은 C)뿐입니다). 중간에 멈추려면 Read-Host에서 Ctrl+C를 누릅니다(`finally`가 정리합니다).
- **되돌리기:**
  - 오투입이면 `vault kv destroy "-versions=<N>" <path>` 후 재투입합니다. ⚠ `destroy`는 메타데이터의 `current_version`을 0으로 되돌리지 않으므로 **재투입에 `-cas=0`을 쓸 수 없습니다**(정확한 동작은 VD-14에서 함께 확인합니다). 재투입은 `-cas=<current_version>`으로 하거나, 경로를 `vault kv metadata delete`로 지운 뒤 블록을 다시 실행합니다.
  - 구 버전이 남아 있다는 점은 VD-14로 확인합니다.
- **정정 블록(kv 값 정정 — 잠금 복구 R1의 2단계와 G3 되돌리기가 참조합니다):**
  - **kv 정정은 OP1의 `$seed`로 하지 않습니다.** `$seed`는 경로에 값이 있으면 "존재하지만 값이 다름 → 중단"으로 `throw`하고 최초 쓰기는 `-cas=0`이라, 정의상 **덮어쓰기를 거부하는 것이 설계**입니다. 정정은 아래 전용 게이트 블록으로만 합니다.
  - 값의 출처는 세 갈래입니다. (a) 라이브 Secret이 아직 옳으면 라이브에서 다시 읽습니다(OP1 `$getLive`와 같은 방식) (b) 라이브가 이미 덮였으면 G4 블록의 `$pre`를 base64 디코드합니다 (c) 둘 다 신뢰할 수 없으면 PM 값을 `Read-Host -AsSecureString`으로 넣습니다.

  ```powershell
  # ===== T045 kv 값 정정 블록 — 통째로 붙여 넣어도 안전(창 D, 창 C의 port-forward 유지) =====
  # 원칙은 OP1과 같다: 사람 동작마다 Read-Host, 모든 취득·put·되읽기가 fail-closed, finally가 토큰·변수·클립보드를 정리한다.
  $ErrorActionPreference = 'Stop'
  $fixPath  = 'kv/platform/cloudflare/tunnel'    # 정정할 경로(DNS면 kv/platform/cloudflare/dns-token)
  $fixField = 'token'
  try {
    if ((Get-ItemProperty HKCU:\Software\Microsoft\Clipboard).EnableClipboardHistory -ne 0) { throw '클립보드 기록이 켜져 있음 — 끄고 다시' }
    $env:VAULT_ADDR = 'http://127.0.0.1:18200'
    $st = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status | ConvertFrom-Json
    if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 도달 실패 또는 sealed — 창 C port-forward 확인' }
    $env:VAULT_TOKEN = (Read-Host 'root 토큰(PM에서 복사 · 화면에 남지 않음)' -AsSecureString | ConvertFrom-SecureString -AsPlainText)
    if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
    $tl = vault token lookup "-format=json" | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0 -or $tl.data.policies -notcontains 'root') { throw 'root 토큰 확인 실패 — 중단' }

    # 1) 정정 값 취득(세 갈래). 빈 값·짧은 값·앞뒤 공백이면 중단한다.
    $src = Read-Host '값 출처: a=라이브 Secret · b=이 세션의 $pre(base64) · c=PM 직접 입력'
    switch ($src) {
      'a' { $ns = Read-Host 'ns'; $sn = Read-Host 'secret 이름'; $sk = Read-Host 'secret 키'
            $b64 = kubectl -n $ns get secret $sn -o "jsonpath={.data.$sk}"
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($b64)) { throw '라이브 Secret 취득 실패 — 중단' }
            $new = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) }
      'b' { if ([string]::IsNullOrWhiteSpace($pre)) { throw '$pre 가 비어 있다(이 세션이 아니다) — c 로 간다' }
            $new = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($pre)) }
      'c' { $new = (Read-Host 'PM 값' -AsSecureString | ConvertFrom-SecureString -AsPlainText) }
      default { throw '출처를 고르지 않았다 — 중단' }
    }
    if ([string]::IsNullOrWhiteSpace($new) -or $new.Length -lt 32) { throw '정정 값이 비었거나 비정상적으로 짧다 — 중단' }
    if (-not [string]::Equals($new, $new.Trim(), [StringComparison]::Ordinal)) { throw '정정 값 앞뒤에 공백/개행 — 중단' }

    # 2) CAS 대상 = 현재 버전. 못 읽으면 중단(덮어쓰기를 눈감고 하지 않는다).
    $cur = (vault kv metadata get "-format=json" $fixPath | ConvertFrom-Json).data.current_version
    if ($LASTEXITCODE -ne 0 -or $null -eq $cur) { throw "current_version 취득 실패: $fixPath — 중단" }
    $ok = Read-Host "3) $fixPath 의 현재 버전 $cur 를 덮어쓴다. 계속하려면 yes 를 입력하고 Enter"
    if (-not [string]::Equals($ok, 'yes', [StringComparison]::Ordinal)) { throw '취소됨 — 아무것도 쓰지 않았다' }

    # 4) CAS put → 되읽기 SHA-256 Ordinal 비교
    (@{ $fixField = $new } | ConvertTo-Json -Compress) | vault kv put "-cas=$cur" $fixPath -
    if ($LASTEXITCODE -ne 0) { throw "정정 put 실패(CAS 충돌이면 그 사이 다른 쓰기가 있었다): $fixPath" }
    $sha  = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
    $back = [string](vault kv get "-field=$fixField" $fixPath)
    if ($LASTEXITCODE -ne 0) { throw "되읽기 실패: $fixPath .$fixField" }
    if (-not [string]::Equals((& $sha $back), (& $sha $new), [StringComparison]::Ordinal)) { throw '되읽기 해시 불일치 — 값이 기대와 다르다. 다음 refresh 전에 다시 정정한다' }
    "OK 정정 완료: $fixPath .$fixField (새 버전 $($cur + 1))"
  }
  finally {
    # ⚠ `$pre`·`$preUid`는 지우지 않는다 — G4 되돌리기 R2의 stdin 복구에 필요하다.
    Remove-Variable new, back, b64, src, ns, sn, sk, sha, tl, st, cur, ok -ErrorAction SilentlyContinue
    if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
    if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
    try { Set-Clipboard -Value ' ' } catch { }
    '다음 refresh(≤5분) 또는 VD-15 force-sync 뒤 라이브 Secret 값을 다시 비교한다.'
  }
  ```

- **라이브 영향:** 낮음.
  - kv 쓰기만 합니다(ES가 아직 없습니다).
  - 이 창이 값과 root 토큰이 한 셸에 함께 있는 최대 노출 구간입니다.
  - 감사 장치가 1개이고 fail-closed입니다. 장치에 장애가 나면 put이 거부됩니다.

### 단계 8b — DR1: 테스트용 ES/Secret 드릴 ✋ (D4-⑤ · G2r 뒤 · G3 앞 · 사용자 입회)

**목적.** `Orphan`/`Retain`/`refreshPolicy: Periodic` 조합이 실제로 어떻게 동작하는지를 **터널·DNS가 아닌 대상으로 먼저** 봅니다. 여기서 확인한 사실이 G3·G4의 게이트 문면과 되돌리기 절차의 근거가 됩니다.

- **대상:** ns `external-secrets`, kv `platform/test/t045-probe`(OP1 D 단계에서 시드한 **비밀 아닌** 값), Secret 이름 `t045-probe`.
- **적용 방법:** 운영자가 `kubectl apply -f -`로 직접 적용하고 직접 제거합니다. **git을 거치지 않습니다** — Argo가 모르는 객체라 `prune: false`로 인한 잔존이 없습니다.
- **인수 대상 만들기:** 먼저 같은 이름의 Secret을 수동으로 만들어 두고(값은 kv와 같게), 그 위에 ES를 적용해 **인수 경로를 그대로 재현**합니다.

```powershell
# ===== T045 DR1 드릴 블록 — 통째로 붙여 넣어도 안전 =====
# 원칙: (a) 사람 동작마다 Read-Host (b) 모든 취득·적용·삭제가 fail-closed(exit 확인 뒤 판정)
#       (c) 시작 시 이전 잔존물이 있으면 중단(잔존물 위에서는 "첫 인수" 실측이 아니다 — managed 라벨·data-hash가 이미 있다)
#       (d) finally 가 잔존물을 알리고 정리 명령을 출력한다(잔존 ES 는 하네스 eso-2 에도 영향)
$ErrorActionPreference = 'Stop'
$NS = 'external-secrets'; $N = 't045-probe'
try {
  # 0) 이전 실행의 잔존물 검사
  $pre0 = kubectl -n $NS get externalsecret,secret $N --ignore-not-found -o name
  if ($LASTEXITCODE -ne 0) { throw '잔존물 조회 실패 — 판정 불가' }
  if ($pre0) { throw "이전 드릴 잔존물이 있다($pre0) — 6) 정리 두 줄을 먼저 실행하고 다시" }

  # ES YAML 은 변수에 담아 2)와 5)에서 재사용한다(다른 창에서 손으로 재구성하지 않는다)
  $esYaml = @"
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: $N, namespace: $NS }
spec:
  refreshPolicy: Periodic
  refreshInterval: 5m
  secretStoreRef: { kind: ClusterSecretStore, name: vault-platform }
  target:
    name: $N
    creationPolicy: Orphan
    deletionPolicy: Retain
    template:
      metadata: {}
  data:
    - secretKey: value
      remoteRef: { key: platform/test/t045-probe, property: value }
"@
  # SecretSynced 까지 최대 120초 폴링(5초 간격). 고정 sleep 을 쓰지 않는다.
  $waitSynced = {
    $c = ''
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
      $c = kubectl -n $NS get externalsecret $N -o "jsonpath={.status.conditions[?(@.type=='Ready')].reason}"
      if ($LASTEXITCODE -eq 0 -and [string]::Equals([string]$c, 'SecretSynced', [StringComparison]::Ordinal)) { return }
      Start-Sleep -Seconds 5
    }
    throw "드릴 ES 가 120초 안에 SecretSynced 가 되지 않았다(마지막 reason=$c) — 원인 확인(store·권한·경로)"
  }

  # 1) 수동 Secret 생성(비밀 아님) → 인수 전 UID·값 기록
  (@{apiVersion='v1';kind='Secret';type='Opaque';metadata=@{name=$N;namespace=$NS};stringData=@{value='t045-drill-not-a-secret'}} | ConvertTo-Json -Compress -Depth 5) | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) { throw '드릴 Secret 생성 실패' }
  $uid0 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}"
  $h0   = kubectl -n $NS get secret $N -o "jsonpath={.data.value}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($uid0) -or [string]::IsNullOrWhiteSpace($h0)) { throw '인수 전 상태 취득 실패' }

  Read-Host '2) 이제 드릴 ES 를 적용한다(Orphan/Retain/Periodic 5m). Enter'
  $esYaml | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) { throw '드릴 ES 적용 실패 — admission(webhook) 또는 store 문제' }
  & $waitSynced

  # 3) 인수 실측: UID 불변 · 값 불변 · ownerRef 부재
  $uid1 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}"
  $h1   = kubectl -n $NS get secret $N -o "jsonpath={.data.value}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($uid1) -or [string]::IsNullOrWhiteSpace($h1)) { throw '인수 후 상태 취득 실패 — 판정 불가' }
  $own = kubectl -n $NS get secret $N -o "jsonpath={.metadata.ownerReferences}"
  if ($LASTEXITCODE -ne 0) { throw 'ownerReferences 조회 실패 — 판정 불가(빈 문자열을 "없음"으로 읽지 않는다)' }
  if (-not [string]::Equals($uid0, $uid1, [StringComparison]::Ordinal)) { throw '드릴: UID가 바뀌었다 = 제자리 인수가 아니라 재생성이다 — G3/G4 게이트 문면을 다시 짠다' }
  if (-not [string]::Equals($h0,   $h1,   [StringComparison]::Ordinal)) { throw '드릴: 값이 바뀌었다 — kv 값과 수동 값이 달랐다는 뜻' }
  if (-not [string]::IsNullOrWhiteSpace($own)) { throw '드릴: ownerReferences 가 붙었다 — Orphan이 기대대로 동작하지 않는다. G4를 열지 않는다' }
  'OK 드릴 인수: UID 불변 · 값 불변 · ownerRef 없음'

  Read-Host '4) ES 삭제 후 Secret 잔존 확인. Enter'
  kubectl -n $NS delete externalsecret $N
  if ($LASTEXITCODE -ne 0) { throw 'ES 삭제 실패(webhook 이 DELETE 를 거부했나?) — 잔존 판정 불가' }
  Start-Sleep -Seconds 15    # 비동기 GC 가 있었다면 이 사이에 드러난다(삭제 직후 즉시 조회는 자명하게 통과한다)
  $left = kubectl -n $NS get externalsecret $N --ignore-not-found -o name
  if ($LASTEXITCODE -ne 0) { throw 'ES 부재 확인 실패 — 판정 불가' }
  if ($left) { throw "ES 가 아직 있다($left) — 삭제가 실제로 되지 않았다" }
  $uid2 = kubectl -n $NS get secret $N -o "jsonpath={.metadata.uid}"
  $h2   = kubectl -n $NS get secret $N -o "jsonpath={.data.value}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($uid2)) { throw '드릴: ES 삭제 후 Secret 이 사라졌다 — Orphan 전제 붕괴' }
  if (-not [string]::Equals($uid0, $uid2, [StringComparison]::Ordinal)) { throw '드릴: Secret 이 재생성됐다(UID 변경) — Orphan 전제 붕괴' }
  if (-not [string]::Equals($h0,   $h2,   [StringComparison]::Ordinal)) { throw '드릴: ES 삭제 후 값이 바뀌었다 — 원인 확인' }
  'OK ES 삭제 후에도 Secret 잔존(같은 UID · 같은 값)'

  Read-Host '5) ES 를 다시 적용하고 Secret 을 삭제해 재생성 시점을 잰다(VD-20). Enter'
  $esYaml | kubectl apply -f -
  if ($LASTEXITCODE -ne 0) { throw '드릴 ES 재적용 실패' }
  & $waitSynced
  $t0 = Get-Date
  kubectl -n $NS delete secret $N
  if ($LASTEXITCODE -ne 0) { throw '드릴 Secret 삭제 실패 — VD-20 측정 불가' }
  $back = $null
  while ((Get-Date) -lt $t0.AddSeconds(420)) {
    $back = kubectl -n $NS get secret $N --ignore-not-found -o name
    if ($LASTEXITCODE -eq 0 -and $back) { break }
    $back = $null
    Start-Sleep -Seconds 5
  }
  if (-not $back) { throw 'VD-20 = 미재생성(420초) — 런북에 그대로 기록하고 G3 전에 원인을 확인한다' }
  "VD-20: Secret 재생성까지 약 $([int]((Get-Date) - $t0).TotalSeconds) 초(폴링 간격 5초) — 즉시인지 ≤5분 주기인지의 판정 근거"

  Read-Host '6) 정리(전부 삭제). Enter'
  kubectl -n $NS delete externalsecret $N --ignore-not-found
  kubectl -n $NS delete secret $N --ignore-not-found
  'K8s 객체 정리 완료 — kv 경로는 아래 "kv 정리 블록"에서 지운다(root 토큰을 한 번 더 입력한다)'
}
finally {
  $leftOver = kubectl -n $NS get externalsecret,secret $N --ignore-not-found -o name 2>$null
  $global:LASTEXITCODE = 0
  if ($leftOver) {
    Write-Warning "드릴 잔존물이 남아 있다($leftOver) — 아래 두 줄을 실행해 정리한다(잔존 ES 는 하네스 eso-2 에도 영향)"
    "kubectl -n $NS delete externalsecret $N --ignore-not-found"
    "kubectl -n $NS delete secret $N --ignore-not-found"
  }
  Remove-Variable pre0, esYaml, waitSynced, uid0, uid1, uid2, h0, h1, h2, own, left, back, t0, leftOver -ErrorAction SilentlyContinue
}
```

**kv 정리 블록(DR1 뒤 — `kv/platform/test/t045-probe` 삭제).** OP1 블록의 `finally`가 `VAULT_TOKEN`·`VAULT_ADDR`를 이미 지웠으므로 "OP1 창"에는 자격이 남아 있지 않습니다. root 토큰을 한 번 더 입력하는 전용 게이트 블록으로 지웁니다(창 C의 port-forward는 유지합니다).

```powershell
# ===== T045 DR1 kv 정리 블록 — 통째로 붙여 넣어도 안전(창 D) =====
$ErrorActionPreference = 'Stop'
try {
  if ((Get-ItemProperty HKCU:\Software\Microsoft\Clipboard).EnableClipboardHistory -ne 0) { throw '클립보드 기록이 켜져 있음 — 끄고 다시' }
  $env:VAULT_ADDR = 'http://127.0.0.1:18200'
  $st = curl.exe -s --max-time 5 http://127.0.0.1:18200/v1/sys/seal-status | ConvertFrom-Json
  if (-not $st -or -not $st.initialized -or $st.sealed) { throw 'Vault 도달 실패 또는 sealed — 창 C port-forward 확인' }
  $env:VAULT_TOKEN = (Read-Host 'root 토큰(PM에서 복사 · 화면에 남지 않음)' -AsSecureString | ConvertFrom-SecureString -AsPlainText)
  if ([string]::IsNullOrWhiteSpace($env:VAULT_TOKEN)) { throw '빈 토큰 — 중단' }
  $tl = vault token lookup "-format=json" | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0 -or $tl.data.policies -notcontains 'root') { throw 'root 토큰 확인 실패 — 중단' }

  Read-Host 'kv/platform/test/t045-probe 를 메타데이터째 삭제한다(드릴 전용 · 비밀 아님). Enter'
  vault kv metadata delete kv/platform/test/t045-probe
  if ($LASTEXITCODE -ne 0) { throw 'kv 경로 삭제 실패 — 수동 확인' }
  vault kv metadata get kv/platform/test/t045-probe 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { throw '경로가 아직 있다 — 삭제가 되지 않았다' }
  $global:LASTEXITCODE = 0
  'OK kv 드릴 경로 삭제'
}
finally {
  Remove-Variable tl, st -ErrorAction SilentlyContinue
  if (Test-Path Env:VAULT_TOKEN) { Remove-Item Env:VAULT_TOKEN }
  if (Test-Path Env:VAULT_ADDR)  { Remove-Item Env:VAULT_ADDR }
  try { Set-Clipboard -Value ' ' } catch { }
}
```

- **게이트(합격 문면):**
  - `OK 드릴 인수: UID 불변 · 값 불변 · ownerRef 없음`
  - `OK ES 삭제 후에도 Secret 잔존(같은 UID · 같은 값)` — ES 삭제가 종료 코드 0이고, 15초 뒤 ES 부재가 확인된 뒤의 판정입니다(webhook이 DELETE를 거부했는데 "잔존"으로 읽는 가짜 PASS를 막습니다).
  - `VD-20: Secret 재생성까지 약 N 초` 줄이 출력되고, 그 **시점**(즉시인지 ≤5분 주기인지)이 런북에 기록됩니다.
  - 정리 후 ns `external-secrets`에 `t045-probe` ES·Secret이 없고(블록의 `finally`가 잔존을 경고합니다), **kv 정리 블록**까지 실행해 `kv/platform/test/t045-probe`가 지워졌습니다.
- **이 드릴이 증명하지 않는 것:** `Delete=false,Prune=false`의 Argo 동작(드릴은 git을 거치지 않습니다)과, webhook 장애 중의 동작. 전자는 G4에서 Argo 경로로 확인하고, 후자는 T048 인계입니다.
- **라이브 영향:** 낮음. 모든 대상이 이번에 만든 테스트 객체이고, 값이 비밀이 아닙니다. 단 ESO admission·store를 실제로 통과하므로 **G2 게이트가 PASS한 뒤에만** 합니다.
- **되돌리기:** 6) 정리 단계가 곧 되돌리기이고, 중간에서 `throw`로 멈춰도 `finally`가 잔존물과 정리 명령 두 줄을 출력합니다. **kv 정리 블록**까지 마쳐야 끝입니다.

### 단계 9 — G3: `platform/secrets` + dns 토큰 인수 ✋ (저위험, VD-3)

- **빌드 게이트:**
  - `kustomize build platform/secrets`가 rc=0이고 ES 1장이 나와야 합니다(VD-13).
  - 출력에 `cp=Orphan ns=cert-manager`가 있어야 합니다(D4 = B′).
  - `bash tests/validate.sh`에서 3.0, 3.1, 3.2, 7.1, 7.2, **7.3(단일 소유)**가 PASS해야 합니다.
  - **이 PR에 D3 조건 1·2·3 문구가 들어가야 합니다** — `platform/secrets/README.md`(신규)와 `secrets/README.md`(전문 교체, §4.10)에 범위(ES 2장 · 새 ES 추가 전 원본·소비자 wave 확인) · 단일 소유 · 콜드 부트스트랩 수동 선행이 있어야 합니다. G5는 이 본문을 고치지 않고 실측 확정값만 채웁니다.
- **머지 전(운영자, 같은 창을 유지):**
  ```powershell
  $ErrorActionPreference = 'Stop'
  # ⚠ DNS 토큰 값 자체는 세션 변수로 보관하지 않는다(존 전체 DNS 쓰기 권한). 비교는 해시로 한다 —
  #    복구용 원본은 PM과 kv에 있고, 값 정정은 §5 단계 8의 정정 블록이 담당한다.
  $sha     = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
  $b64     = kubectl -n cert-manager get secret cloudflare-dns-token -o "jsonpath={.data.api-token}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($b64)) { throw '인수 전 값 취득 실패' }
  $preHash = & $sha $b64
  Remove-Variable b64
  $preUid  = kubectl -n cert-manager get secret cloudflare-dns-token -o "jsonpath={.metadata.uid}"
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($preUid)) { throw '인수 전 UID 취득 실패' }
  ```
- **머지 후 게이트(D4-② — G4와 같은 세 검사):**
  ```powershell
  $ErrorActionPreference = 'Stop'
  try {
    $r = kubectl -n cert-manager get externalsecret cloudflare-dns-token -o "jsonpath={.status.conditions[?(@.type=='Ready')].reason}"
    if ($LASTEXITCODE -ne 0) { throw 'ES 상태 취득 실패 — 판정 불가' }
    if (-not [string]::Equals($r, 'SecretSynced', [StringComparison]::Ordinal)) { throw "ES reason=$r — provider 실패면 Secret은 미변경이다. 원인 확인" }
    $post = kubectl -n cert-manager get secret cloudflare-dns-token -o "jsonpath={.data.api-token}"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($post)) { throw '인수 후 상태 취득 실패' }
    $postHash = & $sha $post
    Remove-Variable post
    $postUid = kubectl -n cert-manager get secret cloudflare-dns-token -o "jsonpath={.metadata.uid}"
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($postUid)) { throw '인수 후 상태 취득 실패' }
    $own = kubectl -n cert-manager get secret cloudflare-dns-token -o "jsonpath={.metadata.ownerReferences}"
    if ($LASTEXITCODE -ne 0) { throw 'ownerReferences 조회 실패 — 판정 불가(빈 문자열을 "없음"으로 읽지 않는다)' }
    if (-not [string]::Equals($preHash, $postHash, [StringComparison]::Ordinal)) { throw '값이 바뀌었다 — G4로 가지 않는다. kv 재확인' }
    if (-not [string]::Equals($preUid, $postUid, [StringComparison]::Ordinal))   { throw 'UID가 바뀌었다 = 제자리 인수가 아니다 — G4로 가지 않는다' }
    if (-not [string]::IsNullOrWhiteSpace($own))                                 { throw 'ownerReferences 가 붙었다 — creationPolicy 가 Orphan 이 아니다. ES를 지우지 말고 매니페스트 확인' }
    'OK 값 불변 · UID 불변 · ownerRef 없음'
  }
  finally {
    Remove-Variable pre, post, preHash, postHash, preUid, postUid, own, r, sha, b64 -ErrorAction SilentlyContinue
  }
  ```
  - **단일 소유 확인(D3 조건 2 · VD-21):**
    ```powershell
    kubectl -n cert-manager get externalsecret cloudflare-dns-token -o "jsonpath={.metadata.annotations.argocd\.argoproj\.io/tracking-id}"   # platform-secrets:…
    kubectl -n argocd get app platform-cert-manager-issuers -o "jsonpath={range .status.resources[*]}{.group}/{.kind} {end}"                  # external-secrets.io 0건
    ```
    - 뒤 명령의 "issuers에 `external-secrets.io` 0건"이 **VD-23의 ②(issuers 몫)**입니다. VD-23의 ①(webhook `rules` 대상이 `secretstores`·`clustersecretstores`·`externalsecrets`뿐)과 ③(소비자 Deployment server-side dry-run)은 터널 ES가 들어간 뒤인 **단계 10 게이트**에서 `platform-cloudflared`를 대상으로 판정합니다.
  - 이어서 staging 능동 검증을 합니다. **prod 재발급은 금지**입니다.
    - 임시 Certificate(ns `kube-system`, issuer `letsencrypt-staging`, dnsNames `t045-probe.joshuatech.dev`)를 만듭니다.
    - 5분 안에 Ready=True가 되면 Certificate와 Secret을 삭제합니다.
    - 실패 메시지가 CF `Authentication error`이면 kv 값이 잘못된 것입니다.
  - prod 와일드카드의 `Ready`, `status.renewalTime`, `notAfter`를 기준값으로 기록합니다(VD-17).
  - `platform-secrets`가 Synced/Healthy여야 합니다.
- **되돌리기(D4-④ — 터널과 같은 절차):**
  - 값 문제이면 kv를 정정합니다 — **§5 단계 8의 "정정 블록"**을 씁니다(OP1의 `$seed`는 덮어쓰기를 거부하는 것이 설계라 정정에 쓸 수 없습니다). 수동으로 Secret만 고치면 다음 갱신에 다시 덮입니다.
  - 인수 자체를 해제해야 하면 순서를 지킵니다.
    1. revert PR을 머지합니다(먼저 하지 않으면 `selfHeal`이 ES를 다시 만듭니다).
    2. **Argo에 반영됐는지 확인합니다** — `platform-secrets`의 리비전이 revert 커밋이고, 해당 ES가 `requiresPruning`으로 표시됩니다.
    3. `kubectl -n cert-manager delete externalsecret cloudflare-dns-token`을 실행합니다.
    4. **Secret 잔존·UID·값 불변을 확인합니다**(Orphan이므로 GC되지 않습니다).
    5. 값이 깨졌으면 stdin JSON으로 복구합니다. 복구 값의 출처는 kv 또는 PM입니다 — 이 창에는 DNS 토큰 값을 보관하지 않고 해시(`$preHash`)만 남깁니다.
    6. 소비자 파드를 1개씩 교체합니다(cert-manager는 챌린지 순간에만 읽으므로 대개 불필요합니다).
  - 갱신 창(≈2026-11-08) 밖이면 공백·지연은 무해합니다.
- **라이브 영향:** 낮음.

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

### 단계 11 — G5(gitops docs)와 모노레포 마무리

- **gitops docs(README 4건 — `cloudflared`·`cert-manager-issuers`는 정정, `platform/secrets`·`platform/external-secrets`는 G3·G1에서 만든 본문에 실측 확정값(VD-20 재생성 시점 · 노드 간 미실측 한계 · G1p 실측 기록)을 보강):**
  - `platform/cloudflared/README.md` ⑨에 확정값을 적습니다.
    - `token`, `Orphan`/`Retain`, `refreshPolicy: Periodic`/`5m`
    - 회전 시 수동 재시작이 필요하다는 점
    - R1~R3(인수 해제는 revert → Argo 반영 확인 → ES 삭제 → Secret 잔존 확인 순서)
    - **콜드 부트스트랩에서는 터널 Secret과 cloudflared를 T039 절차대로 수동으로 먼저 올린다**(D3 조건 3)
    - break-glass의 실제 명령
  - `platform/cert-manager-issuers/README.md` §11을 고칩니다.
    - `property: token`
    - DNS ES가 `Orphan`이라는 점(§11이 `Owner`를 전제하지 않도록)
    - VD-10을 실증으로 교체
    - conditions에 cert-manager가 포함됨을 확인 완료로 표기
  - `platform/secrets/README.md`: G3에서 만든 본문(범위(ES 2장) · 단일 소유 · 인수 해제 절차 · Argo 고아 경고 · 콜드 부트스트랩)에 VD-20 실측 결과를 채웁니다.
  - `platform/external-secrets/README.md`: 렌더 grep 체크리스트 · 되돌리기 · **노드 간 webhook 경로 미실측 한계**(D6-④).
  - (`secrets/README.md`는 G3에서 이미 §4.10으로 전문 교체했고, policies 주석은 G1p에서 실측 기록으로 교체했습니다. G5에서는 확정값만 맞춥니다.)
  - README에 wave 숫자를 다시 적지 않습니다.
- **모노레포:** §8의 목록을 처리합니다.
- **게이트:**
  - `pwsh -NoProfile -File tests/run-all.ps1`이 PASS합니다.
  - agent-view로 `run-platform-tests.ps1`을 돌립니다.
    - eso-1(강화판), eso-2, eso-3, eso-4(두 ES 모두 `Orphan`), np-set-5(강화판), argo-1, argo-4가 PASS합니다.
    - ca-1은 T056까지 SKIP(`until T056`)이 예상됩니다(설계 초안의 "FAIL"은 오류 — 하네스는 미러 Secret이 없으면 SKIP).
- **완료 보고(D10-④):** report.md · 런북 · 체크박스 커밋 메시지에 **이연 범위**를 명시합니다 — Access 4경로(T077·T092), `grafana-cloud`(T098), 그리고 건너뛴 경우 `oci/s3`(T053 전 별도 발급·교체).
- **tasks.md:** T045 체크박스만 `[X]`로 바꿉니다.

---

## 6. 위험·차단 시나리오

| # | 시나리오 | 출처 | 설계 반영 | 상태 |
|---|---|---|---|---|
| R-1 | fail-open 시드: 빈 토큰이 kv에 기록되고, 빈 값끼리의 비교가 통과하고, ESO가 라이브 터널 Secret을 빈 값으로 덮고, 다음 파드 교체에서 잠깁니다 | 비평 1 blocker | OP1 블록의 `$getLive`(exit·빈 값·길이·공백 `throw`), `$seed`(빈 값·put 실패·CAS 충돌·되읽기 해시 불일치 `throw`), `$readField`(exit `throw`)가 모두 fail-closed입니다. G3·G4에서 인수 전후 값이 불변인지도 `throw`로 확인합니다 | 반영 |
| R-2 | 복구한 Secret을 ESO가 5분 안에 다시 덮습니다. `scale 0`은 selfHeal이 되돌립니다 | 비평 1 blocker + 종합 보강 | 되돌리기를 R1(kv 정정 우선 — 전용 정정 블록) → R2(revert 머지 → **Argo 반영 확인(리비전 = revert 커밋 · 해당 ES `requiresPruning`)** → ES 삭제(비상 시에만) → Secret 잔존·UID·값 확인 → stdin 복구 → 파드 1개씩; **두 ES 공통**, D4-④) → R3 순으로 다시 썼습니다. 평시 ES 삭제 금지와 비상 시 허용을 구분했습니다 | 반영 |
| R-3 | 카나리아가 `prune:false` 때문에 라이브에 남습니다(토큰 사본, eso-2가 카나리아에 종속) | 비평 1 blocker | 카나리아를 뺐습니다(D5에서 구성으로 동일성 보장) | 반영 |
| R-4 | ns external-secrets의 webhook 정책에 flannel /32가 없습니다(계약 위반, 검사의 사각지대) | 비평 2 blocker | **D6 = A 확정**. G1p add-only PR이고, 값은 머지 전 노드 A 실측으로 확정합니다. 검사의 사각지대는 `np-set-5` 강화 + validate 5.x 신설로 닫습니다. `network-policy.md`는 고치지 않습니다 | 반영(확정) |
| R-5 | 권한 축소와 컴포넌트를 한 머지에 묶는 것은 D7 위반입니다 | 비평 2 blocker | G2r 단독 PR로 분리하고 G2 직후로 앞당겼습니다 | 반영 |
| R-6 | 터널·issuers Application의 sync가 ESO webhook에 묶입니다 | 비평 1 major | **D3 = B 확정** — 전용 `platform/secrets`. 효과는 "소비자 배포와 ES 적용의 분리"이고, 구조 검증 2건 + dry-run으로 판정합니다(라이브 드릴은 T048) | 반영(확정, VD-13·R-23) |
| R-7 | store가 wave 0에 있으면 Vault 일시 장애가 root sync 정지로 이어집니다 | 비평 1·2 major | **D2 = B 확정** — `platform/secret-stores` 분리. ⚠ store(15)·secrets(18) Application 자체의 Degraded와 root wave 대기는 남습니다(R-21) | 반영(확정) |
| R-8 | break-glass 계약 문면("OpenTofu 변수")이 실제와 다릅니다. `break-glass.md`는 아직 없습니다 | 비평 1 major | M0에서 `hostnames-and-access.md:93`을 정정합니다. G4 사전 조건에서 OCI 자격을 실측합니다 | 반영. 런북 본체는 T084 |
| R-9 | PM 해시 눈 대조가 평문을 다시 노출시킵니다 | 비평 1 major | 파이프 복사를 택했고 클립보드 기록 `throw`를 복제했습니다 | 반영 |
| R-10 | dns 토큰 회귀가 ≈2026-11-08까지 증상이 없고 알림 경로가 0입니다 | 비평 1 major | VD-17 기준값을 기록합니다. **2026-11-01 이전에 staging 재프로브를 날짜를 정해 점검**합니다. report의 잔여 위험으로 남기고 T098에 인계합니다. staging 프로브를 상시 유지하는 안은 기각했습니다. 갱신 시점(발급 후 약 60일)이 prod 갱신보다 늦어서 효용이 없습니다 | 부분 반영. **잔여 위험은 명시** |
| R-11 | 계약 §디렉터리 열거와 §워크로드 강화 목록이 갱신되지 않았습니다 | 비평 2 major/minor | M0의 ②와 ⑥ | 반영 |
| R-12 | validate 3.8 신설이 계약의 "7항목" 문면과 어긋납니다 | 비평 2 major | T045에서는 추가하지 않습니다. 규칙 명세를 T047에 인계합니다. 그 사이의 회귀는 하네스 eso-4와 reboot-4가 잡습니다 | 반영(이월) |
| R-13 | 동결 문면의 `selfsubjectrulesreviews`를 삭제하는 것 | 비평 2 major | 문면대로 유지하고 주석과 계약 각주를 답니다 | 반영 |
| R-14 | data-model.md §8의 grafana-cloud 키를 변경하는 것은 동결 범위입니다 | 비평 2 major | 편집하지 않고, 해당 경로의 시드도 **T098로 이연**합니다(임시 값·sentinel 금지). 불일치는 T098 인계와 converge에 기록합니다 | 확정(이연) — 해소는 T098 |
| R-15 | 임시 파일에 토큰 재료가 남습니다 | 비평 1 minor | 파일 리다이렉트를 전부 없애고 세션 변수로만 다룹니다 | 반영 |
| R-16 | 블록 안의 블로킹 port-forward | 비평 1 minor | 블록 밖 창 C에서 띄우고, 블록의 첫 부분에서 도달 확인 후 `throw`합니다 | 반영 |
| R-17 | Orphan 회귀를 잡는 가드가 없습니다 | 비평 1·2 minor | eso-4는 ES **spec**(`creationPolicy == 'Orphan'`)을 검사합니다. D4 = B′ 확정으로 대상이 **두 ES 모두**입니다. agent-view로 읽을 수 있습니다 | 반영 |
| R-18 | values 오타에 대한 방어선이 없고 digest 검사의 사각지대가 있습니다 | 사실 렌즈 | G1 렌더 grep 게이트를 두고 T047에 인계합니다 | 반영(수동 그물) |
| R-19 | G1~G2r 사이에 전역 `serviceaccounts/token create`가 있고, cert-controller에 전역 secrets read가 있습니다 | 사실 렌즈 | 전자는 G2r로 닫습니다. 후자는 범위 밖이라 report의 잔여 권한에 기록합니다 | 부분 — **후자는 미해결** |
| R-20 | 비밀 사본이 여러 곳에 있습니다: PM, Vault, K8s Secret, `infra/cloudflare` state(`joshuatech-tfstate`) | 사실 렌즈 | 런북 §4에 기록하고 T084에 인계합니다 | **미해결(T084)** |
| R-21 | 콜드 부트스트랩은 Vault init·시드 전까지 store wave에서 멈춥니다. **파생: root가 wave 60의 cloudflared까지 가지 못하므로 터널 Secret과 cloudflared가 자동으로 올라오지 않습니다** | 종합 + D3 조건 3 | 런북 §3 T045 절과 `platform/secrets`·`platform/cloudflared` README에 "터널 Secret·cloudflared는 T039 절차대로 수동 선행, ESO 인수는 Vault 시드 뒤"를 명시합니다. T048이 콜드 부트스트랩을 재현하지 않는다는 점도 기록합니다 | 문서화(VD-11) |
| R-22 | 한 ExternalSecret을 두 Application이 각자 적용해 소유권이 갈립니다(소비자 kustomization이 `secrets/<ns>`를 base로 넣는 경우) | D3 조건 2 | validate 7.3 정적 검사 + 픽스처, 라이브 확인(ES tracking-id = `platform-secrets`, 소비자 Application의 `status.resources`에 ExternalSecret 0건) | 반영(VD-21) |
| R-23 | "webhook 장애 중에도 터널 Deployment를 독립 변경할 수 있다"를 **라이브로** 증명하지 못합니다(webhook을 내리면 selfHeal이 되돌립니다) | D3 조건 5 | T045에서는 구조 검증 2건 + server-side dry-run까지만 판정합니다. 실제 교란 드릴은 T048의 선택 항목으로 인계합니다 | **부분 — 라이브 미검증(T048)** |
| R-24 | Access 4경로와 `grafana-cloud`가 이연되어 **Vault 밖(PM · `infra/cloudflare` state)에만 남습니다** — 운영 복구는 PM 사본에 의존합니다 | D10 확정 | 의도된 이연입니다(권한 범위·전달 절차·소비자 키 집합 미확정). PM 복구 사본을 유지하고, 완료 보고·런북·converge에 이연 범위를 명시합니다 | **잔여(T077·T092·T098)** |
| R-25 | `oci/s3` 키 쌍의 절반이 없어 시드를 건너뛰면 T053 백업 구성이 막힙니다 | D10-③ | 자동 재발급을 금지하고, 별도 발급·교체 작업으로 분리해 "T053 백업 구성 전 완료" 인계 항목으로 남깁니다 | **조건부 잔여(T053)** |

---

## 7. VD 실측 항목

| # | 시점 | 기본 가정 | 명령(누가) | 판정 |
|---|---|---|---|---|
| VD-1 | G1 직후와 G1p 직후 | 노드 A에 배치되어 있으면 kube-router LOCAL 예외로 통과합니다 | (운영자) `kubectl -n external-secrets get pod -o wide`. `kubectl apply --dry-run=server -f platform/secret-stores/clustersecretstore-vault-platform.yaml; echo $LASTEXITCODE`. 노드 A에서 `sudo iptables -S \| grep -c 'src-type LOCAL'` | **판정 기준(D6-③ 교체): 종료 코드 0 + `created (server dry run)` 출력.** "오류 문자열이 없다"는 기준이 아닙니다. G1p 직후의 PASS가 G2의 선행조건입니다(D6-⑤). 두 시점의 결과를 policies 주석과 런북에 기록합니다 |
| VD-2 | G2 직후 | namespace를 명시했으므로 실제 로그인을 합니다 | §5 단계 6의 custom-columns 명령과 로그 grep + spec namespace 4장 조회 | 5행 모두 `True Valid`여야 합니다. `ValidationUnknown`은 불합격입니다(k8s provider 신호). namespace 생략은 `Valid`로 나오므로 spec 조회로 잡습니다(정정 2026-09-18). 메시지별 원인: `invalid audience (aud) claim`(audiences 오기), `cannot find secrets bound to service account`(vault store의 TokenRequest 실패 → 레거시 폴백 — G2r 게이트 신호), `Vault is sealed`(503), 연결 오류(Vault 미기동·egress) |
| VD-3 | G3 직후 | ownerRef 없는 Secret을 제자리에서 인수하고 값·UID가 불변입니다 | §5 단계 9의 블록 | `SecretSynced` · **값 불변 · UID 불변 · ownerReferences 부재**(D4-② — G4와 같은 세 검사). 모두 PASS해야 G4로 갑니다 |
| VD-4 | G4 | Orphan이므로 ownerRef가 없고 값·UID·파드가 불변입니다 | §5 단계 10의 블록 | 모든 `throw`를 통과하고 파드 1개 교체 드릴이 성공해야 합니다 |
| VD-5 | G1 이후 15분 간격 2회 | 희망 상태에 없는 필드이므로 드리프트가 없습니다 | `kubectl -n argocd get app platform-external-secrets -o jsonpath='{.status.sync.status} {.status.health.status}'`. `status.resources` 중 Synced가 아닌 것. (운영자) `external-secrets-webhook`의 `tls.crt` 길이가 0보다 큰지 | 유지되면 ignoreDifferences가 필요 없습니다. 반복해서 OutOfSync가 나면 별도 PR(`/data`, `/webhooks/*/clientConfig/caBundle`)을 엽니다 |
| VD-6 | OP1 블록의 A) | `vault kv put <path> -`는 JSON을 디코드합니다 | 블록에 내장 | 키가 `a,b`여야 합니다. 아니면 `throw`하고 키당 개별 호출 폴백을 설계합니다 |
| VD-7 | G1 전과 후 | Role 없이도 `yes`입니다 | `kubectl api-resources --namespaced=false \| Select-String selfsubject`. `kubectl auth can-i create selfsubjectrulesreviews --as=system:serviceaccount:external-secrets:eso-ca-reader` | 전부터 `yes`이면 계약 각주를 확정하고 converge 편차로 올립니다. `no`→`yes`로 바뀌면 각주를 철회합니다 |
| VD-8 | G3 + 1시간, 2회 | 로그인이 시간당 약 72회(±20)입니다 | (운영자) Vault 파드의 감사 파일 크기와 `auth/kubernetes/login` 건수 | 하루 증가량이 50 MB를 넘으면 캐시 채택이나 회전을 T098과 함께 결정합니다 |
| VD-9 | G1 직후 | kubelet 프로브가 정책을 우회합니다 | webhook 파드의 Ready 조건 | `True`이면 8081 정책이 필요 없습니다. 아니면 정책·계약·PORT 표를 고치는 별도 PR을 엽니다 |
| VD-10 | G2 직후 | `k8s-data-ca`가 `Valid`입니다 | 같은 custom-columns 명령 | 아니면 순서대로 확인합니다: url → caProvider → audiences 없음. 401이면 audiences, x509이면 CA가 원인입니다 |
| VD-11 | 라이브에서는 불가 | ~~콜드 부트스트랩은 … store wave에서 기다립니다~~ **정정(2026-09-18, Argo v3.5.2 소스 판독)**: root는 store wave에서 기다리지 않는다 — 첫 operation만 실패, retry부터 진행, root health만 Degraded. 대기 지점은 wave 10 | 오늘 확인 가능한 것은 `platform-secret-stores`가 Healthy인지뿐입니다 | 런북 §3 T045 절에 "시드 순서는 Argo가 보장하지 않으며 런북 절차로 보장한다"로 명시합니다. T048 기록에는 "이 리허설은 콜드 부트스트랩을 재현하지 않는다"고 적습니다 |
| VD-12 | G1 빌드, bump 때마다 | digest 3줄, CRD 어노테이션 25건 | §5 단계 3. bump 시 ghcr manifests API의 `docker-content-digest` | 기대값과 일치하고 arm64를 포함해야 합니다 |
| VD-13 | G3 빌드 | `platform/secrets`의 교차 base가 렌더됩니다(1개, 2개 모두) | `kustomize build platform/secrets` | rc=0이고 ES의 ns와 creationPolicy가 기대대로여야 합니다. 실패하면 D3의 A로 폴백하고 계약 문면을 다시 고칩니다 |
| VD-14 | OP1 직후(선택) | 구 버전이 읽힙니다. `destroy`는 `current_version`을 0으로 되돌리지 않으므로 그 뒤 `-cas=0` 재투입은 실패합니다(미확인) | 오투입이 있었을 때만 `vault kv get "-version=<N>"`을 실행하고 키 이름만 확인합니다. 이어서 `vault kv metadata get <path>`로 `current_version`을 봅니다 | 읽히면 `kv destroy`까지가 정정 절차입니다. 재투입 방법(`-cas=<current_version>` 또는 `metadata delete` 후 재실행)을 실측 결과에 맞춰 런북에 적습니다 |
| VD-15 | R1이 필요할 때만 | `force-sync` 어노테이션으로 즉시 refresh가 됩니다 | `kubectl -n <ns> annotate externalsecret <name> force-sync=$(Get-Date -UFormat %s) --overwrite` | `refreshTime`이 갱신되는지 봅니다. 안 되면 5분 이내로 기다립니다 |
| VD-16 | G2r + 5분 | store 5장이 `Valid`를 유지합니다 | VD-2와 같은 명령 | 하나라도 실패하면 revert합니다 |
| VD-17 | G3 직후, 2026-11-01 이전 | prod 와일드카드가 Ready이고 renewalTime이 ≈2026-11-08입니다 | `kubectl -n <ns> get certificate <wildcard> -o jsonpath='{.status.conditions[0].status} {.status.renewalTime} {.status.notAfter}'`. 기한 전에 staging 프로브를 1회 다시 돌립니다 | 기준값을 기록합니다. 재프로브가 실패하면 kv와 ES를 점검합니다 |
| VD-18 | G1 직후 | 3개 파드가 노드 A에 있고 PSA 위반이 0입니다 | `get pod -o wide`, `get events --field-selector reason=FailedCreate`, `kubectl top pod` | 위반이 0이어야 합니다. 리소스 실측값은 T097 입력으로 씁니다 |
| VD-19 | G1p 머지 전 | 노드 A의 flannel 출발 주소가 podCIDR의 네트워크 주소(`10.42.0.0`)이고 podCIDR이 `10.42.0.0/24`입니다 | (운영자, 노드 A) `ip -4 -o addr show flannel-wg` · `ip route get <노드 B 파드 IP>`의 `src`(노드 간 경로) · `kubectl get node <A> -o jsonpath='{.spec.podCIDR}'` · 참고 기록: `ip route get <ESO webhook 파드 IP>` · `--src-type LOCAL` 행 · (있으면) conntrack | **`flannel-wg` 장치 주소와 노드 B 파드로 가는 `ip route get`의 `src` 두 값이 일치해야 그 주소로 `/32`를 확정합니다**(같은 노드 경로의 값은 다를 수 있고 중단 사유가 아닙니다)(D6-① · conntrack 사용 여부를 기록). 엇갈리거나 podCIDR이 다르면 중단하고 사용자에게 보고합니다. podCIDR 대조만으로 끝내지 않습니다 |
| VD-20 | DR1(§5 단계 8b) | Secret이 삭제되면 다음 주기(≤5분)에 재생성됩니다. 관리 Secret watch로 **즉시** 재조정될 가능성도 있습니다(미확인) | 드릴 5) 단계: ES 재적용 → `kubectl -n external-secrets delete secret t045-probe` → `kubectl -n external-secrets get secret t045-probe -w` | 재생성이 관측되고 **그 시점**(즉시 / ≤5분)이 기록되어야 합니다. 결과를 런북과 `platform/secrets/README.md`의 재생성 문구에 반영합니다 |
| VD-21 | G3 직후·G4 직후 | 각 ExternalSecret을 관리하는 Application은 `platform-secrets` 하나뿐입니다 | ES의 `argocd.argoproj.io/tracking-id` · `kubectl -n argocd get app platform-cloudflared\|platform-cert-manager-issuers -o jsonpath='{range .status.resources[*]}…'` | tracking-id가 `platform-secrets`이고, 소비자 Application의 `status.resources`에 `external-secrets.io` kind가 **0건**이어야 합니다(D3 조건 2 · R-22) |
| VD-22 | G1p 머지 직전 | `platform/policies`에 대기 중인 다른 변경이 없습니다 | `kustomize build platform/policies \| kubectl diff -f -` | diff가 **external-secrets `allow-apiserver-webhook`의 ipBlock 1줄 추가뿐**이어야 합니다. 다른 diff가 있으면 머지하지 않습니다(D6-② — 머지 = 자동 적용) |
| VD-23 | G3 직후(issuers) · G4 직후(cloudflared) — 구조 검증 | 소비자 Application은 ESO admission에 묶이지 않습니다 | `platform-cloudflared`의 `status.resources`에 `external-secrets.io` kind 0건 · `kubectl get validatingwebhookconfiguration -o jsonpath='…rules…'`(대상이 `secretstores`·`clustersecretstores`·`externalsecrets`뿐) · cloudflared Deployment `kubectl apply --dry-run=server` | 세 가지가 모두 성립해야 D3 조건 5 (b)의 게이트를 통과합니다. **라이브 교란 드릴은 T048 선택 항목**입니다(R-23) |

---

## 8. 테스트·문서 변경 목록

**모노레포 `joshuatech_ver2`**

| 파일 | 변경 |
|---|---|
| `specs/003-platform-foundation/contracts/gitops-repo.md` | M0의 ①~⑦(§5 단계 1) — §sync-wave 표 2행, §디렉터리 열거, `secrets/<ns>` 적용 주체 각주, k8s-data-ca 무효 규칙 각주, §ExternalSecret 규약 5항(Orphan 사용 조건 · Retain의 한계 · `template.metadata` · `refreshPolicy` 명시 · 인수 해제 순서), §워크로드 강화 목록, `secrets/<ns>` 단일 소유 |
| `specs/003-platform-foundation/contracts/hostnames-and-access.md` | `:93`의 break-glass 문면 정정 |
| `specs/003-platform-foundation/contracts/network-policy.md` | **변경 없음**(D6 = A 확정 — 계약이 정본이고 매니페스트를 맞춥니다) |
| `tests/platform/cluster.tests.ps1` | **eso-1 강화.** `status=True` 그리고 `reason=Valid`를 요구합니다. vault store 4개의 `serviceAccountRef.namespace == 'external-secrets'`와 `audiences == ['vault']`를 확인합니다. `k8s-data-ca`의 `remoteNamespace == 'data'`를 확인합니다. 머리 주석(:42-43)을 갱신합니다. **eso-4 신설.** ExternalSecret `cloudflared/cloudflared-tunnel`과 `cert-manager/cloudflare-dns-token`의 `spec.target.creationPolicy == 'Orphan'`을 **둘 다** 검사합니다(D4 = B′). ES spec이므로 agent-view로 가능합니다. **np-set-5 강화(D6-③ — M1: G1p 머지 전에 커밋하고, 머지 전 `external-secrets` 행 FAIL → 머지 후 PASS를 판정으로 씁니다).** 현재는 "아무 `/32` + 포트"만 보므로, webhook 3개 ns(`cert-manager`·`external-secrets`·`cnpg-system`)에 대해 **정확한 두 출발 주소(노드 A private IP `/32` · 노드 A flannel 출발 주소 `/32`)와 ns별 포트**를 요구하도록 바꿉니다. `vault` 8200 행은 private IP만 요구합니다(webhook이 아니라 port-forward 도착 경로). 주소 상수는 파일 머리의 기존 상수 정의 방식을 따릅니다 |
| `tests/platform/reboot.tests.ps1` | 변경 없음(reboot-4가 처음으로 실질 검사가 됩니다) |
| `docs/runbooks/bootstrap.md` | §3에 T045 절을 신설합니다. 내용: PR 사슬과 게이트 출력, **G1p 실측값(flannel 출발 주소)과 VD-22 diff 확인**, VD-1 결과(종료 코드 + `created (server dry run)`), **노드 간 webhook 경로 미실측 한계**, store reason, **DR1 드릴 결과(UID·값·ownerRef·재생성 시점 VD-20)**, 인수 전후 "값·UID 불변" 사실(해시나 값은 적지 않음), 파드 교체 드릴 결과, R1~R3와 **인수 해제 절차(두 ES 공통)**, **콜드 부트스트랩 수동 게이트(터널 Secret·cloudflared 수동 선행)**. §0 토큰 표 ①②를 갱신합니다(Vault 이관, PM은 백업, state 사본 존재). T011의 "Vault 투입은 T043"을 T045로 정정합니다 |
| `docs/runbooks/vault-unseal.md` | §4에 T045 시드 기록을 남깁니다. 내용: 경로, 키 이름, 버전, 출처, 발급일, 만료, 폭발 반경(값 없음), **경로별 완료·보류·이연 요약(블록의 요약 표 그대로)과 재실행 절차**, OP1 블록 전문, kv 입력 규칙(JSON stdin, 문자열만, `key=-` 금지, **최초 쓰기 `-cas=0`**, 10버전 보존과 `destroy`/`metadata delete`의 차이), D4 재확인(root는 revoke하지 않음) |
| `specs/003-platform-foundation/design/t045-design.md`, `build-notes.md` | 본 문서를 보존합니다 |
| `content/tmp/003-t045/<YYYY-MM-DD>.md` | 학습 로그(세션 날짜별 파일 — `.claude/rules/content.md` 형식). 주제: `Owner`는 GC되고 `Orphan`이어도 값은 덮인다는 점(그래서 둘 다 Orphan으로 통일했다는 결론), Ready=True인데 로그인하지 않는 referent auth, 디렉터리만 있고 배달자가 없던 `secrets/`, fail-open 해시 게이트, "머지 = 자동 적용"인 정책 컴포넌트를 "운영자 트리거"로 오해했던 전제 정정 |
| `specs/003-platform-foundation/tasks.md` | T045 체크박스만 수정 |
| report.md(`/finish` 시) | 편차 항목: eso-1 강화, np-set-5 강화, 문면의 무효 규칙, data-model 불일치, store 위치(D2). 잔여 권한: cert-controller의 전역 secrets read. 노출 창: G1~G2r. 잔여 위험: R-10 · R-23 · R-24 · R-25. **이연 범위 명시(D10-④): Access 4경로(T077·T092) · `grafana-cloud`(T098) · (건너뛴 경우) `oci/s3`(T053)** |
| **새 런북 없음** | `secret-rotation.md`와 `break-glass.md`는 T084 산출물입니다 |

**`platform-gitops`**

§4의 파일 트리와 같습니다. `tests/validate.sh`에는 다음이 들어갑니다.

- WAVE_TABLE 2행(`secret-stores 15 external-secrets` · `secrets 18 -`).
- **5.x 신설(webhook 출발 주소 정적 검사, G1p)** — webhook 3개 ns의 ingress `from`이 정확히 두 출발 주소이고 포트가 각주와 같은지. 픽스처 `tests/fixtures/pol-webhook-src/`.
- **7.3 신설(`../../secrets/*` 단일 소유 검사, G3)** — 그 base를 포함하는 kustomization이 `platform/secrets` 하나뿐인지. 픽스처 `tests/fixtures/secrets-base-owner/`.

그 밖의 검사 항목(ES `refreshInterval`·`creationPolicy` 정적 가드, helm repo 허용 목록, 4b 보강)은 계약 §validate.yml의 "7항목" 문면 개정이 선행이라 **T047로 이월**합니다(R-12).

---

## 9. 인계

- **T046(Reloader).**
  - VD-9 롤아웃의 실측 대상(jt-dev의 ES와 Deployment)은 T072·T075 이후에야 생깁니다.
  - 권고는 다음과 같습니다. T046은 Reloader 배포, Available 확인, scoped 확인까지만 합니다. VD-9는 T075 직후에 붙입니다.
  - **감시 ns 목록에 `cloudflared`를 넣지 않습니다.** 터널 Secret 변경이 자동 롤아웃되면 잘못된 값이 곧바로 잠금으로 이어집니다.
- **T047(validate 워크플로).**
  - `helmCharts[].repo` 허용 목록 검사가 필요합니다. 인플레이트 경로에서는 차트 출처가 통제되지 않습니다(세 번째 사례).
  - 4b 보강이 필요합니다. helm values `tag:`의 digest와 3개 트리를 봐야 합니다.
  - **ES 정적 가드 명세**는 다음과 같습니다.
    - `secrets/**`는 `refreshInterval == 5m`이고 `refreshPolicy == Periodic`이어야 합니다.
    - `secrets/**`는 `creationPolicy != Owner`여야 합니다(T045 확정 = 두 ES 모두 `Orphan`. 계약 예시가 `Owner`이므로 §ExternalSecret 규약 문면과 함께 개정합니다).
    - `platform/secrets/kustomization.yaml`만 `../../secrets/*`를 base로 가져야 합니다(T045에서 7.3으로 먼저 넣습니다 — T047은 그 검사를 유지·보강만 합니다).
    - 계약 §validate.yml의 "7항목" 문면을 함께 개정해야 합니다.
  - 약 2 MB 렌더에 대한 diff 코멘트 전략이 필요합니다.
- **T048(재부팅 리허설).**
  - **T045가 완료되기 전에는 실행하지 않습니다.**
  - 재부팅은 cloudflared 전면 교체와 같고, G4의 최종 증명이 됩니다. 리허설 전에 노드 A SSH 세션을 유지합니다.
  - reboot-2와 reboot-4가 처음으로 실질 검사가 됩니다.
  - Vault가 재unseal되는 동안 store가 Ready=False에서 True로 복귀하는 시간을 기록합니다.
  - 그 동안 `platform-secret-stores`·`platform-secrets`가 Degraded가 되고 ESO Application은 Healthy인지 확인합니다.
  - **선택 항목 — ESO webhook 교란 드릴(D3 조건 5 b · R-23).** T045에서는 구조 검증 2건 + dry-run까지만 했습니다. 계획된 교란 창에서 webhook을 실제로 내리고(`selfHeal` 때문에 **PR로만** 가능합니다) 그 동안 `platform-cloudflared`의 sync와 Deployment 변경이 통과하는지 확인합니다. 드릴 뒤 즉시 되돌립니다.
  - SC-001 기록에 "콜드 부트스트랩 미재현"을 명시합니다. 콜드 부트스트랩에서는 터널 Secret·cloudflared가 수동 선행이라는 점(R-21)도 함께 적습니다.
- **T052(CNPG).**
  - `cnpg-system` webhook의 dial 프로브는 VD-1 선례를 그대로 복제합니다(판정 기준도 같습니다 — 종료 코드 0 + `created (server dry run)`).
  - barman-cloud 배선 전에 `kv/platform/oci/s3`의 시드 여부를 확인합니다.
  - 첫 백업 전에 S3 호환 엔드포인트로 자격을 확인합니다.
- **T053(백업 구성) — OCI S3 자격(D10-③ · R-25).**
  - T045 OP1에서 `kv/platform/oci/s3`를 건너뛴 경우, **T053 백업 구성 전에** 별도 발급·교체 작업으로 완료해야 합니다.
  - T045는 키 쌍의 절반이 없어도 **자동 재발급하지 않습니다**(기존 키가 다른 곳에서 쓰이고 있을 수 있습니다). 발급·교체는 영향 범위를 확인한 뒤 독립 작업으로 진행합니다.
  - 완료 시 시드 방법은 OP1 블록의 C) 단계와 같습니다(`-cas=0` · 되읽기 해시 비교).
- **T056(CA 미러).**
  - store와 Role은 이미 Ready입니다. 대상 Secret이 없어도 Valid입니다.
  - 미러 ES는 `property: ca.crt`만 쓰고 `dataFrom`은 금지입니다.
  - 미러 ES는 `platform/secrets`가 **아니라** 계약 §sync-wave 표 40번 행(`cnpg-databases`·`kafka-topics`) 소유입니다(D3 조건 1). 원본 CA가 생긴 뒤에 놓입니다. `platform/secrets`로 옮기려면 **원본과 소비자의 wave를 먼저 확인**하고 계약 표를 고친 뒤에 합니다.
  - ca-1은 그때까지 SKIP(`until T056`)이 정상입니다.
- **T072·T075.**
  - `vault-dev`와 `vault-prod` store, `refreshInterval: 5m`, `template.metadata` 규약이 확정되었습니다.
  - 앱 ES는 `apps/<pod>/overlays/<env>`에 둡니다. `secrets/` 규칙은 플랫폼 ns에만 적용됩니다.
  - VD-9 실측을 여기에 붙입니다.
- **T077.**
  - `kv/platform/access/tester-{m2m,k8s}`는 **T045에서 시드하지 않았습니다**(D10-② 이연 · R-24). Vault에는 없습니다. 사본은 PM과 `infra/cloudflare` state(`joshuatech-tfstate`)에 있으며, 독립적인 PM 복구 사본을 유지합니다(D10-②).
  - 시드 전에 확정해야 할 것: `eso-platform` role의 읽기 범위(`kv/data/platform/*`)에 이 경로가 들어간다는 점을 감안한 권한 설계와, tester의 취득·전달 경로.
- **T084(회전, root revoke).**
  - dns 토큰과 터널 토큰이 PM, Vault, K8s Secret, `infra/cloudflare` state의 **4곳**에 있습니다.
  - dns 토큰은 존 전체의 DNS 쓰기·삭제 권한을 가집니다.
  - Access 토큰은 1년 만료입니다(60일 전에 회전합니다).
  - 터널 회전 절차는 "kv 교체 → ES refresh → 한 replica씩 수동 재시작 + 등록 확인"입니다.
  - 구 버전은 `kv destroy`로 지웁니다.
  - PM과 라이브의 동일성을 점검합니다.
  - `break-glass.md`를 작성합니다(M0에서 정정한 계약 문면이 입력입니다).
  - root revoke는 여기서 합니다(ADR 0010 §6 ⑥ 정정).
- **T092.**
  - `kv/{dev,prod}/access/web-bff`는 **T045에서 시드하지 않았습니다**(D10-② 이연 · R-24). 이 경로는 `eso-dev`/`eso-prod` role의 읽기 범위(`kv/data/{env}/*`)에 들어가므로, 권한 범위를 확정한 뒤 시드합니다.
  - 시드하려면 root 창을 한 번 더 엽니다(OP1 블록의 `$seed` 헬퍼를 그대로 씁니다 — `-cas=0` · 되읽기 해시 비교).
- **T098(monitoring).**
  - ESO에 metrics Service가 없습니다(`metrics.service.enabled: false`). discovery 방식에 따라 PR이 필요합니다.
  - **`kv/platform/grafana-cloud`의 키 집합이 data-model §8(4키)과 소비자(R10의 instance id)에서 다릅니다.** T045는 시드하지 않았습니다(D10-④ · R-14 · R-24). **T098이 실제 소비자(Alloy) 기준으로 키 집합을 확정한 뒤, T098 착수 전에 시드**합니다. 임시 값·sentinel은 넣지 않습니다.
  - cloudflared metrics 2000번 포트와 cert-manager 갱신 실패에 대한 알림이 필요합니다(R-10의 상시 대책).
  - VD-8의 증가량을 Loki 용량 산정의 입력으로 씁니다.
- **converge.**
  1. ADR 0010 §6 ⑥("시드 후 root 즉시 revoke")이 D4와 다릅니다.
  2. tasks.md T045 문면의 `selfsubjectrulesreviews` Role 규칙이 실효가 없습니다(VD-7 결과를 첨부합니다).
  3. data-model §8의 grafana-cloud 키가 불일치합니다.
  4. eso-1 판정을 강화했습니다(T031 문면보다 엄격합니다). `np-set-5`도 강화했습니다(D6-③).
  5. store 5개가 task 문면의 `platform/external-secrets/`가 아니라 `platform/secret-stores/`에 놓였습니다(D2).
  6. AppProject destinations의 jt-dev·jt-prod 모순이 남아 있습니다(T041 인계).
  7. cert-controller의 전역 secrets read가 남아 있습니다(후속 하드닝 후보).
  8. **DNS ExternalSecret의 `creationPolicy`가 계약 예시의 `Owner`가 아니라 `Orphan`입니다**(D4 = B′ — 인수 해제 절차를 두 ES 공통으로 두기 위함. M0에서 계약 §ExternalSecret 규약에 근거를 넣습니다).
  9. **시드 범위를 tasks 문면보다 좁혔습니다**(Access 4경로 → T077·T092, `grafana-cloud` → T098, `oci/s3`는 조건부 — D10 · R-24 · R-25).
  10. "webhook 장애 중 소비자 Application 독립 변경"은 구조 검증까지만 했고 라이브 드릴은 T048로 넘겼습니다(R-23).
