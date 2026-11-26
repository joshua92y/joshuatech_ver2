// e2e/selftest-browser/site-probe.test.ts — T087 lib/site-probe.ts(토큰 3계층 · dark ref 불변 · prefetch 계수기)와 freshGet 헤더 동작(VD-T087-1)의 시험
// (설계 specs/003-platform-foundation/design/t086-design.md D10 ⑤ · ⑦ · D12). 로컬 node:http(127.0.0.1) 흉내 서버만 — 공개 호스트 0 · 자격 0.
// 헤더 이름 양성 대조(Next-Router-Prefetch: 1을 실제로 세는지)는 여기서 한다 — h-9의 「≤ 10」이 헤더 이름 오타로 공허하게 통과하지 않게(D12 T087 행).
import { test, expect } from '../lib/test-base';
import type { Page } from '@playwright/test';
import * as http from 'node:http';
import type { AddressInfo } from 'node:net';
import { freshGet, guarded, navigate } from '../lib/http';
import { cookieNames, type TokenLayers } from '../lib/site';
import { probeTokenLayers, refStableUnderDark, startPrefetchCounter } from '../lib/site-probe';

// 토큰 CSS — ref(원시 값) → sys(의미 · 테마) → comp(컴포넌트 슬롯). dark는 sys만 다시 잇는다(web.md:53–:54).
const REF = '--jt-ref-blue-500: #2563eb; --jt-ref-gray-50: #f9fafb; --jt-ref-gray-900: #111827;';
const SYS = '--jt-sys-accent: var(--jt-ref-blue-500); --jt-sys-surface: var(--jt-ref-gray-50); --jt-sys-on-surface: var(--jt-ref-gray-900);';
const COMP = '--jt-comp-button-bg: var(--jt-sys-accent); --jt-comp-card-bg: var(--jt-sys-surface);';
const DARK_SYS = '@media (prefers-color-scheme: dark) { :root { --jt-sys-surface: var(--jt-ref-gray-900); --jt-sys-on-surface: var(--jt-ref-gray-50); } }';
// :root 밖 선언은 세지도 판정하지도 않는다(컴포넌트 선택자 안의 ref 참조 포함)
const ELSEWHERE = '.card { --jt-comp-card-shadow: var(--jt-ref-gray-900); }';

const TOKEN_CSS: Record<string, string> = {
  ok: `:root { ${REF} ${SYS} ${COMP} } ${DARK_SYS} ${ELSEWHERE}`,
  'ref-missing': `:root { ${SYS} ${COMP} } ${DARK_SYS}`,
  'ref-partial': `:root { ${REF} ${SYS} --jt-sys-border: var(--jt-ref-gray-300); ${COMP} } ${DARK_SYS}`,
  'comp-ref': `:root { ${REF} ${SYS} ${COMP} --jt-comp-link-fg: var(--jt-ref-blue-500); } ${DARK_SYS}`,
  'comp-zero': `:root { ${REF} ${SYS} } ${DARK_SYS}`,
  'sys-comp': `:root { ${REF} ${SYS} ${COMP} --jt-sys-focus: var(--jt-comp-button-bg); } ${DARK_SYS}`,
  'dark-ref': `:root { ${REF} ${SYS} ${COMP} } ${DARK_SYS} @media (prefers-color-scheme: dark) { :root { --jt-ref-blue-500: #60a5fa; } }`,
};

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

