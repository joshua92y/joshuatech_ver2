# SP-1 결정 목록과 트레이드오프 (2026-08-27)

**상태**: 조사 자료(결정 전). SP-1 feature 디렉터리가 생기면 `specs/003-<slug>/research/`로 옮긴다.
**출처**: 웹 조사 에이전트 6(OCI·Cloudflare·웹 프레임워크·API/인증·데이터·배포 트랙) + v1 저장소 평가 1 + 반박 검증 8건. 1차 출처 URL은 §9. 수치는 2026-08-27 기준이며 무료 한도는 바뀔 수 있다.
**검증 상태**: 결정을 뒤집을 수 있는 주장 34건 중 8건을 독립 반박 검증(확정 5, 부분 오류 3 — 정정 반영), 나머지 26건은 미검증이나 대부분 두 개 이상의 에이전트가 같은 1차 문서에서 독립적으로 읽은 값(OCI 2/12, Workers Free 한도, Hyperdrive Free, Neon/Supabase/D1 한도 등).

---

## 1. v1 평가에서 전제가 바뀐 것

| 항목 | 이전 가정 | 실제 (v1 저장소 확인) |
|---|---|---|
| Postgres 위치 | OCI VM | **Render 관리형 free DB**(`my-db`, 버전 미기록). OCI에는 DB가 없다 |
| OCI VM | 1대 | **2대** — fastapi VM(Traefik v2.10 + FastAPI), cache VM(Dragonfly + R2 삭제 워커). shape/OCPU 미확인 |
| Django Admin | OCI | **Render free 웹서비스**(admin/mainapi 호스트), FastAPI가 5분마다 keep-alive 핑 |
| 사이트가 읽는 데이터 | DB | **저장소 내 MDX뿐**. DB(MarkdownPost/Project/Resume/FileMeta)는 관리자 전용, 사이트에 노출 안 됨 |
| 콘텐츠 자산 | 블로그 다수 | 실제 글: 작업물 MDX 2편. 블로그 11편은 Magic Portfolio 템플릿 설명서 |
| 프론트 배포 경로 | Pages | Pages + `@cloudflare/next-on-pages`(**npm deprecated** → 어차피 Workers 이행 필요) |
| 저장소 상태 | 운영 중 | 2025-06 이후 휴면, 마지막 커밋 2026-02-20 "마이그레이션 전 백업" |
| 도메인 존 | 미확인 | `joshuatech.dev` 존은 Cloudflare에 있음 → Workers 커스텀 도메인 전제 충족. 호스트 6개(apex/www, api, admin, mainapi, cdn, traefik) |
| 디자인 시스템 | 재사용 | Once UI 소스 vendoring은 **CC BY-NC 4.0** → SaaS/상업 전환 시 라이선스 문제. 토큰 구조만 차용 |
| 테스트 | 일부 | 통과 가능한 테스트 0건, CI 게이트 0건, `:latest`·PAT·SSH heredoc 시크릿 |

**결론**: v2는 재작성 전제가 맞고, 데이터 이행의 무게가 작다(DB는 관리자 전용·Render에 있음, R2 두 버킷은 그대로 참조 가능). 컷오버 제약은 DNS 호스트별 단계 전환, `api.joshuatech.dev`의 ACME 인증서 소유(OCI Traefik 443), v1 워크플로 4개(브랜치 필터 없음 — 건드리기 전 비활성화), Render 서비스는 마지막에 정리.

---

## 2. SP-1에서 결정해야 하는 것 (순서대로)

