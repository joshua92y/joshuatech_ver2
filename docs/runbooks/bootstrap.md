# Runbook: bootstrap

## 문서 목적·전제

이 문서는 003-platform-foundation의 플랫폼 부트스트랩 전 과정을 기록하는 **살아 있는 런북**이다. §0(사용자 수동 준비)만 T005에서 완성되고, §1–§7은 각 절에 표기된 후속 task가 실제 실행 결과(순서·시각·기록값)를 채운다. §번호는 다른 task들이 참조하므로 바꾸지 않는다.

- 전제: OCI 인스턴스 2대(노드 A `joshtech_api_1st`, 노드 B `joshtech_cache`)가 존재하고, 도메인 `joshuatech.dev`가 Cloudflare 존으로 관리된다.
- 런북 규약: 런북 8종의 목록은 FR-041이 정하고, 각 절의 구성(목적·전제·절차·검증·되돌리기)은 T114가 정한다.

## §0 사용자 수동 준비 (T005)

**목적**: 에이전트가 대신할 수 없는 계정 온보딩·키 생성·토큰 발급을 부트스트랩 시작 전에 운영자가 마치고, 완료를 체크리스트로 확인한다.

- 전제: 운영자 본인의 브라우저·CLI 세션에서 수행한다(에이전트·CI에 위임 금지).
- 절차: 아래 체크리스트 각 항목의 콘솔 경로/명령.
- 검증: 이 체크리스트 자체가 검증이다(전 항목 체크 = §0 완료).
- 되돌리기: N/A — 계정·키 생성은 되돌릴 대상이 없고, 폐기·회전은 토큰 표 ⑥·⑦과 `docs/runbooks/secret-rotation.md`의 절차를 따른다.

### 완료 확인 체크리스트

> **이름 예외 — OCI(사용자 결정 2026-09-03)**: 그룹 `jt-verify` → 실명 **`joshuatech-verify`**, 버킷 `jt-tfstate`·`jt-backup`·`jt-backup-platform` → 실명 **`joshuatech-tfstate`**(콘솔 생성 2026-09-03, versioning·NoPublicAccess·루트 컴파트먼트)·**`joshuatech-backup`**·**`joshuatech-backup-platform`**(뒤 2개는 T010 OpenTofu가 이 실명으로 생성). tasks·contracts·연구 문서의 `jt-*` 표기는 전부 이 실명으로 읽는다 — backend.tf·T010 IAM 정책·svc 사용자 스코프·백업 스크립트 포함.

> **이름 예외(사용자 결정 2026-09-02)**: GitHub App은 `jt-ci`가 아니라 **`joshuatech-gitapp-1`**(App ID 4800793)이고, 변수·시크릿 이름은 **`JOSHUATECH_CI_APP_CLIENT_ID`**(repo 변수)·**`JOSHUATECH_CI_APP_PRIVATE_KEY`**(Environment `production` 시크릿)다. tasks.md·contracts의 `jt-ci`·`jt-ci[bot]`·`JT_CI_APP_*` 표기는 전부 이 실제 이름으로 읽는다 — 봇 로그인은 `joshuatech-gitapp-1[bot]`(T033 validate lint·T074 워크플로·T115 증거가 이 로그인을 사용). App 권한: Contents RW · Pull requests RW · Metadata R(확인 2026-09-02). Environment `production` 배포 브랜치 = `main`(확인).

