# Quickstart: 플랫폼 기반 (SP-1) 검증 가이드

US별로 "이 명령을 치면 이 결과가 나와야 한다"를 적는다. 구현 절차는 `tasks.md`와 런북에, 계약은 `contracts/`에 있다. 모든 클러스터 명령은 cloudflared 터널 뒤에서(`cloudflared access tcp --hostname k8s.joshuatech.dev --url 127.0.0.1:6443`) `KUBECONFIG`를 잡은 뒤 실행한다. 그 kubeconfig는 SA `agent-view`(ns `kube-system`)의 단기 토큰으로 만든 것만 쓴다 — `kubectl create token agent-view -n kube-system --duration=8h`. admin kubeconfig(`k3s.yaml`)는 운영자 비밀번호 관리자에만 있고 에이전트·tester·CI에는 배포하지 않는다. 값·이름은 `research/2026-09-01-approval-remediation.md`(R1–R25)와 `research/2026-09-01-approval-remediation-r2.md`(R26–R38 · VD-1–VD-9)를 따른다 — 충돌하면 2차가 우선. **VD-n**이 붙은 확인은 "외부 서비스라 결과를 문서로 미리 못 박지 않는다"는 뜻이다: 기본 가정대로 명령을 돌리고, 결과가 옵션 A인지 B인지를 **해당 task 착수 시 사용자와 함께 판정**해 tasks 체크박스 옆 한 줄과 `report.md`에 적는다.

## 사전 조건

