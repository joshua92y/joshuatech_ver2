# T042 전체 검수 — 최종 판정 (2026-09-10)

정본 = `t042-audit-fable.md`(fable 종합, 51건 생존 · 52건 탈락 · 확인 130여 항목). 이 파일은 컨트롤러 초안과의 대조 결과와 실행 순서만 담는다.
원본 지적 103건 = `t042-audit-raw.md`. 워크플로 = `t042-full-audit.js` (run `wf_1e75552d-64c`).

## 1. 판정

- **라이브·매니페스트 건전.** critical/high 생존 0건. Certificate ↔ TLSStore ↔ 테스트 상수 4곳 Ordinal 일치, ACME 배선·CRD 스키마·Application/AppProject 정합, 정책 add-only, 시크릿 0, 강제 푸시 0, 동결 파일 무변경, 계약 정정(d5f8a82)이 PR #13 머지 3분 54초 전.
- **결함 = 문서와 실제의 어긋남.** medium 8 · low 15 · info 3. 컨트롤러가 실측 뒤 문면을 갱신하지 않은 것이 대부분.
- **PR-4 머지: README 2줄(:84·:206 hard refresh 대상 root→platform-traefik) 고친 뒤 go.** 같은 커밋에 문면 정정 4건 편승.

## 2. 컨트롤러 초안에서 정정된 것 (fable 종합·검증자 반박으로 뒤집힘)

| 초안 주장 | 정정 | 근거 |
|---|---|---|
| block-pr4 7건 | **차단은 :84·:206 두 줄뿐.** TR-2/3/4/6은 편승 권고(게이트·런타임 영향 0) | 검증자 버킷 조정 |
| pwsh에서 jsonpath `[?(@.type=="Ready")]` 큰따옴표가 깨진다 | **틀림.** pwsh 7.6.5 실측 정상. 깨지는 조건은 `custom-columns=A:.x,B:'…'`처럼 **쉼표 뒤 작은따옴표**. 런북 :218 원인 서술도 오기 | TR-7 반박 |
| kubeconform이 TLSStore를 skip → validate.sh 검사 1 공백(기지 결함 c, T047 인계 ④) | **틀림.** validate.sh는 항상 datree `-schema-location`을 넘기고 캐시에 `traefik.io/tlsstore_v1alpha1.json`이 실재(2026-09-09 19:13) → **실제로 검증했다.** "skipped"는 맨몸 kubeconform 실행. traefik README §10 ④·PR #16 본문 86행 정정 필요. 벤더링은 오프라인 결정성 개선 옵션 | test-9 반박 |
| 32a1022 트레일러 누락(기지 결함 d) | GitHub squash가 `Co-authored-by` 소문자 1줄로 정규화 → 저작 표기 보존 | PG-11 |
| root refresh는 무조건 틀림 | **범위 명시형**: root 자신의 소스(`clusters/oci-k3s/apps/`, 새 child 정의)가 바뀌면 root가 정답(T041 PR-B2), 기존 child의 `platform/<comp>/`만 바뀌면 child. 일괄 치환 금지 | M-1 |
| cert-manager 재시작 실행 여부 미기록(운영자 확인) | **재시작 없었다는 긍정 증거 있음**: build-notes:153 `sync_call_count` 273→282 연속 증가. 확인 항목에서 제외 | OPS-5 반박 |
| 10.42.0.0/32 주석이 hostNetwork·kube-system privileged를 빠뜨림 | 스푸핑 SYN-ACK가 호스트 netns로 돌아가 핸드셰이크 불가, 오늘 노드 A hostNetwork 파드 0, :631·:649-657이 재검토 조건 명시 → 결함 아님 | NP-6 반박 |
| 단일 서버 전제 미명시 | 계약 :50이 노드 무관 일반형, 노드 B 승격 시 LOCAL 예외로 통과 실측, spec.md:202 단일 서버 명시 | NP-8 반박 |
| D5·D6·ACME 키 결정이 파일 어디에도 없다 | D6=A1은 cad608a 본문 34행, D5는 PR #16 본문·설계 §7 단계 9, ACME 키는 issuers README §3/§11·ClusterIssuer 주석에 있음. **남는 공백 = 설계 §14.5 표 셀("⏸ 다음"·"실측 후")과 런북 결정표** | DOC-11·FD-07 |
| "port 53 누수" (컨트롤러 부수 발견 ①) | YAML·kube-router 코드로 성립 불가. UDP fire-and-forget 프로브가 REJECT ICMP보다 먼저 "성공"했을 가능성. **인계처는 T047이 아니라 np-5-live(T031)→T102.** 재측정은 응답 요구 프로브(`dig +time=2 +tries=1`) | M-3 |
| renewBefore 40% 처방 | 64일 수명에서 25.6일 < 30 → cert-2 4.4일/주기 FAIL. ≥47%, 실용 50 | L-5 (초안과 동일, 재확인) |

