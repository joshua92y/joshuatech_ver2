# Contract: identity-admin API (SP-1 범위)

Django 6.1 + Ninja 1.7(`ninja==1.7.0` 정확 핀, 회귀 시 1.6.2 폴백). 오류는 RFC 9457. 응답 헤더에 `x-request-id`를 되돌린다(상류 `X-Request-ID`는 `^[A-Za-z0-9._:-]{1,128}$`에 맞을 때만 그대로 쓰고 아니면 새로 만든다 — 로그 증폭·임의 문자열 적재 방지 · T063 보정 2026-11-02). 저장 규칙은 data-model §1–3(테이블 등급 B), 거부 목록 키는 contracts/denylist.md.

## 호스트 · Ingress 경로 · Access AUD

| 호스트 | Ingress 경로(허용 목록, PathPrefix) | Access 앱 → AUD | 용도 |
|---|---|---|---|
| `identity-m2m-prod.joshuatech.dev` · `identity-m2m-dev.joshuatech.dev` | `/api` · `/health` · `/session` · `/sessions` · `/tenants` | Service Auth 앱(`web-bff-<env>` 토큰) → `ACCESS_AUD_M2M` | BFF 호출. 그 외 경로는 Ingress에 없어 404 |
| `admin.joshuatech.dev`(PathPrefix `/identity-admin`, prod만) | `/identity-admin/admin/…`(Traefik `stripPrefix`로 접두를 벗겨 pod에는 `/admin/…` · env `FORCE_SCRIPT_NAME=/identity-admin`은 `ADMIN_HOST` 요청에만 적용 — 아래 `ADMIN_HOST` 항목) | GitHub IdP 앱 `admin` + Authentik forward-auth → `ACCESS_AUD_ADMIN` | Django admin |
| `identity-admin.jt-prod.svc` · `identity-admin.jt-dev.svc`(클러스터 내부) | `/webhooks/authentik` · `/healthz` · `/ready` | Access 없음(svc DNS, FR-046) | Authentik 웹훅, kubelet 프로브 |

- **m2m Ingress에 `/webhooks`·`/healthz`·`/ready`는 넣지 않는다.** 웹훅은 Authentik이 클러스터 안에서 svc DNS로만 부르고, `/healthz`·`/ready`는 kubelet 프로브 전용이다. 공개 호스트로 이 셋을 부르면 **404**여야 한다(Ingress 층위이므로 앱 pytest가 아니라 **T076 E2E**가 단언한다). BFF가 중계하는 상세 헬스는 `/health`(Ingress에 있음)뿐이다.
- `ADMIN_HOST`(settings 필수값): admin urlconf는 `request.get_host() == ADMIN_HOST`일 때만 장착한다(정확 일치 — 부분 일치·포함 검사 금지). m2m 호스트로 `/admin/` 요청 → 404(T066). **dev는 `ADMIN_HOST`가 빈 값**이라 admin urlconf가 아예 없다(dev에 admin Ingress도 없다 · 빈 값은 어떤 호스트와도 일치하지 않는다 — 빈 문자열이 모든 호스트에 "포함"되는 실수 금지). **admin 경로 접두(T066 r1 보정 2026-11-03)**: env `FORCE_SCRIPT_NAME=/identity-admin`은 settings `ADMIN_SCRIPT_NAME`(선택 · 기본 빈 값 = 접두 없음)으로 읽고 **`ADMIN_HOST` 요청에만** script prefix로 적용한다(`reverse()` · 리다이렉트 `Location` · `request.path` — 익명 `/admin/` → `/identity-admin/admin/login/?next=/identity-admin/admin/`). Django 전역 설정 `FORCE_SCRIPT_NAME`은 두지 않는다 — 전역이면 m2m·svc 요청의 `reverse()`와 OpenAPI 경로 키에도 접두가 붙는다. 요청이 끝나면 접두를 되돌린다(스레드 로컬이 다음 요청에 새지 않게). 문서 tasks.md T075·T084의 "`FORCE_SCRIPT_NAME`"은 이 env를 가리킨다(Django 전역 설정이 아니다 — report.md 편차 후보).
- `ALLOWED_HOSTS`(필수값): svc DNS(`identity-admin.<ns>.svc`) · m2m 호스트 · (prod만) admin 호스트. 밖의 호스트는 400 — 업무 경로에서는 **인증보다 먼저** 판정한다(자격 없는 요청도 403이 아니라 400 · T066 보정 2026-11-03). kubelet 프로브의 Host(pod IP)와의 관계는 contracts/pod-template.md §런타임 계약 프로브 행.
- `ACCESS_AUD_M2M`·`ACCESS_AUD_ADMIN`·`ACCESS_EXPECTED_CN`은 ConfigMap 값(비밀 아님). Access 서비스 토큰 secret(`kv/{env}/access/web-bff`)은 Workers Secrets에만 있고 이 pod에는 없다.
- 외부 요청은 Cloudflare Access + Traefik(AOP mTLS)을 지나 도착한다. identity-admin이 Authentik을 부를 때는 **svc DNS만** 쓴다: 관리 API·revoke는 `http://authentik-server.identity.svc:9000/…`, **JWKS도 svc DNS** `http://authentik-server.identity.svc:9000/application/o/identity-admin/jwks/`(`kv/{env}/authentik/identity-admin.jwks_url`에 이 값을 넣는다). 토큰의 **`iss`만** 공개 URL `https://auth.joshuatech.dev/application/o/identity-admin/`로 검증한다. FR-046 예외 2(클러스터 안에서 공개 호스트 사용)는 **Argo CD·Vault의 OIDC discovery 둘로 한정**되며 pod는 해당되지 않는다(contracts/network-policy.md).

