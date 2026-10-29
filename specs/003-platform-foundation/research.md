# Research: 플랫폼 기반 (SP-1) — Phase 0

2026-09-01, 조사 에이전트 14(1차 출처 우선, 도구 호출 1,436회). 주제별로 **결정(Decision) / 근거(Rationale) / 대안(Alternatives)**, 확인된 버전, 설정 스니펫, 함정(gotchas), 미확인 항목(open)을 적는다. 이 문서의 결정은 spec D1–D20을 바꾸지 않고 구현 세부만 정한다. 원문 JSON은 `research/2026-09-01-plan-research-raw.json`.

## 목차

- [R1 K3s](#r1-k3s)
- [R2 Argo CD](#r2-argo-cd)
- [R3 cert-manager · AOP · Traefik](#r3-cert-manager---aop---traefik)
- [R4 Vault · OCI KMS · ESO](#r4-vault---oci-kms---eso)
- [R5 CNPG · barman-cloud](#r5-cnpg---barman-cloud)
- [R6 Strimzi Kafka](#r6-strimzi-kafka)
- [R7 Authentik · OpenFGA](#r7-authentik---openfga)
- [R8 Next.js · OpenNext](#r8-nextjs---opennext)
- [R9 Django pod 템플릿](#r9-django-pod-템플릿)
- [R10 Alloy · Grafana Cloud · Sentry](#r10-alloy---grafana-cloud---sentry)
- [R11 OpenTofu OCI](#r11-opentofu-oci)
- [R12 OpenTofu Cloudflare](#r12-opentofu-cloudflare)
- [R13 GitHub Actions](#r13-github-actions)
- [R14 OCI 운영](#r14-oci-운영)


## R1 K3s

R1 K3s v1.36 2노드 설치·설정 — Ubuntu 24.04 arm64(OCI VM.Standard.A1.Flex), 노드 A role=platform(server) / 노드 B role=data(agent)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| K3s (stable·latest·v1.36 채널 모두 동일) | v1.36.4+k3s1 (Kubernetes v1.36.4, Go 1.26.7) | 2026-08-27 | <https://github.com/k3s-io/k3s/releases/tag/v1.36.4%2Bk3s1> |
| K3s 릴리스 채널 해석(update.k3s.io) | stable→v1.36.4+k3s1, v1.36→v1.36.4+k3s1, v1.35→v1.35.8+k3s1 | 2026-09-01 조회 | <https://update.k3s.io/v1-release/channels> |
| K3s 번들 Traefik (image rancher/mirrored-library-traefik) | v3.7.8 / chart traefik-40.1.4+up40.1.0 (upstream chart 40.1.0, appVersion v3.7.1 → K3s가 tag 3.7.8로 덮어씀) | 2026-08-27 (K3s 릴리스 동봉) | <https://raw.githubusercontent.com/k3s-io/k3s/v1.36.4%2Bk3s1/manifests/traefik.yaml> |
| Traefik upstream (참고, 번들과 다름) | v3.7.12 / helm chart v41.4.0 | 2026-08-26 / 2026-08-27 | <https://github.com/traefik/traefik-helm-chart/releases> |
| K3s 번들 containerd (k3s-io fork) | v2.3.4-k3s1.36 (runc v1.4.2) | 2026-08-27 | <https://github.com/k3s-io/k3s/releases/tag/v1.36.4%2Bk3s1> |
| K3s 번들 Kine / SQLite / Flannel / CoreDNS / metrics-server | Kine v0.16.4, SQLite 3.53.4, Flannel v0.28.4, CoreDNS v1.14.6, metrics-server v0.9.0 | 2026-08-27 | <https://github.com/k3s-io/k3s/releases/tag/v1.36.4%2Bk3s1> |
| local-path-provisioner (K3s 번들) | v0.0.37 | 2026-08-05 | <https://github.com/rancher/local-path-provisioner/releases/tag/v0.0.37> |
| klipper-lb (ServiceLB 런타임 이미지, arm64 포함) | v0.4.17 | 2026-04-28 | <https://github.com/k3s-io/klipper-lb/releases> |
| system-upgrade-controller (K8s 1.36 의존성, amd64/arm64/arm 이미지) | v0.20.1 | 2026-07-22 | <https://github.com/rancher/system-upgrade-controller/releases/tag/v0.20.1> |
| rancher/k3s-upgrade 이미지 (linux/arm64 있음) | v1.36.4-k3s1 | 2026-08-27 | <https://hub.docker.com/r/rancher/k3s-upgrade/tags> |
| OCI Ubuntu 24.04 aarch64 플랫폼 이미지 | Canonical-Ubuntu-24.04-aarch64-2026.07.17-0 (24.04.4, 커널 6.17.0-10xx-oracle) | 2026-07-21 | <https://docs.oracle.com/en-us/iaas/images/ubuntu-2404/canonical-ubuntu-24-04-aarch64-2026-07-17-0.htm> |
| Ubuntu noble linux-oracle-6.17 (HWE 계열 oracle 커널) | 6.17.0-1020.20 (noble-updates/security) | 2026-08-17 | <https://launchpad.net/ubuntu/+source/linux-oracle-6.17> |
| Ubuntu 24.04 iptables 패키지 (nft 모드) | 1.8.10-3ubuntu2 | noble GA | <https://packages.ubuntu.com/noble/iptables> |
| Cloudflare Authenticated Origin Pulls CA (Global AOP, CN=origin-pull.cloudflare.net) | authenticated_origin_pull_ca.pem (만료 2029-11-01) | 2026-09-01 조회 | <https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem> |

### 결정

**K3S-D1. K3s 버전을 어떻게 고정·설치하는가 (INSTALL_K3S_VERSION vs 채널)?**

- Decision: OpenTofu cloud-init에서 `INSTALL_K3S_VERSION=v1.36.4+k3s1`로 명시 고정하고, 이후 패치 승격은 system-upgrade-controller(Plan)가 담당한다. 설치 스크립트에는 `INSTALL_K3S_EXEC=server|agent`만 주고 모든 플래그는 `/etc/rancher/k3s/config.yaml`에 둔다.
- Rationale: 채널(stable)은 시점에 따라 값이 바뀌어 재현성이 없다(오늘은 stable=v1.36.4+k3s1). config.yaml은 설치 방식과 무관하게 항상 로드되고, CLI 인자는 리스트 값(node-label 등)을 통째로 덮어쓰므로 선언적 파일 한 곳이 안전하다. `K3S_URL`만 있으면 EXEC 기본이 agent가 된다.
- Alternatives considered: `INSTALL_K3S_CHANNEL=stable`(재현성 없음); `INSTALL_K3S_EXEC="server --secrets-encryption ..."`처럼 플래그 나열(리스트 덮어쓰기 함정).
- Source: <https://docs.k3s.io/installation/configuration>

**K3S-D2. secrets-encryption을 어떤 provider로, 언제 켜는가?**

- Decision: 첫 부팅 config.yaml에 `secrets-encryption: true` + `secrets-encryption-provider: secretbox`를 넣어 처음부터 켠다.
- Rationale: secrets-encryption은 서버 재시작 없이는 켤 수 없고, 나중에 켜면 reencrypt(초당 ~5 secrets) + 재시작이 필요하다. Kubernetes 공식 문서는 aescbc를 'CBC padding oracle 취약 → Not recommended'로 분류하고, K3s는 2025-04 릴리스(v1.33.0+k3s1)부터 `--secrets-encryption-provider secretbox`를 지원한다. 회전은 `k3s secrets-encrypt rotate-keys` → 로그에서 reencrypt_finished 확인 → 서버 재시작.
- Alternatives considered: 기본 aescbc(약함, 나중에 secretbox로 마이그레이션 시 rotate-keys 필요); KMS v2(OCI KMS용 kube KMS 플러그인이 없어 과함 — Vault auto-unseal에만 OCI KMS 사용).
- Source: <https://docs.k3s.io/security/secrets-encryption>

**K3S-D3. 노드 역할 라벨과 ServiceLB(klipper-lb) 배치를 어떻게 고정하는가?**

- Decision: 노드 A(server) config.yaml에 `node-label: [role=platform, svccontroller.k3s.cattle.io/enablelb=true]`, 노드 B(agent)에 `node-label: [role=data]`. `--disable`은 쓰지 않고 servicelb·traefik·local-storage·coredns·metrics-server 모두 유지. `node-external-ip`는 설정하지 않는다.
- Rationale: `svccontroller.k3s.cattle.io/enablelb=true`가 하나라도 붙으면 ServiceLB가 allow-list 모드로 전환되어 라벨 없는 노드(B)에는 svclb 파드가 생기지 않는다 → 80/443 hostPort는 A에만 점유되고 Ingress status도 A IP만 노출. node-label은 등록 시점에만 적용되므로 첫 부팅 config에 있어야 한다. OCI는 공인 IP가 NAT라 `node-external-ip`를 주면 externalTrafficPolicy=Local이 오동작한다는 문서 경고가 있고, 원 IP는 어차피 Cloudflare 헤더(CF-Connecting-IP)로 받는다.
- Alternatives considered: `svccontroller.k3s.cattle.io/lbpool` 노드풀 + Traefik Service 라벨 매칭(노드가 2대뿐이라 과함); `--disable servicelb` + MetalLB(불필요).
- Source: <https://docs.k3s.io/networking/networking-services>

**K3S-D4. API 서버 인증서 SAN(--tls-san)에 무엇을 넣는가?**

- Decision: `tls-san: [<A private IP>, k3s.joshuatech.dev]` (cloudflared 터널로 kubectl 접근할 호스트명). `tls-san-security`는 기본 true 유지.
- Rationale: kubectl은 cloudflared `access tcp` 경유 시 127.0.0.1로 붙지만(기본 SAN 포함) 원격 호스트명으로 직접 검증하려면 SAN이 필요하다. 에이전트는 A의 private IP:6443으로 조인하므로 private IP도 포함.
- Alternatives considered: 공인 IP를 SAN에 추가(6443을 공개하지 않으므로 불필요).
- Source: <https://docs.k3s.io/cli/server>

**K3S-D5. 에이전트(B) 조인 토큰은 어떤 형식·경로로 전달하는가?**

- Decision: A의 `/var/lib/rancher/k3s/server/token`(보안 형식 `K10<CA-hash>::server:<pw>`)을 OpenTofu/Vault 경유로 B의 `/etc/rancher/k3s/token`(0600)에 배치하고 config.yaml에 `token-file`을 쓴다. 첫 서버는 `token`을 짧은 형식(비밀번호만)으로 미리 지정한다.
- Rationale: 보안 형식은 조인 전에 클러스터 CA 해시를 검증해 MITM을 막는다. 첫 서버는 CA 생성 전이라 짧은 형식만 가능(문서 경고). 서버 토큰은 datastore bootstrap 데이터의 PBKDF2 암호이므로 백업 세트에도 반드시 포함.
- Alternatives considered: `k3s token create`로 만료형 bootstrap 토큰(더 안전하지만 재조인 자동화가 복잡); `K3S_TOKEN` 환경변수(systemd env 파일에 평문 잔존).
- Source: <https://docs.k3s.io/cli/token>

**K3S-D6. 번들 Traefik을 어떻게 커스터마이즈하고(HelmChartConfig) 어떤 값 키를 쓰는가?**

- Decision: `/var/lib/rancher/k3s/server/manifests/traefik-config.yaml`에 `HelmChartConfig{name: traefik, ns: kube-system}` 하나로 nodeSelector(role=platform), JSON 로그(`logs.general.format`/`logs.access.*`), OTLP gRPC 트레이싱(`tracing.otlp.grpc` → Alloy), web→websecure 리다이렉트(`ports.web.http.redirections.entryPoint`), `ports.websecure.forwardedHeaders.trustedIPs=[10.42.0.0/16]`, `tlsOptions.default.clientAuth`(mTLS)를 설정한다. 값 키는 반드시 chart 40.1.x values.yaml 기준.
- Rationale: traefik.yaml 원본은 K3s가 시작 때마다 재작성하므로 편집 금지, HelmChartConfig의 valuesContent가 추가 values 파일로 helm에 전달된다. K3s v1.36.4 번들 chart 40.1.x는 `logs.general`/`logs.access`(하위 `fields.headers.defaultmode` 소문자)이고 upstream 41.x는 `log`/`accessLog`/`defaultMode`로 바뀌어 최신 문서를 그대로 붙이면 무시된다. chart 40.0에서 provider 이름이 `kubernetesIngressNGINX`로 바뀐 breaking change도 릴리스 노트에 명시.
- Alternatives considered: `--disable traefik` 후 Argo CD로 upstream chart 41.x 설치(최신이지만 K3s 업그레이드와 이중 관리, CRD 소유권 충돌); Gateway API 활성(`providers.kubernetesGateway.enabled`, 현 설계 불필요).
- Source: <https://docs.k3s.io/helm#customizing-packaged-components-with-helmchartconfig>

**K3S-D7. Cloudflare Authenticated Origin Pulls를 Traefik에서 어떻게 강제하는가?**

- Decision: Global AOP(존 설정 `tls_client_auth=on`, Cloudflare 제공 CA `authenticated_origin_pull_ca.pem`)를 쓰고, Traefik에는 kube-system Secret(`ca.crt` 키)을 참조하는 `TLSOption/default`(`clientAuthType: RequireAndVerifyClientCert`, `minVersion: VersionTLS12`, `sniStrict: true`)를 chart `tlsOptions.default`로 생성한다.
- Rationale: 이름이 `default`인 TLSOption은 클러스터 전체에 하나만 존재하며 별도 참조 없이 모든 TLS 라우터에 적용된다. Traefik은 Secret의 `tls.ca` 또는 `ca.crt`에서 CA를 읽고, Secret은 TLSOption과 같은 네임스페이스여야 한다. Global AOP CA는 'Cloudflare 네트워크에서 왔다'만 보장하므로 OCI 보안 리스트의 Cloudflare IP 한정과 겹쳐서 방어한다.
- Alternatives considered: Zone-level AOP(자체 CA로 leaf 발급·업로드, 계정 전용이라 더 엄격하지만 인증서 수명 관리 필요 — 2단계 강화 후보); 라우터별 `tls.options` 참조(누락 위험).
- Source: <https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/set-up/global/>

**K3S-D8. local-path-provisioner 경로·노드 고정을 어떻게 다루는가?**

- Decision: 기본 경로 `/var/lib/rancher/k3s/storage`를 유지하되 데이터 노드 B에는 별도 블록 볼륨을 그 경로에 마운트한다(경로를 바꿀 때만 `default-local-storage-path`). PV의 노드 고정은 파드 `nodeSelector: {role: data}`로 결정하고 `local-path-config` ConfigMap은 편집하지 않는다.
- Rationale: StorageClass는 WaitForFirstConsumer라 파드가 처음 스케줄된 노드에 PV가 생성되고 `kubernetes.io/hostname` nodeAffinity로 영구 고정된다(노드 간 이동 불가, reclaim Delete). local-storage.yaml은 K3s가 시작마다 다시 쓰는 패키지 manifest이므로 ConfigMap 직접 편집은 되돌아간다.
- Alternatives considered: Longhorn(2노드·arm64에 과중); `--default-local-storage-path /data/local-path`로 경로 분리(허용, 취향).
- Source: <https://docs.k3s.io/storage>

**K3S-D9. SQLite 데이터스토어 백업은 어떻게 하는가 (etcd-snapshot 불가)?**

- Decision: systemd timer가 `sqlite3 state.db ".backup"`으로 온라인 스냅샷을 뜬 뒤 `server/token`과 `server/cred/`를 함께 tar → OCI Object Storage(S3 호환)로 업로드(rclone/oci-cli). 복원은 k3s 정지 → `server/db/` 교체 → 같은 token → 기동.
- Rationale: 공식 문서는 `/var/lib/rancher/k3s/server/db/` 복사 + token 보존만 요구하고 `k3s etcd-snapshot`은 embedded etcd 전용이다. kine SQLite DSN이 `_journal_mode=WAL`이라 실행 중 파일 복사는 -wal 누락 위험이 있어 sqlite3 백업 API가 일관적이다. token이 다르면 bootstrap 데이터 복호화가 불가해 스냅샷이 무용.
- Alternatives considered: `systemctl stop k3s` 후 tar(가장 단순, 제어평면 수십 초 중단); Litestream(kine에 `_kine_disable_wal_autocheckpoint` 등 호환 옵션은 있으나 K3s DSN 전달 경로 미확인).
- Source: <https://docs.k3s.io/datastore/backup-restore>

**K3S-D10. K3s 자동 업그레이드 창(system-upgrade-controller)을 어떻게 구성하는가?**

- Decision: SUC v0.20.1(crd.yaml + system-upgrade-controller.yaml)을 Argo CD platform AppProject로 설치하고 server-plan/agent-plan 두 Plan을 `channel: https://update.k3s.io/v1-release/channels/v1.36` + `window: {days:[sunday], startTime:03:00, endTime:05:00, timeZone:Asia/Seoul}` + `concurrency:1, cordon:true`로 둔다. agent-plan은 `prepare: [prepare, server-plan]`으로 서버 완료를 기다린다.
- Rationale: 마이너 채널(v1.36)은 skew 정책 위반(마이너 건너뜀)을 막으면서 패치만 자동 승격한다. window는 Job 생성만 제한하고 진행 중 Job은 창을 넘겨도 계속된다. k3s-upgrade 이미지는 다운그레이드를 거부하고 실패 시 cordon 상태가 남는다. 이미지(rancher/k3s-upgrade, SUC) 모두 linux/arm64 제공.
- Alternatives considered: `version: v1.36.x+k3s1` 고정 + Renovate PR(더 GitOps적이지만 Renovate에 K3s 채널 datasource 구성이 필요); stable 채널(마이너 자동 상승 → skew·Traefik chart breaking 노출).
- Source: <https://docs.k3s.io/upgrades/automated>

**K3S-D11. Ubuntu 24.04(OCI 이미지) 호스트 사전 설정은 무엇이 필요한가?**

- Decision: (1) ufw는 건드리지 않고(비활성 확인만) OCI 이미지의 `/etc/iptables/rules.v4`에서 마지막 `INPUT/FORWARD ... REJECT` 두 줄 앞에 K3s 포트·파드 CIDR 규칙을 삽입 후 `netfilter-persistent reload`; `InstanceServices` 체인·iSCSI 규칙은 보존. (2) OCI 보안 리스트(또는 NSG)에 서브넷 내부 6443/tcp, 8472/udp, 10250/tcp와 Cloudflare IP→443 허용. (3) cgroup v2 확인(`stat -fc %T /sys/fs/cgroup/` = cgroup2fs). (4) iptables 1.8.10(nft)은 그대로 사용, `--prefer-bundled-bin` 불필요. (5) `sqlite3` 패키지 설치(백업용).
- Rationale: OCI Ubuntu 이미지는 iptables-persistent로 22·ICMP·NTP만 열고 나머지를 REJECT하며 규칙을 뒤에 붙이면 무시된다; Oracle 문서는 Ubuntu 이미지에서 UFW로 규칙을 편집하면 부팅 실패할 수 있다고 경고한다. OCI 보안 리스트는 VNIC 단위로 적용되어 같은 서브넷 내부 통신에도 규칙이 필요하고 기본은 22·ICMP만 허용. Ubuntu 21.10+는 cgroup v2 기본이며 kubelet 1.35+는 v1에서 기동을 거부. K3s known-issues의 문제 버전은 iptables 1.8.0–1.8.4.
- Alternatives considered: iptables 전부 flush(`iptables -F`, 블로그들이 권하지만 iSCSI/메타데이터 규칙까지 지워 위험); firewalld(Ubuntu 비표준).
- Source: <https://docs.k3s.io/installation/requirements>

### 설정 스니펫

**노드 A(server, role=platform) — /etc/rancher/k3s/config.yaml + 설치 명령** — <https://docs.k3s.io/installation/configuration>
```
# /etc/rancher/k3s/config.yaml  (cloud-init/OpenTofu가 배치)
write-kubeconfig-mode: "0600"
token-file: /etc/rancher/k3s/token        # 첫 서버는 짧은 형식(비밀번호)만 가능
tls-san:
  - "10.0.0.11"                          # A private IP
  - "k3s.joshuatech.dev"                 # cloudflared 터널 호스트명
node-label:
  - "role=platform"
  - "svccontroller.k3s.cattle.io/enablelb=true"   # ServiceLB allow-list → svclb 파드는 A에만
secrets-encryption: true
secrets-encryption-provider: secretbox
flannel-backend: vxlan
# node-external-ip 는 설정하지 않음 (ServiceLB NAT 알려진 이슈)
# disable 없음: coredns/servicelb/traefik/local-storage/metrics-server 유지

# 설치 (버전 고정)
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.36.4+k3s1" INSTALL_K3S_EXEC="server" sh -s -
# 확인
k3s secrets-encrypt status
cat /var/lib/rancher/k3s/server/token   # K10<ca-hash>::server:<pw>  → B에 전달
```

**노드 B(agent, role=data) — config.yaml + 설치 명령** — <https://docs.k3s.io/cli/agent>
```
# /etc/rancher/k3s/config.yaml
server: https://10.0.0.11:6443
token-file: /etc/rancher/k3s/token        # A의 server/token (보안 형식, 0600)
node-label:
  - "role=data"

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.36.4+k3s1" INSTALL_K3S_EXEC="agent" sh -s -
# (K3S_URL 환경변수를 주면 EXEC 생략 시에도 agent가 기본)
kubectl get nodes -L role,svccontroller.k3s.cattle.io/enablelb
```

**번들 Traefik HelmChartConfig (chart 40.1.x 키) — 노드 고정·JSON 로그·OTLP·리다이렉트·XFF 신뢰·mTLS** — <https://raw.githubusercontent.com/traefik/traefik-helm-chart/v40.1.0/traefik/values.yaml>
```
# /var/lib/rancher/k3s/server/manifests/traefik-config.yaml   (파일명: 밑줄 금지, 유일해야 함)
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    nodeSelector:
      role: platform
    logs:                      # 40.x 키. upstream 41.x 는 log/accessLog 로 바뀜
      general:
        format: json
        level: INFO
      access:
        enabled: true
        format: json
        fields:
          general:
            defaultmode: keep
          headers:
            defaultmode: drop
            names:
              CF-Connecting-IP: keep
              CF-Ray: keep
              User-Agent: keep
    tracing:
      serviceName: traefik
      sampleRate: 0.1
      otlp:
        enabled: true
        grpc:
          enabled: true
          endpoint: alloy.monitoring.svc.cluster.local:4317
          insecure: true
    ports:
      web:
        http:
          redirections:
            entryPoint:
              to: websecure
              scheme: https
              permanent: true
      websecure:
        forwardedHeaders:
          trustedIPs:
            - 10.42.0.0/16      # svclb 파드가 MASQUERADE → Cloudflare X-Forwarded-* 를 신뢰하려면 필요
        http:
          tls:
            enabled: true
    tlsOptions:                # → TLSOption/default (kube-system), 모든 TLS 라우터에 자동 적용
      default:
        minVersion: VersionTLS12
        sniStrict: true
        clientAuth:
          secretNames:
            - cloudflare-origin-pull-ca
          clientAuthType: RequireAndVerifyClientCert
---
# CA Secret (공개 CA이므로 bootstrap manifest로 배치 가능; 같은 ns 필수, 키 ca.crt 또는 tls.ca)
# curl -sSO https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem
# kubectl -n kube-system create secret generic cloudflare-origin-pull-ca --from-file=ca.crt=authenticated_origin_pull_ca.pem
```

**OCI Ubuntu 이미지 /etc/iptables/rules.v4 — REJECT 앞 삽입 규칙** — <https://docs.oracle.com/en-us/iaas/Content/Compute/References/images.htm>
```
# 기존 파일(iptables-persistent)의 마지막 두 줄
#   -A INPUT -j REJECT --reject-with icmp-host-prohibited
#   -A FORWARD -j REJECT --reject-with icmp-host-prohibited
# 바로 *앞*에 삽입 (뒤에 붙이면 무시됨). InstanceServices 체인/iSCSI 규칙은 그대로 둔다.
-A INPUT -s 10.0.0.0/24 -p tcp -m state --state NEW -m multiport --dports 6443,10250 -j ACCEPT   # 서브넷 내부: API/supervisor, kubelet
-A INPUT -s 10.0.0.0/24 -p udp --dport 8472 -j ACCEPT                                          # Flannel VXLAN (절대 외부 공개 금지)
-A INPUT -s 10.42.0.0/16 -j ACCEPT                                                              # 파드 → 호스트(hostPort svclb, kubelet)
-A INPUT -s 10.43.0.0/16 -j ACCEPT
# 노드 A만: Cloudflare→443 (OCI 보안 리스트에서 이미 Cloudflare IP 한정, 80은 리다이렉트용)
-A INPUT -p tcp -m state --state NEW -m multiport --dports 80,443 -j ACCEPT
-A FORWARD -s 10.42.0.0/16 -j ACCEPT
-A FORWARD -d 10.42.0.0/16 -j ACCEPT

# 적용
sudo netfilter-persistent reload      # 또는 iptables-restore < /etc/iptables/rules.v4
sudo ufw status                       # inactive 여야 함 — OCI 문서: Ubuntu 이미지에서 UFW로 규칙 편집 금지
stat -fc %T /sys/fs/cgroup/           # cgroup2fs
```

**system-upgrade-controller v0.20.1 + Plan(창: 일요일 03–05 KST, v1.36 채널)** — <https://docs.k3s.io/upgrades/automated>
```
kubectl apply -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.20.1/crd.yaml \
              -f https://github.com/rancher/system-upgrade-controller/releases/download/v0.20.1/system-upgrade-controller.yaml
---
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata: {name: server-plan, namespace: system-upgrade}
spec:
  concurrency: 1
  cordon: true
  nodeSelector:
    matchExpressions:
      - {key: node-role.kubernetes.io/control-plane, operator: In, values: ["true"]}
  serviceAccountName: system-upgrade
  upgrade: {image: rancher/k3s-upgrade}
  channel: https://update.k3s.io/v1-release/channels/v1.36   # 패치만 자동, 마이너 승격은 수동
  window:
    days: [sunday]
    startTime: "03:00"
    endTime: "05:00"
    timeZone: Asia/Seoul
---
apiVersion: upgrade.cattle.io/v1
kind: Plan
metadata: {name: agent-plan, namespace: system-upgrade}
spec:
  concurrency: 1
  cordon: true
  nodeSelector:
    matchExpressions:
      - {key: node-role.kubernetes.io/control-plane, operator: DoesNotExist}
  prepare: {image: rancher/k3s-upgrade, args: [prepare, server-plan]}
  serviceAccountName: system-upgrade
  upgrade: {image: rancher/k3s-upgrade}
  channel: https://update.k3s.io/v1-release/channels/v1.36
  window: {days: [sunday], startTime: "03:00", endTime: "05:00", timeZone: Asia/Seoul}
# 모니터링: kubectl -n system-upgrade get plans -o wide; kubectl -n system-upgrade get jobs
```

**SQLite 데이터스토어 백업 스크립트(systemd timer용) — etcd-snapshot 대체** — <https://docs.k3s.io/datastore/backup-restore>
```
#!/bin/sh
# /usr/local/sbin/k3s-sqlite-backup.sh  (apt-get install -y sqlite3)
set -eu
S=/var/lib/rancher/k3s/server
TS=$(date -u +%Y%m%dT%H%M%SZ); OUT=/var/backups/k3s/$TS; mkdir -p "$OUT"
sqlite3 "$S/db/state.db" ".backup '$OUT/state.db'"   # WAL 모드에서도 일관된 온라인 스냅샷
cp -p  "$S/token" "$OUT/token"                          # 없으면 복원 불가(bootstrap 데이터 PBKDF2 키)
cp -rp "$S/cred"  "$OUT/cred"                           # encryption-config.json 포함(안전 여유분)
tar -C /var/backups/k3s -czf "/var/backups/k3s/k3s-$TS.tgz" "$TS" && rm -rf "$OUT"
# rclone copy /var/backups/k3s/k3s-$TS.tgz oci:k3s-backup/   (OCI Object Storage S3 호환)

# 복원: systemctl stop k3s → $S/db/ 비우고 state.db 복사 → token 동일 유지(또는 --token) → systemctl start k3s
```

**secrets-encryption 키 회전(단일 서버) 절차** — <https://docs.k3s.io/cli/secrets-encrypt>
```
k3s secrets-encrypt status
k3s secrets-encrypt rotate-keys          # prepare+rotate+reencrypt 자동, ~5 secrets/s
journalctl -u k3s -f | grep -i reencrypt # 'reencrypt_finished' 확인
systemctl restart k3s                    # 동일 인자로 재시작 필수
# provider 변경(aescbc→secretbox)도 config.yaml 수정 후 위 절차
```

### 함정

- Traefik 값 키 세대 차이: K3s v1.36.4 번들 chart 40.1.x는 `logs.general`/`logs.access`(하위 `fields.headers.defaultmode` 소문자), upstream 41.x는 `log`/`accessLog`/`defaultMode`. 최신 문서/VALUES.md를 복붙하면 조용히 무시된다. 리다이렉트 키도 `ports.web.http.redirections.entryPoint.{to,scheme,permanent}`.
- chart 40.0 breaking: ingress-nginx 호환 provider 이름이 `kubernetesIngressNginx`→`kubernetesIngressNGINX`로 바뀜(K3s 릴리스 노트 경고). 사용하지 않더라도 values에 옛 키가 있으면 실패.
- klipper-lb(svclb)는 iptables DNAT+MASQUERADE로 전달하므로 Traefik이 보는 원격 IP는 svclb 파드 IP(10.42/16). `forwardedHeaders.trustedIPs`에 10.42.0.0/16을 넣지 않으면 Cloudflare의 X-Forwarded-For가 버려지고 접근 로그·ipStrategy 미들웨어가 svclb IP를 본다. 앱은 CF-Connecting-IP를 쓰되, mTLS(default TLSOption)가 websecure를 지키므로 클러스터 내부 XFF 스푸핑도 차단됨. 반면 web(80)은 mTLS가 없으니 리다이렉트 전용으로만 둘 것.
- `--node-external-ip`를 주면(OCI 공인 IP는 NAT) ServiceLB의 externalTrafficPolicy=Local이 오동작한다는 공식 경고. 미설정 시 Ingress status에는 private IP만 표시되나 DNS는 OpenTofu가 관리하므로 무해.
- `node-label`은 kubelet 등록 시 1회만 적용된다. 나중에 config.yaml을 바꿔도 반영되지 않고, `kubectl label`로 바꾼 값과 config 값이 어긋난다. 첫 부팅 전에 확정할 것.
- secrets-encryption은 서버 재시작 없이 켤 수 없고, provider 변경/키 회전은 rotate-keys 후 서버 재시작이 필수. 처음부터 secretbox로 시작해 마이그레이션 비용을 없앨 것. Kubernetes 문서는 aescbc를 padding-oracle 취약으로 'Not recommended' 표기.
- `k3s etcd-snapshot`은 embedded etcd 전용 — SQLite에서는 no-op. kine SQLite는 `_journal_mode=WAL`이므로 실행 중 state.db만 복사하면 -wal 내용이 빠진다(디렉터리 전체 복사 또는 sqlite3 `.backup`). server/token 없이는 복원 불가.
- local-path PV는 `kubernetes.io/hostname` nodeAffinity로 영구 고정되고 노드 간 이동 불가, reclaim 기본 Delete(PVC 삭제 = 데이터 삭제). `local-path-config` ConfigMap은 K3s 패키지 manifest(local-storage.yaml)에 속해 K3s 재시작 시 재작성되므로 직접 편집이 되돌아감 — 경로 변경은 `default-local-storage-path`로만.
- OCI Ubuntu 이미지 호스트 방화벽: `/etc/iptables/rules.v4`가 22/ICMP/NTP 외 INPUT과 FORWARD 전체를 REJECT한다. K3s 포트(6443, 8472/udp, 10250)와 파드 CIDR 규칙을 REJECT 앞에 넣지 않으면 노드 B 조인·VXLAN·metrics-server가 실패하고, 뒤에 붙이면 무시된다. Oracle 문서: Ubuntu 이미지에서 UFW로 규칙 편집 시 부팅 실패 가능, iSCSI(169.254.0.2:3260 등)·InstanceServices 규칙 제거 금지.
- OCI 보안 리스트는 서브넷 단위로 설정되지만 VNIC 단위로 적용되어 같은 서브넷 두 노드 사이에도 규칙이 필요하다(기본 목록은 22/tcp와 ICMP만). 6443/8472udp/10250을 서브넷 CIDR 소스로 열고, 8472/udp는 절대 0.0.0.0/0에 열지 말 것(문서 경고: 클러스터 네트워크 노출).
- OCI Ubuntu 24.04 aarch64 이미지의 커널은 linux-oracle-6.17(6.17.0-10xx-oracle). 커널 6.17부터 AppArmor ABI 변화로 containerd 기본 프로파일이 unix 소켓을 막던 문제(containerd#12726, Argo CD repo-server 등에서 발현)는 containerd 2.3.x의 `abi <abi/3.0>` 고정(#12864/#13268)으로 해결되어 K3s v1.36.4(containerd v2.3.4-k3s1.36)에는 포함됨. 그러나 stacked-profile signal DENIED(containerd#12886, `kubectl exec`·exec 프로브에서 `cri-containerd.apparmor.d//&unconfined` peer 불일치)는 2026-07 기준 미해결(open PR #12887/#13905). Ubuntu 26.04/25.10(parser 5.0)에서 재현되며 24.04(apparmor 4.0.x)에서는 재현 조건이 불확실 — 배포 후 dmesg `apparmor="DENIED" ... signal=urg` 모니터링 필요. 임시 우회: `/etc/apparmor/parser.conf`에 `override-policy-abi=/etc/apparmor.d/abi/4.0`(AppArmor 업스트림 #561) 또는 해당 파드 `securityContext.appArmorProfile: {type: Unconfined}`.
- kubelet 1.35+는 cgroup v1 노드에서 기동을 거부(`failCgroupV1` 기본). Ubuntu 24.04는 v2 기본이지만 커스텀 커널 파라미터(systemd.unified_cgroup_hierarchy=0)가 없는지 확인.
- system-upgrade-controller: window는 Job 생성만 막고 진행 중 Job은 창을 넘겨도 계속됨. 단일 서버라 server-plan 실행 중 API가 수십 초~수 분 중단(파드는 계속 실행). k3s-upgrade는 다운그레이드를 거부하며 실패 시 `cordon: true` 노드가 cordon 상태로 남는다(Plan 삭제 후 `kubectl uncordon`). `channel` 사용 시 GitOps 밖에서 버전이 바뀌므로 Renovate/변경 이력과 이중 관리됨.
- `/var/lib/rancher/k3s/server/manifests`의 AddOn 파일은 basename이 AddOn 이름(RFC1123: 밑줄 불가, 패키지 이름과 충돌 금지)이고, 파일을 지워도 리소스는 지워지지 않는다. HelmChart `spec.set` 값은 HelmChartConfig valuesContent보다 우선(K3s가 `global.systemDefaultRegistry`를 set으로 넣음).
- Traefik이 kube-system에서 CriticalAddonsOnly/control-plane toleration으로 뜨지만 nodeSelector가 없으면 B에도 갈 수 있다 → `nodeSelector: {role: platform}` 필수. ServiceLB의 enablelb 라벨과 Traefik 파드 nodeSelector는 별개 메커니즘.
- Ubuntu 24.04 iptables 1.8.10(nft 모드)은 K3s known-issues의 문제 범위(1.6.1 이하 nft, 1.8.0–1.8.4) 밖. `--prefer-bundled-bin`은 불필요하지만 문서상 번들 버전은 v1.8.8로 표기되어 있어 호스트 버전이 더 새롭다.
- Cloudflare Global AOP CA는 모든 Cloudflare 계정이 공유(『Cloudflare 네트워크 유래』만 보장). 존 전용 보증이 필요하면 Zone-level AOP(자체 CA·leaf 업로드, 만료 알림 설정)로 올릴 것. `tls_client_auth` 존 설정(Global)과 Zone-level enablement 엔드포인트는 서로 다른 API.

### 미확인

- OCI Ubuntu 24.04 2026.07 이미지의 실제 `/etc/iptables/rules.v4` 내용(특히 `-A FORWARD -j REJECT` 존재)과 flannel v0.28/kube-proxy가 FORWARD 규칙을 REJECT 앞에 넣는지 — Oracle 개발자 블로그(1차 출처)가 403이라 bluemap 인용본으로만 확인. 인스턴스 재이미지 후 `iptables -S FORWARD`로 실측 필요.
- 커널 6.17 + Ubuntu 24.04 AppArmor 4.0.x 조합에서 containerd#12886(stacked profile signal DENIED)이 실제 재현되는지, 재현 시 SIGURG 외 기능 영향(exec 프로브 실패 등)이 있는지.
- `server/cred/encryption-config.json`이 bootstrap 데이터로 datastore에 함께 저장되어 db+token만으로 복원되는지(문서는 db+token만 언급). 확인 전까지 백업 세트에 cred/ 포함.
- kine의 Litestream 호환 옵션(`_kine_disable_wal_autocheckpoint` 등)을 K3s `--datastore-endpoint` SQLite DSN으로 전달해 OCI Object Storage로 연속 복제할 수 있는지(대안 백업 경로).
- K3s 문서의 번들 iptables v1.8.8 표기가 v1.36.4 실제 번들 버전과 같은지(호스트 1.8.10 사용 시 무관).
- k3s-charts 리팩 `traefik-40.1.4+up40.1.0`이 upstream 40.1.0 values와 완전히 동일한지(동일 가정으로 스니펫 작성).
- Cloudflare 'Always Use HTTPS' 사용 시 오리진 80 포트를 아예 열지 않아도 되는지(현재 스니펫은 80/443 모두 허용).
- Renovate가 update.k3s.io 채널 또는 GitHub 릴리스로 `Plan.spec.version`을 자동 갱신하는 datasource 구성(version 고정 대안 채택 시).
- 2 OCPU/13 GB 노드 A에 K3s server + Traefik + Argo CD + Vault + Strimzi + Authentik + OpenFGA + Alloy + cloudflared를 올릴 때 메모리 요청 합계·kubelet system-reserved 값 — R1 범위 밖, 리소스 프로파일링 주제.


## R2 Argo CD

R2: Argo CD 3.5.x 설치·GitOps 구조 (kustomize 설치·app-of-apps·AppProject·Helm values·Authentik SSO·알림·소규모 리소스)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| Argo CD (server/controller/repo-server/notifications 이미지 quay.io/argoproj/argocd, arm64 멀티아치) | v3.5.2 | 2026-08-27 | <https://github.com/argoproj/argo-cd/releases/tag/v3.5.2> |
| Argo CD 3.5 minor 최초 릴리스 (Helm 4, repo-server mTLS 옵션, Source Integrity, ApplicationSet any-namespace, React 19 UI) | v3.5.0 | 2026-08-04 | <https://github.com/argoproj/argo-cd/releases/tag/v3.5.0> |
| Argo CD 3.4 계열 최신 패치 (롤백 후보) | v3.4.8 | 2026-08-27 | <https://github.com/argoproj/argo-cd/releases> |
| argocd CLI (서버와 동일 태그 사용; linux-arm64·windows-amd64 바이너리 제공) | v3.5.2 | 2026-08-27 | <https://github.com/argoproj/argo-cd/releases/tag/v3.5.2> |
| repo-server 번들 Helm (3.5부터 Helm 4 단일 바이너리, spec.source.helm.version 무시) | 4.2.1 (hack/tool-versions.sh@v3.5.2; 업그레이드 문서는 4.2.0 표기) |  | <https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/hack/tool-versions.sh> |
| repo-server 번들 Kustomize | 5.8.1 |  | <https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/hack/tool-versions.sh> |
| Dex (install.yaml 포함, 본 설계에서는 제거) ghcr.io/dexidp/dex | v2.45.1 |  | <https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/base/dex/argocd-dex-server-deployment.yaml> |
| Redis (install.yaml, public.ecr.aws/docker/library/redis 미러) | 8.2.3-alpine |  | <https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/base/redis/argocd-redis-deployment.yaml> |
| Argo CD 3.5 테스트된 Kubernetes (K3s v1.36 포함) | v1.36, v1.35, v1.34, v1.33 |  | <https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/> |
| Notifications 트리거/템플릿 카탈로그 (notifications_catalog/install.yaml, 서버 태그와 동일) | v3.5.2 | 2026-08-27 | <https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/notifications_catalog/install.yaml> |
| Application 레벨 Prune=confirm / Delete=confirm syncOption (PR #23370, milestone v3.3) | v3.3+ | 2026-03-13 (merge) | <https://github.com/argoproj/argo-cd/pull/23370> |
| Server-Side Diff (controller.diff.server.side) Stable | v3.1.0+ |  | <https://argo-cd.readthedocs.io/en/stable/user-guide/diff-strategies/> |
| argo-helm chart argo-cd (대안 경로, 미채택) appVersion v3.5.2 | 10.5.0 | 2026-08-31 | <https://raw.githubusercontent.com/argoproj/argo-helm/main/charts/argo-cd/Chart.yaml> |
| authentik 공식 Argo CD 통합 가이드 (Dex 커넥터 기반; 본 설계는 oidc.config 직결) | integrations.goauthentik.io/infrastructure/argocd (2026-09 기준) |  | <https://integrations.goauthentik.io/infrastructure/argocd/> |

### 결정

**ARGOCD-D1. 설치 베이스: install.yaml(=cluster-install) vs core-install.yaml, 그리고 kustomize remote base 형식**

- Decision: `https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml`을 kustomize resources로 핀 고정하고, dex·applicationset-controller는 `$patch: delete`로 제거. core-install은 채택하지 않음.
- Rationale: core-install kustomization은 crds + cluster-rbac/application-controller + base/{config,application-controller,applicationset-controller,repo-server,redis}만 포함 — argocd-server(UI/API), notifications-controller, dex가 없어 SSO·알림·UI 요구를 못 채움. install.yaml은 base 8개 컴포넌트(application-controller, dex, repo-server, server, config, redis, notification, applicationset-controller) + cluster RBAC + CRD. 공식 문서도 'remote resource + kustomize patches' 방식을 권장. `github.com/argoproj/argo-cd//manifests/cluster-install?ref=v3.5.2` 형식도 동일 결과지만 repo-server가 대형 git 저장소를 clone해야 하므로 raw 단일 파일 URL이 가볍다.
- Alternatives considered: (a) argo-helm chart argo-cd 10.5.0 — `dex.enabled=false`, `applicationSet.enabled=false` 토글이 편하지만 문서·자가관리 예제와 다른 두 번째 템플릿 계층이 생김. (b) core-install + 별도 server 추가 — 문서화되지 않은 조합. (c) namespace-install — 단일 클러스터라 cluster-admin 회피 이점 없음.
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/>

**ARGOCD-D2. dex·applicationset-controller를 kustomize로 끄는 방법**

- Decision: 삭제 대상 리소스를 개별 `$patch: delete` 인라인 패치로 제거: dex 6종(Deployment/Role/RoleBinding/ServiceAccount/Service/NetworkPolicy `argocd-dex-server*`), applicationset 6종 ns 리소스 + ClusterRole/ClusterRoleBinding `argocd-applicationset-controller`. CRD `applicationsets.argoproj.io`는 유지(무해, CLI/RBAC 호환).
- Rationale: upstream 매니페스트에는 enable/disable 토글이 없고 `argocd-cmd-params-cm`에도 dex/applicationset 비활성 키가 없음(`server.dex.server`는 주소일 뿐). 삭제 패치는 kustomize 표준 기능. argocd-server는 `dex.config`가 없으면 dex를 호출하지 않음.
- Alternatives considered: replicas=0 패치(리소스는 남고 Argo UI에 Degraded 노이즈), chart 토글(위 결정 참조).
- Source: <https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/base/kustomization.yaml>

**ARGOCD-D3. ServerSideApply를 '기본값'으로 만드는 방법**

- Decision: 전역 키는 존재하지 않으므로 (1) 모든 Application(root·child)의 `syncPolicy.syncOptions`에 `ServerSideApply=true`를 규약으로 넣고 gitops repo CI에서 lint(없으면 실패), (2) `argocd-cmd-params-cm`에 `controller.diff.server.side: "true"`로 Server-Side Diff를 전역 활성화.
- Rationale: argocd-cm/argocd-cmd-params-cm 레퍼런스에 sync option 기본값 키가 없음; SSA는 Application 또는 리소스 annotation 단위로만 설정 가능. 자가관리 Argo CD는 SSA 필수(문서), ApplicationSet CRD·CNPG CRD는 client-side apply 262144바이트 annotation 한계를 넘음. Server-Side Diff(3.1 Stable)는 SSA와 짝을 이뤄 다른 필드 매니저가 추가한 필드(ESO Merge 키, 컨트롤러 default)로 인한 가짜 OutOfSync를 없앰.
- Alternatives considered: 리소스별 `argocd.argoproj.io/sync-options: ServerSideApply=true` annotation(누락 위험 큼), `Replace=true`(파괴적, SSA보다 우선 적용됨).
- Source: <https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/>

**ARGOCD-D4. app-of-apps 구성과 sync-wave 대기 조건**

- Decision: root Application `platform-root`(project platform, path `apps/`)가 child Application 매니페스트(plain YAML, kustomize)를 관리. child에 `argocd.argoproj.io/sync-wave`로 순서 부여(-20 argocd 자가관리 → -10 cert-manager/ESO → 0 Vault → 5 ClusterSecretStore → 10 CNPG/Strimzi/Dragonfly operator → 20 CNPG Cluster/Kafka → 30 Authentik/OpenFGA → 40 Alloy/cloudflared). `argocd-cm`에 `resource.customizations.health.argoproj.io_Application` Lua를 넣어 child 헬스를 root가 기다리게 함. 모든 Application에 `resources-finalizer.argocd.argoproj.io`.
- Rationale: Application CRD의 내장 헬스 평가는 1.8에서 제거되어 Lua 재등록 없이는 wave가 child 완료를 기다리지 않음. wave는 phase→wave→kind→name 순, 기본 wave 0, wave 간 2초 지연(`ARGOCD_SYNC_WAVE_DELAY`). finalizer가 있어야 root 삭제 시 cascade 정리.
- Alternatives considered: ApplicationSet git generator(설계상 컨트롤러 제거로 불가), Helm 차트로 child 생성(공식 예제 형식이지만 values 템플릿 계층 추가).
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/health/>

**ARGOCD-D5. AppProject 3개(platform/dev/prod) 경계와 default 무력화**

- Decision: `platform`: destinations in-cluster/`*` ns, clusterResourceWhitelist `*/*`, sourceRepos = platform-gitops + 사용하는 차트 저장소 URL만 열거. `dev`/`prod`: destinations `dev-*`/`prod-*` ns만, clusterResourceWhitelist 빈 값, namespaceResourceBlacklist(ResourceQuota/LimitRange/NetworkPolicy), sourceRepos = platform-gitops만. `default`는 sourceRepos/destinations 빈 배열 + `namespaceResourceBlacklist: '*'/'*'`로 봉인. 모든 프로젝트 `orphanedResources.warn: true`.
- Rationale: 공식 경고: 'Projects which can deploy to the Argo CD namespace grant admin access' — argocd ns 배포 권한은 platform에만. default 프로젝트는 '모든 repo·모든 클러스터·모든 kind'를 허용하므로 문서의 봉인 매니페스트 적용. multiple sources 사용 시 차트 저장소 URL도 sourceRepos에 있어야 sync 허용됨.
- Alternatives considered: sync impersonation(3.5 beta, AppProject.destinationServiceAccounts)으로 프로젝트별 SA 분리 — 단일 운영자 규모에서는 과함, SP-2 이후 검토.
- Source: <https://argo-cd.readthedocs.io/en/stable/user-guide/projects/>

**ARGOCD-D6. syncOptions 표준 세트(Prune=confirm/Delete=confirm 포함)**

- Decision: 공통: `ServerSideApply=true`, `CreateNamespace=true`, `PruneLast=true`, retry(limit 5, backoff 10s×2, max 3m). 상태 저장/프로덕션 앱(CNPG Cluster, Kafka, Vault, Authentik, prod-*) 및 root: `Prune=confirm`, `Delete=confirm` 추가. CRD가 이전 wave 다른 앱에서 오는 CR 전용 앱(ClusterIssuer/Certificate, ExternalSecret, KafkaTopic, CNPG Cluster)에만 `SkipDryRunOnMissingResource=true`.
- Rationale: `Prune=confirm`은 sync 중 Git에서 사라진 리소스 삭제 전 승인 대기(Progressing 유지), `Delete=confirm`은 Application 삭제 cascade 전 승인 대기; 승인은 UI/CLI 또는 `argocd.argoproj.io/deletion-approved: <ISO timestamp>` annotation. Application 레벨 지정은 v3.3+ — 리소스 annotation만 쓰면 앱 레벨 '확인' 버튼이 뜨지 않음(discussion #27569). SkipDryRun은 CRD가 이미 있으면 dry-run을 수행하므로 무해하지만, 남발하면 검증 누락.
- Alternatives considered: prod에 automated sync 미사용(수동 sync) — OutOfSync 알림 트리거로 보완 가능하나 selfHeal 이점 상실; `Prune=false`(정리 안 됨).
- Source: <https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/>

**ARGOCD-D7. Helm 차트 values 관리: multiple sources vs kustomize helmCharts**

- Decision: 기본은 multiple sources: source[0] = 차트 저장소(`chart`+`targetRevision` 핀, `helm.valueFiles: [$values/platform/<name>/values.yaml]`), source[1] = platform-gitops(`ref: values`, path 없음). 차트 출력에 post-render 패치(sync-wave annotation 주입, 리소스 삭제)가 꼭 필요한 컴포넌트만 kustomize `helmCharts`(+ argocd-cm `kustomize.buildOptions: --enable-helm`).
- Rationale: multiple sources는 repo-server 네이티브 Helm 렌더링(Helm 4), 차트 핀·values 파일 diff가 Git에 남고 UI에서 parameters 확인 가능. kustomize helmCharts는 kustomize가 helm 바이너리로 shell-out하는 '제한 지원' 기능이며 사설 저장소 인증 미지원, Helm 4 바이너리와의 호환은 미검증. 제약: `ref` source에는 `chart` 불가, values 경로는 `$values/`로 시작, path를 주면 그 repo도 매니페스트 생성 대상이 됨, 2–3개 초과 금지.
- Alternatives considered: umbrella chart(Chart.yaml dependency)로 values 관리 — 차트 lock 갱신 노동; `valuesObject` 인라인 — Application이 비대해지고 values 파일 diff 불가.
- Source: <https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/>

**ARGOCD-D8. Authentik OIDC SSO 방식(oidc.config vs Dex) 및 클라이언트 타입**

- Decision: Dex 제거 후 `argocd-cm.oidc.config` 직결. Authentik OAuth2 provider는 **Public** client + PKCE, redirect URI(Strict) 2개: `https://argocd.joshuatech.dev/auth/callback`, `http://localhost:8085/auth/callback`; issuer `https://auth.joshuatech.dev/application/o/argocd/`. Argo 측 `enablePKCEAuthentication: true`, clientSecret 없음, `requestedScopes: [openid, profile, email]`, `requestedIDTokenClaims: {groups: {essential: true}}`. 검증 후 `admin.enabled: "false"`. RBAC `policy.default: ""`, `scopes: '[groups, email]'`, `g, argocd-admins, role:admin`.
- Rationale: authentik 공식 가이드는 Dex 커넥터(`insecureEnableGroups`, scopes openid/profile/email) 경로라 Dex 제거 설계와 불일치. argocd CLI `--sso`는 서버 설정에서 clientID만 받아 client secret 없이 PKCE(S256)로 코드 교환 → confidential client면 CLI 로그인 실패. `cliClientID`로 두 번째 provider를 두면 Authentik의 provider별 issuer(`/application/o/<slug>/`)가 달라져 토큰 issuer 검증 불일치. Keycloak 문서에서 PKCE=public client·clientSecret 생략 확인. Authentik `profile` scope가 그룹 멤버십(groups claim)을 포함하므로 별도 groups scope 불필요. Secret이 필요 없어 'gitops repo에는 ExternalSecret만' 규칙과도 정합.
- Alternatives considered: Confidential client + clientSecret을 ESO 소유 Secret에 두고 `clientSecret: $argocd-oidc:clientSecret`(라벨 `app.kubernetes.io/part-of: argocd` 필요) 참조 — 브라우저 SSO는 되나 CLI는 `argocd --core`(kubectl 경유, RBAC/SSO 없음)로만; Dex 유지(추가 pod, authentik 가이드 그대로).
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/>

**ARGOCD-D9. 알림: Slack/Discord 서비스 정의와 OutOfSync 트리거**

- Decision: Slack은 `service.slack`(bot token `xoxb-`, scope `chat:write`, 채널에 봇 초대), Discord는 네이티브 서비스가 없으므로 `service.webhook.discord`(url `$discord-webhook-url`, Content-Type application/json, embeds body). 토큰은 ESO가 `argocd-notifications-secret`에 `creationPolicy: Merge`로 주입. 카탈로그(`notifications_catalog/install.yaml`) 설치 후 커스텀 `trigger.on-out-of-sync`(when `app.status.sync.status == 'OutOfSync'`, `oncePer: app.status.sync.revision`) 추가. 구독은 앱별 annotation 대신 CM `subscriptions`(전역, selector 가능)로 on-sync-failed/on-health-degraded/on-deployed/on-out-of-sync를 일괄 구독.
- Rationale: 지원 서비스 목록(AwsSqs, Email, GitHub, Slack, Mattermost, Opsgenie, Grafana, Webhook, Telegram, Teams, Google Chat, Rocket.Chat, Pushover, Alertmanager)에 Discord 없음 — discussion #22277에서 webhook 방식 동작 확인. 카탈로그 트리거는 모두 `oncePer: app.status.operationState?.syncResult?.revision`이며 OutOfSync 트리거는 없음. `oncePer`로 flapping 억제. `context.argocdUrl`로 링크 생성.
- Alternatives considered: Slack incoming webhook(`service.webhook.slack_webhook`) — 앱 토큰 없이 가능하나 thread/grouping(deliveryPolicy) 불가; Grafana Cloud Alerting 경유 — Argo 이벤트가 아닌 메트릭 기반이라 지연.
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/services/overview/>

**ARGOCD-D10. 단일 노드 소규모(≈20–30 Application) 메모리 requests/limits**

- Decision: 공식 권장 수치는 없으므로 커뮤니티 small 프로파일을 출발점으로: application-controller req 256Mi/lim 1Gi + `GOMEMLIMIT=900MiB`; repo-server 128Mi/512Mi; server 128Mi/512Mi; redis 32Mi/128Mi; notifications-controller 64Mi/256Mi (CPU req 50–100m, limit 미설정). 합계 요청 ≈ 600Mi. 운영 1주 후 `kubectl top`으로 재조정. `controller.status.processors: "10"`, `controller.operation.processors: "5"`, `controller.kubectl.parallelism.limit: "5"`, `reposerver.parallelism.limit: "2"`로 동시성 축소, 3.0 기본 `resource.exclusions`(Endpoints/Leases/TokenReview) 유지.
- Rationale: upstream 매니페스트는 requests/limits를 전혀 설정하지 않음. HA 문서: GOMEMLIMIT를 limit의 80–90%로 두면 OOMKill 전에 GC; processors/parallelism 축소는 메모리 스파이크를 시간축으로 분산(대신 sync 느려짐). argocd-operator 예시(controller 1Gi/2Gi 등)는 '권장값 아님' 명시. oneuptime small(≤50 apps): controller 256Mi/1Gi, repo-server 128Mi/512Mi, server 128Mi/512Mi, redis 64Mi/128Mi.
- Alternatives considered: VPA recommend 모드(추가 컴포넌트, 이 클러스터엔 없음); limit 미설정(노드 B 워크로드와 경합 시 OOM 위험을 노드 전체로 확산).
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/>

**ARGOCD-D11. Ingress·TLS·CLI 접근(Traefik + Cloudflare Access)**

- Decision: Traefik IngressRoute(websecure, cert-manager 와일드카드 secret) 2 rule(HTTP → :80, `Content-Type: application/grpc` → :80 scheme h2c) + `argocd-cmd-params-cm server.insecure: "true"`. CLI는 `argocd login argocd.joshuatech.dev --sso --grpc-web --header "CF-Access-Client-Id: …" --header "CF-Access-Client-Secret: …"`(Service Auth 토큰). 비상 경로는 cloudflared 터널 kubectl + `argocd --core`.
- Rationale: 공식 Traefik v3 예제 그대로; TLS를 Traefik이 종료하므로 서버 TLS off 필수. `--header` 플래그가 CLI 모든 요청에 헤더를 붙임(반복 가능). Cloudflare proxied 경유 gRPC는 grpc-web이 단순. core 모드는 RBAC/SSO/알림 없이 kubectl 권한으로 동작 — admin 전용 break-glass.
- Alternatives considered: argocd.joshuatech.dev를 Cloudflare Access 밖에 두고 Argo RBAC만 의존(공격면 증가); 터널 전용(퍼블릭 UI 없음 — 학습 공개 목적과 충돌).
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/>

**ARGOCD-D12. Git 변경 감지: 폴링 vs GitHub webhook**

- Decision: 초기에는 기본 3분 폴링(`timeout.reconciliation: 180s`) + Application `argocd.argoproj.io/manifest-generate-paths` annotation(모노레포 캐시 무효화 억제). GitHub webhook(`/api/webhook`, `webhook.github.secret`)은 Cloudflare Access bypass 정책 설계 후 SP-2에서 검토.
- Rationale: public repo·저빈도 커밋이라 3분 지연 허용. webhook은 Cloudflare Access 뒤라 GitHub 발신을 통과시키는 예외 정책이 필요. manifest-generate-paths는 v2.11+ webhook 없이도 동작.
- Alternatives considered: GitHub Actions에서 `argocd app get --refresh` 호출(CI에 Argo 자격증명 필요).
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/>

**ARGOCD-D13. Argo CD 자기 자신 관리(bootstrap → self-managed)**

- Decision: 최초 1회 `kubectl apply --server-side --force-conflicts -k platform/argocd/` 후 root Application 적용; child로 `argocd` Application(path `platform/argocd`, wave -20, `ServerSideApply=true`, `Prune=confirm`, `Delete=confirm`)을 두어 이후 업그레이드는 install.yaml URL 태그 변경 커밋으로 수행.
- Rationale: 공식 'Manage Argo CD Using Argo CD' 절: kustomize base + `ServerSideApply=true` 필수. 3.3 노트: ApplicationSet CRD가 client-side apply 한계를 초과하므로 bootstrap도 `--server-side --force-conflicts`.
- Alternatives considered: 수동 `kubectl apply`로만 업그레이드(GitOps 원칙 위반).
- Source: <https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/>

### 설정 스니펫

**platform/argocd/kustomization.yaml — remote base + dex/applicationset 삭제 + 패치** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/>
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: argocd
resources:
  - https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/manifests/install.yaml
  - ingressroute.yaml
  - projects.yaml
  - externalsecret-notifications.yaml
patches:
  - path: argocd-cm.yaml
  - path: argocd-cmd-params-cm.yaml
  - path: argocd-rbac-cm.yaml
  - path: argocd-notifications-cm.yaml
  - path: resources.yaml
  # dex 제거 (Deployment/Role/RoleBinding/ServiceAccount/Service/NetworkPolicy 6종, 동일 형식 반복)
  - target: {kind: Deployment, name: argocd-dex-server}
    patch: |-
      $patch: delete
      apiVersion: apps/v1
      kind: Deployment
      metadata: {name: argocd-dex-server}
  - target: {kind: NetworkPolicy, name: argocd-dex-server-network-policy}
    patch: |-
      $patch: delete
      apiVersion: networking.k8s.io/v1
      kind: NetworkPolicy
      metadata: {name: argocd-dex-server-network-policy}
  # applicationset-controller 제거 (ns 6종 + ClusterRole/ClusterRoleBinding argocd-applicationset-controller)
  - target: {kind: Deployment, name: argocd-applicationset-controller}
    patch: |-
      $patch: delete
      apiVersion: apps/v1
      kind: Deployment
      metadata: {name: argocd-applicationset-controller}
  - target: {kind: ClusterRoleBinding, name: argocd-applicationset-controller}
    patch: |-
      $patch: delete
      apiVersion: rbac.authorization.k8s.io/v1
      kind: ClusterRoleBinding
      metadata: {name: argocd-applicationset-controller}
```

**argocd-cmd-params-cm.yaml — TLS off, server-side diff, 소규모 동시성** — <https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/docs/operator-manual/argocd-cmd-params-cm.yaml>
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
data:
  server.insecure: "true"                 # Traefik이 TLS 종료
  controller.diff.server.side: "true"     # SSA와 짝, Stable(3.1+)
  controller.status.processors: "10"
  controller.operation.processors: "5"
  controller.kubectl.parallelism.limit: "5"
  reposerver.parallelism.limit: "2"
  reposerver.repo.cache.expiration: "1h"
```

**argocd-cm.yaml — URL, Authentik OIDC(PKCE public client), Application 헬스 Lua** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/>
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
data:
  url: https://argocd.joshuatech.dev
  admin.enabled: "false"               # SSO 검증 후 적용
  timeout.reconciliation: 180s
  # kustomize.buildOptions: --enable-helm   # kustomize helmCharts 쓸 때만
  oidc.config: |
    name: Authentik
    issuer: https://auth.joshuatech.dev/application/o/argocd/
    clientID: <authentik-client-id>
    enablePKCEAuthentication: true     # Public client → clientSecret 불필요, CLI --sso 동작
    requestedScopes: ["openid", "profile", "email"]   # Authentik profile에 groups 포함
    requestedIDTokenClaims: {"groups": {"essential": true}}
    logoutURL: https://auth.joshuatech.dev/application/o/argocd/end-session/
  resource.customizations.health.argoproj.io_Application: |
    hs = {}
    hs.status = "Progressing"
    hs.message = ""
    if obj.status ~= nil then
      if obj.status.health ~= nil then
        hs.status = obj.status.health.status
        if obj.status.health.message ~= nil then
          hs.message = obj.status.health.message
        end
      end
    end
    return hs
```

**argocd-rbac-cm.yaml — Authentik 그룹 → 역할, 기본 거부** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/rbac/>
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
data:
  policy.default: ""            # 빈 값 = 매핑 안 된 사용자는 거부
  scopes: "[groups, email]"
  policy.csv: |
    p, role:viewer, applications, get, */*, allow
    p, role:viewer, logs, get, */*, allow
    p, role:viewer, projects, get, *, allow
    g, argocd-admins, role:admin      # Authentik 그룹명 그대로
    g, argocd-viewers, role:viewer
```

**resources.yaml — controller(StatefulSet) requests/limits + GOMEMLIMIT (Deployment 4종도 동일 패턴)** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/high_availability/>
```
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: argocd-application-controller
spec:
  template:
    spec:
      containers:
        - name: argocd-application-controller
          env:
            - {name: GOMEMLIMIT, value: 900MiB}   # limit의 ~90%
          resources:
            requests: {cpu: 100m, memory: 256Mi}
            limits: {memory: 1Gi}
# Deployment 패치: argocd-repo-server(컨테이너 argocd-repo-server) 128Mi/512Mi,
#   argocd-server(argocd-server) 128Mi/512Mi, argocd-redis(redis) 32Mi/128Mi,
#   argocd-notifications-controller(argocd-notifications-controller) 64Mi/256Mi
```

**projects.yaml — default 봉인 + platform/dev/prod AppProject** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/>
```
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: {name: default, namespace: argocd}
spec:
  sourceRepos: []
  sourceNamespaces: []
  destinations: []
  clusterResourceWhitelist: []
  namespaceResourceBlacklist:
    - {group: "*", kind: "*"}
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: {name: platform, namespace: argocd}
spec:
  description: 플랫폼 컴포넌트 (argocd ns 배포 가능 = admin 등가, push 권한 관리자만)
  sourceRepos:
    - https://github.com/<org>/platform-gitops.git
    - https://charts.jetstack.io           # multiple sources의 차트 repo도 반드시 열거
    - https://charts.external-secrets.io
    - https://helm.releases.hashicorp.com
    - https://cloudnative-pg.github.io/charts
    - https://strimzi.io/charts/
    - https://charts.goauthentik.io
  destinations:
    - {server: https://kubernetes.default.svc, namespace: "*"}
  clusterResourceWhitelist:
    - {group: "*", kind: "*"}
  orphanedResources: {warn: true}
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata: {name: prod, namespace: argocd}   # dev는 namespace prod-* → dev-* 로 동일
spec:
  sourceRepos:
    - https://github.com/<org>/platform-gitops.git
  destinations:
    - {server: https://kubernetes.default.svc, namespace: "prod-*"}
  clusterResourceWhitelist: []
  namespaceResourceBlacklist:
    - {group: "", kind: ResourceQuota}
    - {group: "", kind: LimitRange}
    - {group: networking.k8s.io, kind: NetworkPolicy}
  orphanedResources: {warn: true}
```

**apps/root.yaml + child Application 3패턴 (wave, syncOptions, confirm, SkipDryRun)** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/>
```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-root
  namespace: argocd
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: platform
  source:
    repoURL: https://github.com/<org>/platform-gitops.git
    targetRevision: main
    path: apps                      # child Application 매니페스트(kustomize)
  destination: {server: https://kubernetes.default.svc, namespace: argocd}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [ServerSideApply=true, Prune=confirm, Delete=confirm]
---
# child 1: 오퍼레이터(CRD 포함) — 공통 세트
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  annotations: {argocd.argoproj.io/sync-wave: "-10"}
  finalizers: [resources-finalizer.argocd.argoproj.io]
spec:
  project: platform
  sources: []   # 아래 multiple sources 스니펫
  destination: {server: https://kubernetes.default.svc, namespace: cert-manager}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [ServerSideApply=true, CreateNamespace=true, PruneLast=true]
    retry:
      limit: 5
      backoff: {duration: 10s, factor: 2, maxDuration: 3m}
---
# child 2: 이전 wave의 CRD에 의존하는 CR만 담은 앱
metadata:
  name: cluster-issuers
  annotations: {argocd.argoproj.io/sync-wave: "-5"}
spec:
  syncPolicy:
    syncOptions: [ServerSideApply=true, SkipDryRunOnMissingResource=true]
---
# child 3: 상태 저장/프로덕션 — 삭제·prune 승인 필수 (승인: UI/CLI 또는
#   argocd.argoproj.io/deletion-approved: <ISO timestamp> annotation)
metadata:
  name: cnpg-cluster
  annotations: {argocd.argoproj.io/sync-wave: "20"}
spec:
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [ServerSideApply=true, CreateNamespace=true, SkipDryRunOnMissingResource=true, Prune=confirm, Delete=confirm]
```

**Helm 차트 Application — multiple sources ($values) / kustomize helmCharts 대안** — <https://argo-cd.readthedocs.io/en/stable/user-guide/multiple_sources/>
```
# (기본) multiple sources
spec:
  project: platform
  sources:
    - repoURL: https://charts.jetstack.io
      chart: cert-manager
      targetRevision: v1.19.1            # 항상 핀
      helm:
        releaseName: cert-manager
        valueFiles:
          - $values/platform/cert-manager/values.yaml
    - repoURL: https://github.com/<org>/platform-gitops.git
      targetRevision: main
      ref: values                        # ref 소스에는 chart 금지, path 없으면 values 전용
# OCI 차트: repoURL에 oci:// 없이 host/path, 저장소 Secret(type: helm, enableOCI: "true") 선등록
---
# (예외) post-render 패치가 필요한 경우만: argocd-cm kustomize.buildOptions: --enable-helm
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: cert-manager
helmCharts:
  - name: cert-manager
    repo: https://charts.jetstack.io
    version: v1.19.1
    releaseName: cert-manager
    namespace: cert-manager
    includeCRDs: true
    valuesFile: values.yaml
patches:
  - target: {kind: CustomResourceDefinition}
    patch: |-
      - op: add
        path: /metadata/annotations/argocd.argoproj.io~1sync-wave
        value: "-15"
```

**argocd-notifications-cm.yaml + ExternalSecret — Slack, Discord(webhook), OutOfSync 트리거, 전역 구독** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/services/webhook/>
```
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
data:
  context: |
    argocdUrl: https://argocd.joshuatech.dev
  service.slack: |
    token: $slack-token
  service.webhook.discord: |
    url: $discord-webhook-url
    headers:
      - name: Content-Type
        value: application/json
  template.app-state-changed: |
    message: |
      [{{.app.metadata.name}}] sync={{.app.status.sync.status}} health={{.app.status.health.status}} {{.context.argocdUrl}}/applications/{{.app.metadata.name}}
    webhook:
      discord:
        method: POST
        body: |
          {"username": "Argo CD", "embeds": [{"title": "{{.app.metadata.name}}: sync {{.app.status.sync.status}} / health {{.app.status.health.status}}", "url": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}", "color": 15158332}]}
  trigger.on-out-of-sync: |
    - when: app.status.sync.status == 'OutOfSync'
      oncePer: app.status.sync.revision      # 커밋당 1회, flapping 억제
      send: [app-state-changed]
  subscriptions: |
    - recipients: [slack:platform-alerts, discord]
      triggers: [on-sync-failed, on-health-degraded, on-deployed, on-out-of-sync]
---
# 카탈로그(on-deployed/on-sync-failed/on-health-degraded 등 기본 트리거·템플릿) 설치:
# kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/notifications_catalog/install.yaml
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: {name: argocd-notifications-secret, namespace: argocd}
spec:
  refreshInterval: 1h
  secretStoreRef: {kind: ClusterSecretStore, name: vault}
  target:
    name: argocd-notifications-secret
    creationPolicy: Merge     # install.yaml이 만든 빈 Secret에 키만 병합
  data:
    - secretKey: slack-token
      remoteRef: {key: platform/argocd/notifications, property: slack-token}
    - secretKey: discord-webhook-url
      remoteRef: {key: platform/argocd/notifications, property: discord-webhook-url}
```

**ingressroute.yaml — Traefik v3 + 와일드카드 cert, CLI 로그인 명령** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/ingress/>
```
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: {name: argocd-server, namespace: argocd}
spec:
  entryPoints: [websecure]
  routes:
    - kind: Rule
      match: Host(`argocd.joshuatech.dev`)
      priority: 10
      services: [{name: argocd-server, port: 80}]
    - kind: Rule
      match: Host(`argocd.joshuatech.dev`) && Header(`Content-Type`, `application/grpc`)
      priority: 11
      services: [{name: argocd-server, port: 80, scheme: h2c}]
  tls:
    secretName: wildcard-joshuatech-dev-tls   # cert-manager DNS-01 와일드카드
# CLI (Cloudflare Access Service Auth 토큰 + grpc-web)
# argocd login argocd.joshuatech.dev --sso --grpc-web \
#   --header "CF-Access-Client-Id: $CF_ID" --header "CF-Access-Client-Secret: $CF_SECRET"
# break-glass: argocd --core (터널 kubectl 컨텍스트, RBAC/SSO 없음)
```

**bootstrap 순서 (최초 1회, 이후 self-managed)** — <https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/>
```
kubectl create namespace argocd
kubectl apply --server-side --force-conflicts -k platform/argocd/        # ApplicationSet CRD가 client-side 한계 초과 → SSA 필수
kubectl apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.2/notifications_catalog/install.yaml
kubectl apply -n argocd -f apps/root.yaml                                 # platform-root → child로 argocd 자기 자신 포함
# 업그레이드: kustomization.yaml의 install.yaml 태그(v3.5.2 → v3.5.x) 커밋 → argocd Application이 SSA로 자체 적용
```

### 함정

- arm64: quay.io/argoproj/argocd, ghcr.io/dexidp/dex, redis 이미지 모두 linux/arm64 멀티아치(learn.arm.com 가이드·upstream 매니페스트 그대로 동작). CLI는 argocd-linux-arm64 별도 다운로드.
- ServerSideApply 전역 기본값 키가 없다 — child Application 하나라도 syncOptions에서 빠지면 client-side apply로 조용히 돌아간다. gitops repo CI에 'ServerSideApply=true 없는 Application 실패' lint 필수. ApplicationSet CRD(3.3 노트)·CNPG 매니페스트(공식 `kubectl apply --server-side`)는 client-side 262144바이트 annotation 한계를 넘는다.
- SSA만 켜고 Server-Side Diff를 안 켜면 ESO Merge 키·컨트롤러 default 필드 때문에 영구 OutOfSync가 난다 — `controller.diff.server.side: "true"` 후 application-controller 재시작 필요.
- argoproj.io/Application 헬스 평가는 1.8에서 제거됨 — argocd-cm Lua 커스터마이즈 없이는 root의 sync-wave가 child 완료를 기다리지 않고 통째로 Healthy 처리된다.
- Prune=confirm/Delete=confirm을 Application 레벨에 쓰려면 v3.3+; 리소스 annotation으로만 두면 UI '확인' 버튼이 뜨지 않고 그 리소스만 prune 제외된다(discussion #27569). 승인 대기 중 앱은 Progressing 상태로 남아 `on-deployed` 알림이 오지 않는다.
- SkipDryRunOnMissingResource는 CRD가 이미 있으면 dry-run을 수행한다. 같은 sync 안에서 CRD가 다른 앱에서 오는 경우 첫 sync가 실패할 수 있어 syncPolicy.retry가 있어야 한다.
- multiple sources: `ref` 소스에 `chart` 불가, valueFiles는 `$values/`로 시작하는 상대경로만, `path`를 주면 그 repo도 매니페스트 생성 대상이 된다. AppProject.sourceRepos에 차트 저장소 URL이 없으면 sync 거부. 문서상 2–3개 초과 금지, UI 편집 제약.
- Argo CD 3.5 repo-server는 Helm 4 단일 바이너리: `spec.source.helm.version: v3`는 무시되고, plain-HTTP OCI 저장소는 `--insecure-oci-force-http`(Secret `insecureOCIForceHttp: "true"`) 명시 필요, OCI 의존 차트도 저장소 등록 필요. kustomize helmCharts는 helm으로 shell-out하는 '제한 지원' 기능이며 Helm 4와의 조합은 미검증.
- Authentik OIDC: Argo 기본 requestedScopes에 `groups`가 포함되는데 Authentik에는 groups scope가 없고(groups claim은 profile에 포함) 미할당 scope 처리 방식이 문서화되어 있지 않다 — requestedScopes를 명시하라. authentik 공식 가이드는 Dex 경로(`/api/dex/callback`)라 그대로 따르면 안 된다.
- argocd CLI `--sso`는 client secret 없이 PKCE(S256)로 토큰을 교환한다 — Authentik provider를 Confidential로 만들면 브라우저 SSO는 되지만 CLI 로그인이 실패한다. `cliClientID`로 두 번째 provider를 두는 우회는 Authentik의 provider별 issuer 때문에 issuer 검증에서 막힌다.
- RBAC: `policy.default`가 빈 값이면 거부, `role:readonly`면 Authentik에 로그인 가능한 모든 사용자가 읽기 가능. 3.0부터 logs는 `logs, get`을 명시해야 보인다. `admin.enabled: "false"` 전에 SSO를 검증하고, break-glass는 kubectl edit로 재활성화 또는 `argocd --core`.
- install.yaml이 만드는 빈 `argocd-secret`·`argocd-notifications-secret`을 삭제 패치하면 안 된다(server.secretkey 등 런타임 생성). ESO는 `creationPolicy: Merge`로 키만 병합하고, OIDC 등 다른 Secret 참조는 `$<secret-name>:<key>` + 라벨 `app.kubernetes.io/part-of: argocd`.
- Discord는 네이티브 서비스가 없다(지원 목록 15종에 없음) — `service.webhook.discord` + Content-Type application/json + `content`/`embeds` body. webhook 구독 annotation 값은 빈 문자열(`notifications.argoproj.io/subscribe.<trigger>.discord: ""`).
- OutOfSync 트리거는 automated sync 앱에서 매 커밋마다 순간적으로 참이 된다 — `oncePer: app.status.sync.revision` 없이는 알림 폭주. 카탈로그 트리거는 모두 `oncePer: app.status.operationState?.syncResult?.revision`.
- application-controller는 StatefulSet(Deployment 아님) — resources 패치의 kind를 맞춰야 한다. upstream 매니페스트는 requests/limits가 전혀 없고, GOMEMLIMIT는 limit의 80–90%가 공식 권장. processors 축소는 sync 시간을 늘린다.
- Cloudflare Access 뒤에 두면 GitHub webhook(`/api/webhook`)이 차단된다 — 3분 폴링으로 시작하고, CLI는 `--header`로 Service Auth 토큰을 실어야 한다. Cloudflare proxied gRPC는 `--grpc-web`이 단순.
- kustomize 삭제 패치: 같은 객체에 delete 지시가 든 패치를 2개 이상 두면 오류('does not support more than one patch for the same object that contain a delete directive'). `patchesStrategicMerge`는 5.0에서 deprecated — `patches` 필드 사용.
- sync-wave 간 기본 2초 지연(ARGOCD_SYNC_WAVE_DELAY)이 root 앱의 wave 수만큼 누적된다; 앱 수 20–30이면 무시 가능하지만 wave를 필요 이상 잘게 쪼개지 말 것.
- 3.0부터 리소스 추적이 annotation 기반 기본값 — Helm 차트의 `app.kubernetes.io/instance` 라벨 충돌 없음. 3.0 기본 `resource.exclusions`(Endpoints/Leases/TokenReview)를 덮어쓰지 말고 추가만 할 것.
- Argo CD 3.5의 Source Integrity가 GnuPG 서명 검증을 대체 — AppProject.signatureKeys는 deprecated. public gitops repo에 서명 커밋 강제(`sourceIntegrity.required`)를 붙이려면 GitHub App 커밋 서명 방식을 먼저 정해야 한다.

### 미확인

- Authentik이 provider에 없는 scope(`groups`)를 요청받았을 때 오류인지 무시인지 문서에서 확인 못 함 — 스모크에서 requestedScopes 명시 상태로만 검증.
- Authentik Public client + PKCE로 Argo CD 서버(브라우저) 로그인과 CLI `--sso` 둘 다 end-to-end 동작하는지 미검증(3.1부터 서버가 항상 auth code flow를 처리). 실패 시 fallback: Confidential client + ESO Secret 참조, CLI는 `argocd --core`.
- kustomize 5.8.1 `helmCharts`가 repo-server의 Helm 4.2.x 바이너리와 호환되는지 미검증 — multiple sources를 기본으로 두는 이유. 필요해지면 스모크로 확인.
- argocd-notifications-cm `subscriptions` 목록에서 webhook 서비스 recipient 표기(`discord` vs `discord:`)를 문서에서 확정 못 함 — annotation 형식(`subscribe.<trigger>.discord: ""`)은 확실. 스모크에서 결정.
- 리소스 레벨 Prune=confirm annotation이 처음 들어간 버전(검색 요약은 v2.14 표기)은 릴리스 노트로 확인 못 함; Application 레벨은 v3.3(PR #23370)로 확정.
- 번들 Helm 버전이 4.2.0(업그레이드 문서)인지 4.2.1(v3.5.2 tool-versions.sh)인지 — 동작 차이 없음, 문서 표기 불일치만 기록.
- dev/prod AppProject에 Namespace kind가 clusterResourceWhitelist에 없어도 `CreateNamespace=true`가 동작하는지 문서에서 확정 못 함 — 스모크에서 확인, 실패 시 `{group: "", kind: Namespace}` 화이트리스트 추가.
- arm64 A1.Flex에서 Application ~20–30개 기준 실제 idle/spike 메모리는 커뮤니티 수치뿐 — 운영 1주 후 `kubectl top`으로 requests 재조정 태스크 필요.
- Cloudflare Access 뒤 `/api/webhook` GitHub 예외 정책(GitHub hooks IP 범위 bypass) 설계는 SP-2로 이월.
- Argo CD 3.5 repo-server mTLS(`argocd-repo-server-mtls` Secret 존재 시 자동 활성)는 단일 노드에서 이점이 작아 미적용 — 향후 멀티테넌트 시 재검토.
- Discord webhook `url: $discord-webhook-url` 치환은 discussion #22277 사용자 보고로만 확인(공식 문서에 URL 필드 예시 없음).


## R3 cert-manager · AOP · Traefik

R3 — cert-manager + Cloudflare DNS-01 와일드카드 + Authenticated Origin Pulls(AOP) + Traefik TLSOption + OCI 보안 리스트 (K3s v1.36 번들 Traefik 기준)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| cert-manager (컨트롤러·Helm 차트, OCI 레지스트리 oci://quay.io/jetstack/charts/cert-manager) | v1.21.1 (1.21.0은 2026-07-08; 지원 K8s 1.33→1.36, 테스트 1.36 포함; quay 이미지 manifest list: linux/amd64·arm64·arm·ppc64le·s390x) | 2026-07-29 | <https://github.com/cert-manager/cert-manager/releases/tag/v1.21.1> |
| cert-manager 지원 매트릭스 (1.22는 2026-11 예정) | 1.21 = K8s 1.33–1.36 / 1.20 = 1.32–1.35 | 2026-07-08 | <https://cert-manager.io/docs/releases/> |
| K3s (번들 Traefik 3.7.8 이미지 rancher/mirrored-library-traefik:3.7.8, 차트 traefik-40.1.4+up40.1.0, helm-controller v0.17.7, local-path-provisioner v0.0.37, Kubernetes v1.36.4) | v1.36.4+k3s1 | 2026-08-27 | <https://github.com/k3s-io/k3s/releases/tag/v1.36.4+k3s1> |
| Traefik Proxy 업스트림 (K3s 번들 3.7.8보다 4패치 앞섬; 3.7.10–3.7.12는 CVE 수정) | v3.7.12 | 2026-08-26 | <https://github.com/traefik/traefik/releases> |
| Traefik Helm 차트 업스트림 (K3s는 40.1.0 포크 사용; tlsOptions/tlsStore/forwardedHeaders 키는 40.1.0에도 존재 확인) | 41.4.0 (appVersion v3.7.12) | 2026-08 | <https://github.com/traefik/traefik-helm-chart/blob/master/traefik/Chart.yaml> |
| Cloudflare 글로벌 AOP CA 인증서 (CN=origin-pull.cloudflare.net, CA:TRUE pathlen 2, serial 5791BA9556C22E61, SHA256 9A:1A:C2:B4:BE:15:F9:F2:7E:EE:20:A7:34:CB:A4:E9:89:8F:61:00:1B:3B:D7:C8:4B:69:B5:6A:3E:25:A2:B9) | notBefore 2019-10-10 / notAfter 2029-11-01 (openssl로 직접 확인) | 2019-10-10 | <https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem> |
| Cloudflare IP 대역 (ips-v4 15개, ips-v6 7개 = 22 CIDR; API etag 38f79d050aa027e3be3865e495dcc9bc) | Last updated 2023-09-28 | 2023-09-28 | <https://www.cloudflare.com/ips/> |
| terraform-provider-cloudflare (OpenTofu 호환; v5 리소스 cloudflare_zone_setting, cloudflare_authenticated_origin_pulls_settings, data cloudflare_ip_ranges) | v5.24.0 | 2026-08-24 | <https://github.com/cloudflare/terraform-provider-cloudflare/releases> |
| Let's Encrypt 레이트 리밋 문서 (신규 주문 300/3h/계정, 등록 도메인당 50/7d, 동일 SAN 세트 5/7d, 검증 실패 5/h/식별자) | 2026-08-05 갱신 | 2026-08-05 | <https://letsencrypt.org/docs/rate-limits/> |
| Let's Encrypt ACME 프로필 (classic 90d → 2027-02-10 64d → 2028-02-16 45d; tlsserver 45d(2026-05-13~); shortlived ~6d; tlsclient 2026-07-08 폐지) | classic/tlsserver/shortlived | 2025-12-02 발표 | <https://letsencrypt.org/docs/profiles/> |

### 결정

**INGRESS-D1. cert-manager를 어떻게 설치·CRD 관리하나?**

- Decision: Argo CD Application(AppProject platform, sync-wave 앞순위)으로 OCI Helm 차트 oci://quay.io/jetstack/charts/cert-manager v1.21.1 설치, values `crds.enabled=true`·`crds.keep=true`(기본 true), ServerSideApply. ClusterIssuer·Certificate는 별도 Application(뒤 wave) + `SkipDryRunOnMissingResource=true`.
- Rationale: 공식 문서가 `--set crds.enabled=true`를 표준으로 제시(`installCRDs`는 values.yaml에 Deprecated 명시). `crds.keep`은 CRD 삭제 시 모든 Certificate/Issuer가 GC로 사라지는 사고 방지. cert-manager CRD는 크기가 커 SSA가 필요하고, 문서가 서브차트 임베딩을 금지(클러스터 범위 리소스 관리).
- Alternatives considered: `installCRDs=true`(deprecated) / kubectl static manifest(업그레이드 수동) / 다른 차트의 서브차트(문서가 금지) / charts.jetstack.io 레거시 repo(OCI보다 수 시간 늦게 반영).
- Source: <https://cert-manager.io/docs/installation/helm/>

**INGRESS-D2. ACME 발급자·챌린지 방식은?**

- Decision: ClusterIssuer 2개(letsencrypt-staging, letsencrypt-prod), DNS-01 Cloudflare 솔버, `apiTokenSecretRef`로 API 토큰(권한 Zone:DNS:Edit + Zone:Zone:Read, 대상 joshuatech.dev 존) 참조. Secret은 cert-manager 네임스페이스(=`clusterResourceNamespace` 기본)에 ESO ExternalSecret으로 생성. `dns01RecursiveNameservers="1.1.1.1:53,8.8.8.8:53"` + `dns01RecursiveNameserversOnly=true`.
- Rationale: 와일드카드는 DNS-01만 가능(HTTP-01 불가). ClusterIssuer가 참조하는 Secret은 반드시 cert-manager ns에 있어야 함(문서 명시). Global API Key 대신 최소 권한 토큰. 자체 검사(self-check)는 노드 resolv.conf → 권위 서버 조회 순인데 OCI 내부 리졸버·캐시 문제를 피하려면 공개 리커시브 고정이 안전.
- Alternatives considered: HTTP-01(와일드카드 불가·80포트 개방 필요·AOP와 충돌) / Cloudflare Origin CA 인증서(브라우저 미신뢰, 15년, Cloudflare 경유 전용) / Global API Key(과권한).
- Source: <https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/>

**INGRESS-D3. 와일드카드 인증서를 어디에 두고 Ingress에 어떻게 연결하나?**

- Decision: Certificate `wildcard-joshuatech-dev`(dnsNames: joshuatech.dev, *.joshuatech.dev; ECDSA P-256; rotationPolicy Always; renewBeforePercentage 33)를 kube-system(Traefik ns)에 1장만 발급하고 Traefik `TLSStore default.defaultCertificate.secretName`으로 지정. 앱 Ingress는 `router.tls: "true"`만 달고 `spec.tls` 생략.
- Rationale: TLSStore `default`는 Traefik ns 1개만 허용되며 모든 TLS 라우터가 자동 사용 → 네임스페이스마다 Secret 복제·재발급 불필요, LE 중복 발급 한도(동일 SAN 5/7d) 소모 최소화. rotationPolicy 기본은 1.18+에서 Always. `renewBeforePercentage`는 발급 CA가 요청보다 짧은 유효기간(64→45일 전환)을 줄 때 재발급 루프를 막는 권장 방식.
- Alternatives considered: 네임스페이스별 Certificate(중복 발급·한도 소모) / Secret 복제 도구(reflector) / Ingress `spec.tls.secretName` 직접 참조(ns 간 참조 불가).
- Source: <https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/crd/tls/tlsstore/>

**INGRESS-D4. AOP는 어느 레벨(글로벌/존/호스트별)로 켜나?**

- Decision: 글로벌 AOP(Cloudflare 제공 CA 사용). Terraform `cloudflare_zone_setting { setting_id = "tls_client_auth", value = "on" }`(= API PATCH /zones/{zone_id}/settings/tls_client_auth). 오리진은 `authenticated_origin_pull_ca.pem`(CN origin-pull.cloudflare.net, 2029-11-01 만료)으로 검증. 전제: SSL 모드 Full 이상.
- Rationale: 문서: 글로벌 = Cloudflare가 공유 인증서를 제시, 오리진 설정만 하면 됨(가장 단순). 존 수준(zone-level)은 '자체 발급 리프 인증서 업로드 + 자체 CA를 오리진에 배포'라 갱신·만료 운영 부담이 생기며, 리소스도 다름(`cloudflare_authenticated_origin_pulls_settings` = PUT /origin_tls_client_auth/settings). 1인 운영·Free 플랜에는 글로벌이 적정. 보안 리스트로 Cloudflare IP 한정까지 겹치므로 '계정 단독 보장' 필요성은 낮음.
- Alternatives considered: 존 수준 자체 인증서(계정 단독 보장·FIPS·PQC ML-DSA 지원, 만료 알림 있음) / 호스트별 AOP / AOP 없이 IP 한정만(스푸핑·타 계정 Cloudflare 경유 우회 가능).
- Source: <https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/set-up/global/>

**INGRESS-D5. Traefik에서 클라이언트 인증서를 어떻게 강제하나?**

- Decision: K3s HelmChartConfig(`/var/lib/rancher/k3s/server/manifests/traefik-config.yaml`) `valuesContent.tlsOptions.default`에 `clientAuth.secretNames: [cloudflare-origin-pull-ca]`, `clientAuthType: RequireAndVerifyClientCert`, `sniStrict: true`, `minVersion: VersionTLS12`. Secret은 kube-system, 키 `ca.crt`(또는 `tls.ca`). 전환 순서: AOP on → `VerifyClientCertIfGiven`으로 관찰 → `RequireAndVerifyClientCert`.
- Rationale: 이름이 `default`인 TLSOption은 클러스터 전체 1개만 허용되며 옵션 미지정 라우터에 자동 적용 → Ingress마다 어노테이션 불필요·누락 위험 없음. 차트 40.1.0 템플릿이 `clientAuth`를 그대로 통과시킴(확인). Cloudflare edge는 항상 SNI를 보내므로 sniStrict로 IP 스캐너 차단 가능.
- Alternatives considered: Ingress별 `traefik.ingress.kubernetes.io/router.tls.options: kube-system-<name>@kubernetescrd` / IngressRoute `tls.options` / 미들웨어 PassTLSClientCert로 앱 레벨 검증.
- Source: <https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/crd/tls/tlsoption/>

**INGRESS-D6. OCI 인바운드를 Cloudflare로 한정하는 방법과 한도는?**

- Decision: 노드 A 서브넷 보안 리스트에 ingress 443/tcp × Cloudflare 22 CIDR(OpenTofu `data.cloudflare_ip_ranges` → `dynamic ingress_security_rules`), 80은 열지 않음(Always Use HTTPS는 edge에서). VCN에 IPv6가 없으면 ips-v4 15개만.
- Rationale: 한도: 보안 리스트당 ingress 200·egress 200(증설 불가), 서브넷당 5개, VCN당 300; 22개는 여유. 보안 리스트 규칙 소스는 CIDR만 가능. NSG(120 rules, VNIC당 5)는 NSG→NSG 참조가 필요할 때만 이점. DNS-01이라 80 불필요.
- Alternatives considered: NSG `oci_core_network_security_group_security_rule`(규칙당 리소스 1개, 총 120) / 노드 iptables·nftables(K3s ServiceLB와 충돌 위험) / 오리진을 cloudflared로만 노출(AOP 불가, 설계상 관리용 전용).
- Source: <https://docs.oracle.com/en-us/iaas/Content/Network/Concepts/securityrules.htm>

**INGRESS-D7. Full(strict)에서 LE 와일드카드를 오리진 인증서로 쓸 때 조건은?**

- Decision: 공개 CA(LE) 인증서 허용; SAN에 apex(joshuatech.dev)와 `*.joshuatech.dev` 모두 포함; 공개 호스트명은 1단계 서브도메인으로만 설계(api., auth., dev-api. 등); 오리진 443만; Traefik 기본 인증서를 반드시 TLSStore로 지정(자체 서명 fallback이면 526).
- Rationale: Full(strict)는 미만료 + CN/SAN 호스트명 일치 + 443 을 검사하고 실패 시 526. 와일드카드는 1단계만 매칭하며 Universal SSL(Free) edge 인증서도 apex+1단계만 커버 → 2단계(`*.dev.joshuatech.dev`)는 edge·오리진 둘 다 안 됨(ACM 유료).
- Alternatives considered: Cloudflare Origin CA(무료·15년·브라우저 미신뢰) / Advanced Certificate Manager(다단계 서브도메인).
- Source: <https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/>

**INGRESS-D8. LE 레이트 리밋(동일 SAN 5/7d 등)을 어떻게 피하나?**

- Decision: (1) 파이프라인·테스트는 letsencrypt-staging 로만, prod 발급은 1장; (2) Secret 보존: `enableCertificateOwnerRef=false`(기본)로 Certificate 삭제/prune 시에도 Secret 유지, 재적용 시 재발급 없음; (3) `renewBeforePercentage: 33`(절대값 renewBefore 금지); (4) ACME 계정 키 Secret(`privateKeySecretRef`) 보존; (5) ARI는 `featureGates: "ACMEUseARI=true"`(실험)로 staging 검증 후 도입.
- Rationale: 동일 식별자 세트 5/7d는 override 불가. 갱신(ARI면 전부, 비-ARI도 주문/도메인 한도)은 면제이므로 문제는 '재설치·Secret 삭제 반복'뿐. cert-manager는 유효한 Secret이 있으면 재발급하지 않음. 45일 전환에도 LE는 '갱신은 한도 면제'라 추가 조치 불필요.
- Alternatives considered: SAN 세트를 바꿔 새 발급(한도 회피용 꼼수, 비권장) / shortlived 6일 프로필(발급 빈도 15배, 단일 노드에 위험) / 상용 CA.
- Source: <https://letsencrypt.org/docs/rate-limits/>

**INGRESS-D9. Traefik 버전은 K3s 번들(3.7.8)로 두나, 업스트림 3.7.12로 올리나?**

- Decision: K3s 번들 3.7.8 + 차트 40.1.x 유지, K3s 패치 릴리스로 추적. CVE가 급하면 HelmChartConfig `image.repository: traefik` + `image.tag`로만 오버라이드(차트 버전은 유지).
- Rationale: K3s 매니페스트가 이미지 태그를 고정(rancher/mirrored-library-traefik:3.7.8)하며 차트는 K3s 정적 차트에서 온다. 업스트림 3.7.10–3.7.12가 CVE 수정을 담았으나 K3s 1.36.5에서 따라올 가능성이 높음. 차트 메이저 변경(41.x)은 values 스키마 변경 위험.
- Alternatives considered: `--disable=traefik` 후 업스트림 차트를 Argo CD로 직접 관리(가장 최신·완전 GitOps, 대신 ServiceLB 연동을 직접 구성).
- Source: <https://raw.githubusercontent.com/k3s-io/k3s/v1.36.4+k3s1/manifests/traefik.yaml>

### 설정 스니펫

**Argo CD Application — cert-manager Helm(OCI) v1.21.1** — <https://cert-manager.io/docs/installation/helm/>
```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cert-manager
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
spec:
  project: platform
  source:
    repoURL: quay.io/jetstack/charts   # OCI: repo 자격증명에 enableOCI=true, oci:// 접두사 없이
    chart: cert-manager
    targetRevision: v1.21.1
    helm:
      valuesObject:
        crds: { enabled: true, keep: true }
        dns01RecursiveNameservers: "1.1.1.1:53,8.8.8.8:53"
        dns01RecursiveNameserversOnly: true
        # featureGates: "ACMEUseARI=true"   # 실험 기능, staging 검증 후
  destination:
    server: https://kubernetes.default.svc
    namespace: cert-manager
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true, ServerSideApply=true]
```

**ExternalSecret + ClusterIssuer (Cloudflare DNS-01, prod; staging은 server만 교체)** — <https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/>
```
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: cloudflare-api-token, namespace: cert-manager }   # ClusterIssuer용 Secret은 반드시 cert-manager ns
spec:
  secretStoreRef: { kind: ClusterSecretStore, name: vault }
  target: { name: cloudflare-api-token }
  data:
    - secretKey: api-token
      remoteRef: { key: platform/cloudflare, property: cert_manager_dns_token }   # 권한: Zone:DNS:Edit + Zone:Zone:Read, joshuatech.dev 존 한정
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod   # letsencrypt-staging: https://acme-staging-v02.api.letsencrypt.org/directory
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: ops@joshuatech.dev
    privateKeySecretRef: { name: letsencrypt-prod-account-key }   # 삭제 금지(계정 재등록 한도 10/3h/IP)
    # profile: tlsserver   # 45일 프로필; 2027-02-10 classic 64일 전환 전에 결정
    solvers:
      - selector: { dnsZones: [joshuatech.dev] }
        dns01:
          cloudflare:
            apiTokenSecretRef: { name: cloudflare-api-token, key: api-token }
```

**와일드카드 Certificate (Traefik ns에 1장)** — <https://cert-manager.io/docs/usage/certificate/>
```
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: wildcard-joshuatech-dev
  namespace: kube-system            # Traefik TLSStore default 와 같은 ns
  annotations:
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  secretName: wildcard-joshuatech-dev-tls
  issuerRef: { name: letsencrypt-prod, kind: ClusterIssuer }
  dnsNames: ["joshuatech.dev", "*.joshuatech.dev"]   # apex 별도 SAN 필수, 1단계만 매칭
  privateKey: { algorithm: ECDSA, size: 256, rotationPolicy: Always }
  renewBeforePercentage: 33         # 절대값 renewBefore 대신 (64/45일 전환 대비)
```

**Cloudflare AOP CA Secret 생성 (공개 CA — Vault kv 경유 ExternalSecret 또는 평문 커밋 가능)** — <https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/set-up/global/>
```
curl -sSLO https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem
openssl x509 -in authenticated_origin_pull_ca.pem -noout -subject -enddate
#  subject=... CN = origin-pull.cloudflare.net / notAfter=Nov  1 17:00:00 2029 GMT
kubectl -n kube-system create secret generic cloudflare-origin-pull-ca \
  --from-file=ca.crt=authenticated_origin_pull_ca.pem --dry-run=client -o yaml   # TLSOption은 ca.crt 또는 tls.ca 키
```

**K3s HelmChartConfig — Traefik(chart 40.1.x): default TLSOption(mTLS)·TLSStore·Cloudflare trustedIPs** — <https://docs.k3s.io/networking/networking-services>
```
# /var/lib/rancher/k3s/server/manifests/traefik-config.yaml (cloud-init/OpenTofu로 배치)
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata: { name: traefik, namespace: kube-system }
spec:
  valuesContent: |-
    ports:
      websecure:
        forwardedHeaders:
          trustedIPs:   # Cloudflare ips-v4 15 + ips-v6 7 (2023-09-28)
            - 173.245.48.0/20
            - 103.21.244.0/22
            - 103.22.200.0/22
            - 103.31.4.0/22
            - 141.101.64.0/18
            - 108.162.192.0/18
            - 190.93.240.0/20
            - 188.114.96.0/20
            - 197.234.240.0/22
            - 198.41.128.0/17
            - 162.158.0.0/15
            - 104.16.0.0/13
            - 104.24.0.0/14
            - 172.64.0.0/13
            - 131.0.72.0/22
            - "2400:cb00::/32"
            - "2606:4700::/32"
            - "2803:f800::/32"
            - "2405:b500::/32"
            - "2405:8100::/32"
            - "2a06:98c0::/29"
            - "2c0f:f248::/32"
    tlsOptions:
      default:                         # 클러스터 전체 1개, 옵션 미지정 라우터에 자동 적용
        minVersion: VersionTLS12
        sniStrict: true
        clientAuth:
          secretNames: [cloudflare-origin-pull-ca]
          clientAuthType: RequireAndVerifyClientCert   # 1단계 전환 시 VerifyClientCertIfGiven
    tlsStore:
      default:
        defaultCertificate:
          secretName: wildcard-joshuatech-dev-tls
```

**표준 Ingress (default TLSOption·TLSStore 자동 적용)** — <https://doc.traefik.io/traefik/reference/routing-configuration/kubernetes/ingress/>
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api
  namespace: prod
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
    # 다른 옵션이 필요할 때만: traefik.ingress.kubernetes.io/router.tls.options: kube-system-<name>@kubernetescrd
spec:
  ingressClassName: traefik
  rules:
    - host: api.joshuatech.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend: { service: { name: api, port: { number: 8000 } } }
  # spec.tls 생략 → TLSStore default 의 와일드카드 사용
```

**OpenTofu — Cloudflare 존 설정(Full strict·글로벌 AOP) + IP 대역 + OCI 보안 리스트** — <https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zone_setting.md>
```
# provider cloudflare ~> 5.24
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = var.zone_id
  setting_id = "ssl"
  value      = "strict"
}
resource "cloudflare_zone_setting" "aop_global" {   # = PATCH /zones/{id}/settings/tls_client_auth
  zone_id    = var.zone_id
  setting_id = "tls_client_auth"
  value      = "on"
}
resource "cloudflare_zone_setting" "always_https" {
  zone_id    = var.zone_id
  setting_id = "always_use_https"
  value      = "on"
}
# (존 수준 '자체 인증서' AOP를 택할 때만) cloudflare_authenticated_origin_pulls_settings { zone_id, enabled = true }

data "cloudflare_ip_ranges" "cf" {}
locals {
  cf_cidrs = concat(data.cloudflare_ip_ranges.cf.ipv4_cidrs,
                    var.vcn_ipv6 ? data.cloudflare_ip_ranges.cf.ipv6_cidrs : [])
}

resource "oci_core_security_list" "cloudflare_443" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "cloudflare-443-only"
  dynamic "ingress_security_rules" {
    for_each = toset(local.cf_cidrs)   # 15(+7)개, 한도 200/리스트
    content {
      description = "Cloudflare edge"
      protocol    = "6"
      source      = ingress_security_rules.value
      source_type = "CIDR_BLOCK"
      stateless   = false
      tcp_options {
        min = 443
        max = 443
      }
    }
  }
  egress_security_rules {
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
  }
}
```

**AOP 활성화·검증 (API/curl)** — <https://developers.cloudflare.com/api/resources/zones/subresources/settings/methods/edit/>
```
# 글로벌 AOP on (Terraform 없이)
curl -X PATCH "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/settings/tls_client_auth" \
  -H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json" --data '{"value":"on"}'
# (참고) 존 수준 자체 인증서 AOP는 별도: PUT /zones/$ZONE_ID/origin_tls_client_auth/settings  {"enabled":true}

# 검증 1: Cloudflare 경유 → 200
curl -sSI https://api.joshuatech.dev/healthz
# 검증 2: 오리진 직접 → 클라이언트 인증서 요구로 핸드셰이크 실패해야 정상(보안 리스트 통과 시에도)
curl -skI --resolve api.joshuatech.dev:443:$NODE_A_PUBLIC_IP https://api.joshuatech.dev/healthz
# 검증 3: Cloudflare 최신 IP etag 비교(변경 시 tofu apply)
curl -s https://api.cloudflare.com/client/v4/ips | jq -r .result.etag   # 현재 38f79d050aa027e3be3865e495dcc9bc
```

### 함정

- AOP 문서 구조 주의: '존 수준(zone-level)'은 자체 리프 인증서를 업로드하는 방식이고, Cloudflare 제공 CA(`authenticated_origin_pull_ca.pem`)를 쓰는 것은 '글로벌'이다. API/Terraform도 다르다 — 글로벌 = zone setting `tls_client_auth`(`cloudflare_zone_setting`), 존 수준 = `/origin_tls_client_auth/settings`(`cloudflare_authenticated_origin_pulls_settings`). 셋은 서로 독립이라 잘못 켜면 '켜졌는데 인증서가 안 온다' 상태가 된다.
- AOP는 Cloudflare Tunnel 오리진에 적용되지 않는다(문서 명시: 인바운드 리스너가 없어 클라이언트 인증서를 제시할 곳이 없음). 설계대로 cloudflared를 SSH/kubectl 전용으로 두고, HTTP 앱은 절대 터널로 노출하지 말 것(노출하면 TLSOption mTLS를 우회).
- `tlsOptions.default`에 `RequireAndVerifyClientCert`를 걸면 Cloudflare 경유가 아닌 모든 TLS 접속이 거부된다: 클러스터 내부 pod가 공개 호스트명(https://auth.joshuatech.dev 등)으로 자기 자신을 호출하는 경우(Authentik OIDC discovery, Next.js BFF→API, Celery 콜백), 노드에서의 curl 테스트, 외부 업타임 체크 직결 등. 내부 호출은 Service DNS를 쓰거나 Cloudflare를 경유(노드 이그레스는 허용)하도록 설계에 못박아야 한다.
- 전환 순서: 오리진에 Require를 먼저 걸면 AOP를 켜기 전까지 Cloudflare가 인증서를 제시하지 않아 전 서비스 5xx. 순서는 AOP on → `VerifyClientCertIfGiven`로 로그 확인 → `RequireAndVerifyClientCert`. 글로벌 AOP CA는 2029-11-01 만료이며 글로벌에는 만료 알림 기능이 없다(존 수준만 30/14일 알림) → 운영 캘린더에 2029 Q3 교체 항목 필요.
- Traefik Ingress의 TLS 옵션은 Ingress가 아니라 호스트명에 매핑된다 — 같은 호스트를 다른 옵션으로 서빙하는 Ingress가 어느 ns에든 있으면 충돌(문서). default 옵션만 쓰면 회피됨. 어노테이션으로 다른 ns의 TLSOption을 참조할 때 형식은 `<ns>-<name>@kubernetescrd`이며, `allowCrossNamespace`가 필요한지는 문서가 IngressRoute에만 명시(open 참조).
- Full(strict) 526 함정: Traefik에 TLSStore default를 지정하지 않으면 자체 서명 'TRAEFIK DEFAULT CERT'로 응답해 Cloudflare가 526을 낸다. 또 와일드카드는 1단계만 매칭하고 Universal SSL(Free)도 apex+1단계만 커버하므로 `*.dev.joshuatech.dev` 같은 2단계 호스트는 edge·오리진 모두 실패(ACM 유료 필요). 호스트명 규약을 `<svc>-<env>.joshuatech.dev` 처럼 1단계로 고정.
- cert-manager 1.21 breaking: Helm 차트가 기본 tokenrequest RBAC를 제거했고, 메트릭 포트 이름이 `http-metrics`로 바뀌며 `prometheus.servicemonitor.targetPort/path`, `prometheus.podmonitor.path` 값이 삭제됨 → Alloy scrape 설정에서 포트명 기준으로 잡을 것. 1.21.0의 `renewal.policy: Disabled` 크래시 루프는 1.21.1에서 수정.
- LE 유효기간 축소 일정(classic 90→64일 2027-02-10, →45일 2028-02-16; tlsserver 45일은 2026-05-13부터)에 대비해 `renewBefore` 절대값(예: 360h) 대신 `renewBeforePercentage`를 써야 재발급 루프를 피한다. 단일 서버 K3s라 cert-manager가 2주 이상 죽어 있으면 45일 인증서는 만료→526: `certmanager_certificate_expiration_timestamp_seconds` 기반 Grafana Cloud 알림을 SP-1 관측 항목에 포함.
- LE 동일 SAN 세트 한도 5/7d는 override 불가. 클러스터 재이미지·재설치 리허설 때 prod 발급자를 쓰면 하루에 소진된다 → 리허설·CI는 staging 발급자 고정, prod Secret(`wildcard-joshuatech-dev-tls`)과 ACME 계정 키 Secret은 `enableCertificateOwnerRef=false`(기본)로 보존하고 재설치 전 백업(Vault kv 또는 오프라인).
- Cloudflare API 토큰을 존 하나로 한정할 때 `Zone:Zone:Read`가 빠지면 `com.cloudflare.api.account.zone.list` 권한 오류. 또 self-check가 OCI 내부 리졸버 캐시에 걸리면 챌린지가 오래 대기 → `dns01RecursiveNameservers`+`Only` 고정. `cnameStrategy: Follow`는 와일드카드 CNAME 합성 문제가 있어 기본(None) 유지.
- OCI 보안 리스트: ingress/egress 각 200/리스트, 서브넷당 5개는 증설 불가; 소스는 CIDR만. Cloudflare 대역은 2023-09-28 이후 변경이 없지만 변경 시 Renovate로는 감지 못함 → `api.cloudflare.com/client/v4/ips`의 etag를 주기 워크플로(GitHub Actions cron)로 비교해 tofu plan 알림. VCN에 IPv6를 켜지 않으면 ips-v6 7개는 넣지 않아도 되고 AAAA 레코드도 만들지 말 것.
- K3s는 Traefik 이미지·차트를 매니페스트에 고정(3.7.8, chart 40.1.4+up40.1.0; 차트 appVersion은 3.7.1이지만 이미지 태그 3.7.8 오버라이드). 업스트림 3.7.10~3.7.12 CVE 수정은 K3s 다음 패치를 기다리거나 HelmChartConfig `image`로만 올릴 것. K3s 업그레이드로 차트가 41.x가 되면 values 스키마 변화(예: `kubernetesIngressNginx`→`kubernetesIngressNGINX`)를 릴리스 노트에서 확인.
- Argo CD와 cert-manager CRD: CRD가 커서 클라이언트 사이드 apply는 어노테이션 크기 한도에 걸린다(ServerSideApply=true 필수, 이미 설계). ClusterIssuer/Certificate를 cert-manager와 같은 sync에 넣으면 첫 동기화에서 CRD 부재로 dry-run 실패 → 별도 Application(뒤 wave) + `SkipDryRunOnMissingResource=true`. `crds.keep`의 `helm.sh/resource-policy: keep`은 Argo CD prune과 무관(open 참조).
- cert-manager 이미지는 quay manifest list에 linux/arm64 포함(확인). Traefik `rancher/mirrored-library-traefik`도 multi-arch. 반면 사용자 정의 사이드카·검증 스크립트 이미지는 arm64 빌드를 별도로 확인해야 한다.

### 미확인

- K3s ServiceLB(klipper-lb) 경유 시 클라이언트 소스 IP가 Traefik에 보존되는지(hostPort DNAT) — 보존되지 않으면 `forwardedHeaders.trustedIPs`에 Cloudflare 대역이 아니라 노드/파드 CIDR을 넣어야 하고 `CF-Connecting-IP`만 신뢰해야 함. 노드 A에서 실측 필요.
- Traefik 표준 Ingress 어노테이션 `router.tls.options: <ns>-<name>@kubernetescrd`로 다른 네임스페이스의 TLSOption을 참조할 때 `providers.kubernetesCRD.allowCrossNamespace`가 요구되는지 — 문서는 IngressRoute에만 명시. default TLSOption 채택으로 회피하되 예외 옵션이 생기면 실측.
- Argo CD에서 `crds.keep=true`(helm.sh/resource-policy: keep)와 Application 삭제/prune의 상호작용 — Argo CD는 Helm 훅·정책을 무시하므로 CRD가 함께 삭제될 수 있음. AppProject platform에 CRD 삭제 금지 정책(또는 `Prune=false` 어노테이션)이 필요한지 확인.
- LE ACME 프로필 선택(`spec.acme.profile: tlsserver`, 45일)을 SP-1에서 바로 할지 2027-02-10 classic 64일 전환 직전에 할지 — tlsserver는 Key Encipherment KU와 SKI가 없는 인증서라 오래된 클라이언트 호환성 검토 필요(Cloudflare edge는 문제없음).
- Cloudflare가 글로벌 AOP CA(2029-11-01 만료)를 조기 교체할 때의 공지 채널(changelog RSS 여부) — 미확인. 교체 시 kube-system Secret 갱신 절차를 runbook에 둘 것.
- OCI 춘천 VCN의 IPv6 활성 여부(설계 결정 필요) → ips-v6 규칙 7개와 AAAA 레코드 필요성이 여기에 종속.
- `rancher/mirrored-library-traefik`에 3.7.12 태그가 이미 있는지(있으면 HelmChartConfig image.tag만으로 CVE 패치 가능) — 미확인.
- ESO의 ExternalSecret API 버전(`external-secrets.io/v1` vs `v1beta1`)은 R-ESO/Vault 주제의 ESO 버전 확정에 따라 스니펫 갱신 필요.


## R4 Vault · OCI KMS · ESO

R4 — HashiCorp Vault(ocikms auto-unseal, Raft 단일 replica) + Kubernetes auth + External Secrets Operator + Authentik OIDC (SP-1 platform foundation, 2026-09-01 기준)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| HashiCorp Vault (Community, BSL 1.1 / Licensor IBM, Change License MPL 2.0) | 2.0.4 | 2026-08-04 | <https://github.com/hashicorp/vault/releases> |
| hashicorp/vault Docker 이미지 2.0.4 (linux/amd64, linux/arm64, linux/386 매니페스트) | 2.0.4 | 2026-08-04 | <https://hub.docker.com/v2/repositories/hashicorp/vault/tags/2.0.4> |
| vault-helm 차트 (appVersion 2.0.4, vault-k8s 1.7.6, kubeVersion >= 1.20.0-0; K8s v1.32–1.36 테스트) | 0.34.1 | 2026-08-13 | <https://github.com/hashicorp/vault-helm/releases> |
| External Secrets Operator (ghcr.io/external-secrets/external-secrets, amd64/arm64/ppc64le 빌드) | v2.10.0 | 2026-08-28 | <https://github.com/external-secrets/external-secrets/releases> |
| external-secrets Helm 차트 (appVersion v2.10.0, kubeVersion >= 1.19.0-0, API external-secrets.io/v1) | 2.10.0 | 2026-08-28 | <https://raw.githubusercontent.com/external-secrets/external-secrets/main/deploy/charts/external-secrets/Chart.yaml> |
| terraform-provider-vault (OpenTofu 호환, MPL 2.0) | v5.11.0 | 2026-08-14 | <https://github.com/hashicorp/terraform-provider-vault/releases> |
| go-kms-wrapping ocikms 래퍼 (Vault 내장; Encrypt/Decrypt/GetKey 호출, InstancePrincipalConfigurationProvider) | wrappers/ocikms/v2 (main) |  | <https://raw.githubusercontent.com/hashicorp/go-kms-wrapping/main/wrappers/ocikms/ocikms.go> |

### 결정

**VAULT-D1. Vault 버전·배포판·이미지는?**

- Decision: Vault Community 2.0.4(BSL 1.1), 공식 hashicorp/vault:2.0.4 multi-arch 이미지(arm64 포함), vault-helm 0.34.1로 배포.
- Rationale: 2.0.x가 2026-04 GA된 현행 라인이고 차트 0.34.1 기본값이 2.0.4. BSL 1.1은 자체 운영(경쟁 호스팅 아님)에 사용 가능. 이미지 매니페스트에 linux/arm64 포함 확인.
- Alternatives considered: 1.21.x 유지(2026-03 이후 패치 없음), OpenBao(MPL fork, ocikms seal 동일 문서) — 커뮤니티/ESO 생태계 호환 위해 Vault 유지.
- Source: <https://github.com/hashicorp/vault/releases>

**VAULT-D2. Helm 값: Raft 단일 replica 구성은?**

- Decision: server.ha.enabled=true, ha.replicas=1, ha.raft.enabled=true, setNodeId=true, dataStorage(local-path, 5Gi), nodeSelector role=platform, injector/csi 비활성, ui Service 활성, resources req 100m/256Mi·limit 512Mi, authDelegator 기본(true) 유지.
- Rationale: Raft(integrated storage)는 스냅샷 백업·향후 3노드 확장 경로를 제공. injector는 ESO로 대체하므로 불필요. 차트 기본 podAntiAffinity는 replicas=1이면 무해. authDelegator가 system:auth-delegator CRB를 만들어 Kubernetes auth 리뷰어 권한을 제공.
- Alternatives considered: standalone 모드(file 스토리지: 스냅샷 명령 없음), Bitnami vault 차트, HA 3 replica(노드 2개라 불가).
- Source: <https://raw.githubusercontent.com/hashicorp/vault-helm/main/values.yaml>

**VAULT-D3. 클러스터 내부 TLS 처리?**

- Decision: SP-1은 차트 기본 global.tlsDisable=true(listener tls_disable=1)로 내부 평문, 외부는 Traefik(cert-manager 와일드카드)+Cloudflare Access에서 종단. listener에 x_forwarded_for_authorized_addrs=Pod CIDR 설정.
- Rationale: ESO·Authentik은 같은 클러스터에서 접근하며 운영 부담 최소화. X-Forwarded-For 신뢰 설정으로 감사 로그에 실제 클라이언트 IP 기록.
- Alternatives considered: cert-manager 인증서를 server.volumes로 마운트해 listener TLS(엔드투엔드) — SP-2 후속 항목으로 기록.
- Source: <https://developer.hashicorp.com/vault/docs/configuration/listener/tcp>

**VAULT-D4. Auto-unseal seal 설정과 OCI 측 준비는?**

- Decision: seal "ocikms" { key_id, crypto_endpoint, management_endpoint, auth_type_api_key="false" }(인스턴스 프린시펄). OCI: platform 컴파트먼트에 DEFAULT 타입 Vault 1개 + AES 256(length 32) SOFTWARE 보호 키, 동적 그룹 matching_rule = Any {instance.id='<노드A OCID>', instance.id='<노드B OCID>'}, 정책 `Allow dynamic-group vault-unseal to use keys in compartment <c> where target.key.id = '<key OCID>'`. 모두 OpenTofu로 관리.
- Rationale: 래퍼는 InstancePrincipalConfigurationProvider + Encrypt/Decrypt/GetKey(현재 key version 조회)만 사용하므로 `use keys`(inspect→read→use 누적)면 충분하고 target.key.id 조건으로 최소권한. SOFTWARE 키는 HSM key-version 과금을 피함(Encrypt는 AES_256_GCM 지원). 환경변수(VAULT_OCIKMS_SEAL_KEY_ID 등) 대신 HCL 명시로 GitOps 추적.
- Alternatives considered: auth_type_api_key=true + ~/.oci/config를 Secret 마운트(키 로테이션 부담), Shamir 수동 unseal(Pod 재시작마다 수동), Transit seal(별도 Vault 필요).
- Source: <https://developer.hashicorp.com/vault/docs/configuration/seal/ocikms>

**VAULT-D5. vault operator init 자동화와 recovery key·root 토큰 처리?**

- Decision: 1회 수동 init: `vault operator init -recovery-shares=3 -recovery-threshold=2 -format=json`(auto-unseal이므로 unseal key 대신 recovery key 반환). 출력은 즉시 비밀번호 관리자(오프라인)로 이동, 부트스트랩(OIDC·정책·k8s auth) 후 root 토큰 `vault token revoke -self`. 자동 init 스크립트는 만들지 않음(`-status`로 멱등 체크만).
- Rationale: HashiCorp 권고: root 토큰은 초기 설정에만 쓰고 즉시 폐기, 필요 시 `generate-root`(auto-unseal에서는 recovery key 사용). 2.0.0부터 sys/generate-root·sys/rekey는 유효 토큰도 요구. 1인 운영이라 3/2로 충분.
- Alternatives considered: init Job이 키를 K8s Secret에 저장(비밀 노출), 1/1 recovery key(분실 시 복구 불가), PGP 암호화 출력(-recovery-pgp-keys)은 선택.
- Source: <https://developer.hashicorp.com/vault/docs/commands/operator/init>

**VAULT-D6. Vault 내부 설정(auth/policy/role/OIDC)의 관리 방식?**

- Decision: OpenTofu `hashicorp/vault` provider 5.11.0(MPL 2.0)으로 코드화, 상태는 OCI Object Storage S3 백엔드(기존 OpenTofu 스택과 동일), 실행은 운영자 PC에서 cloudflared 터널/port-forward 경유.
- Rationale: 수동 CLI는 재현 불가·드리프트 발생; provider는 MPL이라 라이선스 문제 없음. Argo CD는 Vault를 '읽기'만 하므로(ESO) 구성은 Tofu가 적합.
- Alternatives considered: bash 부트스트랩 스크립트(초기 1회는 병행), Argo CD PostSync Job(토큰 관리 난점).
- Source: <https://github.com/hashicorp/terraform-provider-vault/releases>

**VAULT-D7. Kubernetes auth 설정 순서와 ESO 연동은?**

- Decision: (1) Helm 배포+init → (2) `vault auth enable kubernetes` → (3) `auth/kubernetes/config`에 kubernetes_host만 지정(로컬 SA 토큰·CA 자동 사용) → (4) 소비자별 role에 bound_service_account_names/namespaces + audience 필수(ESO role: external-secrets/external-secrets, audience=vault) → (5) ESO 설치 → (6) ClusterSecretStore(vault provider, kv v2, auth.kubernetes.serviceAccountRef{name,namespace,audiences:[vault]}) → (7) ExternalSecret.
- Rationale: Vault가 Pod 안에 있으면 로컬 SA 토큰을 리뷰어 JWT로 쓰는 것이 권장(1.9.3+, 단기 토큰 자동 재읽기). ESO 문서: 1.20은 경고, 1.21+는 audience 없으면 인증 실패. ClusterSecretStore는 serviceAccountRef.namespace 필수.
- Alternatives considered: 장수명 리뷰어 토큰(보안 후퇴), 클라이언트 JWT를 리뷰어로 사용(disable_local_ca_jwt=true, CRB 관리 부담), Vault Secrets Operator/CSI provider.
- Source: <https://developer.hashicorp.com/vault/docs/auth/kubernetes>

**VAULT-D8. ESO 설치·동기화 정책?**

- Decision: 차트 2.10.0을 Argo CD Application으로, syncOptions ServerSideApply=true 필수(CRD 256KB 초과), installCRDs=true, controller/webhook/certController 각 1 replica, nodeSelector role=platform. ExternalSecret 기본 refreshInterval 1h(Periodic), dataFrom.extract로 kv 경로 전체를 Secret으로, creationPolicy Owner.
- Rationale: ESO 공식 문서가 CRD 크기 때문에 server-side apply를 요구. 단일 노드라 leaderElect 불필요. 1h 폴링은 무료 리소스에서 충분하고 회전 시 `refreshPolicy`/annotation으로 강제 가능.
- Alternatives considered: refreshInterval 0(1회 생성만), CreatedOnce, Vault Agent 사이드카.
- Source: <https://external-secrets.io/latest/introduction/getting-started/>

**VAULT-D9. Vault OIDC(Authentik) 로그인과 UI 노출?**

- Decision: Authentik OAuth2/OIDC provider(Confidential, redirect URI Strict: https://vault.joshuatech.dev/ui/vault/auth/oidc/oidc/callback, http://localhost:8250/oidc/callback). Vault: oidc_discovery_url=https://<authentik>/application/o/<slug>/ (끝 슬래시), role admin에 bound_audiences=<client id>, user_claim=sub, groups_claim=groups, oidc_scopes=profile,email; external identity group + group-alias(authentik 그룹명)로 정책 매핑. UI는 ui=true + Traefik + Cloudflare Access(GitHub IdP) 뒤에만 노출.
- Rationale: authentik 공식 통합 문서 절차 그대로; 기본 profile scope가 groups 클레임 제공. 그룹→정책 매핑으로 Authentik에서 권한 회수 가능.
- Alternatives considered: GitHub auth method 직접 사용(조직 필요), userpass(MFA 없음).
- Source: <https://integrations.goauthentik.io/services/hashicorp-vault/>

**VAULT-D10. Shamir↔KMS seal 마이그레이션 전략?**

- Decision: 처음부터 ocikms로 init(Shamir 단계 생략, 마이그레이션 회피). 비상 절차만 문서화: KMS→Shamir는 seal 블록에 disabled="true" 추가 후 재기동, `vault operator unseal -migrate`에 recovery key 입력(→unseal key). Shamir→KMS는 seal 블록 추가 후 재기동, `-migrate`에 unseal key 입력(→recovery key), 로그 `seal re-wrap completed` 확인. 단일 노드 Raft: 노드 내리고 설정 변경 후 재기동, 다운타임 필수.
- Rationale: 공식 문서: 마이그레이션은 전체 클러스터 다운타임과 신·구 seal 동시 가용을 요구. 단일 노드이므로 standby 순회 절차 불필요.
- Alternatives considered: Shamir로 시작 후 KMS로 전환(불필요한 다운타임·복잡도).
- Source: <https://developer.hashicorp.com/vault/docs/concepts/seal>

### 설정 스니펫

**vault-values.yaml (hashicorp/vault 0.34.1, Raft 1 replica + ocikms seal)** — <https://raw.githubusercontent.com/hashicorp/vault-helm/main/values.yaml>
```
global:
  tlsDisable: true            # 내부 평문, TLS는 Traefik 종단
injector: { enabled: false }
csi: { enabled: false }
ui: { enabled: true }         # Service만; UI 자체는 HCL ui = true
server:
  image: { repository: hashicorp/vault, tag: "2.0.4" }
  nodeSelector: { role: platform }
  resources:
    requests: { cpu: 100m, memory: 256Mi }
    limits: { memory: 512Mi }
  dataStorage: { enabled: true, size: 5Gi, storageClass: local-path }
  authDelegator: { enabled: true }   # system:auth-delegator CRB
  ha:
    enabled: true
    replicas: 1
    raft:
      enabled: true
      setNodeId: true
      config: |
        ui = true
        disable_mlock = true        # 2.0.2+ 이미지 cap_ipc_lock 없음, raft 권장값
        listener "tcp" {
          address         = "[::]:8200"
          cluster_address = "[::]:8201"
          tls_disable     = 1
          x_forwarded_for_authorized_addrs = "10.42.0.0/16"   # K3s Pod CIDR(Traefik)
        }
        storage "raft" { path = "/vault/data" }
        seal "ocikms" {
          key_id              = "ocid1.key.oc1.ap-chuncheon-1.<...>"
          crypto_endpoint     = "https://<prefix>-crypto.kms.ap-chuncheon-1.oraclecloud.com"
          management_endpoint = "https://<prefix>-management.kms.ap-chuncheon-1.oraclecloud.com"
          auth_type_api_key   = "false"   # 인스턴스 프린시펄
        }
        service_registration "kubernetes" {}
```

**OpenTofu: OCI KMS 키 + 동적 그룹 + 정책** — <https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/kms_key.html>
```
resource "oci_kms_vault" "platform" {
  compartment_id = var.platform_compartment_id
  display_name   = "joshuatech-platform"
  vault_type     = "DEFAULT"
}
resource "oci_kms_key" "vault_unseal" {
  compartment_id      = var.platform_compartment_id
  display_name        = "vault-unseal"
  management_endpoint = oci_kms_vault.platform.management_endpoint
  protection_mode     = "SOFTWARE"          # HSM은 key version 과금
  key_shape { algorithm = "AES"  length = 32 }   # AES-256
}
resource "oci_identity_dynamic_group" "vault_unseal" {
  compartment_id = var.tenancy_ocid
  name           = "vault-unseal"
  description    = "K3s nodes allowed to unseal Vault"
  matching_rule  = "Any {instance.id = '${var.node_a_ocid}', instance.id = '${var.node_b_ocid}'}"
}
resource "oci_identity_policy" "vault_unseal" {
  compartment_id = var.tenancy_ocid
  name           = "vault-unseal"
  description    = "Vault ocikms seal"
  statements = [
    "Allow dynamic-group vault-unseal to use keys in compartment ${var.platform_compartment_name} where target.key.id = '${oci_kms_key.vault_unseal.id}'",
  ]
}
output "vault_seal" {
  value = {
    key_id              = oci_kms_key.vault_unseal.id
    crypto_endpoint     = oci_kms_vault.platform.crypto_endpoint
    management_endpoint = oci_kms_vault.platform.management_endpoint
  }
}
```

**init → kv → kubernetes auth → ESO role (1회 부트스트랩)** — <https://developer.hashicorp.com/vault/docs/auth/kubernetes>
```
# init (auto-unseal: recovery key 반환), 출력은 즉시 오프라인 보관
kubectl -n vault exec vault-0 -- vault operator init -status || \
kubectl -n vault exec vault-0 -- vault operator init \
  -recovery-shares=3 -recovery-threshold=2 -format=json > vault-init.json
export VAULT_ADDR=http://127.0.0.1:8200   # kubectl port-forward svc/vault 8200
export VAULT_TOKEN=$(jq -r .root_token vault-init.json)

vault secrets enable -path=kv -version=2 kv
vault auth enable kubernetes
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"   # 로컬 SA 토큰·CA 자동(1.9.3+)
vault policy write eso-reader - <<'EOF'
path "kv/data/*"     { capabilities = ["read"] }
path "kv/metadata/*" { capabilities = ["read", "list"] }
EOF
vault write auth/kubernetes/role/external-secrets \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  audience=vault token_policies=eso-reader token_ttl=1h
# ... OIDC/정책 설정 후
vault token revoke -self        # root 토큰 폐기 (필요 시 generate-root + recovery key)
```

**ESO ClusterSecretStore + ExternalSecret (external-secrets.io/v1)** — <https://external-secrets.io/latest/provider/hashicorp-vault/>
```
# Argo CD Application external-secrets(chart 2.10.0): syncOptions [ServerSideApply=true, CreateNamespace=true]
# values: installCRDs: true, replicaCount: 1, webhook.replicaCount: 1, certController.replicaCount: 1, nodeSelector: {role: platform}
---
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata: { name: vault }
spec:
  provider:
    vault:
      server: "http://vault.vault.svc:8200"
      path: "kv"          # KV v2 마운트
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: "external-secrets"
            namespace: "external-secrets"   # ClusterSecretStore는 필수
            audiences: ["vault"]            # Vault 1.21+ / role.audience와 일치
  conditions:
    - namespaces: ["platform", "dev", "prod"]
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: api-db, namespace: prod }
spec:
  refreshInterval: 1h
  secretStoreRef: { name: vault, kind: ClusterSecretStore }
  target: { name: api-db, creationPolicy: Owner }
  dataFrom:
    - extract: { key: prod/api/db }   # kv/data/prod/api/db 의 모든 키
```

**Vault OIDC ← Authentik (그룹 매핑 포함)** — <https://integrations.goauthentik.io/services/hashicorp-vault/>
```
# authentik: OAuth2/OIDC provider, Confidential, redirect URIs(Strict):
#   https://vault.joshuatech.dev/ui/vault/auth/oidc/oidc/callback
#   http://localhost:8250/oidc/callback
vault auth enable oidc
vault write auth/oidc/config \
  oidc_discovery_url="https://auth.joshuatech.dev/application/o/vault/" \   # 끝 슬래시 필수
  oidc_client_id="$CLIENT_ID" oidc_client_secret="$CLIENT_SECRET" default_role="admin"
vault write auth/oidc/role/admin \
  bound_audiences="$CLIENT_ID" \
  allowed_redirect_uris="https://vault.joshuatech.dev/ui/vault/auth/oidc/oidc/callback" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="sub" groups_claim="groups" oidc_scopes="profile,email" \
  token_policies="default" token_ttl=1h token_max_ttl=8h
vault write identity/group name="vault-admins" type="external" policies="admin"
ACC=$(vault read -field=accessor sys/auth/oidc)
GID=$(vault read -field=id identity/group/name/vault-admins)
vault write identity/group-alias name="vault-admins" mount_accessor="$ACC" canonical_id="$GID"   # authentik 그룹명
```

**seal 마이그레이션 (비상용 KMS→Shamir / Shamir→KMS)** — <https://developer.hashicorp.com/vault/docs/concepts/seal>
```
# KMS → Shamir: 기존 seal 블록에 disabled 추가, Pod 재기동(단일 노드 = 전체 다운타임)
seal "ocikms" {
  disabled            = "true"
  key_id              = "..."
  crypto_endpoint     = "..."
  management_endpoint = "..."
}
# $ vault operator unseal -migrate      # recovery key를 threshold만큼 → unseal key로 승격
# Shamir → KMS: seal 블록 추가 후 재기동, `vault operator unseal -migrate` 에 unseal key 입력 → recovery key
# 로그 "seal re-wrap completed" 확인. 마이그레이션 중 신·구 seal 모두 접근 가능해야 함.
```

### 함정

- Vault 2.0.2+ 공식 이미지는 cap_ipc_lock을 제거 → `disable_mlock = true` 필수(raft에서는 원래 권장). vault-helm 0.32.0+는 HCL에 없으면 자동으로 끝에 추가하지만, 2.0.4는 HCL 중복 속성을 파싱 오류로 거부하므로 명시할 땐 한 번만 쓸 것.
- Vault 2.0.0부터 sys/rekey·sys/generate-root 등 이전에 비인증이던 엔드포인트가 유효 토큰 + recovery key 조각을 함께 요구. root 토큰 폐기 후 비상 복구 절차(generate-root)를 미리 리허설.
- Kubernetes auth `audience`: ESO 문서는 Vault 1.21+에서 role에 audience 없으면 인증 실패라고 명시하나 Vault 공식 문서는 예시만 제공(변경 추적기에는 JWT auth의 bound_audiences 필수화만 기록). 모든 role에 audience를 넣고 ESO store에 `audiences: [vault]`를 맞추면 어느 쪽이든 안전. K3s 기본 마운트 토큰의 aud는 `vault`가 아니므로 TokenRequest 기반 클라이언트(ESO)만 이 값이 붙는다.
- ESO CRD는 256KB 한도를 넘어 client-side apply가 실패 → Argo CD Application에 `ServerSideApply=true`(설계의 SSA 전제와 일치). ClusterSecretStore의 serviceAccountRef.namespace 누락 시 인증 실패.
- OCI 인스턴스 프린시펄은 Pod 안의 Vault가 IMDS(169.254.169.254, v2는 `Authorization: Bearer Oracle` 헤더)에 직접 닿아야 함 → NetworkPolicy egress 허용 필요, 프록시 경유(X-Forwarded-*) 요청은 IMDS가 거부. nodeSelector role=platform이라 노드 A OCID만으로 동작하지만, 노드 B로 옮겨야 하는 DR을 위해 동적 그룹에 두 인스턴스 OCID를 모두 넣을 것(재이미지 시 OCID 유지되므로 규칙 변경 불필요).
- OCI KMS 키: Encrypt는 AES(AES_256_GCM)/RSA만 지원 → AES length 32. protection_mode는 생성 후 변경 불가, SOFTWARE 선택으로 HSM key-version 과금 회피. 키 회전 시 래퍼가 encrypt마다 CurrentKeyVersion을 갱신하므로 회전은 안전하나, 구 버전이 비활성/삭제되면 저장된 root key를 복호화 못 함 → 키 버전 삭제 금지, 키 삭제 보호(OCI 삭제 대기 기간) 유지.
- crypto/management 엔드포인트는 OCI Vault마다 다른 호스트명(`https://<prefix>-crypto.kms.ap-chuncheon-1.oraclecloud.com`) → 하드코딩하지 말고 OpenTofu `oci_kms_vault` 출력 또는 `oci kms management vault get`에서 읽어 values로 주입.
- Recovery key로는 unseal 불가 → OCI KMS 장애/키 손실 = Vault 정지(seal 마이그레이션도 양쪽 seal 필요). 완화: `vault operator raft snapshot save` CronJob → OCI Object Storage, 키는 별도 컴파트먼트에 두고 OpenTofu에서 `prevent_destroy`.
- seal 마이그레이션은 다운타임 필수. 단일 노드 Raft는 노드 내린 뒤 설정 변경·재기동 후 `vault operator unseal -migrate`만 수행(standby 순회 절차 불필요).
- vault-helm 기본 `updateStrategyType: OnDelete` → 차트/이미지 업그레이드 후 Pod가 자동 재생성되지 않음(Argo CD가 OutOfSync 유지). 업그레이드 절차에 Pod 삭제 단계를 넣거나 RollingUpdate로 변경.
- readinessProbe 기본값은 sealed 상태에서 NotReady → Service에서 제외. auto-unseal 정상이면 문제없지만, KMS 문제로 sealed면 Traefik 라우팅이 끊겨 UI로 진단 불가 → kubectl exec/로그로 확인.
- Vault UI를 Cloudflare Access 뒤에 두면 OIDC 콜백(`/ui/vault/auth/oidc/oidc/callback`)도 Access 세션이 있어야 통과(이중 로그인). CLI `vault login -method=oidc`는 localhost:8250 콜백이라 브라우저 흐름은 되지만 VAULT_ADDR가 Access 뒤 도메인이면 API 호출이 차단됨 → 운영자 CLI는 cloudflared/kubectl port-forward 경로 사용.
- authentik discovery URL은 `/application/o/<slug>/` 끝 슬래시 필수; redirect URI는 스킴·호스트·포트·슬래시까지 정확히 일치해야 함(Vault 문서 명시).
- ui.enabled=true는 Service만 만들고 UI 자체는 HCL `ui = true`; injector.enabled 기본 "-"는 global.enabled를 상속(=true)이라 명시적으로 false 지정해야 vault-k8s 웹훅이 설치되지 않음.
- ESO는 `refreshInterval: 0`이면 1회 생성 후 갱신 안 함; Vault 값 회전을 반영하려면 주기적 Periodic(1h) 또는 annotation 강제 갱신 절차 필요.
- Vault Community는 Enterprise LTS(1.16/1.19) 대상이 아니며 Enterprise 표준 지원도 약 1년 → 2.0.x 패치를 Renovate로 추적하고 2.1 이후 마이너 업그레이드 시 upgrade guide 확인.

### 미확인

- OCI Vault 과금 1차 출처 미확인(oracle.com 가격 페이지 403). 2차 출처: SOFTWARE 키 무료, HSM 키 version당 약 US$0.53/월(첫 20 version 무료), Virtual Private Vault 시간당 과금 — 콘솔 비용 추정기로 검증 필요.
- Vault 2.0.x에서 Kubernetes auth role에 audience가 없을 때 실제로 실패하는지(ESO 문서) vs 경고만인지(Vault 문서 무언급) — E2E에서 확인(어쨌든 audience 설정).
- OCI 동적 그룹이 Default 외 identity domain에 있을 때 정책 참조 문법(그룹은 `group '<domain>'/<name>` 형식 확인, dynamic-group 동일 형식은 미검증) — 테넌시 도메인 구성 확인 후 결정.
- Raft 스냅샷을 다른 seal(키) 상태에서 복원할 때 `vault operator raft snapshot restore -force` 필요 여부 — 백업/복구 리허설에서 검증.
- Vault Community 2.0.x의 지원/패치 기간(Enterprise 문서만 확인됨, CE는 별도 명시 없음).
- ESO 2.10.0이 external-secrets.io/v1beta1 API를 여전히 서빙하는지(차트 주석은 v1alpha1 중단만 언급) — v1만 사용하면 무관.
- ap-chuncheon-1 KMS 엔드포인트 도메인이 `*.kms.ap-chuncheon-1.oraclecloud.com`인지 `*.oci.oraclecloud.com` 신형인지 — 데이터 소스 출력값을 그대로 사용하면 무관.
- recovery-shares/threshold 최소값(1/1 허용 여부)은 미확인 — 3/2 채택으로 회피.


## R5 CNPG · barman-cloud

R5 — CloudNativePG 1.30 + plugin-barman-cloud + OCI Object Storage S3 호환 (PG 18, arm64 K3s 단일 인스턴스)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| CloudNativePG operator | 1.30.0 (K8s 1.34–1.36, PG 14–18, 기본 PG 이미지 18.4; in-tree barman은 1.31.0에서 제거) | 2026-06-29 | <https://github.com/cloudnative-pg/cloudnative-pg/releases/tag/v1.30.0> |
| Helm chart cnpg/cloudnative-pg | 0.29.0 (appVersion 1.30.0, kubeVersion >=1.29) | 2026-06-29 | <https://github.com/cloudnative-pg/charts/releases> |
| plugin-barman-cloud (CNPG-I) | v0.14.0 (CNPG ≥1.26, cert-manager 필수; 이미지 linux/amd64+arm64 확인) | 2026-07-29 | <https://github.com/cloudnative-pg/plugin-barman-cloud/releases> |
| Helm chart cnpg/plugin-barman-cloud | 0.7.1 (appVersion v0.14.0) | 2026-07-29 | <https://github.com/cloudnative-pg/charts/releases> |
| PostgreSQL operand image (standard, trixie) | ghcr.io/cloudnative-pg/postgresql:18.6-202608310817-standard-trixie (ClusterImageCatalog major 18, sha256 고정; linux/arm64 매니페스트 확인; pgvector·pgaudit·pg_failover_slots·JIT 포함) | 2026-08-31 (카탈로그 갱신일) | <https://raw.githubusercontent.com/cloudnative-pg/artifacts/main/image-catalogs/catalog-standard-trixie.yaml> |
| pgvector | standard 이미지 내장(PGDG postgresql-18-pgvector 0.8.4-1.pgdg13+1 기준) / 별도 image-volume 이미지 ghcr.io/cloudnative-pg/pgvector:0.8.6-18-trixie(arm64 포함) | 2026-08 (GHCR 태그 조회) | <https://github.com/cloudnative-pg/postgres-extensions-containers> |
| pg_bigm | v1.2-20250903 (PG 18 지원; PGDG apt에 패키지 없음, CNPG 확장 이미지 없음 → 자체 빌드) | 2025-09-02 | <https://github.com/pgbigm/pg_bigm/releases> |
| K3s | v1.36.4+k3s1 (containerd 2.3.x; ImageVolume GA는 K8s 1.36, KEP-4639) | 2026-08-27 | <https://github.com/k3s-io/k3s/releases> |
| Django | 6.1 (PG ≥15, psycopg ≥3.1.12, Python 3.12–3.14; PG18 virtual generated column 지원) | 2026-08-05 | <https://docs.djangoproject.com/en/6.1/releases/6.1/> |
| psycopg | 3.3.5 (PG 18 libpq 지원은 3.2.8부터, Python 3.14는 3.2.10부터; psycopg-binary cp313 manylinux_2_28_aarch64 휠 존재) | 2026-08-31 | <https://pypi.org/project/psycopg/> |
| django-ninja | 1.7.0 | 2026-08-30 | <https://pypi.org/project/django-ninja/> |

### 결정

**CNPG-D1. CNPG operator 설치 방식은?**

- Decision: Argo CD helm 소스로 cnpg/cloudnative-pg 0.29.0을 cnpg-system에 설치(clusterWide, replicaCount 1). config.data에 ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES="true"를 켜 operator 업그레이드 시 단일 PG 인스턴스 재시작을 피한다. crds.create=true, Argo ServerSideApply(CRD 크기 대응).
- Rationale: 차트가 appVersion 1.30.0을 그대로 추적하고 Renovate로 버전 갱신이 쉬움. 인스턴스 1개라 primaryUpdateStrategy(switchover)는 의미가 없고, in-place update만이 무중단 수단. 차트 제거 시 CRD는 남으므로(삭제하면 Cluster·PVC 연쇄 삭제) Argo prune 정책에서 CRD를 제외.
- Alternatives considered: raw manifest cnpg-1.30.0.yaml(kustomize remote base; 버전 갱신 수동) / OLM(OperatorHub, K3s에서 불필요한 부담).
- Source: <https://raw.githubusercontent.com/cloudnative-pg/charts/main/charts/cloudnative-pg/README.md>

**CNPG-D2. PG 18 이미지와 확장은 어떻게 고르나?**

- Decision: 공식 ClusterImageCatalog(catalog-standard-trixie.yaml, sha256 고정)를 gitops에 vendoring하고 Cluster는 imageCatalogRef(major 18)로 참조. standard 플레이버 사용(pgvector·pgaudit·pg_failover_slots·LLVM JIT 내장, arm64 매니페스트 확인).
- Rationale: minimal은 PG18부터 JIT 미포함이고 pgvector도 없음. standard면 pgvector를 위해 image-volume 확장을 쓸 필요가 없어 구성 단순. 카탈로그는 digest 고정이라 재현성 확보, Renovate가 파일 갱신 PR을 만들면 됨.
- Alternatives considered: spec.imageName에 태그 직접 고정(카탈로그보다 갱신 수작업) / minimal + ghcr.io/cloudnative-pg/pgvector:0.8.6-18-trixie image-volume(JIT 없음).
- Source: <https://cloudnative-pg.io/docs/1.30/image_catalog>

**CNPG-D3. pg_bigm(한·일 2-gram 검색)은 어떻게 넣나?**

- Decision: 자체 확장 이미지(image-volume)로 제공: pg_bigm v1.2-20250903 소스를 standard 이미지(builder)에서 make 후 scratch에 /lib, /share/extension만 복사(postgres-extensions-containers 레이아웃), ubuntu-24.04-arm 러너로 ghcr.io/<org>/pg_bigm:1.2-20250903-18-trixie 빌드·attestation. Cluster spec.postgresql.extensions로 마운트(K3s 1.36 = ImageVolume GA, containerd 2.3; PG18 extension_control_path 필요).
- Rationale: PGDG apt(trixie/arm64)에 postgresql-18-pg-bigm이 없고 CNPG 커뮤니티 확장 이미지 8종(pgaudit, pg_crash, pg_ivm, pgrouting, pgvector, postgis, timescaledb-oss, wal2json)에도 없음. 확장 이미지 방식이면 operand 이미지를 포크하지 않아 카탈로그 digest 갱신을 그대로 따라갈 수 있음.
- Alternatives considered: 커스텀 operand 이미지(FROM standard + 빌드; 이미지 갱신마다 재빌드 필요) / pg_bigm 포기하고 contrib pg_trgm(3-gram, CJK 2글자 검색 약함) / PGroonga(역시 자체 빌드).
- Source: <https://cloudnative-pg.io/docs/1.30/imagevolume_extensions>

**CNPG-D4. Cluster CR 기본 형태(단일 노드 B, local-path)?**

- Decision: instances 1, storage.storageClass local-path size 40Gi(walStorage 미분리), resources requests=limits 1 CPU/2Gi(Guaranteed QoS), shared_buffers 512MB(25%), affinity.nodeSelector role=data, enablePodAntiAffinity false, enableSuperuserAccess false(기본), postgresql.parameters로 max_connections·work_mem 등 명시, pg_hba는 CNPG 기본(scram-sha-256, TLS 1.3).
- Rationale: Guaranteed QoS면 CNPG가 PG_OOM_ADJUST_VALUE=0을 적용해 postmaster보다 자식 프로세스가 먼저 OOM-kill 됨. local-path는 확장이 불가하므로 크기를 처음부터 넉넉히 잡아야 함. walStorage는 한번 추가하면 제거 불가라 단일 볼륨으로 시작.
- Alternatives considered: Longhorn 등 CSI(2노드에 과함) / walStorage 분리(관리 복잡, 이점은 I/O 병렬화뿐).
- Source: <https://cloudnative-pg.io/docs/1.30/resource_management>

**CNPG-D5. pod별 database·role을 선언적으로 어떻게 관리하나?**

- Decision: 1.30의 DatabaseRole CRD로 pod마다 두 role — <app>_owner(login, 마이그레이션·DDL 소유) / <app>_app(login, 런타임, bypassrls/superuser/createdb/createrole 모두 false = 기본값). 비밀번호는 Vault→ESO가 만든 kubernetes.io/basic-auth Secret(label cnpg.io/reload: "true")을 passwordSecret으로 참조. Database CRD는 owner=<app>_owner, schemas, extensions(vector)와 databaseReclaimPolicy retain. app role의 DML 권한과 ALTER DEFAULT PRIVILEGES는 pod의 Django 마이그레이션(owner로 실행)에서 부여.
- Rationale: PG는 superuser·BYPASSRLS·테이블 owner가 RLS를 우회하므로 런타임 role을 owner와 분리해야 RLS(SET LOCAL 미들웨어)가 실제로 적용됨. DatabaseRole은 독립 CR라 app 디렉터리와 함께 gitops로 관리 가능하고 1.30에서 비밀번호를 SCRAM으로 인코딩해 전달(CVE-2026-55765). Database CRD에는 grant 필드가 없어 권한은 마이그레이션이 담당.
- Alternatives considered: Cluster.spec.managed.roles(주기적 reconcile·ensure absent 지원, 그러나 Cluster CR에 집중) / initdb.postInitApplicationSQL(초기 1회뿐) / superuser 사용(금지).
- Source: <https://cloudnative-pg.io/docs/1.30/declarative_role_management>

**CNPG-D6. 백업 방식과 대상은?**

- Decision: plugin-barman-cloud v0.14.0(Helm 0.7.1, cnpg-system, cert-manager 재사용) + ObjectStore `oci-backups`: endpointURL https://<namespace>.compat.objectstorage.ap-chuncheon-1.oci.customer-oci.com, destinationPath s3://joshuatech-cnpg-backups/, s3Credentials(accessKeyId·secretAccessKey·region 모두 ESO Secret 키 참조, region=ap-chuncheon-1), wal.compression zstd, data.compression lz4, retentionPolicy "14d". Cluster.spec.plugins에 isWALArchiver true. ScheduledBackup 매일 18:00 UTC(03:00 KST), immediate true, backupOwnerReference self, method plugin.
- Rationale: in-tree barmanObjectStore는 1.31.0에서 삭제 예정(1.30에서 이미 deprecated). volumeSnapshot은 local-path에 CSI 스냅샷이 없어 불가. 플러그인의 barman-cloud 라이브러리는 s3Credentials.region을 AWS_DEFAULT_REGION으로 export하므로 OCI가 요구하는 SigV4 리전 서명이 맞음. lz4는 2 OCPU에서 CPU 부담이 작음.
- Alternatives considered: pgBackRest(CNPG-I 플러그인 없음) / OCI 네이티브 API(barman 미지원) / 보존 30d(오브젝트 비용 증가, PAYG).
- Source: <https://cloudnative-pg.io/plugin-barman-cloud/docs/object_stores/>

**CNPG-D7. OCI S3 자격 증명과 버킷은 어떻게 준비하나?**

- Decision: OpenTofu로 전용 IAM 사용자 svc-cnpg-backup + 그룹 + 정책(`Allow group cnpg-backup to manage objects in compartment platform where target.bucket.name='joshuatech-cnpg-backups'`, `read buckets`), 버킷은 OpenTofu(oci_objectstorage_bucket)로 컴파트먼트에 선생성. Customer Secret Key(사용자당 최대 2개, 만료 없음, 시크릿은 생성 시 1회만 표시)를 Vault kv에 저장 → ESO → Secret 키 ACCESS_KEY_ID/ACCESS_SECRET_KEY/REGION.
- Rationale: S3 호환 API로 만든 버킷은 기본적으로 루트 컴파트먼트에 생기므로 버킷은 OCI API로 먼저 만든다. 키가 2개까지라 회전은 '새 키 생성→ESO 갱신→구 키 삭제' 순서로 가능. 인스턴스 프린시펄은 S3 호환 API에서 쓸 수 없음.
- Alternatives considered: S3 API로 버킷 생성 후 사용자별 'S3 지정 컴파트먼트' 설정(OBJECTSTORAGE_NAMESPACE_UPDATE 권한 필요) / 개인 계정 키 사용(금지).
- Source: <https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm>

**CNPG-D8. 복구(PITR) 절차는?**

- Decision: 런북: 새 Cluster `pg-main-restored`를 bootstrap.recovery.source=origin + externalClusters[origin].plugin(barmanObjectName oci-backups, serverName pg-main)으로 부트스트랩, 필요 시 recoveryTarget.targetTime(RFC3339). 복구 클러스터의 자체 아카이브는 spec.plugins에 serverName: pg-main-restored를 지정해 같은 ObjectStore의 다른 경로로. 검증 후 앱 Secret/Service 참조를 교체하고 옛 Cluster 삭제(PVC 보존).
- Rationale: CNPG는 in-place 복구를 지원하지 않고 항상 새 Cluster를 만든다. serverName 미지정 시 클러스터 이름이 쓰이므로 동일 serverName으로 아카이브하면 WAL 덮어쓰기 위험(빈 아카이브 검사에 걸려 기동 실패, cnpg.io/skipEmptyWalArchiveCheck는 사용 금지).
- Alternatives considered: bootstrap.recovery.backup.name(같은 네임스페이스 Backup 객체 참조; PITR 대상 지정은 동일) / 복제 클러스터(replica) 상시 유지(2노드 예산 초과).
- Source: <https://cloudnative-pg.io/docs/1.30/recovery>

**CNPG-D9. Django 6.1 ↔ PG 18 접속 구성은?**

- Decision: psycopg[c] 3.3.x(arm64 Dockerfile에서 libpq-dev로 빌드; 대안 psycopg[binary] aarch64 휠) + psycopg-pool, DATABASES OPTIONS {pool: {min:1,max:8}, sslmode: verify-full, sslrootcert: <cluster>-ca Secret 마운트}, CONN_MAX_AGE 0, HOST <cluster>-rw. 마이그레이션 Job은 owner Secret, 런타임 Deployment는 app Secret.
- Rationale: Django 6.1은 PG 15+ / psycopg 3.1.12+를 요구하고 PG 18 libpq 지원은 psycopg 3.2.8부터. CNPG는 TLS 1.3만 허용하므로 클라이언트에 CA를 주면 verify-full이 무료로 가능. psycopg pool을 쓰면 Pooler(PgBouncer) 없이도 2 OCPU에서 연결 수를 억제.
- Alternatives considered: CNPG Pooler(PgBouncer) 추가(pod 1개 더, 메모리) / psycopg2(향후 제거 예고).
- Source: <https://docs.djangoproject.com/en/6.1/ref/databases/>

**CNPG-D10. Argo CD sync-wave 순서는?**

- Decision: cert-manager(-5) → cnpg operator(-4) → plugin-barman-cloud(-3) → ClusterImageCatalog·ObjectStore·ESO Secret(-2) → Cluster(-1) → DatabaseRole(0) → Database(1) → ScheduledBackup(2). Database/DatabaseRole/ScheduledBackup의 cluster 참조는 1.30부터 immutable.
- Rationale: 플러그인은 cert-manager 인증서로 gRPC를 보호하고 operator와 같은 네임스페이스에 있어야 함. Database.spec.owner는 이미 존재하는 role이어야 하므로 DatabaseRole이 먼저.
- Alternatives considered: 단일 wave + 재시도(수렴은 되지만 Argo Degraded 노이즈).
- Source: <https://cloudnative-pg.io/plugin-barman-cloud/docs/installation/>

### 설정 스니펫

**cnpg operator Helm values (Argo CD helm source)** — <https://raw.githubusercontent.com/cloudnative-pg/charts/main/charts/cloudnative-pg/values.yaml>
```
# chart cnpg/cloudnative-pg 0.29.0, namespace cnpg-system
replicaCount: 1
crds:
  create: true
config:
  clusterWide: true
  data:
    ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES: "true"
    INHERITED_LABELS: app.kubernetes.io/part-of
nodeSelector:
  role: platform
resources:
  requests: { cpu: 100m, memory: 200Mi }
  limits:   { cpu: 500m, memory: 400Mi }
monitoring:
  podMonitorEnabled: false
# helm repo add cnpg https://cloudnative-pg.github.io/charts
```

**plugin-barman-cloud Helm values** — <https://raw.githubusercontent.com/cloudnative-pg/charts/main/charts/plugin-barman-cloud/README.md>
```
# chart cnpg/plugin-barman-cloud 0.7.1 → v0.14.0, 반드시 namespace cnpg-system (operator와 동일), cert-manager 선행
replicaCount: 1
certificate:
  createIssuer: true      # issuerName 비우면 자체 Issuer 생성
  duration: 2160h
  renewBefore: 360h
nodeSelector:
  role: platform
# 수동 설치 대안:
# kubectl apply -f https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/v0.14.0/manifest.yaml
```

**Cluster CR (pg-main, 단일 인스턴스, local-path, 노드 B)** — <https://cloudnative-pg.io/docs/1.30/scheduling>
```
# 카탈로그: kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/artifacts/main/image-catalogs/catalog-standard-trixie.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-main
  namespace: data
spec:
  instances: 1
  imageCatalogRef:
    apiGroup: postgresql.cnpg.io
    kind: ClusterImageCatalog
    name: postgresql-standard-trixie
    major: 18
  enableSuperuserAccess: false
  storage:
    storageClass: local-path
    size: 40Gi
  resources:
    requests: { cpu: "1", memory: 2Gi }
    limits:   { cpu: "1", memory: 2Gi }
  affinity:
    enablePodAntiAffinity: false
    nodeSelector:
      role: data
  postgresql:
    parameters:
      shared_buffers: 512MB
      effective_cache_size: 1536MB
      work_mem: 8MB
      maintenance_work_mem: 128MB
      max_connections: "100"
      wal_compression: zstd
      pg_stat_statements.max: "5000"   # shared_preload_libraries는 operator가 자동 추가
    extensions:
      - name: pg_bigm
        image:
          reference: ghcr.io/<org>/pg_bigm:1.2-20250903-18-trixie
  bootstrap:
    initdb:
      database: platform
      owner: platform_owner
      dataChecksums: true
  plugins:
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: oci-backups
```

**DatabaseRole ×2 + Database (pod "blog" 예)** — <https://cloudnative-pg.io/docs/1.30/declarative_database_management>
```
# ESO가 만드는 Secret 형태(Vault kv → ExternalSecret): type kubernetes.io/basic-auth, keys username/password, label cnpg.io/reload: "true"
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata: { name: blog-owner, namespace: data }
spec:
  cluster: { name: pg-main }
  name: blog_owner
  login: true
  passwordSecret: { name: pg-main-blog-owner }
  databaseRoleReclaimPolicy: retain
---
apiVersion: postgresql.cnpg.io/v1
kind: DatabaseRole
metadata: { name: blog-app, namespace: data }
spec:
  cluster: { name: pg-main }
  name: blog_app
  login: true
  superuser: false
  bypassrls: false      # 기본값이지만 명시 (RLS 보장)
  createdb: false
  createrole: false
  connectionLimit: 20
  passwordSecret: { name: pg-main-blog-app }
---
apiVersion: postgresql.cnpg.io/v1
kind: Database
metadata: { name: blog, namespace: data }
spec:
  cluster: { name: pg-main }
  name: blog
  owner: blog_owner
  databaseReclaimPolicy: retain
  extensions:
    - { name: vector, ensure: present }
    - { name: pg_bigm, ensure: present }
  schemas:
    - { name: app, owner: blog_owner }
# app role 권한은 Django 마이그레이션(owner로 실행):
# GRANT USAGE ON SCHEMA app TO blog_app;
# GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA app TO blog_app;
# ALTER DEFAULT PRIVILEGES FOR ROLE blog_owner IN SCHEMA app GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO blog_app;
```

**ObjectStore (OCI S3 호환) + ScheduledBackup** — <https://cloudnative-pg.io/plugin-barman-cloud/docs/usage/>
```
# ESO Secret oci-s3-creds: ACCESS_KEY_ID / ACCESS_SECRET_KEY (Customer Secret Key) / REGION=ap-chuncheon-1
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata: { name: oci-backups, namespace: data }
spec:
  configuration:
    destinationPath: s3://joshuatech-cnpg-backups/
    endpointURL: https://<namespace>.compat.objectstorage.ap-chuncheon-1.oci.customer-oci.com
    s3Credentials:
      accessKeyId:     { name: oci-s3-creds, key: ACCESS_KEY_ID }
      secretAccessKey: { name: oci-s3-creds, key: ACCESS_SECRET_KEY }
      region:          { name: oci-s3-creds, key: REGION }   # → AWS_DEFAULT_REGION
    wal:  { compression: zstd, maxParallel: 2 }
    data: { compression: lz4, jobs: 1 }
  retentionPolicy: "14d"
  instanceSidecarConfiguration:
    retentionPolicyIntervalSeconds: 1800
    resources:
      requests: { cpu: 50m, memory: 128Mi }
      limits:   { cpu: 500m, memory: 256Mi }
    env:   # SigV4/체크섬 오류 시에만 활성화
      - { name: AWS_REQUEST_CHECKSUM_CALCULATION, value: when_required }
      - { name: AWS_RESPONSE_CHECKSUM_VALIDATION, value: when_required }
---
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata: { name: pg-main-daily, namespace: data }
spec:
  cluster: { name: pg-main }
  schedule: "0 0 18 * * *"   # 6필드(초 포함) = 매일 18:00 UTC / 03:00 KST
  immediate: true
  backupOwnerReference: self
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
```

**복구 Cluster (PITR)** — <https://cloudnative-pg.io/docs/1.30/recovery>
```
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata: { name: pg-main-restored, namespace: data }
spec:
  instances: 1
  imageCatalogRef: { apiGroup: postgresql.cnpg.io, kind: ClusterImageCatalog, name: postgresql-standard-trixie, major: 18 }
  storage: { storageClass: local-path, size: 40Gi }
  bootstrap:
    recovery:
      source: origin
      recoveryTarget:
        targetTime: "2026-09-01T02:30:00Z"   # 생략 시 최신 WAL까지
  externalClusters:
    - name: origin
      plugin:
        name: barman-cloud.cloudnative-pg.io
        parameters:
          barmanObjectName: oci-backups
          serverName: pg-main
  plugins:                      # 복구 클러스터 자체 아카이브(다른 serverName 필수)
    - name: barman-cloud.cloudnative-pg.io
      isWALArchiver: true
      parameters:
        barmanObjectName: oci-backups
        serverName: pg-main-restored
```

**pg_bigm 확장 이미지 Dockerfile (image-volume 레이아웃)** — <https://raw.githubusercontent.com/cloudnative-pg/postgres-extensions-containers/main/pgvector/Dockerfile>
```
ARG BASE=ghcr.io/cloudnative-pg/postgresql:18-standard-trixie
FROM $BASE AS builder
ARG PG_MAJOR=18
ARG EXT_VERSION=1.2-20250903
USER 0
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential postgresql-server-dev-${PG_MAJOR} curl ca-certificates \
 && curl -fsSL https://github.com/pgbigm/pg_bigm/archive/refs/tags/v${EXT_VERSION}.tar.gz | tar xz \
 && cd pg_bigm-${EXT_VERSION} && make USE_PGXS=1 && make USE_PGXS=1 install
FROM scratch
ARG PG_MAJOR=18
COPY --from=builder /usr/lib/postgresql/${PG_MAJOR}/lib/pg_bigm* /lib/
COPY --from=builder /usr/share/postgresql/${PG_MAJOR}/extension/pg_bigm* /share/extension/
USER 65532:65532
# GitHub Actions: runs-on ubuntu-24.04-arm, docker buildx --platform linux/arm64, 태그 1.2-20250903-18-trixie
```

**Django 6.1 DATABASES (psycopg 3 pool + verify-full)** — <https://docs.djangoproject.com/en/6.1/ref/databases/>
```
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": "pg-main-rw.data.svc",
        "PORT": 5432,
        "NAME": "blog",
        "USER": env("DB_USER"),          # 런타임 blog_app / 마이그레이션 Job blog_owner
        "PASSWORD": env("DB_PASSWORD"),
        "CONN_MAX_AGE": 0,               # pool 사용 시 0
        "OPTIONS": {
            "pool": {"min_size": 1, "max_size": 8, "timeout": 10},
            "sslmode": "verify-full",
            "sslrootcert": "/etc/cnpg/ca.crt",   # Secret pg-main-ca 마운트
            "application_name": "blog",
        },
    }
}
# pyproject: psycopg[c,pool]>=3.3.5 (arm64 빌드 시 libpq-dev) 또는 psycopg[binary,pool]
```

### 함정

- local-path(K3s 기본 SC)는 볼륨 확장 불가·용량 미강제: 40Gi는 명목값이며 실제로는 노드 B 부트 볼륨(/var/lib/rancher/k3s/storage)을 그대로 씀. instances=1이라 PVC 재생성=백업 복구이므로 부트 볼륨을 OpenTofu에서 충분히(예: 100GB+) 잡거나 전용 블록 볼륨을 그 경로에 마운트.
- in-tree barmanObjectStore/retentionPolicy는 1.30에서 deprecated, 1.31.0에서 삭제 → ScheduledBackup/Backup은 method: plugin 필수, 보존은 ObjectStore.spec.retentionPolicy(^[1-9][0-9]*[dwm]$, RECOVERY WINDOW 의미)로만.
- plugin-barman-cloud는 cert-manager 필수, operator와 같은 네임스페이스(cnpg-system) 필수. ObjectStore.spec.configuration.serverName은 API 호환용이라 항상 비워두고 Cluster plugin parameters.serverName만 사용.
- s3Credentials.region은 문자열이 아니라 Secret 키 참조(secretKeyRef)이며 사이드카에 AWS_DEFAULT_REGION으로 export됨. OCI S3 호환 API는 SigV4 필수이고 리전 ID가 실제 OCI 리전(ap-chuncheon-1)과 일치해야 함. 관련 이슈 #9724(리전 미반영, closed-not-planned)가 있어 서명 오류 시 instanceSidecarConfiguration.env에 AWS_DEFAULT_REGION을 직접 넣는 폴백을 준비.
- boto3 1.36+ 데이터 무결성 체크섬 변경으로 S3 호환 스토리지에서 x-amz-content-sha256 오류가 날 수 있음 → AWS_REQUEST_CHECKSUM_CALCULATION/AWS_RESPONSE_CHECKSUM_VALIDATION=when_required 환경변수(플러그인 문서 공식 워크어라운드).
- OCI S3 호환 API로 만든 버킷은 루트 컴파트먼트에 생성됨 → 버킷은 OpenTofu(oci_objectstorage_bucket)로 먼저 만든다. Customer Secret Key는 사용자당 최대 2개, 만료 없음, 시크릿은 생성 직후 1회만 표시. 엔드포인트는 path-style(<ns>.compat.objectstorage.<region>.oci.customer-oci.com), ListObjectsV2·버전관리·라이프사이클 등 미지원 API가 있어 barman 호출 세트를 스모크 테스트로 확인.
- ScheduledBackup.schedule은 초를 포함한 6필드 cron("0 0 18 * * *"); 5필드로 쓰면 의미가 바뀜. target prefer-standby는 인스턴스 1개면 primary로 폴백되어 베이스 백업 I/O가 서비스에 직접 영향 → 새벽(KST) 스케줄.
- 1.30부터 Database/DatabaseRole/ScheduledBackup/Pooler의 cluster 참조는 immutable(변경 시 API 거부). Database.spec.owner는 이미 존재하는 role이어야 하고(sync-wave), 이름 변경 불가, postgres/template0/template1 예약. DatabaseRole은 기존 role을 '입양'하며 inRoles에 없는 멤버십을 회수하고 생략한 속성을 기본값으로 되돌림; ensure 필드 없음(삭제는 databaseRoleReclaimPolicy).
- RLS: superuser·BYPASSRLS·테이블 owner는 RLS를 우회 → 런타임 role을 owner와 분리하고 bypassrls: false 유지. Django 마이그레이션은 owner로, 서비스는 app role로 접속(Secret 2종). 필요 시 ALTER TABLE ... FORCE ROW LEVEL SECURITY.
- enableSuperuserAccess 기본 false → postgres 비밀번호 NULL. 관리 작업은 kubectl cnpg psql(플러그인) 또는 임시로 true 전환. ALTER SYSTEM은 기본 비활성.
- PG 18 minimal 이미지는 LLVM JIT 제외, standard만 postgresql-18-jit 포함. 확장 이미지(image-volume)는 Cluster의 아키텍처·배포판·PG major와 일치해야 하며(arm64/trixie/18) 확장 이미지 변경 시 PG pod 재시작, ld_library_path/bin_path/env 변경은 수동 재시작 필요. ImageVolume은 containerd ≥2.1 필요(K3s 1.36.x = containerd 2.2/2.3), PG18 extension_control_path 필요.
- operator 업그레이드는 모든 Cluster의 롤링 재시작을 유발 → ENABLE_INSTANCE_MANAGER_INPLACE_UPDATES로 회피; PG 이미지 digest 갱신(카탈로그)은 인스턴스 1개라 stop/start 수 초 다운타임 불가피 → Renovate PR을 유지보수 창에 머지.
- CNPG 기본 파라미터 wal_level=logical, wal_keep_size=512MB, max_parallel_workers=32, archive_timeout=5min → 40Gi 중 WAL 여유 고려; 2 OCPU에 맞게 max_parallel_workers·max_worker_processes를 명시적으로 낮출 것.
- Secret 비밀번호 회전: label cnpg.io/reload: "true" 없으면 즉시 반영 안 됨. ESO ExternalSecret template에 label과 type kubernetes.io/basic-auth를 넣어야 함. 1.30은 평문 비밀번호를 SCRAM-SHA-256로 인코딩해 SQL로 전달(CVE-2026-55765).
- Helm 차트 제거는 CRD를 남기지만 CRD를 지우면 Cluster·PVC·데이터가 연쇄 삭제됨(비가역) → Argo CD Application에 CRD prune 금지 어노테이션(argocd.argoproj.io/sync-options: Prune=false)을 걸 것.
- psycopg[c]는 arm64 이미지 빌드 시 libpq-dev·gcc가 필요(psycopg[binary]는 manylinux_2_28_aarch64 휠 존재하지만 libpq 번들). Django pool 옵션은 psycopg-pool 설치 필요, psycopg2에서는 무시되며 CONN_MAX_AGE와 병용 금지.

### 미확인

- OCI S3 호환 API가 barman-cloud가 쓰는 boto3 호출(ListObjectsV2 포함 여부)을 모두 지원하는지 1차 문서로 확정 못 함. Oracle의 'CloudNativePG + OCI Object Storage' 실전 가이드(Medium, oracledevs)가 존재하지만 403으로 본문 확인 실패 → plan에 barman-cloud-backup-list/복구 스모크 테스트 태스크 필수.
- Kubernetes 1.36 ImageVolume GA는 KEP-4639(Stable target 1.36, GA PR)와 2차 블로그로 확인했으나 공식 feature-gate 표 페이지를 읽지 못함 → K3s 1.36.4에서 kubectl explain pod.spec.volumes.image 로 확인.
- 18.6-202608310817-standard-trixie 이미지에 실제 포함된 pgvector 버전(PGDG 인덱스 0.8.4 확인, 확장 이미지는 0.8.6까지 존재) — 이미지 SBOM으로 확인 필요.
- plugin-barman-cloud의 region 처리 이슈 #9724는 closed-not-planned(1.28/플러그인 조합 보고) — v0.14.0에서 s3Credentials.region → AWS_DEFAULT_REGION이 실제로 동작하는지 e2e로 검증(실패 시 env 폴백).
- plugin Helm 차트에서 certificate.issuerName을 비웠을 때 self-signed Issuer가 자동 생성되는지(values createIssuer: true) 설치 시 확인; 기존 cert-manager ClusterIssuer 재사용 여부 결정.
- pg_bigm scratch 레이아웃(/lib, /share/extension)만으로 CREATE EXTENSION이 동작하는지(공유 라이브러리 의존성 없음 예상) 자체 이미지 빌드 후 확인. postgresql-server-dev-18이 standard 이미지의 apt 소스(PGDG)에서 설치 가능한지도 빌드에서 검증.
- OCI 부트/블록 볼륨 크기와 PAYG 비용(블록 스토리지 GB-월 단가) 확정 → local-path 40Gi 실효 용량 확보 방안(부트 볼륨 확장 vs 전용 블록 볼륨) 선택.
- PGDG apt 인덱스가 postgresql-18을 18.3으로 보고했는데 CNPG 이미지는 18.6 — apt 미러 지연으로 추정, 자체 빌드 시 최신 minor 반영 여부 확인.
- Argo CD에서 CNPG Cluster CR의 status/annotation 변경에 따른 OutOfSync 노이즈가 있는지(ignoreDifferences 필요 여부) 실측.


## R6 Strimzi Kafka

R6 — Strimzi 1.2.0 + KRaft combined 단일 노드 Kafka 4.3.1 (K3s local-path, arm64, SCRAM-SHA-512/TLS, Argo CD Helm OCI, Python 클라이언트)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| Strimzi Cluster Operator (strimzi-kafka-operator) | 1.2.0 — 지원 Kafka 4.2.0 / 4.2.1 / 4.3.0 / 4.3.1, Kubernetes 1.30–1.36(테스트 범위, K3s v1.36 포함) | 2026-08-20 | <https://github.com/strimzi/strimzi-kafka-operator/releases/tag/1.2.0> |
| Strimzi Helm chart (OCI) | oci://quay.io/strimzi-helm/strimzi-kafka-operator 1.2.0 (defaultImageTag 1.2.0, 이미지 quay.io/strimzi/{operator,kafka}:1.2.0-kafka-4.3.1, amd64/arm64 multi-arch 0.27.0+) | 2026-08-20 | <https://github.com/strimzi/strimzi-kafka-operator/blob/main/helm-charts/helm3/strimzi-kafka-operator/README.md> |
| Strimzi CRD API | kafka.strimzi.io/v1 만 served/stored (v1beta2·v1beta1·v1alpha1 은 1.0.0 에서 제거; strimzi.io/kraft·node-pools 어노테이션은 0.48.0부터 무시) | 2026-04-28 (1.0.0) | <https://github.com/strimzi/strimzi-kafka-operator/blob/main/CHANGELOG.md> |
| Apache Kafka | 4.3.1 (Strimzi 1.2.0 기본 예제 version: 4.3.1 / metadataVersion: 4.3-IV0) | 2026-06-25 | <https://kafka.apache.org/blog/releases/> |
| Strimzi Metrics Reporter (Kafka 이미지 번들) | 0.4.0 (metricsConfig.type: strimziMetricsReporter, broker/controller 지원) | 2026-08-20 (Strimzi 1.2.0) | <https://github.com/strimzi/strimzi-kafka-operator/blob/main/CHANGELOG.md> |
| confluent-kafka (Python, librdkafka 2.15.0 번들) | 2.15.0 — Python 3.8–3.14, manylinux_2_28_aarch64 wheel 제공 (cp313: confluent_kafka-2.15.0-cp313-cp313-manylinux_2_28_aarch64.whl) | 2026-06-30 | <https://pypi.org/project/confluent-kafka/> |
| aiokafka (Python asyncio) | 0.14.0 — Python 3.10–3.14, manylinux ARM64 wheel, SCRAM-SHA-512 내장(추가 패키지 불필요) | 2026-04-29 | <https://pypi.org/project/aiokafka/> |
| K3s Local Path Provisioner (StorageClass local-path) | K3s 번들 — provisioner rancher.io/local-path, volumeBindingMode WaitForFirstConsumer, reclaimPolicy Delete, 기본 경로 /var/lib/rancher/k3s/storage | K3s 릴리스에 종속 | <https://github.com/k3s-io/k3s/blob/master/manifests/local-storage.yaml> |
| Strimzi 1.3.0 (개발 중) | main 브랜치 CHANGELOG에 1.3.0 항목 존재, 마일스톤 open(14 open / 28 closed, due date 없음) | 미정 | <https://github.com/strimzi/strimzi-kafka-operator/milestones> |

### 결정

**STRIMZI-D1. Strimzi 오퍼레이터를 어떻게 설치·감시 범위를 잡는가?**

- Decision: Argo CD Application(sync-wave 최우선)에서 Helm OCI `quay.io/strimzi-helm` chart `strimzi-kafka-operator` targetRevision `1.2.0`을 namespace `kafka`에 설치. `watchNamespaces: []`, `watchAnyNamespace: false`(설치 ns만 감시). Kafka·KafkaNodePool·KafkaTopic·KafkaUser CR 전부 `kafka` ns에 둔다.
- Rationale: 1.0.1부터 Entity Operator의 cross-namespace 감시가 `STRIMZI_ENTITY_OPERATOR_WATCHED_NAMESPACE_ENABLED=false` 기본으로 꺼져 있어 KafkaTopic/KafkaUser는 어차피 Kafka ns에 있어야 한다. 단일 ns 감시가 RBAC 최소. Argo CD는 chart `crds/`를 함께 렌더링하므로 chart 버전 bump만으로 CRD가 갱신된다(`helm upgrade`는 CRD를 갱신하지 않음). Argo CD OCI 소스는 repoURL에 `oci://` 접두사를 쓰지 않는다.
- Alternatives considered: `watchAnyNamespace: true`(모든 ns에 ClusterRoleBinding, 앱 ns에 KafkaUser 배치 가능하나 Secret 배포 문제는 동일); `strimzi.io/install/latest` YAML을 kustomize로 vendoring(CRD 수동 갱신 부담).
- Source: <https://github.com/strimzi/strimzi-kafka-operator/blob/main/helm-charts/helm3/strimzi-kafka-operator/README.md>

**STRIMZI-D2. KRaft 토폴로지와 복제 설정은?**

- Decision: KafkaNodePool 1개(`roles: [controller, broker]`, replicas 1) + Kafka CR(`version: 4.3.1`, `metadataVersion: 4.3-IV0`). config에 `offsets.topic.replication.factor=1`, `transaction.state.log.replication.factor=1`, `transaction.state.log.min.isr=1`, `default.replication.factor=1`, `min.insync.replicas=1`, `auto.create.topics.enable=false`. KafkaTopic은 `replicas: 1`.
- Rationale: Strimzi 공식 예제 `examples/kafka/kafka-single-node.yaml`이 정확히 이 구성. 노드 2대 중 Kafka는 노드 A 고정이므로 controller/broker 분리는 pod·힙만 2배. Apache Kafka 문서는 combined 모드를 production 비권장으로 두지만 단일 노드 자체가 HA가 없으므로 동일 리스크. 내부 토픽 RF 기본값 3이라 1로 명시하지 않으면 __consumer_offsets 생성 실패.
- Alternatives considered: controller 풀 + broker 풀 분리(pod 2개, +약 1 GiB RAM, 향후 broker 확장 시 무중단 롤링에 유리); 3노드 KRaft(노드 부족으로 불가).
- Source: <https://github.com/strimzi/strimzi-kafka-operator/blob/main/examples/kafka/kafka-single-node.yaml>

**STRIMZI-D3. 스토리지는?**

- Decision: `storage.type: jbod`, volume 1개 `persistent-claim`, `class: local-path`, `size: 20Gi`(명목), `deleteClaim: false`, `kraftMetadata: shared`. KafkaNodePool·entityOperator `template.pod.affinity`로 role=platform 노드 A에 고정.
- Rationale: local-path는 WaitForFirstConsumer라 첫 스케줄 노드에 PV가 생성되고 이후 영구 고정 → affinity를 명시해야 의도한 노드에 붙는다. local-path는 용량을 강제하지 않고 확장도 없으므로 크기는 명목값, 실제 상한은 retention과 디스크 모니터링. `kraftMetadata`는 볼륨 최대 1개에 `shared`만 허용. reclaimPolicy Delete라 `deleteClaim: false` 유지.
- Alternatives considered: OCI Block Volume CSI(oci-cloud-controller-manager 추가, 볼륨 비용·복잡도); ephemeral(재시작 시 데이터 소실).
- Source: <https://github.com/strimzi/strimzi-kafka-operator/blob/main/packaging/install/cluster-operator/045-Crd-kafkanodepool.yaml>

**STRIMZI-D4. 단일 노드(13 GB, 다른 플랫폼 pod 공존)에서 리소스/JVM은?**

- Decision: Kafka pod: requests cpu 250m / memory 1536Mi, limits cpu 1 / memory 2Gi, `jvmOptions: -Xms 1g, -Xmx 1g`. Entity Operator: topicOperator·userOperator 각 requests 256Mi / limits 384Mi, `jvmOptions -Xmx 256m`. Cluster Operator: chart 기본 384Mi/384Mi(cpu 200m/1000m). Kafka 스택 합계 약 3 GiB.
- Rationale: Strimzi는 `-Xmx` 미지정 시 Kafka 힙을 memory limit의 50%(최대 5 GB)로 자동 설정하고, broker 컨테이너는 페이지 캐시용으로 힙보다 훨씬 큰 메모리를 요청하라고 문서화. 1g 힙 + 1g 페이지 캐시/오프힙이 2Gi limit의 근거. TO/UO 최소치는 문서에 없고 예제만 512Mi·256Mi가 혼재하므로 256Mi/384Mi는 가정(측정 후 조정).
- Alternatives considered: `-Xmx 512m` + limit 1.5Gi(docs 소형 예제; 처리량 낮음); TO/UO 512Mi(docs 1.2.0 예제).
- Source: <https://strimzi.io/docs/operators/latest/full/configuring.html>

**STRIMZI-D5. 리스너·인증·인가는?**

- Decision: 내부 리스너 1개 `name: tls`, port 9093, `tls: true`, `authentication.type: scram-sha-512`; `spec.kafka.authorization.type: simple`, `superUsers`에 운영용 KafkaUser 이름만(SCRAM은 `CN=` 없이). plain 9092 리스너는 만들지 않음.
- Rationale: SCRAM 비밀번호는 KafkaUser `password.valueFrom.secretKeyRef`로 외부 Secret(ESO/Vault)에서 주입 가능 → 앱 ns와 kafka ns가 같은 Vault 경로를 읽으면 cross-namespace Secret 복사가 필요 없다. mTLS(type: tls)는 User Operator가 kafka ns에 만든 인증서 Secret을 앱 ns로 옮겨야 한다. broker 인증서 SAN에 `<cluster>-kafka-bootstrap.<ns>.svc(.cluster.local)`이 포함되어 hostname 검증이 그대로 통과.
- Alternatives considered: mTLS + ESO kubernetes provider로 Secret 미러링; OAuth(strimzi-kafka-oauth, Authentik)—토큰 갱신·설정 부담 큼.
- Source: <https://github.com/strimzi/strimzi-kafka-operator/blob/main/examples/security/scram-sha-512-auth/kafka.yaml>

**STRIMZI-D6. pod별 KafkaUser/KafkaTopic 규약은?**

- Decision: 토픽 `<env>.<pod>.<event>`(예: prod.blog.post-published), 사용자 `<env>-<pod>`, 컨슈머 그룹 `<env>-<pod>-*`. KafkaUser ACL: 자기 토픽 prefix `<env>.<pod>.`에 Write+Describe, 구독 토픽 literal Read+Describe, group prefix `<env>-<pod>-` Read. KafkaTopic: partitions 3, replicas 1, `retention.ms: 604800000`. 모두 platform-gitops의 kafka ns 디렉터리에서 선언(auto.create 비활성).
- Rationale: Kafka 클러스터가 하나뿐이므로 env 분리는 토픽/사용자 prefix로만 가능. 1.2.0 KafkaUser CRD의 operations enum(Read, Write, Create, Delete, Alter, Describe, ClusterAction, AlterConfigs, DescribeConfigs, IdempotentWrite, All)·patternType(literal/prefix)·host 기본 `*`에 맞춤. 토픽을 CR로 선언하므로 Create ACL 불필요.
- Alternatives considered: dev/prod 별도 Kafka 클러스터(RAM 2배); Create 권한 부여 후 앱이 토픽 자동 생성(GitOps 추적 불가).
- Source: <https://github.com/strimzi/strimzi-kafka-operator/blob/main/packaging/install/cluster-operator/044-Crd-kafkauser.yaml>

**STRIMZI-D7. 앱 pod에 SCRAM 비밀번호와 클러스터 CA를 어떻게 전달하나?**

- Decision: 비밀번호: Vault `kv/kafka/users/<env>/<pod>`를 단일 소스로 두고, kafka ns에는 ESO ExternalSecret → Secret(KafkaUser secretKeyRef용), 앱 ns에는 같은 Vault 키를 읽는 ExternalSecret. CA: `<cluster>-cluster-ca-cert` Secret의 `ca.crt`(PEM)를 ESO kubernetes provider(ClusterSecretStore, remoteNamespace kafka)로 앱 ns에 미러링.
- Rationale: gitops repo에 ExternalSecret만 두는 설계와 일치. Strimzi CA Secret은 kafka ns에만 생성되고 갱신 시 내용이 바뀌므로 ESO refresh로 자동 추종. Python 클라이언트는 PEM(`ca.crt`)만 필요(p12 불필요).
- Alternatives considered: 자체 CA를 Vault PKI에서 발급해 Strimzi `clusterCa.generateCertificateAuthority: false`로 주입(갱신 수동); CA를 Vault에 복사하는 CronJob.
- Source: <https://github.com/strimzi/strimzi-kafka-operator/blob/main/documentation/modules/security/proc-configuring-internal-clients-to-trust-cluster-ca.adoc>

**STRIMZI-D8. Python 클라이언트는 confluent-kafka vs aiokafka?**

- Decision: Django/Celery outbox 릴레이·동기 소비자는 confluent-kafka 2.15.0(`enable.idempotence=true`). asyncio 소비자가 꼭 필요할 때만 aiokafka 0.14.0.
- Rationale: confluent-kafka는 cp313 manylinux_2_28_aarch64 wheel을 제공하고 librdkafka의 idempotent producer·재시도·SCRAM/TLS가 검증됨. aiokafka는 Kafka 4.x에서 '동작한다'(메인테이너, 2026-03)는 답변이나 KIP-896 대응 프로토콜 현대화 PR(#1136/#1139)이 진행 중이고 issue #1085 미종결; 0.13.0에서 `api_version` 제거 후 0.14.0에서 deprecated로 복귀하는 등 API가 흔들림.
- Alternatives considered: aiokafka 단독(순수 asyncio, Kafka 4.x 프로토콜 리스크); kafka-python(유지보수 불안정).
- Source: <https://github.com/aio-libs/aiokafka/issues/1085>

**STRIMZI-D9. 메트릭 수집은?**

- Decision: `spec.kafka.metricsConfig.type: strimziMetricsReporter`(1.2.0 번들 0.4.0)로 Prometheus 엔드포인트 노출 → Alloy가 pod 스크레이프. jmxPrometheusExporter ConfigMap은 쓰지 않음.
- Rationale: Strimzi 문서: 매핑 규칙 없는 경량 리포터, `allowList` 변경은 롤링 없이 동적 반영, broker/controller 지원. JMX exporter는 규칙 ConfigMap·추가 지연.
- Alternatives considered: jmxPrometheusExporter(examples/metrics/kafka-metrics.yaml, 더 많은 대시보드 호환); 메트릭 없이 시작.
- Source: <https://strimzi.io/docs/operators/latest/configuring.html>

**STRIMZI-D10. 업그레이드 정책과 Renovate 처리?**

- Decision: Renovate가 Helm OCI chart(1.x)와 Kafka CR `spec.kafka.version`을 별도 PR로 추적. 순서 고정: (1) chart bump(오퍼레이터+CRD, ServerSideApply) → (2) `spec.kafka.version` bump → (3) `metadataVersion` bump. Strimzi 릴리스 2개 이상 뒤처지지 않도록 월 1회 점검.
- Rationale: Strimzi는 최신 릴리스만 지원(이전 minor는 치명 CVE만 패치), 약 2개월 주기(1.0.0 04-28 → 1.0.1 06-17 → 1.1.0 06-27 → 1.2.0 08-20). 각 릴리스는 최근 Kafka minor 2개만 지원(1.1.0에서 4.1.x 제거) → 오퍼레이터가 모르는 Kafka 버전은 기동 불가. 문서상 multi-version(minor 건너뛰기) 업그레이드는 허용.
- Alternatives considered: 수동 분기별 업그레이드; Kafka 버전을 chart와 같은 PR로 묶기(오퍼레이터 선행 원칙 위반 위험).
- Source: <https://github.com/orgs/strimzi/discussions/7575>

**STRIMZI-D11. KafkaTopic finalizer는 유지하나?**

- Decision: 기본값(`STRIMZI_USE_FINALIZERS=true`, finalizer `strimzi.io/topic-operator`) 유지. 런북에 TO 정지 시 `kubectl get kt -o=json | jq '.items[].metadata.finalizers = null' | kubectl apply -f -` 제거 절차 기록.
- Rationale: GitOps에서 KafkaTopic 삭제 = Kafka 토픽 삭제를 보장하려면 finalizer가 필요. 끄면 CR 삭제 시 토픽이 남는다.
- Alternatives considered: `STRIMZI_USE_FINALIZERS=false`(ns 삭제가 막히지 않지만 토픽 잔존).
- Source: <https://github.com/strimzi/strimzi-kafka-operator/blob/main/documentation/modules/operators/con-removing-topic-finalizers.adoc>

### 설정 스니펫

**Argo CD Application — Strimzi Helm OCI 1.2.0** — <https://argo-cd.readthedocs.io/en/stable/user-guide/helm/>
```
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: strimzi-operator
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "-5"
spec:
  project: platform
  source:
    repoURL: quay.io/strimzi-helm        # OCI: oci:// 접두사 생략
    chart: strimzi-kafka-operator
    targetRevision: 1.2.0
    helm:
      releaseName: strimzi
      valuesObject:
        replicas: 1
        watchNamespaces: []              # 설치 ns(kafka)만 감시
        watchAnyNamespace: false
        resources:
          requests: { cpu: 100m, memory: 384Mi }
          limits:   { cpu: 1000m, memory: 384Mi }
        generateNetworkPolicy: true
        extraEnvs: []   # 필요 시 {name: STRIMZI_POD_SECURITY_PROVIDER_CLASS, value: restricted}
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka
  syncPolicy:
    automated: { prune: true, selfHeal: true }
    syncOptions: [CreateNamespace=true, ServerSideApply=true]   # CRD 262144B 초과 대응
```

**KafkaNodePool + Kafka — KRaft combined 1노드 (local-path, SCRAM/TLS, simple ACL)** — <https://github.com/strimzi/strimzi-kafka-operator/blob/main/examples/kafka/kafka-single-node.yaml>
```
apiVersion: kafka.strimzi.io/v1
kind: KafkaNodePool
metadata:
  name: combined
  namespace: kafka
  labels:
    strimzi.io/cluster: platform
spec:
  replicas: 1
  roles: [controller, broker]
  storage:
    type: jbod
    volumes:
      - id: 0
        type: persistent-claim
        class: local-path
        size: 20Gi              # local-path는 용량 미강제(명목값)
        deleteClaim: false
        kraftMetadata: shared
  resources:
    requests: { cpu: 250m, memory: 1536Mi }
    limits:   { cpu: "1",  memory: 2Gi }
  jvmOptions:
    -Xms: 1g
    -Xmx: 1g
  template:
    pod:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - { key: role, operator: In, values: [platform] }
---
apiVersion: kafka.strimzi.io/v1
kind: Kafka
metadata:
  name: platform
  namespace: kafka
spec:
  kafka:
    version: 4.3.1
    metadataVersion: 4.3-IV0
    listeners:
      - name: tls               # 소문자/숫자, 11자 이하
        port: 9093
        type: internal
        tls: true
        authentication:
          type: scram-sha-512
    authorization:
      type: simple
      superUsers:
        - ops-admin             # KafkaUser 이름(SCRAM은 CN= 없이)
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
      auto.create.topics.enable: false
      log.retention.hours: 168
    metricsConfig:
      type: strimziMetricsReporter
      values:
        allowList: ["kafka_server.*", "kafka_log.*", "kafka_controller.*"]  # 스키마 확인 필요(open)
  entityOperator:
    topicOperator:
      resources:
        requests: { cpu: 50m, memory: 256Mi }
        limits:   { memory: 384Mi }
      jvmOptions: { -Xms: 128m, -Xmx: 256m }
    userOperator:
      resources:
        requests: { cpu: 50m, memory: 256Mi }
        limits:   { memory: 384Mi }
      jvmOptions: { -Xms: 128m, -Xmx: 256m }
    template:
      pod:
        affinity:
          nodeAffinity:
            requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                    - { key: role, operator: In, values: [platform] }
```

**KafkaUser — pod별 SCRAM 사용자(비밀번호 외부 Secret) + ACL** — <https://github.com/strimzi/strimzi-kafka-operator/blob/main/documentation/modules/security/con-securing-client-authentication.adoc>
```
apiVersion: kafka.strimzi.io/v1
kind: KafkaUser
metadata:
  name: prod-blog                     # <env>-<pod>
  namespace: kafka
  labels:
    strimzi.io/cluster: platform
spec:
  authentication:
    type: scram-sha-512
    password:
      valueFrom:
        secretKeyRef:
          name: kafka-user-prod-blog  # ESO가 Vault kv/kafka/users/prod/blog 에서 생성
          key: password
  authorization:
    type: simple
    acls:
      - resource: { type: topic, name: prod.blog., patternType: prefix }   # 자기 토픽 생산
        operations: [Write, Describe]
      - resource: { type: topic, name: prod.auth.user-registered, patternType: literal }  # 구독
        operations: [Read, Describe]
      - resource: { type: group, name: prod-blog-, patternType: prefix }   # 컨슈머 그룹
        operations: [Read]
# host 생략 시 "*". 생성 Secret(kafka ns, 이름=KafkaUser명): password, sasl.jaas.config
```

**KafkaTopic — partitions 3, RF 1, 7일 보존** — <https://github.com/strimzi/strimzi-kafka-operator/blob/main/examples/topic/kafka-topic.yaml>
```
apiVersion: kafka.strimzi.io/v1
kind: KafkaTopic
metadata:
  name: prod.blog.post-published      # K8s 이름 불가 문자면 spec.topicName 사용
  namespace: kafka
  labels:
    strimzi.io/cluster: platform
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 604800000           # 7d
    min.insync.replicas: 1
```

**ESO 배선 — 비밀번호(Vault) + 클러스터 CA(kubernetes provider) (ESO 스키마는 R-ESO 주제에서 재확인)** — <https://github.com/strimzi/strimzi-kafka-operator/blob/main/documentation/modules/security/proc-configuring-internal-clients-to-trust-cluster-ca.adoc>
```
# kafka ns: Vault -> Secret (KafkaUser secretKeyRef 대상)
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: kafka-user-prod-blog, namespace: kafka }
spec:
  refreshInterval: 1h
  secretStoreRef: { kind: ClusterSecretStore, name: vault }
  target: { name: kafka-user-prod-blog }
  data:
    - secretKey: password
      remoteRef: { key: kafka/users/prod/blog, property: password }
---
# 앱 ns(prod): 같은 Vault 키 -> 환경변수용 Secret
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: kafka-client, namespace: prod }
spec:
  secretStoreRef: { kind: ClusterSecretStore, name: vault }
  target: { name: kafka-client }
  data:
    - secretKey: KAFKA_SASL_PASSWORD
      remoteRef: { key: kafka/users/prod/blog, property: password }
---
# 클러스터 CA 미러: kafka/platform-cluster-ca-cert:ca.crt -> prod/kafka-ca:ca.crt
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata: { name: kafka-ca }
spec:
  provider:
    kubernetes:
      remoteNamespace: kafka
      server:
        caProvider: { type: ConfigMap, name: kube-root-ca.crt, key: ca.crt, namespace: kafka }
      auth:
        serviceAccount: { name: eso-kafka-ca-reader, namespace: kafka }  # secrets get/list RBAC
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: kafka-ca, namespace: prod }
spec:
  secretStoreRef: { kind: ClusterSecretStore, name: kafka-ca }
  target: { name: kafka-ca }
  data:
    - secretKey: ca.crt
      remoteRef: { key: platform-cluster-ca-cert, property: ca.crt }
```

**confluent-kafka 2.15.0 — SCRAM-SHA-512 + TLS idempotent producer (outbox 릴레이)** — <https://github.com/confluentinc/librdkafka/blob/master/CONFIGURATION.md>
```
import os
from confluent_kafka import Producer

conf = {
    "bootstrap.servers": "platform-kafka-bootstrap.kafka.svc:9093",  # SAN 포함 이름
    "security.protocol": "SASL_SSL",
    "sasl.mechanisms": "SCRAM-SHA-512",
    "sasl.username": "prod-blog",
    "sasl.password": os.environ["KAFKA_SASL_PASSWORD"],
    "ssl.ca.location": "/etc/kafka/ca.crt",   # Secret kafka-ca:ca.crt 마운트(PEM)
    "enable.idempotence": True,               # acks=all 자동 강제
    "client.id": "prod-blog-outbox-relay",
}
producer = Producer(conf)
producer.produce("prod.blog.post-published", key=str(event_id).encode(), value=payload,
                 on_delivery=lambda err, msg: err and log.error("delivery failed", err=err))
producer.flush(10)
# Dockerfile: python:3.13-slim-bookworm(arm64) + uv pip install confluent-kafka==2.15.0 → manylinux_2_28_aarch64 wheel
```

**aiokafka 0.14.0 — SCRAM-SHA-512 + TLS consumer** — <https://aiokafka.readthedocs.io/en/stable/api.html>
```
import os
from aiokafka import AIOKafkaConsumer
from aiokafka.helpers import create_ssl_context

consumer = AIOKafkaConsumer(
    "prod.auth.user-registered",
    bootstrap_servers="platform-kafka-bootstrap.kafka.svc:9093",
    group_id="prod-blog-user-sync",            # ACL group prefix prod-blog-
    security_protocol="SASL_SSL",
    sasl_mechanism="SCRAM-SHA-512",
    sasl_plain_username="prod-blog",
    sasl_plain_password=os.environ["KAFKA_SASL_PASSWORD"],
    ssl_context=create_ssl_context(cafile="/etc/kafka/ca.crt"),
    enable_auto_commit=False,
)   # api_version 인자는 지정하지 말 것(0.13.0 제거, 0.14.0 deprecated 복귀)
await consumer.start()
```

### 함정

- Strimzi CRD(특히 kafkas.kafka.strimzi.io)는 client-side apply 시 `metadata.annotations: Too long: must have at most 262144 bytes`로 실패 → Argo CD `ServerSideApply=true` 필수(설계에 이미 포함). Helm chart `crds/`를 Argo가 렌더링하므로 chart bump 시 CRD도 함께 SSA로 갱신되지만, `helm upgrade` 직접 실행 경로에서는 CRD가 갱신되지 않는다.
- 1.0.0부터 `kafka.strimzi.io/v1`만 서빙 — v1beta2 매니페스트는 거부된다. 블로그·예제의 v1beta2 YAML을 복사하지 말 것. `strimzi.io/kraft`·`strimzi.io/node-pools` 어노테이션은 0.48.0부터 무시(붙여도 무해).
- 1.0.1부터 Entity Operator cross-namespace 감시가 기본 비활성(`STRIMZI_ENTITY_OPERATOR_WATCHED_NAMESPACE_ENABLED=false`) → KafkaTopic/KafkaUser와 그 생성 Secret(비밀번호·CA)은 kafka ns에만 존재. 앱 ns로는 Vault+ESO 간접 전달이 필요하고, ESO kubernetes provider용 SA에 kafka ns Secret get/list RBAC를 줘야 한다.
- K3s local-path: PVC 용량 미강제·확장 불가, PV가 첫 스케줄 노드에 영구 고정, reclaimPolicy Delete, 기본 경로 /var/lib/rancher/k3s/storage(부트 볼륨). Kafka 로그가 루트 디스크를 채우지 않도록 `retention.ms`/`retention.bytes`와 노드 디스크 알람 필수; 가능하면 `--default-local-storage-path`로 별도 블록 볼륨 경로 지정.
- 단일 broker에서 `offsets.topic.replication.factor` 등 RF 관련 5개 키를 1로 명시하지 않으면 내부 토픽 생성이 실패한다. KafkaTopic `replicas`는 broker 수(1)를 넘을 수 없다. Apache Kafka 문서는 combined(controller+broker) 모드를 production 비권장으로 명시 — 단일 노드 한계로 수용.
- Kafka 힙: `-Xmx` 미지정 시 memory limit의 50%(최대 5 GB)가 자동 적용. broker는 페이지 캐시 때문에 요청 메모리를 힙보다 크게 잡아야 한다. Kafka 2Gi + TO/UO 각 384Mi + Cluster Operator 384Mi ≈ 3 GiB가 노드 A(13 GB)에서 Vault·Authentik·Argo CD·OpenFGA 등과 공존해야 한다.
- confluent-kafka wheel은 manylinux_2_28(glibc ≥ 2.28)만 제공, musllinux 없음 → Alpine 이미지에서는 librdkafka 소스 빌드로 떨어진다. Debian 기반 `python:3.13-slim` 사용. 사전 빌드 wheel에는 GSSAPI(Kerberos)가 없으나 SCRAM/TLS는 포함.
- aiokafka와 Kafka 4.x(KIP-896으로 2.1 이전 프로토콜 제거): 현재 버전이 '동작한다'는 메인테이너 답변(2026-03)뿐이며 프로토콜 현대화 PR 진행 중·issue #1085 미종결. `api_version` 인자는 0.13.0에서 제거됐다가 0.14.0에서 deprecated로 복귀 — 설정하지 말 것.
- 지원 정책: Strimzi는 최신 릴리스만 지원(이전 minor는 치명 CVE만), 약 2개월 주기. 각 릴리스가 지원하는 Kafka는 최근 2개 minor 정도(1.1.0에서 4.1.x 삭제, 1.2.0은 4.2.0–4.3.1). 오퍼레이터가 모르는 Kafka `version`은 `STRIMZI_KAFKA_IMAGES`에 없어 기동 실패 → 항상 오퍼레이터 먼저, Kafka `version` 다음, `metadataVersion` 마지막(KRaft metadataVersion 다운그레이드 불가).
- 리스너 이름은 소문자/숫자 11자 이하. `spec.kafka.config`에서 `listeners.`, `advertised.`, `sasl.`, `ssl.`, `security.`, `authorizer.`, `process.roles`, `log.dir`, `node.id` 등 접두사는 금지(오퍼레이터가 관리).
- KafkaTopic finalizer `strimzi.io/topic-operator`(`STRIMZI_USE_FINALIZERS` 기본 true): Topic Operator가 죽은 상태에서 kafka ns나 KafkaTopic을 삭제하면 Terminating에 걸린다. 런북에 finalizer 제거 명령 기록.
- superUsers는 SCRAM 사용자면 KafkaUser 이름 그대로(`CN=`은 mTLS용). broker 인증서 SAN은 `<cluster>-kafka-bootstrap[.<ns>[.svc[.cluster.local]]]`, `<cluster>-kafka-brokers…`, `<pod>.<cluster>-kafka-brokers.<ns>.svc…`만 포함 → IP나 다른 이름으로 접속하면 hostname 검증 실패.
- 1.2.0: 오퍼레이터 pod는 Restricted PSS securityContext가 기본이지만 Kafka pod는 여전히 Baseline provider(`STRIMZI_POD_SECURITY_PROVIDER_CLASS` 기본 Baseline). restricted로 바꾸면 local-path hostPath 볼륨 권한과 충돌 가능 — 테스트 후 적용. 1.2.0은 SA 토큰 자동 마운트도 중단(볼륨 마운트로 대체).
- auto.create.topics.enable 기본 true → false로 꺼서 KafkaTopic CR을 단일 진실로 유지. 오타 토픽 자동 생성·ACL 우회 방지. Kafka ≥ 2.8(KIP-679)에서는 토픽 Write ACL만으로 idempotent producer 가능하므로 별도 cluster IdempotentWrite ACL은 불필요.
- arm64: Strimzi 이미지는 0.27.0부터 amd64/arm64 multi-arch(quay.io/strimzi/kafka:1.2.0-kafka-4.3.1) — VM.Standard.A1.Flex에서 추가 설정 없음. Strimzi 1.2.0 테스트 K8s 범위 1.30–1.36에 K3s v1.36 포함.

### 미확인

- strimziMetricsReporter의 `values.allowList` 정확한 스키마(문자열 목록 vs 콤마 문자열)와 노출 포트/컨테이너 포트 이름(Alloy 스크레이프 대상) — CRD/문서에서 미확인.
- Topic/User Operator 최소 메모리(256Mi/384Mi, -Xmx 256m)는 문서 근거 없는 가정 — 기동 후 실측 필요. Entity Operator에 `STRIMZI_USE_FINALIZERS`를 넣는 정확한 경로(`spec.entityOperator.template.topicOperatorContainer.env`)도 문서 원문으로 재확인 못 함.
- `STRIMZI_POD_SECURITY_PROVIDER_CLASS=restricted` + K3s local-path 조합의 볼륨 쓰기 권한(fsGroup) 동작 미검증.
- Strimzi 1.3.0 출시 시점과 Kafka 4.4 지원 여부(마일스톤 14 open/28 closed, due date 없음).
- Strimzi 클러스터 CA 기본 유효기간/갱신 기간과 ESO refreshInterval 정합(갱신 직후 앱 재기동 필요 여부) 미확인.
- aiokafka의 Kafka 4.x 프로토콜 현대화(PR #1136/#1139) 병합 상태 — 0.14.0 이후 릴리스에서 재확인.
- OCI A1 부트 볼륨 IOPS/처리량으로 Kafka fsync 부하가 감당되는지, 별도 Block Volume(`--default-local-storage-path`) 필요 여부.
- ESO `external-secrets.io/v1` ClusterSecretStore kubernetes provider 스니펫은 이 조사에서 검증하지 않음(ESO 담당 주제에서 확정).
- Strimzi 1.2.0 Kafka 이미지의 JVM 런타임 버전(0.50.0부터 Java 21 — Java 25 전환 여부 미확인).


## R7 Authentik · OpenFGA

R7 — Authentik 2026.8 + OpenFGA 설치·설정 (K3s arm64, CNPG 외부 PG, Traefik forward-auth, 블루프린트 GitOps)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| authentik server (ghcr.io/goauthentik/server, linux/amd64+arm64) | 2026.8.0 | 2026-08-18 | <https://github.com/goauthentik/authentik/releases/tag/version%2F2026.8.0> |
| authentik Helm chart (charts.goauthentik.io, chart==appVersion; 의존성: bitnami postgresql 18.8.13[postgresql.enabled], authentik-remote-cluster 2.1.0[serviceAccount.create]; Redis 의존성 없음) | authentik-2026.8.0 | 2026-08-18 | <https://github.com/goauthentik/helm/blob/main/charts/authentik/Chart.yaml> |
| authentik 지원 PostgreSQL | 14–18 (PG 18 지원) |  | <https://docs.goauthentik.io/install-config/configuration/> |
| OpenFGA server (docker openfga/openfga, linux/amd64+arm64) | v1.19.0 | 2026-08-25 | <https://github.com/openfga/openfga/releases/tag/v1.19.0> |
| OpenFGA Helm chart (openfga/openfga, appVersion v1.19.0) | 0.3.13 | 2026-08-26 | <https://github.com/openfga/helm-charts/releases> |
| OpenFGA CLI fga (linux_arm64 deb/rpm/tar.gz + docker openfga/cli arm64) | v0.7.20 | 2026-08-10 | <https://github.com/openfga/cli/releases/tag/v0.7.20> |
| OpenFGA 지원 datastore | PostgreSQL 14+, MySQL 8, SQLite(beta) — PG 18 명시 없음 |  | <https://github.com/openfga/openfga/blob/main/README.md> |

### 결정

**AUTHENTIK-D1. Authentik 배포 형태와 캐시(Redis/Dragonfly) 필요 여부**

- Decision: Helm chart authentik/authentik 2026.8.0을 Argo CD로 배포. postgresql.enabled=false(CNPG 외부 PG), server/worker replicas=1. Redis·Dragonfly는 붙이지 않는다.
- Rationale: 2025.8에서 태스크, 2025.10에서 캐시·embedded outpost·WebSocket까지 PostgreSQL로 이전되어 authentik은 Redis를 전혀 쓰지 않으며 Redis 설정은 제거됨. 2026.8 차트 values/Chart.yaml에도 redis 키·의존성이 없다. 캐시 튜닝은 AUTHENTIK_CACHE__TIMEOUT(300s)만 남음.
- Alternatives considered: docker-compose 단독 VM 설치(K3s 밖) — GitOps·ESO 통합 불리. 번들 bitnami PG 사용 — 문서상 데모/테스트 전용.
- Source: <https://goauthentik.io/blog/2025-11-13-we-removed-redis/>

**AUTHENTIK-D2. CNPG 연결 방식(TLS, 풀러)**

- Decision: CNPG 클러스터에 database `authentik`/owner role 생성, `AUTHENTIK_POSTGRESQL__SSLMODE=verify-full` + `SSLROOTCERT`에 CNPG `<cluster>-ca` Secret(ca.crt) 마운트. 비밀번호는 ESO Secret을 `global.env[].valueFrom`으로 주입. CNPG Pooler(트랜잭션 모드)는 쓰지 않으므로 `AUTHENTIK_POSTGRESQL__DIRECT__*`는 미설정.
- Rationale: 문서는 SSLMODE 기본을 verify-ca로 명시하고 verify-*에는 SSLROOTCERT가 필수라고 함(코드 default.yml은 disable — 상충하므로 명시). 2026.8의 DIRECT 설정은 트랜잭션 풀러 사용 시 LISTEN/NOTIFY·advisory lock용 별도 엔드포인트인데 instances=1 단일 PG에는 불필요. 차트의 env는 toYaml 통과라 valueFrom secretKeyRef가 그대로 동작하고 빈 값 항목은 생성 Secret에서 제외됨.
- Alternatives considered: sslmode=require(서버 인증서 미검증), CNPG Pooler + DIRECT 설정(연결 수가 많아질 때).
- Source: <https://docs.goauthentik.io/install-config/configuration/>

**AUTHENTIK-D3. 블루프린트를 선언적으로 적용하는 방법**

- Decision: platform-gitops에 도메인별 ConfigMap(ak-bp-core, ak-bp-providers, ak-bp-events)을 두고 차트 `blueprints.configMaps`로 마운트. 비밀값은 `!Env`로 ESO 주입 env에서 읽고, 의존 객체는 한 파일 안에서 `!KeyOf`/`!Find`로 참조.
- Rationale: 워커 Deployment가 `/blueprints/mounted/cm-<name>`에 ConfigMap을 마운트하고 `.yaml`로 끝나는 키만 발견·적용. `/blueprints` 아래 추가 yaml은 라벨(`blueprints.goauthentik.io/instantiate`, 기본 "true")에 따라 자동 인스턴스화되며 파일 변경 시 즉시, 이후 60분마다 재적용된다. 발견 순서는 보장되지 않으므로 파일 간 의존은 피한다.
- Alternatives considered: OCI 레지스트리 블루프린트(oci://ghcr.io/...:ref) — 별도 빌드 파이프라인 필요. Terraform authentik provider — OpenTofu 상태에 IdP 객체가 섞임.
- Source: <https://github.com/goauthentik/helm/blob/main/charts/authentik/templates/worker/deployment.yaml>

**AUTHENTIK-D4. OAuth2 Provider 기본값(토큰 수명·서명키·sub·JWKS·커스텀 클레임)**

- Decision: pod별 OAuth2 provider(confidential): signing_key=공용 RSA CertificateKeyPair(비대칭 서명), access_token_validity=minutes=15, refresh_token_validity=days=30(기본), sub_mode=user_uuid, issuer_mode=per_provider. tenant_id는 ScopeMapping(scope `tenant`)으로 user.attributes에서 반환. JWKS는 `/application/o/<slug>/jwks/`, 디스커버리는 `/application/o/<slug>/.well-known/openid-configuration`.
- Rationale: 모델 기본값은 access_code minutes=1, access_token hours=1, refresh days=30, sub_mode hashed_user_id(문서에는 기본값 표기 없음, models.py 확인). signing_key 미선택 시 client_secret 대칭 서명이라 pod 간 JWKS 검증이 불가. ScopeMapping 반환 dict는 access/ID 토큰 커스텀 클레임으로 병합됨.
- Alternatives considered: sub_mode=user_email(이메일 변경 시 sub 변동), provider별 개별 서명키(키 회전 단위 세분화).
- Source: <https://docs.goauthentik.io/add-secure-apps/providers/oauth2/>

**AUTHENTIK-D5. RFC 8693 token exchange 토폴로지(BFF→pod API)**

- Decision: web-bff provider(A)가 사용자 토큰 발급; 각 pod API provider(B)는 Grant Types에 `Token exchange` 추가 + Federated OAuth2/OpenID Providers에 A 등록. BFF는 B의 client 자격으로 A 토큰을 subject_token으로 교환. 다른 provider를 대상으로 할 땐 `audience=<대상 client_id>`(대상 provider도 교환 수행 provider를 federated로 등록). OBO는 actor_token(Actor 계정 토큰)으로 `act` 클레임 발급.
- Rationale: 2026.8에서 정식 지원; 기본 비활성. 문서: subject 토큰 발급 provider(또는 OIDC source)를 Federated에 등록해야 검증되고, audience 대상은 application에 바인딩되어 있어야 하며 사용자가 대상 앱 정책을 통과해야 한다. grant_types 문자열은 `urn:ietf:params:oauth:grant-type:token-exchange`, subject_token_type은 `urn:ietf:params:oauth:token-type:access_token`/`jwt`.
- Alternatives considered: A 토큰을 모든 pod가 공용 검증(aud 격리 없음), pod별 client_credentials 서비스 계정 + 사용자 컨텍스트 헤더 전달(감사 추적 약함).
- Source: <https://docs.goauthentik.io/add-secure-apps/providers/oauth2/token_exchange/>

**AUTHENTIK-D6. 소셜(GitHub/Google) + 이메일/비밀번호 + MFA 흐름**

- Decision: OAuthSource(slug github/google, provider_type github/google, user_matching_mode=email_link)를 default-authentication-flow의 Identification 스테이지 Sources에 노출. 인증 흐름 = identification(email,username) → password → authenticator_validate(device_classes totp,webauthn; not_configured_action=configure; configuration_stages=기본 TOTP/WebAuthn 셋업) → user_login. 가입은 example `flows-enrollment-email-verification.yaml` 기반.
- Rationale: 콜백 URL은 `https://<authentik>/source/oauth/callback/<slug>/`로 slug 일치 필수. 기본 인증 플로우 블루프린트가 이미 order 10/20/30/100 구조라 MFA 스테이지 attrs만 덮어쓰면 됨. 사용자 셀프서비스는 Settings의 Sessions 탭(원격 세션 삭제 포함)·Credentials(MFA 기기·토큰) 탭이 존재.
- Alternatives considered: 이메일 매직링크(passwordless) 플로우, Google Workspace 전용 도메인 제한 정책.
- Source: <https://docs.goauthentik.io/users-sources/user/user-interface/>

**AUTHENTIK-D7. login/logout 이벤트를 pod로 보내는 방법**

- Decision: NotificationTransport(mode=webhook, send_once=true, in-cluster URL, header 매핑으로 Bearer) + NotificationRule(severity notice, destination_group=webhook-sink) + EventMatcherPolicy(action=login / logout / login_failed) 바인딩. body 매핑으로 event.action/user/client_ip/created/context를 보냄. pod는 수신을 outbox에 기록해 Kafka로 릴레이.
- Rationale: 이벤트 액션에 `login`, `login_failed`, `logout`이 존재. 알림은 destination_group 또는 destination_event_user가 있어야 생성됨. 기본 페이로드는 body/severity/user_email/user_username/event_user_*뿐이라 매핑 필수. 매핑 컨텍스트는 user/request/notification이며 notification.event로 Event 모델(action, user JSON, app, context, client_ip, created)에 접근.
- Alternatives considered: Events API 폴링(워커 부하·지연), Slack 모드 웹훅(포맷 고정).
- Source: <https://docs.goauthentik.io/sys-mgmt/events/transports/>

**AUTHENTIK-D8. Django admin·Argo CD·Vault 앞 SSO**

- Decision: Django admin: embedded outpost + Proxy Provider(forward_single, external_host=https://admin.joshuatech.dev) + Traefik forwardAuth Middleware(주소는 in-cluster Service `authentik-server`). Argo CD: Dex OIDC 커넥터(공식 통합), Vault: OIDC auth method(공식 통합). Argo/Vault에는 forward-auth를 걸지 않는다.
- Rationale: embedded outpost는 server pod 안에서 9000 포트로 `/outpost.goauthentik.io` 경로를 처리하며 기본 활성(outposts.disable_embedded_outpost=false). 공식 Argo CD/Vault 통합은 OIDC이며 argocd CLI(gRPC)·vault CLI 로그인은 forward-auth 쿠키를 다룰 수 없다. 관리 도메인은 이미 Cloudflare Access(GitHub IdP)가 앞단에 있어 forward-auth 이중화는 UX만 나빠짐.
- Alternatives considered: 도메인 레벨 forward-auth(cookie_domain=joshuatech.dev)로 셋 다 감싸고 skip_path_regex로 API 경로 제외 — 앱별 권한 분리 불가.
- Source: <https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_traefik>

**AUTHENTIK-D9. OpenFGA 배포·datastore·인증**

- Decision: Helm chart openfga/openfga 0.3.13, replicaCount=1, datastore.engine=postgres, existingSecret(uri)로 CNPG `openfga` DB 연결, applyMigrations=true(migrationType job), authn.method=preshared(keysSecret, 키 이름 `keys`), playground 비활성, checkQueryCache 활성, log json.
- Rationale: 차트 기본값이 replicaCount 3·engine memory·playground true·pullPolicy Always라 반드시 덮어써야 함. 프로덕션 가이드: 인증 설정, playground 비활성, JSON 로그, `openfga migrate`로 인덱스 보장, MIN/MAX_OPEN_CONNS 튜닝, 캐시·메트릭 활성. 이미지·CLI 모두 arm64 제공.
- Alternatives considered: authn oidc(issuer=authentik) — pod마다 client_credentials 필요, 단순성 낮음. SQLite datastore(beta) — 단일 노드지만 백업 경로가 CNPG 밖으로 벗어남.
- Source: <https://github.com/openfga/helm-charts/blob/main/charts/openfga/values.yaml>

**AUTHENTIK-D10. 모델(.fga) 적용과 env별 store**

- Decision: 레포에 `authz/model.fga` + `model.fga.yaml` 테스트. CI: `fga model validate`/`fga model test`. CD: env별 store(joshuatech-dev, joshuatech-prod)를 최초 1회 `fga store create --name … --model`로 만들고 store id를 ESO/ConfigMap에 기록, 이후 `fga model write --store-id --file`로 새 모델 버전 발행(앱은 최신 모델 사용).
- Rationale: OpenFGA에는 환경 개념이 없고 store가 격리 단위. CLI는 FGA_API_URL/FGA_STORE_ID/FGA_API_TOKEN env 또는 .fga.yaml로 설정. `fga store import --file *.fga.yaml`은 모델+시드 튜플을 한 번에 넣는다.
- Alternatives considered: env마다 OpenFGA 인스턴스 분리(리소스 2배), 단일 store에 env 타입 추가(실수 시 교차 오염).
- Source: <https://github.com/openfga/cli/blob/main/README.md>

### 설정 스니펫

**authentik values.yaml (chart 2026.8.0, CNPG 외부 PG, Redis 없음, blueprints ConfigMap)** — <https://github.com/goauthentik/helm/blob/main/charts/authentik/values.yaml>
```
global:
  env:
    - name: AUTHENTIK_SECRET_KEY
      valueFrom: { secretKeyRef: { name: authentik-env, key: secret_key } }
    - name: AUTHENTIK_POSTGRESQL__PASSWORD
      valueFrom: { secretKeyRef: { name: authentik-db-app, key: password } }   # CNPG <cluster>-app 또는 ESO
    - { name: AUTHENTIK_POSTGRESQL__SSLMODE, value: verify-full }
    - { name: AUTHENTIK_POSTGRESQL__SSLROOTCERT, value: /etc/cnpg-ca/ca.crt }
    - { name: AUTHENTIK_WEB__BASE_URL, value: https://auth.joshuatech.dev }
    - name: GITHUB_CLIENT_SECRET            # 블루프린트 !Env 용
      valueFrom: { secretKeyRef: { name: authentik-env, key: github_client_secret } }
  volumes:
    - name: cnpg-ca
      secret: { secretName: pg-main-ca }   # CNPG 클러스터 CA(ca.crt)
  volumeMounts:
    - { name: cnpg-ca, mountPath: /etc/cnpg-ca, readOnly: true }
authentik:
  postgresql: { host: pg-main-rw.data.svc.cluster.local, port: 5432, name: authentik, user: authentik }
  log_level: info
  error_reporting: { enabled: false }
postgresql: { enabled: false }          # 번들 bitnami PG 비활성(데모 전용)
server:
  replicas: 1
  resources: { requests: { cpu: 100m, memory: 512Mi }, limits: { memory: 1Gi } }
  ingress: { enabled: true, ingressClassName: traefik, hosts: [auth.joshuatech.dev] }
worker:
  replicas: 1
  resources: { requests: { cpu: 100m, memory: 512Mi }, limits: { memory: 1Gi } }
blueprints:
  configMaps: [ak-bp-core, ak-bp-providers, ak-bp-events]   # → /blueprints/mounted/cm-<name>/*.yaml
```

**blueprint: OAuth2 provider ×2 + tenant 스코프 매핑 + token exchange/federated** — <https://docs.goauthentik.io/customize/blueprints/v1/structure>
```
version: 1
metadata: { name: joshuatech-providers }
entries:
  - model: authentik_providers_oauth2.scopemapping
    id: scope-tenant
    identifiers: { managed: joshuatech.dev/scope-tenant }
    attrs:
      name: "joshuatech: tenant"
      scope_name: tenant
      description: "Tenant membership"
      expression: |
        return {"tenant_id": request.user.attributes.get("tenant_id"),
                "roles": [g.name for g in request.user.ak_groups.all()]}
  - model: authentik_providers_oauth2.oauth2provider
    id: prov-web-bff
    identifiers: { name: web-bff }
    attrs:
      client_type: confidential
      client_id: !Env WEB_BFF_CLIENT_ID
      client_secret: !Env WEB_BFF_CLIENT_SECRET
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
      signing_key: !Find [authentik_crypto.certificatekeypair, [name, joshuatech-jwt-signing]]
      redirect_uris: [{ matching_mode: strict, url: "https://joshuatech.dev/api/auth/callback" }]
      access_token_validity: minutes=15
      refresh_token_validity: days=30
      sub_mode: user_uuid
      issuer_mode: per_provider
      grant_types: [authorization_code, refresh_token]
      property_mappings:
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-email]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-profile]]
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-offline_access]]
        - !KeyOf scope-tenant
  - model: authentik_providers_oauth2.oauth2provider
    id: prov-identity-api
    identifiers: { name: identity-api }
    attrs:
      client_type: confidential
      client_id: !Env IDENTITY_API_CLIENT_ID
      client_secret: !Env IDENTITY_API_CLIENT_SECRET
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
      signing_key: !Find [authentik_crypto.certificatekeypair, [name, joshuatech-jwt-signing]]
      access_token_validity: minutes=15
      sub_mode: user_uuid
      grant_types: [client_credentials, "urn:ietf:params:oauth:grant-type:token-exchange"]
      jwt_federation_providers: [!KeyOf prov-web-bff]     # web-bff 토큰을 subject_token으로 수락
      property_mappings:
        - !Find [authentik_providers_oauth2.scopemapping, [managed, goauthentik.io/providers/oauth2/scope-openid]]
        - !KeyOf scope-tenant
  - model: authentik_core.application
    identifiers: { slug: identity-api }
    attrs: { name: Identity API, provider: !KeyOf prov-identity-api }
# JWKS: https://auth.joshuatech.dev/application/o/identity-api/jwks/
# 디스커버리: https://auth.joshuatech.dev/application/o/identity-api/.well-known/openid-configuration
```

**token exchange 요청(impersonation / audience / OBO)** — <https://docs.goauthentik.io/add-secure-apps/providers/oauth2/token_exchange/>
```
POST https://auth.joshuatech.dev/application/o/token/
Content-Type: application/x-www-form-urlencoded

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_id=<identity-api client_id>&client_secret=<identity-api secret>
&subject_token=<web-bff access token>
&subject_token_type=urn:ietf:params:oauth:token-type:access_token
&scope=openid tenant
# 다른 provider용 토큰: &audience=<대상 provider client_id 또는 app pbm_uuid>
#   → 대상 provider의 Federated OAuth2/OpenID Providers에 교환 수행 provider 등록 + 사용자가 대상 앱 정책 통과 필요
# OBO(delegation): &actor_token=<Actor 토큰>&actor_token_type=urn:ietf:params:oauth:token-type:access_token → JWT에 act 클레임
# 응답: access_token, issued_token_type, token_type=Bearer, expires_in, scope
```

**blueprint: login/logout 웹훅 transport + rule + event matcher** — <https://docs.goauthentik.io/sys-mgmt/events/notifications/>
```
version: 1
metadata: { name: joshuatech-auth-events }
entries:
  - model: authentik_core.group
    id: grp-sink
    identifiers: { name: webhook-sink }      # 알림 생성에 destination_group 필수
  - model: authentik_events.notificationwebhookmapping
    id: map-body
    identifiers: { name: auth-event-body }
    attrs:
      expression: |
        e = request.context["notification"].event
        return {"action": e.action, "user": e.user, "app": e.app,
                "client_ip": e.client_ip, "created": e.created.isoformat(),
                "context": e.context}
  - model: authentik_events.notificationwebhookmapping
    id: map-headers
    identifiers: { name: auth-event-headers }
    attrs:
      expression: !Format ["return {'Authorization': 'Bearer %s'}", !Env AUTHENTIK_WEBHOOK_TOKEN]
  - model: authentik_events.notificationtransport
    id: tr-webhook
    identifiers: { name: identity-api-webhook }
    attrs:
      mode: webhook
      webhook_url: http://identity-api.apps.svc.cluster.local:8000/internal/authentik/events
      webhook_mapping_body: !KeyOf map-body
      webhook_mapping_headers: !KeyOf map-headers
      send_once: true
  - model: authentik_policies_event_matcher.eventmatcherpolicy
    id: pol-login
    identifiers: { name: match-login }
    attrs: { action: login }
  - model: authentik_policies_event_matcher.eventmatcherpolicy
    id: pol-logout
    identifiers: { name: match-logout }
    attrs: { action: logout }
  - model: authentik_events.notificationrule
    id: rule
    identifiers: { name: forward-auth-events }
    attrs:
      severity: notice
      destination_group: !KeyOf grp-sink
      transports: [!KeyOf tr-webhook]
  - model: authentik_policies.policybinding
    identifiers: { target: !KeyOf rule, policy: !KeyOf pol-login, order: 0 }
  - model: authentik_policies.policybinding
    identifiers: { target: !KeyOf rule, policy: !KeyOf pol-logout, order: 1 }
# 기본 페이로드(매핑 없을 때): body, severity, user_email, user_username, event_user_email, event_user_username
```

**blueprint: 소셜 소스(GitHub/Google) + MFA 검증 스테이지 + embedded outpost proxy provider** — <https://docs.goauthentik.io/users-sources/sources/social-logins/github/>
```
version: 1
metadata: { name: joshuatech-core }
entries:
  - model: authentik_sources_oauth.oauthsource
    identifiers: { slug: github }            # 콜백: https://auth.joshuatech.dev/source/oauth/callback/github/
    attrs:
      name: GitHub
      provider_type: github
      consumer_key: !Env GITHUB_CLIENT_ID
      consumer_secret: !Env GITHUB_CLIENT_SECRET
      user_matching_mode: email_link
      authentication_flow: !Find [authentik_flows.flow, [slug, default-source-authentication]]
      enrollment_flow: !Find [authentik_flows.flow, [slug, default-source-enrollment]]
  # google: slug google / provider_type google / 콜백 .../source/oauth/callback/google/ (Google OAuth client = Web application)
  - model: authentik_stages_authenticator_validate.authenticatorvalidatestage
    identifiers: { name: default-authentication-mfa-validation }   # 기본 인증 플로우 order 30
    attrs:
      device_classes: [totp, webauthn]
      not_configured_action: configure       # skip | deny | configure
      configuration_stages:
        - !Find [authentik_stages_authenticator_totp.authenticatortotpstage, [name, default-authenticator-totp-setup]]
        - !Find [authentik_stages_authenticator_webauthn.authenticatorwebauthnstage, [name, default-authenticator-webauthn-setup]]
      last_auth_threshold: days=30
  - model: authentik_providers_proxy.proxyprovider
    id: prov-django-admin
    identifiers: { name: django-admin-forward }
    attrs:
      mode: forward_single
      external_host: https://admin.joshuatech.dev
      authorization_flow: !Find [authentik_flows.flow, [slug, default-provider-authorization-implicit-consent]]
      invalidation_flow: !Find [authentik_flows.flow, [slug, default-provider-invalidation-flow]]
  - model: authentik_core.application
    identifiers: { slug: django-admin }
    attrs: { name: Django Admin, provider: !KeyOf prov-django-admin }
  - model: authentik_outposts.outpost
    identifiers: { managed: goauthentik.io/outposts/embedded }
    attrs:
      providers: [!KeyOf prov-django-admin]
      config: { authentik_host: https://auth.joshuatech.dev }
```

**Traefik forward-auth (embedded outpost) Middleware + IngressRoute** — <https://docs.goauthentik.io/add-secure-apps/providers/proxy/server_traefik>
```
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata: { name: authentik-forward-auth, namespace: apps }   # Middleware는 참조하는 IngressRoute와 같은 ns(또는 allowCrossNamespace)
spec:
  forwardAuth:
    address: http://authentik-server.authentik.svc.cluster.local/outpost.goauthentik.io/auth/traefik   # Service(80), Ingress 아님
    trustForwardHeader: true
    authResponseHeaders: [X-authentik-username, X-authentik-groups, X-authentik-entitlements, X-authentik-email,
      X-authentik-name, X-authentik-uid, X-authentik-jwt, X-authentik-meta-jwks, X-authentik-meta-outpost,
      X-authentik-meta-provider, X-authentik-meta-app, X-authentik-meta-version]
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: { name: django-admin, namespace: apps }
spec:
  entryPoints: [websecure]
  routes:
    - kind: Rule
      match: Host(`admin.joshuatech.dev`)
      priority: 10
      middlewares: [{ name: authentik-forward-auth }]
      services: [{ name: identity-api, port: 8000 }]
---
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata: { name: outpost-paths, namespace: authentik }        # 앱 호스트의 /outpost.goauthentik.io/ 를 authentik-server로
spec:
  entryPoints: [websecure]
  routes:
    - kind: Rule
      match: Host(`admin.joshuatech.dev`) && PathPrefix(`/outpost.goauthentik.io/`)
      priority: 15
      services: [{ name: authentik-server, port: 80 }]
# 표준 Ingress 사용 시: annotation traefik.ingress.kubernetes.io/router.middlewares: apps-authentik-forward-auth@kubernetescrd
```

**Argo CD(Dex OIDC) / Vault(OIDC auth) 공식 통합 요약** — <https://integrations.goauthentik.io/security/hashicorp-vault/>
```
# argocd-cm  (authentik provider: OAuth2/OIDC, Redirect URI strict https://argocd.joshuatech.dev/api/dex/callback)
dex.config: |
  connectors:
  - type: oidc
    id: authentik
    name: authentik
    config:
      issuer: https://auth.joshuatech.dev/application/o/argocd/
      clientID: <client_id>
      clientSecret: $dex.authentik.clientSecret
      insecureEnableGroups: true
      scopes: [openid, profile, email]
# argocd-rbac-cm  policy.csv: |  g, platform-admins, role:admin

# Vault (Redirect URIs: https://vault.joshuatech.dev/ui/vault/auth/oidc/oidc/callback, http://localhost:8250/oidc/callback)
vault auth enable oidc
vault write auth/oidc/config oidc_discovery_url="https://auth.joshuatech.dev/application/o/vault/" \
  oidc_client_id="<client_id>" oidc_client_secret="<secret>" default_role="reader"
vault write auth/oidc/role/reader bound_audiences="<client_id>" \
  allowed_redirect_uris="https://vault.joshuatech.dev/ui/vault/auth/oidc/oidc/callback" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="sub" groups_claim="groups" oidc_scopes="profile" token_policies="reader"
```

**OpenFGA values.yaml (chart 0.3.13)** — <https://github.com/openfga/helm-charts/blob/main/charts/openfga/README.md>
```
replicaCount: 1
image: { pullPolicy: IfNotPresent }              # 기본 Always
datastore:
  engine: postgres                               # 기본 memory
  existingSecret: openfga-db                     # ESO: uri=postgres://openfga:<pw>@pg-main-rw.data.svc.cluster.local:5432/openfga?sslmode=require
  secretKeys: { uriKey: uri }
  applyMigrations: true
  waitForMigrations: true                        # init container(groundnuty/k8s-wait-for job-wr <release>-migrate)
  migrationType: job                             # helm.sh/hook post-install,post-upgrade → Argo CD 훅 매핑 검증(open)
  maxOpenConns: 10
authn:
  method: preshared
  preshared: { keysSecret: openfga-authn }       # Secret data 키 이름은 반드시 keys (comma-separated)
playground: { enabled: false }                   # 기본 true
checkQueryCache: { enabled: true }
log: { format: json, level: info }
telemetry: { metrics: { enabled: true } }
resources: { requests: { cpu: 50m, memory: 128Mi }, limits: { memory: 512Mi } }
extraEnvVars:
  - { name: OPENFGA_DATASTORE_MIN_OPEN_CONNS, value: "2" }
  - { name: OPENFGA_REQUEST_TIMEOUT, value: 3s }
# helm install openfga oci://ghcr.io/openfga/helm-charts/openfga --version 0.3.13 -f values.yaml
```

**fga CLI: 모델 검증/테스트, env별 store, 모델 발행** — <https://github.com/openfga/cli/blob/main/README.md>
```
# CI (서버 불필요)
fga model validate --file authz/model.fga
fga model test --tests authz/model.fga.yaml

# CD (in-cluster Job 또는 cloudflared 경유)
export FGA_API_URL=http://openfga.platform.svc.cluster.local:8080
export FGA_API_TOKEN="$OPENFGA_PRESHARED_KEY"
fga store create --name joshuatech-dev --model authz/model.fga     # 최초 1회 → {"store":{"id":"01J…"},"model":{"authorization_model_id":"01J…"}}
fga model write --store-id "$FGA_STORE_ID" --file authz/model.fga  # 새 모델 버전(불변); 앱은 최신 model id 사용
fga store import --store-id "$FGA_STORE_ID" --file authz/seed.fga.yaml   # 모델 + 시드 튜플
# ~/.fga.yaml: api-url / store-id / api-token 로 대체 가능
```

### 함정

- Redis는 2025.10부터 완전히 제거됨(캐시·태스크·embedded outpost·WebSocket 모두 PostgreSQL). Dragonfly를 authentik에 연결하지 말고 AUTHENTIK_REDIS__* 설정도 넣지 말 것 — 차트 2026.8.0 values에 redis 키 자체가 없다.
- PostgreSQL SSLMODE: 문서 기본은 verify-ca(verify-*는 SSLROOTCERT 필수), main 브랜치 default.yml은 disable로 상충. CNPG 서버 인증서는 자체 CA라 verify-* 사용 시 `<cluster>-ca` Secret의 ca.crt를 마운트하지 않으면 기동 실패 → SSLMODE/SSLROOTCERT를 항상 명시.
- 차트 번들 bitnami postgresql(18.8.13)은 데모/테스트 전용이며 postgresql.enabled=false로 꺼야 CNPG를 쓴다. 차트 의존성 authentik-remote-cluster(serviceAccount.create)는 Kubernetes 아웃포스트 통합용 ClusterRole을 만든다 — embedded outpost만 쓰면 불필요하지만 끄면 자동 생성되는 Local Kubernetes 서비스 연결이 실패 로그를 낼 수 있으니 embedded outpost의 service_connection을 비워두는 쪽을 검증.
- 블루프린트 ConfigMap: `.yaml`로 끝나는 키만 발견, ConfigMap 1 MiB 한도, 파일 간 적용 순서 미보장(의존 객체는 한 파일에 !KeyOf/!Find). 60분마다 재적용되므로 UI에서 손으로 바꾼 값은 되돌아간다(의도된 GitOps 동작이지만 운영자가 놀랄 수 있음).
- OAuth2 provider 기본 access_token_validity는 hours=1(문서에 미기재, models.py 기준). signing_key를 지정하지 않으면 client_secret 대칭 서명이라 JWKS 검증이 불가 → pod 간 토큰 검증에는 CertificateKeyPair 필수. sub_mode 기본 hashed_user_id.
- Token exchange는 provider별 기본 비활성(Grant Types에 추가). 교환 수행 provider의 Federated OAuth2/OpenID Providers에 subject 토큰 발급 provider를 넣어야 하고, audience 지정 시 대상 provider 쪽에도 교환 provider 등록 + 사용자가 대상 앱 정책 통과 필요. federated 등록은 introspect/revoke 권한도 함께 부여한다.
- 알림은 destination_group 또는 destination_event_user가 설정된 rule에서만 생성되며, 알림 rule에 바인딩된 정책이 만든 이벤트는 루프 방지로 알림을 만들지 않는다. 웹훅 재시도/전달 보장은 문서화되어 있지 않으므로 pod 쪽 outbox+Kafka를 진실 원천으로 두고 웹훅은 best-effort로 취급.
- embedded outpost는 기본 활성(outposts.disable_embedded_outpost=false)이며 server pod의 9000 포트에서 /outpost.goauthentik.io 를 처리. Traefik forwardAuth address는 Ingress가 아닌 in-cluster Service(authentik-server, servicePortHttp 80)를 가리켜야 하고, 각 앱 호스트의 /outpost.goauthentik.io/ 경로를 authentik-server로 라우팅(priority 높게)해야 한다. Traefik 3(K3s 번들)은 CRD apiVersion traefik.io/v1alpha1.
- Traefik CRD provider는 기본 allowCrossNamespace=false — 다른 ns의 Middleware/Service를 IngressRoute에서 참조하면 무시된다. Middleware는 앱 ns마다 두거나 HelmChartConfig에서 providers.kubernetescrd.allowCrossNamespace=true 설정.
- Argo CD·Vault 앞에 forward-auth를 걸면 argocd CLI(gRPC)·vault CLI 로그인과 API 클라이언트가 쿠키 기반 리다이렉트에 깨진다. 공식 통합은 둘 다 OIDC(Argo=Dex 커넥터, Vault=auth/oidc). Cloudflare Access(GitHub IdP)까지 겹치면 삼중 로그인.
- 2026.8 breaking: `hash_password` 명령이 인자로 비밀번호를 받지 않음(stdin), WebAuthn 셋업 스테이지의 '중복 기기 방지' 옵션 삭제, AUTHENTIK_POSTGRESQL__CONN_OPTIONS deprecated. 2026.8은 OpenID Certified(로그아웃 프로파일 포함).
- arm64: ghcr.io/goauthentik/server는 amd64/arm64 멀티아치. 별도 proxy outpost 이미지(ghcr.io/goauthentik/proxy)는 과거 arm64 누락 이슈가 있었으므로 embedded outpost로 회피하고, 독립 outpost가 필요해지면 매니페스트를 먼저 확인.
- OpenFGA 차트 기본값 함정: replicaCount 3, datastore.engine memory, playground.enabled true, image.pullPolicy Always, postgresql/mysql 서브차트 deprecated. authn.preshared.keysSecret은 Secret의 data 키가 정확히 `keys`(comma-separated)여야 함.
- OpenFGA 마이그레이션 Job은 helm.sh/hook post-install/post-upgrade이고 Deployment의 init container가 그 Job 완료를 기다린다. Argo CD는 helm 훅을 PostSync로 매핑해 Deployment가 Healthy가 될 때까지 Job을 안 돌리므로 교착 가능 — Argo 배포 전 검증 필요(open).
- OpenFGA 요청 타임아웃 기본 3s, check-query-cache 기본 off, max-tuples-per-write 100(시드 튜플 배치 크기 제한). SQLite datastore는 beta.
- 호스트 최소 사양(docker-compose 문서): 2 CPU/2 GB. 노드 A(2 OCPU/13 GB)에 authentik server+worker(각 512Mi 요청)와 OpenFGA(128Mi)를 함께 올려도 여유가 있으나 Vault·Strimzi·Argo와 합산해 requests 총량을 plan에서 계산할 것.

### 미확인

- 2026.8.1: 릴리스 노트에 'Fixed in 2026.8.1' 절이 있으나 2026-09-01 기준 GitHub 태그/릴리스는 version/2026.8.0까지만 존재 → 차트 2026.8.0으로 핀하고 patch 태그를 Renovate로 추적.
- Actor(에이전트 계정) 생성 경로와 actor_token 발급 절차(2026.8 신기능 'Agent Accounts')의 정확한 UI/블루프린트 모델명을 문서에서 확인하지 못함.
- token exchange 응답에 refresh_token/id_token이 포함되는지, audience 대상 토큰에 대상 provider의 스코프 매핑(tenant_id)이 적용되는지 문서에 없음 → 스테이징에서 검증.
- OpenFGA `migrationType` 허용값(job 외 initContainer 등)과 Argo CD 훅 매핑 교착 여부를 차트 소스에서 직접 확인 필요; 필요 시 PreSync Job으로 `openfga migrate`를 분리.
- OpenFGA의 PostgreSQL 18 명시 지원 여부(README는 'PostgreSQL 14+', 차트 README는 PG ≥15.4 권고).
- authentik SSLMODE 실제 기본값(문서 verify-ca vs default.yml disable) — 어느 쪽이든 명시하므로 영향은 없으나 문서 정정 여부 추적.
- 차트 `authentik.existingSecret.secretName`이 생성 Secret을 완전히 대체하는지(그 경우 authentik.postgresql.* 값이 무시되는지) 미확인 → global.env valueFrom 방식으로 우회.
- 블루프린트 `!Format` 태그 인자 순서와 NotificationWebhookMapping 모델명(authentik_events.notificationwebhookmapping)은 소스 기억 기반 — 적용 전 `ak export_blueprint` 결과와 대조.
- ghcr.io/goauthentik/proxy arm64 매니페스트 존재 여부(독립 outpost가 필요해질 때만).
- embedded outpost에 service_connection이 자동 지정될 때 forward_single 모드에서 K8s Ingress/Middleware 객체를 자동 생성·간섭하는지(직접 라우팅과 충돌 가능) 검증.
- 웹훅 transport의 재시도·타임아웃 정책과 순서 보장 여부(문서 없음).


## R8 Next.js · OpenNext

R8 — Next.js 16.3 + @opennextjs/cloudflare lean 구성 (정적 프리렌더 + BFF Route Handler, Workers Free)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| @opennextjs/cloudflare | 1.20.5 | 2026-08-31 (1.20.3 2026-08-26: Next peer 15.5.24/16.3.3, 16.3 Turbopack wasm 패치 수정, 실험적 Node middleware) | <https://github.com/opennextjs/opennextjs-cloudflare/releases> |
| wrangler | 4.127.1 | 2026-08-28 (check startup 번들/gzip 출력은 4.116.0+, preview alias 4.21.0+, 긴 alias 자동 축약 4.30.0+) | <https://github.com/cloudflare/workers-sdk/releases> |
| next | 16.3.4 | 2026-08-31 (16.3.0 2026-08-03; 16.3.3 2026-08-25 보안 수정 — 16.3.3 미만 금지) | <https://github.com/vercel/next.js/releases> |
| cloudflare/wrangler-action | v4.0.0 | 2026-05-12 (기본 wrangler v4, Global API Key 지원 제거, 태그는 @v4 형식) | <https://github.com/cloudflare/wrangler-action/tags> |
| Node.js (요구) | Next 16: >= 20.9 / wrangler: Current·Active·Maintenance 버전 |  | <https://nextjs.org/docs/app/getting-started/installation> |
| vinext (Cloudflare 신규 권장 경로, 참고) | 1.0.0-beta.8 | 2026-08-20 (beta; Cache Components·PPR 미지원) | <https://github.com/cloudflare/vinext/releases> |
| GitHub Actions ubuntu-24.04-arm (public repo 무료) | GA | 2025-08-07 | <https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/> |

### 결정

**OPENNEXT-D1. 어댑터: OpenNext vs Cloudflare 문서가 권장하는 vinext?**

- Decision: @opennextjs/cloudflare 1.20.x 유지
- Rationale: Cloudflare 문서는 vinext를 권장 경로로 바꿨지만 vinext는 1.0.0-beta.8이며 Cache Components·PPR·빌드타임 이미지 최적화 미지원. OpenNext는 Next 16 전 minor 지원(1.20.3 peer 16.3.3)이고 정적+Route Handler 조합이 검증돼 있음
- Alternatives considered: vinext(빌드 빠르고 번들 작으나 beta) / output:'export' + 별도 Worker(BFF를 Next Route Handler로 못 씀)
- Source: <https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/>

**OPENNEXT-D2. open-next.config.ts 최소 설정(캐시 비활성/정적 전용)**

- Decision: incrementalCache: staticAssetsIncrementalCache + enableCacheInterception: true, 나머지(tagCache/queue/cachePurge) 생략
- Rationale: defineCloudflareConfig 기본값이 모두 "dummy"이므로 생략만으로 KV/R2/D1/DO 바인딩이 0개가 됨. static-assets 캐시는 읽기 전용(ISR 불가)이며 ASSETS 바인딩만 사용. cache interception은 프리렌더 라우트에서 NextServer 로드를 생략해 콜드스타트·CPU 절감. WORKER_SELF_REFERENCE는 revalidation 전용이라 불필요
- Alternatives considered: R2 incremental cache(유료 성격·바인딩 필요) / KV(eventually consistent) / 캐시 완전 dummy(프리렌더 페이지도 매번 렌더 → CPU 낭비)
- Source: <https://opennext.js.org/cloudflare/caching>

**OPENNEXT-D3. 프리렌더 HTML을 정적 자산으로 서빙해 Worker 호출·CPU를 0으로 만들 수 있나?**

- Decision: 기본 구성에서는 불가 — 페이지 요청은 Worker가 받되 cache interception으로 ASSETS(cdn-cgi/_next_cache)에서 즉시 응답. 'Worker 미호출'은 실험 옵션(빌드 후 .next/server/app/**/*.html을 .open-next/assets로 복사)으로만 가능하며 E2E로 검증 후 채택
- Rationale: OpenNext는 프리렌더 HTML을 assets에 넣지 않고 .cache 파일만 populateCache 시 assets/cdn-cgi/_next_cache로 복사한다(populate-cache.ts). 자산이 없으면 Worker가 호출되는 것이 Static Assets 기본 동작. HTML을 assets에 복사하면 경로 기반 매칭이라 RSC 요청(?_rsc=, RSC 헤더)에도 HTML이 반환되고 Next 클라이언트는 non-text/x-component 응답을 doMpaNavigation(전체 페이지 로드)으로 강등시킴
- Alternatives considered: output:'export'(RSC 페이로드를 .txt로 내보내 정적 호스팅에 맞게 설계됨, 단 요청 의존 Route Handler 불가) / Worker 호출 감수(정적 자산 요청은 무료·무제한이므로 페이지 HTML만 Worker 1회)
- Source: <https://github.com/cloudflare/cloudflare-docs/issues/24616>

**OPENNEXT-D4. wrangler.jsonc assets 라우팅(run_worker_first, not_found_handling)**

- Decision: assets.directory .open-next/assets, binding ASSETS, run_worker_first: ["/api/*"], not_found_handling 생략(none)
- Rationale: 기본(false)만으로도 _next/static·public·cdn-cgi/_next_cache는 Worker를 거치지 않고 서빙되며 자산 미스는 Worker로 감. 배열 지정은 /api/*가 자산과 충돌해도 항상 Worker로 가도록 명시하는 문서화 목적. not_found_handling은 none이어야 미스가 Worker(Next 404)로 감. compatibility_date 2025-04-01+면 assets_navigation_prefers_asset_serving으로 내비게이션 요청이 자산 우선
- Alternatives considered: run_worker_first: true(모든 요청 과금·자산 헤더 무시, skew protection 필요 시만) / not_found_handling 404-page(정적 404 파일 필요, Worker 404 미사용 시)
- Source: <https://developers.cloudflare.com/workers/static-assets/binding/>

**OPENNEXT-D5. compatibility_date / flags**

- Decision: compatibility_date "2026-08-04" 이상(오늘 날짜 고정), compatibility_flags ["nodejs_compat", "global_fetch_strictly_public"]
- Rationale: 2026-08-04+는 nodejs_compat·nodejs_compat_v2가 기본 활성이지만 OpenNext 설정 검사가 nodejs_compat 명시를 기대함. 2025-05-05+로 FinalizationRegistry 오류 해소, 2025-04-01+로 자산 우선 내비게이션. global_fetch_strictly_public은 BFF가 같은 zone(api.joshuatech.dev)을 fetch할 때 Cloudflare front door(Access·WAF)를 거치게 함
- Alternatives considered: 템플릿 기본 2024-12-30(구 동작·FinalizationRegistry 이슈)
- Source: <https://developers.cloudflare.com/workers/configuration/compatibility-flags/>

**OPENNEXT-D6. app/[lang] 전부 프리렌더 + Route Handler만 동적으로 남기는 설정**

- Decision: app/[lang]/layout.tsx에 generateStaticParams([ko,en,ja]) + export const dynamicParams = false; app/api/**/route.ts에 export const dynamic = 'force-dynamic'; cacheComponents는 끈 채 유지
- Rationale: v15부터 GET 핸들러는 기본 동적이지만 force-dynamic으로 빌드 시 프리렌더를 명시적으로 금지. cacheComponents를 켜면 dynamic/dynamicParams 세그먼트 설정이 제거되고 cache interception도 PPR과 비호환. 16.3 root params(next/root-params의 lang())는 Server Component 전용, Route Handler 미지원
- Alternatives considered: generateStaticParams만(미지정 lang이 런타임 렌더돼 Worker CPU 사용) / cacheComponents+'use cache'(SP-2 이후 검토)
- Source: <https://nextjs.org/docs/app/guides/caching-without-cache-components>

**OPENNEXT-D7. 이미지 최적화**

- Decision: next.config images.unoptimized: true, wrangler.jsonc images 바인딩 미선언
- Rationale: OpenNext에서 next/image 최적화는 IMAGES 바인딩 또는 custom loader가 있어야 동작. 비활성화하면 /_next/image Worker 호출과 Cloudflare Images 사용량이 0
- Alternatives considered: custom loader → /cdn-cgi/image/(zone Image Transformations 필요, 무료 한도 확인 필요) / IMAGES 바인딩(사용량 과금)
- Source: <https://opennext.js.org/cloudflare/howtos/image>

**OPENNEXT-D8. 서버 번들 gzip 크기 측정·CI 게이트(<= 2.5 MiB)**

- Decision: CI에서 opennextjs-cloudflare build → wrangler versions upload --dry-run --outdir .wrangler/dry-run → 출력 파일 gzip -9 합산 → 2,621,440 bytes 초과 시 실패. 보조로 wrangler check startup("Bundle: X KiB / gzip: Y KiB")
- Rationale: Free 한도 3 MiB는 압축 후 크기 기준. dry-run은 인증 없이 실제 배포와 같은 esbuild 번들을 만들며, 분석은 .open-next/server-functions/default/handler.mjs.meta.json을 esbuild analyzer에 넣음
- Alternatives considered: wrangler deploy 로그의 'gzip:' 파싱(배포 시점이라 늦음) / opennextjs 1.2+ 기준 일반 앱 1.6 MiB gzip 수준이라 여유
- Source: <https://developers.cloudflare.com/changelog/post/2026-07-31-wrangler-startup-profile-summary/>

**OPENNEXT-D9. PR 프리뷰: wrangler versions upload --preview-alias**

- Decision: PR마다 `versions upload --preview-alias pr-<number>` → https://pr-<n>-<worker>.<subdomain>.workers.dev; main은 `deploy`
- Rationale: alias는 소문자·숫자·대시, 소문자로 시작, alias+worker 이름 <= 63자(브랜치명은 '/' 때문에 부적합 → PR 번호 사용), 최근 1000개만 보존. workers.dev 전용(커스텀 도메인 불가), preview_urls 기본값 = workers_dev. 문서상 플랜 제한 언급 없음
- Alternatives considered: 브랜치명 alias(4.30.0+ 자동 축약·해시) / 별도 스테이징 Worker
- Source: <https://developers.cloudflare.com/workers/configuration/previews/>

**OPENNEXT-D10. wrangler-action v4 사용법**

- Decision: cloudflare/wrangler-action@v4 with apiToken(‘Edit Cloudflare Workers’ 템플릿), accountId, workingDirectory, packageManager: pnpm, command: 'versions upload --preview-alias …' 또는 'deploy'
- Rationale: v4는 wrangler v4 기본, Global API Key 제거, @v4 태그 형식. command는 'wrangler ' 뒤에 붙는 문자열이므로 opennextjs-cloudflare 명령은 별도 run 스텝(build, populateCache local)으로 먼저 실행
- Alternatives considered: run 스텝에서 pnpm exec opennextjs-cloudflare upload --preview-alias … (미인식 플래그를 wrangler로 전달하는 코드 경로 존재, CI에서 검증 필요)
- Source: <https://github.com/cloudflare/wrangler-action>

**OPENNEXT-D11. Workers Free에서 OpenNext 바인딩 전부 끄기**

- Decision: wrangler.jsonc에 kv_namespaces/r2_buckets/d1_databases/durable_objects/services(WORKER_SELF_REFERENCE)/images를 선언하지 않음; open-next.config.ts는 static-assets 캐시만
- Rationale: queue/tagCache/cachePurge 기본 "dummy"; DO 큐·D1 태그·R2 캐시는 revalidation 전용. Free 플랜은 DO가 SQLite 백엔드만 가능하고 Worker당 3 MiB·10 ms CPU·100k req/day 한도. 정적 자산 요청은 무료·무제한
- Alternatives considered: KV incremental cache(Free 100k read/day 소모) — 불필요
- Source: <https://developers.cloudflare.com/workers/platform/pricing/>

**OPENNEXT-D12. Windows 개발 환경**

- Decision: next dev는 Windows 네이티브 허용, opennextjs-cloudflare build/preview는 WSL2(Ubuntu, 저장소는 /home 아래) 또는 CI(ubuntu)에서만
- Rationale: OpenNext 공식: 'Windows full support is not guaranteed', WSL·Linux VM·Linux CI 권장. Next 공식 지원 OS는 macOS·Windows(WSL 포함)·Linux. MS 문서: WSL 프로젝트는 /mnt/c가 아닌 Linux FS에 두어야 성능 확보
- Alternatives considered: Windows에서 OpenNext 직접 실행(자기 책임, 1.20.2에 Windows 경로 정규화 수정 있었음)
- Source: <https://opennext.js.org/cloudflare#windows-support>

**OPENNEXT-D13. CI 러너**

- Decision: 웹 Worker 빌드는 ubuntu-24.04(x64); ubuntu-24.04-arm은 Django 이미지 빌드에만
- Rationale: Worker 산출물은 아키텍처 무관. OpenNext/wrangler/workerd의 linux-arm64 동작은 문서로 확인 못 함(open)
- Alternatives considered: ubuntu-24.04-arm 단일 러너(검증 후)
- Source: <https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/>

### 설정 스니펫

**open-next.config.ts (lean, 바인딩 0개)** — <https://opennext.js.org/cloudflare/caching>
```
import { defineCloudflareConfig } from "@opennextjs/cloudflare";
import staticAssetsIncrementalCache from "@opennextjs/cloudflare/overrides/incremental-cache/static-assets-incremental-cache";

export default defineCloudflareConfig({
  incrementalCache: staticAssetsIncrementalCache, // 읽기 전용, ASSETS 바인딩만 사용(revalidate 불가)
  enableCacheInterception: true,                   // 프리렌더 라우트에서 NextServer 로드 생략
  // tagCache / queue / cachePurge 생략 → "dummy" (KV/R2/D1/DO 불필요)
});
```

**wrangler.jsonc** — <https://opennext.js.org/cloudflare/get-started>
```
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "joshuatech-web",
  "main": ".open-next/worker.js",
  "compatibility_date": "2026-08-04",
  "compatibility_flags": ["nodejs_compat", "global_fetch_strictly_public"],
  "assets": {
    "directory": ".open-next/assets",
    "binding": "ASSETS",
    "run_worker_first": ["/api/*"]
    // not_found_handling 생략(none): 자산 미스 → Worker(Next 404)
  },
  "routes": [{ "pattern": "joshuatech.dev", "custom_domain": true }],
  "workers_dev": true,   // preview alias는 workers.dev 전용
  "preview_urls": true
  // kv_namespaces / r2_buckets / d1_databases / durable_objects / services / images: 선언하지 않음
}
```

**next.config.ts** — <https://opennext.js.org/cloudflare/get-started>
```
import type { NextConfig } from "next";
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";

const nextConfig: NextConfig = {
  images: { unoptimized: true },   // /_next/image Worker 호출·IMAGES 바인딩 회피
  trailingSlash: false,             // assets html_handling(auto-trailing-slash)과 일치
  // cacheComponents 미설정(false): export const dynamic 사용, cache interception은 PPR 비호환
  // serverExternalPackages: ["jose"]  // workerd 조건부 export 패키지를 쓸 때만
};

export default nextConfig;
initOpenNextCloudflareForDev();
```

**app/[lang]/layout.tsx + app/api/health/route.ts** — <https://nextjs.org/docs/app/api-reference/functions/generate-static-params>
```
// app/[lang]/layout.tsx
export const dynamicParams = false; // ko/en/ja 외는 404, 런타임 렌더 금지
export function generateStaticParams() {
  return [{ lang: "ko" }, { lang: "en" }, { lang: "ja" }];
}
export default async function RootLayout({ children, params }: LayoutProps<"/[lang]">) {
  const { lang } = await params;
  return <html lang={lang}><body>{children}</body></html>;
}

// app/api/health/route.ts (BFF, [lang] 밖)
export const dynamic = "force-dynamic"; // 빌드 시 프리렌더 금지
export async function GET(request: Request) {
  return Response.json({ ok: true, at: new Date().toISOString() });
}
```

**package.json scripts + public/_headers + .dev.vars** — <https://opennext.js.org/cloudflare/cli>
```
"scripts": {
  "dev": "next dev",
  "build": "next build",
  "cf:build": "opennextjs-cloudflare build",
  "cf:populate": "opennextjs-cloudflare populateCache local",
  "preview": "opennextjs-cloudflare build && opennextjs-cloudflare preview",
  "deploy": "opennextjs-cloudflare build && opennextjs-cloudflare deploy",
  "upload": "opennextjs-cloudflare build && opennextjs-cloudflare upload",
  "cf-typegen": "wrangler types --env-interface CloudflareEnv cloudflare-env.d.ts",
  "size:check": "bash scripts/check-worker-size.sh"
}

# public/_headers
/_next/static/*
  Cache-Control: public,max-age=31536000,immutable

# .dev.vars (gitignore)
NEXTJS_ENV=development
# .gitignore 에 .open-next 추가
```

**scripts/check-worker-size.sh (CI gzip 게이트)** — <https://developers.cloudflare.com/workers/wrangler/commands/workers/>
```
#!/usr/bin/env bash
set -euo pipefail
LIMIT=${WORKER_GZIP_LIMIT:-2621440}   # 2.5 MiB (Free 한도 3 MiB, 압축 후 기준)
OUT=.wrangler/dry-run
rm -rf "$OUT"
npx wrangler versions upload --dry-run --outdir "$OUT"   # 인증 불필요, 배포와 같은 번들
total=0
while IFS= read -r -d '' f; do
  s=$(gzip -9 -c "$f" | wc -c); total=$((total + s))
done < <(find "$OUT" -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.bin' \) -print0)
echo "worker gzip total: $total bytes (limit $LIMIT)"
[ "$total" -le "$LIMIT" ] || { echo "::error::Worker gzip size $total > $LIMIT"; exit 1; }
# 보조: npx wrangler check startup  → "Bundle: N KiB / gzip: M KiB" (wrangler >= 4.116.0)
# 분석: .open-next/server-functions/default/handler.mjs.meta.json → esbuild bundle analyzer
```

**.github/workflows/web.yml (wrangler-action v4: PR 프리뷰 + main 배포)** — <https://developers.cloudflare.com/workers/ci-cd/external-cicd/github-actions/>
```
name: web
on:
  push: { branches: [main], paths: ["apps/web/**"] }
  pull_request: { paths: ["apps/web/**"] }
permissions: { contents: read }
jobs:
  web:
    runs-on: ubuntu-24.04
    defaults: { run: { working-directory: apps/web } }
    steps:
      - uses: actions/checkout@v6
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v5
        with: { node-version: 22, cache: pnpm, cache-dependency-path: apps/web/pnpm-lock.yaml }
      - run: pnpm install --frozen-lockfile
      - run: pnpm run cf:build            # next build + OpenNext
      - run: pnpm run size:check          # gzip <= 2.5 MiB
      - run: pnpm run cf:populate         # .open-next/cache → assets/cdn-cgi/_next_cache (raw wrangler 사용 시 필수)
      - name: Preview (PR, 같은 repo만 — fork PR엔 secrets 없음)
        if: github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository
        uses: cloudflare/wrangler-action@v4
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}   # 'Edit Cloudflare Workers' 템플릿
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          workingDirectory: apps/web
          packageManager: pnpm
          command: versions upload --preview-alias pr-${{ github.event.number }}
      - name: Deploy (main)
        if: github.ref == 'refs/heads/main'
        uses: cloudflare/wrangler-action@v4
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          workingDirectory: apps/web
          packageManager: pnpm
          command: deploy
```

**(실험) 프리렌더 HTML을 Static Assets로 직접 서빙 — Worker 미호출, RSC 내비게이션은 MPA로 강등** — <https://rohitai.com/blog/fix-nextjs-blog-not-displaying-cloudflare-workers>
```
# opennextjs-cloudflare build 직후, 프로젝트 루트에서
find .next/server/app -name '*.html' -not -name '_not-found*' -print0 | while IFS= read -r -d '' f; do
  rel=${f#.next/server/app/}
  mkdir -p ".open-next/assets/$(dirname "$rel")"
  cp "$f" ".open-next/assets/$rel"      # /ko/about → ko/about.html (html_handling auto-trailing-slash)
done
# 검증: curl -H 'RSC: 1' https://…/ko/about → HTML이 오면 클라이언트는 doMpaNavigation(전체 로드)
```

### 함정

- 프리렌더 페이지도 Worker를 호출한다: OpenNext는 HTML을 assets에 넣지 않고(.cache만 populateCache 시 assets/cdn-cgi/_next_cache로 복사) Worker가 cache interception으로 응답한다. 100k req/day·CPU를 소모하며, 'static' 페이지 내용은 Worker 번들 크기에도 포함된다(cloudflare-docs #24616, 2025-08 open)
- HTML을 assets에 복사하는 실험은 경로 기반 매칭이라 RSC 요청(?_rsc=, RSC 헤더)에 HTML을 돌려주고 Next 클라이언트는 non-text/x-component 응답을 doMpaNavigation(전체 페이지 로드)으로 처리한다(fetch-server-response.ts). 프리페치도 HTML을 내려받는다
- Next 16.3 + OpenNext(cache interception 사용 시) 무한 RSC prefetch 루프: issue #1334(2026-08-10 open), PR #1348(2026-08-19 open, 'cache-interception 빌드 한정'). 16.2.12로 내리면 사라짐. 본 설계가 enableCacheInterception을 쓰므로 직접 영향 — 도입 시 Next-Router-Prefetch 요청 수를 E2E로 계측하고 필요하면 next를 16.2.x에 고정
- Next 16.3 Turbopack wasm 패치 누락(#1335/#1342/#1351, WebAssembly.compileStreaming is not a function)은 1.20.3에서 수정 — wasm 의존성(Prisma 등) 쓰면 1.20.3+ 필수
- Workers Free: Worker 3 MiB(압축 후), 10 ms CPU/요청, 100k 요청/일, 정적 자산 20,000 파일/버전·25 MiB/파일. run_worker_first 경로는 한도 초과 시 정적 폴백 없이 429. 정적 자산 요청은 무료·무제한
- 10 ms CPU 한도에서 Next Route Handler(OpenNext 런타임 포함)의 실제 CPU는 문서로 확인 못 함(커뮤니티에는 프록시 핸들러 수십 ms 보고) — BFF는 얇게(fetch 위임·JSON 패스스루) 유지하고 Error 1102를 E2E에서 감시
- static-assets incremental cache는 읽기 전용: revalidate/revalidateTag/ISR/'use cache' 저장이 동작하지 않는다. 페이지는 완전 정적으로만
- cacheComponents를 켜면 dynamic·dynamicParams·revalidate 세그먼트 설정이 제거되고 cache interception은 PPR과 비호환 — SP-1은 끈다
- `export const runtime = 'edge'`는 미지원(제거). Next 16 proxy.ts(Node middleware)는 1.20.3에서 실험적(nodejs_compat 필요) — lean 구성에선 쓰지 않음
- compatibility_date 2026-08-04+는 nodejs_compat/v2가 기본이지만 OpenNext 설정 검사를 위해 nodejs_compat을 명시. remove_nodejs_compat_eol_v22(2027-04-30)·v24(2028-04-30)에 대비해 날짜를 고정하고 의도적으로만 올린다
- global_fetch_strictly_public: 같은 zone 호출이 Cloudflare front door로 나가므로 BFF→api.joshuatech.dev에 Access Service Auth 헤더(CF-Access-Client-Id/Secret)를 반드시 실어야 하고, 자기 호스트를 fetch하면 같은 Worker로 되돌아올 수 있다
- Preview URL은 workers.dev 전용, DO 포함 Worker엔 생성 안 됨, 로그(Workers Logs/tail) 조회 불가, alias 1000개 초과분 삭제. workers.dev를 켜면 커스텀 도메인과 중복 색인 가능성(workers.dev 응답에 noindex 헤더/robots 처리 검토)
- wrangler-action의 command는 'wrangler ' 뒤 문자열이므로 opennextjs-cloudflare build/populateCache는 별도 run 스텝으로; raw `wrangler versions upload`를 쓰면 populateCache local을 먼저 돌려야 cdn-cgi/_next_cache가 assets에 들어간다(build 단계는 복사하지 않음). fork PR에는 secrets가 없어 프리뷰 스텝을 조건부로
- wrangler-action v4는 @v4 태그 형식만, Global API Key/Email 인증 제거. 토큰은 'Edit Cloudflare Workers' 템플릿, 계정 ID는 secret
- 이미지: images.unoptimized 없이 next/image를 쓰면 IMAGES 바인딩 또는 custom loader가 없어 최적화가 동작하지 않고 /_next/image가 Worker를 탄다(#1328 원격 이미지 I/O 오류 보고)
- 번들 분석은 .open-next/server-functions/default/handler.mjs.meta.json → esbuild analyzer; 큰 원인은 흔히 Sentry 서버 계측 등. workerd 조건부 export 패키지(jose, postgres, @prisma/client)는 serverExternalPackages에 넣어야 workerd 엔트리포인트를 쓴다
- wrangler check startup의 CPU 프로파일은 로컬 CPU 기준이라 시간은 참고용, 크기(Bundle/gzip)만 게이트에 사용
- Windows: OpenNext는 'full support is not guaranteed'. WSL2에서 저장소를 /mnt/c가 아닌 Linux FS에 두어야 next build·파일 감시 성능이 나온다. 1.20.2가 Windows 경로 정규화를 고쳤지만 CI(ubuntu)가 정답
- Next 16.3부터 next build 디스크 캐시(turbopackFileSystemCache)가 기본 — CI에서 .next/cache를 actions/cache로 보존하면 재빌드가 빨라진다(선택)
- Cloudflare 문서가 Next.js 권장 경로를 vinext(beta)로 바꿨다 — OpenNext는 '기존 앱 유지' 용도로 서술. 유지보수 추이를 SP-2에서 재평가

### 미확인

- Workers Free 플랜에서 preview alias/versions upload가 실제 허용되는지 — 문서에 플랜 제한 언급이 없을 뿐 명시 확인 못 함(계정에서 1회 실행으로 검증)
- `opennextjs-cloudflare upload --preview-alias …` 플래그 패스스루(미인식 플래그를 wrangler로 전달하는 코드 경로 존재) 동작 여부 — CI에서 검증, 실패 시 populateCache local + raw wrangler 2단계로
- OpenNext build/wrangler dry-run/workerd가 ubuntu-24.04-arm 러너에서 도는지(문서 미확인) — 웹 빌드는 x64 유지 후 실험
- 프리렌더 HTML 복사 실험의 실제 효과(Worker 요청 수 감소량 vs MPA 강등·프리페치 낭비) — E2E에서 Next-Router-Prefetch/?_rsc 응답 검증 후 채택 여부 결정
- issue #1334(16.3 prefetch 루프) 수정 릴리스 시점 — 구현 착수 시 @opennextjs/cloudflare 릴리스 노트 재확인, 미해결이면 next 16.2.x 고정
- Free 플랜 10 ms CPU에서 OpenNext Route Handler(BFF)의 실측 CPU — 커뮤니티 보고(60–120 ms) 원문은 접근 불가(403)라 미검증
- workers_dev:false + preview_urls:true 조합이 허용되는지(문서는 preview_urls 기본값=workers_dev만 명시) — 중복 색인 회피용으로 확인
- custom loader(/cdn-cgi/image/) 채택 시 Cloudflare Image Transformations 무료 한도 — 현재 images.unoptimized라 보류
- assets 내 cdn-cgi/_next_cache/*.cache가 공개 URL로 노출되는지(Cloudflare가 /cdn-cgi/ 경로를 edge에서 가로채는지) — 프리렌더 데이터라 민감하지 않지만 확인


## R9 Django pod 템플릿

R9 Django 6.1 + Django Ninja 1.7 pod 템플릿 구성요소 (Python 3.13·uv·copier·RLS·outbox→Kafka·JWT·관측·테스트·arm64 Docker) — 2026-09-01 기준 조사

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| Python (3.13 계열 최신 패치) | 3.13.15 | 2026-08-05 (3.13.16 = 마지막 정규 bugfix, 2026-10-06 예정) | <https://www.python.org/downloads/release/python-31315/> |
| Django | 6.1 (6.1.1 은 2026-09-02 예정, 회귀 9건 수정) | 2026-08-05 — Python 3.12/3.13/3.14, PostgreSQL 15+, psycopg 3.1.12+ | <https://docs.djangoproject.com/en/6.1/releases/6.1/> |
| django-ninja | 1.7.0 | 2026-08-30 — Django 6.1 명시 지원, Django 상한 제거, Python 3.14 호환 | <https://pypi.org/project/django-ninja/> |
| pydantic | 2.13.5 | 2026-08-28 | <https://github.com/pydantic/pydantic/releases> |
| psycopg (psycopg[binary], psycopg-binary, psycopg[pool]) | 3.3.5 | 2026-08-31 — Python 3.10–3.14, PostgreSQL 10–18, cp313 manylinux_2_28 aarch64 wheel 있음 | <https://pypi.org/project/psycopg/> |
| Celery | 5.6.3 | 2026-03-26 — Python 3.9–3.14, celery[redis]/celery[django] extras | <https://pypi.org/project/celery/> |
| redis-py | 8.1.0 | 2026-07-30 — RESP3 기본, redis[hiredis] | <https://pypi.org/project/redis/> |
| confluent-kafka (Kafka producer) | 2.15.0 | 2026-06-30 — confluent_kafka-2.15.0-cp313-cp313-manylinux_2_28_aarch64.whl 제공 | <https://pypi.org/project/confluent-kafka/> |
| aiokafka (대안, async 전용) | 0.14.0 | 2026-04-29 | <https://pypi.org/project/aiokafka/> |
| kafka-python-ng (제외) | 2.2.3 | 2024-10-28 — 2025-07-11 저장소 archived, Python 3.13 테스트 중단 | <https://github.com/kafka-python-ng/kafka-python-ng/releases> |
| cloudevents (Python SDK) | 2.2.0 | 2026-06-11 — Python 3.10+, 2.x core API(cloudevents.core.*), Kafka 바인딩 포함 | <https://pypi.org/project/cloudevents/> |
| PyJWT | 2.13.0 | 2026-05-21 — JWKS 캐시/스킴 취약점 5건 수정(CVE-2026-48522/48524 포함) | <https://pypi.org/project/PyJWT/> |
| joserfc (대안) | 1.7.5 | 2026-08-29 — JWKS HTTP 클라이언트 없음 | <https://pypi.org/project/joserfc/> |
| structlog | 26.1.0 | 2026-06-06 | <https://pypi.org/project/structlog/> |
| django-structlog | 10.1.0 | 2026-05-30 — classifier 는 Django 5.2 까지 | <https://pypi.org/project/django-structlog/> |
| opentelemetry-sdk / opentelemetry-exporter-otlp-proto-grpc | 1.44.0 | 2026-07-16 — Python 3.10–3.14 | <https://pypi.org/project/opentelemetry-exporter-otlp-proto-grpc/> |
| opentelemetry-instrumentation-django | 0.65b0 | 2026-07-16 — instruments django>=2.0, SDK 1.44 짝 | <https://pypi.org/project/opentelemetry-instrumentation-django/> |
| sentry-sdk | 2.68.1 | 2026-08-24 — Django 1.8+ 지원 | <https://pypi.org/project/sentry-sdk/> |
| django-health-check | 4.5.1 | 2026-08-21 — Django 5.2/6.0/6.1, extras celery/kafka/redis | <https://pypi.org/project/django-health-check/> |
| pytest-django | 4.14.0 | 2026-08-10 — Django 5.2/6.0/6.1(main), pytest>=7 | <https://pypi.org/project/pytest-django/> |
| testcontainers (python) | 4.15.0 | 2026-07-24 — Python 3.14 지원(4.13.3+), PostgresContainer/KafkaContainer(with_kraft) | <https://github.com/testcontainers/testcontainers-python/releases> |
| uv | 0.12.8 | 2026-08-31 | <https://github.com/astral-sh/uv/releases> |
| uv Docker 이미지 | ghcr.io/astral-sh/uv:0.12.8-python3.13-trixie-slim (Debian trixie 만 문서화, bookworm 태그 미기재) | 문서 기준 2026-08 | <https://docs.astral.sh/uv/guides/integration/docker/> |
| copier | 9.17.2 | 2026-08-19 — Python 3.10+, 9.17.x 는 보안(샌드박스 탈출·경로 탈출) 패치 | <https://github.com/copier-org/copier/releases> |
| django-rls-tenants (참고, 미채택) | 1.3.0 | 2026-06-28 — Django 4.2–6.0, PG 15+ | <https://libraries.io/pypi/django-rls-tenants> |
| confluentinc/cp-kafka (testcontainers 용 이미지) | 8.0.0 | 2025-06-11 — amd64+arm64 멀티아치 확인 | <https://hub.docker.com/v2/repositories/confluentinc/cp-kafka/tags/8.0.0> |

### 결정

**DJANGO-D1. (1) Python 3.13 에서 Django 6.1·Ninja 1.7·psycopg 3·Celery 5.6·copier·uv 조합이 호환되는가**

- Decision: 전부 호환: Django 6.1(3.12–3.14), django-ninja 1.7.0(Django 6.1 명시), psycopg 3.3.5(3.10–3.14, PG 18), Celery 5.6.3(3.9–3.14), copier 9.17.2(3.10+), uv 0.12.8. 템플릿은 requires-python ">=3.13,<3.14" 로 고정하고 3.14 는 다음 사이클에서 검토
- Rationale: 각 패키지 PyPI/릴리스 노트가 3.13 을 명시. 3.14 는 Django 는 지원하나 django-rls 류·일부 계측이 아직 3.13 까지만 테스트
- Alternatives considered: Python 3.14 즉시 채택(부가 라이브러리 검증 부담) / Django 6.0 LTS 아님(6.0 은 2027-04 까지 보안 지원, 6.1 보다 이점 없음)
- Source: <https://docs.djangoproject.com/en/6.1/releases/6.1/>

**DJANGO-D2. (2-a) 요청마다 트랜잭션 + SET LOCAL app.tenant_id 강제 방식 — ATOMIC_REQUESTS 인가, 미들웨어인가**

- Decision: 전용 미들웨어(TenantContextMiddleware)가 직접 `transaction.atomic()` 을 열고 그 안에서 `SELECT set_config('app.tenant_id', %s, true)` 를 실행한 뒤 get_response 를 호출한다. ATOMIC_REQUESTS 는 사용하지 않는다
- Rationale: Django 문서: ATOMIC_REQUESTS 는 view 만 감싸고 middleware 와 템플릿 렌더링은 트랜잭션 밖에서 실행 → 미들웨어의 SET LOCAL 이 트랜잭션 밖이면 PostgreSQL 은 경고만 내고 무효. `SET` 은 bind 파라미터를 받지 못하므로 set_config(name, value, is_local=true) 가 SET LOCAL 의 파라미터화 가능한 등가물
- Alternatives considered: ATOMIC_REQUESTS=True + view 데코레이터에서 set_config(뷰마다 누락 위험) / 세션 레벨 set_config(false) + request_finished 정리(django-rls-tenants 방식; psycopg pool 재사용 시 누출 위험)
- Source: <https://docs.djangoproject.com/en/6.1/topics/db/transactions/>

**DJANGO-D3. (2-b) django-pgrls 류 라이브러리를 쓸 것인가**

- Decision: 자체 구현(미들웨어 + RunSQL 헬퍼 + check 명령). 라이브러리는 채택하지 않음
- Rationale: django-pgrls 라는 패키지는 확인되지 않음. 후보 django-rls-tenants 1.3.0 은 Django 6.0 까지·세션 레벨 GUC(set_config ..., false) 방식, kdpisda/django-rls 는 Django 6.0/PG 17 까지 테스트·Q 객체→정책 변환 등 우리 요구(테넌트 컬럼 1개 정책) 대비 과함. 두 쪽 모두 Django 6.1 미명시. pod 별 DB 분리 구조라 정책 수가 적어 수십 줄이면 충분
- Alternatives considered: django-rls-tenants(RLSProtectedModel, check_rls 명령 참고 가치는 있음) / django-rls(Meta.rls_policies, makemigrations 자동 생성)
- Source: <https://github.com/dvoraj75/django-rls-tenants>

**DJANGO-D4. (2-c) RLS 정책을 마이그레이션으로 만드는 헬퍼 관행**

- Decision: `core/db/rls.py` 에 `rls_policy(table, tenant_col)` 헬퍼: `migrations.RunSQL` 로 ENABLE + FORCE ROW LEVEL SECURITY + CREATE POLICY(USING/WITH CHECK, `NULLIF(current_setting('app.tenant_id', true), '')::uuid` fail-closed), reverse_sql 로 DROP POLICY/DISABLE. 모델 마이그레이션 뒤 별도 마이그레이션에서 호출. state_operations 불필요(Django 상태 변화 없음)
- Rationale: RunSQL 은 sql/reverse_sql 을 지원하고 PostgreSQL 에서는 다중 문장을 한 번에 실행. FORCE 가 없으면 테이블 owner 는 정책을 우회(PostgreSQL 문서). missing_ok=true + NULLIF 로 GUC 미설정 시 아무 행도 매치되지 않게(fail-closed)
- Alternatives considered: SeparateDatabaseAndState(불필요) / 라이브러리의 자동 생성 정책
- Source: <https://docs.djangoproject.com/en/6.1/ref/migration-operations/#runsql>

**DJANGO-D5. (2-d) app role 이 테이블 비소유일 때 마이그레이션을 owner role 로 돌리는 방법 — DATABASES 다중 alias?**

- Decision: 단일 alias `default` 를 유지하고 자격증명만 환경변수(ESO Secret)로 바꾼다: 런타임 Deployment 는 app role Secret, Argo CD PreSync 마이그레이션 Job 은 owner role Secret. `migrate --database=<alias>` 다중 alias 방식은 채택하지 않음
- Rationale: Django 문서: 같은 물리 DB 를 여러 alias 로 잡는 것은 비권장(객체가 alias 에 sticky). 다중 alias 로 하면 router.allow_migrate 로 default 를 막고 django_migrations 기록 위치까지 관리해야 함. env 스위치는 코드 변경 0, CNPG 가 owner 와 app 사용자 Secret 을 각각 제공하므로 자연스러움
- Alternatives considered: DATABASES['migrate'] alias + `migrate --database=migrate` + router / app role 에 소유권 부여(FORCE 필수, 권한 분리 약화)
- Source: <https://docs.djangoproject.com/en/6.1/topics/db/multi-db/>

**DJANGO-D6. (3-a) outbox 릴레이의 SKIP LOCKED 를 Django ORM 으로**

- Decision: `OutboxEvent.objects.filter(published_at__isnull=True).order_by('id').select_for_update(skip_locked=True, of=('self',))[:N]` 를 `transaction.atomic()` 안에서 실행 → produce → flush → published_at 갱신. 전용 management command(`relay_outbox`) 를 별도 Deployment(replica 1, 필요시 N) 로 폴링 실행
- Rationale: Django 는 PostgreSQL 에서 nowait/skip_locked/of/no_key 모두 지원, 단 autocommit 에서는 TransactionManagementError. skip_locked 덕분에 릴레이 인스턴스가 여러 개여도 중복 없이 분산. Celery beat 로 돌리면 스케줄 지연·beat 단일화 문제
- Alternatives considered: Celery beat 주기 태스크 / PG LISTEN·NOTIFY 트리거(복잡) / Debezium(리소스 과다, 2 노드에 부적합)
- Source: <https://docs.djangoproject.com/en/6.1/ref/models/querysets/#select-for-update>

**DJANGO-D7. (3-b) Kafka producer 라이브러리**

- Decision: confluent-kafka 2.15.0 (librdkafka 번들, cp313 manylinux_2_28 aarch64 wheel). SASL_SSL + SCRAM-SHA-512 로 Strimzi KafkaUser 자격증명 사용, enable.idempotence=true, acks=all
- Rationale: 동기 릴레이 루프·Celery 워커 모두 sync 이므로 librdkafka 기반이 가장 검증됨. aiokafka 0.14.0 은 async 전용(sync Django 에서는 이벤트루프 관리 부담), kafka-python-ng 는 2025-07 archived 이고 3.13 테스트 중단
- Alternatives considered: aiokafka(ASGI 전환 시 재검토) / kafka-python-ng(제외)
- Source: <https://pypi.org/project/confluent-kafka/>

**DJANGO-D8. (3-c) CloudEvents 직렬화**

- Decision: cloudevents 2.2.0 의 `cloudevents.core.v1.event.CloudEvent` + `cloudevents.core.bindings.kafka.to_structured_event(event, key_mapper=...)`. 구조화 모드(value = JSONFormat bytes, content-type application/cloudevents+json), partitionkey 확장 속성 → Kafka key. outbox 행에는 id/type/source/subject/time/data 를 컬럼으로 저장
- Rationale: 2.x 는 1.x 의 cloudevents.http·pydantic 통합을 제거하고 Format 프로토콜(JSONFormat.write → bytes)로 명시화. Kafka 바인딩이 내장돼 헤더/키 매핑을 직접 구현할 필요 없음. 구조화 모드는 소비자 언어가 달라도 파싱이 단순
- Alternatives considered: binary 모드(헤더에 ce_* 속성) / 자체 JSON 스키마
- Source: <https://github.com/cloudevents/sdk-python/blob/main/MIGRATION.md>

**DJANGO-D9. (4-a) JWKS 캐시 검증 라이브러리 — PyJWT vs joserfc**

- Decision: PyJWT[crypto] >=2.13.0 의 `PyJWKClient(uri, cache_jwk_set=True, lifespan=3600)` + `jwt.decode(..., audience, issuer, algorithms=['RS256'], options={'require':[...]})`. Authentik 은 `https://auth.joshuatech.dev/application/o/<slug>/jwks/`, issuer 는 per-provider `https://auth.joshuatech.dev/application/o/<slug>/`
- Rationale: PyJWKClient 가 JWKS fetch·kid 매칭·2단 캐시를 내장. 2.13.0 에서 fetch 실패 시 캐시 삭제·스킴 미검증 등 취약점 수정 → 하한 고정. joserfc 1.7.5 는 JWKS HTTP 클라이언트가 없어 functools.cache 등으로 직접 구현해야 함
- Alternatives considered: joserfc + 자체 캐시(JWE 필요 시 재검토) / authlib
- Source: <https://pyjwt.readthedocs.io/en/stable/usage.html>

**DJANGO-D10. (4-b) Cloudflare Access JWT(Service Auth) 검증**

- Decision: `Cf-Access-Jwt-Assertion` 헤더의 JWT 를 같은 PyJWKClient 로 `https://<team>.cloudflareaccess.com/cdn-cgi/access/certs` 에서 검증(aud = Access 애플리케이션 AUD 태그, iss = `https://<team>.cloudflareaccess.com`, exp 필수). 서비스 토큰은 sub 가 빈 문자열이고 `common_name`(= CF-Access-Client-Id) 로 호출자를 식별 → Ninja 의 커스텀 auth callable 로 구현(HttpBearer 는 Authorization 헤더 전용)
- Rationale: Cloudflare 문서: 헤더 전달이 권장, 쿠키(CF_Authorization)는 보장되지 않음; certs 엔드포인트가 keys(JWK) 배열을 주므로 PyJWKClient 와 호환. 키는 6주마다 회전, 이전 키 7일 유효
- Alternatives considered: public_certs PEM 을 직접 파싱(Cloudflare 예제) / 검증 생략(Cloudflare IP 제한만 의존 — 금지)
- Source: <https://developers.cloudflare.com/cloudflare-one/identity/authorization-cookie/validating-json/>

**DJANGO-D11. (4-c) Dragonfly 접근 클라이언트**

- Decision: redis-py 8.1.0(redis[hiredis]) 단일 클라이언트: 세션/캐시 조회, Django CACHES(django.core.cache.backends.redis.RedisCache), Celery broker/result 모두 Dragonfly 로. 새 코드는 `legacy_responses=False`
- Rationale: Dragonfly 는 RESP2/RESP3 네이티브라 redis-py 그대로 동작; Dragonfly 공식 블로그가 Celery broker/result 조합을 안내. RESP3 이 8.x 기본이며 Lua 스크립트·모듈 의존 코드는 피해야 함
- Alternatives considered: django-redis(현재 Django 내장 RedisCache 로 충분) / valkey-py
- Source: <https://pypi.org/project/redis/>

**DJANGO-D12. (5-a) 구조화 로그 + request_id**

- Decision: structlog 26.1.0 + django-structlog 10.1.0 `RequestMiddleware`(X-Request-ID 헤더가 있으면 그대로 request_id, 없으면 생성) → JSONRenderer 로 stdout → Alloy 가 pod 로그 수집. Celery 는 `DJANGO_STRUCTLOG_CELERY_ENABLED=True`
- Rationale: 미들웨어 하나로 request_id/user_id 컨텍스트 바인딩·request_started/finished 이벤트를 제공. Cloudflare/Traefik 이 넘기는 X-Request-ID 와 이어짐
- Alternatives considered: 자체 request_id 미들웨어 + structlog contextvars(django-structlog 의 Django 6.1 지원이 문제되면 폴백)
- Source: <https://django-structlog.readthedocs.io/en/latest/getting_started.html>

**DJANGO-D13. (5-b) 트레이싱**

- Decision: opentelemetry-instrumentation-django 0.65b0 + sdk/otlp-proto-grpc 1.44.0. wsgi/asgi 진입점에서 `DjangoInstrumentor().instrument(response_hook=...)`, OTLP gRPC → Alloy(OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability:4317), `OTEL_PYTHON_DJANGO_EXCLUDED_URLS=healthz,ht/.*`, tenant/user 속성은 response_hook 에서
- Rationale: Django 계측은 미들웨어보다 먼저 span 을 만들므로 request.user/tenant 는 response_hook 에서만 접근 가능(공식 문서). 0.65b0 은 SDK 1.44.0 과 같은 날 릴리스된 짝
- Alternatives considered: opentelemetry-instrument 자동 계측 CLI(entrypoint 가 바뀌어 gunicorn 과 조합이 번거로움)
- Source: <https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/django/django.html>

**DJANGO-D14. (5-c) Sentry**

- Decision: sentry-sdk[django] 2.68.1, `DjangoIntegration(transaction_style='url')`, traces_sample_rate=0(트레이싱은 OTel), send_default_pii=False, release = 이미지 digest, environment = dev/prod. enable_logs 는 끔(구조화 로그는 Alloy→Grafana)
- Rationale: Free 플랜 쿼터 절약, 관측 경로 중복 방지. Django 통합은 Django 1.8+ 전 버전 지원
- Alternatives considered: Sentry tracing 병행(쿼터 초과 위험)
- Source: <https://docs.sentry.io/platforms/python/integrations/django/>

**DJANGO-D15. (5-d) /health, /ready 관행**

- Decision: liveness `/healthz` = 의존성 없는 200 응답(자체 view), readiness `/ht/` = django-health-check 4.5.1(DB·cache(Dragonfly)·필요 시 kafka extra) `?format=json`, 200/500. 두 URL 모두 OTel 제외·Cloudflare Access 예외 없음(내부 probe 는 kubelet 이 pod IP 로 직접 호출)
- Rationale: 4.5.1 이 Django 6.1 을 명시 지원하고 JSON/OpenMetrics/CLI(`health_check --no-http`, exec probe 용) 제공. liveness 에 DB 체크를 넣으면 DB 장애 시 pod 재시작 폭풍
- Alternatives considered: 자체 두 view 만(라이브러리 없이) / 라이브러리를 liveness 에도 사용(금지)
- Source: <https://codingjoe.dev/django-health-check/usage/>

**DJANGO-D16. (6) 테스트 스택**

- Decision: pytest-django 4.14.0 + testcontainers[postgres,kafka] 4.15.0. conftest 에서 세션 스코프 PostgresContainer('postgres:18', driver=None) 와 KafkaContainer('confluentinc/cp-kafka:8.0.0').with_kraft() 를 띄우고 `django_db_modify_db_settings` 를 오버라이드. RLS 테스트는 비-superuser app role 을 만들어 그 자격증명으로, outbox 동시성 테스트는 transactional_db
- Rationale: Docker 필요: GitHub ubuntu-24.04-arm 러너와 로컬 Docker Desktop 에서만 실행(K8s 안에서는 불가). PostgresContainer 의 driver 기본값은 psycopg2 접두사이므로 driver=None. cp-kafka 8.0.0 은 amd64/arm64 멀티아치 확인, testcontainers 기본 7.6.0 은 오래됨
- Alternatives considered: pytest-postgresql(로컬 바이너리 필요) / Redpanda 컨테이너(Strimzi 와 동작 차이) / CI 서비스 컨테이너(services:)
- Source: <https://pytest-django.readthedocs.io/en/latest/database.html>

**DJANGO-D17. (7) uv Docker 멀티스테이지 arm64 이미지**

- Decision: builder = `ghcr.io/astral-sh/uv:0.12.8-python3.13-trixie-slim`, runtime = `python:3.13-slim-trixie`(동일 Python). UV_COMPILE_BYTECODE=1, UV_LINK_MODE=copy, cache mount, `uv sync --locked --no-install-project --no-dev` → 소스 복사 → `uv sync --locked --no-dev`, `.venv` 만 복사, non-root. psycopg[binary] 로 빌드 도구 불필요
- Rationale: uv 문서의 권장 패턴. 문서의 Debian 파생 태그는 trixie 만 나열(bookworm 태그 미기재). manylinux_2_28 wheel(psycopg-binary, confluent-kafka)은 glibc 2.28+ 필요 → trixie OK, Alpine(musl) 은 confluent-kafka 미확인. 태그는 uv 버전까지 고정하고 SHA 핀 권장
- Alternatives considered: psycopg[c] 빌드(문서상 production 권장이나 libpq-dev·gcc 필요, 이미지 2단계 빌드 복잡) / distroless uv 이미지 + COPY --from 으로 uv 만 가져오기
- Source: <https://docs.astral.sh/uv/guides/integration/docker/>

**DJANGO-D18. (8) copier 템플릿 구조·업데이트**

- Decision: 저장소 `pod-template`: 루트 `copier.yml` + `_subdirectory: template`, `_templates_suffix: .jinja`(기본), 디렉터리명 `{{ python_package }}`, `_min_copier_version: "9.17"`, `_skip_if_exists` 로 로컬 설정 보호, `_tasks: [["uv","lock"]]`. 템플릿은 git tag(semver v0.x.y)로 버전 관리. 생성 `copier copy --trust gh:<org>/pod-template ./<pod>`, 갱신 `copier update --trust --skip-answered`(사전 `copier check-update`), 충돌은 기본 inline 마커
- Rationale: copier update 는 .copier-answers.yml + 템플릿 git tag + 클린 워킹트리를 요구하고 PEP 440 로 최신 태그를 고름. _tasks/_migrations 가 있으면 --trust 필수. 9.15+ 는 Jinja StrictUndefined 지원, 9.17.x 는 보안 패치이므로 하한 고정
- Alternatives considered: cookiecutter(업데이트 기능 없음) / cruft(cookiecutter 기반)
- Source: <https://copier.readthedocs.io/en/stable/updating/>

### 설정 스니펫

**pyproject.toml (uv) — 핀 하한** — <https://pypi.org/project/django-ninja/>
```
[project]
name = "{{ python_package }}"
requires-python = ">=3.13,<3.14"
dependencies = [
  "django>=6.1,<6.2",
  "django-ninja>=1.7,<2",
  "pydantic>=2.13,<3",
  "psycopg[binary,pool]>=3.3.5,<4",
  "celery[redis]>=5.6.3,<6",
  "redis[hiredis]>=8.1,<9",
  "confluent-kafka>=2.15,<3",
  "cloudevents>=2.2,<3",
  "PyJWT[crypto]>=2.13,<3",
  "structlog>=26.1", "django-structlog>=10.1",
  "opentelemetry-sdk>=1.44,<2", "opentelemetry-exporter-otlp-proto-grpc>=1.44,<2",
  "opentelemetry-instrumentation-django>=0.65b0",
  "sentry-sdk[django]>=2.68",
  "django-health-check[redis]>=4.5.1",
  "gunicorn>=23",
]
[dependency-groups]
dev = ["pytest-django>=4.14", "testcontainers[postgres,kafka]>=4.15", "copier>=9.17", "ruff", "mypy"]
```

**settings.py — DATABASES (단일 alias, env 로 role 전환, psycopg pool)** — <https://docs.djangoproject.com/en/6.1/ref/databases/#postgresql-notes>
```
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": env("DB_HOST"), "NAME": env("DB_NAME"),
        "USER": env("DB_USER"), "PASSWORD": env("DB_PASSWORD"),  # Deployment: app role Secret / migrate Job: owner Secret (ESO)
        "CONN_MAX_AGE": 0,                     # pool 사용 시 persistent connection 금지
        "OPTIONS": {
            "pool": {"min_size": 1, "max_size": 4},  # psycopg[pool] 필요
            "sslmode": "require",
            "application_name": env("OTEL_SERVICE_NAME"),
        },
    }
}
# ATOMIC_REQUESTS 는 켜지 않는다(뷰만 감싸므로 미들웨어의 set_config 가 트랜잭션 밖이 됨)
```

**core/middleware/tenant.py — 요청 트랜잭션 + SET LOCAL 등가(set_config)** — <https://www.postgresql.org/docs/current/functions-admin.html>
```
from django.db import connection, transaction

class TenantContextMiddleware:
    """JWT 검증 미들웨어/auth 가 request.tenant_id 를 채운 뒤에 위치시킬 것."""
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        tenant_id = getattr(request, "tenant_id", None)
        with transaction.atomic():                       # 요청 전체를 한 트랜잭션으로
            with connection.cursor() as cur:
                # SET LOCAL 은 bind 파라미터 불가 -> set_config(..., is_local=true)
                cur.execute("SELECT set_config('app.tenant_id', %s, true)", [str(tenant_id) if tenant_id else ""])
            return self.get_response(request)         # 예외 시 rollback, StreamingHttpResponse 금지
```

**core/db/rls.py — RunSQL 정책 헬퍼 + 마이그레이션 사용** — <https://www.postgresql.org/docs/current/ddl-rowsecurity.html>
```
from django.db import migrations

def rls_policy(table: str, tenant_col: str = "tenant_id", cast: str = "uuid") -> migrations.RunSQL:
    guc = "NULLIF(current_setting('app.tenant_id', true), '')::" + cast   # 미설정 -> NULL -> 0행 (fail-closed)
    return migrations.RunSQL(
        sql=f"""
        ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;
        ALTER TABLE {table} FORCE ROW LEVEL SECURITY;          -- owner 도 정책 적용
        CREATE POLICY tenant_isolation ON {table}
            USING ({tenant_col} = {guc})
            WITH CHECK ({tenant_col} = {guc});
        """,
        reverse_sql=f"""
        DROP POLICY IF EXISTS tenant_isolation ON {table};
        ALTER TABLE {table} NO FORCE ROW LEVEL SECURITY;
        ALTER TABLE {table} DISABLE ROW LEVEL SECURITY;
        """,
    )

# orders/migrations/0002_rls.py
# operations = [rls_policy("orders_order"), rls_policy("orders_orderline")]
# 실행: migrate Job 이 owner role 로 실행(DB_USER=owner). app role 에는 BYPASSRLS 를 절대 주지 않음.
```

**outbox/relay.py — SKIP LOCKED 릴레이 + confluent-kafka + CloudEvents 구조화** — <https://github.com/cloudevents/sdk-python/blob/main/src/cloudevents/core/bindings/kafka.py>
```
from cloudevents.core.v1.event import CloudEvent
from cloudevents.core.bindings.kafka import to_structured_event
from confluent_kafka import Producer
from django.db import transaction
from django.db.models.functions import Now

producer = Producer({
    "bootstrap.servers": env("KAFKA_BOOTSTRAP"),          # <cluster>-kafka-bootstrap.kafka:9093
    "security.protocol": "SASL_SSL",
    "sasl.mechanisms": "SCRAM-SHA-512",                    # Strimzi KafkaUser(scram-sha-512)
    "sasl.username": env("KAFKA_USER"), "sasl.password": env("KAFKA_PASSWORD"),
    "ssl.ca.location": "/etc/kafka/ca.crt",               # <cluster>-cluster-ca-cert Secret 마운트
    "enable.idempotence": True, "acks": "all", "linger.ms": 5, "compression.type": "zstd",
    "client.id": f"{env('OTEL_SERVICE_NAME')}-outbox",
})

def relay_batch(batch: int = 100) -> int:
    with transaction.atomic():
        rows = list(
            OutboxEvent.objects.filter(published_at__isnull=True)
            .order_by("id").select_for_update(skip_locked=True, of=("self",))[:batch]
        )
        for r in rows:
            ev = CloudEvent({"id": str(r.id), "type": r.type, "source": r.source, "subject": r.subject,
                             "time": r.created_at, "partitionkey": str(r.tenant_id),
                             "datacontenttype": "application/json"}, r.payload)
            msg = to_structured_event(ev)                    # value=JSONFormat bytes, headers content-type=application/cloudevents+json
            producer.produce(r.topic, key=msg.key, value=msg.value, headers=list(msg.headers.items()))
        producer.flush(10)                                   # 실패 시 예외 -> rollback -> 재시도
        OutboxEvent.objects.filter(id__in=[r.id for r in rows]).update(published_at=Now())
    return len(rows)
# manage.py relay_outbox: while True: n = relay_batch(); sleep(0.2 if n else 1.0)
```

**auth.py — PyJWKClient(Authentik + Cloudflare Access) → Ninja auth** — <https://developers.cloudflare.com/cloudflare-one/identity/authorization-cookie/application-token/>
```
import jwt
from jwt import PyJWKClient
from ninja import NinjaAPI
from ninja.security import HttpBearer

AUTHENTIK_ISS = f"https://auth.joshuatech.dev/application/o/{settings.AK_SLUG}/"
ak_jwks = PyJWKClient(AUTHENTIK_ISS + "jwks/", cache_jwk_set=True, lifespan=3600, timeout=5)
cf_jwks = PyJWKClient(f"https://{settings.CF_TEAM}.cloudflareaccess.com/cdn-cgi/access/certs",
                      cache_jwk_set=True, lifespan=3600, timeout=5)   # 키 6주 회전, 이전 키 7일 유효

class AuthentikBearer(HttpBearer):
    def authenticate(self, request, token):
        key = ak_jwks.get_signing_key_from_jwt(token)
        claims = jwt.decode(token, key, algorithms=["RS256"], audience=settings.AK_AUD, issuer=AUTHENTIK_ISS,
                            options={"require": ["exp", "iat", "aud", "iss", "sub"]}, leeway=5)
        request.tenant_id = claims.get("tenant_id")
        return claims

def cf_access_auth(request):                      # Service Auth 토큰 (pod API)
    tok = request.headers.get("Cf-Access-Jwt-Assertion")
    if not tok:
        return None
    key = cf_jwks.get_signing_key_from_jwt(tok)
    claims = jwt.decode(tok, key, algorithms=["RS256"], audience=settings.CF_ACCESS_AUD,
                        issuer=f"https://{settings.CF_TEAM}.cloudflareaccess.com",
                        options={"require": ["exp", "iat", "aud", "iss"]}, leeway=5)
    return claims.get("common_name") or claims.get("email")   # 서비스 토큰: sub="" , common_name=Client ID

api = NinjaAPI(auth=[cf_access_auth, AuthentikBearer()])   # 둘 중 하나 통과
```

**settings.py — structlog JSON + django-structlog RequestMiddleware** — <https://django-structlog.readthedocs.io/en/latest/getting_started.html>
```
INSTALLED_APPS += ["django_structlog"]
MIDDLEWARE = ["django_structlog.middlewares.RequestMiddleware", ...]   # X-Request-ID 있으면 재사용, 없으면 생성
DJANGO_STRUCTLOG_CELERY_ENABLED = True
LOGGING = {
    "version": 1, "disable_existing_loggers": False,
    "formatters": {"json": {"()": structlog.stdlib.ProcessorFormatter, "processor": structlog.processors.JSONRenderer()}},
    "handlers": {"console": {"class": "logging.StreamHandler", "formatter": "json"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
structlog.configure(
    processors=[structlog.contextvars.merge_contextvars, structlog.stdlib.add_logger_name,
                structlog.stdlib.add_log_level, structlog.processors.TimeStamper(fmt="iso"),
                structlog.processors.format_exc_info, structlog.stdlib.ProcessorFormatter.wrap_for_formatter],
    logger_factory=structlog.stdlib.LoggerFactory(), cache_logger_on_first_use=True,
)
```

**config/wsgi.py 상단 — OTel + Sentry 초기화** — <https://opentelemetry-python-contrib.readthedocs.io/en/latest/instrumentation/django/django.html>
```
import os, sentry_sdk
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.django import DjangoInstrumentor
from sentry_sdk.integrations.django import DjangoIntegration

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": os.environ["OTEL_SERVICE_NAME"]})))
trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))  # OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.observability:4317

def _resp_hook(span, request, response):            # 미들웨어 이후에만 tenant/user 접근 가능
    if tid := getattr(request, "tenant_id", None):
        span.set_attribute("app.tenant_id", str(tid))
DjangoInstrumentor().instrument(response_hook=_resp_hook)   # OTEL_PYTHON_DJANGO_EXCLUDED_URLS="healthz,ht/.*"

sentry_sdk.init(dsn=os.environ.get("SENTRY_DSN", ""), integrations=[DjangoIntegration(transaction_style="url")],
                traces_sample_rate=0.0, send_default_pii=False,
                environment=os.environ.get("APP_ENV", "dev"), release=os.environ.get("IMAGE_DIGEST"))

from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
```

**urls.py — liveness/readiness** — <https://codingjoe.dev/django-health-check/install/>
```
from django.http import HttpResponse
from django.urls import path
from health_check.views import HealthCheckView          # 4.x: 체크 목록을 view 에 명시 (정확한 kwargs 는 install 문서 확인)
import health_check

urlpatterns = [
    path("healthz", lambda r: HttpResponse("ok")),      # livenessProbe: 의존성 없음
    path("ht/", HealthCheckView.as_view(checks=[health_check.Database(), health_check.Cache()]),
         name="health_check"),                          # readinessProbe: GET /ht/?format=json -> 200/500
]
# Deployment: livenessProbe httpGet /healthz ; readinessProbe httpGet /ht/?format=json ; startupProbe 동일 URL, failureThreshold 30
```

**tests/conftest.py + pytest.ini — testcontainers Postgres/Kafka** — <https://pytest-django.readthedocs.io/en/latest/database.html>
```
# pytest.ini
# [pytest]
# DJANGO_SETTINGS_MODULE = config.settings.test
# addopts = --reuse-db

import pytest
from testcontainers.postgres import PostgresContainer
from testcontainers.kafka import KafkaContainer

@pytest.fixture(scope="session")
def pg():
    with PostgresContainer("postgres:18", driver=None) as c:   # driver 기본값은 psycopg2 접두사
        yield c

@pytest.fixture(scope="session")
def django_db_modify_db_settings(pg):                       # pytest-django 훅 오버라이드
    from django.conf import settings
    settings.DATABASES["default"].update(
        HOST=pg.get_container_host_ip(), PORT=int(pg.get_exposed_port(5432)),
        NAME=pg.dbname, USER=pg.username, PASSWORD=pg.password,
    )

@pytest.fixture(scope="session")
def kafka_bootstrap():
    with KafkaContainer("confluentinc/cp-kafka:8.0.0").with_kraft() as k:   # 8.0 은 KRaft 전용, arm64 이미지 있음
        yield k.get_bootstrap_server()

# RLS 테스트: 컨테이너 사용자는 superuser(RLS 우회) -> 마이그레이션 후 `CREATE ROLE app LOGIN ...; GRANT ...` 하고
# app 자격증명으로 재접속하거나 `SET ROLE app` 후 검증. outbox 동시성 테스트는 @pytest.mark.django_db(transaction=True).
```

**Dockerfile — uv 멀티스테이지 arm64** — <https://docs.astral.sh/uv/guides/integration/docker/>
```
# syntax=docker/dockerfile:1
FROM ghcr.io/astral-sh/uv:0.12.8-python3.13-trixie-slim AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=0
WORKDIR /app
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv uv sync --locked --no-dev

FROM python:3.13-slim-trixie
RUN useradd -r -u 10001 -d /app app
COPY --from=builder --chown=app:app /app /app
ENV PATH="/app/.venv/bin:$PATH" PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1
USER app
WORKDIR /app
EXPOSE 8000
CMD ["gunicorn", "config.wsgi", "-b", "0.0.0.0:8000", "-k", "gthread", "--threads", "4", "--workers", "2"]
# CI(ubuntu-24.04-arm): docker buildx build --platform linux/arm64 --provenance=true --sbom=true -t ghcr.io/<org>/<pod>:<sha> .
```

**pod-template/copier.yml + 레이아웃** — <https://copier.readthedocs.io/en/stable/configuring/>
```
# pod-template/
#   copier.yml
#   template/
#     pyproject.toml.jinja  Dockerfile  .github/workflows/ci.yml.jinja
#     config/settings/{base,test}.py.jinja  {{ python_package }}/__init__.py
#     core/{middleware/tenant.py,db/rls.py,auth.py}  outbox/  tests/conftest.py.jinja
_min_copier_version: "9.17"
_subdirectory: template
_templates_suffix: .jinja
_answers_file: .copier-answers.yml
_skip_if_exists: ["README.md", "config/settings/local.py"]
_tasks:
  - ["uv", "lock"]            # --trust 필요

project_slug:
  type: str
  help: pod 이름 (kebab-case, 이미지/네임스페이스 이름)
  validator: "{% if not project_slug | regex_search('^[a-z][a-z0-9-]{2,30}$') %}kebab-case 만 허용{% endif %}"
python_package:
  type: str
  default: "{{ project_slug | replace('-', '_') }}"
needs_kafka:  {type: bool, default: true}
needs_celery: {type: bool, default: false}

# 사용: copier copy --trust gh:<org>/pod-template ./svc-foo
# 갱신: copier check-update && copier update --trust --skip-answered   (템플릿은 git tag vX.Y.Z 로 버전)
```

### 함정

- ATOMIC_REQUESTS 는 view 실행만 감싼다 — 미들웨어·템플릿 렌더링은 트랜잭션 밖. 미들웨어에서 SET LOCAL/set_config(...,true) 를 하려면 미들웨어가 직접 transaction.atomic() 을 열어야 한다. 트랜잭션 밖 SET LOCAL 은 PostgreSQL 이 경고만 내고 무효 → RLS 가 fail-closed 면 모든 조회가 0행(증상: 빈 응답).
- `SET LOCAL app.tenant_id = %s` 는 bind 파라미터를 받지 않는다(psycopg3 server_side_binding 을 켜면 즉시 오류). 항상 `SELECT set_config('app.tenant_id', %s, true)` 를 쓴다.
- Django psycopg pool(OPTIONS.pool) 은 연결을 재사용하므로 세션 레벨 set_config(..., false) 나 SET 은 다음 요청으로 누출된다(django-rls-tenants 가 이 방식 + request_finished 정리). is_local=true 만 허용. ASGI 에서는 CONN_MAX_AGE 를 0 으로.
- 테이블 owner·superuser·BYPASSRLS 역할은 RLS 를 우회한다. FORCE ROW LEVEL SECURITY 를 항상 같이 걸고, CNPG 가 만드는 app 사용자에게 BYPASSRLS 를 주지 않으며, 마이그레이션은 owner 로만. testcontainers 의 기본 postgres 사용자도 superuser 라 RLS 테스트가 헛되이 통과한다 → 비-superuser 역할로 검증.
- StreamingHttpResponse 본문은 미들웨어의 atomic 블록이 닫힌 뒤 생성된다 → tenant GUC 없이 DB 를 읽게 된다. 스트리밍 뷰에서는 DB 접근 금지 또는 사전 materialize.
- select_for_update 는 autocommit 에서 TransactionManagementError. pytest-django `db` fixture 는 테스트 전체를 트랜잭션으로 감싸므로 skip_locked 동시성은 관찰되지 않는다 → transactional_db / django_db(transaction=True). nowait 와 skip_locked 는 상호 배타.
- 같은 물리 DB 를 두 alias 로 잡는 것은 Django 문서가 비권장(객체가 alias 에 sticky) — owner/app 전환은 alias 가 아니라 자격증명 env 로.
- Django 6.1 파괴 변경: QuerySet.first()/last() 가 ordering 을 지웠을 때 더 이상 pk 로 자동 정렬하지 않음(outbox 폴링은 order_by('id') 명시), 서명 쿠키 salt 파생 변경(SIGNED_COOKIE_LEGACY_SALT_FALLBACK), 엄격한 Base64 검증, EMAIL_BACKEND → MAILERS 로 deprecated, PostgreSQL 14 지원 종료(15+; PG 18 OK).
- PyJWT 2.13.0 미만은 JWKS fetch 실패 시 캐시를 비우고(CVE-2026-48522) 미지 kid 마다 무제한 재요청(CVE-2026-48524)한다 — 하한 2.13.0 고정. get_signing_key_from_jwt 는 미지 kid 면 재fetch 하므로 lifespan 을 1시간 이하로 두되 오류 시 폴백을 의존하지 말 것.
- Cloudflare Access 서비스 토큰 JWT 는 sub 가 빈 문자열이고 email 이 없다 — common_name(Client ID) 로 식별. 쿠키 CF_Authorization 전달은 보장되지 않으므로 Cf-Access-Jwt-Assertion 헤더만 본다. 서명 키는 6주마다 회전(이전 키 7일 유효).
- confluent-kafka·psycopg-binary 의 aarch64 wheel 은 manylinux_2_28(glibc ≥ 2.28) — Debian trixie OK, Alpine(musl) 은 confluent-kafka wheel 이 없어 librdkafka 빌드가 필요. uv 문서의 Debian 파생 태그는 trixie 만 나열되므로 bookworm 을 가정하지 말 것.
- kafka-python-ng 는 2025-07-11 archived 이고 Python 3.13 테스트를 중단했다. aiokafka 0.14.0 은 async 전용이라 sync Django/Celery 릴레이에는 부적합.
- cloudevents 2.x 는 1.x 의 cloudevents.http / to_json·from_json / pydantic 통합을 제거했다(MIGRATION.md). 블로그 예제의 1.x API 를 그대로 옮기면 ImportError. JSONFormat.write 는 bytes 를 반환하고 datetime 은 RFC 3339 'Z' 로 직렬화.
- librdkafka 설정 키는 `sasl.mechanisms`(별칭 sasl.mechanism), `security.protocol=SASL_SSL`; Strimzi 내부 tls 리스너에 붙을 때 cluster CA(`<cluster>-cluster-ca-cert`) 를 ssl.ca.location 으로 마운트하지 않으면 handshake 실패. enable.idempotence=true 는 acks=all 을 강제.
- OpenTelemetry Django 계측은 미들웨어보다 먼저 span 을 만든다 → request.user/tenant 는 response_hook 에서만. instrumentation 0.65b0 은 SDK 1.44.0 과 짝(다른 minor 조합은 import 오류). /healthz, /ht/ 는 OTEL_PYTHON_DJANGO_EXCLUDED_URLS 로 제외하지 않으면 probe 가 트레이스를 오염.
- django-structlog 10.1.0 의 classifier 는 Django 5.2 까지(6.0/6.1 미명시), 9.0.0 부터 RequestMiddleware 가 got_request_exception 시그널에 의존 — 예외 로깅 순서가 미들웨어 위치와 무관. Sentry enable_logs 를 켜면 structlog→stdlib 로그가 Sentry 로도 전송돼 Free 쿼터를 소모.
- psycopg 문서는 production 에 psycopg[c](로컬 빌드) 를 권장하고 [binary] 는 편의용. binary 를 쓰면 libpq 보안 패치가 이미지 재빌드(Renovate 로 psycopg-binary 갱신)에 의존한다.
- testcontainers KafkaContainer 기본 이미지는 confluentinc/cp-kafka:7.6.0(2024) 이며 with_kraft() 를 호출하지 않으면 ZooKeeper 모드; cp-kafka 8.x 는 ZooKeeper 가 없으므로 with_kraft() 필수. PostgresContainer(driver 기본 'psycopg2') 는 URL 에 psycopg2 접두사를 붙이므로 driver=None. testcontainers 는 Docker 소켓이 필요 — K8s pod 안(tester agent 포함) 에서는 실행 불가, ubuntu-24.04-arm 러너·로컬 Docker Desktop 에서만.
- copier: _tasks/_migrations 가 있으면 copy/update 에 --trust 필수, .copier-answers.yml 수동 편집 금지, 템플릿에 git tag 가 없으면 update 불가(--vcs-ref=HEAD 로 우회). 9.15+ StrictUndefined 를 켜면 미정의 변수가 즉시 오류 — 템플릿 CI 에서 활성화 권장.
- uv Dockerfile: 첫 sync 는 --no-install-project 로 의존성 레이어를 분리, --locked 는 lock 이 pyproject 와 불일치하면 실패(원하는 동작), UV_LINK_MODE=copy 가 없으면 cache mount 경고. runtime 이미지의 Python 은 builder(python3.13-trixie-slim = python:3.13-slim-trixie 기반)와 동일 버전이어야 .venv 가 동작.
- RunSQL 에 파라미터를 넘길 때는 SQL 의 리터럴 % 를 %% 로 이스케이프; 헬퍼처럼 f-string 으로 식별자를 넣으면 파라미터 없이 실행되므로 % 이스케이프는 불필요하지만 테이블명은 반드시 코드 상수(사용자 입력 금지).

### 미확인

- Django 6.1.1 이 2026-09-02 예정 — plan 확정 시점에 6.1.1 로 핀을 올릴지(from_db/fetch_mode 회귀 수정 포함) 확인.
- django-structlog 10.1.0 의 Django 6.1 동작은 classifier 로 확인되지 않음 — 템플릿 스모크 테스트에서 RequestMiddleware + Celery 통합을 실측하고, 문제 시 자체 request_id 미들웨어(structlog contextvars)로 폴백.
- Authentik 2026.8 access token 의 aud 값(기본 client_id 인지, provider 별 audience 를 어디서 설정하는지)과 RFC 8693 token exchange 의 audience/resource 파라미터는 문서에서 확인하지 못함 — 인증 주제(R-auth) 결과와 교차 확인 필요. tenant_id 클레임 이름·scope mapping 도 미확정.
- Cloudflare Access 가 cloudflared 터널이 아닌 proxied origin(Traefik) 경로에서도 Cf-Access-Jwt-Assertion 헤더를 주입하는지, 그리고 서비스 토큰 JWT 의 수명(기본 세션 기간) 은 문서에서 확인하지 못함 — Access self-hosted app + Authenticated Origin Pulls 조합으로 실측.
- django-health-check 4.x 의 HealthCheckView.as_view(checks=[...]) 정확한 kwargs 와 체크 클래스 모듈 경로(health_check.Database 등), kafka extra 의 브로커 설정 키는 install/usage 문서 본문에서 재확인 필요(요약만 확보).
- psycopg[binary] vs psycopg[c] 최종 선택 보류 — arm64 이미지에서 libpq-dev+gcc 빌드 스테이지 비용 vs 보안 패치 추적 부담 비교 후 결정.
- confluent-kafka 2.15.0 에 번들된 librdkafka 정확한 버전(2.15.0 으로 추정)과 free-threaded Python 미지원 여부의 영향 없음 확인.
- uv 이미지 bookworm 태그가 실제로 제거됐는지(문서에서만 사라짐) — trixie 사용 전제이므로 영향은 없으나 Renovate regex 에 반영.
- testcontainers KafkaContainer 가 cp-kafka 8.0.0 + with_kraft() 조합에서 정상 기동하는지(모듈은 MIN_KRAFT_TAG 7.0.0 만 검사) arm64 러너에서 실측 필요.
- Django psycopg pool 과 Celery prefork 워커의 fork 안전성(부모에서 pool 이 열린 채 fork 되면 연결 공유) — worker_process_init 에서 connections.close_all() 필요 여부 확인.
- gunicorn(gthread) vs uvicorn/ASGI 선택은 본 조사 범위 밖 — Ninja 는 sync 뷰 기준이며 async 전환 시 aiokafka·pool 설정을 재검토.
- PostgreSQL 18 에서 psycopg 3.3.5·CNPG 이미지 조합의 신규 기능(예: uuidv7 함수와 Django 6.1 UUID7 DB 함수) 사용 여부는 plan 에서 결정.


## R10 Alloy · Grafana Cloud · Sentry

R10 Alloy -> Grafana Cloud Free + Sentry (k8s-monitoring v4 차트, 시리즈 예산, OTLP 수신, 알림, Sentry Free, 토큰)

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| grafana/k8s-monitoring Helm 차트 (Kubernetes Monitoring) | 4.5.1 (v4 계열; v3 아님 — v4는 2026-04-13 출시) | 4.5.0 = 2026-08-25, 4.5.1 = main Chart.yaml | <https://github.com/grafana/k8s-monitoring-helm/releases> |
| alloy-operator (k8s-monitoring 4.5.1 의존성) | 0.7.1 (alloy-crd 1.0.1) | 2026-08-27 | <https://github.com/grafana/alloy-operator/releases> |
| Grafana Alloy | v1.19.2 | 2026-08-26 (v1.19.0 = 2026-08-24) | <https://github.com/grafana/alloy/releases> |
| K3s (번들 Traefik) | v1.36.3+k3s1 → Traefik v3.7.8, Traefik 차트 v40.x | 2026-08-04 | <https://docs.k3s.io/release-notes/v1.36.X> |
| sentry-sdk (Python) | 2.68.1 (extras: django, opentelemetry-otlp) | 2026-08-24 | <https://pypi.org/project/sentry-sdk/> |
| @sentry/nextjs (sentry-javascript) | 10.73.0 (11.0.0-alpha.2 프리릴리스 존재) | 2026-08-31 | <https://github.com/getsentry/sentry-javascript/releases> |
| terraform-provider-grafana (OpenTofu용) | v4.45.2 | 2026-08-25 | <https://github.com/grafana/terraform-provider-grafana/releases> |
| Grafana Cloud Free 한도 | 메트릭 10k active series / 로그 50 GB/월 / 트레이스 50 GB/월 / 프로파일 50 GB/월, 보존 14일, K8s Monitoring 2,232 host-hours + 37,944 container-hours/월, Grafana 3 active users, IRM 3 users | 2026-09-01 조회 | <https://grafana.com/pricing/> |
| Sentry Developer(Free) 플랜 | 5k errors / 5M spans / 50 replays / 5 GB logs / 1 cron / 1 uptime / 1 user / 30-day lookback / 1 GB attachments | 2026-09-01 조회 | <https://sentry.io/pricing/> |

### 결정

**OBSERVABILITY-D1. 어떤 차트/버전으로 Alloy를 배포하나?**

- Decision: grafana/k8s-monitoring 4.5.1 (v4 계열) 단일 릴리스 `k8s-monitoring`, 네임스페이스 `monitoring`. alloy-operator 0.7.1이 함께 설치되고 collectors 맵이 Alloy CR로 렌더링됨.
- Rationale: v4(2026-04)에서 값 스키마가 전면 개편됨(podLogs→podLogsViaLoki, destinations 리스트→맵, 고정 alloy-* 이름→사용자 정의 collectors+presets, telemetryServices 명시 배포). v3 예제는 더 이상 유효하지 않고 모든 공식 예제가 v4로 갱신됨.
- Alternatives considered: (a) grafana/alloy 차트 + 수작업 Alloy 설정 — 유연하나 kube-state-metrics/node-exporter/allowlist를 직접 관리해야 함. (b) OpenTelemetry Collector 차트 — Grafana Cloud K8s Monitoring 앱·사전 정의 알림과의 정합성 떨어짐.
- Source: <https://grafana.com/blog/kubernetes-monitoring-helm-chart-v4-biggest-update-ever-/>

**OBSERVABILITY-D2. 컬렉터 토폴로지(2노드, 노드 A platform / 노드 B data)는?**

- Decision: collectors 2개만: `alloy-metrics` presets [small, statefulset, singleton] (clusterMetrics·clusterEvents·annotationAutodiscovery·applicationObservability OTLP 수신 담당, 노드 A에 nodeSelector), `alloy-logs` presets [small, filesystem-log-reader, daemonset] (양 노드 Pod 로그). `clustered` 프리셋은 1 replica라 생략.
- Rationale: 차트 문서: 각 feature는 `collector:` 필드로 컬렉터를 지정하며 하나만 정의하면 자동 사용. 로그는 /var/log 마운트가 필요한 DaemonSet, 나머지는 단일 StatefulSet로 합쳐 pod 수·메모리를 최소화(리소스 프리셋 small = requests cpu 100m/mem 128Mi급).
- Alternatives considered: 공식 기본 3개(alloy-metrics / alloy-logs / alloy-receiver deployment) — pod 1개 추가. 메모리 여유 생기면 분리.
- Source: <https://grafana.com/docs/grafana-cloud/monitor-infrastructure/kubernetes-monitoring/configuration/helm-chart-config/helm-chart/collector-reference/>

**OBSERVABILITY-D3. 목적지(destinations)를 신호별 네이티브로 할지 OTLP 게이트웨이 하나로 할지?**

- Decision: 메트릭 = `prometheus`(remote_write, Mimir 엔드포인트), 로그 = `loki`, 트레이스만 = `otlp` (protocol http, otlp-gateway). 각 destination은 `secret.create: false`로 기존 Secret `grafana-cloud-credentials` 참조.
- Rationale: Grafana Cloud OTLP 게이트웨이는 OTLP/HTTP(protobuf)만 지원하고 gRPC 불가. 메트릭을 OTLP로 보내면 이름 변환(점→밑줄, target_info)이 생겨 K8s Monitoring 앱·사전 정의 알림(integrations-kubernetes)과 어긋남. 네이티브 remote_write/Loki push가 기본 경로.
- Alternatives considered: 전부 OTLP 게이트웨이 — 설정은 단순하지만 위 호환성 문제.
- Source: <https://grafana.com/docs/grafana-cloud/send-data/otlp/send-data-otlp/>

**OBSERVABILITY-D4. 10k active series Free 한도 안에 어떻게 맞추나?**

- Decision: 기본 allowlist 유지(kubelet/cadvisor/kube-state-metrics `useDefaultAllowList: true`), 컨트롤플레인 스크레이프 기본 off 유지, cadvisor `excludeMetrics: [container_network_.*, container_fs_.*]`, `global.scrapeInterval: 60s`, hostMetrics(node-exporter)는 `useIntegrationAllowList: true`, annotationAutodiscovery 대상(Argo CD·Traefik)은 `metricsTuning.includeMetrics`로 화이트리스트. Strimzi/CNPG/Authentik의 exporter는 SP-1에서 스크레이프하지 않음. 설치 후 `grafanacloud_instance_active_series`로 실측 후 조정.
- Rationale: active series는 scrape 간격과 무관(간격은 샘플 수만 줄임)하므로 allowlist/exclude만이 시리즈를 줄임. 기본 allowlist는 사전 정의 알림·대시보드에 필요한 최소 집합으로 설계됨. 10호스트 클러스터가 대략 1.5k–5k 시리즈라는 추정치 기준으로 2노드는 여유 있으나 annotation 자동탐색은 allowlist가 없어 필터가 필수.
- Alternatives considered: scrape interval 120s — 시리즈는 그대로, DPM만 감소. Pro 전환($19/월 + $6.50/1k series).
- Source: <https://github.com/grafana/k8s-monitoring-helm/blob/main/charts/k8s-monitoring/docs/examples/metrics-tuning/README.md>

**OBSERVABILITY-D5. Argo CD 메트릭(argocd_app_info)을 어떻게 수집하나?**

- Decision: argo-cd 차트 `controller.metrics.enabled: true` + `controller.metrics.service.annotations`에 `k8s.grafana.com/scrape: "true"`, `k8s.grafana.com/metrics.portName: http-metrics`, `k8s.grafana.com/job: argocd-application-controller` → k8s-monitoring `annotationAutodiscovery` (includeMetrics: argocd_app_info, argocd_app_sync_total, argocd_app_reconcile_.*).
- Rationale: Prometheus Operator CRD(ServiceMonitor)를 별도로 설치할 필요가 없음(v4는 CRD 미번들). 포트 8082/portName http-metrics는 argo-helm 기본값.
- Alternatives considered: `prometheusOperatorObjects` + argo-helm `serviceMonitor.enabled` — prometheus-community/prometheus-operator-crds 추가 설치 필요.
- Source: <https://github.com/grafana/k8s-monitoring-helm/blob/main/charts/k8s-monitoring/charts/feature-annotation-autodiscovery/README.md>

**OBSERVABILITY-D6. Traefik·Django 트레이스 경로와 샘플링은?**

- Decision: Traefik(HelmChartConfig) `tracing.otlp.grpc` → `k8s-monitoring-alloy-metrics.monitoring.svc.cluster.local:4317` (insecure), `sampleRate: 0.1`(prod)/1.0(dev). Django pod는 OTel SDK 환경변수로 같은 Service의 4318(http/protobuf), `OTEL_TRACES_SAMPLER=parentbased_always_on` → Traefik의 루트 결정을 따름. Alloy는 applicationObservability 기능(k8sattributes+batch)으로 otlp-gateway에 HTTP 전송.
- Rationale: applicationObservability 활성 시 4317/4318 리시버가 자동 노출되고 Service 이름은 `<RELEASE>-<COLLECTOR>` 규칙. Free 트레이스 50 GB/월은 넉넉하지만 head-sampling을 엣지(Traefik)에서 한 번만 결정해 Django와 불일치 방지.
- Alternatives considered: Alloy `otelcol.processor.tail_sampling` — 단일 노드 메모리 부담, SP-1 범위 밖.
- Source: <https://doc.traefik.io/traefik/reference/install-configuration/observability/tracing/>

**OBSERVABILITY-D7. 알림 규칙은 어디에 어떻게 정의하나?**

- Decision: Grafana-managed 알림을 OpenTofu `grafana_rule_group`(provider grafana 4.45.2)으로 코드화: NodeMemoryAvailableLow (`node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10`, for 10m, warning), ArgoAppOutOfSync (`argocd_app_info{sync_status!="Synced"} == 1`, for 1h), ArgoAppMissing (`absent(argocd_app_info) == 1`, for 15m). 데이터소스는 `data "grafana_data_source"` 이름 조회(`grafanacloud-<stack>-prom`). K8s Monitoring 마법사 Step 1의 사전 정의 규칙(integrations-kubernetes)은 그대로 설치.
- Rationale: argo-helm이 제공하는 예제 규칙(ArgoAppNotSynced 12h/ArgoAppMissing 15m)을 근거로 하되 12h는 너무 길어 1h로 단축. Grafana provider는 서비스 계정 토큰으로 인증(Access policy 토큰 아님).
- Alternatives considered: Mimir 룰러(PrometheusRule via mimirtool) — Free에서도 가능하나 Grafana-managed가 UI·연락처와 일체화되어 단순.
- Source: <https://grafana.com/docs/grafana-cloud/alerting/set-up/provision-alerting-resources/terraform-provisioning/>

**OBSERVABILITY-D8. Sentry는 어떤 플랜·역할로 쓰나?**

- Decision: Sentry SaaS Developer(Free) 1개 org, 프로젝트 2개(django-api, next-web). Sentry = 에러 전용. Django는 `traces_sample_rate` 미설정(트레이스는 OTel→Alloy→Tempo), Next.js는 클라이언트 전용(`instrumentation-client.ts`) + tracesSampleRate 0.1, `enableLogs: false`, replay는 onError만 1.0(세션 0).
- Rationale: Free 한도(5k errors/5M spans/50 replays/5 GB logs/1 user)와 Grafana Tempo 중복을 피하기 위해 트레이스는 한 곳(Tempo)에만. sentry-javascript 10.71+는 enableLogs 기본 true, sentry-python 2.68은 enable_logs 폐기 → 명시적으로 로그 차단.
- Alternatives considered: sentry-sdk `OTLPIntegration`(OTel 트레이스를 Sentry로도 전송, 이때 traces_sample_rate 설정 금지) — span 쿼터 소모·이중 전송이라 보류. Grafana Cloud Frontend Observability(Faro, 50k sessions Free)로 Sentry 대체 — SP-2 검토.
- Source: <https://docs.sentry.io/platforms/python/integrations/otlp/>

**OBSERVABILITY-D9. Next.js(OpenNext Cloudflare)에서 Sentry 서버 SDK를 넣을까?**

- Decision: 넣지 않는다. `sentry.server.config.ts`/`sentry.edge.config.ts`/`instrumentation.ts` 생성 안 함, `withSentryConfig`는 소스맵 업로드 목적으로만(CI에서 `SENTRY_AUTH_TOKEN`), `tunnelRoute` 미사용.
- Rationale: OpenNext/Workers에서 서버 SDK는 Debug ID 손실·AsyncLocalStorage·Turbopack @opentelemetry/api 중복 등 이슈가 보고돼 있고, 서버 번들 gzip ≤ 2.5 MiB 게이트에 불리. 클라이언트 전용은 커뮤니티에서 확인된 우회책.
- Alternatives considered: `@sentry/cloudflare`로 Worker 계측 — BFF Route Handler 에러 캡처가 필요해지면 SP-2에서 재검토.
- Source: <https://github.com/getsentry/sentry-javascript/issues/14931>

**OBSERVABILITY-D10. Grafana Cloud 토큰은 어떻게 만들고 어디에 두나?**

- Decision: Cloud Portal → Security → Access Policies에서 realm = 해당 스택(stack realm), scopes `metrics:write, logs:write, traces:write`(마법사 사용 시 `set:alloy-data-write` = metrics/logs/traces/profiles:write + fleet-management:read) 정책 1개 + 토큰 1개(만료 365일). 토큰은 Vault `platform/grafana-cloud`에 저장 → ESO ExternalSecret → Secret `grafana-cloud-credentials`(키 prom-username, loki-username, otlp-username, access-token). 알림 IaC용은 별도로 스택 Grafana 서비스 계정(Admin) 토큰을 Vault에 저장.
- Rationale: Basic auth username은 신호별 인스턴스 ID(Prometheus ID ≠ Loki ID ≠ 스택 ID)이고 비밀번호는 동일 토큰. gitops repo에는 ExternalSecret만 커밋(설계 원칙).
- Alternatives considered: org realm 토큰 — 스택 추가 시 편하지만 권한 범위 과다.
- Source: <https://grafana.com/docs/grafana-cloud/security-and-account-management/authentication-and-permissions/access-policies/>

### 설정 스니펫

**k8s-monitoring 4.5.1 values.yaml (Grafana Cloud, 2노드 arm64)** — <https://github.com/grafana/k8s-monitoring-helm/blob/main/charts/k8s-monitoring/README.md>
```
cluster:
  name: joshtech-k3s
global:
  scrapeInterval: 60s

destinations:
  gc-metrics:
    type: prometheus
    url: https://prometheus-prod-XX-prod-<region>.grafana.net/api/prom/push   # 포털 Prometheus 타일
    auth: {type: basic, usernameKey: prom-username, passwordKey: access-token}
    secret: {create: false, name: grafana-cloud-credentials, namespace: monitoring}
  gc-logs:
    type: loki
    url: https://logs-prod-XXX.grafana.net/loki/api/v1/push
    auth: {type: basic, usernameKey: loki-username, passwordKey: access-token}
    secret: {create: false, name: grafana-cloud-credentials, namespace: monitoring}
  gc-traces:
    type: otlp
    protocol: http                      # 게이트웨이는 OTLP/HTTP만
    url: https://otlp-gateway-prod-<region>.grafana.net/otlp
    metrics: {enabled: false}
    logs: {enabled: false}
    traces: {enabled: true}
    auth: {type: basic, usernameKey: otlp-username, passwordKey: access-token}
    secret: {create: false, name: grafana-cloud-credentials, namespace: monitoring}

clusterMetrics:
  enabled: true
  collector: alloy-metrics
  kubelet: {metricsTuning: {useDefaultAllowList: true}}
  cadvisor:
    metricsTuning:
      useDefaultAllowList: true
      excludeMetrics: [container_network_.*, container_fs_.*]
  kube-state-metrics: {metricsTuning: {useDefaultAllowList: true}}
hostMetrics:
  enabled: true
  collector: alloy-metrics
  node-exporter: {metricsTuning: {useIntegrationAllowList: true}}
clusterEvents:
  enabled: true
  collector: alloy-metrics
podLogsViaLoki:
  enabled: true
  collector: alloy-logs
annotationAutodiscovery:
  enabled: true
  collector: alloy-metrics
  metricsTuning:
    includeMetrics: [argocd_app_info, argocd_app_sync_total, argocd_app_reconcile_.*, traefik_entrypoint_requests_total, traefik_service_request_duration_seconds_.*]
applicationObservability:
  enabled: true
  collector: alloy-metrics
  receivers:
    otlp:
      grpc: {enabled: true, port: 4317}
      http: {enabled: true, port: 4318}

telemetryServices:
  kube-state-metrics:
    deploy: true
    resources: {requests: {cpu: 10m, memory: 32Mi}, limits: {memory: 64Mi}}
  node-exporter:
    deploy: true
    resources: {requests: {cpu: 50m, memory: 30Mi}, limits: {memory: 50Mi}}

collectors:
  alloy-metrics:
    presets: [small, statefulset, singleton]
    controller: {nodeSelector: {role: platform}}   # 키 경로는 helm show values로 검증(open)
  alloy-logs:
    presets: [small, filesystem-log-reader, daemonset]
```

**ExternalSecret → grafana-cloud-credentials (gitops repo에 커밋되는 유일한 시크릿 객체)** — <https://github.com/grafana/k8s-monitoring-helm/blob/main/charts/k8s-monitoring/docs/examples/auth/external-secrets/values.yaml>
```
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: {name: grafana-cloud-credentials, namespace: monitoring}
spec:
  refreshInterval: 1h
  secretStoreRef: {kind: ClusterSecretStore, name: vault}
  target: {name: grafana-cloud-credentials}
  data:
    - {secretKey: prom-username, remoteRef: {key: platform/grafana-cloud, property: prom_instance_id}}
    - {secretKey: loki-username, remoteRef: {key: platform/grafana-cloud, property: loki_instance_id}}
    - {secretKey: otlp-username, remoteRef: {key: platform/grafana-cloud, property: stack_instance_id}}
    - {secretKey: access-token,  remoteRef: {key: platform/grafana-cloud, property: access_policy_token}}
```

**K3s Traefik HelmChartConfig — OTLP 트레이스 → Alloy + 메트릭 스크레이프 어노테이션** — <https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml>
```
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata: {name: traefik, namespace: kube-system}
spec:
  valuesContent: |-
    tracing:
      serviceName: traefik
      sampleRate: 0.1
      otlp:
        enabled: true
        grpc:
          enabled: true
          endpoint: k8s-monitoring-alloy-metrics.monitoring.svc.cluster.local:4317
          insecure: true
    deployment:
      podAnnotations:
        k8s.grafana.com/scrape: "true"
        k8s.grafana.com/metrics.portName: metrics
        k8s.grafana.com/job: traefik
```

**argo-cd Helm values — 컨트롤러 메트릭 노출 + 자동탐색 어노테이션** — <https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/values.yaml>
```
controller:
  metrics:
    enabled: true
    service:
      portName: http-metrics   # 8082
      annotations:
        k8s.grafana.com/scrape: "true"
        k8s.grafana.com/metrics.portName: http-metrics
        k8s.grafana.com/job: argocd-application-controller
```

**Django pod OTel 환경변수 (OTLP → Alloy 4318)** — <https://grafana.com/docs/grafana-cloud/send-data/otlp/send-data-otlp/>
```
env:
  - {name: OTEL_SERVICE_NAME, value: portfolio-api}
  - {name: OTEL_EXPORTER_OTLP_ENDPOINT, value: http://k8s-monitoring-alloy-metrics.monitoring.svc.cluster.local:4318}
  - {name: OTEL_EXPORTER_OTLP_PROTOCOL, value: http/protobuf}
  - {name: OTEL_TRACES_SAMPLER, value: parentbased_always_on}   # Traefik 루트 샘플링 결정을 따름
  - {name: OTEL_RESOURCE_ATTRIBUTES, value: deployment.environment=prod,service.namespace=joshuatech}
```

**Alloy 원시 설정 참고 — otelcol.receiver.otlp (차트가 동일 내용을 생성; extraConfig 시 참고)** — <https://grafana.com/docs/alloy/latest/reference/components/otelcol/otelcol.receiver.otlp/>
```
otelcol.receiver.otlp "default" {
  grpc { endpoint = "0.0.0.0:4317" }
  http { endpoint = "0.0.0.0:4318" }
  output {
    traces = [otelcol.processor.k8sattributes.default.input]
  }
}
otelcol.processor.k8sattributes "default" {
  output { traces = [otelcol.processor.batch.default.input] }
}
otelcol.processor.batch "default" {
  output { traces = [otelcol.exporter.otlphttp.grafana_cloud.input] }
}
otelcol.exporter.otlphttp "grafana_cloud" {
  client {
    endpoint = "https://otlp-gateway-prod-<region>.grafana.net/otlp"
    auth     = otelcol.auth.basic.grafana_cloud.handler
  }
}
```

**OpenTofu — Grafana-managed 알림 규칙 (노드 메모리, Argo OutOfSync)** — <https://github.com/grafana/terraform-provider-grafana/blob/main/docs/resources/rule_group.md>
```
provider "grafana" {
  url  = var.grafana_url            # https://<stack>.grafana.net
  auth = var.grafana_sa_token       # 스택 서비스 계정 토큰(Vault)
}
data "grafana_data_source" "prom" { name = "grafanacloud-${var.stack}-prom" }
resource "grafana_folder" "platform" { title = "platform" }

resource "grafana_rule_group" "platform" {
  name             = "platform"
  folder_uid       = grafana_folder.platform.uid
  interval_seconds = 60

  rule {
    name = "NodeMemoryAvailableLow"; for = "10m"; condition = "C"
    no_data_state = "NoData"; exec_err_state = "Error"
    labels = { severity = "warning" }
    annotations = { summary = "{{ $labels.instance }} MemAvailable < 10%" }
    data {
      ref_id = "A"; datasource_uid = data.grafana_data_source.prom.uid
      relative_time_range { from = 600; to = 0 }
      model = jsonencode({ refId = "A", instant = true,
        expr = "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes" })
    }
    data {
      ref_id = "C"; datasource_uid = "__expr__"
      relative_time_range { from = 0; to = 0 }
      model = jsonencode({ refId = "C", type = "threshold", expression = "A",
        conditions = [{ evaluator = { type = "lt", params = [0.10] } }] })
    }
  }

  rule {
    name = "ArgoAppOutOfSync"; for = "1h"; condition = "C"
    no_data_state = "OK"; exec_err_state = "Error"
    labels = { severity = "warning" }
    annotations = { summary = "[{{ $labels.name }}] Application not synchronized" }
    data {
      ref_id = "A"; datasource_uid = data.grafana_data_source.prom.uid
      relative_time_range { from = 600; to = 0 }
      model = jsonencode({ refId = "A", instant = true,
        expr = "argocd_app_info{sync_status!=\"Synced\"} == 1" })
    }
    data {
      ref_id = "C"; datasource_uid = "__expr__"
      relative_time_range { from = 0; to = 0 }
      model = jsonencode({ refId = "C", type = "threshold", expression = "A",
        conditions = [{ evaluator = { type = "gt", params = [0] } }] })
    }
  }
}
```

**Django settings.py — Sentry 에러 전용 (트레이스는 OTel)** — <https://docs.sentry.io/platforms/python/integrations/django/>
```
# pyproject: sentry-sdk[django]>=2.68.1  (Celery 사용 시 CeleryIntegration 추가)
import sentry_sdk
from sentry_sdk.integrations.django import DjangoIntegration
from sentry_sdk.integrations.celery import CeleryIntegration

sentry_sdk.init(
    dsn=env("SENTRY_DSN", default=""),   # 비어 있으면 비활성
    environment=env("APP_ENV"),          # dev | prod
    release=env("IMAGE_DIGEST"),         # GHCR digest
    send_default_pii=False,              # 멀티테넌트: 사용자 식별자 자동 첨부 금지
    # traces_sample_rate 미설정 = Sentry 트레이싱 off (OTel -> Alloy -> Tempo)
    integrations=[DjangoIntegration(transaction_style="url"), CeleryIntegration()],
)
```

**Next.js 16 클라이언트 전용 Sentry — instrumentation-client.ts + next.config.ts** — <https://docs.sentry.io/platforms/javascript/guides/nextjs/manual-setup/>
```
// instrumentation-client.ts  (sentry.server/edge.config·instrumentation.ts는 만들지 않음)
import * as Sentry from "@sentry/nextjs";
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NEXT_PUBLIC_APP_ENV,
  release: process.env.NEXT_PUBLIC_RELEASE,
  tracesSampleRate: 0.1,
  enableLogs: false,            // 10.71+ 기본 true
  sendDefaultPii: false,
  integrations: [Sentry.replayIntegration()],
  replaysSessionSampleRate: 0,  // Free 50 replays/월
  replaysOnErrorSampleRate: 1.0,
});
export const onRouterTransitionStart = Sentry.captureRouterTransitionStart;

// next.config.ts — 소스맵 업로드 전용
import { withSentryConfig } from "@sentry/nextjs";
export default withSentryConfig(nextConfig, {
  org: "<org>", project: "joshuatech-web",
  authToken: process.env.SENTRY_AUTH_TOKEN,   // CI 시크릿
  silent: !process.env.CI,
  widenClientFileUpload: true,
  sourcemaps: { deleteSourcemapsAfterUpload: true },
});
```

### 함정

- k8s-monitoring는 v4(4.5.1)가 현재 — v3용 values(podLogs, destinations 리스트, alloy-metrics.enabled)는 그대로 쓰면 실패. 변환기: https://grafana.github.io/k8s-monitoring-helm-migrator/ . 차트에 values.schema.json이 있어 오타 키가 helm template 단계에서 거부되므로 CI에 `helm template --version 4.5.1` 검증을 넣을 것.
- Grafana Cloud OTLP 게이트웨이(otlp-gateway-*.grafana.net)는 OTLP/HTTP(protobuf)만 지원, gRPC 불가 → 차트 otlp destination은 `protocol: http`, 원시 Alloy는 otelcol.exporter.otlphttp. 앱 SDK 직결 시 OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf. Python 환경변수의 헤더는 'Basic ' → 'Basic%20'.
- Basic auth username은 신호별로 다르다: Prometheus(Mimir) 인스턴스 ID, Loki 인스턴스 ID, OTLP는 Grafana 스택 인스턴스 ID. 토큰은 하나로 공유 가능. Secret에 세 username 키를 따로 둘 것.
- active series 예산(10k)은 scrape interval로는 줄지 않는다(샘플/DPM만 감소). 시리즈를 줄이는 손잡이는 metricsTuning의 useDefaultAllowList/includeMetrics/excludeMetrics뿐. annotationAutodiscovery·prometheusOperatorObjects에는 기본 allowlist가 없어 includeMetrics 없이 Argo/Traefik을 붙이면 수천 시리즈가 유입될 수 있음.
- Free 플랜 보존 14일(메트릭·로그·트레이스) — 장기 추세·학습 노트용 데이터는 남지 않음. Grafana UI 3 active users, IRM 3 users 한도.
- Kubernetes Monitoring Free 2,232 host-hours/월 = 노드 3대 × 744h → 2노드 OK, 3노드부터 초과.
- Argo CD로 k8s-monitoring을 설치하면 alloy-operator CRD(alloys.collectors.grafana.com)와 Alloy CR이 같은 앱에 있어 첫 sync의 dry-run이 CRD 부재로 실패할 수 있음 → CRD를 낮은 sync-wave의 별도 Application으로 분리하거나 Alloy CR에 `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true`(+ 기존 설계의 ServerSideApply) 적용. v4는 Prometheus Operator CRD를 번들하지 않음(필요 시 prometheus-community/prometheus-operator-crds).
- 컬렉터 워크로드/Service 이름은 `<RELEASE>-<COLLECTOR>` — 릴리스 이름에 컬렉터 이름이 포함되면 반복하지 않음(예: 릴리스 `alloy` + 컬렉터 `alloy-metrics` → 이름이 달라짐). Traefik/Django의 엔드포인트 FQDN을 릴리스 이름과 함께 고정하고 tester가 `nc -z`로 검증.
- arm64: grafana/alloy 이미지는 linux/arm64 공식 지원(BoringCrypto 변형도 arm64). kube-state-metrics·node-exporter 공식 이미지도 multi-arch. costMetrics(OpenCost)·profiling(Beyla/eBPF)·autoInstrumentation은 끄기 — 메모리와 시리즈만 소모.
- Alloy 1.19.0 breaking: prometheus.write.queue 컴포넌트 제거, ServiceMonitor의 로컬 파일 참조(bearerTokenFile 등) 기본 거부(allow_arbitrary_file_access=true 필요). 차트 기본 remote_write에는 영향 없음.
- K3s v1.36.2+부터 Traefik 차트 v40.x — ingress-nginx 마이그레이션 provider 이름이 kubernetesIngressNginx → kubernetesIngressNGINX로 변경. HelmChartConfig의 tracing 키(tracing.otlp.grpc.enabled/endpoint/insecure, tracing.sampleRate)는 v40 값 스키마 기준. 평문 in-cluster gRPC는 `insecure: true` 필수.
- Sentry JS 10.71.0부터 enableLogs 기본 true(Sentry.logger.* 또는 콘솔 통합 사용 시에만 전송되지만 Free 5 GB 로그 쿼터 보호를 위해 명시적 false). sentry-python 2.68.0은 enable_logs/enable_metrics를 폐기(무동작) — 로그는 통합별 capture_sentry_logs로만 opt-in.
- sentry-python OTLPIntegration을 쓰면 traces_sample_rate/traces_sampler를 설정하면 안 됨(이중 계측). 본 설계는 Sentry 에러 전용이므로 traces_sample_rate 자체를 두지 않음.
- Next.js 16 + Turbopack에서 @sentry/nextjs 서버 SDK는 @opentelemetry/api 청크 중복(#19367), SSR 중 Math.random 제약, proxy/middleware 미계측(#21713) 이슈가 보고됨 — 클라이언트 전용 구성이 이를 우회. Turbopack에서는 로더가 instrumentation*.ts 파일에만 주입됨.
- Sentry `tunnelRoute`는 서버 라우트를 추가하므로 Worker 번들이 커짐 — 사용 안 함(광고차단기로 인한 일부 이벤트 손실 감수). 소스맵 업로드는 withSentryConfig + CI SENTRY_AUTH_TOKEN으로만.
- Sentry Developer 플랜은 1 user — 팀원 초대 불가, 보존 30일. UI/continuous profiling은 PAYG 필요.
- Grafana provider(OpenTofu) 인증은 Access policy 토큰이 아니라 스택 Grafana 서비스 계정 토큰. 프로비저닝 후 UI 편집을 허용하려면 `disable_provenance = true`. 사전 정의 K8s 알림(integrations-kubernetes 폴더)은 마법사 Step 1에서 설치되며 Grafana-managed로 동작.
- statefulset 프리셋의 Alloy는 remote_write WAL을 pod 로컬에 두므로 노드 A 재이미지/재시작 시 미전송 샘플 유실 — Free 플랜에서는 감수. `small` 프리셋 요청값은 대략 cpu 100m/mem 128Mi 급이므로 13 GB 노드 A 예산에 Alloy 2개 + KSM + node-exporter ≈ 0.5 GiB로 잡을 것.

### 미확인

- alloy-operator 0.7.1(appVersion 1.12.1은 오퍼레이터 자체 버전)이 기본으로 배포하는 Alloy 이미지 태그가 1.19.x인지 미확인 — `helm template` 출력의 image 태그로 확인.
- v4 collectors 하위에서 nodeSelector/tolerations/resources를 지정하는 정확한 키 경로(`controller.nodeSelector` vs `nodeSelector`) 미검증 — `helm show values grafana/k8s-monitoring --version 4.5.1`로 확인.
- otlp destination의 HTTP 전환 키가 `protocol: http`인지(v4 스키마) 재확인 필요.
- applicationObservability의 4317/4318이 statefulset 컬렉터에 붙을 때 Service가 자동 생성되는지(수신 전용 deployment 컬렉터를 전제한 예제만 확인됨).
- Argo CD가 k8s-monitoring의 Alloy CR을 첫 sync에서 어떻게 처리하는지(SkipDryRunOnMissingResource 필요 여부) 실검증 전.
- 실제 active series 수: 2노드·약 60 pod 기준 3k–6k로 추정하나 설치 후 `grafanacloud_instance_active_series`로 측정 필요(Strimzi/CNPG 스크레이프 추가 시 재산정).
- Grafana Cloud 스택 리전 코드(춘천/서울에 가장 가까운 ap-northeast 계열)와 Prometheus/Loki/OTLP 엔드포인트 호스트는 포털 타일에서 확인 — 리전 생성 시점에 따라 호스트가 다를 수 있음.
- withSentryConfig를 클라이언트 전용으로 써도 OpenNext Worker 번들에 서버 스텁이 포함되는지, 2.5 MiB 게이트에 미치는 영향 미측정 — CI에서 with/without 비교.
- @sentry/nextjs 10.73이 Next.js 16.3을 공식 지원 범위로 명시하는지(README는 최소 14.0.0만 기재) — 릴리스 노트·이슈 추적.
- sentry-python은 2.67.0에서 Django 6.1 alpha/beta를 tox에서 제외 — Django 6.1 GA 이후 지원 매트릭스 재확인.
- Grafana Cloud 기본 Prometheus 데이터소스 UID 문자열(`grafanacloud-prom` 추정)은 확정하지 않고 `data grafana_data_source` 이름 조회로 회피.
- K8s Monitoring host-hours가 K3s 서버 노드(마스터 겸 워커)에 대해 어떻게 계산되는지 미확인.


## R11 OpenTofu OCI

R11 OpenTofu + OCI provider — 인스턴스 재이미지(부트 볼륨 교체)·import·네트워크(Cloudflare IP)·Object Storage/S3 백엔드·KMS·IAM·Budgets·Ubuntu 24.04 arm64 이미지

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| OpenTofu (tofu) | 1.12.6 (안정 최신; 1.11.14 동일일 패치, 1.13.0-beta1 2026-08-27 프리릴리스) | 2026-08-19 | <https://github.com/opentofu/opentofu/releases> |
| OCI provider oracle/oci (OpenTofu 레지스트리 미러 동일 주소 oracle/oci) | 8.29.0 | 2026-08-26 | <https://github.com/oracle/terraform-provider-oci/releases> |
| Cloudflare provider cloudflare/cloudflare (data.cloudflare_ip_ranges 용) | 5.24.0 | 2026-08-24 | <https://github.com/cloudflare/terraform-provider-cloudflare/releases> |
| Canonical Ubuntu 24.04 aarch64 플랫폼 이미지 (ap-chuncheon-1 OCID: ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalxokbvhkaibe6ieaosyvzxih2xyglm3ypyiedbg3x4rpifmauw5a) | Canonical-Ubuntu-24.04-aarch64-2026.07.17-0 | 2026-07-21 | <https://docs.oracle.com/en-us/iaas/images/ubuntu-2404/canonical-ubuntu-24-04-aarch64-2026-07-17-0.htm> |
| OCI provider 부트 볼륨 교체(UpdateInstance sourceDetails) 지원 시작 버전 | 5.38.0 | 2024-04-17 | <https://raw.githubusercontent.com/oracle/terraform-provider-oci/master/CHANGELOG.md> |
| OpenTofu S3 백엔드 네이티브 잠금 use_lockfile 도입 버전 | 1.10 | 2025 | <https://opentofu.org/docs/v1.10/intro/whats-new/> |

### 결정

**OCI-TOFU-D1. OpenTofu·provider 버전 고정은?**

- Decision: `required_version = ">= 1.12.6, < 2.0.0"`, `oracle/oci ~> 8.29`, `cloudflare/cloudflare ~> 5.24`. 1.13은 beta라 채택하지 않음.
- Rationale: 1.12.6이 2026-08-19 안정 최신(동적 prevent_destroy·-json-into 포함). oracle/oci는 OpenTofu 레지스트리가 동일 주소로 미러(8.29.0 확인). 잠금 파일 `.terraform.lock.hcl` 커밋.
- Alternatives considered: 1.11.x LTS 유지(1.12 기능 불필요 시) / 1.13 beta(비권장)
- Source: <https://api.opentofu.org/registry/docs/providers/oracle/oci/index.json>

**OCI-TOFU-D2. 상태 저장은 어디에, 어떤 플래그로?**

- Decision: OCI Object Storage 버킷 `jt-tfstate`(versioning=Enabled) + S3 호환 백엔드. 필수 플래그: endpoints.s3=`https://<namespace>.compat.objectstorage.ap-chuncheon-1.oraclecloud.com`, region=ap-chuncheon-1, skip_region_validation·skip_credentials_validation·skip_requesting_account_id·skip_metadata_api_check·skip_s3_checksum·use_path_style 모두 true. `use_lockfile`은 끈다. 자격 증명은 Customer Secret Key를 AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY 환경변수로.
- Rationale: Oracle 공식 문서(terraformUsingObjectStore)가 1.6.4+ 구성으로 정확히 이 플래그 집합을 제시. OCI compat API는 SigV4만 지원하며 체크섬 헤더 미지원이라 skip_s3_checksum 없으면 PutObject 400. `use_lockfile`은 If-None-Match 조건부 쓰기가 필요한데 OCI 지원 요청 이슈(#2323)가 미해결.
- Alternatives considered: OCI 네이티브 `oci` 백엔드 없음 / GitHub Actions 아티팩트·로컬 상태(비권장) / DynamoDB 대체 없음 → CI에서는 GitHub `concurrency` 그룹으로 직렬화
- Source: <https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformUsingObjectStore.htm>

**OCI-TOFU-D3. 상태 버킷·시크릿 키의 부트스트랩 순서(닭-달걀)는?**

- Decision: 1단계(로컬 상태): 버킷 `jt-tfstate` + 전용 IAM 사용자의 Customer Secret Key를 OCI CLI로 먼저 만든다(`oci os bucket create --versioning Enabled`, `oci iam customer-secret-key create`). 2단계: backend 블록 추가 후 `tofu init -migrate-state`. tfstate용 시크릿 키는 OpenTofu 리소스로 만들지 않는다(상태 안에 자기 자신의 자격 증명이 들어가므로).
- Rationale: `oci_identity_customer_secret_key.key`는 생성 시점에만 노출되고 상태에 평문 저장됨. 사용자당 최대 2개.
- Alternatives considered: 모든 것을 OpenTofu로 만들고 상태를 로컬에 두었다가 migrate(가능하나 시크릿이 상태에 남음)
- Source: <https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/identity_customer_secret_key.html>

**OCI-TOFU-D4. 기존 인스턴스를 OCID·IP 유지한 채 Ubuntu 24.04로 바꾸는 방법은?**

- Decision: OCI 'Replace Boot Volume'(UpdateInstance.sourceDetails)을 OpenTofu로 수행: import한 `oci_core_instance`의 `source_details.source_id`를 새 이미지 OCID로 바꾸면 provider가 UpdateInstance(sourceDetails, work request 대기)를 호출해 in-place로 부트 볼륨을 교체한다(source_id/source_type은 ForceNew 아님, provider 5.38.0+). `is_preserve_boot_volume_enabled=true`, `boot_volume_size_in_gbs=100`, `update_operation_constraint="ALLOW_DOWNTIME"`, `lifecycle { prevent_destroy = true }`. plan에 `-/+` 또는 `destroy`가 보이면 apply 금지. 먼저 joshtech_cache(노드 B)로 리허설 후 joshtech_api_1st.
- Rationale: OCI 문서: 인스턴스가 정지→볼륨 교체→이전 상태로 복귀하며 terminate 없음, Linux 전용·같은 배포판만 허용(기존 VM은 `ubuntu` 사용자로 SSH하는 Ubuntu이므로 충족). provider 소스(core_instance_resource.go updateOptionsViaWorkRequest)에서 source_id 변경 시 UpdateInstanceSourceViaImageDetails{ImageId, BootVolumeSizeInGBs, KmsKeyId(비어 있으면 미전송), IsPreserveBootVolumeEnabled}를 전송함을 확인. 2025-11 사용자 보고(provider 7.27.0): Linux↔Linux 교체 정상.
- Alternatives considered: CLI `oci compute instance update --source-details '{"sourceType":"image",...}'` 후 OpenTofu에서 source_id만 맞춰 import/refresh / 콘솔 More Actions → Replace Boot Volume / terminate+재생성(금지: OCID·A1 할당 상실)
- Source: <https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/replacingbootvolume.htm>

**OCI-TOFU-D5. 기존 리소스를 OpenTofu 상태로 어떻게 가져오나?**

- Decision: `import {}` 블록 + `tofu plan -generate-config-out=generated.tf`로 인스턴스 2대·VCN·서브넷·보안 리스트·IGW·라우트 테이블을 1회 가져온 뒤 생성 HCL을 정리하고 import 블록은 커밋에 남긴다. 부트 볼륨 리소스는 import하지 않는다(교체로 사라짐).
- Rationale: OpenTofu import 블록은 plan 단계에서 구성 생성 가능(실험적, for_each와 병용 불가). `oci_core_instance` import id는 인스턴스 OCID, 보안 리스트·VCN·서브넷도 OCID, 버킷은 `n/{ns}/b/{name}`.
- Alternatives considered: OCI 리소스 디스커버리 `terraform-provider-oci -command=export -compartment_id=<c> -services=core -output_path=./discovered -generate_state`(ignore_changes 자동 삽입) / `tofu import` CLI 수동
- Source: <https://opentofu.org/docs/language/import/>

**OCI-TOFU-D6. Cloudflare IP 한정 인바운드는 보안 리스트인가 NSG인가?**

- Decision: NSG. 노드 A VNIC에 `nsg-node-a-platform`(Cloudflare 22개 CIDR → 443/tcp, 22규칙)과 두 노드 공통 `nsg-cluster`(source_type=NETWORK_SECURITY_GROUP 자기참조, protocol all)를 붙이고, 서브넷 보안 리스트는 egress all만 남긴다. 노드 B는 인터넷 인바운드 규칙 없음. CIDR 목록은 `data.cloudflare_ip_ranges`(ipv4_cidrs·ipv6_cidrs)로 받아 for_each. 80은 열지 않는다(Cloudflare Full(strict)는 443, LE는 DNS-01).
- Rationale: 보안 리스트는 서브넷 전체(노드 B 포함)에 적용되어 역할별 분리가 불가. 한도: 보안 리스트 ingress 200/egress 200(증설 불가), NSG 120(ingress+egress 합), VNIC당 NSG 5개 — 22~44 규칙은 모두 여유. NSG 규칙은 리소스 1개=규칙 1개라 diff가 명확.
- Alternatives considered: 보안 리스트 dynamic ingress_security_rules(tcp_options.min/max) — 단일 서브넷에 두 노드가 같이 있어 비권장 / 노드 B를 사설 서브넷으로 분리(추가 서브넷·NAT 비용)
- Source: <https://docs.oracle.com/en-us/iaas/Content/General/Concepts/servicelimits.htm>

**OCI-TOFU-D7. Vault auto-unseal 키·IAM은?**

- Decision: `oci_kms_vault`(vault_type=DEFAULT) 1개 + `oci_kms_key`(protection_mode=HSM, AES/32, is_auto_rotation_enabled=false). 동적 그룹 `jt-k3s-nodes`(Any{instance.id=A, instance.id=B}) + 정책 `use keys ... where target.key.id='<key>'`, `read buckets`, `manage objects ... where target.bucket.name='jt-backup'`. Vault seal 스탠자는 key_id·crypto_endpoint·management_endpoint(모두 vault 리소스 attribute)만 두고 auth_type_api_key 미설정(=인스턴스 프린시펄).
- Rationale: go-kms-wrapping ocikms는 SetConfig에서 Encrypt(빈 문자열) 테스트와 management GetKey(현재 키 버전)를 호출 → `use keys` 동사가 KEY_READ+KEY_ENCRYPT+KEY_DECRYPT를 모두 포함. Always Free/PAYG 공통으로 HSM 키 버전 20개까지 무료, 소프트웨어 키는 무제한 무료. VIRTUAL_PRIVATE는 유료 시간 과금·Always Free 제외.
- Alternatives considered: protection_mode=SOFTWARE(무료·무제한, HSM 요구 없으면 충분) / Vault Shamir 수동 unseal(재부팅마다 개입)
- Source: <https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/keypolicyreference.htm>

**OCI-TOFU-D8. 동적 그룹·정책 리소스는 legacy IAM인가 Identity Domains인가?**

- Decision: legacy `oci_identity_dynamic_group`(compartment_id=테넌시 OCID) + `oci_identity_policy`. 테넌시가 Default 도메인만 쓰는 전제.
- Rationale: Default 도메인은 legacy IAM API로 계속 관리 가능(OCI 랜딩존 모듈이 두 방식 병행). matching_rule 갱신 반영에 최대 ~1시간, 테넌시당 동적 그룹 50개·인스턴스당 5개 한도.
- Alternatives considered: `oci_identity_domains_dynamic_resource_group`(비Default 도메인 필요 시)
- Source: <https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingdynamicgroups.htm>

**OCI-TOFU-D9. 예산 알림은?**

- Decision: `oci_budget_budget`(compartment_id=테넌시 루트, reset_period=MONTHLY, target_type=COMPARTMENT, targets=[테넌시 OCID], amount=SGD 정수) + `oci_budget_alert_rule` 2개: ACTUAL 80% PERCENTAGE, FORECAST 100% PERCENTAGE, recipients=운영자 이메일.
- Rationale: 예산은 루트 컴파트먼트에만 생성되며(`manage usage-budgets in tenancy` 정책 필요) 평가는 주기적(실시간 아님). PAYG SGD 테넌시이므로 금액 단위 SGD.
- Alternatives considered: 태그 기반 예산(TAG) / OCI Monitoring 알람(비용 아님)
- Source: <https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/budgetsoverview.htm>

**OCI-TOFU-D10. 이미지 OCID를 어떻게 정하고 참조하나?**

- Decision: OCID를 변수에 고정(ap-chuncheon-1: `ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalxokbvhkaibe6ieaosyvzxih2xyglm3ypyiedbg3x4rpifmauw5a`, Canonical-Ubuntu-24.04-aarch64-2026.07.17-0). `data.oci_core_images` '최신'을 source_id에 직접 넣지 않는다. 조회는 CLI `oci compute image list -c <tenancy> --operating-system "Canonical Ubuntu" --operating-system-version 24.04 --shape VM.Standard.A1.Flex --sort-by TIMECREATED --sort-order DESC --all`(Minimal 제외).
- Rationale: source_id 변경 = 부트 볼륨 교체이므로 월간 이미지 갱신 때마다 노드가 초기화되는 사고를 막아야 함. OCID는 리전별로 다름.
- Alternatives considered: data source + `lifecycle.ignore_changes = [source_details[0].source_id]`(교체 시 잠시 해제) — 실수 여지 큼
- Source: <https://docs.oracle.com/en-us/iaas/images/ubuntu-2404/index.htm>

**OCI-TOFU-D11. K3s 부트스트랩을 cloud-init user_data로 할 수 있나?**

- Decision: 아니오. 부트 볼륨 교체 후 부트스트랩은 cloudflared 터널 SSH(기존 ssh_authorized_keys 유지) + 스크립트/Ansible로 한다.
- Rationale: UpdateInstance는 `user_data`·`ssh_authorized_keys` 변경을 거부(생성 후 불변). 새 볼륨의 cloud-init은 인스턴스에 이미 붙어 있는 메타데이터(2025-05 생성 시 값)를 그대로 읽는다.
- Alternatives considered: metadata의 다른 키로 값 전달(가능) / 커스텀 이미지 굽기
- Source: <https://docs.oracle.com/en-us/iaas/tools/python/latest/api/core/models/oci.core.models.UpdateInstanceDetails.html>

### 설정 스니펫

**versions.tf + backend s3 (OCI Object Storage)** — <https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/terraformUsingObjectStore.htm>
```
terraform {
  required_version = ">= 1.12.6, < 2.0.0"
  required_providers {
    oci        = { source = "oracle/oci",             version = "~> 8.29" }
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.24" }
  }
  backend "s3" {
    bucket = "jt-tfstate"
    key    = "oci/terraform.tfstate"
    region = "ap-chuncheon-1"
    endpoints = { s3 = "https://<namespace>.compat.objectstorage.ap-chuncheon-1.oraclecloud.com" }
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
    # use_lockfile = true  # OCI compat API If-None-Match 미확인(oracle/terraform-provider-oci#2323) — 검증 전 금지
  }
}
# 자격 증명(저장소 밖): AWS_ACCESS_KEY_ID=<customer secret key id>  AWS_SECRET_ACCESS_KEY=<key>
# 필요 시: AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
```

**import 블록 + 재이미지용 oci_core_instance** — <https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/core_instance.html>
```
import { to = oci_core_instance.node_a  id = "ocid1.instance.oc1.ap-chuncheon-1.<joshtech_api_1st>" }
import { to = oci_core_instance.node_b  id = "ocid1.instance.oc1.ap-chuncheon-1.<joshtech_cache>" }
import { to = oci_core_vcn.main         id = "ocid1.vcn.oc1.ap-chuncheon-1.<...>" }
import { to = oci_core_subnet.public    id = "ocid1.subnet.oc1.ap-chuncheon-1.<...>" }
# 1회: tofu plan -generate-config-out=generated.tf  → 정리 후 아래 형태로 유지

variable "ubuntu_2404_arm_image_ocid" {
  # Canonical-Ubuntu-24.04-aarch64-2026.07.17-0, ap-chuncheon-1 — 고정값. 변경 = 부트 볼륨 교체
  default = "ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalxokbvhkaibe6ieaosyvzxih2xyglm3ypyiedbg3x4rpifmauw5a"
}

resource "oci_core_instance" "node_a" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.ad
  display_name        = "joshtech_api_1st"
  shape               = "VM.Standard.A1.Flex"
  shape_config { ocpus = 2  memory_in_gbs = 13 }
  preserve_boot_volume        = true             # destroy 경로 2중 안전
  update_operation_constraint = "ALLOW_DOWNTIME"  # 교체 중 정지 허용

  source_details {
    source_type                     = "image"
    source_id                       = var.ubuntu_2404_arm_image_ocid  # ← 변경 시 UpdateInstance(sourceDetails) in-place
    boot_volume_size_in_gbs         = 100
    is_preserve_boot_volume_enabled = true       # 구 볼륨 보존 → 검증 후 수동 삭제
  }
  create_vnic_details {                          # import 시 primary VNIC에서 채워짐 — 값 일치 필수
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    nsg_ids          = [oci_core_network_security_group.node_a.id, oci_core_network_security_group.cluster.id]
  }
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [metadata, defined_tags, create_vnic_details[0].defined_tags]
  }
}
# 검증: tofu plan 결과가 '~ update in-place' 이고 source_details 만 바뀌어야 함. '-/+' 또는 '- destroy' 시 apply 금지.
```

**OCI CLI: 이미지 조회 + 부트 볼륨 교체(대안·리허설)** — <https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/compute/instance/update.html>
```
# 이미지 OCID 조회(Minimal 제외)
oci compute image list -c <tenancy_ocid> --all \
  --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
  --shape VM.Standard.A1.Flex --sort-by TIMECREATED --sort-order DESC \
  --query 'data[?!contains("display-name", `Minimal`)].{name:"display-name", id:id, created:"time-created"}' --output table

# 부트 볼륨 교체(인스턴스 OCID·IP 유지; 서비스가 정지→교체→재시작)
oci compute instance update --instance-id <instance_ocid> \
  --source-details '{"sourceType":"image","imageId":"ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalxokbvhkaibe6ieaosyvzxih2xyglm3ypyiedbg3x4rpifmauw5a","bootVolumeSizeInGBs":100,"isPreserveBootVolumeEnabled":true}' \
  --update-operation-constraint ALLOW_DOWNTIME --wait-for-state RUNNING --force
# 최소 IAM: allow group X to {INSTANCE_BOOT_VOLUME_REPLACE} in compartment C (또는 manage instance-family)
```

**NSG: Cloudflare IP → 443, 클러스터 내부 자기참조** — <https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/core_network_security_group_security_rule.html>
```
data "cloudflare_ip_ranges" "cf" {}
locals {
  cf_cidrs = toset(concat(data.cloudflare_ip_ranges.cf.ipv4_cidrs, data.cloudflare_ip_ranges.cf.ipv6_cidrs)) # 15 + 7 = 22
}

resource "oci_core_network_security_group" "node_a" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "nsg-node-a-platform"
}
resource "oci_core_network_security_group_security_rule" "cf_https" {
  for_each                  = local.cf_cidrs
  network_security_group_id = oci_core_network_security_group.node_a.id
  direction   = "INGRESS"
  protocol    = "6"
  source_type = "CIDR_BLOCK"
  source      = each.value
  description = "Cloudflare edge -> Traefik 443"
  tcp_options { destination_port_range { min = 443  max = 443 } }
}

resource "oci_core_network_security_group" "cluster" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "nsg-cluster"
}
resource "oci_core_network_security_group_security_rule" "cluster_self" {
  network_security_group_id = oci_core_network_security_group.cluster.id
  direction   = "INGRESS"
  protocol    = "all"
  source_type = "NETWORK_SECURITY_GROUP"
  source      = oci_core_network_security_group.cluster.id   # K3s 6443/10250/8472 등 노드 간
}
# 보안 리스트 대안(참고): ingress_security_rules { protocol="6" source=each.value tcp_options { min=443 max=443 } } — min/max가 tcp_options 바로 아래
```

**Object Storage 버킷 + Customer Secret Key + KMS + 동적 그룹/정책** — <https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/kms_key.html>
```
data "oci_objectstorage_namespace" "ns" { compartment_id = var.tenancy_ocid }

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "jt-tfstate"
  versioning     = "Enabled"      # 생성 시 Enabled/Disabled, 이후 Suspended 가능
  access_type    = "NoPublicAccess"
}
resource "oci_objectstorage_bucket" "backup" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = "jt-backup"
  versioning     = "Disabled"
}

# barman-cloud(S3 호환)용 — 전용 IAM 사용자, 사용자당 최대 2개, key는 생성 시에만
resource "oci_identity_customer_secret_key" "backup_s3" {
  user_id      = var.backup_user_ocid
  display_name = "jt-backup-barman"
}
output "backup_s3_access_key" { value = oci_identity_customer_secret_key.backup_s3.id  sensitive = true }
output "backup_s3_secret_key" { value = oci_identity_customer_secret_key.backup_s3.key sensitive = true }

resource "oci_kms_vault" "platform" {
  compartment_id = var.compartment_ocid
  display_name   = "jt-vault"
  vault_type     = "DEFAULT"
}
resource "oci_kms_key" "vault_unseal" {
  compartment_id      = var.compartment_ocid
  display_name        = "hashicorp-vault-unseal"
  management_endpoint = oci_kms_vault.platform.management_endpoint
  protection_mode     = "HSM"          # HSM 키 버전 20개까지 무료(테넌시 합산)
  key_shape { algorithm = "AES"  length = 32 }
  is_auto_rotation_enabled = false     # 회전 = 키 버전 소모
}
output "vault_seal" {
  value = {
    key_id              = oci_kms_key.vault_unseal.id
    crypto_endpoint     = oci_kms_vault.platform.crypto_endpoint
    management_endpoint = oci_kms_vault.platform.management_endpoint
  }
}

resource "oci_identity_dynamic_group" "k3s_nodes" {
  compartment_id = var.tenancy_ocid
  name           = "jt-k3s-nodes"
  description    = "K3s nodes (instance principal)"
  matching_rule  = "Any {instance.id = '${oci_core_instance.node_a.id}', instance.id = '${oci_core_instance.node_b.id}'}"
}
resource "oci_identity_policy" "k3s_nodes" {
  compartment_id = var.compartment_ocid
  name           = "jt-k3s-nodes"
  description    = "Vault auto-unseal + backup bucket"
  statements = [
    "Allow dynamic-group jt-k3s-nodes to use keys in compartment ${var.compartment_name} where target.key.id = '${oci_kms_key.vault_unseal.id}'",
    "Allow dynamic-group jt-k3s-nodes to read buckets in compartment ${var.compartment_name}",
    "Allow dynamic-group jt-k3s-nodes to manage objects in compartment ${var.compartment_name} where target.bucket.name = 'jt-backup'",
  ]
}

# Vault 측 seal(참고): seal "ocikms" { key_id = ... crypto_endpoint = ... management_endpoint = ... }  # auth_type_api_key 미설정 = 인스턴스 프린시펄
```

**Budgets** — <https://docs.oracle.com/en-us/iaas/tools/terraform-provider-oci/latest/docs/r/budget_alert_rule.html>
```
resource "oci_budget_budget" "monthly" {
  compartment_id = var.tenancy_ocid      # 예산은 루트 컴파트먼트에만
  display_name   = "jt-monthly"
  description    = "joshuatech v2 platform"
  amount         = 20                    # SGD 정수(PAYG 테넌시 통화)
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.tenancy_ocid]
}
resource "oci_budget_alert_rule" "actual_80" {
  budget_id      = oci_budget_budget.monthly.id
  display_name   = "actual-80pct"
  type           = "ACTUAL"
  threshold      = 80
  threshold_type = "PERCENTAGE"
  recipients     = var.alert_email       # 쉼표/공백/세미콜론 구분 다중 가능
  message        = "OCI 월 예산 80% 도달"
}
resource "oci_budget_alert_rule" "forecast_100" {
  budget_id      = oci_budget_budget.monthly.id
  display_name   = "forecast-100pct"
  type           = "FORECAST"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = var.alert_email
  message        = "OCI 월 예산 100% 초과 예상"
}
# IAM: Allow group <admins> to manage usage-budgets in tenancy
```

### 함정

- provider는 source_details.source_id가 바뀌면 무조건 'in-place'로 plan하고 UpdateInstance를 호출한다 — OCI가 거부하는 경우(Windows/마켓플레이스 이미지, 다른 배포판)는 apply 단계에서야 실패(oracle/terraform-provider-oci#2136, 여전히 open). Linux→Linux는 정상(2025-11 보고, 7.27.0). 반드시 joshtech_cache로 먼저 리허설.
- source_id를 data.oci_core_images '최신'으로 두면 월간 이미지 갱신마다 부트 볼륨 교체(노드 초기화)가 plan에 뜬다 — OCID 고정 필수. OCID는 리전별(ap-chuncheon-1 값만 유효).
- UpdateInstance는 metadata의 user_data·ssh_authorized_keys 변경을 거부한다 — 새 볼륨의 cloud-init은 2025-05 생성 시 값(있다면 v1 user_data 포함)을 그대로 실행. K3s 부트스트랩은 SSH 경로로.
- 부트 볼륨 교체 중 인스턴스가 정지·재시작된다(다운타임) — is_preserve_boot_volume_enabled=true면 구 50 GB 볼륨 2개가 남아 스토리지가 일시 2배(100 GB×2 + 50 GB×2). 검증 후 수동 삭제(과금·Always Free 200 GB 블록 한도).
- OCI 문서상 교체는 '같은 Linux 배포판'만 허용(OL↔Ubuntu 불가). 같은 배포판의 버전 변경(22.04→24.04)은 명시되지 않음. 이미지 launch options(PARAVIRTUALIZED)가 인스턴스와 맞아야 함.
- OCI S3 compat: SigV4만, 체크섬 미지원 → skip_s3_checksum=true 없으면 PutObject 400(x-amz-content-sha256). Terraform 1.11.2+/최신 aws-sdk-go-v2 기본 CRC32 체크섬 때문에 AWS_REQUEST_CHECKSUM_CALCULATION=when_required·AWS_RESPONSE_CHECKSUM_VALIDATION=when_required가 추가로 필요했던 보고(#2348) — OpenTofu 1.12에서 필요 여부 미확인, 환경변수는 무해하니 CI에 넣어둘 것.
- use_lockfile(네이티브 S3 잠금)은 If-None-Match 조건부 쓰기가 필요 — OCI compat 지원 요청 이슈 #2323가 open, OpenTofu #4405(R2)처럼 호환 엔드포인트에서 412 자기잠금 사례도 있음 → 잠금 없이 운영하고 CI concurrency로 직렬화.
- Customer Secret Key는 사용자당 2개, secret은 생성 시 1회만 노출되며 OpenTofu 리소스로 만들면 tfstate에 평문 저장 → 상태 버킷은 NoPublicAccess+versioning, 상태용 키는 CLI로 별도 생성.
- KMS: HSM 키 버전은 테넌시 합산 20개까지 무료(Always Free 표), 그 이상 유료(약 $0.53/버전/월, 미검증) — 자동 회전 끄기. 키·볼트 삭제는 즉시가 아니라 pending deletion(스케줄) → tofu destroy 후에도 남음. VIRTUAL_PRIVATE는 시간 과금·Always Free 제외.
- 한도: 보안 리스트 ingress/egress 각 200(증설 불가), 서브넷당 5개; NSG 규칙 120(ingress+egress), VNIC당 NSG 5개; NSG 규칙 단일 호출 25개 제한(provider는 리소스당 1개라 무관). NSG는 VNIC에 nsg_ids로 붙여야 효력.
- Cloudflare IPv6 7개 규칙은 VCN/서브넷에 IPv6가 없고 오리진 레코드가 A뿐이면 무의미(넣어도 무해). Cloudflare 대역은 바뀔 수 있음 → data source로 매 plan마다 갱신.
- import 후 첫 plan에서 create_vnic_details(primary VNIC에서 채움)·metadata·defined_tags(Oracle-Tags)·hostname_label(top-level은 deprecated) diff가 흔함 — ignore_changes로 흡수하되 source_details·shape diff는 절대 무시하지 말 것. -generate-config-out은 실험적이며 for_each import와 병용 불가.
- 동적 그룹 matching_rule 변경 반영에 최대 ~1시간; 테넌시당 동적 그룹 50개·인스턴스당 5개. Identity Domains 테넌시에서 legacy oci_identity_dynamic_group은 Default 도메인에만 해당.
- 예산은 루트 컴파트먼트 전용, 평가가 주기적(실시간 아님)이라 급증 비용은 놓칠 수 있음. barman-cloud는 S3 호환 경로(액세스 키)라 동적 그룹의 manage objects 정책은 인스턴스 프린시펄 도구(oci CLI/SDK)에만 쓰인다.
- CLI --source-details의 sourceType 값은 API 표기 "image"/"bootVolume"(대문자 IMAGE 아님). 새 부트 볼륨 최소 50 GB.
- OpenTofu prevent_destroy는 1.12부터 동적 표현식 허용 — 재이미지 작업 동안에도 true 유지(교체는 update이므로 충돌 없음).

### 미확인

- OCI S3 compat API가 PutObject If-None-Match(조건부 쓰기)를 지원하는지 — `aws s3api put-object --if-none-match '*'`로 compat 엔드포인트에 직접 테스트 후 use_lockfile 결정.
- OpenTofu 1.12.6의 S3 백엔드가 OCI에서 AWS_REQUEST_CHECKSUM_CALCULATION=when_required 없이 저장되는지(Terraform 1.11.2+ 보고 #2348은 필요) — 부트스트랩 단계에서 실측.
- 기존 VM의 정확한 Ubuntu 버전과 metadata(user_data 존재 여부) — `oci compute instance get`으로 확인; 22.04→24.04 교체가 '같은 배포판' 규칙에 걸리는지 joshtech_cache 리허설로 검증.
- 테넌시 joshua92y가 Identity Domains(Default 도메인) 구성인지 — legacy oci_identity_dynamic_group / oci_identity_customer_secret_key가 그대로 동작하는지 확인.
- VCN/서브넷 IPv6 활성 여부(Cloudflare IPv6 규칙 필요성)와 Chuncheon PAYG에서 Always Free 블록 스토리지 200 GB 무료분 적용 여부(구 볼륨 보존 기간 비용).
- HSM 키 버전 21개째부터의 단가(pricing 페이지 403으로 미확인; 검색 결과 $0.53/버전/월).
- 예산 1개당 alert rule 최대 수(문서에 명시 없음).
- 교체 직후 새 볼륨의 cloud-init이 같은 인스턴스 OCID로 '첫 부팅'으로 동작해 ssh_authorized_keys를 주입하는지(문서 미기재, 논리상 그렇게 동작) — 리허설에서 SSH 접속으로 확인.
- OCI 블로그 'Terraform state locking on OCI'(2026)가 사이트 오류로 열리지 않아 Oracle 측 최신 권고(토큰 인증·잠금) 미확인.


## R12 OpenTofu Cloudflare

R12 Cloudflare: OpenTofu provider 5.x 리소스 이름, Access(Service Auth/GitHub IdP), AOP, Workers 커스텀 도메인, cloudflared on K8s, Image Transformations, 계정 소유 토큰, Pages→Workers 도메인 이전

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| cloudflare/cloudflare Terraform/OpenTofu provider | 5.24.0 | 2026-08-24 (GitHub release; CHANGELOG 표기 2026-08-20). OpenTofu registry에도 5.24.0 존재(linux/arm64 포함) | <https://github.com/cloudflare/terraform-provider-cloudflare/releases/tag/v5.24.0> |
| cloudflared (server/client, Docker image cloudflare/cloudflared) | 2026.8.3 | 2026-08-31 (GitHub release publish; RELEASE_NOTES 2026-08-28). Docker Hub 태그 2026.8.3 = linux/amd64 + linux/arm64 | <https://github.com/cloudflare/cloudflared/releases/tag/2026.8.3> |
| cloudflare/wrangler-action | v4.0.0 (기본 Wrangler v4) | 2026-05-12 | <https://github.com/cloudflare/wrangler-action/releases/tag/v4.0.0> |
| wrangler | 4.127.1 (CHANGELOG 최상단) | 2026-08 (CHANGELOG 기준) | <https://github.com/cloudflare/workers-sdk/blob/main/packages/wrangler/CHANGELOG.md> |
| OpenTofu | 1.12.6 (write-only attribute는 1.11+ 필요) | 2026-08-19 | <https://github.com/opentofu/opentofu/releases/tag/v1.12.6> |
| Access Service Token client secret 형식 | cfast_[40자][8자 checksum] (2026-08 이후 신규 발급분; 기존 64자 hex도 유효) | 2026-08 | <https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/> |

### 결정

**CLOUDFLARE-TOFU-D1. provider 버전·리소스 이름 체계(5.x)를 무엇으로 고정하나?**

- Decision: `cloudflare/cloudflare ~> 5.24` + OpenTofu >= 1.11(실사용 1.12.6). 리소스: `cloudflare_dns_record`, `cloudflare_zone_setting`(setting_id=ssl/always_use_https/min_tls_version/tls_client_auth), `cloudflare_zero_trust_access_application`/`_policy`/`_service_token`/`_identity_provider`, `cloudflare_authenticated_origin_pulls`(+`_settings`, `_certificate`), `cloudflare_workers_custom_domain`, `cloudflare_r2_bucket`/`cloudflare_r2_custom_domain`, `cloudflare_zero_trust_tunnel_cloudflared`/`_config` + data `cloudflare_zero_trust_tunnel_cloudflared_token`, data `cloudflare_ip_ranges`.
- Rationale: 5.x는 OpenAPI 코드 생성 기반으로 2~3주마다 릴리스되며 5.22에서 workers_custom_domain·authenticated_origin_pulls의 v4→v5 state upgrader가 들어감. 5.6+는 write-only 속성(`config.client_secret`)을 써서 OpenTofu 1.10 이하에서는 오류.
- Alternatives considered: 4.52.x(유지보수만, 리소스명 구식 `cloudflare_record`/`cloudflare_access_*`); cf-terraforming/tf-migrate로 v4 → v5 변환.
- Source: <https://github.com/cloudflare/terraform-provider-cloudflare/blob/main/CHANGELOG.md>

**CLOUDFLARE-TOFU-D2. Access 정책 모델: pod API(서비스 토큰 전용)와 admin(GitHub IdP)을 어떻게 나누나?**

- Decision: 계정 스코프 재사용 정책 2종: (a) `decision = "non_identity"`(UI의 Service Auth) + `include.service_token.token_id`; (b) `decision = "allow"` + `include.email` + `require.login_method`(GitHub IdP id). 앱은 `type = "self_hosted"`, `policies = [{ id, precedence }]`로 참조. API 앱은 `service_auth_401_redirect = true`, admin 앱은 `allowed_idps=[github]` + `auto_redirect_to_identity = true`.
- Rationale: Access는 deny-by-default; 서비스 토큰은 Allow 정책이면 IdP 로그인으로 리다이렉트되므로 반드시 Service Auth. Bypass/Service Auth가 먼저 평가되고 그다음 Block/Allow. 서비스 토큰은 seat를 소비하지 않음(Free 50석 보존).
- Alternatives considered: `any_valid_service_token = {}`(모든 토큰 허용 — 토큰 단위 분리 불가); `github_organization`(org 필요, 개인 계정이면 부적합); 앱 inline policy(재사용 불가).
- Source: <https://developers.cloudflare.com/cloudflare-one/access-controls/policies/>

**CLOUDFLARE-TOFU-D3. Zero Trust Free 플랜 조건은?**

- Decision: Free = 50 seats. 온보딩 시 팀 이름 + 플랜 선택 + 결제수단 입력이 필수(무료여도 카드 등록, 청구 없음). 팀 도메인 생성은 대시보드에서 먼저 수행하고 OpenTofu는 그 이후 리소스만 관리.
- Rationale: 공식 setup 문서: "If you chose the Zero Trust Free plan, this step is still needed but you will not be charged." 계정 한도: Access 앱 500, 재사용 정책 500, 서비스 토큰 50, IdP 50, 터널 1,000.
- Alternatives considered: Standard $7/user/월(불필요); `cloudflare_zero_trust_organization` 리소스(import 미지원이라 신규 생성 전용).
- Source: <https://developers.cloudflare.com/cloudflare-one/setup/>

**CLOUDFLARE-TOFU-D4. Authenticated Origin Pulls는 global/zone-level/per-hostname 중 무엇으로?**

- Decision: 1단계는 global AOP: `cloudflare_zone_setting` `tls_client_auth = "on"` + Traefik `TLSOption`(RequireAndVerifyClientCert, CA = authenticated_origin_pull_ca.pem). SSL 모드 `strict` 필수. 원본 IP 제한(OCI 보안 리스트 = `cloudflare_ip_ranges`)과 조합.
- Rationale: global 인증서는 "Cloudflare 네트워크에서 온 요청"만 보증(모든 고객 공유). 계정 단위 보증이 필요하면 zone-level(`cloudflare_authenticated_origin_pulls_settings` + 직접 발급한 leaf cert 업로드 `_certificate`)로 승격 — 인증서 수명 관리가 추가되므로 SP-1 범위 밖.
- Alternatives considered: zone-level AOP(자체 CA 운영), per-hostname AOP(`cloudflare_authenticated_origin_pulls` config[{hostname, cert_id, enabled}]), Cloudflare Tunnel로 앱 트래픽까지 넣기(설계상 터널은 관리 전용).
- Source: <https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/set-up/global/>

**CLOUDFLARE-TOFU-D5. Workers 커스텀 도메인은 Custom Domain과 Route 중 무엇으로, 누가 관리하나?**

- Decision: `cloudflare_workers_custom_domain`(account_id, zone_id, zone_name, hostname, service)로 OpenTofu가 관리. wrangler 쪽 `routes[].custom_domain`은 쓰지 않음(이중 관리 방지). CI 토큰은 Workers Scripts:Edit만.
- Rationale: Custom Domain은 DNS 레코드+Advanced cert를 Cloudflare가 자동 생성하고 Worker가 origin이 됨. 같은 hostname에 기존 CNAME이 있으면 생성 실패하므로 해당 hostname의 `cloudflare_dns_record`는 두지 않음. 도메인 삭제 시 인증서는 남음(수동 삭제).
- Alternatives considered: Workers Route(`cloudflare_workers_route`, proxied DNS 레코드 선행 필요, 같은 hostname에선 Route가 Custom Domain보다 우선); wrangler가 배포 시 도메인 부착.
- Source: <https://developers.cloudflare.com/workers/configuration/routing/custom-domains/>

**CLOUDFLARE-TOFU-D6. R2 버킷과 cdn.joshuatech.dev 커스텀 도메인 조건은?**

- Decision: `cloudflare_r2_bucket`(location="apac", jurisdiction 기본) + `cloudflare_r2_custom_domain`(domain="cdn.joshuatech.dev", zone_id=joshuatech.dev, enabled=true, min_tls="1.2"). r2.dev 공개 URL은 비활성 유지.
- Rationale: 커스텀 도메인은 "같은 계정의 zone"이어야 하며 연결 시 proxied DNS 레코드가 자동 생성됨. 커스텀 도메인과 r2.dev는 독립 스위치. 기본 캐시는 특정 파일 타입만 → Cache Rule(Cache Everything) 필요.
- Alternatives considered: Worker 바인딩으로 R2 서빙(Workers Free 요청 한도 소모); r2.dev(캐시·커스텀 도메인 없음, 레이트 리밋).
- Source: <https://developers.cloudflare.com/r2/buckets/public-buckets/>

**CLOUDFLARE-TOFU-D7. 관리용 터널(SSH/kubectl)의 리소스·토큰 전달 경로는?**

- Decision: `cloudflare_zero_trust_tunnel_cloudflared`(config_src="cloudflare") + `_config` ingress(`ssh://<노드 private IP>:22`, `tcp://kubernetes.default.svc.cluster.local:443`, 마지막 `http_status:404`) + data `cloudflare_zero_trust_tunnel_cloudflared_token` → 토큰을 Vault kv에 저장 → ESO `ExternalSecret` → Secret `tunnel-token`. 각 hostname은 `cloudflare_dns_record` CNAME `<tunnel_id>.cfargotunnel.com`(proxied).
- Rationale: 원격 관리 터널은 API 순서(POST cfd_tunnel → GET token → PUT configurations → CNAME)를 provider가 그대로 감쌈. gitops repo는 public이므로 ExternalSecret만 커밋.
- Alternatives considered: 로컬 관리 터널(config.yml + credentials.json, config_src="local"); `cloudflared tunnel token` CLI로 수동 주입.
- Source: <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel-api/>

**CLOUDFLARE-TOFU-D8. cloudflared를 K8s에 어떻게 배포하나(이미지·replica·배치)?**

- Decision: 공식 이미지 `cloudflare/cloudflared:2026.8.3`(태그 고정, arm64), `tunnel --no-autoupdate --metrics 0.0.0.0:2000 run`, `TUNNEL_TOKEN` env(secretKeyRef), replicas=2, `podAntiAffinity requiredDuringScheduling`(hostname), nodeSelector 없이 두 노드에 분산, liveness `/ready:2000`.
- Rationale: 공식 매니페스트 기준. 2 replica는 HA 전용(부하분산 아님). 관리 터널의 목적이 노드 A 장애 시 접근 확보이므로 role=platform 고정 대신 양 노드 분산이 맞음(required anti-affinity + nodeSelector=platform은 1개 Pending). `--token` 인자는 ps에 노출되므로 env 사용(2026.7.x에서 서비스 설치가 `--token-file`로 이동한 배경).
- Alternatives considered: community-charts cloudflared Helm 차트; hostNetwork DaemonSet; `--protocol http2` 고정(UDP 7844 차단 환경).
- Source: <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/deployment-guides/kubernetes/>

**CLOUDFLARE-TOFU-D9. SSH/kubectl 클라이언트 접속 방식은?**

- Decision: SSH: `~/.ssh/config`에 `ProxyCommand cloudflared access ssh --hostname %h`. kubectl: `cloudflared access tcp --hostname kube.joshuatech.dev --url 127.0.0.1:6443` 백그라운드 + kubeconfig `server: https://127.0.0.1:6443`, `tls-server-name: kubernetes`(K3s 인증서 SAN). 인증은 GitHub IdP 브라우저 플로우(admin). 비대화형은 `TUNNEL_SERVICE_TOKEN_ID/SECRET` env.
- Rationale: 공식 arbitrary-TCP 가이드 방식이며 WARP 클라이언트 등록이 불필요. 공식 kubectl 튜토리얼의 client-go exec plugin(`cloudflared access token -app=`)은 API 서버가 Access JWT를 검증하도록 OIDC 설정이 필요해 K3s 기본에는 과함.
- Alternatives considered: WARP-to-Tunnel 사설망(WARP 등록 필요, Gateway 정책); Access for Infrastructure(SSH 명령 로깅, 단기 인증서); 브라우저 렌더링 SSH.
- Source: <https://developers.cloudflare.com/cloudflare-one/access-controls/applications/non-http/cloudflared-authentication/arbitrary-tcp/>

**CLOUDFLARE-TOFU-D10. Image Transformations를 어떻게 켜고 Next.js에서 쓰나?**

- Decision: 대시보드 Images > Transformations > joshuatech.dev zone Enable, Sources는 기본(same zone)로 유지 — cdn.joshuatech.dev는 같은 zone의 서브도메인이라 allowlist 불필요. Next.js `images.loader = "custom"` + `image-loader.ts`가 `/cdn-cgi/image/width=…,quality=…,format=auto/<src>` 생성(OpenNext 공식 예). R2 원본은 절대 URL `https://cdn.joshuatech.dev/...`.
- Rationale: URL 방식은 zone 활성화 필요, 기본 소스 정책은 "같은 zone(서브도메인 허용)". Free 5,000 unique transformations/월, format 변형은 1회로 계산. 커스텀 로더는 `remotePatterns`를 검사하지 않으므로 대시보드 소스 제한이 실질 방어선.
- Alternatives considered: Worker `fetch(..., {cf:{image:{}}})`(zone 활성화 불필요, Worker 요청 한도 소모); next/image 기본 최적화(OpenNext Workers에서 미지원); "Resize from any origin"(제3자가 우리 zone에서 변환 남용 가능).
- Source: <https://opennext.js.org/cloudflare/howtos/image>

**CLOUDFLARE-TOFU-D11. Workers 배포용 CI 토큰은 사용자 토큰과 계정 소유 토큰(cfat_) 중 무엇으로, 최소 권한은?**

- Decision: 계정 소유 토큰(`cfat_`), 대시보드 Manage Account > Account API Tokens > Create Token, 권한 = Account · Workers Scripts · Edit 단일, 리소스 = 해당 계정 1개. `CLOUDFLARE_ACCOUNT_ID`를 secrets로 함께 주입. 커스텀 도메인/R2/DNS는 OpenTofu 토큰(별도, DNS Write·SSL Write·Workers Scripts Write·Workers R2 Storage Write·Access Write)로 분리.
- Rationale: 계정 토큰은 특정 사용자에 묶이지 않는 service principal(호환 매트릭스에 Workers/Pages/R2/Access/Tunnel/DNS/SSL 지원). Workers custom domain API(PUT /accounts/{id}/workers/domains)도 Workers Scripts Write만 요구하지만 CI에서 도메인을 만지지 않으므로 제외. 생성에는 Super Administrator 필요.
- Alternatives considered: 사용자 토큰 템플릿 "Edit Cloudflare Workers"(D1/KV/Pages 등 초과 권한); wrangler OAuth 로그인(CI 불가).
- Source: <https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/>

**CLOUDFLARE-TOFU-D12. 기존 Pages 프로젝트의 joshuatech.dev를 Workers 커스텀 도메인으로 어떻게 옮기고 다운타임은?**

- Decision: 스크립트로 원자적 전환(계획된 수 초 다운타임): (1) Worker를 workers.dev/preview alias에 배포·검증 → (2) `DELETE /accounts/{a}/pages/projects/{p}/domains/{d}` → (3) `DELETE /zones/{z}/dns_records/{id}`(Pages가 만든 CNAME → <proj>.pages.dev) → (4) `PUT /accounts/{a}/workers/domains {hostname, service, zone_id}` → (5) `tofu import cloudflare_workers_custom_domain.web <account_id>/<domain_id>`. www도 동일 반복. 전환 후 Pages 프로젝트는 며칠 두었다가 삭제.
- Rationale: Pages에 붙은 동안 CNAME 편집·Workers 도메인 추가가 불가, Workers Custom Domain은 기존 CNAME이 있으면 생성 거부(공식). 커뮤니티 측정치 2–5초. Universal cert가 apex + *.joshuatech.dev를 이미 커버해 TLS 공백 없음(Advanced cert는 백그라운드 발급).
- Alternatives considered: Workers Route(POST /zones/{z}/workers/routes)를 기존 proxied CNAME 위에 얹어 먼저 트래픽을 가로챈 뒤 Pages 도메인을 해제 — 무중단 가설이나 미검증(open 참조); Pages 유지(신규 기능 동결 상태).
- Source: <https://developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/>

### 설정 스니펫

**versions.tf — provider 고정(OpenTofu)** — <https://github.com/cloudflare/terraform-provider-cloudflare/releases/tag/v5.24.0>
```
terraform {
  required_version = ">= 1.11" # write-only attrs (client_secret)
  required_providers {
    cloudflare = { source = "cloudflare/cloudflare", version = "~> 5.24" }
  }
}
provider "cloudflare" {} # CLOUDFLARE_API_TOKEN env
```

**zone.tf — SSL strict, AOP(global), DNS, Cloudflare IP 목록** — <https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zone_setting.md>
```
resource "cloudflare_zone_setting" "ssl"      { zone_id = var.zone_id  setting_id = "ssl"              value = "strict" }
resource "cloudflare_zone_setting" "https"    { zone_id = var.zone_id  setting_id = "always_use_https" value = "on" }
resource "cloudflare_zone_setting" "min_tls"  { zone_id = var.zone_id  setting_id = "min_tls_version"  value = "1.2" }
resource "cloudflare_zone_setting" "aop"      { zone_id = var.zone_id  setting_id = "tls_client_auth"  value = "on" } # global AOP

resource "cloudflare_dns_record" "api" {
  zone_id = var.zone_id
  name    = "api"          # api.joshuatech.dev -> node A
  type    = "A"
  content = var.node_a_public_ip
  ttl     = 1              # 1 = automatic (proxied)
  proxied = true
}

data "cloudflare_ip_ranges" "cf" {}
output "cf_ipv4_cidrs" { value = data.cloudflare_ip_ranges.cf.ipv4_cidrs } # -> OCI security list ingress 443
```

**access.tf — GitHub IdP, 서비스 토큰, Service Auth/Allow 정책, 앱** — <https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zero_trust_access_policy.md>
```
resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = var.account_id
  name       = "GitHub"
  type       = "github"
  config     = { client_id = var.gh_oauth_client_id, client_secret = var.gh_oauth_client_secret } # callback: https://<team>.cloudflareaccess.com/cdn-cgi/access/callback
}

resource "cloudflare_zero_trust_access_service_token" "pod_api" {
  account_id = var.account_id
  name       = "pod-api"
  duration   = "8760h"
}

resource "cloudflare_zero_trust_access_policy" "admin_github" {
  account_id       = var.account_id
  name             = "admin-github"
  decision         = "allow"
  session_duration = "24h" # 5.24: 기본값 없음, 명시
  include = [{ email = { email = var.admin_email } }]
  require = [{ login_method = { id = cloudflare_zero_trust_access_identity_provider.github.id } }]
}

resource "cloudflare_zero_trust_access_policy" "service_auth" {
  account_id = var.account_id
  name       = "pod-api-service-token"
  decision   = "non_identity" # UI: Service Auth
  include    = [{ service_token = { token_id = cloudflare_zero_trust_access_service_token.pod_api.id } }]
}

resource "cloudflare_zero_trust_access_application" "kube" {
  account_id                = var.account_id
  name                      = "kube-api"
  type                      = "self_hosted"
  domain                    = "kube.joshuatech.dev"
  destinations              = [{ type = "public", uri = "kube.joshuatech.dev" }]
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id]
  auto_redirect_to_identity = true
  session_duration          = "24h"
  policies = [{ id = cloudflare_zero_trust_access_policy.admin_github.id, precedence = 1 }]
}

resource "cloudflare_zero_trust_access_application" "pod_api" {
  account_id                = var.account_id
  name                      = "pod-api"
  type                      = "self_hosted"
  domain                    = "api.joshuatech.dev"
  destinations              = [{ type = "public", uri = "api.joshuatech.dev" }]
  service_auth_401_redirect = true # 로그인 페이지 대신 401
  policies = [{ id = cloudflare_zero_trust_access_policy.service_auth.id, precedence = 1 }]
}
# 호출: curl -H "CF-Access-Client-Id: $ID" -H "CF-Access-Client-Secret: $SECRET" https://api.joshuatech.dev/
```

**tunnel.tf — 원격 관리 터널 + ingress + 토큰 + CNAME** — <https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zero_trust_tunnel_cloudflared_config.md>
```
resource "cloudflare_zero_trust_tunnel_cloudflared" "mgmt" {
  account_id = var.account_id
  name       = "joshuatech-mgmt"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "mgmt" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.mgmt.id
  config = {
    ingress = [
      { hostname = "ssh-a.joshuatech.dev", service = "ssh://${var.node_a_private_ip}:22" },
      { hostname = "ssh-b.joshuatech.dev", service = "ssh://${var.node_b_private_ip}:22" },
      { hostname = "kube.joshuatech.dev",  service = "tcp://kubernetes.default.svc.cluster.local:443" },
      { service = "http_status:404" },
    ]
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "mgmt" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.mgmt.id
}

resource "cloudflare_dns_record" "tunnel" {
  for_each = toset(["ssh-a", "ssh-b", "kube"])
  zone_id  = var.zone_id
  name     = each.key
  type     = "CNAME"
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.mgmt.id}.cfargotunnel.com"
  ttl      = 1
  proxied  = true
}

output "tunnel_token" { value = data.cloudflare_zero_trust_tunnel_cloudflared_token.mgmt.token  sensitive = true } # -> Vault kv cloudflare/tunnel
```

**workers-r2.tf — Workers 커스텀 도메인, R2 버킷/커스텀 도메인** — <https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/r2_custom_domain.md>
```
resource "cloudflare_workers_custom_domain" "web" {
  account_id = var.account_id
  zone_id    = var.zone_id
  zone_name  = "joshuatech.dev"
  hostname   = "joshuatech.dev"   # 기존 CNAME이 있으면 생성 실패
  service    = "joshuatech-web"   # wrangler.jsonc name
}

resource "cloudflare_r2_bucket" "cdn" {
  account_id = var.account_id
  name       = "joshuatech-cdn"
  location   = "apac"
}

resource "cloudflare_r2_custom_domain" "cdn" {
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.cdn.name
  domain      = "cdn.joshuatech.dev"
  zone_id     = var.zone_id      # 같은 계정의 zone 필수
  enabled     = true
  min_tls     = "1.2"
}
```

**cloudflared Deployment (gitops: platform/cloudflared)** — <https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/deployment-guides/kubernetes/>
```
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata: { name: tunnel-token, namespace: cloudflared }
spec:
  secretStoreRef: { name: vault, kind: ClusterSecretStore }
  target: { name: tunnel-token }
  data:
    - secretKey: token
      remoteRef: { key: cloudflare/tunnel, property: token }
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: cloudflared, namespace: cloudflared }
spec:
  replicas: 2
  selector: { matchLabels: { app: cloudflared } }
  template:
    metadata: { labels: { app: cloudflared } }
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector: { matchLabels: { app: cloudflared } }
              topologyKey: kubernetes.io/hostname
      containers:
        - name: cloudflared
          image: cloudflare/cloudflared:2026.8.3   # 태그 고정, linux/arm64 지원
          args: ["tunnel", "--no-autoupdate", "--loglevel", "info", "--metrics", "0.0.0.0:2000", "run"]
          env:
            - name: TUNNEL_TOKEN
              valueFrom: { secretKeyRef: { name: tunnel-token, key: token } }
          ports: [{ name: metrics, containerPort: 2000 }]
          livenessProbe:
            httpGet: { path: /ready, port: 2000 }
            failureThreshold: 1
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests: { cpu: 20m, memory: 32Mi }
            limits: { memory: 128Mi }
# egress: 7844 TCP/UDP -> region1/region2.v2.argotunnel.com, 443 -> api.cloudflare.com
```

**클라이언트: SSH ProxyCommand + kubectl via cloudflared access tcp** — <https://raw.githubusercontent.com/cloudflare/cloudflared/master/cmd/cloudflared/access/cmd.go>
```
# ~/.ssh/config
Host ssh-a.joshuatech.dev ssh-b.joshuatech.dev
  User ubuntu
  ProxyCommand cloudflared access ssh --hostname %h

# kubectl (터미널 1)
cloudflared access tcp --hostname kube.joshuatech.dev --url 127.0.0.1:6443
# 비대화형(CI/스크립트): export TUNNEL_SERVICE_TOKEN_ID=... TUNNEL_SERVICE_TOKEN_SECRET=...

# ~/.kube/joshuatech.yaml (K3s /etc/rancher/k3s/k3s.yaml의 CA/클라이언트 인증서 재사용)
apiVersion: v1
kind: Config
clusters:
- name: joshuatech
  cluster:
    server: https://127.0.0.1:6443
    tls-server-name: kubernetes        # K3s API 인증서 SAN
    certificate-authority-data: <k3s CA>
users:
- name: admin
  user: { client-certificate-data: <...>, client-key-data: <...> }
contexts:
- name: joshuatech
  context: { cluster: joshuatech, user: admin }
current-context: joshuatech
```

**Traefik TLSOption — global AOP 클라이언트 인증서 요구** — <https://doc.traefik.io/traefik/reference/routing-configuration/http/tls/tls-options/>
```
# curl -o aop-ca.pem https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem
# kubectl -n traefik create secret generic cloudflare-aop-ca --from-file=tls.ca=aop-ca.pem   # 키 이름은 open 항목 참조
apiVersion: traefik.io/v1alpha1
kind: TLSOption
metadata: { name: default, namespace: traefik }   # name=default -> 모든 TLS 라우터에 적용
spec:
  minVersion: VersionTLS12
  clientAuth:
    secretNames: [cloudflare-aop-ca]
    clientAuthType: RequireAndVerifyClientCert
# 검증: 직접 접속 curl https://api.joshuatech.dev --resolve api.joshuatech.dev:443:<node IP> -> TLS handshake 실패, 프록시 경유 -> 200
```

**Next.js 16 image-loader.ts + next.config.ts (OpenNext 공식)** — <https://opennext.js.org/cloudflare/howtos/image>
```
// image-loader.ts
import type { ImageLoaderProps } from "next/image";
const normalizeSrc = (src: string) => (src.startsWith("/") ? src.slice(1) : src);
export default function cloudflareLoader({ src, width, quality }: ImageLoaderProps) {
  const params = [`width=${width}`, "format=auto"];
  if (quality) params.push(`quality=${quality}`);
  if (process.env.NODE_ENV === "development") return `${src}?${params.join("&")}`;
  return `/cdn-cgi/image/${params.join(",")}/${normalizeSrc(src)}`;
}
// next.config.ts
const nextConfig: NextConfig = { images: { loader: "custom", loaderFile: "./image-loader.ts" } };
// 사용: <Image src="https://cdn.joshuatech.dev/posts/a.jpg" width={800} height={450} .../> -> /cdn-cgi/image/width=800,format=auto/https://cdn.joshuatech.dev/posts/a.jpg
```

**Pages -> Workers 커스텀 도메인 원자적 전환 스크립트** — <https://developers.cloudflare.com/api/resources/workers/subresources/domains/methods/update/>
```
#!/usr/bin/env bash
set -euo pipefail
API=https://api.cloudflare.com/client/v4; H=(-H "Authorization: Bearer $CF_TOKEN" -H "Content-Type: application/json")
D=joshuatech.dev; SVC=joshuatech-web
REC=$(curl -s "${H[@]}" "$API/zones/$ZONE_ID/dns_records?type=CNAME&name=$D" | jq -r '.result[0].id')
curl -s -X DELETE "${H[@]}" "$API/accounts/$ACCOUNT_ID/pages/projects/$PAGES_PROJECT/domains/$D"   # Pages Write
curl -s -X DELETE "${H[@]}" "$API/zones/$ZONE_ID/dns_records/$REC"                                   # DNS Write
curl -s -X PUT "${H[@]}" "$API/accounts/$ACCOUNT_ID/workers/domains" \
  -d "{\"hostname\":\"$D\",\"service\":\"$SVC\",\"zone_id\":\"$ZONE_ID\"}" | jq -r '.result.id'  # Workers Scripts Write
# 이후: tofu import cloudflare_workers_custom_domain.web "$ACCOUNT_ID/<result.id>"; www도 반복. 다운타임: 2~3회 API 호출 시간(수 초)
```

**GitHub Actions — wrangler-action v4 (preview alias)** — <https://developers.cloudflare.com/workers/versions-and-deployments/preview-urls/>
```
- uses: cloudflare/wrangler-action@v4
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}     # cfat_ 계정 토큰, Workers Scripts:Edit
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    workingDirectory: apps/web
    command: versions upload --preview-alias pr-${{ github.event.number }}   # <alias>-<worker>.<subdomain>.workers.dev
# main: command: deploy
```

### 함정

- registry.terraform.io 문서는 JS 렌더라 도구/스크립트로 못 읽음 — 스키마는 raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/<name>.md를 기준으로 할 것.
- OpenTofu 1.10 이하 + provider 5.6+ 조합은 `cloudflare_zero_trust_access_identity_provider.config.client_secret`(write-only)에서 "Write-only attributes are only supported in Terraform 1.11 and later" 오류(issue #5748). OpenTofu 1.11+ 필수, 현재 1.12.6.
- provider 5.24.0 breaking: `zero_trust_access_policy.session_duration` 기본값(24h) 제거 → 명시 안 하면 null; `hostname_tls_setting`·`image_variant` 스키마 변경. 5.x는 2~3주마다 릴리스하므로 `~> 5.24`로 patch만 자동 허용하고 minor 업은 Renovate PR로.
- `cloudflare_workers_custom_domain`은 provider 문서상 `zone_name`이 Required(API에서는 optional). 해당 hostname에 기존 CNAME이 있으면 생성 실패, Terraform에서 같은 hostname의 `cloudflare_dns_record`를 함께 관리하면 충돌. 도메인 삭제 시 Advanced cert는 남음.
- `cloudflare_zero_trust_access_service_token.client_secret`은 생성 시 1회만 반환(state에 sensitive로 남음) → apply 직후 Vault에 옮기고 state 접근 통제. 회전은 `client_secret_version` 증가 + `previous_client_secret_expires_at`. 2026-08부터 신규 시크릿은 `cfast_…` 형식.
- 서비스 토큰 정책의 decision은 반드시 `non_identity`(Service Auth). `allow`로 두면 IdP 로그인으로 리다이렉트. 평가 순서: Bypass/Service Auth → Block/Allow, Allow/Block 매치 시 즉시 종료. API 앱에는 `service_auth_401_redirect = true`로 로그인 HTML 대신 401 반환.
- Zero Trust Free: 온보딩에서 결제수단 입력 필수(무료여도). 팀 이름(auth_domain)은 대시보드에서 먼저 만들어야 하며 `cloudflare_zero_trust_organization`은 import 미지원. 서비스 토큰은 seat 미소비. 한도: 앱 500, 재사용 정책 500, 서비스 토큰 50, IdP 50.
- cloudflared 2026.6.0부터 `cloudflared access tcp/ssh`가 서비스 토큰(플래그·env·-H)을 무시하고 브라우저 인증으로 떨어지는 회귀(issue #1673, 2026-08-31 기준 open·코멘트 0, 2026.8.3 릴리스 노트에 수정 언급 없음). 서버측 터널·HTTP 서비스 토큰(헤더)은 영향 없음. 비대화형 TCP가 필요하면 클라이언트만 2026.5.1 고정 후 검증.
- cloudflared egress: 7844 TCP+UDP(region1/region2.v2.argotunnel.com, QUIC 실패 시 http2 폴백), 443(api.cloudflare.com, <team>.cloudflareaccess.com). OCI 보안 리스트 egress를 all-allow가 아니면 명시.
- cloudflared `--token <값>`은 프로세스 인자로 노출(2026.7.x가 서비스 설치를 `--token-file`로 바꾼 이유) → 컨테이너는 `TUNNEL_TOKEN` env. `:latest` 대신 태그 고정 + `--no-autoupdate`. 2 replica는 HA 전용이며 required anti-affinity + nodeSelector(role=platform)는 1 pod Pending.
- kubectl 경유 시 `tcp://kubernetes.default.svc.cluster.local:443`은 K3s 인증서 SAN에 `kubernetes`가 있으므로 kubeconfig에 `tls-server-name: kubernetes` 필요(127.0.0.1로 접속하므로). 공식 kubectl 튜토리얼의 exec-plugin(Access JWT bearer) 방식은 API 서버 OIDC 설정 전제.
- global AOP 인증서는 모든 Cloudflare 고객 공유 → "Cloudflare 망 경유"만 보증. 계정 배타성이 필요하면 zone-level(자체 cert 업로드). SSL 모드 Full 이상 필수(설계는 strict). `tls_client_auth` zone setting은 global 토글이며 zone-level 토글(`authenticated_origin_pulls_settings`)과 별개.
- Traefik `TLSOption name=default`에 RequireAndVerifyClientCert를 걸면 Cloudflare를 거치지 않는 모든 직접 TLS 접속(헬스체크 포함)이 핸드셰이크에서 실패 — 의도된 동작이지만 노드 내부 curl 점검은 프록시 경유로 해야 함. cert-manager LE 와일드카드가 Traefik default cert여야 strict 통과.
- Image Transformations: zone 활성화 후 `/cdn-cgi/image/`는 zone의 proxied hostname 어디서나 동작(Workers 커스텀 도메인 포함). 기본 Sources=같은 zone(서브도메인 허용)이라 cdn.joshuatech.dev는 별도 allowlist 불필요; "any origin"은 남용 위험. Free 5,000 unique/월(width×quality 조합별 1회, format=auto 변형은 1회). 변환 결과 개별 purge 불가. 커스텀 로더는 `remotePatterns` 미검사.
- R2 커스텀 도메인: 같은 계정 zone 필수, 연결 시 proxied DNS 레코드 자동 생성(Terraform으로 별도 DNS 레코드 만들지 말 것). 기본 캐시는 일부 파일 타입만 → Cache Rule 필요. 공개 버킷은 목록 조회 불가지만 누구나 객체 읽기 가능.
- 계정 소유 토큰(cfat_) 생성은 Super Administrator만 가능. wrangler는 `CLOUDFLARE_ACCOUNT_ID`를 함께 주면 계정 열거를 건너뛰므로 Workers Scripts:Edit 하나로 deploy/versions upload 가능(open: whoami 경고 여부). Page Rules·Turnstile 등 일부 제품은 계정 토큰 미지원.
- Pages 커스텀 도메인 삭제는 CNAME 수동 삭제 + 프로젝트에서 Remove 두 단계(레코드 자동 삭제 안 됨). Pages known issue: "Worker가 이미 라우팅된 hostname에는 Pages 커스텀 도메인을 추가할 수 없음" → 롤백하려면 Workers 도메인/route를 먼저 제거해야 함.
- Workers Free 한도: 100k req/일(초과 시 1027), 10 ms CPU/요청, 압축 스크립트 3 MB(설계 CI 검사 2.5 MiB는 여유 있음), 정적 자산 20,000 파일/25 MiB, zone당 커스텀 도메인 100. Preview URL은 workers.dev 서브도메인 활성화 필요, Access로 보호 가능.
- `cloudflare_ip_ranges` 데이터 소스는 ipv4_cidrs/ipv6_cidrs만 제공(china_colos 없음). OCI 보안 리스트 규칙 수(15 v4 + 7 v6)는 한도 내지만, Cloudflare IP 변경 시 tofu apply가 필요하므로 Renovate와 별도로 주기 실행 cron이 필요.

### 미확인

- Traefik TLSOption `clientAuth.secretNames`가 참조하는 Secret의 키 이름(`tls.ca` vs `ca.crt`) — 문서 페이지(kubernetes/crd tlsoption) 404로 미확인; 배포 전 Traefik v3 CRD 레퍼런스에서 확인.
- `cloudflare_zone_setting`이 `setting_id = "image_resizing"`(on/off/open)을 허용하는지 미확인 — 안 되면 Image Transformations zone 활성화는 대시보드 수동 단계로 plan에 표기.
- cloudflared issue #1673(access tcp/ssh 서비스 토큰 무시) 수정 버전 — 2026.8.3까지 릴리스 노트에 언급 없음; 클라이언트 2026.8.3으로 재현 테스트 필요.
- wrangler 4.127.x가 계정 소유 토큰(cfat_)으로 `whoami`/verify를 정상 처리하는지(사용자 토큰용 /user 엔드포인트 경고 가능성) — CHANGELOG에 관련 항목 없음; CI 첫 실행에서 확인.
- Pages 커스텀 도메인 hostname 위에 Workers Route를 먼저 추가하면 Route가 Pages보다 우선해 무중단 전환이 되는지 — 공식 문서는 반대 방향 제약만 명시. 스테이징 hostname으로 실험 후 채택 여부 결정.
- global AOP CA(authenticated_origin_pull_ca.pem)의 만료일 — 문서에 명시 없음; `openssl x509 -noout -dates`로 확인해 만료 알림을 runbook에 추가.
- Zero Trust Free 플랜의 Access 앱/정책 수가 기본 한도(500/500)와 동일한지 — account-limits 문서는 Free 전용 수치를 DEX/캡처 외에는 구분하지 않음.
- K3s v1.36 API 서버 인증서 SAN에 `kubernetes`·`127.0.0.1`이 기본 포함되는지(tls-san 기본값) — kubeconfig `tls-server-name` 설정과 함께 실제 확인.
- `cloudflare_zero_trust_access_application.destinations` 항목의 정확한 필드(type=public/private, uri) — raw 문서 요약에서 필드 목록까지는 검증 못 함; `domain`만으로도 동작하므로 plan/validate에서 확인.


## R13 GitHub Actions

R13 GitHub Actions(public repo): ubuntu-24.04-arm 러너, GHCR digest·attestation, GitHub App 크로스 repo 커밋, ruleset, Renovate, gitleaks, SHA 핀, promote.yml

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| GitHub-hosted 러너 ubuntu-24.04-arm (public repo GA) | 라벨 ubuntu-24.04-arm / 이미지 20260823.101.1 (Ubuntu 24.04.4, Docker 28.0.4, Buildx 0.36.1, Kustomize 5.8.1, yq 4.53.6, kubectl 1.36.4, Helm 3.21.4, gh 2.98.0, Node 22.23.2, Python 3.12.3; uv·cosign 미포함) | GA 2025-08-07 / 이미지 2026-08-23 | <https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Arm64-Readme.md> |
| actions/checkout | v7.0.1 (Node 24) | 2026-07-20 | <https://github.com/actions/checkout/releases> |
| docker/setup-buildx-action | v4.3.0 | 2026-08-19 | <https://github.com/docker/setup-buildx-action/releases> |
| docker/login-action | v4.6.0 | 2026-07-29 | <https://github.com/docker/login-action/releases> |
| docker/metadata-action | v6.2.0 (v6.0.0 2026-03-05: Node 24, ESM) | 2026-07-02 | <https://github.com/docker/metadata-action/releases> |
| docker/build-push-action | v7.3.0 (v7.0.0 2026-03-05: Node 24, runner ≥2.327.1, outputs imageid/digest/metadata) | 2026-07-01 | <https://github.com/docker/build-push-action/releases> |
| actions/attest (attest-build-provenance는 v4부터 이 액션의 래퍼) | v4.2.2 / attest-build-provenance v4.2.2 | 2026-08-04 / 2026-08-06 | <https://github.com/actions/attest/releases> |
| actions/create-github-app-token | v3.2.0 (v3.0.0 2026-03-14 Node 24; v3.1.0 client-id 도입, app-id deprecated) | 2026-05-12 | <https://github.com/actions/create-github-app-token/releases> |
| gitleaks/gitleaks-action | v3.0.0 (Node 24, 입출력 변화 없음) | 2026-05-30 | <https://github.com/gitleaks/gitleaks-action/releases/tag/v3.0.0> |
| gitleaks (CLI) | v8.30.1 | 2026-03-21 | <https://github.com/gitleaks/gitleaks/releases> |
| Renovate (Mend Renovate GitHub App, hosted Community) | 44.53.0 | 2026-09-01 | <https://github.com/renovatebot/renovate/releases> |
| integrations/terraform-provider-github (OpenTofu용) | v6.13.0 | 2026-07-08 | <https://github.com/integrations/terraform-provider-github/releases> |
| GitHub CLI (gh) | v2.98.0 (gh ruleset은 list/view/check만) | 2026-08-20 | <https://github.com/cli/cli/releases> |
| kustomize | v5.8.1 | 2026-02-09 | <https://github.com/kubernetes-sigs/kustomize/releases> |
| astral-sh/setup-uv / uv | v10.0.1 / 0.12.8 | 2026-08-14 / 2026-08-31 | <https://github.com/astral-sh/setup-uv/releases> |
| actions/setup-python / actions/setup-node | v7.0.0 / v7.0.0 | 2026-07-20 / 2026-07-14 | <https://github.com/actions/setup-python/releases> |
| actions/upload-artifact | v7.0.1 | 2026-04-10 | <https://github.com/actions/upload-artifact/releases> |
| cloudflare/wrangler-action | v4.0.0 | 2026-05-12 | <https://github.com/cloudflare/wrangler-action/releases> |
| Node 20 → 24 런타임 전환(액션) | 2026-06-16 Node 24 기본, 2026-09-23 Node 20 제거 | changelog 2025-09-19 | <https://github.blog/changelog/2025-09-19-deprecation-of-node-20-on-github-actions-runners/> |

### 결정

**GITHUB-CI-D1. CI 러너는 무엇을 쓰나?**

- Decision: 모든 job을 `runs-on: ubuntu-24.04-arm` 으로 고정(ubuntu-latest 금지). arm64 네이티브 빌드라 QEMU 불필요.
- Rationale: public repo는 표준 러너 무료·무제한, arm64 표준 러너 GA(2025-08-07), 사양 4 vCPU/16 GB/14 GB SSD로 x64와 동일, Free 플랜 동시 20 job(macOS 5). OCI A1(arm64) 이미지를 같은 아키텍처에서 빌드·테스트(testcontainers)할 수 있다.
- Alternatives considered: x64 + docker/setup-qemu-action(느리고 testcontainers 에뮬레이션 불안정); larger runner(유료); OCI 노드 self-hosted(플랫폼 노드 자원 잠식).
- Source: <https://docs.github.com/en/actions/reference/runners/github-hosted-runners>

**GITHUB-CI-D2. 이미지 빌드·GHCR push·digest 전달 방식은?**

- Decision: docker/setup-buildx-action v4 → login-action v4(GITHUB_TOKEN) → metadata-action v6(`type=sha,format=long` + 기본 브랜치 `main` raw 태그) → build-push-action v7(`platforms: linux/arm64`, `provenance: false`, `sbom: false`, `cache-from/to: type=gha`) → `steps.build.outputs.digest`를 job output으로 후속 gitops job에 전달. 배포는 태그가 아닌 digest로만 참조.
- Rationale: build-push-action은 public repo에서 provenance mode=max를 자동 부착해 단일 플랫폼이라도 이미지 인덱스를 만들고(GHCR unknown/unknown 항목, digest가 인덱스 digest) 혼동을 낳는다. SLSA 출처 증명은 GitHub attestation(actions/attest)으로 대체하므로 buildx 측 attestation은 끈다.
- Alternatives considered: `provenance: mode=max` 유지(인덱스 digest를 kustomize에 적는 방식도 동작은 함); cosign keyless(추가 도구).
- Source: <https://docs.docker.com/build/ci/github-actions/attestations/>

**GITHUB-CI-D3. 빌드 출처 증명(attestation)은 어떻게 남기나?**

- Decision: `actions/attest@v4`(attest-build-provenance는 래퍼)로 `subject-name: ghcr.io/<owner>/<img>`(태그 없음), `subject-digest: <build digest>`, `push-to-registry: true`. permissions `id-token: write`, `attestations: write`, `packages: write`. 개인 계정 repo면 `create-storage-record: false`. 검증은 `gh attestation verify oci://ghcr.io/<owner>/<img>@<digest> -R <owner>/<repo>`.
- Rationale: public repo는 모든 플랜에서 무료, Sigstore 공개 투명성 로그에 기록, SLSA v1 Build L2. push-to-registry로 GHCR에 OCI referrer로도 저장돼 레지스트리만으로 검증 가능. storage record는 org 소유 repo 전용.
- Alternatives considered: cosign sign --keyless + policy-controller(K8s admission 검증까지 필요할 때); attestation 생략.
- Source: <https://github.com/actions/attest>

**GITHUB-CI-D4. pod repo에서 platform-gitops(다른 repo)에 커밋/PR을 만들 인증 수단은?**

- Decision: GitHub App 1개(권한: Repository → Contents write, Pull requests write, Metadata read) 를 platform-gitops(및 필요 시 pod repo)에 설치. 워크플로에서 `actions/create-github-app-token@v3`로 `client-id`(vars)+`private-key`(secret), `repositories: platform-gitops`, `permission-contents: write`, `permission-pull-requests: write`로 최소 스코프 토큰 발급. 커밋 아이덴티티는 `<app-slug>[bot]` + `gh api /users/<app-slug>[bot] --jq .id`로 얻은 uid 이메일.
- Rationale: GITHUB_TOKEN은 다른 repo에 접근할 수 없고 그것으로 만든 push/PR은 다른 워크플로를 트리거하지 않는다. App 토큰은 job 종료 시 자동 revoke, 만료·개인 종속이 없는 반면 PAT는 개인 계정 수명에 묶인다. GitHub 공식 문서도 이 패턴을 권장.
- Alternatives considered: fine-grained PAT(개인 종속, 만료 관리); deploy key(PR 생성 불가, gh 사용 불가).
- Source: <https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow>

**GITHUB-CI-D5. dev/prod overlay 갱신 경로는?**

- Decision: dev: pod repo main 빌드 후 App 토큰으로 platform-gitops를 checkout → `kustomize edit set image <img>@sha256:…` → main에 직접 push(App이 ruleset bypass actor). 충돌 시 `git pull --rebase` 재시도 루프. prod: `promote.yml`(workflow_dispatch)이 dev overlay의 digest를 읽어 브랜치+PR 생성, 사람이 머지.
- Rationale: dev는 자동·즉시(Argo CD 폴링 3분), prod는 PR 기록이 남는 승격. kustomize `images[].digest` 필드 사용으로 태그와 무관하게 불변 참조.
- Alternatives considered: dev도 PR + automerge(노이즈, 지연); Argo CD Image Updater(레지스트리 폴링, GitOps 커밋 주체가 클러스터로 이동).
- Source: <https://github.com/kubernetes-sigs/kustomize/blob/master/kustomize/commands/edit/set/setimage.go>

**GITHUB-CI-D6. platform-gitops(및 pod repo) main ruleset 구성은?**

- Decision: target=branch, include `~DEFAULT_BRANCH`; rules: `pull_request`(required_approving_review_count 0, allowed_merge_methods [squash]), `required_status_checks`(strict false, do_not_enforce_on_create true, context = job 이름 예 `gitleaks`,`build`, integration_id 15368=GitHub Actions), `deletion`, `non_fast_forward`, `required_linear_history`. `required_signatures`는 사용 안 함. bypass_actors: `{actor_type: Integration, actor_id: <GitHub App ID(숫자)>, bypass_mode: always}` 만. 생성은 OpenTofu `github_repository_ruleset`(provider 6.13) 또는 `gh api -X POST repos/<o>/<r>/rulesets --input ruleset.json`(fine-grained 토큰 Administration write).
- Rationale: 1인 운영이라 본인 PR을 승인할 수 없으므로 approvals 0 + required check로 게이트. strict를 켜면 Renovate PR마다 rebase·재실행 폭증. App 커밋은 git push 경로라 미서명이므로 signed 요구 시 차단됨. gh ruleset 서브커맨드는 조회 전용.
- Alternatives considered: classic branch protection(레거시); required_signatures + GraphQL createCommitOnBranch(GitHub 서명 커밋).
- Source: <https://docs.github.com/en/rest/repos/rules?apiVersion=2022-11-28#create-a-repository-ruleset>

**GITHUB-CI-D7. 의존성 자동 갱신 도구는 Renovate인가 Dependabot인가?**

- Decision: Renovate 단독(Mend Renovate GitHub App hosted, Community 무료: org당 1 동시 job, 4시간 주기, 3 GB, 30분 timeout). Dependabot은 비활성(둘 다 켜면 중복 PR). renovate.json: `config:best-practices`(= config:recommended + docker:pinDigests + helpers:pinGitHubActionDigests + :configMigration + :pinDevDependencies + abandonments:recommended + security:minimumReleaseAgeNpm + :maintainLockFilesWeekly) + argocd/kubernetes 매니저 managerFilePatterns 명시 + 자체 ghcr 이미지 제외 규칙 + pep621 uv.lock lockFileMaintenance.
- Rationale: Dependabot은 uv(2025-03 GA)·GitHub Actions SHA·Docker·Helm·npm은 되지만 kustomize `images[]`/Argo CD Application chart targetRevision/Helm values 파일을 다루지 못하고 docker digest 핀 갱신·grouping·automerge 규칙이 약하다. Renovate는 github-actions·dockerfile·kustomize·argocd·helm-values·helmv3·pep621(uv.lock)·npm·terraform을 한 설정으로 처리하고 `# vX.Y.Z` 주석을 유지한다.
- Alternatives considered: Dependabot(설정 0, GitHub 내장, 보안 업데이트 통합); self-hosted Renovate(GitHub Actions cron, 무제한 자원이나 운영 부담).
- Source: <https://docs.renovatebot.com/presets-config/>

**GITHUB-CI-D8. 시크릿 유출 검사는?**

- Decision: `gitleaks/gitleaks-action@v3`(pull_request + main push + 일일 schedule, `fetch-depth: 0`) 를 required check `gitleaks`로 등록. 개인 계정 소유 repo면 GITLEAKS_LICENSE 불필요, org 소유면 gitleaks.io에서 무료 키 발급해 secret으로 등록. 병행: GitHub secret scanning + push protection(public repo 무료) 활성.
- Rationale: README 명시: 'personal account… no license key is required', 'organization account… free license key'. 액션은 PR 코멘트·SARIF 아티팩트·job summary를 기본 제공. push protection은 커밋 전 차단이라 gitleaks와 상호 보완.
- Alternatives considered: gitleaks 바이너리 직접 실행(`gitleaks git --pre-commit`, 라이선스 무관, PR 코멘트 없음); trufflehog action.
- Source: <https://github.com/gitleaks/gitleaks-action>

**GITHUB-CI-D9. 액션 버전 핀 관행은?**

- Decision: 모든 `uses:` 를 full commit SHA + `# vX.Y.Z` 주석으로 핀하고, repo Settings → Actions → 'Require actions to be pinned to a full-length commit SHA' 활성. 핀 유지·갱신은 Renovate `helpers:pinGitHubActionDigests`(config:best-practices 포함)에 위임. actions.lock(gh actions-lock)은 실험적이라 미사용.
- Rationale: 태그는 이동 가능(tj-actions 사건류), SHA만 불변. 정책 설정은 로컬 액션(./)과 재사용 워크플로는 태그를 허용하므로 자체 composite/reusable 사용에 지장 없음. Node 24 전환(2026-06-16 기본, 09-23 Node 20 제거)으로 구버전 핀은 어차피 갱신 필요.
- Alternatives considered: 태그 핀 + Dependabot; GitHub actions.lock 락파일 방식.
- Source: <https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/>

**GITHUB-CI-D10. prod 승격(promote.yml) 절차는?**

- Decision: platform-gitops repo에 `promote.yml`(workflow_dispatch, input `app`). App 토큰으로 self checkout → `yq`로 `overlays/dev/<app>/kustomization.yaml`의 `images[0].name/.digest` 읽기 → 브랜치 `promote/<app>/<digest12>` → `kustomize edit set image <img>@<digest>` in overlays/prod/<app> → push → `gh pr create --base main --head <branch> --label promote`. 머지는 사람.
- Rationale: dev에서 이미 실행 중인 정확한 digest만 승격(재빌드 없음). App 토큰이라 'Allow GitHub Actions to create PRs' 설정 없이도 PR 생성되고 gitops repo의 검증 워크플로(kustomize build)가 정상 트리거된다. 러너 이미지에 kustomize 5.8.1·yq 4.53.6·gh 2.98.0이 이미 있다.
- Alternatives considered: pod repo 쪽에서 promote 실행(크로스 repo checkout 필요); Argo CD 태그 기반 승격.
- Source: <https://cli.github.com/manual/gh_pr_create>

### 설정 스니펫

**.github/workflows/build.yml — arm64 빌드·GHCR push·digest 출력·attestation (pod repo)** — <https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations>
```
name: build
on:
  push: { branches: [main] }
  pull_request:
permissions: { contents: read }
env:
  IMAGE: ghcr.io/${{ github.repository }}
jobs:
  build:                      # ruleset required check context = "build"
    runs-on: ubuntu-24.04-arm # ubuntu-latest 금지
    permissions: { contents: read, packages: write, id-token: write, attestations: write }
    outputs: { digest: ${{ steps.build.outputs.digest }} }
    steps:
      - uses: actions/checkout@<SHA> # v7.0.1
      - uses: docker/setup-buildx-action@<SHA> # v4.3.0
      - uses: docker/login-action@<SHA> # v4.6.0
        with: { registry: ghcr.io, username: ${{ github.actor }}, password: ${{ secrets.GITHUB_TOKEN }} }
      - id: meta
        uses: docker/metadata-action@<SHA> # v6.2.0
        with:
          images: ${{ env.IMAGE }}
          tags: |
            type=sha,format=long
            type=raw,value=main,enable={{is_default_branch}}
      - id: build
        uses: docker/build-push-action@<SHA> # v7.3.0
        with:
          context: .
          platforms: linux/arm64
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          provenance: false   # public repo 기본 mode=max → 인덱스/unknown-unknown 방지
          sbom: false
          cache-from: type=gha
          cache-to: type=gha,mode=max
      - if: github.event_name != 'pull_request'
        uses: actions/attest@<SHA> # v4.2.2
        with:
          subject-name: ${{ env.IMAGE }}          # 태그 없이 FQIN
          subject-digest: ${{ steps.build.outputs.digest }}
          push-to-registry: true
          create-storage-record: false             # 개인 계정 repo(org 전용 기능)
```

**build.yml — bump-dev job: GitHub App 토큰으로 platform-gitops dev overlay digest 커밋** — <https://github.com/actions/create-github-app-token>
```
  bump-dev:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-24.04-arm
    concurrency: { group: gitops-bump, cancel-in-progress: false }
    steps:
      - id: app-token
        uses: actions/create-github-app-token@<SHA> # v3.2.0
        with:
          client-id: ${{ vars.GITOPS_APP_CLIENT_ID }}
          private-key: ${{ secrets.GITOPS_APP_PRIVATE_KEY }}
          repositories: platform-gitops
          permission-contents: write
          permission-pull-requests: write
      - uses: actions/checkout@<SHA> # v7.0.1
        with:
          repository: ${{ github.repository_owner }}/platform-gitops
          token: ${{ steps.app-token.outputs.token }}
      - env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
          APP_SLUG: ${{ steps.app-token.outputs.app-slug }}
          APP: ${{ github.event.repository.name }}
          IMAGE: ghcr.io/${{ github.repository }}
          DIGEST: ${{ needs.build.outputs.digest }}
        run: |
          set -euo pipefail
          uid=$(gh api "/users/${APP_SLUG}[bot]" --jq .id)
          git config user.name  "${APP_SLUG}[bot]"
          git config user.email "${uid}+${APP_SLUG}[bot]@users.noreply.github.com"
          (cd "overlays/dev/${APP}" && kustomize edit set image "${IMAGE}@${DIGEST}")
          git commit -am "chore(dev): ${APP} -> ${DIGEST} (${GITHUB_SHA::7})"
          for i in 1 2 3 4 5; do git push && break; git pull --rebase && sleep $((i*5)); done
```

**ruleset.json + gh api (main 보호, bypass = GitHub App만)** — <https://docs.github.com/en/rest/repos/rules?apiVersion=2022-11-28#create-a-repository-ruleset>
```
{
  "name": "main", "target": "branch", "enforcement": "active",
  "bypass_actors": [ { "actor_id": <GITOPS_APP_ID>, "actor_type": "Integration", "bypass_mode": "always" } ],
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" }, { "type": "non_fast_forward" }, { "type": "required_linear_history" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false, "require_last_push_approval": false,
        "required_review_thread_resolution": false, "allowed_merge_methods": ["squash"] } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": false, "do_not_enforce_on_create": true,
        "required_status_checks": [
          { "context": "gitleaks", "integration_id": 15368 },
          { "context": "build",    "integration_id": 15368 } ] } }
  ]
}
# 적용 (fine-grained 토큰: Repository → Administration: write)
gh api -X POST -H "Accept: application/vnd.github+json" repos/<owner>/platform-gitops/rulesets --input ruleset.json
gh ruleset list -R <owner>/platform-gitops   # 조회 전용
```

**OpenTofu — github_repository_ruleset (terraform-provider-github 6.13)** — <https://github.com/integrations/terraform-provider-github/blob/main/docs/resources/repository_ruleset.md>
```
resource "github_repository_ruleset" "main" {
  name        = "main"
  repository  = github_repository.platform_gitops.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  bypass_actors {
    actor_id    = var.gitops_app_id   # GitHub App ID(숫자, App 설정 페이지). installation id 아님
    actor_type  = "Integration"
    bypass_mode = "always"
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      required_approving_review_count = 0
      allowed_merge_methods           = ["squash"]
    }

    required_status_checks {
      strict_required_status_checks_policy = false
      do_not_enforce_on_create             = true
      required_check {
        context        = "gitleaks"
        integration_id = 15368
      }
      required_check {
        context        = "build"
        integration_id = 15368
      }
    }
  }
}
```

**renovate.json (platform-gitops·pod repo 공용 골격)** — <https://docs.renovatebot.com/presets-config/>
```
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:best-practices", ":semanticCommits", "schedule:weekends"],
  "timezone": "Asia/Seoul",
  "argocd":     { "managerFilePatterns": ["/^apps/.+\\.ya?ml$/"] },
  "kubernetes": { "managerFilePatterns": ["/^(base|overlays)/.+\\.ya?ml$/"] },
  "lockFileMaintenance": { "enabled": true },
  "packageRules": [
    { "description": "CI가 digest를 bump하는 자체 이미지는 Renovate 제외",
      "matchDatasources": ["docker"], "matchPackageNames": ["ghcr.io/<owner>/**"], "enabled": false },
    { "matchManagers": ["github-actions"], "groupName": "github-actions",
      "matchUpdateTypes": ["minor", "patch", "digest", "pin"], "automerge": true },
    { "matchManagers": ["helmv3", "argocd", "kustomize"], "matchUpdateTypes": ["major"], "dependencyDashboardApproval": true }
  ]
}
// config:best-practices = config:recommended + docker:pinDigests + helpers:pinGitHubActionDigests
//   + :configMigration + :pinDevDependencies + abandonments:recommended + security:minimumReleaseAgeNpm + :maintainLockFilesWeekly
// pep621 매니저가 pyproject.toml + uv.lock(uv workspaces 포함)을 갱신; 설치: https://github.com/apps/renovate → 온보딩 PR 머지
```

**.github/workflows/gitleaks.yml (required check "gitleaks")** — <https://github.com/gitleaks/gitleaks-action>
```
name: gitleaks
on:
  pull_request:
  push: { branches: [main] }
  schedule: [{ cron: "0 19 * * *" }]   # 04:00 KST
permissions: { contents: read, pull-requests: write }
jobs:
  gitleaks:
    name: gitleaks
    runs-on: ubuntu-24.04-arm
    steps:
      - uses: actions/checkout@<SHA> # v7.0.1
        with: { fetch-depth: 0 }
      - uses: gitleaks/gitleaks-action@<SHA> # v3.0.0
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          # GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}  # org 소유 repo에서만(무료 키, gitleaks.io)
          GITLEAKS_ENABLE_UPLOAD_ARTIFACT: "false"
          # GITLEAKS_CONFIG: .gitleaks.toml  # 커스텀 룰(예: ghs_[A-Za-z0-9._]{36,})
```

**.github/workflows/promote.yml (platform-gitops repo, dev digest → prod PR)** — <https://cli.github.com/manual/gh_pr_create>
```
name: promote
on:
  workflow_dispatch:
    inputs:
      app: { description: "overlays/dev/<app>", required: true, type: string }
permissions: { contents: read }
jobs:
  promote:
    runs-on: ubuntu-24.04-arm
    steps:
      - id: app-token
        uses: actions/create-github-app-token@<SHA> # v3.2.0
        with:
          client-id: ${{ vars.GITOPS_APP_CLIENT_ID }}
          private-key: ${{ secrets.GITOPS_APP_PRIVATE_KEY }}
          permission-contents: write
          permission-pull-requests: write
      - uses: actions/checkout@<SHA> # v7.0.1
        with: { token: ${{ steps.app-token.outputs.token }} }
      - env:
          GH_TOKEN: ${{ steps.app-token.outputs.token }}
          APP_SLUG: ${{ steps.app-token.outputs.app-slug }}
          APP: ${{ inputs.app }}
        run: |
          set -euo pipefail
          f="overlays/dev/${APP}/kustomization.yaml"
          img=$(yq '.images[0].name' "$f"); dig=$(yq '.images[0].digest' "$f")
          [[ "$dig" == sha256:* ]] || { echo "dev overlay에 digest 없음"; exit 1; }
          short=${dig#sha256:}; br="promote/${APP}/${short:0:12}"
          uid=$(gh api "/users/${APP_SLUG}[bot]" --jq .id)
          git config user.name "${APP_SLUG}[bot]"
          git config user.email "${uid}+${APP_SLUG}[bot]@users.noreply.github.com"
          git switch -c "$br"
          (cd "overlays/prod/${APP}" && kustomize edit set image "${img}@${dig}")
          git commit -am "chore(prod): promote ${APP} -> ${dig}"
          git push -u origin "$br"
          gh pr create --base main --head "$br" --label promote \
            --title "promote(${APP}): ${short:0:12}" \
            --body "dev overlay digest를 prod로 승격. run: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}"
```

### 함정

- ubuntu-24.04-arm은 public repo에서만 무료(private는 2026-01-29부터 표준 러너로 사용 가능하나 분 소진). 이미지는 Arm이 관리하는 별도 이미지로 CodeQL·Chrome/Edge·Homebrew·Android SDK 등이 빠져 있고, x64·arm64 모두 uv·cosign 미포함(astral-sh/setup-uv 필요), 기본 Python 3.12.3/Node 22 → Python 3.13은 setup-python 또는 `uv python install`.
- `ubuntu-latest` 사용 금지: ubuntu-26.04/-arm이 2026-06-11 프리뷰로 나왔고 latest 라벨 이관 시점은 미공지. 라벨을 명시 고정하고 Renovate가 runs-on 갱신을 제안하게 둔다.
- Node 20 → 24 전환: 2026-06-16부터 Node 24가 기본, 2026-09-23 Node 20 제거. checkout v4/v5, build-push v6, create-github-app-token v2, gitleaks-action v2 등 Node 20 액션은 실패하므로 모두 v7/v7/v3/v3 이상으로.
- build-push-action은 public repo에서 provenance mode=max를 자동 부착 → 단일 플랫폼도 이미지 인덱스가 되고 GHCR에 unknown/unknown 항목, `outputs.digest`가 인덱스 digest가 됨. `provenance: false, sbom: false`로 끄거나, 켜둘 경우 kustomize에 인덱스 digest를 그대로 쓴다(containerd pull은 정상).
- GHCR: 개인 계정에서 처음 push된 패키지는 private → K3s가 pull 실패(401). 패키지 설정에서 Public 전환(되돌릴 수 없음)하거나 imagePullSecret 필요. 패키지는 repo 권한만 상속하고 가시성은 상속하지 않는다.
- actions/attest `push-to-registry`는 `packages: write` + 사전 docker/login 필요. storage record(`artifact-metadata: write`)는 org 소유 repo 전용 → 개인 계정 repo는 `create-storage-record: false`. fork PR에서는 id-token 발급이 안 되므로 attest는 push 이벤트에서만.
- GITHUB_TOKEN으로 만든 커밋/PR은 다른 워크플로를 트리거하지 않고 다른 repo에 접근 불가 → 크로스 repo는 App 토큰 필수. create-github-app-token v3.1+는 `app-id` deprecated(`client-id` 사용), App은 대상 repo에 설치돼 있어야 하며 `permission-*`는 App 등록 권한의 부분집합만 가능. 토큰은 job 종료 시 revoke(`skip-token-revoke`로 유지 가능).
- 2026-04-27부터 GitHub App 설치 토큰이 `ghs_APPID_JWT`(~520자, 점 2개) 형식으로 롤아웃. 길이 40 고정·`ghs_[A-Za-z0-9]{36}` 정규식에 의존하는 도구는 오탐/미탐 → gitleaks 커스텀 룰은 `ghs_[A-Za-z0-9._]{36,}` 권장, GitHub secret scanning을 병행.
- ruleset bypass_actors의 Integration `actor_id`는 GitHub App ID(App 설정 페이지의 숫자, 예 Renovate 2740·Dependabot 29110)이며 installation id/node id가 아니다. required_status_checks의 `integration_id` 15368 = GitHub Actions 앱 id. terraform-provider-github는 bypass_actors 제거가 반영되지 않는 버그(#2269, #2952)가 있어 제거 후 UI로 확인.
- required status check의 context는 job의 `name`(없으면 job id). paths 필터로 job이 스킵되면 PR이 영구 블록되므로 required로 지정한 job(gitleaks, build)은 paths 필터 없이 항상 실행. strict(up-to-date)를 켜면 Renovate PR마다 rebase·재실행 → 끈다.
- `required_signatures`를 켜면 Actions에서 git push한 App 커밋(미서명)이 차단된다(bypass가 always면 통과하지만 PR 경로는 아님). 서명 커밋이 필요하면 GraphQL createCommitOnBranch로 GitHub 서명 커밋을 만든다.
- approvals 0 + PR 필수여도 본인 PR을 리뷰 없이 머지할 수 있다. 게이트는 required check(gitleaks·build·kustomize build 검증)가 전부이므로 검증 워크플로가 실제로 실패하도록 유지해야 한다.
- 여러 pod repo가 동시에 platform-gitops main에 push하면 non-fast-forward 충돌. `concurrency` 그룹은 같은 repo 안에서만 직렬화되므로 `git pull --rebase` 재시도 루프가 필수. dev overlay는 pod별 디렉터리로 분리해 rebase 충돌을 피한다.
- Renovate hosted Community: org당 동시 1 job, 4시간 주기, 30분 timeout, 3 GB → uv lockFileMaintenance 등 무거운 작업이 timeout될 수 있다(OSI 라이선스면 Community OSS 플랜 신청 가능: 2 job/6 GB/60분).
- Renovate argocd·kubernetes 매니저는 managerFilePatterns 기본값이 없어 설정하지 않으면 아무것도 하지 않는다. kustomize `images[]`에 `digest`가 있으면 `newTag`는 무시되므로 둘 다 갱신하려면 `newTag: v1.2.3@sha256:…` 형태. docker:pinDigests 프리셋은 argocd·helmv3·devcontainer·pyenv 매니저에는 pinDigests false.
- 자체 이미지(ghcr.io/<owner>/**)는 CI가 digest를 bump하므로 Renovate에서 제외하지 않으면 digest PR이 충돌한다. K3s HelmChartConfig의 inline valuesContent와 Traefik 번들 버전은 Renovate가 관리하지 못한다(K3s 업그레이드로 따라감).
- SHA 핀 필수 설정을 켜면 `uses: owner/repo@v7` 태그 참조는 즉시 실패(로컬 `./` 액션과 재사용 워크플로는 예외). 설정 전에 Renovate pin PR을 먼저 머지. Dependabot과 Renovate를 동시에 켜면 중복 PR.
- gitleaks-action: org 소유 repo는 무료 키라도 GITLEAKS_LICENSE 없으면 실패, 개인 계정 repo는 불필요. `fetch-depth: 0` 없으면 PR 커밋 범위 스캔이 깨진다. PR 코멘트에 `pull-requests: write` 필요(기본 GITHUB_TOKEN은 read-only).
- Actions 캐시(type=gha)는 repo당 10 GB; arm64와 x64 캐시 키가 섞이지 않게 scope를 나눈다. Free 플랜 동시 실행 20 job(macOS 5)은 public repo에도 적용.
- gh CLI `gh ruleset`은 list/view/check만 지원 → 생성·수정은 `gh api --input ruleset.json`(UI에서 export한 JSON 재사용 가능) 또는 OpenTofu. fine-grained 토큰은 Administration: write 필요.

### 미확인

- 'Require actions to be pinned to a full-length commit SHA' 설정을 REST/OpenTofu로 켜는 필드명 미확인 → 초기엔 UI로 설정하고 후속 확인.
- actions/attest에서 개인 계정 repo에 `create-storage-record`를 기본값(true)으로 두면 경고인지 실패인지 미확인(README는 org 전용이라고만 명시).
- gitleaks v8.30.1 기본 룰이 새 `ghs_APPID_JWT` 토큰 형식을 탐지하는지 미확인 → 커스텀 룰 추가 여부 결정 필요.
- Renovate hosted 환경의 uv 버전 고정(`constraints.uv`) 동작과 uv.lock lockFileMaintenance 소요 시간(30분 timeout 내인지) 미검증.
- ubuntu-latest → 26.04 전환 일정 미공지.
- gitleaks 라이선스: README는 org 계정에 '무료 키'만 언급하나 일부 2차 출처는 1 repo 초과 시 유료를 언급 → repo가 org로 이관될 경우 gitleaks.io 약관 재확인.
- provenance: false 선택 시 buildx SBOM/provenance는 없고 GitHub attestation(SLSA L2)만 남는다 — 정책상 충분한지 사용자 확인. cosign policy-controller 등 클러스터 측 검증은 범위 외.
- platform-gitops main으로의 App 직접 push(dev)와 PR(prod)을 하나의 ruleset(bypass always)으로 두면 dev/prod 경로 구분이 ruleset이 아닌 워크플로 관례에 의존 → overlays/prod 경로 변경만 PR을 강제하는 push ruleset(file_path_restriction)이 가능한지 검토.


## R14 OCI 운영

R14 OCI 운영: 인스턴스 프린시펄(KMS·Object Storage), S3 호환 자격증명, KMS 비용, Budgets, 재이미지 CLI, A1 무료분·비용 확인, 유휴 회수

### 버전 (2026-09-01 확인)

| 구성요소 | 버전 | 릴리스 | 출처 |
|---|---|---|---|
| OCI CLI (oci) | 3.91.0 | 2026-08-25 | <https://github.com/oracle/oci-cli/releases> |
| terraform-provider-oci (OpenTofu registry에서도 사용) | v8.29.0 | 2026-08-26 | <https://github.com/oracle/terraform-provider-oci/releases> |
| OpenTofu (내장 백엔드: s3 등 11종, `oci` 백엔드 없음) | v1.12.6 (1.13 beta 진행 중) | 2026-08-19 | <https://github.com/opentofu/opentofu/releases> |
| HashiCorp Vault (ocikms seal 소비자) | v2.0.4 | 2026-08-04 | <https://github.com/hashicorp/vault/releases> |
| CNPG plugin-barman-cloud (ObjectStore CRD, S3 호환 endpointURL) | v0.14.0 | 2026-07-29 | <https://github.com/cloudnative-pg/plugin-barman-cloud/releases> |
| Terraform 전용 `oci` 네이티브 백엔드(If-None-Match 잠금) — Terraform v1.16 문서에만 존재, OpenTofu 미포함 | Terraform 1.16.x 문서 기준 |  | <https://developer.hashicorp.com/terraform/language/backend/oci> |

### 결정

**OCI-OPS-D1. 어느 컴포넌트가 어떤 자격증명으로 OCI에 접근하는가?**

- Decision: (a) Vault→KMS: 인스턴스 프린시펄(노드 A 동적 그룹 + `use keys`). (b) CNPG/barman→Object Storage 및 OpenTofu S3 백엔드: 전용 IAM 서비스 사용자의 Customer Secret Key(AWS_ACCESS_KEY_ID/SECRET). 인스턴스 프린시펄은 S3 호환 API에 쓸 수 없다.
- Rationale: OCI 문서상 S3 호환 API는 Customer Secret Key(Access/Secret 쌍)만 지원하고 인스턴스/리소스 프린시펄은 언급조차 없다. 반면 KMS Encrypt/Decrypt는 네이티브 OCI API라 인스턴스 프린시펄이 그대로 통한다. HashiCorp ocikms seal은 `auth_type_api_key` 미지정 시 기본이 인스턴스 프린시펄이다.
- Alternatives considered: barman이 OCI 네이티브 API를 쓰도록 하는 방법 없음(barman-cloud는 boto3/S3만). Vault에 API 키(~/.oci/config)를 넣는 방식은 키 파일 보관 문제로 배제.
- Source: <https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm>

**OCI-OPS-D2. 동적 그룹 matching rule 범위는?**

- Decision: KMS용 동적 그룹은 `Any {instance.id = '<노드A OCID>'}` 로 노드 A 한 대만 매칭. 컴파트먼트 단위 규칙 `All {instance.compartment.id = '<compartment>'}`는 노드 B(데이터·앱 pod)까지 KMS 권한을 주므로 쓰지 않는다. 정책은 `where target.key.id = '<key ocid>'` 조건으로 키 1개에 한정.
- Rationale: 인스턴스 OCID는 설계상 고정(terminate 금지)이라 instance.id 매칭이 깨질 일이 없고, 인스턴스 프린시펄은 '노드 위의 모든 프로세스'가 상속하므로(문서: SSH 접근자가 권한을 그대로 얻음) 범위를 최소화해야 한다.
- Alternatives considered: compartment 규칙 + `instance.id != '<노드B>'` 제외 조건(문서 예시)도 가능하나 instance.id 나열이 더 명시적.
- Source: <https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm>

**OCI-OPS-D3. KMS 볼트·키 구성과 월 비용 0 조건은?**

- Decision: `--vault-type DEFAULT`(가상 볼트) 1개 + AES-256(길이 32) 키 1개, `--protection-mode HSM`, 자동 회전 비활성. Virtual Private Vault는 절대 만들지 않는다.
- Rationale: Always Free 문서: 소프트웨어 보호 키는 무제한 무료, HSM 보호 키는 테넌시 전체 20 key version까지 무료, 시크릿 150개 무료. 가상 볼트 자체는 시간 과금이 없고 key version 단위로만 과금(FAQ), Virtual Private Vault는 생성 시점부터 시간당 과금. 회전마다 key version이 1개 늘어 20개 한도를 소모하므로 회전은 수동·연 1회 이하로.
- Alternatives considered: SOFTWARE 보호 모드로 두면 회전 횟수 무제한 무료. 보안 요구가 낮으면 이쪽이 더 안전한 비용 선택(플랜에서 택일).
- Source: <https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm>

**OCI-OPS-D4. Vault ocikms seal에 필요한 최소 IAM 권한은?**

- Decision: `Allow dynamic-group dg-vault-node to use keys in compartment <platform> where target.key.id = '<key ocid>'` 한 줄. `manage keys` 불필요.
- Rationale: go-kms-wrapping ocikms 래퍼는 기동 시 management endpoint로 GetKey(현재 key version 조회) 후 crypto endpoint로 Encrypt/Decrypt를 호출한다. `use keys` = KEY_READ+KEY_ENCRYPT+KEY_DECRYPT 등이므로 GetKey까지 커버된다. HashiCorp 문서 예시도 `use keys`.
- Alternatives considered: `use key-delegate`는 OCI 통합 서비스(Object Storage 등)용 위임 권한이라 Vault에는 부적합.
- Source: <https://docs.oracle.com/en-us/iaas/Content/Identity/policyreference/keypolicyreference.htm>

**OCI-OPS-D5. S3 호환 자격증명은 누구 명의로, 어떻게 관리하는가?**

- Decision: Default 도메인에 전용 서비스 사용자 `svc-s3-backup`(사람 로그인 불가) + 그룹 정책으로 백업 버킷과 tfstate 버킷만 `manage objects`. Customer Secret Key는 사용자당 최대 2개이므로 2개 슬롯을 '현재/다음'으로 써서 무중단 회전(새 키 생성→ESO/Secret 교체→구 키 삭제). 키는 Vault kv에 넣고 ESO로 CNPG Secret에 투영.
- Rationale: Customer Secret Key는 만료가 없고 생성 시 1회만 표시되며 사용자당 2개 제한(관리 문서). 관리자 개인 계정의 키를 쓰면 계정 이탈·MFA 변경 시 백업이 끊긴다.
- Alternatives considered: barman/tfstate 별도 사용자 2명(키 4개)으로 분리하면 권한 분리는 좋으나 관리 부담 증가; 초기에는 1 사용자로 시작.
- Source: <https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/managingcredentials.htm>

**OCI-OPS-D6. Budgets를 어떻게 구성하는가?**

- Decision: 루트 컴파트먼트에 월 예산 1개(`--target-type COMPARTMENT --targets '["<tenancy ocid>"]' --reset-period MONTHLY --processing-period-type MONTH`, 금액 USD 10~35 사이에서 A1 무료분 결론에 따라 확정). 알림 규칙 4개: ACTUAL 50%·80%·100%, FORECAST 100%, `--recipients` 이메일.
- Rationale: 예산은 타깃과 무관하게 항상 루트 컴파트먼트에 생성되며 `manage usage-budgets in tenancy` 권한이 필요하다. 평가 주기는 24시간, Cost Analysis 데이터 지연은 최대 48시간이므로 예산은 '지출 차단'이 아니라 '1~3일 지연 통보'로 설계한다. FORECAST 규칙이 월초 이상 징후를 가장 빨리 잡는다.
- Alternatives considered: 컴파트먼트별 예산 분할(한 컴파트먼트당 예산 1개 제한)은 단일 테넌시 개인 프로젝트에 과함. OCI Notifications 토픽 경유는 불필요(규칙의 recipients로 직접 메일 발송).
- Source: <https://docs.oracle.com/en-us/iaas/Content/Billing/Concepts/budgetsoverview.htm>

**OCI-OPS-D7. 인스턴스 재이미지(부트 볼륨 교체) 절차는?**

- Decision: `oci compute instance update-instance-update-instance-source-via-image-details --instance-id <ocid> --source-details-image-id <Ubuntu 24.04 aarch64 이미지> --source-details-is-preserve-boot-volume-enabled true` 한 방. 수동 stop/detach/attach 불필요(서비스가 stop→교체→이전 상태 복귀). 검증 후 이전 부트 볼륨 삭제.
- Rationale: 공식 '부트 볼륨 교체'는 인스턴스를 terminate하지 않고 OCID를 유지한다('The OCID of the instance remains the same'). Preserve 옵션으로 롤백 여지 확보. 전제: Linux 전용, 마켓플레이스 이미지 불가, 그리고 '같은 Linux 배포판'만 허용(Oracle Linux↔Ubuntu 전환 불가).
- Alternatives considered: 부트 볼륨을 미리 만드는 `...-via-boot-volume-details`는 이미지에서 직접 부트 볼륨을 만들 수 없어(백업/기존 볼륨에서만) 이점이 없다. terminate 후 재생성은 설계상 금지.
- Source: <https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/replacingbootvolume.htm>

**OCI-OPS-D8. 퍼블릭 IP를 유지하려면(ephemeral vs reserved)?**

- Decision: 재이미지 전에 두 노드의 ephemeral 퍼블릭 IP를 삭제하고 Reserved 퍼블릭 IP를 생성·할당한다(주소 1회 변경, 이후 영구). Cloudflare DNS A 레코드는 OpenTofu로 갱신.
- Rationale: ephemeral IP는 VNIC의 primary private IP에 묶여 있어 stop/start와 부트 볼륨 교체에는 살아남지만(문서: 정지 시 유지, VNIC/인스턴스 종료 시에만 삭제), ephemeral→reserved 변환은 불가능하고 반드시 삭제 후 새로 만들어야 한다. Reserved는 무료이며 리전 단위로 이동 가능해 향후 어떤 사고에도 주소가 보존된다.
- Alternatives considered: ephemeral 유지: 이번 재이미지에서는 IP가 바뀌지 않을 가능성이 높으나 공식 문서가 부트 볼륨 교체 시 IP 보존을 명시하지 않고, 향후 VNIC 재생성 시 주소가 바뀐다.
- Source: <https://docs.oracle.com/en-us/iaas/Content/Network/Tasks/managingpublicIPs.htm>

**OCI-OPS-D9. PAYG 테넌시의 A1 무료분과 예상 과금은?**

- Decision: 공식 문서는 2026-06-15부터 '모든 테넌시' 기준 월 1,500 OCPU-h / 9,000 GB-h(=2 OCPU/12 GB 상시)로 축소. 설계(2×2 OCPU/13 GB = 4 OCPU/26 GB, 744h 기준 2,976 OCPU-h / 19,344 GB-h)는 새 한도로는 월 약 $30.3(OCPU 1,476h×$0.01=$14.76 + 메모리 10,344GB-h×$0.0015=$15.52), 구 한도(3,000/18,000)가 PAYG에 유지된다면 월 약 $2.0(메모리 1,344 GB-h 초과분)로 계획한다. Budgets 상한은 보수적으로 $35.
- Rationale: Always Free 문서 원문: 'All tenancies get the first 1,500 OCPU hours and 9,000 GB hours per month for free'. PAYG에 대해 Oracle 지원은 상반된 답을 했고(PAYG는 4/24 유지 vs PAYG도 축소) 공식 해명 없음. 'Oracle doesn't charge for Always Free resources after you upgrade, and will only charge you for resource usage above the Always Free limits'는 유지.
- Alternatives considered: 노드당 메모리를 13→12 GB로 줄이면 구 한도 기준 완전 무료(24 GB×744=17,856 < 18,000). 새 한도가 적용된다면 어떤 조정도 무료가 안 되므로 비용을 받아들이거나 노드 1대로 축소해야 함(설계 변경 사항이라 플랜에서 결정).
- Source: <https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm>

**OCI-OPS-D10. 유휴 회수 규칙이 PAYG 인스턴스에도 적용되는가?**

- Decision: 적용되지 않는 것으로 가정하되 감시한다. 공식 문서는 'Idle Always Free compute instances may be reclaimed'(7일간 CPU p95<20%·네트워크<20%·메모리<20%, 메모리는 A1만)이고, Oracle 회수 안내 메일 원문은 'you can keep idle compute instances from being stopped by converting your account to Pay As You Go (PAYG)'라고 명시.
- Rationale: 회수 대상은 Always Free 테넌시의 Always Free 인스턴스. PAYG 전환 후에는 한도 초과분이 과금될 뿐 회수·종료 대상이 아니다(2026-08-18 자동 종료 통보도 Always Free 테넌시 대상). 다만 문서에 PAYG 면제가 명문화돼 있지는 않다.
- Alternatives considered: K3s+Argo+Kafka+Vault 상시 부하로 20% 임계는 자연히 넘기므로 인위적 부하 생성은 불필요.
- Source: <https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm>

**OCI-OPS-D11. OpenTofu 상태 백엔드(OCI Object Storage S3 호환) 잠금은?**

- Decision: OpenTofu `backend "s3"` + Customer Secret Key, `use_lockfile = true`를 1차 시도하고 If-None-Match 미지원으로 실패하면 잠금 없이(단일 운영자, CI 직렬화) 운용한다. Terraform의 네이티브 `oci` 백엔드는 OpenTofu에 없다.
- Rationale: OpenTofu 내장 백엔드 목록에 `oci`가 없고 플러그인 로드도 불가. `use_lockfile`은 S3 조건부 쓰기(If-None-Match)에 의존하는데 OCI S3 호환 API의 지원 여부는 문서에 없고 oracle/terraform-provider-oci#2323이 2026-06 'internal ticket' 상태.
- Alternatives considered: Terraform(BUSL) 1.16 `oci` 백엔드(If-None-Match 기반 잠금, 인스턴스 프린시펄 인증)는 잠금이 확실하나 OpenTofu 결정과 충돌. `pg` 백엔드(CNPG)는 클러스터 부트스트랩 순환 의존.
- Source: <https://opentofu.org/docs/language/settings/backends/s3/>

**OCI-OPS-D12. 노드 위 다른 pod가 인스턴스 프린시펄을 훔쳐 쓰는 것을 어떻게 막는가?**

- Decision: K3s 기본 NetworkPolicy 컨트롤러로 vault 네임스페이스 외 모든 네임스페이스에서 169.254.169.254/32 egress를 차단하고, 두 인스턴스 모두 IMDS v1을 비활성화(`--instance-options '{"areLegacyImdsEndpointsDisabled": true}'`).
- Rationale: 인스턴스 프린시펄은 노드 단위 신원이라 IMDS(169.254.169.254)에 닿는 모든 pod가 KMS 권한을 상속한다. OCI SDK/CLI는 v2(Authorization: Bearer Oracle)를 자동 사용하므로 v1 차단은 무해.
- Alternatives considered: OKE Workload Identity는 K3s에 없음. Vault를 API 키로 바꾸는 것은 키 파일 노출 위험이 더 큼.
- Source: <https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm>

### 설정 스니펫

**동적 그룹 + KMS use keys 정책 (CLI, Default 도메인)** — <https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/iam/dynamic-group/create.html>
```
# 동적 그룹: 노드 A만
oci iam dynamic-group create --name dg-vault-node \
  --description "K3s platform node (Vault auto-unseal)" \
  --matching-rule "Any {instance.id = '<NODE_A_INSTANCE_OCID>'}"

# 정책 (루트 컴파트먼트, 키 1개로 한정)
cat > pol-vault-kms.json <<'EOF'
["Allow dynamic-group dg-vault-node to use keys in compartment platform where target.key.id = '<KEY_OCID>'"]
EOF
oci iam policy create --compartment-id <TENANCY_OCID> --name pol-vault-kms \
  --description "Vault ocikms seal" --statements file://pol-vault-kms.json
```

**KMS 가상 볼트·AES-256 키 생성 + Vault seal 스탠자** — <https://developer.hashicorp.com/vault/docs/configuration/seal/ocikms>
```
oci kms management vault create -c <PLATFORM_COMPARTMENT_OCID> \
  --display-name platform-vault --vault-type DEFAULT --wait-for-state ACTIVE
# 응답의 management-endpoint / crypto-endpoint 를 아래에 사용
oci kms management key create -c <PLATFORM_COMPARTMENT_OCID> \
  --display-name vault-unseal --endpoint <MANAGEMENT_ENDPOINT> \
  --protection-mode HSM --key-shape '{"algorithm":"AES","length":32}' \
  --wait-for-state ENABLED

# vault.hcl (auth_type_api_key 생략 = instance principal)
seal "ocikms" {
  key_id              = "<KEY_OCID>"
  crypto_endpoint     = "https://<VAULT_ID>-crypto.kms.ap-chuncheon-1.oraclecloud.com"
  management_endpoint = "https://<VAULT_ID>-management.kms.ap-chuncheon-1.oraclecloud.com"
}
```

**S3 호환 서비스 사용자 + Customer Secret Key + aws cli 검증** — <https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/iam/customer-secret-key/create.html>
```
oci iam user create --name svc-s3-backup --description "barman/tfstate S3 compat"
oci iam user update-user-capabilities --user-id <USER_OCID> \
  --can-use-console-password false --can-use-api-keys false --can-use-customer-secret-keys true
oci iam group create --name grp-s3-backup --description "S3 compat objects"
oci iam group add-user --group-id <GROUP_OCID> --user-id <USER_OCID>
# 정책(루트): 버킷 2개에만 objects manage
# ["Allow group grp-s3-backup to read buckets in compartment platform",
#  "Allow group grp-s3-backup to manage objects in compartment platform where any {target.bucket.name = 'joshuatech-pg-backup', target.bucket.name = 'joshuatech-tfstate'}"]
oci iam customer-secret-key create --user-id <USER_OCID> --display-name barman-2026q3
#  -> data.id = AWS_ACCESS_KEY_ID, data.key = AWS_SECRET_ACCESS_KEY (1회만 표시)

# 버킷은 네이티브 API로 platform 컴파트먼트에 생성 (S3 API로 만들면 루트 컴파트먼트에 생김)
oci os bucket create -c <PLATFORM_COMPARTMENT_OCID> --name joshuatech-pg-backup

# 검증 (boto3/aws cli >=1.36 체크섬 문제 회피 env 포함)
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... \
  AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required
NS=$(oci os ns get --query data --raw-output)
aws --region ap-chuncheon-1 \
  --endpoint-url https://$NS.compat.objectstorage.ap-chuncheon-1.oci.customer-oci.com \
  s3 ls s3://joshuatech-pg-backup/
```

**CNPG barman-cloud ObjectStore (OCI S3 호환)** — <https://cloudnative-pg.io/plugin-barman-cloud/docs/next/object_stores/>
```
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata: {name: oci-pg-backup, namespace: data}
spec:
  configuration:
    destinationPath: "s3://joshuatech-pg-backup/"
    endpointURL: "https://<NS>.compat.objectstorage.ap-chuncheon-1.oci.customer-oci.com"
    s3Credentials:
      accessKeyId:     {name: oci-s3-creds, key: ACCESS_KEY_ID}      # ESO가 Vault에서 투영
      secretAccessKey: {name: oci-s3-creds, key: ACCESS_SECRET_KEY}
    wal:  {compression: gzip}
    data: {compression: gzip}
  retentionPolicy: "14d"
  instanceSidecarConfiguration:      # v0.14.0 CRD에서 필드명 재확인
    env:
      - {name: AWS_REQUEST_CHECKSUM_CALCULATION,  value: when_required}
      - {name: AWS_RESPONSE_CHECKSUM_VALIDATION,  value: when_required}
```

**Budgets: 월 예산 + Actual/Forecast 알림 (CLI)** — <https://github.com/oracle/oci-cli/blob/master/services/budget/examples_and_test_scripts/budget_example.sh>
```
# 권한: Allow group <admins> to manage usage-budgets in tenancy
BUDGET=$(oci budgets budget create --compartment-id <TENANCY_OCID> \
  --target-type COMPARTMENT --targets '["<TENANCY_OCID>"]' \
  --amount 35 --reset-period MONTHLY --processing-period-type MONTH \
  --display-name monthly-cap --query data.id --raw-output)
for T in 50 80 100; do
  oci budgets alert-rule create --budget-id $BUDGET --type ACTUAL \
    --threshold $T --threshold-type PERCENTAGE --recipients "<ALERT_EMAIL>" \
    --display-name actual-$T
done
oci budgets alert-rule create --budget-id $BUDGET --type FORECAST \
  --threshold 100 --threshold-type PERCENTAGE --recipients "<ALERT_EMAIL>" \
  --display-name forecast-100 --message "Forecast exceeds monthly cap"
```

**Reserved 퍼블릭 IP 전환 (재이미지 전, 노드당 1회)** — <https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/network/public-ip/create.html>
```
VNIC=$(oci compute instance list-vnics --instance-id <INSTANCE_OCID> --query 'data[0].id' --raw-output)
PRIV=$(oci network private-ip list --vnic-id $VNIC --query 'data[?"is-primary"].id | [0]' --raw-output)
EPH=$(oci network public-ip get --private-ip-id $PRIV --query data.id --raw-output)
oci network public-ip delete --public-ip-id $EPH --force           # ephemeral 삭제(주소 변경 1회)
oci network public-ip create -c <PLATFORM_COMPARTMENT_OCID> --lifetime RESERVED \
  --display-name node-a-public --private-ip-id $PRIV --wait-for-state ASSIGNED
# 이후 Cloudflare A 레코드는 OpenTofu(cloudflare provider)로 갱신
```

**재이미지: Ubuntu 24.04 aarch64 이미지로 부트 볼륨 교체** — <https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/compute/instance/update-instance-update-instance-source-via-image-details.html>
```
# 1) 최신 플랫폼 이미지 OCID
IMG=$(oci compute image list -c <TENANCY_OCID> --operating-system "Canonical Ubuntu" \
  --operating-system-version "24.04" --shape VM.Standard.A1.Flex \
  --sort-by TIMECREATED --sort-order DESC --query 'data[0].id' --raw-output)
# 2) 교체 (서비스가 stop -> 교체 -> 이전 상태 복귀; OCID 유지, 필요 권한 INSTANCE_BOOT_VOLUME_REPLACE)
oci compute instance update-instance-update-instance-source-via-image-details \
  --instance-id <INSTANCE_OCID> --source-details-image-id $IMG \
  --source-details-boot-volume-size-in-gbs 50 \
  --source-details-is-preserve-boot-volume-enabled true \
  --update-operation-constraint ALLOW_DOWNTIME --wait-for-state RUNNING
# 3) IMDS v1 비활성화, 4) SSH 검증 후 이전 부트 볼륨 삭제
oci compute instance update --instance-id <INSTANCE_OCID> \
  --instance-options '{"areLegacyImdsEndpointsDisabled": true}'
oci bv boot-volume list -c <COMPARTMENT_OCID> --availability-domain <AD> --query 'data[?"lifecycle-state"==`AVAILABLE`].{id:id,name:"display-name"}'
oci bv boot-volume delete --boot-volume-id <OLD_BOOT_VOLUME_OCID> --force
```

**월 비용 확인 (usage-api)** — <https://docs.oracle.com/en-us/iaas/tools/oci-cli/latest/oci_cli_docs/cmdref/usage-api/usage-summary/request-summarized-usages.html>
```
# 권한: Allow group <admins> to read usage-report in tenancy  (데이터 최대 48h 지연)
oci usage-api usage-summary request-summarized-usages --tenant-id <TENANCY_OCID> \
  --time-usage-started 2026-09-01T00:00:00Z --time-usage-ended 2026-10-01T00:00:00Z \
  --granularity MONTHLY --query-type COST --group-by '["service","skuName"]' \
  --query 'data.items[?computedAmount > `0`].{svc:service,sku:skuName,amt:computedAmount,cur:currency}' \
  --output table
```

**OpenTofu s3 백엔드 (OCI Object Storage S3 호환)** — <https://opentofu.org/docs/language/settings/backends/s3/>
```
terraform {
  backend "s3" {
    bucket = "joshuatech-tfstate"
    key    = "platform/terraform.tfstate"
    region = "ap-chuncheon-1"
    endpoints = { s3 = "https://<NS>.compat.objectstorage.ap-chuncheon-1.oci.customer-oci.com" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = true   # If-None-Match 미지원이면 false로 내리고 CI에서 직렬화
  }
}
# 자격증명: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY = Customer Secret Key
```

**IMDS 차단 NetworkPolicy (vault 네임스페이스 제외 전 네임스페이스에 적용)** — <https://docs.oracle.com/en-us/iaas/Content/Identity/Tasks/callingservicesfrominstances.htm>
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: deny-imds, namespace: <NS>}
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - ipBlock: {cidr: 0.0.0.0/0, except: [169.254.169.254/32]}
```

### 함정

- A1 무료분 축소(2026-06-15): 공식 문서가 '모든 테넌시' 1,500 OCPU-h/9,000 GB-h로 바뀌었고 PAYG 적용 여부는 Oracle 지원 답변이 서로 모순됨. 설계(4 OCPU/26 GB)는 최악 월 ≈$30, 최선 월 ≈$2 — Budgets를 $35로 잡고 첫 달 usage-api로 실측해 확정할 것. Always Free 테넌시는 2026-08-18부터 초과 인스턴스 자동 종료 통보가 있었으나 PAYG는 과금 대상(종료 아님).
- S3 호환 API는 인스턴스 프린시펄 불가 — Customer Secret Key 필수. 사용자당 최대 2개, 만료 없음, 생성 시 1회만 표시. 관리자 개인 계정 대신 전용 서비스 사용자 사용.
- boto3/botocore ≥1.36(aws cli 포함)은 기본으로 CRC32 체크섬을 붙여 OCI S3 호환 API에서 실패한다. barman 사이드카와 aws cli 모두 AWS_REQUEST_CHECKSUM_CALCULATION=when_required, AWS_RESPONSE_CHECKSUM_VALIDATION=when_required 필요(plugin-barman-cloud 문서에도 동일 안내).
- S3 호환 API의 region은 OCI 리전 ID(ap-chuncheon-1)로 설정해야 한다. 앱이 리전을 못 바꾸면 us-east-1/공백만 가능하고 그 경우 홈 리전에서만 동작. SigV2 미지원(SigV4만).
- S3 API로 만든 버킷은 기본적으로 루트 컴파트먼트에 생성된다(namespace 메타데이터 default-s3-compartment). 버킷은 `oci os bucket create`로 platform 컴파트먼트에 미리 만들고 S3 API는 읽기/쓰기에만 사용.
- Vault ocikms 래퍼는 기동 시 management endpoint로 GetKey를 호출하므로 crypto·management 두 엔드포인트 모두 egress 허용 필요. Encrypt에 알고리즘을 지정하지 않으므로(OCI 기본 AES_256_GCM) 키는 반드시 AES 대칭 키(길이 32). 키 자동 회전을 켜면 회전마다 HSM key version이 늘어 테넌시 무료 20개를 소모.
- Virtual Private Vault(`--vault-type VIRTUAL_PRIVATE`)는 생성 즉시 시간당 과금이며 볼트 타입은 생성 후 변경 불가 — 반드시 DEFAULT로 생성.
- 인스턴스 프린시펄 = 노드 신원. 노드 A의 모든 pod가 169.254.169.254에 닿으면 KMS 권한을 얻으므로 NetworkPolicy로 vault 네임스페이스 외 IMDS egress 차단 + IMDS v1 비활성화. K3s는 기본 NetworkPolicy 컨트롤러가 켜져 있어 추가 CNI 불필요.
- 부트 볼륨 교체는 '같은 Linux 배포판'끼리만 허용(Oracle Linux↔Ubuntu 불가), Linux 전용, 마켓플레이스 이미지 불가. 기존 인스턴스가 Ubuntu가 아니면 이 경로가 막히므로 재이미지 전 `oci compute instance get`으로 현재 이미지의 OS를 먼저 확인.
- UpdateInstance는 metadata의 user_data와 ssh_authorized_keys를 변경할 수 없다. 재이미지 후 새 부트 볼륨의 cloud-init은 기존 ssh 키를 그대로 주입하지만 K3s 설치 등 부트스트랩을 cloud-init user_data로 바꿀 수는 없다 → SSH/Ansible(또는 cloudflared 터널 경유) 후처리로 설계.
- ephemeral 퍼블릭 IP는 reserved로 변환 불가(삭제 후 재생성 → 주소 변경 1회). reserved IP는 무료. 재이미지 자체(stop→교체→start)에서는 VNIC이 유지돼 ephemeral IP도 유지되지만 공식 문서가 이를 명시하지 않는다.
- Preserve 옵션으로 남긴 이전 부트 볼륨은 블록 볼륨 용량(Always Free 합계 200 GB, PAYG 초과분 과금)을 계속 점유 — 검증 후 즉시 삭제.
- Budgets는 24시간 주기 평가 + Cost Analysis 최대 48시간 지연 → 알림은 실제 지출보다 1~3일 늦다. 컴파트먼트당 예산 1개, 항상 루트 컴파트먼트에 생성, `manage usage-budgets in tenancy` 필요.
- Object Storage 무료분은 PAYG/유료 계정 기준 Standard 10 GB + IA 10 GB + Archive 10 GB, 요청 50,000건/월. WAL 아카이브 PUT이 요청 수에 들어가므로 archive_timeout을 과도하게 짧게(예: 30초) 잡지 말 것. 초과분 $0.0255/GB-월, PUT $0.0034/1만 건.
- OpenTofu에는 Terraform 1.16의 `oci` 네이티브 백엔드가 없다. s3 백엔드 `use_lockfile`은 OCI S3 호환 API의 If-None-Match 지원에 의존하며 미확인(oracle/terraform-provider-oci#2323 진행 중).
- `oci iam dynamic-group create`/`oci iam user create`는 Default 아이덴티티 도메인에만 동작(다른 도메인은 `oci identity-domains ...`). 이 테넌시는 Default 도메인만 쓰므로 문제 없음.
- 유휴 회수 임계는 2023년 10%→15%→현재 20%로 올라왔다. PAYG 전환이 회수를 막는다는 근거는 Oracle 안내 메일이며 문서에 PAYG 면제 조항은 없다.

### 미확인

- 기존 인스턴스(joshtech_api_1st, joshtech_cache)의 현재 OS/이미지: Ubuntu가 아니면 부트 볼륨 교체 경로가 '같은 배포판' 규칙에 막힌다 → `oci compute instance get`·`oci compute image get`으로 확인 필요.
- PAYG 테넌시의 실제 A1 무료분(1,500/9,000 vs 3,000/18,000): Oracle 지원 SR로 서면 확인 + 첫 달 usage-api 실측. 결과에 따라 노드 메모리 13→12 GB 조정 또는 비용 수용 결정.
- OCI S3 호환 API의 If-None-Match(조건부 PUT) 지원 여부: `aws s3api put-object --if-none-match '*'` 2회 호출로 실증 후 `use_lockfile` 유지/제거 결정.
- plugin-barman-cloud v0.14.0 ObjectStore CRD에서 사이드카 env 필드명(`instanceSidecarConfiguration.env`) 확인.
- S3 호환 엔드포인트 호스트: 문서는 `<ns>.compat.objectstorage.<region>.oci.customer-oci.com`, 구형 `…oraclecloud.com`도 통용 — ap-chuncheon-1에서 DNS 해석·인증서 확인.
- A1 단가($0.01/OCPU-h, $0.0015/GB-h)와 Reserved 퍼블릭 IP 무료 여부는 oracle.com 가격 페이지가 403이라 2차 출처(Oracle 블로그 요약·검색 결과)로만 확인 — 콘솔 Cost Estimator로 재확인.
- KMS FAQ/가격 페이지 403: 가상 볼트 무과금·HSM key version $0.53/월(20개 무료)은 검색 요약 기준. Always Free 문서의 '20 HSM key versions·소프트웨어 키 무료'만 1차 출처로 확인됨.
- `oci iam user update-user-capabilities --can-use-customer-secret-keys` 플래그 필요 여부(신규 사용자 기본값)는 CLI 레퍼런스로 재확인.
- 부트 볼륨 교체 시 보조 VNIC·연결된 블록 볼륨·ephemeral IP 보존은 문서가 명시하지 않음(롤백 절차에 '볼륨 상태 복원'만 언급). 노드 B(데이터)에 블록 볼륨이 있다면 교체 전 detach 여부 결정.
- Budgets 알림 메일이 Notifications 서비스 없이 직접 발송되는지 문서가 명시하지 않음(콘솔 UI상 recipients 직접 입력). 생성 후 테스트 규칙(ACTUAL 1%)으로 수신 확인.
