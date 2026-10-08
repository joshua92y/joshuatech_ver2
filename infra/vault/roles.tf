# infra/vault/roles.tf — Kubernetes auth role 6개 (T044) = eso 4 + vault-backup + e2e-reader (tasks T044 "auth role 합계 6")
#
# 계약(contracts/gitops-repo.md :108-110): role 이름 = bound SA 이름 · audiences [vault] · token_ttl 1h · token_max_ttl 4h.
#   예외 1건: `e2e-reader`의 bound SA는 `kube-system/agent-view`(hostnames-and-access.md :79).
# 필드 주의:
#   - provider 필드 이름은 **`audience`(단수 문자열)**. 계약 문면의 "audiences: [vault]"는 개념 표기.
#   - token_ttl/token_max_ttl은 **초 단위 정수**(1h=3600, 4h=14400). 기본 32일 금지.
#   - `token_type = "service"` 명시 — ESO checkToken(auth.go)은 batch 토큰을 "유효하지 않음"으로 돌려 캐시 재사용을 막고(매 reconcile 재로그인)
#     Close의 revoke-self도 건너뛴다; service 토큰이어야 lookup-self/revoke-self 흐름이 성립한다.
#   - `token_no_default_policy`는 쓰지 않는다(policies.tf 헤더). `alias_name_source` 미지정(기본 serviceaccount_uid).
#   - `bound_service_account_names`/`namespaces`에 `"*"`를 쓰지 않는다.
#   - e2e-reader 외 엔트리는 `sa` 키를 두지 않는다(role 이름 = SA 이름 규약을 코드로; 하네스 vt-9가 전수 대조).
# 확인 명령(부트스트랩 1회, VD-18):
#   kubectl create token vault-backup -n vault --audience vault --duration=10m | vault write -field=token auth/kubernetes/login role=vault-backup jwt=-

locals {
  roles = {
    "eso-platform" = { ns = "external-secrets" }
    "eso-dev"      = { ns = "external-secrets" }
    "eso-prod"     = { ns = "external-secrets" }
    "eso-data"     = { ns = "external-secrets" }
    "vault-backup" = { ns = "vault" }
    "e2e-reader"   = { ns = "kube-system", sa = "agent-view" }
  }
}

resource "vault_kubernetes_auth_backend_role" "this" {
  for_each = local.roles

  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = each.key
  bound_service_account_names      = [try(each.value.sa, each.key)]
  bound_service_account_namespaces = [each.value.ns]
  audience                         = "vault"
  token_policies                   = [each.key]
  token_ttl                        = 3600
  token_max_ttl                    = 14400
  token_type                       = "service"

  depends_on = [vault_policy.this]
}
