// T067 (US6 · test-first) — packages/events 스키마 7개의 내용과 검사기에 T067이 더한 규칙의 테스트(vitest).
//
// 과제(tasks.md T067): schemas/_envelope.json + 토픽 스키마 6(contracts/events.md 필드 · tenantid = uuid) + scripts/check-compat.mjs.
//   T064(check-compat.test.mjs)는 모듈 API · 비교 규칙 · 파일 모양을 고정한다. 이 파일은 실제 스키마의 내용을 계약 표에 묶고
//   (필수 · 선택 · 형식 — 필수 집합은 main에 들어간 뒤로 추가도 제거도 할 수 없다), 검사기에 T067이 더한 규칙을 고정한다.
// 정본: specs/003-platform-foundation/contracts/events.md §봉투(필드 형식) · 「필드 형식 · 필수(T067 확정 2026-11-03)」
//   · §호환성 규칙(CI 기준과 검사기 · 검사기가 다루는 키 · 값 제약) · .claude/rules/events.md §Compatibility rules
//   · build-notes 「T067」 D2(스키마 내용) · D3(검사기 규칙) · D4(이 파일).
// 짝 구현: T067 — schemas/*.json 7 · scripts/check-compat.mjs.
// 빨강(T067 구현 전): 이 파일을 수집할 때 "../scripts/check-compat.mjs" 로드가 실패한다(구현 없음). 모듈만 생기고 스키마 파일이
//   없으면 실제 schemas/를 읽는 단언이 전부 실패한다.
// r2(리뷰 r1 반영 · 계약 r2 보정): 패턴 끝 $(?!\n) · subject/target 제어 문자 클래스 · url https pattern(sch-3 · 6 · 7 · 8),
//   additionalProperties: false 거부(sch-18) · enum/const 신설 = enum-removed(sch-19) · x-* 키워드 등록(sch-20)
//   · CLI 요약 줄 고정 계약(sch-21) · 일반 파일이 아닌 .json(sch-22).
// r3(리뷰 r2 A2-2 · 계약 r3 보정 「검사기가 다루는 키」): x-* 스키마 키의 이름 꼴 ^x-[a-z0-9]+(-[a-z0-9]+)*$ — 꼴 밖이면 diffSchema ·
//   CLI 2, validateEvent는 스키마 위치(스키마 객체의 키)만 꼴에 맞는 이름을 등록한다 — 속성 이름과 examples · default · enum · const
//   값 안의 키는 스키마 키가 아니다(sch-20).
// r4(리뷰 r3 A3-1): 등록 위치 — items 스키마 · 스키마인 additionalProperties 안의 x-* 키도 컴파일 전에 등록한다(sch-20 ⑥).
// r5(리뷰 r4 B4-1 · B4-2 · 계약 r5 보정 「한계」 · 「Node 설치는 체크아웃 전」): sch-14 CLI를 패키지 밖 사본으로도 실제 schemas/에 돌린다
//   (자기 비교 · 빈 기준 — 머지 뒤 게이트가 기준 쪽 사본을 돌리는 조건) · sch-23 게이트 job(events-compat)의 Node 고정값 = 저장소
//   .node-version(ci.yml 원문을 읽는다).
// r6(리뷰 r5 R5-1 · R5-3 · 계약 r6 보정 「한계」): 패키지 밖 사본(sch-9 · sch-14 · sch-21)은 NODE_PATH · NODE_OPTIONS를 지운 env로 돈다
//   (outOfPackageEnv — CI 명령 pnpm --filter @jt/events --fail-if-no-match test는 pnpm의 vitest 실행 shim을 거치고, 그 shim이 NODE_PATH에
//   .pnpm/node_modules(ajv가 호이스트된 곳)를 넣는다) · sch-24 그 env에서 사본 위치가 ajv를 해석하지 못한다는 전제 단언 · sch-23 핀은
//   setup-node 스텝의 with: 아래 줄만 센다.
// r7(리뷰 r6 R6-1 · 지시문 F36): sch-23은 r6 결속에 더해 job events-compat 블록 전체를 본다 — setup-node를 가리키는 줄은 꼴과
//   상관없이 대시 꼴 스텝 머리 하나 · node-version 키 줄은 그 with: 아래 핀 하나 · node-version-file 키 줄 0. with:는 스텝 키 깊이에서만
//   받고(env: 아래 with:는 입력이 아니다), 줄은 YAML 줄바꿈(홀로 선 CR 포함)으로 나누며, 주석 줄은 블록 경계가 아니다. 키 줄 수 대조
//   (pinKeyLines)는 그 블록 안에서만 센다.
// r8(리뷰 r7 R7-1 · R7-2 · 지시문 F39 · 계약 r8): sch-23은 줄 단위 드리프트 검사다 — 실수로 갈라진 값 · 옮겨진 핀 · 늘어난 setup-node
//   스텝을 잡는다. 위 「꼴과 상관없이」는 앞의 "- " 유무 · 따옴표 · 대소문자 · 흐름 매핑 꼴을 뜻하고, YAML 이어짐 줄 · 이스케이프 · 별칭 ·
//   가짜 job 블록처럼 ci.yml을 일부러 꼬아 쓰는 편집은 범위 밖이다(코드 소유자 리뷰가 막는다). ci.yml 원문에 NEL · LS · PS가 하나라도
//   있으면 불일치다(파서마다 줄바꿈 여부가 달라 블록 경계가 갈린다 — 그 글자에서 나눈 조각이 블록을 앞당겨 끝낼 수 있다).
//
// id: sch-1 파일 7 · 필수 · 선택 = 계약 표 / sch-2 모든 속성에 type / sch-3 속성 정의 = 계약 표 · 설계 D2(제약 키 — 메타데이터 제외)
//   / sch-4 파일 머리 · 정규 서식 / sch-5 토픽별 표본 · 필수 누락 · 선택 생략 / sch-6 형식 · 값의 음성과 경계
//   / sch-7 봉투 형식 · v2 이름 · 열린 스키마 / sch-8 패턴 이식성(ajv u 플래그 ↔ Python re — 끝 고정 · 맨 . · 문자 클래스)
//   / sch-9 검사기 CLI 자립성 / sch-10 허용 키 목록 / sch-11 const = 값 하나짜리 enum / sch-12 JSON 포인터 이스케이프
//   / sch-13 경로 탈출 심층 방어 / sch-14 실제 스키마 ↔ 검사기 / sch-15 ajv strict 출력 0 / sch-16 객체가 아닌 봉투 · 문자열이 아닌 type
//   / sch-17 제어 문자가 든 이름도 위반 하나 = 한 줄(CI 로그의 워크플로 명령 주입 방지)
//   / sch-18 additionalProperties: false는 어느 위치 · 어느 쪽 · 어느 파일이든 거부(기준 쪽 검사기가 열린 스키마 규칙을 강제)
//   / sch-19 제한이 없던 속성의 enum · const 신설 = enum-removed / sch-20 x-* 메타데이터 키와 ajv strict(이름 꼴 · 스키마 위치)
//   / sch-21 CLI 요약 줄(events-compat.sh가 읽는 고정 계약) / sch-22 일반 파일이 아닌 .json은 예외 · CLI 2
//   / sch-23 게이트 job(events-compat)의 Node 고정값 = 저장소 .node-version(setup-node 스텝의 with:에 있는 핀 — job 블록 전체에서
//     setup-node를 가리키는 줄 · node-version 키 줄은 그 스텝 · 그 핀 하나뿐 · ci.yml 원문에 NEL · LS · PS 없음 — 줄 단위 드리프트 검사)
//   / sch-24 패키지 밖 사본 env의 전제(그 env · 그 자리에서 ajv · ajv-formats가 해석되지 않는다).
// 제어 문자 · 줄바꿈 값은 String.fromCodePoint로 만든다(소스에 이스케이프를 두지 않는다).
// 테스트는 네트워크에 닿지 않는다(임시 디렉터리 · 자식 node 프로세스 · 저장소 파일 읽기만 — sch-23은 저장소 루트의 ci.yml ·
//   .node-version을 읽는다).

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { afterEach, describe, expect, it, vi } from "vitest";

import { compareDirectories, diffSchema, validateEvent } from "../scripts/check-compat.mjs";

// 테스트 파일 기준 상대 경로(패키지 루트 = tests/의 부모)
const SCRIPT = fileURLToPath(new URL("../scripts/check-compat.mjs", import.meta.url));
const SCHEMAS_DIR = fileURLToPath(new URL("../schemas/", import.meta.url));
// sch-23: 저장소 루트(이 파일 = packages/events/tests/ — 세 단계 위)의 워크플로와 .node-version
const CI_WORKFLOW = fileURLToPath(new URL("../../../.github/workflows/ci.yml", import.meta.url));
const NODE_VERSION_FILE = fileURLToPath(new URL("../../../.node-version", import.meta.url));

const DRAFT_2020_12 = "https://json-schema.org/draft/2020-12/schema";
const KINDS = [
  "field-removed",
  "type-changed",
  "required-added",
  "required-removed",
  "enum-removed",
  "schema-removed",
];
// 검사기가 무시하는 메타데이터 키(계약 §호환성 규칙 「검사기가 다루는 키」) — x- 접두 키도 메타데이터다
const METADATA_KEYS = new Set([
  "$schema",
  "$id",
  "$comment",
  "title",
  "description",
  "examples",
  "default",
  "deprecated",
  "readOnly",
  "writeOnly",
]);

// 계약 「필드 형식 · 필수(T067 확정)」 표 — 파일마다 필수 · 선택 필드. 봉투는 §봉투 · data-model §5의 필수 9(선택 없음).
const FIELDS = {
  "_envelope.json": {
    required: ["specversion", "id", "source", "type", "time", "subject", "tenantid", "datacontenttype", "data"],
    optional: [],
  },
  "identity-admin.session.revoked.json": { required: ["sub", "nbf", "reason"], optional: ["sid"] },
  "identity-admin.user.registered.json": {
    required: ["sub", "tenant_id", "role", "registered_at"],
    optional: ["email_hash"],
  },
  "identity-admin.tenant.created.json": { required: ["tenant_id", "slug", "display_name"], optional: [] },
  "portfolio-core.note.published.json": {
    required: ["slug", "lang", "title", "tags", "published_at"],
    optional: ["change"],
  },
  "engagement.comment.created.json": {
    required: ["comment_id", "target", "author_sub", "created_at", "body_excerpt"],
    optional: [],
  },
  "media.object.ready.json": { required: ["media_id", "owner_sub", "kind", "variants", "bytes"], optional: [] },
};
const FILES = Object.keys(FIELDS);
const TOPICS = FILES.filter((name) => !name.startsWith("_")).map((name) => name.slice(0, -".json".length));

// 계약 「필드 형식 · 필수」 표 · 설계 D2 표의 속성 정의 — 제약 키만(메타데이터는 sch-3이 걷어 내고 비교한다).
// pattern은 계약 문자열 그대로다(String.raw — 역슬래시가 글자 그대로 남는다). 끝 고정은 $(?!\n)이다(계약 §봉투 「패턴 이식성」 ③ —
// Python re의 $는 끝 줄바꿈 바로 앞에서도 맞는다).
// 공통 꼴: UUID(소문자 — format만으로는 대문자 · urn: 접두가 통과한다) · 시각(RFC 3339) · 비지 않은 문자열 · <종류>:<id>
const END = String.raw`$(?!\n)`;
const UUID = {
  type: "string",
  format: "uuid",
  pattern: String.raw`^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$(?!\n)`,
};
const DATE_TIME = { type: "string", format: "date-time" };
const NON_EMPTY = { type: "string", minLength: 1 };
// <종류>:<id> — id 부분은 제어 문자(C0 · DEL · C1)가 없는 비지 않은 문자열(봉투 subject · comment.created target 공통)
const KIND_REF = { type: "string", pattern: String.raw`^[a-z][a-z0-9-]*:[^\x00-\x1f\x7f-\x9f]+$(?!\n)` };
// media.object.ready variants[].url — scheme은 https만 · RFC 3986 글자만(Python 소비자는 uri 형식을 검사하지 않는다)
const HTTPS_URL = String.raw`^https://[A-Za-z0-9._~:/?#@!$&'()*+,;=%\[\]-]+$(?!\n)`;
const CONSTRAINTS = {
  "_envelope.json": {
    specversion: { type: "string", const: "1.0" },
    id: { type: "string", pattern: String.raw`^[0-7][0-9A-HJKMNP-TV-Z]{25}$(?!\n)` },
    source: { type: "string", pattern: String.raw`^[a-z][a-z0-9]*(-[a-z0-9]+)*$(?!\n)` },
    type: { type: "string", pattern: String.raw`^[a-z][a-z0-9]*(-[a-z0-9]+)*(\.[a-z][a-z0-9]*(-[a-z0-9]+)*){2,}$(?!\n)` },
    time: DATE_TIME,
    subject: KIND_REF,
    tenantid: UUID,
    datacontenttype: { type: "string", const: "application/json" },
    data: { type: "object" },
  },
  "identity-admin.session.revoked.json": {
    sub: NON_EMPTY,
    sid: { type: ["string", "null"], minLength: 1 },
    nbf: { type: "integer", minimum: 0 },
    reason: { type: "string", enum: ["logout", "logout_all", "admin", "authentik_webhook", "tenant_suspended"] },
  },
  "identity-admin.user.registered.json": {
    sub: NON_EMPTY,
    email_hash: { type: "string", pattern: String.raw`^[0-9a-f]{64}$(?!\n)` },
    tenant_id: UUID,
    role: { type: "string", enum: ["owner", "member"] },
    registered_at: DATE_TIME,
  },
  "identity-admin.tenant.created.json": {
    tenant_id: UUID,
    slug: { type: "string", pattern: String.raw`^[a-z0-9][a-z0-9-]{1,30}$(?!\n)` },
    display_name: { type: "string", minLength: 1, maxLength: 80 },
  },
  "portfolio-core.note.published.json": {
    slug: { type: "string", pattern: String.raw`^[a-z0-9]+(-[a-z0-9]+)*$(?!\n)` },
    lang: { type: "string", enum: ["ko", "en", "ja"] },
    title: NON_EMPTY,
    tags: { type: "array", items: NON_EMPTY },
    published_at: DATE_TIME,
    change: { type: "string", pattern: String.raw`^[0-9]{3}-[a-z0-9-]+$(?!\n)` },
  },
  "engagement.comment.created.json": {
    comment_id: NON_EMPTY,
    target: KIND_REF,
    author_sub: NON_EMPTY,
    created_at: DATE_TIME,
    body_excerpt: { type: "string", maxLength: 200 },
  },
  "media.object.ready.json": {
    media_id: NON_EMPTY,
    owner_sub: NON_EMPTY,
    kind: { type: "string", enum: ["image", "file"] },
    variants: {
      type: "array",
      items: {
        type: "object",
        properties: { name: NON_EMPTY, url: { type: "string", format: "uri", pattern: HTTPS_URL } },
        required: ["name", "url"],
      },
    },
    bytes: { type: "integer", minimum: 0 },
  },
};

const TENANT = "00000000-0000-4000-8000-00000000000a";
const EMAIL_HASH = createHash("sha256").update("user@example.com").digest("hex");