## 인증 계층 (django-common 미들웨어)

1. `Cf-Access-Jwt-Assertion` 검증(팀 도메인 `joshua-tech.cloudflareaccess.com`의 `/cdn-cgi/access/certs`, `aud ∈ {ACCESS_AUD_M2M, ACCESS_AUD_ADMIN}`) — 없거나 실패 403 `access_required`. 면제: 헬스 3종, `/webhooks/authentik`(svc DNS 경로, HMAC이 대신함).
2. `Authorization: Bearer` JWT 검증: JWKS(`kv/{env}/authentik/identity-admin.jwks_url` = **svc DNS**, 1시간 캐시), `iss`(공개 issuer URL)·`aud=identity-admin`·`exp`·`nbf`. 실패 401 `invalid_token`.
3. **호출자 식별** — 아래 §호출자 식별.
4. Dragonfly 거부 목록: `revoked:sub:{sub}`의 `nbf > iat` 또는 `revoked:sid:{sid}` 존재 → 401 `session_revoked`. 조회 실패(타임아웃 0.2 s 포함) → **503 `denylist_unavailable`(fail-closed)**, 헬스 경로만 면제.
5. `tenant_id` 클레임(UUID) → 요청 트랜잭션 안 `SELECT set_config('app.tenant_id', %s, true)`. 없으면 403 `tenant_required`. 값이 UUID로 파싱되지 않으면(slug 등) 2단계의 토큰 검증 실패로 보아 401 `invalid_token`(테넌트 컨텍스트에 닿기 전에 fail-closed · T062). 등급 B 테이블은 이 컨텍스트와 무관하게 app role로 읽는다.

서비스 간 호출(BFF → `/session/check`, Authentik 웹훅)은 2–5 대신 표의 규칙을 따른다. 구현 규약(T066 보정 2026-11-03): `/session/check`는 **Access 전용 경로**다 — 미들웨어 설정 `AUTH_ACCESS_ONLY_PATHS = ("/session/check",)`(정확 일치 · 라이브러리 기본값은 빈 튜플)에 든 경로는 1단계(Access JWT · `aud ∈ {M2M, ADMIN}` · `common_name == ACCESS_EXPECTED_CN`)만 요구하고 2–5를 건너뛴다(Bearer가 와도 검증하지 않는다 · 미들웨어는 거부 목록을 조회하지 않고 뷰가 질의 대상을 조회한다 · `request.access_claims`만 두고 `request.auth_claims`·`request.tenant_id`는 두지 않는다). 면제 목록(`AUTH_EXEMPT_PATHS` — 헬스 3종 + `/webhooks/authentik`)과는 다른 집합이다. 두 경로 모두 Bearer가 없어 테넌트 클레임이 없으므로 identity-admin의 `TENANT_CONTEXT_EXEMPT_PATHS`는 헬스 3종 + `/webhooks/authentik` + `/session/check`다(T068 미들웨어가 403 `tenant_required`를 내지 않게). 관리자 판정(`/sessions/revoke`에서 토큰과 다른 `sub` 지정)은 Bearer 클레임 **`groups`가 목록이고 그 원소 하나가 정확히 `platform-admin`** 인지로 한다(문자열 부분 일치·비슷한 이름 금지 · Authentik 그룹 scope mapping — T081 blueprint; 아니면 403 `forbidden`).

