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
- `tenantid`는 확장 속성(CloudEvents 확장 규칙: 소문자 영숫자). 값은 항상 테넌트 UUID(slug 금지). 사용자 단위 이벤트의 `tenantid`는 그 사용자의 테넌트(SP-1 가정: 사용자당 테넌트 1).

## SP-1에서 정의하는 스키마 (`packages/events/schemas/`)

| 토픽 | subject | data | 발행 | 소비(예정) |
|---|---|---|---|---|
| `identity-admin.session.revoked` | `user:<sub>` | `sub`(string, req) · `sid`(string\|null) · `nbf`(int epoch, req) · `reason`(enum logout·logout_all·admin·authentik_webhook·tenant_suspended, req) | identity-admin | insights(SP-3). 거부 목록 재적용에는 쓰지 않는다 — pod는 Dragonfly를 직접 조회하고, 재적용은 identity-admin의 30 s 무조건 재적용(contracts/denylist.md) |
| `identity-admin.user.registered` | `user:<sub>` | `sub` · `email_hash`(sha256) · `tenant_id` · `role` · `registered_at` | identity-admin(SP-2) | portfolio-core·engagement(투영), notification(환영 메일) |
| `identity-admin.tenant.created` | `tenant:<id>` | `tenant_id` · `slug` · `display_name` | identity-admin(SP-2) | 모든 pod(테넌트 시드) |
| `portfolio-core.note.published` | `note:<slug>` | `slug` · `lang` · `title` · `tags[]` · `published_at` · `change` | portfolio-core(SP-2, CI notes-sync) | search(색인), notification(구독 알림), insights |
| `engagement.comment.created` | `comment:<id>` | `comment_id` · `target`(`note:<slug>` 등) · `author_sub` · `created_at` · `body_excerpt`(≤ 200자) | engagement(SP-2) | notification, insights |
| `media.object.ready` | `media:<id>` | `media_id` · `owner_sub` · `kind`(image·file) · `variants[]`(name·url) · `bytes` | media(SP-2) | portfolio-core·engagement(첨부 연결) |

## 호환성 규칙 (CI `packages/events` 검사)

- 허용: 선택 필드 추가, enum 값 추가(소비자는 알 수 없는 값을 무시).
- 금지: 필드 삭제·이름 변경·타입 변경, `required` 추가, enum 값 삭제. 필요하면 새 토픽 `…v2`를 만들고 둘 다 발행하는 기간을 둔다.
- 검사 방식: `main`의 스키마와 PR 스키마를 필드 단위로 비교(스크립트 `packages/events/scripts/check-compat.mjs`), 위반 시 실패.

## 발행 API (`django_common.outbox.publish`)

```python
def publish(topic: str, subject: str, data: dict, *, tenant_id: UUID | str | None = None) -> OutboxEvent: ...
```

- `tenant_id`는 **키워드 전용 선택 인자**다. 생략하면 요청 트랜잭션의 테넌트 컨텍스트(`app.tenant_id`)에서 읽는다. 컨텍스트가 있는 요청 경로(A 등급 도메인 쓰기)는 인자를 넘기지 않고, 컨텍스트가 없는 경로(웹훅·관리자 revoke·기동 시 작업 — 전부 등급 B 테이블 위에서 돈다)는 **명시적으로 넘긴다**.
- **컨텍스트도 없고 인자도 없으면 `OutboxUsageError`** 를 던진다(`tenantid` 없는 봉투가 Kafka로 나가는 것을 막는다). `transaction.atomic()` 밖에서 호출해도 같은 예외다.
- 확정된 `tenant_id`가 봉투의 `tenantid`와 outbox 행의 `partition_key`가 된다.
- 웹훅·관리자 revoke가 넘길 `tenant_id`는 `TenantMembership`에서 토큰·본문의 `sub`로 조회한 값이다(없으면 400 — contracts/identity-admin-api.md).

## outbox 릴레이 (django-common)

- 실행: pod당 `manage.py outbox_relay` 프로세스 1개(Deployment의 `relay` 컨테이너, web과 같은 pod), 폴링 500 ms, 배치 100. **app role**로 실행하며 `outbox` 테이블은 등급 B(pod 전역, RLS 미적용)라 모든 테넌트의 행을 읽는다(T061: 테넌트 A·B 행이 모두 릴레이되고 각 `tenantid`·파티션 키가 맞음).
- **선택 조건**: `WHERE dead_at IS NULL ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 100`. dead 행은 다시 집지 않는다(재발행 폭주 방지) — 재처리는 `dead_at`을 비우는 수동 command로만.
- 트랜잭션 규칙: outbox INSERT는 도메인 쓰기와 같은 `transaction.atomic()` 안에서만. 라이브러리는 autocommit 상태의 INSERT를 `OutboxUsageError`로 막는다.
- 프로듀서: confluent-kafka idempotent producer, SASL_SSL SCRAM-SHA-512, `delivery.timeout.ms` 30000.
- 실패: 프로듀서 오류 시 `attempts += 1`, `last_error` 기록, 지수 백오프(최대 5분). **`attempts ≥ max_attempts(10)`이면 원본 봉투를 `<pod>.dlq`로 발행(+ `error` 헤더)하고 `dead_at`을 기록**한다(행 유지, 재처리는 수동 command).
- **dead 행 purge**: 일 1회 `dead_at + 30 d < now()`인 행을 삭제한다(Celery beat). `outbox` 테이블이 무한히 자라지 않게 하는 유일한 경로이며, 30일은 수동 재처리 여유다.
- 관측(relay 컨테이너 `prometheus_client` 9464, `k8s.grafana.com/scrape: "true"`): `outbox_pending`(gauge, `dead_at IS NULL`만 셈), `outbox_oldest_pending_seconds`(가장 오래된 pending의 나이, 알림 `OutboxOldestPending` > 60 s), `outbox_dead_total`(counter).

## 소비자 규칙

- consumer group `<pod>-<purpose>`(예: `notification-note-published`). 오프셋 커밋은 처리 트랜잭션 커밋 뒤.
- 처리 실패 3회 → DLQ로 이동(원본 봉투 + `error` 헤더). DLQ 재처리는 수동 command.
- 스키마 검증: 소비자는 `packages/events`의 스키마로 `data`를 검증하고, 실패는 DLQ.
- 컨슈머 그룹 lag 지표는 SP-2(`kafkaExporter`); SP-1 알림은 outbox pending·oldest age + 브로커 under-replicated만.