/** 코드 포인트 하나짜리 문자열 — 제어 문자 · 줄바꿈 값을 소스 이스케이프 없이 만든다 */
const cp = (code) => String.fromCodePoint(code);
const LF = cp(0x0a);
const BACKSLASH = cp(0x5c);
// 검사기 CLI 요약 줄(고정 계약 — scripts/ci/events-compat.sh가 이 꼴로 읽는다 · contracts/events.md 「검사기 출력 계약」)
const SUMMARY_RE = /^check-compat: checked [0-9]+ · added [0-9]+ · violations ([0-9]+)$/;
// x-* 스키마 키의 이름 꼴(계약 「검사기가 다루는 키」 · T067 r3) — 검사기의 사유 문구가 이 글자를 그대로 담는다
const X_KEY_FORM = "^x-[a-z0-9]+(-[a-z0-9]+)*$";

// 계약 §봉투 예시 모양(T064 · T061과 같은 봉투) — 토픽 표본은 type · subject · data만 바꾼다
const SAMPLE_ENVELOPE = {
  specversion: "1.0",
  id: "01J8QK3Q9S8ZQ4V7H2M1X0N5AB",
  source: "identity-admin",
  type: "identity-admin.session.revoked",
  time: "2026-09-01T03:21:07.123Z",
  subject: "user:9f2c-test",
  tenantid: TENANT,
  datacontenttype: "application/json",
  data: { sub: "9f2c-test", sid: null, nbf: 1756696867, reason: "logout_all" },
};

// 토픽별 계약 모양의 표본 — subject는 계약 §SP-1 표의 꼴(user:<sub> · tenant:<id> · note:<slug> · comment:<id> · media:<id>)
const SAMPLES = {
  "identity-admin.session.revoked": {
    subject: "user:9f2c-test",
    data: { sub: "9f2c-test", sid: null, nbf: 1756696867, reason: "logout_all" },
  },
  "identity-admin.user.registered": {
    subject: "user:9f2c-test",
    data: {
      sub: "9f2c-test",
      email_hash: EMAIL_HASH,
      tenant_id: TENANT,
      role: "owner",
      registered_at: "2026-09-01T03:21:07.123Z",
    },
  },
  "identity-admin.tenant.created": {
    subject: `tenant:${TENANT}`,
    data: { tenant_id: TENANT, slug: "joshuatech", display_name: "JoshuaTech" },
  },
  "portfolio-core.note.published": {
    subject: "note:events-compat",
    data: {
      slug: "events-compat",
      lang: "ko",
      title: "이벤트 스키마 호환성 검사",
      tags: ["events", "json-schema"],
      published_at: "2026-11-03T09:00:00Z",
      change: "003-platform-foundation",
    },
  },
  "engagement.comment.created": {
    subject: "comment:c-01",
    data: {
      comment_id: "c-01",
      target: "note:events-compat",
      author_sub: "4b1d-test",
      created_at: "2026-11-03T18:30:00+09:00",
      body_excerpt: "기준 쪽 검사기 설명이 좋다.",
    },
  },
  "media.object.ready": {
    subject: "media:m-01",
    data: {
      media_id: "m-01",
      owner_sub: "9f2c-test",
      kind: "image",
      variants: [
        { name: "thumb", url: "https://media.joshuatech.dev/m-01/thumb.webp" },
        { name: "original", url: "https://media.joshuatech.dev/m-01/original.png" },
      ],
      bytes: 48213,
    },
  },
};

// 검사기 규칙 시험용 작은 data 스키마(열린 스키마 — T064 BASE와 같은 규약)
const SMALL = {
  $schema: DRAFT_2020_12,
  $id: "https://joshuatech.dev/events/sample.small.event/v1",
  "x-version": "1.0.0",
  title: "sample.small.event",
  type: "object",
  properties: {
    x: { type: "string" },
    n: { type: "integer" },
  },
  required: ["n"],
};

const tempDirs = [];

afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

/** 테스트가 끝나면 afterEach가 지우는 임시 디렉터리 */
function makeTempDir() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "jt-events-sch-"));
  tempDirs.push(dir);
  return dir;
}

/** parent 아래에 name 디렉터리를 만든다 */
function makeSubDir(parent, name) {
  const dir = path.join(parent, name);
  fs.mkdirSync(dir, { recursive: true });
  return dir;
}

/** dir에 { 파일 이름: 내용 }을 쓴다 — 객체는 JSON(2칸 · 끝 줄바꿈), 문자열은 그대로 */
function writeSchemas(dir, files) {
  for (const [name, content] of Object.entries(files)) {
    const text = typeof content === "string" ? content : `${JSON.stringify(content, null, 2)}\n`;
    fs.writeFileSync(path.join(dir, name), text, "utf8");
  }
  return dir;
}

/** 실제 schemas/의 파일 원문 */
function readRealText(name) {
  return fs.readFileSync(path.join(SCHEMAS_DIR, name), "utf8");
}

/** 실제 schemas/의 파일을 읽어 파싱한다(파싱 실패는 예외로 드러난다) */
function readRealSchema(name) {
  return JSON.parse(readRealText(name));
}

/** 실제 schemas/의 7개 파일을 dir에 복사한다(새 디렉터리 = 새 ajv 인스턴스 — 컴파일이 다시 일어난다) */
function copyRealSchemas(dir) {
  for (const name of FILES) fs.copyFileSync(path.join(SCHEMAS_DIR, name), path.join(dir, name));
  return dir;
}

/** 토픽 표본 봉투(SAMPLE_ENVELOPE에서 type · subject · data만 바꾼다) */
function envelopeFor(topic, data = SAMPLES[topic].data) {
  return {
    ...structuredClone(SAMPLE_ENVELOPE),
    type: topic,
    subject: SAMPLES[topic].subject,
    data: structuredClone(data),
  };
}