## 호출자 식별

**기본 모드 = impersonation 교환.** BFF는 RFC 8693 token exchange를 impersonation으로 쓰고(발급 토큰에 `act` 클레임 없음), pod는 **Cloudflare Access 서비스 토큰의 `common_name`** 으로 호출자를 식별한다.

| 검사 | 값 |
|---|---|
| Access JWT `common_name` | ConfigMap `ACCESS_EXPECTED_CN`과 일치해야 한다 — 값은 서비스 토큰 `web-bff-prod`(prod) · `web-bff-dev`(dev)의 **Client ID**(`<32 hex>.access`)다. Cloudflare가 서비스 토큰 JWT의 `common_name`에 넣는 값은 토큰 이름이 아니라 `CF-Access-Client-Id`이며 비밀이 아니다(T062 보정 2026-11-02 · T073 ConfigMap 값 · T076 E2E 실측). 불일치·부재 → 403 `access_required` |
| Bearer `act.sub` | ConfigMap **`AUTH_ACTOR_SUB`가 설정된 경우에만** 검증한다(일치하지 않으면 401 `invalid_token`). **미설정(기본) = impersonation 모드** — `act`가 없어도 통과 |

- `AUTH_ACTOR_SUB`는 env마다 다른 값을 가질 수 있다(prod `web-bff`, dev `web-bff-dev`). 값이 비어 있으면 검사 자체를 건너뛴다 — dev 체인(preview Worker·로컬 `next dev`)이 prod와 다른 provider를 쓰기 때문에 하나의 하드코딩된 기대값을 두지 않는다.
- 참고: `audience`를 지정하지 않고 교환하면 발급 토큰의 `azp`가 web-bff provider의 client_id가 되므로 `iss`+`azp`로도 호출자를 판별할 수 있다. 다만 **`audience` 지정과 양립하지 않으며** SP-1은 `audience=<pod>`를 쓰므로 이 경로는 대안으로만 기록한다(ADR 0006).

### VD-1 (검증 후 결정) — Authentik OSS에서 delegation을 쓸 수 있는가

- **기본 가정(문서 기본값)**: impersonation 교환 + `common_name` 식별(`AUTH_ACTOR_SUB` 미설정). 근거: delegation 자체는 2026.8 OSS 기능이지만 `actor_token`은 **authentik `Actor`** 를 가리켜야 하고, OSS에는 `Actor`를 만드는 지원 경로가 없다(운영 경로는 Enterprise `Agent`; `Actor`는 serializer가 없어 blueprint/API로 만들 수 없다).
- **옵션 A**: OSS에서 `Actor` 생성에 성공하면(blueprint·API·`ak shell` 실험) delegation 교환으로 바꾸고 `AUTH_ACTOR_SUB`를 설정해 `act.sub`를 검증한다. 이때 `sub`는 대상 provider의 Subject mode(기본 hashed user id)를 따르므로 provider `sub_mode`를 명시해야 한다.
- **옵션 B**: 교환이 `invalid_grant`(`actor_not_controlled`)면 기본 가정 그대로 간다.
- **실측(사용자 동석)**: T081 착수 시 — OSS 인스턴스에서 Actor 생성 시도 → BFF client-credentials 토큰을 `actor_token`으로 교환 → 응답에 `act`가 있으면 A, `invalid_grant`면 B. 교환 응답 캡처를 증거로 `report.md`에 남긴다.
- 코드는 어느 쪽이든 바뀌지 않는다(`AUTH_ACTOR_SUB` 유무로 갈린다). Enterprise 도입 시 `Agent`는 parent user에 묶이므로 "전 사용자를 대행하는 BFF actor"에는 parentless `Actor`가 필요하다는 조건도 ADR 0006에 기록한다.

## 엔드포인트

