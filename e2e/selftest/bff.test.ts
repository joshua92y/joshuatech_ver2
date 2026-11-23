// e2e/selftest/bff.test.ts — T079 BFF 분류 표 · probe 판정 · 체인 · 쿠키 사본 · 기준선 · 로그아웃 · AC4 결정 상수 · 시간 창(설계 D7 · D12 ①b · r2 — A-2) selftest.
// 브라우저 0 · 네트워크 0. 값(표식 글자)은 시험 안에서 만들고, 판정 결과에 실리지 않는지 함께 본다.
import { test, expect } from '@playwright/test';
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  AC3_PROBE_DELAY_MS,
  AC3_SPAN_MS,
  AC4_PATH,
  AC4_PROBE_DELAY_MS,
  AC4_SPAN_MS,
  BFF_CSRF_COOKIE,
  BFF_PATHS,
  BFF_SESSION_COOKIE,
  CHAIN_ENV,
  CLOCK_SLACK_MS,
  CSRF_HEADER,
  DIAG_INTERVAL_MS,
  DIAG_LIMIT_MS,
  LOGOUT_BODY,
  PROBLEM_SESSION_REVOKED,
  WEBHOOK_GAP_MS,
  ac4Gate,
  classifyBffHealth,
  classifyBffHealthError,
  cookieHeader,
  diagnoseUntil,
  gapWaitMs,
  judgeLogout,
  judgeRevokedProbe,
  judgeSession,
  judgeTenantsMe,
  logoutHeaders,
  observeHttp,
  pickSessionCopies,
  pollUntil,
  probeHeaders,
  resolveChain,
  revocationWindow,
  type HttpObservation,
} from '../lib/bff';

const REPO = path.resolve(__dirname, '..', '..');
const JSON_CT = 'application/json';
const PROBLEM_CT = 'application/problem+json';
const HEALTH_OK = { status: 'ok', upstream: 'identity-admin', upstream_ms: 12, checks: { db: 'ok', dragonfly: 'ok' } };
const TRAEFIK_404_BODY = '404 page not found\n';

function marker(): string {
  return 'mk' + crypto.randomBytes(8).toString('hex');
}

function obs(status: number, contentType: string | null, body: unknown = ''): HttpObservation {
  const buf = Buffer.isBuffer(body) ? body : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body));
  return { status, contentType, body: buf };
}

// 판정 → 사람이 읽는 사유 글자('[prefix] code' 또는 PASS 코드)
function reason(v: { ok: boolean; code?: string; prefix?: string; layer?: string }): string {
  if (v.ok) return v.code ?? `layer=${v.layer}`;
  return `[${v.prefix}] ${v.code}`;
}

test('bff: chain table — dev = http://localhost:3000 · jt-dev · stage 1, prod = https://joshuatech.dev · jt-prod · stage 2 (D5)', () => {
  expect(CHAIN_ENV).toBe('JT_E2E_CHAIN');
  expect(resolveChain({ [CHAIN_ENV]: 'dev' })).toEqual({ ok: true, chain: 'dev', base: 'http://localhost:3000', ns: 'jt-dev', stage: 1 });
  expect(resolveChain({ [CHAIN_ENV]: 'prod' })).toEqual({ ok: true, chain: 'prod', base: 'https://joshuatech.dev', ns: 'jt-prod', stage: 2 });
});

test('bff: chain env missing or outside the table → [env] by name only (value never echoed)', () => {
  expect(reason(resolveChain({}))).toBe('[env] missing JT_E2E_CHAIN');
  expect(reason(resolveChain({ [CHAIN_ENV]: '' }))).toBe('[env] missing JT_E2E_CHAIN');
  for (const bad of ['Dev', 'PROD', 'staging', ' dev', 'dev ', 'constructor', '__proto__', 'toString', 'hasOwnProperty']) {
    expect(reason(resolveChain({ [CHAIN_ENV]: bad })), bad).toBe('[env] shape JT_E2E_CHAIN');
  }
  const m = marker();
  expect(JSON.stringify(resolveChain({ [CHAIN_ENV]: m })).includes(m)).toBe(false);
});

