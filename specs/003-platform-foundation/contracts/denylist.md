# Contract: 세션 거부 목록 (Dragonfly 키 스키마 · ACL)

소유 identity-admin. 정본은 DB 테이블 `session_revocation_log`(data-model §3)이고 Dragonfly는 **파생 캐시**다. 모든 pod의 인증 미들웨어(`django_common.auth.Denylist`)가 JWT 검증 뒤 이 키를 1회 조회한다. 인스턴스: `data` ns `dragonfly-dev`·`dragonfly-prod`(6379), env마다 하나. 사용자 단위 폐기는 같은 로그 행에서 세션 하한 키(§키 스키마)도 파생한다 — 이 키는 identity-admin `/session/check`만 읽는다(T073 보정 2026-11-12).

## 키 스키마

| 키 | 값 | TTL | 쓰는 쪽 | 의미 |
|---|---|---|---|---|
| `revoked:sub:{sub}` | `nbf`(epoch 초, 정수) | 330 s | identity-admin | `iat < nbf`인 토큰은 거부 — 전체 기기 로그아웃·관리자 폐기·테넌트 정지 |
| `revoked:sid:{sid}` | `1` | 330 s | identity-admin | 특정 세션(`sid`)의 토큰만 거부 — 단일 기기 로그아웃(pod 경계에서는 조회되지 않는다 — §조회 규약 1 · 집행은 BFF의 `/session/check` · T073 보정 2026-11-12) |
| `identity-admin:session-floor:{sub}` | 그 `sub`의 사용자 단위 폐기 행 가운데 가장 큰 `nbf`(epoch 초, 정수) | 그 행의 `expires_at + 30 d`까지(= `nbf` + 330 s + 30 d) | identity-admin | 세션 하한 — BFF 세션 시작 시각 < 값인 세션은 inactive(`/session/check`만 읽는다 · T073 보정 2026-11-12) |
| `identity-admin:denylist:reapplied-at` | 마지막 재적용 시각(epoch 초) | 300 s | identity-admin | 재적용 생존 신호(판정에 쓰지 않는다 · T073 보정 2026-11-12) |

- **센티널 키 `denylist:epoch`는 쓰지 않는다**(폐지). 아래 §쓰기 규약의 무조건 재적용이 그 역할을 대신한다.
- TTL 330 s = access 토큰 TTL 300 s + 30 s 여유. `expires_at`(DB) = `nbf` + 330 s. 재적용이 쓰는 TTL은 그 행의 `expires_at`까지 남은 초다 — `nbf`가 미래인 행(웹훅 시각 창 · 관리 명령의 상한 안)에서는 330 s를 넘을 수 있다(닫힌 쪽이다 · 요청 경로의 커밋 뒤 쓰기는 `min(330, …)` · T073 보정 2026-11-13).
- 키 이름은 spec·`Denylist`·테스트(T062)에서 이 표 그대로 쓴다(`revoked:{sub}` 같은 축약형 금지).
- `{sub}`·`{sid}`는 Authentik 토큰 클레임 값 그대로(인코딩 없음).
- **세션 하한(T073 보정 2026-11-12)**: `revoked:*`의 330 s는 이미 나간 access 토큰을 막는 수명이다. 폐기 전에 시작한 BFF 세션(쿠키의 refresh 토큰)은 330 s 뒤에도 refresh로 살아남는다 — Authentik은 세션을 지워도 refresh 토큰을 남기고 서비스 계정은 남의 refresh 토큰을 지울 수 없다(소스 판독 2026.8.0 — 실측 T081 · VD-T081-4). 그래서 사용자 단위 폐기는 30일짜리 하한 키를 함께 남기고, `/session/check`가 「하한 > 세션 시작 시각」이면 inactive를 낸다. 정본은 같은 `session_revocation_log`의 사용자 단위 행(`sid` NULL)이다(새 표 · 새 열 없음). `sid` 행은 하한을 만들지 않는다. 키 이름에 epoch를 쓰지 않는다(폐지된 센티널과 헷갈린다).
- 하한 수명의 30일은 로그 보존(`expires_at + 30 d`)과 `/session/check`의 세션 절대 수명(`now − iat > 30 d`면 inactive)이 함께 쓰는 상수 하나다. 하한 수명(`nbf` + 330 s + 30 d) ≥ 세션 최대 나이(30 d)라서, 폐기 전에 시작한 세션은 하한이 사는 동안은 하한이, 그 뒤에는 나이가 막는다(겹침 330 s). 하한이 막는 것은 폐기 전에 만든 BFF 세션이다 — Authentik 로그인 세션이 살아 있는 기기의 재로그인은 막지 않는다(contracts/bff-api.md).

