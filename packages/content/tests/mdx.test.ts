// packages/content/tests/mdx.test.ts — T090 조각 ③(시험 먼저 · vitest). 짝 구현 = packages/content/src/mdx.ts.
//
// 정본: specs/003-platform-foundation/design/t090-design.md — D3(파이프라인) · D5(BOM · 줄 · 울타리 · YAML 판독) · D6(본문 거부 규칙
//   · 위치 없는 노드의 줄 · 열) · D7(html · 헤딩 · Shiki · 읽기 시간 · 각주 라벨) · D12 ③ mx-1–mx-8 · §6-1(mx-4 기대 html · 위치 없는
//   노드) · §6-3(날 DEL) · §6-7(--- !!map) · §6-9(위치 없는 노드의 열) · D13 mu-3 · mu-8 · mu-26 · mu-28 · mu-46 · mu-47 · mu-49–mu-51
//   · mu-54–mu-59 · mu-68 · mu-69 · mu-71–mu-74.
//   「확장」 표시 = 설계 표 밖에 더한 사례: 파일 함수의 encoding · yaml 갈래 · 블록 안 --- !!map(파일 단위) · 중첩 키 꼴 · null 키
//   · 하이라이터 지연 생성(자식 — 언어 모듈 import 0) · 목록 밖 언어 · 위치 없는 노드의 열 값(order-A · order-B) · 같은 줄 열 순
//   · D6 표 기본 규칙(단위) · 프로그래머 오류.
//   리뷰 고침(2026-11-27): mx-2 「정정 노트 1」 YAML 1.1 태그 = 모르는 태그(루트 · 중첩 → yaml) + 허용 짝(core 태그 — 확장 !!float 포함)
//   · mu-79 · mu-56b(고침 뒤 동등) / 확장(리뷰 C RC-2): 위치 없는 노드의 줄 — CRLF · CR 파일 7-x2 + 셋째 줄(줄 끝 셈 · 변이 g2a · g2b)
//   · 문자 참조 줄 끝의 조상 끝 줄 · 끝 열 자르기(변이 g3 · g3b).
//   자식 env 고침(2026-11-27): childEnv가 FORCE_COLOR도 지운다(결정 K-11 — 색 env 충돌 경고가 자식 stderr 0 단언을 깨지 않게).
// 빨강(구현 전): 이 파일을 수집할 때 ../src/mdx.ts 로드가 실패한다(구현 없음).
//
// 이 시험이 쓰는 mdx.ts 표면:
//   parseFile(bytes) => { ok: true, data, tree, body } | { ok: false, field: 'file', code: 'encoding' }
//                       | { ok: false, field: 'frontmatter', code: 'fence' | 'yaml' }  — D3 3-1–3-4 · 3-6(body = 정렬된 본문 위반)
//   readYamlBlock(block) => { ok: true, data } | { ok: false }                         — D5 YAML 판독 규율(블록 문자열 입력)
//   parseMarkdown(text) => mdast Root(remark-parse + remark-frontmatter yaml + remark-gfm — 원문 전체 · 줄 = 원문 줄)
//   bodyViolations(tree) => { code, line, column }[]                                   — D6 · 순서 = 줄 → 열 → 규칙 순(D4 순서 4)
//   compile(tree, lang) => Promise<{ html, headings, readingTime }>                    — D7
//   readingTime(tree, lang) => 분(정수 ≥ 1) · LANGS = ['ko', 'en', 'ja'] · CODE_LANGS = Shiki 언어 고정 목록
// 시험 단언은 값을 출력하지 않는다 — 실패 메시지는 사례 id · 규칙 · 줄 · 열만(원문 · URL은 시험 안에서 만들고 싣지 않는다).
// VD-T090-2(Shiki 첫 생성 시간)는 mx-6 첫 사례의 소요로 잰다(verbose 리포터 — 이 파일에서 하이라이터를 처음 만드는 사례다).

import { Buffer } from 'node:buffer';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { inspect, isDeepStrictEqual } from 'node:util';

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { parseDocument } from 'yaml';

import { CODE_LANGS, LANGS, bodyViolations, compile, parseFile, parseMarkdown, readingTime, readYamlBlock } from '../src/mdx.ts';
import type { Lang } from '../src/mdx.ts';

type Violation = { code: string; line: number; column: number };
type FileOutcome = { ok: boolean; field?: string; code?: string; data?: unknown; body?: readonly Violation[] };

const MDX_TS = fileURLToPath(new URL('../src/mdx.ts', import.meta.url));
const MX4 = fileURLToPath(new URL('./fixtures/t090-mx-4/', import.meta.url));

// 특수 글자는 소스에 날 글자 · 역슬래시-u 이스케이프로 두지 않는다(loader.test.ts:78 선례)
const BS = String.fromCharCode(92);
const TAB = String.fromCharCode(9);
const NBSP = String.fromCharCode(0xa0);
const DEL = String.fromCharCode(0x7f);
const NEL = String.fromCharCode(0x85);
const BOM_BYTES = Buffer.from([0xef, 0xbb, 0xbf]);
const IMPORT = "import x from 'y'";

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
  const dir = mkdtempSync(join(tmpdir(), 'jt-mdx-'));
  temps.push(dir);
  return dir;
}

/** 값 없는 단언 — 실패하면 label만 남는다 */
function check(cond: boolean, label: string): void {
  expect(cond, label).toBe(true);
}

const NOT_THROWN = Symbol('not-thrown');

/** run이 던지거나 거부한 값(동기 throw도 받는다) · 아무것도 던지지 않으면 NOT_THROWN */
async function failure(run: () => unknown): Promise<unknown> {
  try {
    await run();
  } catch (error) {
    return error;
  }
  return NOT_THROWN;
}

const encode = (text: string): Uint8Array => Buffer.from(text, 'utf8');