test('bff: paths are the contract routes (bff-api.md §엔드포인트 — health · login · callback · logout · session · proxy)', () => {
  expect(BFF_PATHS).toEqual({
    health: '/api/health',
    login: '/api/auth/login',
    callback: '/api/auth/callback',
    logout: '/api/auth/logout',
    session: '/api/session',
    tenantsMe: '/api/proxy/identity-admin/tenants/me',
  });
});

test('bff: observeHttp keeps status, content-type and body only', () => {
  const o = observeHttp({ status: 401, headers: { 'content-type': PROBLEM_CT, 'set-cookie': 'jt_session=x', 'x-request-id': 'r' }, body: Buffer.from('{}') });
  expect(Object.keys(o).sort()).toEqual(['body', 'contentType', 'status']);
  expect(o.status).toBe(401);
  expect(o.contentType).toBe(PROBLEM_CT);
  expect(observeHttp({ status: 204, headers: {}, body: Buffer.alloc(0) }).contentType).toBeNull();
});

test('bff: reach-bff 200 contract shape → PASS on both chains', () => {
  for (const chain of ['dev', 'prod'] as const) {
    expect(classifyBffHealth(chain, obs(200, JSON_CT, HEALTH_OK)), chain).toEqual({ ok: true, code: 'bff-health' });
    expect(classifyBffHealth(chain, obs(200, 'application/json; charset=utf-8', { upstream: 'identity-admin' })).ok, chain).toBe(true);
  }
});

test('bff: reach-bff dev connection refused → [env] dev-chain-server-absent (T092 · T085 · dev 서버 미기동)', () => {
  const v = classifyBffHealthError('dev', 'refused');
  expect(reason(v)).toBe('[env] dev-chain-server-absent');
  expect(v.ok === false ? v.note : undefined).toBe('T092 · T085 · dev 서버 미기동');
  // 그 밖의 요청 오류는 두 체인 모두 [env] network
  expect(reason(classifyBffHealthError('dev', 'timeout'))).toBe('[env] network (timeout)');
  expect(reason(classifyBffHealthError('dev', 'reset'))).toBe('[env] network (reset)');
  expect(reason(classifyBffHealthError('prod', 'refused'))).toBe('[env] network (refused)');
  expect(reason(classifyBffHealthError('prod', 'dns'))).toBe('[env] network (dns)');
});

test('bff: reach-bff 52x and other 5xx → [env] origin on both chains (same as reach)', () => {
  for (const chain of ['dev', 'prod'] as const) {
    for (const s of [500, 502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 530]) {
      expect(reason(classifyBffHealth(chain, obs(s, 'text/html', '<html>x</html>'))), `${chain} ${s}`).toBe(`[env] origin status=${s}`);
    }
  }
  // BFF가 만든 503 problem+json(upstream_unavailable)도 도달 단계에서는 오리진 쪽 부재다
  expect(reason(classifyBffHealth('dev', obs(503, PROBLEM_CT, { type: 'https://joshuatech.dev/problems/upstream-unavailable' })))).toBe('[env] origin status=503');
});

const NON_CONTRACT: HttpObservation[] = [
  obs(200, 'text/html; charset=utf-8', '<!doctype html><html><body>v1 site</body></html>'), // apex가 아직 v1
  obs(200, JSON_CT, { status: 'ok' }), // upstream 없음
  obs(200, JSON_CT, { status: 'ok', upstream: 'portfolio-core' }),
  obs(200, JSON_CT, '[1,2]'),
  obs(200, JSON_CT, 'not json'),
  obs(200, 'text/plain', JSON.stringify(HEALTH_OK)),
  obs(204, null, ''),
  obs(301, null, ''),
  obs(302, null, ''),
  obs(401, 'text/html', ''),
  obs(403, 'text/html', ''),
  obs(404, 'text/plain; charset=utf-8', TRAEFIK_404_BODY),
  obs(404, 'text/html', 'nf'),
];

test('bff: reach-bff prod non-contract response → [env] prod-chain-not-bff (apex still v1 included — T094 전)', () => {
  for (const o of NON_CONTRACT) {
    const v = classifyBffHealth('prod', o);
    expect(reason(v), `${o.status} ${o.contentType}`).toBe(`[env] prod-chain-not-bff status=${o.status}`);
    expect(v.ok === false ? v.note : undefined).toBe('T094 전');
  }
});

