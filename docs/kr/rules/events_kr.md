> 번역본(편의용). 정본은 영어 원본 `.claude/rules/events.md`이며 충돌 시 영어가 우선한다. 동기화: /finish.

```yaml
paths:
  - "packages/events/**"
```

# Rules for `packages/events/`

기록 계약: `specs/003-platform-foundation/contracts/events.md`. 충돌 시 계약이 우선한다; 계약을 먼저 개정한다.

## Envelope (CloudEvents 1.0, JSON, structured mode)

- 모든 이벤트는 `specversion`, `id`, `source`, `type`, `time`, `subject`, `tenantid`, `datacontenttype: application/json`, `data`를 가진 CloudEvents 1.0 JSON 엔벨로프다.
- `id` = outbox 행 id(ULID). 컨슈머는 멱등 처리를 위해 `(consumer_group, id)`를 저장한다.
- Kafka 헤더: `ce_type`, `ce_source`, `ce_id`, `content-type: application/cloudevents+json`(structured 모드 — 엔벨로프가 메시지 값이다).
- `tenantid`는 CloudEvents 확장 속성이다(소문자 영숫자 이름). 그 값은 항상 테넌트 UUID다 — 절대 슬러그가 아니다. 사용자 범위 이벤트는 그 사용자의 테넌트를 담는다. `tenantid` 없는 엔벨로프는 절대 Kafka에 도달해서는 안 된다(업스트림의 `OutboxUsageError`가 이를 보장한다).

## Topic conventions

- 이름: prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`. pod 이름은 kebab-case; entity와 event는 단수 소문자다. DLQ는 `<pod>.dlq`다.
- 파티션 3개; 파티션 키 = `tenantid`(UUID 문자열)로 테넌트별 순서가 보존된다. 보존 기간 7일 — 그보다 뒤처진 컨슈머는 보존 기간 연장이 아니라, 소유 pod의 DB로부터 재인덱싱/재프로젝션으로 복구한다.
- 쓰기 권한: 소유 pod만 자기 `<pod>.` 토픽 접두에 발행한다. 다른 pod를 대신해 절대 발행하지 않는다.

## Schemas

- 발행되는 모든 토픽은 `packages/events/schemas/` 아래에 스키마를 가진다; 스키마 없이 토픽을 추가하는 것은 미완성 작업이다.
- 컨슈머는 `data`를 `packages/events` 스키마에 대해 검증한다; 검증 실패는 관대한(lenient) 파싱이 아니라 DLQ로 간다.

## Compatibility rules (CI-enforced)

- 허용되는 변경: OPTIONAL 필드 추가; enum 값 추가(컨슈머는 모르는 enum 값을 반드시 무시해야 한다).
- 금지: 필드 삭제나 개명, 필드 타입 변경, `required` 필드 추가, enum 값 삭제.
- 파괴적(breaking) 변경은 새(NEW) 토픽(`...v2`)을 의미하며 두 토픽에 이중 발행(dual-publish) 기간을 둔다; 기존 스키마를 비호환으로 절대 변형하지 않는다.
- CI는 `packages/events/scripts/check-compat.mjs`를 실행해 PR 스키마를 `main`과 필드 단위로 비교한다; 위반은 빌드를 실패시킨다. 스키마 변경을 넣으려고 이 검사를 절대 약화하거나 우회하지 않는다.

## Consumer rules

- 컨슈머 그룹 이름: `<pod>-<purpose>`(예: `notification-note-published`).
- 오프셋 커밋은 처리 트랜잭션이 커밋된 뒤에만(AFTER) 한다.
- 처리 실패 3회 → 원본 엔벨로프(+ `error` 헤더)를 DLQ로 옮긴다; DLQ 재처리는 수동 명령으로만 한다.
- SP-1 알림은 outbox pending/oldest-age와 브로커 under-replication만 다룬다; 컨슈머 그룹 lag 메트릭은 SP-2에 온다 — 여기에 임시(ad-hoc) lag 알림을 추가하지 않는다.
