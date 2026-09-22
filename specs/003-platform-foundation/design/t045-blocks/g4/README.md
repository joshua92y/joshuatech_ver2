# T045 G4 운영자 블록 — 인계 상태 (2026-09-22)

> **G4 운영자 블록의 오프라인 준비를 완료했다.** 하네스 122/122, 변이 223/223, 독립 코드 검토 Approved / Approved다. **라이브 인수·드릴과 G5는 아직 미완**이며 PR #29도 미머지다. 다음은 사용자 입회에서 기준값을 캡처한 뒤 머지하는 단계다. 전체 저장소 검사의 OpenTofu 슬롯은 필수 환경 변수 부재로 실패해 G5 확인 항목으로 남는다.

## 이 디렉터리

| 파일 | 상태 |
|---|---|
| `g4-adopt.ps1` | 캡처 → 머지 대기 → 인수 판정 → 해시·UID 인계. 클러스터 쓰기 0건 |
| `g4-drill.ps1` | 독립 게이트와 별도 입회 뒤 이름을 지정한 파드 1개 교체 |
| `g4-restore.ps1` | 값 복구(R2 마지막 단계). 재인수 뒤 정규 drill과 ES 없는 비상 복구를 구별 |
| `harness-g4.ps1` | 세 블록 모의 하네스. 최종 코드 122/122 · lint 실패 0; 대화형 bash 모의 3건 포함 |
| `mutants-g4.ps1` | 기존 201개 ID 보존·이동·구조 대체 + 신규 22개. 223/223 CAUGHT, 잠금 127/127, ESCAPED·ANCHOR-ERR·NO-OP 0 |
| `NOTES.md` | 라운드별 처리·근거·미확인 목록 |
| `reviews/` | 매니페스트 리뷰 + 라운드별 적대적 검증 보고(JSON·MD) |

분리 전 최신 지적은 `reviews/verify-r4-r5.json`의 `rounds[1].findings`다(high 1 · medium 4 · low 6 · info 3). 분리 후 처리는 `NOTES.md` §11에 이어 기록한다. 분리 전 안전장치와 새 목적지의 대응은 `reviews/split-safety-map.md`에서 확인한다.

최종 증거는 [분리 검증 보고서](reviews/split-verification.md), [하네스 실행 기록](reviews/split-harness.txt), [변이 실행 기록](reviews/split-mutants.txt), [223개 실패 근거 감사](reviews/split-mutant-audit.json), [최종 코드 검토](reviews/split-review3.md)에 보존했다. 변이 전수 실행 뒤 결과 분류를 강화했고, 동일 로그를 재평가했다. 당시 원시 종료 코드는 미저장이므로 완전한 실패 요약과 하네스 계약에서 추론했다는 한계를 보고서에 명시했다.

## 확정된 설계 변경(사용자 결정 2026-09-22)

**파드 드릴을 별도 블록으로 분리한다.**

이유: 3·4·5라운드가 매번 같은 계열의 high를 새로 찾아냈다. "이전 실행이 이미 파드를 지웠다"는 사실을 **운영자가 타자로 옮겨 적는 `drilled:` 접두어**로 이어가는데, 그 사슬이 끊어지는 경로가 라운드마다 새로 나왔다(3R 라벨 삭제 · 4R 접두어 제거 · 5R 중단된 실행의 요약이 접두어 유실 · 5R 라벨+data-hash 동시 삭제). 패치가 아니라 구조를 바꾼다.

| 블록 | 역할 | 클러스터 쓰기 |
|---|---|---|
| `g4-adopt.ps1` | 캡처 → 머지 대기 → 판정 → 끝 | **0건** |
| `g4-drill.ps1` (신설) | 파드 **1개** 교체 | 1건 |
| `g4-restore.ps1` | 값 복구 | 1건 |

- adopt가 읽기 전용이면 "중단돼도 클러스터를 바꾸지 않는다"가 증명 대상이 아니라 자명해진다. `drilled:` 사슬 · `first-drill` · `nopods` · 이전 드릴 감지 · `$podDrill` 체인은 **전부 삭제**한다(그 기계장치가 문제의 근원이었다).
- adopt는 판정 성공 시 다음 단계를 명시하고 drill이 입력받을 값(**값 해시 · UID** — 비밀 아님)을 인쇄한다. adopt를 재실행해도 클러스터 쓰기는 없다. resume에서는 인수 전 파드 불변까지 증명했다고 주장하지 않는다.
- drill 머리글 첫 줄: **"이 블록은 파드 1개를 지운다. 두 번 실행하면 두 커넥터가 모두 교체되어 '한쪽은 옛 값을 들고 있다'는 안전망이 사라진다."**
- drill의 삭제 전 게이트(전부 fail-closed): ⓐ 클러스터 신원·권한 ⓑ ES `Ready=True`/`SecretSynced` ⓒ 값 해시 == 입력 해시 **그리고** UID == 입력 UID ⓓ `data-hash` 어노테이션 존재 ⓔ 파드 정확히 2개이고 둘 다 Ready ⓕ break-glass(ssh boot_id + oci 프로브 — 둘 다 실패면 단어 `no-breakglass` + **삭제 거부**) ⓖ **지울 파드 이름을 운영자가 타자**하는 정지점 ⓗ 삭제 직전 값·UID·파드 재확인.
- 이미 한 번 교체된 것으로 보이면(파드 하나의 `startTime`이 ES `creationTimestamp`보다 뒤) 경고 + 단어를 `second`로 바꿔 받는다 — **하드 게이트가 아니다**(사슬을 만들지 않는다).
- 삭제 대상 = `startTime`이 가장 늦은 파드(같으면 이름 Ordinal). `kubectl delete pod <이름> --wait=false`, **회계를 네이티브 호출보다 먼저** 기록. `rollout restart`·`scale`·셀렉터 삭제 금지.
- 삭제 뒤: 새 파드 Ready 폴링 · 로그 `Registered tunnel connection` · 남은 파드 미접촉 확인 · 창 A 세션 재확인 안내 · `ssh ssh-a hostname` · `kubectl get nodes`. 새 파드가 Ready가 안 되면 **남은 파드를 절대 건드리지 않고** 중단 + 복구 안내.

