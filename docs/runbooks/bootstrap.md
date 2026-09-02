# Runbook: bootstrap

## 문서 목적·전제

이 문서는 003-platform-foundation의 플랫폼 부트스트랩 전 과정을 기록하는 **살아 있는 런북**이다. §0(사용자 수동 준비)만 T005에서 완성되고, §1–§6은 각 절에 표기된 후속 task가 실제 실행 결과(순서·시각·기록값)를 채운다. §번호는 다른 task들이 참조하므로 바꾸지 않는다.

- 전제: OCI 인스턴스 2대(노드 A `joshtech_api_1st`, 노드 B `joshtech_cache`)가 존재하고, 도메인 `joshuatech.dev`가 Cloudflare 존으로 관리된다.
- 런북 규약(FR-041): 각 절은 목적·전제·절차·검증·되돌리기를 갖춘다.

## §0 사용자 수동 준비 (T005)

**목적**: 에이전트가 대신할 수 없는 계정 온보딩·키 생성·토큰 발급을 부트스트랩 시작 전에 운영자가 마치고, 완료를 체크리스트로 확인한다.

- 전제: 운영자 본인의 브라우저·CLI 세션에서 수행한다(에이전트·CI에 위임 금지).
- 절차: 아래 체크리스트 각 항목의 콘솔 경로/명령.
- 검증: 이 체크리스트 자체가 검증이다(전 항목 체크 = §0 완료).
- 되돌리기: N/A — 계정·키 생성은 되돌릴 대상이 없고, 폐기·회전은 토큰 표 ⑥·⑦과 `docs/runbooks/secret-rotation.md`의 절차를 따른다.

### 완료 확인 체크리스트

- [x] **Cloudflare Zero Trust 온보딩** — 팀 이름 `joshua-tech`, 팀 도메인 `joshua-tech.cloudflareaccess.com`(이 도메인이 Access JWT의 `iss`이자 JWKS 원천이다), Free 플랜 — 결제수단 등록·청구 없음.
- [x] **Grafana Cloud Free 스택(ap 리전)** — org `joshuatech`, 스택 `https://joshuatech.grafana.net/`.
- [ ] **Grafana Cloud Alloy 전송용 Access policy 토큰** — Grafana Cloud 포털(grafana.com) → Security → Access Policies → Create access policy(realm: 스택 `joshuatech`, scopes: `metrics:write`·`logs:write`·`traces:write`) → Add token. 값은 비밀번호 관리자에만 기록(토큰 표 참고).
- [x] **Sentry Developer org** — org `joshtech`, 팀 `joshtech`.
- [ ] **Sentry 프로젝트 2** — sentry.io org `joshtech` → Projects → Create Project로 `identity-admin`·`web` 생성.
- [ ] **OCI 서비스 사용자 `svc-tfstate`·`svc-s3-backup` + Customer Secret Key 각 1** — OCI 콘솔 → Identity & Security → Domains → (기본 도메인) → Users에서 두 사용자 생성 → 각 사용자 상세 → Customer secret keys → Generate secret key 1개(Secret은 생성 시 1회만 표시 — 즉시 비밀번호 관리자에 기록). 접근은 버킷 1개씩만: `svc-tfstate` → `jt-tfstate`, `svc-s3-backup` → `jt-backup`(IAM 정책 선언·적용은 T010, 교차 버킷 정책 0).
- [ ] **운영자 `age` 키쌍** — `age-keygen`으로 생성. 공개키만 노드 A에 둔다(T036 `platform-backup.sh`가 암호화에 사용). 개인키는 Vault recovery key와 같은 오프라인 보관 — 노드·저장소·클라우드에 두지 않는다.
- [ ] **SSH 키 `jt-ops`** — FIDO2 `ssh-keygen -t ed25519-sk -f ~/.ssh/jt-ops` 또는 passphrase 키 + `ssh-add -c`(사용마다 확인). T014에서 두 노드 `~ubuntu/.ssh/authorized_keys`를 이 키로 교체한다(구 v1 키 제거 — 개인키 파기 순서는 토큰 표 ⑦).
- [ ] **GitHub secret scanning + push protection 활성** — `joshua92y/joshuatech_ver2`(모노레포)와 `joshua92y/platform-gitops`(T003 생성 후) 각각 Settings → Code security and analysis → Secret scanning **Enable** + Push protection **Enable**(T116이 재확인).
- [ ] **토큰 표 ①–⑤ 발급** — 아래 표의 스코프 그대로 발급(⑥·⑦은 발급 항목이 아니라 운영 규칙이다).