/** 유효한 study 프런트매터(1–9행) · 10행 빈 줄 · 본문은 11행부터(lx-7 꼴) */
const FRONT = ['---', 'title: "제목"', 'description: "한 문장."', 'pubDate: 2026-05-01', 'tags: []', 'draft: false', 'change: "001-a"', 'sources: []', '---'];
const FRONT_DATA = { title: '제목', description: '한 문장.', pubDate: '2026-05-01', tags: [], draft: false, change: '001-a', sources: [] };
const note = (body: readonly string[], eol = '\n'): string => [...FRONT, '', ...body, ''].join(eol);

/** 위치 없는 노드 사례 원문 — 1–3행 프런트매터 · 4행 빈 줄 · 5행부터 본문(D12 mx-8 · 〔① 탐침〕 꼴) */
const probe = (...body: string[]): string => ['---', 'title: "a"', '---', '', ...body].join('\n');

/** probe와 같은 꼴 · 줄 끝만 eol(전체 줄 끝이 같은 꼴 — CRLF · CR 파일) */
const probeEol = (eol: string, ...body: string[]): string => ['---', 'title: "a"', '---', '', ...body].join(eol);

const outcome = (result: FileOutcome): string => (result.ok ? 'ok' : `${result.field} ${result.code}`);
const fileOutcome = (bytes: Uint8Array): FileOutcome => parseFile(bytes) as unknown as FileOutcome;
const at = (v: Violation): string => `${v.code} ${v.line}`;
const atCol = (v: Violation): string => `${v.code} ${v.line}:${v.column}`;
const bodyOf = (text: string): string[] => (bodyViolations(parseMarkdown(text)) as Violation[]).map(at);
const bodyColsOf = (text: string): string[] => (bodyViolations(parseMarkdown(text)) as Violation[]).map(atCol);

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

/** 자식이 import할 mdx.ts URL(JS 문자열 리터럴) */
const MDX_URL = JSON.stringify(pathToFileURL(MDX_TS).href);

// =====================================================================================================

describe('mx-1 울타리 · 줄(파일 함수 parseFile — D3 3-1–3-4 · D5)', () => {
  it('mx-1 정상 노트 → ok · data(날짜 = 문자열) · 본문 위반 0', () => {
    const result = fileOutcome(encode(note(['## 문제', '', '본문이다.'])));
    expect(outcome(result), 'mx-1 정상').toBe('ok');
    check(isDeepStrictEqual(result.data, FRONT_DATA), 'mx-1 data = 프런트매터 객체(날짜 = 문자열)');
    expect((result.body ?? []).map(at), 'mx-1 본문 위반').toEqual([]);
  });

  it.each([
    ['LF', '\n'],
    ['CRLF', '\r\n'],
    ['CR', '\r'],
  ])('mx-1 %s 노트 → ok · 같은 data · 본문 위반 줄 = 파일 줄(〔A-9〕)', (label, eol) => {
    const result = fileOutcome(encode(note(['문단 첫 줄', '<b>x</b>', '', '[x](javascript:a)'], eol)));
    expect(outcome(result), `mx-1 ${label}`).toBe('ok');
    check(isDeepStrictEqual(result.data, FRONT_DATA), `mx-1 ${label} data`);
    expect((result.body ?? []).map(at), `mx-1 ${label} 본문 줄`).toEqual(['raw-html 12', 'raw-html 12', 'unsafe-url 14']);
  });

  const FENCE_CASES: Array<[string, Uint8Array]> = [
    ['BOM + ---(BOM은 지우지 않는다 — N-3)', Buffer.concat([BOM_BYTES, Buffer.from(note(['본문.']), 'utf8')])],
    ['첫 줄 "--- "(뒤 공백)', encode(note(['본문.']).replace(/^---/, '--- '))],
    ['첫 줄 ---js', encode(note(['본문.']).replace(/^---/, '---js'))],
    ['닫는 --- 없음', encode(['---', 'title: "제목"', '', '본문.', ''].join('\n'))],
    ['빈 파일', encode('')],
    ['블록 안 "--- " 줄(뒤에 정확한 --- 닫는 줄이 있어도 — micromark가 그 줄에서 닫는다)', encode(['---', 'title: ""', '--- ', 'description: x', '---', '', '본문.', ''].join('\n'))],
    ['블록 안 "---<TAB>" 줄(뒤에 정확한 --- 닫는 줄이 있어도)', encode(['---', 'title: ""', `---${TAB}`, 'description: x', '---', '', '본문.', ''].join('\n'))],
  ];

  it.each(FENCE_CASES)('mx-1 %s → (frontmatter, fence)', (label, bytes) => {
    expect(outcome(fileOutcome(bytes)), `mx-1 ${label}`).toBe('frontmatter fence');
  });

  it('mx-1 확장: 깨진 UTF-8 → (file, encoding) · 같은 원문의 정상 바이트는 ok', () => {
    const good = Buffer.from(note(['본문.']), 'utf8');
    expect(outcome(fileOutcome(good)), 'mx-1 확장 정상 바이트').toBe('ok');
    const broken = Buffer.concat([good.subarray(0, 4), Buffer.from([0xff]), good.subarray(4)]);
    expect(outcome(fileOutcome(broken)), 'mx-1 확장 깨진 UTF-8').toBe('file encoding');
  });

  it('mx-1 확장: 블록 안 --- !!map 줄 + 다음 줄 매핑 → (frontmatter, yaml)(micromark는 닫지 않고 yaml은 받는다 — 판독 1 · §6-7)', () => {
    const text = ['---', '--- !!map', ...FRONT.slice(1, 8), '---', '', '본문.', ''].join('\n');
    expect(outcome(fileOutcome(encode(text))), 'mx-1 확장 --- !!map').toBe('frontmatter yaml');
  });

  it('mx-1 확장: 중복 키 → (frontmatter, yaml) · 울타리 · 판독 통과 노트는 ok(양성 짝)', () => {
    expect(outcome(fileOutcome(encode(note(['본문.'])))), 'mx-1 확장 양성').toBe('ok');
    const text = ['---', 'title: "a"', 'title: "b"', '---', '', '본문.', ''].join('\n');
    expect(outcome(fileOutcome(encode(text))), 'mx-1 확장 중복 키').toBe('frontmatter yaml');
  });
});

