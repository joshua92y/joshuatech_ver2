// e2e/selftest/reach.test.ts — reach 분류 표(설계 D6 reach · D12 ①a 필수 사례 r2 — A-2). 브라우저 0 · 네트워크 0.
import { test, expect } from '@playwright/test';
import { AUTH_ORIGIN, CONTROL_URL, REACH_URL, TRAEFIK_404, classifyReach, classifyReachError, hasAuthentikMarker, reachReason, type ReachObservation } from '../lib/reach';

const SIG: ReachObservation = {
  status: 404,
  contentType: 'text/plain; charset=utf-8',
  bodyLength: 19,
  bodySha256: TRAEFIK_404.sha256,
  cfCacheStatus: 'DYNAMIC',
  location: null,
  authentikMarker: false,
};

function reason(o: Partial<ReachObservation>): string {
  return reachReason(classifyReach({ ...SIG, ...o }));
}

test('reach: constants — fixed hosts and the T076 D10 Traefik 404 signature', () => {
  expect(AUTH_ORIGIN).toBe('https://auth.joshuatech.dev');
  expect(REACH_URL).toBe('https://auth.joshuatech.dev/');
  expect(CONTROL_URL).toBe('https://identity-m2m-dev.joshuatech.dev/health');
  expect(TRAEFIK_404.status).toBe(404);
  expect(TRAEFIK_404.contentType).toBe('text/plain; charset=utf-8');
  expect(TRAEFIK_404.length).toBe(19);
  expect(TRAEFIK_404.sha256).toBe('b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793');
});

test('reach: full Traefik 404 signature → [gate] authentik-absent until T080', () => {
  expect(reason({})).toBe('[gate] authentik-absent until T080');
  // cf-cache-status 없음도 ≠ HIT 이다
  expect(reason({ cfCacheStatus: null })).toBe('[gate] authentik-absent until T080');
  const v = classifyReach(SIG);
  expect(v.ok).toBe(false);
});

test('reach: 522 · 525 · 503 and other 5xx → [env] origin (not red evidence)', () => {
  for (const status of [521, 522, 523, 525, 526, 503, 500, 502, 520, 524, 530]) {
    const r = reason({ status, contentType: 'text/html', bodyLength: 4000, bodySha256: 'f'.repeat(64) });
    expect(r, String(status)).toBe(`[env] origin status=${status}`);
  }
});

test('reach: a 404 whose signature differs in any one field → [product] reach-unexpected, never [gate]', () => {
  const variants: Array<[Partial<ReachObservation>, string]> = [
    [{ bodyLength: 18 }, 'length'],
    [{ bodySha256: '0'.repeat(64) }, 'sha256'],
    [{ contentType: 'text/html' }, 'content-type'],
    [{ cfCacheStatus: 'HIT' }, 'cf-cache-status'],
    [{ cfCacheStatus: 'hit' }, 'cf-cache-status'],
  ];
  for (const [o, field] of variants) {
    const r = reason(o);
    expect(r, field).toBe(`[product] reach-unexpected status=404 mismatch=${field}`);
    expect(r.startsWith('[gate]'), field).toBe(false);
  }
  expect(reason({ bodyLength: 18, contentType: 'text/html' })).toBe('[product] reach-unexpected status=404 mismatch=content-type,length');
});

test('reach: Cloudflare Access 302 or 401 → [product] reach-access', () => {
  expect(reason({ status: 302, contentType: null, bodyLength: 0, bodySha256: '', location: 'https://joshua-tech.cloudflareaccess.com/cdn-cgi/access/login/auth.joshuatech.dev?kid=x&redirect_url=%2F' }))
    .toBe('[product] reach-access status=302');
  expect(reason({ status: 401, contentType: 'text/html', bodyLength: 100, bodySha256: 'a'.repeat(64) })).toBe('[product] reach-access status=401');
});

test('reach: Authentik category → PASS (same-host /if/ or /flows/ redirect, or 200 HTML with the marker)', () => {
  const r302 = classifyReach({ ...SIG, status: 302, contentType: null, bodyLength: 0, bodySha256: '', location: '/if/flow/default-authentication-flow/?next=%2F' });
  expect(r302).toEqual({ ok: true, code: 'authentik-redirect' });
  expect(reachReason(r302)).toBe('authentik-redirect');
  const abs = classifyReach({ ...SIG, status: 302, contentType: null, bodyLength: 0, bodySha256: '', location: 'https://auth.joshuatech.dev/flows/-/default/authentication/' });
  expect(abs).toEqual({ ok: true, code: 'authentik-redirect' });
  const page = classifyReach({ ...SIG, status: 200, contentType: 'text/html; charset=utf-8', bodyLength: 5000, bodySha256: 'b'.repeat(64), authentikMarker: true });
  expect(page).toEqual({ ok: true, code: 'authentik-page' });
});

test('reach: other redirects and pages are not Authentik', () => {
  const base = { contentType: null, bodyLength: 0, bodySha256: '' };
  expect(reason({ ...base, status: 302, location: 'https://evil.example/if/flow/x/' })).toBe('[product] reach-unexpected status=302');
  expect(reason({ ...base, status: 302, location: '//evil.example/if/flow/x/' })).toBe('[product] reach-unexpected status=302');
  expect(reason({ ...base, status: 302, location: '/somewhere/else' })).toBe('[product] reach-unexpected status=302');
  expect(reason({ ...base, status: 302, location: null })).toBe('[product] reach-unexpected status=302');
  expect(reason({ ...base, status: 301, location: '/if/flow/x/' })).toBe('[product] reach-unexpected status=301');
  expect(reason({ status: 200, contentType: 'text/html', bodyLength: 10, bodySha256: 'c'.repeat(64), authentikMarker: false })).toBe('[product] reach-unexpected status=200');
  expect(reason({ status: 200, contentType: 'application/json', bodyLength: 10, bodySha256: 'c'.repeat(64), authentikMarker: true })).toBe('[product] reach-unexpected status=200');
  expect(reason({ status: 403, contentType: 'text/html', bodyLength: 10, bodySha256: 'c'.repeat(64) })).toBe('[product] reach-unexpected status=403');
});

test('reach: request errors → [env] network with the sanitized code only', () => {
  expect(reachReason(classifyReachError('dns'))).toBe('[env] network (dns)');
  expect(reachReason(classifyReachError('timeout'))).toBe('[env] network (timeout)');
  expect(reachReason(classifyReachError('refused'))).toBe('[env] network (refused)');
});

test('reach: Authentik HTML marker is detected from the body without returning it', () => {
  expect(hasAuthentikMarker(Buffer.from('<html><body><ak-flow-executor></ak-flow-executor></body></html>'))).toBe(true);
  expect(hasAuthentikMarker(Buffer.from('<html><body><ak-interface-user></ak-interface-user></body></html>'))).toBe(true);
  expect(hasAuthentikMarker(Buffer.from('404 page not found\n'))).toBe(false);
});
