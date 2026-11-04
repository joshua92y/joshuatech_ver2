// T064 (US6 · test-first) — packages/events 스키마 호환성 검사와 봉투 검증의 계약 테스트(vitest).
//
// 과제(tasks.md T064): 필드 추가 → PASS, 필드 삭제·타입 변경·required 추가 → FAIL 보고, envelope 필수 필드 검증.
//   필드 추가 → PASS = compat-1 · 2 · 3 · 13(CLI 0) / 금지 변경 → FAIL 보고 = compat-4 … 12 · 13(CLI 1)
//   / envelope 필수 필드 검증 = compat-14 · 15 · 16.
// 정본: specs/003-platform-foundation/contracts/events.md §봉투 · §SP-1 스키마 표 · §호환성 규칙(2026-11-02 T064 보정)
//   · .claude/rules/events.md §Compatibility rules · data-model §5 · ADR 0008 결정 5.
// 짝 구현: T067 — scripts/check-compat.mjs · schemas/_envelope.json · 토픽 스키마 6.
// 빨강(T067 전): 이 파일을 수집할 때 "../scripts/check-compat.mjs" 로드가 실패한다(구현 없음).
//   모듈만 생기고 스키마 파일이 없으면 실제 schemas/를 읽는 compat-14 · 15 · 16이 실패한다.
//
// 이 테스트가 고정하는 모듈 API(T067 가정 — build-notes 「T064」 D2):
//   scripts/check-compat.mjs — ESM named exports
//   · diffSchema(base, head, { file = "<memory>" } = {}) -> Violation[]
//       Violation = { file, path, kind, message }
//       path    JSON 포인터 — "#/properties/<name>" · 중첩 "#/properties/a/properties/b"
//               · 배열 "#/properties/list/items/properties/x" · required 위반은 그 스키마 포인터 + "/required"
//               (최상위 "#/required") · 파일 삭제 "#"
//       kind    field-removed · type-changed · required-added · required-removed · enum-removed · schema-removed
//       message 사람용 한 줄(required 위반은 필드 이름, enum 위반은 삭제된 값을 담는다)
//       위반이 없으면 [] · 첫 위반에서 멈추지 않고 전부 돌려준다.
//   · compareDirectories(baseDir, headDir) -> { violations, added, checked }
//       .json 파일만 본다 · base에만 있음 → schema-removed(path "#") · head에만 있음 → added(파일 이름 · 정렬)
//       · 양쪽에 있음 → diffSchema(file = 파일 이름) · checked = 양쪽 모두에 있는 파일 수
//   · validateEvent(envelope, { schemasDir } = {}) -> { ok, errors: { path, message }[] }
//       schemasDir 기본 = 패키지 schemas/ · _envelope.json으로 봉투를, schemas/<envelope.type>.json으로 data를 검증
//       · 토픽 스키마 파일이 없으면 ok: false + message에 "schema-missing"과 토픽 이름 · type으로 schemasDir 밖 파일을 읽지 않는다
//       · path = JSON 포인터("#/tenantid" · "#/data/reason" 꼴)
//   · CLI node scripts/check-compat.mjs --base <dir> --head <dir>
//       종료 코드 0 위반 없음 · 1 위반 ≥ 1(stdout에 위반마다 "<file> <path> <kind> <message>" 한 줄)
//       · 2 인자 누락 · 디렉터리 없음(stderr) · import만으로는 실행되지 않는다(진입점 가드)
//   비교 규칙: type은 집합 비교(문자열 ↔ 배열 정규화 · 어떤 변화든 type-changed) · enum 축소 = enum-removed(확대 허용)
//   · required 집합 추가/제거 = required-added/required-removed · properties · items(단일 스키마) 재귀
//   · 메타데이터(title · description · examples · x-version · $comment)는 무시한다.
// 테스트는 네트워크에 닿지 않는다(임시 디렉터리 · 자식 node 프로세스만).

import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { afterEach, describe, expect, it } from "vitest";

import { compareDirectories, diffSchema, validateEvent } from "../scripts/check-compat.mjs";

