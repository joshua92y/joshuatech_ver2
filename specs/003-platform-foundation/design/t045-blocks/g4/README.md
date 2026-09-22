# T045 G4 운영자 블록 — 인계 상태 (2026-09-22)

> ⚠ **미완이다.** 아래 「남은 일」을 끝내기 전에는 운영자에게 주지 않고, gitops PR #29도 머지하지 않는다.

## 이 디렉터리

| 파일 | 상태 |
|---|---|
| `g4-adopt.ps1` (724줄) | 5라운드 검증판. 판정 + 파드 1개 드릴을 **한 블록에** 담고 있다 — 분리 대상 |
| `g4-restore.ps1` (226줄) | 5라운드 검증판. 값 복구(R2 마지막 단계) |
| `harness-g4.ps1` | 모의 하네스 121 시나리오(PASS 121/121 · lint 실패 0) |
| `mutants-g4.ps1` | 변이 시험 201개(전부 CAUGHT · ESCAPED 0) |
| `NOTES.md` | 라운드별 처리·근거·미확인 목록 |
| `reviews/` | 매니페스트 리뷰 + 라운드별 적대적 검증 보고(JSON·MD) |

`reviews/verify-r4-r5.json`의 `rounds[1].findings`가 **가장 최신 잔여 지적**이다(high 1 · medium 4 · low 6 · info 3).

## 확정된 설계 변경(사용자 결정 2026-09-22) — 아직 반영 안 됨

**파드 드릴을 별도 블록으로 분리한다.**

이유: 3·4·5라운드가 매번 같은 계열의 high를 새로 찾아냈다. "이전 실행이 이미 파드를 지웠다"는 사실을 **운영자가 타자로 옮겨 적는 `drilled:` 접두어**로 이어가는데, 그 사슬이 끊어지는 경로가 라운드마다 새로 나왔다(3R 라벨 삭제 · 4R 접두어 제거 · 5R 중단된 실행의 요약이 접두어 유실 · 5R 라벨+data-hash 동시 삭제). 패치가 아니라 구조를 바꾼다.

| 블록 | 역할 | 클러스터 쓰기 |
|---|---|---|
| `g4-adopt.ps1` | 캡처 → 머지 대기 → 판정 → 끝 | **0건** |
| `g4-drill.ps1` (신설) | 파드 **1개** 교체 | 1건 |
| `g4-restore.ps1` | 값 복구 | 1건 |

- adopt가 읽기 전용이면 "중단돼도 클러스터를 바꾸지 않는다"가 증명 대상이 아니라 자명해진다. `drilled:` 사슬 · `first-drill` · `nopods` · 이전 드릴 감지 · `$podDrill` 체인은 **전부 삭제**한다(그 기계장치가 문제의 근원이었다).
- adopt는 끝에서 다음 단계를 명시하고 drill이 입력받을 값(**값 해시 · UID** — 비밀 아님)을 인쇄한다. 재실행은 언제나 안전하다.
- drill 머리글 첫 줄: **"이 블록은 파드 1개를 지운다. 두 번 실행하면 두 커넥터가 모두 교체되어 '한쪽은 옛 값을 들고 있다'는 안전망이 사라진다."**
- drill의 삭제 전 게이트(전부 fail-closed): ⓐ 클러스터 신원·권한 ⓑ ES `Ready=True`/`SecretSynced` ⓒ 값 해시 == 입력 해시 **그리고** UID == 입력 UID ⓓ `data-hash` 어노테이션 존재 ⓔ 파드 정확히 2개이고 둘 다 Ready ⓕ break-glass(ssh boot_id + oci 프로브 — 둘 다 실패면 단어 `no-breakglass` + **삭제 거부**) ⓖ **지울 파드 이름을 운영자가 타자**하는 정지점 ⓗ 삭제 직전 값·UID·파드 재확인.
- 이미 한 번 교체된 것으로 보이면(파드 하나의 `startTime`이 ES `creationTimestamp`보다 뒤) 경고 + 단어를 `second`로 바꿔 받는다 — **하드 게이트가 아니다**(사슬을 만들지 않는다).
- 삭제 대상 = `startTime`이 가장 늦은 파드(같으면 이름 Ordinal). `kubectl delete pod <이름> --wait=false`, **회계를 네이티브 호출보다 먼저** 기록. `rollout restart`·`scale`·셀렉터 삭제 금지.
- 삭제 뒤: 새 파드 Ready 폴링 · 로그 `Registered tunnel connection` · 남은 파드 미접촉 확인 · 창 A 세션 재확인 안내 · `ssh ssh-a hostname` · `kubectl get nodes`. 새 파드가 Ready가 안 되면 **남은 파드를 절대 건드리지 않고** 중단 + 복구 안내.

