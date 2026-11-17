# T073 설계: `apps/identity-admin` 생성 · 모델 · API · beat · 시드 → T066 PASS

2026-11-12 확정(컨트롤러). 경과는 다음과 같다.
- 조사 `wf_f01d2b5d-63b`(리더 5 — 발견 164건 · 열린 질문 74건 · 보고 `.superpowers/t073/research/*.json`)
- 설계 초안 `wf_a09c5a74-a30`(D1–D28 · 보고 `.superpowers/t073/design-draft.md`)
- 비판 `wf_79a84bf9-f57`(A 계약 · 완전성 approve_with_fixes high 1 · medium 6 · low 8 / B 실패 양상 · 위생 approve_with_fixes high 1 · medium 3 · low 7 — 보고 `.superpowers/t073/design-critic{A,B}.json`)
- 컨트롤러 결정 Y1–Y24(비판 반영 — `.superpowers/t073/decisions-controller.md`)
- 폐기 최종성 분석 `wf_6a1dd5d0-d8f`(사실 검증 2 → 설계 변형 4 → 판정 → 반박 — 보고 `.superpowers/t073/epoch/`)
- 사용자 결정 둘(2026-11-12): 폐기 최종성 = 「로그 파생 + 수명 30일」 · 일 1회 대조 = 「이벤트 대조 구현」
- 컨트롤러 결정 E1–E14(분석 반영 — 같은 결정 문서)
- 최종 설계 워크플로 `wf_8b1b5785-fb3`의 검토 3렌즈(A 결정 반영 · 일관성 12건 / B 보안 · 실패 양상 10건 / C 빌드 가능성 14건 — 셋 다 approve_with_fixes · high 0 · medium 6 · low 30 · 보고 `.superpowers/t073/reviews/final-reviews.json`)
- 컨트롤러 결정 W1–W36(검토 반영 — 같은 결정 문서)
- 검토 반영 워크플로 `wf_7bdc5270-c6d`의 재검토 2렌즈(A 반영 · 일관성 6건 / B 보안 · 실패 양상 16건 — 둘 다 approve_with_fixes · high 0 · medium 3 · low 19 · 보고 `.superpowers/t073/reviews/fix1/final-reviews.json`)
- 컨트롤러 결정 Z1–Z22(재검토 반영 · 마감 라운드 — 같은 결정 문서)
- 마감 워크플로 `wf_66532cef-008`의 변경분 확인(approve_with_fixes · high 0 · medium 0 · low 2 · 제안 일곱 — 보고 `.superpowers/t073/reviews/fix2/fix2-review.json`) → 컨트롤러가 직접 반영(§10 (마))

본문은 반영 뒤 모양이고 반영 내역은 §10 반영표에 있다. 반영으로 바뀌거나 더해진 곳에는 〔Y n〕 · 〔E n〕 · 〔W n〕 · 〔Z n〕을 단다. W가 Y · E와 다른 곳은 W를 따랐다(신선도 키의 수명 · nbf 상한의 기준 시계 · 관리 명령의 `--sid` · VD-T073-11과 VD-T073-15의 자리와 절차 · 조각 ①의 범위 — §10 (다)). Z가 W와 다른 곳은 Z를 따랐다(웹훅 본문 `nbf`가 상한을 넘을 때의 처리 · `PARTIAL`의 종료 코드 · 조각 ③-b의 가름 · VD-T073-9 · 10의 자리 · 복구 시간 상한의 문면 — §10 (라)). 빌드 라운드의 결과와 정정은 bn 「## T073」 절에 이어 적는다(이 문서는 태스크가 닫히면 고치지 않는다 — 규칙 specs.md).

수(본문에서 다시 센 값): 결정 D1–D30 · 계약 · 규칙 보정 C1–C49(48항목 — C31은 빈 번호 · 〈설계 커밋〉 46 + 〈조각 ⓪〉 2) · T073 소유 시험 ia-1–ia-41 · T073 안 VD-T073-1–16과 VD-T073-CI · 라이브로 넘긴 VD 12 · report 편차 후보 29행 · 사용자 결정 확정 3 · 대기 6.

표기는 다음과 같다.
- 「T066 고정」: 계약이나 T066 시험이 이미 정한 것이라 다시 정하지 않는다.
- 「공백 → 설계」: 계약에 없던 것을 이 설계가 정했다는 뜻이다. 해당 계약 보정을 C n으로 함께 단다.
- 〔편차 n〕: report.md 편차 후보(§1 목록의 번호 — 초안과 결정 문서가 「R n」으로 부른 것과 같은 번호다).
- 〔UD-n〕: 사용자 결정(§8 — 확정과 대기).
- 「추론」: 실측하지 않은 판단. 실측이 필요한 것은 VD로 넘긴다.

## 약어

- **api계약** = `specs/003-platform-foundation/contracts/identity-admin-api.md`
- **dl** = contracts/denylist.md · **bff** = contracts/bff-api.md · **pt** = contracts/pod-template.md · **ev** = contracts/events.md · **gr** = contracts/gitops-repo.md
- **dm** = data-model.md · **bn** = design/build-notes.md · **t072** = design/t072-design.md
- **tasks** · **spec** · **plan** = 같은 디렉터리의 승인 고정 문서 · **규칙** = `.claude/rules/django-pod.md`
- **H/** = `templates/django-pod/` · **T/** = `templates/django-pod/template/` · **P/** = `T/{{ pod_snake }}/`
- **IA/** = `apps/identity-admin/` · **dc/** = `packages/django-common/src/django_common/`
- **〔S · T · P · L n〕 · 〔조사 E n〕** = 조사 JSON(spec · tests · template · library · external)의 발견 ID. 외부 URL과 실측 출처는 그 JSON에 있다. external의 발견은 결정 E n과 글자가 겹쳐 「조사」를 붙여 쓴다(〔조사 …〕로 시작하는 괄호 안의 E n은 모두 조사 발견이다 — 결정 문서 Y12의 「E19」도 이것이다).
- **〔Y n〕 · 〔E n〕 · 〔W n〕 · 〔Z n〕** = 컨트롤러 결정(`.superpowers/t073/decisions-controller.md` — Y1–Y24는 비판 반영, E1–E14는 폐기 최종성 분석 반영, W1–W36은 최종 설계 검토 반영, Z1–Z22는 재검토 반영 · 마감 라운드)이자 §10 반영표의 항목.
- **〔V n〕 · 〔R n〕** = 폐기 최종성 분석의 사실 검증 ID(V1–V17 = `.superpowers/t073/epoch/epoch-vAuthentik.json` — Authentik 소스 판독 · R1–R20 = `epoch-vRepo.json` — 저장소 제약). **〔ATK-n〕** = 같은 분석의 반박(`epoch-refutation.json`)이 돌린 공격 번호.
- **A-n · B-n** = 설계 비판의 발견 번호(`design-criticA.json` · `design-criticB.json`). 최종 설계 검토의 발견(`.superpowers/t073/reviews/final-reviews.json` — 렌즈 A · B · C)은 글자가 겹쳐 「검토 A-n」처럼 「검토」를 붙여 쓴다(§10 (다)). 재검토의 발견(`.superpowers/t073/reviews/fix1/final-reviews.json` — RA-1–6 · RB-1–16)은 「재검토 RA-n · RB-n」으로 쓴다(§10 (라)).
- 이 문서가 인용하는 계약 · dm · 규칙의 줄 번호는 이 설계 커밋의 보정이 들어가기 전(HEAD `3626d16`) 번호다 — 보정 뒤에는 줄이 밀리므로 문장으로 다시 찾는다(§4 머리말과 같다). 〔W12〕

---

## 1. 과제 문면과 계약 우선 원칙

### 문면 요약(tasks:190)

- copier 생성 명령: `copier copy templates/django-pod apps/identity-admin --data pod_name=identity-admin owns_events=[session.revoked,user.registered,tenant.created]`
- 모델: Tenant · TenantMembership · SessionRevocationLog(모두 B 등급) + 「RLS 마이그레이션」
- 시드 명령: `seed_tenant --tenant-id <고정 UUID>`
  - 멱등이어야 한다.
  - 멤버십은 2건이다.
  - 파생 쓰기 3종(Authentik 그룹 소속 · `user.attributes.tenant_id` · FGA 튜플)을 쓰는 주체는 seed 하나뿐이다.
- API 4개
  - `/session/check`
  - `/sessions/revoke`: 로그 + outbox → SET → Authentik revoke(Celery, 5 s × 3)
  - `/webhooks/authentik`
  - `/tenants/me`
- beat 3종: 30 s 재적용 · 일 1회 `reconcile_authentik_sessions` · 일 1회 purge
- Authentik 클라이언트: svc DNS만 쓰고, dev에서는 쓰기 호출을 끈다.
- 완료 조건: T066 PASS

### 계약 우선 원칙

어긋날 때 무엇이 이기는지는 다음 순서로 정한다.
- 문면과 계약이 다르면 계약이 이긴다(규칙:14).
- 계약과 T066 시험이 다르면 T066 시험이 이긴다. 그 시험은 T066 r1–r4 계약 보정과 함께 확정됐다(bn:811). 계약을 시험에 맞춘다.
- 계약 · 시험이 외부 실제 동작과 다르면 외부 동작을 따른다. 외부 동작은 Authentik 2026.8.0 소스와 OpenFGA v1.19.0 실측을 말한다. 계약을 고치고, 시험은 가짜 서버 충실도 문제로 VD에 남긴다.
- tasks · spec · plan은 승인 뒤 고정이다. 낡은 문장은 계약 · dm · bn · report에서만 바로잡는다.

### 문면 · 정본 · T066 시험의 어긋남(정본을 따른다)

- **A1** 생성 명령에 `--trust` · `--defaults` · `--overwrite`가 없고, 키마다 `--data`를 주지 않는다(tasks:190). 실측 꼴은 pt:3 · 〔P35 · S13〕을 따르고 실행 위치는 D2다. 〔편차 1〕
- **A2** owns_events가 3개다. 이 설계는 `session.revoked` 하나로 줄인다(D22). 〔편차 2〕
- **A3** 「RLS 마이그레이션」은 B 등급 3표에 적용할 대상이 없다. RLS를 켜면 check_rls가 실패한다(pt:59 ② · 〔S15 · T25〕). 〔편차 3〕
- **A4** 문면의 `seed_tenant --tenant-id`만으로는 부족하다. `--owner-sub` · `--member-sub`가 필수다(dm:22 · test_api.py:713-737 · spec:282 · tasks:219). 〔편차 4〕
- **A5** 「owner role = 마이그레이션 · 시드 전용」(spec:314 · 429 · dm:121 · pt:58)과 달리, `seed_tenant`는 runtime 프로필 · app role로 돈다(D19). 〔편차 5〕
- **A6** 문면의 「Authentik revoke 호출」은 실제로는 사용자 단위 세션 삭제 위임이다(D16).
  - sid 단위와 웹훅 경로에서는 위임하지 않는다.
  - FR-024 「Authentik 토큰 revoke」(spec:264)와 T083의 `/api/v3/core/tokens/`(tasks:219)는 다른 API다(〔조사 E7〕). 〔편차 6〕
- **A7** `reconcile_authentik_sessions`의 「활성 세션 API와 대조」(spec:206 · tasks:190)로는 유실 웹훅을 알 수 없다. events API의 logout 이벤트와 대조한다(D17 · 〔조사 E32〕 — 사용자 확정 2026-11-12 · 〔E8〕). 〔편차 7〕
- **A8** T081 · dm §9의 서비스 계정 권한 목록(tasks:217 「사용자 read · `delete_authenticatedsession` · 토큰 revoke」)이 시드 · 대조 · 삭제에 모자라고, 「토큰 revoke」는 줄 수 없는 권한이다(〔조사 E4 · E7〕). 〔UD-2〕 〔편차 21〕
- **A9** T083 「platform-admin 소속도 seed가 쓴다」(tasks:219)가 T066 미끼 단언(test_api.py:303-308 · 702-705)과 정면으로 어긋난다. 〔UD-3〕 〔편차 24〕
- **A10** SC-003 · US4 AC4의 「Authentik 세션 삭제 → 웹훅」(spec:107 · 328)은 성립하지 않는다. Authentik은 세션 삭제 이벤트를 만들지 않는다(〔조사 E14〕). 〔UD-4〕 〔편차 25〕
- **A11** US4 AC3 「identity-admin이 refresh 토큰을 revoke」(spec:106)와 달리, refresh 폐기는 BFF가 한다(bff:32 · 〔조사 E7〕). Authentik은 세션을 지워도 refresh 토큰을 남기므로(〔조사 E8〕) 폐기 전에 시작한 세션의 종료는 세션 하한과 절대 수명이 맡는다(D29 — 사용자 확정 2026-11-12 〔UD-5〕). 〔편차 12 · 18 · 19〕
- **A12** 문면에 없지만 다른 근거가 요구하는 작업이 있다.
  - CI job(D27) 〔편차 11〕
  - 템플릿 문서 정정(D3) 〔편차 14〕
  - T066 독스트링 정합(D26) 〔편차 13〕
  - 생성물 손 수정. 「수정 없이 통과」는 sample-pod의 성질이다(D3). 〔편차 15〕
  - 관리 명령 `revoke_sessions`(D30 — SP-1에는 관리자 폐기를 부를 다른 길이 없다 · 사용자 단위만 · 〔Y23 · W13〕) 〔편차 17〕
  - 세션 하한 키 · 세션 절대 수명 30일 · 재적용 신선도 키(D29 · D14 — 〔E1 · E2 · E5〕) 〔편차 18 · 19〕
- **A13** plan의 낡은 판(cloudevents · django-health-check · OTel 1.44 · ninja 폴백 1.6.2)은 쓰지 않는다(plan:17 · 〔S35〕). 폴백 판은 1.6.5로 바로잡는다(D28). 〔편차 10〕
- **A14** 교환 토큰에는 `sid`가 없다(〔조사 E9 · V4〕). 그래서 pod 경계의 즉시 거부(「같은 access 토큰 401」 — spec:100 · 106 · 328 · tasks:212 · quickstart:90)는 사용자 단위 폐기(`revoked:sub`)에서만 성립한다. `sid` 단위 폐기는 BFF의 `/session/check`(`sid` 질의)와 BFF의 refresh 폐기로만 집행된다. T073 코드는 그대로다(T066 고정 — api-12는 손으로 만든 `sid` 있는 토큰을 쓴다). 기본 로그아웃 범위는 〔UD-7〕이다. 〔Y1〕 〔편차 16〕
- **A15** T081 Rule의 이벤트 「login · logout · model_deleted session」(tasks:217)은 logout만으로 줄인다(D21 — login은 토큰 교환마다 생기고 세션 삭제 이벤트는 없다 · 〔조사 E14〕). 〔편차 22〕

### 계약 · 시험 · 외부 동작의 어긋남과 고칠 쪽

- **G1** SET 실패 처리가 문서마다 다르다. dl:28은 「로그 + Celery 재시도」, api계약:58은 「202 · 30 s 재적용」이다. dl을 고친다(D13 · C12). 〔편차 8〕
- **G2** 요청 경로 「EX 330」 고정은 과거 nbf 웹훅에서 키 수명과 `expires_at`이 어긋난다. 계약을 고친다(D13 · C4). 〔편차 9〕
- **G3** 웹훅 action `session_deleted`(api계약:58 · api-20)는 Authentik이 만들지 않는 값이다. 받아도 해가 없으므로 계약 · 시험은 그대로 두고 UD-4로 넘긴다.
- **G4** Authentik 차트 Service 포트는 80이고, 계약 · api-48은 `:9000`이다. T080 values를 고친다(D20 · 〔조사 E17〕).
- **G5** t072:1211의 「멤버를 안 빼면 루트 잠금을 고친다」는 틀렸다. 실측하면 uv lock이 실패한다(〔P3〕). 설계 문서는 닫혔으므로 정정은 bn 「T073」 절에 적는다.
- **G6** pt:69 startupProbe의 「거부 목록 기동 재적용 대기」는 틀렸다. 재적용은 Celery `beat_init`에서 일어난다. 계약을 고친다(C18).
- **G7** dm:121 · pt:58의 「owner = 시드 전용」은 T066이 default 별칭(app role)으로 시드를 부르는 것과 다르다. 계약을 고친다(C17 · C25).
- **G8** 템플릿 README 「재생성」의 문장 셋이 실측과 다르다(〔P7 · P8 · P9 · P39〕). 템플릿 문서를 고친다(D3).
- **G9** api계약 §이벤트 표가 스키마보다 낡았다(registered_at · display_name이 빠짐 — 〔L18〕). 표를 고친다(C6).
- **G10** 생성물 ACL은 `%R~revoked:*`이고 dl:42는 쓰기 규칙이다. 생성물을 고친다(D24).
- **G11** T066 독스트링(래퍼 setdefault · 형식 검사 없음 · `-p no:django` · 「커밋 후 SET EX 330」 — test_api.py:14)이 실제 · 보정된 계약과 다르다. 독스트링만 고친다(D26 · 〔Y15〕).
- **G12** 웹훅 ±5분 창과 Authentik 재시도 최대 약 15분이 어긋난다. 창은 유지한다(D21). 유실분은 D17이 이벤트 시각 기준으로 기록하고, 그 행이 세션 하한을 만든다(D29).
- **G13** dl:19 · api계약:24는 「`sid` 클레임이 있으면 `revoked:sid`를 본다」인데 pod가 받는 교환 토큰에는 `sid`가 없다(〔조사 E9 · V4〕). 계약에 한계를 적는다(C4 · C40 — A14 · 〔Y1〕).
- **G14** 가짜 OpenFGA는 다른 store에 404 `store_id_not_found`를 주고 v1.19.0 실측은 쓰기 400 · 읽기 200이다(〔조사 E19〕). 가짜 충실도 차이일 뿐 동작 영향은 없다 — D19는 쓰기 응답으로만 판정하고 2xx가 아니면 모두 실패다(VD-T082-1 · 〔Y12〕).
- **G15** dm:57 「웹훅 행만 `event_pk` 값이 있다」는 일 1회 대조 보정 행과 어긋난다. 계약을 고친다(C24 · 〔Y15〕).
- **G16** bff:21의 `issued_at`은 저장소에서 그 한 줄에만 나오고 정의가 없다. `/session/check`에 보내는 `iat`의 원천도, refresh · 프록시 앞의 폐기 확인도 계약 표에 없다(spec:263은 「요청 처리 전 확인」이다). 교환 토큰 캐시 키는 `sub+aud`다(bff:24). 계약을 고친다(C36 · C43–C45 · 〔R12 · R13 · R14〕 · 〔E4〕).
- **G17** dm:164 · 187의 서비스 계정 권한 「토큰 revoke」는 Authentik에 없는 권한이다 — 비슈퍼유저는 남의 OIDC 토큰을 지울 수 없다(〔조사 E7 · V6〕). 계약을 고친다(C26 · C27).
- **G18** dl:30 「재적용 행 수는 수십 건」은 세션 하한 뒤 30일치 사용자 단위 행으로 는다. 문장을 고친다(C13 · 〔R10〕).
- **G19** dm:190의 Rule 이벤트 「`logout` · `login` · `model_deleted(session)`」은 만들 수 없거나 해롭다(A15). 계약을 고친다(C27).

### report.md 편차 후보(승인 고정 문면과 달라지는 것)

고정 문면(spec · plan · tasks)은 고치지 않는다. 계약 · dm을 고치고(§4) 아래를 report.md에 편차로 옮긴다. 번호는 본문의 〔편차 n〕이다. 23 · 25는 사용자 결정(UD-1 · UD-4)이 그 답으로 정해질 때만 편차가 된다.

| # | 고정 문면(줄) | 달라지는 것 | 자리 |
|---|---|---|---|
| 1 | tasks:190 생성 명령 | `--trust` · `--defaults` · `--overwrite` · 키마다 `--data` · 하네스 copier(`uv run --project`) | D2 · C20 |
| 2 | tasks:190 `owns_events` 3개 | `session.revoked` 하나 | D22 · C6 |
| 3 | tasks:190 「RLS 마이그레이션」 | B 등급 3표에 RLS 연산 0 | D5 |
| 4 | tasks:190 · spec:282 `seed_tenant --tenant-id`뿐 | `--owner-sub` · `--member-sub` 필수 · 선택 `--authentik-token-stdin` | D19 · C22 |
| 5 | spec:314 · 429 owner role 「마이그레이션·시드 전용」 | 시드 명령은 runtime 프로필 · app role | D19 · C17 · C25 · C28 |
| 6 | tasks:190 · spec:264 · 422 「Authentik (토큰) revoke」 · tasks:219 `/api/v3/core/tokens/` | 사용자 단위 폐기의 Authentik 세션 삭제 위임(토큰 API가 아니다) | D16 · C4 · C7 |
| 7 | spec:206 · tasks:190 「활성 세션 API와 대조」 | logout 이벤트 72시간 창 대조 | D17 · C7 |
| 8 | (고정 문면에 해당 줄 없음 — 계약 dl:28 정정) | SET 실패 = 로그만 · 30 s 재적용(Celery 재시도 없음) | D13 · C12 |
| 9 | tasks:190 · spec:106 · 264 · 310 「TTL 330 s」 | 요청 경로 TTL = `min(330, 남은 초)` · 1 미만이면 쓰지 않는다 | D13 · C4 · C12 |
| 10 | plan:17 ninja 폴백 1.6.2 등 | 폴백 1.6.5 · 낡은 판 미사용 | D28 · C1 · C16 |
| 11 | tasks:190(문면에 없음) | CI job `identity-admin` | D27 |
| 12 | spec:106 · 264 「identity-admin이 refresh 토큰을 revoke」 | refresh 폐기는 BFF의 RFC 7009 | D16 · D29 · C4 |
| 13 | tasks:190(문면에 없음) | T066 시험 파일의 독스트링 · 주석 정합(단언 변경 0) | D26 |
| 14 | tasks:190(문면에 없음 · T072 산출물) | 템플릿 README 「재생성」 · copier.yml 머리 주석 정정 | D3 · C34 · C35 |
| 15 | spec:141 · tasks:168 「생성물 · 생성한 pod는 수정 없이 … 통과」(계약 pt:3) | identity-admin은 템플릿 소유 15파일을 손으로 고친다 | D3 · C20 |
| 16 | spec:100 · 106 · 328 · tasks:212 · 224 「로그아웃 뒤 같은 access 토큰 401」 | pod 경계에서는 사용자 단위 폐기에서만 성립(교환 토큰에 `sid` 없음) | A14 · C4 · C40 · UD-7 |
| 17 | tasks:190(문면에 없음) | 관리 명령 `revoke_sessions --sub`(사용자 단위만 — 단일 세션 폐기 수단은 두지 않는다 · 〔W13〕) | D30 · C38 |
| 18 | (승인 문면에 없는 새 동작 — 사용자 결정 2026-11-12) | 세션 절대 수명 30일: `/session/check`가 시작한 지 30일 넘은 세션을 inactive로 판정 | D29 · C3 · C45 |
| 19 | spec:206 · 264 · 310 · tasks:190 「거부 목록 키 둘 · TTL 330 s」 · 「삭제된 세션은 access TTL 뒤 끝난다」 | 세션 하한 키(30일) · 재적용 신선도 키 추가 — 폐기 전에 시작한 세션은 하한과 절대 수명이 끝낸다 | D29 · D14 · C39–C41 |
| 20 | tasks:241 · 247 · 224 | BFF 폐기 확인 자리(네 라우트 · refresh · 교환 앞) · inactive 처리(RFC 7009) · 캐시 키 둘 · T085 측정 사례 추가 | C36 · C43–C45 · §7 |
| 21 | tasks:217 서비스 계정 권한 「사용자 read · `delete_authenticatedsession` · 토큰 revoke」 · dev 「사용자 read만」 | 「토큰 revoke」 삭제 · 권한별 표(`view_authenticatedsession` · `view_event` 등 — 부여는 UD-2) | C26 · C27 · UD-2 |
| 22 | tasks:217 Rule 「login · logout · model_deleted session」 | logout만 · 매핑 `nbf` 필수 | D21 · C27 |
| 23 | tasks:216 · plan:17 Authentik 2026.8.0(helm 2026.8.0) | 판 결정(UD-1 — 결정되면) | UD-1 |
| 24 | tasks:219 「`platform-admin` … seed_tenant가 쓰는 파생」 | seed는 `platform-admin`을 건드리지 않는다(T066 고정) | D19 · UD-3 |
| 25 | spec:107 · 328 · tasks:212 · 224 「Authentik 세션 삭제 → 웹훅」 | Authentik은 세션 삭제 이벤트를 만들지 않는다 — 경로 정의(UD-4 — 결정되면) | G3 · UD-4 |
| 26 | docs/decisions/0006:29 「identity-admin이 Authentik revoke」 | converge에서 새 ADR(세션 폐기 최종성 = 하한 + 절대 수명 · refresh 폐기 주체 = BFF) — 설계 커밋에서는 만들지 않는다 | §7 · 〔E11〕 |
| 27 | tasks:212 · 224 「m2m 호출은 Access 서비스 토큰 `tester-m2m`」(→ `/tenants/me` 401 · `identity-m2m-dev` 200) | pod는 Access `common_name`이 `ACCESS_EXPECTED_CN`(web-bff Client ID 하나)인 호출만 받는다 — `tester-m2m`으로 헬스 밖 경로를 직접 부르면 403 `access_required`다(T070 구현 그대로 · 이 설계가 계약 §관리 명령에 처음 적었다). 측정 경로는 T079 설계가 정한다 | D30 · C38 · C33 (가) · §7 T079 · T085 |
| 28 | spec:264 · tasks:217 「Authentik revoke·reconcile 쓰기 호출은 dev에서 설정 플래그로 비활성」 | 일 1회 대조는 Authentik에 쓰지 않는다 — 보정은 자기 DB 기록(로그 · 이벤트 · 세션 하한)이라 `AUTHENTIK_WRITES_ENABLED`와 무관하고, dev 수행 여부는 `view_event` 부여를 따른다(이전 계약 문구는 보정을 플래그로 껐다) | D17 · D18 · C7 · C8 · C27 |
| 29 | spec:205 「실제 창은 최대 30 s로 좁혀진다」 · tasks:224 「Dragonfly pod SIGKILL 후 재기동 시 ≤ 30 s 안에 폐기된 세션이 다시 401」 | 유실 뒤 복구 시간의 상한 = 다음 tick(30 s) + 워커가 먼저 받은 작업들의 마감 + 워커 재접속 — solo 워커가 다른 작업을 돌거나 브로커에 다시 붙는 동안 30 s 재적용이 밀린다(운영 토폴로지 값은 T085 실측) | D29 · C13 · C48 · C24 (자) · C42 · §7 T085 |

- 행 27 · 28은 최종 설계 검토에서 더했다(〔W1 · W8〕). 행 15 · 23의 인용 줄도 그때 바로잡았다(tasks:190에는 「수정 없이」가 없다 — 컨트롤러 확인).
- 행 29는 재검토에서 더했다(〔Z1〕 — 인용한 두 줄은 그 줄만 읽어 확인했다). 같은 라운드에 행 27의 「자리」 칸에 C33 (가)를 더했고(〔Z2〕), 행 28의 인용 줄을 spec:264 · tasks:217 둘로 줄였다(〔Z4〕 — 앞 라운드가 함께 든 tasks:190의 문구는 「revoke·세션 삭제 등 쓰기 호출」이라 설계의 플래그 대상과 어긋나지 않는다).

---

## 2. 소스로 확인한 사실(설계에 꼭 필요한 것만)

- **①** T066 현황
  - 시험 76개 = 함수 56 + parametrize 20.
  - 템플릿 생성물에 세 파일을 복사해 돌리면 13 PASS / 63 FAIL이다. 가짜 자기검사 26 PASS, 템플릿 시험 165 PASS다.
  - 실패 63개는 전부 「구현 없음」이고 8묶음이다: 모델 27 · revoke 6 · 웹훅 면제 1 · Access 전용 6 · OpenAPI 2 · beat 1 · seed 8 · conf 12. 인프라 결함은 0이다(〔T1 · T2〕).
- **②** 루트 워크스페이스
  - 멤버에 identity-admin이 있다(pyproject.toml:3-7). uv.lock에도 virtual로 있다(:5-9 · 348-350). pod는 스텁이다(IA/pyproject.toml:1-5).
  - 멤버로 둔 채 생성하면 `_tasks: uv lock`이 실패한다(copier exit 1). 반쯤 생성된 트리가 남고 루트 잠금은 바뀌지 않는다(〔P3〕).
  - 멤버를 빼면 루트 잠금이 낡아 다시 잠가야 한다. diff는 identity-admin 2곳과 revision 3→5뿐이다(〔P4〕).
  - `exclude`는 uv 동작에 차이가 없다. 방어용이다(〔P5〕).
  - CI lint · test의 첫 스텝이 `uv sync --locked`다(ci.yml:328 · 371).
- **③** 생성 실측
  - `--trust --defaults --overwrite --data pod_name=… --data 'owns_events=[…]'`가 rc 0으로 끝난다(〔P1 · P6〕).
  - 충돌은 스텁 pyproject 하나뿐이다. T066 세 파일은 보존되고 `tests/__init__.py`가 새로 생긴다.
  - `--overwrite` 없이 비대화로 돌리면 InteractiveSessionError다.
  - 대상이 이미 있으면 uv lock이 실패해도 copier가 지우지 않는다(H/.venv copier/_main.py:1291 — 〔P7〕).
  - `recopy`는 저장소 루트 cwd에서만 된다. 손으로 고친 템플릿 파일은 되돌아가고, 템플릿에 없는 새 파일은 남는다. `--defaults`가 기록된 답을 다시 쓴다(〔P9〕).
- **④** 최소 확장 시제품
  - 템플릿 기본 시험이 정확히 2개 깨진다: T/tests/test_auth_middleware.py.jinja:669-675(필수 집합 상수)와 test_outbox.py.jinja:716(beat 목록). 스냅샷도 갱신해야 한다(〔T21 · P10〕).
  - 시험 래퍼에 새 필수값을 넣지 않으면 pytest-django가 ImportError로 시작하지 않는다(〔T20 · P11〕).
- **⑤** conf 확장 지점(P/conf.py.jinja)
  - `SECRET_SETTINGS`는 getattr 값이 비면 거부한다. 필드가 없는 이름도 거부한다(:81 · 349).
  - `IN_CLUSTER_URL_SETTINGS`는 따로 파싱하는 셋 밖의 이름을 http(s) URL로 일반 계산한다(:85 · 376-399).
  - 게이트 2는 `model_dump()`의 모든 문자열 값을 본다. 예외는 env ∩ `PLACEHOLDER_EXEMPTABLE`(템플릿은 빈 집합)뿐이다(:88-92 · 318-327 · 372).
  - 경로 셋은 settings.py.jinja:105-108에 있다. startup `_paths`가 AUTH_EXEMPT ⊆ TENANT_EXEMPT, ACCESS_ONLY ⊆ TENANT_EXEMPT를 강제한다(P/startup.py.jinja).
- **⑥** pydantic bool 파싱: env가 없으면 False, `""`이면 기동 거부, true · false · 1 · 0은 정상(〔P13〕).
- **⑦** Ninja
  - HTTP_ERROR_SLUGS는 {400, 403, 404}뿐이다. 그 밖의 HttpError는 다시 올려 500이 된다(P/api.py.jinja:25 · 35-40).
  - 1.7.0에서 튜플을 반환하면 DeprecationWarning이 난다. `Status`를 쓴다(〔T28〕).
  - Optional 응답 필드는 null로 실린다. `exclude_none`이 필요하다(〔T4〕).
- **⑧** Celery
  - beat 일정은 P/celery.py.jinja:43-46에 있다. autodiscover는 `identity_admin.tasks`만 import한다(:50).
  - 템플릿은 celery를 runtime 분기 안에서만 import한다(P/apps.py.jinja:32-35 — migrate 프로필은 `<pod_snake>.celery`를 import하지 않는다). 템플릿 소유 시험 둘이 migrate 프로필에서 `django.setup()` + `ROOT_URLCONF` import 뒤 `"celery" in sys.modules`가 거짓임을 고정한다(T/tests/test_auth_middleware.py.jinja:1055-1066 · T/tests/test_migrations.py.jinja:85-103 · 430-442 — 컨트롤러 확인 · 〔W22〕).
  - 브로커 전송 옵션은 `socket_timeout` 5 · `socket_connect_timeout` 2다(P/celery.py.jinja:32-36). 연결은 되고 응답이 없는 브로커에서는 `max_retries` 0이어도 첫 읽기에서 약 5 s가 걸리고(kombu 채널이 만들 때 `ping`을 부른다), `max_retries` 0이면 kombu `Connection.ensure`가 재접속 없이 올려 브로커 재기동 뒤 풀에 남은 죽은 연결에서 첫 enqueue가 실패할 수 있다(둘 다 소스 판독 — 실행으로 잰 적은 없다 · 검토 C-4 · 〔W25〕).
  - beat 스케줄 파일은 `/tmp/celerybeat-schedule`이고(P/celery.py.jinja:3) celery 컨테이너의 `/tmp`는 emptyDir다(T/deploy/base/deployment-celery.yaml.jinja:59 · 88 · 94 — pod 수명의 볼륨이다). pod가 바뀌면(롤아웃 · Reloader · 축출) 스케줄 파일이 새로 생겨 「마지막 실행」 기록이 없고, 그 교체가 실행 시각을 걸쳤으면 그날 실행을 건너뛴다. 같은 pod 안의 컨테이너 재시작은 파일이 남아 기동 직후 따라잡는다 — 새 항목만 `last_run_at`이 지금이 되고(celery 5.6.3 `beat.py`), 남아 있는 `last_run_at`이 지난 실행 시각보다 앞이면 crontab은 기동 즉시 due다(`schedules.py` · `beat_cron_starting_deadline` 기본 None — 소스 판독 · 검토 B-7 · 재검토 RB-7 · 〔W19 · Z11〕). 앞 라운드 문장은 컨테이너 재시작에도 기록이 없다고 적었다 — 고쳤다.
  - beat_init 신호는 Service 인스턴스를 sender로 보낸다. 수신자 예외는 로그만 남긴다(〔T8〕).
  - 실제 워커 시험(test_outbox.py.jinja:742-797)이 pod 사용자로 beat를 띄우고 NOPERM 0을 단언한다(〔P17〕).
  - 닫힌 포트 브로커에 send_task를 하면 약 4 s 걸린다(retry=False여도 4.03 s). `retry_policy`의 `max_retries`를 0으로 주면 2.01 s다(Windows 실측 — 〔T27 · L14〕).
  - solo 풀에는 작업 시간 제한이 없다. beat는 보내지 못한 tick을 다시 보내지 않고 다음 주기로 넘긴다. 워커의 브로커 재접속 간격은 2 s씩 늘어 최대 30 s다. 내장 beat 자식이 죽어도 워커는 살고 beat는 다시 뜨지 않는다(celery 5.6.3 · kombu 5.7.0 소스 판독 — 비판 B-3 · B extra).
  - 성공 줄은 작업의 반환값을 찍는다. 호출 인자의 표시는 `argsrepr`로 가릴 수 있다(celery 5.6.3 app/trace.py — 비판 B-8).
  - autoretry 의미(〔조사 E21〕)
    - backoff는 int로 쓴다.
    - backoff_max는 지연 1회의 상한이다.
    - jitter 기본값은 True다.
    - max_retries 3이면 시도는 4회다.
- **⑨** Dragonfly
  - 생성물 ACL은 `%R~revoked:*`다(T/compose/dragonfly-dev.acl.jinja:3 · T/tests/conftest.py.jinja:301-304). 계약의 identity-admin 규칙은 `~revoked:* ~identity-admin:* +@all`이다(dl:42).
  - v1.40.1 실측: EX ≤ 0이면 오류이고 기존 키는 보존된다. 파이프라인은 오류 명령만 실패한다. 채널은 기본 resetchannels다(〔조사 E23 · E25 · L15〕).
  - redis-py `from_url` 기본 타임아웃은 5 s다. 0.2 s를 명시하면 닫힌 포트에서 0.217 s에 끝난다(〔L10〕).
  - 조회는 값을 `int()`로 읽는다(〔L11〕).
- **⑩** django-common 공개 API로 충분하다.
  - GlobalModel(dc/tenancy.py:175-179) · 허용 목록(:131-133) · tenant_context(:213-238)
  - publish 검사 · Denylist(dc/auth.py:653-730) · verify_authentik_webhook · problem_response · sub_hash
  - 쓰기 API는 없다(auth.py:166-181 — 〔L9 · L20〕).
- **⑪** 시험의 시각 규율: nbf는 프로세스 시계로 잰다(api-11 · 25). 재적용 TTL과 purge 경계는 DB now()로 잰다(api-30 · 34 — 〔T30〕).
- **⑫** UUID v7
  - Python 3.13에는 uuid7이 없다(〔S32 · L1〕).
  - Django 6.1 `UUID7()`는 PG 18 이상의 `uuidv7()`다(.venv django/db/models/functions/uuid.py:47-77).
  - db_default 필드는 INSERT RETURNING으로 값이 돌아온다(fields/__init__.py:973-975).
  - 시험은 id의 UUID 판(version)을 단언하지 않는다.
- **⑬** HTTP 클라이언트 의존: 생성 pod의 런타임 직접 의존에 없다. requests는 OTLP exporter의 전이 의존이다(〔T29 · P28〕). 가짜 Authentik은 JSON Content-Type이 아니면 415다.
- **⑭** Authentik 2026.8.0 소스
  - 세션 목록(〔조사 E2–E4〕)
    - 필터는 `user__username`뿐이다.
    - sid와 세션 키는 응답에 없다.
    - view 권한이 없으면 오류 없이 빈 목록이다.
    - 단건 DELETE는 남의 세션에 404다.
    - bulk_delete는 8.0 · 8.1에서 500이 날 수 있다.
  - 비슈퍼유저는 남의 refresh 토큰을 지울 수 없다(〔조사 E7〕). 세션을 지워도 refresh는 산다(〔조사 E8〕).
  - 교환 토큰에는 sid가 없다(〔조사 E9〕).
  - 세션 삭제 이벤트는 없다. login 이벤트는 교환마다 생긴다(〔조사 E14〕).
  - 웹훅 서명 기능은 없다. 매핑 결과는 sanitize된다. 멱등 키는 `event.pk`여야 한다(Notification.uuid는 시도마다 다르다 — 〔조사 E11 · E12〕).
  - 재시도는 5회, 누적 465–930 s다(〔조사 E15〕).
  - 보안 권고 GHSA-h6c5 · GHSA-m9h4가 8.1까지에 해당하고 8.2에서 고쳐졌다(〔조사 E1〕). h6c5는 「사용자 · 그룹 관리를 위임받은 계정」의 권한 상승이라 시드 쓰기 권한을 가진 토큰에 해당하고, m9h4는 설정 객체(소스 · provider · outpost 등)의 view 권한 문제라 런타임 권한(사용자 · 세션 · 이벤트)과 무관하다(비판 B-5 · 〔Y7〕).
  - events API는 `actions=logout`으로 조회하고 view_event 권한이 필요하다(〔조사 E32〕). 2026.8.0에는 필터 `actions`(여러 값)와 `action`(부분 일치)이 둘 다 있고 기본 정렬은 `-created`다. 모르는 질의 키는 오류 없이 무시돼 전체 목록이 온다(〔조사 E5〕 · 비판 B-4).
  - 권한이 없을 때의 응답 꼴은 서비스 계정의 형에 달려 있다 — 전역 권한이 없고 걸러진 결과가 비면 거부(403)인데, internal service account에는 같은 필터가 빈 결과를 그대로 돌려준다(`rbac/filters.py` 소스 판독 — 요약으로 읽었고 라이브 실측은 0이다 · 검토 B-10). 그래서 이 설계는 권한 없음의 응답 꼴을 단정하지 않는다(D17 · VD-T081-2 · 〔W2〕).
  - logout 이벤트는 로그아웃 흐름 말고도 세션 결속이 깨질 때 생긴다(결속 기본값은 꺼짐 — 〔ATK-7〕).
- **⑮** OpenFGA v1.19.0 실측: 중복 쓰기는 400 `write_failed_due_to_invalid_input`이다. 일괄 쓰기는 원자적이다. `on_duplicate: "ignore"`는 멱등이다. 없는 store는 400(쓰기) · 200(읽기)이다(〔조사 E18 · E19〕).
- **⑯** PG 18.6 실측: `expires_at + 30d < now()`는 Seq Scan, `expires_at < now() − 30d`는 Index Scan이다. Django `Now()`는 STATEMENT_TIMESTAMP다(〔조사 E29〕).
- **⑰** 템플릿 deploy/base
  - ES data[0..7]가 정해져 있고 「새 항목은 8번부터」다(T/deploy/base/externalsecret-env.yaml.jinja:1-4 · 33-65). ConfigMap은 configmap.yaml.jinja:11-28이다.
  - `dev_shape_env`는 base ConfigMap의 자리값 이름을 정확히 {ACCESS_AUD_M2M, ACCESS_EXPECTED_CN}으로 단언한다(T/tests/_boot.py.jinja:401-422).
  - 하네스 렌더 검사는 sample-pod 고정이다. kubeconform은 ES를 건너뛴다(〔P24〕).
- **⑱** CI
  - job test는 pytest 두 줄 · 60분 · 예산 1800 s다(ci.yml:332-433 · tests/scripts/kubeconform-deploy.tests.ps1:506 static-15).
  - static-14는 세 job의 setup-uv가 같은지 본다(:488). static-16은 POD_PYTEST_ENV 이름을 ci.yml 전역에서 금지한다(:544).
  - 로컬 시간: 템플릿 165개 171–364 s, 시제품 269개 179 s(〔P27〕).
- **⑲** ninja 1.7.0 → 1.7.3: 소스 차이 5파일이고 보안 권고는 0건이다. 영향 경로는 응답 하위 클래스(#1823)뿐이다. 1.7.3에서도 165 passed이고 스냅샷이 같다(〔P30–P32 · 조사 E26〕).
- **⑳** OWNED_EVENTS가 publish_owned의 관문이다(P/events/__init__.py.jinja:19-32). gitops KafkaTopic은 `session.revoked` · dlq와 각각의 dev판뿐이다(〔S21 · L18〕).
- **㉑** 고정 테넌트 UUID 리터럴은 어디에도 없다(〔S28〕).
- **㉒** T066 독스트링 불일치(〔T22 · T23 · P34〕)
  - 가정 ⑥은 setdefault라고 적었다(test_api.py:55-60). 실제 래퍼는 덮어쓴다(T/tests/settings.py.jinja:80-82).
  - 「형식 검사 없음」이라고 적었지만 SECRET_KEY는 W009 기준으로 검사한다(P/conf.py.jinja:310-315).
  - `-p no:django`(test_api.py:107 · test_identity_fakes.py:10 · _identity_fakes.py:24)는 생성 pod에서 종료 4다.
  - 「커밋 후 SET EX 330」(test_api.py:14)은 보정된 TTL 식(D13)과 문면이 다르다. 단언(api-10 [325, 330] · api-20 [320, 330])은 그대로 통과한다.
- **㉓** AdminHostMiddleware는 ADMIN_HOST가 비지 않으면 모든 요청에서 `get_host()`를 부른다(P/middleware.py.jinja:64).
- **㉔** bff-api: logout은 `/sessions/revoke`를 부르고, Authentik refresh revoke는 BFF가 한다(:32). BFF 세션 쿠키에 `issued_at` · `sid`가 있다(:21). `/session/check`가 inactive면 BFF는 쿠키를 지운다(:48).
  - `issued_at`은 저장소 전체에서 bff:21 한 줄에만 나오고 뜻과 refresh 때의 변화가 정해져 있지 않다. `/session/check`의 `iat` 원천도 없다(〔R12〕).
  - 계약 표가 적은 폐기 확인 자리는 `/api/session`과 프록시 통과 경로뿐이다. refresh · callback · 교환 앞에는 없다(〔R13〕). 교환 토큰 캐시 키는 `sub+aud`라 세션을 가르지 않는다(〔R14〕).
  - 쿠키 Max-Age 30일이 callback · refresh마다 다시 실린다. 절대 수명 규정이 없다(bff:21 · 22 · 33).
- **㉕** Authentik refresh 토큰(2026.8.0 · 2026.8.5 소스 판독 — 라이브 실측 0)
  - 회전 때마다 새 만료가 now + 30 d다. 절대 수명 · 최대 세션 길이가 없어 30일 안에 한 번씩만 쓰면 무기한 이어진다(〔V11〕).
  - refresh grant는 토큰 행 · 만료 · revoked · DPoP만 본다. 세션 유무 · 사용자 활성 여부 · 정책은 보지 않는다(〔V5〕).
  - 세션 결속 설정도 사용자별 not-before도 없다(〔V7 · V9〕). 비슈퍼유저가 남의 refresh 토큰을 지울 길은 최신 패치판에도 없다(〔V6〕).
  - OSS에서 Authentik이 스스로 주는 최종 폐기는 사용자 비활성화(`change_user`) 하나다 — 세션과 Access · Refresh · Device 토큰을 모두 지운다(〔V8〕).
  - 옛 토큰을 다시 내면 의심 이벤트 + `invalid_grant`뿐이고 계열 폐기는 없다(〔V11〕).
  - refresh 토큰은 scope에 `offline_access`가 있을 때만 나온다(〔ATK-11〕).
- **㉖** 토큰의 시각 클레임(소스 판독)
  - ID 토큰 `iat`는 발급 때마다 지금 시각이다. callback의 코드 교환 응답에서는 코드 교환 시각(Authentik 시계)이다(〔V2 · V3〕).
  - `auth_time`은 Authentik 로그인 세션의 인증 시각이다. Authentik 세션이 살아 있으면 다시 로그인해도 같은 값이 나온다. refresh 뒤에도 그대로다(〔V2 · V3〕).
  - 교환 토큰은 `auth_time` = `iat` = 교환 시각이고 `sid` · refresh 토큰이 없다. pod 경계에는 세션 정체가 없다(〔V4〕).
- **㉗** T066이 `/session/check`와 키에 대해 고정한 것(원문 대조 — 실행은 구현 때)
  - api-4–9 · 44의 `iat`는 전부 `int(time.time())`이다(test_api.py:1213 · 1224 · 1242 · 1255 · 1272 · 1287 · 2123). api-4–9는 DB 마크가 없어 뷰가 DB에 닿으면 실패한다(〔R1〕 — api-44는 `@DB`가 있다 · test_api.py:2116).
  - 응답은 dict 완전 일치다. 늘 실리는 새 필드는 깨지고, 새 키를 한 번 더 읽는 것은 통과한다. 명령 수 · 연결 수 단언은 test_api.py에 없다(〔R2〕).
  - 키 단언은 `revoked:*` 접두 훑기와 `denylist:epoch` 부재뿐이다(test_api.py:623-625 · 1782). 시험 사용자 ACL은 `~revoked:* ~identity-admin:* +@all`이다(:236 — 〔R3 · R16〕).
  - api-34가 로그 보존 경계를 30 d ± 1 h로 고정한다(:1855-1865 — 〔R5〕).
- **㉘** spec:309가 `SessionRevocationLog`를 「폐기의 DB 정본(기동 · 30 s beat 재적용의 원천)」으로 적는다. 로그에서 파생한 키는 승인 문면의 틀 안이다(〔R18〕). B 등급 표를 더하면 허용 목록 상수 · tc-17 · 규칙 2 · 계약 2 · ADR 0007 · 승인 문면 5곳이 따라 바뀐다(〔R7〕).
- **㉙** stdlib HTTP: `http.client`는 제어 문자가 든 경로를 `InvalidURL`로 거부하면서 경로 + 쿼리를 문구에 싣는다. `build_opener`는 file · ftp · data 핸들러를 기본으로 단다(비판 B-8).

---

## 3. 결정 D1–D30

D1–D28은 초안의 결정에 비판 · 분석 반영을 얹은 것이고, D29(세션 하한 · 절대 수명) · D30(관리 명령 `revoke_sessions`)은 반영으로 새로 생겼다.

### D1 범위와 파일 배치

- **무엇**
  - **고치는 곳**
    - 루트 `pyproject.toml` · `uv.lock`
    - `IA/**`: 생성 + 템플릿 소유 15파일의 손 수정(D3) + 새 파일
    - T066 세 파일: 독스트링 · 주석만
    - 템플릿 문서 둘: `T/README.md.jinja`(「재생성」 절 · 뷰 응답 규칙 문단)와 `H/copier.yml` 머리 주석
    - `.github/workflows/ci.yml`
    - `tests/scripts/kubeconform-deploy.tests.ps1`
    - §4 계약 · 규칙 보정
  - **새 pod 소유 파일**(템플릿에 없는 이름 — 템플릿이 뒤에 같은 경로를 만들면 재생성 때 덮이므로 목록을 생성 README 「재생성」 절에 싣는다 · 〔Y13〕)
    - `IA/identity_admin/` 아래
      - `models.py` · `migrations/{__init__,0001_initial}.py`
      - `identity_api.py`(엔드포인트 4) · `revocation.py`(기록 공통 관문) · `denylist_writer.py`(거부 목록 · 하한 쓰기 · 재적용 · purge) · `session_floor.py`(하한 키 · 보존 상수 · 판정 — D29)
      - `outbound.py` · `authentik.py` · `openfga.py`
      - `identity_metrics.py` · `jobs.py`
      - `management/commands/seed_tenant.py` · `management/commands/revoke_sessions.py`(D30)
    - `IA/tests/` 아래
      - `test_identity_contract.py`(엔드포인트 · 기록 · 요청 경로의 하한) · `test_identity_jobs.py`(재적용 · beat · 위임 · 대조) · `test_identity_commands.py`(seed · `revoke_sessions`) · `test_identity_infra.py`(설정 · ACL · 배포 정적 · 외부 호출 위생)
      - `_ia_support.py` · `_ia_fakes.py` · `test_ia_fakes.py`
      - 파일 이름은 설계자가 정했다. 초안의 `test_identity_seed.py`는 명령이 둘이 돼 `test_identity_commands.py`로 바꿨고, DB · 가짜 서버가 필요 없는 정적 시험을 `test_identity_infra.py`로 모았다(T066 가정 ⑧의 금지 이름 셋과 겹치지 않는다).
  - **고치지 않는 곳**: dc · 템플릿 코드 · 템플릿 시험 · 하네스 · gitops(T075) · packages/events · `apps/web`(BFF 쪽은 계약 보정만 — 구현은 T089 · T092)
- **왜**
  - dc를 고치면 T068–T071 계약 시험을 다시 열어야 한다(〔L20〕).
  - 템플릿 코드를 고치면 T065 가정이 바뀌고 하네스 918개를 다시 초록으로 만들어야 한다.
  - 런타임 코드는 `identity_admin/` 패키지 안에 있어야 이미지 허용 목록에 든다(〔P22〕).
- **기각**
  - 거부 목록 쓰기를 dc 공개 API로 올리기: 소비자가 하나뿐이고 T070 계약 개정이 따른다.
  - 하위 앱 신설: INSTALLED_APPS와 린터 `include_apps` 손 수정이 늘어난다(T/tests/test_migrations.py.jinja:389-401).

### D2 생성 · 루트 워크스페이스

- **무엇**: 아래 순서를 고정하고 모두 「생성 커밋」에 넣는다.
  1. 루트 `pyproject.toml`
     - `members = ["packages/django-common"]`
     - `exclude = ["apps/*", "templates/*"]` + 독립 uv 프로젝트라는 주석(pt:25 · 규칙:19)
  2. 루트 `uv lock`(uv 0.13.7)
     - 기대 diff: identity-admin 2곳 + revision 3→5(〔P4〕)
     - 확인: `uv lock --check` · `uv sync --locked`
  3. 저장소 루트를 cwd로 두고 생성한다.
     ```
     uv run --project templates/django-pod --locked python -m copier copy --trust --defaults --overwrite --data pod_name=identity-admin --data 'owns_events=[session.revoked]' --data 'description=Session revocation, tenant membership and Authentik webhook intake' templates/django-pod apps/identity-admin
     ```
     - `--directory`를 쓰면 cwd가 바뀌어 상대 인자가 틀어진다(H/tests/_layout.py:56-62).
     - 상대 경로라야 `.copier-answers.yml`의 `_src_path`에 로컬 절대 경로가 남지 않는다(〔P8 · T26〕).
     - `description` 답은 한 줄로 준다(〔Y12〕 · pt:15): `Session revocation, tenant membership and Authentik webhook intake`. 문구는 설계자가 정했다 — 한 줄 · 120자 이하(H/copier.yml:113-116의 validator)이고 ASCII라 셸 인자와 `tojson` 렌더(pyproject `description` · `api.py`의 `TITLE`)에 이스케이프가 생기지 않는다. 값에 공백이 있어 `owns_events`처럼 작은따옴표로 감싼다(하네스도 공백 든 값을 넣어 생성한다 — H/tests/test_generate.py:482). README 머리 둘째 문단과 OpenAPI title이 이 값이 되고, 스냅샷은 title을 빼고 비교하며 title 시험의 기대값은 렌더가 함께 바꾼다(〔P36〕). 답은 `.copier-answers.yml`에 남아 `recopy --defaults`가 다시 쓴다.
  4. 사후 확인
     - `git status` = `M IA/pyproject.toml` + 새 파일들
     - T066 세 파일은 `git diff --quiet`
     - answers의 `_src_path: templates/django-pod` · `description`이 위 문구 · `owns_events`가 `session.revoked` 하나
     - pod에서 `uv lock --check` · `uv sync --locked`, `exclude-newer-span = "P3D"`(T072 UD-2)
  5. 실패하면 대상이 남는다(〔P7〕). 아래 되돌리기는 **조각 ⓪에서만** 쓴다 — 뒤 조각은 작업 트리에 미커밋 구현이 쌓여 있어 같은 명령이 그것까지 없앤다(〔W35〕).
     - `git restore IA/pyproject.toml`
     - `git clean -nd -- apps/identity-admin`으로 목록을 확인하고 그 목록만 지운다(`-d`가 없으면 새 디렉터리가 목록에 나오지 않는다 — 〔Y11〕). T066 파일은 추적 파일이라 목록에 들지 않는다.
     - 원인(PyPI · 숙성 창)을 없앤 뒤 3단계를 다시 돈다.
- **왜**
  - 멤버로 남기면 uv lock이 실패한다(G5).
  - 루트 잠금이 같은 커밋에 없으면 CI 첫 스텝이 깨진다(②).
- **기각**
  - exclude 생략: 동작은 같지만 규칙:19 문장이 거짓으로 남는다.
  - 절대 템플릿 경로.
- **계약**: C16 · C20.
- **시험**: 순정 생성물에서 템플릿 시험 165 passed(〔P2〕). T066은 13/63이고, 실패 사유를 ①의 8묶음과 노드별로 대조한다. VD-T073-1 · 2.

### D3 손 수정 경계 · 재생성 · 템플릿 문서

- **원칙**
  - identity-admin 고유 로직은 새 파일(D1)에 둔다.
  - 템플릿 소유 파일에서는 세 가지만 한다: 확장 지점에 이름 더하기, 한 줄 연결, 기대값을 pod 계약으로 바꾸기(템플릿 기본값을 적은 단언에 한한다 — 불변식 단언의 기대값은 건드리지 않는다 · 아래 「두 갈래」 · 〔W22〕).
  - 손댄 줄이나 블록에는 `# identity-admin(T073)` 표식을 단다.
  - **표식 예외**: 주석을 둘 수 없는 파일 둘은 표식 없이 고치고 README 손 수정 표가 정본이다 — ⑨ `openapi.json`(JSON) · ⑪ `dragonfly-dev.acl`(USER 줄만 둔다 — 주석 줄을 Dragonfly가 받는지 실측한 적이 없다). 〔Y8〕
- **손 수정 목록(템플릿 소유 15파일)**: 생성 README 「재생성」 절에 그대로 싣는다(파일 · 고친 자리 · 지키는 시험).
  - ① `conf.py`(D6 — `RuntimeEnv` 필드 7 · 목록 셋 · 교차 규칙 둘)
  - ② `settings.py`(D6 · D7)
  - ③ `api.py`의 `api.add_router("", identity_router)` 한 줄(D8)
  - ④ `celery.py` beat 3항목(D15) + 머리 독스트링의 ACL 규칙 문자열(D24 뒤 낡는다 — T/…celery.py.jinja:7 · 〔Y8〕)
  - ⑤ `tasks.py` import 한 줄(D15)
  - ⑥ `tests/settings.py`(D6)
  - ⑦ `tests/test_auth_middleware.py` 상수 둘(D26)
  - ⑧ `tests/test_outbox.py` beat 단언(D26) + 독스트링의 ACL 규칙 문자열(T/tests/test_outbox.py.jinja:27 · 〔Y8〕)
  - ⑨ `tests/snapshots/openapi.json`(D26)
  - ⑩ `tests/conftest.py`: `DRAGONFLY_USERS[POD_NAME]` 규칙과 독스트링(D24) + `pytest_plugins` 한 줄 + `register_assert_rewrite`에 T073 도우미 둘(D26 · 〔Y8 · Y14〕)
  - ⑪ `compose/dragonfly-dev.acl`(D24)
  - ⑫ `env.example`
  - ⑬ `deploy/base/externalsecret-env.yaml`
  - ⑭ `deploy/base/configmap.yaml`
  - ⑮ `README.md`
  - ⑫–⑮는 D23 몫이다.
  - **지키는 시험**: ①–⑧ · ⑩은 생성물 기본 시험과 T066 · ia 시험이 직접 지킨다(되돌리면 깨진다). ⑨는 스냅샷 시험, ⑩ · ⑪은 ia-24, ⑫ · ⑬ · ⑭는 ia-18이 지킨다. ⑮(README)와 ④ · ⑧의 독스트링 문자열은 시험 밖이다 — 리뷰가 본다. 〔Y8〕
  - 최소 시제품에서는 템플릿 기본 시험이 정확히 2개 깨졌다(사실 ④). 모델 · 면제 상수 · ACL · ConfigMap 키 · 실제 작업 본체는 시제품 밖이라, 조각 ② · ⑤-a · ⑥의 끝에서 깨진 템플릿 소유 시험을 다시 센다. 더 깨졌을 때의 처리는 아래 두 갈래다(규칙:69 · 비판 A extra · 〔W22〕).
- **깨진 템플릿 소유 시험의 처리 — 두 갈래**(〔W22〕 · 이름은 템플릿 시험 원문 `T/tests/`에서 확인했다 — 생성물에서는 `tests/<파일>.py`)
  - **(가) 템플릿 기본값을 적은 단언** — 삭제 · skip 없이 **기대값을 pod 계약으로 바꾸고** 위 손 수정 목록과 README 표를 갱신한다. 대상은 넷뿐이다.
    - 필수 · 비밀 설정 상수: `test_auth_middleware.py`의 `REQUIRED_SETTINGS` · `SECRET_SETTINGS`(`test_required_settings_match_contract`가 `conf.RuntimeEnv` · `conf.SECRET_SETTINGS`와 견준다 — 손 수정 ⑦)
    - beat 항목 목록: `test_outbox.py::test_celery_app_configuration`의 `list(conf.beat_schedule) == ["purge-dead-outbox"]`(손 수정 ⑧)
    - OpenAPI 스냅샷: `tests/snapshots/openapi.json`(`test_openapi_snapshot.py::test_openapi_schema_matches_snapshot` — 손 수정 ⑨)
    - ACL 규칙 문자열: `conftest.py`의 `DRAGONFLY_USERS[POD_NAME]`과 그 값을 옮겨 적은 독스트링(손 수정 ④ · ⑧ · ⑩)
  - **(나) 불변식 단언** — 기대값을 건드리지 않고 **코드를 고친다**.
    - migrate 프로필의 celery 미import · 런타임 설정 0: `test_auth_middleware.py::test_boot_migrate_profile_needs_only_owner_url`(`celery_imported is False` · `runtime_settings == []`)과 `test_migrations.py::test_migrate_profile_boots_without_runtime_settings`(같은 둘). Celery 앱을 모듈 머리에서 가져오면 여기서 깨진다(D16).
    - 기동 중 이름 조회 0 · 기동 위생: `tests/_boot.py`의 `assert_boot_hygiene`을 지나는 기동 시험 전부(`test_auth_middleware.py`의 `test_boot_*` — 공개 이름 조회 0 · 출력에 심은 비밀과 그 12자 조각 0 · `input_value=` 0. `network_zero`로 도는 migrate 프로필 · dev 모양 · prod 모양 기동은 이름 조회 자체가 0이다)와 `test_logging.py::test_wsgi_entry_boots_with_otel_and_no_public_lookups`(공개 이름 조회 0 · stdout은 줄마다 JSON 객체 · stderr 0)
    - app role 권한의 정확 일치: `test_tenant_rls.py::test_app_role_has_exactly_dml_on_every_table` · `test_app_role_uses_every_sequence`
    - relay 레지스트리에 web 지표 없음: `test_outbox.py::test_relay_process_registry_has_outbox_metrics_only`
  - 두 목록에 없는 템플릿 소유 시험이 깨지면 빌더는 고치지 않고 컨트롤러에 보고한다.
- **재생성**(SP-1은 copier update 미지원 — pt:7)
  - **정본 = 실측된 `recopy` + diff**(〔P9〕): 저장소 루트에서 `uv run --project templates/django-pod --locked python -m copier recopy --trust --defaults --overwrite apps/identity-admin`을 돌린다. 기록된 답을 다시 쓰고, 손으로 고친 템플릿 소유 파일은 템플릿 꼴로 되돌아가며, 템플릿에 없는 pod 소유 파일은 남는다. 그 뒤 `git diff`를 보고 손 수정 목록의 표식 블록을 되살리고 생성물 시험 전체를 돌린다. 계약 · 규칙 · README에는 이 절차만 적는다. 〔Y6〕
  - **3-way는 후보다**: 「생성 커밋에서 갈라 템플릿만 새 판으로 두고 같은 `recopy` → 커밋 → 손 수정이 든 쪽에 cherry-pick(git의 3-way 병합)」은 손 수정 15파일이 다 생긴 **조각 ⑥ 끝 뒤의 컨트롤러 단계**에서 한 번 실측한다(VD-T073-11 — 저장소 밖 임시 복제본에서 돈다 · 절차는 §5 「⑥ 끝 뒤 — 컨트롤러 단계」). 조각 ⓪에서는 잴 수 없다 — 생성 커밋도 손 수정도 아직 없어 cherry-pick이 충돌 없이 얹히고 통과 기준이 공허하게 참이 된다(검토 C-2 · 〔W23〕). 실측이 통과한 뒤에만 bn 「T073」 절과 생성 README에 정본으로 올린다. 초안의 `git diff --no-index` + `git apply -3` 꼴은 쓰지 않는다 — 임시 디렉터리의 배치 · answers 원천 · `--skip-tasks`일 때의 uv.lock · 경로 접두가 정해지지 않았다(A-6 · 〔Y6〕).
- **템플릿 문서 정정**(코드 · 시험 무변경 — 조각 ⓪ 커밋 · C34 · C35)
  - `T/README.md.jinja:286-298` 「재생성」 절의 세 문장
    - 맨 `copier copy …` → 하네스 잠금의 copier로 도는 `recopy`(위 명령)
    - 「답도 `--data`로」 → `--defaults`가 기록된 답을 다시 쓴다.
    - 「uv lock이 실패하면 대상을 지운다」 → copier는 자기가 새로 만든 대상만 지운다. 이미 있던 디렉터리는 반쯤 생성된 채 남는다.
  - `T/README.md.jinja`에 뷰 응답 규칙 한 문단(D28 · 〔Y9〕)
  - `H/copier.yml` 머리 주석의 같은 문장(〔P7 · P39〕)
  - 규칙:24에 따라 하네스 전체를 1회 돈다(918개 · 로컬 약 6–7분 — bn:4484). 하네스는 README 내용을 단언하지 않는다(파일 존재와 명령 상수 주석뿐 — 비판 A extra).
- **왜 일반화하지 않는가**: 템플릿 일반화(필수 집합 · beat 단언을 ⊇로 바꾸거나 conf에 pod 확장 상수를 두는 것)는 세 가지 비용이 있다.
  - 템플릿 자기 단언이 약해진다. 「기본 beat = purge 하나」가 회귀를 못 잡게 된다.
  - 하네스 변이 표 · T065 가정 · pt §기본 테스트 6을 고쳐야 한다.
  - 일반화는 확장하는 두 번째 pod(SP-2)가 생길 때 정한다.
- **기각**
  - copier 질문 신설(D24)
  - 런타임에 beat 일정을 주입하기: 시험 순서에 따라 결과가 흔들린다(추론).
- **계약**: C20 · C30(설계 커밋) · C34 · C35(조각 ⓪ 커밋) 〔편차 14 · 15〕.
- **시험**: 하네스 전체 초록. 손 수정마다 지키는 시험은 위 목록 끝 줄이다.

### D4 모델 3종

- **무엇**: `identity_admin/models.py`에 둔다. pod 앱 `identity_admin`은 이미 INSTALLED_APPS(P/settings.py.jinja:40)와 린터 대상(T/tests/settings.py.jinja:89)이다. 셋 다 `GlobalModel` 하위이고 `class Meta(GlobalModel.Meta): db_table = …`로 허용 이름을 쓴다.

| db_table | 필드 | 제약 · 인덱스 |
|---|---|---|
| `tenant` | `id` UUIDField pk `db_default=UUID7()` editable=False · `slug` CharField(32) · `display_name` CharField(80) · `status` CharField(16, active/suspended, default active) · `created_at` · `updated_at` DateTimeField `db_default=Now()` | `tenant_slug_uniq` · check `tenant_slug_format`(`^[a-z0-9][a-z0-9-]{1,30}$`) · `tenant_display_name_nonempty` · `tenant_status_valid` |
| `tenant_membership` | `id`(같은 꼴) · `tenant_id` UUIDField(값 참조 · FK 아님) · `sub` TextField · `role` CharField(16, owner/member) · `created_at` | `tenant_membership_sub_tenant_uniq`(sub, tenant_id) · `tenant_membership_role_valid` |
| `session_revocation_log` | `id` · `tenant_id` · `sub` TextField · `sid` TextField(null) · `reason` CharField(32, 5값) · `nbf` · `expires_at` DateTimeField · `event_pk` TextField(null — 저장 꼴은 D12의 정규형) · `created_at` | UniqueConstraint `srl_event_pk_uniq`(경합 판정에 이름을 쓴다 — D12) · `srl_reason_valid` · 인덱스 `srl_expires_at_idx`(`expires_at` — 재적용 · purge) · 부분 인덱스 `srl_user_floor_idx` = `(sub, nbf DESC) WHERE sid IS NULL`(세션 하한의 sub별 최댓값 — D29 · 〔E1〕) |

- 업무 필드만으로 `objects.create()`를 해도 pk가 RETURNING으로 채워진다(T066 가정 ③ — test_api.py:79-81).
- `updated_at`은 db_default만 둔다. 갱신 경로는 SP-2에 생기고, 그 경로가 `Now()`를 함께 쓴다. SP-1에는 Tenant를 갱신하는 경로가 없다(D19).
- admin 등록은 0이다(D28).
- **왜**
  - DB 함수를 쓰면 시계 · 난수 생성 코드가 0이다. 시험 DB와 운영 DB가 둘 다 PG 18.6이다(〔조사 E30〕).
  - pod 앱에 두면 템플릿 파일 수정이 0이다. `migrate core zero` 시험(test_migrations.py.jinja:404-427)과도 엮이지 않는다(〔P16 · T25〕).
- **기각**
  - core 앱
  - 새 하위 앱
  - uuid4 + report 편차: dm:13 · 33 · 50과 어긋난다.
  - 앱 쪽 uuid7 구현
  - 뒤의 둘은 `UUID7()` db_default가 될 때의 기각이다. VD-T073-3이 실패하면 이 순서로 되살린다(앱 쪽 생성기 → 그것도 안 되면 uuid4 + 편차 — 컨트롤러 결정 · 〔Y15〕).
- **계약**: C23 · C24(인덱스 · 제약 줄).
- **시험**
  - T066: api-10 · 15 · 27–41(db_table로 정확히 하나 — test_api.py:348-352)
  - makemigrations --check · lintmigrations
  - ia-20(B 등급 3표의 RLS 꺼짐 · `check_rls` 성공 줄의 B 등급 수 ≥ 4 · 로그 표의 제약 · 인덱스 이름 넷 — `srl_event_pk_uniq` · `srl_reason_valid` · `srl_expires_at_idx` · `srl_user_floor_idx` — 이 카탈로그에 있다)
- **변이**: db_default 삭제 → api-10. event_pk unique 삭제 → ia-7(api-21은 D10 5단계의 사전 확인이 200을 내 그대로 통과한다 — 〔Y10〕). `srl_user_floor_idx` 삭제 → ia-20.

### D5 마이그레이션 · GRANT

- **무엇**
  - `0001_initial.py`는 makemigrations 산출 그대로 쓴다. 손 SQL 0, rls_policies 0이다.
  - dependencies는 비운다. core 0001과 엮지 않아야 core zero 시험이 identity-admin 표를 지우지 않는다.
  - app role 권한은 core/0001의 ALL TABLES + DEFAULT PRIVILEGES가 적용 순서와 무관하게 준다(VD-T072-14 · 〔조사 E27〕). REVOKE는 하지 않는다.
- **왜 REVOKE를 안 하는가**
  - 시드가 app role로 tenant · membership을 쓴다(D19).
  - 로그 표는 INSERT · SELECT · DELETE가 다 필요하다.
  - UPDATE만 빼면 템플릿 시험이 깨진다 — T/tests/test_tenant_rls.py.jinja:316-324가 public 표 전부의 app role 권한을 정확히 SELECT · INSERT · UPDATE · DELETE로 단언한다(비판 A extra).
- **기각**: `REVOKE UPDATE` · owner 전용 시드.
- **계약**: 〔편차 3〕.
- **시험**: lintmigrations 「Erroneous 0」 · 템플릿 check_rls · ia-20.
- **변이**: `rls_policies("tenant")`를 넣으면 check_rls가 위반을 낸다.

### D6 설정 · 래퍼 · 자리값 면제

- **`RuntimeEnv` 필드 7**(api계약:93-100)
  - `AUTHENTIK_API_URL: NonEmpty = "http://authentik-server.identity.svc:9000"`
  - `AUTHENTIK_API_TOKEN: NonEmptySecret`
  - `AUTHENTIK_WEBHOOK_SECRET: NonEmptySecret`
  - `AUTHENTIK_WRITES_ENABLED: bool = False`
  - `OPENFGA_API_URL: NonEmpty = "http://openfga.identity.svc:8080"`
  - `OPENFGA_STORE_ID: NonEmpty`(꼴은 conf 교차 규칙으로 올리지 않는다 — 경로에 넣는 호출 시점에만 본다 · D20 · 〔W5〕)
  - `OPENFGA_PRESHARED_KEY: NonEmptySecret`
  - `AUTHENTIK_JWKS_URL`은 템플릿 필드 그대로다.
- **목록**
  - `SECRET_SETTINGS` + 비밀 3
  - `IN_CLUSTER_URL_SETTINGS` + API URL 2
  - `PLACEHOLDER_EXEMPTABLE = frozenset({"AUTHENTIK_API_TOKEN", "OPENFGA_STORE_ID", "OPENFGA_PRESHARED_KEY"})`
    - 나가는 쪽 자격의 닫힌 상한이다.
    - 웹훅 비밀 · JWKS URL · ISSUER는 넣지 않는다(dm:164-165 · 〔S20 · P14〕).
    - 면제 env는 overlay(T075)가 두고, 처리는 D18이다.
- **교차 규칙 둘**(`_runtime_problems`에 더한다 — 어기면 이름만 실은 기동 실패)
  - `AUTHENTIK_WEBHOOK_SECRET`은 32자 이상이어야 한다. 웹훅은 HMAC 하나로 지키는데 템플릿의 비밀 검사는 「비지 않음」뿐이다(P/conf.py.jinja:349 · B-9 · 〔Y21〕). T066 기동 시험의 새 난수(64자)와 래퍼 값이 모두 넘는다.
  - `AUTHENTIK_API_URL` · `OPENFGA_API_URL`은 스킴이 http · https이고 사용자 정보 · 쿼리 · 조각이 없으며 경로가 빈 값이나 `/`여야 한다. 템플릿의 일반 검사는 스킴과 호스트만 본다(P/conf.py.jinja:298-302 · 376-399 · B-8 · 〔Y20〕). 기본값 둘과 api-49의 다섯 값은 판정이 그대로다.
- **settings.py**: runtime 블록에 대문자 7개를 노출한다. 코드는 호출 시점에 읽는다(규칙:57).
- **래퍼 `tests/settings.py`**
  - `_required_values`에 넷을 더한다: 비밀 셋은 `secrets.token_urlsafe(32)`(43자 — 32자 규칙을 넘는다), `OPENFGA_STORE_ID = "test-openfga-store"`.
  - 자리값에 숫자를 넣지 않는다(gitleaks X33 — t072:1110).
  - `POD_SETTINGS_ENV_REMOVED`에 `AUTHENTIK_API_URL` · `OPENFGA_API_URL` · `AUTHENTIK_WRITES_ENABLED`를 더한다. 개발자 셸 값이 api-48을 흔들지 못하게 한다(〔T20〕).
- **값 꼴**: ConfigMap의 `AUTHENTIK_WRITES_ENABLED`는 늘 명시 문자열이다. base는 `"false"`다(D23 · 〔P13〕).
- **기각**
  - URL 둘을 base ConfigMap에 둔다: 기본값과 중복된다.
  - 면제 상수에서 preshared를 뺀다: US6 동안 platform 값이 아직 없을 수 있다(dm:157 · 174).
- **계약**: C8.
- **시험**
  - T066 기동 17개: api-46–49 · 54 · 55
  - 템플릿 매개화가 자동으로 는다: REQUIRED +4 · empty-secret +3 · in-cluster +2(test_auth_middleware.py.jinja:678 · 684 · 960)
  - **ia-23**(기동 하위 프로세스 — 템플릿 `tests._boot`의 `boot` · `assert_refused` · `boot_facts`를 다시 쓴다 · 〔Y5〕). 템플릿 시험은 빈 상수의 음성 두 갈래만 지나서, 면제 상수의 양성 분기를 지나는 시험이 달리 없다(A-5).
    - ① 세 이름에 자리값(`PLACEHOLDER-` 포함 값) + `JT_PLACEHOLDER_EXEMPT` = 세 이름 → 종료 0
    - ② 면제 env 없이 같은 자리값 → 기동 거부, 거부 이름 = 그 셋
    - ③ `AUTHENTIK_WEBHOOK_SECRET` · `AUTHENTIK_JWKS_URL` · `AUTHENTIK_ISSUER`에 자리값 + 그 이름으로 면제 요청 → 거부(그 이름 + `JT_PLACEHOLDER_EXEMPT`)
    - ④ `conf.PLACEHOLDER_EXEMPTABLE` == 세 이름(정확 일치)
    - ⑤ 웹훅 비밀 31자 → 거부(`AUTHENTIK_WEBHOOK_SECRET`) · 32자 → 종료 0
    - ⑥ API URL에 사용자 정보 · 쿼리 · 조각 · 경로(`/api`)가 든 값 → 각각 거부
- **변이**: IN_CLUSTER에서 OPENFGA_API_URL을 빼면 api-49 openfga-public이 잡는다. 웹훅 비밀을 면제 상수에 더하면 ia-23 ③ · ④가 잡는다. 길이 규칙을 지우면 ia-23 ⑤가 잡는다.

### D7 경로 집합

- **값**(api계약:27 · T066 가정 ②)
  - `AUTH_EXEMPT_PATHS = ("/healthz", "/ready", "/health", "/webhooks/authentik")`
  - `AUTH_ACCESS_ONLY_PATHS = ("/session/check",)`
  - `TENANT_CONTEXT_EXEMPT_PATHS` = 헬스 3 + 웹훅 + `/session/check`
- startup `_paths`가 ⊆를 강제한다.
- **시험**: api-4–9 · 20–26 · 44 · ia-3.
- **변이**: 웹훅을 면제 목록에서 빼면 api-23이 403이 된다.

### D8 GET /session/check

- **`iat`의 뜻**: BFF 세션 시작 시각(쿠키 `issued_at` — D29 · C43)이다. refresh마다 바뀌는 토큰 `iat`가 아니다. pod는 값의 원천을 확인할 수 없다 — BFF 계약(C45)과 T089가 고정한다. 〔E4〕
- **처리**(`identity_api.py` — 순서 고정 · 〔E2〕)
  1. `Query[CheckQuery]`: `sub` · `iat: int` · `sid: str | None`. `sub` · `sid`는 출력 가능 ASCII(`!`–`~`) 1–255자다(스키마 제약 `min_length` 1 · `max_length` 255 · `pattern` `^[!-~]+$` — OpenAPI에 드러난다). 어기면 400 `validation_error`다. `sid=` · `sub=`도 400이다. 〔Y21〕
  2. 모듈 수준 `_DENYLIST = Denylist()` 하나로 `lookup`한다. 생성은 연결하지 않는다.
     - `DenylistUnavailable`은 `exc.to_response()`로 503을 낸다. 이때 3단계(하한 조회)를 시도하지 않는다 — api-8의 0.5 s 상한을 지킨다.
     - `HttpError(503)`은 표 밖이라 500이 되므로 쓰지 않는다(⑦).
  3. 세션 하한 조회: `session_floor.read_floor(sub)` — 쓰기 클라이언트(D13 — 0.2 s · 재시도 0)로 `GET identity-admin:session-floor:{sub}` 1회. 클라이언트는 호출할 때마다 `denylist_writer.client()`로 얻는다(모듈 속성 호출 — ia-30 (b)가 덮는 이음매다). `denylist_writer`가 상수 때문에 `session_floor`를 import하므로, `session_floor`는 `denylist_writer`를 모듈 머리가 아니라 `read_floor` 안에서 가져온다(순환 import를 만들지 않는다). 조회가 실패하거나 값이 정수가 아니면 `read_floor`가 WARNING `session_floor.lookup_failed error=<클래스>`를 남기고 `DenylistUnavailable`(dc/auth)을 올린다 — 실패를 값으로 돌려주지 않는다(〔W29〕). 뷰는 그것을 2단계와 같은 꼴의 503 `denylist_unavailable`로 바꾼다(fail-closed — dl:24의 「정수가 아니면 조회 실패」와 같은 규칙). DB로 메우지 않는다. 뷰는 `session_floor.read_floor`를 모듈 속성으로 부른다(ia-30 (a)가 가로채 센다 — D26 「이음매」).
  4. 판정(`session_floor.is_active(record=, floor=, iat=, now=)` — `now` = `int(time.time())` · pod 시계). 아래 넷이 모두 아닐 때만 active다.
     - ① `record.revokes(iat)`(T066 고정 — `revoked:sub` 값 > `iat` 또는 `revoked:sid` 존재)
     - ② 하한이 있고 하한 > `iat`(같으면 active — 미들웨어 4단계와 같은 「초과일 때만 폐기」)
     - ③ `now − iat > 2,592,000`(세션 절대 수명 30 d — D29의 상수) 〔E2〕
     - ④ `iat > now + 60`(미래 값). 하한 비교가 `iat`에 기대므로 미래 값은 하한을 조용히 무력화한다 — 열림을 닫힘으로 바꾼다. WARNING `session_check.iat_in_future`를 남긴다(값 · `sub` 없음). 〔E3〕 닿는 길은 둘뿐이다 — Authentik 시계가 pod보다 60 s 넘게 앞섬 · BFF 결함(ms epoch · `exp` 같은 값을 보냄). pod 시계가 뒤처진 경우는 이 경로의 Access JWT `iat` 검사가 먼저 403을 내 BFF가 503으로 접고 쿠키를 지킨다(추론 — Access가 서비스 토큰 요청마다 `iat`를 새로 찍는다는 전제 · 실측 T085 · 〔Z17〕 — D29 「경계 동작」 · 〔W15〕).
  5. 응답 dict `{"active": <판정>}`. `record.sub_nbf`가 있으면 `nbf`를 싣는다(active여도 · 판정 원인과 무관하게). ② · ③ · ④만으로 inactive이고 `revoked:sub` 키가 없으면 `{"active": false}`다(키가 있으면 `nbf`가 실린다 — ia-29 넷째 사례). 〔W4〕
     - 라우트에 `response={200: CheckOut}`와 `exclude_none=True`를 둔다. 뷰는 dict를 돌려준다(D28의 반환 규칙).
- ③ · ④를 조회 뒤(4단계)에 두는 까닭: 응답 `nbf` 규칙(「`revoked:sub` 키가 있을 때만」)과 503 우선(fail-closed)을 판정 원인과 무관하게 한 가지로 둔다. ④를 조회 앞에 두면 Dragonfly 장애 때의 응답이 `iat` 값에 따라 갈린다(설계자 결정).
- DB 접근은 0이다(api-4–9는 DB 마크가 없다 — 〔R1〕). Dragonfly 왕복은 2회다(연결은 클라이언트 둘 — `Denylist` 것과 쓰기 클라이언트).
- **T066 고정**: api-4–9. 시험의 `iat`가 전부 현재 시각이고 시험이 `revoked:*`만 두므로(사실 ㉗) ② · ③ · ④는 그 시험들에서 늘 거짓이다 — 응답 dict가 그대로다.
- **공백 → 설계**: 문자 · 길이 규칙(C3). BFF가 보내는 값은 UUID 36자 · sha256 hex 64자라 잃는 것이 없다.
- **기각**
  - 뷰 전용 3명령 파이프라인(왕복 1): `denylist_lookup_seconds` 관측과 계약의 「모듈 수준 `Denylist` 재사용」(api계약:56 · dl:24)을 버려야 한다.
  - `Denylist.lookup` 확장: 모든 pod 공용이고 명령 수가 dc 계약 시험 ac-13으로 고정이며 다른 pod 사용자는 `identity-admin:*`를 읽지 못한다(〔R2 · R15〕).
- **시험**
  - api-4–9 · 44 · 53
  - **ia-1**(U8 a): `sub=` · `sid=` · 256자 · 공백이 든 값 · NUL(`%00`) · 끝 줄바꿈(`%0A` — `$`가 끝 줄바꿈 앞에서도 맞는 엔진이면 새는 값) · 비ASCII → 400. DRAGONFLY_URL을 닫힌 포트로 바꿔도 400이어야 한다(조회 전에 판정).
  - **ia-2**: 3회 요청 → Dragonfly `total_connections_received` 증가 ≤ 2(클라이언트 둘 — 요청마다 새로 만들면 6이다).
  - 하한 · 나이 · 미래 값의 판정 표는 ia-29 · 30 · 36 · 37(D29).
- **변이**: 요청마다 `Denylist()` → ia-2. 검증을 조회 뒤로 → ia-1. `exclude_none` 빼기 → api-4. 하한 조회 예외를 삼킴 → ia-29(정수 아님) · ia-30 (b). 첫 조회가 실패해도 하한을 조회 → ia-30 (a).

### D9 POST /sessions/revoke

1. **본문** `RevokeIn`
   - `sub` · `sid`: 출력 가능 ASCII(`!`–`~`) 1–255자 str 또는 없음(스키마 제약 — D8과 같은 규칙 · 〔Y21〕)
   - `all_devices`: StrictBool, 필수
   - `reason`: Literal 3값, 필수
   - 어기면 400(api-18)
2. **호출자 판정**
   - caller = `auth_claims["sub"]`, target = `body.sub or caller`, self = (target == caller)
   - admin = `groups`가 list이고 원소 하나가 정확히 `"platform-admin"`일 때만(api-16)
3. self가 아니고 admin도 아니면 → 403 `forbidden`(api-16).
4. **조합 검사**(공백 → 설계 · C4)
   - self: `reason ∈ {logout, logout_all}`이고, `logout_all`이면 `all_devices = true`, `logout`이면 `false`
   - self가 아님: `reason == admin`만
   - 어기면 400. 순서를 403 뒤에 두어 api-16을 지킨다.
5. **tenant 결정**
   - self: `request.tenant_id`(미들웨어가 이미 UUID로 보장)
   - self가 아님: 대상 sub의 멤버십. 0건이면 400(api-17). 여러 건이면 D12 규칙.
6. **sid 결정**
   - `all_devices` 참: None. 본문 sid는 무시한다(api-10).
   - 거짓: 본문 sid → (self일 때만) 토큰 sid. 둘 다 없으면 400(api-14 · 51).
   - 교환 토큰에는 sid가 없다(〔조사 E9〕). 그래서 BFF는 본문 sid를 보낸다(C36 · 인계 T092).
   - 쓰기에 들어가는 `sub` · `sid`는 원천(본문 · 토큰)과 무관하게 같은 문자 규칙을 지켜야 한다. 토큰에서 온 값이 어기면(JSON 문자열은 NUL도 담는다) 400이다 — PostgreSQL text와 publish가 NUL을 받지 않아 그대로 두면 500이 된다(B-9 · 〔Y21〕).
7. `nbf = ⌊time.time()⌋ + 1`, `expires_at = nbf + 330`(api-11).
8. `record_revocation(…, delegate=all_devices, source="revoke"|"admin")`(D12). 이 경로에는 `nbf` 상한 비교가 없다 — 관문이 거부할 수 있는 것은 문자 규칙뿐이고 그것은 6단계가 먼저 400으로 거른다(〔W14〕). `nbf`는 서버가 pod 시계로 정하고, pod 시계가 300 s 넘게 앞서면 Bearer 검증이 먼저 깨진다 — DB 시계와 견주면 막는 사례는 없고 PG 시계 지연이 폐기 불능이 되는 사례만 생긴다.
9. `Status(202, {id, nbf, expires_at})`.

- 요청 처리 중 Authentik 호출은 0이다(api-19).
- 4xx 판정은 모두 쓰기 전에 끝낸다. 4xx 응답도 요청 트랜잭션이 커밋되기 때문이다(〔L2〕).
- **pod 경계의 한계**(A14 · 〔Y1〕): `all_devices: false`가 쓰는 `revoked:sid:{sid}`는 `sid` 클레임이 있는 토큰만 막는다. BFF가 pod를 부를 때 쓰는 교환 토큰에는 `sid`가 없으므로 pod 미들웨어에서는 걸리지 않는다. 집행은 BFF의 `/session/check`(`sid` 질의)와 BFF의 refresh 폐기가 맡는다. T073 코드는 본문대로 두 범위를 다 구현한다(T066 고정 — api-12 · 13 · 51). BFF가 기본 로그아웃을 어느 범위로 보낼지는 UD-7이다.
- **관리자 갈래의 `sid` 폐기**(〔W13〕): 관리자 갈래(`reason: admin` · `all_devices: false` — api-51)가 일으킨 `sid` 폐기에는 refresh 폐기가 따르지 않는다(BFF 로그아웃과 달리 그 자리에서 refresh를 지우는 주체가 없다). 그 세션이 330 s 안에 BFF에 닿지 않으면 효력이 없다. SP-1에는 이 갈래를 부르는 호출자가 없고(D30), 관리 명령도 이 범위를 두지 않는다.
- **시험**: api-10–19 · 51 · ia-4(판정 순서 · 조합 · 256자 · NUL · 토큰 `sid`의 규칙 위반 → 400이고 로그 0 · outbox 0 · 키 0 · 지표 0) · ia-5 · **ia-25**(특성 시험 — 한계 고정: `revoked:sid:x` 키를 둔 채 `sid` 클레임이 없는 Bearer로 `/tenants/me` → 200 · 〔Y1〕 · 조각 ③-a에 둔다 — 이 시험이 지나는 것은 미들웨어와 `/tenants/me`뿐이라, 그 뷰가 생기기 전에는 404이고 생긴 뒤 200이다. 쓰기 조각에 두면 구현 전에 이미 초록이다 · 〔Z7〕).
- **변이**: 조합 검사를 403 앞에 둔다 → api-16. 관리자 판정을 부분 문자열로 한다 → api-16.

### D10 POST /webhooks/authentik

1. `request.get_host()`를 먼저 부른다. 밖 Host면 400 `invalid_host`(U8 b · api계약:15).
2. `verify_authentik_webhook(request.body, 서명 헤더, secret=settings.AUTHENTIK_WEBHOOK_SECRET)`. `WebhookSignatureInvalid`면 `to_response()`로 401(api-22).
3. **action**: 없거나 str가 아니면 400. `logout` · `session_deleted`가 아니면 200 `{}`(api-24) — 이때 `sub` · `nbf` · `pk` 꼴은 보지 않는다(무시하는 action의 본문을 검증하지 않는다 · 〔Y12〕).
4. **sub · nbf · pk**(폐기 action일 때만 · 어기면 400 — 공백 → 설계 · C5)
   - sub는 str이고 출력 가능 ASCII(`!`–`~`) 1–255자여야 한다. ORM 조회 전에 isinstance로 본다(api-24의 정수 5). 〔Y21〕
   - nbf가 없으면 `⌊수신 시각⌋ + 1`(api-25 — 프로세스 시계)을 쓰고 WARNING `webhook.nbf_missing`을 남긴다. 이 값이 세션 하한에도 그대로 쓰여 재시도 지연(최대 300 s) 동안 새로 로그인한 세션이 걸린다 — T081 매핑은 `nbf`를 반드시 싣는다(D21 · 〔E7〕).
   - nbf가 있으면 int(bool 제외) · 0 이상이어야 한다(어기면 400 `validation_error` · 쓰기 0 — 형은 api-24 · 음수는 ia-6).
   - **nbf의 상한은 `⌊created⌋ + 1`이다 — 넘으면 거부하지 않고 그 값으로 낮춰 기록한다**(〔Z8〕 — 앞 라운드 〔W14〕의 「넘으면 400 · 쓰기 0」을 고쳤다). 본문 `nbf > ⌊created⌋ + 1`이면 `nbf`를 `⌊created⌋ + 1`로 바꿔 뒤 단계로 넘기고 WARNING `webhook.nbf_clamped`(필드 `sub_hash`)를 남긴다. 응답(202) · 로그 행 · 이벤트 · 키의 `nbf`가 모두 낮춘 값이다. `nbf ≤ ⌊created⌋ + 1`인 값(과거 값 포함)은 본문 값 그대로다(T066 api-20).
     - 거부하지 않는 까닭: 서명이 맞고 창 안인 진짜 로그아웃을 보조 필드 때문에 버리지 않는다. 400이면 Authentik 재시도가 전부 400으로 끝나 그 로그아웃이 유실된다(열린 쪽 — 대조 권한이 없으면 메울 길도 없다 · 재검토 RB-3).
     - 기록되는 값은 여전히 `⌊created⌋ + 1` 이하다 — 미래 값이 하한으로 들어가지 않는다. `created`가 이미 pod 시계 ±300 s 안이므로 기록되는 `nbf ≤ pod now + 301`이 같은 메시지 안에서 나온다(시계를 하나 더 끌어들이지 않는다). 매핑이 `nbf`를 잘못 계산한 것은 WARNING으로 드러난다(1건이라도 경보다 — D25 · T098).
     - `created`는 2단계 `verify_authentik_webhook`이 돌려준 `WebhookEvent.created`(aware datetime — dc/auth.py:826-882)이고 내림은 `math.floor(created.timestamp())`다. 정수끼리 견준다(큰 정수의 datetime 변환 앞).
     - `nbf`가 없을 때 쓰는 값(⌊수신⌋ + 1)에는 이 비교를 하지 않는다 — 서버가 정한 값이다(이 값까지 낮추면 api-25의 하한 `⌊t0⌋ + 1`이 초 경계에서 깨진다 — 그 시험은 본문 `created`를 t0보다 먼저 만든다).
     - T066과의 양립(원문 확인 — api-20–26 · 〔Z8〕): 웹훅 본문을 만드는 시험은 `nbf = int(time.time()) − 2`를 먼저 정하고 `created = datetime.now(UTC)`를 뒤에 만든다(test_api.py:1553-1554 · 1577 · 1683-1684 · T/tests/_jwt.py.jinja:133-137) — 늘 `nbf ≤ ⌊created⌋ + 1`이라 낮춤에 닿지 않고, api-20의 「로그 행 `nbf` = 본문 `nbf` · `revoked:sub` = 본문 `nbf`」와 api-21 · 26의 202가 그대로다. `nbf`를 싣지 않는 본문(api-22 · 23 · 25)과 형이 틀린 `nbf`(api-24 — 형 검사가 먼저 400)도 낮춤에 닿지 않는다. 본문 `nbf`가 `⌊created⌋ + 1`을 넘는 T066 사례는 없다.
   - pk(`verify_authentik_webhook`이 준 비지 않은 str)는 출력 가능 ASCII 1–255자여야 한다. UUID로 읽히면(hex 32자 또는 8-4-4-4-12 꼴 · 대소문자 무관) 대시 소문자 정규형으로 바꿔 쓴다(`revocation.normalize_event_pk`) — 매핑이 `str()`을 빠뜨려 hex 꼴이 와도 일 1회 대조의 pk와 한 행이 된다(B-4 · 〔Y17〕). T066 본문의 pk는 대시 소문자 uuid4라 api-20 · 21의 단언이 그대로다.
5. event_pk 사전 확인(`revocation.event_already_recorded(pk)` — 정규형으로 묻는다): 이미 있으면 200 `{}`(api-21). 멤버십 조회보다 앞에 두어 재전송을 늘 멱등으로 만든다.
6. 멤버십: 0건이면 400(api-23). 여러 건이면 D12 규칙.
7. `record_revocation(reason="authentik_webhook", sid=None, event_pk=pk, delegate=False, source="webhook")`. 경합으로 Replayed면 200 `{}`, Recorded면 `Status(202, {id, nbf, expires_at})`다. 관문(D12)이 이 경로에서 거부할 수 있는 것은 4단계가 이미 거른 문자 규칙과 `nbf` 음수뿐이다 — 그래도 `RevocationRejected`는 400 `validation_error`로 바꾼다(심층 방어 · 관문은 INSERT 앞에서 판정한다 — 쓰기 0). `nbf` 상한을 DB 시계와 견주지 않는다(〔W14〕).

- Ninja operation은 본문 파라미터 없이 선언한다(T066 가정 ⑦).
- Authentik 위임은 하지 않는다. 출처가 Authentik이기 때문이다(〔L14〕).
- 커밋 뒤 쓰기는 사용자 단위 행의 규칙 그대로다 — `revoked:sub`와 세션 하한 키(D13 · D29). 재전송(5단계)은 어떤 키도 다시 쓰지 않는다(api-21).
- **시험**
  - api-20–26
  - ia-3(U8 b — MIDDLEWARE에서 CommonMiddleware를 빼고 ADMIN_HOST="", 서명이 맞든 틀리든 400) · ia-5
  - **ia-6**: nbf 음수 → 400 · 과거 nbf(지금 − 3600) → 202 · sub에 NUL · 공백 · 끝 줄바꿈 · 256자 → 400 · 256자 pk · NUL이 든 pk → 400(400인 경우는 모두 로그 0 · outbox 0 · 키 0) 〔Y21〕
  - ia-7(D12)
  - **ia-8**: 202 본문 키 정확히 셋 · 200 본문 `{}` · 위임 0(쓰기 플래그를 켜도 enqueue 0) · 무시 action(`login`)은 sub가 정수 · nbf가 문자열이어도 200 · hex 32자 pk와 같은 UUID의 대시 꼴 pk는 한 행(둘째는 200) · nbf 없는 본문 → WARNING `webhook.nbf_missing` 한 줄 〔Y12 · Y17 · E7〕
  - nbf 상한(`⌊created⌋ + 1`)을 넘는 값의 낮춤은 ia-39 (a) · HTTP 경로가 DB 시계를 보지 않는 것은 ia-39 (c)(D12)
- **변이**: get_host를 HMAC 뒤로 → ia-3. `str(sub)`로 조회 → api-24. pk 정규화 삭제 → ia-8. 낮춤 삭제(본문 값 그대로 기록) → ia-39 (a)(〔Z8〕).

### D11 GET /tenants/me

- 멤버십을 `filter(sub=auth_claims["sub"], tenant_id=request.tenant_id).first()`로 찾는다.
- 멤버십이 없거나 Tenant가 없으면(고아 멤버십) `problem_response("not_found", 404)`. 고아 멤버십의 404는 공백 → 설계다(C37 · 〔Y15〕).
- 응답 dict: `{tenant: {id, slug, display_name, status}, role}`.
- **시험**: api-27–29 · 45 · ia-21(고아 멤버십 — 같은 멤버십으로 Tenant 행이 있을 때 200 → 그 행을 지운 뒤 404 · 〔Z7〕: 404만 보면 `/tenants/me`가 없어도 템플릿 handler404가 같은 404 `not_found`를 내 구현 전에 초록이다).
- **변이**(〔W34〕 — T066 원문으로 확인): `tenant_id` 조건 삭제 → api-28 · 29(api-28은 A · B 두 멤버십을 둔 사용자의 B 토큰이 먼저 만든 A 멤버십을 받고, api-29는 A에만 있는 사용자의 B 토큰이 404 대신 200을 받는다). 고아 처리 삭제 → ia-21.

### D12 폐기 기록 공통 · 다중 멤버십 · 무결성

- **함수**: `revocation.record_revocation(*, tenant_id: UUID, sub, sid, reason, nbf: int, source, event_pk=None, delegate=False) -> Recorded | Replayed`
  - 폐기를 기록하는 모든 경로의 단일 관문이다: `/sessions/revoke`(source `revoke` · `admin`) · 웹훅(`webhook`) · 일 1회 대조(`reconcile`) · 관리 명령(`command` — D30). 모델에 직접 INSERT하는 경로를 두지 않는다(하한 · 이벤트 · 로그가 한 행에서 나온다).
  - `Recorded(id, nbf, expires_at, after)` · `Replayed()`. `expires_at` = `nbf + 330 s`(Python에서 만든다).
    - `after`는 커밋 뒤 콜백 `_after`(6단계)가 채우는 작은 가변 객체다 — 칸은 `denylist` · `delegate` 둘이고 초깃값은 None이다(〔W21〕).
    - 읽는 쪽은 관리 명령 하나다(D30). 명령 경로에서는 atomic이 가장 바깥이라 `record_revocation`이 돌아오기 전에 콜백이 끝난다. HTTP 경로의 뷰는 이 칸을 읽지 않는다 — `/sessions/revoke`에서는 콜백이 뷰가 돌아간 뒤(미들웨어 트랜잭션의 커밋 때) 돈다.
  1. `transaction.atomic()` 안에서 처리한다. revoke에서는 미들웨어 durable 아래 savepoint이고, 웹훅 · 백필 · 명령에서는 가장 바깥 트랜잭션이다.
  2. **관문**(쓰기 앞 · 위반은 `RevocationRejected(code)` — 메시지 · 값 없음 · 〔E6 · Y21 · W14〕)
     - 입력: `sub` · `sid`(있으면) · `event_pk`(있으면)가 출력 가능 ASCII(`!`–`~`) 1–255자다(`revocation.valid_identifier` — `re.fullmatch`로 본다: Python의 `$`는 끝 줄바꿈 앞에서도 맞는다). 호출자가 먼저 400 · CommandError로 거르는 규칙의 심층 방어다. 웹훅 · 관리 명령 · 토큰에서 온 값처럼 스키마를 지나지 않는 입력은 호출자도 이 함수로 본다.
     - `nbf`: 0 이상 정수여야 한다(모든 source).
     - **`nbf` 상한 — `source == "command"`일 때만**(〔W14〕): `nbf ≤ db_now_epoch() + 301`이어야 한다(`revocation.db_now_epoch()` — `SELECT floor(extract(epoch FROM statement_timestamp()))::bigint` 한 번 · 호출 지점은 모듈 속성으로 부른다 — ia-39의 이음매 · D26). 정수끼리 견준다(datetime 변환 앞 — 큰 정수의 `OverflowError`가 500이 되지 않게). 관리 명령은 JWT도 시각 창도 없는 유일한 경로다 — 시계가 틀린 곳에서 돈 명령이 30일짜리 하한을 미래 값으로 올리는 것을 DB 시계로 막는다(〔ATK-9〕). 301은 웹훅 시각 창 +300 s 끝에서 매핑 `nbf = ⌊created⌋ + 1`이 내는 값과 같은 여유다(〔Y15 · Y21〕).
     - **미래 값은 경로마다 쓰기 전에 막힌다**(값 301과 「잘못 오른 값을 쓰기 전에 막는다」는 〔E6〕 그대로이고, 기준 시계만 경로별로 갈랐다 — 〔W14〕)
       - 웹훅: 뷰가 본문 `nbf`의 상한 `⌊created⌋ + 1`을 본다 — 넘는 값은 거부하지 않고 그 값으로 낮춰 기록한다(D10 4단계 · 〔Z8〕 — `created`가 pod 시계 ±300 s 안이라 기록되는 값은 `pod now + 301` 이하다).
       - 대조: 3단계의 재확인(`created ≤ now + 300 s`)으로 `nbf = ⌊created⌋ + 1 ≤ now + 301`이 구성상 성립한다(D17). 관문에 `source == "reconcile"` 비교를 다시 넣지는 않는다 — 같은 시계(워커)로 같은 것을 두 번 보는 일이다. 그 위쪽 끝은 ia-13의 미래 이벤트 미끼와 변이가 지킨다(〔Z3〕).
       - 관리 명령: 위 DB 시계 비교.
       - `/sessions/revoke`(source `revoke` · `admin`): 상한 비교가 없다 — `nbf`는 서버가 pod 시계로 정한다(D9).
     - HTTP 경로에서 DB 시계와 견주지 않는 까닭: 막는 사례가 없다(`/sessions/revoke`의 `nbf`는 서버가 정하고, pod 시계가 300 s 넘게 앞서면 Bearer 검증이 먼저 깨진다). 견주면 PG 시계 지연이 폐기 불능(revoke 500 · 웹훅 400)이 되고 T066의 revoke · 웹훅 시험이 DB 컨테이너 시계에 기대게 된다(검토 B-2).
     - 호출자의 처리: 관리 명령 = `CommandError`. 웹훅 뷰는 `RevocationRejected`를 400 `validation_error`로 바꾼다(D10 7단계 — 4단계가 같은 규칙을 먼저 거르므로 심층 방어다). `/sessions/revoke`와 대조는 호출자가 문자 규칙을 먼저 거르므로(D9 6단계 · D17 3 · 5단계) 관문이 거부할 것이 남지 않는다.
     - **시험 환경 주의**: DB 시계에 기대는 시험은 실제 DB 시계로 `revoke_sessions`를 도는 ia-26 하나다 — DB 컨테이너의 시계가 시험 프로세스보다 300 s 넘게 늦으면 `CommandError`다(Docker Desktop의 VM 시계는 호스트 절전 뒤 늦을 수 있다 — 추론 · 이 PC에서 잰 적은 없다). 확인 명령은 §5 공통 환경에 둔다. T066의 revoke · 웹훅 시험(api-10–25)은 DB 시계를 보지 않는다(T066의 다른 단언도 두 시계를 섞지 않는다 — 사실 ⑪).
  3. event_pk가 있고 `revocation.event_already_recorded(event_pk)`면 Replayed(이 함수 이름이 ia-7의 이음매다 — 〔Y10〕).
  4. 중첩 atomic 안에서 INSERT한다.
     - IntegrityError의 `diag.constraint_name`이 `srl_event_pk_uniq`면 Replayed.
     - 그 밖의 IntegrityError는 `RevocationWriteError() from None`. 메시지가 없는 500이다. DETAIL의 행 값이 로그 · Sentry에 실리지 않게 한다(bn:3724).
  5. `with tenant_context(tenant_id): publish_owned("session.revoked", f"user:{sub}", {sub, sid, nbf, reason}, tenant_id=tenant_id)`
     - 교차 테넌트 · 웹훅 · 백필 · 명령이 모두 같은 꼴이다.
     - data 키는 정확히 4개다(T066 ⑪ · 〔L5 · L6〕).
  6. `on_commit(_after, robust=True)` 하나를 등록한다. 안에서 차례로 돈다.
     - ① D13 쓰기(결과 = `ok` · `skipped` · `failed`(명령 단위 오류 · DB 조회 실패) · `unreachable`(연결 · 시간 초과)) — 결과를 `after.denylist`에 적는다
     - ② 지표 +1
     - ③ 로그 `session_revocation.recorded`
     - ④ delegate면 D16 위임 — ①이 `unreachable`이면 건너뛴다(브로커가 같은 Dragonfly라 enqueue도 같은 시간을 쓰고 실패한다 · INFO `authentik.revoke_skipped reason=denylist_unreachable` · 〔Y18〕). Celery 앱은 이 단계 안에서 가져온다(`from identity_admin.celery import app` — 모듈 머리 import 금지 · D16 · 〔W22〕). 결과를 `after.delegate`에 적는다 — `enqueued` · `skipped`(자리값 자격 · ①이 `unreachable`) · `off`(쓰기 플래그 거짓) · `failed`(enqueue 실패). 판정은 쓰기 플래그 → 자리값 자격 → ①의 결과 → enqueue 순서다(D16 「위임 조건」의 순서 — 값이 하나로 정해진다). delegate가 거짓인 호출에서는 None으로 남는다(〔W21〕)
     - 단계마다 자기 try/except가 예외 클래스 이름만 남긴다. Django robust 로그는 예외 문구를 싣는다(〔L8〕).
- 롤백이면 콜백이 버려진다. 키 · 지표 · 로그 · 위임이 모두 0이다.
- **event_pk 정규형**(`revocation.normalize_event_pk` · 〔Y17〕): UUID로 읽히는 값(hex 32자 · 8-4-4-4-12 꼴)은 대시 소문자, 그 밖의 값은 그대로다. 웹훅(D10)과 대조(D17)가 저장 · 조회 앞에서 같은 함수를 지난다.
- **다중 멤버십**(공백 → 설계)
  - `tenant_id`가 가장 작은 행을 결정적으로 고른다.
  - WARNING `identity.multiple_memberships`(count · sub_hash)을 남긴다.
  - 키는 sub 단위라 폐기 효과는 같다. 400으로 막으면 웹훅이 재시도 끝에 폐기를 놓친다(fail-open).
  - SP-1 가정 「사용자당 테넌트 1」(dm:40)이 깨질 때만 생긴다.
  - 409는 두지 않는다(〔L23〕).
- **계약**: C4 · C5 · C11 · C24 · C38.
- **시험**
  - api-10 · 15 · 20 · 21
  - **ia-5**: 같은 sub에 멤버십 둘(테넌트 A · B) → 관리자 호출과 웹훅 모두 202이고(409 아님) 로그 · outbox의 `tenant_id`가 둘 가운데 작은 쪽이다 · WARNING `identity.multiple_memberships` 한 줄(count 2 · `sub_hash` — 원문 sub 없음)
  - **ia-7**: `revocation.event_already_recorded`를 monkeypatch로 늘 거짓으로 두고 같은 event_pk를 두 번 → 둘째는 200(Replayed) · 500 아님 · 행 1 · 로그와 응답에 DETAIL 없음
  - **ia-39**(`nbf` 상한 — 경로별 · 〔W14 · Z8〕 · 셋 다 조각 ③-b2 — 웹훅이나 관리 명령을 지난다 · 〔Z20〕)
    - (a) 웹훅의 낮춤(〔Z8〕 — 다시 썼다): 본문 `nbf` = `⌊created⌋ + 2` · `⌊created⌋ + 86400` → 둘 다 202이고 응답 · 로그 행 · 세션 하한의 `nbf`가 `⌊created⌋ + 1` · WARNING `webhook.nbf_clamped` 한 줄(그 줄에 sub 원문 없음) / 본문 `nbf` = `⌊created⌋ + 1` → 202 · 본문 값 그대로 · WARNING 0. 본문의 `created`를 시험이 정해 넣으므로 사례의 판정이 시계에 기대지 않는다.
    - (b) `revocation.db_now_epoch`를 지금 − 400을 돌려주게 덮고(호출 수를 센다) `revoke_sessions` → `CommandError` · 행 0 · 호출 1회 이상
    - (c) 같은 덮기 아래 `/sessions/revoke`(전체 로그아웃)와 웹훅 → 둘 다 202이고 `db_now_epoch` 호출 0. HTTP 경로가 DB 시계를 보지 않음을 고정한다 — (b)가 같은 가로채기로 호출이 닿는 것을 먼저 보인다(D26 「이음매」의 규칙).
    - 앞 라운드의 (c)(대조 백필의 `reason=nbf_future` — 조각 ⑤ 소속)는 없어졌다. 앞 라운드의 (a)(상한을 넘는 본문 `nbf`를 거부하고 쓰기 0을 단언했다)는 〔Z8〕로 위 꼴이 됐다.
- **변이**: 명령의 `nbf` 상한 삭제 → ia-39 (b). 웹훅의 낮춤 삭제(본문 값 그대로 기록) → ia-39 (a)(〔Z8〕). HTTP 경로에 DB 시계 비교를 넣음 → ia-39 (c). unique 삭제 → ia-7(D4). 콜백 ④의 `unreachable` 건너뛰기 삭제 → ia-11. `after`를 채우지 않음 → ia-26(D30).

### D13 거부 목록 · 세션 하한 쓰기(요청 경로)

- **클라이언트**(`denylist_writer.client()`)
  - `Redis.from_url(settings.DRAGONFLY_URL, socket_timeout=0.2, socket_connect_timeout=0.2, retry=Retry(NoBackoff(), 0))`
  - URL별로 캐시하고 잠금을 둔다. 지연 생성이다.
  - URL에 쿼리가 있으면 쓰지 않는다(dl:24와 같은 이유).
  - dc의 비공개 `_denylist_client`는 쓰지 않는다(〔L9 · L10〕).
  - `/session/check`의 하한 조회(D8)와 재적용(D14)도 이 클라이언트를 쓴다.
- **키 · 값**
  - `revoked:sub:{sub}` = `str(nbf)`(정수 꼴) · `revoked:sid:{sid}` = `"1"`(dl:7-15)
  - `identity-admin:session-floor:{sub}` = `str(nbf)`(D29 · 〔E1〕)
- **`sid` 행**(`denylist_writer.apply_sid(sid, expires_at)`): `SET revoked:sid:{sid} 1 EX min(330, ⌊expires_at − time.time()⌋)`. 자기 행 값으로 쓰고 DB를 읽지 않는다. 하한을 만들지 않는다(〔E13〕).
- **사용자 단위 행**(`denylist_writer.apply_user(sub)` · 〔E1 · Y22〕)
  1. 커밋 뒤 SQL 1회로 그 sub의 보존 창 안 사용자 단위 행 가운데 `nbf`가 가장 큰 행을 읽는다(app role · 한 문장). 30일은 리터럴이 아니라 `REVOCATION_LOG_RETENTION`을 매개변수로 넘긴다(D29).
     ```sql
     SELECT extract(epoch FROM nbf)::bigint,
            extract(epoch FROM expires_at)::bigint,
            floor(extract(epoch FROM expires_at + %(retention)s - statement_timestamp()))::bigint
     FROM session_revocation_log
     WHERE sub = %(sub)s AND sid IS NULL AND expires_at > statement_timestamp() - %(retention)s
     ORDER BY nbf DESC, expires_at DESC LIMIT 1
     ```
  2. 파이프라인 1회(`pipeline(transaction=False)` · `execute(raise_on_error=False)`)로 둘을 보낸다.
     - `SET revoked:sub:{sub} <그 nbf> EX min(330, ⌊그 행 expires_at − time.time()⌋)`
     - `SET identity-admin:session-floor:{sub} <그 nbf> EX <셋째 열>`
  3. TTL이 1 미만인 키는 보내지 않는다(〔조사 E25〕). 둘 다 빠지거나 행이 없으면 Dragonfly에 닿지 않고 INFO `denylist.set_skipped`를 남긴다.
  - **왜 자기 행 값이 아닌가**: 늦게 끝난 요청(역순 커밋)과 과거 `nbf` 웹훅 · 백필이 더 큰 값을 덮어 낮추는 일을 요청 경로에서 없앤다(B-10 · 〔L13〕). `ORDER BY … LIMIT 1`로 한 행을 고르므로 「`expires_at` = `nbf` + 330」 관계에 기대지 않는다.
  - **`sid` 행에는 이 조회를 두지 않는다**(설계자 결정): `revoked:sid`의 값은 상수 `1`이라 덮어써도 약해지지 않는다. 달라질 수 있는 것은 TTL뿐이고 그 차이는 두 폐기의 `nbf` 차이(보통 1 s)이며 재적용이 맞춘다.
- **반환**(〔W29〕): `apply_user` · `apply_sid`는 네 문자열 `ok` · `skipped` · `failed` · `unreachable` 가운데 하나를 돌려준다. 아래 「실패」의 세 갈래도 예외가 아니라 이 값으로 돌려준다(D12 6단계 ①이 `after.denylist`에 적는다).
- **TTL의 시계**
  - `revoked:*`는 프로세스 시계로 잰다. `nbf`를 프로세스 시계로 정하므로(api-11 · 25 — 〔T30〕) 같은 시계로 재면 DB 컨테이너와 시험 프로세스의 시계가 어긋나도 TTL이 [329, 330]에 든다 — revoke는 330(api-10 [325, 330]), 웹훅 nbf = now − 2는 328(api-20 [320, 330])이다. 바탕 설계는 이 TTL도 DB 시계로 썼지만 결정 문서는 하한 TTL만 DB 시계로 정했다 — T066 단언이 시계 차에 흔들리지 않는 쪽을 골랐다(설계자 결정).
  - 하한 TTL은 DB 시계다(〔E1〕). 30일 규모라 초 단위 어긋남은 뜻이 없고 재적용(D14)과 같은 식이 된다.
- **실패**
  - 1단계 DB 조회 실패 → WARNING `denylist.set_failed error=<클래스> stage=lookup` · 아무것도 쓰지 않는다(결과 `failed`). 자기 행 값으로 대신 쓰지 않는다 — 더 큰 기존 값을 낮출 수 있다.
  - 파이프라인의 연결 · 시간 초과 → WARNING `denylist.set_failed error=<클래스> stage=connect`(결과 `unreachable` — D12 ④의 위임 건너뛰기 판정).
  - 명령 단위 오류(NOPERM 등 — 결과 목록의 예외 객체) → WARNING `denylist.set_failed error=<클래스> stage=command`(결과 `failed`).
  - 어느 경우든 응답은 그대로다(api-26). Celery 재시도는 enqueue하지 않는다. 브로커가 같은 Dragonfly라 함께 실패하고 응답만 약 4 s 늦어진다(〔L14〕). D14의 30 s 재적용이 키를 되살린다.
- **기각**
  - EX 330 고정(G2)
  - 로그 + Celery 재시도
  - 키별 최댓값 Lua · `ZADD GT`: 커밋 뒤 최댓값 조회로 요청 경로에서 자기 행 값으로 덮는 경합(역순 커밋 · 과거 `nbf` 웹훅)은 없앴다. 「조회 뒤 SET」 경합은 재적용과 콜백 사이, 콜백과 콜백 사이에 남는다(창은 ms · 다음 재적용이 되돌린다 — §9 · 〔W18〕). 그것까지 없애려고 Lua를 들이면 Dragonfly 실측 항목만 늘고 얻는 것이 작다.
- **계약**: C4 · C5 · C12 · C15 · C39 〔편차 8 · 9 · 19〕.
- **시험**: api-10 · 12 · 20 · 26 · ia-6 · ia-19 · ia-27 · 28 · 31 · 34 · 35(D29).
- **변이**: 0.2 s 명시를 지운다 → ia-19(블랙홀 포트에서 시간 상한 ≤ 1 s — 닫힌 포트는 Linux에서 즉시 RST라 가르지 못한다 · 〔Y10〕). `min` 상한을 지운다 → api-10 TTL이 331이 될 수 있다. 최댓값 조회를 지우고 자기 행 값을 쓴다 → ia-31.

### D14 무조건 재적용 · beat_init · 로그 purge

- **재적용**: `denylist_writer.reapply() -> ReapplyResult`
  - **첫 SQL — `revoked:*`**(한 문장 = DB 시계 하나 · 초안 그대로)
    ```sql
    SELECT sub, sid, extract(epoch FROM nbf)::bigint, floor(extract(epoch FROM expires_at - statement_timestamp()))::bigint
    FROM session_revocation_log WHERE expires_at > statement_timestamp() ORDER BY nbf, expires_at
    ```
    - 행 → 키(dm:68). 같은 키가 여럿이면 마지막 행만 남긴다. 그 행이 nbf 최대 · expires 최대다(〔L13 · T31〕).
  - **둘째 SQL — 세션 하한**(〔E1〕): 보존 창 안 사용자 단위 행을 sub별로 묶어 `nbf`가 가장 큰 행 하나씩 읽는다. 30일은 D13과 같은 매개변수다.
    ```sql
    SELECT DISTINCT ON (sub) sub, extract(epoch FROM nbf)::bigint,
           floor(extract(epoch FROM expires_at + %(retention)s - statement_timestamp()))::bigint
    FROM session_revocation_log
    WHERE sid IS NULL AND expires_at > statement_timestamp() - %(retention)s
    ORDER BY sub, nbf DESC, expires_at DESC
    ```
    - 행 → `identity-admin:session-floor:{sub}` = 그 `nbf` · TTL = 셋째 열. 쓸 때마다 「남은 초」로 두므로 재적용이 TTL을 늘리지 않는다(`revoked:*`와 같은 규칙).
  - TTL < 1인 키는 건너뛴다(두 SQL 모두).
  - **신선도 키**(〔E5 · W16〕): 파이프라인의 마지막 명령으로 `SET identity-admin:denylist:reapplied-at <epoch 초> EX 300`을 보낸다. 행이 0이어도 보낸다 — 초안의 「키가 0이면 Dragonfly에 닿지 않는다」는 이 키 하나를 예외로 고친다. 값은 워커의 `int(time.time())`이다(자동 소비자는 키의 존재를 보고, 사람은 값이 전진하는지를 본다 — 아래 「키의 뜻」 · 설계자 결정 · 〔Z10〕). 자기 접두라 ACL 변경이 없고 템플릿 규칙(`~<pod>:*`) 아래에서도 써지므로 실제 워커 시험의 NOPERM 0이 유지된다(〔P17〕).
    - 키의 뜻 = 「최근 300 s 안에 재적용이 두 SQL을 끝내고 Dragonfly까지 닿았다」. 명령 단위 실패(NOPERM)는 가리지 못한다 — 그것은 `failed` 건수가 알린다.
    - 키의 존재는 「최근 300 s 안에 한 번 닿았다」일 뿐이다 — 재적용이 죽은 직후 300 s는 키가 남는다(〔Z10〕 · 재검토 RB-5). 사람이 판단할 때는 값(epoch 초)이 전진하는지 본다(35 s 간격으로 두 번 읽는다). gitops README의 dump 삭제 조건(§7 T075)과 런북(§7 T114)이 이 기준을 쓴다. 관리 명령의 `PARTIAL` 문구(D30)는 신선도 키를 가리키지 않고, 그 폐기의 키 둘이 60 s 뒤 생겼는지를 직접 보게 한다.
    - 수명 300 s의 근거(〔W16〕 — 결정 E5의 120 s를 고쳤다): 가장 긴 작업 마감 120 s(일 1회 대조 — D17) + tick 30 s + 여유이고, T098의 「성공 줄 5분 무소식」과 같은 문턱이다. 120 s면 solo 워커가 대조를 마감까지 도는 동안 tick이 밀려 버려지고(`expires` 30) 키가 수 초에서 30 s쯤 거짓으로 빈다(검토 B-4).
    - web 프로세스의 「신선도 키 없음」 WARNING은 넣지 않는다. 소비자는 T098 경보(성공 줄 5분 무소식)와 T075의 celery 생존 판정이다(§7 · 〔E5〕).
  - `pipeline(transaction=False)`로 SET을 보내고(1000개 단위로 나눈다 — 신선도 키는 마지막 묶음) `execute(raise_on_error=False)`로 받는다.
    - 명령 단위 실패가 있으면 WARNING `denylist.reapply_failed failed=n error=<첫 클래스>`.
    - EXISTS 0 · `denylist:epoch` 0이다(dl:29).
  - **반환 계약**(〔Y10 · Y16 · E5〕): `ReapplyResult(rows, keys, floors, skipped, failed)` — 모두 정수.
    - `rows` = 첫 SQL이 읽은 활성 행 수 · `keys` = 보낸 `revoked:*` SET 수(같은 키를 묶은 뒤) · `floors` = 보낸 하한 SET 수 · `skipped` = TTL < 1로 건너뛴 키 수(둘 합) · `failed` = 결과가 오류였던 명령 수(신선도 키 포함)
    - SQL 실패나 연결 · 시간 초과는 예외로 올린다(반환하지 않는다).
  - **규모**: `revoked:*` 대상은 최근 330 s의 활성 행(수 건)이고, 하한 대상은 최근 30 d + 330 s의 사용자 단위 행이다. SP-1(사용자 2 · E2E 반복 · 백필)은 수십–수백 행 · 한 자리 키로 본다(추론 · 미실측 — VD-T073-13). 사용자 단위 행이 10^5를 넘으면 증분 재적용(tick마다 최근 `created_at`만 · 전량은 `beat_init`과 N분 주기)으로 바꾸되 「캐시 상태를 묻지 않는다」는 유지한다(dl:30 보정 — C13 · 〔R10〕).
- **작업 `reconcile_denylist`**(30 s — `jobs.py`)
  - `reapply()`를 부르고 결과를 dict `{rows, keys, floors, skipped, failed}`로 반환한다. Celery 성공 줄이 그 값을 찍는다 — 이 줄이 재적용 생존 신호다(5분 무소식 = 경보 — T098 · 〔Y16〕).
  - 예외는 잡아 WARNING `denylist.reapply_failed phase=tick error=<클래스>`를 남기고 `ReapplyFailed() from None`(메시지 없음)으로 다시 올린다. 성공 줄이 찍히지 않고, redis-py · psycopg 예외 문구(호스트 · 포트)가 Celery 실패 로그에 실리지 않는다.
- **beat_init**: `jobs.py`의 `@beat_init.connect`(sender로 거르지 않는다 — T066 ④)
  - 같은 함수(`reapply()`)를 동기로 부른다. 하한 · 신선도 키도 같이 쓴다.
  - 예외는 WARNING `denylist.reapply_failed phase=beat_init error=<클래스>`만 남기고 beat 기동은 계속된다(api계약:81).
  - 성공하면 INFO `denylist.reapplied phase=beat_init`(필드 = 반환 계약의 다섯 건수).
  - 운영의 내장 beat는 fork된 자식에서 fd를 닫은 뒤 이 신호를 받는다(celery 5.6.3 beat.py — B-3). 그 토폴로지에서 수신자가 실제로 키를 만드는지는 ia-40과 VD-T073-5가 본다.
- **purge**(작업 `purge_session_revocation_log` → `denylist_writer.purge_log()`): `filter(expires_at__lt=Now() - REVOCATION_LOG_RETENTION).delete()`
  - 계약 식과 같은 뜻의 인덱스 친화 식이다(〔조사 E29〕). 일 1회 03:27 UTC. 삭제 건수를 반환한다.
  - 이 경계가 하한 수명의 경계와 같은 식 · 같은 상수다 — 하한이 사는 동안 그 행은 반드시 DB에 있다(D29).
- **이름**: `identity_admin.tasks.reconcile_denylist` · `…purge_session_revocation_log`.
- **계약**: C7 · C13 · C41.
- **시험**
  - api-26 · 30–32 · 34
  - **ia-9**: 같은 sub 활성 행 둘을 역순으로 넣는다 → 값 = 큰 nbf, TTL은 그 행 기준. 같은 sid 둘 → 키 하나.
  - **ia-10**: 만료 0.4 s 전 `sid` 행 → 그 키 없음 · 오류 0 · 반환 `skipped == 1` · 다른 키는 그대로 있다. 조회 시점에 행이 (0, 1)초 창 밖이었으면(`skipped == 0`) 행을 새로 넣고 다시 한다(최대 5회 — 창을 놓친 실행이 공허하게 통과하지 않게 · 〔Y10〕).
  - **ia-32** · **ia-33**(하한 재적용 · purge와의 경계 — D29)
  - **ia-38**: 행 0에서 재적용 → 신선도 키가 있고 TTL ∈ [290, 300] · 반환 다섯 건수 0 · `revoked:*` 키 0 / 행을 넣고 재적용 → 작업 반환 dict의 키가 정확히 다섯 · 값이 실제 키 수와 같다 / Dragonfly를 닫힌 포트로 두면 작업이 실패하고(성공 아님) 실패 로그에 호스트 · 포트가 없다 / beat 항목 `reconcile-denylist`의 `options` == `{"expires": 30}`(D15) 〔E5 · Y16〕
  - **ia-40**: 실제 worker + beat(D26 — `FLUSHALL` 앞의 tick 단언(뺄 수 없다 · 〔Z16〕)과 `FLUSHALL` 뒤 60 s 안의 복귀 단언 · VD-T073-15 (a) · 〔W25〕)
- **변이**: ORDER BY 삭제 → ia-9. TTL<1 가드 삭제 → ia-10. sender 필터 → api-32. 신선도 키를 행이 있을 때만 쓴다 → ia-38. 신선도 키의 수명을 120 s로 → ia-38. 둘째 SQL 삭제 → ia-32.

### D15 Celery 배선

- **celery.py beat**: 기존 `purge-dead-outbox`(03:17)는 그대로 두고 셋을 더한다.
  - `"reconcile-denylist"`: `timedelta(seconds=30)` + `"options": {"expires": 30}` — 워커가 다른 작업에 잡혀 밀린 tick을 쌓아 두었다가 연달아 돌리지 않고 버린다(B-3 · 〔Y16〕). api-33은 항목의 `task`와 `schedule`만 본다.
  - `"purge-session-revocation-log"`: crontab(27, 3)
  - `"reconcile-authentik-sessions"`: crontab(37, 3)
  - 일 1회의 정의는 api계약:87을 따른다.
- **작업 정의**: `jobs.py`의 `@app.task(name="identity_admin.tasks.<이름>")`
  - `tasks.py`에는 `from identity_admin import jobs as _jobs  # noqa: F401` 한 줄만 둔다. autodiscover가 `identity_admin.tasks`만 import하기 때문이다(⑧).
- **작업 목록**
  - reconcile_denylist
  - purge_session_revocation_log
  - reconcile_authentik_sessions
  - revoke_authentik_sessions(beat 밖 — D16)
  - 템플릿 purge_dead_outbox
- import 시 DB · 네트워크는 0이다(api-33은 DB 마크가 없다).
- 브로커 · transport · eager 끔은 템플릿 그대로다(test_outbox.py.jinja:714).
- 롤링 중 beat가 둘이어도 모든 작업이 멱등이다.
- **반환값**: 작업은 None이나 건수(정수 · 정수만 든 dict)만 반환한다. Celery 성공 줄이 반환값을 찍으므로 `sub` · URL · 토큰이 든 값을 돌려주지 않는다(B-8 · 〔Y20〕).
- **실행 경로의 성질**(운영 = 컨테이너 하나 · `celery worker --pool solo --beat`): 작업은 한 번에 하나이고 Celery 시간 제한을 쓸 수 없다. 그래서 외부 호출 작업은 코드 안 마감을 갖고(D16 · D17 · D20), 재적용 tick은 `expires`를 갖는다. 내장 beat 자식이 죽으면 워커는 살아도 tick이 멈춘다 — 탐지는 성공 줄 무소식 경보뿐이다(§9 · 〔Y24〕).
- **시험**: api-33 · 35 · 템플릿 beat 단언(D26) · ia-38(beat 항목의 `expires`) · ia-40 · VD-T073-5 · 15.
- **변이**(〔W34〕 — T066 원문으로 확인): `tasks.py`의 import 줄 삭제 → api-33(`_celery_app()`은 `import_default_modules()`로 `identity_admin.tasks`만 적재한다 — test_api.py:643-647 — 그 줄이 없으면 `jobs.py`가 등록하는 작업이 `app.tasks`에 없다. api-26 · 30–32 · 34도 「등록되지 않았다」로 함께 깨진다). 이 변이는 api-33을 노드 ID로 따로 돌려 본다 — 같은 프로세스에서 다른 시험이 먼저 `identity_admin.jobs`를 가져오면 등록이 남는다. beat `expires` 삭제 → ia-38.

### D16 Authentik 세션 삭제 위임

- **작업**: `identity_admin.tasks.revoke_authentik_sessions(sub: str, nbf: int)`
  - 옵션: `autoretry_for=(AuthentikTransient,)` · `retry_backoff=5` · `retry_backoff_max=300` · `retry_jitter=False` · `max_retries=3` · `acks_late=True` · `reject_on_worker_lost=True` · `ignore_result`
  - 「5 s × 3회 지수 백오프(최대 5분)」의 해석
    - HTTP 타임아웃 5 s(호출마다) · 한 시도 전체 마감 20 s(`jobs.DELEGATION_DEADLINE_S` — 단조 시계 · `outbound.Deadline` · D20 · 상수 이름은 D26 · 〔W29〕). solo 풀에는 작업 시간 제한이 없어, 느리지만 살아 있는 Authentik이 한 작업으로 워커를 수 분 잡으면 그동안 30 s 재적용이 돌지 못한다(B-3 · 〔Y16〕).
    - 재시도 대기 5 → 10 → 20 s 결정적, 3회(시도 4회)
    - 위임 창 = nbf + 300 s. 그 뒤에 시작된 시도는 버린다. 큐에 오래 묵은 위임이 그 사이 새로 로그인한 세션을 지우지 않게 한다(〔조사 E21 · E22〕). Dragonfly 5분 스냅숏은 Celery 큐도 되살리므로(비정상 종료 뒤 최대 5분 전 메시지가 다시 온다) 창이 그 재전달도 버린다(〔Y24〕).
- **본체**(반환 = `deleted` — 204로 지운 세션 수 · 〔W30〕)
  1. 쓰기 플래그가 거짓이거나 자격이 자리값이면 skip + 로그(D18 · 방어).
  2. 창을 지났으면 `authentik.revoke_expired`.
  3. `GET /api/v3/core/users/?uuid=<sub>`에서 uuid가 같은 결과가 정확히 1이어야 한다. 0이면 `revoke_user_missing`. `pk`는 정수(bool 제외) · `username`은 비지 않은 str이어야 한다.
  4. `GET /api/v3/core/authenticated_sessions/?user__username=<username>&page_size=100&page=<n>`를 돈다. 쪽 번호는 1부터 직접 세고 `pagination.next`가 0이면 멈춘다. 상한은 10쪽이다(`authentik.SESSION_PAGE_LIMIT` · 넘으면 그 시도는 `revoke_done truncated=true`로 끝낸다 — 응답의 `next` 값을 URL로 따라가지 않는다). 결과 중 `user == pk`인 세션만 남긴다. 필터가 무시돼도 남의 세션을 지우지 않게 한다(〔조사 E2〕).
  5. 각 세션에 `DELETE …/<uuid>/`. 204는 `deleted`, 404는 `gone`으로 **갈라 센다**(둘 다 그 세션의 처리를 끝낸다 — 재시도하지 않는다). 남의 세션 DELETE는 권한이 없을 때도 404라(사실 ⑭), 둘을 한 수로 세면 삭제 권한이 빠진 채로도 「지웠다」로 보인다(검토 C-10 · 〔W30〕). 경로에 넣는 `uuid`는 응답에서 온 값이라 UUID 꼴을 확인한 뒤 조립한다(아니면 그 항목을 건너뛴다 — D20 · 〔Y20〕).
  6. INFO `authentik.revoke_done`(필드 `deleted` · `gone` · `truncated`). 작업의 반환값은 `deleted`다.
  - 429 · 5xx · 시간 초과 · 연결 오류 · 마감 초과만 재시도한다(`AuthentikTransient`). 401 · 403 · 그 밖 4xx는 WARNING `authentik.revoke_failed status=<코드>`를 남기고 끝낸다(설정 오류 — 〔조사 E6〕).
  - bulk_delete는 쓰지 않는다. 8.0 버그가 있고, 단건 DELETE는 판에 무관하다(〔조사 E3〕).
- **위임 조건**
  - 사용자 단위(`/sessions/revoke`의 all_devices 참 · 관리 명령 `revoke_sessions` — 명령은 사용자 단위뿐이다 · 〔W13〕)일 때만 · 쓰기 플래그 참 · 자격이 자리값이 아님 · 같은 콜백의 SET이 `unreachable`이 아님(D12 ④ · 〔Y18〕).
  - sid 단위는 위임하지 않는다. Authentik이 sid로 세션을 찾을 수 없다(〔조사 E9〕). 웹훅 · 대조 백필도 위임하지 않는다(출처가 Authentik이다).
- **enqueue 꼴**(커밋 뒤 콜백 — `revocation.py` · 〔Y12 · Y16 · Y20 · W22〕)
  ```python
  from identity_admin.celery import app  # 콜백의 위임 단계 안 — 모듈 머리에서 가져오지 않는다

  app.send_task(
      "identity_admin.tasks.revoke_authentik_sessions",
      args=(sub, nbf),
      expires=datetime.fromtimestamp(nbf + 300, UTC),
      retry_policy={"max_retries": 0},
      argsrepr="(<redacted>)",
  )
  ```
  - **Celery 앱을 가져오는 자리**(〔W22〕): `app`은 커밋 뒤 콜백의 위임 단계 **안에서** `from identity_admin.celery import app`로 가져온다. `revocation.py`(와 그것을 가져오는 `identity_api.py`)의 모듈 머리에서 가져오지 않는다 — urlconf → `api` → `identity_api` → `revocation` 사슬은 migrate 프로필에서도 import되고, 템플릿 소유 시험 둘이 그 프로필에서 `"celery" in sys.modules`가 거짓임을 고정한다(사실 ⑧). 그 시험이 깨지면 기대값이 아니라 이 import 자리를 고친다(D3 (나)).
  - 이름으로 보낸다(`apply_async`와 같은 옵션이다). 요청 경로가 `jobs.py`를 import하지 않아 web 프로세스에 작업 모듈과 `beat_init` 수신자가 실리지 않고, 조각 ③-b1 · ③-b2가 조각 ⑤-b의 작업 본체에 기대지 않는다(설계자 결정).
  - `retry_policy`의 `max_retries` 0: 닫힌 포트 브로커에서 실패까지 약 2 s다(`retry=False`는 4 s 경로 — 〔T27〕). BFF의 pod fetch 3 s 안에 202가 나가야 한다 — 합격선은 「브로커가 닫힌 포트일 때 revoke 요청이 202까지 3 s 미만」이다(VD-T073-6 ①). 〔W25〕
    - 연결은 되고 응답이 없는 브로커에서는 전송 옵션 `socket_timeout` 5 s라 이 값으로도 3 s를 넘는다(사실 ⑧ — 합격선 밖 · 잰 값은 기록만 한다). 그 경우의 통과 근거는 운영 구성이다 — 브로커가 거부 목록과 같은 Dragonfly라 커밋 뒤 SET이 먼저 `unreachable`(0.2 s)이 되어 D12 ④가 enqueue를 건너뛴다(VD-T073-6 ③ · 계약 C9에 이 전제를 단다).
    - `max_retries` 0이면 브로커 재기동 뒤 풀에 남은 죽은 연결에서 첫 enqueue가 재접속 없이 실패할 수 있다(사실 ⑧). VD-T073-6 ④가 0과 1을 둘 다 재서 보고한다. **값의 결정은 컨트롤러가 한다** — 기본은 0 유지이고, 빌더는 ia-11과 계약 C9를 바꾸지 않는다(0을 지킬 때의 누락 가능성은 §9).
    - 시험 Celery의 브로커는 래퍼 자리값(닫힌 포트)이라 `DRAGONFLY_URL`과 따로다 — 그래서 거부 목록 조회와 SET은 되고 enqueue만 실패하는 api-19의 상황이 선다(운영은 둘이 같은 Dragonfly라 대개 미들웨어가 먼저 503을 낸다).
  - `expires`는 위임 창의 절대 시각이다. 묵은 위임과 스냅숏에서 되살아난 메시지를 워커가 실행 없이 버린다(본체 2단계는 같은 창의 둘째 방어다).
  - `argsrepr`: 워커의 수신 · 이벤트 표시에 `sub`가 실리지 않게 가린다.
  - 실패하면 WARNING `authentik.revoke_enqueue_failed error=<클래스>`만 남긴다(api-19 ⑫). 다시 보내는 주체는 없다 — 그 폐기의 Authentik 세션 삭제는 빠진다(§9 · 〔E12〕 — 30 s 재적용이 최근 사용자 단위 행의 위임을 다시 내는 안은 채택하지 않았다).
- **계약**: C4 · C7 · C9 〔편차 6〕.
- **시험**
  - api-19
  - **ia-11**(`identity_admin.celery.app`의 `send_task` 속성을 덮어 센다 — 콜백이 호출 때마다 앱을 가져와 속성으로 부르므로 덮은 것이 불린다 · 〔W22〕. 「0회」 사례보다 먼저 같은 가로채기로 「사용자 단위 + 쓰기 켬 → 1회」를 단언한다 — D26 「이음매」): 쓰기 끔 → 0 · 자리값 자격 → 0 · sid 단위 → 0 · 웹훅 → 0 · 사용자 단위 + 쓰기 켬 → 1회이고 이름이 글자 그대로 `identity_admin.tasks.revoke_authentik_sessions` · 옵션이 위 꼴(`expires` = nbf + 300의 UTC 시각 · `retry_policy` `max_retries` 0 · `argsrepr`에 sub 없음) · SET이 `unreachable`(DRAGONFLY_URL 닫힌 포트 — `record_revocation`을 직접 부른다) → 0이고 `authentik.revoke_skipped reason=denylist_unreachable`
  - **ia-12**(가짜 확장 — 작업은 `app.loader.import_default_modules()` 뒤 `app.tasks["identity_admin.tasks.revoke_authentik_sessions"]`로 찾는다: 이름으로 보내는 enqueue와 등록 이름이 어긋나면 ia-11이나 이 시험이 글자 그대로 잡는다): 대상만 삭제(반환 `deleted` = 지운 수) · 필터 무시 미끼 · DELETE가 404인 세션 → 실패가 아니고 `deleted == 0` · `gone == 1`(로그 `authentik.revoke_done`의 필드로 단언 · 〔W30〕) · 5xx 두 번 뒤 성공(eager apply는 바로 재시도 — 〔조사 E21〕) · 403이면 중단 · 창 지남 · 쓰기 끔 · 자리값 · 마감 0 s(`jobs.DELEGATION_DEADLINE_S`를 0으로 덮는다) → 일시 오류(호출 0) · `next`가 끝나지 않는 가짜 → 10쪽에서 멈춤 · UUID 꼴이 아닌 세션 `uuid` → DELETE 0 · 반환값이 정수
- **변이**: `user == pk` 확인 삭제 → ia-12 미끼. 창 검사 삭제 → ia-12. `expires` 삭제 → ia-11. 쪽 상한 삭제 → ia-12(시험 시간 상한). 404를 `deleted`로 셈 → ia-12. Celery 앱을 모듈 머리에서 가져옴 → 템플릿 migrate 프로필 시험 둘(D3 (나) — 생성물 기본 시험).

### D17 reconcile_authentik_sessions

- **확정**(사용자 2026-11-12 「이벤트 대조 구현」 · 〔E8〕): Authentik logout 이벤트를 72시간 창으로 읽어, 웹훅으로 받지 못한 것을 이벤트 시각 기준으로 기록한다.
- **알고리즘**(한 번 실행의 전체 마감 120 s — `jobs.RECONCILE_DEADLINE_S` · `outbound.Deadline` · 〔Y16〕 · 상수 이름은 D26 · 〔W29〕)
  1. 자격이 자리값이면 호출 0(D18).
  2. `GET /api/v3/events/events/?actions=logout&ordering=-created&page_size=100&page=<n>`를 돈다. 쪽 번호는 1부터 직접 세고 `pagination.next`가 0이면 멈춘다. 상한은 50쪽이고(`authentik.EVENT_PAGE_LIMIT`), 닿으면 WARNING `authentik.reconcile_truncated`를 남긴다.
     - **정렬에 기대어 일찍 멈추지 않는다**: 창 밖 이벤트를 만나도 그 쪽과 뒤 쪽을 계속 본다. 정렬 인자가 무시되거나 정렬 필드가 바뀌어도 창 안 이벤트를 놓치지 않는다. SP-1 규모에서 보존 기간(90일)의 logout 이벤트는 50쪽 안이다(추론 — 넘으면 위 WARNING이 알린다). 〔Y17〕
  3. 받은 이벤트마다 **클라이언트 쪽에서 다시 확인**한다(하나라도 아니면 그 이벤트를 건너뛴다 · 〔Y17〕). 서버 필터가 무시되면(모르는 질의 키는 오류 없이 전체 목록이 온다) 토큰 교환마다 생기는 login 이벤트가 섞여 오기 때문이다 — 그것이 폐기로 기록되면 그 시각 활성 사용자 전원에게 30일 하한이 걸린다(B-4).
     - `action`이 정확히 `"logout"`
     - `created`가 tz 있는 ISO 8601로 읽히고 `now − 72 h ≤ created ≤ now + 300 s`(워커 시계 · 창 72 h = `jobs.RECONCILE_WINDOW`). 이 위쪽 끝으로 7단계의 `nbf = ⌊created⌋ + 1 ≤ now + 301`이 구성상 성립한다(〔W14〕).
     - `user.pk`가 정수(bool 제외)
     - 이벤트 `pk`가 str이고 정규형(D12)으로 바꾼 값이 출력 가능 ASCII 1–255자
  4. `revocation.event_already_recorded(pk)`면 건너뛴다(사용자 조회 앞 — 평소에는 추가 호출이 0이다).
  5. `GET …/core/users/<pk>/`로 uuid(= sub)를 얻는다. Event.user에는 uuid가 없다(〔조사 E13〕). 같은 실행 안에서는 pk → uuid를 캐시한다. 404면 그 이벤트를 건너뛴다(지워진 사용자 — `view_user`가 없는 계정도 이 꼴일 수 있다). 401 · 403이면 아래 「실패」의 갈래로 끝난다(〔W2〕). 그 밖의 4xx · `malformed` · `too_large`는 이벤트 조회의 그 밖 실패와 같은 갈래다(WARNING `authentik.reconcile_failed` 뒤 끝난다 — 마감 확인 제안). uuid는 UUID 꼴이어야 한다.
  6. 멤버십이 없으면 건너뛴다. 여럿이면 D12 규칙.
  7. `record_revocation(reason="authentik_webhook", sid=None, event_pk=<정규형 pk>, nbf=⌊created⌋ + 1, delegate=False, source="reconcile")`. 이 경로에는 `nbf` 상한 비교가 따로 없다 — 3단계의 재확인이 이미 막는다(〔W14〕 — 앞 라운드에 있던 「관문이 거부하면 건너뛰고 WARNING」 갈래와 그 reason은 없앴다). 관문에 `source == "reconcile"` 비교를 다시 넣지는 않는다(같은 워커 시계로 같은 것을 두 번 보는 일이다). 그래서 3단계의 「창 위쪽 끝」이 이 경로의 유일한 방어다 — ia-13의 미래 이벤트 미끼와 변이가 지킨다(〔Z3〕).
  8. 끝에 INFO `authentik.reconcile_done seen=n recorded=m skipped=k pages=p`. 반환 = `{seen, recorded, skipped}`. 한 실행에서 사용자 조회를 한 pk가 1개 이상이고 그 전부가 404였으면 끝에 WARNING `authentik.reconcile_skipped reason=user_lookup count=<n>` 한 줄도 남긴다(n = 그 pk 수 — 권한 없음이 조용한 0건으로 끝나지 않게 · 〔W2〕).
  - event_pk 대조로 멱등이다. 창이 72 h라 하루 실패해도 다음 이틀이 다시 본다(행 보존은 30 d다).
  - 웹훅과 백필이 같은 꼴의 pk를 쓰는지는 VD-T081-1이 보고, 어긋나도 UUID로 읽히면 정규형이 한 행으로 모은다.
- **백필 행의 효과**(〔E8〕): 이벤트 시각이 `nbf`라 대개 `revoked:sub`의 TTL이 지나 쓰이지 않고(D13의 TTL < 1 생략) 세션 하한 키만 남는다 — 남은 수명은 약 27–30일이다. 그래서 창 밖으로 늦은 Authentik 로그아웃도 폐기 전에 시작한 BFF 세션을 끝낸다(D29). 이벤트 시각을 쓰므로 그 뒤에 다시 로그인한 세션은 죽이지 않는다. 기록(로그 · Kafka 이벤트 — FR-024)의 완전성도 채운다.
- **왜 세션 목록과 대조하지 않는가**: 세션 목록에는 sid도 삭제 흔적도 없어 무엇을 보정할지 끌어낼 수 없다(〔조사 E32 · S22〕).
- **실패**
  - 일시 오류(429 · 5xx · 시간 초과 · 연결 · 마감 초과): 첫 번째에서 멈춘다. WARNING `authentik.reconcile_failed error=<종류>` · 이미 기록한 행은 남는다 · 다음 날 다시 돈다(재시도 없음). 〔Y16〕
  - 이벤트 조회의 그 밖 실패(〔Z13〕): 그 밖의 4xx(401 · 403은 아래 갈래) · `malformed` · `too_large` · `scheme` → WARNING `authentik.reconcile_failed` 뒤 끝난다(재시도 없음). 사용자 조회의 「404 = 건너뜀」을 이벤트 조회에 옮기지 않는다 — 경로나 판이 바뀌어 이벤트 조회가 404인데 조용히 끝나면 유실 웹훅이 메워지지 않은 채 아무도 모른다(재검토 RB-9).
  - **권한이 없을 때**(〔W2〕 — 응답 꼴을 단정하지 않는다: 소스 판독 기준이고 실측은 T081 · VD-T081-2다. 아래 세 꼴 모두에서 동작이 안전하다)
    - 이벤트 조회가 401 · 403: WARNING `authentik.reconcile_forbidden status=<코드>` 한 줄 뒤 끝난다(다음 날 다시).
    - 이벤트 조회가 오류 없이 빈 목록: `authentik.reconcile_done seen=0`으로 끝난다. 서비스 계정의 형이 internal service account면 권한이 없어도 이 꼴이고 「로그아웃이 없었다」와 구별되지 않는다(소스 판독 — `rbac/filters.py` · 사실 ⑭).
    - 사용자 조회(5단계): 404 → 그 이벤트를 건너뛴다. 401 · 403 → 이벤트 조회의 401 · 403과 같은 갈래다(WARNING `authentik.reconcile_forbidden` 뒤 끝난다 · 이미 기록한 행은 남는다).
    - 조용한 0건을 드러내는 한 줄: 한 실행에서 사용자 조회를 한 pk가 1개 이상이고 그 전부가 404였으면 끝에 WARNING `authentik.reconcile_skipped reason=user_lookup count=<n>`(8단계).
- **권한과 dev**(〔E8 · Y7 · W2〕): `view_event` · `view_user`가 필요하다. 부여는 T081(UD-2 본체)에서 확정한다. 코드에는 env별 플래그를 두지 않는다 — 권한이 없으면 위 「권한이 없을 때」의 갈래로 끝난다. dev 수행 여부도 권한 부여를 따른다(계약의 dev 계정은 「사용자 read만」이라 기본으로는 dev에서 하루 한 줄 WARNING이 남거나, 계정 형에 따라 `seen=0`으로 경고 없이 끝난다). 이 작업은 Authentik에 쓰지 않으므로 `AUTHENTIK_WRITES_ENABLED`와 무관하다(C7 dev 각주 정정 · 〔편차 28〕).
- **logout 이벤트의 원천**(〔E8 · ATK-7〕): 세션 결속이 깨져 생긴 logout 이벤트를 거를지는 T081 매핑이 정한다. T073 기본은 거르지 않는다(fail-safe — 웹훅도 같은 이벤트를 폐기로 받는다). T081이 거르기로 정하면 3단계의 재확인에 같은 조건을 더하는 코드 변경이 그 과제의 범위다(§7).
- **계약**: C7 · C27 〔편차 7〕.
- **시험**
  - api-33(등록)
  - **ia-13**(가짜 확장 · 〔Y17〕)
    - 누락 logout → 행 1 · outbox 1 · `event_pk` = 정규형 · `nbf` = ⌊created⌋ + 1 / 이미 있는 pk → 무변화(사용자 조회 0) / 멤버십 없음 → 건너뜀
    - 미끼(필터 무시 모드 — 가짜가 질의를 무시하고 전부 준다): login 이벤트 · 창 밖(73 h 전) 이벤트 · user 없는 이벤트 · pk가 정수인 이벤트 → 모두 행 0. 정렬을 뒤섞어도(창 밖 이벤트가 먼저) 창 안 누락 logout은 기록된다
    - 창 위쪽 끝의 미끼(미래 이벤트 · 〔Z3〕 — 3단계의 위쪽 끝이 이 경로에서 미래 `nbf`를 막는 유일한 방어다): `created` = 지금 + 600 s · 지금 + 1 h인 logout 이벤트 → 행 0 · outbox 0 · 키 0 / 경계 `created` = 지금 + 290 s → 기록(`nbf` = ⌊created⌋ + 1). 「+ 301 s」처럼 처리 지연 1 s에 판정이 뒤집히는 값은 쓰지 않는다
    - 쪽: 둘째 쪽의 누락 logout도 기록 · `next`가 끝나지 않는 가짜 → 50쪽에서 멈추고 `reconcile_truncated`
    - hex 32자 pk 이벤트와 같은 UUID의 대시 꼴 웹훅 행 → 한 행(무변화)
    - 자리값 → 호출 0 · 이벤트 조회 403 → 행 0이고 `reconcile_forbidden` · 이벤트 조회 404 → 행 0이고 `reconcile_failed`(건너뜀으로 조용히 끝나지 않는다 · 〔Z13〕) · 5xx → 그 자리에서 멈춤(뒤 쪽 호출 0) · 마감 0 s(`jobs.RECONCILE_DEADLINE_S`를 0으로 덮는다) → 호출 0
    - 같은 사용자의 이벤트 둘 → 사용자 조회 1회(캐시)
    - 사용자 조회의 권한 없음(〔W2〕): 두 사용자 모두 사용자 조회 404 → 행 0이고 끝에 `reconcile_skipped reason=user_lookup` 한 줄(`count` 2) / 둘 가운데 하나만 404 → 그 줄 없음(다른 하나는 기록된다) / 사용자 조회 403 → `reconcile_forbidden`이고 뒤 호출 0
- **변이**: `action` 확인 삭제 → ia-13(login 미끼). 창 확인 삭제 → ia-13(73 h 전 미끼 — 아래쪽 끝). 창의 위쪽 끝(`created ≤ now + 300 s`) 확인 삭제 → ia-13(미래 이벤트 미끼 · 〔Z3〕). 창 밖 이벤트에서 멈춤 → ia-13(뒤섞인 정렬). 사용자 조회 403을 건너뜀으로 접음 → ia-13(뒤 호출이 이어진다). 전부 404일 때의 경고 삭제 → ia-13. 이벤트 조회의 그 밖 4xx를 건너뜀으로 접음 → ia-13(이벤트 조회 404 사례 · 〔Z13〕).

### D18 자리값 자격 · 쓰기 플래그

- **무엇**: 호출 전에 자격 값에 `conf.PLACEHOLDER_MARK`가 있으면 그 외부 호출을 하지 않는다.
  - 위임(enqueue 시점과 작업 본체 둘 다) · reconcile: skip + WARNING `authentik.calls_disabled reason=placeholder_credential`.
  - seed: `CommandError`(Authentik 토큰 · OpenFGA store id · preshared 키 어느 것이든 — `--authentik-token-stdin`을 주면 Authentik 쪽은 stdin 값으로 판정한다).
  - 웹훅 · /session/check · /tenants/me · 재적용 · `revoke_sessions`의 기록은 나가는 쪽 자격을 쓰지 않으므로 무관하다(`revoke_sessions`의 위임만 위 규칙을 따른다).
- **쓰기 플래그 `AUTHENTIK_WRITES_ENABLED`의 대상**: Authentik에 쓰는 호출 둘뿐이다 — 세션 삭제 위임(D16)과 `seed_tenant`의 소속 · attribute 쓰기(D19). 읽기(시드의 그룹 · 사용자 조회 · 일 1회 대조)는 플래그와 무관하게 한다. 계약의 「`reconcile_authentik_sessions` 보정」은 Authentik 쓰기가 아니라 자기 DB 기록이다(C8 정정).
- **왜**
  - US6 기간에는 kv가 T044 sentinel이다(dm:164 · docs/runbooks/vault-unseal.md:294-330).
  - 그 상태로 부르면 매일 실패하고, 위임마다 재시도 3회가 난다(bn:3233-3237 H1).
  - skip이면 prod 플래그를 계약대로 `true`로 둘 수 있다. T083이 실값을 넣는 순간 동작한다. H1의 「prod false → T083에서 켬」 편차가 필요 없다.
- **기각**: 플래그로 끄기 · 일 1회 실패 수용.
- **계약**: C8.
- **시험**: ia-11(enqueue 시점 — 자리값 · 쓰기 끔) · ia-12(작업 본체 — 자리값 · 쓰기 끔) · ia-13(대조 — 자리값) · ia-15(seed — 자리값) · api-38(seed — 쓰기 끔).
- **변이**(〔W34〕 — 적힌 시험의 사례와 T066 원문으로 확인)
  - 자리값 검사 삭제: enqueue 시점 → ia-11 · 작업 본체 → ia-12 · 대조 → ia-13 · seed → ia-15(seed의 자리값 사례는 이번에 ia-15에 더했다 — D19).
  - 쓰기 플래그 검사 삭제: enqueue 시점 → ia-11 · 작업 본체 → ia-12 · seed → api-38(변경 요청 0 단언 — test_api.py:1955-1970).
  - api-19는 이 변이들을 잡지 못한다 — 시험 브로커가 닫힌 포트라 enqueue가 실패하고 가짜 Authentik에 요청이 닿지 않는다(그래서 위임 쪽은 `send_task`를 덮어 세는 ia-11이 맡는다).

### D19 seed_tenant

1. **인자**
   - `--tenant-id`: UUID를 소문자 정규형으로 바꾼다. v7이 아니면 CommandError.
   - `--owner-sub` · `--member-sub`: 출력 가능 ASCII(`!`–`~`) 1–255자(〔Y21〕). 같으면 CommandError.
   - 선택 `--authentik-token-stdin`(UD-2): stdin 한 줄, 끝 CR/LF만 뗀다. 비어 있거나 출력 불가 ASCII가 섞이면 CommandError. `call_command`용 `stealth_options = ("stdin",)`. 주면 이 실행의 Authentik 호출은 모두 그 토큰을 쓴다(설정의 장기 토큰을 쓰지 않는다).
   - slug · display_name은 상수다(dm:22).
2. 자리값 자격 검사(D18).
3. **그룹 조회**(읽기 — DB 단계 **앞**에서 한 번 · 플래그와 무관 — api-40 · 〔Y19〕)
   - `?name=tenant:<uuid>`에서 이름이 정확히 같은 결과가 정확히 1이어야 한다. 0이면 CommandError이고 그룹을 만들지 않으며 **DB를 쓰지 않는다**.
   - 오타가 난 `--tenant-id`(v7 꼴)로 한 번 돌았을 때 틀린 id의 Tenant 행(slug `joshuatech`)이 남아 올바른 재실행이 slug 충돌로 막히는 교착을 없앤다 — 그 UUID의 그룹은 blueprint에 없다(B-7). api-41의 「변경 요청 0」과 api-56의 「DB 행 유지」는 그대로다(그룹 조회는 GET이고 사용자 조회는 5단계다).
4. **DB 단계**(atomic 하나)
   - id가 있으면 slug가 `joshuatech`이어야 한다. id가 없으면 slug가 다른 id로 있는지 먼저 본다(api-41 — 파생 쓰기 0). 둘 다 아니면 생성한다.
   - slug 경합 IntegrityError는 메시지 없는 CommandError로 바꾼다.
   - 기존 Tenant의 display_name · status는 건드리지 않는다.
   - 멤버십 둘: 없으면 생성한다. 이미 있는데 role이 인자와 다르면 **CommandError**다(atomic이 롤백해 그 실행의 DB 쓰기가 0이다 · 〔Y19〕). SP-1에는 역할을 바꾸는 경로가 필요 없고, owner였던 sub를 member로 내리면 OpenFGA에 owner 튜플이 남아 정본과 파생이 어긋난다(B-7). dm:13의 「이미 있으면 갱신만」은 「행을 다시 만들지 않는다」로 읽는다(C22).
5. **사용자 조회**(읽기 — 플래그와 무관 — api-56)
   - `?uuid=<sub>`에서 uuid가 정확히 같은 결과가 정확히 1이어야 한다. 0이면 CommandError(DB 행은 남는다).
   - 필터가 무시돼도 미끼를 고르지 않는다(〔조사 E5〕 · api-36).
6. **Authentik 판정과 쓰기**
   - 사용자마다 두 항목을 본다: 소속(사용자 `groups`에 그룹 pk가 있는가) · attribute(`tenant_id`가 이 테넌트인가).
   - `tenant_id`가 다른 값으로 이미 있으면 **쓰기 플래그와 무관하게** CommandError다. 사용자를 조용히 다른 테넌트로 옮기지 않는다(공백 → 설계 · 〔Y19〕).
   - 플래그 참: 소속이 없을 때만 `add_user {pk}`, `tenant_id`가 없을 때만 「기존 사전 + tenant_id」 전체를 PATCH한다. 이미 같으면 쓰기 0(api-37).
   - 플래그 거짓: 쓰지 않는다. 어긋난 항목 수(사용자 2 × 항목 2 = 0–4)를 세어 출력의 `drift`에 싣는다 — dev 시드가 「prod 시드가 아직 쓰지 않았다」를 조용히 지나치지 않는다(〔Y19〕). 추가 호출은 없다(3 · 5단계에서 읽은 값으로 견준다).
7. **OpenFGA**(dev도 쓴다)
   - `write {tuple_keys: [owner, member], on_duplicate: "ignore"}` 한 번(〔조사 E18〕 · api-37 셋째).
   - 그 밖의 4xx · 5xx는 상태 코드만 담은 CommandError(api-39). 판정은 쓰기 응답으로만 한다(G14).
8. **출력**: `seed_tenant:`로 시작하는 줄 하나 `seed_tenant: OK tenant=<uuid> memberships=created:<n>/unchanged:<n> authentik=written|unchanged|skipped(drift=<n>) fga=ok`. sub · 토큰 · URL은 없다(api-36). 실제 실행에서는 같은 stdout에 `configure_logging`의 JSON 로그 줄이 섞이므로 읽는 쪽은 접두로 그 줄을 찾는다(`revoke_sessions`와 같다 — D30 · 마감 확인 제안).

- 순서는 그룹 조회(읽기) → DB → 파생이다. 파생이 실패해도 DB 행은 남고, 재실행이 마저 쓴다(dm:23).
- **실행 자격**: runtime 프로필 · app role. B 등급이고 런타임 설정이 필요하며, T066이 default 별칭으로 부른다. migrate 프로필에는 런타임 키가 없다(pt:84).
- **운영 실행**: `kubectl -n jt-<env> exec deploy/identity-admin -c web -- python manage.py seed_tenant …`
  - `--authentik-token-stdin`은 구현해 두고 기본은 끈다. UD-2(T081 전)가 「prod 시드는 운영자 만료 토큰」으로 정해지면 prod는 `kubectl exec -i`로 토큰을 stdin에 파이프한다 — 코드는 어느 답이든 같다.
  - prod를 먼저 돈다(Authentik attribute는 prod 시드만 쓴다 — dev 시드가 먼저면 `drift`가 0이 아니다 · T114).
  - Job은 두지 않는다.
- 이벤트는 0이다(tenant.created는 SP-2). platform-admin도 0이다(UD-3).
- **고정 테넌트 UUID**: 코드에 넣지 않고 인자로만 받는다. 정본 = dm §1 「SP-1 고정 테넌트」 줄(C21).
  - 값은 설계 커밋 때 컨트롤러가 `uuidv7()`로 한 번 만들고, 이후 바꾸지 않는다.
  - T081 그룹 이름 · T083 인자 · T085 단언이 이 값을 읽는다.
- **계약**: C17 · C21 · C22 · C25 〔편차 4 · 5〕.
- **시험**
  - api-36–41 · 56
  - **ia-14**: stdin 토큰으로만 인증하고 설정 토큰은 쓰지 않는다. 출력에 토큰이 없다.
  - **ia-15**: 맨 앞에 `get_commands()`에 `seed_tenant`가 있음을 단언한다(〔Z7〕 — 명령이 없어도 `call_command`는 `CommandError`라 아래 사례가 구현 전에 초록이 된다 · T066 `_seed()`와 같은 방식) / owner == member · v4 tenant-id · sub에 NUL · 256자 → CommandError이고 요청 0 / 자리값 자격(Authentik 토큰 · OpenFGA store id · preshared 키 각각 — `conf.PLACEHOLDER_MARK`가 든 값) → CommandError이고 요청 0 · DB 행 0(D18 · 〔W34〕) / store id에 `/` · `?` · 공백 → OpenFGA 호출 0 · CommandError(D20 · 〔W5〕) / attribute 충돌(다른 `tenant_id`)은 쓰기 켬 · 끔 둘 다 CommandError이고 Authentik 쓰기 0 / 그룹 없음 → DB 행 0(Tenant · 멤버십이 생기지 않는다) 〔Y19 · Y21〕
  - **ia-16**: 맨 앞에 같은 명령 존재 단언을 둔다(〔Z7〕) / 기존 멤버십의 role이 인자와 다름 → CommandError · DB 무변화 · OpenFGA 쓰기 0 / 출력 셈(첫 실행 `created:2/unchanged:0` · 재실행 `created:0/unchanged:2` · `authentik=unchanged`) / 쓰기 끔에서 소속 · attribute가 없는 상태 → `authentik=skipped(drift=4)`, 다 있는 상태 → `skipped(drift=0)` 〔Y19〕
- **변이**
  - 필터 없이 첫 결과를 쓴다 → api-36
  - 쓰기 끔에서 조회를 건너뛴다 → api-40 writes-off
  - ignore 없이 일괄 쓴다 → api-37
  - 그룹 조회를 DB 뒤로 → ia-15(그룹 없음에서 DB 행이 남는다)
  - 역할 불일치를 갱신으로 → ia-16
  - 자리값 자격 검사(2단계) 삭제 → ia-15(D18)
  - store id 꼴 검사 삭제 → ia-15(D20 · 〔W5〕)

### D20 외부 HTTP 클라이언트 · Authentik 포트

- **`outbound.request_json(method, url, *, token, body=None, deadline=None)`**(stdlib · 〔Y20 · Y16〕)
  - **opener**: `OpenerDirector`를 직접 짓고 HTTP · HTTPS 핸들러와 오류 처리기만 단다. `build_opener`가 기본으로 다는 file · ftp · data 핸들러 · 프록시 핸들러 · 리디렉션 핸들러를 싣지 않는다 — 프록시 env를 무시하고, 3xx는 오류가 된다. urllib 기본 리디렉션은 Authorization을 다른 호스트로 다시 보낸다(추론 · bff:50과 같은 원칙).
  - **스킴**: 호출 시점에 http · https만 받는다(그 밖은 호출 0 · `UpstreamUnavailable("scheme")`). 시험은 설정을 실행 중에 바꾸므로 기동 검사(D6)만으로는 모자란다.
  - **URL 조립**: 질의는 `urlencode`로 만든다(`http.client`는 제어 문자가 든 경로를 `InvalidURL`로 거부하면서 원문 질의를 문구에 싣는다 — 사실 ㉙). 경로 성분은 UUID나 정수 꼴을 확인한 뒤 넣는다 — 응답에서 온 값(세션 `uuid` · 사용자 `pk` · 그룹 `pk`)도 같다. 설정에서 오는 경로 성분은 `OPENFGA_STORE_ID` 하나이고 UUID · 정수 꼴이 아니다(운영 ULID 26자 · T066 가짜 `01` + Crockford 24자 · 래퍼 `test-openfga-store`) — 호출 시점에 `re.fullmatch(r"[A-Za-z0-9_-]{1,64}", …)`를 확인한 뒤 넣는다(아니면 호출 0 → `seed_tenant`는 `CommandError`). conf 교차 규칙으로는 올리지 않는다(호출 시점 검사만 · 〔W5〕).
  - **반환**(〔W29〕): 성공이면 디코드한 JSON 값을 돌려준다(빈 본문 — 204 등 — 은 None). 실패는 아래 오류 형으로 올린다.
  - 헤더: Bearer · `Accept` · 본문이 있으면 `Content-Type: application/json`(가짜 415) · `User-Agent: identity-admin/<APP_VERSION>`.
  - **시간**: 타임아웃 5 s(소켓 동작마다). `deadline`(`outbound.Deadline(seconds)` — 단조 시계)을 주면 호출 앞에서 남은 시간을 보고(0 이하면 호출 0 · `UpstreamUnavailable("deadline")`) 소켓 타임아웃을 `min(5, 남은 시간)`으로 두며, 응답을 64 KiB씩 읽는 사이에도 본다. 한 작업이 끝없이 워커를 잡지 못한다.
  - **크기**: 응답이 1 MiB를 넘으면 실패다(`UpstreamUnavailable("too_large")` — 일시 오류가 아니다: 다시 해도 같다).
  - **오류 형**: `UpstreamStatus(status)` · `UpstreamUnavailable(kind)`. `.transient`는 429 · 5xx와 연결 · 시간 초과 · 마감일 때만 참이다(`scheme` · `too_large` · `malformed`(JSON이 아니거나 꼴이 계약 밖)는 거짓). 메시지에는 상태 코드와 종류만 담는다. URL · 쿼리(사용자 uuid) · 토큰 · 본문은 담지 않는다.
  - **연쇄 끊기**: 예외는 `raise … from None`으로 올린다. Celery 실패 로그와 Django robust 로그는 연쇄 예외까지 찍는다(B-8).
  - import 시점에 객체 · 연결 0(〔T19〕).
- **`authentik.py`**
  - base = 호출 시점의 `settings.AUTHENTIK_API_URL.rstrip("/")` + `/api/v3/…/`(끝 슬래시).
  - 메서드(모두 선택 인자 `deadline` · `token`): `find_group` · `find_user` · `get_user` · `add_user` · `patch_attributes` · `list_sessions` · `delete_session` · `list_logout_events`.
  - 목록 메서드는 쪽 번호를 직접 세고 상한을 받는다(세션 `authentik.SESSION_PAGE_LIMIT` = 10 · 이벤트 `authentik.EVENT_PAGE_LIMIT` = 50 — 이름은 D26 · 〔W29〕). 응답의 `pagination.next`는 「더 있는가」로만 쓴다.
  - `list_sessions`는 응답의 `user`가 그 사용자 pk인 세션만 돌려주고(필터 무시 미끼를 여기서 거른다), `delete_session`은 204와 404를 갈라 알린다(`deleted` · `gone` — D16 · 〔W30〕). 꼴이 아닌 pk · uuid는 호출하지 않고 건너뛴다.
- **`openfga.py`**: `write_tuples`(5 s · 재시도 없음).
- 401 · 403은 재시도하지 않는다(〔조사 E6〕).
- 클러스터 안 Authentik · OpenFGA 호출은 평문 HTTP다(계약 고정 — svc DNS). 토큰 · preshared 키의 전송 보호는 노드 간 암호화(WireGuard)에 기댄다(§9 · 〔Y24〕).
- **포트**
  - 기본 URL `:9000`을 유지한다(api-48 고정).
  - 차트 기본 Service 포트는 80이므로 T080이 `server.service.servicePortHttp: 9000`을 둔다(〔조사 E17〕 · VD-T080-1).
  - NetworkPolicy는 pod 포트 9000이라 그대로다(network-policy.md:88).
- **기각**
  - requests · httpx 직접 의존: pyproject 손 수정 + 재잠금 + 공급망 부담(〔P28〕).
  - openfga-sdk: aiohttp 의존 트리 · 숨은 재시도 3회(〔조사 E20〕).
- **시험**: api-36–41 · 56 · **ia-22**(`outbound.request_json` — 가짜는 `_ia_fakes`의 원시 HTTP 서버다: 302 + Location · JSON이 아닌 200 · 느린 조각은 T066 `FakeAuthentik`의 핸들러로 만들 수 없다 · D26 · 〔W27〕) · **ia-41**(`authentik.py` 메서드 단위 · 〔W28〕)
  - 302 → 오류이고 대상 호스트가 받은 요청 0(Authorization이 따라가지 않는다) · 프록시 env를 둬도 직접 간다
  - 블랙홀 → 5 s대 오류 · 마감을 준 느린 가짜(조각 사이 지연) → 마감에서 끊긴다 · 마감 0 s → 호출 0
  - `file://` · `ftp://` 스킴 → 호출 0 오류
  - 질의 값에 `&` · `#` · `%` · 공백이 있어도 가짜가 받은 값이 원문과 같다(urlencode) · 꼴이 아닌 경로 성분 → 호출 0
  - 1 MiB 초과 응답 → 실패(`transient` 거짓) · JSON이 아닌 200 → `malformed`
  - 오류 문자열 위생: 예외 `str` · `repr`에 URL · 질의 값 · 토큰이 없다. `__cause__ is None`이고 `__suppress_context__`가 참이다
  - **ia-41**(조각 ④ — `authentik.py`의 메서드 여덟을 확장 가짜로 하나씩 부른다): 메서드마다 경로와 끝 슬래시 · 질의 인코딩(urlencode — 가짜가 받은 값이 원문과 같다) · 필터 무시 미끼 거르기(`list_sessions`의 `user == pk` · `find_group` · `find_user`의 정확 일치) · 쪽 상한(세션 10 · 이벤트 50 — `next`가 끝나지 않는 가짜) · 꼴이 아닌 pk · uuid 건너뜀(호출 0) · 반환 꼴(`delete_session`의 204 · 404 구분 포함). ia-22는 `outbound.request_json`만 보므로, 이 시험이 없으면 `authentik.py`를 처음 지나는 시험이 조각 ⑤-b(ia-12 · 13)와 ⑦(api-36–41 · ia-14–16)이 되어 조각 ④의 끝 조건이 산출의 절반을 검증하지 못한다(검토 C-7).
- **변이**: `from None` 삭제 → ia-22. opener를 `build_opener()`로 → ia-22(302 · 프록시 · file 스킴). 마감 확인 삭제 → ia-22. 목록 메서드의 쪽 상한 삭제 · `user == pk` 거르기 삭제 · 경로 성분 꼴 확인 삭제 → ia-41.

### D21 웹훅 송신 규약 · 창 · 모르는 sub · session_deleted

- 수신 쪽은 계약 그대로다(정규형 HMAC · 두 매핑 — api계약:61-67).
- **창 ±300 s 유지**
  - 폐기 대상 **access 토큰**은 iat < nbf(= created + 1)이다. 그런 토큰은 늦어도 created + 301 s(+ leeway 5 s)에 만료된다. 그래서 창 밖으로 늦게 배달된 웹훅이 막을 수 있는 access 토큰은 없다(〔조사 E15〕).
  - 이 근거는 access 토큰에만 참이다. **BFF 세션(쿠키의 refresh 토큰)은 창 밖에서도 살아 있다** — identity-admin이 5분 넘게 내려가 웹훅이 창 밖으로 밀리면 그 로그아웃은 웹훅으로는 기록되지 않는다(B-1 · 〔Y2〕). 그 유실분은 D17이 이벤트 시각 기준으로 기록하고, 그 행의 세션 하한이 폐기 전에 시작한 세션을 끝낸다(D29). D17이 돌 때까지(일 1회 — 길면 하루 남짓)는 그 폐기가 아직 집행되지 않는다. `view_event` 권한이 없어 대조가 돌지 못하면 그 유실분은 기록되지 않고, 세션 절대 수명 30일이 상한이다.
- **모르는 sub = 400 유지**(api-23 고정). 공유 Authentik 재시도 소음은 T081 Rule 설계로 줄인다(〔조사 E31〕). 멤버십이 없는 sub의 Authentik 로그아웃은 어느 경로로도 기록되지 않는다(대조도 건너뛴다 — SP-1 사용자는 둘 다 멤버십이 있다).
- **`session_deleted`**는 Authentik이 만들지 않는 값이다. 받아 두되 오지 않는다(〔조사 E14〕 · UD-4).
- **T081 매핑 규칙**(인계 · C27)
  - pk = `str(event.pk)` 대시 꼴(빠뜨려 hex 꼴이 와도 pod가 정규형으로 모은다 — D12)
  - created = `event.created.isoformat()`
  - **nbf = `floor(created) + 1` — 필수**. 빠지면 pod는 수신 시각 + 1을 쓰고(api-25 고정) 그 값이 30일 하한이 된다 — 재시도 지연 동안 새로 로그인한 세션이 죽는다(닫힌 쪽). pod는 WARNING `webhook.nbf_missing`으로 드러낸다(〔E7〕 · VD-T081-1). `nbf`를 `⌊created⌋ + 1`보다 크게 실으면 pod가 그 값으로 낮춰 기록하고 WARNING `webhook.nbf_clamped`를 남긴다(거부하지 않는다 — D10 4단계 · 〔Z8〕).
  - sub = 이벤트 사용자 UUID
  - JSON 기본형만(리스트 · float 금지)
  - Rule = logout만(login 폭주 · `model_deleted(session)`은 생기지 않음 — A15)
  - 같은 이벤트를 여러 번 보내지 않게 send_once 또는 event user만(〔조사 E11–E15〕)
  - logout 이벤트의 원천: 세션 결속이 깨져 생긴 logout(context `logout_reason`)을 거를지 T081이 정한다. 기본은 거르지 않는다 — 한 기기의 망 전환이 그 사용자의 전 기기 세션 종료가 된다(결속 기본값은 꺼짐). 거르면 D17도 같은 조건을 쓴다(〔E8 · ATK-7〕).
- **계약**: C5 · C27.

### D22 이벤트

- **owns_events = [session.revoked]** 〔편차 2〕
  - OWNED_EVENTS가 publish_owned의 관문이다. 생성 README 규칙은 「목록 = 스키마 · KafkaTopic · ACL 한 묶음」이다.
  - SP-1에는 SP-2 토픽 둘의 KafkaTopic이 없다. 목록에 두면 발행 실수가 토픽 없음 → 10회 실패 → DLQ로만 드러난다(⑳ · 〔L18〕).
  - SP-2가 스키마 · KafkaTopic과 함께 답을 고치고 다시 생성한다.
- **데이터**: data 키 정확히 4 · nbf는 int. 발행 경로는 넷이다 — revoke · 웹훅 · 대조 백필 · 관리 명령(모두 `record_revocation` — D12).
- **스키마 대조 시험**(ia-17)
  - outbox data가 `packages/events/schemas/identity-admin.session.revoked.json`을 만족하는지 본다.
  - 시험 안에 작은 검사기를 둔다(type · minLength · minimum · enum · required). 새 의존은 0이다. 검사기가 모르는 검증 키워드를 스키마에서 만나면 실패한다 — 스키마가 넓어질 때 시험이 공허해지지 않는다(비판 A extra).
  - 생산하는 4 reason을 모두 넣는다(`logout` · `logout_all` · `admin` · `authentik_webhook`).
- **계약 표 정정**: C6.
- **기각**: owns_events 셋 · jsonschema dev 의존.
- **변이**(〔W34〕 — T066 원문으로 확인): data 키 추가 → api-10(`_assert_event`가 data를 네 키의 dict와 완전 일치로 본다 — test_api.py:413-419). reason 오타 → ia-17(스키마 enum · 생산하는 4 reason을 모두 넣는다 — 웹훅 쪽 리터럴은 api-20도 잡는다).

### D23 deploy/base · env.example · README

- **ES `identity-admin-env` data[8..11]** + template.data 4

| i | secretKey | remoteRef key · property | env |
|---|---|---|---|
| 8 | authentik_api_token | dev/authentik/identity-admin · api_token | AUTHENTIK_API_TOKEN |
| 9 | authentik_webhook_secret | dev/authentik/webhooks/identity-admin · secret | AUTHENTIK_WEBHOOK_SECRET |
| 10 | openfga_store_id | dev/openfga/store_id · store_id | OPENFGA_STORE_ID |
| 11 | openfga_preshared_key | dev/openfga/preshared · key | OPENFGA_PRESHARED_KEY |

- `client_id` · `client_secret`은 매핑하지 않는다. pod에 그 설정이 없으니 최소 노출로 간다(C26).
- **ConfigMap**
  - `AUTHENTIK_WRITES_ENABLED: "false"`
  - URL 둘은 두지 않는다. 포트가 바뀌면 overlay가 키를 더한다.
  - 자리값 이름 집합은 그대로 둔다(⑰).
- **env.example**: 필수 4 + 선택 3(키만).
- **README 「identity-admin」 절**
  - 설정 7개와 자리값 동작(D18) · 경로 집합 · 포트 전제
  - 관리 명령 둘(`seed_tenant` · `revoke_sessions`)의 실행 꼴
  - 「재생성」: 실측된 `recopy` + diff 절차(D3) · 손 수정 표(파일 · 고친 자리 · 지키는 시험 · 표식 예외 둘) · pod 소유 새 파일 목록과 「템플릿이 같은 경로를 만들면 덮인다」(〔Y13〕)
  - 스냅샷 갱신 · 시험 명령 · 뷰 응답 규칙(D28)
- **검사 공백 메우기**(〔P24 · P37〕)
  - **ia-18**(정적 — 파일을 읽어 단언한다 · DB 없음)
    - data[0..7] 순서가 바뀌지 않았다.
    - [8..11]이 위 표와 같다.
    - template 참조 ⊆ secretKey.
    - store `vault-dev` · 키 `dev/`.
    - ConfigMap 값이 `"false"`이고 URL 키가 없다.
    - `env.example`의 키 집합 ⊇ `conf.RuntimeEnv` 필드 이름 − {`POD_IP`, `POD_NAMESPACE`, `DATABASE_OWNER_URL`, `JT_PLACEHOLDER_EXEMPT`}. 뺀 넷은 템플릿 env.example에도 없는 이름이다(클러스터가 주는 값 · 런타임에 두지 않는 값 · 면제 env — P/conf.py.jinja:152-156). 새 필드를 더하고 env.example을 잊으면 걸린다(〔Y8〕).
  - VD-T073-8(gitops validate 거울).
- **계약**: C26 · C32.
- **변이**(〔W34〕): ES `data[]` 순번 뒤바꿈(8–11의 두 항목을 맞바꾸거나 0–7 사이에 끼움) → ia-18. ConfigMap `AUTHENTIK_WRITES_ENABLED` 값을 따옴표 없는 불린(`false`)으로 → ia-18(값이 문자열 `"false"`인지 본다 — 템플릿 `base_configmap_env()`의 「값이 전부 문자열」 단언도 함께 걸린다).

### D24 Dragonfly ACL(생성물)

- **무엇**
  - aclfile: `USER identity-admin ON nopass ~revoked:* ~identity-admin:* +@all`
  - conftest: `DRAGONFLY_USERS[POD_NAME] = ("resetchannels", "~revoked:*", f"~{POD_NAME}:*", "+@all")` + 독스트링
  - 같은 파일의 낡는 문자열도 고친다: conftest 독스트링 · `celery.py` 머리 독스트링 · `test_outbox.py` 독스트링의 `%R~revoked:*`(D3 ④ · ⑧ · ⑩).
- **왜**
  - conftest의 약속은 「운영 규칙과 같은 문자열」이다(T/tests/conftest.py.jinja:18-21).
  - 로컬 compose에서 revoke · 재적용이 NOPERM이면 안 된다(〔P18 · L15〕).
  - 실제 워커 시험이 identity-admin 규칙 아래 돈다 — VD-T066-3의 로컬 몫 가운데 **브로커 몫만** 덮는다(채널 권한은 같다 — 〔조사 E23〕). 템플릿 워커 시험은 outbox 행만 심어 재적용 대상이 0이므로 거부 목록 쓰기 권한은 지나지 않는다(A-4 · 〔Y4〕).
  - 템플릿 기본 시험은 pod 사용자의 revoked 쓰기 NOPERM을 단언하지 않는다.
- **이 결정을 지키는 시험**(초안에는 ACL을 되돌려도 깨지는 시험이 없었다 — A-4 · 〔Y4〕)
  - ia 시험 가운데 revoke · 웹훅 · 재적용 · 하한을 지나는 것은 T066의 `ia_dragonfly` 사용자가 아니라 **conftest pod 사용자**(`dragonfly.pod_url` — 이 결정이 고친 규칙)로 돈다(D26). ⑩을 `%R~revoked:*`로 되돌리면 그 시험들이 NOPERM(`denylist.set_failed` · 키 없음)으로 깨진다 = 변이.
  - **ia-24**(정적): `compose/dragonfly-dev.acl`의 `USER identity-admin` 줄의 규칙 토큰 == `DRAGONFLY_USERS[POD_NAME]`에서 `resetchannels`를 뺀 것 == `("~revoked:*", "~identity-admin:*", "+@all")`. 셋째 항은 dl:42의 문자열을 시험 상수로 박은 것이다(T066 `IA_DRAGONFLY_RULES` — test_api.py:236 — 와 같은 값 · 시험이 specs 경로를 읽지 않게 한다 — 설계자 결정).
  - **ia-40**: 활성 로그 행을 둔 실제 워커 시험(D26) — pod 사용자로 `beat_init` 재적용이 키를 만든다.
- **기각**: copier 질문(pod 하나에 템플릿 · 하네스 · 계약 표를 바꿔야 한다) · 그대로 두기.
- **계약**: C14 · C19 · C29.
- **시험**: 템플릿 실제 워커 시험 NOPERM 0이 그대로 통과해야 한다 · ia-24 · ia-40 · pod 사용자로 도는 ia 시험들.
- **남는 것**(〔Y24 · W33〕): `+@all`은 키 패턴이 걸리지 않는 명령(`FLUSHALL` · `ACL SETUSER` · `CONFIG SET`)도 pod 사용자에게 여는 것으로 읽힌다(Redis ACL 의미 기준 추론). 라이브(T097)로 미루지 않고 T073 안에서 잰다 — **VD-T073-16**(조각 ②): 시험 Dragonfly(운영과 같은 digest · pod 사용자 규칙 `+@all`)에서 pod 사용자로 세 명령의 가부를 재 bn과 §7 T075 인계에 적는다. 규칙 자체는 계약 규칙을 생성물에 그대로 옮긴 것이라 T073에서 바꾸지 않는다.

### D25 관측

- **로그 꼴**(〔W26〕): T073 모듈은 structlog 로거(`structlog.get_logger(__name__)`)로 `log.warning("denylist.set_failed", error=…, stage=…)` 꼴을 쓴다 — 이벤트 이름 = JSON `event` 값이고 아래 표의 필드 = JSON 최상위 키다. 본문 곳곳의 `이름 k=v` 표기는 그 줄임이다.
  - stdlib `logging`의 `extra`는 쓰지 않는다 — `configure_logging`의 stdlib 쪽 사슬(`foreign_pre_chain`)에는 `extra`를 올리는 처리기가 없어 JSON 키가 되지 않는다(dc/observability.py:349-389 — 컨트롤러 확인). 메시지 문자열 하나로 찍으면 T079 · T098이 읽을 `reason` · `source` 필드가 없다.
  - ia 시험은 conftest `log_lines`(T/tests/conftest.py.jinja:504)로 읽고 필드를 키로 단언한다.
- **필드 이름과 마스킹**(〔W26〕): 필드 이름에 `mask_sensitive`가 키째 지우는 이름을 쓰지 않는다 — 지워진 필드는 로그에도 시험에도 보이지 않는다. 그 규칙(dc/observability.py:86-219)은 이름을 소문자로 바꾸고 `_` · `.`를 `-`로 바꾼 뒤(앞의 `http-` 하나와 쿠키 접두를 떼고 · camelCase 경계 꼴도 함께) 아래 닫힌 목록과 견준다.
  - 정확히 같은 이름
    - 헤더: `authorization` · `proxy-authorization` · `cookie` · `set-cookie` · `x-authentik-signature` · `x-forwarded-user-sub` · `x-csrftoken` · `referer` · `referrer`
    - 쿠키 · 폼: `cf-authorization` · `sessionid` · `session-key` · `csrftoken` · `csrfmiddlewaretoken` · `password1` · `password2` · `new-password1` · `new-password2` · `jt-session` · `jt-csrf`
    - 요청 환경: `csrf-cookie` · `query-string` · `raw-uri` · `request-uri`
    - 비밀 이름: `password` · `passwd` · `passphrase` · `pgpassword` · `secret` · `token` · `api-key` · `apikey` · `private-key` · `secret-key` · `preshared-key`
    - 자격 URL 설정: `database-url` · `database-owner-url` · `dragonfly-url`
    - 원문 주체: `sub`
  - 접두: `cf-access-` · `opentelemetry-instrumentor-`
  - 접미: `-password` · `-passwd` · `-passphrase` · `-secret` · `-token` · `-api-key` · `-apikey` · `-access-key` · `-private-key` · `-secret-key` · `-preshared-key` · `-key-pem`
  - 아래 표의 필드(`reason` · `scope` · `source` · `tenant_id` · `sub_hash` · `revocation_id` · `count` · `error` · `stage` · `phase` · `rows` · `keys` · `floors` · `skipped` · `failed` · `deleted` · `gone` · `truncated` · `status` · `seen` · `recorded` · `pages`)는 어느 것에도 걸리지 않는다(`sub_hash`는 `sub`와 다른 이름이고, 일반 `-key` · `-url` 접미는 목록에 없다). 마스킹은 값을 보지 않는다 — 원문 `sub`는 값으로도 싣지 않고 `sub_hash`만 쓴다.

| 이벤트 | 수준 | 필드 |
|---|---|---|
| `session_revocation.recorded` | INFO | reason · scope(user/session) · source(revoke/admin/webhook/reconcile/command) · tenant_id · sub_hash · revocation_id |
| `identity.multiple_memberships` | WARNING | count · sub_hash |
| `denylist.set_failed` | WARNING | error(클래스) · stage(lookup/connect/command) |
| `denylist.set_skipped` | INFO | (TTL < 1이거나 행이 없어 쓰지 않았다) |
| `denylist.reapplied` | INFO | phase(beat_init) · rows · keys · floors · skipped · failed |
| `denylist.reapply_failed` | WARNING | phase(beat_init/tick) · error(클래스) · failed |
| `session_floor.lookup_failed` | WARNING | error(클래스) |
| `session_check.iat_in_future` | WARNING | (필드 없음 — 값과 sub를 싣지 않는다) |
| `webhook.nbf_missing` | WARNING | sub_hash |
| `webhook.nbf_clamped` | WARNING | sub_hash(본문 `nbf`가 `⌊created⌋ + 1`을 넘어 그 값으로 낮춰 기록했다 — 〔Z8〕) |
| `authentik.revoke_{enqueued,enqueue_failed,skipped,done,failed,expired,user_missing}` | INFO · WARNING | sub_hash · deleted(204 수) · gone(404 수 — 〔W30〕) · truncated · status · error · reason |
| `authentik.calls_disabled` | WARNING | reason(placeholder_credential) |
| `authentik.reconcile_{done,failed,forbidden,truncated,skipped}` | INFO · WARNING | seen · recorded · skipped · pages · status · error · reason(user_lookup — 〔W2〕) · count |

- 이벤트 이름과 필드는 설계자가 정했다(계약 C10에 이름을 싣는다). 30 s 재적용의 평시 성공은 자기 로그 줄 없이 Celery 성공 줄(반환값)로만 남는다(D14).
- 원문 sub · sid · URL · 예외 문구 · 토큰은 싣지 않는다(pt:81). sub_hash는 dc의 함수를 쓴다.
- **지표**: `session_revocations_total{reason}`
  - 템플릿 metrics.py처럼 지연 등록한다(〔P19〕).
  - 커밋 뒤에만 +1한다. 재전송 · 4xx · 롤백은 0이다.
  - web 프로세스 지표다. 워커의 대조 백필과 `kubectl exec`로 도는 관리 명령의 +1은 수집되지 않는다(celery 컨테이너에 지표 포트가 없다). 그 수는 로그 `session_revocation.recorded`의 `source`로 센다(C10 · 〔Y24〕).
  - 새 지표는 두지 않는다(하한 · 신선도의 관측은 로그와 키다).
- **경보 기준**(T098 인계 · §7): `reconcile_denylist` 성공 줄 5분 무소식 · `denylist.set_failed` · `denylist.reapply_failed` · `authentik.revoke_failed`의 status 401 · 403 · US4 뒤의 `authentik.calls_disabled` · `authentik.reconcile_truncated`. 〔Y23 · E5〕
  - 검토 반영으로 더한 것(〔W19〕 — 설계가 「WARNING이 드러낸다」고 기대던 것들이다)
    - `webhook.nbf_missing` 1건(매핑 회귀 — 수신 시각이 30일 하한 값이 된다 · D21)
    - prod의 `authentik.reconcile_forbidden` · `authentik.reconcile_failed` 이틀 연속(창이 72 h라 사흘째면 유실 웹훅이 영영 기록되지 않는다 · dev의 `reconcile_forbidden`은 권한을 주지 않았을 때 하루 한 줄이라 뺀다)
    - `authentik.reconcile_done` 48 h 무소식(beat 스케줄 파일이 `/tmp` emptyDir라 pod가 바뀌면 — 롤아웃 · Reloader · 축출 — 스케줄 파일이 새로 생겨, 03:37을 걸친 교체는 그날 실행을 실패 줄 없이 건너뛴다. 같은 pod 안의 컨테이너 재시작은 파일이 남아 기동 직후 따라잡는다 — 사실 ⑧ · 〔Z11〕)
    - `session_check.iat_in_future` 1건(Authentik 시계가 앞섰거나 BFF 결함이다 — D29 · 〔W15〕)
    - `session_floor.lookup_failed`
  - 재검토 반영으로 더한 것(〔Z8 · Z12〕)
    - `webhook.nbf_clamped` 1건(매핑이 `nbf`를 `⌊created⌋ + 1`보다 크게 계산했다 — 폐기는 낮춘 값으로 기록됐다 · D10 · 〔Z8〕)
    - prod의 `authentik.reconcile_skipped` 이틀 연속(사용자 조회가 전부 404다 — 조회 권한을 본다 · D17 · 〔Z12〕)
    - `authentik.revoke_done`에서 `deleted` 0 · `gone` ≥ 1이 되풀이됨(삭제 권한을 본다 — 권한이 빠진 DELETE도 404라 위임이 실패 줄 없이 끝난다 · D16 · 〔Z12〕)
- **계약**: C10 · C33.
- **시험**: api-10 · 21 · **ia-19**(로그 위생: revoke · 웹훅 · SET 실패 경로의 로그 줄에 원문 sub · sid · Dragonfly URL · 비밀번호 · 예외 문구가 없다 — 재적용 실패 경로의 위생은 ia-38이 본다 / 활성 사용자 단위 행을 넣고 DRAGONFLY_URL을 블랙홀 포트로 둔 채 `denylist_writer.apply_user`를 직접 부르면 1 s 안에 `unreachable`로 끝난다 — 0.2 s 명시를 지우면 redis-py 기본 5 s가 된다 · 닫힌 포트는 Linux에서 즉시 RST라 가르지 못해 쓰지 않는다 · 〔Y10〕).

### D26 시험 구성 · 스냅샷 · T066 독스트링

- **수(추정 — 조각 끝마다 실제 수를 bn에 적는다)**
  - T066 102: api 76 + 가짜 자기검사 26
  - 생성물 기본 174: 165 + 매개화 9
  - T073 소유 ia-1–41 + 가짜 자기검사(`test_ia_fakes.py`)
- **템플릿 소유 시험 손 수정**(삭제 · skip 아님 — 규칙:69)
  - test_auth_middleware.py.jinja:116-136: REQUIRED +4 · SECRET +3
  - test_outbox.py.jinja:716: 목록을 `["purge-dead-outbox", "reconcile-denylist", "purge-session-revocation-log", "reconcile-authentik-sessions"]`로 바꾸고 새 세 항목의 주기 단언을 더한다. 03:17 단언은 그대로다.
- **스냅샷**: 엔드포인트를 더한 같은 커밋에서 README 명령(T/README.md.jinja:275-284)으로 다시 쓰고 경로별로 검토한다(규칙:86). 구조는 api-50이 따로 지킨다.
- **T073 소유 도우미와 배선**(〔Y14〕)
  - `_ia_support.py`: 픽스처와 도우미(자격 헤더 · 요청 · 로그 행 넣기 · 키 읽기). T066 모듈(`test_api.py`)에서는 import하지 않고, 도우미는 템플릿 `tests._jwt` · `tests._problem` · `tests._secret`과 T066 `tests._identity_fakes`(가짜 · 닫힌 포트 · 블랙홀 · DNS 가드)를 다시 쓴다.
  - **배선**: 생성물 `tests/conftest.py`에 `pytest_plugins = ("tests._ia_support",)` 한 줄과 `register_assert_rewrite`에 `"tests._ia_support"` · `"tests._ia_fakes"`를 더한다(손 수정 ⑩). star-import는 쓰지 않는다 — 세션 픽스처가 모듈마다 다시 만들어진다(A-14). pod 루트나 `tests/` 아래 노드 ID로 돌릴 때 `tests/conftest.py`는 첫 적재 conftest라 `pytest_plugins`가 허용된다(수집 성공이 조각 ①의 실측이다).
  - **autouse를 두지 않는다**: 플러그인의 autouse 픽스처는 T066 · 템플릿 시험에도 걸린다(템플릿 conftest의 원칙 — T/tests/conftest.py.jinja:3). ia 모듈은 머리에서 `pytestmark = pytest.mark.usefixtures("ia73_env")`로 고른다.
  - **픽스처**(이름 접두 `ia73_` — T066의 모듈 픽스처 `ia_*`와 겹치지 않는다)
    - `ia73_env`(함수): ① pod 설정 덮기 — T066 `ia_settings`와 같은 값이되 `DRAGONFLY_URL` = **`dragonfly.pod_url`**(conftest pod 사용자 — D24) · Authentik은 확장 가짜 ② 가짜 서버 초기화 ③ Dragonfly FLUSHALL(admin) ④ 공개 DNS 가드 + 프록시 env 끄기(끝에 기록 0 단언)
    - `ia73_authentik`(세션 — `_ia_fakes`의 확장 가짜) · `ia73_openfga`(세션 — T066 `FakeOpenFga`) · `ia73_webhook_secret`(세션) · `ia73_df_admin`(함수 — admin 클라이언트)
    - Dragonfly 사용자를 새로 만들지 않는다(`ACL SETUSER` 없음 — T066의 `identity-admin-test` 사용자와 무관하다).
  - `_ia_fakes.py`: 가짜 **둘**(〔W27〕)
    - ① T066 `FakeAuthentik` 하위 클래스(`_route` 재정의 — 응답은 기반 핸들러대로 JSON 본문 한 번이다)
      - sessions 목록(필터 무시 미끼 모드 · 끝나지 않는 `next`) · 단건 DELETE(204 · 404)
      - events 쪽(필터 무시 · 정렬 뒤섞기 · 끝나지 않는 `next`)
      - 상태 순서 주입(5xx 두 번 뒤 200 등) · 큰 JSON 응답
    - ② 독립 원시 HTTP 서버(`BaseHTTPRequestHandler`를 직접 쓴다 — 상태 · 헤더 · 본문 바이트 · 조각 사이 지연을 스크립트한다). ia-22의 302 + Location(둘째 호스트가 받은 요청 0) · JSON이 아닌 200 · 느린 조각은 이것이 맡는다. T066 기반 핸들러는 JSON 본문 한 번과 고정 헤더만 내고(`tests/_identity_fakes.py:88-128`) 그 파일은 독스트링만 고칠 수 있어 하위 클래스로는 만들 수 없다(검토 C-6).
  - `test_ia_fakes.py`: 위 가짜 둘의 자기검사
  - DB에 닿는 ia 시험의 마크는 T066과 같다(`django_db(transaction=True, databases=["default", "owner"])` — T072 가정 ①). `/session/check` 판정 시험(ia-1 · 2 · 29 · 30 · 36 · 37)은 DB 마크를 달지 않는다(뷰가 DB에 닿으면 실패한다).
  - **구현 모듈은 시험 함수 안에서 가져온다**: ia 모듈과 `_ia_support.py`는 머리에서 `identity_admin.revocation` · `denylist_writer` · `session_floor` · `jobs` · `outbound` 등을 import하지 않고 `importlib.import_module`(모델은 T066처럼 `apps.get_models()`)로 쓰는 자리에서 가져온다. ia 시험은 그 조각의 첫 단계 — 구현 앞 — 에 쓰므로(§5 · 〔W24〕), 구현 없이도 수집이 성공하고 빨강의 사유가 수집 오류가 아니라 「구현 없음」(`ModuleNotFoundError` · 404 · 속성 없음 · `NotImplementedError`)으로 노드마다 드러난다(T066과 같은 방식 — test_api.py:166 · 348 · 645).
- **이음매**(시험이 덮거나 가로채는 자리 · 〔W29〕)

| 이음매 | 쓰는 시험 | 무엇을 하나 |
|---|---|---|
| `revocation.event_already_recorded` | ia-7 | 늘 거짓으로 덮어 INSERT 경합 갈래(`srl_event_pk_uniq`)를 지나게 한다 |
| `revocation.db_now_epoch` | ia-39 (b) · (c) | 지금 − 400을 돌려주게 덮고 호출 수를 센다 |
| `session_floor.read_floor` | ia-30 (a) | 첫 조회가 실패했을 때 호출 0을 센다 |
| `denylist_writer.client` | ia-30 (b) | 닫힌 포트의 클라이언트를 돌려주게 덮는다 |
| `session_floor.REVOCATION_LOG_RETENTION` | ia-33 | 다른 값으로 덮어 purge 경계와 하한 창이 함께 움직이는지 본다 |
| `identity_admin.celery.app.send_task` | ia-11 · ia-26 | 위임 enqueue의 횟수와 옵션을 본다 |

- **이음매 규칙**(〔W29〕)
  - **호출 지점은 모듈 속성으로 부른다**(`revocation.event_already_recorded(pk)` · `session_floor.read_floor(sub)` 꼴). `from … import 이름`으로 묶지 않는다 — 묶으면 시험이 모듈 속성을 덮어도 호출 지점은 묶어 둔 옛 객체를 부르고, 「0회」를 세는 시험이 조회를 했는데도 0회로 보여 공허하게 통과한다(검토 C-8).
  - 가로채 「0회」를 세는 시험은 같은 가로채기로 정상 요청의 1회를 먼저 단언한다(ia-11 · ia-30 (a) · ia-39 (b) → (c)).
  - **부정 사례의 짝**(〔Z7〕 — 재검토 RB-2): 부정 사례(400 · 404 · `CommandError` · 호출 0 · 키 없음)는 같은 준비물에서 한 가지만 바꾼 정상 사례와 짝을 둔다 — 부정 단언만 있으면 준비물이 틀려도, 구현이 아직 없어도 같은 결과로 통과한다. `CommandError`를 기대하는 명령 시험은 먼저 `get_commands()`에 그 명령이 있음을 단언한다(T066 `_seed()`와 같은 방식 — 명령이 없어도 `call_command`는 `CommandError`다). 문면에 적어 둔 곳: ia-21(Tenant 행이 있을 때 200 → 지운 뒤 404) · ia-26 · ia-15 · ia-16(명령 존재 단언).
  - **상수 이름**(시험이 「마감 0 s」 같은 조건을 만들 때 덮는 이름 — 값의 근거는 각 결정): `jobs.DELEGATION_DEADLINE_S`(20) · `jobs.RECONCILE_DEADLINE_S`(120) · `jobs.RECONCILE_WINDOW`(72 h) · `authentik.SESSION_PAGE_LIMIT`(10) · `authentik.EVENT_PAGE_LIMIT`(50). 쓰는 자리에서 모듈 속성으로 읽는다.
  - **반환 꼴 셋**
    - `session_floor.read_floor`: 실패는 `DenylistUnavailable`을 올린다(값이 정수가 아닌 것도 같다). 키가 없으면 None이다.
    - `outbound.request_json`: 성공 반환은 디코드한 JSON 값이다(빈 본문은 None).
    - `denylist_writer.apply_user` · `apply_sid`: 네 문자열(`ok` · `skipped` · `failed` · `unreachable`) 가운데 하나다.
- **ia 목록**(파일은 D1 · 상세는 각 결정)
  - 1 U8(a) · 문자 규칙 — D8
  - 2 클라이언트 재사용(연결 증가 ≤ 2) — D8
  - 3 U8(b) — D10
  - 4 revoke 판정 순서 · 조합 · 문자 규칙 · 지표 0 — D9
  - 5 다중 멤버십 — D12
  - 6 웹훅 nbf 범위 · 과거 nbf · sub · pk 문자 규칙 — D10
  - 7 event_pk 경합 — D12
  - 8 웹훅 200 · 202 본문 · 위임 0 · 무시 action · pk 정규화 · nbf 누락 경고 — D10
  - 9 · 10 재적용(`revoked:*`) — D14
  - 11 enqueue 조건과 옵션 — D16
  - 12 위임 본체 — D16
  - 13 대조 — D17
  - 14 · 15 · 16 seed — D19
  - 17 스키마 — D22
  - 18 deploy 정적 · env.example — D23
  - 19 로그 위생 · 쓰기 시간 상한 — D25
  - 20 B 표 RLS 꺼짐 · check_rls B ≥ 4 · 제약 · 인덱스 — D4
  - 21 고아 멤버십 — D11
  - 22 HTTP 클라이언트 위생 — D20
  - 23 기동 면제 상수 · 길이 · URL 꼴 — D6
  - 24 ACL 정적 — D24
  - 25 `sid` 한계 고정 — D9
  - 26 관리 명령 `revoke_sessions`(사용자 단위 · 커밋 뒤 결과 출력) — D30
  - 27–37 세션 하한 · 절대 수명 · 미래 `iat`(27 쓰기 3경로 · 28 sid는 하한 없음 · 29 판정 표 · 30 조회 실패 둘 · 31 최댓값 유지 · 32 재적용 · 33 purge 경계 · 34 백필 꼴 · 35 재전송 · 36 나이 경계 · 37 미래 값) — D29
  - 38 신선도 키 · 반환 계약 — D14
  - 39 `nbf` 상한(경로별 — a 웹훅은 낮춰 기록 · b 관리 명령은 거부 · c HTTP 경로는 DB 시계를 보지 않는다) — D12 · D10
  - 40 실제 worker + beat(30 s tick이 실제로 도는지 · 유실 뒤 복구) — 아래
  - 41 `authentik.py` 메서드 단위 — D20(〔W28〕)
- **ia-40 실제 worker + beat**(〔Y4 · Y16 · Z16〕): 템플릿 실제 워커 시험(T/tests/test_outbox.py.jinja:742-797)의 도우미(`_celery_commands` · `_start` · `_stop` · `_wait_for` · `_child_env` · `_tails` · `NOPERM_MARKERS`)를 `tests.test_outbox`에서 이름으로 가져와 쓴다(시험 함수는 가져오지 않는다 — 두 번 수집된다).
  - 활성 사용자 단위 로그 행 1개를 넣고 Dragonfly를 비운 뒤 worker(+ beat)를 pod 사용자(`dragonfly.pod_url`)로 띄운다. Windows는 두 프로세스, POSIX는 D14 내장 명령 하나다(`_celery_commands`가 가른다).
  - 기다린 뒤 단언: `revoked:sub:<sub>` · `identity-admin:session-floor:<sub>` · `identity-admin:denylist:reapplied-at` 키가 있다 · 로그에 `denylist.reapplied`(phase `beat_init` · `floors` ≥ 1) 줄이 있다 · NOPERM 0 · 로그에 DB · Dragonfly 비밀번호와 원문 sub 0.
  - **tick이 실제로 도는가**(〔Z16〕 — **뺄 수 없는 단언** · 재검토 RB-12): `FLUSHALL` 앞에, 기동 뒤 60 s 안에 신선도 키의 값이 `beat_init` 때 읽은 값보다 커진다(또는 로그에 `reconcile_denylist` 성공 줄이 1회 이상 있다). 위의 기동 단언은 `beat_init` 재적용이라 브로커를 거치지 않고, 다른 재적용 시험(api-30–32 · ia-9 · 10 · 32 · 38)은 `task.apply()`와 정적 단언이다 — 30 s tick이 beat → 브로커 → 워커로 실제로 도는 것을 보는 시험은 이것 하나다.
  - **유실 뒤 복구**(VD-T073-15 (a) · 〔W25〕): 위 키들이 생긴 것을 본 뒤 admin으로 `FLUSHALL` → 60 s 안에 `revoked:sub:<sub>` · 세션 하한 · 신선도 키가 돌아온다(tick 30 s + 여유). `FLUSHALL`은 Celery 브로커 키도 지우므로 재적용 경로가 브로커에 남은 상태에 기대지 않는지도 함께 본다. 이 복귀 단언이 실패하면 **이 단언만** 빼고 한계를 bn에 적은 뒤 컨트롤러에 보고한다(결정 후보: 재적용 루프를 beat 프로세스 타이머로 — §6 VD-T073-15). 뺄 수 있는 것은 `FLUSHALL` 뒤 복귀 단언뿐이다 — 위의 tick 단언은 빼지 않는다(그것이 실패하면 `FLUSHALL` 고유의 문제가 아니라 tick 경로의 결함이다 · 〔Z16〕).
  - CI(arm64 Linux)에서는 이 시험이 운영과 같은 내장 beat 토폴로지로 돈다 — 기동 재적용이 조용히 실패하면 빨강이다(VD-T073-5 · VD-T073-CI).
  - 템플릿 도우미 이름에 기대므로 재생성 때 이름이 바뀌면 수집에서 시끄럽게 깨진다(의도 — §9).
- **T066 독스트링 정합**(단언 변경 0 · 〔Y15〕)
  - test_api.py:8-10: `/session/check`의 active 정의 문장 끝에 「세션 하한 · 절대 수명 · 미래 `iat` 조건은 T073 보정이고 tests/test_identity_contract.py가 본다」를 덧붙인다.
  - :14: 「커밋 후 SET EX 330」 → 「커밋 후 SET(TTL = min(330, 남은 초) · 사용자 단위는 세션 하한 키도 — T073 보정)」.
  - :24-26: 주기 작업 문장 끝에 「같은 재적용이 세션 하한 키와 신선도 키도 쓴다 — T073 보정 · tests/test_identity_jobs.py가 본다」를 덧붙인다(`revoked:*`의 「한 행 = 한 키」 서술은 그대로 참이다).
  - :55-60 ⑥: 「setdefault」 → 덮어쓰기. 「형식 · 길이 검사 없음」 → 길이를 보는 것은 SECRET_KEY(W009 기준)와 `AUTHENTIK_WEBHOOK_SECRET`(32자 이상)이고 64자 난수는 늘 통과한다.
  - :103-108 「빨간 상태」 → 생성 pod에서는 일반 실행.
  - :134(한계 목록의 「실시간 SIGKILL ≤ 30 s는 T085」) → 「실시간 SIGKILL 뒤 복구 시간은 T085 — 상한은 contracts/denylist.md §쓰기 규약 유실 창(T073 보정)」(마감 확인 제안 — 〔편차 29〕와 맞춘다 · api-30 독스트링 :1761의 「"30 s 안에"는 … 대신한다(실시간은 T085)」는 그대로 참이라 두어도 된다).
  - :313-314 주석(같은 길이 문장).
  - test_identity_fakes.py:10 · _identity_fakes.py:24: `-p no:django` 문장.
  - 검증: 독스트링 · 주석을 뺀 AST 덤프가 전후 같아야 한다(빌더 증거).
- **실행**
  - 반복 중에는 노드 ID만 돌린다(`uv run --directory apps/identity-admin --locked pytest -q tests/…::…`).
  - 조각 끝에 전체를 한 번 돈다.
  - `-p no:django` · `-o addopts`는 쓰지 않는다(규칙:71).

### D27 CI

- **새 job `identity-admin`**
  - `ubuntu-24.04-arm` · `timeout-minutes: 30`
  - checkout `persist-credentials: false`
  - setup-uv: 세 job과 바이트까지 같은 블록
  - run `uv run --directory apps/identity-admin --locked pytest -q` 한 줄
  - env 0(static-16)
- **ps1**(〔W32〕 — 고치는 파일은 `tests/scripts/kubeconform-deploy.tests.ps1` 하나다. static-14–17과 새 static-18이 모두 이 파일의 `static` 묶음에 있다 — 원문 확인)
  - static-14를 네 job으로 넓힌다.
  - 새 static-18: pytest 줄 정확히 하나 · persist false · timeout ≤ 30 · 업로드 없음.
  - static-15는 그대로다.
  - `ci.yml`을 읽는 다른 ps1 하네스 둘(`tests/scripts/ci-gitleaks.tests.ps1` · `tests/scripts/events-compat.tests.ps1`)은 고치지 않는다. job을 더한 뒤 한 번씩 돌려 초록을 본다 — `events-compat.tests.ps1`의 st-1은 job `events-compat` 바로 다음이 `events-test`임을 본다(:635-641). 새 job을 그 둘 사이에 두지 않는다.
  - `tests/run-all.ps1` 전체는 어느 조각에서도 돌리지 않는다(§5 공통 환경).
- **왜**: job test의 60분은 이미 다 배정됐다(ci.yml:337-341 · static-15). 새 job은 병렬이라 벽시계 시간이 늘지 않고, SP-2에서는 matrix로 넓힌다.
- **기각**: job test 셋째 줄. 예산 · static-15 · 타임아웃을 함께 고쳐야 하고 직렬 시간이 는다.
- **운영자 단계**: main ruleset required check 지정은 인계로 넘긴다(events-compat 선례 — bn:1026).
- 〔편차 11〕 · VD-T073-10 · CI.

### D28 django-ninja · 사람 admin · admin 등록 · US7 AC3

- **ninja = 1.7.0 유지**(UD-6 확정 — 컨트롤러 · t072 §8 「사용자 결정이 아니다」)
  - **반환 규칙**: 1.7.0에 머무는 동안 뷰는 dict 또는 선언 스키마의 정확한 인스턴스만 돌려준다. 하위 클래스 인스턴스는 금지다 — 선언 밖 필드가 응답에 실릴 수 있다(#1823 · 1.7.3에서 고쳐짐 — 사실 ⑲). 200이 아닌 응답은 `Status(code, body)`로 낸다(튜플 반환은 폐기 경고 — ⑦).
  - **규칙의 정본 자리**(〔Y9〕): 설계 문서는 과제가 닫히면 고치지 않는 내부 자료라 규칙이 살 곳이 못 된다. `.claude/rules/django-pod.md` §Errors(C47 — 설계 커밋)와 템플릿 README(C34 — 조각 ⓪)에 한 줄씩 둔다. 템플릿 핀도 1.7.0이라 SP-2 pod에도 같은 경로가 있다. T073 리뷰 체크리스트에도 넣는다.
  - 폐기 폴백 문장 1.6.2 → 1.6.5(C1 · C16)는 plan:17 편차다(〔편차 10〕).
  - 1.7.3 올림은 T116에서 템플릿과 pod를 함께 한다(§7).
- **사람 admin(O1 · O2 · VD-T066-5)**: T073은 손대지 않는다(pt:78 「T084로 미룸 — 닫힌 쪽」 · test_api.py:136-137).
- **admin 모델 등록 0**: admin에서 고치면 seed의 DB → 파생 규칙을 우회한다(dm:20). 읽기 전용 등록 여부는 T084가 정한다.
- **US7 AC3 「의도적 예외」**(bn:3381): 운영 코드에 고의 500 경로를 두지 않는다. 계약 밖 표면이기 때문이다.
  - 인계 T100. 권고안: 관리 명령 `sentry_smoke`
    - 프로세스 안에서 `configure_sentry` 뒤 합성 요청 하나를 처리기에 흘린다.
    - RequestIdMiddleware → handler500 → Sentry `request_id` 태그 경로를 그대로 지난다.
    - 시험 전용 urlconf는 그 프로세스에서만 쓴다.

### D29 세션 하한 · 절대 수명(폐기 최종성)

- **문제**(A-2 · B-1 · 〔Y2〕)
  - `revoked:*` 키의 330 s는 이미 나간 access 토큰을 막는 수명이다.
  - BFF 세션은 쿠키 안의 refresh 토큰이다. Authentik은 세션을 지워도 refresh 토큰을 남기고(〔조사 E8 · V7〕), refresh grant는 세션을 보지 않으며(〔V5〕), 비슈퍼유저 서비스 계정은 남의 refresh 토큰을 지울 수 없다(〔조사 E7 · V6〕).
  - 그래서 폐기 뒤 330 s 넘게 쉬던 기기(전체 로그아웃의 「다른 기기」)와 복사해 둔 쿠키는 다음 요청에서 active → refresh → 교환으로 계속 산다. BFF가 `iat`에 세션 시작 시각을 보내는 것만으로는 키가 사는 330 s 안에 BFF에 닿은 세션만 끊긴다.
- **결정**(사용자 2026-11-12 「로그 파생 + 수명 30일」 · 〔E1 · E2 · E3〕): 기존 폐기 로그의 사용자 단위 행에서 사용자별 not-before 키(세션 하한)를 파생해 30일 유지하고, `/session/check`가 「하한 > 세션 시작 시각」이거나 「세션 나이 > 30일」이면 inactive로 판정한다. 새 표 · 새 열은 0이다.
- **정본과 값**
  - 정본 = `session_revocation_log`의 사용자 단위 행(`sid` NULL) 그대로다. 폐기되는 sub마다 늘 있는 행은 이 로그 행뿐이다(본인 폐기는 tenant · 멤버십 행 없이 202다 — api-10 · 〔R11〕). 표 · 열 · 허용 목록 · 엔티티 수(14) 변경이 0이다(〔R7 · R9〕). spec:309의 「폐기의 DB 정본」 그대로다(〔R18〕).
  - 값 = 보존 창(`expires_at + 30 d > DB now()`) 안 그 sub 사용자 단위 행의 `nbf` 최댓값(정수 epoch 초).
  - 키 = `identity-admin:session-floor:{sub}`(정수 꼴 문자열).
  - TTL = 최댓값 행의 `expires_at + 30 d − DB now()` 내림(1 미만이면 SET 생략). 수명 끝 = `nbf` + 330 s + 30 d = 그 행의 purge 경계.
  - `sid` 행은 하한을 만들지 않는다(〔E13〕).
- **접두와 이름**
  - `revoked:` 아래에 두면 api-10 · api-30의 키 목록 완전 일치가 깨진다(test_api.py:623-625 · 1327 · 1777 — 〔R3〕).
  - `identity-admin:*`는 운영 ACL(dl:42)과 T066 픽스처 규칙(test_api.py:236)이 이미 읽기 · 쓰기를 준다. ACL · Vault aclfile · gitops 변경이 0이다(〔R16〕). Celery 키(`global_keyprefix` `identity-admin:`)와는 하위 이름 `session-floor:`로 가른다.
  - 이름에 epoch를 쓰지 않는다. 폐지된 센티널 `denylist:epoch`와 헷갈린다(dl:12 · api-30).
- **상수**(`identity_admin/session_floor.py` — 이름은 설계자가 정했다)
  - `REVOCATION_LOG_RETENTION = timedelta(days=30)`: 로그 purge(D14) · 하한 수명(D13 · D14의 SQL 매개변수) · 세션 절대 수명이 함께 쓰는 상수 하나다. env 설정으로 열지 않는다 — 셋이 따로 움직이면 조용히 열린다.
  - `SESSION_ABSOLUTE_LIFETIME = REVOCATION_LOG_RETENTION`: 같은 객체를 가리키는 별칭이다(뜻을 드러내는 이름일 뿐 값을 따로 두지 않는다).
  - `FUTURE_IAT_TOLERANCE_S = 60` · `FLOOR_KEY_PREFIX = "identity-admin:session-floor:"`.
  - SQL에는 `interval '30 days'` 리터럴을 쓰지 않고 상수를 매개변수로 넘긴다(psycopg가 `timedelta`를 interval로 옮긴다). 상수 하나를 바꾸면 purge 경계 · 하한 수명 · 나이 조건이 함께 움직인다. api-34가 30 d ± 1 h를 고정하므로 값 변경은 T066이 잡는다(〔R5〕). 쓰는 쪽(`denylist_writer`의 SQL 둘 · `purge_log`)은 `session_floor.REVOCATION_LOG_RETENTION`을 호출할 때 모듈 속성으로 읽는다(`from … import`로 이름을 묶어 두지 않는다 — ia-33이 이 값을 덮어 본다).
- **쓰기**: D13(커밋 뒤 최댓값 조회 → `revoked:sub`와 한 파이프라인). **재적용**: D14(둘째 SQL · `beat_init`도 같다 · 새 beat 항목 0). **읽기**: D8(3단계).
- **판정식**(`session_floor.is_active(*, record, floor, iat, now) -> bool` — 순수 함수)
  ```python
  lifetime_s = int(SESSION_ABSOLUTE_LIFETIME.total_seconds())  # 2,592,000 — 호출 때 상수에서 계산한다(초 단위 값을 따로 두지 않는다)
  active = (
      not record.revokes(iat)                        # T066 고정: revoked:sub 값 > iat 또는 revoked:sid 존재
      and not (floor is not None and floor > iat)    # 세션 하한(같으면 active)
      and not (now - iat > lifetime_s)               # 세션 절대 수명 30 d
      and not (iat > now + FUTURE_IAT_TOLERANCE_S)   # 미래 iat
  )
  ```
- **최종성 논증**: 사용자 단위 폐기의 `nbf`를 n, 폐기 전에 시작한 세션의 시작 시각을 s(< n), `/session/check` 시각을 t라 하자. 하한 키는 값이 n 이상이고(최댓값이다) n + 330 s + 30 d까지 산다. t ≤ n + 330 s + 30 d면 하한(≥ n > s)이 막는다. 그 뒤라면 t − s > (n + 330 s + 30 d) − s > 30 d이므로 나이 조건이 막는다. 두 구간이 330 s 겹쳐 틈이 없다. 곧 **하한 수명(n + 330 s + 30 d) ≥ 세션 최대 나이(30 d)**가 이 설계의 불변식이고, 하한 수명과 절대 수명이 같은 상수라 늘 성립한다. 이 논증은 기록 지연(웹훅 재시도 · 72시간 백필 — 하한의 수명 끝은 기록 시각이 아니라 이벤트 시각 n에 붙는다) · Authentik의 refresh 수명 · Dragonfly 유실 창에서 일어난 회전과 무관하다 — 그 사이 세션이 몇 번을 회전했든 다음 확인에서 같은 식으로 걸린다. 그래서 바탕 설계가 붙였던 「refresh 수명 27일」 보강 · gitops의 refresh 수명 정적 검사 · 「기간 한정」 · 「백필 꼬리」 · 「유실 창 뒤 부활」 서술은 이 불변식으로 대체된다(〔E2 · ATK-6〕). 겹침 330 s는 pod · PG · Authentik 시계의 어긋남도 흡수한다(합격선 1 s 미만 — 〔E10〕).
- **남는 열림**(논증이 덮지 않는 것 — §9에 다시 적는다)
  - **재적용이 돌아올 때까지**: Dragonfly가 데이터를 잃으면 하한이 없다(키 없음 = 통과). 30 s 재적용이 되살릴 때까지 폐기 전 세션이 active로 보이고, beat가 멈춘 채 유실되면 사람이 알 때까지다. 재적용이 돌아오면 다음 확인에서 다시 inactive가 된다(되살아난 채로 남지 않는다).
  - **기록되지 못한 폐기**: 유실된 웹훅(대조가 돌기 전이거나 대조 권한이 없을 때) · 503으로 끝난 전체 로그아웃. 하한이 생기지 않으므로 그 세션은 시작한 지 30일이 될 때까지 산다 — 상한이 30일이다.
  - **시계 틈**: Authentik이 pod보다 앞선 만큼, 폐기 직전에 만든 세션이 `issued_at` ≥ `nbf`가 되어 산다. 이것도 상한이 30일이다.
  - **SSO 재진입**: 하한이 막는 것은 폐기 전에 만든 BFF 세션이다. Authentik 로그인 세션이 살아 있는 기기는 사용자 단위 폐기 뒤에도 재인증 없이 새 BFF 세션을 얻는다. 닫는 수단(callback 입장 판정)은 UD-8이고, 계정 탈취 대응의 완결은 Authentik 사용자 비활성화다(T114 · 〔E9〕).
  - **BFF 규율**: `iat`의 원천과 확인 자리는 BFF가 지킨다(C43–C45 · T089). BFF가 refresh 때 `issued_at`을 갱신하면 하한도 나이 조건도 무력해진다.
  - **`sid` 단위 폐기**: 하한이 없다. 최종성은 BFF 로그아웃의 RFC 7009에 기댄다. `sid` 30일 키로 넓히는 것은 UD-7 결정 뒤의 SP-2 후보다(〔E13〕).
- **경계 동작**
  - 폐기 직후 재로그인: `issued_at ≥ nbf`면 active다. `/sessions/revoke`의 `nbf`가 ⌊처리⌋ + 1이라, 폐기와 같은 시계 초 안에 코드 교환이 끝난 재로그인은 한 번 튕긴다(닫힌 쪽 — 다시 로그인하면 된다). 자동화(T079 · T085)는 폐기 뒤 2 s 이상 두고 재로그인한다(〔E10〕).
  - 늦은 웹훅 재시도 · 72시간 뒤 백필: 값이 수신 시각이 아니라 이벤트 시각이고 쓰는 값은 늘 최댓값이다. 그 사이 다시 로그인한 세션을 죽이지 않고 새 하한을 낮추지도 않는다. 조건은 매핑이 `nbf`를 싣는 것이다(D21).
  - 330초 넘게 쉬던 기기 · 복사된 쿠키: 다음 BFF 접촉에서 죽는다. 제시하는 순간 BFF가 그 refresh 토큰을 RFC 7009로 지운다(C45).
  - 30일 넘은 세션: 폐기가 없어도 inactive다. 사용자는 30일마다 다시 로그인한다(Authentik 로그인 세션이 살아 있으면 자격 입력 없이). 승인 문면에 없는 새 동작이다(〔편차 18〕).
  - 미래 `iat`: pod 시계보다 60 s 넘게 앞선 값은 inactive다. 닿는 길은 둘뿐이다(〔W15〕).
    - ① Authentik 시계가 pod보다 60 s 넘게 앞섬: 갓 만든 세션이 그 차이만큼 inactive로 보인다(닫힌 쪽). 시계 실측이 먼저 잡는다 — 5 s만 어긋나도 pod의 Bearer 검증이 leeway에서 깨진다(dc/auth.py:202).
    - ② BFF 결함: `iat`에 ms epoch나 `exp` 같은 값을 보냄. 하한 · 나이 조건이 조용히 무력해지는 대신 로그인 직후 inactive로 드러난다(T089 · T092 시험에서 잡힌다).
    - pod 시계가 뒤처진 경우는 여기 닿지 않는다 — `/session/check`의 Access JWT `iat` 검사가 먼저 403을 내고 BFF가 503으로 접어 쿠키를 지킨다(「pod 시계가 순간 뒤처져 전원이 로그아웃된다」는 생기지 않는다). 이 문장은 추론이다 — Access가 서비스 토큰 요청마다 `iat`를 새로 찍는다는 전제에 기대고, 그 전제는 이 저장소에서 잰 적이 없다(실측 T085 — 같은 서비스 토큰으로 30 s 간격 두 요청의 `Cf-Access-Jwt-Assertion` `iat` · §7). 전제가 틀려 Access가 JWT를 다시 쓰면 뒤처진 pod가 갓 만든 세션을 미래 `iat`로 보아 inactive를 내므로, 「닿는 길은 둘」을 셋으로 고친다(〔Z17〕 · 재검토 RB-13).
    - WARNING `session_check.iat_in_future`는 1건이라도 경보다(D25 · T098).
- **불변식**(어기면 어느 쪽으로 실패하는가)
  1. 하한 수명 ≥ 세션 최대 나이 — 두 값이 같은 상수다. 어기면(상수를 나눠 보존만 줄임) 열림: 하한이 끝난 뒤 나이 조건이 닿기 전의 세션이 산다. ia-36의 상수 동일성 단언과 api-34가 지킨다.
  2. purge 경계 = 하한 수명 경계(같은 식 · 같은 상수). 하한이 사는 동안 그 행이 DB에 있다. 어기면 열림: 재적용이 되살릴 행이 없다. ia-33이 지킨다.
  3. 하한 값은 그 sub 사용자 단위 행의 `nbf` 최댓값이다(커밋 뒤 조회 · 재적용 `DISTINCT ON`). 어기면 다음 재적용까지 열림(≤ 다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감 + 워커 재접속 — 〔W18 · Z1〕): 늦게 온 옛 행이 더 큰 하한을 낮춘다. ia-31 · 32가 지킨다.
  4. 웹훅 · 백필의 `nbf`는 이벤트 시각(⌊created⌋ + 1)이고 백필은 받은 이벤트를 다시 확인한다. 어기면 닫힘: 새로 로그인한 세션이나 활성 사용자 전원이 30일 하한에 걸린다(재로그인 한 번으로 회복). ia-13 · VD-T081-1.
  5. 미래 `nbf`는 어느 경로로도 하한에 들어가지 않는다 — 웹훅: 본문 `nbf`가 `⌊created⌋ + 1`을 넘으면 그 값으로 낮춰 기록한다(거부하지 않는다 — 기록되는 값은 늘 `⌊created⌋ + 1` 이하다 · 〔Z8〕) · 대조: `created` 재확인(위쪽 끝 `now + 300 s`) · 관리 명령: DB 시계 + 301 s를 넘으면 거부 · `/sessions/revoke`: 서버가 정한다(D12 · 〔W14〕). 어기면 닫힘: 그 시각까지 그 사용자의 새 세션이 태어나자마자 죽고, 값이 30일 동안 스스로 내려가지 않는다. ia-39 · ia-13(창 위쪽 끝 — 미래 이벤트 미끼와 변이 · 〔Z3〕).
  6. `/session/check`는 하한 조회 실패와 정수가 아닌 값을 503으로 낸다(삼키지 않는다 · DB로 메우지 않는다). 어기면 열림. ia-29 · 30.
  7. 하한 키는 `identity-admin:` 접두 아래에만 둔다. `revoked:` 아래에 쓰면 api-10 · 30이 깨진다(T066이 잡는다).
  8. 재적용(beat 30 s · `beat_init`)이 살아 있다. 어기면 유실 뒤 하한이 돌아오지 않고, 유실이 없어도 커밋 뒤 쓰기가 실패한 폐기가 복구되지 않는다(둘 다 조용함 · 〔W18〕). 신선도 키와 성공 줄 무소식 경보가 탐지다(D14 · T098).
  9. BFF: `/session/check`의 `iat` = 쿠키 `issued_at`(callback ID 토큰 `iat` · refresh에서 불변) · 세션을 쓰는 네 라우트 모두 토큰 엔드포인트 호출과 교환 캐시 사용 앞에서 확인 · 503이면 회전 0 · inactive면 RFC 7009 + 쿠키 삭제 · 캐시 키 둘에 `issued_at`. 어기면 열림이다 — 이 설계의 집행이 통째로 기대는 곳이고 T089가 고정한다(C36 · C43–C45).
  10. pod · PG · Authentik 시계가 맞아 있다(1 s 미만 — VD-T081-5).
- **실패 양상**

| 상황 | 방향 | 내용 |
|---|---|---|
| Dragonfly 장애 | 닫힘 | `/session/check` 503 → BFF 503 · 쿠키 유지 · 회전 0. 웹훅 · 관리 명령 · 대조 백필은 로그 + outbox가 커밋되고 SET 실패는 로그만 남는다(복구 뒤 재적용). `/sessions/revoke`는 미들웨어의 거부 목록 조회에서 503이라 기록 0이다(〔W18〕) |
| Dragonfly 데이터 유실(비정상 종료 · dump 삭제 · FLUSHALL) | 열림 | 재적용이 돌 때까지 하한과 `revoked:*`가 없다. 그 시간의 상한은 다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속이다 — solo 워커는 받은 순서대로 돌고 그동안의 tick은 `expires` 30으로 버려진다(〔W18 · Z1〕 · 〔편차 29〕 · 실측은 VD-T073-15). 돌아오면 다음 확인에서 다시 inactive |
| beat 정지 | 열림 | 요청 경로 SET은 계속 되지만, 유실이 없는 평시에도 커밋 뒤 쓰기가 실패한 폐기의 복구 · 일 1회 대조 · purge가 멈춘다(〔W18〕). 유실과 겹치면 하한이 돌아오지 않는다(조용함) → 탐지는 신선도 키 · 성공 줄 무소식 경보 |
| identity-admin 장애 | 닫힘 | 로그인은 된다(callback은 identity-admin을 부르지 않는다). 세션 라우트는 503 · 회전 0. 웹훅은 재시도 뒤 유실되고 대조가 메운다 |
| Authentik 장애 | 무관 / 닫힘 | 하한 쓰기 · 판정은 무관. BFF refresh · 교환은 503 |
| 시계 어긋남 | 열림 / 닫힘 | Authentik이 앞서면 열림(그 차이만큼 · 30일 상한 — 60 s를 넘으면 미래 `iat` 조건이 닫는다), pod가 앞서면 닫힘(재로그인이 한 번 튕긴다). 관리 명령은 실행 프로세스 시계가 PG보다 300 s 넘게 앞서면 거부된다(`CommandError` — 시끄럽게 드러난다). HTTP 경로의 폐기 기록은 PG 시계에 기대지 않는다(〔W14〕) |
| 로그 보존 상수 변경 | 함께 움직임 | purge · 하한 수명 · 절대 수명이 같은 상수다. api-34가 30 d ± 1 h를 고정한다 |
| DB 시점 복구(PITR) | 열림 | 복구 시점 뒤의 폐기 행이 사라지고 다음 재적용이 하한을 낮춘다(30일 상한). 런북: 전 사용자 종료 = `SESSION_ENCRYPTION_KEY` 교체(T114) |
| BFF 결함(확인 누락 · `iat` 원천 오류) | 열림 | 확인이 빠진 경로로 회전한 세션도 다음 확인에서 하한이나 나이에 걸린다. `issued_at`을 갱신하는 결함은 둘 다 무력하게 한다 |
| 오탐 폐기(백필 필터 무시 · 웹훅 비밀 유출 · `nbf` 누락) | 닫힘 | 지속이 30일이다(재로그인 한 번으로 회복). 잘못 오른 하한 내리기 = 로그 행 정정 + 키 DEL(T114) |

- **T066 영향 0**(원문 대조 — 실행은 조각 ③ · ⑤-a와 마지막 조각): 근거는 사실 ㉗이다. 하한 키는 `identity-admin:` 아래라 `revoked:*` 키 목록 단언에 보이지 않는다. `/session/check` 시험은 FLUSHALL 뒤 `revoked:*`만 두고 `iat`가 현재 시각이다. api-8은 첫 조회에서 503이다. api-21의 재전송은 어떤 키도 다시 쓰지 않는다. api-30–32는 로그 행만 넣고 `revoked:*` 결과를 본다. 표 · 열 추가가 없다(부분 인덱스 하나).
- **기각**
  - 전용 B 등급 표(영구 `session_epoch`): 허용 목록 4 → 5 개정(dc 상수 · tc-17 · 규칙 2 · 계약 2 · ADR 0007 · 승인 문면 5곳 — 〔R7〕)과 정본 이원화가 따른다. 절대 수명을 두면 30일보다 오래된 행은 판정에 쓰이지 않아 영구 보존의 실익이 없다(〔ATK-6〕). 「재로그인 없이 30일 넘게 이어지는 세션」이 요구될 때만 앞선다.
  - 카운터형(버전): 늦은 이벤트와 그 사이 새 로그인의 선후를 가리지 못하고(〔V14〕) 로그인 때 identity-admin 호출이 필요하다.
  - Authentik 속성형: 전역 `change_user` 장기 토큰 · dev 쓰기 끔 · attributes 단일 작성자 원칙에 걸린다(〔R19〕).
  - refresh 수명 27일: 폐기 3일 뒤의 무확인 회전을 덮지 못한다(〔ATK-6〕). 나이 조건이 대신한다.
  - `/session/check`가 DB로 메우기 · cold 캐시를 503으로 바꾸는 표식: 계약 「DB 접근 없음」과 api-4(FLUSHALL 직후 200)에 걸린다.
- **계약**: C3 · C4 · C5 · C7 · C12 · C13 · C24 · C39–C45 · C48 〔편차 18 · 19 · 20 · 29〕.
- **시험**(파일은 D1 · 쓰기를 지나는 시험은 pod 사용자로 돈다 — D24)
  - **ia-27**: 사용자 단위 3경로(revoke `all_devices` · 관리자 호출 · 웹훅) → 하한 값 = `nbf` · TTL = ⌊`expires_at` + 30 d − DB now⌋ ± 5(api-30과 같은 재는 법 — DB 시계 기준). 2,592,000을 넘는 `EX`를 Dragonfly가 받고 TTL로 돌려주는지의 실측이기도 하다(VD-T073-12).
  - **ia-28**: `sid` 폐기 → 하한 키 없음
  - **ia-29**(DB 마크 없음 — 키를 admin으로 직접 둔다): 하한만 있고 하한 > `iat` → `{"active": false}`(nbf 키 없음) · 하한 = `iat` → active · 하한 < `iat` → active · 하한 > `iat`이고 `revoked:sub` ≤ `iat` → `{"active": false, "nbf": <revoked:sub 값>}` · 하한 값이 정수가 아님 → 503 `denylist_unavailable`
  - **ia-30**(DB 마크 없음): (a) DRAGONFLY_URL이 블랙홀 포트 → 503 `denylist_unavailable` · `session_floor.read_floor` 호출 0(가로채 센다 — 0.2 s와 0.4 s는 시간으로 안정적으로 가르지 못한다. 같은 가로채기로 정상 요청에서 1회 불리는 것을 먼저 단언한다 — D26 「이음매」 · 〔W29〕) · 경과 1 s 미만 (b) 거부 목록 조회는 성공하고 하한 조회만 실패(`denylist_writer.client`가 닫힌 포트의 클라이언트를 돌려주게 덮는다) → 503 `denylist_unavailable` + WARNING `session_floor.lookup_failed`(그 줄에 sub · URL 없음)
  - **ia-31**: 큰 `nbf`의 사용자 단위 행이 있는 sub에 과거 `nbf` 웹훅 → 하한과 `revoked:sub` 값이 큰 `nbf` 그대로 · 같은 sub의 두 행을 역순으로 커밋해도 값 = 큰 쪽(〔Y22〕)
  - **ia-32**: 재적용의 하한 — 창 경계(`expires_at` = DB now − 30 d ± 1 h 가운데 안쪽 행만) · `sid` 행 제외 · sub별 최댓값 · TTL ± 5 · 두 번 돌려도 TTL이 늘지 않는다 · FLUSHALL 뒤 복원
  - **ia-33**: api-34와 같은 세 행으로 purge → 지워진 행의 sub는 재적용 뒤 하한이 없고 남은 두 행의 sub는 있다(purge 대상 ⇔ 하한 대상 아님). `REVOCATION_LOG_RETENTION`을 다른 값으로 덮으면 purge 경계와 재적용의 하한 창이 함께 움직인다(상수 하나 — SQL 리터럴이 남아 있으면 깨진다)
  - **ia-34**: 백필 꼴(웹훅 본문 `nbf` = 지금 − 3600) → 202 · `revoked:sub` 없음 · 하한 있음(TTL ≈ 30 d − 3270 s)
  - **ia-35**: 웹훅 재전송 → 하한 키를 다시 쓰지 않는다(재전송 전에 admin이 둔 표식 값이 그대로다)
  - **ia-36**(DB 마크 없음): HTTP로 나이 경계 — `iat` = now − 30 d − 5 → inactive · now − 30 d + 60 → active. 순수 함수 `is_active`로 초 단위 경계 — `now − iat` = 2,592,000 → active · 2,592,001 → inactive. 상수 — `SESSION_ABSOLUTE_LIFETIME is REVOCATION_LOG_RETENTION`이고 값이 30일이다(purge · 재적용이 같은 상수를 쓰는지는 ia-33)
  - **ia-37**(DB 마크 없음): HTTP로 `iat` = now + 120 → `{"active": false}` + WARNING `session_check.iat_in_future`(그 로그 줄에 `iat` 값과 sub가 없다) · now + 30 → active. 순수 함수로 `iat` = now + 60 → active · now + 61 → inactive
- **변이**: 최댓값 조회 삭제 → ia-31 · `sid IS NULL` 삭제 → ia-28 · 32 · 하한 비교를 `>=`로 → ia-29 · 재적용 창을 `expires_at > now()`로 → ia-32 · 요청 경로(D13)의 창을 같은 꼴로 → ia-34 · 하한 조회 예외 삼킴 → ia-29 · 30 (b) · 첫 조회 실패 뒤에도 하한 조회 → ia-30 (a) · 나이 조건 삭제 → ia-36 · 나이 비교를 `>=`로 → ia-36(순수 함수 경계) · 상수 분리 → ia-36 · 미래 조건 삭제 → ia-37

### D30 관리 명령 `revoke_sessions`

- **왜 T073에 넣는가**(B-11 · 〔Y23〕): 폐기 3경로의 하나인 관리자 폐기(spec:422)를 SP-1에서 부를 길이 달리 없다.
  - `/sessions/revoke`의 관리자 갈래는 `platform-admin` 그룹의 Bearer가 필요한데, pod는 Access `common_name`이 web-bff Client ID인 호출만 받는다(api계약:35).
  - BFF 프록시의 허용 경로는 `/tenants/me` · `/session/check` GET 둘뿐이다(bff:36). tester 서비스 토큰(`tester-m2m`)은 Access를 지나도 pod의 `common_name` 검사에서 403 `access_required`다(dc/auth.py:549-551 — 컨트롤러 확인).
    - 이 사실은 고정 문면 tasks:212 · 224의 「m2m 호출은 Access 서비스 토큰 `tester-m2m`」(→ `/tenants/me` 401 · `identity-m2m-dev` 200)과 양립하지 않는다. T073 코드 영향은 0이고, 측정 경로는 T079 설계가 정한다(〔편차 27〕 · §7 T079 · T085 · 〔W1〕).
  - 계정 탈취 대응(T114)과 T085의 「관리자 폐기」 측정에 실행 수단이 있어야 한다.
- **사용자 단위만이다**(〔W13〕 — 결정 Y23의 `--sid` 인자를 뺐다)
  - `--sid` 폐기는 `revoked:sid` 330 s 차단뿐이다 — 하한이 없고 위임도 없으며, BFF 로그아웃과 달리 그 자리에서 refresh를 지우는 주체도 없다. 그 세션이 330 s 안에 BFF에 닿지 않으면 효력이 0인데 출력은 성공으로 나온다(검토 B-1 — 고장 난 구성 요소 없이 성립하는 타임라인).
  - 운영자가 `sid`를 얻을 경로도 없다(Authentik 세션 목록에 sid 없음 · 쿠키는 암호문 · 로그에 sid 없음).
  - T066은 명령을 고정하지 않는다(api-51이 고정한 것은 HTTP 갈래다). 탈취 대응은 사용자 단위로 한다(§7 T114).
- **명령**: `python manage.py revoke_sessions --sub <sub>`(`management/commands/revoke_sessions.py`)
  1. 인자: `--sub` 필수. 출력 가능 ASCII(`!`–`~`) 1–255자(어기면 CommandError).
  2. `tenant_id` = `--sub`의 `TenantMembership`(D12 규칙 — 0건이면 CommandError · 여럿이면 가장 작은 `tenant_id` + WARNING). 웹훅 · 관리자 호출과 같은 원천이다.
  3. `nbf` = ⌊`time.time()`⌋ + 1.
  4. `record_revocation(tenant_id=…, sub=…, sid=None, reason="admin", nbf=…, source="command", delegate=True)`. 관문이 거부하면 CommandError다 — 이 경로만 `nbf`를 DB 시계 + 301 s와 견준다(D12 · 〔E6 · W14〕).
  5. 출력(stdout에 `revoke_sessions:`로 시작하는 줄 하나 · `sub` · 토큰 · URL 없음 · 〔W21 · Z9〕): `revoke_sessions: OK id=<uuid> nbf=<int> expires_at=<ISO 8601 UTC> denylist=<값> delegate=<값>`
     - 「stdout 한 줄」이라고 적지 않는다(〔Z9〕) — 실제 실행에서는 같은 stdout에 `configure_logging`의 JSON 로그 줄이 섞인다. 읽는 쪽은 `revoke_sessions:` 접두로 그 줄을 찾는다.
     - 두 값은 `Recorded.after`에서 읽는다(D12 — 명령 경로에서는 `record_revocation`이 돌아오기 전에 커밋 뒤 콜백이 끝난다). `denylist` = `ok` · `skipped` · `failed` · `unreachable`, `delegate` = `enqueued` · `skipped` · `off` · `failed`다. 콜백이 채우지 못한 칸은 `none`으로 찍는다.
     - `denylist`가 `ok` · `skipped`가 아니면(`failed` · `unreachable` · 채워지지 않음) 머리말을 `PARTIAL`로 바꿔 찍고 `CommandError("행은 기록됐다 — 거부 목록 쓰기 실패 · 60 s 뒤 revoked:sub와 세션 하한 키가 생겼는지 확인한다", returncode=3)`으로 끝낸다(문구에 값을 싣지 않는다 · 〔Z9 · Z10〕).
       - 종료 코드는 3이다(〔Z9〕 — 앞 라운드 〔W21〕의 값을 고쳤다 · 재검토 RB-4). 앞 라운드의 값은 argparse 사용법 오류(인자 누락 · 없어진 `--sid`를 붙임)가 내는 코드와 같아, 「행은 기록됐다」와 「아무것도 하지 않았다」가 한 코드로 읽혔다.
       - 문구는 신선도 키가 아니라 그 폐기의 키 둘을 가리킨다(〔Z10〕) — 신선도 키의 존재는 재적용이 죽은 직후 300 s 동안 거짓 생존을 말한다(D14 「키의 뜻」). 재적용이 살아 있으면 다음 tick이 키를 만들므로 60 s 뒤에 직접 본다.
     - `delegate=failed`는 종료 코드 0 그대로다 — 출력으로 드러난다(탈취 대응의 완결은 사용자 비활성화다 — §7 T114).
     - 앞 라운드의 `scope=` 칸은 없앴다(명령이 사용자 단위뿐이다).
- **효과**: 로그 행(`sid` NULL) + outbox 이벤트(reason `admin`) → 커밋 뒤 `revoked:sub` + 세션 하한 → Authentik 세션 삭제 위임(D16의 조건 — 쓰기 플래그 · 자리값 · SET 결과).
- **실행**: 운영자 `kubectl -n jt-<env> exec deploy/identity-admin -c web -- python manage.py revoke_sessions --sub <sub>`. runtime 프로필 · app role이다(`seed_tenant`와 같다). web 컨테이너의 `AppConfig.ready`가 브로커를 두므로 위임 enqueue가 된다.
- **한계**: 지표 `session_revocations_total{reason="admin"}`의 +1은 명령 프로세스의 레지스트리에만 남는다(D25). 단일 세션 폐기 수단은 없다(〔W13〕).
- 문면(tasks:190)에 없는 관리 명령이다(〔편차 17〕).
- **계약**: C38 · C4(관리자 갈래의 `sid` 폐기 한 줄) · C24 (라).
- **시험**: **ia-26**(〔W13 · W21 · Z7 · Z9〕 · 조각 ③-b2)
  - 맨 앞에 `get_commands()`에 `revoke_sessions`가 있음을 단언한다(〔Z7〕 — 명령이 없어도 `call_command`는 `CommandError`라 아래 부정 사례가 구현 전에 초록이 된다).
  - 정상(쓰기 켬 · `send_task`를 ia-11처럼 덮는다): 로그 1행(tenant = 멤버십 값 · `sid` NULL · reason `admin`) · outbox 1 · `revoked:sub` · 하한 키 · 위임 1회 · stdout에 `revoke_sessions:`로 시작하는 줄이 하나이고 그 줄이 `OK … denylist=ok delegate=enqueued`이며 sub가 없다
  - 쓰기 끔 → 출력 `delegate=off`(위임 0 · 행과 키는 같다)
  - 쓰기 켬 + DRAGONFLY_URL 닫힌 포트 → 행 1 · 출력 `PARTIAL … denylist=unreachable delegate=skipped` · `CommandError`이고 `exc.returncode == 3`(〔Z9〕)
  - 멤버십 없는 sub → CommandError · 행 0 · 키 0 / NUL · 256자 인자 → CommandError(이 부정 사례들의 짝은 위 정상 사례다 — 같은 준비물에서 `--sub`만 바꾼다 · D26 「부정 사례의 짝」)
  - `nbf` 상한 관문은 ia-39 (b).
- **변이**: 출력에 sub를 싣는다 → ia-26. `after`를 읽지 않고 늘 `OK`를 찍는다 → ia-26(닫힌 포트 사례). 쓰기 끔을 `enqueued`로 찍는다 → ia-26.

### 덮임 표(열린 질문 74)

비판과 분석을 반영한 뒤의 연결이다. 74개 모두 결정 · 인계 · VD · 사용자 결정 가운데 하나에 닿는다.

- **spec**
  - Q1 → D19 · C21 · 인계 T081
  - Q2 → D19 · 인계 T083
  - Q3 → UD-3
  - Q4 → UD-2 · C27(권한별 표)
  - Q5 → D18 · 인계 T075
  - Q6 → D6 · D18 · ia-23
  - Q7 → D18
  - Q8 → D17(UD-2 하위 확정)
  - Q9 → D16
  - Q10 → D13
  - Q11 → D20 · VD-T080-1
  - Q12 → D4
  - Q13 → D22
  - Q14 → D9 · D10 · D12
  - Q15 → D25
  - Q16 → D28 · 인계 T100
  - Q17 → D27
  - Q18 → D24
  - Q19 → D23
  - Q20 → D28(UD-6 확정)
- **tests**
  - Q1 → D4
  - Q2 → D5 · 〔편차 3〕
  - Q3 → D20
  - Q4 → D19 · UD-2
  - Q5 → UD-3
  - Q6 → D19(그룹 소속은 user.groups로 판정 · ignore 쓰기) · VD-T083-1(users 응답의 `groups` 꼴) · VD-T082-1
  - Q7 → D13 · D14 · D21 · D29
  - Q8 → D16 · D17 · D26
  - Q9 → D26
  - Q10 → D24 · ia-24 · ia-40 · VD-T073-5
  - Q11 → D6 · D23
- **template**
  - Q1 → D4
  - Q2 → D3
  - Q3 → D24
  - Q4 → D6 · D18
  - Q5 → D27
  - Q6 → D28(UD-6 확정)
  - Q7 → D23
  - Q8 → D23 · ia-18
  - Q9 → D20
  - Q10 → D3 · C34 · C35
  - Q11 → 〔편차 1 · 3〕
  - Q12 → 인계(정리)
- **external**
  - Q1 → UD-1
  - Q2 → D20 · 인계 T080
  - Q3 → D16
  - Q4 → UD-2 · C27
  - Q5 → D29(UD-5 확정) · C43–C45
  - Q6 → UD-4
  - Q7 → D21 · 인계 T081
  - Q8 → D21(창 유지 · 유실분은 D17 + D29)
  - Q9 → D21 · 인계 T081
  - Q10 → D21
  - Q11 → D17(UD-2 하위 확정)
  - Q12 → D16
  - Q13 → D28(UD-6 확정)
  - Q14 → D5
  - Q15 → D4
  - Q16 → 인계(정리)
- **library**
  - Q1 · Q2 → D13
  - Q3 → D10 · D12(관문)
  - Q4 → D13 · D14
  - Q5 → D12
  - Q6 → D4
  - Q7 · Q8 → D13
  - Q9 → D24
  - Q10 → D9
  - Q11 → D22
  - Q12 → D22 · ia-17
  - Q13 → D19
  - Q14 · Q15 → D28

---

## 4. 계약 · 규칙 보정 목록(표식 「T073 보정 2026-11-12」)

읽는 법은 다음과 같다.
- 항목마다 `파일`(소제목) · 절(현재 줄 번호 — 줄은 문장으로 다시 찾는다) · **확정 문면** · 소속 커밋을 적는다. 코드 블록 안의 글이 문서에 들어가는 문장이다(글자 그대로 — 표 칸 구분과 줄 나눔은 대상 문서의 꼴에 맞춘다). 항목 줄이 「A / B」처럼 자리를 여럿 적었으면 블록의 줄은 그 순서대로 한 줄씩이다. 항목 줄이 행 · 항목 · 절을 「더한다」 · 「…로 바꾼다」고 적은 블록은 블록 전체가 그 한 자리에 들어간다.
- 소속은 〈설계 커밋〉(이 문서와 함께 — C1–C33 · C36–C49)과 〈조각 ⓪〉(템플릿 파일 — C34 · C35) 둘이다.
- 번호: 초안의 C1–C35를 잇고(C31은 비운다 — contracts/events.md는 무변경) 비판 · 분석 반영이 C36–C47을, 검토 반영이 C48 · C49와 여러 하위 항목을 더했다.
- **검토 반영 라운드의 표기**(〔W n〕): 아래 블록은 모두 검토 반영 뒤의 확정 문면이다. 앞 라운드에 이미 문서에 들어간 문장을 바꾸는 항목은 설명 줄에 「(W n — 앞 라운드 문면을 바꾼다)」를 적었고, 새로 넣는 문장은 새 하위 항목이나 새 C 번호(C48 · C49)로 더했다. 설명 줄에 W 표기가 없는 항목은 앞 라운드에 반영된 문면 그대로다(다시 반영할 것이 없다). 줄 번호는 앞 라운드 그대로 보정 전(HEAD `3626d16`) 기준이고, 검토 반영으로 새로 가리키는 자리는 문장으로 적었다(작업 트리의 줄 번호를 적은 곳에는 「작업 트리 기준」이라고 밝혔다).
- **표식 횟수**(〔W35〕): 앞 라운드가 하위 항목마다 실어 준 표식은 그대로 둔다(한 칸에 여럿이어도 된다). 검토 반영으로 새로 넣는 문장은 그 문단 · 칸에 「T073 보정 2026-11-12」가 아직 없을 때만 하나를 단다 — 이미 표식이 있는 문단 · 칸에 덧붙이는 문장에는 달지 않았다.
- **재검토 반영(마감 라운드)의 표기**(〔Z n〕 · 〔Z22〕): 검토 반영 뒤 문서에 들어간 문장을 다시 바꾸는 항목은 설명 줄에 「(Z n — 앞 라운드 문면을 바꾼다)」와 바뀌는 옛 구절을 적었다 — C3 · C4 (마) · C5 (가) · C10 · C38 · C13 (나) · C48 · C45 (바) · C24 (가) · (자) · C27 (나) · C33 (가) · (다). 새로 넣는 문장은 새 하위 항목으로 더했다 — C5 (라) · C42 (다) · C45 (사)(새 C 번호는 없다 · 셋 다 표식이 이미 있는 문단 · 칸이라 표식을 더 달지 않는다). 「(Z5 — …)」로 적은 셋(C7 (다) · C37 · C26 (다))은 이 블록 쪽을 문서 글자에 맞춘 것이라 문서는 그대로다. C5 (다)의 「(Z21 — 바뀌는 것 없음)」과 C42 (가) · (나)의 이름 붙이기도 문서를 바꾸지 않는다. 설명 줄에 Z 표기가 없는 항목은 검토 반영 뒤의 문면 그대로다(다시 반영할 것이 없다). 「바뀌는 옛 구절」은 대상 문서의 지금 문장을 작업 트리에서 읽어 확인한 것이다.
- 사용자 결정이 남은 곳(UD-1 · UD-2 본체 · UD-3 · UD-4 · UD-7 · UD-8)은 어느 답이든 참인 사실만 적고 「T081 전 결정」처럼 대기를 문면에 밝힌다. 결정 뒤의 문면은 그 과제가 고친다(§8).
- 승인 고정 문면(spec · plan · tasks)과 달라지는 것은 §1 「report.md 편차 후보」에 모았다.

### contracts/identity-admin-api.md

- **C1** — :3 첫 문장의 괄호 〈설계 커밋〉
  - 지금: 「(`ninja==1.7.0` 정확 핀, 회귀 시 1.6.2 폴백)」
  ```text
  (`ninja==1.7.0` 정확 핀 · 회귀 시 폴백은 1.6.5 — 이 계약 · contracts/pod-template.md 생성 트리 pyproject 행 · 템플릿 핀 · 하네스 `_tree.py` NINJA_SPEC을 함께 고친 뒤에만 · T073 보정 2026-11-12)
  ```
- **C2** — :17 「외부 요청은 …」 항목 〈설계 커밋〉
  - 「관리 API·revoke는」을 「관리 API(세션 삭제 위임 · 일 1회 대조 · 시드)는」으로 바꾸고, 항목 끝에 한 문장을 덧붙인다.
  ```text
  `:9000`은 Authentik Service 포트다 — 차트 기본 Service 포트는 80(→ pod 9000)이므로 T080이 `server.service.servicePortHttp: 9000`을 둔다(NetworkPolicy는 pod 포트 9000 그대로 · T073 보정 2026-11-12).
  ```
- **C3** — :56 `GET /session/check` 행의 「동작」 칸 전체 〈설계 커밋〉(D8 · D29 · 〔E2 · E3 · E4 · Y21 · W4 · W15 · Z17〕)
  - (W4 · W15 — 앞 라운드 문면을 바꾼다) 두 곳이 바뀐다: 「`now`는 pod 시계다.」 뒤에 미래 값의 도달 조건 두 문장을 넣고(W15), 「응답 `nbf`는 …」 문장의 괄호를 고친다(W4 — 앞 라운드 괄호 「(active여도 싣는다 · T066 보정 2026-11-03 — ③ · ④만으로 inactive면 `{ "active": false }`다)」). 나머지는 앞 라운드 그대로다.
  - (Z17 — 앞 라운드 문면을 바꾼다) 한 곳이 바뀐다: 문장 「pod 시계가 뒤처진 경우는 이 경로의 Access JWT `iat` 검사가 먼저 403을 내 BFF가 503으로 접고 쿠키를 지킨다.」의 마침표 앞에 추론 표시 「(추론 — Access가 서비스 토큰 요청마다 `iat`를 새로 찍는다는 전제 · 실측 T085)」를 넣는다. 나머지는 검토 반영 뒤 그대로다.
  ```text
  Dragonfly 조회만 한다 — 거부 목록 조회(`Denylist.lookup` 1회)와 세션 하한 조회(뷰 소유 클라이언트의 `GET identity-admin:session-floor:{sub}` 1회 · 0.2 s · 재시도 0 — contracts/denylist.md §키 스키마). DB 접근 없음. 쿼리 `sub`(필수) · `iat`(필수 정수 epoch 초 — **BFF 세션 시작 시각**(쿠키 `issued_at` — contracts/bff-api.md §세션 쿠키)이다. refresh마다 바뀌는 토큰 `iat`가 아니다) · `sid`(선택 — `sid=` 빈 값은 400 · BFF는 `sid`가 없으면 쿼리에서 뺀다 · T070 r2). `sub` · `sid`는 출력 가능 ASCII(`!`–`~`) 1–255자다(공백 · 제어 문자 · 비ASCII · 256자 이상은 400). **`active` = 아래 넷이 모두 아닐 때**: ① `revoked:sub:{sub}` 값 > `iat` ② `sid`가 있고 `revoked:sid:{sid}`가 있음 ③ 세션 하한 값 > `iat` ④ `now − iat > 30 d`(세션 절대 수명 — 로그 보존과 같은 상수) 또는 `iat > now + 60 s`(미래 값 — WARNING `session_check.iat_in_future`). ① · ③은 값이 `iat`와 같으면 active다(미들웨어 4단계와 같은 "초과일 때만 폐기" 비교). `now`는 pod 시계다. 미래 값에 닿는 길은 둘뿐이다 — Authentik 시계가 pod보다 60 s 넘게 앞섬 · BFF 결함(ms epoch · `exp` 같은 값을 보냄). pod 시계가 뒤처진 경우는 이 경로의 Access JWT `iat` 검사가 먼저 403을 내 BFF가 503으로 접고 쿠키를 지킨다(추론 — Access가 서비스 토큰 요청마다 `iat`를 새로 찍는다는 전제 · 실측 T085). 판정 순서: 쿼리 검증(400 — 조회 앞 · `Denylist.lookup`은 빈 값에 `ValueError`다 · 뷰는 모듈 수준 `Denylist` 하나를 재사용한다 · T070 r2) → 거부 목록 조회(실패 = 503 · 하한 조회를 하지 않는다) → 세션 하한 조회(실패 · 정수가 아닌 값 = 503) → 판정. 응답 `nbf`는 `revoked:sub:{sub}` 키가 있을 때만 그 값(정수)으로 싣는다(active여도 싣는다 · T066 보정 2026-11-03 — 그 키가 없으면 ③ · ④로 inactive여도 `{ "active": false }`다). Dragonfly 실패 → 503 `denylist_unavailable`(조회마다 0.2 s · 재시도 0). 세션 하한 · 절대 수명 · 미래 값 · 문자 규칙 = T073 보정 2026-11-12
  ```
- **C4** — :57 `POST /sessions/revoke` 행의 「동작」 칸 〈설계 커밋〉(D9 · D12 · D13 · D16 · 〔Y1 · Y12 · Y18 · Y21 · Y22 · E1 · E6 · W3 · W10 · W13 · W14 · Z21〕)
  - 검토 반영으로 바뀌는 것은 (다)의 세 곳과 새 하위 항목 (마)다. 「응답」 칸은 그대로다 — 500을 더하지 않는다(W14로 이 경로의 관문 500이 없어진다 · W10). 재검토 반영으로 바뀌는 것은 (마)의 첫 줄 하나다(Z21 — 잇닿은 괄호를 합친다).
  - (가) 「본인은 `sub` 생략(토큰의 sub · 토큰과 같은 `sub`를 적어도 본인 호출).」 뒤에 넣는다.
  ```text
  **판정 순서(T073 보정 2026-11-12)**: 본문 검증(400) → 다른 `sub`인데 관리자가 아님(403 `forbidden`) → 조합 검증(400) → `tenant_id` · `sid` 결정(400) → 기록. 조합: 본인 호출은 `reason`이 `logout`이면 `all_devices: false`, `logout_all`이면 `true`여야 하고(`admin`은 쓸 수 없다), 다른 `sub`를 지정한 관리자 호출은 `reason: "admin"`만이다. 쓰기에 들어가는 `sub` · `sid`는 본문 · 토큰 어느 쪽에서 왔든 출력 가능 ASCII(`!`–`~`) 1–255자여야 하고 어기면 400이다. 4xx 판정은 전부 쓰기 앞에서 끝낸다.
  ```
  - (나) 「…**관리자 호출(다른 `sub` 지정)은 `TenantMembership`에서 그 `sub`로 조회**한다 — 없으면 400 `validation_error`.」 뒤에 넣는다.
  ```text
  멤버십이 여럿이면(SP-1 가정 「사용자당 테넌트 1」이 깨진 경우) `tenant_id`가 가장 작은 행을 쓰고 WARNING `identity.multiple_memberships`를 남긴다 — 키가 `sub` 단위라 폐기 효과는 같다(T073 보정 2026-11-12).
  ```
  - (다) 「→ 커밋 후 Dragonfly `SET … EX 330` → Authentik revoke API(서비스 계정 `identity-admin` 토큰, svc DNS; 실패해도 거부 목록은 유효, Celery 5 s × 3회 지수 백오프 최대 5분 — **요청 처리 중에는 Authentik을 부르지 않는다**: 커밋 뒤 비동기 위임만).」을 아래로 바꾼다.
    - (W3 · W13 · W14 — 앞 라운드 문면을 바꾼다) 앞 라운드에 넣은 이 문단에서 세 곳이 바뀐다. ① 「… 서비스 계정은 남의 refresh 토큰을 지울 수 없다」 뒤에 실측 표시 「(소스 판독 2026.8.0 — 실측 T081 · VD-T081-4)」를 단다(W3). ② 문장 「기록 관문이 `nbf > DB now() + 301 s`인 기록을 거부한다(이 경로의 `nbf`는 서버가 정하므로 시계 고장일 때만 걸린다 — 500 `internal_error`).」를 뺀다(W14 — 이 경로에는 `nbf` 상한 비교가 없다). ③ 문단 끝(「… BFF의 refresh 폐기로만 집행된다(BFF의 기본 로그아웃 범위는 T089 전 사용자 결정 · 실측 T081).」 뒤)에 관리자 갈래 문장을 더한다(W13).
  ```text
  → 커밋 후 Dragonfly SET(T073 보정 2026-11-12 — contracts/denylist.md §쓰기 규약): `sid` 행은 `SET revoked:sid:{sid} 1 EX min(330, ⌊expires_at − 현재 시각⌋)`, 사용자 단위 행은 DB에서 그 `sub`의 사용자 단위 행 가운데 `nbf`가 가장 큰 행을 한 번 읽어 `revoked:sub:{sub}` = 그 `nbf`(`EX min(330, ⌊그 행 expires_at − 현재 시각⌋)`)와 세션 하한 키 `identity-admin:session-floor:{sub}` = 그 `nbf`(`EX ⌊그 행 expires_at + 30 d − DB now()⌋`)를 한 파이프라인으로 쓴다. TTL이 1 미만인 키는 쓰지 않는다. 쓰기는 0.2 s · 재시도 0이고, 실패해도 202다 — 로그만 남기고 30 s 재적용이 되살린다(Celery 재시도를 넣지 않는다 — 브로커가 같은 Dragonfly다). → **Authentik 세션 삭제 위임**(사용자 단위 폐기에서만): Celery 작업 `identity_admin.tasks.revoke_authentik_sessions`가 서비스 계정 토큰 · svc DNS로 그 사용자의 Authentik 세션을 지운다(재시도는 §주기 작업 표 · 실패해도 거부 목록은 유효 — **요청 처리 중에는 Authentik을 부르지 않는다**: 커밋 뒤 비동기 위임만). `sid` 단위 폐기는 위임하지 않는다(Authentik은 `sid`로 세션을 찾을 수 없다). 같은 콜백의 SET이 연결 오류로 실패했으면 위임을 넣지 않는다. Authentik은 세션을 지워도 refresh 토큰을 남기고 서비스 계정은 남의 refresh 토큰을 지울 수 없다(소스 판독 2026.8.0 — 실측 T081 · VD-T081-4) — refresh 폐기는 BFF의 RFC 7009(contracts/bff-api.md)가, 폐기 전에 시작한 세션의 종료는 세션 하한과 절대 수명(`/session/check` 행)이 맡는다. **pod 경계의 한계**: BFF가 pod를 부를 때 쓰는 교환 토큰에는 `sid` 클레임이 없어 pod 미들웨어는 `revoked:sid:{sid}`를 볼 일이 없다 — pod의 즉시 거부(같은 access 토큰 401)는 사용자 단위 폐기에서만 성립하고, `sid` 단위 폐기는 BFF의 `/session/check`(`sid` 질의)와 BFF의 refresh 폐기로만 집행된다(BFF의 기본 로그아웃 범위는 T089 전 사용자 결정 · 실측 T081). 관리자 갈래(`reason: admin` · `all_devices: false`)가 일으킨 `sid` 폐기에는 refresh 폐기가 따르지 않는다 — 그 세션이 330 s 안에 BFF에 닿지 않으면 효력이 없다(SP-1에는 이 갈래를 부르는 호출자가 없다).
  ```
  - (라) 「**dev는 Authentik revoke 호출을 설정 플래그(`AUTHENTIK_WRITES_ENABLED=false`)로 비활성**(…)」 괄호 끝에 덧붙인다(앞 라운드 그대로 — 이 문장의 머리 낱말은 (마)가 바꾼다).
  ```text
  자격이 자리값(`PLACEHOLDER-` 포함)이면 env와 무관하게 위임하지 않는다 — §identity-admin 전용 설정 · T073 보정 2026-11-12
  ```
  - (마) 같은 칸에 남은 옛 문장 셋을 바꾼다(W10 — 새 문장과 글자로 어긋나던 T073 이전 문장이다 · 칸에 표식이 이미 있어 더 달지 않는다): 「`all_devices: true` → `sid` NULL 행 + `revoked:sub:{sub}` = `nbf`(본문 `sid`는 쓰지 않는다)」 / 「**dev는 Authentik revoke 호출을 설정 플래그(`AUTHENTIK_WRITES_ENABLED=false`)로 비활성**」 / 「처리마다 `session_revocations_total{reason}` +1.」
    - (Z21 — 앞 라운드 문면을 바꾼다) 첫 줄에서 W10이 넣은 괄호가 기존 괄호와 잇닿아 있었다(「= `nbf`(같은 `sub`의 사용자 단위 행이 여럿이면 가장 큰 `nbf` — 아래 커밋 후 SET)(본문 `sid`는 쓰지 않는다)」) — 괄호 하나로 합친다. 둘째 · 셋째 줄은 그대로다.
  ```text
  `all_devices: true` → `sid` NULL 행 + `revoked:sub:{sub}` = `nbf`(같은 `sub`의 사용자 단위 행이 여럿이면 가장 큰 `nbf` — 아래 커밋 후 SET · 본문 `sid`는 쓰지 않는다)
  **dev는 Authentik 세션 삭제 위임을 설정 플래그(`AUTHENTIK_WRITES_ENABLED=false`)로 비활성**
  커밋 뒤 `session_revocations_total{reason}` +1(§관측).
  ```
- **C5** — :58 `POST /webhooks/authentik` 행의 「동작」 칸과 :64 §웹훅 서명 규약 〈설계 커밋〉(D10 · D12 · D21 · 〔Y12 · Y17 · Y21 · E6 · E7 · W3 · W10 · W14 · Z8 · Z21〕)
  - (가) :58 「…`action`이 없거나 문자열이 아니면 400 `validation_error`(T066 보정 2026-11-03).」 뒤에 넣는다.
    - (W3 · W14 — 앞 라운드 문면을 바꾼다) 앞 라운드에 넣은 이 문단에서 두 곳이 바뀐다. ① 문장 「본문 `nbf`는 0 이상이어야 하고, 기록 관문이 `nbf > DB now() + 301 s`를 거부한다(400 — 301은 시각 창 +300 s 끝에서 매핑 `nbf = ⌊created⌋ + 1`이 내는 값이다).」를 아래의 「본문 `nbf`가 있으면 … 이 비교를 하지 않는다.」 문장들로 바꾼다(W14 — 상한 = `⌊created⌋ + 1` · DB 시계를 보지 않는다 · 상한을 넘는 값의 처리는 아래 Z8이 다시 고쳤다). ② `session_deleted` 문장의 괄호에 실측 표시를 넣는다(W3).
    - (Z8 — 앞 라운드 문면을 바꾼다) 검토 반영이 넣은 문장 「본문 `nbf`가 있으면 0 이상이고 `⌊created⌋ + 1` 이하여야 한다(`created` = 서명 검증이 읽은 본문 `created` · 넘으면 400 — `created`가 이미 pod 시계 ±300 s 안이라 `nbf ≤ pod 시각 + 301 s`가 같은 본문 안에서 나오고, 매핑이 `nbf`를 잘못 계산한 것도 400으로 드러난다).」을 아래의 「본문 `nbf`가 있으면 0 이상이어야 한다(음수는 400). … 본문 값 그대로 쓴다.」 다섯 문장으로 바꾼다 — 상한을 넘는 값은 거부하지 않고 `⌊created⌋ + 1`로 낮춰 기록한다. 바로 뒤 문장 「본문 `nbf`가 없어 서버가 정하는 값에는 이 비교를 하지 않는다.」와 나머지는 검토 반영 뒤 그대로다.
  ```text
  **판정 순서와 입력 규칙(T073 보정 2026-11-12)**: `request.get_host()`(밖 Host는 400 `invalid_host`) → 서명 · 시각(401) → `action`(없음 · 문자열 아님은 400 / 폐기 대상이 아닌 문자열은 `sub` · `nbf` · `pk` 꼴을 보지 않고 200 `{}`) → `sub` · `nbf` · `pk` 꼴(400) → 재전송(200 `{}` — 멤버십 조회 앞이라 재전송은 늘 멱등이다) → 멤버십(없으면 400 · 여럿이면 `tenant_id`가 가장 작은 행 + WARNING `identity.multiple_memberships`) → 기록(202 `{ id, nbf, expires_at }`). `sub` · `pk`는 출력 가능 ASCII(`!`–`~`) 1–255자다. `pk`가 UUID로 읽히면(hex 32자 · 8-4-4-4-12 꼴) 대시 소문자 정규형으로 바꿔 `event_pk`에 저장한다 — 매핑이 hex 꼴을 보내도 일 1회 대조의 pk와 한 행이 된다. 본문 `nbf`가 있으면 0 이상이어야 한다(음수는 400). 상한은 `⌊created⌋ + 1`이다(`created` = 서명 검증이 읽은 본문 `created`) — 넘으면 거부하지 않고 그 값으로 낮춰 기록하고(202 · 응답과 로그 행의 `nbf`가 낮춘 값이다) WARNING `webhook.nbf_clamped`를 남긴다. 서명이 맞고 시각 창 안인 로그아웃을 보조 필드 때문에 버리지 않는다(거부하면 Authentik 재시도가 모두 같은 응답으로 끝나 그 로그아웃이 유실된다). `created`가 이미 pod 시계 ±300 s 안이라 기록되는 값은 `pod 시각 + 301 s` 이하다 — 미래 값이 세션 하한으로 들어가지 않는다. `⌊created⌋ + 1` 이하인 값(과거 값 포함)은 본문 값 그대로 쓴다. 본문 `nbf`가 없어 서버가 정하는 값에는 이 비교를 하지 않는다. 커밋 뒤 쓰기는 `/sessions/revoke`의 사용자 단위 행과 같다(`revoked:sub` + 세션 하한 키). Authentik 세션 삭제 위임은 하지 않는다(출처가 Authentik이다). `session_deleted`는 Authentik 2026.8이 만들지 않는 action이다(세션 삭제는 이벤트를 남기지 않는다 · 소스 판독 — 실측 T081 · VD-T081-1) — 받아도 해가 없어 그대로 둔다(이 경로의 정의는 T081 전 사용자 결정).
  ```
  - (나) :64 「`nbf`(정수 epoch 초 · 선택 — 없으면 `/sessions/revoke`와 같은 규칙: 수신 시각 epoch 초 내림 + 1 · …)」 문장 뒤에 넣는다.
  ```text
  본문 `nbf`가 없으면 pod는 WARNING `webhook.nbf_missing`을 남긴다 — 수신 시각이 세션 하한 값이 되어 재시도 지연(최대 300 s) 동안 새로 로그인한 세션까지 걸리므로 T081 매핑은 `nbf = ⌊event.created⌋ + 1`을 반드시 싣는다(T073 보정 2026-11-12).
  ```
  - (다) :58 같은 칸에 남은 옛 문장을 바꾼다(W10 — 칸에 표식이 이미 있어 더 달지 않는다): 「**항상 사용자 단위**: `sid` NULL 행 + `revoked:sub:{sub}` = `nbf` — 본문 `sid`는 쓰지 않는다」
    - (Z21 — 바뀌는 것 없음) 이 줄에서는 W10이 넣은 괄호가 다른 괄호와 잇닿지 않는다(「= `nbf`(…) — 본문 `sid`는 쓰지 않는다」 — 바깥 괄호 안에 든 꼴이다). 합칠 곳은 `/sessions/revoke` 행의 C4 (마) 첫 줄 하나다.
  ```text
  **항상 사용자 단위**: `sid` NULL 행 + `revoked:sub:{sub}` = `nbf`(같은 `sub`의 사용자 단위 행이 여럿이면 가장 큰 `nbf` — 아래 커밋 후 SET) — 본문 `sid`는 쓰지 않는다
  ```
  - (라) :64 §웹훅 서명 규약의 `nbf` 설명 끝 — (나)가 넣은 문장(「… `nbf = ⌊event.created⌋ + 1`을 반드시 싣는다(T073 보정 2026-11-12).」) 바로 뒤에 넣는다(Z21 — 새 항목 · 이 절만 읽어도 Z8의 상한 규칙에 닿게 · 문단에 (나)의 표식이 이미 있어 더 달지 않는다).
  ```text
  본문 `nbf`의 상한은 `⌊created⌋ + 1` — 넘으면 그 값으로 낮춰 기록한다(표 참조).
  ```
- **C6** — :71-75 §이벤트(발행) 표 〈설계 커밋〉(D22)
  - `identity-admin.session.revoked` 행의 「트리거」 칸
  ```text
  `/sessions/revoke` · 웹훅 · 일 1회 대조 보정 · 관리 명령 `revoke_sessions`(T073 보정 2026-11-12)
  ```
  - `identity-admin.user.registered` 행의 「data」 칸 / `identity-admin.tenant.created` 행의 「data」 칸(스키마 파일이 정본)
  ```text
  `{ sub, email_hash?, tenant_id, role, registered_at }`
  `{ tenant_id, slug, display_name }`
  ```
  - 표 아래에 한 줄(W6 — 이 블록을 문서에 들어간 글자와 맞췄다: 「표의 아래 두 토픽은」 · 문서는 그대로다)
  ```text
  SP-1의 `OWNED_EVENTS`(pod `events/__init__.py`)는 `session.revoked` 하나다 — 표의 아래 두 토픽은 스키마만 있고 KafkaTopic과 발행 코드가 없다(SP-2가 스키마 · KafkaTopic과 함께 copier 답을 고치고 다시 생성한다 · T073 보정 2026-11-12).
  ```
- **C7** — :79-87 §주기 작업 표 〈설계 커밋〉(D14–D17 · 〔Y16 · Y17 · E1 · E5 · E8 · W2 · W16 · W30 · Z5〕)
  - (가) `reconcile_denylist` 행의 「내용」 칸 끝에 덧붙인다(W16 — 앞 라운드 문면을 바꾼다: 신선도 키 문장의 「`EX 120`으로 쓴다(행이 0이어도 쓴다 — 재적용 생존 신호)」가 아래 꼴이 된다).
  ```text
  같은 키로 가는 행이 여럿이면 `nbf`가 가장 큰 행의 값 · TTL을 쓰고, 남은 TTL이 1초 미만인 키는 건너뛴다(`EX 0`은 오류다). **세션 하한(T073 보정 2026-11-12)**: 같은 실행에서 `sid`가 NULL이고 `expires_at + 30 d > now()`인 행을 `sub`별로 묶어 `nbf`가 가장 큰 행으로 `identity-admin:session-floor:{sub}` = 그 `nbf`를 다시 SET한다(TTL = 그 행 `expires_at + 30 d − now()` 초 내림 · 1 미만이면 건너뜀 — contracts/denylist.md §키 스키마). 끝에 신선도 키 `identity-admin:denylist:reapplied-at` = epoch 초를 `EX 300`으로 쓴다(행이 0이어도 쓴다 — 재적용 생존 신호: 최근 300 s 안에 재적용이 끝나 Dragonfly까지 닿았다). 작업은 건수 `{ rows, keys, floors, skipped, failed }`를 반환한다(Celery 성공 줄이 그 값을 찍는다 — 이 줄이 5분 끊기면 경보다 · T098). beat 항목은 `expires` 30 s를 둔다(밀린 tick을 쌓아 두지 않는다). `beat_init`의 1회 실행도 하한과 신선도 키를 같이 쓴다.
  ```
  - (나) `reconcile_authentik_sessions` 행의 「내용」 칸 전체(W2 — 앞 라운드 문면을 바꾼다: 문장 「권한 `view_event` · `view_user`가 없으면(403) WARNING `authentik.reconcile_forbidden` 한 줄 뒤 끝난다(다음 날 다시 — dev 수행 여부는 권한 부여를 따른다 · data-model §9).」가 아래의 「권한이 없을 때(…): … dev 수행 여부는 권한 부여를 따른다(data-model §9).」 세 문장이 된다. 나머지는 앞 라운드 그대로다)
  ```text
  Authentik events API(서비스 계정 토큰 · svc DNS)의 logout 이벤트를 최근 72시간 창으로 읽어, `event_pk`가 로그에 없는 이벤트를 웹훅과 같은 기록 경로로 보정한다(reason `authentik_webhook` · `nbf` = 이벤트 `created` 내림 + 1 · 멱등 = `event_pk` 정규형). 세션 목록 API와는 대조하지 않는다 — 세션 목록에는 `sid`도 지워진 세션의 흔적도 없어 무엇을 보정할지 끌어낼 수 없다. 받은 이벤트는 클라이언트 쪽에서 다시 확인한다(action이 정확히 `logout` · `created`가 창 안 · `user.pk`가 정수 — 아니면 건너뛴다 · 정렬에 기대어 일찍 멈추지 않는다 · 쪽 상한 50에 닿으면 WARNING `authentik.reconcile_truncated`). 보정 행은 이벤트 시각이 `nbf`라 `revoked:sub`는 대개 TTL이 지나 쓰이지 않고 세션 하한 키만 남는다. 권한이 없을 때(소스 판독 기준 · 실측 T081 — VD-T081-2): `view_event`가 없어 이벤트 조회가 401 · 403이면 WARNING `authentik.reconcile_forbidden` 한 줄 뒤 끝난다(다음 날 다시 — 오류 없이 빈 목록이 오는 계정 형이면 경고 없이 `seen` 0으로 끝난다). `view_user`가 없어 사용자 조회가 401 · 403이면 같은 갈래이고, 404면 그 이벤트를 건너뛴다(전부 404면 WARNING `authentik.reconcile_skipped reason=user_lookup`). dev 수행 여부는 권한 부여를 따른다(data-model §9). Authentik에 쓰지 않으므로 `AUTHENTIK_WRITES_ENABLED`와 무관하다. 한 번 실행의 전체 마감은 120 s이고 첫 일시 오류(429 · 5xx · 시간 초과)에서 멈춘다(재시도 없음). T073 보정 2026-11-12 — 이전 문구 「Authentik 활성 세션 API와 대조」
  ```
  - (다) `session_revocation_log` purge 행의 「내용」 칸 끝에 덧붙인다(Z5 — 이 블록을 문서에 들어간 글자와 맞췄다: 표 칸 끝이라 마침표가 없다 · 문서는 그대로다).
  ```text
  구현 식은 같은 뜻의 `expires_at < now() − 30 d`다(인덱스를 탄다). 이 30일은 세션 하한 수명 · `/session/check`의 세션 절대 수명과 같은 상수 하나다 — 따로 바꾸지 않는다(T073 보정 2026-11-12)
  ```
  - (라) 「Authentik revoke 재시도 | 이벤트 | 5 s × 3회 지수 백오프(최대 5분)」 행 전체(W30 — 앞 라운드 문면을 바꾼다: 괄호 「(204 · 404 = 성공 · `bulk_delete`는 쓰지 않는다)」가 아래 꼴이 된다)
  ```text
  | Authentik 세션 삭제 위임 `identity_admin.tasks.revoke_authentik_sessions` | 이벤트(사용자 단위 폐기의 커밋 뒤) | 본체: 사용자 조회(`?uuid=<sub>`) → 세션 목록(`?user__username=` — 응답의 `user`가 그 사용자 pk인 것만 · 10쪽 상한) → 세션마다 단건 `DELETE`(204 = 지움 · 404 = 이미 없음 — 둘 다 그 세션의 처리를 끝내되 로그 `authentik.revoke_done`의 `deleted` · `gone`으로 갈라 센다 · `bulk_delete`는 쓰지 않는다). HTTP 타임아웃 5 s · 한 시도 전체 마감 20 s. 일시 오류(429 · 5xx · 시간 초과 · 연결)만 재시도한다 — 대기 5 → 10 → 20 s(지수 · jitter 없음) · 3회(시도 4회). 위임 창 = `nbf + 300 s`(메시지 `expires`와 작업 안 검사 — 묵은 위임이 그 사이 새로 로그인한 세션을 지우지 않게). 401 · 403 · 그 밖의 4xx는 재시도하지 않는다(로그). 문면 「5 s × 3회 지수 백오프(최대 5분)」의 해석이다(T073 보정 2026-11-12) |
  ```
- **C8** — :89-105 §identity-admin 전용 설정 〈설계 커밋〉(D6 · D18 · 〔Y5 · Y20 · Y21〕)
  - (가) `AUTHENTIK_API_URL` 행의 「규칙」 칸 끝 / `OPENFGA_API_URL` 행의 「규칙」 칸 끝
  ```text
  스킴은 http · https만이고 사용자 정보 · 쿼리 · 조각이 없어야 하며 경로는 빈 값이나 `/`뿐이다(어기면 기동 실패 · T073 보정 2026-11-12). `:9000`의 전제는 §호스트.
  URL 꼴 규칙도 `AUTHENTIK_API_URL`과 같다(T073 보정 2026-11-12).
  ```
  - (나) `AUTHENTIK_API_TOKEN` 행의 「규칙」 칸 전체
  ```text
  `Authorization: Bearer`. 주체: prod 서비스 계정 `identity-admin` · dev `identity-admin-ro`(권한은 data-model §9 「서비스 계정 권한」 표 · T073 보정 2026-11-12)
  ```
  - (다) `AUTHENTIK_WEBHOOK_SECRET` 행의 「기본값」 칸 전체
  ```text
  없음(필수 · 비밀 · 빈 값과 32자 미만은 기동 실패 — T073 보정 2026-11-12)
  ```
  - (라) `AUTHENTIK_WRITES_ENABLED` 행의 「규칙」 칸 전체
  ```text
  Authentik **쓰기** 호출 둘 — 세션 삭제 위임 · `seed_tenant`의 그룹 소속·attribute — 의 여부. 거짓이면 쓰기를 시도하지 않고 로그만 남긴다(읽기 — `seed_tenant`의 그룹 · 사용자 조회와 일 1회 대조 — 는 한다. 대조의 보정은 Authentik 쓰기가 아니라 자기 DB 기록이라 이 플래그와 무관하다). 기본값이 거짓인 것은 fail-safe다(dev 토큰은 쓰기 권한이 없다). ConfigMap 값은 늘 명시 문자열 `"true"` · `"false"`다 — 빈 문자열은 기동 실패다(T073 보정 2026-11-12)
  ```
  - (마) 표 아래 항목 목록 끝에 한 항목을 더한다.
  ```text
  - **자리값 자격(T073 보정 2026-11-12)**: 게이트 2(contracts/pod-template.md §런타임 계약 설정 행)의 면제 상수 `PLACEHOLDER_EXEMPTABLE`은 identity-admin에서 정확히 `AUTHENTIK_API_TOKEN` · `OPENFGA_STORE_ID` · `OPENFGA_PRESHARED_KEY` 셋이다(나가는 쪽 자격의 닫힌 상한). `AUTHENTIK_WEBHOOK_SECRET` · `AUTHENTIK_JWKS_URL` · `AUTHENTIK_ISSUER`는 면제할 수 없다(들어오는 쪽 검증 값 — data-model §8). 면제된 자리값 자격으로는 외부를 부르지 않는다 — 세션 삭제 위임과 일 1회 대조는 건너뛰고 WARNING `authentik.calls_disabled`를 남기며, `seed_tenant`는 `CommandError`다.
  ```
  - (바) `AUTHENTIK_API_URL` 행의 「규칙」 칸 머리의 옛 문장을 바꾼다(W10 — C2가 §호스트에서 고친 표현과 맞춘다 · 칸에 표식이 이미 있어 더 달지 않는다): 「관리 API·revoke·세션 API의 base URL」
  ```text
  관리 API(사용자 · 그룹 · 세션 · 이벤트)의 base URL
  ```
- **C9** — :111-121 §타임아웃 · 재시도 표 〈설계 커밋〉(D13 · D16 · D17 · D20 · 〔Y12 · Y16 · W25〕)
  - (가) 「Dragonfly `socket_timeout`」 행의 「값」 칸 끝에 덧붙인다.
  ```text
  `/session/check`는 조회가 둘이다(거부 목록 → 세션 하한 — 첫 조회가 실패하면 둘째를 하지 않는다). 커밋 뒤 쓰기와 재적용도 0.2 s · 재시도 0이고 실패는 로그만 남긴다(T073 보정 2026-11-12)
  ```
  - (나) 「identity-admin → Authentik(revoke·세션 API) | 5 s × 3회 지수 백오프(최대 5분, Celery)」 행을 아래 세 행으로 바꾼다(W25 — 앞 라운드 문면을 바꾼다: 셋째 행 「값」 칸의 「… 202다(BFF pod fetch 3 s 안 · T073 보정 2026-11-12)」에 3 s가 성립하는 전제를 적었다. 앞의 두 행은 그대로다).
  ```text
  | identity-admin → Authentik(세션 삭제 위임 · 일 1회 대조 · 시드) | 호출마다 5 s(소켓 동작마다) · 응답 1 MiB 상한 · 리디렉션과 프록시를 따르지 않는다. 세션 삭제 위임 = 한 시도 전체 20 s · 재시도 대기 5 → 10 → 20 s(3회 · 창 `nbf + 300 s`). 일 1회 대조 = 한 번 실행 전체 120 s · 재시도 없음. 시드 = 재시도 없음(T073 보정 2026-11-12) |
  | identity-admin → OpenFGA(시드) | 5 s · 재시도 없음(T073 보정 2026-11-12) |
  | Authentik 세션 삭제 위임의 enqueue(요청 경로) | 발행 재시도 0 — 브로커가 불통이면 로그만 남기고 202다. BFF pod fetch 3 s 안에 드는 전제: 브로커가 연결을 거부하면 약 2 s 안에 실패하고, 운영에서는 브로커가 거부 목록과 같은 Dragonfly라 불통이면 커밋 뒤 SET이 먼저 실패(0.2 s)해 위임을 넣지 않는다. 연결은 되고 응답이 없는 브로커만 따로 서면 브로커 `socket_timeout` 5 s까지 걸린다(T073 보정 2026-11-12) |
  ```
- **C10** — :123-128 §관측 〈설계 커밋〉(D25 · 〔Y24 · Z8〕)
  - 「로그」 항목 뒤에 한 항목 / 「메트릭」 항목 끝에 덧붙임
  - (Z8 — 앞 라운드 문면을 바꾼다) 첫 줄의 이벤트 이름 목록에서 「`webhook.nbf_missing` · `authentik.revoke_{…}`」 사이에 `webhook.nbf_clamped`를 넣는다(「· `webhook.nbf_missing` · `webhook.nbf_clamped` · `authentik.revoke_{…}`」). 둘째 줄은 그대로다.
  ```text
  - identity-admin 로그 이벤트(T073 보정 2026-11-12 — 원문 `sub` · `sid` · URL · 토큰 · 예외 문구를 싣지 않는다 · 사용자는 `sub_hash`): `session_revocation.recorded`(필드 `reason` · `scope` user|session · `source` revoke|admin|webhook|reconcile|command · `tenant_id` · `sub_hash` · `revocation_id`) · `identity.multiple_memberships` · `denylist.set_failed` · `denylist.set_skipped` · `denylist.reapplied` · `denylist.reapply_failed` · `session_floor.lookup_failed` · `session_check.iat_in_future` · `webhook.nbf_missing` · `webhook.nbf_clamped` · `authentik.revoke_{enqueued,enqueue_failed,skipped,done,failed,expired,user_missing}` · `authentik.calls_disabled` · `authentik.reconcile_{done,failed,forbidden,truncated,skipped}`.
  `session_revocations_total{reason}`은 커밋 뒤에만 +1 한다(재전송 · 4xx · 롤백은 0). web 프로세스 지표다 — 워커의 대조 보정과 관리 명령의 +1은 수집되지 않으므로(celery 컨테이너에 지표 포트가 없다) 그 수는 로그 `session_revocation.recorded`의 `source`로 센다. 세션 하한 · 재적용 신선도에는 새 지표를 두지 않는다(T073 보정 2026-11-12).
  ```
- **C11** — :109 §오류 슬러그 문단 끝에 덧붙임 〈설계 커밋〉(D12)
  ```text
  DB 무결성 오류의 처리(T073 보정 2026-11-12): `event_pk` 중복은 재전송 200이고, `seed_tenant`의 slug 경합은 `CommandError`이며, 그 밖은 `detail` 없는 500 `internal_error`다(제약 위반 DETAIL의 행 값을 응답 · 로그에 싣지 않는다).
  ```
- **C37** — :59 `GET /tenants/me` 행의 「동작」 칸 끝에 덧붙임 〈설계 커밋〉(D11 · 〔Y15 · Z5〕)
  - (Z5 — 이 블록을 문서에 들어간 글자와 맞췄다: 표 칸 끝이라 마침표가 없다 · 문서는 그대로다)
  ```text
  멤버십은 있는데 그 `tenant_id`의 Tenant 행이 없어도(고아 멤버십) 같은 404다(T073 보정 2026-11-12)
  ```
- **C38** — 새 절: `## 주기 작업` 절 끝(:87)과 `## identity-admin 전용 설정` 사이 〈설계 커밋〉(D19 · D30 · 〔Y23 · W13 · W14 · W21 · Z9 · Z10〕)
  - (W13 · W14 · W21 — 앞 라운드 문면을 바꾼다) `revoke_sessions` 행 전체가 바뀐다: 「명령」 칸에서 `[--sid <sid>]`를 빼고(W13), 「동작」 칸을 아래로 바꾼다 — 사용자 단위만 · 관문은 이 경로만 DB 시계 + 301 s(W14) · 출력에 커밋 뒤 결과와 `PARTIAL`(W21 — 앞 라운드의 `scope=` 칸은 없다 · W21이 정한 종료 코드 값과 확인 문구는 아래 Z9 · Z10이 고쳤다). 제목 줄과 `seed_tenant` 행은 앞 라운드 그대로다.
  - (Z9 · Z10 — 앞 라운드 문면을 바꾼다) `revoke_sessions` 행 「동작」 칸에서 세 곳이 바뀐다. ① 「출력은 한 줄 `revoke_sessions: OK id=<uuid> … delegate=<값>`이고 `sub` · 토큰 · URL을 싣지 않는다.」 → 아래의 「출력은 `revoke_sessions:`로 시작하는 줄 하나다 — …(같은 stdout에 JSON 로그 줄이 섞인다 · `sub` · 토큰 · URL을 싣지 않는다).」(Z9) ② 「머리말이 `PARTIAL`이고 종료 코드 2다」 → 「머리말이 `PARTIAL`이고 종료 코드 3이다」(Z9 — 앞의 값은 인자 사용법 오류가 내는 코드와 겹친다) ③ 그 뒤 괄호 「(행은 기록됐다 — 재적용 생존을 신선도 키로 확인한다)」 → 아래의 괄호(Z10 — 신선도 키의 존재는 재적용이 죽은 직후 300 s 동안 남는다). 나머지는 검토 반영 뒤 그대로다.
  ```text
  ## 관리 명령 (T073 보정 2026-11-12)

  | 명령 | 실행 | 동작 |
  |---|---|---|
  | `seed_tenant --tenant-id <uuid> --owner-sub <sub> --member-sub <sub> [--authentik-token-stdin]` | 운영자 `kubectl exec`(web 컨테이너 · runtime 프로필 · app role) | data-model §1 |
  | `revoke_sessions --sub <sub>` | 같음 | 관리자 폐기 — 사용자 단위만이다(단일 세션 폐기 인자는 두지 않는다 — `sid` 폐기는 330 s 차단뿐이고 refresh 폐기가 따르지 않아, 그 세션이 330 s 안에 BFF에 닿지 않으면 효력이 없다). SP-1에는 `/sessions/revoke`의 관리자 갈래를 부를 다른 길이 없다(BFF 프록시 허용 경로는 GET 둘뿐이고 tester 서비스 토큰은 `common_name` 검사에서 403이다). 효과는 `sid` NULL 행 · `revoked:sub` + 세션 하한 키 · Authentik 세션 삭제 위임이다. reason `admin` · `tenant_id` = `--sub`의 `TenantMembership`(없으면 `CommandError`) · `nbf` = 실행 시각 내림 + 1. 기록 경로와 입력 문자 규칙은 `/sessions/revoke`와 같다. 이 경로만 `nbf`를 DB 시계와 견준다 — `nbf > DB now() + 301 s`면 기록하지 않고 `CommandError`다(JWT도 시각 창도 없는 경로라 시계가 틀린 곳에서 돈 명령을 막는다). 출력은 `revoke_sessions:`로 시작하는 줄 하나다 — `revoke_sessions: OK id=<uuid> nbf=<int> expires_at=<ISO 8601 UTC> denylist=<값> delegate=<값>`(같은 stdout에 JSON 로그 줄이 섞인다 · `sub` · 토큰 · URL을 싣지 않는다). 두 값은 커밋 뒤 쓰기의 결과다 — `denylist`는 `ok` · `skipped` · `failed` · `unreachable`, `delegate`는 `enqueued` · `skipped`(자리값 자격이거나 거부 목록 쓰기가 연결에서 실패) · `off`(쓰기 플래그 거짓) · `failed`다. `denylist`가 `ok` · `skipped`가 아니면 머리말이 `PARTIAL`이고 종료 코드 3이다(행은 기록됐다 — 거부 목록 쓰기 실패 · 60 s 뒤 `revoked:sub`와 세션 하한 키가 생겼는지 확인한다 · 2는 인자 사용법 오류가 내는 코드라 쓰지 않는다). `delegate=failed`는 종료 코드 0 그대로다 |
  ```

### contracts/denylist.md

- **C39** — :3 머리말 끝과 :7-15 §키 스키마 〈설계 커밋〉(D29 · D14 · 〔E1 · E2 · E5 · W3 · W16 · W35〕)
  - (가) :3 머리말 끝에 한 문장
  ```text
  사용자 단위 폐기는 같은 로그 행에서 세션 하한 키(§키 스키마)도 파생한다 — 이 키는 identity-admin `/session/check`만 읽는다(T073 보정 2026-11-12).
  ```
  - (나) 키 표에 두 행을 더한다(`revoked:sid` 행 뒤). (W16 — 앞 라운드 문면을 바꾼다: 둘째 행 「TTL」 칸이 `120 s`에서 `300 s`가 된다)
  ```text
  | `identity-admin:session-floor:{sub}` | 그 `sub`의 사용자 단위 폐기 행 가운데 가장 큰 `nbf`(epoch 초, 정수) | 그 행의 `expires_at + 30 d`까지(= `nbf` + 330 s + 30 d) | identity-admin | 세션 하한 — BFF 세션 시작 시각 < 값인 세션은 inactive(`/session/check`만 읽는다 · T073 보정 2026-11-12) |
  | `identity-admin:denylist:reapplied-at` | 마지막 재적용 시각(epoch 초) | 300 s | identity-admin | 재적용 생존 신호(판정에 쓰지 않는다 · T073 보정 2026-11-12) |
  ```
  - (다) 표 아래 항목 목록 끝에 두 항목을 더한다. :14 「키 이름은 … 이 표 그대로 쓴다」는 그대로 둔다. (W3 — 앞 라운드 문면을 바꾼다: 첫 항목의 「… 서비스 계정은 남의 refresh 토큰을 지울 수 없다」 뒤에 실측 표시를 단다. 둘째 항목은 그대로다)
  ```text
  - **세션 하한(T073 보정 2026-11-12)**: `revoked:*`의 330 s는 이미 나간 access 토큰을 막는 수명이다. 폐기 전에 시작한 BFF 세션(쿠키의 refresh 토큰)은 330 s 뒤에도 refresh로 살아남는다 — Authentik은 세션을 지워도 refresh 토큰을 남기고 서비스 계정은 남의 refresh 토큰을 지울 수 없다(소스 판독 2026.8.0 — 실측 T081 · VD-T081-4). 그래서 사용자 단위 폐기는 30일짜리 하한 키를 함께 남기고, `/session/check`가 「하한 > 세션 시작 시각」이면 inactive를 낸다. 정본은 같은 `session_revocation_log`의 사용자 단위 행(`sid` NULL)이다(새 표 · 새 열 없음). `sid` 행은 하한을 만들지 않는다. 키 이름에 epoch를 쓰지 않는다(폐지된 센티널과 헷갈린다).
  - 하한 수명의 30일은 로그 보존(`expires_at + 30 d`)과 `/session/check`의 세션 절대 수명(`now − iat > 30 d`면 inactive)이 함께 쓰는 상수 하나다. 하한 수명(`nbf` + 330 s + 30 d) ≥ 세션 최대 나이(30 d)라서, 폐기 전에 시작한 세션은 하한이 사는 동안은 하한이, 그 뒤에는 나이가 막는다(겹침 330 s). 하한이 막는 것은 폐기 전에 만든 BFF 세션이다 — Authentik 로그인 세션이 살아 있는 기기의 재로그인은 막지 않는다(contracts/bff-api.md).
  ```
  - (라) 키 표 `revoked:sid:{sid}` 행의 「의미」 칸 끝에 덧붙인다(W35 — 새 문장 · 이 칸만 읽으면 pod에서 집행되는 것처럼 읽힌다).
  ```text
  (pod 경계에서는 조회되지 않는다 — §조회 규약 1 · 집행은 BFF의 `/session/check` · T073 보정 2026-11-12)
  ```
- **C40** — :19-24 §조회 규약 〈설계 커밋〉(D8 · 〔Y1 · E2〕)
  - (가) 1번 항목 끝에 덧붙인다.
  ```text
  BFF가 pod를 부를 때 쓰는 교환 토큰에는 `sid` 클레임이 없다(Authentik의 토큰 교환은 세션 없이 토큰을 만든다 — 소스 판독 · 실측 T081). 그래서 pod 경계에서 `revoked:sid`는 조회되지 않고, pod의 즉시 거부는 `revoked:sub`(사용자 단위 폐기)에서만 성립한다. `sid` 단위 폐기는 BFF의 `/session/check`(`sid` 질의)와 BFF의 refresh 폐기로 집행된다(T073 보정 2026-11-12).
  ```
  - (나) 목록 끝에 7번 항목을 더한다.
  ```text
  7. 세션 하한은 identity-admin `/session/check`만 조회한다(거부 목록 조회 뒤의 둘째 왕복 `GET` · 뷰 소유 클라이언트 · 0.2 s · 재시도 0 · 실패나 정수가 아닌 값은 503 `denylist_unavailable` · 첫 조회가 실패하면 둘째를 하지 않는다). 모든 pod의 미들웨어 조회와 `Denylist.lookup`은 2키 그대로다 — 다른 pod 사용자는 `identity-admin:*`를 읽지 못한다(T073 보정 2026-11-12).
  ```
- **C12** — :28 §쓰기 규약 첫 항목 전체 〈설계 커밋〉(D13 · 〔Y22 · E1〕)
  ```text
  - `/sessions/revoke`·웹훅(· 일 1회 대조 보정 · 관리 명령 `revoke_sessions`): `session_revocation_log` INSERT + outbox INSERT 트랜잭션 커밋 **후** SET한다(T073 보정 2026-11-12). `sid` 행은 `SET revoked:sid:{sid} 1 EX min(330, ⌊expires_at − 현재 시각⌋)`다(이 키는 BFF의 `/session/check`가 `sid` 질의로 읽는다 — pod 미들웨어는 교환 토큰에 `sid`가 없어 조회하지 않는다 · §조회 규약 1). 사용자 단위 행(`sid` NULL)은 DB에서 그 `sub`의 사용자 단위 행 가운데 `nbf`가 가장 큰 행을 한 번 읽어(자기 행 값이 아니다 — 늦게 끝난 요청이나 과거 `nbf` 웹훅이 더 큰 값을 덮지 않게) `SET revoked:sub:{sub} <그 nbf> EX min(330, ⌊그 행 expires_at − 현재 시각⌋)`와 `SET identity-admin:session-floor:{sub} <그 nbf> EX ⌊그 행 expires_at + 30 d − DB now()⌋`를 한 파이프라인으로 보낸다. 남은 TTL이 1초 미만인 키는 쓰지 않는다(`EX 0`은 오류다). 쓰기 클라이언트도 0.2 s · 재시도 0이다. Dragonfly SET 실패는 로그만 남긴다 — Celery 재시도를 넣지 않는다(브로커가 같은 Dragonfly라 함께 실패하고 응답만 늦어진다). 아래 30 s 재적용이 반영한다.
  ```
- **C13** — :29-30 §쓰기 규약 재적용 항목 〈설계 커밋〉(D14 · 〔Y22 · E1 · E5 · W16 · W18 · Z1〕)
  - (가) :29 항목 끝에 덧붙인다(W16 — 앞 라운드 문면을 바꾼다: 「`EX 120`으로 쓴다」가 「`EX 300`으로 쓴다」가 된다).
  ```text
  같은 키로 가는 행이 여럿이면 `nbf`가 가장 큰 행의 값 · TTL로 쓴다. 남은 TTL이 1초 미만인 키는 건너뛴다. 같은 실행이 세션 하한 키도 되살린다 — `sid`가 NULL이고 `expires_at + 30 d > now()`인 행을 `sub`별로 묶어 `nbf`가 가장 큰 행으로 SET한다(TTL = 그 행 `expires_at + 30 d − now()` 초 내림). 끝에 신선도 키 `identity-admin:denylist:reapplied-at`을 `EX 300`으로 쓴다(행이 0이어도 쓴다). SET은 파이프라인으로 보내고 명령 단위 실패는 건수만 로그에 남긴다(T073 보정 2026-11-12).
  ```
  - (나) :30 하위 항목 「행 수는 SP-1 규모에서 수십 건이므로 …」 전체를 아래 두 하위 항목으로 바꾼다(W18 — 앞 라운드 문면을 바꾼다: 둘째 하위 항목 「남는 경합 하나: … 다음 재적용(≤ 30 s)이 되돌린다(받아들인다 · T073 보정 2026-11-12).」 전체가 아래의 「남는 경합: …」이 된다. 첫 하위 항목은 그대로다).
    - (Z1 — 앞 라운드 문면을 바꾼다) 둘째 하위 항목 끝 괄호의 상한 「≤ 30 s + 실행 중 작업의 마감(대조 120 s · 위임 한 시도 20 s) + 워커 재접속」이 아래 꼴이 된다(solo 워커는 받은 순서대로 돌므로 「실행 중인 작업 하나」가 아니라 「먼저 받은 작업들」이다). 나머지 글자는 그대로다.
  ```text
    - 행 수: `revoked:*` 대상은 최근 330 s의 활성 행(수 건)이고, 세션 하한 대상은 최근 30일 + 330 s의 사용자 단위 행이다(SP-1 규모에서 수십–수백 행 · 키는 그 기간에 폐기된 `sub` 수 — 추론). 30초마다 전량 SET해도 비용이 무시할 수준이다. 규모가 커지면(사용자 단위 행 10^5 이상) 인덱스 + 증분 재적용(tick마다 최근 행만 · 전량은 기동과 N분 주기)으로 바꾸되 "무조건"은 유지한다(T073 보정 2026-11-12).
    - 남는 경합: 요청 경로에서 자기 행 값으로 덮는 경합은 없앴다(커밋 뒤 최댓값 조회). 「조회 뒤 SET」 경합은 재적용과 요청 경로의 커밋 뒤 쓰기 사이, 커밋 뒤 쓰기 둘 사이에 남는다 — 조회한 뒤 SET하는 사이에 커밋된 더 큰 `nbf`를 낡은 조회 값으로 덮을 수 있다(창은 ms). 다음 재적용이 되돌린다(≤ 다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속 · 받아들인다 · T073 보정 2026-11-12).
  ```
- **C41** — :31 유실 창 항목 끝 / :33 purge 항목 끝 〈설계 커밋〉(D29 · 〔E2 · E5〕)
  ```text
  유실 창에는 세션 하한도 없다(키 없음 = 통과). 그 사이 `/session/check`에 닿은 폐기 전 세션은 active로 보이지만, 재적용이 돌아오면 다음 확인에서 다시 inactive가 된다(하한이 사는 동안은 하한, 그 뒤에는 절대 수명). 재적용이 멈춘 채 유실되면 키가 돌아오지 않는다 — 신선도 키와 재적용 성공 줄 무소식 경보(T098)가 그 탐지다(T073 보정 2026-11-12).
  이 경계는 세션 하한 수명과 같은 식 · 같은 상수다 — 하한이 사는 동안 그 행은 DB에 있다(T073 보정 2026-11-12).
  ```
- **C48** — §쓰기 규약 「유실 창」 항목의 문장 「거부 목록 공백은 **비정상 종료**(OOM kill·SIGKILL·스냅샷 저장 실패)일 때만 생기고, 그때도 **최대 30초**다. 그 30초를 줄이려고 pod가 DB를 직접 보지는 않는다(fail-closed와 30 s 재적용으로 충분).」을 아래로 바꾼다 〈설계 커밋〉(D29 · 〔W18 · Z1〕 — 새 항목: T073 이전 문장이다 · 이 문단에는 C41이 넣은 표식이 이미 있어 더 달지 않는다)
  - (Z1 — 앞 라운드 문면을 바꾼다) 검토 반영이 넣은 첫 문장의 「그때도 **최대 30초 + 실행 중 작업의 마감(대조 120 s · 위임 한 시도 20 s) + 워커 재접속**이다(이전 문구 「최대 30초」 — 워커가 다른 작업을 도는 동안은 30 s 재적용이 밀린다)」가 아래의 「그때도 상한은 **다음 tick(최대 30초) + …**이다(이전 문구 「최대 30초」 — …)」가 된다. 둘째 문장은 그대로다.
  ```text
  거부 목록 공백은 **비정상 종료**(OOM kill·SIGKILL·스냅샷 저장 실패)일 때만 생기고, 그때도 상한은 **다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속**이다(이전 문구 「최대 30초」 — solo 워커는 받은 순서대로 돌고 그동안의 30 s tick은 `expires` 30으로 버려진다). 그 공백을 줄이려고 pod가 DB를 직접 보지는 않는다(fail-closed와 30 s 재적용으로 충분).
  ```
- **C14** — :42-50 §ACL 표 아래 항목 목록 끝에 한 항목 〈설계 커밋〉(D24 · 〔Y4〕)
  ```text
  - 생성물 compose(`compose/dragonfly-dev.acl`)와 시험 conftest(`DRAGONFLY_USERS`)의 `identity-admin` 사용자도 위 표의 `identity-admin` 행 규칙이다(템플릿 기본 `%R~revoked:*`가 아니다 — 로컬 compose와 pod 사용자로 도는 시험에서 거부 목록 쓰기가 NOPERM이 되지 않게). 세션 하한 키와 신선도 키는 자기 접두(`identity-admin:`)라 ACL 변경이 없고, Celery 키와는 하위 이름 `session-floor:` · `denylist:`로 가른다(T073 보정 2026-11-12).
  ```
- **C15** — :68-75 §타임아웃 표에 세 행을 더한다 〈설계 커밋〉(D13 · D29 · 〔W16〕 — 앞 라운드 문면을 바꾼다: 셋째 행의 값이 `120 s`에서 `300 s`가 된다)
  ```text
  | 거부 목록 · 세션 하한 쓰기(요청 경로 · 재적용) · 세션 하한 조회 | 0.2 s · 재시도 0(T073 보정 2026-11-12) |
  | 세션 하한 키 수명 | 그 행 `expires_at + 30 d`까지 |
  | 재적용 신선도 키 | 300 s |
  ```
- **C42** — :79-82 §검증 〈설계 커밋〉(〔Z1〕)
  - (가) T066 항목 뒤에 한 항목 / (나) T085 항목 끝에 덧붙임(둘 다 앞 라운드 그대로다 — 재검토 반영에서는 하위 항목 이름 (가) · (나)만 붙였다)
  ```text
  - **T073**(`apps/identity-admin/tests/test_identity_*.py`): 사용자 단위 폐기 3경로 → 세션 하한 값 · TTL · `sid` 폐기는 하한 없음 · `/session/check` 판정 표(하한만 · 같음 · 정수 아님 503 · 나이 경계 · 미래 `iat`) · 재적용의 하한 복원(창 경계 · `sub`별 최댓값 · TTL 비증가) · purge 대상 ⇔ 하한 대상 아님 · 신선도 키 · 교환 토큰 꼴(`sid` 없음)의 Bearer는 `revoked:sid`에 걸리지 않음(한계 고정).
  330초 넘게 쉰 기기와 복사 쿠키가 사용자 단위 폐기 뒤 다음 접촉에서 401인지 · SIGKILL 뒤 세션 하한 키까지 복구되는 시간(T073 보정 2026-11-12).
  ```
  - (다) T085 항목의 첫 문장 「Dragonfly SIGKILL 후 ≤ 30 s 안에 폐기된 세션이 다시 401이 되는지.」를 아래로 바꾼다(Z1 — 새 항목: T073 이전 문장이다 · 같은 문서 §쓰기 규약 「유실 창」의 상한(C48)과 어긋났다 · 이 문단에는 (나)가 넣은 표식이 이미 있어 더 달지 않는다).
  ```text
  Dragonfly SIGKILL 후 폐기된 세션이 다시 401이 되기까지의 시간 — 상한은 §쓰기 규약 「유실 창」(이전 문구 「≤ 30 s 안에」).
  ```
  - (라) T066 항목의 첫 구절 「캐시를 비운 뒤(센티널 없음) **30 s 안에 무조건 재적용**이 `expires_at > now()` 행을 전부 되살리는지 — SIGKILL 재시작 시나리오」를 아래로 바꾼다(마감 확인 RC-1 — (다)와 같은 까닭이다: 같은 절의 「30 s 안에」가 「유실 창」의 상한과 글자로 달랐다. T066 시험은 이 구절을 「beat 주기 30 s + 작업 결과」로 본다 — test_api.py:134 · 1761. 이 문단에는 T073 표식이 없어 하나를 단다).
  ```text
  캐시를 비운 뒤(센티널 없음) **무조건 재적용** 한 번이 `expires_at > now()` 행을 전부 되살리는지 — SIGKILL 재시작 시나리오(시험은 beat 주기 30 s와 작업 결과로 본다 · 복구 시간의 상한은 §쓰기 규약 「유실 창」 · T073 보정 2026-11-12 — 이전 문구 「30 s 안에 무조건 재적용」)
  ```

### contracts/bff-api.md

구현은 T089(시험) · T092(라우트)다. T073은 계약만 고친다 — pod 코드는 이 계약의 어느 문장에도 기대지 않는다(〔E4〕).

- **C43** — :21 `jt_session` 행과 :24 문단 〈설계 커밋〉(〔E4 · R12 · R14 · ATK-4 · W3〕)
  - (가) :21 `jt_session` 행의 「내용」 칸 끝에 덧붙인다(W3 — 앞 라운드 문면을 바꾼다: 끝의 「… 되풀이해 inactive가 된다) · T073 보정 2026-11-12」 사이에 실측 표시 문장을 넣는다).
  ```text
  `issued_at` = **세션 시작 시각** — callback의 코드 교환 응답 ID 토큰 `iat`(정수 epoch 초 · Authentik 시계)다. refresh 때 새 쿠키에 **그대로 옮긴다**(갱신하지 않는다 — 갱신하면 폐기된 세션이 refresh 한 번으로 세션 하한 위로 올라간다). `auth_time`은 쓰지 않는다(Authentik 로그인 세션이 살아 있으면 재로그인도 같은 값이라, 폐기 뒤의 로그인이 되풀이해 inactive가 된다). ID 토큰 `iat` · `auth_time`의 이 동작은 소스 판독이다(실측 T081 · VD-T081-4: 다르면 `issued_at`의 원천을 고친다) · T073 보정 2026-11-12
  ```
  - (나) :24 문단 전체
  ```text
  access 토큰은 쿠키에 넣지 않는다. BFF isolate 메모리 캐시 `Map<sub+aud+issued_at, {token, exp}>`(최대 5분)에서 재사용하고, 없으면 refresh → exchange. 캐시 키에 `issued_at`을 넣는다 — `sub+aud`면 전체 로그아웃 뒤 5분 안에 다시 로그인한 세션이 옛 세션의 교환 토큰을 받아 pod에서 401 `session_revoked`가 된다. 캐시 사용 · refresh · 교환은 모두 폐기 확인 뒤다(§하류 호출 규약 · T073 보정 2026-11-12). `tenant_id`는 UUID.
  ```
- **C44** — :30-36 §엔드포인트 표와 :38 표 아래 문장 〈설계 커밋〉(〔E4 · R13 · W6 · W9〕)
  - (가) :30 `GET /api/auth/login` 행의 「동작」 칸 끝
  ```text
  인가 요청의 scope에는 `openid`와 `offline_access`가 있어야 한다(ID 토큰 `iat` = 세션 시작 시각 · refresh 토큰 발급의 전제 — T081 · T092 · T073 보정 2026-11-12)
  ```
  - (나) :31 `GET /api/auth/callback` 행의 「동작」 칸 끝
  ```text
  `jt_session`의 `issued_at`을 여기서 정한다(코드 교환 응답 ID 토큰의 `iat`). identity-admin을 부르지 않는다 — 로그인이 identity-admin 장애에 묶이지 않는다(폐기 뒤 재로그인의 입장 판정을 둘지는 T089 전 사용자 결정 · T073 보정 2026-11-12)
  ```
  - (다) :33 `POST /api/auth/refresh` 행의 「동작」 칸 전체
  ```text
  먼저 폐기 확인(§하류 호출 규약)을 한다 — inactive면 재발급하지 않고 자기 refresh 토큰 RFC 7009 폐기 → 쿠키 삭제 → 401 `session_revoked`, 확인이 503이면 재발급하지 않고 503이다(쿠키 유지 · T073 보정 2026-11-12). 통과하면 `jt_session`의 refresh 토큰으로 Authentik 토큰 재발급(회전 refresh — 새 refresh를 쿠키에 다시 넣고 `issued_at`은 그대로 옮긴다) 후 isolate 교환 캐시를 비운다. refresh가 만료·폐기됐으면 쿠키 삭제 + 401
  ```
  - (라) :34 `GET /api/session` 행의 「동작」 칸 끝(W6 — 이 블록을 문서에 들어간 글자와 맞췄다: 표식이 들어 있다 · 문서는 그대로다)
  ```text
  (inactive · 503의 처리는 §하류 호출 규약 폐기 확인 · T073 보정 2026-11-12)
  ```
  - (마) :36 `ALL /api/proxy/<pod>/<path>` 행의 「허용된 요청은 교환 토큰 + 서비스 토큰으로 호출한다.」(W9 — 앞 라운드 문면을 바꾼다: 괄호 「(교환 캐시 사용 · refresh · 교환 앞 — inactive면 401 `session_revoked` + 쿠키 삭제 · 503이면 503 쿠키 유지 · T073 보정 2026-11-12)」가 아래 꼴이 된다 — RFC 7009 폐기가 빠져 있었다)
  ```text
  허용된 요청은 먼저 폐기 확인을 하고(교환 캐시 사용 · refresh · 교환 앞 — inactive · 503의 처리는 §하류 호출 규약 폐기 확인: inactive면 RFC 7009 폐기 → 쿠키 삭제 → 401 `session_revoked` · 503이면 503 쿠키 유지 · T073 보정 2026-11-12) 교환 토큰 + 서비스 토큰으로 호출한다.
  ```
  - (바) :38 표 아래 문장의 끝 괄호 「(폐기 확인은 `/api/session` 안에서 상류 `/session/check`를 부른다)」
  ```text
  (폐기 확인은 세션 쿠키를 쓰는 네 라우트 — `/api/session` · `/api/auth/refresh` · `/api/proxy/*` · `/api/auth/logout` — 가 저마다 하류 호출 앞에서 상류 `/session/check`를 부른다 · T073 보정 2026-11-12 — 이전 문구 「`/api/session` 안에서」)
  ```
  - (사) :36 `ALL /api/proxy/<pod>/<path>` 행 「동작」 칸의 옛 문장을 바꾼다(W9 — 새 항목 · `iat`가 토큰 `iat`로 읽히지 않게 · 칸에 (마)의 표식이 이미 있어 더 달지 않는다): 「`/api/session`의 폐기 확인과 같은 세션 값(`sub` · `iat` · `sid` 클레임이 있을 때만 `sid`)」
  ```text
  `/api/session`의 폐기 확인과 같은 세션 값(`sub` · `iat` = 쿠키 `issued_at` · 쿠키에 `sid`가 있을 때만 `sid`)
  ```
  - (아) 같은 행의 「응답」 칸 전체(W9 — 새 항목 · 폐기 확인이 만드는 401을 더한다): 「pod 응답 상태(2xx JSON · 4xx problem+json) / 404 / 503 `upstream_unavailable`」
  ```text
  pod 응답 상태(2xx JSON · 4xx problem+json) / 401 `session_revoked`(폐기 확인 — BFF problem+json · T073 보정 2026-11-12) / 404 / 503 `upstream_unavailable`
  ```
- **C36** — :32 `POST /api/auth/logout` 행의 「동작」 칸과 「응답」 칸 〈설계 커밋〉(〔Y13 · Y1 · E4 · W17〕)
  - (가) 「동작」 칸: 「body `{ all_devices?: boolean }`.」 뒤에 넣는다. 뒤의 실패 갈래 문장들은 그대로 둔다. (W17 — 앞 라운드 문면을 바꾼다: 첫 문장 「… 자기 refresh 토큰 RFC 7009 폐기 → 쿠키 삭제 → 204다(이미 폐기된 쿠키가 남의 전 기기 로그아웃을 일으키지 못한다).」가 아래의 첫 두 문장이 된다 — inactive 세션의 전체 로그아웃이 조용히 버려지지 않게 응답을 가른다. 나머지는 앞 라운드 그대로다)
  ```text
  먼저 폐기 확인(§하류 호출 규약)을 한다 — inactive면 `/sessions/revoke`를 부르지 않고 자기 refresh 토큰 RFC 7009 폐기 → 쿠키 삭제까지 한 뒤, 요청 본문이 `all_devices: true`를 명시했으면 401 `session_revoked`, 그 밖은 204다(이미 폐기된 쿠키가 남의 전 기기 로그아웃을 일으키지 못한다). 이 갈래는 아무 폐기도 기록하지 않는다 — 다른 기기는 그대로이므로, 전체 로그아웃을 명시한 클라이언트는 401을 받고 다시 로그인한 뒤 전체 로그아웃을 한다. 확인이 503이면 refresh · 교환을 하지 않으므로 `/sessions/revoke`를 부를 수 없다 — Authentik refresh revoke만 시도하고 쿠키를 지운 503 `upstream_unavailable`이다(아래 실패 갈래와 같다). 하류 `/sessions/revoke` 본문 규칙(contracts/identity-admin-api.md — 어기면 400): 전체 기기 = `{ "all_devices": true, "reason": "logout_all" }`, 단일 세션 = `{ "all_devices": false, "reason": "logout", "sid": "<쿠키 sid>" }`(교환 토큰에는 `sid`가 없어 본문 `sid`가 필수다 — 쿠키에 `sid`가 없으면 단일 세션 폐기를 보낼 수 없다). 단일 세션 폐기는 pod 경계에서 집행되지 않는다(교환 토큰에 `sid` 없음 — BFF의 폐기 확인과 refresh 폐기가 집행한다). `all_devices`를 생략한 요청을 어느 쪽으로 보낼지(기본 로그아웃 범위)는 T089 전 사용자 결정이다(T073 보정 2026-11-12).
  ```
  - (나) 같은 행의 「응답」 칸 전체(W17 — 새 항목 · (가)가 만든 401을 싣는다): 「204 / 503 `upstream_unavailable`」
  ```text
  204 / 401 `session_revoked`(이미 폐기된 세션의 `all_devices: true` 요청 — 아무 폐기도 기록되지 않았다 · T073 보정 2026-11-12) / 503 `upstream_unavailable`
  ```
- **C45** — :48 §하류 호출 규약 「폐기 확인」 항목과 :56-60 §타임아웃 표 〈설계 커밋〉(〔E2 · E4 · E9 · W17 · Z21〕)
  - (가) :48의 질의 「`…/session/check?sub=<sub>&iat=<iat>&sid=<sid>`」에서 `<iat>`를 `<issued_at>`으로 바꾸고, 바로 뒤 괄호 「(`sid` 클레임이 없으면 `sid`를 빼고 보낸다 — …)」의 머리(여는 괄호 바로 뒤)에 넣는다. 넣은 글 뒤에 빈칸 하나를 두고 괄호의 나머지가 그대로 이어진다(그 나머지의 첫 구절은 아래 (사)가 바꾼다).
  ```text
  `iat`에는 쿠키의 `issued_at`(세션 시작 시각)을 보낸다 — 토큰의 `iat`가 아니다 · T073 보정 2026-11-12 ·
  ```
  - (나) :48 「결과를 **2 s** 캐시.」
  ```text
  결과를 **2 s** 캐시한다(키 = `sub` + `issued_at` + `sid`). **자리**: 세션 쿠키를 쓰는 네 라우트(`/api/session` · `/api/auth/refresh` · `/api/proxy/*` · `/api/auth/logout`) 모두 Authentik 토큰 엔드포인트 호출(refresh · 교환)과 교환 토큰 캐시 사용 **앞**이다 — 확인 없는 회전 경로를 두지 않는다(gateway의 관문 하나를 거친 세션만 refresh · 교환 함수가 받는다 — T092).
  ```
  - (다) :48 「`active=false`면 쿠키 삭제 + 401 `session_revoked`.」(W17 — 앞 라운드 문면을 바꾼다: 끝 괄호 「(logout은 `/sessions/revoke` 없이 204)」가 아래 꼴이 된다)
  ```text
  `active=false`면 ① 쿠키의 refresh 토큰을 RFC 7009로 폐기(3 s · 실패해도 진행) ② `jt_session` · `jt_csrf` 삭제 ③ 401 `session_revoked`(logout은 `/sessions/revoke`를 부르지 않고 204 — 본문이 `all_devices: true`를 명시했으면 401 · 엔드포인트 표).
  ```
  - (라) :48 「(fail-closed; 쿠키는 유지 · T070 보정)」
  ```text
  (fail-closed; 쿠키는 유지하고 refresh · 교환을 하지 않는다 — 회전 0 · logout만 쿠키를 지운다(엔드포인트 표) · T070 보정 · T073 보정 2026-11-12)
  ```
  - (마) :48 항목 끝에 덧붙인다.
  ```text
  세션 하한과 세션 절대 수명(시작한 지 30일)은 `/session/check`가 집행한다 — BFF는 `active`만 본다(쿠키 `Max-Age`를 남은 수명으로 줄이는 것은 T092 선택). **한계**: 세션 하한이 막는 것은 폐기 전에 만든 BFF 세션이다. Authentik 로그인 세션이 살아 있는 기기는 사용자 단위 폐기 뒤에도 재인증 없이 새 BFF 세션을 얻는다(callback 입장 판정의 채택 여부는 T089 전 사용자 결정 · 계정 탈취 대응의 완결은 Authentik 사용자 비활성화 — 런북 · T073 보정 2026-11-12).
  ```
  - (바) 타임아웃 표: 「`/session/check` 결과 캐시」 행의 「비고」 칸 / 「교환 토큰 캐시」 행의 「비고」 칸 / 「BFF → Authentik(토큰·교환·revoke)」 행의 「비고」 칸 끝 / 「pod 측(참고)」 행의 「pod → Authentik 5 s × 3회 지수 백오프(Celery, 최대 5분)」
    - (Z21 — 앞 라운드 문면을 바꾼다) 셋째 줄의 「실패해도 쿠키 삭제 + 401로 진행한다」가 아래 꼴이 된다 — logout의 inactive 갈래는 204이거나 401이라(C36 (가) · C45 (다)) 「401」 하나로 적으면 그 갈래와 어긋난다. 나머지 세 줄은 그대로다.
  ```text
  isolate 메모리 · 키 = `sub` + `issued_at` + `sid`(T073 보정 2026-11-12)
  isolate 메모리 · 키 = `sub` + `aud` + `issued_at`(T073 보정 2026-11-12)
  inactive 처리의 RFC 7009 폐기는 실패해도 쿠키 삭제 뒤 그 라우트의 inactive 응답(401 · logout은 §엔드포인트)으로 진행한다(T073 보정 2026-11-12)
  pod → Authentik 호출마다 5 s · 세션 삭제 위임 재시도 5 → 10 → 20 s(Celery · 창 `nbf + 300 s` — contracts/identity-admin-api.md §타임아웃 · T073 보정 2026-11-12)
  ```
  - (사) :48 「폐기 확인」 항목의 같은 괄호 안 옛 구절 「`sid` 클레임이 없으면 `sid`를 빼고 보낸다」를 아래로 바꾼다(Z21 — 새 항목 · 프록시 행의 C44 (사) 「쿠키에 `sid`가 있을 때만 `sid`」와 같은 낱말로 맞춘다 · 괄호에 (가)의 표식이 이미 있어 더 달지 않는다). 뒤의 「 — 빈 `sid=`는 400 · T070 r2)」는 그대로 이어진다.
  ```text
  쿠키에 `sid`가 없으면 `sid`를 빼고 보낸다
  ```

### data-model.md

- **C21** — §1 :13 `id` 행의 「규칙」 칸 끝에 덧붙임 〈설계 커밋〉(D19)
  ```text
  SP-1 고정 테넌트 UUID = `01a1cec4-ecef-77fe-839d-5af5a01a211f`(UUID v7 · 한 번 정하면 바꾸지 않는다 — T081 그룹 이름 `tenant:<uuid>` · T083 `seed_tenant` 인자 · T085 단언이 이 줄의 값을 읽는다 · 코드에는 넣지 않는다 · T073 보정 2026-11-12)
  ```
  - 값은 컨트롤러가 설계 커밋 직전에 한 번 만든 UUID v7이다(2026-11-12 · 난수 74비트는 OS 난수원). 식별자일 뿐 비밀이 아니다(토큰 `tenant_id` 클레임 · 그룹 이름 · FGA object에 그대로 실린다). 같은 파일 「시드」 항목의 `--tenant-id <고정 uuid>`는 인자 자리 표기라 그대로 둔다.
- **C23** — §1 :13 · :17 · §2 :33 · :37 · §3 :50 · :58 〈설계 커밋〉(D4)
  - `id` 행 셋의 「규칙」 칸 머리(「PK」 뒤 — §2 · §3처럼 마침표가 없으면 「PK.」로 만들고 잇는다)에 / §1 `created_at` · `updated_at` 행(한 행이다)의 「규칙」 칸 전체 / §2 · §3 `created_at` 행의 「규칙」 칸(지금은 빈 칸)
  ```text
  값을 주지 않으면 DB가 만든다(`uuidv7()` — Django 6.1 `UUID7()` `db_default` · PostgreSQL 18 · T073 보정 2026-11-12).
  DB 기본값(`db_default=Now()` — 문장 시작 시각). SP-1에는 Tenant를 갱신하는 경로가 없어 `updated_at`은 생성 시각 그대로다(갱신 경로는 SP-2 · T073 보정 2026-11-12)
  DB 기본값(`db_default=Now()` · T073 보정 2026-11-12)
  ```
- **C22** — §1 :22-26 시드 항목 〈설계 커밋〉(D19 · 〔Y19 · Y21 · W35〕)
  - (가) 하위 목록 끝에 한 항목(앞 라운드 그대로)
  ```text
  - **세부(T073 보정 2026-11-12)**: `--tenant-id`는 UUID v7이어야 하고 소문자 정규형으로 쓴다. `--owner-sub` · `--member-sub`는 출력 가능 ASCII 1–255자이고 서로 달라야 한다(어기면 `CommandError`). 순서는 ① 그룹 `tenant:<uuid>` 이름 조회(읽기 — 없으면 DB를 쓰지 않고 실패한다) ② DB(한 트랜잭션) ③ 사용자 조회 ④ Authentik 쓰기 ⑤ OpenFGA 쓰기다. DB 단계: Tenant가 그 id로 이미 있으면 slug가 `joshuatech`이어야 하고 기존 `display_name` · `status`는 건드리지 않는다. 멤버십이 이미 있는데 role이 인자와 다르면 `CommandError`다(바꾸지 않는다 — SP-1에는 역할 변경 경로가 없고, role을 내리면 OpenFGA에 옛 관계가 남는다 · 위 「이미 있으면 갱신만」은 행을 다시 만들지 않는다는 뜻이다). Authentik: 소속은 사용자 `groups`에 그룹 pk가 없을 때만 더하고 attribute는 `tenant_id`가 없을 때만 쓴다. 다른 `tenant_id`가 이미 있으면 쓰기 플래그와 무관하게 `CommandError`다(사용자를 조용히 다른 테넌트로 옮기지 않는다). 쓰기를 끈 실행도 소속 · attribute를 비교해 어긋난 항목 수를 출력한다. OpenFGA는 `on_duplicate: "ignore"` 일괄 쓰기 한 번이다. 성공 출력은 `seed_tenant:`로 시작하는 줄 하나 `seed_tenant: OK tenant=<uuid> memberships=created:<n>/unchanged:<n> authentik=written|unchanged|skipped(drift=<n>) fga=ok`이고 `sub` · 토큰 · URL을 싣지 않는다. 자격이 자리값(`PLACEHOLDER-` 포함)이면 `CommandError`다. 실행은 운영자 `kubectl exec`(web 컨테이너 · runtime 프로필 · app role — B 등급 테이블과 런타임 설정이 필요하다 · Job을 두지 않는다)이고 prod를 먼저 돈다(Authentik attribute는 prod 시드만 쓴다). 선택 인자 `--authentik-token-stdin`은 Authentik 호출에 설정의 장기 토큰 대신 표준 입력 한 줄의 토큰을 쓴다(prod 시드를 운영자 만료 토큰으로 돌릴 때 — 서비스 계정 권한의 확정은 T081 전 사용자 결정). `platform-admin` 그룹은 건드리지 않는다.
  ```
  - (나) 「파생 쓰기 규칙」 첫 하위 항목의 「순서는 DB(정본) → 파생」 바로 뒤(마침표 앞)에 넣는다(W35 — 새 문장 · (가)의 순서 ①과 나란히 읽을 때 그룹 조회의 자리가 달라 보이지 않게).
  ```text
  (쓰기의 순서다 — 그룹 이름 조회(읽기)는 DB 앞에 온다 · 아래 · T073 보정 2026-11-12)
  ```
- **C49** — §2 끝 항목(「**테넌트 컨텍스트가 없는 경로의 `tenant_id` 원천이 이 테이블이다.** … (contracts/events.md·identity-admin-api.md).」) 끝에 덧붙인다 〈설계 커밋〉(D12 · D30 · 〔W35〕 — 새 항목)
  ```text
  (다중 멤버십 · 관리 명령 `revoke_sessions`의 규칙은 contracts/identity-admin-api.md · T073 보정 2026-11-12)
  ```
- **C24** — §3(:55 · :57 · :60-73) · 머리 :7 · 관계 요약 :251 〈설계 커밋〉(D4 · D13 · D14 · D29 · 〔Y15 · E1 · E2 · E6 · W6 · W13 · W14 · W16 · W18 · Z1 · Z8〕)
  - (가) :55 `nbf` 행의 「규칙」 칸 끝(W14 — 앞 라운드 문면을 바꾼다: 둘째 문장 「기록 관문이 `nbf > DB now() + 301 s`를 거부한다」가 아래의 「미래 값은 …」이 된다 — 기준 시계가 경로별이다)
    - (Z8 — 앞 라운드 문면을 바꾼다) 검토 반영이 넣은 구절 「웹훅 본문 `nbf`는 이벤트 `created` 내림 + 1 이하여야 하고(넘으면 400),」이 아래의 「웹훅 본문 `nbf`가 이벤트 `created` 내림 + 1을 넘으면 그 값으로 낮춰 기록하고(거부하지 않는다 — contracts/identity-admin-api.md),」가 된다. 나머지 글자는 그대로다. Z8이 든 자리 목록에는 이 칸이 없지만, 같은 규칙을 적은 문장이라 함께 고친다(그대로 두면 data-model과 api계약이 반대되는 말을 한다 — 설계자 판단 · §10 (라)).
  ```text
  일 1회 대조 보정은 이벤트 `created` 내림 + 1이다. 미래 값은 경로마다 쓰기 전에 막는다 — 웹훅 본문 `nbf`가 이벤트 `created` 내림 + 1을 넘으면 그 값으로 낮춰 기록하고(거부하지 않는다 — contracts/identity-admin-api.md), 관리 명령 `revoke_sessions`는 `nbf > DB now() + 301 s`면 기록하지 않는다(`CommandError`). `/sessions/revoke`의 `nbf`는 서버가 정한다(T073 보정 2026-11-12)
  ```
  - (나) :57 `event_pk` 행의 「규칙」 칸 전체
  ```text
  nullable · **unique** — Authentik 이벤트 `pk`(멱등 키 · 재전송은 이 제약으로 200 no-op · UUID로 읽히면 대시 소문자 정규형으로 저장한다). 웹훅 행과 일 1회 대조 보정 행만 값이 있다(T066 보정 2026-11-03 · T073 보정 2026-11-12)
  ```
  - (다) Dragonfly 키 표(:62-65)에 두 행을 더한다. (W16 — 앞 라운드 문면을 바꾼다: 둘째 행 「TTL」 칸이 `120 s`에서 `300 s`가 된다)
  ```text
  | `identity-admin:session-floor:{sub}` | 그 `sub`의 사용자 단위 행 가운데 가장 큰 `nbf`(epoch 초) — 세션 시작 시각 < 값인 BFF 세션은 inactive(`/session/check`만 읽는다 · T073 보정 2026-11-12) | 그 행 `expires_at + 30 d`까지 |
  | `identity-admin:denylist:reapplied-at` | 마지막 재적용 시각(epoch 초) — 재적용 생존 신호(T073 보정 2026-11-12) | 300 s |
  ```
  - (라) :68 「한 행 = 한 키」 항목 끝에 덧붙인다. (W6 · W13 — 문서 쪽을 이 블록으로 되돌린다: 앞 라운드 반영이 괄호 안에 덧붙인 구절 「`revoke_sessions --sid`가 만든 행은 `sid` 행이다 — contracts/identity-admin-api.md §관리 명령 · 」을 뺀다 — 명령이 사용자 단위뿐이다. 이 블록의 글자는 앞 라운드 그대로다)
  ```text
  사용자 단위 행(`sid` NULL)은 그 밖에 세션 하한 키 `identity-admin:session-floor:{sub}`를 만든다 — 값은 같은 `sub`의 사용자 단위 행 가운데 가장 큰 `nbf`다(contracts/denylist.md §키 스키마). `revoked:*`는 그대로 한 행 = 한 키다. 일 1회 대조 보정 행과 관리 명령 `revoke_sessions`의 행도 같은 규칙이다(T073 보정 2026-11-12).
  ```
  - (마) :69 「쓰기」 항목의 「커밋 후 Dragonfly SET.」
  ```text
  커밋 후 Dragonfly SET(TTL = `min(330, 남은 초)` · 1 미만이면 쓰지 않는다 · 사용자 단위 행은 그 `sub`의 최댓값 행을 읽어 `revoked:sub`와 세션 하한 키를 함께 쓴다 — contracts/denylist.md §쓰기 규약 · T073 보정 2026-11-12).
  ```
  - (바) :70 「재적용」 항목 끝 / :71 「유실 창」 항목 끝 / :72 「보존」 항목 전체 / :73 「상태」 항목 전체(W6 — 넷째 줄을 문서에 들어간 글자와 맞췄다: 끝 괄호에 표식이 들어 있다 · 문서는 그대로다)
  ```text
  같은 키의 행이 여럿이면 `nbf`가 가장 큰 행을 쓰고 TTL 1초 미만은 건너뛴다. 같은 실행이 `sid` NULL이고 `expires_at + 30 d > now()`인 행으로 세션 하한 키를 되살리고 신선도 키를 쓴다(T073 보정 2026-11-12).
  세션 하한도 같은 창이다 — 재적용이 돌아오면 다음 확인에서 다시 inactive가 된다(contracts/denylist.md · T073 보정 2026-11-12).
  - 보존: `expires_at + 30 d` 지난 행을 일 1회 purge(구현 식 `expires_at < now() − 30 d`). 이 30일이 세션 하한 수명이자 `/session/check`의 세션 절대 수명이다(상수 하나 — T073 보정 2026-11-12).
  - 상태: `recorded`(캐시 키 존재) → `expired`(`revoked:*` TTL 만료 — 사용자 단위 행은 세션 하한 키만 남는다) → purge(하한도 끝난다 · T073 보정 2026-11-12).
  ```
  - (사) §3 항목 목록 끝에 한 항목
  ```text
  - 제약 · 인덱스(T073 보정 2026-11-12): unique `srl_event_pk_uniq`(`event_pk`) · check `srl_reason_valid` · 인덱스 `srl_expires_at_idx`(`expires_at` — 재적용 · purge) · 부분 인덱스 `srl_user_floor_idx` = `(sub, nbf DESC) WHERE sid IS NULL`(세션 하한의 `sub`별 최댓값). 마이그레이션은 pod 앱 `identity_admin`의 `0001_initial` 하나다(§1–§3의 세 표 · RLS 연산 없음 — B 등급).
  ```
  - (아) :7 머리 문단 끝 / :251 관계 요약의 `SessionRevocationLog(DB, 정본) ──…` 줄
  ```text
  세션 하한 키는 §3 `SessionRevocation`(파생 캐시)의 키 한 줄이라 엔티티 수는 그대로다(T073 보정 2026-11-12).
  SessionRevocationLog(DB, 정본) ──기동 1회 + 30 s 무조건 재적용──▶ SessionRevocation(Dragonfly 캐시 revoked:sub·revoked:sid ◀──조회── 모든 pod · identity-admin:session-floor ◀──조회── identity-admin /session/check)
  ```
  - (자) :71 「유실 창」 항목의 옛 문장을 바꾼다(W18 — 새 항목: T073 이전 문장이다 · 이 항목에는 (바)가 넣은 표식이 이미 있어 더 달지 않는다): 「**비정상 종료**(OOM·SIGKILL·저장 실패)일 때만 최대 30 s 공백이 생긴다(contracts/denylist.md).」
    - (Z1 — 앞 라운드 문면을 바꾼다) 검토 반영이 넣은 「그 길이는 최대 30 s + 실행 중 작업의 마감(대조 120 s · 위임 한 시도 20 s) + 워커 재접속이다」가 아래의 「그 길이의 상한은 다음 tick(최대 30초) + …이다」가 된다(contracts/denylist.md §쓰기 규약 「유실 창」 — C48과 같은 상한).
  ```text
  **비정상 종료**(OOM·SIGKILL·저장 실패)일 때만 공백이 생기고 그 길이의 상한은 다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속이다(contracts/denylist.md).
  ```
- **C25** — §7 :121 owner role 행의 「규칙」 칸 머리 「테이블 소유, 마이그레이션·시드 전용,」 〈설계 커밋〉(D19)
  ```text
  테이블 소유, 마이그레이션 전용(B 등급 표만 쓰는 시드 명령 `seed_tenant`는 runtime 프로필 · app role로 돈다 — §1 · T073 보정 2026-11-12 — 이전 문구 「마이그레이션·시드 전용」),
  ```
- **C26** — §8 :164 `kv/{env}/authentik/identity-admin` 행 〈설계 커밋〉(D23 · 〔Y7 · Z5〕)
  - (가) 「키」 칸의 `api_token` 괄호 전체
  ```text
  `api_token`(주체: prod = 서비스 계정 `identity-admin` · dev = `identity-admin-ro` — 권한은 §9 「서비스 계정 권한」 표 · 「토큰 revoke」 권한은 없다 · T073 보정 2026-11-12)
  ```
  - (나) 「소비자」 칸의 「`client_id` · `client_secret`(identity-admin 설정 없음 · ESO 동기화만)」
  ```text
  `client_id` · `client_secret`(identity-admin 설정 없음 — pod env에 매핑하지 않는다 · T073 보정 2026-11-12)
  ```
  - (다) 「소비자」 칸 끝에 덧붙인다(Z5 — 이 블록을 문서에 들어간 글자와 맞췄다: 표 칸 끝이라 마침표가 없다 · 문서는 그대로다).
  ```text
  게이트 2에서 면제할 수 있는 이름은 `AUTHENTIK_API_TOKEN` · `OPENFGA_STORE_ID` · `OPENFGA_PRESHARED_KEY` 셋뿐이다(contracts/identity-admin-api.md §identity-admin 전용 설정 · T073 보정 2026-11-12)
  ```
- **C27** — §9 :187 User 행 · :188 Provider 행 · :190 NotificationTransport 행 · 표 아래 〈설계 커밋〉(D16 · D17 · D21 · 〔Y7 · E7 · E8 · W2 · W3 · Z21〕)
  - 검토 반영으로 바뀌는 것은 (가)의 첫 괄호 · (라) · (마) 표의 두 칸이다(W2 · W3 — 앞 라운드 문면을 바꾼다). (다)와 (마)의 나머지는 앞 라운드 그대로다. 재검토 반영으로 바뀌는 것은 (나)의 끝 괄호 하나다(Z21).
  - (가) :187의 두 괄호 — 「(prod; 권한: 사용자 read · `authentik_core.delete_authenticatedsession` · 토큰 revoke)」와 「(사용자 **read만** — Authentik API 토큰은 계정 권한을 그대로 가지므로 토큰 단위 축소가 아니라 별도 계정으로 분리한다)」 — 를 차례로 아래 둘로 바꾼다.
  ```text
  (prod; 권한은 표 아래 「서비스 계정 권한」 — 「토큰 revoke」 권한은 없다: Authentik에서 비슈퍼유저는 남의 OIDC 토큰을 지울 수 없다(소스 판독 — 실측 T081 · VD-T081-2) · T073 보정 2026-11-12)
  (권한은 표 아래 「서비스 계정 권한」 · 지금 계약은 사용자 **read만** — Authentik API 토큰은 계정 권한을 그대로 가지므로 토큰 단위 축소가 아니라 별도 계정으로 분리한다)
  ```
  - (나) :187 끝의 「dev의 Authentik revoke·reconcile **쓰기 호출은 설정 플래그로 비활성**(…)」
    - (Z21 — 앞 라운드 문면을 바꾼다) 끝의 「권한이 없으면 로그 한 줄 뒤 끝난다(T073 보정 2026-11-12)」가 아래 꼴이 된다 — 표 아래 「서비스 계정 권한」의 `view_event` 칸(빈 목록이면 경고 없이 `seen` 0)과 나란히 읽을 때 한 꼴만 말하는 것처럼 읽히지 않게 한다. 첫 문장은 그대로다.
  ```text
  dev의 Authentik 쓰기 호출(세션 삭제 위임 · 시드 쓰기)은 설정 플래그로 비활성이다(시도하지 않고 로그만 — contracts/identity-admin-api.md §identity-admin 전용 설정). 일 1회 대조는 읽기라 플래그와 무관하고 권한이 없으면 로그 한 줄 뒤 끝난다(응답 꼴에 따라 경고 한 줄이거나 `seen` 0 — contracts/identity-admin-api.md §주기 작업 · T073 보정 2026-11-12)
  ```
  - (다) :188 Provider 행의 「SP-1 인스턴스」 칸 끝에 덧붙인다.
  ```text
  `web-bff` · `web-bff-dev`의 scope에는 `openid`와 `offline_access`가 있어야 한다(ID 토큰 `iat` = BFF 세션 시작 시각 · refresh 토큰 발급의 전제). 세션 폐기의 최종성은 refresh 수명에 기대지 않는다 — `/session/check`의 세션 하한과 세션 절대 수명 30일이 맡는다(contracts/denylist.md · T073 보정 2026-11-12)
  ```
  - (라) :190 NotificationTransport 행의 「이벤트 `logout`·`login`·`model_deleted(session)`; 매핑 본문에 `pk`·`created` 포함」
  ```text
  이벤트는 `logout`만(T073 보정 2026-11-12 — 이전 문구 「`logout`·`login`·`model_deleted(session)`」: Authentik은 세션 삭제 이벤트를 만들지 않고 `login`은 토큰 교환마다 생긴다 · 소스 판독 — 실측 T081 · VD-T081-1). 매핑 본문은 JSON 기본형만 쓴다(문자열 · 정수 · bool · null · dict): `pk` = `str(event.pk)`(대시 꼴) · `created` = `event.created.isoformat()` · **`nbf` = `floor(created) + 1`(필수 — 빠지면 수신 시각이 30일 세션 하한 값이 된다)** · `sub` = 이벤트 사용자 UUID · `action`. 같은 이벤트를 여러 번 보내지 않게 수신자를 이벤트 사용자 하나로 둔다(또는 `send_once`). 세션 결속이 깨져 생긴 logout 이벤트를 거를지는 T081이 정한다(기본 = 거르지 않는다 — 일 1회 대조도 같은 기준을 쓴다)
  ```
  - (마) §9 표 아래(「Blueprints는 YAML 파일로 …」 항목 앞)에 표 하나와 그 아래 문단을 더한다.
  ```text
  **서비스 계정 권한(T073 보정 2026-11-12 — 권한마다 쓰는 작업. 어느 계정 · 토큰에 줄지의 확정은 T081 전 사용자 결정)**

  | 권한 | 쓰는 작업 | 없을 때 | 토큰이 새면 |
  |---|---|---|---|
  | `authentik_core.view_user` | 세션 삭제 위임(sub → 사용자) · 일 1회 대조(이벤트 사용자 pk → uuid) · `seed_tenant` 사용자 조회 | 401 · 403 · 404(또는 빈 결과 — T081 실측) → 위임은 로그 뒤 끝나고 대조는 contracts/identity-admin-api.md §주기 작업의 갈래(401 · 403 = 경고 뒤 끝 · 404 = 그 이벤트를 건너뜀)를 따르며 시드는 `CommandError` | 전 사용자의 이메일 · attributes 열람 |
  | `authentik_core.view_authenticatedsession` | 세션 삭제 위임(세션 목록) | 목록이 오류 없이 빈다 → 삭제 0건(조용한 실패 — T081 실측) | 전 사용자의 세션 IP · UA 열람 |
  | `authentik_core.delete_authenticatedsession` | 세션 삭제 위임(단건 DELETE) | 403 · 404 → 로그 | 운영자를 포함한 임의 사용자 강제 로그아웃 |
  | `authentik_events.view_event` | 일 1회 대조(logout 이벤트 72시간 창) | 401 · 403(또는 오류 없는 빈 목록 — T081 실측) → `authentik.reconcile_forbidden` 한 줄 뒤 끝난다(빈 목록이면 경고 없이 `seen` 0으로 끝난다 · 어느 쪽이든 유실 웹훅은 기록되지 않는다) | 감사 이벤트 전체 열람(로그인 IP · UA · 사용자명 · 관리자 행위 — dev · prod가 한 인스턴스라 env를 가르지 않는다) |
  | `authentik_core.view_group` | `seed_tenant` 그룹 조회 | 그룹 0건 → `CommandError` | 그룹 구성 열람 |
  | `authentik_core.add_user_to_group` · `authentik_core.change_user` | `seed_tenant` 쓰기(prod만 — 소속 · `attributes.tenant_id`) | 403 → `CommandError` | 임의 사용자의 그룹 소속 · attributes 변경 · 비활성화(권한 상승 경로) |

  앞의 셋은 런타임(세션 삭제 위임)에 필요하다. `view_event`를 줄지, 시드 쓰기 권한을 pod 장기 토큰에 둘지 운영자 만료 토큰(`seed_tenant --authentik-token-stdin`)에만 둘지는 T081 전에 정한다.
  ```

### contracts/pod-template.md

- **C20** — :3 머리 문단 끝과 :7 「생성 위치·버전 규칙」 문단 〈설계 커밋〉(D2 · D3 · 〔Y6〕)
  - (가) :3 끝에 덧붙인다.
  ```text
  이미 있는 디렉터리에 생성할 때의 실측 꼴(T073 보정 2026-11-12): 저장소 루트를 cwd로 `uv run --project templates/django-pod --locked python -m copier copy --trust --defaults --overwrite --data pod_name=<pod> templates/django-pod apps/<pod>` — 하네스 잠금의 copier를 쓰고, 템플릿 경로가 상대 경로여야 `.copier-answers.yml`의 `_src_path`에 로컬 절대 경로가 남지 않는다. `_tasks: uv lock`이 실패하면 copier는 자기가 새로 만든 대상만 지운다 — 이미 있던 디렉터리는 반쯤 생성된 채 남는다(git 상태를 보고 원인을 고친 뒤 같은 명령을 다시 돈다). 「생성물은 수정 없이 테스트를 통과하고」는 템플릿 기본 pod(sample-pod)의 성질이다 — 고유 로직을 더하는 pod(identity-admin)는 템플릿 소유 파일의 확장 지점을 손으로 고치고 표식과 목록을 생성 README 「재생성」 절에 둔다.
  ```
  - (나) :7의 「(재생성 뒤 diff로 갱신;」
  ```text
  (재생성 뒤 diff로 갱신 — 저장소 루트에서 `uv run --project templates/django-pod --locked python -m copier recopy --trust --defaults --overwrite apps/<pod>`: 기록된 답을 다시 쓰고, 손으로 고친 템플릿 소유 파일은 템플릿 꼴로 되돌아가며 템플릿에 없는 pod 소유 파일은 남는다 → `git diff`를 보고 손 수정 표식 블록을 되살린다 · T073 보정 2026-11-12;
  ```
- **C16** — :25 생성 트리 pyproject 행 〈설계 커밋〉(D28 · D2 · 〔W7〕)
  - 「django-ninja==1.7.0(폴백은 이 계약과 하네스 `_tree.py` NINJA_SPEC 개정 뒤에만 · T072 보정)」 / 「`exclude = ["apps/*", "templates/*"]`로 명시 — T073 · 2026-11-02 T065」
  - (W7 — 앞 라운드 문면을 바꾼다) 둘째 줄의 「T073에서 반영(2026-11-12)」이 「T073 조각 ⓪(생성 커밋)에서 반영」이 된다 — 루트 워크스페이스 변경은 설계 커밋이 아니라 생성 커밋(D2 1단계)에서 일어난다. 날짜를 박지 않는다. 첫 줄은 그대로다.
  ```text
  django-ninja==1.7.0(폴백은 1.6.5 — 이 계약과 하네스 `_tree.py` NINJA_SPEC 개정 뒤에만 · T072 보정 · T073 보정 2026-11-12)
  `exclude = ["apps/*", "templates/*"]`로 명시 — T073 조각 ⓪(생성 커밋)에서 반영 · 2026-11-02 T065
  ```
- **C17** — :58 owner role 항목의 「마이그레이션·시드 전용, 런타임 pod에는 자격이 없다.」 〈설계 커밋〉(D19)
  ```text
  마이그레이션 전용, 런타임 pod에는 자격이 없다(B 등급 표만 쓰는 시드 명령 — identity-admin `seed_tenant` — 은 runtime 프로필 · app role로 돈다 · T073 보정 2026-11-12 — 이전 문구 「마이그레이션·시드 전용」).
  ```
- **C18** — :69 프로브 행의 괄호 「(PreSync migrate Job이 끝난 직후 커넥션·GUC 설정·거부 목록 기동 재적용이 완료될 때까지 liveness가 pod를 죽이지 않게 한다)」 〈설계 커밋〉(G6)
  ```text
  (PreSync migrate Job이 끝난 직후 커넥션·GUC 설정이 완료될 때까지 liveness가 pod를 죽이지 않게 한다 — 거부 목록 기동 재적용은 web 컨테이너가 아니라 celery 컨테이너의 `beat_init`에서 일어나 이 프로브와 무관하다 · T073 보정 2026-11-12)
  ```
- **C19** — :79 Dragonfly 행의 「— 읽기 전용은 `%R~` 패턴으로만 표현한다, contracts/denylist.md)」 〈설계 커밋〉(D24)
  ```text
  — 읽기 전용은 `%R~` 패턴으로만 표현한다, contracts/denylist.md · 예외: 거부 목록을 쓰는 identity-admin은 `~revoked:* ~identity-admin:* +@all`이고 그 생성물의 compose aclfile · 시험 conftest도 같은 규칙으로 손 수정한다 — T073 보정 2026-11-12)
  ```
- **C46** — :84 설정 행의 「— 템플릿은 빈 집합)」 / :95 §타임아웃 · 재시도 표의 「pod → Authentik」 행 전체 〈설계 커밋〉(D6 · D16)
  ```text
  — 템플릿은 빈 집합 · identity-admin은 나가는 쪽 자격 셋: contracts/identity-admin-api.md §identity-admin 전용 설정 · T073 보정 2026-11-12)
  | pod → Authentik | 호출마다 5 s · 세션 삭제 위임 재시도 5 → 10 → 20 s(Celery · 창 `nbf + 300 s` — contracts/identity-admin-api.md §타임아웃 · T073 보정 2026-11-12) |
  ```

### contracts/gitops-repo.md

- **C32** — :172 「pod마다 ExternalSecret 2개」 항목 끝에 덧붙임 〈설계 커밋〉(D23)
  ```text
  identity-admin의 `<pod>-env`는 템플릿 base의 `data[0..7]` 뒤에 `data[8..11]`을 더한다 — `authentik_api_token`(`{env}/authentik/identity-admin` · `api_token`) · `authentik_webhook_secret`(`{env}/authentik/webhooks/identity-admin` · `secret`) · `openfga_store_id`(`{env}/openfga/store_id` · `store_id`) · `openfga_preshared_key`(`{env}/openfga/preshared` · `key`). 순번은 prod overlay의 JSON6902 `op: test`가 secretKey로 확인한다. `client_id` · `client_secret`은 매핑하지 않는다(T073 보정 2026-11-12).
  ```

### quickstart.md

- **C33** — :90 · :91 US4 폐기 단계와 그 아래 줄 · US6 코드 블록 〈설계 커밋〉(D25 · 〔Y1 · W35 · Z2 · Z21〕 · G3)
  - (가) :90 끝에 덧붙인다 / (나) :91의 첫 문장(「… 같은 401.」) 뒤에 넣는다. 기존 문장은 고치지 않는다((나)는 앞 라운드 그대로다).
    - (Z2 — 앞 라운드 문면을 바꾼다) (가)의 괄호 「(교환 토큰에는 `sid`가 없어 … BFF의 기본 로그아웃 범위는 T089 전 사용자 결정 · T073 보정 2026-11-12)」가 아래 첫 줄이 된다 — 「T089 전 사용자 결정」 뒤를 마침표로 끊고 `tester-m2m` 문장을 넣는다(이 단계의 curl이 Access 서비스 토큰 헤더로 pod를 직접 부르는데, 그 토큰이 `tester-m2m`이면 pod의 `common_name` 검사에서 403이다 — 〔편차 27〕). 표식은 그 괄호에 하나 그대로다.
  ```text
  (교환 토큰에는 `sid`가 없어 이 401은 사용자 단위 폐기 — 전체 기기 로그아웃 — 에서만 난다. BFF의 기본 로그아웃 범위는 T089 전 사용자 결정. pod는 Access `common_name`이 web-bff Client ID인 호출만 받으므로 이 curl의 Access 헤더가 `tester-m2m`이면 401이 아니라 403 `access_required`다 — 측정 경로는 T079 설계가 정한다 · T073 보정 2026-11-12)
  로그의 꼴은 이벤트 `session_revocation.recorded`(필드 `reason` = `authentik_webhook`)다. Authentik 2026.8은 세션 삭제에 이벤트를 만들지 않으므로 이 단계가 무엇으로 일어나는지(로그아웃 이벤트 웹훅 등)는 T081 전 사용자 결정이다(T073 보정 2026-11-12).
  ```
  - (다) US4 4번 바로 아래 줄(작업 트리 기준 :92 — 「폐기 3경로 E2E(T085)와 SC-003(≤ 2 s) 측정은 …」) 전체를 아래로 바꾼다(W35 — 새 항목: 「dev의 revoke·reconcile 쓰기 호출은 설정 플래그로 비활성(로그만)이라,」가 계약 C7 · C8 · C27과 어긋난다 — 플래그가 끄는 것은 Authentik에 쓰는 호출이고 대조는 읽기다). 줄 머리의 들여쓰기(빈칸 셋 — 4번 항목에 이어지는 줄이다)는 그대로 둔다.
    - (Z21 — 앞 라운드 문면을 바꾼다) 끝의 「권한이 없으면 로그 한 줄 뒤 끝난다(T073 보정 2026-11-12).」가 아래 꼴이 된다(data-model §9 User 행의 C27 (나)와 같은 구절 — 「로그 한 줄」이 경고 한 줄만 뜻하는 것으로 읽히지 않게). 나머지 글자는 그대로다.
  ```text
  폐기 3경로 E2E(T085)와 SC-003(≤ 2 s) 측정은 **prod 체인에서만** 한다 — dev의 Authentik 자격은 dev 전용 서비스 계정 `identity-admin-ro`(사용자 read만, `kv/dev/authentik/identity-admin.api_token`)이고 dev에서는 Authentik에 쓰는 호출(세션 삭제 위임 · 시드 쓰기)을 설정 플래그로 끄므로(시도하지 않고 로그만), dev 로그아웃 검증은 denylist 401·로컬 세션 삭제까지만 본다. 일 1회 대조는 읽기라 플래그와 무관하고 권한이 없으면 로그 한 줄 뒤 끝난다(응답 꼴에 따라 경고 한 줄이거나 `seen` 0 — contracts/identity-admin-api.md §주기 작업 · T073 보정 2026-11-12).
  ```
  - (라) US6 코드 블록의 identity-admin 주석 줄(작업 트리 기준 :121 — 「# identity-admin API 계약 테스트(T066 test-first → T073이 초록) — …」) 전체를 아래로 바꾼다(W35 — 새 항목: T073 시험 파일을 더한다).
  ```text
  # identity-admin API 계약 테스트(T066 test-first → T073이 초록) — 생성물 내장 7종 + test_api.py + 가짜 Authentik·OpenFGA 자기검사 + T073 시험 tests/test_identity_*.py(T073 보정 2026-11-12)
  ```

### 규칙 `.claude/rules/django-pod.md`(영어 정본)와 미러 `docs/kr/rules/django-pod_kr.md`

영어 정본은 영어로, 미러는 같은 자리에 같은 뜻으로 옮긴다. 미러 첫 줄의 translation-pending 안내는 그대로 둔다. 줄 번호는 영어 정본 / 미러 순이다.

- **C30** — §Template and structure :18 · :22 / 미러 :20 뒤 〈설계 커밋〉(D2 · D3 · 〔Y6〕)
  - (가) 영어 :18 항목 전체
  ```text
  - Pods are generated with `copier copy --trust --defaults --data pod_name=<pod> templates/django-pod apps/<pod>` (`--trust` is required by the template's `_tasks: uv lock`), run from the repository root with the harness copier — `uv run --project templates/django-pod --locked python -m copier …` — and a relative template path, so that `.copier-answers.yml` records no local absolute path; add `--overwrite` when the target directory already exists (T073). The default generated pod (sample-pod) must pass its tests unmodified; a pod that adds its own logic (identity-admin) edits template-owned files only at their extension points, marks each edit, and lists the edits in its README (T073). Every pod depends on `packages/django-common` (never copy common code into a pod).
  ```
  - (나) 영어 :22 항목 전체
  ```text
  - The in-monorepo template path is not a git repository root, so copier reads the working tree and records no `_commit`; `copier update` is unsupported in SP-1 — regenerate and diff instead: from the repository root run `uv run --project templates/django-pod --locked python -m copier recopy --trust --defaults --overwrite apps/<pod>` (it reuses the recorded answers, reverts hand-edited template-owned files and keeps pod-owned files the template does not render), then restore the marked edits from `git diff`. When `_tasks: uv lock` fails, copier removes only a target directory it created itself — an existing directory is left half-generated (T073).
  ```
  - (다) 미러 :20 항목 전체 / 그 뒤에 새 항목 하나
  ```text
  - pod는 `copier copy --trust --defaults --data pod_name=<pod> templates/django-pod apps/<pod>`로 생성한다(`--trust`는 템플릿의 `_tasks: uv lock` 때문에 필요하다). 저장소 루트에서 하네스 copier(`uv run --project templates/django-pod --locked python -m copier …`)와 상대 템플릿 경로로 돌려 `.copier-answers.yml`에 로컬 절대 경로가 남지 않게 하고, 대상 디렉터리가 이미 있으면 `--overwrite`를 더한다(T073). 기본 생성 pod(sample-pod)는 수정 없이 자기 테스트를 통과해야 한다; 고유 로직을 더하는 pod(identity-admin)는 템플릿 소유 파일을 확장 지점에서만 고치고 고친 자리마다 표식을 달며 그 목록을 README에 둔다(T073). 모든 pod는 `packages/django-common`에 의존한다(공통 코드를 pod로 복사하지 않는다).
  - 모노레포 안 템플릿 경로는 git 저장소 루트가 아니라서 copier가 작업 트리를 읽고 `_commit`을 남기지 않는다; `copier update`는 SP-1에서 지원하지 않는다 — 다시 생성하고 diff로 옮긴다: 저장소 루트에서 `uv run --project templates/django-pod --locked python -m copier recopy --trust --defaults --overwrite apps/<pod>`를 돌리고(기록된 답을 다시 쓰고, 손으로 고친 템플릿 소유 파일은 되돌아가며, 템플릿이 만들지 않는 pod 소유 파일은 남는다) `git diff`에서 표식 달린 수정을 되살린다. `_tasks: uv lock`이 실패하면 copier는 자기가 만든 대상 디렉터리만 지운다 — 이미 있던 디렉터리는 반쯤 생성된 채 남는다(T073).
  ```
- **C28** — §Table grades Roles 항목 영어 :31 / 미러 :28 전체 〈설계 커밋〉(D19)
  ```text
  - Roles: owner role has `bypassrls` and is used by migrations only — NEVER at runtime; app role is `NOBYPASSRLS`. A seed command that writes grade-B tables only (identity-admin `seed_tenant`) runs under the runtime profile with the app role (T073). DB and role names are env-separated (`dev_` prefix in dev); never share a role across envs.
  - 역할(role): owner 역할은 `bypassrls`를 가지며 마이그레이션 전용이다 — 런타임에는 절대 쓰지 않는다; app 역할은 `NOBYPASSRLS`다. B 등급 표만 쓰는 시드 명령(identity-admin `seed_tenant`)은 runtime 프로필 · app 역할로 돈다(T073). DB와 역할 이름은 환경별로 분리한다(dev는 `dev_` 접두); 역할을 환경 간에 절대 공유하지 않는다.
  ```
- **C47** — §Errors 끝에 새 항목(영어 :65 뒤) / 미러에는 §Errors 절이 아직 없다 — `## Settings` 절과 `## Tests (mandatory, constitution II)` 절 사이에 `## Errors` 제목을 만들고 이 항목 하나만 옮긴다(나머지 두 항목은 기존 translation-pending 범위다) 〈설계 커밋〉(D28 · 〔Y9〕)
  ```text
  - While the pin stays at django-ninja 1.7.0, a view returns either a dict or an instance of exactly the declared response schema — never an instance of a subclass (with 1.7.0 a subclass instance can put fields outside the declared schema into the response; django-ninja #1823, fixed in 1.7.3). Return non-200 responses with `Status(code, body)`, not a `(code, body)` tuple (T073).
  - 핀이 django-ninja 1.7.0에 머무는 동안 뷰는 dict 또는 선언한 응답 스키마의 정확한 인스턴스만 반환한다 — 하위 클래스 인스턴스는 반환하지 않는다(1.7.0에서는 하위 클래스 인스턴스가 선언 밖 필드를 응답에 실을 수 있다; django-ninja #1823 · 1.7.3에서 고쳐짐). 200이 아닌 응답은 `(code, body)` 튜플이 아니라 `Status(code, body)`로 낸다(T073).
  ```
- **C29** — §Dragonfly 항목 끝에 덧붙임 영어 :82 / 미러 :61 〈설계 커밋〉(D24 · D29)
  ```text
  Exception: identity-admin, the only writer of the denylist, uses `~revoked:* ~identity-admin:* +@all`, and its generated compose aclfile and test conftest carry the same rule (`contracts/denylist.md` §ACL). Keys a pod derives for itself also live under its own prefix (identity-admin: `identity-admin:session-floor:{sub}`, `identity-admin:denylist:reapplied-at`) (T073).
  예외: 거부 목록을 쓰는 유일한 pod인 identity-admin은 `~revoked:* ~identity-admin:* +@all`이고, 그 생성물의 compose aclfile과 시험 conftest도 같은 규칙이다(`contracts/denylist.md` §ACL). pod가 스스로 파생하는 키도 자기 접두 아래에 둔다(identity-admin: `identity-admin:session-floor:{sub}` · `identity-admin:denylist:reapplied-at`)(T073).
  ```

### 조각 ⓪ 소속(템플릿 파일 — 설계 커밋에서는 고치지 않는다)

템플릿 변경이라 규칙:24에 따라 하네스 전체를 돌린다(D3). 줄 나눔은 그 파일의 폭에 맞춘다.

- **C34** — `templates/django-pod/template/README.md.jinja` 〈조각 ⓪〉(D3 · D28 · 〔Y6 · Y9〕)
  - (가) :286-298 「## 재생성」 절의 본문 전체를 아래로 바꾼다(제목은 그대로).
  ````text
  `copier update`는 지원하지 않는다(모노레포 안 템플릿이라 `_commit`이 없다). 템플릿이 바뀌면 같은 답으로 다시 생성하고 diff로 옮긴다 — 저장소 루트를 cwd로 두고 하네스 잠금의 copier로 돌린다(맨 `copier`가 아니다). `.copier-answers.yml`에 기록된 답은 `--defaults`가 다시 쓴다(`--data`로 되풀이하지 않는다):

  ```sh
  uv run --project templates/django-pod --locked python -m copier recopy --trust --defaults --overwrite apps/{{ pod_name }}
  ```

  손으로 고친 템플릿 소유 파일은 템플릿 꼴로 되돌아가고, 템플릿에 없는 pod 소유 파일은 그대로 남는다 — `git diff`를 보고 고친 자리(conf.py의 목록 · 시험 상수 등)를 다시 옮긴다.

  `_tasks: uv lock`이 실패하면 copier는 자기가 새로 만든 대상 디렉터리만 지운다(`--no-cleanup`으로 남겨 원인을 본다). 이미 있던 디렉터리는 지우지 않으므로 반쯤 생성된 채 남는다 — `git status`로 확인하고 원인을 고친 뒤 같은 명령을 다시 돈다.
  ````
  - (나) 「## OpenAPI 스냅샷 갱신」 절 앞에 새 절 하나를 더한다.
  ```text
  ## 뷰 응답 규칙

  django-ninja 핀이 1.7.0에 머무는 동안 뷰는 dict 또는 선언한 응답 스키마의 정확한 인스턴스만 돌려준다. 하위 클래스 인스턴스는 선언 밖 필드를 응답에 실을 수 있다(규칙 django-pod.md §Errors). 200이 아닌 응답은 `Status(code, body)`로 낸다(튜플 반환은 폐기 경고가 난다).
  ```
- **C35** — `templates/django-pod/copier.yml` 머리 주석 :3-6(Usage 문단)을 아래로 바꾼다 〈조각 ⓪〉(D3)
  ```text
  # Usage (from the repository root, with the harness copier and a relative template path):
  #   uv run --project templates/django-pod --locked python -m copier copy --trust --defaults --data pod_name=<pod> templates/django-pod apps/<pod>
  #   (add --overwrite when apps/<pod> already exists.)
  #   --trust is required: _tasks runs `uv lock` inside the generated pod (needs PyPI). If the task fails, copier deletes
  #   only a destination it created itself (rerun with --no-cleanup to keep it for debugging); an existing directory is
  #   left half-generated — check git status, fix the cause and rerun.
  ```
- (C31은 비운다. contracts/events.md · contracts/network-policy.md · contracts/hostnames-and-access.md는 무변경이다.)

---

## 5. 빌드 조각

**공통 환경**
- Windows 호스트 · Docker Desktop.
- **arm64 binfmt**: 이 PC는 Docker Desktop · WSL을 다시 켤 때마다 arm64 binfmt가 꺼져 `exec format error`가 난다. 하네스(buildx arm64)와 VD-T073-9 앞에서 아래 명령을 돈다(T072에서 쓴 것 그대로 — digest 핀 이미지 · 손 컨테이너. bn에는 digest가 잘려 있어 전문을 여기 싣는다). Docker Desktop을 다시 띄우면(아래 컨테이너 시계 보정 포함) 다시 등록한다. 확인은 `docker buildx inspect --bootstrap`의 Platforms에 `linux/arm64`가 있는지로 한다. 〔Y11 · W31〕
  ```
  docker run --privileged --rm tonistiigi/binfmt@sha256:400a4873b838d1b89194d982c45e5fb3cda4593fbfd7e08a02e76b03b21166f0 --install arm64
  ```
- copier는 하네스 venv를 `uv run --project templates/django-pod`로 쓴다.
- `kustomize` · `kubeconform`은 `.superpowers/bin`을 PATH 앞에 둔다(또는 `JT_KUSTOMIZE` · `JT_KUBECONFORM` — t072 공통 환경).
- 하네스를 돌릴 때는 짧은 `JT_SAMPLE_POD_ROOT`를 쓴다(저장소 밖 · 조상 아님).
- 누출 탐침 위생: 허용 목록 env + 심은 가짜 값만 쓴다(bn:4440 사고 교훈).
- 바꾼 파일마다 gitleaks로 exit 0을 확인한다(X33).
- 반복 중에는 노드 ID만(`uv run --directory apps/identity-admin --locked pytest -q tests/…::…`), 전체 실행은 조각 끝에 한 번이다.
- pod 스위트를 동시에 둘 돌리지 않는다. pg-tls 태그를 같이 쓴다(〔P38〕). 조각마다 도는 리뷰 렌즈 · django-common 스위트 · 템플릿 하네스도 여기에 든다 — pg-tls 이미지 · 하네스 이미지 태그 · 스모크 컨테이너 쓸기가 부딪힌다(빌더와 리뷰 렌즈가 같은 시간에 스위트를 돌리지 않는다 · 〔W35〕).
- **`tests/run-all.ps1` 전체는 어느 조각에서도 돌리지 않는다**(〔W32〕 — tofu plan 슬롯이 운영자 프로필을 쓴다 · bn:1015 · 한 번에 약 45분). 필요한 슬롯의 명령만 따로 돈다. T073이 고치는 ps1 하네스는 `tests/scripts/kubeconform-deploy.tests.ps1` 하나다(조각 ⑥ · D27).
- **컨테이너 시계**(〔W14〕 — 대상이 ia-26 하나로 줄었다): DB 시계에 기대는 시험은 실제 DB 시계로 `revoke_sessions`를 도는 ia-26뿐이다 — 명령의 관문(D12)이 `nbf`를 DB 시계 + 301 s와 견주므로 DB 컨테이너가 시험 프로세스보다 300 s 넘게 늦으면 `CommandError`다. T066의 revoke · 웹훅 시험은 DB 시계를 보지 않는다. ia-26이 든 **모든** 전체 실행 앞에서 Docker 쪽 시계와 호스트 시계를 견준다 — ia-26이 생기는 조각 ③-b2부터 마지막 조각의 닫기까지다(③-b2 · ④ · ⑤-a · ⑤-b · ⑥ · ⑦의 끝 실행 · 〔Z6〕 — 조각 사이에 호스트가 절전하면 뒤 조각의 「앞 조각까지의 초록 유지」가 시험 결함처럼 `CommandError`로 깨져 보인다). 견주는 법은 `docker run --rm <시험이 쓰는 pg 이미지> date -u +%s`와 호스트의 epoch 초다(차이가 몇 초 안이어야 한다). 어긋나 있으면 Docker Desktop을 다시 띄워 맞춘 뒤 돈다(binfmt도 다시 등록한다).
- 조각마다 그 결정의 「변이」 줄을 실제로 넣어 적힌 시험이 빨강이 되는지 보고 되돌린다. 잡지 못한 변이는 bn 「T073」 절에 한계로 적는다.
- 조각 끝마다 깨진 템플릿 소유 시험을 다시 센다. 더 깨졌으면 D3의 두 갈래를 따른다(〔W22〕) — (가) 템플릿 기본값을 적은 단언(필수 · 비밀 상수 · beat 항목 목록 · OpenAPI 스냅샷 · ACL 규칙 문자열)만 삭제 · skip 없이 기대값을 pod 계약으로 바꾸고 D3의 손 수정 목록과 README 표를 갱신한다. (나) 불변식 단언(migrate 프로필의 celery 미import · 런타임 설정 0 / 기동 중 이름 조회 0 · 기동 위생 / app role 권한의 정확 일치 / relay 레지스트리에 web 지표 없음)은 기대값을 건드리지 않고 코드를 고친다. 두 목록에 없는 템플릿 소유 시험이 깨지면 고치지 않고 컨트롤러에 보고한다.
- 빌더는 커밋하지 않는다(컨트롤러가 파일 이름으로 스테이징한다).
- **조각 ②–⑦의 차례**(〔W24〕 — test-first를 조각 안에서 지킨다): ⓐ 그 조각의 ia 시험 작성(그 조각 「기대 초록」의 ia 번호 — 시험 줄과 변이 줄은 각 결정) → ⓑ 빨강 확인(노드별 사유 = 「구현 없음」 — 그 표를 보고에 싣는다 · 수집 오류와 픽스처 오류는 0이어야 한다) → ⓒ 구현 → ⓓ 초록(그 조각의 「기대 초록」 + 앞 조각까지의 초록 유지) → ⓔ 그 결정의 변이 줄 확인.
  - **구현 전에 초록인 노드**(ⓑ · 〔Z7〕): 구현 전에 이미 초록인 노드가 나오면 양성 대조(같은 준비물의 정상 사례 — D26 「부정 사례의 짝」)를 넣어 빨강으로 만들고 그 표에 적는다. 그래도 초록이면 그 까닭을 보고에 적는다.
  - ia 시험 파일 넷(D1)은 그 파일에 드는 ia 시험을 처음 쓰는 조각이 만든다.
  - 뒤 조각은 앞 조각이 쓴 ia 시험 · 도우미 · 가짜의 결함을 고칠 수 있다. 고친 것은 보고와 bn에 적는다(T066 세 파일은 여전히 독스트링만 고친다 — D26).

**커밋 셋**: 설계 커밋(이 문서 + §4의 〈설계 커밋〉 항목) · 생성 커밋(조각 ⓪ — C34 · C35 · 루트 워크스페이스 · 순정 생성 트리. 재생성 diff의 기준이다) · 구현 커밋(조각 ①–⑦).

**순서**(〔Y3〕): 외부 HTTP 클라이언트(④)가 그것을 쓰는 Celery 작업(⑤)보다 앞이다. 마지막 조각은 `openfga.py` + `seed_tenant`이고, 전체 닫기 실행을 그 끝 조건에 둔다.

- **⓪ 템플릿 문서 정정 · 루트 워크스페이스 · 순정 생성**
  - 입력: D2 · D3 · C34 · C35.
  - 산출: `T/README.md.jinja` · `H/copier.yml`(문서 · 주석만) · 루트 `pyproject.toml` · `uv.lock` · `apps/identity-admin/**` 순정 생성 트리(T066 세 파일은 그대로).
  - 차례: C34 · C35 → 하네스 전체 → 루트 워크스페이스 · 잠금(D2 1 · 2) → 생성(D2 3 · 4).
  - 검증 명령
    - `uv run --directory templates/django-pod --locked pytest -q`(하네스 918 — 템플릿 문서를 고친 뒤)
    - 루트 `uv lock --check` · `uv sync --locked` / pod `uv lock --check` · `uv sync --locked`
    - `uv run --directory apps/identity-admin --locked pytest -q`(순정 트리 — 아래 기대대로 빨강이 섞인다)
  - 기대: 템플릿 시험 165 passed · T066 13 passed / 63 failed(사유가 사실 ①의 8묶음과 노드별로 맞다) · 가짜 자기검사 26 passed.
    - 순정 트리에서 이미 초록인 13개는 api-1 · 2 · 3 · 52(헬스) · 5 · 35 · 42 · 43 · 46 · 47의 둘 · 49의 하나 · 54다(〔T1〕). 뒤 조각의 「기대 초록」에는 새로 초록이 되는 것만 적는다 — 이 13개는 모든 조각 끝에서 초록 그대로여야 한다(api-5는 구현 없이도 403이라 판별력이 없다 — Access 전용 경로의 판별은 api-4 · 44가 맡는다).
  - VD-T073-1 · 2. 3-way 재생성 리허설(VD-T073-11)은 여기서 재지 않는다 — 생성 커밋도 손 수정도 아직 없다. 조각 ⑥ 끝 뒤의 컨트롤러 단계로 옮겼다(〔W23〕).
  - 끝 조건: 순정 생성 트리가 손 수정 없이 그대로 커밋 가능하다(생성 커밋).
- **① 토대**(〔W24〕 — ia 시험은 여기서 쓰지 않는다. 한 빌더가 ia 41묶음을 오라클 없이 한 번에 쓰면 시험의 결함이 「구현 없음」 뒤에 숨는다 — 검토 C-3)
  - 입력: D26(도우미 · 가짜 둘 · 배선 · T066 독스트링 정합).
  - 산출: `_ia_support.py` · `_ia_fakes.py`(가짜 둘 — D26 · 〔W27〕) · `test_ia_fakes.py` · conftest 배선 두 줄(손 수정 ⑩ 가운데 `pytest_plugins` · `register_assert_rewrite`) · T066 독스트링 정합.
  - 검증: `pytest --collect-only -q` 수집 성공 · `test_ia_fakes.py` 초록 · T066 세 파일의 AST 동일(독스트링 · 주석을 뺀 AST 덤프가 전후 같다 — D26).
  - 끝 조건: 위 셋이다(수집 성공 · `test_ia_fakes.py` 초록 · T066 세 파일의 AST 동일). 순정 트리의 결과(템플릿 165 · T066 13 / 63 · 가짜 자기검사 26)는 그대로여야 한다.
- **② 설정 · 모델 · 마이그레이션 · ACL**
  - 범위: D4–D7 · D18의 conf 부분 · D24 · D29의 상수(`session_floor.py` — 상수와 키 이름만).
  - 산출: 손 수정 ① ② ⑥ ⑦ ⑩(ACL 규칙 · 독스트링) ⑪ · `models.py` · `migrations/` · `session_floor.py`.
  - 차례: ia-20 · 23 · 24 작성 → 빨강 확인 → 구현 → 초록 → 변이 줄(D4 · D5 · D6 · D7 · D24).
  - `0001_initial` 생성 명령(〔W31〕 — **예상 꼴이다: 실행으로 확인한 적이 없다.** 조각 ②가 실제로 돈 꼴을 보고에 남긴다): pod 루트에서 `DJANGO_SETTINGS_MODULE=tests.settings uv run --locked python manage.py makemigrations identity_admin`(PowerShell이면 `$env:DJANGO_SETTINGS_MODULE = 'tests.settings'`를 먼저 둔다). `manage.py`의 기본 설정은 pod 설정이라 런타임 env 전부가 필요하므로 시험 래퍼 설정으로 돈다. 래퍼의 DB는 닫힌 포트라 이력 검사가 DB에 닿지 못하는데, 그때 Django가 경고 한 줄 뒤 진행한다는 것은 소스 판독이다(`makemigrations` — 실측 전).
  - 기대 초록: T066 기동 17 전부(api-46–49 · 54 · 55 — 순정 트리에서 초록이던 다섯을 포함해 열일곱이 다 초록 · 새로 초록이 되는 것은 conf 묶음 열둘) · 생성물 기본 시험 전부(174 추정) · `makemigrations --check` · lintmigrations · ia-20 · 23 · 24.
  - api-29(배정은 ③-a)가 이 조각 끝에서 먼저 초록이 될 수 있다 — 모델만 있으면 handler404가 같은 404 `not_found`를 낸다. 그 경우 이 조각의 초록으로 세고 보고에 적는다(〔Z7〕 — 배정의 합계 표의 주).
  - VD-T073-3 · 16.
- **③ 엔드포인트 · 기록 · 쓰기 · 하한 · 관리 명령 · 관측**
  - 범위: D8–D13 · D25 · D29 · D30 · `api.py` 연결(손 수정 ③) · 스냅샷(⑨).
  - 산출: `identity_api.py` · `revocation.py` · `denylist_writer.py`(클라이언트 · `apply_user` · `apply_sid`) · `session_floor.py`(`read_floor` · `is_active`) · `identity_metrics.py` · `management/commands/revoke_sessions.py`.
  - 가장 큰 조각이라 셋으로 나눠 돌린다 — ③-a · ③-b1 · ③-b2(〔Z20〕 — 검토 반영 때 「쓰기와 기록」 한 조각이던 것을 둘로 갈랐다: 가르기 전의 조각 ⑤보다 컸다 · 재검토 RB-16). 조각마다 차례는 공통 환경의 ⓐ–ⓔ다.
    - **③-a 읽기와 판정**(D8 · D11 · D29의 읽기 — `identity_api.py`의 `/session/check` · `/tenants/me` · `session_floor.py`의 `read_floor` · `is_active` · `denylist_writer.py`의 `client`)
      - 기대 초록: api-4 · 6–9 · 27–29 · 44 · 45 · 53(OpenAPI에 `/session/check` 경로가 생긴다) · ia-1 · 2 · 21 · 25 · 29 · 30 · 36 · 37
      - ia-25는 여기다(〔Z7〕 — 지나는 것이 미들웨어와 `/tenants/me`뿐이라 구현 전 404 → 구현 뒤 200이다. 쓰기 조각에 두면 구현 전에 이미 초록이다).
      - api-29는 조각 ② 끝에서 먼저 초록이 될 수 있다(〔Z7〕 — 모델만 있으면 `/tenants/me`가 없어도 handler404가 같은 404 `not_found`를 낸다 · 원문 판독). 그 경우 ②의 초록으로 세고 보고에 적는다 — `/tenants/me`의 판별은 api-27 · 28이 맡는다.
    - **③-b1 revoke · 기록 공통 · 쓰기 · 지표**(D9 · D12 · D13 · D25 · D29의 쓰기 — `identity_api.py`의 `/sessions/revoke` · `revocation.py` · `denylist_writer.py`의 `apply_user` · `apply_sid` · `identity_metrics.py`)
      - 기대 초록: api-10–19 · 51 · ia-4 · 28
    - **③-b2 웹훅 · 관리 명령**(D10 · D30 — `identity_api.py`의 `/webhooks/authentik` · `management/commands/revoke_sessions.py`)
      - 기대 초록: api-20–25 · 50(네 경로가 다 있어야 한다) · ia-3 · 5–8 · 11 · 17 · 19 · 26 · 27 · 31 · 34 · 35 · 39(a · b · c)
    - **ia의 자리**(〔Z20〕): ia 시험은 「그 시험이 지나는 경로가 다 있는 첫 조각」에 둔다. 웹훅이나 관리 명령을 지나는 ia는 ③-b2다 — revoke와 웹훅을 다 보는 묶음(ia-5 · 11 · 17 · 19 · 27 · 39)도 그렇다. revoke만 지나는 ia-4 · 28이 ③-b1이다.
      - 그 결과 ③-b1 구현(`revocation.py`의 관문과 커밋 뒤 콜백 · `denylist_writer`의 쓰기)의 변이 줄 가운데 ③-b2의 ia가 잡는 것 — D12의 ia-7 · 11 · 26 · 39 · D13의 ia-19 · 31 · D16의 ia-11 · D22의 ia-17 · D29의 ia-31 · 34 — 은 ③-b2의 ⓔ에서 확인한다(변이 줄이 가리키는 시험이 뒤 조각에서 생기면 그 조각의 ⓔ에서 본다 — 조각 ②의 D4 변이가 가리키는 api-10 · ia-7도 같다). ③-b1의 ⓔ는 그 조각에 있는 시험(api-10–19 · 51 · ia-4 · 28 · 생성물 기본 시험)이 잡는 변이까지다.
      - ③-b2의 ⓑ(빨강 확인)에서 revoke 경로만 지나는 노드는 ③-b1 산출로 이미 초록일 수 있다 — 그 표에 까닭(「③-b1 산출」)을 적는다(공통 환경의 「구현 전에 초록인 노드」).
      - **사례 단위 가름**(컨트롤러 마감 — 위 규칙대로면 ia가 ③-b1에 둘 · ③-b2에 열넷이라 ③-b1 구현을 지키는 ia가 한 조각 늦는다): 두 경로를 다 보는 묶음 ia-5 · 11 · 17 · 19 · 27 · 31은 사례 단위로 가른다. revoke 경로와 `record_revocation` 직접 호출만으로 서는 사례 — ia-5의 관리자 호출 · ia-11의 「웹훅 → 0」을 뺀 전부 · ia-17의 `logout` · `logout_all` · `admin` · ia-19의 revoke 경로와 SET 실패 경로(`apply_user` 직접 호출 포함) · ia-27의 `all_devices`와 관리자 호출 · ia-31의 역순 커밋 — 는 ③-b1이 먼저 쓰고, 웹훅 · 관리 명령을 지나는 사례는 ③-b2가 같은 묶음(같은 번호 · 같은 시험 파일)에 더한다. 번호는 다시 매기지 않고, 「기대 초록」과 「배정의 합계」 표는 묶음이 다 차는 ③-b2에 한 번만 센다. ③-b1의 ⓔ는 그 사례들이 잡는 변이(D12 콜백 ④의 건너뛰기 · D13의 0.2 s와 최댓값 조회 · D16의 `expires` · D22의 reason)까지 먼저 확인하고, 웹훅 · 명령 사례가 잡는 변이만 위 줄대로 ③-b2에서 본다.
    - 스냅샷(손 수정 ⑨)은 경로가 는 ③-a · ③-b1 · ③-b2 끝에서 각각 다시 쓰고 경로별로 검토한다(셋 다 같은 구현 커밋 안이다 — 규칙:86). 다시 쓰지 않으면 템플릿 소유 스냅샷 시험이 빨강이다.
  - 위임 enqueue는 이름으로 보내므로(D16) 작업 본체(조각 ⑤-b) 없이 api-19(③-b1) · ia-11(③-b2)이 초록이 된다. Celery 앱은 콜백 안에서 가져온다 — 모듈 머리에서 가져오면 생성물 기본 시험의 migrate 프로필 단언 둘이 깨진다(D3 (나) · 〔W22〕).
  - VD-T073-4(③-a의 api-4에서 시작해 ③-b1의 api-10 · 18과 ③-b2의 api-50으로 닫는다) · 14(③-a) · 6 · 7(③-b1) · 12(③-b2 — 통과 기준인 ia-27이 여기다).
- **④ 외부 HTTP 클라이언트**
  - 범위: D20의 `outbound.py` · `authentik.py`.
  - 차례: ia-22 · 41 작성 → 빨강 확인 → 구현 → 초록 → 변이 줄(D20).
  - 기대 초록: ia-22 · ia-41(〔W28〕 — `authentik.py`의 메서드 여덟을 이 조각에서 검증한다).
- **⑤ Celery**(둘로 가른다 — 〔W24〕)
  - **⑤-a 재적용 · purge · beat 배선 · `beat_init`**
    - 범위: D14 · D15. 산출: `denylist_writer.py`(`reapply` · `purge_log`) · `jobs.py`(작업 `reconcile_denylist` · `purge_session_revocation_log`의 본체 · `beat_init` 수신자 · 아래 등록 자리 둘) · 손 수정 ④ ⑤ ⑧.
    - `jobs.py`는 여기서 D15의 작업을 모두 **등록**한다 — api-33이 beat 항목의 네 작업 이름이 `app.tasks`에 있음을 보기 때문이다(test_api.py:1846). ⑤-b 몫인 `revoke_authentik_sessions` · `reconcile_authentik_sessions`는 이 반쪽에서 이름과 옵션(D16)만 등록하고 본체는 `NotImplementedError`를 올리는 자리 표시로 둔다(조용한 no-op을 두지 않는다 — ⑤-b의 첫 단계에서 쓴 ia-12 · 13이 이것으로 빨강이 된다).
    - 위임 · 대조 작업의 자리 표시 본체(`NotImplementedError`)가 있는 동안 ia-40은 「작업 실패 0」을 단언하지 않는다(자리 표시는 ⑤-b에서 없어진다 · 〔Z21〕 — 실제 워커가 그 작업을 받으면 실패 줄이 남는다).
    - 기대 초록: api-26 · 30–34(api-26은 웹훅 뒤 `reconcile_denylist`로 키를 되살리는 시험이라 이 반쪽이다 — 원문 확인. api-35는 순정 트리부터 초록이다 — beat 항목 셋을 더한 뒤에도 그대로여야 한다) · ia-9 · 10 · 32 · 33 · 38 · 40.
    - VD-T073-5 · 13 · 15.
  - **⑤-b 위임 본체 · 대조**
    - 범위: D16의 작업 본체 · D17. 산출: `jobs.py`(`revoke_authentik_sessions` · `reconcile_authentik_sessions`의 본체).
    - 기대 초록: ia-12 · 13(T066에서 새로 초록이 되는 것은 없다).
- **⑥ deploy · env.example · README · CI**
  - 범위: D23 · D27. 산출: 손 수정 ⑫–⑮ · `.github/workflows/ci.yml` · `tests/scripts/kubeconform-deploy.tests.ps1`.
  - 차례: ia-18 작성 → 빨강 확인 → 구현 → 초록 → 변이 줄(D23).
  - 기대 초록: ia-18 · ps1 하네스(아래 명령).
  - 검증 명령(〔W32〕 — `tests/run-all.ps1` 전체는 돌리지 않는다)
    - `pwsh -NoProfile -File tests/scripts/kubeconform-deploy.tests.ps1`(T073이 고치는 유일한 ps1 하네스 — static-14 · 18)
    - `pwsh -NoProfile -File tests/scripts/ci-gitleaks.tests.ps1` · `pwsh -NoProfile -File tests/scripts/events-compat.tests.ps1`(고치지 않는다 — `ci.yml`을 읽는 하네스라 job을 더한 뒤 한 번씩 돌려 초록을 본다 · D27)
    - kubeconform은 CI(ci.yml:501-509)처럼 렌더 전용 생성물 세 벌을 저장소 밖 임시 디렉터리에 만들어 `--generated`로 넘긴다(〔Y11〕). `--generated` 없이 돌면 경보선에 걸려 exit 1이다(scripts/ci/kubeconform-deploy.sh 머리 주석).
      ```
      uv run --directory templates/django-pod --locked python -m copier copy --defaults --skip-tasks --quiet --data pod_name=sample-pod "<저장소 루트 절대 경로>/templates/django-pod" "<tmp>/gen/default/apps/sample-pod"
      (같은 꼴로 `--data has_celery=false` → `<tmp>/gen/no-celery/…` · `--data has_celery=false --data has_admin=false` → `<tmp>/gen/no-admin/…`)
      bash scripts/ci/kubeconform-deploy.sh --generated "<tmp>/gen/default/apps/sample-pod" --generated "<tmp>/gen/no-celery/apps/sample-pod" --generated "<tmp>/gen/no-admin/apps/sample-pod"
      ```
      판정 = exit 0이고 출력에 `[PASS] apps/identity-admin/deploy/base` 줄이 있다.
  - VD-T073-8. arm64 이미지 탐침과 로컬 전체 시간(VD-T073-9 · 10)은 이 조각에서 재지 않는다 — 조각 ⑦ 닫기로 옮겼다(〔Z14〕 — 탐침이 가져올 모듈 목록에 조각 ⑦ 산출 `openfga` · `seed_tenant`가 들고, 전체 시간도 ⑦의 시험이 든 뒤라야 CI job 예산과 견줄 값이 된다).
- **⑥ 끝 뒤 — 컨트롤러 단계: 3-way 재생성 리허설**(VD-T073-11 · 〔W23〕)
  - 손 수정 15파일이 다 생긴 뒤라야 통과 기준(충돌이 손 수정 표식 블록에만 난다)이 뜻을 갖는다. ⑫–⑮가 조각 ⑥에서 생기므로 그 끝 뒤다(조각 ⑦은 pod 소유 새 파일만 더한다).
  - 누가 · 어디서: 전용 하위 에이전트가 **저장소 밖 임시 복제본**에서 돈다. 복제본 안에서는 커밋이 허용되고, 이 저장소의 ref와 작업 트리는 건드리지 않는다(변경 0).
  - 절차: 생성 커밋을 체크아웃 → 그 위에 손 수정 트리(조각 ⑥ 끝의 `apps/identity-admin`)를 얹어 커밋 → 생성 커밋에서 갈라 템플릿 변경 + 같은 `recopy`(D3의 명령) 커밋 → 그것을 손 수정 커밋에 cherry-pick.
  - 바꾸는 템플릿 줄은 둘이다(〔Z18〕): ① 손 수정 블록 바로 옆 줄(예: `conf.py.jinja`의 목록 상수) ② 손 수정이 없는 파일의 줄. ①은 충돌이 그 블록에만 나야 하고 ②는 충돌이 0이어야 한다 — 손 수정이 없는 줄 하나만 바꾸면 충돌 0으로 통과 기준이 공허하게 참이 된다(재검토 RB-14).
  - 통과 기준과 실패 시 갈 곳은 §6 VD-T073-11 그대로다. 통과한 뒤에만 bn 「T073」 절과 생성 README 「재생성」 절에 정본으로 올린다(D3).
- **⑦ OpenFGA 클라이언트 · seed_tenant(마지막)**
  - 범위: D19 · D20의 `openfga.py`. 산출: `openfga.py` · `management/commands/seed_tenant.py`.
  - 차례: ia-14 · 15 · 16 작성 → 빨강 확인 → 구현 → 초록 → 변이 줄(D18의 seed 갈래 · D19).
  - 기대 초록: api-36–41 · 56 · ia-14–16.
  - **끝 조건(전체 닫기)**
    - `uv run --directory apps/identity-admin --locked pytest -q` 한 번이 종료 0이다. 그 안에서 T066 76개가 실제로 돌아 전부 초록이고(「T066 변화 0」은 원문 대조 결론이었다 — 실측으로 닫는다) 가짜 자기검사 26 · 생성물 기본 시험 전부(삭제 · skip 0) · ia 전체 · `test_ia_fakes.py`가 초록이다.
    - `uv run --directory templates/django-pod --locked pytest -q`(하네스 전체) 초록.
    - VD-T073-10(〔Z14〕): 위 pod 전체 실행의 로컬 벽시계 시간을 기록한다(조각 ⑦의 시험까지 든 값이라야 CI job 30분 예산과 견줄 수 있다 — §6).
    - VD-T073-9(〔Z14〕): arm64 이미지를 빌드하고 D1의 새 모듈 전부(조각 ⑦ 산출 `openfga` · `seed_tenant` 포함)를 가져오는 탐침을 돈다(§6 절차 · 앞에 binfmt 등록).
    - 조각 ⑥의 ps1 하네스 셋을 한 번 더 돌려 초록 · 바꾼 파일 gitleaks exit 0. `tests/run-all.ps1` 전체는 여기서도 돌리지 않는다(〔W32〕).
    - §4의 〈설계 커밋〉 항목이 실제 문서와 맞는지 한 번 대조한다(구현 중 계약과 어긋난 것은 bn에 적고 컨트롤러가 계약 보정을 정한다).
  - push(VD-T073-CI)는 사용자 확인 뒤에 한다.

**배정의 합계**(〔W24 · Z20〕 — 조각을 다시 짠 뒤 빠짐 · 겹침 없이 한 번씩 배정되는지 세었다. 재검토 반영에서 ③-b를 ③-b1 · ③-b2로 가르고 ia-25를 ③-a로 옮긴 뒤 다시 세었다 — 〔Z7 · Z20〕)

| 조각 | T066 새로 초록(노드 수) | ia(묶음 수) |
|---|---|---|
| ⓪ 순정 생성 | (순정 초록 13 — api-1 · 2 · 3 · 52 · 5 · 35 · 42 · 43 · 46 · 47의 둘 · 49의 하나 · 54) | — |
| ① 토대 | 0 | 0(`test_ia_fakes.py`만) |
| ② | 12 — api-47의 넷 · 48 · 49의 넷 · 55의 셋 | 3 — ia-20 · 23 · 24 |
| ③-a | 11 — api-4 · 6 · 7 · 8 · 9 · 27 · 28 · 29(주 — 표 아래) · 44 · 45 · 53 | 8 — ia-1 · 2 · 21 · 25 · 29 · 30 · 36 · 37 |
| ③-b1 | 14 — api-10–15(6) · 16(4) · 17–19(3) · 51 | 2 — ia-4 · 28 |
| ③-b2 | 11 — api-20(2) · 21 · 22(4) · 23–25(3) · 50 | 14 — ia-3 · 5 · 6 · 7 · 8 · 11 · 17 · 19 · 26 · 27 · 31 · 34 · 35 · 39 |
| ④ | 0 | 2 — ia-22 · 41 |
| ⑤-a | 6 — api-26 · 30–34 | 6 — ia-9 · 10 · 32 · 33 · 38 · 40 |
| ⑤-b | 0 | 2 — ia-12 · 13 |
| ⑥ | 0 | 1 — ia-18 |
| ⑦ | 9 — api-36–39(4) · 40(2) · 41 · 56(2) | 3 — ia-14 · 15 · 16 |
| 합계 | 빨강 63 = 12 + 11 + 14 + 11 + 6 + 9 · 순정 초록 13 → 76 | 41 = 3 + 8 + 2 + 14 + 2 + 6 + 2 + 1 + 3(ia-1–41 · ia-39의 a · b · c는 셋 다 ③-b2) |

- api-29의 주(〔Z7〕): 조각 ② 끝에서 먼저 초록이 될 수 있다 — 모델만 있으면 `/tenants/me`가 없어도 handler404가 같은 404 `not_found`를 낸다(원문 판독 — test_api.py:1736-1747의 단언은 404 둘과 응답에 다른 테넌트 값이 없음뿐이다). 그 경우 ②의 초록으로 세고(② 13 · ③-a 10) 보고에 적는다. `/tenants/me`의 판별은 api-27 · 28이다.
- ③-b의 가름(〔Z20〕): ia 시험은 「그 시험이 지나는 경로가 다 있는 첫 조각」에 둔다 — 웹훅이나 관리 명령을 지나는 ia는 ③-b2이고(revoke와 웹훅을 다 보는 ia-5 · 11 · 17 · 19 · 27 · 39 포함), revoke만 지나는 ia-4 · 28이 ③-b1이다. T066은 api-10–19 · 51(revoke 14노드)이 ③-b1, api-20–25 · 50(웹훅과 OpenAPI 네 경로 11노드)이 ③-b2다 — 14 + 11 = 가르기 전의 25.
- T066 76 = 함수 56 + 매개화로 는 20이다. 매개화 함수 여덟의 노드 수는 api-16 4 · api-20 2 · api-22 4 · api-40 2 · api-56 2 · api-47 6 · api-49 5 · api-55 3(합 28 = 함수 8 + 20 — test_api.py 원문에서 다시 세었다). 기동 17(api-46 · 47의 여섯 · 48 · 49의 다섯 · 54 · 55의 셋) 가운데 순정 초록이 다섯, 조각 ②에서 새로 초록이 되는 것이 열둘이다.

조각마다 리뷰 2렌즈(A 계약 · 완전성 / B 실패 양상 · 위생)를 돈다. 렌즈 A는 「그 조각의 ia 시험이 설계의 시험 줄 · 변이 줄과 맞는가 · 빨강 증거(노드별 사유 표)가 있는가」도 본다(〔W24〕). 학습 로그는 `content/tmp/003-t073/<날짜>.md`에 남긴다.

---

## 6. VD 목록

### T073 안에서 실측

항목마다 기본 가정 · 통과 기준 · 실패 시 갈 곳을 적는다(〔Y15〕). 결과는 bn 「T073」 절에 남긴다.

| VD | 조각 | 기본 가정 | 통과 기준 | 실패 시 갈 곳 |
|---|---|---|---|---|
| **VD-T073-1** 생성 꼴 | ⓪ | D2의 명령이 rc 0이고 충돌은 스텁 pyproject 하나다(〔P1 · P6〕) | `git status` = `M IA/pyproject.toml` + 새 파일 · T066 세 파일 무변화 · answers `_src_path`가 상대 경로이고 `description` · `owns_events`가 D2의 값 · pod `uv.lock`의 패키지 · 판 집합이 조각 ⓪에서 방금 돈 하네스의 sample-pod `uv.lock`과 같다(프로젝트 이름만 다르다 — 수를 박지 않는다: 숙성 창과 범위 의존 때문에 전이 의존 하나로 수가 바뀐다 · 〔W31〕) · `exclude-newer-span = "P3D"` | D2 5단계로 되돌린 뒤 원인을 가른다 — PyPI · 숙성 창이면 다시, 그 밖이면 멈추고 컨트롤러에 보고 |
| **VD-T073-2** 루트 잠금 | ⓪ | diff는 identity-admin 2곳 + revision 3→5뿐이다(〔P4〕) | `uv lock --check` · `uv sync --locked` 종료 0 · diff가 그 범위 | diff가 넓으면 멈춘다(다른 의존이 움직였다 — uv 판 · 숙성 창을 본다) |
| **VD-T073-3** `UUID7()` db_default | ② | Django 6.1 + PG 18.6에서 마이그레이션이 안정이고 pk가 RETURNING으로 채워진다 | `makemigrations --check` 0 · lintmigrations Erroneous 0 · ORM `objects.create()` 뒤 pk가 채워진다(조각 ② 탐침 — api-10은 revoke 조각 ③-b1에서 확인한다 · 〔Z14〕) · `uuid_extract_version(id)` = 7 | 앱 쪽 v7 생성기(`default=` 호출형) → 그것도 안 되면 uuid4 + 편차(dm과 어긋남 — 컨트롤러 결정 · D4) |
| **VD-T073-4** Ninja 1.7.0 | ③-a · ③-b1 · ③-b2 | `Status` 반환에 경고 0 · `exclude_none` · StrictBool이 OpenAPI boolean · 본문 없는 operation · `expires_at`이 ISO 8601 UTC | api-4 · 10 · 18 · 50 초록 · 스냅샷 diff가 새 경로와 스키마뿐 | 뷰가 dict를 손으로 만들어 돌려준다(스키마 직렬화에 기대지 않는다) |
| **VD-T073-5** 실제 worker + beat | ⑤-a | `beat_init` 수신자가 beat 프로세스에서 돌아 키를 만든다 — Windows 두 프로세스와 POSIX 내장 beat(fork된 자식) 모두 | ia-40 초록(로컬 Windows) + 첫 CI에서 초록(내장 토폴로지) · NOPERM 0(VD-T066-3 로컬 몫 가운데 브로커 · 쓰기) | 수신자 머리에서 물려받은 DB 연결을 닫는다(`connections.close_all()`) → 그래도 실패면 멈추고 보고(신호를 바꾸는 것은 계약 보정이다) |
| **VD-T073-6** 위임 enqueue 시간(〔W25 · Z15〕 — 사례와 절차는 표 아래) | ③-b1 | `retry_policy` `max_retries` 0이면 닫힌 포트 브로커에서 약 2 s 안에 실패한다(〔T27〕). 연결은 되고 응답이 없는 브로커에서는 `socket_timeout` 5 s까지 걸린다(사실 ⑧ — 합격선 밖) | 사례 ①(브로커가 닫힌 포트): 「revoke 요청이 202까지 3 s 미만」 — 합격선은 이것 하나다. 사례 ② · ③ · ④ · ⑤는 기록 항목이다(표 아래) | ①이 3 s를 넘으면 호출 단위 연결 옵션으로 재접속을 0회로 줄인다 → 그래도 넘으면 enqueue를 요청 스레드 밖으로 떼는 안을 결정 후보로 올린다. ④의 값(`max_retries` 0 대 1)은 컨트롤러가 정한다 |
| **VD-T073-7** 파이프라인 결과 꼴 | ③-b1 | `execute(raise_on_error=False)`가 명령 단위 오류(NOPERM · `EX 0`)를 결과 목록의 예외 객체로 주고 연결 오류는 던진다(Dragonfly v1.40.1) | 탐침 시험에서 그 꼴 그대로 | 명령마다 따로 보낸다(왕복이 늘 뿐 값은 같다) |
| **VD-T073-8** gitops validate 거울(명령은 표 아래 — 〔W31〕) | ⑥ | identity-admin base가 ESO CRD 파생 스키마를 통과한다(VD-T072-19 꼴) | 임시 복제본에서 검사 통과 | ES · ConfigMap을 고치고 ia-18에 그 사례를 더한다 |
| **VD-T073-9** arm64 이미지(명령은 표 아래 — 〔W31〕) | ⑦ 닫기(〔Z14〕) | 새 모듈이 이미지 허용 목록에 들어 import된다(탐침의 모듈 목록이 조각 ⑦ 산출을 포함한다) | arm64 빌드 성공 · `--network none`에서 새 모듈 import 탐침 0 오류 | dockerignore 허용 목록과 파일 위치를 본다(런타임 코드는 `identity_admin/` 안) |
| **VD-T073-10** 로컬 전체 시간 | ⑦ 닫기(〔Z14〕) | pod 전체가 CI job 30분 예산 안이다 | 로컬 벽시계 시간을 기록(템플릿 165개가 171–364 s였다 — 〔P27〕) | job `timeout-minutes`와 static-18 상한을 실측에 맞춰 올린다 |
| **VD-T073-11** 재생성 3-way(〔W23 · Z18〕 — 절차는 표 아래) | ⑥ 끝 뒤(컨트롤러 단계) | 저장소 밖 임시 복제본에서 생성 커밋 위에 손 수정 커밋을 얹고, 생성 커밋에서 갈라 만든 「템플릿 변경(줄 둘) + 같은 `recopy`」 커밋을 거기에 cherry-pick하면 손 수정을 지킨 채 템플릿 변경만 얹힌다 | 바꾸는 템플릿 줄은 둘이다(〔Z18〕) — 손 수정 블록 바로 옆 줄(예: `conf.py.jinja`의 목록 상수)은 충돌이 그 블록에만 나고, 손 수정이 없는 파일의 줄은 충돌이 0이다(손 수정 15파일이 다 든 트리에서) | 정본은 `recopy` + diff 그대로 둔다(3-way는 올리지 않는다 — 〔Y6〕) |
| **VD-T073-12** 긴 TTL 키 | ③-b2 | Dragonfly v1.40.1이 `EX` 2,592,330 SET을 받고 `TTL`이 그 값을 돌려준다 | ia-27 초록 | TTL 표현을 `EXAT`(절대 시각)로 바꿔 본다 → 안 되면 멈추고 보고 |
| **VD-T073-13** 둘째 SQL의 계획과 시간(명령은 표 아래 — 〔W31〕) | ⑤-a | `srl_user_floor_idx`를 타고 SP-1 규모에서 수 ms다 | 사용자 단위 행 10^3 · 10^5에서 `EXPLAIN (ANALYZE)` 기록 — 10^3에서 50 ms 미만 | 인덱스 꼴을 고친다 · 10^5 수치는 증분 재적용 전환 기준의 근거로 남긴다(D14) |
| **VD-T073-14** `/session/check` 지연 | ③-a | Dragonfly 2왕복이 로컬에서 수 ms이고, 첫 조회 실패는 0.2 s대에 503이다 | api-8 초록(0.5 s 미만) · ia-30 초록 · 정상 경로 p95 기록 | 하한 조회를 `Denylist` 조회와 한 파이프라인으로 합치는 안을 결정 후보로 올린다(계약 문장 보정이 따른다 — D8 기각 1) |
| **VD-T073-15** 유실 뒤 복구(〔W25 · Z16〕 — 둘로 가른다 · 절차는 표 아래) | ⑤-a | (a) 데이터 유실(연결 유지 — `FLUSHALL`): 다음 tick이 키(`revoked:*` · 하한 · 신선도)를 되살린다 (b) 프로세스 재기동(연결 끊김 — `docker kill` → `docker start`): tick 30 s에 워커 재접속(최대 30 s)이 더해질 수 있다(소스 판독 — B-3) | (a) ia-40의 단언 — `FLUSHALL` 뒤 60 s 안에 세 키가 돌아온다(그 앞의 tick 단언은 이 VD와 무관하게 뺄 수 없는 단언이다 — D26 · 〔Z16〕) (b) 합격선을 두지 않는다 — 신선도 키와 세션 하한 키로 5회 재서 최댓값을 **참고값**으로 기록한다(〔Z16〕 · 로컬 Windows는 두 프로세스 토폴로지다 · 운영 토폴로지 값은 T085의 SIGKILL 측정) | (a) `FLUSHALL` 뒤 복귀 단언이 실패하면 그 단언만 빼고 한계를 bn에 적은 뒤 컨트롤러에 보고한다(결정 후보: 재적용 루프를 beat 프로세스 안 타이머로 — 브로커 비경유 · 〔Y16〕). tick 단언은 빼지 않는다(〔Z16〕) (b) worker · beat가 되살아나지 않으면 그 사실을 보고한다(T075 liveness 결정의 근거). 계약 문구는 구조상 상한(다음 tick 30 s + 워커가 먼저 받은 작업들의 마감 + 워커 재접속)으로 적었다(〔W18 · Z1〕) |
| **VD-T073-16** pod 사용자의 `+@all` 범위(〔W33 · Z18〕 — 절차는 표 아래) | ② | `+@all`은 키 패턴이 걸리지 않는 명령(`FLUSHALL` · `ACL SETUSER` · `CONFIG SET`)도 pod 사용자에게 연다(Redis ACL 의미 기준 추론) | 합격선을 두지 않는다 — 세 명령의 가부(허용인지 NOPERM인지)를 재서 bn과 §7 T075 인계에 적는다 | 허용으로 나와도 규칙은 T073에서 바꾸지 않는다 — T075 · T097에 넘긴다(ACL에서 위험 명령을 빼는 것은 dl 계약 보정이다) |
| **VD-T073-CI** 첫 CI | push 뒤 | 새 job이 30분 안에 초록이다 | job `identity-admin` success · ia-40이 내장 beat 토폴로지로 초록 · static-14 · 18 초록 | 시간 초과면 VD-T073-10의 길, ia-40 실패면 VD-T073-5의 길 |

**절차와 실행 명령**(표의 칸에 다 싣지 못한 것 — 〔W23 · W25 · W31 · W33 · Z15 · Z16 · Z18〕. 「예상 꼴」이라고 적은 명령은 실행으로 확인한 적이 없다 — 그 조각이 실제로 돈 꼴을 보고에 남긴다)

- **VD-T073-6**(조각 ③-b1): 재는 값은 「전체 로그아웃 revoke 요청(쓰기 켬 · 자격이 자리값 아님)을 보낸 때부터 202까지」다(사례 ① · ② · ③ — ④ · ⑤는 아래에 따로 적은 값을 잰다). 거부 목록 Dragonfly는 정상으로 두고 Celery 브로커만 바꾼다.
  - 브로커를 바꿔 재는 법(예상 꼴): `identity_admin.celery.configure_broker(<url>)`로 broker URL을 넣은 뒤 연결 풀을 비운다 — `kombu.pools.reset()`을 부르고 앱에 캐시된 풀 둘(`app._pool` · `app.amqp._producer_pool`)을 None으로 둔다(celery 5.6.3 `app/base.py`의 `_after_fork`가 하는 일 — 소스 판독). 재고 나면 같은 방법으로 원래 URL로 되돌린다.
  - ① 브로커가 닫힌 포트: **합격선 「202까지 3 s 미만」**.
  - ② SYN이 버려지는 불통(connect 2 s): 이 호스트에 재현 수단이 없으면 소스 판독으로 대신하고 그렇게 적는다(전송 옵션 `socket_connect_timeout` 2 s — 사실 ⑧).
  - ③ 연결은 되고 응답이 없는 브로커(T066 `tests/_identity_fakes.py`의 블랙홀 도우미 — accept하지 않는 리스너): 전송 옵션 `socket_timeout` 5 s라 합격선 밖이다 — 잰 값을 기록만 한다. 이 사례의 통과 근거는 운영 구성이다: 브로커가 거부 목록과 같은 Dragonfly라 커밋 뒤 SET이 먼저 `unreachable`(0.2 s)이 되어 D12 ④가 enqueue를 건너뛴다(계약 C9에 이 전제를 달았다).
  - ④ 브로커 재기동 뒤 첫 enqueue: `retry_policy` `max_retries` 0과 1을 둘 다 재서 보고한다(0이면 풀에 남은 죽은 연결에서 첫 enqueue가 재접속 없이 실패할 수 있다 — kombu `Connection.ensure` · 사실 ⑧). **값의 결정은 컨트롤러가 한다** — 기본은 0 유지이고, 빌더는 ia-11과 계약 C9를 바꾸지 않는다. 0을 지키면 「브로커 재기동 뒤 첫 위임 1건 누락 가능」이 남는다(§9).
    - 절차(〔Z15〕 — 앞 라운드에는 절차가 없었다 · 재검토 RB-11): 따로 띄운 수동 Dragonfly로 잰다 — `docker run --rm -d -p 127.0.0.1:<빈 포트>:6379 <conftest와 같은 digest>`.
    - 차례: 브로커를 그 URL로 바꿈(위 「브로커를 바꿔 재는 법」) → `send_task` 1회 성공(풀에 산 연결이 남아야 재기동 뒤 「죽은 연결」 사례가 된다 — 풀을 비운 직후에 재면 그 사례가 아니다) → `docker kill`(`--rm`이라 컨테이너가 지워진다) → 같은 포트로 다시 `docker run` → `send_task` 1회의 성패와 시간을 `max_retries` 0 · 1로 잰다. 값마다 이 차례(성공 1회 → kill → 재기동 → 1회)를 따로 돈다 — 재기동 뒤 첫 `send_task`가 죽은 연결을 써 버리므로 한 번의 재기동으로 두 값을 잴 수 없다(마감 확인 제안).
    - 뷰가 아니라 `send_task`를 직접 부른다(뷰의 값은 ia-11과 계약 C9가 0으로 고정한다 — 1은 직접 불러야 잴 수 있다).
    - 세션 픽스처 Dragonfly는 건드리지 않는다(다시 띄우면 `ACL SETUSER`로 만든 사용자가 사라져 그 세션의 남은 시험이 깨진다 — VD-T073-15 (b)와 같은 까닭).
    - 재현하지 못하면 ②처럼 소스 판독으로 대신하고 그렇게 적는다.
  - ⑤ 기록 사례(〔Z15〕): 거부 목록과 브로커가 같은 Dragonfly일 때(운영 구성) 재기동 뒤 첫 사용자 단위 폐기의 `denylist` · `delegate` 값을 기록한다. 예상 꼴: ④의 수동 Dragonfly를 `DRAGONFLY_URL`과 브로커 둘 다로 두고, 폐기 1회 성공 → 재기동 → `record_revocation`(사용자 단위 · `delegate=True`)을 직접 불러 `Recorded.after`의 두 칸을 읽는다(관리 명령은 ③-b2에서 생긴다). 쓰기 클라이언트의 죽은 소켓에서 SET이 `unreachable`이 되면 D12 ④가 enqueue를 건너뛴다 — 그 1건은 `max_retries`와 무관하게 빠진다(§9).
- **VD-T073-8**(조각 ⑥ — t072의 VD-T072-19 절차 그대로다: t072:1152 · 1181 · 결과는 bn:4464): `git clone --no-hardlinks <platform-gitops 로컬 저장소> <저장소 밖 임시 경로>` → `apps/identity-admin/deploy/base`의 파일을 그 복제본의 `apps/identity-admin/base`에 덮어 복사한다(그 자리에는 자리 표시 `kustomization.yaml`이 있다) → Git Bash에서 `.superpowers/bin`을 PATH 앞에 두고 `bash tests/validate.sh --root <복제본>` → 검사 1 · 3(3.0–3.7) · 3.5 · 4a · 11 · 13의 PASS · FAIL 줄을 기록한다. base만 넣어서 생기는 FAIL(overlay · Application 쪽)은 원인을 한 줄씩 적는다. 끝에 복제본을 지운다(원본 저장소 쓰기 0 · 커밋 · push 없음). T072에서는 한 번에 약 11분 걸렸다.
- **VD-T073-9**(조각 ⑦ 닫기 · 예상 꼴 · 〔Z14〕 — 아래 모듈 목록에 조각 ⑦ 산출 `openfga`와 관리 명령 `seed_tenant`가 들어 있어 그 조각 뒤라야 돈다): 앞에 binfmt를 등록한다(§5). 빌드는 저장소 루트에서 `docker buildx build --platform linux/arm64 --load -f apps/identity-admin/Dockerfile -t jt-identity-admin:t073 .`(컨텍스트 = 저장소 루트 — 규칙 django-pod.md)다. 탐침은 그 이미지를 `docker run --rm --network none`으로 띄워 `python -c`로 `django.setup()` 뒤 D1의 새 모듈(`identity_admin.models` · `identity_api` · `revocation` · `denylist_writer` · `session_floor` · `outbound` · `authentik` · `openfga` · `identity_metrics` · `jobs`와 관리 명령 둘)을 가져온다.
  - 탐침에 줄 env는 허용 목록뿐이다 — 하네스 `smoke_env()`(H/tests/conftest.py:481-523)의 이름 집합에 identity-admin 필수 넷(`AUTHENTIK_API_TOKEN` · `AUTHENTIK_WEBHOOK_SECRET` · `OPENFGA_STORE_ID` · `OPENFGA_PRESHARED_KEY`)을 더하고, 값은 심은 가짜(새 난수 · 닫힌 127.0.0.1 포트)로 둔다. 셸 env 전체를 물려주지 않는다(누출 탐침 위생 — bn:4440).
  - 끝나면 그 이미지를 지운다.
- **VD-T073-11**(컨트롤러 단계): 절차는 §5 「⑥ 끝 뒤 — 컨트롤러 단계」다(저장소 밖 임시 복제본 · 전용 하위 에이전트). 바꾸는 템플릿 줄은 둘이다 — 손 수정 블록 바로 옆 줄(예: `conf.py.jinja`의 목록 상수)과 손 수정이 없는 파일의 줄. 앞의 것은 충돌이 그 블록에만, 뒤의 것은 충돌 0이어야 한다(〔Z18〕).
- **VD-T073-13**(조각 ⑤-a · 예상 꼴): 시험 DB에 owner 연결로 사용자 단위 행을 채우고 D14의 둘째 SQL을 `EXPLAIN (ANALYZE)`로 돈다. `id` · `created_at`은 DB 기본값이 채운다(D4). 30일 자리는 이 탐침에서만 리터럴로 둔다(코드에서는 매개변수다 — D29). 끝나면 채운 행을 지운다(`DELETE FROM session_revocation_log WHERE sub LIKE 'vd13-%'`).
  ```sql
  -- 행 채우기(10^3 — 10^5 측정은 generate_series(1, 100000))
  INSERT INTO session_revocation_log (tenant_id, sub, sid, reason, nbf, expires_at)
  SELECT gen_random_uuid(), 'vd13-' || (g % 1000), NULL, 'logout_all',
         now() - make_interval(secs => g), now() - make_interval(secs => g) + interval '330 seconds'
  FROM generate_series(1, 1000) AS g;

  EXPLAIN (ANALYZE, BUFFERS)
  SELECT DISTINCT ON (sub) sub, extract(epoch FROM nbf)::bigint,
         floor(extract(epoch FROM expires_at + interval '30 days' - statement_timestamp()))::bigint
  FROM session_revocation_log
  WHERE sid IS NULL AND expires_at > statement_timestamp() - interval '30 days'
  ORDER BY sub, nbf DESC, expires_at DESC;
  ```
- **VD-T073-15**(조각 ⑤-a)
  - (a) 데이터 유실(연결 유지): ia-40의 단언이다(D26). 키가 생긴 뒤 admin `FLUSHALL` → 60 s 안에 `revoked:sub` · 세션 하한 · 신선도 키가 돌아온다(tick 30 s + 여유). `FLUSHALL`은 Celery 브로커 키도 지우므로 재적용 경로가 브로커에 남은 상태에 기대지 않는지도 함께 본다.
    - 이 복귀 단언이 실패했을 때 뺄 수 있는 것은 이 단언뿐이다(〔Z16〕). ia-40에는 `FLUSHALL` 앞의 tick 단언(기동 뒤 60 s 안에 신선도 키의 값이 `beat_init` 때보다 커진다 — 또는 `reconcile_denylist` 성공 줄 1회 이상)이 따로 있고, 그것은 빼지 않는다 — 30 s tick이 beat → 브로커 → 워커로 실제로 도는 것을 보는 유일한 시험이다(D26).
  - (b) 프로세스 재기동(연결 끊김): 생성물 `compose.dev.yml`의 Dragonfly(고정 포트 · aclfile이라 재기동 뒤에도 사용자가 남는다)와 PG로 생성 README 「로컬 실행」 절차대로 worker + beat를 띄운다. 사용자 단위 행을 둔 채 Dragonfly 컨테이너를 `docker kill` → `docker start`한 뒤 admin으로 0.5 s 간격으로 키를 조회한다 — 5회 재서 최댓값을 기록한다.
    - 재는 키는 신선도 키와 세션 하한 키다(〔Z16〕) — 둘은 5회 내내 유효하다(하한은 30일 · 신선도 키는 tick마다 다시 쓰인다). `revoked:sub`는 행이 활성인 330 s 동안만 되살아나므로, 한 행으로 5회를 재면 뒤 회차는 그 키가 돌아오지 않아 「worker · beat가 되살아나지 않는다」로 잘못 읽힌다 — `revoked:sub`를 보려면 회차마다 행을 새로 넣는다.
    - env(마감 확인 RC-2): 「로컬 실행」 4단계의 값에 identity-admin 필수 넷(`AUTHENTIK_API_TOKEN` · `AUTHENTIK_WEBHOOK_SECRET`(32자 이상) · `OPENFGA_STORE_ID` · `OPENFGA_PRESHARED_KEY`)을 심은 가짜 값으로 더한다(VD-T073-9 탐침과 같은 넷). `env.example` · README의 그 키는 조각 ⑥에서 생긴다 — 없으면 worker · beat가 기동에서 설정 이름만 실은 `ImproperlyConfigured`로 멈춘다. 사용자 단위 행은 `manage.py shell`로 넣는다(`revoke_sessions`는 멤버십 행이 있어야 하고 `seed_tenant`는 조각 ⑦이다).
    - 시험 Dragonfly(testcontainers)는 쓰지 않는다 — 임시 포트에 기동 뒤 `ACL SETUSER`로 사용자를 만들므로 재기동하면 사용자가 사라진다(검토 C-4).
    - 호스트 포트는 셸 env(`JT_DEV_POSTGRES_PORT` · `JT_DEV_DRAGONFLY_PORT` · `JT_DEV_KAFKA_PORT`)로 비켜 둔다. 관계없는 컨테이너는 건드리지 않는다. 끝나면 `docker compose -f compose.dev.yml down -v`로 지우고 dangling 볼륨 수가 전과 같음을 확인한다.
    - 로컬 Windows 값(두 프로세스 토폴로지)은 참고값이다 — 합격선을 두지 않는다. worker · beat가 되살아나지 않으면 그 사실을 보고한다.
- **VD-T073-16**(조각 ②): 시험 Dragonfly(운영과 같은 digest · conftest가 만든 pod 사용자 — 규칙 `+@all`)에 pod 사용자로 붙어 `FLUSHALL` · `ACL SETUSER <임시 사용자> …` · `CONFIG SET`을 하나씩 보내 허용인지 NOPERM인지 본다.
  - `CONFIG SET`의 항목(〔Z18〕): admin으로 `CONFIG GET maxmemory`를 읽고 pod 사용자로 같은 값을 `CONFIG SET` 한다 — 허용이어도 바뀌는 것이 없다(항목을 빌더가 고르지 않는다 — 비밀번호 계열 항목이 바뀌면 그 세션의 admin 접속이 깨질 수 있다).
  - 도는 자리(〔Z18〕): 커밋하지 않는 임시 시험 파일로 돌리고 지운다(conftest `dragonfly` 픽스처로 그 세션의 Dragonfly에 붙는다 — 그 컨테이너는 pytest 세션 동안만 있다).
  - 시험 컨테이너 안에서만 한다. 만든 사용자는 admin으로 지운다(`ACL DELUSER`) — 같은 세션의 다른 시험이 그 Dragonfly를 쓴다.

### 라이브로 넘김

Authentik 동작에 대한 이 설계의 근거는 전부 소스 판독이다(〔V1–V17〕 — 라이브 실측 0). 아래에서 처음 잰다.

| VD | 과제 | 기본 가정 | 통과 기준 | 실패 시 갈 곳 |
|---|---|---|---|---|
| **VD-T080-1** 포트 | T080 | `servicePortHttp: 9000`으로 Service가 9000을 연다 | jt-dev pod에서 `:9000/api/v3/` 도달 | 계약 URL의 포트를 80으로 고친다(api-48 · 계약 보정) |
| **VD-T081-1** 웹훅 매핑 | T081 | 매핑 둘이 HMAC을 통과하고(VD-T062-1) 본문에 `nbf` = ⌊created⌋ + 1이 실리며 pk가 events API의 pk와 같은 꼴이다 | pod 로그에 `webhook.nbf_missing` 0건 · `webhook.nbf_clamped` 0건(〔Z8〕) · 같은 로그아웃의 웹훅 행과 대조가 한 행 · 세션을 지웠을 때 이벤트가 생기지 않는지와 토큰 교환마다 login 이벤트가 생기는지를 기록한다(계약 C5 · C27 (라)의 실측 표시가 이 항목을 가리킨다 — 〔W3〕) | 매핑을 고친다(pod는 정규형으로 hex 꼴을 흡수한다 — D12). 세션 삭제가 이벤트를 만들면 C5 · C27의 그 문장과 UD-4를 다시 본다 |
| **VD-T081-2** 권한 | T081 | 권한이 없는 조회의 응답 꼴은 계정의 형에 달려 있다 — 401 · 403이거나 오류 없는 빈 목록 · 404다(소스 판독 — 사실 ⑭ · 〔W2〕) | prod: 세션 목록 · DELETE · events가 된다. dev: 계약대로의 권한에서 사용자 조회가 된다. 기록할 것(〔W2 · W3〕): 서비스 계정의 형(type) · `view_event` 없는 events 조회의 응답 · `view_user` 없는 `GET /core/users/<pk>/`의 응답 · 비슈퍼유저 서비스 계정으로 남의 OIDC 토큰을 지우려 할 때의 응답(계약 C27 (가)의 실측 표시) | UD-2 결정과 권한 표(C27) · C7 (나)의 갈래 문장을 실측에 맞춘다 |
| **VD-T081-3** 토큰 꼴 | T081 | `sub_mode` user_uuid로 두 토큰의 `sub`가 같고 `groups` 클레임이 목록이며(VD-T066-1) **교환 토큰에는 `sid`가 없다** | 교환 토큰의 클레임 캡처 | `sid`가 실리면 A14 · C4 · C40의 한계 문장을 고치고 UD-7을 다시 본다(〔Y1〕) |
| **VD-T081-4** refresh · ID 토큰 | T081 | 회전 뒤 새 refresh 만료 = now + validity(절대 수명 없음) · callback ID 토큰 `iat` = 코드 교환 시각 · 세션 삭제 뒤에도 refresh 성공 · refresh 뒤 `auth_time` 불변 · scope에 `offline_access`가 있어야 refresh 토큰이 나온다 · RFC 7009 뒤 그 사슬의 refresh 실패 | 항목마다 요청 · 응답 캡처(계약 C4 · C39 · C43의 실측 표시가 이 항목을 가리킨다 — 〔W3〕 · 「서비스 계정은 남의 refresh 토큰을 지울 수 없다」의 확인은 VD-T081-2와 함께) | `iat`가 기대와 다르면 `issued_at`의 원천을 Workers 시계로 바꾼다(bff 계약 보정 — 시계가 하나 더 낀다) |
| **VD-T081-5** 시계 | T081 · T085 | Authentik · identity-admin pod · PG(pg-main)의 시계 차가 1 s 미만이다 | 세 곳의 시각을 같은 순간에 재서 차이 기록(합격선 1 s 미만 — PG는 `SELECT now()`) | 노드 시간 동기를 고친다. 그때까지 「Authentik이 앞선 만큼 폐기 직전 세션이 산다」를 §9대로 받아들인다(〔E10〕) |
| **VD-T082-1** OpenFGA | T082 | 배포된 판이 `on_duplicate`를 받고 model id를 생략할 수 있다(VD-T066-2). 없는 store는 쓰기 400 · 읽기 200이다(가짜는 404 — G14) | 시드가 두 번 돌아도 같은 상태 | 중복 400을 튜플별로 판정하는 꼴로 바꾼다(dm:25의 셋째 방식) |
| **VD-T083-1** 시드 · 위임 | T083 | users 응답의 `groups`가 그룹 pk 목록이다(D19의 소속 판정이 기댄다 — 〔Y12〕). 위임이 실제 세션을 지운다 | 시드(prod 쓰기 켬 · dev 끔 — dev 출력 `drift=0`) · 위임 `deleted` ≥ 1이고 세션 목록을 다시 조회하면 0(〔W30〕 — `gone`만 세어졌으면 삭제 권한이 빠진 404일 수 있다) | 소속 판정을 그룹의 `users` 목록으로 바꾼다 · `deleted`가 0이면 `delete_authenticatedsession` 권한을 본다 |
| **VD-T085-1** 폐기 E2E | T085 | 하한과 절대 수명이 BFF 경유로 집행된다 | §7 T085의 사례 전부 | 사례별로 계약 · 구현을 가른다(pod 쪽이면 converge 과제) |
| **VD-T092-1** Workers | T092 | RFC 7009 응답이 계약대로이고 같은 쿠키의 동시 refresh는 둘째가 `invalid_grant`다 | Workers 런타임에서 캡처 | 동시 refresh 완화(`refresh_token_threshold`)를 T092가 정한다 |
| **VD-T097-1** Dragonfly 운영 | T097 | 30일 키가 수십 개 수준이라 메모리 영향이 없다 | 키 수 · 메모리 실측 · maxmemory에 닿았을 때의 쓰기 동작(pod 사용자의 `FLUSHALL` · `ACL SETUSER` · `CONFIG SET` 가부는 T073 안으로 당겼다 — VD-T073-16 · 〔W33〕) | 메모리 한도 · maxmemory 동작을 조정한다. VD-T073-16이 「허용」으로 나왔으면 ACL에서 위험 명령을 빼는 dl 계약 보정(`-@dangerous` 등)을 여기서 함께 정한다 |
| **VD-T066-3** 라이브 Celery ACL | T075 | 운영 ACL 아래에서 worker · beat가 NOPERM 없이 돈다 | celery 로그 NOPERM 0 · 신선도 키의 값이 전진한다(35 s 간격으로 두 번 읽는다 — 존재만으로는 죽은 직후 300 s를 가리지 못한다 · 〔Z10〕) | ACL · transport 옵션을 본다 |

---

## 7. 인계

받는 과제마다 이 설계가 새로 만든 전제(세션 하한 · 절대 수명 · 신선도 키 · 권한 · 관리 명령)를 함께 넘긴다(〔E14〕).

- **T074**: publish-pod는 루트 컨텍스트 + `-f apps/identity-admin/Dockerfile`. revision 라벨 == `github.sha` 단언. paths는 `apps/identity-admin/**` · `packages/django-common/**`.
- **T075**
  - base는 1:1 복사한다.
  - ConfigMap `AUTHENTIK_WRITES_ENABLED`: dev `"false"` · prod `"true"`(D18로 US6 기간도 안전).
  - prod ES data[8..11]는 JSON6902 + `op: test`(secretKey).
  - `JT_PLACEHOLDER_EXEMPT`(두 overlay) = `AUTHENTIK_API_TOKEN,OPENFGA_STORE_ID,OPENFGA_PRESHARED_KEY`.
  - kv 시드: 웹훅 비밀은 CSPRNG 실값이고 **32자 이상**이어야 기동한다(D6). jwks_url · issuer는 계약 값.
  - API URL 둘(`AUTHENTIK_API_URL` · `OPENFGA_API_URL`)의 꼴 규칙(〔W35〕): 스킴은 http · https만이고 사용자 정보 · 쿼리 · 조각이 없어야 하며 경로는 빈 값이나 `/`뿐이다(D6 — 어기면 기동 실패). overlay가 URL 키를 더할 때(포트 변경 등) 걸린다.
  - **celery 생존 판정**(〔Y16 · Y24 · E5 · W16〕): celery 컨테이너에는 프로브 · 지표 포트가 없다. 판정 수단은 둘이다 — 신선도 키 `identity-admin:denylist:reapplied-at`의 존재(수명 300 s — 최근 300 s 안에 재적용이 끝나 Dragonfly까지 닿았다)와 `reconcile_denylist` 성공 줄. 내장 beat 자식이 죽어도 워커는 살고 beat는 다시 뜨지 않는다.
    - 키의 존재는 「최근 300 s 안에 한 번 닿았다」일 뿐이다 — 재적용이 죽은 직후 300 s는 키가 남는다. 사람이 판단할 때는 값(epoch 초)이 전진하는지 본다(35 s 간격으로 두 번 읽는다 — D14 · 〔Z10〕).
    - **결정 후보**(T075가 정한다): celery 컨테이너 exec liveness — 신선도 키가 N분 연속 없으면 재시작한다(컨테이너 재시작은 같은 pod라 beat 스케줄 파일이 남는다 — 일 1회 작업을 건너뛰지 않는다 · 사실 ⑧ · 〔Z11〕). 조건 둘을 함께 둔다. ① Dragonfly에 닿지 못하면 통과로 본다(브로커 장애 때 재시작 루프가 복구를 늦춘다). ② 재적용이 DB 장애로 실패 중일 때도 키가 비므로 문턱을 넉넉히 둔다.
    - 채택하지 않으면 「T098 전에는 beat 사망 탐지 0」이 T075의 알려진 한계다.
    - VD-T073-15 (b)에서 Dragonfly 재기동 뒤 worker · beat가 되살아나지 않았으면 그 보고(bn 「T073」)가 이 결정의 근거다.
  - gitops Dragonfly README의 「캐시이므로 dump 삭제가 안전하다」 문장에 「재적용이 살아 있을 때(신선도 키의 값이 전진하는지 확인 — 35 s 간격으로 두 번 읽는다)」 조건을 단다 — 하한 키는 30일치다(〔ATK-2〕). 키의 존재만 보면 재적용이 죽은 직후 300 s 동안 속는다(〔Z10〕).
  - pod 사용자의 `+@all` 범위(〔W33〕): T073 안에서 잰다(VD-T073-16 · 조각 ② — `FLUSHALL` · `ACL SETUSER` · `CONFIG SET`의 가부). 결과를 bn 「T073」 절에서 받아 운영 aclfile을 정할 때 본다(규칙 자체는 T073에서 바꾸지 않는다).
  - VD-T066-3 라이브.
- **T079**
  - 「로그에 reason」 = 이벤트 `session_revocation.recorded`의 `reason` 필드.
  - pod를 교환 토큰으로 직접 불러 401을 보는 단언은 사용자 단위 폐기에서만 성립한다(A14 · UD-7).
  - `tester-m2m`으로 pod를 직접 부르는 단언(tasks:212)은 그대로는 성립하지 않는다 — pod의 `common_name` 검사에서 403 `access_required`다(D30 · api계약 §호출자 식별). 401 · 200을 재는 경로(BFF 프록시 경유 · `ACCESS_EXPECTED_CN`을 여러 값으로 여는 계약 보정 등)는 T079 설계가 사용자 결정으로 정한다(〔편차 27〕 · 〔W1〕).
  - 폐기 뒤 2 s 이상 두고 재로그인한다(같은 초의 재로그인은 한 번 튕긴다 — 〔E10〕).
- **T080**: chart 판(UD-1 — 올리면 〔편차 23〕) · `server.service.servicePortHttp: 9000`.
- **T081**
  - 권한(UD-2 본체 — `view_event` 부여 여부 · 시드 쓰기 권한의 자리 · dev 계정 범위 포함 · 권한별 표는 C27) · token intent api · expiring false.
  - 매핑 규칙(D21): **`nbf` = `floor(created) + 1` 필수**(빠지면 WARNING `webhook.nbf_missing` · 더 크면 pod가 `⌊created⌋ + 1`로 낮춰 기록하고 WARNING `webhook.nbf_clamped` — 거부하지 않는다 · 〔Z8〕 · 둘 다 0건이 VD-T081-1의 통과 기준이다) · pk = `str(event.pk)` · JSON 기본형만 · Rule = logout만 · send_once.
  - logout 이벤트의 원천(세션 결속 깨짐 포함)을 거를지 정한다. 거르면 D17의 재확인에 같은 조건을 더하는 코드 변경이 이 과제의 범위다(〔E8〕).
  - provider scope에 `openid`와 `offline_access`(ID 토큰 `iat` · refresh 토큰 발급의 전제 — C27 · C44).
  - sub_mode user_uuid · groups 목록 · 그룹 껍데기(C21의 고정 UUID).
  - platform-admin(UD-3) · 세션 삭제 경로(UD-4).
  - 실측: VD-T081-1–5(매핑 · 권한 · 토큰 꼴 · refresh와 ID 토큰 · 시계). VD-T081-2에는 서비스 계정의 형과 권한 없는 조회의 응답 꼴이 든다 — 일 1회 대조의 「권한이 없을 때」 갈래(D17 · C7 (나) · C27)가 이 실측으로 확정된다(〔W2〕). 계약의 「소스 판독 — 실측 T081」 표시 여섯 곳도 여기서 닫는다(〔W3〕).
- **T082**: on_duplicate 지원 판 · store_id · preshared 사본. 실값을 넣은 뒤 두 overlay의 `JT_PLACEHOLDER_EXEMPT`에서 `OPENFGA_STORE_ID` · `OPENFGA_PRESHARED_KEY`를 거둔다(〔Y13〕).
- **T083**
  - 시드 절차(D19 — exec · prod 먼저 · UD-2 결과에 따라 `--authentik-token-stdin`).
  - 위임 검증은 세션 삭제로 한다(`/core/tokens/` 아님).
  - api_token 실값 뒤 면제 env에서 `AUTHENTIK_API_TOKEN`을 거둔다.
  - VD-T083-1(users 응답의 `groups` 꼴 · 위임 `deleted` ≥ 1).
- **T084**: 사람 admin 경로 · admin 모델 읽기 전용 등록 여부 · CSRF.
- **T085**
  - 끝 상태: 값에 `PLACEHOLDER-` 0 · **`JT_PLACEHOLDER_EXEMPT`가 빈 값**(〔Y13〕) · 로그에 `authentik.calls_disabled` 0건.
  - SC-003의 측정 정의는 UD-4 · UD-7 결과를 따른다. 관리자 폐기는 관리 명령 `revoke_sessions`로 일으킨다(D30).
  - m2m 직접 호출(`tester-m2m` — tasks:224)의 200 · 401 단언은 T079가 정한 측정 경로를 따른다(〔편차 27〕 · 〔W1〕).
  - 폐기 최종성 사례(지금의 T079 · T085는 「같은 access 토큰 401」만 재서 하한의 효과가 보이지 않는다 — 〔E14〕)
    - 전체 로그아웃의 「다른 기기」(BFF 세션 둘 — 한쪽에서 전체 로그아웃을 하고 다른 쪽은 330초 넘게 쉰다 · 6분 대기)와 복사한 쿠키가 사용자 단위 폐기 뒤 다음 접촉에서 401
    - 늦은 웹훅(또는 대조 백필) 뒤에 다시 로그인한 세션은 산다
    - 전체 로그아웃 2초 뒤 재로그인 → 프록시 호출이 pod에서 200(교환 캐시 키에 `issued_at`)
    - Dragonfly 유실 뒤 키(세션 하한 포함)의 복구 시간. 사례는 「마지막 5분 스냅숏 뒤에 만든 사용자 단위 폐기 → SIGKILL」 또는 「dump 삭제 뒤 재기동」으로 만든다 — 스냅숏 앞에 만든 하한은 재적용 없이 적재로 돌아와, 재적용이 아니라 적재 시간을 재게 된다(〔W19〕). 기대 상한은 「다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속」이다(〔W18 · Z1〕). tasks:224의 「≤ 30 s 안에」와 다르다 — 〔편차 29〕(solo 워커가 다른 작업을 돌거나 브로커에 다시 붙는 동안 30 s 재적용이 밀린다 · 운영 토폴로지 값은 이 측정이 처음 낸다)
    - 세션 절대 수명 30일은 시계를 조작하지 않고 볼 수 있는 범위만 본다(판정식과 경계는 T073 ia-36이 덮는다)
  - 위임 효과(Authentik 세션 삭제) · 웹훅의 사용자 단위 폐기 · dev/prod 웹훅 분리 · 시계 차(VD-T081-5)를 보고에 적는다. prod 대조의 `seen`이 0이 아닌 날이 있는지도 적는다(권한 없음이 조용한 0건으로 끝나고 있지 않은지 — 〔W2〕).
  - 기록 항목 하나 더(〔Z17〕): 같은 서비스 토큰으로 30 s 간격 두 요청의 `Cf-Access-Jwt-Assertion` `iat`. 「pod 시계가 뒤처지면 Access JWT `iat` 검사가 먼저 403」(D8 · D29 · 계약 C3)은 Access가 요청마다 `iat`를 새로 찍는다는 전제에 선 추론이다. 잰 결과가 전제와 다르면(두 `iat`가 같다 — Access가 JWT를 다시 쓴다) 「닿는 길은 둘」을 셋으로 고친다.
- **T089**(BFF 시험 — C36 · C43–C45의 사례)
  - `issued_at`의 원천(callback ID 토큰 `iat`)과 refresh에서의 불변
  - 네 라우트(`/api/session` · refresh · proxy · logout)에서 `/session/check`가 토큰 엔드포인트 호출과 교환 캐시 사용보다 먼저다
  - inactive 처리: RFC 7009 → 쿠키 삭제 → 401 · 503이면 회전 0. 프록시의 inactive도 같은 세 단계이고 응답은 BFF가 만든 401 `session_revoked`다(C44 (마) · (아) · 〔W9〕).
  - logout + inactive(C36 · 〔W17〕): `/sessions/revoke`를 부르지 않고 RFC 7009 → 쿠키 삭제까지는 같다. 응답만 갈린다 — 본문이 `all_devices: true`를 명시했으면 401 `session_revoked`, 그 밖은 204. 사례 하나: inactive 세션의 전체 로그아웃 → 401이고 `/sessions/revoke` 호출 0(이 갈래는 아무 폐기도 기록하지 않는다 — 다른 기기는 그대로다).
  - 캐시 키 둘(2초 캐시 = `sub` + `issued_at` + `sid` · 교환 캐시 = `sub` + `aud` + `issued_at`)
  - 「전체 로그아웃 → 재로그인 → 프록시 200」(〔ATK-4〕)
  - logout의 하류 본문 규칙(C36) — 기본 범위는 UD-7 뒤에 고정한다.
- **T092**(BFF 구현)
  - 관문 하나(`requireActiveSession`)를 거친 세션만 refresh · 교환 함수가 받는다(확인 없는 회전 경로 0을 구조로 지킨다).
  - logout 매핑은 UD-7 결정 뒤에 정한다(초안의 「기본 로그아웃 = 단일 세션」은 지웠다 — 교환 토큰에 `sid`가 없어 단일 세션 폐기는 pod에서 집행되지 않는다 · 〔Y1〕). `sid`가 없으면 `/session/check` 쿼리에서 뺀다.
  - RFC 7009 응답 꼴 · 같은 쿠키의 동시 refresh(VD-T092-1) · scope `openid` + `offline_access` · callback 입장 판정(UD-8 결과).
  - 쿠키 `Max-Age`를 세션 절대 수명의 남은 시간으로 줄일지는 선택이다.
- **T097**: 30일 키의 메모리 · maxmemory에 닿았을 때의 쓰기 동작 · 재적용이 읽는 범위(30일치 사용자 단위 행 — `logout_all` 반복으로 불어난다)와 증분 재적용 전환 기준(VD-T097-1). `+@all` 명령 범위는 T073 안에서 잰다(VD-T073-16 — 결과는 bn 「T073」 · 〔W33〕).
- **T098**: 로그 이벤트(D25) · celery stdout · 지표. **경보 기준** — `reconcile_denylist` 성공 줄 5분 무소식 · `denylist.set_failed` · `denylist.reapply_failed` · `authentik.revoke_failed`의 status 401 · 403 · US4 뒤의 `authentik.calls_disabled` · `authentik.reconcile_truncated`. dev의 `authentik.reconcile_forbidden`(권한을 주지 않았을 때 하루 한 줄)은 경보에서 뺀다(〔Y16 · Y23〕).
  - 검토 반영으로 더한 기준(〔W19〕): `webhook.nbf_missing` 1건 · prod의 `authentik.reconcile_forbidden` · `authentik.reconcile_failed` 이틀 연속 · `authentik.reconcile_done` 48 h 무소식(beat 스케줄 파일이 `/tmp` emptyDir라 pod가 바뀌면 — 롤아웃 · Reloader · 축출 — 스케줄 파일이 새로 생겨, 03:37을 걸친 교체는 그날 실행을 실패 줄 없이 건너뛴다. 같은 pod 안의 컨테이너 재시작은 파일이 남아 기동 직후 따라잡는다 — 소스 판독 · 〔Z11〕 · 경보 기준 48 h는 그대로다) · `session_check.iat_in_future` 1건 · `session_floor.lookup_failed`.
  - 재검토 반영으로 더한 기준(〔Z8 · Z12〕): `webhook.nbf_clamped` 1건(매핑이 `nbf`를 `⌊created⌋ + 1`보다 크게 계산했다 — 폐기는 낮춘 값으로 기록됐다) · prod의 `authentik.reconcile_skipped` 이틀 연속(사용자 조회 권한을 본다) · `authentik.revoke_done`에서 `deleted` 0 · `gone` ≥ 1이 되풀이됨(삭제 권한을 본다 — 권한이 빠진 DELETE도 404라 실패 줄이 없다).
  - 「오류 없는 빈 목록」의 탐지 후보 둘(〔Z13〕 — T073에서는 구현하지 않는다): 대조 권한이 없는데 이벤트 조회가 오류 없이 빈 목록으로 오는 계정 형이면 `reconcile_done seen=0`이 매일 정상처럼 찍힌다(D17 · §9). ① prod `authentik.reconcile_done`의 `seen` 0이 여러 날 이어짐을 경보로 둔다. ② 자기 점검 `authentik.reconcile_blind` — 창 안에 기록된 `event_pk`가 있는데 이번에 읽은 이벤트 pk와 하나도 겹치지 않으면 WARNING(웹훅이 한 건이라도 온 72 h에는 「못 읽는 계정」이 드러난다). ②는 코드 변경이라 converge 과제 후보다.
  - 신선도 키의 수명 300 s는 성공 줄 5분 무소식과 같은 문턱이다(〔W16〕). 로그 필드는 JSON 최상위 키로 읽는다(D25 「로그 꼴」 · 〔W26〕).
- **T100**: US7 AC3 smoke 권고(D28) · Celery Sentry 없음.
- **T114**(런북)
  - 계정 탈취 대응(〔W20〕 — 순서를 지킨다): ① Authentik 사용자 **비활성화**(세션 · Access · Refresh · Device 토큰 전부 삭제 — 〔V8〕) → ② `revoke_sessions --sub`(BFF 세션 종료) → ③ 조사 → ④ 재활성화.
    - 비활성화가 먼저다 — 그 뒤에는 새 세션이 생길 수 없어 하한이 전부를 덮는다. 순서가 반대면 둘 사이에 SSO로 만든 새 BFF 세션이 교환 캐시가 사는 5분 동안 산다.
    - 하한만으로는 Authentik 로그인 세션이 살아 있는 기기의 재진입을 막지 못한다(〔Y2 · E9〕).
    - 재활성화 전 확인: 비밀번호 재설정 · API 토큰과 app password 삭제(비활성화가 지우지 않는다 — 〔V8〕) · MFA 장치 확인 · 연결된 소스(소셜 로그인) 연동과 이메일 변경 여부(〔Z19〕 — 공격자가 건 연동이 남으면 비밀번호와 MFA를 바꿔도 재활성화 뒤 그 길로 들어온다 · Authentik 동작은 T081 · T114에서 확인).
    - 단일 세션 폐기 수단은 없다 — 탈취 대응은 사용자 단위다(관리 명령에 `--sid`를 두지 않았다 · 〔W13〕).
    - 명령의 판정은 stdout의 `revoke_sessions: OK|PARTIAL` 줄로 한다 — 그 줄이 없으면 기록되지 않았다(〔Z9〕 · 같은 stdout에 JSON 로그 줄이 섞이므로 그 접두로 찾는다 · 인자 사용법 오류는 그 줄 없이 2로 끝난다).
    - 머리말이 `PARTIAL`(종료 코드 3 · 〔Z9〕)이면 행은 기록됐지만 거부 목록 쓰기가 실패한 것이다 — 60 s 뒤 `revoked:sub`와 세션 하한 키가 생겼는지 확인한다(〔Z10〕). 생기지 않았으면 재적용이 닿지 못하는 것이다(Dragonfly 장애가 이어지거나 재적용이 죽었다) — 재적용 생존은 신선도 키의 존재가 아니라 값이 전진하는지로 본다(35 s 간격으로 두 번 읽는다 — 죽은 직후 300 s는 키가 남는다). `delegate=failed`면 Authentik 세션 삭제 위임이 나가지 않았다(D30 · 〔W21〕).
  - 잘못 오른 하한 내리기(〔W20 · Z19〕): 로그 행의 `nbf`와 `expires_at`을 함께 고치거나 행을 지운다 → 키 둘(`revoked:sub` · 세션 하한)을 DEL한다 → 30 s 뒤와 비정상 재기동 뒤 다시 확인한다.
    - 행이 먼저다 — 키를 먼저 지우면 30 s 재적용이 되살린다(재적용은 SET만 한다 — 〔E6 · ATK-9〕).
    - `nbf`만 낮추고 `expires_at`(= `nbf` + 330 s)을 두면 그 행이 재적용 첫 SQL에서 계속 활성이고 하한 수명 · purge 경계도 옛 값을 따른다. 행을 지운 경우는 재적용이 그 키를 건드리지 않으므로 DEL이 유일한 수단이다(재검토 RB-15).
    - 비정상 재기동 뒤의 확인은 5분 스냅숏이 키를 되살릴 수 있어서다.
  - DB 시점 복구 뒤: 복구 시점 이후의 폐기가 사라진다 → 전 사용자 종료 = `SESSION_ENCRYPTION_KEY` 교체. 교체는 이중 키 창 없이 즉시 한다 — T084의 「버전 접두 이중 키 창」을 두면 옛 쿠키가 창 동안 산다(〔W20〕).
  - Dragonfly 유실: 30 s 재적용 · `beat_init` · 신선도 키의 값이 전진하는지 확인(존재만으로는 재적용이 죽은 직후 300 s를 가리지 못한다 — 〔Z10〕) · beat가 죽었으면 celery 컨테이너 재시작.
  - 시드: prod 먼저 · 자리값 → 실값 전환 확인(`authentik.calls_disabled` 0건 · `JT_PLACEHOLDER_EXEMPT` 회수) · `--tenant-id` 오타 복구(그룹 조회가 먼저라 DB에 남지 않는다 — D19).
  - 재생성 절차(D3).
- **CI · T116 · 운영자**
  - main ruleset required check `identity-admin`
  - Renovate: 생성 pod의 템플릿 소유 파일(Dockerfile digest · `compose.dev.yml` · `pyproject.toml` 핀 · `deploy/base`)은 템플릿과 함께 올린다. `uv.lock` 유지보수는 pod 단독으로 허용한다. ninja 1.7.3 올림도 템플릿과 pod를 함께 한다(〔Y13〕).
  - 다음 템플릿 변경 때 하네스 FORBIDDEN 이름에 ia 파일을 더할지(이름이 basename 단위라 `models.py`는 그대로 넣을 수 없다 — H/tests/_tree.py:449)
- **converge**
  - 새 ADR: 「세션 폐기 최종성 = 세션 하한(로그 파생 30일 키) + 세션 절대 수명 · refresh 폐기 주체 = BFF의 RFC 7009 · ADR 0006:29 정정」. 번호는 그때 정한다(0011은 Vault 정정에 예약돼 있다). 설계 커밋에서는 만들지 않는다(〔E11〕 · 〔편차 26〕).
  - UD-4가 back-channel logout으로 정해지면 새 수신 경로는 converge 과제 규모다.
  - 대조의 자기 점검 `authentik.reconcile_blind`(T098 인계의 후보 ② · 〔Z13〕)를 채택하면 코드 변경이라 converge 과제다(T073에서는 구현하지 않는다).
- **컨트롤러**
  - 고정 테넌트 UUID는 채웠다(dm §1 `id` 행 · C21 — 이후 바꾸지 않는다).
  - bn 「T073」 절 머리에 G5의 정정(t072:1211)과 이 설계의 요약을 적는다.
  - 조각 ⑥ 끝 뒤에 3-way 재생성 리허설을 돌린다(VD-T073-11 — 저장소 밖 임시 복제본 · 전용 하위 에이전트 · §5 · 〔W23〕).
  - VD-T073-6 ④의 측정(`retry_policy` `max_retries` 0 대 1)을 받아 값을 정한다(기본은 0 유지 — 〔W25〕). VD-T073-15 (a)가 실패하거나 (b)에서 worker · beat가 되살아나지 않으면 재적용 루프의 자리(beat 프로세스 타이머)와 T075 liveness를 결정 후보로 본다.
  - D3의 두 목록에 없는 템플릿 소유 시험이 깨졌다는 빌더 보고를 받으면 그 시험이 기본값 단언인지 불변식 단언인지 정한다(〔W22〕).
  - 조사 임시 디렉터리 정리: `C:\jt73p` · `C:\jt73p-ow` · `-ow2` · `-ow4` · `-n173` · `C:\jt73-tests` · `C:\jt73-external` · `C:\jt73-library`.

---

## 8. 사용자 결정

### 현재 상태(2026-11-12)

확정은 셋이고 대기는 여섯이다. 대기 항목은 해당 과제 전에 하나씩 묻는다. T073 코드는 대기 항목의 어느 답이든 같다 — 근거는 「결정 전 기본값」과 「바꾸는 자리」 칸이다.

| # | 내용 | 상태 | 결정 전 기본값(T073 코드) | 답에 따라 바뀌는 자리 |
|---|---|---|---|---|
| UD-5 | 폐기 최종성(330초 뒤 refresh로 부활) | **확정(사용자 2026-11-12): 「로그 파생 + 수명 30일」** | — | D29 · C3 · C39–C45 |
| UD-2 하위 | 일 1회 대조의 자료원 | **확정(사용자 2026-11-12): 「이벤트 대조 구현」** | — | D17 · C7(`view_event`의 실제 부여는 UD-2 본체) |
| UD-6 | django-ninja 1.7.0 유지 대 1.7.3 | **확정(컨트롤러 — 사용자 결정이 아니다): 1.7.0 유지** | — | D28 · C1 · C16 · C47 |
| UD-1 | Authentik ≥ 2026.8.2 | 대기 — T080 착수 때 묻는다(그때 최신 패치 재확인) | 판과 무관하게 짰다: 세션은 단건 DELETE(`bulk_delete` 미사용 — 8.0 · 8.1 버그 회피) | gitops chart 판(T080) · report 편차 23 |
| UD-2 본체 | pod 장기 토큰의 권한 범위 · prod 시드 쓰기 자격 · `view_event` 부여 | 대기 — T081 전 | `--authentik-token-stdin`을 구현해 두고 기본은 끈다. 권한이 없는 호출은 로그 뒤 끝나게 짰다(대조의 「권한이 없을 때」 갈래 — D17 · 위임 4xx) | Authentik blueprint의 권한(T081) · 시드 절차(T083) · C27 표의 「부여」 |
| UD-3 | `platform-admin` 소속을 누가 쓰나 | 대기 — T083 전 | seed는 `platform-admin`을 건드리지 않는다(T066 고정 — 미끼 단언) | 운영 절차 · blueprint(T083 · T084) |
| UD-4 | SC-003 「Authentik 세션 삭제」 경로의 정의 | 대기 — T081 전(T081의 Rule · 매핑 설계가 이 답에 기댄다 — 〔W11〕) | 웹훅은 `logout`과 `session_deleted`를 둘 다 받는다(뒤의 것은 오지 않아도 해가 없다) | SC-003 측정 정의(T085) · A안이면 새 수신 경로(converge 과제) |
| UD-7 | BFF의 기본 로그아웃 범위(전체 기기 대 단일 세션) | 대기 — T089 전 | pod는 본문대로 두 범위를 다 구현한다(T066 고정). 조합 규칙(D9)만 지키면 된다 | BFF logout의 본문 매핑(C36의 끝 문장 · T089 · T092) · AC3 · SC-003 측정 방법 |
| UD-8 | SSO 재진입 — callback 입장 판정을 둘지 | 대기 — T089 전 | BFF callback은 identity-admin을 부르지 않는다. `/session/check`는 `iat` 하나로 판정하므로 입장 판정을 두더라도 pod 코드는 그대로다 | BFF callback(C44 (나) · T089 · T092) |

### UD-1 Authentik 판(대기 — T080 착수 때 · T073 코드 영향 0)

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A 2026.8.0(plan:17) | 편차 없음 | GHSA-h6c5 · m9h4 · bulk_delete 버그가 남는다 | 시드 쓰기 권한을 가진 토큰이 새면 권한 상승(h6c5) · 설정 객체 view 권한을 가진 계정의 저장 자격 열람(m9h4 — 런타임 권한과는 무관하다) |
| B ≥ 2026.8.2(착수 때 최신 패치 — 조사 시점 8.5) | 권고 둘과 bulk_delete 버그 해소 | plan 판 편차(report) | 패치판 회귀(소규모) |

**권고: B.**

### UD-2 서비스 계정 권한 · 시드 쓰기 자격(본체 대기 — T081 전 · 하위는 확정)

**하위 결정(확정 2026-11-12)**: 일 1회 대조의 자료원은 events API다(「이벤트 대조 구현」 — D17). 대안은 「SP-1은 작업 등록만 하고 no-op」이었다. 대조에 필요한 `view_event`를 실제로 줄지는 아래 본체에서 정한다. 주지 않으면 대조는 「권한이 없을 때」의 갈래로 끝난다 — 401 · 403이면 로그 한 줄 뒤, 서비스 계정의 형에 따라서는 경고 없이 `seen` 0으로(D17 · 코드 플래그 없음 — 〔E8 · W2〕).

**본체(대기)** — 두 안의 권한을 같은 기준(런타임 필수 + 시드)으로 적는다(〔Y7〕). 권한별 사용 작업은 C27의 표다.

| | A — pod 장기 토큰에 시드 쓰기 권한까지 | B — pod 장기 토큰은 런타임 권한만 · prod 시드는 운영자 만료 토큰(stdin) |
|---|---|---|
| prod pod 토큰의 런타임 권한 | `view_user` · `view_authenticatedsession` · `delete_authenticatedsession`(+ 대조를 켜면 `view_event`) | 같다 |
| prod pod 토큰의 시드 권한 | `view_group` · `add_user_to_group` · `change_user` | 없음(운영자 만료 토큰이 `view_group` · `add_user_to_group` · `change_user`를 갖는다) |
| dev pod 토큰 | `view_user` + 시드 읽기용 `view_group`(+ 대조를 켜면 `view_event`) | 같다(계약의 「사용자 read만」에서 `view_group`만큼 넓어진다 — 아니면 dev 시드도 stdin 토큰으로 돈다) |
| 토큰이 새면 읽히는 것 | 전 사용자의 이메일 · attributes · 세션 IP · UA(+ `view_event`면 감사 이벤트 전체 — 로그인 IP · 사용자명 · 관리자 행위) | 같다 |
| 토큰이 새면 할 수 있는 것 | 임의 사용자 강제 로그아웃 + **임의 사용자의 그룹 소속 · attributes 변경 · 비활성화**(8.0 · 8.1이면 GHSA-h6c5로 superuser) | 임의 사용자 강제 로그아웃뿐 |
| 장점 | T083 문면 그대로 · 운영 단계가 적다 | 장기 토큰의 쓰기 권한이 세션 삭제 하나 · 「권한 한정」 취지에 맞다 |
| 단점 | T081 권한 목록을 넓힌다 | 운영 단계가 하나 늘고 T083 문면과 다르다 · stdin 취급 실수 |

- 두 안 공통: 「토큰 revoke」 권한을 뺀다(줄 수 없는 권한이다 — 〔조사 E7〕). `view_authenticatedsession`은 필수다 — 없으면 세션 목록이 오류 없이 빈다(〔조사 E4〕).
- GHSA-m9h4는 설정 객체의 view 권한 문제라 두 안의 권한과 무관하다. GHSA-h6c5만 A안의 시드 쓰기 권한에 해당한다(UD-1과의 결합은 이 범위다).
- 따로 정할 것 둘: (가) `view_event`를 줄지 — dev · prod가 한 Authentik이라 dev 토큰에 주면 prod 사용자의 이벤트도 읽힌다. dev에는 주지 않는 것이 기본이다(계약의 dev 계정 = 사용자 read만 — dm:187) (나) dev 시드의 그룹 조회 자격.
- 결정 전 기본값: `--authentik-token-stdin`을 구현해 두되 기본은 꺼 둔다. 어느 쪽을 골라도 코드는 바뀌지 않는다.

**권고: B.**

### UD-3 platform-admin 소속 주체(대기 — T083 전)

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A seed 옵션 | 한 번에 끝 | T066 미끼 취지와 충돌 | 그 토큰이 새면 관리자 승격(Argo · Vault admin — tasks:220) |
| B 운영자가 Authentik UI에서 1회 추가(MFA · 런북 · T085가 groups 클레임 확인) | 자동화 토큰에 승격 권한 0 | 수동 단계 · T083 문면 편차 | 절차 누락(T085가 잡는다) |
| C blueprint `!Find` | git 선언으로 남는다 | 운영자 식별자가 gitops에 실린다 · 첫 로그인 전 적용 불가 | 적용 순서 |

**권고: B.**

### UD-4 SC-003 「Authentik 세션 삭제」 경로(대기 — T081 전)

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| A OIDC back-channel logout(새 수신 경로 · logout+jwt · sid) | 삭제를 실제로 통지한다 | 새 엔드포인트 · provider JWKS · 계약 · 시험 → converge 과제 규모 | 살아 있는 access 토큰이 없는 세션(330초 넘게 쉰 기기)은 통지되지 않는다(〔조사 E10 · V10〕) — 하한의 쓰기 신호로는 모자란다 |
| B 정의 변경: 3경로 = BFF 로그아웃 · 관리자 폐기(관리 명령 `revoke_sessions`) · Authentik 로그아웃 이벤트 웹훅 | 지금 장치로 측정할 수 있다 | 명세 편차(report) | Authentik UI에서 직접 지운 세션은 이벤트가 없어 기록되지 않는다 — 그 BFF 세션은 세션 절대 수명(30일)까지 산다(D29의 「기록되지 못한 폐기」) |
| C 일 1회 대조 | 코드 0 | ≤ 2 s 불가 | SC 미충족 |

**권고: B.** A는 SP-2 후보다. 어느 답이든 T073 코드는 같다 — 웹훅은 `session_deleted`를 받아도 해가 없다(D21).

### UD-5 폐기 최종성(확정 2026-11-12)

**확정: 「로그 파생 + 수명 30일」**(사용자 2026-11-12) — 기존 폐기 로그에서 사용자별 세션 하한 키를 파생해 30일 유지하고, `/session/check`가 30일 넘은 세션도 inactive로 판정한다. 새 표 0. 구현은 D29다.

경과는 다음과 같다.
1. 초안의 표는 「A — BFF가 `/session/check`의 iat에 세션 시작 시각을 넣는다 / B — 받아들인다 / C — 관리자 폐기 때 사용자 비활성화」였고 A를 권고했다.
2. 비판 둘이 A의 효과가 과장임을 밝혔다(A-2 · B-1 · 〔Y2〕): A는 키가 사는 **330초 안에 BFF에 닿은 세션만** 끊는다. 330초 넘게 쉰 기기 · 전체 로그아웃의 다른 기기 · 복사한 쿠키는 refresh로 산다.
3. 사용자가 「세션 시작 시각 하한」을 문제 정의로 받고 서버 측 정책의 분석을 요청했다. 분석 `wf_6a1dd5d0-d8f`가 네 변형(시각형 전용 표 · 카운터형 · TTL 하한 키 · Authentik 속성)을 견줬고, 반박이 「TTL 하한 키 + 서버가 집행하는 절대 세션 수명」이 전용 영구 표와 같은 최종성을 표 없이 갖는다는 것을 보였다(〔ATK-6〕).
4. 다시 물은 선택지와 답은 아래다.

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **(가) 로그 파생 하한 키 + 세션 절대 수명 30일 — 확정** | 새 표 · 허용 목록 · django-common · 템플릿 변경 0 · 정본이 하나(로그) · 기록되지 못한 폐기와 시계 틈도 30일로 묶인다 | 세션이 30일마다 다시 로그인된다(승인 문면에 없는 새 동작) · BFF 계약 보정 | BFF 규율에 기댄다 · 유실 뒤 재적용이 돌아올 때까지 열린다(D29의 「남는 열림」) |
| (나) 전용 B 등급 표(영구) | 30일 넘는 세션을 재로그인 없이 허용할 수 있다 | 허용 목록 4 → 5 개정(dc · 계약 2 · 규칙 2 · ADR 0007 · 승인 문면 5곳) · 정본 이원화 | 기록되지 못한 폐기에는 상한이 없다 |
| 카운터형 | 판정에 시각 비교가 없다(요청 경로) | 로그인 때 identity-admin 호출 · 쿠키 필드 추가 | 늦은 이벤트가 새 세션을 끊는다 |

**SP-1에서 닫지 않은 것**: SSO 재진입은 UD-8, `sid` 단위 폐기의 최종성은 UD-7과 SP-2(D29).

### UD-6 django-ninja(확정 — 컨트롤러)

**확정: 1.7.0 유지.** t072 §8이 「사용자 결정이 아니다」로 둔 항목이다. 1.7.3 올림은 T116에서 템플릿과 pod를 함께 한다.

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| **A 1.7.0 + 「dict · 정확한 스키마 인스턴스만」 규칙 — 확정** | 템플릿 · 하네스 · 계약의 핀이 그대로다 | 1.7.1–1.7.3 수정이 빠진다 · 폐기 폴백 문장 1.6.2 → 1.6.5는 plan:17 편차다(〔편차 10〕 · 〔Y9〕) | 규칙을 어긴 뷰의 필드 누출 — 규칙을 `.claude/rules/django-pod.md`와 템플릿 README에 둔다(C47 · C34) |
| B 1.7.3(템플릿 · 하네스 · 계약 2곳 · plan 편차) | 누출 경로 제거 · dc 시험 판과 일치 | 하네스 918 재검증 | 회귀 실측 0(〔P32〕) |

### UD-7 기본 로그아웃 범위(대기 — T089 전 · 새 항목 〔Y1〕)

교환 토큰에 `sid`가 없어 pod 경계는 `revoked:sid`를 보지 못한다(A14). BFF의 `/api/auth/logout`이 `all_devices`를 생략한 요청을 어느 범위로 보낼지 정해야 한다.

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| (가) SP-1의 BFF 로그아웃은 늘 사용자 단위(`all_devices: true` · `logout_all`) | AC3 문면의 `revoked:sub` 그대로 · pod에서 같은 access 토큰이 401 · 로그아웃마다 세션 하한이 생겨 최종성이 같다 | 다른 기기도 함께 로그아웃된다 | 재적용이 읽는 사용자 단위 행이 로그아웃 수에 비례해 는다(T097) |
| (나) 단일 세션 유지(`all_devices: false` + 쿠키 `sid`) | 다른 기기를 건드리지 않는다 | pod 경계에서 집행되지 않는다 — 집행은 BFF의 쿠키 삭제 + refresh 폐기(RFC 7009) + 교환 토큰 캐시 폐기뿐 · AC3 · SC-003 측정을 BFF 경유로 한정해야 한다(인수 기준 편차) | RFC 7009가 실패하면 330초 뒤 복사 쿠키가 산다(하한 없음 — 〔E13〕) · 같은 Authentik 세션에서 다시 로그인하면 `sid`가 같다(`sid` = sha256(세션 키) — 〔V2〕 · 소스 판독) — `revoked:sid` 값은 `1`이라 시각으로 가를 수 없어 단일 로그아웃 뒤 330 s 안의 재로그인은 매번 inactive이고 BFF가 그 refresh까지 지운다(〔W35〕) |

결정 전 기본값: pod는 본문대로 두 범위를 다 처리한다(T066 고정). T073 코드 영향 0.

- logout + inactive 갈래와의 관계(C36 · 〔W17〕): 지금 계약은 본문이 `all_devices: true`를 **명시**했을 때만 401 `session_revoked`를 내고 생략 요청은 204다. UD-7이 (가)로 정해지면 생략 요청도 전체 로그아웃이 되므로, 그 갈래의 응답을 그때 다시 정한다.

### UD-8 SSO 재진입(대기 — T089 전 · 새 항목 〔E9〕)

사용자 단위 폐기 뒤에도 Authentik 로그인 세션이 살아 있는 기기는 재인증 없이 새 BFF 세션을 얻는다(하한이 막는 것은 폐기 전에 만든 BFF 세션이다 — 〔ATK-3〕). Authentik 세션 삭제 위임(D16)은 prod의 요청 경로에서 창 안에 성공할 때만 그 세션을 지운다.

| 선택지 | 장점 | 단점 | 위험 |
|---|---|---|---|
| (가) callback 입장 판정 — callback이 `/session/check?iat=<auth_time>`을 한 번 부르고 inactive면 쿠키를 만들지 않고 `prompt=login`으로 다시 인가한다 | 웹훅 · 백필 · dev · 위임 창 밖 경로에서도 「모든 기기 로그아웃」이 자격 재입력을 강제한다 · Authentik 쓰기 권한이 필요 없다 | 로그인이 identity-admin과 Dragonfly에 묶인다 · 입장 판정이 `iat=<auth_time>`으로 물으면 나이 조건도 `auth_time`에 걸린다 — Authentik 로그인 세션이 30일을 넘으면 inactive → `prompt=login`이다(〔W35〕) | `prompt=login` 동작은 소스 판독뿐이다(T081 실측) |
| (나) 한계 수용 — 「전체 로그아웃은 Authentik 세션 삭제(D16)가 성공한 기기에서만 재인증을 강제한다」 | 변경 0 · 로그인이 identity-admin 장애에 묶이지 않는다 | dev · 웹훅 경로에서는 재인증이 강제되지 않는다 | 탈취된 브라우저 프로필이 자격 없이 다시 들어온다(완결은 Authentik 사용자 비활성화 — T114) |

결정 전 기본값: BFF callback은 identity-admin을 부르지 않는다(C44). `/session/check`는 `iat` 하나로 판정하므로 (가)를 골라도 pod 코드는 그대로다 — T073 코드 영향 0.

---

## 9. 위험 · 이 설계가 확인하지 못한 것

확정 설계 기준이다. 폐기 최종성 분석의 반박이 견디지 못했다고 본 공격과 판정이 남긴 위험 가운데 이 안에 해당하는 것을 함께 적는다.

### 폐기 최종성(D29)이 덮지 않는 것

- **집행은 BFF 규율이다.** `issued_at`의 불변 · 네 라우트의 확인 자리 · 캐시 키 둘은 identity-admin이 지킬 수 없다. `apps/web`이 아직 없어 T089 · T092에서 처음 검증된다. 나이 조건도 BFF가 보낸 `iat`에 기대므로, refresh 때 `issued_at`을 갱신하는 결함은 하한과 나이를 함께 무력하게 한다. 확인이 한 번 빠진 경로로 회전한 세션은 다음 확인에서 다시 잡힌다.
- **Dragonfly 유실 ~ 재적용 복귀 사이는 열려 있다.** 키 없음 = 통과다(api-4가 빈 Dragonfly에서 active를 요구해 닫힌 쪽 표식을 둘 수 없다). 상한은 「다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속」이고(구조상 상한 — 계약도 이렇게 적었다 · 〔W18 · Z1〕 · 승인 문면의 「최대 30 s」와 다르다 — 〔편차 29〕 · 재접속 몫의 실측은 VD-T073-15), beat가 멈춘 채 유실되면 사람이 알 때까지다. 탐지는 신선도 키와 성공 줄 무소식 경보인데 경보는 T098에야 생긴다 — 그 전 US6 기간의 탐지 수단은 로그와 키를 손으로 보는 것뿐이다(〔ATK-2〕).
- **기록되지 못한 폐기는 30일까지 산다.** 유실된 웹훅(대조 권한을 주지 않았거나 대조가 돌기 전) · 503으로 끝난 전체 로그아웃(Dragonfly 장애 중의 `/sessions/revoke`는 미들웨어에서 503이다) · Authentik UI에서 직접 지운 세션 · 멤버십이 없는 sub의 로그아웃(〔ATK-5〕).
- **시계**: Authentik이 pod보다 앞선 만큼 폐기 직전에 만든 세션이 산다(열림 · 30일 상한 — 〔ATK-1〕). pod가 앞서면 폐기 직후 재로그인이 한 번 튕긴다(닫힘 — 〔ATK-8〕). Authentik이 pod보다 60 s 넘게 앞서면 갓 만든 세션이 그 차이만큼 inactive다(미래 `iat` 조건 — 닿는 길은 이것과 BFF 결함 둘뿐이다 · 〔W15〕). 「둘뿐」은 추론이다 — pod 시계가 뒤처진 경우를 Access JWT `iat` 검사가 먼저 403으로 막는다는 것은 Access가 서비스 토큰 요청마다 `iat`를 새로 찍는다는 전제에 서고, 그 전제는 잰 적이 없다(실측 T085 — 전제가 틀리면 뒤처진 pod가 갓 만든 세션을 inactive로 보아 로그인할 때마다 세션이 지워진다 · 〔Z17〕). 관리 명령은 실행 프로세스 시계가 PG보다 300 s 넘게 앞서면 거부된다(`CommandError` — 시끄럽게 드러난다 · D12). HTTP 경로의 폐기 기록은 PG 시계에 기대지 않는다(〔W14〕). 시계 차는 실측한 적이 없다(VD-T081-5).
- **SSO 재진입**: 하한이 막는 것은 폐기 전에 만든 BFF 세션이다. Authentik 로그인 세션이 살아 있는 기기는 자격 없이 다시 들어온다(〔ATK-3〕 · UD-8). 계정 탈취 대응의 완결은 Authentik 사용자 비활성화다(T114).
- **위임 enqueue 실패 = 그 폐기의 Authentik 세션 삭제 누락.** 다시 보내는 주체가 없다(〔E12〕). SSO 재진입과 같은 범주의 열림이고 하한은 유지된다. 워커가 5분 넘게 내려가 위임 창을 넘겨도 같다.
- **위임이 늦게 돌면 닫힌 쪽으로 넘친다.** 창(300 s) 안에서 폐기 뒤 다시 로그인한 Authentik 세션도 지운다 — 세션 목록에 생성 시각이 없다(〔조사 E2〕 · 한 번 더 로그인하면 된다).
- **`sid` 단위 폐기**: pod 경계에서 집행되지 않고(교환 토큰에 `sid` 없음 — A14) 하한도 없다. 최종성은 BFF 로그아웃의 RFC 7009에 기대며, 그 호출이 실패하면 330초 뒤 복사 쿠키가 산다(〔E13〕). 같은 Authentik 세션에서 다시 로그인하면 `sid`가 같다(`sid` = sha256(세션 키) — 〔V2〕 · 소스 판독) — `revoked:sid` 값은 `1`이라 시각으로 가를 수 없어 단일 로그아웃 뒤 330 s 안의 재로그인은 매번 inactive이고 BFF가 그 refresh까지 지운다(UD-7 · T092 · 〔W35〕). 관리자 갈래(`/sessions/revoke`의 `reason: admin` · `all_devices: false`)가 일으킨 `sid` 폐기에는 refresh 폐기가 따르지 않는다 — SP-1에는 그 갈래를 부르는 호출자가 없고 관리 명령도 단일 세션 폐기를 두지 않는다(〔W13〕).
- **오탐 폐기의 값이 30일이다.** 대조가 login 이벤트를 폐기로 기록하거나(재확인이 막는다 — D17) 매핑이 `nbf`를 빠뜨리면(경고 `webhook.nbf_missing`이 드러낸다 — D21 · 1건이라도 경보다 · 〔W19〕) 닫힌 쪽으로 30일 간다. 매핑이 `nbf`를 `⌊created⌋ + 1`보다 크게 계산한 것은 그 값으로 낮춰 기록되고 WARNING `webhook.nbf_clamped`가 드러낸다(1건이라도 경보다 · 〔Z8〕 — 거부하면 그 로그아웃이 Authentik 재시도 끝에 유실돼 열린 쪽으로 간다. 경보가 생기는 T098 전에는 이 WARNING도 로그를 손으로 봐야 보인다). 재로그인 한 번으로 회복된다. 웹훅 비밀이 새면 5분마다 미래 `nbf`(≤ 수신 + 301 s)를 보내 특정 사용자의 로그인을 계속 막을 수 있다(기존 `revoked:sub`와 같은 능력 — 〔ATK-9〕).
- **잘못 오른 하한은 스스로 내려가지 않는다.** 미래 값은 경로마다 쓰기 전에 막고(D12 — 웹훅은 `⌊created⌋ + 1`로 낮춤 · 대조의 `created` 재확인 · 관리 명령의 DB 시계 + 301 s · 〔W14 · Z8〕), 내리는 절차(로그 행의 `nbf`와 `expires_at`을 함께 고치거나 행을 지운 뒤 키 둘 DEL → 30 s 뒤와 비정상 재기동 뒤 확인)는 T114 런북이다(〔W20 · Z19〕).
- **inactive 세션에서 누른 로그아웃은 아무 폐기도 기록하지 않는다.** 이미 폐기됐거나 30일을 넘긴 세션의 「모든 기기 로그아웃」은 `/sessions/revoke`에 닿지 않는다 — 전체 로그아웃을 명시한 요청은 401을 받아 다시 로그인한 뒤 해야 하고, 생략 요청은 204로 끝난다(다른 기기는 그대로다 — C36 · 〔W17〕).
- **DB 시점 복구** 뒤에는 복구 시점 이후의 폐기 행이 사라지고 다음 재적용이 하한을 낮춘다(30일 상한 · 런북: `SESSION_ENCRYPTION_KEY` 교체).

### 재적용 · Celery 실행 경로

- **재적용의 실행 경로가 좁다.** 내장 beat → 브로커(같은 Dragonfly) → solo 워커 하나다. 복구 시간의 상한은 구조상 「다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속」이고 계약도 그렇게 적었다(〔W18 · Z1〕). solo 워커는 받은 순서대로 돌고 그동안의 tick은 `expires` 30으로 버려진다 — 느린 Authentik에서 위임이 여럿 먼저 쌓이면 그 마감들이 더해진다(추론 · 유실 때는 큐도 함께 비워져 드물다 · 재검토 RB-6). 승인 문면(spec:205 「최대 30 s」 · tasks:224 「≤ 30 s 안에」)과 다르다 — 〔편차 29〕. 재접속 몫의 실측이 VD-T073-15다 — (a) 연결을 유지한 유실은 ia-40이 60 s 안의 복귀를 단언하고, (b) 프로세스 재기동은 로컬 참고값만 남긴다(운영 토폴로지 값은 T085). (a)가 실패하면 재적용 루프를 beat 프로세스 타이머로 옮기는 결정이 남는다(〔Y16 · W25〕). (a)의 복귀 단언은 실패하면 뺄 수 있지만, ia-40의 tick 단언(`FLUSHALL` 앞 — 30 s tick이 beat → 브로커 → 워커로 실제로 도는가)은 빼지 않는다(〔Z16〕).
- **내장 beat 자식이 죽으면 워커는 살고 beat는 다시 뜨지 않는다.** 무소식 경보가 유일한 탐지다(〔Y24〕). beat가 멈추면 유실과 겹치지 않아도 커밋 뒤 쓰기가 실패한 폐기의 복구 · 일 1회 대조 · purge가 멈춘다(〔W18〕). T075가 celery liveness를 채택하지 않으면 T098 전에는 beat 사망 탐지가 0이다(§7 T075 · 〔W16〕).
- **일 1회 작업은 pod 교체에 조용히 빠질 수 있다.** beat 스케줄 파일이 `/tmp` emptyDir라 pod가 바뀌면(롤아웃 · Reloader · 축출) 스케줄 파일이 새로 생기고, 실행 시각(03:27 · 03:37 UTC)을 걸친 교체는 그날의 purge · 대조를 실패 줄 없이 건너뛴다. 같은 pod 안의 컨테이너 재시작은 파일이 남아 기동 직후 따라잡는다(소스 판독 — 사실 ⑧ · 〔Z11〕). 대조는 창이 72 h라 이틀까지는 다음 실행이 메우고, 탐지는 `authentik.reconcile_done` 48 h 무소식 경보다(〔W19〕).
- **브로커 재기동 뒤 첫 위임 1건이 빠질 수 있다.** `retry_policy` `max_retries` 0이면 풀에 남은 죽은 연결에서 첫 enqueue가 재접속 없이 실패할 수 있다(소스 판독 — VD-T073-6 ④가 0과 1을 재고 값은 컨트롤러가 정한다 · 기본은 0 유지 · 〔W25〕). SET `unreachable` 건너뛰기로도 빠진다 — `max_retries`와 무관하다(〔Z15〕): 운영은 브로커와 거부 목록이 같은 Dragonfly라, 재기동 뒤 첫 사용자 단위 폐기는 쓰기 클라이언트의 죽은 소켓에서 SET이 `unreachable`이 되어 D12 ④가 enqueue를 건너뛸 수 있다(추론 — VD-T073-6 ⑤가 그 `denylist` · `delegate` 값을 기록한다). 빠지는 것은 그 폐기의 Authentik 세션 삭제뿐이고 거부 목록과 하한은 유지된다(SET이 실패한 폐기는 30 s 재적용이 되살린다).
- **`beat_init` 수신 시점(fork된 내장 beat)과 실제 워커 동작은 추론이다**(VD-T073-5 · ia-40이 CI에서 본다).
- **신선도 키는 명령 단위 실패를 가리지 못한다.** 「Dragonfly까지 닿았다」만 말한다 — NOPERM은 `failed` 건수와 WARNING이 알린다. 키의 존재도 「최근 300 s 안에 한 번 닿았다」일 뿐이라, 재적용이 죽은 직후 300 s 동안은 살아 있는 것처럼 보인다 — 사람이 판단할 때는 값이 전진하는지 본다(D14 · 〔Z10〕).
- **「조회 뒤 SET」 경합이 남는다.** 요청 경로에서 자기 행 값으로 덮는 경합(역순 커밋 · 과거 `nbf` 웹훅)은 커밋 뒤 최댓값 조회로 없앴다(〔Y22〕). 조회한 뒤 SET하는 사이에 커밋된 더 큰 `nbf`를 낡은 조회 값으로 덮는 경합은 재적용과 콜백 사이, 콜백과 콜백 사이에 남는다(창은 ms · 다음 재적용이 되돌린다 — 〔W18〕).
- **재적용이 읽는 범위가 330초치에서 30일치(사용자 단위 행)로 늘었다.** 사용자가 `logout_all`을 되풀이하면 행이 는다(키는 sub당 하나). SP-1 규모에서는 무시할 수준으로 본다(추론 — VD-T073-13 · T097).
- **ia-40은 템플릿 실제 워커 시험의 도우미 이름에 기댄다.** 재생성으로 이름이 바뀌면 수집에서 깨진다(조용히 통과하지 않는다).

### 외부 동작 · 권한 · 운영

- **Authentik 동작의 근거는 전부 소스 판독이다**(2026.8.0 · 2026.8.5 — 〔V1–V17〕). 세션 · events · 권한의 조용한 실패 · 회전 뒤 만료 · ID 토큰 `iat` · 교환 토큰의 `sid` 부재를 라이브로 본 적이 없다(VD-T081-1–5 · T083).
- **`view_event`는 감사 이벤트 전체 읽기다.** 주면 pod 장기 토큰이 로그인 IP · 사용자명 · 관리자 행위를 읽는다(dev · prod가 한 인스턴스다). 주지 않으면 유실 웹훅이 기록되지 않는다(위 「기록되지 못한 폐기」). UD-2 본체가 정한다.
- **대조의 쪽 상한**: 90일치 logout 이벤트가 5,000건을 넘으면 `reconcile_truncated`가 매일 난다(정렬에 기대어 멈추지 않기 때문이다 — SP-1 규모 밖).
- **자리값 skip**: 실값 교체를 잊어도 기능이 조용히 멈춘다. WARNING 로그 `authentik.calls_disabled`와 T085 끝 상태 단언이 지킨다.
- **Dragonfly ACL `+@all`**이 키 패턴 밖 명령(`FLUSHALL` · `ACL SETUSER` · `CONFIG SET`)을 pod 사용자에게도 여는 것으로 읽힌다(추론 — T073 안에서 잰다: VD-T073-16 · 조각 ② · 〔W33〕). 허용이면 pod 사용자의 `FLUSHALL` 한 번이 30일치 하한을 지운다(재적용이 되살린다). 규칙은 T073에서 바꾸지 않는다.
- **tester의 m2m 직접 호출은 pod에서 403이다.** pod는 Access `common_name`이 web-bff Client ID인 호출만 받는다 — 「같은 access 토큰 401」의 측정 경로가 아직 없다(〔편차 27〕 · UD-7 (나)의 「BFF 경유 한정」과 함께 T079 전에 정한다 · 〔W1〕).
- **대조의 「권한 없음」은 조용한 0건일 수 있다.** 서비스 계정의 형에 따라 권한이 없는 events 조회가 오류 없는 빈 목록으로 오면 대조는 `seen=0`으로 끝나 「로그아웃이 없었다」와 구별되지 않는다(소스 판독 — 실측 VD-T081-2 · T085 보고 항목 「prod 대조의 `seen`이 0이 아닌 날이 있는가」 · 〔W2〕). 사용자 조회만 전부 404인 경우는 WARNING `authentik.reconcile_skipped reason=user_lookup`이 드러낸다. 「오류 없는 빈 목록」 꼴은 T073 안에서는 드러낼 수단이 없다 — 탐지 후보 둘을 T098에 인계했다(prod `reconcile_done`의 `seen` 0이 여러 날 이어짐 · 자기 점검 `authentik.reconcile_blind` — 뒤의 것은 코드 변경이라 converge 과제 후보 · 〔Z13〕). 이벤트 조회의 그 밖 실패(404 등)는 조용히 끝나지 않고 `authentik.reconcile_failed`를 남긴다(D17).
- **`session_revocations_total`은 web 프로세스 지표다.** 워커의 백필과 관리 명령의 폐기는 지표에 없다(로그로 센다 — 〔Y24〕).
- **클러스터 안 Authentik · OpenFGA 호출은 평문 HTTP다**(계약 고정). 토큰과 preshared 키의 전송 보호는 노드 간 암호화에 기댄다(〔Y24〕).
- **다중 멤버십의 결정적 선택은 SP-1 가정 위에서만 맞다.** SP-2 다테넌트에서 다시 정해야 한다.

### 빌드 · 유지보수

- **UUID7은 PG 18 전용이다.** 템플릿을 일반화할 때 주의한다(VD-T073-3).
- **Ninja 1.7.0 세부는 VD다.** 조사는 1.7.3 소스를 읽었다(t072 ⑨ · VD-T073-4). 반환 규칙은 사람이 지킨다(검사 도구가 없다 — 리뷰 체크리스트).
- **웹훅 pk 꼴**: UUID로 읽히는 꼴은 정규형이 한 행으로 모은다. UUID가 아닌 꼴이 두 경로에서 다르면 두 행으로 남는다(VD-T081-1).
- **CI arm64 시간은 실측이 없다.** 기동 하위 프로세스 · api-19의 위임 대기 · ia-40의 실제 워커가 시간을 늘린다(VD-T073-10 · CI).
- **재생성은 손 작업이다.** 템플릿 소유 15파일의 손 수정 목록과 표식에 기댄다. 3-way 절차는 실측 전이다(VD-T073-11 — 조각 ⑥ 끝 뒤의 컨트롤러 단계에서 잰다 · 〔W23〕).
- **ia 시험은 구현 조각마다 그 조각의 빌더가 쓴다**(〔W24〕). T066과 달리 오라클 참조 구현이 없다 — 시험의 결함은 조각 리뷰의 렌즈 A(시험 줄 · 변이 줄과의 대조 · 빨강 증거)와 변이 확인이 잡고, 뒤 조각이 앞 조각의 시험을 고치면 보고와 bn에 남긴다.
- **③-b1 구현의 일부 갈래는 ③-b2의 시험이 처음 본다**(〔Z20〕). ia 시험을 「지나는 경로가 다 있는 첫 조각」에 두므로, revoke와 웹훅을 다 보는 묶음(ia-5 · 11 · 17 · 19 · 27 · 39)과 웹훅으로 만드는 사례(ia-7 · 31 · 34)가 ③-b2에 있다. 그 사이 ③-b1을 지키는 것은 T066 api-10–19 · 51과 ia-4 · 28이고, 관문의 명령 상한 · 콜백의 위임 건너뛰기 · 쓰기의 0.2 s · 최댓값 조회의 변이는 ③-b2의 ⓔ에서 확인된다(§5).
- **깨진 템플릿 소유 시험의 두 목록(D3)은 템플릿 시험 전부를 가르지 않는다.** 목록 밖의 시험이 깨지면 빌더는 고치지 않고 보고한다(〔W22〕).
- **「예상 꼴」 명령은 실행으로 확인하지 않았다**: `0001_initial` 생성 명령(§5 조각 ②) · 시험 Celery의 브로커 교체(VD-T073-6) · 수동 Dragonfly로 재는 브로커 재기동 사례(VD-T073-6 ④ · ⑤ — 〔Z15〕) · arm64 탐침(VD-T073-9) · 둘째 SQL의 계획 측정 SQL(VD-T073-13). 그 조각이 실제로 돈 꼴을 보고에 남긴다(〔W31〕).
- **고정 테넌트 UUID**를 설계 커밋에서 만든 뒤 T081 전에 바뀌면 claim · 그룹 · FGA가 어긋난다. 불변 규칙을 dm에 적는다(C21).
- **세션 절대 수명 30일은 승인 문면에 없는 새 동작이다.** 사용자가 결정했고(2026-11-12) report 편차 18로 옮긴다. 30일 넘는 세션을 재로그인 없이 이어야 하는 요구가 생기면 전용 표(D29 기각 1)를 다시 본다.

---

## 10. 반영표(2026-11-12 · 컨트롤러 결정)

결정의 정본은 `.superpowers/t073/decisions-controller.md`다. 본문에서 반영으로 바뀌거나 더해진 곳에는 〔Y n〕 · 〔E n〕 · 〔W n〕 · 〔Z n〕을 달았다. (가) · (나)의 「반영 자리」는 그 결정이 처음 반영된 자리이고, 그 가운데 (다)의 검토 반영이 다시 고친 곳은 (다)의 문면이 지금 모양이다(W가 Y · E와 다르면 W가 이긴다). (다)의 「요지」와 「반영 자리」도 그 라운드의 것이다 — 그 가운데 (라)의 재검토 반영이 다시 고친 곳은 (라)의 문면이 지금 모양이다(Z가 W와 다르면 Z가 이긴다: W14의 웹훅 「넘으면 400」 · W18 (c)의 상한 문면 · W19의 스케줄 파일 문장 · W21의 종료 코드 값 · W24의 조각 ③-b · W25의 VD 절차 · W31의 VD-T073-9 · 10 자리).

### (가) 비판 반영 Y1–Y24

비판 A(계약 · 완전성) 15건과 B(실패 양상 · 위생) 11건 + B의 덧붙인 관찰을 Y1–Y24로 묶었다. 같은 내용은 하나로 합쳤다(A-1 = B-2 · A-2 = B-1 · A-7 = B-5). 기각한 것은 없고, 여섯은 범위나 수단을 좁혀 닫았다(Y4 · Y8 · Y14 · Y17 · Y18 · Y22 — 판정 칸 · Y18은 유실 보완인 위임 재발행을 채택하지 않았다 · 〔W35〕).

| Y | 비판 ID | 심각도 | 판정 | 반영 자리 |
|---|---|---|---|---|
| Y1 | A-1 · B-2 교환 토큰에 `sid` 없음 — pod 경계는 `revoked:sid`를 집행하지 못한다 | high · medium | 채택(T073 코드는 그대로 — 한계를 문서 · 계약 · 시험으로 고정) | §1 A14 · G13 · 편차 16 · D9(한계 · ia-25) · C4 · C12 · C36 · C40 · C33 · VD-T081-3 · §7 T079 · T092 · §8 UD-7 · §9 |
| Y2 | A-2 · B-1 사용자 단위 폐기가 330 s 뒤 refresh로 되살아난다 | medium · high | 채택 — 구현은 UD-5 결과(D29) | §8 UD-5(경과 · 표) · D21(access 토큰 기준으로 좁힘) · D29 · §7 T085 · T114 · §9 |
| Y3 | A-3 조각 순서 | medium | 채택 | §5 순서(④ 외부 HTTP 클라이언트 → ⑤ Celery · 마지막 ⑦ openfga + seed) |
| Y4 | A-4 D24를 지키는 시험이 없다 | medium | 채택(ia-24의 셋째 항은 dl:42를 읽지 않고 같은 문자열을 시험 상수로 둔다 — 시험이 specs 경로에 기대지 않게) | D24(지키는 시험 · 「브로커 몫만」) · D26(pod 사용자 · ia-40) · ia-24 · VD-T073-5 · CI |
| Y5 | A-5 면제 상수의 기동 시험 | medium | 채택 | D6 ia-23 |
| Y6 | A-6 3-way 재생성이 실측 없이 정본이 된다 | medium | 채택(3-way는 실측 뒤에만 올린다) | D3 재생성 · C20 · C30 · C34 · VD-T073-11 |
| Y7 | A-7 · B-5 `view_event`와 권한 표 | medium · low | 채택 | §8 UD-2(표 재구성 · 하위 결정) · 사실 ⑭ · C26 · C27(권한별 표) · D17(권한과 dev) |
| Y8 | A-8 표식 예외 · 지켜지지 않는 손 수정 | low | 채택(env.example 단언은 템플릿에 없는 네 이름을 빼고 건다) | D3(표식 예외 · 목록 · 지키는 시험) · D23 ia-18 · D26 배선 |
| Y9 | A-9 ninja 반환 규칙의 정본 자리 | low | 채택 | D28 · C47 · C34 (나) · §8 UD-6 · 편차 10 |
| Y10 | A-10 변이 · 시험 판별력 넷 | low | 채택 | D4 변이 · D13 변이 · D25 ia-19 · D14 반환 계약 · ia-10 · D12(`event_already_recorded`) |
| Y11 | A-11 검증 명령 셋 | low | 채택 | §5 공통 환경(binfmt) · 조각 ⑥ kubeconform 명령 · D2 5단계 |
| Y12 | A-12 덮임 표 · 덮이지 않은 조사 발견 | low | 채택 | VD-T083-1 · 덮임 표 tests Q6 · G14 · VD-T082-1 · D2(description) · D10 3단계 · C5 · ia-8 · D16 enqueue 꼴 · VD-T073-6 |
| Y13 | A-13 인계 · 계약 보정 누락 | low | 채택 | §7 T082 · T085 · T116 · C36 · D1 · D23(README의 pod 소유 파일 목록) |
| Y14 | A-14 시험 도우미 배선 | low | 채택(가짜 초기화 · FLUSHALL · DNS 가드는 autouse가 아니라 ia 모듈 머리의 `usefixtures` 하나로 건다 — 플러그인의 autouse는 T066 · 템플릿 시험에도 걸린다) | D26 배선 · 픽스처 · D3 ⑩ |
| Y15 | A-15 VD 기준 · 잔 문면 | low | 채택 | §6(표 꼴) · §4(소속 표기 — C34 · C35는 조각 ⓪) · D12 관문(301) · C24 (나) · C37 · D26 정합 목록(test_api.py:14) |
| Y16 | B-3 재적용 실행 경로 | medium | 채택 | D16(시도 마감 20 s · `expires`) · D17(마감 120 s · 캐시 · 첫 일시 오류에서 멈춤) · D20(`Deadline`) · D15(beat `expires`) · D14(반환 · 성공 줄) · VD-T073-5 · 15 · ia-40 · §7 T075 · T098 |
| Y17 | B-4 대조가 서버 필터를 믿는다 | medium | 채택(멈춤 규칙은 「정렬에 기대지 않고 끝까지 본다」로 정했다) | D17(재확인 · 72 h · 쪽 상한 WARNING) · D12 정규형 · D10 · ia-13 · ia-8 · C5 · C7 |
| Y18 | B-6 위임 enqueue | low | 채택 — 유실 보완(위임 재발행)은 채택하지 않았다(E12) | D12 ④ · D16 위임 조건 · ia-11 · VD-T073-6 · §9 |
| Y19 | B-7 seed 강등 · 오타 교착 | low | 채택 | D19(3 · 4 · 6단계 · 출력) · C22 · ia-15 · ia-16 |
| Y20 | B-8 외부 호출 · 작업 위생 | low | 채택 | D20 · D16(쪽 상한 · 경로 성분 · argsrepr) · D6(URL 꼴 교차 규칙) · D15(반환값) · ia-22 · C8 |
| Y21 | B-9 입력 문자 집합 · 길이 | low | 채택 | D8 · D9 · D10 · D19 · D30(문자 규칙) · D12 관문 · D6(32자) · C3 · C4 · C5 · C8 · ia-1 · 4 · 6 · 23 |
| Y22 | B-10 셋째 경합 | low | 채택(`sid` 키에는 조회를 두지 않는다 — 값이 상수다) | D13 · ia-31 · C12 · C13 · §9 |
| Y23 | B-11 관리자 폐기를 부를 길 · 런북 · 경보 | low | 채택 | D30 · C38 · 편차 17 · §7 T085 · T098 · T114 · D25 경보 기준 |
| Y24 | B extra 관찰 다섯 | — | 기재 | D24(남는 것) · D25(지표) · D15 · D16(스냅숏) · D20(평문 HTTP) · C10 · VD-T097-1 · §9 |

### (나) 분석 반영 E1–E14

폐기 최종성 분석(`.superpowers/t073/epoch/`)의 판정 · 반박 · 사실 검증과 사용자 결정 둘을 E1–E14로 묶었다. 바탕 설계는 `epoch-design-floor-ttl.md`이고, 결정과 다른 곳은 결정을 따랐다.

| E | 출처(반박 · 판정 · 사실 검증) | 반영 자리 |
|---|---|---|
| E1 세션 하한(파생 키) | 사용자 결정 UD-5 · 바탕 설계 1–3절 · 〔R3 · R5 · R10 · R16 · R18〕 | D29(정본 · 값 · 키 · 상수) · D13(쓰기) · D14(둘째 SQL) · D4(인덱스) · C3 · C4 · C5 · C7 · C12 · C13 · C24 · C39–C41 |
| E2 세션 절대 수명 | 반박 〔ATK-6〕 · 놓친 대안 1 · 컨트롤러 확인 1 · 2 | D29(판정식 · 최종성 논증 · 불변식 1) · D8 4단계 · ia-36 · C3 · C39 · C45 · 편차 18 |
| E3 미래 `iat` | 컨트롤러 결정(하한 비교가 `iat`에 기댄다) | D8 4단계 ④ · D29(경계 동작) · ia-37 · C3 · §9 |
| E4 BFF 계약 보정 | 반박 〔ATK-4〕 · 필수 조건 2 · 3 · 〔R12 · R13 · R14 · V2 · V3〕 | C36 · C43–C45 · D8(`iat`의 뜻) · §7 T089 · T092 |
| E5 재적용 생존 신호 | 반박 〔ATK-2〕 · 필수 조건 5 · 판정 정정 3 | D14(신선도 키 · 반환 계약 · 성공 줄) · D25 · ia-38 · C7 · C13 · C39 · §7 T075 · T098 |
| E6 nbf 상한 가드 | 반박 〔ATK-9〕 · 필수 조건 6 | D12 관문(시험 환경 주의 포함) · D9 · D10 · D17 · D30 · ia-39 · C4 · C5 · C24 · §5 공통 환경(컨테이너 시계) · §7 T114 · §9 |
| E7 웹훅 `nbf` 누락 | 판정 남는 위험 6 · 반박 〔ATK-8〕 | D10 4단계 · D21 · ia-8 · C5 (나) · C27 (라) · VD-T081-1 |
| E8 일 1회 대조 확정 | 사용자 결정 UD-2 하위 · 반박 〔ATK-5 · ATK-7〕 | D17 · D21 · C7 (나) · C27 · §7 T081 · §8 UD-2 |
| E9 SSO 재진입 | 반박 〔ATK-3〕 · 판정 정정 2 · 남는 위험 8 | D29(남는 열림) · C39 · C45 (마) · §8 UD-8 · §7 T114 · §9 |
| E10 시계 | 반박 〔ATK-1 · ATK-8〕 · 필수 조건 4 | D29(경계 동작 · 불변식 10) · VD-T081-5 · §7 T079 · T085 · §9 |
| E11 ADR | 반박 필수 조건 11 | §7 converge · 편차 26 |
| E12 위임 재발행 불채택 | Y18 · 비판 B-6 (3) | D16(enqueue 실패) · §9 |
| E13 `sid` 단위 | 바탕 설계 5절 (e) · 판정 남는 위험 9 | D13(`sid` 행) · D29(남는 열림) · §8 UD-7 · §9 |
| E14 인계 · 편차 모음 | 반박 필수 조건 5 · 8 · 10–13 | §7(T075 · T081 · T085 · T089 · T092 · T097 · T098 · T114 · converge) · §1 편차 표 |

- 바탕 설계와 다르게 쓴 곳
  - 「refresh 27일」 보강 · gitops refresh 수명 정적 검사 · 불변식 4(수명 결합) · 「기간 한정」 · 「백필 꼬리」 · 「유실 창 뒤 부활」 서술은 「하한 수명 ≥ 세션 최대 나이」 불변식으로 대체했다(E2).
  - 요청 경로의 `revoked:*` TTL은 DB 시계가 아니라 프로세스 시계로 잰다(D13 — T066의 TTL 창이 시계 차에 흔들리지 않게). 하한 TTL은 결정대로 DB 시계다.
  - 재적용의 반환값 이름은 `{rows, keys, floors, skipped, failed}`로 하나로 맞췄다(Y10 · E5).
- 분석이 견딘다고 본 것(그대로 둔다): T066 76개에 바꿀 단언이 없다(〔ATK-10〕 — 원문 대조 · 실측은 마지막 조각) · Authentik 사실(〔ATK-11〕 — 소스 판독 · 실측은 T081) · 값을 시각으로 두는 방향 · 카운터형과 Authentik 속성형의 기각.
- 검토 반영이 다시 고친 곳: E5의 신선도 키 수명(120 s → 300 s — W16) · E6의 기준 시계(모든 경로의 DB 시계 → 경로별 — W14). 값 301과 「미래 값은 쓰기 전에 막는다」는 그대로다.
- 재검토 반영이 다시 고친 곳: E6의 웹훅 갈래 — 상한(`⌊created⌋ + 1`)을 넘는 본문 `nbf`를 거부하지 않고 그 값으로 낮춰 기록한다(Z8). 「미래 값이 하한으로 들어가지 않는다」는 그대로다. E5의 신선도 키는 그대로이고, 사람이 판단할 때 존재가 아니라 값의 전진을 본다는 기준이 붙었다(Z10).

### (다) 검토 반영 W1–W36

최종 설계 워크플로의 검토 3렌즈(`.superpowers/t073/reviews/final-reviews.json` — A 결정 반영 · 일관성 12건 / B 보안 · 실패 양상 10건 / C 빌드 가능성 · 시험 · 조각 14건 · 셋 다 approve_with_fixes · high 0 · medium 6 · low 30)와 설계 작성자 · 계약 반영 역할의 우려를 W1–W36으로 묶었다. 발견 36건(12 + 10 + 14)은 모두 어느 W에 닿는다(A-2 = B-10 → W2 · A-5 = C-9 → W5). 기각한 것은 없고, 컨트롤러가 「검토에서 다시 본다」고 둔 셋(E3 · E5 (b) · E6)은 W15 · W16 · W14로 다시 판정했다. Y · E와 다른 곳은 W를 따랐다 — E5의 `EX 120`(W16) · E6의 기준 시계(W14) · Y23의 `--sid`(W13) · Y6 · Y16 ③의 VD 자리와 절차(W23 · W25) · 조각 ①의 범위(W24).

| W | 검토 ID(심각도) | 요지 | 반영 자리 |
|---|---|---|---|
| W1 | A-1(medium) | 「tester-m2m 직접 호출은 pod에서 403」과 양립하지 않는 고정 문면(tasks:212 · 224)을 편차와 인계에 올린다 — T073 코드 영향 0 | §1 편차 표 행 27 · D30(왜 T073에 넣는가) · §7 T079 · T085 · §9 「외부 동작 · 권한 · 운영」 |
| W2 | A-2 · B-10(low) | 일 1회 대조에서 「권한이 없을 때의 응답 꼴」을 단정하지 않는다 — 세 꼴(401 · 403 / 오류 없는 빈 목록 / 사용자 조회 404) 모두에서 안전하게 · 조용한 0건을 드러내는 경고 한 줄 | 사실 ⑭ · D17(5 · 8단계 · 실패 · 권한과 dev · ia-13 · 변이) · D25(reason `user_lookup` · `count`) · C7 (나) · C27 (마) · VD-T081-2 · §7 T081 · T085 · §8 UD-2 · §9 |
| W3 | A-3(low) | Authentik 동작을 단정한 계약 문장 여섯에 「소스 판독 — 실측 T081」 표시 | C4 (다) · C39 (다) · C5 (가) · C27 (가) · (라) · C43 (가) · VD-T081-1 · 2 · 4 · §7 T081 |
| W4 | A-4(low) | `/session/check` 응답의 `nbf` 문장을 ia-29 넷째 사례와 맞춘다 | D8 5단계 · C3 |
| W5 | A-5 · C-9(low) | OpenFGA store id는 UUID · 정수 꼴이 아니다 — 호출 시점에 `[A-Za-z0-9_-]{1,64}`를 확인(conf 교차 규칙으로는 올리지 않는다) | D6(`OPENFGA_STORE_ID` 줄) · D20(URL 조립) · D19(ia-15 · 변이) |
| W6 | A-6(low) | §4 「확정 문면」을 실제 문서와 글자로 맞춘다(C24 (라)는 문서 쪽을 되돌린다) | C6 · C44 (라) · C24 (바) · C24 (라) |
| W7 | A-7(low) | C16의 완료형 날짜 문구 → 「T073 조각 ⓪(생성 커밋)에서 반영」 | C16 |
| W8 | A-8(low) | 편차 표의 인용 줄 정정(행 15 · 23)과 새 행 28(dev의 reconcile 「쓰기 호출 비활성」 해석 변경) | §1 편차 표 행 15 · 23 · 28 · D17(권한과 dev) |
| W9 | A-9(low) | bff 프록시 행: inactive 처리에 RFC 7009 폐기 · 응답 칸에 401 · 옛 문장의 `iat` = 쿠키 `issued_at` | C44 (마) · (사) · (아) · §7 T089 |
| W10 | A-10(low) | api계약의 보정한 칸에 남은 옛 문장 넷을 고친다(응답 칸에 500은 더하지 않는다) | C4 (마) · C4 머리 줄 · C5 (다) · C8 (바) |
| W11 | A-11(low) | UD-4의 질문 시점은 「T081 전」이다 | §8 현재 상태 표 · UD-4 소제목 |
| W12 | A-12(low) | 인용 줄 번호는 보정 전(HEAD `3626d16`) 번호다 | 「약어」 절 끝 · §4 머리말 |
| W13 | B-1(medium) | 관리 명령에서 `--sid`를 뺀다 — SP-1 `revoke_sessions`는 사용자 단위만 · 관리자 갈래의 `sid` 폐기에는 refresh 폐기가 따르지 않는다 | §1 A12 · 편차 표 행 17 · D9(관리자 갈래의 `sid` 폐기) · D16(위임 조건) · D30(사용자 단위만 · 명령 · 효과 · 한계 · ia-26 · 변이) · D26(ia 목록 26) · C38 · C4 (다) · C24 (라) · §7 T114 · §9 |
| W14 | B-2(low · E6 재판정) | `nbf` 상한의 기준 시계를 경로별로 가른다 — 웹훅 `⌊created⌋ + 1` · 대조는 구성상 · 관리 명령만 DB 시계 + 301 s · `/sessions/revoke`는 비교 없음(웹훅에서 상한을 넘는 값의 처리는 Z8이 고쳤다 — (라)) | D9 8단계 · D10(4 · 7단계 · 시험 · 변이) · D12(관문 · 호출자의 처리 · 시험 환경 주의 · ia-39 · 변이) · D17(3 · 7단계) · D25(reason 삭제) · D26(이음매 · ia 목록 39) · D29(불변식 5 · 실패 표 「시계 어긋남」) · D30 4단계 · C4 (다) · C5 (가) · C24 (가) · C38 · §5(컨테이너 시계 · 그때의 조각 ③-b — 지금의 ③-b2) · §9 |
| W15 | B-3(low · E3 재판정) | 미래 `iat` → inactive · 60 s 유지 — 도달 조건 둘을 문면에 적고 경보에 올린다 | D8 4단계 ④ · D29 경계 동작 · C3 · D25 경보 기준 · §7 T098 · §9 「시계」 |
| W16 | B-4(low · E5 (b) 재판정) | 신선도 키는 채택하되 수명을 `EX 300`으로 — T075 liveness를 결정 후보로 | D14(신선도 키 · ia-38) · C7 (가) · C13 (가) · C15 · C39 (나) · C24 (다) · §7 T075 · T098 · §9 |
| W17 | B-5(low) | logout + inactive: `/sessions/revoke`는 부르지 않되 `all_devices: true`를 명시한 요청은 401 | C36 (가) · (나) · C45 (다) · §7 T089 · §8 UD-7 · §9 |
| W18 | B-6(low) | 문면 넷 — (a) beat 정지는 평시에도 열림 (b) Dragonfly 장애에서 `/sessions/revoke`는 기록 0 (c) 복구 상한 = 30 s + 실행 중 작업의 마감 + 워커 재접속(이 문면은 Z1이 다시 고쳤다 — (라)) (d) 「조회 뒤 SET」 경합은 남는다 | D29(실패 표 세 행 · 불변식 8) · D13 기각 · C13 (나) · C48 · C24 (자) · §6 VD-T073-15 · §7 T085 · §9 |
| W19 | B-7(low) | T098 경보 기준 여섯을 더하고 T085 SIGKILL 사례를 스냅숏 뒤 폐기로 적는다(beat 스케줄 파일 문장은 Z11이 고쳤다 — (라)) | 사실 ⑧(beat 스케줄 파일) · D25 경보 기준 · §7 T098 · T085 · §9 |
| W20 | B-8(low) | T114 인계 — 비활성화 → `revoke_sessions` 순서 · 재활성화 전 확인 · 하한 내리기 순서 · 키 교체는 이중 키 창 없이 | §7 T114 · §9(잘못 오른 하한) |
| W21 | B-9(low) | `revoke_sessions`가 커밋 뒤 결과를 출력에 싣는다 — `denylist` · `delegate` · `PARTIAL` · 그때의 종료 코드 값 2(Z9가 3으로 고쳤다 — (라)) | D12(`Recorded.after` · 6단계 ① ④ · 변이) · D30(5단계 · 한계 · ia-26 · 변이) · C38 · §7 T114 |
| W22 | C-1(medium) | Celery 앱은 콜백의 위임 단계 안에서 가져온다 · 깨진 템플릿 소유 시험의 처리를 기본값 단언과 불변식 단언으로 가른다 | 사실 ⑧ · D3(두 갈래 목록) · D12 6단계 ④ · D16(enqueue 꼴 · ia-11 · 변이) · §5(공통 환경 · 조각 ③) · §7 컨트롤러 · §9 |
| W23 | C-2(medium · Y6 정정) | VD-T073-11을 조각 ⓪에서 빼 조각 ⑥ 끝 뒤의 컨트롤러 단계로 옮긴다(저장소 밖 임시 복제본) | D3 재생성 · §5(조각 ⓪ · 「⑥ 끝 뒤 — 컨트롤러 단계」) · §6 VD-T073-11 · §7 컨트롤러 · §9 |
| W24 | C-3(medium) | 조각 ①을 토대만으로 줄이고 ia 시험은 구현 조각마다 그 첫 단계에서 쓴다 · 조각 ⑤를 ⑤-a · ⑤-b로 가른다 · 배정을 다시 센다(쓰기 조각은 Z20이 ③-b1 · ③-b2로 다시 갈랐다 — (라)) | D26(구현 모듈은 시험 함수 안에서) · D3 · D29(조각 이름) · §5(공통 환경의 차례 · 조각 ① · ②–⑦의 차례 · ⑤-a · ⑤-b · 배정의 합계 · 리뷰 렌즈 A) · §6 조각 칸 · §9 |
| W25 | C-4(medium · Y16 ③ · Y18 정정) | VD-T073-6 · 15의 사례 · 절차 · 합격선을 다시 적는다 — 6은 닫힌 포트만 합격선 · 15는 (a) ia-40 단언 (b) 참고값(6 ④의 절차와 15 (b)의 조회 키 · ia-40의 tick 단언은 Z15 · Z16이 더했다 — (라)) | 사실 ⑧ · D16(`retry_policy`) · D26(ia-40 유실 뒤 복구) · C9 (나) · §6 VD-T073-6 · 15(표 · 절차) · §7 T075 · 컨트롤러 · §9 |
| W26 | C-5(low) | 로그 꼴 고정 — structlog 키-값 · 필드 = JSON 최상위 키 · 마스킹 대상 이름을 필드에 쓰지 않는다 | D25(로그 꼴 · 필드 이름과 마스킹) · §7 T098 |
| W27 | C-6(low) | `_ia_fakes.py`는 둘이다 — `FakeAuthentik` 하위 클래스와 독립 원시 HTTP 서버 | D26(`_ia_fakes.py` · `test_ia_fakes.py`) · D20(ia-22) · §5 조각 ① |
| W28 | C-7(low) | 조각 ④에 `authentik.py` 메서드 단위 시험 ia-41 | D20(시험 · 변이) · D26(수 · ia 목록 41) · §5 조각 ④ · 배정의 합계 |
| W29 | C-8(low) | 「이음매」 표 — 호출 지점은 모듈 속성 · 0회 앞에 1회 · 상수 이름 다섯 · 반환 꼴 셋 | D26(이음매 표 · 규칙) · D8 3단계 · D12(`db_now_epoch`) · D13(반환) · D16 · D17(상수 이름) · D20(반환 · 상수) · D29(ia-30 (a)) |
| W30 | C-10(low) | 세션 DELETE의 204와 404를 `deleted` · `gone`으로 갈라 센다 | D16(5 · 6단계 · ia-12 · 변이) · D20(`delete_session`) · D25(필드 `gone`) · C7 (라) · VD-T083-1 |
| W31 | C-11(low) | 빠진 명령 꼴 — binfmt 전문 · `0001_initial` 생성 명령 · 「77 packages」 기준 · VD-T073-8 · 9 · 13의 명령(VD-T073-9 · 10의 자리는 Z14가 조각 ⑦ 닫기로 옮겼다 — (라)) | §5(공통 환경 binfmt · 조각 ②) · §6(VD-T073-1 · 절차와 실행 명령) · §9 |
| W32 | C-12(low · 컨트롤러 규칙) | `tests/run-all.ps1` 전체는 어느 조각에서도 돌리지 않는다 — 건드리는 ps1 하네스를 이름으로 | D27(ps1) · §5(공통 환경 · 조각 ⑥ · 조각 ⑦ 끝 조건) |
| W33 | C-13(low) | pod 사용자의 `+@all` 범위를 T073 안에서 잰다(VD-T073-16) | D24(남는 것) · §5 조각 ② · §6(VD-T073-16 · VD-T097-1) · §7 T075 · T097 · §9 |
| W34 | C-14(low) | 「변이」 줄이 없던 결정 다섯에 줄을 더한다 | D11 · D15 · D18 · D22 · D23 · D19(ia-15의 자리값 사례 · 변이) |
| W35 | (부록 · 반영 역할의 우려) | 작은 것들 — 동시 실행 금지의 범위 · T075 URL 꼴 · `git restore`는 조각 ⓪만 · UD-7 · UD-8 문구 · §10 머리의 수 · 계약 · quickstart의 남은 문장 · 표식 횟수 | §5 공통 환경 · §7 T075 · D2 5단계 · §8 UD-7 (나) · UD-8 (가) · §9(`sid` 단위 폐기) · §10 (가) 머리 · §4 머리말(표식 횟수) · C39 (라) · C49 · C22 (나) · C33 (다) · (라) |
| W36 | — | 이 표 · §8 「현재 상태」의 수(확정 3 · 대기 6)는 그대로다(새 사용자 결정 없음) | §10 (다) · 머리의 경과와 수 |

- 계약 · 규칙 문서에 다시 반영할 것은 §4에서 설명 줄에 W 표기가 있는 항목이다(W2 · W3 · W4 · W7 · W9 · W10 · W13 · W14 · W15 · W16 · W17 · W18 · W21 · W25 · W30 · W35 — W6은 C24 (라) 하나만 문서를 고치고 나머지는 이 문서 쪽을 맞췄다).
- 검토가 발견으로 올리지 않은 관찰 가운데 W35로 반영한 것: 조각의 리뷰 렌즈와 스위트의 동시 실행 · T075 인계의 URL 꼴 규칙 · `git restore`의 범위 · UD-7 (나) · UD-8 (가)의 문구.

### (라) 재검토 반영 Z1–Z22

검토 반영 워크플로 `wf_7bdc5270-c6d`의 재검토 2렌즈(`.superpowers/t073/reviews/fix1/final-reviews.json` — A 반영 · 일관성 RA-1–6 / B 보안 · 실패 양상 RB-1–16 · 둘 다 approve_with_fixes · high 0 · medium 3 · low 19)와 반영 역할의 우려(`reviews/fix1/final-design.json` · `final-applied.json`)를 Z1–Z22로 묶었다. 발견 22건은 모두 어느 Z에 닿는다(RA-1 = RB-6 → Z1 · RA-3 = RB-1 → Z3 · RA-6과 RB-10의 시계 몫 → Z6 · RB-10의 나머지 → Z14). 기각한 것은 없다. 발견의 fix 문면은 참고이고 Z가 채택한 범위만 반영했다 — Z8은 검토자의 최소안(거부는 두고 경고를 더한다)이 아니라 대안(낮춰 기록)을 골랐고, Z13은 자기 점검 `reconcile_blind`를 T073에서 구현하지 않고 T098 후보로 인계하며, Z3은 관문의 심층 방어(선택안)를 넣지 않고 시험과 변이로 지킨다. W와 다른 곳은 Z를 따랐다 — W14의 웹훅 「넘으면 400」(Z8) · W21의 종료 코드(Z9) · W24의 조각 ③-b(Z20) · W25 · W31의 VD 자리와 절차(Z14 · Z15 · Z16) · W18 (c)의 상한 문면(Z1) · W19의 스케줄 파일 문장(Z11).

| Z | 재검토 ID(심각도) | 요지 | 반영 자리 |
|---|---|---|---|
| Z1 | RA-1 · RB-6(medium · W18 (c) 마무리) | 복구 시간 상한의 문면 = 「다음 tick(최대 30초) + 워커가 먼저 받은 작업들의 마감(대조 120 s · 위임 한 시도 20 s씩 — 평시 0–1건) + 워커 재접속」 · denylist §검증 T085 첫 문장의 「≤ 30 s 안에」를 고친다 · 승인 문면과 달라진 것을 편차 행 29로 올린다 | 머리(수 · 「Z가 W와 다른 곳」) · §1 편차 표 행 29 · 표 아래 주 · D29(불변식 3 · 실패 표 「Dragonfly 데이터 유실」 · 계약 줄) · C13 (나) · C48 · C42 (다) · C24 (자) · §6 VD-T073-15(실패 시 갈 곳) · §7 T085 · §9(「Dragonfly 유실 ~ 재적용 복귀」 · 「재적용의 실행 경로가 좁다」) |
| Z2 | RA-2(low) | quickstart US4 3번의 괄호에 「그 curl의 Access 헤더가 `tester-m2m`이면 403 `access_required`」를 적는다 | C33 (가) · §1 편차 표 행 27 「자리」 칸 · 표 아래 주 |
| Z3 | RA-3(low) · RB-1(medium) | 대조 경로의 미래 `created` 방어(「창 위쪽 끝」)에 시험과 변이를 둔다 — 관문에 `source == "reconcile"` 비교는 다시 넣지 않는다 | D17(7단계 · ia-13의 미래 이벤트 미끼와 경계 · 변이) · D12 관문(대조 줄) · D29 불변식 5 |
| Z4 | RA-4(low) | 편차 표 행 28의 인용 줄에서 tasks:190을 뺀다 | §1 편차 표 행 28 · 표 아래 주 |
| Z5 | RA-5(low) | §4 블록 셋의 끝 마침표를 지워 문서와 글자로 맞춘다(문서는 그대로) | C7 (다) · C37 · C26 (다) · §4 머리말 |
| Z6 | RA-6 · RB-10(low) | 「컨테이너 시계」 확인 시점 = ia-26이 든 모든 전체 실행 앞 | §5 공통 환경 「컨테이너 시계」 |
| Z7 | RB-2(medium) | 「빨강 확인」이 성립하지 않는 노드를 정리한다 — 부정 사례의 짝 · 명령 존재 단언 · ia-25를 ③-a로 · 구현 전에 초록인 노드의 처리 · api-29의 주 | D26(이음매 규칙 「부정 사례의 짝」) · D11(ia-21) · D30(ia-26) · D19(ia-15 · 16) · D9(ia-25) · §5(공통 환경 「구현 전에 초록인 노드」 · 조각 ②의 api-29 줄 · 조각 ③-a · 배정의 합계 표와 api-29의 주) |
| Z8 | RB-3(low · W14 정정) | 웹훅 본문 `nbf`가 `⌊created⌋ + 1`을 넘으면 거부하지 않고 그 값으로 낮춰 기록한다(202) + WARNING `webhook.nbf_clamped` · ia-39 (a)를 다시 쓴다 · 경보와 VD-T081-1 기준에 올린다 | 머리(「Z가 W와 다른 곳」) · D10(4단계 · 시험 · 변이) · D12(관문의 웹훅 줄 · ia-39 (a) · 변이) · D21(T081 매핑 규칙) · D25(표 · 경보 기준) · D26(ia 목록 39) · D29 불변식 5 · C5 (가) · C10 · C24 (가) · §6 VD-T081-1 · §7 T081 · T098 · §9(「오탐 폐기」 · 「잘못 오른 하한」) · §10 (나) 끝 줄 |
| Z9 | RB-4(low · W21 정정) | `PARTIAL`의 종료 코드를 3으로 한다(2는 argparse 사용법 오류와 겹친다) · 출력은 「`revoke_sessions:`로 시작하는 줄 하나」 · 판정은 그 줄로 한다 | D30(5단계 · ia-26) · C38 · §7 T114 |
| Z10 | RB-5(low) | 신선도 키의 존재는 「최근 300 s 안에 한 번 닿았다」일 뿐이다 — 사람은 값의 전진을 본다 · `PARTIAL` 문구는 그 폐기의 키 둘을 60 s 뒤 보게 한다 | D14(신선도 키 · 「키의 뜻」) · D30 5단계 · C38 · §6 VD-T066-3(통과 기준) · §7 T075(celery 생존 판정 · gitops README 조건) · T114 · §9(「신선도 키는 …」) · §10 (나) 끝 줄 |
| Z11 | RB-7(low · W19 정정) | beat 스케줄 파일: pod가 바뀌면 그날 실행을 건너뛰고, 같은 pod 안의 컨테이너 재시작은 기동 직후 따라잡는다 | 사실 ⑧ · D25 경보 기준 · §7 T098 · T075(liveness 후보) · §9(「일 1회 작업은 pod 교체에 …」) |
| Z12 | RB-8(low) | T098 경보 기준 둘 — prod `authentik.reconcile_skipped` 이틀 연속 · `authentik.revoke_done`의 `deleted` 0 · `gone` ≥ 1 되풀이 | D25 경보 기준 · §7 T098 |
| Z13 | RB-9(low) | 이벤트 조회의 그 밖 실패는 `authentik.reconcile_failed` 뒤 끝난다(건너뜀으로 접지 않는다) · 「오류 없는 빈 목록」의 탐지는 T098 후보 둘로 인계 | D17(실패 · ia-13) · §7 T098 · converge · §9(「대조의 권한 없음」) |
| Z14 | RB-10(low) | VD-T073-9 · 10을 조각 ⑦ 닫기로 옮긴다 · VD-T073-3의 통과 기준에서 「api-10 초록」을 뺀다 | §5(조각 ⑥ · 조각 ⑦ 끝 조건) · §6(VD-T073-3 · 9 · 10 표 · VD-T073-9 절차) |
| Z15 | RB-11(low) | VD-T073-6 ④의 절차(수동 Dragonfly · `send_task` 직접 호출) · 기록 사례 ⑤ · 「첫 위임 1건 누락」은 SET `unreachable`로도 난다 | §6(VD-T073-6 표 · 절차 ④ · ⑤) · §9(「브로커 재기동 뒤 첫 위임 1건」 · 「예상 꼴」) |
| Z16 | RB-12(low) | ia-40에 뺄 수 없는 tick 단언 · 뺄 수 있는 것은 `FLUSHALL` 뒤 복귀 단언뿐 · VD-T073-15 (b)는 신선도 키와 세션 하한 키로 잰다 | D26(ia-40 · ia 목록 40) · D14 시험 줄 · §6(VD-T073-15 표 · 절차 (a) · (b)) · §9(「재적용의 실행 경로가 좁다」) |
| Z17 | RB-13(low) | 「pod 시계가 뒤처지면 Access JWT `iat` 검사가 먼저 403」에 추론 표시 · T085 기록 항목 | D8 4단계 ④ · D29 경계 동작 · C3 · §7 T085 · §9 「시계」 |
| Z18 | RB-14(low) | VD-T073-16의 `CONFIG SET` 항목과 도는 자리 · VD-T073-11의 바꾸는 줄 둘 | §6(VD-T073-16 표 · 절차 · VD-T073-11 표 · 절차) · §5 「⑥ 끝 뒤 — 컨트롤러 단계」 |
| Z19 | RB-15(low) | T114 — 재활성화 전 확인에 연결된 소스 연동과 이메일 변경 · 하한 내리기는 `nbf`와 `expires_at`을 함께 | §7 T114(재활성화 전 확인 · 잘못 오른 하한 내리기) · §9(「잘못 오른 하한」) |
| Z20 | RB-16(low · W24 보강) | 조각 ③-b를 ③-b1(revoke · 기록 공통 · 쓰기 · 지표) · ③-b2(웹훅 · 관리 명령)로 가른다 · ia는 「지나는 경로가 다 있는 첫 조각」 · 배정을 다시 센다 | §5(조각 ③ · 「컨테이너 시계」 · 배정의 합계) · §6(VD-T073-4 · 6 · 7 · 12의 조각 칸 · VD-T073-6 절차) · D12(ia-39) · D16(enqueue 꼴) · D30(ia-26) · §9(「③-b1 구현의 일부 갈래」) |
| Z21 | (반영 역할의 우려) | 계약의 작은 것들 — 웹훅 서명 규약의 `nbf` 상한 한 구절 · 잇닿은 괄호 합침 · bff 「폐기 확인」의 낱말 · bff 타임아웃 표의 inactive 응답 · 「로그 한 줄」의 두 꼴 · 조각 ⑤-a의 ia-40 한 줄 | C5 (라) · C4 (마) · C5 (다)(바뀌는 것 없음) · C45 (사) · (바) · C27 (나) · C33 (다) · §5 조각 ⑤-a |
| Z22 | — | 머리의 수와 경과 줄 · 이 표 · 새 사용자 결정은 없다(§8 「현재 상태」의 확정 3 · 대기 6 그대로) | 머리(경과 · 수) · 약어 · §4 머리말 · §10 머리 · (다)의 행 일곱에 붙인 꼬리 · (라) |

- 계약 · 규칙 문서에 다시 반영할 것은 §4에서 설명 줄에 Z 표기가 있는 항목이다 — 문서를 고치는 것: C3(Z17) · C4 (마)(Z21) · C5 (가)(Z8) · C5 (라)(Z21) · C10(Z8) · C38(Z9 · Z10) · C13 (나)(Z1) · C48(Z1) · C42 (다)(Z1) · C45 (바) · (사)(Z21) · C24 (가)(Z8) · C24 (자)(Z1) · C27 (나)(Z21) · C33 (가)(Z2) · C33 (다)(Z21). 문서는 그대로이고 이 문서의 블록만 맞춘 것: C7 (다) · C37 · C26 (다)(Z5). 규칙 영어 정본과 미러 · pod-template.md · gitops-repo.md에는 이번 라운드에 바뀌는 항목이 없다.
- Z의 「바뀌는 자리」에 없지만 같은 규칙을 적은 문장이라 함께 고친 곳(설계자 판단)
  - 계약: C24 (가) — data-model §3 `nbf` 행의 「웹훅 본문 `nbf`는 … 이하여야 하고(넘으면 400)」(Z8). 그대로 두면 data-model과 api계약이 반대되는 말을 한다.
  - 이 문서 안: D21의 T081 매핑 규칙 · §7 T081의 「더 크면 pod가 거부한다」(Z8) · §6 VD-T066-3의 통과 기준 「신선도 키 존재」(Z10 — 사람이 판단하는 자리다).
- Z21이 든 두 행 가운데 웹훅 행에는 합칠 괄호가 없다 — W10이 넣은 괄호가 다른 괄호와 잇닿은 곳은 `/sessions/revoke` 행 하나다(C4 (마) · C5 (다)의 주).
- Z20의 배정 규칙을 그대로 따르면 ③-b1의 ia는 둘(ia-4 · 28)이고 ③-b2가 열넷이다 — revoke와 웹훅을 다 보는 묶음이 ③-b2로 간다. 그래서 ③-b1 구현의 변이 줄 일부는 ③-b2의 ⓔ에서 확인한다(§5 조각 ③ · §9).
- Z17의 「다르면 셋으로 고친다」는 「잰 결과가 전제와 다르면(두 `iat`가 같다 — Access가 JWT를 다시 쓴다)」으로 풀어 적었다(§7 T085).

### (마) 마감 확인 반영(컨트롤러가 직접 고쳤다 · 2026-11-12)

마감 워크플로 `wf_66532cef-008`의 변경분 확인은 approve_with_fixes였다(high 0 · medium 0 · low 2 · 제안 일곱 — 보고 `.superpowers/t073/reviews/fix2/fix2-review.json`). 아래는 하위 에이전트 없이 컨트롤러가 고친 것이다(Z 번호는 붙이지 않는다).

| # | 출처 | 고친 것 | 자리 |
|---|---|---|---|
| 1 | RC-1(low) | denylist.md §검증 T066 줄의 「30 s 안에 무조건 재적용」 → 「무조건 재적용 한 번」 + 상한 가리킴 | §4 C42 (라) · contracts/denylist.md §검증 |
| 2 | RC-2(low) | VD-T073-15 (b)의 env — identity-admin 필수 넷과 행을 넣는 방법 | §6 VD-T073-15 (b) |
| 3 | 제안 1 | T066 독스트링 정합 목록에 test_api.py:134 | D26 |
| 4 | 제안 3 | 편차 29가 인용하는 글자(spec:205 「최대 30 s」 · tasks:224 「≤ 30 s 안에」) | §9 |
| 5 | 제안 4 | VD-T073-6 ④는 값마다 재기동 주기를 따로 돈다 | §6 VD-T073-6 ④ |
| 6 | 제안 5 · 설계 역할의 우려 | 사용자 조회의 그 밖 실패 갈래 · 이벤트 조회 4xx의 변이 줄 | D17 5단계 · 변이 |
| 7 | 제안 6 | `seed_tenant` 출력 = 접두로 찾는 줄 하나 | D19 8단계 · §4 C22 · data-model.md §1 시드 |
| 8 | 제안 7 | 사실 ㉗ — api-44에는 `@DB`가 있다 | §2 ㉗ |
| 9 | 설계 역할의 우려(③-b1 · ③-b2의 ia 2 대 14) | 두 경로를 다 보는 묶음 여섯을 사례 단위로 갈라 revoke 사례는 ③-b1이 먼저 쓴다(번호 · 합계 표는 그대로) | §5 조각 ③ 「사례 단위 가름」 |

- 받아들이지 않은 것: 제안 2(③-b2의 ⓔ 열거에 D18 변이를 더하기 — 같은 줄의 일반 규칙이 덮는다).
- 범위 밖으로 남긴 것: contracts/pod-template.md §런타임 계약 표의 두 행(「DB 연결」 · 「인증」)은 칸 안의 이스케이프 안 된 `|` 때문에 GFM에서 칸이 셋으로 갈린다. 이 설계 커밋 앞(HEAD `3626d16`)부터 있던 꼴이고 이번 diff가 만든 것이 아니라 여기서 고치지 않는다(bn 「T073」 절에 적어 둔다).
