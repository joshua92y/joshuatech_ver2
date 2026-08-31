# SP-1 브레인스토밍 결정 로그 (2026-08-27 ~ 28)

**상태**: 브레인스토밍 진행 중(라운드 5까지 완료). 이 파일은 spec.md 작성 전 결정 기록이며 SP-1 디렉터리가 생기면 `specs/003-<slug>/research/`로 옮긴다.
**참조**: `2026-08-27-sp1-decisions-and-tradeoffs.md`(트레이드오프·출처), 9-Pod 청사진 artifact(3fb9e0f3, 텍스트 사본 `artifact-9pod.txt`).

## 1. 사용자 결정 (1차 — 트레이드오프 표 이후)

| # | 결정 | 답 |
|---|---|---|
| D1 | v1 사이트 유지 여부 | **내려도 됨** |
| D2 | 저장소 공개 | **public** |
| D3 | 런타임 트랙 | **B1 K3s + GitOps** |
| D4 | 웹 호스팅 | **Workers static assets** |
| D5 | 웹 프레임워크 | **Next.js 16.3 + OpenNext** |
| D6 | API | **9-Pod 청사진 원칙**: 기본 Django, FastAPI는 수치 트리거 ADR 예외 |
| D7 | 주 DB | **Postgres on CNPG** |
| D8 | v2 초기 동적 범위 | **정적 + 문의·업로드·관리자 + 외부 사용자 로그인** |
| D9 | 인증 | **청사진**: Authentik 단일 IdP, provider별 audience, RFC 8693 token exchange |
| D10 | 멀티테넌트 경계 | **청사진**: tenant_id 클레임 + owner 컬럼, 교차 컨텍스트는 OpenFGA |
| D11 | 캐시·큐 | **Dragonfly 유지** |
| D12 | 배포 | **K3s + Argo CD** |

## 2. 브레인스토밍 라운드별 결정

### 라운드 1 — 범위·예산·D0
- SP-1 산출물: **문서 + 뼈대** (ADR, `.specify/memory/product·architecture.md`, `.claude/rules·agents`, 모노레포 뼈대, K3s + Argo CD root app + platform-gitops 부트스트랩; 앱 기능은 SP-2).
- 청사진 적용 범위: **원칙 + Authentik + OpenFGA 전부** (처음부터).
- 예산: 사용자 제안 "SSR/ISR 없이 Next.js BFF 라우트만 Worker" → 검토 결과 **$0 가능(조건부)**: OpenNext lean — 페이지 전부 프리렌더, Worker는 BFF Route Handler만, 서버 번들 gzip 예산(2.5 MiB) CI 검사, 초과 시 $5 탈출구 ADR 명시. (근거: Free 3 MiB 압축 한도, 최소 템플릿 ≈ 1.04 MiB gzip; 정적 export는 Request 읽는 Route Handler·proxy·cookies 불가)
- D0: **인스턴스 2대 전제** → 이후 답변에서 **2 OCPU/12 GB × 2 노드**(합계 4/24). 테넌시 유형 확인은 SP-1 첫 task.

### 라운드 2 — 웹 구조·노드·이벤트·DB
- 웹: **OpenNext lean + 번들 예산**(개발은 WSL).
- K3s 토폴로지: 2 노드 — 배치 추천 채택 대기 없이 진행(아래 §3).
- 이벤트 버스: **Kafka KRaft 단일 노드 사용**(사용자 확정). 노드 배치는 추천대로 노드 A.
- CNPG: **클러스터 1개(instances=1, PG 18) + pod별 database/owner role**, barman-cloud 플러그인 → OCI Object Storage.

### 라운드 3 — pod·인증·테넌트·관리자
- pod: identity-admin, portfolio-core, media까지 우선 + 도메인 브레인스토밍으로 추가 확인(→ 라운드 4·5).
- 로그인 수단: **소셜(GitHub·Google) + 이메일/비밀번호 + MFA**.
- 테넌트 격리: **앱 계층 + Postgres RLS 이중**(tenant_id NOT NULL, FORCE RLS, 요청 트랜잭션 내 SET LOCAL, Django 커넥션 래퍼, "다른 tenant_id로 0행" 테스트 필수).
- 관리자 보호: **Cloudflare Access(GitHub IdP) 앞단 + Authentik SSO(forward-auth/OIDC) 뒷단**, 공인 IP 없이 cloudflared 터널만.

### 라운드 4 — 사용자 행동·분석·검색·노트 정본
- 외부 사용자 기능: 댓글·반응·방명록, 뉴스레터·새 노트 알림 구독, AI 어시스턴트, 문의, 공유 — "기본 블로그 기능".
- 분석: **insights pod**(BFF→core POST PageViewed → outbox → Kafka → 집계; 개인정보 없음).
- 검색: **Elasticsearch + Kibana + Nori + FastAPI, ECK + Argo CD**(사용자 확정).
- 학습 노트: **정본 = git, DB는 파생 메타만**(CI가 main 머지 후 core 'notes sync' API 업서트 → NotePublished 이벤트).

