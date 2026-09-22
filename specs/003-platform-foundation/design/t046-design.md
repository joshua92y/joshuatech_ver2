# T046 설계 — Stakater Reloader(scoped 모드) + VD-9 실측

작성 2026-09-22. 과제 문면은 `tasks.md` T046 줄이 정본이고, 이 문서는 조사 결과·결정·실행 순서를 담는다.

## 1. 조사로 확정한 사실

| # | 사실 | 근거 |
|---|---|---|
| F1 | 차트 2.2.16에 **scoped 모드**가 있다. `watchGlobally: false` + `namespaces: [...]`면 나열한 ns마다 Role + RoleBinding을 만들고 **ClusterRole을 만들지 않는다**. 릴리스 ns는 자동으로 포함된다. `watchGlobally: true`와 `namespaces`를 함께 주면 렌더가 `fail`한다 | 차트 `values.yaml` 47–55행 · `templates/role.yaml` |
| F2 | 바이너리 v1.4.21이 `--namespaces` 목록을 받으면 **정확히 그 ns만** 감시한다(global 아님) | `stakater/Reloader@v1.4.21` `internal/pkg/cmd/reloader.go` `resolveWatchNamespaces` |
| F3 | 후보 values 렌더 = 12개: SA 1 · Deployment 1 · Role 5(`identity`·`jt-dev`·`jt-prod`·`reloader` 각 `reloader-role` + `reloader/reloader-metadata-role`) · RoleBinding 5 · **ClusterRole 0**. 인자 `--namespaces=identity,jt-dev,jt-prod,reloader` · `--reload-strategy=annotations` | `helm template`(차트 tgz sha256 `5389fb49…74d2b7`) |
| F4 | 감시 ns의 Role 규칙: secrets·configmaps `get/list/watch` · apps deployments/daemonsets/statefulsets `get/list/update/patch` · batch cronjobs `get/list` · **batch jobs `create/delete/get/list`** · events `create/patch`. jobs·cronjobs 규칙은 **values와 무관하게 항상** 렌더된다 | 차트 `_helpers.tpl` `reloader-namespaced-rules` |
| F5 | 차트 기본값 `watchGlobally: true` — values 오타가 전역 모드로 되돌릴 수 있다(values 스키마에 `additionalProperties: false` 없음). **정정(G1 실측 2026-09-22)**: `watchGlobally` 한 키 오타(`watchGlobaly`)는 `namespaces`가 남아 차트 `role.yaml` 가드가 렌더를 `fail`시킨다(Argo `ComparisonError` — 시끄러운 실패). **조용히** 전역 모드 + ClusterRole이 되는 것은 부모 키 `reloader:` 오타처럼 두 설정이 함께 빠질 때다. 렌더 결과 검사가 유일한 방어선이라는 결론은 같다 | T045 G1 교훈과 같은 종류 · gitops 픽스처 `rel-scoped/typo-key`·`typo-parent` |
| F6 | 이미지 `ghcr.io/stakater/reloader:v1.4.21` 인덱스 digest `sha256:b253579350a835082cdad8d8736671cedaa0f8309437c894bd1bf1c2f0e0d45e`(linux/arm64 포함) | ghcr.io 레지스트리 API |
| F7 | 보안 설정: 파드 `runAsNonRoot`·`runAsUser 65534`·`seccompProfile RuntimeDefault`, 컨테이너 `allowPrivilegeEscalation false`·`capabilities.drop [ALL]`·`readOnlyRootFilesystem true`(emptyDir `/tmp`) — PSA restricted 충족. 포트 9090(metrics·프로브) | 렌더 |
| F8 | Argo는 **Server-Side Diff 전역**(`controller.diff.server.side: "true"`) + 모든 Application SSA. 다른 field manager가 넣은 필드는 드리프트로 보지 않는다 → 이론상 Reloader의 파드 템플릿 수정을 selfHeal이 되돌리지 않는다. **이것이 VD-9가 실측할 대상이다** | `bootstrap/argocd/argocd-cmd-params-cm.yaml` |
| F9 | `platform-reloader` Application: `prune: false` · `selfHeal: true` · SSA · AppProject `platform`(ns 제한 없음 · destinations 14 ns) | `clusters/oci-k3s/apps/platform-reloader.yaml` |
| F10 | agent-view는 Deployment·ReplicaSet·이벤트·파드 로그·Application을 읽을 수 있고 **ClusterRole·Role·Secret은 읽지 못한다** | `kubectl auth can-i` |
| F11 | 네트워크: `reloader` ns는 `allow-kube-api`(6443)만 필요하고 이미 있다(T041). metrics 수집 행은 매트릭스에 없다 → Service·ServiceMonitor·PodMonitor·차트 NetworkPolicy 모두 끈다(차트 기본값도 off) | 계약 `network-policy.md` |

