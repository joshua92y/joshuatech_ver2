// packages/content/tests/loader.test.ts — T086(US5 · 시험 먼저 · vitest). 짝 구현 = T090 `packages/content/src/{schema,loader,mdx,index}.ts`.
//
// 과제(tasks.md T086): 001·002 노트 로드(제목·날짜·태그·slug·lang ko), `pubDate` 누락 fixture → 오류,
//   `<slug>.en.mdx` → lang en + translations 연결, ko 파일 없음 → 오류, `draft:true`는 PROD에서 제외,
//   `updatedDate < pubDate` → 오류, remark 헤딩 앵커·읽기 시간 — FAIL 확인.
// 정본: specs/003-platform-foundation/design/t086-design.md D4 · D12 · §7 N-1 · N-2 · N-3 · N-7 · N-13(§7이 본문을 이긴다)
//   · .claude/rules/content.md · data-model.md §11 · spec AC2 · FR-029. 「수정 r1」 표시 = 리뷰 r0 A-1 · A-7 · B-1 · B-4의 컨트롤러 결정
//   · 「수정 r2」 표시 = 검증 r1 V1-2의 컨트롤러 결정.
// 빨강(T090 전): 이 파일을 수집할 때 "../src/index" 로드가 실패한다(구현 없음).
//
// 이 시험이 고정하는 모듈 API(시험 머리 주석이 정본 — T090은 이름 · 꼴 그대로 만족한다):
//   getCollection(name: 'study' | 'blog' | 'projects',
//                 opts?: { lang?: 'ko' | 'en' | 'ja', includeDrafts?: boolean, root?: string }) => Promise<ContentItem[]>
//     · root = study/ · blog/ · projects/를 담는 디렉터리. 기본 = 저장소 content/(패키지 위치 기준 · cwd 무관)
//       · env JT_CONTENT_ROOT가 있으면 기본 대신 그 값. root 부재 → (., root, missing) · study/ 부재 → (study/, collection,
//       missing) · blog/ · projects/ 부재 → [] · 모르는 컬렉션 → TypeError.
//     · includeDrafts 기본 = 호출 시점의 NODE_ENV가 정확히 'development' 또는 'test'일 때만 true(미설정 · 'production' · 그 밖은
//       false — N-1). 모든 파일을 검증한 뒤 draft를 거른다(draft인 위반 파일도 오류).
//     · 본문 절(content.md의 다섯 절 · 순서 · 비어 있지 않음)은 검증하지 않는다 — 사람 검토와 /finish Study contract가 맡고,
//       실제 노트는 ld-1이 지킨다(수정 r1 · A-1).
//     · lang 미지정 = 'ko'. 요청 로케일 변형이 없으면 ko 항목(lang: 'ko'). slug마다 항목 하나. .mdx가 아닌 파일은 무시.
//     · study 파일 이름 = ^\d{3}-[a-z0-9-]+(\.(en|ja))?\.mdx$ · 같은 slug의 변형은 pubDate · change가 ko와 같고 ko 파일 필수.
//     · 정렬: pubDate 내림차순 → 같으면 slug 오름차순.
//   ContentItem = { collection, slug(파일 이름 — 언어 접미사 · 확장자 제외), lang, translations(같은 slug의 다른 lang · 정렬),
//                   data(프런트매터), readingTime(분 · 정수 ≥ 1), headings: { depth: 2 | 3, text, id }[] }
//     · data.pubDate · data.updatedDate = 'YYYY-MM-DD' 문자열 하나(Date 객체 아님 · 따옴표 없는 YAML 날짜도 같은 문자열 — T091
//       time[datetime] · 수정 r1 · A-7).
//     · 헤딩 id = github-slugger(rehype-slug — 한글 보존 · 공백 '-' · 중복 '-1'). 키 집합은 정확 단언하지 않는다(T090이 더한다).
//   class ContentValidationError extends Error { name = 'ContentValidationError';
//                   issues: { file: string, field: string, code: string, line?: number }[] }
//     · 위반은 모아 하나로 던진다. issues 순서 = file(Ordinal) → 문서 순(N-7).
//     · file = root 상대 '/' 경로(root 자체 '.' · 컬렉션 디렉터리 'study/').
//     · field = zod 경로를 '.'로 이은 것(sources.0.url) 또는 교차 규칙의 키 — series 짝 위반은 빠진 쪽 키 · sources 원소에
//       path · url이 둘 다 있거나 둘 다 없으면 'sources.<i>' · 변형의 pubDate · change 어긋남은 그 변형 파일의 'pubDate' · 'change'
//       · 모르는 키는 그 키 이름 · study 파일 이름 위반과 ko 파일이 없는 변형은 'file'(code는 아래 file 줄).
//     · sources[].url = http(s) 절대 URL만 · sources[].path = ^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$ 이고 '.' · '..' 세그먼트 0(N-13).
//     · field가 'body' · 'frontmatter' · 'file'이면 code = 규칙 이름:
//       body        raw-html · esm · expression · unsafe-url — line 필수(파일 첫 줄 = 1). raw-html은 html 노드마다 하나(글줄
//                   안의 여는 · 닫는 태그는 각각 하나) · expression은 텍스트 노드마다 하나이고 line = 노드 시작 줄 · image alt와
//                   link · image · definition title의 중괄호도 본다(N-7). 트리 전체를 돈다 — 목록 항목 · 인용 · 표 칸 · 헤딩
//                   · 링크 글자 · 각주 정의 안의 위반도 같은 issue다(수정 r1 · B-4).
//       frontmatter fence(첫 줄이 정확히 '---'가 아님 — BOM · '---js' 포함 · 닫는 '---' 없음) · yaml(구문 · 중복 키 · 모르는 태그 · 경고)
//       file        encoding(엄격 UTF-8 실패 — BOM은 지우지 않고 남겨 fence로 판정한다 · N-3) · (수정 r1 · A-7) name(study 파일
//                   이름 규칙 위반) · ko-missing(같은 slug의 ko 파일 없음 — 그 slug의 변형 파일마다 하나)
//       울타리 · YAML이 실패한 파일에는 스키마 · 본문 규칙을 돌리지 않는다(그 파일의 issue는 하나 — N-7).
//     · message = issue마다 `<file>[:<line>]: <field> (<code>)` 한 줄을 '\n'으로 이은 것.
//     · 입력 값 0(N-2 · 수정 r1 · B-1): 오류 객체 전체 — message · issues · stack · util.inspect 출력(cause · 자기 속성 포함) — 에
//       입력 값(위반 URL · 프런트매터 값 · 원문 줄)이 없다. cause 0(Error 생성자에 { cause }를 넘기지 않는다 — YAML · 디코더
//       오류를 싣지 않는다) · 자기 속성 키는 issues · name · message · stack뿐.
// 시험 단언은 값을 출력하지 않는다 — 실패 메시지는 사례 id · 파일 · 필드 · 규칙 이름 · 줄만.
// 픽스처: tests/fixtures/<case>/study/*.mdx(커밋 · 짧은 노트). BOM · 깨진 UTF-8 · 긴 글 · 빈 root는 실행 중 mkdtemp에 만든다.