// 테스트 파일 기준 상대 경로(패키지 루트 = tests/의 부모)
const SCRIPT = fileURLToPath(new URL("../scripts/check-compat.mjs", import.meta.url));
const SCHEMAS_DIR = fileURLToPath(new URL("../schemas/", import.meta.url));

const DRAFT_2020_12 = "https://json-schema.org/draft/2020-12/schema";
const KINDS = [
  "field-removed",
  "type-changed",
  "required-added",
  "required-removed",
  "enum-removed",
  "schema-removed",
];

// 계약 §SP-1 스키마 표의 토픽 6
const TOPICS = [
  "identity-admin.session.revoked",
  "identity-admin.user.registered",
  "identity-admin.tenant.created",
  "portfolio-core.note.published",
  "engagement.comment.created",
  "media.object.ready",
];

// 계약 §봉투 · data-model §5 — 봉투 필수 필드 9
const ENVELOPE_REQUIRED = [
  "specversion",
  "id",
  "source",
  "type",
  "time",
  "subject",
  "tenantid",
  "datacontenttype",
  "data",
];

// 기준 data 스키마(토픽 data 스키마 모양 — session.revoked 필드 + media.object.ready의 variants[] 꼴). 열린 스키마다 —
// additionalProperties: false는 계약 §호환성 규칙이 금지한다(소비자는 미지 속성을 무시 · compat-15가 실제 파일에서 단언).
const BASE = {
  $schema: DRAFT_2020_12,
  $id: "https://joshuatech.dev/events/sample.topic.event/v1",
  "x-version": "1.0.0",
  title: "sample",
  type: "object",
  properties: {
    sub: { type: "string" },
    sid: { type: ["string", "null"] },
    nbf: { type: "integer" },
    reason: { enum: ["logout", "logout_all", "admin"] },
    variants: {
      type: "array",
      items: {
        type: "object",
        properties: {
          name: { type: "string" },
          url: { type: "string" },
        },
        required: ["name"],
      },
    },
  },
  required: ["sub", "nbf", "reason"],
};

// 계약 §봉투 예시 모양(T061 test_outbox.py와 같은 테넌트 · subject · data)
const SAMPLE_ENVELOPE = {
  specversion: "1.0",
  id: "01J8QK3Q9S8ZQ4V7H2M1X0N5AB",
  source: "identity-admin",
  type: "identity-admin.session.revoked",
  time: "2026-09-01T03:21:07.123Z",
  subject: "user:9f2c-test",
  tenantid: "00000000-0000-4000-8000-00000000000a",
  datacontenttype: "application/json",
  data: { sub: "9f2c-test", sid: null, nbf: 1756696867, reason: "logout_all" },
};

const tempDirs = [];

afterEach(() => {
  for (const dir of tempDirs.splice(0)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});

/** 테스트가 끝나면 afterEach가 지우는 임시 디렉터리 */
function makeTempDir() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "jt-events-"));
  tempDirs.push(dir);
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

/** 실제 schemas/의 파일을 읽어 파싱한다(T067 산출물 — 파싱 실패는 예외로 드러난다) */
function readRealSchema(name) {
  return JSON.parse(fs.readFileSync(path.join(SCHEMAS_DIR, name), "utf8"));
}

/** 위반 kind 집합 */
function kinds(violations) {
  return new Set(violations.map((violation) => violation.kind));
}

/** name이 식별자 단위로 text에 들어 있는가("tenantid" 안의 "id"는 세지 않는다 · name은 [A-Za-z0-9_]만) */
function mentions(text, name) {
  return new RegExp(`(^|[^A-Za-z0-9_])${name}([^A-Za-z0-9_]|$)`).test(text);
}

/** errors에 topic 스키마 부재(schema-missing + 토픽 이름)가 있는가 — _envelope.json 부재와 가른다 */
function schemaMissingFor(errors, topic) {
  return errors.some((error) => error.message.includes("schema-missing") && error.message.includes(topic));
}

