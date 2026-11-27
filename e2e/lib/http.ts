// e2e/lib/http.ts — http · 탐색 감싸개(설계 D10 ② · ④ · r1 — B-1 · 컨트롤러 N-4). APIRequestContext 호출 · 탐색 · URL 대기 · URL 읽기는 여기만 지난다(static-gate).
// 예외면 '<METHOD> <origin+pathname> failed (<코드|status N>)'만 담은 새 오류로 다시 던지고 cause를 잇지 않는다 —
// Playwright call log(요청 · 응답 헤더 · 쿠키 · 탐색 URL)가 실패 메시지 · error-context에 실리지 않게 한다. toBeOK 금지 — 상태는 수로 비교한다.
import { request, type APIRequestContext, type Page } from '@playwright/test';
import { pace } from './pace';

const SAFE_MESSAGE = /^[\x20-\x7e]+$/;
const CODE_KEY = Symbol.for('jt.e2e.safe-code');

export interface HttpResult {
  status: number;
  headers: Record<string, string>;
  body: Buffer;
}

export interface GetOptions {
  maxRedirects?: number;
  timeout?: number;
  headers?: Record<string, string>;
}

// 값 없는 오류 — 메시지는 인쇄 가능한 ASCII 한 줄만, cause 없음. 코드는 기호 속성으로 붙인다.
export function safeError(message: string, code: string): Error {
  const e = new Error(SAFE_MESSAGE.test(message) ? message : 'sanitized error (message rejected)');
  Object.defineProperty(e, CODE_KEY, { value: code, enumerable: false });
  return e;
}

export function safeErrorCode(e: unknown): string | undefined {
  if (e instanceof Error) {
    const v = (e as unknown as Record<symbol, unknown>)[CODE_KEY];
    return typeof v === 'string' ? v : undefined;
  }
  return undefined;
}

export function originPath(raw: string): string {
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    return 'invalid-url';
  }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') return 'non-http-url';
  return u.origin + u.pathname;
}

// 원래 오류의 메시지는 고정 낱말을 고르는 데만 쓰고 어디에도 옮기지 않는다.
export function errorCode(e: unknown): string {
  const known = safeErrorCode(e);
  if (known) return known;
  if (!(e instanceof Error)) return 'error';
  if (e.name === 'TimeoutError') return 'timeout';
  const m = String(e.message);
  if (/ECONNREFUSED/.test(m)) return 'refused';
  // 'aborted' = 응답 헤더 뒤 본문 도중 끊김(1.65.1 APIRequestContext 실측 — 빌드 리뷰 r1 — B-7). 탐색의 net::ERR_ABORTED(대문자)는 아래 network다.
  if (/ECONNRESET|socket hang up|EPIPE|\baborted\b/.test(m)) return 'reset';
  if (/ENOTFOUND|EAI_AGAIN/.test(m)) return 'dns';
  if (/ETIMEDOUT|Timeout \d+ms exceeded/.test(m)) return 'timeout';
  if (/has been closed|Target closed/.test(m)) return 'closed';
  if (/net::ERR_/.test(m)) return 'network';
  if (/CERT_|certificate|SSL routines|TLS/.test(m)) return 'tls';
  return 'error';
}

function checkLabel(label: string): void {
  if (!/^[A-Za-z0-9][A-Za-z0-9 ._:/-]*$/.test(label)) throw safeError('guarded: label rejected', 'error');
}

// 페이지 동작(클릭 · 표식 대기 등) 감싸개 — 실패하면 '<label> failed (<코드>)'만 남긴다.
export async function guarded<T>(label: string, fn: () => Promise<T>): Promise<T> {
  checkLabel(label);
  try {
    return await fn();
  } catch (e) {
    const code = errorCode(e);
    throw safeError(`${label} failed (${code})`, code);
  }
}

export async function httpGet(ctx: APIRequestContext, url: string, opts: GetOptions = {}): Promise<HttpResult> {
  const label = `GET ${originPath(url)}`;
  await pace();
  let res: Awaited<ReturnType<APIRequestContext['get']>> | undefined;
  try {
    res = await ctx.get(url, {
      maxRedirects: opts.maxRedirects ?? 0,
      timeout: opts.timeout ?? 20_000,
      headers: opts.headers,
      failOnStatusCode: false,
    });
    const body = await res.body();
    return { status: res.status(), headers: res.headers(), body };
  } catch (e) {
    const code = errorCode(e);
    throw safeError(`${label} failed (${code})`, code);
  } finally {
    if (res) await res.dispose().catch(() => undefined);
  }
}

