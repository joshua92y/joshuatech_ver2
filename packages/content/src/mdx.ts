// packages/content/src/mdx.ts — T090: 파일 하나 — 디코드 · 울타리 · 본문 파싱(yaml 노드 대조) · YAML 판독 · 본문 거부 규칙 넷
//   · 컴파일(rehype · slug · 헤딩 · Shiki · html) · 읽기 시간.
//
// 설계: specs/003-platform-foundation/design/t090-design.md D3 · D5 · D6 · D7(§6이 본문을 이긴다 — §6-1 위치 없는 노드의 줄
//   · §6-3 날 DEL · §6-9 위치 없는 노드의 열).
// 순수 마크다운 + GFM(T086-e): MDX 파서 · 날 HTML 통과 플러그인을 쓰지 않는다. 본문 위반은 순수 함수로 모은다(〔90-8〕).
// 입력 값 0(D4): 반환 값에는 code · 줄 · 열만 싣는다. 라이브러리 오류(디코더 · YAML · 별칭 이름)는 버리고 code로 바꾼다.
// 출력 0: 이 모듈은 표준 출력 · 오류 출력 · 프로세스 경고를 쓰지 않는다 — YAML은 parseDocument + logLevel 'error'로만 읽는다
//   (yaml의 간편 파서 함수는 문서 경고를 프로세스 경고로 보내 원문 줄 · 키가 공개 CI 로그로 나간다 — D5).
// 특수 글자는 소스에 날 글자 · 역슬래시-u 이스케이프로 두지 않는다 — 코드 단위 비교로 판정한다(D15).

import rehypeShiki from '@shikijs/rehype';
import { toHtml } from 'hast-util-to-html';
import { toString as hastToString } from 'hast-util-to-string';
import rehypeSlug from 'rehype-slug';
import remarkFrontmatter from 'remark-frontmatter';
import remarkGfm from 'remark-gfm';
import remarkParse from 'remark-parse';
import remarkRehype from 'remark-rehype';
import { unified } from 'unified';
import { EXIT, SKIP, visit } from 'unist-util-visit';
import { isAlias, isMap, isNode, isPair, isScalar, parseDocument, visit as visitYaml } from 'yaml';

import { hasHttpUserinfo, hasUnsafeUrlChar } from './schema.ts';

// ---------- 형(이 모듈이 읽는 칸만 — 형 검사 도입 때 @types/mdast · @types/hast로 바꿀 수 있다 · §4-3) ----------

type Point = { readonly line: number; readonly column: number };
type Position = { readonly start: Point; readonly end: Point };

/** mdast 노드 */
export type MdNode = {
  type: string;
  value?: string;
  url?: string;
  alt?: string | null;
  title?: string | null;
  children?: MdNode[];
  position?: Position;
};

/** mdast 루트(parseMarkdown · parseFile이 돌려준다 — compile에 그대로 넘긴다) */
export type MdRoot = MdNode & { type: 'root'; children: MdNode[] };

/** 로케일(ko · en · ja) — URL 경로로만 나타낸다(web.md i18n) */
export const LANGS = ['ko', 'en', 'ja'] as const;
export type Lang = (typeof LANGS)[number];

const isLang = (value: unknown): value is Lang => typeof value === 'string' && (LANGS as readonly string[]).includes(value);

/** Shiki 언어 고정 목록(저장소가 쓰는 언어 — 정확한 Shiki 이름 · 별칭은 Shiki가 푼다 · mx-6). 공개 LANGS와 이름을 가른다(〔A-24〕 ②) */
export const CODE_LANGS: readonly string[] = Object.freeze([
  'shellscript',
  'powershell',
  'json',
  'yaml',
  'typescript',
  'tsx',
  'javascript',
  'python',
  'hcl',
  'diff',
  'toml',
  'docker',
]);

// ---------- 줄 · 위치(D5 줄 · D6 위치 없는 노드의 줄 · 열) ----------

/** CommonMark 줄 끝(\r\n · \r · \n) — micromark와 같다(〔A-9〕) */
const LINE_BREAK = /\r\n|\r|\n/;

const CR = 0x0d;
const LF = 0x0a;

