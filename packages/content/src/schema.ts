// packages/content/src/schema.ts — T090: 프런트매터 스키마(zod — 코드 정본) · zod 밖 규칙 · issue 매핑 · JSON Schema 내보내기 + CLI.
//
// 정본 사슬: .claude/rules/content.md(사람 계약) → 이 파일의 zod 스키마(코드 정본 — FR-029 · data-model §11)
//   → schemas/study.schema.json(파생 사본 — pnpm --filter @jt/content --fail-if-no-match schema).
// 설계: specs/003-platform-foundation/design/t090-design.md D4 · D5 · D10(§6이 본문을 이긴다 — §6-2 url format 되살림 · §6-4).
// 입력 값 0(D4): issue에는 field · code만 싣는다. zod issue 객체(원 값이 실린다)는 경로 · code 매핑에만 쓰고 싣지 않는다.
// 패턴 규율(D5 · events.md:28): 명시 문자 클래스만 · 클래스 밖 맨 '.' 0 · 끝 앵커는 $(?!\n) · JSON Schema로 나가는 문자열은 ASCII뿐
//   — U+ 범위는 날 글자 대신 BS + 'u' + 16진 넷으로 조립한다(D15). JSON Schema에 나가지 않는 판정(url 원 문자열)은 코드 단위 비교다.

