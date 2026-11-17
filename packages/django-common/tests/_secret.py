"""시험 비밀 값의 repr 가림(T062) — conftest · tests/test_auth.py가 같이 쓴다.

pytest는 실패한 트레이스백 항목(기본 --tb=auto에서 첫 항목과 마지막 항목)의 함수 인자를 repr로 출력한다. 비밀번호 ·
자격이 든 URL · 웹훅 비밀이 인자로 흘러간 프레임(시험 헬퍼 · 구현 · 라이브러리)에서 실패하면 그 값이 출력에 실린다
(2026-11-02 실측 — 노출 단언 헬퍼가 실패하자 인자 needles가 그대로 찍혔다). 그래서 세션 비밀은 만들 때부터 Secret으로
감싼다. 값 자체(비교 · 포맷 · encode · URL 파싱)는 str 그대로 쓰인다 — repr만 가린다.
"""

from __future__ import annotations


class Secret(str):
    """repr이 `'***'`인 str. f-string · str() · encode()는 실제 값을 낸다(값을 쓰는 곳에는 영향이 없다)."""

    __slots__ = ()

    def __repr__(self) -> str:
        return "'***'"
