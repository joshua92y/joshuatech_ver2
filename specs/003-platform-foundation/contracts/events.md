# Contract: 이벤트 (Kafka · CloudEvents · outbox)

## 토픽 규약

- 이름: prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`. pod 이름은 kebab-case, entity·event는 단수 소문자. DLQ `<pod>.dlq`.
- 파티션 3, 키 = `tenantid`(UUID 문자열). 같은 테넌트의 이벤트는 순서를 보존한다.
- 보존 7일. 소비자는 7일 안에 따라잡지 못하면 재색인/재투영으로 복구한다(원천은 각 pod DB).
- 쓰기 권한: 토픽 접두 `<pod>.`의 소유 pod만. 다른 pod가 대신 발행하지 않는다.

## 봉투 (CloudEvents 1.0, JSON)

```json
{
  "specversion": "1.0",
  "id": "01J8QK3Q9S8ZQ4V7H2M1X0N5AB",
  "source": "identity-admin",
  "type": "identity-admin.session.revoked",
  "time": "2026-09-01T03:21:07.123Z",
  "subject": "user:9f2c…",
  "tenantid": "018f6c2e-…",
  "datacontenttype": "application/json",
  "data": { "sub": "9f2c…", "sid": null, "nbf": 1756696867, "reason": "logout_all" }
}
```

- `id` = outbox 행 id(ULID). 소비자는 `(consumer_group, id)`를 저장해 멱등 처리한다.
- Kafka 헤더: `ce_type`, `ce_source`, `ce_id`, `content-type: application/cloudevents+json`(structured mode).
- `tenantid`는 확장 속성(CloudEvents 확장 규칙: 소문자 영숫자).

## SP-1에서 정의하는 스키마 (`packages/events/schemas/`)

| 토픽 | subject | data | 발행 | 소비(예정) |
|---|---|---|---|---|
| `identity-admin.session.revoked` | `user:<sub>` | `sub`(string, req) · `sid`(string\|null) · `nbf`(int epoch, req) · `reason`(enum logout·logout_all·admin·authentik_webhook·tenant_suspended, req) | identity-admin | 모든 pod(선택: 거부 목록 재적용), insights(SP-3) |
| `identity-admin.user.registered` | `user:<sub>` | `sub` · `email_hash`(sha256) · `tenant_id` · `role` · `registered_at` | identity-admin(SP-2) | portfolio-core·engagement(투영), notification(환영 메일) |
| `identity-admin.tenant.created` | `tenant:<id>` | `tenant_id` · `slug` · `display_name` | identity-admin(SP-2) | 모든 pod(테넌트 시드) |
| `portfolio-core.note.published` | `note:<slug>` | `slug` · `lang` · `title` · `tags[]` · `published_at` · `change` | portfolio-core(SP-2, CI notes-sync) | search(색인), notification(구독 알림), insights |
| `engagement.comment.created` | `comment:<id>` | `comment_id` · `target`(`note:<slug>` 등) · `author_sub` · `created_at` · `body_excerpt`(≤ 200자) | engagement(SP-2) | notification, insights |
| `media.object.ready` | `media:<id>` | `media_id` · `owner_sub` · `kind`(image·file) · `variants[]`(name·url) · `bytes` | media(SP-2) | portfolio-core·engagement(첨부 연결) |

## 호환성 규칙 (CI `packages/events` 검사)

- 허용: 선택 필드 추가, enum 값 추가(소비자는 알 수 없는 값을 무시).
- 금지: 필드 삭제·이름 변경·타입 변경, `required` 추가, enum 값 삭제. 필요하면 새 토픽 `…v2`를 만들고 둘 다 발행하는 기간을 둔다.
- 검사 방식: `main`의 스키마와 PR 스키마를 필드 단위로 비교(스크립트 `packages/events/scripts/check-compat.mjs`), 위반 시 실패.

## outbox 릴레이 (django-common)

- 실행: pod당 `manage.py outbox_relay` 프로세스 1개(Deployment 별도 컨테이너 또는 사이드카), 폴링 500 ms, 배치 100.
- 트랜잭션 규칙: outbox INSERT는 도메인 쓰기와 같은 `transaction.atomic()` 안에서만. 라이브러리는 autocommit 상태의 INSERT를 예외로 막는다.
- 실패: 프로듀서 오류 시 `attempts += 1`, `last_error` 기록, 지수 백오프(최대 5분). `attempts ≥ 10`이면 메트릭 `outbox_publish_failures_total` + 알림, 행 유지(수동 개입).
- 관측: `outbox_pending` gauge, `outbox_relay_lag_seconds`(가장 오래된 pending의 나이).

## 소비자 규칙

- consumer group `<pod>-<purpose>`(예: `notification-note-published`). 오프셋 커밋은 처리 트랜잭션 커밋 뒤.
- 처리 실패 3회 → DLQ로 이동(원본 봉투 + `error` 헤더). DLQ 재처리는 수동 command.
- 스키마 검증: 소비자는 `packages/events`의 스키마로 `data`를 검증하고, 실패는 DLQ.
