# 2차 approval 리뷰 지적사항 팩트체크 (2026-09-01)

사용자 요청: "Authentik 공식 문서 기준으로 delegation/OBO는 2026.8+에서 제공된다는데, 모든 지적사항을 공식 문서로 다시 체크해서 보고." 검증자 13(항목 그룹 10 + Authentik 독립 검증 3, workflow `wf_ceb4eb63-d3f`) + 컨트롤러 직접 대조(문서 4쪽·소스 6파일). 인용은 공식 문서·릴리스 노트·저장소 소스만.

**집계**: 42개 주장 중 확인 32 · 부분 확인 8 · **반박 2**. 2차 리뷰의 HIGH 8묶음(R26–R33)은 전부 성립하며, 반박된 2건은 MEDIUM 세부 항목이다.

## 1. Authentik delegation (R26) — 독립 검증 3/3 동일 결론

| 질문 | 답 | 근거 |
|---|---|---|
| OBO/delegation이 2026.8+ OSS 기능인가 | **예** (사용자 인용 정확) | oauth2 provider 문서: "authentik supports both impersonation and delegation … available in authentik 2026.8 and later." Enterprise 배지 없음. |
| BFF의 client-credentials 서비스 계정 토큰을 `actor_token`으로 쓸 수 있는가 | **아니오** | token_exchange 문서: "the actor token must identify an authentik Actor. Ordinary users and non-Actor service accounts cannot be used as actors." 소스 `authentik/providers/oauth2/token/token_exchange.py:170` — JWT actor 검증 뒤 `Actor.objects.filter(pk=…)`가 비면 `invalid_grant`(`actor_not_controlled`). `ak-<provider>-client_credentials`는 `Actor` 행이 아님. |
| OSS에서 Actor를 만들 수 있는가 | **지원 경로 없음** | `Actor.for_user`(core)는 테스트에서만 호출. 운영 경로는 `authentik/enterprise/agents/`의 `Agent.create_for_user`뿐이며 API(`POST /api/v3/agents/agents/`)는 `EnterpriseRequiredMixin` → "Enterprise is required". `Actor`는 serializer가 없어 blueprint/API 노출 불가. 2026.8 릴리스 노트 Enterprise 목록에 "Agent accounts". 유일한 비공식 우회 = `ak shell`에서 `Actor.for_user(None, …)` — 미문서·미지원. |
| `act.sub`가 `web-bff`가 되는가 | **아니오** | `id_token.act = {"sub": _resolve_sub(provider, actor)}` — 대상 provider의 Subject mode(기본 hashed user id). username 모드여도 Actor username은 자동 생성(`<parent>-agent-<id>`). |

**결론**: 2차 트렌드 리뷰어의 판정은 정확했고, 사용자 인용 문장도 정확하다 — 두 문장이 양립한다("delegation은 OSS이나 Actor 생성 수단이 OSS에 없다"). **R26 유지**: SP-1은 impersonation 교환 + Access 서비스 토큰 `common_name`으로 호출자 식별. 보강 2건: (a) `audience` 없이 교환하면 발급 토큰 `azp` = web-bff provider의 client_id이므로 `iss`+`azp`로도 호출자 판별 가능 — 단 `audience` 지정과 양립 불가하므로 설계서에 명시; (b) Enterprise 도입 시 Agent 계정은 parent user에 묶이므로 "전 사용자를 대행하는 BFF actor"는 parentless Actor가 필요 — 조건부 경로로 ADR 0006에 기록.

## 2. 항목별 판정

