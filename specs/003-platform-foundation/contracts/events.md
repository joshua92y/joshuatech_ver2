# Contract: 이벤트 (Kafka · CloudEvents · outbox)

## 토픽 규약

- 이름: prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`. pod 이름은 kebab-case, entity·event는 단수 소문자. DLQ prod `<pod>.dlq` · dev `dev.<pod>.dlq`(2026-10-16 T056 정정 — KafkaUser ACL 접두가 env별이라 dev 자격으로는 `<pod>.dlq`에 쓸 수 없다 · data-model §6).
- 파티션 3, 키 = `tenantid`(UUID 문자열). 같은 테넌트의 이벤트는 순서를 보존한다.
- 보존 7일. 소비자는 7일 안에 따라잡지 못하면 재색인/재투영으로 복구한다(원천은 각 pod DB).
- 쓰기 권한: 토픽 접두(prod `<pod>.` · dev `dev.<pod>.`)의 소유 pod만. 다른 pod가 대신 발행하지 않는다.

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
- 필드 형식(T067 보정 2026-11-03 — 정본 `packages/events/schemas/_envelope.json`): `specversion` const `"1.0"` · `id` ULID `^[0-7][0-9A-HJKMNP-TV-Z]{25}$` · `source` pod 이름(kebab-case `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`) · `type` = **논리 토픽**(env 접두 없음 — dev Kafka 토픽은 `dev.` + `type`, 접두는 릴레이가 붙인다 · 점으로 나뉜 kebab-case 토큰 셋 이상 — `<pod>.<entity>.<event>`, v2 토픽은 토큰을 하나 더 쓴다) · `time` RFC 3339 date-time · `subject` `<종류>:<id>`(`^[a-z][a-z0-9-]*:.+$`) · `tenantid` 소문자 UUID(`format: uuid` + pattern) · `datacontenttype` const `"application/json"` · `data` 객체. 패턴은 JS(ajv · u 플래그)와 Python `re`(jsonschema)에서 같은 뜻인 명시 문자 클래스만 쓴다(`\d` · `\w` · `\s` 금지 — Python은 유니코드 숫자·글자까지 맞춘다).

## SP-1에서 정의하는 스키마 (`packages/events/schemas/`)

| 토픽 | subject | data | 발행 | 소비(예정) |
|---|---|---|---|---|
| `identity-admin.session.revoked` | `user:<sub>` | `sub`(string, req) · `sid`(string\|null) · `nbf`(int epoch, req) · `reason`(enum logout·logout_all·admin·authentik_webhook·tenant_suspended, req) | identity-admin | insights(SP-3). 거부 목록 재적용에는 쓰지 않는다 — pod는 Dragonfly를 직접 조회하고, 재적용은 identity-admin의 30 s 무조건 재적용(contracts/denylist.md) |
| `identity-admin.user.registered` | `user:<sub>` | `sub` · `email_hash`(sha256) · `tenant_id` · `role` · `registered_at` | identity-admin(SP-2) | portfolio-core·engagement(투영), notification(환영 메일) |
| `identity-admin.tenant.created` | `tenant:<id>` | `tenant_id` · `slug` · `display_name` | identity-admin(SP-2) | 모든 pod(테넌트 시드) |
| `portfolio-core.note.published` | `note:<slug>` | `slug` · `lang` · `title` · `tags[]` · `published_at` · `change` | portfolio-core(SP-2, CI notes-sync) | search(색인), notification(구독 알림), insights |
| `engagement.comment.created` | `comment:<id>` | `comment_id` · `target`(`note:<slug>` 등) · `author_sub` · `created_at` · `body_excerpt`(≤ 200자) | engagement(SP-2) | notification, insights |
| `media.object.ready` | `media:<id>` | `media_id` · `owner_sub` · `kind`(image·file) · `variants[]`(name·url) · `bytes` | media(SP-2) | portfolio-core·engagement(첨부 연결) |

### 필드 형식 · 필수 (T067 확정 2026-11-03)

정본은 `packages/events/schemas/<토픽>.json`이다(이 표와 어긋나면 표를 먼저 고친다). 필수 집합은 main에 들어간 뒤로 바꿀 수 없다(아래 §호환성 규칙 — 추가 · 제거 모두 금지). 모든 속성은 `type`을 명시한다(나중에 `type`을 더하는 것도 타입 변경이다). 공통 형식: UUID = 소문자 UUID 문자열 · 시각 = RFC 3339 date-time · 문자열 = 비지 않은 문자열.

| 토픽 | 필수 | 선택 | 형식 |
|---|---|---|---|
| `identity-admin.session.revoked` | `sub` · `nbf` · `reason` | `sid` | `sub` 문자열 · `sid` 비지 않은 문자열 또는 null · `nbf` 정수 ≥ 0 · `reason` enum(위 표의 5값) |
| `identity-admin.user.registered` | `sub` · `tenant_id` · `role` · `registered_at` | `email_hash` | `sub` 문자열 · `email_hash` sha256 소문자 hex 64자(메일이 없는 IdP 사용자가 있다) · `tenant_id` UUID · `role` enum `owner` · `member`(`admin`은 SP-2에 enum 값 추가로) · `registered_at` 시각 |
| `identity-admin.tenant.created` | `tenant_id` · `slug` · `display_name` | — | `tenant_id` UUID · `slug` `^[a-z0-9][a-z0-9-]{1,30}$`(data-model §1) · `display_name` 1–80자 |
| `portfolio-core.note.published` | `slug` · `lang` · `title` · `tags` · `published_at` | `change` | `slug` kebab-case(`^[a-z0-9]+(-[a-z0-9]+)*$`) · `lang` enum `ko` · `en` · `ja` · `title` 문자열 · `tags` 비지 않은 문자열의 배열(빈 배열 허용) · `published_at` 시각 · `change` `^[0-9]{3}-[a-z0-9-]+$`(study만 — data-model §11) |
| `engagement.comment.created` | 다섯 필드 전부 | — | `comment_id` · `author_sub` 문자열 · `target` `<종류>:<id>` · `created_at` 시각 · `body_excerpt` 200자 이하(코드 포인트 — ajv · Python 같은 셈) |
| `media.object.ready` | 다섯 필드 전부 | — | `media_id` · `owner_sub` 문자열 · `kind` enum `image` · `file` · `variants` 항목 `{name 문자열, url 절대 URI}`(둘 다 필수 · 빈 배열 허용) · `bytes` 정수 ≥ 0 |

- SP-2 토픽의 id(`comment_id` · `media_id`)와 sub류에는 형식을 두지 않는다 — 생산 pod의 id 체계가 정해지지 않았고, 형식을 나중에 두거나 풀면 그 형식에 기댄 생산자 · 소비자가 깨진다. 표본 sub가 `9f2c-test` 꼴이다(T061 · T064).
- Python 소비자(jsonschema 4.26)는 `uuid`를 자체 검사하지만 `date-time` · `uri`는 추가 패키지(`rfc3339-validator` · `rfc3987`)가 없으면 검사하지 않는다(통과로 처리) — SP-2 소비자 도우미가 정한다. UUID는 pattern이 함께 있어 형식 검사 없이도 걸린다.

## 호환성 규칙 (CI `packages/events` 검사)

- 허용: 선택 필드 추가, enum 값 추가(소비자는 알 수 없는 값을 무시). 그래서 토픽 data 스키마와 `_envelope.json`은 **`additionalProperties: false`를 두지 않는다** — 소비자는 알 수 없는 속성을 무시한다(enum 미지 값 무시와 같은 원칙). 닫힌 스키마면 생산자가 허용된 선택 필드를 추가해 배포한 순간 옛 스키마를 가진 소비자(pod별 배포)가 모든 이벤트를 DLQ로 보내고, 봉투는 CloudEvents 확장 속성(예: `traceparent`)을 받을 수 없다(T064 리뷰 A-1 · 2026-11-02).
- 금지: 필드 삭제·이름 변경·타입 변경(`type`의 집합이 달라지면 전부 — `string` → `["string", "null"]`도 소비자에게는 타입 변경), `required` 추가, **`required` 제거**(존재를 전제한 소비자가 깨진다 — T064 보정 2026-11-02), enum 값 삭제, 스키마 파일 삭제(토픽 제거). 필요하면 새 토픽 `…v2`를 만들고 둘 다 발행하는 기간을 둔다. 메타데이터(`title` · `description` · `examples` · `x-version` · `$comment`)만 바뀌는 것은 위반이 아니다.
- 검사 방식: `main`의 스키마와 PR 스키마를 필드 단위로(중첩 객체 · 배열 `items` 포함) 비교(스크립트 `packages/events/scripts/check-compat.mjs` — CLI `--base <dir> --head <dir>` · 종료 코드 0 위반 없음 / 1 위반 / 2 사용·입출력 오류 · 위반은 파일 · JSON 포인터 경로 · 종류를 전부 보고하고 첫 위반에서 멈추지 않는다), 위반 시 실패. `_envelope.json`도 같은 규칙을 받는다.
- **CI 기준과 검사기**(T067 보정 2026-11-03): 기준은 PR이면 merge 커밋의 첫째 부모(둘째 부모가 PR head인지 확인), push면 `before`(0이면 빈 기준 — 전부 추가). 검사기는 **기준 커밋의 `check-compat.mjs`**를 쓰고, 기준에 검사기가 없을 때만 이 변경의 것을 쓴다(부트스트랩) — PR이 검사기를 약하게 고쳐 같은 PR의 스키마 변경을 통과시키지 못하게 한다. 그래서 검사기의 CLI 경로는 Node 내장 모듈만 쓰고 ajv는 `validateEvent`가 처음 부를 때 지연 로드한다(CI가 기준 쪽 사본을 패키지 밖에서 돌린다). PR 브랜치 안의 스키마 디렉터리 삭제는 전부 `schema-removed`다. 판정 규칙의 정본은 `scripts/ci/events-compat.sh` 머리 주석이다. 같은 PR이 워크플로 파일(`.github/workflows/ci.yml`) 자체를 바꾸면 그 PR에서는 바뀐 워크플로가 돈다 — 그 변경은 리뷰가 막는다(검사기 신뢰 모델의 한계).
- **검사기가 다루는 키**(T067 보정): 구조 키 `type` · `properties` · `required` · `items` · `enum` · `const` · `additionalProperties`(스키마일 때 재귀)를 비교하고, 값 제약 `format` · `pattern` · `minLength` · `maxLength` · `minimum` · `maximum` · `exclusiveMinimum` · `exclusiveMaximum` · `minItems` · `maxItems` · `uniqueItems`와 메타데이터(`$schema` · `$id` · `$comment` · `title` · `description` · `examples` · `default` · `deprecated` · `readOnly` · `writeOnly` · `x-*`)는 그대로 둔다. 이 밖의 키(`$ref` · `$defs` · `allOf` · `anyOf` · `oneOf` · `not` · `if`/`then`/`else` · `prefixItems` · `patternProperties` · `dependent*` · `unevaluated*` 등)는 쓰지 않는다 — 쓰면 검사기가 2로 끝난다(비교하지 못한 변경을 통과로 두지 않는다 · 쓰려면 검사기를 먼저 넓힌다).
- **값 제약**(T067 보정): `const` 값이 바뀌는 것은 enum 값 삭제와 같다(`enum-removed`). `format` · `pattern` · 길이 · 범위는 바꾸지 않는다 — 검사기가 보지 못하므로 리뷰가 막는다(강화는 생산자를, 완화는 그 값에 기댄 소비자를 깨뜨린다 · 바꾸려면 새 토픽 v2).
- **enum 값 추가의 배포 순서**(T067 보정): 그 토픽의 소비자가 새 스키마를 담은 빌드로 먼저 배포되고 생산자는 그다음에 새 값을 보낸다 — 소비자는 data를 스키마로 검증하므로 옛 스키마의 enum은 새 값을 거부해 DLQ로 보낸다("알 수 없는 enum 값 무시"는 검증을 통과한 뒤의 업무 처리 규칙이다). 소비자 도우미가 enum 위반만 따로 다룰지는 SP-2가 정한다.

## 발행 API (`django_common.outbox.publish`)

```python
def publish(topic: str, subject: str, data: dict, *, tenant_id: UUID | str | None = None) -> OutboxEvent: ...
```

- `tenant_id`는 **키워드 전용 선택 인자**다. 생략하면 요청 트랜잭션의 테넌트 컨텍스트(`app.tenant_id`)에서 읽는다. 컨텍스트가 있는 요청 경로(A 등급 도메인 쓰기)는 인자를 넘기지 않고, 컨텍스트가 없는 경로(웹훅·관리자 revoke·기동 시 작업 — 전부 등급 B 테이블 위에서 돈다)는 **명시적으로 넘긴다**.
- **컨텍스트도 없고 인자도 없으면 `OutboxUsageError`** 를 던진다(`tenantid` 없는 봉투가 Kafka로 나가는 것을 막는다). `transaction.atomic()` 밖에서 호출해도 같은 예외다.
- 확정된 `tenant_id`가 봉투의 `tenantid`와 outbox 행의 `partition_key`가 된다.
- `tenant_id`로 넘긴 값(UUID 또는 str)이 **UUID로 파싱되지 않으면 `OutboxUsageError`**(slug 금지 — 봉투 스키마 검증보다 앞선 관문 · 2026-11-02 T061 리뷰 B-1). 테넌트 컨텍스트와 `tenant_id` 인자가 **둘 다 있고 서로 다르면 `OutboxUsageError`**(심층 방어 — A 등급 트랜잭션 안에서 다른 테넌트로 레이블된 봉투가 커밋되는 코드 실수를 라이브러리가 막는다), 같으면 허용(T061 리뷰 B-2).
- 웹훅·관리자 revoke가 넘길 `tenant_id`는 `TenantMembership`에서 토큰·본문의 `sub`로 조회한 값이다(없으면 400 — contracts/identity-admin-api.md).

## outbox 릴레이 (django-common)

- 실행: pod당 `manage.py outbox_relay` 프로세스 1개(Deployment의 `relay` 컨테이너, web과 같은 pod), 폴링 500 ms, 배치 100. **app role**로 실행하며 `outbox` 테이블은 등급 B(pod 전역, RLS 미적용)라 모든 테넌트의 행을 읽는다(T061: 테넌트 A·B 행이 모두 릴레이되고 각 `tenantid`·파티션 키가 맞음).
- **선택 조건**: `WHERE dead_at IS NULL ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 100`. dead 행은 다시 집지 않는다(재발행 폭주 방지) — 재처리는 `dead_at`을 비우는 수동 command로만.
- 트랜잭션 규칙: outbox INSERT는 도메인 쓰기와 같은 `transaction.atomic()` 안에서만. 라이브러리는 autocommit 상태의 INSERT를 `OutboxUsageError`로 막는다.
- 프로듀서: confluent-kafka idempotent producer, SASL_SSL SCRAM-SHA-512, `delivery.timeout.ms` 30000.
- 실패: 프로듀서 오류 시 `attempts += 1`, `last_error` 기록, 지수 백오프(최대 5분). **`attempts ≥ max_attempts(10)`이면 원본 봉투를 그 env의 DLQ(prod `<pod>.dlq` · dev `dev.<pod>.dlq`)로 발행(+ `error` 헤더)하고 `dead_at`을 기록**한다(행 유지, 재처리는 수동 command).
- **dead 행 purge**: 일 1회 `dead_at + 30 d < now()`인 행을 삭제한다(Celery beat). `outbox` 테이블이 무한히 자라지 않게 하는 유일한 경로이며, 30일은 수동 재처리 여유다.
- 관측(relay 컨테이너 `prometheus_client` 9464, `k8s.grafana.com/scrape: "true"`): `outbox_pending`(gauge, `dead_at IS NULL`만 셈), `outbox_oldest_pending_seconds`(가장 오래된 pending의 나이, 알림 `OutboxOldestPending` > 60 s), `outbox_dead_total`(counter).

## 소비자 규칙

- consumer group prod `<pod>-<purpose>` · dev `dev-<pod>-<purpose>`(예: `notification-note-published` · `dev-notification-note-published` — KafkaUser 그룹 ACL 접두가 prod `<pod>-` · dev `dev-<pod>-`이다 · data-model §6 · 2026-10-16 T056 정정). 오프셋 커밋은 처리 트랜잭션 커밋 뒤.
- 처리 실패 3회 → DLQ로 이동(원본 봉투 + `error` 헤더). DLQ 재처리는 수동 command.
- 스키마 검증: 소비자는 `packages/events`의 스키마로 `data`를 검증하고, 실패는 DLQ.
- 컨슈머 그룹 lag 지표는 SP-2(`kafkaExporter`); SP-1 알림은 outbox pending·oldest age + 브로커 under-replicated만.
