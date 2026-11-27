// e2e/selftest/site.test.ts — T087 site 판정 표(설계 specs/003-platform-foundation/design/t086-design.md D10 ⑥ · D11 · D12) selftest. 브라우저 0 · 네트워크 0.
// 스캐폴드 유무 픽스처는 실행 중 outputDir(저장소 밖) 아래에 만든다. 값(표식 글자)은 시험 안에서 만들고 판정 결과에 실리지 않는지 함께 본다.
// 마지막 두 시험은 hello.spec.ts의 꼴을 고정한다: 시험 h-1–h-9 · reach 먼저(h-7 local만 reach 전 INFO + skip) · 스펙은 env를 읽지 않는다.
import { test, expect } from '@playwright/test';
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { envGuard } from '../global-setup';
import { BFF_PATHS } from '../lib/bff';
import type { HttpResult } from '../lib/http';
import { formatInfo } from '../lib/out';
import {
  EDGE_COOKIE_NAMES,
  HEALTH_DEGRADED_INFO,
  HEALTH_PATH,
  HEALTH_SKIP_INFO,
  LOCALES,
  NOTES,
  NOTE_SEL,
  NOTE_TAG,
  NOT_A_POD_PATH,
  PREFETCH_LIMIT,
  PREFETCH_WINDOW_MS,
  PROBLEM_NOT_FOUND,
  PROD_ORIGIN,
  REQUEST_ID_RE,
  ROOT_CASES,
  SCAFFOLD_FILE,
  SITE_ABSENT_CODE,
  SITE_ABSENT_NOTE,
  SITE_MARKER,
  SITE_MARKER_SELECTOR,
  classifySiteReach,
  classifySiteReachError,
  cookieNames,
  judgeCookieNames,
  judgeHealth,
  judgeLocale,
  judgeNotFound,
  judgePrefetch,
  judgeRootRedirect,
  judgeSetCookie,
  judgeTokenLayers,
  observeSite,
  scaffoldPresent,
  siteErrorVerdict,
  validateSiteTarget,
  type SiteMode,
  type TokenLayers,
} from '../lib/site';

const REPO = path.resolve(__dirname, '..', '..');
const HTML = 'text/html; charset=utf-8';
const JSON_CT = 'application/json';
const PROBLEM_CT = 'application/problem+json';
const LOCAL = 'http://127.0.0.1:3000';
const GUARD = '[guard] site-target-not-allowed';

function marker(): string {
  return 'mk' + crypto.randomBytes(8).toString('hex');
}

function res(status: number, headers: Record<string, string> = {}, body: unknown = ''): HttpResult {
  const buf = Buffer.isBuffer(body) ? body : Buffer.from(typeof body === 'string' ? body : JSON.stringify(body));
  return { status, headers, body: buf };
}

// 판정 → 사람이 읽는 사유 글자('[prefix] code' 또는 PASS 코드)
function reason(v: { ok: boolean; code?: string; prefix?: string }): string {
  return v.ok ? (v.code ?? '') : `[${v.prefix}] ${v.code}`;
}

const V2_PAGE = `<!doctype html><html lang="ko" ${SITE_MARKER}><body>v2</body></html>`;

test('site: constants — prod origin, locales, v2 marker, scaffold file, edge cookie names (VD-T087-4), problem type, paths, prefetch guard', () => {
  expect(PROD_ORIGIN).toBe('https://joshuatech.dev');
  expect([...LOCALES]).toEqual(['ko', 'en', 'ja']);
  expect(SITE_MARKER).toBe('data-jt-app="web"');
  expect(SITE_MARKER_SELECTOR).toBe('[data-jt-app="web"]');
  expect(SCAFFOLD_FILE).toBe('apps/web/next.config.ts');
  expect([...EDGE_COOKIE_NAMES].sort()).toEqual(['__cf_bm', '__cflb', '_cfuvid', 'cf_clearance']);
  expect(PROBLEM_NOT_FOUND).toBe('https://joshuatech.dev/problems/not-found');
  expect(NOT_A_POD_PATH).toBe('/api/proxy/not-a-pod/x');
  // BFF 경로는 T079 상수를 다시 쓴다(bff-api.md §엔드포인트)
  expect(HEALTH_PATH).toBe(BFF_PATHS.health);
  expect(HEALTH_PATH).toBe('/api/health');
  expect(PREFETCH_LIMIT).toBe(10);
  expect(PREFETCH_WINDOW_MS).toBe(30_000);
  expect(HEALTH_SKIP_INFO).toBe('T087 health skipped mode=local');
  expect(SITE_ABSENT_CODE).toBe('site-absent until T091');
  expect(SITE_ABSENT_NOTE).toBe('loopback refused and apps/web scaffold absent (next.config.ts)');
});

