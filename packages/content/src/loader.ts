// packages/content/src/loader.ts — T090: getCollection · ContentValidationError — 인자 · root 해석 · 스캔(not-regular · 이름)
//   · 파일 단위 검증 조율(mdx.ts parseFile · schema.ts validateFrontmatter) · 묶음 · 교차 파일 규칙 · issue 정렬 · 1회 스캔 메모
//   · draft 거름 · lang 고르기 · 정렬.
//
// 설계: specs/003-platform-foundation/design/t090-design.md D2 · D3 · D4 · D8 · D9(§6이 본문을 이긴다). API 정본: tests/loader.test.ts
//   머리 주석 :11–:49(T086).
// 파이프라인(D3): A 검증(모든 파일 — draft 포함 · 거름은 뒤) → issue가 하나라도 있으면 정렬해 ContentValidationError 하나로 던진다
//   (메모에 보관하지 않는다) → B 컴파일(issue 0일 때만) → 메모 → C 호출마다 draft 거름 · lang 고르기 · translations · 정렬 · structuredClone.
// 입력 값 0(D4): 오류 객체 · issues · message에는 file · field · code · line만 싣는다 — 원문 · 프런트매터 값 · 라이브러리 오류 0.
//   오류 생성자에는 메시지 하나만 넘긴다(cause 옵션 0). 프로그래머 오류(TypeError)의 메시지는 값 없는 상수다.
// 출력 0: 이 모듈은 표준 출력 · 오류 출력 · 프로세스 경고를 쓰지 않고, import만으로는 파일 시스템에 닿지 않는다.
// 예상 밖 fs 오류(EACCES 등)는 그대로 던진다(환경 오류 — 생성 스크립트가 이름만 싣는다 · §5-2 T091).

import type { Dirent } from 'node:fs';
import { readdir, readFile, stat } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { compile, LANGS, parseFile } from './mdx.ts';
import type { Heading, Lang, MdRoot } from './mdx.ts';
import { COLLECTIONS, CONTRACT_KEYS, validateFrontmatter } from './schema.ts';
import type { Collection, Frontmatter } from './schema.ts';

// ---------- 공개 형 ----------

/** issue 하나(머리 :30) — line은 body issue에만 있다(D4) */
export type ContentIssue = { readonly file: string; readonly field: string; readonly code: string; readonly line?: number };

/** 항목 하나(머리 :24–:25 + html — D2 · 〔90-6〕). 호출마다 새 객체다(structuredClone — 받는 쪽이 바꿔도 메모는 그대로) */
export type ContentItem = {
  collection: Collection;
  slug: string;
  lang: Lang;
  translations: Lang[];
  data: Frontmatter;
  readingTime: number;
  headings: Heading[];
  html: string;
};

/** getCollection 옵션(머리 :13) — 키의 명시 undefined는 그 키를 뺀 것과 같다(〔A-16〕) */
export type GetCollectionOptions = { readonly lang?: Lang; readonly includeDrafts?: boolean; readonly root?: string };

// ---------- 오류(D4) ----------

/** issue 줄 — `<file>[:<line>]: <field> (<code>)`(머리 :46) */
const formatIssue = (issue: ContentIssue): string =>
  `${issue.file}${issue.line === undefined ? '' : `:${issue.line}`}: ${issue.field} (${issue.code})`;

/** 키 file · field · code(+ body issue의 line)만 실은 얼린 사본 */
function frozenIssue(issue: ContentIssue): ContentIssue {
  const { file, field, code, line } = issue;
  return Object.freeze(line === undefined ? { file, field, code } : { file, field, code, line });
}

/**
 * 콘텐츠 검증 실패(머리 :29–:31 · :46–:49 · D4). 위반을 모아 하나로 던진다 — issues 순서 = file(Ordinal) → 문서 순.
 * 자기 속성 = issues · name(클래스 필드) + Error가 다는 message · stack. issues 배열과 각 issue는 얼려 있다.
 * message = issue 줄들을 '\n'으로 이은 것(머리말 · 요약 · 끝 줄바꿈 0).
 */
