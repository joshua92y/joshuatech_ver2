# R2: 공개 자산 버킷(apac) + 커스텀 도메인 cdn.joshuatech.dev(Image Transformations 원본 존).
# v1 의 버킷 joshtech 과 그 커스텀 도메인 cdn.joshuatech.dev 는 이 스택이 건드리지 않는다(import·수정 금지) —
# 새 커스텀 도메인은 v1 R2 도메인이 US8 에서 제거된 뒤에만 붙일 수 있어 var.enable_r2_custom_domain 으로 막아 둔다.

resource "cloudflare_r2_bucket" "public" {
  account_id = local.account_id
  name       = var.r2_public_bucket_name
  location   = "apac"
}

resource "cloudflare_r2_custom_domain" "cdn" {
  count = var.enable_r2_custom_domain ? 1 : 0 # US8 에서 true

  account_id  = local.account_id
  zone_id     = local.zone_id
  bucket_name = cloudflare_r2_bucket.public.name
  domain      = "cdn.${var.zone_name}"
  enabled     = true
  min_tls     = "1.2"
}
