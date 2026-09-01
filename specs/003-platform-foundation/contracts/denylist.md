# Contract: 세션 거부 목록 (Dragonfly 키 스키마 · ACL)

소유 identity-admin. 정본은 DB 테이블 `session_revocation_log`(data-model §3)이고 Dragonfly는 **파생 캐시**다. 모든 pod의 인증 미들웨어(`django_common.auth.Denylist`)가 JWT 검증 뒤 이 키를 1회 조회한다. 인스턴스: `data` ns `dragonfly-dev`·`dragonfly-prod`(6379), env마다 하나.

## 키 스키마

| 키 | 값 | TTL | 쓰는 쪽 | 의미 |
|---|---|---|---|---|
| `revoked:sub:{sub}` | `nbf`(epoch 초, 정수) | 330 s | identity-admin | `iat < nbf`인 토큰은 거부 — 전체 기기 로그아웃·관리자 폐기·테넌트 정지 |
| `revoked:sid:{sid}` | `1` | 330 s | identity-admin | 특정 세션(`sid`)의 토큰만 거부 — 단일 기기 로그아웃 |

- **센티널 키 `denylist:epoch`는 쓰지 않는다**(폐지). 아래 §쓰기 규약의 무조건 재적용이 그 역할을 대신한다.
- TTL 330 s = access 토큰 TTL 300 s + 30 s 여유. `expires_at`(DB) = `nbf` + 330 s.
- 키 이름은 spec·`Denylist`·테스트(T062)에서 이 표 그대로 쓴다(`revoked:{sub}` 같은 축약형 금지).
- `{sub}`·`{sid}`는 Authentik 토큰 클레임 값 그대로(인코딩 없음).

## 조회 규약 (모든 pod)

1. JWT 검증(JWKS·`iss`·`aud`·`exp`·`nbf`) 통과 뒤 `GET revoked:sub:{sub}` + (`sid` 클레임이 있으면) `EXISTS revoked:sid:{sid}`를 파이프라인 1회로 보낸다.
2. `revoked:sub` 값(`nbf`) > 토큰 `iat` → 401 `session_revoked`. `revoked:sid` 존재 → 401 `session_revoked`.
3. **fail-closed**: Dragonfly 연결 실패·타임아웃(`socket_timeout` 0.2 s)·NOPERM 등 어떤 오류든 비헬스 경로는 503 RFC 9457 `type: https://joshuatech.dev/problems/denylist-unavailable`. 헬스 경로(`/healthz`·`/ready`·`/health`)는 거부 목록을 조회하지 않는다.
4. 결과를 pod 안에서 캐시하지 않는다(BFF의 `/session/check` 2 s 캐시는 BFF 계층의 것).
5. 메트릭: `denylist_lookup_seconds`(histogram), 오류는 `denylist_lookup_seconds{result="error"}`.

## 쓰기 규약 (identity-admin만)

- `/sessions/revoke`·웹훅: `session_revocation_log` INSERT + outbox INSERT 트랜잭션 커밋 **후** `SET revoked:sub:{sub} <nbf> EX 330`(또는 `SET revoked:sid:{sid} 1 EX 330`). Dragonfly SET 실패는 로그 + 재시도(Celery); 아래 30 s 재적용이 결국 반영한다.
- **30 s 무조건 재적용(Celery beat)**: 30초마다 `session_revocation_log`에서 `expires_at > now()`인 행을 **조건 없이 전부** 다시 SET한다(남은 TTL = `expires_at - now()`, 초 단위 내림). 기동 시에도 같은 절차를 1회 실행한다. `SET`은 멱등이므로 캐시가 살아 있어도 결과가 같고, 캐시가 비었으면 채워진다 — 캐시 상태를 묻는 조회(`EXISTS`)를 먼저 하지 않는다.
  - 행 수는 SP-1 규모에서 수십 건이므로 30초마다 전량 SET해도 비용이 무시할 수준이다. 규모가 커지면 `expires_at` 인덱스 + 페이지 단위 SET으로 바꾸되 "무조건"은 유지한다.
- **유실 창**: Dragonfly가 **정상 종료**하면 종료 시 스냅샷을 저장하고 재기동 때 자동 적재하므로 키가 남는다. 거부 목록 공백은 **비정상 종료**(OOM kill·SIGKILL·스냅샷 저장 실패)일 때만 생기고, 그때도 **최대 30초**다. 그 30초를 줄이려고 pod가 DB를 직접 보지는 않는다(fail-closed와 30 s 재적용으로 충분).
  - Dragonfly Deployment에 `terminationGracePeriodSeconds: 60`을 **명시**한다(기본 30 s에 기대지 않는다 — T057). 스냅샷 저장이 끝나기 전에 SIGKILL이 오면 위 유실 창에 들어간다.
