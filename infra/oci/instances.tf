# 기존 인스턴스 2대 — `tofu plan -generate-config-out` 결과(2026-09-03)를 정리한 파일 (T008).
# 현재 상태 그대로 코드화(diff 0 목표) — 알려진 편차는 후속 태스크에서 수정한다:
#   are_legacy_imds_endpoints_disabled: T010(2026-09-03)에서 false → true(IMDS v1 비활성; provider 문서상 instance_options와
#   그 하위 필드 모두 (Updatable) → in-place 갱신), boot 볼륨 47GB → T013/T014.
# T009(2026-09-03): nsg_ids 배선(노드 A: platform+cluster, 노드 B: cluster) —
#   provider 문서상 create_vnic_details.nsg_ids는 (Updatable)이라 VNIC in-place 갱신이다.
#   plan이 replace를 요구하면 prevent_destroy가 막는다 — 그 경우 진행하지 말고 보고한다.
#   assign_public_ip는 ignore_changes에 둔다 — 영구 가드(T010에서 문구 정정; 블록 내 주석).
# metadata의 ssh_authorized_keys는 공개 키이며 비밀이 아니다(키 교체는 별도 태스크 몫).

resource "oci_core_instance" "node_a" {
  availability_domain = "TxjY:AP-CHUNCHEON-1-AD-1"
  compartment_id      = var.compartment_ocid
  defined_tags        = {}
  display_name        = "joshtech_api_1st"
  extended_metadata   = {}
  fault_domain        = "FAULT-DOMAIN-3"
  freeform_tags       = {}
  metadata = {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLOZ71CEhQCsJoElCcU25q+/FOBwvFv/yfYKX/4osSFNHHGRGhTpF8VrcCruQKg2zPtV6krMP9THdF4B4c+Z4Rl30MQec8xHK973SBby7SQ1EjVTfrp23d396ng8JEVo0sQXHPi8gjkTpdFQ+7jcUyIM6r3vGK93gXcz4TEqUCmKiJF7DID5Kex9V3HQvXr304yU/QKfWnvkORWfHidVihM4aDSKBqzJIHAs7gjlZCqzVSURczRFD1vqNh8Ry3ndDSqEUgc4xzkszlEJfQ71Gmxmq4ORysgGce6Z2GRTuCQ8y6X5ao8qOjlgIMfDd78sduIHlf6hiS8cqOFYjIcpoOOxPBceljoSrftyuuMs+ld5VKMqKyZFkxwi+90dxvqadLutPZ0dBGZJE+EqTkqLW2qdQ+HnkMiYG5jRXHULP8zfAygjNc0YFuRT20UHr25A7CiNFcSjukDqAsNraW7fNXSX3Fv81LwFB79qFLn42OqjX5bpmPeTPckv1xp2gbz+tNVAIThynWcd48M0KtDmYhIF/E7EvQWthBSqJUPhZ0X9x9p27rRTGILAi1gZJYFjU1EPiSFV9kp0IIg6eJhpkgO17akYTVsf4yzkquLnoN+IZY5zAMhbd+MVXp+hrnhZlZkYiMEaDT0rfS7Q0JmJRktkO2UmoDefygqUdd2JNIEw== wlsgh@Home-2024"
  }
  security_attributes = {}
  shape               = "VM.Standard.A1.Flex"
  state               = "RUNNING"

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    is_live_migration_preferred = false
    recovery_action             = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = false
    assign_public_ip          = "true"
    defined_tags              = {}
    display_name              = "joshtech_api_1st"
    freeform_tags             = {}
    hostname_label            = "joshtech-api"
    # T009: 공개 경계(nsg-node-a-platform: Cloudflare→443) + 클러스터 내부(nsg-cluster).
    nsg_ids                = [oci_core_network_security_group.node_a_platform.id, oci_core_network_security_group.cluster.id]
    private_ip             = "10.0.7.78"
    private_ip_id          = ""
    security_attributes    = {}
    skip_source_dest_check = false
    subnet_cidr            = ""
    subnet_id              = oci_core_subnet.api.id
    vlan_id                = ""
  }

  # T010: IMDS v1(/opc/v1) 비활성 — .claude/rules/infra.md "IMDS v1 stays disabled". 노드 위 도구는 v2(/opc/v2 + Authorization: Bearer Oracle)만 쓴다.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  shape_config {
    baseline_ocpu_utilization = "BASELINE_1_1"
    local_volume_size_in_gbs  = 0
    memory_in_gbs             = 13
    nvmes                     = 0
    ocpus                     = 2
    resource_management       = ""
    vcpus                     = 2
  }

  source_details {
    boot_volume_size_in_gbs         = "47"
    boot_volume_vpus_per_gb         = "10"
    is_preserve_boot_volume_enabled = false
    kms_key_id                      = ""
    source_id                       = "ocid1.image.oc1.ap-chuncheon-1.aaaaaaaamwkrl3fycvbnrt6d3cztl22se3j3z5x22yxhfvedu3za2yjkoaca"
    source_type                     = "image"
  }

  lifecycle {
    prevent_destroy = true
    # assign_public_ip — 영구 가드(T010에서 문구 정정; T009의 "교체 창 임시 차단"이 아니다). 공개 IP의 소유자는
    # oci_core_public_ip(reserved, network.tf)다. provider 문서상 이 필드는 (Updatable)이며, 값이 바뀌면 provider가 VNIC의
    # 공개 IP를 직접 생성·삭제한다 — reserved IP가 붙어 있어도 예외가 아니라서 여기서 false로 읽히거나 바뀌면 그 reserved IP까지
    # 건드린다(주소 유실 경로). 따라서 컷오버가 끝나도 이 ignore는 유지한다: 이 리소스가 공개 IP를 절대 관리하지 않게 하는 상시 조치다.
    ignore_changes = [metadata, defined_tags, create_vnic_details[0].hostname_label, create_vnic_details[0].assign_public_ip]
  }
}