export class ContentValidationError extends Error {
  name = 'ContentValidationError';
  readonly issues: readonly ContentIssue[];

  constructor(issues: readonly ContentIssue[]) {
    const frozen = Object.freeze(issues.map(frozenIssue));
    super(frozen.map(formatIssue).join('\n'));
    this.issues = frozen;
  }
}

// ---------- 스캔(D8 스캔 · D9 이름 규칙) ----------

/** 후보 = 이름이 .mdx로 끝나는 항목 — 확장자는 대소문자 무관(〔A-1〕). 그 밖(.md · .txt · 확장자 없음)은 무시한다(머리 :21) */
const MDX_SUFFIX = /\.[Mm][Dd][Xx]$/;

/** issue file 칸에 쓸 수 있는 이름 글자(loader.test.ts:156 FILE_RE) — 밖이면 그 파일 대신 컬렉션 디렉터리를 짚는다(〔A-2〕) */
const FILE_NAME = /^[A-Za-z0-9._-]+$/;

/**
 * 컬렉션 이름 규칙(D9 — Ordinal · 소문자 .mdx). 1 = slug(언어 접미사 · 확장자 제외) · 2 = 언어 접미사(없으면 ko).
 * study = 머리 :22 · blog · projects = kebab(〔90-3〕 잠정 · data-model.md:244).
 */
const KEBAB = /^([a-z0-9]+(?:-[a-z0-9]+)*)(?:\.(en|ja))?\.mdx$/;
const NAME_RULES: Readonly<Record<Collection, RegExp>> = Object.freeze({
  study: /^([0-9]{3}-[a-z0-9-]+)(?:\.(en|ja))?\.mdx$/,
  blog: KEBAB,
  projects: KEBAB,
});

/** 같은 slug의 한 파일 — 이름 규칙을 지킨 정규 파일만 묶음에 든다 */
export type Member = { readonly slug: string; readonly lang: Lang };

/** 스캔 항목 분류(D8 스캔 2–5) */
export type EntryClass =
  | { readonly kind: 'ignored' }
  | { readonly kind: 'rejected'; readonly issue: ContentIssue }
  | { readonly kind: 'file'; readonly file: string; readonly name: string; readonly member: Member | null };

type FileEntry = Extract<EntryClass, { kind: 'file' }>;

const IGNORED: EntryClass = Object.freeze({ kind: 'ignored' });

/**
 * 스캔 항목 하나를 분류한다(D8 스캔 2–5) — 순수 함수: 이름과 isFile()만 보고, 따라가거나 읽지 않는다(C3).
 *   .mdx 아님(대소문자 무관)          → ignored
 *   FILE_RE 밖 이름                   → rejected (<컬렉션>/, file, name) — 그 항목 끝(〔A-2〕 · not-regular보다 먼저)
 *   정규 파일 아님(디렉터리 · 심볼릭 링크 · junction · 그 밖) → rejected (file, file, not-regular) — 그 항목 끝(〔A-1〕)
 *   그 밖                             → file — 컬렉션 이름 규칙을 어기면 member = null(→ name issue · 파일 단위 검증은 계속 · 묶음 밖 — C8)
 */
export function classifyEntry(collection: Collection, entry: { readonly name: string; isFile(): boolean }): EntryClass {
  const { name } = entry;
  if (!MDX_SUFFIX.test(name)) return IGNORED;
  if (!FILE_NAME.test(name)) return { kind: 'rejected', issue: { file: `${collection}/`, field: 'file', code: 'name' } };
  const file = `${collection}/${name}`;
  if (!entry.isFile()) return { kind: 'rejected', issue: { file, field: 'file', code: 'not-regular' } };
  const match = NAME_RULES[collection].exec(name);
  if (match === null) return { kind: 'file', file, name, member: null };
  return { kind: 'file', file, name, member: { slug: match[1] as string, lang: (match[2] ?? 'ko') as Lang } };
}

// ---------- 파일 단위 검증(D3 A-3) ----------