### 라운드 5 — pod 확정·outbox·이벤트 스키마·ES
- pod 8개 확정 및 단계: **SP-2** identity-admin·portfolio-core·media·engagement(Django) / **SP-3** notification(FastAPI+taskiq, 구독 소유)·insights(Django, Kafka 소비)·search(FastAPI+ES) / **SP-4** assistant(FastAPI SSE/WS + pgvector). SP-1 뼈대는 8개 전부의 provider·DB·role·토픽 명명을 미리 잡는다.
- outbox 릴레이: **앱 내 폴링 릴레이**(SELECT … FOR UPDATE SKIP LOCKED → produce → 삭제; 공통 라이브러리 `packages/`).
- 이벤트: **CloudEvents JSON, 토픽 `<pod>.<entity>.<event>`, 스키마는 모노레포 JSON Schema + CI 호환성 검사**, tenant_id = 파티션 키.
- ES: **1노드(heap 1 GB) 노드 B + Kibana 노드 A, Basic 라이선스**, analysis-nori 커스텀 이미지, Kibana는 Access+SSO 뒤.

### 라운드 6 — 웹 세부
- 디자인 시스템: **Material Design 차용 + slot 반응형(데스크탑·태블릿·모바일) + 자체 토큰(계층 구조는 Once UI 차용) + 모든 컴포넌트 소스 소유**(라이브러리 의존 없음).
- MDX 파이프라인: **자체 로더 패키지 `packages/content`** — fs + gray-matter + next-mdx-remote/rsc(v1 뼈대) + zod 스키마(rules/content.md 계약 코드화) + 타입 + React.cache 1회 스캔 + draft 필터 + remark/rehype(헤딩 앵커·목차·읽기 시간·shiki); CI notes-sync 스크립트가 재사용, zod→JSON Schema로 Django 계약 도출. (v1 분석: 스키마 검증 없음·페이지당 3회 재스캔·콘텐츠가 src/app 안·edge 런타임에 fs)
- i18n: **ko 기본 + en·ja 라우트**(`app/[lang]`, 프리렌더, i18n 라이브러리는 서버 번들 제외). 콘텐츠 파일: **같은 폴더 접미사** `<slug>.mdx`(ko) / `<slug>.en.mdx` / `<slug>.ja.mdx`, 없는 언어는 ko 폴백 + 표시.
- 정본: **학습 노트·블로그 글·프로젝트 모두 git MDX**(`content/{study,blog,projects}`), DB(portfolio-core content 앱)는 slug 레지스트리 + 조회수·댓글 연결만. 테넌트 전환 시 DB 저자 모드 추가.
- 이미지: **R2 원본 → 커스텀 loader → Cloudflare Image Transformations**(Free 존 월 5,000 고유 변환 무료, 초과 시 오류·과금 없음, 같은 존 원본 = `cdn.joshuatech.dev`; 2026-07-08 문서). media pod 변형 생성은 불필요(원본 저장 + 메타만).

### 라운드 7 — 운영 (1차 답, 세부 확인 중)
- 시크릿: **자체 Vault pod 운영**(HashiCorp Vault vs OpenBao, unseal 방식, 주입 방식은 후속 질문).
- 관측: **Grafana Cloud Free + Alloy(메트릭·로그·트레이스) + Sentry SaaS Free(에러·성능)**. Sentry 서버 SDK는 Worker 번들 제외.
- 환경: **dev + prod 상시**(사용자 확정) → RAM 한계 안에서 dev 범위를 제한하는 방식은 후속 질문.
- 인그레스: 사용자 지시 "R:\home\linuxpc\egenauto-deploy\k3s 참조" → 기존 egenauto K3s 구성을 읽고 그 패턴을 따름(아래 §5에 기록 예정).