test('bff: reach-bff dev non-contract response → [product]', () => {
  for (const o of NON_CONTRACT) {
    expect(reason(classifyBffHealth('dev', o)), `${o.status} ${o.contentType}`).toBe(`[product] bff-health-unexpected status=${o.status}`);
  }
});

test('bff: reach-bff never yields [gate] on any branch (D5 — [gate] is Traefik 404 · Ingress · Job only)', () => {
  const statuses = [200, 201, 204, 301, 302, 304, 400, 401, 403, 404, 405, 429, 500, 502, 503, 520, 522, 525, 530];
  const cts = [null, 'text/plain; charset=utf-8', 'text/html', JSON_CT, PROBLEM_CT];
  const bodies = ['', TRAEFIK_404_BODY, JSON.stringify(HEALTH_OK), '{"upstream":"identity-admin"}'];
  let n = 0;
  for (const chain of ['dev', 'prod'] as const) {
    for (const s of statuses) {
      for (const ct of cts) {
        for (const b of bodies) {
          const v = classifyBffHealth(chain, obs(s, ct, b));
          if (!v.ok) expect(v.prefix, `${chain} ${s} ${ct}`).not.toBe('gate');
          n += 1;
        }
      }
    }
    for (const code of ['refused', 'reset', 'dns', 'timeout', 'tls', 'network', 'closed', 'error']) {
      const v = classifyBffHealthError(chain, code);
      expect(v.ok).toBe(false);
      if (!v.ok) expect(v.prefix, `${chain} ${code}`).not.toBe('gate');
    }
  }
  expect(n).toBe(2 * 19 * 5 * 4);
});

test('bff: probe 401 problem+json with type .../session-revoked → PASS; layer INFO from request_id presence', () => {
  expect(PROBLEM_SESSION_REVOKED).toBe('https://joshuatech.dev/problems/session-revoked');
  // pod 401을 BFF가 중계(bff-api.md:90 — 본문에 request_id 없음)
  expect(judgeRevokedProbe(obs(401, PROBLEM_CT, { type: PROBLEM_SESSION_REVOKED, title: 'Session revoked', status: 401 }))).toEqual({ ok: true, layer: 'pod-relay' });
  // BFF 자신의 401(폐기 확인 — request_id 있음)
  expect(judgeRevokedProbe(obs(401, 'application/problem+json; charset=utf-8', { type: PROBLEM_SESSION_REVOKED, status: 401, request_id: 'r-1' }))).toEqual({ ok: true, layer: 'bff' });
});

test('bff: probe type with the underscore slug → FAIL (a string match on session_revoked is not a PASS)', () => {
  for (const t of ['https://joshuatech.dev/problems/session_revoked', 'session_revoked', 'about:blank#session_revoked']) {
    expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, { type: t, request_id: 'r' }))), t).toBe('[product] probe-type-underscore');
    expect(judgeRevokedProbe(obs(401, PROBLEM_CT, { type: t })).ok, t).toBe(false);
  }
});

test('bff: probe other failures — status, media type, body, type', () => {
  expect(reason(judgeRevokedProbe(obs(200, JSON_CT, { tenant: { id: 'x' }, role: 'member' })))).toBe('[product] probe-not-revoked status=200');
  expect(reason(judgeRevokedProbe(obs(503, PROBLEM_CT, { type: 'https://joshuatech.dev/problems/upstream-unavailable' })))).toBe('[product] probe-not-revoked status=503');
  expect(reason(judgeRevokedProbe(obs(403, PROBLEM_CT, { type: 'https://joshuatech.dev/problems/access-required' })))).toBe('[product] probe-not-revoked status=403');
  expect(reason(judgeRevokedProbe(obs(401, JSON_CT, { type: PROBLEM_SESSION_REVOKED })))).toBe('[product] probe-media-type');
  expect(reason(judgeRevokedProbe(obs(401, 'text/html', '<html>401</html>')))).toBe('[product] probe-media-type');
  expect(reason(judgeRevokedProbe(obs(401, null, '')))).toBe('[product] probe-media-type');
  expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, 'not json')))).toBe('[product] probe-body-not-json');
  expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, '[]')))).toBe('[product] probe-body-not-json');
  expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, { title: 'x' })))).toBe('[product] probe-type-missing');
  expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, { type: 42 })))).toBe('[product] probe-type-missing');
  expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, { type: 'https://joshuatech.dev/problems/invalid-token' })))).toBe('[product] probe-type-mismatch');
  expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, { type: PROBLEM_SESSION_REVOKED + '/' })))).toBe('[product] probe-type-mismatch');
  expect(reason(judgeRevokedProbe(obs(401, PROBLEM_CT, { type: 'HTTPS://JOSHUATECH.DEV/problems/session-revoked' })))).toBe('[product] probe-type-mismatch');
});

