# infra/cloudflare — Cloudflare 존(joshuatech.dev)·Zero Trust·Workers 도메인·R2·터널 선언 스택(T011).
# provider 핀은 cloudflare 하나뿐이다(OCI 리소스는 infra/oci 스택이 소유). `.terraform.lock.hcl`을 커밋한다.

terraform {
  required_version = ">= 1.12.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.24.0"
    }
  }
}
