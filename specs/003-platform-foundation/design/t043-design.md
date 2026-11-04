# T043 최종 설계 — AOP(Authenticated Origin Pulls) 강제 · Argo CD Ingress `argo.joshuatech.dev`

작성 2026-09-11 · 기반안 **설계안 1(안전 우선·단계적)** + 설계안 2에서 접목 5건(되돌리기 목표 단일화 · 게이트 grep 특정화 · 콜로 게이트 격하 · Ingress 단독 창 · 문서 누락 5곳)
비평 major 5건 전부 반영(keep-alive 판정 순서 · `error` grep · step 12 되돌리기 목표 · 동결 문면 정합 · gitops-repo.md :10 미정정), minor 9건 반영, **미해결 0**(실측 필요 항목은 §7 VD로 이관)
저장소 변경 없음(설계 문서만) · 사실은 전부 사실 수집 4렌즈에서 verified/likely로 확인된 것만 쓰고 likely는 VD 번호를 단다.

---

## 1. 결론 요약

### 1.1 T043의 실제 모양

T043은 "443을 끊을 수 있는 변경"을 **세 번**(Argo Ingress → CA Secret → TLSOption clientAuth) 하는 태스크다. 셋은 같은 Traefik 파드·같은 TLSOption `default`·같은 websecure 엔트리포인트를 건드리므로 **한 창에 한 원인**만 들어가게 PR/커밋을 쪼개고, 단계마다 (1) 합격 문면이 고정된 실측 게이트, (2) 노드 A 직전 파일 사본 재설치라는 ≈15초 되돌리기, (3) 운영자가 붙어 있는 창을 둔다. Traefik 롤아웃은 어느 단계에도 없다(`tlsOptions`는 `templates/tlsoption.yaml` 하나로만 렌더 — T042 실측 반영 ≈15초).

### 1.2 채택한 설계안과 이유

**설계안 1(관찰 단계 경유: `VerifyClientCertIfGiven` → `RequireAndVerifyClientCert`)을 기반으로 채택**한다. 이유 세 가지:

1. **동결 문면과 정확히 겹친다.** tasks.md T038(완료)이 `tlsOptions.default`의 "초기 `VerifyClientCertIfGiven`"을, T043이 그것을 `RequireAndVerifyClientCert`로 "전환"한다고 적는다(tasks.md:117·:122). 계약 hostnames-and-access.md:94, research INGRESS-D5(:915)·:1178, traefik-config.yaml 헤더 :61, 테스트 doc-4 리터럴(:183-187)이 전부 같은 2단계 경로다. 설계안 2(직행)는 계약 :94를 고쳐야 하고, 동결된 T038 문면과의 편차는 계약 정정으로 닫히지 않으며(비평 2 major), 계약에 미실측(525/520 분류)을 확정처럼 적게 된다.
2. **VD 원칙.** "Cloudflare edge가 모든 origin pull에 인증서를 제시하고 우리 CA로 검증된다"는 문서가 명문화하지 않는 외부 서비스 동작이다. Verify 단계는 이것을 **차단 없이** 액세스 로그 `TLSClientSubject`로 증명하는 유일한 저비용 경로이고, Require 승격 뒤에는 인증서 없는 연결이 로그에 도달하지 않아 이 증거를 다시는 얻을 수 없다(렌즈 1 verified).
3. **설계안 2의 반론은 맞지만 결론을 바꾸지 못한다.** 비평 1이 지적한 대로 Verify는 CA 불일치에 대해 Require와 똑같이 443 전면 실패이므로 "무해한 단계"가 아니다 — 이 문서는 그 위험을 관찰 단계가 아니라 **Secret 지문 게이트(설치 전)와 특정 패턴 로그 게이트(설치 30초 뒤)**로 받는다. 관찰 단계가 더하는 비용은 커밋 1·운영자 창 1이고, 없애는 것은 "엣지 미제시 → 전 플랫폼 호스트 525"라는 첫 장애 한 건이다.

설계안 2에서 접목한 것: ① 장애 되돌리기 목표를 **항상 clientAuth 없는 사본**으로 단일화(설계안 1 step 12의 "Verify로 하향"은 CA 불일치에서 복구하지 못함), ② 게이트 grep을 AOP 특정 문구로 한정(`error` 일반 패턴은 T098 전 OTLP 잡음 때문에 항상 ≥1줄), ③ 콜로 다양성은 기록 항목으로 격하, ④ Ingress를 AOP 전에 단독 창에서 노드 내부 curl 200으로 닫기, ⑤ 문서 누락 5곳 추가.

### 1.3 순서(요약)와 근거

```
0  착수 게이트(읽기 전용)          운영자   존 설정 on · Zone-level off · tofu plan 0 · agent-view can-i
1  M1 계약 보강 커밋               컨트롤러 hostnames-and-access.md:94 · gitops-repo.md:10·:19   ← gitops보다 먼저
2  G1 Ingress PR 작성              builder  bootstrap/argocd/ingress.yaml + 주석 4곳
3  G1 머지 · Ingress 실측          운영자   노드 내부 curl 200 · 8080 누출 404 · 브라우저 UI · argo-2 PASS
4  M2 CA Secret 파일 + 테스트      builder  infra/bootstrap/cloudflare-origin-pull-ca.yaml · 지문 고정 스위트 · run-all 1l
5  Secret 설치 · 지문 게이트       운영자   Secret 먼저(clientAuth 전) · 지문·notAfter·키·라벨 4중 대조
6  M3 Verify 커밋                  builder  스위트 1단계(red→green) · 헤더 '관찰 단계 투입'
7  Verify 설치 · 180초 · 양성 증거 운영자   tlsoption spec · 로그 0줄 · auth 404 · TLSClientSubject
8  되돌리기 리허설(선택)           운영자   Job 완료 확인 간격 ≥60초
9  관찰 창(선택 소크)              운영자   기록 항목 — 게이트 아님
10 M4 Require 커밋                 builder  스위트 2단계 · 헤더 절차 4 기대값 반전
11 Require 설치 · 음성 증거        운영자   노드 내부 curl exit 56/35 · auth 404 · aop-1 PASS
12 G2 gitops 문서 PR               builder  README §5/§6/§9/§10 · tlsstore:54 · apps/README:36 · bootstrap/README
13 M5 런북 §3 T043 절 · 체크박스   컨트롤러 tasks.md T043 [X] (49/119)
```

**Ingress를 AOP보다 먼저 두는 이유**(과제 문면의 "AOP → Ingress" 나열 순서와 다른 점을 명시): `argo.`는 Access 앱이 전체 호스트를 덮어 워크스테이션 curl이 항상 302라 오리진 상태를 반영하지 못하고(gitops README §5 표), Require 승격 뒤에는 노드 내부 curl이 인증서 없이 000이 되어 "Ingress가 정말 200을 내는가"를 오리진 측에서 확인할 길이 브라우저뿐이 된다. Ingress 오류(백엔드 포트·ingressClass)와 AOP 오류(CA·순서)를 한 창에 넣으면 귀속이 안 된다(T042 A/B 표와 같은 논리). Verify 단계에서도 노드 내부 curl은 통과하므로 "Secret → Verify → Ingress → Require"도 가능하지만, 단독 창 원칙상 **Ingress 먼저**가 가장 깨끗하다.

### 1.4 결정 목록

| ID | 질문 | 권고 | 사용자 확인 |
|---|---|---|---|
| **D1** | CA Secret `kube-system/cloudflare-origin-pull-ca`의 정본·생성자 | **C** 모노레포 `infra/bootstrap/cloudflare-origin-pull-ca.yaml`(K3s manifests, traefik-config.yaml과 같은 위치·절차) + 지문 고정 정적 테스트 | **필요** (A 수동 Secret이 차선) |
| **D2** | clientAuthType 투입 단계 | **(b)** Verify 관찰(최소 게이트 = TLSOption 반영 뒤 ≥180초 + 새 연결 프로브 ≥3회) → Require. 소크 길이는 선택 | **필요** (직행 (a)는 동결 문면 편차 기록 + 계약 정정이 따라옴) |
| **D3** | Argo Ingress 위치 | `bootstrap/argocd/ingress.yaml` + kustomization resources 1줄, **M1에서 gitops-repo.md:10 보강** | 필요(권고 확정형) |
| **D4** | `argocd-cm` `url` 투입 시점 | **T084**(oidc.config와 한 PR, 재시작 1회) | 필요(권고 확정형) |
| **D5** | Require 뒤 노드 내부 curl 판별의 대체 | **(ii)** 인증서 없이 되는 판별로 교체(openssl s_client · edge auth 404 · 프로브 로그 TLSClientSubject · exit 56/35) + Verify 단계에서 기존 실험 마지막 1회 | 필요(권고 확정형) |
| **D6** | 커밋/PR 분할·순서 | **7건 분리, 계약 먼저**(M1 → G1 → M2 → M3 → M4 → G2 → M5) | 필요(권고 확정형) |

**사용자 결정 불요(설계 확정)**: Argo UI 고아 경고(kube-system Secret)는 `projects/platform.yaml`을 건드리지 않고 gitops '정상 경고' 목록에 기록만(cert-manager-issuers README §3 선례 — 두 설계안·두 비평 모두 동의) · Ingress 형태(§4.1) · 장애 되돌리기 목표 = clientAuth 없는 `pre-t043` 사본 고정 · 게이트 grep = AOP 특정 문구만 · TLSClientSubject 판정은 TLSOption 반영 시각 + ≥180초 이후 프로브로만 · `kubectl delete helmchartconfig`·Secret 선삭제 금지.

### 1.5 최대 차단 위험

**Secret 없이(또는 키 이름 오류·`owner=helm` 라벨·다른 ns) clientAuth가 실리면 websecure 443이 전 호스트에서 무증상으로 죽는다** — Traefik `kubernetes.go:1332-1334`가 Secret 부재를 Warn+continue로 넘기고 `tlsmanager.go:469-472`가 "CAFiles is required"로 tls.Config 생성에 실패 → 모든 HTTP 라우터가 `brokenTLSRouter`, 폴백 `defaultTLSConf`도 nil. 파드는 Ready(liveness 8080 /ping), helm Job 정상, INFO 로그 조용. 이 경로는 **투입 순서(Secret → 지문 게이트 → clientAuth)와 되돌리기 순서(clientAuth 제거 → spec 빈 값 확인 → Secret 삭제)**만이 막는다. 복구 경로는 보전된다: cloudflared 터널(`ssh-a`·`ssh-b`·`k8s`)은 Traefik 443을 경유하지 않는다(tunnel.tf:20-34).

---

## 2. 사용자 결정 목록

각 결정은 독립적으로 물을 수 있다. 권고안을 받아들이면 §5 순서가 그대로 성립한다.

### D1 — AOP CA Secret의 정본 위치와 생성자

Traefik 동작은 세 실행 가능 안에서 동일하다(같은 Secret 값·같은 ns·같은 키). 차이는 재현성·검사·규약뿐이다.

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A** 운영자 수동 `kubectl -n kube-system create secret generic cloudflare-origin-pull-ca --from-file=ca.crt=` (T042 `cloudflare-dns-token` 선례, research.md:227이 이 명령을 이미 기재) | 규약 충돌 0 · 정적 검사 무관 · git에 `kind: Secret` 없음 · 지금 당장 가능 | 'git 밖 라이브 상태'가 **영구** 항목(비밀이 아니라 T045 ESO 이관 경로에도 안 실림) · 지문·만료를 커밋에서 고정 불가 · 재부트스트랩·T114 break-glass에서 사람이 기억 · 삭제 시 자동 복원 없음 | 키 이름을 `authenticated_origin_pull_ca.pem`처럼 잘못 주거나 다른 ns에 만들면 clientAuth 투입 순간 443 전면 중단 — 커밋 리뷰로 못 잡음(운영자 게이트로만) |
| **B** gitops `platform/traefik/`에 `kind: Secret`(값 = 공개 PEM) | Argo selfHeal로 삭제 즉시 복원 · 고아 경고 없음 | 계약 gitops-repo.md:3('ExternalSecret만')·§디렉터리('Middleware·TLSOption·TLSStore만') + gitops kustomization:30·README:148('이 저장소에 비밀은 없다') **4곳 정정 선행** · validate.sh·gitleaks 어느 것도 반응하지 않아 규약 위반이 조용히 들어감 | '공개값이면 Secret을 gitops에' 선례가 k8s-data-ca·Strimzi/CNPG CA로 확산 |
| **C** 모노레포 `infra/bootstrap/cloudflare-origin-pull-ca.yaml` — K3s manifests 파일(traefik-config.yaml과 같은 정본 위치·같은 scp+install 절차) + `tests/infra/cloudflare-origin-pull-ca.tests.ps1`(ns·키·PEM 1블록·개인키 없음·sha256 지문·notAfter 고정) + run-all 슬롯 1l | 계약이 지목한 '정본 = 노드 A server/manifests'와 같은 위치 → 규약 충돌 0(gitops-repo.md:19 병기만) · 의존 대상(HelmChartConfig clientAuth)과 같은 디렉터리라 "Secret 먼저"를 헤더 한 곳에서 규율 · CA 진위·만료가 커밋에 고정(A로는 불가) · 파일이 git에 있어 T114 재현 그대로, k3s 재시작 때 재적용 · A는 C의 부분집합(부트스트랩 창에서는 같은 파일을 manifests에 두면 됨) | 모노레포에 `kind: Secret` 파일 → 오독 가능(헤더 주석 + 테스트로 완화) · x-8은 traefik-config.yaml 한정이라 새 파일 전용 테스트 필요 · gitleaks/push protection 통과는 likely(→ VD-16) · Argo 고아 경고 1건(정상 목록 기록) · `stringData` 재적용 잡음 가능성 미실측(→ VD-18) · 삭제 시 자동 복원은 k3s 재시작/파일 변경 때뿐 | **절대 traefik-config.yaml의 두 번째 문서로 넣지 말 것**(x-8 즉시 FAIL + K3s AddOn objectset이 나중에 분리할 때 Secret을 지워 443 중단 경로) · 파일 삭제 뒤 AddOn 잔존(되돌리기에 `delete addon` 1줄 추가) |
| D T045 ExternalSecret | 시크릿 관리 일원화 | 의존 순서 T043→T044→T045라 T043을 막음 · Vault(wave 10)·ESO(wave 0)는 K3s 번들 Traefik보다 늦게 기동 → 443 가용성이 Vault에 종속 · 공개값을 '시크릿 원천'에 넣는 의미 왜곡 | **각하** |
| E ConfigMap | '비밀 아님'이 kind로 드러남 | Traefik v3.7.8 TLSOption.clientAuth는 `secretNames`만 받음(CRD 스키마 :58-79, `getCABlocks`; ConfigMap 경로는 ServersTransport 전용) | **각하(동작 불가)** |

**권고: C.** 근거: CA 진위(지문)·만료를 커밋에서 고정할 수 있는 유일한 안이고, 투입/제거 순서를 traefik-config.yaml과 같은 디렉터리·같은 절차 안에서 규율한다. 비평 반영: ① run-all 슬롯 1l의 "잔여일 ≥180일" **FAIL 단언은 두지 않는다**(정적 슬롯은 SKIP 경로가 없어 2029-05부터 무관한 finish 게이트까지 막는다) — 정확한 NotAfter 리터럴 단언만 두고 잔여일은 합계 밖 WARN 출력 + T114 월간 점검·VD-20 분기 대조로 감시, ② 헤더에 `PRIVATE KEY`·`BEGIN CERTIFICATE` 낱말을 쓰지 않는다(자기 테스트 충돌 방지 — '개인키 없음'·'PEM 1블록'으로만), ③ M1에서 gitops-repo.md:19에 병기, hostnames-and-access.md:94에 "값은 공개 인증서 — AGENTS.md 비밀 금지의 대상 아님" 한 구절, ④ 되돌리기에 `kubectl -n kube-system delete addon cloudflare-origin-pull-ca` 추가. A를 택해도 §5는 단계 4를 빼고 단계 5의 명령만 바뀐다(§5 단계 5에 A 분기 병기).