| 메서드·경로 | 인증 | 동작 | 응답 |
|---|---|---|---|
| `GET /healthz` | 없음 | liveness: 프로세스만(외부 의존 조회 없음) | 200 `{ status: "ok", version, git_sha }` |
| `GET /ready` | 없음 | readiness: **DB만**(`SELECT 1`, app role). Dragonfly·Kafka는 보지 않는다(outbox·fail-closed가 그 장애를 흡수하므로 pod를 내리지 않음) | 200 / 503 `not_ready` |
| `GET /health` | 없음(Access 뒤; svc DNS는 면제) | 상세: `{ status, checks: { db, dragonfly, kafka_producer } }` 항목마다 `ok`·`fail` + 지연 ms. **항상 200** | 200 |
| `GET /session/check?sub&iat&sid` | Access 서비스 토큰(BFF, `ACCESS_AUD_M2M`) — Access 전용 경로(위 구현 규약) | 거부 목록 조회만. DB 접근 없음. 쿼리 `sub`(필수 문자열) · `iat`(필수 정수 epoch 초) · `sid`(선택). **`active` = `revoked:sub:{sub}` 값 > `iat`가 아니고, `sid`가 있으면 `revoked:sid:{sid}`도 없음** — 값이 `iat`와 같으면 active(미들웨어 4단계와 같은 "초과일 때만 폐기" 비교). 응답 `nbf`는 `revoked:sub:{sub}` 키가 있을 때만 그 값(정수)으로 싣는다(active여도 싣는다 · T066 보정 2026-11-03). 쿼리 검증 실패 → 400 `validation_error`. Dragonfly 실패 → 503 `denylist_unavailable`(0.2 s · 재시도 0) | 200 `{ active: boolean, nbf?: number }` / 400 / 503 |
| `POST /sessions/revoke` | Bearer(사용자 본인, `aud=identity-admin`) 또는 관리자(`platform-admin` 그룹) + §호출자 식별 | body `{ sub?: string, sid?: string, all_devices: boolean, reason: "logout"\|"logout_all"\|"admin" }`. 본인은 `sub` 생략(토큰의 sub · 토큰과 같은 `sub`를 적어도 본인 호출). **`tenant_id` 결정**: 본인 호출은 토큰 클레임, **관리자 호출(다른 `sub` 지정)은 `TenantMembership`에서 그 `sub`로 조회**한다 — 없으면 400 `validation_error`. **폐기 범위(T066 보정 2026-11-03 · 한 행 = 한 키 — data-model §3)**: `all_devices: true` → `sid` NULL 행 + `revoked:sub:{sub}` = `nbf`(본문 `sid`는 쓰지 않는다) / `false` → `sid` 행(본문 `sid`, 없으면 본인 호출의 토큰 `sid` 클레임 · 둘 다 없으면 400 `validation_error`) + `revoked:sid:{sid}` = `1`. **`nbf` = 처리 시각의 epoch 초 내림 + 1**(같은 초에 발급된 토큰 — 이 요청을 부른 토큰 포함 — 도 `nbf > iat`로 거부된다) · `expires_at = nbf + 330 s`. 트랜잭션(app role, 등급 B 테이블): `session_revocation_log` INSERT + `publish(..., tenant_id=<결정값>)`(관리자 호출의 대상 테넌트가 요청의 테넌트 컨텍스트와 다르면 컨텍스트와 인자 충돌이 `OutboxUsageError`이므로 — contracts/events.md — 뷰가 같은 트랜잭션 안에서 컨텍스트를 대상 테넌트로 다시 설정하거나 비운 뒤 publish한다) → 커밋 후 Dragonfly `SET … EX 330` → Authentik revoke API(서비스 계정 `identity-admin` 토큰, svc DNS; 실패해도 거부 목록은 유효, Celery 5 s × 3회 지수 백오프 최대 5분 — **요청 처리 중에는 Authentik을 부르지 않는다**: 커밋 뒤 비동기 위임만). **dev는 Authentik revoke 호출을 설정 플래그(`AUTHENTIK_WRITES_ENABLED=false`)로 비활성**(시도하지 않고 로그만 — dev 서비스 계정 `identity-admin-ro`는 read만, data-model §9; 거부 목록·로그 기록은 dev도 동일). 처리마다 `session_revocations_total{reason}` +1. 폐기 3경로 E2E·SC-003 측정은 **prod 체인에서만**(T085; dev 로그아웃 검증은 denylist 401·로컬 세션 삭제까지) | 202 `{ id(로그 행 uuid), nbf(정수 epoch 초), expires_at(ISO 8601 UTC) }` / 400 / 403 |
| `POST /webhooks/authentik` | `X-Authentik-Signature: sha256=<hex>` = HMAC-SHA256(비밀 `kv/{env}/authentik/webhooks/identity-admin`, **본문 JSON의 정규형** — 아래 §웹훅 서명 규약) + 본문 `pk` · `created`(ISO 8601 · tz 필수) 시각이 서버 시각 ±5분 | Bearer·Access **면제 목록**에 명시된 유일한 업무 경로(svc DNS로만 도달, m2m Ingress에 없음). Authentik notification webhook — 본문 `action`이 `logout`·`session_deleted`면 `/sessions/revoke`와 같은 트랜잭션으로 처리(reason `authentik_webhook` · **항상 사용자 단위**: `sid` NULL 행 + `revoked:sub:{sub}` = `nbf` — 본문 `sid`는 쓰지 않는다 · 아래 §웹훅 서명 규약). **테넌트 컨텍스트가 없으므로 `tenant_id`는 본문의 `sub`로 `TenantMembership`을 조회해 얻고**(없으면 400 `validation_error`), `publish(..., tenant_id=…)`에 명시적으로 넘긴다. 멱등: 이벤트 `pk`를 같은 트랜잭션에서 `session_revocation_log.event_pk`(unique)로 저장하고, 재전송은 200 no-op(행·이벤트·키·지표 변화 0). 그 밖의 `action` 문자열(예: `login`)은 200 no-op(무시 · DB·Dragonfly 변화 0), `action`이 없거나 문자열이 아니면 400 `validation_error`(T066 보정 2026-11-03). 커밋 뒤 Dragonfly SET이 실패해도 202(DB가 정본 — 30 s 재적용이 키를 되살린다). 서명 없음/틀림/시각 밖 → 401 `webhook_signature_invalid` | 202 / 200 / 401 / 400 |
| `GET /tenants/me` | Bearer | app role로 **등급 B 테이블**(`tenant`, `tenant_membership`)만 읽는다 — RLS가 없으므로 토큰의 `sub`·`tenant_id`로 명시 필터(둘 다 일치하는 멤버십만 — 다른 테넌트의 행은 0건). SP-1 가정: 사용자당 테넌트 1. 멤버십이 없으면 **404 `not_found`**(data-model §2 · T066 보정 2026-11-03) | 200 `{ tenant: { id, slug, display_name, status }, role }` / 404 |

