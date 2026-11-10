"""app role 테이블 · 시퀀스 GRANT(T072 D12 · 계약 「마이그레이션」 행) — owner로 도는 migrate(PreSync Job · 시험 · 로컬)가 실행한다.

app role 이름은 DB 이름에서 파생한다: `<current_database()>_app`(prod <pod_snake>_app · dev dev_<pod_snake>_app — 계약 「DB·role 이름」
행). role이 없으면 RAISE EXCEPTION으로 migrate가 실패한다(이름 규칙이 바뀌면 크게 실패한다).
- 스키마 public USAGE · 지금 있는 표 전부 SELECT · INSERT · UPDATE · DELETE · 시퀀스 전부 USAGE · SELECT.
- ALTER DEFAULT PRIVILEGES — owner가 나중에 만드는 표 · 시퀀스에도 같은 권한(마이그레이션 순서와 무관 — ALL TABLES + DEFAULT
  PRIVILEGES가 앞뒤를 함께 덮는다).
- django_migrations는 SELECT만 남긴다(app role은 마이그레이션 이력을 쓰지 않는다 — 앱은 migrate를 돌리지 않는다).
app role은 관계를 소유하지 않는다(소유자는 NO FORCE · DROP POLICY로 RLS를 끌 수 있다 — check_rls --require-rls-role). CONNECT
경계(REVOKE CONNECT … FROM PUBLIC · GRANT CONNECT)는 이 마이그레이션이 아니라 migrate Job의 첫 단계다(deploy/base).
"""

from django.db import migrations

GRANT_SQL = """
DO $grants$
DECLARE
    app_role text := current_database() || '_app';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = app_role) THEN
        RAISE EXCEPTION 'app role % does not exist', app_role;
    END IF;
    EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', app_role);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO %I', app_role);
    EXECUTE format('GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO %I', app_role);
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO %I', app_role
    );
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO %I', app_role);
    EXECUTE format('REVOKE INSERT, UPDATE, DELETE ON public.django_migrations FROM %I', app_role);
END
$grants$;
"""

REVOKE_SQL = """
DO $grants$
DECLARE
    app_role text := current_database() || '_app';
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = app_role) THEN
        RETURN;
    END IF;
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE USAGE, SELECT ON SEQUENCES FROM %I', app_role);
    EXECUTE format(
        'ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT, INSERT, UPDATE, DELETE ON TABLES FROM %I', app_role
    );
    EXECUTE format('REVOKE USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public FROM %I', app_role);
    EXECUTE format('REVOKE SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public FROM %I', app_role);
END
$grants$;
"""


class Migration(migrations.Migration):
    initial = True

    dependencies: list[tuple[str, str]] = []

    operations = [migrations.RunSQL(sql=GRANT_SQL, reverse_sql=REVOKE_SQL)]
