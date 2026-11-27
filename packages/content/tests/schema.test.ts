// packages/content/tests/schema.test.ts — T090 조각 ②(시험 먼저 · vitest). 짝 구현 = packages/content/src/schema.ts.
//
// 정본: specs/003-platform-foundation/design/t090-design.md — D4(code 어휘 · 한 경로 하나 · 순서) · D5(프런트매터 스키마 · zod 밖 규칙
//   · url 원 문자열 · userinfo · host) · D10(JSON Schema 내보내기 · CLI · isEntryPoint) · D12 ② sx-1–sx-7 · §6-2(url format 되살림)
//   · §6-4(description의 url host) · D13 mu-29 · mu-30 · mu-31 · mu-49 · mu-53 · mu-68 · mu-69 · mu-70 · mu-76.
//   sx-8 · sx-9는 설계 표 밖의 확장이다 — D4 code 어휘 · 필드 issue 순서를 검증 함수 단위로 먼저 고정한다(로더 단위 짝 = lx-7 · lx-8b).
//   sx-10도 확장이다 — url 판정 보조 둘(D5 url 원 문자열 · userinfo = D6 unsafe-url 1 · 4단계와 같은 집합 · mdx.ts가 함께 쓴다)을 직접 고정한다.
//   리뷰 고침(2026-11-27): sx-9 「계약 키 순 목록 하나」(설계 정정 노트 4 — CONTRACT_KEYS 내보내기 · 얼림 · zod shape 순) · sx-1
//   description 「url host」(§6-4 문구 — 리뷰 C RC-4 · 변이 n1).
//   description url host 문구 = 「점이 있는 도메인 이름 꼴」(결정 K-6 · 정정 노트 6 — sx-1 단언 「url host」 포함은 그대로).
//   자식 env 고침(2026-11-27): childEnv가 FORCE_COLOR도 지운다(결정 K-11 — 색 env 충돌 경고가 자식 stderr 0 단언을 깨지 않게).
// 빨강(구현 전): 이 파일을 수집할 때 ../src/schema.ts 로드가 실패한다(구현 없음).
//
// 이 시험이 쓰는 schema.ts 표면:
//   CONTRACT_KEYS => content.md 계약 키 순(title … sources)의 얼린 목록 — zod study 필드 shape 키 순에서 얻는다(loader.ts가 함께 쓴다)
//   validateFrontmatter(data, collection) => { field, code }[] — zod + zod 밖 규칙 · 한 경로에 issue 하나(D4 표의 가장 위 행)
//     · 순서 = 문서에 나온 키 순 → 없는 키는 계약 키 순으로 뒤 · 배열 첨자는 수로 비교 · 부모 경로가 자식보다 앞.
//   studyJsonSchema() => JSON Schema 객체(머리 키 $schema · $id · title · description 순)
//   renderStudySchema() => JSON.stringify(studyJsonSchema(), null, 2) + '\n' — 커밋 파일 schemas/study.schema.json의 바이트
//   CLI: node src/schema.ts [--out <dir>] — stdout 한 줄 'content-schema wrote=study.schema.json bytes=<n>' · 인자 오류 exit 2
// 시험 단언은 값을 출력하지 않는다 — 실패 메시지는 사례 id · 파일 · 필드 · 규칙만(URL · 경로 값은 시험 안에서 만들고 싣지 않는다).

import { Buffer } from 'node:buffer';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

import Ajv2020Module from 'ajv/dist/2020.js';
import addFormatsModule from 'ajv-formats';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { parseDocument } from 'yaml';

import {
  CONTRACT_KEYS as EXPORTED_CONTRACT_KEYS,
  hasHttpUserinfo,
  hasUnsafeUrlChar,
  renderStudySchema,
  studyJsonSchema,
  validateFrontmatter,
} from '../src/schema.ts';

type FieldIssue = { field: string; code: string };
type Json = Record<string, unknown>;

const SCHEMA_TS = fileURLToPath(new URL('../src/schema.ts', import.meta.url));
const SCHEMAS_DIR = fileURLToPath(new URL('../schemas/', import.meta.url));
const SCHEMA_JSON = join(SCHEMAS_DIR, 'study.schema.json');
const FIXTURES = fileURLToPath(new URL('./fixtures/', import.meta.url));
const NOTES = fileURLToPath(new URL('../../../content/study/', import.meta.url));
const REGENERATE = '재생성: pnpm --filter @jt/content --fail-if-no-match schema';

// 특수 글자는 소스에 날 글자 · 역슬래시-u 이스케이프로 두지 않는다(loader.test.ts:78 선례)
const BS = String.fromCharCode(92);
const TAB = String.fromCharCode(9);
const LF = String.fromCharCode(10);
const NBSP = String.fromCharCode(0xa0);
const SOH = String.fromCharCode(0x01);
const DEL = String.fromCharCode(0x7f);
const NEL = String.fromCharCode(0x85);
const ZWNBSP = String.fromCharCode(0xfeff);

const CONTRACT_KEYS = ['title', 'description', 'pubDate', 'updatedDate', 'tags', 'series', 'seriesOrder', 'draft', 'change', 'sources'];
const REQUIRED_KEYS = ['title', 'description', 'pubDate', 'tags', 'draft', 'change', 'sources'];
const URL_PATTERN = `^[Hh][Tt][Tt][Pp][Ss]?:${BS}/${BS}/`;
const END_ANCHOR = `$(?!${BS}n)`;

