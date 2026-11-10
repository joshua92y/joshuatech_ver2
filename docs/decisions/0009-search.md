---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0009: 검색 — Elasticsearch + Nori + ECK(SP-3 구현)·pg_bigm 이월

<!-- 근거: spec D11·§1(토폴로지 — SP-3 자리 노드 B)·§8 ADR 표·Assumptions(ES/ECK·Kibana ≈ 3 GiB, plan A14), plan Complexity Tracking(Elasticsearch/ECK 자리만)·A5(pg_bigm 자체 이미지)·A14(노드 B 예산), data-model §7(확장 행 — pg_bigm SP-3 이월), research R5(CNPG-D3), ADR 0005(FastAPI 예외 트리거·부록 D18), research/2026-08-28-brainstorm-decisions.md(사용자 확정) -->

## Context and Problem Statement

사이트 검색(학습 노트·글·프로젝트)은 한국어가 기본 언어이고 en·ja 번역이 따라온다(ADR 0004 부록 D19 — ko 기본 + 접미사 파일). 구현은 SP-3(D11, D18의 search pod)이지만 검색 스택 선택은 노드 RAM 예산·pod 목록·CNPG 확장 계획·이벤트 소비 설계에 지금 영향을 주므로, SP-1에서 **결정만** 고정한다(plan Complexity Tracking — "SP-1은 RAM 자리만 남기고 구현하지 않음").

제약: Postgres FTS에는 한국어 형태소 분석이 없어 토큰화가 약하고, 보완 후보 pg_bigm(한·일 2-gram)은 PGDG apt에도 CNPG 확장 이미지에도 없어 자체 image-volume 확장 이미지 빌드가 필요하다(plan A5). 노드 B 예산은 8 GiB이고 SP-1 상주 합계는 ≈ 3.6 GiB다(plan A14).

SP-3 착수 시 바뀔 수 있는 것은 버전·구현 상세뿐이다 — 스택 방향 자체가 바뀌면 이 ADR을 편집하지 않고 대체하는 새 ADR을 쓴다(rules/docs.md).

## Considered Options

- **Elasticsearch 1노드 + Kibana + Nori(한국어 형태소 분석기) + ECK 오퍼레이터 + FastAPI search pod — SP-3 구현 (채택)** — 한국어 검색 품질과 ES·Kibana·오퍼레이터 운영 학습을 함께 얻는다
- Postgres FTS(+ pg_trgm/pg_bigm) — 상주 RAM 0이지만 한국어 형태소 분석이 없고(plan Complexity Tracking), pg_bigm 2-gram도 형태소 기반 랭킹을 대신하지 못하며 자체 확장 이미지 빌드 부담이 따라온다(plan A5)
- Pagefind — 정적 색인이라 서버 0이지만, 정본이 git MDX + DB 메타(반응·비공개)로 갈리는 구조(D19)에서 DB 쪽 메타 검색이 불가하고 검색 인프라 운영 학습 목표를 채우지 못한다
- OpenSearch — 라이선스는 Apache 2.0이지만 사용자가 ES + Kibana + ECK 조합을 확정했다(2026-08-28 브레인스톰 — 생태계·학습 가치 기준)

## Decision Outcome

1. **스택**: Elasticsearch 1노드 + Nori analyzer를 ECK 오퍼레이터로 선언 관리한다(Argo CD Application — 다른 플랫폼 컴포넌트와 같은 GitOps 경로, ADR 0002·0003).
2. **질의 앞단 = FastAPI search pod**: ADR 0005의 예외 트리거 ③(외부 I/O 대기가 응답 시간을 지배 — ES 질의 프록시)에 해당하는 예정 예외이며, 수치는 SP-3 feature에서 측정치와 함께 확정한다. D18대로 search는 notification·insights와 함께 SP-3 pod다.
3. **Kibana**: 색인·질의 디버깅과 학습 콘솔로 ES와 함께 배포한다(D11). ≈ 3 GiB 자리에 포함되며, 접근 경계(Access 뒤 노출 방식)는 SP-3에서 정한다.
4. **SP-1은 배치 계획만**: 아무것도 배포하지 않는다. ES·Kibana·ECK ≈ 3 GiB 자리를 **전부 노드 B**에 예약한다(B 합계 ≈ 6.6 GiB ≤ 8 GiB — plan A14). 노드 A에는 SP-3 자리를 잡지 않는다 — A의 여유는 ≈ 0.4 GiB뿐이다.
5. **색인은 이벤트 파생**: 콘텐츠 정본은 git MDX + pod DB(D19, ADR 0007)이고, 색인은 `portfolio-core.note.published` 등 Kafka 이벤트(ADR 0008) 소비로 만든다. 색인 유실 = 재색인이며 데이터 손실이 아니다 — ES 1노드 무HA를 수용하는 근거다.
6. **pg_bigm 이월**: SP-1 CNPG는 standard 이미지에 내장된 `pgvector`만 활성화한다(data-model §7, `CREATE EXTENSION`은 owner role). pg_bigm은 자체 확장 이미지(image-volume, K8s 1.36 GA) 빌드가 필요해 SP-3로 이월하고, ES가 요구를 충족하면 도입하지 않을 수 있다(research CNPG-D3 — 폴백 후보로만 유지).
7. **이 ADR은 결정 기록이다**: ES·ECK 버전 핀, 인덱스 매핑·다국어 analyzer 구성, 색인 파이프라인 같은 구현 상세는 SP-3 feature의 spec/plan(필요 시 후속 ADR)에서 잡는다 — 여기서 미리 확정하지 않는다.

### Consequences

- 좋음: 한국어 형태소 검색 품질과 Kibana·ECK 운영 학습을 확보하고, RAM 자리를 지금 예약해 SP-3에서 노드 재배치·예산 재협상이 없으며, 색인이 이벤트 파생이라 언제든 재구축할 수 있다.
- 나쁨: 구현 시 ≈ 3 GiB 상주(노드 B의 최대 단일 항목)가 추가되고, FastAPI 예외 pod가 하나 늘어 django-common 공통 규율의 async 재구현 비용(ADR 0005)을 search·notification이 나눠 지며, ES·ECK 업그레이드가 운영 부담에 더해진다.
- 위험 수용: SP-3까지 사이트 검색이 없다 — 그때까지 콘텐츠 탐색은 목록·태그다. Elastic License(비 OSI)와 ES 1노드 무HA·버전 선택은 SP-3 착수 시 재확인 항목으로 남긴다(이 ADR은 스택 방향만 고정한다).
