# 기존 VCN·서브넷·IGW·라우트 테이블·보안 리스트 — `tofu plan -generate-config-out`
# 결과(2026-09-03)를 정리한 파일 (T008). T009(2026-09-03)에서 네트워크 경계를 재정의했다:
#   - 보안 리스트의 0.0.0.0/0 22·80·443·8080·6379 ingress 전부 제거(egress-only) — ingress 책임은 NSG로 이동,
#   - NSG 2개 신설: nsg-node-a-platform(Cloudflare IPv4 → 443/tcp만) + nsg-cluster(자기참조 all),
#   - reserved 공개 IP 2개 선언(ephemeral → reserved 교체; ephemeral 삭제는 운영자 수동 단계 — 아래 주석),
#   - IPv6 미사용 명시(D-계열): is_ipv6enabled는 라이브 값 그대로 두고 어떤 서브넷·VNIC에도 IPv6를 배정하지 않는다.
# manage_default_resource_id·default DHCP options는 생성 시 값 그대로 리터럴 유지(diff 0 우선).

# ---- VCN ----

# IPv6 미사용 명시(T009, D-계열): is_ipv6enabled=true는 생성 시 라이브 값이며 여기서 바꾸지 않는다
# (false로 뒤집으면 라이브 VCN 갱신·/56 블록 회수 등 예측 불가한 변경 위험). IPv6는 설계상 미사용이다 —
# ipv6private_cidr_blocks=[]이고, 어떤 서브넷도 ipv6cidr_blocks를 갖지 않으며(아래 두 서브넷 주석),
# 어떤 VNIC도 assign_ipv6ip=true를 갖지 않는다(instances.tf). NSG·보안 리스트에도 IPv6 규칙이 없다.
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

# ---- 보안 리스트 (T009: egress-only) ----
# ingress 책임은 전부 NSG로 이동했다(nsg-node-a-platform: Cloudflare→443, nsg-cluster: 노드 간 all).
# SSH(22)는 이제부터 cloudflared 터널로만 접근한다(T011/T014); 임시 SSH가 필요하면
# T013 절차의 임시 NSG 규칙을 쓴다 — 보안 리스트에 ingress를 되살리지 않는다.
# 적용 순서 주의: 이 SL ingress 제거와 인스턴스 nsg_ids 부착 사이에는 의존성이 없어서
# 단일 apply에서는 SL 제거가 NSG 부착보다 먼저 실행될 수 있다(수 초의 443 단절 위험).
# 컷오버 절차는 NSG·인스턴스를 -target으로 먼저 적용한 뒤 SL을 적용한다(runbook 절차 참조).

resource "oci_core_security_list" "api" {
  compartment_id = var.compartment_ocid
  defined_tags   = {}
  display_name   = "joshtech_api"
  freeform_tags  = {}
  vcn_id         = oci_core_vcn.main.id
  # ingress 없음(egress-only) — 이전의 0.0.0.0/0 22·80·443·8080은 T009에서 제거.
  # egress는 default 보안 리스트(아래)의 0.0.0.0/0 all이 담당한다(두 서브넷 모두 default SL을 함께 부착).
}

resource "oci_core_security_list" "cache" {
  compartment_id = var.compartment_ocid
  defined_tags   = {}
  display_name   = "joshtech_cache"
  freeform_tags  = {}
  vcn_id         = oci_core_vcn.main.id
  # ingress 없음(egress-only) — 이전의 0.0.0.0/0 22·6379는 T009에서 제거.
  # 노드 간 redis 6379는 nsg-cluster(자기참조 all)가 사설 IP 경로로 허용한다 —
  # v1 API의 redis 접속 문자열이 공인 IP가 아니라 10.0.10.193을 쓰는지 컷오버 전에 확인할 것.
}

resource "oci_core_default_security_list" "default" {
  compartment_id             = var.compartment_ocid
  defined_tags               = {}
  display_name               = "Default Security List for joshtech"
  freeform_tags              = {}
  manage_default_resource_id = "ocid1.securitylist.oc1.ap-chuncheon-1.aaaaaaaagsb7msdfxi6luoifig6zmlqpfcvc2xe46fzo32uvbeidba6uwwha"
  # ingress 없음(egress-only) — 이전의 ICMP(10.0.0.0/16 type3, 0.0.0.0/0 type3/code4)·0.0.0.0/0 22는
  # T009에서 제거. 노드 간 ICMP는 nsg-cluster(all)가 담당한다.
  egress_security_rules {
    description      = ""
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }
}

# ---- 서브넷 ----

