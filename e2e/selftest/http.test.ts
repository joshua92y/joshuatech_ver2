// e2e/selftest/http.test.ts — http 감싸개(설계 D10 ② · ④) selftest. 가짜 컨텍스트 · 가짜 페이지만 — 브라우저 0 · 네트워크 0.
import { test, expect } from '@playwright/test';
import * as crypto from 'node:crypto';
import { currentOriginPath, errorCode, freshGet, freshPost, guarded, httpGet, httpGetExpect, httpPost, navigate, originPath, safeError, safeErrorCode, waitForPath, withFreshContext } from '../lib/http';

function marker(): string {
  return 'mk' + crypto.randomBytes(8).toString('hex');
}

function leaky(message: string, name = 'Error'): Error {
  const e = new Error(message);
  e.name = name;
  return e;
}

async function thrown(p: Promise<unknown>): Promise<Error> {
  try {
    await p;
  } catch (e) {
    return e as Error;
  }
  throw new Error('expected a rejection');
}

function assertClean(e: Error, secret: string): void {
  expect(String(e.message).includes(secret)).toBe(false);
  expect(String(e.stack).includes(secret)).toBe(false);
  expect((e as { cause?: unknown }).cause).toBeUndefined();
}

test('http: originPath keeps only origin + pathname (no query, fragment or userinfo)', () => {
  expect(originPath('https://auth.joshuatech.dev/if/flow/x/?next=%2F&code=abc#frag')).toBe('https://auth.joshuatech.dev/if/flow/x/');
  expect(originPath('http://127.0.0.1:5123/nd-3?q=1')).toBe('http://127.0.0.1:5123/nd-3');
  expect(originPath('https://user:pass@auth.joshuatech.dev/p')).toBe('https://auth.joshuatech.dev/p');
  expect(originPath('not a url')).toBe('invalid-url');
  expect(originPath('file:///C:/x')).toBe('non-http-url');
});

test('http: errorCode maps Playwright/Node failures to a fixed word', () => {
  expect(errorCode(leaky('apiRequestContext.get: Timeout 1000ms exceeded.', 'TimeoutError'))).toBe('timeout');
  expect(errorCode(leaky('apiRequestContext.get: connect ECONNREFUSED 127.0.0.1:9'))).toBe('refused');
  expect(errorCode(leaky('apiRequestContext.get: socket hang up (ECONNRESET)'))).toBe('reset');
  // 응답 헤더 뒤 본문 도중 끊김(1.65.1 실측 — 리뷰 B-7) — 네트워크 오류다([product]가 아니라 [env] network)
  expect(errorCode(leaky('apiRequestContext.get: aborted'))).toBe('reset');
  expect(errorCode(leaky('apiRequestContext.fetch: aborted\nCall log:\n  - x'))).toBe('reset');
  // net::ERR_ABORTED(탐색)는 그대로 network다
  expect(errorCode(leaky('page.goto: net::ERR_ABORTED at https://h/'))).toBe('network');
  expect(errorCode(leaky('apiRequestContext.get: getaddrinfo ENOTFOUND x.invalid'))).toBe('dns');
  expect(errorCode(leaky('page.goto: net::ERR_CONNECTION_CLOSED at https://x/'))).toBe('network');
  expect(errorCode(leaky('page.goto: Target page, context or browser has been closed'))).toBe('closed');
  expect(errorCode(leaky('something else'))).toBe('error');
  expect(errorCode('not an error')).toBe('error');
  expect(errorCode(safeError('GET https://h/p failed (refused)', 'refused'))).toBe('refused');
});

test('http: safeError carries a fixed code and rejects a label with newline or non-ASCII', () => {
  const e = safeError('GET https://h/p failed (timeout)', 'timeout');
  expect(e.message).toBe('GET https://h/p failed (timeout)');
  expect(safeErrorCode(e)).toBe('timeout');
  expect(safeErrorCode(new Error('x'))).toBeUndefined();
  expect(safeError('a\nb', 'error').message).toBe('sanitized error (message rejected)');
  expect(safeError('한글', 'error').message).toBe('sanitized error (message rejected)');
});