const isPoint = (point: unknown): point is Point =>
  typeof point === 'object' &&
  point !== null &&
  Number.isInteger((point as Point).line) &&
  (point as Point).line >= 1 &&
  Number.isInteger((point as Point).column) &&
  (point as Point).column >= 1;

/** 위치가 온전한가 — mdast 변환(GFM 자동 링크 리터럴의 find-and-replace)이 만든 노드에는 위치가 없다(§6-1) */
function hasPosition(node: MdNode | undefined): node is MdNode & { position: Position } {
  const position = node?.position;
  return position !== undefined && position !== null && isPoint(position.start) && isPoint(position.end);
}

/** point에서 text를 따라 나아간다 — 줄 끝(\r\n · \r · \n 각각 하나)마다 다음 줄 1열 · 그 밖 UTF-16 code unit마다 열 + 1(micromark 열 단위) */
function advance(point: Point, text: string): Point {
  let { line, column } = point;
  for (let index = 0; index < text.length; index += 1) {
    const code = text.charCodeAt(index);
    if (code === CR) {
      if (text.charCodeAt(index + 1) === LF) index += 1;
      line += 1;
      column = 1;
    } else if (code === LF) {
      line += 1;
      column = 1;
    } else {
      column += 1;
    }
  }
  return { line, column };
}

/** 노드와 자손의 text 값(문서 순) */
function textOf(node: MdNode): string {
  if (node.type === 'text') return node.value ?? '';
  let out = '';
  for (const child of node.children ?? []) out += textOf(child);
  return out;
}

type Link = { readonly parent: MdNode; readonly index: number };

/** 가장 가까운 위치 있는 조상(link.parent부터 위로)의 끝 줄을 넘지 않게 자른다 — 자르면 열은 그 끝 열이다(문자 참조로 풀린 줄 끝 — §5-1 24) */
function clampToAncestor(point: Point, link: Link, links: WeakMap<MdNode, Link>): Point {
  let current: MdNode = link.parent;
  let currentLink = links.get(current);
  while (!hasPosition(current)) {
    if (currentLink === undefined) return point;
    current = currentLink.parent;
    currentLink = links.get(current);
  }
  const end = current.position.end;
  return point.line > end.line ? { line: end.line, column: end.column } : point;
}

/**
 * 노드의 시작 점(D6 「위치 없는 노드의 줄」 · §6-9 열). 위치가 있으면 그 시작 점이다. 없으면 같은 부모에서 앞선 위치 있는 형제의 끝 점
 * (없으면 부모의 시작 점 — 부모도 위치가 없으면 같은 규칙으로 재귀)에서 출발해 그 사이 위치 없는 형제들의 text 값(자손 포함)을 따라
 * 나아가고, 가장 가까운 위치 있는 조상의 끝 줄에서 자른다. position을 그대로 읽지 않는다(위치 없는 노드에서 position.start는 없다).
 */
function startPoint(node: MdNode, link: Link | undefined, links: WeakMap<MdNode, Link>): Point {
  if (hasPosition(node)) return node.position.start;
  if (link === undefined) return { line: 1, column: 1 };
  const siblings = link.parent.children ?? [];
  let previous = link.index - 1;
  while (previous >= 0 && !hasPosition(siblings[previous])) previous -= 1;
  const anchor = siblings[previous];
  let point = previous >= 0 && hasPosition(anchor) ? anchor.position.end : startPoint(link.parent, links.get(link.parent), links);
  for (let index = previous + 1; index < link.index; index += 1) {
    const sibling = siblings[index];
    if (sibling !== undefined) point = advance(point, textOf(sibling));
  }
  return clampToAncestor(point, link, links);
}

// ---------- 파싱(D3 3-3) ----------

/** remark-parse + remark-frontmatter(yaml만) + remark-gfm — 한 번 만들어 얼린다. parse가 GFM mdast 변환(자동 링크 리터럴)까지 돈다 */
const PARSER = unified().use(remarkParse).use(remarkFrontmatter, ['yaml']).use(remarkGfm).freeze();

/** 원문 전체를 mdast로(줄 = 원문 줄 · 파일 첫 줄 = 1) */
export function parseMarkdown(text: string): MdRoot {
  if (typeof text !== 'string') throw new TypeError('parseMarkdown: text must be a string');
  return PARSER.parse(text) as unknown as MdRoot;
}

// ---------- 본문 거부 규칙(D6 — 모든 컬렉션) ----------

