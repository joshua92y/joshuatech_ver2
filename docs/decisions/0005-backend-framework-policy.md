---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0005: 백엔드 프레임워크 정책 — Django+Ninja 기본, FastAPI 수치 트리거 예외

<!-- 근거: spec D5·D18·§4(pod 템플릿 기본값)·§8 ADR 표, plan Complexity Tracking(Django pod 템플릿 + django-common), contracts/pod-template.md(생성 트리·런타임 계약·Celery), research/2026-08-28-brainstorm-decisions.md 라운드 5(pod 8개 확정·notification FastAPI+taskiq·assistant SSE/WS) -->

## Context and Problem Statement

SP-2~SP-4에 걸쳐 API pod 8개(부록 D18)를 1인이 만들고 운영한다. pod마다 프레임워크를 자유롭게 고르게 두면 RLS·outbox·인증·관측 규율이 첫 편차에서 무너진다(plan Complexity Tracking — 템플릿 + django-common이 규율을 지키는 유일한 방법). 따라서 기본 프레임워크 하나와, 그 기본을 벗어날 수 있는 통제된 예외 경로를 함께 고정해야 한다. 참고 청사진(커머스 SaaS 9-Pod)의 원칙도 같다: 기본 Django, FastAPI는 ADR 예외.

## Considered Options

- **Django 6.1 + Ninja 1.7 기본, FastAPI는 수치 트리거 ADR 예외 (채택)** — admin·ORM·마이그레이션 체계를 기본으로 얻고, async 특성이 지배하는 pod만 예외로 연다
- FastAPI 단일 — 전부 async지만 admin·ORM 마이그레이션·RLS 헬퍼를 pod 8개에서 직접 조립해야 한다
- Hono(TypeScript) — 웹과 언어가 통일되지만 Python 자산(v1 코드·Django 경험·Celery 생태계)을 포기한다
- Python Workers — 엣지 실행이 가능하나 K3s pod 표준(컨테이너·relay sidecar·Celery·testcontainers)과 어긋나고 런타임 제약이 크다

## Decision Outcome

1. **기본 = Django 6.1 + Django Ninja 1.7**(`ninja==1.7.0` 정확 핀, 회귀 시 1.6.2 폴백). 모든 pod는 `templates/django-pod`(copier)로 생성하고 `packages/django-common`(tenancy·outbox·auth·observability)에 의존한다(contracts/pod-template.md).
2. **FastAPI 예외는 수치 트리거로만 연다.** 트리거는 세 가지 워크로드 특성이다 — ① 동시 **연결 수**(장기 SSE/WS 연결이 워커를 점유), ② **fan-out**(한 이벤트가 다수 수신자 호출로 퍼짐), ③ 외부 **I/O 대기**가 응답 시간을 지배(업스트림 검색·외부 API 프록시). 예외 채택은 해당 pod feature에서 측정치·예상 수치를 적은 ADR로 기록한다(이 ADR 참조).
3. **예정 예외 3개**(D5): search(ES 질의 프록시 — I/O 대기), notification(구독 fan-out), assistant(SSE/WS — 연결 수). 셋 다 SP-3·SP-4 feature에서 수치와 함께 확정한다.
4. **all-async 약속**: FastAPI를 채택한 pod는 전 경로를 async로 쓴다. 동기 핸들러·동기 DB 드라이버 혼용은 금지 — 혼용하면 스레드풀 병목이 생겨 예외를 연 이유(연결 수·I/O 대기)가 사라진다.
5. **백그라운드 작업 규칙**: Django pod = **Celery**(+beat, Dragonfly 브로커 — contracts/pod-template.md) / FastAPI pod = **taskiq**(async 네이티브, notification이 첫 사례). 한 pod 안에서 두 체계를 섞지 않는다.
6. **경계 계약은 프레임워크 중립**: 테이블 등급 A/B·outbox `publish`·인증 미들웨어 순서·structlog/OTel/Sentry 계약(contracts/pod-template.md)은 FastAPI pod에도 동일하게 적용된다. django-common의 해당 부분은 FastAPI용 구현이 따로 필요하다(SP-3 비용으로 수용).

### Consequences

- 좋음: pod 8개가 같은 템플릿·라이브러리 규율을 공유하고, Django admin·ORM·마이그레이션 체계(expand→contract — ADR 0002)를 기본으로 얻으며, 예외가 문서화된 수치 트리거로만 열려 프레임워크 표류가 없다.
- 나쁨: Django 기본 경로는 sync라 장기 연결·대량 fan-out에 부적합 — 그런 요구가 생기면 예외 ADR 절차를 거쳐야 하고, FastAPI pod가 생기는 SP-3부터 공통 라이브러리 일부를 async로 재구현해야 한다.
- 위험 수용: SP-1은 Django 경로(identity-admin)만 실증한다. FastAPI 예외 경로(all-async·taskiq)는 SP-3 notification에서 처음 검증되며, 그 전까지는 문서 약속이다.

### 부록: D18 pod 목록

spec §8 ADR 표에 따라 D18을 이 ADR 부록에 귀속한다. pod 8개와 단계: **SP-2** identity-admin·portfolio-core·media·engagement(전부 Django) / **SP-3** notification(FastAPI+taskiq, 구독 소유)·insights(Django, Kafka 소비)·search(FastAPI+ES) / **SP-4** assistant(FastAPI SSE/WS + pgvector). SP-1 뼈대는 8개 전부의 provider·DB·role·토픽 명명을 미리 잡는다. 기각: 단일 pod(경계·pod 규율 학습 목표 상실), 청사진 그대로 9개(포트폴리오 규모에 불필요한 pod까지 복제).
