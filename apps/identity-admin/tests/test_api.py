"""identity-admin API 계약 테스트(T066 · test-first — 짝 구현 T073 · 라이브러리 T068–T071 · 템플릿 T072가 초록으로 만든다).

계약:
- 헬스(contracts/identity-admin-api.md §엔드포인트 · §타임아웃): /healthz 200 {status "ok", version, git_sha}(의존 조회
  없음) · /ready DB만(DB 다운 503 not_ready · Dragonfly·Kafka 다운 200) · /health 항상 200 + checks {db, dragonfly,
  kafka_producer} · 전체 ≤ 3 s · 의존 검사 병렬(항목 상한 DB 2 s · Dragonfly 0.2 s · Kafka 1 s — 순차 합 3.2 s)(api-1..3 ·
  api-52).
- /session/check(§엔드포인트 · §인증 계층 구현 규약): Access 전용 경로(Bearer를 검증하지 않는다) · DB 접근 없음 · active =
  `revoked:sub:{sub}` 값 > iat가 아니고 sid가 있으면 `revoked:sid:{sid}`도 없음(같은 값이면 active) · nbf는 sub 키가 있을
  때만 · 질의 검증 실패 400 validation_error · Dragonfly 실패 503 denylist_unavailable(0.2 s)(api-4..9).
- /sessions/revoke(§엔드포인트 · data-model §3 · contracts/denylist.md §쓰기 규약 · contracts/events.md §발행 API): 202
  {id, nbf, expires_at} · 한 행 = 한 키(all_devices true → sid NULL 행 + revoked:sub = nbf(본문 sid는 쓰지 않는다) ·
  false → sid 행 + revoked:sid = 1 · sid 원천 = 본문 → 본인 호출의 토큰(관리자 호출은 본문만) · 둘 다 없으면 400) · nbf =
  처리 시각 epoch 초 내림 + 1 · expires_at = nbf + 330 s · 로그 + outbox 같은 트랜잭션 → 커밋 후 SET EX 330 · 관리자 =
  groups 목록 원소가 정확히 platform-admin(아니면 403 forbidden) · 관리자 대상 테넌트 = TenantMembership(없으면 400) · 요청
  처리 중 Authentik을 부르지 않는다(위임 실패도 202) · 지표 session_revocations_total{reason}(api-10..19 · api-51).
- /webhooks/authentik(§웹훅 서명 규약): HMAC(정규형) · created ±5분 · 실패 401 webhook_signature_invalid · 항상 사용자
  단위(본문 sid 미사용) · tenant_id = 본문 sub의 TenantMembership(없으면 400) · event_pk 멱등(DB unique — 캐시를 비워도
  재전송 200 no-op · 행·이벤트·키·지표 변화 0) · 그 밖의 action 200 no-op · 업무 필드 검증 400(action 없음/문자열 아님 ·
  sub 없음/문자열 아님 · nbf 정수 아님 — bool · 실수 · 문자열) · 본문 nbf 없으면 수신 시각 내림 + 1 · 커밋 뒤 SET이
  실패해도 202(api-20..26).
- /tenants/me(§엔드포인트 · data-model §2): app role로 B 등급 테이블만 · 토큰 sub·tenant_id 둘 다 일치하는 멤버십만 ·
  없으면 404 not_found(api-27..29).
- 주기 작업(§주기 작업 · contracts/denylist.md §쓰기 규약): expires_at > now() 행 전부 조건 없이 다시 SET(센티널 없음 ·
  덮어쓰기 · 남은 TTL = expires_at − now() 내림 · 한 행 = 한 키) · beat 30 s · beat_init에서 같은 프로세스 동기 1회 · 로그
  purge(expires_at + 30 d) · outbox dead purge(dead_at + 30 d) · 경계 = DB now()(api-30..35).
- seed_tenant(data-model §1 파생 쓰기 규칙): 멱등(행 수·id 불변 · 파생 중복 없음 · 같은 상태면 Authentik 쓰기 0) · DB →
  파생 · 파생 실패 CommandError · 그룹 `?name=` · 사용자 `?uuid=` 조회(쓰기 플래그와 무관하게 늘 한다 — 없으면
  CommandError · 그룹은 만들지 않는다 · 미끼 그룹·사용자 불변) · attributes 병합 PATCH · AUTHENTIK_WRITES_ENABLED · FGA
  중복만 성공 · slug 충돌 실패 · 출력에 비밀 없음(api-36..41 · api-56 — 그룹 없음 api-40 · 사용자 없음 api-56은 쓰기 켬 ·
  끔 둘 다).
- 호스트·설정(§호스트 · §identity-admin 전용 설정 · §오류 슬러그 · rules/django-pod.md §Auth · §Settings · §Errors):
  ADMIN_HOST 정확 일치에서만 admin 장착 · 빈 값이면 admin 없음 · admin 경로 접두(ADMIN_SCRIPT_NAME ← env FORCE_SCRIPT_NAME)는
  ADMIN_HOST 요청에만 적용하고 요청 끝에 되돌린다(Django 전역 FORCE_SCRIPT_NAME 없음 · 접두 env가 있으면 STATIC_URL은 절대
  `<접두>/static/` — api-54) · ALLOWED_HOSTS 밖 400 invalid_host(업무 경로 · 인증보다 먼저) · URL 없음 404 not_found
  (Django 자체 400 · 404도 RFC 9457) · JWKS도 svc DNS(iss만 공개 URL) · svc DNS 기본값 · 공개 호스트 설정이면 기동 실패 ·
  필수값은 존재만 본다(빈 값 유효 — 단 비밀 3개는 빈 값도 기동 실패) · 기동 출력에 설정 값 없음 · 기동 중 공개 이름 조회
  0(api-42..49 · api-53..55) · OpenAPI 계약 구조(api-50).

T072 가정(템플릿이 만드는 생성물 시험 인프라 — build-notes 「T066」 D2 · 바꾸면 이 파일과 함께):
① pytest-django 설정 = pod 설정(`identity_admin.settings`를 import하는 tests 래퍼 허용) · DATABASES `default`(app role · TLS ·
  `TEST.MIRROR` = owner) + `owner`(owner role) · 세션 시작 owner 별칭 migrate(django-common `django_db_setup` 재정의와 같은
  꼴) — DB 마크는 `databases=["default", "owner"]`다(MIRROR인 default만 두면 TransactionTestCase가 아무 별칭도 flush하지
  않아 행이 테스트 사이에 샌다 — Django `_databases_names(include_mirrors=False)`) · 시험 DB 설정은 psycopg 연결 풀
  (`OPTIONS["pool"]`)을 켜지 않는다 — `_db_down`(api-3 · 52)이 settings_dict를 바꿔 다운을 흉내 내는데, 풀은 별칭의 첫
  설정을 고정한다.
② 픽스처 `dragonfly`(세션 · `.admin_url`(Secret) · `.host` · `.port` — admin = 전 키 사용자) · `jwks_server`(세션 ·
  `.jwks_url` · `.base_url` · `.authentik_key` · `.access_key` · `.hits`).
③ 헬퍼 `tests._jwt`(`mint` · `bearer_claims` · `access_claims` · `AUTHENTIK_KID` · `ACCESS_KID` · `JWKS_PATH` ·
  `sign_webhook` · `webhook_body` · `TENANT_ID` · `TOKEN_TTL_S`) · `tests._problem.assert_problem` ·
  `tests._secret.Secret`(django-common과 같은 API).
④ `tests/__init__.py`(기동 하위 프로세스도 pod 루트에서 `tests._identity_fakes`를 import한다) · pyproject `addopts
  --tb=short` · `filterwarnings` 자기 모듈 한정.
⑤ win32 `TESTCONTAINERS_HOST_OVERRIDE=127.0.0.1`(testcontainers import 전).
⑥ 시험 프로세스 `os.environ`에 pod 설정이 요구하는 env 키 전부(래퍼의 `os.environ.setdefault` — 하위 프로세스 기동 시험이
  복사한다) · Celery 브로커 자리값은 닫힌 포트(api-19의 위임 실패 경로) · 기동(`django.setup()` + urlconf import)은 외부
  의존(DB · Dragonfly · Kafka · 이름 조회)에 닿지 않는다(기동 시험은 닫힌 포트 자리값 env로 하위 프로세스를 띄운다) ·
  기동 시험은 이름에 PASSWORD · SECRET · TOKEN · KEY가 든 env 값과 URL 비밀번호를 URL-safe 난수(64자)로 바꿔 넣는다 —
  설정은 비밀 값의 형식·길이를 검사하지 않는다(비어 있지 않음만) · 기동 실패 출력(메시지 · 트레이스백 소스 줄)에
  `input_value=` 글자가 없다 — 설정 이름만 싣고 `from None`으로 끊는다 · 설정 모델 `hide_input_in_errors=True`.
⑦ Celery `task_always_eager` 끔(요청 경로가 Authentik을 동기로 부르는지 api-19가 본다 — api-19가 먼저 확인한다).
⑧ 생성물은 `test_api.py` · `_identity_fakes.py` · `test_identity_fakes.py` 이름을 쓰지 않는다.
⑨ 생성물 urlconf의 `handler400`(호스트 거부 → 400 `invalid_host`) · `handler404`(→ 404 `not_found`)가 RFC 9457을 낸다
  (api-42 · 43 · 44 · 53 — rules/django-pod.md §Errors).

T071 가정(T063 고정 — 계약이 값을 정하지 않은 /health 모양은 django-common tests/test_observability.py docstring의 T071
가정을 따른다): 본문 `status` "ok"|"degraded" · `checks.<이름>.status` "ok"|"fail"(+ 지연 `latency_ms`) · `version` ·
`git_sha`(api-2 · 3 · 52). 의존 검사 예산 = DB `connect_timeout` 하한 2 s · Dragonfly 0.2 s · Kafka
`list_topics(timeout=1.0)`(django-common tests/test_observability.py의 T071 가정 · 계약 §타임아웃 항목별 상한) — api-52의
순차 합 3.2 s ≥ 3 s가 이 예산에 기댄다.

T073 가정(identity-admin 이름 — build-notes 「T066」 D3):
① 설정 이름·기본값 = 계약 §identity-admin 전용 설정 + 템플릿·T063 이름(`ADMIN_HOST` · `ALLOWED_HOSTS` ·
  `AUTHENTIK_ISSUER/JWKS_URL/AUDIENCE` · `ACCESS_TEAM_DOMAIN/AUD_M2M/AUD_ADMIN/EXPECTED_CN` · `AUTH_ACTOR_SUB` ·
  `DRAGONFLY_URL` · `KAFKA_BOOTSTRAP_SERVERS` · `APP_VERSION` · `APP_GIT_SHA`) — 전부 호출 시점에 `django.conf.settings`에서
  읽는다(값은 문자열 · `AUTHENTIK_WRITES_ENABLED`는 bool).
② 미들웨어: `AUTH_ACCESS_ONLY_PATHS = ("/session/check",)` · `TENANT_CONTEXT_EXEMPT_PATHS` ⊇ 헬스 3 + `/webhooks/authentik` +
  `/session/check` · 호스트 검증이 인증보다 먼저(업무 경로).
③ 모델은 db_table `tenant` · `tenant_membership` · `session_revocation_log`(+ django-common `outbox`)로 찾는다
  (`apps.get_models()` — 모듈 경로 무관) · 필드 = data-model §1–3(+ `event_pk`) · `tenant_id`는 UUID 값 참조(FK 아님 —
  data-model §1 · §2 · §3) · attname 대입 · 행은 업무 필드만으로 만들 수 있다(PK · created_at · updated_at은 기본값).
④ Celery 앱 `identity_admin.celery.app` · 작업 4(`identity_admin.tasks.reconcile_denylist` ·
  `purge_session_revocation_log` · `reconcile_authentik_sessions` · `purge_dead_outbox`) — worker·beat처럼
  `app.loader.import_default_modules()` 뒤 `app.tasks`에 있다 · beat 주기 · `beat_init` 수신 → 같은 프로세스 동기 재적용 ·
  `beat_init` 수신자는 sender로 거르지 않는다(시험은 `sender=None` · 실제 beat는 Service 인스턴스를 보낸다).
⑤ 명령 `seed_tenant --tenant-id --owner-sub --member-sub` · 실패 = `CommandError`.
⑥ Authentik/OpenFGA HTTP 표면 = data-model §1 시드 규칙(가짜 서버 tests/_identity_fakes.py가 흉내 · VD-T066-1·2) ·
  Authentik 요청 본문은 `Content-Type: application/json`(가짜는 그 밖을 415로 거부한다).
⑦ `/api/openapi.json`(Bearer 경로 · m2m 호스트에서 경로 키에 접두가 붙지 않는다) · 엔드포인트 7개는 모두 Ninja operation이고
  성공 코드를 responses에 선언한다(웹훅은 본문 파라미터 없이 — 서명 검증 전에 Ninja가 본문을 파싱하면 400이 먼저 나간다).
⑧ admin = `django.contrib.admin` `/admin/` · `ADMIN_HOST`에서 익명 → 302 `…/admin/login/` · 경로 접두 = settings
  `ADMIN_SCRIPT_NAME`(env `FORCE_SCRIPT_NAME` · 선택 · 기본 빈 값)을 `ADMIN_HOST` 요청에만 script prefix로 적용하고
  (`reverse()` · `Location` · `request.path`) 요청 끝에 되돌린다 · Django 전역 `FORCE_SCRIPT_NAME`은 None(기동 직후 script
  prefix "/") · 접두는 Django 요청 처리 안(미들웨어)에서 적용한다(시험 Client는 wsgi.py · WSGIHandler를 거치지 않는다) ·
  정적 자산은 절대 `STATIC_URL` `<ADMIN_SCRIPT_NAME>/static/`(contracts/pod-template.md `has_admin` 행 — 설정 값은 api-54가
  본다 · 서빙은 시험하지 않는다).
⑨ 뷰 오류 RFC 9457(400 `validation_error` · 403 `forbidden` · 404 `not_found`).
⑩ 지표 `session_revocations_total{reason}`(prometheus_client 기본 REGISTRY · 샘플 `_total`).
⑪ 응답 본문 모양(계약 표 그대로 · 202 `{id, nbf, expires_at}`) · outbox data 키는 정확히 4(`sub` · `sid`(사용자 단위면
  null) · `nbf` · `reason`).
⑫ `on_commit` 위임 실패(브로커 불통 등)가 응답을 500으로 만들지 않는다(robust).

빨간 상태: 저장소 안에서는 실행되지 않는다 — apps/identity-admin에 pod 환경(의존 · conftest · tests/__init__ · 설정 래퍼)이
없다(T072 · T073 뒤 실행 · T065 결정 — 생성 pod는 독립 uv 프로젝트). T072 시제품 미니 저장소(scratch)에서는 pytest-django가
tests.settings를 import할 때 `from identity_admin.settings import *`가 ModuleNotFoundError다 — "구현 없음"이 원인이다
(pytest-django가 이 ModuleNotFoundError를 `ImportError: No module named 'identity_admin'`로 다시 던진다).
`-p no:django --collect-only`는 수집에 성공한다: 모듈 수준 import는 Django 설정 · django_common 구현 · identity_admin에 기대지
않는다(구현 import — django_common.outbox · identity_admin.celery · celery 신호 — 는 테스트 안에서 지연 import).

인프라: 템플릿에서 받는 것은 DB 설정 · `dragonfly`(admin URL) · `jwks_server` · 헬퍼 3모듈(T072 가정 ① ② ③)뿐이다. T066 소유는
이 파일의 `ia_dragonfly`(운영 identity-admin 규칙 `~revoked:* ~identity-admin:* +@all`의 ACL 사용자) · `webhook_secret` ·
`fake_authentik` · `fake_openfga`(+ `_reset_fakes` · 시드 전제 `_seed_fakes` — 정답보다 앞에 미끼) · `ia_settings` ·
`ia_flush` · `dns_guard`(프록시 env를 끈다) · 자격·요청 헬퍼 · `_timed` · `_db_down` · `_boot`와 tests/_identity_fakes.py
(가짜 서버 · DNS 가드(socket `getaddrinfo` · `gethostbyname` · `gethostbyname_ex` · `gethostbyaddr`를 감싼다) · 닫힌 포트 ·
블랙홀 포트 — 자기검사 tests/test_identity_fakes.py)다.
DB에 닿는 테스트만 DB 마크를 단다 — /healthz · /session/check · beat 등록 · 하위 프로세스 기동 테스트는 DB 마크가 없다(DB에
닿으면 pytest-django가 막는다 = "DB 접근 없음" 단언).

비밀: 세션 비밀(ia Dragonfly 비밀번호 · 웹훅 비밀 · 가짜 Authentik 토큰 · OpenFGA preshared 키 · 닫힌 포트 URL의 비밀번호)은
tests._secret.Secret(repr 가림)이다 · 노출 단언은 위치 번호 목록으로 접는다(_assert_absent) · 요청 · 명령 · 작업의 예외는 원
트레이스백 없이 실패로 바꾼다(psycopg conninfo 비밀번호 — T063) · 하위 프로세스 실패 메시지는 종료 코드 + stderr 마지막 한
줄(env 비밀 값 가림 · 긴 값부터)만 싣는다 · 하위 프로세스 env의 비밀(이름에 PASSWORD · SECRET · TOKEN · KEY가 든 값 · URL의
비밀번호 — 경로형 이름(끝이 FILE · PATH · DIR)과 GIT_CONFIG_*는 그대로 두고 SSLKEYLOGFILE은 뺀다)은 새 난수(64자)로 바꿔
넣고 기동 출력(stdout · stderr)에 그 값이 없음을 단언한다(rules/django-pod.md §Settings — 기동 실패 메시지는 설정 이름만):
pydantic ValidationError의 input_value는 긴 표현을 앞뒤만 남기고 잘라도 조각이 실린다(필수값 누락이면 env 사전 마지막 값의
꼬리) → 값 전체 + 12자 조각 + `input_value=` 표식(pydantic 표기)으로 본다. 표식 단언은 기동 출력(stdout · stderr) 전체를
본다 — 기동 실패 메시지 · 로그 · 트레이스백이 찍는 소스 줄(raise 문 전체 · 그 줄 끝 주석)에 `input_value=` 글자를 두지
않는다(T072 · T073).

한계 — 단언하지 않는 것:
- 운영 Authentik revoke 호출의 세부(엔드포인트 · 5 s × 3 지수 백오프 · 최대 5분) — T085(api-19는 "요청 처리 중 호출 없음"만).
- `reconcile_authentik_sessions` 본체 — 주기 등록만 본다(api-33).
- /health Kafka ok 상태 — 시험 브로커가 없다(fail만 · ok는 django-common T063 obs-17).
- 실제 30 s 경과 — beat 주기 30 s(api-33) + 작업 결과(api-30..32)로 대신한다(실시간 SIGKILL ≤ 30 s는 T085).
- m2m 호스트의 /webhooks/authentik · /healthz · /ready 404 — Ingress 층위라 앱 pytest로 검증할 수 없다(T076 E2E).
- admin 사람 경로(GitHub IdP Access JWT · forward-auth — O1 · VD-T066-5) — api-42 · 53은 M2M 자격으로 장착 여부 · 경로
  접두만 본다.
- 로그 필드 · 마스킹 — 템플릿 내장 test_logging(T063 라이브러리 시험).
- OpenAPI 스냅샷 파일 — 템플릿 내장 test_openapi_snapshot(T072)이 맡는다(ninja minor bump 시 갱신 절차 — rules/django-pod.md
  §OpenAPI snapshot refresh) · api-50은 계약 구조(경로 · 메서드 · 코드 · 본문 · 질의)만 단언해 스냅샷 갱신이 계약을 조용히
  지우지 못하게 한다.
- Celery 브로커(Dragonfly ACL `~identity-admin:*` + global_keyprefix) 아래 worker · beat 동작(VD-T066-3 — T073 · T075) ·
  kubelet 프로브 Host(VD-T066-4 — T072 · T075).
- 커밋 뒤 SET 순서(로그 + outbox 커밋 → SET) — HTTP로 구별할 수 없다(구현 리뷰 몫 · 오라클 M46).
- /tenants/me의 "B 등급 테이블만" — 관측하지 않는다(app role 연결과 교차 테넌트 0건만 본다 — api-27..29).
- 쓰기를 켰을 때 Authentik revoke가 실제로 위임되는지 — 보지 않는다(api-19는 "요청 처리 중 호출 없음"만 · T085 E2E).
- 웹훅 시각 창 안쪽 경계(±299 s 수락) — 라이브러리 수준(T062 auth-25) · api-22는 창 밖(±330 s)만 본다.
- /health 병렬성 — 위 예산(T071 가정) 위에서만 가린다: 예산을 줄인 순차 구현(예: Kafka 0.5 s → 합 2.7 s < 3 s · 오라클
  r2 N39)은 "병렬" 계약 위반이지만 api-52가 잡지 못한다(응답 시간 상한 3 s는 지킨다).
- admin Ingress `stripPrefix` — Ingress 층위라 앱 pytest로 볼 수 없다(T075 · T076 E2E).
- `handler403` · `handler500` · CSRF 실패 응답과 호스트 밖의 Django 400(`PermissionDenied` · CSRF 실패 → 403 `forbidden` ·
  처리하지 못한 예외 → 500 `internal_error` · `SuspiciousOperation` · `BadRequest` → 400 `validation_error`) — 시험으로
  일으키지 않는다(contracts/pod-template.md §기본 테스트 3(T066 r3 · r4 보정 — T072)).
- 정적 자산 서빙(`stripPrefix` 뒤 pod가 받는 `/static/…` → 200 — contracts/pod-template.md §기본 테스트 3(T066 r4 보정 —
  T072)) — 설정 값(`STATIC_URL`)은 api-54가 본다.
- 설정 모델 `hide_input_in_errors=True`(r2 보정) — 이름만 싣고 `from None`으로 끊는 구현에서는 기동 출력이 같아 관찰할 수
  없다(오라클 r3 N48 · contracts/pod-template.md §기본 테스트 3 — T072).
- `from None`(연쇄 예외 없음) — 설정 모델이 `hide_input_in_errors=True`면 연쇄된 ValidationError 트레이스백에도 값 ·
  `input_value=`가 없어 기동 출력으로 가릴 수 없다(N48의 대칭 · contracts/pod-template.md §기본 테스트 3 — T072).
- 12자보다 짧은 비밀 조각(설계 문턱 — 오라클 r3 N49 · pydantic 잘림 꼬리는 22자) · 넣은 비밀이 아닌 설정 값의 출력
  (rules/django-pod.md §Settings "never their values"는 모든 설정이 대상 — 기동 위생은 넣은 비밀만 본다).
"""

