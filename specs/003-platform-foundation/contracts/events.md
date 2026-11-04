# Contract: 이벤트 (Kafka · CloudEvents · outbox)

## 토픽 규약

- 이름: prod `<pod>.<entity>.<event>`, dev `dev.<pod>.<entity>.<event>`. pod 이름은 kebab-case, entity·event는 단수 소문자. DLQ prod `<pod>.dlq` · dev `dev.<pod>.dlq`(2026-10-16 T056 정정 — KafkaUser ACL 접두가 env별이라 dev 자격으로는 `<pod>.dlq`에 쓸 수 없다 · data-model §6).
- 파티션 3, 키 = `tenantid`(UUID 문자열). 같은 테넌트의 이벤트는 순서를 보존한다.
- 보존 7일. 소비자는 7일 안에 따라잡지 못하면 재색인/재투영으로 복구한다(원천은 각 pod DB).
- 쓰기 권한: 토픽 접두(prod `<pod>.` · dev `dev.<pod>.`)의 소유 pod만. 다른 pod가 대신 발행하지 않는다.

## 봉투 (CloudEvents 1.0, JSON)

```json
{
  "specversion": "1.0",
  "id": "01J8QK3Q9S8ZQ4V7H2M1X0N5AB",
  "source": "identity-admin",
  "type": "identity-admin.session.revoked",
  "time": "2026-09-01T03:21:07.123Z",
  "subject": "user:9f2c…",
  "tenantid": "018f6c2e-…",
  "datacontenttype": "application/json",
  "data": { "sub": "9f2c…", "sid": null, "nbf": 1756696867, "reason": "logout_all" }
}
```

- `id` = outbox 행 id(ULID). 소비자는 `(consumer_group, id)`를 저장해 멱등 처리한다.
- Kafka 헤더: `ce_type`, `ce_source`, `ce_id`, `content-type: application/cloudevents+json`(structured mode).
- `tenantid`는 확장 속성(CloudEvents 확장 규칙: 소문자 영숫자). 값은 항상 테넌트 UUID(slug 금지). 사용자 단위 이벤트의 `tenantid`는 그 사용자의 테넌트(SP-1 가정: 사용자당 테넌트 1).
- 필드 형식(T067 보정 2026-11-03 — 정본 `packages/events/schemas/_envelope.json`): `specversion` const `"1.0"` · `id` ULID `^[0-7][0-9A-HJKMNP-TV-Z]{25}$(?!\n)` · `source` pod 이름(kebab-case `^[a-z][a-z0-9]*(-[a-z0-9]+)*$(?!\n)`) · `type` = **논리 토픽**(env 접두 없음 — dev Kafka 토픽은 `dev.` + `type`, 접두는 릴레이가 붙인다 · 점으로 나뉜 kebab-case 토큰 셋 이상 — `<pod>.<entity>.<event>`, v2 토픽은 토큰을 하나 더 쓴다) · `time` RFC 3339 date-time · `subject` `<종류>:<id>`(`^[a-z][a-z0-9-]*:[^\x00-\x1f\x7f-\x9f]+$(?!\n)` — id 부분은 제어 문자(C0 · DEL · C1)가 없는 비지 않은 문자열) · `tenantid` 소문자 UUID(`format: uuid` + pattern) · `datacontenttype` const `"application/json"` · `data` 객체.
- 패턴 이식성(T067 r2 보정 — 두 엔진 실측): pattern은 JS(ajv · u 플래그)와 Python `re.search`(jsonschema)에서 같은 뜻으로만 쓴다. ① 명시 문자 클래스만 — `\d` · `\w` · `\s` 금지(Python은 유니코드 숫자·글자까지 맞춘다). ② `.` 금지 — Python의 `.`은 CR · U+2028/2029에도 맞고 JS는 거부한다. ③ 끝 고정은 `$(?!\n)` — Python의 `$`는 끝 줄바꿈 바로 앞에서도 맞는다(`id` + `"\n"`을 Python만 통과시켰다). pattern은 main에 들어간 뒤로 바꿀 수 없다(§호환성 규칙 「값 제약」).

## SP-1에서 정의하는 스키마 (`packages/events/schemas/`)

