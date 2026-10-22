---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0006: 신원·인가 — Authentik 단일 IdP·RFC 8693 교환(기본 impersonation)·OpenFGA

<!-- 근거: spec D6·D7·§3(웹·BFF·인증 흐름)·§7(리스크 표)·Assumptions(VD-1 절)·Key Entities(TenantMembership·SessionRevocationLog·SessionRevocation), contracts/identity-admin-api.md §호출자 식별·§VD-1, data-model §2·§3·§10, plan Complexity Tracking(Authentik + OpenFGA), research/2026-09-01-approval-r2-factcheck.md §1(R26 — delegation 판정·azp·parentless Actor) -->

## Context and Problem Statement

pod 8개가 하나의 신원 체계를 공유해야 한다: 소셜(GitHub·Google) + 이메일/비밀번호 + MFA 로그인, pod마다 최소 신뢰의 audience 분리, 로그아웃·관리자 폐기가 2초 안에 전 pod에 반영되는 세션(SC-003), SP-2부터 pod 경계를 넘는 인가(media↔engagement). 제약: Authentik 2026.8 OSS의 RFC 8693 token exchange에서 delegation의 `actor_token`은 authentik `Actor`를 가리켜야 하는데, OSS에는 `Actor`를 만드는 지원 경로가 없다(팩트체크 2026-09-01 §1) — BFF 호출자 식별 방식이 이 제약에 걸리므로 기본 모드와 실측 경로를 함께 고정해야 한다.

## Considered Options

- **Authentik 단일 IdP + provider별 aud + RFC 8693 교환(기본 impersonation) + BFF 게이트웨이 + OpenFGA + Access 이중 (채택)** — IdP 운영·audience 분리·교차 인가를 처음부터 연습
- Better Auth — 라이브러리라 상주 비용이 없지만 provider별 audience·토큰 교환·MFA·소셜 연동을 직접 구현해야 한다
- Clerk — 관리형이라 운영이 없지만 SaaS 종속·셀프호스트 불가, IdP 운영 학습 목표와 어긋난다
- 자체 세션 서비스 — identity-admin이 세션 정본을 갖는 안: 저장·회전·MFA를 재구현하고 Authentik과 정본이 이원화된다
- 요청마다 introspection — 폐기 즉시성은 얻지만 모든 pod 요청이 Authentik 가용성·지연에 동기 결합된다(TTL 축소만으로는 SC-003 2초를 못 지킨다)

## Decision Outcome

1. **Authentik 단일 IdP**(소셜 GitHub·Google + 이메일/비밀번호 + MFA), **provider별 audience** — pod는 자기 `aud`만 신뢰하고, 브라우저 토큰(`aud=web-bff`)은 pod에 닿지 않는다.
2. **BFF = 유일한 게이트웨이**: BFF가 RFC 8693 token exchange로 `audience=<pod>` 토큰을 받아 `<alias>-m2m-<env>.joshuatech.dev`를 호출한다(인클러스터 게이트웨이는 두지 않는다 — D6 기각).
3. **호출자 식별, SP-1 기본 = impersonation 교환**: 발급 토큰에 `act` 클레임이 없고, pod는 **Cloudflare Access 서비스 토큰의 `common_name`**(ConfigMap `ACCESS_EXPECTED_CN` — prod `web-bff-prod`, dev `web-bff-dev`)으로 호출자를 식별한다. `AUTH_ACTOR_SUB`는 선택값 — 설정된 배포에서만 `act.sub`를 그 값과 대조하고, 미설정(기본)이면 `act`를 요구하지 않는다. **Access 서비스 토큰은 어느 모드에서도 네트워크 게이트로 유지**한다(Access + pod 자체 검증 이중).
4. **세션(D7)**: 정본 = **Authentik 서버측 세션** + BFF 암호화 refresh 쿠키(HttpOnly·Secure·SameSite=Lax — egenauto authx 동형), access 토큰은 isolate 캐시 5분. **즉시 폐기** = identity-admin이 Authentik revoke + `SessionRevocationLog`(DB 정본) 기록 + Dragonfly 파생 캐시(`revoked:sub:{sub}` = nbf epoch·`revoked:sid:{sid}`, TTL 330 s) + Kafka `identity-admin.session.revoked` 발행. 모든 pod 미들웨어가 요청마다 거부 목록을 1회 조회하고(타임아웃 0.2 s), 조회 실패는 비헬스 경로 503 fail-closed다. 30 s Celery beat가 로그를 **조건 없이 재적용**하므로(센티널 폐지) Dragonfly 비정상 종료의 유실 창은 최대 30 s다.
5. **OpenFGA = 교차 컨텍스트 인가만**(테넌트 격리 자체는 RLS — ADR 0007). SP-1 모델은 `tenant`의 `owner`·`member` 2관계(`owner ⊂ member`)이고, 튜플 `user:<sub> member tenant:<uuid>`는 멤버십 정본 `TenantMembership`의 파생으로 identity-admin만 쓴다(SP-1은 `seed_tenant`).

