```
지적별 처리: 수용 28 · 대체 구현 1(K8S-13) · 기각 0 · 추가 수정 4

■ 수용(구현 위치는 NOTES.md §1.1 표)
PS-G4-01 $kdel 회계를 네이티브 호출 앞으로 + lint L-B / PS-G4-02 합격 문면을 판정 여부에 묶음($podNote) /
PS-G4-03 드릴 대상 = startTime 최댓값 / PS-G4-04·SL-07 $kapply 회계 선행 + --request-timeout=30s + finally 3분기 /
PS-G4-05·K8S-07 $kq 에 $okRc 추가(can-i 의 exit 1) / PS-G4-06 2) 순서 역전(단어 먼저, 머지는 그 뒤) /
PS-G4-07·K8S-02 delete --wait=false + 드릴 대기 실패는 계속 폴링 / PS-G4-08·SL-01·K8S-10 삭제 직전 값·UID 재확인 /
PS-G4-09 두 파일 헤더에서 "붙여넣기 안전" 주장 철회 / SL-02 nopods 실행은 삭제 0 /
SL-03·K8S-03 $kq 문면을 $changes 로 분기 + 재시작 금지 문장 + 미판정 중단 경고 / SL-04 복구 블록이 Git 선언(requiresPruning)까지 검사 /
SL-05 break-glass 를 boot_id 8자 대조로 전환 / SL-06 1P) PM 원본 해시 대조 단계 신설 /
SL-08 -cnotmatch → [regex]::IsMatch + lint L-D / SL-09 인수 전 캡처를 단일 GET 으로 /
SL-10 파드 서명 빈 입력 거부·nopods 명시·형식 검사, resume 는 continue / SL-11 창 A 세션의 커넥터 종속 경고 + 단어 noglass/no-oci 분리 /
SL-12 OCI_CLI_PROFILE=svc-verify 검사 / SL-13 $kq 런타임 동사 허용 목록 + 13b/13e 를 merge 시점 무장 + lint L-E /
K8S-01(high) 안전망을 "컨테이너 재시작 전까지"로 정정(머리 주석·throw 4곳·복구 안내 0번·restore 헤더·NOTES) + 복구 안내에 현재 파드서명 출력 /
K8S-04 인수 뒤 시작한 Ready 파드가 있으면 드릴 SKIP / K8S-05 드릴이 창 A 세션을 끊을 수 있다는 경고 3곳 /
K8S-06 $recover 를 value/uid 로 분리, UID 전용 안내 / K8S-08 data-hash 를 하드 판정으로 승격 /
K8S-09 -l app=cloudflared / K8S-11 R2 에 finalizer·webhook·확인 명령·refreshTime·managed 라벨 잔존 5항 추가 /
K8S-12 tracking=annotation 확정(대안 문장 삭제) · "2분"→"최대 3∼4분" · 복구 원본 넷째 tofu output

■ 대체 구현: K8S-13(PM==라이브 미검증)은 옳은 지적이고 SL-06 과 같은 사안이라, 제안된 g4-restore 의 verify 분기가 아니라
  g4-adopt 의 1P) 에 넣었다. 근거 3: ① 바로잡을 수 있는 시점은 머지 전이다 ② 복구 블록은 apply 가 모호하게 끝났을 때
  재실행해 해시로 확인하는 비상 경로여서 프롬프트를 늘리면 왕복이 는다 ③ 값이 실제로 덮인 경우에는 원래 토큰을 묻고
  해시로 게이트한다 — K8S-13 이 메우려던 구멍("덮이지 않았는데 예행")이 곧 1P 다.

■ 기각 0건. PS-G4-02 의 부수 항목($dh 위치)은 K8S-08 과 충돌해서, dh 를 OK 줄 앞의 하드 판정으로 올려 양쪽을 동시에 해결했다
  (그러면 "OK 출력과 $log 대입 사이" 구간 자체가 사라진다).

■ 하네스/변이 결과
  pwsh -NoProfile -File harness-g4.ps1   → PASS 67 / 67, lint 실패 0 (검수 전 41/41 → 시나리오 26개 추가)
  pwsh -NoProfile -File mutants-g4.ps1   → 변이 53 개 중 CAUGHT 53 · ESCAPED 0 · ANCHOR-ERR 0 (약 6분)
  파서 오류 0 · 단일 최상위 문 · 빈 줄 0 · CR 0 · TAB 0 · 끝 3바이트 0A 7D 0A (4개 파일 전부)
  하네스 강화: 첫 실행에서 M01/M02(3) 인수 판정의 값·UID 단언 제거)가 빠져나갔다 — 2) 감시 루프가 항상 먼저 잡는
  시나리오밖에 없었기 때문이다. 모의에 "SecretSynced 를 본 직후(폴링 종료 뒤, 3) 이 읽기 전) 값·UID 변경" 결함을 넣고
  G4-06b·G4-07b 를 만들어 3) 만이 잡을 수 있는 창을 고정했다. 그 외 51개는 처음부터 잡혔다.
  새 lint 4종: L-B(변경 헬퍼의 회계가 kubectl 보다 앞) · L-C(변경 헬퍼 필수 플래그) · L-D(비밀 변수에 -match 금지) ·
  L-E($kq 인자에 변경 동사 금지 + finally 의 Remove-Variable 필수 목록). 각각 M42/M50 · M43 · M53 · M22/M35 를 잡는다.
  요구 (h) 는 이제 정적(lint)·런타임($kq 동사 검사)·구조(회계 선행)·동적(변경 로그 정확 일치) 네 겹이고,
  "실행 횟수를 통틀어 삭제 ≤1" 은 nopods 가드 + 인수 후 Ready 파드 SKIP + startTime 최댓값 선정 세 겹이다.

■ 남은 위험(상세 NOTES.md §4 "하네스가 증명하지 못하는 것" · §6)
  1. 컨테이너 재시작은 운영자가 통제하지 못한다(K8S-01). 값이 덮인 채 liveness 실패·OOM·노드 재부팅이 두 파드에
     동시에 오면 아무도 파드를 건드리지 않았는데 전면 잠금이다. 블록은 문면(복구를 미루지 마라 · 재부팅/SUC Plan/drain 금지)만
     남길 수 있다 — **이 항목은 설계(런북 §3)로 올려야 한다.**
  2. 새 jsonpath 3종이 실물 kubectl 로 미검증: 단일 GET 템플릿 `{uid}|{managed}|{data}` · `{.metadata.creationTimestamp}` ·
     `{.status.containerStatuses[0].restartCount}`. 형식이 다르면 오판이 아니라 중단이다.
  3. Argo 3.5.2 가 Missing 상태 ExternalSecret 을 status.resources 에 싣는지 미확인(SL-04 분기의 전제). 싣지 않으면
     R-10 보호가 라이브에서 동작하지 않는다 — ES 가 살아 있을 때의 기존 경고는 그대로다.
  4. `kubectl delete --wait=false` 가 실제로 짧은 단발 호출인지 미확인(응답 손실 가능성은 남고, 그때 문면은
     "요청이 수락됐는지는 알 수 없다"로 바뀐다).
  5. `cut -c1-8 /proc/sys/kernel/random/boot_id` 가 이 노드 이미지에서 8자 hex 를 주는지, `oci iam region list` 가
     이 테넌시에서 성공하는지 미확인(둘 다 실패 시 단어가 noglass/no-oci 로 바뀌는 쪽이라 fail-closed).
  6. 1P 를 skip-pm 으로 건너뛰면 K8S-13 의 위험이 그대로 남는다(경고만 한다).
  7. Ctrl+C 중 finally 절단·FlushInputBuffer 실제 제거율·붙여넣기는 여전히 미재현. PS-G4-01/04 는 구조(회계 선행)로 막았고,
     붙여넣기는 이제 두 블록 모두 "파일 실행만"이라고 적는다.
  8. g4-restore 의 temporary 경로는 K8S-01 의 부산물로 실제 쓸모가 생겼다(ES 가 살아 있어도 ≤5분간 옳은 값을 놓아
     노출 창을 줄인다). 런북에 적을지는 컨트롤러 판단.

산출물(전부 이 디렉터리에만, 저장소 미수정):
  C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-blocks\g4-adopt.ps1
  C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-blocks\g4-restore.ps1
  C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-blocks\harness-g4.ps1
  C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-blocks\mutants-g4.ps1  (신규)
  C:\Users\2401\AppData\Local\Temp\claude\d--code-joshuatech-ver2\df87ded7-ec45-4ac5-a67b-9b974d5bfd59\scratchpad\t045-g4-blocks\NOTES.md
```