# 기존 인스턴스 2대 — `tofu plan -generate-config-out` 결과(2026-09-03)를 정리한 파일 (T008).
# 현재 상태 그대로 코드화(diff 0 목표) — 알려진 편차는 후속 태스크에서 수정한다:
#   are_legacy_imds_endpoints_disabled=false(IMDS v1 활성) → T010,
#   ephemeral 공개 IP → T009, boot 볼륨 47GB → T013/T014.
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
    nsg_ids                   = []
    private_ip                = "10.0.7.78"
    private_ip_id             = ""
    security_attributes       = {}
    skip_source_dest_check    = false
    subnet_cidr               = ""
    subnet_id                 = oci_core_subnet.api.id
    vlan_id                   = ""
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = false
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
    ignore_changes  = [metadata, defined_tags, create_vnic_details[0].hostname_label]
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
    nsg_ids                   = []
    private_ip                = "10.0.10.193"
    private_ip_id             = ""
    security_attributes       = {}
    skip_source_dest_check    = false
    subnet_cidr               = ""
    subnet_id                 = oci_core_subnet.cache.id
    vlan_id                   = ""
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = false
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
    ignore_changes  = [metadata, defined_tags, create_vnic_details[0].hostname_label]
  }
}
