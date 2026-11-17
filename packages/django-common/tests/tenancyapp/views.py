"""시험 tenancy 뷰(T068 · D11 · r2).

- exempt_probe: 면제 경로 자리(헬스 3종 · /custom-exempt). 미들웨어가 연 atomic 안인지(in_atomic_block)와 상류 미들웨어가 둔
  request.tenant_id의 타입 이름(없으면 NoneType)만 비춘다 — DB에 닿지 않는다(연결 · 요청 속성만 읽는다).
- exempt_raise: 면제 경로에서 예외를 내는 뷰(tc-27 — 예외 타입이 TransactionManagementError로 가려지지 않는지).
- context_probe: 면제 밖 경로. in_atomic_block과 GUC 원문(current_setting('app.tenant_id', true))을 비춘다 — 라이브러리
  도우미(current_tenant_id)를 쓰지 않고 SQL로 직접 읽는다(구현과 독립된 관찰).
- widget_write_*: A 등급 행(Widget · 요청의 tenant_id)을 쓴 뒤 세 결말 — 200 응답(tc-9) · 예외 없이 돌려준 500 응답(tc-8) ·
  뷰 예외 IntentionalViewError(tc-7).
"""

from django.db import connections
from django.http import HttpRequest, JsonResponse

from tests.testapp.models import Widget


class IntentionalViewError(Exception):
    """tc-7 · tc-27 — 일부러 내는 뷰 예외.

    tc-7은 response.exc_info로 예외가 이 종류인지 본다 — 쓰기(INSERT)가 성공한 뒤의 예외라는 증거다(쓰기 자체가
    실패해 0행인 경우를 롤백으로 오인하지 않게). tc-27은 면제 경로에서도 이 종류가 그대로 전파되는지 본다.
    """


def exempt_probe(request: HttpRequest) -> JsonResponse:
    return JsonResponse(
        {
            "in_atomic_block": connections["default"].in_atomic_block,
            "tenant_id_type": type(getattr(request, "tenant_id", None)).__name__,
        }
    )


def exempt_raise(request: HttpRequest) -> JsonResponse:
    raise IntentionalViewError("tc-27: 면제 경로 뷰가 낸 예외")


def context_probe(request: HttpRequest) -> JsonResponse:
    connection = connections["default"]
    with connection.cursor() as cursor:
        cursor.execute("SELECT current_setting('app.tenant_id', true)")
        (guc,) = cursor.fetchone()
    return JsonResponse({"in_atomic_block": connection.in_atomic_block, "guc": guc})


def _write_widget(request: HttpRequest) -> str:
    widget = Widget.objects.create(tenant_id=request.tenant_id, name="tc")
    return str(widget.pk)


def widget_write_ok(request: HttpRequest) -> JsonResponse:
    return JsonResponse({"id": _write_widget(request)})


def widget_write_500(request: HttpRequest) -> JsonResponse:
    return JsonResponse({"id": _write_widget(request)}, status=500)


def widget_write_raise(request: HttpRequest) -> JsonResponse:
    _write_widget(request)
    raise IntentionalViewError("tc-7: 행을 쓴 뒤 낸 뷰 예외")
