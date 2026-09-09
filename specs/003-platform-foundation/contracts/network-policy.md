# Contract: 네임스페이스 · Pod Security Admission · NetworkPolicy 허용 매트릭스

`platform-gitops/platform/policies/`가 선언하는 네임스페이스·PSA 라벨·NetworkPolicy의 정본. default-deny를 적용하는 순간 끊기면 안 되는 경로를 전부 여기에 열거한다. 이 표에 없는 트래픽은 막혀야 정상이며, 새 경로가 필요하면 이 계약을 먼저 고친다(`allow-all`로 푸는 것은 금지).

## 네임스페이스 표 (전체, PSA `enforce` 레벨)

| 네임스페이스 | 구성요소 | PSA | privileged 사유 |
|---|---|---|---|
| `kube-system` | traefik · coredns · metrics-server (K3s 번들) | `privileged` | K3s 시스템 컴포넌트(svclb hostPort 등) |
| `argocd` | Argo CD | `restricted` | |
| `vault` | Vault(Raft 1, ocikms seal) | `restricted` | |
| `external-secrets` | ESO + SA `eso-platform`·`eso-dev`·`eso-prod`·`eso-data`·`eso-ca-reader` | `restricted` | |
| `cert-manager` | cert-manager(DNS-01 와일드카드 1장 → `kube-system` TLSStore) | `baseline` | |
| `cnpg-system` | CNPG operator + barman-cloud plugin | `baseline` | |
| `data` | pg-main(CNPG) · kafka(Strimzi) · dragonfly | `baseline` | |
| `identity` | authentik · openfga | `restricted` | |
| `jt-dev` | pod dev 배포(identity-admin …) | `restricted` | |
| `jt-prod` | pod prod 배포 | `restricted` | |
| `monitoring` | alloy(k8s-monitoring: metrics·logs·node-exporter) | `privileged` | hostPath `/var/log`(alloy-logs), node-exporter hostNetwork |
| `system-upgrade` | system-upgrade-controller + Plan Job | `privileged` | hostPID · hostIPC · hostNetwork · `chroot /host`(K3s 업그레이드·`platform-backup.sh --pre-upgrade`) |
| `cloudflared` | cloudflared 터널 커넥터 | `restricted` | |
| `reloader` | Stakater Reloader | `restricted` | |

- `observability`라는 이름은 쓰지 않는다(→ `monitoring`).
- 라벨: `pod-security.kubernetes.io/enforce=<레벨>` + `warn`·`audit`은 같은 레벨. **PSA 레벨을 바꾸는 변경은 상향(baseline → restricted)·하향(restricted → baseline) 모두** approval-review `k8s-security` 경계 대상이다.
- **`platform/policies/`는 이 표의 네임스페이스를 전부 선언해야 한다.** `kube-system`은 K3s가 이미 만든 네임스페이스이므로 **라벨만 SSA로 패치**하고(정책은 `deny-imds`만), 나머지 13개는 Namespace + 라벨 + 아래 정책을 선언한다. validate.yml(T033)이 `platform/policies`의 Namespace 목록 = 이 표(14개)임을 lint하고, T031이 클러스터의 모든 네임스페이스가 PSA 라벨 + 해당 정책을 가짐을 단언한다.
- helm 차트로 배포하는 컴포넌트(Vault·Authentik·OpenFGA·Reloader)는 차트 values에 `runAsNonRoot: true` · `allowPrivilegeEscalation: false` · `capabilities.drop: [ALL]` · `seccompProfile.type: RuntimeDefault` **4항목을 명시**한다(차트 기본값에 기대지 않는다). PSA `restricted` ns에서 이 값이 빠지면 admission이 거부한다.

## 정책 세트 (공통 5종)

