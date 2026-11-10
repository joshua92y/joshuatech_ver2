"""T070 계약 시험 urlconf(T070 소유 · tests/test_auth_contract.py) — 모델 없음 · INSTALLED_APPS에 넣지 않는다.

T062의 tests/authapp은 바꾸지 않는다(T062 산출물). 여기에는 T062가 고정하지 않은 표면을 보는 데 필요한 것만 둔다.
- urls: 헬스 1(`/healthz`) · 무인증 뷰(`/open` — 면제 목록을 시험이 바꿀 때) · 속성 비춤 뷰(`/protected` · `/access-only`) ·
  handler400(호스트 거부 DisallowedHost → 400 invalid_host · 그 밖 → 400 validation_error — 템플릿 handler400의 대역 ·
  계약 §런타임 계약 「오류」 행).
- middleware.AttributeProbeMiddleware: JwtAuthMiddleware 바깥에서 (선택) 가짜 요청 속성을 미리 두고, 안쪽이 돌아온 뒤
  요청에 남은 인증 속성의 이름만 응답 헤더로 비춘다(값은 싣지 않는다).
"""
