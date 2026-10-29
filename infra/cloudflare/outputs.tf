# 출력. 비밀(서비스 토큰·터널 토큰)은 sensitive — `tofu output -json <name>` 으로 운영자만 꺼내 Vault 에 넣는다.
# 화면·로그·파일에 남기지 않는다.

output "zone_id" {
  description = "joshuatech.dev zone id"
  value       = local.zone_id
}

output "account_id" {
  description = "존을 소유한 Cloudflare account id(비밀 아님)"
  value       = local.account_id
}

output "access_team_domain" {
  description = "Access JWT iss / JWKS 도메인"
  value       = local.access_team_domain
}

# AUD 는 비밀이 아니다 — pod ConfigMap ACCESS_AUD_M2M(identity-m2m-<env>)·ACCESS_AUD_ADMIN(admin) 에 그대로 준다.
output "access_app_aud" {
  description = "Access 앱 이름 → AUD 태그"
  value = merge(
    { for k, app in cloudflare_zero_trust_access_application.github : k => app.aud },
    { for k, app in cloudflare_zero_trust_access_application.identity_m2m : "identity-m2m-${k}" => app.aud },
    {
      auth-admin = cloudflare_zero_trust_access_application.auth_admin.aud
      ssh        = cloudflare_zero_trust_access_application.ssh.aud
      k8s        = cloudflare_zero_trust_access_application.k8s.aud
    },
  )
}

output "service_tokens" {
  description = "Access 서비스 토큰 이름 → { client_id, client_secret } (sensitive; Vault 투입 전 로컬 보관)"
  sensitive   = true
  value = {
    for k, t in cloudflare_zero_trust_access_service_token.tokens : k => {
      client_id     = t.client_id
      client_secret = t.client_secret
      expires_at    = t.expires_at
    }
  }
}

output "tunnel_id" {
  description = "cloudflared 터널 id(CNAME 대상 <id>.cfargotunnel.com)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.main.id
}

output "tunnel_token" {
  description = "cloudflared tunnel run --token 값(sensitive)"
  sensitive   = true
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.main.token
}

output "r2_public_bucket_name" {
  description = "공개 자산 R2 버킷 이름"
  value       = cloudflare_r2_bucket.public.name
}
