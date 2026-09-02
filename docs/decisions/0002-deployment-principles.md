---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0002: 배포 원칙 — 불변 digest·Git 정본·pull CD (L1)

<!-- 근거: spec D2·D15·D16·§5(CI/CD)·§8 ADR 표, plan A26·A27·A35, research R13(GITHUB-CI-D2·D5·D6·D10), CI/CD 정책 검토 2026-08-26 §7.1 -->

## Context and Problem Statement

SP-1은 public 저장소 2개(모노레포·platform-gitops — D2)로 1인 운영 플랫폼을 세운다. v1은 SSH push 배포였다: CI가 서버 자격증명을 쥐고, 서버 상태는 git과 갈라지며, 롤백 절차가 없었다. public 저장소에서 같은 방식을 쓰면 CI 자격 유출 = 서버 장악이 된다. 트랙(ADR 0003)이나 프레임워크(ADR 0004)와 무관하게 모든 배포가 따라야 하는 최상위(L1) 불변식을 먼저 고정해야 한다.

## Considered Options

- **Git 정본 + pull CD + 불변 digest + PR 승격 (채택)** — 자격 최소·이력 완전·롤백 단일 절차, 대신 GitOps 스택 상주 비용
- SSH push 배포(v1 방식) — 단순하지만 CI가 서버 자격을 보유, drift 복원·승격 이력 없음
- `:latest` 태그 참조 — 편하지만 배포가 비재현적이고 롤백 대상이 특정되지 않음
- 수동 배포(kubectl/compose 직접 적용) — 기록·검증 없이 상태가 갈라져 1인 운영에서 사고 원인 추적 불가

## Decision Outcome

L1 원칙 7개를 채택한다. 이후 모든 CI/CD·gitops 설계(FR-032~FR-039)는 이 원칙의 구현이다.

1. **불변 digest** — 배포는 이미지 태그가 아닌 digest만 참조한다(kustomize `images[].digest`). 빌드 산출물과 실행물이 바이트 단위로 동일하다.
2. **Git 정본** — 클러스터·Worker의 원하는 상태 정본은 git(platform-gitops·모노레포)이다. 수동 변경은 drift로 감지·복원된다.
3. **pull CD** — 클러스터 배포는 클러스터 안의 Argo CD가 git을 pull한다. CI는 클러스터에 접근하지 않는다.
4. **CI 무자격증명** — CI에는 클러스터·OCI 자격증명이 없고 PAT도 없다(GitHub App 최소 스코프 토큰). 예외는 push 배포가 불가피한 Cloudflare Workers뿐이며, 스코프 토큰('Edit Cloudflare Workers')을 Environment `production` 시크릿으로 한정한다.
5. **PR 검증 / main 발행** — 모든 변경은 PR에서 검증(required check, ruleset `bypass_actors: []`)하고, 발행(이미지 빌드·digest bump·deploy)은 main에서만 한다. dev는 자동 digest bump PR(auto-merge 시도 — VD-5, VD = 검증 후 결정), prod 승격 PR은 사람이 머지한다(D16).
6. **rollback = revert** — 롤백은 gitops revert 커밋(웹은 `wrangler rollback`)이다. 클러스터 직접 조작으로 되돌리지 않는다.
7. **expand→contract** — 스키마·계약 변경은 확장(호환 추가) → 이행 → 수축(제거) 순서로 나눠, 배포 순서와 마이그레이션이 서로를 막지 않게 한다.

### Consequences

- 좋음: public 저장소 2개에 시크릿·자격 0건(시크릿은 Vault+ESO, ADR 0010), 모든 변경이 PR 이력으로 남음, 롤백이 단일 절차, 재현 가능한 배포.
- 나쁨: Argo CD 상주 RAM(≈ 0.6 GiB)과 gitops 저장소 관리가 추가되고, dev digest bump PR이 노이즈를 만들며, expand→contract는 마이그레이션을 두 단계로 쪼개는 부담이 있다(approval 리뷰 지적 F-7 — expand→contract linter는 후속 task로 수용).
- 위험 수용: `gh pr merge --auto` 동작 여부는 VD-5(실측)로 남긴다 — 실패 시 dev bump도 수동 머지.

### 부록: D10 Dragonfly (v1 계승)

spec §8 ADR 표에 따라 D10을 이 ADR 부록에 귀속한다(신규 결정 아님 — v1에서 계승). 캐시·큐·세션 거부 목록 저장소로 **Dragonfly를 유지**한다: dev·prod 인스턴스 분리, 인증 필수(`--aclfile`, pod별 사용자·키 범위 제한), Celery 브로커 겸용. 기각: Valkey(운영 중인 v1 자산·성능 프로파일 재검증 비용), Postgres 큐(거부 목록 0.2 s 조회 예산에 부적합). Authentik 2025.10+는 Redis 계열을 쓰지 않으므로 Dragonfly에 연결하지 않는다.
