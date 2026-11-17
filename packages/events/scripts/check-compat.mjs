// check-compat.mjs — packages/events 스키마 호환성 검사기와 봉투 검증(T067).
//
// 정본: specs/003-platform-foundation/contracts/events.md §봉투 · §호환성 규칙 · .claude/rules/events.md §Compatibility rules.
// 모듈 API의 정본은 tests/check-compat.test.mjs(T064) 머리 주석이다 — 여기에는 구현 규칙만 적는다.
//   diffSchema(base, head, { file = "<memory>" } = {}) -> Violation[] { file, path, kind, message }
//   compareDirectories(baseDir, headDir) -> { violations, added, checked }
//   validateEvent(envelope, { schemasDir = <패키지>/schemas } = {}) -> { ok, errors: { path, message }[] }
//   UnsupportedSchemaError — 검사기가 비교할 수 없는 스키마(허용 키 밖 · 모양 오류). CLI는 2로 끝난다.
// CLI: node scripts/check-compat.mjs --base <dir> --head <dir>
//   exit 0 위반 없음 · 1 위반 ≥ 1(stdout에 위반마다 "<file> <path> <kind> <message>" 한 줄) · 2 인자 · 디렉터리 · 읽기 · 파싱 오류와
//   허용 키 밖의 스키마(stderr). stdout에는 위반 줄만 쓴다.
//   요약 줄(고정 CLI 계약): 0 · 1로 끝날 때 stderr에 "check-compat: checked N · added M · violations K" 꼴의 줄을 정확히 하나 쓴다
//   (K = stdout의 위반 줄 수 — 0이면 exit 0, 1 이상이면 exit 1). scripts/ci/events-compat.sh가 기준 커밋의 이 파일을 돌리고 이 줄을
//   읽어 종료 코드와 맞춰 본다 — 꼴을 바꾸면 기준 쪽 검사기와 변경 쪽 스크립트가 어긋나 게이트가 2로 막힌다(contracts/events.md
//   「검사기 출력 계약」). 요약 줄 뒤에 added 목록 · 안내 줄이 더 붙을 수 있다.
//   찍는 글자의 제어 문자(줄바꿈 포함)는 \uXXXX 꼴로 바꾼다 — 위반 하나 = 한 줄이고, PR이 고른 파일 이름 · 속성 이름이 줄 머리에
//   워크플로 명령(::)을 만들지 못한다.
//
// 기준 쪽 실행 제약(계약 §호환성 규칙 「CI 기준과 검사기」 · scripts/ci/events-compat.sh):
//   CI는 기준 커밋의 이 파일을 패키지 밖 임시 디렉터리(node_modules 없음)에 꺼내 CLI로 돌린다 — PR이 검사기를 약하게 고쳐 같은 PR의
//   스키마 변경을 통과시키지 못하게. 그래서 모듈 머리는 node: 내장 모듈만 import하고, ajv · ajv-formats는 validateEvent가 처음 부를 때
//   createRequire로 읽는다(CLI 경로는 ajv를 부르지 않는다). 정적 import나 최상위의 패키지 로드를 더하면 기준 쪽 실행이 깨진다
//   (tests/schemas.test.mjs sch-9가 지킨다).
//
// 비교 규칙(diffSchema) — 노드마다 아래 순서로 보고, 첫 위반에서 멈추지 않는다:
//   type      집합으로 비교한다(문자열 ↔ 배열 · 순서 무관 · 키 없음 = 빈 집합). 집합이 다르면 type-changed — 없던 type을 더하는 것도.
//   enum      허용 값의 집합(값은 키를 정렬한 JSON으로 비교 — 순서 무관)이 줄면 enum-removed(message에 삭제된 값). const는 값 하나짜리
//             enum이다 — 값이 바뀌면 enum-removed. enum과 const가 함께 있으면 교집합. 기준에 제한이 없는데(enum · const 둘 다 없음)
//             변경 쪽에 생기면 enum-removed(허용 값 제한 신설 — "모든 값"에서 몇 개로 준다 · 없던 type을 더하면 type-changed인 것과
//             같은 원칙). 늘거나 키가 통째로 없어지면(확대) 위반이 아니다.
//   required  집합의 추가 · 제거마다 required-added · required-removed(path = 그 노드 포인터 + "/required" · message에 필드 이름).
//   properties 기준에 있던 이름이 변경 쪽에 없으면 field-removed(path = …/properties/<이름>), 양쪽에 있으면 재귀. 새 이름은 허용.
//   items     어느 한쪽에라도 있으면 재귀한다(없는 쪽은 빈 스키마 {} — 제약이 없다는 뜻이 같다). 배열 꼴(튜플)은 허용 키 밖이다.
//   additionalProperties 어느 한쪽에라도 있으면 스키마끼리 재귀한다(true · 없음 = 빈 스키마 {}). false는 여기 오지 않는다 — 아래
//             허용 키 검사가 먼저 거부한다.
//   포인터는 RFC 6901로 이스케이프한다(~ → ~0 · / → ~1). 메타데이터와 값 제약은 비교하지 않는다(값 제약은 리뷰가 막는다 — 계약).
// 허용 키(계약 §호환성 규칙 「검사기가 다루는 키」): 구조 type · properties · required · items · enum · const · additionalProperties /
//   값 제약 format · pattern · minLength · maxLength · minimum · maximum · exclusiveMinimum · exclusiveMaximum · minItems · maxItems ·
//   uniqueItems / 메타데이터 $schema · $id · $comment · title · description · examples · default · deprecated · readOnly · writeOnly ·
//   x-*(이름이 ^x-[a-z0-9]+(-[a-z0-9]+)*$ 꼴일 때만 — 꼴 밖의 x- 키는 허용 키 밖이다: 점 · 공백 · 비ASCII가 든 이름은 ajv가 키워드로
//   등록하지 못해 validateEvent가 판정 대신 예외를 던진다). 키는 스키마 객체의 키만 본다 — properties 아래의 속성 이름과 examples ·
//   default · enum · const 값 안의 키는 스키마 키가 아니므로 훑지 않는다. 이 밖의 키가 기준이나 변경 쪽의 어느 노드(새로 더한 속성 ·
//   새 파일 · 지운 파일 포함)에든 있으면 UnsupportedSchemaError — 비교하지 못한 변경을 통과로 두지 않는다. 노드가 객체가 아니거나(불리언
//   스키마 · 배열) type · required · enum · properties의 모양이 틀려도 같은 예외다. additionalProperties는 스키마이거나 true여야 한다 —
//   false는 어느 위치 · 어느 쪽 · 어느 파일이든 같은 예외다(계약이 금지한 닫힌 스키마를 기준 쪽 검사기가 강제한다 — PR이 테스트를 지워도).
// compareDirectories: 두 디렉터리의 .json 일반 파일만 이름순으로 본다(심볼릭 링크 · 디렉터리는 예외 — 따라가지 않는다).
//   기준에만 있으면 schema-removed(path "#"), 변경 쪽에만 있으면 added(정렬), 양쪽에 있으면 diffSchema(file = 파일 이름).
//   읽기 · 파싱 실패는 파일 이름을 담은 예외다.
// validateEvent: schemasDir(path.resolve 기준)마다 Ajv 인스턴스를 따로 두고(한 인스턴스에 같은 $id를 두 번 컴파일하면 예외다)
//   컴파일한 검증기는 파일 경로마다 캐시한다. Ajv2020 { strict: true, allErrors: true } + ajv-formats. 스키마를 컴파일하기 전에
//   스키마 위치(허용 키 검사와 같은 재귀 — 스키마 객체의 키 · properties의 각 값 · items · 스키마인 additionalProperties)의 키 중
//   x-* 꼴에 맞고 아직 키워드가 아닌 것을 값 검사 없는 키워드로 등록한다(addKeyword — strict 모드는 모르는 키워드를 예외로 낸다 ·
//   허용 키의 x-* 메타데이터와 맞춘다). 속성 이름과 examples · default · enum · const 값 안의 키는 등록하지 않고, 꼴 밖의 x- 키도
//   등록하지 않는다(컴파일이 strict 예외로 끝난다 — CLI는 그런 스키마를 2로 막는다).
//   봉투(_envelope.json) 오류의 path는 "#" + instancePath, data 오류는 "#/data" + instancePath — required 오류는 빠진 속성 이름을
//   이스케이프해 붙인다. message는 "<keyword>: <ajv message>" 한 줄. data는 봉투가 객체이고 data가 있고 type이 문자열이며 #/type
//   오류가 없을 때만 schemas/<type>.json으로 검증한다. 그 파일 경로가 schemasDir 바로 아래가 아니면(.. · 경로 구분자 · 드라이브)
//   거부한다(심층 방어 — 1차 방어는 봉투 type의 pattern). 파일이 없으면 #/type에 schema-missing(message에 토픽 이름).
//   _envelope.json이나 토픽 스키마를 읽거나 컴파일하지 못하면 예외다(설정 오류 — 이벤트 하나의 실패가 아니다).

