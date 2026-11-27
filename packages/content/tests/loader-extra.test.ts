// packages/content/tests/loader-extra.test.ts — T090 조각 ④(시험 먼저 · vitest). 짝 구현 = packages/content/src/{loader,index}.ts.
//
// 정본: specs/003-platform-foundation/design/t090-design.md — D2(공개 표면) · D3(파이프라인) · D4(오류 · 순서 · code · 입력 값 0 · 얼림)
//   · D8(인자 · root · 스캔 · not-regular · 1회 스캔 메모) · D9(다국어 · draft · 정렬 · blog · projects) · D12 ④ lx-1–lx-18
//   · §6(§6-5 lx-18 · §6-7 블록 안 --- !!map · §6-8 lx-7 하위 사례마다 mkdtemp root · §6-9 위치 없는 노드의 열)
//   · D13 mu-7 · mu-9–mu-13 · mu-23 · mu-34 · mu-36–mu-45 · mu-48 · mu-52 · mu-59–mu-67 · mu-75 · mu-77 · mu-78.
//   API 정본 = tests/loader.test.ts 머리 주석 :11–:49(T086 — 고치지 않는다).
//   「확장」 표시 = 설계 표 밖에 더한 사례: 공개 표면 정확 집합(lx-0) · 상대 opts.root(호출 시점 cwd) · 호출마다 다시 읽는 env
//   · 배열 opts → TypeError · root 부재도 보관하지 않음 · 변형 어긋남의 문서 키 순 · 이름 규칙 대소문자 · 이름 위반 파일은 ko 아님
//   · root · 컬렉션 경로가 파일(lx-x1) · 항목 키 여덟 정확 · html의 헤딩 id · 메모 주석 정적 확인 · 금지 토큰 패턴 자가 시험.
//   리뷰 고침(2026-11-27) — 확장: lx-x2 YAML 1.1 태그 = 모르는 태그(설계 정정 노트 1 파일 단위 · mu-79) · lx-13 blog · projects도 필드
//   검증 · 본문 거부 규칙(리뷰 C RC-1 · 변이 g1 · g1b) · lx-18 네트워크 · 프로세스 내장 가져오기(node: 접두 무관 · http2 · tls · dgram
//   · dns · worker_threads) · undici · WebSocket(리뷰 B RB-2). lx-15에 픽스처 root 기본 호출(리뷰 C RC-5 — 실제 노트 draft 값과 무관한 N-1 · mu-01).
//   재확인 고침(2026-11-27) — 확장: RR-1 사례(lx-13 변형 change · sources 동시 누락 — 계약 키 순 · 변이 k3-loader-rank · 결정 K-7).
//   자식 env 고침(2026-11-27): childEnv가 FORCE_COLOR도 늘 지운다(결정 K-11 — 색 env 충돌 경고가 자식 stderr 0 단언을 깨지 않게).
// 빨강(구현 전): 이 파일을 수집할 때 ../src/index.ts(그리고 ../src/loader.ts) 로드가 실패한다(구현 없음).
//
// 이 시험이 쓰는 표면:
//   index.ts  getCollection · ContentValidationError · COLLECTIONS · LANGS(+ 형 ContentItem · ContentIssue · Collection · Lang · Frontmatter · Heading)
//   loader.ts classifyEntry(collection, { name, isFile() }) => { kind: 'ignored' } | { kind: 'rejected', issue }
//             | { kind: 'file', file, name, member: { slug, lang } | null }   — D8 스캔 2–5(순수 함수 · lx-12 보조)
// 시험 단언은 값을 출력하지 않는다 — 실패 메시지는 사례 id · 파일 · 필드 · 규칙 이름 · 줄만(issue 비교는 quad — body가 아니면 line '-').
// 픽스처: T086 tests/fixtures/<case>/는 읽기만 한다. 나머지는 실행 중 mkdtemp에 만든다(하위 사례마다 새 root).

import { Buffer } from 'node:buffer';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { isDeepStrictEqual } from 'node:util';

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { COLLECTIONS, ContentValidationError, LANGS, getCollection } from '../src/index.ts';
import type { ContentIssue, ContentItem } from '../src/index.ts';
import { classifyEntry } from '../src/loader.ts';

const FIXTURES = fileURLToPath(new URL('./fixtures', import.meta.url));
const fixture = (name: string): string => join(FIXTURES, name);
const SRC = fileURLToPath(new URL('../src/', import.meta.url));

/** 자식이 import할 index.ts URL(JS 문자열 리터럴) */
const INDEX_URL = JSON.stringify(pathToFileURL(join(SRC, 'index.ts')).href);

// content.md 본문 절 — 순서 그대로(ld-1과 같은 값)
const SECTION_TEXTS = ['문제', '배운 개념', '선택과 대안', '결과와 검증', '다음 학습'];
const SECTION_IDS = ['문제', '배운-개념', '선택과-대안', '결과와-검증', '다음-학습'];
const REAL = ['001-claude-setup', '002-smoke'];

const temps: string[] = [];

beforeEach(() => {
  // 개발자 env의 JT_CONTENT_ROOT가 기본 root · 픽스처 root를 가리지 않게 지운다(afterEach가 되돌린다 — loader.test.ts:86–:89 꼴)
  vi.stubEnv('JT_CONTENT_ROOT', undefined);
});

afterEach(() => {
  vi.unstubAllEnvs();
  for (const dir of temps.splice(0)) rmSync(dir, { recursive: true, force: true });
});

/** afterEach가 지우는 빈 임시 디렉터리 */
function tempRoot(): string {
  const dir = mkdtempSync(join(tmpdir(), 'jt-loader-'));
  temps.push(dir);
  return dir;
}

/** root 아래 rel('/' 경로)에 쓴다 — 상위 디렉터리를 만든다 */
function put(root: string, rel: string, content: string | Uint8Array): void {
  const full = join(root, ...rel.split('/'));
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, content);
}

// ---------- 노트 원문 ----------

/** 유효한 study 프런트매터 키 일곱(content.md 계약 순 — 2–8행) */
const BASE_KEYS: ReadonlyArray<readonly [string, string]> = [
  ['title', '"제목"'],
  ['description', '"한 문장."'],
  ['pubDate', '2026-05-01'],
  ['tags', '[]'],
  ['draft', 'false'],
  ['change', '"001-a"'],
  ['sources', '[]'],
];

type Over = Readonly<Record<string, string | null>>;

/** BASE_KEYS 줄 — over의 키는 값을 바꾸고(null이면 그 키를 뺀다) · BASE_KEYS에 없는 키는 끝에 붙인다 */
function keyLines(over: Over = {}): string[] {
  const lines: string[] = [];
  for (const [key, value] of BASE_KEYS) {
    const next = Object.hasOwn(over, key) ? over[key] : value;
    if (next !== null && next !== undefined) lines.push(`${key}: ${next}`);
  }
  for (const [key, value] of Object.entries(over)) {
    if (!BASE_KEYS.some(([base]) => base === key) && value !== null) lines.push(`${key}: ${value}`);
  }
  return lines;
}

/** 노트 원문 — 1행 '---' · 프런트매터 줄 · 닫는 '---' · 빈 줄 · 본문(키 일곱이면 1–9행 프런트매터 · 10행 빈 줄 · 본문은 11행부터) */
const doc = (front: readonly string[], body: readonly string[] = ['본문.']): string =>
  ['---', ...front, '---', '', ...body, ''].join('\n');

/** 유효한 노트(change와 over만 바꾼다) */
const valid = (change: string, body?: readonly string[], over: Over = {}): string => doc(keyLines({ change: `"${change}"`, ...over }), body);

/** 넷째 바이트 뒤에 0xFF를 끼운 깨진 UTF-8 */
function broken(text: string): Buffer {
  const good = Buffer.from(text, 'utf8');
  return Buffer.concat([good.subarray(0, 4), Buffer.from([0xff]), good.subarray(4)]);
}

// ---------- 단언 도우미(값 없는 실패 메시지) ----------

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