| 토픽 | subject | data | 발행 | 소비(예정) |
|---|---|---|---|---|
| `identity-admin.session.revoked` | `user:<sub>` | `sub`(string, req) · `sid`(string\|null) · `nbf`(int epoch, req) · `reason`(enum logout·logout_all·admin·authentik_webhook·tenant_suspended, req) | identity-admin | insights(SP-3). 거부 목록 재적용에는 쓰지 않는다 — pod는 Dragonfly를 직접 조회하고, 재적용은 identity-admin의 30 s 무조건 재적용(contracts/denylist.md) |
| `identity-admin.user.registered` | `user:<sub>` | `sub` · `email_hash`(sha256) · `tenant_id` · `role` · `registered_at` | identity-admin(SP-2) | portfolio-core·engagement(투영), notification(환영 메일) |
| `identity-admin.tenant.created` | `tenant:<id>` | `tenant_id` · `slug` · `display_name` | identity-admin(SP-2) | 모든 pod(테넌트 시드) |
| `portfolio-core.note.published` | `note:<slug>` | `slug` · `lang` · `title` · `tags[]` · `published_at` · `change` | portfolio-core(SP-2, CI notes-sync) | search(색인), notification(구독 알림), insights |
| `engagement.comment.created` | `comment:<id>` | `comment_id` · `target`(`note:<slug>` 등) · `author_sub` · `created_at` · `body_excerpt`(≤ 200자) | engagement(SP-2) | notification, insights |
| `media.object.ready` | `media:<id>` | `media_id` · `owner_sub` · `kind`(image·file) · `variants[]`(name·url) · `bytes` | media(SP-2) | portfolio-core·engagement(첨부 연결) |

### 필드 형식 · 필수 (T067 확정 2026-11-03)

정본은 `packages/events/schemas/<토픽>.json`이다(이 표와 어긋나면 표를 먼저 고친다). 필수 집합은 main에 들어간 뒤로 바꿀 수 없다(아래 §호환성 규칙 — 추가 · 제거 모두 금지). 모든 속성은 `type`을 명시한다(나중에 `type`을 더하는 것도 타입 변경이다). 공통 형식: UUID = 소문자 UUID 문자열 · 시각 = RFC 3339 date-time · 문자열 = 비지 않은 문자열(예외는 표에 적는다 — `body_excerpt`) · pattern의 끝은 `$(?!\n)`(위 §봉투 「패턴 이식성」).

| 토픽 | 필수 | 선택 | 형식 |
|---|---|---|---|
| `identity-admin.session.revoked` | `sub` · `nbf` · `reason` | `sid` | `sub` 문자열 · `sid` 비지 않은 문자열 또는 null · `nbf` 정수 ≥ 0 · `reason` enum(위 표의 5값) |
| `identity-admin.user.registered` | `sub` · `tenant_id` · `role` · `registered_at` | `email_hash` | `sub` 문자열 · `email_hash` sha256 소문자 hex 64자(메일이 없는 IdP 사용자가 있다) · `tenant_id` UUID · `role` enum `owner` · `member`(`admin`은 SP-2에 enum 값 추가로) · `registered_at` 시각 |
| `identity-admin.tenant.created` | `tenant_id` · `slug` · `display_name` | — | `tenant_id` UUID · `slug` `^[a-z0-9][a-z0-9-]{1,30}$(?!\n)`(data-model §1) · `display_name` 1–80자 |
| `portfolio-core.note.published` | `slug` · `lang` · `title` · `tags` · `published_at` | `change` | `slug` kebab-case(`^[a-z0-9]+(-[a-z0-9]+)*$(?!\n)`) · `lang` enum `ko` · `en` · `ja` · `title` 문자열 · `tags` 비지 않은 문자열의 배열(빈 배열 허용) · `published_at` 시각 · `change` `^[0-9]{3}-[a-z0-9-]+$(?!\n)`(study만 — data-model §11) |
| `engagement.comment.created` | 다섯 필드 전부 | — | `comment_id` · `author_sub` 문자열 · `target` `<종류>:<id>`(봉투 `subject`와 같은 pattern) · `created_at` 시각 · `body_excerpt` 0–200자(**빈 문자열 허용** — 본문이 첨부뿐이거나 정규화 뒤 비는 경우 · 코드 포인트 — ajv · Python 같은 셈 · T067 r2 명시) |
| `media.object.ready` | 다섯 필드 전부 | — | `media_id` · `owner_sub` 문자열 · `kind` enum `image` · `file` · `variants` 항목 `{name 문자열, url https 절대 URI}`(둘 다 필수 · 빈 배열 허용) · `bytes` 정수 ≥ 0. `url`은 `format: uri` + pattern `^https://[A-Za-z0-9._~:/?#@!$&'()*+,;=%\[\]-]+$(?!\n)`(scheme은 https만 · RFC 3986 글자만 — Python 소비자는 `uri` 형식을 검사하지 않으므로 scheme과 글자 집합은 pattern이 지킨다 · `javascript:` · `file:` · `http:` 거부 · T067 r2 보정). 렌더하거나 가져오기 전에 허용 호스트를 확인하는 것은 소비자 몫이다 |

