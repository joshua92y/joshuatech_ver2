// e2e/needle/needle.test.ts — 바늘 시험 실행 1(설계 D10 ⑧ · r2 — V-6 · VD-T077-4 · 빌드 리뷰 r1 — B-1). JT_E2E_NEEDLE=1일 때만 실린다(D3).
// 로컬 페이지 · 로컬 node:http 서버만 — 공개 호스트 0. 의도 실패는 정확히 9건이고, 메시지는 런처 기대 목록(launch.mjs EXPECTED_NEEDLE_FAILURES)과 같아야 한다.
// 시험마다 실제 노출 경로를 밟는다(감싸개가 빠지면 바늘이 보여야 한다 — 실행 2 needle-control이 경로마다 감싸개 없이 같은 경로를 밟아 그것을 증명한다):
//   nd-1 fill 오류(call log에 값) · nd-2 값이 칸에 남은 채 단계가 안 넘어감(페이지 스냅숏에 칸 값) · nd-3 요청 헤더(cookie · authorization) 뒤 끊김 ·
//   nd-3b 응답 헤더(Set-Cookie) 뒤 본문 도중 끊김 · nd-4 500 · nd-5 대기 중 쿼리 URL로 다시 탐색(「navigated to」) · nd-6 Sessions 꼴 표(가짜 IP · UA) ·
//   nd-7 mask 대상 0 · nd-8 쿼리 URL 탐색 시간 초과(call log의 「navigating to」).
// needle 실행은 preserveOutput 'always'라 실패 산출물(error-context 등)이 루트에 남아 스캔 면에 든다(B-1 ③).
// 바늘 값은 런처가 실행마다 만들어 env로만 넘긴다 — 이 파일은 실제 읽기 경로(readSecretsOnce)로 받는다(리터럴 0).
import { test as base, expect } from '../lib/test-base';
import type { TestInfo } from '@playwright/test';
import * as http from 'node:http';
import type { AddressInfo } from 'node:net';
import { readSecretsOnce } from '../lib/env-contract';
import { evidenceShot } from '../lib/evidence';
import { guarded, httpGet, httpGetExpect, navigate, waitForPath } from '../lib/http';
import { secretFill } from '../lib/secret-input';

interface Needles { password: string; codes: readonly string[]; cookie: string; authorization: string; query: string; ip: string; ua: string }
interface Local { base: string; rows: { ip: string; ua: string }[]; setCookie: string; query: string }

function needles(testInfo: TestInfo): Needles {
  const d = readSecretsOnce(testInfo);
  if (d.kind !== 'ok' || d.mode !== 'needle') throw new Error(`needle setup failed (${d.kind === 'stop' ? `[${d.prefix}] ${d.code}` : d.kind})`);
  return { password: d.secrets.password, codes: d.secrets.codes, ...d.extras };
}

function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

function page(body: string): string {
  return `<!doctype html><html><head><meta charset="utf-8"><title>needle</title></head><body>${body}</body></html>`;
}

function sessionsTable(rows: Local['rows']): string {
  const tr = rows.map((r) => `<tr><td class="ip">${esc(r.ip)}</td><td class="ua">${esc(r.ua)}</td></tr>`).join('');
  return `<table id="sessions"><thead><tr><th>IP</th><th>Agent</th></tr></thead><tbody>${tr}</tbody></table>`;
}