from __future__ import annotations

import importlib
import io
import json
import math
import os
import secrets
import subprocess
import sys
import threading
import time
import uuid
from collections.abc import Callable, Iterable, Iterator, Mapping
from contextlib import contextmanager
from copy import deepcopy
from dataclasses import dataclass, field
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import TYPE_CHECKING, Any, NoReturn, Protocol
from urllib.parse import parse_qs, urlencode, urlsplit, urlunsplit

import pytest
import redis
from django.apps import apps
from django.core.management import call_command, get_commands
from django.core.management.base import CommandError
from django.db import connections, transaction
from django.test import Client
from django.urls import set_script_prefix
from prometheus_client import REGISTRY

from tests._identity_fakes import FakeAuthentik, FakeOpenFga, blackhole, closed_port, public_dns_guard
from tests._jwt import (
    ACCESS_KID,
    AUTHENTIK_KID,
    JWKS_PATH,
    TENANT_ID,
    TOKEN_TTL_S,
    access_claims,
    bearer_claims,
    mint,
    sign_webhook,
    webhook_body,
)
from tests._problem import assert_problem
from tests._secret import Secret

if TYPE_CHECKING:
    from django.http import HttpResponse
    from pytest_django import Settings

# --- 상수 -------------------------------------------------------------------------------------------------------------

SVC_HOST = "identity-admin.jt-dev.svc"  # 클러스터 내부(웹훅 · 프로브) — contracts/identity-admin-api.md §호스트
M2M_HOST = "identity-m2m-dev.joshuatech.dev"  # BFF 호출 호스트(dev)
ADMIN_HOST_VALUE = "admin.joshuatech.dev"
ADMIN_PREFIX = "/identity-admin"  # prod admin 경로 접두(env FORCE_SCRIPT_NAME → 설정 ADMIN_SCRIPT_NAME — §호스트)
EVIL_HOST = "evil.example.com"  # ALLOWED_HOSTS 밖
PUBLIC_ISSUER = "https://auth.joshuatech.dev/application/o/identity-admin/"  # Bearer iss(공개 URL — 문자열 비교만)
AUTHENTIK_SVC_URL = "http://authentik-server.identity.svc:9000"  # §identity-admin 전용 설정 기본값
OPENFGA_SVC_URL = "http://openfga.identity.svc:8080"
ACCESS_AUD_M2M = "aud-m2m-test"
ACCESS_AUD_ADMIN = "aud-admin-test"
ACCESS_EXPECTED_CN = "web-bff-test-client-id.access"  # 서비스 토큰 Client ID 자리의 가짜 값(비밀 아님)
TOPIC = "identity-admin.session.revoked"
SOURCE = "identity-admin"
DENYLIST_TTL_S = 330  # contracts/denylist.md §키 스키마(access TTL 300 s + 30 s)
TENANT_A = TENANT_ID  # tests._jwt 테넌트 A(UUID 문자열)
TENANT_B = "00000000-0000-4000-8000-00000000000b"
TENANT_SLUGS = {TENANT_A: "tenant-a", TENANT_B: "tenant-b"}
IA_DRAGONFLY_USER = "identity-admin-test"
IA_DRAGONFLY_RULES = ("~revoked:*", "~identity-admin:*", "+@all")  # contracts/denylist.md §ACL identity-admin 행 그대로
CHECK_PATH = "/session/check"
REVOKE_PATH = "/sessions/revoke"
WEBHOOK_PATH = "/webhooks/authentik"
TENANTS_ME = "/tenants/me"
OPENAPI_PATH = "/api/openapi.json"
SIGNATURE_HEADER = "X-Authentik-Signature"
METRIC = "session_revocations_total"
CHECK_NAMES = frozenset({"db", "dragonfly", "kafka_producer"})
HTTP_METHODS = frozenset({"get", "post", "put", "patch", "delete", "head", "options", "trace"})
WEBHOOK_WINDOW_S = 300  # §웹훅 서명 규약 — |now − created| > 300 s 거부
WEBHOOK_OUTSIDE_S = WEBHOOK_WINDOW_S + 30  # api-22 창 밖 시각(처리 지연 여유 30 s · 창 안쪽 경계는 T062 auth-25)
REPLAY_MARK = "replay-mark"  # api-21 — 재전송 전에 키에 둔 표식 값(비밀 아님)
TTL_TOLERANCE_S = 5  # 재적용 TTL 비교 여유(초 내림 · 작업 실행 왕복 — build-notes 「T066」 D9 ±5 s)
# 시간 상한: 헬스 판정 = 계약 §타임아웃(BFF pod fetch 3 s 안) · 거부 목록 판정 = 0.2 s + 처리 여유 0.3 s(T062 auth-17/18 근거와
# 같다 — 로컬 certs 첫 fetch + RS256 검증 수십 ms · redis-py 기본 재시도 10회를 쓴 구현은 4.7–6.8 s라 9배 밖에서 걸린다 · 느린
# 호스트에서 넘으면 수치를 보고한다). 그 밖의 상한은 멈춤을 유한한 실패로 바꾸는 장치일 뿐 성능 요구가 아니다.
DOWN_LIMIT_S = 3.0
DENYLIST_VERDICT_LIMIT_S = 0.5
VERDICT_HANG_LIMIT_S = 5.0
HANG_LIMIT_S = 10.0
WEBHOOK_DOWN_LIMIT_S = 20.0
DELEGATION_HANG_LIMIT_S = 60.0  # api-19 — Celery 위임이 닫힌 포트 브로커에 재시도하는 시간(Windows 연결 거부 ≈ 2 s × 재시도)
DB_DOWN_CONNECT_TIMEOUT_S = 1  # psycopg가 2 s로 올린다(libpq 하한)
BOOT_TIMEOUT_S = 120
BOOT_MARK = "JT-BOOT "  # 기동 하위 프로세스의 설정 값 줄 표식
DNS_MARK = "JT-DNS "  # 기동 하위 프로세스의 공개 이름 조회 시도 줄 표식(실패 기동에도 finally에서 싣는다)
MISSING_SETTING = "<missing>"  # 값 줄에서 없는 설정 이름의 표식 값(이름 하나 때문에 관계없는 기동 시험이 같이 떨어지지 않게)
BOOT_SETTINGS = (
    "ADMIN_HOST",
    "ADMIN_SCRIPT_NAME",
    "FORCE_SCRIPT_NAME",
    "AUTHENTIK_API_URL",
    "OPENFGA_API_URL",
    "AUTHENTIK_WRITES_ENABLED",
    "STATIC_URL",  # Django LazySettings.__getattr__이 상대 값에 script prefix를 붙이고 절대 값은 그대로 둔다(api-54)
)
# 기동 필수값(§identity-admin 전용 설정 · §호스트) — 없으면 기동 실패(api-47) · 비밀 3개는 빈 값도 기동 실패(api-55).
REQUIRED_SETTINGS = (
    "ADMIN_HOST",
    "AUTHENTIK_API_TOKEN",
    "AUTHENTIK_WEBHOOK_SECRET",
    "OPENFGA_STORE_ID",
    "OPENFGA_PRESHARED_KEY",
    "AUTHENTIK_JWKS_URL",
)
SECRET_SETTINGS = ("AUTHENTIK_API_TOKEN", "AUTHENTIK_WEBHOOK_SECRET", "OPENFGA_PRESHARED_KEY")
TASK_RECONCILE = "identity_admin.tasks.reconcile_denylist"
TASK_PURGE_LOG = "identity_admin.tasks.purge_session_revocation_log"
TASK_RECONCILE_AUTHENTIK = "identity_admin.tasks.reconcile_authentik_sessions"
TASK_PURGE_OUTBOX = "identity_admin.tasks.purge_dead_outbox"
DAILY_TASKS = (TASK_PURGE_LOG, TASK_RECONCILE_AUTHENTIK, TASK_PURGE_OUTBOX)
POD_ROOT = Path(__file__).resolve().parents[1]
# seed_tenant(data-model §1): 고정 테넌트 UUID · Authentik 사용자 UUID = sub(provider sub_mode user_uuid — data-model §9).
SEED_TENANT = "0192e4c1-7a00-7000-8000-00000000c0de"
OTHER_TENANT = "0192e4c1-7a00-7000-8000-0000000000ff"
SEED_OWNER = "11111111-1111-4111-8111-111111111111"
SEED_MEMBER = "22222222-2222-4222-8222-222222222222"
SEED_SLUG = "joshuatech"
SEED_DISPLAY = "JoshuaTech"
SEED_GROUP = f"tenant:{SEED_TENANT}"
SEED_TUPLES = {
    (f"user:{SEED_OWNER}", "owner", f"tenant:{SEED_TENANT}"),
    (f"user:{SEED_MEMBER}", "member", f"tenant:{SEED_TENANT}"),
}
GROUPS_API = "/api/v3/core/groups/"
USERS_API = "/api/v3/core/users/"
# 미끼(B-1 · K18): 운영 Authentik에 실제로 있는 superuser 그룹 · 플랫폼 관리자 그룹 · 기본 관리자 사용자. 가짜 목록에서 정답
# 보다 앞에 둔다 — 필터 없이 목록을 받아 첫 결과를 쓰는 시드는 tenant owner·member를 관리자 그룹에 넣거나 akadmin을 고친다.
DECOY_ADMINS_GROUP = "authentik Admins"
DECOY_PLATFORM_GROUP = "platform-admin"
DECOY_ADMIN_PK = 1
DECOY_ADMIN_UUID = "33333333-3333-4333-8333-333333333333"
# DB 마크 — T072 가정 ①의 owner 별칭을 같이 연다(테스트 끝 flush가 owner에서 돈다).
DB = pytest.mark.django_db(transaction=True, databases=["default", "owner"])
_SENSITIVE_ENV_MARKERS = ("PASSWORD", "SECRET", "TOKEN", "KEY", "URL", "DSN")  # 실패 메시지 가림 대상 이름
_SECRET_NAME_MARKERS = ("PASSWORD", "SECRET", "TOKEN", "KEY")  # 기동 하위 프로세스에 새 난수로 넣는 env 이름(K19)
# 64자 — Django SECRET_KEY 권장 50자 이상 · 설정은 비밀 형식·길이를 검사하지 않는다는 T072 가정 ⑥.
FRESH_SECRET_BYTES = 48
# 새 난수로 바꾸지 않는 env 이름: GIT_CONFIG_*(KEY · VALUE · COUNT 묶음 — KEY만 난수가 되면 자식이 부르는 git이 설정 파싱에
# 실패하고 그 값을 stderr에 찍어 위생 단언이 정상 구현에 거짓 양성을 낸다) · 경로형(SSLKEYLOGFILE처럼 이름에 KEY가 든 경로).
# 부분 문자열 표식 자체는 유지한다(PGPASSWORD처럼 밑줄 경계 없는 실제 비밀 이름이 있다).
_FRESH_SKIP_PREFIXES = ("GIT_CONFIG_",)
_FRESH_SKIP_SUFFIXES = ("FILE", "PATH", "DIR")
SECRET_WINDOW = 12  # 잘린 표현의 조각을 잡는 길이 — 우연 일치 확률 64^-12 · 오라클 r2 검증 꼴
# pydantic 문자열 표현의 값 표식([type=…, input_value=…, input_type=…]) — 산문 · 주석 · 식별자와 우연히 맞지 않게 `=`까지
# 본다(hide_input_in_errors=True면 이 부분이 빠진다 · errors() 덤프는 키가 'input'이라 값 · 조각 단언이 잡는다).
PYDANTIC_INPUT_MARK = "input_value="
_PROXY_ENV = ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")


class DragonflyFixture(Protocol):
    """T072 가정 ② — 템플릿 conftest `dragonfly`(세션)에서 이 파일이 쓰는 속성."""

    host: str
    port: int
    admin_url: str


class JwksFixture(Protocol):
    """T072 가정 ② — 템플릿 conftest `jwks_server`(세션)에서 이 파일이 쓰는 속성."""

    base_url: str
    jwks_url: str
    authentik_key: Any
    access_key: Any
    hits: dict[str, int]


# --- 헬퍼: 모델 · 시각 · 행 ------------------------------------------------------------------------------------------------


def _model(table: str) -> Any:
    """db_table이 table인 모델 — apps.get_models()에서 정확히 하나여야 한다(T073 가정 ③ · 모듈 경로 무관)."""
    found = [model for model in apps.get_models() if model._meta.db_table == table]
    assert len(found) == 1, f"db_table {table!r} 모델 수 {len(found)}"
    return found[0]


def _rows(table: str) -> list[Any]:
    return list(_model(table).objects.all())


def _count(table: str) -> int:
    count: int = _model(table).objects.count()
    return count


def _db_now() -> datetime:
    """default 연결의 `SELECT now()`(aware) — 경계 시각은 전부 이것 기준이다(Python 시계 금지 — T061 교훈)."""
    with connections["default"].cursor() as cursor:
        cursor.execute("SELECT now()")
        (now,) = cursor.fetchone()
    return now


def _floor(value: datetime) -> int:
    return math.floor(value.timestamp())


def _at(epoch: int) -> datetime:
    return datetime.fromtimestamp(epoch, UTC)


def _remaining(expires_at: datetime, now: datetime) -> int:
    """남은 TTL = expires_at − now 초 내림(계약 §주기 작업)."""
    return math.floor((expires_at - now).total_seconds())


def _tenant(tenant_id: str, *, slug: str | None = None, display_name: str | None = None) -> Any:
    """Tenant 행(이미 있으면 그대로) — status active."""
    model = _model("tenant")
    existing = model.objects.filter(pk=tenant_id).first()
    if existing is not None:
        return existing
    slug = slug or TENANT_SLUGS.get(tenant_id) or f"t-{tenant_id[-8:]}"
    return model.objects.create(id=tenant_id, slug=slug, display_name=display_name or slug, status="active")


def _member(sub: str, tenant_id: str, role: str = "member") -> Any:
    """TenantMembership 행(Tenant 행이 없으면 먼저 만든다 — /tenants/me가 Tenant를 읽는다)."""
    _tenant(tenant_id)
    return _model("tenant_membership").objects.create(tenant_id=tenant_id, sub=sub, role=role)


def _log_row(sub: str, *, nbf: datetime, sid: str | None = None, reason: str = "logout_all") -> Any:
    """session_revocation_log 행(테넌트 A · expires_at = nbf + 330 s · event_pk 없음)."""
    return _model("session_revocation_log").objects.create(
        tenant_id=TENANT_A,
        sub=sub,
        sid=sid,
        reason=reason,
        nbf=nbf,
        expires_at=nbf + timedelta(seconds=DENYLIST_TTL_S),
    )


def _assert_event(row: Any, *, tenant: str, sub: str, sid: str | None, nbf: int, reason: str) -> None:
    """outbox 행 = identity-admin.session.revoked 봉투(contracts/events.md §봉투 · §SP-1 스키마 표)."""
    payload = row.payload if isinstance(row.payload, dict) else json.loads(row.payload)
    assert (row.topic, row.partition_key) == (TOPIC, tenant)
    header = (payload.get("type"), payload.get("source"), payload.get("subject"), payload.get("tenantid"))
    assert header == (TOPIC, SOURCE, f"user:{sub}", tenant)
    assert payload.get("data") == {"sub": sub, "sid": sid, "nbf": nbf, "reason": reason}


# --- 헬퍼: 자격 · 요청 ----------------------------------------------------------------------------------------------------


