"""시험 뷰(T060 · D5)."""

from django.http import HttpRequest, HttpResponse, JsonResponse, StreamingHttpResponse

from tests.testapp.models import Widget


def widget_count(request: HttpRequest) -> JsonResponse:
    """보이는 Widget 수와 tenant_id 목록 — RLS가 요청 트랜잭션의 테넌트 컨텍스트로 거른 결과다."""
    tenant_ids = sorted({str(t) for t in Widget.objects.values_list("tenant_id", flat=True)})
    return JsonResponse({"count": Widget.objects.count(), "tenant_ids": tenant_ids})


def widget_stream(request: HttpRequest) -> StreamingHttpResponse:
    """스트리밍 응답 — 본문은 미들웨어의 트랜잭션 밖에서 만들어지므로 DB에 닿지 않는다(경고 대상)."""
    return StreamingHttpResponse(iter([b"x"]))


def healthz(request: HttpRequest) -> HttpResponse:
    """헬스 — DB 없음 · 테넌트 컨텍스트 면제 경로."""
    return HttpResponse("ok")