resource "oci_core_instance" "node_b" {
  availability_domain = "TxjY:AP-CHUNCHEON-1-AD-1"
  compartment_id      = var.compartment_ocid
  defined_tags        = {}
  display_name        = "joshtech_cache"
  extended_metadata   = {}
  fault_domain        = "FAULT-DOMAIN-1"
  freeform_tags       = {}
  metadata = {
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLOZ71CEhQCsJoElCcU25q+/FOBwvFv/yfYKX/4osSFNHHGRGhTpF8VrcCruQKg2zPtV6krMP9THdF4B4c+Z4Rl30MQec8xHK973SBby7SQ1EjVTfrp23d396ng8JEVo0sQXHPi8gjkTpdFQ+7jcUyIM6r3vGK93gXcz4TEqUCmKiJF7DID5Kex9V3HQvXr304yU/QKfWnvkORWfHidVihM4aDSKBqzJIHAs7gjlZCqzVSURczRFD1vqNh8Ry3ndDSqEUgc4xzkszlEJfQ71Gmxmq4ORysgGce6Z2GRTuCQ8y6X5ao8qOjlgIMfDd78sduIHlf6hiS8cqOFYjIcpoOOxPBceljoSrftyuuMs+ld5VKMqKyZFkxwi+90dxvqadLutPZ0dBGZJE+EqTkqLW2qdQ+HnkMiYG5jRXHULP8zfAygjNc0YFuRT20UHr25A7CiNFcSjukDqAsNraW7fNXSX3Fv81LwFB79qFLn42OqjX5bpmPeTPckv1xp2gbz+tNVAIThynWcd48M0KtDmYhIF/E7EvQWthBSqJUPhZ0X9x9p27rRTGILAi1gZJYFjU1EPiSFV9kp0IIg6eJhpkgO17akYTVsf4yzkquLnoN+IZY5zAMhbd+MVXp+hrnhZlZkYiMEaDT0rfS7Q0JmJRktkO2UmoDefygqUdd2JNIEw== wlsgh@Home-2024"
  }
  security_attributes = {}
  shape               = "VM.Standard.A1.Flex"
  state               = "RUNNING"

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    is_live_migration_preferred = false
    recovery_action             = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = false
    assign_public_ip          = "true"
    defined_tags              = {}
    display_name              = "joshtech_cache"
    freeform_tags             = {}
    hostname_label            = "joshtech-cache"
    # T009: 클러스터 내부(nsg-cluster)만 — 노드 B는 공개 ingress가 전혀 없다.
    nsg_ids                = [oci_core_network_security_group.cluster.id]
    private_ip             = "10.0.10.193"
    private_ip_id          = ""
    security_attributes    = {}
    skip_source_dest_check = false
    subnet_cidr            = ""
    subnet_id              = oci_core_subnet.cache.id
    vlan_id                = ""
  }

  # T010: IMDS v1(/opc/v1) 비활성 — .claude/rules/infra.md "IMDS v1 stays disabled". 노드 위 도구는 v2(/opc/v2 + Authorization: Bearer Oracle)만 쓴다.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  shape_config {
    baseline_ocpu_utilization = "BASELINE_1_1"
    local_volume_size_in_gbs  = 0
    memory_in_gbs             = 13
    nvmes                     = 0
    ocpus                     = 2
    resource_management       = ""
    vcpus                     = 2
  }

  source_details {
    boot_volume_size_in_gbs         = "47"
    boot_volume_vpus_per_gb         = "10"
    is_preserve_boot_volume_enabled = false
    kms_key_id                      = ""
    source_id                       = "ocid1.image.oc1.ap-chuncheon-1.aaaaaaaaxuyyow2meckrqx27dj3nphly7dwq5pu7sr3id5uqzuy3wdk3khya"
    source_type                     = "image"
  }

  lifecycle {
    prevent_destroy = true
    # assign_public_ip — 영구 가드(T010에서 문구 정정; T009의 "교체 창 임시 차단"이 아니다). 공개 IP의 소유자는
    # oci_core_public_ip(reserved, network.tf)다. provider 문서상 이 필드는 (Updatable)이며, 값이 바뀌면 provider가 VNIC의
    # 공개 IP를 직접 생성·삭제한다 — reserved IP가 붙어 있어도 예외가 아니라서 여기서 false로 읽히거나 바뀌면 그 reserved IP까지
    # 건드린다(주소 유실 경로). 따라서 컷오버가 끝나도 이 ignore는 유지한다: 이 리소스가 공개 IP를 절대 관리하지 않게 하는 상시 조치다.
    ignore_changes = [metadata, defined_tags, create_vnic_details[0].hostname_label, create_vnic_details[0].assign_public_ip]
  }
}