def _access(jwks: JwksFixture, **overrides: Any) -> str:
    """Access 키로 서명한 Cf-Access-Jwt-Assertion(기본 = 유효 서비스 토큰 · aud M2M · common_name = 설정값)."""
    return mint(access_claims(**overrides), jwks.access_key, ACCESS_KID)


def _bearer(
    jwks: JwksFixture,
    sub: str,
    tenant: str | None,
    *,
    sid: str | None = "sid-1",
    groups: Any = None,
    iat: int | None = None,
) -> str:
    """Authentik 키로 서명한 Bearer(iss = 설정 AUTHENTIK_ISSUER · aud identity-admin). None인 값은 클레임을 뺀다."""
    claims: dict[str, Any] = {"sub": sub, "tenant_id": tenant, "sid": sid, "groups": groups}
    if iat is not None:
        claims.update(iat=iat, exp=iat + TOKEN_TTL_S)
    return mint(bearer_claims(**claims), jwks.authentik_key, AUTHENTIK_KID)


def _headers(
    jwks: JwksFixture,
    host: str,
    *,
    access: bool | str = True,
    bearer: str | None = None,
    extra: Mapping[str, str] | None = None,
) -> dict[str, str]:
    """요청 헤더 — Host는 늘 명시한다(시험이 ALLOWED_HOSTS를 덮어 testserver가 빠진다). access=True면 유효 Access를 만든다."""
    headers = {"host": host}
    if access is True:
        headers["Cf-Access-Jwt-Assertion"] = _access(jwks)
    elif isinstance(access, str):
        headers["Cf-Access-Jwt-Assertion"] = access
    if bearer is not None:
        headers["Authorization"] = f"Bearer {bearer}"
    if extra:
        headers.update(extra)
    return headers


def _check_path(sub: str, iat: int, sid: str | None = None) -> str:
    params = {"sub": sub, "iat": str(iat)}
    if sid is not None:
        params["sid"] = sid
    return f"{CHECK_PATH}?{urlencode(params)}"


def _fail_without_trace(what: str, exc: BaseException) -> NoReturn:
    """예외를 원 트레이스백·메시지 없이 실패로 바꾼다(pytrace=False — T063 꼴).

    pytest 긴 트레이스백은 마지막 항목의 함수 인자를 지금 값의 repr로 찍는다 — psycopg Connection.connect의 conninfo
    (비밀번호 포함)가 그 예다. 형식 이름만 싣고, 호출자는 except 블록 밖에서 부른다(연쇄된 원 예외가 남지 않게).
    """
    kind = f"{type(exc).__module__}.{type(exc).__name__}"
    if isinstance(exc, RuntimeError) and str(exc).startswith("Database access not allowed"):
        # pytest-django DB 차단기의 고정 문구(비밀 없음) — DB 마크가 없는 테스트의 경로가 DB에 닿았다는 뜻이다.
        pytest.fail(f"{what}: DB 마크가 없는 경로가 DB에 닿았다(pytest-django 차단 · {kind})", pytrace=False)
    pytest.fail(f"{what}: 예외로 끝났다({kind}) — 원 트레이스백·메시지는 비밀 노출을 막으려고 싣지 않는다", pytrace=False)


def _request(client: Client, method: str, path: str, **kwargs: Any) -> HttpResponse:
    """시험 Client 요청 한 번 — 예외(시험 Client는 뷰 예외를 다시 던진다)는 원 트레이스백 없이 실패로 바꾼다."""
    try:
        response: HttpResponse = getattr(client, method)(path, **kwargs)
    except Exception as exc:  # noqa: BLE001 — 어떤 예외든 원 트레이스백 없이 실패로 바꾼다
        failure = exc
    else:
        return response
    _fail_without_trace(f"{method.upper()} {path.split('?')[0]}", failure)


def _get(client: Client, path: str, headers: dict[str, str]) -> HttpResponse:
    return _request(client, "get", path, headers=headers)


def _post_json(client: Client, path: str, headers: dict[str, str], body: Any) -> HttpResponse:
    """JSON 본문 POST — body가 str이면 그대로 보낸다(JSON이 아닌 본문 시험)."""
    data = body if isinstance(body, str) else json.dumps(body)
    return _request(client, "post", path, data=data, content_type="application/json", headers=headers)


def _webhook_headers(signature: str | None) -> dict[str, str]:
    """웹훅 요청 헤더 — svc 호스트 · 자격 헤더 없음(면제 경로) · 서명(있으면)."""
    headers = {"host": SVC_HOST}
    if signature is not None:
        headers[SIGNATURE_HEADER] = signature
    return headers


def _post_webhook(client: Client, body: bytes, signature: str | None) -> HttpResponse:
    return _request(
        client, "post", WEBHOOK_PATH, data=body, content_type="application/json", headers=_webhook_headers(signature)
    )


def _signed(sub: str, **overrides: Any) -> tuple[dict[str, Any], bytes]:
    """유효한 웹훅 본문 dict와 그 바이트(tests._jwt.webhook_body — pk는 매번 새 uuid4)."""
    data = webhook_body(sub=sub, **overrides)
    return data, json.dumps(data).encode()


def _timed(fn: Callable[[], Any], limit: float = HANG_LIMIT_S) -> tuple[Any, float]:
    """fn()을 데몬 스레드에서 돌리고 (결과, 경과 초)를 준다 — limit 안에 끝나지 않으면 유한한 실패로 끝낸다.

    스레드 안의 DB 연결은 그 스레드 것이다(settings.DATABASES의 같은 dict로 새로 연다) — 끝에 connections.close_all()로
    자기 연결만 닫는다. 스레드 안의 예외는 원 트레이스백 없이 실패로 바꾼다(pytest 실패 자체는 그대로 다시 던진다).
    """
    outcome: list[Any] = []

    def run() -> None:
        try:
            outcome.append(fn())
        except BaseException as exc:  # noqa: BLE001 — 스레드 경계: 어떤 예외든 호출 스레드로 넘긴다
            outcome.append(exc)
        finally:
            connections.close_all()

    worker = threading.Thread(target=run, name="ia-timed", daemon=True)
    start = time.perf_counter()
    worker.start()
    worker.join(limit)
    elapsed = time.perf_counter() - start
    if worker.is_alive():
        pytest.fail(f"{limit:.0f} s 안에 끝나지 않았다 — 의존 조회·위임에 시간 초과가 없는 구현인가", pytrace=False)
    result = outcome[0]
    if isinstance(result, pytest.fail.Exception):
        raise result
    if isinstance(result, BaseException):
        _fail_without_trace("시간 상한 요청", result)
    return result, elapsed


def _response_text(response: HttpResponse) -> str:
    """응답 본문 + 헤더 전체(노출 검사용)."""
    headers = "\n".join(f"{name}: {value}" for name, value in response.items())
    return f"{response.content.decode('utf-8', errors='replace')}\n{headers}"


def _assert_absent(where: str, text: str, *needles: str) -> None:
    """needles(비밀번호 · 자격이 든 URL · 토큰)가 text 어디에도 없다.

    값이 실패 출력에 실리지 않게 두 겹으로 막는다(T062 _assert_no_leak · T063 _assert_absent와 같다): 인자를 Secret으로 다시
    묶고(repr 가림) · 위치 번호 목록으로 접어 단언한다.
    """
    text = Secret(text)
    needles = tuple(Secret(needle) for needle in needles)
    leaked = [index for index, needle in enumerate(needles) if needle and needle in text]
    assert leaked == [], f"{where}에 민감 값이 있다(needles 위치 {leaked})"


def _health(response: HttpResponse) -> tuple[Any, dict[str, Any], dict[str, Any]]:
    """/health 본문의 status · 항목별 status(checks 키는 정확히 db · dragonfly · kafka_producer) · 본문."""
    body: dict[str, Any] = json.loads(response.content)
    checks = body.get("checks")
    assert isinstance(checks, dict)
    assert set(checks) == CHECK_NAMES
    statuses = {name: check.get("status") if isinstance(check, dict) else None for name, check in checks.items()}
    return body.get("status"), statuses, body


@contextmanager
def _db_down(port: int | None = None) -> Iterator[Secret]:
    """default 별칭을 응답 없는 127.0.0.1 포트로 돌려 DB 다운을 흉내 낸다 · 끝나면 되돌린다 · app role 비밀번호(Secret)를 준다.

    port가 없으면 닫힌 포트(api-3 — 연결 거부 또는 연결 시간 초과) · 있으면 그 포트(api-52 — 블랙홀: 연결된 뒤
    connect_timeout까지 기다린다). connection.settings_dict는 settings.DATABASES["default"]와 같은 dict라 작업 스레드의 새
    연결에도 유효하다 · HOST도 127.0.0.1로 둔다(`localhost`는 ::1 시도가 먼저라 판정이 두 배가 된다 — T063 실측).
    """
    connection = connections["default"]
    original = deepcopy(connection.settings_dict)
    try:
        connection.close()
        connection.settings_dict["HOST"] = "127.0.0.1"
        connection.settings_dict["PORT"] = str(closed_port() if port is None else port)
        options = dict(original.get("OPTIONS") or {})
        connection.settings_dict["OPTIONS"] = {**options, "connect_timeout": DB_DOWN_CONNECT_TIMEOUT_S}
        yield Secret(str(original.get("PASSWORD") or ""))
    finally:
        connection.close()
        connection.settings_dict.clear()
        connection.settings_dict.update(original)


def _unreachable_dragonfly(port: int | None = None) -> tuple[Secret, Secret]:
    """응답 없는 127.0.0.1 포트(없으면 닫힌 포트 · 있으면 그 포트 — 블랙홀)를 가리키는 ia 모양 Dragonfly URL과 그
    비밀번호(랜덤 · 노출 단언용 · 둘 다 Secret)."""
    password = Secret(secrets.token_urlsafe(16))
    target = closed_port() if port is None else port
    return Secret(f"redis://{IA_DRAGONFLY_USER}:{password}@127.0.0.1:{target}/0"), password


def _get_int(client: redis.Redis, key: str) -> int | None:
    value = client.get(key)
    return None if value is None else int(value)


def _denylist_keys(client: redis.Redis) -> list[str]:
    """지금 있는 거부 목록 키(`revoked:*`) — 정렬."""
    return sorted(key.decode() for key in client.scan_iter(match="revoked:*", count=1000))


def _counter(reason: str) -> float:
    """session_revocations_total{reason} 현재 값(아직 없으면 0) — 전후 차이로 단언한다."""
    return REGISTRY.get_sample_value(METRIC, {"reason": reason}) or 0.0


def _align_second() -> None:
    """현재 시각의 소수부가 0.3 미만이 될 때까지 짧게 잔다(최대 1.5 s) — 같은 초 안에 발급·처리가 끝나게."""
    deadline = time.monotonic() + 1.5
    while time.time() % 1 >= 0.3 and time.monotonic() < deadline:
        time.sleep(0.01)


# --- 헬퍼: Celery · 명령 · 하위 프로세스 · OpenAPI ----------------------------------------------------------------------------


def _celery_app() -> Any:
    """identity_admin.celery.app(지연 import — 실패가 테스트별로 보인다) + worker·beat처럼 기본 모듈 적재(autodiscover)."""
    app = importlib.import_module("identity_admin.celery").app
    app.loader.import_default_modules()
    return app


def _run_task(name: str) -> None:
    """등록된 작업을 같은 프로세스에서 한 번 돌린다(app.tasks[name].apply() — 브로커 없음) · 성공이어야 한다.

    실패 메시지는 예외 종류와 메시지 첫 줄(200자)만 싣는다.
    """
    task = _celery_app().tasks.get(name)
    assert task is not None, f"Celery 작업 {name}이 등록되지 않았다"
    failure: BaseException | None = None
    try:
        result = task.apply()
    except Exception as exc:  # noqa: BLE001 — task_eager_propagates 구성에서도 같은 실패 모양으로
        failure = exc
    else:
        if result.successful():
            return
        outcome = result.result
        failure = outcome if isinstance(outcome, BaseException) else RuntimeError(type(outcome).__name__)
    lines = str(failure).splitlines()
    first = lines[0][:200] if lines else ""
    pytest.fail(f"{name} 실패: {type(failure).__name__}: {first}", pytrace=False)


_SEED_USERS: dict[int, dict[str, Any]] = {
    101: {"pk": 101, "uuid": SEED_OWNER, "username": "owner", "attributes": {"existing": "keep"}},
    102: {"pk": 102, "uuid": SEED_MEMBER, "username": "member", "attributes": {}},
}


def _seed_fakes(fake_authentik: FakeAuthentik, *, group: bool = True, users: tuple[int, ...] = (101, 102)) -> None:
    """가짜 Authentik 시드 전제 — 미끼가 정답보다 앞에 온다(B-1 · K18):
    그룹 = authentik Admins(superuser · 소속 akadmin) · platform-admin(소속 없음) · (group이면) tenant:<T>(소속 없음) /
    사용자 = akadmin(pk 1 · 미끼) + users(101 = owner sub · 기존 attributes {"existing": "keep"} · 102 = member sub · {}).
    필터 없이 목록을 받아 첫 결과를 쓰는 구현은 미끼를 고른다(_assert_decoys_untouched가 잡는다)."""
    groups: list[dict[str, Any]] = [
        {"name": DECOY_ADMINS_GROUP, "users": [DECOY_ADMIN_PK], "is_superuser": True},
        {"name": DECOY_PLATFORM_GROUP, "users": []},
    ]
    if group:
        groups.append({"name": SEED_GROUP, "users": []})
    decoy = {"pk": DECOY_ADMIN_PK, "uuid": DECOY_ADMIN_UUID, "username": "akadmin", "attributes": {"keep": "admin"}}
    fake_authentik.reset(groups=groups, users=[decoy, *(_SEED_USERS[pk] for pk in users)])


def _decoy_state(fake_authentik: FakeAuthentik) -> tuple[Any, ...]:
    """미끼 상태 — (authentik Admins 소속 · platform-admin 소속 · akadmin attributes)."""
    return (
        fake_authentik.group_users(DECOY_ADMINS_GROUP),
        fake_authentik.group_users(DECOY_PLATFORM_GROUP),
        fake_authentik.user(DECOY_ADMIN_PK)["attributes"],
    )


def _assert_decoys_untouched(fake_authentik: FakeAuthentik) -> None:
    """미끼 불변 — authentik Admins 소속 {1} · platform-admin 소속 없음 · akadmin attributes {"keep": "admin"}(필터 없는
    조회의 첫 결과를 쓰는 시드는 여기를 바꾼다)."""
    assert _decoy_state(fake_authentik) == ({DECOY_ADMIN_PK}, set(), {"keep": "admin"})


def _lookup_queries(fake_authentik: FakeAuthentik, path: str, key: str) -> list[list[str] | None]:
    """가짜 Authentik이 받은 목록 GET(path) 각각의 질의 값 key(없으면 None) — data-model §1 `?name=` · `?uuid=` 단언용."""
    return [r.query.get(key) for r in fake_authentik.requests if r.method == "GET" and r.path == path]


def _seed(*, stdout: io.StringIO | None = None, stderr: io.StringIO | None = None) -> None:
    """`seed_tenant --tenant-id <T> --owner-sub <S1> --member-sub <S2>` — CommandError는 그대로 올리고 그 밖의 예외는 원
    트레이스백 없이 실패로 바꾼다. 명령이 없으면 먼저 실패한다(없는 명령의 CommandError가 기대 실패로 통과하지 않게)."""
    assert "seed_tenant" in get_commands(), "seed_tenant 관리 명령이 없다"
    failure: BaseException | None = None
    try:
        call_command(
            "seed_tenant",
            "--tenant-id",
            SEED_TENANT,
            "--owner-sub",
            SEED_OWNER,
            "--member-sub",
            SEED_MEMBER,
            stdout=stdout or io.StringIO(),
            stderr=stderr or io.StringIO(),
        )
    except CommandError:
        raise
    except Exception as exc:  # noqa: BLE001 — 어떤 예외든 원 트레이스백 없이 실패로 바꾼다
        failure = exc
    if failure is not None:
        _fail_without_trace("seed_tenant", failure)


def _seed_state(fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga) -> tuple[Any, ...]:
    """시드 결과 스냅숏 — Tenant · 멤버십(id 포함) · 행 수 · 그룹 소속 · 사용자 attributes · 미끼 상태 · FGA 튜플."""
    tenants = frozenset((str(t.pk), t.slug, t.display_name, t.status) for t in _rows("tenant"))
    memberships = frozenset((str(m.pk), str(m.tenant_id), m.sub, m.role) for m in _rows("tenant_membership"))
    attributes = (fake_authentik.user(101)["attributes"], fake_authentik.user(102)["attributes"])
    return (
        tenants,
        memberships,
        _count("tenant"),
        _count("tenant_membership"),
        fake_authentik.group_users(SEED_GROUP),
        attributes,
        _decoy_state(fake_authentik),
        frozenset(fake_openfga.tuples),
    )


# 기동 하위 프로세스(cwd = pod 루트): 공개 DNS 가드 안에서 django.setup() → ROOT_URLCONF import → script prefix를 읽고, 가드
# 기록을 finally에서 DNS_MARK 줄로 싣는다(실패 기동에도 남는다) · 성공이면 설정 값 JSON 한 줄(BOOT_MARK — 없는 이름은
# MISSING_SETTING · script_prefix = 기동 직후 django.urls.get_script_prefix()).
BOOT_SCRIPT = f"""
import json
from importlib import import_module

from tests._identity_fakes import public_dns_guard

with public_dns_guard() as attempts:
    try:
        import django
        from django.conf import settings
        from django.urls import get_script_prefix

        django.setup()
        import_module(settings.ROOT_URLCONF)
        prefix = get_script_prefix()
    finally:
        print({DNS_MARK!r} + json.dumps(list(attempts)), flush=True)
values = {{name: getattr(settings, name, {MISSING_SETTING!r}) for name in {BOOT_SETTINGS!r}}}
values["script_prefix"] = prefix
print({BOOT_MARK!r} + json.dumps(values, default=str), flush=True)
"""


def _redact_env(text: str, env: Mapping[str, str], extra: tuple[str, ...] = ()) -> str:
    """text에서 비밀처럼 보이는 env 값(이름에 PASSWORD · SECRET · TOKEN · KEY · URL · DSN)과 extra 값을 가린다 — 긴 값부터
    가린다(한 값이 다른 값의 부분 문자열이어도 긴 값의 꼬리가 드러나지 않게)."""
    values = {
        value
        for name, value in env.items()
        if value and len(value) >= 4 and any(marker in name.upper() for marker in _SENSITIVE_ENV_MARKERS)
    }
    values.update(value for value in extra if value)
    for value in sorted(values, key=len, reverse=True):
        text = text.replace(value, "***")
    return text


def _url_password(value: str) -> str | None:
    """value가 비밀번호가 든 URL이면 그 비밀번호(아니면 None — URL이 아닌 값도 None)."""
    try:
        return urlsplit(value).password or None
    except ValueError:
        return None


