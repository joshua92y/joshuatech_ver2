# Contract: 호스트명 · Cloudflare Access · 오리진 보호

모든 호스트는 Cloudflare proxied(orange), SSL Full(strict), 오리진 인증서 = cert-manager 와일드카드 `*.joshuatech.dev` **1장**(`kube-system` Secret, Traefik `TLSStore default`; 네임스페이스마다 발급하지 않음, 1단계 서브도메인만). 오리진(노드 A Traefik)은 Authenticated Origin Pulls(mTLS)로 Cloudflare 이외 접속을 거부하고, OCI NSG는 443만 Cloudflare **IPv4** 대역에 연다. Cloudflare Zero Trust 팀: `joshua-tech`(팀 도메인 `joshua-tech.cloudflareaccess.com`, Free) — Access JWT의 `iss`·JWKS(`/cdn-cgi/access/certs`)가 이 도메인이다.

## 호스트 규약 (2026-09-01 사용자 결정)

- pod API(M2M, Service Auth 전용): `<alias>-m2m-<env>.joshuatech.dev` — env ∈ `prod`·`dev`. alias는 pod 이름의 짧은 형태로 아래 표에 고정한다. m2m Ingress는 경로 허용 목록 `/api`·`/health`·`/session`·`/sessions`·`/tenants`만 노출한다. **`/webhooks`·`/healthz`·`/ready`·`/admin/`은 공개 호스트에 없다**(웹훅은 svc DNS 전용, 프로브는 kubelet 전용) → 404.
- 관리자 UI: 단일 호스트 `admin.joshuatech.dev` + pod별 경로 접두 `/<pod>/…`(Django `FORCE_SCRIPT_NAME=/<pod>`, `ADMIN_HOST=admin.joshuatech.dev`일 때만 admin urlconf 장착, Traefik Ingress `PathPrefix`). 예: `admin.joshuatech.dev/identity-admin/admin/`.

| pod | alias | prod 호스트 | dev 호스트 |
|---|---|---|---|
| identity-admin | `identity` | `identity-m2m-prod` | `identity-m2m-dev` |
| portfolio-core | `core` | `core-m2m-prod` | `core-m2m-dev` |
| media | `media` | `media-m2m-prod` | `media-m2m-dev` |
| engagement | `engagement` | `engagement-m2m-prod` | `engagement-m2m-dev` |
| notification · insights · search · assistant | 같은 이름 | `<alias>-m2m-prod` | `<alias>-m2m-dev` |

## 호스트 표