## 조회 규약 (모든 pod)

1. JWT 검증(JWKS·`iss`·`aud`·`exp`·`nbf`) 통과 뒤 `GET revoked:sub:{sub}` + (`sid` 클레임이 있으면) `EXISTS revoked:sid:{sid}`를 파이프라인 1회로 보낸다. BFF가 pod를 부를 때 쓰는 교환 토큰에는 `sid` 클레임이 없다(Authentik의 토큰 교환은 세션 없이 토큰을 만든다 — 소스 판독 · 실측 T081). 그래서 pod 경계에서 `revoked:sid`는 조회되지 않고, pod의 즉시 거부는 `revoked:sub`(사용자 단위 폐기)에서만 성립한다. `sid` 단위 폐기는 BFF의 `/session/check`(`sid` 질의)와 BFF의 refresh 폐기로 집행된다(T073 보정 2026-11-12).
2. `revoked:sub` 값(`nbf`) > 토큰 `iat` → 401 `session_revoked`. `revoked:sid` 존재 → 401 `session_revoked`.
3. **fail-closed**: Dragonfly 연결 실패·타임아웃(`socket_timeout` 0.2 s)·NOPERM 등 어떤 오류든 비헬스 경로는 503 RFC 9457 `type: https://joshuatech.dev/problems/denylist-unavailable`. 헬스 경로(`/healthz`·`/ready`·`/health`)는 거부 목록을 조회하지 않는다. **클라이언트 재시도 0**: 어느 생성 경로든 `retry=Retry(NoBackoff(), 0)`과 `socket_connect_timeout` 0.2 s를 **명시**한다. 근거(redis-py 8.1.0 실측 · 소스): `Redis(...)` 생성자 기본값은 `ExponentialWithJitterBackoff` 10회 재시도라 연결 거부 ≈ 4.7 s · 응답 없는 소켓 ≈ 6.8 s 뒤에야 실패하고, `Redis.from_url()`은 retry 미지정 시 `Retry(NoBackoff(), 0)`이다 — 어느 기본값에도 기대지 않는다(기본값 변경 방어). 맺어진 연결에서는 판정이 타임아웃 0.2 s 안에 끝나고(`retries=0` 실측 0.20–0.22 s · 새 연결 · DNS는 아래 문장 · T070 r3 문구) 재시도는 호출자(BFF)의 몫이다(T062 보정 2026-11-02 · 리뷰 B-7). 0.2 s는 소켓 동작마다의 상한이다 — DNS 해석(`getaddrinfo`)은 시간 제한 밖이고, 새 연결은 핸드셰이크 왕복(HELLO · AUTH · CLIENT SETINFO 등 최대 4)마다 0.2 s가 따로 걸린다(T070 r2).
4. 결과를 pod 안에서 캐시하지 않는다(BFF의 `/session/check` 2 s 캐시는 BFF 계층의 것).
5. 메트릭: `denylist_lookup_seconds`(histogram · 조회 1회 = 관측 1회), 레이블 `result` = `ok`(키 없음) · `revoked`(폐기 키가 하나라도 있었다 — 판정이 아니다: 오래된 sub 키로 200인 요청도 `revoked`로 센다 · 거부한 요청 수는 401 응답 지표로 본다) · `error`(조회 실패) · T070 r2.
6. 공개 API(T070 보정 2026-11-05): `django_common.auth.Denylist().lookup(sub, sid=None) -> DenylistRecord(sub_nbf, sid_revoked)` · `DenylistRecord.revokes(iat)`(T073 `/session/check`가 같은 것을 쓴다). `DRAGONFLY_URL`은 호출 시점에 읽는다. URL에 쿼리가 있으면 조회 실패(503)로 본다 — redis-py는 URL 쿼리를 키워드 인자보다 우선해 타임아웃 · 재시도 설정을 덮어쓴다. 값이 정수가 아니면 조회 실패(503)다. 예외 메시지(키 = sub · URL)는 응답 · 로그 · 연쇄 예외에 싣지 않는다. `lookup`의 `sub`는 비지 않은 str · `sid`는 None 또는 비지 않은 str이어야 하고 어기면 `TypeError` · `ValueError`다(호출자 오류 — T073은 질의 검증 400을 앞에 둔다). 클라이언트는 인스턴스 안에 URL별로 두므로 호출자는 인스턴스 하나를 재사용한다(T070 r2).
7. 세션 하한은 identity-admin `/session/check`만 조회한다(거부 목록 조회 뒤의 둘째 왕복 `GET` · 뷰 소유 클라이언트 · 0.2 s · 재시도 0 · 실패나 ASCII 숫자 1–19자가 아닌 값은 503 `denylist_unavailable`(T073 보정 2026-11-16 — 이전 문구 「정수가 아닌 값」) · 첫 조회가 실패하면 둘째를 하지 않는다). 모든 pod의 미들웨어 조회와 `Denylist.lookup`은 2키 그대로다 — 다른 pod 사용자는 `identity-admin:*`를 읽지 못한다(T073 보정 2026-11-12).