- [x] **GitHub App `joshuatech-gitapp-1`** — 생성·권한 3종·`JOSHUATECH_CI_APP_CLIENT_ID` repo 변수·`JOSHUATECH_CI_APP_PRIVATE_KEY` production 환경 시크릿 등록(2026-09-02). 모노레포·platform-gitops **두 저장소 설치 완료**(사용자 확인 2026-09-02). 2026-09-01 노출 키는 **재발급·재등록 완료**, App의 구 키 삭제·바탕화면 구 `.pem` 삭제까지 **운영자 확인 완료**(2026-09-03) — 항목 마감.
- [x] **Cloudflare Zero Trust 온보딩** — 팀 이름 `joshua-tech`, 팀 도메인 `joshua-tech.cloudflareaccess.com`(이 도메인이 Access JWT의 `iss`이자 JWKS 원천이다), Free 플랜 — 결제수단 등록·청구 없음.
- [x] **Grafana Cloud Free 스택(ap 리전)** — org `joshuatech`, 스택 `https://joshuatech.grafana.net/`.
- [x] **Grafana Cloud Alloy 전송용 Access policy 토큰** — Grafana Cloud 포털(grafana.com) → Security → Access Policies → Create access policy(realm: 스택 `joshuatech`, scopes: `metrics:write`·`logs:write`·`traces:write`) → Add token. 값은 비밀번호 관리자에만 기록(토큰 표 참고). 완료(2026-09-03): 정책 `joshuatech-grafana-alloy`(scopes 3종 write) + 동명 토큰 발급·비밀번호 관리자 보관 확인.
- [x] **Sentry Developer org** — org `joshtech`, 팀 `joshtech`.
- [x] **Sentry 프로젝트 2** — sentry.io org `joshtech` → Projects → Create Project로 생성: `identity-admin`(플랫폼 django) · `web`(플랫폼 javascript-nextjs). **이름 예외(사용자 결정 2026-09-02)**: 실제 프로젝트명은 **`joshtech-admin`**(django) · **`joshuatech-web`**(javascript-nextjs) — 이후 task의 `identity-admin`·`web` Sentry 프로젝트 표기는 이 실제 이름으로 읽는다(DSN 등록·알림 설정 포함). 생성 확인 2026-09-02.
- [x] **OCI 서비스 사용자 `svc-tfstate`·`svc-s3-backup` + Customer Secret Key 각 1** — OCI 콘솔 → Identity & Security → Domains → (기본 도메인) → Users에서 두 사용자 생성 → 각 사용자 상세 → Customer secret keys → Generate secret key 1개(Secret은 생성 시 1회만 표시 — 즉시 비밀번호 관리자에 기록). 접근은 버킷 1개씩만: `svc-tfstate` → `jt-tfstate`, `svc-s3-backup` → `jt-backup`(IAM 정책 선언·적용은 T010, 교차 버킷 정책 0). 완료(2026-09-03): 두 사용자 + Secret Key 각 1(`svc-tfstate-screat-key`·`svc-s3-backup-screat-key`) 생성·보관 확인.
- [x] **OCI 읽기 사용자 `svc-verify` 생성 + 그룹 `jt-verify` 가입** — 위 서비스 사용자 항목과 같은 콘솔(Identity & Security → Domains → (기본 도메인) → Users)에서 사용자 생성, Groups에서 `jt-verify` 생성 후 가입. 그룹에 붙는 정책 선언은 T010 OpenTofu 몫(스코프는 표 ③). 완료(2026-09-03): 사용자 생성·그룹 가입 — **이름 예외(사용자 결정 2026-09-03): 그룹 실명은 `joshuatech-verify`**(T010 정책·문서의 `jt-verify` 표기는 이 이름으로 읽는다). 실수로 생성됐던 Customer Secret Key `svc-verify-screat-key`는 표 ③ "상주 자격 없음" 원칙에 따라 **삭제 확인**(2026-09-03) — svc-verify는 세션 인증 전용.
- [ ] **운영자 `age` 키쌍** — §0에서는 키쌍 생성만: `age-keygen -o <오프라인 보관 파일>`. 공개키의 노드 배치는 T036 시점에 한다(노드 A는 T014 재이미지로 초기화되므로 §0에서 미리 두지 않는다). 개인키는 Vault recovery key와 같은 오프라인 보관 — 노드·저장소·클라우드에 두지 않는다.
- [ ] **SSH 키 `jt-ops`** — FIDO2 `ssh-keygen -t ed25519-sk -f ~/.ssh/jt-ops` 또는 passphrase 키 + `ssh-add -c`(사용마다 확인). T014에서 두 노드 `~ubuntu/.ssh/authorized_keys`를 이 키로 교체한다(구 v1 키 제거 — 개인키 파기 순서는 토큰 표 ⑦).
- [x] **GitHub secret scanning + push protection 활성** — `joshua92y/joshuatech_ver2`(모노레포)와 `joshua92y/platform-gitops` 각각 Settings → Advanced Security → Secret Protection에서 Secret scanning **Enable** + Push protection **Enable**(T116이 재확인). 완료(API 확인 2026-09-03): **두 저장소 모두 secret_scanning·push_protection enabled** ✅.
- [x] **토큰 ① Cloudflare 배포 토큰(OpenTofu용) 발급** — Cloudflare 대시보드 → My Profile → API Tokens → Create Token(스코프는 표 ① 그대로). 완료(2026-09-03): 토큰명 **`joshuatech-tofu-deploy`** — Account: Workers Scripts:Edit / Zone `joshuatech.dev` 한정: Zone:Read·DNS:Edit·Zone Settings:Edit·Access Apps and Policies:Edit·Workers Routes:Edit(표 ① 스코프와 일치), 비밀번호 관리자 보관. 참고: 별도 목적의 DNS 토큰 2종 추가 발급됨 — `joshuatech-cert-manager-dns01`·`joshuatech-ddns-dns-edit`(각 DNS:Edit + Zone:Read, 존 한정); cert-manager 토큰은 Vault kv 시드(T043)에서 소비 예정, ddns 토큰 용도·회전은 secret-rotation(T084)에서 기록.
- [x] **토큰 ② Cloudflare `Account Analytics:Read` 발급** — 같은 경로(My Profile → API Tokens → Create Token, 스코프는 표 ②). 완료(2026-09-03): 토큰명 **`joshuatech-analytics-read`**(Account Analytics:Read, 쓰기 0), 비밀번호 관리자 보관.
- [x] **③ `svc-verify` 세션 인증 확인** — 상주 토큰 없음: `oci session authenticate --profile-name svc-verify`(1 h) 동작 확인(사용자·그룹 생성은 위 항목, 스코프는 표 ③). 완료(2026-09-03): 브라우저 인증 성공, `C:\Users\2401\.oci\config`에 프로파일 `svc-verify` 기록(스모크: `oci iam region list --profile svc-verify --auth security_token`).
- [ ] **토큰 ④ Grafana Cloud Viewer 서비스 계정 토큰 발급** — Grafana Cloud → Administration → Service accounts → Viewer 계정 → Add service account token.
- [x] **토큰 ⑤ Sentry 읽기 전용 auth token 발급** — Sentry → Settings → Auth Tokens(read-only 스코프만). 완료(2026-09-03): 토큰명 `joshuatech-sentry-read`, 스코프 `alerts:read`·`event:read`·`org:read`·`project:read`·`team:read`(전부 read — 표 ⑤ 준수), 비밀번호 관리자 보관.