| 호스트 | 대상 | Access 정책 | 비고 |
|---|---|---|---|
| `joshuatech.dev`, `www.` | prod Worker(웹 + BFF) | 없음(공개) | Workers 커스텀 도메인은 **apex만**(`www`는 존 redirect rule **301 → apex** — Workers 도메인 아님). main `deploy`만 배포(GitHub Environment `production`) |
| `preview.joshuatech.dev` | Worker `joshuatech-web-preview`(wrangler env `preview`) | **GitHub IdP**(Access 앱 `preview`) | PR마다 `wrangler deploy --env preview`(같은 repo PR만, fork PR 미생성). dev 시크릿만: Access 서비스 토큰 `web-bff-dev` → `identity-m2m-dev`, 자체 `SESSION_ENCRYPTION_KEY`, Authentik provider `web-bff-dev` |
| `auth.joshuatech.dev` — 공개 경로 `/application/o/*` · `/if/flow/*` · `/if/user/*` · `/.well-known/*` · **`/api/v3/*`** | Authentik(identity ns, Ingress) | 없음(공개 로그인·OIDC issuer/JWKS) | Authentik 자체 보호(Reputation 정책·MFA). FR-046 예외 2(클러스터 안에서 이 공개 호스트 사용)는 **Argo CD·Vault의 OIDC discovery로 한정** — pod의 JWKS는 svc DNS를 쓴다(contracts/network-policy.md) |
| `auth.joshuatech.dev/if/admin/*` | Authentik 관리 UI(SPA) | **GitHub IdP**(Access 앱 `auth-admin`, 경로 스코프 `/if/admin/*`만) | 관리자 그룹 `platform-admin`은 WebAuthn 필수. identity-admin의 Authentik API 호출은 svc DNS(`identity` ns 9000)로만 — 이 Access 앱을 지나지 않는다 |
| `identity-m2m-prod.joshuatech.dev` | identity-admin prod | **Service Auth**: BFF 서비스 토큰 `web-bff-prod`만 | 브라우저 직접 접근 불가(Access 403). AUD → pod ConfigMap `ACCESS_AUD_M2M` |
| `identity-m2m-dev.joshuatech.dev` | identity-admin dev | Service Auth(`web-bff-dev`) | preview Worker·로컬 `next dev`의 상류 |
| `<alias>-m2m-prod.` / `<alias>-m2m-dev.` | SP-2+ pod | Service Auth | pod마다 Access 앱 1개(AUD 분리) |
| `admin.joshuatech.dev` | Django admin — 경로별 pod(`/identity-admin/` 등) | **GitHub IdP** 로그인(운영자 이메일 allow) + Authentik forward-auth | 이중. Access 앱 1개(AUD → pod ConfigMap `ACCESS_AUD_ADMIN`), Ingress는 pod마다 PathPrefix |
| `argo.joshuatech.dev` | Argo CD UI | GitHub IdP | 뒤에서 Authentik OIDC SSO |
| `vault.joshuatech.dev` | Vault UI(Ingress는 T044) | GitHub IdP | 뒤에서 Authentik OIDC |
| `traefik.joshuatech.dev` | Traefik 대시보드 | GitHub IdP | api@internal |
| `kibana.joshuatech.dev` | — | — | **이름만 예약. DNS 레코드도 Access 앱도 SP-3에서 만든다**(SP-1은 아무것도 생성하지 않는다) |
| `cdn.joshuatech.dev` | R2 공개 버킷(커스텀 도메인) | 없음 | Image Transformations 원본 존 |
| `ssh-a.joshuatech.dev` | cloudflared 터널 → **노드 A** 22 | GitHub IdP + `cloudflared access tcp`, Access 앱 `ssh`의 `session_duration` 1h | 공개 DNS에는 CNAME만, 포트 개방 없음 |
| `ssh-b.joshuatech.dev` | cloudflared 터널 → **노드 B** 22 | 같은 Access 앱 `ssh`(호스트 2개) | NetworkPolicy에 `cloudflared → 노드 B private IP:22` 행이 있어야 도달한다(contracts/network-policy.md) |
| `k8s.joshuatech.dev` | cloudflared 터널 → K3s 6443 | GitHub IdP + `cloudflared access tcp`, Access 앱 `k8s` | 에이전트·tester·CI는 아래 `agent-view` 자격만 |

## Access 정책 규칙

