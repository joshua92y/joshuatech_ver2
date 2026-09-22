# T045 G4 수정 슬라이스 — 리뷰 생존 14건(중복 제외 11항) 반영 (커밋 금지)

리뷰 결과 전문(JSON — 각 항목의 `claim`·`evidence`·`corrected_fix`·`reason`): `C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-review-result.json`
**`corrected_fix`가 있으면 그것이 정본이다**(검증자가 리뷰어 수정안을 고친 것). 매니페스트 값 지적은 0건이다 — **ES spec과 `platform/cloudflared/*.yaml`은 건드리지 않는다**(렌더 바이트 동일 유지). 범위·금지 사항은 첫 슬라이스와 같다(브랜치 `t045-g4-tunnel-secret` · git 쓰기 금지 · kubectl 금지 · 한국어·정규식 파일은 Edit/Write · CR 0).

## 새로 확정된 사실(이 수정의 기준 — 첫 슬라이스의 해당 문장을 대체한다)
- **F1(안전망의 시한)**: env(`secretKeyRef`)는 파드가 아니라 **컨테이너가 시작될 때마다** kubelet이 Secret을 다시 읽어 채운다 — 파드 교체뿐 아니라 같은 파드 안의 제자리 재시작(liveness 실패 · OOMKill · 크래시 · 노드 재부팅 = 파드 이름·UID 그대로, restartCount만 증가)도 포함이다. 이 Deployment의 liveness는 `/ready`(10s × 6)라 edge 단절이 약 60초 이어지면 **두 커넥터가 파드 교체 없이 거의 동시에 재시작**할 수 있다. 따라서 "실행 중 파드는 옛 값을 들고 있다"는 안전망은 **컨테이너가 재시작되지 않는 동안만** 유효하다 — 값이 틀린 상태는 안전 상태가 아니라 **시한 상태**다(복구를 미루지 않는다 · 그동안 노드 재부팅/SUC Plan/drain 금지). 첫 슬라이스의 "토큰은 파드 시작 시에만 읽는다"는 이 문장으로 대체한다.
- **F2**: 모노레포 하네스 `eso-4`는 **이미 있다**(커밋 `27f90dd` — 인수형 ES 2장의 Orphan/Retain/Periodic/빈 template.metadata/sync-options 라이브 검사. 라이브 검사라 **적용된 뒤에만** 보인다 · agent-view로 수동 실행 · G4 머지 전에는 터널 ES 부재로 FAIL이 기대값).
- **F3**: managed 라벨은 ESO가 provider 조회 **전에** 붙일 수 있다(확정 사실 ③). ESO가 **데이터를 썼다**는 양성 증거는 `reconcile.external-secrets.io/data-hash` 어노테이션이다 — 정본 블록(`g4-adopt.ps1`)은 이것을 판정 항목으로 본다. README §2 판정 항목에 넣는다.
- **F4**: 계약이 먼저 고쳐졌다(모노레포 `2752afd` — gitops-repo.md §validate.yml 4 「(T045 G4) 배달자는 base를 묶기만 한다」): `platform/secrets/kustomization.yaml` 최상위 키 = `{apiVersion, kind, resources}`뿐 · `secrets/<ns>/kustomization.yaml`은 거기에 `namespace`까지만 · `platform/secrets` 렌더에도 `secrets/**` 위치 규칙 적용.
- **F5(외부 서비스 — VD 표기 필수)**: Cloudflare remote-managed 터널은 새 토큰을 발급(Refresh)하는 순간 옛 토큰으로 **새 연결**을 맺지 못한다(기존 연결은 유지) — **Cloudflare 문서 기준이며 실측은 T084 VD**라고 반드시 병기한다(단정 금지).