import { Buffer } from 'node:buffer';
import { copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inspect } from 'node:util';

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ContentValidationError, getCollection } from '../src/index';

type Issue = { file: string; field: string; code: string; line?: number };
type Heading = { depth: number; text: string; id: string };
type Item = {
  collection: string;
  slug: string;
  lang: string;
  translations: string[];
  data: Record<string, unknown>;
  readingTime: number;
  headings: Heading[];
};

const FIXTURES = fileURLToPath(new URL('./fixtures', import.meta.url));
const fixture = (name: string): string => join(FIXTURES, name);
const BS = String.fromCharCode(92); // 역슬래시(소스에 이스케이프를 두지 않는다)

// content.md:28 본문 절 — 순서 그대로
const SECTION_TEXTS = ['문제', '배운 개념', '선택과 대안', '결과와 검증', '다음 학습'];
const SECTION_IDS = ['문제', '배운-개념', '선택과-대안', '결과와-검증', '다음-학습'];

const temps: string[] = [];

beforeEach(() => {
  // 개발자 env의 JT_CONTENT_ROOT가 기본 root · 픽스처 root를 가리지 않게 지운다(afterEach가 되돌린다)
  vi.stubEnv('JT_CONTENT_ROOT', undefined);
});

afterEach(() => {
  vi.unstubAllEnvs();
  for (const dir of temps.splice(0)) rmSync(dir, { recursive: true, force: true });
});

/** afterEach가 지우는 빈 임시 디렉터리 */
function tempRoot(): string {
  const dir = mkdtempSync(join(tmpdir(), 'jt-content-'));
  temps.push(dir);
  return dir;
}

/** root 아래 rel('/' 경로)에 쓴다 — 상위 디렉터리를 만든다 */
function put(root: string, rel: string, content: string | Uint8Array): void {
  const full = join(root, ...rel.split('/'));
  mkdirSync(dirname(full), { recursive: true });
  writeFileSync(full, content);
}