### D2 — clientAuthType 투입 단계

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **(a)** 즉시 `RequireAndVerifyClientCert`(설치 1회·스위트 변경 1회) | 커밋·운영자 창 각 1회 절약 · tasks T043 문면 "전환"의 목적지와 일치 | "edge가 인증서를 제시한다"(문서 미명시)와 "우리 CA로 검증된다"를 실증 없이 강제 → 실패 시 v2 플랫폼 호스트 전부 525/520이 첫 장애 · 승격 뒤에는 미제시 vs 불일치를 로그로 구분 못 함 · **동결 T038 "초기 VerifyClientCertIfGiven"·계약 :94·research D5·헤더 :61·doc-4 리터럴과 편차** → 계약 정정 + 편차 기록 + converge 인계가 따라옴 | R4(미제시)와 R1(Secret 오류)이 같은 증상으로 겹쳐 원인 귀속 불가 |
| **(b)** `VerifyClientCertIfGiven` 관찰 → `RequireAndVerifyClientCert`(설치 2회·스위트 변경 2회) | 미제시는 통과되며 `TLSClientSubject` 부재로 드러나고, 제시+검증 성공은 존재로 증명(Verify는 잘못된 인증서를 거절하므로 필드 존재 = 체인 검증 통과) · 승격 전 노드 내부 curl로 판별 실험 ①②·Ingress 200을 마지막으로 돌릴 수 있고 되돌리기 리허설도 무순단 · 승격(Verify→Require)은 새 실패 모드를 더하지 않음(유일한 차이 = 인증서 부재, 이미 관찰로 증명) · 동결 문면·계약·헤더·테스트 리터럴 어느 것도 고치지 않음 | 스위트 2회 변경(v-25 값·x-5), 운영자 창 2회 · **CA 불일치·Secret 오류에 대해서는 Require와 똑같이 443 전면 실패**(Go handshake_server.go: `ClientAuth >= VerifyClientCertIfGiven && len(certs) > 0 → Verify → bad_certificate`) — '무해한 단계'가 아니다 | F2/F3 시 ≈30초 순단(사본 재설치). Secret 지문 게이트(설치 전)와 특정 패턴 로그 게이트(30초 뒤)가 받는다 |
| (c) `RequestClientCert`(요청만, 검증 없음) → Verify → Require | 1단계는 CA 유무·일치와 무관하게 실패 모드 0 | 미제시 탐지는 (b) Verify도 순단 없이 해내고 불일치는 어차피 Verify에서만 드러남 → 새 정보 없음 · 스위트 3회 · 문서·테스트 어디에도 예고 없는 제3의 값 | **과잉** — 단 (b) 관찰에서 `TLSClientSubject`가 비어 나올 때 원인 판별용 **비상 진단 경로**로만 보유 |

**권고: (b).** 관찰 판정(비평 1 반영으로 재정의): ① `get tlsoption default` spec에 Verify 반영 확인 → ② 그 시각으로부터 **≥180초**(Traefik `respondingTimeouts.idleTimeout` 기본값 — edge↔오리진 keep-alive 연결이 옛 tls.Config로 살아 있는 상한, VD-5) → ③ 그 뒤 `auth` `/__probe-404` 프로브 ≥3회(간격 ≥1분)의 로그 줄 **전부**에 `TLSClientSubject` 비어 있지 않음 → ④ 같은 창에 AOP 특정 오류 패턴 0줄 + edge auth 404 유지. CF-Ray 콜로 접미사는 **기록 항목**(운영자 워크스테이션은 거의 같은 콜로에 붙어 '2종 이상'을 게이트로 걸면 진행이 막힌다). 소크 길이(다음 운영자 창까지 vs 24h)는 사용자 선택이며 게이트가 아니다 — `logs --since=24h`는 OTLP 잡음으로 로그 회전 한도를 넘을 수 있어 24h 전 줄 판정은 정의상 검증 불가. (a)를 택하면: 런북 '사용자 결정'과 '문면 편차'에 T038 초기값·계약 :94·research D5와의 편차를 기록하고, 계약 :94는 전환 순서 문장만 바꾸며(근거·525/520 분류는 런북 VD로), converge에 tasks T038/T043 편차를 인계한다.

### D3 — Argo CD Ingress의 gitops 위치

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **`bootstrap/argocd/ingress.yaml`** + kustomization `resources:` 1줄(`platform-argocd`가 sync) | 계약 §디렉터리(:20 "platform/argocd = bootstrap/argocd를 소스로") · `platform-argocd` source.path · bootstrap/argocd 머리 3) 예고문 · validate 7.1 허용 경로(:861)와 일치 · `namespace: argocd` 변환기가 있어 ns 생략 · `manifest-generate-paths: .`에 포함 · AppProject `platform`은 namespaced 리소스 제한 없음 · 검사 1이 kubeconform으로 스키마 검증 | Argo CD 내장 Ingress health가 `status.loadBalancer.ingress`를 요구 → publishedService가 못 채우면 `platform-argocd` Progressing 고착(cluster argo-1·reboot-3 FAIL) → VD-13 · **계약 gitops-repo.md:10이 `argocd/`를 "remote base + patches"로만 정의** → M1에서 보강 필요(비평 2 major) | 낮음. 백엔드 포트 https/443·entrypoints 누락은 validate가 못 잡음 → PR 체크리스트 |
| `platform/argocd/`(자리표시) + `platform-argocd` source 이동 | 'platform/<component>' 트리 일관성 | source 이동 + install.yaml 이중 렌더 위험 + 자리표시 파일 머리가 명시적으로 금지("실제로 쓰면 source를 함께 옮겨야 한다") · 자기 관리 Application까지 변경 반경 확대 | 높음(자기 참조 잠김) |

**권고: bootstrap/argocd/ingress.yaml**, 단 **M1에서 gitops-repo.md:10을 "remote base + patches + `ingress.yaml`(Ingress `argo.` — T043; platform/argocd는 자리표시 유지)"로 보강**하고 G1은 그 뒤에 낸다(계약 커밋이 gitops보다 먼저 — CLAUDE.md 규율).

### D4 — `argocd-cm` `url: https://argo.joshuatech.dev`를 T043에 넣는가

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| 지금(G1에 동봉) | gitops bootstrap/README:215 문면과 일치 | UI·admin 로그인·`--grpc-web`에 불필요(문서상 SSO 콜백용) · server.go가 url 변경 시 argocd-server 재시작("url modified. restarting") → T084 oidc.config 때 또 1회 · argocd-cm.yaml:5 머리("아직 넣지 않는 것: url · oidc.config · admin.enabled")·tasks.md T084(SSO 일체)와 어긋남 · 권한 확대 경계 파일을 T043에서 건드림 | 낮지만 실익 0 |
| **T084(oidc.config와 한 PR)** | 재시작 1회 절약 · 머리 주석·tasks.md와 일치 | README:215·argocd-cm.yaml:5의 'T043' 문구를 T084로 정정(G1 주석만) | 없음 |

**권고: T084.** 그때 `url: https://argo.joshuatech.dev`(research :534의 `argocd.` 아님)와 Authentik redirect URI `https://argo.joshuatech.dev/auth/callback` — 호스트 불일치는 converge 인계.

### D5 — Require 뒤 노드 내부 직접 curl이 000이 되는 문제의 대체

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| (i) 진단용 자체 CA를 `secretNames`에 추가 + 운영자 클라이언트 인증서 | 기존 curl 절차 유지 | 공개 443 신뢰 앵커에 운영자 CA 추가 → 계약 '오리진 보호 3중'(AOP CA 단일) 확대 · 보호할 개인키·회전 항목 신설(T084 매트릭스) · 얻는 실험 ②(SNI 불일치)는 sniStrict 때문에 어차피 옵션 제거가 필요해 실익 거의 없음 | 과잉 + 새 비밀 자산 |
| **(ii)** 인증서 없이 되는 판별로 교체: 서버 인증서 = `openssl s_client -servername`(CertificateRequest 이전에 전송) · 443 생존 = edge `auth` 404(526/525/520 아님) + 공개 CT · TLSOption 반영 = spec + Traefik 로그 · AOP 양성 = `/__probe-404` 액세스 로그 `TLSClientSubject` · AOP 음성 = 노드 내부 curl **exit 56/35 + 000**을 합격값으로 반전 · 판별 실험 ①②는 '승격 전 마지막 점검' + '재투입 절차 전용'으로 재분류 | 새 자산 0 · 계약 불변 · 모든 판정이 운영자 admin kubectl/ssh 또는 공개 경로 | 두 문서(traefik-config 헤더 :116-127, gitops README §9)와 cert-manager-issuers README의 노드 내부 curl 문장 갱신 필요 | `TLSClientSubject` 필드명·기본 keep은 v3.7.8 `logger.go`로 verified, 실제 JSON 리터럴은 첫 프로브에서 확정(VD-6) |
| (iii) Verify 단계에서만 기존 실험 후 폐기 | 문서 변경 최소 | 승격 뒤 526/525 진단 절차 소실 | 장애 시 판별 수단 부재 |

**권고: (ii) + (iii)의 '승격 전 마지막 점검' 결합.** SNI 불일치 000과 인증서 부재 000의 구분은 `curl -v` stderr(`unrecognized name`/서버 종료 vs `certificate required`/`bad certificate` alert)로 런북 판별표에 고정한다.

### D6 — 커밋/PR 분할과 순서

| 옵션 | 장점 | 단점 | 위험 |
|---|---|---|---|
| 한 번에: gitops PR 1(Ingress) + 모노레포 커밋 1(Secret+Require+테스트+문서) | 커밋 수 최소 | Ingress·Secret·clientAuth 실패가 한 창에 겹쳐 귀속 불가 · 스위트가 관찰 단계를 못 거침 · 문서에 실측값을 못 적음 | 높음 |
| **7건 분리, 계약 먼저**: M1 계약 → G1 Ingress(단독 머지·검증) → M2 CA Secret 파일+테스트 → [설치·지문 게이트] → M3 Verify+스위트 1단계 → [설치·관찰] → M4 Require+스위트 2단계 → [설치·음성 증거] → G2 gitops 문서 + M5 런북·체크박스 | 각 창의 실패가 한 변경에 귀속 · TDD가 커밋 단위로 드러남(헌법 II) · 계약 커밋이 gitops보다 먼저 · 실측값을 문서에 적을 수 있음 | 커밋 5 + PR 2, 운영자 창 4회 + 관찰 | 낮음. G1 주석 정정(kustomization:41·argocd-cm:5·cmd-params:9·bootstrap README)은 G1에 동봉해 '만들지 않는 것' 문면이 머지 순간 거짓이 되지 않게 |

**권고: 7건 분리.** M3·M4는 각각 '테스트 수정 → FAIL 확인 → yaml 수정 → PASS'를 한 커밋 안에서 남긴다(T043 안의 단계별 커밋). 비평 반영: network-policy.md 포트 각주에 `argocd 8080` 행 추가는 **M1에서 뺀다**(각주는 helm 차트 기본값 포트 목록이고 validate PORT_TABLE이 그 사본이라 한쪽만 고치면 조용한 드리프트) → T047에서 PORT_TABLE과 같은 창에 처리.

---

## 3. 사실 근거

confidence: **V** = verified(소스·실측), **L** = likely(문서·추론 → VD 번호).

### 3.1 Traefik v3.7.8 mTLS 동작(소스 발췌 4파일 + upstream raw + doc.traefik.io)

| # | 사실 | 등급 |
|---|---|---|
| T1 | `clientAuthType` 문자열은 Go `tls.ClientAuthType`에 1:1 매핑(`tlsmanager.go:474-487`). Verify = 인증서 부재 통과·제시 시 반드시 CA 검증 통과; Require = 부재도 실패. 두 모드의 유일한 차이 = 인증서 부재 케이스 | V |
| T2 | `secretNames`(=CAFiles)만 주고 `clientAuthType`을 생략하면 암묵적으로 `RequireAndVerifyClientCert`(`tlsmanager.go:448-465`) — 관찰 단계에서 줄 하나 빠뜨리면 곧바로 강제 | V |
| T3 | CA 부재(Secret 없음·키 불일치·PEM 파싱 실패) + Verify/Require → `invalid clientAuthType: …, CAFiles is required` → tls.Config nil → `AddHTTPTLSConfig(domain, nil)` = `brokenTLSRouter`, 폴백 `defaultTLSConf`도 nil → **websecure 전 호스트 TLS 중단**, 파드 Ready 유지(`manager.go`·`router.go` raw v3.7.8, `kubernetes.go:1332-1334` Warn+continue) | V |
| T4 | Require 거절은 액세스 로그에 남지 않는다(핸드셰이크에서 종료 → `logTheRoundTrip` 미도달). Go http.Server `TLS handshake error` 메시지는 DEBUG 추정(`--log.level=INFO`) | L → VD-9 |
| T5 | 액세스 로그 JSON core 필드 `TLSClientSubject`(= `req.TLS.PeerCertificates[0].Subject.String()`, 피어 인증서 ≥1일 때), `TLSVersion`·`TLSCipher`(HTTPS면 항상). 헤더가 아니라 core 필드라 `fields.headers.defaultmode: drop` 무관, `fields.defaultmode=keep`(rendered.yaml:214-216) → 설정 변경 없이 이미 기록. 필터 `statuscodes=400-599`라 302/200 줄은 없음 → `auth` 404 프로브가 유일한 저비용 경로 | V(필드 존재) / L(리터럴 `CN=origin-pull.cloudflare.net,OU=Origin Pull,O=CloudFlare\, Inc.` — Go pkix.Name.String() 추론) → VD-6 |
| T6 | Secret 키 읽기 `tls.ca` → `ca.crt`, 둘 다 없으면 오류. type 무관. TLSOption 경로에는 ServersTransport의 단일 키 폴백이 없다. ConfigMap 불가(`kubernetes.go:1591-1603`, :1325-1344, CRD :72-77) | V |
| T7 | 다중 CA: `secretNames` 각 항목이 CAFiles 하나, `pool.AppendCertsFromPEM` 합집합. 한 Secret 값에 PEM 여러 블록 가능. 어느 하나라도 파싱 실패면 전체 실패 | V |
| T8 | Secret 변경은 자동 반영: CRD provider가 전 ns Secret informer(`crd_client.go:239-243`) + `throttleDuration` 미설정 → 즉시 재빌드. 라벨 `owner=helm` Secret은 informer 필터 제외 = '없는 Secret' | V |
| T9 | **Secret 삭제 = 443 전면 중단**(T3 경로). 되돌리기 순서 = clientAuth 제거 → TLSOption spec 확인 → Secret 삭제. 투입은 그 반대 | V |
| T10 | TLSOption은 자기 ns(kube-system)에서만 Secret을 읽는다(`kubernetes.go:1326`). agent-view는 Secret get 없음 → 존재 확인은 운영자 admin | V |
| T11 | sniStrict와 clientAuth는 같은 tls.Config에 공존. Go 서버 핸드셰이크는 GetCertificate(SNI 판정) → CertificateRequest → 클라이언트 인증서 검증 순 → SNI 불일치는 인증서 유무 무관 000 | L(표준 라이브러리 순서) → VD-8 |
| T12 | TLS 설정은 라우터 Host 도메인별 등록, 옵션 이름 없는 라우터 = `default`. 대시보드 IngressRoute·Argo Ingress 둘 다 옵션 미지정 → TLSOption `default`의 clientAuth가 websecure 전 라우터에 적용, Ingress에 `router.tls.options` 불필요 | V |
| T13 | 라우터가 tls 섹션이 없으면 엔트리포인트 `http.tls=true` 모델이 복사됨(`aggregator.go applyModel`). `router.tls: "true"`·`spec.tls`는 엔트리포인트 TLS를 **병합 없이 대체** — `router.tls: "true"`(옵션 없음)는 결과 동일하나 실측 | L → VD-11 |
| T14 | IngressClass `traefik`(is-default-class true), provider에 `ingressClass` 필터 없음 → `spec.ingressClassName: traefik` 명시 시 처리 | V |
| T15 | `router.entrypoints: websecure` **필수**: 차트 40.1.x는 어느 포트도 `asDefault`가 아니라(values.yaml:927) 생략 시 라우터가 traefik(8080)·metrics(9100)·web(8000) 전부에 붙음 | L → VD-12 |
| T16 | 백엔드 스킴: Service 포트 443 또는 이름 `https*`면 TLS(`getProtocol`). Argo Service `argocd-server` http 80→8080 · https 443→8080 → **`port.name: http`** 고정(https/443이면 평문 8080에 TLS 시도 → 502) | V |
| T17 | gRPC-Web은 HTTP/1.1 POST라 단일 HTTP Ingress로 통과; h2c 라우트는 네이티브 gRPC 전용 | L(Argo 문서) — 단 Cloudflare Access가 gRPC 미지원(V, A2)이라 h2c 경로는 애초에 성립 안 함 |
| T18 | 되돌리기는 대칭: clientAuth 블록 없는 파일 재설치 → 템플릿 `{{- with $config.clientAuth }}`가 키 자체를 제거 → `NoClientCert`. 파드 롤아웃 없음, ≈15초 + helm Job ≈5초. **새 핸드셰이크부터** 적용, 수립된 연결은 무영향 | V |
| T19 | 되돌리기 수단은 노드 A 보존 사본 재설치뿐. `kubectl delete helmchartconfig traefik`은 T038 전량 소실(T042 R8) | V |
| T20 | 액세스 로그 프로브 판정은 **새 연결**에서만 유효 — edge↔오리진 keep-alive 연결은 옛 tls.Config로 살아 있다(T18 귀결). idleTimeout 기본 180s(doc.traefik.io `respondingTimeouts.idleTimeout`) | L → VD-5 |
| T21 | 정적 스위트 현재 69 passed / 0 failed(2026-09-11 재실행). v-20·x-6·doc-4가 Verify 투입에, x-5가 Require에 FAIL → 단계별 반전 필요. x-8은 `$raw`(traefik-config.yaml 한 파일)만 검사 | V |
| T22 | 소형 파서 함정: 인라인 주석이 값에 포함(`'VerifyClientCertIfGiven   # …'`), 플로우 리스트 `[…]`는 Seq가 아니라 Scalar → valuesContent는 주석 없는 블록 리스트만. CRD enum 검증이 잘못된 값의 TLSOption을 거부해 helm Job만 실패, 기존 TLSOption 유지(443 무영향) | V |