// issue 필드 꼴(loader.test.ts:156–:158) — 값이 섞이면 diff 출력 전에 값 없는 실패로 멈춘다
const FILE_RE = /^(?:\.|[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._-]+)*\/?)$/;
const FIELD_RE = /^[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*$/;
const CODE_RE = /^[A-Za-z0-9_:-]+$/;
const ERROR_OWN_KEYS: ReadonlySet<PropertyKey> = new Set<PropertyKey>(['issues', 'name', 'message', 'stack']);

const formatIssue = (i: ContentIssue): string => `${i.file}${i.line === undefined ? '' : `:${i.line}`}: ${i.field} (${i.code})`;
const quad = (i: ContentIssue): string => `${i.file} ${i.field} ${i.code} ${i.line ?? '-'}`;
const triple = (i: ContentIssue): string => `${i.file} ${i.field} ${i.code}`;

/**
 * thrown이 계약 꼴의 ContentValidationError인지 본다 — 클래스 · 이름 · cause 0 · 자기 속성 키 · issues ≥ 1 · 필드 꼴 · 키 집합(body = file
 * · field · code · line / 그 밖 = file · field · code — D4 「line은 body issue에만」) · message = issue 줄들. 통과하면 issues를 돌려준다.
 */
function expectIssues(thrown: unknown, label: string): ContentIssue[] {
  check(thrown !== NOT_THROWN, `${label}: 오류가 나야 한다`);
  check(thrown instanceof ContentValidationError, `${label}: ContentValidationError 인스턴스`);
  const error = thrown as Error & { issues?: unknown };
  check(error instanceof Error && error.name === 'ContentValidationError', `${label}: Error · name`);
  check(error.cause === undefined, `${label}: cause 0`);
  check(Reflect.ownKeys(error).every((key) => ERROR_OWN_KEYS.has(key)), `${label}: 자기 속성 키 ⊆ {issues, name, message, stack}`);
  check(Array.isArray(error.issues) && error.issues.length >= 1, `${label}: issues ≥ 1`);
  const raw = error.issues as unknown[];
  raw.forEach((entry, index) => {
    const at = `${label}: issues[${index}]`;
    check(entry !== null && typeof entry === 'object', `${at} 객체`);
    const i = entry as Partial<ContentIssue>;
    check(typeof i.file === 'string' && FILE_RE.test(i.file), `${at}.file 꼴`);
    check(typeof i.field === 'string' && FIELD_RE.test(i.field), `${at}.field 꼴`);
    check(typeof i.code === 'string' && CODE_RE.test(i.code), `${at}.code 꼴`);
    const keys = Object.keys(entry as object).join(',');
    if (i.field === 'body') {
      check(keys === 'file,field,code,line' && Number.isInteger(i.line) && (i.line as number) >= 1, `${at} body = 키 넷 · line 정수 ≥ 1`);
    } else {
      check(keys === 'file,field,code', `${at} body 밖 = 키 셋(line 없음)`);
    }
  });
  const issues = raw as ContentIssue[];
  check(error.message === issues.map(formatIssue).join('\n'), `${label}: message = issue 줄들('<file>[:<line>]: <field> (<code>)')`);
  return issues;
}

/** root의 study 컬렉션을 불러 오류의 quad 목록을 돌려준다(오류가 아니면 값 없는 실패) */
async function quadsOf(root: string, label: string, collection: 'study' | 'blog' | 'projects' = 'study'): Promise<string[]> {
  return expectIssues(await failure(() => getCollection(collection, { root })), label).map(quad);
}

function slugsOf(items: unknown, label: string): string[] {
  check(Array.isArray(items), `${label}: 배열`);
  return (items as ContentItem[]).map((item) => item.slug);
}

/** items에서 slug 항목 하나를 찾는다(없거나 둘 이상이면 값 없는 실패) */
function bySlug(items: unknown, slug: string, label: string): ContentItem {
  check(Array.isArray(items), `${label}: 배열`);
  const found = (items as ContentItem[]).filter((item) => item !== null && typeof item === 'object' && item.slug === slug);
  check(found.length === 1, `${label}: ${slug} 항목 정확히 하나`);
  return found[0] as ContentItem;
}

// ---------- 자식 프로세스(process.execPath · env에서 JT_CONTENT_ROOT · NODE_OPTIONS · FORCE_COLOR(+ drop) 삭제) ----------

function childEnv(extra: Readonly<Record<string, string>> = {}, drop: readonly string[] = []): NodeJS.ProcessEnv {
  // FORCE_COLOR도 늘 지운다(extra로 일부러 넣으면 그대로 둔다) — NO_COLOR · NODE_DISABLE_COLORS와 함께 있으면 Node가 자식 stderr에
  // env 충돌 경고를 찍어 stderr 0 단언이 환경 탓으로 깨진다(컨트롤러 관찰 2026-11-27 · 결정 K-11). 색 env는 시험 대상 계약이 아니다.
  const removed = new Set(['JT_CONTENT_ROOT', 'NODE_OPTIONS', 'FORCE_COLOR', ...drop]);
  const env: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) if (!removed.has(key.toUpperCase())) env[key] = value;
  return { ...env, ...extra };
}

type Run = { status: number | null; stdout: string; stderr: string };

function runNode(code: string, cwd: string, env: NodeJS.ProcessEnv): Run {
  const result = spawnSync(process.execPath, ['--input-type=module', '-e', code], { cwd, env, encoding: 'utf8', timeout: 60_000 });
  return { status: result.status, stdout: result.stdout ?? '', stderr: result.stderr ?? '' };
}

// =====================================================================================================

describe('lx-0 공개 표면(D2 — 확장)', () => {
  it('lx-0 index.ts 값 내보내기 = getCollection · ContentValidationError · COLLECTIONS · LANGS 정확 · 상수 값', async () => {
    const mod = (await import('../src/index.ts')) as Record<string, unknown>;
    expect(Object.keys(mod).sort(), 'lx-0 값 내보내기 집합').toEqual(['COLLECTIONS', 'ContentValidationError', 'LANGS', 'getCollection']);
    expect([...COLLECTIONS], 'lx-0 COLLECTIONS').toEqual(['study', 'blog', 'projects']);
    expect([...LANGS], 'lx-0 LANGS').toEqual(['ko', 'en', 'ja']);
    check(typeof getCollection === 'function' && typeof ContentValidationError === 'function', 'lx-0 값의 형');
  });
});

describe('lx-1 root 우선순위(정정 노트 35 — opts.root > env > 기본)', () => {
  it('lx-1 env = i18n · opts.root = drafts → drafts의 slug', async () => {
    vi.stubEnv('JT_CONTENT_ROOT', fixture('i18n'));
    const slugs = slugsOf(await getCollection('study', { root: fixture('drafts'), includeDrafts: true }), 'lx-1');
    expect(slugs, 'lx-1 slug(pubDate 내림차순)').toEqual(['002-draft', '001-public']);
  });

  it('lx-1 상대 opts.root = 호출 시점 cwd 기준(path.resolve — 확장)', async () => {
    const rel = relative(process.cwd(), fixture('drafts'));
    const slugs = slugsOf(await getCollection('study', { root: rel, includeDrafts: true }), 'lx-1 상대');
    expect(slugs, 'lx-1 상대 root slug').toEqual(['002-draft', '001-public']);
  });
});

describe('lx-2 env는 호출 시점에 읽는다', () => {
  it('lx-2 import 뒤 env = i18n · root 없음 → i18n slug(기본 root보다 앞) · 호출마다 다시 읽는다(확장)', async () => {
    vi.stubEnv('JT_CONTENT_ROOT', fixture('i18n'));
    expect(slugsOf(await getCollection('study'), 'lx-2'), 'lx-2 env root slug').toEqual(['001-hello', '002-ko-only']);
    vi.stubEnv('JT_CONTENT_ROOT', fixture('drafts'));
    expect(slugsOf(await getCollection('study', { includeDrafts: true }), 'lx-2 바뀐 env'), 'lx-2 바뀐 env slug').toEqual([
      '002-draft',
      '001-public',
    ]);
  });
});

