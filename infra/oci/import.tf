# 기존 OCI 리소스 import 블록 (T008).
# OCID 출처: 운영자 확인 목록 2026-09-03 (region ap-chuncheon-1, 루트 컴파트먼트 = 테넌시).
# 이 import 블록들은 커밋에 유지한다(T008 태스크 라인) — 상태가 이미 import된 뒤에는 no-op이며,
# 어떤 리소스가 어디서 왔는지의 기록으로 남긴다.

# ---- 인스턴스 2 ----

import {
  to = oci_core_instance.node_a
  id = "ocid1.instance.oc1.ap-chuncheon-1.an4w4ljr46wbjmqcqnacrfilhr4yro4dizvsplrti2lcyt4cnf43fhbiqpga"
}

import {
  to = oci_core_instance.node_b
  id = "ocid1.instance.oc1.ap-chuncheon-1.an4w4ljr46wbjmqcplrmdldp75dpapkzvlrfx6oxpm4jluti3vpyn7rpersa"
}

# ---- VCN ----

import {
  to = oci_core_vcn.main
  id = "ocid1.vcn.oc1.ap-chuncheon-1.amaaaaaa46wbjmqa35bcqpwy2v6vqchvka2k2mqepsyhx6thigvoy2ypsqxq"
}

# ---- 서브넷 2 ----

import {
  to = oci_core_subnet.api
  id = "ocid1.subnet.oc1.ap-chuncheon-1.aaaaaaaagayma3z5m3oyk2edvc3zjmgbprpclzlhzoa5wz55ivxo3yxniuoq"
}

import {
  to = oci_core_subnet.cache
  id = "ocid1.subnet.oc1.ap-chuncheon-1.aaaaaaaaxkkgijjdr6lo36n7vrxenehyux5rqvqqa3temr2vnc5teve6qnza"
}

# ---- 인터넷 게이트웨이 ----

import {
  to = oci_core_internet_gateway.main
  id = "ocid1.internetgateway.oc1.ap-chuncheon-1.aaaaaaaa3qsv26tid54ixssjqzejtxhw7bzvhsc2bwthebom64tc4lqsjinq"
}

# ---- 라우트 테이블 3 (기본 라우트 테이블 포함) ----

import {
  to = oci_core_route_table.api
  id = "ocid1.routetable.oc1.ap-chuncheon-1.aaaaaaaa4mo26bspb4wx7nzqa4w5pru6whjdo372hazj7mds7sys7vsw3era"
}

import {
  to = oci_core_route_table.cache
  id = "ocid1.routetable.oc1.ap-chuncheon-1.aaaaaaaannq2j3njgcdsoqgk2tdkooh27gp6jxzclitd54zx2vdja26wki5a"
}

import {
  to = oci_core_default_route_table.default
  id = "ocid1.routetable.oc1.ap-chuncheon-1.aaaaaaaaguukxrmq4673ixkrcnwym6eajccw624embmupmp7rqfg2st55bjq"
}

# ---- 보안 리스트 3 (기본 보안 리스트 포함) ----

import {
  to = oci_core_security_list.api
  id = "ocid1.securitylist.oc1.ap-chuncheon-1.aaaaaaaaiaqgylhen24wawnkrzedk4hunjhjnyj63cnl33zhwd5qkx5biaoa"
}

import {
  to = oci_core_security_list.cache
  id = "ocid1.securitylist.oc1.ap-chuncheon-1.aaaaaaaapp25i3o25qmlyu3gi64tnqs6nwseeg2ktqqdyni2yoo6ve5fvi4q"
}

import {
  to = oci_core_default_security_list.default
  id = "ocid1.securitylist.oc1.ap-chuncheon-1.aaaaaaaagsb7msdfxi6luoifig6zmlqpfcvc2xe46fzo32uvbeidba6uwwha"
}

# ---- T010: Object Storage 버킷 joshuatech-tfstate (콘솔 생성 2026-09-03 — 생성이 아니라 import) ----
# id 형식 n/{namespace}/b/{bucket}; 네임스페이스 axvjykgvo2m1(backend.tf와 동일). 리소스 선언은 storage.tf.

import {
  to = oci_objectstorage_bucket.tfstate
  id = "n/axvjykgvo2m1/b/joshuatech-tfstate"
}