### 3.2 Cloudflare AOP 동작(developers.cloudflare.com + Go crypto/tls + 실측)

| # | 사실 | 등급 |
|---|---|---|
| C1 | T011의 `tls_client_auth=on`은 **Global AOP**. Zone-level(고객 업로드 인증서, `/origin_tls_client_auth/settings`)·Per-hostname은 독립. 대시보드 Global 토글을 봐야 함 | V |
| C2 | Global AOP는 존의 **모든 proxied 호스트 origin pull**에 Cloudflare 제공 인증서 제시. 전제 SSL Full 이상(우리 `strict`) | V(문서) — "모든 핸드셰이크에 실제로 제시"는 명문화 없음 → VD-6 |
| C3 | 터널 오리진(`ssh-a`·`ssh-b`·`k8s`)에는 무효과 → T043 영향권 밖 | V |
| C4 | Workers same-zone `fetch()`(edgeWorkerFetch)에 AOP 인증서가 제시되는지 문서 미명시. Worker 자체 mTLS 바인딩은 proxied 존에 불가(520) | L → VD-21(T043 밖) |
| C5 | 문서 PEM = 우리 측정 CA: 2154바이트 1블록, subject=issuer `C=US, O=CloudFlare, Inc., OU=Origin Pull, L=San Francisco, ST=California, CN=origin-pull.cloudflare.net`, notBefore 2019-10-10 18:45 GMT, **notAfter 2029-11-01 17:00 GMT**, sha256 `9A:1A:C2:B4:BE:15:F9:F2:7E:EE:20:A7:34:CB:A4:E9:89:8F:61:00:1B:3B:D7:C8:4B:69:B5:6A:3E:25:A2:B9`, ETag `b0b28c5a814263fa93aebdb1a3803323`, `CA:TRUE pathlen:2`. 루트 CA(edge는 이 CA가 서명한 leaf 제시) | V |
| C6 | Cloudflare는 Global CA 교체·만료 알림을 제공하지 않는다(changelog·문서). cloudflare-docs 정적 파일 마지막 커밋 2024-08-14(사이트 이전) | V |
| C7 | 현 상태(AOP on, Traefik `NoClientCert`)는 무해 — 서버가 CertificateRequest를 보내지 않으면 인증서는 전송되지 않는다(Go handshake_server.go:606). T011 이후 v1·v2 proxied 호스트 정상 응답이 실측 증거 | V |
| C8 | **Verify는 관찰용 무해 단계가 아니다**: 인증서가 오면 반드시 검증(handshake_server.go:970-996) → CA 불일치 시 Require와 동일하게 443 전면 실패 | V |
| C9 | 오리진 거절 alert: 인증서 없음 → TLS1.2 `handshake_failure`(40, curl exit 35) / TLS1.3 `certificate_required`(116, post-handshake → curl exit 56); 검증 실패 → `bad_certificate`(42). aop-1 화이트리스트 {35,56}이 둘 다 덮음. edge↔오리진은 TLS1.3 가능성 높음 | V(Go) / L(TLS 버전) → VD-8 |
| C10 | 525 = edge↔오리진 핸드셰이크 실패, 526 = 오리진 **서버** 인증서 검증 실패. **AOP 실패는 526이 아니다.** TLS1.3 post-handshake alert를 525로 분류하는지 520인지 문서 없음 | L → VD-7(판정 기준 '525 또는 520 = AOP 불일치') |
| C11 | 읽기 전용 확인: `GET /zones/{id}/settings/tls_client_auth`(Zone Settings Read) `result.value=="on"`·`editable`; `GET …/origin_tls_client_auth/settings` `enabled==false`. API 스키마의 "(Enterprise Only)" 문구는 낡음(가용성 표 Free: Yes, T011 apply 성공) | V |
| C12 | `tofu plan` No changes = on(refresh 단계 GET) — 전제: `-refresh=false` 아님, 상태에 리소스 존재 | L → VD-1 |
| C13 | v1 잔재 호스트 전부 proxied → Global AOP가 인증서를 내밀지만 오리진이 요구하지 않으면 무영향. 2026-09-11 실측: apex 200 · api/mainapi/mcp/cdn 404 · www 522 · **cache 15초 타임아웃(curl 28)** — AOP 무관 별건 | V |
| C14 | Access 앱 `argo`(GitHub IdP, 24h)는 edge에서 처리되고 origin pull은 그 뒤 → AOP와 충돌 없음. argo 302 Location의 `mtls_auth.cert_presented:false`는 방문자→edge 필드(AOP 무관) | V |
| C15 | Global CA는 전 Cloudflare 계정 공유 → "Cloudflare 망에서 왔다"만 보증. 계정 교차 우회의 오리진 측 통제는 Access + T084 forward-auth + 앱 JWT | V |

### 3.3 Argo CD Ingress(v3.5.2 소스·문서 + gitops 실파일)

| # | 사실 | 등급 |
|---|---|---|
| A1 | `server.insecure: "true"`면 8080 하나에서 HTTP/1.1·gRPC(h2c)·gRPC-Web 전부 서빙(`grpcweb.WrapServer` + cmux) → `argocd login --grpc-web`은 단일 HTTP Ingress로 동작 | V |
| A2 | Cloudflare gRPC 존 설정 기본 비활성(403) + "Access does not support gRPC" → research D11의 h2c 2-rule IngressRoute는 죽은 경로, 계약 "grpc-web"·spec FR-011 표준 Ingress·T032 argo-2가 정합 | V |
| A3 | 렌더 IngressClass `traefik`, `--providers.kubernetesingress` + `publishedservice=kube-system/traefik`, `--entryPoints.websecure.http.tls=true` | V |
| A4 | 배치 = `bootstrap/argocd/kustomization.yaml` resources(계약 :10·:20, platform-argocd source.path, platform/argocd 자리표시 머리, bootstrap/argocd 머리 3) 예고) | V |
| A5 | `platform-argocd`: `automated {prune:false, selfHeal:true}` + SSA, `manifest-generate-paths: .` → 머지만으로 SSA 생성(폴링 180s, 즉시는 refresh 어노테이션). AppProject `platform`은 namespaced 리소스 제한 없음 | V |
| A6 | `argocd-cm url`은 SSO 콜백용, UI·CLI에 불필요, 변경 시 서버 재시작 | L(문서+소스) → T084 |
| A7 | Access `CF_Authorization` 쿠키가 같은 오리진 XHR·SSE에 자동 첨부 → UI 전체 한 로그인. Cloudflare 100초 무응답 타임아웃이 SSE에 걸리는지 미확인 | L → VD-14 |
| A8 | argo-2 = agent-view `get ingress -A` rules[].host 일치(ns·이름 불문). aop-1은 운영자 PC NSG 28로 T043 전후 불변 | V |
| A9 | agent-view(ClusterRole `view` 집계)가 ingresses list 가능 | L → VD-15 |
| A10 | validate.sh 검사 1이 bootstrap/argocd를 렌더+kubeconform(Ingress 기본 카탈로그) → 자동 검증. 5.4는 반응 없음(8080 행 없음, 방향 표→정책). validate.yml은 T003 골격(CI = gitleaks만) | V |
| A11 | Access 앱 `argo`는 T011 access.tf에 이미 존재 → T043에 Cloudflare 변경(tofu) 없음 | V |
| A12 | CLI 로그인의 Access 통과 헤더(`cf-access-token` vs Service Auth) 미확인 | **unverified** → VD-22(T084) |
| A13 | Argo 내장 Ingress health는 `status.loadBalancer.ingress` 채움을 요구 → publishedService가 svclb 상태를 복사해 Healthy가 될 것 | L → VD-13 |

### 3.4 CA Secret 배치·규약(계약·검사 실파일)

| # | 사실 | 등급 |
|---|---|---|
| S1 | (B) gitops Secret은 계약 :3·§디렉터리 + gitops kustomization:30·README:148 4곳과 정면 충돌. validate.sh·gitleaks는 무반응(규약 위반이 검사로 안 드러남) | V |
| S2 | gitleaks 기본 규칙에 `BEGIN CERTIFICATE` 규칙 없음(`private-key`는 "PRIVATE KEY" 필수). 두 저장소 push protection enabled, 공개 인증서 패턴은 없는 것으로 알려짐 — 미실측 | L → VD-16 |
| S3 | (C) 모노레포: x-8은 traefik-config.yaml만, run-all·hooks에 전역 비밀 스캔 없음 → 새 파일 별도 테스트. **traefik-config.yaml 두 번째 문서로 넣으면 x-8 FAIL + AddOn objectset 분리 시 Secret 삭제** | V |
| S4 | K3s manifests: 시작 시·파일 변경 시 적용, 다중 문서 가능, kind 제한 없음, 파일 삭제로 리소스 삭제 없음(AddOn 잔존). `k3s-server.sh`는 커스텀 manifests 설치 미자동화 → scp+install 수동 | L → VD-18 |
| S5 | Argo 고아 경고: AppProject `platform` `orphanedResources.warn: true` + platform-traefik destination kube-system → 경고 1건. cert-manager-issuers README가 같은 부류를 "정상, 지우지 않는다"로 기록 | V |
| S6 | (A) 선례: 런북 §3 T042 'git 밖 라이브 상태' 목록(`cloudflare-dns-token`). research.md:225-227이 (C)를 "공개 CA이므로 bootstrap manifest로 배치 가능"으로 이미 예고 + `kubectl create secret` 명령 병기 | V |
| S7 | (D) 각하: 의존 순서 T043→T044→T045, Traefik(K3s 번들)이 Vault(wave 10)·ESO(wave 0)보다 먼저 기동 | V |
| S8 | 두 저장소 모두 PUBLIC → 공개 인증서를 어디 두든 공개 범위 동일 | V |

### 3.5 테스트·문서·절차 영향(실파일 줄 번호)

| # | 사실 | 등급 |
|---|---|---|
| E1 | run-all 슬롯 1k 판정 `^\d+ passed, 0 failed` — 단언 수 증가 무관 | V |
| E2 | 파서 프로브: 제안 블록의 Keys 3개 추가·Seq count=1·Sort-Object와 Ordinal 정렬 동일(6키) | V |
| E3 | `$allNames`(:53-60)에 신설 단언 등록 필수(파일 부재 fail-closed). doc-6(:191-193)는 리터럴 '의도적 편차' 요구 → 헤더 :41-42는 과거형으로 보존 | V |
| E4 | x-8(:342-345)은 `$raw` 전체에 `BEGIN CERTIFICATE` 금지 → 헤더에 낱말 자체 금지(지문·CN·만료·URL 가능, x-9 URL 금지는 valuesText 한정) | V |
| E5 | 헤더 :112 `grep -Ei 'error|…'   # 비어야 정상`은 :64-66("T098 전 OTLP 오류 로그 주기 적재")과 모순. 런북 :296 'Traefik 오류 로그 0건'과도 미확정 | V(모순) → VD-4에서 패턴 특정화 |
| E6 | cluster.tests.ps1 argo-1(전 Application Healthy)·reboot-3이 platform-argocd Healthy 조건으로 간접 영향 | L → VD-13 |
| E7 | 회전·만료 캘린더 정본 `docs/runbooks/secret-rotation.md`(T084 작성, T114 완성)는 아직 없음 → T043은 런북 §3·계약 :94·헤더 세 곳에 기록, 등재는 T084 | V |
| E8 | T043 뒤 낡는 문면(비평 보강 포함): traefik-config 헤더 :41-42·:53-61·:68·:109·:112·:116-127; gitops platform/traefik/README.md :79-82·:156·:187-194·:209·:291·§9·§10④; platform/traefik/kustomization.yaml:22-27; **platform/traefik/tlsstore-default.yaml:54**; **clusters/oci-k3s/apps/README.md:36**; bootstrap/README.md :125-137·**:209**·:215; bootstrap/argocd/kustomization.yaml:52; argocd-cm.yaml:5; argocd-cmd-params-cm.yaml:9; **infra/cloudflare/zone_settings.tf:26-27**; docs/runbooks/bootstrap.md :250·:118·:321; **docs/decisions/0010-secrets.md:33**(ADR 본문 편집 금지 → 런북 기록만) | V |

---

## 4. 파일 트리 · 매니페스트

### 4.0 변경 파일 트리

```
D:/code/joshuatech_ver2  (모노레포, 브랜치 003-platform-foundation)
├── specs/003-platform-foundation/contracts/
│   ├── hostnames-and-access.md        M1  :94 보강(Secret 위치·키·정본·지문·판정·'공개값' 구절)
│   └── gitops-repo.md                 M1  :10 argocd/ 에 ingress.yaml 병기 · :19 cloudflare-origin-pull-ca.yaml 병기
├── infra/bootstrap/
│   ├── cloudflare-origin-pull-ca.yaml M2  신규(D1=C) — §4.2
│   └── traefik-config.yaml            M3/M4 tlsOptions 블록(§4.3) + 헤더(§8)
├── tests/infra/
│   ├── cloudflare-origin-pull-ca.tests.ps1  M2 신규 — §4.4
│   └── traefik-config.tests.ps1       M3/M4 v-20·v-25·v-26·x-5·x-6·doc-4·doc-18·$allNames
├── tests/run-all.ps1                  M2  슬롯 1l
├── docs/runbooks/bootstrap.md         M5  §3 T043 절 · :250 · :118
└── specs/003-platform-foundation/tasks.md  M5  T043 [X]

D:/code/platform-gitops  (main d3950dd)
├── bootstrap/argocd/
│   ├── ingress.yaml                   G1  신규 — §4.1
│   ├── kustomization.yaml             G1  resources += ingress.yaml · 머리 3) 갱신
│   ├── argocd-cm.yaml                 G1  :5 주석(T043 → T084)
│   └── argocd-cmd-params-cm.yaml      G1  :9 주석 과거형
├── bootstrap/README.md                G1  ⑥(:125-137) · :209 · :215
├── platform/traefik/
│   ├── README.md                      G2  §5·§6·§9·§10④·:79-82·:156·:291 · 고아 경고 정상 목록
│   ├── kustomization.yaml             G2  :22-27 현재형
│   └── tlsstore-default.yaml          G2  :54 현재형
├── clusters/oci-k3s/apps/README.md    G2  :36 각주
└── platform/cert-manager-issuers/README.md  G2 (VD-23 grep 결과에 따라)
```

### 4.1 `D:/code/platform-gitops/bootstrap/argocd/ingress.yaml` (G1)