import { Buffer } from 'node:buffer';
import { mkdirSync, realpathSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { z } from 'zod';

/** 컬렉션 이름(머리 :12) — change 필수 여부가 갈린다(study 필수 · blog · projects 선택 — 〔90-3〕) */
export const COLLECTIONS = ['study', 'blog', 'projects'] as const;
export type Collection = (typeof COLLECTIONS)[number];

const BS = String.fromCharCode(92); // 역슬래시(소스에 이스케이프를 두지 않는다 — loader.test.ts:78 선례)

/** ECMAScript 공백 집합(WhiteSpace + LineTerminator — 정규식 \s와 같다)의 코드 단위 구간 — NONBLANK · url 원 문자열이 함께 쓴다 */
const WHITESPACE_RANGES: ReadonlyArray<readonly [number, number]> = [
  [0x0009, 0x000d],
  [0x0020, 0x0020],
  [0x00a0, 0x00a0],
  [0x1680, 0x1680],
  [0x2000, 0x200a],
  [0x2028, 0x2029],
  [0x202f, 0x202f],
  [0x205f, 0x205f],
  [0x3000, 0x3000],
  [0xfeff, 0xfeff],
];

/** 코드 단위 → ASCII 이스케이프(역슬래시 + u + 16진 넷) */
const escapeUnit = (code: number): string => `${BS}u${code.toString(16).padStart(4, '0')}`;

/** 공백 아닌 글자가 하나 이상 있다(앵커 없는 검색) — 부정 문자 클래스 하나 · ASCII 이스케이프만 */
const NONBLANK = new RegExp(
  `[^${WHITESPACE_RANGES.map(([low, high]) => (low === high ? escapeUnit(low) : `${escapeUnit(low)}-${escapeUnit(high)}`)).join('')}]`,
);

/** change = 기능 디렉터리 이름(content.md:21 · data-model.md:244) */
const CHANGE = /^[0-9]{3}-[a-z0-9-]+$(?!\n)/;

/** sources[].path = 저장소 상대 경로 · '.' · '..' 세그먼트 0 · ':' 0(N-13) — 세그먼트에 룩어라운드가 없다(JSON Schema로 같은 판정) */
const SEGMENT = String.raw`(?:[A-Za-z0-9_-][A-Za-z0-9._-]*|\.[A-Za-z0-9_-][A-Za-z0-9._-]*|\.\.[A-Za-z0-9._-]+)`;
const PATH = new RegExp(String.raw`^${SEGMENT}(?:/${SEGMENT})*$(?!\n)`);

/** sources[].url 접두 — httpUrl만이면 JSON Schema에 format: uri로만 나가 javascript:가 통과한다(D5) */
const HTTP_PREFIX = /^[Hh][Tt][Tt][Pp][Ss]?:\/\//;

const nonBlank = () => z.string().min(1).regex(NONBLANK);

// zod 4.6.7은 .regex()가 붙으면 내보낸 JSON Schema에서 url의 format을 지운다(v4/core/json-schema-processors.js — regex 검사의
// format이 마지막에 이겨 빈 format으로 지워진다). .meta로 format: 'uri'를 다시 싣는다(§6-2) — zod 런타임 판정은 바뀌지 않는다.
// host = 점이 있는 도메인 이름 꼴(설계 정정 노트 6 · 컨트롤러 결정 K-6 — httpUrl의 hostname 검사 · 런타임 전용 — 〔V-A-5〕). 실제 판정은
//   zod domain 꼴뿐이다(점이 있는 이름 + 영문 최상위 라벨): localhost · IP 주소(정수 · 16진 표기 · IPv6 포함) · 단일 라벨 · 끝 점 FQDN
//   · xn-- TLD는 거부하지만 *.localhost · *.local · *.internal · *.home.arpa · *.svc.cluster.local 같은 내부 이름은 통과한다
//   (리뷰 B RB-1 실측 — 꼴만 보는 검사라 내부 이름은 저자가 뺀다(content.md) · 특수 용도 TLD 거부 목록은 새 계약 규칙이라 미룸 — 〔90-11〕).
const sourceUrl = () => z.httpUrl().regex(HTTP_PREFIX).meta({ format: 'uri' });

// sources 원소는 strict 객체 하나 + zod 밖 규칙(path · url 정확히 하나 — D5). union으로 짜면 source-kind · title 없음 · 원소가 객체 아님이
// invalid로 바뀐다(zod 4.6.7 handleUnionResults는 중단되지 않은 갈래가 하나면 그 갈래의 issue를 그대로 내므로 url 꼴 오류는
// sources.<i>.url에 남는다 — 설계 정정 노트 2 · 변이 mu-15 실측).
const source = () =>
  z.strictObject({
    title: nonBlank(),
    path: z.string().regex(PATH).optional(),
    url: sourceUrl().optional(),
  });

/** content.md:11–:25 계약 키 순(change · sources 앞까지) — 이 삽입 순이 CONTRACT_KEYS의 근원이다(sx-9가 계약 순으로 고정한다) */
const sharedShape = () => ({
  title: nonBlank(),
  description: nonBlank(),
  pubDate: z.iso.date(),
  updatedDate: z.iso.date().optional(),
  tags: z.array(nonBlank()),
  series: nonBlank().optional(),
  seriesOrder: z.int().positive().optional(),
  draft: z.boolean(),
});

/** study 프런트매터 필드 — JSON Schema 내보내기의 원본(교차 규칙은 처음부터 이 객체 밖이다 — D10) */
const studyFields = z.strictObject({ ...sharedShape(), change: z.string().regex(CHANGE), sources: z.array(source()) });

/** blog · projects 프런트매터 필드 — change 선택(〔90-3〕 잠정) */
const entryFields = z.strictObject({ ...sharedShape(), change: z.string().regex(CHANGE).optional(), sources: z.array(source()) });

/** 검증을 통과한 프런트매터(모든 컬렉션 — study는 change가 늘 있다) · 날짜는 'YYYY-MM-DD' 문자열(머리 :26) */
export type Frontmatter = z.output<typeof entryFields>;

/** field가 프런트매터 키일 때의 code 어휘(D4 표 — variant-mismatch는 교차 파일 규칙이라 로더가 낸다) */
export type FieldCode =
  | 'missing'
  | 'type'
  | 'empty'
  | 'format'
  | 'range'
  | 'unknown-key'
  | 'series-pair'
  | 'date-order'
  | 'source-kind'
  | 'invalid';

export type FieldIssue = { readonly field: string; readonly code: FieldCode };

/** D4 표의 행 순 — 한 경로에 zod issue가 여럿이면 가장 위 행 하나를 남긴다 */
const CODE_RANK: Readonly<Record<FieldCode, number>> = {
  missing: 0,
  type: 1,
  empty: 2,
  format: 3,
  range: 4,
  'unknown-key': 5,
  'series-pair': 6,
  'date-order': 7,
  'source-kind': 8,
  invalid: 9,
};

/**
 * content.md 계약 키 순(title … sources) — 없는 키의 issue를 둘 순서(D4 순서 3). 하나뿐인 목록이다(설계 정정 노트 4): study 필드 객체의
 * zod shape 키 순(삽입 순 — sharedShape → change → sources)에서 얻어 얼린다. loader.ts가 import한다(index.ts에는 싣지 않는다).
 */
export const CONTRACT_KEYS: readonly string[] = Object.freeze(Object.keys(studyFields.shape));

/** sources 원소의 없는 키를 둘 순서 — 원소 객체의 zod shape 키 순(같은 원칙 · 복제 0) */
const SOURCE_KEYS: readonly string[] = Object.freeze(Object.keys(source().shape));

type Segment = string | number;
type Path = readonly Segment[];
type Candidate = { readonly path: Path; readonly code: FieldCode };

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const childOf = (node: unknown, segment: Segment): unknown =>
  typeof node === 'object' && node !== null ? (node as Record<Segment, unknown>)[segment] : undefined;

/** 원본 객체에 그 경로의 키가 있는가(자기 속성만 — 프로토타입 키를 키로 치지 않는다) */
function presentAt(data: unknown, path: Path): boolean {
  let node: unknown = data;
  for (const segment of path) {
    if (typeof node !== 'object' || node === null || !Object.hasOwn(node, segment)) return false;
    node = childOf(node, segment);
  }
  return true;
}

/** 빈 값 · 공백만이 empty인 필드(D4 표): title · description · series · tags[i] · sources[i].title */
function isNonBlankField(path: Path): boolean {
  if (path.length === 1) return path[0] === 'title' || path[0] === 'description' || path[0] === 'series';
  if (path.length === 2) return path[0] === 'tags' && typeof path[1] === 'number';
  return path.length === 3 && path[0] === 'sources' && typeof path[1] === 'number' && path[2] === 'title';
}

/** 꼴이 format인 필드(D4 표): 날짜 · change · sources[i].path · sources[i].url */
function isFormatField(path: Path): boolean {
  if (path.length === 1) return path[0] === 'pubDate' || path[0] === 'updatedDate' || path[0] === 'change';
  return path.length === 3 && path[0] === 'sources' && typeof path[1] === 'number' && (path[2] === 'path' || path[2] === 'url');
}

/** zod issue 하나 → (경로, code) — 객체의 그 밖 칸(원 값 · 메시지)은 읽지 않는다 */
function zodCandidates(issue: z.core.$ZodIssue, data: Record<string, unknown>): Candidate[] {
  const path: Segment[] = issue.path.filter((segment): segment is Segment => typeof segment === 'string' || typeof segment === 'number');
  switch (issue.code) {
    case 'unrecognized_keys':
      return issue.keys.map((key) => ({ path: [...path, key], code: 'unknown-key' }));
    case 'invalid_type':
      return [{ path, code: presentAt(data, path) ? 'type' : 'missing' }];
    case 'too_small':
    case 'too_big':
      if (issue.origin === 'number' || issue.origin === 'int') return [{ path, code: 'range' }];
      return [{ path, code: issue.code === 'too_small' && issue.origin === 'string' && isNonBlankField(path) ? 'empty' : 'invalid' }];
    case 'invalid_format':
      if (isNonBlankField(path)) return [{ path, code: 'empty' }];
      return [{ path, code: isFormatField(path) ? 'format' : 'invalid' }];
    default:
      return [{ path, code: 'invalid' }];
  }
}

const isWhitespaceUnit = (code: number): boolean => WHITESPACE_RANGES.some(([low, high]) => code >= low && code <= high);

/**
 * url 원 문자열 규칙(D5 〔B-4〕 · D6 unsafe-url 1단계와 같은 집합): 공백(NONBLANK가 빼는 집합) · C0 제어(U+0000–U+001F) · DEL(U+007F)
 * · C1(U+0080–U+009F) · 역슬래시가 하나라도 있다. zod는 값을 trim하고 탭 · 줄바꿈을 지운 뒤 판정하므로 원 값으로 따로 본다.
 */
export function hasUnsafeUrlChar(value: string): boolean {
  for (let index = 0; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code <= 0x1f || (code >= 0x7f && code <= 0x9f) || code === 0x5c || isWhitespaceUnit(code)) return true;
  }
  return false;
}