def _with_password(value: str, password: str) -> str:
    """URL value의 비밀번호만 password로 바꾼다(스킴 · 사용자 · 호스트 · 경로 · 질의는 그대로)."""
    parts = urlsplit(value)
    userinfo, _, hostport = parts.netloc.rpartition("@")
    user = userinfo.split(":", 1)[0]
    return urlunsplit(parts._replace(netloc=f"{user}:{password}@{hostport}"))


def _fresh_secrets(env: dict[str, str], keep: frozenset[str]) -> tuple[str, ...]:
    """env의 비밀을 새 난수(URL-safe 64자)로 바꿔 넣고 넣은 값들을 준다(K19 · K29 — keep의 이름은 그대로 둔다).

    대상: 이름에 PASSWORD · SECRET · TOKEN · KEY가 든 비어 있지 않은 값(값 전체) · 비밀번호가 든 URL 값(비밀번호 부분만 — URL
    모양은 유지한다). 건너뛰는 이름: GIT_CONFIG_* 묶음 · 끝이 FILE · PATH · DIR인 경로형 이름(_FRESH_SKIP_*). 기동 출력에 이
    값들이 없음을 단언한다(rules/django-pod.md §Settings — 기동 실패 메시지는 설정 이름만): pydantic ValidationError의
    input_value는 긴 표현을 앞뒤만 남기고 잘라도 조각이 실린다 → 값 전체 + 12자 조각 + `input_value=` 표식(pydantic 표기)으로
    본다(_assert_boot_hygiene). 이름에 표식이 든 env 값은 자식에게 가지 않는다(표식 없는 이름 — `*_AUTH` · `*_PWD` 등 — 은
    그대로 간다 · 경로형 · GIT_CONFIG_*는 그대로 둔다).
    """
    inserted: list[str] = []
    for name, value in list(env.items()):
        upper = name.upper()
        if name in keep or not value or upper.startswith(_FRESH_SKIP_PREFIXES) or upper.endswith(_FRESH_SKIP_SUFFIXES):
            continue
        if any(marker in upper for marker in _SECRET_NAME_MARKERS):
            env[name] = fresh = secrets.token_urlsafe(FRESH_SECRET_BYTES)
        elif _url_password(value) is not None:
            fresh = secrets.token_urlsafe(FRESH_SECRET_BYTES)
            env[name] = _with_password(value, fresh)
        else:
            continue
        inserted.append(fresh)
    return tuple(inserted)


def _windows(values: Iterable[str], size: int = SECRET_WINDOW) -> tuple[str, ...]:
    """values 중 길이가 size 이상인 값 각각의 모든 size자 조각(중복 제거 · 순서 유지) — 잘린 표현에 실린 비밀 조각을 찾는
    needles(K28)."""
    pieces = (
        value[start : start + size] for value in values if len(value) >= size for start in range(len(value) - size + 1)
    )
    return tuple(dict.fromkeys(pieces))


@dataclass(frozen=True)
class BootResult:
    """하위 프로세스 기동 결과 — 출력 · env · 넣은 비밀은 repr에서 뺀다(단언 실패 출력에 실리지 않게)."""

    returncode: int
    stdout: str = field(repr=False)
    stderr: str = field(repr=False)
    env: dict[str, str] = field(repr=False)
    secrets: tuple[str, ...] = field(repr=False, default=())

    def summary(self) -> str:
        """종료 코드 + stderr 마지막 한 줄(env 비밀 값 · 넣은 비밀 가림 · 300자)."""
        lines = [line for line in self.stderr.splitlines() if line.strip()]
        last = _redact_env(lines[-1], self.env, self.secrets)[:300] if lines else ""
        return f"종료 코드 {self.returncode} · stderr 마지막 줄: {last}"


def _boot(overrides: Mapping[str, str], remove: tuple[str, ...] = ()) -> BootResult:
    """pod 설정으로 새 프로세스를 띄운다(BOOT_SCRIPT — 공개 DNS 가드 안 django.setup() → ROOT_URLCONF import).

    env = 이 프로세스의 os.environ(T072 가정 ⑥ — 래퍼가 채운 env 키 전부 · dns_guard가 끈 프록시 env 포함) +
    DJANGO_SETTINGS_MODULE=identity_admin.settings + PYTHONPATH 앞에 pod 루트 − SSLKEYLOGFILE(자식은 TLS 키 로그가 필요
    없다 — 있으면 SSL 컨텍스트를 만들 때 그 경로에 파일이 생긴다 · 상대 경로면 cwd = pod 루트) · 비밀은 새 난수
    (_fresh_secrets — overrides · remove 이름은 제외) + overrides − remove · cwd = pod 루트 · shell 없음 · 시간 상한 120 s
    (넘으면 유한한 실패).
    """
    env = dict(os.environ)
    env["DJANGO_SETTINGS_MODULE"] = "identity_admin.settings"
    env["PYTHONPATH"] = os.pathsep.join(part for part in (str(POD_ROOT), env.get("PYTHONPATH", "")) if part)
    env["PYTHONIOENCODING"] = "utf-8"
    env.pop("SSLKEYLOGFILE", None)
    inserted = _fresh_secrets(env, frozenset(overrides) | frozenset(remove))
    env.update(overrides)
    for name in remove:
        env.pop(name, None)
    completed: subprocess.CompletedProcess[str] | None
    try:
        completed = subprocess.run(  # noqa: S603 — 인자 고정 · shell 없음 · 이 프로세스의 인터프리터
            [sys.executable, "-c", BOOT_SCRIPT],
            cwd=POD_ROOT,
            env=env,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=BOOT_TIMEOUT_S,
            check=False,
            shell=False,
        )
    except subprocess.TimeoutExpired:
        completed = None  # 실패는 except 밖에서 낸다(명령 줄 · 부분 출력이 연쇄 예외로 실리지 않게)
    if completed is None:
        pytest.fail(f"기동이 {BOOT_TIMEOUT_S} s 안에 끝나지 않았다", pytrace=False)
    return BootResult(completed.returncode, completed.stdout, completed.stderr, env, inserted)


def _assert_boot_hygiene(result: BootResult) -> None:
    """기동 위생 — 공개 이름 조회 0(DNS_MARK 줄 · 실패 기동에도 있다 · 없으면 요약과 함께 실패) · 기동 출력(stdout +
    stderr)에 넣은 비밀이 없다: pydantic ValidationError의 input_value는 긴 표현을 앞뒤만 남기고 잘라도 조각이 실린다(필수값
    누락이면 env 사전 마지막 값의 꼬리) → 값 전체 + 12자 조각(_windows) + `input_value=` 표식(PYDANTIC_INPUT_MARK — pydantic
    표기 · 산문 · 주석과 우연히 맞지 않게 · 키 순서와 무관한 보강)으로 본다. 표식 단언도 기동 출력(stdout · stderr) 전체를
    본다 — 기동 실패 메시지 · 로그 · 트레이스백이 찍는 소스 줄(raise 문 전체 · 그 줄 끝 주석)에 `input_value=` 글자를 두지
    않는다(T072 · T073).
    표식 단언은 bool로 접는다(`assert PYDANTIC_INPUT_MARK not in output`은 pytest 단언 재작성이 출력 본문을 실패 메시지에
    싣는다)."""
    lines = [line for line in result.stdout.splitlines() if line.startswith(DNS_MARK)]
    assert len(lines) == 1, f"DNS 가드 기록 줄 수 {len(lines)} · {result.summary()}"
    attempts = json.loads(lines[0][len(DNS_MARK) :])
    assert attempts == [], f"기동 중 공개 호스트 이름 조회: {sorted(set(attempts))}"
    output = result.stdout + result.stderr
    _assert_absent("기동 출력", output, *result.secrets)
    _assert_absent("기동 출력(비밀 조각)", output, *_windows(result.secrets))
    leaked = PYDANTIC_INPUT_MARK in output
    assert not leaked, (
        "기동 출력에 pydantic `input_value=`(설정 값 되풀이)가 있다 — 이름만 싣고 from None으로 끊는다"
        "(hide_input_in_errors=True도 둔다)"
    )


def _boot_values(result: BootResult) -> dict[str, Any]:
    """기동 성공(종료 0) · 기동 위생 · 값 JSON 한 줄을 확인하고 그 값을 준다."""
    assert result.returncode == 0, result.summary()
    _assert_boot_hygiene(result)
    lines = [line for line in result.stdout.splitlines() if line.startswith(BOOT_MARK)]
    assert len(lines) == 1, f"값 줄 수 {len(lines)} · {result.summary()}"
    values: dict[str, Any] = json.loads(lines[0][len(BOOT_MARK) :])
    return values


def _assert_boot_refused(result: BootResult) -> None:
    """기동이 ImproperlyConfigured로 멈췄다(종료 코드 0 아님 + stderr에 ImproperlyConfigured) · 기동 위생(실패 출력에도 설정
    값이 없다 — rules/django-pod.md §Settings)."""
    refused = result.returncode != 0 and "ImproperlyConfigured" in result.stderr
    assert refused, f"기동이 ImproperlyConfigured로 멈추지 않았다 — {result.summary()}"
    _assert_boot_hygiene(result)


def _kebab(name: str) -> str:
    """설정 이름 → 테스트 id(소문자 kebab — api-47 · 55)."""
    return name.lower().replace("_", "-")


def _deref(spec: dict[str, Any], node: Any) -> Any:
    """OpenAPI 노드의 `$ref`(문서 안 JSON 포인터)와 원소 하나짜리 allOf를 따라간다."""
    for _ in range(32):
        if isinstance(node, dict) and "$ref" in node:
            ref = node["$ref"]
            assert isinstance(ref, str) and ref.startswith("#/"), f"문서 밖 $ref: {ref!r}"
            target: Any = spec
            for part in ref[2:].split("/"):
                target = target[part.replace("~1", "/").replace("~0", "~")]
            node = target
        elif isinstance(node, dict) and isinstance(node.get("allOf"), list) and len(node["allOf"]) == 1:
            node = node["allOf"][0]
        else:
            return node
    raise AssertionError("$ref가 순환한다")


def _alternatives(spec: dict[str, Any], node: Any) -> list[dict[str, Any]]:
    """노드 자체 또는 anyOf/oneOf의 null이 아닌 갈래들(각각 $ref 해석)."""
    node = _deref(spec, node)
    members = node.get("anyOf") or node.get("oneOf")
    if not members:
        return [node]
    resolved = [_deref(spec, member) for member in members]
    return [member for member in resolved if member.get("type") != "null"]


def _enum_values(spec: dict[str, Any], node: Any) -> set[Any]:
    return {value for member in _alternatives(spec, node) for value in member.get("enum", ())}


def _types(spec: dict[str, Any], node: Any) -> set[str]:
    types: set[str] = set()
    for member in _alternatives(spec, node):
        kind = member.get("type")
        types |= {kind} if isinstance(kind, str) else set(kind or ())
    return types


# --- T066 소유 픽스처 ----------------------------------------------------------------------------------------------------


@pytest.fixture(scope="session")
def ia_dragonfly(dragonfly: DragonflyFixture) -> Secret:
    """identity-admin 규칙(`~revoked:* ~identity-admin:* +@all`)의 ACL 사용자 identity-admin-test를 만들고 그 URL(Secret)을 준다.

    운영 identity-admin 사용자와 같은 규칙이다(거부 목록 읽기·쓰기 + 자기 접두). 템플릿 conftest의 사용자 이름과 무관하게
    admin 연결로 직접 만든다(D4). 비밀번호는 세션 랜덤이고 규칙 토큰도 Secret으로 넘긴다(redis-py 프레임 인자 가림).
    """
    password = Secret(secrets.token_urlsafe(24))
    admin = redis.Redis.from_url(dragonfly.admin_url)
    failure: str | None = None
    try:
        admin.execute_command("ACL", "SETUSER", IA_DRAGONFLY_USER, "on", Secret(f">{password}"), *IA_DRAGONFLY_RULES)
    except Exception as exc:  # noqa: BLE001 — 오류 메시지가 규칙 토큰(비밀번호)을 되풀이할 수 있다 → 가린 사본만
        failure = f"Dragonfly ACL 준비 실패: {type(exc).__name__}: {exc}".replace(password, "***")
    finally:
        admin.close()
    if failure is not None:
        pytest.fail(failure, pytrace=False)
    return Secret(f"redis://{IA_DRAGONFLY_USER}:{password}@{dragonfly.host}:{dragonfly.port}/0")


@pytest.fixture(scope="session")
def webhook_secret() -> Secret:
    """웹훅 HMAC 공유 비밀(세션 랜덤 · 출력하지 않는다)."""
    return Secret(secrets.token_urlsafe(32))


@pytest.fixture(scope="session")
def fake_authentik() -> Iterator[FakeAuthentik]:
    server = FakeAuthentik()
    try:
        yield server
    finally:
        server.close()


@pytest.fixture(scope="session")
def fake_openfga() -> Iterator[FakeOpenFga]:
    server = FakeOpenFga()
    try:
        yield server
    finally:
        server.close()


@pytest.fixture(autouse=True)
def _reset_fakes(fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga) -> Iterator[None]:
    """가짜 서버 상태 · 요청 기록 · 실패 주입을 테스트마다 비운다."""
    fake_authentik.reset()
    fake_openfga.reset()
    yield
    fake_openfga.fail_next_write = None


@pytest.fixture(autouse=True)
def ia_settings(
    settings: Settings,
    jwks_server: JwksFixture,
    ia_dragonfly: Secret,
    webhook_secret: Secret,
    fake_authentik: FakeAuthentik,
    fake_openfga: FakeOpenFga,
) -> Settings:
    """pod 설정을 시험 값으로 덮는다(pytest-django settings — 테스트가 끝나면 되돌린다 · 구현은 호출 시점에 읽는다).

    AUTHENTIK_WRITES_ENABLED는 계약 기본값 False(dev 꼴) — 켜는 시험(api-19 후반 · 시드 api-36·37·39·41 · api-40 · 56
    writes-on)만 켠다.
    Kafka는 닫힌 포트다(브로커 없음 — /health kafka_producer는 fail).
    """
    settings.AUTHENTIK_JWKS_URL = jwks_server.jwks_url
    settings.ACCESS_TEAM_DOMAIN = jwks_server.base_url
    settings.ACCESS_AUD_M2M = ACCESS_AUD_M2M
    settings.ACCESS_AUD_ADMIN = ACCESS_AUD_ADMIN
    settings.ACCESS_EXPECTED_CN = ACCESS_EXPECTED_CN
    settings.AUTHENTIK_ISSUER = PUBLIC_ISSUER
    settings.AUTHENTIK_AUDIENCE = "identity-admin"
    settings.AUTH_ACTOR_SUB = ""
    settings.DRAGONFLY_URL = ia_dragonfly
    settings.AUTHENTIK_WEBHOOK_SECRET = webhook_secret
    settings.ALLOWED_HOSTS = [SVC_HOST, M2M_HOST, ADMIN_HOST_VALUE]
    settings.ADMIN_HOST = ADMIN_HOST_VALUE
    settings.AUTHENTIK_API_URL = fake_authentik.base_url
    settings.AUTHENTIK_API_TOKEN = fake_authentik.token
    settings.OPENFGA_API_URL = fake_openfga.base_url
    settings.OPENFGA_STORE_ID = fake_openfga.store_id
    settings.OPENFGA_PRESHARED_KEY = fake_openfga.key
    settings.AUTHENTIK_WRITES_ENABLED = False
    settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{closed_port()}"
    return settings


@pytest.fixture(autouse=True)
def ia_flush(dragonfly: DragonflyFixture) -> None:
    """테스트마다 Dragonfly를 비운다(admin FLUSHALL) — 거부 목록 키가 테스트 사이에 새지 않게."""
    admin = redis.Redis.from_url(dragonfly.admin_url)
    try:
        admin.flushall()
    finally:
        admin.close()


@pytest.fixture
def df_admin(dragonfly: DragonflyFixture) -> Iterator[redis.Redis]:
    """Dragonfly admin 클라이언트(GET · TTL · SET · FLUSHALL) — 시험 관측·준비용."""
    client = redis.Redis.from_url(dragonfly.admin_url)
    try:
        yield client
    finally:
        client.close()


@pytest.fixture(autouse=True)
def dns_guard(monkeypatch: pytest.MonkeyPatch) -> Iterator[list[str]]:
    """공개 도메인(joshuatech.dev · 하위) 이름 조회를 막고 기록한다 — 끝나면 기록 0을 단언한다(pod는 공개 호스트를 부르지
    않는다 · FR-046 · JWKS도 svc DNS).

    프록시를 끈다: HTTP_PROXY · HTTPS_PROXY · ALL_PROXY(소문자 포함)를 지우고 NO_PROXY · no_proxy = "*" — 프록시 경유
    요청은 이름 조회가 프록시 이름으로 바뀌어 가드 밖이다(urllib은 env 프록시 사전이 비어 있지 않으면 Windows 레지스트리
    프록시를 읽지 않는다 · 기동 하위 프로세스는 이 env를 물려받는다).
    """
    for name in _PROXY_ENV:
        monkeypatch.delenv(name, raising=False)
    for name in ("NO_PROXY", "no_proxy"):
        monkeypatch.setenv(name, "*")
    with public_dns_guard() as attempts:
        yield attempts
    assert attempts == [], f"공개 호스트 이름 조회 시도: {sorted(set(attempts))}"


# --- 헬스(/healthz · /ready · /health) --------------------------------------------------------------------------------


def test_api_1_healthz(settings: Settings) -> None:
    """api-1 — /healthz(svc 호스트 · 자격 없음 · DB 마크 없음) → 200 · 본문 == {"status": "ok", "version": APP_VERSION,
    "git_sha": APP_GIT_SHA}."""
    response = _get(Client(), "/healthz", {"host": SVC_HOST})
    assert response.status_code == 200
    expected = {"status": "ok", "version": settings.APP_VERSION, "git_sha": settings.APP_GIT_SHA}
    assert json.loads(response.content) == expected


@DB
def test_api_2_dependencies_down(settings: Settings) -> None:
    """api-2 — DB 정상 + Dragonfly·Kafka 닫힌 포트 → /ready 200(DB만 본다) · /health 200 · status degraded · checks 키 정확히
    {db, dragonfly, kafka_producer} = (ok, fail, fail) · version·git_sha == 설정 · 각 요청 < 3 s · 응답에 Dragonfly 자격 없음."""
    url, password = _unreachable_dragonfly()
    settings.DRAGONFLY_URL = url
    client = Client()
    host = {"host": SVC_HOST}
    ready, ready_s = _timed(lambda: client.get("/ready", headers=host))
    health, health_s = _timed(lambda: client.get("/health", headers=host))
    assert ready.status_code == 200
    assert health.status_code == 200
    status, checks, body = _health(health)
    assert status == "degraded"
    assert (checks["db"], checks["dragonfly"], checks["kafka_producer"]) == ("ok", "fail", "fail")
    assert (body.get("version"), body.get("git_sha")) == (settings.APP_VERSION, settings.APP_GIT_SHA)
    elapsed = {"/ready": round(ready_s, 2), "/health": round(health_s, 2)}
    assert [path for path, seconds in elapsed.items() if seconds >= DOWN_LIMIT_S] == [], f"경과(s) {elapsed}"
    for response in (ready, health):
        _assert_absent("응답", _response_text(response), url, password)


