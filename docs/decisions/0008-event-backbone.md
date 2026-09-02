---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0008: 이벤트 백본 — Kafka KRaft(Strimzi)·폴링 outbox 릴레이·CloudEvents JSON

<!-- 근거: spec D9·§4(pod 템플릿·데이터·이벤트)·§7(리스크 표 — 노드 RAM 초과·Kafka 단일 노드 손실)·Edge Cases(Kafka 디스크 포화), contracts/events.md(토픽 규약·발행 API·릴레이·DLQ — 정본), data-model §4(OutboxEvent)·§5(EventSchema)·§6(KafkaTopic/KafkaUser), plan Complexity Tracking(Strimzi Kafka)·A14(RAM 예산), research R6(STRIMZI-D1·D2·D4·D5·D8)·R9(DJANGO-D6) -->

## Context and Problem Statement

pod 8개(ADR 0005 부록 D18)는 서로의 DB를 읽지 않는다(헌법 III, ADR 0007) — 상태 전파는 이벤트로만 한다. SP-1부터 세션 폐기 전파(`identity-admin.session.revoked`)가 실사용이고, SP-2~SP-3의 색인·알림·투영 소비자를 위해 SP-1이 토픽 6개의 스키마를 미리 정의한다(contracts/events.md).

제약: 노드 A 13 GB 예산 안에서 브로커가 상주해야 하고(plan A14 — Kafka 스택 ≈ 2.6 GiB), 단일 브로커라 HA가 없으므로 "발행 유실 없음"은 브로커가 아니라 발행 경로에서 보장해야 하며, dev·prod가 클러스터 하나를 공유하고(D15), 스키마는 public 모노레포에서 pod 간 유일한 결합 계약이 된다.

## Considered Options

- **Kafka 4.3.1 KRaft 단일 노드(Strimzi 1.2.0) + 앱 내 폴링 outbox 릴레이 + CloudEvents 1.0 JSON + 모노레포 JSON Schema (채택)** — 소비자 시맨틱(그룹·오프셋·보존)을 표준 그대로 학습하고, 유실 없음은 outbox가 보장
- Postgres outbox + Dragonfly Streams — RAM 최소지만 consumer group·오프셋·보존 시맨틱이 없고, 사용자가 Kafka 학습을 명시 요구(plan Complexity Tracking)
- Redpanda — 브로커 RAM ≈ 0.5–1 GiB로 가볍지만 Kafka 표준 스택(Strimzi CRD·생태계) 학습 목표에서 벗어난다 — RAM 초과 시 전환 트리거로만 남긴다
- Debezium(CDC 릴레이) — WAL 기반이라 폴링이 없지만 Kafka Connect 상주가 2노드 예산에 과다(research DJANGO-D6) — 릴레이 지연이 병목이 될 때의 트리거로만 남긴다
- Avro + Schema Registry — 스키마 강제가 강하지만 Registry 상주 + 바이너리 봉투 디버깅 비용이 든다; JSON Schema는 CI 비교만으로 같은 호환 규칙을 강제한다

## Decision Outcome