/** 유효한 study 노트 원문(실행 중 픽스처) */
function noteText(slug: string, body: string): string {
  return [
    '---',
    `title: "생성 노트 ${slug}"`,
    'description: "실행 중에 만든 픽스처."',
    'pubDate: 2026-05-01',
    'tags: []',
    'draft: false',
    `change: "${slug}"`,
    'sources: []',
    '---',
    '',
    body,
    '',
  ].join('\n');
}

/** 한국어 낱말 n개 — 50개마다 문단을 나눈다(읽기 시간 픽스처) */
function words(n: number): string {
  const pool = ['학습', '노트', '본문', '문장', '읽기', '시간', '측정', '단어'];
  const all: string[] = [];
  for (let k = 0; k < n; k += 1) all.push(pool[k % pool.length]);
  const paragraphs: string[] = [];
  for (let k = 0; k < all.length; k += 50) paragraphs.push(`${all.slice(k, k + 50).join(' ')}.`);
  return paragraphs.join('\n\n');
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

// issue 필드 꼴 — 값이 섞이면 diff 출력 전에 값 없는 실패로 멈춘다
const FILE_RE = /^(?:\.|[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._-]+)*\/?)$/;
const FIELD_RE = /^[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*$/;
const CODE_RE = /^[A-Za-z0-9_:-]+$/;

const formatIssue = (i: Issue): string => `${i.file}${i.line === undefined ? '' : `:${i.line}`}: ${i.field} (${i.code})`;
const pair = (i: Issue): string => `${i.file} ${i.field}`;
const triple = (i: Issue): string => `${i.file} ${i.field} ${i.code}`;
const quad = (i: Issue): string => `${i.file} ${i.field} ${i.code} ${i.line ?? '-'}`;

/** value 안의 모든 문자열(깊이 6까지) */
function stringsIn(value: unknown, out: string[] = [], depth = 0): string[] {
  if (depth > 6) return out;
  if (typeof value === 'string') out.push(value);
  else if (Array.isArray(value)) for (const v of value) stringsIn(v, out, depth + 1);
  else if (value !== null && typeof value === 'object') for (const v of Object.values(value)) stringsIn(v, out, depth + 1);
  return out;
}

// 오류 객체의 자기 속성으로 허용하는 키 — 그 밖(cause · 원문을 실은 속성)은 0(수정 r1 · B-1)
const ERROR_OWN_KEYS: ReadonlySet<PropertyKey> = new Set<PropertyKey>(['issues', 'name', 'message', 'stack']);

/**
 * thrown이 ContentValidationError이고 issues · message가 계약 꼴인지 본다(클래스 · 이름 · cause 0 · 자기 속성 키
 * · issues ≥ 1 · 필드 꼴 · body line 필수 · 메시지 = issue 줄들 · needles(입력 값) 0). 바늘은 오류 객체 전체를 본다 —
 * message · issues · stack · util.inspect(depth 무제한 — cause · 자기 속성까지)(수정 r1 · B-1). 통과하면 issues를 돌려준다.
 */
function expectContentError(thrown: unknown, label: string, needles: readonly string[] = []): Issue[] {
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
    const i = entry as Partial<Issue>;
    check(typeof i.file === 'string' && FILE_RE.test(i.file), `${at}.file 꼴`);
    check(typeof i.field === 'string' && FIELD_RE.test(i.field), `${at}.field 꼴`);
    check(typeof i.code === 'string' && CODE_RE.test(i.code), `${at}.code 꼴`);
    check(i.line === undefined || (Number.isInteger(i.line) && (i.line as number) >= 1), `${at}.line 꼴`);
    if (i.field === 'body') check(Number.isInteger(i.line), `${at} body issue의 line 필수`);
  });
  const issues = raw as Issue[];
  const haystack = [String(error.message), String(error.stack), inspect(error, { depth: null }), ...stringsIn(issues)].map((s) =>
    s.toLowerCase(),
  );
  needles.forEach((needle, index) => {
    check(!haystack.some((s) => s.includes(needle.toLowerCase())), `${label}: 오류 객체에 입력 값 0(needle #${index})`);
  });
  check(error.message === issues.map(formatIssue).join('\n'), `${label}: message = issue 줄들('<file>[:<line>]: <field> (<code>)')`);
  return issues;
}