/** 파일 하나의 검증 결과 — issue는 범주마다 문서 순으로 모은다(D4 순서 2) */
type Checked = {
  readonly file: string;
  readonly member: Member | null;
  /** 파일 단위: name → encoding → ko-missing(D4 순서 2-1 — ko-missing은 교차 파일 규칙이 붙인다) */
  readonly fileIssues: ContentIssue[];
  /** 프런트매터 단위: fence · yaml(있으면 그 하나뿐) */
  readonly frontmatterIssue: ContentIssue | undefined;
  /** 필드: 최상위 키의 문서 순 · 없는 키는 뒤(validateFrontmatter 순서 — variant-mismatch도 같은 순서로 끼운다) */
  fieldIssues: ContentIssue[];
  /** 본문: 줄 → 열 → 규칙 순(mdx.ts parseFile이 정렬해 돌려준다) */
  readonly bodyIssues: ContentIssue[];
  /** 내용 단계(디코드 · 울타리 · YAML)를 통과했을 때만 있다 */
  readonly data: Record<string, unknown> | undefined;
  readonly tree: MdRoot | undefined;
};

async function checkFile(collection: Collection, dir: string, entry: FileEntry): Promise<Checked> {
  const { file, name, member } = entry;
  const fileIssues: ContentIssue[] = member === null ? [{ file, field: 'file', code: 'name' }] : [];
  const parsed = parseFile(await readFile(join(dir, name)));
  if (!parsed.ok) {
    // 디코드 · 울타리 · YAML이 실패한 파일에는 스키마 · 본문 규칙을 돌리지 않는다(내용 단계 issue 하나 — 머리 :45)
    if (parsed.field === 'file') fileIssues.push({ file, field: 'file', code: parsed.code });
    const frontmatterIssue = parsed.field === 'frontmatter' ? { file, field: 'frontmatter', code: parsed.code } : undefined;
    return { file, member, fileIssues, frontmatterIssue, fieldIssues: [], bodyIssues: [], data: undefined, tree: undefined };
  }
  return {
    file,
    member,
    fileIssues,
    frontmatterIssue: undefined,
    fieldIssues: validateFrontmatter(parsed.data, collection).map(({ field, code }) => ({ file, field, code })),
    bodyIssues: parsed.body.map(({ code, line }) => ({ file, field: 'body', code, line })),
    data: parsed.data,
    tree: parsed.tree,
  };
}

// ---------- 교차 파일 규칙(D9) ----------

/** 언어 변형이 ko 파일과 같아야 하는 키(머리 :22) */
const SHARED_KEYS: readonly string[] = ['pubDate', 'change'];

const hasFieldIssue = (record: Checked, key: string): boolean => record.fieldIssues.some((issue) => issue.field === key);

/**
 * 변형의 key가 ko 파일과 다른가 — 두 파일 모두 내용 단계를 통과하고 그 키에 issue가 없을 때만 비교한다(D9 · lx-8b).
 * 한쪽에만 키가 있으면 다르다(blog · projects의 선택 change — 〔A-17〕). 둘 다 없으면 같다.
 */
function differs(ko: Checked, variant: Checked, key: string): boolean {
  if (ko.data === undefined || variant.data === undefined) return false;
  if (hasFieldIssue(ko, key) || hasFieldIssue(variant, key)) return false;
  const inKo = Object.hasOwn(ko.data, key);
  if (inKo !== Object.hasOwn(variant.data, key)) return true;
  return inKo && ko.data[key] !== variant.data[key];
}

/**
 * 필드 issue를 최상위 키의 문서 순으로 다시 둔다 — 안정 정렬이라 같은 최상위 키 안의 순서는 그대로다. 없는 키는 그 뒤 계약 키 순
 * (schema.ts CONTRACT_KEYS — validateFrontmatter와 같은 목록 하나 · 설계 정정 노트 4)
 */
function byDocumentKey(issues: readonly ContentIssue[], data: Record<string, unknown> | undefined): ContentIssue[] {
  const keys = data === undefined ? [] : Object.keys(data);
  const rank = (field: string): number => {
    const top = field.split('.', 1)[0] ?? field;
    const at = keys.indexOf(top);
    if (at >= 0) return at;
    const contract = CONTRACT_KEYS.indexOf(top);
    return keys.length + (contract >= 0 ? contract : CONTRACT_KEYS.length);
  };
  return issues
    .map((issue, index) => ({ issue, index, rank: rank(issue.field) }))
    .sort((left, right) => left.rank - right.rank || left.index - right.index)
    .map(({ issue }) => issue);
}