/** 스키마 안의 모든 $ref 값 */
// 스키마 트리에서 additionalProperties: false인 위치(JSON 포인터)를 모은다 — 계약 §호환성 규칙: 토픽 data 스키마와
// _envelope.json은 열린 스키마다(소비자는 미지 속성을 무시 · 닫힌 스키마면 선택 필드 추가가 옛 소비자를 DLQ로 보낸다).
function collectClosed(node, pointer = "#", found = []) {
  if (Array.isArray(node)) {
    node.forEach((item, index) => collectClosed(item, `${pointer}/${index}`, found));
  } else if (node && typeof node === "object") {
    if (node.additionalProperties === false) found.push(pointer);
    for (const [key, value] of Object.entries(node)) {
      collectClosed(value, `${pointer}/${key}`, found);
    }
  }
  return found;
}

function collectRefs(node, refs = []) {
  if (Array.isArray(node)) {
    for (const item of node) collectRefs(item, refs);
  } else if (node !== null && typeof node === "object") {
    for (const [key, value] of Object.entries(node)) {
      if (key === "$ref" && typeof value === "string") refs.push(value);
      else collectRefs(value, refs);
    }
  }
  return refs;
}

/** Violation[] 모양(D2): file 문자열 · path JSON 포인터 · kind 6종 · message 비지 않은 한 줄 */
function expectViolationShape(violations) {
  expect(Array.isArray(violations)).toBe(true);
  for (const violation of violations) {
    expect(typeof violation.file).toBe("string");
    expect(violation.path).toMatch(/^#(\/|$)/);
    expect(KINDS).toContain(violation.kind);
    expect(typeof violation.message).toBe("string");
    expect(violation.message.trim()).not.toBe("");
    expect(violation.message).not.toMatch(/[\r\n]/);
  }
  return violations;
}

/** BASE의 깊은 복사본 쌍을 만들고 head만 mutate로 바꾼 뒤 diffSchema 결과(모양 검사 포함) */
function diffAfter(mutate) {
  const base = structuredClone(BASE);
  const head = structuredClone(base);
  mutate(head);
  return expectViolationShape(diffSchema(base, head));
}

/** validateEvent 결과 모양(D2): { ok: boolean, errors: { path, message }[] } · ok ⇔ errors 없음 */
function validate(envelope, options) {
  const result = validateEvent(envelope, options);
  expect(typeof result.ok).toBe("boolean");
  expect(Array.isArray(result.errors)).toBe(true);
  for (const error of result.errors) {
    expect(error.path).toMatch(/^#(\/|$)/);
    expect(typeof error.message).toBe("string");
    expect(error.message.trim()).not.toBe("");
  }
  expect(result.ok).toBe(result.errors.length === 0);
  return result;
}

describe("diffSchema — 허용되는 변경(위반 0)", () => {
  it("compat-1 선택 필드 추가는 위반이 아니다", () => {
    expect(
      diffAfter((head) => {
        head.properties.extra = { type: "string" };
      }),
    ).toEqual([]);
  });

  it("compat-2 enum 값 추가는 위반이 아니다(enum은 집합 — 순서만 바뀐 것도 위반 아님)", () => {
    expect(
      diffAfter((head) => {
        head.properties.reason.enum.push("tenant_suspended");
      }),
    ).toEqual([]);
    expect(
      diffAfter((head) => {
        head.properties.reason.enum.reverse();
      }),
    ).toEqual([]);
  });

  it("compat-3 메타데이터(title · description · examples · x-version · $comment)만 바뀌면 위반이 아니다", () => {
    expect(
      diffAfter((head) => {
        head.title = "sample (제목 변경)";
        head.description = "설명 추가";
        head["x-version"] = "1.1.0";
        head.examples = [{ sub: "s-1", nbf: 1, reason: "admin" }];
        head.$comment = "메타데이터만 바뀐다";
        head.properties.sub.description = "토큰 sub(중첩 메타데이터)";
      }),
    ).toEqual([]);
  });
});

describe("diffSchema — 금지되는 변경(위반 보고)", () => {
  it("compat-4 필드 삭제 → field-removed #/properties/sid", () => {
    const violations = diffAfter((head) => {
      delete head.properties.sid;
    });
    expect(violations).toHaveLength(1);
    expect(violations[0]).toMatchObject({
      file: "<memory>",
      kind: "field-removed",
      path: "#/properties/sid",
    });
  });

  it("compat-5 필드 이름 변경(nbf → not_before)은 옛 이름의 삭제로 보고된다", () => {
    const violations = diffAfter((head) => {
      delete head.properties.nbf;
      head.properties.not_before = { type: "integer" };
      head.required = head.required.map((name) => (name === "nbf" ? "not_before" : name));
    });
    // required 변화(not_before 추가 · nbf 제거)도 함께 보고될 수 있다 — 삭제 보고만 단언한다
    expect(violations.length).toBeGreaterThanOrEqual(1);
    expect(violations).toContainEqual(
      expect.objectContaining({ kind: "field-removed", path: "#/properties/nbf" }),
    );
  });

  it.each([
    [
      "nbf integer → string",
      (head) => {
        head.properties.nbf.type = "string";
      },
      "#/properties/nbf",
    ],
    [
      'sub string → ["string", "null"]',
      (head) => {
        head.properties.sub.type = ["string", "null"];
      },
      "#/properties/sub",
    ],
    [
      'sid ["string", "null"] → string',
      (head) => {
        head.properties.sid.type = "string";
      },
      "#/properties/sid",
    ],
  ])("compat-6 타입 변경(%s) → type-changed", (_label, mutate, pointer) => {
    const violations = diffAfter(mutate);
    expect(violations).toHaveLength(1);
    expect(violations[0]).toMatchObject({ kind: "type-changed", path: pointer });
  });

  it("compat-6 type은 집합으로 비교한다 — 표기(문자열 ↔ 배열)·순서 차이는 위반이 아니다", () => {
    expect(
      diffAfter((head) => {
        head.properties.sub.type = ["string"];
      }),
    ).toEqual([]);
    expect(
      diffAfter((head) => {
        head.properties.sid.type = ["null", "string"];
      }),
    ).toEqual([]);
  });

  it("compat-7 required 추가 → required-added #/required(message에 필드 이름)", () => {
    const violations = diffAfter((head) => {
      head.required.push("sid");
    });
    expect(violations).toHaveLength(1);
    expect(violations[0]).toMatchObject({ kind: "required-added", path: "#/required" });
    expect(mentions(violations[0].message, "sid"), violations[0].message).toBe(true);
  });

  it("compat-8 required 제거 → required-removed #/required(message에 필드 이름)", () => {
    const violations = diffAfter((head) => {
      head.required = head.required.filter((name) => name !== "reason");
    });
    expect(violations).toHaveLength(1);
    expect(violations[0]).toMatchObject({ kind: "required-removed", path: "#/required" });
    expect(mentions(violations[0].message, "reason"), violations[0].message).toBe(true);
  });

  it("compat-9 enum 값 삭제 → enum-removed #/properties/reason(message에 값)", () => {
    const violations = diffAfter((head) => {
      head.properties.reason.enum = head.properties.reason.enum.filter((value) => value !== "admin");
    });
    expect(violations).toHaveLength(1);
    expect(violations[0]).toMatchObject({ kind: "enum-removed", path: "#/properties/reason" });
    expect(mentions(violations[0].message, "admin"), violations[0].message).toBe(true);
  });

  it("compat-10 중첩 객체 · 배열 items 안도 필드 단위로 비교한다", () => {
    const typeChanged = diffAfter((head) => {
      head.properties.variants.items.properties.url.type = "integer";
    });
    expect(typeChanged).toHaveLength(1);
    expect(typeChanged[0]).toMatchObject({
      kind: "type-changed",
      path: "#/properties/variants/items/properties/url",
    });

    const removed = diffAfter((head) => {
      delete head.properties.variants.items.properties.name;
    });
    // name은 items의 required에 들어 있다 — 그쪽 보고 여부와 무관하게 삭제 보고만 단언한다
    expect(removed).toContainEqual(
      expect.objectContaining({
        kind: "field-removed",
        path: "#/properties/variants/items/properties/name",
      }),
    );

    // 중첩 스키마의 required 추가도 같은 규칙(경로 = 그 스키마 포인터 + "/required")
    const requiredAdded = diffAfter((head) => {
      head.properties.variants.items.required.push("url");
    });
    expect(requiredAdded).toHaveLength(1);
    expect(requiredAdded[0]).toMatchObject({
      kind: "required-added",
      path: "#/properties/variants/items/required",
    });
    expect(mentions(requiredAdded[0].message, "url"), requiredAdded[0].message).toBe(true);
  });

  it("compat-11 위반을 첫 건에서 멈추지 않고 전부 보고한다", () => {
    const violations = diffAfter((head) => {
      delete head.properties.sid;
      head.properties.nbf.type = "string";
      head.properties.extra_req = { type: "string" };
      head.required.push("extra_req");
    });
    expect(violations).toHaveLength(3);
    expect(kinds(violations)).toEqual(new Set(["field-removed", "type-changed", "required-added"]));
  });
});

describe("compareDirectories — main ↔ PR 스키마 디렉터리 비교", () => {
  // 시험용 축약 봉투 스키마(실제 _envelope.json과 무관 — 디렉터리 비교 규칙만 본다)
  const ENVELOPE_LITE = {
    $schema: DRAFT_2020_12,
    title: "envelope (시험용 축약)",
    type: "object",
    properties: {
      specversion: { const: "1.0" },
      id: { type: "string" },
      type: { type: "string" },
      subject: { type: "string" },
      tenantid: { type: "string", format: "uuid" },
      data: { type: "object" },
    },
    required: ["specversion", "id", "type", "tenantid", "data"],
  };

  it("compat-12 파일 삭제 → schema-removed · 새 파일 → added · 공통 파일 → 필드 비교 · .json만 본다", () => {
    const envelopeHead = structuredClone(ENVELOPE_LITE);
    delete envelopeHead.properties.subject; // required 밖 필드 — 위반은 field-removed 하나
    const baseDir = writeSchemas(makeTempDir(), {
      "a.json": BASE,
      "b.json": BASE,
      "_envelope.json": ENVELOPE_LITE,
      "notes.txt": "JSON이 아닌 파일은 비교하지 않는다\n",
    });
    const headDir = writeSchemas(makeTempDir(), {
      "a.json": BASE,
      "_envelope.json": envelopeHead,
      "c.json": BASE,
      ".gitkeep": "",
    });

    const result = compareDirectories(baseDir, headDir);

    expectViolationShape(result.violations);
    expect(result.violations).toHaveLength(2);
    expect(result.violations).toContainEqual(
      expect.objectContaining({ file: "b.json", kind: "schema-removed", path: "#" }),
    );
    expect(result.violations).toContainEqual(
      expect.objectContaining({
        file: "_envelope.json",
        kind: "field-removed",
        path: "#/properties/subject",
      }),
    );
    expect(result.added).toEqual(["c.json"]);
    expect(result.checked).toBe(2);
  });
});

describe("CLI — node scripts/check-compat.mjs --base <dir> --head <dir>", () => {
  const ANY_KIND = new RegExp(KINDS.join("|"));

  /** 실제 node 프로세스로 CLI를 돌린다(셸 없음 · 시간 제한) */
  function runCli(args) {
    return spawnSync(process.execPath, [SCRIPT, ...args], { encoding: "utf8", timeout: 30_000 });
  }

  it("compat-13 종료 코드 — 위반 1(위반마다 한 줄) · 위반 없음/허용 변경 0 · 인자 누락/디렉터리 없음 2", { timeout: 60_000 }, () => {
    const breaking = structuredClone(BASE);
    delete breaking.properties.sid;
    breaking.properties.nbf.type = "string";
    const allowed = structuredClone(BASE);
    allowed.properties.extra = { type: "string" };
    const baseDir = writeSchemas(makeTempDir(), { "x.json": BASE });
    const headDir = writeSchemas(makeTempDir(), { "x.json": breaking });
    const allowedDir = writeSchemas(makeTempDir(), { "x.json": allowed, "y.json": BASE });

    const violating = runCli(["--base", baseDir, "--head", headDir]);
    expect(violating.error).toBeUndefined();
    expect(violating.status, violating.stderr).toBe(1);
    const lines = violating.stdout.split(/\r?\n/);
    // 위반마다 "<file> <path> <kind> <message>" 한 줄 — 두 위반 모두(첫 위반에서 멈추지 않는다)
    expect(lines.some((line) => line.startsWith("x.json #/properties/sid field-removed ")), violating.stdout).toBe(true);
    expect(lines.some((line) => line.startsWith("x.json #/properties/nbf type-changed ")), violating.stdout).toBe(true);

    const same = runCli(["--base", baseDir, "--head", baseDir]);
    expect(same.status, same.stderr).toBe(0);
    expect(same.stdout).not.toMatch(ANY_KIND);

    const additive = runCli(["--base", baseDir, "--head", allowedDir]);
    expect(additive.status, additive.stderr).toBe(0);
    expect(additive.stdout).not.toMatch(ANY_KIND);

    const missingHead = runCli(["--base", baseDir]);
    expect(missingHead.status).toBe(2);
    expect(missingHead.stderr.trim()).not.toBe("");

    const missingDir = runCli(["--base", baseDir, "--head", path.join(baseDir, "no-such-dir")]);
    expect(missingDir.status).toBe(2);
    expect(missingDir.stderr.trim()).not.toBe("");
  });

  it("compat-13 import만으로는 CLI가 실행되지 않는다(진입점 가드)", { timeout: 60_000 }, () => {
    const importer = path.join(makeTempDir(), "importer.mjs");
    const source = [
      `const mod = await import(${JSON.stringify(pathToFileURL(SCRIPT).href)});`,
      'console.log(["diffSchema", "compareDirectories", "validateEvent"].map((name) => typeof mod[name]).join(","));',
      "",
    ].join("\n");
    fs.writeFileSync(importer, source, "utf8");

    const result = spawnSync(process.execPath, [importer], { encoding: "utf8", timeout: 30_000 });

    expect(result.status, result.stderr).toBe(0);
    expect(result.stdout.trim()).toBe("function,function,function");
  });
});

describe("validateEvent — 봉투(_envelope.json) + 토픽 data 스키마(실제 schemas/)", () => {
  it("compat-14 계약 예시 모양의 봉투는 통과한다", () => {
    const result = validate(structuredClone(SAMPLE_ENVELOPE));
    expect(result.errors).toEqual([]);
    expect(result.ok).toBe(true);
  });

  it.each(ENVELOPE_REQUIRED)("compat-14 필수 필드 %s 누락 → 실패", (field) => {
    const envelope = structuredClone(SAMPLE_ENVELOPE);
    delete envelope[field];

    const result = validate(envelope);

    expect(result.ok).toBe(false);
    expect(
      result.errors.some((error) => error.path === `#/${field}` || mentions(error.message, field)),
      JSON.stringify(result.errors),
    ).toBe(true);
  });

  it.each([
    ["tenantid", "joshuatech"], // slug 금지 — 값은 항상 테넌트 UUID
    ["specversion", "0.3"], // CloudEvents 1.0만
    ["id", "not-a-ulid"], // outbox 행 id = ULID
    ["time", "2026-09-01"], // RFC 3339 date-time
    ["datacontenttype", "text/plain"], // application/json만
  ])("compat-14 %s = %j → 실패", (field, value) => {
    const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), [field]: value });
    expect(result.ok).toBe(false);
    expect(result.errors, JSON.stringify(result.errors)).toContainEqual(
      expect.objectContaining({ path: `#/${field}` }),
    );
  });

  it("compat-14 data는 type의 토픽 스키마로 검증한다(enum 밖 reason → #/data/reason)", () => {
    const envelope = structuredClone(SAMPLE_ENVELOPE);
    envelope.data.reason = "bogus";

    const result = validate(envelope);

    expect(result.ok).toBe(false);
    expect(result.errors, JSON.stringify(result.errors)).toContainEqual(
      expect.objectContaining({ path: "#/data/reason" }),
    );
  });

  it("compat-14 토픽 스키마가 없는 type → schema-missing(message에 토픽 이름)", () => {
    const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), type: "nope.topic.event" });
    expect(result.ok).toBe(false);
    expect(schemaMissingFor(result.errors, "nope.topic.event"), JSON.stringify(result.errors)).toBe(true);
  });

  it("compat-14 schemasDir 옵션의 디렉터리에서 스키마를 읽는다", () => {
    const dir = writeSchemas(makeTempDir(), {
      "_envelope.json": readRealSchema("_envelope.json"),
      "sample.topic.event.json": BASE,
    });
    const envelope = {
      ...structuredClone(SAMPLE_ENVELOPE),
      type: "sample.topic.event",
      data: { sub: "9f2c-test", nbf: 1756696867, reason: "admin" },
    };

    const result = validate(envelope, { schemasDir: dir });
    expect(result.errors).toEqual([]);
    expect(result.ok).toBe(true);

    // 기본 schemas/에는 이 토픽이 없다 — 옵션이 실제로 디렉터리를 바꿨다는 대조
    const fallback = validate(envelope);
    expect(fallback.ok).toBe(false);
    expect(schemaMissingFor(fallback.errors, "sample.topic.event"), JSON.stringify(fallback.errors)).toBe(true);
  });

  it("compat-14 type으로 schemasDir 밖 파일을 스키마로 읽지 않는다(경로 탈출)", () => {
    // root/schemas/ = schemasDir · root/evil.json = 무엇이든 통과시키는 스키마 {}
    const root = makeTempDir();
    const schemasDir = path.join(root, "schemas");
    fs.mkdirSync(schemasDir);
    writeSchemas(schemasDir, { "_envelope.json": readRealSchema("_envelope.json") });
    writeSchemas(root, { "evil.json": {} });

    const result = validate({ ...structuredClone(SAMPLE_ENVELOPE), type: "../evil" }, { schemasDir });

    expect(result.ok).toBe(false);
  });
});