test('http: guarded rethrows a new value-free error without cause', async () => {
  const secret = marker();
  const e = await thrown(guarded('submit password', async () => {
    throw leaky(`locator.click: Timeout\nCall log:\n  - cookie: ${secret}`, 'TimeoutError');
  }));
  expect(e.message).toBe('submit password failed (timeout)');
  assertClean(e, secret);
  expect(await guarded('ok step', async () => 7)).toBe(7);
});

test('http: httpGet never follows redirects by default, returns status/headers/body, sanitizes failures', async () => {
  const secret = marker();
  const calls: Array<{ url: string; opts: Record<string, unknown> }> = [];
  const ok = {
    get: async (url: string, opts: Record<string, unknown>) => {
      calls.push({ url, opts });
      return {
        status: () => 404,
        headers: () => ({ 'content-type': 'text/plain; charset=utf-8' }),
        body: async () => Buffer.from('x'),
        dispose: async () => undefined,
      };
    },
  };
  const res = await httpGet(ok as never, 'https://auth.joshuatech.dev/?a=1');
  expect(res.status).toBe(404);
  expect(res.headers['content-type']).toBe('text/plain; charset=utf-8');
  expect(res.body.length).toBe(1);
  expect(calls[0].opts.maxRedirects).toBe(0);
  expect(calls[0].opts.failOnStatusCode).toBe(false);
  expect(calls[0].opts.timeout).toBe(20_000);

  const bad = {
    get: async () => {
      throw leaky(`apiRequestContext.get: socket hang up (ECONNRESET)\nCall log:\n  - cookie: ${secret}\n  - authorization: ${secret}`);
    },
  };
  const e = await thrown(httpGet(bad as never, `https://auth.joshuatech.dev/p?code=${secret}`, { headers: { cookie: secret } }));
  expect(e.message).toBe('GET https://auth.joshuatech.dev/p failed (reset)');
  assertClean(e, secret);
});

test('http: httpGetExpect turns an unexpected status into a value-free failure', async () => {
  const ctx = {
    get: async () => ({ status: () => 500, headers: () => ({}), body: async () => Buffer.from('boom'), dispose: async () => undefined }),
  };
  const e = await thrown(httpGetExpect(ctx as never, 'http://127.0.0.1:5000/nd-4?x=1', 200));
  expect(e.message).toBe('GET http://127.0.0.1:5000/nd-4 failed (status 500)');
  const r = await httpGetExpect({ get: async () => ({ status: () => 200, headers: () => ({}), body: async () => Buffer.alloc(0), dispose: async () => undefined }) } as never, 'http://127.0.0.1:5000/ok', 200);
  expect(r.status).toBe(200);
});

test('http: navigate, waitForPath and currentOriginPath sanitize URLs', async () => {
  const secret = marker();
  const page = {
    goto: async () => {
      throw leaky(`page.goto: net::ERR_ABORTED\nCall log:\n  - navigating to "https://h/cb?code=${secret}"`);
    },
    waitForURL: async () => {
      throw leaky(`page.waitForURL: Timeout 10ms exceeded.\n  navigated to "https://h/cb?state=${secret}"`, 'TimeoutError');
    },
    url: () => `https://h/cb?code=${secret}`,
  };
  const e1 = await thrown(navigate(page as never, `https://h/cb?code=${secret}`));
  expect(e1.message).toBe('GOTO https://h/cb failed (network)');
  assertClean(e1, secret);
  const e2 = await thrown(waitForPath(page as never, 'https://h/never', { timeout: 10 }));
  expect(e2.message).toBe('WAIT https://h/never failed (timeout)');
  assertClean(e2, secret);
  expect(currentOriginPath(page as never)).toBe('https://h/cb');
});

test('http: navigate returns the response status when the navigation succeeds', async () => {
  const page = { goto: async () => ({ status: () => 200 }) };
  expect(await navigate(page as never, 'https://h/x')).toBe(200);
  const page2 = { goto: async () => null };
  expect(await navigate(page2 as never, 'https://h/x#frag')).toBeNull();
});

// --- T079 조각 ①b: BFF logout POST · probe 꼴(호출마다 새 요청 컨텍스트 + 명시 Cookie 헤더) — 설계 D7 probe 꼴 · D10 ② ---

function fakeResponse(status: number, headers: Record<string, string> = {}, body = '') {
  return { status: () => status, headers: () => headers, body: async () => Buffer.from(body), dispose: async () => undefined };
}

