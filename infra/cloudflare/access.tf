# Cloudflare Access(Zero Trust 팀 joshua-tech) — contracts/hostnames-and-access.md §호스트 표·§Access 정책 규칙.
# 구성: GitHub IdP 1 · 서비스 토큰 4 · 재사용 정책 5 · 앱 10. 모든 앱·정책이 session_duration 을 명시한다
# (provider 5.24 에서 필수; tests/infra/tofu.tests.ps1 access-1 이 원문으로 검사한다).
#
# 서비스 토큰 secret 취급: 출력은 sensitive(outputs.tf). Vault 투입 전까지 운영자 로컬 보관 —
#   web-bff-dev/prod → kv/{env}/access/web-bff → Workers Secrets 에만, tester-m2m/tester-k8s → kv/platform/access/*.
#   회전 매트릭스는 T084.

# ---- IdP: GitHub(운영자 OAuth App; 값은 TF_VAR_* 로만) ----

resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = local.account_id
  name       = "GitHub"
  type       = "github"

  config = {
    client_id     = var.github_oauth_client_id
    client_secret = var.github_oauth_client_secret
  }
}

# ---- 서비스 토큰 4(1년, 만료 60일 전 회전 — 런북 secret-rotation.md) ----

resource "cloudflare_zero_trust_access_service_token" "tokens" {
  for_each = toset(["web-bff-dev", "web-bff-prod", "tester-m2m", "tester-k8s"])

  account_id = local.account_id
  name       = each.key
  duration   = "8760h"
}

# ---- 재사용 정책(account 수준) ----

# Service Auth(dev): BFF preview/local 의 web-bff-dev + tester 의 tester-m2m.
resource "cloudflare_zero_trust_access_policy" "svc_auth_dev" {
  account_id       = local.account_id
  name             = "svc-auth-dev"
  decision         = "non_identity"
  session_duration = "24h"

  include = [
    { service_token = { token_id = cloudflare_zero_trust_access_service_token.tokens["web-bff-dev"].id } },
    { service_token = { token_id = cloudflare_zero_trust_access_service_token.tokens["tester-m2m"].id } },
  ]
}

# Service Auth(prod): prod Worker 의 web-bff-prod + tester 의 tester-m2m.
resource "cloudflare_zero_trust_access_policy" "svc_auth_prod" {
  account_id       = local.account_id
  name             = "svc-auth-prod"
  decision         = "non_identity"
  session_duration = "24h"

  include = [
    { service_token = { token_id = cloudflare_zero_trust_access_service_token.tokens["web-bff-prod"].id } },
    { service_token = { token_id = cloudflare_zero_trust_access_service_token.tokens["tester-m2m"].id } },
  ]
}

# Service Auth(k8s): tester 의 tester-k8s 만 — k8s 앱에서 cloudflared access tcp 로 6443 접속.
resource "cloudflare_zero_trust_access_policy" "svc_auth_k8s" {
  account_id       = local.account_id
  name             = "svc-auth-k8s"
  decision         = "non_identity"
  session_duration = "24h"

  include = [
    { service_token = { token_id = cloudflare_zero_trust_access_service_token.tokens["tester-k8s"].id } },
  ]
}

# 운영자 로그인: allow, include = 운영자 이메일, require = GitHub IdP 로그인(login_method). 기본 24h.
# include 이메일 = var.operator_email(기본값 없음) — 이 값이 GitHub 기본 이메일과 다르면 운영자 잠금; 변경 plan 에 email diff 가 보이면 반드시 멈출 것.
resource "cloudflare_zero_trust_access_policy" "admin_github" {
  account_id       = local.account_id
  name             = "admin-github"
  decision         = "allow"
  session_duration = "24h"

  include = [
    { email = { email = var.operator_email } },
  ]
  require = [
    { login_method = { id = cloudflare_zero_trust_access_identity_provider.github.id } },
  ]
}

# 같은 규칙의 1h 판 — ssh 앱 전용(계약: "ssh 앱만 1h"; 정책 session_duration 이 앱 값을 덮으므로 별도 정책이 필요).
# include 이메일 = var.operator_email(기본값 없음) — 이 값이 GitHub 기본 이메일과 다르면 운영자 잠금; 변경 plan 에 email diff 가 보이면 반드시 멈출 것.
resource "cloudflare_zero_trust_access_policy" "admin_github_ssh" {
  account_id       = local.account_id
  name             = "admin-github-ssh"
  decision         = "allow"
  session_duration = "1h"

  include = [
    { email = { email = var.operator_email } },
  ]
  require = [
    { login_method = { id = cloudflare_zero_trust_access_identity_provider.github.id } },
  ]
}

