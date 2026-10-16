# IAM (T010): 서비스 사용자 그룹 2 + 정책 2, joshuatech-verify 정책, Object Storage 서비스 주체 정책(VD-6), 동적 그룹 joshuatech-node-a + 정책.
# 전부 루트 컴파트먼트(= 테넌시) 범위 — 문장은 `in tenancy` + `target.bucket.name` 조건으로 버킷 단위까지 좁힌다.
# 이름 예외(사용자 결정 2026-09-03, docs/runbooks/bootstrap.md §0): jt-* 표기는 joshuatech-*로 읽고, 새로 만드는 이름도 같은 패턴이다.
#
# 버킷별 분리 원칙(한 주체가 남의 버킷을 넘보는 문장 0 — 각 문장의 target.bucket.name을 grep으로 자가 점검):
#   svc-tfstate   (그룹 joshuatech-tfstate)   → joshuatech-tfstate 만: manage objects + read buckets(S3 호환 HeadBucket)
#   svc-s3-backup (그룹 joshuatech-s3-backup) → joshuatech-backup  만: manage objects + read buckets(barman-cloud의 head_bucket)
#   svc-verify    (그룹 joshuatech-verify — 콘솔 생성, 여기서 미관리) → backup·backup-platform read objects(목록 + 검증용 다운로드)
#                 + read usage-reports·usage-budgets·instance-family, manage 0
#   노드 A 인스턴스(동적 그룹 joshuatech-node-a) → joshuatech-backup-platform OBJECT_CREATE·OBJECT_INSPECT 만 + kms.tf 키 use
#   Object Storage 서비스 주체 → backup·backup-platform 두 버킷(lifecycle 실행 주체라 설계상 두 버킷을 가진다 — tasks T010 문면)
#
# 서비스 사용자 3명(svc-tfstate·svc-s3-backup·svc-verify)은 기본 identity domain에 콘솔로 생성됐다(§0). 그룹 가입은 이 스택이 하지 않는다:
# 운영자 plan(2026-09-03)에서 legacy IAM API(data.oci_identity_users)가 Default 도메인 사용자를 빈 목록으로 돌려줘 membership 선언을 뺐다.
# → 그룹 가입은 apply 후 운영자 콘솔 단계다: Identity → Domains → Default → Groups → Add user
#     svc-tfstate   → joshuatech-tfstate
#     svc-s3-backup → joshuatech-s3-backup
# 그룹 joshuatech-verify는 이미 svc-verify가 가입된 콘솔 그룹이라 이름으로만 참조한다.

locals {
  region                = "ap-chuncheon-1"
  objectstorage_service = "objectstorage-${local.region}"
  verify_group_name     = "joshuatech-verify"

  # lifecycle 대상 버킷(서비스 주체 정책의 범위) — tfstate는 포함하지 않는다(규칙 없음).
  lifecycle_buckets = [local.bucket_names.backup_platform, local.bucket_names.backup]
}

# ---- 그룹 2 (가입은 apply 후 운영자 콘솔 단계 — 파일 머리 주석) ----

# 가입 대상: svc-tfstate (콘솔: Identity → Domains → Default → Groups → joshuatech-tfstate → Add user)
resource "oci_identity_group" "tfstate" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-tfstate"
  description    = "svc-tfstate: OpenTofu remote state (S3 compat) on bucket joshuatech-tfstate only"
}

# 가입 대상: svc-s3-backup (콘솔: Identity → Domains → Default → Groups → joshuatech-s3-backup → Add user)
resource "oci_identity_group" "s3_backup" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-s3-backup"
  description    = "svc-s3-backup: CNPG barman (S3 compat) on bucket joshuatech-backup only"
}

# ---- 정책: svc-tfstate → joshuatech-tfstate 만 ----

resource "oci_identity_policy" "tfstate" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-tfstate-policy"
  description    = "group joshuatech-tfstate (svc-tfstate): objects + bucket read on joshuatech-tfstate only"
  statements = [
    "allow group ${oci_identity_group.tfstate.name} to manage objects in tenancy where target.bucket.name = '${local.bucket_names.tfstate}'",
    "allow group ${oci_identity_group.tfstate.name} to read buckets in tenancy where target.bucket.name = '${local.bucket_names.tfstate}'",
  ]
}

# ---- 정책: svc-s3-backup → joshuatech-backup 만 ----

resource "oci_identity_policy" "s3_backup" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-s3-backup-policy"
  description    = "group joshuatech-s3-backup (svc-s3-backup): objects + bucket read on joshuatech-backup only"
  statements = [
    "allow group ${oci_identity_group.s3_backup.name} to manage objects in tenancy where target.bucket.name = '${local.bucket_names.backup}'",
    "allow group ${oci_identity_group.s3_backup.name} to read buckets in tenancy where target.bucket.name = '${local.bucket_names.backup}'",
  ]
}

# ---- 정책: svc-verify(그룹 joshuatech-verify) — 읽기 전용, manage 0 ----
# read objects = OBJECT_INSPECT(목록·버전 목록) + OBJECT_READ(검증용 다운로드) — 사양 문면(bootstrap §0 표 ③ "inspect/read objects",
# read ⊇ inspect; 컨트롤러 정정 2026-09-03). VD-6 관찰(`oci --profile svc-verify os object list … --all`)은 INSPECT 쪽으로 충분하다.