import fs from "node:fs";
import { createRequire } from "node:module";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const PROG = "check-compat";
const ENVELOPE_FILE = "_envelope.json";
const DEFAULT_SCHEMAS_DIR = fileURLToPath(new URL("../schemas/", import.meta.url));
const USAGE = "사용법: node scripts/check-compat.mjs --base <기준 스키마 디렉터리> --head <변경 쪽 스키마 디렉터리>";

const STRUCTURAL_KEYS = new Set(["type", "properties", "required", "items", "enum", "const", "additionalProperties"]);
const VALUE_KEYS = new Set([
  "format",
  "pattern",
  "minLength",
  "maxLength",
  "minimum",
  "maximum",
  "exclusiveMinimum",
  "exclusiveMaximum",
  "minItems",
  "maxItems",
  "uniqueItems",
]);
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
// x-* 메타데이터 키의 이름 꼴(계약 「검사기가 다루는 키」) — ajv가 키워드로 등록할 수 있는 이름의 부분집합(소문자 kebab)
const METADATA_X_KEY = /^x-[a-z0-9]+(-[a-z0-9]+)*$/;
const JSON_TYPES = new Set(["string", "number", "integer", "boolean", "object", "array", "null"]);
const BACKSLASH = "\\";

/** 검사기가 비교할 수 없는 스키마 — 허용 키 밖의 키 · 모양 오류(CLI exit 2) */
export class UnsupportedSchemaError extends Error {
  constructor(file, pointer, detail) {
    super(`${file} ${pointer}: ${detail}`);
    this.name = "UnsupportedSchemaError";
    this.file = file;
    this.path = pointer;
  }
}

