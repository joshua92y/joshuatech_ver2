# T072 설계: `templates/django-pod` 완성 → T065 PASS

2026-11-07 확정(컨트롤러). 조사 `wf_2688d649-760`(리더 5 — 보고 `.superpowers/t072/research/*.json`) → 설계 초안 `wf_0ccb979c-612`(설계자 1 · 비판 2렌즈 — A 계약 · 하네스 · 인계 approve_with_fixes medium 6 · low 12 / B 보안 · 운영 · gitops approve_with_fixes medium 3 · low 13 — 보고 `.superpowers/t072/design-critic{A,B}.json`) → 컨트롤러가 비판을 반영했다. 본문은 반영 뒤 모양이고 반영 내역은 §10 반영표(X1–X33 — X33은 컨트롤러 실측)에 있다. 반영으로 바뀌거나 더해진 줄 끝에는 〔Xn〕을 단다. 빌드 라운드의 결과와 정정은 build-notes 「## T072」 절에 이어 적는다(이 문서는 태스크가 닫히면 고치지 않는다 — 규칙 specs.md).

## 약어

- **계약** = `specs/003-platform-foundation/contracts/pod-template.md`
- **규칙** = `.claude/rules/django-pod.md`
- **bn** = `specs/003-platform-foundation/design/build-notes.md`
- **tasks** = `specs/003-platform-foundation/tasks.md`
- **H** = `templates/django-pod/`
- **dc** = `packages/django-common/`
- **gitops:** = `D:\code\platform-gitops`
- **venv** = 루트 `.venv/Lib/site-packages`(Django 6.1.2 · django-ninja 1.7.3)
- **〔조사 X Fnn〕** = `.superpowers/t072/research/<X>.json`의 발견 ID. 외부 근거와 실측 출처는 그 JSON에 있다.
- **〔R n〕** = report.md 편차 후보(§1 목록).
- **〔Xn〕** = §10 반영표 항목(설계 비판 A-n · B-n을 반영한 자리).

---

## 1. 과제 문면과 계약 우선 원칙

### 문면 요약(tasks:189)

T072가 만들어야 할 것은 다음과 같다.

- **copier.yml**: 질문 · `_tasks: uv lock` · `_min_copier_version 9.17`
- **`template/{{pod_snake}}/`**
  - pydantic-settings 필수값: `DATABASE_URL`(verify-full 「고정」) · `ALLOWED_HOSTS` · `ADMIN_HOST`(빈 값 허용) · `ACCESS_*` · `AUTH_ACTOR_SUB`(선택) · Dragonfly URL · 「타임아웃 표」
  - `MAILERS`만 쓴다.
  - urls · Ninja api · core TenantModel/GlobalModel 예
  - events 헬퍼 · management
  - Celery beat 작업 = outbox dead purge