```yaml
# bootstrap/argocd/ingress.yaml — Argo CD UI/API 공개 진입점 `argo.joshuatech.dev` (T043)
#
# 정본 계약: 모노레포 specs/003-platform-foundation/contracts/hostnames-and-access.md(호스트 argo. · Access 앱 `argo` GitHub IdP · TLSOption default)
#   · spec FR-011(표준 networking.k8s.io Ingress · ingressClassName traefik · router.tls true · spec.tls 생략)
#   · contracts/network-policy.md :82(kube-system(traefik) → argocd 8080 — platform/policies allow-from-traefik, 이미 라이브)
#   · contracts/gitops-repo.md :10(argocd/ = remote base + patches + ingress.yaml).
# 형태 근거(Traefik v3.7.8 ingress provider · Argo CD v3.5.2):
#   - 백엔드는 Service argocd-server 의 포트 **`http`(80→8080)** 다. `https`/443 을 적으면 Traefik 이 평문 8080(argocd-cmd-params-cm
#     `server.insecure: "true"`)에 TLS 를 시도해 502 가 난다(포트 443 또는 이름 https* → 백엔드 TLS 규칙).
#   - `router.entrypoints: websecure` 는 **필수**다. 차트 40.1.x 는 어느 엔트리포인트도 asDefault 가 아니라, 생략하면 이 라우터가
#     traefik(8080)·metrics(9100)·web(8000) 엔트리포인트에도 붙는다(클러스터 내부에서 Access 미경유 평문 경로).
#   - `router.tls: "true"` 는 websecure 의 `http.tls=true` 와 등가라 중복이지만 FR-011 문면이므로 둔다. `router.tls.options` 는 적지 않는다 —
#     옵션 이름이 없는 라우터는 kube-system TLSOption `default`(minVersion · sniStrict · T043 clientAuth)를 받는다.
#   - `spec.tls` 없음: 인증서는 TLSStore default 의 certificates 목록(와일드카드 *.joshuatech.dev, T042)이 SNI 로 고른다.
#   - gRPC-Web(`argocd login … --grpc-web`)은 HTTP/1.1 POST(application/grpc-web+proto)라 이 Ingress 하나로 UI·CLI 가 된다.
#     네이티브 gRPC(h2c) 라우트는 두지 않는다 — Cloudflare Access 가 gRPC 를 지원하지 않아 edge 에서 성립하지 않는다
#     (research ARGOCD-D11 의 2-rule IngressRoute 는 spec FR-011 보다 낡은 결정 — converge 정정 대상).
#   - metadata.namespace 를 적지 않는다 — kustomization.yaml 의 `namespace: argocd` 가 붙인다(패치 원칙과 동일).
#   - CLI 로그인은 Access 앞단 때문에 헤더(cf-access-token 또는 Service Auth 쌍)가 따로 필요하다 — T084 실측 항목. T043 수용 기준은 브라우저 UI.
# 되돌리기: 이 파일 제거 PR 을 머지해도 platform-argocd 는 prune:false 라 객체가 남는다 → 운영자 `kubectl -n argocd delete ingress argocd-server`.
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/part-of: argocd
    app.kubernetes.io/component: server
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
spec:
  ingressClassName: traefik
  rules:
    - host: argo.joshuatech.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  name: http
```

`bootstrap/argocd/kustomization.yaml`: `resources:` 목록에 `- ingress.yaml` 1줄 추가; 머리 "이 디렉터리가 만들지 않는 것" 3)의 Ingress를 "만드는 것(T043 ingress.yaml)"으로 옮기고 남는 항목을 "Authentik OIDC(url·oidc.config)·RBAC·알림: T084"로.

### 4.2 `D:/code/joshuatech_ver2/infra/bootstrap/cloudflare-origin-pull-ca.yaml` (M2, D1=C 채택 시)

PEM은 builder가 M2에서 `https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem`을 **다시 받아** 지문 대조 뒤 붙인다(아래 본문은 사실 수집의 라이브 사본 — 전사 오류는 테스트 p-4 지문 단언이 잡는다). 헤더에 `PRIVATE KEY`·`BEGIN CERTIFICATE` 낱말을 쓰지 않는다(자기 테스트 충돌 방지).

```yaml
# infra/bootstrap/cloudflare-origin-pull-ca.yaml — Cloudflare Global AOP 루트 CA(공개 인증서) → kube-system Secret cloudflare-origin-pull-ca — 003-platform-foundation T043
#
# ⚠ 이 파일의 `kind: Secret` 은 비밀이 아니다. 값은 Cloudflare 가 공개 배포하는 **루트 CA 인증서**(개인키 없음)이고 원본은
#   https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem (2026-09-11 조회: 2154 바이트 · ETag b0b28c5a814263fa93aebdb1a3803323).
#   AGENTS.md "Secrets never enter the repository" 의 예외가 아니라 대상이 아니다(contracts/hostnames-and-access.md :94).
#   Secret kind 인 이유: Traefik v3.7.8 TLSOption.clientAuth 는 `secretNames` 만 받는다(ConfigMap 불가 — kubernetes.go getCABlocks 가 Secret 의
#   키 `tls.ca` → `ca.crt` 순으로 읽는다; ConfigMap 경로는 ServersTransport 전용). type 은 무관(Opaque).
#   subject = issuer: C=US, O=CloudFlare, Inc., OU=Origin Pull, L=San Francisco, ST=California, CN=origin-pull.cloudflare.net
#   notBefore 2019-10-10 18:45 GMT · **notAfter 2029-11-01 17:00 GMT**(운영 캘린더 — docs/runbooks/secret-rotation.md, T084 작성)
#   sha256 지문 9A:1A:C2:B4:BE:15:F9:F2:7E:EE:20:A7:34:CB:A4:E9:89:8F:61:00:1B:3B:D7:C8:4B:69:B5:6A:3E:25:A2:B9
#   → tests/infra/cloudflare-origin-pull-ca.tests.ps1 이 ns·키·PEM 1블록·개인키 없음·지문·만료를 고정한다(run-all 슬롯 1l; 잔여일은 WARN 만).
# 보증 범위: 이 CA 는 모든 Cloudflare 계정이 공유한다 — "Cloudflare 망에서 왔다" 만 보증하고 "우리 존에서 왔다" 는 보증하지 않는다.
#   계정 교차 우회의 오리진 측 통제는 Access 앱 + T084 forward-auth + 앱 계층 JWT 검증(contracts/hostnames-and-access.md §오리진 보호 3중).
# 설치: traefik-config.yaml 과 같은 위치·같은 절차(노드 A /var/lib/rancher/k3s/server/manifests/, 그 파일 헤더 절차 1~2: scp → sudo install).
#   K3s deploy 컨트롤러가 AddOn `cloudflare-origin-pull-ca` 로 적용한다(시작 시 · 파일 변경 시, 반영 ≈15 초). 파일을 지워도 객체는 남는다
#   (완전 제거 = 파일 rm → `kubectl -n kube-system delete addon cloudflare-origin-pull-ca` → Secret 삭제 — 아래 순서 규율 뒤에만).
#   운영자가 kubectl 로 먼저 만들지 않는다 — 부트스트랩 창에서도 이 파일을 manifests 디렉터리에 두는 한 경로만 쓴다(소유권 충돌 방지).
# ⚠ 순서 규율(둘 다 websecure 443 전면 중단 경로):
#   투입 = 이 Secret 먼저 → 지문·notAfter 대조(kubectl get secret … | base64 -d | openssl x509 -noout -fingerprint -sha256 -enddate)
#        → 그다음에 traefik-config.yaml 의 tlsOptions.default.clientAuth.
#   제거 = traefik-config.yaml 에서 clientAuth 블록 제거·재설치 → `kubectl -n kube-system get tlsoption default -o jsonpath='{.spec.clientAuth}'` 가
#        빈 값인 것을 확인 → 그다음에야 이 파일 삭제 + addon 삭제 + `kubectl -n kube-system delete secret cloudflare-origin-pull-ca`.
#   clientAuth 가 실린 상태에서 Secret 이 없거나 키가 ca.crt/tls.ca 가 아니면 Traefik 이 "invalid clientAuthType: …, CAFiles is required" 로
#   TLSOption 등록에 실패하고 websecure 전 호스트가 brokenTLSRouter 가 된다(파드는 Ready 유지 · INFO 로그 조용 — 능동 확인 필수).
# 교체(2029-11-01 만료 전 또는 Cloudflare 조기 교체 — 공지 채널 없음): 새 PEM 을 아래 ca.crt 값으로 바꾸고(옛+새 두 블록 병기 가능 —
#   Traefik 은 문자열 전체를 CA 풀에 넣는다) 테스트의 허용 지문을 갱신한 뒤 절차 1~2 재실행. CRD provider 가 Secret 변경 이벤트로 재빌드하므로
#   롤아웃·TLSOption 변경 없이 반영된다. 분기 1회 원본 지문 대조(traefik-config.yaml 헤더 "재검토 주기" 와 같은 주기):
#     curl -s https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem | openssl x509 -noout -fingerprint -sha256
# 라벨 `owner=helm` 을 붙이지 않는다 — Traefik 의 Secret informer 가 그 라벨을 제외해 "없는 Secret" 으로 취급한다.
# Argo CD UI 에는 고아 리소스 경고로 보인다(platform-traefik destination = kube-system) — 정상이며 지우지 않는다(gitops platform/traefik/README).
apiVersion: v1
kind: Secret
metadata:
  name: cloudflare-origin-pull-ca
  namespace: kube-system
type: Opaque
stringData:
  ca.crt: |
    -----BEGIN CERTIFICATE-----
    MIIGCjCCA/KgAwIBAgIIV5G6lVbCLmEwDQYJKoZIhvcNAQENBQAwgZAxCzAJBgNV
    BAYTAlVTMRkwFwYDVQQKExBDbG91ZEZsYXJlLCBJbmMuMRQwEgYDVQQLEwtPcmln
    aW4gUHVsbDEWMBQGA1UEBxMNU2FuIEZyYW5jaXNjbzETMBEGA1UECBMKQ2FsaWZv
    cm5pYTEjMCEGA1UEAxMab3JpZ2luLXB1bGwuY2xvdWRmbGFyZS5uZXQwHhcNMTkx
    MDEwMTg0NTAwWhcNMjkxMTAxMTcwMDAwWjCBkDELMAkGA1UEBhMCVVMxGTAXBgNV
    BAoTEENsb3VkRmxhcmUsIEluYy4xFDASBgNVBAsTC09yaWdpbiBQdWxsMRYwFAYD
    VQQHEw1TYW4gRnJhbmNpc2NvMRMwEQYDVQQIEwpDYWxpZm9ybmlhMSMwIQYDVQQD
    ExpvcmlnaW4tcHVsbC5jbG91ZGZsYXJlLm5ldDCCAiIwDQYJKoZIhvcNAQEBBQAD
    ggIPADCCAgoCggIBAN2y2zojYfl0bKfhp0AJBFeV+jQqbCw3sHmvEPwLmqDLqynI
    42tZXR5y914ZB9ZrwbL/K5O46exd/LujJnV2b3dzcx5rtiQzso0xzljqbnbQT20e
    ihx/WrF4OkZKydZzsdaJsWAPuplDH5P7J82q3re88jQdgE5hqjqFZ3clCG7lxoBw
    hLaazm3NJJlUfzdk97ouRvnFGAuXd5cQVx8jYOOeU60sWqmMe4QHdOvpqB91bJoY
    QSKVFjUgHeTpN8tNpKJfb9LIn3pun3bC9NKNHtRKMNX3Kl/sAPq7q/AlndvA2Kw3
    Dkum2mHQUGdzVHqcOgea9BGjLK2h7SuX93zTWL02u799dr6Xkrad/WShHchfjjRn
    aL35niJUDr02YJtPgxWObsrfOU63B8juLUphW/4BOjjJyAG5l9j1//aUGEi/sEe5
    lqVv0P78QrxoxR+MMXiJwQab5FB8TG/ac6mRHgF9CmkX90uaRh+OC07XjTdfSKGR
    PpM9hB2ZhLol/nf8qmoLdoD5HvODZuKu2+muKeVHXgw2/A6wM7OwrinxZiyBk5Hh
    CvaADH7PZpU6z/zv5NU5HSvXiKtCzFuDu4/Zfi34RfHXeCUfHAb4KfNRXJwMsxUa
    +4ZpSAX2G6RnGU5meuXpU5/V+DQJp/e69XyyY6RXDoMywaEFlIlXBqjRRA2pAgMB
    AAGjZjBkMA4GA1UdDwEB/wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgECMB0GA1Ud
    DgQWBBRDWUsraYuA4REzalfNVzjann3F6zAfBgNVHSMEGDAWgBRDWUsraYuA4REz
    alfNVzjann3F6zANBgkqhkiG9w0BAQ0FAAOCAgEAkQ+T9nqcSlAuW/90DeYmQOW1
    QhqOor5psBEGvxbNGV2hdLJY8h6QUq48BCevcMChg/L1CkznBNI40i3/6heDn3IS
    zVEwXKf34pPFCACWVMZxbQjkNRTiH8iRur9EsaNQ5oXCPJkhwg2+IFyoPAAYURoX
    VcI9SCDUa45clmYHJ/XYwV1icGVI8/9b2JUqklnOTa5tugwIUi5sTfipNcJXHhgz
    6BKYDl0/UP0lLKbsUETXeTGDiDpxZYIgbcFrRDDkHC6BSvdWVEiH5b9mH2BON60z
    0O0j8EEKTwi9jnafVtZQXP/D8yoVowdFDjXcKkOPF/1gIh9qrFR6GdoPVgB3SkLc
    5ulBqZaCHm563jsvWb/kXJnlFxW+1bsO9BDD6DweBcGdNurgmH625wBXksSdD7y/
    fakk8DagjbjKShYlPEFOAqEcliwjF45eabL0t27MJV61O/jHzHL3dknXeE4BDa2j
    bA+JbyJeUMtU7KMsxvx82RmhqBEJJDBCJ3scVptvhDMRrtqDBW5JShxoAOcpFQGm
    iYWicn46nPDjgTU0bX1ZPpTpryXbvciVL5RkVBuyX2ntcOLDPlZWgxZCBp96x07F
    AnOzKgZk4RzZPNAxCXERVxajn/FLcOhglVAKo5H0ac+AitlQ0ip55D2/mf8o72tM
    fVQ6VpyjEXdiIXWUq/o=
    -----END CERTIFICATE-----
```

`stringData` vs `data`: K3s가 재조정마다 `stringData`→`data` 변환 차이를 보고 Secret을 다시 패치하면 Traefik 재빌드가 반복될 수 있다(미실측, VD-18). resourceVersion이 흔들리면 `data: {ca.crt: <base64>}`로 전환하고 테스트는 base64 디코드 후 파싱한다.

### 4.3 `infra/bootstrap/traefik-config.yaml` — valuesContent `tlsOptions` 블록(인라인 주석·플로우 리스트 금지)

M3(관찰 단계):
```yaml
    tlsOptions:
      default:
        minVersion: VersionTLS12
        sniStrict: true
        clientAuth:
          secretNames:
            - cloudflare-origin-pull-ca
          clientAuthType: VerifyClientCertIfGiven
```

M4(최종):
```yaml
    tlsOptions:
      default:
        minVersion: VersionTLS12
        sniStrict: true
        clientAuth:
          secretNames:
            - cloudflare-origin-pull-ca
          clientAuthType: RequireAndVerifyClientCert
```

헤더 :57-61 최종형 조각(M4; 파서 밖이라 주석 가능, `BEGIN CERTIFICATE`·`PRIVATE KEY` 낱말 금지):
```
#     T043 뒤 — **승격 완료(2026-09-xx)**. kube-system Secret cloudflare-origin-pull-ca(키 ca.crt = Cloudflare Global AOP 루트 CA, 정본
#       infra/bootstrap/cloudflare-origin-pull-ca.yaml — 같은 디렉터리·같은 절차 1~2)를 **먼저** 설치하고 지문을 대조한 다음에만 넣었다:
#         clientAuth:
#           secretNames:
#             - cloudflare-origin-pull-ca
#           clientAuthType: RequireAndVerifyClientCert
#       관찰 단계(clientAuthType: VerifyClientCertIfGiven, 2026-09-xx 투입)에서 edge 프로브 로그 TLSClientSubject = <실측 리터럴> 를 확인한 뒤 승격.
#       주의: VerifyClientCertIfGiven 도 CA 불일치에는 Require 와 똑같이 443 전면 실패다 — '무해한 단계' 가 아니라 '인증서 부재만 통과' 다.
#       CA 진위 게이트: subject CN=origin-pull.cloudflare.net · notAfter 2029-11-01 17:00 GMT · sha256 지문
#       9A:1A:C2:B4:BE:15:F9:F2:7E:EE:20:A7:34:CB:A4:E9:89:8F:61:00:1B:3B:D7:C8:4B:69:B5:6A:3E:25:A2:B9 (contracts/hostnames-and-access.md :94).
#       ⚠ 되돌리기 순서: clientAuth 블록 제거(이 파일 → 노드 A, spec 에서 사라진 것 확인) → 그다음에야 Secret 삭제. 뒤집으면 Secret 부재 경고 +
#         CAFiles 없는 TLSOption 등록 실패로 443 전면 중단이다. 장애 되돌리기 목표는 항상 clientAuth 없는 사본(Verify 사본이 아님).
```

### 4.4 테스트 변경 diff 요약

**`tests/infra/cloudflare-origin-pull-ca.tests.ps1`(M2 신규)** — traefik-config.tests.ps1의 Assert/Test-Group/fail-closed 골격 복제, `$target = infra/bootstrap/cloudflare-origin-pull-ca.yaml`:

| 단언 | 내용 |
|---|---|
| f-1 | 파일 존재 · UTF-8 BOM 없음 · LF · 탭 0 · 행말 공백 0 |
| k-1 | `apiVersion: v1` · `kind: Secret` · `metadata.name: cloudflare-origin-pull-ca` · `metadata.namespace: kube-system` · `type: Opaque` |
| k-2 | `stringData:` 아래 키 정확히 `ca.crt` 하나 · `data:` 키 없음(VD-18로 전환 시 반대) |
| k-3 | `metadata.labels`에 `owner` 키 없음 |
| p-1 | `-----BEGIN CERTIFICATE-----` 정확히 1회 · `-----END CERTIFICATE-----` 1회 · 정규식 `-----BEGIN [A-Z ]*PRIVATE KEY-----` 0회(x-8 형태 — 낱말 검사 아님) |
| p-2 | `[System.Security.Cryptography.X509Certificates.X509Certificate2]::CreateFromPem($pem)` 파싱 성공 |
| p-3 | Subject에 `CN=origin-pull.cloudflare.net` 포함 · Subject == Issuer |
| p-4 | `GetCertHashString(SHA256)` == `9A1AC2B4BE15F9F27EEE20A734CBA4E9898F61001B3BD7C84B69B56A3E25A2B9`(Ordinal) |
| p-5 | `NotAfter.ToUniversalTime()` == 2029-11-01T17:00:00Z |
| p-6 | **단언 아님** — 잔여일을 `WARN remaining=<n>d`로 출력만(합계 밖). 180일 미만이면 WARN 문구에 '교체 신호' |
| d-1 | 헤더에 다운로드 URL · 지문 · '공개' · '순서' · 'clientAuth' 문자열 존재 |

모든 이름을 `$allNames`에 등록(파일 부재 = 전부 FAIL). `tests/run-all.ps1` 슬롯 1l(1k 바로 뒤, 같은 규율):
```powershell
# 1l. cloudflare-origin-pull-ca (T043) — tests/infra/cloudflare-origin-pull-ca.tests.ps1: infra/bootstrap/cloudflare-origin-pull-ca.yaml(공개 AOP 루트 CA Secret)
#     정적 검사(ns·키·PEM 1블록·개인키 없음·sha256 지문·notAfter 2029-11-01). 1k와 같은 규율: SKIP 없이 fail closed,
#     exit 0 이면서 'N passed, 0 failed'가 있어야 PASS. 잔여일은 WARN 출력만(시한 FAIL 없음) — 교체 감시는 T114 월간 점검·분기 지문 대조.
$o = pwsh -NoProfile -ExecutionPolicy Bypass -File tests/infra/cloudflare-origin-pull-ca.tests.ps1 2>&1 | Out-String
$c = $LASTEXITCODE
Write-Host ($o.TrimEnd())
Check 'cloudflare-origin-pull-ca' ($c -eq 0 -and $o -match '(?m)^\d+ passed, 0 failed\r?$') "exit=$c; see cloudflare-origin-pull-ca test output above"
```

**`tests/infra/traefik-config.tests.ps1`** — 단계별:

| 단계 | 단언 | 변경 |
|---|---|---|
| M3 | `$allNames`(:53-60) | + `v-25`, `v-26`, `doc-18` |
| M3 | v-20(:300-304) | `$wantTls` = 6키 `tlsOptions.default, .clientAuth, .clientAuth.clientAuthType, .clientAuth.secretNames, .minVersion, .sniStrict`(Sort-Object와 Ordinal 정렬 동일 확인됨) — 문구 'carries exactly minVersion + sniStrict + clientAuth{secretNames,clientAuthType} (T043)' |
| M3 | v-25 신설 | `Eq (Scalar $vals 'tlsOptions.default.clientAuth.clientAuthType') 'VerifyClientCertIfGiven'` — 리터럴 완전 일치(인라인 주석 파서 함정이 곧 주석 금지 검사) |
| M3 | v-26 신설 | `$sn = Seq $vals 'tlsOptions.default.clientAuth.secretNames'; ($sn.Count -eq 1) -and (Eq $sn[0] 'cloudflare-origin-pull-ca')`(플로우 리스트는 Scalar로 가 FAIL — 의도) |
| M3 | x-6(:332-334) 반전 | `([regex]::Matches($valuesText,'clientAuth:')).Count -eq 1 -and ([regex]::Matches($valuesText,'secretNames:')).Count -eq 1` — 'x-6: clientAuth block appears exactly once in valuesContent (T043)' |
| M3 | x-5(:329-331) | 현행 유지(RequireAndVerifyClientCert 부재) |
| M3 | doc-4(:183-187) | 헤더에 `T043`·`clientAuth:`·`secretNames:`·`cloudflare-origin-pull-ca`·`clientAuthType: VerifyClientCertIfGiven`·`CAFiles`·`관찰 단계 투입` — '완료' 리터럴 **요구하지 않음** |
| M3 | doc-6(:191-193) | 무변경 — 헤더 :41-42를 과거형으로 고치되 리터럴 '의도적 편차' 보존 |
| M3 | doc-18 신설 | 헤더에 지문 `9A:1A:C2:B4:…:A2:B9` · `2029-11-01` · `origin-pull.cloudflare.net` · `clientAuth 블록 제거` · `Secret 삭제` — 되돌리기 순서 고정 |
| M3 | 머리 목록 :14·:27-31 | V/X/DOC 설명 갱신 |
| M3 | 기대 | **72 passed, 0 failed** |
| M4 | v-25 | 값 → `'RequireAndVerifyClientCert'` |
| M4 | x-5 반전 | `([regex]::Matches($valuesText,'RequireAndVerifyClientCert')).Count -eq 1 -and -not (Has $valuesText 'VerifyClientCertIfGiven') -and -not (Has $valuesText 'RequestClientCert')` — 'exactly once and no other clientAuthType literal in valuesContent (T043 승격 — 하향·중복 금지)' |
| M4 | doc-4 | `clientAuthType: RequireAndVerifyClientCert` + `승격 완료` + 과거형 `VerifyClientCertIfGiven` 유지 |
| M4 | 기대 | **72 passed, 0 failed** |
| 전 단계 | x-8 | 헤더에 `BEGIN CERTIFICATE`·PEM 절대 금지(지문·CN·만료·URL만) |

**변경 없음(판정만)**: `tests/platform/ingress.tests.ps1` argo-2는 G1 머지 뒤 PASS, aop-1은 28(NSG)로 PASS 유지 — 보고 문구 'NSG 계층 거부, AOP 자체는 노드 내부 실측(런북 T043 절)'. `cluster.tests.ps1` argo-1·`reboot.tests.ps1` reboot-3는 platform-argocd Healthy 조건으로 간접 영향(VD-13). gitops `tests/validate.sh` 무변경(검사 1 자동 포함).

---

## 5. 운영자 적용 순서

> **전 단계 공통 규율**
> 1. **투입 순서 = Secret → 지문 게이트 → clientAuth. 되돌리기 순서 = clientAuth 제거 → `get tlsoption default` spec에서 clientAuth 빈 값 확인 → (선택) addon·Secret 삭제.** 역순은 443 전면 중단.
> 2. **장애 되돌리기 목표는 항상 clientAuth 없는 사본(`traefik-config.pre-t043.yaml`)**이다. Verify 사본으로 하향하는 것은 "엣지 미제시가 확인된 경우"에만 쓰는 2차 선택지(CA 불일치·Secret 오류에서는 Verify도 죽는다).
> 3. **TLSOption 변경 판정은 두 시계로**: ① 반영 ≈15초 + helm Job ≈5초 뒤 spec 확인, ② 액세스 로그 `TLSClientSubject` 판정은 spec 반영 시각 + **≥180초**(idleTimeout, VD-5) 이후의 프로브로만(옛 keep-alive 연결이 옛 tls.Config로 살아 있다). edge auth 404는 '장애 없음' 판정에만 쓰고 강제 실효 판정에는 쓰지 않는다.
> 4. **로그 게이트 grep 패턴(고정)**: `'CAFiles is required|invalid certificate|does not exist|Failed to extract CA|unknown client auth|Default TLS Options defined in multiple'` — 일반 `error`는 T098 전 OTLP 잡음으로 항상 ≥1줄이라 게이트에 쓰지 않는다(보조 조회는 `grep -Ei error | grep -viE 'otlp|4317|tracing'`).
> 5. HelmChartConfig 연속 변경 사이에는 `kubectl -n kube-system get job helm-install-traefik -o jsonpath='{.status.succeeded}'` = 1 확인(최소 60초) — Job immutable/pending-upgrade 함정(헤더 :136-138).
> 6. `kubectl delete helmchartconfig traefik` 금지(T038 전량 소실). 사용자 재확인은 라이브 변경 단계(3·5·7·8·11)마다 1회.

### curl 기대값 표(단계별)

| 프로브 | 현재(T042) | Ingress 뒤(3) | Secret 뒤(5) | Verify 뒤(7) | Require 뒤(11) |
|---|---|---|---|---|---|
| edge `curl.exe -sI https://auth.joshuatech.dev/` | 404 | 404 | 404 | 404 | **404**(525/520 = AOP 불일치 → 즉시 되돌리기; 526 = 서버 인증서 별건) |
| edge `curl.exe -sI https://argo.joshuatech.dev/` | 302 | 302 | 302 | 302 | 302 |
| 노드 A `curl -sk --resolve traefik.joshuatech.dev:443:10.0.7.78` | 302 | 302 | 302 | 302(무인증서 통과) | **000 + exit 56**(`--tls-max 1.2` → exit 35) |
| 노드 A `curl -sk --resolve argo.joshuatech.dev:443:10.0.7.78 …/` | 404 | **200** | 200 | 200 | 000 + exit 56 |
| 노드 A `curl -sk --resolve no-such.example.invalid:443:10.0.7.78` | 000 | 000 | 000 | 000 | 000(stderr `unrecognized name` — 인증서 부재 000과 구분) |
| 노드 A `curl -H 'Host: argo.joshuatech.dev' http://<traefik podIP>:8080/` | — | **404** | 404 | 404 | 404 |
| 노드 A `openssl s_client -servername traefik.joshuatech.dev` issuer | LE YE2 | LE YE2 | LE YE2 | LE YE2 | **LE YE2**(서버 인증서는 여전히 읽힘) |
| `/__probe-404` 로그 줄 `TLSClientSubject` | 없음 | 없음 | 없음 | **있음**(180초 뒤) | 있음 |

### 단계 0 — 착수 게이트(읽기 전용) · 운영자

```powershell
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/traefik-config.tests.ps1          # 69 passed, 0 failed
curl.exe -s -H "Authorization: Bearer $env:CF_TOKEN" https://api.cloudflare.com/client/v4/zones/$env:CF_ZONE_ID/settings/tls_client_auth | ConvertFrom-Json | % result | Select-Object value,editable,modified_on
curl.exe -s -H "Authorization: Bearer $env:CF_TOKEN" https://api.cloudflare.com/client/v4/zones/$env:CF_ZONE_ID/origin_tls_client_auth/settings | ConvertFrom-Json | % result
tofu -chdir=D:/code/joshuatech_ver2/infra/cloudflare plan -detailed-exitcode -lock=false; $LASTEXITCODE
kubectl --kubeconfig=$env:AGENT_VIEW_KUBECONFIG auth can-i list ingresses.networking.k8s.io -A
kubectl get tlsoption -A
kubectl -n kube-system get secret cloudflare-origin-pull-ca 2>&1                                 # NotFound
kubectl -n kube-system get deploy traefik -o jsonpath='{.spec.template.spec.containers[0].args}' | Select-String idleTimeout
```
**게이트**: 69/0 · `tls_client_auth` value=`on`·editable=`true`(modified_on만 런북에) · `origin_tls_client_auth` enabled=`false` · tofu exit 0 · can-i `yes` · tlsoption `default` kube-system 정확히 1개 · Secret NotFound · idleTimeout 인자 없음(=기본 180s) 또는 값 기록. 하나라도 어긋나면 진입 금지(존 설정은 T011 tofu 재적용; can-i no면 agent-view-extra 계약 변경 선행).
**되돌리기/라이브 영향**: 없음.

### 단계 1 — M1 계약 보강 커밋(모노레포 단독, gitops보다 먼저) · 컨트롤러

파일: `contracts/hostnames-and-access.md:94` — Secret `kube-system/cloudflare-origin-pull-ca`(키 `ca.crt`, 정본 `infra/bootstrap/cloudflare-origin-pull-ca.yaml`, 값은 공개 인증서로 AGENTS.md 비밀 금지의 대상 아님) · CA 주체 `CN=origin-pull.cloudflare.net` · sha256 지문 · notAfter 2029-11-01 17:00 GMT · 관찰 판정 = 액세스 로그 `TLSClientSubject`(반영 +180초 이후 프로브) · 승격 뒤 직접 접속 판정 = curl exit 56/35 · 되돌리기 순서 · 분기 지문 대조. 전환 순서 문장(관찰→승격)은 그대로. `contracts/gitops-repo.md:10` — `argocd/`에 `ingress.yaml`(Ingress `argo.`, T043; platform/argocd 자리표시 유지) 병기; `:19` — `server/manifests/`에 `cloudflare-origin-pull-ca.yaml`(공개 AOP 루트 CA Secret, 정본 모노레포 infra/bootstrap/) 병기. **network-policy.md 각주는 건드리지 않는다**(T047에서 PORT_TABLE과 같이).
```powershell
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/run-all.ps1
git -C D:/code/joshuatech_ver2 add specs/003-platform-foundation/contracts/hostnames-and-access.md specs/003-platform-foundation/contracts/gitops-repo.md
git -C D:/code/joshuatech_ver2 commit -m "docs(003-platform-foundation): T043 계약 보강 — AOP CA Secret 정본·지문·판정, argocd/ ingress.yaml"
```
**게이트**: diff가 두 계약 파일에만 · spec/plan/tasks 무변경 · run-all 전 PASS. **되돌리기**: git revert. **라이브 영향**: 없음.

### 단계 2 — G1 Argo CD Ingress PR 작성 · builder

파일: `bootstrap/argocd/ingress.yaml`(§4.1) · `bootstrap/argocd/kustomization.yaml`(resources 1줄 + 머리 3)) · `argocd-cm.yaml:5`('뒤 태스크(T043 · SSO)' → 'T084(SSO: url=https://argo.joshuatech.dev · oidc.config · admin.enabled)') · `argocd-cmd-params-cm.yaml:9`('T043 전 접근은 port-forward' → 과거형) · `bootstrap/README.md` ⑥(:125-137 기본 = Access(GitHub) → Argo UI, port-forward는 edge/Access 장애 시 대체) · :209 절 제목 · :215('T043 = Ingress만(완료). url·oidc.config·rbac·admin.enabled = T084').
```bash
git -C /d/code/platform-gitops switch -c t043-argocd-ingress main
bash /d/code/platform-gitops/tests/validate.sh
kustomize build /d/code/platform-gitops/bootstrap/argocd | yq 'select(.kind=="Ingress")'
gh pr create -R <org>/platform-gitops --title "feat(argocd): Ingress argo.joshuatech.dev (T043 PR-1)" --body "...validate.sh 8검사 출력 첨부..."
```
**게이트**: validate.sh 8/8 PASS · 렌더 Ingress 1개: `namespace: argocd` · `ingressClassName: traefik` · 어노테이션 entrypoints=websecure, tls="true" · `router.tls.options` 없음 · backend `port.name: http` · `spec.tls` 없음 · PR 본문 체크리스트(https/443 금지 · entrypoints 필수) + 로컬 validate 결과(CI는 골격). **되돌리기**: PR 닫기. **라이브 영향**: 없음.

### 단계 3 — G1 머지 · Ingress 실측(clientAuth 없는 상태) · 운영자 ⚠ 사용자 재확인

```powershell
gh pr merge <G1> -R <org>/platform-gitops --squash
kubectl -n argocd annotate app platform-argocd argocd.argoproj.io/refresh=normal --overwrite
Start-Sleep 30
kubectl -n argocd get ingress argocd-server -o jsonpath='{.spec.ingressClassName} {.status.loadBalancer.ingress}{"\n"}'
kubectl -n argocd get app platform-argocd -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
ssh ssh-a "curl -skv --resolve argo.joshuatech.dev:443:10.0.7.78 https://argo.joshuatech.dev/ -o /dev/null 2>&1 | grep -Ei 'issuer:|expire date|^< HTTP'"
$pod = kubectl -n kube-system get pod -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].status.podIP}'
ssh ssh-a "curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: argo.joshuatech.dev' http://$pod:8080/"
curl.exe -sI https://argo.joshuatech.dev/ | Select-Object -First 1
# 브라우저: https://argo.joshuatech.dev → Access(GitHub) → Argo admin 로그인 → Applications 목록 · 3분 SSE(VD-14)
# 브라우저: https://traefik.joshuatech.dev/api/http/routers → argocd 라우터 tls.options (VD-11)
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/platform/run-platform-tests.ps1
```
**게이트**: `status.loadBalancer.ingress` 비어 있지 않음 + platform-argocd Synced/Healthy(VD-13) · 노드 내부 curl issuer Let's Encrypt + `< HTTP/2 200` · 8080 Host 프로브 **404**(VD-12) · edge 302 유지 · 브라우저 Applications 목록 로딩(=T043 '접근 확인') · 라우터 `tls.options` default 또는 빈 값(VD-11) · run-platform-tests `PASS argo-2 … ingress=[argocd/argocd-server]`, 남은 FAIL = vault-2 1건.
**되돌리기**: gitops revert 머지(prune:false라 객체 잔존) → `kubectl -n argocd delete ingress argocd-server`. edge는 302 그대로.
**라이브 영향**: argo. 가 Access 뒤 Traefik 404 → Argo UI로. 다른 호스트 무영향, 롤아웃 없음.

