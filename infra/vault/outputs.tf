# 출력에는 시크릿을 두지 않는다(accessor와 이름 목록뿐).
output "kv_mount_accessor" {
  description = "kv v2 마운트 accessor(ESO 디버깅·감사 로그 대조용)"
  value       = vault_mount.kv.accessor
}

output "kubernetes_auth_accessor" {
  description = "auth/kubernetes accessor"
  value       = vault_auth_backend.kubernetes.accessor
}

output "auth_role_names" {
  description = "생성된 Kubernetes auth role 이름(계약 대조용, 6개)"
  value       = sort(keys(local.roles))
}