/** validateEvent 결과 모양(T064 D2): { ok: boolean, errors: { path, message }[] } · ok ⇔ errors 없음 */
function validate(envelope, options) {
  const result = validateEvent(envelope, options);
  expect(typeof result.ok).toBe("boolean");
  expect(Array.isArray(result.errors)).toBe(true);
  for (const error of result.errors) {
    expect(error.path).toMatch(/^#(\/|$)/);
    expect(typeof error.message).toBe("string");
    expect(error.message.trim()).not.toBe("");
    expect(error.message).not.toMatch(/[\r\n]/);
  }
  expect(result.ok).toBe(result.errors.length === 0);
  return result;
}

/** errors의 경로 집합 */
function errorPaths(result) {
  return [...new Set(result.errors.map((error) => error.path))].sort();
}

/** errors에 topic 스키마 부재(schema-missing + 토픽 이름)가 있는가 */
function schemaMissingFor(errors, topic) {
  return errors.some((error) => error.message.includes("schema-missing") && error.message.includes(topic));
}

/** fn이 UnsupportedSchemaError(이름)를 던지고 메시지가 key를 담는가 */
function expectUnsupported(fn, key) {
  let thrown;
  try {
    fn();
  } catch (error) {
    thrown = error;
  }
  expect(thrown, `${key}: 예외가 나지 않았다`).toBeInstanceOf(Error);
  expect(thrown.name, thrown.message).toBe("UnsupportedSchemaError");
  expect(thrown.message).toContain(key);
}

/** 스키마 노드에서 메타데이터(METADATA_KEYS · x-*)를 걷어 낸 제약 — properties · items · additionalProperties(스키마) 재귀 */
function constraintsOf(node) {
  const out = {};
  for (const [key, value] of Object.entries(node)) {
    if (METADATA_KEYS.has(key) || key.startsWith("x-")) continue;
    if (key === "properties") {
      out.properties = Object.fromEntries(Object.entries(value).map(([name, child]) => [name, constraintsOf(child)]));
    } else if ((key === "items" || key === "additionalProperties") && value !== null && typeof value === "object") {
      out[key] = constraintsOf(value);
    } else {
      out[key] = value;
    }
  }
  return out;
}

/** 스키마 트리의 하위 스키마(속성 · items · additionalProperties)를 [포인터, 스키마]로 모은다 */
function subschemas(node, pointer = "#", found = []) {
  for (const [name, child] of Object.entries(node.properties ?? {})) {
    const childPointer = `${pointer}/properties/${name}`;
    found.push([childPointer, child]);
    subschemas(child, childPointer, found);
  }
  for (const key of ["items", "additionalProperties"]) {
    const child = node[key];
    if (child !== null && typeof child === "object" && !Array.isArray(child)) {
      found.push([`${pointer}/${key}`, child]);
      subschemas(child, `${pointer}/${key}`, found);
    }
  }
  return found;
}

/** 실제 CLI를 node 프로세스로 돌린다(셸 없음 · 시간 제한). env를 주면 그 env로 돌고(패키지 밖 사본 — runCopy), 없으면 부모 env를 물려받는다 */
function runCli(script, args, env) {
  return spawnSync(process.execPath, [script, ...args], { encoding: "utf8", timeout: 30_000, ...(env === undefined ? {} : { env }) });
}

// r6(리뷰 r5 R5-1 · 계약 r6 보정 「한계」): 패키지 밖 사본은 머지 뒤 게이트와 같은 조건(node_modules 없음)에서 돌아야 판별력이 있다.
// 게이트 job은 setup-node + bash → node <사본>이고 NODE_PATH를 두지 않는다. 반면 이 파일을 도는 CI 명령(pnpm --filter @jt/events
// --fail-if-no-match test)은 pnpm의 vitest 실행 shim(node_modules/.bin/vitest)을 거치고, 그 shim이 NODE_PATH에 <루트>/node_modules/.pnpm/
// node_modules(ajv · ajv-formats가 호이스트된 곳)를 넣는다 — 그대로 물려주면 사본이 ajv를 찾아, CLI 경로에서 ajv를 부르는 변경이 이 시험들을
// 통과하고 머지 뒤 게이트에서 MODULE_NOT_FOUND → 요약 줄 0 → 2(되돌리는 PR까지 막히는 교착)가 된다. NODE_OPTIONS(--require · --import ·
// --conditions 등)도 같은 까닭으로 지운다. Windows의 env 키는 대소문자를 가리지 않으므로 키 대소문자를 무시하고 지운다. 이 env와 사본 자리가
// 그 조건을 만든다는 것은 sch-24가 먼저 단언한다.
const STRIPPED_ENV_KEYS = new Set(["NODE_PATH", "NODE_OPTIONS"]);

/** 패키지 밖 사본 실행 env — process.env에서 NODE_PATH · NODE_OPTIONS를 키 대소문자를 무시하고 지운 사본 */
function outOfPackageEnv() {
  return Object.fromEntries(Object.entries(process.env).filter(([key]) => !STRIPPED_ENV_KEYS.has(key.toUpperCase())));
}

/** 검사기를 dir/check-compat.mjs로 복사한다(패키지 밖 — 머지 뒤 게이트가 기준 쪽 검사기 blob을 꺼내 두는 자리와 같은 조건) */
function copyChecker(dir) {
  const copy = path.join(dir, "check-compat.mjs");
  fs.copyFileSync(SCRIPT, copy);
  return copy;
}

/** 패키지 밖 사본을 게이트와 같은 env(outOfPackageEnv)로 돌린다 */
function runCopy(copy, args) {
  return runCli(copy, args, outOfPackageEnv());
}

/**
 * sch-24 탐침: from 파일 자리에서 specifier를 Node의 require 해석 규칙으로 찾는다(require('node:module').createRequire(from).resolve) —
 * 해석되면 exit 0, 못 찾으면 MODULE_NOT_FOUND 예외로 0이 아닌 코드. specifier는 코드 글자에 넣지 않고 인자로 넘긴다.
 */
function resolveProbe(from, specifier, env) {
  return spawnSync(
    process.execPath,
    ["-e", "require('node:module').createRequire(process.argv[1]).resolve(process.argv[2])", from, specifier],
    { encoding: "utf8", timeout: 30_000, env },
  );
}

// r7(리뷰 r6 R6-1): ci.yml을 YAML 파서 없이 줄 단위로 읽으므로 줄을 YAML과 같은 자리에서 나눈다 — YAML은 홀로 선 CR도 줄바꿈으로
// 읽는다(LF로만 나누면 CR 뒤에 숨긴 키 · 스텝을 보지 못한다). YAML 1.1 계열 파서(libyaml 계열)는 NEL · LS · PS도 줄바꿈으로 읽으므로
// 그 글자로도 나눈다. 글자는 String.fromCodePoint로 만든다(소스에 이스케이프를 두지 않는다).
// r8(리뷰 r7 R7-1 · 지시문 F39): 나누는 것이 늘 더 엄격한 쪽은 아니다 — 나뉜 조각이 2칸 이하 키 줄이 되면(주석 안 LS 뒤의 「x: y」 등)
// 블록 경계가 앞당겨져 그 뒤 스텝이 보이지 않는다(YAML 1.2는 그 글자를 줄바꿈으로 읽지 않아 스텝이 그대로 job 안에 있다 — 파서마다 갈린다).
// 그래서 gateNodePin은 원문에 NEL · LS · PS가 하나라도 있으면 불일치로 본다(아래 가드). 이 검사는 줄 단위 드리프트 검사다(계약 r8 —
// 실수로 갈라진 값 · 옮겨진 핀 · 늘어난 setup-node 스텝을 잡고, ci.yml을 일부러 꼬아 쓰는 편집은 범위 밖이라 코드 소유자 리뷰가 막는다).
const YAML_NON_ASCII_BREAKS = String.fromCodePoint(0x85, 0x2028, 0x2029);
const YAML_LINE_BREAK = new RegExp(String.raw`\r\n|[\r\n` + YAML_NON_ASCII_BREAKS + "]");

/** YAML 줄바꿈(CRLF · LF · 홀로 선 CR · NEL · LS · PS)으로 나눈 줄 배열 */
function yamlLines(text) {
  return text.split(YAML_LINE_BREAK);
}

/** 줄의 들여쓰기 글자 수 */
function indentOf(line) {
  return line.length - line.trimStart().length;
}

/** 키 · 값이 있는 줄(빈 줄 · 주석 줄이 아니다) */
function isKeyLine(line) {
  return line.trim() !== "" && !line.trimStart().startsWith("#");
}

/**
 * job events-compat 블록의 줄 범위 { from, to }(to는 빼고) — jobs: 아래 2칸 들여쓴 "events-compat:" 줄 다음부터, 주석이 아니면서 2칸
 * 이하로 들여쓴 다음 줄(다음 job 키 · 최상위 키) 앞까지. 블록이 없으면 null.
 * r7(리뷰 r6 R6-1): 주석 줄은 경계가 아니다 — YAML에서 주석은 매핑을 끝내지 않는다(r6까지는 0 · 2칸 주석 한 줄이 블록을 끝내 그 뒤
 * 스텝을 보지 못했다). 하네스 Get-JobBlock은 그 주석에서 끝나지만, 그러면 뒤 스텝이 빠져 정확한 스텝 목록 단언(st-3)이 실패한다(닫힌 쪽).
 */
function eventsCompatRange(lines) {
  const jobsAt = lines.findIndex((line) => /^jobs:\s*$/.test(line));
  const head = jobsAt < 0 ? -1 : lines.findIndex((line, index) => index > jobsAt && /^ {2}events-compat:\s*$/.test(line));
  if (head < 0) return null;
  let end = head + 1;
  while (end < lines.length && !(isKeyLine(lines[end]) && /^ {0,2}\S/.test(lines[end]))) end += 1;
  return { from: head + 1, to: end };
}

// sch-23이 세는 줄(주석 줄은 세지 않는다 — 주석 안의 글자는 키가 아니다)
// - 대시 꼴 setup-node 스텝 머리(r6): 무리 1의 길이 = 스텝 키 깊이(대시 줄에서 uses가 시작하는 열)
const SETUP_NODE_HEAD = /^(\s*-\s+)uses:\s*actions\/setup-node@/;
// - r7 (b): setup-node를 가리키는 줄 — 꼴 무관(앞의 "- " 유무 · 키 · 값의 따옴표 · 대소문자 · 흐름 매핑 · 접힌 값의 다음 줄 · 하위 경로)
const SETUP_NODE_REF = /actions\/setup-node[/@]/i;
// - r6 핀: setup-node with: 바로 아래 키 줄(대소문자 · 따옴표 없는 정확한 꼴 — 키와 ":" 사이는 YAML 공백(스페이스 · 탭)만)
const PIN_KEY = /^\s*node-version[ \t]*:/;
const PIN_FILE_KEY = /^\s*node-version-file[ \t]*:/;
// - r7 (a): node-version · node-version-file 키 줄 — 꼴 무관(따옴표 키 · 흐름 매핑 · 대소문자 · INPUT_NODE-VERSION 같은 env 이름 · "? 키"
//   명시 키). 앞 글자가 영숫자 · "." · "-"가 아니어야 하고(파일 이름 .node-version · 다른 이름의 일부와 구분) 뒤는 따옴표 · 공백 다음
//   ":" · "#" · 줄 끝이다(node-version-file은 node-version 키가 아니다).
const NODE_VERSION_KEY = /(?:^|[^A-Za-z0-9.-])node-version["']?[ \t]*(?::|#|$)/i;
const NODE_VERSION_FILE_KEY = /(?:^|[^A-Za-z0-9.-])node-version-file["']?[ \t]*(?::|#|$)/i;

/**
 * sch-23: ci.yml 원문에서 job events-compat(게이트)의 Node 고정값을 꺼내 nodeVersion(.node-version 내용)과 대조한다.
 * 줄은 YAML 줄바꿈으로 나누고(yamlLines) 블록은 eventsCompatRange다(주석 줄은 경계가 아니다). r6(리뷰 r5 R5-3): 핀은 그 블록의
 * "- uses: actions/setup-node@" 스텝(정확히 하나 — 같은 들여쓰기의 다음 "- " 줄이나 더 얕은 키 줄 전까지)의 with: 바로 아래 키 줄만 센다 —
 * 같은 job의 다른 스텝(checkout의 with: · 게이트 스텝의 env:)에 있는 핀은 setup-node의 버전 입력이 아니다(러너 기본 Node). 주석 줄은 키가
 * 아니고(그 안의 node-version-file 글자도), with: 아래에서 첫 키보다 깊이 들여쓴 줄은 값의 이어짐이다.
 * r7(리뷰 r6 R6-1 · 지시문 F36): 여기에 더해 블록 전체(주석 줄 제외)에서 — (b) setup-node를 가리키는 줄은 꼴과 상관없이 정확히 하나이고 그
 * 줄이 위 대시 꼴 스텝 머리다(꼴이 다른 둘째 setup-node 스텝도 PATH 앞에 제 Node를 놓는다) · (c) with:는 스텝 키 깊이에서만 받는다(env:
 * 같은 다른 키 아래에 들여쓴 with:는 setup-node의 입력이 아니다) · (a) node-version 키 줄은 위 핀 하나뿐이고 node-version-file 키 줄은
 * 없다(꼴 무관).
 * r8(리뷰 r7 R7-1 · 지시문 F39): 원문(ci.yml 전체)에 NEL · LS · PS가 하나라도 있으면 문제 하나를 더한다 — 파서마다 줄바꿈 여부가 달라
 * 블록 경계가 갈린다(YAML_LINE_BREAK 주석). 이 검사는 줄 단위 드리프트 검사다(계약 r8).
 * 돌려주는 값: { problems: 문제 목록(비면 일치), line: node-version 키 줄의 번호(0부터 — 정확히 하나가 아니면 -1) }
 */
function gateNodePin(ciText, nodeVersion) {
  const breaks = [...ciText].filter((char) => YAML_NON_ASCII_BREAKS.includes(char)).length;
  const problems = breaks > 0 ? [`ci.yml에 NEL · LS · PS가 ${breaks}개 — 파서마다 줄바꿈 여부가 달라 블록 경계가 갈린다`] : [];
  const lines = yamlLines(ciText);
  const range = eventsCompatRange(lines);
  if (range === null) return { problems: [...problems, "job events-compat 블록이 없다"], line: -1 };
  const keyLines = [];
  for (let index = range.from; index < range.to; index += 1) {
    if (isKeyLine(lines[index])) keyLines.push(index);
  }
  const starts = keyLines.filter((index) => SETUP_NODE_HEAD.test(lines[index]));
  if (starts.length !== 1) return { problems: [...problems, `setup-node 스텝 ${starts.length}개(정확히 1개여야 한다)`], line: -1 };
  // (b) 대시 꼴 머리도 SETUP_NODE_REF에 맞으므로, 하나뿐이면 그 줄이 곧 대시 꼴 스텝 머리다
  const refs = keyLines.filter((index) => SETUP_NODE_REF.test(lines[index]));
  if (refs.length !== 1) problems.push(`setup-node를 가리키는 줄 ${refs.length}개(꼴 무관 — 대시 꼴 스텝 머리 하나뿐이어야 한다)`);
  const step = starts[0];
  const dash = indentOf(lines[step]);
  const keyDepth = SETUP_NODE_HEAD.exec(lines[step])[1].length;
  let stepEnd = step + 1;
  while (stepEnd < range.to && !(isKeyLine(lines[stepEnd]) && indentOf(lines[stepEnd]) <= dash)) stepEnd += 1;
  const pins = [];
  const versionFiles = [];
  for (let index = step + 1; index < stepEnd; index += 1) {
    // (c) with:는 스텝 키 깊이에서만 — 더 깊은 with:는 다른 키(env: 등)의 값이다
    if (!/^\s*with:\s*$/.test(lines[index]) || indentOf(lines[index]) !== keyDepth) continue;
    let keyIndent = -1;
    for (let child = index + 1; child < stepEnd; child += 1) {
      if (!isKeyLine(lines[child])) continue;
      const indent = indentOf(lines[child]);
      if (indent <= keyDepth) break;
      if (keyIndent < 0) keyIndent = indent;
      if (indent !== keyIndent) continue;
      if (PIN_KEY.test(lines[child])) pins.push(child);
      if (PIN_FILE_KEY.test(lines[child])) versionFiles.push(child);
    }
  }
  if (pins.length !== 1) problems.push(`setup-node with: 아래 node-version 줄 ${pins.length}개(정확히 1개여야 한다)`);
  if (versionFiles.length > 0) problems.push(`setup-node with: 아래 node-version-file 줄 ${versionFiles.length}개(없어야 한다 — 체크아웃 전이라 읽을 파일이 없다)`);
  // (a) 블록 전체의 키 줄 — 위 핀 · node-version-file 줄 밖에 하나라도 있으면 불일치
  const strayPins = keyLines.filter((index) => NODE_VERSION_KEY.test(lines[index]) && !pins.includes(index));
  const strayFiles = keyLines.filter((index) => NODE_VERSION_FILE_KEY.test(lines[index]) && !versionFiles.includes(index));
  if (strayPins.length > 0) problems.push(`setup-node with: 밖 node-version 키 줄 ${strayPins.length}개(job 블록 전체 — 핀은 setup-node with: 아래 하나뿐이어야 한다)`);
  if (strayFiles.length > 0) problems.push(`setup-node with: 밖 node-version-file 키 줄 ${strayFiles.length}개(job 블록 전체 — 없어야 한다)`);
  if (pins.length === 1) {
    const value = lines[pins[0]].replace(/^\s*node-version[ \t]*:[ \t]*/, "").trimEnd();
    const quoted = /^'([^']*)'$/.exec(value);
    if (quoted === null) problems.push(`node-version 값 ${value}가 작은따옴표 문자열이 아니다`);
    else if (quoted[1] !== nodeVersion) problems.push(`node-version '${quoted[1]}' ≠ .node-version ${JSON.stringify(nodeVersion)}`);
  }
  return { problems, line: pins.length === 1 ? pins[0] : -1 };
}

/** sch-23 키 줄 수 대조 — job events-compat 블록 안(주석 줄 제외)의 node-version 키 줄 수(블록이 없으면 -1). r7 (e): ci.yml 전체가 아니다 */
function gateBlockPinKeyLines(ciText) {
  const lines = yamlLines(ciText);
  const range = eventsCompatRange(lines);
  if (range === null) return -1;
  return lines.slice(range.from, range.to).filter((line) => isKeyLine(line) && NODE_VERSION_KEY.test(line)).length;
}

describe("schemas/ — 계약 「필드 형식 · 필수」 표 ↔ 파일 내용", () => {
  it("sch-1 schemas/의 .json은 정확히 7개(_envelope.json + 계약 토픽 6)다", () => {
    const files = fs.readdirSync(SCHEMAS_DIR).filter((name) => name.endsWith(".json"));
    expect(files.sort()).toEqual([...FILES].sort());
  });

  it.each(FILES)("sch-1 %s — required = 계약 표의 필수 · properties = 필수 + 선택", (name) => {
    const schema = readRealSchema(name);
    const { required, optional } = FIELDS[name];
    expect(Array.isArray(schema.required), name).toBe(true);
    expect(new Set(schema.required).size, "required 중복").toBe(schema.required.length);
    expect(new Set(schema.required)).toEqual(new Set(required));
    expect(new Set(Object.keys(schema.properties))).toEqual(new Set([...required, ...optional]));
  });

  it.each(FILES)("sch-2 %s — 모든 속성(중첩 · items 포함)이 type을 명시한다", (name) => {
    const schema = readRealSchema(name);
    expect(Object.hasOwn(schema, "type"), "#").toBe(true);
    const found = subschemas(schema);
    expect(found.length).toBeGreaterThan(0);
    const untyped = found.filter(([, node]) => !Object.hasOwn(node, "type")).map(([pointer]) => pointer);
    expect(untyped).toEqual([]);
  });

  it.each(FILES)("sch-3 %s — 속성 정의 = 설계 D2 표(제약 키 — 메타데이터 제외)", (name) => {
    const schema = readRealSchema(name);
    expect(constraintsOf({ properties: schema.properties }).properties).toEqual(CONSTRAINTS[name]);
  });

  it.each(FILES)("sch-4 %s — 머리(Draft 2020-12 · $id · x-version 1.0.0 · title · 한국어 description · type object) · 정규 서식", (name) => {
    const text = readRealText(name);
    const schema = JSON.parse(text);
    // 머리 키: 설계 D2 공통 키만(+ 메타데이터 $comment · examples) — additionalProperties · $defs · $ref 없음
    const common = ["$schema", "$id", "x-version", "title", "description", "type", "properties", "required"];
    for (const key of common) expect(Object.hasOwn(schema, key), `${name}: ${key} 없음`).toBe(true);
    expect(Object.keys(schema).filter((key) => !common.includes(key) && key !== "$comment" && key !== "examples")).toEqual([]);
    expect(schema.$schema).toBe(DRAFT_2020_12);
    expect(schema["x-version"]).toBe("1.0.0");
    expect(schema.type).toBe("object");
    if (name === "_envelope.json") {
      expect(schema.$id).toBe("https://joshuatech.dev/events/_envelope/v1");
      expect(schema.title).toBe("CloudEvents 1.0 봉투");
    } else {
      const topic = name.slice(0, -".json".length);
      expect(schema.$id).toBe(`https://joshuatech.dev/events/${topic}/v1`);
      expect(schema.title).toBe(topic);
    }
    expect(typeof schema.description).toBe("string");
    expect(schema.description).toMatch(/[가-힣]/);
    // 정규 서식: JSON.stringify(…, null, 2) + 끝 LF 그대로(2칸 들여쓰기 · BOM · CR · 줄 끝 공백 없음)
    expect(text).toBe(`${JSON.stringify(schema, null, 2)}\n`);
  });
});

describe("validateEvent — 토픽별 data(실제 schemas/)", () => {
  it.each(TOPICS)("sch-5 %s — 계약 모양의 표본 봉투는 통과한다", (topic) => {
    const result = validate(envelopeFor(topic));
    expect(result.errors).toEqual([]);
  });

  it("sch-5 identity-admin.session.revoked — 웹훅 모양(sid 문자열 · reason authentik_webhook)도 통과한다(T061 DATA_WEBHOOK)", () => {
    const data = { sub: "4b1d-test", sid: "sid-4b1d", nbf: 1756696868, reason: "authentik_webhook" };
    const result = validate(envelopeFor("identity-admin.session.revoked", data));
    expect(result.errors).toEqual([]);
  });

  const requiredCases = TOPICS.flatMap((topic) => FIELDS[`${topic}.json`].required.map((field) => [topic, field]));
  it.each(requiredCases)("sch-5 %s — 필수 필드 %s 누락 → 실패(#/data/<필드>)", (topic, field) => {
    const data = structuredClone(SAMPLES[topic].data);
    delete data[field];
    const result = validate(envelopeFor(topic, data));
    expect(result.ok).toBe(false);
    expect(errorPaths(result)).toEqual([`#/data/${field}`]);
  });

  const optionalCases = TOPICS.flatMap((topic) => FIELDS[`${topic}.json`].optional.map((field) => [topic, field]));
  it.each(optionalCases)("sch-5 %s — 선택 필드 %s는 빼도 통과한다", (topic, field) => {
    const data = structuredClone(SAMPLES[topic].data);
    delete data[field];
    const result = validate(envelopeFor(topic, data));
    expect(result.errors).toEqual([]);
  });

  // [이름, 토픽, data 변경, 실패 경로]
  const NEGATIVE = [
    ["tenant_id 비-UUID(slug)", "identity-admin.user.registered", (d) => { d.tenant_id = "joshuatech"; }, "#/data/tenant_id"],
    ["tenant_id 대문자 UUID", "identity-admin.user.registered", (d) => { d.tenant_id = TENANT.toUpperCase(); }, "#/data/tenant_id"],
    ["tenant_id urn:uuid: 접두", "identity-admin.tenant.created", (d) => { d.tenant_id = `urn:uuid:${TENANT}`; }, "#/data/tenant_id"],
    ["tenant_id 비-UUID", "identity-admin.tenant.created", (d) => { d.tenant_id = "tenant-1"; }, "#/data/tenant_id"],
    ["registered_at 날짜만", "identity-admin.user.registered", (d) => { d.registered_at = "2026-09-01"; }, "#/data/registered_at"],
    ["registered_at 시간대 없음", "identity-admin.user.registered", (d) => { d.registered_at = "2026-09-01T03:21:07"; }, "#/data/registered_at"],
    ["role admin(SP-2 예약 — enum 값 추가로 넣는다)", "identity-admin.user.registered", (d) => { d.role = "admin"; }, "#/data/role"],
    ["email_hash 대문자 hex", "identity-admin.user.registered", (d) => { d.email_hash = EMAIL_HASH.toUpperCase(); }, "#/data/email_hash"],
    ["email_hash 63자", "identity-admin.user.registered", (d) => { d.email_hash = EMAIL_HASH.slice(1); }, "#/data/email_hash"],
    ["sub 빈 문자열", "identity-admin.user.registered", (d) => { d.sub = ""; }, "#/data/sub"],
    ["slug 한 글자(최소 2자)", "identity-admin.tenant.created", (d) => { d.slug = "j"; }, "#/data/slug"],
    ["slug - 시작", "identity-admin.tenant.created", (d) => { d.slug = "-joshuatech"; }, "#/data/slug"],
    ["slug 대문자", "identity-admin.tenant.created", (d) => { d.slug = "JoshuaTech"; }, "#/data/slug"],
    ["slug 32자", "identity-admin.tenant.created", (d) => { d.slug = "a".repeat(32); }, "#/data/slug"],
    ["display_name 빈 문자열", "identity-admin.tenant.created", (d) => { d.display_name = ""; }, "#/data/display_name"],
    ["display_name 81자", "identity-admin.tenant.created", (d) => { d.display_name = "가".repeat(81); }, "#/data/display_name"],
    ["lang fr", "portfolio-core.note.published", (d) => { d.lang = "fr"; }, "#/data/lang"],
    ["change 3-x", "portfolio-core.note.published", (d) => { d.change = "3-x"; }, "#/data/change"],
    ["note slug 연속 -", "portfolio-core.note.published", (d) => { d.slug = "events--compat"; }, "#/data/slug"],
    ["note slug 대문자", "portfolio-core.note.published", (d) => { d.slug = "Events-Compat"; }, "#/data/slug"],
    ["title 빈 문자열", "portfolio-core.note.published", (d) => { d.title = ""; }, "#/data/title"],
    ["tags 빈 문자열 항목", "portfolio-core.note.published", (d) => { d.tags = ["events", ""]; }, "#/data/tags/1"],
    ["tags 문자열(배열 아님)", "portfolio-core.note.published", (d) => { d.tags = "events"; }, "#/data/tags"],
    ["published_at 날짜만", "portfolio-core.note.published", (d) => { d.published_at = "2026-11-03"; }, "#/data/published_at"],
    ["body_excerpt 201자", "engagement.comment.created", (d) => { d.body_excerpt = "가".repeat(201); }, "#/data/body_excerpt"],
    ["body_excerpt 201 코드 포인트(이모지)", "engagement.comment.created", (d) => { d.body_excerpt = "😀".repeat(201); }, "#/data/body_excerpt"],
    ["target 종류 없음", "engagement.comment.created", (d) => { d.target = "events-compat"; }, "#/data/target"],
    ["created_at 시간대 없음", "engagement.comment.created", (d) => { d.created_at = "2026-11-03T18:30:00"; }, "#/data/created_at"],
    ["author_sub 빈 문자열", "engagement.comment.created", (d) => { d.author_sub = ""; }, "#/data/author_sub"],
    ["bytes −1", "media.object.ready", (d) => { d.bytes = -1; }, "#/data/bytes"],
    ["bytes 실수", "media.object.ready", (d) => { d.bytes = 1.5; }, "#/data/bytes"],
    ["kind video", "media.object.ready", (d) => { d.kind = "video"; }, "#/data/kind"],
    ["variants 항목 url 없음", "media.object.ready", (d) => { delete d.variants[0].url; }, "#/data/variants/0/url"],
    ["variants 항목 url 상대 경로", "media.object.ready", (d) => { d.variants[1].url = "/m-01/original.png"; }, "#/data/variants/1/url"],
    ["variants 항목 name 빈 문자열", "media.object.ready", (d) => { d.variants[0].name = ""; }, "#/data/variants/0/name"],
    ["sid 빈 문자열", "identity-admin.session.revoked", (d) => { d.sid = ""; }, "#/data/sid"],
    ["sid 숫자", "identity-admin.session.revoked", (d) => { d.sid = 7; }, "#/data/sid"],
    ["nbf 실수", "identity-admin.session.revoked", (d) => { d.nbf = 1756696867.5; }, "#/data/nbf"],
    ["nbf −1", "identity-admin.session.revoked", (d) => { d.nbf = -1; }, "#/data/nbf"],
    ["nbf 문자열", "identity-admin.session.revoked", (d) => { d.nbf = "1756696867"; }, "#/data/nbf"],
    ["reason enum 밖", "identity-admin.session.revoked", (d) => { d.reason = "expired"; }, "#/data/reason"],
    // r2 — 끝 줄바꿈(Python re의 맨 $가 통과시키던 값). ajv에서는 r1 패턴(맨 `$`)으로도 거부된다 — Python 쪽 의미는 sch-8 꼴 검사
    // (끝 `$(?!\n)` · 맨 `.` 금지)와 저장소 밖 두 엔진 대조가 지킨다(Python 쪽 저장소 안 시험은 T069 인계).
    ["note slug 끝 줄바꿈", "portfolio-core.note.published", (d) => { d.slug = `events-compat${LF}`; }, "#/data/slug"],
    ["change 끝 줄바꿈", "portfolio-core.note.published", (d) => { d.change = `003-platform-foundation${LF}`; }, "#/data/change"],
    ["email_hash 끝 줄바꿈", "identity-admin.user.registered", (d) => { d.email_hash = `${EMAIL_HASH}${LF}`; }, "#/data/email_hash"],
    ["tenant slug 끝 줄바꿈", "identity-admin.tenant.created", (d) => { d.slug = `joshuatech${LF}`; }, "#/data/slug"],
    ["tenant_id 끝 줄바꿈", "identity-admin.tenant.created", (d) => { d.tenant_id = `${TENANT}${LF}`; }, "#/data/tenant_id"],
    ["target 끝 줄바꿈", "engagement.comment.created", (d) => { d.target = `note:events-compat${LF}`; }, "#/data/target"],
    // r2 — target id 부분의 제어 문자(C0 · DEL · C1 — 계약 「필드 형식 · 필수」: 봉투 subject와 같은 pattern)
    ["target CR", "engagement.comment.created", (d) => { d.target = `note:a${cp(0x0d)}b`; }, "#/data/target"],
    ["target TAB", "engagement.comment.created", (d) => { d.target = `note:a${cp(0x09)}b`; }, "#/data/target"],
    ["target NUL", "engagement.comment.created", (d) => { d.target = `note:a${cp(0x00)}b`; }, "#/data/target"],
    ["target DEL", "engagement.comment.created", (d) => { d.target = `note:a${cp(0x7f)}`; }, "#/data/target"],
    ["target U+0085(C1)", "engagement.comment.created", (d) => { d.target = `note:a${cp(0x85)}b`; }, "#/data/target"],
    ["target id 없음", "engagement.comment.created", (d) => { d.target = "note:"; }, "#/data/target"],
    // r2 — variants[].url: https 절대 URL · RFC 3986 글자만(scheme 대문자도 거부 — pattern은 소문자 https://만)
    ["url http", "media.object.ready", (d) => { d.variants[0].url = "http://media.joshuatech.dev/m-01/thumb.webp"; }, "#/data/variants/0/url"],
    ["url javascript:", "media.object.ready", (d) => { d.variants[0].url = "javascript:alert(1)"; }, "#/data/variants/0/url"],
    ["url file:", "media.object.ready", (d) => { d.variants[0].url = "file:///etc/passwd"; }, "#/data/variants/0/url"],
    ["url 공백", "media.object.ready", (d) => { d.variants[0].url = "https://media.joshuatech.dev/m 01/thumb.webp"; }, "#/data/variants/0/url"],
    ["url <", "media.object.ready", (d) => { d.variants[0].url = "https://media.joshuatech.dev/<script>"; }, "#/data/variants/0/url"],
    ["url 비ASCII", "media.object.ready", (d) => { d.variants[0].url = "https://media.joshuatech.dev/파일.png"; }, "#/data/variants/0/url"],
    ["url scheme 대문자", "media.object.ready", (d) => { d.variants[0].url = "HTTPS://media.joshuatech.dev/m-01/thumb.webp"; }, "#/data/variants/0/url"],
    ["url 끝 줄바꿈", "media.object.ready", (d) => { d.variants[0].url = `https://media.joshuatech.dev/m-01/thumb.webp${LF}`; }, "#/data/variants/0/url"],
  ];
  it.each(NEGATIVE)("sch-6 %s(%s) → 실패", (_label, topic, mutate, pointer) => {
    const data = structuredClone(SAMPLES[topic].data);
    mutate(data);
    const result = validate(envelopeFor(topic, data));
    expect(result.ok).toBe(false);
    expect(errorPaths(result), JSON.stringify(result.errors)).toEqual([pointer]);
  });

  // [이름, 토픽, data 변경] — 경계값은 통과한다
  const BOUNDARY = [
    ["body_excerpt 200자(한글)", "engagement.comment.created", (d) => { d.body_excerpt = "가".repeat(200); }],
    ["body_excerpt 200 코드 포인트(이모지 — UTF-16 400단위)", "engagement.comment.created", (d) => { d.body_excerpt = "😀".repeat(200); }],
    ["body_excerpt 빈 문자열", "engagement.comment.created", (d) => { d.body_excerpt = ""; }],
    ["display_name 80자", "identity-admin.tenant.created", (d) => { d.display_name = "가".repeat(80); }],
    ["slug 31자", "identity-admin.tenant.created", (d) => { d.slug = `j${"a".repeat(30)}`; }],
    ["tags 빈 배열", "portfolio-core.note.published", (d) => { d.tags = []; }],
    ["variants 빈 배열", "media.object.ready", (d) => { d.variants = []; }],
    ["bytes 0", "media.object.ready", (d) => { d.bytes = 0; }],
    ["nbf 0", "identity-admin.session.revoked", (d) => { d.nbf = 0; }],
    ["role member", "identity-admin.user.registered", (d) => { d.role = "member"; }],
    ["created_at 오프셋 +09:00", "engagement.comment.created", (d) => { d.created_at = "2026-11-03T18:30:00.5+09:00"; }],
    ["알 수 없는 속성(열린 스키마 — 소비자는 무시한다)", "identity-admin.session.revoked", (d) => { d.extra_field = { any: true }; }],
    // r2 — target id 부분은 제어 문자만 막는다(NBSP · 한글 · 이모지 · U+2028은 통과 — 두 엔진 같은 판정)
    ["target NBSP", "engagement.comment.created", (d) => { d.target = `note:a${cp(0xa0)}b`; }],
    ["target 한글", "engagement.comment.created", (d) => { d.target = "note:이벤트-호환성"; }],
    ["target 이모지", "engagement.comment.created", (d) => { d.target = `note:${cp(0x1f600)}`; }],
    ["target U+2028", "engagement.comment.created", (d) => { d.target = `note:a${cp(0x2028)}b`; }],
    // r2 — https 절대 URL(쿼리 · 조각 · IP 리터럴 · 포트 · 퍼센트 인코딩 · 하위 구분자)
    ["url https 쿼리 · 조각", "media.object.ready", (d) => { d.variants[0].url = "https://cdn.example.com/a/b.webp?x=1&y=2#f"; }],
    ["url https IP 리터럴 · 포트", "media.object.ready", (d) => { d.variants[0].url = "https://[::1]:8443/x"; }],
    ["url https 퍼센트 인코딩 · 하위 구분자", "media.object.ready", (d) => { d.variants[0].url = "https://example.com/%E2%82%AC'(x)*+,;=~@!$"; }],
  ];
  it.each(BOUNDARY)("sch-6 %s(%s) → 통과", (_label, topic, mutate) => {
    const data = structuredClone(SAMPLES[topic].data);
    mutate(data);
    const result = validate(envelopeFor(topic, data));
    expect(result.errors).toEqual([]);
  });
});

describe("validateEvent — 봉투 형식(계약 §봉투 필드 형식)", () => {
  it.each([
    ["source", "Identity_Admin"],
    ["source", "identity-admin-"],
    ["subject", "9f2c"],
    ["subject", "User:9f2c"],
    ["type", "Identity-Admin.session.revoked"],
    ["type", "a..b.c"],
    ["type", "../evil"],
    ["type", "identity-admin.session"],
    ["type", "identity-admin.session.revoked."],
    ["type", "_envelope.x.y"],
    ["tenantid", "00000000-0000-4000-8000-00000000000A"],
    ["id", "01j8qk3q9s8zq4v7h2m1x0n5ab"],
    ["id", "81J8QK3Q9S8ZQ4V7H2M1X0N5AB"],
    ["time", "2026-09-01T03:21:07"],
    // r2 — 끝 줄바꿈(Python re의 맨 $가 통과시키던 값 — ajv에서는 r1 패턴으로도 거부된다: sch-6 끝 줄바꿈 주석)
    ["id", `01J8QK3Q9S8ZQ4V7H2M1X0N5AB${LF}`],
    ["source", `identity-admin${LF}`],
    ["type", `identity-admin.session.revoked${LF}`],
    ["subject", `user:9f2c-test${LF}`],
    // r2 — subject id 부분의 제어 문자(C0 · DEL · C1 — Python re의 .이 통과시키던 CR 포함)
    ["subject", `user:9f2c${cp(0x0d)}test`],
    ["subject", `user:9f2c${cp(0x09)}test`],
    ["subject", `user:9f2c${cp(0x00)}test`],
    ["subject", `user:9f2c${cp(0x7f)}`],
    ["subject", `user:9f2c${cp(0x85)}test`],
    ["subject", "user:"],
  ])("sch-7 %s = %j → 실패(#/<필드>)", (field, value) => {
    const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), [field]: value });
    expect(result.ok).toBe(false);
    expect(result.errors, JSON.stringify(result.errors)).toContainEqual(expect.objectContaining({ path: `#/${field}` }));
  });

  it.each([
    "identity-admin.session.revoked.v2", // 호환 깨는 변경의 새 토픽(…v2) — 이름은 봉투 pattern을 통과한다
    "dev.identity-admin.session.revoked", // 물리 토픽(env 접두) — type은 논리 토픽이어야 한다
  ])("sch-7 type %s — 봉투 pattern은 통과하고 schema-missing으로 실패한다", (type) => {
    const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), type });
    expect(result.ok).toBe(false);
    expect(schemaMissingFor(result.errors, type), JSON.stringify(result.errors)).toBe(true);
    // #/type 오류는 schema-missing 하나뿐이다(pattern 위반 없음)
    expect(result.errors.filter((error) => error.path === "#/type" && !error.message.includes("schema-missing"))).toEqual([]);
  });

  it.each([
    ["NBSP", `user:a${cp(0xa0)}b`],
    ["한글", "note:이벤트-호환성"],
    ["이모지", `user:${cp(0x1f600)}`],
    ["U+2028", `user:a${cp(0x2028)}b`],
  ])("sch-7 subject id 부분의 %s는 통과한다(제어 문자만 막는다 — 두 엔진 같은 판정)", (_label, subject) => {
    const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), subject });
    expect(result.errors).toEqual([]);
  });

  it("sch-7 봉투에 CloudEvents 확장 속성(traceparent)이 더해져도 통과한다(열린 스키마)", () => {
    const envelope = {
      ...structuredClone(SAMPLE_ENVELOPE),
      traceparent: "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
    };
    const result = validate(envelope);
    expect(result.errors).toEqual([]);
  });
});