/**
 * 묶음(slug) · 교차 파일 규칙(D9): ko 파일이 없는 slug는 변형 파일마다 (변형, file, ko-missing) — ko 이름의 항목이 정규 파일이
 * 아니거나 이름 규칙을 어겼으면 묶음 밖이라 ko가 없는 것이다. 변형의 pubDate · change가 ko와 다르면 (변형, 그 키, variant-mismatch).
 */
function applyCrossFileRules(checked: readonly Checked[]): void {
  const groups = new Map<string, Checked[]>();
  for (const record of checked) {
    if (record.member === null) continue;
    const group = groups.get(record.member.slug);
    if (group === undefined) groups.set(record.member.slug, [record]);
    else group.push(record);
  }
  for (const group of groups.values()) {
    const ko = group.find((record) => record.member?.lang === 'ko');
    for (const variant of group) {
      if (variant === ko) continue;
      if (ko === undefined) {
        variant.fileIssues.push({ file: variant.file, field: 'file', code: 'ko-missing' });
        continue;
      }
      const mismatched = SHARED_KEYS.filter((key) => differs(ko, variant, key));
      if (mismatched.length === 0) continue;
      const added = mismatched.map((key) => ({ file: variant.file, field: key, code: 'variant-mismatch' }));
      variant.fieldIssues = byDocumentKey([...variant.fieldIssues, ...added], variant.data);
    }
  }
}

// ---------- issue 정렬(D4 순서) ----------

/** Ordinal(UTF-16 코드 단위) 비교 — localeCompare · Intl.Collator는 쓰지 않는다(D4 순서 1 · mu-7) */
const ordinal = (left: string, right: string): number => (left < right ? -1 : left > right ? 1 : 0);

/** file(Ordinal) → 같은 파일 안 문서 순(파일 단위 → 프런트매터 단위 → 필드 → 본문) — 그 항목의 유일한 issue(rejected)는 홀로 */
function collectIssues(rejected: readonly ContentIssue[], checked: readonly Checked[]): ContentIssue[] {
  const groups = rejected.map((issue) => ({ file: issue.file, issues: [issue] }));
  for (const record of checked) {
    const frontmatter = record.frontmatterIssue === undefined ? [] : [record.frontmatterIssue];
    const issues = [...record.fileIssues, ...frontmatter, ...record.fieldIssues, ...record.bodyIssues];
    if (issues.length > 0) groups.push({ file: record.file, issues });
  }
  return groups.sort((left, right) => ordinal(left.file, right.file)).flatMap((group) => group.issues);
}

// ---------- 컬렉션 하나 스캔 · 검증 · 컴파일(D3 A–B) ----------

/** 메모 항목(모든 lang · draft 포함) */
type Entry = { readonly slug: string; readonly lang: Lang; readonly draft: boolean; readonly item: ContentItem };

const isMissing = (error: unknown): boolean => {
  const code = typeof error === 'object' && error !== null ? (error as { code?: unknown }).code : undefined;
  return code === 'ENOENT' || code === 'ENOTDIR';
};

/** root가 디렉터리인가(링크는 따라간다 — 〔B-14〕) — 없거나 디렉터리가 아니면 false · 그 밖 fs 오류는 던진다 */
async function isDirectory(path: string): Promise<boolean> {
  try {
    return (await stat(path)).isDirectory();
  } catch (error) {
    if (isMissing(error)) return false;
    throw error;
  }
}