- 개발기: Windows 11 + WSL(Ubuntu 24.04) — `uv`, `node 24`, `pnpm`, `wrangler 4`, `copier`, `kubectl`, `argocd`, `vault`, `oci`, `tofu`, `cloudflared`, `gh`, `age`, `docker`(testcontainers).
- 계정: OCI(PAYG, 춘천), Cloudflare(존 `joshuatech.dev`, Zero Trust Free, Workers Free), GitHub(org/App 생성 권한), Grafana Cloud Free, Sentry Free.
- 비밀은 Vault에만. 로컬 `.env`는 `env.example`에서 복사해 값을 채우되 커밋하지 않는다(gitleaks가 CI에서 막는다).
- age 키 쌍: 운영자가 `age-keygen`으로 1회 생성. 공개키만 노드 A에 두고(`platform-backup.sh`가 `age -r <공개키>`로 K3s 번들·Vault 스냅샷을 암호화), 개인키는 오프라인(Vault recovery key와 같은 곳)에 보관해 복원 때만 꺼낸다.
- 에이전트·tester·CI 클러스터 자격: SA `agent-view`(ns `kube-system`) = ClusterRole `view` 집계 + `applications.argoproj.io` get/list + **ClusterRole `agent-view-extra`**(get/list/watch: core `nodes`, `apiextensions.k8s.io customresourcedefinitions`, `argoproj.io appprojects`, `postgresql.cnpg.io clusters·backups·scheduledbackups·databases·databaseroles`, `kafka.strimzi.io *`, `external-secrets.io *` — Secret 제외) + **Role `pods/portforward`(`vault`·`data`·`identity`)**. Secret get·exec 없음. `kubectl auth whoami`가 `system:serviceaccount:kube-system:agent-view`여야 한다(T004 단언).
- 자격이 필요한 데이터 검사(psql·kcat·redis-cli·fga)는 tester가 직접 실행하지 않는다. gitops `platform/policies/tests/`가 배포하는 Job `data-assert`·`kafka-assert`·`authz-assert`(ns `jt-dev`, dev scope ExternalSecret만 envFrom)가 클러스터 안에서 돌고, tester는 `kubectl -n jt-dev logs job/<이름>`만 읽는다. 그래도 `exec`·`run`이 필요한 예외 명령은 운영자가 admin kubeconfig로 실행하고 출력을 tester 보고에 첨부한다.
- 터널 클라이언트: tester·운영자 워크스테이션의 cloudflared는 **2026.5.1 핀**(2026.6+는 `access tcp/ssh`에서 서비스 토큰을 무시하는 회귀 — plan A12). `k8s` Access 앱에는 `tester-k8s` 서비스 토큰 정책이 있어야 비대화형 `kubectl`이 가능하다. 세션이 끝나면 `cloudflared access logout`.
- tester Access 서비스 토큰 2개(T011 `access.tf`가 생성, 회전은 T084 매트릭스): **`tester-k8s`**(`k8s` 앱 include — 비대화형 `kubectl`) · **`tester-m2m`**(dev·prod m2m 앱 include — 아래 `identity-m2m-*` 검증 curl의 `CF-Access-Client-Id/Secret` 헤더). 보관은 Vault `kv/platform/access/{tester-k8s,tester-m2m}`.
- OCI 읽기 자격: 사용자 `svc-verify`(그룹 `jt-verify` — `jt-backup`·`jt-backup-platform` inspect/read objects, read usage-reports·budgets·instance-family, manage 0). 세션 토큰으로만 쓴다 — `oci session authenticate --profile-name svc-verify --region ap-chuncheon-1`(1 h) 후 아래 `oci` 명령에 `--profile svc-verify`. 쓰기 권한이 있는 프로필로는 검증을 실행하지 않는다.
- 읽기 전용 SaaS 토큰(운영자가 1회 발급, Vault 보관): Grafana Cloud **Viewer 서비스 계정 토큰**(대시보드·알림 조회) · Sentry **읽기 전용 auth token** · Cloudflare **`Account Analytics:Read`** 토큰(Workers 사용량). GitHub은 `gh` 읽기(공개 저장소)면 충분하다. `argocd --sso` 로그인과 Authentik 관리 API 확인은 비대화형으로 불가하므로 **운영자 수동 + 스크린샷**으로 대체한다.
- E2E 신원: Authentik 로컬 사용자 `e2e@joshuatech.dev`. 비밀번호·TOTP 시드는 Vault **`kv/platform/authentik/e2e`** 한 경로에만 있고(tester도 같은 경로), tester는 K8s auth role `e2e-reader`(bound SA `kube-system/agent-view`, 정책 = 그 경로 read, ttl 1 h)로 `agent-view` 토큰을 그대로 써서 읽는다 — 새 시크릿을 만들지 않는다. e2e 사용자는 `platform-admin` 그룹에 넣지 않는다. GitHub 테스트 계정은 만들지 않으며, 소셜 로그인(US4 AC1)은 운영자가 브라우저로 1회 수동 검증하고 스크린샷을 tester 보고에 첨부한다. 운영자 개인 계정 자격은 어떤 환경변수·파일에도 넣지 않는다. Playwright storageState는 `e2e/.auth/`(gitignore, 실행 후 삭제), trace는 `mask`.
- SP-1 CI에는 클러스터·OCI 자격을 주지 않는다(배포는 Argo pull, Cloudflare만 스코프 토큰).

## US1 — 결정 문서화

```bash
pwsh -NoProfile -File tests/run-all.ps1            # ADR MADR 검사·미러·CLAUDE.md 줄 수 포함, ALL PASS
ls docs/decisions/00{02..10}-*.md                   # 9개
grep -l '^paths:' .claude/rules/{web,django-pod,fastapi-pod,infra,events}.md | wc -l   # 5 (US9 T109 산출물 — US1 시점에는 0이 정상, US9 E2E(T113)에서 재검)
```
기대: run-all ALL PASS, `docs/README.md`에 0002–0010 링크, `.specify/memory/{product,architecture}.md` 존재.

## US2 — 클러스터·GitOps·인그레스·시크릿

