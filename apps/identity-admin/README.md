# identity-admin

Session revocation, tenant membership and Authentik webhook intake

`templates/django-pod`(copier)로 생성한 Django pod다. 계약의 정본은 `specs/003-platform-foundation/contracts/pod-template.md`,
규칙은 `.claude/rules/django-pod.md`다. 공용 코드는 `packages/django-common`에 있고 pod에 복사하지 않는다.

<!-- identity-admin(T073) — 이 절 전체가 손 수정 ⑮다(아래 「재생성」의 손 수정 표). -->
## identity-admin

세션 폐기(`/sessions/revoke` · Authentik 웹훅 · 관리 명령) · 폐기 확인(`/session/check`) · 테넌트 소속(`/tenants/me`) · Celery 주기 작업
(30 s 무조건 재적용 · 폐기 로그 purge · Authentik logout 이벤트 대조) · Authentik 세션 삭제 위임을 맡는 pod다. 계약의 정본은
`specs/003-platform-foundation/contracts/identity-admin-api.md`(엔드포인트 · 주기 작업 · 관리 명령 · 전용 설정 · 관측)와
`contracts/denylist.md`(키 스키마 · 쓰기 규약 · ACL)다. 템플릿이 만든 아래 절들은 생성 그대로이고, identity-admin이 더하거나 바꾼
것은 이 절과 「재생성」의 손 수정 표에 있다.

이 pod의 celery 컨테이너(아래 「프로세스」 표의 celery 행)는 30 s 무조건 재적용도 돌린다 — 그 컨테이너가 멈추면 폐기 키(`revoked:*` ·
세션 하한)의 복구가 멈춘다(그 행에 적힌 「dead outbox purge」만이 아니다 · 프로브 · 지표가 없어 멈춰도 재시작되지 않는다).

### 전용 설정

identity-admin 전용 설정 7개의 정본은 이 표다 — `identity_admin/conf.py` 모듈 머리 독스트링의 필수 목록 · 교차 규칙 목록은 템플릿
문면 그대로라 이 일곱을 싣지 않는다(코드의 정본은 `RuntimeEnv` 필드와 `_runtime_problems`의 `identity-admin(T073)` 블록이다).

| 이름 | runtime | 출처(운영) | 값의 꼴 · 규칙 |
|---|---|---|---|
| `AUTHENTIK_API_TOKEN` | 필수 · 비밀 | `<pod>-env`(kv `{env}/authentik/identity-admin` · property `api_token`) | 공백 없는 출력 가능 ASCII(`!`–`~`) · 관리 API `Authorization: Bearer` · 자리값 면제 가능 |
| `AUTHENTIK_WEBHOOK_SECRET` | 필수 · 비밀 | `<pod>-env`(kv `{env}/authentik/webhooks/identity-admin` · property `secret`) | 공백 없는 출력 가능 ASCII · **32자 이상** · 웹훅 HMAC 공유 비밀 · 자리값 면제 불가 |
| `OPENFGA_STORE_ID` | 필수 | `<pod>-env`(kv `{env}/openfga/store_id` · property `store_id`) | 꼴(`[A-Za-z0-9_-]{1,64}`)은 경로에 넣는 호출 시점에 본다(`seed_tenant`는 DB 앞 2단계에서도 본다) · 자리값 면제 가능 |
| `OPENFGA_PRESHARED_KEY` | 필수 · 비밀 | `<pod>-env`(kv `{env}/openfga/preshared` · property `key`) | 공백 없는 출력 가능 ASCII · OpenFGA `Authorization: Bearer` · 값은 `kv/platform/openfga/preshared`와 같다 · 자리값 면제 가능 |
| `AUTHENTIK_API_URL` | 선택(기본 `http://authentik-server.identity.svc:9000`) | 기본값(ConfigMap에 키 없음 — 포트가 바뀌면 overlay가 키를 더한다) | 아래 「서비스 기준 URL」 |
| `OPENFGA_API_URL` | 선택(기본 `http://openfga.identity.svc:8080`) | 같음 | 아래 「서비스 기준 URL」 |
| `AUTHENTIK_WRITES_ENABLED` | 선택(기본 거짓) | ConfigMap(base = dev `"false"` · prod overlay `"true"`) | 따옴표 있는 `"true"` · `"false"`만 쓴다 |

- **비밀 셋**(`AUTHENTIK_API_TOKEN` · `AUTHENTIK_WEBHOOK_SECRET` · `OPENFGA_PRESHARED_KEY`): 빈 값과 끝 줄바꿈 · CR · 공백 · 탭 · 제어 문자 ·
  비ASCII(보이지 않는 글자 포함)가 든 값은 기동 실패다(설정 이름만 싣는다). Vault 값에 끝 줄바꿈을 넣지 않는다 — 끝 줄바꿈이 든 토큰은
  HTTP 클라이언트가 헤더 값을 예외 문구에 싣고, 끝 줄바꿈이 든 웹훅 비밀은 모든 웹훅을 401로 만든다.
- **서비스 기준 URL**(`AUTHENTIK_API_URL` · `OPENFGA_API_URL`): `http(s)://호스트[:포트][/]` 꼴만 받는다 — 호스트는 ASCII 글자 · 숫자 ·
  `.` · `-`뿐 · 포트는 있으면 1–65535 · 경로는 빈 값이나 `/`뿐(뒤에 `/api/v3/…` · `/stores/…`를 붙인다). 사용자 정보 · 쿼리 · 조각 ·
  퍼센트 인코딩(urllib가 풀어서 접속한다) · 역슬래시 · `;` · 빈 포트 · 포트 0 · IPv6 리터럴은 기동 실패이고, 호스트가 공개 도메인
  `joshuatech.dev`(하위 포함)이어도 기동 실패다(`IN_CLUSTER_URL_SETTINGS`에 둘을 더했다 — pod는 svc DNS만 부른다).
- **쓰기 플래그**(`AUTHENTIK_WRITES_ENABLED`): 빈 값 · 앞뒤 공백이 든 값은 기동 실패다. 해석이 pydantic bool이라 `yes` · `on` · `1`도
  참으로 읽히므로 ConfigMap은 `"true"` · `"false"` 두 문자열만 쓴다(따옴표 없는 `false`는 YAML 불린이라 ConfigMap 값이 될 수 없다).
  대상은 Authentik **쓰기** 호출 둘뿐이다 — 세션 삭제 위임과 `seed_tenant`의 그룹 소속 · attribute 쓰기. 읽기(`seed_tenant`의 그룹 ·
  사용자 조회 · 일 1회 대조)는 플래그와 무관하게 한다(대조의 보정은 Authentik 쓰기가 아니라 이 pod의 DB 기록이다).
- **자리값 자격**: 게이트 2의 면제 상수 `PLACEHOLDER_EXEMPTABLE`은 정확히 `AUTHENTIK_API_TOKEN` · `OPENFGA_STORE_ID` ·
  `OPENFGA_PRESHARED_KEY`(나가는 쪽 자격 — 닫힌 상한)이고, env `JT_PLACEHOLDER_EXEMPT`(쉼표 이름 · overlay가 둔다)에도 그 이름이 있어야
  기동한다. 웹훅 비밀 · `AUTHENTIK_JWKS_URL` · `AUTHENTIK_ISSUER`는 면제할 수 없다(들어오는 쪽 검증 값). 자격 값에 `PLACEHOLDER-`가
  있으면 그 외부 호출을 하지 않는다 — 세션 삭제 위임(enqueue 시점과 작업 본체)과 일 1회 대조는 건너뛰고 WARNING
  `authentik.calls_disabled reason=placeholder_credential`을 남기며(`revoke_sessions` 출력은 `delegate=skipped`), `seed_tenant`는
  `CommandError`다. 웹훅 · `/session/check` · `/tenants/me` · 재적용 · `revoke_sessions`의 기록은 나가는 쪽 자격을 쓰지 않아 무관하다.
  위임의 `delegate=skipped`와 그 WARNING은 쓰기 플래그가 참일 때다 — 거짓이면 그 판정이 먼저라 `delegate=off`이고 위임 쪽에는 INFO
  `authentik.revoke_skipped reason=writes_disabled`만 남는다(`revocation._delegate`의 판정 순서: 쓰기 플래그 → 자리값 자격 → 커밋 뒤
  거부 목록 쓰기 결과 · 대조는 읽기라 플래그와 무관하게 WARNING을 남긴다).
- 설정은 요청 · 작업 · 명령 실행 시점에 `django.conf.settings`에서 읽는다(`settings.py`가 대문자 일곱을 노출한다 — import 시점 상수 없음).

### 경로 집합(`identity_admin/settings.py` — 정확 일치)

| 설정 | 값 |
|---|---|
| `AUTH_EXEMPT_PATHS` | `/healthz` · `/ready` · `/health` · `/webhooks/authentik`(HMAC이 대신한다 — 뷰가 서명 검증 앞에서 `request.get_host()`를 부른다) |
| `AUTH_ACCESS_ONLY_PATHS` | `/session/check`(Access JWT · `common_name`만 보고 Bearer · 거부 목록 단계를 건너뛴다) |
| `TENANT_CONTEXT_EXEMPT_PATHS` | 헬스 셋 + `/webhooks/authentik` + `/session/check`(둘 다 Bearer가 없어 테넌트 클레임이 없다) |

기동 단언(`startup._paths`)이 `AUTH_EXEMPT_PATHS` · `AUTH_ACCESS_ONLY_PATHS` ⊆ `TENANT_CONTEXT_EXEMPT_PATHS`를 강제한다. m2m Ingress
허용 경로(`/api` · `/health` · `/session` · `/sessions` · `/tenants`)에는 `/webhooks` · `/healthz` · `/ready`가 없다 — 웹훅은 클러스터 안
svc DNS(`http://identity-admin.jt-<env>.svc/webhooks/authentik` — 끝 슬래시 없이)로만 온다.

### 포트 전제

`AUTHENTIK_API_URL` 기본값의 `:9000`은 Authentik **Service** 포트다 — 차트 기본 Service 포트는 80(→ pod 9000)이라 T080이
`server.service.servicePortHttp: 9000`을 둔다(NetworkPolicy는 pod 포트 9000 그대로). `OPENFGA_API_URL` 기본값은 `:8080`이다. 둘 중
하나라도 바뀌면 그 env의 overlay가 ConfigMap에 그 URL 키를 더한다(base에는 두지 않는다).