⑥·⑦은 발급 항목이 아니라 운영 규칙이다(아래 표).

> ⚠️ v1 SSH 개인키는 T105 잔여 확인 전 삭제 금지 — 앞당기면 두 노드에서 잠긴다.

### 토큰 표

| 토큰 | 스코프 | 보관처 | 회전 |
|---|---|---|---|
| ① Cloudflare **배포 토큰**(OpenTofu용) | 존 `joshuatech.dev` 한정 — Zone:Read · DNS:Edit · Zone Settings:Edit · Access: Apps and Policies:Edit · Workers Scripts:Edit · Workers Routes:Edit. 계정 단위 권한은 필요한 것만. **T011 실측 추가(2026-09-03)**: 룰셋 조회가 인증 오류 → Zone **Zone WAF:Edit**(Rate Limiting·Managed WAF 룰셋) + Account **Cloudflare Tunnel:Edit**·**Access: Organizations, Identity Providers, and Groups:Edit**(GitHub IdP)·**Access: Service Tokens:Edit**·**Workers R2 Storage:Edit**·**Access: Apps and Policies:Edit(Account 단위 — 재사용 정책은 계정 리소스라 존 권한만으로는 403 auth.forbidden)** — 기존 토큰 편집으로 추가(값 유지) | 비밀번호 관리자(Vault 투입 전) | secret-rotation 매트릭스·캘린더 대조* |
| ② Cloudflare **`Account Analytics:Read`** | Workers 사용량 검증 전용, 쓰기 0 | 비밀번호 관리자 | secret-rotation 매트릭스·캘린더 대조* |
| ③ OCI 읽기 사용자 **`svc-verify`** | 그룹 `jt-verify`(실명 `joshuatech-verify` — 이름 예외 2026-09-03): `jt-backup`·`jt-backup-platform` inspect/read objects + read usage-reports·budgets·instance-family, **manage 0**. API 키를 상주시키지 않고 `oci session authenticate --profile-name svc-verify`(1 h) 세션 토큰으로만 사용 | 상주 자격 없음(세션 토큰 1 h 자동 만료). 사용자 로그인 자격은 비밀번호 관리자 | 세션 토큰은 1 h 만료로 회전 불요; 계정 자격은 secret-rotation 대조* |
| ④ Grafana Cloud **Viewer 서비스 계정 토큰** | Viewer(읽기 전용) | 비밀번호 관리자 | secret-rotation 매트릭스·캘린더 대조* |
| ⑤ Sentry **읽기 전용 auth token** | 읽기 전용 | 비밀번호 관리자 | secret-rotation 매트릭스·캘린더 대조* |
| ⑥ Vault 토큰 | 상시 토큰을 만들지 않는다 — 사람은 Authentik OIDC 로그인으로 받는 **단기 토큰**(기본 TTL 1 h)만 쓴다. `vault operator init`의 root 토큰은 부트스트랩 직후 `vault token revoke` | 보관하지 않음. recovery key는 오프라인(`generate-root`·rekey 전용, unseal 수단 아님) | 단기 토큰 자동 만료; root 토큰은 즉시 폐기 |
| ⑦ **v1 SSH 개인키 파기 순서** | T014에서 `authorized_keys`를 `jt-ops`로 교체 → T103에서 두 노드 `authorized_keys`에 구 키 0 확인 → T105 잔여 확인 후에야 워크스테이션·비밀번호 관리자에서 v1 개인키 삭제(경고는 표 위 blockquote) | 파기 전까지 현 위치 유지(워크스테이션·비밀번호 관리자) | N/A(회전이 아니라 파기 절차) |

