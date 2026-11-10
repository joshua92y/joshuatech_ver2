# T044 최종 설계 — Vault(시크릿 원천) 배포 · ocikms auto-unseal · `infra/vault` · 런북

작성 2026-09-14 · 기반안 **설계안 2(최소 단계·최소 산출물)** + 설계안 1에서 접목 4건(계약 선행 커밋 · bound SA/ns 전수 매핑 단언 · seal 3값 커밋 단계에 사용자 재확인 · VD 목록 확장)
비평 반영: blocker 4건(전사 검증 3단 분리 · vault-admin SA 부재 · **7번째 role = 동결 위반** · **T044 내 root revoke = ADR 순서 위반**) 전부 반영, major 6건 반영(토큰 리터럴 제거 · SUC 창 순서 · metadata `read`만 · 단언 정확 일치 · vt-10 보강 · OCID 공개 사용자 확인), minor 8건 반영, nit 2건 반영. **미해결 1건**: root revoke 이후의 관리 경로(Vault 2.0 `generate-root` 토큰 요구) — T044 범위 밖, §2 D4 + §9 converge 인계로 명시.
저장소 변경 없음(설계 문서만). 사실은 사실 수집 6렌즈에서 verified/likely로 확인된 것만 쓰고 likely·unverified는 §7 VD 번호를 단다. 비밀 값·OCID 실값은 자리표시자로만 쓴다.

---

## 1. 결론 요약

### 1.1 T044의 실제 모양

T044는 "되돌릴 수 없는 것"이 셋 있는 태스크다 — ① `vault operator init`의 출력(recovery key 3 + root 토큰: 분실 시 Vault 2.0에서는 복구 경로 없음), ② StatefulSet `volumeClaimTemplates`(PVC 삭제 보호 어노테이션은 첫 apply에만 넣을 수 있다), ③ public gitops 저장소 커밋 히스토리에 들어가는 KMS key OCID·엔드포인트(자격이 아니라 식별자지만 되돌릴 수 없다). 그리고 "시계가 도는 것"이 둘 있다 — G1 머지 순간부터 (a) init 전까지 `cluster.tests` argo-1(Application 20/20 Healthy)이 FAIL이고, (b) `svc vault`가 생겨 `platform-backup.sh --pre-upgrade`가 vault 스냅샷 성공을 **필수**로 승격하므로 role `vault-backup`이 생기기 전에 SUC 창(일요일 03:00–05:00 KST, 다음 창 **2026-09-20**)이 열리면 prepare가 실패하고 그 실패는 창 밖에서도 재트리거된다. 따라서 설계의 핵심은 값 하나하나보다 **순서**다: 모노레포 `infra/vault`를 머지 전에 완성해 두고, G1 머지 → init → audit → 재기동 리허설 → tofu apply → 플레이스홀더 → 백업 연결을 **한 운영자 세션**에서 연속으로 끝낸다.

### 1.2 채택한 설계안과 이유

**설계안 2(최소 단계)를 기반으로 채택**한다. 이유 세 가지:

1. **SUC 창 길이.** 설계안 1은 G1 머지(단계 6) 뒤에 builder의 `infra/vault` 저작(단계 11)과 컨트롤러 리뷰(단계 12)를 끼워 넣어 `svc vault` 존재 ~ role `vault-backup` 생성 사이가 개방형으로 늘어난다(비평 1 major). 설계안 2는 M1을 머지 전에 커밋·`run-all` 통과까지 끝낸다.
2. **정책 본문의 계약 일치.** 설계안 2의 eso-* 정책은 tasks.md:123·gitops-repo.md:98-101이 요구하는 `read`와 그대로 맞고, 설계안 1은 metadata에 `list`를 더해 최소권한을 넓혔다(비평 2 major). heredoc 인라인은 tofu.tests.ps1:24의 heredoc 금지가 **infra/oci 한정**이라 규약 위반이 아니며, 공용 `New-TfValidateCopy`(oci·cloudflare 공유)를 건드리지 않는다.
3. **설계안 1의 break-glass 경로는 실재하지 않았다.** role `vault-admin`을 만들면서 SA 매니페스트가 없고 스모크 게이트도 없었다(비평 1·2 공통 major). 다만 이 문제는 **두 설계안 모두가 안고 있던 blocker**로 흡수된다 — 7번째 role은 동결된 tasks.md:123("auth role 합계 6")·ADR 0010:33("role 6개")·spec FR-041(break-glass = generate-root)을 동시에 바꾸는 결정 변경이라 T044 설계가 단독으로 내릴 수 없다(비평 2 blocker). 같은 이유로 설계안 2의 "T044 안에서 root revoke"(단계 12)도 tasks 문면("root 토큰과 함께 오프라인 보관")·ADR §6(revoke = 시드 완료 후 = T045)과 어긋나 **삭제**한다.

결과: **auth role 6 · 정책 6 · root 토큰은 revoke하지 않고 오프라인 보관 · break-glass 공백은 D4로 사용자·converge에 올린다.** 설계안 1에서 접목한 것: ① 계약 한 줄(e2e-reader 토큰 발급 절차)을 모노레포 단독 커밋으로 먼저, ② `vault-tf-9`(6개 role의 SA/ns 전수 매핑) 단언, ③ seal 3값 커밋 단계를 `user+operator`로, ④ DNS 공인 IP·스왑·렌더 전수 VD.

두 설계안이 공유한 최대 결함(비평 1 blocker)은 init 출력 전사였다 — 이 저장소에는 `Set-Clipboard`로 꺼낸 비밀이 비밀번호 관리자에 저장되지 않아 argocd admin 비밀번호를 잃은 기록(bootstrap.md:182 ⑥)이 있다. §5 단계 9는 전사 → **해시 대조 + PM 사본 root 토큰으로 `vault token lookup` 성공** → 소거의 3단으로 분리한다.

### 1.3 순서(요약)

```
0  사용자 결정(D4·D7·D8·D9) + 사전 확인 7종     user+operator   CLI 2.0.4 · 클립보드 기록 OFF · DNS 공인 IP · 스왑 0 · SC · env 파일 · SUC 창 여유
1  M0 계약 커밋(hostnames :79 한 줄)             controller      gitops보다 먼저
2  G1 파일 작성(자리표시자)                       builder         kustomization · ingress · SA vault-backup · README · AppProject 1줄
3  G1 커밋 2개 + draft PR + gitleaks              controller
4  seal 3값 채움 + 렌더 검증                      user+operator   ★ public 저장소 게재(D7) · 렌더 10장 · image 1줄
5  M1 작성(infra/vault + tofu.tests)              builder         커밋 금지
6  M1 커밋 + run-all                              controller      validate-vault-1/2 무자격 PASS
── 여기까지 라이브 변경 0 ──
7  G1 머지 → vault-0 Running 0/1                  user+operator   ⏱ argo-1 적색 창 · SUC pre-upgrade 게이트 시작
8  port-forward · seal-status 사전 점검           operator        200 · type=ocikms · init -status exit 2
9  ⭐ vault operator init(사용자 입회) 3단 전사    user+operator   해시 3/3 · PM 사본 토큰 lookup 성공 → 소거
10 vault audit enable file(stdout)                operator        감사 JSON ≥1행
11 auto-unseal 재기동 리허설                      operator        90~180초 내 sealed=false
12 tofu init/plan/apply + 인증 스모크             operator        15 add/0/0 · vault-backup 로그인 · capabilities
13 kv 플레이스홀더 8경로                          operator        PLACEHOLDER-T044-
14 백업 연결(env 삭제 · 수동 1회 · pre-upgrade)   operator        exit 0 · 버킷 .age 1건   ⏱ SUC 게이트 해소
15 라이브 하네스 재측정                            controller      vault-1/2 · argo-1 · np-4 · ingress vault-2 · backup-2/3
16 Ingress·UI 도달                                operator        내부 200/307 · edge 302 · 로그인 화면 렌더
17 세션 정리 + root 토큰 오프라인 보관 확인        user+operator   env 제거 · ~/.vault-token False · tfplan 삭제 (revoke 안 함)
18 M2 문서(vault-unseal.md · bootstrap §4 · README) builder
19 커밋 + tasks 체크박스 + 인계                    controller      편차·정정 목록
```

### 1.4 결정 목록

| ID | 질문 | 권고 | 사용자 확인 |
|---|---|---|---|
| **D1** | Ingress 형태·백엔드 | 순수 매니페스트 `platform/vault/ingress.yaml` · Service `vault` · 포트 **이름 `http`** | 필요(권고 확정형) |
| **D2** | PVC 삭제 보호 어노테이션 위치 | `server.dataStorage.annotations`에만 + `auditStorage.enabled: false` · `kubeVersion`/`persistentVolumeClaimRetentionPolicy`는 넣지 않음 | 필요(권고 확정형) |
| **D3** | init 실행 경로·출력 취급 | 워크스테이션 CLI 2.0.4 + port-forward · 파일 금지 · **3단 전사(전사→검증→소거)** | 필요(입회 절차 확정) |
| **D4** | root 토큰 취급과 revoke 이후 관리 경로 | **T044: role 6 유지 · root 오프라인 보관(revoke 안 함)** · Vault 2.0 `generate-root` 토큰 요구 → ADR 0010 §6·FR-041 정정 후보를 converge로 · break-glass 대체(7번째 role 등)는 **T045 revoke 전에 결정** | **필요 — 미해결 항목** |
| **D5** | 감사 장치 소유 | CLI 1회 `vault audit enable file file_path=stdout`, tofu `vault_audit` 없음 | 필요(권고 확정형) |
| **D6** | 이미지 digest 병기 | `server.image.tag: "2.0.4@sha256:<인덱스 digest>"` · 실패 시 태그만으로 폴백(VD-12) | 필요(권고 확정형) |
| **D7** | PR/커밋 분할 + **KMS key OCID·엔드포인트의 public 저장소 게재** | G1 단일 PR(커밋 2: platform/vault 4장 · AppProject 1줄) · Ingress 포함 · seal 3값 커밋은 `user+operator` | **필요**(공개 게재는 되돌릴 수 없음) |
| **D8** | US6 kv 플레이스홀더 투입 범위 | T044 포함, 8경로, 리터럴 한 형태, `web-bff`·`access` 제외 | **필요**(범위) |
| **D9** | 문면 밖 values·research 편차 | XFF 3줄 **미도입**(research D3 편차) · 보강 5종(PDB off · includeConfigAnnotation · `disable_hostname` · networkPolicy false 명시 · active/standby off) · `ui.enabled: false`(research D2 편차) | **필요**(편차 기록 + converge) |

**사용자 결정 불요(설계 확정)**: 정책 본문 = `policies.tf` heredoc 인라인(공용 하네스 함수 무변경) · eso-* metadata `read`만 · pod 재기동 auto-unseal 리허설을 T044에 포함 · `tests/platform/run-platform-tests.ps1` 게이트 배열 **무변경**(infra/oci가 이미 존재해 tofu.tests가 돈다) · `infra/vault`에 plan 단언 없음 · 되돌리기 삭제 순서 = Ingress → STS(orphan) → Pod → 나머지, **PVC/PV 제외** · VaultSealed `absent()`는 FR-040 MetricsAbsent가 이미 덮음(인계 문구만 정정).

### 1.5 최대 차단 위험

**init 출력을 잃으면 복구 경로가 없다.** Vault 2.0부터 `sys/generate-root`·`sys/rekey`는 recovery key 조각 **과 유효한 토큰**을 함께 요구하므로, recovery key 하나라도 클립보드 실패로 사라지고 root 토큰까지 잘못 전사되면 argocd처럼 bcrypt 재설정으로 되살릴 수 없다 — PVC 삭제 후 재init(모든 시드 재투입)이 유일한 길이다. 이 저장소는 같은 절차(`Set-Clipboard` → 삭제)로 argocd admin 비밀번호를 이미 한 번 잃었다(bootstrap.md:182 ⑥). §5 단계 9의 3단 분리 게이트(해시 3/3 일치 + PM 사본 토큰 `vault token lookup` 성공)가 유일한 방어이며, 이 게이트를 통과하기 전에는 `Remove-Variable init`도 창 종료도 하지 않는다.

두 번째 위험은 **seal 설정 실패 = 프로세스 즉사**다(sealed 대기가 아니다). 값 오타·IMDS·DNS·IAM 어느 것이든 `error parsing Seal configuration: failed key_id validation`으로 `vault server`가 종료해 CrashLoopBackOff가 되고, seal-status는 `sealed:true`가 아니라 연결 거부다. ADR 0010·tasks 문면의 "KMS 일시 장애 = sealed 대기"와 "삭제 유예 30일"은 둘 다 정확하지 않으며(§6·§9 정정 항목), 런북은 실제 동작대로 쓴다.

---

## 2. 사용자 결정 목록

각 결정은 독립적으로 물을 수 있다. 권고안을 받아들이면 §5 순서가 그대로 성립한다.

### D1 — Ingress 형태·백엔드 Service·포트 표기

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** 순수 매니페스트 `platform/vault/ingress.yaml` + Service `vault` + 포트 **이름 `http`** | `bootstrap/argocd/ingress.yaml` 선례와 형태 동일(networking.k8s.io/v1 · ingressClassName traefik · websecure + router.tls · spec.tls 없음 · options 미기재 → TLSOption default 상속) · `vault`는 `publishNotReadyAddresses: true`라 **봉인·미초기화 중에도 UI 도달** · 포트 이름이면 `tlsDisable` 전환 시 이름이 `https`로 바뀌어 눈에 보이게 깨진다(Traefik은 https* 이름을 백엔드 TLS로 취급 → 정답으로 전환) · 근거 주석 가능 | 파일 1장 추가 | 낮음. `/` Prefix라 Access 통과 세션에 `/v1/*` 전체가 열린다 → US4 전까지 Access + AOP가 유일 방어선(런북 §0 명시) |
| B 차트 `server.ingress.enabled: true` | values 한 곳 | ha 모드 기본 `activeService: true` → 백엔드 `vault-active`(selector `vault-active: "true"`는 unseal 뒤에 붙음) → **init 전·봉인 중 엔드포인트 0 = 503** · 포트가 번호로 렌더돼 선례와 갈림 | 중 — `activeService: false` 한 줄 누락이 장애 시점의 관측 수단을 없앤다 |
| C A + 포트 번호 8200 | validate 5.4b의 8200과 표기 일치 | `tlsDisable` 전환 시 평문 요청이 TLS 리스너로 가는 조용한 502 | 낮~중 |

**권고: A.** `ingress.tests` vault-2는 host 일치만 보므로 형태는 설계 자유이며, 판정 기준은 장애 시점의 관측 가능성이다. 차트 쪽 `server.ingress.enabled: false`를 명시한다.

### D2 — PVC 삭제 보호 어노테이션 위치

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** `server.dataStorage.annotations`에만 + `auditStorage.enabled: false` 유지 | 차트가 `volumeClaimTemplates[0].metadata.annotations`로 렌더 → STS 컨트롤러가 DeepCopy → `data-vault-0`에 전파 = cluster.tests argo-4(:492-494, ns vault의 **모든** PVC, 0개도 FAIL)를 만족하는 유일한 경로 · 키 1개 | 어노테이션은 Argo 관리 밖 PVC의 '표식'일 뿐 실제 보호가 아님 → 오해 방지 문구 필요 | **첫 apply 필수**(volumeClaimTemplates 불변 — 이후 sync 거부 → STS `--cascade=orphan` 재생성 또는 수동 annotate로 정본-라이브 괴리) |
| B STS 자체에도 patches로 추가 | 의도가 눈에 띔 | 계약(§삭제 보호 = Vault/Dragonfly **PVC** · 오퍼레이터 CRD)·테스트 어디에도 요구 없음 · `prune: false`와 중복 | 낮지만 불필요 |
| C A + `helmCharts[].kubeVersion: "1.36.4"` + `persistentVolumeClaimRetentionPolicy: Retain/Retain` 명시(설계안 1) | 기본값을 코드에 고정 | 동작 불변(K8s 기본이 이미 Retain/Retain) · kubeVersion은 차트 전체의 `.Capabilities.KubeVersion` 게이트를 한꺼번에 여는 플래그라 렌더 표면만 넓힘 · 문면에 없는 항목 2개 추가 | 낮음(비평 2 minor) |

**권고: A.** PVC 보존은 런북 §11에 "PVC 삭제 = local-path PV 데이터 소멸(reclaimPolicy Delete — VD-04), 복구는 raft 스냅샷뿐"으로 문서화한다. `auditStorage`를 켜면 어노테이션 없는 `audit-vault-0`이 생겨 argo-4가 FAIL한다(감사는 stdout).

### D3 — `vault operator init` 실행 경로와 출력 취급

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** 운영자 워크스테이션 `vault` CLI 2.0.4 + admin kubeconfig `port-forward svc/vault 18200:8200`, 출력은 파일 없이 변수 → 비밀번호 관리자, **3단(전사→검증→소거)** | 계약 :59(port-forward, exec 불필요)·ADR 0010('전부 워크스테이션 CLI')과 일치 · 컨테이너 exec 불필요(이미지에 openssl·ps 없음) · `vault login` 금지로 `~/.vault-token` 잔존 0 증명 가능 · 검증 단계가 argocd 사고(bootstrap.md:182 ⑥)의 교훈을 그대로 이행 | CLI 설치 선행(VD-01) · PowerShell `-flag=value` 인자 함정 → 따옴표 · 클립보드 기록 ON이면 화면 직접 전사로 전환 | 잔여 = PSReadLine 히스토리·Transcript·클립보드 기록·SSH 스크롤백·대화 로그 5곳 → **모든 새 창 첫 줄** 체크리스트로 닫는다 |
| B 노드 A의 vault CLI(v2.1.0, host-prep 설치) | 설치 불필요 | 출력이 cloudflared SSH 스크롤백·`sudo` 컨텍스트를 지남 · 노드 A는 KMS 인스턴스 프린시펄 보유 호스트 · CLI 2.1.0 ↔ 서버 2.0.4 스큐 | 중 |
| C 브라우저 UI 초기화 화면 | 클릭 | recovery key·root 토큰이 화면·**다운로드 파일**로 남음 — 표준 제약 정면 위반 | **금지**(README §0·런북 §0 첫 줄에 굵게) |

**권고: A.** 전문은 §5 단계 9. 멱등 체크 `vault operator init "-status"`(0=이미 init, 2=미init)가 인자 전달 확인을 겸한다. `-recovery-shares/-threshold`는 auto-unseal에서만 유효하므로 인자가 먹혔다는 사실이 seal=ocikms의 간접 증거다.

### D4 — root 토큰 취급과 revoke 이후의 관리 경로 (**미해결 — 사용자 결정 + converge**)