@DB
def test_api_3_db_down() -> None:
    """api-3 — DB 다운(default 별칭 → 닫힌 127.0.0.1 포트 · connect_timeout 1 → psycopg 2 s) → /ready 503 not_ready ·
    /health 200 · degraded · db fail · /healthz 200 · 각 < 3 s · 응답에 app role 비밀번호 없음(Dragonfly는 ia 사용자로 살아
    있고 Kafka는 닫힌 포트다)."""
    client = Client()
    host = {"host": SVC_HOST}
    with _db_down() as password:
        ready, ready_s = _timed(lambda: client.get("/ready", headers=host))
        health, health_s = _timed(lambda: client.get("/health", headers=host))
        healthz, healthz_s = _timed(lambda: client.get("/healthz", headers=host))
    for response in (ready, health, healthz):
        _assert_absent("응답", _response_text(response), password)
    assert_problem(ready, 503, "not_ready")
    assert health.status_code == 200
    status, checks, _ = _health(health)
    assert (status, checks["db"]) == ("degraded", "fail")
    assert healthz.status_code == 200
    elapsed = {"/ready": round(ready_s, 2), "/health": round(health_s, 2), "/healthz": round(healthz_s, 2)}
    assert [path for path, seconds in elapsed.items() if seconds >= DOWN_LIMIT_S] == [], f"경과(s) {elapsed}"


@DB
def test_api_52_health_parallel_blackholes(settings: Settings) -> None:
    """api-52 — 의존 검사 병렬(§타임아웃): DB(default 별칭 · connect_timeout 1 → psycopg 2 s) · Dragonfly(ia 모양 URL ·
    랜덤 비밀번호) · Kafka를 모두 블랙홀(listen만 하고 accept하지 않는 127.0.0.1 포트 — 연결은 되고 응답이 없다)로 → /health
    200 · degraded · (fail, fail, fail) · 경과 < 3 s / /ready 503 not_ready · 경과 < 3 s / 응답에 비밀번호 없음.

    T071 가정의 예산에서 순차 구현의 합은 2 + 0.2 + 1 = 3.2 s ≥ 3 s, 병렬이면 ≈ 2 s다(오라클 실측 병렬 2.02 s / 순차
    3.25 s). 닫힌 포트(api-3)는 Linux가 즉시 RST로 거부해 순차 구현도 3 s 안에 끝나므로 api-3만으로는 병렬성을 가리지
    못한다 — 블랙홀은 OS와 무관하게 각 검사를 자기 시간 초과까지 기다리게 한다(tests/_identity_fakes.py blackhole). 측정
    전에 같은 Client로 /healthz를 한 번 보낸다(urlconf · 미들웨어 적재가 측정 창에 들지 않게 — 의존 조회 없음)."""
    client = Client()
    host = {"host": SVC_HOST}
    assert _get(client, "/healthz", host).status_code == 200
    with blackhole() as db_port, blackhole() as dragonfly_port, blackhole() as kafka_port:
        url, password = _unreachable_dragonfly(dragonfly_port)
        settings.DRAGONFLY_URL = url
        settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{kafka_port}"
        with _db_down(db_port) as db_password:
            health, health_s = _timed(lambda: client.get("/health", headers=host))
            ready, ready_s = _timed(lambda: client.get("/ready", headers=host))
    for response in (health, ready):
        _assert_absent("응답", _response_text(response), url, password, db_password)
    assert health.status_code == 200
    status, checks, _ = _health(health)
    assert status == "degraded"
    assert (checks["db"], checks["dragonfly"], checks["kafka_producer"]) == ("fail", "fail", "fail")
    assert_problem(ready, 503, "not_ready")
    elapsed = {"/health": round(health_s, 2), "/ready": round(ready_s, 2)}
    assert [path for path, seconds in elapsed.items() if seconds >= DOWN_LIMIT_S] == [], f"경과(s) {elapsed}"


# --- GET /session/check(Access 전용 경로 · DB 마크 없음) --------------------------------------------------------------------


def test_api_4_session_check_access_only(jwks_server: JwksFixture) -> None:
    """api-4 — /session/check?sub&iat(m2m 호스트 · Access만) → 200 {"active": true}(sub 키 없음 → nbf 키 없음) ·
    `Authorization: Bearer not-a-jwt`를 붙여도 같다(Access 전용 경로는 Bearer를 검증하지 않는다). DB 마크가 없다 — 뷰나
    테넌트 미들웨어가 DB에 닿으면 pytest-django가 막는다."""
    client = Client()
    path = _check_path("check-sub", int(time.time()))
    for case, extra in (("access-only", None), ("garbage-bearer", {"Authorization": "Bearer not-a-jwt"})):
        response = _get(client, path, _headers(jwks_server, M2M_HOST, extra=extra))
        assert response.status_code == 200, case
        assert json.loads(response.content) == {"active": True}, case


def test_api_5_session_check_access_required(jwks_server: JwksFixture) -> None:
    """api-5 — /session/check의 Access 검사: 없음 · common_name 다름 · aud 밖 · (유효 Bearer만 · Access 없음) → 403
    access_required."""
    client = Client()
    path = _check_path("check-sub", int(time.time()))
    bearer = _bearer(jwks_server, "check-sub", TENANT_A)
    cases = {
        "no-access": _headers(jwks_server, M2M_HOST, access=False),
        "other-common-name": _headers(jwks_server, M2M_HOST, access=_access(jwks_server, common_name="other.access")),
        "other-aud": _headers(jwks_server, M2M_HOST, access=_access(jwks_server, aud=["other"])),
        "bearer-only": _headers(jwks_server, M2M_HOST, access=False, bearer=bearer),
    }
    for case, headers in cases.items():
        response = _get(client, path, headers)
        assert response.status_code == 403, case
        assert_problem(response, 403, "access_required")


def test_api_6_session_check_sub_key(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-6 — revoked:sub:{sub} 값과 iat 비교(값 > iat일 때만 폐기 — 미들웨어 4단계와 같은 비교): 값 = iat+1 →
    {"active": false, "nbf": iat+1} · = iat → {"active": true, "nbf": iat}(경계) · = iat−100 → {"active": true,
    "nbf": iat−100}(nbf는 sub 키가 있으면 active여도 싣는다). 같은 Client로 이어 묻는다(결과를 캐시하지 않는다)."""
    sub, iat = "check-sub", int(time.time())
    client = Client()
    headers = _headers(jwks_server, M2M_HOST)
    for nbf, active in ((iat + 1, False), (iat, True), (iat - 100, True)):
        df_admin.set(f"revoked:sub:{sub}", nbf, ex=DENYLIST_TTL_S)
        response = _get(client, _check_path(sub, iat), headers)
        assert response.status_code == 200, f"nbf = iat {nbf - iat:+d}"
        assert json.loads(response.content) == {"active": active, "nbf": nbf}, f"nbf = iat {nbf - iat:+d}"


def test_api_7_session_check_sid_key(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-7 — revoked:sid:sid-x = 1 → sid 쿼리가 sid-x면 {"active": false}(sub 키가 없으니 nbf 키 없음) · sid 쿼리 없음 →
    {"active": true} · 다른 sid → {"active": true}."""
    sub, iat = "check-sub", int(time.time())
    df_admin.set("revoked:sid:sid-x", 1, ex=DENYLIST_TTL_S)
    client = Client()
    headers = _headers(jwks_server, M2M_HOST)
    for sid, expected in (("sid-x", {"active": False}), (None, {"active": True}), ("sid-other", {"active": True})):
        response = _get(client, _check_path(sub, iat, sid), headers)
        assert response.status_code == 200, sid
        assert json.loads(response.content) == expected, sid


def test_api_8_session_check_denylist_unavailable(jwks_server: JwksFixture, settings: Settings) -> None:
    """api-8 — DRAGONFLY_URL = 닫힌 포트 → 503 denylist_unavailable(fail-closed) · 경과 < 0.5 s(판정 0.2 s + 처리 여유 —
    T062 auth-17/18과 같은 근거 · 멈추는 구현은 5 s 상한에서 유한하게 실패) · 응답에 자격 없음. 측정 전에 같은 Client로
    정상 Dragonfly 요청을 한 번 보낸다(200 — urlconf · 미들웨어 · Access certs 적재가 측정 창에 들지 않게 · 단독 실행에서도
    같은 창) — 그 뒤 설정을 닫힌 포트로 바꾼다(구현은 호출 시점에 설정을 읽는다 — T073 가정 ①)."""
    client = Client()
    headers = _headers(jwks_server, M2M_HOST)
    path = _check_path("check-sub", int(time.time()))
    assert _get(client, path, headers).status_code == 200
    url, password = _unreachable_dragonfly()
    settings.DRAGONFLY_URL = url
    response, elapsed = _timed(lambda: client.get(path, headers=headers), VERDICT_HANG_LIMIT_S)
    assert_problem(response, 503, "denylist_unavailable")
    assert elapsed < DENYLIST_VERDICT_LIMIT_S, f"판정 {elapsed:.3f} s"
    _assert_absent("응답", _response_text(response), url, password)


def test_api_9_session_check_validation(jwks_server: JwksFixture) -> None:
    """api-9 — 질의 검증 실패 → 400 validation_error(RFC 9457 — Ninja 기본 422 `{detail}` 아님): sub 누락 · iat 누락 ·
    iat=abc."""
    client = Client()
    headers = _headers(jwks_server, M2M_HOST)
    iat = str(int(time.time()))
    cases = {"no-sub": {"iat": iat}, "no-iat": {"sub": "check-sub"}, "iat-abc": {"sub": "check-sub", "iat": "abc"}}
    for case, params in cases.items():
        response = _get(client, f"{CHECK_PATH}?{urlencode(params)}", headers)
        assert response.status_code == 400, case
        assert_problem(response, 400, "validation_error")


# --- POST /sessions/revoke ------------------------------------------------------------------------------------------


@DB
def test_api_10_revoke_all_devices(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-10 — 본인 {"all_devices": true, "reason": "logout_all", "sid": "sid-9"}(테넌트 A · 토큰 sid sid-1 · 본문 sid를
    함께 보내도 쓰지 않는다 — 계약 §엔드포인트 revoke) → 202 · 본문 키 정확히 {id, nbf, expires_at} · id uuid · nbf 정수 ·
    expires_at = nbf + 330 s(ISO 8601 · UTC) / 로그 1행(id == 본문 id · tenant A · sub · sid NULL · reason · nbf/expires_at ·
    event_pk NULL) / outbox 1행(topic · partition_key = A · 봉투 type · source · subject user:<sub> · tenantid = A · data
    {sub, sid: null, nbf, reason}) / revoked:sub:<sub> = nbf · TTL ∈ [325, 330] · 거부 목록 키는 그것 하나(sid-9 · sid-1 키
    없음 — all_devices는 sid 키를 쓰지 않는다) / 지표 logout_all +1."""
    sub = "self-sub"
    before = _counter("logout_all")
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_A, sid="sid-1"))
    payload = {"all_devices": True, "reason": "logout_all", "sid": "sid-9"}
    response = _post_json(Client(), REVOKE_PATH, headers, payload)
    assert response.status_code == 202
    body = json.loads(response.content)
    assert set(body) == {"id", "nbf", "expires_at"}
    revoke_id, nbf = uuid.UUID(body["id"]), body["nbf"]
    assert isinstance(nbf, int) and not isinstance(nbf, bool)
    expires_at = datetime.fromisoformat(body["expires_at"])
    assert expires_at.utcoffset() == timedelta(0)
    assert expires_at == _at(nbf + DENYLIST_TTL_S)
    (row,) = _rows("session_revocation_log")
    assert (uuid.UUID(str(row.pk)), str(row.tenant_id), row.sub, row.sid) == (revoke_id, TENANT_A, sub, None)
    assert (row.reason, row.event_pk) == ("logout_all", None)
    assert (row.nbf, row.expires_at) == (_at(nbf), _at(nbf + DENYLIST_TTL_S))
    (event,) = _rows("outbox")
    _assert_event(event, tenant=TENANT_A, sub=sub, sid=None, nbf=nbf, reason="logout_all")
    assert _get_int(df_admin, f"revoked:sub:{sub}") == nbf
    assert 325 <= df_admin.ttl(f"revoked:sub:{sub}") <= DENYLIST_TTL_S
    assert _denylist_keys(df_admin) == [f"revoked:sub:{sub}"]
    assert _counter("logout_all") == before + 1


@DB
def test_api_11_revoke_same_second(jwks_server: JwksFixture) -> None:
    """api-11 — nbf = 처리 시각 epoch 초 내림 + 1: 초 경계 정렬(소수부 < 0.3) 뒤 발급한 토큰(iat = 지금 초)으로 revoke(all
    devices) → 응답 nbf > iat · 같은 토큰으로 /tenants/me → 401 session_revoked(그 사용자의 멤버십을 미리 둔다 — 401이
    멤버십 때문이 아니다). 내림만 쓰는 구현(nbf = iat)은 이 요청을 부른 같은 초의 토큰을 살려 둔다(PyJWT는 미래 iat를
    거부하므로 iat를 앞당긴 토큰으로 시험할 수 없다 — 정렬로 같은 초를 만든다)."""
    sub = "same-second-sub"
    _member(sub, TENANT_A)
    client = Client()
    _align_second()
    iat = int(time.time())
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_A, iat=iat))
    response = _post_json(client, REVOKE_PATH, headers, {"all_devices": True, "reason": "logout_all"})
    assert response.status_code == 202
    nbf = json.loads(response.content)["nbf"]
    assert nbf > iat, f"nbf {nbf} · iat {iat}"
    assert_problem(_get(client, TENANTS_ME, headers), 401, "session_revoked")


@DB
def test_api_12_revoke_single_session(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-12 — {"all_devices": false, "reason": "logout"}(토큰 sid sid-1) → 202 · revoked:sid:sid-1 = "1" · TTL ∈
    [325, 330] · revoked:sub:<sub> 없음 · 로그 sid = sid-1 · 이벤트 data sid = sid-1 · 지표 logout +1 · 같은 토큰 →
    /tenants/me 401 session_revoked · 같은 sub의 sid-2 토큰 → /tenants/me 200(그 세션만 거부된다)."""
    sub = "single-sub"
    _member(sub, TENANT_A)
    before = _counter("logout")
    client = Client()
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_A, sid="sid-1"))
    response = _post_json(client, REVOKE_PATH, headers, {"all_devices": False, "reason": "logout"})
    assert response.status_code == 202
    nbf = json.loads(response.content)["nbf"]
    assert df_admin.get("revoked:sid:sid-1") == b"1"
    assert 325 <= df_admin.ttl("revoked:sid:sid-1") <= DENYLIST_TTL_S
    assert df_admin.exists(f"revoked:sub:{sub}") == 0
    (row,) = _rows("session_revocation_log")
    assert (row.sid, row.reason) == ("sid-1", "logout")
    (event,) = _rows("outbox")
    _assert_event(event, tenant=TENANT_A, sub=sub, sid="sid-1", nbf=nbf, reason="logout")
    assert _counter("logout") == before + 1
    assert_problem(_get(client, TENANTS_ME, headers), 401, "session_revoked")
    other = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_A, sid="sid-2"))
    assert _get(client, TENANTS_ME, other).status_code == 200


@DB
def test_api_13_revoke_body_sid(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-13 — all_devices false + 본문 sid "sid-9"(토큰 sid는 sid-1) → revoked:sid:sid-9만 생긴다(본문 sid가 우선) ·
    revoked:sid:sid-1 · revoked:sub:<sub> 없음 · 로그 sid = sid-9."""
    sub = "body-sid-sub"
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_A, sid="sid-1"))
    body = {"all_devices": False, "reason": "logout", "sid": "sid-9"}
    assert _post_json(Client(), REVOKE_PATH, headers, body).status_code == 202
    assert _denylist_keys(df_admin) == ["revoked:sid:sid-9"]
    assert df_admin.get("revoked:sid:sid-9") == b"1"
    (row,) = _rows("session_revocation_log")
    assert row.sid == "sid-9"


@DB
def test_api_14_revoke_without_sid(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-14 — all_devices false인데 토큰 sid도 본문 sid도 없음 → 400 validation_error · 로그 0 · outbox 0 · 거부 목록 키 0."""
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "no-sid-sub", TENANT_A, sid=None))
    response = _post_json(Client(), REVOKE_PATH, headers, {"all_devices": False, "reason": "logout"})
    assert_problem(response, 400, "validation_error")
    assert (_count("session_revocation_log"), _count("outbox")) == (0, 0)
    assert _denylist_keys(df_admin) == []


@DB
def test_api_15_revoke_admin_cross_tenant(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-15 — 관리자(sub admin-sub · 테넌트 A 토큰 · groups ["platform-admin"])가 테넌트 B 멤버 target-sub 폐기
    ({"sub": "target-sub", "all_devices": true, "reason": "admin"}) → 202 · 로그 tenant = B(멤버십 조회값 — 토큰 테넌트 아님) ·
    reason admin · outbox tenantid · partition_key = B · subject user:target-sub(요청의 테넌트 컨텍스트 A와 다른 tenant_id로
    publish — 컨텍스트를 대상 테넌트로 다시 두거나 비워야 OutboxUsageError가 나지 않는다) · revoked:sub:target-sub = nbf ·
    revoked:sub:admin-sub 없음 · 지표 admin +1."""
    target = "target-sub"
    _member(target, TENANT_B)
    before = _counter("admin")
    groups = ["platform-admin"]
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "admin-sub", TENANT_A, groups=groups))
    response = _post_json(Client(), REVOKE_PATH, headers, {"sub": target, "all_devices": True, "reason": "admin"})
    assert response.status_code == 202
    nbf = json.loads(response.content)["nbf"]
    (row,) = _rows("session_revocation_log")
    assert (str(row.tenant_id), row.sub, row.sid, row.reason) == (TENANT_B, target, None, "admin")
    (event,) = _rows("outbox")
    _assert_event(event, tenant=TENANT_B, sub=target, sid=None, nbf=nbf, reason="admin")
    assert _get_int(df_admin, f"revoked:sub:{target}") == nbf
    assert df_admin.exists("revoked:sub:admin-sub") == 0
    assert _counter("admin") == before + 1


@DB
@pytest.mark.parametrize(
    "groups",
    [None, ["platform-admins"], "platform-admin", ["platform-admin-x"]],
    ids=["no-groups", "platform-admins", "string", "platform-admin-x"],
)
def test_api_16_revoke_non_admin(groups: Any, jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-16 — 관리자 판정은 groups가 목록이고 원소 하나가 정확히 "platform-admin"일 때만이다: groups 없음 ·
    ["platform-admins"] · 문자열 "platform-admin"(부분 문자열 검사면 통과해 버린다) · ["platform-admin-x"] → 다른 sub(테넌트
    A 멤버 · reason admin과 logout_all 둘 다) 폐기 403 forbidden · 로그 0 · outbox 0 · 키 0 / 같은 토큰으로 자기 sub를
    적으면 본인 호출 202(로그 1 · 테넌트 A)."""
    caller, other = "plain-sub", "other-member-sub"
    _member(other, TENANT_A)
    client = Client()
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, caller, TENANT_A, groups=groups))
    for reason in ("admin", "logout_all"):
        response = _post_json(client, REVOKE_PATH, headers, {"sub": other, "all_devices": True, "reason": reason})
        assert response.status_code == 403, reason
        assert_problem(response, 403, "forbidden")
    assert (_count("session_revocation_log"), _count("outbox")) == (0, 0)
    assert _denylist_keys(df_admin) == []
    own = _post_json(client, REVOKE_PATH, headers, {"sub": caller, "all_devices": True, "reason": "logout_all"})
    assert own.status_code == 202
    (row,) = _rows("session_revocation_log")
    assert (row.sub, str(row.tenant_id)) == (caller, TENANT_A)