test('site: x-request-id shape = pod 수락 꼴 ^[A-Za-z0-9._:-]{1,128}$ (bff-api.md:3)', () => {
  for (const ok of [crypto.randomUUID(), 'a', 'A.b_c:d-e', 'x'.repeat(128)]) expect(REQUEST_ID_RE.test(ok), ok).toBe(true);
  for (const bad of ['', 'x'.repeat(129), 'a b', 'a/b', 'a\nb', 'a;b', String.fromCharCode(0xac00)]) expect(REQUEST_ID_RE.test(bad), JSON.stringify(bad)).toBe(false);
});

test('site: target allowlist — local = http://127.0.0.1:<port> | http://localhost:<port> (origin only), prod = exactly https://joshuatech.dev (D10 ①)', () => {
  const allowed: Array<[string, SiteMode]> = [
    ['http://127.0.0.1:3000', 'local'],
    ['http://localhost:3000', 'local'],
    ['http://127.0.0.1:1', 'local'],
    ['http://localhost:65535', 'local'],
    ['https://joshuatech.dev', 'prod'],
  ];
  for (const [base, mode] of allowed) expect(validateSiteTarget(base, mode), `${base} ${mode}`).toEqual({ ok: true, base, mode });
});

test('site: anything else → [guard] site-target-not-allowed, the value never echoed (preview is behind Access — not an automatic target)', () => {
  const rejected: Array<[unknown, unknown]> = [
    // local 꼴 변형 — 경로 · 끝 슬래시 · 질의 · 조각 · 스킴 · 다른 루프백 · 포트 없음/범위 밖/앞 0/기본값 · 사용자 정보 · 대문자 · 공백
    ['http://127.0.0.1:3000/', 'local'],
    ['http://127.0.0.1:3000/ko', 'local'],
    ['http://127.0.0.1:3000?x=1', 'local'],
    ['http://127.0.0.1:3000#x', 'local'],
    ['https://127.0.0.1:3000', 'local'],
    ['http://127.0.0.2:3000', 'local'],
    ['http://0.0.0.0:3000', 'local'],
    ['http://[::1]:3000', 'local'],
    ['http://localhost', 'local'],
    ['http://127.0.0.1', 'local'],
    ['http://127.0.0.1:0', 'local'],
    ['http://127.0.0.1:65536', 'local'],
    ['http://127.0.0.1:03000', 'local'],
    ['http://localhost:80', 'local'],
    ['http://user@127.0.0.1:3000', 'local'],
    ['HTTP://LOCALHOST:3000', 'local'],
    ['http://localhost.:3000', 'local'],
    [' http://127.0.0.1:3000', 'local'],
    ['http://127.0.0.1:3000 ', 'local'],
    ['http://joshuatech.dev:3000', 'local'],
    // 모드와 대상이 어긋남
    ['https://joshuatech.dev', 'local'],
    [LOCAL, 'prod'],
    // prod 꼴 변형
    ['https://joshuatech.dev/', 'prod'],
    ['https://www.joshuatech.dev', 'prod'],
    ['http://joshuatech.dev', 'prod'],
    ['https://preview.joshuatech.dev', 'prod'],
    ['https://joshuatech.dev:443', 'prod'],
    ['https://JOSHUATECH.dev', 'prod'],
    ['https://joshuatech.dev/ko', 'prod'],
    // 모드 값
    [LOCAL, 'Local'],
    [LOCAL, 'PROD'],
    [LOCAL, ''],
    [LOCAL, 'preview'],
    [LOCAL, 'dev'],
    [LOCAL, '__proto__'],
    [LOCAL, 'constructor'],
    [LOCAL, undefined],
    [LOCAL, null],
    [LOCAL, 1],
    // 대상 값
    [undefined, 'local'],
    [null, 'local'],
    ['', 'local'],
    [3000, 'local'],
  ];
  for (const [base, mode] of rejected) expect(reason(validateSiteTarget(base, mode)), `${String(base)} ${String(mode)}`).toBe(GUARD);
  const m = marker();
  for (const v of [validateSiteTarget(`http://${m}:3000`, 'local'), validateSiteTarget(LOCAL, m), validateSiteTarget(`https://${m}.joshuatech.dev`, 'prod')]) {
    expect(JSON.stringify(v).includes(m)).toBe(false);
  }
});

test('site: reach table (D11) — 200 text/html with the v2 marker → PASS site-v2 on both modes', () => {
  for (const mode of ['local', 'prod'] as const) {
    expect(classifySiteReach(mode, observeSite(res(200, { 'content-type': HTML }, V2_PAGE))), mode).toEqual({ ok: true, code: 'site-v2' });
    expect(classifySiteReach(mode, observeSite(res(200, { 'content-type': 'text/html' }, V2_PAGE))).ok, mode).toBe(true);
  }
  expect(observeSite(res(200, { 'content-type': HTML }, V2_PAGE))).toEqual({ status: 200, contentType: HTML, marker: true });
  expect(observeSite(res(204))).toEqual({ status: 204, contentType: null, marker: false });
});