## 2. 결정

| # | 결정 | 근거 |
|---|---|---|
| D1 | **scoped 모드** — `watchGlobally: false` + `namespaces: [identity, jt-dev, jt-prod]` | 실제 소비자: T080 authentik · T082 openfga(`identity`), T072 파드 템플릿(`jt-dev`·`jt-prod`). **`cloudflared`는 넣지 않는다** — 터널 커넥터는 수동 교체가 안전장치다(T045 G4). 새 소비자 ns는 이 목록과 계약에 한 줄 추가로 늘린다 |
| D2 | `reloadStrategy: annotations` | GitOps 환경 권장 방식(파드 템플릿 어노테이션 `reloader.stakater.com/last-reloaded-from`만 바뀐다 — 컨테이너 env를 건드리지 않는다). F8로 두 방식 모두 이론상 드리프트가 없으며, VD-9가 실측한다 |
| D3 | 권한은 **차트 기본값 유지**(테넌트 ns의 Job `create` 포함) | Reloader가 반드시 가져야 하는 `patch deployments`만으로도 같은 ns에서 임의 코드를 실행할 수 있다(이미지·명령 교체). Job `create`는 위험 수준을 올리지 않는다. 감시 ns의 모든 Secret을 읽는다는 사실과 함께 README·완료 보고에 적는다 |
| D4 | **VD-9 = Argo가 관리하는 시험 Deployment**(사용자 결정 2026-09-22) | 실제 소비자와 같은 구조(Argo 관리 Deployment + Argo 밖에서 값이 바뀌는 Secret)라야 "Argo가 Reloader의 수정을 되돌리지 않는가"를 볼 수 있다. 과제 문면의 "`jt-dev` ExternalSecret patch"는 지금 대상이 없어 Secret patch로 바꾼다 — ESO→Secret 갱신은 T045 DR1에서 이미 실측했고, Reloader는 Secret의 출처와 무관하게 Secret 변경을 본다(편차로 기록) |
| D5 | 이미지 `tag@digest` 병기 — `v1.4.21@sha256:b2535793…0d45e` | 계약 §이미지 |
| D6 | 정적 가드: gitops `validate.sh`에 `platform/reloader` 렌더 검사(ClusterRole·ClusterRoleBinding 0 · Deployment `--namespaces` 집합 = 계약 목록 + `reloader` · `--reload-strategy=annotations`) + 라이브 가드: 하네스 `reloader-2`(Application `status.resources`에 ClusterRole·ClusterRoleBinding 0 · Deployment 인자 집합) | F5 — 오타 한 글자가 조용히 전역 모드로 되돌린다 |

## 3. VD-9 시험 대상과 판정

- **시험 대상**(gitops `platform/reloader/vd9-probe/`, 일시): Deployment `vd9-probe`(ns `jt-dev`) — `registry.k8s.io/pause`(digest 고정) · replicas 1 · 어노테이션 `reloader.stakater.com/auto: "true"` · `envFrom.secretRef: vd9-probe` · restricted 보안 설정 · `automountServiceAccountToken: false` · requests/limits 최소(jt-dev LimitRange·ResourceQuota 안).
- **Secret `vd9-probe`는 Git에 두지 않는다**(비밀이 아닌 더미 값이지만 저장소 규약상 Secret 매니페스트 금지) — 운영자가 **머지 전에** `kubectl create secret generic`으로 만든다. 이 Secret은 Argo 밖에서 바뀌므로 실제 소비자의 "ESO가 쓴 Secret"과 같은 위치다.
- **판정(전부 만족해야 PASS)**
  1. 머지 뒤 기준: `vd9-probe` revision `1` · Available · 파드 템플릿에 `last-reloaded-from` 없음 · `platform-reloader` Synced/Healthy(`.status.sync.revision` = 머지 커밋).
  2. 운영자가 Secret 값을 한 번 바꾼다.
  3. **롤아웃 정확히 1회**: revision `1 → 2`, 이후 5분 관찰 동안 `3` 없음 · ReplicaSet 2개(옛 것 0 replicas).
  4. **Argo Synced 유지**: 5분 동안 `platform-reloader` Synced/Healthy · operation history에 selfHeal 동기화 0건 추가.
  5. 파드 템플릿 어노테이션 `reloader.stakater.com/last-reloaded-from` 존재(annotations 전략 동작 증거) · Reloader 로그에 해당 Secret 재적재 1줄.
  6. ClusterRole 0(Application `status.resources`) · Reloader 시작 로그가 scoped 목록을 보고.