export async function httpGetExpect(ctx: APIRequestContext, url: string, expected: number, opts: GetOptions = {}): Promise<HttpResult> {
  const r = await httpGet(ctx, url, opts);
  if (r.status !== expected) throw safeError(`GET ${originPath(url)} failed (status ${r.status})`, `status-${r.status}`);
  return r;
}

// T079(조각 ①b) — BFF logout 같은 상태 변경 호출. 리다이렉트 미추적 · 실패는 '<POST> <origin+pathname> failed (<코드>)'만 남긴다(httpGet과 같은 규칙).
export async function httpPost(ctx: APIRequestContext, url: string, data: unknown, opts: GetOptions = {}): Promise<HttpResult> {
  const label = `POST ${originPath(url)}`;
  await pace();
  let res: Awaited<ReturnType<APIRequestContext['post']>> | undefined;
  try {
    res = await ctx.post(url, {
      data,
      maxRedirects: opts.maxRedirects ?? 0,
      timeout: opts.timeout ?? 20_000,
      headers: opts.headers,
      failOnStatusCode: false,
    });
    const body = await res.body();
    return { status: res.status(), headers: res.headers(), body };
  } catch (e) {
    const code = errorCode(e);
    throw safeError(`${label} failed (${code})`, code);
  } finally {
    if (res) await res.dispose().catch(() => undefined);
  }
}

// probe 꼴(설계 D7 — r1 — A-17 · A-13 ⓑ): 호출마다 새 요청 컨텍스트를 만들고 쓰고 나면 버린다. 쿠키는 jar가 아니라 호출자가 주는 명시 Cookie 헤더로만 싣는다 —
// 명시 cookie 헤더가 있으면 Playwright는 jar를 보지 않는다(1.65.1 fetch _updateRequestCookieHeader). 응답의 쿠키 삭제는 버려지는 컨텍스트에만 닿는다.
export type ContextFactory = () => Promise<APIRequestContext>;

export const defaultContextFactory: ContextFactory = () => request.newContext({ ignoreHTTPSErrors: false });

export async function withFreshContext<T>(fn: (ctx: APIRequestContext) => Promise<T>, factory: ContextFactory = defaultContextFactory): Promise<T> {
  let ctx: APIRequestContext;
  try {
    ctx = await factory();
  } catch (e) {
    const code = errorCode(e);
    throw safeError(`request context failed (${code})`, code);
  }
  try {
    return await fn(ctx);
  } finally {
    await ctx.dispose().catch(() => undefined);
  }
}

export function freshGet(url: string, opts: GetOptions = {}, factory?: ContextFactory): Promise<HttpResult> {
  return withFreshContext((ctx) => httpGet(ctx, url, opts), factory);
}

export function freshPost(url: string, data: unknown, opts: GetOptions = {}, factory?: ContextFactory): Promise<HttpResult> {
  return withFreshContext((ctx) => httpPost(ctx, url, data, opts), factory);
}

export async function navigate(page: Page, url: string, opts: { timeout?: number } = {}): Promise<number | null> {
  const label = `GOTO ${originPath(url)}`;
  await pace();
  try {
    const r = await page.goto(url, { timeout: opts.timeout, waitUntil: 'load' });
    return r ? r.status() : null;
  } catch (e) {
    const code = errorCode(e);
    throw safeError(`${label} failed (${code})`, code);
  }
}

// 쿼리를 보지 않는다 — origin + pathname이 같거나(prefix면 그것으로 시작하면) 도착으로 본다.
export async function waitForPath(page: Page, target: string, opts: { timeout?: number; prefix?: boolean } = {}): Promise<void> {
  const want = originPath(target);
  const label = `WAIT ${want}`;
  try {
    await page.waitForURL((u) => {
      const got = u.origin + u.pathname;
      return opts.prefix ? got.startsWith(want) : got === want;
    }, { timeout: opts.timeout, waitUntil: 'load' });
  } catch (e) {
    const code = errorCode(e);
    throw safeError(`${label} failed (${code})`, code);
  }
}

// 현재 페이지 URL을 읽는 유일한 helper — origin + pathname만 돌려준다.
export function currentOriginPath(page: Page): string {
  return originPath(page.url());
}
