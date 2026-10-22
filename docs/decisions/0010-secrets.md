---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0010: 시크릿 — Vault Raft + OCI KMS auto-unseal + ESO

<!-- 근거: spec D13·§5(시크릿)·§7(리스크 표 — Vault unseal 실패)·Edge Cases(Vault 자동 unseal 실패·KMS 키 삭제)·FR-047, data-model §8(SecretPath — 경로 규약 정본), contracts/gitops-repo.md §ClusterSecretStore 5개·§이름·인증 규약, plan Complexity Tracking(HashiCorp Vault + ESO)·A16(SOFTWARE 키)·A19(버킷 분리)·A20(스냅샷·recovery 3/2), research R4(VAULT-D1·D2·D3·D4·D5·D7·D8·D10), tasks T043–T045, docs/runbooks/bootstrap.md §0 토큰 표 ⑥·§4 -->

## Context and Problem Statement

public 저장소 2개(D2)에 시크릿 0건이 L1 불변식이다(ADR 0002). 지켜야 할 비밀은 DB role·Kafka SCRAM·Dragonfly ACL·Authentik·OpenFGA·Cloudflare 토큰·관측 토큰 등 수십 경로(data-model §8)이고, gitops에는 참조만 두고 값은 별도 정본에서 와야 하며, 회전·감사가 가능해야 한다. 1인 운영이라 노드 재부팅 시 사람 개입 없이 복구되어야 한다 — 노드 A 장애의 복구 경로가 "재부팅 → Vault 자동 unseal → Argo 재동기화"다(spec Edge Cases).

동시에 시크릿 정본 자체가 새 단일 장애점이 된다: unseal 키 관리, dev가 prod 경로를 읽는 사고, 정본 유실(백업)까지 이 ADR이 함께 닫아야 한다.

## Considered Options

- **HashiCorp Vault Community 2.0.4 Raft(1 replica) + OCI KMS(SOFTWARE 키) auto-unseal + External Secrets Operator (채택)** — 중앙 정본·회전·감사·무인 unseal을 무료 자원 안에서
- Sealed Secrets — 가볍지만 회전·감사·중앙 정본이 없고 클러스터 봉인 키 백업이 단일 장애점이다(plan Complexity Tracking); 사용자가 Vault 운영 경험을 명시 요구
- SOPS + age — git에 암호문을 두는 방식이라 "gitops에는 참조만" 원칙(D13)과 충돌하고, 회전이 커밋 이력에 남는 수동 절차가 된다
- OpenBao — MPL fork이고 ocikms seal 문서도 동일하나, ESO·커뮤니티 생태계 호환과 학습 이전 가치로 Vault를 유지한다(research VAULT-D1; BSL 1.1은 자체 운영에 허용)
- 클러스터 내 unseal(Shamir 수동 / Transit seal) — Shamir는 재부팅마다 수동 개입이라 무인 복구 요구와 충돌하고, Transit은 별도 Vault 인스턴스가 필요하다(research VAULT-D4·D10)

## Decision Outcome