describe('mx-2 YAML 판독 규율(블록 함수 readYamlBlock — D5 판독 1–6)', () => {
  const KEY64 = 'a'.repeat(64);
  const BOMB = [
    'a: &a ["x", "x", "x", "x", "x", "x", "x", "x", "x"]',
    'b: &b [*a, *a, *a, *a, *a, *a, *a, *a, *a]',
    'c: &c [*b, *b, *b, *b, *b, *b, *b, *b, *b]',
    'd: &d [*c, *c, *c, *c, *c, *c, *c, *c, *c]',
    'e: &e [*d, *d, *d, *d, *d, *d, *d, *d, *d]',
    'f: [*e, *e, *e, *e, *e, *e, *e, *e, *e]',
  ].join('\n');
  const DIRECTIVE_DOC = '%YAML 1.1\n--- \ntitle: x';
  const END_DOTS = 'title: x\n...';

  const REJECT: Array<[string, string]> = [
    ['매핑 아님 — 빈 블록', ''],
    ['매핑 아님 — 스칼라', 'x'],
    ['매핑 아님 — 목록', '- a'],
    ['%YAML 1.1 + "--- " 줄 + 매핑(판독 1만 잡는 꼴)', DIRECTIVE_DOC],
    ['블록 마지막 줄 ...(판독 1만 잡는 꼴)', END_DOTS],
    ['키 a-b', 'a-b: x'],
    ['키 한글', '제목: x'],
    ['키 1(수)', '1: x'],
    ['키 true(불리언)', 'true: x'],
    ['키 <<', '<<: x'],
    ['키 65자', `${KEY64}a: x`],
    ['컬렉션 키', '? [a]\n: x'],
    ['앵커 &a(별칭 없음)', 'title: &a x'],
    ['해결되는 별칭', 'x: &a 1\ny: *a'],
    ['별칭 폭탄', BOMB],
    ['확장: 중첩 키 꼴(sources 원소의 a-b)', 'sources:\n  - title: x\n    a-b: 1'],
    ['확장: null 키(~)', '~: x'],
    ['확장: !!js/function(경고 = 판독 2)', "title: !!js/function 'x'"],
    ['확장: 중복 키(따옴표 키 포함)', 'title: a\n"title": b'],
    // 정정 노트 1: YAML 1.1 태그 = 모르는 태그(resolveKnownTags: false → TAG_RESOLVE_FAILED 경고 → 판독 2) · mu-79
    ['정정 노트 1: 루트 !!set(? 줄 — 매핑의 하위 형이라 판독 3이 못 막는다)', '!!set\n? a\n? b'],
    ['정정 노트 1: 루트 !!omap', '!!omap\n- a: 1'],
    ['정정 노트 1: 루트 !!pairs', '!!pairs\n- a: 1'],
    ['정정 노트 1: 루트 !!timestamp', '!!timestamp 2026-01-01'],
    ['정정 노트 1: 루트 !!binary', '!!binary aGk='],
    ['정정 노트 1: 중첩 pubDate: !!timestamp', 'pubDate: !!timestamp 2026-01-01'],
    ['정정 노트 1: 중첩 sources: !!pairs []', 'sources: !!pairs []'],
    ['정정 노트 1: 중첩 s: !!set {}', 's: !!set {}'],
    ['정정 노트 1: 중첩 b: !!binary', 'b: !!binary aGk='],
  ];

  it.each(REJECT)('mx-2 %s → yaml', (label, block) => {
    check(readYamlBlock(block).ok === false, `mx-2 ${label} → yaml`);
  });

  it('mx-2 사실 — 판독 1만 잡는 두 꼴은 yaml 2.9.1이 오류 · 경고 없이 매핑으로 받는다(판독 1이 없으면 통과한다)', () => {
    const options = { version: '1.2', schema: 'core', uniqueKeys: true, strict: true, prettyErrors: false, logLevel: 'error' } as const;
    for (const [label, block] of [['%YAML 1.1 + "--- "', DIRECTIVE_DOC], ['끝 ...', END_DOTS]] as const) {
      const doc = parseDocument(block, options);
      check(doc.errors.length === 0 && doc.warnings.length === 0, `mx-2 사실 ${label} 오류 · 경고 0`);
    }
  });

  it('mx-2 미해결 별칭 title: *nope → yaml · 던지지 않는다 · 반환 값에 바늘 0(〔B-3〕)', () => {
    let thrown: unknown = NOT_THROWN;
    let result: unknown = null;
    try {
      result = readYamlBlock('title: *nope');
    } catch (error) {
      thrown = error;
    }
    check(thrown === NOT_THROWN, 'mx-2 미해결 별칭 — 던지지 않는다');
    check((result as { ok?: unknown } | null)?.ok === false, 'mx-2 미해결 별칭 → yaml');
    check(!inspect(result, { depth: null }).toLowerCase().includes('nope'), 'mx-2 미해결 별칭 — 반환 값에 바늘 0');
  });

  it('mx-2 허용 — 따옴표 키(큰 · 작은따옴표) · 64자 키 · !!str · 날짜 = 문자열', () => {
    check(isDeepStrictEqual(readYamlBlock('"title": x\n\'draft\': true'), { ok: true, data: { title: 'x', draft: true } }), 'mx-2 따옴표 키 허용');
    check(isDeepStrictEqual(readYamlBlock(`${KEY64}: x`), { ok: true, data: { [KEY64]: 'x' } }), 'mx-2 64자 키 허용');
    check(isDeepStrictEqual(readYamlBlock('title: !!str 2026-01-01'), { ok: true, data: { title: '2026-01-01' } }), 'mx-2 !!str 허용');
    check(isDeepStrictEqual(readYamlBlock('pubDate: 2026-01-01'), { ok: true, data: { pubDate: '2026-01-01' } }), 'mx-2 날짜 = 문자열');
  });

  it('mx-2 허용 짝(정정 노트 1) — core 태그는 그대로 풀린다: 루트 !!map + 매핑 · 중첩 !!int · !!bool · !!null · !!seq · 확장: !!float', () => {
    check(isDeepStrictEqual(readYamlBlock('!!map\ntitle: x'), { ok: true, data: { title: 'x' } }), 'mx-2 루트 !!map + 매핑 허용');
    check(isDeepStrictEqual(readYamlBlock('n: !!int 3'), { ok: true, data: { n: 3 } }), 'mx-2 중첩 !!int 허용');
    check(isDeepStrictEqual(readYamlBlock('n: !!bool true'), { ok: true, data: { n: true } }), 'mx-2 중첩 !!bool 허용');
    check(isDeepStrictEqual(readYamlBlock('n: !!null'), { ok: true, data: { n: null } }), 'mx-2 중첩 !!null 허용');
    check(isDeepStrictEqual(readYamlBlock('n: !!seq [a]'), { ok: true, data: { n: ['a'] } }), 'mx-2 중첩 !!seq 허용');
    check(isDeepStrictEqual(readYamlBlock('n: !!float 1.5'), { ok: true, data: { n: 1.5 } }), 'mx-2 확장 중첩 !!float 허용');
  });
});

