# infra/vault — Vault 내부 설정 스택(T044): kv v2 마운트 · kubernetes auth · 정책 6 · role 6.
# provider 핀은 vault 하나뿐이다. `.terraform.lock.hcl`을 커밋한다(registry.opentofu.org/hashicorp/vault 5.11.0).
#
# 이 스택이 소유하지 "않는" 것:
#   - Vault 서버 배포(helm) → platform-gitops `platform/vault/`
#   - 감사 장치(`sys/audit`) → **CLI 1회**(설계 D5). list·enable·disable이 전부 sudo라 tofu가 소유하면 매 plan의 refresh가 sudo를 요구한다.
#   - kv **값** → 운영자 `vault kv put`(T044 플레이스홀더 8경로 · T045 시드 · T081/T082 실값). 상태 파일에 비밀을 남기지 않는다.
#   - ClusterSecretStore/ExternalSecret → platform-gitops `secrets/`(T045)
#   - role `identity-admin` · 정책 `pod-identity-admin` · OIDC auth method(US4)
terraform {
  required_version = ">= 1.12.6"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.11.0"
    }
  }
}