### 웹훅 서명 규약 (`django_common.auth.verify_authentik_webhook` · T062 보정 2026-11-02)

- 헤더 `X-Authentik-Signature: sha256=<hex 소문자>` — `hex = HMAC-SHA256(secret, canonical)` · `canonical = json.dumps(body_obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()`. pod는 수신 본문을 `json.loads`한 뒤 같은 규칙으로 다시 직렬화해 `hmac.compare_digest`로 비교한다. 본문의 키 순서·공백은 서명에 영향이 없고, 값 하나가 바뀌면 서명이 깨진다(본문 전체가 서명에 묶인다).
- 본문은 JSON 객체이고 `pk`(비어 있지 않은 문자열 — 멱등 키 · 재전송 200 no-op · 저장은 pod) · `created`(ISO 8601 · tz 오프셋 필수)를 가진다. `|now − created| > 300 s` → 거부. **업무 필드(T066 보정 2026-11-03 · T081 매핑이 만든다)**: `sub`(문자열 · 필수 — `TenantMembership` 조회 키 · 없거나 문자열이 아니면 400 `validation_error`) · `action`(`logout` · `session_deleted`면 폐기 — 둘 다 reason `authentik_webhook`; 그 밖의 문자열은 200 no-op) · `nbf`(정수 epoch 초 · 선택 — 없으면 `/sessions/revoke`와 같은 규칙: 수신 시각 epoch 초 내림 + 1 · 있는데 정수가 아니면(bool · 실수 · 문자열) 400 `validation_error` — T066 r1 보정). 본문에 `sid`가 있어도 쓰지 않는다 — Authentik 이벤트 문맥이 토큰의 `sid` 클레임과 같은 값을 준다는 보장이 없어 웹훅 폐기는 항상 사용자 단위다(fail-safe: 그 사용자의 기존 토큰 전부 거부 — 다른 기기까지 로그아웃되는 것은 SP-1에서 받아들인다). 멱등 저장은 `pk` 단위이며(`session_revocation_log.event_pk` unique) 보존 기간은 로그 보존(`expires_at + 30 d`)이라 재전송 창(±5분)의 2배 이상이다.
- 거부 사유는 모두 401 `webhook_signature_invalid`: 헤더 없음 · `sha256=` 형식 아님 · 불일치 · 본문이 JSON 객체가 아님 · `pk`/`created` 없음 · `created` 파싱 불가·tz 없음·±5분 밖. 서명 검증 뒤 뷰가 `sub`로 `TenantMembership`을 못 찾으면 400(표 참조).
- **송신 측 근거(authentik `events/models.py` `NotificationTransport.send_webhook`, 2026-11-02 확인)**: `webhook_mapping_body`·`webhook_mapping_headers`를 각각 `evaluate(user, request=None, notification)`으로 평가하고 `post(url, json=body, headers=headers)`로 보낸다. 헤더 매핑은 **전송 본문을 받지 못하므로** "원시 본문 바이트의 HMAC"은 만들 수 없다 → 두 매핑이 `notification.event`에서 같은 dict를 만들고 헤더 매핑이 그 정규형의 HMAC을 계산한다(표현식 globals에 builtins 제한이 없어 `import hmac, hashlib, json, os` 가능 · 비밀은 authentik worker env에서 읽는다 — ESO `vault-data` 경로 `kv/{env}/authentik/webhooks/*`, 환경변수 이름은 T081이 정한다).
- **VD-T062-1(검증 후 결정)**: 기본 = 위 규약. T081에서 매핑 두 개로 실제 서명이 pod 검증을 통과하는지 실측한다. 실패하면 옵션 B(정적 공유 비밀 헤더 상수 시간 비교)를 헬퍼의 두 번째 모드로 추가하고 이 절·data-model §9를 고친다.

