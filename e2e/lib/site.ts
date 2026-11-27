// e2e/lib/site.ts — T087 site 프로젝트의 대상 검증 · 도달 분류 · 판정(설계 specs/003-platform-foundation/design/t086-design.md D10 ① ⑥ · D11 · D12).
// 순수 함수 — 호출은 http.ts 감싸개(spec), 출력은 out.ts(spec)가 한다. 판정 결과에는 상태 코드 · 수 · 고정 사유 코드 · 우리 상수(경로 · slug)만 싣는다 —
// 본문 · 헤더 · 쿠키 값과 BASE_URL 값은 0. 계약: contracts/bff-api.md :3(x-request-id) · :35(health) · :36(proxy) · :62–:67(Set-Cookie 위생) · :87 · :90(오류 형식).
import * as fs from 'node:fs';
import * as path from 'node:path';
import { BFF_PATHS } from './bff';
import type { HttpResult } from './http';
import type { StopPrefix } from './out';

const REPO_ROOT = path.resolve(__dirname, '..', '..');

export type SiteMode = 'local' | 'prod';

export interface SiteStop {
  ok: false;
  prefix: StopPrefix;
  code: string;
  note?: string;
}

export type SiteVerdict = { ok: true; code: string } | SiteStop;

const product = (code: string): SiteStop => ({ ok: false, prefix: 'product', code });

// ---- 대상(D10 ①) — local = 루프백 origin만 · prod = 정확히 apex. preview는 Access 뒤라 자동 대상 밖(infra/cloudflare/access.tf) · next dev도 대상 밖 ----
export const PROD_ORIGIN = 'https://joshuatech.dev';
const LOCAL_ORIGIN = /^http:\/\/(127\.0\.0\.1|localhost):([0-9]{1,5})$/;

export function validateSiteTarget(baseUrl: unknown, mode: unknown): { ok: true; base: string; mode: SiteMode } | SiteStop {
  const guard: SiteStop = { ok: false, prefix: 'guard', code: 'site-target-not-allowed' };
  if (typeof baseUrl !== 'string' || (mode !== 'local' && mode !== 'prod')) return guard;
  if (mode === 'prod') return baseUrl === PROD_ORIGIN ? { ok: true, base: baseUrl, mode } : guard;
  const m = LOCAL_ORIGIN.exec(baseUrl);
  if (!m) return guard;
  const port = Number(m[2]);
  if (!Number.isInteger(port) || port < 1 || port > 65535) return guard;
  let origin: string;
  try {
    origin = new URL(baseUrl).origin;
  } catch {
    return guard;
  }
  // 정규형과 글자 그대로 같아야 한다(앞 0 · 기본 포트 80 · 대소문자 변형은 다른 글자로 접힌다)
  return origin === baseUrl ? { ok: true, base: baseUrl, mode } : guard;
}

// ---- 도달(D11 표) ----
export const LOCALES = ['ko', 'en', 'ja'] as const;
export const SITE_MARKER = 'data-jt-app="web"';
export const SITE_MARKER_SELECTOR = '[data-jt-app="web"]';
export const SCAFFOLD_FILE = 'apps/web/next.config.ts';
export const SITE_ABSENT_CODE = 'site-absent until T091';
export const SITE_ABSENT_NOTE = 'loopback refused and apps/web scaffold absent (next.config.ts)';
const SERVER_NOT_RUNNING_NOTE = 'apps/web scaffold present (next.config.ts) - next start is not listening';
const PROD_NOT_V2_NOTE = 'T094 전';

export interface SiteObservation {
  status: number;
  contentType: string | null;
  marker: boolean;
}

function mediaType(contentType: string | null | undefined): string {
  return (contentType ?? '').split(';')[0].trim().toLowerCase();
}

export function observeSite(r: HttpResult): SiteObservation {
  return { status: r.status, contentType: r.headers['content-type'] ?? null, marker: r.body.toString('utf8').includes(SITE_MARKER) };
}

export function classifySiteReach(mode: SiteMode, o: SiteObservation): SiteVerdict {
  if (o.status === 200 && mediaType(o.contentType) === 'text/html' && o.marker) return { ok: true, code: 'site-v2' };
  if (mode === 'local') return product(`reach-unexpected status=${o.status}`);
  // prod — 52x와 그 밖 5xx는 오리진 쪽(빨강 증거 아님) · 그 밖(T094 전 v1 apex 포함)은 v2 부재. T094 뒤에는 [product]로 바꾼다.
  if (o.status >= 500 && o.status <= 599) return { ok: false, prefix: 'env', code: `origin status=${o.status}` };
  return { ok: false, prefix: 'env', code: `prod-site-not-v2 status=${o.status}`, note: PROD_NOT_V2_NOTE };
}