- SP-2 토픽의 id(`comment_id` · `media_id`)와 sub류에는 형식을 두지 않는다 — 생산 pod의 id 체계가 정해지지 않았고, 형식을 나중에 두거나 풀면 그 형식에 기댄 생산자 · 소비자가 깨진다. 표본 sub가 `9f2c-test` 꼴이다(T061 · T064).
- Python 소비자(jsonschema 4.26)는 `uuid`를 자체 검사하지만 `date-time` · `uri`는 추가 패키지(`rfc3339-validator` · `rfc3987`)가 없으면 검사하지 않는다(통과로 처리) — SP-2 소비자 도우미가 정한다. UUID는 pattern이 함께 있어 형식 검사 없이도 걸린다.

## 호환성 규칙 (CI `packages/events` 검사)

- 허용: 선택 필드 추가, enum 값 추가(소비자는 알 수 없는 값을 무시). 그래서 토픽 data 스키마와 `_envelope.json`은 **`additionalProperties: false`를 두지 않는다** — 소비자는 알 수 없는 속성을 무시한다(enum 미지 값 무시와 같은 원칙). 닫힌 스키마면 생산자가 허용된 선택 필드를 추가해 배포한 순간 옛 스키마를 가진 소비자(pod별 배포)가 모든 이벤트를 DLQ로 보내고, 봉투는 CloudEvents 확장 속성(예: `traceparent`)을 받을 수 없다(T064 리뷰 A-1 · 2026-11-02).
- 금지: 필드 삭제·이름 변경·타입 변경(`type`의 집합이 달라지면 전부 — `string` → `["string", "null"]`도 소비자에게는 타입 변경), `required` 추가, **`required` 제거**(존재를 전제한 소비자가 깨진다 — T064 보정 2026-11-02), enum 값 삭제, 스키마 파일 삭제(토픽 제거). 필요하면 새 토픽 `…v2`를 만들고 둘 다 발행하는 기간을 둔다. 메타데이터(`title` · `description` · `examples` · `x-version` · `$comment`)만 바뀌는 것은 위반이 아니다.
- 검사 방식: `main`의 스키마와 PR 스키마를 필드 단위로(중첩 객체 · 배열 `items` 포함) 비교(스크립트 `packages/events/scripts/check-compat.mjs` — CLI `--base <dir> --head <dir>` · 종료 코드 0 위반 없음 / 1 위반 / 2 사용·입출력 오류 · 위반은 파일 · JSON 포인터 경로 · 종류를 전부 보고하고 첫 위반에서 멈추지 않는다), 위반 시 실패. `_envelope.json`도 같은 규칙을 받는다.
- **CI 기준과 검사기**(T067 보정 2026-11-03): 기준은 PR이면 merge 커밋의 첫째 부모(둘째 부모가 PR head인지 확인), push면 `before`(0이면 빈 기준 — 전부 추가). 검사기는 **기준 커밋의 `check-compat.mjs`**를 쓰고, 기준에 검사기도 스키마도 없을 때만 이 변경의 것을 쓴다(부트스트랩 — 아래 「부트스트랩 조건」) — PR이 검사기를 약하게 고쳐 같은 PR의 스키마 변경을 통과시키지 못하게 한다. 그래서 검사기의 CLI 경로는 Node 내장 모듈만 쓰고 ajv는 `validateEvent`가 처음 부를 때 지연 로드한다(CI가 기준 쪽 사본을 패키지 밖에서 돌린다). PR 브랜치 안의 스키마 디렉터리 삭제는 전부 `schema-removed`다. 판정 규칙의 정본은 `scripts/ci/events-compat.sh` 머리 주석이다.
  - 게이트 job(T067 r2 보정 · r4 순서 보정): job `events-compat`의 스텝은 Node 설치 → 체크아웃 → 게이트 스크립트 순서이고, 체크아웃 뒤에 도는 스텝은 게이트 스크립트 하나뿐이다. PR 코드(의존성 설치 · vitest — 테스트 · 테스트가 import하는 PR의 검사기 · package.json 스크립트)는 다른 job `events-test`에서 돈다 — 같은 러너에서 게이트보다 먼저 돌면 PR 코드가 게이트 스크립트 · git 객체 · 속성 · 다음 스텝의 환경(`GITHUB_PATH` · `GITHUB_ENV`)을 바꿔 기준 쪽 검사기를 무력화할 수 있다. 예외는 부트스트랩뿐이다 — 게이트 스텝 안에서 이 변경의 검사기가 돌지만 기준이 비어 지킬 것이 없다.
  - Node 설치는 체크아웃 전(T067 r4 보정): setup-node(v6.5.0 원문 `printEnvDetailsAndSetOutput`)는 설치 뒤 조건 없이 작업 공간을 cwd로 `node` · `npm` · `yarn`의 `--version`을 돌리고, 러너 이미지의 Yarn 1(1.22.22 원문 `start()`)은 `--version`을 처리하기 전에 cwd와 그 위 디렉터리의 `.yarnrc` · `.yarnrc.yml`에 적힌 `yarnPath`를 실행한다(러너 실측은 VD) — setup-node가 체크아웃 뒤에 돌면 게이트 파일을 하나도 바꾸지 않은 PR(`.yarnrc.yml` + 스크립트 하나)이 게이트보다 먼저 같은 러너에서 코드를 돌린다. 그래서 setup-node는 빈 작업 공간에서 체크아웃보다 먼저 돌고, Node 버전은 `node-version-file`이 아니라 ci.yml에 적은 `node-version` 값으로 준다 — 그 값은 `.node-version`과 같아야 한다(CI에서는 job `events-test`의 `schemas.test.mjs` sch-23이, 로컬에서는 하네스 st-5 · st-15가 지킨다 — 둘이 갈라진 채 검사기가 새 판에만 있는 Node API를 쓰면, 머지 뒤 게이트가 그 검사기를 옛 Node로 돌려 교착이 된다 · T067 r5 보정). 이 검사들은 **줄 단위 드리프트 검사**다 — 실수로 갈라진 값 · 옮겨진 핀 · 늘어난 setup-node 스텝을 잡는다. YAML 이어짐 줄 · 이스케이프 · 별칭 · 가짜 job 블록처럼 ci.yml을 일부러 꼬아 쓰는 편집은 이 검사의 범위가 아니다 — ci.yml을 고치는 PR은 게이트를 통째로 바꿀 수도 있으므로, 그런 편집은 아래 「한계」대로 게이트 파일 리뷰(코드 소유자)가 막는다(T067 r8 보정). 이 보호는 GitHub 호스티드 러너(job마다 새 VM — 체크아웃 전 작업 공간이 비어 있다)를 전제한다 — 작업 공간을 재사용하는 자체 호스티드 러너로 옮기면 이전 job이 체크아웃한 PR 파일을 체크아웃 전 탐침이 실행할 수 있어 이 보호는 무효다(T067 r5 보정).
  - 캐시 없음(T067 r3 보정): 게이트 job은 어떤 캐시도 복원하지 않는다 — setup-node에 `cache` 입력을 두지 않고 `package-manager-cache: false`를 둔다. setup-node(v6.5.0 원문)는 `cache`가 없어도 체크아웃의 `package.json`(`devEngines.packageManager` · `packageManager`)이 npm을 가리키면 자동 캐시를 켜고, 복원 경로는 체크아웃의 `.npmrc`가 고른다 — 같은 PR의 이전 실행이 저장한 디렉터리(스키마 · 게이트 스크립트)가 게이트 앞에 풀려 최종 diff에 보이지 않는 우회가 된다. setup-node가 체크아웃 전에 돌아 읽을 `package.json`이 없어도 이 입력은 그대로 둔다(심층 방어 · T067 r4 보정).
  - 기준 꺼내기(T067 r2 보정): 기준 스키마와 검사기는 기준 커밋의 트리에서 `git ls-tree` + `git cat-file blob`으로 꺼낸다(`git archive` 아님 — `.gitattributes`의 `export-ignore` 한 줄이 머지되면 이후 기준이 비었다 · 실측). 경로 성분이 트리가 아니거나(심볼릭 링크 · 파일 · gitlink) git이 실패하면 2다 — "없음"으로 보지 않는다. `.json` 항목은 일반 파일(blob 100644 · 100755)이고 이름이 `^[A-Za-z0-9_][A-Za-z0-9._-]*\.json$`인 것만 받는다(아니면 2 · `.json`이 아닌 항목은 무시한다).
  - 변경 쪽(T067 r3 보정): CI(`GITHUB_ACTIONS=true`)에서는 변경 쪽 스키마와 부트스트랩 검사기도 HEAD 커밋(= `GITHUB_SHA`)의 트리에서 같은 방법으로 꺼낸다 — 작업 트리는 체크아웃이 PR의 `.gitattributes`(`working-tree-encoding` · `ident` · `eol`)로 바꾼 바이트라 머지되는 blob과 다를 수 있다(실측: `ident` · 음역 인코딩으로 겉의 JSON이 달라진다). 또 작업 트리의 스키마 `.json`은 그 blob과 바이트가 같아야 한다(`git hash-object --no-filters` · `.json` 집합도 같다 — 다르면 2: 소비자의 체크아웃이 검사한 것과 다른 내용을 읽는다). 로컬 실행(CI 밖)은 작업 트리를 읽는다.
  - 다음 기준의 모양(T067 r3 보정): 변경 쪽도 기준 쪽과 같은 모양 규칙(경로 성분 = 디렉터리 · `.json` = 일반 파일 · 이름 꼴)을 지켜야 하고, 검사기 경로 `packages/events/scripts/check-compat.mjs`도 기준 쪽처럼 스키마 수와 상관없이 본다 — 경로 성분이 디렉터리가 아니거나 검사기가 일반 파일이 아니면(링크 · gitlink) 2, 검사기가 없는 것은 스키마 `.json`이 하나라도 있을 때 2다(T067 r4 보정). 머지되면 다음 기준이 될 트리가 기준 꺼내기에서 2가 되는 모양이면 머지 전에 막는다(머지된 뒤에는 되돌리는 PR까지 2로 막힌다).
  - 부트스트랩 조건(T067 r2 보정): 기준에 검사기도 스키마(`.json`)도 없을 때만이다. 기준에 스키마가 있는데 검사기가 없으면 2 — 검사기를 지우는 PR이 머지되면 다음 PR이 제 검사기로 도는 경로를 막는다.
  - 검사기 출력 계약(T067 r2 보정): 검사기는 0 · 1로 끝날 때 stderr에 요약 줄 `check-compat: checked N · added M · violations K` 하나를 쓴다. 게이트는 이 줄이 정확히 하나가 아니거나, K가 앞 0 없는 9자리 이하 십진수가 아니거나, 종료 코드와 맞지 않거나(0인데 K ≠ 0 · 1인데 K = 0), stdout의 위반 줄(위반 하나 = 한 줄) 수가 K와 다르면 2로 끝난다(T067 r3 보정 — 스크립트가 이미 그렇게 판정한다) — 검사기 적재 실패나 진입점 가드 꺼짐을 통과나 위반으로 잘못 읽지 않게. 이 줄의 꼴은 바꾸지 않는다(기준 쪽 검사기의 출력을 변경 쪽 스크립트가 읽는다).
  - 한계: GitHub의 `pull_request`는 PR 브랜치의 워크플로 정의로 돈다. 같은 PR이 `.github/workflows/ci.yml`이나 `scripts/ci/events-compat.sh`를 바꾸면 그 PR에서는 바뀐 것이 돈다(게이트 스크립트는 체크아웃이 PR의 `.gitattributes`로 바꾼 바이트로 돈다 — 이것도 같은 한계다). 게이트 job이 PR 내용에서 읽는 것은 이 둘뿐이고(Node 버전은 ci.yml의 값 — T067 r4 보정), 스키마 · 검사기는 커밋 객체에서 읽는다(T067 r3 보정). 또 게이트 파일(`ci.yml` · `events-compat.sh` · `check-compat.mjs`)의 변경은 머지되면 그 뒤 모든 PR의 게이트가 된다 — 기준 쪽 검사기 규칙은 같은 PR 안의 약화만 막고, 검사기를 약하게 고친 PR 자체는 스키마를 바꾸지 않으면 통과한다(두 단계 경로). 검사기를 더 엄격하게 하거나 잘못 고친 변경도 머지되면 그것이 기준 쪽 검사기가 되어 기준 스키마에서 2(또는 거짓 위반 1)로 끝나고, 되돌리는 PR까지 이후 모든 PR이 막힌다(T067 r4 보정). 복구는 게이트 스크립트를 함께 고친 PR이 먼저다 — 그 PR에서는 그 PR의 스크립트가 돈다(코드 소유자 리뷰 · 뒤에 스크립트를 원래대로 돌리는 PR이 하나 더 필요). required check를 비켜 가는 운영자 머지는 같은 ruleset의 다른 required check까지 비켜 가므로 마지막 수단이다(T067 r5 보정). 머지 전에는 job `events-test`가 잡는다: 패키지 밖 검사기 사본으로 실제 스키마를 자기 자신 · 빈 기준과 비교(`schemas.test.mjs` sch-14 — 머지 뒤 게이트가 기준 쪽 사본을 돌리는 조건과 같다) · 요약 줄(sch-21) · CLI 경로의 Node 내장 모듈 자립(sch-9) · 게이트 Node 고정값 = `.node-version`(sch-23). 패키지 밖 사본은 `NODE_PATH` · `NODE_OPTIONS`를 지운 env로 돌고, 그 env에서 사본 위치가 ajv를 해석하지 못함을 sch-24가 먼저 확인한다 — pnpm의 vitest 실행 shim이 `NODE_PATH`에 `.pnpm/node_modules`(ajv가 호이스트된 곳)를 넣어, 그대로 물려주면 사본이 ajv를 찾아 게이트 조건(node_modules 없음)을 재현하지 못한다(T067 r6 보정 · 리뷰가 CI 명령으로 재현). 단 events-test가 그 시험을 실제로 돌릴 때만이다 — 시험 실행 경로(시험 파일 · `packages/events/package.json`의 `test` 스크립트 · vitest 설정 · 루트 `pnpm-workspace.yaml` · `package.json` · `pnpm-lock.yaml` · `.npmrc`(pnpm `node-options` 등) · `.pnpmfile.cjs` 등 events-test가 읽는 pnpm · vitest 설정과 훅 파일 — events-test는 PR 코드를 도는 job이라 이 목록은 닫힌 목록이 아니다)를 바꾸는 변경(앞선 PR 포함)은 이 방어를 끌 수 있다(T067 r5 · r6 · r7 보정). events-test 명령은 `pnpm --filter @jt/events --fail-if-no-match test`다 — 걸러 낸 프로젝트가 없으면 pnpm이 exit 0으로 끝나므로, 워크스페이스에서 `packages/events`를 빼는 변경이 빈 통과가 되지 않게 한다(T067 r6 보정). 그래서 이 파일들의 변경은 리뷰가 막는다(검사기 신뢰 모델의 한계 — 운영자 인계: `packages/events/` · `scripts/ci/` · `.github/workflows/` · 모든 깊이의 `.gitattributes` · 루트 `pnpm-workspace.yaml` · `package.json` · `pnpm-lock.yaml` · `.npmrc` · `.pnpmfile.cjs`(아직 없는 경로도 지정할 수 있다) · `.github/CODEOWNERS` 자신에 CODEOWNERS · 코드 소유자 리뷰 필수 · `events-compat` · `events-test`를 ruleset(main)의 required check로 지정 — 교착 방어가 events-test에 기댄다).