\* 회전 열의 정본은 `docs/runbooks/secret-rotation.md`(T084 작성, T114 완성)의 매트릭스·캘린더이며, 이 표의 회전 주기는 그 문서와 대조한다.

### 보관 원칙

모든 값(토큰·Secret Key·시드)은 Vault 투입 전까지 **비밀번호 관리자에만** 둔다. 저장소·채팅에 붙여 넣는 것을 금지하며, CI의 gitleaks job이 저장소 유입을 막는다(push protection이 push 단계에서 한 번 더 막는다).

## §1 OpenTofu 부트스트랩

### T007 — 상태 백엔드 (2026-09-03)

- **버킷**: `joshuatech-tfstate`(이름 예외 — §0 blockquote), 콘솔 생성 2026-09-03 04:59 UTC, versioning Enabled·NoPublicAccess·루트 컴파트먼트, 네임스페이스 `axvjykgvo2m1`.
- **코드**: `infra/oci/{versions.tf,backend.tf,providers.tf}` + `.terraform.lock.hcl`(oracle/oci 8.29.0·cloudflare 5.24.0 서명 검증) — 커밋 `fd7b60d` + 이름 예외 `5b21df5`.
- **init**: `AWS_REQUEST_CHECKSUM_CALCULATION=when_required tofu -chdir=infra/oci init -migrate-state` → "Successfully configured the backend \"s3\"" / "successfully initialized" (운영자 실행, 2026-09-03).
- **부트스트랩 공백과 임시 키**: `svc-tfstate`의 IAM 정책은 T010에서 선언되므로 init 시점에는 권한이 없다(첫 시도 404). 해법: 운영자 본인 계정의 임시 Customer Secret Key **`joshuatech-tfstate-bootstrap-temp`**를 `~/.aws/credentials` `[joshuatech-tfstate]` 프로파일에 사용. 직후 403 SignatureDoesNotMatch는 키 전파 지연 — 수 분 뒤 재시도로 해소.
- **⚠️ T010 마감 시 교체 절차(예정)**: T010 apply로 svc-tfstate 정책이 생기면 ① 프로파일 값을 svc-tfstate Customer Secret Key로 교체 → ② init 재검(plan 동작 확인) → ③ 운영자 계정의 `joshuatech-tfstate-bootstrap-temp` 키 삭제. 이 3단계 완료를 T010 체크 조건에 포함한다.

### T008 — 기존 리소스 import (2026-09-03)

- **코드**: `import.tf`(12블록 유지)·`instances.tf`·`network.tf`·`providers.tf` — 커밋 `caeaea3`. 인스턴스 2에 `prevent_destroy` + `ignore_changes [metadata, defined_tags, create_vnic_details[0].hostname_label]`, VCN·서브넷 2에 `prevent_destroy`.
- **실행**(운영자): `plan -generate-config-out` → 정리 → `plan` **12 to import / 0 / 0 / 0** → `apply` → **"Apply complete! Resources: 12 imported, 0 added, 0 changed, 0 destroyed."** → `state list` 12개 → 재plan **"No changes."**
- **provider 인증 전환 기록**: `auth = var.oci_auth`(기본 `APIKey`, 운영자 DEFAULT 프로파일)로 전환 — 세션 1 h 만료 없이 부트스트랩 진행 목적. 부작용: 이 워크스테이션에서 하네스가 운영자 API 키로 읽기 plan을 수행할 수 있음(리뷰 지적) — **T010 키 교체 시점에 기본값 재결정**(SecurityToken 복귀 / 기본 제거 / 하네스 게이트).
- **v1 유산 확인**(후속 task 몫): IMDS v1 활성→T010, ephemeral 공개 IP(A 152.69.233.183·B 158.180.87.55)·SL 0.0.0.0/0(22·80·443·8080·6379)·VCN IPv6→T009, boot 47GB·v1 SSH 키→T013/T014.

