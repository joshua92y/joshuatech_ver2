# Product Memory — JoshuaTech v2

> 정본: `specs/003-platform-foundation/spec.md`(결정 요약 D1–D20)와 `AGENTS.md`. 이 문서는 merge 이후 에이전트가 읽는 현재 상태 요약이며, 스택·경계의 상세는 `.specify/memory/architecture.md`에 있다.

## 제품 목표

- 개발자 포트폴리오 플랫폼을 처음부터 재구축한다. v1(`d:\code\joshuatech`)은 백업·임포트 없이 종료했다(D1 — VM은 재이미지, OCI 인스턴스는 유지).
- SaaS급 규율과 multi-tenant-ready 경계로 운영하고, 자체 학습 노트를 발행한다(learning in public).
- 저장소는 public 2개: 모노레포 `joshuatech_ver2` + 배포 정본 `platform-gitops`(D2).
- 런타임: 웹 Cloudflare Workers(Next.js + OpenNext lean) + API는 OCI K3s 2노드 + Argo CD — `docs/decisions/0003-runtime-track.md`. 백엔드 기본은 Django 6.1 + Ninja 1.7이고 FastAPI는 수치 트리거 ADR 예외(search·notification·assistant 후보)다 — `docs/decisions/0005-backend-framework-policy.md`.

## 도메인

포트폴리오 · 블로그 · 학습 노트 · 문의 · 미디어 · 사용자.

- 콘텐츠(학습 노트·글·프로젝트)의 정본은 git MDX(`content/**`, D19)이며 DB에는 메타·반응만 둔다.
- 사용자·테넌트·세션의 정본은 identity-admin(Authentik은 단일 IdP)이다.

## Pod 목록 (D18 — 8개)

| pod | 도입 단계 | 역할 요약 |
|---|---|---|
| identity-admin | SP-2(뼈대는 SP-1: health·세션 폐기·웹훅) | 사용자·테넌트·멤버십·세션 폐기 정본 |
| portfolio-core | SP-2 | 포트폴리오·블로그·학습 노트의 DB 메타·slug 연결(콘텐츠 정본은 git MDX) |
| media | SP-2 | 미디어(R2 원본 + Cloudflare Image Transformations) |
| engagement | SP-2 | 방문자 상호작용 — 반응·문의(상세 스코프는 SP-2 spec에서 확정) |
| notification | SP-3 | 알림 발송(FastAPI 예외 후보) |
| insights | SP-3 | 지표·분석(상세 스코프는 SP-3 spec에서 확정) |
| search | SP-3 | 검색 — Elasticsearch + Nori(FastAPI 예외 후보) |
| assistant | SP-4 | 어시스턴트·에이전트 계층(FastAPI 예외 후보) |

pod 간 경계(DB 독점·이벤트 소유·BFF 게이트웨이)는 `.specify/memory/architecture.md` §경계.

## 로드맵 (SP-1 ~ SP-4)

| 단계 | 상태 | 내용 |
|---|---|---|
| SP-1 플랫폼 기반 | 진행 중(003 merge 후 `/speckit-archive-run`에서 완료로 갱신) — `specs/003-platform-foundation/` | ADR 0002–0010, OCI K3s 2노드 플랫폼(GitOps·인그레스·시크릿·데이터·이벤트·신원·관측), 웹 hello + BFF, Django pod 템플릿, v1 종료·도메인 전환 |
| SP-2 사이트 코어 | 예정 | identity-admin(테넌트 오케스트레이션·사용자 삭제/내보내기)·portfolio-core·media·engagement, notes-sync |
| SP-3 | 예정 | notification·insights·search + Elasticsearch/ECK/Kibana(노드 B 예산 자리), 복원 실연(SC-011 이월) |
| SP-4 | 예정 | assistant, 테넌트별 Authentik Brand |

## 비기능 목표

- **무료 티어 우선**: Cloudflare Free(Workers·Zero Trust 50석·R2·Image Transformations)·Grafana Cloud Free·Sentry Free·OCI PAYG(월 Compute ≈ $1–2 감수, 예산 35 SGD + 알림 규칙 4 — D17). 실측 비용은 US7 뒤 갱신(T118).
- **SaaS 규율**: 테넌트 격리(`tenant_id` UUID + FORCE RLS), pod별 DB 독점, 이벤트 소유권, 테스트 우선·관측/롤백 준비(헌법 II·IV), 시크릿은 저장소 밖(Vault), public 저장소 gitleaks 0건.
- SP-1은 단일 테넌트 `joshuatech`를 시드하지만 모든 계약은 multi-tenant-ready다(사용자당 테넌트 1, 다테넌트 선택은 SP-2).