test('bff: verdicts never carry response values (body, content-type, cookie values)', () => {
  const m = marker();
  const outs: unknown[] = [
    classifyBffHealth('dev', obs(200, JSON_CT, { upstream: m })),
    classifyBffHealth('dev', obs(200, m, '{}')),
    classifyBffHealth('prod', obs(200, 'text/html', m)),
    judgeRevokedProbe(obs(401, PROBLEM_CT, { type: m, request_id: m })),
    judgeRevokedProbe(obs(401, PROBLEM_CT, m)),
    judgeRevokedProbe(obs(401, m, '{}')),
    judgeTenantsMe(obs(200, JSON_CT, { tenant: { id: m }, role: m })),
    judgeSession(obs(200, JSON_CT, { sub: m })),
    judgeSession(obs(200, JSON_CT, m)),
    judgeLogout(obs(401, PROBLEM_CT, { type: m })),
  ];
  for (const o of outs) expect(JSON.stringify(o).includes(m)).toBe(false);
});

test('bff: session cookie copies are picked by name and chain host; values never enter a verdict', () => {
  const s = marker();
  const c = marker();
  const cookies = [
    { name: 'jt_session', value: s, domain: 'localhost' },
    { name: 'jt_csrf', value: c, domain: 'localhost' },
    { name: 'authentik_session', value: marker(), domain: 'auth.joshuatech.dev' },
  ];
  const r = pickSessionCopies(cookies, 'http://localhost:3000');
  expect(r.ok).toBe(true);
  if (r.ok) expect(r.copies).toEqual({ session: s, csrf: c });
  // prod — host-only 도메인 · 앞 점 도메인
  expect(pickSessionCopies([{ name: 'jt_session', value: s, domain: '.joshuatech.dev' }, { name: 'jt_csrf', value: c, domain: 'joshuatech.dev' }], 'https://joshuatech.dev').ok).toBe(true);
  // 다른 호스트의 쿠키는 사본이 아니다
  const other = pickSessionCopies([{ name: 'jt_session', value: s, domain: 'preview.joshuatech.dev' }, { name: 'jt_csrf', value: c, domain: 'localhost' }], 'http://localhost:3000');
  expect(reason(other)).toBe('[product] session-cookies-missing names=jt_session');
  expect(reason(pickSessionCopies([], 'http://localhost:3000'))).toBe('[product] session-cookies-missing names=jt_session,jt_csrf');
  // 빈 값은 없는 것과 같다
  const empty = pickSessionCopies([{ name: 'jt_session', value: '', domain: 'localhost' }, { name: 'jt_csrf', value: c, domain: 'localhost' }], 'http://localhost:3000');
  expect(reason(empty)).toBe('[product] session-cookies-missing names=jt_session');
  // 같은 이름이 둘이면 어느 사본인지 모른다
  const dup = pickSessionCopies([...cookies, { name: 'jt_session', value: marker(), domain: 'localhost' }], 'http://localhost:3000');
  expect(reason(dup)).toBe('[product] session-cookies-ambiguous names=jt_session');
  for (const v of [other, empty, dup]) {
    expect(JSON.stringify(v).includes(s)).toBe(false);
    expect(JSON.stringify(v).includes(c)).toBe(false);
  }
});

test('bff: probe and logout headers — explicit Cookie with both copies; CSRF header only on logout; body all_devices true', () => {
  const copies = { session: 'S1', csrf: 'C1' };
  expect(BFF_SESSION_COOKIE).toBe('jt_session');
  expect(BFF_CSRF_COOKIE).toBe('jt_csrf');
  expect(CSRF_HEADER).toBe('x-csrf-token');
  expect(cookieHeader(copies)).toBe('jt_session=S1; jt_csrf=C1');
  expect(probeHeaders(copies)).toEqual({ cookie: 'jt_session=S1; jt_csrf=C1' });
  expect(logoutHeaders(copies)).toEqual({ cookie: 'jt_session=S1; jt_csrf=C1', 'x-csrf-token': 'C1' });
  expect(LOGOUT_BODY).toEqual({ all_devices: true });
});