// prefetch 흉내 페이지 — load 때 n개(Next-Router-Prefetch: 1) + plain개(헤더 없음) + 1개(값 0)를 같은 origin에 보내고 끝나면 #done.
// #more를 누를 때마다 5개(값 1)를 더 보내고 끝나면 #more-<k>.
function prefetchPage(): string {
  const script = [
    'const q = new URLSearchParams(location.search);',
    "const n = Number(q.get('n') || 0);",
    "const plain = Number(q.get('plain') || 0);",
    "const go = (k, h) => Array.from({ length: k }, (_, i) => fetch('/rsc?i=' + i + '&r=' + Math.random(), { headers: h }));",
    "const mark = (id) => { const p = document.createElement('p'); p.id = id; document.body.appendChild(p); };",
    "Promise.all([...go(n, { 'Next-Router-Prefetch': '1' }), ...go(plain, {}), ...go(plain > 0 ? 1 : 0, { 'Next-Router-Prefetch': '0' })]).then(() => mark('done'));",
    'let k = 0;',
    "document.getElementById('more').addEventListener('click', () => { k += 1; const id = 'more-' + k; Promise.all(go(5, { 'Next-Router-Prefetch': '1' })).then(() => mark(id)); });",
  ].join('\n');
  return `<!doctype html><html><head><meta charset="utf-8"><title>prefetch</title></head><body><button id="more" type="button">more</button><script>${script}</script></body></html>`;
}

function html(res: http.ServerResponse, body: string): void {
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
  res.end(body);
}

interface Emu {
  base: string;
  acceptLanguage: string | null; // 마지막 /echo가 받은 accept-language('absent' = 없음 · null = 아직 없음)
}

const ft = test.extend<{ emu: Emu }>({
  emu: async ({}, use) => {
    const state: Emu = { base: '', acceptLanguage: null };
    const server = http.createServer((req, res) => {
      const route = new URL(req.url ?? '/', 'http://127.0.0.1').pathname;
      req.resume();
      if (route.startsWith('/tokens/')) {
        const css = TOKEN_CSS[route.slice('/tokens/'.length)];
        if (css !== undefined) return html(res, `<!doctype html><html><head><meta charset="utf-8"><style>${css}</style></head><body><p id="t">tokens</p></body></html>`);
      }
      if (route === '/prefetch') return html(res, prefetchPage());
      if (route === '/rsc') {
        res.writeHead(200, { 'content-type': 'text/plain', 'cache-control': 'no-store' });
        return void res.end('x');
      }
      if (route === '/echo') {
        const al = req.headers['accept-language'];
        state.acceptLanguage = typeof al === 'string' ? al : 'absent';
        res.writeHead(204);
        return void res.end();
      }
      if (route === '/two-cookies') {
        res.writeHead(200, { 'content-type': 'text/plain', 'set-cookie': ['a_one=1; Path=/', 'b_two=2; Path=/; HttpOnly'] });
        return void res.end('ok');
      }
      res.writeHead(404, { 'content-type': 'text/plain' });
      res.end('none');
    });
    await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
    state.base = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
    await use(state);
    server.closeAllConnections();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  },
});

async function open(page: Page, emu: Emu, path: string): Promise<void> {
  expect(await navigate(page, emu.base + path), path).toBe(200);
}

async function marker(page: Page, id: string): Promise<void> {
  await guarded(`marker ${id}`, () => page.locator(`#${id}`).waitFor({ state: 'attached', timeout: 5_000 }));
}

ft('site-probe: tokens — the normal three-layer page passes every field (dark media declarations counted, :root only) and ref stays put under dark', async ({ page, emu }) => {
  await open(page, emu, '/tokens/ok');
  expect(await probeTokenLayers(page)).toEqual(LAYERS_OK);
  expect(await refStableUnderDark(page)).toBe(true);
  // 판정 뒤 라이트로 돌아온다 — 다시 재도 같다
  expect(await probeTokenLayers(page)).toEqual(LAYERS_OK);
});

const VARIANTS: Array<[string, Partial<TokenLayers>, boolean]> = [
  // ref가 하나도 없으면 sys 계산값이 비어(해석 불가 — VD-T087-2) allResolve가 거짓이고, 비교할 ref가 없으니 dark 불변도 공허하게 참이 되지 않는다
  ['ref-missing', { refCount: 0, allResolve: false, sysChainExists: false }, false],
  ['ref-partial', { sysCount: 4, allResolve: false }, true],
  ['comp-ref', { compCount: 3, compAvoidsRef: false }, true],
  ['comp-zero', { compCount: 0, compChainExists: false }, true],
  ['sys-comp', { sysCount: 4, sysRefsRefOrSys: false }, true],
  ['dark-ref', {}, false],
];

