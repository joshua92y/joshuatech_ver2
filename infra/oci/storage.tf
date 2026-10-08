# Object Storage (T010): 버킷 3 + lifecycle 정책 2 + 네임스페이스 출력. 루트 컴파트먼트(= 테넌시), 네임스페이스 axvjykgvo2m1(data로 조회).
# 이름 예외(사용자 결정 2026-09-03, docs/runbooks/bootstrap.md §0): 설계 문서의 jt-tfstate·jt-backup·jt-backup-platform은
# 실명 joshuatech-tfstate·joshuatech-backup·joshuatech-backup-platform으로 읽는다. 아래 local.bucket_names가 실명의 단일 출처이며
# iam.tf의 정책 문장과 backend.tf의 bucket 값이 같은 이름을 쓴다.
#
#   joshuatech-tfstate          OpenTofu 원격 상태(backend.tf). 콘솔 생성 2026-09-03(versioning Enabled·NoPublicAccess) —
#                               생성이 아니라 import(import.tf T010 절). lifecycle 규칙 없음(상태 이력은 versioning이 보존).
#   joshuatech-backup           CNPG barman(WAL·베이스 백업, svc-s3-backup의 S3 호환 API). versioning +
#                               previous-object-versions DELETE 60일 — barman의 30일 보존 정리가 지운 베이스·WAL의 이전 버전 정리(op R3-4).
#   joshuatech-backup-platform  K3s 번들 + Vault Raft 스냅샷(노드 A 인스턴스 주체 → platform-backup.sh). versioning +
#                               objects DELETE k3s/ 7일·vault/ 30일 + previous-object-versions DELETE 60일(삭제 표식으로 남는 이전 버전 정리).
#
# 세 버킷 전부 access_type = NoPublicAccess(provider 인자명은 access_type — 설계 문서·tests/infra의 public_access_type 표기와 다르다).
# versioning 버킷에서 DELETE는 현재 버전을 이전 버전으로 돌리는 것(삭제 표식)이라 실제 용량 회수는 previous-object-versions 규칙의
# 몫이다 — 그 규칙이 정말 이전 버전을 지우는지(서비스 주체 정책이 필요한지)는 VD-6(apply 후 첫 만료 60일 관찰; iam.tf의
# Object Storage 서비스 주체 정책 주석)에서 확정한다.
# storage_tier·auto_tiering·object_events_enabled·태그는 선언하지 않는다(Optional+Computed — 라이브 값 그대로, import 버킷 diff 0 목표).

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_ocid
}

locals {
  bucket_names = {
    tfstate         = "joshuatech-tfstate"
    backup          = "joshuatech-backup"
    backup_platform = "joshuatech-backup-platform"
  }
}

# ---- joshuatech-tfstate (import — 콘솔 생성 버킷) ----

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = local.bucket_names.tfstate
  versioning     = "Enabled"
  access_type    = "NoPublicAccess"

  # 원격 상태의 집 — 파괴는 곧 상태 유실이다. 이 스택에서는 절대 삭제하지 않는다.
  lifecycle {
    prevent_destroy = true
  }
}

# ---- joshuatech-backup (CNPG barman) ----

resource "oci_objectstorage_bucket" "backup" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = local.bucket_names.backup
  versioning     = "Enabled"
  access_type    = "NoPublicAccess"

  # 백업 버킷 — 파괴 금지(객체가 있으면 API도 거부하지만 계획 단계에서 먼저 막는다).
  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_objectstorage_object_lifecycle_policy" "backup" {
  namespace = data.oci_objectstorage_namespace.ns.namespace
  bucket    = oci_objectstorage_bucket.backup.name

  # 이전 버전 정리 60일 — barman의 30일 보존 정리(현재 버전 삭제 → 삭제 표식)가 남긴 이전 버전을 만료시킨다(op R3-4).
  rules {
    name        = "previous-versions-delete-60d"
    action      = "DELETE"
    target      = "previous-object-versions"
    is_enabled  = true
    time_amount = 60
    time_unit   = "DAYS"
  }

  # lifecycle 실행 주체는 Object Storage 서비스다 — 서비스 주체 정책(iam.tf, VD-6)이 먼저 있어야 규칙이 동작한다.
  depends_on = [oci_identity_policy.objectstorage_lifecycle]
}

# ---- joshuatech-backup-platform (K3s 번들 + Vault Raft 스냅샷) ----

resource "oci_objectstorage_bucket" "backup_platform" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = local.bucket_names.backup_platform
  versioning     = "Enabled"
  access_type    = "NoPublicAccess"

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_objectstorage_object_lifecycle_policy" "backup_platform" {
  namespace = data.oci_objectstorage_namespace.ns.namespace
  bucket    = oci_objectstorage_bucket.backup_platform.name

  # K3s 번들(k3s/ 접두사) 7일 — 매일 만들어지는 번들은 일주일치면 충분하다(복구 절차는 최신 번들만 쓴다).
  rules {
    name        = "k3s-delete-7d"
    action      = "DELETE"
    target      = "objects"
    is_enabled  = true
    time_amount = 7
    time_unit   = "DAYS"
    object_name_filter {
      inclusion_prefixes = ["k3s/"]
    }
  }

  # Vault Raft 스냅샷(vault/ 접두사) 30일.
  rules {
    name        = "vault-delete-30d"
    action      = "DELETE"
    target      = "objects"
    is_enabled  = true
    time_amount = 30
    time_unit   = "DAYS"
    object_name_filter {
      inclusion_prefixes = ["vault/"]
    }
  }

  # 위 두 규칙이 남기는 삭제 표식(이전 버전) 정리 60일.
  rules {
    name        = "previous-versions-delete-60d"
    action      = "DELETE"
    target      = "previous-object-versions"
    is_enabled  = true
    time_amount = 60
    time_unit   = "DAYS"
  }

  depends_on = [oci_identity_policy.objectstorage_lifecycle]
}

# ---- 출력 ----

output "object_storage_namespace" {
  description = "테넌시 Object Storage 네임스페이스 — S3 호환 엔드포인트 호스트·`oci os` 명령의 -ns 값"
  value       = data.oci_objectstorage_namespace.ns.namespace
}