| 정책 | 내용 | 적용 범위 |
|---|---|---|
| `default-deny` | `policyTypes: [Ingress, Egress]`, `podSelector: {}`, 규칙 없음 | `kube-system` 제외 13 ns |
| `allow-dns` | egress → `kube-system` `k8s-app=kube-dns` 53/UDP·53/TCP | `kube-system` 제외 13 ns |
| `allow-same-namespace` | ingress·egress 모두 `podSelector: {}` ← / → 같은 ns(`namespaceSelector`로 자기 ns 라벨) | `argocd` · `data` · `cnpg-system` · `external-secrets` · `cert-manager` · `monitoring` · `identity` (7) |
| `allow-kube-api` | egress → `ipBlock <노드 A private IP>/32` 6443 | `argocd` · `vault` · `external-secrets` · `cert-manager` · `cnpg-system` · `data` · `monitoring` · `system-upgrade` · `reloader` · `cloudflared` (10) |
| `allow-apiserver-webhook` | ingress ← `ipBlock <노드 A private IP>/32` **및**(webhook 행 한정) `ipBlock <노드 A flannel 터널 장치 주소>/32`, ns마다 포트 지정 | `cert-manager` 10250 · `external-secrets` 10250 · `cnpg-system` 9443 · `vault` 8200 |

조건부 2종:

| 정책 | 내용 | 적용 범위 |
|---|---|---|
| `deny-imds` | egress `ipBlock 0.0.0.0/0 except [169.254.169.254/32]` | **`kube-system` 전용** |
| `allow-imds` | egress → `ipBlock 169.254.169.254/32` 80 | **`vault` 전용**(인스턴스 프린시펄) |

- `kube-system`에는 default-deny를 걸지 않는다(K3s 번들 컴포넌트). 그래서 IMDS 차단만 `deny-imds` 한 장으로 표현한다 — allow-only 모델에서 `except`가 있는 egress 규칙은 그 규칙 안에서만 의미가 있으므로, **default-deny가 있는 나머지 13 ns에서는 `deny-imds` 같은 별도 정책이 아무것도 막지 못한다**. 따라서 그 13 ns의 IMDS 차단은 아래 "외부 egress 규칙 형식"으로 규칙마다 표현한다.
- `allow-same-namespace`가 필요한 이유: Strimzi operator ↔ broker ↔ entity-operator, CNPG operator ↔ instance, Argo server ↔ repo-server ↔ redis ↔ controller, Alloy 내부, Authentik server ↔ worker는 전부 같은 ns 안 통신인데 default-deny가 이를 끊는다.
- `allow-apiserver-webhook`의 `vault` 8200 행은 admission webhook이 아니라 `kubectl port-forward svc/vault 8200`(운영자 seal 확인, `platform-backup.sh`의 Vault 스냅샷)의 도착 경로다. `platform-backup.sh`는 **반드시 port-forward를 경유**하고 공개 호스트(`vault.joshuatech.dev`)나 pod IP를 직접 쓰지 않는다.
- **이 정책의 두 행은 메커니즘이 다르다**(2026-09-09 VD-W 실측으로 확인, T042):
  - **webhook 행**(`cert-manager` · `external-secrets` · `cnpg-system`) — API 서버가 **엔드포인트 pod IP로 직접 dial** 한다. K3s 기본 `--egress-selector-mode: agent`에서 터널에 등록되는 것은 노드 IP와 kubelet 포트뿐이라 pod IP는 터널 대상이 아니고, 연결은 API 서버가 도는 노드의 호스트 네임스페이스에서 나간다. `flannel-backend: wireguard-native`에서는 pod CIDR이 `dev flannel-wg scope link` 라우트이고 그 장치의 유일한 주소가 **그 노드 pod CIDR의 네트워크 주소(/32)**이므로, 출발 IP는 노드 private IP가 **아니다**. 따라서 노드 B에 배치된 webhook에는 flannel 터널 장치 주소를 함께 허용해야 한다. `flannel-backend: host-gw`였다면 노드 private IP가 정확히 옳다 — 이 항목은 백엔드 선택에 딸린 것이지 주소를 잘못 적은 것이 아니다.
  - **`vault` port-forward 행** — API 서버·kubelet을 거쳐 CRI 스트리밍 서버가 **pod 네임스페이스 안에서 loopback으로** 접속하므로 호스트의 NetworkPolicy 체인을 통과하지 않는다. 즉 이 행은 실효가 없으나, ns 집합의 완결성(정책 4장이 네 ns에 존재)을 위해 유지한다.
  - 같은 이유로 `kubectl get --raw /api/v1/namespaces/<ns>/pods/<pod>:<port>/proxy`(에이전트 진단 경로)도 pod IP 직접 dial이라 default-deny ns의 다른 노드 pod에 대해서는 같은 허용이 필요하다.
  - 허용 대상 주소는 pod CIDR의 **네트워크 주소**라 어떤 pod에도 할당되지 않는다 — 실질 허용 범위는 그 노드의 호스트 네임스페이스뿐이다. 노드 재조인·재이미지로 flannel 리스가 바뀌면 `.spec.podCIDR`과 재대조한다.