// [gate](빨강 증거)는 local 루프백 거부 + apps/web 스캐폴드 없음일 때만이다 — 스캐폴드가 있는데 거부면 서버를 띄우지 않은 실행 환경 문제다.
export function classifySiteReachError(mode: SiteMode, code: string, scaffold: boolean): SiteVerdict {
  if (mode === 'local' && code === 'refused') {
    return scaffold
      ? { ok: false, prefix: 'env', code: 'site-server-not-running', note: SERVER_NOT_RUNNING_NOTE }
      : { ok: false, prefix: 'gate', code: SITE_ABSENT_CODE, note: SITE_ABSENT_NOTE };
  }
  return { ok: false, prefix: 'env', code: `network (${code})` };
}

export function scaffoldPresent(root: string = REPO_ROOT): boolean {
  try {
    return fs.statSync(path.join(root, ...SCAFFOLD_FILE.split('/'))).isFile();
  } catch {
    return false;
  }
}

const NETWORK_CODES = new Set(['dns', 'refused', 'reset', 'network', 'tls']);

// 도달 뒤 단계의 요청 · 탐색 오류
export function siteErrorVerdict(step: string, code: string): SiteStop {
  return NETWORK_CODES.has(code) ? { ok: false, prefix: 'env', code: `network (${code})` } : product(`${step}-failed (${code})`);
}

// ---- h-1 ----
export function judgeLocale(pathname: string, r: HttpResult): SiteVerdict {
  if (r.status !== 200) return product(`locale status=${r.status} path=${pathname}`);
  if (mediaType(r.headers['content-type']) !== 'text/html') return product(`locale-media-type path=${pathname}`);
  if (!r.body.toString('utf8').includes(SITE_MARKER)) return product(`locale-marker path=${pathname}`);
  return { ok: true, code: 'locale' };
}

// ---- Set-Cookie 위생(h-3 · h-4 · h-7 · h-8 — bff-api.md:67 · 86-5) ----
// prod 엣지(Cloudflare)가 붙일 수 있는 쿠키 이름 — 이름만 INFO로 낸다(VD-T087-4 — T095 실측으로 확정)
export const EDGE_COOKIE_NAMES: readonly string[] = Object.freeze(['__cf_bm', '_cfuvid', 'cf_clearance', '__cflb']);
// RFC 6265 cookie-name = token(RFC 2616) — 그 밖의 이름은 글자를 남기지 않고 수만 센다
const TOKEN = /^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/;

// Playwright APIResponse.headers()는 여러 Set-Cookie를 줄바꿈으로 잇는다(selftest-browser site-probe 실측). 값은 버린다.
export function cookieNames(setCookie: string | undefined): { names: string[]; unparsable: number } {
  const names: string[] = [];
  let unparsable = 0;
  for (const line of (setCookie ?? '').split('\n')) {
    if (line.trim().length === 0) continue;
    const eq = line.indexOf('=');
    const name = eq === -1 ? '' : line.slice(0, eq).trim();
    if (TOKEN.test(name)) names.push(name);
    else unparsable += 1;
  }
  return { names, unparsable };
}

function edgeOnly(names: readonly string[]): string[] {
  return [...new Set(names.filter((n) => EDGE_COOKIE_NAMES.includes(n)))].sort();
}

// local: Set-Cookie 0 · prod: 엣지 이름 밖 0(이름 · 꼴을 모르는 것은 앱 쿠키로 센다)
export function judgeSetCookie(mode: SiteMode, pathname: string, r: HttpResult): { ok: true; edge: string[] } | SiteStop {
  const c = cookieNames(r.headers['set-cookie']);
  const bad = mode === 'local' ? c.names.length + c.unparsable : c.names.filter((n) => !EDGE_COOKIE_NAMES.includes(n)).length + c.unparsable;
  if (bad > 0) return product(`set-cookie n=${bad} path=${pathname}`);
  return { ok: true, edge: mode === 'local' ? [] : edgeOnly(c.names) };
}