### deploy/base 추가분(T075가 gitops로 복사한다)

- ExternalSecret `identity-admin-env` `data[8..11]`(0–7 뒤에 덧붙였다 — 순번은 overlay 인덱스 패치의 인터페이스다 · 다음 새 항목은
  12번부터) + `template.data` 네 줄:

| # | secretKey | remoteRef.key(dev) | property | env |
|---|---|---|---|---|
| 8 | authentik_api_token | `dev/authentik/identity-admin` | api_token | `AUTHENTIK_API_TOKEN` |
| 9 | authentik_webhook_secret | `dev/authentik/webhooks/identity-admin` | secret | `AUTHENTIK_WEBHOOK_SECRET` |
| 10 | openfga_store_id | `dev/openfga/store_id` | store_id | `OPENFGA_STORE_ID` |
| 11 | openfga_preshared_key | `dev/openfga/preshared` | key | `OPENFGA_PRESHARED_KEY` |

- `client_id` · `client_secret`은 매핑하지 않는다(pod에 그 설정이 없다). prod overlay는 8–11의 키도 `prod/…`로 바꾸고, 인덱스 replace마다
  앞에 `op: test`(`path: /spec/data/N/secretKey`)를 둔다.
- ConfigMap `identity-admin-config`에 `AUTHENTIK_WRITES_ENABLED: "false"`(base = dev) 한 키 — prod overlay가 `"true"`로 바꾼다. prod
  overlay가 이 키를 `"true"`로 패치하지 않으면 기동은 되고(기동 게이트 · 렌더 검사 어디에도 걸리지 않는다) 위임 · 시드의 Authentik
  쓰기만 조용히 꺼진다 — T075가 overlay 렌더로 확인한다.
- `env.example`에 일곱 키(필수 넷 · 선택 셋)를 더했다(키만 — 값은 두지 않는다).

### 관리 명령

운영자가 web 컨테이너에서 돈다(runtime 프로필 · app role — 런타임 설정이 필요해 migrate 프로필 · Job으로는 돌지 않는다). 같은
stdout에 `configure_logging`의 JSON 로그 줄이 섞이므로 결과는 명령 이름 접두로 찾는다. `kubectl exec`의 출력은 컨테이너 로그(Loki)에
들어가지 않는다 — 실행 출력 전체를 사건 기록에 남기고, 명령의 폐기 수 · 감사는 DB 행(`reason = admin`)과 `session.revoked` 이벤트로
센다. 실행 전에 네임스페이스를 확인한다 — dev · prod가 한 Authentik을 써 같은 sub가 두 env에 멤버십을 가질 수 있고, 그러면 두
네임스페이스(`jt-dev` · `jt-prod`)에서 각각 돈다(돌지 않은 env의 pod에는 그 sub의 하한이 생기지 않는다 · 출력의 `env=`가 그 실행의
env다). kubectl에는 관리자 kubeconfig를 명령에 직접 적는다(`--kubeconfig <관리자 kubeconfig>` — 빠지면 다른 기본
kubeconfig로 가서 실패한다 · `docs/runbooks/bootstrap.md` 「늦은 시드」의 실측 교훈 · `docs/runbooks/restore-drill.md`와 같은 꼴).

**계정 탈취 대응은 Authentik 사용자 비활성화가 먼저**이고 `revoke_sessions`는 그다음이다 — 이 명령의 세션 하한이 막는 것은 폐기 전에
만든 BFF 세션이고, Authentik 로그인 세션이 남은 기기는 SSO로 재인증 없이 새 BFF 세션을 얻는다(비활성화가 Authentik 세션과 Access ·
Refresh · Device 토큰을 지운다 — API 토큰 · app password는 지우지 않으므로 재활성화 전에 지운다 · 재활성화 전에는 비밀번호 재설정 ·
MFA 장치 · 연결된 소스(소셜 로그인) · 이메일 변경 여부도 본다 — 공격자가 건 연동이 남으면 비밀번호와 MFA를 바꿔도 재활성화 뒤 그
길로 들어온다 · 순서와 절차는 런북 T114).

```bash
kubectl --kubeconfig <관리자 kubeconfig> -n jt-<env> exec deploy/identity-admin -c web -- python manage.py revoke_sessions --sub <sub>
```

- 사용자 단위 관리자 폐기다(`sid` NULL 행 · `revoked:sub` + 세션 하한 키 · Authentik 세션 삭제 위임 · reason `admin` · `tenant_id` =
  `--sub`의 `TenantMembership`). 출력은 `revoke_sessions:`로 시작하는 줄 하나다(sub · 토큰 · URL을 싣지 않는다):
  `revoke_sessions: OK env=<env> id=<uuid> nbf=<int> expires_at=<ISO 8601 UTC> denylist=<값> delegate=<값>`.
- `denylist` 값: `ok`(거부 목록 키를 썼다) · `skipped`(쓸 키가 없다 — 남은 수명 1 s 미만) · `failed`(쓰기 실패) · `unreachable`
  (Dragonfly 연결 실패 · 시간 초과) · `none`(커밋 뒤 쓰기가 채우지 못했다) — `ok` · `skipped` 밖이면 머리말이 `PARTIAL`이다.
- `delegate` 값: `enqueued`(Authentik 세션 삭제 위임을 보냈다 — 삭제 결과는 워커 로그 `authentik.revoke_done`) · `off`(쓰기 플래그
  거짓) · `skipped`(자리값 자격이거나 거부 목록 쓰기가 연결에서 실패) · `failed`(위임을 넣지 못했다) · `none`(채워지지 않았다).
  **`delegate=enqueued`만이 위임을 보냈다는 뜻이다** — 그 밖(`off` · `skipped` · `failed` · `none`)이면 Authentik 세션은 그대로이고,
  머리말이 `OK` · 종료 0이어도 같다.
- 종료 코드: 0 = `OK`(`delegate=failed`도 0 — 출력으로 드러난다) · **3 = `PARTIAL`**(행은 기록됐고 거부 목록 쓰기가 실패했다 — 60 s 뒤
  `revoked:sub`와 세션 하한 키가 생겼는지 본다) · 1 = 기록하지 않음(멤버십 없음 · 문자 규칙 위반 · `nbf`가 DB 시계 + 301 s를 넘음 · 바깥
  트랜잭션 안 · `ENV` 설정 없음) · 2 = 인자 사용법 오류. `revoke_sessions:` 줄이 없으면 기록되지 않은 것으로 읽는다(안전한 쪽 — 다시
  돌면 더 큰 `nbf` 행이 하나 더 생길 뿐이다).
- `PARTIAL` 뒤 60 s에 두 키(`revoked:sub` · 세션 하한 키) 가운데 하나라도 없으면 먼저 두 곳의 실패 줄을 본다(로그는 JSON 줄이다 —
  `event` 값과 키로 찾는다). ① 그 명령 출력에서 `event`가 `denylist.set_failed`인 줄의 `stage` — `connect`(Dragonfly 연결 실패 ·
  시간 초과 · 그 밖의 클라이언트 단계 예외 — Dragonfly 연결 · 설정을 고친다) · `command`(명령 단위 오류 — 아래 `error`로 가른다) ·
  `lookup`(DB 조회 실패 — DB를 고친다). ② celery 컨테이너 로그에서 그 명령을 돈 뒤부터 `event`가 `denylist.reapply_failed`인 줄 — 키
  `failed`가 있으면 명령 단위 오류다(재적용은 명령마다 결과를 받아 한 명령의 오류가 다른 명령을 막지 않는다 — 신선도 값이 전진해도
  실패일 수 있다). 키 `phase`(`tick` · `beat_init`)가 있으면 재적용 예외(Dragonfly 연결 · 시간 초과 · DB 장애)다 — 그 원인을
  고친다(재시작은 그 원인을 고치지 못한다). 명령 단위 오류(① `stage`가 `command` · ② 키 `failed`)는 `error`(예외 클래스 이름)로
  가른다 — `NoPermissionError`면 ACL을 고친다(`specs/003-platform-foundation/contracts/denylist.md` §ACL — `revoked:*`만 막혔으면
  신선도 값은 전진하고 `identity-admin:*`도 막혔으면 멈춘다) · 그 밖의 클래스면 Dragonfly 상태(메모리 한도 · 읽기 전용 등 — 신선도
  SET도 막혀 값이 멈출 수 있다)를 고친다. 두 곳에 실패 줄이 없으면 재적용 생존을 본다 — 신선도 키
  `identity-admin:denylist:reapplied-at`의 값(epoch 초)을 35 s 간격으로 두 번 읽어 전진하는가(키의 존재만으로는 재적용이 죽은 직후
  300 s를 가리지 못한다). 실패 줄 없이 값이 멈췄으면(재적용을 돌리는 beat · 워커가 멈췄다) celery **컨테이너**를 재시작한다(재적용은
  그 컨테이너가 돈다 — 위 머리말). pod를 바꾸지 않는다 — beat 스케줄 파일이 `/tmp` emptyDir라 pod가 바뀌면 그날의 일 1회 작업을
  건너뛸 수 있다. 재시작 방법과 키를 읽는 방법(관리자 자격)은 런북 T114가 정한다.

```bash
kubectl --kubeconfig <관리자 kubeconfig> -n jt-<env> exec deploy/identity-admin -c web -- python manage.py seed_tenant --tenant-id <uuid> --owner-sub <sub> --member-sub <sub>
# 단기 운영자 토큰으로 Authentik을 부를 때(설정의 장기 토큰을 쓰지 않는다 — 토큰은 stdin 한 줄)
read -rs T; printf '%s\n' "$T" | kubectl --kubeconfig <관리자 kubeconfig> -n jt-<env> exec -i deploy/identity-admin -c web -- python manage.py seed_tenant --tenant-id <uuid> --owner-sub <sub> --member-sub <sub> --authentik-token-stdin; unset T
```

