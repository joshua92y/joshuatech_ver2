# T045 G4 빌더 슬라이스 — platform-gitops: `secrets/cloudflared` ExternalSecret(터널 토큰 인수 · 잠금 위험) (커밋 금지)

## 역할·범위
- 저장소 `D:\code\platform-gitops`, 브랜치 `t045-g4-tunnel-secret`(컨트롤러가 `main` = `22f96c3`에서 만들어 둔다). **git add/commit/switch/stash/push/checkout 금지.**
- 라이브(2026-09-21): G3 완료 — `platform/secrets` → Application `platform-secrets`가 `secrets/cert-manager`의 DNS 토큰 ES를 적용해 인수 성공(값·UID 불변 · ownerRef 없음 · Argo tracking 미복사). kv `kv/platform/cloudflare/tunnel` 필드 `token` version 1(라이브 Secret에서 파이프 복사, 되읽기 해시 일치, 형식 판정 base64-JSON{a,t,s} = True). 라이브 Secret `cloudflared/cloudflared-tunnel`의 키 = **`TUNNEL_TOKEN` 하나**. `platform/cloudflared`는 Deployment replicas 2(노드당 1, anti-affinity) — 토큰은 **파드 시작 시에만** 읽는다(env). 이 Deployment에는 reloader 어노테이션이 없다.
- ⚠ **이 Secret은 SSH·K8s API의 유일한 접근 경로(터널)의 자격이다.** 틀린 값으로 덮이고 파드가 교체되면 운영자가 잠긴다. 실행 중 파드는 옛 값을 env로 들고 있어 Secret이 바뀌어도 즉시 끊기지는 않는다 — "파드를 재시작하지 않는다"가 안전망이다.
- 만드는/고치는 것:
  1. `secrets/cloudflared/kustomization.yaml` + `secrets/cloudflared/externalsecret-cloudflared-tunnel.yaml`(신규) — 설계 스냅샷 §4.9 기준. **G3의 `secrets/cert-manager/externalsecret-cloudflare-dns-token.yaml`과 같은 정책·같은 주석 품질**: `Orphan` · `Retain` · `Periodic` · `5m` · `target.template.metadata: {}` · store `ClusterSecretStore/vault-platform` · `target.name: cloudflared-tunnel` · `data[].secretKey: TUNNEL_TOKEN` ← `remoteRef {key: platform/cloudflare/tunnel, property: token}` · `argocd.argoproj.io/sync-options: Delete=false,Prune=false`(범위 한정 주석).
  2. `platform/secrets/kustomization.yaml` — `resources`에 `../../secrets/cloudflared` 1줄 추가(G3가 남긴 G4용 주석 줄을 살린다).
  3. 문서: `platform/secrets/README.md`(범위 = ES 2장 · §2 게이트를 터널 ES에도 — 단 **터널 쪽 운영자 블록의 정본은 모노레포 `specs/003-platform-foundation/design/t045-blocks/`의 G4 블록(검수 중)과 런북**이라고 가리키고 README에는 판정 항목만: ES `SecretSynced` · 값 해시 불변 · UID 불변 · ownerReferences 없음 · **파드 이름/restartCount 불변** · tracking-id = `platform-secrets` · `platform-cloudflared`의 `status.resources`에 `external-secrets.io` 0건 · 그 뒤 **파드 1개만** 교체하는 드릴 · `rollout restart` 금지) · §5 revert 모양(ES 2장이므로 "그 줄만 지운다"가 성립 — 1장 남을 때의 `resources: []` 규칙 유지) · `secrets/README.md`(터널 행을 "있음"으로) · `platform/cloudflared/README.md` ⑨(G0에서 임시 정정문을 넣어 둔 절 → **최종 문면**: 인수 완료 사실 · 회전 절차 = kv 값 먼저(모노레포 런북 정정 블록) → ESO 반영(≤5분) 확인 → 파드를 **1개씩** 수동 교체(반대쪽 커넥터가 살아 있는 동안) · Secret만 바꾸면 5분 안에 kv 옛 값으로 복귀 · 콜드 부트스트랩은 수동 Secret + cloudflared 먼저(T039), ESO는 Vault 시드 뒤 인수) · `platform/external-secrets/README.md` §8과 `platform/secret-stores/README.md` §4의 G4 항 완료 표기 · `clusters/oci-k3s/apps/README.md`의 platform-secrets 행(ES 2장).
  4. 테스트: positive 픽스처에 두 번째 ns가 필요하면 최소 보강. `bash tests/validate.sh`에서 검사 3(ES ①–⑦ — 특히 3.2 scope↔위치: `secrets/**` → `platform/` 접두 + `vault-platform`)·3.6(cloudflared automount — 기존 검사가 ES 추가로 달라지지 않는지)·7.3(secrets/<ns> 2개 모두 배달자 포함)이 PASS.