describe('lx-3 인자(〔90-5〕 · 〔A-16〕 · 〔V-B-13〕 — TypeError · 값 없는 상수 메시지 · 명시 undefined = 미지정)', () => {
  const root = fixture('i18n');
  const NEEDLE = 'zz-needle-lang';
  const CASES: Array<[string, () => Promise<unknown>, readonly string[]]> = [
    ["opts.root ''", () => getCollection('study', { root: '' }), []],
    ['opts.root 42(문자열 아님)', () => getCollection('study', { root: 42 as never }), ['42']],
    ["env ''", () => {
      vi.stubEnv('JT_CONTENT_ROOT', '');
      return getCollection('study');
    }, []],
    ['lang zz-needle-lang', () => getCollection('study', { root, lang: NEEDLE as never }), [NEEDLE]],
    ["includeDrafts 'yes'", () => getCollection('study', { root, includeDrafts: 'yes' as never }), ['yes']],
    ['opts = null', () => getCollection('study', null as never), []],
    ["opts = 'x'(객체 아님)", () => getCollection('study', 'x' as never), []],
    ['opts = [](배열 — 확장)', () => getCollection('study', [] as never), []],
  ];

  it.each(CASES)('lx-3 %s → TypeError(값 없는 상수 메시지 · 있는 root는 정상)', async (label, run, needles) => {
    check(slugsOf(await getCollection('study', { root }), `lx-3 ${label} 양성 짝`).length >= 1, `lx-3 ${label}: 있는 root는 항목`);
    const thrown = await failure(run);
    check(thrown instanceof TypeError, `lx-3 ${label}: TypeError`);
    check(!(thrown instanceof ContentValidationError), `lx-3 ${label}: ContentValidationError 아님`);
    const message = String((thrown as Error).message).toLowerCase();
    needles.forEach((needle, index) => {
      check(!message.includes(needle.toLowerCase()), `lx-3 ${label}: 메시지에 입력 값 0(needle #${index})`);
    });
  });

  it('lx-3 명시 undefined(lang · includeDrafts · root) = 그 키를 뺀 호출 · opts undefined · {} = 기본', async () => {
    vi.stubEnv('NODE_ENV', 'production');
    const drafts = fixture('drafts');
    const base = await getCollection('study', { root: drafts });
    expect(slugsOf(base, 'lx-3 기준'), 'lx-3 기준 slug(NODE_ENV production → draft 제외)').toEqual(['001-public']);
    const explicit = await getCollection('study', { root: drafts, lang: undefined, includeDrafts: undefined });
    check(isDeepStrictEqual(explicit, base), 'lx-3 lang · includeDrafts undefined = 미지정');
    vi.stubEnv('JT_CONTENT_ROOT', drafts);
    check(isDeepStrictEqual(await getCollection('study', { root: undefined }), base), 'lx-3 root undefined = 미지정(env 단계)');
    check(isDeepStrictEqual(await getCollection('study', undefined), base), 'lx-3 opts undefined = 기본');
    check(isDeepStrictEqual(await getCollection('study', {}), base), 'lx-3 빈 opts = 기본');
  });
});

describe('lx-4 1회 스캔(〔90-1〕 모듈 메모 — 키 = 해석된 root · 컬렉션)', () => {
  it('lx-4 첫 호출 → 파일 하나 삭제 → 다른 lang · includeDrafts로 다시 → 같은 slug 집합 · 같은 내용의 새 root는 삭제를 본다', async () => {
    const build = (root: string): void => {
      put(root, 'study/001-a.mdx', valid('001-a'));
      put(root, 'study/002-b.mdx', valid('002-b'));
    };
    const root = tempRoot();
    build(root);
    expect(slugsOf(await getCollection('study', { root, lang: 'ko', includeDrafts: false }), 'lx-4 첫'), 'lx-4 첫 slug').toEqual([
      '001-a',
      '002-b',
    ]);
    rmSync(join(root, 'study', '002-b.mdx'));
    expect(slugsOf(await getCollection('study', { root, lang: 'en', includeDrafts: true }), 'lx-4 다시'), 'lx-4 다시 slug(메모)').toEqual([
      '001-a',
      '002-b',
    ]);
    const fresh = tempRoot();
    build(fresh);
    rmSync(join(fresh, 'study', '002-b.mdx'));
    expect(slugsOf(await getCollection('study', { root: fresh }), 'lx-4 새 root'), 'lx-4 새 root slug(삭제를 본다)').toEqual(['001-a']);
  });
});

describe('lx-5 거부 보관 0', () => {
  it('lx-5 위반 root → 오류 → 고친 뒤 → 항목', async () => {
    const root = tempRoot();
    put(root, 'study/001-a.mdx', doc(keyLines({ title: '""' })));
    expect(await quadsOf(root, 'lx-5'), 'lx-5 issues').toEqual(['study/001-a.mdx title empty -']);
    put(root, 'study/001-a.mdx', valid('001-a'));
    expect(slugsOf(await getCollection('study', { root }), 'lx-5 고친 뒤'), 'lx-5 고친 뒤 slug').toEqual(['001-a']);
  });

  it('lx-5 root 부재도 보관하지 않는다 — 없음 → (., root, missing) → 만든 뒤 → 항목(확장)', async () => {
    const root = join(tempRoot(), 'later');
    expect(await quadsOf(root, 'lx-5 부재'), 'lx-5 부재 issues').toEqual(['. root missing -']);
    put(root, 'study/001-a.mdx', valid('001-a'));
    expect(slugsOf(await getCollection('study', { root }), 'lx-5 만든 뒤'), 'lx-5 만든 뒤 slug').toEqual(['001-a']);
  });
});

describe('lx-6 호출 간 독립(structuredClone)', () => {
  it('lx-6 돌려받은 배열 · data · headings · translations 변경이 다음 호출 결과에 0', async () => {
    const root = fixture('i18n');
    const first = await getCollection('study', { root });
    check(first.length === 2, 'lx-6 첫 결과 두 항목');
    const snapshot = structuredClone(first);
    const item = first[0] as ContentItem;
    (item.data as Record<string, unknown>).title = 'changed';
    (item.data.tags as string[]).push('changed');
    item.headings.splice(0);
    item.translations.push('ja');
    first.pop();
    const second = await getCollection('study', { root });
    check(isDeepStrictEqual(second, snapshot), 'lx-6 다음 호출 = 변경 전 결과');
    check(second !== first && second[0] !== first[0], 'lx-6 새 배열 · 새 항목');
  });
});