사실: Vault 2.0부터 `sys/generate-root`·`sys/rekey`는 recovery key 조각 **과 유효한 Vault 토큰**을 함께 요구한다(공식 important-changes; research VAULT-D5에도 기록됨). 따라서 ADR 0010 §6 "OIDC 전 Vault 변경이 필요하면 recovery key generate-root(break-glass)뿐"과 spec FR-041의 break-glass 정의는 2.0에서 성립하지 않는다 — root를 revoke하고 OIDC(US4)가 없으면 관리·복원 경로가 0이다(스냅샷 복원도 `sys/storage/raft/snapshot` update 권한 필요).

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** T044: role 6 그대로 · root 토큰 **revoke하지 않고** recovery key와 오프라인 보관(tasks 문면 그대로) · revoke는 ADR §6대로 T045 시드 완료 뒤 · **그 전에** break-glass 대체를 converge에서 결정 | 동결 문면(tasks:123 "합계 6" · ADR:33 · FR-041) 무위반 · T045 시드가 막히지 않음 · 새 권한 객체 0 | revoke 이후 경로 문제가 T044에서 해결되지 않음(미해결로 명시) · root 토큰이 T045까지 상시 유효(토큰 표 ⑥과 긴장) | 중 — converge가 T045 전에 결론을 못 내면 T045에서 revoke를 또 미루거나 관리 공백을 감수해야 한다 |
| B T044에서 7번째 role `vault-admin`(SA `vault/vault-admin`, RBAC 0, 정책 = 관리 경로) 추가 + 로그인·`tofu plan` 0 변경 게이트 뒤 T044 내 revoke(설계안 2 + 비평 1 권고) | 상시 토큰 0 원칙을 지키며 관리 경로 실증 | tasks:123 "합계 6"·ADR:33 "role 6개"·FR-041 break-glass 정의 **3곳 동시 위반** = 설계가 단독으로 못 내리는 결정 변경(비평 2 blocker) · 계약 gitops-repo.md 표 행 추가 선행 · T044 내 revoke는 tasks 문면("오프라인 보관")·ADR ⑤→⑥ 순서와 충돌 | 낮음(기술) / 높음(절차) |
| C HCL `enable_unauthenticated_access = ["generate-root"]` | 고전 break-glass 복원 · role 수 불변 | in-cluster 8200 도달자가 generate-root 시도를 남발하는 DoS 표면 · 보안 후퇴를 HCL에 영구 새김 | 중~높 |
| D root 토큰을 US4 OIDC 확인까지 보관 | 단순 | 상시 전권 토큰 장기 존재 · ADR ⑥ 위반 | 중 |

**권고: A.** T044 산출물은 role 6·정책 6이며 root는 보관만 한다. 런북 §4·§5에는 "revoke 전제 = 대체 관리 경로가 결정·실증된 뒤"와 "2.0에서는 recovery key만으로 break-glass가 성립하지 않는다"를 사실로 기록한다. B가 기술적으로 가장 깔끔하지만 converge(ADR 0010 §6·FR-041·tasks 정정)가 먼저다 — **T045의 root revoke 전에 결론이 필요**하다는 것을 §9에 인계한다.

### D5 — 감사 장치 소유

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** CLI 1회 `vault audit enable file file_path=stdout`, tofu 미소유 | task 문면 그대로 · `sys/audit`의 list/enable/disable 전부 sudo → tofu 소유 시 매 plan refresh가 sudo 요구 · init → audit → tofu 순서라 tofu write 15건이 전부 감사에 남음 | 드리프트 감지 없음 | 낮음 — agent-view `pods/log`로 감사 JSON 존재 확인 가능(VD-15) |
| B CLI 후 `tofu import vault_audit.file file/` | 드리프트 감지 | 이후 모든 plan에 sudo 필요 → 정례 토큰 권한 바닥 상승 | 중 |
| C tofu가 생성 | 선언형 | B 단점 + 부트스트랩 write가 감사에 안 남음 | 중 |

**권고: A.** stdout 단일 장치는 fail-closed다 — 쓰기가 막히면 Vault가 모든 API 요청을 거부한다(노드 A 디스크 포화 = Vault 전면 정지). 두 번째 장치를 임시 FS에 두는 '보험'은 감사 유실 경로라 채택하지 않고, `NodeDiskLow`(FR-040)를 조기 경보로 런북 §9에 명시한다. `vault_auth_backend`(`sys/auth`, 역시 sudo)는 tofu가 소유한다 — 정례 plan은 운영자 절차(root 또는 D4 결정 후 경로)로 런북에 남기고 하네스에는 넣지 않는다.

### D6 — 이미지 digest 병기

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** `server.image.tag: "2.0.4@sha256:5be49781ecf78bfe775c5309c6a4d9f4e9e040b6c885c99eb2b12fb69855e1a2"` | 차트에 `image.digest` 키 없음·STS가 `{repo}:{tag}` 한 줄만 렌더 → 유일한 병기 방법 · 렌더 `hashicorp/vault:2.0.4@sha256:…`는 유효 OCI 참조 · 인덱스(매니페스트 리스트) digest라 arm64 2대 안전(2026-09-14 실측) · 스키마가 tag를 string으로만 제약 | 태그 필드 오염 · bump마다 수동 갱신(validate 4b는 블록 표기라 매칭 자체 안 함 — 자동 검사 없음) | containerd 수용 여부 **미검증** → VD-12, 실패 시 `"2.0.4"`로 즉시 폴백 |
| B kustomize `images:` | — | digest 지정 시 태그를 지운 `hashicorp/vault@sha256:…`로 치환(병기 위반) · `newTag`는 validate 4a 금지 | 기각 |
| C 태그만 + README digest 기록 | 단순 | 계약 §이미지 위반(acmesolver 예외는 파드 미생성 근거였음) | 중 |

**권고: A.** 차트 자체 digest(index.yaml tgz sha256 `df4c37fa…64c4`)는 kustomization 주석에 대조 기록으로 남긴다.

### D7 — PR/커밋 분할·순서 + KMS 식별자의 public 저장소 게재

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** G1 단일 PR(커밋 ① platform/vault 4장, ② AppProject `sourceRepos` hashicorp 줄 삭제, ③ seal 3값 투입 — `user+operator`) · Ingress 포함 · M1 모노레포 커밋은 **머지 전** | PR 1·되돌리기 단위 1 · vault-2 테스트가 같은 PR에서 초록 · AppProject 줄은 권한 축소 방향(`source.repoURL`만 검사하는 필드, T042 PR-5 선례)이라 커밋 분리로 리뷰 경계 유지 · SUC 창 최소 | AppProject 변경이 컴포넌트 PR에 섞임(커밋으로만 구분) · init 전 UI 창 존재(문서 + 경과 시간 기록으로 방어) | G1 머지 = 즉시 자동 sync = argo-1 적색 창 + SUC 게이트 시작 → **init 준비된 시각에만 머지** |
| B G0(AppProject) + G1 + G2(Ingress 후속) | 리뷰 경계 최선 | PR 3 · vault-2 FAIL 1 PR 더 · 창 1개 추가 | 낮음 |

**함께 확인할 것(되돌릴 수 없음)**: seal 스탠자의 `key_id`(`ocid1.key.oc1.ap-chuncheon-1.…`)·crypto/management 엔드포인트가 **PUBLIC** `platform-gitops`에 리터럴로 들어간다(현재 `ocid1.`·`oraclecloud.com` 0건 — 최초 사례). 자격증명이 아니라 식별자다: OCI 호출은 인스턴스 프린시펄 x509 서명으로만 인가되고 권한은 `target.key.id` 조건 IAM 정책이 정하며, env 우회는 Vault가 `WithDisallowEnvVars(true)`를 넘겨 구조적으로 불가하다. 대안(HCL 전체를 Secret 볼륨으로)은 GitOps 추적성·selfHeal·Argo 헬스를 모두 해쳐 비권장. 부결 시 T044를 중단하고 다시 결정한다.

**권고: A + 게재 허용.** README §0에 근거를 남기고, 커밋 전 게이트 `grep -rn 'ocid1\.' D:/code/platform-gitops`가 `platform/vault/kustomization.yaml` 안에서만 히트(테넌시·컴파트먼트·사용자 OCID 0건)를 확인한다(VD-09 gitleaks와 별개).

### D8 — US6 kv 플레이스홀더를 T044에 넣는가

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** T044 포함 — tofu apply 직후 같은 세션, **8경로**, 리터럴 한 형태 | 쓰기 토큰이 살아 있는 창에서 한 번에(별도 창 0) · US6 전 경로 오타 조기 발견 · 런북 §4 이월 문면 이행 | 경로 목록을 지금 고정 | 낮음. 값 `PLACEHOLDER-T044-<path>-20260914`로 가짜임이 한눈에 |
| B T075/T081로 미룸 | 단계 1개 감소 | 그때는 root 상태가 다름(D4) · US6 착수 시 오타 발견 | 중 |

**권고: A.** 경로 8개(data-model §8 기준, ESO 소비분만): `kv/{dev,prod}/authentik/identity-admin`(client_id·client_secret·jwks_url·issuer·api_token) · `kv/{dev,prod}/authentik/webhooks/identity-admin`(secret) · `kv/{dev,prod}/openfga/store_id`(store_id) · `kv/{dev,prod}/openfga/preshared`(key). `kv/{env}/authentik/web-bff`·`kv/{env}/access/web-bff`는 Workers 전용(ESO 밖)이라 제외. 불변식 한 줄을 §4 기록에 넣는다: **`kv/{env}/openfga/preshared`는 US6에서 `kv/platform/openfga/preshared`와 같은 값으로 교체, 회전은 둘을 함께**(data-model §8).

### D9 — 문면 밖 values·research 편차

| 항목 | 넣는다(권고) | 근거 | 편차 성격 |
|---|---|---|---|
| `x_forwarded_for_*` 3줄 | **넣지 않음** | authorized_addrs가 비면 XFF 래퍼 자체가 설치되지 않음. 설치되면 remote 주소를 보기 전 헤더 부재를 검사(http/handler.go :728-736) → readinessProbe(127.0.0.1)·port-forward seal-status(vault-1/2·reboot-1)·platform-backup·ESO·metrics가 동시 400 위험. 실제 클라이언트 IP는 Access 로그·Traefik 액세스 로그(CF-Connecting-IP)에 남음 | research VAULT-D3 편차 |
| `ha.disruptionBudget.enabled: false` | 넣음 | replicas=1이면 헬퍼가 `maxUnavailable: 0` 고정(override 불가) → 향후 `kubectl drain` 영구 대기. SUC는 cordon만 | 문면 외 보강 |
| `includeConfigAnnotation: true` | 넣음 | OnDelete(차트 기본 유지)에서 뒤처진 파드 식별 | 문면 외 보강 |
| telemetry `disable_hostname = true` | 넣음 | 없으면 게이지에 호스트명 접두 → `VaultSealed`(`vault_core_unsealed == 0`) 불성립 | 문면 보완(알림 성립 조건) |
| `networkPolicy.enabled: false` 명시 | 넣음 | 켜지면 `namespaceSelector: {}` → np-4 즉사, validate 5.0은 helm 렌더 결과를 안 봄 | 기본값 명시 |
| `service.active/standby.enabled: false` | 넣음 | 1 replica에 무의미 · 봉인 중 엔드포인트 0 | 문면 외 보강 |
| `ui.enabled: false` | 넣음 | 이 키는 Service `vault-ui`만 추가 — UI는 HCL `ui = true`로 8200 `/ui` 서빙, Ingress·테스트는 `svc/vault` | research VAULT-D2 편차 |

**권고: 전부 채택.** vault-helm `values.schema.json`에는 `additionalProperties: false`가 0곳이라 기본값에 기대는 항목이 많을수록 리뷰가 검증 못 하는 가정이 늘어난다. 편차 3건(XFF·ui·보강)은 report '문면 편차' + converge 인계.

### 2.10 사용자 확정 기록 (2026-09-14)

| 결정 | 확정 | 설계 대비 변경 |
|---|---|---|
| D1 | A — 순수 매니페스트 `platform/vault/ingress.yaml` · Service `vault` · 포트 이름 `http` · 차트 `server.ingress.enabled: false` | 없음 |
| D2 | A — `server.dataStorage.annotations`만 · `auditStorage.enabled: false` | 없음 |
| D3 | A — 워크스테이션 CLI + port-forward + 3단 전사 · **CLI 버전은 문서에 고정하지 않는다**: 단계 0에서 실제 설치본(winget 최신)을 확인해 기록. 서버 2.0.4보다 CLI가 최신이어도 HTTP 클라이언트라 호환 | VD-01 판정 = "`vault version`이 2.x이면 진행, 실제 값 기록" |
| D4 | A(T044) + 후속 매핑 확정: T044 role 6 · root 오프라인 보관(revoke 없음) · T045는 root로 시드하되 revoke 안 함 · **T084** = Vault OIDC auth role `admin`(동결 문면 이름) + 실제 관리 작업 실증 · **converge 추가 task** = 7번째 K8s auth role `vault-break-glass`(SA `vault/vault-break-glass`, K8s RBAC 0, 정책 `sys/generate-root/*`·`sys/rekey/*` update만, 토큰은 admin kubeconfig `kubectl create token --audience vault`로만 — 저장 토큰 0, 비root 토큰은 max TTL 32일이라 오프라인 보관 불가) + quorum 드릴(`generate-root -init` → 2/3 조각 → 디코드 → `token lookup` → 드릴 root revoke; **초기 root revoke 전에**) → 초기 root revoke · **ADR 0011**로 ADR 0010 §6 "recovery key generate-root뿐" 문장 + ⑥ revoke 시점(시드 직후 → T084+드릴 뒤) supersede · T114 break-glass.md 문구 · 런북 토큰 표 ⑥ 정정 | §9 인계에 T084/converge/ADR 0011 항목 추가. 감수 위험: 초기 root의 오프라인 유효 창이 T084+드릴 뒤까지 길어짐 |
| D5 | A′ — audit는 privileged bootstrap/런북 소유(단계 10, root 토큰), tofu 미소유 · **T098 인계**: audit-health = `vault_audit_log_request_failure`·`vault_audit_log_response_failure` 카운터 + Loki 감사 스트림 존재(결측 = 장치 제거·드리프트); FR-040 알림 13개 동결이라 `VaultAuditFailure` 규칙 추가는 converge 항목 · 두 번째 독립 sink(후보 socket → Alloy)는 후속 hardening 인계 | §9 T098 항목 보강 |
| D6 | A — `server.image.tag: "2.0.4@sha256:5be49781…"` · VD-12 실패 시 `"2.0.4"` 폴백 | 없음 |
| D7 | **B** — PR 3개 **G0**(AppProject `sourceRepos` hashicorp 줄 삭제) → **G1**(`platform/vault/` kustomization+seal 3값+values · SA `vault-backup` · README, **Ingress 제외**) → **G2**(`ingress.yaml` + kustomization resources 1줄 + README §). 각 PR은 다음 단계 선행조건을 실제 sync/운영 검증으로 확인한 뒤 진행 · KMS key OCID·crypto/management 엔드포인트의 public 게재 **허용**(식별자, 자격증명 아님; 권한 = instance principal + IAM) · credential material 전용 secret-scan 게이트(gitleaks exit 0 + `grep -rn 'ocid1\.'` 히트가 kustomization 안 `ocid1.key.` 1건뿐 — tenancy·user·compartment 0)를 **PR마다** | §5 단계 2–4·7·16 재배열: 단계 2 = G0 파일(1줄) → G0 PR·머지·게이트(20 App Synced/Healthy 유지, 삭제 repo 참조 앱 0) → 단계 2′ = G1 파일(ingress 제외) → 단계 3–4 = G1 커밋·seal 값·렌더 **9장**(Ingress 없음) → 단계 5–6 M1 → 단계 7 G1 머지(init 입회 가능 시각) → 단계 8–15 → 단계 16 = **G2 PR 작성·머지·VD-21** → 17–19. 되돌리기 ① Ingress 삭제는 G2 이후에만 해당 |
| D8 | A′ — T044에서 US6 8경로 + key schema 선점 · 값은 **단일 sentinel `PLACEHOLDER-T044-SENTINEL`**(공통 리터럴, credential 아님) · 런북 §4 불변식 "sentinel 잔존 0 = consumer 활성화 전제" · **게이트 1(운영자, 주입 뒤·활성화 전)** = 런북 스크립트 블록 `vault kv get -format=json` × 8 → `Select-String 'PLACEHOLDER-'` 0행이 PASS(토큰 = T084 뒤 OIDC admin, 그 전 root) — 실행은 T075·T081 · **게이트 2(consumer 자체, 무토큰)** = django-pod 템플릿 pydantic-settings 검증기: 값이 `PLACEHOLDER-`로 시작하면 기동 실패(fail-closed) + T077 tester 단언 `PLACEHOLDER-` 0 → T072·T075·T077 인계 · T044에 새 테스트 파일 없음 | 단계 13 값 형태 변경(경로별 → 단일 리터럴) · §9 T072/T075/T077 항목 추가 |
| D9 | 전부 채택(XFF 미도입 · PDB/active/standby/vault-ui/networkPolicy false 명시 · includeConfigAnnotation · disable_hostname) · 편차 3건 converge 인계 | 없음 |

---

## 3. 사실 근거

confidence: **V** verified · **L** likely(VD 연결) · **U** unverified(VD 연결).

### 3.1 vault-helm 0.34.1 차트 동작

| 사실 | conf | VD |
|---|---|---|
| 0.34.1 = appVersion 2.0.4, 기본 image `hashicorp/vault:2.0.4`, repo는 **HTTPS** `https://helm.releases.hashicorp.com`(index.yaml tgz sha256 `df4c37fa…64c4`) — `oci://` 접두 금지 | V | — |
| `image.digest` 키 없음, STS `image: {repo}:{tag}` 한 줄 → 태그에 digest 병기가 유일 | V/L | VD-12 |
| `injector.enabled` 기본 `"-"` = `global.enabled` 상속 = **활성** → 명시 false 필수(MutatingWebhookConfiguration 포함) | V | VD-13 |
| `ha.enabled` → mode ha, `server.ha.config` **비우면** ConfigMap·마운트 사라지고 볼륨만 남아 ContainerCreating — 건드리지 않음 | V | — |
| `vault.config` 헬퍼: `disable_mlock` 없으면 자동 append, `tpl` 렌더(HCL에 `{{ }}` 금지), 기본 raft config의 `service_registration "kubernetes" {}`는 통째 교체 시 직접 재기입 | V | — |
| 컨테이너 args가 `/tmp/storageconfig.hcl`에 씀 → `readOnlyRootFilesystem` 불가; env VAULT_API_ADDR/CLUSTER_ADDR 주입 → HCL에 api_addr 불필요 | V | — |
| securityContext 기본: pod = runAsNonRoot·runAsUser 100·runAsGroup 1000·fsGroup 1000, container = allowPrivilegeEscalation false **뿐**; 값 주면 **대체**(병합 아님); IPC_LOCK 없음(SKIP_SETCAP=true) | V | — |
| PSA restricted 통과에 `capabilities.drop [ALL]`·`seccompProfile RuntimeDefault` 명시 필수 | V | — |
| `dataStorage.annotations` → volumeClaimTemplates → STS DeepCopy → PVC 전파; volumeClaimTemplates 불변 | V/L | VD-04 |
| `auditStorage.enabled` 기본 false(두 번째 PVC 없음) | V | — |
| ha 렌더 Service 4종(vault·active·standby·internal), 포트 이름 = `vault.scheme`(tlsDisable → `http`) 8200 + `https-internal` 8201 | V | — |
| `releaseName: vault` 필수(fullname → Service/STS/SA/ConfigMap/PVC 이름) | V | — |
| 차트 Ingress는 ha+activeService 기본 → `vault-active` 백엔드·포트 번호 | V | — |
| replicas=1 → PDB `maxUnavailable: 0`(override보다 먼저 특수 처리) | V | — |
| `updateStrategyType` 기본 OnDelete → HCL 변경이 파드 재시작 안 함 | V | — |
| readinessProbe 기본 exec `vault status`(0/1/2) → init 전 NotReady → gitops-engine STS 헬스가 ReadyReplicas<Replicas를 OnDelete 분기보다 먼저 봄 → **Progressing**(Degraded 아님) → argo-1 FAIL 창 | V | — |
| `server.networkPolicy` 켜면 `namespaceSelector: {}` 8200·8201 → np-4 FAIL; validate 5.0은 원본 파일만 검사 | V | — |
| `values.schema.json`에 `additionalProperties: false` 0곳 → 키 오타 무검출 | V | VD-08 |
| helm 기본 `KubeVersion` v1.20 → `>= 1.23-0` 게이트 뒤 필드(PVC 보존 정책·ipFamilies)는 kubeVersion 없이 조용히 사라짐(D2에서 미채택) | V | — |
| 예상 렌더 10장(injector/csi/ui/PDB/active/standby/NetworkPolicy 0) | L | VD-08 |
| preStop 기본 `pidof vault` — 이미지 `pidof` 유무 미확인 | L | VD-17 |
| `dataStorage.storageClass` 비우면 기본 SC 의존 → `local-path` 명시 | L | VD-04 |

