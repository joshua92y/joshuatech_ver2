# 입력 변수. 비밀은 어떤 변수에도 기본값을 두지 않는다 — 운영자가 TF_VAR_<name> 환경 변수로만 넘긴다.
# 게이트 변수(enable_*)는 아직 apply 하면 안 되는 자원을 막는다: 기본 false, 켜는 태스크를 주석에 적었다.

# ---- 존·계정 ----

variable "zone_name" {
  description = "관리 대상 Cloudflare 존 이름. zone id·account id는 data.cloudflare_zones 로 조회한다(data.tf)."
  type        = string
  default     = "joshuatech.dev"
}

# ---- 노드 IP(OCI 스택이 소유하는 사실값 — 운영자 확인 2026-09-03; 공인 reserved IP·RFC 1918 사설 IP는 비밀이 아니다) ----

variable "node_a_reserved_ip" {
  description = "노드 A reserved 공인 IP — auth·*-m2m-*·admin·argo·vault·traefik A 레코드의 값(dns.tf)."
  type        = string
  default     = "144.24.85.118"

  validation {
    condition     = can(cidrhost("${var.node_a_reserved_ip}/32", 0))
    error_message = "node_a_reserved_ip must be a single IPv4 address."
  }
}

variable "node_a_private_ip" {
  description = "노드 A VCN 사설 IP — 터널 ingress ssh-a → ssh://<ip>:22 (tunnel.tf)."
  type        = string
  default     = "10.0.7.78"

  validation {
    condition     = can(cidrhost("${var.node_a_private_ip}/32", 0))
    error_message = "node_a_private_ip must be a single IPv4 address."
  }
}

variable "node_b_private_ip" {
  description = "노드 B VCN 사설 IP — 터널 ingress ssh-b → ssh://<ip>:22 (tunnel.tf)."
  type        = string
  default     = "10.0.10.193"

  validation {
    condition     = can(cidrhost("${var.node_b_private_ip}/32", 0))
    error_message = "node_b_private_ip must be a single IPv4 address."
  }
}

# ---- Access: GitHub IdP(운영자가 GitHub OAuth App을 만들고 두 값을 TF_VAR_* 로 넘긴다; 기본값 없음) ----
# OAuth App 콜백 URL: https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/callback

variable "github_oauth_client_id" {
  description = "Cloudflare Access GitHub IdP용 GitHub OAuth App Client ID (TF_VAR_github_oauth_client_id)."
  type        = string
  nullable    = false
}

variable "github_oauth_client_secret" {
  description = "같은 OAuth App의 Client Secret (TF_VAR_github_oauth_client_secret). 비밀 — 기본값 없음, 출력 금지."
  type        = string
  sensitive   = true
  nullable    = false
}

variable "operator_email" {
  description = <<-EOT
    admin-github·admin-github-ssh 정책이 allow 하는 운영자 이메일(contracts/hostnames-and-access.md §Access 정책 규칙).
    기본값 없음 — TF_VAR_operator_email 로 반드시 지정. 운영자의 GitHub 계정이 Cloudflare Access 에 보고하는 기본(primary)
    이메일이어야 하며, 값이 다르면 admin/ssh/k8s 등 GitHub IdP 앱 전부에서 로그인이 거부된다.
    include 값은 GitHub 기본 이메일(joshua92y@gmail.com) — 대표 메일 contact@joshuatech.dev 와 다름(사용자 결정 B 2026-09-07: GitHub 기본 이메일을 바꾸기 전까지 유지).
    2026-09-07 기본값 회전 사고(환경변수 없는 셸의 apply 가 include 이메일을 T011 값에서 기본값으로 조용히 바꿈)로 기본값을 제거했다 —
    tests/infra/tofu.tests.ps1 cf-vars-1 이 default 부재를 원문으로 검사한다.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.operator_email))
    error_message = "operator_email must be a single e-mail address."
  }
}

# ---- 기존 자원 import 게이트(비어 있으면 import 블록이 생성되지 않는다 — import.tf) ----