@DB
def test_api_17_revoke_admin_unknown_member(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-17 — 관리자 + TenantMembership이 없는 sub → 400 validation_error(대상 테넌트를 정할 수 없다) · 로그 0 · outbox 0 ·
    키 0."""
    groups = ["platform-admin"]
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "admin-sub", TENANT_A, groups=groups))
    response = _post_json(Client(), REVOKE_PATH, headers, {"sub": "ghost-sub", "all_devices": True, "reason": "admin"})
    assert_problem(response, 400, "validation_error")
    assert (_count("session_revocation_log"), _count("outbox")) == (0, 0)
    assert _denylist_keys(df_admin) == []


@DB
def test_api_51_revoke_admin_single_session(jwks_server: JwksFixture, df_admin: redis.Redis) -> None:
    """api-51 — 관리자 단일 세션 폐기(관리자 sub admin-sub · 테넌트 A · groups ["platform-admin"] · 토큰 sid admin-sid →
    테넌트 B 멤버 target-sub · all_devices false): (a) 본문 sid 없음 → 400 validation_error · 로그 0 · outbox 0 · 키 0(관리자
    호출은 "본인 호출"이 아니라 토큰 sid를 쓰지 않는다 — 계약 §엔드포인트 revoke "본문 sid, 없으면 본인 호출의 토큰 sid")
    (b) 본문 sid target-sid → 202 · 거부 목록 키는 revoked:sid:target-sid 하나(값 "1") · 로그 (tenant B · target-sub ·
    target-sid · admin) · revoked:sid:admin-sid 없음(관리자 자신의 세션을 끊는 구현은 대상을 로그인 상태로 둔다)."""
    target = "target-sub"
    _member(target, TENANT_B)
    client = Client()
    bearer = _bearer(jwks_server, "admin-sub", TENANT_A, sid="admin-sid", groups=["platform-admin"])
    headers = _headers(jwks_server, M2M_HOST, bearer=bearer)
    body = {"sub": target, "all_devices": False, "reason": "admin"}
    assert_problem(_post_json(client, REVOKE_PATH, headers, body), 400, "validation_error")
    assert (_count("session_revocation_log"), _count("outbox")) == (0, 0)
    assert _denylist_keys(df_admin) == []
    response = _post_json(client, REVOKE_PATH, headers, {**body, "sid": "target-sid"})
    assert response.status_code == 202
    assert _denylist_keys(df_admin) == ["revoked:sid:target-sid"]
    assert df_admin.get("revoked:sid:target-sid") == b"1"
    (row,) = _rows("session_revocation_log")
    assert (str(row.tenant_id), row.sub, row.sid, row.reason) == (TENANT_B, target, "target-sid", "admin")
    assert df_admin.exists("revoked:sid:admin-sid") == 0


@DB
def test_api_18_revoke_body_validation(jwks_server: JwksFixture) -> None:
    """api-18 — 본문 검증 실패 → 400 validation_error(RFC 9457 — Ninja 기본 422 · 400 `{detail}` 아님): reason 범위 밖
    (bogus) · all_devices 누락 · JSON이 아닌 본문(content_type json) → 로그 0 · outbox 0."""
    client = Client()
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "body-sub", TENANT_A))
    cases: dict[str, Any] = {
        "bogus-reason": {"all_devices": True, "reason": "bogus"},
        "no-all-devices": {"reason": "logout_all"},
        "not-json": "not json",
    }
    for case, body in cases.items():
        response = _post_json(client, REVOKE_PATH, headers, body)
        assert response.status_code == 400, case
        assert_problem(response, 400, "validation_error")
    assert (_count("session_revocation_log"), _count("outbox")) == (0, 0)


@DB
def test_api_19_revoke_never_calls_authentik_in_request(
    jwks_server: JwksFixture, settings: Settings, fake_authentik: FakeAuthentik
) -> None:
    """api-19 — 요청 처리 중 Authentik을 부르지 않는다(커밋 뒤 비동기 위임만 · 위임 실패도 202 — 계약 C3):
    (a) AUTHENTIK_WRITES_ENABLED=False(계약 기본값 · dev — 쓰기를 시도하지 않는다) → 202 · 가짜 Authentik 요청 0(직후 ·
    0.5 s 뒤) (b) True → 202 · 응답 직후 가짜 Authentik 요청 0(요청 경로의 동기 호출 금지). 시험 Celery는 eager가 아니고
    (T072 가정 ⑦ — 먼저 확인한다) 브로커 자리값이 닫힌 포트라(⑥) 위임 자체가 실패한다 — 그래도 202다(T073 가정 ⑫). 두 요청
    모두 60 s 상한 안에서 돈다(플래그와 무관하게 위임하고 작업 안에서 플래그를 보는 설계도 브로커 재시도를 겪는다 — 무한
    재시도면 멈춤 대신 유한한 실패)."""
    assert settings.AUTHENTIK_WRITES_ENABLED is False
    off = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "flag-off-sub", TENANT_A))
    first, _ = _timed(
        lambda: _post_json(Client(), REVOKE_PATH, off, {"all_devices": True, "reason": "logout_all"}),
        DELEGATION_HANG_LIMIT_S,
    )
    assert first.status_code == 202
    assert fake_authentik.requests == []
    time.sleep(0.5)
    assert fake_authentik.requests == []
    eager = _celery_app().conf.task_always_eager
    assert eager is False, "T072 가정 ⑦ — 시험 Celery는 eager가 아니어야 한다(eager면 위임이 요청 안에서 돈다)"
    settings.AUTHENTIK_WRITES_ENABLED = True
    client = Client()
    on = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "flag-on-sub", TENANT_A))
    payload = json.dumps({"all_devices": True, "reason": "logout_all"})
    second, _ = _timed(
        lambda: client.post(REVOKE_PATH, data=payload, content_type="application/json", headers=on),
        DELEGATION_HANG_LIMIT_S,
    )
    assert second.status_code == 202
    assert fake_authentik.requests == []


# --- POST /webhooks/authentik(svc 호스트 · 자격 헤더 없음) -------------------------------------------------------------------


@DB
@pytest.mark.parametrize("action", ["logout", "session_deleted"])
def test_api_20_webhook_revokes_user(action: str, df_admin: redis.Redis, webhook_secret: Secret) -> None:
    """api-20 — 테넌트 A 멤버 S의 웹훅(action logout · session_deleted · 본문 nbf = 지금 − 2 · 본문 sid sid-x) → 202 ·
    로그 1(tenant A = 멤버십 조회값 · sid NULL — 본문 sid는 쓰지 않는다(사용자 단위 fail-safe) · reason authentik_webhook ·
    nbf = 본문 nbf · event_pk = pk) · outbox 1(tenantid A · data {sub, sid: null, nbf, reason}) · revoked:sub:S = nbf ·
    TTL ∈ [320, 330] · revoked:sid:sid-x 없음 · 지표 authentik_webhook +1."""
    sub = "webhook-sub"
    _member(sub, TENANT_A)
    before = _counter("authentik_webhook")
    nbf = int(time.time()) - 2
    data, body = _signed(sub, action=action, nbf=nbf, sid="sid-x")
    response = _post_webhook(Client(), body, sign_webhook(body, webhook_secret))
    assert response.status_code == 202
    (row,) = _rows("session_revocation_log")
    assert (str(row.tenant_id), row.sub, row.sid, row.reason) == (TENANT_A, sub, None, "authentik_webhook")
    assert (row.event_pk, row.nbf, row.expires_at) == (data["pk"], _at(nbf), _at(nbf + DENYLIST_TTL_S))
    (event,) = _rows("outbox")
    _assert_event(event, tenant=TENANT_A, sub=sub, sid=None, nbf=nbf, reason="authentik_webhook")
    assert _get_int(df_admin, f"revoked:sub:{sub}") == nbf
    assert 320 <= df_admin.ttl(f"revoked:sub:{sub}") <= DENYLIST_TTL_S
    assert df_admin.exists("revoked:sid:sid-x") == 0
    assert _counter("authentik_webhook") == before + 1


@DB
def test_api_21_webhook_replay_noop(df_admin: redis.Redis, webhook_secret: Secret) -> None:
    """api-21 — 같은 바이트·서명 재전송 → 200 no-op(계약: 행·이벤트·키·지표 변화 0). 첫 202 뒤 캐시를 통째로 비운다
    (FLUSHALL — 비정상 종료로 캐시를 잃은 시나리오): 멱등은 DB unique(event_pk — data-model §3)에서 나와야 하므로 캐시를 비워도
    재전송은 no-op이다(캐시 키로 중복을 거르는 구현을 잡는다). 로그 · outbox 행 수 (1, 1) 그대로 · 거부 목록 키를 다시 쓰지
    않는다(재전송 전에 admin이 키 값을 표식으로 둔다 — 그대로 남고 키는 그것 하나 · 재전송에 다시 SET하는 구현을 잡는다) ·
    지표 불변."""
    sub = "replay-sub"
    _member(sub, TENANT_A)
    _, body = _signed(sub, nbf=int(time.time()) - 2)
    signature = sign_webhook(body, webhook_secret)
    client = Client()
    assert _post_webhook(client, body, signature).status_code == 202
    key = f"revoked:sub:{sub}"
    df_admin.flushall()
    df_admin.set(key, REPLAY_MARK, ex=DENYLIST_TTL_S)
    metric = _counter("authentik_webhook")
    replay = _post_webhook(client, body, signature)
    assert replay.status_code == 200
    assert (_count("session_revocation_log"), _count("outbox")) == (1, 1)
    assert df_admin.get(key) == REPLAY_MARK.encode()
    assert _denylist_keys(df_admin) == [key]
    assert _counter("authentik_webhook") == metric


@DB
@pytest.mark.parametrize("case", ["missing", "other-secret", "created-past", "created-future"])
def test_api_22_webhook_signature_invalid(case: str, df_admin: redis.Redis, webhook_secret: Secret) -> None:
    """api-22 — 서명 헤더 없음 · 다른 비밀로 서명 · created −330 s · +330 s(창 ±300 s 밖 · 서명은 맞다 — 처리 지연 여유
    30 s · 창 안쪽 경계는 T062 auth-25) → 401 webhook_signature_invalid · 로그 0 · 키 0 · 응답 본문·헤더에 웹훅 비밀이 없다.
    멤버십은 있다 — 거부 사유는 서명·시각뿐이다."""
    sub = "unsigned-sub"
    _member(sub, TENANT_A)
    offset = {"created-past": -WEBHOOK_OUTSIDE_S, "created-future": WEBHOOK_OUTSIDE_S}.get(case, 0)
    created = (datetime.now(UTC) + timedelta(seconds=offset)).isoformat()
    _, body = _signed(sub, created=created)
    signatures = {"missing": None, "other-secret": sign_webhook(body, secrets.token_urlsafe(32))}
    signature = signatures[case] if case in signatures else sign_webhook(body, webhook_secret)
    response = _post_webhook(Client(), body, signature)
    assert_problem(response, 401, "webhook_signature_invalid")
    assert _count("session_revocation_log") == 0
    assert _denylist_keys(df_admin) == []
    _assert_absent("응답", _response_text(response), webhook_secret)


@DB
def test_api_23_webhook_unknown_member(df_admin: redis.Redis, webhook_secret: Secret) -> None:
    """api-23 — 서명은 맞지만 본문 sub의 TenantMembership이 없다 → 400 validation_error(tenant_id를 정할 수 없다) · 로그 0 ·
    outbox 0 · 키 0."""
    _, body = _signed("stranger-sub")
    response = _post_webhook(Client(), body, sign_webhook(body, webhook_secret))
    assert_problem(response, 400, "validation_error")
    assert (_count("session_revocation_log"), _count("outbox")) == (0, 0)
    assert _denylist_keys(df_admin) == []


@DB
def test_api_24_webhook_body_fields(df_admin: redis.Redis, webhook_secret: Secret) -> None:
    """api-24 — 웹훅 업무 필드(§웹훅 서명 규약 · 서명은 맞고 멤버십도 있다): action "login"(폐기 대상 아님) → 200 no-op /
    action 없음 · 정수 5 · sub 없음 · sub 정수 5(문자열 · 필수) · nbf true · 1.5 · "123"(있으면 정수 epoch 초 — bool · 실수 ·
    문자열 거부) → 각각 400 validation_error / 끝에 로그 0 · outbox 0 · 키 0. 루프 전에 문자열 "5" 멤버십을 둔다 — sub 정수
    5를 str()로 바꿔 조회하는 구현은 이 멤버십을 찾아 202를 내고 400 단언과 끝 단언(로그 0 · outbox 0 · 키 0)에서 걸린다
    (타입을 검사하는 구현은 400 — 멤버십이 없어서 나는 400(api-23)과 가른다)."""
    sub = "action-sub"
    _member(sub, TENANT_A)
    client = Client()
    _, login = _signed(sub, action="login")
    assert _post_webhook(client, login, sign_webhook(login, webhook_secret)).status_code == 200
    _member("5", TENANT_A)  # 문자열 "5" 멤버십 — sub 정수 5를 str()로 바꾸는 구현은 202를 낸다(sub-integer 케이스)
    cases: dict[str, dict[str, Any]] = {
        "action-missing": {"action": None},
        "action-integer": {"action": 5},
        "sub-missing": {"sub": None},
        "sub-integer": {"sub": 5},
        "nbf-bool": {"nbf": True},
        "nbf-float": {"nbf": 1.5},
        "nbf-string": {"nbf": "123"},
    }
    for case, overrides in cases.items():
        body = json.dumps(webhook_body(**{"sub": sub, **overrides})).encode()  # 값이 None인 키는 webhook_body가 지운다
        response = _post_webhook(client, body, sign_webhook(body, webhook_secret))
        assert response.status_code == 400, case
        assert_problem(response, 400, "validation_error")
    assert (_count("session_revocation_log"), _count("outbox")) == (0, 0)
    assert _denylist_keys(df_admin) == []


@DB
def test_api_25_webhook_default_nbf(df_admin: redis.Redis, webhook_secret: Secret) -> None:
    """api-25 — 본문 nbf 없음 → 202 · 로그 nbf ∈ [⌊t0⌋ + 1, ⌊t1⌋ + 1](t0 · t1 = 요청 전후 시각 — 수신 시각 epoch 초 내림 + 1)
    · revoked:sub 값 = 그 nbf."""
    sub = "default-nbf-sub"
    _member(sub, TENANT_A)
    _, body = _signed(sub)
    signature = sign_webhook(body, webhook_secret)
    client = Client()
    t0 = time.time()
    response = _post_webhook(client, body, signature)
    t1 = time.time()
    assert response.status_code == 202
    (row,) = _rows("session_revocation_log")
    nbf = row.nbf.timestamp()
    assert math.floor(t0) + 1 <= nbf <= math.floor(t1) + 1, f"nbf {nbf} · t0 {t0:.3f} · t1 {t1:.3f}"
    assert nbf == int(nbf), "nbf가 정수 초가 아니다"
    assert _get_int(df_admin, f"revoked:sub:{sub}") == int(nbf)


@DB
def test_api_26_webhook_dragonfly_down(
    settings: Settings, df_admin: redis.Redis, webhook_secret: Secret, ia_dragonfly: Secret
) -> None:
    """api-26 — DRAGONFLY_URL 닫힌 포트(커밋 뒤 SET 실패) → 202(DB가 정본) · 로그 1 · outbox 1 → URL 복구 → 키 없음 →
    reconcile_denylist(app.tasks[...].apply()) → 키 = nbf(재적용이 키를 되살린다)."""
    sub = "df-down-sub"
    _member(sub, TENANT_A)
    nbf = int(time.time()) - 2
    _, body = _signed(sub, nbf=nbf)
    headers = _webhook_headers(sign_webhook(body, webhook_secret))
    settings.DRAGONFLY_URL, _ = _unreachable_dragonfly()
    client = Client()
    response, _ = _timed(
        lambda: client.post(WEBHOOK_PATH, data=body, content_type="application/json", headers=headers),
        WEBHOOK_DOWN_LIMIT_S,
    )
    assert response.status_code == 202
    assert (_count("session_revocation_log"), _count("outbox")) == (1, 1)
    settings.DRAGONFLY_URL = ia_dragonfly
    key = f"revoked:sub:{sub}"
    assert df_admin.exists(key) == 0
    _run_task(TASK_RECONCILE)
    assert _get_int(df_admin, key) == nbf


# --- GET /tenants/me ------------------------------------------------------------------------------------------------


@DB
def test_api_27_tenants_me(jwks_server: JwksFixture) -> None:
    """api-27 — 테넌트 A(slug tenant-a · display Tenant A · active) + 멤버십(S, A, owner) → 토큰(S, A) → 200 ==
    {"tenant": {"id": A, "slug": "tenant-a", "display_name": "Tenant A", "status": "active"}, "role": "owner"}."""
    sub = "owner-sub"
    _tenant(TENANT_A, slug="tenant-a", display_name="Tenant A")
    _member(sub, TENANT_A, "owner")
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_A))
    response = _get(Client(), TENANTS_ME, headers)
    assert response.status_code == 200
    tenant = {"id": TENANT_A, "slug": "tenant-a", "display_name": "Tenant A", "status": "active"}
    assert json.loads(response.content) == {"tenant": tenant, "role": "owner"}


@DB
def test_api_28_tenants_me_token_tenant(jwks_server: JwksFixture) -> None:
    """api-28 — S가 A(owner)·B(member) 둘 다 → 토큰(S, B) → 200 · tenant B · role member · 응답 바이트에 A의 id · slug 없음
    (sub와 tenant_id를 둘 다 거른다 — 테넌트 B 토큰으로 테넌트 A 데이터 0건)."""
    sub = "two-tenant-sub"
    _tenant(TENANT_A, slug="tenant-a", display_name="Tenant A")
    _tenant(TENANT_B, slug="tenant-b", display_name="Tenant B")
    _member(sub, TENANT_A, "owner")
    _member(sub, TENANT_B, "member")
    response = _get(Client(), TENANTS_ME, _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_B)))
    assert response.status_code == 200
    body = json.loads(response.content)
    assert (body["tenant"]["id"], body["tenant"]["slug"], body["role"]) == (TENANT_B, "tenant-b", "member")
    text = response.content.decode("utf-8", errors="replace")
    assert [needle for needle in (TENANT_A, "tenant-a") if needle in text] == []


@DB
def test_api_29_tenants_me_not_found(jwks_server: JwksFixture) -> None:
    """api-29 — S가 A에만 있다 → 토큰(S, B) → 404 not_found · 응답에 A의 id · slug 없음 / 멤버십 없는 사용자 → 404."""
    sub = "a-only-sub"
    _tenant(TENANT_A, slug="tenant-a", display_name="Tenant A")
    _member(sub, TENANT_A, "owner")
    client = Client()
    cross = _get(client, TENANTS_ME, _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_B)))
    assert_problem(cross, 404, "not_found")
    text = cross.content.decode("utf-8", errors="replace")
    assert [needle for needle in (TENANT_A, "tenant-a") if needle in text] == []
    stranger = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "nobody-sub", TENANT_A))
    assert_problem(_get(client, TENANTS_ME, stranger), 404, "not_found")


# --- 거부 목록 무조건 재적용 · purge · beat -----------------------------------------------------------------------------------


@DB
def test_api_30_reconcile_restores_all(df_admin: redis.Redis) -> None:
    """api-30 — 무조건 재적용(SIGKILL 재시작 시나리오 — 캐시를 통째로 비운 상태 · 센티널 denylist:epoch를 쓰지 않는다):
    FLUSHALL 뒤 행 4(r1 sub 단위 활성 nbf = now−100 s · r2 sid sid-2 활성 nbf = now−10 s · r3 만료 nbf = now−1000 s · r4 sub
    단위 활성 nbf = now−50 s — r4 키에는 낡은 값 1 EX 5를 미리 둔다) → reconcile_denylist 1회 → revoked:sub:r1 = nbf1 ·
    revoked:sid:sid-2 = "1" · revoked:sub:r4 = nbf4(낡은 값을 덮어쓴다 — EXISTS로 건너뛰지 않는다) · TTL = ⌊expires_at − DB
    now⌋ ± 5(5가 아니다 · 330으로 되돌리지 않는다 — 어긋남은 수십 s 이상이라 ±5로도 가린다) · r3 키 없음 · revoked:* 키
    정확히 3(한 행 = 한 키 — sid 행은 sub 키를 만들지 않는다) · denylist:epoch 없음. Celery 앱을 now 측정 전에 적재한다(첫
    적재 비용이 비교 창에 들지 않게). "30 s 안에"는 beat 주기 30 s(api-33) + 이 작업 결과로 대신한다(실시간은 T085)."""
    base = _floor(_db_now())
    r1 = _log_row("r1-sub", nbf=_at(base - 100))
    r2 = _log_row("r2-sub", nbf=_at(base - 10), sid="sid-2", reason="logout")
    _log_row("r3-sub", nbf=_at(base - 1000))
    r4 = _log_row("r4-sub", nbf=_at(base - 50))
    df_admin.flushall()
    df_admin.set("revoked:sub:r4-sub", 1, ex=5)
    _celery_app()
    now = _db_now()
    _run_task(TASK_RECONCILE)
    expected = {
        "revoked:sub:r1-sub": (str(base - 100), _remaining(r1.expires_at, now)),
        "revoked:sid:sid-2": ("1", _remaining(r2.expires_at, now)),
        "revoked:sub:r4-sub": (str(base - 50), _remaining(r4.expires_at, now)),
    }
    assert _denylist_keys(df_admin) == sorted(expected)
    for key, (value, ttl) in expected.items():
        assert df_admin.get(key) == value.encode(), key
        actual = df_admin.ttl(key)
        assert abs(actual - ttl) <= TTL_TOLERANCE_S, f"{key} TTL {actual} · 기대 {ttl}"
    assert df_admin.exists("denylist:epoch") == 0


@DB
def test_api_31_reconcile_idempotent_ttl(df_admin: redis.Redis) -> None:
    """api-31 — 재적용 두 번(사이 1.2 s) → 값 불변 · 둘째 TTL ≤ 첫째 TTL · 둘 다 < 330(SET이 멱등이라 여러 번 돌려도 TTL이
    늘지 않는다 — 남은 TTL로 다시 둔다)."""
    base = _floor(_db_now())
    _log_row("idem-sub", nbf=_at(base - 100))
    key = "revoked:sub:idem-sub"
    _run_task(TASK_RECONCILE)
    first = (df_admin.get(key), df_admin.ttl(key))
    time.sleep(1.2)
    _run_task(TASK_RECONCILE)
    second = (df_admin.get(key), df_admin.ttl(key))
    assert first[0] == second[0] == str(base - 100).encode()
    assert 0 < second[1] <= first[1] < DENYLIST_TTL_S, f"TTL {first[1]} → {second[1]}"


@DB
def test_api_32_reconcile_on_beat_init(df_admin: redis.Redis) -> None:
    """api-32 — 기동 시 1회: Celery beat_init 신호(beat가 기동할 때 보낸다)를 보내면 반환 직후 키가 있다(같은 프로세스 ·
    동기 — 브로커 경유 아님) · 수신자 예외 없음(Celery Signal.send는 수신자 예외를 응답 목록에 담고 로그만 남긴다)."""
    from celery.signals import beat_init

    base = _floor(_db_now())
    _log_row("boot-sub", nbf=_at(base - 30))
    df_admin.flushall()
    _celery_app()
    responses = beat_init.send(sender=None)
    errors = [type(result).__name__ for _, result in responses if isinstance(result, BaseException)]
    assert errors == []
    assert _get_int(df_admin, "revoked:sub:boot-sub") == base - 30


def test_api_33_beat_schedule() -> None:
    """api-33 — app.conf.beat_schedule(작업 이름 → 주기): reconcile_denylist = 정확히 30 s(숫자 30 · timedelta(seconds=30) ·
    schedule(run_every 30 s)) · purge_session_revocation_log · reconcile_authentik_sessions · purge_dead_outbox = 일 1회
    (86400 s 간격 또는 분·시가 각각 값 하나이고 요일·일·월이 전부인 crontab) · 네 작업 모두 app.tasks에 있다. 같은 작업의
    항목이 여럿이면 전부 그 주기여야 한다."""
    from celery.schedules import crontab, schedule

    def seconds(value: Any) -> float | None:
        if isinstance(value, bool):
            return None
        if isinstance(value, int | float):
            return float(value)
        if isinstance(value, timedelta):
            return value.total_seconds()
        if isinstance(value, schedule) and not isinstance(value, crontab):
            return value.run_every.total_seconds()
        return None

    def daily(value: Any) -> bool:
        if isinstance(value, crontab):
            fixed = len(value.minute) == 1 and len(value.hour) == 1
            every_day = value.day_of_week == set(range(7)) and value.day_of_month == set(range(1, 32))
            return fixed and every_day and value.month_of_year == set(range(1, 13))
        return seconds(value) == 86400.0

    app = _celery_app()
    by_task: dict[str, list[Any]] = {}
    for entry in app.conf.beat_schedule.values():
        by_task.setdefault(entry["task"], []).append(entry["schedule"])
    assert [name for name in (TASK_RECONCILE, *DAILY_TASKS) if name not in app.tasks] == []
    reconcile = by_task.get(TASK_RECONCILE, [])
    assert reconcile and all(seconds(value) == 30.0 for value in reconcile), f"reconcile 주기 {reconcile!r}"
    for name in DAILY_TASKS:
        schedules = by_task.get(name, [])
        assert schedules and all(daily(value) for value in schedules), f"{name} 주기 {schedules!r}"


@DB
def test_api_34_purge_revocation_log() -> None:
    """api-34 — 로그 purge 경계(expires_at + 30 d < DB now()): expires_at = now − 30 d − 1 h 삭제 · now − 30 d + 1 h 유지 ·
    now + 100 s 유지 → 남은 id 집합 = 뒤 둘."""
    base = _at(_floor(_db_now()))
    month, hour, ttl = timedelta(days=30), timedelta(hours=1), timedelta(seconds=DENYLIST_TTL_S)
    _log_row("purge-old", nbf=base - month - hour - ttl)
    recent = _log_row("purge-recent", nbf=base - month + hour - ttl)
    active = _log_row("purge-active", nbf=base + timedelta(seconds=100) - ttl)
    _run_task(TASK_PURGE_LOG)
    remaining = set(_model("session_revocation_log").objects.values_list("pk", flat=True))
    assert remaining == {recent.pk, active.pk}


@DB
def test_api_35_purge_dead_outbox() -> None:
    """api-35 — outbox dead purge 경계(dead_at + 30 d < DB now() · dead_at NULL은 대상 아님): transaction.atomic() 안
    django_common.outbox.publish(..., tenant_id=A) 3행 → dead_at = now − 30 d − 1 h · now − 30 d + 1 h · NULL →
    purge_dead_outbox → 남은 id = 뒤 둘."""
    from django_common.outbox import publish

    data = {"sub": "purge-sub", "sid": None, "nbf": 1756696867, "reason": "logout"}
    with transaction.atomic():
        events = [publish(TOPIC, "user:purge-sub", data, tenant_id=TENANT_A) for _ in range(3)]
    base = _db_now()
    outbox = _model("outbox")
    dead = (base - timedelta(days=30, hours=1), base - timedelta(days=30) + timedelta(hours=1), None)
    for event, dead_at in zip(events, dead, strict=True):
        outbox.objects.filter(pk=event.pk).update(dead_at=dead_at)
    _run_task(TASK_PURGE_OUTBOX)
    assert set(outbox.objects.values_list("pk", flat=True)) == {events[1].pk, events[2].pk}


# --- seed_tenant(data-model §1) -------------------------------------------------------------------------------------


@DB
def test_api_36_seed_tenant(
    settings: Settings, fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga, capfd: pytest.CaptureFixture[str]
) -> None:
    """api-36 — 시드 1회(AUTHENTIK_WRITES_ENABLED=True · 가짜 Authentik(_seed_fakes): 미끼 그룹 authentik Admins(superuser)
    · platform-admin과 미끼 사용자 akadmin이 정답보다 앞 · 그룹 tenant:<T>(소속 없음) · 사용자 101(uuid = owner sub ·
    attributes {"existing": "keep"}) · 102(uuid = member sub · {})) → Tenant 1(id T · slug joshuatech · display
    JoshuaTech · active) · 멤버십 {(owner, owner), (member, member)}(tenant T) · 그룹 소속 {101, 102} · 101 attributes =
    {"existing": "keep", "tenant_id": T}(병합 PATCH — 가짜 PATCH는 통째로 바꾼다) · 102 = {"tenant_id": T} · 미끼 불변 · FGA
    튜플 = {(user:<owner>, owner, tenant:T), (user:<member>, member, tenant:T)} · 조회 질의(data-model §1): 그룹 목록 GET은 전부
    `?name=tenant:<T>`(하나 이상) · 사용자 목록 GET은 전부 `?uuid=<owner 또는 member sub>`(둘 다 한 번 이상) · 두 가짜
    서버가 받은 요청이 전부 인증됨(하나 이상) · 명령 출력(stdout · stderr · 프로세스 fd)에 API 토큰 · preshared 키 없음."""
    settings.AUTHENTIK_WRITES_ENABLED = True
    _seed_fakes(fake_authentik)
    out, err = io.StringIO(), io.StringIO()
    _seed(stdout=out, stderr=err)
    (tenant,) = _rows("tenant")
    seeded = (str(tenant.pk), tenant.slug, tenant.display_name, tenant.status)
    assert seeded == (SEED_TENANT, SEED_SLUG, SEED_DISPLAY, "active")
    memberships = sorted((m.sub, m.role, str(m.tenant_id)) for m in _rows("tenant_membership"))
    assert memberships == sorted([(SEED_OWNER, "owner", SEED_TENANT), (SEED_MEMBER, "member", SEED_TENANT)])
    assert fake_authentik.group_users(SEED_GROUP) == {101, 102}
    assert fake_authentik.user(101)["attributes"] == {"existing": "keep", "tenant_id": SEED_TENANT}
    assert fake_authentik.user(102)["attributes"] == {"tenant_id": SEED_TENANT}
    _assert_decoys_untouched(fake_authentik)
    assert fake_openfga.tuples == SEED_TUPLES
    group_queries = _lookup_queries(fake_authentik, GROUPS_API, "name")
    assert group_queries and all(query == [SEED_GROUP] for query in group_queries), f"그룹 조회 질의 {group_queries}"
    user_queries = _lookup_queries(fake_authentik, USERS_API, "uuid")
    assert all(query in ([SEED_OWNER], [SEED_MEMBER]) for query in user_queries), f"사용자 조회 질의 {user_queries}"
    assert [SEED_OWNER] in user_queries and [SEED_MEMBER] in user_queries, f"사용자 조회 질의 {user_queries}"
    requests = {"authentik": fake_authentik.requests, "openfga": fake_openfga.requests}
    assert [name for name, made in requests.items() if not made] == []
    unauthenticated = [(name, r.method, r.path) for name, made in requests.items() for r in made if not r.authorized]
    assert unauthenticated == []
    captured = capfd.readouterr()
    text = "\n".join((out.getvalue(), err.getvalue(), captured.out, captured.err))
    _assert_absent("명령 출력", text, fake_authentik.token, fake_openfga.key)


@DB
def test_api_37_seed_idempotent(settings: Settings, fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga) -> None:
    """api-37 — 시드 2회 → Tenant · 멤버십 id 집합 · 행 수 · 그룹 소속 · attributes · FGA 튜플 불변 · 예외 없음(가짜 FGA는
    중복 쓰기를 400 write_failed_due_to_invalid_input으로 거부한다 — 미리 읽어 건너뛰거나 on_duplicate ignore를 쓰거나 중복
    400만 성공으로 보는 구현을 요구) / 파생이 일부만 있는 상태(member 튜플만 빠짐)에서 다시 실행 → 마저 쓴다(같은 상태 —
    가짜 FGA는 요청 단위로 원자적이라 [owner, member] 일괄 쓰기의 중복 400을 성공으로 삼키는 구현은 member를 놓친다 ·
    data-model §1 "다시 실행하면 멱등하게 마저 쓴다") / 2회차 · 3회차의 Authentik 쓰기 0(첫 시드 뒤 변경 요청 수 그대로 —
    data-model §1 "이미 같은 상태면 쓰지 않음" · 문면 "파생 쓰기가 중복되지 않음") · FGA 재쓰기는 세지 않는다(계약이
    `on_duplicate: "ignore"` 재쓰기와 중복 400 성공 처리를 허용한다) · 미끼 불변."""
    settings.AUTHENTIK_WRITES_ENABLED = True
    _seed_fakes(fake_authentik)
    _seed()
    first = _seed_state(fake_authentik, fake_openfga)
    writes = len(fake_authentik.mutations())
    _seed()
    assert _seed_state(fake_authentik, fake_openfga) == first
    assert len(fake_authentik.mutations()) == writes, "같은 상태인데 Authentik에 다시 썼다(2회차)"
    fake_openfga.reset(tuples=[key for key in SEED_TUPLES if key[1] == "owner"])
    _seed()
    assert _seed_state(fake_authentik, fake_openfga) == first
    assert len(fake_authentik.mutations()) == writes, "같은 상태인데 Authentik에 다시 썼다(3회차)"
    _assert_decoys_untouched(fake_authentik)


@DB
def test_api_38_seed_writes_disabled(
    settings: Settings, fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga
) -> None:
    """api-38 — AUTHENTIK_WRITES_ENABLED=False(dev) → 시드 → 가짜 Authentik 변경 요청(POST · PATCH · PUT · DELETE) 0 · 그룹
    소속 · attributes 불변(읽기는 한다 — api-56) · 미끼 불변 · FGA 튜플 2(env별 store — dev도 쓴다) · DB 행(Tenant 1 ·
    멤버십 2)."""
    assert settings.AUTHENTIK_WRITES_ENABLED is False
    _seed_fakes(fake_authentik)
    _seed()
    assert [(r.method, r.path) for r in fake_authentik.mutations()] == []
    assert fake_authentik.group_users(SEED_GROUP) == set()
    attributes = (fake_authentik.user(101)["attributes"], fake_authentik.user(102)["attributes"])
    assert attributes == ({"existing": "keep"}, {})
    _assert_decoys_untouched(fake_authentik)
    assert fake_openfga.tuples == SEED_TUPLES
    assert (_count("tenant"), _count("tenant_membership")) == (1, 2)


@DB
def test_api_39_seed_fga_failure(settings: Settings, fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga) -> None:
    """api-39 — 가짜 FGA가 다음 쓰기를 400 validation_error(중복이 아닌 400 — 삼키면 안 된다)로 실패시키면 CommandError ·
    주입된 실패가 실제로 소비됐다(다른 이유의 CommandError가 아니다) · DB 행은 남는다(순서 DB → 파생 — data-model §1) · 다시
    실행하면 마저 쓴다(FGA 튜플 2) · 미끼 불변."""
    settings.AUTHENTIK_WRITES_ENABLED = True
    _seed_fakes(fake_authentik)
    fake_openfga.fail_next_write = (400, {"code": "validation_error", "message": "invalid tuple"})
    with pytest.raises(CommandError):
        _seed()
    assert fake_openfga.fail_next_write is None
    assert (_count("tenant"), _count("tenant_membership")) == (1, 2)
    _seed()
    assert fake_openfga.tuples == SEED_TUPLES
    _assert_decoys_untouched(fake_authentik)


@DB
@pytest.mark.parametrize("writes", [True, False], ids=["writes-on", "writes-off"])
def test_api_40_seed_group_missing(
    writes: bool, settings: Settings, fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga
) -> None:
    """api-40 — 가짜 Authentik에 그룹 tenant:<T>가 없다(미끼 그룹 둘만 있다) → CommandError · 그룹 생성 시도 0
    (`/api/v3/core/groups/`로의 POST 중 add_user가 아닌 것 0 — 그룹 껍데기는 blueprint의 몫) · 그룹 이름 집합은 미끼 둘
    그대로(만들지 않았다) · 그룹 목록 GET은 전부 `?name=tenant:<T>`이고 하나 이상(이름으로 조회했다 — 필터 없이 첫 그룹을
    쓰는 구현은 미끼를 고른다) · 미끼 불변. 쓰기 플래그와 무관하다 — 그룹 조회는 읽기라 늘 한다(data-model §1 · 쓰기를 끄면
    그룹 조회를 건너뛰는 구현은 writes-off에서 조회 질의 0 또는 CommandError 없음으로 걸린다)."""
    settings.AUTHENTIK_WRITES_ENABLED = writes
    _seed_fakes(fake_authentik, group=False)
    with pytest.raises(CommandError):
        _seed()
    creations = [
        r.path
        for r in fake_authentik.mutations()
        if r.method == "POST" and r.path.startswith(GROUPS_API) and not r.path.endswith("/add_user/")
    ]
    assert creations == []
    assert fake_authentik.group_names() == {DECOY_ADMINS_GROUP, DECOY_PLATFORM_GROUP}
    group_queries = _lookup_queries(fake_authentik, GROUPS_API, "name")
    assert group_queries and all(query == [SEED_GROUP] for query in group_queries), f"그룹 조회 질의 {group_queries}"
    _assert_decoys_untouched(fake_authentik)


@DB
def test_api_41_seed_slug_conflict(
    settings: Settings, fake_authentik: FakeAuthentik, fake_openfga: FakeOpenFga
) -> None:
    """api-41 — slug joshuatech가 다른 id로 이미 있다 → CommandError · tenant 1행(기존 것 · 새 행을 만들지 않는다) · 파생
    쓰기 0(순서 DB → 파생 — DB 단계에서 멈춘다) · 미끼 불변."""
    settings.AUTHENTIK_WRITES_ENABLED = True
    _seed_fakes(fake_authentik)
    _tenant(OTHER_TENANT, slug=SEED_SLUG, display_name="Existing")
    with pytest.raises(CommandError):
        _seed()
    assert [str(t.pk) for t in _rows("tenant")] == [OTHER_TENANT]
    assert fake_openfga.tuples == set()
    assert [(r.method, r.path) for r in fake_authentik.mutations()] == []
    _assert_decoys_untouched(fake_authentik)


@DB
@pytest.mark.parametrize("writes", [True, False], ids=["writes-on", "writes-off"])
def test_api_56_seed_missing_user(writes: bool, settings: Settings, fake_authentik: FakeAuthentik) -> None:
    """api-56 — 가짜 Authentik에 member 사용자(uuid = member sub)가 없다(미끼 + 그룹 + 사용자 101만) → CommandError · DB
    행(Tenant 1 · 멤버십 2) 유지(순서 DB → 파생) · 미끼 불변. 쓰기 플래그와 무관하다 — 그룹·사용자 조회는 읽기라 늘 한다
    (data-model §1 · 쓰기를 끈 dev 시드도 사용자가 없으면 실패). 그룹 소속 · FGA 튜플은 단언하지 않는다(파생 순서는 계약
    밖)."""
    settings.AUTHENTIK_WRITES_ENABLED = writes
    _seed_fakes(fake_authentik, users=(101,))
    with pytest.raises(CommandError):
        _seed()
    assert (_count("tenant"), _count("tenant_membership")) == (1, 2)
    _assert_decoys_untouched(fake_authentik)


# --- 호스트 · admin · 기동 설정 --------------------------------------------------------------------------------------------


@DB
def test_api_42_admin_mounted_on_admin_host_only(jwks_server: JwksFixture, settings: Settings) -> None:
    """api-42 — 유효 자격(Access M2M + Bearer) · ADMIN_HOST = admin.joshuatech.dev → GET /admin/: m2m 호스트 · svc 호스트
    404 not_found(RFC 9457 — 템플릿 handler404 · T072 가정 ⑨) · admin 호스트 302 + Location에 /admin/login/(익명 → 로그인).
    M2M 자격은 장착 여부를 보려는 것이다(사람 경로는 VD-T066-5)."""
    assert settings.ADMIN_HOST == ADMIN_HOST_VALUE
    client = Client()
    bearer = _bearer(jwks_server, "admin-probe-sub", TENANT_A)
    for host in (M2M_HOST, SVC_HOST):
        response = _get(client, "/admin/", _headers(jwks_server, host, bearer=bearer))
        assert response.status_code == 404, host
        assert_problem(response, 404, "not_found")
    response = _get(client, "/admin/", _headers(jwks_server, ADMIN_HOST_VALUE, bearer=bearer))
    assert response.status_code == 302
    assert "/admin/login/" in response["Location"]


@DB
def test_api_43_admin_absent_when_admin_host_empty(jwks_server: JwksFixture, settings: Settings) -> None:
    """api-43 — ADMIN_HOST = ""(dev) → svc · m2m · admin 세 호스트 모두 /admin/ 404 not_found(빈 값은 어떤 호스트와도 일치하지
    않는다 — 포함 검사면 빈 문자열이 모든 호스트에 "들어 있다")."""
    settings.ADMIN_HOST = ""
    client = Client()
    bearer = _bearer(jwks_server, "admin-probe-sub", TENANT_A)
    for host in (SVC_HOST, M2M_HOST, ADMIN_HOST_VALUE):
        response = _get(client, "/admin/", _headers(jwks_server, host, bearer=bearer))
        assert response.status_code == 404, host
        assert_problem(response, 404, "not_found")


@DB
def test_api_53_admin_script_prefix_admin_host_only(jwks_server: JwksFixture, settings: Settings) -> None:
    """api-53 — admin 경로 접두(§호스트 · rules/django-pod.md §Auth): ADMIN_SCRIPT_NAME = "/identity-admin"(prod 꼴 — env
    FORCE_SCRIPT_NAME) · Client 하나로 차례로 (1) admin 호스트 GET /admin/(api-42와 같은 M2M 자격) → 302 · Location 경로 ==
    /identity-admin/admin/login/ · next == ["/identity-admin/admin/"](reverse()와 request.path 둘 다 접두) (2) m2m 호스트
    GET /api/openapi.json → 200 · /session/check 경로 키가 있고 /identity-admin으로 시작하는 키 0(m2m에는 접두가 없고 앞
    요청의 스레드 로컬 접두가 새지 않는다 — 요청 끝에 되돌린다) (3) m2m 호스트 GET /admin/ → 404 not_found.

    끝에 script prefix를 "/"로 되돌린다(구현이 되돌리지 않아 이 테스트가 떨어져도 뒤 테스트로 번지지 않게 — 누수 단언 (2)는
    그 전에 끝난다 · 시험 Client는 WSGIHandler와 달리 요청마다 script prefix를 다시 두지 않는다).

    설정 변경 전에 같은 Client로 미들웨어 모듈 import와 인스턴스 생성을 끝낸다(svc 호스트 /healthz → 200 — 의존 조회 없음) —
    import 시점 상수나 미들웨어 `__init__`에서 설정을 읽는 구현(계약: 호출 시점에 읽는다)을 단독 실행(`-k api_53`)에서도
    잡는다(pytest-django는 DB 테스트를 먼저 돌리므로 단독 실행에서는 이 테스트가 첫 적재일 수 있다). 별도 Client로 예열하지
    않는다(`Client()`마다 미들웨어 인스턴스를 새로 만든다)."""
    client = Client()
    assert _get(client, "/healthz", {"host": SVC_HOST}).status_code == 200
    settings.ADMIN_SCRIPT_NAME = ADMIN_PREFIX
    bearer = _bearer(jwks_server, "admin-prefix-sub", TENANT_A)
    try:
        response = _get(client, "/admin/", _headers(jwks_server, ADMIN_HOST_VALUE, bearer=bearer))
        assert response.status_code == 302
        location = urlsplit(response["Location"])
        assert location.path == f"{ADMIN_PREFIX}/admin/login/"
        assert parse_qs(location.query).get("next") == [f"{ADMIN_PREFIX}/admin/"]
        spec = _get(client, OPENAPI_PATH, _headers(jwks_server, M2M_HOST, bearer=bearer))
        assert spec.status_code == 200
        paths: dict[str, Any] = json.loads(spec.content).get("paths", {})
        assert CHECK_PATH in paths
        assert [path for path in paths if path.startswith(ADMIN_PREFIX)] == []
        assert_problem(_get(client, "/admin/", _headers(jwks_server, M2M_HOST, bearer=bearer)), 404, "not_found")
    finally:
        set_script_prefix("/")


@DB
def test_api_44_disallowed_host(jwks_server: JwksFixture) -> None:
    """api-44 — Host evil.example.com(ALLOWED_HOSTS 밖) → /session/check(자격 없음) · (Access만) · /tenants/me(전 자격) 모두
    400 invalid_host(RFC 9457 — 템플릿 handler400 · T072 가정 ⑨ · 호스트 판정이 인증보다 먼저 — 자격 없는 요청도 403이
    아니라 400) / 양성 대조: svc · m2m 호스트 + Access → /session/check 200. 잘못된 구현이 인증을 지나 DB에 닿아도 오류가
    아니라 판정 실패로 보이게 DB 마크를 둔다."""
    client = Client()
    path = _check_path("host-sub", int(time.time()))
    bearer = _bearer(jwks_server, "host-sub", TENANT_A)
    cases = {
        "check-no-credentials": (path, _headers(jwks_server, EVIL_HOST, access=False)),
        "check-access-only": (path, _headers(jwks_server, EVIL_HOST)),
        "tenants-me-full": (TENANTS_ME, _headers(jwks_server, EVIL_HOST, bearer=bearer)),
    }
    for case, (target, headers) in cases.items():
        response = _get(client, target, headers)
        assert response.status_code == 400, case
        assert_problem(response, 400, "invalid_host")
    for host in (SVC_HOST, M2M_HOST):
        assert _get(client, path, _headers(jwks_server, host)).status_code == 200, host


@DB
def test_api_45_jwks_via_svc_dns(jwks_server: JwksFixture, settings: Settings, dns_guard: list[str]) -> None:
    """api-45 — 공개 iss(https://auth.joshuatech.dev/…) Bearer로 /tenants/me 200(멤버십 준비) · JWKS는 설정 URL(로컬 JWKS
    서버 = 운영 svc DNS 자리)에서 가져왔다(hits 증가 — 새 Client = 새 미들웨어 인스턴스의 JWKS 클라이언트 · T062 가정) ·
    공개 호스트 이름 조회 0(iss로 OIDC discovery를 하지 않는다 — dns_guard가 teardown에서도 다시 본다)."""
    assert settings.AUTHENTIK_ISSUER == PUBLIC_ISSUER
    sub = "jwks-sub"
    _member(sub, TENANT_A)
    before = jwks_server.hits.get(JWKS_PATH, 0)
    response = _get(Client(), TENANTS_ME, _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, sub, TENANT_A)))
    assert response.status_code == 200
    assert jwks_server.hits.get(JWKS_PATH, 0) > before
    assert dns_guard == []


def test_api_46_boot_admin_host_empty() -> None:
    """api-46 — ADMIN_HOST=""(dev 꼴)로 새 프로세스 기동(django.setup() + ROOT_URLCONF import) → 종료 0 · ADMIN_HOST == ""
    (필수값 검사는 존재만 본다 — 빈 값이 유효하다 · 이때 admin이 없다는 것은 api-43) · 기동 위생(공개 이름 조회 0 · 출력에
    비밀 없음 — _boot_values)."""
    values = _boot_values(_boot({"ADMIN_HOST": ""}))
    assert values["ADMIN_HOST"] == ""


@pytest.mark.parametrize("name", REQUIRED_SETTINGS, ids=_kebab)
def test_api_47_boot_required_missing(name: str) -> None:
    """api-47 — 필수값 env 하나가 없음(ADMIN_HOST · AUTHENTIK_API_TOKEN · AUTHENTIK_WEBHOOK_SECRET · OPENFGA_STORE_ID ·
    OPENFGA_PRESHARED_KEY · AUTHENTIK_JWKS_URL — §identity-admin 전용 설정 "없음(필수)" · §호스트) → 기동 실패(종료 코드 0
    아님 · ImproperlyConfigured) · 기동 위생(실패 출력에도 설정 값 없음 · 공개 이름 조회 0)."""
    _assert_boot_refused(_boot({}, remove=(name,)))


@pytest.mark.parametrize("name", SECRET_SETTINGS, ids=_kebab)
def test_api_55_boot_empty_secret_refused(name: str) -> None:
    """api-55 — 비밀 3개(AUTHENTIK_API_TOKEN · AUTHENTIK_WEBHOOK_SECRET · OPENFGA_PRESHARED_KEY) 중 하나가 빈 값 → 기동 실패
    (빈 HMAC 키 · 빈 토큰은 누구나 만들 수 있다 — §identity-admin 전용 설정 T066 r1 보정 · rules/django-pod.md §Settings ·
    빈 값이 유효한 것은 ADMIN_HOST · AUTH_ACTOR_SUB 같은 비밀 아닌 값뿐) · 기동 위생."""
    _assert_boot_refused(_boot({name: ""}))


def test_api_48_boot_service_defaults() -> None:
    """api-48 — AUTHENTIK_API_URL · OPENFGA_API_URL · AUTHENTIK_WRITES_ENABLED env 없음 → svc DNS 기본값
    http://authentik-server.identity.svc:9000 · http://openfga.identity.svc:8080 · 쓰기 플래그 False(bool — fail-safe) ·
    기동 위생."""
    values = _boot_values(_boot({}, remove=("AUTHENTIK_API_URL", "OPENFGA_API_URL", "AUTHENTIK_WRITES_ENABLED")))
    assert (values["AUTHENTIK_API_URL"], values["OPENFGA_API_URL"]) == (AUTHENTIK_SVC_URL, OPENFGA_SVC_URL)
    assert values["AUTHENTIK_WRITES_ENABLED"] is False


@pytest.mark.parametrize(
    ("name", "value"),
    [
        ("AUTHENTIK_JWKS_URL", "https://auth.joshuatech.dev/application/o/identity-admin/jwks/"),
        ("AUTHENTIK_API_URL", "https://auth.joshuatech.dev"),
        ("OPENFGA_API_URL", "https://fga.joshuatech.dev"),
        ("AUTHENTIK_API_URL", "https://AUTH.JOSHUATECH.DEV"),
        ("AUTHENTIK_API_URL", "https://joshuatech.dev"),
    ],
    ids=["jwks-public", "authentik-api-public", "openfga-public", "authentik-api-uppercase", "authentik-api-apex"],
)
def test_api_49_boot_public_host_refused(name: str, value: str) -> None:
    """api-49 — pod가 직접 부르는 클러스터 안 서비스 URL의 호스트가 공개 도메인(joshuatech.dev 자체 · 하위 · 대소문자
    무관)이면 기동 실패(ImproperlyConfigured — pod는 공개 호스트를 부르지 않는다 · FR-046 · 문자열 판정 — 기동 위생이 이름
    조회 0을 본다)."""
    _assert_boot_refused(_boot({name: value}))


def test_api_54_boot_force_script_name_env() -> None:
    """api-54 — env FORCE_SCRIPT_NAME=/identity-admin(prod admin 경로 접두) → 설정 ADMIN_SCRIPT_NAME == "/identity-admin" ·
    Django 전역 FORCE_SCRIPT_NAME은 None · 기동 직후 script prefix "/"(전역 접두 없음 — 전역이면 m2m reverse()와 OpenAPI 경로
    키에도 붙는다) · STATIC_URL == "/identity-admin/static/"(절대 경로 — 상대 값은 Django가 첫 접근 때의 script prefix를 붙여
    캐시하므로 요청 단위 접두를 따를 수 없다 · contracts/pod-template.md `has_admin` 행 · 설정 값만 보고 서빙은 시험하지
    않는다) / env 없음 → ADMIN_SCRIPT_NAME == ""(선택 · 기본 빈 값) · FORCE_SCRIPT_NAME None(§호스트 · T073 가정 ⑧ · 이때
    STATIC_URL은 계약이 값을 정하지 않아 단언하지 않는다) · 기동 위생."""
    values = _boot_values(_boot({"FORCE_SCRIPT_NAME": ADMIN_PREFIX}))
    observed = (values["ADMIN_SCRIPT_NAME"], values["FORCE_SCRIPT_NAME"], values["script_prefix"], values["STATIC_URL"])
    assert observed == (ADMIN_PREFIX, None, "/", f"{ADMIN_PREFIX}/static/")
    values = _boot_values(_boot({}, remove=("FORCE_SCRIPT_NAME",)))
    assert (values["ADMIN_SCRIPT_NAME"], values["FORCE_SCRIPT_NAME"]) == ("", None)


# --- OpenAPI 계약 구조 --------------------------------------------------------------------------------------------------


@DB
def test_api_50_openapi_contract(jwks_server: JwksFixture) -> None:
    """api-50 — /api/openapi.json(m2m 호스트 · 전 자격) → 200 JSON: 경로·메서드 ⊇ {/healthz get · /ready get · /health get ·
    /session/check get · /sessions/revoke post · /webhooks/authentik post · /tenants/me get} · `/admin`을 담은 경로 0 ·
    revoke requestBody 스키마($ref 해석) 속성 ⊇ {sub, sid, all_devices, reason} · reason enum == {logout, logout_all, admin} ·
    required ⊇ {all_devices, reason} · 성공 코드(revoke 202 · session/check 200 · tenants/me 200 · webhook 202) ·
    session/check 질의 sub(필수 · string) · iat(필수 · integer) · sid(선택). 스냅샷 파일은 템플릿 test_openapi_snapshot의
    몫이고 이 테스트는 스냅샷 갱신이 계약 구조를 조용히 지우지 못하게 한다."""
    headers = _headers(jwks_server, M2M_HOST, bearer=_bearer(jwks_server, "openapi-sub", TENANT_A))
    response = _get(Client(), OPENAPI_PATH, headers)
    assert response.status_code == 200
    spec: dict[str, Any] = json.loads(response.content)
    paths: dict[str, Any] = spec.get("paths", {})
    present = {(path, method) for path, item in paths.items() for method in item if method in HTTP_METHODS}
    expected = {
        ("/healthz", "get"),
        ("/ready", "get"),
        ("/health", "get"),
        (CHECK_PATH, "get"),
        (REVOKE_PATH, "post"),
        (WEBHOOK_PATH, "post"),
        (TENANTS_ME, "get"),
    }
    assert sorted(expected - present) == []
    assert [path for path in paths if "/admin" in path] == []
    revoke = paths[REVOKE_PATH]["post"]
    schema = _deref(spec, revoke["requestBody"]["content"]["application/json"]["schema"])
    properties = schema.get("properties", {})
    assert {"sub", "sid", "all_devices", "reason"} <= set(properties)
    assert _enum_values(spec, properties["reason"]) == {"logout", "logout_all", "admin"}
    assert {"all_devices", "reason"} <= set(schema.get("required", []))
    codes = {
        (REVOKE_PATH, "post"): "202",
        (CHECK_PATH, "get"): "200",
        (TENANTS_ME, "get"): "200",
        (WEBHOOK_PATH, "post"): "202",
    }
    missing = [
        f"{method.upper()} {path} {code}"
        for (path, method), code in codes.items()
        if code not in paths[path][method].get("responses", {})
    ]
    assert missing == []
    query = {p["name"]: p for p in paths[CHECK_PATH]["get"].get("parameters", []) if p.get("in") == "query"}
    assert {"sub", "iat", "sid"} <= set(query)
    assert (query["sub"].get("required"), _types(spec, query["sub"].get("schema", {}))) == (True, {"string"})
    assert (query["iat"].get("required"), _types(spec, query["iat"].get("schema", {}))) == (True, {"integer"})
    assert query["sid"].get("required", False) is False
