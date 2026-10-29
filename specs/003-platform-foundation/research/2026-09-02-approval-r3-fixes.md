# Approval 3차 리뷰 시정 목록 (2026-09-02)

입력: 3차 리뷰(analyze H1–H4·M1–M12·L1–L9 + 경계 6개 신규 지적). 성격: **전부 이미 확정된 결정(R26–R38·VD)의 문구 전파 누락·실행 주체 공백** — 새 설계 결정 없음, task 재번호 없음. 리뷰어 권고안을 그대로 채택했다.

## HIGH (승인 전 필수)

| # | 시정 | 반영 위치 |
|---|---|---|
| X1 | 검증 Job 3종 ns = 전부 `jt-dev`(dev 자격은 `vault-dev`에서만 나옴 — 계약이 정본) | spec FR-044 |
| X2 | m2m Ingress 경로 목록 = `/api`·`/health`·`/session`·`/sessions`·`/tenants` 5개(`/healthz`·`/ready`·`/webhooks` 제거) | tasks T072·T075 (spec·계약·T066은 이미 정본) |
| X3 | 13번째 알림 = **`MetricsAbsent`**, absent 대상 = 합집합 6종(`outbox_oldest_pending_seconds`·`platform_backup_last_success_timestamp`·`vault_core_unsealed`·`cnpg_collector_last_available_backup_timestamp`·`certmanager_certificate_expiration_timestamp_seconds`·`argocd_app_info`), 각 30m. 정의 정본 = plan §Observability 표, spec·tasks는 이름+참조 | spec FR-040·FR-048·US7 AC1, plan 표, T096·T099 |
| X4 | 공유 DB CONNECT 실행 주체: `platform/cnpg-databases/`에 **PostSync SQL Job**(자격 `kv/platform/db/{authentik,openfga}/owner`, store `vault-platform`, 멱등 `REVOKE CONNECT … FROM PUBLIC; GRANT CONNECT … TO <db>_owner`). FR-016 공유 role 표기 = `authentik_owner`·`openfga_owner`(owner만), DatabaseRole 수 = 6(pod 4 + 공유 owner 2)으로 통일 | spec FR-016·US3 IT, tasks T054·T050, data-model §7 |

## MEDIUM (같은 회차)

| # | 시정 | 반영 위치 |
|---|---|---|
| X5 | Vault role `e2e-reader`(bound `kube-system/agent-view`, `kv/data/platform/authentik/e2e` read, ttl 1h)를 T044 role 목록에 추가(합계 6: eso 4 + vault-backup + e2e-reader) | T044 |
| X6 | T077 e2e 경로 → `kv/platform/authentik/e2e`(role `e2e-reader`) | T077 |
| X7 | `JT_CI_APP_PRIVATE_KEY` = Environment `production` 시크릿으로 확정; publish-pod bump job과 promote job에 `environment: production` 명시; T093 환경 시크릿 목록에 추가 | T003·T074·T093 |
| X8 | T075 `identity-admin-env`의 US4 이후 키(`kv/{env}/authentik/*`·`openfga/*`): US6 시점에 운영자가 플레이스홀더 값을 `vault kv put`(T043 스크립트 절차에 한 줄) → US4(T081·T082)에서 실값 교체(Reloader 재적재) | T075(+T043·T081 한 줄) |
| X9 | tester의 m2m Service Auth 통과: Access 서비스 토큰 `tester-m2m` 신설(dev·prod m2m 앱 include, 보관 `kv/platform/access/tester-m2m`, 회전 매트릭스 T084) + `tester-k8s` 토큰(F6)도 같은 방식 — T011 `access.tf`에 두 토큰 생성 | T011·T076·T079·T084·T085, spec FR-044, hostnames §에이전트 자격 |
| X10 | `platform/policies/tests/`는 **전용 AppProject `tests`**(source = gitops, destination `jt-dev`만, cluster 리소스 금지) — "platform 프로젝트 destination에 Application 한정 추가"는 Argo에서 불가 | contracts/hostnames(문구 삭제)·gitops-repo(AppProject 표)·T041 |
| X11 | T044 Vault helm values에 securityContext 4항목(`runAsNonRoot`·`allowPrivilegeEscalation false`·`capabilities.drop [ALL]`·`seccompProfile RuntimeDefault`; IPC_LOCK 불필요 주석) | T044 |
| X12 | v1 SSH 키 파기 게이트 참조 T102/T104 → **T103/T105** | T005 §0 ⑦·T014 |
| X13 | `allow-apiserver-webhook` 적용 수 = 4(vault 8200 포함) | T031·plan A21 |
| X14 | T050 교차 검증 재구성: 실접속 단언은 dev 방향만(`dev_identity_admin_app` → `identity_admin`·`authentik` 거부), prod role 방향은 카탈로그 `SELECT has_database_privilege('identity_admin_app','dev_identity_admin'|'authentik','CONNECT')` = false | T050·spec US3 IT/AC1·AC5 |
| X15 | dev Authentik 자격 확정: dev 전용 서비스 계정 **`identity-admin-ro`**(사용자 read만) = `kv/dev/authentik/identity-admin.api_token`의 주체; dev의 Authentik revoke·reconcile 쓰기 호출은 설정 플래그로 비활성(로그만); 폐기 3경로 E2E(T085)·SC-003은 **prod 체인에서만** 측정, dev 로그아웃 검증은 denylist 401·로컬 세션 삭제까지 | T081·T073·T085, spec FR-024 한 줄, data-model §9, identity-admin-api §주기 작업 |
| X16 | VD-2 실측 절차 성립화: 기본 = Cache Rule 미생성(spec FR-004 선언 목록에서 제거, FR-023 "기본 = 미생성"), T093 실측 = "임시 Cache Rule 1회 apply → `curl -I /ko` 10회 → HIT면 유지(A)/아니면 제거(B)" | spec FR-004·FR-023·Edge Case, T093 |
| X17 | FGA 모델 정본 = spec FR-025 2관계(`owner`·`member`); data-model §10의 `admin` 관계·`TenantMembership.role`의 `admin`은 "SP-2 예약" 주석으로 강등 | data-model §2·§10 |
| X18 | T029는 spec을 편집하지 않는다: spec §8 표의 ADR 링크를 지금 확정 경로(`docs/decisions/000N-<slug>.md`, T018–T026의 고정 슬러그)로 완성하고, T029는 docs/README·specs/README 갱신·링크 유효 확인만 | spec §8·T029 |