### 라운드 7b — 운영 세부 확정
- 인그레스: **egenauto 패턴 이식** — 번들 Traefik(ServiceLB, 노드 A) 80/443 공개 + OCI 보안 리스트 Cloudflare IP 대역만 + **Authenticated Origin Pulls(mTLS)** + cert-manager DNS-01 와일드카드 `*.joshuatech.dev` + 표준 Ingress + Cloudflare proxied Full(strict). Traefik 대시보드·관리 UI는 Access 뒤. cloudflared는 SSH·kubectl 관리 접근 전용.
- 시크릿: **HashiCorp Vault(BSL 1.1)** Raft PVC(노드 A) + **OCI KMS auto-unseal**(Always Free Vault HSM 키) + K8s auth + **ESO Vault provider**(ExternalSecret → Secret). GitOps repo에는 경로 참조만.
- dev 범위: **앱 pod만 dev 네임스페이스 복제, 플랫폼 공유**(Authentik 별도 Application/Provider, Kafka 토픽 접두 `dev.`, CNPG 별도 database, ES 인덱스 접두, Dragonfly 별도 인스턴스/DB, Vault 별도 경로). dev quota requests 2Gi/limits 4Gi/pods 20, 도메인 `*dev.joshuatech.dev`.
- 승격·GitOps: **`platform-gitops` 별도 public repo**. CI(모노레포)가 main 빌드 후 digest를 `overlays/dev`에 커밋(GitHub App) → Argo auto-sync; prod는 `promote.yml`(workflow_dispatch)이 dev digest로 `overlays/prod` PR → ruleset(required checks, 0 approvals) → 머지 → sync. 롤백 = git revert. 태그 대신 digest 고정.

### 라운드 8 — 게이트웨이·v1 종료·SP-1 뼈대·문서
- 게이트웨이: **BFF Worker(Next.js Route Handler) = 게이트웨이** — 세션 쿠키 보관, Authentik에서 대상 pod audience로 토큰 교환, Traefik 공개 호스트 호출(Access 서비스 토큰 헤더). **pod별 호스트**: `joshuatech.dev`(웹), `auth.`(Authentik), `<pod>-api.`(pod), `admin-<pod>.`(Django admin, Access+SSO), `argo.`/`vault.`/`kibana.`(관리), `cdn.`(R2). 인클러스터 게이트웨이 없음.
- v1 종료: **바로 종료, 백업 없음**(사용자 결정; 데이터 임포트 없음). 설계 메모: 인스턴스 '종료(terminate)'가 아니라 **재이미지(인스턴스 유지)**로 처리해 A1 4/24 할당을 잃지 않게 한다 — 설계 제시 시 확인.
- SP-1 뼈대: **플랫폼 전부(ES/ECK 제외) + 웹 hello + Django pod 템플릿 + RAM 실측 보고**. tasks는 단계(클러스터→데이터→신원→웹)로 나눔.
- 문서 산출물: ADR 0002~0010(9개) + `.specify/memory/{product,architecture}.md` + `.claude/rules/{web,django-pod,fastapi-pod,infra,events}.md` + `.claude/agents/{web,api,infra}-builder.md` + approval-review boundary `k8s-security` — **그대로 확정**.

### 라운드 9 — 설계 승인 + 열린 질문 해소 (2026-08-28)
- 설계서 아티팩트 https://claude.ai/code/artifact/9b5205f4-4287-43fc-8d1f-fe7e43c02795 — 1절 승인, 2–7절 "열린 질문 결정 후 승인"(사용자).
- **D0 확정(OCI CLI)**: 테넌시 joshua92y, 홈 리전 ap-chuncheon-1, **PAYG(UPGRADED, SGD)**, A1 한도 250 OCPU/1,666 GB, 사용 4/26, 인스턴스 `joshtech_api_1st`·`joshtech_cache` 각 2 OCPU/13 GB(2025-05-18 생성), 8월 MTD Compute 1.18 SGD. → **13 GB 유지, 소액 과금(≈ $1–2/월) 감수**(사용자).
- BFF 세션: egenauto authx 모델 분석(백엔드=IdP, refresh 쿠키 HttpOnly, 서버측 토큰 행) → v2는 **Authentik 세션·refresh = 서버측 상태 + BFF refresh 쿠키(암호화, HttpOnly, SameSite=Lax) + access 5분 isolate 캐시**. 즉시 폐기: **폐기 이벤트 + Dragonfly 거부 목록** — 로그아웃/관리자 폐기/Authentik 세션 삭제 웹훅 → identity-admin이 Authentik revoke + Dragonfly `revoked:{sub}` not-before(또는 sid) 기록(TTL=access TTL) + Kafka `identity-admin.session.revoked`; 모든 pod 인증 미들웨어(django-common)가 JWT 검증 후 Dragonfly GET 1회; BFF는 identity-admin `/session/check` 2초 캐시. 근거: Google(불투명 토큰 중앙 검증 + RISC 이벤트 전파), Naver(불투명 토큰 + grant_type=delete).
- Django API 계층: **Django Ninja 1.7.0**(PyPI 최신, 릴리스 직후).
- Kafka: **Strimzi 오퍼레이터**(KafkaNodePool KRaft combined 1노드, KafkaTopic/KafkaUser CRD). 노드 A RAM +0.5–0.8 GB.
- OpenTofu 상태: **OCI Object Storage S3 호환 백엔드**(버킷 jt-tfstate, 버전 관리).
- 다음: 아티팩트 갱신 → `create-new-feature-branch.ps1` + `create-new-feature.ps1 -ShortName platform-foundation` → spec.md.

