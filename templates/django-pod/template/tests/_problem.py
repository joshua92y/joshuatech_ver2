"""RFC 9457 문제 응답 단언 헬퍼(T072 D16 — django-common tests/_problem.py와 같은 API).

계약: contracts/pod-template.md §런타임 계약 「오류」 행 — Content-Type application/problem+json · type =
https://joshuatech.dev/problems/ + 오류 슬러그의 `_`를 `-`로(예: not_ready → …/problems/not-ready).

Django를 모듈 수준에서 import하지 않는다(타입 힌트만).
"""

from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

if TYPE_CHECKING:
    from django.http import HttpResponse

PROBLEM_TYPE_BASE = "https://joshuatech.dev/problems/"
PROBLEM_CONTENT_TYPE = "application/problem+json"


def problem_type(slug: str) -> str:
    """RFC 9457 type URI — 오류 슬러그의 `_`를 `-`로."""
    return PROBLEM_TYPE_BASE + slug.replace("_", "-")


def assert_problem(response: HttpResponse, status: int, slug: str) -> dict[str, Any]:
    """RFC 9457 문제 응답 — 상태 · Content-Type problem+json · type 규칙 · title(비어 있지 않은 str) · status · detail(있으면 str).
    본문 dict를 돌려준다. 단언은 꺼낸 값으로 한다 — 실패 출력에 본문 전체(detail 포함)가 실리지 않게."""
    assert response.status_code == status
    assert response["Content-Type"].startswith(PROBLEM_CONTENT_TYPE)
    body: dict[str, Any] = json.loads(response.content)
    body_type = body.get("type")
    title = body.get("title")
    body_status = body.get("status")
    detail_is_str = isinstance(body.get("detail", ""), str)
    assert body_type == problem_type(slug)
    assert isinstance(title, str) and title != ""
    assert body_status == status
    assert detail_is_str
    return body
