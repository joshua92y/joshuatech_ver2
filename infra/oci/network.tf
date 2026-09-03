# 기존 VCN·서브넷·IGW·라우트 테이블·보안 리스트 — `tofu plan -generate-config-out`
# 결과(2026-09-03)를 정리한 파일 (T008). 현재 상태 그대로 코드화(diff 0 목표).
# 알려진 편차는 후속 태스크에서 수정한다:
#   보안 리스트의 0.0.0.0/0 22·80·443·8080·6379 ingress → T009,
#   VCN is_ipv6enabled=true → T009(명시 대상), ephemeral 공개 IP 허용 서브넷 → T009.
# manage_default_resource_id·default DHCP options는 생성 시 값 그대로 리터럴 유지(diff 0 우선).

# ---- VCN ----

resource "oci_core_vcn" "main" {
  cidr_block              = "10.0.0.0/16"
  cidr_blocks             = ["10.0.0.0/16"]
  compartment_id          = var.compartment_ocid
  defined_tags            = {}
  display_name            = "joshtech"
  dns_label               = "joshtech"
  freeform_tags           = {}
  ipv6private_cidr_blocks = []
  is_ipv6enabled          = true
  security_attributes     = {}

  lifecycle {
    prevent_destroy = true
  }
}

# ---- 인터넷 게이트웨이 ----

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  defined_tags   = {}
  display_name   = "Internet Gateway joshtech"
  enabled        = true
  freeform_tags  = {}
  route_table_id = oci_core_default_route_table.default.id
  vcn_id         = oci_core_vcn.main.id
}

# ---- 라우트 테이블 ----

resource "oci_core_route_table" "api" {
  compartment_id = var.compartment_ocid
  defined_tags   = {}
  display_name   = "joshtech_api"
  freeform_tags  = {}
  vcn_id         = oci_core_vcn.main.id
  route_rules {
    description       = ""
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
    route_type        = "STATIC"
  }
}

resource "oci_core_route_table" "cache" {
  compartment_id = var.compartment_ocid
  defined_tags   = {}
  display_name   = "joshtech_cashe_route" # 실제 표시 이름의 오탈자(cashe)를 그대로 유지 — 수정하면 diff가 생긴다
  freeform_tags  = {}
  vcn_id         = oci_core_vcn.main.id
  route_rules {
    description       = ""
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
    route_type        = "STATIC"
  }
}

resource "oci_core_default_route_table" "default" {
  compartment_id             = var.compartment_ocid
  defined_tags               = {}
  display_name               = "Default Route Table for joshtech"
  freeform_tags              = {}
  manage_default_resource_id = "ocid1.routetable.oc1.ap-chuncheon-1.aaaaaaaaguukxrmq4673ixkrcnwym6eajccw624embmupmp7rqfg2st55bjq"
}

# ---- 보안 리스트 ----

resource "oci_core_security_list" "api" {
  compartment_id = var.compartment_ocid
  defined_tags   = {}
  display_name   = "joshtech_api"
  freeform_tags  = {}
  vcn_id         = oci_core_vcn.main.id
  ingress_security_rules {
    description = ""
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    description = ""
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      max = 443
      min = 443
    }
  }
  ingress_security_rules {
    description = ""
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      max = 8080
      min = 8080
    }
  }
  ingress_security_rules {
    description = ""
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_security_list" "cache" {
  compartment_id = var.compartment_ocid
  defined_tags   = {}
  display_name   = "joshtech_cache"
  freeform_tags  = {}
  vcn_id         = oci_core_vcn.main.id
  ingress_security_rules {
    description = "joshtech_cache_22포트수"
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      max = 22
      min = 22
    }
  }
  ingress_security_rules {
    description = "redis 6379 포"
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      max = 6379
      min = 6379
    }
  }
}

resource "oci_core_default_security_list" "default" {
  compartment_id             = var.compartment_ocid
  defined_tags               = {}
  display_name               = "Default Security List for joshtech"
  freeform_tags              = {}
  manage_default_resource_id = "ocid1.securitylist.oc1.ap-chuncheon-1.aaaaaaaagsb7msdfxi6luoifig6zmlqpfcvc2xe46fzo32uvbeidba6uwwha"
  egress_security_rules {
    description      = ""
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }
  ingress_security_rules {
    description = ""
    protocol    = "1"
    source      = "10.0.0.0/16"
    source_type = "CIDR_BLOCK"
    stateless   = false
    icmp_options {
      code = -1
      type = 3
    }
  }
  ingress_security_rules {
    description = ""
    protocol    = "1"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    icmp_options {
      code = 4
      type = 3
    }
  }
  ingress_security_rules {
    description = ""
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      max = 22
      min = 22
    }
  }
}

# ---- 서브넷 ----

resource "oci_core_subnet" "api" {
  cidr_block                 = "10.0.4.0/22"
  compartment_id             = var.compartment_ocid
  defined_tags               = {}
  dhcp_options_id            = "ocid1.dhcpoptions.oc1.ap-chuncheon-1.aaaaaaaa2bcptnw6m7sckgwews4aztjz6btdxt3nmw3bofrrj67qskwxltua" # VCN 기본 DHCP options
  display_name               = "joshtech1st_api"
  dns_label                  = "subnet05190449"
  freeform_tags              = {}
  ipv4cidr_blocks            = ["10.0.4.0/22"]
  ipv6cidr_blocks            = []
  prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.api.id
  security_list_ids          = [oci_core_default_security_list.default.id, oci_core_security_list.api.id]
  vcn_id                     = oci_core_vcn.main.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_subnet" "cache" {
  cidr_block                 = "10.0.10.0/24"
  compartment_id             = var.compartment_ocid
  defined_tags               = {}
  dhcp_options_id            = "ocid1.dhcpoptions.oc1.ap-chuncheon-1.aaaaaaaa2bcptnw6m7sckgwews4aztjz6btdxt3nmw3bofrrj67qskwxltua" # VCN 기본 DHCP options
  display_name               = "joshtech1st_cache"
  dns_label                  = "cache"
  freeform_tags              = {}
  ipv4cidr_blocks            = ["10.0.10.0/24"]
  ipv6cidr_blocks            = []
  prohibit_internet_ingress  = false
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_route_table.cache.id
  security_list_ids          = [oci_core_default_security_list.default.id, oci_core_security_list.cache.id]
  vcn_id                     = oci_core_vcn.main.id

  lifecycle {
    prevent_destroy = true
  }
}