// 탐색 뒤 브라우저 쿠키 이름(값은 받지 않는다) — local 0 · prod 엣지 이름만
export function judgeCookieNames(mode: SiteMode, where: string, names: readonly string[]): { ok: true; edge: string[] } | SiteStop {
  const bad = mode === 'local' ? names.length : names.filter((n) => !EDGE_COOKIE_NAMES.includes(n)).length;
  if (bad > 0) return product(`browser-cookies n=${bad} path=${where}`);
  return { ok: true, edge: mode === 'local' ? [] : edgeOnly(names) };
}

// ---- h-4 `/` 302(D11 사례 표 — T091은 302를 명시한다 · NextResponse.redirect 기본은 307) ----
export interface RootCase {
  id: string;
  acceptLanguage: string | null;
  expect: '/ko' | '/en' | '/ja';
}

export const ROOT_CASES: readonly RootCase[] = Object.freeze([
  { id: 'r1', acceptLanguage: 'ko', expect: '/ko' },
  { id: 'r2', acceptLanguage: 'ko-KR,ko;q=0.9,en;q=0.8', expect: '/ko' },
  { id: 'r3', acceptLanguage: 'en-US,en;q=0.9', expect: '/en' },
  { id: 'r4', acceptLanguage: 'ja,en;q=0.5', expect: '/ja' },
  { id: 'r5', acceptLanguage: null, expect: '/ko' }, // 헤더 없음(새 요청 컨텍스트는 accept-language를 싣지 않는다 — VD-T087-1)
  { id: 'r6', acceptLanguage: 'fr-FR,fr;q=0.9', expect: '/ko' },
  { id: 'r7', acceptLanguage: 'fr, en;q=0.5, ja;q=0.8', expect: '/ja' },
] as RootCase[]);

export function judgeRootRedirect(base: string, c: RootCase, r: HttpResult): SiteVerdict {
  if (r.status !== 302) return product(`root-redirect status=${r.status} case=${c.id}`);
  const loc = r.headers['location'];
  let u: URL | null = null;
  if (typeof loc === 'string' && loc.length > 0) {
    try {
      u = new URL(loc, base);
    } catch {
      u = null;
    }
  }
  if (u === null || u.origin !== new URL(base).origin || u.pathname !== c.expect) return product(`root-location case=${c.id}`);
  return { ok: true, code: 'root-redirect' };
}

// ---- 문제 응답 · x-request-id(bff-api.md:3 · :87 · :90) ----
export const REQUEST_ID_RE = /^[A-Za-z0-9._:-]{1,128}$/;
export const PROBLEM_NOT_FOUND = 'https://joshuatech.dev/problems/not-found';
export const NOT_A_POD_PATH = '/api/proxy/not-a-pod/x';
export const HEALTH_PATH = BFF_PATHS.health;
export const HEALTH_SKIP_INFO = 'T087 health skipped mode=local';
// h-7 degraded 알림(리뷰 A-2 · 컨트롤러 결정) — spec이 이 상수 한 줄만 낸다(상류 값 · 본문 글자 0)
export const HEALTH_DEGRADED_INFO = 'health-status degraded';

// JSON 객체만 돌려준다. JSON.parse 오류 메시지는 입력 조각을 싣는다(V8) — 오류를 삼키고 null만 돌려준다.
function jsonObject(body: Buffer): Record<string, unknown> | null {
  let v: unknown;
  try {
    v = JSON.parse(body.toString('utf8'));
  } catch {
    return null;
  }
  return typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
}

function requestIdHeader(r: HttpResult): string | null {
  const v = r.headers['x-request-id'];
  return typeof v === 'string' && REQUEST_ID_RE.test(v) ? v : null;
}

// h-7(prod) — 200 { status: "ok" | "degraded", upstream: "identity-admin", upstream_ms, checks } + x-request-id(BFF가 만든 응답 — bff-api.md GET /api/health 행 · C17).
// status는 상류 값이고 둘 다 계약상 유효하다(그 밖이면 BFF는 503) — 둘 다 PASS, degraded는 불리언으로만 돌려준다(spec이 HEALTH_DEGRADED_INFO 한 줄 — 리뷰 A-2).
export type HealthVerdict = { ok: true; code: 'health'; degraded: boolean } | SiteStop;

