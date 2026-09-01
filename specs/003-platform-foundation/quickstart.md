# Quickstart: 플랫폼 기반 (SP-1) 검증 가이드

US별로 "이 명령을 치면 이 결과가 나와야 한다"를 적는다. 구현 절차는 `tasks.md`와 런북에, 계약은 `contracts/`에 있다. 모든 클러스터 명령은 cloudflared 터널 뒤에서(`cloudflared access tcp --hostname k8s.joshuatech.dev --url 127.0.0.1:6443`) `KUBECONFIG`를 잡은 뒤 실행한다.

## 사전 조건

- 개발기: Windows 11 + WSL(Ubuntu 24.04) — `uv`, `node 22`, `pnpm`, `wrangler 4`, `copier`, `kubectl`, `argocd`, `vault`, `oci`, `tofu`, `cloudflared`, `gh`, `docker`(testcontainers).
- 계정: OCI(PAYG, 춘천), Cloudflare(존 `joshuatech.dev`, Zero Trust Free, Workers Free), GitHub(org/App 생성 권한), Grafana Cloud Free, Sentry Free.
- 비밀은 Vault에만. 로컬 `.env`는 `env.example`에서 복사해 값을 채우되 커밋하지 않는다(gitleaks가 CI에서 막는다).

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
kubectl get nodes -o wide                            # 2 Ready, 라벨 role=platform / role=data
kubectl -n argocd get applications                   # root 포함 전부 Synced/Healthy (ES 제외)
kubectl -n argocd get appprojects default -o jsonpath='{.spec.sourceRepos}'   # [] (무력화)
curl -sI https://argo.joshuatech.dev | head -1       # 302 → Cloudflare Access 로그인
curl -sk --resolve argo.joshuatech.dev:443:<노드A IP> https://argo.joshuatech.dev   # TLS handshake 실패(AOP)
kubectl -n vault exec vault-0 -- vault status | grep -E 'Sealed|Seal Type'     # Sealed false, Seal Type ocikms
kubectl get externalsecret -A | grep -v SecretSynced # 빈 출력
gitleaks detect --source . --no-git                  # 0 findings (두 저장소)
```
재부팅 시나리오: `sudo reboot`(노드 A) → 5분 뒤 `vault status` Sealed false, ESO `Ready`.

## US3 — 데이터·이벤트 플랫폼

```bash
kubectl -n data get cluster pg-main                  # Cluster in healthy state, instances 1
kubectl -n data get databases                        # identity_admin authentik openfga … (dev_ 접두 포함)
kubectl -n data exec pg-main-1 -- psql -U identity_admin_app -d authentik -c 'select 1'   # permission denied for database
kubectl -n data get scheduledbackup,backup           # completed 1건
oci os object list --bucket-name jt-backup --query 'data[?contains(name, `base`)].name'  # 베이스 백업 오브젝트
kubectl -n data get kafka,kafkanodepool,kafkatopic,kafkauser
# produce/consume 왕복(5초 내)
kubectl -n data run kcat --rm -it --image=edenhill/kcat:1.7.1 -- kcat -b jt-kafka-bootstrap:9092 -X security.protocol=SASL_SSL ... -t identity-admin.session.revoked -P
kubectl -n data exec deploy/dragonfly-prod -- redis-cli ping   # NOAUTH 오류(인증 필수)
```

## US4 — 신원·인가

1. 브라우저 `https://auth.joshuatech.dev` → GitHub 로그인 → 사용자 설정 Sessions에 세션 1건.
2. 토큰 교환:
```bash
ACCESS=$(curl -s -X POST https://auth.joshuatech.dev/application/o/token/ -d grant_type=urn:ietf:params:oauth:grant-type:token-exchange -d subject_token=$WEB_BFF_TOKEN -d audience=identity-admin -u $WEB_BFF_CLIENT_ID:$WEB_BFF_SECRET | jq -r .access_token)
echo $ACCESS | cut -d. -f2 | base64 -d | jq '{aud, tenant_id, exp}'        # aud identity-admin, tenant_id 존재, exp = iat+300
curl -s -X POST … -d audience=portfolio-core …                             # error: invalid_target (SP-1 미허용)
```
3. 폐기: `curl -X POST https://joshuatech.dev/api/auth/logout -H 'x-csrf-token: …' -b jt_session=…` → 1초 뒤 `curl -H "Authorization: Bearer $ACCESS" -H "CF-Access-Client-Id: …" https://identity-m2m-prod.joshuatech.dev/tenants/me` → 401 `session_revoked`.
4. Authentik 관리자에서 세션 삭제 → identity-admin 로그에 `authentik_webhook` reason 기록 → 같은 401.
5. OpenFGA: `fga tuple write --store-id $STORE user:<sub> member tenant:<id>` → `fga query check user:<sub> member tenant:<id>` → `{"allowed":true}`.
6. Access: `curl -sI https://admin.joshuatech.dev/identity-admin/admin/` → 302(Access 로그인); 서비스 토큰 헤더로 `identity-m2m-prod…/health` → 200.

