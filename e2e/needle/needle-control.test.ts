// e2e/needle/needle-control.test.ts — 바늘 시험 실행 2 · 양성 대조 변이 스펙(설계 D10 ⑤ · ⑧ · 컨트롤러 N-1 · 빌드 리뷰 r1 — B-1). JT_E2E_NEEDLE=1일 때만 실린다(D3).
// 실행 1(needle.test.ts)의 「hits 0」이 공허하지 않음을 노출 경로마다 증명한다: 같은 경로를 감싸개 없이(Playwright 원래 API로) 밟아 그 경로 전용 대조 바늘이
// 실제로 새는지 프로세스 안에서 확인하고(새지 않으면 이 시험이 실패한다 — 그 경로는 더 이상 노출 경로가 아니다), 새는 글자를 로그 면에 일부러 낸다.
// 런처는 경로별 대조 바늘이 정해진 면(메시지 경로 = 로그 · 페이지 스냅숏 경로 = 보존된 루트)에서 잡혀야 needle=PASS로 본다.
//   c-log console 출력(스캐너 자체) · c-inp fill 오류(nd-1) · c-req 요청 헤더(nd-3) · c-sck 응답 Set-Cookie(nd-3b) · c-url 「navigated to」 쿼리(nd-5) ·
//   c-nav 쿼리 URL 탐색 오류(nd-8) · c-pgs 실패 시험의 페이지 스냅숏 → error-context(nd-2 · nd-6 · nd-7 — 의도 실패 1건) + 바이너리 산출물 대조 1개.
// static-gate의 이름 붙은 예외(출력 · 원래 API: console · request · goto · waitForURL · fill)이며, 대조 바늘만 쓴다 — 자격 env는 읽지 않는다
// (env-contract의 needle-control 갈래가 대조 꼴 값만 돌려준다). 공개 호스트 0 — 127.0.0.1만.
import { test as base } from '../lib/test-base';
import type { TestInfo } from '@playwright/test';
import * as fs from 'node:fs';
import * as http from 'node:http';
import type { AddressInfo } from 'node:net';
import { readSecretsOnce, type ControlPaths } from '../lib/env-contract';

interface Controls {
  control: string;
  paths: ControlPaths;
}

interface Local {
  base: string;
  c?: Controls;
}

function controls(testInfo: TestInfo): Controls {
  const d = readSecretsOnce(testInfo);
  if (d.kind !== 'control') throw new Error('needle-control setup failed');
  return { control: d.control, paths: d.paths };
}

// 원래 API의 오류 메시지(감싸개 없이) — 값이 실릴 수 있는 바로 그 글자
async function rawMessage(fn: () => Promise<unknown>): Promise<string> {
  try {
    await fn();
  } catch (e) {
    return String((e as Error)?.message ?? e);
  }
  return '';
}

// 그 경로가 실제로 대조 바늘을 내는지 확인하고(아니면 실패 — 값은 싣지 않는다), 낸 글자를 로그 면에 일부러 둔다
function expose(name: string, message: string, needle: string): void {
  if (!message.includes(needle)) throw new Error(`control ${name} did not expose its needle`);
  console.log(message);
}

const test = base.extend<{ local: Local }>({
  local: async ({}, use, testInfo) => {
    const state: Local = { base: '', c: controls(testInfo) };
    const server = http.createServer((req, res) => {
      const route = (req.url ?? '/').split('?')[0];
      const c = state.c as Controls;
      req.resume();
      const html = (body: string) => {
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
        res.end(`<!doctype html><html><head><meta charset="utf-8"><title>control</title></head><body>${body}</body></html>`);
      };
      if (route === '/c-drop') return void req.socket.destroy();
      if (route === '/c-sck') {
        res.writeHead(200, { 'content-type': 'text/plain', 'set-cookie': `jt_session=${c.paths.setCookie}; Path=/; HttpOnly` });
        res.write('partial');
        return void setTimeout(() => req.socket.destroy(), 50);
      }
      if (route === '/c-land') {
        const q = encodeURIComponent(c.paths.url);
        return html(`<p>landing</p><script>setTimeout(() => { location.href = '/c-url?code=${q}&state=${q}'; }, 300);</script>`);
      }
      if (route === '/c-url') return html('<p>landed</p>');
      if (route === '/c-nav') return; // 응답하지 않는다
      if (route === '/c-pgs') return html(`<p id="v">${c.paths.file}</p>`);
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

test('c-log console prints the control needle on the log surface', async ({ local }) => {
  console.log((local.c as Controls).control);
});

test('c-inp raw fill exposes the value in its error', async ({ page, local }) => {
  const c = local.c as Controls;
  await page.setContent('<input id="pw" type="password" disabled>');
  expose('controlFill', await rawMessage(() => page.locator('#pw').fill(c.paths.fill, { timeout: 1_000 })), c.paths.fill);
});

test('c-req raw request exposes its request headers in its error', async ({ request, local }) => {
  const c = local.c as Controls;
  expose('controlRequest', await rawMessage(() => request.get(`${local.base}/c-drop`, { headers: { cookie: `jt_session=${c.paths.requestHeaders}` }, timeout: 5_000, maxRedirects: 0 })), c.paths.requestHeaders);
});

test('c-sck raw request exposes the response set-cookie in its error', async ({ request, local }) => {
  const c = local.c as Controls;
  expose('controlSetCookie', await rawMessage(() => request.get(`${local.base}/c-sck`, { timeout: 5_000, maxRedirects: 0 })), c.paths.setCookie);
});

test('c-url raw waitForURL exposes the query of a url navigated to while waiting', async ({ page, local }) => {
  const c = local.c as Controls;
  await page.goto(`${local.base}/c-land`);
  expose('controlUrl', await rawMessage(() => page.waitForURL('**/c-never', { timeout: 2_000 })), c.paths.url);
});

test('c-nav raw goto exposes the query of the url it navigates to', async ({ page, local }) => {
  const c = local.c as Controls;
  const q = encodeURIComponent(c.paths.goto);
  expose('controlGoto', await rawMessage(() => page.goto(`${local.base}/c-nav?code=${q}&state=${q}`, { timeout: 2_000 })), c.paths.goto);
});

// 마지막에 둔다 — 이 시험은 워커 env를 바꾼 채 실패하고, 실패 뒤 워커는 새로 뜬다.
test('c-pgs page snapshot of a failed test lands in the preserved output', async ({ page, local }, testInfo) => {
  await page.goto(`${local.base}/c-pgs`);
  // 바이너리 산출물 양성 대조 — 루트 산출물 계수(zip · webm · png)가 실제로 보고 있음을 증명한다(내용 0)
  fs.writeFileSync(testInfo.outputPath('control-artifact.png'), 'not an image');
  // 회귀 흉내: 페이지 스냅숏 끄기(설정의 PLAYWRIGHT_NO_COPY_PROMPT)가 빠지면 실패 시험의 error-context에 화면 글자가 실린다
  delete process.env.PLAYWRIGHT_NO_COPY_PROMPT;
  throw new Error('needle-control page-snapshot path');
});
