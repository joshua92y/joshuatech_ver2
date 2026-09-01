# Contract: 네임스페이스 · Pod Security Admission · NetworkPolicy 허용 매트릭스

`platform-gitops/platform/policies/`가 선언하는 네임스페이스·PSA 라벨·NetworkPolicy의 정본. default-deny를 적용하는 순간 끊기면 안 되는 경로를 전부 여기에 열거한다. 이 표에 없는 트래픽은 막혀야 정상이며, 새 경로가 필요하면 이 계약을 먼저 고친다(`allow-all`로 푸는 것은 금지).

## 네임스페이스 표 (전체, PSA `enforce` 레벨)

| 네임스페이스 | 구성요소 | PSA | privileged 사유 |
|---|---|---|---|
| `kube-system` | traefik · coredns · metrics-server (K3s 번들) | `privileged` | K3s 시스템 컴포넌트(svclb hostPort 등) |
| `argocd` | Argo CD | `restricted` | |
| `vault` | Vault(Raft 1, ocikms seal) | `restricted` | |
| `external-secrets` | ESO + SA `eso-platform`·`eso-dev`·`eso-prod` | `restricted` | |
| `cert-manager` | cert-manager(DNS-01 와일드카드 1장 → `kube-system` TLSStore) | `baseline` | |
| `cnpg-system` | CNPG operator + barman-cloud plugin | `baseline` | |
| `data` | pg-main(CNPG) · kafka(Strimzi) · dragonfly | `baseline` | |
| `identity` | authentik · openfga | `restricted` | |
| `jt-dev` | pod dev 배포(identity-admin …) | `restricted` | |
| `jt-prod` | pod prod 배포 | `restricted` | |
| `monitoring` | alloy(k8s-monitoring: metrics·logs·node-exporter) | `privileged` | hostPath `/var/log`(alloy-logs), node-exporter hostNetwork |
| `system-upgrade` | system-upgrade-controller + Plan Job | `privileged` | hostPID · `chroot /host`(K3s 업그레이드·`platform-backup.sh --pre-upgrade`) |
| `cloudflared` | cloudflared 터널 커넥터 | `restricted` | |
| `reloader` | Stakater Reloader | `restricted` | |

- `observability`라는 이름은 쓰지 않는다(→ `monitoring`).
- 라벨: `pod-security.kubernetes.io/enforce=<레벨>` + `warn`·`audit`은 같은 레벨. 레벨을 올리는 변경(baseline → restricted)은 approval-review `k8s-security` 경계 대상.
- **`platform/policies/`는 이 표의 네임스페이스를 전부 선언해야 한다.** validate.yml(T033)이 `platform/policies`의 Namespace 목록 = 이 표(14개)임을 lint하고, T031이 클러스터의 모든 네임스페이스가 PSA 라벨 + 아래 정책 3종을 가짐을 단언한다.

## 정책 3종 (네임스페이스마다)

| 정책 | 내용 | 적용 범위 |
|---|---|---|
| `default-deny` | `policyTypes: [Ingress, Egress]`, `podSelector: {}`, 규칙 없음 | `kube-system` 제외 전 ns |
| `allow-dns` | egress → `kube-system` `k8s-app=kube-dns` 53/UDP·53/TCP | `kube-system` 제외 전 ns |
| `deny-imds` | egress에서 `169.254.169.254/32` 제외(`ipBlock 0.0.0.0/0 except 169.254.169.254/32`) — `vault` ns만 `allow-imds`로 예외 | **전 ns(`kube-system` 포함)** |

`kube-system`은 `deny-imds`만 가진다(K3s 번들 컴포넌트에 default-deny를 걸지 않는다).

## 허용 매트릭스 (출발 → 도착:포트)

각 행은 출발 ns의 egress 정책 + 도착 ns의 ingress 정책 한 쌍으로 구현한다(클러스터 안 목적지). 클러스터 밖 목적지(외부 443, IMDS, KMS, 노드 IP)는 출발 ns의 egress `ipBlock`으로만 표현한다 — 표준 NetworkPolicy는 FQDN을 지원하지 않으므로 "github·google·postmark 443"은 `ipBlock 0.0.0.0/0`(except RFC 1918 · `169.254.169.254/32`) 포트 443으로 쓴다.