describe('lx-7 순서(〔A-8〕 · 〔A-10〕 · 〔V-B-4〕 · 〔V-B-15〕 · §6-7 · §6-9 — 하위 사례마다 mkdtemp root · quad)', () => {
  const F = 'study/001-a.mdx';

  it('lx-7 B.mdx · a.mdx(둘 다 name) → study/B.mdx 먼저(Ordinal — localeCompare 0)', async () => {
    const root = tempRoot();
    put(root, 'study/B.mdx', valid('001-b'));
    put(root, 'study/a.mdx', valid('001-a'));
    expect(await quadsOf(root, 'lx-7 Ordinal'), 'lx-7 Ordinal').toEqual(['study/B.mdx file name -', 'study/a.mdx file name -']);
  });

  it('lx-7 한 파일 — 프런트매터 issue(문서 키 순 · 없는 키는 뒤) → 본문(줄 순)', async () => {
    const root = tempRoot();
    // 1 --- · 2 draft · 3 title · 4 pubDate · 5 tags · 6 change · 7 sources · 8 --- · 9 빈 줄 · 10 {y} · 11 빈 줄 · 12 a <b>x</b>
    put(root, F, doc(['draft: "no"', 'title: ""', 'pubDate: 2026-05-01', 'tags: []', 'change: "001-a"', 'sources: []'], ['{y}', '', 'a <b>x</b>']));
    expect(await quadsOf(root, 'lx-7 한 파일'), 'lx-7 한 파일').toEqual([
      `${F} draft type -`,
      `${F} title empty -`,
      `${F} description missing -`,
      `${F} body expression 10`,
      `${F} body raw-html 12`,
      `${F} body raw-html 12`,
    ]);
  });

  it('lx-7 no-number 꼴 이름 + ---js → [name, fence] 정확', async () => {
    const root = tempRoot();
    put(root, 'study/no-number.mdx', ['---js', ...keyLines({ change: '"017-no-number"' }), '---', '', '본문.', ''].join('\n'));
    expect(await quadsOf(root, 'lx-7 name+fence'), 'lx-7 name+fence').toEqual([
      'study/no-number.mdx file name -',
      'study/no-number.mdx frontmatter fence -',
    ]);
  });

  it('lx-7 sources 11개(2번 · 10번 url 위반) → sources.2.url → sources.10.url(첨자 수 비교)', async () => {
    const root = tempRoot();
    const sources = Array.from({ length: 11 }, (_, index) => {
      const url = index === 2 || index === 10 ? 'ftp://example.com/x' : `https://example.com/${index}`;
      return `  - { title: "s${index}", url: "${url}" }`;
    });
    put(root, F, doc([...keyLines({ sources: null }), 'sources:', ...sources]));
    expect(await quadsOf(root, 'lx-7 첨자'), 'lx-7 첨자').toEqual([`${F} sources.2.url format -`, `${F} sources.10.url format -`]);
  });

  it('lx-7 이름 위반 + 깨진 UTF-8 → [name, encoding] · ko 없는 변형 + 깨진 UTF-8 → [encoding, ko-missing]', async () => {
    const named = tempRoot();
    put(named, 'study/no-number.mdx', broken(valid('017-no-number')));
    expect(await quadsOf(named, 'lx-7 name+encoding'), 'lx-7 name+encoding').toEqual([
      'study/no-number.mdx file name -',
      'study/no-number.mdx file encoding -',
    ]);
    const orphan = tempRoot();
    put(orphan, 'study/001-x.en.mdx', broken(valid('001-x')));
    expect(await quadsOf(orphan, 'lx-7 encoding+ko-missing'), 'lx-7 encoding+ko-missing').toEqual([
      'study/001-x.en.mdx file encoding -',
      'study/001-x.en.mdx file ko-missing -',
    ]);
  });

  it("lx-7 한 줄 import {a} from 'b' → esm → expression(같은 줄 · 같은 열 = 규칙 순)", async () => {
    const root = tempRoot();
    put(root, F, valid('001-a', ["import {a} from 'b'"]));
    expect(await quadsOf(root, 'lx-7 규칙 순'), 'lx-7 규칙 순').toEqual([`${F} body esm 11`, `${F} body expression 11`]);
  });

  it('lx-7 한 줄 {x} <b> → expression → raw-html(같은 줄 · 열 1 < 열 5 — 규칙 순이면 반대)', async () => {
    const root = tempRoot();
    put(root, F, valid('001-a', ['{x} <b>']));
    expect(await quadsOf(root, 'lx-7 열 순'), 'lx-7 열 순').toEqual([`${F} body expression 11`, `${F} body raw-html 11`]);
  });

  it('lx-7 블록 안 「--- 」(뒤 공백) → [fence] 하나(스키마 issue 0 — micromark가 그 줄에서 닫는다)', async () => {
    const root = tempRoot();
    put(root, F, ['---', 'title: ""', '--- ', 'description: x', '---', '', '본문.', ''].join('\n'));
    expect(await quadsOf(root, 'lx-7 블록 안 닫힘'), 'lx-7 블록 안 닫힘').toEqual([`${F} frontmatter fence -`]);
  });

  it('lx-7 블록 안 「--- !!map」 + 유효 키 일곱 → [yaml] 하나(판독 1만 잡는 꼴 — §6-7)', async () => {
    const root = tempRoot();
    put(root, F, ['---', '--- !!map', ...keyLines(), '---', '', '본문.', ''].join('\n'));
    expect(await quadsOf(root, 'lx-7 문서 표식'), 'lx-7 문서 표식').toEqual([`${F} frontmatter yaml -`]);
  });

  it('lx-7 위치 없는 노드의 열(§6-9) — {x} see "www.example.com" <b> → [expression, raw-html] · [x](javascript:a) {y} "www.example.com" → [unsafe-url, expression]', async () => {
    const a = tempRoot();
    put(a, F, valid('001-a', ['{x} see "www.example.com" <b>']));
    expect(await quadsOf(a, 'lx-7 order-A'), 'lx-7 order-A').toEqual([`${F} body expression 11`, `${F} body raw-html 11`]);
    const b = tempRoot();
    put(b, F, valid('001-a', ['[x](javascript:a) {y} "www.example.com"']));
    expect(await quadsOf(b, 'lx-7 order-B'), 'lx-7 order-B').toEqual([`${F} body unsafe-url 11`, `${F} body expression 11`]);
  });

  it('lx-7 변형 어긋남도 문서 키 순 — (pubDate, variant-mismatch)(있는 키) → (change, missing)(없는 키 · 뒤)(확장)', async () => {
    const root = tempRoot();
    put(root, F, valid('001-a'));
    put(root, 'study/001-a.en.mdx', doc(keyLines({ pubDate: '2026-05-02', change: null })));
    expect(await quadsOf(root, 'lx-7 변형 순서'), 'lx-7 변형 순서').toEqual([
      'study/001-a.en.mdx pubDate variant-mismatch -',
      'study/001-a.en.mdx change missing -',
    ]);
  });

  it('lx-7 issues 배열 · 각 issue는 얼어 있다(Object.isFrozen — D4)', async () => {
    const root = tempRoot();
    put(root, F, valid('001-a', ['{x} <b>']));
    const thrown = await failure(() => getCollection('study', { root }));
    const issues = expectIssues(thrown, 'lx-7 얼림');
    check(Object.isFrozen((thrown as ContentValidationError).issues), 'lx-7 issues 배열 얼림');
    check(issues.length === 2 && issues.every((issue) => Object.isFrozen(issue)), 'lx-7 각 issue 얼림');
  });
});

describe('lx-8 code 어휘(T086 픽스처 — 읽기만 · triple 정확)', () => {
  const triples = async (name: string): Promise<string[]> =>
    expectIssues(await failure(() => getCollection('study', { root: fixture(name) })), `lx-8 ${name}`).map(triple);

  it('lx-8 missing — ld-2 · collect · draft-invalid', async () => {
    expect(await triples('missing-pubdate'), 'lx-8 missing-pubdate').toEqual(['study/001-missing-pubdate.mdx pubDate missing']);
    expect(await triples('collect'), 'lx-8 collect').toEqual(['study/001-first-bad.mdx title missing', 'study/002-second-bad.mdx tags missing']);
    expect(await triples('draft-invalid'), 'lx-8 draft-invalid').toEqual(['study/001-draft-broken.mdx description missing']);
  });

  it('lx-8 date-order — updated-before', async () => {
    expect(await triples('updated-before'), 'lx-8 updated-before').toEqual(['study/001-updated-before.mdx updatedDate date-order']);
  });

  it('lx-8 series-pair · format · source-kind · variant-mismatch · unknown-key · name — schema-violations', async () => {
    expect(await triples('schema-violations'), 'lx-8 schema-violations').toEqual([
      'study/001-series-only.mdx seriesOrder series-pair',
      'study/002-series-order-only.mdx series series-pair',
      'study/003-bad-change.mdx change format',
      'study/004-source-both.mdx sources.0 source-kind',
      'study/005-source-none.mdx sources.0 source-kind',
      'study/006-variant-pubdate.en.mdx pubDate variant-mismatch',
      'study/007-variant-change.en.mdx change variant-mismatch',
      'study/008-unknown-key.mdx pubdate unknown-key',
      'study/009-url-js.mdx sources.0.url format',
      'study/010-url-data.mdx sources.0.url format',
      'study/011-url-scheme-relative.mdx sources.0.url format',
      'study/012-path-absolute.mdx sources.0.path format',
      'study/013-path-backslash.mdx sources.0.path format',
      'study/014-path-dotdot.mdx sources.0.path format',
      'study/015-path-js.mdx sources.0.path format',
      'study/016-path-url.mdx sources.0.path format',
      'study/no-number.mdx file name',
    ]);
  });
});