### 토큰 표

| 토큰 | 스코프 | 보관처 | 회전 |
|---|---|---|---|
| ① Cloudflare **배포 토큰**(OpenTofu용) | 존 `joshuatech.dev` 한정 — Zone:Read · DNS:Edit · Zone Settings:Edit · Access: Apps and Policies:Edit · Workers Scripts:Edit · Workers Routes:Edit. 계정 단위 권한은 필요한 것만 | 비밀번호 관리자(Vault 투입 전) | secret-rotation 매트릭스·캘린더 대조* |
| ② Cloudflare **`Account Analytics:Read`** | Workers 사용량 검증 전용, 쓰기 0 | 비밀번호 관리자 | secret-rotation 매트릭스·캘린더 대조* |
| ③ OCI 읽기 사용자 **`svc-verify`** | 그룹 `jt-verify`: `jt-backup`·`jt-backup-platform` inspect/read objects + read usage-reports·budgets·instance-family, **manage 0**. API 키를 상주시키지 않고 `oci session authenticate --profile-name svc-verify`(1 h) 세션 토큰으로만 사용 | 상주 자격 없음(세션 토큰 1 h 자동 만료). 사용자 로그인 자격은 비밀번호 관리자 | 세션 토큰은 1 h 만료로 회전 불요; 계정 자격은 secret-rotation 대조* |
| ④ Grafana Cloud **Viewer 서비스 계정 토큰** | Viewer(읽기 전용) | 비밀번호 관리자 | secret-rotation 매트릭스·캘린더 대조* |
| ⑤ Sentry **읽기 전용 auth token** | 읽기 전용 | 비밀번호 관리자 | secret-rotation 매트릭스·캘린더 대조* |
| ⑥ Vault 토큰 | 상시 토큰을 만들지 않는다 — 사람은 Authentik OIDC 로그인으로 받는 **단기 토큰**(기본 TTL 1 h)만 쓴다. `vault operator init`의 root 토큰은 부트스트랩 직후 `vault token revoke` | 보관하지 않음. recovery key는 오프라인(`generate-root`·rekey 전용, unseal 수단 아님) | 단기 토큰 자동 만료; root 토큰은 즉시 폐기 |
| ⑦ **v1 SSH 개인키 파기 순서** | T014에서 `authorized_keys`를 `jt-ops`로 교체 → T103에서 두 노드 `authorized_keys`에 구 키 0 확인 → T105 잔여 확인 후에야 워크스테이션·비밀번호 관리자에서 v1 개인키 삭제. **순서를 앞당기면 잠긴다** | 파기 전까지 현 위치 유지(워크스테이션·비밀번호 관리자) | N/A(회전이 아니라 파기 절차) |

\* 회전 열의 정본은 `docs/runbooks/secret-rotation.md`(T084 작성, T114 완성)의 매트릭스·캘린더이며, 이 표의 회전 주기는 그 문서와 대조한다.

### 보관 원칙

모든 값(토큰·Secret Key·시드)은 Vault 투입 전까지 **비밀번호 관리자에만** 둔다. 저장소·채팅에 붙여 넣는 것을 금지하며, CI의 gitleaks job이 저장소 유입을 막는다(push protection이 push 단계에서 한 번 더 막는다).

## §1 OpenTofu 부트스트랩

(T007–T011에서 작성)

## §2 재이미지·host-prep

(T013–T014에서 작성)

## §3 K3s·Argo

(T035–T041에서 작성)

## §4 Vault init·시크릿 시드

(T043–T045에서 작성)

## §5 v1 삭제 기록

(T104–T105에서 작성)

## §6 업그레이드 창

(T037에서 작성)