- `--authentik-token-stdin`의 토큰은 화면 · 셸 기록 · 프로세스 인자에 남지 않게 넣는다 — 위 꼴은 bash `read -rs`(입력을 화면에 찍지
  않는다)로 받아 `printf`(bash 내장이라 프로세스 인자 목록에 남지 않는다)로 넘기고 끝에 `unset`한다(`echo <토큰> |`은 셸 기록에,
  터미널에 바로 치기는 화면에 남는다). 운영자 블록의 정본은 T083 · T114가 정한다.
- SP-1 고정 테넌트 시드다(정본 = `specs/003-platform-foundation/data-model.md` §1 · `contracts/identity-admin-api.md` §관리 명령).
  순서는 그룹 조회(읽기) → DB(Tenant · 멤버십 둘 · 한 트랜잭션) → 사용자 조회(읽기) → Authentik 쓰기(쓰기 플래그가 참일 때만) →
  OpenFGA 튜플이고, 파생이 일시 오류(429 · 5xx · 연결 · 시간 초과)로 멈추면 DB 행은 남고 재실행이 마저 쓴다(그 밖의 실패는 아래
  「인자가 틀렸을 때」). 조회 둘은 쓰기 플래그와 무관하게 한다. prod를 먼저 돈다(Authentik attribute는 prod 시드만 쓴다). 출력은
  `seed_tenant:`로 시작하는 줄 하나다(sub · 토큰 · URL 없음 — 같은 stdout의 JSON 로그 줄 사이에서 접두로 찾는다):
  `seed_tenant: OK env=<env> tenant=<uuid> memberships=created:<n>/unchanged:<n> authentik=written|unchanged|skipped(drift=<n>) fga=ok`(`env`는
  그 실행의 `ENV` — `revoke_sessions`와 같다).
- `authentik` 값: `written`(소속 · `attributes.tenant_id` 가운데 하나 이상을 썼다) · `unchanged`(이미 같다 — 쓰기 0) ·
  `skipped(drift=<n>)`(쓰기 플래그 거짓 — 쓰지 않았고 n은 어긋난 항목 수 0-4 = 사용자 둘 × 소속 · attribute). prod 시드 뒤의 dev
  시드는 `drift=0`이어야 한다 — 0이 아니면 prod 시드가 아직 쓰지 않았거나 실패했다. prod 시드는 `written`(첫 실행) ·
  `unchanged`(재실행)여야 한다 — prod에서 `skipped`면 prod overlay의 쓰기 플래그가 `"true"`가 아니다(위 「deploy/base 추가분」) ·
  고친 뒤 다시 돈다.
- 인자가 틀렸을 때: 시드 전에 두 `sub`를 Authentik에서 uuid로 조회해 username을 눈으로 확인한다 — 출력 줄에는 `sub`가 없어 OK 줄로는
  누구를 시드했는지 알 수 없다. 인자(`sub` · role 순서 · `--tenant-id`)가 틀려 남은 DB 행 · Authentik 소속과 `attributes.tenant_id`
  · OpenFGA 튜플은 명령이 지우지 않는다(같은 인자로 다시 돌아도 같은 자리에서 멈추고, 바른 인자로 다시 돌면 role 불일치 · slug 충돌
  · attribute 충돌로 막힐 수 있다) — 런북 T114의 삭제 절차 뒤 바른 인자로 다시 돈다. `--owner-sub` · `--member-sub`는 명령 인자라 셸
  기록 · 프로세스 목록 · kube-apiserver의 exec 감사 기록에 남는다(`sub`는 가명 식별자라 토큰과 달리 가리지 않는다 — 출력 · 오류 ·
  로그에는 싣지 않는다 · `revoke_sessions --sub`도 같다). 조회와 PATCH 사이에 Authentik에서 바뀐 그 사용자의 `attributes`는
  덮인다(PATCH는 사전 전체를 보낸다) — 시드 중에는 두 사용자를 Authentik에서 고치지 않는다.
- 종료 코드: 0 = `OK` · 1 = CommandError(`seed_tenant:` 줄 없음 · 문구가 멈춘 단계를 말한다 · 문구에 sub · 토큰 · URL이 없고 HTTP
  실패는 상태 코드나 종류만) · 2 = 인자 사용법 오류(인자 누락 등). CommandError는 세 무리다 — ① 아무것도 쓰기 전: `--tenant-id`가
  8-4-4-4-12 꼴의 UUID v7이 아님 · sub가 Authentik 사용자 uuid의 소문자 정규형(8-4-4-4-12)이 아니거나 둘이 같음 · stdin 토큰을 읽지
  못했거나 꼴이 아님 · stdin이 터미널(`exec -it`) · 자리값 자격(`PLACEHOLDER-` — Authentik 토큰(stdin을 주면 그 값) · store id ·
  preshared 키) · store id 꼴(`[A-Za-z0-9_-]{1,64}`) 아님 · 바깥 트랜잭션 안 · `ENV` 설정 없음(migrate 프로필 등) · 그룹
  `tenant:<uuid>`를 찾지 못함 · 여럿 · pk 꼴 아님 · superuser 그룹이거나 응답에 `is_superuser`가 없음 · 그룹 조회 실패(문구 끝
  「DB는 쓰지 않았다」 — 오타 난 `--tenant-id`가 DB에 흔적을 남기지 않는다) ② DB 단계: slug `joshuatech`가 다른 id로 있음 · 그 id의
  Tenant slug가 다름 · 기존 멤버십 role이 인자와 다름(바꾸지 않는다) · 무결성 충돌(「이 실행의 DB 쓰기는 0이다」) ③ 파생 단계:
  사용자를 찾지 못함 · 여럿 · 응답 꼴 밖 · 사용자의 `attributes.tenant_id`가 다른 테넌트(쓰기 플래그와 무관 — 옮기지 않는다) ·
  Authentik 쓰기 실패 · OpenFGA 쓰기 실패(문구 끝 — 일시 오류면 「다시 실행하면 마저 쓴다」 · 그 밖이면 「인자 · 상태를 고친 뒤 다시
  실행한다」 — 위 「인자가 틀렸을 때」).

### 시험

```sh
uv run --locked pytest -q                                            # pod 루트에서 — 전체
uv run --directory apps/identity-admin --locked pytest -q            # 저장소 루트에서 — CI job identity-admin과 같은 명령
uv run --locked pytest -q tests/test_identity_infra.py::test_ia_18_env_example_covers_runtime_fields   # 노드 하나
```

- 전체 실행은 Docker가 필요하고(testcontainers) 개발 호스트(Windows · Docker Desktop)에서 약 5분이다. 고칠 때는 노드 ID만 돌리고 전체는
  끝에 한 번 돈다. `test_ia_fakes.py`와 ia의 정적 노드(ia-18 · ia-23 · ia-24 등)는 Docker 없이 돈다.
- 실제 worker(+ beat) 하위 프로세스를 띄우는 사례가 둘 든다 — 30 s 재적용(`test_ia_40_real_worker_and_beat_reapply` · 약 61 s — tick과
  FLUSHALL 뒤 복귀를 각각 75 s까지 기다린다)과 위임의 실제 발행 사슬(`test_ia_11_real_publish_reaches_worker` — 하위 프로세스
  `revoke_sessions` → 브로커 → 워커 → 가짜 Authentik).
- 실행이 03:17 · 03:27 · 03:37 UTC를 걸치면 그 안의 beat가 일 1회 작업(outbox purge · 폐기 로그 purge · Authentik 대조)을 실제로
  발화한다 — 시험 래퍼의 닫힌 포트라 대조는 `authentik.reconcile_failed error=connection` 뒤 SUCCESS로 끝난다(정상).
- ia 시험 파일 넷(`test_identity_contract.py` · `test_identity_jobs.py` · `test_identity_commands.py` · `test_identity_infra.py`)과 가짜 ·
  도우미(`_ia_fakes.py` · `_ia_support.py` · 자기검사 `test_ia_fakes.py`)는 pod 소유다. `test_api.py` · `_identity_fakes.py` ·
  `test_identity_fakes.py`는 T066(먼저 쓴 수용 시험)이고 단언을 바꾸지 않는다.

### OpenAPI 스냅샷

아래 「OpenAPI 스냅샷 갱신」의 명령 그대로다. identity-admin 스냅샷에는 업무 경로 넷(`/session/check` · `/sessions/revoke` ·
`/tenants/me` · `/webhooks/authentik`)과 그 스키마가 더 있다(손 수정 ⑨ — JSON이라 표식이 없다). `identity_admin/identity_api.py`의
경로 · 스키마 · 뷰 독스트링(스냅샷의 `description`이 된다)을 바꿨을 때만 갱신하고, 바뀐 경로만 diff에 보이는지 검토한다.

### 뷰 응답 규칙(`identity_admin/identity_api.py`)

아래 「뷰 응답 규칙」을 따른다 — 뷰는 dict를 돌려주고 200이 아닌 성공은 `Status(202, {...})`로 낸다(선언 스키마의 하위 클래스
인스턴스를 돌려주지 않는다 · 튜플 반환 없음). 오류(400 · 401 · 403 · 404 · 503)는 RFC 9457 응답(`problem_response(...)` ·
django-common 예외의 `to_response()` — `HttpError(503)`은 `api.py` 오류 표 밖이라 500이 되므로 쓰지 않는다)을 바로 돌려주므로
OpenAPI에는 성공 코드만 선언된다. `/session/check`가 만드는 응답(200 · 503)에는 `Cache-Control: no-store`를 단다.

<!-- identity-admin(T073) 끝 -->

## 구성