## 항목
1. **ML-1 = G4-RVA-2 [high]** `platform/cloudflared/README.md` ② :46-47: "회전 시 재실행해도 되고" 제거 → 멱등·`last-applied-configuration` 미생성은 유지 + "⚠ T045 G4 뒤에는 이 절차가 **회전 수단이 아니다** … 회전은 ⑨(kv 먼저) … ②는 콜드 부트스트랩과 인수 해제 뒤 복구 전용". ② 제목 아래에도 같은 취지 한 줄. `platform/cert-manager-issuers/README.md`:76의 **글자 그대로 인용**을 함께 맞추고(인용부를 `last-applied-configuration` 절로 줄임) :77 "회전으로 이 절차를 재실행할 때도" → "복구·재부트스트랩으로 재실행할 때도"(그 컴포넌트의 매니페스트는 불변 — 렌더 바이트 동일 확인).
2. **ML-3 = G4-RVA-3 [medium] (F1)**: "파드 시작 시 1회만"·"다음 파드 교체에서" 류 문면을 F1로 통일 — ES 머리 주석 :5 부근 · `platform/secrets/README.md`(:22-23 · :35 · :80 · :214 · :315 · :332-333 · :350-353) · `platform/cloudflared/README.md` ⑨(:254 · :262 · :266-267) · `secrets/README.md`(:14 · :23 · :28-29) · `platform/external-secrets/README.md`(:471-472). 줄 번호는 리뷰 시점 기준이니 grep(`파드 시작` · `1회` · `파드 교체` · `옛 값` · `재시작하지`)으로 전수 확인한다. §2 「판정이 깨졌을 때」에는 시한 문장(F1의 liveness 60초 · "②③이 깨지면 지체 없이 kv를 정정한다" · 그동안 재부팅/SUC/drain 금지)을 넣는다. Secret 삭제 뒤 5분 창의 "실행 중 커넥터는 무영향"에는 "(재시작되지 않는 한 — 그 창에서 컨테이너가 재시작하면 Secret이 재생성될 때까지 `CreateContainerConfigError`)"를 덧붙인다.
3. **ML-2 [PARTIAL]** ⑨ 회전 절: `corrected_fix` 그대로 — 0단계(시작 전 전제 · data-hash 기록) + F5 경고 단락(VD 병기) + 2단계 구체화 + 3단계 추가 문장. `platform/secrets/README.md` §6의 T084 인계 불릿에 한 줄. **§5와 `secrets/README.md`에는 복제하지 않고 ⑨를 가리킨다.**
4. **ML-4 [low]** `platform/secrets/README.md` §4 끝: Vault 스냅샷 복원 경로 경고 한 문장(`corrected_fix`).
5. **ML-5 [low]** §5 revert 불릿: G4 PR 전체 revert = 첫 불릿과 같은 모양(+ README의 터널 해제 절차도 함께 되돌아가니 3–6단계가 끝날 때까지 되돌리기 전 판 또는 정본 `g4-restore.ps1`을 열어 둔다) · 셋째 불릿 제목을 "G3 PR(#28)까지 되돌려 `platform/secrets/` 자체가 사라지는 경우"로 한정.
6. **ML-6 = G4-RVA-5 [low]** `platform/secrets/kustomization.yaml` 주석: "이 줄을 지워도 인수는 **풀리지 않는다** — `prune: false` + ES의 `Prune=false`라 라이브 ES는 남아 5분마다 조정을 계속한다(해제 절차는 README §5: revert → 반영 확인 → `kubectl delete externalsecret`)".
7. **ML-7 ⓑ [low]** "런북의 **정정 블록**" 두 곳 → "모노레포 `specs/003-platform-foundation/design/t045-blocks/kv-correct.ps1`(정정 블록 — 런북 `bootstrap.md` §3 T045 절이 가리킨다)". 선택 항목(:330 다듬기)도 반영. ⓐⓒ는 컨트롤러 몫(건드리지 않는다).
8. **ML-8 [low]** ⑨ 인수 해제 요약: "… → Secret 잔존·UID·값(해시) 확인 → **값이 깨졌으면 복구하고 해시를 다시 확인** → (값을 복구한 경우에만) 파드 **1개** 교체"로 §5·`secrets/README.md`와 같은 순서.
9. **ML-9 + G4-RVA-1 [low] (F2)**: `secrets/README.md`:19-20 · `platform/secrets/README.md`:372-373의 "자동 검사 아직 없다 · G5 신설 예정" → F2 문면. ES 머리 주석 :23의 "`eso-4`(G5 신설)" → "`eso-4`(라이브 검사라 적용된 뒤에만 보인다 — 머지 전 방어선은 README §2의 렌더 체크)". `platform/secrets/README.md` §2 렌더 체크리스트에 sync-options 확인 줄(`corrected_fix`의 yq 명령 · 기대값 두 줄 모두 `Delete=false,Prune=false` — **실제로 실행해 출력이 문면과 같은지 확인**). `tests/README.md` 「한계」에 "검사 3은 target.creationPolicy/deletionPolicy · refreshInterval/Policy · 어노테이션 · template · data[].secretKey를 보지 않는다 — 머지 전은 platform/secrets/README §2의 yq 체크, 라이브는 하네스 eso-4".
10. **F3**: `platform/secrets/README.md` §1 판정 표와 §2 터널 절 판정 항목에 "`reconcile.external-secrets.io/data-hash` 어노테이션 존재 = ESO가 데이터를 썼다는 양성 증거(managed 라벨은 provider 조회 전에도 붙는다)"를 추가. G3 절의 기존 서술과 모순이 생기지 않게 같은 표현으로.
11. **G4-RVA-4 [low → 이 PR에서 닫는다] (F4)** `tests/validate.sh` 검사 7.3에 구조 금지 추가:
    - `platform/secrets/kustomization.yaml` 최상위 키가 `{apiVersion, kind, resources}`를 벗어나면 FAIL · `secrets/<ns>/kustomization.yaml`은 `{apiVersion, kind, resources, namespace}`를 벗어나면 FAIL(메시지에 벗어난 키 이름을 나열). yq 식은 `corrected_fix` 참고(`keys - [...] | length`) — 파일이 YAML로 안 읽히면 fail-closed.
    - 보조: 3.2의 위치 판정에 배달자 렌더 포함(:650 부근 `elif [[ $p =~ $RE_LOC_SECRETS || $p == "$SECRETS_OWNER_DIR" ]]` — 변수명은 실제 코드에 맞춘다).
    - 부정 픽스처 `tests/fixtures/secrets-owner/deliverer-patch/`(배달자에 `patches:`로 Owner + `remoteRef.key` 바꿔치기) + `secrets/<ns>` 쪽 변환 키 픽스처 1개(예: `namePrefix`) + `tests/validate.tests.sh` 등록(고유 문자열 단언) + `tests/README.md`(검사 목록·「한계」에 "3.2는 platform/secrets 렌더를 위치로 보지 않았다 → 변환 키 금지 + 렌더 포함으로 닫음") + validate.sh 머리 목차.
    - 실제 트리와 **모든 기존 픽스처**의 배달자·`secrets/<ns>` kustomization이 허용 키만 쓰는지 먼저 전수 확인(가짜 FAIL 0). positive의 `secrets/vault`는 `namespace:`를 쓴다.
    - `platform/secrets/README.md` §0-1의 "조용히 꺼진다" 경고 옆에 "배달자·`secrets/<ns>` kustomization에 변환 키를 넣지 않는다 — 검사 7.3이 막는다(계약 §validate.yml 4)" 한 줄.

