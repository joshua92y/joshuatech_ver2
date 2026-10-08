# 존 보안 규칙: Rate Limiting 1개(Free 한도 = 규칙 1개·10 s 주기·IP 기준) + WAF Free Managed Ruleset 의 상태 고정.
# Cache Rule 은 만들지 않는다 — 커스텀 도메인 Worker 가 캐시보다 먼저 실행되어 존 Cache Rule 이 응답에 닿지 않는다
# (대안인 프리렌더 HTML 자산화는 VD-2, T093 실측).

# ---- VD-3: Rate Limiting 표현식 ----
# 옵션 A(기본, var.ratelimit_use_host_condition = true): 옵션 B + (http.host eq "joshuatech.dev" and /api/*) 확대.
# 옵션 B(폴백, -var=false): 경로만 — /api/auth/* 또는 /if/flow/*.
# VD-3 실측 2026-09-03: Free 플랜에서 host 조건 수락(plan 1 change in-place → apply 성공) → 옵션 A 확정(옵션 B 폴백은 -var=false).
# 어느 쪽이든 호출 측 간격 ≥ 200 ms 규칙(T079·T087·T095)은 그대로다.
locals {
  ratelimit_expr_path_only = "(starts_with(http.request.uri.path, \"/api/auth/\")) or (starts_with(http.request.uri.path, \"/if/flow/\"))"
  ratelimit_expr_with_host = "${local.ratelimit_expr_path_only} or (http.host eq \"${var.zone_name}\" and starts_with(http.request.uri.path, \"/api/\"))"
  ratelimit_expression     = var.ratelimit_use_host_condition ? local.ratelimit_expr_with_host : local.ratelimit_expr_path_only
}

# IP당 10초 60회 초과 → block 10초. characteristics 의 cf.colo.id 는 Rulesets API 가 모든 요금제에서 요구한다.
resource "cloudflare_ruleset" "ratelimit" {
  zone_id     = local.zone_id
  kind        = "zone"
  phase       = "http_ratelimit"
  name        = "joshuatech-ratelimit"
  description = "Auth/login path rate limit (VD-3: option A adds host condition, option B path only)"

  rules = [
    {
      ref         = "auth_paths_60_per_10s"
      description = "Block an IP for 10s after 60 requests / 10s to auth paths"
      expression  = local.ratelimit_expression
      action      = "block"
      enabled     = true

      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = 10
        requests_per_period = 60
        mitigation_timeout  = 10
      }
    },
  ]
}

# ---- WAF: Cloudflare Free Managed Ruleset(id 77454fe2d30c4220b5701f6fdfb893ba) 배포를 IaC 로 고정 ----
# 새 규칙을 만드는 것이 아니라 Free 존에 기본 배포된 상태를 선언한다. 존에 이 단계의 entrypoint ruleset 이 이미 있으면
# 새 생성이 거부되므로 var.waf_managed_ruleset_id 로 import 한다(import.tf, 운영자 조회 명령은 variables.tf).
resource "cloudflare_ruleset" "waf_managed" {
  zone_id     = local.zone_id
  kind        = "zone"
  phase       = "http_request_firewall_managed"
  name        = "joshuatech-waf-managed"
  description = "Cloudflare Free Managed Ruleset deployment (state pin, no custom rules)"

  rules = [
    {
      ref         = "cloudflare_free_managed_ruleset"
      description = "Execute Cloudflare Free Managed Ruleset"
      expression  = "true"
      action      = "execute"
      enabled     = true

      action_parameters = {
        id = "77454fe2d30c4220b5701f6fdfb893ba"
      }
    },
  ]
}