- **검사기가 다루는 키**(T067 보정): 구조 키 `type` · `properties` · `required` · `items` · `enum` · `const` · `additionalProperties`(스키마일 때 재귀 — `false`는 어느 위치든 2: 위 「허용」의 열린 스키마 규칙을 기준 쪽 검사기가 강제한다 · T067 r2 보정)를 비교하고, 값 제약 `format` · `pattern` · `minLength` · `maxLength` · `minimum` · `maximum` · `exclusiveMinimum` · `exclusiveMaximum` · `minItems` · `maxItems` · `uniqueItems`와 메타데이터(`$schema` · `$id` · `$comment` · `title` · `description` · `examples` · `default` · `deprecated` · `readOnly` · `writeOnly` · `x-*`)는 그대로 둔다. `x-*`는 스키마 객체의 키일 때만 메타데이터이고 이름이 소문자 kebab 꼴 `^x-[a-z0-9]+(-[a-z0-9]+)*$`이어야 한다 — 꼴 밖이면 2(T067 r3 보정 · ajv strict에서는 `x-*`를 값 검사 없는 키워드로 등록해야 컴파일되는데, 공백 · 점 · 비ASCII가 든 이름은 등록이 예외로 끝나 `validateEvent`가 판정 대신 예외를 던진다). `properties` 아래의 속성 이름과 `examples` · `default` · `enum` · `const`의 값 안 키는 스키마 키가 아니다. 이 밖의 키(`$ref` · `$defs` · `allOf` · `anyOf` · `oneOf` · `not` · `if`/`then`/`else` · `prefixItems` · `patternProperties` · `dependent*` · `unevaluated*` 등)는 쓰지 않는다 — 쓰면 검사기가 2로 끝난다(비교하지 못한 변경을 통과로 두지 않는다 · 쓰려면 검사기를 먼저 넓힌다).
- **값 제약**(T067 보정): `const` 값이 바뀌는 것은 enum 값 삭제와 같다(`enum-removed`). 제한이 없던 속성에 `enum` · `const`를 새로 두는 것도 `enum-removed`다 — 허용 값이 "모든 값"에서 몇 개로 준다(T067 r2 보정 · 없던 `type`을 더하는 것이 `type-changed`인 것과 같은 원칙). `format` · `pattern` · 길이 · 범위는 바꾸지 않는다 — 검사기가 보지 못하므로 리뷰가 막는다(강화는 생산자를, 완화는 그 값에 기댄 소비자를 깨뜨린다 · 바꾸려면 새 토픽 v2).
- **enum 값 추가의 배포 순서**(T067 보정): 그 토픽의 소비자가 새 스키마를 담은 빌드로 먼저 배포되고 생산자는 그다음에 새 값을 보낸다 — 소비자는 data를 스키마로 검증하므로 옛 스키마의 enum은 새 값을 거부해 DLQ로 보낸다("알 수 없는 enum 값 무시"는 검증을 통과한 뒤의 업무 처리 규칙이다). 소비자 도우미가 enum 위반만 따로 다룰지는 SP-2가 정한다.