export type BodyCode = 'raw-html' | 'esm' | 'expression' | 'unsafe-url';

/** 본문 위반 하나 — 열은 정렬(D4 순서 4)에만 쓴다(issue에는 싣지 않는다) */
export type BodyViolation = { readonly code: BodyCode; readonly line: number; readonly column: number };

/** 같은 줄 · 같은 열이면 머리 :38의 규칙 순 */
const RULE_RANK: Readonly<Record<BodyCode, number>> = { 'raw-html': 0, esm: 1, expression: 2, 'unsafe-url': 3 };

/** esm 줄 머리 판정 — 설계 정규식 /^(?:import|export)[ \t{*]/를 줄 머리 자리에서 잰다(sticky) */
const ESM_AT = /(?:import|export)[ \t{*]/y;

function esmAt(value: string, offset: number): boolean {
  ESM_AT.lastIndex = offset;
  return ESM_AT.test(value);
}

const hasBrace = (value: unknown): boolean => typeof value === 'string' && (value.includes('{') || value.includes('}'));

const SCHEME = /^([A-Za-z][A-Za-z0-9+.-]*):/;
const ALLOWED_SCHEMES: ReadonlySet<string> = new Set(['http', 'https', 'mailto']);

/**
 * unsafe-url 판정(D6 순서): 1 공백 · 제어(C0 · DEL · C1) · 역슬래시 → 위반 · 2 `//`로 시작 → 위반 · 3 `#`로 시작 → 허용
 * · 4 스킴이 있으면 소문자가 http · https · mailto일 때만 허용(http(s)는 authority의 userinfo `@` → 위반) · 5 그 밖(상대 · 빈 값) → 허용.
 * 값은 mdast url(문자 참조 해석 뒤)이다. url이 문자열이 아니면 닫힌 쪽(위반)이다.
 */
function isUnsafeUrl(url: unknown): boolean {
  if (typeof url !== 'string') return true;
  if (hasUnsafeUrlChar(url)) return true;
  if (url.startsWith('//')) return true;
  if (url.startsWith('#')) return false;
  const scheme = SCHEME.exec(url);
  if (scheme === null) return false;
  if (!ALLOWED_SCHEMES.has((scheme[1] ?? '').toLowerCase())) return true;
  return hasHttpUserinfo(url);
}

function compareViolations(left: BodyViolation, right: BodyViolation): number {
  return left.line - right.line || left.column - right.column || RULE_RANK[left.code] - RULE_RANK[right.code];
}

/**
 * 본문 위반(D6)을 모은다 — 순수 함수. 트리 전체를 문서 순으로 돈다(yaml 노드는 건너뛰고 code · inlineCode 값은 보지 않는다).
 *   raw-html   html 노드마다(흐름 · 글줄)
 *   esm        문단의 직계 text 자식에서 줄 머리(문단 첫 자식의 시작 · break 바로 뒤 자식의 시작 · 값 안 줄 끝 바로 뒤)가
 *              /^(?:import|export)[ \t{*]/로 시작하는 줄마다(컨테이너 기준 — 〔A-7〕)
 *   expression text 값 · image · imageReference alt · link · image · definition title의 중괄호 — 노드마다
 *   unsafe-url link · image · definition url(위 판정) — 노드마다
 * 줄 · 열 = 노드 시작 점(위치 없는 노드는 startPoint 규칙 · 가장 가까운 위치 있는 조상의 끝 줄에서 자른다).
 * 돌려주는 순서 = 줄 → 열 → 규칙 순(D4 순서 4) — 로더는 파일 안 본문 issue를 이 순서 그대로 둔다.
 */
export function bodyViolations(tree: MdRoot): BodyViolation[] {
  const links = new WeakMap<MdNode, Link>();
  const out: BodyViolation[] = [];

  const add = (code: BodyCode, point: Point): void => {
    out.push({ code, line: point.line, column: point.column });
  };
  const at = (node: MdNode, link: Link | undefined): Point => startPoint(node, link, links);

  // esm 줄 = text 시작 줄 + 앞선 줄 끝 수(text에 위치가 없으면 시작 줄은 startPoint 규칙 — D6 표). 문자 참조로 만든 줄 끝(&#10;)도
  // 줄 끝으로 세므로 그때 줄은 실제 줄과 어긋날 수 있다(D6 「보수적인 곳」 — 기록).
  const scanEsm = (paragraph: MdNode): void => {
    let lineHead = true; // 문단 첫 자식의 시작
    (paragraph.children ?? []).forEach((child, index) => {
      if (child.type === 'text') {
        const value = child.value ?? '';
        let start: Point | undefined; // 맞는 줄이 있을 때만 잰다
        const startOfText = (): Point => (start ??= startPoint(child, { parent: paragraph, index }, links));
        if (lineHead && esmAt(value, 0)) add('esm', startOfText());
        let breaks = 0;
        for (let offset = 0; offset < value.length; offset += 1) {
          const code = value.charCodeAt(offset);
          if (code !== CR && code !== LF) continue;
          if (code === CR && value.charCodeAt(offset + 1) === LF) offset += 1;
          breaks += 1;
          // 값 안 줄 끝 바로 뒤 = 다음 줄 1열(advance와 같은 걸음)
          if (esmAt(value, offset + 1)) add('esm', { line: startOfText().line + breaks, column: 1 });
        }
      }
      lineHead = child.type === 'break';
    });
  };

  visit(tree as never, (node: MdNode, index: number | undefined, parent: MdNode | undefined) => {
    const link = parent !== undefined && index !== undefined ? { parent, index } : undefined;
    if (link !== undefined) links.set(node, link);
    switch (node.type) {
      case 'yaml':
        return SKIP;
      case 'html':
        add('raw-html', at(node, link));
        break;
      case 'paragraph':
        scanEsm(node);
        break;
      case 'text':
        if (hasBrace(node.value)) add('expression', at(node, link));
        break;
      case 'imageReference':
        if (hasBrace(node.alt)) add('expression', at(node, link));
        break;
      case 'image':
        if (hasBrace(node.alt) || hasBrace(node.title)) add('expression', at(node, link));
        if (isUnsafeUrl(node.url)) add('unsafe-url', at(node, link));
        break;
      case 'link':
      case 'definition':
        if (hasBrace(node.title)) add('expression', at(node, link));
        if (isUnsafeUrl(node.url)) add('unsafe-url', at(node, link));
        break;
      default:
        break;
    }
    return undefined;
  });

  return out.sort(compareViolations);
}

// ---------- 프런트매터(D5) ----------

type Fence = { readonly block: string; readonly closeLine: number };

/**
 * 울타리(디코드한 원문으로 판정 — remark에 맡기지 않는다): 첫 줄이 정확히 `---` · 닫는 줄 = 둘째 줄부터 정확히 `---`인 첫 줄.
 * YAML 블록 = 그 사이 줄들을 \n으로 다시 이은 것(줄 끝 꼴과 무관). 아니면 undefined(fence).
 */
function splitFrontmatter(text: string): Fence | undefined {
  const lines = text.split(LINE_BREAK);
  if (lines[0] !== '---') return undefined;
  const close = lines.indexOf('---', 1);
  if (close < 1) return undefined;
  return { block: lines.slice(1, close).join('\n'), closeLine: close + 1 };
}

/** D3 3-3: 첫 자식이 yaml 노드이고 그 끝 줄이 우리 닫는 울타리 줄이다(블록 안 `---␠` · `---<TAB>` 줄에서는 micromark가 먼저 닫는다) */
function yamlNodeEndsAt(tree: MdRoot, closeLine: number): boolean {
  const first = tree.children[0];
  return first !== undefined && first.type === 'yaml' && hasPosition(first) && first.position.end.line === closeLine;
}

/**
 * yaml 2.9.1 판독 옵션 — 간편 파서 함수 금지 · logLevel 'error'(경고를 프로세스로 보내지 않는다 · 'silent'은 MULTIPLE_DOCS까지 지운다).
 * resolveKnownTags: false(설계 정정 노트 1) — version '1.2'의 기본값은 true라 core 스키마 밖의 YAML 1.1 태그(!!set · !!omap · !!pairs
 * · !!timestamp · !!binary · !!merge)를 경고 없이 Set · Map · Date · 바이트 배열로 푼다(yaml dist/doc/Document.js:272
 * · dist/schema/tags.js:47–:54). false면 그 태그가 모르는 태그(TAG_RESOLVE_FAILED 경고)가 되어 판독 2가 yaml로 닫는다.
 * core 태그(!!map · !!seq · !!str · !!null · !!bool · !!int · !!float)는 그대로 풀린다.
 */
const YAML_OPTIONS = {
  version: '1.2',
  schema: 'core',
  resolveKnownTags: false,
  uniqueKeys: true,
  strict: true,
  prettyErrors: false,
  logLevel: 'error',
} as const;

/** 키 꼴(content.md:31) — 따옴표 키도 같은 글자 규칙만 본다(〔A-9〕 ②) */
const KEY_RE = /^[A-Za-z][A-Za-z0-9_]{0,63}$/;

/** 지시자 · 추가 문서 표식 줄(판독 1) */
const DOCUMENT_MARKER = /^(?:---|\.\.\.)(?:[ \t]|$)/;

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const isPlainKey = (key: unknown): boolean => isScalar(key) && typeof key.value === 'string' && KEY_RE.test(key.value);

export type YamlResult = { readonly ok: true; readonly data: Record<string, unknown> } | { readonly ok: false };

const YAML_REJECTED: YamlResult = Object.freeze({ ok: false });

/**
 * YAML 블록 판독(D5 — YAML 1.2 core · 날짜는 문자열). 아래 중 하나면 { ok: false }(→ frontmatter yaml)이고 이유 · 원 예외는 싣지 않는다.
 *   1 블록에 `---` · `...`(+ 공백 · 탭 · 줄 끝) 줄이나 `%` 줄이 있다   2 doc.errors · doc.warnings가 있다(모르는 태그 = 경고 · YAML 1.1 태그 포함)
 *   3 최상위가 매핑이 아니다   4 매핑 키(중첩 포함)가 문자열 스칼라가 아니거나 KEY_RE 밖이다   5 앵커 · 별칭이 하나라도 있다
 *   6 toJS가 던진다(남는 방어 — 원 예외는 버린다)
 */
export function readYamlBlock(block: string): YamlResult {
  if (typeof block !== 'string') throw new TypeError('readYamlBlock: block must be a string');
  for (const line of block.split(LINE_BREAK)) {
    if (DOCUMENT_MARKER.test(line) || line.startsWith('%')) return YAML_REJECTED;
  }
  const doc = parseDocument(block, YAML_OPTIONS);
  if (doc.errors.length > 0 || doc.warnings.length > 0) return YAML_REJECTED;
  if (!isMap(doc.contents)) return YAML_REJECTED;
  let rejected = false;
  visitYaml(doc, (_key, node) => {
    const anchored = isNode(node) && typeof node.anchor === 'string';
    if (isAlias(node) || anchored || (isPair(node) && !isPlainKey(node.key))) {
      rejected = true;
      return visitYaml.BREAK;
    }
    return undefined;
  });
  if (rejected) return YAML_REJECTED;
  let data: unknown;
  try {
    data = doc.toJS();
  } catch {
    return YAML_REJECTED;
  }
  if (!isRecord(data)) return YAML_REJECTED;
  return { ok: true, data };
}

// ---------- 파일 함수(D3 3-1–3-4 · 3-6) ----------

export type FileResult =
  | { readonly ok: true; readonly data: Record<string, unknown>; readonly tree: MdRoot; readonly body: readonly BodyViolation[] }
  | { readonly ok: false; readonly field: 'file'; readonly code: 'encoding' }
  | { readonly ok: false; readonly field: 'frontmatter'; readonly code: 'fence' | 'yaml' };

const ENCODING_FAILURE: FileResult = Object.freeze({ ok: false, field: 'file', code: 'encoding' });
const FENCE_FAILURE: FileResult = Object.freeze({ ok: false, field: 'frontmatter', code: 'fence' });
const YAML_FAILURE: FileResult = Object.freeze({ ok: false, field: 'frontmatter', code: 'yaml' });

/** 엄격 UTF-8 · BOM은 지우지 않고 남긴다(N-3 — 첫 줄이 U+FEFF + `---`이면 fence). 실패하면 undefined(디코더 오류는 버린다) */
const DECODER = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true });