/** 제어 문자(C0 · DEL · C1 · U+2028 · U+2029)를 \uXXXX 꼴로 바꿔 한 줄로 만든다 */
function oneLine(text) {
  let out = "";
  for (const char of String(text)) {
    const code = char.codePointAt(0);
    const unsafe = code <= 0x1f || (code >= 0x7f && code <= 0x9f) || code === 0x2028 || code === 0x2029;
    out += unsafe ? `${BACKSLASH}u${code.toString(16).padStart(4, "0")}` : char;
  }
  return out;
}

/** RFC 6901 참조 토큰 이스케이프(~ → ~0 · / → ~1) */
function escapeToken(token) {
  return String(token).replaceAll("~", "~0").replaceAll("/", "~1");
}

function childPointer(pointer, ...tokens) {
  return [pointer, ...tokens.map(escapeToken)].join("/");
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

/** x-* 메타데이터 키인가 — 이름이 꼴(METADATA_X_KEY)에 맞을 때만(접두만으로는 아니다) */
function isMetadataXKey(key) {
  return METADATA_X_KEY.test(key);
}

function isKnownKey(key) {
  return STRUCTURAL_KEYS.has(key) || VALUE_KEYS.has(key) || METADATA_KEYS.has(key) || isMetadataXKey(key);
}

/** 키를 정렬한 JSON — 값 비교용(객체 키 순서가 달라도 같은 값) */
function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(",")}]`;
  if (isPlainObject(value)) {
    const members = Object.keys(value)
      .sort()
      .map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`);
    return `{${members.join(",")}}`;
  }
  return JSON.stringify(value);
}