## US5 — 웹 hello·BFF 왕복

```bash
for l in ko en ja; do curl -s -o /dev/null -w '%{http_code}\n' https://joshuatech.dev/$l; done   # 200 200 200
curl -s https://joshuatech.dev/ko | grep -c 'data-note-slug'   # ≥ 2 (001·002 학습 노트)
curl -s https://joshuatech.dev/api/health | jq                  # {status: ok, upstream: identity-admin, upstream_ms: n}
pnpm --filter web build && node apps/web/scripts/bundle-budget.mjs   # server bundle gzip: x.xx MiB (≤ 2.5)
```
Workers 대시보드 → Analytics: `_next/static/*`는 "Static asset requests"로 집계, 페이지 GET·`/api/*`는 Worker 호출로 집계되며 CPU p95 ≤ 10 ms·Error 1102 0건(일 요청 수를 report에 기록). PR을 열면 `deploy-web.yml`이 프리뷰 URL 코멘트(`pr-<n>` 별칭).

## US6 — pod 템플릿

```bash
copier copy templates/django-pod /tmp/sample-pod --data pod_name=sample-pod --defaults
cd /tmp/sample-pod && uv sync && docker compose -f compose.dev.yml up -d && uv run pytest -q   # all passed
docker buildx build --platform linux/arm64 -t sample-pod:test .                                # 성공
```
기대 테스트: `test_tenant_rls`(0행 2건 + owner 전체), `test_outbox`(발행·삭제·실패 attempts), `test_auth_middleware`(5 케이스), `test_health`, `test_logging`, `test_openapi_snapshot`.

## US7 — 관측·RAM

```bash
for i in 1 2 3; do kubectl top nodes; sleep 600; done            # A ≤ 9 GB, B ≤ 8 GB
kubectl top pods -A --sort-by=memory | head -15                   # report 표 입력
oci usage-api usage-summary request-summarized-usages --tenant-id $T --time-usage-started 2026-09-01T00:00:00Z --time-usage-ended 2026-10-01T00:00:00Z --granularity MONTHLY --query-type COST --group-by '["service"]'   # Compute ≤ 3 SGD
oci budgets budget list --compartment-id $T                       # 예산 35 SGD 1개, 알림 규칙 4개
```
Grafana Cloud: 대시보드 3개에 데이터, 알림 규칙 2개 `Normal`. Sentry: identity-admin `raise` 테스트 이벤트 1건(`request_id` 태그).

## US8 — v1 정리

```bash
gh workflow list -R joshua92y/joshtech                            # 4개, 트리거 workflow_dispatch만(파일 확인)
oci compute instance list --compartment-id $T --query 'data[*].{name:"display-name",id:id,state:"lifecycle-state"}'   # OCID 2개 불변, RUNNING
ssh via cloudflared: lsb_release -a                               # Ubuntu 24.04
dig +short joshuatech.dev                                         # Cloudflare 프록시 IP, curl → v2 hello
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
| 웹 | `wrangler rollback`(최근 버전 선택) |
| 플랫폼 컴포넌트 | gitops revert; CRD 제거는 `Delete=confirm`으로 사람 확인 |
| DB | CNPG `bootstrap.recovery`(barman-cloud, PITR) — 런북 `restore-drill` |
| 인프라 | `tofu plan`에서 destroy 0 확인 후 apply; 인스턴스는 `prevent_destroy` |
| 도메인 | Cloudflare DNS 레코드 되돌리기(TTL auto ≈ 5분) |