## 3. 초안에 없던 신규 발견

- **차트 버전 bump 함정** (L-15): kustomize 5.8.1 `chartExistsLocally()`는 버전을 보지 않아 `charts/cert-manager`가 있으면 pull을 건너뛰고, repo-server는 최초 init 1회만 `git clean -ffdx` → `helmCharts[0].version`을 올려도 살아 있는 repo-server는 옛 차트를 재사용하며 hard refresh로 안 풀린다(재시작 또는 charts/ 제거 필요). cert-manager README §2/§3에 한 줄.
- **"노드 B 드레인 중" 문구 오류**: SUC Plan은 `cordon: true`만 있고 `drain:` 키 없음 → issuers README:21-26·cert-manager README:129-130의 근거 메커니즘이 존재하지 않음. "노드 B 비가용 중(SUC 창은 cordon만)"으로.
- **Traefik 전 ns Secret 읽기 = 폭발 반경 미등재** (SEC-9): chart 40.1.0 `rbac.namespaced: false`. `namespaced: true`는 IngressClass provider와 양립 불가 → **spec FR-011과 충돌** → converge 신규 task.
- **validate.sh는 `helmCharts[].repo`를 한 번도 읽지 않음** → AppProject sourceRepos가 인플레이트에 무력하므로 차트 출처는 정적 검사 밖. T047 검사 1에 허용 목록 단언.
- **테넌트 AppProject blacklist만으로는 ingress-shim 우회** (L-8): jt-dev Ingress에 `cert-manager.io/cluster-issuer` 어노테이션만으로 Certificate 생성(Ingress는 blacklist 불가). 완전 차단은 `disableAutoApproval: true` + approver-policy 또는 ns별 Issuer(converge 결정). 오늘 dev/prod/tests를 쓰는 Application 0개라 low. LE 중복 5/7일은 동일 SAN 집합 기준이라 와일드카드 슬롯 미소모.
- **origin-1 상시 단언 부재** (M-7): cert-1/cert-2 PASS인데 auth=526인 오늘 상태가 블라인드스팟 실증. `https://auth.joshuatech.dev/` 상태 ≠ 52x(T080 전 404 허용) → converge + T048 `-AfterReboot` 재실행.
- **validate.yml 스텁이 초록을 낸다** (M-6): T047 완성 전까지 job이 `exit 1`로 fail-loud 해야 함 — 기존 §11 T047 인계에 없음.
- **CAA 2단계** (L-9): 지금 `CAA 0 issue "letsencrypt.org"` + `issuewild` + `iodef mailto:contact@joshuatech.dev`(dns.tf + hostnames 표); `accounturi`·`validationmethods` 핀은 계정키 백업·복구 절차(T045/T084) 뒤.

## 4. 실행 순서 (버킷별 · fable §실행 목록 요약)

1. ~~**block-pr4**~~ → **완료 2026-09-10 · 커밋 `6b99400` · 푸시됨(fast-forward) · PR #16 draft 유지 · checks SUCCESS/CLEAN.**
   적용: README:84·:206 대상 교체 + root가 정답인 경우 명시 · §8 표(중복 시맨틱 2행) · §3 ③ 로그 확인 전면 재작성 · §7 만료 거동 · §9 ① `expire date` · §1 ⓪ 상태 코드만 · §6 IngressRoute 저장소 한정 · §10 ④ kubeconform 정정 · §10 ⑤ 인계 5건 · cert-2 47%/50.
   3렌즈 리뷰(26 에이전트, 적대적 검증) 생존 2건 반영 + 탈락 지적에서 사실이 옳았던 1건(내장 기본 minVersion) 자발 반영. 매니페스트 무변경(yq 파싱 결과 동일).
   PR #16 본문도 같은 4곳을 정정하고 「2026-09-10 문면 정정 커밋」 절을 추가했다.