1. **브로커 = Strimzi 1.2.0 + Kafka 4.3.1 KRaft combined 단일 노드**: `KafkaNodePool` 1개(`roles: [controller, broker]`, replicas 1, 노드 A 고정), 내부 토픽 포함 RF·`min.insync.replicas` 1, `auto.create.topics.enable=false`, local-path 20 Gi(`deleteClaim: false`). 리스너는 `tls` 9093 하나(SCRAM-SHA-512), `authorization: simple`, plain 리스너 없음(research STRIMZI-D2·D5).
2. **토픽 규약(정본 contracts/events.md)**: prod `<pod>.<entity>.<event>` / dev `dev.` 접두, 파티션 3, 파티션 키 = 봉투 `tenantid`(테넌트 UUID — 같은 테넌트 순서 보존), 보존 7일, DLQ `<pod>.dlq`. 토픽 접두는 소유 pod만 쓴다. `KafkaTopic`·`KafkaUser`(`<pod>`·`dev-<pod>`, ACL 최소)는 platform-gitops 선언이며, SCRAM 비밀번호는 Vault `kv/{env}/kafka/<pod>` → ESO, 클러스터 CA는 `k8s-data-ca` 미러다(ADR 0010, data-model §6).
3. **발행 = transactional outbox**: `django_common.outbox.publish`는 도메인 쓰기와 같은 `transaction.atomic()` 안의 outbox INSERT만 허용한다(`OutboxUsageError` — `tenantid`를 확정할 수 없어도 같은 예외). outbox는 등급 B 테이블(pod 전역, RLS 미적용 — ADR 0007)이고, 릴레이는 web과 같은 pod의 `relay` 컨테이너 1개가 app role로 500 ms 폴링한다.
4. **릴레이·DLQ**: `WHERE dead_at IS NULL ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 100` → idempotent producer(SASL_SSL, `delivery.timeout.ms` 30000, confluent-kafka) → 성공 시 행 삭제. 실패는 지수 백오프(최대 5분), `attempts ≥ 10`이면 원본 봉투를 `<pod>.dlq`로 발행하고 `dead_at`을 기록(행 유지, 재처리는 수동 command), dead 행은 30일 뒤 일 1회 purge — outbox가 무한히 자라지 않는 유일한 경로다. 지표 `outbox_pending`·`outbox_oldest_pending_seconds`(알림 > 60 s)·`outbox_dead_total`.
5. **봉투 = CloudEvents 1.0 structured JSON**: `id` = outbox ULID(소비자는 `(consumer_group, id)`로 멱등 처리), 확장 속성 `tenantid`. 스키마 정본은 모노레포 `packages/events/schemas/`의 JSON Schema 2020-12 하나뿐이고, CI가 main↔PR 필드 비교로 호환을 강제한다(필드 삭제·타입 변경·`required` 추가 금지 — 위반은 새 토픽 `…v2`).
6. **소비자 규칙**: group `<pod>-<purpose>`, 오프셋 커밋은 처리 트랜잭션 커밋 뒤, 처리·스키마 검증 3회 실패 → DLQ. 브로커 유실·7일 초과 지연은 원천(각 pod DB)에서 재색인·재투영으로 복구한다 — 브로커는 전달 버스이지 정본이 아니다.
7. **전환 트리거 2건**: (a) US7 RAM 실측에서 완화 순서(Argo core → Alloy 축소 → dev quota 축소) 뒤에도 노드 A가 초과하면 Redpanda 전환 검토를 새 ADR로 연다(spec §7). (b) 릴레이 폴링 지연(`outbox_oldest_pending_seconds`)이 요구를 계속 넘으면 Debezium CDC를 같은 절차로 검토한다.

### Consequences

- 좋음: 발행이 도메인 트랜잭션과 원자적이라 유실이 없고, pod 간 결합이 JSON Schema 계약뿐이며, consumer group·오프셋·보존을 SP-2 전부터 표준 그대로 연습하고, env 분리가 토픽 접두만으로 끝나며(브로커 1개), Registry 없이 스키마를 관리한다.
- 나쁨: Kafka 스택 ≈ 2.6 GiB 상주(노드 A 예산의 최대 단일 항목 — plan A14), 폴링 릴레이의 평균 지연 ~0.25 s와 상시 DB 폴링 부하, 브로커 디스크 장애 시 미소비 이벤트는 재투영 전까지 비어 있다(지연으로만 나타남 — spec §7 수용).
- 위험 수용: KRaft combined 모드는 Kafka 문서상 production 비권장이지만 단일 노드 자체가 HA 없음이라 리스크가 같다(research STRIMZI-D2). 소비자 lag 지표는 SP-2(`kafkaExporter`)로 미룬다 — SP-1 알림은 outbox·브로커 지표뿐이다.
