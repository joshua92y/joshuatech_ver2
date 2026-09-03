# cloudflared 터널(remote-managed: 설정은 Cloudflare 쪽 config, cloudflared 는 토큰만 갖는다).
# ingress: ssh-a → 노드 A 22, ssh-b → 노드 B 22, k8s → K3s API 6443(클러스터 svc DNS) + catch-all 404.
# 공개 DNS 에는 CNAME 만(dns.tf), OCI 쪽 포트 개방 없음. 터널 토큰 출력은 sensitive(outputs.tf) — Vault 투입 전 로컬 보관.

resource "cloudflare_zero_trust_tunnel_cloudflared" "main" {
  account_id = local.account_id
  name       = "joshuatech-tunnel"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "main" {
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id
  source     = "cloudflare"

  config = {
    ingress = [
      {
        hostname = "ssh-a.${var.zone_name}"
        service  = "ssh://${var.node_a_private_ip}:22"
      },
      {
        hostname = "ssh-b.${var.zone_name}"
        service  = "ssh://${var.node_b_private_ip}:22" # 도달에는 NetworkPolicy cloudflared → 노드 B :22 행이 필요(contracts/network-policy.md)
      },
      {
        hostname = "k8s.${var.zone_name}"
        service  = "tcp://kubernetes.default.svc.cluster.local:6443"
      },
      {
        service = "http_status:404" # catch-all — 위 셋 외의 호스트는 404
      },
    ]
  }
}

# 터널 실행 토큰(cloudflared tunnel run --token) — sensitive 출력 전용.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "main" {
  account_id = local.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.main.id
}