| 경로 | 내용 |
|---|---|
| `identity_admin/conf.py` | 설정 모델(pydantic-settings) — env 검증 · 프로필 · 교차 규칙. 실패는 설정 이름만 실은 `ImproperlyConfigured` |
| `identity_admin/settings.py` | Django 설정(conf 값에서 파생 · `MAILERS` · `LOGGING_CONFIG = None`) |
| `identity_admin/apps.py` · `startup.py` | `PodConfig.ready()` = 로깅 → 기동 단언(네트워크 0) → Celery 브로커 |
| `identity_admin/wsgi.py` · `gunicorn_conf.py` | web(gunicorn gthread 워커 1 × 스레드 4) · OTel · Sentry · 지표 9100 |
| `identity_admin/api.py` · `urls.py` · `errors.py` | Ninja API(헬스 3종 · `/api/openapi.json`) · RFC 9457 오류 처리기 · `urls_admin.py`(ADMIN_HOST만) |
| `identity_admin/middleware.py` · `metrics.py` | `http_requests_total{route,status}` · AdminHostMiddleware(admin urlconf · 경로 접두 · 정적 자산) |
| `identity_admin/core/` | 도메인 앱 자리 · `0001_app_role_grants`(app role GRANT) |
| `identity_admin/events/` | 소유 이벤트(`OWNED_EVENTS` · `publish_owned`) — `events/README.md` |
| `identity_admin/celery.py` · `tasks.py` | Celery 앱(워커 + 내장 beat) · 기본 작업 outbox dead purge |
| `identity_admin/management/commands/` | `outbox_relay`(django-common 재노출) · `startup_check`(web initContainer) |
| `tests/` | 시험 래퍼(`tests/settings.py`) · 픽스처(`conftest.py`) · 도우미 · TLS 전용 PostgreSQL 이미지(`tests/docker/pg-tls`) |

## 시험

```sh
uv sync --locked
uv run --locked pytest -q
```

- Docker가 필요하다(testcontainers — PostgreSQL 18.6 TLS · Kafka · Dragonfly). 시험은 skip하지 않는다.
- 시험 설정 = 래퍼 `tests.settings`(pyproject addopts `--ds=tests.settings` · ini `DJANGO_SETTINGS_MODULE`) — pytest-django는
  옵션 > env > ini 순이라 셸의 `DJANGO_SETTINGS_MODULE`도 래퍼를 비켜 가지 못한다. 래퍼는 pod 설정 env를 시험 자리값(닫힌 포트 ·
  난수 비밀 · `ENV=test`)으로 덮어쓰고 선택 설정 · 검증된 설정을 대신하는 env(`CELERY_BROKER_URL` 등 — 아래 「설정」)를 지운 뒤
  pod 설정을 적재한다. 셸에 둔 실제 설정 env는 시험에 닿지 않는다.
- 실패 출력 위생: `addopts = ["--tb=short", "--show-capture=no", "--ds=tests.settings"]`를 바꾸지 않는다. `tests/conftest.py` 가드가
  python `-O` · `PYTHONOPTIMIZE` · 실패 출력을 넓히는 옵션(short가 아닌 `--tb` · `-l` · no가 아닌 `--show-capture` · `--full-trace` —
  명령줄 · `PYTEST_ADDOPTS` · `-o addopts=`로 들어온 것 포함) · `tests.settings`가 아닌 설정 모듈로 돈 실행을 시험 전에
  `UsageError`(종료 4 · 조건 이름만)로 멈춘다. 도우미 모듈(`tests._boot` · `_problem` · `_outbox_fakes` · `_jwt` · `_kafka`)의 단언은
  pytest 단언 재작성에 등록돼 있다. 가드 밖의 넓히는 설정(`log_cli` · `--log-cli-level` · `--log-file` · `junit_logging` · `-s` ·
  `--capture=no|tee-sys`)은 로컬에서만 쓰고 그 출력은 공유하지 않는다(접속 문자열 · 심은 비밀). 새 시험은 env 매핑(`os.environ`) ·
  자격 헤더(토큰) · 비밀 · 자격 URL을 단언 식 안(호출 인자 · 피연산자)에 두지 않는다 — 결과를 지역 변수로 받아 단언한다(단언 재작성이
  인자 repr을 찍고 `-vv`는 자르지 않는다).
- 시험 이미지 `jt-identity-admin-pg-tls:18.6`(`tests/docker/pg-tls`)은 세션이 끝나도 남긴다 — 같은 이미지(ID)를 쓰는 동시 세션의
  이미지 삭제 충돌을 피한다. 다음 세션의 빌드(캐시)가 같은 태그를 덮는다.
- 마이그레이션 검사: `makemigrations --check` · `lintmigrations`(django-migration-linter — 대상 = pod 앱 `identity_admin` · `core`)는
  시험(`tests/test_migrations.py`)이 돈다.

## 설정

프로필은 env `JT_SETTINGS_PROFILE`이다 — `runtime`(없음 · 기본) | `migrate`(PreSync migrate Job 전용). 모르는 값은 기동 실패다.

| 이름 | runtime | 출처(운영) | 비고 |
|---|---|---|---|
| `SECRET_KEY` | 필수 · 비밀 | `<pod>-env`(kv `{env}/django/identity-admin`) | 50자 이상 · 서로 다른 글자 5 이상 · `django-insecure-` 접두 아님 |
| `DATABASE_URL` | 필수 · 비밀 | `<pod>-env`(app role) | dev · prod는 `sslmode=verify-full&sslrootcert=/etc/pg/ca.crt` · test는 require 이상 · 쿼리는 이 둘만 |
| `DRAGONFLY_URL` | 필수 · 비밀 | `<pod>-env` | `redis://identity-admin:…@…/0` · 쿼리 없음 |
| `KAFKA_PASSWORD` | 필수 · 비밀 | `<pod>-env` | SASL SCRAM-SHA-512 |
| `KAFKA_BOOTSTRAP` · `KAFKA_USERNAME` | 필수 | ConfigMap | `host:port` 목록 · prod `identity-admin` / dev `dev-identity-admin` |
| `AUTHENTIK_ISSUER` · `AUTHENTIK_JWKS_URL` · `AUTHENTIK_AUDIENCE` | 필수 | `<pod>-env` · `<pod>-env` · ConfigMap | ISSUER = 공개 URL(문자열 비교만) · JWKS = 클러스터 안 svc DNS · AUDIENCE = `identity-admin` |
| `ACCESS_TEAM_DOMAIN` · `ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN` | 필수 | ConfigMap | dev · prod에서 `http://` 거부 · EXPECTED_CN = 서비스 토큰 Client ID |
| `ACCESS_AUD_ADMIN` · `ADMIN_HOST` | 필수(빈 값 유효) | ConfigMap | 빈 `ADMIN_HOST` = admin 없음(dev) |
| `ALLOWED_HOSTS` | 필수 | ConfigMap | 쉼표 목록 · `*` 금지 · web은 downward API `POD_IP`가 더해진다 |
| `ENV` | 필수 | ConfigMap | `dev` · `prod` · `test`(클러스터 밖 전용) |
| `APP_VERSION` · `APP_GIT_SHA` | 필수 | 이미지 ENV(build-arg) | git sha = 소문자 hex 7–64 |
| `AUTH_ACTOR_SUB` · `SENTRY_DSN` | 선택(기본 빈 값) | ConfigMap · `<pod>-env` | 빈 `SENTRY_DSN` = Sentry 끔 |
| `FORCE_SCRIPT_NAME` | 선택 | ConfigMap(prod) | `/<pod>` 꼴 → `ADMIN_SCRIPT_NAME`(ADMIN_HOST 요청에만 적용 · Django 전역 `FORCE_SCRIPT_NAME` 아님) |
| `POD_IP` · `POD_NAMESPACE` | 선택 | downward API | `POD_NAMESPACE`가 있으면 클러스터 교차 규칙 |
| `OTEL_EXPORTER_OTLP_ENDPOINT` · `OTEL_TRACES_SAMPLER` · `OTEL_TRACES_SAMPLER_ARG` | 선택 | ConfigMap | 엔드포인트 빈 값 = 내보내기 끔(T098) |
| `DATABASE_OWNER_URL` | **거부**(비지 않으면 기동 실패) | `<pod>-migrate`(migrate 프로필 필수) | owner role · migrate Job 전용 |

- **게이트 2**: 문자열 값에 `PLACEHOLDER-`가 있으면 기동 실패(base ConfigMap 자리값이 overlay에서 빠진 경우). 면제는 env
  `JT_PLACEHOLDER_EXEMPT`(쉼표 이름) ∩ 코드 상수 `PLACEHOLDER_EXEMPTABLE`(템플릿은 빈 집합)뿐이다.
- **클러스터 교차 규칙**(`POD_NAMESPACE`가 있을 때): `ENV` ≠ test · `POD_NAMESPACE` = `jt-<ENV>` · `KAFKA_USERNAME` = (dev면
  `dev-`) + `identity-admin` · `DATABASE_URL` 사용자 = (dev면 `dev_`) + `identity_admin_app` · `ALLOWED_HOSTS`에
  `identity-admin.<POD_NAMESPACE>.svc`.
- 클러스터 안 URL(`DATABASE_URL` · `DRAGONFLY_URL` · `KAFKA_BOOTSTRAP` · `AUTHENTIK_JWKS_URL` · OTLP 엔드포인트)이 공개 도메인
  `joshuatech.dev`(하위 포함)을 가리키면 기동 실패다.
- 자격 URL(`DATABASE_URL` · `DATABASE_OWNER_URL` · `DRAGONFLY_URL`)의 사용자 정보는 `[A-Za-z0-9_-]`만 받는다.
- 검증된 설정을 대신하는 env — `CELERY_BROKER_URL` · `CELERY_BROKER_READ_URL` · `CELERY_BROKER_WRITE_URL` ·
  `CELERY_RESULT_BACKEND`(Celery가 `DRAGONFLY_URL`보다 먼저 읽는다) · `GUNICORN_CMD_ARGS`(`gunicorn_conf`를 덮는다) — 가 있으면(빈
  값 포함) runtime 프로필의 모든 프로세스(migrate Job은 migrate 프로필이라 제외)의 기동이 실패한다(`identity_admin/startup.py` —
  이름만 싣는다). `GUNICORN_CMD_ARGS`는 gunicorn이 먼저 읽는다: gunicorn이 해석하는 값은 runtime 기동이 이름만 실어 거부한다 — 단
  그 값에 `--log-level debug`가 있으면 gunicorn이 Django 전에 설정 덤프(해석한 값 — `raw_env` 등)를 찍는다. 해석하지 못하는 값은 Django
  전에 gunicorn 사용법 오류(값 포함 · 종료 2)로 끝난다 — 값 쪽 방어선은 렌더 단언(env_hygiene) · 이미지 단언 · T075 gitops lint다.