async function compileAll(collection: Collection, checked: readonly Checked[]): Promise<Entry[]> {
  const entries: Entry[] = [];
  for (const { member, data, tree } of checked) {
    // issue 0이면 모든 파일이 이름 규칙을 지키고 내용 단계를 통과했다(아니면 name · encoding · fence · yaml issue가 났다)
    if (member === null || data === undefined || tree === undefined) throw new Error('getCollection: internal invariant');
    const compiled = await compile(tree, member.lang);
    const item: ContentItem = {
      collection,
      slug: member.slug,
      lang: member.lang,
      translations: [],
      data: data as Frontmatter,
      readingTime: compiled.readingTime,
      headings: compiled.headings,
      html: compiled.html,
    };
    entries.push({ slug: member.slug, lang: member.lang, draft: data.draft === true, item });
  }
  return entries;
}

/**
 * D3 A–B: 존재 확인 → 스캔(이름 Ordinal · 비재귀) → 파일마다 검증 → 교차 파일 규칙 → issue가 있으면 던진다 → 없을 때만 컴파일.
 * root가 없거나 디렉터리가 아니면 (., root, missing) · 컬렉션 디렉터리가 없으면 study는 (study/, collection, missing) · blog · projects는 [].
 */
async function scanCollection(root: string, collection: Collection): Promise<Entry[]> {
  if (!(await isDirectory(root))) throw new ContentValidationError([{ file: '.', field: 'root', code: 'missing' }]);
  const dir = join(root, collection);
  let dirents: Dirent[];
  try {
    dirents = await readdir(dir, { withFileTypes: true });
  } catch (error) {
    if (!isMissing(error)) throw error;
    if (collection === 'study') throw new ContentValidationError([{ file: `${collection}/`, field: 'collection', code: 'missing' }]);
    return [];
  }
  dirents.sort((left, right) => ordinal(left.name, right.name));
  const rejected: ContentIssue[] = [];
  const checked: Checked[] = [];
  for (const dirent of dirents) {
    const entry = classifyEntry(collection, dirent);
    if (entry.kind === 'rejected') rejected.push(entry.issue);
    else if (entry.kind === 'file') checked.push(await checkFile(collection, dir, entry));
  }
  applyCrossFileRules(checked);
  const issues = collectIssues(rejected, checked);
  if (issues.length > 0) throw new ContentValidationError(issues);
  return compileAll(collection, checked);
}

// ---------- 1회 스캔 메모(D8 — 〔90-1〕) ----------

// tasks.md T090 『React.cache 1회』 = 이 모듈 메모(〔90-1〕)
//   키 = (해석된 절대 root, 컬렉션) · 값 = 검증 · 컴파일을 마친 항목(모든 lang · draft 포함)의 Promise — 생성 프로세스에서 컬렉션마다
//   스캔 1회(react 의존 0 — 사용자 결정 2026-11-27). 같은 키의 동시 호출은 Promise를 함께 쓰고, 거부되면(검증 실패 · 부재 · fs 오류)
//   그 Promise일 때만 지운다 — 거부는 보관하지 않는다. 무효화는 없다(원샷 생성 프로세스 · watch는 나중).
const SCANS = new Map<string, Promise<readonly Entry[]>>();

function scanOnce(root: string, collection: Collection): Promise<readonly Entry[]> {
  const key = JSON.stringify([root, collection]);
  const cached = SCANS.get(key);
  if (cached !== undefined) return cached;
  const scan = scanCollection(root, collection);
  SCANS.set(key, scan);
  scan.catch(() => {
    if (SCANS.get(key) === scan) SCANS.delete(key);
  });
  return scan;
}

// ---------- 호출마다(D9 C) ----------

/**
 * draft 거름(파일 단위 — ko가 걸러지면 slug 전체 제외 · 〔90-9〕) → lang 고르기(요청 lang 변형이 남아 있으면 그것, 아니면 ko)
 * → translations(같은 slug에서 남은 다른 lang · Ordinal) → 정렬(pubDate 내림차순 → slug 오름차순 · Ordinal) → structuredClone.
 */