/** pattern에서 문자 클래스([…]) 밖의 이스케이프되지 않은 "."의 위치 — 이스케이프(역슬래시 + 글자 하나)와 클래스 괄호를 따라간다 */
function unescapedDots(pattern) {
  const found = [];
  let inClass = false;
  for (let index = 0; index < pattern.length; index += 1) {
    const char = pattern[index];
    if (char === BACKSLASH) {
      index += 1; // 다음 글자는 이스케이프된 글자다
    } else if (inClass) {
      if (char === "]") inClass = false;
    } else if (char === "[") {
      inClass = true;
    } else if (char === ".") {
      found.push(index);
    }
  }
  return found;
}

describe("패턴 이식성 — ajv(JS u 플래그)와 Python re(jsonschema)에서 같은 뜻", () => {
  it("sch-8 스캐너 자체 확인 — 클래스 밖의 맨 .만 센다(이스케이프된 . · 클래스 안의 . · 이스케이프된 ]는 클래스를 닫지 않는다)", () => {
    expect(unescapedDots("^a.b$")).toEqual([2]);
    expect(unescapedDots(String.raw`^a\.b[.x]c$`)).toEqual([]);
    expect(unescapedDots(String.raw`^[\].]x.$`)).toEqual([7]);
    expect(unescapedDots(String.raw`^[^\x00-\x1f]+$(?!\n)`)).toEqual([]);
  });

  it("sch-8 7개 파일의 모든 pattern은 ^로 시작하고 $(?!\\n)으로 끝나며(맨 $ 끝 없음) 클래스 밖의 맨 . · \\d \\w \\s \\b \\p (?<가 없고 u 플래그로 컴파일된다", () => {
    const patterns = [];
    for (const name of FILES) {
      const schema = readRealSchema(name);
      for (const [pointer, node] of subschemas(schema)) {
        if (typeof node.pattern === "string") patterns.push([`${name} ${pointer}`, node.pattern]);
      }
    }
    // 봉투 5(id · source · type · subject · tenantid) + 토픽 8(email_hash · tenant_id 2 · slug 2 · change · target · url)
    expect(patterns.length).toBeGreaterThanOrEqual(13);
    for (const [where, pattern] of patterns) {
      expect(pattern, where).not.toMatch(/\\[dDwWsSbBpP]|\(\?<|\(\?P/);
      expect(pattern.startsWith("^"), where).toBe(true);
      expect(pattern.endsWith(END), `${where}: 끝은 $(?!\\n)이어야 한다 — ${pattern}`).toBe(true);
      expect(unescapedDots(pattern), `${where}: 클래스 밖의 맨 . — ${pattern}`).toEqual([]);
      expect(() => new RegExp(pattern, "u"), where).not.toThrow();
    }
  });
});

// 왜 전제 단언이 따로 있는가(T067 r6 · 리뷰 r5 R5-1 · 계약 r6 「한계」): sch-9 · sch-14(패키지 밖) · sch-21은 사본이 ajv를 찾지 못하는 조건
// (머지 뒤 게이트 — setup-node + bash → node <사본> · node_modules도 NODE_PATH도 없다)에서만 판별력이 있다. 그 조건은 outOfPackageEnv
// (NODE_PATH · NODE_OPTIONS 제거) · 사본 자리(os.tmpdir() 아래 — 위쪽 디렉터리에 node_modules가 없어야 한다) · Node 전역 폴더(~/.node_modules ·
// ~/.node_libraries · <prefix>/lib/node)가 함께 만든다. 하나라도 깨지면(CI 명령의 pnpm vitest shim이 넣은 NODE_PATH를 물려줌 · 임시 디렉터리
// 위쪽의 node_modules · 전역 폴더의 ajv) 그 시험들은 CLI 경로에서 ajv를 부르는 변경을 조용히 통과시킨다. 그래서 같은 env · 같은 자리에서 ajv ·
// ajv-formats가 해석되지 않음을 먼저 단언한다 — 전제가 깨진 환경에서는 판별력을 잃는 대신 이 시험이 FAIL한다. 대조: 같은 env · 같은 탐침을
// 패키지 안 검사기 자리(SCRIPT)에서 돌리면 해석된다(탐침이 공허하지 않다 — 실패는 자리와 env 때문이다).
describe("패키지 밖 사본의 실행 env — 게이트 조건의 전제(sch-24)", () => {
  it("sch-24 outOfPackageEnv에서 패키지 밖 사본 자리(makeTempDir())로는 ajv/dist/2020 · ajv-formats가 해석되지 않는다(MODULE_NOT_FOUND — pnpm vitest shim의 NODE_PATH를 물려주면 해석된다) · 그 env에는 NODE_PATH · NODE_OPTIONS가 (대소문자 무관) 없다 · 대조: 같은 env에서 패키지 안 검사기 자리로는 해석된다", { timeout: 60_000 }, () => {
    const env = outOfPackageEnv();
    const copy = copyChecker(makeTempDir());
    for (const specifier of ["ajv/dist/2020", "ajv-formats"]) {
      const probe = resolveProbe(copy, specifier, env);
      expect(probe.error, specifier).toBeUndefined();
      expect(typeof probe.status, `${specifier}: ${probe.stderr}`).toBe("number");
      expect(probe.status, `${specifier}: 사본 자리에서 해석됐다(exit ${probe.status}) — 게이트 조건(node_modules 없음)이 아니다`).not.toBe(0);
      expect(probe.stderr, specifier).toMatch(/MODULE_NOT_FOUND|Cannot find module/);
      expect(probe.stderr, specifier).toContain(specifier);

      const control = resolveProbe(SCRIPT, specifier, env);
      expect(control.error, `대조 ${specifier}`).toBeUndefined();
      expect(control.status, `대조 ${specifier}: ${control.stderr}`).toBe(0);
    }
    expect(Object.keys(env).filter((key) => STRIPPED_ENV_KEYS.has(key.toUpperCase())), "outOfPackageEnv에 남은 키").toEqual([]);
  });
});

describe("검사기 — T067 규칙(build-notes D3)", () => {
  it("sch-9 모듈 머리의 정적 import · re-export는 node: 내장 모듈뿐이고 동적 import도 없다(ajv는 validateEvent가 지연 로드)", () => {
    const source = fs.readFileSync(SCRIPT, "utf8");
    const specifiers = [
      ...source.matchAll(/^\s*import\s+(?:[^"';]*?\sfrom\s*)?["']([^"']+)["']/gm),
      ...source.matchAll(/^\s*export\s+[^"';]*?\sfrom\s*["']([^"']+)["']/gm),
    ].map((match) => match[1]);
    expect(specifiers.length).toBeGreaterThan(0);
    expect(specifiers.filter((specifier) => !specifier.startsWith("node:"))).toEqual([]);
    expect(source).not.toMatch(/\bimport\s*\(/);
  });

  // r6(리뷰 r5 R5-1): 사본은 NODE_PATH · NODE_OPTIONS를 지운 env로 돈다(runCopy — 전제는 sch-24). 위의 정적 규칙은 import 문만 보므로
  // createRequire로 패키지를 부르는 CLI 경로는 이 실행 사례 · sch-14(패키지 밖) · sch-21이 잡는다.
  it("sch-9 검사기 CLI는 패키지 밖(node_modules 없음 · NODE_PATH · NODE_OPTIONS 없는 env)에 복사해도 0 · 1 · 2로 끝난다(CI 기준 쪽 사본 실행)", { timeout: 60_000 }, () => {
    const root = makeTempDir();
    const copy = copyChecker(root);
    const withoutX = structuredClone(SMALL);
    delete withoutX.properties.x;
    const withAnyOf = structuredClone(SMALL);
    withAnyOf.properties.x.anyOf = [{ type: "string" }];
    const baseDir = writeSchemas(makeSubDir(root, "base"), { "s.json": SMALL });
    const sameDir = writeSchemas(makeSubDir(root, "same"), { "s.json": SMALL });
    const brokenDir = writeSchemas(makeSubDir(root, "broken"), { "s.json": withoutX });
    const unsupportedDir = writeSchemas(makeSubDir(root, "unsupported"), { "s.json": withAnyOf });

    const same = runCopy(copy, ["--base", baseDir, "--head", sameDir]);
    expect(same.error).toBeUndefined();
    expect(same.status, same.stderr).toBe(0);
    expect(same.stdout).toBe("");

    const broken = runCopy(copy, ["--base", baseDir, "--head", brokenDir]);
    expect(broken.status, broken.stderr).toBe(1);
    // stdout은 위반 줄만 — "<file> <path> <kind> <message>"
    const lines = broken.stdout.split(/\r?\n/).filter((line) => line !== "");
    expect(lines).toHaveLength(1);
    expect(lines[0].startsWith("s.json #/properties/x field-removed "), broken.stdout).toBe(true);
    expect(broken.stderr).toContain("violations 1");

    const missing = runCopy(copy, ["--base", baseDir, "--head", path.join(root, "no-such-dir")]);
    expect(missing.status).toBe(2);
    expect(missing.stderr.trim()).not.toBe("");

    const unsupported = runCopy(copy, ["--base", baseDir, "--head", unsupportedDir]);
    expect(unsupported.status, unsupported.stderr).toBe(2);
    expect(unsupported.stderr).toContain("anyOf");
    expect(unsupported.stderr).toContain("s.json");
    expect(unsupported.stdout).not.toMatch(new RegExp(KINDS.join("|")));
  });

  // [이름, 키, head 변경] — 허용 목록 밖의 구조 키는 위치(최상위 · 기존 속성 · 새 속성 · items 안)와 무관하게 거부한다
  const UNSUPPORTED = [
    ["anyOf(기존 속성 안)", "anyOf", (s) => { s.properties.x.anyOf = [{ type: "string" }, { type: "null" }]; }],
    ["$ref(새 속성 — head에만)", "$ref", (s) => { s.properties.added = { $ref: "#/properties/x" }; }],
    ["prefixItems(새 배열 속성)", "prefixItems", (s) => { s.properties.list = { type: "array", prefixItems: [{ type: "string" }] }; }],
    ["anyOf(items 안)", "anyOf", (s) => { s.properties.list = { type: "array", items: { anyOf: [{ type: "string" }] } }; }],
    ["$defs(최상위)", "$defs", (s) => { s.$defs = { id: { type: "string" } }; }],
    ["allOf", "allOf", (s) => { s.allOf = [{ required: ["x"] }]; }],
    ["oneOf", "oneOf", (s) => { s.properties.n.oneOf = [{ minimum: 0 }, { maximum: -10 }]; }],
    ["not", "not", (s) => { s.properties.x.not = { const: "" }; }],
    ["if", "if", (s) => { s.if = { required: ["x"] }; }],
    ["patternProperties", "patternProperties", (s) => { s.patternProperties = { "^x-": { type: "string" } }; }],
    ["dependentRequired", "dependentRequired", (s) => { s.dependentRequired = { x: ["n"] }; }],
    ["unevaluatedProperties", "unevaluatedProperties", (s) => { s.unevaluatedProperties = false; }],
    ["contains", "contains", (s) => { s.properties.list = { type: "array", contains: { type: "string" } }; }],
  ];
  it.each(UNSUPPORTED)("sch-10 허용 키 밖 %s → diffSchema가 UnsupportedSchemaError(head에만 · base에만 모두)", (_label, key, mutate) => {
    const changed = structuredClone(SMALL);
    mutate(changed);
    expectUnsupported(() => diffSchema(structuredClone(SMALL), changed), key);
    expectUnsupported(() => diffSchema(changed, structuredClone(SMALL)), key);
  });

  it("sch-10 새 스키마 파일(added)도 허용 키 밖이면 compareDirectories가 거부한다", () => {
    const withRef = structuredClone(SMALL);
    withRef.properties.added = { $ref: "#/properties/x" };
    const baseDir = writeSchemas(makeTempDir(), { "s.json": SMALL });
    const headDir = writeSchemas(makeTempDir(), { "s.json": SMALL, "t.json": withRef });
    let thrown;
    try {
      compareDirectories(baseDir, headDir);
    } catch (error) {
      thrown = error;
    }
    expect(thrown).toBeInstanceOf(Error);
    expect(thrown.name).toBe("UnsupportedSchemaError");
    expect(thrown.message).toContain("$ref");
    expect(thrown.message).toContain("t.json");
  });

  it("sch-10 메타데이터 키(x-* · $comment · deprecated · readOnly · writeOnly · default · examples)는 허용되고, examples · default의 값 안은 훑지 않는다", () => {
    const head = structuredClone(SMALL);
    head["x-owner"] = "identity-admin";
    head.$comment = "메타데이터만 더한다";
    head.examples = [{ anyOf: "examples 값 안은 훑지 않는다", $ref: "#" }];
    head.properties.x.deprecated = true;
    head.properties.x.readOnly = true;
    head.properties.x.default = { prefixItems: [] };
    head.properties.x.title = "x";
    head.properties.x.description = "설명";
    head.properties.n.writeOnly = false;
    head.properties.n.examples = [1, 2];
    expect(diffSchema(structuredClone(SMALL), head)).toEqual([]);
  });

  it("sch-11 const는 값 하나짜리 enum이다 — 값이 바뀌면 enum-removed(옛 값) · 같거나 키가 사라지면(확대) 위반 아님", () => {
    const envelope = readRealSchema("_envelope.json");
    const changed = structuredClone(envelope);
    changed.properties.specversion.const = "1.1";
    const violations = diffSchema(envelope, changed, { file: "_envelope.json" });
    expect(violations).toHaveLength(1);
    expect(violations[0]).toMatchObject({ file: "_envelope.json", kind: "enum-removed", path: "#/properties/specversion" });
    expect(violations[0].message).toContain('"1.0"');

    const removed = structuredClone(envelope);
    delete removed.properties.specversion.const;
    expect(diffSchema(envelope, removed)).toEqual([]);
    expect(diffSchema(envelope, structuredClone(envelope))).toEqual([]);

    // enum → const로 좁히면 빠진 값이 enum-removed · const → enum으로 넓히면 위반 아님
    const wide = { type: "object", properties: { r: { type: "string", enum: ["a", "b"] } } };
    const narrow = { type: "object", properties: { r: { type: "string", const: "a" } } };
    const narrowed = diffSchema(wide, narrow);
    expect(narrowed).toHaveLength(1);
    expect(narrowed[0]).toMatchObject({ kind: "enum-removed", path: "#/properties/r" });
    expect(narrowed[0].message).toContain('"b"');
    expect(diffSchema(narrow, wide)).toEqual([]);
  });

  it("sch-12 diffSchema 경로는 RFC 6901로 이스케이프한다(~ → ~0 · / → ~1 — 중첩 · required 포함)", () => {
    const base = {
      type: "object",
      properties: {
        "a/b": { type: "string" },
        "m~n": { type: "string" },
        "p/q": {
          type: "object",
          properties: { "r~s": { type: "integer" } },
          required: [],
        },
      },
    };
    const head = structuredClone(base);
    delete head.properties["a/b"];
    delete head.properties["m~n"];
    head.properties["p/q"].properties["r~s"].type = "string";
    head.properties["p/q"].required.push("r~s");
    const violations = diffSchema(base, head);
    expect(violations.map((violation) => `${violation.kind} ${violation.path}`).sort()).toEqual([
      "field-removed #/properties/a~1b",
      "field-removed #/properties/m~0n",
      "required-added #/properties/p~1q/required",
      "type-changed #/properties/p~1q/properties/r~0s",
    ]);
  });

  it("sch-12 validateEvent 오류 경로도 같은 이스케이프(필수 누락 · 타입 위반)", () => {
    const dir = writeSchemas(makeTempDir(), {
      "_envelope.json": readRealSchema("_envelope.json"),
      "sample.escape.event.json": {
        $schema: DRAFT_2020_12,
        $id: "https://joshuatech.dev/events/sample.escape.event/v1",
        type: "object",
        properties: { "a/b": { type: "string" }, "m~n": { type: "integer" } },
        required: ["a/b"],
      },
    });
    const envelope = { ...structuredClone(SAMPLE_ENVELOPE), type: "sample.escape.event", data: { "m~n": "x" } };
    const result = validate(envelope, { schemasDir: dir });
    expect(result.ok).toBe(false);
    expect(errorPaths(result)).toEqual(["#/data/a~1b", "#/data/m~0n"]);
  });

  it("sch-13 type이 schemasDir 밖이나 하위 디렉터리를 가리키면 봉투 pattern이 없어도 거부한다(심층 방어 — #/type)", () => {
    // root/evil.json · root/schemas/nested/inner.topic.event.json = 무엇이든 통과시키는 스키마 {}
    const root = makeTempDir();
    const schemasDir = makeSubDir(root, "schemas");
    const loose = readRealSchema("_envelope.json");
    delete loose.properties.type.pattern; // 1차 방어(봉투 pattern)를 뺀 사본
    writeSchemas(schemasDir, { "_envelope.json": loose, "sample.topic.event.json": {} });
    writeSchemas(root, { "evil.json": {} });
    writeSchemas(makeSubDir(schemasDir, "nested"), { "inner.topic.event.json": {} });

    for (const type of ["../evil", "..\\evil", "nested/inner.topic.event", "nested\\inner.topic.event"]) {
      const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), type }, { schemasDir });
      expect(result.ok, type).toBe(false);
      expect(errorPaths(result), `${type}: ${JSON.stringify(result.errors)}`).toEqual(["#/type"]);
    }

    // 대조: schemasDir 바로 아래의 파일은 읽는다(같은 느슨한 봉투)
    const control = validate({ ...structuredClone(SAMPLE_ENVELOPE), type: "sample.topic.event" }, { schemasDir });
    expect(control.errors).toEqual([]);
  });

  it("sch-14 실제 schemas/는 검사기가 다루는 키만 쓴다 — 자기 자신과 비교 0 · 빈 기준 대비 전부 added · 전부 지우면 schema-removed 7", () => {
    const empty = makeTempDir();
    expect(compareDirectories(SCHEMAS_DIR, SCHEMAS_DIR)).toEqual({ violations: [], added: [], checked: FILES.length });

    const bootstrap = compareDirectories(empty, SCHEMAS_DIR);
    expect(bootstrap.violations).toEqual([]);
    expect(bootstrap.added).toEqual([...FILES].sort());
    expect(bootstrap.checked).toBe(0);

    const removedAll = compareDirectories(SCHEMAS_DIR, empty);
    expect(removedAll.violations.map((violation) => `${violation.file} ${violation.path} ${violation.kind}`)).toEqual(
      [...FILES].sort().map((name) => `${name} # schema-removed`),
    );
  });

  it("sch-14 CLI — 실제 schemas/를 자기 자신과 비교하면 exit 0 · stdout 비어 있음", { timeout: 60_000 }, () => {
    const result = runCli(SCRIPT, ["--base", SCHEMAS_DIR, "--head", SCHEMAS_DIR]);
    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout).toBe("");
    expect(result.stderr).toContain(`checked ${FILES.length}`);
  });

  // r5(리뷰 r4 B4-1): 머지 뒤 게이트는 기준 커밋의 검사기 blob을 작업 디렉터리(패키지 밖 · node_modules 없음)에 꺼내 실제 스키마에 돌린다.
  // 위 사례(패키지 안 SCRIPT)는 createRequire가 패키지의 node_modules에서 ajv를 찾고, sch-9 · sch-21(패키지 밖 사본)은 작은 합성 스키마
  // (SMALL — pattern · format 등 없음)뿐이라, 실제 스키마에만 있는 키워드를 만날 때 CLI 경로에서 ajv를 부르는 변경을 놓친다(머지 뒤
  // MODULE_NOT_FOUND → 요약 줄 0 → 게이트 2 — 되돌리는 PR까지 막히는 교착). 이 사례가 그 조합을 그대로 돌린다.
  // r6(리뷰 r5 R5-1): 사본은 NODE_PATH · NODE_OPTIONS를 지운 env로 돈다(runCopy) — CI 명령의 pnpm vitest shim이 넣는 NODE_PATH를 물려주면
  // 사본이 ajv를 찾아 이 조건이 아니게 된다(전제는 sch-24).
  it("sch-14 CLI — 패키지 밖 사본(node_modules 없음 · NODE_PATH · NODE_OPTIONS 없는 env)으로 실제 schemas/를 자기 자신 · 빈 기준과 비교하면 exit 0 · stdout 비어 있음 · stderr의 요약 줄이 정확히 하나(checked 7 · added 0 / checked 0 · added 7 · violations 0 — 머지 뒤 게이트가 기준 쪽 사본을 돌리는 조건)", { timeout: 60_000 }, () => {
    const root = makeTempDir();
    const copy = copyChecker(root);
    const empty = makeSubDir(root, "empty");
    for (const [label, baseDir, summary] of [
      ["자기 비교", SCHEMAS_DIR, `check-compat: checked ${FILES.length} · added 0 · violations 0`],
      ["빈 기준 → 실제 스키마", empty, `check-compat: checked 0 · added ${FILES.length} · violations 0`],
    ]) {
      const result = runCopy(copy, ["--base", baseDir, "--head", SCHEMAS_DIR]);
      expect(result.error, label).toBeUndefined();
      expect(result.status, `${label}: ${result.stderr}`).toBe(0);
      expect(result.stdout, label).toBe("");
      const summaries = result.stderr.split(/\r?\n/).filter((line) => line.startsWith("check-compat: checked"));
      expect(summaries, `${label}: ${result.stderr}`).toEqual([summary]);
    }
  });

  it("sch-15 ajv strict 모드로 7개 파일을 새로 컴파일해도 콘솔 출력(경고 · 오류)이 없다", () => {
    const dir = copyRealSchemas(makeTempDir());
    const methods = ["warn", "error", "log", "info", "debug"];
    const spies = methods.map((method) => vi.spyOn(console, method).mockImplementation(() => {}));
    let counts;
    try {
      for (const topic of TOPICS) {
        const result = validateEvent(envelopeFor(topic), { schemasDir: dir });
        expect(result.errors, topic).toEqual([]);
      }
    } finally {
      counts = Object.fromEntries(methods.map((method, index) => [method, spies[index].mock.calls.length]));
      for (const spy of spies) spy.mockRestore();
    }
    expect(counts).toEqual({ warn: 0, error: 0, log: 0, info: 0, debug: 0 });
  });

  it.each([[null], [[]], ["envelope"], [42]])("sch-16 객체가 아닌 봉투(%j)는 예외 없이 ok false(#)", (value) => {
    const result = validate(value);
    expect(result.ok).toBe(false);
    expect(errorPaths(result)).toEqual(["#"]);
  });

  it("sch-16 type이 문자열이 아니면 data를 검증하지 않는다(#/type 오류만 — schema-missing 없음)", () => {
    const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), type: 42 });
    expect(result.ok).toBe(false);
    expect(errorPaths(result)).toEqual(["#/type"]);
    expect(result.errors.some((error) => error.message.includes("schema-missing"))).toBe(false);
  });

  it("sch-17 속성 이름에 줄바꿈이 있어도 위반 하나 = 한 줄이고 줄 머리에 워크플로 명령(::)이 생기지 않는다", { timeout: 60_000 }, () => {
    const name = "a\n::warning::injected";
    const base = { type: "object", properties: { [name]: { type: "string" } } };
    const head = { type: "object", properties: {} };
    const violations = diffSchema(base, head);
    expect(violations).toHaveLength(1);
    expect(violations[0].kind).toBe("field-removed");
    expect(violations[0].message).not.toMatch(/[\r\n]/);

    const root = makeTempDir();
    const baseDir = writeSchemas(makeSubDir(root, "base"), { "s.json": base });
    const headDir = writeSchemas(makeSubDir(root, "head"), { "s.json": head });
    const result = runCli(SCRIPT, ["--base", baseDir, "--head", headDir]);
    expect(result.status, result.stderr).toBe(1);
    const lines = result.stdout.split(/\r?\n/).filter((line) => line !== "");
    expect(lines).toHaveLength(1);
    expect(lines[0].startsWith("s.json #/properties/a"), result.stdout).toBe(true);
    expect([...lines, ...result.stderr.split(/\r?\n/)].filter((line) => line.startsWith("::"))).toEqual([]);
  });

  // [위치, head 변경, 예외 경로] — additionalProperties: false는 계약이 금지한다(열린 스키마). 기준 쪽 검사기가 이 규칙을 강제한다:
  // PR이 T064 compat-15(실제 파일 단언)를 지워도 기준 커밋의 검사기가 2로 막는다.
  const CLOSED = [
    ["루트", (s) => { s.additionalProperties = false; }, "#/additionalProperties"],
    ["기존 속성(객체로 바꾼 x — 타입 변경보다 먼저 거부)", (s) => { s.properties.x = { type: "object", additionalProperties: false }; }, "#/properties/x/additionalProperties"],
    ["새 객체 속성 안", (s) => { s.properties.obj = { type: "object", properties: { k: { type: "string" } }, additionalProperties: false }; }, "#/properties/obj/additionalProperties"],
    ["items 안", (s) => { s.properties.list = { type: "array", items: { type: "object", additionalProperties: false } }; }, "#/properties/list/items/additionalProperties"],
    ["additionalProperties 스키마 안", (s) => { s.additionalProperties = { type: "object", additionalProperties: false }; }, "#/additionalProperties/additionalProperties"],
  ];
  it.each(CLOSED)("sch-18 additionalProperties: false(%s) → UnsupportedSchemaError(head에만 · base에만 모두 — 경로 포함)", (_label, mutate, pointer) => {
    const closed = structuredClone(SMALL);
    mutate(closed);
    for (const [base, head] of [[structuredClone(SMALL), closed], [closed, structuredClone(SMALL)]]) {
      let thrown;
      try {
        diffSchema(base, head);
      } catch (error) {
        thrown = error;
      }
      expect(thrown, "예외가 나지 않았다").toBeInstanceOf(Error);
      expect(thrown.name, thrown.message).toBe("UnsupportedSchemaError");
      expect(thrown.message).toContain("additionalProperties: false");
      expect(thrown.path).toBe(pointer);
    }
  });

  it("sch-18 additionalProperties: false는 새 파일(added) · 지운 파일(removed)에서도 compareDirectories가 거부하고 CLI는 2로 끝난다", { timeout: 60_000 }, () => {
    const closed = structuredClone(SMALL);
    closed.properties.obj = { type: "object", additionalProperties: false };
    const root = makeTempDir();
    const onlySmall = writeSchemas(makeSubDir(root, "small"), { "s.json": SMALL });
    const withClosed = writeSchemas(makeSubDir(root, "closed"), { "s.json": SMALL, "t.json": closed });
    for (const [label, baseDir, headDir] of [["added", onlySmall, withClosed], ["removed", withClosed, onlySmall]]) {
      let thrown;
      try {
        compareDirectories(baseDir, headDir);
      } catch (error) {
        thrown = error;
      }
      expect(thrown, `${label}: 예외가 나지 않았다`).toBeInstanceOf(Error);
      expect(thrown.name, label).toBe("UnsupportedSchemaError");
      expect(thrown.message, label).toContain("t.json");
      expect(thrown.message, label).toContain("additionalProperties: false");

      const cli = runCli(SCRIPT, ["--base", baseDir, "--head", headDir]);
      expect(cli.status, `${label}: ${cli.stderr}`).toBe(2);
      expect(cli.stderr, label).toContain("additionalProperties: false");
      expect(cli.stdout, label).not.toMatch(new RegExp(KINDS.join("|")));
    }
  });

  it("sch-18 additionalProperties: true는 허용된다(없음과 같다 — 예외 없음 · 위반 0 · 루트와 중첩 모두)", () => {
    const open = structuredClone(SMALL);
    open.additionalProperties = true;
    open.properties.obj = { type: "object", additionalProperties: true };
    const base = structuredClone(SMALL);
    base.properties.obj = { type: "object" };
    expect(diffSchema(base, open)).toEqual([]);
    expect(diffSchema(open, base)).toEqual([]);
  });

  it("sch-19 제한이 없던 속성에 enum · const를 새로 두면 enum-removed(허용 값 제한 신설 — 그 노드 경로 · message에 값) · 키를 통째로 지우면(확대) 위반 아님", () => {
    const base = {
      type: "object",
      properties: {
        reason: { type: "string" },
        list: { type: "array", items: { type: "object", properties: { k: { type: "string" } } } },
      },
    };
    const cases = [
      ["enum 신설", (s) => { s.properties.reason.enum = ["a", "b"]; }, "#/properties/reason", ['"a"', '"b"']],
      ["const 신설", (s) => { s.properties.reason.const = "a"; }, "#/properties/reason", ['"a"']],
      ["items 안 중첩 enum 신설", (s) => { s.properties.list.items.properties.k.enum = ["x"]; }, "#/properties/list/items/properties/k", ['"x"']],
      ["items 자체에 const 신설", (s) => { s.properties.list.items.const = { k: "x" }; }, "#/properties/list/items", ['"k"']],
    ];
    for (const [label, mutate, pointer, values] of cases) {
      const head = structuredClone(base);
      mutate(head);
      const violations = diffSchema(base, head);
      expect(violations, label).toHaveLength(1);
      expect(violations[0], label).toMatchObject({ kind: "enum-removed", path: pointer });
      expect(violations[0].message, label).toContain("허용 값 제한 신설");
      for (const value of values) expect(violations[0].message, label).toContain(value);
      // 반대 방향(제한을 통째로 지움 = 허용 값 확대)은 위반이 아니다
      expect(diffSchema(head, base), `${label}(확대)`).toEqual([]);
    }
  });

  it("sch-20 x-* 메타데이터 키(x-version 밖)가 루트 · 중첩 속성에 있어도 validateEvent는 예외 · 콘솔 출력 없이 검증한다(ajv strict — 컴파일 전에 등록)", () => {
    const dir = writeSchemas(makeTempDir(), {
      "_envelope.json": readRealSchema("_envelope.json"),
      "sample.meta.event.json": {
        $schema: DRAFT_2020_12,
        $id: "https://joshuatech.dev/events/sample.meta.event/v1",
        "x-version": "1.0.0",
        "x-owner": "identity-admin",
        title: "sample.meta.event",
        type: "object",
        properties: {
          n: { type: "integer", "x-unit": "seconds" },
          obj: { type: "object", "x-owner": "media", properties: { k: { type: "string", "x-pii": false } } },
        },
        required: ["n"],
      },
    });
    const methods = ["warn", "error", "log", "info", "debug"];
    const spies = methods.map((method) => vi.spyOn(console, method).mockImplementation(() => {}));
    let counts;
    let good;
    let bad;
    try {
      good = validate({ ...structuredClone(SAMPLE_ENVELOPE), type: "sample.meta.event", data: { n: 1, obj: { k: "v" } } }, { schemasDir: dir });
      bad = validate({ ...structuredClone(SAMPLE_ENVELOPE), type: "sample.meta.event", data: { n: "1", obj: { k: 2 } } }, { schemasDir: dir });
    } finally {
      counts = Object.fromEntries(methods.map((method, index) => [method, spies[index].mock.calls.length]));
      for (const spy of spies) spy.mockRestore();
    }
    expect(good.errors).toEqual([]);
    expect(bad.ok).toBe(false);
    expect(errorPaths(bad)).toEqual(["#/data/n", "#/data/obj/k"]);
    expect(counts).toEqual({ warn: 0, error: 0, log: 0, info: 0, debug: 0 });
    // 같은 키가 diffSchema에서도 메타데이터다(위반 0)
    const schema = JSON.parse(fs.readFileSync(path.join(dir, "sample.meta.event.json"), "utf8"));
    const stripped = structuredClone(schema);
    delete stripped["x-owner"];
    delete stripped.properties.n["x-unit"];
    expect(diffSchema(stripped, schema)).toEqual([]);
  });

  // r3 ② — 꼴 밖의 x- 스키마 키: 점 · 대문자 · 빈 꼬리 · 밑줄(ajv 키워드 이름으로는 x-A · x- · x-a_b가 유효하지만 계약 꼴 밖이다)
  it.each(["x-a.b", "x-A", "x-", "x-a_b"])(
    "sch-20 꼴 밖의 x- 스키마 키 %j(루트 · 중첩 속성 · 기준 · 변경 쪽) → diffSchema가 UnsupportedSchemaError(그 노드 경로 · 꼴 문구) · CLI 2",
    { timeout: 60_000 },
    (key) => {
      for (const [where, pointer, mutate] of [
        ["루트", "#", (s) => { s[key] = "v"; }],
        ["중첩 속성", "#/properties/x", (s) => { s.properties.x[key] = "v"; }],
      ]) {
        const changed = structuredClone(SMALL);
        mutate(changed);
        for (const [side, base, head] of [["변경 쪽", structuredClone(SMALL), changed], ["기준", changed, structuredClone(SMALL)]]) {
          let thrown;
          try {
            diffSchema(base, head);
          } catch (error) {
            thrown = error;
          }
          expect(thrown, `${where} · ${side}: 예외가 나지 않았다`).toBeInstanceOf(Error);
          expect(thrown.name, thrown.message).toBe("UnsupportedSchemaError");
          expect(thrown.path, `${where} · ${side}`).toBe(pointer);
          expect(thrown.message).toContain(JSON.stringify(key));
          expect(thrown.message).toContain(X_KEY_FORM);
        }
      }
      // CLI: 변경 쪽 파일의 중첩 속성에 둔다 → 2 · stderr에 파일 · 경로 · 키 · 위반 줄 없음
      const root = makeTempDir();
      const head = structuredClone(SMALL);
      head.properties.x[key] = "v";
      const baseDir = writeSchemas(makeSubDir(root, "base"), { "s.json": SMALL });
      const headDir = writeSchemas(makeSubDir(root, "head"), { "s.json": head });
      const cli = runCli(SCRIPT, ["--base", baseDir, "--head", headDir]);
      expect(cli.status, cli.stderr).toBe(2);
      expect(cli.stderr).toContain("s.json #/properties/x");
      expect(cli.stderr).toContain(JSON.stringify(key));
      expect(cli.stdout).not.toMatch(new RegExp(KINDS.join("|")));
    },
  );

  it("sch-20 x-로 시작하는 속성 이름(x-a b · x-c.d — 키워드 이름 꼴 밖)은 스키마 키가 아니다 — diffSchema 위반 0 · validateEvent가 예외 없이 그 속성 값까지 검증한다", () => {
    const topic = {
      $schema: DRAFT_2020_12,
      $id: "https://joshuatech.dev/events/sample.prop.event/v1",
      "x-version": "1.0.0",
      title: "sample.prop.event",
      type: "object",
      properties: {
        n: { type: "integer" },
        "x-a b": { type: "string" },
        obj: { type: "object", properties: { "x-c.d": { type: "integer" } } },
      },
      required: ["n"],
    };
    const without = structuredClone(topic);
    delete without.properties["x-a b"];
    delete without.properties.obj.properties["x-c.d"];
    expect(diffSchema(without, topic)).toEqual([]);
    expect(diffSchema(topic, structuredClone(topic))).toEqual([]);

    const dir = writeSchemas(makeTempDir(), { "_envelope.json": readRealSchema("_envelope.json"), "sample.prop.event.json": topic });
    const envelope = (data) => ({ ...structuredClone(SAMPLE_ENVELOPE), type: "sample.prop.event", data });
    const good = validate(envelope({ n: 1, "x-a b": "v", obj: { "x-c.d": 2 } }), { schemasDir: dir });
    expect(good.errors).toEqual([]);
    const bad = validate(envelope({ n: 1, "x-a b": 2, obj: { "x-c.d": "2" } }), { schemasDir: dir });
    expect(bad.ok).toBe(false);
    expect(errorPaths(bad)).toEqual(["#/data/obj/x-c.d", "#/data/x-a b"]);
  });

  it("sch-20 examples · default · enum · const 값 안의 x- 키(키워드 이름 꼴 밖 포함)는 스키마 키가 아니다 — validateEvent가 예외 없이 검증한다", () => {
    const topic = {
      $schema: DRAFT_2020_12,
      $id: "https://joshuatech.dev/events/sample.values.event/v1",
      "x-version": "1.0.0",
      title: "sample.values.event",
      type: "object",
      examples: [{ n: 1, "x-a b": 1, "x-c.d": { "x-é": true } }],
      properties: {
        n: { type: "integer" },
        obj: { type: "object", default: { "x-a b": 1, "x-e/f": [{ "x-g h": 1 }] }, properties: { k: { type: "string" } } },
        pick: { type: "object", enum: [{ "x-a b": 1 }, { "x-c.d": 2 }] },
        fixed: { type: "object", const: { "x-e f": true } },
      },
      required: ["n"],
    };
    expect(diffSchema(topic, structuredClone(topic))).toEqual([]);

    const dir = writeSchemas(makeTempDir(), { "_envelope.json": readRealSchema("_envelope.json"), "sample.values.event.json": topic });
    const envelope = (data) => ({ ...structuredClone(SAMPLE_ENVELOPE), type: "sample.values.event", data });
    const good = validate(envelope({ n: 1, obj: { k: "v" }, pick: { "x-a b": 1 }, fixed: { "x-e f": true } }), { schemasDir: dir });
    expect(good.errors).toEqual([]);
    const bad = validate(envelope({ n: "1", obj: { k: 2 }, pick: { "x-a b": 2 }, fixed: { "x-e f": false } }), { schemasDir: dir });
    expect(bad.ok).toBe(false);
    expect(errorPaths(bad)).toEqual(["#/data/fixed", "#/data/n", "#/data/obj/k", "#/data/pick"]);
  });

  it("sch-20 꼴 밖의 x- 스키마 키(x-A — ajv 키워드 이름으로는 유효)는 validateEvent도 키워드로 등록하지 않는다 — 컴파일이 strict 예외로 끝난다(검사기 CLI가 2로 막는 스키마와 같은 규칙)", () => {
    const topic = {
      $schema: DRAFT_2020_12,
      $id: "https://joshuatech.dev/events/sample.badkey.event/v1",
      "x-version": "1.0.0",
      title: "sample.badkey.event",
      type: "object",
      properties: { n: { type: "integer", "x-A": "v" } },
      required: ["n"],
    };
    const dir = writeSchemas(makeTempDir(), { "_envelope.json": readRealSchema("_envelope.json"), "sample.badkey.event.json": topic });
    const envelope = { ...structuredClone(SAMPLE_ENVELOPE), type: "sample.badkey.event", data: { n: 1 } };
    expect(() => validateEvent(envelope, { schemasDir: dir })).toThrow(/x-A/);
  });

  // r4 ⑥(리뷰 r3 A3-1) — 등록 순회의 items · additionalProperties 갈래: x-unit은 items 스키마 안에만, x-pii는 스키마인
  // additionalProperties 안에만 둔다(이 디렉터리의 다른 위치 · _envelope.json에는 없다 — 그 갈래가 아니면 어디서도 등록되지 않아
  // 컴파일이 strict 예외로 끝난다)
  it("sch-20 items 스키마 · 스키마인 additionalProperties 안의 x-* 키(꼴 안 — 그 위치에만 있다)도 validateEvent가 컴파일 전에 등록한다 — 예외 · 콘솔 출력 없이 그 위치의 값까지 검증하고 diffSchema(같은 스키마) = []", () => {
    const topic = {
      $schema: DRAFT_2020_12,
      $id: "https://joshuatech.dev/events/sample.nested.event/v1",
      "x-version": "1.0.0",
      title: "sample.nested.event",
      type: "object",
      properties: {
        n: { type: "integer" },
        list: { type: "array", items: { type: "integer", "x-unit": "seconds" } },
        map: { type: "object", additionalProperties: { type: "string", "x-pii": true } },
      },
      required: ["n"],
    };
    expect(diffSchema(topic, structuredClone(topic))).toEqual([]);

    const dir = writeSchemas(makeTempDir(), { "_envelope.json": readRealSchema("_envelope.json"), "sample.nested.event.json": topic });
    const envelope = (data) => ({ ...structuredClone(SAMPLE_ENVELOPE), type: "sample.nested.event", data });
    const methods = ["warn", "error", "log", "info", "debug"];
    const spies = methods.map((method) => vi.spyOn(console, method).mockImplementation(() => {}));
    let counts;
    let good;
    let bad;
    try {
      good = validate(envelope({ n: 1, list: [1, 2], map: { k: "v" } }), { schemasDir: dir });
      bad = validate(envelope({ n: 1, list: ["1"], map: { k: 2 } }), { schemasDir: dir });
    } finally {
      counts = Object.fromEntries(methods.map((method, index) => [method, spies[index].mock.calls.length]));
      for (const spy of spies) spy.mockRestore();
    }
    expect(good).toEqual({ ok: true, errors: [] });
    expect(bad.ok).toBe(false);
    expect(bad.errors.map((error) => error.path).sort()).toEqual(["#/data/list/0", "#/data/map/k"]);
    expect(counts).toEqual({ warn: 0, error: 0, log: 0, info: 0, debug: 0 });
  });

  it("sch-21 CLI 요약 줄(고정 계약 — events-compat.sh가 읽는다)은 exit 0 · 1 모두 stderr에 정확히 한 줄이고 violations = stdout 위반 줄 수다(패키지 밖 사본 · NODE_PATH · NODE_OPTIONS 없는 env)", { timeout: 60_000 }, () => {
    const root = makeTempDir();
    const copy = copyChecker(root);
    const breaking = structuredClone(SMALL);
    delete breaking.properties.x;
    breaking.properties.n.type = "string";
    const baseDir = writeSchemas(makeSubDir(root, "base"), { "s.json": SMALL });
    const sameDir = writeSchemas(makeSubDir(root, "same"), { "s.json": SMALL, "added.json": SMALL });
    const brokenDir = writeSchemas(makeSubDir(root, "broken"), { "s.json": breaking });
    for (const [label, headDir, status, violations] of [["exit 0(added 포함)", sameDir, 0, 0], ["exit 1", brokenDir, 1, 2]]) {
      const result = runCopy(copy, ["--base", baseDir, "--head", headDir]);
      expect(result.status, `${label}: ${result.stderr}`).toBe(status);
      const summaries = result.stderr.split(/\r?\n/).filter((line) => line.startsWith("check-compat: checked"));
      expect(summaries, label).toHaveLength(1);
      const match = SUMMARY_RE.exec(summaries[0]);
      expect(match, `${label}: ${summaries[0]}`).not.toBeNull();
      expect(Number(match[1]), label).toBe(violations);
      expect(result.stdout.split(/\r?\n/).filter((line) => line !== ""), label).toHaveLength(violations);
    }
  });

  it("sch-22 스키마 디렉터리의 .json이 일반 파일이 아니면(디렉터리) compareDirectories가 예외를 던지고 CLI는 2로 끝난다(기준 · 변경 쪽 모두)", { timeout: 60_000 }, () => {
    const root = makeTempDir();
    const plain = writeSchemas(makeSubDir(root, "plain"), { "s.json": SMALL });
    const withDir = writeSchemas(makeSubDir(root, "with-dir"), { "s.json": SMALL });
    fs.mkdirSync(path.join(withDir, "x.json"));
    for (const [label, baseDir, headDir] of [["head", plain, withDir], ["base", withDir, plain]]) {
      expect(() => compareDirectories(baseDir, headDir), label).toThrow(/x\.json/);
      const cli = runCli(SCRIPT, ["--base", baseDir, "--head", headDir]);
      expect(cli.status, `${label}: ${cli.stderr}`).toBe(2);
      expect(cli.stderr, label).toContain("x.json");
    }
  });
});