test('site: reach table (D11) — local: anything else that answered → [product] reach-unexpected status=<n>', () => {
  const cases: HttpResult[] = [
    res(200, { 'content-type': HTML }, '<!doctype html><html><body>v1 site</body></html>'), // 표식 없음
    res(200, { 'content-type': JSON_CT }, `{"x":"${SITE_MARKER}"}`), // 표식은 있지만 HTML 아님
    res(302, { location: '/ko' }),
    res(404, { 'content-type': 'text/plain' }, 'nf'),
    res(500, { 'content-type': HTML }, V2_PAGE),
    res(503, { 'content-type': PROBLEM_CT }, '{}'),
  ];
  for (const r of cases) expect(reason(classifySiteReach('local', observeSite(r))), String(r.status)).toBe(`[product] reach-unexpected status=${r.status}`);
});

test('site: reach table (D11) — prod: 52x/5xx → [env] origin, other answers (v1 before T094) → [env] prod-site-not-v2', () => {
  for (const s of [500, 502, 503, 504, 520, 521, 522, 523, 524, 525, 526, 530]) {
    expect(reason(classifySiteReach('prod', observeSite(res(s, { 'content-type': HTML }, '<html>x</html>')))), String(s)).toBe(`[env] origin status=${s}`);
  }
  for (const r of [res(200, { 'content-type': HTML }, '<!doctype html><html><body>v1 site</body></html>'), res(302, { location: '/x' }), res(401), res(403), res(404)]) {
    const v = classifySiteReach('prod', observeSite(r));
    expect(reason(v), String(r.status)).toBe(`[env] prod-site-not-v2 status=${r.status}`);
    expect(v.ok === false ? v.note : undefined).toBe('T094 전');
  }
});

test('site: reach errors (D11) — local refused + no scaffold → [gate] site-absent until T091; refused + scaffold → [env] site-server-not-running; others → [env] network', () => {
  const gate = classifySiteReachError('local', 'refused', false);
  expect(reason(gate)).toBe('[gate] site-absent until T091');
  expect(gate.ok === false ? gate.note : undefined).toBe(SITE_ABSENT_NOTE);
  expect(reason(classifySiteReachError('local', 'refused', true))).toBe('[env] site-server-not-running');
  for (const code of ['timeout', 'reset', 'dns', 'tls', 'network', 'closed', 'error']) {
    for (const scaffold of [false, true]) {
      expect(reason(classifySiteReachError('local', code, scaffold)), `${code} ${scaffold}`).toBe(`[env] network (${code})`);
      expect(reason(classifySiteReachError('prod', code, scaffold)), `${code} ${scaffold}`).toBe(`[env] network (${code})`);
    }
  }
  // prod 거부는 구현 부재 증거가 아니다 — [gate]는 루프백 거부 + 스캐폴드 없음뿐
  expect(reason(classifySiteReachError('prod', 'refused', false))).toBe('[env] network (refused)');
  expect(reason(classifySiteReachError('prod', 'refused', true))).toBe('[env] network (refused)');
});

test('site: [gate] never comes out of an answered request (any status, content type, body, mode)', () => {
  let n = 0;
  for (const mode of ['local', 'prod'] as const) {
    for (const s of [200, 204, 301, 302, 304, 307, 400, 401, 403, 404, 405, 429, 500, 502, 503, 520, 522, 530]) {
      for (const ct of [null, 'text/plain; charset=utf-8', HTML, JSON_CT, PROBLEM_CT]) {
        for (const body of ['', V2_PAGE, '404 page not found\n']) {
          const v = classifySiteReach(mode, observeSite(res(s, ct === null ? {} : { 'content-type': ct }, body)));
          if (!v.ok) expect(v.prefix, `${mode} ${s} ${ct}`).not.toBe('gate');
          n += 1;
        }
      }
    }
  }
  expect(n).toBe(2 * 18 * 5 * 3);
});

test('site: scaffoldPresent() looks for the apps/web/next.config.ts file (fixtures generated in the output dir)', ({}, testInfo) => {
  const root = testInfo.outputPath('scaffold');
  fs.mkdirSync(path.join(root, 'apps', 'web'), { recursive: true });
  fs.writeFileSync(path.join(root, 'apps', 'web', 'package.json'), '{}\n');
  expect(scaffoldPresent(root)).toBe(false);
  fs.writeFileSync(path.join(root, 'apps', 'web', 'next.config.ts'), 'export default {};\n');
  expect(scaffoldPresent(root)).toBe(true);
  // 같은 이름의 디렉터리는 파일이 아니다
  const dirRoot = testInfo.outputPath('scaffold-dir');
  fs.mkdirSync(path.join(dirRoot, 'apps', 'web', 'next.config.ts'), { recursive: true });
  expect(scaffoldPresent(dirRoot)).toBe(false);
  expect(scaffoldPresent(testInfo.outputPath('no-such-root'))).toBe(false);
  // 픽스처는 저장소 밖에 있다
  const rel = path.relative(REPO, root);
  expect(rel.startsWith('..') || path.isAbsolute(rel)).toBe(true);
});