resource "oci_core_subnet" "api" {
  cidr_block      = "10.0.4.0/22"
  compartment_id  = var.compartment_ocid
  defined_tags    = {}
  dhcp_options_id = "ocid1.dhcpoptions.oc1.ap-chuncheon-1.aaaaaaaa2bcptnw6m7sckgwews4aztjz6btdxt3nmw3bofrrj67qskwxltua" # VCN 기본 DHCP options
  display_name    = "joshtech1st_api"
  dns_label       = "subnet05190449"
  freeform_tags   = {}
  ipv4cidr_blocks = ["10.0.4.0/22"]
  # IPv6 미사용 명시(T009): 이 서브넷에 IPv6 CIDR을 배정하지 않는다(빈 배열이 의도된 값).
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
  cidr_block      = "10.0.10.0/24"
  compartment_id  = var.compartment_ocid
  defined_tags    = {}
  dhcp_options_id = "ocid1.dhcpoptions.oc1.ap-chuncheon-1.aaaaaaaa2bcptnw6m7sckgwews4aztjz6btdxt3nmw3bofrrj67qskwxltua" # VCN 기본 DHCP options
  display_name    = "joshtech1st_cache"
  dns_label       = "cache"
  freeform_tags   = {}
  ipv4cidr_blocks = ["10.0.10.0/24"]
  # IPv6 미사용 명시(T009): 이 서브넷에 IPv6 CIDR을 배정하지 않는다(빈 배열이 의도된 값).
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

# ---- NSG (T009) ----
# ingress의 유일한 소유자. 규칙 계약(.claude/rules/infra.md):
#   443 ingress는 Cloudflare IPv4 대역에만 열린다. 0.0.0.0/0 ingress 금지. 22는 절대 공개하지 않는다.

# Cloudflare 공표 IP 대역(https://api.cloudflare.com/client/v4/ips) — plan 시점에 조회된다.
# 운영자 plan/apply 시 CLOUDFLARE_API_TOKEN 환경 변수가 필요하다(providers.tf 주석 참조).
data "cloudflare_ip_ranges" "cloudflare" {}

# 노드 A 공개 서비스 경계: Cloudflare IPv4 → 443/tcp 만. 그 외 ingress 없음.
resource "oci_core_network_security_group" "node_a_platform" {
  compartment_id = var.compartment_ocid
  display_name   = "nsg-node-a-platform"
  vcn_id         = oci_core_vcn.main.id
}

# Cloudflare IPv4 CIDR마다 규칙 1개(for_each). 목록이 바뀌면 다음 plan에서 규칙이 증감한다.
resource "oci_core_network_security_group_security_rule" "node_a_platform_443" {
  for_each = toset(data.cloudflare_ip_ranges.cloudflare.ipv4_cidrs)

  network_security_group_id = oci_core_network_security_group.node_a_platform.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = each.value
  source_type               = "CIDR_BLOCK"
  stateless                 = false
  description               = "Cloudflare IPv4 -> 443/tcp"

  tcp_options {
    destination_port_range {
      min = 443
      max = 443
    }
  }
}

# 클러스터 내부 경계: 자기참조 all — 이 NSG에 속한 VNIC끼리(사설 IP 경로) 모든 프로토콜 허용.
# 두 노드 모두 가입한다(instances.tf nsg_ids). K3s 6443/10250/51820과 현행 v1의 노드 간
# redis 6379 트래픽을 모두 덮는다. 공인 IP를 경유한 노드 간 통신은 NSG 소속 매칭이 되지 않으므로
# 차단된다 — v1 설정이 사설 IP(10.0.7.78 ↔ 10.0.10.193)를 쓰는지 컷오버 전에 확인할 것.
resource "oci_core_network_security_group" "cluster" {
  compartment_id = var.compartment_ocid
  display_name   = "nsg-cluster"
  vcn_id         = oci_core_vcn.main.id
}

resource "oci_core_network_security_group_security_rule" "cluster_self_all" {
  network_security_group_id = oci_core_network_security_group.cluster.id
  direction                 = "INGRESS"
  protocol                  = "all"
  source                    = oci_core_network_security_group.cluster.id
  source_type               = "NETWORK_SECURITY_GROUP"
  stateless                 = false
  description               = "cluster-internal: all protocols between members of nsg-cluster"
}

# ---- reserved 공개 IP (T009) ----
# ephemeral → reserved 교체. OCI 제약: private IP 1개는 공개 IP를 1개만 가질 수 있으므로
# 기존 ephemeral(노드 A 152.69.233.183, 노드 B 158.180.87.55)을 운영자가 콘솔/CLI로 먼저 삭제해야
# 아래 attach(create가 곧 assign)가 성공한다. 순서: NSG·SL 적용 → ephemeral 삭제(수동) → 이 리소스 apply
# → 새 reserved 주소 확인 → v1 DNS(api·mainapi 등) 재지정. 상세 절차는 컷오버 runbook에 기록한다.
# 주소가 바뀌므로 v1 DNS 재지정 전까지 해당 노드의 공개 트래픽이 끊긴다(중단 창 최소화 절차 필수).

# 각 노드 primary private IP의 OCID 조회(공개 IP는 private IP OCID에 attach된다).
data "oci_core_private_ips" "node_a_primary" {
  subnet_id  = oci_core_subnet.api.id
  ip_address = "10.0.7.78"
}

data "oci_core_private_ips" "node_b_primary" {
  subnet_id  = oci_core_subnet.cache.id
  ip_address = "10.0.10.193"
}

resource "oci_core_public_ip" "node_a" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "joshuatech-node-a"
  private_ip_id  = data.oci_core_private_ips.node_a_primary.private_ips[0].id

  # reserved 주소는 DNS가 가리키는 고정 자산 — 파괴는 곧 주소 유실이다.
  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_public_ip" "node_b" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "joshuatech-node-b"
  private_ip_id  = data.oci_core_private_ips.node_b_primary.private_ips[0].id

  lifecycle {
    prevent_destroy = true
  }
}

# apply 후 운영자가 v1 DNS 재지정에 쓸 새 주소.
output "node_a_reserved_public_ip" {
  description = "노드 A(joshtech_api_1st) reserved 공개 IP — v1 DNS(api·mainapi 등) 재지정 대상"
  value       = oci_core_public_ip.node_a.ip_address
}

output "node_b_reserved_public_ip" {
  description = "노드 B(joshtech_cache) reserved 공개 IP"
  value       = oci_core_public_ip.node_b.ip_address
}