describe('lx-8b code 어휘 행마다(〔A-3〕 · mkdtemp · quad)', () => {
  const F = 'study/001-a.mdx';
  const V = 'study/001-a.en.mdx';
  const CASES: Array<[string, Readonly<Record<string, string>>, readonly string[]]> = [
    ['title "" → (title, empty) 하나(길이 · 패턴 issue 둘 → 한 경로 하나)', { [F]: doc(keyLines({ title: '""' })) }, [`${F} title empty -`]],
    ['title "  " → (title, empty)', { [F]: doc(keyLines({ title: '"  "' })) }, [`${F} title empty -`]],
    ['title:(null) → (title, type)', { [F]: doc(['title:', ...keyLines({ title: null })]) }, [`${F} title type -`]],
    ['title 키 없음 → (title, missing)', { [F]: doc(keyLines({ title: null })) }, [`${F} title missing -`]],
    ['tags "x" → (tags, type)', { [F]: doc(keyLines({ tags: '"x"' })) }, [`${F} tags type -`]],
    ['tags ["a", ""] → (tags.1, empty)', { [F]: doc(keyLines({ tags: '["a", ""]' })) }, [`${F} tags.1 empty -`]],
    ['seriesOrder 0(series와 함께) → range', { [F]: doc(keyLines({ series: '"s"', seriesOrder: '0' })) }, [`${F} seriesOrder range -`]],
    ['seriesOrder 1.5(series와 함께) → type', { [F]: doc(keyLines({ series: '"s"', seriesOrder: '1.5' })) }, [`${F} seriesOrder type -`]],
    ['pubDate 2026-02-30 → format', { [F]: doc(keyLines({ pubDate: '2026-02-30' })) }, [`${F} pubDate format -`]],
    ['draft "false" → type', { [F]: doc(keyLines({ draft: '"false"' })) }, [`${F} draft type -`]],
    [
      'sources [{title, path, foo}] → (sources.0.foo, unknown-key)',
      { [F]: doc(keyLines({ sources: '[{title: x, path: a, foo: 1}]' })) },
      [`${F} sources.0.foo unknown-key -`],
    ],
    [
      '변형 pubDate 꼴 오류 → (변형, pubDate, format) 하나(variant-mismatch 0)',
      { [F]: valid('001-a'), [V]: doc(keyLines({ pubDate: '2026-02-30' })) },
      [`${V} pubDate format -`],
    ],
    [
      'ko pubDate 2026-02-30 + en 유효 다른 날짜 → ko format만 · en issue 0(두 값이 유효할 때만 비교)',
      { [F]: doc(keyLines({ pubDate: '2026-02-30' })), [V]: doc(keyLines({ pubDate: '2026-03-01' })) },
      [`${F} pubDate format -`],
    ],
    [
      'ko ---js + en → ko fence 하나 · en issue 0',
      { [F]: ['---js', ...keyLines(), '---', '', '본문.', ''].join('\n'), [V]: valid('001-a') },
      [`${F} frontmatter fence -`],
    ],
  ];

  it.each(CASES)('lx-8b %s', async (label, files, expected) => {
    const root = tempRoot();
    for (const [rel, content] of Object.entries(files)) put(root, rel, content);
    expect(await quadsOf(root, `lx-8b ${label}`), `lx-8b ${label}`).toEqual(expected);
  });
});

describe('lx-9 translations', () => {
  it('lx-9 ko · en · ja 셋 → 각 항목 = 요청 lang · translations = 남은 다른 lang(Ordinal 정렬)', async () => {
    const root = tempRoot();
    for (const suffix of ['', '.en', '.ja']) put(root, `study/001-a${suffix}.mdx`, valid('001-a'));
    const expected: Readonly<Record<string, readonly string[]>> = { ko: ['en', 'ja'], en: ['ja', 'ko'], ja: ['en', 'ko'] };
    for (const lang of ['ko', 'en', 'ja'] as const) {
      const item = bySlug(await getCollection('study', { root, lang }), '001-a', `lx-9 ${lang}`);
      expect(item.lang, `lx-9 ${lang} lang`).toBe(lang);
      expect(item.translations, `lx-9 ${lang} translations`).toEqual(expected[lang]);
    }
  });
});

describe('lx-10 변형 draft(〔90-9〕 — 파일 단위 거름 · ko가 걸러지면 slug 전체 제외)', () => {
  it('lx-10 en draft → includeDrafts false: en 요청 = ko 항목 · [] / true: en 항목 · [ko]', async () => {
    const root = tempRoot();
    put(root, 'study/001-a.mdx', valid('001-a'));
    put(root, 'study/001-a.en.mdx', valid('001-a', undefined, { draft: 'true' }));
    const off = bySlug(await getCollection('study', { root, lang: 'en', includeDrafts: false }), '001-a', 'lx-10 false');
    expect(off.lang, 'lx-10 false lang').toBe('ko');
    expect(off.translations, 'lx-10 false translations').toEqual([]);
    const on = bySlug(await getCollection('study', { root, lang: 'en', includeDrafts: true }), '001-a', 'lx-10 true');
    expect(on.lang, 'lx-10 true lang').toBe('en');
    expect(on.translations, 'lx-10 true translations').toEqual(['ko']);
  });

  it('lx-10 ko draft → slug 전체 제외(변형 공개 0) · includeDrafts true면 포함', async () => {
    const root = tempRoot();
    put(root, 'study/001-a.mdx', valid('001-a', undefined, { draft: 'true' }));
    put(root, 'study/001-a.en.mdx', valid('001-a'));
    put(root, 'study/002-b.mdx', valid('002-b'));
    for (const lang of ['ko', 'en'] as const) {
      const off = slugsOf(await getCollection('study', { root, lang, includeDrafts: false }), `lx-10 ${lang} false`);
      expect(off, `lx-10 ${lang} false slug`).toEqual(['002-b']);
      const on = slugsOf(await getCollection('study', { root, lang, includeDrafts: true }), `lx-10 ${lang} true`);
      expect(on, `lx-10 ${lang} true slug`).toEqual(['001-a', '002-b']);
    }
  });
});

describe('lx-11 스캔 규칙(〔A-1〕 · 〔A-2〕 · C3 · C8)', () => {
  it('lx-11 숨김 · 대소문자 다른 .mdx · 디렉터리 · FILE_RE 밖 이름 · 이름 위반 → 정확 quad(Ordinal) · .md · .txt 무시 · FILE_RE 밖 본문 issue 0', async () => {
    const root = tempRoot();
    put(root, 'study/.x.mdx', valid('001-x'));
    put(root, 'study/X.MDX', valid('001-x'));
    put(root, 'study/y.Mdx', valid('001-y'));
    put(root, 'study/y.md', '마크다운 파일 {x} <b>');
    put(root, 'study/notes.txt', '글 파일 {x} <b>');
    mkdirSync(join(root, 'study', 'sub.mdx'));
    put(root, 'study/노트.mdx', valid('001-n', ['{x} <b>']));
    put(root, 'study/a b.mdx', valid('001-s', ['{x} <b>']));
    put(root, 'study/01-bad.mdx', valid('001-bad', ['{x}']));
    expect(await quadsOf(root, 'lx-11'), 'lx-11 issues').toEqual([
      'study/ file name -',
      'study/ file name -',
      'study/.x.mdx file name -',
      'study/01-bad.mdx file name -',
      'study/01-bad.mdx body expression 11',
      'study/X.MDX file name -',
      'study/sub.mdx file not-regular -',
      'study/y.Mdx file name -',
    ]);
  });

  it('lx-11 이름 규칙은 대소문자를 가린다(001-a.MDX → name) · 이름 위반 파일은 ko로 치지 않는다(001-c.MDX + 001-c.en.mdx → en ko-missing)(확장)', async () => {
    const root = tempRoot();
    put(root, 'study/001-a.MDX', valid('001-a'));
    put(root, 'study/001-b.mdx', valid('001-b'));
    put(root, 'study/001-c.MDX', valid('001-c'));
    put(root, 'study/001-c.en.mdx', valid('001-c'));
    expect(await quadsOf(root, 'lx-11 대소문자'), 'lx-11 대소문자').toEqual([
      'study/001-a.MDX file name -',
      'study/001-c.MDX file name -',
      'study/001-c.en.mdx file ko-missing -',
    ]);
  });
});