// JSON Schema의 pattern 위치 — 로더가 정한 것(D5 events.md:28 꼴)과 zod가 정한 날짜 패턴
const NONBLANK_POINTERS = [
  '/properties/title/pattern',
  '/properties/description/pattern',
  '/properties/tags/items/pattern',
  '/properties/series/pattern',
  '/properties/sources/items/properties/title/pattern',
];
const END_ANCHORED_POINTERS = ['/properties/change/pattern', '/properties/sources/items/properties/path/pattern'];
const URL_POINTER = '/properties/sources/items/properties/url/pattern';
const LOADER_POINTERS = [...NONBLANK_POINTERS, ...END_ANCHORED_POINTERS, URL_POINTER];
const ZOD_DATE_POINTERS = ['/properties/pubDate/pattern', '/properties/updatedDate/pattern'];

const temps: string[] = [];

beforeEach(() => {
  // 개발자 env의 JT_CONTENT_ROOT가 시험에 끼지 않게 지운다(afterEach가 되돌린다 — loader.test.ts:86–:89 꼴)
  vi.stubEnv('JT_CONTENT_ROOT', undefined);
});

afterEach(() => {
  vi.unstubAllEnvs();
  for (const dir of temps.splice(0)) rmSync(dir, { recursive: true, force: true });
});

/** afterEach가 지우는 빈 임시 디렉터리 */
function tempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), 'jt-schema-'));
  temps.push(dir);
  return dir;
}

/** 값 없는 단언 — 실패하면 label만 남는다 */
function check(cond: boolean, label: string): void {
  expect(cond, label).toBe(true);
}

const fc = (issue: FieldIssue): string => `${issue.field} ${issue.code}`;

/** 유효한 study 프런트매터(계약 키 순) — 사례마다 새 객체 */
function base(): Json {
  return {
    title: '제목',
    description: '한 문장.',
    pubDate: '2026-05-01',
    tags: [],
    draft: false,
    change: '003-platform-foundation',
    sources: [],
  };
}

/** sources 원소 하나를 단 유효한 프런트매터 */
function withSource(source: Json): Json {
  return { ...base(), sources: [{ title: '출처', ...source }] };
}

/** 프런트매터를 뺀 base */
function without(...keys: string[]): Json {
  const data = base();
  for (const key of keys) delete data[key];
  return data;
}

// ---------- ajv(2020 + formats) — 내보낸 JSON Schema로 판정한다 ----------

type AjvLike = { compile: (schema: unknown) => (data: unknown) => unknown };
const Ajv2020 = ((Ajv2020Module as unknown as { default?: unknown }).default ?? Ajv2020Module) as unknown as new (opts: object) => AjvLike;
const addFormats = ((addFormatsModule as unknown as { default?: unknown }).default ?? addFormatsModule) as unknown as (ajv: AjvLike) => void;

let jsonValidator: ((data: unknown) => unknown) | undefined;

/** 내보낸 스키마(메모리 — sx-2가 커밋 파일과 바이트로 묶는다)로 data를 판정한다 */
function jsonValid(data: unknown): boolean {
  if (jsonValidator === undefined) {
    const ajv = new Ajv2020({ strict: true, allErrors: true });
    addFormats(ajv);
    jsonValidator = ajv.compile(studyJsonSchema());
  }
  return jsonValidator(data) === true;
}

// ---------- JSON Schema의 pattern 모으기 · 꼴 판정 ----------

/** 스키마 안의 모든 pattern 문자열과 JSON 포인터 */
function collectPatterns(node: unknown, pointer = '', out: Array<{ pointer: string; pattern: unknown }> = []): Array<{ pointer: string; pattern: unknown }> {
  if (Array.isArray(node)) {
    node.forEach((child, index) => collectPatterns(child, `${pointer}/${index}`, out));
  } else if (node !== null && typeof node === 'object') {
    for (const [key, child] of Object.entries(node)) {
      if (key === 'pattern') out.push({ pointer: `${pointer}/${key}`, pattern: child });
      else collectPatterns(child, `${pointer}/${key}`, out);
    }
  }
  return out;
}

function patternAt(schema: Json, pointer: string): string {
  const found = collectPatterns(schema).find((entry) => entry.pointer === pointer);
  check(found !== undefined && typeof found.pattern === 'string', `pattern 없음 ${pointer}`);
  return found?.pattern as string;
}

const isPrintableAscii = (text: string): boolean => [...text].every((ch) => ch.charCodeAt(0) >= 0x20 && ch.charCodeAt(0) <= 0x7e);

/** 이스케이프 · 문자 클래스를 따라 읽어 축약 클래스(\d \w \s 와 대문자)와 클래스 밖 맨 '.'을 찾는다 */
function scanPattern(pattern: string): { shorthand: boolean; bareDot: boolean } {
  let inClass = false;
  let shorthand = false;
  let bareDot = false;
  for (let i = 0; i < pattern.length; i += 1) {
    const ch = pattern[i];
    if (ch === BS) {
      const next = pattern[i + 1] ?? '';
      if (next !== '' && 'dDwWsS'.includes(next)) shorthand = true;
      i += 1;
    } else if (inClass) {
      if (ch === ']') inClass = false;
    } else if (ch === '[') {
      inClass = true;
    } else if (ch === '.') {
      bareDot = true;
    }
  }
  return { shorthand, bareDot };
}

// ---------- 픽스처 프런트매터(D5 판독 규율 — YAML 1.2 core) ----------