describe("schemas/ — T067 산출물의 파일 모양", () => {
  it("compat-15 _envelope.json + 토픽 6 · Draft 2020-12 · $id · x-version · 자립 파일 · 열린 스키마 · 봉투 필수 9", () => {
    const files = fs.readdirSync(SCHEMAS_DIR).filter((name) => name.endsWith(".json"));
    for (const name of ["_envelope.json", ...TOPICS.map((topic) => `${topic}.json`)]) {
      expect(files, `schemas/${name} 없음`).toContain(name);
    }

    for (const name of files) {
      const schema = readRealSchema(name);
      expect(schema.$schema, name).toBe(DRAFT_2020_12);
      expect(schema["x-version"], name).toMatch(/^\d+\.\d+\.\d+$/);
      // 자립 파일 — 외부 $ref 없음(Python 소비자 T061이 파일 하나로 검증한다)
      expect(collectRefs(schema).filter((ref) => !ref.startsWith("#")), name).toEqual([]);
      // 열린 스키마 — additionalProperties: false 금지(계약 §호환성 규칙 · 리뷰 r1 A-1 · 봉투·토픽 공통)
      expect(collectClosed(schema), name).toEqual([]);
      if (name.startsWith("_")) continue; // 공용 파일(_envelope.json)은 토픽 규칙 밖
      const topic = name.slice(0, -".json".length);
      expect(schema.$id, name).toBe(`https://joshuatech.dev/events/${topic}/v1`);
      expect(schema.type, name).toBe("object");
    }

    const envelope = readRealSchema("_envelope.json");
    expect(new Set(envelope.required)).toEqual(new Set(ENVELOPE_REQUIRED));
    expect(envelope.properties.tenantid.format).toBe("uuid");
    expect(envelope.properties.specversion.const).toBe("1.0");
  });

  it("compat-16 _envelope.json의 data는 객체만 요구한다(토픽별 data 검증은 validateEvent — compat-14)", () => {
    const envelope = readRealSchema("_envelope.json");
    expect(envelope.properties.data.type).toBe("object");
  });
});