- **만들지 않는 것**: 운영자 블록(PowerShell) — 컨트롤러가 별도 워크플로로 검수한다. `platform/cloudflared`의 매니페스트는 **건드리지 않는다**(렌더 바이트 동일 — README만).
- 정본 스냅샷: `C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-design-snapshot.md`(§4.9 · 단계 10). **스냅샷보다 우선하는 확정 사실(G3 리뷰·실측)**: ①Application을 지워도 ES는 남는다(`Delete=false`가 cascade에서 뺀다) — "cascade로 지워져도" 류 문장 금지 ②`Owner`였다면 ES가 지워지는 어떤 경로에서든 Secret이 GC된다 ③인수는 첫 동기화에서, provider 실패 시 값·UID는 불변(managed 라벨만 먼저 붙을 수 있다) ④**Secret이 지워지면 다음 주기 refresh(5분)에 재생성 — 2026-09-21 DR1 실측 302초(즉시 아님)** → 터널 Secret이 지워지면 최대 5분간 새 파드가 시작하지 못한다(실행 중 파드는 무영향) ⑤**ES에 열거되지 않은 키는 인수 순간 삭제된다**(DR1 실측) — 라이브 키는 `TUNNEL_TOKEN` 하나라 소실 0 ⑥Orphan에서 ESO가 붙이는 것은 `…/managed` 라벨과 `…/data-hash` 어노테이션 둘뿐, `created-by`는 Owner 신호 ⑦실패 문면은 `platform/secrets/README.md` §1 표(ESO 2.10.0 실제 문면) ⑧root sync는 wave에서 기다리지 않는다 ⑨CI는 validate.sh를 부르지 않는다(T047) — "CI가 강제" 금지 ⑩sync-wave 숫자를 본문에 적지 않는다.
- kubectl 금지. 시크릿 값 없음. 한국어 파일은 Edit/Write 도구로 · CR 바이트 0 확인.

## 게이트(출력 원문을 보고에)
도구 PATH: `/c/Users/2401/AppData/Local/Temp/claude/d--code-joshuatech-ver2/df87ded7-ec45-4ac5-a67b-9b974d5bfd59/scratchpad/bin` + `/c/Users/2401/AppData/Local/Microsoft/WinGet/Links`. ES v1 스키마: `scratchpad/t045-g2-schemas/external-secrets.io/externalsecret_v1.json`.
```bash
kustomize build platform/secrets > "$SCRATCH/t045-g4.yaml"      # ExternalSecret 2장(cert-manager/cloudflare-dns-token · cloudflared/cloudflared-tunnel)
# DNS 토큰 ES 문서가 main 렌더와 바이트 동일한지(yq로 그 문서만 뽑아 비교) — G4가 G3의 ES를 건드리지 않았다는 증거
kubeconform -strict -summary -kubernetes-version 1.32.0 -schema-location default -schema-location "<CRD 스키마 템플릿>" "$SCRATCH/t045-g4.yaml"   # Valid 2 · Skipped 0
kustomize build platform/cloudflared   # main(22f96c3) 대비 바이트 동일
bash tests/validate.sh          # FAIL 0 · PASS 수 보고
bash tests/validate.tests.sh    # 백그라운드. 케이스 수 보고(검사 로직을 안 바꿨으면 42 그대로)
gitleaks dir . --no-banner --redact --exit-code 1
git status --short
```
- 계약 대조 표: gitops-repo.md §ExternalSecret 규약 ①–⑦ · §공통 규칙 인수형 예외(계약이 `cloudflared/cloudflared-tunnel`을 이름으로 지정) · §sync-wave `secrets` 행(범위 2장).

## 보고
첫 줄 `DONE`/`DONE_WITH_CONCERNS`/`NEEDS_CONTEXT`/`BLOCKED`. 만든 파일 · 게이트 출력 원문 · 계약 대조 표 · 스냅샷 대비 바꾼 곳(이유) · 의문점. 한국어.