## 이벤트(발행)

| 토픽 | 트리거 | data |
|---|---|---|
| `identity-admin.session.revoked` | `/sessions/revoke`, 웹훅 | `{ sub, sid, nbf, reason }` — 키 4개가 늘 있다(`sid`는 행의 `sid` · 사용자 단위면 `null` — data-model §3 · T066 r1 보정; 스키마는 소비자 호환을 위해 `sid`를 required로 두지 않는다 — contracts/events.md) |
| `identity-admin.user.registered` | Authentik 웹훅 `user_write`(신규) — SP-2 | `{ sub, email_hash, tenant_id, role }` |
| `identity-admin.tenant.created` | SP-2 | `{ tenant_id, slug }` |

## 주기 작업 (Celery beat, identity-admin 전용)

| 작업 | 주기 | 내용 |
|---|---|---|
| 거부 목록 **무조건 재적용** `identity_admin.tasks.reconcile_denylist` | 30 s | `session_revocation_log`에서 `expires_at > now()`인 행을 **조건 없이 전부** Dragonfly에 다시 SET(남은 TTL = `expires_at - now()` 초 내림, 멱등 — 이미 있는 키도 값·TTL을 덮어쓴다 · `EXISTS`로 건너뛰지 않는다 · 키는 data-model §3의 "한 행 = 한 키" 규칙). 센티널 키(`denylist:epoch`)는 쓰지 않는다 — contracts/denylist.md. 기동 시에도 1회 — Celery `beat_init` 신호에서 같은 함수를 **같은 프로세스에서 동기로** 1회 실행한다(브로커 경유 아님 · 실패는 로그만 남기고 beat 기동을 막지 않는다 · T066 보정 2026-11-03) |
| `reconcile_authentik_sessions` `identity_admin.tasks.reconcile_authentik_sessions` | 일 1회 | Authentik 활성 세션 API(서비스 계정 토큰, svc DNS)와 대조해 유실 웹훅을 보정. dev는 웹훅 transport가 있어도 이 보정이 안전망이다. **dev 각주**: 대조(read)는 dev도 수행하되(`identity-admin-ro` 토큰), 보정 **쓰기 호출은 설정 플래그로 비활성**(로그만 — data-model §9) |
| `session_revocation_log` purge `identity_admin.tasks.purge_session_revocation_log` | 일 1회 | `expires_at + 30 d < now()` 행 삭제(경계 시각은 DB `now()`) |
| `outbox` dead purge `identity_admin.tasks.purge_dead_outbox`(템플릿 기본 작업 `<pod_snake>.tasks.purge_dead_outbox`) | 일 1회 | `dead_at + 30 d < now()` 행 삭제(contracts/events.md · `dead_at IS NULL` 행은 대상 아님) |
| Authentik revoke 재시도 | 이벤트 | 5 s × 3회 지수 백오프(최대 5분) |