function decodeUtf8(bytes: Uint8Array): string | undefined {
  try {
    return DECODER.decode(bytes);
  } catch {
    return undefined;
  }
}

/**
 * 파일 하나(D3 A-3): 3-1 디코드(encoding) → 3-2 울타리(fence) → 3-3 본문 파싱 · yaml 노드 끝 줄 대조(fence — YAML · 스키마 앞)
 * → 3-4 YAML(yaml) → 3-6 본문 위반(같은 트리). 스키마(3-5)는 로더가 schema.ts validateFrontmatter(data, collection)로 돈다.
 * 실패한 파일의 내용 단계 issue는 하나다(머리 :45). 성공하면 data · tree(컴파일용) · body(정렬된 본문 위반)를 돌려준다.
 */
export function parseFile(bytes: Uint8Array): FileResult {
  if (!(bytes instanceof Uint8Array)) throw new TypeError('parseFile: bytes must be a Uint8Array');
  const text = decodeUtf8(bytes);
  if (text === undefined) return ENCODING_FAILURE;
  const fence = splitFrontmatter(text);
  if (fence === undefined) return FENCE_FAILURE;
  const tree = parseMarkdown(text);
  if (!yamlNodeEndsAt(tree, fence.closeLine)) return FENCE_FAILURE;
  const yaml = readYamlBlock(fence.block);
  if (!yaml.ok) return YAML_FAILURE;
  return { ok: true, data: yaml.data, tree, body: bodyViolations(tree) };
}