## 쓰기 규약 (identity-admin만)

- `/sessions/revoke`·웹훅(· 일 1회 대조 보정 · 관리 명령 `revoke_sessions`): `session_revocation_log` INSERT + outbox INSERT 트랜잭션 커밋 **후** SET한다(T073 보정 2026-11-12). `sid` 행은 `SET revoked:sid:{sid} 1 EX min(330, ⌊expires_at − 현재 시각⌋)`다(이 키는 BFF의 `/session/check`가 `sid` 질의로 읽는다 — pod 미들웨어는 교환 토큰에 `sid`가 없어 조회하지 않는다 · §조회 규약 1). 사용자 단위 행(`sid` NULL)은 DB에서 그 `sub`의 사용자 단위 행 가운데 `nbf`가 가장 큰 행을 한 번 읽어(자기 행 값이 아니다 — 늦게 끝난 요청이나 과거 `nbf` 웹훅이 더 큰 값을 덮지 않게) `SET revoked:sub:{sub} <그 nbf> EX min(330, ⌊그 행 expires_at − 현재 시각⌋)`와 `SET identity-admin:session-floor:{sub} <그 nbf> EX ⌊그 행 expires_at + 30 d − DB now()⌋`를 한 파이프라인으로 보낸다. 남은 TTL이 1초 미만인 키는 쓰지 않는다(`EX 0`은 오류다). 쓰기 클라이언트도 0.2 s · 재시도 0이다. Dragonfly SET 실패는 로그만 남긴다 — Celery 재시도를 넣지 않는다(브로커가 같은 Dragonfly라 함께 실패하고 응답만 늦어진다). 아래 30 s 재적용이 반영한다.
- **30 s 무조건 재적용(Celery beat)**: 30초마다 `session_revocation_log`에서 `expires_at > now()`인 행을 **조건 없이 전부** 다시 SET한다(남은 TTL = `expires_at - now()`, 초 단위 내림). 기동 시에도 같은 절차를 1회 실행한다. `SET`은 멱등이므로 캐시가 살아 있어도 결과가 같고, 캐시가 비었으면 채워진다 — 캐시 상태를 묻는 조회(`EXISTS`)를 먼저 하지 않는다. 같은 키로 가는 행이 여럿이면 `nbf`가 가장 큰 행의 값 · TTL로 쓴다. 남은 TTL이 1초 미만인 키는 건너뛴다. 같은 실행이 세션 하한 키도 되살린다 — `sid`가 NULL이고 `expires_at + 30 d > now()`인 행을 `sub`별로 묶어 `nbf`가 가장 큰 행으로 SET한다(TTL = 그 행 `expires_at + 30 d − now()` 초 내림). 끝에 신선도 키 `identity-admin:denylist:reapplied-at`을 `EX 300`으로 쓴다(행이 0이어도 쓴다). SET은 파이프라인으로 보내고 명령 단위 실패는 건수만 로그에 남긴다(T073 보정 2026-11-12). 재적용은 실행마다 첫 묶음을 보내기 전에 쓰기 클라이언트의 유휴 연결을 버리고 새 연결로 보낸다 — 재시도가 아니다(재시도 0은 그대로다). FIN이 닿지 않은 끊김(노드 사망 · 분할) 뒤에 살아 보이는 죽은 연결이 tick 하나를 실패시켜 유실 창을 30초 늘리지 않게 한다. FIN · RST가 닿은 끊김(Dragonfly 재기동 · SIGKILL)은 Linux에서 풀이 연결을 꺼낼 때 알아채 다시 붙으므로 버리지 않아도 다음 tick이 성공한다(실측 — linux/amd64 컨테이너 · redis-py 8.1.0 · 운영 토폴로지 값은 T085). 그 대신 tick마다 이름 조회(시간 제한 밖 — §조회 규약 3) · 연결 · 핸드셰이크 왕복(최대 4)이 든다(T073 보정 2026-11-13).
  - 행 수: `revoked:*` 대상은 최근 330 s의 활성 행(수 건)이고, 세션 하한 대상은 최근 30일 + 330 s의 사용자 단위 행이다(SP-1 규모에서 수십–수백 행 · 키는 그 기간에 폐기된 `sub` 수 — 추론). 30초마다 전량 SET해도 비용이 무시할 수준이다. 규모가 커지면(사용자 단위 행 10^5 이상) 인덱스 + 증분 재적용(tick마다 최근 행만 · 전량은 기동과 N분 주기)으로 바꾸되 "무조건"은 유지한다(T073 보정 2026-11-12).
  - 남는 경합: 요청 경로에서 자기 행 값으로 덮는 경합은 없앴다(커밋 뒤 최댓값 조회). 「조회 뒤 SET」 경합은 재적용과 요청 경로의 커밋 뒤 쓰기 사이, 커밋 뒤 쓰기 둘 사이에 남는다 — 조회한 뒤 SET하는 사이에 커밋된 더 큰 `nbf`를 낡은 조회 값으로 덮을 수 있다(창은 ms). 다음 재적용이 되돌린다(≤ 다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속 · 받아들인다 · T073 보정 2026-11-12).