### T009 — NSG·보안 리스트·reserved IP 컷오버 (2026-09-03)

- **코드**: `network.tf`·`instances.tf` 커밋 `a5a97a0`(리뷰 Approved) — NSG `nsg-node-a-platform`(443/tcp ← Cloudflare IPv4 CIDR 15개, for_each) + `nsg-cluster`(자기참조 all, 두 노드 가입), 보안 리스트 3개(api·cache·default) **ingress 0**(egress 유지), reserved IP 2개(`joshuatech-node-a`·`joshuatech-node-b`, prevent_destroy), IPv6는 `is_ipv6enabled` 무변경·주석으로 미사용 명시.
- **사용자 결정(2026-09-03)**: v1 DNS 레코드 `api`·`mcp`·`traefik`(노드 A)·`cache`(노드 B)가 **DNS 전용(비프록시)** 직접 접속이라 NSG 적용 시 v1 API가 끊김 → **옵션 2 "v1 API 중단 수용"** 선택(US8 전환까지 불통; Pages 프론트·Render `mainapi`·R2 `cdn`은 OCI 밖이라 유지). 프록시 전환·Redis 임시 규칙 대안은 채택하지 않음.
- **실행 순서(운영자)**: ① `apply -target`(NSG 2 + 규칙 16 + 인스턴스 nsg_ids + SL 3) → **18 added / 5 changed / 0 destroyed** → 외부 프로브로 노드 A 22·80·443·8080, 노드 B 22·6379 **전부 차단 확인**(이전엔 6개 모두 개방, Redis 6379 전세계 노출 상태였음) → ② ephemeral 공개 IP 2개 삭제(`oci network public-ip delete`, 노드 A 152.69.233.183·노드 B 158.180.87.55) → ③ `apply` → **2 added** → Outputs.
- **주소 변경(기록 의무)**: 노드 A **152.69.233.183 → 144.24.85.118**, 노드 B **158.180.87.55 → 129.154.62.250** (둘 다 RESERVED). ②~③ 사이 창에서는 해당 노드의 **인터넷 egress 전체가 단절**(NAT GW 없음 — 공개 inbound만이 아님, 리뷰 지적) — 수 분.
- **DNS 후속(운영자, Cloudflare) — 완료 2026-09-03**: 옛 ephemeral IP는 다른 테넌트에 재할당될 수 있으므로 A 레코드를 옛 IP에 남겨두지 않는다 — `api`·`mcp`·`traefik` → 144.24.85.118, `cache` → 129.154.62.250로 재지정 완료. 운영자가 4건을 **프록싱됨(주황)** 으로도 전환함(노드 A는 유효 LE 인증서로 443 서빙 + NSG가 CF 대역→443 허용이므로 HTTP 호스트는 CF 경유로 응답 가능; `cache`는 6379가 프록시 대상이 아니라 무의미하나 무해). 최종 `tofu plan` = "No changes". T011 `dns.tf`가 `admin`·`traefik`을 import하며 정리.
- **CF→443 경로 실증(2026-09-03)**: 프록시 전환 직후 `api.joshuatech.dev`가 **522**(CF가 origin 접속 실패) — reserved IP ASSIGNED·VNIC NSG 2개 부착은 정상이었고, 원인은 존 SSL 모드 **자동→Flexible**(CF가 origin에 80으로 접속, NSG는 443만 허용). 운영자가 **Full (Strict)** 로 전환(세 origin 모두 유효 LE 인증서) → `api.joshuatech.dev` **HTTP 200 via Cloudflare(0.87 s)**. 즉 NSG `nsg-node-a-platform`(CF IPv4→443)이 v2 Traefik이 쓸 경로 그대로 동작 확인. T011 `zone_settings.tf`가 `ssl = strict`를 코드로 고정.
- **운영 규칙(신규)**: Cloudflare 공표 IPv4 대역이 바뀌면 정기 plan에 NSG 규칙 destroy가 나타난다 — "CF CIDR 제거로 인한 NSG rule destroy는 사용자 확인 후 apply". 하네스 `tests/infra/tofu.tests.ps1`의 `$cloudflareCidrs` 스냅샷도 함께 갱신(갱신 전까지 nsg-2/4 RED — 의도된 fail-closed).
- **하네스 결함 수정(동반)**: `58f39da`(tofu JSON stdout UTF-8 디코드 — CP949에서 "Ampere® Altra™"로 JSON 파싱 실패; NSG 단언을 T009 문면으로 정합) + `b0b4cb2`(NSG source 분류 구멍 봉인, 보안 리스트 ingress 0 단언 `sl-1` 추가, enc-1 콘솔 무관화) — 34단언, 14 PASS / 20 FAIL(잔여 전부 T010·T011 몫).

