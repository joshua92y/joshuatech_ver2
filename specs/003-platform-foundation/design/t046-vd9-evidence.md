# T046 VD-9 실측 증거 (2026-09-28)

> 내부 작업 자료. 판정과 해석은 `t046-design.md` §8과 런북 `docs/runbooks/bootstrap.md` §3 T046 절에 있다. 이 파일은 출력 원문을 보존한다.
> 정리한 것: 셸 프롬프트와 로컬 경로를 뺐고, 어노테이션 값 안의 Secret 데이터 해시는 `<sha1>`로 바꿨다(더미 값의 해시지만 옮기지 않는다). 시각은 표기가 없으면 UTC다.

## 1. 대상

- gitops main `f5a2d86f21020399322570f3cafed773f50c2a6f`(PR #31 squash, 머지 08:34:44Z)
- Argo 자동 동기화 08:42:58Z(`status.history` id 0 · `initiatedBy.automated=true`)
- 그 직후의 operation(08:42:59Z): `operation.sync.resources` = Deployment `vd9-probe` · Deployment `reloader`, `autoHealAttemptsCount=1`, phase `Succeeded`, message `successfully synced (all tasks run)`

## 2. 판정 ① — 기준(agent-view · 08:43:44Z)

```text
app=Synced/Healthy/f5a2d86f21020399322570f3cafed773f50c2a6f rev=1 available=True last-reloaded-from=[]
baseHistMax=0 baseOpStart=2026-09-28T08:42:59Z baseAuto=[true] baseHeal=[1]
```

## 3. 판정 ⑥ — 권한·감시 범위(agent-view · 08:44:01Z)

```text
Role = 5 (기대 5) OK
RoleBinding = 5 (기대 5) OK
Deployment = 2 (기대 2) OK
ServiceAccount = 1 (기대 1) OK
ClusterRole = 0 (기대 0) OK
ClusterRoleBinding = 0 (기대 0) OK
합계 = 13 (기대 13 — 표 밖의 kind가 있거나 빠지면 FAIL) OK
scoped = 1 (기대 1) OK
all-ns = 0 (기대 0) OK
controller = 8개 [configmaps/identity configmaps/jt-dev configmaps/jt-prod configmaps/reloader secrets/identity secrets/jt-dev secrets/jt-prod secrets/reloader] (기대 8 = configmaps·secrets × identity·jt-dev·jt-prod·reloader) OK
```

Application `status.resources`(13행, 전부 `Synced`): ServiceAccount `reloader/reloader` · Deployment `jt-dev/vd9-probe` · Deployment `reloader/reloader` · Role `reloader-role` × `identity`·`jt-dev`·`jt-prod`·`reloader` · Role `reloader/reloader-metadata-role` · RoleBinding `reloader-role-binding` × 같은 4 ns · RoleBinding `reloader/reloader-metadata-role-binding`.

Application 조건: `OrphanedResourceWarning — Application has 1 orphaned resources`(08:43:04Z). ns `reloader`의 ConfigMap = `kube-root-ca.crt` · `reloader-meta-info`.

컨테이너: 이름 `reloader` 1개 · 인자 `["--log-level=info","--namespaces=identity,jt-dev,jt-prod,reloader","--reload-strategy=annotations"]` · 이미지 `ghcr.io/stakater/reloader:v1.4.21@sha256:b253579350a835082cdad8d8736671cedaa0f8309437c894bd1bf1c2f0e0d45e`.

시작 로그(24줄, 08:43:03Z): `Environment: Kubernetes` → `CSI provider is not installed` → `Starting Reloader` → `Watching scoped namespaces: identity, jt-dev, jt-prod, reloader` → ns마다 `created controller for: configmaps` · `Starting Controller to watch resource type: configmaps in namespace: <ns>` · `created controller for: secrets` · `Starting Controller to watch resource type: secrets in namespace: <ns>` · `Skipping secretproviderclasspodstatuses controller: EnableCSIIntegration is disabled`.

## 4. 단계 2·3 — 운영자 실행(PowerShell 7.6.6 · admin kubeconfig)

```text
secret/vd9-probe patched
t0=2026-09-28T18:11:41.3640840+09:00
probe=djI=
18:13:29 rev=2 app=Synced/Healthy opStart=2026-09-28T08:42:59Z
18:14:07 rev=2 app=Synced/Healthy opStart=2026-09-28T08:42:59Z
18:14:45 rev=2 app=Synced/Healthy opStart=2026-09-28T08:42:59Z
18:15:22 rev=2 app=Synced/Healthy opStart=2026-09-28T08:42:59Z
18:16:00 rev=2 app=Synced/Healthy opStart=2026-09-28T08:42:59Z
18:16:37 rev=2 app=Synced/Healthy opStart=2026-09-28T08:42:59Z
vd9-probe-6f47889d74 replicas=1 rev=2
vd9-probe-6fcb55d445 replicas=0 rev=1
last-reloaded-from=[{"type":"SECRET","name":"vd9-probe","namespace":"jt-dev","hash":"<sha1>","containerRefs":["pause"],"observedAt":1790586701}]
opStart=2026-09-28T08:42:59Z (기준 2026-09-28T08:42:59Z) OK — 관찰 중 새 operation 없음
autoHealAttemptsCount=[1] (기준 [1]) · initiatedBy.automated=[true] (기준 [true]) — 빈 값 = 0·false(omitempty)
histMax=0 (기준 0) OK — 전체 동기화가 끼어들지 않았다(보조 확인)
time="2026-09-28T09:11:41Z" level=info msg="Changes detected in 'vd9-probe' of type 'SECRET' in namespace 'jt-dev'; updated 'vd9-probe' of type 'Deployment' in namespace 'jt-dev'"
표본 = 6개 · 첫 표본 t0+108s · 마지막 표본 t0+296s (기대 6개 이상 · 60초 이내 · 240초 이상) FAIL
③ 마지막 rev = 2 (기대 2) OK
③ ReplicaSet = 2개 · rev 1의 replicas = [0] (기대 2개 · 0) OK
④ sync = Synced 표본 6/6 (기대 전부) OK
④ 마지막 health = Healthy (기대 Healthy) OK
⑤ last-reloaded-from 있음 (기대 비어 있지 않음) OK
⑤ 재적재 로그 줄 = 1 (기대 1) OK
```

표본 시각은 KST다. `observedAt` 1790586701 = 2026-09-28T09:11:41Z.

## 5. 보조 관찰 — agent-view · 읽기 전용 · 10초 간격

08:46:57Z부터 연속 실행(두 프로세스가 겹쳐 돌았다 — 아래 수치는 시각으로 중복을 뺀 것). 유효 표본은 09:50:56Z까지다 — 09:51:06Z에 조회 토큰(8시간)이 만료돼 그 뒤 119표본은 `Unauthorized`였다. 판정 구간 09:11:07Z–09:17:22Z(t0 − 34초 ~ t0 + 341초) 집계:

| 항목 | 값 |
|---|---|
| 표본 수 · 조회 실패 | 38 · 0 |
| Deployment revision | `1` 4표본(09:11:07–09:11:37) → `2` 34표본(09:11:47–09:17:22). `3` 없음 |
| Deployment 상태 | 전 표본 `updatedReplicas=1` · `availableReplicas=1` · `unavailableReplicas` 빈 값 |
| Application | 전 표본 `Synced/Healthy` · `opStart=2026-09-28T08:42:59Z` · `phase=Succeeded` · `heal=1` · `rev=f5a2d86…` |
| `last-reloaded-from` | revision `1` 표본에서 빈 값 → revision `2` 표본에서 값 있음(전부 같은 값) |

구간 밖의 표본도 같다.

| 구간 | 표본 · 조회 실패 | 값(전 표본 동일) |
|---|---|---|
| 변경 전 08:46:57Z–09:11:37Z(대조군 · 약 25분) | 204 · 0 | `rev=1` · `Synced/Healthy` · `opStart=2026-09-28T08:42:59Z` · `heal=1` |
| 변경 뒤 09:11:47Z–09:50:56Z(약 39분) | 232 · 0 | `rev=2` · `Synced/Healthy` · `opStart=2026-09-28T08:42:59Z` · `heal=1` |

즉 5분 창이 아니라 **변경 뒤 39분 동안** 추가 롤아웃과 새 operation이 없었다.

전환 부근 원문:

```text
2026-09-28T09:11:37.544Z rev=1 app=Synced/Healthy|opStart=2026-09-28T08:42:59Z|phase=Succeeded|heal=1|rev=f5a2d86f21020399322570f3cafed773f50c2a6f
2026-09-28T09:11:47.819Z rev=2 app=Synced/Healthy|opStart=2026-09-28T08:42:59Z|phase=Succeeded|heal=1|rev=f5a2d86f21020399322570f3cafed773f50c2a6f
2026-09-28T09:11:57.843Z rev=2 app=Synced/Healthy|opStart=2026-09-28T08:42:59Z|phase=Succeeded|heal=1|rev=f5a2d86f21020399322570f3cafed773f50c2a6f
```

## 6. 관찰 창 종료 뒤 조회(agent-view · 09:18Z)

```text
vd9-probe-6f47889d74 replicas=1 ready=1 rev=2 created=2026-09-28T09:11:41Z
vd9-probe-6fcb55d445 replicas=0 ready= rev=1 created=2026-09-28T08:42:59Z
vd9-probe-6f47889d74-6crsq phase=Running start=2026-09-28T09:11:41Z restarts=0
Synced/Healthy|hist=0|opStart=2026-09-28T08:42:59Z|heal=1|auto=true
reconciledAt=2026-09-28T09:18:18Z|sync=Synced|health=Healthy|healthChanged=2026-09-28T09:11:42Z
```

Deployment `vd9-probe`의 `managedFields`:

```text
argocd-controller|Apply|2026-09-28T08:42:59Z
Reloader|Update|2026-09-28T09:11:41Z
k3s|Update|2026-09-28T09:11:42Z
```

ns `jt-dev` 이벤트(09:11:41Z–09:11:42Z): Deployment `Reloaded` 1 · `ScalingReplicaSet` scale up 1(새 ReplicaSet 0 → 1) · scale down 1(옛 ReplicaSet 1 → 0) · 새 파드 `Pulled`(이미지 이미 있음) → `Created` → `Started` · 옛 파드 `Killing`.

## 7. 원본 파일의 위치

로컬(저장소의 gitignore된 폴더): `.superpowers/t046-wrapup/vd9-live/` — `sampler.log` · `sampler2.log` · `window.log` · `step1.out.txt` · `judge6.out.txt` · 실행한 스크립트(`step1.ps1` · `judge6.ps1` · `op-step2.ps1` · `op-step3.ps1` · `sampler.ps1`). 임시 폴더의 사본은 정리로 사라질 수 있다.