test('site: request errors after reach → [env] network for network codes, else [product] <step>-failed (<code>)', () => {
  for (const code of ['dns', 'refused', 'reset', 'network', 'tls']) expect(reason(siteErrorVerdict('h-3', code)), code).toBe(`[env] network (${code})`);
  for (const code of ['timeout', 'closed', 'error', 'status-500']) expect(reason(siteErrorVerdict('h-3', code)), code).toBe(`[product] h-3-failed (${code})`);
});

test('site: h-1 locale page — 200 text/html with the marker; status, media type and marker failures name the path only', () => {
  expect(judgeLocale('/ko', res(200, { 'content-type': HTML }, V2_PAGE))).toEqual({ ok: true, code: 'locale' });
  expect(reason(judgeLocale('/en', res(404, { 'content-type': HTML }, V2_PAGE)))).toBe('[product] locale status=404 path=/en');
  expect(reason(judgeLocale('/ja', res(200, { 'content-type': JSON_CT }, V2_PAGE)))).toBe('[product] locale-media-type path=/ja');
  expect(reason(judgeLocale('/ko', res(200, { 'content-type': HTML }, '<html>v1</html>')))).toBe('[product] locale-marker path=/ko');
  const m = marker();
  expect(JSON.stringify(judgeLocale('/ko', res(200, { 'content-type': m }, m))).includes(m)).toBe(false);
});

test('site: cookieNames — names of RFC 6265 tokens only, the rest counted as unparsable; values never kept', () => {
  expect(cookieNames(undefined)).toEqual({ names: [], unparsable: 0 });
  expect(cookieNames('')).toEqual({ names: [], unparsable: 0 });
  expect(cookieNames('a=1; Path=/')).toEqual({ names: ['a'], unparsable: 0 });
  // Playwright APIResponse.headers()는 여러 Set-Cookie를 줄바꿈으로 잇는다(selftest-browser site-probe가 실측으로 고정)
  expect(cookieNames('__Host-jt_session=v; Path=/; Secure; HttpOnly\n__Host-jt_csrf=w; Path=/')).toEqual({ names: ['__Host-jt_session', '__Host-jt_csrf'], unparsable: 0 });
  expect(cookieNames(' b = 2')).toEqual({ names: ['b'], unparsable: 0 });
  for (const bad of ['noequals', '=v', 'bad name=v', 'a(b=v', 'a,b=v', `n${String.fromCharCode(0xe9)}=v`]) {
    expect(cookieNames(bad), JSON.stringify(bad)).toEqual({ names: [], unparsable: 1 });
  }
  expect(cookieNames('ok=1\nbad name=2\n\n__cf_bm=3')).toEqual({ names: ['ok', '__cf_bm'], unparsable: 1 });
  const m = marker();
  expect(JSON.stringify(cookieNames(`a=${m}; Path=/\nb=${m}`)).includes(m)).toBe(false);
});

test('site: Set-Cookie — local: none at all; prod: only edge cookie names (INFO), any app or unparsable cookie fails (86-5)', () => {
  const sc = (v?: string) => res(200, v === undefined ? {} : { 'set-cookie': v });
  expect(judgeSetCookie('local', '/ko', sc())).toEqual({ ok: true, edge: [] });
  expect(reason(judgeSetCookie('local', '/ko', sc('__cf_bm=x; Path=/')))).toBe('[product] set-cookie n=1 path=/ko');
  expect(reason(judgeSetCookie('local', '/', sc('a=1\nb=2')))).toBe('[product] set-cookie n=2 path=/');
  expect(reason(judgeSetCookie('local', '/ko', sc('bad name=1')))).toBe('[product] set-cookie n=1 path=/ko');
  expect(judgeSetCookie('prod', '/ko', sc())).toEqual({ ok: true, edge: [] });
  expect(judgeSetCookie('prod', '/ko', sc('_cfuvid=y; Path=/\n__cf_bm=x; Path=/'))).toEqual({ ok: true, edge: ['__cf_bm', '_cfuvid'] });
  expect(reason(judgeSetCookie('prod', '/ko', sc('__Host-jt_session=x; Path=/')))).toBe('[product] set-cookie n=1 path=/ko');
  expect(reason(judgeSetCookie('prod', '/ja', sc('__cf_bm=x\njt_theme=dark')))).toBe('[product] set-cookie n=1 path=/ja');
  expect(reason(judgeSetCookie('prod', '/ko', sc('__cf_bm=x\nbad name=1')))).toBe('[product] set-cookie n=1 path=/ko');
  const m = marker();
  for (const v of [judgeSetCookie('local', '/ko', sc(`a=${m}`)), judgeSetCookie('prod', '/ko', sc(`__cf_bm=${m}\nx=${m}`))]) expect(JSON.stringify(v).includes(m)).toBe(false);
});