```bash
cd infra/oci && tofu plan                            # destroy 0개(인스턴스 재이미지는 부트 볼륨 교체만)
kubectl auth whoami                                  # system:serviceaccount:kube-system:agent-view
kubectl get nodes -o wide                            # 2 Ready, 라벨 role=platform / role=data
kubectl get ns -L pod-security.kubernetes.io/enforce # 14개 전부 PSA 라벨(restricted/baseline/privileged), kube-system 포함, monitoring 존재·observability 없음
kubectl get networkpolicy -A                         # 정책 세트 5: default-deny 13 · allow-dns 13(kube-system 제외 전 ns) · allow-same-namespace 7(argocd·data·cnpg-system·external-secrets·cert-manager·monitoring·identity) · allow-kube-api 10 · allow-apiserver-webhook 4(cert-manager·external-secrets·cnpg-system·vault) + deny-imds 1(kube-system 전용) + allow-imds 1(vault 전용)
kubectl -n monitoring logs ds/alloy-metrics --tail=300 | grep -Eic 'connection refused|context deadline exceeded'   # 0 (스크레이프 대상 ns 도달 — 매트릭스 monitoring 행이 실제로 열려 있음)
kubectl -n argocd get applications                   # root 포함 전부 Synced/Healthy (ES 제외)
kubectl -n argocd get appprojects default -o jsonpath='{.spec.sourceRepos}'   # [] (무력화)
kubectl -n system-upgrade get plans                  # k3s-server, k3s-agent (window 일요일 03:00–05:00 KST)
kubectl -n reloader get deploy                       # reloader 1/1 (차트 2.2.16 / appVersion v1.4.21)
kubectl get clusterrole | grep -c '^reloader'        # VD-9: scoped 모드(watchGlobally false)면 0 — ClusterRole이 남아 있으면 옵션 B로 판정
curl -sI https://argo.joshuatech.dev | head -1       # 302 → Cloudflare Access 로그인
curl -sk --resolve argo.joshuatech.dev:443:<노드A IP> https://argo.joshuatech.dev   # TLS handshake 실패(AOP)
kubectl -n vault port-forward svc/vault 8200:8200 &  # agent-view는 vault ns pods/portforward만(exec 없음)
curl -s http://127.0.0.1:8200/v1/sys/seal-status | jq '{sealed, type}'          # {"sealed": false, "type": "ocikms"}
kubectl get clustersecretstore                       # vault-platform, vault-dev, vault-prod, vault-data, k8s-data-ca — 5개 Ready
kubectl get externalsecret -A | grep -v SecretSynced # 빈 출력
kubectl -n jt-prod get secret pg-main-ca -o jsonpath='{.data}' | jq 'keys'   # ["ca.crt"] — ca.key 없음(k8s-data-ca 미러)
for b in jt-tfstate jt-backup jt-backup-platform; do oci --profile svc-verify os bucket get --bucket-name $b --query 'data."public-access-type"'; done   # NoPublicAccess × 3
oci --profile svc-verify os object list --bucket-name jt-backup-platform --prefix k3s/ --query 'data[].name'     # *.tar.age ≥ 1, 평문 sqlite 0
oci --profile svc-verify os object list --bucket-name jt-backup-platform --prefix vault/ --query 'data[].name'   # *.age ≥ 1 (Vault Raft 스냅샷)
oci iam dynamic-group get --dynamic-group-id <jt-node-a OCID> --query 'data."matching-rule"'   # 노드 A 인스턴스 OCID만(운영자 프로필)
gitleaks detect --source . --no-git                  # 0 findings (두 저장소)
```
재부팅 시나리오: `sudo reboot`(노드 A) → 5분 뒤 `seal-status`가 `sealed false`, ESO `Ready`. 백업: 노드 A `systemctl list-timers platform-backup.timer` → 다음 실행 매일 02:30 KST; SUC Plan의 `prepare` 단계 로그에 `platform-backup.sh --pre-upgrade` 실행 기록. KMS 키는 OpenTofu에 `prevent_destroy` + 삭제 유예 30일(`tofu state show`로 확인). 복원 가능성 검증(T048): 최신 `.age` 2개를 내려받아 `age -d -i <개인키>`로 풀고 K3s는 `sqlite3 state.db 'PRAGMA integrity_check'` → `ok`, Vault는 `vault operator raft snapshot inspect <파일>` → 메타데이터 출력(= **무결성 검증**이며 복원 리허설이 아니다). **VD-9(Reloader)**: `kubectl -n jt-dev patch externalsecret …`로 값 변경 → 대상 Deployment 롤아웃 1회 + Argo Synced 유지면 scoped 모드 유지(옵션 A), ClusterRole 없이 감시가 안 되면 `watchGlobally: true` + `namespaceSelector`(옵션 B, ClusterRole 잔존 트레이드오프를 report에 기록) — T046 착수 시 사용자와 판정. **VD-6(OCI lifecycle)**: `oci --profile svc-verify os object-lifecycle-policy get --bucket-name jt-backup-platform`으로 `previous-object-versions` DELETE 60일 규칙 **존재만** 확인하고, 실제 삭제 동작(정책 `OBJECT_VERSION_DELETE` 필요 여부)은 T010 apply 후 첫 만료를 관찰해 report에 적는다.