- Celery 앱은 `identity_admin.celery.app`이고 beat 항목은 `app.conf.beat_schedule`에서 **작업 이름**으로 찾는다(항목 키 이름은 자유). 주기 표기: 30 s = 정확히 30초 간격(`timedelta(seconds=30)` · 숫자 30 · `schedule(30)`), 일 1회 = 24시간 간격 또는 하루 한 번 발화하는 `crontab`(분·시 각 1개 값 · 날짜 필드 전부 `*`). 작업 본체는 `app.tasks[<이름>].apply()`로 같은 프로세스에서 돌릴 수 있어야 한다(브로커 없이 — T066 시험).

## identity-admin 전용 설정 (T066 보정 2026-11-03)

| 설정(env) | 원천 | 기본값 | 규칙 |
|---|---|---|---|
| `AUTHENTIK_API_URL` | ConfigMap(선택) | `http://authentik-server.identity.svc:9000` | 관리 API·revoke·세션 API의 base URL(뒤에 `/api/v3/…`). 호스트가 `joshuatech.dev`이거나 그 하위면 **기동 실패**(`ImproperlyConfigured` — pod는 공개 호스트를 부르지 않는다 · FR-046) |
| `AUTHENTIK_API_TOKEN` | `kv/{env}/authentik/identity-admin` `api_token` | 없음(필수 · 비밀 · 빈 값도 기동 실패) | `Authorization: Bearer`. 주체: prod 서비스 계정 `identity-admin` · dev `identity-admin-ro`(read만 — data-model §9) |
| `AUTHENTIK_WEBHOOK_SECRET` | `kv/{env}/authentik/webhooks/identity-admin` `secret` | 없음(필수 · 비밀 · 빈 값도 기동 실패) | 웹훅 HMAC 공유 비밀(T062 가정 이름 확정) |
| `AUTHENTIK_WRITES_ENABLED` | ConfigMap(prod `true` · dev `false`) | `false` | Authentik **쓰기** 호출(revoke · 세션 삭제 · `reconcile_authentik_sessions` 보정 · `seed_tenant`의 그룹 소속·attribute) 여부. 거짓이면 쓰기를 시도하지 않고 로그만 남긴다(읽기는 한다). 기본값이 거짓인 것은 fail-safe다(dev 토큰은 쓰기 권한이 없다) |
| `OPENFGA_API_URL` | ConfigMap(선택) | `http://openfga.identity.svc:8080` | 뒤에 `/stores/{id}/…`. 공개 호스트면 기동 실패(위와 같은 검사) |
| `OPENFGA_STORE_ID` | `kv/{env}/openfga/store_id` `store_id` | 없음(필수) | |
| `OPENFGA_PRESHARED_KEY` | `kv/{env}/openfga/preshared` `key` | 없음(필수 · 비밀 · 빈 값도 기동 실패) | `Authorization: Bearer <key>` |
| `AUTHENTIK_JWKS_URL` | `kv/{env}/authentik/identity-admin` `jwks_url` | 없음(필수) | svc DNS. 공개 호스트면 기동 실패(템플릿 공통 규칙 — contracts/pod-template.md §런타임 계약 설정 행) |
| `AUTH_ACCESS_ONLY_PATHS` · `TENANT_CONTEXT_EXEMPT_PATHS` | settings 상수 | — | 위 §인증 계층 구현 규약 |

- 설정은 요청·작업·명령 실행 시점에 `django.conf.settings`에서 읽는다(import 시점 상수 금지 — T066 시험이 설정을 바꾼다). 필수값 검사는 "있는가"만 보고 빈 문자열을 거부하지 않는다(`ADMIN_HOST`·`AUTH_ACTOR_SUB` — rules/django-pod.md §Auth). **예외 — 비밀 3개(`AUTHENTIK_API_TOKEN` · `AUTHENTIK_WEBHOOK_SECRET` · `OPENFGA_PRESHARED_KEY`)는 빈 값도 기동 실패**(`ImproperlyConfigured` — 빈 HMAC 키·빈 토큰은 누구나 만들 수 있다 · T066 r1 보정 2026-11-03).
- 기동 실패(`ImproperlyConfigured`) 메시지와 연쇄 예외에는 **설정 이름만** 싣고 값은 싣지 않는다 — pydantic `ValidationError`(`input_value`가 env 값을 되풀이한다 — `str(exc)`는 긴 표현을 앞뒤만 남기고 잘라도 마지막 값의 꼬리 조각이 실린다)는 `from None`으로 끊고, 설정 모델에 `hide_input_in_errors=True`도 둔다(rules/django-pod.md §Settings · T066 r1 보정 · r2 보정 2026-11-03).
- 비밀(`AUTHENTIK_API_TOKEN` · `AUTHENTIK_WEBHOOK_SECRET` · `OPENFGA_PRESHARED_KEY`과 DB·Dragonfly·Kafka 자격)은 `identity-admin-env` ExternalSecret(T075)이 env로 넣고, 명령 출력·응답·로그에 값이 나오지 않는다.

