---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0004: 웹 프레임워크 — Next.js 16.3 + OpenNext lean

<!-- 근거: spec D4·D19·§3(웹·BFF 흐름)·§7(리스크 표)·§8 ADR 표, plan A1(Worker 경유 수용, VD-2/VD-8)·A2(prefetch 이슈·핀 규칙), research R8(OPENNEXT-D1~D8·D11, 함정 #1334) -->

## Context and Problem Statement

웹 프론트엔드의 프레임워크와 Workers 위 실행 방식을 정해야 한다. 제약: Workers Free 한도(Worker 번들 3 MiB gzip·10 ms CPU/요청·100k 요청/일 — 정적 자산 요청은 무료·무제한), BFF Route Handler가 같은 코드베이스에 있어야 한다는 설계(spec §3), 취업 시장 가치와 v1 재사용(사용자가 Next.js를 명시 선택), 그리고 Cloudflare 어댑터 생태계의 과도기(vinext beta 등장).

## Considered Options

- **Next.js 16.3 + OpenNext lean(@opennextjs/cloudflare 1.20.x) — 프리렌더 + BFF만 (채택)** — 한 코드베이스, Free 한도 안 lean 구성
- Astro — 정적 중심으로 더 단순하지만 사용자가 기각(React 생태계·경력 가치·v1 재사용)
- SvelteKit — 번들이 작지만 React 생태계·v1 컴포넌트 재사용을 포기
- 정적 export + Hono Worker — BFF를 Next Route Handler로 쓸 수 없어 코드베이스가 둘로 갈라짐
- vinext — Cloudflare 신규 권장 경로지만 1.0.0-beta, Cache Components·PPR 미지원(SP-2에서 추이 재평가)

## Decision Outcome

Next.js 16.3(≥ 16.3.3 — 보안 수정 라인) + OpenNext lean 구성을 채택한다.

- **lean 구성**: 페이지는 전부 프리렌더(`app/[lang]` + `generateStaticParams([ko,en,ja])` + `dynamicParams: false`), 동적인 것은 BFF Route Handler(`app/api`, `force-dynamic`)만. 바인딩 0(KV·R2·D1·DO·IMAGES 미선언, `images.unoptimized`), 캐시는 static-assets incremental cache + `enableCacheInterception: true`만.
- **번들 예산 2.5 MiB**(gzip, Free 한도 3 MiB의 안전 마진): CI가 `wrangler versions upload --dry-run` 산출물 gzip 합산으로 게이트(`scripts/bundle-budget.mjs`), 초과 시 빌드 실패.
- **페이지 GET Worker 경유 수용**(사용자 결정 2026-09-01): OpenNext는 프리렌더 HTML을 정적 자산으로 서빙하지 않으므로 페이지 GET도 Worker 1회를 소비한다. "Worker 미호출" 대신 CPU p95 ≤ 10 ms·Error 1102 0건·일 요청 수 기록으로 관리하고, 존 Cache Rule·HTML 자산화 실험은 VD-2/VD-8 실측으로만 결정한다.
- **$5 탈출구**: 번들·CPU·요청 한도를 실측이 넘으면 의존성 제거를 먼저 하고, 그래도 초과면 Workers Paid($5/월) 전환 — 사용자 승인 필요(spec §7).
- **RSC prefetch 이슈 핀 규칙**: Next 16.3 + cache interception 조합의 무한 RSC prefetch 루프(opennextjs-cloudflare #1334 open, 수정 PR #1348 미머지). 16.2.12에는 버그가 없으나 Critical RCE 2건(GHSA-p293-qw3h-jr36 CVSS 9.0·GHSA-2xp9-vwfh-vxw4 CVSS 9.5)이 15.5.24·16.3.3에만 패치되어 있으므로 **보안 패치 라인 밖 다운그레이드 금지 — 16.2.x 폴백 금지**. 이슈 미해결 시 폴백은 16.3.4 유지 + `enableCacheInterception: false` 임시(수정 포함 패치 출시 후 재활성)이며, `e2e/hello.spec.ts`가 "로드 후 30초 내 `Next-Router-Prefetch: 1` 요청 ≤ 10"을 가드한다.

### Consequences

- 좋음: 페이지·BFF·디자인이 한 코드베이스, `_next/static` 등 정적 자산은 무료·무제한, Free 플랜 $0 운영, v1 React 자산 재사용.
- 나쁨: 페이지 GET이 Worker 요청·CPU를 소비하고, static-assets 캐시는 읽기 전용이라 ISR·revalidate·`use cache` 저장이 불가(완전 정적 페이지만), OpenNext는 Windows 빌드를 보장하지 않아 빌드는 WSL2/CI(ubuntu)로 한정된다.
- 위험 수용: Cloudflare가 권장 경로를 vinext로 바꿨다 — OpenNext 유지보수 추이를 SP-2에서 재평가한다. BFF 실측 CPU(10 ms 한도)는 미검증이라 BFF를 얇게(fetch 위임·JSON 패스스루) 유지하고 Error 1102를 E2E에서 감시한다.

### 부록: D19 콘텐츠 정본 (git MDX)

spec §8 ADR 표에 따라 D19를 이 ADR 부록에 귀속한다. 학습 노트·글·프로젝트 콘텐츠의 **정본은 git의 MDX 파일**이고 DB에는 메타·반응만 둔다. 로더는 `packages/content` 자체 구현(zod 스키마·다국어·캐시·remark/rehype — ko 기본 + `en`·`ja` 접미사 파일), 이미지는 R2 원본 + Cloudflare Image Transformations. 기각: Velite(의존 추가 대비 이득 없음), DB 저자 도구(정본 이원화), Cloudflare Images 유료(비용). 근거: 콘텐츠가 git에 있어야 PR 검증·revert(ADR 0002)가 콘텐츠에도 동일하게 적용된다.