- 목록을 넓히는 자리(`identity_admin/conf.py`): `SECRET_SETTINGS`(비밀 — 빈 값 금지) · `IN_CLUSTER_URL_SETTINGS`(`DATABASE_URL` ·
  `DRAGONFLY_URL` · `KAFKA_BOOTSTRAP` 밖의 이름은 http(s) URL로 검사한다 — 꼴이 틀렸거나 모델 필드가 없으면 기동 실패) ·
  `PLACEHOLDER_EXEMPTABLE`. 새 설정은 모델 필드와 이 목록에 함께 더하고, 필수 설정이면 시험 래퍼(`tests/settings.py`)에 자리값도
  둔다(`tests/test_auth_middleware.py`가 목록의 이름마다 공개 호스트 거부를 스스로 시험한다).
- <!-- identity-admin(T073) --> identity-admin 전용 설정 일곱 · 이 pod의 세 목록 값(`SECRET_SETTINGS` +3 · `IN_CLUSTER_URL_SETTINGS` +2 ·
  `PLACEHOLDER_EXEMPTABLE` 셋) · 교차 규칙 셋 · 자리값 동작은 위 「identity-admin」 절 「전용 설정」이 정본이다.

## 로컬 실행

로컬 실행은 `ENV=test`다(Kafka PLAINTEXT · `sslmode=require` · 루프백 `http://` 팀 도메인). 의존 서비스는 `compose.dev.yml`(TLS 전용
PostgreSQL 18.6 · Dragonfly v1.40.1 · Kafka 4.3.1 KRaft — 포트는 127.0.0.1에만)이 띄우고, pod 설정은 `env.example`의 키를 셸 env로
채운다(값을 파일로 저장소에 두지 않는다). 시험은 compose를 쓰지 않는다(testcontainers). 비밀번호는 `[A-Za-z0-9_-]`만 쓴다(자격 URL의
사용자 정보 규칙 — `python -c "import secrets; print(secrets.token_urlsafe(32))"`의 글자다). 명령은 pod 루트(이 디렉터리)에서 bash로 돈다.

1. **의존 서비스** — postgres 슈퍼유저 비밀번호는 셸 env `POSTGRES_PASSWORD`에서만 온다(비어 있으면 postgres가 초기화를 거부한다).
   `--wait`는 postgres가 TCP(TLS)를 받을 때까지 기다린다. 호스트 포트가 이미 쓰이면 `JT_DEV_POSTGRES_PORT` · `JT_DEV_DRAGONFLY_PORT`
   · `JT_DEV_KAFKA_PORT`(기본 5432 · 6379 · 9092)로 바꾸고 아래 URL의 포트도 같은 값으로 쓴다.

   ```bash
   read -rs POSTGRES_PASSWORD; export POSTGRES_PASSWORD
   docker compose -f compose.dev.yml up -d --wait
   ```

2. **DB · role**(한 번) — owner(`identity_admin_owner` · LOGIN BYPASSRLS · DB 소유자)와 app(`identity_admin_app` · LOGIN
   NOBYPASSRLS)으로 나눈다. compose postgres 컨테이너 안의 psql(18 — `\getenv`는 15 이상)이 superuser로(컨테이너 안 유닉스 소켓)
   만든다. 비밀번호는 export한 셸 env로만 넘긴다 — `exec -e <이름>`은 값을 현재 셸 env에서 읽고, psql은 heredoc 안의 `\getenv`로
   읽는다(명령줄 인자 · 프로세스 목록에 값이 실리지 않는다):

   ```bash
   read -rs OWNER_PASSWORD; read -rs APP_PASSWORD; export OWNER_PASSWORD APP_PASSWORD
   docker compose -f compose.dev.yml exec -T -e OWNER_PASSWORD -e APP_PASSWORD postgres \
     psql -v ON_ERROR_STOP=1 --username postgres --dbname postgres <<'SQL'
   SET log_min_error_statement = panic; SET log_statement = 'none';
   \getenv owner_pw OWNER_PASSWORD
   \getenv app_pw APP_PASSWORD
   CREATE ROLE identity_admin_owner LOGIN BYPASSRLS PASSWORD :'owner_pw';
   CREATE ROLE identity_admin_app LOGIN NOBYPASSRLS PASSWORD :'app_pw';
   CREATE DATABASE identity_admin OWNER identity_admin_owner;
   SQL
   ```

   다시 돌리면 role이 있어 실패한다 — 실패한 문장은 서버 로그에 남지 않게 했다(첫 줄 `SET` 둘 — superuser 세션 설정: 실패한
   `CREATE ROLE … PASSWORD` 문장이 `docker logs`에 평문으로 실리지 않는다).

3. **migrate**(owner · migrate 프로필) — app role의 표 권한은 마이그레이션(`core/0001_app_role_grants`)이 준다:

   ```bash
   JT_SETTINGS_PROFILE=migrate ENV=test \
   DATABASE_OWNER_URL="postgresql://identity_admin_owner:$OWNER_PASSWORD@127.0.0.1:5432/identity_admin?sslmode=require" \
     uv run --locked python manage.py migrate --noinput
   ```

4. **runtime env**(app role) — `env.example`의 키를 셸 env로 export한다(`DATABASE_OWNER_URL` · `JT_SETTINGS_PROFILE`은 두지 않는다 —
   runtime 프로필이 owner URL을 거부한다). 로컬 값의 꼴:

   | 이름 | 로컬 값 |
   |---|---|
   | `DATABASE_URL` | `postgresql://identity_admin_app:<APP_PASSWORD>@127.0.0.1:5432/identity_admin?sslmode=require` |
   | `DRAGONFLY_URL` | `redis://identity-admin:<아무 값>@127.0.0.1:6379/0` — aclfile(`compose/dragonfly-dev.acl`)이 `nopass`라 비밀번호는 검사되지 않지만 설정 모델이 사용자 · 비밀번호를 둘 다 요구한다 |
   | `KAFKA_BOOTSTRAP` · `KAFKA_USERNAME` · `KAFKA_PASSWORD` | `127.0.0.1:9092` · `identity-admin` · `<아무 값>`(PLAINTEXT라 쓰지 않지만 비밀 설정이라 빈 값은 기동 실패다) |
   | `ENV` · `ALLOWED_HOSTS` · `SECRET_KEY` | `test` · `127.0.0.1,localhost` · 50자 이상 난수(`secrets.token_urlsafe(48)`) |
   | `APP_VERSION` · `APP_GIT_SHA` | `0.0.0+local` · `0000000`(이미지 밖에서만 — 이미지는 ENV로 준다) |
   | `AUTHENTIK_ISSUER` · `AUTHENTIK_JWKS_URL` · `AUTHENTIK_AUDIENCE` | 공개 URL 문자열 · 클러스터 밖 키 서버 URL(ENV=test는 루프백 `http://`도 받는다) · `identity-admin` |
   | `ACCESS_TEAM_DOMAIN` · `ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN` · `ACCESS_AUD_ADMIN` · `ADMIN_HOST` | 루프백 `http://127.0.0.1:<포트>` 가능 · 값 · 값 · 빈 값 · 빈 값 |
   | `AUTHENTIK_WEBHOOK_SECRET`(identity-admin(T073)) | 32자 이상 난수(`secrets.token_urlsafe(32)` — 43자) · 자리값 면제 불가 |
   | `AUTHENTIK_API_TOKEN` · `OPENFGA_STORE_ID` · `OPENFGA_PRESHARED_KEY`(identity-admin(T073)) | 셋 다 `PLACEHOLDER-LOCAL` + `JT_PLACEHOLDER_EXEMPT=AUTHENTIK_API_TOKEN,OPENFGA_STORE_ID,OPENFGA_PRESHARED_KEY` — 자리값 자격이면 위임 · 대조가 Authentik · OpenFGA를 부르지 않는다(「identity-admin」 절 「전용 설정」) · `AUTHENTIK_API_URL` · `OPENFGA_API_URL` · `AUTHENTIK_WRITES_ENABLED`는 두지 않는다(기본값) |

   확인: `uv run --locked python manage.py startup_check` → `startup_check: OK`(app role 접속 · `check_rls --require-rls-role`).

5. **프로세스** — 아래 「프로세스」 표의 명령을 `uv run --locked …`로 돈다. Windows에서는 gunicorn이 돌지 않는다(POSIX 전용 — web은
   「이미지」의 컨테이너나 WSL에서 돌린다). Windows의 Celery CLI는 `--beat`를 거부한다 — 워커(`--beat` · `--schedule`을
   뺀 명령)와 `celery --app identity_admin beat --schedule <쓰기 가능한 임시 경로>`를 따로 띄운다.

6. **정리** — `docker compose -f compose.dev.yml down -v`(컨테이너 · 네트워크 · 볼륨 — DB 내용도 지운다).

## 프로세스

| 프로세스 | 명령 |
|---|---|
| web | `gunicorn --config python:identity_admin.gunicorn_conf --no-control-socket identity_admin.wsgi:application` |
| relay | `python manage.py outbox_relay`(지표 9464) |
| web initContainer | `python manage.py startup_check`(DB 접속 재시도 → `check_rls --require-rls-role`) |
| celery | `celery --app identity_admin worker --pool solo --beat --schedule /tmp/celerybeat-schedule --without-gossip --without-mingle --without-heartbeat --loglevel INFO` — 프로브 · 지표 없음: 멈춰도 재시작되지 않는다(dead outbox purge 정지 감시는 T098 · T114 인계) |
| migrate(PreSync Job) | CONNECT 경계 SQL 뒤 `python manage.py migrate --noinput`(`JT_SETTINGS_PROFILE=migrate`) — 하위 migrate의 종료 코드를 돌려준다. 접속 · 경계 SQL 재시도 줄은 stdout(`db_connect_retry` · `db_boundary_retry <클래스> attempt=<n>` — 경계는 `OperationalError` · app role 지연 `UndefinedObject`) · 마감은 함께 `JT_DB_CONNECT_WAIT_SECONDS`(기본 120). 스크립트 자신의 실패는 stderr 한 줄 + 종료 1(`db_url_invalid` · `db_connect_wait_invalid` · `db_connect_failed` · `db_boundary_failed` + 예외 클래스 이름 — 트레이스백 · 메시지 · 값 없음) |

## 이미지

빌드 컨텍스트는 저장소 루트다(`packages/django-common`을 함께 넣는다 — `Dockerfile` 머리 주석). 저장소 루트에서:

```bash
docker buildx build --platform linux/arm64 -f apps/identity-admin/Dockerfile \
  --build-arg APP_VERSION=<판> --build-arg APP_GIT_SHA=<git sha> -t identity-admin:<태그> .
```

- build-arg `APP_VERSION`(기본 `0.0.0+local`) · `APP_GIT_SHA`(기본 `0000000` — 소문자 hex 7–64자)는 이미지 ENV와 라벨
  `org.opencontainers.image.revision`이 된다(배포 빌드는 `github.sha`).
- 컨텍스트는 `Dockerfile.dockerignore`가 거른다 — pod 안까지 허용 목록이다(`identity_admin` · `manage.py` · `pyproject.toml` ·
  `uv.lock` + django-common `pyproject.toml` · `src`만 넣고 캐시 · `.venv` · `.git*`와 비밀 후보를 다시 뺀다 — `.env*` · `*.pem` ·
  `*.key` · `*.crt` · `*.p12` · `*.pfx` · `*.env` · `.netrc` · `id_rsa*` · `id_ed25519*` · `id_ecdsa*`, 모두 대소문자를 가리지 않는다:
  `CASE.PEM` · `.Env.prod` · `LOCAL.ENV` · `.NETRC` · `ID_RSA`도 빠진다). 그래서 작업 트리에 무엇이 있든(IDE 설정 · 로컬 env · 키 ·
  시험 · deploy · compose · 문서) 이미지의 `/src/apps/identity-admin` 최상위는 `.venv` · `identity_admin` · `manage.py` · `pyproject.toml` ·
  `uv.lock`뿐이다. 패키지 디렉터리(`identity_admin/`) 안의 파일은 그 재제외 꼴이 아니면 들어간다(`secrets.json` 같은 이름은 걸러지지
  않는다) — 비밀을 패키지 안에 두지 않는다. `packages/django-common/src`의 추적 밖 파일도 django-common wheel을 거쳐 이미지 venv의
  site-packages에 들어간다 — 그 경로에 비밀을 두지 않는다. 저장소 루트 `.dockerignore`(`*`)는 Dockerfile 이름이 어긋난 빌드(다른
  이름으로 복사한 `-f`)를 빈 컨텍스트로 막는다(COPY에서 실패 — 닫힌 쪽).
- USER는 숫자 `10001:10001`이고 루트 파일시스템은 읽기 전용으로 돈다(쓰기는 `/tmp`뿐 — `docker run --read-only --tmpfs /tmp`). 기본
  명령은 web(gunicorn)이다 — relay · celery · 관리 명령은 명령을 바꿔 돈다(`docker run … <이미지> python manage.py outbox_relay`).
- 비밀 env(`SECRET_KEY` · `DATABASE_URL` · `DRAGONFLY_URL` · `KAFKA_PASSWORD`)는 `docker run -e NAME`(값 없이 — docker CLI가 셸 env에서
  읽는다)으로 넘긴다 — `-e NAME=값`은 값을 명령줄 · 셸 기록 · 프로세스 목록에 남긴다.
- 로컬 compose 서비스에 붙이려면 `--network identity-admin-dev_default`와 서비스 이름(`postgres` · `dragonfly`)을 쓴다. Kafka의 광고
  리스너는 호스트용(`127.0.0.1`)이라 그 네트워크의 컨테이너는 브로커에 붙지 못한다(relay는 호스트 프로세스로 돈다).

## deploy/base 인터페이스(T075가 gitops로 복사한다)

- 파일(`kustomization.yaml`의 resources 순서): `configmap.yaml` · `externalsecret-env.yaml` · `externalsecret-migrate.yaml` ·
  `migrate-job.yaml` · `deployment.yaml` · `deployment-celery.yaml` ·
  `service.yaml` · `ingress.yaml`. gitops `apps/identity-admin/base`로 파일 이름 1:1 복사한다.
- base는 dev 값이다 — prod overlay가 namespace · 이미지 digest · Ingress host(`/spec/rules/0/host`) · ConfigMap 값 · ExternalSecret
  store와 키(`prod/…`)를 패치한다. base `kustomization.yaml`에는 `namespace` · `images` · `commonLabels`가 없다. 모든 컨테이너의
  `image`는 태그 · digest 없는 `ghcr.io/joshua92y/identity-admin`이다(overlay `images[].name`과 글자까지 같아야 digest가 붙는다).
  라벨은 `app.kubernetes.io/name: identity-admin` + 워크로드의 `app.kubernetes.io/component`(web · celery · migrate)이고, selector는
  바꿀 수 없으므로 라벨을 바꾸지 않는다. ConfigMap 값은 클러스터 교차 규칙을 만족해야 한다(머지 전 렌더로 확인).
- ConfigMap `identity-admin-config` base 값: `ACCESS_AUD_ADMIN=""` · `ACCESS_AUD_M2M` · `ACCESS_EXPECTED_CN` =
  `PLACEHOLDER-SET-IN-OVERLAY`(게이트 2가 overlay 누락을 기동 실패로 바꾼다) · `ACCESS_TEAM_DOMAIN=joshua-tech.cloudflareaccess.com` ·
  `ADMIN_HOST=""` · `ALLOWED_HOSTS=identity-admin.jt-dev.svc` · `AUTH_ACTOR_SUB=""` · `AUTHENTIK_AUDIENCE=identity-admin` · `ENV=dev` ·
  `FORCE_SCRIPT_NAME=""` · `KAFKA_BOOTSTRAP=jt-kafka-kafka-bootstrap.data.svc:9093` · `KAFKA_USERNAME=dev-identity-admin` ·
  `OTEL_EXPORTER_OTLP_ENDPOINT=""` · `OTEL_TRACES_SAMPLER=parentbased_traceidratio` · `OTEL_TRACES_SAMPLER_ARG="0.1"`(값은 전부 평문
  스칼라 — 블록 스칼라 `|`의 끝 줄바꿈 금지). `APP_VERSION` · `APP_GIT_SHA` · `DJANGO_SETTINGS_MODULE`은 이미지 ENV가 정하므로 두지
  않는다(덮어쓰게 된다).
- ExternalSecret `identity-admin-env`(store `vault-dev` · `refreshInterval: 5m` · `Periodic` · `creationPolicy: Owner` · 템플릿 v2
  `Replace`)의 `data[]` 순번은 overlay 인덱스 패치의 인터페이스다 — prod overlay는 인덱스 replace마다 앞에 `op: test`(`path:
  /spec/data/N/secretKey` · `value: <이름>`)를 둔다(재생성으로 순번이 바뀌면 렌더가 실패한다 — validate 3.2는 키 접두 · store만
  본다). 새 항목은 끝(7번 뒤 — 8번부터)에만 덧붙인다. `DATABASE_URL`은 템플릿이 조립한다(DB 이름 = `db_username`에서 `_app`을 뗀 것
  · `sslmode=verify-full&sslrootcert=/etc/pg/ca.crt`) — prod overlay는 URL 문자열을 패치하지 않는다.

| # | secretKey | remoteRef.key(dev) | property |
|---|---|---|---|
| 0 | db_username | `dev/db/dev_identity_admin/app` | username |
| 1 | db_password | `dev/db/dev_identity_admin/app` | password |
| 2 | kafka_password | `dev/kafka/identity-admin` | password |
| 3 | dragonfly_url | `dev/dragonfly/identity-admin` | url |
| 4 | authentik_issuer | `dev/authentik/identity-admin` | issuer |
| 5 | authentik_jwks_url | `dev/authentik/identity-admin` | jwks_url |
| 6 | sentry_dsn | `dev/sentry/identity-admin` | dsn |
| 7 | secret_key | `dev/django/identity-admin` | secret_key |

- <!-- identity-admin(T073) --> identity-admin은 이 표 뒤에 `data[8..11]`(Authentik · OpenFGA 자격 넷)을, ConfigMap에
  `AUTHENTIK_WRITES_ENABLED: "false"`를 더했다 — 위 「identity-admin」 절 「deploy/base 추가분」.
- ExternalSecret `identity-admin-migrate`: `data[0]` · `data[1]` = `dev/db/dev_identity_admin/owner`의 username · password ·
  `DATABASE_OWNER_URL`(DB 이름 = `db_username`에서 `_owner`를 뗀 것). migrate Job만 참조한다. prod overlay는 store(`vault-prod`)와
  `data[0]` · `data[1]`의 key를 prod 경로(`prod/db/identity_admin/owner`)로 바꾸고, 각 인덱스 replace 앞에 `op: test`(`path:
  /spec/data/N/secretKey` · `value: <이름>`)를 둔다(위 `-env`와 같은 규칙).
- 단계 · sync-wave(첫 배포에 Secret · ConfigMap이 소비자보다 먼저 생긴다):

| 리소스 | 단계 | sync-wave | hook-delete-policy |
|---|---|---|---|
| ExternalSecret `identity-admin-migrate` | PreSync hook | -1 | BeforeHookCreation |
| Job `identity-admin-migrate` | PreSync hook | 0 | BeforeHookCreation |
| ConfigMap `identity-admin-config` · ExternalSecret `identity-admin-env` | Sync | -1 | — |
| Deployment 둘 · Service · Ingress | Sync | 0(주석 없음) | — |

- hook 리소스는 Argo 추적 밖이다: hook만 바뀐 변경은 전체 수동 Sync(리소스 선택 없음) · `identity-admin-migrate` ES 상태는
  Application health 밖(`kubectl get externalsecret identity-admin-migrate`로 직접 본다) · 전체 sync마다 owner Secret이 지워졌다 다시
  생긴다(BeforeHookCreation + Owner — 모든 배포가 Vault · ESO 가용성에 걸린다). hook ES가 Healthy가 되지 않을 때는 두 갈래다(Argo CD
  v3.5.2 — ExternalSecret health: Ready=False는 Degraded · 상태 없음은 Progressing):
  - ES Degraded(kv 누락 · Vault · store 오류 — `kubectl get externalsecret identity-admin-migrate`의 Ready=False 메시지로 판정): operation이
    Failed가 되고, 자동 재시도(기본 창 ≈ 5분)가 다하면 같은 리비전은 다시 자동 sync되지 않는다 → 원인을 고친 뒤 전체 수동 Sync.
  - ES 상태 없음(ESO 컨트롤러 중단 — Progressing): operation이 무기한 Running이다 → operation terminate → ESO 복구 → 전체 수동 Sync.