## US3 — 데이터·이벤트 플랫폼

```bash
kubectl -n data get cluster pg-main                  # Cluster in healthy state, instances 1
kubectl -n data get databases                        # identity_admin dev_identity_admin authentik openfga (SP-1 4개)
kubectl -n data get databaseroles                    # identity_admin_{owner,app} · dev_identity_admin_{owner,app} · authentik_owner · openfga_owner (dev role 규칙: dev_<pod_snake>_*)
kubectl -n data get scheduledbackup,backup           # schedule "0 0 17 * * *"(02:00 KST 매일), completed 1건
oci --profile svc-verify os object list --bucket-name jt-backup --query 'data[?contains(name, `base`)].name'  # 베이스 백업 오브젝트
kubectl -n data get kafka,kafkanodepool,kafkatopic,kafkauser
# 자격이 필요한 검사는 클러스터 안 Job이 수행하고 tester는 로그만 읽는다(gitops platform/policies/tests/)
kubectl -n jt-dev logs job/data-assert               # ① 실접속(dev 방향만 — Job은 dev 자격만 가진다): dev_identity_admin_app → identity_admin DB = permission denied for database
                                                     # ② 실접속: dev_identity_admin_app → authentik DB = permission denied for database
                                                     # ③ 카탈로그(prod role 방향, 로그인 없이): SELECT has_database_privilege('identity_admin_app','dev_identity_admin','CONNECT') = false · has_database_privilege('identity_admin_app','authentik','CONNECT') = false
                                                     # ④ REVOKE CONNECT … FROM PUBLIC 적용 확인(공유 DB authentik·openfga는 cnpg-databases PostSync SQL Job이 적용), pg_stat_ssl에 verify-full 연결
kubectl -n jt-dev logs job/kafka-assert              # produce → consume 왕복 ≤ 5초, 다른 KafkaUser로는 토픽 접근 거부
kubectl -n jt-dev logs job/authz-assert              # fga check allowed=true / 다른 테넌트 object는 false
kubectl -n jt-dev logs job/data-assert | grep -A5 'ACL LIST'   # VD-4: `%R~revoked:*`가 보이면 옵션 A(aclfile 유지)
kubectl -n jt-dev logs job/data-assert | grep 'NOPERM'          # `<pod>` 사용자로 DEL revoked:sub:x → NOPERM (결과와 무관하게 이 단언은 동일)
```
**VD-4(Dragonfly aclfile)**: 기본 가정은 "`--aclfile`이 `%R~revoked:*`를 그대로 로드한다"(v1.40.1 소스 기준). `ACL LIST`에 패턴이 보이면 옵션 A로 확정하고, 로드 오류가 나면 옵션 B(entrypoint `ACL SETUSER` 래퍼)로 전환한다 — **T057 배포 직후 사용자와 함께 판정**하고 결과를 report에 적는다.

## US4 — 신원·인가