/** items에서 slug 항목 하나를 찾는다(없거나 둘 이상이면 값 없는 실패) */
function bySlug(items: unknown, slug: string, label: string): Item {
  check(Array.isArray(items), `${label}: 배열`);
  const found = (items as Item[]).filter((item) => item !== null && typeof item === 'object' && item.slug === slug);
  check(found.length === 1, `${label}: ${slug} 항목 정확히 하나`);
  return found[0];
}

function slugsOf(items: unknown, label: string): string[] {
  check(Array.isArray(items), `${label}: 배열`);
  return (items as Item[]).map((item) => item.slug);
}

describe('ld-1 실제 노트 — 기본 root(저장소 content/) · includeDrafts: true', () => {
  const REAL = [
    { slug: '001-claude-setup', pubDate: '2026-08-26' },
    { slug: '002-smoke', pubDate: '2026-08-27' },
  ];

  it('ld-1 001 · 002 — lang ko · translations [] · collection study · title · pubDate · change = slug · tags ∋ claude-code · readingTime ≥ 1', async () => {
    const items = await getCollection('study', { includeDrafts: true });
    for (const { slug, pubDate } of REAL) {
      const item = bySlug(items, slug, 'ld-1');
      const at = `ld-1 ${slug}`;
      expect(item.lang, `${at} lang`).toBe('ko');
      expect(item.translations, `${at} translations`).toEqual([]);
      expect(item.collection, `${at} collection`).toBe('study');
      check(typeof item.data.title === 'string' && item.data.title.length > 0, `${at} title 비지 않음`);
      check(item.data.pubDate === pubDate, `${at} pubDate = 'YYYY-MM-DD' 문자열`);
      check(item.data.change === slug, `${at} change = slug`);
      check(Array.isArray(item.data.tags) && item.data.tags.includes('claude-code'), `${at} tags ∋ claude-code`);
      check(Number.isInteger(item.readingTime) && item.readingTime >= 1, `${at} readingTime 정수 ≥ 1`);
    }
  });

  it('ld-1 h2 다섯 = content.md 절 순서 · id 문제 · 배운-개념 · 선택과-대안 · 결과와-검증 · 다음-학습', async () => {
    const items = await getCollection('study', { includeDrafts: true });
    for (const { slug } of REAL) {
      const h2 = bySlug(items, slug, 'ld-1').headings.filter((h) => h.depth === 2);
      expect(h2.map((h) => h.id), `ld-1 ${slug} h2 id`).toEqual(SECTION_IDS);
      check(h2.map((h) => h.text).join('|') === SECTION_TEXTS.join('|'), `ld-1 ${slug} h2 text`);
    }
  });

  it('ld-1 정렬 — 002(2026-08-27)가 001(2026-08-26)보다 앞', async () => {
    const slugs = slugsOf(await getCollection('study', { includeDrafts: true }), 'ld-1');
    const i001 = slugs.indexOf('001-claude-setup');
    const i002 = slugs.indexOf('002-smoke');
    check(i001 >= 0 && i002 >= 0 && i002 < i001, 'ld-1 002가 001보다 앞');
  });
});

describe('ld-2 pubDate 누락', () => {
  it('ld-2 pubDate 누락 → 오류(그 파일, pubDate)', async () => {
    const thrown = await failure(() => getCollection('study', { root: fixture('missing-pubdate') }));
    const issues = expectContentError(thrown, 'ld-2');
    expect(issues.map(pair)).toEqual(['study/001-missing-pubdate.mdx pubDate']);
  });
});