- 앱마다 별도 Access Application(AUD 태그). pod는 `Cf-Access-Jwt-Assertion`을 두 AUD(`ACCESS_AUD_M2M` = m2m 앱, `ACCESS_AUD_ADMIN` = admin 앱)로 검증한다(팀 도메인 `joshua-tech.cloudflareaccess.com`의 `/cdn-cgi/access/certs`). AUD는 비밀이 아니며 ConfigMap으로 준다.
- Service Auth 앱: 정책 action `Service Auth`, include = 서비스 토큰 `web-bff-<env>`(m2m 앱에는 tester의 `tester-m2m`도 include — §에이전트 자격). 토큰 secret은 Vault `kv/{env}/access/web-bff` → **Workers Secrets에만**(prod Worker = `web-bff-prod`, preview Worker·로컬 = `web-bff-dev`); pod에는 배포하지 않는다. 1년 만료, 만료 60일 전 회전(런북 `secret-rotation.md`). 예외: tester 토큰 `tester-m2m`·`tester-k8s`의 secret은 Workers Secrets가 아니라 **`kv/platform/access/*`** 에 보관하고 tester가 실행 시 env로만 받는다(§에이전트 자격).
- GitHub IdP 앱(`admin`·`argo`·`vault`·`traefik`·`auth-admin`·`preview`·`ssh`(`ssh-a`·`ssh-b`)·`k8s`): include = 이메일 `egenauto.dev@gmail.com`(운영자), `session_duration` 명시(cloudflare provider 5.24.0에서 필수) — 기본 24h, **`ssh` 앱만 1h**. MFA는 GitHub 측. `kibana` 앱은 SP-3에서 만든다.
- `auth-admin` 앱은 `/if/admin/*`만 감싼다. **`/api/v3`는 공개**로 둔다 — Authentik 로그인 SPA(`/if/flow/*`)와 사용자 UI(`/if/user/*`)가 브라우저에서 `/api/v3/flows/executor/…`·`/api/v3/root/config/`를 직접 호출하므로 Access를 걸면 로그인 자체가 깨진다. 보상 통제: 관리자 그룹 `platform-admin` WebAuthn 필수 · Authentik 서비스 계정 권한을 최소로 한정 · Reputation 정책 · Cloudflare Rate Limiting(`/if/flow/*`). 관리 API 접두(`/api/v3/core/*` 등)만 골라 보호하는 방안은 **SP-2에서 검토**한다.
- Zero Trust Free: 50석. 서비스 토큰은 석을 소비하지 않는다.

## 에이전트 · tester · CI 자격

### 클러스터(K8s)

- ServiceAccount **`agent-view`**(ns `kube-system`) = ClusterRole `view` 집계 + ClusterRole **`agent-view-extra`** + Role `pods/portforward`(ns **`vault`·`data`·`identity`**). **Secret get·exec은 없다.**
- ClusterRole `agent-view-extra`(전부 `get`·`list`·`watch`, Secret 제외):
  - core `nodes` (`kubectl top nodes`가 실패하던 원인 — `nodes.metrics.k8s.io`는 이미 `view`에 집계되지만 core `nodes`는 아니다)
  - `apiextensions.k8s.io` `customresourcedefinitions`
  - `argoproj.io` `appprojects` (기존 `applications`에 더해)
  - `postgresql.cnpg.io` `clusters`·`backups`·`scheduledbackups`·`databases`·`databaseroles`
  - `kafka.strimzi.io` 전체 · `external-secrets.io` 전체
- 배포하는 kubeconfig는 `kubectl create token agent-view -n kube-system --duration=8h`로 만든 것만(T004: 컨텍스트 사용자 = `agent-view` 단언). admin kubeconfig(`k3s.yaml`)는 운영자 비밀번호 관리자에만.
- Vault seal 상태 확인: `kubectl port-forward svc/vault 8200` + `GET /v1/sys/seal-status`(exec 불필요).

### 자격이 필요한 검사는 Job으로 옮긴다

`psql`·`kcat`·`redis-cli`·`fga` 같은 **자격증명이 필요한 검사는 tester가 직접 실행하지 않는다**. gitops `platform/policies/tests/`의 Job이 실행하고 tester는 `kubectl logs job/…`만 읽는다.

| Job | ns | 검사 | 자격 |
|---|---|---|---|
| `data-assert` | `jt-dev` | pg-main role·권한·`pg_stat_ssl`·교차 DB 거부, Dragonfly ACL | **dev scope ExternalSecret만** `envFrom` |
| `kafka-assert` | `jt-dev` | 토픽·KafkaUser·produce/consume 왕복·교차 env 거부 | 같음 |
| `authz-assert` | `jt-dev` | OpenFGA `check` 결과(다른 테넌트 false) | 같음 |