- 로그 purge: 일 1회 `expires_at + 30 d < now()` 행 삭제(data-model §3).

## ACL (Dragonfly `--aclfile /etc/dragonfly/users.acl`)

ACL 파일은 Secret으로 마운트하며 값의 원천은 Vault `kv/{env}/dragonfly/acl`(ESO, store `vault-data`). 사용자별 비밀번호의 원천은 `kv/{env}/dragonfly/<user>`이고 ACL 파일의 비밀번호는 그 값과 같아야 한다(회전은 둘을 함께 갱신 — 런북 `secret-rotation.md`).

| 사용자 | ACL | 용도 |
|---|---|---|
| `admin` | `+@all` (전 키) | 운영자·런북 전용. pod에 배포하지 않는다 |
| `identity-admin` | `~revoked:* ~identity-admin:* +@all` | 거부 목록 쓰기 + 자기 Celery 큐·캐시 |
| `<pod>`(템플릿 기본) | `%R~revoked:* ~<pod>:* +@all` | 거부 목록 **읽기 전용**(`%R~`) + 자기 접두(`<pod>:*`) 전권 |
| `sample-pod`(검사용) | `%R~revoked:* ~sample-pod:* +@all` | T051이 템플릿 규칙을 실제로 검증할 때 쓰는 고정 사용자 |

- **키 패턴과 명령 카테고리는 짝지어지지 않는다.** `~revoked:* +@read ~<pod>:* +@all` 같은 표기는 "`revoked:*`에는 읽기만"을 뜻하지 않는다(패턴 목록과 명령 목록이 독립적으로 합쳐져 `DEL revoked:*`가 허용된다). 읽기 전용은 반드시 **읽기 전용 키 패턴 `%R~`** 로 표현한다.
- 그래서 `<pod>` 사용자는 `GET revoked:sub:x` 성공, `DEL revoked:sub:x`·`SET revoked:sub:x` → NOPERM, `SET identity-admin:x` → NOPERM이다.
- selector 문법(Redis 7 `(%R~… +get)`)과 "읽기용·쓰기용 사용자 2개 분리" 대안은 **채택하지 않는다** — Dragonfly는 selector를 지원하지 않고, `%R~`만으로 목적이 달성된다.
- 키 접두 규약: pod가 만드는 모든 키는 `<pod>:` 접두를 가진다(Celery `broker_transport_options.global_keyprefix = "<pod>:"`, Django 캐시 `KEY_PREFIX = "<pod>"`). `revoked:*`는 identity-admin만 쓴다.
- `DRAGONFLY_URL = redis://<user>:<password>@dragonfly-<env>.data.svc:6379/0` — 사용자 이름 = pod 이름.

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
| `kv/{env}/dragonfly/admin` | `password` | `vault-data` | 운영자(런북) |
| `kv/{env}/dragonfly/identity-admin` · `kv/{env}/dragonfly/<pod>` | `password`, `url` | `vault-{env}` | 해당 pod의 `<pod>-env` ExternalSecret(`DRAGONFLY_URL`) |

## 타임아웃 (공통 표에서 발췌)

| 구간 | 값 |
|---|---|
| Dragonfly `socket_timeout` / `socket_connect_timeout` | 0.2 s |
| BFF `/session/check` 결과 캐시 | 2 s |
| 무조건 재적용 beat | 30 s |
| Dragonfly `terminationGracePeriodSeconds` | 60 s |

## 검증 (tests-first)

- **T051**(`tests/platform/kafka.tests.ps1`, Dragonfly 절): `identity-admin` 사용자로 `SET revoked:sub:x` 성공; `sample-pod` 사용자로 `GET revoked:sub:x` 성공 · `DEL revoked:sub:x` → NOPERM · `SET identity-admin:x` → NOPERM; `ACL LIST` 출력에 `%R~revoked:*` 존재(VD-4).
- **T062**(`packages/django-common/tests/test_auth.py`): 거부 목록 조회 실패 → 비헬스 경로 503 fail-closed, 헬스 경로 면제, `revoked:sub` nbf > iat 401, `revoked:sid` 401.
- **T066**(`apps/identity-admin/tests/test_api.py`): 캐시를 비운 뒤(센티널 없음) **30 s 안에 무조건 재적용**이 `expires_at > now()` 행을 전부 되살리는지 — SIGKILL 재시작 시나리오; `expires_at + 30 d` purge; `SET`이 멱등이라 재적용을 여러 번 돌려도 TTL이 늘지 않음.
- **T085**(US4 E2E): Dragonfly SIGKILL 후 ≤ 30 s 안에 폐기된 세션이 다시 401이 되는지.