| ID | 주장(요약) | 판정 | 결정에 미치는 영향 |
|---|---|---|---|
| C1 | Workers는 캐시보다 먼저 실행; 존 Cache Rule은 Worker(커스텀 도메인 = origin) 응답에 무효 | 확인 | R32 유지 — Cache Rule 삭제, "HTML은 edge 서빙 유지" 문구 제거 |
| C2 | Free 한도 초과 = 429/1027, 자산 요청은 "free and unlimited" | 확인 | R32 유지 — 프리렌더 HTML 자산화 task 승격 근거 확보. 단 `run_worker_first`에 `/ko` 등을 넣지 말 것 |
| C3 | Workers Caching 활성 시 자산 요청도 과금 | 확인 | wrangler `[cache]` 비활성 유지, 런북·ADR 0004에 한 줄 |
| C4 | Workers Logs Free 200k events/일·3일 | 확인 | 주간 검사는 GraphQL·Notifications에 의존, 요청당 이벤트 ≤ 1–2 |
| R1 | Free Rate Limiting: 규칙 1·10 s·IP·필드 Path/Verified Bot만 | 확인 | R32 유지 — 표현식 `/api/auth/*`·`/if/flow/*`; security N11의 host 조건안은 폐기; action은 block |
| R2 | Free Managed Ruleset + Cache Rules 10개 | 확인 | Managed Ruleset은 기존 배포를 IaC로 선언 |
| R3 | Cache Everything이 Set-Cookie 응답도 캐시 | **부분** | 헤더는 제거되고 본문만 캐시 — "쿠키가 남에게 간다"는 틀림. Cache Rule 삭제로 실효; `[lang]` Set-Cookie 금지 규칙은 위생 규칙으로만 |
| D1 | Dragonfly aclfile은 키 패턴 불가 | **반박** | 문서 문장은 2023-11 이후 갱신 안 된 잔재; v1.14(ACL keys, PR #2273)·v1.22(pub/sub, PR #3574)에서 지원, v1.40.1 `acl_family.cc` 로더가 `USER <name> ON >pw %R~revoked:* ~<pod>:* +@all` 형식 로드. **R31 변경**: entrypoint `ACL SETUSER` 래퍼 불필요 → `--aclfile`(Secret) 유지, T051에 `ACL LIST`에 `%R~revoked:*` 존재 단언 |
| D2 | 런타임 ACL이 `%R~`·`%W~`·카테고리 지원 | 확인 | `<pod>: %R~revoked:* ~<pod>:* +@all` 유효, `DEL`은 write라 NOPERM |
| D3 | 키 패턴·명령 집합은 독립(짝지어지지 않음) | 확인 | 현 FR-020 규칙은 결함 — `%R~`로 확정; selector 대안(Dragonfly 미지원)·사용자 2개 분리안은 삭제 |
| D4 | 스냅샷 자동 적재로 센티널 복원 | **부분** | 정상 종료는 종료 시 스냅샷 저장 → 유실 창은 비정상 종료(OOM/SIGKILL/NOSAVE)만. R31의 "센티널 폐지 + 30 s 무조건 재적용"은 유지, T066/T085 시나리오는 SIGKILL로 유발, `terminationGracePeriodSeconds` 명시 |
| K1 | `--cluster-reset`은 embedded etcd 전용 | 확인 | R34 유지 + "SQLite 구성에서 실행하면 etcd로 비가역 전환" 금지 문구 |
| K2 | SQLite 복원 절차 + `server/tls` 필요 | **부분** | 절차는 맞으나 근거 정정: 부트스트랩 데이터는 SQLite에도 저장되며 문제는 "디스크가 더 새로우면 Fatal". `server/tls/` 번들 포함은 타당(또는 복원 전 tls·cred 삭제 → 재생성). `.backup` 단일 파일이면 wal/shm 불필요하되 복원 시 잔재 `-wal`/`-shm` 제거 |
| K3 | wireguard-native = UDP 51820, 모듈 필요 | 확인 | FR-005 정정, T014 모듈 확인(노드 A·B 모두) |
| K4 | secretbox는 v1.33.0+ | **부분** | v1.30.12/1.31.8/1.32.4/1.33.0+k3s1 이상 — 설계 영향 없음 |
| K5 | SUC Plan Job = hostPID·hostIPC·hostNetwork·chroot | 확인 | 하드코딩(비활성화 불가). hostNetwork 예외표 등재, DNS는 ClusterFirstWithHostNet |
| N1 | NetworkPolicy는 allow-only; `deny-imds` ipBlock 규칙이 egress 전부 허용 | 확인 | R28 유지 — `deny-imds`는 kube-system 전용, 나머지는 외부 egress 규칙마다 `except`+`ports` |
| N2 | ClusterRole `view`에 nodes·CRD·metrics 없음 | **부분** | `top nodes` 차단 원인은 core `nodes` 부재(K3s는 `nodes.metrics.k8s.io`를 view에 집계). `agent-view-extra`에 core `nodes`·CRD·`appprojects` 필수; 오퍼레이터 CR은 집계 라벨 여부 개별 확인 |
| N3 | LimitRange `default.cpu`가 CPU limit 주입 | 확인 | R37 유지 + `max.cpu`도 넣지 말 것(defaulting이 max를 default로 복사); 단언은 실제 pod spec |
| N4 | webhook 포트 cert-manager 10250·ESO 10250·CNPG 9443; Argo 8082–8084 | 확인 | R28 행 정확; "차트 기본값 기준" 각주 + T033 lint |
| P1 | CNPG `<cluster>-ca`에 `ca.key` 포함 | 확인 | R27 유지 — `ca.crt`만 미러 |
| P2 | 기본 pg_hba가 임의 role의 cert 인증 허용 | **부분** | 틀림 — 기본은 `host all all all scram-sha-256`; cert는 `streaming_replica`·pooler 고정 행만. 위험은 서버 인증서 위조(verify-full 무력화) + `streaming_replica` 인증서 위조(복제) — 심각도·시정안 유지, 근거 문구 교체 |
| P3 | DatabaseRole은 passwordSecret 1개, role은 클러스터 전역 | 확인 | R29 유지 — dev role 4개 |
| P4 | Database CRD로 owner + CONNECT 제한 | **부분** | owner는 CRD, `REVOKE/GRANT CONNECT`는 CRD 밖 → migrate Job 첫 단계(멱등 SQL) 또는 SQL Job으로 실행 주체 명시(T054) |
| E1 | ClusterSecretStore `conditions.namespaces`·`serviceAccountRef` | 확인 | R27 유지; apiVersion `external-secrets.io/v1`, SA ref에 namespace 필수, audience `vault` |
| E2 | kubernetes provider `remoteNamespace` + RBAC | **부분** | RBAC은 `secrets get/list/watch` + `selfsubjectrulesreviews create`; store 1개 + 대상 ns 3개 ExternalSecret |
| E3 | Vault K8s role audience 불일치 거부; `kubectl create token --audience` | 확인 | R35 유지 (`--audience vault`) |
| E4 | `token_ttl`/`token_max_ttl`, 기본 max 32일 | 확인 | R37 유지 — role마다 1h/4h, 단언은 발급 토큰 `ttl` |
| A1 | 로그인 SPA가 `/api/v3/*`를 브라우저에서 호출 | 확인 | R33 유지 — `auth-admin`은 `/if/admin/*`만 |
| A2 | `AUTHENTIK_POSTGRESQL__SSLMODE/SSLROOTCERT`, `CONN_OPTIONS` 폐기 | 확인 | 유지("2026.5부터 폐기", 기본 verify-ca → verify-full 명시) |
| A3 | Subject mode 기본 = 해시 | 확인 | R26 유지; `AUTH_ACTOR_SUB` 남기면 provider `sub_mode` 명시 |
| A4 | Reputation·`failed_attempts_before_cancel`·`show_matched_user` | 확인 | 스테이지 배치 정확히(identification/password); 잠금 통제로 기술하지 말 것 |
| G1 | `gh pr merge --auto`는 repo "Allow auto-merge" 필요 | 확인 | R35 유지 + required check 등록 명시 |
| G2 | public repo Free에서 Environments·환경 시크릿 가능 | 확인 | R35 유지 (private 전환 시 무시 전제) |
| G3 | `Workers Scripts:Edit`는 계정 단위, IP 제한·TTL 가능 | 확인 | R35 유지 — PR 트리거 제한이 실질 통제 |
| G4 | Reloader v1.4.21 / chart 2.2.16; namespaceSelector·reloadStrategy | 확인 | R37 유지; `namespaceSelector`는 `watchGlobally: true`에서만 → ClusterRole은 남음. ClusterRole 제거는 scoped 모드(`watchGlobally: false` + ns 목록, 인스턴스 1개 가능) — T046에서 확정 |
| G5 | pytest-django 분류자 6.1 미선언 | 확인 | R37 유지 (`filterwarnings` 범위 한정) |
| G6 | `serverExternalPackages: ['jose']`는 Workers에서 실행 실패 | **반박** | OpenNext 공식 howtos/workerd: `jose`는 workerd 조건부 export 패키지로 **`serverExternalPackages`에 넣으라고 명시**, esbuild 단계에서 서버 번들에 포함. **R37에서 "T091 설정 제거" 항목 삭제**, T091 유지 + 근거 주석 |
| O1 | versioning 버킷 삭제 = delete marker; lifecycle이 previous versions 대상 가능 | 확인 | R34 유지 + Object Storage 서비스에 `OBJECT_VERSION_DELETE` IAM 정책 필요(T010·T006) |
| O2 | `oci os`는 API 키/세션/인스턴스 프린시펄만 | 확인 | R30 유지 — `svc-verify`(세션 토큰 1h) |
| O3 | Grafana Free 10k/50 GB/50 GB/14일/3 users; k8s-monitoring 최신 4.5.0 | 확인 | 4.5.0 직접 핀 + Renovate; Viewer 서비스 계정이 사용자 수 소모 여부 확인 |
| O4 | Raft 스냅샷은 seal 래핑 → 동일 KMS 키 필요; recovery key로 unseal 불가 | 확인 | R34 유지; `snapshot inspect`는 "무결성 검증"으로 표기 |

## 3. 결정표 R26–R38에 반영할 정정

1. **R31**: aclfile 유지(`%R~` 포함 파일을 Secret으로) — entrypoint 래퍼 삭제; selector·사용자 2개 대안 삭제; 유실 창은 비정상 종료로 한정, 시나리오는 SIGKILL.
2. **R37**: "`serverExternalPackages: ['jose']` 제거" 항목 삭제 → T091 유지 + 근거 주석.
3. **R27**: CA 미러 RBAC = `secrets get/list/watch` + `selfsubjectrulesreviews create`; apiVersion `v1`; Vault role audience `vault`.
4. **R28**: `agent-view-extra`에 core `nodes`·`customresourcedefinitions`·`appprojects` 필수(`nodes.metrics.k8s.io`는 이미 view); webhook 포트 각주.
5. **R29**: `REVOKE CONNECT … FROM PUBLIC; GRANT CONNECT … TO <db>_app`은 migrate Job 첫 단계(멱등)로 실행 주체 명시.
6. **R34**: K3s 복원 근거 정정(부트스트랩 데이터 "디스크가 더 새로우면 Fatal"), 잔재 wal/shm 제거, `--cluster-reset` 금지 문구; previous-object-versions lifecycle에 `OBJECT_VERSION_DELETE` 정책; `snapshot inspect` = 무결성.
7. **R32**: security N11의 host 조건안 폐기(Free 불가); `run_worker_first`에 `/ko` 등 금지; `[cache]` 비활성 명시.
8. **R26 보강**: `azp` 기반 호출자 판별 옵션(audience 미지정 시)과 Enterprise 조건부 경로를 ADR 0006에.
9. **R37 문구**: LimitRange에 `max.cpu`도 금지; P2 근거 교체(서버 인증서·streaming_replica 위조); K4 버전 문구; Reloader scoped 모드 결정.