resource "oci_identity_policy" "verify" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-verify-policy"
  description    = "group joshuatech-verify (svc-verify): read-only — object listing on the two backup buckets, usage/budget/instance reads; no manage"
  statements = [
    "allow group ${local.verify_group_name} to read objects in tenancy where any {target.bucket.name = '${local.bucket_names.backup}', target.bucket.name = '${local.bucket_names.backup_platform}'}",
    "allow group ${local.verify_group_name} to read usage-reports in tenancy",
    "allow group ${local.verify_group_name} to read usage-budgets in tenancy",
    "allow group ${local.verify_group_name} to read instance-family in tenancy",
  ]
}

# ---- 정책: Object Storage 서비스 주체 — lifecycle 실행 권한 (VD-6) ----
# 가정(VD-6 기본값): versioning 버킷에서 lifecycle 규칙이 이전 버전을 지우려면 Object Storage 서비스 주체에 OBJECT_VERSION_DELETE가
# 필요하다. 그래서 규칙(storage.tf)과 정책을 함께 선언한다. 문장은 두 쌍으로 나눈다:
#   (a) manage object-family 에서 OBJECT_VERSION_DELETE 를 뺀 나머지 — objects 대상 규칙(k3s/·vault/ DELETE)의 실행 권한
#   (b) OBJECT_VERSION_DELETE 만 — previous-object-versions 규칙의 실행 권한(가정의 실체)
# (a)+(b) = tasks 문면의 `manage object-family … where any {두 버킷}`과 같은 권한 집합이지만, (b)만 떼어 낼 수 있어서 관찰이 깨끗하다.
# 관찰 계획(apply 후 60일, 사용자 동석): `oci --profile svc-verify os object list --bucket-name <버킷> --all`로 두 버킷의 이전 버전 수가 줄면
#   옵션 A(규칙만으로 삭제 — (b)가 없어도 되는지는 (b)를 뗀 뒤 다음 만료로 재확인), (b)를 뗐을 때만 멈추면 옵션 B(정책 필요)로 확정하고
#   결과를 report.md에 적는다. 확정 전까지 (b)는 유지한다.
# 문장 형태는 중첩 없는 `all {target.bucket.name = '…', request.permission …}` 평면형만 쓴다(버킷당 1문장; 정책 엔진 문법 위험 최소화).

resource "oci_identity_policy" "objectstorage_lifecycle" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-objectstorage-lifecycle-policy"
  description    = "Object Storage service principal: lifecycle execution on joshuatech-backup-platform + joshuatech-backup (OBJECT_VERSION_DELETE split out for VD-6)"
  statements = concat(
    [for b in local.lifecycle_buckets :
      "allow service ${local.objectstorage_service} to manage object-family in tenancy where all {target.bucket.name = '${b}', request.permission != 'OBJECT_VERSION_DELETE'}"
    ],
    [for b in local.lifecycle_buckets :
      "allow service ${local.objectstorage_service} to manage object-family in tenancy where all {target.bucket.name = '${b}', request.permission = 'OBJECT_VERSION_DELETE'}"
    ],
  )
}

# ---- 동적 그룹: 노드 A 인스턴스만 (노드 B 제외) ----
# matching_rule은 노드 A 인스턴스 OCID 1개만 담는다 — instance.compartment.id 같은 광역 규칙은 노드 B까지 끌어들이므로 금지.

resource "oci_identity_dynamic_group" "node_a" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-node-a"
  description    = "node A instance only (joshtech_api_1st) — platform backups to joshuatech-backup-platform + KMS key use"
  matching_rule  = "instance.id = '${oci_core_instance.node_a.id}'"
}

# ---- 정책: 동적 그룹 joshuatech-node-a ----
#   - kms.tf 키 하나만 use(target.key.id) — 키 OCID는 첫 plan에서 (known after apply)라 문장 전체가 apply 시점에 확정된다.
#   - joshuatech-backup-platform 에 OBJECT_CREATE(업로드)·OBJECT_INSPECT(목록)만 — 덮어쓰기·삭제·다운로드 없음(백업 스크립트는 새 이름으로만 쓴다).

resource "oci_identity_policy" "node_a" {
  compartment_id = var.compartment_ocid
  name           = "joshuatech-node-a-policy"
  description    = "dynamic-group joshuatech-node-a: use the platform KMS key; OBJECT_CREATE + OBJECT_INSPECT on joshuatech-backup-platform only"
  statements = [
    "allow dynamic-group ${oci_identity_dynamic_group.node_a.name} to use keys in tenancy where target.key.id = '${oci_kms_key.platform.id}'",
    "allow dynamic-group ${oci_identity_dynamic_group.node_a.name} to manage objects in tenancy where all {target.bucket.name = '${local.bucket_names.backup_platform}', request.permission = 'OBJECT_CREATE'}",
    "allow dynamic-group ${oci_identity_dynamic_group.node_a.name} to manage objects in tenancy where all {target.bucket.name = '${local.bucket_names.backup_platform}', request.permission = 'OBJECT_INSPECT'}",
  ]
}