## 외부 egress 규칙 형식 (default-deny가 있는 13 ns 공통)

클러스터 밖 목적지는 출발 ns의 egress `ipBlock`으로만 표현한다(표준 NetworkPolicy는 FQDN을 지원하지 않는다). **모든 외부 egress 규칙은 다음 형식을 지킨다** — `except`로 IMDS와 사설 대역을 빼고, `ports`를 반드시 명시한다.

```yaml
egress:
  - to:
      - ipBlock:
          cidr: 0.0.0.0/0
          except:
            - 169.254.169.254/32   # IMDS
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
    ports:
      - { protocol: TCP, port: 443 }
```

- `except`에 사설 대역을 넣으므로 "외부 443" 규칙이 클러스터 내부·노드로 새지 않는다. 클러스터 안 목적지와 노드 IP 목적지는 별도 규칙(`namespaceSelector` 또는 `<노드 IP>/32`)으로 명시한다.
- `ports` 없는 `ipBlock` 규칙은 금지한다(전 포트 개방). T033 lint가 `platform/policies`의 모든 egress `ipBlock` 규칙에 `ports`와 위 `except` 4개가 있는지 검사한다.

## 허용 매트릭스 — 클러스터 내부 (출발 ns → 도착 ns:포트)

각 행은 출발 ns의 egress 규칙 + 도착 ns의 ingress 규칙 한 쌍으로 구현한다.

| 출발 | 도착 | 포트 | 용도 |
|---|---|---|---|
| `kube-system`(traefik) | `argocd` | 8080 | Argo CD UI/API(Ingress `argo.`) |
| `kube-system`(traefik) | `vault` | 8200 | Vault UI(Ingress `vault.`) |
| `kube-system`(traefik) | `identity` | 9000 | Authentik(`auth.` Ingress, forward-auth outpost) |
| `kube-system`(traefik) | `jt-dev` · `jt-prod` | 8000 | pod m2m·admin Ingress |
| `kube-system`(traefik) | `monitoring` | 4317 | Traefik OTLP 트레이스 → Alloy(T038) |
| `jt-dev` · `jt-prod` | `data` | 5432 · 9093 · 6379 | pg-main · Kafka(SCRAM/TLS) · Dragonfly |
| `jt-dev` · `jt-prod` | `identity` | 9000 · 8080 | Authentik(JWKS·revoke API, svc DNS) · OpenFGA |
| `jt-dev` · `jt-prod` | `monitoring` | 4317 · 4318 | OTLP(gRPC·HTTP) → Alloy |
| `identity` | `data` | 5432 | Authentik·OpenFGA DB |
| `identity` | `jt-prod` | 8000 | Authentik → identity-admin prod 웹훅(`/webhooks/authentik`, svc DNS) |
| `identity` | `jt-dev` | 8000 | Authentik → identity-admin **dev** 웹훅(dev NotificationTransport, svc DNS) |
| `external-secrets` | `vault` | 8200 | kv 읽기 |
| `monitoring` | `argocd` | 8082 · 8083 · 8084 | metrics(application-controller · repo-server · server) |
| `monitoring` | `vault` | 8200 | `vault_core_unsealed` 등(`telemetry` + `unauthenticated_metrics_access`) |
| `monitoring` | `external-secrets` | 8080 | ESO metrics |
| `monitoring` | `cert-manager` | 9402 | cert-manager metrics(`CertExpiringSoon`) |
| `monitoring` | `cnpg-system` | 8080 | CNPG operator metrics |
| `monitoring` | `data` | 9187 · 9404 | CNPG instance exporter · Strimzi kafka-exporter |
| `monitoring` | `jt-dev` · `jt-prod` | 9100 · 9464 | pod web metrics · relay outbox metrics |
| 전 ns | `kube-system` kube-dns | 53 | `allow-dns` |

