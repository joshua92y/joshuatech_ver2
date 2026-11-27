# T090 설계: `packages/content` 로더 구현 — 자체 로더 + 순수 마크다운(T086-e) → T086 PASS

- **상태**
  - **확정(2026-11-27) = r2 본문 + §6 확정 보정(컨트롤러 — r2 검증 · ① 실물 대조).**
  - 경과
    1. 조사 3(R1 계약 · R2 의존 · R3 통합 — 워크플로 `wf_128be064-a32`)
    2. 초안 r0(2026-11-26)
    3. 비판 2렌즈(A 정합 · 문면 · 시험 / B 공급망 · 보안 · 번들 · 운영). 둘 다 approve_with_fixes · HIGH 0이다(A: MEDIUM 5 · LOW 17 · NIT 2 / B: MEDIUM 2 · LOW 10 · NIT 6).
    4. 컨트롤러 결정(2026-11-26 — 비판 r0 처리 · 사전 해석) · 사용자 결정 둘(2026-11-27 — 〔90-1〕 = 모듈 메모 · 설치 승인 = 권고 세트 12 + ajv 둘)
    5. r1(수정 · 검증 워크플로 `wf_a012c1b3-72a`) → 검증 2렌즈(A 결정 반영 · 정합: approve_with_fixes · HIGH 0 · MEDIUM 0 · LOW 6 · NIT 10 / B 시험 · 변이 · 관문: revise · HIGH 0 · MEDIUM 1 · LOW 9 · NIT 6)
       - 워크플로 판정 정규식이 `**MEDIUM**` 굵은 표기를 못 읽어 r2가 한 번 건너뛰어졌고, 컨트롤러가 정규식을 고쳐 이어서 돌렸다.
    6. 컨트롤러 처리 결정(2026-11-27 — 결정 문서 「검증 지적 처리」 · 전부 채택) → r2(본문)
    7. r2 검증(approve_with_fixes · HIGH 0 · MEDIUM 2) → ① 실물 대조(T086 기대값 전부 일치 · 설계 어긋남 둘) → 컨트롤러 확정 보정
       - r2 검증은 에이전트 하나였고 r3는 없다. 검증 지적과 ① 어긋남은 컨트롤러가 직접 정해 본문에 넣었고, 항목마다 §6에 기록했다(2026-11-27).
  - **⓪ 실행(2026-11-27 10:15 KST) · 관문 전부 충족 · 증거 `.superpowers/t090/evidence/install/`**(D11 · 결과 정본 = build-notes 「## T090」)
  - 과제가 닫힌 뒤에는 고치지 않는다(`.claude/rules/specs.md` design 규칙). 달라진 점은 끝 「정정 노트」에 덧붙인다.
- **입력**
  - 조사 R1 계약 · R2 의존 · R3 통합(`.superpowers/t090/research/R{1-contract,2-deps,3-integration}.md`). 인용은 〔R1 ③-7〕 · 〔R2 §5-4〕 · 〔R3 F9〕 꼴로 한다.
  - 비판 `.superpowers/t090/reviews/critique-{A,B}-r0.md`. 인용은 〔A-n〕 · 〔B-n〕 꼴로 한다. 처리는 아래 결정 문서가 정본이다.
  - 검증 r1 `.superpowers/t090/reviews/verify-{A,B}-r1.md`. 인용은 〔V-A-n〕 · 〔V-B-n〕 꼴로 한다. 처리는 결정 문서 「검증 지적 처리」 절이 정본이다.
  - 검증 r2 `.superpowers/t090/reviews/verify-r2.md`. 인용은 〔V2-n〕 꼴로 한다. 처리는 §6 확정 보정(컨트롤러)이 정본이다.
  - **컨트롤러 결정 `.superpowers/t090/decisions-controller.md`(정본 · gitignore)** — 「사전 해석」 · 「비판 r0 처리」 · 「사용자 결정」 · 「⓪ 기반 설치」 · 「검증 지적 처리」 · 「① 실물 대조」 절. 비판 · 검증의 「고칠 방향」과 다르면 결정 문서를 따른다.
  - 증거 `.superpowers/t090/evidence/`(저장소 안 · gitignore)
    - `preresolve/` — 사전 해석: `expected-pnpm-lock.yaml`(기대 lock) · `expected-content-package.json` · `lock.diff` · `analyze.mjs`(금지 이름 정규식 2026-11-27 정정 — 〔V-B-9〕) · `setup.mjs`
    - `install/` — ⓪ 실행 기록(2026-11-27): `0-2-install.log` · `0-3-gate.txt` · `0-3b-banned-recheck.txt` · `0-4a-frozen-repo.log` · `0-4b-frozen-empty.log` · `0-5-events.log` · `0-6-content-red.log` · `head-pnpm-lock.yaml`
    - `critic-b/out/expected-closure.tsv` — 정확 목록(머리줄 + 110항목 — name@version · sha512 · 게시일 · 게시자 · 출처 증명)
    - `vd-t086-3-4/` — ① 실물 대조(2026-11-27 · D12 ①): `probe.mjs`(다시 돌릴 수 있다) · `out.txt`(311줄) · `item1-self-list.tsv` · `mx4-input.md` · `mx4-expected-{ko,en,ja}.html`. 빌더는 읽지 않는다 — mx-4 기대값은 컨트롤러가 `packages/content/tests/fixtures/t090-mx-4/`로 옮겼다(§6-1)
    - `v2-1-zod-format/` — 〔V2-1〕 탐침(2026-11-27 · 컨트롤러): `probe.mjs` · `out.txt`(url 스키마의 JSON Schema 꼴 넷 · ajv · zod 판정 — §6-2)
    - `col-probe/` — 〔열 탐침〕(2026-11-27 · 컨트롤러): `probe.mjs` · `out.txt`(micromark 열 단위 · 변환 뒤 위치 없는 노드 · 순서 사례 둘 — §6-9)
    - `draft-probe/` · `critic-a/` · `critic-b/` — 탐침 스크립트 · 데이터
  - 선례 `design/t086-design.md`. 인용은 「t086:줄」 꼴로 한다. 쓰는 곳은 D4 · D12 · D14 · §3 · §5-2 T090 · §7 N-1–N-19 · 정정 노트 1–35다.
  - **API 정본 = `packages/content/tests/loader.test.ts` 머리 주석(:1–:51)**. 인용은 「머리 :줄」 꼴로 한다.
  - 측정 · 열람: 〔측정 S〕 · 〔탐침 A〕 · 〔탐침 B〕 · 〔사전 해석〕 · 〔검증 B〕 · 〔① 탐침〕 · 〔V2-1 탐침〕 · 〔소스〕(아래 「표기」)
- **기준**
  - HEAD `5b9b1ff`(브랜치 `003-platform-foundation`). 이 문서의 줄 번호는 모두 HEAD 실물이다.
  - Node v24.11.1 · pnpm 10.34.5(package.json:4) · `minimumReleaseAge: 4320`(pnpm-workspace.yaml:10)
- **표기**
  - 「추론」 = 실측 전 판단이다. §3 VD로 넘긴다.
  - 〔90-n〕 = report 편차 후보(§1-4)
  - 시험 id
    - `ld-n` = T086 시험이다. **고치지 않는다.**
    - `sx-n` · `mx-n` · `lx-n` = T090 새 시험(D12)
    - `mu-n` = 변이(D13)
  - 〔측정 S〕 = 초안 작성자 측정이다. `.superpowers/t090/evidence/draft-probe/`(data · scripts) · Node v24.11.1 win32 · 2026-11-26.
  - 〔탐침 A〕 = 비판 A 탐침 `.superpowers/t090/evidence/critic-a/` · 〔탐침 B〕 = 비판 B 탐침 `.superpowers/t090/evidence/critic-b/`(받은 tarball은 풀어서 읽기만 했다 — 실행 0)
  - 〔사전 해석〕 = 컨트롤러 사전 해석 `.superpowers/t090/evidence/preresolve/`(2026-11-26 19:51 KST). 스크래치 사본에서 `pnpm install --lockfile-only --ignore-scripts`를 돌렸다 — `resolved 179 · downloaded 0` · 코드 실행 · 압축 풀기 0.
  - 〔검증 B〕 = 검증 B가 실측한 결과 줄이다(2026-11-27 · 탐침은 검증자 스크래치에 있어 결과 줄만 인용한다).
  - 〔① 탐침〕 = ① 실물 대조 탐침 `.superpowers/t090/evidence/vd-t086-3-4/`(2026-11-27 · 설치된 판을 직접 부른다 · 값 출력 0). 사례는 `out.txt`의 사례 id(예: 7-x2)로 인용한다.
  - 〔V2-1 탐침〕 = 컨트롤러 탐침 `.superpowers/t090/evidence/v2-1-zod-format/`(2026-11-27 · zod 4.6.7 · ajv 8.20.0 · ajv-formats 3.0.1)
  - 〔열 탐침〕 = 컨트롤러 탐침 `.superpowers/t090/evidence/col-probe/`(2026-11-27 · 설치된 remark-parse · remark-gfm · remark-frontmatter)
  - 〔소스〕 = 공개 패키지 · Node 소스를 열람한 것이다. jsdelivr · GitHub raw · 2026-11-26 열람 · r2(2026-11-27)와 §6 확정 보정은 설치된 `node_modules` 소스를 읽기만 했다 · 받은 코드 실행 0.
  - `␠` = 공백 한 칸 · `<TAB>` = 탭 · `⏎` = 줄 끝이다(문서 안 표기 — 실제 글자가 아니다).
- **과제 문면**(tasks.md:245 그대로)
  > 「`packages/content/src/{schema.ts,loader.ts,mdx.ts,index.ts}`: zod 스키마(rules/content.md), `glob` 스캔(`content/{study,blog,projects}`) + 다국어 접미사 그룹핑 + 검증 + `React.cache` 1회, remark(gfm·frontmatter·heading id·reading-time)/rehype(shiki) 파이프라인, `getCollection(name, {lang, includeDrafts})`, JSON Schema export(`pnpm --filter content schema`) → T086 PASS」
- **규약**
  - 「Tests MUST be written and FAIL before implementation」(tasks.md:371) · 「T090 ∥ T091」(:381) · 헌법 II
  - 승인된 spec · plan · tasks와 T086 시험 · 픽스처는 불변 입력이다. 어긋나면 「편차 · 사용자 결정 후보」로 적는다.
  - **시험 머리 주석과 뜻이 다른 곳은 0이다.** 머리 주석을 같은 뜻으로 읽는 해석과 머리 주석이 정하지 않은 자리의 확장은 **D16 「해석 · 확장」 열에 전부** 적는다. 뜻이 달라야 하면 「시험 고치기 = 사용자 결정」으로 올린다.

## 0. 이어받은 결정 · 결정됨

### 0-1. 이어받은 결정

| 결정 | 근거 | 이 설계에서 |
|---|---|---|
| **T086-e** (A) 자체 로더 + 순수 마크다운 | `.superpowers/t086/decisions-controller.md`:109–:116 · t086:140–:152 | 아래 목록 · D2 · D3 · D6 · D7 |
| D4-8 실행 자리 | t086:306 · 「1회 스캔 캐시(생성 단계 1회)」 t086:998 | 〔90-1〕(§0-2 — 결정됨) |
| **N-1** draft 기본값 = 닫힌 쪽 | t086:1030–:1036 · 머리 :17–:18 | D9. `NODE_ENV`가 정확히 `development` · `test`일 때만이다. **호출 시점에 읽는다** |
| **N-2 · 정정 노트 3** 입력 값 0 · cause 0 · 자기 속성 넷 | t086:1038–:1042 · :1160–:1164 · 머리 :47–:49 | D4 |
| **N-3** BOM은 남겨서 판정 | t086:1044–:1046 · 머리 :43 | D5 |
| **N-7** 정밀도 · 순서 | t086:1066–:1072 · 머리 :31 · :38–:45 | D4 · D6 |
| **N-13** `sources[].path` 꼴 | t086:1106–:1110 · 머리 :36 | D5 · D10 |
| **정정 노트 1** 본문 5절 검증 0 | t086:1149–:1153 · 머리 :19–:20 | 로더 · TDD 모두 0이다(D3 · D12) |
| **정정 노트 2** 날짜 = `'YYYY-MM-DD'` 문자열 · `name` · `ko-missing`(변형 파일마다) | t086:1154–:1159 · 머리 :22 · :26–:27 · :43–:44 | D5 · D9 |
| **정정 노트 5** 실물 remark 대조 = 설치 직후 첫 단계 | t086:1169–:1173 | D12 ① · §3 |
| 정정 노트 30 증거 참조 금지 | t086:1269–:1272 | 빌더 지시문에 `.superpowers/t086/evidence/`를 넣지 않는다(D13 · D15) |
| **정정 노트 35** root 우선순위 사례 · 머리 주석 정본 | t086:1288–:1289 | D8 · lx-1–lx-3 · D16 |
| 설치 = 착수 때 사용자 승인 → 컨트롤러 기반 커밋 | t086:152 · :1014 | §0-3(결정됨) · D11 |

T086-e가 이 설계에 정하는 것:
- `.mdx`는 Markdown + GFM + 프런트매터(yaml)로만 읽는다. remark-mdx · rehype-raw · `allowDangerousHtml`은 0이다.
- 거부 규칙 넷을 둔다.
- gray-matter · reading-time · 지우기형 도구는 0이다.
- **컴파일은 Node 생성 단계와 시험에서만 한다.**
- 페이지는 산출물만 import한다.

### 0-2. 〔90-1〕 「`React.cache` 1회」 — 결정됨: ① 모듈 메모(사용자 · 2026-11-27)

**결정**(결정 문서 「사용자 결정」)
- `loader.ts` 모듈 수준 Map(키 = 해석된 root · 컬렉션)으로 생성 프로세스에서 컬렉션마다 스캔 1회다. react 의존은 0이다(D8 「1회 스캔 캐시」).
- 문면 편차 〔90-1〕은 report에 기록한다. 코드 주석에 「tasks.md T090 『`React.cache` 1회』 = 이 모듈 메모(〔90-1〕)」를 둔다.
- ADR 0004와 t086 설계는 고치지 않는다.

**근거(사실)**
- React `cache`는 컴포넌트 밖에서 캐시를 읽지도 쓰지도 않는다.
  - 원문: 「When calling `getUser` outside of a component, it will still evaluate the function but not read or update the cache」(https://react.dev/reference/react/cache · 〔R3 F1〕)
  - react-server 조건이 아닌 빌드에서는 함수를 그대로 부르는 감싸개다(react@19.3.1 `cjs/react.production.js:405–409` 〔R2 §5-3〕 · `ReactFeatureFlags.js:196` `disableClientCache = true` 〔R3 F2〕).
- 확정 설계에서 `getCollection`을 부르는 자리는 Node 생성 단계(T091)와 시험뿐이다(t086:306). 그 자리에서 `React.cache`는 1회를 보장하지 못한다(추론 — F1 · F2).
- 페이지가 `@jt/content`를 import하면 컴파일 코드가 Worker 번들에 든다. OpenNext는 매니페스트의 `.js` 항목마다 정적 `require()`를 만든다(〔R3 F3〕 — 소스 정황 · 실측 = VD-T086-6). Workers `node:fs`에는 `/bundle` · `/tmp`뿐이라 런타임 스캔은 되지 않는다(〔R3 F4〕).
- 문면의 출처와 의도(〔A-21〕)
  - 「`React.cache` 1회」의 출처는 조사 결정 문서다: research/2026-08-28-brainstorm-decisions.md:57 「… zod 스키마(…) + 타입 + React.cache 1회 스캔 + draft 필터 …」.
  - 같은 줄 끝 「v1 분석: 스키마 검증 없음·페이지당 3회 재스캔·…」이 의도를 보여 준다. v1의 페이지당 3회 재스캔을 막는 것이다.
  - 당시 구상(fs + gray-matter + next-mdx-remote/rsc — 렌더 때 컴파일)은 T086-e(자체 로더 + 순수 마크다운 · 컴파일은 생성 단계)가 대체했다. 생성 단계 모듈 메모가 그 의도(스캔 1회)를 그대로 채운다.
  - ADR 0004 부록 D19는 「캐시」만 적고 React를 언급하지 않는다(docs/decisions/0004-web-framework.md:42).

비교(결정 근거 — 짧게)

| | ① 모듈 메모(결정) | ② 문면 유지 | ③ RSC 런타임 + `React.cache` |
|---|---|---|---|
| 1회 | 생성 프로세스에서 컬렉션마다 1회(3 컬렉션 × 3 로케일 = 9 호출 → 스캔 3) | ①과 같다(감싸개 효과 0) | 요청마다 무효화된다(F1) |
| 새 의존 | 0 | `react` +1(apps/web의 React 판과 맞춰야 한다) | `react` + T086-e를 다시 연다 |
| 대가 | 문면 편차를 기록한다(〔90-1〕) | 형식만 맞춘다. 읽는 사람이 효과를 오해한다 | 번들 예산 · web.md:14–:15 · T086-e와 정면 충돌 |

### 0-3. 로더 새 의존 설치 — 결정됨: ① 권고 세트 12 + ajv 둘(사용자 · 2026-11-27)

**결정**(결정 문서 「사용자 결정」 — 설치 승인 「권고 세트 설치 (권장)」)
- 런타임 12 + dev ajv 8.20.0 · ajv-formats 3.0.1(아래 표 · 정확 판)
- 관문 = 정확 기대 lock(사전 해석본과 차이 0) · frozen 두 번 · `@jt/events` 267 · content 빨강 원인 그대로다. 깨지면 되돌리고 여쭌다(D11 ⓪-3–⓪-8). push는 run-all 뒤다.
- **⓪ 실행(2026-11-27 10:15 KST)으로 관문을 모두 충족했다**(D11 · `.superpowers/t090/evidence/install/`).

| # | 패키지(정확 판) | 공개 | 하는 일 | 새로 드는 수(고유) | 메모 |
|---|---|---|---|---|---|
| 1–3 | unified 11.0.5 · remark-parse 11.0.0 · remark-rehype 11.1.2 | 2023–2025 | 파서 · 변환 뼈대 | 기반 68 | 메이저 동결 · 공지 0. 전이 mdast-util-to-hast 13.2.2(≥ 13.2.1 — CVE-2025-66400 수정) |
| 4 | remark-gfm 4.0.1 | 2025-02 | 표 · 각주 · 자동 링크 | 17 | T086 픽스처 024(표) · 027(각주) · 099가 GFM 구조를 전제한다(추론 — D6) |
| 5 | remark-frontmatter 5.0.0 | 2023-09 | `---` 블록 분리(줄 번호 = 파일 줄) | 5 | 정정 노트 5 「line = 프런트매터 포함」(t086:1172) |
| 6 | rehype-slug 6.0.0 | 2023-08 | 헤딩 id(github-slugger 2.0.0) | 3 | VD-T086-4 |
| 7 | @shikijs/rehype 4.6.0 | 2026-11-02 | 코드 하이라이트 | 15(약 12.9 MiB) | 출처 증명 ✓. `shiki` 4.6.0이 정확 의존(`"shiki": "4.6.0"`)이라 함께 묶인다 |
| 8–10 | hast-util-to-html 9.0.7 · unist-util-visit 5.2.0 · hast-util-to-string 3.0.1 | 2024–2026 | HTML 출력 · 트리 순회 · 헤딩 글 | 0 | |
| 11 | yaml 2.9.1 | 2026-09 | 프런트매터(gray-matter 대신) | 1 | 과거 공지(<2.8.3)는 해소됐다. vite의 선택 peer라 vitest 줄 접미가 바뀐다(〔B-1〕 · D11 ⓪-3) |
| 12 | zod 4.6.7 | 2026-10 | 스키마 + `z.toJSONSchema` | 1 | GHSA-mrhx(<4.6.6) 이후 판 |
| 13–14 | ajv 8.20.0 · ajv-formats 3.0.1(**devDependencies**) | lock에 이미 있다(`packages/events` importer) | JSON Schema 산출물을 소비자 쪽에서 검사한다(sx-5) | **0** | importer 줄만 는다(〔사전 해석〕 실측 — `3.0.1(ajv@8.20.0)`) |
| 계 | | | | **110 · 22.5 MiB** | 설치 스크립트 0 · 네이티브 0 · 공지 0 · 정확 목록 110/110(name@version + sha512) · 3일 창 충족 |

- 근거는 〔R2 §2-1 · §4 · §8 · §10〕과 비판 B 독립 해석(〔탐침 B〕 — 110 · 22.5 MiB · deprecated 0 · 공지 0/113 이름)이다.
- 전이 수 · lock 차이는 〔사전 해석〕으로 실측했다(결정 문서 「사전 해석」).
  - packages 69 → 179(**+110 · 삭제 0**). 비판 B 정확 목록과 name@version + sha512가 **110/110** 같다. 빌드 · os · cpu 표식 0 · deprecated 0 · 레지스트리 밖 0 · 금지 이름 0이다(2026-11-27 정정 도구 재실행 포함 — D11 ⓪-3 3).
  - lock `+1020 / −9`. 삭제 9줄은 vitest peer 접미 대체뿐이다(D11 ⓪-3).
- **넣지 않는 것**
  - `react`(§0-2 ①)
  - npm `glob` · `tinyglobby`(§0-4)
  - `mdast-util-toc` — 헤딩 id를 두 곳에서 계산하게 된다(〔R2 §2-2〕).
  - `zod-to-json-schema` — 아카이브됐고 v4를 지원하지 않는다(https://github.com/StefanTerdell/zod-to-json-schema).
  - `rehype-stringify` — +1이다. hast-util-to-html은 +0이다.
  - `tsx` — +28 · esbuild postinstall
  - `typescript` · `@types/*` — 형 검사는 T091 · T093 몫이다(정정 노트 34 t086:1285–:1287).
  - gray-matter · reading-time(T086-e)

비교(결정 근거 — 짧게)

| | ① 권고 세트 12 + ajv 둘(결정) | ② 12만 | ③ 축소(예: Shiki 보류) | ④ 보류 |
|---|---|---|---|---|
| 결과 | 전부 충족 · sx-5 소비자 대조 | sx-5 대신 구조 단언만 | FR-029 「코드 하이라이트」(spec:272)와 과제 문면 「rehype(shiki)」를 채우지 못한다 | T090 착수 불가 |

**받아들인 대가**
- 새 패키지 110개 · lock `+1020 / −9`(삭제 = vitest peer 접미 9줄 — apps/web · packages/events importer 줄도 바뀐다)
- 게시자 집중: wooorm이 81/110을 게시했다(R2 셈 · 비판 B `_npmUser` 기준 80/110). 출처 증명은 10/110이고 전부 trusted publisher다(shiki 계열 9 · zod).
- 11월 패치 몰림을 감시해야 한다(〔R2 §4〕). 비판 B가 직전 판과 diff를 대조했고 의심 토큰 증가는 0이었다.
- 정확 핀이라 Renovate PR이 패키지마다 온다(`automerge: false` — renovate.json:12).
- 첫 실행 격리는 하지 않는다(〔B-12〕 기록). 빌더 vitest도 같은 PC에서 돌아 첫 실행만 격리하는 이득이 작다. 방어선 = 정확 핀 · 3일 창 · 공지 0 · 11월 패치 diff 의심 0 · sha512 정확 대조다.
- Shiki Renovate 그룹(t086:998 — 〔A-18〕): 지금은 `shiki`가 @shikijs/rehype 4.6.0의 정확 의존이라 따로 PR이 오지 않는다 → 지금은 해당 없음이다. `shiki`를 직접 선언하는 커밋에는 그룹을 함께 넣는다(D11 ⓪-9).

### 0-4. 〔90-2〕 「`glob` 스캔」 — 결정됨: ① `readdir`(컨트롤러 · 2026-11-26)

**결정**(결정 문서 「비판 r0 처리」 — 비판 B 지지)
- 스캔은 `readdir(withFileTypes)` + 우리 규칙이다(D8). OS와 무관하게 판정하고, 링크를 명시적으로 거부한다(`not-regular`).
- 문면 「`glob` 스캔」의 뜻(세 컬렉션 디렉터리의 `*.mdx` 훑기)은 같다 → 〔90-2〕 report 편차 후보 · 마감 보고 한 줄(사전 질문 없음).

**측정**(〔측정 S〕 — `study/`에 `001-a.mdx` · `X.MDX` · `.002-hidden.mdx` · `003-b.md` · `notes.txt` · 디렉터리 `sub.mdx/`를 두었다)

| 호출 | 결과(출력 줄 그대로) |
|---|---|
| `fs.promises.glob('{study,blog,projects}/*.mdx', { cwd })` | `glob ["study\\001-a.mdx","study\\X.MDX","study\\sub.mdx"]` |
| 같은 glob · `withFileTypes` | `glob-types ["001-a.mdx:f","X.MDX:f","sub.mdx:d"]` |
| `readdir(study, { withFileTypes: true })` | `readdir [".002-hidden.mdx:f","001-a.mdx:f","003-b.md:f","X.MDX:f","notes.txt:f","sub.mdx:d"]` |
| 없는 디렉터리 | `readdir-missing ENOENT` · `glob-missing-cwd []` |

측정에서 드러난 것:
- glob은 Windows에서 대소문자를 무시하고(`X.MDX`), 숨김 파일을 조용히 빼고, 디렉터리를 돌려주며, 구분자가 `\`이다.
- 대소문자 무시는 OS마다 다르다. Node v24.11.1 `lib/internal/fs/glob.js:102`가 `nocase: isWindows || isMacOS`이므로, Linux에서는 같은 패턴이 `X.MDX`를 돌려주지 않는다(〔소스〕 https://raw.githubusercontent.com/nodejs/node/v24.11.1/lib/internal/fs/glob.js — Linux 결과는 추론).

비교(결정 근거 — 짧게)

| | ① `readdir(withFileTypes)` + 우리 규칙(결정) | ② `fs.promises.glob` + 후처리 | ③ npm `glob` 14.0.6 · `tinyglobby` 0.2.17 |
|---|---|---|---|
| OS 무관 | 후보 · 이름을 우리가 판정한다 → 같다 | 후처리 넷이 필요하다: 대소문자 재검사 · 디렉터리 제외 · 숨김 규칙 · 존재 확인 | glob과 같은 문제 |
| 부재 | ENOENT → `missing` 갈래에 그대로 쓴다 | 없는 cwd도 `[]` → 존재를 따로 확인해야 한다 | — |
| 새 의존 | 0 | 0 | glob +8 · BlueOak · minified dist / tinyglobby 0.x(〔R2 §2-2〕) |
| 문면 | 글자가 다르다 → 〔90-2〕(뜻은 같다) | 글자가 맞는다 | 글자가 맞는다 |

- 조사 R2 §5-1과 R3 F9는 ②를 권고했다. 위 측정 때문에 ①을 골랐다. ②로도 후처리 넷으로 같은 결과를 낼 수 있어 결정적 차이는 아니다.

### 0-5. 〔90-3〕 blog · projects 계약 — 결정됨: ① 잠정(컨트롤러 · 2026-11-26)

**결정**(결정 문서 「비판 r0 처리」 A-17)
- 필드 스키마는 study와 같고 `change`는 선택이다. 있으면 같은 꼴이다.
- 이름은 kebab이다: `^[a-z0-9]+(-[a-z0-9]+)*(\.(en|ja))?\.mdx$`(content.md:27 「ASCII kebab-case」).
- 변형과 ko 가운데 한쪽에만 `change`가 있으면 `(변형, change, variant-mismatch)`다(닫힌 쪽 — 〔A-17〕 · lx-13).
- 근거: data-model.md:244 `change` 「필수(study)」가 다른 컬렉션은 선택임을 받쳐 준다.
- 파일이 0이라 지금 영향은 0이고 되돌림 비용이 작다 → 마감 보고에서 한 줄로 알린다. JSON Schema export는 study 하나만 한다(D10).

**사실**
- data-model.md:244에서 `change`는 「필수(study)」다.
- 파일 이름 규칙은 study만 있다(머리 :22). content.md:9 계약도 study만 다룬다.
- 그런데 FR-029는 「`content/{study,blog,projects}`를 빌드 시 읽어 zod 스키마(…)로 검증」한다(spec:272).
- 지금 `content/blog` · `content/projects`는 없다(`git ls-files content` = `content/study/*` · `content/tmp/*`).

비교(결정 근거 — 짧게)

| | ① 같은 필드 · `change` 선택 · 이름 kebab(결정 · 잠정) | ② study 규칙 그대로 | ③ 파일이 있으면 오류(계약 전까지 닫힘) |
|---|---|---|---|
| FR-029 | 맞는다 | 맞는다 | 어긋난다 |
| 대가 | 계약을 우리가 만든다(content.md 한 줄 + 〔90-3〕). SP-2에서 다시 본다 | 블로그 글에 기능 번호를 강요한다 | 새 code가 생기고 FR-029 편차가 된다 |

### 0-6. 컨트롤러 결정 C1–C9 — 결정됨(컨트롤러 · 2026-11-26 · 사용자에게는 마감 보고에서 한 줄)

권고대로 정했다. C3 · C8은 〔A-1〕 · 〔A-2〕 결정으로 바뀌었다.

| # | 항목 | 결정 | 자리 |
|---|---|---|---|
| C1 | run-all `content` 슬롯 | (B) 둔다 — T090 커밋. SKIP = 의존 미설치일 때만이다. pnpm이 PATH에 없으면 FAIL 줄이다(〔A-15〕 · 〔B-6〕) | D14 · 정정 노트 18(t086:1220) |
| C2 | JSON Schema 산출물 | 커밋 + vitest 신선도 시험 · study 하나 | D10 |
| C3 | 숨김 · 대소문자 · 정규 파일 아닌 항목(〔A-1〕로 바뀜) | 후보 = 확장자를 대소문자 무관으로 본 `.mdx`다. 숨김 `.x.mdx` · `X.MDX` · `y.Mdx` → `(file, file, name)`. `*.mdx` 항목(FILE_RE 안 이름)이 정규 파일이 아니면(디렉터리 · 심볼릭 링크 · junction · 그 밖) `(file, file, not-regular)`다 — 따라가지 않고 읽지 않는다. root · 컬렉션 디렉터리는 따라간다(〔B-14〕 기록) | D8 |
| C4 | YAML 엄격 보강 | 지시자 · 문서 표식 · 키 꼴 `^[A-Za-z][A-Za-z0-9_]{0,63}$`(따옴표 키 허용 — 〔A-9〕) · 매핑 아님 · 앵커 · 별칭(〔B-3〕) · 경고 → `(file, frontmatter, yaml)` | D5 |
| C5 | 스키마 issue code 어휘 · 파일 안 순서 | D4 표 · 순서 세부(〔A-10〕). lx-8b가 행마다 고정한다(〔A-3〕) | D4 |
| C6 | 산출 필드 `html` · 헤딩 수집 · 각주 라벨 | D7 — 각주 라벨 · 되돌림 라벨 lang별(〔A-4〕) | D7 |
| C7 | Shiki 언어 · 테마 · 대체 | D7(언어 목록 이름 `CODE_LANGS` — 〔A-24〕 ②) | D7 |
| C8 | 이름 위반 파일의 검증 범위(〔A-2〕로 바뀜) | FILE_RE 안 이름은 파일 단위 검증을 모두 돌고 묶음 · 항목에서 뺀다. FILE_RE 밖 이름은 `(<컬렉션>/, file, name)` 하나만 내고 다른 검증은 0이다 | D8 · D9 |
| C9 | Linux 1회 실행 | 마감 때 Docker `node:24` 또는 WSL | VD-T090-8 |

## 1. AC 대응과 합격선

### 1-1. 과제 ↔ AC ↔ 합격선

| 과제 | AC · FR | 산출 | 초록 |
|---|---|---|---|
| T090 | AC2(spec:124) · FR-029(:272) · Edge 「콘텐츠 스키마 위반 … 빌드 실패」(:221) · content.md · data-model §11 | `src/{schema,loader,mdx,index}.ts` · 새 시험 3파일 · `schemas/study.schema.json` · 매니페스트(⓪) | T086(이 과제). T087 h-2 · h-5는 T091 + T086-a 뒤 |

- FR-029 「remark/rehype(헤딩 앵커·목차·읽기 시간·코드 하이라이트)」 대응: 헤딩 앵커 = 헤딩 id(D7) · **목차 = `headings[]`(h2 · h3 · 각주 라벨 제외 — 〔A-23〕)** · 읽기 시간 = `readingTime`(D7) · 코드 하이라이트 = Shiki(D7)

**합격선**(1–9를 모두 채워야 tick — D15)

1. **T086 48 사례 전부 PASS**
   - `pnpm --filter @jt/content --fail-if-no-match exec vitest run tests/loader.test.ts` → `Tests  48 passed (48)` · exit 0
   - 패키지 전체 `pnpm --filter @jt/content --fail-if-no-match test` → `Test Files  4 passed (4)` · `Tests  N passed (N)` · 건너뜀 0 · exit 0
   - N = 48 + T090 새 사례다. 수치 정본은 build-notes다.
   - 명령 꼴은 정정 노트 7(t086:1177–:1181)이고, tick 기록에는 끝 요약 줄을 함께 적는다.
2. **정정 노트 35 — root 우선순위**: lx-1–lx-3을 시험 먼저 쓴다. 빨강을 관찰하고 원인을 기록한 뒤 초록으로 만든다.
3. **실물 remark 대조(VD-T086-3 · 4 + 정정 노트 5 목록)를 설치 직후 첫 단계로 한다.**
   - 로더 코드를 쓰기 전에 한다(D12 ①).
   - 전부 일치해야 다음 단계로 간다. 어긋나면 멈추고 「시험 고치기 = 사용자 결정」으로 올린다.
4. **실제 노트 2편 통과**
   - ld-1 세 사례 초록(기본 root · 거부 가드 · 스키마 · h2 id 다섯)
   - lx-15: Node 자식(`process.execPath` · 임시 cwd · 자식 env 명시 — `NODE_ENV` · `JT_CONTENT_ROOT` 삭제). 기본 호출 → draft 항목 0(N-1을 순수 Node에서 확인한다) · `includeDrafts: true` → slug ⊇ {001, 002}(〔A-6〕)
5. **JSON Schema export 산출물 검사**
   - 산출물을 스테이징(또는 커밋)한 뒤 `pnpm --filter @jt/content --fail-if-no-match schema`를 두 번 돌고 `git diff --exit-code -- packages/content/schemas/`가 0이어야 한다(멱등 — 〔A-24〕 ④). 새 파일은 커밋 전에 `??`라 `git status`로는 판정하지 못한다.
   - sx-1–sx-7 초록: 꼴 · 신선도 · CLI · import 무실행 · ajv 대조 · path · url
6. **공허 · 변이**
   - T090 새 시험은 구현 전에 올바른 이유로 빨강이어야 한다(§1-2).
   - D13 `mu-n` 표의 변이마다 1개 이상 사례가 FAIL해야 한다. T090 자기 결정 변이(mu-34–mu-78 — 〔A-13〕 · 〔V-B-7〕 · 〔V2-2〕 · 〔V2-8〕 · §6-9)를 포함한다. 살아남은 변이는 사례를 시험 먼저 더하거나 기록한다. 표에 동등 후보로 미리 적은 꼴은 잡는 사례를 따로 둔다.
   - 참조 구현 0 · t086 증거 0
7. **설치 관문**(⓪ — D11) — **충족**(2026-11-27 10:15 KST 실행 · `.superpowers/t090/evidence/install/`)
   - 실제 설치 뒤 lock = 〔사전 해석〕 `expected-pnpm-lock.yaml`(차이 0 — 정확 목록 110 · sha512 · 삭제 9줄 = vitest peer 접미뿐)
   - frozen 두 번
   - `@jt/events` `Tests  267 passed (267)`
   - 설치 뒤에도 content 빨강 원인 = `../src/index` 부재
8. **run-all**(〔A-15〕 · 〔B-6〕)
   - `pwsh -NoProfile -File tests/run-all.ps1` 출력에 `PASS content` · `PASS agent-layer` · `PASS codex-parity`(AGENTS.md 새 행)
   - 슬롯 갈래를 손으로 확인하고 줄을 그대로 build-notes에 적는다: 의존 없는 사본 → `SKIP content -- allowed (packages/content dependencies not installed)` · PATH에 pnpm 없음 → `FAIL content -- pnpm not found on PATH`(run-all은 계속 돈다) · vitest만 있고 로더 의존 없음 → FAIL(SKIP 아님 — 닫힌 쪽 · 기록)
9. **위생**
   - CI 꼴 gitleaks staged 0(D9-5 꼴 · 정정 노트 35 t086:1292)
   - `git status` = 지정 파일
   - 부산물은 루트 `node_modules/.vitest-cache/`(gitignore — 정정 노트 7)와 `.superpowers/t090/evidence/`(저장소 안 · gitignore)뿐이다.
10. (권고) Linux 1회 — VD-T090-8

### 1-2. 착수 전 기대(올바른 이유의 빨강)

- `pnpm --dir <repo> --filter @jt/content --fail-if-no-match test`
  - 출력: `FAIL  tests/loader.test.ts` · `Error: Cannot find module '../src/index' imported from <repo>/packages/content/tests/loader.test.ts` · `Test Files  1 failed (1)` · `Tests  no tests` · exit 1
  - 〔R1 §0〕(2026-11-26 실행) · build-notes.md:5695 재관찰 · 비판 A 재실행(〔탐침 A〕 `red-run.txt`) · 〔검증 B〕 재실행이 같은 꼴이다.
- ⓪ 설치 뒤에도 같은 꼴이었다(2026-11-27 — D11 ⓪-6 · `install/0-6-content-red.log`).
- T090 새 시험의 조각별 첫 빨강
  - sx: `../src/schema.ts` 부재
  - mx: `../src/mdx.ts` 부재
  - lx: `../src/index` 부재
  - 모듈이 생긴 뒤의 빨강은 사례마다 「기대 동작 없음」(단언 실패)이어야 한다. 구문 · 적재 오류면 안 된다.

### 1-3. 초록이 되는 순서

| 대상 | 초록이 되는 때 |
|---|---|
| T086 | T090(이 과제) |
| T087 h-2 · h-5 | T090 + T091 + T086-a(draft 뒤집기 — 사용자 — t086:128–:130) |
| VD-T086-5 | T091 |
| VD-T086-6 | T091 · T093 |
| CI의 content 시험 | T093(t086 §0-5 :134) |

### 1-4. report 편차 후보(`/finish`가 report.md 「편차」로 옮긴다)

| 번호 | 내용 | 근거 |
|---|---|---|
| 90-1 | tasks.md:245 「`React.cache` 1회」 → 모듈 메모(생성 단계 1회 · react 0) — 사용자 결정 2026-11-27 | §0-2 |
| 90-2 | 「`glob` 스캔」 → `readdir`(뜻은 같다) — 컨트롤러 결정 | §0-4 |
| 90-3 | blog · projects 잠정 계약(`change` 선택 · kebab 이름 · 한쪽만 `change` = `variant-mismatch`) — 컨트롤러 결정 | §0-5 · D9 |
| 90-4 | 「JSON Schema export」 = study 프런트매터 **필드만**. zod 밖 규칙(교차 필드 · url 원 문자열 · userinfo) · url host(공개 도메인 — zod domain, 런타임 전용) · 파일 이름 · 본문 규칙은 밖이다(description에 명시 · 「ECMA-262(u) 패턴」 문구). 커밋 + 신선도 시험 | D10 |
| 90-5 | `getCollection` 인자 검증을 넓혔다: 모르는 lang · 불리언 아닌 includeDrafts · 문자열 아닌 root · 빈 root · 빈 `JT_CONTENT_ROOT` · `opts === null` · 객체 아닌 opts → `TypeError`(값 없는 메시지). 명시 `undefined`는 미지정이다(〔A-16〕) | D8 |
| 90-6 | 「remark(… heading id …)/rehype(shiki)」 → 헤딩은 rehype-slug 뒤 hast에서 모은다(각주 라벨 제외). 산출 필드 `html`을 더했다(각주 라벨 · 되돌림 라벨 lang별). Shiki 대체 언어 = text | D7 · 〔86-18〕 |
| 90-7a | YAML 판독 엄격 보강: 지시자 · 추가 문서 표식 · 매핑 아님 · 키 꼴 `^[A-Za-z][A-Za-z0-9_]{0,63}$`(따옴표 키 허용) · 경고 → `yaml` | D5 · C4 |
| 90-7b | 앵커 · 별칭이 하나라도 있으면 `yaml`(〔B-3〕) | D5 |
| 90-7c | 줄 끝 = `\r\n` · `\r` · `\n`(CommonMark 줄 — CRLF 노트는 정상이다 · 〔A-9〕). 마감 보고 알림(결정 질문 3)을 위해 싣는다 — 뜻은 :42의 해석이다(D16 · 〔V-A-14〕) | D5 |
| 90-7d | 스캔: 후보 = 확장자 대소문자 무관 `.mdx` · 숨김 · 대소문자 다른 `.mdx` → `name` · `*.mdx` 이름(FILE_RE 안)의 정규 파일 아닌 항목 → 새 code `not-regular`(〔A-1〕 — FILE_RE 밖 이름이면 〔90-7e〕가 먼저다) | D8 |
| 90-7e | FILE_RE 밖 이름 → `(<컬렉션>/, file, name)` 하나 · 그 파일의 다른 검증 0(〔A-2〕) | D4 · D8 |
| 90-7f | URL: http(s) authority의 userinfo(`@`) → 본문 `unsafe-url` · 프런트매터 `format`(〔B-5〕). 프런트매터 url 원 문자열(공백 · 제어 · `\`) → `format`(〔B-4〕). 프런트매터 url host = 공개 도메인 이름은 zod `domain`이 이미 하는 일을 content.md에 적은 것이다(새 규칙 아님 · 본문은 host 규칙 0 — 〔V-A-5〕) | D5 · D6 |
| 90-8 | T086-e 「거부 플러그인이 `file.fail`로」 → 순수 함수로 모아 `ContentValidationError`로 던진다(결과는 같고 기제만 다르다) | D6 |
| 90-9 | draft는 파일 단위로 거른다. 단 ko 파일이 걸러지면 그 slug 전체를 뺀다. translations는 거른 뒤 기준이다 | D9 |
| 90-10 | 읽기 시간 = `Intl.Segmenter` 단어 수 ÷ 200(코드 블록 제외 · 올림 · 최소 1) | D7 |

- 머리 주석을 같은 뜻으로 읽은 해석(〔A-7〕 esm 컨테이너 기준 · 〔A-8〕 「issue 하나」 = 내용 단계)은 편차가 아니다. D16 「해석 · 확장」 열에 적는다. 〔90-7c〕(〔A-9〕)도 같은 뜻 해석이지만 마감 보고 알림을 위해 이 표에 싣는다(〔V-A-14〕).
- t086의 〔86-11〕 · 〔86-18〕 · 〔86-28〕 · 〔86-29〕는 그 정정 노트 31 · 1대로 읽는다(t086:1273–:1276). 여기 다시 적지 않는다.

## 2. 결정

### D1 범위 · 산출물

- **바꾸는 것**
  - ⓪ 컨트롤러: `packages/content/package.json` · `pnpm-lock.yaml`. 설계 확정 워크플로와 나란히 돌았다(2026-11-27 10:15 KST · 관문 충족 — D11). 커밋은 ① 설계 확정 커밋 뒤다(결정 문서 「설계 확정」).
  - ① 컨트롤러: `packages/content/tests/fixtures/t090-mx-4/{input.md, expected-ko.html, expected-en.html, expected-ja.html}` — ① 탐침 산출(라이브러리를 D7 옵션으로 직접 부른 값 · Shiki 제외 · 우리 구현이 아니다)을 옮긴 mx-4 기대값이다. 커밋 ③에 든다. 빌더는 고치거나 다시 만들지 않는다(§6-1).
  - 빌더
    - `packages/content/src/{schema,mdx,loader,index}.ts`(`src/.gitkeep` 삭제)
    - `packages/content/tests/{schema,mdx,loader-extra}.test.ts`(+ 필요하면 `tests/fixtures/t090-*/` — 대부분은 mkdtemp · `t090-mx-4/`는 위 컨트롤러 것)
    - `packages/content/schemas/study.schema.json`(생성 산출물 · 커밋)
  - 컨트롤러 문서 · 슬롯: §4-1
- **바꾸지 않는 것**
  - `packages/content/tests/loader.test.ts` · T086 픽스처 전부(바꾸면 = 시험 고치기 = 사용자 결정)
  - `content/study/*`(draft 뒤집기는 T086-a — 사용자)
  - `apps/web/**`(T091)
  - `ci.yml`(T093) · `pnpm-workspace.yaml` · `renovate.json`(⓪-9 조건이 생길 때까지)
  - spec · plan · tasks 문면(tick만) · ADR 본문 · `t086-design.md`
  - 라이브 · 클러스터 · 자격 0
- **네트워크**: npm 레지스트리는 설치(⓪) 때만 쓴다. 시험은 네트워크 0이다.

### D2 모듈 경계 · 공개 표면 · 실행 꼴

```
packages/content/
├── package.json            "type":"module" · exports "." → ./src/index.ts(조건부 exports = T091 인계 — B-8) · scripts.schema · 의존 정확 판(⓪)
├── schemas/
│   └── study.schema.json   파생 사본 — pnpm --filter @jt/content --fail-if-no-match schema
├── src/
│   ├── index.ts            재수출만(import만으로 파일 접근 · 출력 0)
│   ├── loader.ts           root 해석 · 스캔(not-regular · 이름) · 파일 단위 검증 조율 · 묶음 · 교차 파일 규칙 · issue 정렬 · ContentValidationError · 메모 · 거름 · 정렬
│   ├── mdx.ts              파일 하나: 디코드 · 울타리 · 본문 파싱(yaml 노드 대조) · YAML · 거부 규칙 넷 · 컴파일(rehype · slug · 헤딩 · Shiki · html) · 읽기 시간
│   └── schema.ts           zod 필드 스키마(코드 정본) · zod 밖 규칙 · issue 매핑 · JSON Schema 내보내기 + CLI(isEntryPoint — 저장소 선례)
└── tests/
    ├── loader.test.ts      T086 — 그대로
    ├── schema.test.ts      T090 sx-n
    ├── mdx.test.ts         T090 mx-n
    ├── loader-extra.test.ts T090 lx-n
    └── fixtures/           T086 12 디렉터리 그대로(§6-10) · t090-mx-4/(mx-4 기대 html — ① 컨트롤러 · 빌더는 읽기만)(+ 필요하면 t090-*)
```

**공개 표면**(`index.ts`)

| 종류 | 이름 | 비고 |
|---|---|---|
| 값 | **`getCollection`** · **`ContentValidationError`** | 머리 :12–:31 고정 |
| 값 | `COLLECTIONS` · `LANGS` | T091 생성 스크립트의 반복용. `LANGS`는 로케일(ko · en · ja)이다 |
| 형 | `ContentItem` · `ContentIssue` · `Collection` · `Lang` · `Frontmatter` · `Heading` | |

- `ContentItem` = 머리 :24–:25 + **`html: string`**(〔86-18〕 · 〔90-6〕)
- Shiki 코드 언어 목록은 `mdx.ts` 내부 상수 `CODE_LANGS`다. 공개 `LANGS`와 이름이 겹치지 않게 한다(〔A-24〕 ②).

**실행 꼴** — Node 24 타입 스트리핑. 변환 도구 0 · 빌드 단계 0.
- 상대 import는 `.ts` 확장자를 쓴다. 형만 가져올 때는 `import type`을 쓴다.
- erasable 문법만 쓴다(enum · namespace · 매개변수 속성 0 — https://nodejs.org/docs/latest-v24.x/api/typescript.html · 〔R3 F8〕).
- 근거 측정
  - 〔R3 F9〕: `type` 없는 TS 패키지는 `MODULE_TYPELESS_PACKAGE_JSON` 경고 · `type: module`이면 경고 0
  - 〔측정 S〕: `.mts`를 직접 실행하면 `main=true`, import하면 `main=false` · 경고 0
- T086 시험의 확장자 없는 `'../src/index'`(:62)는 vitest가 푼다. 형 검사 경로는 T091 몫이다(`bundler` + `allowImportingTsExtensions` + `noEmit` — 〔R3 §7〕 · 정정 노트 34).

### D3 파이프라인 — 「모두 검증 → 위반이 있으면 던진다 → 없을 때만 컴파일」

**A. 검증(모든 파일 — draft 포함 · 거름은 뒤 — 머리 :18 · ld-6)**

1. 인자 검사 → root 해석 → 존재 확인(D8)
2. 스캔(D8)
   - 항목 이름을 Ordinal로 정렬한다. 후보 = 확장자를 대소문자 무관으로 본 `.mdx`다.
   - FILE_RE 밖 이름은 `(<컬렉션>/, file, name)` 하나로 그 항목을 끝낸다(〔A-2〕).
   - 정규 파일이 아니면 `(file, file, not-regular)`로 그 항목을 끝낸다(〔A-1〕).
   - 컬렉션 이름 규칙(D9) 위반이면 `(file, file, name)`을 내고 검증은 계속한다(C8).
3. 파일마다(FILE_RE 안 이름의 정규 파일 — 이름 규칙 위반 파일 포함)
   1. 바이트 읽기 → `new TextDecoder('utf-8', { fatal: true, ignoreBOM: true })`. 실패하면 `(file, file, encoding)` · 그 파일 끝(N-3)
   2. 울타리(D5 — 디코드한 원문으로 판정). 실패하면 `(file, frontmatter, fence)` · 그 파일 끝
   3. 본문 파싱(remark-parse + remark-frontmatter `['yaml']` + remark-gfm — 원문 **전체** · 줄 = 파일 줄)
      - 첫 자식이 `yaml` 노드이고 그 끝 줄이 우리 닫는 울타리 줄이어야 한다. 아니면 `(file, frontmatter, fence)` · 그 파일 끝(VD-T090-6)
      - 블록 안 `---␠` · `---<TAB>` 줄(`---` 뒤 공백 · 탭만)은 micromark가 닫는 울타리로 읽는다(〔소스〕 micromark-extension-frontmatter@2.0.0 `lib/syntax.js:295–:370` — 닫는 줄의 앞 들여쓰기는 받지 않고 뒤 공백 · 탭은 받는다). 그래서 yaml 노드가 그 줄에서 끝나고, 이 대조가 `(file, frontmatter, fence)` 하나로 먼저 끝낸다 — D5 판독 1까지 가지 않는다(lx-7 · mx-1 · 〔V-A-1〕 · 〔V-B-2〕).
      - **울타리 판정은 이 대조까지 YAML · 스키마보다 앞에 둔다**(〔A-8〕 (b)). 늦은 `fence`가 스키마 issue 뒤에 붙지 않게 하려는 것이다.
   4. YAML(D5). 실패하면 `(file, frontmatter, yaml)` · 그 파일 끝
      - 3-2 · 3-3 · 3-4에서 끝난 파일의 내용 단계 issue는 하나다(머리 :45). 파일 단위 issue(`name` · `ko-missing`)는 따로 센다(〔A-8〕 (a) — D16).
   5. 스키마 · zod 밖 규칙(D5) — 계속 진행한다
   6. 거부 규칙 넷(D6) — 3-3의 트리를 그대로 쓴다
4. 묶음 · 교차 파일 규칙(D9): `ko-missing` · 변형 `pubDate` · `change`
5. issue가 하나라도 있으면 정렬(D4) → `ContentValidationError` 하나를 던진다. **메모에 보관하지 않는다.**

**B. 컴파일(issue 0일 때만)**

6. 파일마다: remark-rehype → rehype-slug → 헤딩 수집 → Shiki(코드 블록이 있을 때만) → html · 읽기 시간(D7)
7. 항목(모든 lang · draft 포함)을 메모에 보관한다(D8).

**C. 호출마다**

8. draft 거름 → lang 고르기 → translations → 정렬 → `structuredClone`으로 돌려준다(D9)

- 본문 5절 검증은 **넣지 않는다**(정정 노트 1 — 로더 · TDD 모두 0).

### D4 오류 · 순서 · code · 입력 값 0

**클래스**
- `class ContentValidationError extends Error`
- 생성자는 `super(message)`만 한다. **`{ cause }`를 넘기지 않는다.**
- 자기 속성은 `issues`와 클래스 필드 `name = 'ContentValidationError'`뿐이다. `issues`는 배열과 각 issue 객체를 모두 `Object.freeze`한다(키 `file` · `field` · `code` · `line`, `line`은 body issue에만 — lx-7이 `Object.isFrozen`으로 고정 · 〔V-B-15〕).
- 그래서 `Reflect.ownKeys` ⊆ {issues, name, message, stack}이다(머리 :49 · loader.test.ts:175 · :188).
- `message` = issue마다 `` `${file}${line ? ':' + line : ''}: ${field} (${code})` ``를 `'\n'`으로 잇는다. 머리말 · 요약 · 끝 줄바꿈 0(머리 :46 · :160 · :208).

**`file`**
- root 상대 `/` 경로다. root는 `.`, 컬렉션 디렉터리는 `study/`다(머리 :32).
- 이름에 FILE_RE 문자(`[A-Za-z0-9._-]`) 밖 글자가 있는 `*.mdx`(공백 · 한글 · `+` 등 — loader.test.ts:156)는 그 파일 대신 컬렉션 디렉터리(`study/`)를 file로 쓰고 `(study/, file, name)` **하나만** 낸다.
  - 그 파일의 다른 검증은 돌리지 않는다(〔A-2〕 · 〔90-7e〕). 꼴 계약을 지키면서, 어느 파일인지 모를 내용 issue가 `study/`로 섞이지 않게 하려는 것이다.
  - 여럿이면 각각 하나씩 낸다(readdir Ordinal 순).

**`field`** — zod 경로를 `.`로 잇는다. 그 밖은 머리 :33–:35 그대로다.
- series 짝 위반 → 빠진 쪽 키
- `sources.<i>`(path · url 정확히 하나가 아님)
- 변형 어긋남 → 그 변형 파일의 키
- 모르는 키 → 그 키 이름(중첩이면 경로 `sources.<i>.<키>` — 머리 :35 「그 키 이름」을 경로로 읽는다 · D16 · lx-8b)
- 이름 · ko-missing · not-regular → `file`

**`line`**
- body issue는 필수다(노드 시작 줄 · 파일 첫 줄 = 1).
  - 위치 없는 노드(mdast 변환이 만든 링크 · 쪼개진 text)의 「노드 시작 줄」은 D6 「위치 없는 노드의 줄」 규칙으로 얻는다. 머리 :38 「line = 노드 시작 줄」을 지키는 해석이다(D16 :37–:41 · 〔V2-2〕).
- 그 밖 issue에는 싣지 않는다(머리 :37–:38 · :198 — 선택 칸).

**code 어휘**(field가 `body` · `frontmatter` · `file`이면 규칙 이름 — 머리 :37. 나머지는 T090이 정한다 · 모두 `CODE_RE`(:158) 안 · 상수 · 입력 0)

| 조건 | field | code |
|---|---|---|
| 필수 키 없음(원본 객체에 키 없음) | 그 키 | `missing` |
| 타입이 다름(문자열 · 정수 · 불리언 · 배열 · 객체 아님 — 키는 있고 값이 null인 `title:` 포함) | 경로 | `type` |
| 빈 문자열 · 공백만(title · description · series · tags[i] · sources[i].title) | 경로 | `empty` |
| 꼴(날짜 · change · path · url — url은 host(zod `domain`) · zod 밖 원 문자열 규칙 · userinfo 포함) | 경로 | `format` |
| seriesOrder ≤ 0 · 안전 정수 밖 | `seriesOrder` | `range` |
| 모르는 키 | 키 경로 | `unknown-key` |
| series · seriesOrder 한쪽만 | 빠진 쪽 | `series-pair` |
| updatedDate < pubDate | `updatedDate` | `date-order` |
| sources 원소의 path · url이 정확히 하나가 아님 | `sources.<i>` | `source-kind` |
| 변형 pubDate · change ≠ ko(blog · projects는 한쪽만 `change`인 경우 포함) | 그 키(변형 파일) | `variant-mismatch` |
| 그 밖 zod issue | 경로 | `invalid` |
| 파일 단위 | `file` | `encoding` · `name` · `ko-missing` · `not-regular` |
| 프런트매터 단위 | `frontmatter` | `fence` · `yaml` |
| 본문 | `body` | `raw-html` · `esm` · `expression` · `unsafe-url` |
| root · 컬렉션 부재 | `root` · `collection` | `missing`(머리 :15–:16) |

- `not-regular` = 이름이 `.mdx`로 끝나는(대소문자 무관 · FILE_RE 안 이름) 정규 파일 아닌 항목이다 — 디렉터리 · 심볼릭 링크 · junction · 그 밖. 따라가지 않고 읽지 않는다(〔A-1〕 · 〔90-7d〕). 그 항목의 유일한 issue다. FILE_RE 밖 이름이면 `(<컬렉션>/, file, name)`이 먼저다(D8 스캔 3 · 〔V-A-9〕).
- 한 경로에는 issue를 하나만 둔다. 같은 경로의 zod issue가 여럿이면 표에서 가장 위 행 하나다. zod 밖 규칙(D5)은 그 경로에 zod issue가 없을 때만 낸다(lx-8b `title: ""` · sx-7 `javascript:x` + 탭).
- `invalid`는 위 행에 맞지 않는 zod issue의 대체 칸이다. 지금 스키마에서는 닿는 입력을 찾지 못했다(추론 — 빌더가 찾으면 lx-8b에 사례를 더한다).
- lx-8b가 행마다 사례를 둔다(〔A-3〕).

**순서**(머리 :31 · N-7 「file(Ordinal) → 문서 순」을 이렇게 구체화한다 — 〔A-10〕)
1. `file`을 Ordinal로 비교한다(`a < b ? -1 : a > b ? 1 : 0`). `localeCompare` · `Intl.Collator`는 쓰지 않는다.
2. 같은 파일 안 「문서 순」
   1. 파일 단위: `name` → `encoding` → `ko-missing`
      - 한 파일에 함께 나는 조합은 `name` + `encoding` · `encoding` + `ko-missing`이다. 이름 위반 파일은 묶음에서 빠지므로 `name`과 `ko-missing`은 함께 나지 않는다.
      - `not-regular`는 홀로 난다.
   2. 프런트매터 단위(`fence` 또는 `yaml` — 있으면 그 하나뿐)
   3. 프런트매터 필드 issue
      - **문서에 나온 최상위 키 순서**다(YAML → `toJS` 객체의 키 삽입 순서 = 문서 순 · 숫자 꼴 키는 D5 키 규칙으로 없다).
      - 없는 키(`missing` · `series-pair`의 빠진 쪽)는 그 뒤에 content.md 계약 키 순(title … sources)으로 둔다.
      - 같은 최상위 키 안은 경로 순이다. 배열 첨자는 **수**로 비교한다(`sources.2.url` < `sources.10.url` — field 문자열 정렬 금지). 하위 키는 문서 순이다.
   4. 본문 issue: 줄 → 열 → 같은 줄 · 같은 열이면 머리 :38의 규칙 순(`raw-html` → `esm` → `expression` → `unsafe-url`)이다. 예: 한 줄 `import {a} from 'b'` = `esm` → `expression`. 위치 없는 노드의 줄 · 열은 D6 「위치 없는 노드의 줄」(열 — §6-9)로 얻는다
- lx-7이 넷(첨자 수 비교 · 파일 단위 순 · 같은 줄의 열 순 · 같은 줄 · 같은 열 동률)을 고정한다. 열 순 = 한 줄 `{x} <b>` → `expression` → `raw-html`(〔V-B-4〕).

**입력 값 0 구현 규율**(머리 :47–:49 · 정정 노트 3)
- 오류 객체 · issues · message에 원문 · 프런트매터 값 · URL · YAML · zod · TextDecoder · unified 오류 메시지를 싣지 않는다.
- 라이브러리 오류 객체를 cause · 속성으로 붙이지 않는다.
- zod issue 객체에는 `input`(원 값)이 실린다(〔B-4〕). 그래서 zod issue는 경로 · code 매핑에만 쓰고 객체를 싣지 않는다.
- yaml `toJS()`의 미해결 별칭 예외는 별칭 이름(입력)을 싣는다(〔B-3〕). 그래서 앵커 · 별칭 자체를 `yaml`로 막고(D5), 남는 `toJS()` 예외도 원 예외를 버리고 `yaml`로 바꾼다.
- 라이브러리는 `console.*` · `process.stdout/stderr` · `process.emitWarning`을 쓰지 않는다. 예외는 schema.ts CLI 블록의 `process.stdout` 한 곳 · `process.stderr` 한 곳이다(lx-18 · 〔V-A-2〕).
- **`YAML.parse` 금지**(D5 — 경고가 `process.emitWarning`으로 stderr에 나간다).
- 프로그래머 오류(`TypeError`)의 메시지는 값 없는 상수다(예: `getCollection: unknown collection`).
- 위 규율을 lx-18(정적)과 바늘 사례가 지킨다.

### D5 프런트매터 — BOM · 줄 · 울타리 · YAML · 날짜 · 스키마 · zod 밖 규칙

**BOM(N-3)**
- `ignoreBOM: true`로 U+FEFF를 남긴다.
- 그래서 첫 줄이 U+FEFF + `---`이면 울타리 규칙에서 `fence`가 된다. ld-14 생성 사례가 고정한다.

**줄**(〔A-9〕 ② — 머리 :42 「첫 줄」을 CommonMark 줄로 읽는다)
- 줄 끝 = `\r\n` · `\r` · `\n`이다. CommonMark · micromark와 같아 VD-T090-6 경계가 갈리지 않는다.
- 그래서 CRLF로 저장된 노트도 정상이다. 편집기가 새 노트를 CRLF로 저장할 수 있다 — .gitattributes:2는 체크아웃만 LF로 만들고, 이 기기는 `core.autocrlf=true`다(〔A-9〕). 그래도 로컬과 CI(체크아웃 LF)의 결과가 같다.

**울타리**(디코드한 원문으로 판정하고 remark에 맡기지 않는다 — 〔R1 ④〕 함정)
- 첫 줄이 정확히 `---`여야 한다(BOM · `---js` · `--- `는 `fence`).
- 닫는 울타리 = 둘째 줄부터 **정확히 `---`**인 첫 줄이다. 없으면 `fence`다.
- 뒤 공백 · 탭이 붙은 `---␠` · `---<TAB>` 줄은 우리 닫는 줄이 아니지만 micromark는 닫는 줄로 읽는다 → D3 3-3이 `fence`로 끝낸다(아래 판독 1 · VD-T090-6 · 〔V-A-1〕).
- YAML 블록 = 여는 줄과 닫는 줄 사이의 줄들을 `\n`으로 다시 이은 것이다. 줄 끝 꼴과 무관하게 같은 블록이 된다.
- 뒤이어 D3 3-3이 remark `yaml` 노드 끝 줄과 닫는 울타리 줄을 대조한다(VD-T090-6).

**YAML 판독 규율**(yaml 2.9.1)
- 판독
  - `parseDocument(block, { version: '1.2', schema: 'core', uniqueKeys: true, strict: true, prettyErrors: false, logLevel: 'error' })`
  - 기본값 근거: 〔소스〕 https://cdn.jsdelivr.net/npm/yaml@2.9.1/dist/doc/Document.js :35–:42 — `logLevel: 'warn'` · `prettyErrors: true` · `uniqueKeys: true` · `version: '1.2'`
  - 아래 중 하나면 `yaml`이다.
    1. 블록에 `^(?:---|\.\.\.)(?:[ \t]|$)` 줄이나 `^%` 줄이 있다(지시자 · 추가 문서 표식).
       - 파일 파이프라인에서 `---` + 공백 · 탭만인 줄(`---␠` · `---<TAB>`)은 여기까지 오지 않는다. micromark가 그 줄을 닫는 울타리로 읽으므로 D3 3-3이 `(file, frontmatter, fence)`로 먼저 끝낸다(lx-7 · 〔V-A-1〕 · 〔V-B-2〕). 정확히 `---`인 줄은 우리 닫는 울타리라 블록 안에 없다.
       - 그래서 파일에서 판독 1이 잡는 것 = `--- x`(뒤에 내용) · `...` · `%` 줄이다. YAML 블록 함수 단위(mx-2)에서는 `---␠` 줄도 판독 1이 잡는다.
       - `schema: 'core'`를 명시하므로 `%YAML 1.1`이 와도 날짜 · `yes`는 문자열로 남는다(〔소스〕 yaml@2.9.1 `dist/doc/Document.js:45–:53` · `:284–:288` — 명시한 `schema`가 이긴다). 지시자는 버전 · 태그 해석을 바꾸는 판독 규율 밖의 꼴이라 통째로 막는다.
       - yaml 자체 오류 · 경고와 겹치는 꼴(D13 mu-59 동등 후보): `---` 줄 없는 `%` 줄(MISSING_CHAR — `dist/compose/composer.js:153–:154`) · 모르는 지시자(BAD_DIRECTIVE 경고 — `dist/doc/directives.js:93–:95`) · 뒤에 내용이 있는 `...`(MULTIPLE_DOCS — `dist/public-api.js:50`) · `--- title: x`(같은 줄 블록 매핑 — MISSING_CHAR · `dist/compose/compose-doc.js:28–:31`). 판독 1만 잡는 꼴 = 블록 마지막 줄 `...` · `%YAML 1.1` + `--- ` 줄 + 매핑(블록 함수 단위) · 블록 안 `--- !!map` 줄 + 다음 줄 매핑(micromark는 닫지 않음 · yaml은 받음 — 파일 단위 · lx-7 · 〔소스〕 yaml@2.9.1 `dist/compose/compose-doc.js:26–:31` — 표식 줄 뒤 줄바꿈이 있어 MISSING_CHAR가 나지 않는다 · 〔V2-7〕)이다.
    2. `doc.errors.length > 0` 또는 **`doc.warnings.length > 0`** — `!!js/function`은 오류가 아니라 경고다(〔R1 ④〕 — compose-scalar · VD-T090-5)
    3. 최상위가 매핑이 아니다(빈 블록 · 스칼라 · 목록)
    4. 매핑 키(중첩 포함)가 문자열 스칼라가 아니거나(컬렉션 키 · 수 · 불리언 · null 키), 키 문자열이 `^[A-Za-z][A-Za-z0-9_]{0,63}$` 밖이다(`a-b` · 한글 · `1` · `<<` · 65자 이상).
       - **따옴표 키는 허용한다**(평문 · 작은따옴표 · 큰따옴표 스칼라 모두 — 〔A-9〕 ②). 키 글자 규칙만 남기고 평문 스칼라 요구는 두지 않는다.
       - 중복 키는 따옴표와 무관하게 `uniqueKeys`가 오류로 잡는다.
    5. **앵커 · 별칭이 하나라도 있다**(〔B-3〕 — `YAML.visit`로 Alias 노드 또는 `anchor`가 붙은 노드를 찾는다)
       - 별칭 폭탄과 미해결 별칭이 모두 구조로 닫힌다.
       - 미해결 별칭은 `doc.errors`에 모이지 않고 `toJS()`까지 가서, 별칭 이름을 실은 예외를 던진다(〔소스〕 yaml@2.9.1 `dist/nodes/Alias.js:76–:79` · `dist/compose/compose-node.js:97–:109`).
    6. `doc.toJS()`가 던진다(남는 방어 — 원 예외는 버린다)
- 까닭(〔소스〕 https://cdn.jsdelivr.net/npm/yaml@2.9.1/dist/)
  - `log.js`의 `warn()`은 `logLevel`이 `debug` · `warn`일 때 `process.emitWarning(warning)`을 부른다.
  - `public-api.js:71`에서 `parse()`는 문서 경고를 모두 그 경로로 보낸다.
  - `nodes/addPairToJSMap.js:57`은 컬렉션 키를 문자열로 만들며 키 글자를 담은 경고를 낸다.
  - 그래서 `parse()`를 쓰면 원문 줄과 키가 stderr(공개 CI 로그)로 나간다.
  - `logLevel: 'silent'`은 `MULTIPLE_DOCS` 오류까지 지우므로(`public-api.js:49`) `'error'`를 쓴다.

**날짜**
- YAML 1.2 core에서 따옴표 없는 날짜는 문자열이다. Date로 바꾸지 않는다(정정 노트 2).
- `z.iso.date()`로 실재하는 날짜(달 · 윤년)를 검사하고, 출력은 같은 문자열이다.
- `updatedDate ≥ pubDate`는 문자열 비교다(ISO 꼴 = 사전순).

**zod 스키마**(`z.strictObject` — content.md:9–:25 + data-model.md:233–:247)

| 키 | 스키마 | 필수 |
|---|---|---|
| title · description | `z.string().min(1).regex(NONBLANK)` | ✓ |
| pubDate · updatedDate | `z.iso.date()` | pubDate ✓ |
| tags | `z.array(z.string().min(1).regex(NONBLANK))`(빈 배열 허용) | ✓ |
| series | `z.string().min(1).regex(NONBLANK)` | |
| seriesOrder | `z.int().positive()` | |
| draft | `z.boolean()` | ✓ |
| change | `z.string().regex(CHANGE)` · `CHANGE` = `^[0-9]{3}-[a-z0-9-]+$(?!\n)` | study ✓ · blog · projects 선택(〔90-3〕) |
| sources | `z.array(z.strictObject({ title, path?, url? }))` | ✓ |

- **로더가 정하는 패턴**(change · path · url · 비어 있지 않음)은 events.md:28 꼴로 쓴다(〔A-22〕).
  - 명시 문자 클래스만 쓴다(`\d` · `\w` · `\s` 0). 문자 클래스 밖의 이스케이프하지 않은 `.`(아무 글자)은 0이다 — `\.`과 클래스 안 `.`은 리터럴이다. 끝 앵커가 있는 패턴(change · path)은 `$(?!\n)`로 끝낸다. url(접두 패턴) · NONBLANK(앵커 없는 검색)에는 `$`가 없다(〔V-A-13〕 · 〔V-B-12〕).
  - 패턴 문자열은 ASCII(0x20–0x7E)뿐이다. U+ 범위는 날 글자 대신 역슬래시-u 꼴 ASCII 이스케이프로 조립한다(D15 · sx-1 · 〔V-B-10〕).
  - ajv(`u`)와 Python `re.search`가 같은 뜻으로 읽게 하려는 것이다(D10).
  - content.md · data-model의 `\d` 표기는 사람 계약으로 두고 코드 패턴만 바꾼다(뜻이 같다).
- `NONBLANK` = 공백 아닌 글자가 하나 이상이다. 부정 문자 클래스 하나로 쓴다.
  - 빼는 글자: 탭 · LF · VT · FF · CR · 공백 · U+00A0 · U+1680 · U+2000–U+200A · U+2028 · U+2029 · U+202F · U+205F · U+3000 · U+FEFF(ECMAScript `\s` 집합과 같다)
  - 앵커가 없는 검색이라 「하나 이상 있다」로 읽힌다.
- `path` = `^SEG(?:/SEG)*$(?!\n)`
  - SEG = `(?:[A-Za-z0-9_-][A-Za-z0-9._-]*|\.[A-Za-z0-9_-][A-Za-z0-9._-]*|\.\.[A-Za-z0-9._-]+)`
  - SEG에는 룩어라운드가 없고 N-13과 같은 집합이다. `.` · `..` 세그먼트 0 · `:` 0. JSON Schema `pattern`으로도 같은 판정이 실린다(sx-6).
- `url` = `z.httpUrl().regex(/^[Hh][Tt][Tt][Pp][Ss]?:\/\//)`
  - httpUrl만이면 JSON Schema에는 `format: "uri"`로만 나가 `javascript:`가 통과한다. 그래서 패턴을 함께 둔다.
  - **내보내기에서는 url 스키마에 `.meta({ format: 'uri' })`(또는 동등한 `toJSONSchema` `override`)로 `format: "uri"`를 다시 싣는다.** zod 4.6.7은 `.regex()`가 붙으면 내보낸 JSON Schema에서 url의 `format`을 지우기 때문이다(〔소스〕 zod@4.6.7 `v4/core/json-schema-processors.js:120–:127` — 「custom pattern overrides format」 · `delete json.format`). 둘 다 `{type:"string", pattern:"^[Hh][Tt][Tt][Pp][Ss]?:\\/\\/", format:"uri"}`를 내고 zod 런타임 판정은 바뀌지 않는다(〔V2-1 탐침〕 · sx-1 · 〔V2-1〕).
  - 〔소스〕 zod@4.6.7 `v4/core/json-schema-processors.js` formatMap `url: "uri"` · `v4/classic/schemas.js:338–:345` ZodURL ⊂ ZodStringFormat ⊂ `_ZodString`(`.regex` 있음) · `:401–:407` httpUrl = protocol `httpProtocol` + hostname `domain`
  - **host = 공개 도메인 이름**(〔V-A-5〕 — 새 규칙이 아니라 zod `httpUrl`이 이미 하는 일을 문서화하고 시험한다): zod는 `URL` 해석값의 `hostname`을 `domain`(`^(?=.{1,253}$)(…\.)+[a-zA-Z]{2,63}$`)으로 본다 → localhost · IP 주소 · 끝 점 FQDN(`example.com.`) · IDN 최상위 도메인(`xn--` TLD — 예: `.한국`)이 `format`이 된다(〔소스〕 zod@4.6.7 `v4/core/regexes.js:63` · `v4/core/schemas.js:255–:258` · `:295` — 소스 판독 · 실행 확인은 VD-T090-1 · sx-7). 뒤 둘은 받아들인 한계다(§5-1 23). 본문 링크에는 host 규칙이 없다(〔B-5〕 — 비대칭 · D6).
  - zod URL 검사는 입력을 `trim()`하고, 통과하면 탭 · 줄바꿈을 지운 값으로 바꾼다. 뒤의 `.regex()`는 바뀐 값에 돈다(〔소스〕 zod@4.6.7 `v4/core/schemas.js:225–:254` · `:263–:319` — 〔B-4〕). 그래서 원 문자열 규칙을 zod 밖에 둔다(아래).
- `sources` 원소는 **한 strict 객체 + zod 밖 규칙**으로 짠다. union으로 짜면 url 꼴 오류가 `sources.0`으로 올라가 ld-10 009–011이 깨진다(〔R1 ③-11〕).

**zod 밖 규칙**(`schema.ts` 함수 · JSON Schema에 없다)
- series 짝
- 날짜 순서(두 값 모두 꼴이 맞을 때만)
- sources 정확히 하나(원소가 객체일 때만)
- **url 원 문자열**(〔B-4〕): Unicode 공백(`NONBLANK`가 빼는 집합) · C0 제어(U+0000–U+001F) · DEL(U+007F) · C1(U+0080–U+009F) · `\`가 하나라도 있으면 `(sources.<i>.url, format)`이다. D6 `unsafe-url` 1단계와 같은 집합이다. 판정은 zod가 바꾸기 전 원 값으로 한다. sx-7이 `\` · U+0001 · DEL · U+0085 · U+FEFF까지 고정한다(〔V-B-6〕).
- **url userinfo**(〔B-5〕): http(s) URL의 authority에 `@`가 있으면 `(sources.<i>.url, format)`이다.
  - authority = 스킴 `:` 뒤의 `/`를 모두 건너뛴 자리부터 첫 `/` · `?` · `#` 앞까지다. WHATWG 특수 스킴은 슬래시 개수와 무관하게 authority를 읽기 때문이다.
  - 허용 쪽 경계: path · query · fragment의 `@`는 authority 밖이라 허용이다(`https://www.npmjs.com/package/@shikijs/rehype` · `https://example.com/?q=a@b` · `https://example.com/#a@b` — sx-7 · mx-8 · 〔V-B-3〕).
  - content.md:31 「Never include secrets, tokens」 가운데 기계로 판정할 수 있는 부분이다.
- 한 경로에 issue 하나: 그 경로에 zod issue가 있으면 zod 밖 규칙은 내지 않는다(D4).
- `change = slug`는 **두지 않는다**. 007.en · no-number에 issue가 하나 더 생기고(〔R1 ③-11〕), `-2` 노트 규칙(content.md:27)과도 맞지 않는다.

### D6 본문 거부 규칙 구현(모든 컬렉션 — D4 t086:307–:314 · 머리 :38–:41 · N-2 · N-7)

**순회**
- `unist-util-visit`로 mdast 전체를 문서 순으로 돈다(최상위만 돌면 안 된다 — 정정 노트 4 ⓕ).
- `yaml` 노드는 건너뛴다. `code` · `inlineCode` 값은 보지 않는다.
- 위반은 `{ code, line, column }` 배열로 모은다 — 순수 함수다(〔90-8〕). VFileMessage를 만들지 않으므로 Error 하위 객체 · `ancestors` · stack 0이다.

| code | 판정 | 개수 · line |
|---|---|---|
| `raw-html` | `html` 노드 전부(흐름 · 글줄) | 노드마다 하나 · 노드 시작 줄(글줄의 여는 · 닫는 태그는 각각 — 023 · 027 둘씩) |
| `esm` | 「줄」 = 컨테이너 기준(〔A-7〕). `paragraph`의 직계 `text` 자식 값에서 **줄 머리**이면서 그 줄의 첫 inline인 자리를 본다. 줄 머리 = 문단 첫 자식의 시작 · `break` 바로 뒤 자식의 시작 · 값 안 줄 끝(`\r\n` · `\r` · `\n`) 바로 뒤. CommonMark가 연속 줄의 컨테이너 접두(`> ` · 목록 · 각주 정의 들여쓰기)와 앞 공백을 이미 벗긴다. 그 자리 글이 `/^(?:import\|export)[ \t{*]/`에 맞으면 위반이다 | 줄마다 하나 · 그 줄(text 시작 줄 + 앞선 줄 끝 수 — text에 위치가 없으면 시작 줄은 아래 「위치 없는 노드의 줄」) |
| `expression` | `text` 노드 값에 `{` · `}`가 있다. `image` · **`imageReference`**의 `alt`, `link` · `image` · `definition`의 `title`에 `{` · `}`가 있다 | 노드마다 하나 · 노드 시작 줄(007 두 줄 문단 → 13 하나 · 위치 없는 노드는 아래 「위치 없는 노드의 줄」) |
| `unsafe-url` | `link` · `image` · `definition`의 `url`(문자 참조 해석 뒤 값). 판정은 아래 순서 | 노드마다 하나 · 노드 시작 줄(definition은 정의 줄 — 013 → 15 · 위치 없는 노드는 아래 「위치 없는 노드의 줄」) |

- esm 정규식 원문(표 칸의 `\|`는 GFM 표 이스케이프다 — 〔V-A-13〕): `/^(?:import|export)[ \t{*]/`

**위치 없는 노드의 줄**(① 실측 · 〔V2-2〕 — `expression` · `unsafe-url` · `esm` 모두)
- 토크나이저가 거절하고 mdast 변환(mdast-util-gfm-autolink-literal 2.1.2 · mdast-util-find-and-replace 3.0.5)이 링크를 만든 경우, 새 링크와 쪼개진 text 노드는 position이 없다(〔소스〕 mdast-util-find-and-replace@3.0.5 `lib/index.js:137–:170` · 〔① 탐침〕 7-5–7-9 · 7-x1–7-x3).
  - 예: 닫히지 않은 `[` 뒤(토크나이저는 앞에 짝 없는 `[`가 있으면 리터럴을 만들지 않는다 — 〔소스〕 micromark-extension-gfm-autolink-literal@2.1.0 `lib/syntax.js:831–:839`) · `"` 바로 뒤 `www.`(토크나이저 previousWww는 `( * _ [ ] ~` · 공백만 받는다 — 같은 파일 `:793–:795`. 변환은 유니코드 구두점 전부를 받는다 — mdast-util-gfm-autolink-literal@2.1.2 `lib/index.js:408–:414`)
- **규칙**: 위치 없는 노드의 줄 = 같은 부모에서 앞선 위치 있는 형제의 끝 줄(없으면 부모의 줄 — 부모도 위치가 없으면 같은 규칙으로 재귀) + 그 사이 위치 없는 형제들의 text 값(자손 포함)에 든 줄 끝 수(`\r\n` · `\r` · `\n` 각각 하나). 결과는 가장 가까운 위치 있는 조상의 끝 줄을 넘지 않게 자른다.
- **열(§6-9)**: 같은 순회로 시작 점(줄 · 열)을 함께 얻는다. 출발 = 앞선 위치 있는 형제의 끝 점(없으면 부모의 시작 점 — 재귀)이고, 사이 위치 없는 형제들의 text 값(자손 포함)을 따라 줄 끝마다 다음 줄 1열, 그 밖 글자는 UTF-16 code unit 하나마다 열 + 1로 나아간다(micromark 열과 같은 단위 — 〔열 탐침〕 `unit`). 줄을 자르면 열은 그 조상의 끝 열이다.
  - 열은 D4 정렬(줄 → 열 → 규칙 순)에만 쓴다(issue에 열은 없다). 앞선 위치 있는 노드는 run 시작 점보다 앞이고 뒤따르는 위치 있는 노드는 run 끝보다 뒤라, 같은 줄의 위치 있는 issue와 문서 순서(머리 :31)가 맞는다. 문자 참조 · 이스케이프로 값이 원문보다 짧아도 순서는 지켜진다(문자 참조로 풀린 줄 끝은 예외 — 아래 한계).
  - lx-7 순서 사례 둘(〔열 탐침〕 `order-A` · `order-B`)과 mu-77 · mu-78이 고정한다.
- break 노드는 끝 위치가 다음 줄 머리다. mdast-util-from-markdown이 줄 끝을 break에 넣기 때문이다(〔소스〕 mdast-util-from-markdown@2.1.0 `lib/index.js:732–:740`). 그래서 이 규칙이 그대로 맞는다.
- `position`을 그대로 읽지 않는다. 위치 없는 노드에서 `node.position.start.line`은 던지고, 안전하게 읽어도 line이 비어 나온다(〔① 탐침〕 7-x1–7-x3 — 대체 규칙 없는 D6 독립 구현의 후보 = `expression@null` · `unsafe-url@null` · `esm@null`).
- 한계: 위치 없는 run 안에서 문자 참조로 풀린 줄 끝(`&#10;` · `&#13;`)도 줄 끝으로 센다 → 조상 끝 줄에서 자른다(§5-1 24).
- mx-8 7-x1–7-x4가 고정한다.

`unsafe-url` 판정 순서:
1. Unicode 공백(ECMAScript `\s` 집합 — NBSP · U+FEFF 포함) · C0 제어(U+0000–U+001F) · DEL(U+007F) · C1(U+0080–U+009F) · `\`가 하나라도 있으면 위반이다.
2. `//`로 시작하면 위반이다.
3. `#`로 시작하면 허용이다.
4. `^([A-Za-z][A-Za-z0-9+.-]*):` 스킴이 있으면, 소문자가 http · https · mailto일 때만 허용이다.
   - 단 http · https이면 authority(스킴 `:` 뒤의 `/`를 모두 건너뛴 자리부터 첫 `/` · `?` · `#` 앞까지)에 `@`가 있으면 위반이다(userinfo — 〔B-5〕 · 〔90-7f〕). mailto는 해당하지 않는다. path · query · fragment의 `@`는 허용이다(mx-8 · 〔V-B-3〕).
5. 그 밖(스킴 없는 상대 참조 · 빈 값)은 허용이다.

`linkReference` · `imageReference`의 url은 보지 않는다. 정의(definition) 쪽을 본다.

- `imageReference.alt`는 머리 「image alt」의 참조형이라 같은 뜻으로 읽는다(mx-8 · 〔90-6〕 계열).
- **자동 링크**: GFM 자동 링크 리터럴도 link 노드라 허용 목록이 적용된다(토크나이저가 만든 위치 있는 링크 · 변환이 만든 위치 없는 링크 모두 — 위 「위치 없는 노드의 줄」).
  - **산문 `xmpp:a@b.c` · 산문 `http:user@example.com` = 0 issue**(사실 — ① 실측으로 바로잡음 · 〔V2-2〕). 설치 판에서는 토크나이저(micromark-extension-gfm-autolink-literal 2.1.0)가 이메일 부분을 먼저 `mailto:` 링크로 만들고 `xmpp:` · `http:`는 앞 text에 남는다(〔소스〕 `lib/syntax.js:81` 「To do: `mailto:`, `xmpp:` protocol as prefix」 · `:811–:817` — 이메일 앞 글자 검사가 `:`를 막지 않는다 · 〔① 탐침〕 7-1 · 7-1b · 7-2). mdast 변환의 xmpp 정규식(mdast-util-gfm-autolink-literal@2.1.2 `lib/index.js:157` · `:307`)은 그 뒤라 맞출 것이 없다. 결과는 text + mailto 링크라 무해하다. r2의 「산문 `xmpp:a@b.c`는 `unsafe-url`(사실 — 〔B-16〕)」은 설치 판에서 거짓이었다.
  - `xmpp:` URL 거부는 명시 링크 `[x](xmpp:a@b.c)` → `unsafe-url`, 그리고 변환 경로(닫히지 않은 `[` 뒤 xmpp → 위치 없는 링크 → `unsafe-url` · 줄은 위 줄 대체 규칙 — 〔① 탐침〕 7-5 · 7-x2)로 잰다.
  - 산문 userinfo 거부는 `https://user@example.com` 꼴로 잰다(토크나이저 링크 · 위치 있음 → `unsafe-url` — 〔① 탐침〕 7-10).
  - mx-8이 고정한다.
- **문자 참조 · 날 글자**(사실 — 〔V-B-6〕 · mx-8 · D12 ① 9)
  - 수 문자 참조 `&#127;`(DEL) · `&#133;`(C1) · 탭 · LF · FF · CR 밖의 C0는 micromark가 U+FFFD로 바꾼다(〔소스〕 micromark-util-decode-numeric-character-reference@2.0.2 `index.js:17–:29`). 그래서 DEL · C1은 1단계에 날 글자로만 닿는다. `&#xFEFF;`는 U+FEFF로 해석된다.
  - 꺾쇠 없는 대상의 날 DEL은 명시 링크가 되지 않는다(대상이 http(s)면 GFM 자동 링크 리터럴이 대신 위치 있는 link를 만들어 결국 `unsafe-url`). 명시 링크 경로는 꺾쇠 대상(`[x](<…>)`)으로 잰다(〔V2-3〕).
    - 〔소스〕 꺾쇠 없는 대상은 ASCII 제어를 받지 않는다 — micromark-factory-destination@2.0.1 `index.js:70–:73` · `:179–:184`. 꺾쇠 대상은 DEL을 받는다 — 같은 파일 `:119–:127`.
    - 〔소스〕 자동 링크 대신: 명시 링크가 실패하면 여는 `[`가 `_balanced`로 표시되고(micromark-core-commonmark@2.0.4 `lib/label-end.js:243` · `:313–:314`), 뒤의 `(` 다음에서 리터럴이 시작될 수 있으며(micromark-extension-gfm-autolink-literal@2.1.0 `lib/syntax.js:803–:805`), 경로는 공백 · 줄 끝 전까지 DEL을 포함해 먹는다(같은 파일 `:567–:591`).
  - 날 U+0085 · NBSP는 꺾쇠 없는 대상에서도 link가 된다.
- **보수적인 곳(기록)**
  - 이스케이프 `\{` · `&#123;`도 text에서는 `{`라 `expression`이다.
  - 컨테이너 안 · 목록 첫 줄의 `import …` 산문도 `esm`이다. MDX에서는 최상위 문단만 ESM이고 컨테이너 안은 실행되지 않으므로 보안 영향은 0이다.
  - 문자 참조로 만든 줄 바꿈(`&#10;`) 뒤의 `import`도 줄 머리로 본다. 그때 line은 실제 줄과 어긋날 수 있다.
  - 저자는 코드 스팬을 쓴다(§5-1).
- **과잉 가드 금지**(D12 ⓓ t086:651): 코드 스팬 · 펜스 속 `<` · `{` · `import`와 `&lt;b&gt;`(text 「<b>」)는 위반이 아니다. 099 대조와 ld-1이 지킨다.
- **넣지 않는 것(기록)**
  - 본문 내부 주소(localhost · IP) 거부(〔B-5〕). 산문 속 글자는 못 막는 반쪽 방어라서다. 프런트매터는 zod `domain`이 막는다 — 본문과 비대칭이다(D5 url host · 〔V-A-5〕).
  - definition · reference · footnote의 label · identifier 속 `{}` 검사(〔B-15〕). 렌더 영향이 0이다 — 라벨은 출력되지 않고, 각주 id는 `normalizeUri` + `user-content-` 접두를 거친다.
- **실제 노트**(〔R1 ⑦〕): 001:26 · 002:29 · :30(2백틱 스팬 속 단일 백틱) · :32 · :35 · 002:43(표 칸의 `\|` · `<!-- … -->`)은 모두 inlineCode여야 한다. VD-T086-3에서 실물로 잰다.

### D7 산출 — html · 헤딩 · Shiki · 읽기 시간

**remark-rehype**
- 옵션: `{ allowDangerousHtml: false, footnoteLabel: FOOTNOTE_LABEL[lang], footnoteBackLabel: FOOTNOTE_BACK_LABEL[lang] }`
  - `FOOTNOTE_LABEL`: ko `각주` · en `Footnotes` · ja `脚注`
  - `FOOTNOTE_BACK_LABEL`(〔A-4〕 · C6): ko `${n}번 참조로 돌아가기` · ja `参照 ${n} に戻る` · en = 라이브러리 기본값(영어 문구). mx-4가 고정하고, SP-2 렌더 때 문구를 다시 본다.
    - ko · ja는 함수 `(referenceIndex, rereferenceIndex) => string`으로 넘긴다(옵션은 문자열 · 함수 둘 다 받는다 — 〔소스〕 mdast-util-to-hast@13.2.2 `lib/footer.js:129–:130` · `:198–:200`).
    - n = `referenceIndex + 1` + (rereferenceIndex > 1이면 `-k`)다. 라이브러리 기본값과 같은 자리다(`lib/footer.js:106–:111`).
    - 사실: `footnoteBackLabel(referenceIndex, rereferenceIndex)`의 rereferenceIndex는 1부터 센다(mdast-util-to-hast 13.2.2 `lib/footer.js:166` · `:172` — `let rereferenceIndex = 0` 뒤 `++rereferenceIndex <= counts` · 〔① 탐침〕 호출 인자 `[[0,1],[0,2],[1,1]]`). JSDoc의 「0-indexed」(`:102`)와 다르다 → 코드를 따른다. 위 `-k` 규칙은 코드와 맞는다(〔V2-2〕).
    - 정확 문자열(첫 각주의 둘째 참조): ko `1-2번 참조로 돌아가기` · ja `参照 1-2 に戻る` · en `Back to reference 1-2`(〔V-B-14〕).
- 처리기는 lang마다 하나씩 모듈 수준에서 한 번 만들어 얼린다.
- `yaml` 노드는 버려진다(〔소스〕 mdast-util-to-hast@13.2.2 `lib/handlers/index.js:59–:60`).

**rehype-slug**(prefix '')
- 트리마다 `slugs.reset()`을 하고 id가 없는 헤딩에만 단다(〔소스〕 rehype-slug@6.0.0 `lib/index.js`).
- 변환이 동기라 파일 간 섞임은 없다.

**헤딩 수집**(〔90-6〕 — FR-029 「목차」 = `headings[]` · 〔A-23〕)
- hast를 순회해 `h2` · `h3`만 모은다: `{ depth, text: toString(node), id }`. h1 · h4는 뺀다(머리 :25).
- **`properties.dataFootnotes`가 있는 `section` 아래는 건너뛴다.**
  - mdast-util-to-hast가 각주가 있으면 `<section data-footnotes>` 안에 `h2#footnote-label`(기본 글 「Footnotes」)을 만든다(〔소스〕 `lib/footer.js:131–:132` · `:241–:251`). 건너뛰지 않으면 목차에 각주 라벨이 낀다.
  - T086 사례 중에는 099 대조만 각주가 있다. 그 사례는 headings를 단언하지 않는다 → mx-5가 고정한다.

**Shiki**(@shikijs/rehype 4.6.0 기본 export)
- 옵션
  - `themes: { light: 'github-light', dark: 'github-dark' }` · `defaultColor: false`(색은 CSS 변수 · 사이트가 고른다 — web.md 「prefers-color-scheme」)
  - `langs: CODE_LANGS`(저장소가 쓰는 언어의 고정 목록 — bash(shellscript) · powershell · json · yaml · typescript · tsx · javascript · python · hcl · diff · toml · dockerfile. 정확한 Shiki 이름 · 별칭은 mx-6이 고정한다 · 이름은 〔A-24〕 ②)
  - `defaultLanguage: 'text'` · `fallbackLanguage: 'text'` · `lazy` 0 · `onError` 0(하이라이터 고장은 던진다)
- 근거 〔소스〕 https://cdn.jsdelivr.net/npm/@shikijs/rehype@4.6.0/dist/
  - `index.mjs`: `langs`가 없으면 번들 언어 전부를 적재한다.
  - `core-CAco_GZa.mjs`: 언어가 없고 `defaultLanguage`도 없으면 그대로 둔다. 적재되지 않은 언어는 `fallbackLanguage`로 간다. `codeToHast` 실패는 `onError` 또는 throw다.
- **코드 블록(`pre`)이 없는 문서에서는 하이라이터를 만들지 않는다.** 감싸개가 `pre`를 확인한 뒤 변환을 부른다. 실제 노트 2편(펜스 0 — `grep -n '^```' content/study/*.mdx` 0줄)을 쓰는 ld-1이 5 s 기본 시간 제한(〔R1 ⑤〕)에서 초기화 비용을 내지 않게 하려는 것이다.
- 하이라이터 자체는 `getSingletonHighlighter`라 모듈마다 1회다. 다만 T086 ld-13 대조 사례는 099의 ```` ```js ```` 때문에 loader.test.ts 워커에서 하이라이터를 처음 만든다 → 그 소요를 VD-T090-2가 잰다(〔A-19〕).
- 테마 대안: `createCssVariablesTheme`(〔소스〕 `@shikijs/core@4.6.0` export → `shiki`가 다시 내보낸다)은 색 리터럴이 0이라 web.md 3계층과 맞는다. 다만 `shiki` 직접 선언 +1줄이 필요하다(그 커밋에는 Renovate 그룹 — D11 ⓪-9). SP-2 본문 렌더 때 다시 본다(SP-1은 본문을 렌더하지 않는다 — 〔R3 §8〕).

**html**
- `hast-util-to-html`(기본 — `allowDangerousHtml` false)로 문자열을 낸다. 텍스트 · 속성 값은 이스케이프된다 — mx-4가 행동으로 고정한다(〔A-4〕).
- 같은 입력 · 같은 판이면 같은 문자열이다. 단서: Shiki `tokenizeTimeLimit` 기본값이 500 ms/줄이라(@shikijs/primitive `dist/index.mjs:620`) 아주 느린 기계에서는 토큰이 달라질 수 있다(〔B-17〕 — 산출물은 gitignore · 시험 영향 0 · 기록).
- 소비 성질(Shiki 인라인 `style` · `pre`의 `tabindex="0"` · 헤딩 id 접두 없음 · `footnote-label` id)은 §5-2 T091 · SP-2 인계로 넘긴다(〔B-9〕).

**읽기 시간**(〔90-10〕)
1. 본문 mdast의 `text` · `inlineCode` 값을 모은다(코드 블록 · 프런트매터 제외).
2. `new Intl.Segmenter(lang, { granularity: 'word' })`에서 `isWordLike` 조각 수를 센다.
3. 분 = `max(1, ceil(수 / 200))`이다.
- ld-9(50단어 → 1 · 2,100단어 → 11)를 충족하고, 정확값은 계약 밖이다(머리 :25 · t086:297). 비판 A가 `Intl.Segmenter('ko')`로 같은 값을 확인했다.
- 패키지 0이다. Node 공식 빌드의 ICU라 OS 간에 같다(추론).
- 상수 200 · 라벨 문구 · `CODE_LANGS`는 설계 선택이다. TDD가 고정한다.

### D8 인자 · root · 스캔 · 1회 스캔 캐시

**인자**(〔90-5〕 · 〔A-16〕 · lx-3)
- `opts`가 `undefined`면 기본이다. `opts === null`이거나 객체가 아니면 `TypeError`다.
- 각 옵션의 명시 `undefined`는 미지정(키를 뺀 것)과 같다. `{ includeDrafts: undefined }`는 기본값이다(머리 :13 `includeDrafts?: boolean`).
- 모르는 컬렉션 → `TypeError`(머리 :16 · ld-12)
- lang이 ko · en · ja 밖 · `includeDrafts`가 불리언 아님 · `opts.root`가 문자열 아님 · 빈 문자열 → `TypeError`(값 없는 메시지)

**root 우선순위**(정정 노트 35 · 머리 :14–:15): `opts.root` > env `JT_CONTENT_ROOT` > 기본

| 단계 | 규칙 |
|---|---|
| `opts.root` | `path.resolve(opts.root)`(호출 시점 cwd 기준) |
| env | **호출 시점에** `process.env.JT_CONTENT_ROOT`를 읽는다. 키가 없으면 다음 단계다. 빈 문자열이면 `TypeError`다 — 기본(실제 노트)으로 조용히 넘어가지 않는다(lx-3 · 〔90-5〕) |
| 기본 | `fileURLToPath(new URL('../../../content/', import.meta.url))` — 패키지 위치 기준 · cwd 무관. 워크스페이스 링크 너머에서도 실경로다(〔R3 F9〕 `pkg-url-has-node_modules=false`) |

- `vi.stubEnv(name, undefined)`는 키를 지운다(비판 A 확인 — vitest `chunks/index.aTZaPVhf.js:7443`). 그래서 env `''` → `TypeError`는 ld-1을 깨지 않는다.

**존재 확인**
- root가 없거나 디렉터리가 아니면 `(., root, missing)`이다.
- 컬렉션 디렉터리 `readdir`이 ENOENT · ENOTDIR이면 study는 `(study/, collection, missing)`, blog · projects는 `[]`다(머리 :15–:16).
- 그 밖의 fs 오류(EACCES 등)는 그대로 던진다(환경 오류 · 입력 값 아님).

**스캔**(〔90-2〕 결정 · 〔A-1〕 · 〔A-2〕 · C3)
1. `readdir(dir, { withFileTypes: true })` · 이름 Ordinal 정렬 · 비재귀
2. 후보 = 이름이 `.mdx`로 끝나는 항목이다. **확장자는 대소문자 무관**으로 본다(`X.MDX` · `y.Mdx` 포함). 그 밖(`.md` · `.txt` · 확장자 없음)은 무시한다(머리 :21 「`.mdx`가 아닌 파일은 무시」 — D16 해석).
3. 이름에 FILE_RE 문자(`[A-Za-z0-9._-]`) 밖 글자가 있으면 `(<컬렉션>/, file, name)` 하나를 내고 그 항목을 끝낸다. 다른 검증은 0이다(〔A-2〕 · D4).
4. 정규 파일이 아니면(Dirent `isFile()` 거짓 — 디렉터리 · 심볼릭 링크 · junction · FIFO · 그 밖) `(file, file, not-regular)` 하나를 내고 그 항목을 끝낸다. 따라가지 않고 읽지 않는다(저장소 밖 읽기 0 — 〔A-1〕).
5. 컬렉션 이름 규칙(D9 — Ordinal · 소문자 `.mdx`)을 어기면 `(file, file, name)`이다. 숨김 `.x.mdx` · `X.MDX` · `y.Mdx`가 여기서 걸린다. 파일 단위 검증은 계속하고(C8), 묶음 · 항목에서는 뺀다.
6. 나머지가 묶음 후보다.

- root · 컬렉션 디렉터리는 따라간다. 호출자 · 저장소가 정한 경로이고, C3는 파일 항목만 다룬다(〔B-14〕 기록). 선례 scripts/ci/events-compat.sh:62–:63은 디렉터리 사슬의 링크도 막는다 — 여기서는 받아들인 차이다.
- `core.symlinks=false` 체크아웃의 링크는 대상 경로를 담은 정규 파일이 된다. 첫 줄이 `---`가 아니므로 `fence`로 실패한다(닫힌 쪽 · 〔B-14〕 기록).
- 받아들인 위험: 편집기 잠금 파일 · macOS `._x.mdx`가 로컬 빌드를 깰 수 있다. 메시지가 파일을 짚는다(FILE_RE 밖 글자가 있으면 컬렉션 디렉터리를 짚는다 — 예: Emacs 잠금 파일 `.#x.mdx` → `(study/, file, name)` · 〔V-A-8〕 · §5-1).
- 측정(〔탐침 A〕 `probe/seg-junction.mjs` · 〔검증 B〕)
  - 이 기기(Node v24.11.1)에서 `symlinkSync(dir, 'link.mdx', 'junction')`이 권한 없이 만들어지고, readdir가 symlink로 분류한다(`dirent name=link.mdx file=false dir=false symlink=true`).
  - 디렉터리를 가리키는 junction은 stat로 보아도 디렉터리다(`stat:file=false dir=true`). 그래서 링크를 따라가 분류하는 꼴(mu-34)도 같은 `not-regular`를 낸다. 끊긴 junction(만든 뒤 대상을 지움)은 readdir가 symlink로 분류하고 stat는 ENOENT로 실패한다(`dirent 002-dangling.mdx … symlink=true | stat:ENOENT` — 〔검증 B〕) → mu-34는 끊긴 링크 사례(lx-12b (a))가 잡는다(〔V-A-3〕 · 〔V-B-1〕).
  - Linux는 type 인자를 무시하고 심볼릭 링크를 만든다 → lx-12b가 건너뜀 없이 돈다(끊긴 링크도 같다).
  - 정리(`rmSync` recursive)는 junction을 따라가지 않는다(〔검증 B〕 `after rmSync(tmp): tmp=false keep=true precious=true`).
  - 파일을 가리키는 심볼릭 링크는 Windows에서 Developer Mode나 관리자 권한이 있어야 만들어진다 → vitest 사례로 두지 않고(건너뜀 0 규율) VD-T090-8(Linux 1회)의 탐침으로 확인한다.

**1회 스캔 캐시**(〔90-1〕 ① — 사용자 결정)
- 키 = (해석된 절대 root, 컬렉션) · 값 = D3 A–B를 마친 결과의 Promise(draft 포함 · 모든 lang)
- 코드 주석: 「tasks.md T090 『`React.cache` 1회』 = 이 모듈 메모(〔90-1〕)」
- 같은 키의 동시 호출은 Promise를 함께 쓴다. **거부되면 지운다**(같은 Promise일 때만 — 거부를 보관하지 않는다).
- 거름 · lang · 정렬은 메모 뒤에서 호출마다 한다. ld-5는 같은 root를 일곱 번 부른다 — includeDrafts 2회(:337 · :339) + NODE_ENV 5회(:343–:355)(loader.test.ts:336–:356 · 〔V-A-16〕).
- 돌려줄 때는 `structuredClone`을 쓴다. 호출 간에 독립이고, 받는 쪽이 값을 바꿔도 메모는 그대로다.
- 무효화는 없다(원샷 생성 프로세스). watch는 나중이다.
- T086 시험과 맞는다. 같은 root에서 파일을 바꾼 뒤 다시 부르는 사례가 0이다(〔R3 §5〕). vitest는 시험 파일마다 모듈을 격리한다(추론).

### D9 다국어 · draft · 정렬 · blog · projects

**이름 규칙**(Ordinal — 소문자 `.mdx`)
- study: `^\d{3}-[a-z0-9-]+(\.(en|ja))?\.mdx$`(머리 :22)
- blog · projects: `^[a-z0-9]+(-[a-z0-9]+)*(\.(en|ja))?\.mdx$`(〔90-3〕 ① 잠정 — 컨트롤러 결정 · data-model.md:244)
- 위반하면 `(file, file, name)`이다(FILE_RE 안 이름). 파일 단위 검증은 그대로 돌고(C8), 묶음 · 항목에서는 뺀다. FILE_RE 밖 이름은 D8 스캔 3이 먼저 끝낸다.

**묶음**: slug = 이름에서 `(.en|.ja)?.mdx`를 뺀 것 · lang = 접미사(없으면 ko)

**교차 파일 규칙**
- ko 파일이 없는 slug는 **변형 파일마다** `(변형, file, ko-missing)`이다(정정 노트 2 · ld-4). ko 이름의 항목이 정규 파일이 아니면(`not-regular`) ko 파일이 없는 것으로 본다(lx-12b (b) · 〔V-B-1〕).
- 변형의 pubDate · change가 ko와 다르면 `(변형, pubDate|change, variant-mismatch)`다(ld-10 006 · 007).
- 비교는 두 값이 모두 유효할 때만 한다. ko가 울타리 · YAML 실패이거나 그 키에 issue가 있으면 건너뛴다(lx-8b — 변형 쪽 무효 · ko 쪽 무효 둘 다 · 〔V-B-6〕).
- `change`가 선택인 blog · projects에서 **한쪽에만 `change`가 있으면** `(변형, change, variant-mismatch)`다(닫힌 쪽 — 〔A-17〕 · lx-13). 둘 다 없으면 같은 것으로 본다.

**draft**(〔90-9〕 · N-1)
- 거름은 파일 단위다. 기본값은 `NODE_ENV`(호출 시점)가 정확히 `development` · `test`일 때만 참이다.
- 단, **ko 파일이 걸러지면 그 slug 전체를 뺀다**. 원본 없이 번역만 공개되지 않게 하고, ko 대체의 전제를 지킨다.
- 변형만 걸러지면 그 lang이 없는 것으로 본다.

**lang 고르기**
- 요청 lang 변형이 남아 있으면 그 항목, 아니면 ko 항목이다(머리 :21 · ld-3).
- `translations` = 같은 slug에서 **남은** 다른 lang들(항목 자신의 lang 제외 · Ordinal 정렬 — ko · en · ja 셋이면 ko → `['en','ja']`).
- 정렬은 pubDate 내림차순 → slug 오름차순(Ordinal — 머리 :23)이다.

### D10 JSON Schema export(〔90-4〕 · C2)

- **정본이 아니다.** 사슬: content.md(사람 계약) → `schema.ts` zod(코드 정본 — FR-029 · data-model §11) → JSON Schema(파생 사본 — 〔R3 §9〕)
- **내보내기**
  - `z.toJSONSchema(studyFields, { target: 'draft-2020-12', io: 'input' })`(`unrepresentable` 기본 throw)
  - 머리 키 순서를 고정한다: `$schema` · `$id: https://joshuatech.dev/content/study/frontmatter/v1`(events 꼴 — packages/events/schemas/_envelope.json:3) · `title` · `description`
  - description에 다음 뜻을 싣는다.
    - 파생 사본이다. 정본은 `packages/content/src/schema.ts`다.
    - 패턴은 ECMA-262(`u`) 정규식이다 — Python 소비자는 다시 확인한다(〔A-22〕).
    - zod 밖 규칙(series 짝 · updatedDate ≥ pubDate · sources 정확히 하나 · url 원 문자열 · url userinfo · 변형 일치 · 파일 이름 · ko 필수 · 본문 규칙)과 url host(공개 도메인 — zod domain, 런타임 전용)는 없다 — 이 스키마 통과 ≠ 로더 통과다(〔V2-4〕).
  - `JSON.stringify(…, null, 2) + '\n'`(LF — .gitattributes `*.json eol=lf`)
- **패턴**(〔A-22〕): 로더가 정하는 패턴(change · path · url · 비어 있지 않음)은 D5대로 events.md:28 꼴이다(명시 문자 클래스 · 문자 클래스 밖의 이스케이프하지 않은 `.` 0 · 끝 앵커가 있는 패턴(change · path)은 `$(?!\n)` · url · NONBLANK에는 `$` 0 · ASCII 문자열뿐 — 〔V-A-13〕 · 〔V-B-10〕). zod가 정하는 날짜 패턴은 zod 몫이라 `\d` · `$`가 남을 수 있다(추론 — VD-T090-1) → description 문구가 덮는다.
- **refine은 버려진다**(〔소스〕 zod@4.6.7 `v4/core/json-schema-processors.js` — 검사 기여 표에 `custom` 키가 없다). 교차 규칙은 처음부터 필드 객체 밖에 둔다 → VD-T090-1이 sx-5로 잰다.
- **CLI**(`schema.ts`)
  - 진입 판정 = 저장소 선례 `isEntryPoint()`(packages/events/scripts/check-compat.mjs:565–:575 — 〔A-14〕)
    - `import.meta.main`이 불리언이면 그 값을 쓰고, 없으면 `process.argv[1]`의 실경로와 이 파일의 실경로를 비교한다. 가드가 꺼져 조용히 통과하지 않게 하려는 것이다.
    - `engines.node >=24`(package.json:6)는 `import.meta.main`이 없는 24.0 · 24.1도 허용하기 때문이다.
  - 실행: `node src/schema.ts [--out <dir>]` · 기본 출력 = 패키지 `schemas/` · 임시 파일 → rename(원자적)
  - stdout 한 줄: `content-schema wrote=study.schema.json bytes=<n>`(ASCII) · exit 0. **파일 이름만 싣는다** — `--out`이어도 경로를 싣지 않는다(〔A-14〕 · 〔B-18〕).
  - 인자 오류는 exit 2 · stderr 한 줄 `content-schema: error usage`
  - import만으로는 돌지 않는다(〔측정 S〕 `main=false`). vitest 안 import에서도 `import.meta.main`은 false다(비판 A 확인 — vite `module-runner.js:806–:810`).
- **스크립트**: `"schema": "node src/schema.ts"`. `pnpm --filter content schema`(문면)와 `pnpm --filter @jt/content --fail-if-no-match schema`(AGENTS 꼴) 둘 다 `@jt/content`를 잡는다(〔R3 F12〕 · R1 측정 `@jt/content@0.0.0`) — 문면 편차가 아니다.
- **신선도**: content vitest sx-2가 「메모리 내보내기 = 커밋 파일 바이트」를 단언한다. 실패 메시지는 재생성 명령이다(specs-index-fresh 규율).
- **소비자**(〔A-22〕): SP-2 notes-sync → portfolio-core(Django)가 후보다(research/2026-08-28-brainstorm-decisions.md:57 「zod→JSON Schema로 Django 계약 도출」 · spec.md:394 · data-model.md:277). Python `re`는 `\d` · `$`를 다르게 읽으므로 그때 패턴을 다시 확인한다 → SP-2 인계(§5-2).

### D11 의존 목록(판 고정) · 설치 절차(⓪ — 컨트롤러 · 사용자 승인 2026-11-27 · 실행 2026-11-27 10:15 KST · 관문 전부 충족)

- 결정은 §0-3 ①(권고 세트 12 + ajv 둘)이다.
- ⓪은 설계 확정 워크플로와 나란히 컨트롤러가 돌았다(결정 문서 「⓪ 기반 설치」). 커밋 ②는 ① 설계 확정 커밋 뒤다(결정 문서 「설계 확정」).
- 증거 = `.superpowers/t090/evidence/install/`(각 단계의 로그). 결과 정본 = build-notes 「## T090」(〔V-A-12〕 · 〔V-B-16〕).

**⓪-0 매니페스트**(컨트롤러만 고친다 — 빌더는 package.json을 건드리지 않는다) — 적용함(작업 트리 · 커밋 ②)
- `"type": "module"` · `"exports": { ".": "./src/index.ts" }` · `"scripts.schema": "node src/schema.ts"`
- `description`과 `scripts.build`의 낡은 문구(HEAD packages/content/package.json:5 「skeleton, T015」 · :7 build echo)를 바꾼다(〔A-24〕 ⑤).
  - `description`: `Content loader and schemas - Node only: the content generation step and its tests (T090)`
  - `scripts.build`: `echo @jt/content: no build step, Node runs src via type stripping`
- 기존 `test`는 유지한다.
- 의존 12 + dev ajv 둘의 정확 판 = 〔사전 해석〕 `expected-content-package.json`과 같은 집합이다.
- 조건부 `exports`는 두지 않는다(T091 인계 — 〔B-8〕 · §5-2).

**⓪-1 env 가드**(〔B-10〕 · t086 D3-0 :270) — 결과(2026-11-27): proxy · TLS · npm · pnpm 설정 이름 0 · registry = npmjs 공식
- 다음 이름이 하나라도 있으면 이름만 내고 멈춘다(대소문자 무관): `HTTP_PROXY` · `HTTPS_PROXY` · `ALL_PROXY` · `NODE_OPTIONS` · `NODE_TLS_REJECT_UNAUTHORIZED` · `NODE_EXTRA_CA_CERTS` · `npm_config_*`(`npm_config_registry` · `npm_config_strict_ssl` · `npm_config_cafile` · `npm_config_ca` 포함) · `pnpm_config_*`
- `pnpm config get registry` = `https://registry.npmjs.org/`인지 확인한다.
- 까닭: TLS 계열 값이 있으면 응답이 바뀌어도 integrity가 같은 응답에서 오므로 lock 검사로는 못 잡는다. 독립 대조는 ⓪-3의 정확 목록이 맡는다.

**⓪-2 설치**(〔R2 §9〕) — 기한 2026-11-29 19:21 KST(〔B-2〕) — **충족(11-27 설치)**
- 실행(2026-11-27 10:15 KST · 컨트롤러): ⓪-0 매니페스트에 정확 판을 손으로 적고(T086 ⓪ 선례 — t086:272) `pnpm --dir <repo> install --ignore-scripts` → exit 0 · 46.8 s · `Packages: +113 -3`(node_modules 항목 — 새 110 + vite 계열 재배치 3) · 「Ignored build scripts」 0(〔R2 §4〕 설치 스크립트 0 · `install/0-2-install.log`)
- 기한을 넘겨 다시 설치해야 하면 정확 목록 · 기대 lock을 다시 만든다(정정된 analyze.mjs로 대조 — ⓪-3 3). 그 전에 새로 게시된 판은 72시간 창을 채우지 못해 같은 목록이 나온다(추론 — 비판 B 컷오프 2026-11-23T10:21:56Z).
- 같은 결과를 내는 다른 길(정확 판을 명령으로 더한다):

```
pnpm --dir <repo> --filter @jt/content add --save-exact --ignore-scripts unified@11.0.5 remark-parse@11.0.0 remark-gfm@4.0.1 remark-frontmatter@5.0.0 remark-rehype@11.1.2 rehype-slug@6.0.0 @shikijs/rehype@4.6.0 hast-util-to-html@9.0.7 unist-util-visit@5.2.0 hast-util-to-string@3.0.1 yaml@2.9.1 zod@4.6.7
pnpm --dir <repo> --filter @jt/content add -D --save-exact --ignore-scripts ajv@8.20.0 ajv-formats@3.0.1
```
- 어느 길이든 출력에 「Ignored build scripts」 줄이 0이어야 한다.

**⓪-3 lock 관문 = 정확 기대 lock**(〔B-1〕 · 〔B-2〕 · 〔사전 해석〕 — 렌즈 C) — 결과(2026-11-27): 작업 트리 lock = `expected-pnpm-lock.yaml`(`cmp` 바이트 동일) · lock +1020/−9 · package.json +24/−3 · 110/110 정확 · flags · deprecated · non-registry · 금지 이름 0(정정 도구 재실행 포함 — `install/0-3-gate.txt` · `0-3b-banned-recheck.txt`)
1. 설치 뒤 `pnpm-lock.yaml`이 `.superpowers/t090/evidence/preresolve/expected-pnpm-lock.yaml`과 바이트로 같아야 한다(차이 0 — 예: `git diff --no-index --exit-code`).
2. 그 기대본의 성질(결정 문서 「사전 해석」 — HEAD 대비 `+1020 / −9`)
   - **packages +110 · 삭제 0** = `.superpowers/t090/evidence/critic-b/out/expected-closure.tsv`의 name@version 110개와 같은 집합이다. 각 `resolution.integrity`가 목록의 sha512(공개 레지스트리 독립 조회값)와 같다.
   - importer `packages/content` = dependencies 12(specifier = version · 정확) + devDependencies ajv 8.20.0 · ajv-formats `3.0.1(ajv@8.20.0)` · vitest specifier 그대로
   - **삭제 9줄 = vitest peer 접미 대체뿐이다.** vite의 선택 peer `yaml` + pnpm `dedupePeerDependents` 기본값 true 때문이다(〔B-1〕).
     - 세 importer(apps/web · packages/content · packages/events)의 vitest `version: 5.0.5(vite@8.3.5)` → `5.0.5(vite@8.3.5(yaml@2.9.1))` — 3줄
     - snapshot 키 `vite@8.3.5` · `vitest@5.0.5(vite@8.3.5)` · `'@vitest/mocker@5.0.5(vite@8.3.5)'` → yaml 접미 판 — 3줄
     - 그 snapshot 안 dependencies · optionalDependencies 줄(mocker의 optionalDependencies `vite: 8.3.5` · vitest의 dependencies `'@vitest/mocker': 5.0.5(vite@8.3.5)` · `vite: 8.3.5` — HEAD lock :542 · :706 · :717) → yaml 접미 판 — 3줄(〔V-B-16〕)
   - 다른 importer 변화 = vitest 줄 접미뿐이다. 그 밖 삭제는 0이다.
   - 빌드 · os · cpu 표식 0 · deprecated 0 · `tarball:` · `git+` · `http` specifier 0
   - 판: `mdast-util-to-hast@13.2.2`(≥ 13.2.1) · `zod@4.6.7`(≥ 4.6.6) · `yaml@2.9.1` · `debug@4.4.3`
   - 금지 이름 0: `gray-matter|js-yaml|reading-time|rehype-raw|remark-mdx|@mdx-js|rehype-sanitize|next-mdx-remote|react`
3. 검사 도구: `node .superpowers/t090/evidence/preresolve/analyze.mjs <HEAD lock> <새 lock> <expected-closure.tsv>`. 사전 해석 실측은 packages `added=110 · removed=0` · 목록 110/110 일치였다.
   - **정정(〔V-B-9〕)**: 사전 해석 도구 analyze.mjs의 금지 이름 정규식이 `@mdx-js/` 갈래에서 공허했다 → 2026-11-27 `@mdx-js\/[^@]+`로 정정 · 재실행 `banned=0` · lock 직접 grep(키 줄) = 0(`.superpowers/t090/evidence/install/0-3b-banned-recheck.txt`). 목록 · 기대 lock을 다시 만들 때는 정정된 도구를 쓴다.
4. 어긋나면 ⓪-8이다. 어긋난 패키지는 직전 판 diff를 검토하고(`.superpowers/t090/evidence/critic-b/susp.mjs` 꼴) 여쭌다.

**⓪-4** `pnpm install --frozen-lockfile --ignore-scripts`를 두 번 돈다. 저장소 한 번, 매니페스트와 lock만 복사한 빈 트리 한 번이다(t086 D3-3 :273 · ci.yml 꼴). — 결과: 저장소 `Already up to date` · 빈 사본 exit 0(`install/0-4a-frozen-repo.log` · `0-4b-frozen-empty.log`)

**⓪-5** `pnpm --filter @jt/events --fail-if-no-match test` → `Tests  267 passed (267)` — **필수**다. lock과 events importer 줄이 events-test 방어 경로에 든다(ci.yml:64–:69). — 결과: `Tests  267 passed (267)`(`install/0-5-events.log`)

**⓪-6** `pnpm --filter @jt/content --fail-if-no-match test` → §1-2와 같은 빨강이어야 한다. — 결과: 빨강 그대로 — `Error: Cannot find module '../src/index'` · `Tests  no tests` · exit 1(`install/0-6-content-red.log`)

**⓪-7** gitleaks staged 0 → 파일 이름으로 스테이징(`packages/content/package.json` · `pnpm-lock.yaml`) → 커밋(D15 ② — ① 뒤). — 남음

**⓪-8** 조건이 하나라도 깨지면 되돌리고(`git checkout -- <두 파일>` + frozen 재설치) 멈춘 뒤 여쭌다. — 해당 없음(관문 전부 충족)

**⓪-9 Shiki Renovate 그룹 조건**(〔A-18〕 · t086:998)
- 지금은 `shiki`가 @shikijs/rehype 4.6.0의 정확 의존이라 해당 없다. renovate.json에 그룹을 두지 않는다.
- `shiki`를 직접 선언하는 커밋(VD-T090-2 대안 JS 엔진 · css-variables 테마)에는 renovate.json `packageRules` 그룹(`shiki` · `@shikijs/*`)을 함께 넣는다. 두 패키지의 판이 갈리지 않게 하려는 것이다.

### D12 TDD 조각 · 사례

**① 실물 대조 — 설치 직후 · 로더 코드 전**(정정 노트 5 · 〔R3 §11〕)
- 누가: 컨트롤러 또는 탐침 하위 에이전트. 빌더 착수 전에 한다.
  - 진행: ① 실물 대조 끝(2026-11-27) — T086 기대값 전부 일치(ld-13 EXPECTED 30행 · 정정 노트 5 꼴 일곱 · 실제 노트 후보 0 · ld-1 · ld-8 · VD-T090-6 LF/CRLF/CR · esm 전제) · 설계 어긋남 둘 = §6
    - 탐침 하위 에이전트를 r2와 나란히 띄웠다(결정 문서 「① 실물 대조」 — r2 덧붙임 5 · 6 · 8을 미리 넣었다). 9는 탐침에 없었다(항목 1–8만 — 〔① 탐침〕 `out.txt`) → 컨트롤러가 덧붙여 돌리거나 mx-8 빨강 단계에서 확인한다.
- 어디: `.superpowers/t090/evidence/vd-t086-3-4/probe.mjs`(저장소 안 · gitignore — 〔A-24〕 ③). `createRequire('<repo>/packages/content/package.json')`로 해석한다.
- 무엇
  1. `fixtures/body-rules/study/*.mdx`를 프런트매터 포함 전체로 파싱한다. 규칙별 후보(html 노드 · `{` `}` text · alt · title · 줄 머리 import/export · URL)의 줄 · 개수를 loader.test.ts:501–:531 EXPECTED와 대조한다. 099는 0이어야 한다.
  2. 정정 노트 5 목록(t086:1171)
  3. 실제 노트 001 · 002의 후보 0과 D6 「실제 노트」 자리의 inlineCode 여부
  4. remark-rehype + rehype-slug로 ld-1 h2 id 다섯 · ld-8 `같은-제목` · `같은-제목-1` · `하위`
  5. yaml 노드 끝 줄 = 닫는 울타리 줄(VD-T090-6) — LF · CRLF · CR 노트 모두(〔A-9〕). 블록 안 `---␠` · `---<TAB>` 줄에서는 micromark가 먼저 닫아 끝 줄이 우리 닫는 줄과 갈린다(→ D3 3-3 `fence` — 〔V-A-1〕 · 〔V-B-2〕)
  6. 컨테이너 연속 줄(인용 · `10.` 목록 · 각주 정의 · 게으른 연속 줄)의 문단 text 값에 컨테이너 접두 · 앞 공백이 없다(〔A-7〕 — D6 `esm` 전제). CRLF · CR 파일에서도 문단 text 값의 줄 끝이 원문 그대로(`\r\n` · `\r`)이고 노드 시작 줄이 파일 줄이다. break(공백 둘 · 역슬래시) 바로 뒤 text는 다음 줄 첫 글자에서 시작한다(〔V-B-5〕)
  7. 산문 자동 링크 리터럴의 노드(〔B-16〕): 산문 `xmpp:a@b.c`는 이메일 부분만 mailto link 노드가 되고 `xmpp:`는 앞 text에 남는다(① 실측으로 바로잡음 — r2의 「산문 `xmpp:a@b.c`가 link 노드가 된다」는 거짓이었다 · 〔① 탐침〕 7-1 · 7-1b). 산문 `http:user@example.com`도 같다(7-2). 산문 `https://user@example.com`은 위치 있는 link다(7-10). 닫히지 않은 `[` 뒤 · `"` 바로 뒤 `www.`에서는 변환이 위치 없는 link · text를 만든다(7-5–7-9 · 7-x1–7-x4 → D6 「위치 없는 노드의 줄」 · §6-1)
  8. mx-4 정확 비교용 작은 문서(우리가 만든 문서)의 html. 라이브러리를 직접 불러 D7 옵션으로 낸 문자열(Shiki 제외)을 기대값으로 남긴다(우리 구현이 아니다). 되돌림 라벨 정확 문자열: ko `1번 참조로 돌아가기` · `1-2번 참조로 돌아가기` · `2번 참조로 돌아가기` · ja `参照 1 に戻る` · `参照 1-2 に戻る` · `参照 2 に戻る` · en `Back to reference 1` · `Back to reference 1-2` · `Back to reference 2`(첫 각주를 두 번 참조 — 〔V-B-14〕)
     - 결과(2026-11-27): 세 언어 모두 일치했다. 탐침이 이스케이프 문장 하나(문자 참조 `&lt;b&gt;` · `&amp;` · 큰따옴표)를 문서에 더했다. 산출(`mx4-input.md` · `mx4-expected-{ko,en,ja}.html`)은 컨트롤러가 `packages/content/tests/fixtures/t090-mx-4/{input.md, expected-ko.html, expected-en.html, expected-ja.html}`로 옮겼다(커밋 ③ — mx-4 · §6-1).
  9. 링크 url 값의 문자 참조 · 날 글자(D6 「문자 참조 · 날 글자」 — 〔V-B-6〕): `&#127;` · `&#133;` → U+FFFD · `&#xFEFF;` → U+FEFF · 꺾쇠 대상의 날 DEL → 명시 link · 꺾쇠 없는 대상의 날 DEL은 명시 링크가 되지 않는다(대상이 http(s)면 GFM 자동 링크 리터럴이 대신 위치 있는 link를 만들어 결국 `unsafe-url` — 〔V2-3〕) · 날 U+0085 · NBSP는 꺾쇠 없는 대상에서도 link
- 출력: id · 파일 · 규칙 · 줄 · 수(값 0). 8만 그 문서의 html 문자열을 파일로 남긴다(→ 컨트롤러가 `tests/fixtures/t090-mx-4/`로 옮겼다).
- 합격: 전부 일치 → ② 착수. 어긋나면 멈추고, t090 「정정 노트」에 기록한 뒤 컨트롤러가 결정한다. 기대값을 바꿔야 하면 = 시험 고치기 = 사용자 결정이다.
  - 2026-11-27 결과: T086 기대값은 전부 일치했다(시험 고치기 0). 설계 어긋남 둘은 설계 확정 전이라 「정정 노트」 대신 §6-1에 기록했다.

**②–④ 빌더 조각**(web-builder opus 하나 · 순서대로 · 조각마다 시험 먼저 빨강 → 구현 → 초록)

**② `schema.ts` — `tests/schema.test.ts`**

| id | 사례 | 단언 |
|---|---|---|
| sx-1 | 꼴 | `$schema` 2020-12 · `$id` · `type: object` · `additionalProperties: false` · `required` = {title, description, pubDate, tags, draft, change, sources} 정확 · properties 키 = 계약 10 · `sources.items.additionalProperties: false` · url 속성 = `format: "uri"` + `pattern`(`{type:"string", pattern:"^[Hh][Tt][Tt][Pp][Ss]?:\\/\\/", format:"uri"}` — zod가 지운 `format`을 내보내기에서 되살린다 · D5 · 〔V2-1〕) · description에 「zod 밖 규칙」 · 「ECMA-262(u)」 문구 / 로더가 정한 `pattern`(change · path · url · 비어 있지 않음)에 `\d` · `\w` · `\s` 0 · 문자 클래스 밖의 이스케이프하지 않은 `.` 0 · 끝 앵커가 있는 패턴(change · path)은 `$(?!\n)` · url · NONBLANK에는 `$` 0(〔A-22〕 · 〔V-A-13〕 · 〔V-B-12〕) / 모든 `pattern` 문자열은 ASCII(0x20–0x7E)뿐이다(〔V-B-10〕 — 날 코드 포인트로 만든 NONBLANK는 산출물 `pattern`에 보이지 않는 글자(U+00A0 · U+FEFF 등)를 싣는다: V8 `source`는 줄 끝(LF · CR · U+2028 · U+2029)만, `JSON.stringify`는 제어 글자만 이스케이프한다 — 〔검증 B〕 탐침) |
| sx-2 | 신선도 | 메모리 내보내기 === 커밋 파일 바이트(LF · 끝 줄바꿈 하나) · 실패 메시지 = 재생성 명령 |
| sx-3 | CLI | `process.execPath`로 `src/schema.ts --out <tmp>` → exit 0 · stdout 한 줄 `content-schema wrote=study.schema.json bytes=<n>`(파일 이름만 · 절대 경로 0) · stderr 빈 값 · 파일 === 커밋 바이트 / `--bogus` → exit 2 · stdout 0 · stderr 한 줄(〔A-14〕 · 〔B-18〕) |
| sx-4 | import 무실행 | `process.execPath` 자식(env에서 `JT_CONTENT_ROOT` 삭제)에서 import만 → 파일 쓰기 0 · 출력 0 · exit 0 |
| sx-5 | ajv(2020 + formats) 대조 | valid: 실제 노트 2편 · 유효 픽스처(i18n · drafts) / invalid: ld-10의 표현 가능 위반(003 · 008 · 009–016) · 공백 · 탭 든 url(되살린 `format: "uri"`가 거부한다 — 〔V2-1〕) / valid(한계를 고정한다 — VD-T090-1): 교차 규칙 위반(001 · 002 · 004 · 005 · updated-before) · userinfo url · localhost · IP · 끝 점 FQDN · `xn--` TLD url(되살린 `format: "uri"` + 패턴은 받는다 — userinfo · localhost · IP는 실측(〔V2-1 탐침〕) · 끝 점 FQDN · `xn--` TLD도 uri 꼴이다(추론 — VD-T090-1). 거부는 zod `domain` · zod 밖 userinfo 규칙(런타임)만 한다 · 〔V-A-5〕 · 〔V2-1〕) |
| sx-6 | path | zod와 JSON Schema가 같은 판정 — 허용 `specs/x.md` · `.github/x` · `...` · `..a` / 거부 `.` · `..` · `a/./b` · `a/../b` · `a//b` · `/x` · `a\b` · `x:y` · 끝 줄바꿈 하나 붙은 값 |
| sx-7 | url | `schema.ts` 검증 함수(zod + zod 밖 규칙)와 JSON Schema 둘 다(JSON Schema 쪽 거부는 패턴(접두)과 되살린 `format: "uri"`가 한다 — 〔V2-1 탐침〕 · 〔V2-1〕) — 허용 `https://example.com/x` · `HTTP://EXAMPLE.COM/` · path · query · fragment의 `@`(`https://www.npmjs.com/package/@shikijs/rehype` · `https://example.com/?q=a@b` · `https://example.com/#a@b` — authority 경계 · 〔V-B-3〕) / 거부 `javascript:alert(1)` · `data:text/html,x` · `//host/x` · `ftp://x` · 앞뒤 공백 · 탭 · NBSP 든 값(〔B-4〕 — zod는 값을 trim · 탭 제거하므로 원 문자열 규칙이 `format`으로 막는다) · `https://example.com` + `\` + `x`(zod는 `\`를 `/`로 읽어 통과시킨다) · 경로 가운데 U+0001 · DEL · U+0085 · U+FEFF(URL 파서가 퍼센트 인코딩해 zod는 통과시킨다 — 원 문자열 규칙만 막는다 · 〔V-B-6〕). 값은 시험 안에서 `String.fromCharCode`로 만든다 / 한 경로 하나(검증 함수): `javascript:x` + 탭 → `(sources.0.url, format)` 하나(zod issue와 원 문자열 규칙이 함께 난다 — D4 · 〔V-B-6〕) / 검증 함수만 거부(`format` · JSON Schema 통과는 sx-5 한계): `https://user:tok@example.com/`(〔B-5〕 — userinfo) · `https://localhost/x` · `http://192.0.2.1/` · `https://example.com./x`(끝 점 FQDN) · `https://example.xn--3e0b707e/`(`xn--` TLD — `.한국`)(zod `domain` — 〔V-A-5〕) |

**③ `mdx.ts` — `tests/mdx.test.ts`**(단위)

| id | 사례 | 단언 |
|---|---|---|
| mx-1 | 울타리 · 줄(파일 함수 단위) | 정상 통과 · CRLF 노트 · CR 노트 통과(줄 번호 = 파일 줄 — 〔A-9〕) / BOM + `---` · `--- ` 첫 줄 · `---js` · 닫는 줄 없음 · 빈 파일 → `fence` / 블록 안 `---␠` · `---<TAB>` 줄(뒤에 정확한 `---` 닫는 줄이 있어도) → `fence`(micromark가 그 줄에서 닫는다 — D3 3-3 · 〔V-A-1〕) |
| mx-2 | YAML 규율(YAML 블록 함수 단위 — 블록 문자열 입력) | 매핑 아님(빈 · 스칼라 · 목록) · `%YAML 1.1` + `--- ` 줄 + 매핑 · 블록 마지막 줄 `...`(둘 다 판독 1만 잡는 꼴 — D5 · 〔V-B-2〕) · 키 `a-b` · 한글 · `1` · `true`(불리언 키) · `<<` · 65자 · 컬렉션 키 · 앵커 `&a`(별칭 없음) · 해결되는 별칭(`x: &a 1` + `y: *a`) · `title: *nope`(미해결 별칭 — 반환 issue · 던진 오류 어디에도 바늘 `nope` 0 · 〔B-3〕) · 별칭 폭탄 → `yaml` / 따옴표 키(`"title":` · `'draft':`) 허용(〔A-9〕) · 64자 키 허용 · `!!str` 허용 · 날짜 = 문자열 |
| mx-3 | 경고 누출 0 | `!!js/function` · 컬렉션 키 파일 → `process.on('warning')` 0회(다음 틱까지 기다린다) · stderr 0 |
| mx-4 | html(〔A-4〕 · 〔V2-2〕) | 픽스처 `tests/fixtures/t090-mx-4/input.md`(문단 · 표 · 각주 둘 — 첫 각주를 두 번 참조 · h2 · 이스케이프 문장 하나 — 문자 참조 `&lt;b&gt;` · `&amp;` · 큰따옴표)를 lang마다 컴파일한 html **정확 비교** = `expected-{ko,en,ja}.html`(헤딩 id 속성 · 각주 섹션 포함 — 기대값 = D12 ① 8. 컨트롤러가 옮긴 라이브러리 직접 산출이고, 빌더는 픽스처를 고치거나 다시 만들지 않는다. 코드 블록이 0이라 Shiki 단계는 돌지 않는다(D7). 프런트매터를 붙여도 같은 html이다 — 〔① 탐침〕 `sameWithFrontmatter=true`) / 기대 html 사실: 끝 줄바꿈 0 · `<` → `&#x3C;` · `&` → `&#x26;` · `>` · `"` 그대로 · 각주 라벨 h2 `class="sr-only" id="footnote-label"` · 각주 라벨 lang별(ko 각주 · en Footnotes · ja 脚注) · 되돌림 라벨 lang별 정확 문자열(ko `1번 참조로 돌아가기` · `1-2번 참조로 돌아가기` · `2번 참조로 돌아가기` · ja `参照 1 に戻る` · `参照 1-2 に戻る` · `参照 2 に戻る` · en `Back to reference 1` · `Back to reference 1-2` · `Back to reference 2` — 〔V-B-14〕) / 이스케이프: 글 `&lt;script&gt;` · 코드 스팬 `<script>` · alt 속 `"` → 출력에 `<script` 0 · 이스케이프 꼴(hast-util-to-html 기본 — 글 안 글자는 위 기대 html 사실과 같고, 그 밖 정확 글자는 실물로 고정) |
| mx-5 | 헤딩 | h1 · h4 제외 · h2 · h3 문서 순 · **각주 라벨 h2 제외** · 중복 `-1` |
| mx-6 | Shiki | ```` ```ts ```` → 토큰(`--shiki-light` 변수) · ```` ```nope ```` → 평문 · 던지지 않음 · 언어 없음 → shiki 평문 · 인라인 코드 그대로 · `CODE_LANGS`의 정확한 Shiki 이름 · 별칭 · 첫 생성 시간 기록(VD-T090-2) |
| mx-7 | 읽기 시간 | 코드 블록 낱말 제외 · 빈 본문 1 · 정수 · lang별 Segmenter |
| mx-8 | 거부 보조 | esm 컨테이너 기준(〔A-7〕): 인용 둘째 줄 · `10.` 목록 연속 줄 · 각주 정의 연속 줄 · 게으른 연속 줄의 `import x from 'y'` → 각각 `esm`(그 줄) · 목록 첫 줄 `- import x` → `esm`(보수 — 기록) · 줄 가운데 `import` · 첫 inline이 강조인 줄 → 0 / break 뒤(〔V-B-5〕): `a␠␠⏎import x from 'y'` · `a\⏎import x from 'y'` → `esm`(둘째 줄) / CRLF 파일 · CR 파일(프런트매터 포함 — 전체 줄 끝이 같은 꼴)의 문단 둘째 줄 `import x from 'y'` → `esm` · line = 파일 줄(`\r\n`은 줄 끝 하나 — 〔V-B-5〕) / 정의 동반 `![{a}][r]` + `[r]: https://example.com/x` → `expression`(imageReference.alt — 정의가 없으면 그냥 text라 alt 규칙을 재지 못한다 · 〔V-B-13〕) · `\{` → `expression`(보수 — 기록) / URL(모두 `[x](…)` 링크 꼴 — 산문 URL은 GFM 자동 링크가 다른 노드를 만든다 · 〔V-B-13〕): NBSP(날 글자) · DEL(날 글자 — 꺾쇠 대상 `[x](<…>)`에 둔다. 꺾쇠 없는 대상의 날 DEL은 명시 링크가 되지 않는다 — 대상이 http(s)면 GFM 자동 링크 리터럴이 대신 위치 있는 link를 만들어 결국 `unsafe-url`이다. 명시 링크 경로는 꺾쇠 대상으로 잰다 · D6 · 〔V2-3〕) · U+0085(날 글자) · `&#xFEFF;`(문자 참조) → `unsafe-url`(날 글자는 시험 안에서 `String.fromCharCode`로 만든다 · D6 「문자 참조 · 날 글자」 · 〔V-B-6〕) · `&#127;` · `&#133;`(문자 참조 → U+FFFD) 허용(사실 고정) · `https://user:tok@example.com/` · `http:user@example.com` → `unsafe-url`(〔B-5〕) · `xmpp:a@b.c` → `unsafe-url`(명시 링크 `[x](xmpp:a@b.c)` — 허용 목록 밖 스킴 · 〔V2-2〕) · `mailto:a@example.com` · `?q` · `[x]()` 허용 · path · query · fragment의 `@`(`https://www.npmjs.com/package/@shikijs/rehype` · `https://example.com/?q=a@b` · `https://example.com/#a@b`) 허용(authority 경계 — 〔V-B-3〕) / 산문 자동 링크 리터럴(링크 꼴 아님 — 〔B-16〕 · ① 실측으로 바로잡음 · 〔V2-2〕): 산문 `xmpp:a@b.c` · 산문 `http:user@example.com` → 0 issue(사실 고정 — 토크나이저가 이메일 부분만 mailto 링크로 만든다 · 〔① 탐침〕 7-1 · 7-2) · 산문 `https://user@example.com` → `unsafe-url`(토크나이저 링크 · 위치 있음 — 7-10) / 위치 없는 노드의 줄(D6 · 〔V2-2〕 — 사례 원문 = 1–3행 프런트매터(`---` · `title: "a"` · `---`) · 4행 빈 줄 · 5행부터 본문 · 〔① 탐침〕 꼴): 7-x1 5행 `{x} see "www.example.com" now` → `expression` 하나 · line 5 / 7-x2 5행 `a [b` · 6행 `xmpp:c@d.e` → `unsafe-url` 하나 · line 6 / 7-x3 5행 `see "www.example.com"` · 6행 `import x from 'y'` → `esm` 하나 · line 6 / 7-x4 대조 5행 `{x} see www.example.com now`(평범한 www — 토크나이저 링크 · 위치 있음) → `expression` 하나 · line 5(7-x1과 같은 결과) / 같은 줄 두 html → 열 순 |

**④ `loader.ts` + `index.ts` — `tests/loader-extra.test.ts`**(공개 API 위주) → 마지막에 T086 48

| id | 사례 | 단언 |
|---|---|---|
| lx-1 | root 우선순위(정정 노트 35) | env = i18n · `opts.root` = drafts → drafts의 slug |
| lx-2 | env는 호출 시점 | import 뒤 env = i18n · root 없음 → i18n slug(기본 root보다 앞) |
| lx-3 | 인자(〔90-5〕 · 〔A-16〕 · 〔V-B-13〕) | `opts.root` '' · `opts.root` `42`(문자열 아님) · env '' · lang `zz-needle-lang` · includeDrafts `'yes'` · `opts = null` · `opts = 'x'`(객체 아님) → 각각 `TypeError`(D8 인자 규칙) · 메시지에 바늘 `zz-needle-lang` 0(값 없는 상수 메시지) / 명시 `undefined`(`lang` · `includeDrafts` · `root`) → 그 키를 뺀 호출과 같은 결과 |
| lx-4 | 1회 스캔 | 임시 root 첫 호출 → 파일 하나 삭제 → 다른 lang · includeDrafts로 다시 → 같은 slug 집합 / 같은 내용의 새 root는 삭제를 본다 |
| lx-5 | 거부 보관 0 | 위반 root → 오류 → 고친 뒤 → 항목 |
| lx-6 | 호출 간 독립 | 돌려받은 배열 · `data` 변경이 다음 호출 결과에 0 |
| lx-7 | 순서(〔A-8〕 · 〔A-10〕 · quad 비교 — body가 아니면 line `-` · 〔V-B-15〕 · 하위 사례마다 mkdtemp root — 〔V2-8〕) | `B.mdx` · `a.mdx`(둘 다 name) → `study/B.mdx` 먼저(Ordinal) / 한 파일: 프런트매터 issue(문서 키 순 · 없는 키는 뒤) → 본문 줄 순 / no-number 꼴 이름 + `---js` → `[name, fence]` 정확 / sources 11개(2번 · 10번 url 위반) → `sources.2.url` → `sources.10.url` / 이름 위반 + 깨진 UTF-8 → `[name, encoding]` · ko 없는 변형 + 깨진 UTF-8 → `[encoding, ko-missing]` / 한 줄 `import {a} from 'b'` → `esm` → `expression`(같은 줄 · 같은 열 = 규칙 순) / 한 줄 `{x} <b>`(`study/001-a.mdx` — 1–9행 유효 프런트매터 · 10행 빈 줄 · 11행) → `[(study/001-a.mdx, body, expression, 11), (study/001-a.mdx, body, raw-html, 11)]`(같은 줄 · 열 1 < 열 5 — 규칙 순이면 반대 · 〔V-B-4〕) / 블록 안 `---␠`(`study/001-a.mdx` — 1행 `---` · 2행 `title: ""` · 3행 `---␠` · 4행 `description: x` · 5행 `---`) → `[(study/001-a.mdx, frontmatter, fence, -)]` 하나(스키마 issue 0 — `title` empty · 빠진 키 0 · 〔A-8〕 (b) · 〔V-B-2〕) / 블록 안 `--- !!map`(`study/001-a.mdx` — 1행 `---` · 2행 `--- !!map` · 3–9행 유효 프런트매터 키 일곱(위 `{x} <b>` 사례의 2–8행과 같다) · 10행 `---`) → `[(study/001-a.mdx, frontmatter, yaml, -)]` 하나(micromark는 2행을 닫는 줄로 읽지 않고 — 뒤에 내용이 있다 — yaml은 받는다 → 판독 1만 잡는다 · D5 · mu-59 · 〔V2-7〕) / 위치 없는 노드의 열(D6 · §6-9 · 〔열 탐침〕): 11행 `{x} see "www.example.com" <b>` → `[(study/001-a.mdx, body, expression, 11), (study/001-a.mdx, body, raw-html, 11)]`(변환이 쪼갠 위치 없는 text의 열 1 < html 열 27 — 「열 = +∞」 구현이면 반대 · mu-77) · 11행 `[x](javascript:a) {y} "www.example.com"` → `[(study/001-a.mdx, body, unsafe-url, 11), (study/001-a.mdx, body, expression, 11)]`(위치 있는 link 열 1 < 위치 없는 text 열 18 — 「부모 시작 열」 구현이면 열 1 동률이라 규칙 순으로 expression이 먼저 · mu-78) / `Object.isFrozen(err.issues)` · 모든 issue `Object.isFrozen`(D4 · 〔V-B-15〕) |
| lx-8 | code 어휘(T086 픽스처) | T086 픽스처를 읽기만 해서 triple 정확: `missing`(ld-2 · collect · draft-invalid) · `date-order` · `series-pair` · `format` · `source-kind` · `variant-mismatch` · `unknown-key` · `name` |
| lx-8b | code 어휘 행마다(mkdtemp — 〔A-3〕 · quad 비교 — 〔V-B-15〕) | `title: ""` · `"  "` → `(title, empty)` / `title:`(null) → `(title, type)` · 키 없음 → `(title, missing)` / `tags: "x"` → `(tags, type)` · `tags: ["a", ""]` → `(tags.1, empty)` / `seriesOrder: 0` → `range` · `1.5` → `type`(series와 함께) / `pubDate: 2026-02-30` → `format` / `draft: "false"` → `type` / `sources: [{title: x, path: a, foo: 1}]` → `(sources.0.foo, unknown-key)` / 한 경로 하나(`title: ""` — 길이 · 패턴 issue 둘 → 하나) / 변형 pubDate 꼴 오류 → `(변형, pubDate, format)` 하나(variant-mismatch 0) / ko `pubDate: 2026-02-30` + en 다른 유효 날짜(`2026-03-01`) → `[(ko, pubDate, format, -)]`만 · en issue 0(D9 — 두 값이 유효할 때만 비교 · 〔V-B-6〕) / ko `---js` + en → ko `fence` 하나 · en issue 0 |
| lx-9 | translations | ko · en · ja 셋 → 각 항목의 정렬된 다른 lang |
| lx-10 | 변형 draft | en draft → en 요청 = ko 항목 · `[]` / ko draft → slug 전체 제외 · `includeDrafts: true`면 포함 |
| lx-11 | 스캔 규칙(〔A-1〕 · 〔A-2〕) | 한 root에 `.x.mdx` · `X.MDX` · `y.Mdx`(셋 다 유효 내용) · `y.md` · `notes.txt` · 디렉터리 `sub.mdx/` · `노트.mdx` · `a b.mdx`(둘 다 본문 위반) · 이름 위반 `01-bad.mdx`(본문 위반) → **정확 quad 목록**(Ordinal 순 · body가 아니면 line `-` — 〔V-B-15〕): `(study/, file, name, -)` 둘 → `(study/.x.mdx, file, name, -)` → `(study/01-bad.mdx, file, name, -)` · 그 파일의 본문 issue(줄 포함) → `(study/X.MDX, file, name, -)` → `(study/sub.mdx, file, not-regular, -)` → `(study/y.Mdx, file, name, -)` / `y.md` · `notes.txt` 무시 / FILE_RE 밖 두 파일의 본문 issue 0 |
| lx-12 | not-regular 단위(보조) | 항목 분류 함수(가짜 Dirent — 디렉터리 · 심볼릭 링크 · 그 밖) → `not-regular` · 읽기 0. 분류 함수 구조에 기대므로 변이 귀속에는 쓰지 않는다(〔V-B-1〕) |
| lx-12b | not-regular 통합(〔A-11〕 · 〔V-A-3〕 · 〔V-B-1〕 — 사례마다 mkdtemp root · `symlinkSync(target, path, 'junction')` — Windows는 권한 없이 junction · Linux는 type을 무시하고 심볼릭 링크 · 건너뜀 0) | 기본: 디렉터리를 가리키는 링크 `study/001-x.mdx` → `(study/001-x.mdx, file, not-regular)` 하나 · 대상 읽기 0 / (a) 끊긴 링크 `study/002-y.mdx`(임시 디렉터리로 링크를 만든 뒤 대상을 지운다 — Linux는 끊긴 심볼릭 링크) → `(study/002-y.mdx, file, not-regular)` 하나(stat 구현은 ENOENT로 깨진다 — mu-34) / (b) 링크 `study/003-z.mdx` + 유효한 `study/003-z.en.mdx` → `[(study/003-z.en.mdx, file, ko-missing), (study/003-z.mdx, file, not-regular)]`(ko 이름의 not-regular = ko 없음 — D9 · mu-62) / 정리(`rmSync` recursive)는 링크를 따라가지 않는다(〔검증 B〕 실측 — D8) |
| lx-13 | blog · projects(〔90-3〕 · 〔A-17〕) | `blog/my-post.mdx`(change 없음) → 항목 · `blog/Bad_Name.mdx` → `name` / `blog/x.mdx`(change 있음) + `blog/x.en.mdx`(change 없음) → `(blog/x.en.mdx, change, variant-mismatch)` · 반대(ko에 `change` 없음 · 변형에 있음)도 같다(〔V-A-10〕) / projects 한 사례(〔V-B-13〕): `projects/my-app.mdx`(change 없음) → 항목(collection `projects`) |
| lx-14 | 직렬화 | `JSON.parse(JSON.stringify(items))` **toStrictEqual** items(Date · undefined 속성 · 함수 0 — 〔A-12〕) · `html` 문자열 |
| lx-15 | Node 자식(타입 스트리핑 — 〔A-6〕) | `process.execPath` · 임시 cwd · 자식 env 명시(`NODE_ENV` · `JT_CONTENT_ROOT` 삭제) · `--input-type=module -e` → `import(src/index.ts)` · 두 호출: 기본 → `data.draft === true` 항목 0(N-1을 순수 Node에서) / `includeDrafts: true` → slug ⊇ {001, 002} · stderr 빈 값 · exit 0(VD-T090-3 · VD-T086-5 기제). draft 값 자체는 단언하지 않는다(t086:130 규율) |
| lx-16 | import 무실행 | `process.execPath` 자식 · `JT_CONTENT_ROOT` = 없는 경로로 import만 → 출력 0 · exit 0 |
| lx-17 | 산출 필드 | 실제 노트 001 · 002 `html` 문자열 · headings h2 다섯(ld-1과 같은 값 · 순서) |
| lx-18 | 정적 규율(〔B-11〕 · 〔V-A-2〕) | `src/*.ts`에 `console.` · `emitWarning` · `YAML.parse(` · yaml 모듈 바인딩의 `.parse(`(`\byaml\.parse\(` — 대소문자 무관 · `import * as yaml from 'yaml'` 꼴 · 〔V2-5〕) · yaml의 `parse` 가져오기(`import { parse } from 'yaml'` · `parse as` 포함 — remark `processor.parse(` · `JSON.parse(`와 겹치지 않게 좁힌 꼴) · `{ cause` · `allowDangerousHtml: true` · `remark-mdx` · `rehype-raw` · `from 'react'` · `fetch(` · `node:http` · `node:https` · `node:net` · `node:child_process` · `eval(` · `new Function` 0 / `process.stdout` · `process.stderr`는 schema.ts CLI 블록에 한 곳씩 · 그 밖 파일 0(sx-3 `--bogus` → stderr 한 줄과 맞물린다) |

- 시험은 값을 출력하지 않는다(머리 :50 꼴 — 실패 메시지는 id · 파일 · 필드 · 규칙 · 줄).
- 환경에 따른 건너뜀은 0이다. run-all 판정이 `N passed (N)`이기 때문이다(D14).
- issue 비교는 lx-7 · lx-8b · lx-11에서 quad(`file field code line` — body가 아니면 line `-` · loader.test.ts:163 `quad` 꼴)로 한다(〔V-B-15〕).
- 새 픽스처는 mkdtemp를 우선한다. T086 픽스처는 읽기만 한다.
- 새 시험 파일도 `beforeEach`에서 `JT_CONTENT_ROOT`를 지운다(loader.test.ts:86–:89 꼴). 자식 프로세스는 PATH의 `node`가 아니라 `process.execPath`로 띄우고, 자식 env에서도 `JT_CONTENT_ROOT`를 지운다(〔B-18〕).

### D13 공허 · 변이 검사(참조 구현 없이 — 실제 구현의 날을 시험으로 확인)

**공허**
- 조각마다 새 시험이 구현 전에 올바른 이유로 빨강인지 관찰하고 기록한다(§1-2).
- 부재 단언은 양성 상태 단언과 짝을 짓는다(t086 D12 규율).

**변이**
- 사본 `.superpowers/t090/evidence/mutants/<id>/{packages/content,content/study}`(저장소 안 · gitignore — 〔A-24〕 ③)에서 돈다.
- `node_modules`는 junction으로 잇는다. 끝나면 junction을 먼저 걷는다(정정 노트 30).
- 변이마다 패키지 vitest를 돌려 FAIL ≥ 1을 확인한다. 살아남으면 사례를 시험 먼저 더하거나 기록한다.
- mu-1–mu-33은 T086 사례 · 구현 기제를, mu-34–mu-78은 T090이 새로 정한 결정을 잰다(〔A-13〕). mu-55–mu-72는 〔V-B-7〕이 짚은 빠진 행과 r2 새 사례(〔V-B-4〕 · 〔V-B-5〕 · 〔V-B-6〕 · 〔V-B-15〕)의 짝이다. mu-73–mu-78은 확정 보정(§6 — 〔V2-2〕 · 〔V2-8〕 · 6-9)의 짝이다.
- 동등 후보는 표에 미리 적는다(〔V-B-7〕). 그 꼴만으로는 변이가 죽지 않는 것이 정상이고, 잡는 사례를 따로 둔다.

| mu | 변이 | 잡을 사례(기대) |
|---|---|---|
| 1 | includeDrafts 기본 = `NODE_ENV !== 'production'` | ld-5 staging · 미설정 |
| 2 | draft를 검증 **앞에서** 거른다 | ld-6 |
| 3 | `ignoreBOM: false` | ld-14 생성 BOM |
| 4 | YAML 1.1(Date) | ld-1 pubDate · ld-7 같은 날 |
| 5 | `{ cause }` 싣기 | ld-2 등 cause 0 |
| 6 | YAML 메시지를 issue에 | ld-14 바늘 |
| 7 | `localeCompare` 정렬 | lx-7 |
| 8 | h1 · h4 포함 / 각주 라벨 포함 | mx-5 |
| 9 | 메모 제거 | lx-4 |
| 10 | 메모 키에서 root 뺌 | lx-4 · ld-*(다른 root 결과 섞임) |
| 11 | 거부 보관 | lx-5 |
| 12 | root 우선순위 뒤집기 | lx-1 |
| 13 | env · NODE_ENV를 import 때 읽기 | lx-2 · ld-5 |
| 14 | 모르는 키 field = '' | ld-10 008(FIELD_RE) |
| 15 | sources union | ld-10 009–011 |
| 16 | alt · title 중괄호 생략 | ld-13 008 · 009 |
| 17 | raw-html 문단 단위 | ld-13 023 · 027 |
| 18 | 소문자 차단 목록 | ld-13 017(N-2) |
| 19 | definition 생략 | ld-13 013 |
| 20 | 최상위만 순회 | ld-13 022–027 |
| 21 | 코드 스팬까지 거부(과잉) | ld-1 · ld-13 대조 |
| 22 | readingTime 상수 1 | ld-9 |
| 23 | translations 정렬 0 | lx-9 |
| 24 | ko-missing을 slug당 하나 | ld-4 |
| 25 | 변형 비교를 첫 파일과 | ld-10 006 · 007 |
| 26 | `YAML.parse` 사용 | mx-3 |
| 27 | YAML 경고를 무시 | ld-14 003 |
| 28 | Shiki 대체 언어 없음 | mx-6 |
| 29 | JSON Schema strict 빠짐 · 패턴 빠짐 · url `format` 되살림 빠짐(〔V2-1〕) | sx-1 · sx-5–sx-7 |
| 30 | CLI가 import 때 실행 | sx-4 |
| 31 | 커밋 산출물 한 글자 변경 | sx-2 |
| 32 | message 끝 줄바꿈 | 모든 오류 사례(머리 :46) |
| 33 | `/` 정규화 생략(`\`) | Windows에서 FILE_RE — Linux에서는 살아남을 수 있다(기록) |
| 34 | not-regular 항목을 따라간다(stat로 분류 · 대상 읽기 — C3) | lx-12b (a) 끊긴 링크(stat 분류 · 대상 읽기 모두 ENOENT로 깨진다 — 〔V-A-3〕 · 〔V-B-1〕). 디렉터리를 가리키는 링크(lx-12b 기본) · `sub.mdx/`(lx-11)는 따라가도 디렉터리라 이 변이를 못 잡는다(기록). 파일 링크 꼴은 VD-T090-8 탐침 |
| 35 | 스키마 issue code를 전부 `invalid`로(C5) | lx-8b |
| 36 | 값 null(`title:`)을 `missing`으로(C5) | lx-8b |
| 37 | 같은 경로의 첫 zod issue 채택 — 표 순 무시(C5) | lx-8b(`title: ""`). 같은 code로 모이면 동등 변이다(기록) |
| 38 | FILE_RE 밖 이름 파일도 검증한다(〔A-2〕) | lx-11(FILE_RE 밖 두 파일의 본문 issue 0) |
| 39 | FILE_RE 안 이름 위반 파일의 검증 생략(C8) | lx-11(`01-bad.mdx` 본문 issue) |
| 40 | blog · projects 이름 = study 규칙(〔90-3〕) | lx-13 |
| 41 | 한쪽만 `change` 허용(〔A-17〕) | lx-13 |
| 42 | env `''` → 기본 root로 진행(〔90-5〕) | lx-3 |
| 43 | 명시 `undefined` → `TypeError`(〔A-16〕) | lx-3 |
| 44 | ko draft인데 변형 공개(〔90-9〕) | lx-10 |
| 45 | translations에 걸러진 lang이 남음(〔90-9〕) | lx-10 · lx-9 |
| 46 | html 이스케이프 끄기 · 텍스트를 그대로 이어 붙임(D7) | mx-4 이스케이프 |
| 47 | 각주 라벨 · 되돌림 라벨 ko 고정(D7 · 〔A-4〕) | mx-4 |
| 48 | field 문자열 정렬 — 첨자 수 비교 아님(D4 · 〔A-10〕) | lx-7(sources 11개) |
| 49 | userinfo 허용(〔B-5〕) | mx-8 · sx-7 |
| 50 | 앵커 · 별칭 허용 — 폭탄만 막기(〔B-3〕) | mx-2(앵커 `&a` · 해결되는 별칭 — 〔V-A-11〕 · 〔V-B-11〕). `title: *nope`는 판독 6(toJS 예외 → `yaml`)이 남아 이 변이에서도 바늘 없는 `yaml`이 된다 — 바늘(입력 값 0) 사례로 남긴다 |
| 51 | CRLF를 `fence`로(〔A-9〕) | mx-1 |
| 52 | 숨김 · 대소문자 다른 `.mdx` 무시(〔A-1〕) | lx-11 |
| 53 | url 원 문자열 규칙 생략(〔B-4〕) | sx-7 |
| 54 | esm을 원 소스 줄(컨테이너 접두 포함)로 판정(〔A-7〕) | mx-8(인용 둘째 줄) |
| 55 | 따옴표 키 거부 — 평문 스칼라 요구(〔A-9〕 ②) | mx-2(`"title":` · `'draft':` 허용) |
| 56 | 매핑 아님 허용 — 판독 3 생략(C4) | mx-2(빈 블록 · 스칼라 · 목록 → `yaml`) |
| 57 | 키 형 검사 생략 — 판독 4의 문자열 스칼라 요구(C4) | mx-2(`true` · 컬렉션 키 → `yaml`). 키 `1`은 키 꼴로도 걸려 이 변이에서 동등이다(기록) |
| 58 | 키 꼴 검사 생략 · 느슨하게(C4 · 〔A-9〕) | mx-2(`a-b` · 한글 · `<<` · 65자 → `yaml` / 64자 허용) |
| 59 | 판독 1(지시자 · 추가 문서 표식) 생략(C4 · 〔90-7a〕) | mx-2(블록 마지막 줄 `...` · `%YAML 1.1` + `--- ` 줄 + 매핑 — 블록 함수 단위) · lx-7(블록 안 `--- !!map` 줄 + 다음 줄 매핑 → `[yaml]` 하나 — 파일 단위에서 이 변이를 잡는다 · 〔V2-7〕). 동등 후보(기록 — yaml이 이미 오류 · 경고를 낸다 · D5): `---` 줄 없는 `%` 줄(MISSING_CHAR) · 모르는 지시자(BAD_DIRECTIVE 경고) · 뒤에 내용이 있는 `...`(MULTIPLE_DOCS) · `--- title: x`(MISSING_CHAR). `--- !!map` + 다음 줄 매핑은 동등이 아니다(yaml이 받는다 — lx-7) |
| 60 | 3-3(yaml 노드 끝 줄 대조)을 YAML · 스키마 뒤로 — r0 순서(〔A-8〕 (b)) | lx-7(블록 안 `---␠` 다섯 줄 → `[fence]` 하나 — 이 변이면 판독 1이 먼저 `yaml`을 낸다 · 〔V-A-1〕 · 〔V-B-2〕) |
| 61 | 변형 비교를 값 유효성과 무관하게(D9) | lx-8b(ko `pubDate: 2026-02-30` + en 유효 날짜 → en issue 0 · 변형 pubDate 꼴 오류 → `variant-mismatch` 0) |
| 62 | ko 이름의 not-regular 항목을 ko 있음으로 본다(D9) | lx-12b (b)(en `ko-missing` — 〔V-B-1〕) |
| 63 | `structuredClone` 생략 — 메모 객체를 그대로 돌려준다(D8) | lx-6 |
| 64 | `opts === null` 허용 — 기본으로 진행(〔A-16〕) | lx-3 |
| 65 | 본문 issue 정렬의 열 기준 생략 — 줄 → 규칙 순(D4) | lx-7(`{x} <b>` → `[expression, raw-html]` — 〔V-B-4〕) |
| 66 | issues 얼리지 않음(D4) | lx-7(`Object.isFrozen` — 〔V-B-15〕) |
| 67 | body 밖 issue에도 line을 싣는다(D4) | lx-7 · lx-8b · lx-11(quad `-` — 〔V-B-15〕) |
| 68 | userinfo 판정을 URL 어디든 `@`로 — authority 경계 없음(〔B-5〕) | mx-8 · sx-7(path · query · fragment의 `@` 허용 — 〔V-B-3〕) |
| 69 | url 원 문자열 집합을 `\s` · C0 · DEL로 좁힌다 — C1 · `\` 빠짐(〔B-4〕 · D6 1단계) | sx-7(`\` · U+0085) · mx-8(날 U+0085) · ld-13 016(본문 `\`) — 〔V-B-6〕 |
| 70 | 한 경로 하나 생략 — zod issue와 원 문자열 규칙을 둘 다 낸다(D4) | sx-7(`javascript:x` + 탭 → `format` 하나 — 〔V-B-6〕) |
| 71 | esm 줄 머리에서 break 뒤 갈래 생략(〔A-7〕) | mx-8(break 뒤 둘 — 〔V-B-5〕) |
| 72 | esm 줄 끝 셈 오류 — `\r` 빠짐(`\n`만) 또는 `\r\n`을 둘로 셈(〔A-7〕) | mx-8(CR 파일 · CRLF 파일 — 〔V-B-5〕) |
| 73 | 「조상 시작 줄로 대체」 — 위치 없는 노드에서 난 issue의 line을 가장 가까운 위치 있는 조상의 시작 줄로 낸다(D6 줄 대체 규칙 생략 · 〔V2-2〕) | mx-8 7-x2 · 7-x3(기대 line 6 — 이 변이면 5) |
| 74 | 「position 그대로 읽기」 — `node.position.start.line`(D6 · 〔V2-2〕) | mx-8 7-x1–7-x3(위치 없는 노드에서 던짐으로 잡힌다 — 〔① 탐침〕 `@null`) |
| 75 | 객체 아닌 opts 허용 — 기본으로 진행(D8 · 〔90-5〕 · 〔V2-8〕) | lx-3(`opts = 'x'` → `TypeError`) |
| 76 | url host 검사 없음 — `z.httpUrl()` 대신 `z.url()`(D5 · 〔V-A-5〕 · 〔V2-8〕) | sx-7(`https://localhost/x` · `http://192.0.2.1/` → 검증 함수 `format`) |
| 77 | 위치 없는 노드의 열 = +∞ — 같은 줄의 위치 있는 issue 뒤로 보낸다(D6 열 · §6-9) | lx-7(`{x} see "www.example.com" <b>` → `[expression, raw-html]`) |
| 78 | 위치 없는 노드의 열 = 부모 시작 열 — 형제 순회 생략(D6 열 · §6-9) | lx-7(`[x](javascript:a) {y} "www.example.com"` → `[unsafe-url, expression]`) |

### D14 CI · run-all

- **CI는 T093 소유를 유지한다**(t086 §0-5 :134 · D13 :660).
  - T090 커밋을 push하면 ci.yml lint · test · events-test 세 job이 새 lock으로 frozen 설치(ARM)를 돈다 — content와 무관하게 시험을 도는 것은 events-test뿐이다(새 lock으로 설치한 node_modules를 쓰는 시험 기준 — lint는 자리 표시 · test는 Python 시험만 돈다 · 경로 필터 없음 — ci.yml:73–:76 · :329 · :373 · :595–:626 · t086:273 · 〔V-B-8〕). events importer의 vitest 줄 접미도 바뀐다(〔B-1〕).
  - push 뒤 확인(사용자 확인): lint · test · events-test의 frozen 설치 스텝 성공 · events-test `Tests  267 passed (267)`.
  - events-compat → events-test 인접 규칙은 건드리지 않는다(〔R3 §10〕).
- **run-all `content` 슬롯**(C1 (B) — 결정) — T090 커밋 · `1b2a6. e2e-selftest`(tests/run-all.ps1:90–:97) 다음 `1b2a7. content`
  1. `packages/content/node_modules/vitest`가 없으면 `SKIP content -- allowed (packages/content dependencies not installed)`다.
  2. 있는데 `Get-Command pnpm -ErrorAction SilentlyContinue`가 비면 `FAIL content -- pnpm not found on PATH`다(〔A-15〕 · 〔B-6〕).
     - run-all은 `$ErrorActionPreference = 'Stop'`(tests/run-all.ps1:2)이다. 가드 없이 pnpm을 부르면 명령 없음 예외로 run-all 전체가 멈춘다(비판 A 실측 — `caught=CommandNotFoundException` · 다음 줄 실행 0).
     - 지금 run-all에는 pnpm 호출이 0이다. 이 슬롯이 첫 pnpm 의존이다.
  3. 그 밖에는 `pnpm --filter @jt/content --fail-if-no-match test`가 exit 0이고 요약 `(?m)^\s*Tests\s+(\d+) passed \(\1\)\s*$`가 있을 때만 PASS다(e2e-selftest 규율).
  - 손 확인 세 상태(§1-1 합격선 8 · build-notes): 설치됨 → PASS · pnpm 없음 → FAIL 줄(run-all은 계속) · vitest만 있고 로더 의존 없음 → FAIL(SKIP 조건이 vitest만 보므로 — 닫힌 쪽 · 기록)
  - web 슬롯은 두지 않는다. bundle-budget이 T093까지 빨강이다(정정 노트 18).
- 대안 비교(〔R3 §10〕 — 결정 근거)

| | (A) 공백 수용 | **(B) 슬롯(결정)** | (C) T090이 CI job을 연다 |
|---|---|---|---|
| 잡는 것 | 수동 실행 | run-all마다 | push마다 |
| 대가 | T093까지 회귀가 숨는다 | run-all이 pnpm · 설치에 기댄다(수십 초 — 추론) | 게이트 파일 · CODEOWNERS · st-1 · T093 기본값 번복 |

### D15 빌더 · 리뷰 · 커밋 · tick

**조각**

| 조각 | 담당 | 파일 | 확인 |
|---|---|---|---|
| ⓪ 기반 | 컨트롤러(실행 2026-11-27 10:15 KST · 관문 충족 · 커밋은 ① 뒤) | package.json · lock | D11 ⓪-0–⓪-9 |
| ① 실물 대조 | 컨트롤러 · 탐침 하위 에이전트 | `.superpowers/t090/evidence/vd-t086-3-4/` · `packages/content/tests/fixtures/t090-mx-4/`(mx-4 기대 html — 컨트롤러가 옮김 · 커밋 ③) | D12 ① — 끝(2026-11-27) |
| ②–④ 구현 | **web-builder(opus) 하나**(영역 — web-builder.md:18 「its packages」 · web.md `paths` `packages/content/**`) | D1 빌더 몫 | D12 표 · 조각마다 빨강 → 초록 |
| ⑤ 변이 | 같은 빌더(사본) | `.superpowers/t090/evidence/mutants/` | D13 |
| ⑥ 문서 · 슬롯 | 컨트롤러(또는 문서 담당) | §4-1 | §1-1 합격선 8 |

**빌더 지시문 절**(전체 파일 0 — specs.md)
- tasks.md:245 · AC2 · FR-029 · Edge :221
- loader.test.ts 머리 주석 :1–:51
- content.md · data-model §11
- t086 D4(:278–:319) · N-1 · N-2 · N-3 · N-7 · N-13 · 정정 노트 1 · 2 · 3 · 5 · 35
- 이 설계 §2 · §3(D16 「해석 · 확장」 열 포함)
- **넣지 않는 것**: `.superpowers/t086/evidence/`(정정 노트 30)
- 빌더 규칙: 커밋 0 · 설치 0 · package.json 0 · 공개 호스트 0. 컨트롤러가 파일 이름으로 스테이징한다.
- 정규식의 U+ 범위(`NONBLANK` · url 원 문자열 규칙)는 소스에 날 글자로 두지 않는다. 편집 도구가 역슬래시-u 이스케이프를 실제 글자로 바꾼 일이 이 저장소 작업에서 있었다. U+2028 · U+2029 날 글자는 정규식 리터럴 안에서 구문 오류가 된다.
  - JSON Schema로 나가는 패턴 문자열(`NONBLANK` 등)은 ASCII 이스케이프(역슬래시 + `u` + 16진 네 자리)로 조립한다. 소스에는 `BS + 'u' + hex` 꼴로 쓴다(loader.test.ts:78 `BS` 선례 · 〔V-B-10〕). 날 코드 포인트로 만들면 산출물 `pattern`에 보이지 않는 글자가 실린다(sx-1).
  - JSON Schema에 나가지 않는 판정(url 원 문자열 · D6 1단계)은 코드 포인트 비교로 한다.
  - 쓴 뒤에는 바이트로 확인한다(sx-1 ASCII 단언).

**리뷰 렌즈 셋**
- **A 정합**: 머리 주석 ↔ 구현(D16 「해석 · 확장」 열) · 〔90-n〕 · 계약 문서 보정 · 문면
- **B 노출 · 보안 · 공급망 · 번들**
  - 입력 값 0(오류 객체 · stderr · process 경고 · zod `input` · 별칭 이름)
  - YAML 규율(앵커 · 별칭 · 키 꼴) · URL 판정(원 문자열 · userinfo) · not-regular · 숨김
  - lock 차이(기대 lock과 차이 0) · 판 · 금지 이름 · 설치 스크립트 0
  - `react` 0 · web.md 새 줄
- **C 하네스 · 변이**: 빨강 증거 · 변이 표(mu-34–mu-78 포함 · 동등 후보 기록) · 신선도 · run-all 슬롯(세 상태) · frozen · events · 끝 줄 · Linux 1회

**커밋**(과제마다 하나 + 기반)
1. `docs(003-platform-foundation): T090 설계 확정 — …`(이 문서 + build-notes 「## T090」 머리)
2. `chore(003-platform-foundation): T090 ⓪ 기반 — packages/content 로더 의존 12 정확 판 · ajv 둘(dev · lock 재사용) · vitest peer 접미(vite@8.3.5(yaml@2.9.1) — apps/web · packages/content · packages/events) · type module · exports · schema 스크립트(tick 없음)`
3. `feat(003-platform-foundation): T090 — packages/content 로더(schema · mdx · loader · index) · 순수 마크다운 거부 규칙 · Shiki · JSON Schema export → T086 48 PASS · tick 89/119`
   - 함께 드는 것: §4-1 문서 · run-all 슬롯 · build-notes · 학습 로그 `content/tmp/003-t090/<날짜>.md` · `packages/content/tests/fixtures/t090-mx-4/`(① 컨트롤러 — §6-1)

push는 run-all 뒤 사용자 확인으로 한다.

**tick 조건**
- §1-1 합격선 1–9(run-all — 합격선 8 포함 · 〔A-15〕)
- 컨트롤러가 빨강 · 초록을 한 번 더 관찰한다(T060). 명령과 끝 줄을 build-notes에 그대로 적는다.
- 리뷰 A · B · C approve(HIGH 0)와 고침 반영
- 변이 보고 · VD 결과 · 〔90-n〕 기록
- 표와 다른 FAIL이나 새 편차가 있으면 tick 0 → 사용자 결정

### D16 시험 머리 주석 대조(뜻이 다른 곳 0 · 해석 · 확장은 이 열에 전부)

| 머리 주석 | 설계 자리 | 판정 | 해석 · 확장 |
|---|---|---|---|
| :12–:16 API · root · 부재 · TypeError | D8 | 같은 뜻 | 우선순위 = 「옵션 → env → 기본」(정정 노트 35). env 「있으면」 = 호출 시점에 키가 있으면이다(빈 문자열은 `TypeError` — 〔90-5〕). 확장: 모르는 lang · 불리언 아닌 includeDrafts · 문자열 아닌 · 빈 root · `opts === null` · 객체 아닌 opts → `TypeError` · 명시 `undefined` = 미지정(〔90-5〕 · 〔A-16〕). 해석(:15–:16 부재 — 〔V-A-4〕 ⑤): root가 디렉터리가 아니어도 `(., root, missing)` · 컬렉션 `readdir`의 ENOTDIR도 ENOENT와 같다(study `(study/, collection, missing)` · blog · projects `[]`) · 그 밖 fs 오류(EACCES 등)는 그대로 던진다 · root · 컬렉션 디렉터리 링크는 따라간다(〔B-14〕) · 상대 root = 호출 시점 cwd 기준(`path.resolve`) |
| :17–:18 includeDrafts N-1 · 검증 뒤 거름 | D3 · D9 | 같은 뜻 | 거름 = 파일 단위 · ko가 걸러지면 slug 전체 제외 · translations는 거른 뒤(〔90-9〕) |
| :19–:20 본문 절 검증 0 | D3 | 같은 뜻 | — |
| :21 lang · slug마다 하나 · `.mdx`가 아닌 파일 무시 | D8 · D9 | 같은 뜻 | 「`.mdx`가 아닌 파일」 = 확장자를 대소문자 무관으로 보아 `.mdx`가 아닌 항목이다. `X.MDX` · `y.Mdx` · 숨김 `.x.mdx`는 `.mdx` 파일이고 :22 이름 규칙 밖이므로 `name`이다(t086:318 「어긋나는 `.mdx`는 오류」 — 〔A-1〕 · 〔90-7d〕). 확장: `*.mdx` 이름(FILE_RE 안)의 정규 파일 아닌 항목 → 새 code `not-regular`(〔90-7d〕 · 〔V-A-9〕) |
| :22 study 이름 · 변형 · ko 필수 | D8 · D9 | 같은 뜻 | 이름 규칙 = Ordinal · 소문자 `.mdx`. 확장: FILE_RE 밖 이름 → `(<컬렉션>/, file, name)` 하나 · 그 파일의 다른 검증 0(:32 꼴 계약을 지키려는 것 — 〔A-2〕 · 〔90-7e〕). 해석(〔V-A-4〕 ④): 변형 pubDate · change 비교는 두 값이 모두 유효할 때만 한다(lx-8b) · ko 이름의 정규 파일 아닌 항목 = ko 없음(lx-12b (b)) · 이름 위반 파일은 묶음 밖이라 ko로 치지 않는다(C8). blog · projects 이름 · 한쪽만 `change`는 머리 주석 밖이다(〔90-3〕 잠정) |
| :23 정렬 | D9 | 같은 뜻 | 해석(〔V-A-4〕 ⑧): slug 오름차순 = Ordinal(코드 단위 비교 — `localeCompare` · `Intl.Collator` 0 · mu-7) |
| :24–:28 ContentItem · 날짜 문자열 · 헤딩 id | D2 · D5 · D7 | 같은 뜻 | 확장: `html` 필드(:28 「T090이 더한다」 자리 · 〔90-6〕). headings = FR-029 목차(각주 라벨 제외 — 〔A-23〕) |
| :29–:32 클래스 · 순서 · file | D4 | 같은 뜻 | 「문서 순」 구체화: 파일 단위 `name` → `encoding` → `ko-missing` · 필드는 문서 키 순 · 첨자는 수로 비교 · 본문은 줄 → 열 → 같은 자리면 :38 규칙 순(〔A-10〕). 해석(:30 `line?` · :38 — 〔V-A-4〕 ⑥): body 밖 issue에는 line을 싣지 않는다(키 자체가 없다 — quad `-` · 〔V-B-15〕). 확장: issues 배열과 각 issue를 얼린다(D4) |
| :33–:36 field · sources | D4 · D5 | 같은 뜻 | 확장(:36 「http(s) 절대 URL만」을 기계로 판정): url 원 문자열(공백 · 제어 · `\`) · userinfo → `format`(〔B-4〕 · 〔B-5〕 · 〔90-7f〕). 해석 · 확장(〔V-A-4〕 ② · ③): 중첩 모르는 키의 field = 경로 `sources.<i>.<키>`(:35 「그 키 이름」을 경로로 읽는다 — lx-8b) · url host = 공개 도메인 이름(zod `httpUrl`의 `domain` — localhost · IP · 끝 점 FQDN · `xn--` TLD 거부. 새 규칙이 아니라 zod가 이미 하는 일을 적고 시험한다 — sx-7 · 〔V-A-5〕). 본문 링크에는 host 규칙이 없다(〔B-5〕 — 비대칭) |
| :37–:41 code = 규칙 이름 · body | D4 · D6 | 같은 뜻 | esm 「줄」 = 컨테이너 기준(문단 text 값의 줄 머리이면서 그 줄의 첫 inline · 줄 머리 = 문단 첫 자식 · break 뒤 · 값 안 줄 끝 뒤 · 줄 끝 셋)이다. :40–:41 「트리 전체 · 목록 항목 · 인용 · 각주 정의 안의 위반도 같은 issue」 그대로다(〔A-7〕). 확장: unsafe-url에 http(s) userinfo(〔B-5〕 · 〔90-7f〕). 확장(〔V-A-4〕 ① · ⑦): field가 body · frontmatter · file 밖일 때의 code 어휘(`missing` · `type` · `empty` · `format` · `range` · `unknown-key` · `series-pair` · `date-order` · `source-kind` · `variant-mismatch` · `invalid`)는 T090이 정한다 — 공개 CI 로그에 나가는 계약이다(D4 표 · C5) · 「image alt」에 참조형 `imageReference.alt`를 넣는다(:39–:40 · mx-8). 해석(〔V2-2〕 — ① 실측): 위치 없는 노드(mdast 변환이 만든 링크 · 쪼개진 text)의 「노드 시작 줄」 = D6 「위치 없는 노드의 줄」(같은 부모에서 앞선 위치 있는 형제의 끝 줄 + 그 사이 위치 없는 형제 text 값의 줄 끝 수 · 없으면 부모의 줄 · 가장 가까운 위치 있는 조상의 끝 줄에서 자른다) — :38 「line = 노드 시작 줄」을 지키는 쪽이다(mx-8 7-x1–7-x4) |
| :42 frontmatter fence · yaml | D5 | 같은 뜻 | 「첫 줄이 정확히 `---`」의 줄 = CommonMark 줄(줄 끝 `\r\n` · `\r` · `\n` — micromark와 같다) → CRLF 노트는 정상이다(〔A-9〕 ② · 〔90-7c〕). 확장: `yaml`에 지시자 · 추가 문서 표식 · 매핑 아님 · 키 꼴 `^[A-Za-z][A-Za-z0-9_]{0,63}$`(따옴표 키 허용) · 앵커 · 별칭을 더했다. :42의 「구문 · 중복 키 · 모르는 태그 · 경고」는 그대로다(〔90-7a〕 · 〔90-7b〕). 확장: 블록 안 `---␠` · `---<TAB>` 줄 → `fence`(micromark가 그 줄을 닫는 줄로 읽어 울타리가 갈린다 — D3 3-3 · 〔A-8〕 (b) · 〔V-A-1〕) |
| :43–:44 file code | D4 · D8 | 같은 뜻 | 확장: `not-regular`(〔90-7d〕) |
| :45 울타리 · YAML 실패 = issue 하나 | D3 | 같은 뜻 | 「그 파일의 issue는 하나」 = 내용 단계(울타리 · YAML · 스키마 · 본문) issue 하나다. 파일 단위 issue(`name` · `ko-missing`)는 별개다(〔A-8〕 (a) — lx-7 `[name, fence]`). 울타리 판정(yaml 노드 끝 줄 대조 포함)은 YAML · 스키마 앞이다(〔A-8〕 (b)) |
| :46–:49 message · 입력 값 0 · cause 0 · 자기 속성 | D4 | 같은 뜻 | 입력이 실리는 길 둘을 구조로 막는다: 앵커 · 별칭 금지(toJS 예외의 별칭 이름 — 〔B-3〕) · zod issue 객체(`input`)를 싣지 않음(〔B-4〕) |
| :50–:51 시험 값 출력 0 · 픽스처 | D12 | 같은 뜻 | 새 시험도 같은 규율 · mkdtemp 우선 · `process.execPath` · `JT_CONTENT_ROOT` 삭제(〔B-18〕) |

## 3. VD(검증 후 결정)

| VD | 무엇 | 언제 · 어디서 | 어긋나면 |
|---|---|---|---|
| VD-T086-3 | 실제 노트 2편이 거부 가드 · 스키마를 통과하는가(코드 스팬 · 표 칸 `\|` · 주석 글자 · `` `u{FEFF} `` 글자) | ① 탐침(일치 — 2026-11-27) → ④ ld-1 | 노트 수정(사람 — T086-a와 함께) 또는 규칙 정정 → 정정 노트 · 사용자 |
| VD-T086-4 | 한국어 헤딩 id(rehype-slug · github-slugger 2.0.0) — ld-1 다섯 · ld-8 `-1` | ①(일치 — 2026-11-27) → ld-1 · ld-8 | 기대값 정정 = 시험 고치기 = 사용자 결정 |
| 정정 노트 5 확장 | html 블록 유형 1 · 6 · 2 · 7 · `<Callout />` 글줄 · 두 줄 문단 = text 하나(007 → 13) · 정의 줄(013 → 15) · 문자 참조 · 탭 · 중첩 여섯(022 → 14 · 023 → 13 ×2 · 024 → 15 · 025 · 026 → 13 · 027 → 15 ×2) · LF · CRLF · CR 줄 번호(〔A-9〕) · 컨테이너 연속 줄 text 값(〔A-7〕 전제) · 산문 자동 링크 리터럴(〔B-16〕 — ① 실측으로 바로잡음: 산문 `xmpp:a@b.c` · `http:user@example.com`은 이메일 부분만 mailto 링크가 되어 0 issue다. r2의 「link → `unsafe-url`(사실)」은 거짓이었다) · 위치 없는 노드(변환이 만든 링크 · text → D6 「위치 없는 노드의 줄」) | ① — 끝(2026-11-27): 정정 노트 5 꼴 일곱 일치 · 설계 어긋남 둘(§6-1) | 위와 같다 |
| VD-T090-1 | **내보낸 url에 `format`이 남는가(되살림 뒤)** — 확인됨(컨트롤러 탐침 — 〔V2-1 탐침〕: 되살리지 않으면 `{type:"string", pattern:"^[Hh][Tt][Tt][Pp][Ss]?:\\/\\/"}`뿐 · `.meta` · `override` 둘 다 `pattern`과 함께 `format:"uri"`를 싣는다 · 〔V2-1〕) · zod 4.6.7 `toJSONSchema`가 refine을 던지지 않고 버리는가 · 로더 패턴이 명시 클래스 · `$(?!\n)` 그대로 실리는가 · `z.iso.date()` 출력 꼴(zod 날짜 패턴의 `\d` · `$`) · ajv `format: uri`가 공백 · 탭 · NBSP url을 거부하는가(되살림 뒤 확인됨 — 같은 탐침: 공백 · 탭 · NBSP · `\` · U+0001 · DEL · U+0085 · U+FEFF 거부 · userinfo · localhost · IP 수용) · **httpUrl `domain`이 localhost · IP · 끝 점 FQDN · `xn--` TLD를 거부하는가**(실행 확인 — 〔V-A-5〕) · 패턴 문자열이 ASCII뿐인가(〔V-B-10〕) | ② sx-1 · sx-5 · sx-7 | 필드 객체만 내보낸다(이미 그렇다) · 패턴이 안 실리면 `z.string().regex()` + 교차 검사 · ajv가 공백 url을 받으면 sx-5 한계로 기록 · domain이 받는 값이 있으면 sx-7 기대와 content.md 구를 실물대로 고치고 정정 노트에 적는다 |
| VD-T090-2 | Shiki(onig WASM)가 vitest 5.0.5 안에서 뜨는가 · 첫 생성 시간(목표 ≤ 1 s · 한도 5 s — 〔R1 ⑤〕) · **ld-13 대조 사례 소요**(099의 ```` ```js ````가 loader.test.ts 워커에서 하이라이터를 처음 만든다 — verbose 리포터로 잰다 · 여유 ≤ 2 s — 〔A-19〕) | ③ mx-6 · ④ ld-13(이 PC — Windows x86) · x86 Linux 소요는 VD-T090-8과 함께 적는다. **ARM은 이 PC에서 불가**(Docker arm64 binfmt 꺼짐 — T072 때 실측) → T093 CI 첫 실행(ARM 러너)에서 ld-13 대조 소요를 확인하고, 2 s를 넘으면 JS 엔진 대안. 결정(〔A-19〕 「Linux ARM 꼴 1회」)과 다른 까닭: 이 PC에는 ARM 실행 경로가 없어, 처음 ARM에서 도는 자리가 T093 CI다(〔V-A-6〕) | JS 정규식 엔진(`@shikijs/rehype/core` + `shiki/core` · 새 패키지 0)으로 바꾼다 — `shiki` 직접 선언 + Renovate 그룹(⓪-9). 「코드 블록 없으면 생략」은 이미 둔다 |
| VD-T090-3 | Node 24.11.1 타입 스트리핑으로 `src/index.ts` · `src/schema.ts` 직접 실행(경고 0 · `isEntryPoint()`) | ② sx-3 · ④ lx-15 | `type` · `.ts` 확장자 · erasable 문법 · `import type` 점검 |
| VD-T090-4 | 설치 lock 차이 — 사전 해석으로 실측했고(결정 문서 「사전 해석」: packages +110 · 정확 목록 110/110 · lock `+1020 / −9` · 삭제 9줄 = vitest peer 접미) **⓪ 실행으로 확인을 마쳤다**(2026-11-27 10:15 KST — 작업 트리 lock = 기대본 `cmp` 바이트 동일 · lock +1020/−9 · package.json +24/−3 · 110/110 · frozen 두 번 · `@jt/events` 267 · content 빨강 그대로 · 금지 이름 0(정정 도구 재실행 포함) — `.superpowers/t090/evidence/install/`). 결과 정본 = build-notes 「## T090」 | ⓪(실행함) | 해당 없음(충족). 다시 설치해야 하면 정확 목록 · 기대 lock을 정정된 analyze.mjs로 다시 만든다(D11 ⓪-3 3) |
| VD-T090-5 | yaml 2.9.1: `!!js/function` = 경고 · 중복 키(따옴표 키 포함) = 오류 · `logLevel: 'error'`에서 process 경고 0 · 지시자 · 문서 표식 · 앵커 · 별칭 검출(`YAML.visit`) | ③ mx-2 · mx-3 | D5 규율 보정 |
| VD-T090-6 | remark-frontmatter yaml 노드 끝 줄 = 우리 닫는 울타리 줄(LF · CRLF · CR) · 블록 안 `---␠` · `---<TAB>` 줄에서는 micromark가 먼저 닫아 끝 줄이 갈린다(〔V-A-1〕 · 〔V-B-2〕) | ①(일치 — 2026-11-27: LF · CRLF · CR · 블록 안 `---␠` · `---<TAB>`에서 닫는다 · `----` · `␠---`는 닫지 않는다) · ③ mx-1 · ④ lx-7 | 불일치면 `fence` 처리(D3 3-3 — YAML · 스키마 앞) · 원인 기록. `---␠`에서 닫지 않으면 lx-7 · mx-1 기대를 실물대로 고친다(그때는 판독 1이 `yaml`을 낸다 — 정정 노트) |
| VD-T090-7 | 각주 라벨 h2 제외 · lang별 각주 라벨 · 되돌림 라벨 정확 문자열(재참조 `-k` 자리 — 〔V-B-14〕 · mdast-util-to-hast 13.2.2) | ①(라벨 문자열 세 언어 일치 — 2026-11-27) · ③ mx-4 · mx-5 | 수집 규칙 · 옵션 보정 |
| VD-T090-8 | Linux 1회(경로 구분자 · 대소문자 · Ordinal · junction 대신 심볼릭 링크 — 〔R3 §10〕) + **파일 심볼릭 링크 탐침 1회**(저장소 밖 정규 파일을 가리키는 `study/001-x.mdx` 심볼릭 링크 → `(study/001-x.mdx, file, not-regular)` 하나 — 따라가 읽었다면 항목이 된다. C3의 핵심을 파일 링크로 확인한다. vitest 사례가 아니므로 건너뜀 규율과 무관 — 〔V-A-3〕 · 〔V-B-1〕) | 마감 · Docker `node:24` 또는 WSL. 별도 clone · frozen 설치 · content vitest(Windows `node_modules`를 건드리지 않는다). 이 기기에서 Docker · WSL을 쓸 수 있는지는 그때 확인한다 | 고친 뒤 다시 · 안 되면 T093으로 넘기고 기록 |
| VD-T086-5 | 생성 단계 기본 root | T091(T090 lx-15가 기제를 먼저 잰다) | `JT_CONTENT_ROOT` 기본 주입 등 |
| VD-T086-6 | Worker 번들에 컴파일 코드 0 · 프로덕션 draft 0 | T091 · T093 | 페이지 import 경로 정정 |

## 4. 문서 · 계약 · 규칙 보정 목록

### 4-1. 지금(T090 커밋 · 표식 「T090 보정 2026-11-2x」 · 줄 번호 = HEAD `5b9b1ff`)

| 파일 | 고칠 것 |
|---|---|
| `.claude/rules/content.md` + `docs/kr/rules/content_kr.md` | :27(KR :28) 끝에 번역 파일 규칙 · :27(KR :28) 뒤 새 줄 blog · projects(〔90-3〕 잠정) · :29(KR :30) 뒤 새 줄(YAML 1.2 · 줄 끝 · 키 · 앵커 · 별칭 · URL · url host · 읽는 항목 · 코드 펜스). KR :30은 EN :29 끝 두 문장(프런트매터 `---` 규칙 · 「조용히 지우는 일은 없다」)까지 맞춘다 — HEAD 실물로는 이미 맞다(〔V-A-15〕의 「T086 7e42cdc부터 어긋남」 전제는 성립하지 않았다 — 7e42cdc가 KR :30도 함께 고쳤다). 보정 뒤 KR :28 · :30 · 새 줄이 EN과 같은 뜻인지 한 번 더 대조한다 |
| `data-model.md` §11 | :240 pubDate 꼴 · :244 change(blog · projects 선택 · 변형 일치) · :247 파생 필드(`html` · 목차 = headings · translations · draft) |
| `.claude/rules/web.md` + `docs/kr/rules/web_kr.md` | :14 끝에 한 문장(콘텐츠 = 빌드 단계 전용). KR은 이미 `translation-pending`(web_kr.md:1) → 첫 줄 메모에 이 보정을 더한다(docs.md). 고친 첫 줄도 `> translation-pending (YYYY-MM-DD)` 꼴을 지킨다 — agent-layer `mirror-rules-web-2`가 정규식 `translation-pending \(\d{4}-\d{2}-\d{2}\)`로 본다(tests/agents/agent-layer.tests.ps1:253 · 〔V-B-16〕) |
| `AGENTS.md` + `docs/kr/AGENTS_kr.md` | Commands :52 뒤 새 행(JSON Schema export) |
| `tests/run-all.ps1` | (C1 (B)) `1b2a6` 뒤 슬롯 `1b2a7. content`(pnpm 가드 포함) |
| `packages/content/package.json` | ⓪(D11) |
| build-notes · 학습 로그 · tasks.md | 「## T090」 · `content/tmp/003-t090/<날짜>.md` · :245 tick |

**고치지 않는 것**
- ADR 0004 — 본문 불변(t086:962). D19 「캐시」(0004:42)는 모듈 메모로 충족되고 React 언급이 없다 → 편차는 tasks 문면에만 있다.
- spec · plan · tasks 문면 · `t086-design.md`(닫힌 과제) · loader.test.ts · T086 픽스처 · `content/study/*`
- `.claude/skills/finish/SKILL.md` — 노트 검증 한 줄은 /finish 인계로 둔다(§5-2 · 〔A-20〕).

### 4-2. 새 문장 원문 초안

**`.claude/rules/content.md`**(영어 정본 — KR은 같은 뜻)
- :27 끝에 더한다
  > A translation sits next to it as `<NNN-slug>.en.mdx` or `<NNN-slug>.ja.mdx`, with the same `pubDate` and `change` as the Korean file, which must exist (the loader fails otherwise — T090).
- :27 뒤 새 줄(〔90-3〕 잠정)
  > `content/blog/` and `content/projects/` use the same front matter with `change` optional; a translation follows the same rules (same `pubDate`, Korean file required) and carries the same `change` as its Korean file, or neither has one; file names are ASCII kebab-case slugs (`^[a-z0-9]+(-[a-z0-9]+)*(\.(en|ja))?\.mdx$`) — provisional until SP-2 (T090).
- :29 뒤 새 줄
  > Front matter is read as YAML 1.2 (core schema): dates stay `YYYY-MM-DD` strings; lines may end in LF, CRLF or CR; every key, quoted or not, matches `^[A-Za-z][A-Za-z0-9_]{0,63}$`; directives (`%…`), extra document markers (`---`, `...`) inside the block, anchors and aliases, YAML warnings such as unknown tags, and a block that is not a mapping are front matter errors. In front matter and body, an `http`/`https` URL never carries user info (`user:token@host`), and no URL contains whitespace, a control character or `\`; a front matter `sources[].url` host is a public domain name (localhost and IP addresses are rejected). The loader reads every entry whose name ends in `.mdx` in any letter case: a name outside the file-name rule (another case such as `.MDX`, a leading `.`, a non-ASCII character) and an entry that is not a regular file (a directory, symbolic link or junction) fail the build; other extensions are ignored. Code fences are highlighted at build time for a fixed language list; other languages render as plain text (T090).

**`data-model.md` §11**
- :240 → `| \`pubDate\` | date — 'YYYY-MM-DD' 문자열(YAML 1.2 core · Date 아님 — T086 정정 노트 2 · T090 보정 2026-11-2x) | 필수, \`updatedDate\` ≥ \`pubDate\` |`
- :244 → `| \`change\` | string | 필수(study) · 선택(blog · projects — 변형은 ko 파일과 같은 값이거나 둘 다 없다 · T090 보정 · 〔90-3〕 잠정), \`^\d{3}-[a-z0-9-]+$\` |`
- :247 끝에 더한다
  > `html`(본문 HTML — 원시 HTML 0 · Shiki 하이라이트 · 각주 라벨 · 되돌림 라벨 lang별) · `headings[]` = 목차(depth 2 · 3 · 각주 라벨 제외) · `translations[]`는 그 호출에서 draft를 거른 뒤 남은 같은 slug의 다른 lang(정렬) · ko 파일이 걸러지면 그 slug 전체 제외(T090 보정 2026-11-2x).

**`.claude/rules/web.md`** :14 끝
> `packages/content` (unified, remark, rehype, Shiki, yaml, zod) runs only in Node — in the content generation step and in its tests; pages and layouts import only the generated artifacts and at most `import type` from `@jt/content`, never a value import (T086-e; T091 guards it, T093 checks the server bundle).

**`AGENTS.md`** :52 뒤
> `| Content front matter JSON Schema | \`pnpm --filter @jt/content --fail-if-no-match schema\` — regenerates \`packages/content/schemas/study.schema.json\` from \`packages/content/src/schema.ts\`; the content vitest freshness case fails until it is rerun and committed |`

**`docs/kr/AGENTS_kr.md`** :52 뒤
> `| 콘텐츠 프런트매터 JSON Schema | \`pnpm --filter @jt/content --fail-if-no-match schema\` — \`packages/content/src/schema.ts\`에서 \`packages/content/schemas/study.schema.json\`을 다시 만든다. 다시 돌려 커밋하기 전까지 content vitest 신선도 사례가 FAIL한다 |`

**`tests/run-all.ps1`**(pnpm 가드 포함 — 〔A-15〕 · 〔B-6〕)
```powershell
# 1b2a7. content (T090) — pnpm --filter @jt/content --fail-if-no-match test: 콘텐츠 로더 vitest(T086 계약 48 + T090 자기 시험 · 픽스처 · 실제 노트 2편 · 네트워크 0).
#        packages/content/node_modules/vitest가 없으면 SKIP(설치 전 — 1b2a6과 같은 규율). pnpm이 PATH에 없으면 FAIL 줄(가드 없이 부르면
#        $ErrorActionPreference = 'Stop'이 run-all 전체를 멈춘다). 그 밖에는 exit 0 이면서 요약 줄 'Tests  N passed (N)'(실패 · 건너뜀 0)이 있어야 PASS.
if (-not (Test-Path 'packages/content/node_modules/vitest')) { Write-Host 'SKIP content -- allowed (packages/content dependencies not installed)' }
elseif (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) { Check 'content' $false 'pnpm not found on PATH' }
else {
    $o = pnpm --filter @jt/content --fail-if-no-match test 2>&1 | Out-String
    $c = $LASTEXITCODE
    Write-Host ($o.TrimEnd())
    Check 'content' ($c -eq 0 -and $o -match '(?m)^\s*Tests\s+(\d+) passed \(\1\)\s*$') "exit=$c; see content vitest output above"
}
```

### 4-3. 나중(그 과제와 함께)

| 시점 | 파일 | 고칠 것 |
|---|---|---|
| T091 | apps/web 생성 스크립트 · package.json · tsconfig · `.gitignore` · (정하면) `packages/content` 조건부 exports | §5-2 T091 |
| T091 · T093 | `packages/content` devDependencies | 형 검사 도입 때 `@types/mdast` · `@types/hast` · `@types/unist`(이미 전이 — 새 패키지 0) · `@types/node`(창 지난 판 — 〔R2 §2-2〕) |
| T093 | `ci.yml` web job | content vitest · 생성 · 콘텐츠 코드 가드(110 이름 — §5-2) |
| SP-2 | content.md · data-model · schema.ts | blog · projects 확정 · JSON Schema 소비자(Python `re` 패턴 재확인) · Shiki 테마(css-variables) · 헤딩 id 접두 · CSP |
| `/finish` | report · CLAUDE.md · 학습 노트 | 〔90-1〕–〔90-10〕(〔90-7a〕–〔90-7f〕 포함) · 노트 초안 뒤 content vitest(〔A-20〕) |

## 5. 위험 · 인계

### 5-1. 받아들인 위험

1. 문면 편차 둘 — 〔90-1〕(사용자 결정 2026-11-27) · 〔90-2〕(컨트롤러 결정 · 마감 보고 한 줄).
2. 공급망
   - 새 패키지 110개. wooorm이 81/110(비판 B `_npmUser` 기준 80/110)을 출처 증명 없이 게시했다.
   - 11월 패치 몰림: 직전 판 diff는 버그 수정 꼴이다(〔R2 §4〕 · 비판 B 대조 — 의심 토큰 증가 0).
   - `format`은 휴면 뒤 1.0을 냈다. 우리 경로는 0.2.2라 영향 0이다(`fault@2.0.1`이 `^0.2.0`).
   - 방어선 = 정확 핀 · 정확 목록 + sha512 대조(⓪-3) · 3일 창 · CI frozen
   - 첫 실행 격리는 하지 않는다(〔B-12〕 기록 — §0-3).
3. lock 변경이 events-test 방어 경로에 든다. events importer의 vitest 줄 접미도 바뀐다(〔B-1〕).
   - 방어: 렌즈 C · frozen 두 번 · `@jt/events` 267(⓪-5)
   - CODEOWNERS는 **미설정**이다(`.github/CODEOWNERS` 없음 — 운영자 인계 ci.yml:67–:70 · 〔B-7〕).
4. CI 공백(T090 → T093). run-all 슬롯(B)으로 줄인다.
   - **운영 규칙(〔B-7〕)**: T093 전에는 `pnpm-lock.yaml`이나 `packages/content` 의존을 바꾸는 PR을 머지하기 전에 run-all `content` 슬롯을 돈다. Renovate 주간 lock 유지 PR(`config:best-practices` ⊃ `:maintainLockFilesWeekly` — renovate.json:8–:11)도 포함한다.
5. Shiki 초기화 시간과 vitest 5 s 제한 — VD-T090-2(ld-13 포함) · 코드 블록이 없으면 생략한다. ARM 소요는 T093 CI 첫 실행에서 본다(이 PC는 ARM 불가 — 〔V-A-6〕).
6. 예상 밖 라이브러리 예외는 그대로 던진다(닫힌 쪽).
   - 메시지에 입력이 실릴 수 있는 경로 가운데 알려진 것(YAML 경고 · 별칭 이름 · zod `input` · 언어 이름)은 막았다.
   - 출력 경로는 T091 생성 스크립트다 → 「그 밖 예외 → stderr `content-gen: error <name>` 한 줄 · exit 1」을 인계한다(〔B-11〕 · §5-2).
7. 보수적인 본문 규칙 — `\{` · `&#123;` · 컨테이너 안 · 목록 첫 줄 「import …」 산문이 위반이다. 저자는 코드 스팬을 쓴다.
8. 숨김 · 대소문자 다른 `.mdx`와 `*.mdx` 이름의 정규 파일 아닌 항목은 빌드 실패다(〔A-1〕). 편집기 잠금 파일 · macOS `._x.mdx`가 로컬 빌드를 깰 수 있다 — 메시지가 파일을 짚는다(FILE_RE 밖 글자가 있으면 컬렉션 디렉터리를 짚는다 — 예: `.#x.mdx` → `(study/, file, name)` · 〔V-A-8〕). FILE_RE 안 이름 위반 파일은 끝까지 검증하므로(C8) 소음이 늘 수 있다.
9. JSON Schema는 로더보다 약하다(zod 밖 규칙 없음 — description에 적는다). 소비자가 오용할 수 있다.
10. zod · yaml · shiki 판이 오르면 산출이 바뀐다.
    - Renovate PR에서 sx-2 신선도가 빨강이 된다. 사람이 재생성해 커밋한다(T093 뒤 CI가 잡는다).
    - Shiki가 오르면 html이 바뀐다.
11. Windows 로컬 실행뿐이다(T093 전) — VD-T090-8.
12. 정확 핀 → Renovate PR 수가 는다(unified 생태계는 저장소가 여럿이다).
13. 헤딩 id에 접두가 없다(머리 :28 · ld-1 고정). 본문을 렌더할 때(SP-2) DOM 충돌 · clobbering을 다시 본다(추론 · 〔B-9〕).
14. T091이 페이지에서 `@jt/content` 값을 import하면 Worker 번들에 든다. web.md 새 줄 · T091 가드(+ 조건부 exports 검토 — 〔B-8〕) · T093 meta 가드(110 이름 전체)로 막는다.
15. 읽기 시간 상수(200)는 ja · en에서 거칠다.
16. 실제 노트 2편이 draft다 → 프로덕션 생성 결과는 노트 0편이다. T086-a 전까지 h-2 · h-5는 `[product]`다(t086:128–:130 · 〔R3 §6〕).
17. GFM 자동 링크 리터럴도 link 노드라 허용 목록이 적용된다(변환이 만든 위치 없는 링크 포함 — D6). 산문 `xmpp:a@b.c` · `http:user@example.com`은 이메일 부분만 mailto 링크가 되어 통과한다(0 issue — ① 실측으로 바로잡음 · r2의 「`unsafe-url`로 빌드 실패(사실)」는 거짓이었다 · 〔B-16〕 · 〔V2-2〕 · mx-8). 산문 `https://user@example.com`은 `unsafe-url`이다. 저자는 코드 스팬을 쓴다.
18. 본문 내부 주소(localhost · IP)는 거부하지 않는다. 산문 속 글자를 못 막는 반쪽 방어라서다(〔B-5〕 기록). 프런트매터는 zod `domain`이 막는다(소스 판독 — 실행 확인은 VD-T090-1 · 23).
19. `core.symlinks=false` 체크아웃의 링크는 `fence`로, FIFO 같은 그 밖 종류는 `not-regular`로 실패한다(닫힌 쪽 · 〔B-14〕 기록). root · 컬렉션 디렉터리 링크는 따라간다.
20. label · identifier 속 `{}`는 보지 않는다(렌더 영향 0 · 〔B-15〕 기록).
21. 파일 크기 · 배열 길이 · issue 수에 상한이 없다(zod GHSA-mrhx는 4.6.6에서 수정). Shiki `tokenizeTimeLimit` 때문에 html 결정성에 단서가 붙는다(〔B-17〕 기록 — D7).
22. pnpm `trustPolicy: no-downgrade` · `blockExoticSubdeps`가 꺼져 있다(〔B-13〕). T090 밖(pnpm-workspace.yaml · events-test 방어 경로)이라 마감 보고 때 여쭌다. 이번 110개의 강등은 0이다(〔탐침 B〕 `trust.mjs` 실측).
23. 프런트매터 `sources[].url`은 zod `domain` 때문에 끝 점 FQDN(`example.com.`)과 IDN 최상위 도메인(`xn--` TLD — 예: `.한국`)도 거부한다(〔V-A-5〕 · D5). 학습 노트 출처에서 드물어 받아들인다(필요하면 별도 과제). 본문 링크에는 host 규칙이 없다 — 프런트매터와 비대칭이다(〔B-5〕 · 18).
24. 위치 없는 run 안에서 문자 참조로 풀린 줄 끝(`&#10;` · `&#13;`)도 줄 끝으로 세어 줄이 커질 수 있다 → 가장 가까운 위치 있는 조상의 끝 줄에서 자른다(D6 「위치 없는 노드의 줄」 · 〔V2-2〕).

### 5-2. 인계

- **T091**(〔R3 §12〕)
  - 생성 스크립트 `apps/web/scripts/gen-content.mts`
    - `--mode production|development`는 필수다(없으면 exit 2).
    - `getCollection(c, { lang, includeDrafts: mode === 'development' })`로 **명시해서** 넘긴다(N-1 — `NODE_ENV`에 기대지 않는다).
    - 3 컬렉션 × 3 lang. `COLLECTIONS` · `LANGS`를 쓴다.
    - `ContentValidationError` → stderr에 `error.message` 줄(값 0) · 출력 디렉터리 삭제 · exit 1
    - **그 밖 예외 → stderr `content-gen: error <name>` 한 줄(`error.name`만 — 메시지 · 스택 0) · 출력 디렉터리 삭제 · exit 1**(〔B-11〕 — fs 오류의 절대 경로 · 남은 라이브러리 메시지가 공개 CI 로그로 나가지 않게)
    - 성공 → 임시 → rename · 결정적 · stdout은 수만 낸다.
    - `JT_CONTENT_ROOT`를 존중한다(T095 위반 증거 · VD-T086-6 draft 픽스처).
  - `build` = 생성 `&&` `next build` · `dev` = 생성 `&&` `next dev`. `@jt/content`는 apps/web devDependency `workspace:*`(빌드 전용)다.
  - 페이지는 생성 JSON만 import하고 형은 `import type`만 쓴다. TDD 가드: `app/**` · `src/**`에 `@jt/content` 값 import 0.
  - **조건부 `exports`**(〔B-8〕): `react-server` · `browser` · `worker` · `workerd` · `edge-light` 조건을 import 때 던지는 모듈로 보내는 안(client-only 선례 — `{"react-server":"./error.js","default":"./index.js"}`). 소비자 · Next 해석 실측과 함께 T091이 정한다.
  - **html 소비**(〔B-9〕): 목록 · 메타 산출물에는 html 0 · 상세 페이지는 slug별 조각이다(서버 번들 gzip ≤ 2.5 MiB — web.md:15). SP-1 소비자는 0이다(〔R3 §8〕). 산출 디렉터리는 gitignore한다.
  - 형 검사(정정 노트 34): tsconfig는 `bundler` + `allowImportingTsExtensions` + `noEmit` + `resolveJsonModule`이다. `@types/*`는 §4-3.
  - `apps/web/scripts/**`에 infra.md가 주입된다(정정 노트 8).
  - VD-T086-5 · 6.
  - 병렬 T090 ∥ T091(tasks.md:381)은 유지한다. 생성 스크립트의 통합 시험만 T090 뒤로 둔다.
- **T093**(〔R3 §13〕)
  - CI web 순서: frozen 설치 → content vitest → 생성(production) → tsc → eslint → web vitest → OpenNext build → bundle-budget + **콘텐츠 코드 가드** → Playwright site local
  - 콘텐츠 코드 가드: `.open-next/server-functions/default/handler.mjs.meta.json` inputs에 **packages/content 전이 닫힘 110 이름 전체**(접두 11개 대신 — 〔B-8〕: unist-util · vfile · github-slugger · oniguruma · regex 등이 접두 목록에서 빠졌다 · 지금 목록 = `.superpowers/t090/evidence/critic-b/out/expected-closure.tsv`)와 `packages/content/`가 0이어야 한다.
  - content 시험과 생성 단계는 비밀이 없는 job에서 돈다(〔B-12〕).
  - events-compat과 events-test 사이에 끼우지 않는다.
  - run-all `content` 슬롯은 유지한다. JSON Schema 신선도는 content vitest 안에서 돈다.
- **T095**: `JT_CONTENT_ROOT=<위반 픽스처>`로 `pnpm --filter @jt/web build`를 돌리면 생성 exit 1 · next build 0이어야 한다(tasks.md:253 「스키마 위반 fixture로 빌드 실패 증거」).
- **T086-a**(사용자): 노트 검토 뒤 `draft: false` — T091 첫 렌더 전 ~ T093 전.
- **SP-2**
  - blog · projects 확정(〔90-3〕)
  - JSON Schema 소비자(notes-sync → portfolio-core Django — Python `re` 패턴 재확인 · 〔A-22〕)
  - 상세 페이지 본문 렌더(〔B-9〕 · 〔A-4〕): Shiki 테마 · CSP `style-src-attr`(Shiki 이중 테마가 토큰마다 인라인 `style`을 단다 · `pre`의 `tabindex="0"`) · 헤딩 id 접두(rehype-slug는 기존 id를 모른다) · `footnote-label` id 충돌 · 되돌림 라벨 문구 재검토 · 번들 재평가
  - watch 모드 캐시 무효화
- **/finish**
  - 〔90-1〕–〔90-10〕(〔90-7a〕–〔90-7f〕 포함) · CLAUDE.md Recent Changes · KR 미러(web_kr pending)
  - **노트 초안 뒤 `pnpm --filter @jt/content --fail-if-no-match test`를 돈다**(〔A-20〕). ld-1이 `content/study` 전체 — 새 노트까지 — 를 검증한다(loader.test.ts:232). finish 스킬은 content.md를 따르라고만 하고 로더 검사를 돌지 않는다(.claude/skills/finish/SKILL.md:29–:30).
- **운영자**: CODEOWNERS 미설정(〔B-7〕 — ci.yml:67–:70의 인계 그대로).

### 5-3. 시점별 사용자 질문(한 번에 하나 — user-decision-style)

| 순서 · 시점 | 질문 | 자료 |
|---|---|---|
| 1 · ✅ 2026-11-27 | 〔90-1〕 「`React.cache` 1회」 → 생성 단계 모듈 메모(react 0) — 결정됨 | §0-2 |
| 2 · ✅ 2026-11-27 | 로더 새 의존 설치 승인 → 권고 세트 12 + ajv 둘 — 결정됨 | §0-3 · 결정 문서 「사전 해석」 |
| 3 · T090 마감 보고 | 알림(질문 아님): 〔90-3〕 blog · projects 잠정 · 〔90-2〕 readdir · 〔B-5〕 userinfo(〔90-7f〕) · 〔A-1〕 숨김 · 대소문자 · not-regular(〔90-7d〕) · 〔A-9〕 CRLF 정상(〔90-7c〕) · 편차 목록 · run-all 슬롯 · Linux 1회 결과. **질문: 〔B-13〕 pnpm `trustPolicy: no-downgrade`(+ `blockExoticSubdeps`)를 별도 커밋으로 둘지** | §0-5 · §1-4 · §0-6 · §5-1 22 |
| 기존 · T091 전 | 곁가지 셋(Next · OpenNext peer · 압축 한도 · #1334) · T086-a 노트 검토 | t086 §5-3(:1015–:1016) |
| SP-2 본문 렌더 전 | Shiki 테마(css-variables) · 헤딩 id 접두 · html 소비 · CSP | §5-2 |

## 6. 확정 보정(컨트롤러 · 2026-11-27 — r2 검증 · ① 실물 대조)

r2 검증(`.superpowers/t090/reviews/verify-r2.md` — approve_with_fixes · HIGH 0 · MEDIUM 2 · LOW 2 · NIT 4)의 지적과 ① 실물 대조(결정 문서 「① 실물 대조」 — T086 기대값 전부 일치 · 설계 어긋남 둘)를 컨트롤러가 정했다(2026-11-27 · r3 없음). 확정 보정 수정자가 보고한 두 자리(위치 없는 노드의 열 · T086 픽스처 디렉터리 수)도 컨트롤러가 정했다(6-9 · 6-10). 보정은 본문에 넣었고, 이 절은 항목마다 무엇을 · 왜 · 본문 어디를 고쳤는지 적는다(T086 「§7 확정 보정」 선례). **확정 설계 = r2 본문 + 이 절.** 본문과 이 절이 어긋나면 이 절이 이긴다.

### 6-1. ① 실물 대조 반영 — 설계 어긋남 둘 · mx-4 기대 html(〔V2-2〕 · MEDIUM)

- **어긋남 1 — 산문 xmpp**
  - 무엇: r2의 「산문 `xmpp:a@b.c` → GFM 자동 링크 → `unsafe-url`(사실 — 〔B-16〕)」을 사실대로 바로잡았다. 산문 `xmpp:a@b.c` · 산문 `http:user@example.com` = 0 issue다(결과는 text + mailto 링크라 무해하다). `xmpp:` 거부는 명시 링크 `[x](xmpp:a@b.c)`와 변환 경로(닫히지 않은 `[` 뒤 → 위치 없는 xmpp 링크 — 7-5 · 7-x2)로 잰다. 산문 userinfo 거부는 `https://user@example.com`(토크나이저 링크 · 위치 있음 — 7-10)으로 잰다.
  - 왜: 설치 판의 토크나이저(micromark-extension-gfm-autolink-literal 2.1.0)가 이메일 부분을 먼저 `mailto:` 링크로 만들고 `xmpp:`는 앞 text에 남긴다(`lib/syntax.js:81` · `:811–:817`). mdast 변환의 xmpp 정규식(mdast-util-gfm-autolink-literal 2.1.2 `lib/index.js:157`)은 그 뒤라 맞출 것이 없다(〔① 탐침〕 7-1 · 7-1b · 7-2). 그대로 두면 mx-8이 표와 다르게 FAIL한다(D15 → tick 0).
  - 본문: D6 「자동 링크」 · D12 ① 7 · mx-8(산문 자동 링크 리터럴 · 명시 `xmpp:` 링크) · §3 「정정 노트 5 확장」 · §5-1 17
- **어긋남 2 — 위치 없는 노드**
  - 무엇: D6에 「위치 없는 노드의 줄」 규칙을 두었다(`expression` · `unsafe-url` · `esm` 모두). 줄 = 같은 부모에서 앞선 위치 있는 형제의 끝 줄(없으면 부모의 줄 — 부모도 위치가 없으면 같은 규칙으로 재귀) + 그 사이 위치 없는 형제들의 text 값(자손 포함)에 든 줄 끝 수(`\r\n` · `\r` · `\n` 각각 하나)이고, 가장 가까운 위치 있는 조상의 끝 줄을 넘지 않게 자른다. `position`을 그대로 읽지 않는다. 머리 :38 「line = 노드 시작 줄」을 지키는 해석이다. 사례 = mx-8 7-x1–7-x4 · 변이 = mu-73 · mu-74 · 한계 = §5-1 24.
  - 왜: 토크나이저가 거절하고 mdast 변환(mdast-util-gfm-autolink-literal 2.1.2 · mdast-util-find-and-replace 3.0.5 `lib/index.js:137–:170`)이 링크를 만든 경우(닫히지 않은 `[` 뒤 · `"` 바로 뒤 `www.`) 새 링크와 쪼개진 text 노드에 position이 없다. `node.position.start.line`을 읽는 구현은 던지고, 대체 규칙 없이 안전하게 읽는 구현은 line이 비어 나온다(〔① 탐침〕 7-x1–7-x3 `@null`). break 노드는 끝 위치가 다음 줄 머리라(mdast-util-from-markdown 2.1.0 `lib/index.js:732–:740`) 규칙이 그대로 맞는다.
  - 본문: D4 `line` · D6 표 line 열 · D6 「위치 없는 노드의 줄」 · mx-8(7-x1–7-x4) · D13 mu-73 · mu-74 · D16 :37–:41 · §5-1 24
- **mx-4 기대 html**
  - 무엇: ① 8 산출(라이브러리를 D7 옵션으로 직접 부른 값 · Shiki 제외 · 우리 구현이 아니다)을 컨트롤러가 `packages/content/tests/fixtures/t090-mx-4/{input.md, expected-ko.html, expected-en.html, expected-ja.html}`로 옮겼다(커밋 ③). 빌더는 고치거나 다시 만들지 않는다. 기대 html 사실(끝 줄바꿈 0 · `<` → `&#x3C;` · `&` → `&#x26;` · `>` · `"` 그대로 · 각주 라벨 h2 `class="sr-only" id="footnote-label"` · 입력의 이스케이프 문장 하나 — 문자 참조 `&lt;b&gt;` · `&amp;` · 큰따옴표)을 mx-4에 적었다.
  - 왜: r2는 픽스처 자리를 `t090-*`(D1 · D2)와 evidence(① 8)로 따로 적어 실제 자리와 맞지 않았다. 기대 html에 든 이스케이프 문장과 끝 줄바꿈 0도 mx-4 서술에 없었다(〔V2-2〕 ③).
  - 본문: D1 · D2 트리 · D12 ① 8 · ① 출력 줄 · mx-4 · D15 조각 ① 행 · 커밋 ③ 「함께 드는 것」
- **덧붙인 사실**: `footnoteBackLabel(referenceIndex, rereferenceIndex)`의 rereferenceIndex는 1부터 센다(mdast-util-to-hast 13.2.2 `lib/footer.js:166` · `:172`). JSDoc의 「0-indexed」와 다르다 → 코드를 따른다(우리 `-k` 규칙은 코드와 맞는다) → D7
- **진행 · 머리**: D12 ① 진행 줄(「① 실물 대조 끝(2026-11-27) — …」 · 9는 탐침 밖이라 mx-8 빨강 단계에서 확인한다) · ① 합격 줄(어긋남 둘 = §6-1) · §3 VD-T086-3 · VD-T086-4 · VD-T090-6 · VD-T090-7의 「① 일치」 · 머리 상태 · 경과 7 · 입력(검증 r2 · 결정 문서 「① 실물 대조」) · 증거(`vd-t086-3-4/` · `v2-1-zod-format/`) · 표기(〔① 탐침〕 · 〔V2-1 탐침〕 · 〔소스〕) · 끝 「정정 노트」

### 6-2. url `format` 되살림 — (A)(〔V2-1〕 · MEDIUM)

- 무엇: 내보내기에서 url 스키마에 `.meta({ format: 'uri' })`(또는 동등한 `toJSONSchema` `override`)로 `format: "uri"`를 다시 싣는다. sx-1에 「url 속성 = `format: "uri"` + `pattern`」 단언을 더했다. r2의 sx-5 · sx-7 기대는 그대로다.
- 왜: zod 4.6.7은 `.regex()`가 붙으면 내보낸 JSON Schema에서 url의 `format`을 지운다(`v4/core/json-schema-processors.js:120–:127`). 그러면 url 속성이 접두 `pattern`뿐이라, sx-7 「둘 다 거부」 가운데 뒤 공백 · 탭 · NBSP · `\` · U+0001 · DEL · U+0085 · U+FEFF와 sx-5 invalid 「공백 · 탭 든 url」이 JSON Schema 쪽에서 FAIL한다. 컨트롤러 탐침(〔V2-1 탐침〕)으로 확인했다: `.meta` · `override` 둘 다 `{type:"string", pattern:"^[Hh][Tt][Tt][Pp][Ss]?:\\/\\/", format:"uri"}`를 낸다. 그때 ajv 2020 + ajv-formats는 위 값들을 거부하고 userinfo · localhost · IP는 받으며, zod 런타임 판정은 바뀌지 않는다.
- 본문: D5 url(까닭 한 줄) · sx-1 · sx-5(invalid 근거 · valid 한계 근거) · sx-7(JSON Schema 쪽 거부 주체) · VD-T090-1 첫 항목(「내보낸 url에 `format`이 남는가(되살림 뒤)」 — 확인됨 · r2의 url 패턴 항목을 이 항목에 합쳤다) · D13 mu-29(되살림 빠짐)

### 6-3. 날 DEL 문구(〔V2-3〕 · LOW)

- 무엇: 「꺾쇠 없는 대상의 날 DEL은 명시 링크가 되지 않는다(대상이 http(s)면 GFM 자동 링크 리터럴이 대신 위치 있는 link를 만들어 결국 `unsafe-url`). 명시 링크 경로는 꺾쇠 대상으로 잰다」로 고쳤고, ① 9 기대도 맞췄다.
- 왜: r2의 「꺾쇠 없는 대상은 … 링크가 되지 않는다」는 명시 링크에만 맞다. http(s) 대상이면 명시 링크가 실패한 뒤 `(` 다음에서 자동 링크 리터럴이 DEL까지 먹는 위치 있는 link를 만든다(micromark-core-commonmark 2.0.4 `lib/label-end.js:243` · `:313–:314` · micromark-extension-gfm-autolink-literal 2.1.0 `lib/syntax.js:803–:805` · `:567–:591`). 꺾쇠 대상은 DEL을 받는다(micromark-factory-destination 2.0.1 `index.js:119–:127`). ① 9가 「link 0」을 기대하면 거짓 어긋남이 난다.
- 본문: D6 「문자 참조 · 날 글자」 · D12 ① 9 · mx-8 DEL 괄호

### 6-4. description의 url host(〔V2-4〕 · LOW)

- 무엇: D10 description의 「JSON Schema에 없는 것」 목록과 〔90-4〕에 「url host(공개 도메인 — zod domain, 런타임 전용)」을 더했다.
- 왜: hostname 검사는 zod 런타임 전용이라 JSON Schema에 실리지 않는다(zod 4.6.7 `v4/core/regexes.js:63` · `v4/core/schemas.js:255–:258` · `:295`). sx-5는 이를 한계로 고정했는데, 소비자에게 알리는 description은 말하지 않았다.
- 본문: D10 「내보내기」 description · §1-4 〔90-4〕

### 6-5. yaml 정적 탐지(〔V2-5〕 · NIT)

- 무엇: lx-18에 「yaml 모듈 바인딩의 `.parse(` — `\byaml\.parse\(`(대소문자 무관)」를 더했다.
- 왜: `import * as yaml from 'yaml'` + `yaml.parse(`가 빠졌다. 이 꼴은 `processor.parse(` · `JSON.parse(`와 겹치지 않는다. 행동 가드 mx-3 · mu-26은 그대로다.
- 본문: lx-18

### 6-6. V8 `source` 근거 문구(〔V2-6〕 · NIT)

- 무엇: sx-1 근거를 「V8 `source`는 줄 끝(LF · CR · U+2028 · U+2029)만 이스케이프」로 고쳤다.
- 왜: 검증자가 Node 내장으로 재어 보니 줄 끝 넷을 이스케이프한다. 결론(패턴 ASCII 단언이 필요하다)은 같다.
- 본문: sx-1

### 6-7. 판독 1만 잡는 파일 단위 꼴(〔V2-7〕 · NIT)

- 무엇: D5 「판독 1만 잡는 꼴」에 「블록 안 `--- !!map` 줄 + 다음 줄 매핑」을 더했고, lx-7에 파일 단위 하위 사례 하나(그 꼴 → `[(study/001-a.mdx, frontmatter, yaml, -)]` 하나)를 더했다. 이 사례가 mu-59(판독 1 제거)를 파일 단위에서 잡으므로 mu-59의 귀속(lx-7)과 동등 기록(`--- !!map`은 동등이 아니다)을 고쳤다.
- 왜: micromark는 그 줄을 닫지 않고(공백 뒤에 내용이 있다), yaml은 받는다(표식 줄 뒤 줄바꿈이 있어 MISSING_CHAR가 나지 않는다 — yaml 2.9.1 `dist/compose/compose-doc.js:26–:31`).
- 본문: D5 판독 1 · lx-7 · D13 mu-59

### 6-8. 변이 행 · lx-7 root(〔V2-8〕 · NIT)

- 무엇: D13에 두 행을 더했다 — mu-75 「객체 아닌 opts 허용」 → lx-3 `'x'` · mu-76 「url host 검사 없음(`z.url()`)」 → sx-7 localhost · IP. lx-7에 「하위 사례마다 mkdtemp root」를 적었다.
- 왜: r2가 넓힌 결정 둘에 변이 행이 없었다(잡는 사례는 이미 있었다). lx-7의 하위 사례 여럿이 같은 이름 `study/001-a.mdx`를 쓴다.
- 본문: D13 mu-75 · mu-76 · D13 머리말(mu-34–mu-76 — 6-1의 mu-73 · mu-74 포함 · 6-9가 mu-78까지 넓혔다) · §1-1 합격선 6 · D15 렌즈 C · lx-7

### 6-9. 위치 없는 노드의 열(컨트롤러 — 확정 보정 수정자 보고)

- 무엇: D6 「위치 없는 노드의 줄」에 열을 더했다. 시작 점(줄 · 열)을 같은 순회로 얻는다 — 출발은 앞선 위치 있는 형제의 끝 점(없으면 부모의 시작 점 — 재귀)이고, 사이 위치 없는 형제들의 text 값을 따라 줄 끝마다 다음 줄 1열, 그 밖 글자는 UTF-16 code unit마다 열 + 1이다. 줄 규칙(6-1)은 이 순회의 줄 성분 그대로다. 열은 D4 정렬에만 쓴다(issue에 열은 없다). lx-7에 순서 사례 둘 · D13에 mu-77 · mu-78을 더했다.
- 왜: D4 정렬은 줄 → 열 → 규칙 순인데 6-1은 줄만 정했다. 그래서 같은 줄에 위치 있는 issue와 위치 없는 issue가 함께 나면 순서가 정해지지 않았다(확정 보정 수정자 보고 — 예 `{x} see "www.example.com" <b>`). 열을 같은 순회로 세면 머리 :31 「문서 순」과 맞는다.
  - 〔열 탐침〕 `.superpowers/t090/evidence/col-probe/`(2026-11-27 · 컨트롤러): micromark 열은 UTF-16 code unit 단위다(`unit` — 서로게이트 쌍 하나 + 공백 뒤 html 열 = 4). `order-A`는 위치 없는 text(9 code unit) · 위치 없는 link · 위치 없는 text · html(5:27)이고, `order-B`는 위치 있는 link(5:1–5:18) 뒤 위치 없는 text · link · text다.
  - 두 사례는 「열 = +∞」(order-A — raw-html이 먼저 나온다)와 「부모 시작 열」(order-B — 열 1 동률이 되어 규칙 순으로 expression이 먼저 나온다)을 각각 잡는다.
- 본문: D4 순서 4 · D6 「위치 없는 노드의 줄」 열 · lx-7 · D13 mu-77 · mu-78 · D13 머리말 · §1-1 합격선 6 · D15 렌즈 C · 머리 증거 · 표기

### 6-10. T086 픽스처 디렉터리 수(컨트롤러 — 확정 보정 수정자 보고)

- 무엇: D2 트리의 「T086 13 디렉터리」를 「T086 12 디렉터리」로 고쳤다.
- 왜: `git ls-files`로 세면 T086 픽스처 디렉터리는 12개다(body-rules · collect · draft-invalid · drafts · frontmatter · headings · i18n · ko-missing · missing-pubdate · schema-violations · updated-before · updated-same). r2의 13은 오기였다.
- 본문: D2 트리

## 정정 노트

- 없음(확정).