test('bff: baseline — /api/session 200 JSON object; /tenants/me 200 JSON with role member (T083 seed — FR-036)', () => {
  expect(judgeSession(obs(200, JSON_CT, { sub: 'x', tenant_id: 'y', email: 'e', name: 'n', exp: 1 }))).toEqual({ ok: true, code: 'session-active' });
  expect(reason(judgeSession(obs(401, PROBLEM_CT, { type: PROBLEM_SESSION_REVOKED })))).toBe('[product] baseline-session status=401');
  expect(reason(judgeSession(obs(503, PROBLEM_CT, {})))).toBe('[product] baseline-session status=503');
  expect(reason(judgeSession(obs(200, 'text/html', '<html></html>')))).toBe('[product] baseline-session-shape');
  expect(reason(judgeSession(obs(200, JSON_CT, 'x')))).toBe('[product] baseline-session-shape');
  const me = { tenant: { id: 'u', slug: 's', display_name: 'd', status: 'active' }, role: 'member' };
  expect(judgeTenantsMe(obs(200, JSON_CT, me))).toEqual({ ok: true, code: 'role=member' });
  expect(reason(judgeTenantsMe(obs(200, JSON_CT, { ...me, role: 'owner' })))).toBe('[product] baseline-role-not-member');
  expect(reason(judgeTenantsMe(obs(200, JSON_CT, { tenant: me.tenant })))).toBe('[product] baseline-role-not-member');
  expect(reason(judgeTenantsMe(obs(404, PROBLEM_CT, { type: 'https://joshuatech.dev/problems/not-found' })))).toBe('[product] baseline-tenants-me status=404');
  expect(reason(judgeTenantsMe(obs(200, 'text/html', JSON.stringify(me))))).toBe('[product] baseline-tenants-me-shape');
  expect(reason(judgeTenantsMe(obs(200, JSON_CT, '[]')))).toBe('[product] baseline-tenants-me-shape');
});

test('bff: logout 204 → PASS; anything else → [product] logout-unexpected status', () => {
  expect(judgeLogout(obs(204, null, ''))).toEqual({ ok: true, code: 'logout-204' });
  for (const s of [200, 302, 401, 403, 503]) {
    expect(reason(judgeLogout(obs(s, PROBLEM_CT, '{}'))), String(s)).toBe(`[product] logout-unexpected status=${s}`);
  }
});

test('bff: AC4 path constant is undecided until T081 (UD-4) → [decision]; authentik-logout opens the flow', () => {
  expect(AC4_PATH).toBe('undecided');
  expect(ac4Gate('undecided')).toEqual({ ok: false, prefix: 'decision', code: 'UD-4 undecided', note: 'AC4 path (user decision before T081)' });
  expect(ac4Gate('authentik-logout')).toEqual({ ok: true, code: 'authentik-logout' });
});

test('bff: timing — probe after 1 s (AC3) and 2 s (AC4); windows with a symmetric 2 s clock slack AC3 [t0-2 s, t0+10 s+2 s] and AC4 [t1-2 s, t1+2 s+2 s]; diag 500 ms up to 10 s (리뷰 A-8)', () => {
  expect(AC3_PROBE_DELAY_MS).toBe(1_000);
  expect(AC4_PROBE_DELAY_MS).toBe(2_000);
  expect(CLOCK_SLACK_MS).toBe(2_000);
  // pod 시계가 클라이언트보다 늦어도 거짓 reason-not-logged가 나지 않게 아래쪽에도 여유를 둔다 — 오프셋 기준(anchor)은 t0 · t1 그대로다
  expect(revocationWindow(1_000_000, AC3_SPAN_MS)).toEqual({ anchorMs: 1_000_000, startMs: 998_000, endMs: 1_012_000 });
  expect(revocationWindow(1_000_000, AC4_SPAN_MS)).toEqual({ anchorMs: 1_000_000, startMs: 998_000, endMs: 1_004_000 });
  expect(DIAG_INTERVAL_MS).toBe(500);
  expect(DIAG_LIMIT_MS).toBe(10_000);
});