describe('ld-3 다국어 — <slug>.en.mdx · translations', () => {
  const root = fixture('i18n');

  it('ld-3 lang en → en 변형(lang en · translations [ko]) · ko만인 slug → lang ko · []', async () => {
    const items = await getCollection('study', { root, lang: 'en' });
    const hello = bySlug(items, '001-hello', 'ld-3 en');
    expect(hello.lang, 'ld-3 en 001-hello lang').toBe('en');
    expect(hello.translations, 'ld-3 en 001-hello translations').toEqual(['ko']);
    check(hello.data.title === 'Hello note', 'ld-3 en 001-hello data = en 파일');
    const koOnly = bySlug(items, '002-ko-only', 'ld-3 en');
    expect(koOnly.lang, 'ld-3 en 002-ko-only lang').toBe('ko');
    expect(koOnly.translations, 'ld-3 en 002-ko-only translations').toEqual([]);
  });

  it('ld-3 lang ja → 번역 없으면 ko 항목(lang ko · translations [en])', async () => {
    const items = await getCollection('study', { root, lang: 'ja' });
    const hello = bySlug(items, '001-hello', 'ld-3 ja');
    expect(hello.lang, 'ld-3 ja 001-hello lang').toBe('ko');
    expect(hello.translations, 'ld-3 ja 001-hello translations').toEqual(['en']);
    check(hello.data.title === '안녕 노트', 'ld-3 ja 001-hello data = ko 파일');
    const koOnly = bySlug(items, '002-ko-only', 'ld-3 ja');
    expect(koOnly.lang, 'ld-3 ja 002-ko-only lang').toBe('ko');
    expect(koOnly.translations, 'ld-3 ja 002-ko-only translations').toEqual([]);
  });

  it('ld-3 lang ko · 미지정 → ko 항목(translations [en])', async () => {
    for (const lang of ['ko', undefined] as const) {
      const at = `ld-3 lang=${String(lang)}`;
      const items = await getCollection('study', lang === undefined ? { root } : { root, lang });
      const hello = bySlug(items, '001-hello', at);
      expect(hello.lang, `${at} 001-hello lang`).toBe('ko');
      expect(hello.translations, `${at} 001-hello translations`).toEqual(['en']);
      const koOnly = bySlug(items, '002-ko-only', at);
      expect(koOnly.translations, `${at} 002-ko-only translations`).toEqual([]);
    }
  });

  it('ld-3 slug마다 항목 하나 · 같은 pubDate는 slug 오름차순 · .mdx 아닌 파일 무시', async () => {
    for (const lang of ['ko', 'en', 'ja'] as const) {
      const slugs = slugsOf(await getCollection('study', { root, lang }), `ld-3 ${lang}`);
      expect(slugs, `ld-3 ${lang} slug 순서`).toEqual(['001-hello', '002-ko-only']);
    }
  });
});

describe('ld-4 ko 파일 없음', () => {
  // 픽스처 = 같은 slug의 en · ja 변형 둘(pubDate · change 같음 · 그 밖의 위반 0) — 머리 주석 「그 slug의 변형 파일마다 하나」를
  //   고정한다: slug마다 issue 하나만 내는 구현이 통과하지 못하게(수정 r2 · V1-2)
  // 입력 값 바늘 = 두 변형의 title · description(B-1 — ko-missing 갈래에서만 값을 싣는 구현도 막는다)
  const NEEDLES = ['Orphan translation', 'No Korean original.', '孤立した翻訳', '韓国語の原文がない。'];

  it('ld-4 en · ja 변형만 있고 ko 없음 → 변형 파일마다 오류(그 변형 파일, file, ko-missing) · 오류 객체에 입력 값 0', async () => {
    const thrown = await failure(() => getCollection('study', { root: fixture('ko-missing') }));
    const issues = expectContentError(thrown, 'ld-4', NEEDLES);
    expect(issues.map(triple), 'ld-4 issues').toEqual([
      'study/001-orphan.en.mdx file ko-missing',
      'study/001-orphan.ja.mdx file ko-missing',
    ]);
  });
});

describe('ld-5 draft — 프로덕션 제외(N-1: 기본값은 닫힌 쪽)', () => {
  const root = fixture('drafts');

  it('ld-5 includeDrafts 명시 — false → 제외 · true → 포함', async () => {
    const off = slugsOf(await getCollection('study', { root, includeDrafts: false }), 'ld-5 false');
    expect(off, 'ld-5 includeDrafts false').toEqual(['001-public']);
    const on = slugsOf(await getCollection('study', { root, includeDrafts: true }), 'ld-5 true');
    expect([...on].sort(), 'ld-5 includeDrafts true').toEqual(['001-public', '002-draft']);
  });

  it.each([
    ['production', false],
    ['test', true],
    ['development', true],
    ['staging', false],
    [undefined, false],
  ] as const)('ld-5 기본값 — NODE_ENV=%s → draft 포함 %s', async (env, included) => {
    vi.stubEnv('NODE_ENV', env);
    const at = `ld-5 NODE_ENV=${String(env)}`;
    const slugs = slugsOf(await getCollection('study', { root }), at);
    check(slugs.includes('001-public'), `${at} 공개 노트 있음`);
    check(slugs.includes('002-draft') === included, `${at} draft 포함 = ${String(included)}`);
  });
});

describe('ld-6 draft인 위반 파일', () => {
  it('ld-6 draft: true여도 검증한다 — includeDrafts: false에서 오류(그 파일, description)', async () => {
    const thrown = await failure(() => getCollection('study', { root: fixture('draft-invalid'), includeDrafts: false }));
    const issues = expectContentError(thrown, 'ld-6');
    expect(issues.map(pair)).toEqual(['study/001-draft-broken.mdx description']);
  });
});