# ---- 앱: GitHub IdP 단일 호스트 5(argo·vault·traefik·admin·preview) ----

locals {
  github_apps = {
    argo    = "argo.${var.zone_name}"
    vault   = "vault.${var.zone_name}"
    traefik = "traefik.${var.zone_name}"
    admin   = "admin.${var.zone_name}" # Django admin(경로별 pod) — 뒤에서 Authentik forward-auth 로 이중
    preview = "preview.${var.zone_name}"
  }
}

resource "cloudflare_zero_trust_access_application" "github" {
  for_each = local.github_apps

  account_id                = local.account_id
  name                      = each.key
  type                      = "self_hosted"
  domain                    = each.value
  session_duration          = "24h"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id]
  auto_redirect_to_identity = true
  app_launcher_visible      = false

  policies = [
    { id = cloudflare_zero_trust_access_policy.admin_github.id, precedence = 1 },
  ]
}

# ---- 앱: auth-admin — auth.joshuatech.dev 의 /if/admin/* 경로만(Authentik 관리 SPA) ----
# /api/v3/* · /application/o/* · /if/flow/* · /if/user/* · /.well-known/* 은 공개(로그인 SPA·사용자 UI 가 브라우저에서 직접 호출).
# 관리 API 접두만 골라 보호하는 방안은 SP-2 검토. destinations 에 접두 자체와 하위 와일드카드를 모두 적어 매칭 해석 차이를 없앤다.

resource "cloudflare_zero_trust_access_application" "auth_admin" {
  account_id                = local.account_id
  name                      = "auth-admin"
  type                      = "self_hosted"
  domain                    = "auth.${var.zone_name}/if/admin"
  session_duration          = "24h"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id]
  auto_redirect_to_identity = true
  app_launcher_visible      = false

  destinations = [
    { type = "public", uri = "auth.${var.zone_name}/if/admin" },
    { type = "public", uri = "auth.${var.zone_name}/if/admin/*" },
  ]

  policies = [
    { id = cloudflare_zero_trust_access_policy.admin_github.id, precedence = 1 },
  ]
}

# ---- 앱: identity-m2m-prod / identity-m2m-dev — Service Auth 전용(브라우저 접근 불가, 401) ----
# AUD → pod ConfigMap ACCESS_AUD_M2M(outputs.tf access_app_aud).

resource "cloudflare_zero_trust_access_application" "identity_m2m" {
  for_each = {
    prod = cloudflare_zero_trust_access_policy.svc_auth_prod.id
    dev  = cloudflare_zero_trust_access_policy.svc_auth_dev.id
  }

  account_id                = local.account_id
  name                      = "identity-m2m-${each.key}"
  type                      = "self_hosted"
  domain                    = "identity-m2m-${each.key}.${var.zone_name}"
  session_duration          = "24h"
  service_auth_401_redirect = true
  app_launcher_visible      = false

  policies = [
    { id = each.value, precedence = 1 },
  ]
}

# ---- 앱: ssh — 터널 호스트 2(ssh-a·ssh-b), GitHub IdP, session 1h ----

resource "cloudflare_zero_trust_access_application" "ssh" {
  account_id                = local.account_id
  name                      = "ssh"
  type                      = "self_hosted"
  domain                    = "ssh-a.${var.zone_name}"
  session_duration          = "1h"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id]
  auto_redirect_to_identity = true
  app_launcher_visible      = false

  destinations = [
    { type = "public", uri = "ssh-a.${var.zone_name}" },
    { type = "public", uri = "ssh-b.${var.zone_name}" },
  ]

  policies = [
    { id = cloudflare_zero_trust_access_policy.admin_github_ssh.id, precedence = 1 },
  ]
}

# ---- 앱: k8s — 터널 → K3s 6443. 운영자(GitHub IdP) + tester-k8s 서비스 토큰(svc-auth-k8s) ----

resource "cloudflare_zero_trust_access_application" "k8s" {
  account_id                = local.account_id
  name                      = "k8s"
  type                      = "self_hosted"
  domain                    = "k8s.${var.zone_name}"
  session_duration          = "24h"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.github.id]
  auto_redirect_to_identity = true
  app_launcher_visible      = false

  policies = [
    { id = cloudflare_zero_trust_access_policy.admin_github.id, precedence = 1 },
    { id = cloudflare_zero_trust_access_policy.svc_auth_k8s.id, precedence = 2 },
  ]
}