// ---------- 읽기 시간(D7 — 〔90-10〕) ----------

/** 분당 낱말 수(설계 선택 — mx-7이 고정한다) */
const WORDS_PER_MINUTE = 200;

/** lang마다 낱말 분절기 하나(Node 공식 빌드 ICU) */
const SEGMENTERS: Readonly<Record<Lang, Intl.Segmenter>> = Object.freeze({
  ko: new Intl.Segmenter('ko', { granularity: 'word' }),
  en: new Intl.Segmenter('en', { granularity: 'word' }),
  ja: new Intl.Segmenter('ja', { granularity: 'word' }),
});

/** 본문 mdast의 text · inlineCode 값(코드 블록 · 프런트매터 제외)에서 isWordLike 조각 수 → max(1, ceil(수 / 200)) */
export function readingTime(tree: MdRoot, lang: Lang): number {
  if (!isLang(lang)) throw new TypeError('readingTime: unknown lang');
  const segmenter = SEGMENTERS[lang];
  let words = 0;
  visit(tree as never, (node: MdNode) => {
    if (node.type === 'code' || node.type === 'yaml') return SKIP;
    if ((node.type === 'text' || node.type === 'inlineCode') && typeof node.value === 'string') {
      for (const segment of segmenter.segment(node.value)) if (segment.isWordLike === true) words += 1;
    }
    return undefined;
  });
  return Math.max(1, Math.ceil(words / WORDS_PER_MINUTE));
}