## LOW (같은 회차에 흡수)

- X19 FR-047 lifecycle 문구 = 접두별(k3s/ 7일·vault/ 30일 + previous 60일); plan Storage 요약 동일. `jt-backup`에도 `previous-object-versions` DELETE 60일 규칙 + T006 단언 확장(op R3-4) — T010.
- X20 Workers 커스텀 도메인 = apex·preview 2개, `www`는 301 redirect rule(도메인 아님) 명시 — FR-004·T094·hostnames DNS 표.
- X21 터널 `k8s` 대상 표기 6443으로 통일 — T011.
- X22 US5 AC4 "운영자가 연 같은 repo PR만" — spec.
- X23 T117에 ram-report를 report.md에 병합 명시.
- X24 알림 정의 5중 중복 해소: 정본 = plan §Observability 표 한 곳, spec FR-040·US7 AC1·T096·T099는 "이름 13개 + plan 표 참조"로 축약(X3와 함께).
- X25 FR-020·US3 AC4에 `sample-pod`(dev 전용 검사 계정) 1줄 + prod aclfile에는 미포함(T057·denylist.md) — security R3-7.
- X26 T098 scrape 선언에 web 9100 추가; T098 VD-7 옵션 A = "4.5.1 존재해도 4.5.0 유지, 승급은 Renovate PR"(trends 5).
- X27 T066의 m2m 404 단언은 Ingress 층위라 앱 pytest로 불가 → T066에서 제거하고 T076(E2E)에서 검증(sc L10) — X2와 함께.
- X28 OpenFGA env 격리 없음(단일 인스턴스·전역 preshared)을 ADR 0006(T022)·T111 경계 항목·report 수용 위험에 기재, SP-2 결정 항목(`openfga-dev` 분리) 등재 — security R3-1.
- X29 T042·T052에 `nodeSelector role=data`(cert-manager·CNPG operator·barman plugin), T097에 배치 단언 — op R3-3.
- X30 Grafana 수집량 80% 상시 알림은 미채택 — 사유(월간 점검 + T096 E2E 단언으로 갈음)를 plan §관측에 1줄 — op R3-6.
- X31 identity ns 메일: SP-1은 recovery/enrollment 흐름 없음 → 메일 발송 없음 명시(매트릭스 postmark 각주 제거) — k8s F8 — T081·network-policy.
- X32 T033 lint ⑦: `apps/**`의 `remoteRef.key`가 `(dev|prod)/(access|web)/` 접두면 FAIL — k8s F10 — gitops-repo §검사에도.
- X33 T079에 호출 간격 ≥ 200 ms 1줄(plan A32와 정합) — trends 4.
- X34 T085·T079의 BFF 경유 단언은 "T094 이후 재실행(2단계)" 주석, SC-002 체인 단언은 T095로 이관 명시 — analyze M1.
- X35 T031에 단계별 SKIP 조건(후속 phase 산출물 단언은 해당 phase까지 SKIP, T102에서 전체 재실행) + 양방향 프로브 실행 주체(assert Job 가능분 + 운영자 수동 1회) 명시 — analyze M2·M3.
- X36 표기 통일: 파티션 키 `tenantid`(봉투)·필드 `partition_key`(data-model §4·§6·Key Entities OutboxEvent), dragonfly `admin` 행 store 열 "—(운영자 직접)", T072 템플릿 beat 자리는 outbox dead purge로(identity-admin 고유 beat는 T073) — tenant F5.
- X37 T096의 `active_series < 8000`·40 GB 임계를 FR-040에 1줄 근거로 명시(볼륨 가드) — sc 미반영 1건.

## 반영 규칙
1차·2차 결정표의 규칙 유지: 새 task ID·재번호 금지, VD 형식 보존, 한국어 프로즈·영어 식별자, UTF-8/LF, 편집자는 자기 파일만.