세 Job 모두 ns는 **`jt-dev`**다 — dev scope 자격은 `ClusterSecretStore vault-dev`에서만 나오고 그 store의 `conditions.namespaces`가 `jt-dev` 하나이므로, `data`·`identity`에 두면 dev 전용 자격을 받을 수 없다(그 ns의 `vault-data`는 prod 경로까지 읽을 수 있어 최소 권한에 어긋난다). 도달 경로는 매트릭스의 `jt-dev → data(5432·9093·6379)`·`jt-dev → identity(9000·8080)` 행으로 이미 열려 있다. 매니페스트는 `platform/policies/tests/`가 소유하며 **전용 AppProject `tests`**(source = gitops 저장소만, destination = `jt-dev`만, cluster 리소스 금지)로 배포한다(T041) — Argo CD의 AppProject destination은 Application 한정으로 좁힐 수 없으므로 `platform` 프로젝트에 `jt-dev`를 추가하면 프로젝트 전체가 그 권한을 얻는다(contracts/gitops-repo.md §Application 규약).

Job은 prod 자격을 절대 받지 않는다. tester가 얻는 것은 로그 텍스트뿐이다.

### 클라우드·SaaS 읽기 자격

- **OCI**: 사용자 `svc-verify`(그룹 `jt-verify`) — `inspect`/`read objects` on `jt-backup`·`jt-backup-platform`, `read usage-reports`·`budgets`·`instance-family`. **`manage` 권한 0.** 접속은 `oci session authenticate`(세션 토큰 1 h).
- **Grafana Cloud**: Viewer 서비스 계정 토큰. **Sentry**: 읽기 전용 토큰. **Cloudflare**: `Analytics:Read` 토큰. 셋 다 quickstart 사전 조건으로 운영자가 준비한다.
- **Vault**: role `e2e-reader`(bound `kube-system/agent-view`, 정책 = `kv/data/platform/authentik/e2e` read, `token_ttl` 1h) — Playwright가 E2E 사용자 비밀번호·TOTP 시드를 읽는 유일한 경로.
- `argocd --sso` 로그인 확인과 Authentik 관리 API 확인은 **운영자 수동 + 스크린샷**이다(비대화형 자동화 없음).
- **tester Access 서비스 토큰 2개**(둘 다 T011 `access.tf`가 생성, 회전 매트릭스 T084 등재; secret은 `kv/platform/access/*` 보관 — tester는 실행 시 env로만 받고 파일에 저장하지 않는다):
  - `tester-m2m` — **dev·prod m2m 앱** include(Service Auth): tester의 m2m E2E 호출이 Service Auth를 지나는 경로. 보관 `kv/platform/access/tester-m2m`.
  - `tester-k8s` — **`k8s` 앱** include: `cloudflared access tcp`로 6443 접속. 보관 `kv/platform/access/tester-k8s`. cloudflared 클라이언트는 **2026.5.1로 핀**한다(plan A12: 이후 버전에서 서비스 토큰 회귀).
- **SP-1의 CI(GitHub Actions)에는 클러스터·OCI 자격이 없다.** 클러스터 검사는 운영자·tester 세션에서만 돈다.

### 운영자 자격 취급

- 운영자 개인 계정(GitHub·Google) 자격은 어떤 환경변수·파일에도 넣지 않는다. E2E 신원은 Authentik 로컬 사용자 `e2e@joshuatech.dev`(Vault `kv/platform/authentik/e2e`); 소셜 로그인은 운영자가 브라우저로 1회 수동 검증.
- SSH 키 `jt-ops`는 **FIDO2(`ed25519-sk`) 또는 passphrase + `ssh-add -c`**(사용마다 확인)로만 쓴다. 세션이 끝나면 `cloudflared access logout`을 실행한다.

## 오리진 보호 3중

