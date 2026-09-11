# 존 설정(contracts/hostnames-and-access.md §오리진 보호 3중).
# provider 5.24 의 cloudflare_zone_setting 은 setting_id + value 형태이며 생성 시 PATCH 로 현재 값을 덮어쓴다 —
# 이미 손으로 맞춰 둔 값(SSL Full (strict), 2026-09-03)도 import 없이 그대로 채택된다.

# SSL 모드 Full (strict): 오리진 = cert-manager 와일드카드 *.joshuatech.dev(유효 CA 서명) — 자체 서명 불가.
resource "cloudflare_zone_setting" "ssl" {
  zone_id    = local.zone_id
  setting_id = "ssl"
  value      = "strict"
}

# HTTP → HTTPS 301 을 edge 에서 처리한다(오리진 80 은 열지 않는다 — NSG 443 만).
resource "cloudflare_zone_setting" "always_use_https" {
  zone_id    = local.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# 방문자 ↔ edge 최소 TLS 1.2.
resource "cloudflare_zone_setting" "min_tls_version" {
  zone_id    = local.zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# Authenticated Origin Pulls(global, zone 단위 mTLS). edge 가 오리진에 클라이언트 인증서를 제시한다;
# 오리진(Traefik TLSOption default)은 T043 에서 RequireAndVerifyClientCert 로 전환 완료(2026-09-11) — 이 설정을 끄면 오리진이 edge 를 거절해 플랫폼 호스트 전부 525/520 이다(끄지 말 것).
resource "cloudflare_zone_setting" "tls_client_auth" {
  zone_id    = local.zone_id
  setting_id = "tls_client_auth"
  value      = "on"
}