| # | 결정 | 옵션 | 추천 | 의존 | 시점 |
|---|---|---|---|---|---|
| D0 | **OCI 테넌시·할당 확인** (결정 아님, 사용자 행동) | — | 콘솔 3곳 확인 + VM 2대 `docker stats` | — | 지금 |
| D1 | **v1 사이트를 v2 컷오버까지 살려둬야 하는가** | 유지 / 내려도 됨 | 사용자만 답할 수 있음. 내려도 되면 B1 직행 가능, 유지면 B2→B1 | — | 지금 |
| D2 | **저장소 공개 여부** | public / Pro private($4) / Free private | **public** (ruleset·environment·CodeQL·attestation·arm64 러너·GHCR 무료, learning in public과 정합) | — | SP-1 |
| D3 | **런타임 트랙** | A Cloudflare-native / B2 웹 CF + API OCI compose-pull / B1 웹 CF + API OCI K3s+GitOps / B2→B1 | **B2 → B1**(v1 종료·테넌시 확정·관측 기준선 후 전환). D1이 "내려도 됨"이고 D0가 4/24면 B1 직행도 가능 | D0, D1 | SP-1 |
| D4 | **웹 호스팅** | Pages 유지 / Workers static assets | **Workers static assets** (Cloudflare 공식 "Start new projects with Workers", 정적 자산 요청 무료·무제한) | — | SP-1 |
| D5 | **웹 프레임워크** | Astro 7 / Next.js 16.3 + OpenNext / SvelteKit 3 | **Astro** (콘텐츠 컬렉션·Zod frontmatter 검증·프로젝트 밖 `content/study` 로더가 내장). 취업 키워드 최우선이면 Next.js | D4 | SP-1 |
| D6 | **API 언어·프레임워크** | FastAPI / Django+Ninja / Hono(TS) on Workers / Python Workers | **FastAPI 단일 백엔드**(Django Admin 폐기 → SQLAdmin/Starlette Admin). 트랙 A면 Hono | D3 | SP-1 |
| D7 | **주 DB** | Postgres 컨테이너 on OCI / Neon Free / Supabase Free / CNPG on K3s / D1 | **Postgres 컨테이너 on OCI**(B2) → CNPG(B1 전환 시). 트랙 A면 Neon | D3 | SP-1 |
| D8 | **v2 초기 동적 기능 범위** | 정적 사이트만 / + 문의·파일 업로드·관리자 / + 외부 사용자 로그인 | 사용자 결정. v1 실사용 데이터가 관리자 전용이므로 "외부 로그인"이 초기 범위인지가 인증·프레임워크 선택을 바꿈 | — | SP-1 (SP-2 범위 확정) |
| D9 | **인증** | Cloudflare Access(GitHub IdP)+서비스 토큰 / Better Auth(웹)+JWKS / FastAPI 자체 JWT / Clerk | **Access 위임으로 시작**, 외부 사용자 필요 시 Better Auth + JWT 플러그인(API는 JWKS 검증) | D8 | SP-1/2 |
| D10 | **멀티테넌트 경계** | tenant_id + RLS / 스키마 분리 / DB 분리 | **tenant_id NOT NULL + FORCE RLS + 트랜잭션 내 SET LOCAL**(헌법 III) | D7 | SP-1 |
| D11 | **캐시·큐** | Dragonfly 유지 / Valkey / Postgres 큐(procrastinate·pgmq) / CF Queues | **Dragonfly 폐기(BSL·RAM), 초기엔 Postgres 큐**, 캐시 필요 시 Valkey | D7 | SP-1 |
| D12 | **B2 배포 도구** | Komodo / doco-cd / systemd timer / Portainer CE | SP-1 spike로 Komodo vs doco-cd 실측, systemd 폴백. Watchtower(아카이브)·Dockge(git 없음) 제외 | D3 | SP-1 |
| D13 | **web CI 엔진** | Workers Builds / Actions + wrangler-action | **Actions + wrangler-action v4**(한 트리·한 정책; OIDC는 아직 없음 → 계정 소유 토큰 축소) | D2 | SP-1 |
| D14 | **관측 최소 구성** | Grafana Cloud Free + Alloy / Better Stack Free / Uptime Kuma | Grafana Cloud Free(10k 시리즈, 카드 불필요) + 외부 업타임 1개 | D3 | SP-1 plan(헌법 IV) |
| D15 | **ADR** | 0002 배포 원칙(L1) 채택 여부, 0003 런타임 트랙, 0004 웹 프레임워크 | 0002는 CI/CD 검토 §7.1 원칙 그대로 채택 | D3–D5 | SP-1 |
| D16 | **compose/GitOps 매니페스트 위치** | 모노레포 `infra/` / 별도 public `platform-gitops` | B2 기간은 모노레포, K3s 전환 시 분리 | D3 | SP-1 |

기본값으로 두고 이의 없으면 넘어갈 것: Python 3.13 + uv 멀티스테이지 arm64 이미지, GHCR digest 고정, Traefik v3(어느 트랙이든 v2.10→v3 이행), cloudflared Tunnel + Access 서비스 토큰(SSH·포트 개방 제거), R2=공개 자산 / OCI Object Storage=백업, Conventional Commits·Renovate.