1. 소셜 로그인(US4 AC1)은 운영자 수동 1회: 브라우저 `https://auth.joshuatech.dev` → GitHub 로그인 → 사용자 설정 Sessions에 세션 1건 — 스크린샷을 tester 보고에 첨부. tester 자동화는 Authentik 로컬 사용자 `e2e@joshuatech.dev`(Vault `kv/platform/authentik/e2e`)로 Playwright 로그인, storageState `e2e/.auth/`(실행 후 삭제).
2. 토큰 교환(RFC 8693 — SP-1 기본은 **impersonation**. `$WEB_BFF_TOKEN`은 사용자 토큰(aud web-bff)):
```bash
ACCESS=$(curl -s -X POST https://auth.joshuatech.dev/application/o/token/ -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d subject_token=$WEB_BFF_TOKEN -d subject_token_type=urn:ietf:params:oauth:token-type:access_token -d audience=identity-admin -u $WEB_BFF_CLIENT_ID:$WEB_BFF_SECRET | jq -r .access_token)
echo $ACCESS | cut -d. -f2 | base64 -d | jq '{aud, azp, tenant_id, act, exp}'   # aud identity-admin, tenant_id(uuid) 존재, exp = iat+300; act는 impersonation 모드에서 없음
curl -s -X POST … -d audience=portfolio-core …                             # error: invalid_target (SP-1 미허용)
curl -s -H "Authorization: Bearer $ACCESS" https://identity-m2m-prod.joshuatech.dev/tenants/me   # 401 — Access 서비스 토큰 헤더(CF-Access-Client-Id/Secret) 없이는 네트워크 게이트에서 막힌다
```
   **VD-1(Authentik 호출자 식별)**: 기본 가정은 "impersonation 교환 + Access 서비스 토큰 `common_name`으로 호출자 식별"이고, pod의 `act.sub` 검증은 `AUTH_ACTOR_SUB`가 설정된 경우에만 켠다. **T081 착수 시 사용자와 함께 실측**한다 — OSS 인스턴스에서 Actor 생성을 시도한 뒤 BFF의 client-credentials 토큰을 `actor_token`으로 붙여 위 교환을 다시 호출해서, 응답 토큰에 `act` 클레임이 있으면 옵션 A(delegation + `act.sub == web-bff` 검증), `invalid_grant`(`actor_not_controlled`)면 옵션 B(impersonation 유지). 교환 응답 전문을 증거로 캡처한다. `audience`를 빼고 교환하면 발급 토큰의 `azp`가 web-bff client_id이므로 `iss`+`azp`로도 판별할 수 있으나 `audience` 지정과 양립하지 않는다 — 둘 중 하나만 쓴다.
3. 폐기: `curl -X POST https://joshuatech.dev/api/auth/logout -H 'x-csrf-token: …' -b jt_session=…` → 1초 뒤 `curl -H "Authorization: Bearer $ACCESS" -H "CF-Access-Client-Id: …" https://identity-m2m-prod.joshuatech.dev/tenants/me` → 401 `session_revoked`.
4. Authentik 관리자에서 세션 삭제 → identity-admin 로그에 `authentik_webhook` reason 기록 → 같은 401.
   폐기 3경로 E2E(T085)와 SC-003(≤ 2 s) 측정은 **prod 체인에서만** 한다 — dev의 Authentik 자격은 dev 전용 서비스 계정 `identity-admin-ro`(사용자 read만, `kv/dev/authentik/identity-admin.api_token`)이고 dev의 revoke·reconcile 쓰기 호출은 설정 플래그로 비활성(로그만)이라, dev 로그아웃 검증은 denylist 401·로컬 세션 삭제까지만 본다.
5. OpenFGA: `fga tuple write --store-id $STORE user:<sub> member tenant:<uuid>` → `fga query check user:<sub> member tenant:<uuid>` → `{"allowed":true}`.
6. Access: `curl -sI https://admin.joshuatech.dev/identity-admin/admin/` → 302(Access 로그인); `curl -sI https://auth.joshuatech.dev/if/admin/` → 302 또는 403(Access 앱 `auth-admin` = **`/if/admin/*`만**, GitHub IdP); `curl -sI https://auth.joshuatech.dev/api/v3/flows/executor/<login-slug>/` → **200**(무헤더 — 로그인 흐름 실행기는 공개여야 한다); `curl -sI https://auth.joshuatech.dev/api/v3/root/config/` → **200**(무헤더 — 사용자 UI가 쓴다); `curl -sI https://auth.joshuatech.dev/application/o/<app>/.well-known/openid-configuration` → 200(공개); 서비스 토큰 헤더로 `identity-m2m-prod…/health` → 200. `/api/v3` 전체를 Access 뒤에 두면 로그인 SPA가 깨지므로 관리 API 접두 보호는 SP-2에서 재검토하고, SP-1의 보상 통제는 `platform-admin` WebAuthn·서비스 계정 권한 한정·Reputation 정책·Rate Limiting이다.