### 3.2 ocikms · 인스턴스 프린시펄 · OCI IAM

| 사실 | conf | VD |
|---|---|---|
| seal 필수 키 `key_id`·`crypto_endpoint`·`management_endpoint`; `auth_type_api_key` 기본 false = 인스턴스 프린시펄(`ParseBool`) | V | — |
| HCL seal 스탠자 사용 시 `VAULT_OCIKMS_*` env **전부 무시**(`WithDisallowEnvVars(true)`) → 값을 Secret/env로 빼는 우회 불가 | V | — |
| 래퍼 v2.0.9(OCI SDK v60), envelope 경로 → API = crypto `Encrypt/Decrypt` + management `GetKey` | V | — |
| IMDS v2 `169.254.169.254/opc/v2` **:80** → `auth.<region>.oraclecloud.com/v1/x509` **:443** → KMS :443 | V | — |
| ns vault 정책(allow-imds 80 · allow-egress-external-443 except RFC1918 · allow-dns)이 이 흐름에 정확히 맞음 — 단 엔드포인트가 사설 대역으로 해석되면 except에 걸림 | L | VD-05 |
| IAM `use keys` = 필요 API 정확·최소; `infra/oci/iam.tf:124-133` 이미 그 형태, T044에서 OCI 변경 0 | V | — |
| 동적 그룹 = 노드 A 인스턴스 OCID **1개** → `nodeSelector role=platform`은 가용성 필수 조건 | V | — |
| **seal 설정 실패 = 프로세스 즉사**(setSeal이 KeyNotFound 외 오류에 종료) → CrashLoopBackOff, seal-status는 연결 거부 | V | VD-10 |
| unseal된 파드는 KMS 장애 중에도 계속 서비스(재시작 금지의 진짜 근거) | L | VD-10(로그) |
| `VaultSealed`(`== 0`)만으로는 재시작 실패(absent)를 못 잡음 — FR-040 MetricsAbsent(`absent()` 6종 30m)가 이미 덮음 | V | VD-16 |
| seal-status `type` = `"ocikms"` 문자열 그대로(vault-2 단언 성립); `recovery_seal`·`storage_type` 실제값은 미확인 | V/L | VD-14 |
| **Vault 2.0: `sys/generate-root`·`sys/rekey`는 recovery key + 유효 토큰 요구**; 우회 `enable_unauthenticated_access`는 보안 후퇴 | V | — |
| `disable_mlock=true`의 대가 = 스왑 있을 때 유출 가능 | L | VD-06 |
| 스냅샷은 seal 래핑; `-force`는 정합성 검사 우회일 뿐 다른 키로 복구 불가 | V | — |
| **OCI 키 삭제 예약 즉시** 그 키로 암호화된 것 접근 불능, 30일은 취소 창(7~30일) — "유예 30일"은 오류 | V | — |
| 키 회전은 이전 버전으로 계속 복호화; Community 2.0.4에 `operator seal-rewrap` 없음 | V | — |
| platform-backup.sh 헤더가 이미 `vault-unseal.md`를 참조 | V | — |
| `platform-gitops` PUBLIC, `ocid1.`·`oraclecloud.com` 0건 | V | VD-09 |
| seal 3값은 운영자만 `tofu -chdir=infra/oci output`으로 읽음 | V | — |

### 3.3 Kubernetes auth · 정책/role · OpenTofu provider · 하네스

| 사실 | conf | VD |
|---|---|---|
| hashicorp/vault 5.11.0 = OpenTofu 레지스트리 5.x 최신; 스크래치 `~> 5.11.0` 핀으로 lock 5.11.0 기록 | V | — |
| `tofu init -backend=false` + `validate -json`이 VAULT_ADDR/TOKEN 없이 valid=true(validate는 Configure 안 함) | V | — |
| `file("${path.module}/policies/…")`는 `New-TfValidateCopy`가 하위 디렉터리를 안 복사해 임시 사본에서 FAIL → heredoc 인라인 채택(heredoc 금지는 infra/oci 한정 :24) | V | — |
| `disable_iss_validation`은 provider가 `d.Get`으로 **무조건 전송** → 생략 시 false 기록 → 전 role 로그인 실패 | V | VD-18 |
| `kubernetes_host`만 설정, `token_reviewer_jwt`·`kubernetes_ca_cert` 미설정(상태 파일 비밀 0) | V | VD-23 |
| `kubernetes_host = https://kubernetes.default.svc:443`(allow-dns + allow-kube-api DNAT) | L | VD-18(로그인 = 판정) |
| role 필드: `audience`(단수) · `token_ttl/max_ttl` 초 정수 · `token_policies` · `token_type = service` 명시 | V | — |
| `token_no_default_policy` 금지(ESO lookup-self/revoke-self · 백업 revoke-self가 default에만) | V | — |
| vault-backup 정책 = `sys/storage/raft/snapshot` read 1블록(저장 GET, sudo 불요, 복원 update 자동 차단) | V/L | VD-18 |
| eso-data 20블록(data 10 + metadata 10), 세그먼트 와일드카드도 금지 | V | — |
| `sys/auth` sudo(5곳), `sys/mounts`·`sys/policy` sudo 아님, `sys/audit` 전부 sudo | V | — |
| 감사 fail-closed(모든 장치 실패 시 요청 거부); `file_path=stdout` 공식 형태, `log_raw` false = HMAC | V | — |
| agent-view `view` ClusterRole로 `pods/log` get → 감사 존재 확인 가능 | L | VD-15 |
| provider child 토큰(TTL 20m) → 호출 토큰에 `auth/token/create` update(root는 보유) | V | — |
| `vault_mount type = "kv-v2"`, `options` 생략 | V | — |
| **agent-view에 `serviceaccounts/token` create 없음** → tester가 `--audience vault` 토큰 자급 불가 | V | VD-20 |
| ESO는 TokenRequest 호출 → ESO 컨트롤러 RBAC 필요(T045); Vault role은 SA 존재 검사 안 함 | L | T045 |
| ESO 1.21+/Vault 2.x audience 없으면 인증 실패 | V | — |
| `vault kv get` preflight `sys/internal/ui/mounts/kv`가 default에 없음 → `vault read` 사용 | L | VD-19 |
| run-all은 run-platform-tests.ps1 슬롯 1d 경유; 게이트는 `@('oci','cloudflare')` — infra/oci가 있으므로 tofu.tests가 이미 실행됨(배열 무변경) | V | — |
| infra/vault plan 단언 불가(하네스 예외 확대) | V | — |

### 3.4 계약·테스트·스크립트 정합

| 사실 | conf | VD |
|---|---|---|
| vault-1/vault-2: agent-view port-forward → **http** `/v1/sys/seal-status` 1회 조회, sealed=false·type ordinal `ocikms` → `tlsDisable=true`는 통과 조건 | V | VD-11 |
| argo-4 전체 = ns vault 모든 PVC + pg-main·jt-kafka·Dragonfly·CRD → T044만으로 PASS 아님(T046+ 공동) | V | — |
| np-4: vault ingress 출발 ns ⊆ {kube-system, monitoring, external-secrets}, `namespaceSelector: {}` 하나라도 있으면 FAIL | V | — |
| ingress vault-2 = host `vault.joshuatech.dev` Ingress 존재(대소문자 무시) | V | — |
| backup-2 = 버킷 `vault/` 24h 내 `.age` ≥1, backup-3 = 비-.age 0·총 0이면 FAIL → T044 완료 판정에 env 삭제 + 성공 백업 1회 포함 | V | VD-22 |
| platform-backup.sh 요구: 노드 A `vault`·`k3s`·`curl`·`ss` · Service `vault` · SA `vault-backup` + `--audience vault --duration=10m` · role `vault-backup` · `VAULT_ADDR=http://127.0.0.1:<port>` · `vault status` exit 0 · `raft snapshot save` · `revoke -self` · 키 `vault/vault-<UTC>.snap.age` | V | — |
| 노드 A `vault` CLI v2.1.0 이미 설치(host-prep, platform 전용) | V | — |
| **`--pre-upgrade`는 `svc vault` 감지 시 vault 스냅샷 필수 승격**(:161-176); prepare 실패는 창 밖 재트리거 | V | — |
| `/etc/platform-backup/env`에 `BACKUP_COMPONENTS=k3s` 실존(T036 기록) | V | VD-07 |
| platform-backup.tests.ps1(76 단언)은 코드 텍스트만 대조 → 헤더 산문 수정 안전; 낡는 곳은 :40 · :44-45 · :56-58(+절차 분기) 3곳 | V | — |
| validate 검사 1은 helm 없으면 fail-closed(cert-manager 동일); 5.4b는 키 없으면 skip → port/targetPort 명시 필요; 5.4c는 HCL 여러 줄 첫 줄만 파싱(오탐 없음); 7.1은 Application 불변; 4b는 블록 표기 미매칭 | V/L | VD-08 |
| **gitops CI required check `validate`는 gitleaks만 실동작**(검사 1–7 placeholder) | V | — |
| gitleaks 기본 룰의 OCID 반응 미확인 | U | VD-09 |
| `telemetry { disable_hostname = true }` 없으면 지표명에 호스트 접두 → VaultSealed 불성립 | V | VD-16 |
| `prometheus_retention_time = "1m"`(동결) → 스크레이프 주기 ≤30s 필요 | L | VD-16 |
| ns vault에 `allow-same-namespace` 없음(1 replica 정합); 8201 미허용(HA 확장 시 정책 선행) | V | — |
| Access 앱 `vault` 이미 존재(`infra/cloudflare/access.tf:106-111`) → Cloudflare 변경 0 | V | — |
| local-path setup 0777 여부 미확인 | U | VD-04 |
| 문서 영향: bootstrap §4 T044 절 · vault-unseal.md 신규 + docs/README 행 · docs/kr 미러 불요 · ADR 0010 무편집 · gitops README 신규 · secrets/README는 T045 | V | — |
| 워크스테이션 `vault` CLI 설치 여부 미확인 | U | VD-01 |

### 3.5 gitops 배치 · Argo 동작

| 사실 | conf | VD |
|---|---|---|
| 전역 `namespace:` 변환기 두지 않음(차트가 `vault.namespace` 렌더, CRB subject 재작성 방지); 수기 매니페스트는 ns 명시 | V | — |
| `resources:` = ingress.yaml + serviceaccount-vault-backup.yaml; SA `vault-backup`에 K8s RBAC 불필요 | V | — |
| AppProject `sourceRepos`의 hashicorp 줄 삭제(D7 규칙, jetstack 선례) — `source.repoURL`만 검사하므로 라이브 영향 0 | V | — |
| init 전 Application = Progressing, root app-of-apps도 Healthy 상실 → wave 10에서 멈춤 → **init 전 `clusters/oci-k3s/apps/` PR 머지 금지** | V | — |
| readinessProbe를 HTTP `sealedcode=204`로 바꾸는 레버는 봉인을 은폐하므로 기각 | L | — |
| PVC `data-vault-0`은 Argo 트리 밖 → 고아 경고 1건(정상, 삭제 금지) | V | — |
| Ingress 백엔드 `vault` 포트 이름 `http`; `router.entrypoints` 생략 금지(8080·9100 누출) | V | — |
| AOP 뒤 오리진 확인 = T043 절차 재사용(노드 A 내부 `--resolve` · 4xx 프로브 TLSClientSubject) | V | VD-21 |
| image 인덱스 digest `sha256:5be49781…e1a2`(2026-09-14 실측) | V | VD-12 |
| G1 머지 시각 규율 = cert-manager T042 draft + 체크박스 | V | — |
| XFF `reject_not_present` 런타임 기본값은 v2.0.4 소스상 false(Go 제로값)지만 문서는 true로 읽힘 → 미도입이 안전 | V | VD-11 |

### 3.6 운영자 절차·비밀 취급

| 사실 | conf | VD |
|---|---|---|
| winget `Hashicorp.Vault` 버전 고정 가능 여부(2.0.4 매니페스트) | L | VD-01 |
| zip `vault_2.0.4_windows_amd64.zip` HTTP 200, SHA256 `5e6357e5…d8f` | V | VD-01 |
| install 페이지 latest = 2.1.0 → 스큐 주의 | V | — |
| `~/.vault-token`은 `vault login`만 생성; `VAULT_ADDR` 기본 `https://` → `http://` 명시 필수 | V | — |
| PowerShell `-flag=value` 함정 → 따옴표 | L | VD-03 |
| `init -status` exit 0/1/2; 재init 거부 | V | — |
| init 전 seal-status 인증 불요 | V | — |
| 근접 사고 기록: bootstrap.md:182 ⑥(클립보드 값 미저장 → argocd admin 비밀번호 분실) | V | — |
| audit → tofu 순서로 write 15건 감사에 남음 | L | VD-15 |
| 예상 리소스 15(mount 1 + auth 1 + config 1 + policy 6 + role 6) | L | 단계 12 게이트 |
| 백업 연결 절차(env 삭제 → 수동 1회 → textfile → 버킷 → 러너 → 타이머 02:30) | V | VD-22 |
| 다음 SUC 창 2026-09-20(일) 03:00 KST | V | — |
| KMS 엔드포인트 NXDOMAIN 부정 캐시 선례(T010) | V | VD-05 |
| 복원 뒤 recovery key가 스냅샷 시점으로 되돌아가는지 미검증 | U | VD-24(T048 이후) |

---

## 4. 파일 트리·매니페스트

```
platform-gitops (main fa6d838 기준, G1)
  clusters/oci-k3s/projects/platform.yaml        sourceRepos hashicorp 1줄 삭제(커밋 ②)
  platform/vault/
    kustomization.yaml                           helmCharts 인플레이트 + valuesInline + HCL  (seal 3값은 커밋 ③에서)
    ingress.yaml                                 vault.joshuatech.dev → svc vault:http
    serviceaccount-vault-backup.yaml             SA vault-backup(RBAC 0)
    README.md                                    §0–§8 (cert-manager 형식)

joshuatech_ver2 (M0 · M1 · M2)
  specs/003-platform-foundation/contracts/hostnames-and-access.md   :79 부근 e2e-reader 토큰 발급 절차 1줄 (M0)
  infra/vault/
    versions.tf  backend.tf  providers.tf  main.tf  policies.tf  roles.tf  outputs.tf  .terraform.lock.hcl
  tests/infra/tofu.tests.ps1                     vault 그룹 20 단언 추가(헤더 41 → 61)
  docs/runbooks/vault-unseal.md                  신규(정본)
  docs/runbooks/bootstrap.md                     §4 T044 절
  docs/README.md                                 runbooks 행 1개 추가
  infra/bootstrap/platform-backup.sh             헤더 산문 3곳(+절차 분기)
  specs/003-platform-foundation/tasks.md         T044 [X]만
```

### 4.1 `platform/vault/kustomization.yaml`

```yaml
# platform/vault/ — HashiCorp Vault 2.0.4 (chart 0.34.1 · Raft 1 replica · OCI KMS auto-unseal) (T044)
#
# 정본 계약(모노레포 specs/003-platform-foundation/contracts/):
#   - gitops-repo.md §Application 규약(**삭제 보호**: Vault PVC에 `argocd.argoproj.io/sync-options: Delete=false,Prune=false`)
#     · §sync-wave 단일 표(vault = wave 10 — 번호는 그 표에만) · §이미지(platform/ 이미지는 태그에 `@sha256` 병기)
#     · §ClusterSecretStore 표(role 이름 = SA 이름 · audiences [vault] · token_ttl 1h/4h) — Vault **내부** 설정(kv 마운트 ·
#       auth/kubernetes · 정책 6 · role 6)은 여기가 아니라 모노레포 `infra/vault/` OpenTofu가 소유한다.
#   - network-policy.md §ns 표(`vault` = PSA **restricted**) · §허용 매트릭스(ingress 8200 ← traefik·external-secrets·monitoring /
#     egress 53 · 6443 · 443 · IMDS 80) · §워크로드 강화(helm 컴포넌트는 values에 securityContext 4항목 **명시**)
#   - hostnames-and-access.md :31(`vault.joshuatech.dev` = Vault UI · Access 앱 `vault` GitHub IdP) · :59(seal 확인 = port-forward)
#
# ⚠ **UI로 `vault operator init`을 하지 않는다 — 운영자 워크스테이션 `vault` CLI만.** 절차 정본: 모노레포 docs/runbooks/vault-unseal.md
#   · 실행 기록: docs/runbooks/bootstrap.md §4 T044.
#
# 설치 방식 = kustomize `helmCharts` 인플레이트(cert-manager 선례). 전제: argocd-cm `kustomize.buildOptions: --enable-helm`(T042 PR-0, 라이브).
#   인플레이트는 helm 릴리스가 아니다(`helm list -n vault` 비어 있음이 정상). 로컬 재현: `kustomize build --enable-helm platform/vault`(helm 필요).
#   ⚠ hashicorp 차트는 **HTTPS helm repo**다 — `repo:`에 `oci://`를 붙이지 않는다(cert-manager는 OCI라 붙였다; 규칙이 반대다).
#   ⚠ 이 차트의 `values.schema.json`에는 `additionalProperties: false`가 **한 곳도 없다**(cert-manager는 28곳). 키 오타는 조용히 무시되고
#     렌더는 성공한다 — 유일한 방어는 렌더 결과 대조다(README §2).
#
# 이 디렉터리가 만들지 "않는" 것:
#   1) Namespace `vault`·PSA 라벨·NetworkPolicy → `platform/policies/`(정책 객체는 거기에만; validate 5.0·5.1). 차트 정책은 아래에서 false로 명시.
#   2) Application `platform-vault` → `clusters/oci-k3s/apps/platform-vault.yaml`(T041부터 라이브). 이 PR은 건드리지 않는다(검사 7.1).
#   3) ClusterSecretStore·ExternalSecret → `secrets/`(T045).
#   4) 시크릿 값: 없다. seal의 key OCID·KMS 엔드포인트는 **자격이 아니라 식별자**다 — OCI 호출은 인스턴스 프린시펄 x509 서명으로만 인가되고
#      권한은 `target.key.id` 조건이 붙은 IAM 정책이 정한다(README §0). env 우회는 구조적으로 불가능하다: Vault가 seal 스탠자에
#      `WithDisallowEnvVars(true)`를 넘겨 `VAULT_OCIKMS_*`를 무시한다.
#
# 되돌리기(순서 고정 — README §5 · 런북 §11과 같다): revert 머지 → 렌더 0(Application은 `prune: false`라 객체가 남는다) →
#   ① `kubectl -n vault delete ingress vault`(공개 진입점 먼저) → ② `kubectl -n vault delete sts vault --cascade=orphan` →
#   ③ 남은 pod/vault-0 삭제 → ④ Service·ConfigMap·SA·RBAC 수동 정리 → ⑤ **PVC `data-vault-0`과 PV는 절대 지우지 않는다**
#   (local-path reclaimPolicy Delete → 노드 A 디스크 데이터 소멸; 복구 = Raft 스냅샷 + **같은 KMS 키**뿐).
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

