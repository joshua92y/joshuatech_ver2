# Contract: 세션 거부 목록 (Dragonfly 키 스키마 · ACL)

소유 identity-admin. 정본은 DB 테이블 `session_revocation_log`(data-model §3)이고 Dragonfly는 **파생 캐시**다. 모든 pod의 인증 미들웨어(`django_common.auth.Denylist`)가 JWT 검증 뒤 이 키를 1회 조회한다. 인스턴스: `data` ns `dragonfly-dev`·`dragonfly-prod`(6379), env마다 하나.

## 키 스키마

| 키 | 값 | TTL | 쓰는 쪽 | 의미 |
|---|---|---|---|---|
| `revoked:sub:{sub}` | `nbf`(epoch 초, 정수) | 330 s | identity-admin | `iat < nbf`인 토큰은 거부 — 전체 기기 로그아웃·관리자 폐기·테넌트 정지 |
| `revoked:sid:{sid}` | `1` | 330 s | identity-admin | 특정 세션(`sid`)의 토큰만 거부 — 단일 기기 로그아웃 |
| `denylist:epoch` | identity-admin 기동 시각(epoch 초) | 없음 | identity-admin | 센티널. 없으면 Dragonfly가 비워진 것(재시작·flush) → `session_revocation_log` 재적용 |

- TTL 330 s = access 토큰 TTL 300 s + 30 s 여유. `expires_at`(DB) = `nbf` + 330 s.
- 키 이름은 spec·`Denylist`·테스트(T061)에서 이 표 그대로 쓴다(`revoked:{sub}` 같은 축약형 금지).
- `{sub}`·`{sid}`는 Authentik 토큰 클레임 값 그대로(인코딩 없음).

## 조회 규약 (모든 pod)

1. JWT 검증(JWKS·`iss`·`aud`·`exp`·`nbf`) 통과 뒤 `GET revoked:sub:{sub}` + (`sid` 클레임이 있으면) `EXISTS revoked:sid:{sid}`를 파이프라인 1회로 보낸다.
2. `revoked:sub` 값(`nbf`) > 토큰 `iat` → 401 `session_revoked`. `revoked:sid` 존재 → 401 `session_revoked`.
3. **fail-closed**: Dragonfly 연결 실패·타임아웃(`socket_timeout` 0.2 s)·NOPERM 등 어떤 오류든 비헬스 경로는 503 RFC 9457 `type: https://joshuatech.dev/problems/denylist-unavailable`. 헬스 경로(`/healthz`·`/ready`·`/health`)는 거부 목록을 조회하지 않는다.
4. 결과를 pod 안에서 캐시하지 않는다(BFF의 `/session/check` 2 s 캐시는 BFF 계층의 것).
5. 메트릭: `denylist_lookup_seconds`(histogram), 오류는 `denylist_lookup_seconds{result="error"}`.

## 쓰기 규약 (identity-admin만)

- `/sessions/revoke`·웹훅: `session_revocation_log` INSERT + outbox INSERT 트랜잭션 커밋 **후** `SET revoked:sub:{sub} <nbf> EX 330`(또는 `SET revoked:sid:{sid} 1 EX 330`). Dragonfly SET 실패는 로그 + 재시도(Celery); 30 s 대조가 결국 반영한다.
- 기동 시: `SET denylist:epoch <now>` → `session_revocation_log`에서 `expires_at > now()`인 행을 전부 SET(남은 TTL = `expires_at - now()`).
- 30 s 대조(Celery beat): `EXISTS denylist:epoch`가 0이면 기동 시 절차를 다시 실행한다. Dragonfly만 재시작된 경우 거부 목록 공백은 최대 30 s.
- 로그 purge: 일 1회 `expires_at + 30 d < now()` 행 삭제(data-model §3).

## ACL (Dragonfly `--aclfile /etc/dragonfly/users.acl`)

ACL 파일은 Secret으로 마운트하며 값의 원천은 Vault `kv/{env}/dragonfly/acl`(ESO). 사용자별 비밀번호의 원천은 `kv/{env}/dragonfly/<user>`이고 ACL 파일의 비밀번호는 그 값과 같아야 한다(회전은 둘을 함께 갱신 — 런북 `secret-rotation.md`).

| 사용자 | ACL | 용도 |
|---|---|---|
| `admin` | `+@all` (전 키) | 운영자·런북 전용. pod에 배포하지 않는다 |
| `identity-admin` | `~revoked:* ~identity-admin:* +@all` | 거부 목록 쓰기 + 자기 Celery 큐·캐시 |
| `<pod>`(템플릿 기본) | `~revoked:* +@read ~<pod>:* +@all` | 거부 목록 읽기 전용 + 자기 접두(`<pod>:*`) 전권 |

- 키 접두 규약: pod가 만드는 모든 키는 `<pod>:` 접두를 가진다(Celery `broker_transport_options.global_keyprefix = "<pod>:"`, Django 캐시 `KEY_PREFIX = "<pod>"`). `revoked:*`는 identity-admin만 쓴다.
- `DRAGONFLY_URL = redis://<user>:<password>@dragonfly-<env>.data.svc:6379/0` — 사용자 이름 = pod 이름.
- 검증: T050이 `<pod>` 사용자로 `DEL revoked:x`·`SET revoked:x` → NOPERM, `identity-admin` 사용자로 성공을 단언한다. T061이 fail-closed 503, T072가 30 s 대조(`denylist:epoch` 삭제 → 30 s 내 재적용)를 검증한다.

## Vault 경로

| 경로 | 키 | 소비자 |
|---|---|---|
| `kv/{env}/dragonfly/acl` | `users.acl`(파일 전문) | Dragonfly Deployment(Secret 마운트, `data` ns) |
| `kv/{env}/dragonfly/admin` | `password` | 운영자(런북) |
| `kv/{env}/dragonfly/identity-admin` · `kv/{env}/dragonfly/<pod>` | `password`, `url` | 해당 pod의 `<pod>-env` ExternalSecret(`DRAGONFLY_URL`) |

## 타임아웃 (공통 표에서 발췌)

| 구간 | 값 |
|---|---|
| Dragonfly `socket_timeout` / `socket_connect_timeout` | 0.2 s |
| BFF `/session/check` 결과 캐시 | 2 s |
| 30 s 대조 beat | 30 s |