## US5 — 웹 hello·BFF 왕복

```bash
for l in ko en ja; do curl -s -o /dev/null -w '%{http_code}\n' https://joshuatech.dev/$l; done   # 200 200 200
curl -s https://joshuatech.dev/ko | grep -c 'data-note-slug'   # ≥ 2 (001·002 학습 노트)
curl -s https://joshuatech.dev/api/health | jq                  # {status: ok, upstream: identity-admin, upstream_ms: n}
pnpm --filter web build && node apps/web/scripts/bundle-budget.mjs   # server bundle gzip: x.xx MiB (≤ 2.5)
# VD-2 캐시 실측(T093 배포 직후, 사용자 동석): 임시 Cache Rule 1개를 1회 apply한 뒤 같은 경로를 10회 치고 cf-cache-status 분포를 본다
for i in $(seq 1 10); do curl -sI https://joshuatech.dev/ko | grep -i '^cf-cache-status'; sleep 1; done
```
**VD-2(Cloudflare 캐시)**: **기본 = 존 Cache Rule 미생성**(Worker가 캐시보다 먼저 실행되므로 Cache Rule은 Worker 응답에 효과가 없다고 가정 — FR-004 선언 목록에 없다). 실측은 **임시 Cache Rule 1개를 1회 apply**한 뒤 위 10회를 돌린다: `HIT`가 나오고 **Workers 대시보드의 요청 수가 늘지 않으면 옵션 A**(규칙 유지 — 선언 목록 편입), 전부 `DYNAMIC`/`BYPASS`이고 요청 수가 10 증가하면 **옵션 B** — 임시 규칙을 제거하고 프리렌더 HTML을 `.open-next/assets`(`/ko`·`/en`·`/ja`)로 복사하는 자산화를 같은 task에서 시험한다(자산 요청은 무제한·무료, RSC 프리페치 부작용은 `e2e/hello.spec.ts` 가드로 판정). 어느 쪽이든 `run_worker_first`에는 페이지 경로(`/ko` 등)를 넣지 않고 wrangler `[cache]`는 비활성으로 둔다(활성화하면 자산 요청도 과금된다). 한도 초과 시 동작(429 vs 1027)은 **VD-8** — 의도적으로 초과시키지 않고 발생하면 report에 기록한다.
Workers 대시보드 → Analytics: `_next/static/*`는 "Static asset requests"로 집계, 페이지 GET·`/api/*`는 Worker 호출로 집계되며 CPU p95 ≤ 10 ms·Error 1102 0건(일 요청 수를 report에 기록). `e2e/hello.spec.ts` 가드: 로드 후 30초 내 `Next-Router-Prefetch: 1` 요청 ≤ 10(plan A2). 반복 호출(요청 수·CPU 측정)은 간격 ≥ 200 ms로 돌린다 — Free Rate Limiting 규칙(`/api/auth/*`·`/if/flow/*`, VD-3)에 걸려 측정이 429로 오염되지 않게 한다. PR을 열면 `deploy-web.yml`이 **운영자(`joshua92y`)가 연 PR에 한해** `wrangler deploy --env preview` → `https://preview.joshuatech.dev`(별도 Worker `joshuatech-web-preview`, Access GitHub IdP, dev 시크릿; fork PR·봇 PR은 미생성); prod는 main `deploy`만(GitHub Environment `production` — prod `CLOUDFLARE_API_TOKEN`·`JT_CI_APP_PRIVATE_KEY`·`SENTRY_AUTH_TOKEN`은 환경 시크릿).

## US6 — pod 템플릿