# ⚠ 전역 `namespace:` 변환기를 두지 않는다(cert-manager와 같은 이유). 차트의 ns 객체는 `helmCharts[].namespace`로 렌더되고,
#   `system:auth-delegator` ClusterRoleBinding의 subject ns까지 재작성하는 두 번째 메커니즘을 만들 이유가 없다.
#   아래 순수 매니페스트는 각자 `metadata.namespace: vault`를 명시한다(platform/cloudflared·system-upgrade는 변환기를 쓰니 복사 주의).
resources:
  - ingress.yaml
  - serviceaccount-vault-backup.yaml

helmCharts:
  - name: vault
    repo: https://helm.releases.hashicorp.com   # HTTPS helm repo — `oci://` 접두 금지
    version: 0.34.1                             # appVersion 2.0.4. 대조용 실측(값 고정 아님): index.yaml tgz sha256
                                                #   df4c37fac32496892ff1e1d6fd7954d3a402cc7b1b2b4c2226af11b8a57564c4 (2026-09-14)
                                                # ⚠ kustomize는 `charts/vault`가 이미 있으면 버전을 보지 않고 pull을 건너뛴다 →
                                                #   bump는 repo-server 재시작(또는 charts/ 제거) 뒤에 실제 반영된다(README §2).
    releaseName: vault                          # **필수**. fullname 헬퍼가 릴리스 이름을 그대로 써서 Service/STS/SA/ConfigMap이 `vault`·
                                                # `vault-config`가 된다 — platform-backup.sh `VAULT_SERVICE=vault`, cluster.tests
                                                # `port-forward svc/vault`, PVC `data-vault-0`이 전부 이 값에 걸려 있다.
    namespace: vault
    valuesInline:
      global:
        enabled: true
        tlsDisable: true          # 리스너 평문(8200) — TLS 종단은 Traefik(websecure) + Cloudflare AOP. cluster.tests·reboot.tests·
                                  # platform-backup.sh가 전부 http로 하드코딩돼 있어 선택이 아니라 통과 조건. Service 포트 이름도 이 값으로 `http`.

      injector:
        enabled: false            # ⚠ 기본값은 "-"(= global.enabled 상속 = **true**). 명시하지 않으면 injector Deployment·Service·RBAC·
                                  # certs Secret과 **클러스터 범위 MutatingWebhookConfiguration**이 함께 배포된다(failurePolicy Ignore라
                                  # 조용히 성공해 더 위험). 시크릿 주입은 ESO만(ADR 0010).
      csi:
        enabled: false            # 기본값도 false지만 계약 의도를 코드에 남긴다.
      ui:
        enabled: false            # 이 키는 Service `vault-ui`를 하나 더 만들 뿐이다. UI 자체는 아래 HCL `ui = true`로 8200의 /ui에서
                                  # 서빙되고 Ingress는 Service `vault`를 백엔드로 쓴다(research VAULT-D2 편차 — converge 인계).

      server:
        image:
          repository: hashicorp/vault
          # 이 차트에는 cert-manager의 `image.digest` 키가 **없고** StatefulSet은 `image: {{repo}}:{{tag}}` 한 줄만 렌더한다 →
          # 계약 §이미지의 digest 병기는 태그 문자열에 이어 붙이는 형태가 유일하다(`repo:tag@digest`는 유효한 OCI 참조).
          # digest = 멀티아치 **인덱스** digest(노드 2대 arm64), 2026-09-14 registry-1.docker.io 실측. bump PR이 함께 갱신한다.
          # ⚠ 이 값을 지켜 주는 자동 검사는 없다 — validate 4b는 블록 표기라 `image:` 스칼라 정규식에 매칭조차 하지 않는다(README §2).
          # ImagePullBackOff/InvalidImageName이면 `"2.0.4"`로 되돌리고 digest는 주석 기록만 남긴다(설계 D6 폴백).
          tag: "2.0.4@sha256:5be49781ecf78bfe775c5309c6a4d9f4e9e040b6c885c99eb2b12fb69855e1a2"

        # 차트 기본값 OnDelete를 **유지**한다: HCL(ConfigMap) 변경이 파드를 자동 재시작시키지 않는 편이 "KMS 장애 중 pod 재시작 금지"
        # 규율과 맞다. 대가는 조용한 드리프트 → config 체크섬을 함께 켠다.
        # ⚠ 설정 변경 = PR 머지 **+ 운영자 `kubectl -n vault delete pod vault-0`** 두 단계(README §3 · 런북 §10).
        updateStrategyType: OnDelete
        includeConfigAnnotation: true

        networkPolicy:
          enabled: false          # 켜면 `namespaceSelector: {}`(전 ns) → 8200·8201 ingress가 렌더되어 계약과 cluster.tests np-4를 동시에
                                  # 깬다. validate 5.0은 **원본 파일만** 보므로 helm 렌더 결과의 이 위반은 잡지 못한다 — 라이브 np-4가 유일한 그물.

        nodeSelector:
          role: platform          # **가용성의 필수 조건**(편의가 아니다). OCI 동적 그룹 `joshuatech-node-a`의 matching_rule은 노드 A 인스턴스
                                  # OCID 1개뿐(infra/oci/iam.tf:110-118)이라, 노드 B에 뜨면 인스턴스 프린시펄 federation은 되지만 어떤 KMS
                                  # 정책에도 속하지 않아 Encrypt가 NotAuthorizedOrNotFound → seal 설정 실패 = **프로세스 즉사**.

        service:
          enabled: true
          port: 8200              # 명시해야 validate 5.4b(HELM_PORT_KEYS `vault .server.service.port 8200`)가 **실제로 대조한다**
          targetPort: 8200        # (키가 없으면 검사가 조용히 건너뛴다). 계약 §포트 표·정책 매트릭스와 3중 일치 — 변경 금지.
          publishNotReadyAddresses: true   # 기본값 명시: 봉인·미초기화(NotReady)에서도 엔드포인트가 남아야 port-forward와 UI 도달이 된다.
          active:
            enabled: false        # replicas=1에 무의미. selector `vault-active: "true"`는 unseal 뒤에야 붙어 봉인 중 엔드포인트 0
          standby:
            enabled: false        # (Ingress 백엔드로 쓰면 바로 그때 503). 객체 2장 감소.

        ingress:
          enabled: false          # Ingress는 ingress.yaml 순수 매니페스트(선례 bootstrap/argocd/ingress.yaml, 백엔드 포트 **이름**).

        authDelegator:
          enabled: true           # ClusterRoleBinding → system:auth-delegator. auth/kubernetes TokenReview에 필수(Vault가 자기 파드의
                                  # SA 토큰을 리뷰어로 자동 사용 → token_reviewer_jwt를 tofu 상태에 두지 않는다).
        serviceAccount:
          create: true
          serviceDiscovery:
            enabled: true         # Role/RoleBinding(pods get/watch/list/update/patch) — service_registration "kubernetes"가 요구.

        # securityContext: ns `vault`가 PSA **restricted**이므로 계약 §워크로드 강화의 4항목은 admission 통과 조건이다.
        # ⚠ 차트 헬퍼는 값이 주어지면 기본값을 **병합이 아니라 대체**한다 → pod 쪽 기본값(runAsUser 100 / runAsGroup 1000 / fsGroup 1000)을
        #   여기서 다시 적는다(빠뜨리면 SKIP_CHOWN=true와 겹쳐 /vault/data 쓰기 실패 가능). `readOnlyRootFilesystem`은 넣지 않는다
        #   (args가 /tmp/storageconfig.hcl에 쓴다). `IPC_LOCK` 불필요: HCL `disable_mlock = true` + 이미지 SKIP_SETCAP=true(2.0.2부터 요구 제거).
        statefulSet:
          securityContext:
            pod:
              runAsNonRoot: true
              runAsUser: 100
              runAsGroup: 1000
              fsGroup: 1000
              seccompProfile:
                type: RuntimeDefault
            container:
              allowPrivilegeEscalation: false
              runAsNonRoot: true
              capabilities:
                drop:
                  - ALL
              seccompProfile:
                type: RuntimeDefault

        resources:                # 차트 기본은 `{}` — 명시하지 않으면 plan A14 예산 대조가 성립하지 않는다.
          requests:               # A14 노드 A 행 "Vault·ESO 0.5 GiB"의 Vault 몫. T097 실측으로 교정.
            cpu: 100m
            memory: 256Mi
          limits:
            memory: 512Mi         # CPU limit은 두지 않는다(저장소 관례 · validate 5.5와 같은 취지)

        dataStorage:
          enabled: true
          size: 5Gi
          storageClass: local-path   # 기본 SC에 기대지 않고 못박는다(WaitForFirstConsumer → nodeSelector와 함께 PV도 노드 A).
          annotations:
            # 계약 §삭제 보호. 차트가 이 값을 volumeClaimTemplates[0].metadata.annotations로 렌더하고 StatefulSet 컨트롤러가 템플릿을
            # DeepCopy하므로 PVC `data-vault-0`에 그대로 전파된다 → cluster.tests argo-4(ns vault의 **모든** PVC)를 만족한다.
            # ⚠ volumeClaimTemplates는 STS 생성 후 **불변** — 첫 apply에 없으면 이후 sync가 거부되고 되돌리기가 비싸다.
            # 이 어노테이션은 Argo 관리 밖 PVC의 '표식'일 뿐 실제 보호가 아니다(README §5 · 런북 §11).
            argocd.argoproj.io/sync-options: Delete=false,Prune=false
        auditStorage:
          enabled: false          # 감사는 `vault audit enable file file_path=stdout`(alloy-logs). 켜면 어노테이션 없는 PVC `audit-vault-0`이
                                  # 생겨 argo-4가 FAIL한다.
        # persistentVolumeClaimRetentionPolicy는 적지 않는다: 차트가 `semverCompare ">= 1.23-0"` 뒤에 두는데 helm 기본
        # Capabilities.KubeVersion이 v1.20이라 `helmCharts[].kubeVersion` 없이는 조용히 사라진다. K8s 기본값이 이미 Retain/Retain이라
        # 동작은 같고, 거짓 안전감만 제거한다(설계 D2).

        ha:
          enabled: true
          replicas: 1
          # ⚠ `server.ha.config`는 **건드리지 않는다**(차트 기본 consul HCL 그대로). ConfigMap과 /vault/config 마운트의 렌더 조건이
          #   `standalone.config or ha.config`인데 볼륨 정의만 `ha.raft.config`도 인정한다 — 빈 문자열로 바꾸면 ConfigMap이 사라지고
          #   볼륨만 남아 파드가 ContainerCreating(configmap "vault-config" not found)에 갇힌다. raft가 켜지면 실제 HCL은 아래 raft.config다.
          disruptionBudget:
            enabled: false        # replicas=1이면 차트 헬퍼가 maxUnavailable을 **0**으로 고정(override 불가) → 자발적 축출 전면 차단 =
                                  # 앞으로 노드 A `kubectl drain`이 영구 대기. SUC Plan은 cordon만 쓰므로 업그레이드는 무해하지만 지뢰를 남기지 않는다.
          raft:
            enabled: true
            setNodeId: true
            # HCL 주의사항:
            #  (1) 차트 헬퍼가 이 문자열을 `tpl`로 한 번 렌더한다 → `{{ }}`를 쓰지 않는다.
            #  (2) 기본 raft config를 통째로 대체하므로 `service_registration "kubernetes" {}`를 **직접 다시 넣는다**(빠지면 파드 라벨
            #      vault-active/vault-sealed가 영영 붙지 않는다 — 증상이 조용하다).
            #  (3) `disable_mlock`이 없으면 헬퍼가 자동으로 붙이지만 task 문면대로 명시한다(Vault 2.x는 integrated storage에서 명시 필수).
            #      노드 A 스왑 0 실측이 전제(VD-06).
            #  (4) api_addr/cluster_addr는 적지 않는다 — 차트가 env VAULT_API_ADDR/VAULT_CLUSTER_ADDR로 주입한다.
            #  ⚠ `x_forwarded_for_*`는 **의도적으로 넣지 않는다**(research VAULT-D3 편차, 설계 D9): authorized_addrs가 비어 있지 않으면
            #    Vault가 XFF 래퍼를 설치하고, 그 래퍼는 remote 주소를 보기 전에 헤더 부재를 검사해 reject_not_present일 때 400을 돌려준다.
            #    헤더 없는 경로 = readinessProbe(127.0.0.1) · port-forward seal-status · platform-backup.sh · ESO · metrics 스크레이프 전부.
            #    실제 클라이언트 IP는 Cloudflare Access 로그와 Traefik 액세스 로그(CF-Connecting-IP keep)에 남는다.
            #  ⚠ seal 3값은 **운영자가 `tofu -chdir=infra/oci output -raw …`로 채운다**(에이전트는 읽을 수 없다). 값이 틀리면 sealed가
            #    아니라 **프로세스 즉사(CrashLoopBackOff)** 다. `auth_type_api_key = "false"` = 인스턴스 프린시펄(true면 ~/.oci/config를 찾다 실패).
            #  ⚠ `disable_hostname = true`가 없으면 게이지에 호스트명 접두가 붙어 알림 `VaultSealed`(vault_core_unsealed == 0)가 성립하지 않는다.
            config: |
              ui = true

              listener "tcp" {
                address         = "[::]:8200"
                cluster_address = "[::]:8201"
                tls_disable     = true

                telemetry {
                  unauthenticated_metrics_access = true
                }
              }

              storage "raft" {
                path = "/vault/data"
              }

              seal "ocikms" {
                key_id              = "<OPERATOR-FILL: tofu -chdir=infra/oci output -raw kms_key_id>"
                crypto_endpoint     = "<OPERATOR-FILL: tofu -chdir=infra/oci output -raw kms_crypto_endpoint>"
                management_endpoint = "<OPERATOR-FILL: tofu -chdir=infra/oci output -raw kms_management_endpoint>"
                auth_type_api_key   = "false"
              }

              service_registration "kubernetes" {}

              telemetry {
                prometheus_retention_time = "1m"
                disable_hostname          = true
              }

              disable_mlock = true
```

### 4.2 `platform/vault/ingress.yaml`

```yaml
# platform/vault/ingress.yaml — Vault UI/API 공개 진입점 `vault.joshuatech.dev` (T044)
#
# 정본 계약: 모노레포 contracts/hostnames-and-access.md :31(호스트 vault. · Access 앱 `vault` GitHub IdP · 뒤에서 Authentik OIDC는 US4)
#   · spec FR-011(표준 networking.k8s.io Ingress · ingressClassName traefik · router.tls true · spec.tls 생략)
#   · contracts/network-policy.md(kube-system(traefik) → vault 8200 — platform/policies `allow-from-traefik`, 이미 라이브)
# 형태 근거(bootstrap/argocd/ingress.yaml 선례를 그대로 따른다):
#   - 백엔드는 Service **`vault`**의 포트 **이름 `http`**다. 이유 셋:
#       (a) `vault-active`는 selector `vault-active: "true"`(service_registration이 unseal 뒤 붙이는 라벨)를 요구해
#           **초기화 전·봉인 중 엔드포인트 0 → 503** — UI가 필요한 바로 그 순간에 사라진다.
#       (b) `vault`는 publishNotReadyAddresses: true라 NotReady여도 엔드포인트가 남는다.
#       (c) 포트를 **이름**으로 쓰면 훗날 `global.tlsDisable`을 뒤집었을 때 차트가 포트 이름을 `https`로 바꿔 Ingress가 눈에 보이게
#           깨지고 Traefik이 백엔드 TLS로 전환한다(번호 8200은 평문 요청을 TLS 리스너에 보내는 조용한 502).
#   - `router.entrypoints: websecure`는 **필수**. 생략하면 이 라우터가 traefik(8080)·metrics(9100) 엔트리포인트에도 붙어
#     Access를 지나지 않는 내부 경로가 생긴다.
#   - `router.tls.options`는 적지 않는다 — 이름 없는 라우터는 kube-system TLSOption `default`(TLS12 · sniStrict ·
#     clientAuth RequireAndVerifyClientCert, T043)를 받는다. `spec.tls` 없음: TLSStore default의 와일드카드가 SNI로 고른다.
#   - ⚠ path `/` Prefix라 Access를 통과한 브라우저 세션에는 `/v1/*` API 전체가 열린다. US4에서 Authentik OIDC가 붙기 전까지
#     **Cloudflare Access(GitHub IdP) + AOP가 유일한 방어선**(런북 §0).
#   - ⚠ **UI로 `vault operator init`을 하지 않는다** — 브라우저 초기화 화면은 recovery key·root 토큰을 화면과 다운로드 파일로 남긴다.
# 되돌리기: 이 파일 제거 PR을 머지해도 `platform-vault`는 prune:false라 객체가 남는다 → 운영자 `kubectl -n vault delete ingress vault`
#   (전체 되돌리기 순서에서 **첫 번째** — kustomization.yaml 머리).
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vault
  namespace: vault
  labels:
    app.kubernetes.io/name: vault
    app.kubernetes.io/instance: vault
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  rules:
    - host: vault.joshuatech.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: vault
                port:
                  name: http
```

### 4.3 `platform/vault/serviceaccount-vault-backup.yaml`

```yaml
# platform/vault/serviceaccount-vault-backup.yaml — 노드 A의 platform-backup.sh가 Raft 스냅샷을 뜰 때 쓰는 신원 (T044)
#
# 이 SA에는 **K8s RBAC를 붙이지 않는다**. Vault Kubernetes auth의 bound service account 식별자일 뿐이고, 백업 스크립트는 노드 A에서
# `k3s kubectl -n vault create token vault-backup --audience vault --duration=10m`으로 토큰만 뽑아
# `vault write auth/kubernetes/login role=vault-backup jwt=-`에 파이프로 흘린다(파일·명령줄·로그 없음).
# 짝이 되는 Vault 쪽 설정(role `vault-backup`, 정책 `sys/storage/raft/snapshot` read)은 모노레포 `infra/vault/`가 소유한다.
#
# ⚠ 시간 제약: helm이 Service `vault`를 만든 순간부터 `platform-backup.sh --pre-upgrade`(SUC prepare)가 vault 스냅샷 성공을
#   **필수**로 승격한다. role `vault-backup`이 생기기 전까지 prepare가 실패하고 그 실패는 일요일 03:00–05:00 KST 창 밖에서도
#   재트리거된다 — 배포와 `infra/vault` apply는 같은 운영자 세션에서 끝낸다(bootstrap.md §4 T044).
# 확인: `kubectl create token vault-backup -n vault --audience vault --duration=10m`
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-backup
  namespace: vault
  labels:
    app.kubernetes.io/name: vault
    app.kubernetes.io/component: backup
