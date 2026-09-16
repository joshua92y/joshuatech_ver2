# provider 자격은 .tf에 쓰지 않는다 — 운영자 셸의 VAULT_ADDR·VAULT_TOKEN에서만 읽는다(backend.tf 헤더 절차).
# (문서는 address를 Required로 적지만 5.11.0 스키마는 address·token 모두 Optional이라 디코드가 통과하고, `tofu validate`는
#  Configure를 건너뛰어 VAULT_ADDR 런타임 요구도 적용되지 않는다 → 무자격 하네스가 통과한다. 값은 Configure 시점에
#  VAULT_ADDR·VAULT_TOKEN(없으면 ~/.vault-token 폴백 — 그래서 `vault login` 금지)에서 읽는다.)
#
# provider는 주어진 토큰으로 **child 토큰**(TTL 20분)을 만들어 쓴다 → 호출 토큰에 `auth/token/create` update가 필요하다(root 보유).
# `skip_child_token = true`는 문서가 strongly discouraged라 쓰지 않는다(child 토큰은 상태에 들어가지 않는다).
provider "vault" {
  max_lease_ttl_seconds = 1200
}