- 마운트: CA Secret `pg-main-ca` → `/etc/pg`(모든 컨테이너) · `jt-kafka-cluster-ca-cert` → `/etc/kafka`(web · relay) · `/tmp` emptyDir
  (유일한 쓰기 경로 — 읽기 전용 루트). 런타임 컨테이너는 env `POD_NAMESPACE`(downward API — 클러스터 교차 규칙)를, web은 `POD_IP`도
  받는다(migrate Job은 둘 다 없다).
- 자원(memory — CPU limit 없음):

| 컨테이너 | requests | limits |
|---|---|---|
| web | 256Mi | 512Mi |
| relay | 96Mi | 192Mi |
| startup-check(initContainer) | 128Mi | 256Mi |
| celery | 192Mi | 512Mi |
| migrate(Job) | 256Mi | 512Mi |

## 뷰 응답 규칙

django-ninja 핀이 1.7.0에 머무는 동안 뷰는 dict 또는 선언한 응답 스키마의 정확한 인스턴스만 돌려준다. 하위 클래스 인스턴스는 선언
밖 필드를 응답에 실을 수 있다(규칙 django-pod.md §Errors). 200이 아닌 응답은 `Status(code, body)`로 낸다(튜플 반환은 폐기 경고가
난다).

## OpenAPI 스냅샷 갱신

`tests/snapshots/openapi.json` = `api.get_openapi_schema()`에서 `info.title`을 뺀 값이다(title은 따로 비교한다). API를 일부러
바꿨거나 django-ninja 판을 올렸을 때만 갱신한다 — 시험을 돌려 차이를 경로별로 검토하고, 그 변경을 일으킨 커밋에 스냅샷을 함께
넣는다(맹목 재생성 금지 — 규칙 django-pod.md §OpenAPI snapshot refresh). 새 JSON은 pod 루트에서 이 명령으로 쓴다(시험 래퍼로
`django.setup()` · title 제외 · 키 정렬 · 들여쓰기 2 · UTF-8 · 끝 줄바꿈 — 지금 파일과 같은 꼴이라 diff가 바뀐 경로만 보인다):

```sh
uv run --locked python -c "import json, os, pathlib, django; os.environ['DJANGO_SETTINGS_MODULE'] = 'tests.settings'; django.setup(); from identity_admin.api import api; schema = json.loads(json.dumps(api.get_openapi_schema())); schema['info'].pop('title'); pathlib.Path('tests/snapshots/openapi.json').write_text(json.dumps(schema, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8', newline='\n')"
```

## 재생성

`copier update`는 지원하지 않는다(모노레포 안 템플릿이라 `_commit`이 없다). 템플릿이 바뀌면 같은 답으로 다시 생성하고 diff로
옮긴다 — 저장소 루트를 cwd로 두고 하네스 잠금의 copier로 돌린다(맨 `copier`가 아니다). `.copier-answers.yml`에 기록된 답은
`--defaults`가 다시 쓴다(`--data`로 되풀이하지 않는다):

```sh
uv run --project templates/django-pod --locked python -m copier recopy --trust --defaults --overwrite apps/identity-admin
```

손으로 고친 템플릿 소유 파일은 템플릿 꼴로 되돌아가고, 템플릿에 없는 pod 소유 파일은 그대로 남는다 — `git diff`를 보고 고친
자리(conf.py의 목록 · 시험 상수 등)를 다시 옮긴다.

`_tasks: uv lock`이 실패하면 copier는 자기가 새로 만든 대상 디렉터리만 지운다(`--no-cleanup`으로 남겨 원인을 본다). 이미 있던
디렉터리는 지우지 않으므로 반쯤 생성된 채 남는다 — `git status`로 확인하고 원인을 고친 뒤 같은 명령을 다시 돈다.

<!-- identity-admin(T073) — 아래 절차 · 손 수정 표 · pod 소유 파일 목록은 손 수정 ⑮다. -->
### identity-admin 재생성 — 3-way(정본 · VD-T073-11 실측 2026-11-13)

생성 커밋(손 수정 전의 순정 렌더)에서 갈라 새 템플릿으로 같은 `recopy`를 돈 커밋을 만들고, 그 커밋을 손 수정이 든 작업 브랜치에
cherry-pick한다(git의 3-way 병합 — 기준은 생성 커밋이다). 저장소 밖 임시 복제본에서 템플릿 줄 둘을 바꿔 한 번 쟀다: 손 수정이 없는
파일의 변경은 충돌 없이 실렸고, 손 수정 블록에 맞닿은 변경은 그 블록 한 곳에서만 충돌로 멈췄다(블록 밖 충돌 0 · 지워진 손 수정 0 ·
`uv.lock` · `.copier-answers.yml` 변경 0). **손 수정 블록에 맞닿은 템플릿 변경은 자동으로 실리지 않는다** — 그 블록에서 손으로
합친다.

1. 작업 트리를 커밋해 깨끗하게 둔다(템플릿 변경 `templates/django-pod/**`도 먼저 커밋한다 — 4단계의 되돌리기가 이 커밋으로
   돌아간다).
2. 생성 커밋을 찾는다 — 이 pod의 `.copier-answers.yml`을 처음 더한 커밋이다:
   `git log --diff-filter=A --format=%H -- apps/identity-admin/.copier-answers.yml`(여러 줄이면 마지막 줄 — 가장 오래된 커밋 · SHA를
   적어 두지 않는다 — 머지 방식에 따라 바뀐다).
3. 그 커밋에 worktree를 연다: `git worktree add --detach .worktrees/regen-identity-admin <생성 커밋>`. worktree 루트를 cwd로 위
   `recopy`를 **템플릿을 바꾸기 전에 그대로** 한 번 돌아 종료 코드 0과 빈 `git status --short`를 본다 — 비어 있지 않으면 그 커밋은
   순정 렌더가 아니다(생성과 손 수정이 한 커밋에 든 이력 등 — 그 기준으로 cherry-pick하면 손 수정이 되돌려진다). 멈추고 worktree를
   지운 뒤(`git worktree remove --force .worktrees/regen-identity-admin` — 더러운 worktree는 `--force` 없이 지워지지 않는다) 아래
   `recopy` + diff로 간다. 비어 있으면 템플릿만 작업 브랜치의 것으로
   바꾸고(`git restore --source=<작업 브랜치> --staged --worktree -- templates/django-pod`) `recopy`를 다시 돌아 종료 코드 0을 본 뒤
   `git add -A -- apps/identity-admin templates/django-pod` → `git commit`으로 순정 렌더 커밋을 만든다(커밋 뒤
   `git status --short`가 비고 `git show --stat HEAD`에 생성물 경로가 있어야 한다 — 템플릿 경로만 있으면 생성물이 빠졌다). 그 SHA는
   `git -C .worktrees/regen-identity-admin rev-parse HEAD`다.
4. 원래 작업 트리(작업 브랜치)에서 그 커밋을 커밋하지 않고 가져온다: `git cherry-pick --no-commit <순정 렌더 커밋>`(충돌이 없으면
   `--no-commit` 없이는 곧바로 커밋된다). 충돌은 손 수정 블록에서만 나야 한다 — `git checkout --conflict=zdiff3 -- <파일>`로 기준
   칸(생성 커밋의 줄)을 함께 보고 손 수정과 템플릿 변경을 합친다. 충돌이 없어도 `git diff --cached`로 손 수정 표의
   표식(`identity-admin(T073)`) 블록이 그대로인지 본 뒤 `git commit`한다. 블록 밖에서 충돌이 나거나 손 수정이 사라졌으면
   `git reset --hard HEAD`(1단계의 커밋으로 돌아간다 — `--no-commit`은 HEAD를 옮기지 않는다)와 worktree 삭제(`--force`) 뒤 아래
   `recopy` + diff로 간다.
5. 아래 `recopy` + diff 절차의 5 · 6단계(`uv.lock`의 diff · 생성물 시험 전체 · 시험이 지키지 않는 자리의 diff)를 그대로 한다. 끝나면
   worktree를 지운다(`git worktree remove .worktrees/regen-identity-admin`).

재지 않은 것(그 일이 생기면 쓰기 전에 잰다): ① 둘째 재생성부터의 기준 — cherry-pick은 3단계의 순정 렌더 커밋을 작업 브랜치 이력에
남기지 않는다(직전 재생성 때의 템플릿으로 순정 렌더를 먼저 다시 만들어 기준으로 삼는 꼴을 추론한다 — 실측 전에는 아래 `recopy` +
diff를 쓴다). ② 템플릿이 pod 소유 경로(아래 목록)에 새 파일을 만들 때 — add/add 충돌로 드러날 것으로 추론한다(`recopy` + diff의
`--overwrite`처럼 조용히 덮이지는 않는다). ③ `uv lock`이 잠금을 바꿀 때. 리허설은 저장소 밖 복제본에서 손 수정 커밋에 그냥
cherry-pick했다 — 3단계의 worktree와 4단계의 `--no-commit` · 확인은 같은 git 동작을 저장소 안에서 확인을 끼워 하는 꼴이다.

### identity-admin 재생성 — `recopy` + diff(3-way가 멈췄거나 쓸 수 없을 때)

1. 작업 트리를 커밋해 깨끗하게 둔다(되살릴 원본이 `git`에 있어야 한다). 저장소 루트를 cwd로 위 `recopy`를 돈다. `recopy`는 이 README
   자신도 템플릿 꼴로 되돌린다 — 이 절차와 손 수정 표는 `git show HEAD:apps/identity-admin/README.md`(재생성 앞의 커밋)로 본다.
2. `git status --short -- apps/identity-admin`와 `git diff -- apps/identity-admin`를 본다 — 손 수정 15파일은 템플릿 꼴로 돌아가
   표식 블록이 `-` 줄로 보이고, 템플릿 변경은 같은 diff에 섞여 보인다. `??`로 보이는 파일은 템플릿이 새로 만든 것이다.