2. ~~**머지 직후 확인**~~ → **완료 2026-09-10 07:45Z. main `4f23abd`(PR #16 squash, 트레일러 1개).**
   전건 통과: Synced/Healthy · TLSStore 1개 · secretName 일치(프루닝 없음) · Traefik 로그 0건 · **`auth` 526 → 404** ·
   전 호스트 526 0건 · v1 무영향. 머지 전 게이트는 **공개 CT(certspotter)로 독립 확인**했다 —
   `2026-09-09 → 2026-12-08 · Let's Encrypt CN=YE2 · SAN 2`(staging은 CT에 오르지 않으므로 체인 진위 확정).
3. **저장소 위생**: `git -C D:/code/platform-gitops pull --ff-only`, 워크트리 6 remove+prune, MERGED 로컬 14 삭제, 원격 6 삭제(`delete_branch_on_merge`는 사용자 확인).
4. **pr5** (jetstack 2줄 + 문서 정정): Certificate :6-8·:26·:41·:44-50·:50 · issuers README 시제(:1·:12·:17-18·:160·:281·§10)·:346·§13 갱신 전제 체크리스트·§1 사전 조회·§2 진단 순서(CNAME 먼저) · policies README/yaml(해소 표기·줄번호→리터럴·:272 8.8.8.8·:135/:276 UDP 7844·:117→:122) · hard refresh 대상 명시 4곳(cert-manager README:59,67,158 · issuers README:401) · L-7 주석 과장 2곳 · 차트 bump 함정·드레인 문구·Traefik 반경 1줄 · README §1 토큰 TTL 행 · dev/prod/tests blacklist + 계약 :43(**별도 PR 권장 — AppProject는 즉시 반영**) · I-1 관례 문장 · PR #14/#16 정정 코멘트.
5. **runbook**: §3 T042 실행 절(T041 5부 구조, durable 항목은 PR 본문 포인터) — 기준선 `auth=526·traefik=302·www=522(2026-09-10)` · PR SHA/시각 · 수동 Secret/고아 Secret 시각 · VD-H1/H2/**H3(운영자 회상: `rollout history deploy/argocd-repo-server`)** · CNAME 107분 + "DNS-01 pending이면 CNAME 먼저" · 갱신 ≈2026-11-08/만료 2026-12-08 · cert-2 창 7.2h/60d·2027-02-10 · 기대 FAIL(argo-2·vault-2) · 편차 ①③⑤ · D1–D6 결정표(D6 주체·시각) · :36/:114 T043→T045 · :236 `§2`→gitops README §2 · :218 원인 정정(쉼표+작은따옴표) + root/child 범위 · 프로브 파드 기록 · 53 재측정 결과. 설계 :576·:775(48/119)·§14.5 D5 각주(v-20·x-7 확정, doc-5/doc-6 문자열 유지)·D6 확정. 노트 필터 목록(ssh 별칭·파드 IP·Fly 식별자·개인 메일·토큰명).
6. **contract**: infra.md:27 + kr :28 + network-policy.md:74를 validate 5.3 문장으로; 계약 표 행 ID 도입.
7. **converge**: origin-1 · dns-1(DoH) · 8.8.8.8 문면 + research.md:894/:968 · cert-2 renewalTime 기반 · CAA 2단계 · approver-policy vs ns별 Issuer · Traefik RBAC 스코핑(FR-011 충돌) · 계약 :122 프로토콜 열 · 편차 ①–⑦.
8. **t047**: 도구 5종 핀·env·base ref·**fail-loud 스텁** · 4b 렌더 소스 + system-upgrade 예외 · Certificate ns 단언 · blacklist ⊇ 단언 · `helmCharts[].repo` 허용 목록 · 스키마 벤더링 검토 · `--enable-helm` 단언 · 10.42.0.0/32 두 항목 단언.
9. **operator-check**(읽기 전용): 프로브 파드 잔존(`get pods -o wide` 3개 · ephemeralContainers · orphaned 경고) · Secret 4장 + staging NotFound + `get certificate,certificaterequest,order,challenge` · 백업 타임스탬프 ≥ 2026-09-10 02:30 · VD-H3 · 53 재측정(`dig @8.8.8.8 +time=2 +tries=1` / `nc -zv -w3` / jt-dev 동일 = np-5-live) · 토큰 Expiration 없음(대시보드).

## 5. T042 외 관찰

- `run-all` 14/15 PASS; `tofu` 슬롯만 `TF_VAR_budget_alert_email` 미설정 fail-closed.
- `www.joshuatech.dev` 522(v1 오리진, 범위 밖).
- 모노레포 Codex 어댑터 미커밋 29건(알려짐, `git add -A` 금지).