```bash
copier copy templates/django-pod tests/fixtures/generated/sample-pod --data pod_name=sample-pod --defaults   # 경로는 gitignore
cd tests/fixtures/generated/sample-pod && uv sync && docker compose -f compose.dev.yml up -d && uv run pytest -q   # all passed
docker buildx build --platform linux/arm64 -t sample-pod:test .                                # 성공
```
기대 테스트: `test_tenant_rls`(A 등급 0행 2건 + owner bypass 전체 + B 등급 전역 테이블), `test_outbox`(발행·삭제·실패 attempts), `test_auth_middleware`(5 케이스 + Dragonfly 실패 503), `test_health`(`/healthz`·`/ready`·`/health`), `test_logging`, `test_openapi_snapshot`.

## US7 — 관측·RAM

```bash
for i in 1 2 3; do kubectl top nodes; sleep 600; done            # 단위 환산 후 A ≤ 9 GiB, B ≤ 8 GiB (kubectl top의 Mi ÷ 1024; plan A14 requests 합계: A ≈ 8.6 GiB, B ≈ 3.6 GiB)
kubectl top pods -A --sort-by=memory | head -15                   # report 표 입력(GiB로 환산해 기록)
kubectl get ns monitoring                                         # 존재(Alloy ns; observability 아님)
oci --profile svc-verify usage-api usage-summary request-summarized-usages --tenant-id $T --time-usage-started 2026-09-01T00:00:00Z --time-usage-ended 2026-10-01T00:00:00Z --granularity MONTHLY --query-type COST --group-by '["service"]'   # Compute ≤ 3 SGD
oci --profile svc-verify budgets budget list --compartment-id $T   # 예산 35 SGD 1개, 알림 규칙 4개(ACTUAL 10/50/100% · FORECAST 100%)
```
Grafana Cloud(Viewer 서비스 계정 토큰으로 조회): 대시보드 3개에 데이터, 알림 규칙 **13개** `Normal` — `NodeMemoryHigh`·`ArgoAppOutOfSync`·`ArgoAppUnhealthy`·`CnpgBackupStale`·`PlatformBackupStale`·`PvcUsageHigh`·`VaultSealed`·`CertExpiringSoon`·`QuotaNearLimit`·`NodeDiskLow`·`OutboxOldestPending`·**`MetricsAbsent`**(`absent()` 합집합 6개 조건 — `argocd_app_info` 포함, 각 30m; 정의 정본은 plan §Observability 표)·**`UpgradeJobFailed`**(`kube_job_status_failed{namespace="system-upgrade"} > 0`), 각 규칙에 `runbook_url` = `docs/runbooks/incident-response.md#<slug>`, mute timing 일요일 03:00–05:00 KST. Explore에서 `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total`(relay 9464 scrape)과 `vault_core_unsealed`·`cnpg_collector_last_available_backup_timestamp`·`platform_backup_last_success_timestamp{component="k3s"}`·`{component="vault"}` 조회됨(하나라도 비면 `MetricsAbsent`가 먼저 뜬다 = 스크레이프 경로가 막힌 것). Sentry(읽기 토큰): identity-admin `raise` 테스트 이벤트 1건(`request_id` 태그). Cloudflare(`Account Analytics:Read` 토큰): Workers 일 요청 수·CPU p95. **VD-7**: k8s-monitoring 차트는 4.5.0 핀이고 4.5.1 존재 여부·Grafana Viewer 서비스 계정이 Free 사용자 수(3)를 소모하는지는 T098·T096 착수 시 확인해 report에 적는다.

## US8 — v1 정리

