# Architecture Memory — JoshuaTech v2

> 정본: `specs/003-platform-foundation/spec.md` §Design, `specs/003-platform-foundation/contracts/`, `specs/003-platform-foundation/plan.md`. 이 문서는 그 요약이며, RAM·비용 수치는 예산/추정값이다 — **실측치는 US7 뒤 갱신(T118)**.

## 토폴로지

```
브라우저 ─HTTPS─▶ Cloudflare(DNS·proxied·Access·WAF)
                    ├─ 정적 자산(무료) ─▶ Workers: Next.js OpenNext lean(프리렌더 + BFF Route Handlers)
                    └─ 443(NSG: Cloudflare IP만, AOP mTLS) ─▶ 노드 A Traefik ─▶ Ingress(host) ─▶ pod / Authentik / Argo UI
BFF ─(RFC 8693 교환 + Access 서비스 토큰)─▶ <alias>-m2m-<env>.joshuatech.dev
```

| 노드 | role | shape | 구성요소 | RAM 추정/예산(실측치는 US7 뒤 갱신 — T118) |
|---|---|---|---|---|
| A | `platform` | 2 OCPU/13 GB | K3s server · Traefik · cert-manager · Argo CD · Vault+ESO · Strimzi Kafka · Authentik · OpenFGA · Alloy · cloudflared · Reloader · system-upgrade-controller · 앱 pod+워커(dev·prod, affinity 선호) | ≈ 8.6 / 9 GiB |
| B | `data` | 2 OCPU/13 GB | K3s agent · CNPG `pg-main` · Dragonfly(dev·prod) · cloudflared · cert-manager · CNPG 오퍼레이터(+ 앱 스필오버) | ≈ 3.6 / 8 GiB — SP-3 자리(ES·Kibana·ECK ≈ 3 GiB)는 전부 노드 B |

- 배치 원칙: StatefulSet은 `nodeSelector` 고정(Kafka → A: Postgres I/O와 분리), 앱 Deployment는 A 선호, CPU limit 없음, 오버레이 `flannel-backend: wireguard-native`.
- 환경: dev + prod 상시 — 앱 pod만 복제, 플랫폼 공유(D15; `dev.` 토픽·`dev_` DB·Vault `kv/dev`·OpenFGA store 2).
- 백업 경로: `platform-backup.timer`(노드 A, K3s SQLite + Vault Raft → age → `jt-backup-platform`) · CNPG barman-cloud → `jt-backup`.
- 결정: 런타임 트랙 `docs/decisions/0003-runtime-track.md` · 웹 `docs/decisions/0004-web-framework.md` · 검색(SP-3) `docs/decisions/0009-search.md`.

### 네임스페이스 (14개 · PSA enforce 레벨)

`specs/003-platform-foundation/contracts/network-policy.md` §네임스페이스 표의 요약:

| PSA | 네임스페이스 | privileged 사유 |
|---|---|---|
| `restricted` | `argocd` · `vault` · `external-secrets` · `identity`(authentik·openfga) · `jt-dev` · `jt-prod` · `cloudflared` · `reloader` | — |
| `baseline` | `cert-manager` · `cnpg-system` · `data`(pg-main·kafka·dragonfly) | — |
| `privileged` | `kube-system`(K3s 번들 traefik·coredns·metrics-server) · `monitoring`(alloy hostPath `/var/log`·node-exporter hostNetwork) · `system-upgrade`(hostPID·hostIPC·hostNetwork·`chroot /host`) | 표에 사유 기재 필수 |

- `observability`라는 이름은 쓰지 않는다(→ `monitoring`). AppProject: `platform`·`dev`·`prod`(gitops에는 `tests` 포함 4개 선언).
- NetworkPolicy: `kube-system` 제외 13 ns에 공통 5종(default-deny 포함), 조건부 2종(`deny-imds`는 `kube-system` 전용, `allow-imds`는 `vault` 전용). 허용 매트릭스에 없는 트래픽은 차단이 정상 — 정본과 외부 egress 규칙 형식은 위 계약 문서.

## 경계

- **pod**: pod 8개(`.specify/memory/product.md` §Pod 목록)는 DB를 공유하지 않고 API·이벤트로만 통신한다. 브라우저의 유일한 게이트웨이는 BFF(Workers)다.
- **DB**: CNPG 클러스터 1개(`pg-main`) + pod별 database/role — owner role(`bypassrls`, 마이그레이션·시드 전용) / app role(NOBYPASSRLS). dev는 `dev_` 접두. 테이블 등급 A(테넌트 범위 `TenantModel` + FORCE RLS + `SET LOCAL`) / 등급 B(pod 전역 허용 목록 `tenant`·`tenant_membership`·`outbox`·`session_revocation_log`). 테넌트 식별자는 어디서나 UUID(slug는 `Tenant.slug` 컬럼에만). — `docs/decisions/0007-data-ownership-and-tenancy.md`
- **신원·세션**: Authentik 단일 IdP, provider별 audience, RFC 8693 교환(기본 impersonation + Access `common_name` 식별 — VD-1), 세션 정본 = Authentik + BFF refresh 쿠키. 즉시 폐기의 정본은 DB `SessionRevocationLog`이고 Dragonfly 거부 목록은 파생 캐시다. 멤버십 정본은 identity-admin `TenantMembership`(Authentik 그룹·attribute·FGA 튜플은 파생). OpenFGA는 교차 컨텍스트, Cloudflare Access 이중. — `docs/decisions/0006-identity-and-authz.md`
- **이벤트**: Kafka KRaft(Strimzi, 단일 노드). 토픽 `<pod>.<entity>.<event>`(dev는 `dev.` 접두)은 접두 pod만 발행하고, 발행은 자기 DB `outbox` + 앱 내 폴링 릴레이 경유(CloudEvents JSON + `packages/events` JSON Schema, 파티션 키 `tenantid`, 파티션 3, DLQ `<pod>.dlq`). — `docs/decisions/0008-event-backbone.md`