---

## 3. D0 확인 절차 (사용자)

1. **테넌시 유형**: 콘솔 Billing & Cost Management > Billing > Upgrade and Manage Payment → Subscription Information의 Plan Type(Free Tier = Always Free 전용, 아니면 PAYG).
2. **VM 2대 shape**: Compute > Instances(Shape 열) 또는
   `oci compute instance list --compartment-id <OCID> --query 'data[*].["display-name",shape,"shape-config".ocpus,"shape-config"."memory-in-gbs","lifecycle-state"]' --output table`
3. **한도·사용량**: Governance & Administration > Limits, Quotas and Usage → Compute → `standard-a1-core-count` / `standard-a1-memory-count`의 used/available.
4. **실측 RAM**: 두 VM에서 `docker stats --no-stream` (v1 4컨테이너, 제한 없음).
5. **예산 알림**(PAYG면): Billing & Cost Management > Cost Management > Budgets — $1·$5 두 단계, Actual + Forecast. Budgets는 소프트 한도(24h 평가, 이메일)지만 Events → Functions로 쿼터 0 강제도 가능.

판정 규칙: (a) Always Free + 합계 ≤ 2/12 → "유지", v2는 남는 슬라이스에 맞춰 B2(또는 A). (b) PAYG + 4/24 RUNNING → 그대로 두되 과금 상한 ≈ $28/월을 spec 위험으로 명시(A1 $0.01/OCPU-h + $0.0015/GB-h; Oracle 가격표/API는 유료 테넌시 무료분을 아직 3,000/18,000 = 4/24로 표기해 PAYG 4/24 유지설을 뒷받침하지만 공식 문구는 없음). (c) 2/12 초과 인스턴스가 비활성화됨 → 지원 요청으로 복구 시도, 종료 금지. 유료 노드 추가($28–56/월)는 예산 ≈ 0 위반으로 기각.

주의: 2026-08-18부터 Always Free 테넌시의 초과 인스턴스는 자동 종료 대상(Oracle 이메일). 문서 변경일은 2026-06-12, 발효 06-15. "종료하면 한도 위로 재생성 불가"는 문서가 아니라 6/21 지원 티켓 답변. 한도 내인데 비활성화된 사례도 보고됨(Customer Connect 974476).

---

## 4. 트레이드오프 표

### 4.1 D3 런타임 트랙

| 축 | A Cloudflare-native | B2 웹 CF + API OCI compose-pull | B1 웹 CF + API OCI K3s + Argo CD/Flux | B2 → B1 (추천) |
|---|---|---|---|---|
| 비용/월 | $0 (실사용 시 Workers Paid $5) | $0 | $0 (RAM 초과 시 PAYG 위험) | $0 |
| 운영 시간/월 | ≈1h | 1–3h | 4–8h (Flux 3–6h) | 1–3h → 전환 1회 10–20h → 3–8h |
| 학습·이력서 | 엣지/서버리스 키워드 ↑, Python 백엔드 서사 단절 | Docker·Actions·공급망(digest·attestation)·Tunnel·관측; K8s 없음 | K8s·GitOps·Argo CD(CNCF 조사 60% 채택) 최고. 단 주니어 K8s 공고 5% | "compose→K8s 마이그레이션 수행" 서사, 단계별 학습 노트 |
| 멀티테넌트 | tenant_id 앱 계층 + DO/D1 per-tenant 가능(Free 10 DB) | 앱 계층 tenant_id + compose 네트워크 분리 | 네임스페이스·RBAC·NetworkPolicy·Quota 이중 경계 | 중 → 높음 |
| v1 이행 위험 | 높음: FastAPI·Admin·워커 TS 전면 재작성 | 낮음: 같은 docker 엔진·Traefik, 호스트별 컷오버 | 높음: 같은 VM에서 포트 80/443·CPU·RAM 경쟁 + Traefik v3 전환 동시 | 가장 낮음 |
| 락인 | 최고(DO·Hyperdrive·Access) | 낮음 | 낮음(K8s 매니페스트 이식) | 낮음 |
| 성립 조건 | Python 포기 + TS 재작성 수용 | 없음 | 12 GB에서 v1 병행 어려움 → v1 종료 또는 4/24 확인 후 | 전환 트리거를 spec에 명시 |
| 핵심 근거 | Python Workers는 beta(2026-08-26 문서)·TCP 소켓 없음 → Postgres 드라이버 불가; Containers는 GA지만 Paid 전용(≈$7/월) | K3s 서버 실측 0.5–1.6 GB + Argo CD 0.5–1 GB(공식 수치 없음) + Alloy 0.2–0.7 GB | | |