### 단계 4 — M2 CA Secret 파일 + 정적 테스트 + run-all 1l(테스트 먼저) · builder

```powershell
curl.exe -sS -o $env:TEMP/aop-ca.pem https://developers.cloudflare.com/ssl/static/authenticated_origin_pull_ca.pem
(Get-Item $env:TEMP/aop-ca.pem).Length                                                              # 2154
openssl x509 -in $env:TEMP/aop-ca.pem -noout -fingerprint -sha256 -enddate -subject
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/cloudflare-origin-pull-ca.tests.ps1      # 파일 부재 → 전 단언 FAIL(red)
# infra/bootstrap/cloudflare-origin-pull-ca.yaml 작성(§4.2, PEM 붙임) + traefik-config.yaml:6 한 줄 보강
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/cloudflare-origin-pull-ca.tests.ps1      # N passed, 0 failed
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/traefik-config.tests.ps1                  # 69/0 유지
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/run-all.ps1
git -C D:/code/joshuatech_ver2 commit -am "feat(003-platform-foundation): AOP CA Secret 매니페스트 + 지문 고정 테스트 (T043 단계 1)"
```
**게이트**: 다운로드 지문 == `9A:1A:C2:B4:…:A2:B9`(다르면 **중단·조사** — Cloudflare가 CA를 바꾼 것) · 새 스위트 green(p-6는 WARN 출력) · traefik-config 스위트 69/0 · run-all 전 PASS(1l 포함) · push 뒤 push protection 차단 여부·CI gitleaks 결과 기록(VD-16). **되돌리기**: git revert. **라이브 영향**: 없음.
*(D1=A 선택 시 이 단계 생략, 단계 5의 명령만 `kubectl create secret generic … --from-file=ca.crt=`로.)*

### 단계 5 — CA Secret 설치(clientAuth보다 먼저) → 지문 게이트 · 운영자 ⚠ 사용자 재확인

```powershell
scp D:/code/joshuatech_ver2/infra/bootstrap/cloudflare-origin-pull-ca.yaml ssh-a:/home/ubuntu/cloudflare-origin-pull-ca.yaml
ssh ssh-a "sudo install -m 644 -o root -g root /home/ubuntu/cloudflare-origin-pull-ca.yaml /var/lib/rancher/k3s/server/manifests/cloudflare-origin-pull-ca.yaml && rm -f /home/ubuntu/cloudflare-origin-pull-ca.yaml"
Start-Sleep 30
kubectl -n kube-system get addon cloudflare-origin-pull-ca
kubectl -n kube-system get secret cloudflare-origin-pull-ca -o jsonpath='{.type} {.metadata.labels} {range $k,$v := .data}{$k} {end}{"\n"}'
ssh ssh-a "kubectl -n kube-system get secret cloudflare-origin-pull-ca -o jsonpath='{.data.ca\.crt}' | base64 -d | openssl x509 -noout -subject -enddate -fingerprint -sha256"
kubectl -n kube-system get secret cloudflare-origin-pull-ca -o jsonpath='{.metadata.resourceVersion}{"\n"}'   # 5분 뒤 재조회(VD-18)
kubectl -n kube-system logs deploy/traefik --since=5m | Select-String -Pattern 'CAFiles is required|invalid certificate|does not exist|Failed to extract CA|unknown client auth|Default TLS Options defined in multiple'
curl.exe -sI https://auth.joshuatech.dev/ | Select-Object -First 1
```
*(D1=A: `kubectl -n kube-system create secret generic cloudflare-origin-pull-ca --from-file=ca.crt=$env:TEMP/aop-ca.pem` 뒤 같은 확인; 런북 'git 밖 라이브 상태'에 1줄.)*
**게이트**: AddOn 존재 · type Opaque · 라벨에 `owner: helm` 없음 · data 키 정확히 `ca.crt` · subject `CN = origin-pull.cloudflare.net` · `notAfter=Nov  1 17:00:00 2029 GMT` · 지문 9A:1A:…:A2:B9 — **넷 다 일치해야 다음 단계**(VD-3) · resourceVersion 5분 불변(VD-18) · 로그 패턴 0줄 · auth 404.
**되돌리기**(clientAuth 미설치 상태에서만 안전): `ssh ssh-a "sudo rm -f /var/lib/rancher/k3s/server/manifests/cloudflare-origin-pull-ca.yaml"` → `kubectl -n kube-system delete addon cloudflare-origin-pull-ca` → `kubectl -n kube-system delete secret cloudflare-origin-pull-ca`.
**라이브 영향**: 없음(아직 어떤 TLSOption도 참조하지 않음).

### 단계 6 — M3 clientAuth `VerifyClientCertIfGiven` 커밋(스위트 1단계 → yaml → 헤더) · builder

```powershell
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/traefik-config.tests.ps1   # 테스트 수정 뒤 → v-20/v-25/v-26/x-6/doc-4/doc-18 FAIL(red)
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/traefik-config.tests.ps1   # yaml+헤더 수정 뒤 → 72 passed, 0 failed
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/run-all.ps1
git -C D:/code/joshuatech_ver2 commit -am "feat(003-platform-foundation): Traefik clientAuth VerifyClientCertIfGiven 관찰 단계 (T043 단계 2)"
```
헤더 변경: :41-42 과거형(리터럴 '의도적 편차' 보존) · :53-61 '관찰 단계 투입(날짜)' + 조각 · :52 옆 되돌리기 순서 경고 · :68 · :109 'sniStrict: true 와 clientAuth 가 보여야' · **:112 grep 패턴을 공통 규율 4의 특정 문구로 교체**(:64 잡음 서술과 모순 해소) · :6 한 줄 보강(M2에서 안 했다면).
**게이트**: 72/0(v-25 = Verify, x-5 현행) · valuesContent에 인라인 주석·플로우 리스트 없음 · x-8 PASS. **되돌리기**: git revert. **라이브 영향**: 없음.

### 단계 7 — 관찰 단계 설치 → 사본 보존 → 30초 게이트 → 180초 → 양성 증거 · 운영자 ⚠ 사용자 재확인

```powershell
ssh ssh-a "sudo cp /var/lib/rancher/k3s/server/manifests/traefik-config.yaml /home/ubuntu/traefik-config.pre-t043.yaml && sudo chown ubuntu:ubuntu /home/ubuntu/traefik-config.pre-t043.yaml && grep -c clientAuth /home/ubuntu/traefik-config.pre-t043.yaml"   # 0
git -C D:/code/joshuatech_ver2 log -1 --format=%H -- infra/bootstrap/traefik-config.yaml            # 설치본 = 이 커밋
scp D:/code/joshuatech_ver2/infra/bootstrap/traefik-config.yaml ssh-a:/home/ubuntu/traefik-config.yaml
ssh ssh-a "sudo install -m 644 -o root -g root /home/ubuntu/traefik-config.yaml /var/lib/rancher/k3s/server/manifests/traefik-config.yaml && rm -f /home/ubuntu/traefik-config.yaml && date -u +%FT%TZ"
Start-Sleep 30
kubectl -n kube-system get tlsoption default -o jsonpath='{.spec}{"\n"}'
kubectl get tlsoption -A
kubectl -n kube-system get job helm-install-traefik -o jsonpath='{.status.succeeded}{"\n"}'
kubectl -n kube-system logs deploy/traefik --since=5m | Select-String -Pattern 'CAFiles is required|invalid certificate|does not exist|Failed to extract CA|unknown client auth|Default TLS Options defined in multiple'
kubectl -n kube-system get pod -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.creationTimestamp} {.items[0].status.containerStatuses[0].restartCount}{"\n"}'
curl.exe -sI https://auth.joshuatech.dev/ | Select-Object -First 1
curl.exe -sI https://argo.joshuatech.dev/ | Select-Object -First 1
ssh ssh-a "curl -sk --resolve traefik.joshuatech.dev:443:10.0.7.78 https://traefik.joshuatech.dev -o /dev/null -w 'http=%{http_code}\n'; curl -sk --resolve argo.joshuatech.dev:443:10.0.7.78 https://argo.joshuatech.dev/ -o /dev/null -w 'http=%{http_code}\n'"
# ── spec 반영 시각 + 180초 이후 ──
Start-Sleep 180
1..3 | % { curl.exe -sI https://auth.joshuatech.dev/__probe-404 | Select-String -Pattern '^HTTP|^cf-ray'; Start-Sleep 60 }
kubectl -n kube-system logs deploy/traefik --since=10m | Select-String -Pattern '__probe-404' | Select-Object -Last 3
```
**게이트(30초)**: spec에 `clientAuth: {secretNames:[cloudflare-origin-pull-ca], clientAuthType: VerifyClientCertIfGiven}` + minVersion + sniStrict · tlsoption `default` 1개 · Job succeeded=1 · 로그 패턴 0줄 · 파드 creationTimestamp·restartCount 불변 · edge auth 404·argo 302 · 노드 내부 traefik 302·argo 200(무인증서 통과 = Verify 의미론).
**게이트(180초+)**: 프로브 3줄 **전부** `"TLSClientSubject":"<비어 있지 않음>"` + `"TLSVersion"` → **edge 제시 + CA 검증 통과 증명**(VD-6). 리터럴·TLSVersion·cf-ray 콜로를 런북에 기록. 필드 부재/빈 값 → 승격 금지: 존 설정 재확인(VD-1) → 필요 시 `RequestClientCert` 임시 진단(사용자 재확인).
**되돌리기**: `ssh ssh-a "sudo install -m 644 -o root -g root /home/ubuntu/traefik-config.pre-t043.yaml /var/lib/rancher/k3s/server/manifests/traefik-config.yaml"` → 30초 → `get tlsoption default -o jsonpath='{.spec.clientAuth}'` 빈 값 + auth 404. **절대** `delete helmchartconfig`·Secret 삭제로 되돌리지 않는다.
**라이브 영향**: 새 핸드셰이크마다 CertificateRequest 송신. edge가 우리 CA로 검증되는 인증서를 내밀면 무영향; 불일치/Secret 오류면 443 전면 실패(사본 재설치까지 ≈30초, 플랫폼 호스트 한정, 터널·kubectl 무영향). 인증서 없는 직접 접속은 아직 통과.

### 단계 8 — 되돌리기 리허설(선택, 관찰 단계에서 1회) · 운영자

```powershell
ssh ssh-a "sudo cp /var/lib/rancher/k3s/server/manifests/traefik-config.yaml /home/ubuntu/traefik-config.t043-verify.yaml && sudo install -m 644 -o root -g root /home/ubuntu/traefik-config.pre-t043.yaml /var/lib/rancher/k3s/server/manifests/traefik-config.yaml && date -u +%FT%TZ"
Start-Sleep 30
kubectl -n kube-system get tlsoption default -o jsonpath='{.spec.clientAuth}{"\n"}'                # 빈 문자열
kubectl -n kube-system get job helm-install-traefik -o jsonpath='{.status.succeeded}{"\n"}'        # 1 — 이것을 본 뒤에만 재투입(≥60초)
curl.exe -sI https://auth.joshuatech.dev/ | Select-Object -First 1
ssh ssh-a "sudo install -m 644 -o root -g root /home/ubuntu/traefik-config.t043-verify.yaml /var/lib/rancher/k3s/server/manifests/traefik-config.yaml && date -u +%FT%TZ"
Start-Sleep 30
kubectl -n kube-system get tlsoption default -o jsonpath='{.spec.clientAuth.clientAuthType}{"\n"}' # VerifyClientCertIfGiven
```
**게이트**: 되돌린 뒤 clientAuth 빈 값 + auth 404 + 파드 불변; Job succeeded 확인 뒤 재투입; 재투입 뒤 Verify. 소요 시간(파일 mtime → `journalctl -u k3s | grep 'Applied manifest'`)을 런북에(VD-17). 15초 초과 지연이면 `sudo journalctl -u k3s --since '5 min ago' | grep -E 'Applied manifest|helm-controller'`; pending-upgrade면 헤더 :136-138 절차.
**라이브 영향**: TLSOption CR 2회 갱신, 롤아웃 없음, 수립된 연결 무영향.

### 단계 9 — 관찰 창(선택 소크, 게이트 아님) · 운영자

사용자 선택 길이(다음 운영자 창까지 / 24h). 기록 항목: 시간대를 달리한 `/__probe-404` 프로브 ≥3회의 `TLSClientSubject`·cf-ray 콜로(다양성은 **기록만**) · 로그 첫 줄 타임스탬프(`--since` 범위의 실제 하한) · 로그 패턴 0줄 · edge auth 404·argo UI 정상. 승격 조건은 **단계 7 게이트 통과**이며 소크 중 이상이 없어야 한다.

### 단계 10 — M4 `RequireAndVerifyClientCert` 커밋(스위트 2단계 → yaml → 헤더 절차 4) · builder

```powershell
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/traefik-config.tests.ps1   # v-25/x-5/doc-4 FAIL(red)
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/infra/traefik-config.tests.ps1   # → 72 passed, 0 failed
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/run-all.ps1
git -C D:/code/joshuatech_ver2 commit -am "feat(003-platform-foundation): Traefik clientAuth RequireAndVerifyClientCert 승격 (T043 단계 3)"
```
헤더 변경: :57-61 '승격 완료(날짜)' + 관찰 실측(TLSClientSubject 리터럴·콜로·반영 지연·순단 0) · :116-120 절차 4 기대값 반전(http=000 + exit 56/35 = 정상, 숫자 = 미강제; 443 생존 판정은 edge auth 404) · :121-127 SNI 판정 ② '인증서 부재와 겹쳐 000 — stderr로 구분, 재투입 절차 전용' · openssl s_client 서버 인증서 판별 추가 · :32 재검토 주기에 'AOP CA 원본 지문 대조' 편승. `infra/cloudflare/zone_settings.tf:26-27` 주석 완료형(같은 커밋; `tofu plan` No changes 확인 런북 기록).
**게이트**: 72/0(v-25 = Require · x-5 정확히 1회 + 다른 리터럴 없음 · x-6 각 1회). **되돌리기**: git revert. **라이브 영향**: 없음.

### 단계 11 — 승격 설치 → 30초 게이트 → 음성 증거 · 운영자 ⚠ 사용자 재확인