### T010 — 버킷·KMS·IAM·예산·IMDS (2026-09-03)

- **코드**: `storage.tf`·`kms.tf`·`iam.tf`·`budget.tf` + `instances.tf`(IMDS v1 비활성 2노드, `assign_public_ip` 영구 가드 주석)·`import.tf`(tfstate 버킷 import) — 커밋 `dbe428f`, 리뷰 Approved(IAM 15문장 최소권한·교차 버킷 0·문법 확인). 이름(사용자 확인 2026-09-03): 버킷 `joshuatech-backup`·`joshuatech-backup-platform`(+`joshuatech-tfstate` import), 그룹 `joshuatech-tfstate`·`joshuatech-s3-backup`, 정책 `joshuatech-{tfstate,s3-backup,verify,objectstorage-lifecycle,node-a}-policy`, 동적 그룹 `joshuatech-node-a`, KMS `joshuatech-vault`/`joshuatech-key`, 예산 `joshuatech-budget` + 알림 4.
- **설계 편차(수용)**: 그룹 가입은 legacy IAM API가 Default 도메인 사용자를 못 봐서(precondition 빈 목록) tofu 선언에서 제외 → 콘솔 가입; VD-6 서비스 주체 정책은 `request.permission != / = 'OBJECT_VERSION_DELETE'` 4문장으로 분리(합집합 = 문면 단일 문장, 관찰 시 `=` 반쪽만 제거 가능); svc-verify는 `read objects`(표 ③ "inspect/read").
- **실행**(운영자): plan `1 import / 19 add / 2 change / 0 destroy` → `apply t010.tfplan` → 20개 완료 + **KMS 키만 실패**(볼트 관리 엔드포인트 `gjvjsruaaadoq-management.kms…` NXDOMAIN — 생성 직후 조회 실패가 로컬·1.1.1.1에 **부정 캐시**됨; 8.8.8.8은 해석) → `ipconfig /flushdns` → 재apply **2 added**(키 + `joshuatech-node-a-policy`) → 재plan **"No changes"**.
- **Outputs**: `kms_key_id = ocid1.key.oc1.ap-chuncheon-1.gjvjsruaaadoq.ab4w4ljrjk4tfx75c47dgyeibp4pxgh3pn3pttsudq2p2hcbsjifvacwspda`, `kms_management_endpoint = https://gjvjsruaaadoq-management.kms.ap-chuncheon-1.oci.oraclecloud.com`, `kms_crypto_endpoint = https://gjvjsruaaadoq-crypto.kms.ap-chuncheon-1.oci.oraclecloud.com`, `object_storage_namespace = axvjykgvo2m1`.
- **후속(운영자, 완료 2026-09-03)**: ① 콘솔 그룹 가입 `svc-tfstate → joshuatech-tfstate`, `svc-s3-backup → joshuatech-s3-backup` ② **임시 키 교체**: `[joshuatech-tfstate]` 프로파일을 svc-tfstate Customer Secret Key로 교체 → `plan` "No changes"(svc-tfstate 정책으로 상태 버킷 R/W 확인) → 운영자 계정 임시 키 `joshuatech-tfstate-bootstrap-temp` 삭제(운영자 확인) ③ `oci --profile svc-verify --auth security_token os object list --bucket-name joshuatech-backup-platform --all` → `{"prefixes": []}` (읽기 정책 동작, VD-6 기준선).
- **VD-6 관찰 계획**: 첫 60일 만료 시점(≈ 2026-11-02 이후) 두 백업 버킷의 이전 버전 수 감소 확인 → `= 'OBJECT_VERSION_DELETE'` 문장 2개 제거 후 다음 만료 재관찰 → 옵션 A/B 확정, `report.md` 기록. `previous-object-versions` 60일 규칙은 두 버킷 동일.
- **IMDS v1 비활성**: 노드 스크립트는 IMDS v2(`Authorization: Bearer Oracle`, `/opc/v2/`)만 사용해야 함 — host-prep(T014)·platform-backup 스크립트 작성 시 준수.
- **provider 인증 기본값 결정(T008 이월)**: `auth = var.oci_auth` 기본 `APIKey` **유지** — 운영자 워크스테이션 한정이며 에이전트는 하네스의 읽기 전용 plan 외 접근 없음(하네스 헤더에 전제 명시). 세션 방식은 `-var oci_auth=SecurityToken`.
- **하네스**: `b020add` — T010 단언을 실명·`access_type`·그룹 기반 IAM·`use keys` 허용·`usage-budgets`·iam-5 `= OBJECT_VERSION_DELETE` 형식으로 정합 + iam-6 접근 행렬·kms-3·lc 접두사 강화 → **36/0**(변이 49건), 리뷰 Approved(Minor 4 이월).