function frontmatterOf(path: string, label: string): Json {
  const lines = readFileSync(path, 'utf8').split(/\r\n|\r|\n/);
  const end = lines.indexOf('---', 1);
  check(lines[0] === '---' && end > 0, `프런트매터 울타리 ${label}`);
  const doc = parseDocument(lines.slice(1, end).join('\n'), {
    version: '1.2',
    schema: 'core',
    uniqueKeys: true,
    strict: true,
    prettyErrors: false,
    logLevel: 'error',
  });
  check(doc.errors.length === 0 && doc.warnings.length === 0, `프런트매터 YAML ${label}`);
  const data = doc.toJS() as unknown;
  check(data !== null && typeof data === 'object' && !Array.isArray(data), `프런트매터 매핑 ${label}`);
  return data as Json;
}

// ---------- 자식 프로세스(process.execPath · env에서 JT_CONTENT_ROOT · NODE_OPTIONS · FORCE_COLOR 삭제) ----------

function childEnv(): NodeJS.ProcessEnv {
  const env = { ...process.env };
  // FORCE_COLOR도 지운다 — NO_COLOR · NODE_DISABLE_COLORS와 함께 있으면 Node가 자식 stderr에 env 충돌 경고를 찍어 stderr 0 단언이
  // 환경 탓으로 깨진다(컨트롤러 관찰 2026-11-27 · 결정 K-11). 색 env는 시험 대상 계약이 아니다.
  for (const key of Object.keys(env)) {
    const upper = key.toUpperCase();
    if (upper === 'JT_CONTENT_ROOT' || upper === 'NODE_OPTIONS' || upper === 'FORCE_COLOR') delete env[key];
  }
  return env;
}

type Run = { status: number | null; stdout: string; stderr: string };