describe('mx-3 경고 누출 0(D5 — parseDocument · logLevel error · VD-T090-5)', () => {
  // 자식 프로세스 인자로도 넘기므로 ASCII만 쓴다
  const JS_FUNCTION_NOTE = ['---', "title: !!js/function 'x'", 'description: "d"', '---', '', 'body.', ''].join('\n');
  const COLLECTION_KEY_NOTE = ['---', '? [a]', ': x', '---', '', 'body.', ''].join('\n');

  it('mx-3 같은 프로세스 — !!js/function · 컬렉션 키 파일 → yaml · process warning 0회(다음 틱까지 기다린다)', async () => {
    const seen: unknown[] = [];
    const onWarning = (warning: unknown): void => {
      seen.push(warning);
    };
    process.on('warning', onWarning);
    let outcomes: string[] = [];
    try {
      outcomes = [outcome(fileOutcome(encode(JS_FUNCTION_NOTE))), outcome(fileOutcome(encode(COLLECTION_KEY_NOTE)))];
      await new Promise((resolve) => setImmediate(resolve));
    } finally {
      process.off('warning', onWarning);
    }
    expect(outcomes, 'mx-3 판정').toEqual(['frontmatter yaml', 'frontmatter yaml']);
    check(seen.length === 0, 'mx-3 process warning 0회');
  });

  it('mx-3 자식 프로세스(process.execPath — 타입 스트리핑) — 같은 두 파일 → yaml · warning 0 · stderr 0 · exit 0', () => {
    const code = [
      `const m = await import(${MDX_URL});`,
      'let warnings = 0;',
      "process.on('warning', () => { warnings += 1; });",
      'const encoder = new TextEncoder();',
      "const outcome = (r) => (r.ok ? 'ok' : r.field + ' ' + r.code);",
      `const a = outcome(m.parseFile(encoder.encode(${JSON.stringify(JS_FUNCTION_NOTE)})));`,
      `const b = outcome(m.parseFile(encoder.encode(${JSON.stringify(COLLECTION_KEY_NOTE)})));`,
      'await new Promise((resolve) => setImmediate(resolve));',
      "process.stdout.write([a, b, warnings].join('|'));",
    ].join('\n');
    const cwd = tempDir();
    const run = runNode(['--input-type=module', '-e', code], cwd);
    check(run.status === 0, 'mx-3 자식 exit 0');
    check(run.stdout === 'frontmatter yaml|frontmatter yaml|0', 'mx-3 자식 판정 yaml 둘 · warning 0');
    check(run.stderr === '', 'mx-3 자식 stderr 0');
    expect(readdirSync(cwd), 'mx-3 자식 cwd 쓰기 0').toEqual([]);
  }, 60_000);
});