// ---------- 컴파일(D7 — issue 0일 때만 · D3 B-6) ----------

/** hast 노드(이 모듈이 읽는 칸만) */
type HastNode = { type: string; tagName?: string; properties?: Record<string, unknown>; children?: HastNode[]; value?: string };

/** 목차 항목(FR-029 — h2 · h3 · 각주 라벨 제외) */
export type Heading = { readonly depth: 2 | 3; readonly text: string; readonly id: string };

export type Compiled = { readonly html: string; readonly headings: Heading[]; readonly readingTime: number };

/** 각주 라벨(remark-rehype footnoteLabel — C6) */
const FOOTNOTE_LABEL: Readonly<Record<Lang, string>> = Object.freeze({ ko: '각주', en: 'Footnotes', ja: '脚注' });

/** 되돌림 번호 = referenceIndex + 1 · 재참조(rereferenceIndex는 1부터 센다 — mdast-util-to-hast 13.2.2 footer.js)는 -k */
const backReference = (referenceIndex: number, rereferenceIndex: number): string =>
  `${referenceIndex + 1}${rereferenceIndex > 1 ? `-${rereferenceIndex}` : ''}`;

type BackLabel = (referenceIndex: number, rereferenceIndex: number) => string;

/** 되돌림 라벨(〔A-4〕 · C6) — en은 라이브러리 기본값(Back to reference n)이라 넘기지 않는다 */
const FOOTNOTE_BACK_LABEL: Readonly<Record<Lang, BackLabel | undefined>> = Object.freeze({
  ko: (referenceIndex: number, rereferenceIndex: number) => `${backReference(referenceIndex, rereferenceIndex)}번 참조로 돌아가기`,
  en: undefined,
  ja: (referenceIndex: number, rereferenceIndex: number) => `参照 ${backReference(referenceIndex, rereferenceIndex)} に戻る`,
});