function runNode(args: string[], cwd: string): Run {
  const result = spawnSync(process.execPath, args, { cwd, env: childEnv(), encoding: 'utf8', timeout: 60_000 });
  return { status: result.status, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

/** 패키지 schemas/ 상태(목록 · 커밋 파일 mtime) — 쓰기 0 판정용 */
function schemasState(): string {
  if (!existsSync(SCHEMAS_DIR)) return 'absent';
  const names = readdirSync(SCHEMAS_DIR).sort().join('|');
  const mtime = existsSync(SCHEMA_JSON) ? String(statSync(SCHEMA_JSON).mtimeMs) : '-';
  return `${names} ${mtime}`;
}

const committedBytes = (): Buffer | null => (existsSync(SCHEMA_JSON) ? readFileSync(SCHEMA_JSON) : null);

// =====================================================================================================

describe('sx-1 내보낸 JSON Schema의 꼴', () => {
  it('sx-1 머리 키 · $schema · $id · type · additionalProperties · required · properties', () => {
    const schema = studyJsonSchema() as Json;
    expect(Object.keys(schema).slice(0, 4), 'sx-1 머리 키 순서').toEqual(['$schema', '$id', 'title', 'description']);
    check(schema.$schema === 'https://json-schema.org/draft/2020-12/schema', 'sx-1 $schema 2020-12');
    check(schema.$id === 'https://joshuatech.dev/content/study/frontmatter/v1', 'sx-1 $id');
    check(typeof schema.title === 'string' && schema.title !== '', 'sx-1 title');
    check(schema.type === 'object', 'sx-1 type object');
    check(schema.additionalProperties === false, 'sx-1 additionalProperties false');
    expect([...(schema.required as string[])].sort(), 'sx-1 required').toEqual([...REQUIRED_KEYS].sort());
    expect(Object.keys(schema.properties as Json).sort(), 'sx-1 properties = 계약 10').toEqual([...CONTRACT_KEYS].sort());
  });

  it('sx-1 sources.items strict · url 속성 = pattern + 되살린 format uri(§6-2)', () => {
    const items = ((studyJsonSchema().properties as Json).sources as Json).items as Json;
    check(items.additionalProperties === false, 'sx-1 sources.items.additionalProperties false');
    expect(Object.keys(items.properties as Json).sort(), 'sx-1 sources.items 키').toEqual(['path', 'title', 'url']);
    expect(items.required, 'sx-1 sources.items required').toEqual(['title']);
    const url = (items.properties as Json).url;
    check(isDeepStrictEqual(url, { type: 'string', pattern: URL_PATTERN, format: 'uri' }), 'sx-1 url 속성 {type, pattern, format: uri}');
  });

  it('sx-1 description 문구 — zod 밖 규칙 · ECMA-262(u) · url host(§6-4 — 런타임 전용 규칙)', () => {
    const description = studyJsonSchema().description;
    check(typeof description === 'string', 'sx-1 description 문자열');
    check((description as string).includes('zod 밖 규칙'), 'sx-1 description 「zod 밖 규칙」');
    check((description as string).includes('ECMA-262(u)'), 'sx-1 description 「ECMA-262(u)」');
    check((description as string).includes('url host'), 'sx-1 description 「url host」(§6-4 · 리뷰 C RC-4)');
  });

  it('sx-1 pattern 위치 = 로더 8 + zod 날짜 2 · 모두 ASCII', () => {
    const patterns = collectPatterns(studyJsonSchema());
    expect(patterns.map((entry) => entry.pointer).sort(), 'sx-1 pattern 위치').toEqual([...LOADER_POINTERS, ...ZOD_DATE_POINTERS].sort());
    for (const { pointer, pattern } of patterns) {
      check(typeof pattern === 'string' && isPrintableAscii(pattern), `sx-1 pattern ASCII(0x20–0x7E) ${pointer}`);
    }
  });

  it('sx-1 로더가 정한 pattern — 축약 클래스 0 · 클래스 밖 맨 . 0 · 끝 앵커 꼴', () => {
    const schema = studyJsonSchema();
    for (const pointer of LOADER_POINTERS) {
      const { shorthand, bareDot } = scanPattern(patternAt(schema, pointer));
      check(!shorthand, `sx-1 축약 클래스(d w s) 0 ${pointer}`);
      check(!bareDot, `sx-1 클래스 밖 맨 . 0 ${pointer}`);
    }
    for (const pointer of END_ANCHORED_POINTERS) {
      const pattern = patternAt(schema, pointer);
      check(pattern.endsWith(END_ANCHOR) && pattern.indexOf('$') === pattern.length - END_ANCHOR.length, `sx-1 끝 앵커 $(?!\\n) 하나 ${pointer}`);
    }
    for (const pointer of [...NONBLANK_POINTERS, URL_POINTER]) {
      check(!patternAt(schema, pointer).includes('$'), `sx-1 $ 0 ${pointer}`);
    }
  });
});

describe('sx-2 신선도 — 메모리 내보내기 = 커밋 파일 바이트', () => {
  it('sx-2 renderStudySchema = JSON.stringify(studyJsonSchema(), null, 2) + LF 하나', () => {
    const text = renderStudySchema();
    check(text === `${JSON.stringify(studyJsonSchema(), null, 2)}\n`, 'sx-2 직렬화 꼴');
    check(text.endsWith('\n') && !text.endsWith('\n\n') && !text.includes('\r'), 'sx-2 LF · 끝 줄바꿈 하나');
  });

  it('sx-2 커밋 파일 schemas/study.schema.json = 메모리 내보내기(바이트)', () => {
    const committed = committedBytes();
    check(committed !== null && Buffer.compare(committed, Buffer.from(renderStudySchema(), 'utf8')) === 0, `sx-2 커밋 파일 ≠ 메모리 내보내기 — ${REGENERATE}`);
  });
});

describe('sx-3 CLI(process.execPath — 타입 스트리핑)', () => {
  it('sx-3 --out <tmp> → exit 0 · stdout 한 줄(파일 이름만) · stderr 0 · 파일 = 커밋 바이트 · 임시 파일 0', () => {
    const out = tempDir();
    const run = runNode([SCHEMA_TS, '--out', out], tempDir());
    check(run.status === 0, 'sx-3 exit 0');
    check(run.stderr === '', 'sx-3 stderr 빈 값');
    const written = existsSync(join(out, 'study.schema.json')) ? readFileSync(join(out, 'study.schema.json')) : null;
    check(written !== null, 'sx-3 파일 쓰기');
    check(run.stdout === `content-schema wrote=study.schema.json bytes=${written?.length ?? -1}\n`, 'sx-3 stdout 한 줄 꼴');
    check(!run.stdout.includes(out) && !run.stdout.includes(BS), 'sx-3 stdout 경로 0');
    expect(readdirSync(out), 'sx-3 출력 디렉터리 = 파일 하나(임시 파일 0)').toEqual(['study.schema.json']);
    check(written !== null && Buffer.compare(written, Buffer.from(renderStudySchema(), 'utf8')) === 0, 'sx-3 파일 = 메모리 내보내기');
    const committed = committedBytes();
    check(written !== null && committed !== null && Buffer.compare(written, committed) === 0, `sx-3 파일 = 커밋 바이트 — ${REGENERATE}`);
  }, 60_000);

  it.each([
    ['--bogus', ['--bogus']],
    ['--out 값 없음', ['--out']],
    ['--out 빈 값', ['--out', '']],
    ['--out 뒤 남는 인자', ['--out', '.', 'extra']],
  ])('sx-3 인자 오류(%s) → exit 2 · stdout 0 · stderr 한 줄 · 쓰기 0', (_label, args) => {
    const before = schemasState();
    const cwd = tempDir();
    const run = runNode([SCHEMA_TS, ...(args as string[])], cwd);
    check(run.status === 2, 'sx-3 exit 2');
    check(run.stdout === '', 'sx-3 stdout 0');
    check(run.stderr === 'content-schema: error usage\n', 'sx-3 stderr 한 줄');
    check(schemasState() === before, 'sx-3 패키지 schemas/ 쓰기 0');
    expect(readdirSync(cwd), 'sx-3 cwd 쓰기 0').toEqual([]);
  }, 60_000);

  it('sx-3 확장: --out이 정규 파일 → exit 2 · stdout 0 · stderr 한 줄(경로 0)', () => {
    const dir = tempDir();
    const blocker = join(dir, 'not-a-dir');
    writeFileSync(blocker, 'x');
    const run = runNode([SCHEMA_TS, '--out', blocker], tempDir());
    check(run.status === 2, 'sx-3 확장 exit 2');
    check(run.stdout === '', 'sx-3 확장 stdout 0');
    check(run.stderr === 'content-schema: error write\n', 'sx-3 확장 stderr 한 줄');
    expect(readdirSync(dir), 'sx-3 확장 임시 파일 0').toEqual(['not-a-dir']);
  }, 60_000);
});

describe('sx-4 import 무실행', () => {
  it('sx-4 자식에서 import만 → exit 0(내보내기 있음) · stdout 0 · stderr 0 · 파일 쓰기 0', () => {
    const before = schemasState();
    const cwd = tempDir();
    const code = [
      `const m = await import(${JSON.stringify(pathToFileURL(SCHEMA_TS).href)});`,
      "if (typeof m.renderStudySchema !== 'function' || typeof m.validateFrontmatter !== 'function') process.exit(3);",
    ].join('\n');
    const run = runNode(['--input-type=module', '-e', code], cwd);
    check(run.status === 0, 'sx-4 exit 0 · 내보내기 있음');
    check(run.stdout === '', 'sx-4 stdout 0');
    check(run.stderr === '', 'sx-4 stderr 0');
    check(schemasState() === before, 'sx-4 패키지 schemas/ 쓰기 0');
    expect(readdirSync(cwd), 'sx-4 cwd 쓰기 0').toEqual([]);
  }, 60_000);
});

describe('sx-5 ajv(2020 + formats) 대조 — 내보낸 스키마 · 검증 함수', () => {
  const VALID: Array<[string, string]> = [
    ['실제 노트 001', join(NOTES, '001-claude-setup.mdx')],
    ['실제 노트 002', join(NOTES, '002-smoke.mdx')],
    ['i18n 001 ko', join(FIXTURES, 'i18n', 'study', '001-hello.mdx')],
    ['i18n 001 en', join(FIXTURES, 'i18n', 'study', '001-hello.en.mdx')],
    ['i18n 002', join(FIXTURES, 'i18n', 'study', '002-ko-only.mdx')],
    ['drafts 001', join(FIXTURES, 'drafts', 'study', '001-public.mdx')],
    ['drafts 002', join(FIXTURES, 'drafts', 'study', '002-draft.mdx')],
  ];
  const violation = (name: string): [string, string] => [`ld-10 ${name}`, join(FIXTURES, 'schema-violations', 'study', `${name}.mdx`)];
  const INVALID: Array<[string, string]> = [
    '003-bad-change',
    '008-unknown-key',
    '009-url-js',
    '010-url-data',
    '011-url-scheme-relative',
    '012-path-absolute',
    '013-path-backslash',
    '014-path-dotdot',
    '015-path-js',
    '016-path-url',
  ].map(violation);
  const CROSS_RULE: Array<[string, string]> = [
    ...['001-series-only', '002-series-order-only', '004-source-both', '005-source-none'].map(violation),
    ['updated-before', join(FIXTURES, 'updated-before', 'study', '001-updated-before.mdx')],
  ];

  it.each(VALID)('sx-5 valid %s — ajv 통과 · 검증 함수 issue 0', (label, path) => {
    const data = frontmatterOf(path, label);
    check(jsonValid(data), `sx-5 ajv valid ${label}`);
    expect(validateFrontmatter(data, 'study').map(fc), `sx-5 검증 함수 ${label}`).toEqual([]);
  });

  it.each(INVALID)('sx-5 invalid %s — ajv 거부 · 검증 함수 거부', (label, path) => {
    const data = frontmatterOf(path, label);
    check(!jsonValid(data), `sx-5 ajv invalid ${label}`);
    check(validateFrontmatter(data, 'study').length > 0, `sx-5 검증 함수 거부 ${label}`);
  });

  it.each([
    ['url 경로 가운데 공백', 'https://example.com/a b'],
    ['url 경로 가운데 탭', `https://example.com/a${TAB}b`],
  ])('sx-5 invalid %s — 되살린 format uri가 거부 · 검증 함수 format', (label, url) => {
    const data = withSource({ url });
    check(!jsonValid(data), `sx-5 ajv invalid ${label}`);
    expect(validateFrontmatter(data, 'study').map(fc), `sx-5 검증 함수 ${label}`).toEqual(['sources.0.url format']);
  });

  it.each(CROSS_RULE)('sx-5 한계(교차 규칙) %s — ajv 통과 · 검증 함수만 거부', (label, path) => {
    const data = frontmatterOf(path, label);
    check(jsonValid(data), `sx-5 ajv valid(한계) ${label}`);
    check(validateFrontmatter(data, 'study').length > 0, `sx-5 검증 함수 거부 ${label}`);
  });

  it.each([
    ['userinfo', 'https://user:tok@example.com/'],
    ['localhost', 'https://localhost/x'],
    ['IP 주소', 'http://192.0.2.1/'],
    ['끝 점 FQDN', 'https://example.com./x'],
    ['xn-- 최상위 도메인', 'https://example.xn--3e0b707e/'],
  ])('sx-5 한계(url) %s — ajv 통과 · 검증 함수만 format', (label, url) => {
    const data = withSource({ url });
    check(jsonValid(data), `sx-5 ajv valid(한계) ${label}`);
    expect(validateFrontmatter(data, 'study').map(fc), `sx-5 검증 함수 ${label}`).toEqual(['sources.0.url format']);
  });
});

describe('sx-6 path — zod(검증 함수)와 JSON Schema가 같은 판정', () => {
  it.each([
    ['일반', 'specs/x.md'],
    ['점 디렉터리', '.github/x'],
    ['점 셋', '...'],
    ['점 둘 + 글자', '..a'],
  ])('sx-6 허용 %s', (label, path) => {
    const data = withSource({ path });
    expect(validateFrontmatter(data, 'study').map(fc), `sx-6 검증 함수 허용 ${label}`).toEqual([]);
    check(jsonValid(data), `sx-6 ajv 허용 ${label}`);
  });

  it.each([
    ['점 하나', '.'],
    ['점 둘', '..'],
    ['가운데 점 세그먼트', 'a/./b'],
    ['가운데 점 둘 세그먼트', 'a/../b'],
    ['빈 세그먼트', 'a//b'],
    ['절대 경로', '/x'],
    ['역슬래시', `a${BS}b`],
    ['콜론', 'x:y'],
    ['끝 줄바꿈 하나', `specs/x.md${LF}`],
  ])('sx-6 거부 %s', (label, path) => {
    const data = withSource({ path });
    expect(validateFrontmatter(data, 'study').map(fc), `sx-6 검증 함수 거부 ${label}`).toEqual(['sources.0.path format']);
    check(!jsonValid(data), `sx-6 ajv 거부 ${label}`);
  });
});

describe('sx-7 url — 검증 함수(zod + zod 밖 규칙)와 JSON Schema', () => {
  it.each([
    ['https', 'https://example.com/x'],
    ['대문자 스킴 · 호스트', 'HTTP://EXAMPLE.COM/'],
    ['path의 @', 'https://www.npmjs.com/package/@shikijs/rehype'],
    ['query의 @', 'https://example.com/?q=a@b'],
    ['fragment의 @', 'https://example.com/#a@b'],
  ])('sx-7 허용 %s — 둘 다 통과', (label, url) => {
    const data = withSource({ url });
    expect(validateFrontmatter(data, 'study').map(fc), `sx-7 검증 함수 허용 ${label}`).toEqual([]);
    check(jsonValid(data), `sx-7 ajv 허용 ${label}`);
  });

  const BOTH_REJECT: Array<[string, string]> = [
    ['javascript 스킴', 'javascript:alert(1)'],
    ['data 스킴', 'data:text/html,x'],
    ['스킴 상대', '//host/x'],
    ['ftp 스킴', 'ftp://x'],
    ['앞 공백', ' https://example.com/x'],
    ['뒤 공백', 'https://example.com/x '],
    ['앞 탭', `${TAB}https://example.com/x`],
    ['뒤 탭', `https://example.com/x${TAB}`],
    ['앞 NBSP', `${NBSP}https://example.com/x`],
    ['뒤 NBSP', `https://example.com/x${NBSP}`],
    ['역슬래시', `https://example.com${BS}x`],
    ['경로 가운데 U+0001', `https://example.com/a${SOH}b`],
    ['경로 가운데 DEL', `https://example.com/a${DEL}b`],
    ['경로 가운데 U+0085', `https://example.com/a${NEL}b`],
    ['경로 가운데 U+FEFF', `https://example.com/a${ZWNBSP}b`],
  ];

  it.each(BOTH_REJECT)('sx-7 거부 %s — 검증 함수 format · ajv 거부', (label, url) => {
    const data = withSource({ url });
    expect(validateFrontmatter(data, 'study').map(fc), `sx-7 검증 함수 거부 ${label}`).toEqual(['sources.0.url format']);
    check(!jsonValid(data), `sx-7 ajv 거부 ${label}`);
  });

  it('sx-7 한 경로 하나 — javascript: + 탭 → (sources.0.url, format) 하나(zod issue · 원 문자열 규칙이 함께 난다)', () => {
    expect(validateFrontmatter(withSource({ url: `javascript:x${TAB}` }), 'study').map(fc), 'sx-7 한 경로 하나').toEqual(['sources.0.url format']);
  });

  it.each([
    ['userinfo', 'https://user:tok@example.com/'],
    ['localhost', 'https://localhost/x'],
    ['IP 주소', 'http://192.0.2.1/'],
    ['끝 점 FQDN', 'https://example.com./x'],
    ['xn-- 최상위 도메인', 'https://example.xn--3e0b707e/'],
  ])('sx-7 검증 함수만 거부 %s → format', (label, url) => {
    expect(validateFrontmatter(withSource({ url }), 'study').map(fc), `sx-7 검증 함수 ${label}`).toEqual(['sources.0.url format']);
  });
});

describe('sx-8 확장 — D4 code 어휘(검증 함수 단위 · 행마다)', () => {
  it.each([
    ['title 빈 값 → empty 하나(길이 · 패턴 issue 둘 → 하나)', { ...base(), title: '' }, ['title empty']],
    ['title 공백만 → empty', { ...base(), title: '  ' }, ['title empty']],
    ['title null → type', { ...base(), title: null }, ['title type']],
    ['title 키 없음 → missing', without('title'), ['title missing']],
    ['tags 문자열 → type', { ...base(), tags: 'x' }, ['tags type']],
    ['tags 빈 원소 → tags.1 empty', { ...base(), tags: ['a', ''] }, ['tags.1 empty']],
    ['seriesOrder 0 → range', { ...base(), series: 's', seriesOrder: 0 }, ['seriesOrder range']],
    ['seriesOrder 1.5 → type', { ...base(), series: 's', seriesOrder: 1.5 }, ['seriesOrder type']],
    ['seriesOrder 안전 정수 밖 → range', { ...base(), series: 's', seriesOrder: 2 ** 53 }, ['seriesOrder range']],
    ['pubDate 없는 날 → format', { ...base(), pubDate: '2026-02-30' }, ['pubDate format']],
    ['pubDate 수 → type', { ...base(), pubDate: 20260501 }, ['pubDate type']],
    ['draft 문자열 → type', { ...base(), draft: 'false' }, ['draft type']],
    ['change 꼴 → format', { ...base(), change: 'Bad_Change' }, ['change format']],
    ['최상위 모르는 키 → unknown-key', { ...base(), extraKey: 1 }, ['extraKey unknown-key']],
    ['sources 원소 모르는 키 → 경로 unknown-key', withSource({ path: 'a', foo: 1 }), ['sources.0.foo unknown-key']],
    ['sources 원소 객체 아님 → type(source-kind 0)', { ...base(), sources: [1] }, ['sources.0 type']],
    ['sources 원소 title 없음 → missing', { ...base(), sources: [{ url: 'https://example.com/' }] }, ['sources.0.title missing']],
    ['series만 → 빠진 쪽 seriesOrder series-pair', { ...base(), series: 's' }, ['seriesOrder series-pair']],
    ['seriesOrder만 → 빠진 쪽 series series-pair', { ...base(), seriesOrder: 1 }, ['series series-pair']],
    ['updatedDate < pubDate → date-order', { ...base(), updatedDate: '2026-04-30' }, ['updatedDate date-order']],
    ['updatedDate = pubDate → 0', { ...base(), updatedDate: '2026-05-01' }, []],
    ['updatedDate 꼴 오류 + 앞선 날 → format만(date-order 0)', { ...base(), updatedDate: '2026-02-30' }, ['updatedDate format']],
    ['sources path · url 둘 다 → source-kind', withSource({ path: 'a', url: 'https://example.com/' }), ['sources.0 source-kind']],
    ['sources path · url 둘 다 없음 → source-kind', withSource({}), ['sources.0 source-kind']],
  ] as Array<[string, Json, string[]]>)('sx-8 %s', (label, data, expected) => {
    expect(validateFrontmatter(data, 'study').map(fc), `sx-8 ${label}`).toEqual(expected);
  });

  it('sx-8 change 필수는 study만 — blog · projects는 선택(〔90-3〕) · 꼴은 모두', () => {
    expect(validateFrontmatter(without('change'), 'study').map(fc), 'sx-8 study change 없음').toEqual(['change missing']);
    expect(validateFrontmatter(without('change'), 'blog').map(fc), 'sx-8 blog change 없음').toEqual([]);
    expect(validateFrontmatter(without('change'), 'projects').map(fc), 'sx-8 projects change 없음').toEqual([]);
    expect(validateFrontmatter({ ...base(), change: 'Bad_Change' }, 'blog').map(fc), 'sx-8 blog change 꼴').toEqual(['change format']);
  });

  it('sx-8 프로그래머 오류 → TypeError(값 없는 메시지)', () => {
    const errorOf = (run: () => unknown): unknown => {
      try {
        run();
      } catch (error) {
        return error;
      }
      return undefined;
    };
    const unknownCollection = errorOf(() => validateFrontmatter(base(), 'zz-needle-collection' as never));
    check(unknownCollection instanceof TypeError, 'sx-8 모르는 컬렉션 TypeError');
    check(!String((unknownCollection as Error | undefined)?.message).includes('zz-needle'), 'sx-8 메시지 값 0');
    for (const [label, data] of [['null', null], ['배열', []], ['문자열', 'x']] as Array<[string, unknown]>) {
      check(errorOf(() => validateFrontmatter(data, 'study')) instanceof TypeError, `sx-8 매핑 아님 TypeError ${label}`);
    }
  });

  it('sx-8 NONBLANK = ECMAScript 공백 집합의 여집합(BMP 전부 · 내보낸 pattern을 u 플래그로)', () => {
    const nonblank = new RegExp(patternAt(studyJsonSchema(), '/properties/title/pattern'), 'u');
    const whitespace = /\s/u;
    let mismatches = 0;
    const spaces: string[] = [];
    for (let code = 0; code <= 0xffff; code += 1) {
      const ch = String.fromCharCode(code);
      if (nonblank.test(ch) === whitespace.test(ch)) mismatches += 1;
      if (whitespace.test(ch)) spaces.push(ch);
    }
    check(mismatches === 0, 'sx-8 NONBLANK 집합 = 공백 여집합');
    check(spaces.length === 25, 'sx-8 공백 집합 크기(ECMAScript)');
    for (const ch of spaces) {
      const label = `U+${ch.charCodeAt(0).toString(16).padStart(4, '0')}`;
      expect(validateFrontmatter({ ...base(), title: ch + ch }, 'study').map(fc), `sx-8 공백만 title ${label}`).toEqual(['title empty']);
      expect(validateFrontmatter({ ...base(), title: `a${ch}` }, 'study').map(fc), `sx-8 공백 섞인 title ${label}`).toEqual([]);
      check(!jsonValid({ ...base(), title: ch + ch }), `sx-8 ajv 공백만 title ${label}`);
    }
  });
});

describe('sx-9 확장 — 필드 issue 순서(D4 순서 3)', () => {
  const rest = { description: 'd', pubDate: '2026-05-01', tags: [], draft: false, change: '003-x' };

  it('sx-9 계약 키 순 목록 하나(정정 노트 4) — 내보낸 CONTRACT_KEYS = content.md 계약 키 순 · 얼림 · zod shape 순(= 내보낸 properties 순)', () => {
    check(Array.isArray(EXPORTED_CONTRACT_KEYS), 'sx-9 CONTRACT_KEYS 내보내기(배열)');
    expect([...EXPORTED_CONTRACT_KEYS], 'sx-9 CONTRACT_KEYS = content.md 계약 키 순').toEqual(CONTRACT_KEYS);
    check(Object.isFrozen(EXPORTED_CONTRACT_KEYS), 'sx-9 CONTRACT_KEYS 얼림');
    expect(Object.keys(studyJsonSchema().properties as Json), 'sx-9 내보낸 properties 순 = CONTRACT_KEYS(zod shape 키 순)').toEqual([
      ...EXPORTED_CONTRACT_KEYS,
    ]);
  });

  it('sx-9 문서에 나온 최상위 키 순', () => {
    const sourcesFirst = { sources: [{ title: 't', url: 'ftp://x' }], ...rest, title: '' };
    const titleFirst = { title: '', ...rest, sources: [{ title: 't', url: 'ftp://x' }] };
    expect(validateFrontmatter(sourcesFirst, 'study').map(fc), 'sx-9 sources 먼저').toEqual(['sources.0.url format', 'title empty']);
    expect(validateFrontmatter(titleFirst, 'study').map(fc), 'sx-9 title 먼저').toEqual(['title empty', 'sources.0.url format']);
  });

  it('sx-9 없는 키는 있는 키 뒤 · 계약 키 순(series-pair의 빠진 쪽 포함)', () => {
    const missingTwo = { change: '003-x', tags: [1], sources: [], description: 'd', pubDate: '2026-05-01' };
    expect(validateFrontmatter(missingTwo, 'study').map(fc), 'sx-9 없는 키 뒤').toEqual(['tags.0 type', 'title missing', 'draft missing']);
    const pairMissing = { seriesOrder: 1, pubDate: '2026-02-30', description: 'd', tags: [], draft: false, change: '003-x', sources: [] };
    expect(validateFrontmatter(pairMissing, 'study').map(fc), 'sx-9 series-pair 빠진 쪽').toEqual([
      'pubDate format',
      'title missing',
      'series series-pair',
    ]);
  });

  it('sx-9 배열 첨자는 수로 비교(sources.2 < sources.10)', () => {
    const sources = Array.from({ length: 11 }, (_unused, index) => ({ title: 't', url: index === 2 || index === 10 ? 'ftp://x' : 'https://example.com/' }));
    expect(validateFrontmatter({ ...base(), sources }, 'study').map(fc), 'sx-9 첨자 수 비교').toEqual(['sources.2.url format', 'sources.10.url format']);
  });

  it('sx-9 부모 경로가 자식보다 앞 · 하위 키는 문서 순 · 없는 하위 키는 뒤', () => {
    expect(validateFrontmatter(withSource({ title: '', path: 'a', url: 'https://example.com/' }), 'study').map(fc), 'sx-9 부모 먼저').toEqual([
      'sources.0 source-kind',
      'sources.0.title empty',
    ]);
    expect(validateFrontmatter({ ...base(), sources: [{ url: 'ftp://x', title: '' }] }, 'study').map(fc), 'sx-9 하위 키 문서 순 url 먼저').toEqual([
      'sources.0.url format',
      'sources.0.title empty',
    ]);
    expect(validateFrontmatter({ ...base(), sources: [{ title: '', url: 'ftp://x' }] }, 'study').map(fc), 'sx-9 하위 키 문서 순 title 먼저').toEqual([
      'sources.0.title empty',
      'sources.0.url format',
    ]);
    expect(validateFrontmatter({ ...base(), sources: [{ url: 'ftp://x' }] }, 'study').map(fc), 'sx-9 없는 하위 키 뒤').toEqual([
      'sources.0.url format',
      'sources.0.title missing',
    ]);
  });
});

describe('sx-10 확장 — url 판정 보조(D5 url 원 문자열 · userinfo = D6 unsafe-url 1 · 4단계)', () => {
  it('sx-10 hasUnsafeUrlChar = ECMAScript 공백 ∪ C0 ∪ DEL ∪ C1 ∪ 역슬래시(BMP 전부)', () => {
    const whitespace = /\s/u;
    let mismatches = 0;
    for (let code = 0; code <= 0xffff; code += 1) {
      const ch = String.fromCharCode(code);
      const expected = whitespace.test(ch) || code <= 0x1f || code === 0x7f || (code >= 0x80 && code <= 0x9f) || code === 0x5c;
      if (hasUnsafeUrlChar(`https://example.com/a${ch}b`) !== expected) mismatches += 1;
    }
    check(mismatches === 0, 'sx-10 원 문자열 집합');
    check(!hasUnsafeUrlChar('https://example.com/x?q=1#f'), 'sx-10 평범한 url 허용');
  });

  it.each([
    ['userinfo', 'https://user:tok@example.com/', true],
    ['슬래시 없는 http', 'http:user@example.com', true],
    ['대문자 스킴', 'HTTPS://user@example.com/', true],
    ['슬래시 셋', 'https:///user@example.com/', true],
    ['path의 @', 'https://www.npmjs.com/package/@shikijs/rehype', false],
    ['query의 @', 'https://example.com/?q=a@b', false],
    ['fragment의 @', 'https://example.com/#a@b', false],
    ['mailto(http 밖)', 'mailto:a@example.com', false],
    ['xmpp(http 밖)', 'xmpp:a@b.c', false],
    ['스킴 없음', '//user@example.com/', false],
  ] as Array<[string, string, boolean]>)('sx-10 hasHttpUserinfo %s', (label, url, expected) => {
    check(hasHttpUserinfo(url) === expected, `sx-10 userinfo ${label}`);
  });
});
