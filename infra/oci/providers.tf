# plan/apply는 운영자만 실행한다 — 에이전트는 어떤 프로바이더 자격 증명도 갖지 않으며
# apply를 절대 실행하지 않는다(에이전트 OCI 조회는 읽기 전용 svc-verify 세션 프로파일뿐).

provider "oci" {
  region              = "ap-chuncheon-1"
  auth                = "SecurityToken"
  config_file_profile = var.oci_config_profile
}

# 운영자 본인의 OCI CLI 세션 프로파일 이름(`oci session authenticate` 결과).
variable "oci_config_profile" {
  type    = string
  default = "DEFAULT"
}

# Cloudflare API 토큰은 환경 변수 CLOUDFLARE_API_TOKEN으로만 전달한다
# (운영자의 joshuatech-tofu-deploy 토큰, 패스워드 매니저 보관).
# 토큰을 코드·tfvars에 적어 커밋하는 것은 금지다.
provider "cloudflare" {}