test('site: browser cookies after the visits — local: zero; prod: edge names only', () => {
  expect(judgeCookieNames('local', '/ko,/en,/ja', [])).toEqual({ ok: true, edge: [] });
  expect(reason(judgeCookieNames('local', '/ko,/en,/ja', ['__cf_bm']))).toBe('[product] browser-cookies n=1 path=/ko,/en,/ja');
  expect(judgeCookieNames('prod', '/ko,/en,/ja', ['cf_clearance', '__cf_bm', '__cf_bm'])).toEqual({ ok: true, edge: ['__cf_bm', 'cf_clearance'] });
  expect(reason(judgeCookieNames('prod', '/ko,/en,/ja', ['__cf_bm', '__Host-jt_session', 'a b']))).toBe('[product] browser-cookies n=2 path=/ko,/en,/ja');
});

test('site: / redirect cases (D11 h-4) — seven Accept-Language cases, no header → /ko', () => {
  expect(ROOT_CASES.map((c) => [c.id, c.acceptLanguage, c.expect])).toEqual([
    ['r1', 'ko', '/ko'],
    ['r2', 'ko-KR,ko;q=0.9,en;q=0.8', '/ko'],
    ['r3', 'en-US,en;q=0.9', '/en'],
    ['r4', 'ja,en;q=0.5', '/ja'],
    ['r5', null, '/ko'],
    ['r6', 'fr-FR,fr;q=0.9', '/ko'],
    ['r7', 'fr, en;q=0.5, ja;q=0.8', '/ja'],
  ]);
});

test('site: / redirect judgement — 302 only, Location resolved against the base must be the same origin + the expected pathname', () => {
  const r1 = ROOT_CASES[0];
  const r3 = ROOT_CASES[2];
  expect(judgeRootRedirect(LOCAL, r1, res(302, { location: '/ko' }))).toEqual({ ok: true, code: 'root-redirect' });
  expect(judgeRootRedirect(LOCAL, r1, res(302, { location: `${LOCAL}/ko` })).ok).toBe(true);
  expect(judgeRootRedirect(LOCAL, r1, res(302, { location: '/ko?from=root' })).ok).toBe(true);
  expect(judgeRootRedirect(LOCAL, r3, res(302, { location: '/en' })).ok).toBe(true);
  expect(judgeRootRedirect('https://joshuatech.dev', r1, res(302, { location: 'https://joshuatech.dev/ko' })).ok).toBe(true);
  for (const s of [200, 301, 303, 307, 308, 404, 500]) {
    expect(reason(judgeRootRedirect(LOCAL, r1, res(s, { location: '/ko' }))), String(s)).toBe(`[product] root-redirect status=${s} case=r1`);
  }
  for (const loc of ['/en', '/ko/', '/', 'http://localhost:3000/ko', '//evil.example/ko', 'https://127.0.0.1:3000/ko', 'http://[', '']) {
    expect(reason(judgeRootRedirect(LOCAL, r1, res(302, { location: loc }))), loc).toBe('[product] root-location case=r1');
  }
  expect(reason(judgeRootRedirect(LOCAL, r1, res(302)))).toBe('[product] root-location case=r1');
  const m = marker();
  expect(JSON.stringify(judgeRootRedirect(LOCAL, r1, res(302, { location: `/${m}` }))).includes(m)).toBe(false);
});

