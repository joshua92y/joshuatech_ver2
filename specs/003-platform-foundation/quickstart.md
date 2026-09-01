# Quickstart: 플랫폼 기반 (SP-1) 검증 가이드

US별로 "이 명령을 치면 이 결과가 나와야 한다"를 적는다. 구현 절차는 `tasks.md`와 런북에, 계약은 `contracts/`에 있다. 모든 클러스터 명령은 cloudflared 터널 뒤에서(`cloudflared access tcp --hostname k8s.joshuatech.dev --url 127.0.0.1:6443`) `KUBECONFIG`를 잡은 뒤 실행한다. 그 kubeconfig는 SA `agent-view`(ns `kube-system`)의 단기 토큰으로 만든 것만 쓴다 — `kubectl create token agent-view -n kube-system --duration=8h`. admin kubeconfig(`k3s.yaml`)는 운영자 비밀번호 관리자에만 있고 에이전트·tester·CI에는 배포하지 않는다. 값·이름은 `research/2026-09-01-approval-remediation.md`(R1–R25)를 따른다.

## 사전 조건

- 개발기: Windows 11 + WSL(Ubuntu 24.04) — `uv`, `node 24`, `pnpm`, `wrangler 4`, `copier`, `kubectl`, `argocd`, `vault`, `oci`, `tofu`, `cloudflared`, `gh`, `age`, `docker`(testcontainers).
- 계정: OCI(PAYG, 춘천), Cloudflare(존 `joshuatech.dev`, Zero Trust Free, Workers Free), GitHub(org/App 생성 권한), Grafana Cloud Free, Sentry Free.
- 비밀은 Vault에만. 로컬 `.env`는 `env.example`에서 복사해 값을 채우되 커밋하지 않는다(gitleaks가 CI에서 막는다).
- age 키 쌍: 운영자가 `age-keygen`으로 1회 생성. 공개키만 노드 A에 두고(`platform-backup.sh`가 `age -r <공개키>`로 K3s 번들·Vault 스냅샷을 암호화), 개인키는 오프라인(Vault recovery key와 같은 곳)에 보관해 복원 때만 꺼낸다.
- 에이전트·tester·CI 클러스터 자격: SA `agent-view` = ClusterRole `view` 집계 + `applications.argoproj.io` get/list + Role(`vault` ns) `pods/portforward`. Secret get·exec 없음. `kubectl auth whoami`가 `system:serviceaccount:kube-system:agent-view`여야 한다(T004 단언). 아래에서 `exec`·`run`이 필요한 명령은 운영자가 admin kubeconfig로 실행하고 출력을 tester 보고에 첨부한다.
- E2E 신원: Authentik 로컬 사용자 `e2e@joshuatech.dev`(비밀번호·TOTP 시드는 Vault `kv/{env}/e2e`). GitHub 테스트 계정은 만들지 않으며, 소셜 로그인(US4 AC1)은 운영자가 브라우저로 1회 수동 검증하고 스크린샷을 tester 보고에 첨부한다. 운영자 개인 계정 자격은 어떤 환경변수·파일에도 넣지 않는다. Playwright storageState는 `e2e/.auth/`(gitignore, 실행 후 삭제), trace는 `mask`.

## US1 — 결정 문서화

```bash
pwsh -NoProfile -File tests/run-all.ps1            # ADR MADR 검사·미러·CLAUDE.md 줄 수 포함, ALL PASS
ls docs/decisions/00{02..10}-*.md                   # 9개
grep -l '^paths:' .claude/rules/{web,django-pod,fastapi-pod,infra,events}.md | wc -l   # 5
```
기대: run-all ALL PASS, `docs/README.md`에 0002–0010 링크, `.specify/memory/{product,architecture}.md` 존재.

## US2 — 클러스터·GitOps·인그레스·시크릿