const SCHEME = /^([A-Za-z][A-Za-z0-9+.-]*):/;

/**
 * http(s) URL의 userinfo(D5 〔B-5〕 · D6 4단계): authority(스킴 ':' 뒤의 '/'를 모두 건너뛴 자리부터 첫 '/' · '?' · '#' 앞까지)에
 * '@'가 있다. path · query · fragment의 '@'는 authority 밖이라 해당하지 않는다. http · https 밖의 스킴은 해당하지 않는다.
 */
export function hasHttpUserinfo(value: string): boolean {
  const scheme = SCHEME.exec(value);
  if (scheme === null) return false;
  const name = (scheme[1] ?? '').toLowerCase();
  if (name !== 'http' && name !== 'https') return false;
  let index = scheme[0].length;
  while (index < value.length && value.charCodeAt(index) === 0x2f) index += 1;
  for (; index < value.length; index += 1) {
    const code = value.charCodeAt(index);
    if (code === 0x2f || code === 0x3f || code === 0x23) return false;
    if (code === 0x40) return true;
  }
  return false;
}

/** zod 밖 규칙(D5 — JSON Schema에 없다): series 짝 · 날짜 순서 · sources 정확히 하나 · url 원 문자열 · url userinfo */
function outsideCandidates(data: Record<string, unknown>, zodFields: ReadonlySet<string>): Candidate[] {
  const out: Candidate[] = [];
  const hasSeries = Object.hasOwn(data, 'series');
  const hasOrder = Object.hasOwn(data, 'seriesOrder');
  if (hasSeries && !hasOrder) out.push({ path: ['seriesOrder'], code: 'series-pair' });
  if (!hasSeries && hasOrder) out.push({ path: ['series'], code: 'series-pair' });
  // 날짜 순서 — 두 값 모두 꼴이 맞을 때만 · ISO 꼴이라 문자열(코드 단위) 비교 = 날짜 순
  const pubDate = Object.hasOwn(data, 'pubDate') ? data.pubDate : undefined;
  const updatedDate = Object.hasOwn(data, 'updatedDate') ? data.updatedDate : undefined;
  if (
    typeof pubDate === 'string' &&
    typeof updatedDate === 'string' &&
    !zodFields.has('pubDate') &&
    !zodFields.has('updatedDate') &&
    updatedDate < pubDate
  ) {
    out.push({ path: ['updatedDate'], code: 'date-order' });
  }
  const sources = Object.hasOwn(data, 'sources') ? data.sources : undefined;
  if (Array.isArray(sources)) {
    sources.forEach((element: unknown, index: number) => {
      if (!isRecord(element)) return;
      const hasPath = Object.hasOwn(element, 'path');
      const hasUrl = Object.hasOwn(element, 'url');
      if (hasPath === hasUrl) out.push({ path: ['sources', index], code: 'source-kind' });
      const url = hasUrl ? element.url : undefined;
      if (typeof url === 'string' && (hasUnsafeUrlChar(url) || hasHttpUserinfo(url))) {
        out.push({ path: ['sources', index, 'url'], code: 'format' });
      }
    });
  }
  return out;
}

