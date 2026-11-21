# infra/vault/policies.tf — ACL 정책 6개 (T044)
#
# 정책 본문은 heredoc 인라인이다(설계 확정). 별도 `policies/*.hcl` + `file()`을 쓰지 않는 이유: tests/infra/tofu.tests.ps1의
#   New-TfValidateCopy가 최상위 *.tf(backend.tf 제외)·.terraform.lock.hcl·.terraform/providers만 복사하고 하위 디렉터리는 복사하지 않으므로 무자격 validate가
#   "no file exists at ./policies/…"로 깨진다(oci·cloudflare 공유 함수를 고치지 않는다).
# ⚠ tofu.tests.ps1 머리 주석 「게이트/전제」 [tf-text] 항목의 heredoc 금지는 **infra/oci 한정**(중괄호 파서 대상)이다. infra/vault 단언은 정규식 텍스트 검사만 쓰므로
#   이 디렉터리에 중괄호 파서 기반 단언을 추가하지 않는다(스위트 헤더에 명시).
#
# 공통 규칙:
#   - eso-*·e2e-reader·vault-backup 정책의 capabilities는 정확히 ["read"]다(계약 contracts/gitops-repo.md §ClusterSecretStore 5개 표 —
#     metadata도 read; list는 비밀 이름 전수 열거라 주지 않는다. ESO가 dataFrom.find를 쓰게 되면 계약을 먼저 고친다).
#     예외는 정확히 하나 — eso-platform의 `kv/data/platform/access/*` · `kv/metadata/platform/access/*` ["deny"] 두 줄(UD-15 · T076 —
#     아래 eso-platform 주석). 하네스 vt-14 · vt-14b가 이 예외의 모양(정책 · 경로 · 줄 수)을 고정한다.
#   - `token_no_default_policy`는 **어떤 role에도 걸지 않는다**(roles.tf): ESO는 로그인 후 auth/token/lookup-self, 종료 시 revoke-self를
#     부르고 platform-backup.sh도 `vault token revoke -self`를 쓴다 — 둘 다 내장 `default` 정책에만 있다(default는 kv 권한 0).
#   - 최소권한 토큰(e2e-reader)의 읽기 명령은 `vault read kv/data/...`(정책 exact path와 동일) 또는 HTTP API로 고정한다.
#     `vault kv get`의 preflight(`sys/internal/ui/mounts/kv`)는 Vault가 Unauthenticated 특수 경로로 두고 마운트 하위 권한 유무만
#     (hasMountAccess) 보므로 통과할 수 있으나 실측 전이다(VD-19, T077) — 여기서 403을 단정하지 않는다.

locals {
  policies = {
    # --- ESO store 4개 (다섯 번째 store k8s-data-ca는 kubernetes provider라 Vault role이 없다 — T045) ---
    # eso-platform deny 두 줄(UD-15 · T076): tester Access 서비스 토큰(`kv/platform/access/*`)은 「ESO 밖」이다(data-model §8) — 그것을 관례가
    #   아니라 Vault ACL로 강제한다. store `vault-platform`은 플랫폼 ns 12곳에 열려 있어, 이 deny가 없으면 ExternalSecret 하나로 tester-m2m이
    #   K8s Secret이 될 수 있다. 더 긴 경로 규칙이 이긴다(Vault 정책 우선순위 — 첫 glob이 더 뒤에 있는 패턴이 우선)라 나머지 `platform/*`
    #   읽기는 그대로다. 지금 `platform/access/*`를 읽는 ExternalSecret은 0이다.
    "eso-platform" = <<-EOT
      path "kv/data/platform/*" { capabilities = ["read"] }
      path "kv/metadata/platform/*" { capabilities = ["read"] }
      path "kv/data/platform/access/*" { capabilities = ["deny"] }
      path "kv/metadata/platform/access/*" { capabilities = ["deny"] }
    EOT

    "eso-dev" = <<-EOT
      path "kv/data/dev/*" { capabilities = ["read"] }
      path "kv/metadata/dev/*" { capabilities = ["read"] }
    EOT

    "eso-prod" = <<-EOT
      path "kv/data/prod/*" { capabilities = ["read"] }
      path "kv/metadata/prod/*" { capabilities = ["read"] }
    EOT

    # eso-data: **열거 경로만**. `kv/data/dev/*`나 `kv/data/+/db/*` 같은 env/세그먼트 와일드카드는 금지 —
    # 미래에 추가되는 env·컴포넌트까지 자동으로 열어 준다(계약 §ClusterSecretStore vault-data 행, data-model §8). 블록 수 정확히 20.
    "eso-data" = <<-EOT
      path "kv/data/dev/db/*" { capabilities = ["read"] }
      path "kv/data/dev/kafka/*" { capabilities = ["read"] }
      path "kv/data/dev/dragonfly/*" { capabilities = ["read"] }
      path "kv/data/dev/openfga/*" { capabilities = ["read"] }
      path "kv/data/dev/authentik/webhooks/*" { capabilities = ["read"] }
      path "kv/data/prod/db/*" { capabilities = ["read"] }
      path "kv/data/prod/kafka/*" { capabilities = ["read"] }
      path "kv/data/prod/dragonfly/*" { capabilities = ["read"] }
      path "kv/data/prod/openfga/*" { capabilities = ["read"] }
      path "kv/data/prod/authentik/webhooks/*" { capabilities = ["read"] }
      path "kv/metadata/dev/db/*" { capabilities = ["read"] }
      path "kv/metadata/dev/kafka/*" { capabilities = ["read"] }
      path "kv/metadata/dev/dragonfly/*" { capabilities = ["read"] }
      path "kv/metadata/dev/openfga/*" { capabilities = ["read"] }
      path "kv/metadata/dev/authentik/webhooks/*" { capabilities = ["read"] }
      path "kv/metadata/prod/db/*" { capabilities = ["read"] }
      path "kv/metadata/prod/kafka/*" { capabilities = ["read"] }
      path "kv/metadata/prod/dragonfly/*" { capabilities = ["read"] }
      path "kv/metadata/prod/openfga/*" { capabilities = ["read"] }
      path "kv/metadata/prod/authentik/webhooks/*" { capabilities = ["read"] }
    EOT

    # --- 백업(노드 A platform-backup.sh) ---
    # 스냅샷 저장은 GET /sys/storage/raft/snapshot(= read)이고 sudo를 요구하지 않는다.
    # 복원(POST snapshot / snapshot-force)은 update 권한이라 자동으로 차단된다 — 백업 주체는 복원 불가(VD-18).
    "vault-backup" = <<-EOT
      path "sys/storage/raft/snapshot" { capabilities = ["read"] }
    EOT

    # --- E2E(tester) --- 와일드카드 · metadata 경로 없이 정확히 두 경로(UD-15 · T076 — 이전 「정확히 한 경로」):
    #   authentik/e2e = E2E 사용자 비밀번호 · TOTP 시드(T077 Playwright) · access/tester-m2m = Access 서비스 토큰(T076 O-8 블록 안에서만).
    #   `tester-k8s`는 넣지 않는다(정책 밖 = deny).
    "e2e-reader" = <<-EOT
      path "kv/data/platform/authentik/e2e" { capabilities = ["read"] }
      path "kv/data/platform/access/tester-m2m" { capabilities = ["read"] }
    EOT
  }
}

resource "vault_policy" "this" {
  for_each = local.policies

  name   = each.key
  policy = each.value
}