variable "traefik_dns_record_id" {
  description = <<-EOT
    v1 A 레코드 traefik.joshuatech.dev 의 Cloudflare 레코드 id. 첫 apply 에서만 필요하다(같은 이름을 새로 만들면 충돌하므로
    import 후 값만 노드 A reserved IP로 교체). 운영자 조회 명령(토큰은 env 로만):
      curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        "https://api.cloudflare.com/client/v4/zones/<zone_id>/dns_records?name=traefik.joshuatech.dev&type=A" | jq -r '.result[].id'
    import 가 끝난 뒤(state 에 들어간 뒤)에는 다시 비워 두어도 된다 — import 블록은 no-op 이다.
  EOT
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[0-9a-f]{32}$|^$", var.traefik_dns_record_id))
    error_message = "traefik_dns_record_id must be a 32-char lowercase hex Cloudflare id, or empty to skip the import."
  }
}

variable "waf_managed_ruleset_id" {
  description = <<-EOT
    존의 http_request_firewall_managed 단계 entrypoint ruleset id(존재할 때만). Cloudflare Free Managed Ruleset 이
    대시보드에서 이미 배포돼 entrypoint 가 있으면 새 생성이 API 오류("already exists")를 내므로 import 한다. 조회:
      curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
        "https://api.cloudflare.com/client/v4/zones/<zone_id>/rulesets" | jq -r '.result[] | select(.phase=="http_request_firewall_managed") | .id'
    결과가 비면(entrypoint 없음) 이 변수를 비워 두고 apply 하면 새로 만들어진다(state 고정이 목적이며 규칙 내용은 같다).
  EOT
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[0-9a-f]{32}$|^$", var.waf_managed_ruleset_id))
    error_message = "waf_managed_ruleset_id must be a 32-char lowercase hex Cloudflare ruleset id, or empty to skip the import."
  }
}

# ---- 아직 apply 하면 안 되는 자원의 게이트(기본 false) ----

variable "enable_workers_domain_preview" {
  description = "T093 에서 true: Workers 커스텀 도메인 preview.joshuatech.dev → joshuatech-web-preview. Worker 가 먼저 존재해야 한다."
  type        = bool
  default     = false
}

variable "enable_workers_domain_apex" {
  description = "T094(apex 컷오버·import) 에서 true: Workers 커스텀 도메인 joshuatech.dev → joshuatech-web. v1 apex CNAME 을 걷어낸 뒤에만."
  type        = bool
  default     = false
}

variable "enable_r2_custom_domain" {
  description = "US8 에서 true: R2 커스텀 도메인 cdn.joshuatech.dev → 새 버킷. 지금은 v1 버킷 joshtech 이 같은 도메인을 쓰고 있어 충돌한다."
  type        = bool
  default     = false
}

# ---- VD-3 (T011 실측) ----

variable "ratelimit_use_host_condition" {
  description = <<-EOT
    VD-3: Free 요금제 Rate Limiting 표현식에 host 조건을 쓸 수 있는지의 실측 스위치.
    true = 옵션 A(경로 규칙 + joshuatech.dev/api/* 확대), false = 옵션 B(경로만: /api/auth/* 또는 /if/flow/*).
    VD-3 실측 2026-09-03: Free 플랜에서 host 조건 수락 → 옵션 A 확정(옵션 B 폴백은 -var=ratelimit_use_host_condition=false).
  EOT
  type        = bool
  default     = true
}

# ---- R2 ----

variable "r2_public_bucket_name" {
  description = "공개 자산 R2 버킷 이름. 설계 문서의 jt-public 은 이름 예외 규칙(jt-* → joshuatech-*)에 따라 joshuatech-public 으로 읽는다."
  type        = string
  default     = "joshuatech-public"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.r2_public_bucket_name))
    error_message = "r2_public_bucket_name must be 3-63 chars of lowercase letters, digits, and hyphens."
  }
}