### T011 — Cloudflare 스택 `infra/cloudflare` (2026-09-03)

- **코드**: 15파일(`versions·backend(키 cloudflare/terraform.tfstate)·providers·variables·data·zone_settings·access·security·workers·r2·tunnel·dns·import·outputs.tf` + lock) — 커밋 `7f0f560`, 사전 리뷰 Approved(계약 `hostnames-and-access.md` 앱 10·정책 5·토큰 4 매핑 일치, 공개 경로 누출 0). 이름(사용자 확인): R2 `joshuatech-public`, 터널 `joshuatech-tunnel`, 룰셋 `joshuatech-ratelimit`·`joshuatech-waf-managed`, 추가 정책 `admin-github-ssh`(1h)·`svc-auth-k8s`. 게이트(기본 false): Workers 도메인 2(T093/T094), R2 커스텀 도메인(US8 — `cdn`은 v1 버킷 `joshtech` 소유).
- **편차(수용)**: task가 가정한 `admin` 레코드 부재 → 신규 생성; `traefik`만 import(id `246302c21bbe46054243aeaf06b2dabd`); WAF entrypoint 없음 → 신규 생성(Free Managed Ruleset `77454fe2…` execute).
- **운영자 입력**: GitHub OAuth App `joshuatech-cf-access`(Client ID `Iv23liWmKm2wgQxshEQo`, 콜백 `https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/callback`), `operator_email = joshua92y@gmail.com`(GitHub 기본 이메일), `CLOUDFLARE_API_TOKEN`(`joshuatech-tofu-deploy`).
- **토큰 스코프 실측(표 ① 갱신)**: 룰셋 조회 인증 오류 → Zone WAF:Edit + Tunnel:Edit + Access IdP/Groups:Edit + Access Service Tokens:Edit + R2:Edit 추가; 1차 apply에서 재사용 정책 5개 **403 auth.forbidden** → **Account 단위** Access: Apps and Policies:Edit 추가 후 재apply.
- **실행**: plan `1 import / 38 add / 1 change / 0 destroy` → apply(1차: 정책 403으로 23 add) → 토큰 편집 → 재apply **15 added**(정책 5 + 앱 10) → 총 import 1·add 38·change 1(traefik in-place)·destroy 0.
- **VD-3 실측 → 옵션 A 확정**: `-var=ratelimit_use_host_condition=true` plan(1 change in-place) → apply 성공 — Free 플랜 Rate Limiting 표현식에 `http.host eq "joshuatech.dev" and starts_with(http.request.uri.path, "/api/")` 수락. 코드 기본값을 true로 고정(후속 커밋). 호스트 조건 없는 부분(`/api/auth/*`·`/if/flow/*`)은 US8 전까지 v1 `api.`·`mainapi.`에도 적용됨을 report.md에 기록.
- **Outputs(비밀 아님)**: zone `69559544da12932b3c73e745f3946d0e`, account `91738ffff95834c5972f1a92aac416a6`, tunnel `d0cf3291-f55a-415d-b305-5548c0ebd5bf`, ratelimit 룰셋 `5026b8498eca4013a8b9a93c2b1533a5`, WAF entrypoint `ccbe2a0b69a84ba99c7e3c1b307448af`, IdP `097c94b9-1236-415f-9875-db9618c852d7`, Access AUD: admin `bb921cd6…`, argo `b3ba3e78…`, auth-admin `6f28a967…`, identity-m2m-dev `e808dc6e…`, identity-m2m-prod `4b80c1ea…`, k8s `89363369…`, preview `3e2dcf18…`, ssh `5e939d3c…`, traefik `9bdcf6b1…`, vault `5a667983…`(전체 값은 `tofu -chdir=infra/cloudflare output access_app_aud`).
- **sensitive 출력 보관(운영자 확인 2026-09-03)**: `service_tokens`(web-bff-dev·web-bff-prod·tester-m2m·tester-k8s client_id/secret) + `tunnel_token` → 비밀번호 관리자. Vault 투입은 T043(`kv/platform/access/*`), 터널 토큰은 T014/T035 cloudflared 설치 시 사용.
- **효과**: `argo`·`vault`·`traefik`·`admin`·`preview`·`k8s`·`ssh-a/b`·`auth./if/admin`은 Access(GitHub `joshua92y@gmail.com`) 뒤. SSL strict·HTTPS 강제·TLS 1.2·AOP 존 설정 코드 고정. 터널 CNAME `ssh-a`·`ssh-b`·`k8s` 준비(cloudflared는 T014에서 기동).