function violation(file, pointer, kind, message) {
  return { file, path: pointer, kind, message: oneLine(message) };
}

/** 노드 트리 전체가 검사기가 다루는 모양인지 확인한다 — 아니면 UnsupportedSchemaError(side = 기준 · 변경 쪽) */
function assertSupported(node, pointer, file, side) {
  const fail = (at, detail) => {
    throw new UnsupportedSchemaError(file, at, `${side} 스키마 — ${detail}`);
  };
  if (!isPlainObject(node)) {
    fail(pointer, "스키마 노드가 객체가 아니다(불리언 스키마 · 배열은 비교하지 못한다)");
  }
  for (const key of Object.keys(node)) {
    if (!isKnownKey(key)) {
      const form = key.startsWith("x-")
        ? ` — x-* 메타데이터 키는 이름이 ${METADATA_X_KEY.source} 꼴이어야 한다(꼴 밖의 이름은 ajv strict가 키워드로 받지 않아 validateEvent가 판정 대신 예외를 던진다)`
        : "";
      fail(
        pointer,
        `검사기가 다루지 않는 키 ${JSON.stringify(key)}${form} — 비교하지 못한 변경을 통과로 두지 않는다. 허용 목록 밖의 구조는 쓰지 않는다(쓰려면 검사기를 먼저 넓힌다 — contracts/events.md §호환성 규칙)`,
      );
    }
  }
  if (Object.hasOwn(node, "type")) {
    const list = typeof node.type === "string" ? [node.type] : node.type;
    if (!Array.isArray(list) || list.length === 0 || !list.every((name) => typeof name === "string" && JSON_TYPES.has(name))) {
      fail(`${pointer}/type`, "type은 JSON 타입 이름이나 그 배열이어야 한다");
    }
  }
  if (Object.hasOwn(node, "required")) {
    if (!Array.isArray(node.required) || !node.required.every((name) => typeof name === "string")) {
      fail(`${pointer}/required`, "required는 문자열 배열이어야 한다");
    }
  }
  if (Object.hasOwn(node, "enum") && !Array.isArray(node.enum)) {
    fail(`${pointer}/enum`, "enum은 배열이어야 한다");
  }
  if (Object.hasOwn(node, "properties")) {
    if (!isPlainObject(node.properties)) fail(`${pointer}/properties`, "properties는 객체여야 한다");
    for (const [name, child] of Object.entries(node.properties)) {
      assertSupported(child, childPointer(pointer, "properties", name), file, side);
    }
  }
  if (Object.hasOwn(node, "items")) {
    assertSupported(node.items, `${pointer}/items`, file, side);
  }
  if (Object.hasOwn(node, "additionalProperties")) {
    if (node.additionalProperties === false) {
      fail(
        `${pointer}/additionalProperties`,
        "additionalProperties: false — 계약이 금지한다(열린 스키마 · contracts/events.md §호환성 규칙)",
      );
    }
    if (node.additionalProperties !== true) {
      assertSupported(node.additionalProperties, `${pointer}/additionalProperties`, file, side);
    }
  }
}