## 남은 일

1. 위 분리 수행 + `g4-drill.ps1` 신설 + `g4-restore.ps1` 머리글 참조 갱신.
2. `reviews/verify-r4-r5.json`의 `rounds[1].findings` 잔여 지적 반영(분리로 자동 해소되는 것은 그렇게 기록).
3. 하네스·변이 재구성: **adopt의 lint에 "클러스터를 바꾸는 동사 0개"를 정적으로 못박고**(AST — `get`·`auth`·`logs`만 허용), 모의 kubectl은 변경 동사가 오면 즉시 시나리오 실패. adopt의 모든 시나리오 공통 사후 조건 = 변경 로그가 비어 있음. drill 시나리오 신설(게이트별 거부 · 이름 오타 · `second` · 새 파드 Ready 타임아웃 · kubectl 지속 실패 · 중단 시 회계 선행). 기존 잠금·규약 변이는 **살려서** 전부 CAUGHT.
4. 적대적 재검증(실행·하네스 / 잠금·의미) — adopt 쓰기 0건을 AST와 모의 양쪽으로 증명. 분리로 **잃은** 안전장치가 있는지 옛 구조와 하나씩 대조.
5. gitops PR #29 브랜치에 README 문면 갱신 커밋(두 블록 체계 반영): `platform/secrets/README.md` §2 · `platform/cloudflared/README.md` ⑨ · `secrets/README.md`가 `g4-adopt.ps1`/`g4-restore.ps1`을 이름으로 가리킨다 → `g4-drill.ps1` 추가.
6. 모노레포 런북 `docs/runbooks/bootstrap.md` §3 T045 절에 G4 실행 기록(머지 뒤).

## 작업 규약(v2 블록 — 이 저장소 확정)

단일 최상위 `& { … }` 한 문 · 빈 줄 0 · CR/TAB 0 · 끝 3바이트 `0A 7D 0A` · **파일로만 실행**(`& <경로>`) · 사람 동작마다 정지점(`FlushInputBuffer()` + 타자 단어, 빈 Enter 불통과) · 시크릿은 화면·로그·파일·클립보드·argv·전역 변수·히스토리에 남기지 않는다 · 판정은 SHA-256 Ordinal · fail-closed(조회 실패를 '없음/같음'으로 읽지 않는다) · `try/finally`, finally는 자격 정리 먼저 그다음 `Write-Host`/`Write-Warning`만 · `-flag=value` 인용 · 끝에 단계별 요약 · 재실행 안전. 선례는 상위 디렉터리의 `op1-seed.ps1` · `kv-correct.ps1` · `dr1-drill.ps1` · `g3-capture.ps1` · `g3-gate.ps1` · `harness.ps1` · `CHANGES.md`.

## 라이브 미확인(블록이 기대는 전제)

실물 `kubectl`의 jsonpath 표기(4필드 단일 GET · `creationTimestamp` · `containerStatuses[0].restartCount`) · ESO 2.10.0이 터널 Secret에도 `data-hash`를 같은 키로 남기는가(G3의 DNS 토큰에서만 확인) · `kubectl delete --wait=false`의 실제 왕복 · Argo가 Missing 상태 ES를 `status.resources`에 싣는가 · 노드 sudo NOPASSWD · 운영자 터미널의 bracketed-paste 실동작 · Ctrl+C 중 finally 절단과 `FlushInputBuffer()`의 실제 제거율. 상세는 `NOTES.md` §4.
