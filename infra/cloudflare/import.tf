# 기존 자원 import 블록 — id 가 비어 있으면 for_each 가 빈 맵이 되어 블록이 생성되지 않는다(no-op).
# 운영자가 첫 apply 전에 id 를 조회해 TF_VAR_* 로 넘긴다(조회 명령은 variables.tf 의 각 변수 설명).
# import 가 끝나 state 에 들어간 뒤에는 변수를 비워 둬도 된다.

# v1 A 레코드 traefik.joshuatech.dev → cloudflare_dns_record.node_a["traefik"] (값은 노드 A reserved IP 로 교체된다).
# provider 5.x dns_record import id 형식: <zone_id>/<record_id>
import {
  for_each = { for k, v in { traefik = var.traefik_dns_record_id } : k => v if v != "" }

  to = cloudflare_dns_record.node_a[each.key]
  id = "${local.zone_id}/${each.value}"
}

# 존 http_request_firewall_managed entrypoint ruleset(Free Managed Ruleset 이 이미 배포된 경우) → cloudflare_ruleset.waf_managed.
# provider 5.x ruleset import id 형식: zones/<zone_id>/<ruleset_id>
import {
  for_each = { for k, v in { waf_managed = var.waf_managed_ruleset_id } : k => v if v != "" }

  to = cloudflare_ruleset.waf_managed
  id = "zones/${local.zone_id}/${each.value}"
}
