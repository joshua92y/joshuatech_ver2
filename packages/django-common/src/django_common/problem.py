"""RFC 9457 문제 응답(T068 · D5) — django-common과 pod가 오류 응답을 만드는 한 곳.

계약: contracts/pod-template.md §런타임 계약 「오류」 행 · contracts/identity-admin-api.md §오류 슬러그 · 규칙
.claude/rules/django-pod.md §Errors.

- Content-Type `application/problem+json`(charset 매개변수 없음 — JSON은 UTF-8이다).
- 본문 = `type`(`https://joshuatech.dev/problems/` + 슬러그의 `_`를 `-`로) · `title`(주어진 값 또는 HTTP 상태 문구) ·
  `status` + `detail`(주어질 때만). `detail`에는 토큰 · 비밀 · 자격이 든 URL을 싣지 않는다(호출자 책임).
- 슬러그는 `[a-z][a-z0-9_]*` 꼴이어야 한다(아니면 ValueError — 오류 슬러그 표의 이름 꼴).

쓰는 곳: TenantContextMiddleware의 403 tenant_required(T068) · AuthError.to_response()(T070) · 헬스 503 not_ready(T071) ·
pod 뷰와 오류 핸들러(T072 · T073). 응답을 돌려줄 뿐 예외를 올리지 않는다 — PermissionDenied를 올리면 Django handler403이
`forbidden`으로 바꾼다.
"""

from __future__ import annotations

import json
import re
from http import HTTPStatus

from django.http import HttpResponse

__all__ = ["problem_response"]

_TYPE_BASE = "https://joshuatech.dev/problems/"
_CONTENT_TYPE = "application/problem+json"
# fullmatch로 쓴다 — `$`는 끝 줄바꿈 앞에서도 맞는다.
_SLUG = re.compile(r"[a-z][a-z0-9_]*")


def problem_response(
    slug: str, status: int, *, title: str | None = None, detail: str | None = None
) -> HttpResponse:
    """RFC 9457 `application/problem+json` 응답을 만든다(`type` · `title` · `status` · 선택 `detail`)."""
    if not isinstance(slug, str) or _SLUG.fullmatch(slug) is None:
        raise ValueError("problem 슬러그는 [a-z][a-z0-9_]* 꼴이어야 한다")
    code = int(status)
    body: dict[str, object] = {
        "type": _TYPE_BASE + slug.replace("_", "-"),
        "title": HTTPStatus(code).phrase if title is None else title,
        "status": code,
    }
    if detail is not None:
        body["detail"] = detail
    return HttpResponse(json.dumps(body, ensure_ascii=False), status=code, content_type=_CONTENT_TYPE)
