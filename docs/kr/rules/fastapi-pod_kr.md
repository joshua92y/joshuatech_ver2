> 번역본(편의용). 정본은 영어 원본 `.claude/rules/fastapi-pod.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "templates/fastapi-pod/**"
  - "packages/fastapi-common/**"
```

# Rules for FastAPI pods (`templates/fastapi-pod/`, `packages/fastapi-common/`)

SP-3 대비: 이 경로들은 아직 존재하지 않는다. 위 glob은 미래의 FastAPI pod 템플릿과 그 공유 패키지(Django 배치 `templates/django-pod/` + `packages/django-common/`를 미러링)를 위해 예약된 것이다. 첫 FastAPI pod가 `apps/<pod>` 아래에 스캐폴딩되면 그 경로를 여기에 추가하고 `django-pod.md`에 예외(carve-out)를 기록한다 — 그때까지는 `django-pod.md`가 모든 `apps/<pod>`를 관장한다.

## Same contracts as Django pods

FastAPI pod는 Django pod의 드롭인(drop-in) 동급 구성원이다. 호출자나 운영자가 관찰할 수 있는 모든 것은 `contracts/pod-template.md`와 동일해야 한다:

- 테이블 등급: A(테넌트 범위, `tenant_id` UUID NOT NULL, FORCE RLS + `tenant_isolation` 정책)와 B(pod 전역 허용 목록). `check_rls` 상당의 검사가 CI와 기동 시에 돈다.
- Outbox 의미론: DB 트랜잭션 안에서만 `publish(topic, subject, data, *, tenant_id=None)`; 테넌트 컨텍스트도 인자도 없으면 → 사용 오류; 릴레이는 `dead_at IS NULL`을 선택, `max_attempts 10` → `<pod>.dlq` + `dead_at`, purge는 `dead_at + 30 d`. 엔벨로프는 `tenantid` UUID를 가진 CloudEvents 1.0이다(`contracts/events.md`).
- 인증 체인: Bearer JWT(svc DNS를 통한 JWKS, `iss` 공개 URL, `aud`/`exp`/`nbf`) + Access JWT(`aud` + `common_name`) + 거부 목록 fail-closed 503(0.2초); 헬스 엔드포인트는 예외; webhook은 HMAC + 타임스탬프 ±5분 + 멱등성 키를 쓴다.
- 헬스 3종: `/healthz`(프로세스만), `/ready`(DB만), `/health`(상세, 항상 200); Django 템플릿과 같은 프로브 배선.
- 설정: pydantic-settings를 통한 12-factor; 시크릿은 env(ESO `<pod>-env`)에서만; 비밀이 아닌 값은 ConfigMap에서; owner DB URL은 migrate Job에만.
- 마이그레이션: owner 역할 전용 PreSync Job(CONNECT 경계 SQL 먼저); expand → contract 2단계 규칙; RLS 정책 변경은 전용 마이그레이션으로; CI에 마이그레이션 린터 게이트.
- 로깅: `request_id tenant_id sub_hash trace_id span_id`를 가진 구조화 JSON; `authorization`/`cookie`/`x-authentik-signature` 마스킹; 쿼리 스트링 없음.
- 테스트: `django-pod.md`와 같은 6개 기본 영역(헬스, 테넌트 RLS, outbox, 인증 미들웨어, 로깅, 마이그레이션 + OpenAPI 스냅샷), 필수이며 절대 건너뛰지 않는다.
- Dragonfly: 사용자 = pod 이름, 자기 키는 전부 `<pod>:` 접두, `socket_timeout` 0.2초, 거부 목록은 `%R~revoked:*`로 읽기 전용.

## FastAPI-specific rules

- 전면 비동기(All-async): 모든 엔드포인트는 `async def`다; DB 접근은 비동기 드라이버/세션을 쓴다; 이벤트 루프 안에서 블로킹 I/O(동기 DB, `requests`, `time.sleep`)를 절대 호출하지 않는다 — 불가피한 동기 작업은 명시적으로 스레드풀로 감싼다.
- 백그라운드 작업은 taskiq를 쓴다(Celery 아님): 브로커 = 같은 `<pod>:` 키 접두를 쓰는 Dragonfly; 스케줄 잡(예: outbox dead purge)은 같은 주기와 의미론으로 taskiq 스케줄러로 옮긴다.
- 테넌트 컨텍스트 미들웨어는 라우트 실행 전에 트랜잭션을 열고 `set_config(..., true)`로 `app.tenant_id`를 설정한다(`TenantContextMiddleware`와 동일); 스트리밍 응답은 그 트랜잭션 밖에서 DB를 건드리지 않는다.
- OpenAPI 스냅샷: `django-pod.md`와 같은 갱신 절차 — 의도적 재생성, diff 검토, 원인이 된 변경과 함께 커밋.