ft('site-probe: tokens — each broken variant fails exactly its own fields (ref missing · unresolved sys · comp → ref · comp 0 · sys → comp · ref changed under dark)', async ({ page, emu }) => {
  for (const [variant, diff, stable] of VARIANTS) {
    await open(page, emu, `/tokens/${variant}`);
    expect(await probeTokenLayers(page), variant).toEqual({ ...LAYERS_OK, ...diff });
    expect(await refStableUnderDark(page), `${variant} dark`).toBe(stable);
  }
});

ft('site-probe: return shapes — counts are numbers, the rest booleans; the counter exposes stop() only', async ({ page, emu }) => {
  await open(page, emu, '/tokens/ok');
  const t = await probeTokenLayers(page);
  expect(Object.keys(t).sort()).toEqual(['allResolve', 'compAvoidsRef', 'compChainExists', 'compCount', 'refCount', 'sysChainExists', 'sysCount', 'sysRefsRefOrSys']);
  for (const k of ['refCount', 'sysCount', 'compCount'] as const) expect(typeof t[k], k).toBe('number');
  for (const k of ['allResolve', 'sysRefsRefOrSys', 'sysChainExists', 'compAvoidsRef', 'compChainExists'] as const) expect(typeof t[k], k).toBe('boolean');
  expect(typeof (await refStableUnderDark(page))).toBe('boolean');
  const c = startPrefetchCounter(page);
  expect(Object.keys(c)).toEqual(['stop']);
  expect(typeof c.stop()).toBe('number');
});

ft('site-probe: prefetch counter counts Next-Router-Prefetch: 1 requests only — 3 → 3, 11 → 11, none → 0', async ({ page, emu }) => {
  const cases: Array<[number, number]> = [
    [3, 2],
    [11, 0],
    [0, 4],
  ];
  for (const [n, plain] of cases) {
    const c = startPrefetchCounter(page);
    await open(page, emu, `/prefetch?n=${n}&plain=${plain}`);
    await marker(page, 'done');
    expect(c.stop(), `n=${n} plain=${plain}`).toBe(n);
  }
});

ft('site-probe: requests outside the counting window are not counted — before start and after stop', async ({ page, emu }) => {
  await open(page, emu, '/prefetch?n=2&plain=0');
  await marker(page, 'done');
  // load 때의 2개는 시작 전이다
  const c = startPrefetchCounter(page);
  await guarded('click more', () => page.locator('#more').click({ timeout: 5_000 }));
  await marker(page, 'more-1');
  expect(c.stop()).toBe(5);
  // 멈춘 뒤의 5개는 세지 않는다(다시 불러도 같은 수)
  await guarded('click more', () => page.locator('#more').click({ timeout: 5_000 }));
  await marker(page, 'more-2');
  expect(c.stop()).toBe(5);
  // 새 계수기는 0부터 센다
  const d = startPrefetchCounter(page);
  await guarded('click more', () => page.locator('#more').click({ timeout: 5_000 }));
  await marker(page, 'more-3');
  expect(d.stop()).toBe(5);
});

ft('freshGet sends no accept-language unless the caller gives one (VD-T087-1 — the h-4 no-header case → /ko)', async ({ emu }) => {
  await freshGet(`${emu.base}/echo`);
  expect(emu.acceptLanguage).toBe('absent');
  await freshGet(`${emu.base}/echo`, { headers: { 'accept-language': 'ko' } });
  expect(emu.acceptLanguage).toBe('ko');
});

ft('freshGet joins several Set-Cookie headers with newlines so cookieNames sees every name (positive control for the h-3 · h-4 · h-8 zero checks)', async ({ emu }) => {
  const r = await freshGet(`${emu.base}/two-cookies`);
  expect(r.status).toBe(200);
  expect(cookieNames(r.headers['set-cookie'])).toEqual({ names: ['a_one', 'b_two'], unparsable: 0 });
});