## 게이트(출력 원문을 보고에)
```bash
kustomize build platform/secrets            # ES 2장 · DNS ES 문서가 main(22f96c3) 렌더와 바이트 동일 · 터널 ES 문서가 수정 전 렌더와 바이트 동일(주석만 바뀜)
kubeconform …                                # Valid 2 · Skipped 0
kustomize build platform/cloudflared         # main과 바이트 동일
kustomize build platform/cert-manager-issuers  # main과 바이트 동일(README만)
bash tests/validate.sh                       # FAIL 0 · PASS 수(7.3 확장으로 24 그대로인지 늘었는지 보고)
bash tests/validate.tests.sh                 # 백그라운드(10~35분) — 끝까지 기다려 케이스 수·실패 0 보고(42 + 신규)
# 음성 대조(스크래치패드 사본): 배달자에 patches 추가 → 7.3 FAIL · secrets/cloudflared/kustomization.yaml에 namePrefix → FAIL · 리뷰어 변형(Owner + platform/ 안에서 키 바꿔치기)이 이제 FAIL
gitleaks dir . --no-banner --redact --exit-code 1
git status --short ; 고친/만든 파일 전부 CR 바이트 0
grep -rn "파드 시작 시\|1회만\|회전 시 재실행" platform secrets clusters --include=*.md --include=*.yaml   # 잔존 0(인용·정정 설명 제외 — 남긴 것은 이유를 보고)
```

## 보고
첫 줄 `DONE`/`DONE_WITH_CONCERNS`/`NEEDS_CONTEXT`/`BLOCKED`. 항목별 처리(파일:줄) · 게이트 출력 원문 · 기각한 것이 있으면 근거 · 의문점. 한국어.
