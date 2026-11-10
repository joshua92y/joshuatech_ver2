# 존·계정 식별자 조회. provider 5.24 의 data.cloudflare_zones 는 result[*].account.id 를 함께 돌려주므로
# account id 를 별도 변수·data.cloudflare_accounts 없이 존 하나로 얻는다(토큰에 Account 읽기 권한을 추가로 요구하지 않는다).

data "cloudflare_zones" "main" {
  name = var.zone_name

  lifecycle {
    postcondition {
      condition     = length(self.result) == 1
      error_message = "Expected exactly one Cloudflare zone named ${var.zone_name}; check CLOUDFLARE_API_TOKEN zone scope."
    }
  }
}

locals {
  zone_id    = data.cloudflare_zones.main.result[0].id
  account_id = data.cloudflare_zones.main.result[0].account.id

  # Zero Trust 팀 joshua-tech(운영자 확인 2026-09-03) — Access JWT iss / JWKS(/cdn-cgi/access/certs) 도메인. 출력 참고용.
  access_team_domain = "joshua-tech.cloudflareaccess.com"
}