### T012 — v1 배포 차단 (2026-09-04)

- **사용자 결정(옵션 B 최소안, 2026-09-04)**: 승인 문면의 "v1 GitHub Secrets 전부 삭제"는 **US8(T105) v1 삭제 시 일괄**로 이월. 근거: v1 CI가 v2 인프라에 쓰기 못 하게 하는 것이 목적이며, 토큰을 원천에서 revoke하면 시크릿은 껍데기가 되고 시크릿 삭제는 복구 불가라 부담. 현재 `joshua92y/joshtech` 시크릿 20개(CF_API_TOKEN·DJANGO_API_URL·FLY_API_TOKEN·GHCR_TOKEN·INTERNAL_API_KEY·NEON_API_KEY·OCI_HOST_CACHE_VM·OCI_HOST_FASTAPI_VM·OCI_SSH_PRIVATE_KEY·PAGE_ACCESS_PASSWORD·POSTMARK_API_KEY·R2_ACCESS_KEY·R2_ACCOUNT_ID·R2_BUCKET·R2_ENDPOINT·R2_SECRET_KEY·RAILWAY_TOKEN·RENDER_DEPLOY_HOOK·RENDER_DEPLOY_HOOK_DJANGO·SECRET_KEY)는 **T105에서 삭제**(T105 문면 "잔여 확인만"은 실제 삭제로 읽는다).
- **PR**: `joshua92y/joshtech` PR #1 — 워크플로 4개(`deploy-fastapi-ghcr`·`deploy-django-ghcr`·`deploy-dragonfly-worker`·`deploy-nextjs-ghcr`)에서 `push(paths)` 트리거 제거, `workflow_dispatch`만 유지(23줄 삭제, YAML 4/4 검증). squash 머지 `5b60554`(2026-09-04 01:47 UTC), 브랜치 삭제. 머지 후 main 검증: 4개 모두 `on: workflow_dispatch:`만, 머지로 트리거된 실행 0. main에 branch protection/ruleset 없음.
- **Render**: 웹서비스 `portfolio-django-admin` Auto-Deploy **Off**(운영자 2026-09-04).
- **Cloudflare**: v1 사용자 API 토큰 **`joshtech_cf_api` 폐기**(운영자 2026-09-04). 유효 토큰은 `joshuatech-tofu-deploy`·`joshuatech-analytics-read`·`joshuatech-cert-manager-dns01`·`joshuatech-ddns-dns-edit`. **R2 API 토큰(v1 `R2_ACCESS_KEY`)** revoke는 운영자 확인 대기.
- **잔여 자격(의도)**: `OCI_SSH_PRIVATE_KEY`(v1 SSH 키)는 T014에서 두 노드 `authorized_keys`를 `jt-ops`로 교체하며 무효화(파기 순서는 §0 토큰 표 ⑦).

(T013–T014 기록은 §2 절에 추가)

## §2 재이미지·host-prep

(T013–T014에서 작성)

## §3 K3s·Argo

(T035–T041에서 작성)

## §4 Vault init·시크릿 시드

(T044–T045에서 작성 + T043의 kv 플레이스홀더 투입 절차 — AOP 전환 본체는 §3 범위)

## §5 v1 삭제 기록

(T104–T105에서 작성)

## §6 업그레이드 창

(T037에서 작성)

## §7 K3s 번들 복원

(T114에서 작성 — FR-047 복호화 포함)