- **유실 창**: Dragonfly가 **정상 종료**하면 종료 시 스냅샷을 저장하고 재기동 때 자동 적재하므로 키가 남는다. 거부 목록 공백은 **비정상 종료**(OOM kill·SIGKILL·스냅샷 저장 실패)일 때만 생기고, 그때도 상한은 **다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속**이다(이전 문구 「최대 30초」 — solo 워커는 받은 순서대로 돌고 그동안의 30 s tick은 `expires` 30으로 버려진다). 그 공백을 줄이려고 pod가 DB를 직접 보지는 않는다(fail-closed와 30 s 재적용으로 충분). 유실 창에는 세션 하한도 없다(키 없음 = 통과). 그 사이 `/session/check`에 닿은 폐기 전 세션은 active로 보이지만, 재적용이 돌아오면 다음 확인에서 다시 inactive가 된다(하한이 사는 동안은 하한, 그 뒤에는 절대 수명). 재적용이 멈춘 채 유실되면 키가 돌아오지 않는다 — 신선도 키와 재적용 성공 줄 무소식 경보(T098)가 그 탐지다(T073 보정 2026-11-12).
  - Dragonfly Deployment에 `terminationGracePeriodSeconds: 60`을 **명시**한다(기본 30 s에 기대지 않는다 — T057). 스냅샷 저장이 끝나기 전에 SIGKILL이 오면 위 유실 창에 들어간다.
- 로그 purge: 일 1회 `expires_at + 30 d < now()` 행 삭제(data-model §3). 이 경계는 세션 하한 수명과 같은 식 · 같은 상수다 — 하한이 사는 동안 그 행은 DB에 있다(T073 보정 2026-11-12).

## ACL (Dragonfly `--aclfile /etc/dragonfly/users.acl`)