## 오류 슬러그

`access_required`, `invalid_token`, `session_revoked`, `denylist_unavailable`(503), `tenant_required`, `forbidden`, `validation_error`, `webhook_signature_invalid`, `not_ready`, `not_found`(404 — `/tenants/me` 멤버십 없음 · T066 보정 2026-11-03 · URL이 없는 경로의 404도 같은 슬러그 — 예: m2m 호스트의 `/admin/`), `invalid_host`(400 — `ALLOWED_HOSTS` 밖 호스트 · T066 r1 보정 2026-11-03), `internal_error`(500 — `detail` 없음 · T066 r2 보정 2026-11-03). Django 자체 400·403·404·500도 RFC 9457로 낸다(템플릿 `handler400` — 호스트 거부는 `invalid_host`, 그 밖의 `SuspiciousOperation` · `BadRequest`는 `validation_error` · `handler403` — `PermissionDenied`는 `forbidden`(T066 r3 보정) · `handler404` · `handler500` — contracts/pod-template.md §런타임 계약 오류 행 · 오류 핸들러는 요청의 urlconf에서 찾으므로 admin urlconf에도 둔다 · CSRF 실패(`CSRF_FAILURE_VIEW`)도 403 `forbidden` — T066 r4 보정). RFC 9457 `type` = `https://joshuatech.dev/problems/<slug에서 _ → ->`. 요청 검증 실패(쿼리 누락·타입 오류·enum 밖 값·JSON이 아닌 본문)는 **400 `validation_error`**(RFC 9457) — Ninja 기본 422 `{detail}`를 쓰지 않는다(T066 보정 2026-11-03 · contracts/pod-template.md §런타임 계약 오류 행).

## 타임아웃 · 재시도

| 구간 | 값 |
|---|---|
| Dragonfly `socket_timeout` | 0.2 s, fail-closed 503 |
| `/health` 전체 | ≤ 3 s(BFF pod fetch 3 s 안에 답한다) — 의존 검사는 **병렬**, 항목별 상한 DB 2 s(psycopg `connect_timeout` 하한) · Dragonfly 0.2 s · Kafka `list_topics` 1 s(T063 보정 2026-11-02) |
| PG app role | `statement_timeout 15s` · `idle_in_transaction_session_timeout 30s` |
| Kafka producer | `delivery.timeout.ms` 30000 |
| identity-admin → Authentik(revoke·세션 API) | 5 s × 3회 지수 백오프(최대 5분, Celery) |
| BFF 측(참고) | pod fetch 3 s(AbortController), 초과·연결 실패 시 BFF가 **503 `upstream_unavailable`**(504 아님); `/session/check` 캐시 2 s |

## 관측

- 로그(structlog JSON): `request_id`, `tenant_id`, `sub_hash`, `route`, `status`, `duration_ms`, `trace_id`. processor가 `authorization`·`cookie`·`x-authentik-signature`를 제거하고 쿼리스트링을 남기지 않는다.
- 메트릭: web `http_requests_total{route,status}`, `session_revocations_total{reason}`, `denylist_lookup_seconds`; relay 컨테이너(9464, `k8s.grafana.com/scrape`) `outbox_pending`, `outbox_oldest_pending_seconds`(알림 `OutboxOldestPending` > 60 s), `outbox_dead_total`.
- 트레이스: OTLP → Alloy(`monitoring`), 상류 `traceparent` 이어받음, `OTEL_TRACES_SAMPLER=parentbased_traceidratio` 0.1. span 속성은 `tenant_id` · `sub_hash`만 더하고, URL 속성(`http.url` · `http.target` · `url.full` · `url.query`)에서 쿼리스트링을 떼며, 요청 헤더는 속성으로 담지 않는다(`OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST` 미사용 — 계측 기본값은 `http.url`에 쿼리까지 넣고 AWS/GCS 서명 파라미터만 가린다 · T063 보정 2026-11-02).
- Sentry: errors only, `send_default_pii=False`, `before_send`로 `Authorization`·`Cookie`·`CF-Access-*` 제거.