function select(entries: readonly Entry[], lang: Lang, includeDrafts: boolean): ContentItem[] {
  const bySlug = new Map<string, Map<Lang, Entry>>();
  for (const entry of entries) {
    if (entry.draft && !includeDrafts) continue;
    const langs = bySlug.get(entry.slug) ?? new Map<Lang, Entry>();
    langs.set(entry.lang, entry);
    bySlug.set(entry.slug, langs);
  }
  const items: ContentItem[] = [];
  for (const langs of bySlug.values()) {
    const ko = langs.get('ko');
    if (ko === undefined) continue; // 원본 없이 번역만 공개되지 않게 한다
    const chosen = langs.get(lang) ?? ko;
    const translations = [...langs.keys()].filter((other) => other !== chosen.lang).sort(ordinal);
    items.push({ ...chosen.item, translations });
  }
  items.sort((left, right) => ordinal(right.data.pubDate, left.data.pubDate) || ordinal(left.slug, right.slug));
  return structuredClone(items);
}

// ---------- 인자 · root(D8) ----------

/** 기본 root = 저장소 content/(패키지 위치 기준 · cwd 무관). 경로 계산만 한다(import 때 파일 접근 0) */
const DEFAULT_ROOT = resolve(fileURLToPath(new URL('../../../content/', import.meta.url)));

const isCollection = (value: unknown): value is Collection => typeof value === 'string' && (COLLECTIONS as readonly string[]).includes(value);
const isLang = (value: unknown): value is Lang => typeof value === 'string' && (LANGS as readonly string[]).includes(value);

/** N-1: 기본값은 닫힌 쪽 — 호출 시점의 NODE_ENV가 정확히 development · test일 때만 draft를 포함한다 */
function draftsByDefault(): boolean {
  const mode = process.env.NODE_ENV;
  return mode === 'development' || mode === 'test';
}

/** root 우선순위(정정 노트 35): opts.root > env JT_CONTENT_ROOT(호출 시점 · 키가 있을 때) > 기본. 상대 경로 = 호출 시점 cwd 기준 */
function resolveRoot(root: unknown): string {
  if (root !== undefined) {
    if (typeof root !== 'string' || root === '') throw new TypeError('getCollection: root must be a non-empty string');
    return resolve(root);
  }
  const fromEnv = process.env.JT_CONTENT_ROOT;
  if (fromEnv === undefined) return DEFAULT_ROOT;
  // 빈 값은 기본(실제 노트)으로 조용히 넘어가지 않는다(〔90-5〕)
  if (fromEnv === '') throw new TypeError('getCollection: JT_CONTENT_ROOT must not be empty');
  return resolve(fromEnv);
}

type Arguments = { readonly collection: Collection; readonly root: string; readonly lang: Lang; readonly includeDrafts: boolean };

/** 인자 검사(〔90-5〕 · 〔A-16〕): 모르는 컬렉션 · 객체가 아닌 opts(null · 배열 포함) · 모르는 lang · 불리언 아닌 includeDrafts · 문자열 아닌 · 빈 root → TypeError */
function readArguments(name: unknown, opts: unknown): Arguments {
  if (!isCollection(name)) throw new TypeError('getCollection: unknown collection');
  if (opts !== undefined && (typeof opts !== 'object' || opts === null || Array.isArray(opts))) {
    throw new TypeError('getCollection: options must be an object');
  }
  const { lang = 'ko', includeDrafts = draftsByDefault(), root } = (opts ?? {}) as { lang?: unknown; includeDrafts?: unknown; root?: unknown };
  if (!isLang(lang)) throw new TypeError('getCollection: unknown lang');
  if (typeof includeDrafts !== 'boolean') throw new TypeError('getCollection: includeDrafts must be a boolean');
  return { collection: name, root: resolveRoot(root), lang, includeDrafts };
}

/**
 * 컬렉션 항목을 돌려준다(머리 :12–:23). 모든 파일을 검증한 뒤 draft를 거르고, 위반이 있으면 모아 ContentValidationError 하나로 던진다.
 * 같은 (root, 컬렉션)은 프로세스에서 한 번만 스캔 · 컴파일한다(메모 — 거름 · lang · 정렬은 호출마다).
 */
export async function getCollection(name: Collection, opts?: GetCollectionOptions): Promise<ContentItem[]> {
  const { collection, root, lang, includeDrafts } = readArguments(name, opts);
  return select(await scanOnce(root, collection), lang, includeDrafts);
}
