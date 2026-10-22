# plan/apply는 운영자만 실행한다 — 에이전트는 어떤 프로바이더 자격 증명도 갖지 않으며
# apply를 절대 실행하지 않는다(에이전트 OCI 조회는 읽기 전용 svc-verify 세션 프로파일뿐).

provider "oci" {
  region              = "ap-chuncheon-1"
  auth                = var.oci_auth
  config_file_profile = var.oci_config_profile
}

# 운영자 기본 = API 키 DEFAULT 프로파일(세션 1시간 만료 없이 부트스트랩 진행).
# 세션 토큰 방식이 필요하면 -var 'oci_auth=SecurityToken'으로 선택한다.
variable "oci_auth" {
  type    = string
  default = "APIKey"

  validation {
    condition     = contains(["APIKey", "SecurityToken"], var.oci_auth)
    error_message = "oci_auth must be \"APIKey\" or \"SecurityToken\"."
  }
}

# 운영자 OCI CLI 설정 프로파일 이름 — APIKey 기본값은 DEFAULT(API 키 프로파일),
# SecurityToken 사용 시 `oci session authenticate` 결과 프로파일을 -var로 지정한다.
variable "oci_config_profile" {
  type    = string
  default = "DEFAULT"
}

# 루트 컴파트먼트(= 테넌시 OCID). OCID는 비밀이 아님 — 공개 저장소 수용, 사용자 제공 값(2026-09-03).
variable "compartment_ocid" {
  type    = string
  default = "ocid1.tenancy.oc1..aaaaaaaat7iglpjj2kugdmf7an2v4uimrxr3ggtwo4txkbwptfjh5apddzpa"
}

# Cloudflare API 토큰은 환경 변수 CLOUDFLARE_API_TOKEN으로만 전달한다
# (운영자의 joshuatech-tofu-deploy 토큰, 패스워드 매니저 보관).
# 토큰을 코드·tfvars에 적어 커밋하는 것은 금지다.
provider "cloudflare" {}