ACL 파일은 Secret으로 마운트하며 값의 원천은 Vault `kv/{env}/dragonfly/acl`(ESO, store `vault-data`). 사용자별 비밀번호의 원천은 `kv/{env}/dragonfly/<user>`이고 ACL 파일의 비밀번호는 그 값과 같아야 한다(회전은 둘을 함께 갱신 — 런북 `secret-rotation.md`).

| 사용자 | ACL | 용도 |
|---|---|---|
| `admin` | `+@all` (전 키) | 운영자·런북 전용. pod에 배포하지 않는다 |
| `identity-admin` | `~revoked:* ~identity-admin:* +@all` | 거부 목록 쓰기 + 자기 Celery 큐·캐시 |
| `<pod>`(템플릿 기본) | `%R~revoked:* ~<pod>:* +@all` | 거부 목록 **읽기 전용**(`%R~`) + 자기 접두(`<pod>:*`) 전권 |
| `sample-pod`(검사용) | `%R~revoked:* ~sample-pod:* +@all` | T051이 템플릿 규칙을 실제로 검증할 때 쓰는 고정 사용자. **dev 전용 — prod aclfile(`kv/prod/dragonfly/acl`)에는 넣지 않는다**(T057) |

- **키 패턴과 명령 카테고리는 짝지어지지 않는다.** `~revoked:* +@read ~<pod>:* +@all` 같은 표기는 "`revoked:*`에는 읽기만"을 뜻하지 않는다(패턴 목록과 명령 목록이 독립적으로 합쳐져 `DEL revoked:*`가 허용된다). 읽기 전용은 반드시 **읽기 전용 키 패턴 `%R~`** 로 표현한다.
- 그래서 `<pod>` 사용자는 `GET revoked:sub:x` 성공, `DEL revoked:sub:x`·`SET revoked:sub:x` → NOPERM, `SET identity-admin:x` → NOPERM이다.
- selector 문법(Redis 7 `(%R~… +get)`)과 "읽기용·쓰기용 사용자 2개 분리" 대안은 **채택하지 않는다** — Dragonfly는 selector를 지원하지 않고, `%R~`만으로 목적이 달성된다.
- 키 접두 규약: pod가 만드는 모든 키는 `<pod>:` 접두를 가진다(Celery `broker_transport_options.global_keyprefix = "<pod>:"`, Django 캐시 `KEY_PREFIX = "<pod>"`). `revoked:*`는 identity-admin만 쓴다.
- `DRAGONFLY_URL = redis://<user>:<password>@dragonfly-<env>.data.svc:6379/0` — 사용자 이름 = pod 이름.
- 생성물 compose(`compose/dragonfly-dev.acl`)와 시험 conftest(`DRAGONFLY_USERS`)의 `identity-admin` 사용자도 위 표의 `identity-admin` 행 규칙이다(템플릿 기본 `%R~revoked:*`가 아니다 — 로컬 compose와 pod 사용자로 도는 시험에서 거부 목록 쓰기가 NOPERM이 되지 않게). 세션 하한 키와 신선도 키는 자기 접두(`identity-admin:`)라 ACL 변경이 없고, Celery 키와는 하위 이름 `session-floor:` · `denylist:`로 가른다(T073 보정 2026-11-12).

### VD-4 (검증 후 결정) — aclfile이 키 패턴을 로드하는가

- **기본 가정(문서 기본값)**: `--aclfile`에 `USER <name> ON ><password> %R~revoked:* ~<pod>:* +@all` 형식을 그대로 적고 Dragonfly v1.40.1이 이를 로드한다. (근거: ACL 키 패턴은 v1.14, pub/sub 패턴은 v1.22부터 지원되며 v1.40.1 `acl_family.cc` 로더가 이 형식을 처리한다. "aclfile은 키 패턴을 지원하지 않는다"는 문장은 2023-11 이후 갱신되지 않은 문서 잔재다.)
- **옵션 A**: `ACL LIST` 출력에 `%R~revoked:*`가 보이면 위 기본값을 그대로 확정한다.
- **옵션 B**: 로드 오류가 나면 `--aclfile`을 빼고 entrypoint에서 `ACL SETUSER`를 실행하는 래퍼로 바꾼다(같은 규칙, 값의 원천은 동일한 Vault 경로).
- **실측(사용자 동석)**: T057 배포 직후 `ACL LIST` 확인 + `<pod>` 사용자로 `DEL revoked:sub:x` → NOPERM. 결과를 `report.md`에 기록한다.
- 어느 쪽이 되든 **T051의 단언은 같다**(위 §ACL 표의 동작). 계약이 바뀌는 것은 "규칙을 어떻게 적재하는가"뿐이다.

