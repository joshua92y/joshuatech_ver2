# KMS (T010): 볼트(DEFAULT 타입 — 공유 파티션, 무료 등급) + AES-256 마스터 키(protection_mode SOFTWARE, 자동 회전 off).
# 용도: 노드 A 인스턴스 주체(동적 그룹 joshuatech-node-a, iam.tf)가 `use keys … where target.key.id`로만 쓰는 플랫폼 키.
# 이름은 §0 이름 예외 패턴(joshuatech-*)을 따른다: 볼트 joshuatech-vault · 키 joshuatech-key.
#
# 삭제 정책: 볼트·키 모두 lifecycle prevent_destroy — 이 스택에서는 절대 파괴하지 않는다(tofu destroy 금지 규칙과 별개로 계획 단계에서 막는다).
# 정말 폐기해야 할 때만 운영자가 콘솔/CLI로 "삭제 예약(schedule deletion)"을 걸되 대기 기간은 최대인 30일만 쓴다
# (tasks T010 표기: `--wait-days 30`; 즉시 삭제 불가, 대기 중 예약 취소 가능). 회전(rotate)은 새 키 버전을 만들 뿐 이전 버전을 없애지 않지만
# 이 키는 회전 off가 결정값이다(is_auto_rotation_enabled = false). protection_mode는 생성 후 변경 불가(SOFTWARE 고정).

resource "oci_kms_vault" "platform" {
  compartment_id = var.compartment_ocid
  display_name   = "joshuatech-vault"
  vault_type     = "DEFAULT"

  lifecycle {
    prevent_destroy = true
  }
}

# kms-2 [tf-text] 단언이 이 블록을 원문 파싱한다 — 블록 안에는 전체 행 주석만 둔다.
resource "oci_kms_key" "platform" {
  compartment_id           = var.compartment_ocid
  display_name             = "joshuatech-key"
  management_endpoint      = oci_kms_vault.platform.management_endpoint
  protection_mode          = "SOFTWARE"
  is_auto_rotation_enabled = false

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ---- 출력 (Vault auto-unseal 등 후속 태스크가 참조) ----

output "kms_key_id" {
  description = "플랫폼 AES-256 마스터 키 OCID(joshuatech-key) — 동적 그룹 정책의 target.key.id 값과 동일"
  value       = oci_kms_key.platform.id
}

output "kms_crypto_endpoint" {
  description = "볼트 crypto 엔드포인트(Encrypt/Decrypt/GenerateDataEncryptionKey)"
  value       = oci_kms_vault.platform.crypto_endpoint
}

output "kms_management_endpoint" {
  description = "볼트 management 엔드포인트(키 Create/Get/List/Update/Delete)"
  value       = oci_kms_vault.platform.management_endpoint
}