const test = base.extend<{ local: Local }>({
  local: async ({}, use) => {
    const state: Local = { base: '', rows: [], setCookie: '', query: '' };
    const server = http.createServer((req, res) => {
      const route = (req.url ?? '/').split('?')[0];
      req.resume();
      const html = (body: string) => {
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
        res.end(page(body));
      };
      if (route === '/nd-1') return html('<input id="pw" type="password" disabled>');
      // 제출이 페이지를 바꾸지 않는다 — 값이 칸에 남은 채 다음 단계 표식이 안 나온다(실제 「자격 거부」 꼴)
      if (route === '/nd-2') return html('<form id="f" onsubmit="return false;"><input id="pw" name="pw" type="password"><input id="code" name="code" type="text"><button id="go" type="submit">go</button></form>');
      if (route === '/nd-3') return void req.socket.destroy();
      if (route === '/nd-3b') {
        // 응답 헤더(바늘 Set-Cookie)를 보낸 뒤 본문 도중에 끊는다 — call log에 응답 헤더가 실리는 경로
        res.writeHead(200, { 'content-type': 'text/plain', 'set-cookie': `jt_session=${state.setCookie}; Path=/; HttpOnly` });
        res.write('partial');
        return void setTimeout(() => req.socket.destroy(), 50);
      }
      if (route === '/nd-4') {
        res.writeHead(500, { 'content-type': 'text/plain' });
        return void res.end('internal');
      }
      // 첫 탐색 뒤 대기 중에 쿼리 URL로 다시 탐색한다(실제 OAuth callback 꼴 — 「navigated to」 줄이 오류에 실리는 경로)
      if (route === '/nd-5') {
        const q = encodeURIComponent(state.query);
        return html(`<p id="landing">landing</p><script>setTimeout(() => { location.href = '/nd-5b?code=${q}&state=${q}'; }, 300);</script>`);
      }
      if (route === '/nd-5b') return html('<p id="landed">landed</p>');
      if (route === '/nd-6' || route === '/nd-7') return html(sessionsTable(state.rows));
      // 쿼리 URL로 간 탐색에 응답이 오지 않는다 — 탐색 오류의 call log에 그 URL(쿼리 포함)이 실리는 경로.
      // (리다이렉트 뒤의 쿼리 URL은 1.65.1 탐색 시간 초과 오류에 실리지 않는다 — r1 실측: 양성 대조가 없어 그 꼴은 쓰지 않는다)
      if (route === '/nd-8') return; // 응답하지 않는다(픽스처 끝에서 연결을 닫는다)
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

test('nd-1 secret input fails', async ({ page: p, local }, testInfo) => {
  const n = needles(testInfo);
  await navigate(p, `${local.base}/nd-1`);
  await secretFill(p.locator('#pw'), n.password, 'password', { timeout: 1_500 });
});

test('nd-2 step transition fails while the values stay in the fields', async ({ page: p, local }, testInfo) => {
  const n = needles(testInfo);
  await navigate(p, `${local.base}/nd-2`);
  await secretFill(p.locator('#pw'), n.password, 'password');
  await secretFill(p.locator('#code'), n.codes[0], 'totp');
  await guarded('submit nd-2', () => p.locator('#go').click());
  await guarded('marker totp-step', () => p.locator('#totp-step').waitFor({ state: 'visible', timeout: 2_000 }));
});

test('nd-3 connection drop with needle headers', async ({ request, local }, testInfo) => {
  const n = needles(testInfo);
  await httpGet(request, `${local.base}/nd-3`, { timeout: 5_000, headers: { cookie: `jt_session=${n.cookie}`, authorization: `Bearer ${n.authorization}` } });
});

test('nd-3b connection drop after needle response headers', async ({ request, local }, testInfo) => {
  const n = needles(testInfo);
  local.setCookie = n.cookie;
  await httpGet(request, `${local.base}/nd-3b`, { timeout: 5_000, headers: { authorization: `Bearer ${n.authorization}` } });
});

test('nd-4 server error with needle headers', async ({ request, local }, testInfo) => {
  const n = needles(testInfo);
  await httpGetExpect(request, `${local.base}/nd-4`, 200, { timeout: 5_000, headers: { cookie: `jt_session=${n.cookie}`, authorization: `Bearer ${n.authorization}` } });
});

test('nd-5 waitForURL timeout while the page re-navigates to a needle query url', async ({ page: p, local }, testInfo) => {
  const n = needles(testInfo);
  local.query = n.query;
  await navigate(p, `${local.base}/nd-5?code=${encodeURIComponent(n.query)}&state=${encodeURIComponent(n.query)}`);
  await waitForPath(p, `${local.base}/nd-5-never`, { timeout: 2_000 });
});

test('nd-6 sessions rows mismatch', async ({ page: p, local }, testInfo) => {
  const n = needles(testInfo);
  local.rows = [{ ip: n.ip, ua: n.ua }, { ip: n.ip, ua: n.ua }];
  await navigate(p, `${local.base}/nd-6`);
  const rows = p.locator('#sessions tbody tr');
  const count = await rows.count();
  expect(count, 'sessions rows').toBe(1);
});

test('nd-7 evidence mask target missing', async ({ page: p, local }, testInfo) => {
  const n = needles(testInfo);
  local.rows = [{ ip: n.ip, ua: n.ua }, { ip: n.ip, ua: n.ua }];
  await navigate(p, `${local.base}/nd-7`);
  const rows = await p.locator('#sessions tbody tr').count();
  await evidenceShot(p, 'nd-7', rows, [
    { label: 'ip', locator: p.locator('#sessions td.no-such-ip') },
    { label: 'ua', locator: p.locator('#sessions td.ua') },
  ]);
});

test('nd-8 navigation timeout on a needle query url', async ({ page: p, local }, testInfo) => {
  const n = needles(testInfo);
  await navigate(p, `${local.base}/nd-8?code=${encodeURIComponent(n.query)}&state=${encodeURIComponent(n.query)}`, { timeout: 2_000 });
});
