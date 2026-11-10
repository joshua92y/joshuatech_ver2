# Codex 인계 프롬프트 — SP-1 T045 G4 (2026-09-22)

아래 전문을 Codex에 그대로 붙여 넣으세요.

---

SP-1 feature `003-platform-foundation`의 T045 G4를 이어받는다. 모노레포는 `d:\code\joshuatech_ver2`(브랜치 `003-platform-foundation`, HEAD `2cb0a9d`), GitOps 저장소는 `d:\code\platform-gitops`(브랜치 `t045-g4-tunnel-secret`, HEAD `f2a6cff`, main `22f96c3`). 둘 다 **공개 저장소**다.

먼저 읽어라(순서대로):
1. `AGENTS.md` — 특히 **경로별 규칙 라우팅 표**. 파일을 고치기 전에 해당 `.claude/rules/*.md`를 전부 읽고 적용한다.
2. `.specify/memory/constitution.md`
3. `specs/003-platform-foundation/design/t045-blocks/g4/README.md` — **인계 상태·확정 설계·남은 일이 여기 다 있다.**
4. `docs/runbooks/bootstrap.md` §3 T045 절 — 실행 기록과 절차 메모.

## 지금 상태

T045는 `M0 → G0 → G1 → G1p → G2 → G2r → OP1(시드) → DR1(드릴) → G3 → **G4** → G5` 순서로 진행 중이고, **G3까지 라이브**다. tasks.md는 50/119이며 T045는 아직 체크하지 않았다.

G4 = 운영자가 T039에서 수동으로 만든 Secret `cloudflared/cloudflared-tunnel`(키 `TUNNEL_TOKEN`)을 ExternalSecret이 제자리 인수하는 단계다.

⚠ **이 Secret은 SSH·K8s API의 유일한 경로(Cloudflare Tunnel)의 자격이다.** 틀린 값으로 덮인 채 컨테이너가 다시 시작되면 운영자가 클러스터와 노드에서 함께 잠긴다. env(`secretKeyRef`)는 파드가 아니라 **컨테이너가 시작할 때마다** kubelet이 다시 읽는다 — 제자리 재시작(liveness `/ready` 10s×6 실패 · OOMKill · 노드 재부팅)도 포함이므로 "실행 중 컨테이너가 옛 값을 들고 있다"는 안전망은 **재시작되지 않는 동안만** 유효하다. 값이 틀린 상태는 안전 상태가 아니라 **시한 상태**다.

- **gitops PR #29** — 열려 있고 체크 통과(`validate` pass · GitGuardian pass · MERGEABLE/CLEAN). **머지하지 않았다.** 머지 = 적용이고 잠금 위험이라 **사용자 입회 하에** 머지한다.
- **운영자 블록은 미완이다.** 5라운드 검수·수정·적대적 검증을 거쳤고(하네스 121/121 · 변이 201/201), 사용자가 2026-09-22에 **구조 변경을 결정**했다 — 아직 반영 전이다.

## 해야 할 일 (README.md 「남은 일」과 같다)

1. **블록 분리** — `g4-adopt.ps1`을 읽기 전용(클러스터 쓰기 0건)으로 만들고, 파드 1개 교체를 `g4-drill.ps1`로 분리한다. `drilled:` 접두어 사슬 · `first-drill` · `nopods` · 이전 드릴 감지 · `$podDrill` 체인은 전부 삭제한다. 상세 설계는 README.md의 표와 게이트 목록에 있다.
2. **잔여 지적 반영** — `reviews/verify-r4-r5.json`의 `rounds[1].findings`(high 1 · medium 4 · low 6). 분리로 자동 해소되는 것은 그렇게 기록한다.
3. **하네스·변이 재구성** — adopt의 lint에 "클러스터를 바꾸는 동사 0개"를 AST로 못박고, 모의 kubectl은 변경 동사가 오면 즉시 실패. adopt 모든 시나리오의 공통 사후 조건 = 변경 로그가 비어 있음. drill 시나리오 신설. 기존 잠금·규약 변이는 살려서 전부 CAUGHT.
4. **적대적 재검증** — adopt 쓰기 0건을 AST와 모의 양쪽으로 증명하고, 분리로 **잃은** 안전장치가 있는지 옛 구조와 하나씩 대조한다.
5. **gitops PR #29 브랜치에 README 갱신 커밋** — `platform/secrets/README.md` §2 · `platform/cloudflared/README.md` ⑨ · `secrets/README.md`가 `g4-adopt.ps1`/`g4-restore.ps1`을 이름으로 가리킨다 → `g4-drill.ps1`을 추가한다.
6. **G4 실행(사용자 입회)** → 머지 → 판정 → 드릴 → 런북 §3 T045 절에 실행 기록.
7. **G5 마무리** → T045 체크(51/119).