automountServiceAccountToken: false
```

### 4.4 `infra/vault/versions.tf`

```hcl
# infra/vault — Vault 내부 설정 스택(T044): kv v2 마운트 · kubernetes auth · 정책 6 · role 6.
# provider 핀은 vault 하나뿐이다. `.terraform.lock.hcl`을 커밋한다(registry.opentofu.org/hashicorp/vault 5.11.0).
#
# 이 스택이 소유하지 "않는" 것:
#   - Vault 서버 배포(helm) → platform-gitops `platform/vault/`
#   - 감사 장치(`sys/audit`) → **CLI 1회**(설계 D5). list·enable·disable이 전부 sudo라 tofu가 소유하면 매 plan의 refresh가 sudo를 요구한다.
#   - kv **값** → 운영자 `vault kv put`(T044 플레이스홀더 8경로 · T045 시드 · T081/T082 실값). 상태 파일에 비밀을 남기지 않는다.
#   - ClusterSecretStore/ExternalSecret → platform-gitops `secrets/`(T045)
#   - role `identity-admin` · 정책 `pod-identity-admin` · OIDC auth method(US4)
terraform {
  required_version = ">= 1.12.6"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.11.0"
    }
  }
}
```

### 4.5 `infra/vault/backend.tf`

```hcl
# 원격 상태: OCI Object Storage S3 호환 API (버킷 joshuatech-tfstate) — infra/oci·infra/cloudflare와 같은 버킷, 키만 다르다.
#
# 운영자 전용 절차 — 에이전트는 절대 실행하지 않는다(에이전트는 `init -backend=false`까지만):
#   0. **새 창의 첫 줄**: Set-PSReadLineOption -HistorySaveStyle SaveNothing ; $Transcript 비어 있음 확인 (런북 §0 창 시작 체크리스트)
#   1. Vault가 port-forward로 도달 가능해야 한다(별도 창): kubectl -n vault port-forward svc/vault 18200:8200   # admin kubeconfig
#   2. provider 자격은 환경변수로만 준다(파일·.tf·명령줄 리터럴 금지, `vault login` 금지 — ~/.vault-token 잔존):
#        $env:VAULT_ADDR  = 'http://127.0.0.1:18200'
#        $env:VAULT_TOKEN = (Read-Host -AsSecureString 'VAULT_TOKEN' | ConvertFrom-SecureString -AsPlainText)   # 비밀번호 관리자에서 붙여넣기
#   3. init/plan/apply:
#        $env:AWS_REQUEST_CHECKSUM_CALCULATION='when_required'; tofu -chdir=infra/vault init
#        tofu -chdir=infra/vault plan -out=t044.tfplan      # 기대: 15 to add / 0 to change / 0 to destroy
#        tofu -chdir=infra/vault apply t044.tfplan
#   4. 끝나면 Remove-Item Env:VAULT_TOKEN ; Remove-Item infra/vault/t044.tfplan ; Test-Path $env:USERPROFILE\.vault-token → False
#
# 상태 파일에는 시크릿이 들어가지 않는다: kv 값을 관리하지 않고(vault_generic_secret·vault_kv_secret* 금지), auth/kubernetes/config에
# token_reviewer_jwt·kubernetes_ca_cert를 설정하지 않는다(Vault가 자기 파드의 로컬 SA 토큰을 리뷰어로 쓴다). 다만 상태·plan은
# "누가 무엇을 읽을 수 있는가"의 완전한 인가 지도이므로 비공개·버저닝 버킷을 유지하고 plan 파일은 로컬에 남기지 않는다.
#
# profile "joshuatech-tfstate": 운영자가 svc-tfstate 사용자의 Customer Secret Key를 로컬 ~/.aws/credentials에 보관한다.
terraform {
  backend "s3" {
    bucket  = "joshuatech-tfstate"
    key     = "vault/terraform.tfstate"
    region  = "ap-chuncheon-1"
    profile = "joshuatech-tfstate"

    # axvjykgvo2m1 = 테넌시 Object Storage 네임스페이스(infra/oci/backend.tf와 동일).
    endpoints = {
      s3 = "https://axvjykgvo2m1.compat.objectstorage.ap-chuncheon-1.oraclecloud.com"
    }

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true

    # OCI S3 호환 API는 조건부 쓰기 기반 lockfile을 지원하지 않는다.
    use_lockfile = false
  }
}
```

### 4.6 `infra/vault/providers.tf`

```hcl
# provider 자격은 .tf에 쓰지 않는다 — 운영자 셸의 VAULT_ADDR·VAULT_TOKEN에서만 읽는다(backend.tf 헤더 절차).
# (문서상 address는 Required지만 `tofu validate`는 provider를 Configure하지 않으므로 무자격 하네스가 통과한다.)
#
# provider는 주어진 토큰으로 **child 토큰**(TTL 20분)을 만들어 쓴다 → 호출 토큰에 `auth/token/create` update가 필요하다(root 보유).
# `skip_child_token = true`는 문서가 strongly discouraged라 쓰지 않는다(child 토큰은 상태에 들어가지 않는다).
provider "vault" {
  max_lease_ttl_seconds = 1200
}
```

### 4.7 `infra/vault/main.tf`

```hcl
# infra/vault/main.tf — kv v2 마운트 + Kubernetes auth method (T044)
#
# 계약: contracts/gitops-repo.md §ClusterSecretStore(마운트 `kv`, role 이름 = SA 이름, audiences [vault], TTL 1h/4h)
#       ADR 0010 §6 부트스트랩 순서 ② helm → ③ init → ④ audit(CLI) → ⑤ 이 스택.

resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv-v2"
  description = "platform/dev/prod secrets consumed by External Secrets Operator (T044)"

  # `options`는 생략한다 — provider가 kv-v2를 kv+version=2의 별칭으로 인식한다(소스 주석: options block may be omitted).
}

resource "vault_auth_backend" "kubernetes" {
  type        = "kubernetes"
  path        = "kubernetes"
  description = "K3s service account login for ESO / backup / e2e (T044)"

  # ⚠ `sys/auth`는 sudo 엔드포인트다. 이 리소스를 tofu가 소유하는 한 apply뿐 아니라 **매 plan의 refresh도 sudo**를 요구한다 →
  #   정례 plan은 root(T045 revoke 전) 또는 설계 D4 결정 뒤의 관리 경로로만 가능하다(런북 §4).
}

resource "vault_kubernetes_auth_backend_config" "this" {
  backend = vault_auth_backend.kubernetes.path

  # 워크스테이션에서 apply하므로 pod 내부 $KUBERNETES_SERVICE_HOST를 보간할 수 없다 → 리터럴.
  # ns vault 정책에 allow-dns가 있어 해석되고, ClusterIP는 DNAT 뒤 노드 A:6443이 되어 allow-kube-api가 덮는다.
  # 로그인 실패(연결) 시 대안 "https://10.0.7.78:6443"(정책 변경 불필요) — VD-18.
  kubernetes_host = "https://kubernetes.default.svc:443"

  # ⚠ **필수**: provider는 이 필드를 GetOk가 아니라 d.Get으로 **무조건** 전송한다 → 생략하면 SDK 제로값 false가 기록되어
  #   issuer 검증이 켜지고, 기본 기대 issuer와 K3s 실제 iss가 달라 **6개 role의 모든 로그인이 조용히 실패**한다.
  disable_iss_validation = true

  # token_reviewer_jwt·kubernetes_ca_cert는 **설정하지 않는다**: Vault가 자기 파드의 로컬 SA 토큰과 CA를 리뷰어로 재읽는다(1.9.3+,
  # 차트 `server.authDelegator.enabled: true`가 system:auth-delegator CRB를 만든다). 설정하면 장수명 JWT가 상태 파일에 평문으로 남는다.
  # disable_local_ca_jwt도 생략(provider가 GetOk로 읽어 false는 전송하지 않는다).
}
```

### 4.8 `infra/vault/policies.tf`

```hcl
# infra/vault/policies.tf — ACL 정책 6개 (T044)
#
# 정책 본문은 heredoc 인라인이다(설계 확정). 별도 `policies/*.hcl` + `file()`을 쓰지 않는 이유: tests/infra/tofu.tests.ps1의
#   New-TfValidateCopy가 *.tf와 .terraform.lock.hcl만 임시 사본에 복사하므로 하위 디렉터리를 쓰면 무자격 validate가
#   "no file exists at ./policies/…"로 깨진다(oci·cloudflare 공유 함수를 고치지 않는다).
# ⚠ tofu.tests.ps1:24의 heredoc 금지는 **infra/oci 한정**(중괄호 파서 대상)이다. infra/vault 단언은 정규식 텍스트 검사만 쓰므로
#   이 디렉터리에 중괄호 파서 기반 단언을 추가하지 않는다(스위트 헤더에 명시).
#
# 공통 규칙:
#   - eso-*·e2e-reader·vault-backup 정책의 capabilities는 정확히 ["read"]다(계약 gitops-repo.md:98-101 — metadata도 read;
#     list는 비밀 이름 전수 열거라 주지 않는다. ESO가 dataFrom.find를 쓰게 되면 계약을 먼저 고친다).
#   - `token_no_default_policy`는 **어떤 role에도 걸지 않는다**(roles.tf): ESO는 로그인 후 auth/token/lookup-self, 종료 시 revoke-self를
#     부르고 platform-backup.sh도 `vault token revoke -self`를 쓴다 — 둘 다 내장 `default` 정책에만 있다(default는 kv 권한 0).
#   - `vault kv get`은 kv v2 preflight로 `sys/internal/ui/mounts/kv`를 읽는데 그 경로는 default에 없다 →
#     최소권한 토큰(e2e-reader)은 `vault read kv/data/...` 또는 HTTP API를 쓴다(런북·T077 인계, VD-19).

locals {
  policies = {
    # --- ESO store 4개 (다섯 번째 store k8s-data-ca는 kubernetes provider라 Vault role이 없다 — T045) ---
    "eso-platform" = <<-EOT
      path "kv/data/platform/*" { capabilities = ["read"] }
      path "kv/metadata/platform/*" { capabilities = ["read"] }
    EOT

    "eso-dev" = <<-EOT
      path "kv/data/dev/*" { capabilities = ["read"] }
      path "kv/metadata/dev/*" { capabilities = ["read"] }
    EOT

    "eso-prod" = <<-EOT
      path "kv/data/prod/*" { capabilities = ["read"] }
      path "kv/metadata/prod/*" { capabilities = ["read"] }
    EOT

    # eso-data: **열거 경로만**. `kv/data/dev/*`나 `kv/data/+/db/*` 같은 env/세그먼트 와일드카드는 금지 —
    # 미래에 추가되는 env·컴포넌트까지 자동으로 열어 준다(계약 §ClusterSecretStore vault-data 행, data-model §8). 블록 수 정확히 20.
    "eso-data" = <<-EOT
      path "kv/data/dev/db/*" { capabilities = ["read"] }
      path "kv/data/dev/kafka/*" { capabilities = ["read"] }
      path "kv/data/dev/dragonfly/*" { capabilities = ["read"] }
      path "kv/data/dev/openfga/*" { capabilities = ["read"] }
      path "kv/data/dev/authentik/webhooks/*" { capabilities = ["read"] }
      path "kv/data/prod/db/*" { capabilities = ["read"] }
      path "kv/data/prod/kafka/*" { capabilities = ["read"] }
      path "kv/data/prod/dragonfly/*" { capabilities = ["read"] }
      path "kv/data/prod/openfga/*" { capabilities = ["read"] }
      path "kv/data/prod/authentik/webhooks/*" { capabilities = ["read"] }
      path "kv/metadata/dev/db/*" { capabilities = ["read"] }
      path "kv/metadata/dev/kafka/*" { capabilities = ["read"] }
      path "kv/metadata/dev/dragonfly/*" { capabilities = ["read"] }
      path "kv/metadata/dev/openfga/*" { capabilities = ["read"] }
      path "kv/metadata/dev/authentik/webhooks/*" { capabilities = ["read"] }
      path "kv/metadata/prod/db/*" { capabilities = ["read"] }
      path "kv/metadata/prod/kafka/*" { capabilities = ["read"] }
      path "kv/metadata/prod/dragonfly/*" { capabilities = ["read"] }
      path "kv/metadata/prod/openfga/*" { capabilities = ["read"] }
      path "kv/metadata/prod/authentik/webhooks/*" { capabilities = ["read"] }
    EOT

    # --- 백업(노드 A platform-backup.sh) ---
    # 스냅샷 저장은 GET /sys/storage/raft/snapshot(= read)이고 sudo를 요구하지 않는다.
    # 복원(POST snapshot / snapshot-force)은 update 권한이라 자동으로 차단된다 — 백업 주체는 복원 불가(VD-18).
    "vault-backup" = <<-EOT
      path "sys/storage/raft/snapshot" { capabilities = ["read"] }
    EOT

    # --- E2E(tester, T077) --- 와일드카드 없이 정확히 한 경로.
    "e2e-reader" = <<-EOT
      path "kv/data/platform/authentik/e2e" { capabilities = ["read"] }
    EOT
  }
}

resource "vault_policy" "this" {
  for_each = local.policies

  name   = each.key
  policy = each.value
}
```

### 4.9 `infra/vault/roles.tf`

```hcl
# infra/vault/roles.tf — Kubernetes auth role 6개 (T044) = eso 4 + vault-backup + e2e-reader (tasks T044 "auth role 합계 6")
#
# 계약(contracts/gitops-repo.md :108-110): role 이름 = bound SA 이름 · audiences [vault] · token_ttl 1h · token_max_ttl 4h.
#   예외 1건: `e2e-reader`의 bound SA는 `kube-system/agent-view`(hostnames-and-access.md :79).
# 필드 주의:
#   - provider 필드 이름은 **`audience`(단수 문자열)**. 계약 문면의 "audiences: [vault]"는 개념 표기.
#   - token_ttl/token_max_ttl은 **초 단위 정수**(1h=3600, 4h=14400). 기본 32일 금지.
#   - `token_type = "service"` 명시 — ESO의 checkToken은 batch 토큰을 무효로 보고 즉시 실패 경로로 빠진다.
#   - `token_no_default_policy`는 쓰지 않는다(policies.tf 헤더). `alias_name_source` 미지정(기본 serviceaccount_uid).
#   - `bound_service_account_names`/`namespaces`에 `"*"`를 쓰지 않는다.
#   - e2e-reader 외 엔트리는 `sa` 키를 두지 않는다(role 이름 = SA 이름 규약을 코드로; 하네스 vt-9가 전수 대조).
# 확인 명령(부트스트랩 1회, VD-18):
#   kubectl create token vault-backup -n vault --audience vault --duration=10m | vault write -field=token auth/kubernetes/login role=vault-backup jwt=-

locals {
  roles = {
    "eso-platform" = { ns = "external-secrets" }
    "eso-dev"      = { ns = "external-secrets" }
    "eso-prod"     = { ns = "external-secrets" }
    "eso-data"     = { ns = "external-secrets" }
    "vault-backup" = { ns = "vault" }
    "e2e-reader"   = { ns = "kube-system", sa = "agent-view" }
  }
}

resource "vault_kubernetes_auth_backend_role" "this" {
  for_each = local.roles

  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = each.key
  bound_service_account_names      = [try(each.value.sa, each.key)]
  bound_service_account_namespaces = [each.value.ns]
  audience                         = "vault"
  token_policies                   = [each.key]
  token_ttl                        = 3600
  token_max_ttl                    = 14400
  token_type                       = "service"

  depends_on = [vault_policy.this]
}
```

### 4.10 `infra/vault/outputs.tf`

```hcl
# 출력에는 시크릿을 두지 않는다(accessor와 이름 목록뿐).
output "kv_mount_accessor" {
  description = "kv v2 마운트 accessor(ESO 디버깅·감사 로그 대조용)"
  value       = vault_mount.kv.accessor
}

output "kubernetes_auth_accessor" {
  description = "auth/kubernetes accessor"
  value       = vault_auth_backend.kubernetes.accessor
}

output "auth_role_names" {
  description = "생성된 Kubernetes auth role 이름(계약 대조용, 6개)"
  value       = sort(keys(local.roles))
}
```

### 4.11 `tests/infra/tofu.tests.ps1` 추가 단언 요약(20건, 헤더 41 → 61)

헤더 갱신: "infra/vault는 [tf-text] + 무자격 validate만 — plan 단언 없음(.claude/rules/infra.md의 하네스 예외는 infra/oci 읽기 전용 plan 하나뿐이며 넓히지 않는다)" · "infra/vault 단언은 정규식 텍스트 검사만 쓴다 — 중괄호 파서 기반 단언을 추가하지 않으므로 그 디렉터리의 heredoc은 허용" 두 줄 추가. `$vaultDir = Join-Path $repo 'infra/vault'`. `New-TfValidateCopy`·`run-platform-tests.ps1` 게이트 배열은 **무변경**.

| ID | 단언 |
|---|---|
| dir-3 | infra/vault contains *.tf |
| validate-vault-1 | `tofu init -backend=false` 무자격 임시 사본 성공 |
| validate-vault-2 | `tofu validate -json` valid=true (VAULT_ADDR·VAULT_TOKEN 없이) |
| vt-1 | versions.tf `source "hashicorp/vault"` + `~> 5.11.0`; lock에 `version = "5.11.0"` |
| vt-2 | backend.tf `key = "vault/terraform.tfstate"` · `use_lockfile = false` · `profile = "joshuatech-tfstate"` |
| vt-3 | vault_mount 정확히 1개, `path = "kv"`, `type = "kv-v2"` |
| vt-4 | `disable_iss_validation = true` 정확히 1회 |
| vt-5 | `token_reviewer_jwt` / `token_reviewer_jwt_wo` / `kubernetes_ca_cert` 0회 |
| vt-6 | `kubernetes_host = "https://kubernetes.default.svc:443"` |
| vt-7 | `local.roles` 키 집합 == {eso-platform, eso-dev, eso-prod, eso-data, vault-backup, e2e-reader} 정확히(그 외 0) |
| vt-8 | role 블록에 `audience = "vault"` · `token_ttl = 3600` · `token_max_ttl = 14400` · `token_type = "service"` |
| vt-9 | **bound SA/ns 전수 매핑**: eso-* 4개 ns `external-secrets` + `sa` 키 없음(= 이름 동일), vault-backup ns `vault` + `sa` 없음, e2e-reader `sa = "agent-view"` · ns `kube-system`; 그 외 `sa` 키 0 |
| vt-10 | `token_no_default_policy` 0회 · bound_* 값에 `"*"` 0회 |
| vt-11 | `local.roles`/`local.policies` 키·`role_name`·`vault_policy.name`에 `identity-admin` 없음; 파일 전체에 `pod-identity-admin` 0회(경로 주석의 `authentik/identity-admin`은 오탐 아님) |
| vt-12 | `local.policies` 키 집합 == `local.roles` 키 집합 |
| vt-13 | eso-data heredoc 안 `path "` 줄 정확히 20개, 집합이 기대 20경로(data 10 + metadata 10)와 순서 무관 완전 일치; `kv/data/dev/*`·`kv/data/prod/*`·`kv/(data|metadata)/\+/` 0회 |
| vt-14 | eso-* 4개·e2e-reader·vault-backup 정책의 모든 `capabilities` 가 정확히 `["read"]`(ordinal, **부분집합 아님**) |
| vt-15 | 리소스 타입 `vault_generic_secret` / `vault_kv_secret*` / `vault_audit` 0개 |
| vt-16 | e2e-reader path 정확히 `kv/data/platform/authentik/e2e` 1줄(와일드카드 없음) |
| vt-17 | vault-backup path 정확히 `sys/storage/raft/snapshot` 1줄(`snapshot-force` 0회) |