```bash
gh workflow list -R joshua92y/joshtech                            # 4개, 트리거 workflow_dispatch만(파일 확인)
gh secret list -R joshua92y/joshtech                              # 빈 출력(v1 GitHub Secrets 전부 삭제, T012)
# Cloudflare 대시보드 → API Tokens: v1 API 토큰·R2 토큰 revoked (수동 확인, 시각만 기록)
oci --profile svc-verify compute instance list --compartment-id $T --query 'data[*].{name:"display-name",id:id,state:"lifecycle-state"}'   # OCID 2개 불변, RUNNING
ssh via cloudflared: lsb_release -a                               # Ubuntu 24.04 (클라이언트 2026.5.1 핀, 세션 후 cloudflared access logout)
ssh via cloudflared: cat ~/.ssh/authorized_keys                   # 두 노드 모두 jt-ops 1줄만(구 키 0, T103)
dig +short joshuatech.dev                                         # Cloudflare 프록시 IP, curl → v2 hello
dig +short preview.joshuatech.dev                                 # Cloudflare 프록시 IP(Workers preview), curl -sI → 302 Access
dig +short api.joshuatech.dev mainapi.joshuatech.dev                       # 빈 출력
dig +short admin.joshuatech.dev traefik.joshuatech.dev                     # Cloudflare 프록시 IP (v2 노드 A로 교체됨)
```
Render·Fly 대시보드에 서비스 0개(스크린샷을 report에 첨부하지 않고 시각만 기록; 잔여 확인은 T105).

v1 SSH 키 보관·파기 순서(`docs/runbooks/bootstrap.md` §0 토큰 표, T005): ① 새 키 `jt-ops` 생성 — FIDO2 하드웨어 키를 쓰고, 불가하면 passphrase + `ssh-add -c`(사용 때마다 확인 프롬프트) → ② 두 노드 `~ubuntu/.ssh/authorized_keys`를 `jt-ops` 한 줄로 교체하고 접속 확인(T014 `host-prep.sh`, `ssh_authorized_keys`는 재이미지로 바뀌지 않으므로 반드시 스크립트가 교체) → ③ 위 "구 키 0" 단언(T103) 통과 → ④ v1 개인키를 워크스테이션·비밀번호 관리자에서 파기하고 **파기 시각을 기록**. v1 GitHub Secrets·Cloudflare v1 API/R2 토큰은 T012에서 이미 폐기됐으므로 여기서는 목록이 비어 있는지만 본다.

## US9 — 에이전트 계층

```bash
ls .claude/agents/{web,api,infra}-builder.md .claude/skills/approval-review/boundaries/k8s-security.md
pwsh -NoProfile -File tests/run-all.ps1                           # 미러·헤더 검사 PASS
```
`/approval-review` 실행 결과 파일에 `## K8s security` 절 존재(승인 단계에서 확인).

## 롤백 요약

| 대상 | 방법 |
|---|---|
| 앱 배포 | gitops `git revert` PR → Argo sync(≤ 5분) |
| 웹 | `wrangler rollback`(prod Worker, 최근 버전 선택); preview Worker는 PR 재배포 |
| 플랫폼 컴포넌트 | gitops revert; CRD 제거는 `Delete=confirm`으로 사람 확인. 비가역 변경(CNPG/Strimzi 오퍼레이터 다운그레이드·Kafka `metadataVersion`·PG major·Authentik 스키마·Django contract 단계)은 revert 불가 → `rollback.md` 비가역 변경 표의 복구 경로 |
| K3s 업그레이드 | `INSTALL_K3S_VERSION` 핀 재설치 → `systemctl stop k3s` → SUC `prepare`가 만든 `--pre-upgrade` 번들을 `age -d -i <개인키>`로 풀어 `server/db/state.db`(잔재 `-wal`·`-shm` 제거)·`server/token`·`server/cred/`·`server/tls/` 복원 → `systemctl start k3s` → 노드 B 재조인 — **`k3s server --cluster-reset`은 실행 금지**(embedded etcd 전용, SQLite 구성에서 실행하면 etcd로 비가역 전환); 계획 다운타임, 창 일요일 03:00–05:00 KST |
| Vault | `jt-backup-platform/vault/` 스냅샷 복호화 → `vault operator raft snapshot restore -force`(같은 KMS 키 필수) — 런북 `vault-unseal` |
| DB | CNPG `bootstrap.recovery`(barman-cloud PITR)는 `pg-main` 클러스터 전체(재해 복구 전용); 단일 DB = side Cluster PITR → `pg_dump` → 복원 — 런북 `restore-drill` |
| 인프라 | `tofu plan`에서 destroy 0 확인 후 apply; 인스턴스·KMS 키는 `prevent_destroy` |
| 도메인 | Cloudflare DNS 레코드 되돌리기(TTL auto ≈ 5분) |