function rehypeOptions(lang: Lang): Record<string, unknown> {
  const options: Record<string, unknown> = { allowDangerousHtml: false, footnoteLabel: FOOTNOTE_LABEL[lang] };
  const backLabel = FOOTNOTE_BACK_LABEL[lang];
  if (backLabel !== undefined) options.footnoteBackLabel = backLabel;
  return options;
}

/** lang마다 처리기 하나 — mdast → hast(remark-rehype · 날 HTML은 버린다) → 헤딩 id(rehype-slug · 접두 없음). 모듈 수준에서 한 번 만들어 얼린다 */
const toHastProcessor = (lang: Lang) => unified().use(remarkRehype, rehypeOptions(lang)).use(rehypeSlug).freeze();
const TO_HAST = Object.freeze({ ko: toHastProcessor('ko'), en: toHastProcessor('en'), ja: toHastProcessor('ja') });

/**
 * Shiki(@shikijs/rehype 기본 export): 테마 github-light · github-dark · defaultColor false(색은 CSS 변수) · 언어 = CODE_LANGS
 * · 기본 · 대체 언어 text · lazy 0 · onError 0(하이라이터 고장은 던진다). 하이라이터는 첫 코드 블록에서 만든다(싱글턴).
 */
const SHIKI = unified()
  .use(rehypeShiki, {
    themes: { light: 'github-light', dark: 'github-dark' },
    defaultColor: false,
    langs: [...CODE_LANGS],
    defaultLanguage: 'text',
    fallbackLanguage: 'text',
  })
  .freeze();

/** 코드 블록(pre)이 있는가 — 없으면 하이라이터를 만들지 않는다(ld-1이 초기화 비용을 내지 않게 — D7) */
function hasPre(tree: HastNode): boolean {
  let found = false;
  visit(tree as never, 'element', (node: HastNode) => {
    if (node.tagName !== 'pre') return undefined;
    found = true;
    return EXIT;
  });
  return found;
}

/** 각주 섹션(mdast-util-to-hast가 만드는 section[data-footnotes]) — 그 안의 h2#footnote-label은 목차가 아니다 */
function isFootnoteSection(node: HastNode): boolean {
  const flag = node.properties?.dataFootnotes;
  return node.tagName === 'section' && flag !== undefined && flag !== null && flag !== false;
}

/** rehype-slug 뒤 hast에서 h2 · h3만 문서 순으로 모은다(h1 · h4 제외 · 각주 섹션 아래 건너뜀) */
function collectHeadings(tree: HastNode): Heading[] {
  const headings: Heading[] = [];
  visit(tree as never, 'element', (node: HastNode) => {
    if (isFootnoteSection(node)) return SKIP;
    if (node.tagName !== 'h2' && node.tagName !== 'h3') return undefined;
    const id = node.properties?.id;
    headings.push({ depth: node.tagName === 'h2' ? 2 : 3, text: hastToString(node as never), id: typeof id === 'string' ? id : '' });
    return SKIP;
  });
  return headings;
}

/**
 * 트리 하나를 lang 옵션으로 컴파일한다(D7): remark-rehype → rehype-slug → 헤딩 수집 → Shiki(코드 블록이 있을 때만) → html.
 * html = hast-util-to-html 기본(텍스트 · 속성 값 이스케이프). 받은 mdast는 바꾸지 않는다.
 */
export async function compile(tree: MdRoot, lang: Lang): Promise<Compiled> {
  if (!isLang(lang)) throw new TypeError('compile: unknown lang');
  const minutes = readingTime(tree, lang);
  const hast = (await TO_HAST[lang].run(tree as never)) as unknown as HastNode;
  const headings = collectHeadings(hast);
  const output = hasPre(hast) ? ((await SHIKI.run(hast as never)) as unknown as HastNode) : hast;
  return { html: toHtml(output as never), headings, readingTime: minutes };
}
