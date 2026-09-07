> 번역본(편의용). 정본은 영어 원본 `.claude/rules/infra.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "infra/**"
  - "scripts/**"
```

# Rules for `infra/` and `scripts/` (OpenTofu, gitops, operations scripts)

기록 계약: `specs/003-platform-foundation/contracts/gitops-repo.md`와 `contracts/network-policy.md`. 이 계약들은 이 워크스페이스에서 `platform-gitops` 저장소를 작업할 때의 편집도 관장한다. 충돌 시 계약이 우선한다; 계약을 먼저 개정한다.

## OpenTofu

- 일상적인 `tofu plan`은 반드시 destroy 0을 보여야 한다. destroy가 포함된 plan은 작업을 중단시킨다: 사용자의 명시적 승인을 받고 적용(apply) 전에 PR에 기록한다.
- 변경 흐름은 plan → review → apply다; 검토되지 않은 plan을 절대 적용하지 않는다. 프로바이더 버전을 고정한다; 상태(state)와 자격 증명은 저장소에 절대 들어가지 않는다.
- NSG: 443 인그레스는 Cloudflare IPv4 대역에만 열려 있다; `0.0.0.0/0` 인그레스 규칙 금지. SSH(22)는 절대 공개적으로 노출하지 않는다 — 접근은 cloudflared 터널을 통해서만 한다. 인스턴스에서 IMDS v1은 비활성 상태를 유지한다.
- **부트스트랩 예외(노드에 cloudflared가 아직 돌지 않는 동안 — T013/T014 재이미지 세션과 T035–T039 K3s 부트스트랩 창):** 운영자는 OCI CLI로 정확히 하나의 운영자 주소(`<ip>/32`, `0.0.0.0/0`은 절대 불가)에서 22/tcp로 들어오는 임시 NSG 인그레스 규칙을 OpenTofu 밖에서 추가할 수 있다 — `infra/` 아래에는 절대 선언하지 않는다. T013/T014에서는 같은 운영자 세션 안에서 제거한다. T035–T039에서는 `nsg-cluster`의 규칙 하나를 창 전체 동안 유지할 수 있고(사용자 결정 2026-09-04, 옵션 A), `ssh-a`/`ssh-b` 터널 호스트가 동작하는 T039 끝에 제거한다; 운영자 주소가 바뀌면 새 규칙을 추가하기 전에 옛 규칙을 먼저 제거한다. 제거의 증거는 `oci network nsg rules list`에 선언된 규칙만 남아 있는 것이다; OpenTofu는 자기가 만들지 않은 규칙을 추적하지 않으므로 깨끗한 `tofu plan`은 증거가 되지 않는다.

## GitOps (platform-gitops conventions)

- 이미지는 digest로: `apps/*/overlays/<env>/kustomization.yaml`의 `images:` 항목은 `newName` + `digest: sha256:...`만 담는다 — `newTag`는 금지다(validate.yml이 이를 실패시킨다). `platform/` 이미지는 태그와 함께 `@sha256:...`을 핀한다.
- sync-wave: `contracts/gitops-repo.md` §sync-wave의 단일 표가 유일한 진실의 원천이다. Application의 `argocd.argoproj.io/sync-wave` 어노테이션은 그 표와 일치해야 한다; wave 번호를 다른 곳에 절대 중복하지 않는다; 새 `platform/<component>/` 디렉터리는 그 표를 먼저 개정해야 한다.
- ExternalSecret: `apiVersion: external-secrets.io/v1`; `remoteRef.key`는 `^(platform|dev|prod)/...`와 일치한다; store ↔ 위치는 일치해야 한다(`overlays/dev` → `vault-dev` + `dev/` 키, `overlays/prod` → `vault-prod` + `prod/`, `secrets/**` → `vault-platform` + `platform/`); `auth.kubernetes.serviceAccountRef`는 항상 `namespace: external-secrets`를 지정한다.
- pod당 ExternalSecret은 정확히 2개: `<pod>-env`(런타임)와 `<pod>-migrate`(owner DB, PreSync Job 전용). Deployment/CronJob의 `envFrom`이 `-migrate`를 참조하면 실패다.
- CA 미러(`k8s-data-ca`): `remoteRef.key`는 {`pg-main-ca`, `jt-kafka-cluster-ca-cert`} 안에서 `remoteRef.property: ca.crt`로만 — `dataFrom`은 금지다(`ca.key`를 앱 네임스페이스로 복사하게 된다).
- Workers 전용 시크릿 경로(`(dev|prod)/(access|web)/...`)는 `apps/**` ExternalSecret에 절대 나타나지 않는다; 그 값들은 Workers Secrets로만 간다.
- NetworkPolicy: `contracts/network-policy.md`의 허용 매트릭스가 전부다(exhaustive) — `allow-all` 금지, 새 경로는 계약을 먼저 개정한다. 모든 egress `ipBlock` 규칙은 `ports`와 4개의 `except` 항목(IMDS + RFC 1918 대역 3개)을 함께 가진다.