/** type 집합(정렬) — 키가 없으면 빈 집합 */
function typeSet(node) {
  if (!Object.hasOwn(node, "type")) return [];
  const list = typeof node.type === "string" ? [node.type] : node.type;
  return [...new Set(list)].sort();
}

function formatTypes(types) {
  return types.length === 0 ? "(없음)" : JSON.stringify(types);
}

/** enum · const가 허용하는 값의 집합(키를 정렬한 JSON) — 둘 다 없으면 null(제한 없음). const는 값 하나짜리 enum이다 */
function allowedValues(node) {
  const hasEnum = Object.hasOwn(node, "enum");
  const hasConst = Object.hasOwn(node, "const");
  if (!hasEnum && !hasConst) return null;
  let values = hasEnum ? node.enum.map(canonicalJson) : null;
  if (hasConst) {
    const constant = canonicalJson(node.const);
    values = values === null ? [constant] : values.filter((value) => value === constant);
  }
  return new Set(values);
}

/** 허용 값 집합을 사람용 한 줄로 — 키를 정렬한 JSON을 ", "로 잇는다(값이 없으면 "(값 없음)") */
function formatValues(values) {
  return values.size === 0 ? "(값 없음)" : [...values].join(", ");
}

/** additionalProperties 값을 비교용 스키마로(없음 · true = {} — false는 assertSupported가 이미 거부했다) */
function asSchema(value) {
  return value === undefined || value === true ? {} : value;
}

function compareNode(base, head, pointer, file, out) {
  const baseTypes = typeSet(base);
  const headTypes = typeSet(head);
  if (baseTypes.join("\n") !== headTypes.join("\n")) {
    out.push(violation(file, pointer, "type-changed", `타입 변경: ${formatTypes(baseTypes)} → ${formatTypes(headTypes)}`));
  }

  const baseValues = allowedValues(base);
  const headValues = allowedValues(head);
  if (baseValues === null && headValues !== null) {
    out.push(
      violation(file, pointer, "enum-removed", `허용 값 제한 신설: 기준은 제한 없음 → ${formatValues(headValues)}`),
    );
  } else if (baseValues !== null && headValues !== null) {
    const removed = [...baseValues].filter((value) => !headValues.has(value));
    if (removed.length > 0) {
      const constOnly = [base, head].every((node) => Object.hasOwn(node, "const") && !Object.hasOwn(node, "enum"));
      const message = constOnly
        ? `const 값 변경: ${canonicalJson(base.const)} → ${canonicalJson(head.const)}(값 하나짜리 enum의 값 삭제)`
        : `enum 값 삭제: ${removed.join(", ")}`;
      out.push(violation(file, pointer, "enum-removed", message));
    }
  }

  const baseRequired = new Set(base.required ?? []);
  const headRequired = new Set(head.required ?? []);
  const requiredPointer = `${pointer}/required`;
  for (const name of [...headRequired].filter((item) => !baseRequired.has(item)).sort()) {
    out.push(violation(file, requiredPointer, "required-added", `required 추가: ${JSON.stringify(name)}`));
  }
  for (const name of [...baseRequired].filter((item) => !headRequired.has(item)).sort()) {
    out.push(violation(file, requiredPointer, "required-removed", `required 제거: ${JSON.stringify(name)}`));
  }

  const baseProperties = base.properties ?? {};
  const headProperties = head.properties ?? {};
  for (const name of Object.keys(baseProperties).sort()) {
    const child = childPointer(pointer, "properties", name);
    if (Object.hasOwn(headProperties, name)) {
      compareNode(baseProperties[name], headProperties[name], child, file, out);
    } else {
      out.push(violation(file, child, "field-removed", `필드 삭제: ${JSON.stringify(name)}`));
    }
  }

  if (Object.hasOwn(base, "items") || Object.hasOwn(head, "items")) {
    compareNode(base.items ?? {}, head.items ?? {}, `${pointer}/items`, file, out);
  }

  if (Object.hasOwn(base, "additionalProperties") || Object.hasOwn(head, "additionalProperties")) {
    compareNode(
      asSchema(base.additionalProperties),
      asSchema(head.additionalProperties),
      `${pointer}/additionalProperties`,
      file,
      out,
    );
  }
}