test('site: h-7 /api/health — 200 JSON {status ok | degraded, upstream identity-admin, upstream_ms number} + x-request-id; each failure has its own code', () => {
  const rid = crypto.randomUUID();
  const good = { status: 'ok', upstream: 'identity-admin', upstream_ms: 12, checks: { db: 'ok' } };
  const h = (o: Record<string, string> = {}) => ({ 'content-type': JSON_CT, 'x-request-id': rid, ...o });
  expect(judgeHealth(res(200, h(), good))).toEqual({ ok: true, code: 'health', degraded: false });
  expect(judgeHealth(res(200, h({ 'content-type': 'application/json; charset=utf-8' }), { ...good, upstream_ms: 0 })).ok).toBe(true);
  expect(reason(judgeHealth(res(503, h({ 'content-type': PROBLEM_CT }), { type: 'https://joshuatech.dev/problems/upstream-unavailable' })))).toBe('[product] health status=503');
  expect(reason(judgeHealth(res(200, h({ 'content-type': HTML }), good)))).toBe('[product] health-media-type');
  expect(reason(judgeHealth(res(200, h(), '[1]')))).toBe('[product] health-body');
  expect(reason(judgeHealth(res(200, h(), 'not json')))).toBe('[product] health-body');
  // status는 계약 값 ok · degraded뿐이다(bff-api.md GET /api/health 행 — C17: 그 밖이면 BFF는 503) — 200에 실린 다른 값 · 대소문자 변형 · 빈 값 · 다른 형 · 없음은 [product]
  for (const s of ['down', 'error', 'OK', 'Degraded', 'ok ', '', null, 0, true]) {
    expect(reason(judgeHealth(res(200, h(), { ...good, status: s }))), String(s)).toBe('[product] health-status-field');
  }
  const noStatus: Record<string, unknown> = { ...good };
  delete noStatus.status;
  expect(reason(judgeHealth(res(200, h(), noStatus)))).toBe('[product] health-status-field');
  expect(reason(judgeHealth(res(200, h(), { ...good, upstream: 'portfolio-core' })))).toBe('[product] health-upstream');
  const noUpstream: Record<string, unknown> = { ...good };
  delete noUpstream.upstream;
  expect(reason(judgeHealth(res(200, h(), noUpstream)))).toBe('[product] health-upstream');
  for (const ms of ['12', -1, null, true]) expect(reason(judgeHealth(res(200, h(), { ...good, upstream_ms: ms }))), String(ms)).toBe('[product] health-upstream-ms');
  const noMs: Record<string, unknown> = { ...good };
  delete noMs.upstream_ms;
  expect(reason(judgeHealth(res(200, h(), noMs)))).toBe('[product] health-upstream-ms');
  expect(reason(judgeHealth(res(200, { 'content-type': JSON_CT }, good)))).toBe('[product] request-id-header');
  expect(reason(judgeHealth(res(200, h({ 'x-request-id': 'a b' }), good)))).toBe('[product] request-id-header');
  const m = marker();
  expect(JSON.stringify(judgeHealth(res(200, h({ 'x-request-id': m }), { ...good, upstream: m }))).includes(m)).toBe(false);
});

test('site: h-7 status degraded is a contract value (C17) — PASS with degraded=true, announced only by the value-free INFO line; the other checks still apply (review A-2)', () => {
  const rid = crypto.randomUUID();
  const degraded = { status: 'degraded', upstream: 'identity-admin', upstream_ms: 12, checks: { db: { status: 'degraded', latency_ms: 3 } } };
  const h = (o: Record<string, string> = {}) => ({ 'content-type': JSON_CT, 'x-request-id': rid, ...o });
  expect(judgeHealth(res(200, h(), degraded))).toEqual({ ok: true, code: 'health', degraded: true });
  // spec(h-7)이 내는 줄 — 우리 상수뿐(상류 값 · 본문 글자 0)
  expect(HEALTH_DEGRADED_INFO).toBe('health-status degraded');
  expect(formatInfo(HEALTH_DEGRADED_INFO)).toBe('INFO health-status degraded');
  // degraded여도 나머지 판정은 그대로다
  expect(reason(judgeHealth(res(503, h({ 'content-type': PROBLEM_CT }), degraded)))).toBe('[product] health status=503');
  expect(reason(judgeHealth(res(200, h({ 'content-type': HTML }), degraded)))).toBe('[product] health-media-type');
  expect(reason(judgeHealth(res(200, h(), { ...degraded, upstream: 'portfolio-core' })))).toBe('[product] health-upstream');
  expect(reason(judgeHealth(res(200, h(), { ...degraded, upstream_ms: '12' })))).toBe('[product] health-upstream-ms');
  expect(reason(judgeHealth(res(200, { 'content-type': JSON_CT }, degraded)))).toBe('[product] request-id-header');
  // 판정 결과에는 불리언만 — 본문 · 헤더 값 0
  const m = marker();
  expect(JSON.stringify(judgeHealth(res(200, h({ 'x-request-id': m }), { ...degraded, checks: { [m]: { status: m, latency_ms: 1 } } }))).includes(m)).toBe(false);
});