C(전부 K3s)는 무료 CDN·정적 자산 무료 포기라 기각.

### 4.2 D4 웹 호스팅

| 축 | Pages 유지 | Workers static assets (추천) |
|---|---|---|
| 공식 입장 | "Start new projects with Workers"(2026-08-25 랜딩), 신규 투자 중단(폐기는 아님) | 1급 경로. Astro/SvelteKit/OpenNext 어댑터 문서가 전부 Workers 기준 |
| 비용 | $0 | $0 — 정적 자산 요청 무료·무제한, Free 20,000 파일·Workers Builds 3,000분 |
| 기능 | 외부 존 CNAME, 파일 라우팅, Early Hints | Cron·Queues·Workers Logs·gradual deploy·`versions upload --preview-alias`·`rollback`(100개) |
| 제약 | v1의 next-on-pages는 deprecated | 커스텀 도메인은 활성 CF 존 필수(충족), SSR은 Free 10 ms CPU·100k req/일 안에서 → prerender 우선 |
| 이행 | 없음 | Pages 프로젝트에서 도메인 해제 → Workers 커스텀 도메인, 수 분 공백 |

### 4.3 D5 웹 프레임워크

| 축 | Astro 7.2 (추천) | Next.js 16.3 + OpenNext 1.20 | SvelteKit 3 RC |
|---|---|---|---|
| 학습 노트 컬렉션(핵심 요구) | **내장**: `glob()` 로더 `base`로 프로젝트 밖 `../../content/study` 읽기, Zod frontmatter 스키마, `draft` 필터, MDX | 비내장: `@next/mdx`는 frontmatter 미지원 → Velite/gray-matter + 직접 순회, Turbopack 플러그인 제약 | 비내장: mdsvex + 서드파티 |
| Cloudflare 배포 | `@astrojs/cloudflare` 14(13.0부터 Workers 전용, dev도 workerd) | vinext(베타, CF 1순위 안내) vs OpenNext(성숙; Windows 완전 지원 비보장 → WSL), Free 3 MiB 번들 한도 | adapter-cloudflare, 작은 번들 |
| 취업 시장(국내 2026-08-27) | 사람인 "Astro.js" **0건** | 사람인 "Next.js" **316건**, React 1,058 | Svelte 7건 |
| 만족도(State of JS 2025) | 94% | 55% | 88% |
| 운영 | 1–2h/월, 정적이라 노출면 작음, 메이저 18개월 3회 | 2–4h/월, 월 단위 보안 릴리스(2026-08-25 Critical RCE 2건), 어댑터 경로 2026년 내 재편 | 1–3h/월, 2→3 메이저 직후 |
| v1 재사용 | React 컴포넌트는 아일랜드로, 라우팅 재작성 | 최고(단 Next 16 브레이킹 + Pages→Workers 이행 필수) | 전량 폐기 |
| 지속성 | 2026-01-16 Cloudflare 인수(MIT·다중 타깃 약속) — 어댑터 지속성 ↑, 플랫폼 편향 위험 | Vercel | 독립 |
| 이력서 상쇄 | `@astrojs/react` 아일랜드로 React 유지 + "Next→Astro 전환 근거" ADR·노트 | — | — |

### 4.4 D6 API