describe('lx-x1 부재 해석(D8 · D16 :12–:16 해석 — 확장)', () => {
  it('lx-x1 root가 파일 → (., root, missing) · study가 파일 → (study/, collection, missing) · blog가 파일 → []', async () => {
    const fileRoot = join(tempRoot(), 'root-file');
    writeFileSync(fileRoot, '파일');
    expect(await quadsOf(fileRoot, 'lx-x1 root 파일'), 'lx-x1 root 파일').toEqual(['. root missing -']);
    const root = tempRoot();
    writeFileSync(join(root, 'study'), '파일');
    writeFileSync(join(root, 'blog'), '파일');
    expect(await quadsOf(root, 'lx-x1 study 파일'), 'lx-x1 study 파일').toEqual(['study/ collection missing -']);
    const blog = await getCollection('blog', { root });
    check(Array.isArray(blog) && blog.length === 0, 'lx-x1 blog 파일 → []');
  });
});

describe('lx-x2 YAML 1.1 태그 = 모르는 태그(정정 노트 1 — 파일 단위 · mu-79 · 확장)', () => {
  const F = 'study/001-a.mdx';

  it('lx-x2 루트 !!set 블록(계약 키를 ? 줄로) → [(…, frontmatter, yaml, -)] 하나(필드 missing 0)', async () => {
    const root = tempRoot();
    put(root, F, doc(['!!set', ...BASE_KEYS.map(([key]) => `? ${key}`)]));
    expect(await quadsOf(root, 'lx-x2 루트 !!set'), 'lx-x2 루트 !!set').toEqual([`${F} frontmatter yaml -`]);
  });

  it('lx-x2 유효 프런트매터 + pubDate: !!timestamp → [(…, frontmatter, yaml, -)] 하나((pubDate, type) 0) · 태그 없는 같은 노트는 항목(양성 짝)', async () => {
    const plain = tempRoot();
    put(plain, F, doc(keyLines()));
    expect(slugsOf(await getCollection('study', { root: plain }), 'lx-x2 양성 짝'), 'lx-x2 양성 짝 slug').toEqual(['001-a']);
    const root = tempRoot();
    put(root, F, doc(keyLines({ pubDate: '!!timestamp 2026-05-01' })));
    expect(await quadsOf(root, 'lx-x2 pubDate !!timestamp'), 'lx-x2 pubDate !!timestamp').toEqual([`${F} frontmatter yaml -`]);
  });
});

describe('lx-12 not-regular 단위(보조 — 분류 함수 · 가짜 Dirent · 변이 귀속에 쓰지 않는다 · 〔V-B-1〕)', () => {
  type Kind = 'file' | 'dir' | 'link' | 'other';
  type Classified = { kind: string; issue?: ContentIssue; file?: string; member?: { slug: string; lang: string } | null };

  /** 가짜 Dirent — parentPath는 없는 경로(따라가거나 읽는 분류는 실패한다) */
  const fake = (name: string, kind: Kind) => ({
    name,
    parentPath: join(tempRoot(), 'absent'),
    isFile: () => kind === 'file',
    isDirectory: () => kind === 'dir',
    isSymbolicLink: () => kind === 'link',
  });
  const classify = (name: string, kind: Kind): Classified => {
    const result: unknown = classifyEntry('study', fake(name, kind));
    check(!(result instanceof Promise), `lx-12 ${name} 동기(읽기 0)`);
    return result as Classified;
  };

  it.each([['dir'], ['link'], ['other']] as const)('lx-12 %s 항목 001-x.mdx → (study/001-x.mdx, file, not-regular)', (kind) => {
    const result = classify('001-x.mdx', kind);
    check(result.kind === 'rejected' && result.issue !== undefined, `lx-12 ${kind} rejected`);
    expect(quad(result.issue as ContentIssue), `lx-12 ${kind} issue`).toBe('study/001-x.mdx file not-regular -');
  });

  it('lx-12 양성 짝 — 정규 파일 → 후보(slug · lang) · X.MDX → 후보 · member null · y.md → 무시 · a b.mdx(링크여도) → (study/, file, name)', () => {
    const ko = classify('001-x.mdx', 'file');
    check(ko.kind === 'file' && ko.file === 'study/001-x.mdx', 'lx-12 정규 파일 후보');
    check(isDeepStrictEqual(ko.member, { slug: '001-x', lang: 'ko' }), 'lx-12 member ko');
    check(isDeepStrictEqual(classify('001-x.en.mdx', 'file').member, { slug: '001-x', lang: 'en' }), 'lx-12 member en');
    const upper = classify('X.MDX', 'file');
    check(upper.kind === 'file' && upper.member === null, 'lx-12 이름 규칙 위반 = member null');
    check(classify('y.md', 'file').kind === 'ignored', 'lx-12 .md 무시');
    const spaced = classify('a b.mdx', 'link');
    check(spaced.kind === 'rejected', 'lx-12 FILE_RE 밖 rejected');
    expect(quad(spaced.issue as ContentIssue), 'lx-12 FILE_RE 밖 issue(not-regular보다 먼저)').toBe('study/ file name -');
  });
});

describe('lx-12b not-regular 통합(〔A-11〕 · 〔V-A-3〕 · 〔V-B-1〕 — symlinkSync junction: Windows 권한 없이 junction · Linux 심볼릭 링크 · 건너뜀 0)', () => {
  it('lx-12b 디렉터리를 가리키는 링크 study/001-x.mdx → (study/001-x.mdx, file, not-regular) 하나 · 정리는 링크를 따라가지 않는다', async () => {
    const root = tempRoot();
    const target = tempRoot();
    writeFileSync(join(target, 'keep.txt'), 'keep');
    mkdirSync(join(root, 'study'));
    symlinkSync(target, join(root, 'study', '001-x.mdx'), 'junction');
    expect(await quadsOf(root, 'lx-12b 기본'), 'lx-12b 기본').toEqual(['study/001-x.mdx file not-regular -']);
    rmSync(root, { recursive: true, force: true });
    check(existsSync(join(target, 'keep.txt')), 'lx-12b 정리 뒤 링크 대상 그대로');
  });

  it('lx-12b (a) 끊긴 링크 study/002-y.mdx → (study/002-y.mdx, file, not-regular) 하나', async () => {
    const root = tempRoot();
    const gone = join(tempRoot(), 'gone');
    mkdirSync(gone);
    mkdirSync(join(root, 'study'));
    symlinkSync(gone, join(root, 'study', '002-y.mdx'), 'junction');
    rmSync(gone, { recursive: true, force: true });
    expect(await quadsOf(root, 'lx-12b (a)'), 'lx-12b (a)').toEqual(['study/002-y.mdx file not-regular -']);
  });

  it('lx-12b (b) 링크 study/003-z.mdx + 유효한 003-z.en.mdx → [(en, ko-missing), (링크, not-regular)](ko 이름의 not-regular = ko 없음)', async () => {
    const root = tempRoot();
    const target = tempRoot();
    mkdirSync(join(root, 'study'));
    symlinkSync(target, join(root, 'study', '003-z.mdx'), 'junction');
    put(root, 'study/003-z.en.mdx', valid('003-z'));
    expect(await quadsOf(root, 'lx-12b (b)'), 'lx-12b (b)').toEqual([
      'study/003-z.en.mdx file ko-missing -',
      'study/003-z.mdx file not-regular -',
    ]);
  });
});