- **scrape 대상 ns의 ingress는 `namespaceSelector`가 `monitoring`인 것만 허용한다**(`podSelector: {}` + `from.namespaceSelector: kubernetes.io/metadata.name=monitoring`). `jt-dev` → `vault` 8200 처럼 다른 ns가 같은 포트로 들어오는 경로는 열리지 않는다.
- `traefik → identity 8080`(OpenFGA) 행은 **삭제**했다. OpenFGA는 공개 호스트가 없고 클러스터 안(`jt-*` → `identity` 8080)에서만 호출한다.
- 표에 없는 조합(예: `jt-dev` → `jt-prod`, `jt-*` → `vault`, `data` → `jt-*`, `argocd` → `data`)은 차단된다.

## 허용 매트릭스 — 클러스터 밖 · 노드 IP

| 출발 | 도착 | 포트 | 용도 |
|---|---|---|---|
| `identity` | 외부 | 443 | 소셜 로그인(github·google) |
| `jt-dev` · `jt-prod` | 외부 | 443 | Cloudflare Access certs(`joshua-tech.cloudflareaccess.com/cdn-cgi/access/certs`) · Sentry ingest |
| `cert-manager` | 외부 | 443 | `api.cloudflare.com`(DNS-01) · Let's Encrypt ACME 디렉터리·주문 |
| `cert-manager` | `1.1.1.1` | 53 | DNS-01 전파 확인(`ipBlock 1.1.1.1/32`, UDP·TCP) |
| `vault` | 외부 | 443 | OCI KMS(auto-unseal) · `auth.joshuatech.dev` OIDC discovery(FR-046 예외 2) |
| `vault` | `169.254.169.254` | 80 | 인스턴스 프린시펄(IMDS) — `allow-imds`, 유일한 IMDS 예외 |
| `argocd` | 외부 | 443 | github.com(gitops 저장소) · ghcr.io/quay.io(OCI 차트) · `auth.joshuatech.dev` OIDC discovery(FR-046 예외 2) |
| `data` | 외부 | 443 | OCI Object Storage — barman-cloud 백업·WAL(`jt-backup`) |
| `monitoring` | 외부 | 443 | Grafana Cloud metrics·logs·traces 전송 |
| `monitoring` | 노드 A·B private IP | 10250 | kubelet(cAdvisor·kubelet 지표) |
| `system-upgrade` | 외부 | 443 | `update.k3s.io` 채널 조회(**컨트롤러만**; Plan Job은 hostNetwork라 정책 밖 — 아래 예외표) |
| `cloudflared` | 외부 | 7844 · 443 | Cloudflare edge 터널(QUIC/HTTP2) |
| `cloudflared` | 노드 A private IP | 22 | `ssh-a.joshuatech.dev` 터널 |
| `cloudflared` | 노드 B private IP | 22 | `ssh-b.joshuatech.dev` 터널 |
| 노드 A private IP | `vault` | 8200 | `kubectl port-forward`(운영자 seal 확인 · `platform-backup.sh` Raft 스냅샷) — `allow-apiserver-webhook` |
| 노드 A private IP **및** 노드 A flannel 터널 장치 주소 | `cert-manager` · `external-secrets` · `cnpg-system` | 10250 · 10250 · 9443 | API 서버 → admission webhook(pod IP 직접 dial — 위 각주) — `allow-apiserver-webhook` |
| 위 10 ns | 노드 A private IP | 6443 | K8s API — `allow-kube-api` |

- **`identity`의 메일(SMTP 587/465) egress는 없다** — SP-1은 recovery 이메일을 쓰지 않고 enrollment 흐름도 없어 Authentik이 이메일을 발송하지 않는다(T081). 메일 발송이 생기는 SP에서 이 매트릭스에 행을 먼저 추가한다.

### 공개 호스트 예외(FR-046 예외 2)의 범위