/** 기준 스키마 → 변경 쪽 스키마의 호환성 위반을 전부 돌려준다(위반이 없으면 []) */
export function diffSchema(base, head, { file = "<memory>" } = {}) {
  assertSupported(base, "#", file, "기준");
  assertSupported(head, "#", file, "변경 쪽");
  const out = [];
  compareNode(base, head, "#", file, out);
  return out;
}

/** dir의 .json 일반 파일을 이름 → 파싱한 스키마로 읽는다 */
function readSchemaDirectory(dir) {
  const schemas = new Map();
  const entries = fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((entry) => entry.name.endsWith(".json"))
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
  for (const entry of entries) {
    if (!entry.isFile()) {
      throw new Error(`${oneLine(entry.name)}: 일반 파일이 아니다(심볼릭 링크 · 디렉터리는 읽지 않는다)`);
    }
    let text;
    try {
      text = fs.readFileSync(path.join(dir, entry.name), "utf8");
    } catch (error) {
      throw new Error(`${oneLine(entry.name)}: 읽지 못했다 — ${error.code ?? error.message}`);
    }
    try {
      schemas.set(entry.name, JSON.parse(text));
    } catch (error) {
      throw new Error(`${oneLine(entry.name)}: JSON 파싱 실패 — ${error.message}`);
    }
  }
  return schemas;
}

/** main(기준) ↔ PR(변경 쪽) 스키마 디렉터리 비교 */
export function compareDirectories(baseDir, headDir) {
  const base = readSchemaDirectory(baseDir);
  const head = readSchemaDirectory(headDir);
  const names = [...new Set([...base.keys(), ...head.keys()])].sort();
  const violations = [];
  const added = [];
  let checked = 0;
  for (const name of names) {
    if (base.has(name) && head.has(name)) {
      checked += 1;
      violations.push(...diffSchema(base.get(name), head.get(name), { file: name }));
    } else if (base.has(name)) {
      assertSupported(base.get(name), "#", name, "기준");
      violations.push(violation(name, "#", "schema-removed", `스키마 파일 삭제: ${JSON.stringify(name)} — 토픽을 지울 수 없다`));
    } else {
      assertSupported(head.get(name), "#", name, "변경 쪽");
      added.push(name);
    }
  }
  return { violations, added, checked };
}

// ---------- validateEvent(ajv는 여기서만 — 처음 부를 때 읽는다) ----------
const requirePackage = createRequire(import.meta.url);
let ajvModules = null;
const ajvStates = new Map();

function loadAjv() {
  if (ajvModules === null) {
    const ajvExports = requirePackage("ajv/dist/2020");
    const formatsExports = requirePackage("ajv-formats");
    ajvModules = {
      Ajv2020: ajvExports.default ?? ajvExports,
      addFormats: formatsExports.default ?? formatsExports,
    };
  }
  return ajvModules;
}

/** schemasDir(해석한 경로)마다 Ajv 인스턴스 하나와 파일 경로별 검증기 캐시 */
function ajvStateFor(dir) {
  let state = ajvStates.get(dir);
  if (state === undefined) {
    const { Ajv2020, addFormats } = loadAjv();
    const ajv = new Ajv2020({ strict: true, allErrors: true });
    addFormats(ajv);
    state = { ajv, validators: new Map(), metaKeywords: new Set() };
    ajvStates.set(dir, state);
  }
  return state;
}

