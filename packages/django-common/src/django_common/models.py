"""django_common 앱의 모델 모듈(T069 · D1) — Django는 앱 로딩 때 `<앱>.models`만 import하므로 여기서 OutboxEvent를 등록한다.

정의는 django_common.outbox.models 한 곳이다(여기는 import만 — 같은 모델을 두 번 정의하지 않는다). 테이블은 django_common 앱의
마이그레이션 0001이 만든다(B 등급 outbox · RLS 없음).
"""

from django_common.outbox.models import OutboxEvent

__all__ = ["OutboxEvent"]