```bash
cd infra/oci && tofu plan                            # destroy 0개(인스턴스 재이미지는 부트 볼륨 교체만)
kubectl auth whoami                                  # system:serviceaccount:kube-system:agent-view
kubectl get nodes -o wide                            # 2 Ready, 라벨 role=platform / role=data
kubectl get ns -L pod-security.kubernetes.io/enforce # 14개 전부 PSA 라벨(restricted/baseline/privileged), monitoring 존재·observability 없음
kubectl get networkpolicy -A | grep -c default-deny  # 13 (kube-system 제외 전 ns); allow-dns 13, deny-imds 14
kubectl -n argocd get applications                   # root 포함 전부 Synced/Healthy (ES 제외)
kubectl -n argocd get appprojects default -o jsonpath='{.spec.sourceRepos}'   # [] (무력화)
kubectl -n system-upgrade get plans                  # k3s-server, k3s-agent (window 일요일 03:00–05:00 KST)
kubectl -n reloader get deploy                       # reloader 1/1
curl -sI https://argo.joshuatech.dev | head -1       # 302 → Cloudflare Access 로그인
curl -sk --resolve argo.joshuatech.dev:443:<노드A IP> https://argo.joshuatech.dev   # TLS handshake 실패(AOP)
kubectl -n vault port-forward svc/vault 8200:8200 &  # agent-view는 vault ns pods/portforward만(exec 없음)
curl -s http://127.0.0.1:8200/v1/sys/seal-status | jq '{sealed, type}'          # {"sealed": false, "type": "ocikms"}
kubectl get clustersecretstore                       # vault-platform, vault-dev, vault-prod — 3개 Ready
kubectl get externalsecret -A | grep -v SecretSynced # 빈 출력
for b in jt-tfstate jt-backup jt-backup-platform; do oci os bucket get --bucket-name $b --query 'data."public-access-type"'; done   # NoPublicAccess × 3
oci os object list --bucket-name jt-backup-platform --prefix k3s/ --query 'data[].name'     # *.tar.age ≥ 1, 평문 sqlite 0
oci os object list --bucket-name jt-backup-platform --prefix vault/ --query 'data[].name'   # *.age ≥ 1 (Vault Raft 스냅샷)
oci iam dynamic-group get --dynamic-group-id <jt-node-a OCID> --query 'data."matching-rule"'   # 노드 A 인스턴스 OCID만
gitleaks detect --source . --no-git                  # 0 findings (두 저장소)
```
재부팅 시나리오: `sudo reboot`(노드 A) → 5분 뒤 `seal-status`가 `sealed false`, ESO `Ready`. 백업: 노드 A `systemctl list-timers platform-backup.timer` → 다음 실행 매일 02:30 KST; SUC Plan의 `prepare` 단계 로그에 `platform-backup.sh --pre-upgrade` 실행 기록. KMS 키는 OpenTofu에 `prevent_destroy` + 삭제 유예 30일(`tofu state show`로 확인).

## US3 — 데이터·이벤트 플랫폼

```bash
kubectl -n data get cluster pg-main                  # Cluster in healthy state, instances 1
kubectl -n data get databases                        # identity_admin dev_identity_admin authentik openfga (SP-1 4개)
kubectl -n data exec pg-main-1 -- psql -U identity_admin_app -d authentik -c 'select 1'   # permission denied for database (운영자 실행)
kubectl -n data get scheduledbackup,backup           # schedule "0 0 17 * * *"(02:00 KST 매일), completed 1건
oci os object list --bucket-name jt-backup --query 'data[?contains(name, `base`)].name'  # 베이스 백업 오브젝트
kubectl -n data get kafka,kafkanodepool,kafkatopic,kafkauser
# produce/consume 왕복(5초 내) — 운영자 실행
kubectl -n data run kcat --rm -it --image=edenhill/kcat:1.7.1 -- kcat -b jt-kafka-bootstrap:9092 -X security.protocol=SASL_SSL ... -t identity-admin.session.revoked -P
kubectl -n data exec deploy/dragonfly-prod -- redis-cli ping   # NOAUTH 오류(ACL 사용자 인증 필수, 운영자 실행)
```

## US4 — 신원·인가

