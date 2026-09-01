# Contract: platform-gitops 저장소

클러스터가 바라보는 유일한 정본. public. 시크릿 값은 없고 `ExternalSecret`만 있다. Argo CD root app이 이 저장소의 `clusters/oci-k3s/`를 읽는다.

## 디렉터리

```
platform-gitops/
├── bootstrap/
│   ├── argocd/                     # kustomization: remote base(install.yaml, 버전 핀) + patches(dex·applicationset 비활성, requests, ServerSideApply)
│   └── root-app.yaml               # Application "root" → clusters/oci-k3s/apps (유일한 수동 apply)
├── clusters/oci-k3s/
│   ├── projects/{platform,dev,prod}.yaml   # AppProject
│   └── apps/                       # Application 1개/컴포넌트 (app-of-apps)
├── platform/<component>/           # cert-manager traefik vault external-secrets cnpg kafka dragonfly authentik openfga observability cloudflared policies
│   ├── kustomization.yaml          # helmCharts(values 인라인) 또는 순수 매니페스트
│   └── …
├── apps/<pod>/
│   ├── base/{deployment,service,ingress,externalsecret,kustomization}.yaml   # Ingress host = PLACEHOLDER.joshuatech.dev
│   └── overlays/{dev,prod}/kustomization.yaml   # namespace, images[].digest, Ingress host JSON6902, replicas
├── secrets/                        # 네임스페이스별 ExternalSecret (플랫폼용)
└── .github/workflows/{validate,promote}.yml
```

## Application 규약

| 항목 | 규칙 |
|---|---|
| 이름 | `platform-<component>` · `<pod>-<env>` |
| project | 플랫폼 → `platform`, 앱 → `dev`·`prod` |
| sync-wave | `-1` CRD·namespaces·policies → `0` cert-manager·external-secrets → `1` vault → `2` cnpg-operator·strimzi-operator → `3` pg-main·dragonfly·kafka → `4` authentik·openfga → `5` observability·cloudflared·traefik-config → 앱 `10` |
| syncPolicy | 플랫폼: `automated: { prune: false, selfHeal: true }`, syncOptions `ServerSideApply=true`, `CreateNamespace=true`, `Prune=confirm`, `Delete=confirm`, `SkipDryRunOnMissingResource=true`. dev 앱: prune·selfHeal true. prod 앱: automated이되 변경은 PR로만 |
| AppProject | `platform`: sourceRepos [gitops], destinations 플랫폼 네임스페이스, clusterResourceWhitelist(CRD·Namespace·ClusterRole…). `dev`/`prod`: 자기 네임스페이스만, cluster 리소스 금지. `default`: sourceRepos·destinations 비움 |

## 이미지·승격

- `apps/<pod>/overlays/<env>/kustomization.yaml`의 `images:` 항목은 `newName: ghcr.io/joshua92y/<pod>`, `digest: sha256:…`만(태그 금지). validate.yml이 `newTag` 존재 시 실패.
- dev bump: 모노레포 `publish-pod.yml`이 GitHub App 토큰으로 `overlays/dev` digest를 바꿔 main에 직접 커밋(메시지 `chore(<pod>): dev → <short-digest>`).
- prod 승격: `promote.yml`(workflow_dispatch, 입력 `pod`)이 dev digest를 읽어 `overlays/prod`를 바꾼 PR 생성(제목 `promote(<pod>): <short-digest>`), ruleset(main: PR 필수·required check validate·0 approvals·bypass = CI App)로 머지 → Argo sync. 롤백 = 해당 커밋 `git revert` PR.

## ExternalSecret 규약

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: identity-admin-env, namespace: jt-prod }
spec:
  refreshInterval: 1h
  secretStoreRef: { kind: ClusterSecretStore, name: vault-kv }
  target: { name: identity-admin-env, creationPolicy: Owner }
  data:
    - secretKey: DATABASE_URL
      remoteRef: { key: prod/db/identity_admin/app, property: url }
```

- 경로 형식은 `data-model.md` §8. validate.yml이 `remoteRef.key`를 `^(platform|dev|prod)/[a-z0-9_./-]+$`로 검사한다.
- 앱 Deployment는 `envFrom: secretRef`로 받고, Secret 변경 시 롤아웃은 `reloader.stakater.com/auto: "true"`(Reloader 도입 시) 또는 kustomize configMapGenerator 해시 — SP-1은 Reloader 없이 수동 `rollout restart`.

## validate.yml (required check)

1. `kustomize build`(모든 overlay·platform) → `kubeconform -strict -ignore-missing-schemas`(CRD 스키마는 datreeio 카탈로그).
2. `helm template`(helmCharts 사용 컴포넌트).
3. 시크릿 값 검사: `gitleaks`, `ExternalSecret.remoteRef.key` 정규식, `images[].newTag` 금지.
4. `argocd app diff --local`(선택, Argo CD 토큰 필요 시 생략) 결과를 PR 코멘트.

## 변경 권한

- 사람은 PR로만 main에 쓴다(ruleset). CI App은 `overlays/dev` digest 커밋만 bypass.
- `platform/`·`clusters/` 변경은 approval-review의 `k8s-security` 경계 대상(모노레포 spec에서 링크).