## 계약

정본은 `specs/003-platform-foundation/contracts/` 아래 8종:

| 파일 | 요약 |
|---|---|
| `bff-api.md` | Workers의 유일한 서버 코드. 브라우저 → BFF만; Worker/환경 표(prod·preview·로컬), 세션 쿠키, 토큰 교환·pod 호출(3 s 타임아웃), RFC 9457 오류, `x-request-id` |
| `identity-admin-api.md` | SP-1 pod API — m2m 호스트 경로 허용 목록, admin 호스트(`FORCE_SCRIPT_NAME`), 웹훅·JWKS는 svc DNS 전용, django-common 인증 미들웨어 순서 |
| `events.md` | 토픽 규약 · CloudEvents 1.0 봉투 · outbox 릴레이 · DLQ · 보존 7일 |
| `gitops-repo.md` | platform-gitops 구조(app-of-apps, 컴포넌트 19) · 시크릿은 ExternalSecret 참조만 · dev 자동 digest bump · prod PR 승격 — `docs/decisions/0002-deployment-principles.md` |
| `pod-template.md` | copier `templates/django-pod` 생성물 계약 — `packages/django-common` 의존, 헬스 3종, kustomize base(securityContext·requests·Reloader) — `docs/decisions/0005-backend-framework-policy.md` |
| `hostnames-and-access.md` | 호스트 규약(`<alias>-m2m-<env>.joshuatech.dev` · `admin.` 경로 접두) · Access 앱/AUD · AOP mTLS · 에이전트/tester/CI 자격 |
| `network-policy.md` | 네임스페이스 14 · PSA · default-deny · 허용 매트릭스(표에 없으면 차단) · hostNetwork 예외 |
| `denylist.md` | Dragonfly 거부 목록 키 스키마(`revoked:sub:{sub}`·`revoked:sid:{sid}`, TTL 330 s) · 조회/쓰기 규약 · ACL |

## 운영 원칙

- **관측**: 모든 pod가 structlog JSON(`request_id`·`tenant_id`·`trace_id`, 민감 헤더 제거) + OTLP 트레이스(샘플링 0.1)를 Alloy(`monitoring`) → Grafana Cloud(메트릭·Loki·Tempo)로 보낸다. Sentry는 Django·web 클라이언트(PII 마스킹), BFF는 Workers observability JSON 로그 + `x-request-id`·`traceparent` 전파. 대시보드 3 · 알림 규칙 13(전부 `runbook_url`) — 규칙 이름·조건의 정의 정본은 `specs/003-platform-foundation/plan.md` §Observability & Rollback. 업그레이드 창(일요일 03:00–05:00 KST)은 Grafana mute timing.
- **롤백**: 앱·플랫폼 = gitops `git revert` → sync · 웹 = `wrangler rollback` · DB = CNPG PITR(클러스터 전체, 재해 복구 전용; 단일 DB는 side Cluster PITR → `pg_dump` → 복원) · K3s = 버전 핀 재설치 + 백업 번들 복원(SQLite 데이터스토어 — `--cluster-reset` 실행 금지) · Vault = Raft 스냅샷 restore(같은 KMS 키 필수) · 인프라 = `tofu plan` destroy 0(`prevent_destroy`). 요약 표는 `specs/003-platform-foundation/quickstart.md`, 비가역 변경 표·절차는 런북 8종(`docs/runbooks/`).
- **시크릿**: Vault(Raft, 노드 A) + OCI KMS auto-unseal + ESO(ClusterSecretStore 5) — gitops에는 ExternalSecret 참조만, 값 0개(SC-006). Workers 시크릿은 `wrangler secret put`으로 Workers Secrets에만. CI(GitHub Actions)에는 클러스터·OCI 자격이 없다. — `docs/decisions/0010-secrets.md`
- **보존**: 정본은 `specs/003-platform-foundation/spec.md` FR-018·FR-019·§Assumptions(보존값) — 변경 시 이 표 갱신.

| 대상 | 보존 |
|---|---|
| Authentik events | 90일 |
| Grafana Cloud(로그·메트릭·트레이스) | 14일 |
| Sentry | 30일 |
| `SessionRevocationLog` | `expires_at` + 30일(일 1회 purge) |
| Kafka 토픽 | 7일(원천은 각 pod DB `outbox`) |
| 백업 — CNPG(`jt-backup`, 매일 02:00 KST + WAL) | 30일 |
| 백업 — K3s 번들(`jt-backup-platform/k3s/`, 매일 02:30 KST) | 7일 |
| 백업 — Vault Raft(`jt-backup-platform/vault/`, 매일) | 30일 |
| 버킷 versioning 이전 버전 | lifecycle 60일 삭제(VD-6 — 첫 만료 관찰) |