| 축 | FastAPI on OCI (추천) | Django 6.1 + Ninja on OCI | Hono(TS) on Workers | Python Workers |
|---|---|---|---|---|
| 상태 | 0.141.1, 주 단위 릴리스 | 6.1(2026-08-05, LTS 아님; 6.2 LTS 2027-04), Ninja 1.6.3 | 4.13.5, CF 공식 가이드 | **beta**, `python_workers` 플래그, TCP 소켓 없음 |
| Postgres·RLS | psycopg/asyncpg, Depends에서 SET LOCAL 강제 | ORM이 세션 변수 미지원 → 수동 배관 | Hyperdrive(Free 10만 쿼리/일) + 요청마다 새 pg Client | 드라이버 경로 없음 |
| 관리자 | SQLAdmin 0.31 / Starlette Admin 1.0.1 + Access | Django Admin 내장 | 없음(직접 제작 또는 Directus 컨테이너) | 없음 |
| 인증 | fastapi-users maintenance mode → Access 위임 후 Better Auth JWKS 검증 | allauth 65.19 headless/JWT | Better Auth(Vercel 인수, MIT) organization 플러그인 | — |
| v1 재사용 | 높음(같은 언어, Django façade 제거) | API 전면 재작성 | 전면 재작성 | 이행 불가 |
| 비용/운영 | $0 / 3–5h(VM 포함) | 동일 | $0–5 / 1–2h | — |
| 기각 사유 | — | 새 학습 폭 작음, RLS 배관 | Python 서사 단절, 락인 최고 | beta·DB 경로 없음 |

### 4.5 D7 주 DB

| 축 | Postgres 컨테이너 on OCI (B2 추천) | Neon Free (A일 때) | Supabase Free | CNPG on K3s (B1 전환 시) | D1 |
|---|---|---|---|---|---|
| 한도 | RAM 직접 배분(1–2 GB), 블록 200 GB | 0.5 GB, 100 CU-h/월, 5분 scale-to-zero 고정(콜드 수백 ms) | 500 MB, 7일 비활성 시 일시정지, **자동 백업 없음** | K3s+오퍼레이터+인스턴스 ≥ 1 GB 추가 | DB당 500 MB, 10개 |
| 리전 | OCI 홈 리전 | 싱가포르(서울·도쿄 없음) | **서울 있음** | OCI | apac 힌트(보장 없음) |
| 백업 | pgBackRest 2.59(활발) → OCI Object Storage 20 GB(S3 호환) + 주간 pg_dump → R2 | PITR 6h | 자체 스크립트 | barman-cloud 플러그인 0.14 | Time Travel 7일 |
| RLS | ○ | ○ | ○(service_role은 우회) | ○ | ✕(SQLite) |
| 운영/월 | 2–4h | 0.5h | 1h(일시정지 감시) | 4–8h | 0.5h |
| 학습 | 운영(백업·복구·튜닝) 경험 | 서버리스 브랜칭 | BaaS | 오퍼레이터·GitOps 데이터 계층 최고 | CF 한정 |
| v1 이행 | Render `my-db` pg_dump → 복원(소규모, 분 단위) | 0.5 GB 확인 필요 | 500 MB | initdb.import | 방언 변환·앱 재작성 |
| 비용 | $0 | $0 | $0 (Pro $25) | $0 | $0 |

### 4.6 D12 B2 배포 도구

| 도구 | 상태 | pull/드리프트 | 부담 |
|---|---|---|---|
| Komodo 2.3.2 | 활발, UI, Resource Sync(폴링 diff + 웹훅 자동 실행) | 커밋 diff 알림, 컨테이너 상태 재조정 없음 | MongoDB/FerretDB 의존, <256 MB(2차 출처) |
| doco-cd 0.112 | 매우 활발, distroless 단일 컨테이너, 웹훅+폴링, Renovate | 커밋 기준 | 0.x라 API 불안정 |
| systemd timer + git pull | 도구 없음 | 커밋 해시 비교만, 실패 가시성 낮음 | 최소 |
| Portainer CE 2.45 LTS | git 자동 갱신이 CE인지 문서·블로그가 상충 | — | UI 무거움 |
| Watchtower / Dockge | 아카이브(2025-12-17) / git 폴링 없음 | — | 제외 |

### 4.7 D11 캐시·큐

| 옵션 | 라이선스/상태 | 판단 |
|---|---|---|
| Dragonfly 1.40 | BSL 1.1, RAM 소모, v1에서 6379 공개·무비밀번호 | 폐기 |
| Valkey 9.1 | BSD-3, LF | 캐시가 실제로 필요해질 때 |
| Redis 8.10 | RSALv2/SSPL/AGPL 3중 | 비권장 |
| pgmq 1.12 / procrastinate 3.9 | 활발, Postgres 네이티브 | **초기 기본값**(컨테이너 1개 감소) |
| CF Queues(Free, 1만 ops/일) · KV(1 GB) · DO(SQLite) | 2026-02-04부터 Free | 트랙 A 또는 웹 측 잡무 |