- **실패 시**: ③에서 revision이 3 이상이면 Argo와 충돌한 것 → `reloadStrategy: env-vars`로 바꿔 재측정하거나 `ignoreDifferences`를 검토(결정은 사용자). ⑥에서 감시가 안 되면 과제의 **옵션 B**(`watchGlobally: true` + `namespaceSelector`, ClusterRole이 남는 트레이드오프)로 전환하고 `report.md`에 기록.
- **뒷정리**: 제거 PR(시험 대상 한 줄 삭제) → `prune: false`라 Git 제거만으로는 남는다 → 운영자가 Deployment·Secret `vd9-probe`를 지운다.

## 4. 순서

`M0`(계약) → `M1`(하네스 `reloader-2` 신설 — 테스트 선행, 배포 전 FAIL) → `G1`(gitops PR: 차트 인플레이트 + 시험 대상 + validate 렌더 가드 + README) → 운영자: Secret 생성 → 머지 → 판정 1 → Secret 값 변경 → 5분 관찰(판정 3–6) → `G2`(제거 PR) → 운영자 뒷정리 → 런북·학습 로그 → T046 체크.

## 5. 되돌리기

Reloader 자체의 되돌리기 = revert PR + (`prune: false`) 운영자가 Deployment·SA·Role·RoleBinding(4 ns)을 지운다. Reloader가 없어도 소비자 파드는 멈추지 않는다 — Secret 변경 시 재시작만 일어나지 않을 뿐이다(지금과 같은 상태).

## 6. 진행 상태(2026-09-22 세션 종료 시점 — 재개 지점)

| 단계 | 상태 |
|---|---|
| M0 계약 + 설계 | 완료 — `378f7f6`, F5 정정 `73e47a8` |
| M1 하네스 `reloader-2` | 완료 — `42f3cd5`(shim 19경우 RED→GREEN · 라이브는 배포 전이라 기대 FAIL) |
| G1 gitops 빌드 | 완료 — 렌더 13개 · ClusterRole 0 · validate PASS 25 · 자기검사 49/0 · gitleaks 0 · AppProject stakater 줄 삭제 포함 |
| G1 독립 리뷰 | **APPROVED** + low 5건(① 10 REL이 다른 이름의 Deployment·두 번째 컨테이너·`command`를 안 봄 ② 인자 안 개행 뒤를 안 읽음 ③ "뒤 값이 이긴다" 오기 — pflag StringSlice는 **합친다** ④ README 판정 ⑥이 빈 출력을 PASS로 읽음 ⑤ Secret 없이 머지하면 약 10분 뒤 root health까지 Degraded인데 "파드만 멈춘다"로 서술) |
| low 5건 반영 | **도중 중단(19:20)** — 부정 픽스처 4종(`tests/fixtures/rel-scoped/{second-deploy,command,second-container,args-newline}`) · positive `rbac.yaml` · README·주석 일부까지. **남은 것**: `tests/validate.sh` 10.4(렌더 전체 Role·RoleBinding ns 집합 = 목록 + `reloader` · Reloader 이미지 컨테이너 정확히 1개 · `command` 없음) · 개행 처리 · 메시지 정정 · `validate.tests.sh` 등록 · README ⑥·Secret 부재 서술 완성 · 적대적 검증 |
| 체크포인트 | gitops 브랜치 **`t046-reloader` = `dbd7651`(WIP, 원격 푸시 · PR 없음 · 머지 금지)** — 렌더는 리뷰 시점과 바이트 동일 |
| 운영자 선행 | 시험 Secret `jt-dev/vd9-probe`(키 `probe=v1`) **생성 완료** 2026-09-22 09:51:42Z — 다음 단계까지 그대로 둔다 |

**재개 순서**: 브랜치 `t046-reloader`에서 low 5건의 남은 부분 반영(리뷰 산출물: 세션 스크래치패드 `t046-review/` — 세션이 바뀌면 없으므로 이 표의 요약으로 재현) → validate PASS · 자기검사 전체 · 렌더 바이트 동일 · gitleaks → squash 대상 PR 생성 → 사용자 머지 → 판정 ①·⑥(agent-view) → 사용자 Secret 값 변경(`kubectl -n jt-dev patch secret vd9-probe --type merge -p '{"stringData":{"probe":"v2"}}'`) → 5분 관찰 판정 ③④⑤ → 제거 PR + 운영자가 Deployment·Secret `vd9-probe` 삭제 → 런북·학습 로그 → T046 체크.