test('bff: the diagnostic re-ask waits ≥ 500 ms after the missed probe before its first try (D7 — 리뷰 A-9)', async () => {
  let now = 10_000;
  const events: string[] = [];
  const clock = () => now;
  const wait = async (ms: number) => {
    events.push(`wait ${ms}`);
    now += ms;
  };
  let n = 0;
  const r = await diagnoseUntil(async () => {
    n += 1;
    events.push(`try ${n} at ${now}`);
    now += 50;
    return n >= 2;
  }, (v) => v, { sinceMs: 9_000, clock, wait });
  expect(events).toEqual(['wait 500', 'try 1 at 10500', 'wait 500', 'try 2 at 11050']);
  expect(r).toEqual({ value: true, tries: 2, doneAtMs: 11_100 });
  // 마감(sinceMs + 10 s)은 그대로 — 첫 재질문은 마감과 무관하게 한 번 돈다
  now = 30_000;
  events.length = 0;
  const r2 = await diagnoseUntil(async () => false, (v) => v, { sinceMs: 9_000, clock, wait });
  expect(events).toEqual(['wait 500']);
  expect(r2.tries).toBe(1);
  expect(r2.doneAtMs).toBeNull();
});

test('bff: webhook gap — wait out 15 s after the last Authentik logout; the full gap when it is unknown', () => {
  expect(WEBHOOK_GAP_MS).toBe(15_000);
  expect(gapWaitMs(100_000, undefined)).toBe(15_000);
  expect(gapWaitMs(100_000, 90_000)).toBe(5_000);
  expect(gapWaitMs(100_000, 85_000)).toBe(0);
  expect(gapWaitMs(100_000, 80_000)).toBe(0);
  expect(gapWaitMs(100_000, 99_000, 2_000)).toBe(1_000);
});

test('bff: pollUntil stops at the first success, or when the next try would pass the deadline (fake clock)', async () => {
  let now = 0;
  const waits: number[] = [];
  const clock = () => now;
  const wait = async (ms: number) => {
    waits.push(ms);
    now += ms;
  };
  let n = 0;
  const r = await pollUntil(async () => {
    n += 1;
    now += 100;
    return n >= 3;
  }, (v) => v, { deadlineMs: 10_000, intervalMs: 500, clock, wait });
  expect(r).toEqual({ value: true, tries: 3, doneAtMs: 1_300 });
  expect(waits).toEqual([500, 500]);

  now = 0;
  waits.length = 0;
  const r2 = await pollUntil(async () => {
    now += 100;
    return false;
  }, (v) => v, { deadlineMs: 2_000, intervalMs: 500, clock, wait });
  expect(r2).toEqual({ value: false, tries: 4, doneAtMs: null });
  expect(waits).toEqual([500, 500, 500]);

  // 첫 시도는 마감과 무관하게 한 번은 돈다
  now = 5_000;
  const r3 = await pollUntil(async () => 'x', () => false, { deadlineMs: 1_000, intervalMs: 500, clock, wait });
  expect(r3.tries).toBe(1);
});

test('bff: Authentik flow constants live in one module (lib/authentik-flow.ts) that both live specs import — no spec keeps its own copy (VD-T081-a)', () => {
  const read = (f: string) => fs.readFileSync(path.join(REPO, 'e2e', f), 'utf8');
  for (const spec of ['auth.spec.ts', 'revocation.spec.ts']) {
    const text = read(spec);
    expect(/from '\.\/lib\/authentik-flow'/.test(text), `${spec} imports lib/authentik-flow`).toBe(true);
    // 선택자 · 흐름 경로 글자를 spec이 따로 갖지 않는다(T081 스펙 상수 커밋이 한 곳만 고친다)
    for (const literal of ['uidField', 'input[name=', '/flows/-/default/invalidation/', '/if/flow/', 'authentik_session']) {
      expect(text.includes(literal), `${spec} has no literal ${literal}`).toBe(false);
    }
  }
  const lib = read('lib/authentik-flow.ts');
  for (const key of ['identifyInput', 'passwordInput', 'totpInput', 'submit', 'invalidation', 'userInterface', 'sessions']) {
    expect(new RegExp(`^\\s+${key}: '[^']+',?\\s*$`, 'm').test(lib), `lib/authentik-flow ${key}`).toBe(true);
  }
});