test('site: h-8 proxy not-found — 404 problem+json, type not-found, request_id = x-request-id, nosniff (bff-api.md:36 · :87 · :90 — C26)', () => {
  const rid = crypto.randomUUID();
  const body = { type: PROBLEM_NOT_FOUND, title: 'Not found', status: 404, request_id: rid };
  const h = (o: Record<string, string> = {}) => ({ 'content-type': PROBLEM_CT, 'x-request-id': rid, 'x-content-type-options': 'nosniff', ...o });
  expect(judgeNotFound(res(404, h(), body))).toEqual({ ok: true, code: 'problem=not-found' });
  expect(judgeNotFound(res(404, h({ 'content-type': 'application/problem+json; charset=utf-8', 'x-content-type-options': 'NoSniff' }), body)).ok).toBe(true);
  for (const s of [200, 401, 403, 405, 503]) expect(reason(judgeNotFound(res(s, h(), body))), String(s)).toBe(`[product] proxy-not-found status=${s}`);
  expect(reason(judgeNotFound(res(404, h({ 'content-type': JSON_CT }), body)))).toBe('[product] proxy-not-found-media-type');
  expect(reason(judgeNotFound(res(404, h({ 'content-type': 'text/plain; charset=utf-8' }), '404 page not found\n')))).toBe('[product] proxy-not-found-media-type');
  expect(reason(judgeNotFound(res(404, h(), 'x')))).toBe('[product] proxy-not-found-body');
  expect(reason(judgeNotFound(res(404, h(), '[]')))).toBe('[product] proxy-not-found-body');
  expect(reason(judgeNotFound(res(404, h(), { ...body, type: 'https://joshuatech.dev/problems/not_found' })))).toBe('[product] proxy-not-found-type');
  const noType: Record<string, unknown> = { ...body };
  delete noType.type;
  expect(reason(judgeNotFound(res(404, h(), noType)))).toBe('[product] proxy-not-found-type');
  const noHeader: Record<string, string> = h();
  delete noHeader['x-request-id'];
  expect(reason(judgeNotFound(res(404, noHeader, body)))).toBe('[product] request-id-header');
  expect(reason(judgeNotFound(res(404, h({ 'x-request-id': 'x'.repeat(129) }), { ...body, request_id: 'x'.repeat(129) })))).toBe('[product] request-id-header');
  const noRid: Record<string, unknown> = { ...body };
  delete noRid.request_id;
  expect(reason(judgeNotFound(res(404, h(), noRid)))).toBe('[product] request-id-mismatch');
  expect(reason(judgeNotFound(res(404, h(), { ...body, request_id: crypto.randomUUID() })))).toBe('[product] request-id-mismatch');
  const noSniff: Record<string, string> = h();
  delete noSniff['x-content-type-options'];
  expect(reason(judgeNotFound(res(404, noSniff, body)))).toBe('[product] nosniff');
  expect(reason(judgeNotFound(res(404, h({ 'x-content-type-options': 'sniff' }), body)))).toBe('[product] nosniff');
  const m = marker();
  expect(JSON.stringify(judgeNotFound(res(404, h({ 'x-request-id': m }), { ...body, type: m, request_id: m }))).includes(m)).toBe(false);
});

const LAYERS_OK: TokenLayers = {
  refCount: 3,
  sysCount: 3,
  compCount: 2,
  allResolve: true,
  sysRefsRefOrSys: true,
  sysChainExists: true,
  compAvoidsRef: true,
  compChainExists: true,
};

test('site: h-6 token layers — counts ≥ 1 and every boolean true (86-4); a failure lists the failing fields', () => {
  expect(judgeTokenLayers(LAYERS_OK)).toEqual({ ok: true, code: 'token-layers' });
  for (const k of Object.keys(LAYERS_OK) as Array<keyof TokenLayers>) {
    const bad = { ...LAYERS_OK, [k]: typeof LAYERS_OK[k] === 'number' ? 0 : false };
    expect(reason(judgeTokenLayers(bad)), k).toBe(`[product] token-layers ${k}`);
  }
  expect(reason(judgeTokenLayers({ ...LAYERS_OK, refCount: 0, allResolve: false, compAvoidsRef: false }))).toBe('[product] token-layers allResolve,compAvoidsRef,refCount');
  expect(reason(judgeTokenLayers({ ...LAYERS_OK, sysCount: Number.NaN }))).toBe('[product] token-layers sysCount');
});

test('site: h-9 prefetch guard — n ≤ 10 passes (no lower bound), > 10 → [product] prefetch-storm (web.md:17)', () => {
  for (const n of [0, 1, 10]) expect(judgePrefetch(n), String(n)).toEqual({ ok: true, code: `prefetch n=${n}` });
  expect(reason(judgePrefetch(11))).toBe('[product] prefetch-storm n=11');
  expect(reason(judgePrefetch(40))).toBe('[product] prefetch-storm n=40');
  for (const n of [-1, 1.5, Number.NaN, Number.POSITIVE_INFINITY]) expect(reason(judgePrefetch(n)), String(n)).toBe('[product] prefetch-count-invalid');
});

test('site: notes 001 · 002 — slug = file name, pubDate and the claude-code tag match content/study frontmatter (independent constants)', () => {
  expect(NOTES).toEqual([
    { slug: '001-claude-setup', pubDate: '2026-08-26' },
    { slug: '002-smoke', pubDate: '2026-08-27' },
  ]);
  expect(NOTE_TAG).toBe('claude-code');
  for (const n of NOTES) {
    const text = fs.readFileSync(path.join(REPO, 'content', 'study', `${n.slug}.mdx`), 'utf8');
    const fm = text.split(/^---$/m)[1] ?? '';
    expect(new RegExp(`^pubDate: ${n.pubDate}$`, 'm').test(fm), `${n.slug} pubDate`).toBe(true);
    expect(/^tags: \[.*"claude-code".*\]$/m.test(fm), `${n.slug} tag`).toBe(true);
  }
});