/** 한 단계의 순위: 첨자는 수 · 있는 키는 문서 순(키 삽입 순) · 없는 키는 그 뒤에 계약 키 순 */
function segmentRank(segment: Segment, node: unknown, prefix: Path): number {
  if (typeof segment === 'number') return segment;
  const present = isRecord(node) ? Object.keys(node) : [];
  const at = present.indexOf(segment);
  if (at >= 0) return at;
  const order = prefix.length === 0 ? CONTRACT_KEYS : prefix.length === 2 && prefix[0] === 'sources' ? SOURCE_KEYS : [];
  const contractAt = order.indexOf(segment);
  return present.length + (contractAt >= 0 ? contractAt : order.length);
}

/** D4 순서 3: 최상위 키 문서 순 → 없는 키는 뒤(계약 키 순) → 같은 키 안은 경로 순(첨자 수 비교 · 하위 키 문서 순 · 부모가 먼저) */
function comparePaths(a: Path, b: Path, data: Record<string, unknown>): number {
  let node: unknown = data;
  for (let depth = 0; depth < a.length && depth < b.length; depth += 1) {
    const left = a[depth] as Segment;
    const right = b[depth] as Segment;
    if (left !== right) {
      const prefix = a.slice(0, depth);
      return segmentRank(left, node, prefix) - segmentRank(right, node, prefix);
    }
    node = childOf(node, left);
  }
  return a.length - b.length;
}