```powershell
ssh ssh-a "sudo cp /var/lib/rancher/k3s/server/manifests/traefik-config.yaml /home/ubuntu/traefik-config.t043-verify.yaml"   # (단계 8을 안 했으면)
scp D:/code/joshuatech_ver2/infra/bootstrap/traefik-config.yaml ssh-a:/home/ubuntu/traefik-config.yaml
ssh ssh-a "sudo install -m 644 -o root -g root /home/ubuntu/traefik-config.yaml /var/lib/rancher/k3s/server/manifests/traefik-config.yaml && rm -f /home/ubuntu/traefik-config.yaml && date -u +%FT%TZ"
Start-Sleep 30
kubectl -n kube-system get tlsoption default -o jsonpath='{.spec.clientAuth.clientAuthType}{"\n"}'
kubectl -n kube-system logs deploy/traefik --since=5m | Select-String -Pattern 'CAFiles is required|invalid certificate|does not exist|Failed to extract CA|unknown client auth|Default TLS Options defined in multiple'
kubectl -n kube-system get pod -l app.kubernetes.io/name=traefik -o jsonpath='{.items[0].metadata.creationTimestamp} {.items[0].status.containerStatuses[0].restartCount}{"\n"}'
curl.exe -sI https://auth.joshuatech.dev/ | Select-Object -First 1
curl.exe -sI https://argo.joshuatech.dev/ | Select-Object -First 1
ssh ssh-a "curl -sk --resolve auth.joshuatech.dev:443:10.0.7.78 https://auth.joshuatech.dev/ -o /dev/null -w 'exit=%{exitcode} http=%{http_code}\n'; curl -skv --resolve auth.joshuatech.dev:443:10.0.7.78 https://auth.joshuatech.dev/ -o /dev/null 2>&1 | grep -Ei 'alert|certificate required|bad certificate'"
ssh ssh-a "curl -sk --tls-max 1.2 --resolve auth.joshuatech.dev:443:10.0.7.78 https://auth.joshuatech.dev/ -o /dev/null -w 'exit=%{exitcode} http=%{http_code}\n'"
ssh ssh-a "curl -skv --resolve no-such.example.invalid:443:10.0.7.78 https://no-such.example.invalid -o /dev/null 2>&1 | grep -Ei 'unrecognized|alert|closed'; curl -sk --resolve no-such.example.invalid:443:10.0.7.78 https://no-such.example.invalid -o /dev/null -w 'http=%{http_code}\n'"
ssh ssh-a "echo | openssl s_client -connect 10.0.7.78:443 -servername traefik.joshuatech.dev 2>/dev/null | openssl x509 -noout -issuer -enddate"
kubectl -n kube-system logs deploy/traefik --since=2m | Select-String -CaseSensitive 'handshake' | Measure-Object | % Count
# ── +180초 ──
Start-Sleep 180
curl.exe -sI https://auth.joshuatech.dev/__probe-404 | Select-Object -First 1; kubectl -n kube-system logs deploy/traefik --since=5m | Select-String '__probe-404' | Select-Object -Last 1
# 브라우저: Argo UI Applications 재로딩 · Traefik 대시보드
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/platform/run-platform-tests.ps1
```
**게이트**: clientAuthType = RequireAndVerifyClientCert · 로그 패턴 0줄 · 파드 불변 · edge auth **404**(525/520 → 즉시 되돌리기; 526 = 별건) · argo 302 · 노드 내부 무인증서 curl: TLS1.3 **exit 56 + http=000** + `certificate required`, `--tls-max 1.2` **exit 35** + `handshake failure`(VD-8) · SNI 불일치 000 + `unrecognized name`(구분표) · openssl s_client issuer Let's Encrypt·notAfter Dec 8 2026(VD-10) · handshake 건수 기록(VD-9) · 180초 뒤 프로브 줄 TLSClientSubject 존재 · 브라우저 두 UI 정상 · run-platform-tests `PASS aop-1`(28)·`PASS argo-2`, FAIL = vault-2.
**되돌리기(장애)**: **`pre-t043` 사본**(clientAuth 없음) 재설치 → 30초 → clientAuth 빈 값 + auth 404 → 그다음 원인 분류: 존 설정 GET(VD-1) · Secret 지문(VD-3) · Cloudflare 원본 지문(VD-20). 엣지 미제시로 판명된 경우에만 `t043-verify` 사본으로 관찰 단계 복귀를 검토.
**라이브 영향**: 클라이언트 인증서 없는 직접 오리진 TLS는 핸드셰이크에서 거절(NSG 뒤 2중). edge 경유 트래픽은 관찰 단계에서 증명된 경로 그대로. 롤아웃 없음, 순단 0 기대(실측 기록).

### 단계 12 — G2 gitops 문서 PR · builder

파일·문면은 §8. `grep -nE 'curl -sk|--resolve|노드 내부' D:/code/platform-gitops/platform/cert-manager-issuers/README.md`(VD-23) 결과에 따라 포함. `bash tests/validate.sh` 8/8 → PR. **게이트**: README §9에 '인증서 부재 000 vs SNI 불일치 000' 판별표 + openssl s_client 절차 + AOP 양성/음성 증거 명령이 실측값과 함께; 'T043 전' 조건문 0건. **라이브 영향**: 없음.

### 단계 13 — M5 런북 §3 T043 절 · 잔여 정정 · 체크박스 · 컨트롤러

`docs/runbooks/bootstrap.md` :321 자리표시 뒤 `### T043 — AOP 강제 · Argo CD Ingress (2026-09-xx)`(T042 절 형식: 설계 · 코드(커밋 SHA·PR) · 사용자 결정 D1~D6 · 문면 편차(FR-011 PLACEHOLDER/overlay는 apps/ 전용, 플랫폼 Ingress는 리터럴 호스트 · ADR 0010:33의 'T043'은 T044를 뜻함 — 기록만) · 게이트·사건 실측(지문·notAfter·TLSClientSubject 리터럴·콜로·반영 지연·순단·curl exit·handshake 건수·리허설 소요) · 노드 A manifests 파일 목록(traefik-config.yaml·cloudflare-origin-pull-ca.yaml — '모노레포 정본·수동 install' 범주, 'git 밖 라이브 상태'와 구분; D1=A면 후자에 1줄) · 절차 메모(순서·되돌리기·180초 규칙·grep 패턴) · 미확인·인계) · :250 '남은 FAIL 2건' → 1건(vault-2) · :118 'Vault 투입은 T043' → T045 오기 · §4 자리표시에 kv 플레이스홀더 절차 1줄(T044 뒤) · `tasks.md` T043 `[X]`만.
```powershell
pwsh -NoProfile -File D:/code/joshuatech_ver2/tests/run-all.ps1
pwsh -NoProfile -File D:/code/joshuatech_ver2/scripts/update-specs-index.ps1
git -C D:/code/joshuatech_ver2 commit -am "docs(003-platform-foundation): T043 완료 체크 — AOP CA Secret·clientAuth 승격·Argo Ingress 실행 기록 (49/119)"
```
**게이트**: run-all 전 PASS · specs/README.md 최신 · 런북 T043 절의 숫자 칸 빈 곳 0.

---

## 6. 위험 · 차단 시나리오

| # | 등급 | 내용 · 완화(닫힌 상태) |
|---|---|---|
| **R1** | 차단성 · **무증상** | **순서 사고**: Secret 없이 clientAuth, 또는 되돌리기에서 Secret 선삭제 → `CAFiles is required` → 전 호스트 brokenTLSRouter(파드 Ready·Job 정상·INFO 조용) → Cloudflare 전 호스트 525/526. **완화**: 투입 = Secret → 4중 지문 게이트(단계 5) → clientAuth; 되돌리기 = clientAuth 제거 → spec 빈 값 → addon·Secret; 노드 A 사본 사전 보존; 30초 뒤 특정 패턴 grep(공통 규율 4). |
| **R2** | 차단성 | **clientAuthType 생략 = 즉시 Require**(tlsmanager.go:464). **완화**: v-25 리터럴 정확 일치 단언(M3 Verify / M4 Require) + x-5 '정확히 1회 + 다른 리터럴 없음'. |
| **R3** | 오판 | **keep-alive 오독**(비평 1 major): 적용 직후 프로브가 옛 연결을 타면 `TLSClientSubject` 없음 → '미제시'로 오독하거나, Require 직후 옛 연결로 auth 404가 나와 '강제 실효'로 오독. **완화**: 판정은 spec 반영 시각 + ≥180초(VD-5) 이후 새 연결 프로브 ≥3회로만; 강제 실효의 정본은 노드 내부 curl(항상 새 연결) exit 56/35; edge auth 404는 '장애 없음' 판정에만. |
| **R4** | 차단성 | **edge 미제시 → 전 호스트 525**(문서 미명시). **완화**: Require 승격은 단계 7 양성 증거(TLSClientSubject) 통과 뒤에만. 실패 시 되돌리기 목표는 pre-t043 사본(Verify 사본이 아님 — CA 불일치와 구분 불가하므로). |
| **R5** | 오판 → 불필요 롤백 | **`error` 일반 grep 게이트**(비평 1 major): T098 전 OTLP 잡음으로 항상 ≥1줄 → 매번 되돌리거나 게이트를 무시하는 습관. **완화**: 게이트 패턴 특정화 + 헤더 :112 같은 패턴으로 교체(:64 잡음 서술은 실측으로 확정해 런북에). |
| **R6** | 되돌리기 결함 | **Verify로 하향하는 되돌리기는 CA 불일치에서 복구하지 못한다**(비평 1 major). **완화**: 장애 되돌리기 목표 = clientAuth 없는 사본 고정(공통 규율 2). |
| **R7** | Ingress 누출 | `router.entrypoints` 누락 → traefik(8080)·metrics(9100)에 Access 미경유 평문. **완화**: 어노테이션 필수 + 단계 3 8080 Host 프로브 404(VD-12) + PR 체크리스트; validate 검사는 T047 인계. |
| **R8** | 502 | 백엔드 `https`/443 → 평문 8080에 TLS. **완화**: `port.name: http` 고정, 렌더 게이트 + 노드 내부 curl 200. |
| **R9** | 보안 회귀 · 무증상 | TLSOption `default` 중복(gitops 등) → sniStrict·clientAuth 조용히 소실. **완화**: `kubectl get tlsoption -A` 정확히 1개 게이트 유지 + grep에 `Default TLS Options defined in multiple` 포함. |
| **R10** | Secret 오염 | 라벨 `owner=helm` → informer 제외 → R1. `stringData` 재적용 잡음(VD-18). **완화**: k-3 단언 + 단계 5 라벨·resourceVersion 게이트; 흔들리면 `data:` base64 전환. |
| **R11** | 진단 사각 | 승격 뒤 노드 내부 curl 판별 실험이 000 → 문면 갱신 없으면 다음 운영자가 정상을 장애로 오독. **완화**: D5(ii) + Verify 단계에서 마지막 1회 + 헤더 :116-127·README §9 갱신. 자체 진단 인증서는 CA 개인키가 Cloudflare에 있어 불가. |
| **R12** | CA 교체 | Cloudflare 조기 교체·2029-11-01 만료 모두 자동 경보 없음 → Require 상태에서 전 v2 호스트 525/520. **완화**: 런북 'AOP 의심 시 첫 조치 = pre-t043 사본 롤백 → 새 PEM 지문 대조 → Secret 갱신(옛+새 병기 가능) → 재투입' + 분기 지문 대조(VD-20) + T084 캘린더 + run-all WARN. |
| **R13** | Job 함정 | HelmChartConfig 연속 변경(리허설) 시 Job immutable/pending-upgrade → 두 번째 변경 미반영을 15초 지연으로 오독. **완화**: 변경 사이 Job succeeded=1 확인·≥60초(공통 규율 5). |
| **R14** | 신호 손실 | Ingress health `loadBalancer` 미채움 → platform-argocd Progressing → argo-1·reboot-3 FAIL. **완화**: VD-13 단계 3 게이트; 실패 시 Lua health/분리를 T047 인계. |
| **R15** | 규약 | (B) 선택 시 계약 4곳 정정 연쇄 + 선례 확산 — 각하로 닫힘. (C)의 `kind: Secret` 오독 — 헤더·테스트·계약 :94 '대상 아님' 구절로 완화. |
| **R16** | 게이트 자체 | 정적 슬롯 1l에 시한 FAIL(잔여일)을 두면 2029-05 이후 finish 게이트가 무관하게 막힘(비평 2 minor) — WARN으로 변경해 닫힘. |
| **R17** | 동결 편차 | D2 (a) 선택 시 T038 '초기 Verify'와 편차 → 계약 정정 + 런북 기록 + converge 인계 필수. (b)로 닫힘. |
| **R18** | 커밋 차단 | 새 파일 헤더에 `PRIVATE KEY`·`BEGIN CERTIFICATE` 낱말 → 자기 테스트 FAIL. **완화**: p-1을 PEM 헤더 형태 정규식으로, 헤더 문구는 '개인키 없음'·'PEM 1블록'. |
| **R19** | 복구 경로 | 443 전면 중단 시에도 cloudflared 터널(ssh·k8s)·port-forward 생존(tunnel.tf:20-34), Traefik liveness 8080 /ping이라 파드 재시작 없음 = 무증상 → 능동 확인 필수(단계 게이트). |
| **R20** | 별건 통보 | 2026-09-11 실측 `www` 522 · `cache.joshuatech.dev` 15초 타임아웃 — AOP 무관 v1 경로 상태(US8 전 기록). |

**미해결 없음.** 비평 major 5건은 R3·R5·R6·R17·(D3 M1 보강)으로 닫혔고, 실측이 필요한 것은 §7로 이관됐다.

---

## 7. VD 실측 항목

| ID | 시점 | 기본 가정 | 명령(요약) | 판정 · 실패 시 |
|---|---|---|---|---|
| **VD-1** | 단계 0 | on·editable true·Zone-level false | `GET /zones/{id}/settings/tls_client_auth` · `GET …/origin_tls_client_auth/settings` · `tofu plan -detailed-exitcode` | value==on ∧ editable==true ∧ enabled==false ∧ plan exit 0. 어긋나면 진입 금지. editable false면 Free API 변경 신호 기록 |
| **VD-2** | 단계 4 | 다운로드 PEM = 우리 측정 CA | `openssl x509 -noout -fingerprint -sha256 -enddate -subject` · 2154바이트 | 지문 9A:1A:…:A2:B9 ∧ notAfter Nov 1 17:00:00 2029 GMT ∧ CN=origin-pull.cloudflare.net. 다르면 **중단**(Cloudflare가 CA를 바꿈 → 계약 :94 갱신 뒤 재개) |
| **VD-3** | 단계 5 | 클러스터 Secret = 파일 | `get secret … jsonpath='{.data.ca\.crt}' \| base64 -d \| openssl x509 …` · 라벨 · 키 목록 · addon | 넷 다 일치. 하나라도 다르면 clientAuth 진입 금지 |
| **VD-4** | 단계 5·7·8·11 | 반영 ≈15초 + Job ≈5초, 롤아웃 없음 | `get tlsoption default -o jsonpath='{.spec}'` · `get job helm-install-traefik` · 특정 패턴 grep · 파드 creationTimestamp/restartCount | 기대 spec ∧ Job succeeded=1 ∧ 패턴 0줄 ∧ 파드 불변. 1줄이라도 있으면 즉시 pre-t043 사본 재설치 |
| **VD-5** | 단계 0·7 | idleTimeout 기본 180s, edge↔오리진 keep-alive 재사용 | Traefik args에 `idleTimeout` 유무 · spec 반영 시각 + 180초 뒤 프로브 | 인자 없으면 180s 적용; 값이 있으면 그 값으로 대기 시간 교체 |
| **VD-6** | 단계 7 **핵심** | edge가 제시하고 우리 CA로 검증됨; 리터럴에 `origin-pull.cloudflare.net` 포함(순서·`\,` 이스케이프는 실측) | `curl.exe -sI https://auth.joshuatech.dev/__probe-404` ×3 → `logs … \| Select-String '__probe-404'` | 3줄 전부 `TLSClientSubject` 비어 있지 않음 = 승격 go. `TLSVersion`만 있고 Subject 없음 = 미제시 → 승격 금지, VD-1 재확인, 필요 시 RequestClientCert 임시 진단. 리터럴을 런북·헤더에 고정 |
| **VD-7** | 단계 7·11 | AOP 불일치 = 525(TLS1.3 post-handshake alert의 Cloudflare 분류는 문서 없음 → '525 또는 520'으로 판정) | `curl.exe -sI https://auth.joshuatech.dev/` | 404 = PASS · 525/520 = AOP 불일치 → 즉시 롤백 · 526 = 서버 인증서 별건. 의도적 재현(존 설정 off)은 존 전역 변경이라 하지 않음 |
| **VD-8** | 단계 11 | TLS1.3 exit 56 `certificate required` / TLS1.2 exit 35 `handshake failure`; SNI 불일치는 `unrecognized name` | 노드 A `curl -sk --resolve auth…:10.0.7.78` · `--tls-max 1.2` · `no-such.example.invalid` `-v` | 56/35 + 000 = 강제됨; 숫자 http_code = 미강제 FAIL. stderr 문구를 판별표에 고정 |
| **VD-9** | 단계 11 | Go `TLS handshake error`는 DEBUG(INFO에 안 보임) | `logs --since=2m \| Select-String -CaseSensitive 'handshake' \| Measure-Object` | 0 = 추정 확정 · >0 = 거절 건수 계량 가능으로 문서 정정. 액세스 로그(DownstreamStatus) 줄은 어느 쪽이든 0 |
| **VD-10** | 단계 11 | 서버 인증서는 CertificateRequest 이전 전송 → 클라이언트 인증서 없이 읽힘 | `openssl s_client -connect 10.0.7.78:443 -servername traefik.joshuatech.dev \| openssl x509 -noout -issuer -enddate` | issuer Let's Encrypt YE2 ∧ notAfter Dec 8 2026 |
| **VD-11** | 단계 3 | Ingress 라우터가 TLSOption default를 받음; `router.tls: "true"`가 엔트리포인트 TLS를 대체해도 결과 동일 | 노드 A `curl -skv --resolve argo…` · 대시보드 `/api/http/routers` | issuer LE + HTTP 200 ∧ 라우터 `tls.options` default/빈 값. 자체 서명 = TLS 경로 오류, 404 = Ingress 미인식, 다른 옵션 이름 = FAIL |
| **VD-12** | 단계 3 | entrypoints 어노테이션이 실림 | `curl -H 'Host: argo.joshuatech.dev' http://<podIP>:8080/` | 404 = PASS · 200 = 누락/오타 |
| **VD-13** | 단계 3 | publishedService가 `status.loadBalancer.ingress`를 채워 Healthy | `get ingress argocd-server -o jsonpath='{.status.loadBalancer.ingress}'` · `get app platform-argocd … health` | 비어 있지 않음 ∧ Healthy. 비면 argo-1·reboot-3 FAIL → T047에 Lua health/분리 인계 |
| **VD-14** | 단계 3 | SSE 유지, Cloudflare 100초 타임아웃 미해당 | 브라우저 Applications 3분 + refresh 어노테이션 + DevTools `/api/v1/stream/applications` | 새로고침 없이 갱신 ∧ 524/오류 0. 524면 '주기 재연결(기능 저하)'로 기록 |
| **VD-15** | 단계 0 | ClusterRole view가 ingresses list 포함 | agent-view `auth can-i list ingresses.networking.k8s.io -A` | yes. no면 T041 agent-view-extra 계약 변경 선행 |
| **VD-16** | 단계 4 (D1=C) | gitleaks 기본 규칙·push protection이 공개 인증서를 안 잡음 | `gitleaks dir D:/code/joshuatech_ver2/infra/bootstrap --no-banner --exit-code 1`(운영자 PC 설치) · push 결과 · CI gitleaks job | finding 0 ∧ 차단 없음. 차단되면 키·이름에 secret/token 낱말 재검토 |
| **VD-17** | 단계 8 | 각 방향 ≤30초, 순단 0 | 파일 mtime → `journalctl 'Applied manifest'` · auth 404 연속 | 숫자로 런북 기록 |
| **VD-18** | 단계 5 (D1=C) | `stringData` Secret의 resourceVersion이 재조정에도 불변 | `get secret … -o jsonpath='{.metadata.resourceVersion}'` 5분 간격 2회 | 불변 = PASS. 변하면 `data:` base64로 전환(테스트는 디코드 후 파싱) |
| **VD-19** | 단계 7·9(선택) | Secret 값 교체가 TLSOption·롤아웃 없이 반영 | 같은 PEM으로 파일 touch(주석 1자)·재설치 → 30초 | 패턴 0줄 ∧ auth 404 = 무중단 교체 경로 확인 |
| **VD-20** | 분기 1회(캘린더) | 원본 지문 불변 | `curl -s …/authenticated_origin_pull_ca.pem \| openssl x509 -noout -fingerprint -sha256` · ETag | 9A:1A:…:A2:B9 · `b0b28c5a…`. 다르면 파일 갱신(옛+새 병기) → 테스트 지문 갱신 → 절차 1~2 |
| **VD-21** | **T043 밖**, BFF 착수 전 | edgeWorkerFetch에도 AOP 인증서 제시 | 임의 Worker `fetch('https://auth.joshuatech.dev/')` | 404 = 제시됨 · 525/520 = 미제시 → BFF→pod 경로 재설계(Worker mTLS 바인딩은 proxied 존 불가 520) |
| **VD-22** | **T084** | `cf-access-token` 헤더로 CLI 통과 | `argocd login argo.joshuatech.dev --grpc-web --header "cf-access-token: $(cloudflared access token -app=https://argo.joshuatech.dev)" --username admin` | 'logged in successfully' = PASS · 302/HTML = Service Auth 대안 실측 |
| **VD-23** | 단계 12 | cert-manager-issuers README §4·§9·§12에 노드 내부 curl 의존 문장 있을 수 있음 | `grep -nE 'curl -sk\|--resolve\|노드 내부' …/cert-manager-issuers/README.md` | 매치 있으면 openssl 형식으로 치환, 없으면 무변경 |
| **VD-24** | **T084** | `url` 투입 시 argocd-server 재시작 1회 | `logs deploy/argocd-server \| grep 'url modified'` · `argocd login --sso --grpc-web` | 재시작 1회 ∧ 콜백 성공 |

