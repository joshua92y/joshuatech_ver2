"""도메인 모델 자리(T072 D12) — 템플릿은 실행되는 모델을 두지 않는다(모든 pod DB에 예시 표가 생기지 않게).

아래는 실행되지 않는 예다. 실제 모델을 더하면 makemigrations로 마이그레이션을 만들고, A 등급 표는 RLS 전용 마이그레이션을 따로
둔다(규칙 django-pod.md §Table grades · §Migrations). 실제로 도는 A 등급 예는 시험 전용 앱 tests/rlsapp(RlsWidget)이고, B 등급
예는 django_common의 outbox다.

A 등급(테넌트 범위 — RLS가 행을 거른다 · 매니저 · save()는 tenant_id를 거르거나 채우지 않는다):

    from django.db import models
    from django_common.tenancy import TenantModel

    class Note(TenantModel):                       # 클래스 이름 16자 이하(인덱스 이름 30자 — models.E034)
        title = models.CharField(max_length=200)

        class Meta(TenantModel.Meta):              # 부모 Meta를 상속한다(새 class Meta:는 (tenant_id, id) 인덱스를 잃는다)
            db_table = "note"
            indexes = [*TenantModel.Meta.indexes]  # 인덱스를 더하면 부모 것을 펼쳐 둔다

    class NoteTag(TenantModel):                    # A 등급 M2M은 명시 through(TenantModel 상속)만 — 자동 중간 표는 RLS가 없다
        note = models.ForeignKey(Note, on_delete=models.CASCADE)
        tag = models.CharField(max_length=50)

        class Meta(TenantModel.Meta):
            db_table = "note_tag"

    # RLS 전용 마이그레이션(스키마 · 데이터 변경과 섞지 않는다):
    #     from django_common.tenancy import rls_policies
    #     operations = [*rls_policies("note"), *rls_policies("note_tag")]

B 등급(pod 전역 · RLS 없음)은 허용 목록(tenant · tenant_membership · outbox · session_revocation_log)의 표 이름만 쓴다 — 목록
밖의 B 등급 표는 계약(contracts/pod-template.md)과 규칙을 먼저 개정한다:

    from django_common.tenancy import GlobalModel

    class Tenant(GlobalModel):
        id = models.UUIDField(primary_key=True)
        slug = models.SlugField(unique=True)

        class Meta(GlobalModel.Meta):
            db_table = "tenant"
"""