### 4.12 `docs/runbooks/vault-unseal.md` 목차

```
§0  범위·전제 — 모든 절차는 운영자 워크스테이션 vault CLI(컨테이너 exec 금지: 이미지에 openssl·ps 없음) · 도달 = admin kubeconfig
    port-forward svc/vault 18200:8200 + VAULT_ADDR=http://127.0.0.1:18200 · **UI로 init 하지 않는다** · vault login 금지 ·
    토큰은 $env:VAULT_TOKEN(Read-Host -AsSecureString)으로만 · 창 시작 체크리스트(SaveNothing · Transcript 없음 · 클립보드 기록 OFF) ·
    창 종료 체크리스트(Remove-Item Env:VAULT_TOKEN · Test-Path ~/.vault-token = False · tfplan 삭제) ·
    `/` Prefix Ingress → US4 전 Access + AOP가 유일 방어선
§1  정상 상태와 판정 — GET /v1/sys/seal-status(initialized:true · sealed:false · type:"ocikms") · vault_core_unsealed ·
    T044 실측값(recovery_seal·storage_type — 문서 단정 아님, VD-14)
§2  KMS 일시 장애 — **살아 있으면 그대로 둔다**(루트 키가 메모리) · 하지 말 것: 재시작·Shamir 전환·재init · **재시작 = CrashLoopBackOff**
    (sealed 대기가 아니다 — ADR/tasks 문면 정정) · ESO는 마지막 Secret 유지(기존 파드 정상, 신규·갱신만 멈춤) ·
    알림: VaultSealed(== 0) + MetricsAbsent(absent(vault_core_unsealed) 30m, FR-040 13번째)
§3  sealed/CrashLoop 진단 순서(판별표) — `logs --previous`의 `error parsing Seal configuration … failed key_id validation` →
    IMDS(169.254.169.254:80) → KMS/auth 엔드포인트 DNS(T010 NXDOMAIN 부정 캐시 선례) → OCI 콘솔 키 상태(Enabled/Pending Deletion) →
    동적 그룹 matching_rule(노드 A 인스턴스 OCID 1개 — 노드 재생성 시 tofu apply 선행) → 파드 배치(nodeSelector)
§4  root 토큰 취급 — 발급 = init 1회 · 사용 범위(audit enable · tofu apply · kv 시드) · 보관(비밀번호 관리자, T044 시점 revoke 안 함) ·
    revoke 절차(`vault token revoke -self`, PM 항목 `revoked YYYY-MM-DD` 표기·삭제 금지) · **전제**: 대체 관리 경로가 결정·실증된 뒤
    (설계 D4 · converge) · 정례 `tofu -chdir=infra/vault plan`(sys/auth sudo 필요)이 유일한 드리프트 그물
§5  break-glass — ⚠ Vault 2.0부터 sys/generate-root·sys/rekey는 recovery key 조각 **과 유효 토큰**을 함께 요구(ADR 0010 §6·FR-041 정정 후보) ·
    recovery key 2/3 generate-root 절차(OTP `-decode`)와 그 전제(유효 토큰 존재) · 채택하지 않은 대안 enable_unauthenticated_access(DoS 표면) ·
    인증 방식은 OpenTofu로만 변경, CLI disable 금지
§6  KMS 키 삭제/분실 = 복구 불능 — **Pending Deletion 즉시** 접근 불능, 30일은 취소 창(7–30일) — "삭제 유예 30일" 정정 ·
    prevent_destroy 가치 · 회전은 이전 버전으로 계속 복호화(재래핑 강제 아님) · Community 2.0.4에 seal-rewrap 없음
§7  Raft 스냅샷 복원 — 버킷 vault/ 내려받기 → `age -d -i <개인키>` → `vault operator raft snapshot restore -force <snap>` ·
    -force는 정합성 검사 우회일 뿐 **같은 KMS 키 필수** · restore 반환 ≠ 완료 · snapshot **update** 권한 필요(§4·§5 경로) ·
    복원 뒤 recovery key 유효성 미검증(VD-24, T048 이후)
§8  Shamir 비상 마이그레이션(research VAULT-D10) — seal 블록 `disabled = true` → 재기동 → `vault operator unseal -migrate` · 단일 노드 = 계획 다운타임
§9  감사 장치 장애(fail-closed) — stdout 하나뿐이라 쓰기 실패 = 모든 API 요청 거부 · 증상(전 요청 실패·ESO 정지·백업 실패) ·
    노드 A df -h·kubelet 로그 · 조기 경보 NodeDiskLow(FR-040)
§10 설정 변경 규율(OnDelete) — PR 머지만으로 미반영(Argo Synced/Healthy) · `kubectl -n vault delete pod vault-0` · config-checksum 어노테이션
§11 PVC·PV·되돌리기 — data-vault-0은 Argo 밖(고아 경고 1건 정상) · 어노테이션은 표식 · **PVC 삭제 = local-path PV 데이터 소멸** ·
    되돌리기 순서 ①Ingress ②STS orphan ③Pod ④나머지 ⑤PVC/PV 제외 · PDB 없음(drain 가능)
§12 e2e-reader 토큰(T077) — 운영자 `kubectl create token agent-view -n kube-system --audience vault --duration=1h` → env → login role=e2e-reader →
    `vault read kv/data/platform/authentik/e2e`(kv get 아님)
§13 관련 문서 — bootstrap.md §4 · gitops platform/vault/README.md · ADR 0010 · (T114 secret-rotation·incident-response)
```

### 4.13 `docs/runbooks/bootstrap.md` §4 T044 절 항목(§3 T043 형식)

1. **설계** — 이 문서 참조 · 채택안(설계안 2 기반) · 결정 D1–D9 요약
2. **코드** — G1 PR 번호·커밋 3개(platform/vault · AppProject · seal 3값) · M0/M1/M2 커밋 해시
3. **사용자 결정** — D4(root 보관, break-glass 공백 인계) · D7(OCID 공개 게재 승인 시각) · D8(8경로) · D9(편차 3건)
4. **게이트·실측** — 단계별 기대값/실제값: 사전 확인 7종 결과(CLI 버전 · 클립보드 · DNS A 레코드 · 스왑 · SC reclaim · env 파일 · 타이머) · 렌더 10장 · gitleaks exit · G1 머지 시각 · `initialized:false` 확인 시각 → init 시각 → `initialized:true` 시각(**경과 시간**) · 전사 검증(해시 3/3 · PM 사본 lookup) · audit 활성 시각 · 재기동 리허설 초 · plan add/change/destroy · 로그인 스모크 · capabilities · 플레이스홀더 8경로 + 투입 시각 · env 삭제 시각 · 수동 백업 exit·오브젝트 키 · `--pre-upgrade` exit 0 · 하네스 PASS 목록 · UI 도달 · seal-status 실제 필드(recovery_seal 등)
5. **git 밖 라이브 상태** — Vault 초기화 사실 · recovery 3/2 · root 토큰 보관 위치 **참조**(값 아님) · 감사 장치 file/ · `/etc/platform-backup/env` 삭제 · kv 플레이스홀더 8건 · `kv/{env}/openfga/preshared` = `kv/platform/openfga/preshared` 불변식(US6)
6. **절차 메모** — PowerShell 함정(인자 따옴표 · `-AsSecureString`) · 창 시작/종료 체크리스트 · `key=-` 다중 사용 금지 · 노드 A 내부 `--resolve` 판정
7. **미확인·인계** — VD-14·VD-19·VD-24 · 문면 편차 3건 · 문면 정정 3건(sealed 대기 / 삭제 유예 30일 / break-glass 토큰 요구) · T045 revoke 전 D4 결론 필요

---

## 5. 운영자 적용 순서

표기: **[사용자 재확인]** = 단계 시작 전 사용자 승인 · 명령은 PowerShell 7(워크스테이션) / `ssh ssh-a "…"`(노드 A, sudo) · 대기·게이트·되돌리기·라이브 영향은 각 단계에.

**창 시작 체크리스트(모든 새 PowerShell 창의 첫 줄 — 단계 8·12·17에서 창을 새로 열 때마다)**
```powershell
Set-PSReadLineOption -HistorySaveStyle SaveNothing
if ($Transcript) { throw 'Start-Transcript 활성 — 이 창을 쓰지 않는다' }
(Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory   # 1이면 클립보드 경유 금지
```
**창 종료 체크리스트**
```powershell
Remove-Item Env:VAULT_TOKEN, Env:VAULT_ADDR -ErrorAction SilentlyContinue
Remove-Item D:\code\joshuatech_ver2\infra\vault\t044.tfplan -ErrorAction SilentlyContinue
Test-Path "$env:USERPROFILE\.vault-token"    # False
```

### 단계 0 — 사용자 결정 + 사전 확인 7종 **[사용자 재확인: D4·D7·D8·D9]**
- 누가: user + operator
- 명령:
```powershell
winget show --id Hashicorp.Vault --versions                       # VD-01: 2.0.4 있으면 winget install --id Hashicorp.Vault --exact --version 2.0.4
# 없으면 zip https://releases.hashicorp.com/vault/2.0.4/vault_2.0.4_windows_amd64.zip + SHA256 5e6357e52f75657f9a51f2655d42811b8b129166402ecf2d2dc630ffcd3c8d8f
vault version
(Get-ItemProperty HKCU:\Software\Microsoft\Clipboard -ErrorAction SilentlyContinue).EnableClipboardHistory   # VD-02
nslookup auth.ap-chuncheon-1.oraclecloud.com                      # VD-05 (+ tofu output 호스트 2개 — 운영자)
kubectl get sc local-path -o jsonpath='{.reclaimPolicy} {.volumeBindingMode}{"\n"}'                          # VD-04
kubectl -n kube-system get cm local-path-config -o jsonpath='{.data.setup}'
ssh ssh-a "swapon --show; free -h | head -2"                      # VD-06
ssh ssh-a "cat /etc/platform-backup/env 2>/dev/null; systemctl list-timers platform-backup.timer --no-pager"   # VD-07
```
- 게이트: `Vault v2.0.4` · EnableClipboardHistory ≠ 1(1이면 단계 9는 화면 전사) · DNS A 레코드가 10/8·172.16/12·192.168/16에 **0개** · 스왑 0 · SC reclaim 기록 · 다음 SUC 창(2026-09-20 03:00 KST)까지 단계 7–14를 **한 세션**으로 끝낼 시간 확보. 하나라도 실패하면 T044를 시작하지 않는다.
- 되돌리기: 없음(읽기 전용). 라이브 영향: 없음.

### 단계 1 — M0 계약 커밋(gitops보다 먼저)
- 누가: controller · repo: joshuatech_ver2
- 파일: `specs/003-platform-foundation/contracts/hostnames-and-access.md` :79 부근에 한 줄 — "e2e-reader 토큰은 운영자가 E2E 세션 직전 `kubectl create token agent-view -n kube-system --audience vault --duration=1h`으로 발급해 tester에 env로 전달한다(agent-view에는 serviceaccounts/token create가 없다); 읽기는 `vault read kv/data/platform/authentik/e2e`."
- 명령: `pwsh -NoProfile -File tests/run-all.ps1` → 커밋 `docs(003-platform-foundation): e2e-reader 토큰 발급 절차 계약 명시 (T044 M0)`
- 게이트: run-all 녹색 · gitops-repo.md·tasks·plan·spec 무변경(role 6 그대로).
- 되돌리기: revert. 라이브 영향: 없음.

### 단계 2 — G1 파일 작성(자리표시자, 커밋 금지)
- 누가: builder · repo: platform-gitops
- 파일: `platform/vault/{kustomization.yaml, ingress.yaml, serviceaccount-vault-backup.yaml, README.md}`(§4.1–4.3 전문) · `clusters/oci-k3s/projects/platform.yaml`(sourceRepos hashicorp 줄 삭제)
- 게이트: seal 3값이 `<OPERATOR-FILL: …>` · `grep -rn 'ocid1\.' platform/vault/` 0건 · yq로 `name: vault`·`version: 0.34.1`·`releaseName: vault`·`namespace: vault` 읽힘 · 전역 `namespace:` 변환기 없음. builder는 커밋하지 않는다(컨트롤러가 파일 이름으로 스테이징 — T043 교훈).
- 되돌리기: 파일 삭제. 라이브 영향: 없음.

### 단계 3 — G1 커밋 2개 + draft PR + gitleaks
- 누가: controller
```powershell
git -C D:/code/platform-gitops switch -c t044-vault
git -C D:/code/platform-gitops add platform/vault/kustomization.yaml platform/vault/ingress.yaml platform/vault/serviceaccount-vault-backup.yaml platform/vault/README.md
git -C D:/code/platform-gitops commit -m "feat(vault): Vault 2.0.4 helm 인플레이트 + Ingress + SA vault-backup (T044)"
git -C D:/code/platform-gitops add clusters/oci-k3s/projects/platform.yaml
git -C D:/code/platform-gitops commit -m "chore(argocd): AppProject platform sourceRepos에서 hashicorp helm repo 제거 (T044, D7 규칙)"
gitleaks dir D:/code/platform-gitops --no-banner --redact --exit-code 1      # VD-09
gh pr create --draft --repo joshua92y/platform-gitops --title "T044 Vault 배포" --body-file <본문>
```
- 게이트: gitleaks exit 0 · PR 본문 체크박스 `[ ] seal 3값 채움(운영자) [ ] 렌더 10장 검증 [ ] init 가능 시각 확인` · 첫 줄 "머지 = argo-1 FAIL 창 + SUC 게이트 시작 · **UI로 init 하지 않는다**".
- 되돌리기: 브랜치 삭제. 라이브 영향: 없음(draft).

### 단계 4 — seal 3값 채움 + 렌더 검증 **[사용자 재확인: public 저장소 게재(D7)]**
- 누가: user + operator
```powershell
$env:AWS_REQUEST_CHECKSUM_CALCULATION='when_required'
tofu -chdir=D:/code/joshuatech_ver2/infra/oci output -raw kms_key_id
tofu -chdir=D:/code/joshuatech_ver2/infra/oci output -raw kms_crypto_endpoint
tofu -chdir=D:/code/joshuatech_ver2/infra/oci output -raw kms_management_endpoint
# 세 값을 <OPERATOR-FILL: …> 자리에 붙여 넣는다
grep -rn 'ocid1\.' D:/code/platform-gitops                           # platform/vault/kustomization.yaml 안에서만 히트
git -C D:/code/platform-gitops commit -am "chore(vault): seal ocikms 식별자 3값 투입 (T044, 운영자)"
gitleaks dir D:/code/platform-gitops --no-banner --redact --exit-code 1
kustomize build --enable-helm D:/code/platform-gitops/platform/vault | yq -N '.kind + " " + .metadata.name'   # VD-08 (helm 필요)
kustomize build --enable-helm D:/code/platform-gitops/platform/vault | Select-String 'image:|Delete=false|namespaceSelector'
```
- 게이트: `key_id`가 `ocid1.key.oc1.ap-chuncheon-1.`로, 엔드포인트가 `https://…-crypto.kms.`/`…-management.kms.`로 시작 · OCID 히트가 `platform/vault/kustomization.yaml` 뿐(테넌시·컴파트먼트·사용자 OCID 0) · gitleaks exit 0(잡히면 같은 PR에 `.gitleaks.toml` allowlist + README 근거) · 렌더 **10장** = ServiceAccount vault · ClusterRoleBinding · Role · RoleBinding · ConfigMap vault-config · Service vault · Service vault-internal · StatefulSet · Ingress · ServiceAccount vault-backup(injector/csi/webhook/PDB/active/standby/NetworkPolicy/vault-ui **0**) · `image: hashicorp/vault:2.0.4@sha256:5be4…` 1줄 · `Delete=false,Prune=false` 1회.
- 되돌리기: 커밋 revert(미머지 브랜치). 라이브 영향: 없음. helm 부재 시 이 게이트는 fail-closed → VD-08 결정(1회 설치 권고).

### 단계 5 — M1 작성(infra/vault + tofu.tests, 커밋 금지)
- 누가: builder · repo: joshuatech_ver2 · 파일: `infra/vault/{versions,backend,providers,main,policies,roles,outputs}.tf` · `tests/infra/tofu.tests.ps1`(§4.11)
- 게이트: §4.4–4.10 전문 일치 · `rg -c 'token_no_default_policy|token_reviewer_jwt|kubernetes_ca_cert|vault_audit' infra/vault` 0 · `disable_iss_validation = true` 1건 · eso-data `path "` 20줄 · run-platform-tests.ps1 무변경.

### 단계 6 — M1 커밋 + 무자격 하네스
- 누가: controller
```powershell
tofu -chdir=D:/code/joshuatech_ver2/infra/vault init -backend=false      # lock 생성 전용
git -C D:/code/joshuatech_ver2 add infra/vault/versions.tf infra/vault/backend.tf infra/vault/providers.tf infra/vault/main.tf infra/vault/policies.tf infra/vault/roles.tf infra/vault/outputs.tf infra/vault/.terraform.lock.hcl tests/infra/tofu.tests.ps1
git -C D:/code/joshuatech_ver2 commit -m "feat(003-platform-foundation): infra/vault kv·k8s auth·정책 6·role 6 + tofu 단언 20 (T044 M1)"
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/run-all.ps1
```
- 게이트: run-all 전 슬롯 PASS · lock에 `version = "5.11.0"`·`constraints = "~> 5.11.0"` · validate-vault-1/2 PASS · vt-1~17 PASS. `.terraform/`은 커밋하지 않는다.
- 되돌리기: revert. 라이브 영향: 없음.

━━ 여기부터 라이브 — 단계 7–14는 **한 운영자 세션**(SUC 창 2026-09-20 03:00 KST 전) ━━