## 발행 API (`django_common.outbox.publish`)

```python
def publish(topic: str, subject: str, data: dict, *, tenant_id: UUID | str | None = None) -> OutboxEvent: ...
```

- `tenant_id`는 **키워드 전용 선택 인자**다. 생략하면 요청 트랜잭션의 테넌트 컨텍스트(`app.tenant_id`)에서 읽는다. 컨텍스트가 있는 요청 경로(A 등급 도메인 쓰기)는 인자를 넘기지 않고, 컨텍스트가 없는 경로(웹훅·관리자 revoke·기동 시 작업 — 전부 등급 B 테이블 위에서 돈다)는 **명시적으로 넘긴다**.
- **컨텍스트도 없고 인자도 없으면 `OutboxUsageError`** 를 던진다(`tenantid` 없는 봉투가 Kafka로 나가는 것을 막는다). `transaction.atomic()` 밖에서 호출해도 같은 예외다.
- 확정된 `tenant_id`가 봉투의 `tenantid`와 outbox 행의 `partition_key`가 된다.
- `tenant_id`로 넘긴 값(UUID 또는 str)이 **UUID로 파싱되지 않으면 `OutboxUsageError`**(slug 금지 — 봉투 스키마 검증보다 앞선 관문 · 2026-11-02 T061 리뷰 B-1). 테넌트 컨텍스트와 `tenant_id` 인자가 **둘 다 있고 서로 다르면 `OutboxUsageError`**(심층 방어 — A 등급 트랜잭션 안에서 다른 테넌트로 레이블된 봉투가 커밋되는 코드 실수를 라이브러리가 막는다), 같으면 허용(T061 리뷰 B-2).
- 웹훅·관리자 revoke가 넘길 `tenant_id`는 `TenantMembership`에서 토큰·본문의 `sub`로 조회한 값이다(없으면 400 — contracts/identity-admin-api.md).

