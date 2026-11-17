"""identity-admin 업무 지표(T073 설계 D25 — pod 소유 새 파일) — `session_revocations_total{reason}`.

정본: contracts/identity-admin-api.md §관측 「메트릭」 · 설계 D25 「지표」.

- 템플릿 metrics.py와 같은 꼴로 지연 등록한다 — import가 아니라 session_revocations_total()의 첫 호출에 prometheus_client 기본
  REGISTRY에 등록한다. 부르는 곳은 폐기 기록의 커밋 뒤 콜백(revocation._after)뿐이다 — relay · celery 프로세스가 이 모듈을
  import해도 레지스트리에 이 지표가 생기지 않는다(relay 9464 레지스트리에 web 지표 없음 — 템플릿 불변식).
- 커밋 뒤에만 +1한다(재전송 · 4xx · 롤백은 0). web 프로세스 지표다 — 워커의 대조 보정과 `kubectl exec` 관리 명령의 +1은 그
  프로세스 레지스트리에만 남아 수집되지 않는다(그 수는 로그 `session_revocation.recorded`의 `source`로 센다).
"""

from __future__ import annotations

import threading

from prometheus_client import Counter

__all__ = ["session_revocations_total"]

_lock = threading.Lock()
_revocations_total: Counter | None = None


def session_revocations_total() -> Counter:
    """session_revocations_total{reason} Counter — 첫 호출에 기본 REGISTRY에 등록한다(프로세스에 하나 · 스레드 안전)."""
    global _revocations_total
    with _lock:
        if _revocations_total is None:
            _revocations_total = Counter(
                "session_revocations_total",
                "Session revocations recorded, counted after the recording transaction commits",
                ("reason",),
            )
        return _revocations_total
