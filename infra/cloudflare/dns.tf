# DNS(contracts/hostnames-and-access.md §DNS 레코드). 이 스택이 소유하는 레코드만 선언한다:
#   A 7(→ 노드 A reserved IP, proxied) + 터널 CNAME 3. 나머지는 건드리지 않는다 —
#   v1 전용 api·mainapi·mcp·cache 는 US8 까지 v1 오리진 유지, apex·www 는 T094/US8 컷오버, cdn 은 v1 R2 도메인,
#   메일 레코드(MX/TXT/DKIM/DMARC/SPF)·_acme-challenge 는 영구 제외.
# traefik 은 v1 레코드가 이미 있으므로 import 블록으로 가져와 값만 교체한다(import.tf; admin 은 존재하지 않아 신규 생성).
# proxied 레코드는 ttl = 1(automatic). name 은 FQDN(provider 5.x 가 API 반환값과 맞추는 형태).

locals {
  node_a_hosts = toset(["auth", "identity-m2m-prod", "identity-m2m-dev", "admin", "argo", "vault", "traefik"])
  tunnel_hosts = toset(["ssh-a", "ssh-b", "k8s"])
}

resource "cloudflare_dns_record" "node_a" {
  for_each = local.node_a_hosts

  zone_id = local.zone_id
  name    = "${each.key}.${var.zone_name}"
  type    = "A"
  content = var.node_a_reserved_ip
  proxied = true
  ttl     = 1
  comment = "v2 platform: node A (infra/cloudflare)"
}

resource "cloudflare_dns_record" "tunnel" {
  for_each = local.tunnel_hosts

  zone_id = local.zone_id
  name    = "${each.key}.${var.zone_name}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.main.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "v2 platform: cloudflared tunnel (infra/cloudflare)"
}