1. OCI NSG: 노드 A ingress **443만** ← Cloudflare IPv4 대역(`data.cloudflare_ip_ranges`, OpenTofu 주기 실행으로 갱신). 80은 열지 않는다(Always Use HTTPS는 edge, LE는 DNS-01). 노드 B ingress 없음. 클러스터 내부는 NSG 자기참조. 22는 평시 닫힘 — break-glass 런북의 OpenTofu 변수로만 임시 개방.
2. Authenticated Origin Pulls(global, zone setting `tls_client_auth=on`) + Traefik `TLSOption default`(`clientAuthType: RequireAndVerifyClientCert`, CA = `authenticated_origin_pull_ca.pem`, 만료 2029-11-01 → 운영 캘린더). default 옵션이므로 모든 websecure 호스트에 적용. 전환 순서: AOP on → `VerifyClientCertIfGiven` 관찰 → `RequireAndVerifyClientCert`. Traefik `forwardedHeaders.trustedIPs` = Cloudflare CIDR(클라이언트 IP 복원). **클러스터 내부에서 공개 호스트명으로 자기 호출 금지**(Service DNS 사용) — 예외 1: BFF → pod(Cloudflare 경유), 예외 2: OIDC issuer/JWKS(`auth.joshuatech.dev`).
   - **CA Secret**: `kube-system/cloudflare-origin-pull-ca`, 키 `ca.crt`(Traefik `clientAuth.secretNames`는 Secret만 읽는다 — ConfigMap 불가). 정본은 모노레포 `infra/bootstrap/cloudflare-origin-pull-ca.yaml`이며 노드 A `server/manifests/`에 `traefik-config.yaml`과 같은 절차로 설치한다(K3s AddOn) — gitops `platform/traefik/`에 두지 않고, 운영자가 kubectl로 먼저 만들지도 않는다. 값은 Cloudflare가 공개 배포하는 **루트 CA 인증서**(개인키 없음)이므로 "시크릿은 저장소에 넣지 않는다" 규칙의 예외가 아니라 대상이 아니다.
   - **CA 식별값**(정적 테스트와 설치 게이트가 같은 리터럴을 고정한다): subject = issuer `C=US, O=CloudFlare, Inc., OU=Origin Pull, L=San Francisco, ST=California, CN=origin-pull.cloudflare.net` · sha256 지문 `9A:1A:C2:B4:BE:15:F9:F2:7E:EE:20:A7:34:CB:A4:E9:89:8F:61:00:1B:3B:D7:C8:4B:69:B5:6A:3E:25:A2:B9` · notAfter **2029-11-01 17:00 GMT**. 원본 `https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem`에는 교체 공지 채널이 없으므로 **분기 1회 원본 지문 대조**를 운영 캘린더에 둔다(`docs/runbooks/secret-rotation.md`, T084 작성). 지문이 달라지면 정본 파일의 `ca.crt`에 옛+새 PEM을 병기해 교체한다 — Traefik은 Secret 변경을 informer로 반영하므로 롤아웃·TLSOption 변경이 없다.
   - **투입·되돌리기 순서**(둘 다 어기면 websecure 443 전면 중단): 투입 = Secret 설치 → 지문·notAfter 대조 → `clientAuth` 투입. 되돌리기 = `clientAuth` 제거·재설치 → `tlsoption default` spec의 `clientAuth`가 빈 값임을 확인 → 그다음에야 Secret 삭제. `clientAuth`가 실린 채 Secret이 없거나 키가 `ca.crt`/`tls.ca`가 아니면 TLSOption 등록이 실패해 websecure 전 호스트가 죽는다(파드는 Ready 유지 — 능동 확인 필수). `VerifyClientCertIfGiven`도 **제시된 인증서는 검증**하므로 CA 불일치에는 Require와 똑같이 실패한다 — 관찰 단계가 관대한 것은 "인증서 부재"뿐이다.
   - **판정**: 관찰(Verify) 단계의 강제 실효 판정은 Traefik 액세스 로그의 `TLSClientSubject` 필드로만 한다(TLSOption 반영 시각 + Traefik idleTimeout(기본 180초) **이후**의 프로브만 유효 — 옛 keep-alive 연결은 옛 TLS 설정으로 산다; edge 경유 `auth` 404는 "장애 없음" 판정에만 쓴다). 승격(Require) 뒤 직접 접속 판정 = 클라이언트 인증서 없는 오리진 직접 TLS가 **거절**되는 것 — TLS 1.2는 핸드셰이크 중 `handshake failure`, TLS 1.3은 post-handshake `certificate required` alert(TLS 1.3에서는 `openssl s_client`가 핸드셰이크 성공처럼 보이므로 alert·전송 실패까지 확인한다; curl exit 56/35는 참고값) · edge 경유는 `auth` 404 유지(526은 오리진 **서버** 인증서 별건; AOP 불일치는 525 또는 520으로 나타난다고 보되 어느 쪽인지는 미실측 — 런북 VD-7에서 확정). 서버 인증서 확인은 `openssl s_client -servername`으로 한다(서버 인증서는 클라이언트 인증서 제시 여부와 무관하게 서버 플라이트에서 전송되므로 승격 뒤에도 읽힌다). Secret 값 대조는 운영자 admin kubectl 전용이다(agent-view는 Secret get이 없다 — §에이전트 자격).
   - **보증 범위**: 이 CA는 모든 Cloudflare 계정이 공유한다 — "Cloudflare 망에서 왔다"만 보증하고 "우리 존에서 왔다"는 보증하지 않는다. 계정 교차 우회의 오리진 측 통제는 Access 앱 + 대시보드 forward-auth(T084) + 3.의 앱 계층 JWT 검증이다.
