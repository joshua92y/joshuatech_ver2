# 원격 상태: OCI Object Storage S3 호환 API (버킷 joshuatech-tfstate) — infra/oci 와 같은 버킷, 키만 다르다.
# 이름 예외(사용자 결정 2026-09-03): 설계 문서의 jt-tfstate 표기는 실명 joshuatech-tfstate 로 읽는다(§0 bootstrap.md).
#
# 운영자 전용 절차 — 에이전트는 절대 실행하지 않는다(에이전트는 `init -backend=false` 까지만):
#   (Git Bash)   AWS_REQUEST_CHECKSUM_CALCULATION=when_required tofu -chdir=infra/cloudflare init
#   (PowerShell) $env:AWS_REQUEST_CHECKSUM_CALCULATION='when_required'; tofu -chdir=infra/cloudflare init
#   (AWS SDK 기본 CRC 체크섬을 OCI S3 호환 API가 거부하므로 when_required 가 필수다 — infra/oci/backend.tf 와 동일)
#
# profile "joshuatech-tfstate": 운영자가 svc-tfstate 사용자의 Customer Secret Key를
# 로컬 ~/.aws/credentials 의 [joshuatech-tfstate] 프로파일로 보관한다.
# 자격 증명은 어떤 형태로도 저장소에 들어오지 않는다.

terraform {
  backend "s3" {
    bucket  = "joshuatech-tfstate"
    key     = "cloudflare/terraform.tfstate"
    region  = "ap-chuncheon-1"
    profile = "joshuatech-tfstate"

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