---

## 8. 테스트 · 문서 변경 목록(파일별)

### 모노레포 `D:/code/joshuatech_ver2`

| 파일 | 단계 | 변경 |
|---|---|---|
| `specs/003-platform-foundation/contracts/hostnames-and-access.md` | M1 | :94 — Secret `kube-system/cloudflare-origin-pull-ca`(키 `ca.crt`, 정본 `infra/bootstrap/cloudflare-origin-pull-ca.yaml`; 값은 공개 인증서 — AGENTS.md 비밀 금지의 대상 아님) · CA 주체 · sha256 지문 · notAfter 2029-11-01 17:00 GMT · 관찰 판정 = 액세스 로그 `TLSClientSubject`(반영 +180초 이후) · 승격 뒤 판정 = exit 56/35 · 되돌리기 순서(clientAuth 제거 → Secret 삭제) · 분기 지문 대조 · 보증 범위('Cloudflare 망 유래'만; 계정 교차 우회 통제 = T084 forward-auth). 전환 순서 문장 유지 |
| `specs/003-platform-foundation/contracts/gitops-repo.md` | M1 | :10 `argocd/` = remote base + patches + `ingress.yaml`(Ingress `argo.` — T043; platform/argocd 자리표시 유지) · :19 `server/manifests/`에 `cloudflare-origin-pull-ca.yaml` 병기(정본 모노레포) |
| `specs/003-platform-foundation/contracts/network-policy.md` | — | **무변경**(각주·PORT_TABLE 동시 처리 = T047) |
| `infra/bootstrap/cloudflare-origin-pull-ca.yaml` | M2 | 신규(§4.2) |
| `tests/infra/cloudflare-origin-pull-ca.tests.ps1` | M2 | 신규(§4.4; p-6 WARN) |
| `tests/run-all.ps1` | M2 | 슬롯 1l(§4.4) |
| `infra/bootstrap/traefik-config.yaml` | M2 | :6 '같은 디렉터리의 cloudflare-origin-pull-ca.yaml 은 공개 루트 CA(비밀 아님)' 보강 |
| `infra/bootstrap/traefik-config.yaml` | M3 | tlsOptions 블록(Verify) · :41-42 과거형(리터럴 보존) · :52 옆 되돌리기 순서 경고 · :53-61 '관찰 단계 투입(날짜)' + 조각 · :68 · :109 · **:112 grep 패턴 특정화** · :64-66 잡음 서술은 실측 뒤 정리 |
| `infra/bootstrap/traefik-config.yaml` | M4 | tlsOptions 블록(Require) · :57-61 '승격 완료' + 실측 리터럴(§4.3) · :116-120 절차 4 기대값 반전 + 443 생존 판정 edge auth 404 · :121-127 SNI ② 재분류 + 구분표 · openssl s_client 1줄 · `/__probe-404` TLSClientSubject 1줄 · :32 재검토 주기에 지문 대조 편승 |
| `infra/cloudflare/zone_settings.tf` | M4 | :26-27 주석 완료형('오리진이 RequireAndVerifyClientCert — T043 완료') · `tofu plan` No changes 런북 기록 |
| `tests/infra/traefik-config.tests.ps1` | M3 | `$allNames` + v-25·v-26·doc-18 · v-20 6키 · v-25(Verify) · v-26 · x-6 반전 · doc-4('관찰 단계 투입' + Verify 리터럴) · doc-18 · 머리 :14·:27-31 → 72/0 |
| `tests/infra/traefik-config.tests.ps1` | M4 | v-25(Require) · x-5 반전('정확히 1회 + 다른 리터럴 없음') · doc-4('승격 완료' + Require + 과거형 Verify) → 72/0 |
| `docs/runbooks/bootstrap.md` | M5 | §3 T043 절(§5 단계 13) · :250 → 1건 · :118 T043→T045 · §4 자리표시 kv 플레이스홀더 1줄 |
| `specs/003-platform-foundation/tasks.md` | M5 | T043 `[X]`만(문면 동결) |
| `docs/decisions/0010-secrets.md` | — | **편집 금지** — 런북에 ':33의 T043은 T044를 뜻함' 기록만 |
| `docs/kr/*` | — | 변경 없음(/finish 몫) |

### gitops `D:/code/platform-gitops`

| 파일 | PR | 변경 |
|---|---|---|
| `bootstrap/argocd/ingress.yaml` | G1 | 신규(§4.1) |
| `bootstrap/argocd/kustomization.yaml` | G1 | resources `- ingress.yaml` · 머리 3) Ingress → '만드는 것', 나머지(OIDC url·oidc.config·RBAC·알림) = T084 |
| `bootstrap/argocd/argocd-cm.yaml` | G1 | :5 '뒤 태스크(T043 · SSO)' → 'T084(SSO: url=https://argo.joshuatech.dev · oidc.config · admin.enabled)' |
| `bootstrap/argocd/argocd-cmd-params-cm.yaml` | G1 | :9 'T043 전 접근은 port-forward' → 'T043(날짜)부터 Ingress argo. + Access; port-forward는 README ⑥ 대체 경로' |
| `bootstrap/README.md` | G1 | ⑥(:125-137) 기본 = Access(GitHub) → Argo UI, port-forward 격하 · :209 절 제목('T041·T043·이후로 넘기는 항목' 갱신) · :215 'T043 = Ingress만(완료). url·oidc.config·rbac·admin.enabled = T084', 호스트 `argo.` |
| `platform/traefik/README.md` | G2 | :79-82 뒤집힌 현재형('T043부터 argo UI도 Traefik 443을 타므로 함께 죽는다; AOP 실패는 525/520 계열, 526은 서버 인증서 계열') · §5 표 argo 행 'Ingress argocd/argocd-server(T043)' · :156·:187-194·:209 §6 즉효 레버 판정 'T043 뒤: 526 = 서버 인증서, 525/520 = AOP — 첫 조치 = pre-t043 사본 롤백' · :291 현재형 · §9 판별 실험 D5(ii) 재작성(openssl s_client · edge auth 404 · 프로브 TLSClientSubject · 판별표 · 180초 규칙 · '승격 전 마지막 점검/재투입 절차 전용') · :339·:364-365 완료형 · §10 ④ 'platform/traefik에 kind Secret 존재 시 FAIL' 후보(T047) · 고아 경고 정상 목록에 `kube-system/Secret cloudflare-origin-pull-ca — 지우면 443 전면 중단` |
| `platform/traefik/kustomization.yaml` | G2 | :22-27 '`clientAuth`(T043)' → 투입 완료 현재형('default 이름 TLSOption을 여기 두면 셋 다 조용히 폐기') |
| `platform/traefik/tlsstore-default.yaml` | G2 | :54 '더해지면 둘 다 사라진다' → 현재형 |
| `clusters/oci-k3s/apps/README.md` | G2 | :36 각주 sniStrict·clientAuth 소실 문장 — 투입 완료 표기 |
| `platform/cert-manager-issuers/README.md` | G2 | VD-23 결과에 따라 노드 내부 curl → openssl 형식(§7·§13은 무변경 확정) |
| `tests/validate.sh` · `.github/workflows/validate.yml` | — | 무변경(T047 인계) |

---

## 9. 인계

**T044(Vault)** — task 문면의 '절차 한 줄(US6 준비)': **Vault 가동 뒤 US6 배포 전에 운영자가 `kv/{env}/authentik/*`·`kv/{env}/openfga/*`에 플레이스홀더 값을 투입한다** — T044 이후이므로 T043에서는 런북 §4 자리표시에 기록만 하고 실행하지 않는다. AOP CA는 Vault/ESO에 넣지 않는다(공개값 · K3s 번들 Traefik이 Vault보다 먼저 기동 — D1).

**T045(ESO)** — `cloudflare-dns-token`은 ESO로 이관되지만 `cloudflare-origin-pull-ca`는 이관 대상이 아니다(모노레포 K3s manifests 정본 유지). 런북 '노드 A manifests 파일' 범주에 두 파일(traefik-config.yaml·cloudflare-origin-pull-ca.yaml)을 함께 열거; T045의 수동 Secret 교체 목록에서 제외 명시. VD-E(ESO Owner 인수) 결과와 함께 처리.

**T047(validate.sh·CI 연결)** — ① validate.yml 골격 → validate.sh 연결(지금은 Ingress 스키마가 CI에서 검증되지 않음 — T043 PR들은 로컬 결과를 PR 본문에) ② 신규 검사 후보: Ingress 문서마다 `router.entrypoints`==websecure 필수 + backend port `https*`/443 FAIL; platform/traefik 렌더 kind ∉ {Middleware,TLSOption,TLSStore} FAIL(kind Secret 포함) ③ **network-policy.md 포트 각주와 PORT_TABLE에 `argocd 8080 argocd-server` 행을 같은 창에서**(모노레포 계약 커밋 선행) ④ VD-13 결과에 따라 Ingress health Lua 또는 Application 분리 ⑤ Argo 고아 경고 `orphanedResources.ignore` 일괄 검토(k8s-security 경계).

**T084(SSO·forward-auth·secret-rotation.md)** — ① `argocd-cm url: https://argo.joshuatech.dev`(research :534의 `argocd.` 오기) + oidc.config + admin.enabled + Authentik redirect URI `https://argo.joshuatech.dev/auth/callback`를 한 PR로(재시작 1회, VD-24) ② `docs/runbooks/secret-rotation.md` 캘린더에 'AOP CA notAfter 2029-11-01 · 지문 9A:1A… · 갱신 = 파일 ca.crt 값 교체(옛+새 병기 가능, Traefik informer 자동 반영) · 분기 지문 대조(VD-20)' ③ CLI Access 통과 헤더 실측(VD-22) ④ 대시보드 forward-auth = Global CA 전 계정 공유에 따른 계정 교차 우회의 유일한 오리진 측 통제 — T043 완료 보고의 '방어 범위' 문장과 연결.

**T098(관측)** — Traefik 액세스 로그 `TLSClientSubject`·`TLSVersion`을 Alloy 라벨/필드로 보존; edge 525/520 급증 경보(AOP 불일치 신호) + `CAFiles is required` 로그 패턴 경보 후보; VD-9가 0이면 AOP 거절 계수는 로그로 불가 → edge 525 계수 또는 Traefik 메트릭 대체; OTLP 4317 잡음 정리(헤더 :64 서술 확정).

**T114(월간 점검·break-glass)** — 재부트스트랩 체크리스트에 '노드 A manifests 두 파일을 traefik-config.yaml → 아니라 **cloudflare-origin-pull-ca.yaml 먼저** → traefik-config.yaml 순으로 설치'; 월간 점검에 run-all 1l WARN 잔여일 확인 + 분기 VD-20; D1=A였다면 C로 승격(라이브 변경 0).

**converge(문면 편차·정정 후보)** — ① tasks T043 'RequireAndVerifyClientCert 전환' = 관찰(T038 초기값) → 승격으로 실행(편차 없음, 기록만) ② research ARGOCD-D11 IngressRoute 2-rule+h2c vs spec FR-011 표준 Ingress(Access가 gRPC 미지원) ③ research :534 `argocd.joshuatech.dev` → `argo.` ④ hostnames-and-access.md:43 include 이메일 `<access-email>` vs access.tf 주석 `<operator-email>`(결정 B 2026-09-07, tfvars 정본) ⑤ bootstrap.md:118 'Vault 투입은 T043' → T045 ⑥ gitops README:82 '526' 문맥 — AOP 실패는 525/520 계열로 구분 ⑦ 헤더·계약 :94·research K3S-D7의 관찰 단계 서술에 'VerifyClientCertIfGiven은 CA 불일치에 무해하지 않다' 주석 ⑧ FR-011 PLACEHOLDER/overlay는 apps/ 전용, 플랫폼 Ingress는 리터럴 호스트 ⑨ ADR 0010:33 'T043–T045' 순서 표기(본문 편집 금지 → 기록).

**BFF/Workers 태스크(US4/US5)** — VD-21(edgeWorkerFetch에 Global AOP 인증서 제시)을 BFF 첫 배포 전 게이트로; Worker 자체 mTLS 바인딩은 proxied 존 불가(520)라 대안이 좁다는 사실을 설계 전제에.

**별건 통보(사용자)** — 2026-09-11 실측 `www` 522 · `cache.joshuatech.dev` 15초 타임아웃(curl 28) — AOP 무관 v1 경로, US8 컷오버 전 기록.

**사용자 결정 필요(착수 전, 한 번에 하나씩)** — D1 C · D2 (b)(소크 길이 포함) · D3 bootstrap/argocd + M1 :10 · D4 T084 · D5 (ii) · D6 7건 분리. 추가 1건: 관찰 단계에서 `TLSClientSubject`가 비어 나올 때 `RequestClientCert` 임시 진단 투입을 허용할지.