## 반드시 지킬 제약

- **시크릿은 저장소에도 대화에도 절대 들어가지 않는다.** 값은 해시로만 다룬다.
- **에이전트는 운영자 개인 자격을 쓰지 않는다.** 조회는 `C:\Users\2401\.kube\agent-view.yaml`(8시간 토큰)만 쓰고, `~/.kube/joshuatech-admin.yaml`은 읽지 않는다. `tofu plan`·`apply`·`kubectl` 쓰기·SSH·Vault 로그인·`gh pr merge`는 **전부 운영자(사용자)가 실행**한다. 예외는 `tests/infra/tofu.tests.ps1`의 읽기 전용 plan 하나뿐이다(`.claude/rules/infra.md`에 문서화됨).
- **파괴적·라이브 변경 작업은 단계마다 사용자 재확인**을 받는다. G4 머지와 드릴은 **사용자 입회**가 조건이다.
- `spec.md` · `plan.md` · `tasks.md`는 **동결**이다(tasks.md 체크박스와 converge 추가 phase만 예외). `contracts/`는 편집 가능하되 **gitops 변경보다 앞선 별도 모노레포 커밋**으로 한다.
- 커밋은 Conventional Commits, 한국어 설명 허용, **파일 이름으로 스테이징**한다(`git add -A` 금지). 강제 푸시 금지. 하위 에이전트를 쓴다면 **에이전트가 커밋하지 않는다** — 컨트롤러가 한다.
- 문서·명세·보고서·주석은 한국어, 식별자·슬러그·파일명은 영문 ASCII.
- **학습 로그**: task가 닫힐 때(그리고 여러 날 걸리는 task는 세션마다) `content/tmp/003-t045/<YYYY-MM-DD>.md`에 그날 항목을 덧붙인다(`.claude/rules/content.md`의 절 순서). 공개 저장소이므로 비밀·IP·내부 호스트명·리소스 ID·이메일을 넣지 않는다. 09-17·09-18 항목은 이미 있다.

## 런타임 함정(실측으로 확인된 것)

- 노드 안에서 `kubectl`은 항상 `sudo`. 원격 명령은 리터럴 here-string으로 넘긴다.
- PowerShell에서 `-flag=value`는 인용해야 하고, `-o` 값에 쉼표가 있으면 **값 전체를 작은따옴표 한 쌍**으로 감싼다. `"$k:"`는 파스 오류이므로 `${k}:`로 쓴다.
- 문자열 비교는 `[string]::Equals($a,$b,[StringComparison]::Ordinal)`. `-eq`/`-ceq`는 문화권 비교라 BOM 같은 문자를 무시한다.
- Argo 리비전이 고착되면 `kubectl -n argocd annotate app <app> argocd.argoproj.io/refresh=normal --overwrite`. Synced/Healthy만 보지 말고 `.status.sync.revision`을 함께 본다.
- `tests/run-all.ps1`은 `TF_VAR_budget_alert_email` 환경 변수가 없으면 tofu 슬롯이 실패한다.
- gitops `tests/validate.sh`는 Windows에서 6분 안팎, `tests/validate.tests.sh`는 10~50분 걸린다. 백그라운드로 돌려라.
- gitops CI `validate` 워크플로는 **골격이라 `validate.sh`를 부르지 않는다**(T047까지). 강제 수단은 PR 전 로컬 실행과 리뷰다.
- 도구(kustomize 5.8.1 · kubeconform · yq · gitleaks)는 Claude 세션 스크래치패드에만 있었다. Codex는 자기 경로에 다시 준비해야 한다.

## 오늘 세션에서 이미 끝낸 것(다시 하지 말 것)

모노레포 `eb3a52a`→`2cb0a9d`: 런북 §3 T045 절(G2·G2r·OP1·DR1·G3 기록) · 계약 `gitops-repo.md` §validate.yml에 배달자 변환 키 금지 · 하네스 `eso-1` 강화 + `eso-4` 신설 · 설계 문서 정정(env 재판독) · 학습 로그 2일차 · 블록 산출물 보존.
gitops `f2a6cff`(PR #29): 터널 ES + 문서 11항 + validate 7.3 변환 키 금지 + 부정 픽스처 2.

---

## 사용자에게 (이 세션에서 알아두실 것)

- 진행 중이던 백그라운드 작업은 전부 정리했습니다. 남은 것 없습니다.
- 블록·검증 산출물은 전부 저장소에 커밋했습니다(`2cb0a9d`). 세션이 끝나도 사라지지 않습니다.
- **gitops PR #29는 머지하지 마세요.** 운영자 블록이 준비된 뒤입니다.
- OCI `svc-verify` 세션과 agent-view 토큰은 만료됐을 수 있습니다. Codex가 조회를 시작하기 전에 재발급이 필요합니다.