- **pyproject.toml.jinja**: Django 6.1 · `ninja==1.7.0`(1.6.2 폴백) · psycopg[binary] 3.3 · celery 5.6 · 「django-common workspace」 · 테스트 의존 + linter · `pytest -W error::DeprecationWarning`
- **Dockerfile**: uv 0.12.8 빌더 → `python:3.13-slim-trixie@sha256:…` · `--locked --no-install-project --no-dev` · non-root · arm64
- **compose.dev.yml** · **env.example**
- **tests/**: 6종 + `makemigrations --check` + linter
- **deploy/base**: web+relay · 프로브 3종 · 전략 · requests · securityContext · CA · Reloader · 「relay 컨테이너 scrape」 · Service · Ingress 5경로 · ES 2 · PreSync migrate Job(CONNECT SQL) · ConfigMap

### 계약 우선 원칙

문면과 계약이 다르면 계약이 이긴다(규칙:14 "On conflict, the contracts prevail; amend them first"). 하네스 가정 ①–⑩을 바꾸려면 계약을 먼저 개정해야 한다(H/tests/test_generate.py:8-9 — 그 독스트링이 가리키는 bn 「T065」 절은 닫힌 태스크라 고치지 않고, 가정 변경은 이 문서 D21과 계약 §기본 테스트 6에 적는다. 독스트링의 개정 지시도 그렇게 바꾼다 · 〔X11〕).

### 문면과 정본의 어긋남(정본을 따른다)

- **A1** `-W error::DeprecationWarning` → 자기 모듈로 한정한 filterwarnings. 근거: 계약:36 · 규칙:68 · H/tests/_tree.py:250-266. 〔R1〕
- **A2** 「django-common workspace」 → path 소스를 쓰는 독립 uv 프로젝트. 근거: 계약:23 · 규칙:19. 〔R2〕
- **A3** 「relay 컨테이너 scrape」 → web pod 템플릿 어노테이션 + relay 포트 9464. 근거: 계약:78,108 · H/tests/_render.py:673-692. 〔R3〕
- **A4** `ninja==1.7.0`(1.6.2 폴백) → `django-ninja==1.7.0` 정확 핀. 폴백은 계약 · 하네스(H/tests/_tree.py:79)를 개정한 뒤에만 쓴다. 〔R4〕
- **A5** settings 「타임아웃 표」 → 라이브러리가 소유하는 고정값이다(events.md:132-133 · 규칙:38,43 · 계약:91-93). 템플릿은 이 값을 다시 넣지 않는다. Authentik 재시도는 T073 몫이다. 〔R5〕
- **A6** `DATABASE_URL` 「고정」 → ES 리터럴(하네스 ③)로 지킨다. settings 검증은 dev/prod에서만 verify-full을 요구하고, ENV=test는 require 이상이면 된다(계약:36 · MIS-07). 〔R6〕
- **A7** ConfigMap 목록 → 계약:80 목록에 `ENV` · `KAFKA_BOOTSTRAP` · `KAFKA_USERNAME` · `OTEL_*` · `FORCE_SCRIPT_NAME`을 더하고 `IDENTITY_M2M_URL`은 뺀다(pod 소비자 없음, contracts/bff-api.md:14). 〔R7〕
- **A8** 문면에 없는 has_celery=false CronJob도 만든다(계약:44,84,108). 〔R8〕
- **A9** 문면 `<pod>-env`의 openfga → 템플릿 base에는 없다. identity-admin 전용이고(contracts/identity-admin-api.md:89-105) T073이 더한다. 〔R9〕
- **A10** 「non-root」/계약:24 `USER app` → `USER 10001:10001` + pod `runAsUser/runAsGroup 10001`. kubelet은 이름 USER로 runAsNonRoot를 판정하지 못한다(〔조사 tooling K3〕 · 〔조사 harness F33〕). 〔R10〕
- **A11** 문면에 없지만 다른 근거가 요구하는 것:
  - web 9100 · `http_requests_total`(bn:3363 · 4322) 〔R11〕
  - SECRET_KEY 필수 비밀과 kv 경로(bn:3533 · 4323) 〔R12〕
  - 사람 admin 경로를 T084로 미룸 〔R13〕
  - `<pod>-migrate` ES를 PreSync hook으로 둠 〔R14〕
  - app role GRANT 마이그레이션 〔R15〕
- **A12** 다른 태스크 문면에 남은 어긋남은 인계한다(§7).
  - T073 생성 명령(`--trust` · 키마다 `--data` — 계약:3)
  - T075 `ACCESS_EXPECTED_CN web-bff-<env>`(정본 = Client ID, 계약:74)
  - T076 `tests/fixtures/generated/sample-pod`(배치 = `…/apps/sample-pod`, 계약:5)
- **A13** research/plan의 낡은 결정은 쓰지 않는다: gRPC 4317 · django-health-check · 별도 pod-template 저장소 · cloudevents · OTel 1.44 판 번호(MIS-18). 계약과 dc 실제 판을 따른다.
- **A14** T071 · T100 문면(/ready = health-check · `send_default_pii=False`) → `health_router`의 `SELECT 1` · configure_sentry를 그대로 쓴다(MIS-19).
- **A15** 비판 반영으로 더한 것(문면 · 계약에 없는 동작 — 계약 보정과 함께): 클러스터 교차 규칙(`POD_NAMESPACE` — ENV · KAFKA_USERNAME · DB 사용자 · ALLOWED_HOSTS · 〔X8〕) · SECRET_KEY 강도(〔X21〕) · 자격 URL 사용자 정보 문자 집합(〔X25〕) · web preStop sleep 5 s(〔X29〕) · migrate Job의 `subprocess.call`(골든 꼴 · 〔X4〕). 〔R17〕

### 하네스 · 계약 · gitops 사이의 어긋남과 고칠 쪽

- **G1** 골든 ES의 store/키 자리값(H/tests/fixtures/golden-render.yaml:384,394,413,423)은 gitops 검사 3.0 · 3.1(gitops:tests/validate.sh:1242-1291)에 걸린다 → **골든을 고친다**(dev 값).
- **G2** gitops-repo.md:105-116은 DATABASE_URL을 kv `url`로 바로 쓰는 예시이고, 하네스 ③은 template.data 조립을 요구한다 → **하네스를 유지**하고, 계약 예시와 T075를 맞춘다.
- **G3** gitops-repo.md:24-26 base 파일 목록에 celery · CronJob이 없다 → **계약 gitops-repo를 보정**한다.
- **G4** 골든 Ingress host가 `placeholder.invalid`이고 Traefik 주석이 없다(golden-render.yaml:337) → 골든과 템플릿 모두 `PLACEHOLDER.joshuatech.dev` + 주석 두 개(gitops:bootstrap/argocd/ingress.yaml:31-34).
- **G5** 골든 Job의 ConfigMap envFrom(golden-render.yaml:299)은 첫 배포 교착 원인이다(〔조사 shape F16〕) → **골든을 고친다**.
- **G6** D13 `USER app`(bn:772) → 숫자 UID(A10).
- **G7** gitops:platform/cnpg-databases/README.md:364는 「migrate Job 첫 단계 + app role 테이블 GRANT」로 적었다. 이 설계는 GRANT를 pod 마이그레이션에 둔다(D12) → README 문장을 T075 PR에서 고친다.
- **G8** scripts/ci/kubeconform-deploy.sh:56-61 주석은 `--trust`가 없고 「copier 잠금 없음」이 낡았다 → **스크립트 주석을 고친다**(D22).

---

## 2. 소스로 확인한 사실(설계에 꼭 필요한 것만)

**하네스 상태와 고정값**

- **①** 하네스는 173개다. 지금 결과는 `4 failed, 155 passed, 14 errors`이고, 템플릿에는 `.gitkeep`만 있다(bn:778 · H/tests/test_generate.py:4-5). 판정 명령은 `uv run --directory templates/django-pod --locked pytest -q`, 인프라만 고르려면 `-k "tool or render or check"`(155)를 쓴다(〔조사 harness F01〕).
- **②** 하네스가 고정한 것:
  - 생성 명령 `python -m copier copy --trust --defaults --quiet --data pod_name=sample-pod <절대 경로> <root>/apps/sample-pod`(H/tests/_layout.py:127-141)
  - 미니 저장소는 dc의 pyproject와 src만 복사한다(가정 ⑦, test_generate.py:16-17).
  - 단계 사슬: 생성 → `uv sync --locked` → 생성물 pytest(`--tb=short --junit-xml`, H/tests/conftest.py:106-119) → buildx arm64 `--load`(:122-153) → kustomize → kubeconform(:156-195)
- **③** 가정 ①–⑩(test_generate.py:8-23): 워크로드 식별(Deployment 정확히 2 · Job 1) · 첫 컨테이너 SQL 리터럴 · ES template.data URL · 답변 파일 · path 소스의 정확한 꼴 · USER 비-root · 미니 배치 · Job 컨테이너 전부 -migrate+CA · celery 192Mi · ConfigMap 참조 단언 범위.
- **④** 계약:108이 T072에 test-first로 맡긴 넷(grace ≥ 90 · PROMETHEUS_MULTIPROC_DIR 부재 · has_celery=false 렌더 · `call_command("outbox_purge")`)은 하네스에 0건이다(〔조사 harness F30〕).
- **⑤** 변이 표: 68건(render-02..69, H/tests/test_render_helpers.py:438-511). 「맡은 검사만 위반 · 교차 0」(:523-530)과 「검사마다 변이 ≥ 1」(:532-537)이 불변식이다. `-k` 선택은 모듈 이름에도 걸리므로 test_generate.py의 새 이름에 tool · render · check 낱말을 쓰면 안 된다(test_generate.py:6).

**copier 9.19.1(하네스 venv 소스)**

- **⑥**
  - `_subdirectory`를 쓰면 기본 `_exclude`가 비어 `.gitkeep` · `__pycache__`가 복사된다(copier/_template.py:336-347).
  - `_tasks`가 있으면 `--trust`가 필요하다(copier/_main.py:309-328). `--skip-tasks`는 신뢰 판정에서 tasks를 뺀다(copier/_cli.py:165-175).
  - task가 실패하면 대상 디렉터리를 rmtree한다(copier/_main.py:399-445).
  - `_min_copier_version`은 따옴표 친 문자열이어야 한다. float는 InvalidVersion이다(copier/_template.py:161 · 〔조사 tooling C2〕).
  - `when: false` 계산값도 `--data`로 덮을 수 있고, 덮은 값은 validator를 거친다(copier/_user_data.py:465-478 · 〔조사 tooling C6〕).

**Django · Ninja · pytest-django**

- **⑦** pytest-django는 conftest보다 먼저 settings를 적재한다(pytest_django/plugin.py:274-279,389-397 · 〔조사 harness F32〕). 하네스는 env를 주지 않는다(〔조사 harness F05〕).
- **⑧** Django 6.1
  - `MAILERS`는 옵트인이다(venv django/conf/global_settings.py:189-192).
  - `MAILERS = {}`는 경고 `mail.W001`을 낸다(django/core/checks/mail.py:7-29). dummy backend는 deploy 검사 `mail.E001`에 걸린다(:40-63).
  - MAILERS를 정의하면 `EMAIL_*` 설정이 금지된다(django/conf/__init__.py:65-68,128-130).
  - `LOGGING_CONFIG`가 거짓이면 기본 dictConfig를 건너뛴다(django/utils/log.py:69-78).
  - `ADMINS = []`(global_settings.py:26) · `FORCE_SCRIPT_NAME = None`(:248)
  - `staticfiles.views.serve(request, path, insecure=True)`는 DEBUG가 꺼져도 finders로 서빙한다(django/contrib/staticfiles/views.py:16-41).
  - 관리 명령 탐색은 INSTALLED_APPS 앞쪽 앱이 이긴다(django/core/management/__init__.py:76-78).
- **⑨** Ninja(venv 1.7.3)
  - 기본 처리기: Http404 · HttpError → `{"detail"}`, ValidationError → 422, Exception은 DEBUG가 꺼져 있으면 다시 올린다(ninja/errors.py:87-133).
  - JSON이 아닌 본문은 `HttpError(400)`이다(ninja/params/models.py:136-141).
  - pod 핀 1.7.0의 소스는 읽지 못했다. VD-T071-1이 1.7.0에서 PASS다(bn:3301).

**django-common**

- **⑩** 공개 API · import 제약
  - tenancy · outbox는 `django.setup()` 전에 import할 수 없다(〔조사 library F08〕).
  - `check_settings()`는 네트워크가 0이다(dc/src/django_common/auth.py:742-778).
  - `check_rls(*, using, require_rls_role)`(tenancy.py:624-768)
  - `relay.producer_config()` · `relay_settings()`는 네트워크 0이고 metrics는 지연 import한다(outbox/relay.py:196-215,409).
  - `ENVELOPE_PATTERNS`(outbox/publisher.py:81-87). `_envelope.json` 필수 키 9 · const 2(specversion "1.0" · datacontenttype "application/json")는 packages/events/schemas/_envelope.json에 있다.
- **⑪** dc 시험 도우미는 wheel 밖이라 생성 pod가 import할 수 없다(〔조사 library F33〕). 이식 대상:
  - pg-tls 이미지(dc/tests/docker/pg-tls)
  - role 부트스트랩(dc/tests/conftest.py:158-197)
  - kafka(:264) · dragonfly digest + ACL SETUSER(:308-391) · jwks_server(:439) · log_sink(:551) · otel(:621)
  - win32 override(:62)
  - `_jwt`(JWKS_PATH · BEARER_AUDIENCE = identity-admin 고정, dc/tests/_jwt.py:35,41)

**T066 · T071 인계**

- **⑫** T066 test_api.py
  - 가정 ①–⑨(apps/identity-admin/tests/test_api.py:40-71)
  - 기동 하위 프로세스: env = 시험 프로세스 os.environ + 실제 pod settings 모듈. 비밀은 64자 난수로 바꾼다(:863-897). 공개 DNS 가드를 쓴다(:758-778).
  - Celery 앱 `identity_admin.celery.app` + `import_default_modules()`(:643-647)
  - eager False 단언(:1526-1527)
  - BOOT_SETTINGS로 `ADMIN_SCRIPT_NAME` · `FORCE_SCRIPT_NAME`(Django 전역 None) · `STATIC_URL`을 읽는다(:262-270).
- **⑬** T071 D14 T072 줄(bn:3380)과 그 표식:
  - 호출 자리 · LOGGING 경계 · 필수값 · connect_timeout 2 · OTEL 엔드포인트 스킴 · 프로브 Host · 9100 · CeleryIntegration · SSL_CERT_FILE/REQUESTS_CA_BUNDLE
  - 〔r7 S4 · r8 L3〕 NETRC · SSLKEYLOGFILE · 프록시(소문자 포함) · `.netrc` · `_netrc` · CLIENT_CERT_FILE · CLIENT_KEY_FILE은 렌더 · 이미지 단언으로 막는다(bn:4119,4175).
  - 〔r10 I5〕 `--show-capture=no` · except 밖 configure_sentry · CI django-common pytest(bn:4262)

**이미지 · 의존 판**

- **⑭** `USER app` + `runAsNonRoot`는 kubelet이 거부한다(〔조사 tooling K3〕). gitops 선례는 숫자 runAsUser를 못박는다(gitops:platform/cloudflared/deployment.yaml:46-53 · 〔조사 shape F09〕).
- **⑮** 하네스가 빌드할 때 Windows `.venv`가 컨텍스트에 들어간다. Docker는 `<Dockerfile 이름>.dockerignore`를 우선한다(〔조사 tooling U4〕).
- **⑯** 이미지 digest
  - `uv:0.12.8-python3.13-trixie-slim` Docker Hub 인덱스 `sha256:6fe190f0…`(Python 3.13.15). ghcr 값은 미확인이다(〔조사 tooling U6〕).
  - `python:3.13-slim-trixie` 인덱스 `sha256:09a17cad…`(3.13.18, 〔조사 tooling U7〕).
  - uv 0.12.8은 GHSA-hq85(High, 0.13.4에서 수정)에 걸린다(〔조사 tooling U5〕).
- **⑰** `celery[redis]` + dc의 `redis>=8.1`이 kombu 5.7.0을 강제한다(〔조사 tooling V5〕). celery 5.6 계열의 마지막은 5.6.3이다(V4).
  - Dragonfly pod 사용자는 `resetchannels`다(gitops:platform/dragonfly/README.md:106).
  - Celery 원격 제어 · gossip · heartbeat는 팬아웃 pub/sub을 쓴다(〔조사 tooling D1〕).
  - kombu Lua는 만료 큐에서만 선언 안 된 키에 닿는다(D2).
  - 0.2 s socket_timeout은 BRPOP 1 s 대기와 부딪친다(D4).
- **⑱** gunicorn 25.1+는 제어 소켓을 기본으로 만든다(`--no-control-socket`으로 끈다, 〔조사 tooling V9〕).
- **⑲** django-migration-linter 6.0.0의 분류자는 Django ≤ 6.0이다(〔조사 tooling V7〕).

**gitops**

- **⑳** gitops validate는 `apps/<pod>/base` 자체와 파일 하나하나를 검사한다(〔조사 shape F01〕).
  - ES: v1 · ClusterSecretStore · store 5개 · 키 정규식 · dataFrom은 extract만(gitops:tests/validate.sh:1242-1291)
  - 워크로드: automount false · 비-Job의 `-migrate` 참조 금지(:1313-1340)
  - images는 digest 필수(:1405-1456)
  - 긍정 픽스처 꼴은 base = dev 값, prod overlay가 store · 키를 JSON6902로 바꾸는 것이다(gitops:tests/fixtures/positive/apps/identity-admin/base/externalsecrets.yaml:1-28).
- **㉑** Argo PreSync hook은 Sync 단계 리소스보다 먼저 돈다. 첫 배포에서 `<pod>-migrate` Secret · ConfigMap이 없어 교착될 수 있다(〔조사 shape F16〕, 추론). ESO ExternalSecret에는 Argo v3.5.2 내장 health lua가 있다(gitops:clusters/oci-k3s/apps/platform-cnpg-databases.yaml:31-32).
- **㉒** 쿼터 · LimitRange: jt-dev는 requests 2Gi / limits 4Gi / pods 20, jt-prod는 3Gi / 6Gi / 30. LimitRange는 `default.memory 512Mi`만 둔다(gitops:platform/policies/quota.yaml:19-64). jt-dev 검사 Job 중 kafka-assert는 320Mi/640Mi다(gitops:platform/policies/tests/job-kafka-assert.yaml:309-311).
- **㉓** Ingress 선례: entrypoints websecure 필수 · router.tls "true" · spec.tls 없음(gitops:bootstrap/argocd/ingress.yaml:10-13,31-34). T076은 m2m 호스트에서 `/healthz` · `/ready` · `/webhooks/authentik`이 404이기를 단언한다(tasks:196).
- **㉔** kv 키: `{env}/db/<접두>/{app,owner}` = username · password · url(`database` 키 없음), `kafka/<pod>` = password, `dragonfly/<pod>` = url, `authentik/<pod>` = issuer · jwks_url, `sentry/<pod>` = dsn(data-model.md:160-171). SECRET_KEY 행은 없다.
- **㉕** app role 테이블 GRANT는 「각 pod 마이그레이션(T072)」 몫으로 적혀 있지만 계약에는 장치가 없다(gitops:platform/cnpg-databases/README.md:63 · 〔조사 spec UND-08〕).

**CI**

- **㉖** CI 현재 상태:
  - test job은 자리표시다(.github/workflows/ci.yml:324-345).
  - kubeconform job의 run 줄은 `bash scripts/ci/kubeconform-deploy.sh`(:396-397)
  - 경보선(scripts/ci/kubeconform-deploy.sh:307-326)
  - ps1 static-6(tests/scripts/kubeconform-deploy.tests.ps1:312-314) · test 7(:405-412, FAIL 문구에 `--generated` · `T072`) · r-1(:671-677, 실제 저장소 = 대상 없음)

**비판 반영 때 더한 사실**(컨트롤러 확인)

- **㉗** 로컬 uv는 0.12.6이다 — GHSA-2cv4(0.12.7–0.12.17)는 비해당, GHSA-hq85는 해당(〔조사 tooling U5〕). 하네스 tool-2는 `uv >= (0, 12)`만 본다(H/tests/test_fixtures_tools.py:16,33-40).
- **㉘** gunicorn(gthread)은 plan 단계 research의 기준 템플릿에 있다(research.md:3181 `gunicorn>=23` · :3433 `CMD ["gunicorn", … "-k", "gthread", "--threads", "4", "--workers", "2"]`). gthread와 ASGI의 선택만 범위 밖으로 남았다(:3503). 〔X12〕
- **㉙** T065 사용자 확인 항목(독립 uv 프로젝트 · copier update 미지원 — bn:757)은 2026-11-03 14:07 KST 사용자에게 「이의가 없으시면 그대로 · 바꾸시려면 T072 전에만」으로 고지했고 이의가 없었다(세션 기록). 종결로 본다. 〔X6〕
- **㉚** T066 기동 하위 프로세스는 래퍼가 아닌 `DJANGO_SETTINGS_MODULE=identity_admin.settings`로 뜨고, 비밀 이름 env를 64자 URL-safe 난수로 바꾼다(apps/identity-admin/tests/test_api.py:811-834 · 863-897 · :313 「Django SECRET_KEY 권장 50자 이상」). 시험 래퍼가 os.environ을 덮어써도 자식 기동은 영향이 없고, SECRET_KEY 강도 검사(〔X21〕)도 64자 난수는 늘 통과한다.
- **㉛** Windows CPython의 `os.execv`는 새 프로세스를 띄우고 원래 프로세스를 끝낸다 — 부모 `subprocess.run`은 자식이 끝나기 전에 종료 코드를 받는다(bpo-9148 · bpo-19124 · 비판 A-4). 컨테이너 PID 1인 Python은 SIGTERM 처리기가 없으면 신호를 무시하므로(리눅스 PID 1 규칙) `execv`와 `subprocess.call`의 신호 동작에는 차이가 없다. 〔X4〕
- **㉜** `staticfiles.views.serve`의 경로 탈출(`/static/../conf.py`)은 `safe_join`의 `SuspiciousFileOperation`이 되어 handler400 → 400 `validation_error`다(django/contrib/staticfiles/views.py:16-41 · finders.py:210-219 · core/files/storage/filesystem.py:181-196 — 비판 A-9 · B-13). 〔X9〕
- **㉝** relay 루프 오류는 로그 + 백오프로만 남고 liveness는 TCP 9464뿐이며, Alloy는 T098 전에는 없다(dc outbox_relay.py:244-361 · 계약:66 · gitops:platform/monitoring/kustomization.yaml:1-6). 그래서 Kafka 설정(ENV · KAFKA_USERNAME · CA 마운트)의 잘못은 T098 전까지 조용한 발행 중단이 된다(비판 B-1 · B-2). `client_config()`는 `ssl.ca.location` 파일을 열지 않는다(dc kafka.py:60,114-118). 〔X8 · X2〕
- **㉞** `<pod>-migrate` ES를 hook으로 두면 Argo 추적 밖이다: hook만 바뀐 커밋은 자동 sync를 일으키지 않고, hook 결과는 Application health에 들어가지 않는다(gitops:clusters/oci-k3s/apps/platform-cnpg-databases.yaml:51-52). hook이 Healthy가 되지 않으면 sync operation은 시간 제한 없이 멈춘다(argocd-cmd-params-cm에 sync timeout 없음 — 〔조사 shape F16〕). 〔X26〕
- **㉟** libpq는 연결 문자열에 없는 매개변수를 env(`PGOPTIONS` · `PGSSLCERT` 등)에서 읽는다 — `PGOPTIONS='-c statement_timeout=0'`이면 app role의 15 s 기본값을 덮는다. sentry-sdk 2.73은 `SENTRY_PRINT_ENVELOPES`가 참이면 envelope(dsn 포함)를 마스킹 밖 핸들러로 찍는다(sentry_sdk/transport.py:1098-1113,1261-1264). requests는 `REQUESTS_CA_BUNDLE`이 없으면 `CURL_CA_BUNDLE`을, OpenSSL 기본 문맥은 `SSL_CERT_DIR`을 읽는다(비판 B-6). 〔X18〕

---

## 3. 결정 D1–D22

### D1 범위

- **무엇**
  - 고치는 곳:
    - `H/copier.yml` · `H/template/**`
    - 하네스(`H/tests/**` · fixtures)
    - `.github/workflows/ci.yml`(test · kubeconform job)
    - `scripts/ci/kubeconform-deploy.sh`(머리 주석 · 경보선 FAIL 문구)
    - `tests/scripts/kubeconform-deploy.tests.ps1`
    - 계약 · 규칙 보정(§4)
  - 고치지 않는 곳: dc(공개 API로 충분 · 마스킹 목록 변경 없음) · 루트 pyproject members(T073) · gitops 저장소(T075).
- **왜**: T068–T071 계약 시험을 다시 열지 않는다. 범용 조각(오류 핸들러 · admin 접두 미들웨어)을 dc로 올리는 일은 SP-2 pod가 생긴 뒤로 미룬다.
- **기각한 대안**: dc에 settings 모델 · 오류 핸들러를 공용화. dc 계약 시험 범위가 넓어지고 일정이 늘어난다.
- **계약 · 규칙**: 없음.
- **시험**: §5 조각의 끝 조건.
- **변이**: 없음.

### D2 copier.yml

- **무엇**
  - `_subdirectory: template` 유지, `_min_copier_version: "9.17"`(따옴표, 문면 값 그대로 · ⑥)
  - `_tasks: [["uv", "lock"]]`(목록 꼴 → OS 셸 차이 없음 · 〔조사 tooling C4〕)
  - `_exclude: [".gitkeep", "__pycache__", "*.py[co]", ".pytest_cache", ".venv", ".DS_Store", "~*"]`(항목당 패턴 하나 → 9.17과 호환) + `template/.gitkeep` 삭제
  - `_envops: {undefined: jinja2.StrictUndefined}`(변수 오타가 생성 실패로 드러나게, 〔조사 tooling C7〕)
  - 질문은 계약 7개를 유지한다(계약:11-17).
    - **`pod_name`**: str, 기본값 없음. validator는 하나라도 어기면 고정 문구를 낸다.
      - `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`(봉투 source 패턴과 같음, publisher.py:83)
      - 길이 ≤ 39(CronJob `<pod>-outbox-purge` ≤ 52)
      - `dev`가 아니고 `dev-`로 시작하지 않음(data-model.md:113)
      - 앞뒤 공백 · 줄바꿈 없음(`pod_name == pod_name|trim`)
    - **`pod_snake`**: `when: false`, 기본값 `{{ pod_name | replace('-', '_') }}`. validator는 「파생값과 같아야 한다」(`--data` 덮기를 막는다).
    - **`description`**: 기본값 "". 한 줄 · ≤ 120자. Python · TOML에는 `tojson`으로 넣는다.
    - **`owns_events`**: yaml, 기본값 []. 각 항목이 `entity.event`(케밥 2성분)여야 한다.
    - **`consumes_events`**: yaml, 기본값 []. 각 항목이 `^[a-z][a-z0-9-]*(\.[a-z][a-z0-9-]*){2,}$`(성분 3개 이상인 전체 토픽 — 따옴표 · 개행 · 공백 0)이고 `dev.`로 시작하지 않아야 한다. Python 렌더는 `OWNED_EVENTS` · `CONSUMED_TOPICS` 모두 `tojson`이다. 〔X28〕
    - **`has_celery`** · **`has_admin`**: bool, 기본값 true.
  - 머리 주석 Usage를 `copier copy --trust --defaults --data pod_name=<pod> templates/django-pod apps/<pod>`로 고친다(H/copier.yml:3 · 계약:3).
  - 답변 파일: `template/{{ _copier_conf.answers_file }}.jinja` = `{{ _copier_answers|to_nice_yaml -}}`(가정 ④).
  - ESO Go 템플릿 `{{ .x }}`는 ES 파일의 template.data 블록만 `{% raw %}…{% endraw %}`로 감싼다.
  - 조건부 파일은 `{% if has_celery %}celery.py{% endif %}.jinja` 꼴이다(〔조사 tooling C8〕).
- **왜**
  - `_tasks`가 실패하면 대상이 통째로 지워진다(⑥). 그래서 lock 실패는 gen 전부 ERROR로 드러난다. 디버깅 안내(`--no-cleanup`)를 README와 rules에 적는다.
  - 네트워크(PyPI) 전제가 생기는 곳: 하네스 tool-6 · gen-4, T073 생성, CI test job. 재현성(생성 시점의 해석)은 D4와 UD-2가 다룬다.
- **기각한 대안**
  - 문자열 `_tasks`: Windows는 cmd, Linux는 sh로 돈다.
  - `_envops`로 Jinja 구분자를 바꾸기: 모든 .jinja 파일에 영향이 간다.
  - 템플릿이 uv.lock을 직접 싣기: pod 이름이 달라 lock이 맞지 않는다(〔조사 harness F09〕).
  - `_min_copier_version "9.17.2"`: 보안 수정판이지만 템플릿을 신뢰하므로 영향이 작다. 문면을 유지한다.
- **계약 · 규칙**: C1(렌더 · 검사 전용 `--skip-tasks` · 형제 없는 배치 예외 · 〔X3〕), data-model §6 보정(C29 · 〔X20〕).
- **시험**
  - gen-1 · gen-18(기존)
  - 새 gen-28: `copier copy --defaults --skip-tasks --pretend --data pod_name=<잘못된 값>`이 0이 아닌 종료 코드와 validator 문구를 낸다. 대상 값: `Bad_Name` · `dev` · `dev-x` · 40자 · `--data pod_snake=wrong` · `--data owns_events=[bad]` · `consumes_events`에 따옴표가 든 항목 · 성분 2개 항목(〔X28〕).
  - 새 gen-25: 생성물에 `.gitkeep`이 없다.
- **변이**: 따옴표 없는 9.17(float) → copier 자체 실패. validator 삭제 → gen-28이 잡는다.

### D3 생성 트리와 앱 구조

- **무엇**: 하네스 필수 파일 19개(H/tests/_tree.py:21-48)에 다음을 더한다.

```
apps/<pod>/
├── .copier-answers.yml · README.md · pyproject.toml · uv.lock · manage.py
├── Dockerfile · Dockerfile.dockerignore · compose.dev.yml · compose/dragonfly-dev.acl · env.example
├── <pod_snake>/
│   ├── __init__.py(비어 있음) · apps.py(PodConfig · ready) · conf.py(pydantic-settings 모델 · 검증) · settings.py
│   ├── startup.py(기동 단언 · D7) · urls.py · urls_admin.py(has_admin) · api.py · errors.py · middleware.py · metrics.py
│   ├── wsgi.py · gunicorn_conf.py · celery.py · tasks.py(has_celery)
│   ├── core/  __init__.py · apps.py · models.py(실행 안 되는 예 — D12) · migrations/{__init__.py, 0001_app_role_grants.py}
│   ├── events/  __init__.py(OWNED_EVENTS · publish_owned) · README.md(토픽 · 스키마 경로 · KafkaTopic 예) · consumers.py(consumes_events가 비지 않을 때)
│   └── management/commands/  outbox_relay.py(dc 재노출) · startup_check.py
├── tests/  __init__.py · settings.py(래퍼) · conftest.py · _jwt.py · _problem.py · _secret.py · _kafka.py · _outbox_fakes.py
│           docker/pg-tls/{Dockerfile, 00-tls-only.sh} · rlsapp/(시험 전용 A 등급 앱 · migrations 0001 · 0002_rls)
│           probe_urls.py · probe_admin_urls.py(has_admin) · snapshots/openapi.json · test_*.py 7개
└── deploy/base/  kustomization.yaml · configmap.yaml · externalsecret-env.yaml · externalsecret-migrate.yaml · migrate-job.yaml
                  deployment.yaml · deployment-celery.yaml(has_celery) · cronjob-outbox-purge.yaml(has_celery=false) · service.yaml · ingress.yaml
```

  - INSTALLED_APPS(has_admin): `django.contrib.{admin,auth,contenttypes,sessions,messages,staticfiles}` → `<pod_snake>` → `<pod_snake>.core` → `django_common`.
    - has_admin=false면 contrib를 하나도 두지 않는다.
    - `<pod_snake>`가 `django_common`보다 앞이라 재노출 `outbox_relay`가 이긴다(⑧). 동작은 같다.
  - 파일 이름 `test_api.py` · `_identity_fakes.py` · `test_identity_fakes.py`는 쓰지 않는다(test_api.py:68-69 가정 ⑧).
- **왜**: 계약 트리(계약:21-45)와 인계(bn:799 Celery 레이아웃 · bn:3380 wsgi/AppConfig)를 한 트리로 맞췄다. 템플릿 deploy 파일 이름 = gitops base 이름이라 T075 복사가 1:1이다(〔조사 shape F19〕).
- **기각한 대안**: core에 실제 예시 모델을 둔다. 그러면 모든 pod DB에 예시 표가 생기고, B 예시는 허용 목록 밖이다(D12).
- **계약 · 규칙**: C6.
- **시험**: 새 gen-25(T072 추가 파일 목록 · 금지 이름 · .gitkeep 0 — 기존 REQUIRED_FILES는 T065 계약 트리 그대로 둔다: 변형마다 조건부 파일 집합이 달라 T072 도우미가 has_celery · has_admin · consumes_events 매개변수를 받는다 · 〔X19〕), gen-29(변형 트리 두 벌 — D21).
- **변이**: celery.py 조건문 반전 → 변형 트리 검사가 잡는다.

### D4 pyproject.toml.jinja와 잠금 정책

- **무엇**
  - `requires-python = ">=3.13,<3.14"`(K9 정렬)
  - dependencies:
    - `django>=6.1.3,<6.2`(보안판 하한 · 〔조사 tooling V1〕)
    - `django-ninja==1.7.0`
    - `psycopg[binary]>=3.3,!=3.3.7,<4`(3.3.7 회귀 제외 · V3)
    - has_celery일 때만 `celery[redis]>=5.6.3,<5.7`
    - `django-common`
    - `pydantic-settings>=2.16,<3`
    - `gunicorn>=26.2,<27`
    - `prometheus-client>=0.23,<1`(metrics.py가 직접 import)
  - dev 그룹: `pytest>=9,<10` · `pytest-django>=4.14,<5` · `testcontainers[postgres]>=4.15,<5` · `django-migration-linter>=6,<7` · `pyyaml>=6,<7`(migrate Job 스크립트 시험 · D17)
  - `[tool.uv] package = false`
  - `[tool.uv.sources] django-common = { path = "../../packages/django-common", editable = true }`(가정 ⑤ — 정확 꼴)
  - pytest 설정:
    - `DJANGO_SETTINGS_MODULE = "tests.settings"` · `testpaths = ["tests"]` · `pythonpath = ["."]`
    - `addopts = ["--tb=short", "--show-capture=no"]`
    - `filterwarnings = ["error::DeprecationWarning:<pod_snake>", "error::DeprecationWarning:tests"]`
  - 잠금은 copier `_tasks: uv lock`이 생성 시점에 만든다. 숙성 창 `exclude-newer`는 UD-2 결정에 따른다.
  - PyJWT 핀은 pod에 두지 않는다. 생성 잠금의 PyJWT 판은 VD-T072-2에서 확인한다.
- **왜**
  - gen-2 판정(H/tests/_tree.py:215-275)
  - `--show-capture=no`: 생성물 기동 시험이 비밀 · 감시 값을 심으므로 실패 출력이 그것을 싣지 않게 한다(〔r10 I5〕 · 규칙:69).
  - 「django-common workspace」 · 「celery 5.6」 · 「-W」는 A1 · A2를 따른다.
  - celery를 has_celery에만 둔다: CronJob pod에 쓰지 않는 의존을 넣지 않는다.
- **기각한 대안**
  - 1.6.2 폴백 장치: gen-2가 FAIL한다(A4).
  - celery를 항상 넣기: 변형 venv 공유는 쉬워지지만 이미지가 커진다. 변형 시험은 기본 venv(상위 집합)로 돈다(D21).
  - pytest-timeout: 새 dev 의존이고 하네스가 1800 s로 이미 막는다.
- **계약 · 규칙**: C2 · C24(규칙 §Tests에 생성 pod `--show-capture=no`).
- **시험**: gen-2(기존), 새 gen-26 `check_pytest_hygiene`(addopts에 `--show-capture=no` · 넓히는 옵션 0 · DJANGO_SETTINGS_MODULE). 자기검사 golden과 변이는 test_check_helpers에 둔다.
- **변이**: `--show-capture=all` · `-l` · `log_cli = true` · `-o addopts=` → gen-26이 잡는다.

### D5 settings 모델(`<pod_snake>/conf.py`)

- **무엇**: pydantic-settings `BaseSettings` 하나. 프로필은 env `JT_SETTINGS_PROFILE` ∈ {runtime(없음 · 기본), migrate}이고 모르는 값은 거부한다. 모델 설정은 `case_sensitive=True` · env_file 없음 · `hide_input_in_errors=True` · `env_ignore_empty=False`(빈 값 = 유효한 값 · 〔조사 tooling V6〕)다.
  - **runtime 필수(존재)**
    - 비지 않음:
      - `SECRET_KEY`(비밀 · 강도: 길이 ≥ 50 · 서로 다른 글자 ≥ 5 · `django-insecure-` 접두 아님 — Django `security.W009` 기준 · 어기면 이름만 · 〔X21〕)
      - `DATABASE_URL`(postgresql/postgres 스킴 · 호스트 · DB 이름 · 쿼리는 sslmode · sslrootcert만 · 사용자 정보는 `[A-Za-z0-9_-]`만 — libpq URI 파서 오류 문구가 자격 조각을 싣지 않게 · 〔X25〕)
      - `DRAGONFLY_URL`(사용자 정보 `[A-Za-z0-9_-]`만 · 〔X25〕) · `KAFKA_BOOTSTRAP`(host:port 쉼표 목록) · `KAFKA_USERNAME` · `KAFKA_PASSWORD`(비밀)
      - `AUTHENTIK_ISSUER` · `AUTHENTIK_JWKS_URL` · `AUTHENTIK_AUDIENCE`
      - `ACCESS_TEAM_DOMAIN` · `ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN`
      - `ALLOWED_HOSTS`(`NoDecode` 쉼표 분해, 항목 ≥ 1, `*` 금지)
      - `ENV` ∈ {dev, prod, test}
      - `APP_VERSION`(비지 않음) · `APP_GIT_SHA`(소문자 hex 7–64, 이미지 ENV에서 온다)
    - 빈 값 허용: `ACCESS_AUD_ADMIN` · `ADMIN_HOST`
  - **runtime 선택(기본값 "")**: `AUTH_ACTOR_SUB`(MIS-13 — 문면 · 라이브러리 해석 · C17) · `SENTRY_DSN`(빈 값 = 끔) · `FORCE_SCRIPT_NAME`(has_admin · 꼴 `/<케밥>` · 끝 슬래시 없음 → 설정 `ADMIN_SCRIPT_NAME`) · `POD_IP`(IP 리터럴 → D8) · `POD_NAMESPACE`(downward API — 아래 클러스터 교차 규칙 · 〔X8〕) · `JT_PLACEHOLDER_EXEMPT`
  - **runtime 거부**: 비지 않은 `DATABASE_OWNER_URL`. 런타임에 owner 자격이 섞인 사고를 기동 실패로 바꾼다(규칙:55 심층 방어).
  - **교차 규칙**(모델 생성 뒤 일반 코드로 이름을 모은다)
    - dev/prod: `DATABASE_URL`이 `sslmode=verify-full`과 `sslrootcert=/etc/pg/ca.crt`를 가져야 한다. test는 require · verify-ca · verify-full이면 된다(A6).
    - dev/prod: `ACCESS_TEAM_DOMAIN`의 `http://`를 거부한다. 루프백 http는 ENV=test만 허용한다(bn:2264-2281 N7).
    - 클러스터 안 URL(`DATABASE_URL` 호스트 · `DRAGONFLY_URL` 호스트 · `KAFKA_BOOTSTRAP` 호스트들 · `AUTHENTIK_JWKS_URL` · process env의 OTLP 엔드포인트 둘)의 호스트가 `joshuatech.dev`이거나 그 하위면 거부한다(계약:80 · 규칙:56).
    - 목록은 상수 `IN_CLUSTER_URL_SETTINGS` · `SECRET_SETTINGS`로 두어 T073이 넓힌다(SET-06).
    - **클러스터 교차 규칙**(`POD_NAMESPACE`가 있을 때 — D20이 런타임 컨테이너 전부에 fieldRef `metadata.namespace`로 둔다 · 〔X8〕)
      - `ENV`가 test가 아니고 `POD_NAMESPACE == "jt-" + ENV`다.
      - `KAFKA_USERNAME == ("dev-" if ENV == "dev" else "") + OUTBOX_SOURCE`(data-model §6 KafkaUser 이름).
      - `DATABASE_URL`의 사용자 == `("dev_" if ENV == "dev" else "") + "<pod_snake>_app"`(계약 DB · role 이름 행).
      - `ALLOWED_HOSTS`에 `<pod>.<POD_NAMESPACE>.svc`가 있다.
      - 왜: base ConfigMap이 dev 값이라 prod overlay가 ENV · KAFKA_USERNAME · ALLOWED_HOSTS를 빠뜨려도 렌더 검사가 막지 못하고, relay는 그 잘못을 로그 + 백오프로만 남긴다(㉝ — T098 전에는 감시도 없다). 기동 실패로 앞당긴다.
      - ENV=test는 클러스터 밖(생성물 시험 · 로컬 compose) 전용이 된다. sslmode require · Kafka PLAINTEXT · 루프백 http가 운영 이미지에서 열리지 않는다(〔X13〕).
  - **게이트 2**: 모델의 모든 문자열 값에 `PLACEHOLDER-`가 들어 있으면 거부한다. 예외는 env `JT_PLACEHOLDER_EXEMPT`(쉼표 이름 목록)와 코드 상수 `PLACEHOLDER_EXEMPTABLE`(템플릿은 빈 frozenset)의 교집합뿐이다. 상수 밖 이름을 env에 적으면 그것도 거부한다(bn:2998-3003 · bn:3238-3243 권고 안 1의 장치). identity-admin의 나가는 쪽 자격 목록은 T073 · T075가 정한다.
  - **migrate 프로필**
    - 필수: `DATABASE_OWNER_URL`(같은 URL 규칙). `ENV`는 선택이고, 없으면 verify-full을 강제한다(Job에는 ConfigMap이 없다).
    - 그 밖의 설정은 정의하지 않는다. `DRAGONFLY_URL` · `KAFKA_*` · `AUTHENTIK_*`를 읽는 코드는 전부 runtime 분기 안이다(ready의 configure_broker 포함 — D7). `<pod>-migrate`에 런타임 키를 더해 우회하지 않는다(owner 비밀의 범위가 넓어진다). 〔X7〕
    - `SECRET_KEY`는 비워 둔다(migrate는 SECRET_KEY에 접근하지 않음 — VD-T072-15).
  - **오류**: pydantic `ValidationError`와 교차 위반을 모아 `ImproperlyConfigured("설정 오류: <이름들>") from None`으로 낸다(계약:80 · 규칙:57). raise 줄 · 주석에 `input_value=` 글자를 두지 않는다(test_api.py:913-915).
  - **시험 모드 적재**: `tests/settings.py` 래퍼가 import 첫머리에서 pod 설정 키 전부(모델 필드의 env 이름 + `JT_SETTINGS_PROFILE` · `JT_PLACEHOLDER_EXEMPT` · `POD_IP` · `POD_NAMESPACE` · `DATABASE_OWNER_URL`)를 **덮어쓴다** — 필수값은 `os.environ[k] = 자리값`, 선택값 · 거부 대상은 지운다. 개발자 셸의 실제 env(포트 포워드한 dev 클러스터 등)가 시험 · 기동 하위 프로세스를 실서비스에 닿게 하지 않는다(〔X24〕). 값은 모양이 유효한 닫힌 포트 자리값이고, `SECRET_KEY`는 `secrets.token_urlsafe(48)`(64자)이다.
    - ENV=test
    - `ACCESS_TEAM_DOMAIN=http://127.0.0.1:<닫힌 포트>` · `DATABASE_URL=…?sslmode=require` · `DRAGONFLY_URL=redis://<pod>:…@127.0.0.1:<닫힌 포트>/0`
    - `AUTHENTIK_ISSUER=https://auth.joshuatech.dev/application/o/<pod>/` · `APP_VERSION=0.0.0+test` · `APP_GIT_SHA=0000000`
    - `PLACEHOLDER-` 없음
    - 닫힌 포트는 래퍼가 import할 때 127.0.0.1에 bind했다가 닫아서 얻는다.
    - 그다음 `from <pod_snake>.settings import *`
    - pytest-django가 conftest보다 먼저 settings를 적재하는 문제(⑦)를 이것으로 푼다. T066 ⑥과 같은 env를 기동 하위 프로세스가 물려받는다(⑥의 「`os.environ.setdefault`」는 덮어쓰기로 바뀌지만 결과 — 시험 프로세스 env에 키 전부 — 는 같고, 자식은 래퍼가 아닌 pod 설정 모듈로 뜬다 · ㉚). 실제 의존(시험 DB · Dragonfly)에 닿아야 하는 자식(D14 실제 워커 등)은 `DJANGO_SETTINGS_MODULE=<pod_snake>.settings`와 명시 env로 띄운다.
- **왜**: 계약:30,80 · 규칙:54-58 · T066 ⑥(test_api.py:55-60) · migrate Job은 `<pod>-env`를 받지 못한다(H/tests/_render.py:463-468 · 〔조사 library F29〕).
- **기각한 대안**
  - 프로필을 DATABASE_OWNER_URL 존재로 암묵 판별: owner 자격이 실수로 섞이면 런타임이 조용히 migrate 모드로 바뀐다.
  - 비밀을 전부 선택값으로: 비밀이 빈 값이면 실패해야 한다는 규칙(규칙:58)과 충돌한다.
  - `dj-database-url`: 새 의존이 필요 없다.
- **계약 · 규칙**: C17(설정 행) · C6.
- **시험**: test_auth_middleware 기동 위생, 하위 프로세스로 아래 경우를 본다.
  - 필수값 누락 · 비밀 빈 값 · 공개 도메인 JWKS/DB/Dragonfly
  - ENV=dev에서 http 팀 도메인 · sslmode=require
  - 런타임에 DATABASE_OWNER_URL · `PLACEHOLDER-` · 상수 밖 면제 이름 · 모르는 프로필 · 잘못된 POD_IP · FORCE_SCRIPT_NAME 꼴 → 전부 `ImproperlyConfigured` + 출력에 값 · 비밀 조각 · `input_value=` · 공개 이름 조회 없음
  - migrate 프로필이 DATABASE_OWNER_URL만으로 기동
  - FORCE_SCRIPT_NAME → STATIC_URL `/<pod>/static/`
  - 클러스터 교차 규칙(〔X8〕): dev 모양 기동(POD_NAMESPACE=jt-dev · ENV=dev · KAFKA_USERNAME=dev-<pod> · `dev_<pod_snake>_app` · verify-full · svc 이름 · https 팀 도메인 · 네트워크 0)은 통과하고, jt-prod + ENV=dev · ENV=prod + `dev-<pod>` · DB 사용자 접두 불일치 · svc 이름 없음 · POD_NAMESPACE + ENV=test는 전부 이름만 실은 `ImproperlyConfigured`
  - SECRET_KEY 49자 · `django-insecure-` 접두 · 서로 다른 글자 4 → 기동 실패(〔X21〕) · URL 사용자 정보에 `%`가 든 값 → 이름만(〔X25〕)
- **변이**: hide_input 제거 · `from None` 제거 · 게이트 2 상수 오염 · 교차 규칙 하나 삭제 → 위생 · 교차 시험이 잡는다.

### D6 파생 Django 설정(settings.py)

- **무엇**
  - **메일 · 로깅 · 디버그**
    - `DEBUG = False` · `ADMINS = []` · `MANAGERS = []`
    - `MAILERS = {}` + `SILENCED_SYSTEM_CHECKS = ["mail.W001"]`. 메일 발송은 실패로 드러나고 `EMAIL_*`는 Django가 금지한다(⑧).
    - `LOGGING_CONFIG = None`: Django 기본 dictConfig · mail_admins · console 중복이 생기지 않는다. T071 D14 (a)를 더 강하게 한 꼴이다(bn:3208 · ⑧).
  - **URL · 정적 · CSRF**
    - `ROOT_URLCONF` · `ADMIN_URLCONF = "<pod_snake>.urls_admin"`(미들웨어가 요청마다 읽음 — 시험 주입용)
    - `STATIC_URL`: ADMIN_SCRIPT_NAME이 있으면 `<접두>/static/`, 없으면 `static/`(계약:17). `STATIC_ROOT`는 없다.
    - `CSRF_TRUSTED_ORIGINS = ["https://<ADMIN_HOST>"]`(비면 [])
    - `CSRF_FAILURE_VIEW = "<pod_snake>.errors.csrf_failure"` · `SESSION_COOKIE_SECURE` · `CSRF_COOKIE_SECURE = True`
    - `SECURE_PROXY_SSL_HEADER`는 두지 않는다(계약:17이 CSRF_TRUSTED_ORIGINS 방식을 정했다).
    - `TEMPLATES`는 has_admin일 때만 둔다.
  - **일반**: `DEFAULT_AUTO_FIELD = BigAutoField` · `USE_TZ = True` · `TIME_ZONE = "UTC"` · CACHES 미설정(LocMem). Dragonfly 캐시를 더하는 pod는 `KEY_PREFIX=<pod>`(계약:75)를 쓴다.
  - **DATABASES**
    - default 하나(runtime = DATABASE_URL, migrate = DATABASE_OWNER_URL — 계약:71).
    - OPTIONS: URL의 sslmode · sslrootcert + `connect_timeout=2` + `keepalives_idle=30` · `keepalives_interval=10` · `keepalives_count=3` · `tcp_user_timeout=30000`(VD-L8)
    - `CONN_MAX_AGE=60` · `CONN_HEALTH_CHECKS=True`(relay 인계 bn:1607)
    - pool · `assume_role` · `ATOMIC_REQUESTS`는 쓰지 않는다(계약:71).
  - **Kafka**
    - `KAFKA_BOOTSTRAP_SERVERS` ← `KAFKA_BOOTSTRAP`
    - dev/prod: `KAFKA_CLIENT_CONFIG = {security.protocol SASL_SSL, sasl.mechanism SCRAM-SHA-512, sasl.username, sasl.password, ssl.ca.location "/etc/kafka/ca.crt"}`(마운트 경로 상수 `conf.KAFKA_CA_FILE` · 계약:76 — 생성물 시험이 deploy 마운트와 대조한다 · 〔X2〕)
    - ENV=test: `{"security.protocol": "PLAINTEXT"}`를 명시한다(계약:76 시험 값. 클러스터 안의 ENV=test는 D5 교차 규칙이 기동 실패로 막는다 — 〔X13〕. 그 규칙을 비켜도 9093 TLS 리스너에서 접속이 실패해 닫힌 쪽으로 끝나고 자격도 보내지 않는다).
  - **outbox**: `OUTBOX_SOURCE = "<pod_name>"` · `OUTBOX_TOPIC_PREFIX`(prod "" / 그 밖 "dev.") · `OUTBOX_MAX_ATTEMPTS = 10`
  - **경로 상수**: `AUTH_EXEMPT_PATHS = TENANT_CONTEXT_EXEMPT_PATHS = ("/healthz", "/ready", "/health")` · `AUTH_ACCESS_ONLY_PATHS = ()`(웹훅 없는 pod · bn:2277-2280)
  - `ALLOWED_HOSTS` = 모델 값 + POD_IP(D8)
  - 타임아웃은 다시 넣지 않는다(A5). Dragonfly 0.2 s는 Denylist가, delivery.timeout.ms는 프로듀서가 소유한다.
- **왜**: ExceptionReporter를 쓰지 않는 통제(bn:3024-3033) · 계약:71,76 · T069 인계(bn:1606-1607,1694).
- **기각한 대안**
  - LOGGING dict로 django 로거만 재정의(T071 (a)): 기본 dictConfig가 여전히 돈다.
  - `MAILERS = {"default": dummy}`: `check --deploy`에서 E001에 걸린다.
- **계약 · 규칙**: C12 · C14 · C15 · C17.
- **시험**
  - test_logging: `LOGGING_CONFIG is None` · `django` 로거 핸들러 0 · AdminEmailHandler 없음 · `DEBUG is False` · `ADMINS == []` · `MAILERS == {}` · settings 모듈에 `EMAIL_` 이름 0 · 500 요청 → django.request JSON 한 줄(중복 0)
  - test_outbox: KAFKA_CLIENT_CONFIG 꼴
- **변이**: LOGGING_CONFIG 기본값 복귀 → 중복 줄 시험이 잡는다.

### D7 기동 호출 자리

- **무엇**
  - **`PodConfig.ready()`**: 모든 프로세스.
    1. `configure_logging()`
    2. `logging.captureWarnings(True)`
    3. `startup.run()`: 공통으로 DEBUG False · ADMINS/MANAGERS 빈 값을 확인한다 — 검사는 `assert`가 아니라 `raise ImproperlyConfigured`(이름만)다(`-O` · PYTHONOPTIMIZE가 지우지 못하게 · 〔X18〕). runtime 프로필이면 아래를 이 순서로 돈다. 셋 다 네트워크가 0이다(⑩).
       - 경로 포함 관계(AUTH_EXEMPT ⊆ TENANT_EXEMPT · ACCESS_ONLY ⊆ TENANT_EXEMPT — bn:2242-2243)
       - `django_common.auth.check_settings()`
       - `django_common.kafka.client_config()`
       - `django_common.outbox.relay.producer_config()` · `relay_settings()`
    4. runtime 프로필이고 has_celery면 `<pod_snake>.celery.configure_broker(settings.DRAGONFLY_URL)`(D14) — import도 이 분기 안이다. migrate 프로필은 `<pod_snake>.celery`를 import하지 않는다(`<pod_snake>/__init__.py`는 비어 있고, 워커는 `celery --app <pod_snake>`가 하위 모듈 `celery`를 찾는다 · 〔X7〕).
  - **wsgi.py**: web만. `os.environ.setdefault` → `django.setup(set_prefix=False)` → `configure_otel()` → `configure_sentry()`(try/except 밖) → `application = WSGIHandler()`(bn:3537-3539 Y7 순서). relay · celery · CronJob · migrate는 logging만이다.
  - **`check_rls --require-rls-role`**: web Deployment의 initContainer `startup-check`가 `python manage.py startup_check`를 돈다.
    - 명령 `startup_check [--database default] [--wait 60]`: DB 접속 재시도(1 → 2 → 4 … ≤ 60 s · netpol 경합 bn:422) → `check_rls(using=…, require_rls_role=True)`
    - 최종 실패(재시도 소진 · 위반 · 그 밖의 예외)는 stderr 한 줄(`startup_check: FAIL <예외 클래스 이름>` — 위반이면 표 이름까지) + 종료 코드 1이고, 트레이스백 · 예외 메시지는 내지 않는다(libpq 오류 문구가 자격 조각을 실을 수 있다 · 〔X25〕). 성공이면 stdout `startup_check: OK`.
    - celery · CronJob · migrate에는 initContainer를 두지 않는다(같은 `<pod>-env` 자격을 web이 한 번 증명한다).
- **왜**
  - T066 ⑥: setup · urlconf import에서 DB · Dragonfly · Kafka · DNS를 쓰지 않는다(MIS-22).
  - check_rls는 DB가 필요하고 migrate가 끝난 뒤여야 한다(계약:55 · bn:1194,1416).
  - initContainer는 startupProbe 창(150 s) 밖에서 돌고 web · relay를 함께 막는다.
  - Kafka · outbox 정적 설정 오류를 relay의 로그+백오프(조용히 발행 0)가 아니라 기동 실패로 앞당긴다(계약:74 원칙).
  - wsgi 순서상 configure_otel의 WARNING도 configure_logging 뒤라 JSON으로 나간다(〔조사 library Q9〕 해소).
- **기각한 대안**
  - check_settings를 시스템 check로: migrate · makemigrations까지 auth 설정을 요구하게 된다.
  - check_rls를 web 명령 앞단(`… && exec gunicorn`): startupProbe 창이 줄고 relay가 먼저 뜬다.
  - check_rls 생략: 인계를 위반한다.
- **계약 · 규칙**: C13(check_settings 호출 자리 = ready) · C8(initContainer).
- **시험**
  - test_tenant_rls: `call_command("startup_check")` → `startup_check: OK`(app role). `database="owner"` → 실패(require_rls_role 위반). 닫힌 포트 DB + `--wait 1` 하위 프로세스 → 종료 코드 1 · stderr 한 줄에 예외 클래스 이름만(트레이스백 · URL 조각 0 · 〔X25〕).
  - test_logging: wsgi 진입점을 하위 프로세스로 돌려 application 생성 · `MIDDLEWARE[0]`이 OTel · 공개 이름 조회 0을 본다.
  - 기동 위생 시험의 Kafka 금지 키(`delivery.timeout.ms`)는 `ImproperlyConfigured`다.
- **변이**: ready에서 check_settings 제거 → ACCESS_TEAM_DOMAIN 공백 기동이 통과해 위생 시험이 잡는다.

### D8 kubelet 프로브 Host

- **무엇**: web 컨테이너 env `POD_IP` ← `fieldRef status.podIP`. settings가 POD_IP(IP 리터럴 검증, IPv6면 괄호)를 ALLOWED_HOSTS 끝에 더한다. 프로브에는 httpHeaders를 두지 않는다.
- **왜**
  - 계약:65는 필수이고 두 방식 중 고르게 했다. POD_IP 방식은 ns별 svc 이름을 프로브에 박지 않아 base를 그대로 복사할 수 있다(〔조사 shape F24〕).
  - 위험: 클러스터 안 호출자가 pod IP를 Host로 쓸 수 있다. 그래도 비면제 경로는 Access + Bearer가 막는다. netpol이 traefik · identity · monitoring만 연다.
- **기각한 대안**
  - `httpHeaders Host: <pod>.<ns>.svc`: overlay마다 프로브 3개를 패치해야 한다.
  - `Host: localhost` + ALLOWED_HOSTS에 localhost: 계약:80의 ALLOWED_HOSTS 정의에서 벗어난다.
- **계약 · 규칙**: C9 · 규칙:50 보정.
- **시험**
  - 하네스 gen-19(POD_IP fieldRef)
  - 생성물: Host `10.42.0.7:8000` `/healthz`에 OTel 설치 상태로 POD_IP가 있으면 200, 없으면 400 invalid_host
  - 이미지 스모크 gen-34(POD_IP=127.0.0.1로 기동)
- **변이**: fieldPath `metadata.name` · env 삭제 → gen-19가 잡는다.

### D9 URL · Ninja API · OpenAPI · 오류 처리기

- **무엇**
  - **api.py**: `api = NinjaAPI(title=<description 또는 pod_name>, version="1", openapi_url="/api/openapi.json", docs_url=None)` · `api.add_router("", health_router)` · `install_error_handlers(api)` 함수를 노출한다(시험 probe API가 재사용). 처리기:
    - Ninja `ValidationError` → 400 `validation_error`
    - `HttpError`: 400 → validation_error(잘못된 JSON 본문 포함 · ⑨), 403 → forbidden, 404 → not_found, 그 밖 status → `problem_response(<slug>, status)` 대응표 밖이면 다시 올림
    - `Http404` → not_found
    - **catch-all Exception 처리기는 두지 않는다.** DEBUG가 꺼져 있으면 Ninja가 다시 올려 handler500으로 간다(계약:71 · ⑨).
  - **urls.py**: `path("", api.urls)` + `handler400/403/404/500 = "<pod_snake>.errors.*"`.
  - **urls_admin.py**(has_admin): `path("admin/", admin.site.urls)` + 같은 처리기 4개(계약:81).
  - **errors.py**
    - `bad_request`(DisallowedHost → invalid_host, 그 밖 → validation_error)
    - `permission_denied`(forbidden) · `page_not_found`(not_found)
    - `server_error`(internal_error · detail 없음)
    - `csrf_failure(request, reason="")`(forbidden)
    - 전부 `django_common.problem.problem_response`
  - **OpenAPI 스냅샷**: `tests/snapshots/openapi.json`(정적 · .jinja 아님) = `api.get_openapi_schema()`에서 `info.title`을 뺀 값. title은 따로 비교한다. 갱신 절차는 README에 적는다(규칙:84).
- **왜**: 계약:31,81 · 규칙:62-63 · T066 api-50(/api/openapi.json에 루트 경로 · /docs 없음 — test_api.py:2222-2268 · bn:3552).
- **기각한 대안**
  - NinjaAPI 두 개: 헬스 면제는 경로 정확 일치라 루트 하나로 충분하다(〔조사 library F22〕).
  - 스냅샷을 .jinja로 렌더: Ninja 출력 세부를 템플릿이 흉내 내야 해서 깨지기 쉽다.
- **계약 · 규칙**: C18.
- **시험**: test_auth_middleware · test_openapi_snapshot(D17).
- **변이**: 처리기 미지정 → HTML 500. Ninja 422 → 400 시험이 잡는다.

### D10 미들웨어 순서 · admin 장착 · 정적 자산 · 사람 admin 경로

- **무엇**
  - **MIDDLEWARE(has_admin)**: RequestIdMiddleware → `<pod_snake>.middleware.HttpMetricsMiddleware` → SecurityMiddleware → CommonMiddleware → `<pod_snake>.middleware.AdminHostMiddleware` → SessionMiddleware → CsrfViewMiddleware → AuthenticationMiddleware → MessageMiddleware → XFrameOptionsMiddleware → `django_common.auth.JwtAuthMiddleware` → `django_common.tenancy.TenantContextMiddleware`(마지막)
    - 런타임에 configure_otel이 OTel을 index 0에 넣는다.
    - has_admin=false면 AdminHost · Session · Auth · Message를 뺀다.
  - **AdminHostMiddleware**: ADMIN_HOST가 비어 있거나 `request.get_host() != ADMIN_HOST`면 손대지 않는다. ADMIN_HOST 요청이면:
    - GET/HEAD `/static/<p>` → `staticfiles.views.serve(request, p, insecure=True)`로 바로 응답한다. JwtAuth 앞이므로 자격 없이 200이다. finders가 앱 정적 디렉터리 밖을 거부한다.
    - 그 밖 → `request.urlconf = settings.ADMIN_URLCONF`. ADMIN_SCRIPT_NAME이 있으면 `set_script_prefix` · `request.path` · `META["SCRIPT_NAME"]`에 접두를 넣고 finally에서 되돌린다(계약:17 · 규칙:49).
  - 상류 X-Request-ID 신뢰 설정은 두지 않는다(MIS-21 · 계약:77).
  - WhiteNoise와 collectstatic은 쓰지 않는다.
  - **사람 admin 경로**(GitHub IdP Access · Bearer 없음)는 **T084로 미룬다.** 지금 `/admin/*`는 M2M 자격일 때만 열리고 사람은 401/403이다(fail-closed). 〔R13〕
- **왜**
  - 정적 서빙은 TenantContext 앞이어야 하고(bn:1200), JwtAuth 면제는 정확 일치라 접두를 면제할 수 없다(〔조사 library F41〕).
  - WhiteNoise는 Django 6.1 분류자가 없는 새 의존이다(〔조사 tooling V10〕).
  - `insecure=True` 서빙은 admin 페이지 소량이고 Access 뒤에 있다.
  - 미결 처리(계약:74 · bn:2152): (a)/(b)는 T084 실측이 없어 설계 근거가 없다.
- **기각한 대안**
  - admin 호스트에 별도 미들웨어 스택(O1 (b)): 지금은 과설계다.
  - 사람 모드를 지금 구현(O1 (a)): VD-T066-5 전이다.
- **계약 · 규칙**: C13 · C26(has_admin 행: 서빙 방식).
- **시험**(has_admin)
  - admin 호스트 + M2M 자격 `/admin/` → 302, Location에 `/<pod>/admin/login/` 접두. 같은 스레드의 다음 m2m 요청 reverse에는 접두가 없다.
  - `/static/admin/css/base.css` → 200 · text/css(자격 없음). `/static/../conf.py` → 400 `validation_error` problem+json(본문에 파일 내용 없음 — `safe_join`의 SuspiciousFileOperation · ㉜ · 〔X9〕).
  - m2m 호스트 `/static/…` → 403 access_required. m2m 호스트 `/admin/` + 자격 → 404 not_found.
  - admin 로그인 POST, 토큰 없음 → 403 forbidden problem.
  - ADMIN_HOST 빈 값이면 admin urlconf가 없다.
- **변이**: 정적 서빙을 JwtAuth 뒤로 → 정적 200 시험이 잡는다. finally 복원 삭제 → 다음 요청 접두 시험이 잡는다.

### D11 WSGI 서버 · web 9100 지표

- **무엇**
  - **gunicorn**: gthread · `workers=1` · `threads=4` · `bind 0.0.0.0:8000` · `timeout 30` · `graceful_timeout 30`(pod grace 90 안) · `worker_tmp_dir /tmp` · accesslog 없음(기본 None) · `--preload` 없음.
  - 명령: `gunicorn --config python:<pod_snake>.gunicorn_conf --no-control-socket <pod_snake>.wsgi:application`(⑱).
  - `gunicorn_conf.post_worker_init`에서 `prometheus_client.start_http_server(9100)`.
  - `metrics.py`: `http_requests_total{route,status}` Counter.
    - route = `request.resolver_match.route`(해석 안 됨 = "")
    - HttpMetricsMiddleware만 import하므로 relay · celery 레지스트리에는 생기지 않는다.
  - 워커가 하나라 prometheus multiprocess가 필요 없다. `PROMETHEUS_MULTIPROC_DIR`는 어디에도 두지 않는다.
  - gunicorn master/worker 생애 로그(Booting · exiting)는 원문 stderr로 남는다(문서화한 예외 · T098).
- **왜**
  - plan 단계 research의 기준 템플릿이 gunicorn gthread다(㉘ — 예시의 workers 2를 1로 바꾼 이유는 아래 multiprocess 위험). 계약:77 · 규칙:88의 스택 열거와도 맞다(〔X12〕).
  - 인증 · 테넌트 미들웨어가 sync 전용이라 WSGI를 쓴다(〔조사 library F21〕).
  - 다중 워커 multiprocess의 env 누출이 relay를 죽이는 위험(계약:78)을 원천 제거한다.
  - threads 4 ≤ 헬스 칸 8(bn:3546-3550).
- **기각한 대안**
  - workers 2+ multiprocess: env 위험 · 다중 프로세스 수집기 제약
  - uvicorn/ASGI: sync 미들웨어와 맞지 않는다.
  - waitress: 새 의존
  - gunicorn 로그를 JSON으로 재배선(logconfig_dict): master는 Django 밖이고 disable_existing_loggers 위험이 있다.
- **계약 · 규칙**: C16(9100 소유 · 단일 워커) · C15.
- **시험**
  - 생성물: `/healthz` 호출 뒤 `REGISTRY.get_sample_value("http_requests_total", {route, status})` 증가
  - 이미지 스모크 gen-34: `:9100/metrics`에 http_requests_total · gunicorn 기동이 `--no-control-socket` 판 실측
- **변이**: metrics를 relay 경로에서 import → relay 레지스트리 시험(생성물 relay 명령 실행 뒤 http_requests_total 부재)이 잡는다.

### D12 DB 정책 · app role GRANT · 예시 모델

- **무엇**
  - 연결 정책은 D6.
  - **`<pod_snake>/core/migrations/0001_app_role_grants.py`**: owner로 도는 migrate가 실행하는 RunSQL DO 블록.
    - `app := current_database() || '_app'`(role이 없으면 `RAISE EXCEPTION`)
    - `GRANT USAGE ON SCHEMA public`
    - `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public`
    - `GRANT USAGE, SELECT ON ALL SEQUENCES`
    - `ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT … ON TABLES` / `ON SEQUENCES`(owner가 나중에 만드는 표 · 시퀀스 모두)
    - `REVOKE INSERT, UPDATE, DELETE ON django_migrations FROM app`(SELECT는 남긴다)
    - reverse SQL을 둔다. 마이그레이션 순서와 무관하다(ALL TABLES + DEFAULT PRIVILEGES).
  - **예시 모델**
    - `core/models.py`에는 실행되지 않는 주석 예만 둔다: A 등급 클래스 이름 ≤ 16 · `indexes=[*TenantModel.Meta.indexes]` · through M2M · rls_policies 전용 마이그레이션 · B 등급은 허용 목록만.
    - 실제 A 등급 표는 시험 전용 앱 `tests/rlsapp`(모델 `RlsWidget` · 0001 · 0002 `rls_policies`)뿐이다.
    - B 등급 예시는 dc의 outbox가 대신한다.
- **왜**
  - 문서 공백 ㉕를 pod 마이그레이션 이력으로 닫으면 시험 · 로컬 개발 · 운영이 같은 경로를 탄다.
  - app이 관계를 소유하지 않는다(bn:1317).
  - 예시 표를 모든 pod DB에 만들지 않는다(UND-17).
- **기각한 대안**
  - migrate Job 첫 단계에 GRANT를 넣기(gitops README 문장): 매 배포 재적용 장점은 있다. 그러나 생성물 시험 · compose가 그 경로를 타지 않는다.
  - superuser 부트스트랩으로 GRANT: 운영에 superuser가 없다.
- **계약 · 규칙**: C20(마이그레이션 행: GRANT 주체) · C25(core 행) · 규칙 §Migrations 한 줄 · gitops README(T075).
- **시험**(test_tenant_rls)
  - conftest는 기본 권한을 **주지 않는다**. 대신 app role의 outbox · RlsWidget S/I/U/D(has_table_privilege), django_migrations INSERT false · SELECT true, relay 왕복(app role)으로 증명한다.
  - RLS · TenantContext 경로 시험은 `django_db(transaction=True, databases=["default", "owner"])`다(TestCase는 GUC가 바깥 시험 트랜잭션 끝까지 남는다 — T068 인계 bn:1152-1201 · 〔X15〕).
  - A 등급: 다른 tenant 0행 · 컨텍스트 없음 0행 · owner 전체.
  - B 등급: app이 컨텍스트 없이 전체.
  - `check_rls(using="owner")` OK.
  - 허용 목록 밖 RLS 없는 표를 owner가 만들면 check_rls 실패(정리 포함).
- **변이**: 0001에서 DEFAULT PRIVILEGES 삭제 → relay 시험의 outbox DELETE 권한 실패로 잡힌다.

### D13 events/ · owns/consumes 산출물 · 관리 명령

- **무엇**
  - **`events/__init__.py`**: `OWNED_EVENTS: tuple[str, ...]`(owns_events) · `topic(event)` = `f"{settings.OUTBOX_SOURCE}.{event}"`(목록 밖이면 ValueError) · `publish_owned(event, subject, data, *, tenant_id=None)` → `django_common.outbox.publish`(함수 안에서 import).
  - 스키마 「참조」는 docstring · README의 경로 `packages/events/schemas/<pod>.<entity>.<event>.json`이다. 파일을 읽지 않는다(이미지에 없음 · events.md:102).
  - **`events/README.md`**: 소유 토픽(prod/dev · DLQ) · 스키마 경로 · gitops `platform/kafka-topics`에 낼 KafkaTopic YAML 예(파티션 3 · retention 7d · delete · replicas 1 — data-model §6) · KafkaUser ACL 메모. KafkaTopic은 deploy/base에 두지 않는다(ns data · AppProject 경계 — 〔조사 spec UND-18〕).
  - **`consumers.py`**(consumes_events가 비지 않을 때): `CONSUMED_TOPICS` · `group_id(purpose)`(prod `<pod>-<purpose>` · dev `dev-<pod>-<purpose>` — events.md:140) · 처리 규칙 docstring. 프로세스와 워크로드는 SP-2다.
  - **관리 명령**: `outbox_relay.py` = `from django_common.management.commands.outbox_relay import Command`(재노출 · 계약:34) · `startup_check.py`(D7). outbox_purge · outbox_requeue · check_rls는 dc에서 그대로 발견된다.
- **왜**: 계약:14-15,33-34 · 하네스 가정 ⑦.
- **기각한 대안**: events/에 스키마 사본을 두기. 원본과 갈라질 수 있다.
- **계약 · 규칙**: C6.
- **시험**: 변형 생성(gen-29)에서 `OWNED_EVENTS`에 주입 값 · consumers.py 존재. 생성물 test_outbox가 `publish_owned` 목록 밖 → ValueError.
- **변이**: 없음.

### D14 Celery(has_celery)

- **무엇**
  - **celery.py**: `app = Celery("<pod_snake>")` · `CELERY_CONFIG` dict를 `app.conf.update(...)`로 넣는다.
    - `broker_transport_options = {"global_keyprefix": "<pod>:", "socket_timeout": 5, "socket_connect_timeout": 2}`(BRPOP 1 s보다 큼 · ⑰)
    - `broker_connection_retry_on_startup=True`
    - `worker_enable_remote_control=False`
    - `worker_hijack_root_logger=False`
    - `task_ignore_result=True` · result backend 없음
    - `task_always_eager=False`
    - `timezone="UTC"`
    - `beat_schedule = {"purge-dead-outbox": {"task": "<pod_snake>.tasks.purge_dead_outbox", "schedule": crontab(minute=17, hour=3)}}`
    - `@setup_logging.connect` 빈 수신기
    - `app.autodiscover_tasks(["<pod_snake>"])`
  - **`configure_broker(url)`**: `app.conf.broker_url = url`. ready의 runtime 분기가 부른다(〔X7〕) → 브로커 = `settings.DRAGONFLY_URL`. 새 자격 URL 설정 이름이 없으므로 마스킹 목록 개정이 없다(bn:3721).
  - 시험에서는 기동 순간의 닫힌 포트 자리값이 남는다 → T066 ⑥ · api-19가 결정적이다.
  - **tasks.py**: `@app.task(name="<pod_snake>.tasks.purge_dead_outbox") def purge_dead_outbox() -> int: return purge_dead()`.
  - **워커 명령**: `celery --app <pod_snake> worker --pool solo --beat --schedule /tmp/celerybeat-schedule --without-gossip --without-mingle --without-heartbeat --loglevel INFO`. 배너 같은 원문 stdout은 예외로 둔다(VD로 `--quiet` 확인).
  - CeleryIntegration을 두지 않는다. configure_sentry에 integrations 인자가 없고 자동 통합은 꺼져 있다 → T100이 정한다.
  - Dragonfly ACL을 넓히지 않는다(채널 0 유지).
  - 롤링 중 beat가 둘이 될 수 있다 → 작업은 멱등이다(purge).
- **왜**
  - 계약:75,84 · 규칙:80
  - 채널 권한 없음 + pub/sub 기능을 끈다(⑰ · 〔조사 tooling D1〕). `&<pod>:*`를 더해도 PSUBSCRIBE는 문자 그대로 대조라 무력하다.
  - 결과 백엔드 없음(D5)
  - eager False(T066 ⑦)
- **기각한 대안**
  - `CELERY_BROKER_URL` Django 설정: 마스킹 목록과 dc를 개정해야 한다.
  - celery.py import 시점에 settings를 읽기: 시험에서 픽스처가 바꾼 값을 잡아 비결정적이 된다.
  - worker/beat 두 컨테이너: gen-13 꼴과 프로세스 관리가 복잡해진다.
  - celery 5.7.0: 숙성 창 · 문면 「5.6」과 충돌한다(〔조사 tooling V4〕).
- **계약 · 규칙**: C21 · 규칙 §Dragonfly.
- **시험**(test_outbox, has_celery)
  - 작업 등록 · `apply()`가 purge 실행
  - beat 일 1회 crontab
  - conf 단언: remote control off · keyprefix · result backend 없음 · eager False · `broker_url == 기동 시 DRAGONFLY_URL`
  - **실제 워커(필수 · 〔X23〕)**: 하위 프로세스 `celery --app <pod_snake> worker --pool solo --beat --schedule <tmp>/celerybeat-schedule --without-gossip --without-mingle --without-heartbeat --loglevel INFO`를 `DJANGO_SETTINGS_MODULE=<pod_snake>.settings`와 명시 env(시험 DB app role URL · 시험 Dragonfly `<pod>` 사용자 URL — 운영 줄과 같은 `resetchannels %R~revoked:* ~<pod>:* +@all` · ENV=test)로 띄운다 → `send_task("<pod_snake>.tasks.purge_dead_outbox")` → `dead_at`이 31일 전인 행의 삭제를 관찰 → 로그에 `NOPERM` 0 → SIGTERM(상한 뒤 kill · 정리 확인). 불안정하면 대기 · 타이밍을 고치고, 측정 기록으로 내리지 않는다(VD-T072-4 · VD-T072-13).
- **변이**: remote control 켜기 → 실제 워커 시험에서 NOPERM으로 잡힌다.

### D15 has_celery=false CronJob

- **무엇**: `cronjob-outbox-purge.yaml`
  - `<pod>-outbox-purge` · `schedule: "17 3 * * *"` · `timeZone: Etc/UTC` · `concurrencyPolicy: Forbid` · `startingDeadlineSeconds: 3600` · 이력 1/3
  - jobTemplate: `backoffLimit 2` · `activeDeadlineSeconds 900` · restartPolicy Never
  - pod는 web과 같은 securityContext(D20) + automount false
  - 컨테이너 `outbox-purge`: `python manage.py outbox_purge` · envFrom ConfigMap `<pod>-config` + `<pod>-env` · env `POD_NAMESPACE`(fieldRef · 〔X8〕) · requests 256Mi / limits 512Mi · `/tmp` · pg-ca
- **왜**: 계약:84,108 · bn:1840.
- **기각한 대안**: celery 없이 web 안 스레드 타이머. 워크로드 계약 밖이다.
- **계약 · 규칙**: C21.
- **시험**: 하네스 변형 렌더 gen-30 · 31 + `check_cronjob`(D21). 생성물 test_outbox `call_command("outbox_purge")` → `outbox_purge: N`(기본 pod에서도 돈다).
- **변이**: D21 cron 표.

### D16 생성물 시험 인프라(conftest · 래퍼 · ini)

- **무엇**: conftest는 dc 모양을 이식하되 pod 이름으로 매개화한다.
  - win32 `TESTCONTAINERS_HOST_OVERRIDE=127.0.0.1`(import 전)
  - `pg`: `tests/docker/pg-tls`(dc와 같은 `postgres:18.6-alpine@sha256:10a5c69a…` · hostssl만) 빌드 · 태그 `jt-<pod>-pg-tls:18.6`
    - DB `<pod_snake>`, role `<pod_snake>_owner`(LOGIN BYPASSRLS) · `<pod_snake>_app`(LOGIN NOBYPASSRLS)
    - DB 소유자 = owner · CONNECT 둘 · 멤버십 없음 · 기본 권한 없음(D12가 증명)
    - 비밀번호는 `secrets.token_urlsafe` · repr에서 제외
  - `django_db_modify_db_settings` · `django_db_setup`(owner migrate · test_ DB 없음)
  - 래퍼 DATABASES: default(app · sslmode require · connect_timeout 5 · TEST.MIRROR owner · pool 없음 · CONN_MAX_AGE 0) + owner(`-c lock_timeout=30s`). DB 마크는 `databases=["default","owner"]`(T066 ①).
  - `kafka`(cp-kafka:8.0.0 태그 핀 · PLAINTEXT) · `kafka_settings`
  - `dragonfly`(dc digest 핀 · 계약 aclfile 대신 기동 뒤 `ACL SETUSER`)
    - 사용자: `admin`(전체) · `<pod>`(운영 줄과 같은 `resetchannels %R~revoked:* ~<pod>:* +@all`) · default off
    - 속성: `.host` · `.port` · `.admin_url`(Secret) · `.pod_url`(Secret)
    - 근거: MIS-14 · T066 ②
  - `jwks_server`(`.jwks_url` · `.base_url` · `.authentik_key` · `.access_key` · `.hits`)
  - `auth_settings` · `log_sink`/`log_lines` · `otel`(InMemorySpanExporter)
  - `_outbox_fakes.FakeProducer`(키워드 produce · flush · purge · `poll(0)` — bn:1994)
  - 도우미 `_jwt.py`: `JWKS_PATH = "/application/o/<pod>/jwks/"` · `BEARER_AUDIENCE = "<pod>"`. identity-admin이면 dc 값과 같다. API 이름은 T066 ③ 그대로다.
  - `_problem.assert_problem` · `_secret.Secret` · `_kafka`
  - 래퍼(D5)가 시험 앱 `tests.rlsapp` · `django_migration_linter`과 `MIGRATION_LINTER_OPTIONS`(no_cache · 대상 = pod 앱 — 옵션 이름은 VD-T072-3)를 더한다.
  - ini는 D4.
- **왜**
  - T066 가정 ①–⑨를 그대로 만족한다(test_api.py:40-71).
  - dc 도우미는 import할 수 없다(⑪). 미니 저장소에 pg-tls가 없다(〔조사 harness F32〕).
  - role 이름을 운영 파생 규칙(`<db>_app`)과 맞춰 D12 · migrate Job 스크립트를 실제 이름으로 시험한다.
- **기각한 대안**
  - aclfile을 컨테이너에 마운트: Windows 경로와 권한이 번거롭다. 규칙 문자열이 같으면 동치다.
  - dc 시험을 패키지로 배포: 범위 밖이다.
- **계약 · 규칙**: C7.
- **시험**: gen-5(기존 판정) · gen-26.
- **변이**: 없음(인프라).

### D17 생성물 시험 7파일 내용(계약 §기본 테스트 1–5 + T072 추가)

- **test_health.py**(§4 · 계약:104)
  - `/healthz` 200(DB 마크 없이)
  - `/ready` 200, DB 다운이면 503 not_ready(T063 `_db_down` 꼴), Dragonfly 다운이면 200
  - `/health` 항상 200 · checks `{db, dragonfly, kafka_producer}`
  - POD_IP Host(D8)
- **test_tenant_rls.py**(§1): D12 · D7 항목.
- **test_outbox.py**(§2 · 계약:102)
  - atomic 밖 · 컨텍스트와 인자가 둘 다 없음 → OutboxUsageError · tenant_id 명시 경로
  - 커밋 → `relay_once`(app) → 실제 Kafka 수신
  - **「스키마 통과」 대신 봉투 꼴**: `ENVELOPE_PATTERNS`(id · source · type · subject · tenantid) + 필수 키 9 정확 일치 + const 2 + time `YYYY-MM-DDTHH:MM:SS.mmmZ` + data 왕복. packages/events는 미니 저장소 · 이미지에 없다(가정 ⑦ · events.md:102). MIS-09.
  - 테넌트 A · B의 tenantid와 파티션 키 일치
  - 실패 주입 → attempts 1
  - 10회 → `dev.<pod>.dlq` + dead_at
  - dead 행은 다시 집히지 않음 · 30 d purge
  - `call_command("outbox_purge")` → `outbox_purge: N`(T072 넷 ④)
  - `call_command("outbox_relay", iterations=1, poll_interval=0, metrics_port=0)` + 패치한 build_producer(poll 있음)
  - Celery(D14 — 실제 워커 필수 · 〔X23〕) · publish_owned
  - Kafka CA 경로 대조(〔X2〕): D5의 dev 모양 기동 하위 프로세스가 `KAFKA_CLIENT_CONFIG["ssl.ca.location"]` · `OUTBOX_TOPIC_PREFIX`를 출력하고, 시험이 `deploy/base/deployment.yaml`(pyyaml)의 web · relay kafka-ca mountPath + `/ca.crt`와 같음 · prefix `"dev."`를 단언한다(deploy 파일이 생기는 조각 ④에서 켠다).
- **test_auth_middleware.py**(§3 · 계약:103)
  - 보호 경로 = `/api/openapi.json`
  - 행렬: 유효 200 · 만료 401 · aud 불일치 401 · Access 없음 403 · common_name 불일치 403 · admin AUD 허용 · AUTH_ACTOR_SUB 설정/미설정 · revoked sub/sid 401 · Dragonfly 다운 → 비헬스 503/헬스 200 · JWKS/certs fetch 실패 503 auth_keys_unavailable
  - Django 오류 urlconf마다: 처리기 객체가 urls · urls_admin에 선언됐는지 확인 + `tests/probe_urls.py`(urls.urlpatterns + 일부러 PermissionDenied · BadRequest · Exception을 내는 뷰 · 처리기를 pod urlconf에서 복사)와 `ADMIN_URLCONF` 덮기로 400 invalid_host · 400 validation_error(RequestDataTooBig 포함) · 403 forbidden · CSRF 403 · 404 · 500(detail 없음 · `raise_request_exception=False`)
  - Ninja probe(`install_error_handlers` 재사용): 쿼리 누락 · 잘못된 JSON → 400
  - **Ninja판 tc-7**: 쓰기 뒤 예외 → 500 + 롤백(bn:1197 · T068 인계)
  - 기동 위생 · 클러스터 교차 규칙 · SECRET_KEY 강도 · URL 사용자 정보(D5 · 〔X8 · X21 · X25〕) · admin(D10)
- **test_logging.py**(§5): request_finished의 request_id · tenant_id · trace_id(otel) · route · code / authorization · cookie · x-authentik-signature 없음 / D6 · D7 단언.
- **test_migrations.py**(§5 · 계약:105)
  - `call_command("makemigrations", "--check", "--dry-run")`(같은 줄 — H/tests/_tree.py:310-325)
  - `call_command("lintmigrations")`
  - **migrate 프로필 하위 프로세스**(has_celery 기본 생성물): env에서 pod 설정 키를 지우고 `JT_SETTINGS_PROFILE=migrate` · `ENV=test` · `DATABASE_OWNER_URL` · `DJANGO_SETTINGS_MODULE=<pod_snake>.settings`(pytest-django가 둔 tests.settings를 덮는다) → `manage.py migrate --noinput` 종료 0. 같은 프로필의 setup 탐침이 `DRAGONFLY_URL` 없이 기동하고 `'celery' not in sys.modules`를 단언한다(〔X7〕).
  - **migrate Job 스크립트 실물 시험**: `deploy/base/migrate-job.yaml`을 pyyaml로 읽어 `python -c` 스크립트를 하위 프로세스로 실행 → 시험 PG에서 PUBLIC CONNECT 회수 · `<db>_app` · `<db>_owner` CONNECT 확인(임시 role 비교) + 하위 migrate의 종료 코드가 스크립트 종료 코드로 전달된다(없는 DB 이름 주입 → 0 아님 · 최종 실패 stderr에 예외 클래스 이름만 — 〔X4 · X25〕)
- **test_openapi_snapshot.py**: D9 비교 · title · 경로에 /healthz · /ready · /health · 자격을 붙인 `/api/openapi.json` = 스키마 · `/docs` 404.
- Sentry 스모크는 기본 시험에 두지 않는다 — 생성물은 `SENTRY_DSN` 빈 값(끔) 경로만 돈다. init · 전송은 dc 계약 시험(T071)과 T100이 맡는다(〔X14〕).
- **왜**: 하네스는 7파일 수집 · 통과 · skip 0만 보고 내용은 계약이 정한다(〔조사 harness F10,F32〕).
- **기각한 대안**: 스키마 원천으로 packages/events 사본 + jsonschema. 가정 ⑦과 이미지 경계를 위반한다.
- **계약 · 규칙**: C22 · C23.
- **시험**: gen-5(전부 통과 · skip 0) · 새 gen-27(`check_outbox_test` — `call_command\(\s*["']outbox_purge["']` 표식).
- **변이**: 봉투 꼴 단언 제거 → 자기 검토 몫(하네스는 표식만 본다 — §9 위험).

### D18 Dockerfile · `.dockerignore`

- **무엇**: `Dockerfile.jinja`. `# syntax` 줄 없이 FROM을 직접 적는다(Renovate digest 갱신).

```
FROM ghcr.io/astral-sh/uv:0.12.8-python3.13-trixie-slim@sha256:<VD-T072-7 — Hub 인덱스 6fe190f0…와 같은지> AS builder
ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy UV_PYTHON_DOWNLOADS=never   (UD-1 A면 + UV_SYSTEM_CERTS=1)
WORKDIR /src/apps/<pod>
COPY packages/django-common/pyproject.toml /src/packages/django-common/pyproject.toml
COPY packages/django-common/src /src/packages/django-common/src
COPY apps/<pod>/pyproject.toml apps/<pod>/uv.lock ./
RUN uv sync --locked --no-install-project --no-dev --no-editable
COPY apps/<pod>/ ./
RUN uv sync --locked --no-dev --no-editable
FROM python:3.13-slim-trixie@sha256:09a17cad02668ae61ece136b4fd36ac3849e14f670ebedb637ea3e15580525bc
ARG APP_VERSION=0.0.0+local
ARG APP_GIT_SHA=0000000
LABEL org.opencontainers.image.revision=$APP_GIT_SHA
RUN groupadd --system --gid 10001 app && useradd --system --uid 10001 --gid 10001 --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin app
WORKDIR /src/apps/<pod>
COPY --from=builder /src/apps/<pod> /src/apps/<pod>
ENV PATH=/src/apps/<pod>/.venv/bin:$PATH PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 DJANGO_SETTINGS_MODULE=<pod_snake>.settings APP_VERSION=$APP_VERSION APP_GIT_SHA=$APP_GIT_SHA
USER 10001:10001
EXPOSE 8000 9100 9464
CMD ["gunicorn", "--config", "python:<pod_snake>.gunicorn_conf", "--no-control-socket", "<pod_snake>.wsgi:application"]
```

  - `--no-editable`이라 dc는 site-packages에 정규 설치되고 런타임에 `/src/packages`가 필요 없다(〔조사 tooling U3〕).
  - collectstatic은 없다(D10).
  - `Dockerfile.dockerignore`(허용 목록): `*` → `!apps/<pod>` → `!packages/django-common/pyproject.toml` → `!packages/django-common/src` → 다시 빼기 `**/.venv` · `**/__pycache__` · `**/*.py[co]` · `**/.pytest_cache` · `apps/<pod>/tests` · `apps/<pod>/deploy` · `apps/<pod>/compose*` · `apps/<pod>/env.example` · `apps/<pod>/README.md` · `**/.env` · `**/.env.*` · `**/*.pem` · `**/*.key` · `**/.git*` · `apps/<pod>/.copier-answers.yml`(이미지는 GHCR Public이다 — 로컬 `.env` · 키가 실리지 않게 · 〔X27〕).
  - **Python 패치 판 차이**(빌더 3.13.15 / 런타임 3.13.18)는 받아들이고 기록한다. minor가 같아 `/usr/local/bin/python3.13` 경로 · cp313 ABI · pyc 매직이 같다. ≥ 3.13.2 요구(bn:2683-2686)를 만족한다. 〔R16〕
- **왜**: 계약:24,82 · 루트 컨텍스트 배치 · 숫자 UID(⑭) · Windows .venv(⑮) · build-arg(bn:3380).
- **기각한 대안**
  - 이름 USER + runAsUser만: 이미지를 단독 실행할 때 비-root 판정이 약하다.
  - editable + 런타임에 dc 복사: 경로 결합이 늘어난다.
  - 빌더 = 런타임 digest + `COPY --from uv`: 문면 편차다(UD-1 C로 남김).
  - 바이트컴파일 생략: 읽기 전용 루트에서 기동마다 컴파일한다.
- **계약 · 규칙**: C3 · C19.
- **시험**
  - gen-6(기존)
  - 새 gen-33:
    - `docker image inspect` → `Config.User == "10001:10001"` · Env 이름에 금지 env 0(D21 env_hygiene과 같은 목록 · 〔X18〕) · 라벨 revision · FROM 전부 `@sha256:`(Dockerfile 정적 검사 도우미)
    - `docker run --rm --network none --read-only --tmpfs /tmp --entrypoint python …` 탐침 → uid/gid 10001 · `~/.netrc` · `~/_netrc` 없음 · Python ≥ 3.13.2 · `django_common` 파일이 venv site-packages(비-editable) · django-ninja 1.7.0 · `/src/packages` 없음 · `/src/apps/<pod>` 아래 `.env*` · `*.pem` · `*.key` 0(〔X27〕)
  - 새 gen-34: 웹 기동 스모크(D11)
- **변이**: dockerignore 삭제 → Windows .venv 복사로 gen-33/34 실패. `USER app` → gen-33.

### D19 compose.dev.yml · env.example · README

- **무엇**
  - **compose.dev.yml**: 포트는 127.0.0.1에만 bind한다.
    - postgres: `build: tests/docker/pg-tls`(TLS 전용 · `sslmode=require`)
    - dragonfly: `ghcr.io/dragonflydb/dragonfly:v1.40.1@sha256:ebf3c6c2…` + `--aclfile` `compose/dragonfly-dev.acl`(admin · `<pod>` 운영 규칙 + `nopass` — 비밀 0)
    - kafka: `apache/kafka:4.3.1@sha256:77e3df90…` KRaft PLAINTEXT(〔조사 tooling I1 · I2〕)
    - 로컬 실행은 ENV=test(PLAINTEXT · require)다. 시험은 compose를 쓰지 않는다(MIS-15).
  - **env.example**: 계약 20키 + `SECRET_KEY` · `APP_VERSION` · `APP_GIT_SHA`(이미지 밖 로컬 실행에서도 runtime 필수 — 〔X16〕) + (has_admin) `FORCE_SCRIPT_NAME`. 줄마다 `KEY=`이고 주석은 허용한다. `DATABASE_OWNER_URL` · `EMAIL_*` · `POD_*`는 없다(계약:26-27).
  - **README.md**: 실행 · 시험(Docker 필요) · 설정 표 · 로컬 compose의 DB · role 부트스트랩 절차(psql — 비밀번호는 셸 env · 저장소에 비밀 0 · compose postgres에는 role을 만드는 장치가 없다 · 〔X16〕) · deploy/base 인터페이스(ConfigMap 키와 base dev 값 · ES data[] 순번 표와 인덱스 패치 앞 `op: test` 규칙(〔X30〕) · hook/wave · 자원 표) · OpenAPI 갱신 · 재생성(update 미지원) · `--no-cleanup`.
- **왜**: 계약:25-26 · 저장소에 비밀 0.
- **기각한 대안**
  - `postgres:18` 태그만: 시험 TLS 규칙과 다르고 digest가 없다.
  - aclfile에 비밀번호: gitleaks · 비밀 규칙에 걸린다.
- **계약 · 규칙**: C4 · C5.
- **시험**: gen-3(기존) · 새 gen-35 `docker compose -f compose.dev.yml config --quiet`.
- **변이**: env.example에 값 → gen-3.

### D20 deploy/base

- **무엇**
  - **공통**
    - 라벨 `app.kubernetes.io/name: <pod>` + `app.kubernetes.io/component: web|celery|migrate|outbox-purge`(selector가 불변이라 지금 고정 — 〔조사 shape F14〕)
    - `metadata.namespace` · `images:` · `commonLabels`를 두지 않는다(4a · ⑳).
    - 모든 `image:`는 정확히 `ghcr.io/joshua92y/<pod>`(태그 · digest 없음 — overlay name과 글자까지 같아야 한다 · 〔조사 shape F18〕).
  - **pod 공통 spec**: `automountServiceAccountToken: false` · securityContext `{runAsNonRoot: true, runAsUser: 10001, runAsGroup: 10001, seccompProfile RuntimeDefault}` · 컨테이너 `{allowPrivilegeEscalation: false, capabilities.drop [ALL], readOnlyRootFilesystem: true}` · `/tmp` emptyDir `{}` · pg-ca(secret `pg-main-ca` → `/etc/pg` 읽기 전용)
  - **런타임 컨테이너 env**(web · relay · celery · init `startup-check` · CronJob — runtime 프로필 전부): `POD_NAMESPACE` ← fieldRef `metadata.namespace`(D5 클러스터 교차 규칙 · 〔X8〕). migrate Job에는 두지 않는다(migrate 프로필).
  - **deployment.yaml**(`<pod>`)
    - replicas 1 · RollingUpdate 1/0 · Deployment metadata `reloader.stakater.com/auto: "true"`
    - pod 템플릿 `k8s.grafana.com/scrape: "true"` · `terminationGracePeriodSeconds: 90` · affinity preferred(weight 100 · role In [platform])
    - initContainer `startup-check`: requests 128Mi / limits 256Mi · envFrom ConfigMap + `<pod>-env` · pg-ca · tmp
    - `web`: ports http 8000 · web-metrics 9100 · envFrom ConfigMap + `<pod>-env` · env POD_IP · POD_NAMESPACE · liveness `/healthz` 20 s · readiness `/ready` 5 s · startup `/ready` 30×5 · timeoutSeconds 3(셋 모두) · `lifecycle.preStop.sleep.seconds: 5`(엔드포인트 제거와 SIGTERM의 경합 — BFF는 재시도 없이 3 s라 롤링마다 짧은 503이 난다 · grace 90 안 · 〔X29〕) · 256Mi/512Mi · pg-ca · kafka-ca(secret `jt-kafka-cluster-ca-cert` → `/etc/kafka`) · tmp
    - `relay`: `python manage.py outbox_relay` · port metrics 9464 · liveness tcpSocket metrics(timeoutSeconds 3) · 96Mi/192Mi(events.md:115 전제) · envFrom 같음 · pg-ca · kafka-ca · tmp
  - **deployment-celery.yaml**(`<pod>-celery`): Reloader · RollingUpdate 1/0 · affinity · 컨테이너 `celery`(D14 명령) · 192Mi/512Mi · envFrom 같음 · pg-ca · tmp · 프로브 없음 · 9100/9464 없음
  - **service.yaml**: `<pod>` · ClusterIP · 80 → targetPort `http` · selector component web.
  - **ingress.yaml**: `<pod>` · `ingressClassName: traefik` · 주석 `router.entrypoints: websecure` · `router.tls: "true"` · spec.tls 없음 · host `PLACEHOLDER.joshuatech.dev`(규칙 index 0 = overlay `/spec/rules/0/host`) · 경로: `/api` Prefix · `/health` **Exact**(Traefik 접두가 `/healthz`를 열면 T076 404 단언이 깨진다 — ㉓) · `/session` · `/sessions` · `/tenants` Prefix(`/session/check` 도달 — bn:777 K1) · backend 포트 이름 http.
  - **configmap.yaml**(`<pod>-config` · `argocd.argoproj.io/sync-wave: "-1"` · 평문 스칼라 · 블록 스칼라 `|` 금지): base = dev 값.
    - `ENV=dev` · `ALLOWED_HOSTS=<pod>.jt-dev.svc` · `ADMIN_HOST=""` · `ACCESS_TEAM_DOMAIN=joshua-tech.cloudflareaccess.com`
    - `ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN`의 base 값 = `PLACEHOLDER-SET-IN-OVERLAY`(게이트 2가 overlay 누락을 기동 실패로 바꾼다 · 숫자 없는 값 — gitleaks 8.30.1 generic-api-key가 `PLACEHOLDER-T075`처럼 숫자가 든 자리값을 잡는다 · 실측 2026-11-07 · 〔X33〕)
    - `ACCESS_AUD_ADMIN=""` · `AUTH_ACTOR_SUB=""` · `AUTHENTIK_AUDIENCE=<pod>` · `KAFKA_BOOTSTRAP=jt-kafka-kafka-bootstrap.data.svc:9093` · `KAFKA_USERNAME=dev-<pod>`
    - `OTEL_EXPORTER_OTLP_ENDPOINT=""`(T098) · `OTEL_TRACES_SAMPLER=parentbased_traceidratio` · `OTEL_TRACES_SAMPLER_ARG=0.1` · has_admin `FORCE_SCRIPT_NAME=""`
  - **externalsecret-env.yaml**(`<pod>-env` · 일반 리소스 · sync-wave "-1")
    - v1 · ClusterSecretStore `vault-dev` · `refreshInterval: 5m` · `refreshPolicy: Periodic` · target `{name: <pod>-env, creationPolicy: Owner, template: {engineVersion: v2, mergePolicy: Replace, data: …}}` · `dataFrom` · `templateFrom` 없음
    - data[] 순번 고정(overlay 인덱스 패치 인터페이스):

| # | secretKey | remoteRef.key | property |
|---|---|---|---|
| 0 | db_username | `dev/db/dev_<snake>/app` | username |
| 1 | db_password | `dev/db/dev_<snake>/app` | password |
| 2 | kafka_password | `dev/kafka/<pod>` | password |
| 3 | dragonfly_url | `dev/dragonfly/<pod>` | url |
| 4 | authentik_issuer | `dev/authentik/<pod>` | issuer |
| 5 | authentik_jwks_url | `dev/authentik/<pod>` | jwks_url |
| 6 | sentry_dsn | `dev/sentry/<pod>` | dsn |
| 7 | secret_key | `dev/django/<pod>` | secret_key |

    - 7번 경로는 T072가 정한다(base ES에 필요 — data-model §8 보정 C27). T075는 시드 · 판정만 한다. Vault 정책 `eso-dev`는 `kv/data/dev/*` 전체라 정책 변경은 없다(infra/vault/policies.tf:26-29 · 〔X17〕).
    - 순번은 overlay 인덱스 패치의 인터페이스다. prod overlay는 인덱스 replace마다 앞에 `op: test` · `path: /spec/data/N/secretKey` · `value: <이름>`을 둔다 — 템플릿 재생성으로 순번이 바뀌면 렌더가 실패한다(validate 3.2는 접두 · store만 본다 · VD-L15 · 〔X30〕).
    - template.data(`{% raw %}`): `DATABASE_URL: 'postgresql://{{ .db_username }}:{{ .db_password }}@pg-main-rw.data.svc:5432/{{ .db_username | trimSuffix "_app" }}?sslmode=verify-full&sslrootcert=/etc/pg/ca.crt'` · `KAFKA_PASSWORD` · `DRAGONFLY_URL` · `AUTHENTIK_ISSUER` · `AUTHENTIK_JWKS_URL` · `SENTRY_DSN` · `SECRET_KEY`
    - DB 이름은 role 이름(`<db>_app`)에서 파생한다 → prod overlay가 URL 문자열을 패치하지 않는다. trimSuffix는 VD-L4이고, 실패하면 base dev 리터럴 + prod 패치로 대체한다.
  - **externalsecret-migrate.yaml**(`<pod>-migrate`)
    - **PreSync hook**: `argocd.argoproj.io/hook: PreSync` · `hook-delete-policy: BeforeHookCreation` · `sync-wave: "-1"`
    - data[0, 1] = `dev/db/dev_<snake>/owner` username · password
    - template.data `DATABASE_OWNER_URL`(trimSuffix `"_owner"`)
  - **migrate-job.yaml**(`<pod>-migrate`)
    - PreSync + BeforeHookCreation(wave 0) · `backoffLimit: 1` · `activeDeadlineSeconds: 600` · `ttlSecondsAfterFinished: 604800` · restartPolicy Never
    - 컨테이너 `migrate`: envFrom **`<pod>-migrate`만**(ConfigMap 없음) + env `JT_SETTINGS_PROFILE=migrate` · 256Mi/512Mi · pg-ca · tmp
    - 명령 `["python", "-c", <스크립트>]`. 스크립트 순서:
      1. `DATABASE_OWNER_URL` 경로에서 db를 얻는다.
      2. 접속 재시도 ≤ 120 s. 메시지는 `db_connect_retry`이고 예외 클래스 이름만 싣는다. 최종 실패는 stderr 한 줄(`db_connect_failed <예외 클래스 이름>`) + 종료 코드 1이고 트레이스백 · 예외 메시지는 없다(〔X25〕). REVOKE 앞에 `migrate` 낱말을 두지 않는다(gen-14 순서 규칙).
      3. `sql.SQL("REVOKE CONNECT ON DATABASE {} FROM PUBLIC")` · `sql.SQL("GRANT CONNECT ON DATABASE {} TO {}, {}")`(Identifier — db, db_app, db_owner)
      4. `sys.exit(subprocess.call([sys.executable, "manage.py", "migrate", "--noinput"]))`(골든 꼴 — Windows 시험에서도 종료 코드가 그대로 전달된다 · 컨테이너 PID 1의 신호 동작은 execv와 같다 · ㉛ · 〔X4〕)
  - **첫 배포 순서**: PreSync에서 `<pod>-migrate` ES(wave -1)가 Healthy(Secret 생성)가 된 뒤 Job(wave 0)이 돈다. Argo hook 완료 판정이 health 기반이라는 점은 추론이다(VD-L1). Sync 단계에서는 `<pod>-env` ES · ConfigMap(wave -1)이 Healthy가 된 뒤 Deployment(wave 0)가 적용된다. pg-main-ca · CA 미러는 app sync-wave 100보다 앞인 wave 40에 있다(〔조사 shape F06〕).
  - **hook ES의 운영 성질**(㉞ · 〔X26〕): VD-L1 추론이 틀려 Job이 Secret보다 먼저 떠도 kubelet이 CreateContainerConfigError를 재시도하므로 activeDeadlineSeconds 600 안에서 스스로 풀린다. 남는 것은 넷이다.
    1. `-migrate` ES · migrate Job만 바꾼 변경은 자동 sync를 일으키지 않는다 → 전체 수동 Sync(리소스 선택 없음).
    2. `-migrate` ES 상태는 앱 health에 없다 → 운영자가 `kubectl get externalsecret <pod>-migrate`로 직접 판정한다.
    3. hook이 Healthy가 되지 않으면(Vault · ESO 장애 · kv 누락) operation이 시간 제한 없이 멈춘다 → 운영자가 operation을 terminate한다.
    4. 전체 sync마다 owner Secret이 지워졌다 다시 생긴다(BeforeHookCreation + Owner) — 모든 배포가 Vault · ESO 가용성에 걸린다(닫힌 쪽).
    - 넷 다 T075 런북에 적는다.
  - **자원 · 쿼터**(dev)
    - 정상 상태: requests 544Mi · limits 1216Mi
    - 롤링 중 둘 다 surge: 1088Mi / 2432Mi
    - PreSync Job은 롤링 전이라 정상 상태와만 겹친다: 800Mi / 1728Mi
    - jt-dev 검사 Job 동시 실행(약 416Mi / 832Mi)을 더해도 1504Mi < 2Gi · 3264Mi < 4Gi · pods 8 < 20 ✓(㉒)
- **왜**
  - 계약:44,64-71,78,80,83 · ⑳ · ㉑ · ㉒ · ㉓ · ㉔
  - ES template.data 조립(하네스 ③) · base = dev 값(긍정 픽스처 꼴)
  - `-env`를 hook으로 두지 않는다(BeforeHookCreation이 Secret을 GC해 런타임이 끊긴다).
- **기각한 대안**
  - kv `url`을 바로 매핑: 하네스 ③이 FAIL한다(G2).
  - base 자리값 + 양쪽 overlay 패치: validate 3.0 · 3.1 때문에 base가 어차피 유효해야 한다.
  - 첫 배포를 운영자 리소스 선택 Sync로 풀기: 사람 절차가 남는다.
  - migrate를 Sync hook + wave로: 계약 · 하네스가 PreSync를 고정했다.
  - CPU requests 명시: LimitRange 기본으로 충분하다.
  - Kafka CA를 celery에도: celery는 Kafka를 쓰지 않는다.
- **계약 · 규칙**: C8 · C9 · C10 · C11 · C20 · gitops-repo.md 보정(C28).
- **시험**: gen-7..17(기존) + 새 gen-19..24(D21).
- **변이**: D21 표.

### D21 하네스 test-first 추가(T065 PASS의 정의를 넓힌다)

- **무엇**
  - **H/tests/_render.py**
    - `_pod_spec`이 CronJob(`spec.jobTemplate.spec.template.spec`)도 읽는다.
    - `Workloads.cronjob` 추가.
    - `identify_workloads(docs, *, has_celery=True)`와 모든 `check_*(docs, *, has_celery=True)` · `run_checks(..., has_celery=)`. 기본값이 기존 동작 그대로라 기존 테스트는 바뀌지 않는다.
    - 변형(False)이면 Deployment 정확히 1 · celery 없음.
  - **기존 검사 확장**
    - security_context(gen-9): pod `runAsUser`/`runAsGroup == 10001`(정수) · 컨테이너 값이 있으면 10001
    - ingress(gen-17): class traefik · 주석 둘 · spec.tls 없음 · host `PLACEHOLDER.joshuatech.dev` · 허용 5경로의 pathType(`/health` Exact · 나머지 Prefix) · backend 포트 이름 http
    - 변형에서는 CronJob 컨테이너를 env_split · configmap · db_tls · strategy_resources(256Mi) · security_context가 함께 판정한다.
  - **새 검사**(CHECKS 키 · 각 gen)
    - `pod_lifecycle`(gen-19): web Deployment grace ≥ 90 · web liveness/readiness/startup timeoutSeconds ≥ 3 · web env POD_IP fieldRef `status.podIP` · web `lifecycle.preStop.sleep.seconds` ≥ 5(〔X29〕). 계약:108 ① · Y7 · D8.
    - `env_hygiene`(gen-20): 컨테이너마다 실효 env 이름 = env[].name ∪ (envFrom[].prefix + 참조한 ConfigMap 키) ∪ (prefix + 참조한 ES Secret 키 — template.data, 템플릿이 없거나 Merge면 secretKey). 렌더 밖 ConfigMap · Secret을 가리키는 envFrom은 위반이다(T071 r9 K5 · 〔X18〕).
      - 대소문자를 무시하고 금지 이름을 본다: NETRC · SSLKEYLOGFILE · HTTP_PROXY · HTTPS_PROXY · ALL_PROXY · CLIENT_CERT_FILE · CLIENT_KEY_FILE · SSL_CERT_FILE · SSL_CERT_DIR · REQUESTS_CA_BUNDLE · CURL_CA_BUNDLE · SENTRY_PRINT_ENVELOPES · PYTHONOPTIMIZE · PYTHONINSPECT · PYTHONSTARTUP · PYTHONPATH · `PG`로 시작하는 이름 전부(libpq env — `PGOPTIONS`가 app role의 statement_timeout을 덮는다 · ㉟ · 〔X18〕).
      - 런타임 거부는 두지 않는다 — T071이 정한 방어선(렌더 · 이미지 단언 + T075 gitops lint)과 같은 층이다(bn:4311).
      - `PROMETHEUS_MULTIPROC_DIR`는 relay 이름 집합 · 모든 ConfigMap 키 · `<pod>-env` 키에서 0이어야 한다.
      - 근거: 계약:108 ② · T071 S4/L3.
    - `external_secrets`(gen-21): v1 · ClusterSecretStore `vault-dev` · 키 `^dev/[a-z0-9_./-]+$` 꼴 · `(dev|prod)/(access|web)/` 금지 · property 있음 · refreshInterval 5m · refreshPolicy Periodic · creationPolicy Owner · target.name = 이름 · engineVersion v2 · mergePolicy 없음 또는 Replace · dataFrom · templateFrom 0. gitops 3.0 · 3.1의 거울 + 계약 공통 규칙.
    - `hook_order`(gen-22): `<pod>-migrate` ES = PreSync · BeforeHookCreation · wave < Job wave / Job 컨테이너 · 볼륨에 ConfigMap 참조 0 / `<pod>-env` ES · 모든 ConfigMap은 hook이 아니고 wave < 0. Secret 참조는 env_split 몫이라 교차가 없다.
    - `images`(gen-23): 모든 pod 문서의 모든 컨테이너 image가 정확히 `ghcr.io/joshua92y/sample-pod`. gen-23은 base `kustomization.yaml`에 images · namespace · commonLabels가 없는지도 본다(정적).
    - `cronjob`(gen-24): 기본 렌더 0개. 변형은 `<pod>-outbox-purge` 하나 · schedule `^\d{1,2} \d{1,2} \* \* \*$` · Forbid · timeZone이 있으면 Etc/UTC|UTC · 컨테이너 하나의 명령 = `python manage.py outbox_purge`. 계약:108 ③.
    - `runtime_wiring`(gen-36 · 〔X2〕 — 계약 행은 있는데 단언이 없던 배선. 다른 검사가 맡은 것 — relay 9464(gen-12 · 15), initContainers의 pg-ca · /tmp · securityContext(gen-11 · 9가 `_containers`로 initContainers까지 본다 · H/tests/_render.py:128-133) — 은 다시 보지 않는다)
      - web pod initContainers = `startup-check` 하나 · 명령 `["python", "manage.py", "startup_check"]` · envFrom = ConfigMap `<pod>-config` + secretRef `<pod>-env`(`-migrate` 없음)
      - web · relay가 secret `jt-kafka-cluster-ca-cert` 볼륨을 `/etc/kafka`(readOnly)에 마운트한다(계약:76)
      - web containerPort 9100(계약:64)
      - memory limits: web 512Mi · relay 192Mi · celery 512Mi · migrate 512Mi · CronJob 512Mi · init requests 128Mi / limits 256Mi(C10)
      - 런타임 컨테이너 전부(web · relay · celery · init · CronJob)에 env `POD_NAMESPACE` = fieldRef `metadata.namespace` · migrate Job 컨테이너에는 없다(〔X8〕)
      - ConfigMap data 값과 ES template.data 값에 줄바꿈 · 탭 · 앞뒤 공백이 없다(블록 스칼라 `|`의 끝 줄바꿈 — BAN-02 · HO-10)
  - **골든 갱신**(golden-render.yaml) — 왜: 실제 렌더 모양을 따르고 새 검사가 골든에서 위반 0이어야 한다.
    - web pod에 initContainer `startup-check`
    - grace 90 · timeoutSeconds 3 · POD_IP env
    - runAsUser/runAsGroup 10001
    - 이미지 태그 삭제(`:placeholder` 4곳)
    - ES store/키를 dev 값으로(G1) · `property: database` 삭제와 trimSuffix 조립
    - refreshPolicy · creationPolicy · mergePolicy
    - `-migrate` ES hook · wave · `-env` ES · ConfigMap wave -1
    - Job ConfigMap envFrom 삭제(G5) + env `JT_SETTINGS_PROFILE`
    - Ingress 주석 · host · pathType(G4)
    - kafka-ca 볼륨
    - 컨테이너 이름(web · relay · celery · migrate)은 변이 도우미가 기대므로 유지한다(H/tests/test_render_helpers.py:47-77).
  - **기존 변이 2건 수정**(〔X1〕 — 기존 68 × 새 검사 대조에서 충돌은 이 둘뿐이다 · 비판 A-1)
    - render-21 `env-secret-owner-url-via-secret-key`의 추가 키 `placeholder/sample-pod/db-owner`(:208-212)가 external_secrets에 교차 → `dev/db/dev_sample_pod/owner`로 바꾼다. 의도(secretKey 경로의 owner URL)는 그대로다.
    - render-09 `job-tmp-volume-not-empty-dir`(:158-160)의 `{"name": "tmp", "configMap": {"name": "x"}}`가 hook_order(Job의 ConfigMap 참조 금지)에 교차 → `persistentVolumeClaim: {claimName: x}`로 바꾼다. security_context만 위반하고 의도(Job /tmp가 emptyDir 아님)는 그대로다.
    - 조각 ①의 첫 단계로 기존 변이 68 × 새 검사 7종(runtime_wiring 포함) 교차 행렬을 돌려 충돌이 이 둘뿐임을 기록한다. 새 변이도 맡은 검사만 걸리는 꼴로 둔다(아래 목록은 예시 — 교차하면 꼴을 바꾼다).
  - **새 변이**(render-70부터 표 끝에 이어 붙임): 새 검사마다 2개 이상, 확장분마다 1개 이상.
    - pod_lifecycle: grace-30 · grace 삭제 · readiness timeout 1 · startup timeout 없음 · liveness timeout 1 · POD_IP 삭제 · fieldPath 오류 · preStop 삭제 · preStop 1 s(〔X29〕)
    - env_hygiene: relay env 멀티프로세스 · ConfigMap 멀티프로세스 키 · `-env` 템플릿 키 · web NETRC · celery `https_proxy` · init SSLKEYLOGFILE · ConfigMap REQUESTS_CA_BUNDLE · Job CLIENT_KEY_FILE · envFrom prefix `HTTPS_` + ConfigMap 키 `PROXY` · 렌더 밖 ConfigMap envFrom · relay `PGOPTIONS` · web `SSL_CERT_DIR` · ConfigMap `SENTRY_PRINT_ENVELOPES` · celery `PYTHONPATH`(〔X18〕)
    - external_secrets: placeholder-store · 키 placeholder · v1beta1 · dataFrom · templateFrom · Merge · 1h · refreshPolicy 없음 · Orphan · `dev/access/…` · property 없음
    - hook_order: hook 삭제 · wave 0 · delete-policy 없음 · Job configMapRef · Job ConfigMap 볼륨 · `-env` hook 추가 · ConfigMap wave 없음
    - images: web 태그 · relay digest · celery 다른 이름 · init 태그
    - cronjob: 기본 렌더에 CronJob
    - security_context: pod runAsUser 없음 · Job runAsGroup 0 · celery 컨테이너 runAsUser 0
    - ingress: class nginx · entrypoints 없음 · tls "false" · spec.tls · host invalid · `/health` Prefix · `/session` Exact
    - runtime_wiring(〔X2〕): init 삭제 · init 명령 다름 · init envFrom에서 `<pod>-env` 삭제 · web kafka-ca 마운트 삭제 · relay mountPath `/etc/kafka-ca` · kafka secret 이름 오타 · web 9100 삭제 · web limits 1Gi · init limits 삭제 · relay POD_NAMESPACE 삭제 · celery fieldPath `metadata.name` · Job에 POD_NAMESPACE 추가 · ConfigMap 값 끝 줄바꿈 · ES template.data 값 앞 공백
  - **변형 골든 `fixtures/golden-cronjob.yaml`**(골든 − celery Deployment + CronJob)과 `_CRON_TABLE`(test_render_helpers.py 안 · 함수 이름 `test_render_cron_*`)
    - cron: hourly · Allow · 명령 relay · 이름 다름 · 둘
    - env_split: env 없음 · migrate 참조
    - configmap: 참조 삭제
    - db_tls: CA 마운트 삭제
    - security_context: automount true · readOnly false
    - strategy_resources: 128Mi · CPU limit
    - images: 태그
    - identification: celery Deployment 추가
    - 교차 시험: 기본 골든을 변형 모드로, 변형 골든을 기본 모드로 돌리면 identification이 실패해야 한다.
    - `_CRON_TABLE`에도 `test_render_mutation_table_covers_every_check`와 같은 완전성 시험을 둔다(소유 검사 ⊆ CHECKS · cronjob 소유 ≥ 1 · 〔X1〕).
  - **_tree.py 새 도우미**(기존 상수 · 함수 무수정): `check_generated_files_t072` · `check_pytest_hygiene` · `check_outbox_test` · `check_dockerfile_text` · `check_image_config` + test_check_helpers의 golden/변이.
  - **conftest**
    - `pod_pytest` 인자에 `--show-capture=no`(I5)
    - 새 세션 픽스처:
      - `variant_generated`(두 벌 · 〔X10〕): ① `no-celery` = `--skip-tasks --defaults --data pod_name=sample-pod --data has_celery=false --data owns_events=[thing.created] --data consumes_events=[other-pod.thing.created]`(has_admin 기본 true — 계약:108의 변형 정의 그대로 · SP-2에 가장 흔할 조합) → `<root>/variants/no-celery/apps/sample-pod` ② `no-admin` = `--skip-tasks --defaults --data pod_name=sample-pod --data has_celery=false --data has_admin=false` → `<root>/variants/no-admin/apps/sample-pod`. 형제 django-common 없는 렌더 · 검사 전용 배치다(C1 예외 · 〔X3〕). 빌드 컨텍스트에서는 dockerignore가 뺀다.
      - `variant_rendered` · `variant_kubeconform`
      - `image_smoke`(`docker run --rm` 탐침 · 웹 기동은 `-d` + finally `docker rm -f`)
    - `_layout.copier_copy_argv`에 선택 인자(extra_data · skip_tasks)를 더한다. 기본 출력은 같다.
  - **test_generate.py 새 gen**(이름에 tool · render · check 낱말 금지 — ⑤)
    - gen-19..24(렌더) · gen-25(T072 트리) · gen-26(pytest 위생) · gen-27(outbox_purge 표식) · gen-28(validator)
    - gen-29(변형 두 벌 생성 · 트리) · gen-30(변형 두 벌 kustomize+kubeconform)
    - gen-31(변형 렌더 단언 — CHECKS를 `has_celery=False`로 매개화 · 두 벌)
    - gen-32(변형 Python — 기본 pod venv(상위 집합)로 변형마다 `manage.py check` + settings 하위 프로세스 + `pytest --collect-only` 7파일. 하위 프로세스는 `django.setup()`과 ROOT_URLCONF import 뒤 `'celery' not in sys.modules`를 단언한다 — 상위 집합 venv가 has_celery=false 코드의 celery import를 가리지 못하게. no-celery: admin · Session 미들웨어 있음 · no-admin: contrib · Session · Auth · Message 미들웨어 · TEMPLATES · ADMIN_URLCONF 없음 · 〔X10〕)
    - gen-33(이미지 구성 · 탐침) · gen-34(이미지 기동 스모크 넷 — 아래 · 〔X22〕) · gen-35(compose config) · gen-36(runtime_wiring — 위)
    - gen-34 스모크(공통: `--network none --read-only --tmpfs /tmp` · 이미지 USER 그대로 · 시험 env 자리값 · 대기 상한 180 s(x86 Windows의 QEMU) · 끝에 `docker rm -f`와 정리 확인)
      1. web: gunicorn `--no-control-socket` 기동 · `:9100/metrics`에 `http_requests_total` · POD_IP=127.0.0.1로 `/healthz` 200
      2. relay: `python manage.py outbox_relay`가 N초 뒤 살아 있고 `docker exec`로 `127.0.0.1:9464/metrics`가 응답한다 · 로그에 `Read-only file system` · PermissionError 0
      3. celery: D14 명령이 N초 동안 브로커 재시도 단계까지 가고 `/tmp/celerybeat-schedule*`가 생긴다 · 쓰기 오류 0
      4. 명령: `outbox_purge` · `startup_check --wait 1`이 DB 없음으로 0이 아닌 종료 + 예외 클래스 이름만(값 · 트레이스백 없음 · 〔X25〕)
  - **가정 ①–⑩ 변경**(test_generate.py 독스트링과 이 문서에 적는다 — 닫힌 bn 「T065」 절은 고치지 않는다. 독스트링의 「build-notes 「T065」 설계를 먼저 개정」은 「계약 §기본 테스트 6 + design/t072-design.md를 먼저 개정」으로 바꾼다 · 〔X11〕)
    - ① 변형 모드 추가(기본 규칙 불변)
    - ⑥ 강화(숫자 10001 + pod runAsUser)
    - ⑧ + Job은 ConfigMap 참조 금지
    - ⑩ 일부 대체: pathType · readiness/startup timeout을 이제 단언한다. migrate ConfigMap 참조는 금지로 바뀐다. portNumber 어노테이션은 계속 단언하지 않는다(T098).
    - ② ③ ④ ⑤ ⑦ ⑨는 그대로다.
- **왜**: 계약:108 넷(④) · T071 S4/L3 · 숫자 UID · 하네스가 보지 않던 계약 행(〔조사 harness F34〕) · gitops 거울(⑳).
- **기각한 대안**
  - REQUIRED_FILES 직접 확장: 개수 단언은 동적이라 깨지지 않지만(test_check_helpers.py:269-279 · 305-309), 변형마다 조건부 파일 집합이 달라 매개변수를 받는 T072 도우미가 낫다. check_pyproject 직접 확장은 골든 · 동치 변형(:145-159)을 깬다(〔X19〕).
  - 변형 생성물의 시험까지 실행: testcontainers 시간이 두 배가 된다.
- **계약 · 규칙**: C24.
- **시험 · 끝 조건**
  - `-k "tool or render or check"`에서 기존 155개(같은 ID — 정의가 바뀌는 변이 render-09 · render-21 포함 · 〔X1〕) 전부 초록 + 새 infra 테스트 초록.
  - 조각 ① 끝에는 새 gen이 빨강(사유 = 템플릿 없음)이어야 한다.
  - tool-6은 T072 뒤 `_tasks` 때문에 PyPI 네트워크가 필요하다(§9).
- **변이**: 위 표 자체.

### D22 CI 배선

- **무엇**
  - **test job**(.github/workflows/ci.yml:324-345 자리 교체)
    - 기존 스텝 유지 + checkout `persist-credentials: false` + `timeout-minutes: 60`
    - kustomize · kubeconform 설치 스텝을 kubeconform job과 같은 버전 · sha로 복제(:357-395)
    - `uv run --directory packages/django-common --locked pytest -q`(패키지 ini · `-O` 없음 · 넓히는 옵션 없음 — 규칙:69 · bn:2664 · I5)
    - `uv run --directory templates/django-pod --locked pytest -q`(기본 docker 드라이버 · arm64 네이티브 · 실패 산출물 업로드 없음)
  - **kubeconform job**(timeout 10 · persist-credentials false 유지)
    - setup-uv(SHA 핀 · 판은 UD-1을 따른다)
    - 생성 스텝: `uv run --directory templates/django-pod --locked python -m copier copy --defaults --skip-tasks --quiet --data pod_name=sample-pod "$GITHUB_WORKSPACE/templates/django-pod" "$RUNNER_TEMP/gen/default/apps/sample-pod"` + 같은 꼴로 `--data has_celery=false` → `…/gen/no-celery/apps/sample-pod` · `--data has_celery=false --data has_admin=false` → `…/gen/no-admin/apps/sample-pod`(형제 없는 렌더 전용 배치 — C1 예외 · 〔X3 · X10〕)
    - run 줄: `bash scripts/ci/kubeconform-deploy.sh --generated "$RUNNER_TEMP/gen/default/apps/sample-pod" --generated "$RUNNER_TEMP/gen/no-celery/apps/sample-pod" --generated "$RUNNER_TEMP/gen/no-admin/apps/sample-pod"`(`${{` 없음 — static-3)
  - **kubeconform-deploy.sh**: 머리 주석(:48-63)과 경보선 FAIL 문구(:325)를 실제 CI 명령(`--skip-tasks` · `uv run --locked`)으로 고친다. 낡은 「copier는 잠금 파일에 없다」 줄은 지운다. `--generated` · `T072` 낱말은 유지한다(test 7).
  - **kubeconform-deploy.tests.ps1**
    - static-6: 새 run 줄 정확 일치
    - 새 static: 생성 스텝 낱말(`--skip-tasks` · `--locked` · `pod_name=sample-pod` · 두 경로가 `--generated`와 일치) · test job과 kubeconform job의 KUSTOMIZE/KUBECONFORM 버전 · sha 동일
    - r-1: 실제 저장소 루트 → 종료 1 + 경보선 FAIL 한 줄(`--generated` · `T072` 포함)
  - run-all은 바꾸지 않는다(1b3이 ps1을 돈다).
  - 템플릿 deploy 파일과 CI 배선은 같은 커밋이어야 한다(경보선).
- **왜**
  - 하네스 · dc 시험의 CI 공백(bn:2664 · I5)을 메운다.
  - 경보선은 템플릿 매니페스트가 생기는 즉시 FAIL한다(㉖).
  - `--skip-tasks`는 신뢰 · 네트워크 없이 렌더만 한다(⑥). D13(bn:772)의 「test job에서 `--generated`」 계획을 kubeconform job으로 옮긴다. job이 분리돼 있어 경보선은 kubeconform job에서 꺼져야 한다.
- **기각한 대안**
  - 스크립트 안에서 copier 실행: 스크립트가 uv · 하네스 venv에 결합된다.
  - test job에서만 `--generated`: kubeconform job 경보선이 계속 FAIL한다.
  - django-common pytest를 빼기: CI 공백이 남는다.
- **계약 · 규칙**: C1 · ci.yml 머리 주석 한 줄.
- **시험**: `pwsh -NoProfile -File tests/scripts/kubeconform-deploy.tests.ps1` · run-all · VD-T072-CI(push 뒤 첫 실행).
- **변이**: run 줄에서 `--generated` 하나 빠짐 → 새 static이 잡는다.

### 덮음 표(누락 확인용)

- **UND**
  - UND-01 → D8 · UND-02 → D10 · UND-03 → D10 · UND-04 → D7 · UND-05 → D11 · UND-06 → D11
  - UND-07 → D6/D12 · UND-08 → D12 · UND-09 → D20 · UND-10 → D20 · UND-11 → D6/D20 · UND-12 → D14
  - UND-13 → D20/D5 · UND-14 → D5 · UND-15 → D6 · UND-16 → D9 · UND-17 → D12 · UND-18 → D13
  - UND-19 → D2 · UND-20 → D4/D16/D21 · UND-21 → D4/UD-2 · UND-22 → D18 · UND-23 → D20 · UND-24 → D20
  - UND-25 → D5/D18/D20/C27 · UND-26 → D22
- **MIS**
  - MIS-01 · 02 · 04 → D4 · MIS-03 → D20 · MIS-05 → D20/C17 · MIS-06 → D6 · MIS-07 → D5 · MIS-08 → D15
  - MIS-09 → D17 · MIS-10 · 11 · 12 → D20/D21/C28 · MIS-13 → D5 · MIS-14 → D16 · MIS-15 → D19
  - MIS-16 · 17 → §7 · MIS-18 → A13 · MIS-19 → A14 · MIS-20 → D20 · MIS-21 → D10 · MIS-22 → D7
- **하네스 F**: F30 → D21 · F31 → D2/D21 · F32 → D16/D17 · F33 → D18/D21 · F34 → D20/D21 · F35 → D22
- **REQ · HO**
  - REQ-01 → D2 · REQ-02 → D3 · REQ-03 → D4 · REQ-04 → D5 · REQ-05 → D9 · REQ-06 → D10 · REQ-07 → D6/D10
  - REQ-08 → D12 · REQ-09 → D13 · REQ-10 → D14 · REQ-11 → D15 · REQ-12 → D18 · REQ-13 → D19 · REQ-14 → D16/D17
  - REQ-15 · 16 · 17 → D20 · REQ-18 → D21 · REQ-19 → D22 · REQ-20 → D7/D11 · REQ-21 → D5/D7
  - HO-01 → D12/D20 · HO-02 → D6/D20 · HO-03 → D14 · HO-04 → D16 · HO-05 → D6/D7 · HO-06 → D2-D22 · HO-07 → D16
  - HO-08 → D7/D12 · HO-09 → D6/D15/D20 · HO-10 → D5-D8 · HO-11 · 12 → D6/D7/D11/D21 · HO-13 → D20/D22 · HO-14 → D5
- **SET · DEP · BAN**
  - SET-01..07 → D5/D6/D19
  - DEP-01..07 → §7
  - BAN-01..07 → D5 · D6 · D10 · D14 · D20 · D21(렌더 단언)
- **열린 질문**
  - spec Q1 → D8 · Q2 → D10 · Q3 → D7 · Q4 → D12 · Q5 · 6 · 7 → D20 · Q8 → D11/§7 T098 · Q9 → D5 · Q10 → D14 · Q11 → D10 · Q12 → D12 · Q13 → D20 · Q14 → D17/D13 · Q15 → D2 · Q16 → D22 · Q17 → D5/D18/C27 · Q18 → D18
  - harness Q1 → D21 · Q2 → D18 · Q3 → D16 · Q4 → VD-T072-3 · Q5 → D4 · Q6 → D2 · Q7 → D22 · Q8 → D13 · Q9 → D20(relay는 참조 · migrate는 금지) · Q10 → D4
  - library Q1 · 2 → D7 · Q3 → D5 · Q4 → D17 · Q5 → D10 · Q6 → D6 · Q7 → D4 · Q8 → D6 · Q9 → D7 · Q10 → D6(`/etc/kafka/ca.crt`) · Q11 → D16 · Q12 → D5/D18/D19
  - tooling Q1 → VD-T072-7 · Q2 → UD-1 · Q3 → UD-2 · Q4 · Q8 → D14/VD-T072-4 · Q5 · 6 → VD-T072-5/6 · Q7 → VD-T072-3 · Q9 → D11 · Q10 → D18 · Q11 → D10/D11 · Q12 → D21
  - shape Q1 → D20(hook 안 a) · Q2 → D20(trimSuffix + 대체안) · Q3 → D20/§7 T073 · Q4 → D18/D20 · Q5 → §7 T098 · Q6 → D20 · Q7 → D22 · Q8 → D20 · Q9 → §7 T074 · Q10 → §7 T075/T084
- **비판 A 덮음 표의 부분 항목**: REQ-15 · F34 → X2(runtime_wiring) · HO-06 → X6 · HO-08 → X15 · HO-10 · BAN-02 → X2(값 줄바꿈 0) · HO-12 · UND-20 → X14 · SET-07 → X16 · DEP-07 → §7 T114 · BAN-04 → X13 · BAN-06 → X3

---

## 4. 계약 · 규칙 보정 목록(같은 커밋 · 「T072 보정 2026-11-07」 표식)

**contracts/pod-template.md**

- **C1** :3 뒤 한 줄 추가: 「렌더 · 검사 전용 생성(`--skip-tasks` — uv lock 없음 · `--trust` 불필요 · CI kubeconform job · 하네스 변형)은 형제 django-common 없는 배치를 허용한다. 그 트리에서 uv lock · sync를 하지 않고, 하네스 변형의 Python 실행은 기본 pod venv(상위 집합)로만 한다」 + :5 생성 위치 규칙에 같은 예외 한 줄(〔X3〕).
- **C2** :23 pyproject 행
  - 의존 추가: pydantic-settings · gunicorn · prometheus-client · dev pyyaml
  - celery[redis]는 has_celery에만
  - 「회귀 시 1.6.2 폴백」 → 「폴백은 이 계약과 하네스(`_tree.py` NINJA_SPEC) 개정 뒤에만」
  - pytest addopts에 `--show-capture=no`
- **C3** :24 Dockerfile 행: `USER app` → 「`USER 10001:10001`(숫자 — kubelet은 이름 USER로 runAsNonRoot를 판정하지 못한다) · `Dockerfile.dockerignore`(허용 목록 + `.env*` · `*.pem` · `*.key` · `.git*` 재제외 — 〔X27〕) · build-arg `APP_VERSION` · `APP_GIT_SHA` → ENV + 라벨 revision · `--no-editable` · collectstatic 없음 · 빌더와 런타임 Python 패치 판 차이 허용(minor 동일)」.
- **C4** :25 compose 행: 「TLS 전용 postgres 18.6(tests/docker/pg-tls) · dragonfly v1.40.1(aclfile · nopass 로컬 사용자) · apache/kafka 4.3.1 KRaft PLAINTEXT · 127.0.0.1 bind · digest 핀」.
- **C5** :26 env.example 행: 「+ `SECRET_KEY` · `APP_VERSION` · `APP_GIT_SHA`(〔X16〕) · (has_admin) `FORCE_SCRIPT_NAME` — 키만」.
- **C6** :29-34 트리: conf.py · apps.py · startup.py · wsgi.py · gunicorn_conf.py · middleware.py · metrics.py · errors.py · urls_admin.py · celery.py/tasks.py · events/README.md · consumers.py · startup_check 명령 · tests 도우미 · `JT_SETTINGS_PROFILE`.
- **C7** :36 conftest 행: 「Dragonfly ACL은 기동 뒤 `ACL SETUSER`(운영 aclfile과 같은 규칙 문자열 — admin · `<pod>`) · DB `<pod_snake>` · role `<pod_snake>_owner/_app` · 기본 권한을 주지 않는다(GRANT 마이그레이션이 증명)」.
- **C8** :44 deploy/base 행: 파일 목록 · initContainer `startup-check` · Kafka CA 마운트 · `<pod>-migrate` ES PreSync hook · wave · 런타임 컨테이너 env `POD_NAMESPACE`(〔X8〕) · web preStop sleep 5 s(〔X29〕).
- **C9** :65 프로브 행: 「선택은 T072」 → 「downward API `POD_IP`를 ALLOWED_HOSTS에 더한다(T072) · readiness · startup(· liveness) `timeoutSeconds: 3`」.
- **C10** :68 requests 행에 limits와 init을 더한다: web 512Mi · relay 192Mi · celery 512Mi · migrate · CronJob 512Mi · init 128Mi/256Mi.
- **C11** :69 securityContext 행: pod `runAsUser: 10001` · `runAsGroup: 10001`.
- **C12** :71 DB 행: OPTIONS(connect_timeout 2 · keepalives · tcp_user_timeout) · `CONN_MAX_AGE 60` · `CONN_HEALTH_CHECKS` · URL 쿼리는 sslmode · sslrootcert만 · ENV=test는 require 이상.
- **C13** :74 인증 행: 「T072가 부른다」 → 「`AppConfig.ready`(runtime 프로필)」 · 템플릿 AUTH_EXEMPT = 헬스 3 · 「사람 admin 경로 미결」 → 「T084(report)」.
- **C14** :76 Kafka 행: `ssl.ca.location = /etc/kafka/ca.crt`(상수 `conf.KAFKA_CA_FILE` · Secret `jt-kafka-cluster-ca-cert` → `/etc/kafka`) · ENV=test면 settings가 PLAINTEXT를 명시한다 — ENV=test는 클러스터 밖 전용이다(POD_NAMESPACE 교차 규칙이 클러스터 안 ENV=test를 거부한다 · 〔X13〕).
- **C15** :77 로그 행: `LOGGING_CONFIG = None` · gunicorn · celery 생애 원문 줄은 예외.
- **C16** :78 메트릭 행: 「web 9100 = gunicorn 워커 1 × gthread 4 · 단일 프로세스 레지스트리(multiprocess 없음) · `http_requests_total{route,status}`는 pod `metrics.py`(미들웨어 import만) · 소유 T072」.
- **C17** :80 설정 행
  - IDENTITY_M2M_URL 삭제(「BFF 변수 · pod 설정 아님 — bff-api.md:14」)
  - ConfigMap 키에 ENV · KAFKA_BOOTSTRAP · KAFKA_USERNAME · OTEL_* 추가
  - 「AUTH_ACTOR_SUB와 dev의 ADMIN_HOST는 … 존재만」 → 「ADMIN_HOST는 존재만(빈 값 유효) · AUTH_ACTOR_SUB는 선택(기본 빈 값)」
  - 게이트 2(`PLACEHOLDER-` 포함 거부 · `JT_PLACEHOLDER_EXEMPT` ∩ 코드 상수) · runtime의 DATABASE_OWNER_URL 거부 · ALLOWED_HOSTS 쉼표 목록 · `*` 금지 · migrate 프로필
  - 클러스터 교차 규칙(`POD_NAMESPACE`가 있으면 ENV ≠ test · `jt-<ENV>` · KAFKA_USERNAME · DB 사용자 · svc 이름 — 〔X8〕) · SECRET_KEY 강도(W009 기준 — 〔X21〕) · 자격 URL 사용자 정보 `[A-Za-z0-9_-]`(〔X25〕)
- **C18** :81 오류 행: Ninja HttpError 400 대응 · 처리기 시험은 pod urlconf의 처리기를 복사한 probe urlconf와 `ADMIN_URLCONF` 덮기로 한다.
- **C19** :82 이미지 행: 숫자 USER.
- **C20** :83 마이그레이션 행: 「`<pod>-migrate` ES = PreSync hook wave -1 + BeforeHookCreation(첫 배포 순서) · Job env = `<pod>-migrate` + `JT_SETTINGS_PROFILE=migrate` · Job 명령 = CONNECT 경계 SQL 뒤 `subprocess.call` migrate(종료 코드 전달 · 〔X4〕) · app role 테이블 GRANT는 pod 마이그레이션 `core/0001_app_role_grants` · hook ES의 운영 성질(hook만 바뀐 변경은 전체 수동 Sync · health 집계 밖 · 멈춘 operation은 terminate — 〔X26〕)」.
- **C21** :84 Celery 행: 브로커 = ready의 runtime 분기에서 `settings.DRAGONFLY_URL`(migrate 프로필은 celery를 import하지 않는다 · 〔X7〕) · transport 옵션 · 원격 제어 · gossip · mingle · heartbeat 끔 · 결과 백엔드 없음 · solo + 내장 beat · CronJob 값(`17 3 * * *` Etc/UTC · Forbid · backoffLimit 2 · deadline).
- **C22** :102 §기본 테스트 2: 「스키마 통과」 → 「봉투 꼴 통과(라이브러리 `ENVELOPE_PATTERNS` + 필수 키 9 + const 2 + time 꼴) — 생성물 · 이미지에 packages/events가 없다 · data 스키마 검증은 T067 시험과 dc out-6」.
- **C23** :103 §기본 테스트 3: 기동 위생 항목(게이트 2 · owner URL 거부 · POD_IP · migrate 프로필 · 클러스터 교차 규칙 · SECRET_KEY 강도 · URL 사용자 정보 — 〔X8 · X21 · X25〕) · 처리기 probe 방식 · has_admin 정적 경로 탈출 400(〔X9〕).
- **C24** :108 §기본 테스트 6: 하네스 추가 목록(gen-19..36 요약) · 변형 두 벌(no-celery = has_celery=false — 계약 정의 그대로 · no-admin = has_celery=false + has_admin=false · 〔X10〕) · 변형 Python 실행은 기본 venv + celery 미import 단언 · 이미지 구성 · 기동 스모크 넷(〔X22〕) · runtime_wiring(〔X2〕) · `env.example` 키 수 갱신(〔X16〕).
- **C25** :32 core 행: 「실행되지 않는 예(주석) + `0001_app_role_grants` · 실제 A 등급 표는 시험 전용 앱」.
- **C26** :17 has_admin 행: 정적 서빙 = AdminHostMiddleware + staticfiles finders(`insecure=True`) · JwtAuth 앞 · WhiteNoise · collectstatic 없음.
- **C30** :75 Dragonfly 행 · :93 타임아웃 표: 「0.2 s는 거부 목록 클라이언트 전용 · Celery 브로커 transport는 `socket_timeout` 5 · `socket_connect_timeout` 2(BRPOP 1 s 대기보다 크다)」(〔X20〕).
- **C31** :80 `ALLOWED_HOSTS` 정의에 「(web 컨테이너) downward API `POD_IP`」를 더한다(C9와 같은 내용 · 〔X20〕).

**data-model.md**

- **C29** §6(:113) 「막는 장치는 아직 없다」 → 「copier `pod_name` validator(T072): 케밥 · ≤ 39 · dev/dev- 금지 — 접두 겹침은 여전히 장치 없음」(번호를 C26에서 바꿨다 — pod-template :17의 C26과 겹쳤다 · 〔X20〕).
- **C27** §8에 행 추가: `kv/{env}/django/<pod>` · 키 `secret_key` · `vault-{env}` · `<pod>-env`(SECRET_KEY · 경로는 T072가 정하고 T075는 시드 · 판정만 · 시드 규칙 = CSPRNG ≥ 50자 · dev와 prod 다른 값 · 값을 화면 · argv에 내지 않음 · 회전 = sub_hash 재계산 · 세션 무효 — 〔X17 · X21〕).

**contracts/gitops-repo.md**

- **C28** :24-26 base 파일에 `deployment-celery.yaml`(has_celery) · `cronjob-outbox-purge.yaml`(has_celery=false) 추가 · :105-116 예시를 template.data 조립 · base dev 값 꼴로 고친다 · overlay의 ES 인덱스 replace 앞 `op: test`(secretKey 확인) 규칙 한 줄(〔X30〕) · :161 ConfigMap 예시에서 `IDENTITY_M2M_URL` 삭제(〔X20〕).

**규칙 `.claude/rules/django-pod.md`**(영어 · kr 미러는 translation-pending 줄)

- §Template: 렌더 · 검사 전용 `--skip-tasks`와 형제 없는 배치 예외(uv lock · sync 금지 · 변형 Python은 기본 venv — 〔X3〕)
- §Auth(:50): 프로브 Host = POD_IP
- §Settings(:54): IDENTITY_M2M_URL 삭제 · 프로필 · 게이트 2 · owner URL 거부 · 클러스터 교차 규칙 · ENV=test 클러스터 밖 전용 · SECRET_KEY 강도 · URL 사용자 정보(〔X8 · X13 · X21 · X25〕)
- §Tests(:69): 생성 pod addopts `--show-capture=no`
- §Migrations: app role GRANT 마이그레이션 · `<pod>-migrate` hook
- §Dragonfly(:80): 브로커 transport · pub/sub 끔 · 0.2 s는 거부 목록 전용
- §Logging(:88): gunicorn · celery 생애 원문 줄(stderr)은 「한 줄 = 객체」의 예외(〔X20〕)

**gitops 저장소**(T075 PR): platform/cnpg-databases/README.md:364 「+ app role 테이블 GRANT」를 「pod 마이그레이션 `core/0001_app_role_grants`」로(G7).

---

## 5. 빌드 조각

조각은 검토 단위다. 커밋은 설계 커밋 하나와 구현 커밋 하나로 한다. UD-1이 B면 uv 판 올림은 구현 커밋에 함께 넣는다(잠금 재작성이 크면 조각 ③ 앞 별도 커밋 — 그때 커밋은 셋 · 〔X11〕). 조각 ④의 deploy 파일과 CI 배선은 반드시 같은 커밋이다(경보선).

공통 환경(Windows 빌더):

- `.superpowers/bin`을 PATH 앞에 둔다(또는 JT_KUSTOMIZE · JT_KUBECONFORM).
- 짧은 `JT_SAMPLE_POD_ROOT`(예: `D:\jt-sample` — 저장소 밖이고 조상 디렉터리가 아니다).
- Docker Desktop(arm64 에뮬레이션).
- 경로 길이: 짧은 루트로 VD-T072-18을 조각 ① 시작에 기록한다(〔X14〕).
- 커밋되는 파일(템플릿 · 하네스 · 생성물 시험 · 픽스처 · 문서)에 「접근 · 키 · 비밀 · 토큰 계열 이름 = 숫자가 섞인 10자 이상 값」 꼴을 두지 않는다 — gitleaks 8.30.1 generic-api-key가 잡고 CI `gitleaks` job은 main ruleset의 필수 검사다. 시험 비밀은 런타임 난수(`secrets.token_urlsafe`)로 만들고, 자리값은 숫자 없는 꼴(`PLACEHOLDER-SET-IN-OVERLAY` · `placeholder-access-aud-m2m`)로 쓴다. 바꾼 파일마다 `.superpowers/bin/gitleaks.exe dir <파일> --no-banner --redact`가 exit 0이어야 한다(〔X33〕).
- 반복 중에는 영향 받는 케이스만 돌리고, 전체 실행은 조각 끝에 한 번.

### 조각 ① 하네스 test-first(빨강 만들기)

- **입력**: D21 · H/tests 전부 · 골든.
- **산출**: `_render.py` · `_tree.py` · `_layout.py` · `conftest.py` · `test_generate.py`(gen-19..35 + 독스트링 가정) · `test_render_helpers.py`(골든 갱신 반영 · 변이 1건 수정 · 새 변이 · cron 표) · `test_check_helpers.py` · `fixtures/golden-render.yaml` · `fixtures/golden-cronjob.yaml`. 템플릿은 무수정이다.
- **검증**
  - `uv run --directory templates/django-pod --locked pytest -q -k "tool or render or check"`: 기존 155 ID 전부 + 새 infra 초록, 종료 0.
  - 첫 단계: 기존 변이 68 × 새 검사 7종 교차 행렬(충돌 = render-09 · render-21뿐 · 〔X1〕).
  - 전체 실행: 새 gen마다 기대 결과(FAIL · ERROR)를 픽스처 의존(generated · variant_generated · synced · rendered · image)으로 미리 적고 실제와 대조해 기록한다. 예: `--skip-tasks` 변형 생성(gen-29)은 빈 템플릿에서도 성공하므로 ERROR가 아니라 트리 단언 FAIL이다(〔X5〕).
- **끝 조건**: infra 초록 · 새 gen의 실패 사유가 「템플릿 없음」 계열이다.

### 조각 ② copier + 생성 Python 프로젝트 + 생성물 시험(deploy 제외)

- **입력**: D2–D17 · D19의 env.example · README · dc tests 원본.
- **산출**: `H/copier.yml` · `template/`(deploy/와 Dockerfile 제외 — 단, `tests/test_migrations.py`의 migrate Job 스크립트 시험은 조각 ④ 전까지 파일이 없어 FAIL이다. 그래서 조각 ②에서는 `tests/test_migrations.py`의 YAML 시험을 조각 ④와 함께 켠다. 내용은 같은 커밋 기준으로 판정한다) · `template/.gitkeep` 삭제.
- **검증**
  - 노드 ID로 고른다: `… pytest -q tests/test_generate.py::test_gen_1_generated_files tests/test_generate.py::test_gen_2_pyproject_pins_and_pytest_policy …`(목록은 조각 ①이 만든 이름으로 조각 ② 지시문에 적는다 — `-k gen_1`은 부분 문자열이라 gen_10..19까지 잡는다 · 〔X5〕)
  - gen-1 · gen-25는 deploy 파일 때문에 ④까지 일부 FAIL이 정상이다.
  - 생성물 안 반복: `uv run --directory <root>/apps/sample-pod --locked pytest -q tests/<파일>`. 고친 것은 템플릿으로 옮기고 다시 생성한다.
  - 시작 전: UD-2가 B면 VD-T072-17(첫 생성 전 · 〔X14〕).
  - VD-T072-1 · 2 · 3 · 4 · 9 · 10 · 11 · 12 · 13 · 14 · 15 · 16(워커 · beat 부분)을 기록한다.
- **끝 조건**: 생성물 pytest 실패 0 · 오류 0 · skip 0(VD-7) · 변형 수집 7파일.

### 조각 ③ Dockerfile · compose(이미지 관문)

- **입력**: D18 · D19 · UD-1 결정.
- **산출**: `template/Dockerfile.jinja` · `Dockerfile.dockerignore.jinja` · `compose.dev.yml.jinja` · `compose/dragonfly-dev.acl.jinja`.
- **검증**: 노드 ID로 gen-6 · 33 · 34 · 35(〔X5〕) · VD-T072-5 · 6 · 7 · 8 · 16(compose 부분).
- **끝 조건**: 이미지 4관문 초록 · `docker ps -a`에 스모크 컨테이너 0.

### 조각 ④ deploy/base + CI 배선

- **입력**: D20 · D22.
- **산출**: `template/deploy/base/*.jinja` · ci.yml(test · kubeconform job) · kubeconform-deploy.sh(주석 · 문구) · kubeconform-deploy.tests.ps1(static-6 · 새 static · r-1) · 계약 · 규칙 보정 C1–C28.
- **검증**
  - 전체 하네스 `uv run --directory templates/django-pod --locked pytest -q`: 전부 통과, 종료 0, 총수 = 173 + 추가분.
  - `pwsh -NoProfile -File tests/scripts/kubeconform-deploy.tests.ps1`
  - `pwsh -NoProfile -File tests/run-all.ps1`
  - Git Bash로 `bash scripts/ci/kubeconform-deploy.sh --generated <root>/apps/sample-pod --generated <root>/variants/no-celery/apps/sample-pod --generated <root>/variants/no-admin/apps/sample-pod`: PASS.
  - packages/events vitest(sch-23은 events-compat 블록만 본다 — 영향 없음 확인).
  - VD-T072-19: 생성 deploy/base를 platform-gitops 임시 복제본(커밋 · push 없음)의 `apps/sample-pod/base`로 복사해 `tests/validate.sh` 검사(1 · 3 · 3.5 · 4a · 11 · 13)를 돌리고 PASS 줄을 기록한다(〔X31〕).
- **끝 조건**: 위 전부 초록. push(첫 CI 실행 = VD-T072-CI)는 사용자 확인 뒤에 한다(T067 선례).

조각마다 리뷰 2렌즈(A 완전성 · B 실패 양상)를 돌린다. 학습 로그는 `content/tmp/003-t072/<날짜>.md`(규칙 content.md)에 남긴다.

---

## 6. VD 목록

### T072 안에서 실측

- **VD-T072-1** copier: 따옴표 판 · StrictUndefined · validator 거부 문구 · 조건부 파일 이름(Windows 체크아웃 포함) · `{% raw %}` · `_exclude` · 답변 파일.
- **VD-T072-2** 생성 잠금이 고른 판: kombu 5.7.0 강제 · celery 5.6.3 · Django ≥ 6.1.3 · psycopg 3.3.8 · ninja 1.7.0 · pydantic-settings 2.16.x · sentry-sdk(숙성 · 범위 `<3` — bn:3554 · 〔X14〕) · PyJWT(2.15.1이 아니면 dc auth 계약 시험을 그 판으로 재실행).
- **VD-T072-3** django-migration-linter 6.0 × Django 6.1.3: `lintmigrations` 동작 · `MIGRATION_LINTER_OPTIONS` 키 이름 · RunSQL(0001 · rls_policies) 처리 · DB 필요 여부.
- **VD-T072-4** Celery 5.6.3 + kombu 5.7.0 + Dragonfly(`resetchannels` · `~<pod>:*` · global_keyprefix · 원격 제어 끔): NOPERM 없이 작업 실행(VD-T066-3의 T072 몫).
- **VD-T072-5** buildx가 `-f apps/<pod>/Dockerfile` + 루트 컨텍스트에서 `Dockerfile.dockerignore`를 적용하는지(Docker Desktop · CI).
- **VD-T072-6** 첫 sync 레이어의 path 의존 + `--no-editable`: 런타임에 `/src/packages`가 없어도 import된다.
- **VD-T072-7** ghcr `uv:0.12.8-python3.13-trixie-slim` digest가 Hub 인덱스 `6fe190f0…`와 같은지(`docker buildx imagetools inspect`). 런타임 digest의 현재성.
- **VD-T072-8** gunicorn 26.2 `--no-control-socket` · `python:` 설정 · 읽기 전용 루트 기동.
- **VD-T072-9** pydantic-settings: NoDecode · hide_input_in_errors · case_sensitive(Windows).
- **VD-T072-10** Ninja 1.7.0: 루트 장착 · `openapi_url` · 처리기 · docs 끔.
- **VD-T072-11** `staticfiles serve(insecure=True)` admin 정적.
- **VD-T072-12** `LOGGING_CONFIG None`: 중복 0 · django.request JSON.
- **VD-T072-13** 실제 워커 하위 프로세스(D14): Windows에서 solo pool · 내장 beat 기동 · SIGTERM 종료 · 정리(〔X23〕).
- **VD-T072-14** `0001_app_role_grants` on PG 18.6(기본 권한 · REVOKE).
- **VD-T072-15** migrate 프로필이 SECRET_KEY 없이 migrate.
- **VD-T072-16** Celery 워커 배너 억제 옵션(`--quiet` 위치) · 내장 beat + solo가 읽기 전용 루트에서 기동(가능하면 compose).
- **VD-T072-17** (UD-2 B일 때) `exclude-newer = "3 days"` TOML 상대값 수용 · `--locked` 안정 · 하한 핀과의 해석.
- **VD-T072-18** Windows 경로 길이(짧은 루트 · 조각 ① 시작).
- **VD-T072-19** gitops 검사 거울: 생성 deploy/base를 platform-gitops 임시 복제본에 넣고 `tests/validate.sh`(검사 1의 ESO 2.10.0 CRD 파생 스키마 포함)를 돌린다 — 모노레포 하네스 · kubeconform은 ES를 `-ignore-missing-schemas`로 건너뛴다(〔X31〕).
- **VD-7**(T065) 생성물 testcontainers의 Windows 동작.
- **VD-T072-CI** push 뒤 첫 CI(test job Docker · arm64 · 이미지 pull · ac-24h).

### T075 이후 라이브로 넘김

- **VD-L1** 첫 배포 hook 순서(`-migrate` ES hook이 Healthy가 된 뒤 Job · 추론의 확인) + BeforeHookCreation 삭제 전파와 Secret GC → 재생성 → Job 시작 순서 관찰(〔X26〕).
- **VD-L2** POD_IP 프로브가 400 없이 통과(VD-T066-4 · VD-T071-3).
- **VD-L3** UID 10001 + PSA restricted 기동.
- **VD-L4** ESO v2 `trimSuffix`(실패하면 대체안).
- **VD-L5** startup_check 재시도 창 vs netpol 경합.
- **VD-L6** CNPG app role로 `check_rls --require-rls-role` 통과(T068 잔여).
- **VD-L7** 실제 Dragonfly에서 Celery(VD-T066-3).
- **VD-L8** keepalives · tcp_user_timeout의 효과.
- **VD-L9** Traefik `/health` Exact · Prefix(T076 단언).
- **VD-L10** Reloader 롤아웃(Secret · CA 변경).
- **VD-L11** Alloy 두 포트 스크레이프(T098).
- **VD-L12** GHCR Public pull(T074).
- **VD-L13** Kafka SASL_SSL + CA 마운트 접속 · relay 치명 오류 타이밍(T069 인계).
- **VD-L14** CSRF_TRUSTED_ORIGINS · 사람 admin(T084).
- **VD-L15** kustomize JSON6902 `op: test`가 ES 인덱스 패치 앞에서 동작한다(어긋나면 렌더 실패 · 〔X30〕).
- **VD-L16** T068 라이브 잔여 둘: superuser 소유 확장 멤버 제외 양성(pgvector) · 멤버십 양성(임시 LOGIN role + `GRANT <pod>_owner` → 위반 → DROP · 〔X15〕).
- **VD-L17** web preStop sleep(K3s 1.36 `sleep` 동작) · 롤링 중 BFF 503 0(〔X29〕).
- **VD-L18** 실제 overlay 값으로 클러스터 교차 규칙 통과(dev · prod — 〔X8〕).

---

## 7. 인계

- **T073**
  - 먼저 루트 `pyproject.toml` members에서 `apps/identity-admin`을 빼고 `exclude = ["apps/*", "templates/*"]`를 둔다. 아니면 `_tasks: uv lock`이 루트 잠금을 고친다(〔조사 tooling U1〕).
  - 저장소 루트에서 생성: `copier copy --trust --defaults --overwrite --data pod_name=identity-admin --data 'owns_events=[session.revoked, user.registered, tenant.created]' templates/django-pod apps/identity-admin`(상대 경로 → `_src_path`에 로컬 절대 경로가 남지 않는다). T066 파일 3개는 템플릿에 없는 이름이라 보존된다.
  - 확장:
    - `SECRET_SETTINGS`(+AUTHENTIK_API_TOKEN · AUTHENTIK_WEBHOOK_SECRET · OPENFGA_PRESHARED_KEY)
    - `IN_CLUSTER_URL_SETTINGS`(+AUTHENTIK_API_URL · OPENFGA_API_URL)
    - `PLACEHOLDER_EXEMPTABLE`(나가는 쪽 자격 — T075와)
    - AUTH_EXEMPT = 헬스 + `/webhooks/authentik` · ACCESS_ONLY · TENANT 확장
  - ES data[]는 index 7 뒤에만 덧붙인다(webhook secret · openfga · api_token).
  - ConfigMap `AUTHENTIK_WRITES_ENABLED` · beat 3종 · OpenAPI 스냅샷 의도 갱신 · Celery Sentry 여부(T100) · K9 requires-python.
  - T066 test_api.py 독스트링 정합: 가정 ⑥의 「래퍼의 `os.environ.setdefault`」 → 덮어쓰기(〔X24〕) · 「설정은 비밀 값의 형식 · 길이를 검사하지 않는다」 → SECRET_KEY만 W009 기준 검사(64자 난수는 늘 통과 · 〔X21〕).
- **T074**: build-arg `APP_VERSION` · `APP_GIT_SHA`(=`github.sha`) · 이미지 이름 = base `image:` 문자열 · arm64 · dev bump는 digest 줄만 제자리 교체(`kustomize edit` 재작성 주의 — 〔조사 shape F18〕) · GHCR Public.
- **T075**
  - base는 그대로 복사한다(파일 이름 1:1).
  - overlay 패치:
    - namespace · images digest · Ingress `/spec/rules/0/host`
    - ConfigMap(ENV prod · ALLOWED_HOSTS svc + m2m(+admin) · ADMIN_HOST · ACCESS_AUD_M2M/ADMIN · ACCESS_EXPECTED_CN(Client ID — 문면 web-bff-<env>는 낡음) · KAFKA_USERNAME `<pod>` · FORCE_SCRIPT_NAME · OTEL 엔드포인트(스킴 포함) · AUTH_ACTOR_SUB(VD-1))
    - ES prod(store `vault-prod` · data[i].remoteRef.key `prod/…` — 표 순번)
  - prod admin Ingress와 stripPrefix Middleware 위치.
  - 머지 전 kv 시드: db · kafka · dragonfly · authentik issuer/jwks_url 실값 · sentry dsn 빈 값 · `kv/{env}/django/<pod>` secret_key — data-model §8 행 C27.
  - 게이트 2 면제 env · VD-L1–L13.
  - validate lint에 env 위생 거울 · templateFrom 금지 · cnpg README 문장(G7) · contracts gitops-repo 보정 확인.
  - ES 인덱스 replace 앞 `op: test`(〔X30〕) · hook ES 운영 성질 넷(전체 수동 Sync · health 밖 직접 판정 · 멈춘 operation terminate · owner Secret 재생성 — 〔X26〕)을 런북에 · overlay ConfigMap 값이 클러스터 교차 규칙(ENV · KAFKA_USERNAME · DB 사용자 · svc 이름)을 만족하는지 머지 전 렌더로 확인(〔X8〕) · SECRET_KEY 시드 규칙(CSPRNG ≥ 50자 · dev ≠ prod · 화면 · argv 노출 0 — 〔X21〕) · VD-L15–L18.
- **T076**: 하네스 `JT_SAMPLE_POD_ROOT=tests/fixtures/generated` → `tests/fixtures/generated/apps/sample-pod`(문면 경로 편차 — 계약:5). 증거는 pytest 출력.
- **T084**: 사람 admin 경로(O1 (a)/(b)) · CSRF_TRUSTED_ORIGINS 실측 · 슈퍼유저 생성 절차(app role로 auth_user 쓰기 가능) · admin 호스트 traceparent.
- **T097**: 자원 표(D20) · 쿼터 계산 · app role connectionLimit(gthread 4 + 헬스 스레드 · relay · celery) · web preStop 5 s의 롤링 시간 영향(〔X29〕).
- **T114**: relay 조용한 발행 중단의 두 원인(ACL · 설정) 가운데 설정 쪽은 클러스터 교차 규칙(〔X8〕)이 기동 실패로 앞당긴다. 남는 ACL 쪽은 OutboxOldestPending 경보가 맡는다(DEP-07).
- **T098**: 한 pod 두 메트릭 포트(9100 · 9464) 선택 방식(portNumber 어노테이션) · 원문 stderr 줄(gunicorn · celery 배너 · librdkafka) · OTEL 엔드포인트 값.
- **T100**: SENTRY_DSN kv · web만 Sentry · relay · celery 오류는 로그만(CeleryIntegration을 쓰려면 dc configure_sentry 개정).
- **T081 · T085**: AUTHENTIK_AUDIENCE = pod 이름 전제 · DRAGONFLY_URL 끝 점 FQDN 검토(bn:2316-2318 — kv 형식은 T057 소유라 T072는 바꾸지 않는다).
- **CI**
  - ac-24h flake 감시(bn:2664)
  - uv 판 정렬(UD-1)
  - Renovate: Dockerfile.jinja는 기본 패턴에 걸린다. compose.dev.yml.jinja · conftest 상수 digest와 pep621 `pyproject.toml.jinja`(fileMatch `pyproject.toml$` — 템플릿의 보안 하한 Django ≥ 6.1.3 등)는 걸리지 않는다 → 수동이거나 fileMatch 추가(〔X32〕).
- **dc**(보고만): PyJWT 상한 `<2.16` 검토 · hatchling build-system 미고정(저장소 전체 · T116 후보).

---

## 8. 사용자 결정 후보

### UD-0 독립 uv 프로젝트(T065 사용자 확인 항목) — 종결(〔X6〕)

bn:757의 「사용자 확인 항목(T072 착수 전 되돌릴 수 있음)」은 2026-11-03 14:07 KST 사용자에게 「이의가 없으시면 그대로 · 바꾸시려면 T072 전에만」으로 고지했고(copier update 미지원과 함께) 이의가 없었다(㉙). 결정은 독립 프로젝트 그대로다. 최종 보고에 이 고지 기록을 적는다.

### UD-1 uv 판

문면과 계획의 편차이면서 공급망 사안이다. 계획 · ci.yml 핀은 0.12.8(ci.yml:316,339)이고 GHSA-hq85 High에 걸린다(⑯).

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A 0.12.8 유지 + 완화(이미지 빌드 `UV_SYSTEM_CERTS=1` · 해시 잠금 설치) | 계획 · CI와 일치, 편차 없음 | 권고 미패치 상태로 생성 · 빌드 | 잠금 생성 시점(T073 · 하네스)의 MITM은 해시로 막지 못한다. 시스템 CA 저장소에 그 CA가 남아 있으면 완화가 무효다. |
| B 0.13.x(≥ 0.13.4, 예 0.13.7)로 한 변경에서 올림(ci.yml lint · test · kubeconform setup-uv + 템플릿 빌더 태그 · digest + 로컬 uv) | 권고 해소. Renovate가 낼 bump를 첫 소비자(템플릿 Dockerfile)에서 한 번에 소화 | 계획 핀 편차(report.md) · 새 digest 실측 | 루트 · dc · 하네스 uv.lock이 새 판에서 `--locked` 재작성을 요구할 수 있다(VD). |
| C B + 빌더를 런타임 python digest로 · `COPY --from=ghcr.io/astral-sh/uv:<판>@sha256 /uv /uvx /bin/` | B의 장점 + 빌더 · 런타임 Python 판 동일 | 문면 빌더 이미지 꼴에서 더 벗어난다 | 이미지 핀 두 개를 관리해야 한다 |

**권고: B.** GHSA-2cv4(0.12.7–0.12.17 Windows)도 피한다. 로컬 uv는 0.12.6이라(㉗) B면 로컬도 올린다(`uv self update` — 사용자 PC의 도구 변경이라 실행 전에 확인한다). **상태: 사용자 결정 대기 — 조각 ③(Dockerfile) 전에 받는다.** 조각 ① · ②는 판과 무관하게 진행한다.

### UD-2 Python 숙성 창

공급망 사안이다. T065 B-6 보류(bn:777) · pnpm은 3일이다(〔조사 tooling U8〕).

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A 없음 | 단순 | 2–4일 된 판이 잠금에 들어간다(kombu 5.7.0 · Django 6.1.3 · psycopg 3.3.8) | 손상 릴리스 유입 창 |
| B 생성 pyproject `[tool.uv] exclude-newer = "3 days"` | npm과 대칭 · 생성 시점 방어 | VD-T072-17 · 하한 핀과 충돌하면 해석 실패(psycopg 하한은 `!=3.3.7`로 이미 완화) | 창 안의 긴급 보안판(필요하면 그 패키지만 `exclude-newer-package`) |
| C 하한 · 제외 핀만(D4 그대로) | 실측 불필요 | 일반 방어가 아니다 | — |

**권고: B.** VD-T072-17이 통과해야 하고, 실패하면 C로 간다. 루트 · dc · 하네스 잠금에도 같은 창을 둘지는 저장소 전체 정책이라 이 결정과 따로 다룬다(T065 B-6 — T116 후보). **상태: 사용자 결정 대기 — 조각 ②(첫 생성 잠금) 전에 받는다.**

### (결정) django-ninja 판 — 사용자 결정이 아니다

계약 핀(`==1.7.0`)을 따른다 — 편차가 없어 사용자 결정 대상이 아니다. 보안성 수정이 있는 1.7.2/1.7.3은 아래 표대로 T073 착수 때 다시 본다(report 관찰).

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A 계약 그대로 `==1.7.0` | 계약 · 하네스 · T066(VD-T071-1 PASS)과 일치 | 1.7.2/1.7.3 수정(중첩 라우터 auth · 응답 하위 클래스 필드 누출)이 없다 | 템플릿은 Ninja auth를 쓰지 않고 응답이 스키마 · dict라 직접 영향은 작다(추론) |
| B 계약 · 하네스를 개정해 `==1.7.3` | 수정 포함 · dc 시험 판과 일치 | 계약 · 하네스 · T066 가정 재검 | T066 표면 영향 미확인 |

**권고: A**를 T072에 적용하고 report 후보로 남긴다. T073 착수 때 다시 정한다.

### 사용자 결정이 아닌 것(설계가 정한다)

- **gunicorn**: plan 단계 research 기준 템플릿에 있다(㉘ — 계약:77 스택 열거와도 맞다 · 〔X12〕).
- **숫자 UID**: 계약 의도(non-root)를 강화하는 보정이다.
- **WhiteNoise 미채택**: 새 의존을 피한다.
- **사람 admin 경로 미룸**: 계약이 미결로 적었고, 닫힌 쪽으로 끝난다.
- **게이트 2의 identity-admin 면제 목록**: T073 · T075가 정한다.

---

## 9. 위험과 이 설계가 확인하지 못한 것

- **생성 시점 `uv lock`**: PyPI 장애이거나 오프라인이면 tool-6 · gen-* · T073 생성이 FAIL한다(skip이 아니다). 해석이 날짜에 따라 달라진다(UD-2로 완화). hatchling 빌드 백엔드는 잠금 · 해시 밖이다.
- **celery 5.6.3 × kombu 5.7.0**: 상류가 짝으로 낸 판이 아니다(VD-T072-4). django-migration-linter는 Django 6.1 분류자가 없다(VD-T072-3).
- **Argo · ESO 동작(라이브 미실측)**: hook 완료가 health 기반이라는 점(VD-L1)과 ESO `trimSuffix`(VD-L4)는 추론이다. `-migrate` ES hook은 Vault/ESO 장애 때 배포 자체를 막는다(닫힌 쪽).
- **변형 두 벌(no-celery · no-admin) 생성물 시험은 수집만 한다.** 실행 경로는 `manage.py check` · settings 하위 프로세스(celery 미import 단언 포함)로만 확인한다(〔X10〕).
- **봉투 꼴 시험의 질**: 하네스는 표식만 본다(gen-27). 시험 내용의 질은 리뷰가 지켜야 한다.
- **런타임 특성**
  - gunicorn 워커 하나 × 4스레드(용량은 replicas로 늘린다).
  - gunicorn · celery 원문 줄이 남는다.
  - has_celery pod는 모든 프로세스가 celery를 import한다(메모리 +수 MB).
  - relay 레지스트리에 `denylist_lookup_seconds`가 0값으로 나타난다(auth import · 무해).
  - 롤링 중 beat가 둘이 될 수 있다(멱등 작업).
- **Ninja 1.7.0 소스는 읽지 못했다**(1.7.3을 읽음). 처리기 동작이 같다는 것은 가정이다(VD-T072-10).
- **이름 결합**: DB · role 이름 규칙(`<db>_app` · `_owner`)이 바뀌면 GRANT 마이그레이션 · Job 스크립트 · trimSuffix가 함께 깨진다(크게 실패한다).
- **쿼터 여유**는 pod 하나 기준이다. SP-2 pod가 늘면 limits가 4Gi에 가까워진다(T097).
- **Windows 하네스**: arm64 에뮬레이션 아래 이미지 스모크 · 기동 시간(gen-34 대기 상한 60 s)과 경로 길이.
- **`insecure=True` 정적 서빙**: 운영에서 쓰는 것은 검토가 필요한 선택이다. admin 호스트 · GET/HEAD · finders 범위로 한정했다.
- **POD_IP Host 허용**: 클러스터 안 호출자가 쓸 수 있는 호스트가 하나 는다. 인증 계층이 막는다고 보고 받아들였다.
- **이 설계가 확인하지 못한 외부 사실**: ghcr digest 동일성 · gunicorn 플래그 판 · Celery `--quiet` 위치 · pydantic-settings NoDecode 세부 · Docker의 `Dockerfile.dockerignore` 적용. 전부 VD로 넘겼다.
- **클러스터 교차 규칙의 이름 결합**(〔X8〕): KafkaUser · DB role · 네임스페이스 이름 규칙이 바뀌면 모든 pod 기동이 크게 실패한다(닫힌 쪽 — 규칙과 계약을 함께 고친다).
- **실제 Celery 워커 시험**(〔X23〕)은 Windows에서 타이밍에 민감할 수 있다 — 측정 기록으로 내리지 않고 대기를 고친다.
- **preStop 5 s**(〔X29〕)는 롤링마다 pod 종료를 5 s 늦춘다.

---

## 10. 설계 비판 반영표(2026-11-07 · 컨트롤러)

비판 A(계약 · 하네스 · 인계) 18건과 B(보안 · 운영 · gitops) 16건, A의 덧붙인 메모 셋을 X1–X32로 묶었고, 설계 커밋 직전 컨트롤러 실측 하나를 X33으로 더했다. 같은 내용은 하나로 합쳤다(A-2 = B-2 · A-7 = B-3 · A-9 = B-13). 기각한 것은 없고, 셋은 다른 방법으로 닫았다(X8 · X13 · X24 — 판정 칸).

| X | 비판 | 심각도 | 판정 | 반영 자리 |
|---|---|---|---|---|
| X1 | A-1 hook_order가 기존 변이 render-09와 교차 | medium | 채택 | D21 기존 변이 2건 수정 · 교차 행렬 · `_CRON_TABLE` 완전성 · §5 조각 ① |
| X2 | A-2 · B-2 init startup-check · Kafka CA 마운트 · 9100 · limits 단언 없음 | medium | 채택(검사 하나 `runtime_wiring`) | D21 gen-36 · D6 `conf.KAFKA_CA_FILE` · D17 CA 경로 대조 |
| X3 | A-3 형제 없는 배치에 생성 · 실행 | medium | 채택 | C1 · 규칙 §Template · D21 변형 · D22 |
| X4 | A-4 Windows `os.execv` 거짓 통과 | medium | 채택 | D20 Job 스크립트 · D17 · C20 · ㉛ |
| X5 | A-5 `-k` 부분 문자열 과다 선택 · 기대 빨강 목록 | medium | 채택 | §5 노드 ID 선택 · 기대 결과 대조 |
| X6 | A-6 T065 사용자 확인 항목 미종결 | medium | 종결(2026-11-03 고지 · 이의 없음 기록 인용) | §8 UD-0 · ㉙ |
| X7 | A-7 · B-3 configure_broker가 migrate 프로필에서도 돈다 | medium(B) | 채택 | D5 migrate 프로필 · D7 ④ · D14 · D17 · C21 |
| X8 | B-1 base ConfigMap dev 값이 prod overlay에서 빠져도 막는 장치 없음 | medium | 채택 (b)안(POD_NAMESPACE 교차 규칙). (a) 자리값안은 쓰지 않는다 — base = dev 값 원칙을 지키고 (b)가 같은 실패를 기동에서 잡는다 | D5 · D15 · D20 · D21 runtime_wiring · C8 · C17 · VD-L18 · §7 T075 · T114 |
| X9 | A-9 · B-13 정적 경로 탈출 기대값 오류 | low | 채택(400 기대 — 404로 바꾸는 처리는 두지 않는다) | D10 · ㉜ · C23 |
| X10 | A-10 상위 집합 venv · 흔한 조합 미수집 | low | 채택(변형 두 벌 + celery 미import 단언) | D21 · D22 · C24 |
| X11 | A-11 커밋 규칙 · 닫힌 T065 절 갱신 | low | 채택 | §1 · D21 가정 변경 · §5 |
| X12 | A-12 gunicorn 근거 | low | 근거 보강 — research 기준 템플릿에 있어 사용자 결정이 아니다 | ㉘ · D11 · §8 |
| X13 | A-13 ENV=test 하나가 통제 셋을 늦춘다 | low | 다른 방법으로 닫음 — 래퍼로 옮기지 않고 X8이 클러스터 안 ENV=test를 거부한다(로컬 compose 실행도 같은 settings를 쓴다) | D5 · D6 · C14 · C17 |
| X14 | A-14 VD 누락 · 미배정 · Sentry 스모크 | low | 채택(Sentry 스모크는 두지 않는다 — T100 소유) | §6 VD-2 · 13 · 18 · §5 배정 · D17 |
| X15 | A-15 transaction=True · T068 라이브 잔여 | low | 채택 | D12 · VD-L16 |
| X16 | A-16 로컬 개발 경로 | low | 채택(compose 부트스트랩은 README 절차 — 비밀 0) | D19 · C5 |
| X17 | A-17 SECRET_KEY kv 경로 소유 | low | 채택 | D20 ES 표 · C27 · §7 T075 |
| X18 | B-6 env 위생 계산 · 목록 빈틈 · assert | low | 채택(런타임 거부는 두지 않는다 — T071과 같은 방어선) | D21 env_hygiene · D18 gen-33 · D7 · ㉟ |
| X19 | A-18 REQUIRED_FILES 기각 근거 오류 | low | 근거 정정 | D3 · D21 기각한 대안 |
| X20 | A-8 계약 보정 누락 · 번호 중복 | low | 채택 | §4 C29(번호 바꿈) · C30 · C31 · C28 · 규칙 §Logging |
| X21 | B-8 SECRET_KEY 강도 | low | 채택 | D5 · C17 · C27 · §7 T073 · T075 |
| X22 | B-4 이미지 스모크가 web만 · A 메모 대기 60 s | low | 채택(스모크 넷 · 대기 180 s) | D21 gen-34 |
| X23 | B-7 실제 워커 시험이 선택 | low | 채택(필수 · 하위 프로세스) | D14 · D17 · VD-T072-13 |
| X24 | B-9 래퍼 setdefault가 셸 env를 쓴다 | low | 다른 방법으로 닫음 — 실패 대신 덮어쓰기(T066 자식 기동과 호환 · ㉚) | D5 · §7 T073 |
| X25 | B-12 최종 실패 출력 · URI 오류 문구 | low | 채택 | D5 URL · D7 startup_check · D20 스크립트 · D21 gen-34 ④ |
| X26 | B-5 hook ES의 추적 밖 성질 · A 메모 operation 정지 | low | 채택 | D20 · C20 · VD-L1 · §7 T075 |
| X27 | B-10 dockerignore 재제외 | low | 채택 | D18 · C3 |
| X28 | B-14 consumes_events 정규식 | low | 채택 | D2 |
| X29 | B-16 preStop 없음 | low | 채택 | D20 · D21 pod_lifecycle · C8 · VD-L17 · §7 T097 |
| X30 | B-11 ES 인덱스 replace의 조용한 어긋남 | low | 채택 | D20 · D19 README · C28 · VD-L15 · §7 T075 |
| X31 | B-15 gitops 전용 검사를 T075 전에 한 번도 안 돈다 | low | 채택 | VD-T072-19 · §5 조각 ④ |
| X32 | A 메모 Renovate가 `.jinja`를 못 본다 | — | 채택 | §7 CI |
| X33 | 컨트롤러 실측(설계 커밋 전 gitleaks) — 숫자가 든 자리값(`PLACEHOLDER-T075`)을 generic-api-key가 잡는다 · 숫자 없는 꼴은 통과 | — | 채택 | D20 ConfigMap 값 · §5 공통 환경 규칙 |

- 비판이 통과로 확인한 것(그대로 둔다): base 단독 렌더의 gitops 검사 통과 예상 · Vault `eso-dev` 정책 범위 · AppProject dev 허용 · PSA restricted · 쿼터 계산 · NetworkPolicy 포트 · 첫 배포 교착 해법 · 이미지 참조(비판 B extra) · copier unsafe 판정 · `client_config()`의 CA 파일 무검사 · relay metrics 지연 import · ps1 static-4 범위 · events sch-23 범위(비판 A extra §3).