## Bootstrap and operations scripts

- 반드시 멱등해야 한다: 생성 전에 존재 여부를 확인하고, 재실행해도 중복 리소스와 오류 없이 같은 최종 상태가 된다. `platform-backup.sh`, `host-prep.sh`, `cutover-web.sh`도 포함된다 — 두 번 실행해서 검증한다.
- `platform-backup.sh`는 `kubectl port-forward svc/vault 8200`을 통해서만 Vault에 도달한다; 공개 호스트(`vault.joshuatech.dev`)나 pod IP로는 절대 안 된다.
- 스크립트는 실행 시점에 환경에서 자격 증명을 읽는다; 자격 증명을 절대 내장하거나, 캐시하거나, 디스크에 쓰지 않는다.

## Credentials (hard boundary for agents)

- 운영자의 개인 계정 자격 증명, admin kubeconfig, `jt-ops` SSH 개인 키를 에이전트 환경 변수, 파일, 저장소에 절대 넣지 않는다 — "일시적으로"를 포함해 어떤 형태로도.
- 에이전트 신원은 고정되어 있다: E2E 흐름은 `e2e@joshuatech.dev`를 쓴다; 클러스터 접근은 단기 `agent-view` 토큰을 쓴다; OCI 접근은 `svc-verify` 세션 토큰만 쓴다. 작업에 그 이상이 필요해 보이면 멈추고 사용자에게 묻는다 — 스스로 권한을 올리지 않는다.
- **하네스 예외(사용자 결정 C, 2026-09-07):** `tests/infra/tofu.tests.ps1` — 따라서 `tests/run-all.ps1`도 — 는 운영자의 기본 OCI 프로파일과 `joshuatech-tfstate` 상태 프로파일로 `infra/oci`에 대해 읽기 전용 `tofu plan -lock=false`를 실행한다. 이것이 에이전트가 호출하는 명령 중 운영자 자격 증명에 닿아도 되는 유일한 것이다: 절대 apply 하지 않고, 상태를 쓰지 않으며, "destroy 0"을 증명하기 위해 존재한다. 에이전트는 이를 넓히지 않는다 — 다른 하네스·스크립트·즉석 명령은 그 프로파일을 쓸 수 없고, 쓰기 경로를 추가하는 하네스 변경은 규칙 위반이다.

## `jt-ops` key rules

- `jt-ops` SSH 키는 반드시 FIDO2 하드웨어 키여야 한다. 하드웨어 기반 키가 불가능하면 `ssh-add -c`(사용 시 확인 프롬프트)로 로드하는 패스프레이즈 보호 키를 쓴다 — 보호 없는 키는 절대 안 된다.
- SSH 연결은 cloudflared(`ssh-a.` / `ssh-b.` 터널 호스트)를 통해서만 하고, 직접 공개 엔드포인트로는 절대 하지 않는다 — 위의 부트스트랩 예외만 제외한다.
- 모든 운영자 세션이 끝날 때 `cloudflared access logout`을 실행한다.