describe('mx-4 html(〔A-4〕 · 〔V2-2〕 — 기대값 = tests/fixtures/t090-mx-4 · 라이브러리 직접 산출)', () => {
  const INPUT = readFileSync(join(MX4, 'input.md'), 'utf8');
  const expected = (lang: string): string => readFileSync(join(MX4, `expected-${lang}.html`), 'utf8');
  const FOOTNOTE_LABEL: Record<string, string> = { ko: '각주', en: 'Footnotes', ja: '脚注' };
  const BACK_LABELS: Record<string, string[]> = {
    ko: ['1번 참조로 돌아가기', '1-2번 참조로 돌아가기', '2번 참조로 돌아가기'],
    ja: ['参照 1 に戻る', '参照 1-2 に戻る', '参照 2 に戻る'],
    en: ['Back to reference 1', 'Back to reference 1-2', 'Back to reference 2'],
  };

  it.each([...LANGS])('mx-4 %s — 컴파일한 html = 기대 html(정확 비교 · 헤딩 id · 각주 섹션 포함) · 프런트매터를 붙여도 같다', async (lang) => {
    const want = expected(lang);
    const bare = await compile(parseMarkdown(INPUT), lang);
    check(bare.html === want, `mx-4 ${lang} html = expected-${lang}.html`);
    const fronted = await compile(parseMarkdown(`---\ntitle: "a"\n---\n\n${INPUT}`), lang);
    check(fronted.html === want, `mx-4 ${lang} 프런트매터를 붙여도 같은 html`);
  });

  it.each([...LANGS])('mx-4 %s — 기대 html 사실(끝 줄바꿈 0 · < → &#x3C; · & → &#x26; · > " 그대로 · 각주 라벨 h2 · 되돌림 라벨 정확 문자열)', async (lang) => {
    const { html } = await compile(parseMarkdown(INPUT), lang);
    check(!html.endsWith('\n'), `mx-4 ${lang} 끝 줄바꿈 0`);
    check(html.includes('문자 참조 &#x3C;b> &#x26; "따옴표"는 글자다.'), `mx-4 ${lang} 글 이스케이프 꼴`);
    check(html.includes(`<h2 class="sr-only" id="footnote-label">${FOOTNOTE_LABEL[lang]}</h2>`), `mx-4 ${lang} 각주 라벨 h2`);
    (BACK_LABELS[lang] ?? []).forEach((label, index) => {
      check(html.includes(`aria-label="${label}"`), `mx-4 ${lang} 되돌림 라벨 #${index + 1}`);
    });
  });

  it('mx-4 확장: 같은 트리를 세 lang으로 차례로 컴파일해도 각 기대 html과 같고 트리는 그대로다(compile은 받은 mdast를 바꾸지 않는다)', async () => {
    const tree = parseMarkdown(INPUT);
    const before = structuredClone(tree);
    for (const lang of LANGS) {
      const { html } = await compile(tree, lang);
      check(html === expected(lang), `mx-4 확장 같은 트리 ${lang} html = expected-${lang}.html`);
    }
    check(isDeepStrictEqual(tree, before), 'mx-4 확장 컴파일 뒤 트리 그대로');
  });

  it('mx-4 이스케이프 — 글 &lt;script&gt; · 코드 스팬 <script> · alt 속 " → <script 0 · 이스케이프 꼴(hast-util-to-html 기본)', async () => {
    const { html } = await compile(parseMarkdown('글 &lt;script&gt; 와 `<script>` 와 ![a"b](./x.png)'), 'ko');
    check(!html.toLowerCase().includes('<script'), 'mx-4 이스케이프 — <script 0');
    check(html === '<p>글 &#x3C;script> 와 <code>&#x3C;script></code> 와 <img src="./x.png" alt="a&#x22;b"></p>', 'mx-4 이스케이프 꼴');
  });
});

describe('mx-5 헤딩(D7 — FR-029 목차 = headings)', () => {
  it('mx-5 h1 · h4 제외 · h2 · h3 문서 순 · 각주 라벨 h2 제외 · 중복 -1 · 인라인 요소는 글자로', async () => {
    const text = ['# 큰 제목', '', '## 둘째', '', '### 셋째', '', '#### 넷째', '', '## 둘째', '', '## a *b* `c`', '', '각주[^1].', '', '[^1]: 내용.'].join('\n');
    const { headings, html } = await compile(parseMarkdown(text), 'ko');
    expect(headings.map((h) => `${h.depth} ${h.id}`), 'mx-5 depth · id').toEqual(['2 둘째', '3 셋째', '2 둘째-1', '2 a-b-c']);
    check(headings.map((h) => h.text).join('|') === '둘째|셋째|둘째|a b c', 'mx-5 text');
    check(html.includes('id="footnote-label"'), 'mx-5 각주 라벨 h2는 html에 있다(목차에서만 뺀다)');
  });
});