describe('ld-7 updatedDate < pubDate', () => {
  it('ld-7 updatedDate가 pubDate보다 앞 → 오류(그 파일, updatedDate)', async () => {
    const thrown = await failure(() => getCollection('study', { root: fixture('updated-before') }));
    const issues = expectContentError(thrown, 'ld-7');
    expect(issues.map(pair)).toEqual(['study/001-updated-before.mdx updatedDate']);
  });

  it('ld-7 같은 날은 통과', async () => {
    const item = bySlug(await getCollection('study', { root: fixture('updated-same') }), '001-updated-same', 'ld-7 같은 날');
    check(item.data.updatedDate === '2026-02-10', "ld-7 같은 날 updatedDate = 'YYYY-MM-DD' 문자열");
  });
});

describe('ld-8 헤딩 앵커', () => {
  it('ld-8 같은 제목 둘 → 같은-제목 · 같은-제목-1 · depth 3 포함', async () => {
    const item = bySlug(await getCollection('study', { root: fixture('headings') }), '001-headings', 'ld-8');
    expect(item.headings.map((h) => `${h.depth} ${h.id}`), 'ld-8 depth · id').toEqual(['2 같은-제목', '2 같은-제목-1', '3 하위']);
    check(item.headings.map((h) => h.text).join('|') === '같은 제목|같은 제목|하위', 'ld-8 text');
  });
});

describe('ld-9 읽기 시간', () => {
  it('ld-9 약 50단어 · 2,100단어 → 긴 글 > 짧은 글 · 정수 ≥ 1', async () => {
    const root = tempRoot();
    put(root, 'study/001-short.mdx', noteText('001-short', words(50)));
    put(root, 'study/002-long.mdx', noteText('002-long', words(2100)));
    const items = await getCollection('study', { root });
    const short = bySlug(items, '001-short', 'ld-9');
    const long = bySlug(items, '002-long', 'ld-9');
    check(Number.isInteger(short.readingTime) && short.readingTime >= 1, 'ld-9 짧은 글 정수 ≥ 1');
    check(Number.isInteger(long.readingTime) && long.readingTime >= 1, 'ld-9 긴 글 정수 ≥ 1');
    check(long.readingTime > short.readingTime, 'ld-9 긴 글 > 짧은 글');
  });
});

describe('ld-10 data-model §11 규칙 — 각각 오류(파일, 필드 정확)', () => {
  const root = fixture('schema-violations');
  // 입력 값 바늘 — 오류 객체 전체(메시지 · issues · stack · inspect)에 나오면 안 된다(N-2 · 수정 r1 · B-1 · CI 빌드 로그는 공개다)
  const NEEDLES = ['alert(1)', 'text/html', '//host', 'Bad_Change', 'evil.example', `a${BS}b`, '../x', '007-other-change', 'sample-series'];
  const CASES: Array<[string, string]> = [
    ['study/001-series-only.mdx', 'seriesOrder'],
    ['study/002-series-order-only.mdx', 'series'],
    ['study/003-bad-change.mdx', 'change'],
    ['study/004-source-both.mdx', 'sources.0'],
    ['study/005-source-none.mdx', 'sources.0'],
    ['study/006-variant-pubdate.en.mdx', 'pubDate'],
    ['study/007-variant-change.en.mdx', 'change'],
    ['study/008-unknown-key.mdx', 'pubdate'],
    ['study/009-url-js.mdx', 'sources.0.url'],
    ['study/010-url-data.mdx', 'sources.0.url'],
    ['study/011-url-scheme-relative.mdx', 'sources.0.url'],
    ['study/012-path-absolute.mdx', 'sources.0.path'],
    ['study/013-path-backslash.mdx', 'sources.0.path'],
    ['study/014-path-dotdot.mdx', 'sources.0.path'],
    ['study/015-path-js.mdx', 'sources.0.path'],
    ['study/016-path-url.mdx', 'sources.0.path'],
    ['study/no-number.mdx', 'file'],
  ];
  const issuesOf = async (): Promise<Issue[]> =>
    expectContentError(await failure(() => getCollection('study', { root })), 'ld-10', NEEDLES);

  it.each(CASES)('ld-10 %s → field %s', async (file, field) => {
    const issues = await issuesOf();
    expect(issues.filter((i) => i.file === file).map((i) => i.field), `ld-10 ${file}`).toEqual([field]);
  });

  it('ld-10 study 파일 이름 위반 → code까지 (file, name)(수정 r1 · A-7)', async () => {
    const issues = (await issuesOf()).filter((i) => i.file === 'study/no-number.mdx');
    expect(issues.map(triple), 'ld-10 study/no-number.mdx').toEqual(['study/no-number.mdx file name']);
  });

  it('ld-10 issue가 난 파일 = 사례 파일뿐(유효한 ko 원본 006 · 007은 issue 없음)', async () => {
    const files = [...new Set((await issuesOf()).map((i) => i.file))].sort();
    expect(files, 'ld-10 issue 파일 집합').toEqual(CASES.map(([file]) => file).sort());
  });
});