1. 소셜 로그인(US4 AC1)은 운영자 수동 1회: 브라우저 `https://auth.joshuatech.dev` → GitHub 로그인 → 사용자 설정 Sessions에 세션 1건 — 스크린샷을 tester 보고에 첨부. tester 자동화는 Authentik 로컬 사용자 `e2e@joshuatech.dev`(Vault `kv/{env}/e2e`)로 Playwright 로그인, storageState `e2e/.auth/`(실행 후 삭제).
2. 토큰 교환(RFC 8693 delegation — `$WEB_BFF_TOKEN`은 사용자 토큰(aud web-bff), `$BFF_ACTOR_TOKEN`은 BFF의 client-credentials 토큰):
```bash
ACCESS=$(curl -s -X POST https://auth.joshuatech.dev/application/o/token/ -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d subject_token=$WEB_BFF_TOKEN -d actor_token=$BFF_ACTOR_TOKEN -d actor_token_type=urn:ietf:params:oauth:token-type:access_token -d audience=identity-admin -u $WEB_BFF_CLIENT_ID:$WEB_BFF_SECRET | jq -r .access_token)
echo $ACCESS | cut -d. -f2 | base64 -d | jq '{aud, tenant_id, act, exp}'   # aud identity-admin, tenant_id(uuid) 존재, act.sub web-bff, exp = iat+300
curl -s -X POST … -d audience=portfolio-core …                             # error: invalid_target (SP-1 미허용)
```
3. 폐기: `curl -X POST https://joshuatech.dev/api/auth/logout -H 'x-csrf-token: …' -b jt_session=…` → 1초 뒤 `curl -H "Authorization: Bearer $ACCESS" -H "CF-Access-Client-Id: …" https://identity-m2m-prod.joshuatech.dev/tenants/me` → 401 `session_revoked`.
4. Authentik 관리자에서 세션 삭제 → identity-admin 로그에 `authentik_webhook` reason 기록 → 같은 401.
5. OpenFGA: `fga tuple write --store-id $STORE user:<sub> member tenant:<uuid>` → `fga query check user:<sub> member tenant:<uuid>` → `{"allowed":true}`.
6. Access: `curl -sI https://admin.joshuatech.dev/identity-admin/admin/` → 302(Access 로그인); `curl -sI https://auth.joshuatech.dev/if/admin/` → 302(Access 앱 `auth-admin`, GitHub IdP); `curl -sI https://auth.joshuatech.dev/application/o/<app>/.well-known/openid-configuration` → 200(공개); 서비스 토큰 헤더로 `identity-m2m-prod…/health` → 200.

## US5 — 웹 hello·BFF 왕복

```bash
for l in ko en ja; do curl -s -o /dev/null -w '%{http_code}\n' https://joshuatech.dev/$l; done   # 200 200 200
curl -s https://joshuatech.dev/ko | grep -c 'data-note-slug'   # ≥ 2 (001·002 학습 노트)
curl -s https://joshuatech.dev/api/health | jq                  # {status: ok, upstream: identity-admin, upstream_ms: n}
pnpm --filter web build && node apps/web/scripts/bundle-budget.mjs   # server bundle gzip: x.xx MiB (≤ 2.5)
```
Workers 대시보드 → Analytics: `_next/static/*`는 "Static asset requests"로 집계, 페이지 GET·`/api/*`는 Worker 호출로 집계되며 CPU p95 ≤ 10 ms·Error 1102 0건(일 요청 수를 report에 기록). `e2e/hello.spec.ts` 가드: 로드 후 30초 내 `Next-Router-Prefetch: 1` 요청 ≤ 10(plan A2). PR을 열면 `deploy-web.yml`이 같은 repo PR에 한해 `wrangler deploy --env preview` → `https://preview.joshuatech.dev`(별도 Worker `joshuatech-web-preview`, Access GitHub IdP, dev 시크릿; fork PR은 미생성); prod는 main `deploy`만(GitHub Environment `production`).

## US6 — pod 템플릿

```bash
copier copy templates/django-pod tests/fixtures/generated/sample-pod --data pod_name=sample-pod --defaults   # 경로는 gitignore
cd tests/fixtures/generated/sample-pod && uv sync && docker compose -f compose.dev.yml up -d && uv run pytest -q   # all passed
docker buildx build --platform linux/arm64 -t sample-pod:test .                                # 성공
```
기대 테스트: `test_tenant_rls`(A 등급 0행 2건 + owner bypass 전체 + B 등급 전역 테이블), `test_outbox`(발행·삭제·실패 attempts), `test_auth_middleware`(5 케이스 + Dragonfly 실패 503), `test_health`(`/healthz`·`/ready`·`/health`), `test_logging`, `test_openapi_snapshot`.

