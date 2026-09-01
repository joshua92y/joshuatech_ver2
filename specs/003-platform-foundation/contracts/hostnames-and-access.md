# Contract: 호스트명 · Cloudflare Access · 오리진 보호

모든 호스트는 Cloudflare proxied(orange), SSL Full(strict), 오리진 인증서 = cert-manager 와일드카드 `*.joshuatech.dev`(1단계 서브도메인만). 오리진(노드 A Traefik)은 Authenticated Origin Pulls(mTLS)로 Cloudflare 이외 접속을 거부하고, OCI NSG는 443만 Cloudflare IP 대역에 연다. Cloudflare Zero Trust 팀: `joshua-tech`(팀 도메인 `joshua-tech.cloudflareaccess.com`, Free) — Access JWT의 `iss`·JWKS(`/cdn-cgi/access/certs`)가 이 도메인이다.

## 호스트 규약 (2026-09-01 사용자 결정)

- pod API(M2M, Service Auth 전용): `<alias>-m2m-<env>.joshuatech.dev` — env ∈ `prod`·`dev`. alias는 pod 이름의 짧은 형태로 아래 표에 고정한다.
- 관리자 UI: 단일 호스트 `admin.joshuatech.dev` + pod별 경로 접두 `/<pod>/…`(Django `FORCE_SCRIPT_NAME=/<pod>`, Traefik Ingress `PathPrefix`). 예: `admin.joshuatech.dev/identity-admin/admin/`.

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
| `joshuatech.dev`, `www.` | Workers(웹 + BFF) | 없음(공개) | Workers 커스텀 도메인. `www` → apex 301 |
| `auth.joshuatech.dev` | Authentik(identity ns, Ingress) | 없음(공개 로그인) | Authentik 자체 보호(rate limit·MFA) |
| `identity-m2m-prod.joshuatech.dev` | identity-admin prod | **Service Auth**: BFF 서비스 토큰만 | 브라우저 직접 접근 불가(Access 403) |
| `identity-m2m-dev.joshuatech.dev` | identity-admin dev | Service Auth(dev 토큰) | |
| `<alias>-m2m-prod.` / `<alias>-m2m-dev.` | SP-2+ pod | Service Auth | pod마다 Access 앱 1개(AUD 분리) |
| `admin.joshuatech.dev` | Django admin — 경로별 pod(`/identity-admin/` 등) | **GitHub IdP** 로그인(운영자 이메일 allow) + Authentik forward-auth | 이중. Access 앱 1개, Ingress는 pod마다 PathPrefix |
| `argo.joshuatech.dev` | Argo CD UI | GitHub IdP | 뒤에서 Authentik OIDC SSO |
| `vault.joshuatech.dev` | Vault UI | GitHub IdP | 뒤에서 Authentik OIDC |
| `traefik.joshuatech.dev` | Traefik 대시보드 | GitHub IdP | api@internal |
| `kibana.joshuatech.dev` | SP-3 | GitHub IdP | 예약 |
| `cdn.joshuatech.dev` | R2 공개 버킷(커스텀 도메인) | 없음 | Image Transformations 원본 존 |
| `ssh.joshuatech.dev`, `k8s.joshuatech.dev` | cloudflared 터널 → 노드 22 / K3s 6443 | GitHub IdP + `cloudflared access tcp` | 공개 DNS에는 CNAME만, 포트 개방 없음 |

## Access 정책 규칙

- 앱마다 별도 Access Application(AUD 태그). pod는 자기 AUD로 `Cf-Access-Jwt-Assertion`을 검증한다(팀 도메인 `joshua-tech.cloudflareaccess.com`의 `/cdn-cgi/access/certs`).
- Service Auth 앱: 정책 action `Service Auth`, include = 서비스 토큰 `web-bff-<env>`. 토큰은 1년 만료, 만료 60일 전 회전(런북 `access-token-rotation`).
- GitHub IdP 앱: include = 이메일 `egenauto.dev@gmail.com`(운영자), 세션 24h, MFA는 GitHub 측.
- Zero Trust Free: 50석. 서비스 토큰은 석을 소비하지 않는다.

## 오리진 보호 3중

1. OCI NSG: 노드 A ingress **443만** ← Cloudflare IPv4/IPv6 대역(`data.cloudflare_ip_ranges`, OpenTofu 주기 실행으로 갱신). 80은 열지 않는다(Always Use HTTPS는 edge, LE는 DNS-01). 노드 B ingress 없음. 클러스터 내부는 NSG 자기참조.
2. Authenticated Origin Pulls(global, zone setting `tls_client_auth=on`) + Traefik `TLSOption default`(`clientAuthType: RequireAndVerifyClientCert`, CA = `authenticated_origin_pull_ca.pem`, 만료 2029-11-01 → 운영 캘린더). default 옵션이므로 모든 websecure 호스트에 적용. 전환 순서: AOP on → `VerifyClientCertIfGiven` 관찰 → `RequireAndVerifyClientCert`. **클러스터 내부에서 공개 호스트명으로 자기 호출 금지**(Service DNS 사용).
3. 앱 계층: pod가 Access JWT를 검증(Cloudflare를 통과했어도 Access 정책을 지난 요청만).

## BFF → pod 헤더

```
Authorization: Bearer <exchanged access token, aud=<pod>>
CF-Access-Client-Id: <service token id>
CF-Access-Client-Secret: <service token secret>
x-request-id: <ulid>
traceparent: 00-<trace>-<span>-01
```

## DNS 레코드(OpenTofu `infra/cloudflare`)

| 이름 | 타입 | 값 | proxied |
|---|---|---|---|
| `@`, `www` | Workers 커스텀 도메인(리소스가 레코드 생성) | — | ✓ |
| `auth`, `*-m2m-prod`, `*-m2m-dev`, `admin`, `argo`, `vault`, `traefik`, `kibana` | A (IPv6 미사용) | 노드 A reserved 공인 IP | ✓ |
| `cdn` | R2 커스텀 도메인 | — | ✓ |
| `ssh`, `k8s` | CNAME | `<tunnel-id>.cfargotunnel.com` | ✓ |

v1 전용 레코드 `api`·`mainapi`는 US8에서 제거. `admin`·`traefik`은 v2가 재사용하므로 OpenTofu `import` 블록으로 가져온 뒤 값을 노드 A reserved IP로 교체한다(T010) — Cloudflare에 같은 이름을 새로 만들면 충돌.
