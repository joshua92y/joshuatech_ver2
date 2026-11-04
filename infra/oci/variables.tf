# 노드 재이미지 공용 변수 (T013 노드 B → T014 노드 A가 같은 변수를 재사용한다). 절차·스키마 근거는 instances.tf 머리 주석.
# 이 파일에 비밀은 없다(이미지 OCID·크기뿐). 운영자 SSH 공개 키(실명 joshuatech-ops; 설계 표기 jt-ops)는 tofu 변수가 아니다 —
# OCI API 가 인스턴스 metadata 의 ssh_authorized_keys·user_data 를 launch 뒤 불변으로 취급해 tofu 가 키를 배선할 곳이 없으므로,
# 키 교체는 호스트의 ~ubuntu/.ssh/authorized_keys 에서 한다(T013 은 instances.tf 6단계 수동, T014 는 host-prep.sh).
# 임시 SSH 규칙의 운영자 CIDR 도 변수로 두지 않는다 — 규칙은 tofu 밖(OCI CLI)에서 넣고 뺀다(instances.tf 머리 주석 "스키마·API 근거" 항목).
# provider 별 접속 변수(oci_auth·oci_config_profile·compartment_ocid)는 providers.tf, 예산 변수는 budget.tf 에 그대로 둔다.

# Canonical-Ubuntu-24.04-aarch64-2026.07.17-0 (ap-chuncheon-1, VM.Standard.A1.Flex = aarch64). tasks.md T013 문면으로 고정.
# 이미지를 올릴 때는 이 기본값 하나만 바꾼다 — 두 노드가 같은 이미지에서 떠야 한다(T014 가 노드 A에 같은 변수를 배선한다).
variable "ubuntu_2404_image_ocid" {
  type        = string
  description = "노드 부트 이미지 OCID: Canonical-Ubuntu-24.04-aarch64-2026.07.17-0 (ap-chuncheon-1). T013(노드 B)·T014(노드 A) 재이미지 공용."
  default     = "ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalxokbvhkaibe6ieaosyvzxih2xyglm3ypyiedbg3x4rpifmauw5a"

  validation {
    condition     = startswith(var.ubuntu_2404_image_ocid, "ocid1.image.oc1.ap-chuncheon-1.")
    error_message = "ubuntu_2404_image_ocid must be an image OCID of region ap-chuncheon-1 (prefix ocid1.image.oc1.ap-chuncheon-1.)."
  }
}

# 부트 볼륨 크기(GB): 47 → 100 (T013/T014). OCI 최소 50.
# Always Free 블록 스토리지 총량은 200 GB 다 — is_preserve_boot_volume_enabled = true 로 교체하면 창 동안 구·신 볼륨이 공존하므로
# 노드 B 교체 창 = 47(A) + 47(B 구) + 100(B 신) = 194, 노드 A(T014) 창 = 100(B) + 47(A 구) + 100(A 신) = 247.
# T014 전에 테넌시 한도(oci limits resource-availability get --service-name block-storage --limit-name total-storage-gb)를 확인할 것.
variable "node_boot_volume_size_gb" {
  type        = number
  description = "노드 부트 볼륨 크기(GB). 기본 100 (T013/T014). 정수, 50 이상."
  default     = 100

  validation {
    condition     = var.node_boot_volume_size_gb >= 50 && floor(var.node_boot_volume_size_gb) == var.node_boot_volume_size_gb
    error_message = "node_boot_volume_size_gb must be an integer >= 50 (OCI minimum boot volume size)."
  }
}