## US7 — 관측·RAM

```bash
for i in 1 2 3; do kubectl top nodes; sleep 600; done            # A ≤ 9 GB, B ≤ 8 GB (plan A14 requests 합계: A ≈ 8.9, B ≈ 3.1)
kubectl top pods -A --sort-by=memory | head -15                   # report 표 입력
kubectl get ns monitoring                                         # 존재(Alloy ns; observability 아님)
oci usage-api usage-summary request-summarized-usages --tenant-id $T --time-usage-started 2026-09-01T00:00:00Z --time-usage-ended 2026-10-01T00:00:00Z --granularity MONTHLY --query-type COST --group-by '["service"]'   # Compute ≤ 3 SGD
oci budgets budget list --compartment-id $T                       # 예산 35 SGD 1개, 알림 규칙 4개(ACTUAL 10/50/100% · FORECAST 100%)
```
Grafana Cloud: 대시보드 3개에 데이터, 알림 규칙 11개 `Normal` — `NodeMemoryHigh`·`ArgoAppOutOfSync`·`ArgoAppUnhealthy`·`CnpgBackupStale`·`PlatformBackupStale`·`PvcUsageHigh`·`VaultSealed`·`CertExpiringSoon`·`QuotaNearLimit`·`NodeDiskLow`·`OutboxOldestPending`, 각 규칙에 `runbook_url` = `docs/runbooks/incident-response.md#<slug>`, mute timing 일요일 03:00–05:00 KST. Explore에서 `outbox_pending`·`outbox_oldest_pending_seconds`·`outbox_dead_total`(relay 9464 scrape)과 `vault_core_unsealed`·`cnpg_collector_last_available_backup_timestamp` 조회됨. Sentry: identity-admin `raise` 테스트 이벤트 1건(`request_id` 태그).

## US8 — v1 정리

```bash
gh workflow list -R joshua92y/joshtech                            # 4개, 트리거 workflow_dispatch만(파일 확인)
gh secret list -R joshua92y/joshtech                              # 빈 출력(v1 GitHub Secrets 전부 삭제, T012)
# Cloudflare 대시보드 → API Tokens: v1 API 토큰·R2 토큰 revoked (수동 확인, 시각만 기록)
oci compute instance list --compartment-id $T --query 'data[*].{name:"display-name",id:id,state:"lifecycle-state"}'   # OCID 2개 불변, RUNNING
ssh via cloudflared: lsb_release -a                               # Ubuntu 24.04
ssh via cloudflared: cat ~/.ssh/authorized_keys                   # jt-ops 1줄만(구 키 0, T102)
dig +short joshuatech.dev                                         # Cloudflare 프록시 IP, curl → v2 hello
dig +short preview.joshuatech.dev                                 # Cloudflare 프록시 IP(Workers preview), curl -sI → 302 Access
dig +short api.joshuatech.dev mainapi.joshuatech.dev                       # 빈 출력
dig +short admin.joshuatech.dev traefik.joshuatech.dev                     # Cloudflare 프록시 IP (v2 노드 A로 교체됨)
```
Render·Fly 대시보드에 서비스 0개(스크린샷을 report에 첨부하지 않고 시각만 기록).

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
| K3s 업그레이드 | `INSTALL_K3S_VERSION` 핀 재설치 → `k3s server --cluster-reset` + SQLite 복원(SUC `prepare`가 만든 `--pre-upgrade` 스냅샷, `age -d -i <개인키>`) — 계획 다운타임; 창 일요일 03:00–05:00 KST |
| Vault | `jt-backup-platform/vault/` 스냅샷 복호화 → `vault operator raft snapshot restore -force`(같은 KMS 키 필수) — 런북 `vault-unseal` |
| DB | CNPG `bootstrap.recovery`(barman-cloud PITR)는 `pg-main` 클러스터 전체(재해 복구 전용); 단일 DB = side Cluster PITR → `pg_dump` → 복원 — 런북 `restore-drill` |
| 인프라 | `tofu plan`에서 destroy 0 확인 후 apply; 인스턴스·KMS 키는 `prevent_destroy` |
| 도메인 | Cloudflare DNS 레코드 되돌리기(TTL auto ≈ 5분) |