/**
 * 스키마 위치의 x-* 키(꼴에 맞고 아직 키워드가 아닌 것)를 값 검사 없는 키워드로 등록한다(ajv strict — 모르는 키워드는 예외).
 * 순회는 assertSupported와 같다 — 스키마 객체의 키 · properties의 각 값 · items · 스키마인 additionalProperties. properties 아래의 속성
 * 이름과 examples · default · enum · const 값 안의 키는 스키마 키가 아니므로 훑지 않는다(꼴 밖의 이름을 addKeyword하면 "invalid name"
 * 예외다). 꼴 밖의 x- 스키마 키는 등록하지 않는다 — 컴파일이 strict 예외로 끝난다(검사기 CLI는 그런 스키마를 2로 막는다).
 * 등록한 이름은 state.metaKeywords에도 적는다 — ajv 8.20의 getKeyword는 정의 없이 더한 키워드에 false를 돌려주고(RULES.all에
 * 들지 않는다) 같은 이름을 다시 addKeyword하면 "already defined" 예외다(두 번째 스키마 파일에서 실측).
 */
function registerMetadataKeywords(state, node) {
  if (!isPlainObject(node)) return;
  for (const key of Object.keys(node)) {
    if (isMetadataXKey(key) && !state.metaKeywords.has(key) && !state.ajv.getKeyword(key)) {
      state.ajv.addKeyword(key);
      state.metaKeywords.add(key);
    }
  }
  if (isPlainObject(node.properties)) {
    for (const child of Object.values(node.properties)) registerMetadataKeywords(state, child);
  }
  if (Object.hasOwn(node, "items")) registerMetadataKeywords(state, node.items);
  if (Object.hasOwn(node, "additionalProperties")) registerMetadataKeywords(state, node.additionalProperties);
}

function validatorFor(state, file) {
  let validate = state.validators.get(file);
  if (validate === undefined) {
    const schema = JSON.parse(fs.readFileSync(file, "utf8"));
    registerMetadataKeywords(state, schema);
    validate = state.ajv.compile(schema);
    state.validators.set(file, validate);
  }
  return validate;
}

function isRegularFile(file) {
  try {
    return fs.statSync(file, { throwIfNoEntry: false })?.isFile() ?? false;
  } catch {
    return false;
  }
}

/** ajv 오류 → { path, message } — required는 빠진 속성 이름을 이스케이프해 경로에 붙인다 */
function toErrors(ajvErrors, prefix) {
  return (ajvErrors ?? []).map((error) => {
    let pointer = error.instancePath;
    if (error.keyword === "required" && typeof error.params?.missingProperty === "string") {
      pointer += `/${escapeToken(error.params.missingProperty)}`;
    }
    return { path: `${prefix}${pointer}`, message: oneLine(`${error.keyword}: ${error.message}`) };
  });
}

function validateData(state, dir, type, data) {
  const file = path.resolve(dir, `${type}.json`);
  if (type.includes("\0") || path.dirname(file) !== dir) {
    return [
      {
        path: "#/type",
        message: oneLine(`schema-path: type ${JSON.stringify(type)}이 스키마 디렉터리 바로 아래의 파일을 가리키지 않는다`),
      },
    ];
  }
  if (!isRegularFile(file)) {
    return [
      {
        path: "#/type",
        message: oneLine(`schema-missing: 토픽 ${JSON.stringify(type)}의 스키마 파일(${path.basename(file)})이 없다`),
      },
    ];
  }
  const validate = validatorFor(state, file);
  return validate(data) ? [] : toErrors(validate.errors, "#/data");
}

/** CloudEvents 봉투를 _envelope.json으로, data를 schemas/<type>.json으로 검증한다 */
export function validateEvent(envelope, { schemasDir = DEFAULT_SCHEMAS_DIR } = {}) {
  const dir = path.resolve(schemasDir);
  const state = ajvStateFor(dir);
  const errors = [];
  const validateEnvelope = validatorFor(state, path.join(dir, ENVELOPE_FILE));
  if (!validateEnvelope(envelope)) errors.push(...toErrors(validateEnvelope.errors, "#"));
  const isObject = isPlainObject(envelope);
  const type = isObject ? envelope.type : undefined;
  const typeFailed = errors.some((error) => error.path === "#/type");
  if (isObject && Object.hasOwn(envelope, "data") && typeof type === "string" && !typeFailed) {
    errors.push(...validateData(state, dir, type, envelope.data));
  }
  return { ok: errors.length === 0, errors };
}