3. 아래 손 수정 표의 자리를 하나씩 되살린다 — 표식(`identity-admin(T073)`)이 있는 블록은 diff의 `-` 줄 그대로, 표식 예외 둘(⑨ · ⑪)은
   이 표가 정본이다(`git show HEAD:<경로>`로 꺼내 견준다). 템플릿이 바꾼 줄은 남긴다 — 손 수정 블록과 같은 줄을 템플릿이 바꿨으면 둘을
   합친다.
4. pod 소유 파일(아래 목록)은 템플릿에 없는 경로라 `recopy`가 건드리지 않는다. **템플릿이 같은 경로를 만들면 `--overwrite`로
   덮인다** — 그 파일이 diff에 보이면 `git show HEAD:<경로>`로 되살린 뒤 템플릿이 그 경로에 둔 것과 합칠지 정한다.
5. `uv.lock`(`_tasks: uv lock`이 다시 잠근다)의 diff를 본다 — 템플릿 의존이 바뀌지 않았으면 0이다.
6. 생성물 시험 전체를 돈다(`uv run --locked pytest -q` — 삭제 · skip 0). 손 수정 ①–⑭는 아래 「지키는 시험」이 되살림을 확인한다.
   시험이 지키지 않는 자리는 diff로 본다 — ⑮(이 README) · ④ ⑥ ⑦ ⑧ ⑩의 독스트링 문장 · 모든 행의 주석(표식 줄 포함). ⑩의
   `register_assert_rewrite` 두 이름은 `tests/test_identity_infra.py::test_ia_helper_modules_are_assert_rewritten`이 지킨다(두 도우미
   모듈이 단언 재작성을 받았는지 본다 — `tests._ia_support`는 `pytest_plugins`로도 재작성을 받아 그 이름 하나만 빠진 경우는 걸리지
   않지만 재작성은 그대로다).

### 손 수정 표(템플릿 소유 15파일)

표식은 손댄 줄 · 블록의 `# identity-admin(T073)`이다(README는 HTML 주석 `<!-- identity-admin(T073) -->`와 표 행의
`identity-admin(T073)`). **표식 예외 둘** — 주석을 둘 수 없는 ⑨ `openapi.json`(JSON)과 ⑪ `dragonfly-dev.acl`(USER 줄만 둔다 —
Dragonfly가 aclfile의 주석 줄을 받는지 잰 적이 없다)은 표식 없이 고쳤고 이 표가 정본이다.

| # | 파일 | 고친 자리 | 지키는 시험 |
|---|---|---|---|
| ① | `identity_admin/conf.py` | 표식 블록 일곱: `SECRET_SETTINGS` + 비밀 셋 · `IN_CLUSTER_URL_SETTINGS` + API URL 둘 · `PLACEHOLDER_EXEMPTABLE` = 나가는 쪽 자격 셋 · 모듈 상수 셋(`WEBHOOK_SECRET_MIN_LENGTH` · `ASCII_SECRET_SETTINGS` · `SERVICE_BASE_URL_SETTINGS`) · `RuntimeEnv` 필드 일곱 · `_runtime_problems` 안의 교차 규칙 블록(웹훅 비밀 32자 · 비밀 셋 ASCII · 서비스 기준 URL 꼴) · 도우미 `_service_base_url_ok`. 모듈 머리 독스트링은 고치지 않았다(전용 설정의 정본은 「전용 설정」 표) | `test_auth_middleware.py`(`test_required_settings_match_contract` · 이름마다 매개화된 기동 시험 — 필수 · 빈 비밀 · 클러스터 안 URL) · T066 `test_api_46`–`49` · `54` · `55` · ia-23 |
| ② | `identity_admin/settings.py` | 경로 집합 셋(`AUTH_EXEMPT_PATHS` · `TENANT_CONTEXT_EXEMPT_PATHS` · `AUTH_ACCESS_ONLY_PATHS` — 앞 주석 두 줄 포함) · runtime 분기의 전용 설정 노출 일곱(주석 한 줄) | ia-23 `test_ia_23_settings_expose_identity_seven` · T066 api-4–9 · 20–26 · 44 · ia-3 · 기동 단언 `startup._paths` |
| ③ | `identity_admin/api.py` | `from identity_admin.identity_api import identity_router` 한 줄 · `api.add_router("", identity_router)` 한 줄 | T066 업무 엔드포인트 시험 · `test_openapi_snapshot.py` |
| ④ | `identity_admin/celery.py` | `beat_schedule`의 항목 셋(`reconcile-denylist` 30 s · `expires` 30 / `purge-session-revocation-log` 03:27 / `reconcile-authentik-sessions` 03:37 — 앞 주석 · 끝 표식 줄 포함) · `from datetime import timedelta` 한 줄 · 머리 독스트링의 ACL 문자열(`~revoked:*` — 꼬리 `-@admin -@dangerous -client`는 템플릿 문장 그대로 · T075 UD-9) | `test_outbox.py::test_celery_app_configuration` · T066 api-30–34 · ia-38 · ia-40(독스트링은 시험 밖) |
| ⑤ | `identity_admin/tasks.py` | `from identity_admin import jobs as _jobs` 한 줄(autodiscover는 `tasks` 모듈만 싣는다) | T066 api-33 · ia-11 · ia-40 |
| ⑥ | `tests/settings.py` | `_required_values`에 필수 넷(비밀 셋 = import마다 난수 · store id 자리값)과 API URL 둘(닫힌 루프백 포트) · `POD_SETTINGS_ENV_REMOVED`에 `AUTHENTIK_WRITES_ENABLED` · 모듈 독스트링 문장 하나 | 스위트 전체(시험 래퍼) · T066 api-48 · ia-23 |
| ⑦ | `tests/test_auth_middleware.py` | 상수 둘(`REQUIRED_SETTINGS` + 필수 넷 — `ACCESS_AUD_ADMIN` 앞 · `SECRET_SETTINGS` + 비밀 셋) · `df_admin` 독스트링 한 문장 | 자기 자신(`test_required_settings_match_contract`가 `conf`와 견준다) |
| ⑧ | `tests/test_outbox.py` | `test_celery_app_configuration`의 beat 항목 목록 단언(네 항목) · 새 세 항목의 주기 단언 블록 · 그 함수 독스트링 한 문장 · 모듈 독스트링 Celery 항목의 문장 둘(beat 항목 · ACL 문자열) | 자기 자신(독스트링은 시험 밖) |
| ⑨ | `tests/snapshots/openapi.json`(표식 예외) | 업무 경로 넷과 그 스키마 — 손으로 고치지 않고 「OpenAPI 스냅샷 갱신」 명령으로 다시 만든다(③ · `identity_api.py`가 있는 트리에서) | `test_openapi_snapshot.py::test_openapi_schema_matches_snapshot` |
| ⑩ | `tests/conftest.py` | `DRAGONFLY_USERS[POD_NAME]` = `("resetchannels", "~revoked:*", f"~{POD_NAME}:*", "+@all", "-@admin", "-@dangerous", "-client")`(앞 주석 한 줄 · 꼬리 셋은 템플릿 값 그대로 — T075 UD-9) · `register_assert_rewrite`에 `tests._ia_support` · `tests._ia_fakes` · `pytest_plugins = ("tests._ia_support",)` 한 줄 · 독스트링 셋(모듈 머리의 단언 재작성 목록 · `dragonfly` 항목 · `DragonflyInfo`) | ia-24 · pod 사용자로 도는 ia 시험(되돌리면 NOPERM) · ia 픽스처를 쓰는 시험 전부(`pytest_plugins`) · `test_ia_helper_modules_are_assert_rewritten`(두 도우미의 단언 재작성) |
| ⑪ | `compose/dragonfly-dev.acl`(표식 예외) | `USER identity-admin ON nopass ~revoked:* ~identity-admin:* +@all -@admin -@dangerous -client` 한 줄(템플릿의 `%R~revoked:*` → `~revoked:*` · 꼬리 `-@admin -@dangerous -client`는 템플릿 그대로 — T075 UD-9) | ia-24 |
| ⑫ | `env.example` | 끝 블록 하나 — 필수 넷 · 선택 셋의 키(값 없음 · 앞 빈 줄과 주석 다섯 줄) | ia-18 `test_ia_18_env_example_covers_runtime_fields` |
| ⑬ | `deploy/base/externalsecret-env.yaml` | 머리 주석 두 줄 · `template.data` 네 줄(주석 한 줄) · `data[8..11]`(주석 두 줄) | ia-18 `test_ia_18_env_externalsecret_order_and_mapping` |
| ⑭ | `deploy/base/configmap.yaml` | `AUTHENTIK_WRITES_ENABLED: "false"` 한 키(앞 주석 세 줄) | ia-18 `test_ia_18_configmap_writes_flag_and_no_service_urls` · 템플릿 `base_configmap_env()`의 「값이 전부 문자열」 단언(dev 모양 기동 시험) |
| ⑮ | `README.md` | 「identity-admin」 절 · 「설정」의 항목 하나 · 「로컬 실행」 4단계 표의 행 둘 · 「deploy/base 인터페이스」의 항목 하나 · 「재생성」의 두 절차(3-way · `recopy` + diff) · 이 표 · 아래 목록 | 시험 밖 — 리뷰 |

### pod 소유 파일(템플릿에 없는 경로 — 템플릿이 같은 경로를 만들면 `--overwrite`로 덮인다)

- `identity_admin/`: `models.py` · `migrations/__init__.py` · `migrations/0001_initial.py` · `identity_api.py` · `revocation.py` ·
  `denylist_writer.py` · `session_floor.py` · `identity_metrics.py` · `outbound.py` · `authentik.py` · `openfga.py` · `jobs.py` ·
  `management/commands/revoke_sessions.py` · `management/commands/seed_tenant.py`
- `tests/`: `_ia_support.py` · `_ia_fakes.py` · `test_ia_fakes.py` · `test_identity_contract.py` · `test_identity_jobs.py` ·
  `test_identity_commands.py` · `test_identity_infra.py`
- 생성 전부터 있던 T066 수용 시험 셋: `tests/test_api.py` · `tests/_identity_fakes.py` · `tests/test_identity_fakes.py`(단언을 바꾸지
  않는다 — 독스트링 · 주석만 고쳤다)

<!-- identity-admin(T073) 끝 -->