## 3. 노드 배치 (추천안, 실측으로 확정)

| 노드 | 역할 | 구성요소(RAM 추정) |
|---|---|---|
| A `role=platform` | K3s server(SQLite, secrets-encryption) | K3s server 1.0–1.5 · Argo CD trimmed 0.7–1.0 · Kafka KRaft 1.5–2.0(local-path PV) · Authentik server+worker 1.0–1.2 · OpenFGA 0.2 · Kibana 0.8 · ECK operator 0.2 · Alloy 0.4–0.7 · cloudflared · Sealed Secrets → ≈ 7.5 GB |
| B `role=data` | K3s agent | CNPG Postgres 1.5–2.0 · Dragonfly 0.5–1.0(maxmemory 고정) · Elasticsearch ≈ 2.0(heap 1) · Django/FastAPI pod + 워커 1.5–2.5 · cloudflared → ≈ 7.5 GB |

- StatefulSet은 nodeSelector 고정, 앱 Deployment는 A 선호. cloudflared 2 replica + anti-affinity. CPU request 낮게·limit 없음. Kafka `-Xmx1g`, 보존 7일. Redpanda 대체는 ADR 트리거(실측 > 2 GB).
- Authentik 공식 최소: 호스트 2 CPU / 2 GB (docker-compose 문서, 2026.8).

## 5. 참조 패턴: egenauto-deploy/k3s (R:\home\linuxpc\egenauto-deploy\k3s, 2026-06-08 설계서)

- 단일 노드 K3s v1.35 + **번들 Traefik(ServiceLB 80/443)** + **cert-manager ClusterIssuer(LE, Cloudflare DNS-01) 와일드카드 1장/네임스페이스** + Cloudflare proxied Full(strict) + favonia DDNS(동적 IP). 표준 `Ingress`(ingressClassName traefik, host 라우팅, base는 `PLACEHOLDER.egenauto.com`을 overlay JSON6902 패치로 치환). Traefik HelmChartConfig(externalTrafficPolicy Local, JSON 액세스 로그, Sentry OTLP 트레이싱), 대시보드는 IngressRoute + ipAllowList(LAN/VPN).
- Kustomize `cluster/`(ClusterIssuer·DDNS·Traefik) + `base/`(앱·Dragonfly·Certificate) + `overlays/{dev,prod}/`(namespace, **ResourceQuota + LimitRange**(dev requests 2Gi/limits 4Gi, pods 20), images newTag latest/stable, secretGenerator from `.env`).
- 시크릿: **SOPS + age** `.enc.env` → `apply.sh`가 복호화→apply→평문 삭제. 자동 재배포: systemd 타이머가 GHCR digest 폴링. 승격: promote.yml 재태깅(latest→stable), 롤백은 digest set image.
- Dragonfly 네임스페이스당 1개(PVC 2Gi, maxmemory 512mb, 5분 스냅샷). 앱 프로브는 tcpSocket, requests 100m/128Mi.
- 위생 메모: `overlays/dev/.decrypted~egenauto-shortlink.enc.env` 평문 잔존(삭제·gitignore 확인 필요), Traefik 트레이싱 헤더에 Sentry key 평문.
- v2 적용 시 차이: OCI는 고정 공인 IP(DDNS 불필요), 노드 2대(ServiceLB는 노드별), Argo CD가 apply.sh·auto-redeploy를 대체(CI가 digest를 gitops repo에 기록), SOPS → Vault.

## 4. 남은 질문 라운드 (예정)
6. 웹 세부: 디자인 시스템(shadcn+Tailwind v4 vs Once UI npm), MDX 파이프라인(Velite vs content-collections vs 자체), i18n(ko / ko+en), 이미지 전달(media pod 변형 → R2 vs Cloudflare Images).
7. 운영: 시크릿(Sealed Secrets / SOPS+age / ESO+OCI Vault), 관측(Grafana Cloud+Alloy / 자체 ES·Kibana 로그 / Sentry), 환경(prod + staging ns scale-0), 인그레스(터널 전용, K3s Traefik 비활성).
8. 저장소·CI·컷오버: 모노레포 + platform-gitops 분리, 승격 정책(staging 자동 / prod PR), v1 종료 시점·데이터 보관(pg_dump → Object Storage), 도메인·호스트명 계획, 게이트웨이(= BFF Worker vs 인클러스터 게이트웨이).
9. SP-1 정의: ADR 목록(0002~0009), rules/agents 목록, 뼈대에 포함할 플랫폼 구성요소(CNPG·Kafka·Authentik·OpenFGA를 SP-1 vs SP-2), RAM 실측 task, 완료 기준.