3. 앱 계층: pod가 Access JWT를 검증(Cloudflare를 통과했어도 Access 정책을 지난 요청만) + Access 서비스 토큰의 `common_name`으로 호출자 식별(기본 impersonation 모드; `AUTH_ACTOR_SUB`가 설정된 경우에만 Bearer `act.sub` 추가 검증 — contracts/identity-admin-api.md §호출자 식별·VD-1).

## BFF → pod 헤더

```
Authorization: Bearer <exchanged access token, aud=<pod>>   # 기본 impersonation — act 클레임 없음
CF-Access-Client-Id: <service token id>                     # common_name = web-bff-<env> (호출자 식별)
CF-Access-Client-Secret: <service token secret>
x-request-id: <ulid>
traceparent: 00-<trace>-<span>-01
```

## DNS 레코드(OpenTofu `infra/cloudflare`)

| 이름 | 타입 | 값 | proxied |
|---|---|---|---|
| `@` | Workers 커스텀 도메인(리소스가 레코드 생성) | prod Worker | ✓ |
| `www` | A(더미) + 존 redirect rule — **Workers 커스텀 도메인 아님** | **301 → apex**(`https://joshuatech.dev`) | ✓ |
| `preview` | Workers 커스텀 도메인 | Worker `joshuatech-web-preview` | ✓ |
| `auth`, `*-m2m-prod`, `*-m2m-dev`, `admin`, `argo`, `vault`, `traefik` | A (IPv6 미사용) | 노드 A reserved 공인 IP | ✓ |
| `cdn` | R2 커스텀 도메인 | — | ✓ |
| `ssh-a`, `ssh-b`, `k8s` | CNAME | `<tunnel-id>.cfargotunnel.com` | ✓ |

`kibana`는 SP-3에서 만든다(SP-1 레코드 없음). v1 전용 레코드 `api`·`mainapi`는 US8에서 제거. `admin`·`traefik`은 v2가 재사용하므로 OpenTofu `import` 블록으로 가져온 뒤 값을 노드 A reserved IP로 교체한다(T011) — Cloudflare에 같은 이름을 새로 만들면 충돌. `preview` 커스텀 도메인은 Worker가 존재한 뒤에만 만들 수 있으므로 T093/T094에서 apply한다. provider 핀 `cloudflare ~> 5.24.0` + `.terraform.lock.hcl` 커밋.