### 단계 7 — G1 머지 → vault-0 기동 **[사용자 재확인: init 명령을 칠 준비가 된 시각인가]**
- 누가: user + operator
```powershell
gh pr ready <번호>; gh pr merge <번호> --squash --repo joshua92y/platform-gitops
$t0 = Get-Date   # 기록: 머지 시각
kubectl --kubeconfig $env:AGENT_VIEW_KUBECONFIG -n vault get pods -o wide -w
kubectl -n argocd get app platform-vault -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
kubectl --kubeconfig $env:AGENT_VIEW_KUBECONFIG -n vault logs vault-0 --tail=100 | Select-String 'Seal Type|ocikms|error|x509|IMDS'   # VD-10
kubectl --kubeconfig $env:AGENT_VIEW_KUBECONFIG -n vault get pvc data-vault-0 -o jsonpath='{.metadata.annotations}{"\n"}'
kubectl --kubeconfig $env:AGENT_VIEW_KUBECONFIG -n vault get sts vault -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'   # VD-12
kubectl get mutatingwebhookconfigurations | Select-String vault; kubectl -n vault get pdb,networkpolicy                             # VD-13
```
- 대기: 파드 Running까지(이미지 pull 포함 수 분).
- 게이트: vault-0 노드 A(`role=platform`)에서 **Running 0/1**(readiness = `vault status` exit 2) · Application `Synced Progressing`(Degraded 아님) · 로그에 `Seal Type: ocikms` 1회 + 오류 0줄 · PVC 어노테이션 존재 · image 문자열 digest 병기 · MutatingWebhookConfiguration 0 · ns vault PDB 0 · NetworkPolicy는 platform/policies 소유분만. **CrashLoopBackOff면 즉시 중단** → 런북 §3 순서(seal 3값 오타 → IMDS → DNS → IAM)로 분기, init으로 넘어가지 않는다. `ImagePullBackOff`면 태그만으로 폴백 PR(D6).
- 되돌리기(순서 고정): revert 머지 → ① `kubectl -n vault delete ingress vault` → ② `kubectl -n vault delete sts vault --cascade=orphan` → ③ `kubectl -n vault delete pod vault-0` → ④ Service·ConfigMap·SA·RBAC 수동 정리 → ⑤ **PVC `data-vault-0`·PV 제외**.
- 라이브 영향: ⏱ **두 시계 시작** — (a) `argo-1`(20/20 Healthy) FAIL = init까지 예정된 적색 창(root app-of-apps Healthy 상실, wave 10 정지 → `clusters/oci-k3s/apps/` PR 머지 금지) (b) `svc vault` 존재 → `--pre-upgrade`가 vault 스냅샷 필수 승격 → 단계 12까지 prepare 실패. 세션이 창을 넘길 위험이 생기면 **즉시** `kubectl label node <A> <B> plan.upgrade.cattle.io/k3s-server=disabled plan.upgrade.cattle.io/k3s-agent=disabled`(단계 14에서 제거).