## 진행 상태와 남은 일

1. **구현·코드 검토 완료**: adopt/drill 분리 + restore 참조 갱신. 동결 명세와 task 체크박스는 바꾸지 않는다.
2. **반영 완료**: 5라운드 지적의 실제 수정과 구조 삭제에 의한 해소를 `NOTES.md` §11.5에 구별해 기록했다. EOF·R3 복구 조각 전문·namespace 권한·runtime 허용 동사 목록을 검사한다.
3. **검증 완료**: adopt의 AST 동사는 `get`·`auth`·`logs`만 허용한다. 모의 kubectl은 adopt 변경 동사를 즉시 거부하고, 모든 adopt 시나리오는 변경 로그가 비었는지 검사한다. drill은 게이트별 거부·이름 오타·`second`·새 파드 Ready 타임아웃·지속 조회 실패·회계 선행을 검사한다. 기존 잠금·규약 변이를 포함한 223개가 모두 CAUGHT이며, ANCHOR-ERR·NO-OP는 0이다. 프로세스 오류만 있는 결과도 성공으로 세지 않도록 분류를 보강했다.
4. **적대적 검토 완료**: 검토에서 찾은 5건과 완전 단절 복구 인계의 잔여 갈래를 수정했다. 독립 검토 최종 판정은 Approved / Approved, 잔여 0건이다(`reviews/split-review3.md`). 기존 안전장치 대응표로 분리에서 빠진 보호를 확인했고 변이별 실패 근거도 전부 감사했다.
5. **문서 커밋·로컬 검증 완료**: GitOps PR #29 브랜치의 README 3곳에 세 블록 체계를 반영했다(문서 커밋 `6882d47`). `validate.sh`는 24 PASS / 0 FAIL / 기존 WARN 4, `validate.tests.sh`는 44/44다. 파일 이름으로 한정해 스테이징했다. 머지는 사용자 단계다.
6. **사용자 입회·미실행**: 준비 완료 뒤 캡처 → 사용자 머지 → 인수 판정 → 별도 입회에서 drill. 실행 결과가 확인된 뒤에만 런북 `docs/runbooks/bootstrap.md` §3 T045 절에 기록한다.
7. **미완**: G5의 문서·전체 검사·라이브 하네스 확인 뒤 T045를 체크한다. 현재 50/119이며 G4 모의 검증 통과만으로 완료하지 않는다.

## 작업 규약(v2 블록 — 이 저장소 확정)

단일 최상위 `& { … }` 한 문 · 빈 줄 0 · CR/TAB 0 · 끝 3바이트 `0A 7D 0A` · **파일로만 실행**(`& <경로>`) · 사람 동작마다 정지점(`FlushInputBuffer()` + 타자 단어, 빈 Enter 불통과) · 시크릿은 화면·로그·파일·클립보드·argv·전역 변수·히스토리에 남기지 않는다 · 판정은 SHA-256 Ordinal · fail-closed(조회 실패를 '없음/같음'으로 읽지 않는다) · `try/finally`, finally는 자격 정리 먼저 그다음 `Write-Host`/`Write-Warning`만 · `-flag=value` 인용 · 끝에 단계별 요약. adopt는 쓰기 없이 재실행할 수 있고 restore는 값 해시가 같으면 SKIP한다. **drill은 멱등 블록이 아니며 자동 재실행하지 않는다.** 선례는 상위 디렉터리의 `op1-seed.ps1` · `kv-correct.ps1` · `dr1-drill.ps1` · `g3-capture.ps1` · `g3-gate.ps1` · `harness.ps1` · `CHANGES.md`.

## 라이브 미확인(블록이 기대는 전제)

실물 `kubectl`의 jsonpath 표기(4필드 단일 GET · `creationTimestamp` · `containerStatuses[0].restartCount`) · ESO 2.10.0이 터널 Secret에도 `data-hash`를 같은 키로 남기는가(G3의 DNS 토큰에서만 확인) · `kubectl delete --wait=false`의 실제 왕복 · Argo가 Missing 상태 ES를 `status.resources`에 싣는가 · 노드 sudo NOPASSWD · 운영자 터미널의 bracketed-paste 실동작 · Ctrl+C 중 finally 절단과 `FlushInputBuffer()`의 실제 제거율. 상세는 `NOTES.md` §4.