test('site: selectors for h-2 · h-5 (data attributes only — the badge is judged by attribute, never by text)', () => {
  expect(NOTE_SEL.any).toBe('[data-note-slug]');
  expect(NOTE_SEL.note('001-claude-setup')).toBe('[data-note-slug="001-claude-setup"]');
  expect(NOTE_SEL.title).toBe('[data-note-title]');
  expect(NOTE_SEL.time('2026-08-26')).toBe('time[datetime="2026-08-26"]');
  expect(NOTE_SEL.tag).toBe('[data-note-tag="claude-code"]');
  expect(NOTE_SEL.badge).toBe('[data-translation-missing]');
  expect(NOTE_SEL.langKo).toBe('[data-note-lang="ko"]');
});

test('site: globalSetup env guard lets JT_E2E_SITE · BASE_URL · JT_E2E_SITE_MODE through (D10 ②)', () => {
  expect(envGuard({ JT_E2E_SITE: '1', BASE_URL: LOCAL, JT_E2E_SITE_MODE: 'local' })).toEqual([]);
  expect(envGuard({ JT_E2E_SITE: '1', BASE_URL: 'https://joshuatech.dev', JT_E2E_SITE_MODE: 'prod' })).toEqual([]);
});

function helloText(): string {
  return fs.readFileSync(path.join(REPO, 'e2e', 'hello.spec.ts'), 'utf8');
}

function testBodies(text: string): Array<{ id: string; body: string }> {
  const at: Array<{ id: string; index: number }> = [];
  const re = /\btest\('(h-\d+) /g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(text)) !== null) at.push({ id: m[1], index: m.index });
  return at.map((a, i) => ({ id: a.id, body: text.slice(a.index, i + 1 < at.length ? at[i + 1].index : text.length) }));
}

test('site: hello.spec.ts declares h-1 … h-9 once each; every test validates the target, then reaches before any assertion (D12 — absence only means something after reach)', () => {
  const bodies = testBodies(helloText());
  expect(bodies.map((b) => b.id)).toEqual(['h-1', 'h-2', 'h-3', 'h-4', 'h-5', 'h-6', 'h-7', 'h-8', 'h-9']);
  const after = ['await get(', 'await open(', 'checkSetCookie(', 'startPrefetchCounter(', 'probeTokenLayers(', 'refStableUnderDark(', 'countOf('];
  for (const { id, body } of bodies) {
    const tgt = body.indexOf('target(testInfo, baseURL)');
    const reachAt = body.indexOf('await reach(site)');
    expect(tgt > 0, `${id} target`).toBe(true);
    expect(reachAt > tgt, `${id} reach after target`).toBe(true);
    for (const a of after) {
      const i = body.indexOf(a);
      if (i !== -1) expect(i > reachAt, `${id} ${a} after reach`).toBe(true);
    }
  }
  // h-7 local만 reach 전에 INFO + skip(allowed-skip 줄 — 런처가 센다)
  const h7 = bodies[6].body;
  const reach7 = h7.indexOf('await reach(site)');
  for (const a of ["site.mode === 'local'", 'emitInfo(HEALTH_SKIP_INFO)', 'test.skip(']) {
    const i = h7.indexOf(a);
    expect(i > 0 && i < reach7, `h-7 ${a} before reach`).toBe(true);
  }
  for (const { id, body } of bodies.filter((b) => b.id !== 'h-7')) expect(body.includes('test.skip('), `${id} never skips`).toBe(false);
});

test('site: hello.spec.ts h-7 announces degraded with the value-free INFO constant only, after the verdict passed and before the PASS step (review A-2)', () => {
  const h7 = testBodies(helloText()).find((b) => b.id === 'h-7')?.body ?? '';
  const reachAt = h7.indexOf('await reach(site)');
  const judgeAt = h7.indexOf('judgeHealth(');
  const stopAt = h7.indexOf("if (!v.ok) stop('h-7', v);");
  const infoAt = h7.indexOf('if (v.degraded) emitInfo(HEALTH_DEGRADED_INFO);');
  const passAt = h7.indexOf("emitStep(TASK, 'h-7', 'PASS'");
  expect(reachAt > 0 && judgeAt > reachAt, 'judgeHealth after reach').toBe(true);
  expect(stopAt > judgeAt, 'a failed verdict stops first').toBe(true);
  expect(infoAt > stopAt && infoAt < passAt, 'degraded INFO after the verdict, before PASS').toBe(true);
  // h-7의 INFO는 local skip 줄과 이 줄 둘뿐(degraded를 다른 꼴 · 값으로 내지 않는다)
  expect(h7.split('emitInfo(').length - 1, 'emitInfo calls in h-7').toBe(2);
});

test('site: hello.spec.ts reads no env — mode and target come from project metadata and the baseURL fixture (D10 ②)', () => {
  const text = helloText();
  expect(text.includes('process.env')).toBe(false);
  expect(text.includes('jtSiteMode')).toBe(true);
});