### 단계 8 — port-forward + init 전 사전 점검
- 누가: operator (새 창 → 창 시작 체크리스트)
```powershell
# 별도 창(admin kubeconfig): kubectl -n vault port-forward svc/vault 18200:8200
$env:VAULT_ADDR = 'http://127.0.0.1:18200'
curl.exe -s -o NUL -w "%{http_code}`n" http://127.0.0.1:18200/v1/sys/seal-status      # VD-11
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status
vault operator init "-status"; $LASTEXITCODE                                           # VD-03
```
- 게이트: HTTP **200**(400이면 XFF 거절 — 설계 위반, 중단) · `type:"ocikms"` · `initialized:false` · `sealed:true`(**이 시각 기록** — 단계 9와의 경과 시간을 §4에 남긴다) · `init -status` exit **2**(0이면 이미 초기화됨 → 중단, 사고 처리: 브라우저 init 가능성 전제).
- 되돌리기: port-forward 종료. 라이브 영향: 읽기 전용(CRI 스트리밍 loopback — NetworkPolicy 미경유).

### 단계 9 — ⭐ `vault operator init` — **사용자 입회** · 3단 전사
- 누가: user + operator · 전제: 단계 0 VD-02(클립보드 기록 OFF)가 PASS일 때만 클립보드 경로, 아니면 화면 직접 전사.

**(1) 실행·전사** — 파일 리다이렉트 금지, 변수에만:
```powershell
$init = vault operator init "-recovery-shares=3" "-recovery-threshold=2" "-format=json" | ConvertFrom-Json
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status                    # initialized:true · sealed:false · type:ocikms (VD-14: recovery_seal 등 실제값 기록)
# 비밀번호 관리자에 항목 4개(각각 별도: "T044 vault recovery 1/3 (threshold 2)", 2/3, 3/3, "T044 vault root token — revoke 예정 T045 시드 뒤"):
$init.recovery_keys_b64[0] | Set-Clipboard   # → 붙여넣기 → 저장
$init.recovery_keys_b64[1] | Set-Clipboard   # → 붙여넣기 → 저장
$init.recovery_keys_b64[2] | Set-Clipboard   # → 붙여넣기 → 저장
$init.root_token           | Set-Clipboard   # → 붙여넣기 → 저장
```
**(2) 검증 — 이 게이트를 통과하기 전에는 `$init`을 지우지도, 창을 닫지도 않는다** (bootstrap.md:182 ⑥ 교훈):
```powershell
$h = { param($s) [BitConverter]::ToString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($s))) }
# 비밀번호 관리자를 닫았다가 다시 열어, 저장된 항목에서 하나씩 복사해 온다(메모리 값이 아니라 **되가져온 값**을 대조):
0..2 | ForEach-Object { "recovery $_ : " + ((& $h $init.recovery_keys_b64[$_]) -eq (& $h (Get-Clipboard))) }   # 각 키를 PM에서 복사한 직후 실행 → True 3회
$env:VAULT_TOKEN = (Read-Host -AsSecureString 'root token from PM' | ConvertFrom-SecureString -AsPlainText)   # PM 사본을 붙여넣기
vault token lookup | Select-String 'policies|ttl'                                                             # policies [root] 성공
```
**(3) 소거** — (2)의 True 3/3 + lookup 성공 뒤에만:
```powershell
Set-Clipboard -Value ' '; Remove-Variable init, h
Test-Path "$env:USERPROFILE\.vault-token"    # False (vault login을 쓰지 않았다)
```
- 게이트: `initialized:true`·`sealed:false`·`type:"ocikms"` · **해시 일치 3/3** · **PM 사본 root 토큰으로 `vault token lookup` 성공(policies root)** · 사용자가 항목 4개 저장을 구두 확인 · `~/.vault-token` False · 단계 8의 `initialized:false` 시각 → 지금 시각의 **경과 시간 기록**(수 분 초과 또는 already-initialized 거부 시 중단·사고 처리). 여기까지가 '사용자 입회' 구간이다.
- 되돌리기: **없음**(init 불가역; 재init = PVC 삭제 = 시드 전부 재투입). 실패(sealed 유지·CrashLoop) 시 뒤 단계로 진행하지 않는다.
- 라이브 영향: vault-0 Ready → Application Healthy → **argo-1 적색 창 종료**. recovery key는 unseal 수단이 아니며 2.0에서는 generate-root에도 토큰이 필요하다.

### 단계 10 — 감사 장치(CLI 1회) — tofu write보다 먼저
- 누가: operator
```powershell
vault audit enable file file_path=stdout
vault audit list -detailed
kubectl --kubeconfig $env:AGENT_VIEW_KUBECONFIG -n vault logs vault-0 --tail=20 | Select-String '"type":"request"'   # VD-15
```
- 게이트: `file/` 1개 · 감사 JSON ≥1행(값은 HMAC-SHA256).
- 되돌리기: `vault audit disable file/`(단, 감사 없이 진행하지 않는다). 라이브 영향: 단일 stdout 장치 = fail-closed(노드 A 디스크 포화 = 전 요청 거부, 런북 §9).

### 단계 11 — auto-unseal 재기동 리허설
- 누가: operator
```powershell
kubectl -n vault delete pod vault-0
kubectl --kubeconfig $env:AGENT_VIEW_KUBECONFIG -n vault get pod vault-0 -w
# port-forward 재수립(별도 창) 후
curl.exe -s http://127.0.0.1:18200/v1/sys/seal-status                                                                # VD-17
kubectl --kubeconfig $env:AGENT_VIEW_KUBECONFIG -n vault get events --field-selector involvedObject.name=vault-0 | Select-String FailedPreStopHook
```
- 대기: 90–180초.
- 게이트: `sealed:false`·`type:ocikms`·`initialized:true` · 파드 1/1 Running · 같은 PVC 재부착. `FailedPreStopHook`이 보이면 무해(SIGKILL, raft 크래시 세이프)이나 기록·`server.preStop` 대체 검토.
- 되돌리기: 없음(재생성). sealed/CrashLoop이면 **즉시 중단** — 백업·kv·T045로 진행하지 않고 §3 순서 진단.
- 라이브 영향: 30–90초 Vault 무응답(소비자 없음 — ESO는 T045).

### 단계 12 — `infra/vault` init/plan/apply + 인증 스모크
- 누가: operator (VAULT_TOKEN은 단계 9 (2)에서 env에만; 새 창이면 `Read-Host -AsSecureString`로 재입력)
```powershell
$env:AWS_REQUEST_CHECKSUM_CALCULATION='when_required'; tofu -chdir=D:/code/joshuatech_ver2/infra/vault init
tofu -chdir=D:/code/joshuatech_ver2/infra/vault plan -out=t044.tfplan
tofu -chdir=D:/code/joshuatech_ver2/infra/vault show -json t044.tfplan | Select-String '"actions"' | Measure-Object   # 파이프로만(파일 저장 금지)
tofu -chdir=D:/code/joshuatech_ver2/infra/vault apply t044.tfplan
tofu -chdir=D:/code/joshuatech_ver2/infra/vault state pull | Select-String 'BEGIN (RSA |EC |)PRIVATE KEY|eyJhbGciOi|AGE-SECRET-KEY'   # VD-23: 0행
vault secrets list; vault auth list; vault list auth/kubernetes/role; vault policy list
vault read auth/kubernetes/role/eso-data; vault policy read eso-data; vault read auth/kubernetes/config
# 스모크(토큰 리터럴 없이 파이프→변수):
$tb = (kubectl create token vault-backup -n vault --audience vault --duration=10m | vault write -field=token auth/kubernetes/login role=vault-backup jwt=-)   # VD-18
vault token capabilities $tb sys/storage/raft/snapshot; vault token capabilities $tb sys/storage/raft/snapshot-force
$te = (kubectl create token agent-view -n kube-system --audience vault --duration=10m | vault write -field=token auth/kubernetes/login role=e2e-reader jwt=-)   # admin kubeconfig
vault token capabilities $te kv/data/platform/authentik/e2e; vault token capabilities $te sys/internal/ui/mounts/kv                                        # VD-19
foreach ($t in $tb,$te) { $env:VAULT_TOKEN_TMP=$t; vault token revoke -self 2>$null }; Remove-Variable tb, te; Remove-Item Env:VAULT_TOKEN_TMP -ErrorAction SilentlyContinue
```
  (주: `vault token revoke -self`는 현재 `VAULT_TOKEN`(root)을 쓰므로 스모크 토큰은 `vault token revoke $tb` / `vault token revoke $te`로 root 권한에서 폐기한다 — 위 foreach 대신 이 형태를 쓴다.)
- 게이트: plan **15 to add / 0 change / 0 destroy** · role 6 · policy 6(+default/root) · `eso-data`: bound SA `eso-data`/ns `external-secrets`·audience vault·token_ttl 1h·max 4h · `policy read eso-data` 20줄, env 와일드카드 0 · `auth/kubernetes/config`에 `kubernetes_host`만, `token_reviewer_jwt` 비어 있음 · state pull 비밀 패턴 0행 · vault-backup 로그인 성공(= kubernetes_host·TokenReview·iss·audience 4자 정합) · `snapshot` = read, `snapshot-force` = deny · e2e-reader `kv/data/platform/authentik/e2e` = read, `sys/internal/ui/mounts/kv` = deny(→ tester는 `vault read`) · `.terraform.lock.hcl` 커밋됨.
- 되돌리기: 잘못된 role/정책은 코드 수정 후 재apply(0 destroy 원칙). kv 마운트 삭제 금지. 상태는 버킷 버저닝.
- 라이브 영향: kv v2 마운트·kubernetes auth·정책·role 생성. **이 시점부터 SUC pre-upgrade 게이트가 통과 가능**(단계 14에서 확정).

### 단계 13 — US6 플레이스홀더 8경로(리터럴 한 형태)
- 누가: operator
```powershell
foreach ($e in 'dev','prod') {
  vault kv put "kv/$e/authentik/identity-admin" client_id="PLACEHOLDER-T044-$e-authentik-identity-admin-20260914" client_secret="PLACEHOLDER-T044-$e-authentik-identity-admin-20260914" jwks_url="PLACEHOLDER-T044-$e-authentik-identity-admin-20260914" issuer="PLACEHOLDER-T044-$e-authentik-identity-admin-20260914" api_token="PLACEHOLDER-T044-$e-authentik-identity-admin-20260914"
  vault kv put "kv/$e/authentik/webhooks/identity-admin" secret="PLACEHOLDER-T044-$e-authentik-webhooks-identity-admin-20260914"
  vault kv put "kv/$e/openfga/store_id" store_id="PLACEHOLDER-T044-$e-openfga-store_id-20260914"
  vault kv put "kv/$e/openfga/preshared" key="PLACEHOLDER-T044-$e-openfga-preshared-20260914"
}
vault kv list kv/dev/authentik; vault kv list kv/prod/authentik/webhooks; vault kv list kv/dev/openfga; vault kv list kv/prod/openfga
```
- 게이트: 8경로 존재, 값이 `PLACEHOLDER-T044-`로 시작. 실값은 **절대** 이 형태(명령줄 리터럴)로 넣지 않는다 — 런북의 실값 예시는 별도 블록에 전체 JSON stdin(`Get-Content secret.json | vault kv put <path> -`) 또는 키당 1회 호출로만 적고 `key=-` 다중 사용은 예시에서 없앤다.
- 되돌리기: `vault kv metadata delete kv/<path>`. 라이브 영향: 없음(소비자 US6). 기록: 투입 시각 + preshared 불변식(D8).

### 단계 14 — 백업 연결 + SUC 게이트 확정
- 누가: operator
```powershell
ssh ssh-a "cat /etc/platform-backup/env"                                             # VD-07
ssh ssh-a "sudo rm -f /etc/platform-backup/env && sudo systemctl cat platform-backup.service | grep EnvironmentFile"
ssh ssh-a "sudo /usr/local/bin/platform-backup.sh --components vault; echo exit=$?"
ssh ssh-a "cat /var/lib/node_exporter/textfile_collector/platform_backup_vault.prom"
oci --profile svc-verify os object list --bucket-name joshuatech-backup-platform --prefix vault/ --query 'data[].{name:name,time:"time-created"}'   # VD-22
ssh ssh-a "sudo /usr/local/bin/platform-backup.sh --pre-upgrade; echo exit=$?"
ssh ssh-a "systemctl list-timers platform-backup.timer --no-pager"
# 단계 7에서 disabled 라벨을 붙였다면: kubectl label node <A> <B> plan.upgrade.cattle.io/k3s-server- plan.upgrade.cattle.io/k3s-agent-
```
- 게이트: 수동 백업 exit 0 · `platform_backup_last_success_timestamp{component="vault"}` 갱신 · 버킷 `vault/`에 `vault-<UTC>.snap.age` 1건(비-.age 0) · **`--pre-upgrade` exit 0** · 다음 타이머 02:30 KST.
- 되돌리기: env 파일 재생성(`BACKUP_COMPONENTS=k3s`) — 단 pre-upgrade는 env와 무관하게 vault를 요구하므로 근본 해결 아님.
- 라이브 영향: 일 1회 Raft 스냅샷 시작. ⏱ SUC 시계 종료.

### 단계 15 — 라이브 하네스 재측정
- 누가: controller (agent-view)
```powershell
$env:KUBECONFIG='<agent-view kubeconfig>'; pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/platform/run-platform-tests.ps1
```
- 게이트: vault-1(sealed=false) · vault-2(ocikms) · argo-1(20/20) · np-4 · ingress vault-2 · backup-2/3 PASS. argo-4는 ns vault PVC 어노테이션까지(전체 PASS는 T046+ 공동). 실패 시 런북 §3 판별표.
- 라이브 영향: 읽기 전용.

### 단계 16 — Ingress·UI 도달(VD-21)
- 누가: operator
```powershell
kubectl -n vault get ingress
ssh ssh-a "curl -s -o /dev/null -w '%{http_code}\n' --resolve vault.joshuatech.dev:443:10.0.7.78 https://vault.joshuatech.dev/ui/"
curl.exe -s -o NUL -w "%{http_code}`n" https://vault.joshuatech.dev/
ssh ssh-a "curl -s -o /dev/null -w '%{http_code}\n' --resolve vault.joshuatech.dev:443:10.0.7.78 https://vault.joshuatech.dev/__probe-404"   # 액세스 로그 TLSClientSubject 확인용
```
- 게이트: 노드 A 내부 200/307 · edge 302(Access) · 브라우저에서 **Vault UI 로그인 화면 렌더까지가 합격선**(OIDC는 US4 뒤 — 오판 금지) · 액세스 로그 `TLSClientSubject=CN=origin-pull.cloudflare.net`.
- 되돌리기: `kubectl -n vault delete ingress vault`. 라이브 영향: UI가 Access + AOP 뒤에서 공개(`/v1/*` 포함).

### 단계 17 — 세션 정리 + root 토큰 보관 확인 **[사용자 재확인: revoke는 하지 않는다(D4)]**
- 누가: user + operator
```powershell
Remove-Item Env:VAULT_TOKEN, Env:VAULT_ADDR -ErrorAction SilentlyContinue
Remove-Item D:\code\joshuatech_ver2\infra\vault\t044.tfplan -ErrorAction SilentlyContinue
Test-Path "$env:USERPROFILE\.vault-token"     # False
# port-forward 창 종료
```
- 게이트: env 0 · `.vault-token` False · tfplan 없음 · 비밀번호 관리자 root 항목에 "revoke 예정: T045 시드 완료 뒤 · 전제 = D4 결정" 메모. **T044에서 root를 revoke하지 않는다**(tasks 문면·ADR ⑤→⑥).
- 라이브 영향: 없음.

### 단계 18 — M2 문서
- 누가: builder · 파일: `docs/runbooks/vault-unseal.md`(신규, §4.12) · `docs/runbooks/bootstrap.md` §4(§4.13) · `docs/README.md` 행 · `infra/bootstrap/platform-backup.sh` 헤더 :40·:44-45·:56-58(+절차 3 분기)
- 게이트: `pwsh -NoProfile -File tests/run-all.ps1` 녹색 · platform-backup 슬롯 76 단언 PASS(코드 텍스트 불변).

### 단계 19 — 커밋 + tasks 체크박스 + 인계
- 누가: controller
```powershell
git -C D:/code/joshuatech_ver2 add docs/runbooks/vault-unseal.md docs/README.md docs/runbooks/bootstrap.md infra/bootstrap/platform-backup.sh
git -C D:/code/joshuatech_ver2 commit -m "docs(003-platform-foundation): vault-unseal 런북 + bootstrap §4 T044 실행 기록 (T044 M2)"
git -C D:/code/joshuatech_ver2 add specs/003-platform-foundation/tasks.md
git -C D:/code/joshuatech_ver2 commit -m "chore(003-platform-foundation): T044 완료 표시"
```
- 게이트: tasks.md는 `[X]`만 · §9의 편차 3건·정정 3건이 bootstrap §4 '미확인·인계'와 report 초안에 기록.

**비밀 취급 요약(전 단계 공통)**: 비밀은 명령줄 리터럴로 쓰지 않는다(파이프 → 변수 / `Read-Host -AsSecureString`) · 파일 리다이렉트 금지 · `vault login` 금지 · 창마다 시작/종료 체크리스트 · plan JSON을 `%TEMP%`에 쓰지 않는다 · init 출력은 3단(전사→검증→소거).

---

## 6. 위험·차단 시나리오

| # | 시나리오 | 출처 | 설계 반영 | 상태 |
|---|---|---|---|---|
| 1 | init 출력 유실(클립보드 미저장 → PM 비어 있음 → 소거) — 2.0에서는 복구 불가 | 비평 1 blocker / bootstrap.md:182 ⑥ | 단계 9 3단 분리: 해시 3/3 + PM 사본 토큰 `lookup` 성공 뒤에만 소거 | 반영 |
| 2 | 7번째 role `vault-admin` = tasks:123·ADR:33·FR-041 동시 위반 | 비평 2 blocker | role 6만. break-glass 공백은 D4 미해결 항목 + converge | 반영(공백은 **미해결** 명시) |
| 3 | T044 내 root revoke = tasks 문면("오프라인 보관")·ADR ⑤→⑥ 위반 + T045 시드 차단 | 비평 2 blocker | revoke 단계 삭제, 단계 17에서 보관만 | 반영 |
| 4 | vault-admin SA 부재로 관리 경로 실재하지 않음 | 비평 1·2 major | role 자체를 만들지 않으므로 해소 | 반영(moot) |
| 5 | root/vault-admin 토큰 명령줄 리터럴 → 히스토리 잔존(창별 SaveNothing 미적용) | 비평 1 major | 리터럴 0 · 파이프/`-AsSecureString` · 창 시작/종료 체크리스트 · 스모크 토큰 변수도 정리 | 반영 |
| 6 | SUC `--pre-upgrade` 창: `svc vault` ~ role `vault-backup` 사이가 길어짐 | 비평 1 major | M1을 머지 전(단계 5–6) 완성 · 단계 7–14 한 세션 · 창 위험 시 disabled 라벨 필수 | 반영 |
| 7 | KMS OCID public 게재 단계가 operator 단독 | 비평 1 major | 단계 4 `user+operator` + D7 사용자 결정 + OCID grep 게이트 | 반영 |
| 8 | eso-* metadata `list` = 계약 초과 권한 | 비평 2 major | `["read"]`만, vt-14 정확 일치 | 반영 |
| 9 | 단언 `⊆{read,list}`가 이탈을 못 잡음 | 비평 2 major | vt-13 20경로 집합 동등(data+metadata) · vt-14 정확 일치 · vt-16/17 1줄 | 반영 |
| 10 | bound SA/ns 오타가 정적 하네스 통과 | 비평 2 major | vt-9 전수 매핑 + `sa` 키 부재 단언 | 반영 |
| 11 | seal 설정 실패 = CrashLoop(sealed 대기 아님); 문면 오류 | 렌즈 2 | 단계 7 중단 조건 · 런북 §2·§3 정정 · converge | 반영 |
| 12 | XFF 스탠자로 전 경로 400 | 렌즈 1·4·5 | 미도입 + VD-11 200 게이트 | 반영 |
| 13 | PVC 어노테이션 첫 apply 누락(불변) | 렌즈 1·4 | valuesInline에 포함, 단계 4·7 게이트 | 반영 |
| 14 | argo-1 적색 창 중 `clusters/oci-k3s/apps/` PR 머지 → wave 10 정지 | 렌즈 5 | 단계 7 라이브 영향에 금지 명시 | 반영 |
| 15 | 초기화 전 UI 노출 창에서 제3자/브라우저 init | 비평 1 nit | 머지 시각 규율 + `initialized:false→true` 경과 시간 기록 + already-initialized 시 사고 처리 | 반영 |
| 16 | 되돌리기에 Ingress 누락 → 공개 진입점 잔존 | 비평 1 minor | 삭제 순서 ①Ingress … ⑤PVC 제외(kustomization·README·런북 동일) | 반영 |
| 17 | `key=-` 5개 다중 stdin → 빈 값 | 비평 1 minor | 리터럴 통일, 실값 예시는 JSON stdin/키당 1회 | 반영 |
| 18 | state/plan 산출물 잔존 | 비평 1 minor | `state pull` 비밀 grep 0행 · tfplan 삭제 · `%TEMP%` 저장 금지 | 반영 |
| 19 | run-platform-tests 배열·문자열·픽스처 불일치 | 비평 2 minor | 배열 무변경 | 반영 |
| 20 | VaultSealed absent() 중복 제안 | 비평 2 minor | FR-040 MetricsAbsent 확인만 인계 | 반영 |
| 21 | 단일 stdout 감사 = fail-closed | 렌즈 3·6 | 런북 §9 + NodeDiskLow | 반영(운영 위험 상존) |
| 22 | e2e-reader 토큰 자급 불가(agent-view RBAC) | 렌즈 3·6 | M0 계약 한 줄 + 런북 §12 + T077 인계 | 반영 |
| 23 | helm 부재로 렌더 검증 fail-closed; CI validate는 gitleaks만 | 렌즈 4·5 | VD-08(1회 설치 권고) + T047 인계 | 반영(잔여) |
| 24 | root revoke 이후 관리 경로 0(2.0 generate-root 토큰 요구) | 렌즈 2·6 | **미해결** — D4 + converge, T045 revoke 전 결론 필수 | 미해결 |

---

## 7. VD 실측 항목

| VD | 시점 | 기본 가정 | 명령 | 판정 |
|---|---|---|---|---|
| 01 | 단계 0 | winget에 2.0.4 매니페스트 있음 | `winget show --id Hashicorp.Vault --versions` / zip SHA256 `5e6357e5…d8f` 대조 / `vault version` | `Vault v2.0.4`면 진행, 1.x면 중단 |
| 02 | 단계 0·각 창 | 클립보드 기록 OFF·Transcript 없음 | `EnableClipboardHistory` · `$Transcript` · `Set-PSReadLineOption -HistorySaveStyle SaveNothing` | 1이면 단계 9는 화면 직접 전사 |
| 03 | 단계 8 | `-flag=value` 따옴표로 정상 전달 | `vault operator init "-status"` | exit 2 = 미초기화·인자 정상; 0이면 중단 |
| 04 | 단계 0 | local-path reclaim Delete·WFFC, setup `mkdir -m 0777` | `kubectl get sc local-path -o jsonpath=…` · `cm local-path-config .data.setup` | Delete면 런북 §11 경고 굵게; 0777 아니면 fsGroup 유지 확인 |
| 05 | 단계 0 | auth/KMS 엔드포인트 공인 IP | `nslookup auth.ap-chuncheon-1.oraclecloud.com` + tofu output 호스트 2개 | 사설 대역 0개면 PASS; 있으면 network-policy.md 개정 선행 |
| 06 | 단계 0 | 노드 A 스왑 0 | `ssh ssh-a "swapon --show; free -h"` | 0이면 런북에 실측 기록 |
| 07 | 단계 0·14 | `/etc/platform-backup/env`에 `BACKUP_COMPONENTS=k3s` 잔존 | `ssh ssh-a "cat /etc/platform-backup/env"` | 있으면 단계 14에서 삭제 |
| 08 | 단계 4 | 렌더 10장·image digest 1줄(helm 필요) | `kustomize build --enable-helm platform/vault \| yq …` | 정확히 10장 + injector/csi/webhook/PDB/NetworkPolicy/vault-ui/active/standby 0; helm 없으면 fail-closed → 1회 설치 권고 |
| 09 | 단계 3·4 | gitleaks 기본 룰이 OCID를 잡지 않음 | `gitleaks dir … --exit-code 1` | exit 0; 잡히면 `.gitleaks.toml` allowlist(경로 한정, `ocid1\.key\.`) + README 근거 |
| 10 | 단계 7 | seal 설정 성공, Running 0/1 | `logs vault-0 \| Select-String 'Seal Type\|ocikms\|error\|x509\|IMDS'` | `Seal Type: ocikms` 1회 + 오류 0; CrashLoop면 §3 분기 |
| 11 | 단계 8 | XFF 미도입 → 헤더 없는 요청 200 | `curl.exe -w %{http_code} …/v1/sys/seal-status` | 200 PASS; 400이면 중단 |
| 12 | 단계 7 | containerd가 `repo:tag@digest` 수용 | `get sts … image` · `get pod … imageID` | 두 digest 일치; ImagePullBackOff면 `"2.0.4"` 폴백 |
| 13 | 단계 7 | injector/webhook/PDB/차트 NetworkPolicy 0 | `get mutatingwebhookconfigurations` · `-n vault get pdb,networkpolicy` | 0 · platform/policies 소유분만 |
| 14 | 단계 9 | auto-unseal 필드 `recovery_seal:true`·`storage_type:raft` | `curl …/v1/sys/seal-status` | 실제값을 §4에 기록, 문서 단정 안 함 |
| 15 | 단계 10 | 감사 JSON이 파드 로그에 흐름 | agent-view `logs -n vault vault-0 --tail=20 \| Select-String '"type":"request"'` | ≥1행 |
| 16 | 단계 12 이후 | 토큰 없이 메트릭·호스트 접두 없음·1m 보존 결측 없음 | `curl …/v1/sys/metrics?format=prometheus \| Select-String '^vault_core_unsealed'` 60s×5 | `vault_core_unsealed 1` 5/5; 결측 시 T098 스크레이프 ≤30s 확정 |
| 17 | 단계 11 | 90–180초 내 auto-unseal | `delete pod vault-0` → seal-status · events FailedPreStopHook | sealed=false PASS; 실패 시 즉시 중단 |
| 18 | 단계 12 | kubernetes_host·TokenReview·iss·audience 정합, backup 정책 최소 | vault-backup 로그인 · `token capabilities … snapshot / snapshot-force` | 토큰 반환 · read / deny |
| 19 | 단계 12·T077 | `vault kv get` preflight 403, `vault read` 가능 | e2e-reader 토큰 `capabilities kv/data/platform/authentik/e2e` · `sys/internal/ui/mounts/kv` | read / deny → tester는 `vault read` |
| 20 | 단계 12 | agent-view가 serviceaccounts/token create 불가 | `kubectl auth can-i create serviceaccounts/token -n kube-system --as=system:serviceaccount:kube-system:agent-view` | no → T077 절차 = 운영자 발급 |
| 21 | 단계 16 | Access 302 · 오리진 200/307 · 로그인 화면 렌더 | 노드 A `--resolve` · edge curl · 브라우저 · 4xx 프로브 TLSClientSubject | 합격선 = 로그인 화면 |
| 22 | 단계 14 | 백업 1회 성공·pre-upgrade exit 0 | `platform-backup.sh --components vault` · `oci … os object list --prefix vault/` · `--pre-upgrade` | `.age` 1건 · exit 0 |
| 23 | 단계 12 | 상태 파일 비밀 0 | `tofu state pull \| Select-String 'PRIVATE KEY\|eyJhbGciOi\|AGE-SECRET-KEY'` | 0행 |
| 24 | T048 이후/SP-2 | `-force` 복원 뒤 스냅샷 시점 recovery key 유효 | 비운영/계획 창: 새 init → restore -force → `generate-root -status` | 3/2 보고 시 런북 §7 확정 — **T044에서 실행 안 함** |

---

## 8. 테스트·문서 변경 목록

| 파일 | 변경 |
|---|---|
| `tests/infra/tofu.tests.ps1` | vault 그룹 20 단언(dir-3 · validate-vault-1/2 · vt-1~17, §4.11) · 헤더 41→61 · 게이트/heredoc 규약 2줄. **plan 단언 없음 · `New-TfValidateCopy` 무변경** |
| `tests/platform/run-platform-tests.ps1` · `tests/scripts/run-platform-tests.tests.ps1` | **변경 없음**(infra/oci 존재로 tofu.tests가 이미 실행; 배열·SKIP 문자열·픽스처 삼중 갱신 회피) |
| `tests/platform/cluster.tests.ps1` · `ingress.tests.ps1` · `reboot.tests.ps1` | 변경 없음. T044로 vault-1/2 · argo-1 · np-4 · ingress vault-2 · backup-2/3 FAIL→PASS; argo-4는 ns vault 부분만; argo-1은 G1 머지~init '기대 실패 사전 고지' |
| `tests/infra/platform-backup.tests.ps1` | 변경 없음(76 단언 코드 텍스트) — M2 뒤 재실행 |
| gitops `tests/validate.sh` | 변경 없음. 5.4b가 port/targetPort 명시로 실제 대조 시작; 검사 1은 helm 부재 fail-closed(T047) |
| `docs/runbooks/vault-unseal.md` | **신규** §0–§13(§4.12). 문면 정정 3건(sealed 대기 → CrashLoop · 삭제 유예 30일 → 예약 즉시 불능 · break-glass 토큰 요구) |
| `docs/README.md` | `runbooks/bootstrap.md` 행 아래 1행: `\| [runbooks/vault-unseal.md](runbooks/vault-unseal.md) \| Vault seal 런북 — KMS 장애 대기·break-glass(2.0은 토큰 필수)·Raft 스냅샷 복원(같은 KMS 키 필수), 전부 워크스테이션 CLI \|` |
| `docs/runbooks/bootstrap.md` §4 | T044 절(§4.13 항목 7종) · T043 이월 한 줄 흡수 · 값은 절대 아님 |
| `infra/bootstrap/platform-backup.sh` | 헤더 산문 3곳(:40 · :44-45 · :56-58) + 절차 3 T044 전/뒤 분기 → "T044 확정: tlsDisable=true 유지, 스킴 http / env 파일 삭제 완료 <날짜>" |
| `specs/003-platform-foundation/contracts/hostnames-and-access.md` | :79 부근 e2e-reader 토큰 발급 절차 1줄(M0, 단독 커밋 선행) |
| gitops `platform/vault/README.md` | **신규** §0 소유/비소유 + '**UI로 init 하지 않는다**' + OCID 공개 근거 · §1 인플레이트 이유(7.1 · HTTPS repo) · §2 bump(index digest · image.tag digest · **schema가 오타를 못 잡음** · charts/ 캐시) · §3 values 근거(XFF 미도입 · securityContext 분할 · injector/csi/ui/networkPolicy · PDB · OnDelete+checksum · seal 3값) · §4 init·seal은 모노레포 런북 링크 · §5 되돌리기 순서(PVC/PV 제외) · §6 배포 뒤 확인 명령 · §7 고아 경고 1건 정상 + auth-delegator 폭발 반경 · §8 T045 인계 |
| `specs/003-platform-foundation/tasks.md` | `[X]`만 |
| ADR 0010 · spec · plan · gitops-repo.md | **편집하지 않음**(정정 후보는 §9 converge) |

---

## 9. 인계

- **T045(ESO + store 5)**: role 4개(eso-platform/dev/prod/data)는 존재하며 SA 존재를 검사하지 않으므로 ns external-secrets의 동명 SA는 T045가 만든다 · ESO 컨트롤러 RBAC에 그 SA들의 `serviceaccounts/token` create 필요(`kubectl auth can-i create serviceaccounts/token --as=system:serviceaccount:external-secrets:external-secrets -n external-secrets`) · ClusterSecretStore `auth.kubernetes.serviceAccountRef.audiences: [vault]` 필수 · 다섯 번째 `k8s-data-ca`는 Vault role 없음(SA `eso-ca-reader` K8s RBAC) · 초기 kv 시드는 **root 토큰**(T044에서 보관, revoke 안 함)으로 · **root revoke(ADR ⑥)는 D4 결론(break-glass 대체) 이후에만** · eso-* 정책은 metadata `read`만 — `dataFrom.find` ExternalSecret이 생기면 계약 개정 뒤 list 추가.
- **T048(재부팅 리허설·스냅샷 inspect)**: pod 재기동 auto-unseal은 T044 VD-17로 증명됨. 노드 레벨(reboot-1 300s)과 `raft snapshot inspect`만. 복원 리허설(VD-24)은 비운영/계획 창으로.
- **T077(E2E)**: agent-view는 `--audience vault` 토큰 자급 불가(VD-20) → 운영자가 세션 직전 `kubectl create token agent-view -n kube-system --audience vault --duration=1h` 발급·env 전달(M0 계약 한 줄) → `login role=e2e-reader` → **`vault read kv/data/platform/authentik/e2e`**(`vault kv get`은 preflight 403, VD-19). RBAC 확장은 채택 안 함.
- **T084(회전·운영 매트릭스)**: root 토큰 보관·revoke 시점·대체 관리 경로(D4) 등재 · 정례 `tofu -chdir=infra/vault plan`(sys/auth sudo 필요)이 유일한 드리프트 그물 · OIDC 도입 시 관리 경로 승격 · Vault UI Access 세션(T043 이월과 같은 묶음).
- **T098(관측·알림)**: `VaultSealed`는 plan §Observability 표대로 유지 — 재시작 실패(absent) 사각지대는 **FR-040 13번째 `MetricsAbsent`(absent 6종 30m, `vault_core_unsealed` 포함)가 이미 덮는다**: 등록 여부만 확인 · vault 스크레이프 주기 **≤30s**(HCL `prometheus_retention_time = "1m"` 동결, VD-16) · 감사 fail-closed 경로의 조기 경보 = `NodeDiskLow` · 감사 엔트리 존재를 라이브 테스트에 넣는 것 검토.
- **T047(gitops CI·validate)**: `.github/workflows/validate.yml` 검사 1–7이 `echo` 자리표시자(gitleaks만 실동작) → `tests/validate.sh` 배선 + runner helm 설치 · `helmCharts[].repo` 허용 목록 정적 검사(AppProject sourceRepos에서 hashicorp 줄을 지우며 생긴 공백) · helm 부재 fail-closed 컴포넌트가 cert-manager·vault 둘.
- **T046+(데이터 스택)**: argo-4는 pg-main·jt-kafka·KafkaNodePool·Dragonfly PVC·오퍼레이터 CRD에도 같은 어노테이션 요구 — T044만으로 PASS 아님. Vault는 `role=platform` 고정이 KMS 가용성 조건임을 상기.
- **T114(런북 구성 정본)**: `vault-unseal.md` §0–§13을 통일 형식(목적·전제·절차·검증·되돌리기)으로 재정렬.
- **/speckit-converge(편차·정정 6건)**: ① research VAULT-D3 XFF 미채택(D9) ② research VAULT-D2 `ui.enabled` false(D9) ③ 문면 외 보강 values 5종(D9) ④ **ADR 0010 §6·spec FR-041 정정 후보**: Vault 2.0에서 `generate-root`/`rekey`가 유효 토큰을 요구해 "recovery key만으로 break-glass"가 성립하지 않음 — **T045 root revoke 전에 대체 경로(7번째 role 등, tasks:123 "합계 6" 개정 포함) 결정 필요**(D4 미해결) ⑤ ADR 0010 §4·tasks 문면 "KMS 일시 장애 = sealed 대기" → 재시작 시 CrashLoop(살아 있으면 유지) ⑥ ADR 0010 §5·tasks 문면 "KMS 키 삭제 유예 30일" → Pending Deletion 즉시 불능·30일은 취소 창. ADR·spec·tasks 본문은 T044에서 편집하지 않고 런북·README에 정확한 문면을 쓴 뒤 report.md '문면 정정' 절에 근거와 함께 올린다.