---

## 5. 추천 조합과 결과 트리

**추천**: public repo · B2→B1 · 웹 Workers static assets + Astro 7 · API FastAPI 단일 백엔드(SQLAdmin, Access) · Postgres 컨테이너 on OCI(pgBackRest → OCI Object Storage) · tenant_id + RLS · Postgres 큐 · cloudflared Tunnel + Access 서비스 토큰 · Grafana Cloud Free · Actions + wrangler-action · GHCR digest.

```
joshuatech_ver2/
├── apps/
│   ├── web/                         # Astro 7 + @astrojs/cloudflare 14 → Workers static assets
│   │   ├── src/content.config.ts    #   glob({ base: "../../content/study" }) + Zod(frontmatter 계약 = rules/content.md)
│   │   └── wrangler.jsonc
│   └── api/                         # FastAPI 0.141, Python 3.13, uv, SQLAdmin, tenant_id+RLS Depends
│       ├── Dockerfile               #   ghcr.io/astral-sh/uv:python3.13-trixie-slim → python:3.13-slim-trixie, linux/arm64
│       ├── pyproject.toml / uv.lock
│       └── tests/
├── content/study/                   # 학습 노트(기존, 사이트가 컬렉션으로 읽음)
├── infra/
│   ├── compose/                     # v2 stack: traefik v3, api, postgres, cloudflared, (komodo|doco-cd)
│   │   ├── compose.yml              #   image@sha256 digest, mem_limit, networks, healthcheck
│   │   └── env.example              #   필수값 목록(부팅 시 검증), 값 없음
│   ├── cloudflare/                  # DNS/R2/Tunnel/Access as code
│   └── oci/                         # VM 부트스트랩, pgBackRest → Object Storage, 유휴 회수 방지 잡
├── docs/decisions/
│   ├── 0002-deployment-principles.md   # L1 원칙(CI/CD 검토 §7.1)
│   ├── 0003-runtime-track.md           # B2→B1, 전환 트리거
│   ├── 0004-web-framework.md           # Astro (Next.js 기각 근거)
│   └── 0005-data-tenancy-boundary.md   # tenant_id + RLS
├── .claude/
│   ├── rules/{web,api,infra}.md     # paths 스코프 규칙
│   └── agents/{web,api}-builder.md
├── .github/workflows/
│   ├── ci.yml                       # PR: lint/test/build, 배포 없음
│   ├── publish-api.yml              # main: arm64 native build → digest push → attest → compose digest bump PR
│   └── deploy-web.yml               # PR: versions upload(프리뷰) / main: deploy, wrangler-action v4
└── specs/, tests/, scripts/         # 기존
```

B1 전환 시 추가: `infra/k3s/`, 별도 public `platform-gitops`(CI/CD 검토 §7.2 트리), CNPG + barman-cloud, Argo CD Core 또는 Flux.

---

## 6. 트랙 A를 고를 때의 조합 (참고)

Astro(정적) + Hono on Workers + Neon Free(Hyperdrive) 또는 D1 + Better Auth + CF Queues/KV. 비용 $0(실사용 $5), 운영 ≈1h/월. 대가: Python 포기, Django Admin 대체 없음, 락인 최고, Workers Free 10 ms CPU·100k req/일 경성 한도. v1 데이터는 Neon으로 pg_dump(0.5 GB 확인).

---

## 7. 검증에서 정정된 것

| 주장 | 판정 | 정정 |
|---|---|---|
| OCI 2/12 = 1,500 OCPU-h/9,000 GB-h, 춘천 리전 제외 | 확정 | — |
| 2026-06-15 반감, 문서만 수정, 종료 시 재생성 불가(문서) | 부분 오류 | 문서 변경 2026-06-12(발효 06-15); "재생성 불가"는 지원 티켓 답변; 7/21 공지·8월 이메일(8/18 이후 자동 종료) 있음 |
| PAYG 4/24 무료 유지 공식 문구 없음 | 확정 | 지원 답변 상충, 공식 해명 없음(2026-08-27) |
| A1 단가 $0.01/OCPU-h·$0.0015/GB-h → 초과분 ≈ $28/월 | 확정 | 가격표/API는 유료 테넌시 무료분을 아직 4/24로 표기 → $28은 상한 |
| Budgets는 이메일만, 차단 없음 | 부분 오류 | Events → Notifications/Functions로 쿼터 0 강제 가능; 경로 Cost Management > Budgets |
| Pages 랜딩 "Start new projects with Workers" | 확정 | — |
| Workers Free 한도 10개 수치 | 확정 | 128 MB는 isolate당, 내부 서브리퀘스트 1,000 |