### VD-1 (검증 후 결정) — Authentik OSS에서 delegation을 쓸 수 있는가

- **기본 가정(문서 기본값)**: impersonation 교환 + Access `common_name` 식별(`AUTH_ACTOR_SUB` 미설정). 근거(팩트체크 §1): delegation 자체는 2026.8 OSS 기능이지만 `actor_token`은 **authentik `Actor`** 를 가리켜야 하고, OSS에는 `Actor`를 만드는 지원 경로가 없다(운영 경로는 Enterprise `Agent`; `Actor`는 serializer가 없어 blueprint/API로 만들 수 없다).
- **옵션 A**: OSS에서 `Actor` 생성에 성공하면(blueprint·API·`ak shell` 실험) delegation 교환으로 바꾸고 `AUTH_ACTOR_SUB`를 설정해 `act.sub`를 검증한다. 이때 `act.sub`는 리터럴 `web-bff`가 아니라 **대상 provider의 Subject mode**(기본 hashed user id)를 따르므로 provider `sub_mode`를 명시해야 한다.
- **옵션 B**: 교환이 `invalid_grant`(`actor_not_controlled`)면 기본 가정 그대로 간다.
- **판정**: T081 착수 시 **사용자 동석 실측**(contracts/identity-admin-api.md §호출자 식별·VD-1) — 교환 응답 캡처를 증거로 `report.md`에 남긴다. 코드는 어느 쪽이든 바뀌지 않는다(`AUTH_ACTOR_SUB` 유무로 갈린다).
- **대안 기록 2건**: (a) `audience`를 지정하지 않고 교환하면 발급 토큰의 `azp`가 web-bff provider의 client_id가 되어 `iss`+`azp`로도 호출자를 판별할 수 있으나, **`audience=<pod>` 지정과 양립하지 않으므로** 대안으로만 기록한다. (b) Enterprise 도입 시 `Agent`는 parent user에 묶이므로 "전 사용자를 대행하는 BFF actor"에는 **parentless `Actor`** 가 필요하다 — 조건부 경로.

### Consequences

- 좋음: pod마다 자기 audience만 신뢰(토큰 오남용 반경 최소), 소셜·MFA·플로우는 Authentik이 담당해 public 저장소에 세션 구현 코드가 최소화되고, 폐기가 DB 정본 + 파생 캐시로 2초 안에 전 pod에 반영되며(SC-003), 교차 컨텍스트 인가가 SP-2 전에 자리 잡는다.
- 나쁨: Authentik + OpenFGA 상주 RAM과 blueprint·provider 구성 학습 비용이 들고, 캐시 미스·콜드 isolate 시 교환 1홉 + `/session/check` 조회(2 s 캐시)가 추가되며, 거부 목록 fail-closed 때문에 Dragonfly 장애가 비헬스 경로 503으로 전파된다(의도된 안전 방향).
- 위험 수용 1 — **OpenFGA env 격리 없음**: 인스턴스 1개(`identity` ns)를 dev·prod가 공유하고 서버 preshared key도 전역 1개(`kv/platform/openfga/preshared`, env 사본은 같은 값)다 — dev·prod 분리는 store(`jt-dev`·`jt-prod`)뿐이다. **`openfga-dev` 인스턴스 분리를 SP-2 결정 항목으로 등재한다.**
- 위험 수용 2 — delegation 미확정: VD-1 실측(T081) 전까지 기본 모드는 impersonation이며, `act` 기반 호출자 증명은 없다(Access `common_name`이 대신한다).