describe('ld-11 모아 던지기', () => {
  it('ld-11 위반 파일 2 → 오류 1 · 두 파일 모두', async () => {
    const thrown = await failure(() => getCollection('study', { root: fixture('collect') }));
    const issues = expectContentError(thrown, 'ld-11');
    expect(issues.map(pair)).toEqual(['study/001-first-bad.mdx title', 'study/002-second-bad.mdx tags']);
  });
});

describe('ld-12 컬렉션', () => {
  const root = fixture('i18n');

  it('ld-12 없는 blog/ · projects/ → [](같은 root의 study는 항목)', async () => {
    check(slugsOf(await getCollection('study', { root }), 'ld-12 study').length >= 1, 'ld-12 study 항목 있음');
    const blog = await getCollection('blog', { root });
    check(Array.isArray(blog) && blog.length === 0, 'ld-12 blog = []');
    const projects = await getCollection('projects', { root });
    check(Array.isArray(projects) && projects.length === 0, 'ld-12 projects = []');
  });

  it('ld-12 모르는 컬렉션 이름 → TypeError(아는 이름은 정상)', async () => {
    check(slugsOf(await getCollection('study', { root }), 'ld-12 study').length >= 1, 'ld-12 study 항목 있음');
    const thrown = await failure(() => getCollection('nope' as never, { root }));
    check(thrown instanceof TypeError, 'ld-12 모르는 컬렉션 TypeError');
  });
});

describe('ld-12b root 부재', () => {
  // 부재 오류는 양성 상태와 짝으로 본다 — 언제나 같은 오류를 던지는 구현이 통과하지 못하게
  const presentRootWorks = async (label: string): Promise<void> => {
    check(slugsOf(await getCollection('study', { root: fixture('i18n') }), label).length >= 1, `${label}: 있는 root는 항목`);
  };

  it('ld-12b root가 없음 → (., root, missing)(있는 root는 정상)', async () => {
    await presentRootWorks('ld-12b root');
    const root = join(tempRoot(), 'absent');
    const issues = expectContentError(await failure(() => getCollection('study', { root })), 'ld-12b root');
    expect(issues.map(triple)).toEqual(['. root missing']);
  });

  it('ld-12b study/가 없음 → (study/, collection, missing)(있는 root는 정상)', async () => {
    await presentRootWorks('ld-12b study');
    const root = tempRoot();
    mkdirSync(join(root, 'blog'));
    const issues = expectContentError(await failure(() => getCollection('study', { root })), 'ld-12b study');
    expect(issues.map(triple)).toEqual(['study/ collection missing']);
  });
});