/**
 * 프런트매터 하나를 검증한다(zod + zod 밖 규칙). 위반이 없으면 [].
 * - 한 경로(field)에 issue 하나: zod issue가 여럿이면 D4 표의 가장 위 행 · zod 밖 규칙은 그 경로에 zod issue가 없을 때만.
 * - 순서: D4 순서 3(문서 키 순 · 없는 키는 뒤 · 첨자 수 비교) — 로더는 파일 안 프런트매터 필드 issue를 이 순서 그대로 둔다.
 * - data는 YAML 판독(mdx.ts — 최상위 매핑 · 키 꼴 검사 뒤)의 객체다. 매핑이 아니거나 모르는 컬렉션이면 TypeError(값 없는 메시지).
 */
export function validateFrontmatter(data: unknown, collection: Collection): FieldIssue[] {
  if (!isRecord(data)) throw new TypeError('validateFrontmatter: data must be a mapping');
  if (!(COLLECTIONS as readonly string[]).includes(collection)) throw new TypeError('validateFrontmatter: unknown collection');
  const kept = new Map<string, Candidate>();
  const parsed = (collection === 'study' ? studyFields : entryFields).safeParse(data);
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      for (const candidate of zodCandidates(issue, data)) {
        const field = candidate.path.join('.');
        const previous = kept.get(field);
        if (previous === undefined || CODE_RANK[candidate.code] < CODE_RANK[previous.code]) kept.set(field, candidate);
      }
    }
  }
  const zodFields: ReadonlySet<string> = new Set(kept.keys());
  for (const candidate of outsideCandidates(data, zodFields)) {
    const field = candidate.path.join('.');
    if (!kept.has(field)) kept.set(field, candidate);
  }
  return [...kept.values()]
    .sort((left, right) => comparePaths(left.path, right.path, data))
    .map(({ path, code }) => ({ field: path.join('.'), code }));
}

// ---------- JSON Schema 내보내기(D10 — 정본이 아니다: 파생 사본) ----------

/** $id = events 꼴(packages/events/schemas/_envelope.json:3) */
const SCHEMA_ID = 'https://joshuatech.dev/content/study/frontmatter/v1';
const SCHEMA_TITLE = 'study 노트 프런트매터';
const SCHEMA_DESCRIPTION = [
  'content/study/*.mdx 프런트매터의 파생 사본이다. 정본은 packages/content/src/schema.ts(zod)이고,',
  '이 파일은 pnpm --filter @jt/content --fail-if-no-match schema가 만든다 — 손으로 고치지 않는다.',
  'pattern은 ECMA-262(u) 정규식이다 — Python 등 다른 소비자는 뜻이 같은지 다시 확인한다(zod가 정하는 날짜 pattern에는',
  '숫자 축약 클래스와 끝 앵커 $가 남는다).',
  'zod 밖 규칙(series · seriesOrder 짝 · updatedDate ≥ pubDate · sources 원소의 path · url 정확히 하나',
  '· url 원 문자열(공백 · 제어 문자 · 역슬래시 0) · url userinfo 0 · 언어 변형의 pubDate · change 일치 · 파일 이름',
  '· ko 파일 필수 · 본문 규칙)과 url host 규칙(점이 있는 도메인 이름 꼴 — zod domain · 런타임 전용)은 이 스키마에 없다',
  '— 이 스키마 통과 ≠ 로더 통과.',
].join(' ');