---

## 8. 열린 질문 (spec에 실측 task로 넣을 것)

- v1 VM 2대 실측 RAM/CPU(`docker stats`), 테넌시 유형, A1 used/available — D0.
- Render `my-db`의 Postgres 버전·크기(pg_dump 경로, Neon PG 18 복원 제약).
- 웹(Workers)→API(OCI) RTT p50/p95, Smart Placement 전후.
- Hyperdrive → Tunnel → 사설 Postgres가 Free 플랜에서 되는지(문서에 플랜 언급 없음), Workers VPC(베타 무료).
- Astro dev 서버가 프로젝트 밖 `base` 변경을 HMR로 감시하는지.
- Komodo/doco-cd/cloudflared/Argo CD Core/K3s 1.36의 arm64 실측 RAM.
- SQLAdmin vs Starlette Admin(관리자 요구사항 확정 후).
- R2 무료 구간에 결제수단 등록이 필요한지.

SP-2로 이월: 디자인 시스템(Once UI 라이선스), 관리자 화면 범위, 외부 사용자 기능.

---

## 9. 1차 출처 (2026-08-27 확인)

- OCI: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm · https://docs.oracle.com/iaas/Content/FreeTier/resourceref.htm · https://docs.oracle.com/en-us/iaas/Content/Billing/Tasks/changingpaymentmethod.htm · https://docs.oracle.com/en-us/iaas/Content/General/Concepts/servicelimits.htm · https://docs.oracle.com/en-us/iaas/Content/Billing/Tasks/create-budget.htm · https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/resizinginstances.htm · https://www.oracle.com/cloud/compute/arm/ · https://www.infoq.com/news/2026/07/oracle-cloud-free-tier-limits/ · https://news.ycombinator.com/item?id=49183750 · https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm
- Cloudflare: https://developers.cloudflare.com/pages/ · https://developers.cloudflare.com/workers/platform/limits/ · https://developers.cloudflare.com/workers/platform/pricing/ · https://developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/ · https://developers.cloudflare.com/workers/static-assets/compatibility-matrix/ · https://developers.cloudflare.com/workers/ci-cd/builds/limits-and-pricing/ · https://developers.cloudflare.com/workers/languages/python/ · https://blog.cloudflare.com/python-workers-advancements/ · https://developers.cloudflare.com/changelog/post/2026-04-13-containers-sandbox-ga/ · https://developers.cloudflare.com/containers/pricing/ · https://developers.cloudflare.com/hyperdrive/platform/pricing/ · https://developers.cloudflare.com/hyperdrive/configuration/connect-to-private-database/ · https://developers.cloudflare.com/workers-vpc/ · https://developers.cloudflare.com/changelog/2026-02-04-queues-free-plan/ · https://developers.cloudflare.com/workers/ci-cd/external-cicd/github-actions/ · https://developers.cloudflare.com/fundamentals/api/get-started/account-owned-tokens/ · https://developers.cloudflare.com/workers/configuration/versions-and-deployments/rollbacks/ · https://developers.cloudflare.com/workers/configuration/routing/custom-domains/ · https://developers.cloudflare.com/cloudflare-one/identity/service-tokens/ · https://developers.cloudflare.com/cloudflare-one/team-and-resources/users/seat-management/ · https://developers.cloudflare.com/d1/platform/limits/ · https://developers.cloudflare.com/r2/pricing/ · https://developers.cloudflare.com/kv/platform/limits/ · https://developers.cloudflare.com/durable-objects/platform/pricing/
- 웹: https://astro.build/blog/astro-7/ · https://astro.build/blog/astro-720/ · https://docs.astro.build/en/reference/content-loader-reference/ · https://docs.astro.build/en/guides/content-collections/ · https://docs.astro.build/en/guides/integrations-guide/cloudflare/ · https://astro.build/blog/joining-cloudflare/ · https://nextjs.org/blog/next-16-3 · https://nextjs.org/blog/august-2026-security-release · https://nextjs.org/docs/app/guides/mdx · https://opennext.js.org/cloudflare · https://developers.cloudflare.com/workers/framework-guides/web-apps/nextjs/ · https://github.com/cloudflare/vinext · https://registry.npmjs.org/@cloudflare/next-on-pages/latest · https://svelte.dev/blog/sveltekit-3-release-candidate · https://2025.stateofjs.com/en-US/libraries/ · https://m.saramin.co.kr/search?searchword=Next.js
- API/인증: https://pypi.org/project/fastapi/ · https://docs.djangoproject.com/en/6.1/releases/6.1/ · https://pypi.org/project/django-ninja/ · https://litestar.dev/blog/v3-announcement/ · https://docs.astral.sh/uv/guides/integration/docker/ · https://github.com/GoogleContainerTools/distroless/blob/main/python3/README.md · https://registry.npmjs.org/hono · https://hono.dev/docs/middleware/builtin/cors · https://vercel.com/blog/vercel-acquires-better-auth · https://better-auth.com/docs/plugins/jwt · https://better-auth.com/docs/plugins/organization · https://fastapi-users.github.io/fastapi-users/latest/ · https://pypi.org/project/sqladmin/ · https://pypi.org/project/starlette-admin/ · https://www.postgresql.org/docs/current/ddl-rowsecurity.html · https://www.postgresql.org/docs/current/sql-set.html · https://www.crunchydata.com/blog/row-level-security-for-tenants-in-postgres · https://www.cloudflare.com/zero-trust/products/access/
- 데이터: https://neon.com/docs/introduction/plans · https://neon.com/docs/introduction/regions · https://neon.com/docs/changelog · https://supabase.com/pricing · https://supabase.com/docs/guides/platform/free-project-pausing · https://supabase.com/docs/guides/platform/regions · https://turso.tech/pricing · https://planetscale.com/pricing · https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/autonomous-always-free.html · https://github.com/cloudnative-pg/cloudnative-pg/releases · https://github.com/cloudnative-pg/plugin-barman-cloud/releases · https://pgbackrest.org/release.html · https://redis.io/legal/licenses/ · https://github.com/valkey-io/valkey/releases · https://github.com/dragonflydb/dragonfly/blob/main/LICENSE.md · https://github.com/pgmq/pgmq/releases · https://github.com/procrastinate-org/procrastinate/releases
- 배포: https://docs.k3s.io/release-notes/v1.36.X · https://docs.k3s.io/installation/requirements · https://docs.k3s.io/reference/resource-profiling · https://github.com/k3s-io/k3s/discussions/3558 · https://github.com/argoproj/argo-cd/releases · https://argo-cd.readthedocs.io/en/stable/operator-manual/core/ · https://github.com/fluxcd/flux2/releases · https://github.com/fluxcd/flux2/discussions/558 · https://www.cncf.io/announcements/2025/07/24/cncf-end-user-survey-finds-argo-cd-as-majority-adopted-gitops-solution-for-kubernetes/ · https://komo.do/docs/automate/sync-resources · https://github.com/kimdre/doco-cd · https://github.com/containrrr/watchtower/discussions/2135 · https://docs.portainer.io/user/docker/stacks/add · https://docs.docker.com/reference/compose-file/services/ · https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/tunnel-availability/system-requirements/ · https://grafana.com/pricing/ · https://grafana.com/docs/alloy/latest/introduction/estimate-resource-usage/ · https://betterstack.com/uptime/pricing · https://docs.github.com/en/packages/learn-github-packages/deleting-and-restoring-a-package · https://github.blog/changelog/2025-08-07-arm64-hosted-runners-for-public-repositories-are-now-generally-available/ · https://kube.careers/state-of-kubernetes-jobs-2025-q3
- v1: `d:\code\joshuatech` — README.md, dir.md, docs/user/msa-maturity-comparison/*, docs/user/design-system-comparison/*, infra/oci/*.yml, apps/frontend/{wrangler.toml,next.config.js,package.json}, apps/backend_admin/config/settings.py, render.yaml, .github/workflows/*.yml