## Vault 경로

| 경로 | 키 | store | 소비자 |
|---|---|---|---|
| `kv/{env}/dragonfly/acl` | `users.acl`(파일 전문) | `vault-data` | Dragonfly Deployment(Secret 마운트, `data` ns) |
| `kv/{env}/dragonfly/admin` | `password` | —(운영자 직접, ESO 소비자 없음) | 운영자(런북) |
| `kv/{env}/dragonfly/identity-admin` · `kv/{env}/dragonfly/<pod>` | `password`, `url` | `vault-{env}` | 해당 pod의 `<pod>-env` ExternalSecret(`DRAGONFLY_URL`) |

## 타임아웃 (공통 표에서 발췌)

| 구간 | 값 |
|---|---|
| Dragonfly `socket_timeout` / `socket_connect_timeout` | 0.2 s |
| BFF `/session/check` 결과 캐시 | 2 s |
| 무조건 재적용 beat | 30 s |
| Dragonfly `terminationGracePeriodSeconds` | 60 s |
| 거부 목록 · 세션 하한 쓰기(요청 경로 · 재적용) · 세션 하한 조회 | 0.2 s · 재시도 0(T073 보정 2026-11-12) |
| 세션 하한 키 수명 | 그 행 `expires_at + 30 d`까지 |
| 재적용 신선도 키 | 300 s |

## 검증 (tests-first)

- **T051**(`tests/platform/kafka.tests.ps1`, Dragonfly 절): `identity-admin` 사용자로 `SET revoked:sub:x` 성공; `sample-pod` 사용자로 `GET revoked:sub:x` 성공 · `DEL revoked:sub:x` → NOPERM · `SET identity-admin:x` → NOPERM; `ACL LIST` 출력에 `%R~revoked:*` 존재(VD-4).
- **T062**(`packages/django-common/tests/test_auth.py`): 거부 목록 조회 실패 → 비헬스 경로 503 fail-closed, 헬스 경로 면제, `revoked:sub` nbf > iat 401, `revoked:sid` 401.
- **T066**(`apps/identity-admin/tests/test_api.py`): 캐시를 비운 뒤(센티널 없음) **무조건 재적용** 한 번이 `expires_at > now()` 행을 전부 되살리는지 — SIGKILL 재시작 시나리오(시험은 beat 주기 30 s와 작업 결과로 본다 · 복구 시간의 상한은 §쓰기 규약 「유실 창」 · T073 보정 2026-11-12 — 이전 문구 「30 s 안에 무조건 재적용」); `expires_at + 30 d` purge; `SET`이 멱등이라 재적용을 여러 번 돌려도 TTL이 늘지 않음.
- **T073**(`apps/identity-admin/tests/test_identity_*.py`): 사용자 단위 폐기 3경로 → 세션 하한 값 · TTL · `sid` 폐기는 하한 없음 · `/session/check` 판정 표(하한만 · 같음 · ASCII 숫자 1–19자 아님 503 · 나이 경계 · 미래 `iat`) · 재적용의 하한 복원(창 경계 · `sub`별 최댓값 · TTL 비증가) · purge 대상 ⇔ 하한 대상 아님 · 신선도 키 · 교환 토큰 꼴(`sid` 없음)의 Bearer는 `revoked:sid`에 걸리지 않음(한계 고정).
- **T085**(US4 E2E): Dragonfly SIGKILL 후 폐기된 세션이 다시 401이 되기까지의 시간 — 상한은 §쓰기 규약 「유실 창」(이전 문구 「≤ 30 s 안에」). 330초 넘게 쉰 기기와 복사 쿠키가 사용자 단위 폐기 뒤 다음 접촉에서 401인지 · SIGKILL 뒤 세션 하한 키까지 복구되는 시간(T073 보정 2026-11-12).