describe('mx-6 Shiki(D7 — @shikijs/rehype · github-light/dark · defaultColor false · 대체 언어 text)', () => {
  const SHIKI_PRE = '<pre class="shiki shiki-themes github-light github-dark"';
  const codeOf = (html: string): string => html.slice(html.indexOf('<code>'));
  const highlighted = (html: string): boolean => codeOf(html).includes('<span style="--shiki-light:');
  const fence = (lang: string, body: string): string => [`\`\`\`${lang}`, body, '```'].join('\n');

  it('mx-6 첫 생성(VD-T090-2 — 이 사례 소요 = 하이라이터 첫 생성 · 한도 = vitest 기본 5 s) — ```ts → 토큰(--shiki-light 변수)', async () => {
    const { html } = await compile(parseMarkdown(fence('ts', 'const a: number = 1')), 'ko');
    check(html.startsWith(SHIKI_PRE), 'mx-6 ts → shiki pre');
    check(highlighted(html), 'mx-6 ts → 토큰 style --shiki-light');
  });

  it('mx-6 ```nope → 평문(대체 언어 text) · 던지지 않음', async () => {
    const { html } = await compile(parseMarkdown(fence('nope', 'const a = 1')), 'ko');
    check(html.startsWith(SHIKI_PRE), 'mx-6 nope → shiki pre');
    check(!codeOf(html).includes('style='), 'mx-6 nope → 토큰 style 0(평문)');
    check(codeOf(html).includes('const a = 1'), 'mx-6 nope → 글자 보존');
  });

  it('mx-6 언어 없음 → shiki 평문(기본 언어 text)', async () => {
    const { html } = await compile(parseMarkdown(fence('', 'const a = 1')), 'ko');
    check(html.startsWith(SHIKI_PRE), 'mx-6 언어 없음 → shiki pre');
    check(!codeOf(html).includes('style=') && codeOf(html).includes('const a = 1'), 'mx-6 언어 없음 → 평문');
  });

  it('mx-6 인라인 코드는 그대로(shiki 0)', async () => {
    const { html } = await compile(parseMarkdown('글 `const a = 1` 끝'), 'ko');
    check(html === '<p>글 <code>const a = 1</code> 끝</p>', 'mx-6 인라인 코드 그대로');
  });

  it('mx-6 CODE_LANGS = 정확한 Shiki 이름(고정 목록 · 순서 포함)', () => {
    expect([...CODE_LANGS], 'mx-6 CODE_LANGS').toEqual(['shellscript', 'powershell', 'json', 'yaml', 'typescript', 'tsx', 'javascript', 'python', 'hcl', 'diff', 'toml', 'docker']);
  });

  const SAMPLE: Record<string, string> = {
    shellscript: 'echo hi',
    powershell: 'Write-Host hi',
    json: '{"a": 1}',
    yaml: 'a: 1',
    typescript: 'const a: number = 1',
    tsx: 'const a = <b>x</b>',
    javascript: 'const a = 1',
    python: 'def f(): pass',
    hcl: 'a = "b"',
    diff: '+ a',
    toml: 'a = 1',
    docker: 'FROM node',
  };
  const NAMES: Array<[string, string]> = [
    ['shellscript', 'shellscript'],
    ['bash', 'shellscript'],
    ['sh', 'shellscript'],
    ['shell', 'shellscript'],
    ['zsh', 'shellscript'],
    ['powershell', 'powershell'],
    ['ps', 'powershell'],
    ['ps1', 'powershell'],
    ['pwsh', 'powershell'],
    ['json', 'json'],
    ['yaml', 'yaml'],
    ['yml', 'yaml'],
    ['typescript', 'typescript'],
    ['ts', 'typescript'],
    ['cts', 'typescript'],
    ['mts', 'typescript'],
    ['tsx', 'tsx'],
    ['javascript', 'javascript'],
    ['js', 'javascript'],
    ['cjs', 'javascript'],
    ['mjs', 'javascript'],
    ['python', 'python'],
    ['py', 'python'],
    ['hcl', 'hcl'],
    ['diff', 'diff'],
    ['toml', 'toml'],
    ['docker', 'docker'],
    ['dockerfile', 'docker'],
  ];

  it.each(NAMES)('mx-6 이름 · 별칭 %s → 하이라이트(토큰 style)', async (name, id) => {
    const { html } = await compile(parseMarkdown(fence(name, SAMPLE[id] ?? '')), 'ko');
    check(highlighted(html), `mx-6 ${name} → 토큰 style`);
  });

  it('mx-6 확장: 목록 밖 언어(rust) → 평문 — 번들 언어 전부를 싣지 않는다', async () => {
    const { html } = await compile(parseMarkdown(fence('rust', 'fn main() {}')), 'ko');
    check(html.startsWith(SHIKI_PRE) && !codeOf(html).includes('style='), 'mx-6 확장 rust → 평문');
  });

  it('mx-6 확장: 코드 블록 없는 문서는 하이라이터를 만들지 않는다(자식 — 언어 모듈 import 0 → 코드 블록 뒤 > 0)', () => {
    const NO_CODE = '# Title\n\nbody `x` and [link](https://example.com).\n\n| a | b |\n|---|---|\n| 1 | 2 |';
    const WITH_CODE = '```ts\nconst a = 1\n```';
    const code = [
      "import { registerHooks } from 'node:module';",
      'let langs = 0;',
      "registerHooks({ resolve(specifier, context, nextResolve) { const result = nextResolve(specifier, context); if (result.url.includes('/@shikijs/langs/')) langs += 1; return result; } });",
      `const m = await import(${MDX_URL});`,
      `await m.compile(m.parseMarkdown(${JSON.stringify(NO_CODE)}), 'ko');`,
      'const before = langs;',
      `await m.compile(m.parseMarkdown(${JSON.stringify(WITH_CODE)}), 'ko');`,
      "process.stdout.write(before + ' ' + (langs > 0 ? 'loaded' : 'none'));",
    ].join('\n');
    const run = runNode(['--input-type=module', '-e', code], tempDir());
    check(run.status === 0, 'mx-6 확장 자식 exit 0');
    check(run.stderr === '', 'mx-6 확장 자식 stderr 0');
    check(run.stdout === '0 loaded', 'mx-6 확장 코드 블록 없는 문서 → 언어 모듈 0 · 코드 블록 뒤 적재');
  }, 60_000);
});

describe('mx-7 읽기 시간(D7 — Intl.Segmenter 낱말 ÷ 200 · 올림 · 최소 1)', () => {
  const words = (n: number): string => Array.from({ length: n }, () => '낱말').join(' ');
  const minutes = (text: string, lang: Lang = 'ko'): number => readingTime(parseMarkdown(text), lang);

  it('mx-7 빈 본문 → 1 · 프런트매터만 → 1', () => {
    expect(minutes(''), 'mx-7 빈 본문').toBe(1);
    expect(minutes(note([])), 'mx-7 프런트매터만').toBe(1);
  });

  it('mx-7 정수 · 올림 — 1 → 1 · 200 → 1 · 201 → 2 · 400 → 2 · 401 → 3', () => {
    for (const [n, want] of [[1, 1], [200, 1], [201, 2], [400, 2], [401, 3]] as const) {
      const got = minutes(words(n));
      check(Number.isInteger(got) && got === want, `mx-7 ${n}낱말 → ${want}`);
    }
  });

  it('mx-7 코드 블록 · 프런트매터 낱말 제외 · 인라인 코드는 센다', () => {
    const prose = words(1000);
    expect(minutes(prose), 'mx-7 산문 1000낱말 → 5').toBe(5);
    expect(minutes(['짧은 본문.', '', '```text', prose, '```'].join('\n')), 'mx-7 코드 블록 낱말 제외').toBe(1);
    expect(minutes(['---', `description: "${words(300)}"`, '---', '', '짧은 본문.'].join('\n')), 'mx-7 프런트매터 낱말 제외').toBe(1);
    expect(minutes(words(199) + ' `x y`'), 'mx-7 인라인 코드는 센다(199 + 2 → 2)').toBe(2);
  });

  it.each([...LANGS])('mx-7 lang별 Segmenter(%s) — 띄어쓰기 없는 일본어 201낱말 → 2(사전 분절 · 공백 나누기면 1)', (lang) => {
    expect(minutes('日本語'.repeat(201), lang), `mx-7 ${lang}`).toBe(2);
  });
});