## outbox 릴레이 (django-common)

- 실행: pod당 `manage.py outbox_relay` 프로세스 1개(Deployment의 `relay` 컨테이너, web과 같은 pod), 폴링 500 ms, 배치 100. **app role**로 실행하며 `outbox` 테이블은 등급 B(pod 전역, RLS 미적용)라 모든 테넌트의 행을 읽는다(T061: 테넌트 A·B 행이 모두 릴레이되고 각 `tenantid`·파티션 키가 맞음).
- **선택 조건**: `WHERE dead_at IS NULL ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 100`. dead 행은 다시 집지 않는다(재발행 폭주 방지) — 재처리는 `dead_at`을 비우는 수동 command로만.
- 트랜잭션 규칙: outbox INSERT는 도메인 쓰기와 같은 `transaction.atomic()` 안에서만. 라이브러리는 autocommit 상태의 INSERT를 `OutboxUsageError`로 막는다.
- 프로듀서: confluent-kafka idempotent producer, SASL_SSL SCRAM-SHA-512, `delivery.timeout.ms` 30000.
- 실패: 프로듀서 오류 시 `attempts += 1`, `last_error` 기록, 지수 백오프(최대 5분). **`attempts ≥ max_attempts(10)`이면 원본 봉투를 그 env의 DLQ(prod `<pod>.dlq` · dev `dev.<pod>.dlq`)로 발행(+ `error` 헤더)하고 `dead_at`을 기록**한다(행 유지, 재처리는 수동 command).
- **dead 행 purge**: 일 1회 `dead_at + 30 d < now()`인 행을 삭제한다(Celery beat). `outbox` 테이블이 무한히 자라지 않게 하는 유일한 경로이며, 30일은 수동 재처리 여유다.
- 관측(relay 컨테이너 `prometheus_client` 9464, `k8s.grafana.com/scrape: "true"`): `outbox_pending`(gauge, `dead_at IS NULL`만 셈), `outbox_oldest_pending_seconds`(가장 오래된 pending의 나이, 알림 `OutboxOldestPending` > 60 s), `outbox_dead_total`(counter).

## 소비자 규칙

- consumer group prod `<pod>-<purpose>` · dev `dev-<pod>-<purpose>`(예: `notification-note-published` · `dev-notification-note-published` — KafkaUser 그룹 ACL 접두가 prod `<pod>-` · dev `dev-<pod>-`이다 · data-model §6 · 2026-10-16 T056 정정). 오프셋 커밋은 처리 트랜잭션 커밋 뒤.
- 처리 실패 3회 → DLQ로 이동(원본 봉투 + `error` 헤더). DLQ 재처리는 수동 command.
- 스키마 검증: 소비자는 `packages/events`의 스키마로 `data`를 검증하고, 실패는 DLQ.
- 컨슈머 그룹 lag 지표는 SP-2(`kafkaExporter`); SP-1 알림은 outbox pending·oldest age + 브로커 under-replicated만.