export function judgeHealth(r: HttpResult): HealthVerdict {
  if (r.status !== 200) return product(`health status=${r.status}`);
  if (mediaType(r.headers['content-type']) !== 'application/json') return product('health-media-type');
  const j = jsonObject(r.body);
  if (j === null) return product('health-body');
  if (j.status !== 'ok' && j.status !== 'degraded') return product('health-status-field');
  if (j.upstream !== 'identity-admin') return product('health-upstream');
  const ms = j.upstream_ms;
  if (typeof ms !== 'number' || !Number.isFinite(ms) || ms < 0) return product('health-upstream-ms');
  if (requestIdHeader(r) === null) return product('request-id-header');
  return { ok: true, code: 'health', degraded: j.status === 'degraded' };
}

// h-8 — 맵에 없는 pod는 상류 호출 없이 404 not_found(BFF problem+json · request_id = x-request-id · nosniff) — 설정(env)이 없어도 같다(C26)
export function judgeNotFound(r: HttpResult): SiteVerdict {
  if (r.status !== 404) return product(`proxy-not-found status=${r.status}`);
  if (mediaType(r.headers['content-type']) !== 'application/problem+json') return product('proxy-not-found-media-type');
  const j = jsonObject(r.body);
  if (j === null) return product('proxy-not-found-body');
  if (j.type !== PROBLEM_NOT_FOUND) return product('proxy-not-found-type');
  const rid = requestIdHeader(r);
  if (rid === null) return product('request-id-header');
  if (j.request_id !== rid) return product('request-id-mismatch');
  if ((r.headers['x-content-type-options'] ?? '').trim().toLowerCase() !== 'nosniff') return product('nosniff');
  return { ok: true, code: 'problem=not-found' };
}

// ---- h-2 · h-5 노트 표식(spec AC2 — data-model §11: slug = 파일명) ----
export const NOTES: ReadonlyArray<{ slug: string; pubDate: string }> = Object.freeze([
  { slug: '001-claude-setup', pubDate: '2026-08-26' },
  { slug: '002-smoke', pubDate: '2026-08-27' },
]);
export const NOTE_TAG = 'claude-code';
export const NOTE_SEL = Object.freeze({
  any: '[data-note-slug]',
  note: (slug: string): string => `[data-note-slug="${slug}"]`,
  title: '[data-note-title]',
  time: (pubDate: string): string => `time[datetime="${pubDate}"]`,
  tag: `[data-note-tag="${NOTE_TAG}"]`,
  // 「번역 없음」 배지는 글자가 아니라 속성으로 판정한다(글자 읽기 API 0 — static-gate)
  badge: '[data-translation-missing]',
  langKo: '[data-note-lang="ko"]',
});

// ---- h-6 디자인 토큰 3계층(86-4 — 접두 --jt-ref- · --jt-sys- · --jt-comp- · 참조 방향 · 계산값 · dark에서 ref 불변) ----
// site-probe.ts가 페이지 안에서 판정해 돌려주는 꼴(수 · 불리언만)
export interface TokenLayers {
  refCount: number;
  sysCount: number;
  compCount: number;
  allResolve: boolean;
  sysRefsRefOrSys: boolean;
  sysChainExists: boolean;
  compAvoidsRef: boolean;
  compChainExists: boolean;
}

const LAYER_COUNTS = ['refCount', 'sysCount', 'compCount'] as const;
const LAYER_FLAGS = ['allResolve', 'sysRefsRefOrSys', 'sysChainExists', 'compAvoidsRef', 'compChainExists'] as const;

export function judgeTokenLayers(t: TokenLayers): SiteVerdict {
  const bad: string[] = [];
  for (const k of LAYER_COUNTS) if (!(typeof t[k] === 'number' && t[k] >= 1)) bad.push(k);
  for (const k of LAYER_FLAGS) if (t[k] !== true) bad.push(k);
  if (bad.length > 0) return product(`token-layers ${bad.sort().join(',')}`);
  return { ok: true, code: 'token-layers' };
}

// ---- h-9 prefetch 폭주 가드(web.md:17 · bff-api.md:101 — 로드 뒤 30 s · ≤ 10 · 하한 없음) ----
export const PREFETCH_LIMIT = 10;
export const PREFETCH_WINDOW_MS = 30_000;

export function judgePrefetch(n: number): SiteVerdict {
  if (!Number.isInteger(n) || n < 0) return product('prefetch-count-invalid');
  if (n > PREFETCH_LIMIT) return product(`prefetch-storm n=${n}`);
  return { ok: true, code: `prefetch n=${n}` };
}
