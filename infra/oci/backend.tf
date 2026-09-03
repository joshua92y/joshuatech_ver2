# 원격 상태: OCI Object Storage S3 호환 API (버킷 jt-tfstate).
#
# 운영자 전용 부트스트랩 절차 — 에이전트는 절대 실행하지 않는다:
#   1. 버킷 생성(1회):
#      oci os bucket create --name jt-tfstate --versioning Enabled --public-access-type NoPublicAccess
#   2. 상태 마이그레이션 init — 환경 변수와 함께 실행:
#      AWS_REQUEST_CHECKSUM_CALCULATION=when_required tofu -chdir=infra/oci init -migrate-state
#      (AWS SDK 기본 CRC 체크섬을 OCI S3 호환 API가 거부하므로 when_required가 필수다)
#
# profile "jt-tfstate": 운영자가 svc-tfstate 사용자의 Customer Secret Key를
# 로컬 ~/.aws/credentials 의 [jt-tfstate] 프로파일로 보관한다.
# 자격 증명은 어떤 형태로도 저장소에 들어오지 않는다.

terraform {
  backend "s3" {
    bucket  = "jt-tfstate"
    key     = "oci/terraform.tfstate"
    region  = "ap-chuncheon-1"
    profile = "jt-tfstate"

    # axvjykgvo2m1 = 테넌시 Object Storage 네임스페이스(운영자가 `oci os ns get`으로 확인).
    endpoints = {
      s3 = "https://axvjykgvo2m1.compat.objectstorage.ap-chuncheon-1.oraclecloud.com"
    }

    # OCI S3 호환 엔드포인트는 AWS가 아니므로 AWS 전용 검증·메타데이터 경로를 전부 끈다.
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true

    # OCI S3 호환 API는 조건부 쓰기(conditional write) 기반 lockfile을 지원하지 않는다.
    use_lockfile = false
  }
}
