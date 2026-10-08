# infra/vault/main.tf — kv v2 마운트 + Kubernetes auth method (T044)
#
# 계약: contracts/gitops-repo.md §ClusterSecretStore(마운트 `kv`, role 이름 = SA 이름, audiences [vault], TTL 1h/4h)
#       ADR 0010 §6 부트스트랩 순서 ② helm → ③ init → (audit enable은 CLI 1회, 설계 D5) → ④ 이 스택 → ⑤ ESO + store 5(T045).

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv-v2"
  description = "platform/dev/prod secrets consumed by External Secrets Operator (T044)"

  # `options`는 생략한다 — provider가 kv-v2를 kv+version=2의 별칭으로 인식한다(소스 주석: options block may be omitted).
}

resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  path        = "kubernetes"
  description = "K3s service account login for ESO / backup / e2e (T044)"

  # ⚠ enable/disable(POST·DELETE `sys/auth/kubernetes`)은 sudo(root-protected `auth/*`)다. refresh(plan)는 provider가
  #   `sys/mounts/auth/kubernetes`(+`/tune`)를 읽으므로(vault/api sys_auth.go: "so we don't require sudo") Vault 2.0.4에서는 sudo가
  #   필요 없다 — 정례 plan은 read 전용 정책(sys/mounts/auth/kubernetes{,/tune} · sys/mounts/kv{,/tune} · auth/kubernetes/config ·
  #   auth/kubernetes/role/* · sys/policies/acl/*) + child 토큰용 auth/token/create(default 정책)로 가능하고, apply의 mount/auth 변경만
  #   root 또는 D4 관리 경로가 필요하다(런북 §4). Vault main은 `sys/mounts/auth/+/tune`을 root-protected로 승격했으므로 업그레이드 시 재확인.
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend = vault_auth_backend.kubernetes.path

  # 워크스테이션에서 apply하므로 pod 내부 $KUBERNETES_SERVICE_HOST를 보간할 수 없다 → 리터럴.
  # ns vault 정책에 allow-dns가 있어 해석되고, ClusterIP는 DNAT 뒤 노드 A:6443이 되어 allow-kube-api가 덮는다.
  # 로그인 실패(연결) 시 대안 "https://10.0.7.78:6443"(정책 변경 불필요) — VD-18.
  kubernetes_host = "https://kubernetes.default.svc:443"

  # ⚠ **필수**: provider는 이 필드를 GetOk가 아니라 d.Get으로 **무조건** 전송한다 → 생략하면 SDK 제로값 false가 기록되어
  #   issuer 검증이 켜지고, 기본 기대 issuer와 K3s 실제 iss가 달라 **6개 role의 모든 로그인이 조용히 실패**한다.
  disable_iss_validation = true

  # token_reviewer_jwt·kubernetes_ca_cert는 **설정하지 않는다**: Vault가 자기 파드의 로컬 SA 토큰과 CA를 리뷰어로 재읽는다(1.9.3+,
  # 차트 `server.authDelegator.enabled: true`가 system:auth-delegator CRB를 만든다). 설정하면 장수명 JWT가 상태 파일에 평문으로 남는다.
  # disable_local_ca_jwt도 생략(provider가 GetOk로 읽어 false는 전송하지 않는다).
}