1. **Vault**: Community 2.0.4(vault-helm 0.34.1), `ha.raft` replicas 1(노드 A, local-path 5 Gi), injector/csi 비활성(ESO가 대체). seal `ocikms` — OCI KMS **AES-256 SOFTWARE 키**(HSM key-version 과금 회피 — plan A16)를 인스턴스 프린시펄(동적 그룹 + `use keys`·`target.key.id` 한정 정책)로 쓴다. 내부 리스너는 SP-1 평문(`tls_disable`), UI는 Traefik + Cloudflare Access 뒤다(research VAULT-D2·D3·D4).
2. **경로 규약(정본 data-model §8)**: kv v2 `kv/{scope}/{component}/{name}`, scope ∈ `platform`(환경 무관)·`dev`·`prod`. gitops에는 `ExternalSecret`(경로·키 매핑)만 커밋하고 값은 Vault CLI/UI로만 넣는다. Workers 쪽 비밀(`web-bff`·Access 서비스 토큰·세션 키)은 ESO 밖 — `wrangler secret put` 전용으로 pod에 배포되지 않는다.
3. **ESO**: `ClusterSecretStore` 5개 — `vault-platform`·`vault-dev`·`vault-prod`·`vault-data`(열거 경로만, env 와일드카드 금지)·`k8s-data-ca`(kubernetes provider, CA `ca.crt` 속성만 미러) — namespace 조건·SA·Vault role 표는 contracts/gitops-repo.md §ClusterSecretStore가 정본이다. 모든 K8s auth role은 `audiences: [vault]`·`token_ttl 1h`·`token_max_ttl 4h`, pod는 Vault를 직접 읽지 않는다(ESO Secret만). `refreshInterval 5m`, 회전 = Vault 값 교체 → ESO 반영 → Reloader 롤아웃.
4. **recovery key 3/2 — unseal 수단이 아니다**: auto-unseal에서 recovery key의 용도는 `generate-root`·rekey뿐이다. **KMS 일시 장애 = Vault sealed 대기**: ESO는 마지막 Secret을 유지해 기존 pod는 계속 돌고, 창 동안 pod 재시작을 금지하며, `VaultSealed` 알림이 간다. **KMS 키 삭제 = Raft 스냅샷 + 동일 키 없이는 복구 불능** → 키에 `prevent_destroy` + 삭제 유예 30일을 건다(spec Edge Cases).
5. **백업**: Raft 스냅샷 일 1회 — `platform-backup.sh`가 K8s auth role `vault-backup`(정책 = `sys/storage/raft/snapshot` read만)으로 `raft snapshot save` → age 암호화 → `jt-backup-platform/vault/`(보존 30일, 노드 A 인스턴스 프린시펄 업로드 — plan A19·A20). 스냅샷도 seal 래핑이라 복원에 같은 KMS 키가 필요하다 — 4의 `prevent_destroy`가 백업 유효성의 전제다.
6. **부트스트랩 순서(T043–T045, 런북 bootstrap §4)**: ① OpenTofu가 KMS 키·동적 그룹·버킷 → ② Vault helm(ocikms seal) → ③ `vault operator init -recovery-shares=3 -recovery-threshold=2`(사용자 입회, 출력은 즉시 오프라인 보관) → ④ root 토큰으로 kv v2 마운트·K8s auth·정책·role 6개(`eso-*` 4 + `vault-backup` + `e2e-reader`; `infra/vault/` OpenTofu로 코드화) → ⑤ ESO 설치 + store 5개 → 운영자 초기 kv 값 투입(root 토큰 사용) → ⑥ root 토큰 revoke(시드 완료 후 즉시 — 런북 §0 토큰 표 ⑥의 "부트스트랩 직후"; 이후 사람은 Authentik OIDC 단기 토큰만, 상시 토큰 없음). OIDC auth method는 US4(Authentik) 뒤에야 생기므로, 그 사이 Vault 변경이 필요하면 recovery key `generate-root`(break-glass)뿐이다. 감사 로그는 file(stdout) → Alloy/Loki.

운영 절차의 정본은 런북이다 — `docs/runbooks/vault-unseal.md`(T044 재작성: sealed 대기·`generate-root`·`raft snapshot restore -force`, 전부 워크스테이션 CLI)와 `secret-rotation.md`(회전 매트릭스·캘린더). 이 ADR은 결정과 불변식만 기록한다.

### Consequences

- 좋음: public 저장소 2개에 시크릿 0건이 구조로 보장되고(참조만 커밋), 재부팅이 무인 복구되며(auto-unseal), store·role이 scope별 최소권한이라 dev ExternalSecret이 prod 경로를 못 읽고, 회전·감사 경로가 처음부터 있다.
- 나쁨: Vault + ESO 상주 ≈ 0.5 GiB와 다단계 부트스트랩(수동 init 1회 포함)이 추가되고, OCI KMS 결합으로 클라우드 이식성이 낮아지며, 경로를 추가할 때마다 data-model §8 표·Vault 정책·ExternalSecret을 함께 고쳐야 한다(T044·T045).
- 위험 수용: KMS 장애 창에는 신규 pod 기동·시크릿 갱신이 안 된다(sealed 대기 — 의도된 fail-closed 방향). recovery key 3/2를 잃으면 root 재생성·rekey가 불능이라 오프라인 보관 절차로만 완화한다. Raft 1 replica는 노드 A 장애 도메인에 포함된다(수용 — spec Edge Cases).