| 출발 | 도착 | 포트 | 용도 |
|---|---|---|---|
| `kube-system`(traefik) | `argocd` | 8080 | Argo CD UI/API(Ingress `argo.`) |
| `kube-system`(traefik) | `vault` | 8200 | Vault UI(Ingress `vault.`) |
| `kube-system`(traefik) | `identity` | 9000(authentik) · 8080(openfga) | `auth.` Ingress, forward-auth outpost |
| `kube-system`(traefik) | `jt-dev` · `jt-prod` | 8000 | pod m2m·admin Ingress |
| `jt-dev` · `jt-prod` | `data` | 5432 · 9093 · 6379 | pg-main · Kafka(SCRAM/TLS) · Dragonfly |
| `jt-dev` · `jt-prod` | `identity` | 9000 · 8080 | Authentik(JWKS·revoke API, svc DNS) · OpenFGA |
| `jt-dev` · `jt-prod` | `monitoring` | 4317 · 4318 | OTLP(gRPC·HTTP) → Alloy |
| `identity` | `data` | 5432 | Authentik·OpenFGA DB |
| `identity` | `jt-prod` | 8000 | Authentik → identity-admin 웹훅(`/webhooks/authentik`, svc DNS) |
| `identity` | 외부 | 443 | 소셜 로그인(github·google) · 메일(postmark) |
| `external-secrets` | `vault` | 8200 | kv 읽기 |
| `external-secrets` | K8s API(노드 A private IP) | 6443 | Secret 쓰기·SA 토큰 |
| `vault` | `169.254.169.254` | 80 | 인스턴스 프린시펄(IMDS) — 유일한 IMDS 예외 |
| `vault` | OCI KMS 엔드포인트 | 443 | auto-unseal |
| `data` | OCI Object Storage | 443 | barman-cloud 백업·WAL(`jt-backup`) |
| `argocd` | K8s API(노드 A private IP) | 6443 | sync |
| `argocd` | github.com · ghcr.io | 443 | gitops 저장소 · OCI 차트 |
| `cert-manager` | `api.cloudflare.com` | 443 | DNS-01 |
| `cert-manager` | `1.1.1.1` | 53 | DNS-01 전파 확인 |
| `cloudflared` | Cloudflare edge | 7844 · 443 | 터널(QUIC/HTTP2) |
| `cloudflared` | K8s API(노드 A private IP) | 6443 | `k8s.joshuatech.dev` 터널 |
| `cloudflared` | 노드 A private IP | 22 | `ssh.joshuatech.dev` 터널 |
| `monitoring` | Grafana Cloud | 443 | metrics·logs·traces 전송 |
| `monitoring` | kubelet(노드 A·B) | 10250 | cAdvisor·kubelet 지표 |
| `reloader` | K8s API(노드 A private IP) | 6443 | Deployment 롤아웃 |
| 전 ns | `kube-system` kube-dns | 53 | `allow-dns` |

표에 없는 조합(예: `jt-dev` → `jt-prod`, `jt-*` → `vault`, `data` → `jt-*`, `identity` → `jt-dev`)은 차단된다.

## hostNetwork · 호스트 네임스페이스 예외

NetworkPolicy는 pod 네트워크에만 적용된다. 다음 워크로드는 그 밖에 있으므로 예외로 열거하고, 다른 곳에 두지 않는다.

| 워크로드 | ns | 이유 | 보완 통제 |
|---|---|---|---|
| node-exporter(k8s-monitoring) | `monitoring` | hostNetwork(노드 지표) | PSA privileged ns 격리, 인스턴스 IMDS v1 비활성, 동적 그룹 `jt-node-a`는 노드 A OCID만 |
| alloy-logs | `monitoring` | hostPath `/var/log` 읽기(pod 네트워크는 유지) | 같은 ns 정책 3종 적용 |
| system-upgrade Plan Job | `system-upgrade` | hostPID · `chroot /host` | 업그레이드 창(일요일 03:00–05:00 KST)에만 생성, Plan은 gitops 정본 |
| K3s svclb(traefik hostPort 443) | `kube-system` | 호스트 포트 바인딩 | OCI NSG 443 ← Cloudflare IPv4 대역만, AOP mTLS |

hostNetwork pod에는 `deny-imds`가 미치지 않으므로 IMDS 보호는 인스턴스 측(IMDS v1 비활성 + 동적 그룹 노드 A 한정 + `use keys where target.key.id = <키>`)이 맡는다.

## 검증 (tests-first)

- T031: 모든 ns에 PSA 라벨 + `default-deny`·`allow-dns`·`deny-imds`(kube-system은 `deny-imds`만), `vault` ns만 IMDS 도달, `jt-dev` pod에서 `jt-prod` svc 도달 실패.
- T033(validate.yml): `platform/policies` Namespace 목록 = 이 표; 정책 3종 × ns 존재.
- T041: 이 계약을 그대로 매니페스트로 옮긴다(추가 허용 규칙 금지).
