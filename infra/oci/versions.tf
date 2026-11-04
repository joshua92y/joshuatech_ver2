terraform {
  required_version = ">= 1.12.6"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 8.29.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.24.0"
    }
  }
}