describe('ld-13 본문 거부 규칙(T086-e) — 금지 구문은 빌드 실패 · 대조 구문은 통과', () => {
  const root = fixture('body-rules');
  const NEEDLES = [
    '<script', 'x()', '<iframe', '<callout', '<!--', '<br', 'import x', 'export const', '1 + 1', '{x}', '{t}', 'javascript',
    'alert(', 'text/html', 'vbscript', '&#', 'evil.invalid', 'ftp:', 'java script', `${BS}evil`, '<b>', '<i>', '{y}', '{z}',
  ];
  // 파일마다 위반 하나(021은 둘 · 023 · 027은 글줄 안 여는 · 닫는 태그 = html 노드 둘) · 파일 이름순 → 문서 순 · 099-control은 issues에 없다
  // 022–027 = 중첩 위치(목록 항목 · 인용 · 표 칸 · 헤딩 · 링크 글자 · 각주 정의 — 수정 r1 · B-4): 최상위 children(+ 문단 글줄)만 도는
  //   거부 플러그인이 통과하지 못하게 한다
  const body = (file: string, code: string, line: number): Issue => ({ file: `study/${file}`, field: 'body', code, line });
  const EXPECTED: Issue[] = [
    body('001-raw-script.mdx', 'raw-html', 13),
    body('002-raw-iframe.mdx', 'raw-html', 13),
    body('003-raw-component.mdx', 'raw-html', 13),
    body('004-raw-comment.mdx', 'raw-html', 13),
    body('005-esm-import.mdx', 'esm', 13),
    body('006-esm-export.mdx', 'esm', 13),
    body('007-expression.mdx', 'expression', 13),
    body('008-expression-alt.mdx', 'expression', 13),
    body('009-expression-title.mdx', 'expression', 13),
    body('010-url-js.mdx', 'unsafe-url', 13),
    body('011-url-autolink.mdx', 'unsafe-url', 13),
    body('012-image-data.mdx', 'unsafe-url', 13),
    body('013-definition.mdx', 'unsafe-url', 15),
    body('014-url-charref.mdx', 'unsafe-url', 13),
    body('015-url-scheme-relative.mdx', 'unsafe-url', 13),
    body('016-url-backslash.mdx', 'unsafe-url', 13),
    body('017-url-mixed-case.mdx', 'unsafe-url', 13),
    body('018-url-ftp.mdx', 'unsafe-url', 13),
    body('019-url-pointy-space.mdx', 'unsafe-url', 13),
    body('020-url-tab-charref.mdx', 'unsafe-url', 13),
    body('021-two-issues.mdx', 'raw-html', 13),
    body('021-two-issues.mdx', 'unsafe-url', 15),
    body('022-nested-list.mdx', 'unsafe-url', 14),
    body('023-nested-quote.mdx', 'raw-html', 13),
    body('023-nested-quote.mdx', 'raw-html', 13),
    body('024-nested-table.mdx', 'expression', 15),
    body('025-nested-heading.mdx', 'expression', 13),
    body('026-nested-link-text.mdx', 'expression', 13),
    body('027-nested-footnote.mdx', 'raw-html', 15),
    body('027-nested-footnote.mdx', 'raw-html', 15),
  ];

  it('ld-13 금지 사례 — issues가 정확히 같다(파일 Ordinal → 문서 순 · 중첩 위치 포함 · 대조 파일 없음) · 오류 객체에 입력 값 0', async () => {
    const issues = expectContentError(await failure(() => getCollection('study', { root })), 'ld-13', NEEDLES);
    expect(issues.map(quad), 'ld-13 issues').toEqual(EXPECTED.map(quad));
  });

  it('ld-13 대조 — 대조 파일만 둔 root는 항목을 돌려준다', async () => {
    const only = tempRoot();
    mkdirSync(join(only, 'study'));
    copyFileSync(join(root, 'study', '099-control.mdx'), join(only, 'study', '099-control.mdx'));
    expect(slugsOf(await getCollection('study', { root: only }), 'ld-13 대조'), 'ld-13 대조 slug').toEqual(['099-control']);
  });
});

describe('ld-14 프런트매터 · 인코딩(T086-e · N-3 · N-7)', () => {
  it('ld-14 ---js → fence · 중복 키 title → yaml · !!js/function → yaml(파일마다 프런트매터 issue 하나)', async () => {
    const NEEDLES = ['js/function', '첫 제목', '둘째 제목', '자바스크립트 울타리'];
    const thrown = await failure(() => getCollection('study', { root: fixture('frontmatter') }));
    const issues = expectContentError(thrown, 'ld-14', NEEDLES);
    expect(issues.map(triple), 'ld-14 issues').toEqual([
      'study/001-fence-js.mdx frontmatter fence',
      'study/002-duplicate-key.mdx frontmatter yaml',
      'study/003-js-tag.mdx frontmatter yaml',
    ]);
  });

  it('ld-14 (실행 중 생성) BOM + --- → fence · 깨진 UTF-8 → (file, file, encoding)', async () => {
    const root = tempRoot();
    const bom = Buffer.from([0xef, 0xbb, 0xbf]);
    put(root, 'study/001-bom.mdx', Buffer.concat([bom, Buffer.from(noteText('001-bom', '본문.'), 'utf8')]));
    const good = Buffer.from(noteText('002-bad-utf8', '본문.'), 'utf8');
    put(root, 'study/002-bad-utf8.mdx', Buffer.concat([good.subarray(0, 4), Buffer.from([0xff]), good.subarray(4)]));
    const issues = expectContentError(await failure(() => getCollection('study', { root })), 'ld-14 생성');
    expect(issues.map(triple), 'ld-14 생성 issues').toEqual([
      'study/001-bom.mdx frontmatter fence',
      'study/002-bad-utf8.mdx file encoding',
    ]);
  });
});