describe('lx-13 blog · projects(〔90-3〕 잠정 · 〔A-17〕 · 〔V-A-10〕 · 〔V-B-13〕)', () => {
  const noChange = (over: Over = {}): string => doc(keyLines({ change: null, ...over }));

  it('lx-13 blog/my-post.mdx(change 없음) → 항목(collection blog · lang ko · data에 change 없음)', async () => {
    const root = tempRoot();
    put(root, 'blog/my-post.mdx', noChange());
    const item = bySlug(await getCollection('blog', { root }), 'my-post', 'lx-13 blog');
    expect(item.collection, 'lx-13 collection').toBe('blog');
    expect(item.lang, 'lx-13 lang').toBe('ko');
    check(!Object.hasOwn(item.data, 'change'), 'lx-13 data에 change 없음');
  });

  it('lx-13 blog/Bad_Name.mdx → (blog/Bad_Name.mdx, file, name)', async () => {
    const root = tempRoot();
    put(root, 'blog/my-post.mdx', noChange());
    put(root, 'blog/Bad_Name.mdx', noChange());
    expect(await quadsOf(root, 'lx-13 Bad_Name', 'blog'), 'lx-13 Bad_Name').toEqual(['blog/Bad_Name.mdx file name -']);
  });

  it('lx-13 한쪽에만 change → (변형, change, variant-mismatch) — ko에만 · 변형에만 / 둘 다 없음은 같다', async () => {
    const koOnly = tempRoot();
    put(koOnly, 'blog/x.mdx', valid('001-x'));
    put(koOnly, 'blog/x.en.mdx', noChange());
    expect(await quadsOf(koOnly, 'lx-13 ko에만', 'blog'), 'lx-13 ko에만').toEqual(['blog/x.en.mdx change variant-mismatch -']);
    const variantOnly = tempRoot();
    put(variantOnly, 'blog/x.mdx', noChange());
    put(variantOnly, 'blog/x.en.mdx', valid('001-x'));
    expect(await quadsOf(variantOnly, 'lx-13 변형에만', 'blog'), 'lx-13 변형에만').toEqual(['blog/x.en.mdx change variant-mismatch -']);
    const neither = tempRoot();
    put(neither, 'blog/x.mdx', noChange());
    put(neither, 'blog/x.en.mdx', noChange());
    const item = bySlug(await getCollection('blog', { root: neither }), 'x', 'lx-13 둘 다 없음');
    expect(item.translations, 'lx-13 둘 다 없음 translations').toEqual(['en']);
  });

  it('lx-13 변형 change · sources 동시 누락 → (변형, change, variant-mismatch) → (변형, sources, missing) — 없는 키끼리는 계약 키 순(재확인 RR-1 · 결정 K-7 · 확장)', async () => {
    // 변형의 문서 키 = title · description · pubDate · tags · draft. change(교차 규칙이 끼운 variant-mismatch)와 sources(missing)는 둘 다
    // 문서에 없어 계약 키 순(CONTRACT_KEYS — change → sources)으로 뒤에 선다. 끼운 차례(sources → change)와 반대라 그 순위를 가린다.
    const root = tempRoot();
    put(root, 'blog/x.mdx', valid('001-x'));
    put(root, 'blog/x.en.mdx', noChange({ sources: null }));
    expect(await quadsOf(root, 'lx-13 change · sources 동시 누락', 'blog'), 'lx-13 change · sources 동시 누락').toEqual([
      'blog/x.en.mdx change variant-mismatch -',
      'blog/x.en.mdx sources missing -',
    ]);
  });

  it('lx-13 projects/my-app.mdx(change 없음) → 항목(collection projects)', async () => {
    const root = tempRoot();
    put(root, 'projects/my-app.mdx', noChange());
    const item = bySlug(await getCollection('projects', { root }), 'my-app', 'lx-13 projects');
    expect(item.collection, 'lx-13 projects collection').toBe('projects');
  });

  it('lx-13 blog · projects도 필드 검증 · 본문 거부 규칙을 돈다(D6 「모든 컬렉션」 · 하류 sanitizer 0 — 리뷰 C RC-1 · 확장)', async () => {
    // 1 --- · 2–6 description · pubDate · tags · draft · sources · 7 --- · 8 빈 줄 · 9 본문(링크 열 1 · <b> 열 26)
    const body = ['[x](javascript:alert(1)) <b>y</b>'];
    const blog = tempRoot();
    put(blog, 'blog/my-post.mdx', doc(keyLines({ change: null, title: null }), body));
    expect(await quadsOf(blog, 'lx-13 blog 규칙', 'blog'), 'lx-13 blog 필드 · 본문').toEqual([
      'blog/my-post.mdx title missing -',
      'blog/my-post.mdx body unsafe-url 9',
      'blog/my-post.mdx body raw-html 9',
      'blog/my-post.mdx body raw-html 9',
    ]);
    const projects = tempRoot();
    put(projects, 'projects/my-app.mdx', doc(keyLines({ change: null, title: null, sources: '[{title: s, url: "javascript:x"}]' }), body));
    expect(await quadsOf(projects, 'lx-13 projects 규칙', 'projects'), 'lx-13 projects 필드 · 본문').toEqual([
      'projects/my-app.mdx sources.0.url format -',
      'projects/my-app.mdx title missing -',
      'projects/my-app.mdx body unsafe-url 9',
      'projects/my-app.mdx body raw-html 9',
      'projects/my-app.mdx body raw-html 9',
    ]);
  });
});

describe('lx-14 직렬화(〔A-12〕)', () => {
  it('lx-14 JSON 왕복 = 항목(엄격 동등 — Date · undefined 속성 · 함수 0) · 항목 키 여덟 정확(확장) · html 문자열', async () => {
    const items = await getCollection('study', { root: fixture('i18n'), lang: 'en' });
    check(items.length === 2, 'lx-14 두 항목');
    // toStrictEqual과 같은 엄격 비교(원형 · 키 집합)를 값 없는 메시지로 한다
    check(isDeepStrictEqual(JSON.parse(JSON.stringify(items)), items), 'lx-14 JSON 왕복 엄격 동등');
    for (const item of items) {
      expect(Object.keys(item), `lx-14 ${item.slug} 키`).toEqual(['collection', 'slug', 'lang', 'translations', 'data', 'readingTime', 'headings', 'html']);
      check(typeof item.html === 'string' && item.html.length > 0, `lx-14 ${item.slug} html 문자열`);
    }
  });
});

describe('lx-15 · lx-16 Node 자식(타입 스트리핑 — 〔A-6〕 · VD-T090-3)', () => {
  it('lx-15 process.execPath · 임시 cwd · NODE_ENV · JT_CONTENT_ROOT 삭제 — 픽스처 root(drafts) 기본 → 001-public만(실제 노트 draft 값과 무관 — 리뷰 C RC-5) · 기본 → draft 항목 0 · includeDrafts: true → slug ⊇ {001, 002} · stderr 0 · exit 0', () => {
    const code = [
      `const m = await import(${INDEX_URL});`,
      `const fixed = await m.getCollection('study', { root: ${JSON.stringify(fixture('drafts'))} });`,
      "const plain = await m.getCollection('study');",
      "const all = await m.getCollection('study', { includeDrafts: true });",
      'const drafts = plain.filter((item) => item.data.draft === true).length;',
      'const slugs = all.map((item) => item.slug);',
      "process.stdout.write([fixed.map((item) => item.slug).join(','), drafts, slugs.includes('001-claude-setup'), slugs.includes('002-smoke')].join('|'));",
    ].join('\n');
    const cwd = tempRoot();
    const run = runNode(code, cwd, childEnv({}, ['NODE_ENV']));
    check(run.status === 0, 'lx-15 자식 exit 0');
    check(run.stderr === '', 'lx-15 자식 stderr 0');
    const [fixedSlugs, ...rest] = run.stdout.split('|');
    // 픽스처 root를 먼저 본다 — 실제 노트가 draft: false로 바뀌어도(T086-a) N-1을 순수 Node에서 잰다(리뷰 C RC-5 · mu-01)
    check(fixedSlugs === '001-public', 'lx-15 픽스처 root(drafts) 기본 → 001-public만(N-1)');
    check(rest.join('|') === '0|true|true', 'lx-15 기본 draft 항목 0 · includeDrafts true → 001 · 002');
    expect(readdirSync(cwd), 'lx-15 자식 cwd 쓰기 0').toEqual([]);
  }, 60_000);

  it('lx-16 import만으로 실행 0 — JT_CONTENT_ROOT = 없는 경로 · import → stdout 0 · stderr 0 · exit 0 · 부를 때는 그 env를 읽는다(양성 짝)', () => {
    const cwd = tempRoot();
    const env = childEnv({ JT_CONTENT_ROOT: join(cwd, 'absent') });
    const onlyImport = runNode(`await import(${INDEX_URL});`, cwd, env);
    check(onlyImport.status === 0, 'lx-16 import 자식 exit 0');
    check(onlyImport.stdout === '' && onlyImport.stderr === '', 'lx-16 import 자식 출력 0');
    expect(readdirSync(cwd), 'lx-16 import 자식 cwd 쓰기 0').toEqual([]);
    const called = runNode(
      [
        `const m = await import(${INDEX_URL});`,
        "let out = 'resolved';",
        "try { await m.getCollection('study'); } catch (error) { out = error.name + '|' + error.message; }",
        'process.stdout.write(out);',
      ].join('\n'),
      cwd,
      env,
    );
    check(called.status === 0 && called.stderr === '', 'lx-16 호출 자식 exit 0 · stderr 0');
    check(called.stdout === 'ContentValidationError|.: root (missing)', 'lx-16 호출 자식 = env root 부재 오류');
  }, 60_000);
});