// 왜 패키지 시험이 ci.yml을 읽는가(계약 「Node 설치는 체크아웃 전」 · T067 r5 · 리뷰 r4 B4-2): 게이트 job events-compat은 setup-node를
// 체크아웃 전에 돌리므로 Node 버전을 .node-version에서 읽지 않고 ci.yml의 고정값(node-version)으로 준다. 게이트 job은 PR 내용을 읽지
// 않으니 두 값의 드리프트를 CI에서 막을 곳은 PR 코드를 도는 job events-test(이 vitest)뿐이다 — 로컬에서는 하네스
// tests/scripts/events-compat.tests.ps1 st-5 · st-15가 같은 것을 본다. 둘이 갈라진 채 검사기가 .node-version 쪽(새) Node에만 있는 API를
// 쓰면 events-test는 초록인 채 머지되고, 그 뒤 게이트가 기준 쪽 검사기를 ci.yml의 옛 Node로 돌려 적재 · 실행이 실패한다(요약 줄 0 →
// 2) — 되돌리는 PR까지 막히는 교착(계약 「한계」).
// r6(리뷰 r5 R5-3): 값만이 아니라 자리도 본다 — 핀이 setup-node 스텝의 with: 아래에 있어야 setup-node가 그 판을 설치한다. 같은 job의 다른
// 스텝(checkout의 with: · 게이트 스텝의 env:)으로 옮긴 핀은 버전 입력이 아니다(러너 기본 Node) — 하네스 st-5는 로컬에서만 돈다.
// r7(리뷰 r6 R6-1): r6 결속은 「- uses: actions/setup-node@」 꼴 스텝 하나의 with:만 봐서, 꼴이 다른 둘째 setup-node 스텝(name-first ·
// 따옴표 · 대소문자 · 흐름 매핑)과 그 스텝의 node-version · node-version-file이 보이지 않았다 — 뒤에 도는 setup-node가 PATH 앞에 제 Node를
// 놓으므로 게이트는 그 판으로 돈다. 그래서 job 블록 전체에서 setup-node를 가리키는 줄 · node-version · node-version-file 키 줄을 꼴과
// 상관없이 센다. env: 아래에 들여쓴 with:는 setup-node의 입력이 아니다(with:는 스텝 키 깊이에서만). 0칸 주석 · 홀로 선 CR 뒤에 둔 스텝도
// YAML에서는 같은 job의 스텝이다. 키 줄 수 대조는 그 블록 안에서만 센다(다른 job의 node-version 줄은 이 시험과 무관하다).
// r8(리뷰 r7 R7-1 · R7-2 · 지시문 F39 · 계약 r8): 이 시험은 줄 단위 드리프트 검사다 — 「꼴과 상관없이」는 앞의 "- " 유무 · 따옴표 · 대소문자 ·
// 흐름 매핑 꼴이고, YAML 이어짐 줄 · 이스케이프 · 별칭 · 가짜 job 블록처럼 ci.yml을 일부러 꼬아 쓰는 편집은 범위 밖이다(코드 소유자 리뷰).
// 다만 원문의 NEL · LS · PS는 불일치로 본다 — 주석 안 LS 뒤에 0칸 글자를 두면 그 글자에서 나눈 블록이 앞당겨 끝나 뒤 스텝이 보이지 않았다(⑨).
describe("CI 게이트 job — Node 고정값 = .node-version(sch-23)", () => {
  it("sch-23 job events-compat에 대시 꼴 setup-node 스텝이 정확히 하나이고 그 스텝 키 깊이의 with: 아래 node-version 줄이 정확히 하나 · 값은 작은따옴표 문자열 · 저장소 .node-version 내용(끝 줄바꿈 하나 제외)과 같다 — job 블록 전체(주석 줄 제외 · YAML 줄바꿈 · 주석은 경계가 아니다)에서 setup-node를 가리키는 줄은 그 스텝 머리 하나(꼴 무관) · node-version 키 줄은 그 핀 하나 · node-version-file 키 줄은 0(음성 대조: 같은 ci.yml에서 값 · 따옴표 · 줄 수 · 키 · 자리(checkout의 with: · 게이트 스텝의 env: · setup-node 스텝 안 env: 아래 with:) · setup-node 스텝 수 · 꼴이 다른 둘째 setup-node 스텝(name-first · 따옴표 · 대소문자 · 흐름 매핑 · 0칸 주석 뒤 · 홀로 선 CR 뒤) · ci.yml 원문의 NEL · LS · PS(주석 안 LS 뒤 0칸 글자)만 바꾸면 불일치 · 양성 대조: with: 안에서 순서만 · 다른 job의 node-version 줄 · job 안 0칸 주석이면 일치 — 줄 단위 드리프트 검사)", () => {
    const ciText = fs.readFileSync(CI_WORKFLOW, "utf8");
    const nodeVersion = fs.readFileSync(NODE_VERSION_FILE, "utf8").replace(/\r?\n$/, "");
    expect(nodeVersion, ".node-version 내용").toMatch(/^[^'\s]+$/);
    const actual = gateNodePin(ciText, nodeVersion);
    expect(actual.problems).toEqual([]);
    expect(actual.line).toBeGreaterThan(0);

    // 음성 대조 — 실제 ci.yml 글에서 그 키 줄만 바꿔 같은 함수에 넣는다(시험이 공허하지 않다)
    const lines = yamlLines(ciText);
    const pinLine = lines[actual.line];
    const withPin = (...replacement) => [...lines.slice(0, actual.line), ...replacement, ...lines.slice(actual.line + 1)].join("\n");
    const other = nodeVersion === "22" ? "20" : "22";
    const cases = [
      ["다른 값", withPin(pinLine.replace(`'${nodeVersion}'`, `'${other}'`)), [`node-version '${other}' ≠ .node-version ${JSON.stringify(nodeVersion)}`]],
      ["큰따옴표", withPin(pinLine.replace(`'${nodeVersion}'`, `"${nodeVersion}"`)), [`node-version 값 "${nodeVersion}"가 작은따옴표 문자열이 아니다`]],
      ["두 줄", withPin(pinLine, pinLine), ["setup-node with: 아래 node-version 줄 2개(정확히 1개여야 한다)"]],
      [
        "node-version-file",
        withPin(pinLine.replace(/node-version:.*$/, "node-version-file: '.node-version'")),
        [
          "setup-node with: 아래 node-version 줄 0개(정확히 1개여야 한다)",
          "setup-node with: 아래 node-version-file 줄 1개(없어야 한다 — 체크아웃 전이라 읽을 파일이 없다)",
        ],
      ],
    ];
    for (const [label, text, problems] of cases) {
      expect(text, label).not.toBe(ciText);
      expect(gateNodePin(text, nodeVersion).problems, label).toEqual(problems);
    }

    // r6(리뷰 r5 R5-3) 자리 대조 — 핀 줄을 빼고 같은 job의 다른 자리에 그대로 넣는다. 옮긴 글에도 node-version 키 줄은 하나 그대로 있다
    // (job 블록 전체에서 센 수만 보면 일치로 보인다 — r5 함수가 놓친 꼴). 양성 대조: setup-node의 with: 안에서 순서만 바꾸면 일치다.
    const without = [...lines.slice(0, actual.line), ...lines.slice(actual.line + 1)];
    const after = (from, pattern) => without.findIndex((line, index) => index >= from && pattern.test(line));
    const cacheLine = after(actual.line, /^\s*package-manager-cache:\s*false\s*$/);
    const checkoutStep = after(actual.line, /^\s*-\s+uses:\s*actions\/checkout@/);
    const checkoutWith = after(checkoutStep, /^\s*with:\s*$/);
    const gateEnv = after(checkoutWith, /^\s*env:\s*$/);
    expect([cacheLine, checkoutStep, checkoutWith, gateEnv].every((index) => index >= actual.line), "자리 대조의 기준 줄을 찾지 못했다").toBe(true);
    expect(cacheLine < checkoutStep && checkoutStep < checkoutWith && checkoutWith < gateEnv, "자리 대조의 기준 줄 순서").toBe(true);
    const insertAfter = (at) => [...without.slice(0, at + 1), pinLine, ...without.slice(at + 1)].join("\n");
    // r7 (e): 키 줄 수는 job events-compat 블록 안에서만 센다 — r6는 ci.yml 전체를 세어, 다른 job에 node-version 줄이 생기면 기대 수가 깨졌다
    const pinKeyLines = gateBlockPinKeyLines;
    const setupStart = lines.findLastIndex((line, index) => index < actual.line && /^\s*-\s+uses:\s*actions\/setup-node@/.test(line));
    const checkoutStart = lines.findIndex((line, index) => index > actual.line && /^\s*-\s+uses:\s*actions\/checkout@/.test(line));
    expect(setupStart >= 0 && checkoutStart > setupStart, "setup-node · checkout 스텝 머리를 찾지 못했다").toBe(true);
    const twoSetups = [...lines.slice(0, checkoutStart), ...lines.slice(setupStart, checkoutStart), ...lines.slice(checkoutStart)].join("\n");

    // r7(리뷰 r6 R6-1 · 지시문 F36 (d)) 꼴 대조 — 둘째 setup-node 스텝(같은 SHA)을 꼴만 바꿔 체크아웃 앞에 끼우거나, 핀을 setup-node 스텝
    // 안 env: 아래 with:로 옮긴다. r6 함수는 이 꼴을 모두 일치([])로 봤다. 양성 대조: 다른 job의 node-version 줄 · job 안 0칸 주석.
    const setupHead = lines[setupStart];
    const sha = /actions\/setup-node@([0-9a-f]{40})/.exec(setupHead)?.[1] ?? "";
    expect(sha, "setup-node 액션 SHA").toMatch(/^[0-9a-f]{40}$/);
    const padOf = (line) => " ".repeat(line.length - line.trimStart().length);
    const dashPad = padOf(setupHead);
    const keyPad = " ".repeat(/^(\s*-\s+)uses:/.exec(setupHead)[1].length);
    const childPad = padOf(pinLine);
    const CR = String.fromCodePoint(13);
    const beforeCheckout = (...inserted) => [...lines.slice(0, checkoutStart), ...inserted, ...lines.slice(checkoutStart)].join("\n");
    const secondStep = (head, input) => [head, `${keyPad}with:`, `${childPad}${input}`];
    const pinUnderEnv = [...without.slice(0, setupStart + 1), `${keyPad}env:`, `${childPad}with:`, `${childPad}  ${pinLine.trim()}`, ...without.slice(setupStart + 1)].join("\n");
    const cacheAt = lines.findIndex((line, index) => index > actual.line && /^\s*package-manager-cache:\s*false\s*$/.test(line));
    const crHidden = lines.map((line, index) => (index === cacheAt ? [line, ...secondStep(`${dashPad}- uses: actions/setup-node@${sha}`, `node-version: '${other}'`)].join(CR) : line)).join("\n");
    const otherJobLines = lines.map((line) => line.replace(/^(\s*)node-version-file: '\.node-version'$/, `$1node-version: '${other}'`));
    expect(otherJobLines.filter((line) => /^\s*node-version\s*:/.test(line)).length, "다른 job에 node-version 줄을 만들었다(ci.yml 전체에서 세면 1보다 많다)").toBeGreaterThan(1);
    const commentBeforeSetup = [...lines.slice(0, setupStart), "# 0칸 주석 — YAML에서 주석은 매핑을 끝내지 않는다", ...lines.slice(setupStart)].join("\n");
    // r8(리뷰 r7 R7-1 표 첫 줄 · 지시문 F39): 주석 줄 안 LS 뒤의 0칸 글자 「x: y」 — yamlLines가 LS에서 나누면 그 조각이 2칸 이하 키 줄이 되어
    // 블록이 앞당겨 끝나고 뒤의 둘째 setup-node 스텝이 보이지 않는다(r7 함수는 []). 글자는 String.fromCodePoint로 만든다.
    const LS = String.fromCodePoint(0x2028);
    const lsHidden = beforeCheckout(`${dashPad}# note${LS}x: y`, ...secondStep(`${dashPad}- uses: actions/setup-node@${sha}`, `node-version: '${other}'`));
    const breakChars = (count) => `ci.yml에 NEL · LS · PS가 ${count}개 — 파서마다 줄바꿈 여부가 달라 블록 경계가 갈린다`;
    const steps = (count) => `setup-node 스텝 ${count}개(정확히 1개여야 한다)`;
    const refs = (count) => `setup-node를 가리키는 줄 ${count}개(꼴 무관 — 대시 꼴 스텝 머리 하나뿐이어야 한다)`;
    const underWith = (count) => `setup-node with: 아래 node-version 줄 ${count}개(정확히 1개여야 한다)`;
    const stray = (count) => `setup-node with: 밖 node-version 키 줄 ${count}개(job 블록 전체 — 핀은 setup-node with: 아래 하나뿐이어야 한다)`;
    const strayFile = (count) => `setup-node with: 밖 node-version-file 키 줄 ${count}개(job 블록 전체 — 없어야 한다)`;
    const placed = [
      ["핀을 checkout 스텝의 with:로 옮김", insertAfter(checkoutWith), 1, [underWith(0), stray(1)]],
      ["핀을 게이트 스텝의 env:로 옮김", insertAfter(gateEnv), 1, [underWith(0), stray(1)]],
      ["setup-node 스텝 둘(같은 스텝을 체크아웃 앞에 하나 더)", twoSetups, 2, [steps(2)]],
      ["양성 대조 — 핀을 setup-node with: 안 끝으로(순서만)", insertAfter(cacheLine), 1, []],
      [
        "① name-first 둘째 setup-node 스텝 + node-version",
        beforeCheckout(`${dashPad}- name: node`, ...secondStep(`${keyPad}uses: actions/setup-node@${sha}`, `node-version: '${other}'`)),
        2,
        [refs(2), stray(1)],
      ],
      [
        "② name-first 둘째 setup-node 스텝 + node-version-file",
        beforeCheckout(`${dashPad}- name: node`, ...secondStep(`${keyPad}uses: actions/setup-node@${sha}`, "node-version-file: '.node-version'")),
        1,
        [refs(2), strayFile(1)],
      ],
      [
        "③ 따옴표 꼴 둘째 setup-node 스텝 + node-version-file",
        beforeCheckout(...secondStep(`${dashPad}- uses: "actions/setup-node@${sha}"`, "node-version-file: '.node-version'")),
        1,
        [refs(2), strayFile(1)],
      ],
      [
        "④ 대소문자 꼴 둘째 setup-node 스텝 + node-version",
        beforeCheckout(...secondStep(`${dashPad}- uses: Actions/Setup-Node@${sha}`, `node-version: '${other}'`)),
        2,
        [refs(2), stray(1)],
      ],
      ["⑤ 핀을 setup-node 스텝 안 env: 아래 with:로 옮김", pinUnderEnv, 1, [underWith(0), stray(1)]],
      [
        "⑥ 흐름 매핑 꼴 둘째 setup-node 스텝 + node-version",
        beforeCheckout(`${dashPad}- { uses: actions/setup-node@${sha}, with: { node-version: '${other}' } }`),
        2,
        [refs(2), stray(1)],
      ],
      [
        "⑦ 0칸 주석 뒤 둘째 setup-node 스텝(대시 꼴) + node-version",
        beforeCheckout("# 0칸 주석 — YAML에서 주석은 매핑을 끝내지 않는다", ...secondStep(`${dashPad}- uses: actions/setup-node@${sha}`, `node-version: '${other}'`)),
        2,
        [steps(2)],
      ],
      ["⑧ 홀로 선 CR 뒤에 숨긴 둘째 setup-node 스텝 + node-version", crHidden, 2, [steps(2)]],
      ["⑨ 주석 안 LS 뒤 0칸 글자(x: y) + 둘째 setup-node 스텝(대시 꼴) + node-version — 원문의 NEL · LS · PS(r8 가드)", lsHidden, 1, [breakChars(1)]],
      ["양성 대조 — 다른 job(lint · test · events-test)의 setup-node를 node-version으로", otherJobLines.join("\n"), 1, []],
      ["양성 대조 — job 안 0칸 주석(setup-node 스텝 앞)", commentBeforeSetup, 1, []],
    ];
    // 사례마다 한 번에 모아 비교한다 — 어긋나면 모든 사례의 실제 값이 한 diff에 드러난다
    const observed = placed.map(([label, text]) => ({ label, changed: text !== ciText, keyLines: pinKeyLines(text), problems: gateNodePin(text, nodeVersion).problems }));
    expect(observed).toEqual(placed.map(([label, , keyLines, problems]) => ({ label, changed: true, keyLines, problems })));
  });
});