describe('mx-8 거부 보조(D6)', () => {
  it.each([
    ['인용 둘째 줄', `> a\n> ${IMPORT}`],
    ['10. 목록 연속 줄', `10. a\n    ${IMPORT}`],
    ['각주 정의 연속 줄', `[^1]: a\n    ${IMPORT}`],
    ['게으른 연속 줄', `> a\n${IMPORT}`],
  ])('mx-8 esm 컨테이너 기준(〔A-7〕) — %s → esm(그 줄)', (label, text) => {
    expect(bodyOf(text), `mx-8 ${label}`).toEqual(['esm 2']);
  });

  it('mx-8 esm 목록 첫 줄 - import x → esm(보수 — 기록)', () => {
    expect(bodyOf('- import x'), 'mx-8 목록 첫 줄').toEqual(['esm 1']);
  });

  it('mx-8 esm 아님 — 줄 가운데 import · 첫 inline이 강조인 줄 → 0(줄 머리 import는 esm — 양성 짝)', () => {
    expect(bodyOf(IMPORT), 'mx-8 양성 — 줄 머리 import').toEqual(['esm 1']);
    expect(bodyOf(`a ${IMPORT}`), 'mx-8 줄 가운데 import').toEqual([]);
    expect(bodyOf("*import* x from 'y'"), 'mx-8 첫 inline이 강조').toEqual([]);
  });

  it.each([
    ['공백 둘 break', `a  \n${IMPORT}`],
    ['역슬래시 break', `a${BS}\n${IMPORT}`],
  ])('mx-8 esm break 뒤(〔V-B-5〕) — %s → esm(둘째 줄)', (label, text) => {
    expect(bodyOf(text), `mx-8 ${label}`).toEqual(['esm 2']);
  });

  it.each([
    ['LF', '\n'],
    ['CRLF', '\r\n'],
    ['CR', '\r'],
  ])('mx-8 esm %s 파일(프런트매터 포함 — 전체 줄 끝이 같은 꼴) — 문단 셋째 줄 import(뒤에 넷째 줄) → esm · line = 파일 줄(〔V-B-5〕)', (label, eol) => {
    // import 줄을 text의 끝 줄에 두지 않는다 — 줄 끝 셈 오류(\r\n을 둘로 · \r 빠짐)가 끝 줄 자르기에 가려지지 않게(mu-72)
    const result = fileOutcome(encode(note(['문단 첫 줄', '둘째 줄', IMPORT, '넷째 줄'], eol)));
    expect(outcome(result), `mx-8 ${label} ok`).toBe('ok');
    expect((result.body ?? []).map(at), `mx-8 ${label} esm 줄`).toEqual(['esm 13']);
  });

  it('mx-8 expression — 정의 동반 ![{a}][r](imageReference.alt — 〔V-B-13〕) · 역슬래시 중괄호(보수 — 기록)', () => {
    expect(bodyOf('![{a}][r]\n\n[r]: https://example.com/x'), 'mx-8 imageReference.alt').toEqual(['expression 1']);
    expect(bodyOf(`${BS}{`), 'mx-8 이스케이프 중괄호').toEqual(['expression 1']);
  });

  const link = (url: string): string => `[x](${url})`;

  it.each([
    ['NBSP(날 글자)', link(`https://example.com/a${NBSP}b`)],
    ['DEL(날 글자 — 꺾쇠 대상)', `[x](<https://example.com/a${DEL}b>)`],
    ['U+0085(날 글자)', link(`https://example.com/a${NEL}b`)],
    ['문자 참조 &#xFEFF;', link('https://example.com/a&#xFEFF;b')],
    ['userinfo(user:tok@)', link('https://user:tok@example.com/')],
    ['슬래시 없는 http:user@', link('http:user@example.com')],
    ['xmpp: 명시 링크(허용 목록 밖 스킴 — 〔V2-2〕)', link('xmpp:a@b.c')],
    ['확장: DEL(날 글자 — 꺾쇠 없는 대상 → GFM 자동 링크가 위치 있는 link · §6-3)', link(`https://example.com/a${DEL}b`)],
  ])('mx-8 unsafe-url — %s → unsafe-url', (label, text) => {
    expect(bodyOf(text), `mx-8 ${label}`).toEqual(['unsafe-url 1']);
  });

  it.each([
    ['문자 참조 &#127; · &#133;(U+FFFD로 해석 — 사실 고정)', `${link('https://example.com/a&#127;b')} ${link('https://example.com/a&#133;b')}`],
    ['mailto', link('mailto:a@example.com')],
    ['?q', link('?q')],
    ['빈 대상 [x]()', '[x]()'],
    ['path의 @', link('https://www.npmjs.com/package/@shikijs/rehype')],
    ['query의 @', link('https://example.com/?q=a@b')],
    ['fragment의 @', link('https://example.com/#a@b')],
  ])('mx-8 허용 — %s → 0', (label, text) => {
    expect(bodyOf(text), `mx-8 ${label}`).toEqual([]);
  });

  it('mx-8 산문 자동 링크 리터럴(〔B-16〕 · §6-1) — 산문 xmpp · http:user@ → 0(사실) · 산문 https://user@ → unsafe-url', () => {
    expect(bodyOf('see xmpp:a@b.c now'), 'mx-8 산문 xmpp').toEqual([]);
    expect(bodyOf('see http:user@example.com now'), 'mx-8 산문 http:user@').toEqual([]);
    expect(bodyOf('see https://user@example.com now'), 'mx-8 산문 https://user@').toEqual(['unsafe-url 1']);
  });

  it.each([
    ['7-x1', probe('{x} see "www.example.com" now'), ['expression 5']],
    ['7-x2', probe('a [b', 'xmpp:c@d.e'), ['unsafe-url 6']],
    ['7-x3', probe('see "www.example.com"', IMPORT), ['esm 6']],
    ['7-x4(대조 — 평범한 www · 토크나이저 링크)', probe('{x} see www.example.com now'), ['expression 5']],
  ] as Array<[string, string, string[]]>)('mx-8 위치 없는 노드의 줄(D6 · §6-1) %s', (label, text, want) => {
    expect(bodyOf(text), `mx-8 ${label}`).toEqual(want);
  });

  it.each([
    ['CRLF', '\r\n'],
    ['CR', '\r'],
  ])('mx-8 위치 없는 노드의 줄 — 7-x2 %s 파일 + 셋째 줄 → unsafe-url 6(CRLF · CR 각각 줄 끝 하나 · 셋째 줄 = 끝 줄 자르기에 가려지지 않게 — 리뷰 C RC-2 · 확장)', (label, eol) => {
    expect(bodyOf(probeEol(eol, 'a [b', 'xmpp:c@d.e', 'third')), `mx-8 7-x2 ${label} + 셋째 줄`).toEqual(['unsafe-url 6']);
  });

  it('mx-8 위치 없는 노드의 줄 — 문자 참조 줄 끝(&#10; 둘)은 가장 가까운 위치 있는 조상(문단)의 끝 줄 · 끝 열에서 자른다(D6 · §5-1 24 — 리뷰 C RC-2 · 확장)', () => {
    expect(bodyColsOf(probe('a [b&#10;&#10;xmpp:c@d.e')), 'mx-8 조상 끝 줄 · 끝 열 자르기').toEqual(['unsafe-url 5:25']);
  });

  it('mx-8 같은 줄 두 html → 열 순 · 확장: 위치 없는 노드의 열(order-A · order-B — §6-9) · 같은 줄 같은 열 = 규칙 순 · 열 순 ≠ 규칙 순', () => {
    expect(bodyColsOf('<b>x</b>'), 'mx-8 같은 줄 두 html').toEqual(['raw-html 1:1', 'raw-html 1:5']);
    expect(bodyColsOf(probe('{x} see "www.example.com" <b>')), 'mx-8 order-A').toEqual(['expression 5:1', 'raw-html 5:27']);
    expect(bodyColsOf(probe('[x](javascript:a) {y} "www.example.com"')), 'mx-8 order-B').toEqual(['unsafe-url 5:1', 'expression 5:18']);
    expect(bodyColsOf("import {a} from 'b'"), 'mx-8 같은 줄 같은 열').toEqual(['esm 1:1', 'expression 1:1']);
    expect(bodyColsOf('{x} <b>'), 'mx-8 열 순 ≠ 규칙 순').toEqual(['expression 1:1', 'raw-html 1:5']);
  });

  it.each([
    ['html 흐름 블록 → raw-html 하나', '<div>\nx\n</div>', ['raw-html 1']],
    ['html 주석', '<!-- c -->', ['raw-html 1']],
    ['export 줄', 'export const a = 1', ['esm 1']],
    ['link title 중괄호', '[a](./x "{t}")', ['expression 1']],
    ['image alt 중괄호', '![{x}](./a.png)', ['expression 1']],
    ['image url data:', '![a](data:text/html,x)', ['unsafe-url 1']],
    ['definition title 중괄호 · url은 정의 줄', '[a][r]\n\n[r]: ./x "{t}"', ['expression 3']],
    ['definition url', '[a][r]\n\n[r]: vbscript:x', ['unsafe-url 3']],
    ['자동 링크 <javascript:…>', '<javascript:alert(1)>', ['unsafe-url 1']],
    ['문자 참조로 만든 스킴', link('&#106;avascript:a'), ['unsafe-url 1']],
    ['//로 시작', link('//evil.invalid/x'), ['unsafe-url 1']],
    ['역슬래시', link(`/${BS}evil.invalid`), ['unsafe-url 1']],
    ['ftp', link('ftp://example.com/x'), ['unsafe-url 1']],
    ['허용 — 대문자 HTTPS · MAILTO · # · 상대 · /ko · 산문 자동 링크', `${link('HTTPS://example.com')} ${link('MAILTO:a@example.com')} ${link('#top')} ${link('./rel')} ${link('/ko')} https://example.com`, []],
    ['허용 — 코드 스팬 · 펜스 · 문자 참조 &lt;b&gt;(과잉 가드 0)', '`<b>` `{a}` `import x`\n\n```js\nimport x from \'y\'\nconst z = {}\n```\n\n&lt;b&gt;', []],
    ['중첩 — 목록 · 인용 · 표 칸 · 헤딩 · 링크 글자 · 각주 정의', '- [x](javascript:a)\n\n> <b>x</b>\n\n| a |\n|---|\n| {x} |\n\n## {y}\n\n[{z}](./a)\n\n[^1]: <i>x</i>', ['unsafe-url 1', 'raw-html 3', 'raw-html 3', 'expression 7', 'expression 9', 'expression 11', 'raw-html 13', 'raw-html 13']],
  ] as Array<[string, string, string[]]>)('mx-8 확장: D6 표 기본(단위) — %s', (label, text, want) => {
    expect(bodyOf(text), `mx-8 확장 ${label}`).toEqual(want);
  });
});

describe('mx 확장 — 프로그래머 오류(값 없는 상수 메시지)', () => {
  it('compile · readingTime 모르는 lang → TypeError · 메시지에 바늘 0(아는 lang은 정상 — 양성 짝)', async () => {
    const tree = parseMarkdown('본문.');
    const known = await compile(tree, 'ko');
    check(known.html === '<p>본문.</p>' && known.readingTime === 1, 'compile 아는 lang 정상');
    check(readingTime(tree, 'ja') === 1, 'readingTime 아는 lang 정상');
    const needle = 'zz-needle-lang';
    const compiled = await failure(() => compile(tree, needle as Lang));
    check(compiled instanceof TypeError && !String((compiled as Error).message).includes(needle), 'compile 모르는 lang → TypeError(바늘 0)');
    const reading = await failure(() => readingTime(tree, needle as Lang));
    check(reading instanceof TypeError && !String((reading as Error).message).includes(needle), 'readingTime 모르는 lang → TypeError(바늘 0)');
  });
});