// ---------- CLI ----------
function parseCliArgs(argv) {
  const values = { base: undefined, head: undefined };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "-h" || arg === "--help") return { help: true };
    const match = /^--(base|head)(?:=(.*))?$/su.exec(arg);
    if (match === null) return { error: `알 수 없는 인자: ${JSON.stringify(arg)}` };
    const name = match[1];
    let value = match[2];
    if (value === undefined) {
      index += 1;
      value = argv[index];
    }
    if (value === undefined || value === "") return { error: `--${name}에 디렉터리를 준다` };
    if (values[name] !== undefined) return { error: `--${name}를 두 번 줬다` };
    values[name] = value;
  }
  for (const name of ["base", "head"]) {
    if (values[name] === undefined) return { error: `--${name}가 없다` };
  }
  return values;
}

function isDirectory(dir) {
  try {
    return fs.statSync(dir, { throwIfNoEntry: false })?.isDirectory() ?? false;
  } catch {
    return false;
  }
}

function writeLines(stream, lines) {
  if (lines.length > 0) stream.write(`${lines.join("\n")}\n`);
}

function main(argv) {
  const args = parseCliArgs(argv);
  if (args.help) {
    writeLines(process.stdout, [USAGE]);
    return 0;
  }
  if (args.error !== undefined) {
    writeLines(process.stderr, [`${PROG}: 사용법 오류 — ${oneLine(args.error)}`, USAGE]);
    return 2;
  }
  for (const name of ["base", "head"]) {
    if (!isDirectory(args[name])) {
      writeLines(process.stderr, [`${PROG}: --${name} 디렉터리가 없다(또는 디렉터리가 아니다): ${oneLine(args[name])}`]);
      return 2;
    }
  }
  let result;
  try {
    result = compareDirectories(args.base, args.head);
  } catch (error) {
    writeLines(process.stderr, [`${PROG}: 검사하지 못했다(exit 2) — ${oneLine(error.message)}`]);
    return 2;
  }
  const { violations, added, checked } = result;
  writeLines(
    process.stdout,
    violations.map((item) => `${oneLine(item.file)} ${oneLine(item.path)} ${item.kind} ${item.message}`),
  );
  const summary = [`${PROG}: checked ${checked} · added ${added.length} · violations ${violations.length}`];
  if (added.length > 0) summary.push(`${PROG}: added — ${added.map(oneLine).join(", ")}`);
  if (violations.length > 0) {
    summary.push(
      `${PROG}: 호환성 위반 — 필드 삭제 · 타입 변경 · required 변경 · enum 값 삭제 · 스키마 파일 삭제는 금지다. 새 토픽(…v2)과 이중 발행 기간으로 대신한다(contracts/events.md §호환성 규칙)`,
    );
  }
  writeLines(process.stderr, summary);
  return violations.length > 0 ? 1 : 0;
}

/** 직접 실행됐는가 — import.meta.main(Node 22.18 · 24.2+)이 없으면 argv[1]과 이 파일을 비교한다(가드가 꺼져 조용히 통과하지 않게) */
function isEntryPoint() {
  if (typeof import.meta.main === "boolean") return import.meta.main;
  const entry = process.argv[1];
  if (entry === undefined) return false;
  try {
    return fs.realpathSync(entry) === fs.realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (isEntryPoint()) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (error) {
    process.stderr.write(`${PROG}: 예상 밖 오류(exit 2) — ${oneLine(error?.stack ?? error)}\n`);
    process.exitCode = 2;
  }
}
