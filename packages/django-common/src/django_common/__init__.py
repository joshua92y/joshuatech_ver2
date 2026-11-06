"""django_common — Django pod 공용 라이브러리(T015 골격 · T068부터 구현 모듈).

구현된 모듈: tenancy(테이블 등급 · TenantContextMiddleware · rls_policies · check_rls · 컨텍스트 도우미 — T068) ·
problem(RFC 9457 problem_response — T068) · outbox(트랜잭셔널 outbox — publish · relay_once · purge_dead · requeue_dead ·
하위 모듈 metrics — T069) · kafka(Kafka 클라이언트 설정 검증 client_config — T069) · models(OutboxEvent 등록 · 마이그레이션
0001 — T069) · auth(JwtAuthMiddleware · AccessJwtValidator · Denylist · 웹훅 헬퍼 · check_settings — T070) · 관리 명령
check_rls(T068) · outbox_relay · outbox_requeue · outbox_purge(T069). observability · health(T071)는 뒤 과제에서 들어온다.
계약 정본: specs/003-platform-foundation/contracts/pod-template.md.
"""