- 클러스터 안에서 공개 호스트(`https://auth.joshuatech.dev/…`)로 나가는 것은 **Argo CD와 Vault의 OIDC discovery 둘뿐**이다(둘 다 `.well-known` + JWKS를 issuer URL로만 다루는 라이브러리라 svc DNS로 바꿀 수 없다).
- pod(identity-admin 등)의 **JWKS는 svc DNS**를 쓴다: `http://authentik-server.identity.svc:9000/application/o/<pod>/jwks/`. 토큰의 `iss`만 공개 URL(`https://auth.joshuatech.dev/application/o/<pod>/`)로 검증한다. 그래서 `jt-*` → 외부 443 규칙에 Authentik은 들어가지 않는다(contracts/identity-admin-api.md §호스트, T083).

## hostNetwork · 호스트 네임스페이스 예외

NetworkPolicy는 pod 네트워크에만 적용된다. 다음 워크로드는 그 밖에 있으므로 예외로 열거하고, 다른 곳에 두지 않는다.

| 워크로드 | ns | 이유 | 보완 통제 |
|---|---|---|---|
| node-exporter(k8s-monitoring) | `monitoring` | hostNetwork(노드 지표) | PSA privileged ns 격리, 인스턴스 IMDS v1 비활성, 동적 그룹 `jt-node-a`는 노드 A OCID만 |
| alloy-logs | `monitoring` | hostPath `/var/log` 읽기(pod 네트워크는 유지) | 같은 ns 공통 정책 적용 |
| system-upgrade Plan Job | `system-upgrade` | **hostPID · hostIPC · hostNetwork · `chroot /host`가 SUC에 하드코딩**(비활성화 불가). DNS는 `ClusterFirstWithHostNet` | 업그레이드 창(일요일 03:00–05:00 KST)에만 생성, Plan은 gitops 정본, 이미지 digest 핀. 컨트롤러 pod는 정책 안(위 표) |
| K3s svclb(traefik hostPort 443) | `kube-system` | 호스트 포트 바인딩 | OCI NSG 443 ← Cloudflare IPv4 대역만, AOP mTLS |

hostNetwork pod에는 IMDS 차단이 미치지 않으므로 IMDS 보호는 인스턴스 측(IMDS v1 비활성 + 동적 그룹 노드 A 한정 + `use keys where target.key.id = <키>`)이 맡는다.

## 포트 출처 각주

매트릭스의 포트는 각 컴포넌트 **helm 차트 기본값** 기준이다: cert-manager webhook 10250 · ESO webhook 10250 · CNPG webhook 9443 · Argo CD metrics 8082/8083/8084 · ESO metrics 8080 · cert-manager metrics 9402 · CNPG operator metrics 8080 · CNPG instance exporter 9187 · Strimzi kafka-exporter 9404 · Vault 8200 · Authentik 9000 · OpenFGA 8080 · pod web 8000/9100 · relay 9464. 차트 values에서 포트를 바꾸면 이 표와 정책도 함께 바꾼다 — T033 lint가 `platform/**` helm values의 포트 설정과 `platform/policies`의 정책 포트가 일치하는지 검사한다.

## 검증 (tests-first)

- **T031(양방향 단언)**: ① 모든 ns에 PSA 라벨 + 해당 정책(`kube-system`은 라벨 + `deny-imds`만) ② 매트릭스 **행마다 도달 성공** ③ **표 밖 조합 차단**(`jt-dev` → `jt-prod` svc, `data` → `jt-dev`) ④ `monitoring` 아닌 ns에서 `vault` 8200 거부 ⑤ `jt-dev` pod에서 `1.1.1.1:443` 연결 실패(외부 443 규칙의 `except`·`ports` 확인) ⑥ `vault` ns만 IMDS 도달 ⑦ 전 ns PSA 위반 이벤트 0.
- **T033(validate.yml)**: `platform/policies` Namespace 목록 = 이 표(14개); ns마다 공통 정책 세트 존재; 모든 egress `ipBlock` 규칙에 `ports` + `except` 4개; helm values 포트 ↔ 정책 포트 일치.
- **T041**: 이 계약을 그대로 매니페스트로 옮긴다(추가 허용 규칙 금지). `kube-system`은 라벨만 SSA 패치.
- **T034·T036·T037·T038·T044·T046·T080·T081·T082**: 각 컴포넌트 배포 시 securityContext 4항목 values·정책 포트를 이 계약과 대조한다.
