# Workers 커스텀 도메인 2 — 선언만. 둘 다 대상 Worker 가 존재한 뒤에만 만들 수 있으므로 apply 는
#   preview → T093(var.enable_workers_domain_preview = true),
#   apex    → T094(var.enable_workers_domain_apex = true; v1 apex CNAME joshtech-frontend.pages.dev 를 걷어낸 뒤 — 같은 이름의
#             레코드가 있으면 커스텀 도메인 생성이 거부된다)
# 에서 한다. `www` 는 Workers 도메인이 아니라 존 redirect rule 301 → apex(US8 컷오버 범위, 이 스택 밖).
# environment 는 지정하지 않는다(API 기본 "production"; wrangler env `preview` 는 스크립트 이름 joshuatech-web-preview 로 배포된다).

resource "cloudflare_workers_custom_domain" "preview" {
  count = var.enable_workers_domain_preview ? 1 : 0

  account_id = local.account_id
  zone_id    = local.zone_id
  hostname   = "preview.${var.zone_name}"
  service    = "joshuatech-web-preview"
}

resource "cloudflare_workers_custom_domain" "apex" {
  count = var.enable_workers_domain_apex ? 1 : 0

  account_id = local.account_id
  zone_id    = local.zone_id
  hostname   = var.zone_name
  service    = "joshuatech-web"
}