describe('lx-17 산출 필드 — 실제 노트(기본 root = 저장소 content/)', () => {
  it('lx-17 001 · 002 html 문자열 · headings h2 다섯(ld-1과 같은 값 · 순서) · html에 그 h2 id(확장)', async () => {
    const items = await getCollection('study', { includeDrafts: true });
    for (const slug of REAL) {
      const item = bySlug(items, slug, 'lx-17');
      check(typeof item.html === 'string' && item.html.length > 0, `lx-17 ${slug} html 문자열`);
      const h2 = item.headings.filter((heading) => heading.depth === 2);
      expect(h2.map((heading) => heading.id), `lx-17 ${slug} h2 id`).toEqual(SECTION_IDS);
      check(h2.map((heading) => heading.text).join('|') === SECTION_TEXTS.join('|'), `lx-17 ${slug} h2 text`);
      SECTION_IDS.forEach((id, index) => {
        check(item.html.includes(`<h2 id="${id}">`), `lx-17 ${slug} html에 h2 id #${index}`);
      });
    }
  });
});

describe('lx-18 정적 규율(〔B-11〕 · 〔V-A-2〕 · §6-5 · 확장: 리뷰 B RB-2 네트워크 가져오기)', () => {
  type Banned = { readonly id: string; readonly re: RegExp; readonly hit: string | readonly string[]; readonly miss?: string | readonly string[] };
  const BANNED: readonly Banned[] = [
    { id: 'console', re: /console\./, hit: 'console.log(1)' },
    { id: 'emitWarning', re: /emitWarning/, hit: 'process.emitWarning(w)' },
    { id: 'YAML.parse', re: /YAML\.parse\(/, hit: 'YAML.parse(block)' },
    { id: 'yaml 바인딩 .parse(', re: /\byaml\.parse\(/i, hit: 'yaml.parse(block)', miss: 'processor.parse(text) JSON.parse(text) readYamlBlock(block)' },
    {
      id: 'yaml parse 가져오기',
      re: /import\s*\{[^}]*\bparse\b[^}]*\}\s*from\s*['"]yaml['"]/,
      hit: "import { isMap, parse as readYaml } from 'yaml'",
      miss: "import { isMap, parseDocument, visit as visitYaml } from 'yaml'",
    },
    { id: 'cause 옵션', re: /\{\s*cause\b/, hit: 'new Error(message, { cause })' },
    { id: 'allowDangerousHtml true', re: /allowDangerousHtml\s*:\s*true/, hit: '{ allowDangerousHtml: true }', miss: '{ allowDangerousHtml: false }' },
    { id: 'remark-mdx', re: /remark-mdx/, hit: "import x from 'remark-mdx'" },
    { id: 'rehype-raw', re: /rehype-raw/, hit: "import x from 'rehype-raw'" },
    { id: 'react', re: /from\s*['"]react['"]/, hit: "import { cache } from 'react'" },
    { id: 'fetch(', re: /\bfetch\(/, hit: 'await fetch(url)' },
    { id: 'node:http · node:https', re: /node:https?\b/, hit: "import http from 'node:http'" },
    { id: 'node:net', re: /node:net\b/, hit: "import net from 'node:net'" },
    { id: 'node:child_process', re: /node:child_process/, hit: "import cp from 'node:child_process'" },
    {
      // 확장(리뷰 B RB-2): node: 접두 없는 내장 · node:http2 · 하위 경로까지 — 가져오기 자리(from · import · import() · require())로 좁혀
      // 스킴 비교 문자열('http' · 'https')과 겹치지 않게 한다
      id: '네트워크 · 프로세스 내장 가져오기(접두 무관)',
      re: /(?:\bfrom\s*|\bimport\s*\(\s*|\bimport\s+|\brequire\s*\(\s*)['"](?:node:)?(?:https?|http2|net|tls|dgram|dns|child_process|worker_threads)(?:\/[A-Za-z_]+)?['"]/,
      hit: [
        "import http from 'http'",
        "import { request } from 'https'",
        "export { request } from 'https'",
        "import { connect } from 'node:http2'",
        "import tls from 'tls'",
        "import dgram from 'node:dgram'",
        "import { lookup } from 'dns/promises'",
        "import 'net'",
        "const cp = require('child_process')",
        "await import('worker_threads')",
      ],
      miss: [
        "if (name !== 'http' && name !== 'https') return false;",
        "new Set(['http', 'https', 'mailto'])",
        "import { readdir } from 'node:fs/promises'",
        "import { netlify } from 'netlify'",
      ],
    },
    { id: 'undici', re: /\bundici\b/, hit: "import { request } from 'undici'" },
    { id: 'WebSocket', re: /\bWebSocket\b/, hit: "new WebSocket('wss://example.invalid/')" },
    { id: 'eval(', re: /\beval\(/, hit: 'eval(code)', miss: 'retrieval(x)' },
    { id: 'new Function', re: /new\s+Function\b/, hit: 'new Function(code)' },
  ];
  const count = (text: string, token: string): number => text.split(token).length - 1;
  const sourceFiles = (): string[] => readdirSync(SRC).filter((name) => name.endsWith('.ts')).sort();

  it('lx-18 패턴 자가 시험 — 금지 패턴마다 표본은 잡고 허용 꼴은 놓는다(확장)', () => {
    for (const banned of BANNED) {
      [banned.hit].flat().forEach((sample, index) => {
        check(banned.re.test(sample), `lx-18 ${banned.id} 표본 #${index}을 잡는다`);
      });
      [banned.miss ?? []].flat().forEach((sample, index) => {
        check(!banned.re.test(sample), `lx-18 ${banned.id} 허용 꼴 #${index}을 놓는다`);
      });
    }
  });

  it('lx-18 src/*.ts에 금지 토큰 0 · process.stdout · process.stderr는 schema.ts CLI 블록에 한 곳씩 · 그 밖 파일 0', () => {
    const files = sourceFiles();
    check(['index.ts', 'loader.ts', 'mdx.ts', 'schema.ts'].every((name) => files.includes(name)), 'lx-18 src 파일 넷');
    for (const name of files) {
      const text = readFileSync(join(SRC, name), 'utf8');
      for (const banned of BANNED) check(!banned.re.test(text), `lx-18 ${name} 금지 토큰 0(${banned.id})`);
      const stdout = count(text, 'process.stdout');
      const stderr = count(text, 'process.stderr');
      if (name === 'schema.ts') {
        const block = text.indexOf('if (isEntryPoint())');
        check(stdout === 1 && stderr === 1, 'lx-18 schema.ts process.stdout · process.stderr 한 곳씩');
        check(block >= 0 && text.indexOf('process.stdout') > block && text.indexOf('process.stderr') > block, 'lx-18 schema.ts 출력은 CLI 블록 안');
      } else {
        check(stdout === 0 && stderr === 0, `lx-18 ${name} process.stdout · process.stderr 0`);
      }
    }
  });

  it('lx-18 loader.ts 메모 주석 — 「tasks.md T090 『React.cache 1회』 = 이 모듈 메모(〔90-1〕)」(D8 · 확장)', () => {
    const text = readFileSync(join(SRC, 'loader.ts'), 'utf8');
    check(text.includes('tasks.md T090 『React.cache 1회』 = 이 모듈 메모(〔90-1〕)'), 'lx-18 loader.ts 메모 주석');
  });
});