/** study 필드 객체의 JSON Schema(draft 2020-12 · io input) — 머리 키 순서 $schema · $id · title · description */
export function studyJsonSchema(): Record<string, unknown> {
  const { $schema, ...rest } = z.toJSONSchema(studyFields, { target: 'draft-2020-12', io: 'input' }) as Record<string, unknown>;
  return { $schema, $id: SCHEMA_ID, title: SCHEMA_TITLE, description: SCHEMA_DESCRIPTION, ...rest };
}

/** 커밋 파일 schemas/study.schema.json의 바이트(LF · 끝 줄바꿈 하나 — .gitattributes *.json eol=lf) */
export function renderStudySchema(): string {
  return `${JSON.stringify(studyJsonSchema(), null, 2)}\n`;
}

// ---------- CLI: node src/schema.ts [--out <dir>] ----------

const PROG = 'content-schema';

/** 산출물 파일 이름 — 출력 줄에는 이 이름만 싣는다(--out이어도 경로 0 — 〔A-14〕 · 〔B-18〕) */
const SCHEMA_FILE = 'study.schema.json';

const DEFAULT_OUT_DIR = fileURLToPath(new URL('../schemas/', import.meta.url));

type CliResult = { readonly exitCode: number; readonly out: string; readonly err: string };

/** 임시 파일에 쓴 뒤 rename(원자적 교체) — 실패하면 임시 파일을 지우고 다시 던진다 */
function writeAtomically(dir: string, name: string, text: string): void {
  mkdirSync(dir, { recursive: true });
  const temp = join(dir, `.${name}.${process.pid}.tmp`);
  try {
    writeFileSync(temp, text, 'utf8');
    renameSync(temp, join(dir, name));
  } catch (error) {
    rmSync(temp, { force: true });
    throw error;
  }
}

/** 인자 → 결과(쓰기 포함). 인자 오류 · 쓰기 실패는 exit 2와 값 없는 한 줄 — 오류 객체의 메시지 · 경로는 싣지 않는다 */
function runCli(argv: readonly string[]): CliResult {
  let outDir = DEFAULT_OUT_DIR;
  if (argv.length === 2 && argv[0] === '--out' && argv[1] !== '') outDir = resolve(argv[1] as string);
  else if (argv.length !== 0) return { exitCode: 2, out: '', err: `${PROG}: error usage\n` };
  const text = renderStudySchema();
  try {
    writeAtomically(outDir, SCHEMA_FILE, text);
  } catch {
    return { exitCode: 2, out: '', err: `${PROG}: error write\n` };
  }
  return { exitCode: 0, out: `${PROG} wrote=${SCHEMA_FILE} bytes=${Buffer.byteLength(text, 'utf8')}\n`, err: '' };
}

/**
 * 직접 실행됐는가 — import.meta.main(Node 22.18 · 24.2+)이 불리언이면 그 값, 없으면 argv[1]과 이 파일의 실경로를 비교한다
 * (가드가 꺼져 조용히 통과하지 않게 — packages/events/scripts/check-compat.mjs:565–:575 선례 · engines >=24는 24.0 · 24.1도 받는다).
 * import만으로는 돌지 않는다(vitest 안 import에서도 false).
 */
function isEntryPoint(): boolean {
  const main = (import.meta as ImportMeta & { main?: unknown }).main;
  if (typeof main === 'boolean') return main;
  const entry = process.argv[1];
  if (entry === undefined) return false;
  try {
    return realpathSync(entry) === realpathSync(fileURLToPath(import.meta.url));
  } catch {
    return false;
  }
}

if (isEntryPoint()) {
  const result = runCli(process.argv.slice(2));
  if (result.out !== '') process.stdout.write(result.out);
  if (result.err !== '') process.stderr.write(result.err);
  process.exitCode = result.exitCode;
}