test('http: httpPost sends the data without following redirects and sanitizes failures (no value, no cause)', async () => {
  const secret = marker();
  const calls: Array<{ url: string; opts: Record<string, unknown> }> = [];
  const ok = {
    post: async (url: string, opts: Record<string, unknown>) => {
      calls.push({ url, opts });
      return fakeResponse(204);
    },
  };
  const res = await httpPost(ok as never, 'http://localhost:3000/api/auth/logout', { all_devices: true }, { headers: { cookie: secret, 'x-csrf-token': secret } });
  expect(res.status).toBe(204);
  expect(res.body.length).toBe(0);
  expect(calls[0].opts.maxRedirects).toBe(0);
  expect(calls[0].opts.failOnStatusCode).toBe(false);
  expect(calls[0].opts.timeout).toBe(20_000);
  expect(calls[0].opts.data).toEqual({ all_devices: true });
  expect(calls[0].opts.headers).toEqual({ cookie: secret, 'x-csrf-token': secret });

  const bad = {
    post: async () => {
      throw leaky(`apiRequestContext.post: connect ECONNREFUSED ::1:3000\nCall log:\n  - cookie: jt_session=${secret}\n  - x-csrf-token: ${secret}`);
    },
  };
  const e = await thrown(httpPost(bad as never, `http://localhost:3000/api/auth/logout?state=${secret}`, { all_devices: true }, { headers: { cookie: secret } }));
  expect(e.message).toBe('POST http://localhost:3000/api/auth/logout failed (refused)');
  assertClean(e, secret);
});

test('http: withFreshContext makes a new context per call and always disposes it; a factory failure is sanitized', async () => {
  const made: Array<{ disposed: boolean }> = [];
  const factory = async () => {
    const c = { disposed: false, dispose: async () => { c.disposed = true; } };
    made.push(c);
    return c as never;
  };
  expect(await withFreshContext(async () => 7, factory)).toBe(7);
  const e1 = await thrown(withFreshContext(async () => {
    throw safeError('GET http://localhost:3000/api/session failed (reset)', 'reset');
  }, factory));
  expect(e1.message).toBe('GET http://localhost:3000/api/session failed (reset)');
  expect(made.length).toBe(2);
  expect(made[0] === made[1]).toBe(false);
  expect(made.every((c) => c.disposed)).toBe(true);

  const secret = marker();
  const e2 = await thrown(withFreshContext(async () => 1, async () => {
    throw leaky(`apiRequest.newContext: proxy credentials ${secret}`);
  }));
  expect(e2.message).toBe('request context failed (error)');
  assertClean(e2, secret);
});

test('http: freshGet and freshPost run exactly one call in their own fresh context with the given headers', async () => {
  const seen: Array<[string, string, unknown, number]> = [];
  let n = 0;
  const factory = async () => {
    n += 1;
    const id = n;
    return {
      get: async (url: string, opts: Record<string, unknown>) => {
        seen.push(['GET', url, opts.headers, id]);
        return fakeResponse(401, { 'content-type': 'application/problem+json' }, '{"type":"x"}');
      },
      post: async (url: string, opts: Record<string, unknown>) => {
        seen.push(['POST', url, opts.headers, id]);
        return fakeResponse(204);
      },
      dispose: async () => undefined,
    } as never;
  };
  const g = await freshGet('http://localhost:3000/api/proxy/identity-admin/tenants/me', { headers: { cookie: 'jt_session=a; jt_csrf=b' } }, factory);
  expect(g.status).toBe(401);
  expect(g.headers['content-type']).toBe('application/problem+json');
  const p = await freshPost('http://localhost:3000/api/auth/logout', { all_devices: true }, { headers: { cookie: 'jt_session=a; jt_csrf=b', 'x-csrf-token': 'b' } }, factory);
  expect(p.status).toBe(204);
  expect(seen).toEqual([
    ['GET', 'http://localhost:3000/api/proxy/identity-admin/tenants/me', { cookie: 'jt_session=a; jt_csrf=b' }, 1],
    ['POST', 'http://localhost:3000/api/auth/logout', { cookie: 'jt_session=a; jt_csrf=b', 'x-csrf-token': 'b' }, 2],
  ]);
});
