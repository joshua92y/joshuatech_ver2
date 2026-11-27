// e2e/selftest-browser/authentik-flow.test.ts — 두 live spec이 함께 쓰는 Authentik 흐름(lib/authentik-flow.ts)의 동작 시험(빌드 리뷰 r1 — A-1 · A-10 · B-4 · B-5 · B-6).
// 로컬 node:http(127.0.0.1) 서버가 Authentik 화면을 흉내 낸다 — 공개 호스트 0 · 자격 0. 값은 시험 안에서 만들고 줄에는 싣지 않는다.
// 흐름 단계 줄은 주입한 sink에만 쌓는다(이 실행의 출력에 가짜 단계 줄이 섞이지 않게).
import { test, expect } from '../lib/test-base';
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as http from 'node:http';
import type { AddressInfo } from 'node:net';
import * as path from 'node:path';
import { AUTH_PATHS, AUTH_SEL, authentikLogin, authentikLogout, confirmDeadAndStore, type FlowSink } from '../lib/authentik-flow';
import type { Secrets } from '../lib/env-contract';
import { LOCK_FILE_NAME, RUN_MARKER_NAME, lockGate, lockPresent, type LockTarget } from '../lib/login-lock';
import { formatInfo, formatStep, type Verdict } from '../lib/out';

const RUN = 't077-20261123T090000Z-a1b2c3';
const STEP_MS = 2_000;

interface Mode {
  password: 'advance' | 'stuck' | 'disabled';
  totp: 'submit' | 'autosubmit';
  logout: 'complete' | 'never';
}

interface Emu {
  base: string;
  mode: Mode;
  revoked: boolean;
  logoutPosts: number;
}

// 로그인 흐름 화면(한 페이지 안에서 단계가 바뀐다 — Authentik 흐름 실행기처럼)
function loginPage(mode: Mode): string {
  const script = [
    `const MODE = ${JSON.stringify(mode)};`,
    "const root = document.getElementById('root');",
    'function show(html, onSubmit) {',
    '  root.innerHTML = html;',
    "  const f = root.querySelector('form');",
    "  f.addEventListener('submit', (e) => { e.preventDefault(); onSubmit(f); });",
    '  return f;',
    '}',
    "function identify() { show('<form><input name=\"uidField\" type=\"text\"><button type=\"submit\">Log in</button></form>', password); }",
    'function password() {',
    "  const dis = MODE.password === 'disabled' ? ' disabled' : '';",
    "  show('<form><input name=\"password\" type=\"password\"' + dis + '><button type=\"submit\">Continue</button></form>', () => { if (MODE.password === 'advance') totp(); });",
    '}',
    'function totp() {',
    "  const f = show('<form><input name=\"code\" type=\"text\"><button type=\"submit\">Continue</button></form>', done);",
    "  if (MODE.totp === 'autosubmit') { const i = f.querySelector('input'); i.addEventListener('input', () => { if (i.value.length >= 6) done(); }); }",
    '}',
    "function done() { document.cookie = 'authentik_session=alive; path=/'; location.href = '/if/user/'; }",
    'identify();',
  ].join('\n');
  return `<!doctype html><html><head><meta charset="utf-8"><title>flow</title></head><body><div id="root"></div><script>${script}</script></body></html>`;
}

function html(res: http.ServerResponse, body: string): void {
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' });
  res.end(body);
}

function redirect(res: http.ServerResponse, location: string): void {
  res.writeHead(302, { location, 'cache-control': 'no-store' });
  res.end();
}

const ft = test.extend<{ emu: Emu }>({
  emu: async ({}, use) => {
    const state: Emu = { base: '', mode: { password: 'advance', totp: 'submit', logout: 'complete' }, revoked: false, logoutPosts: 0 };
    const server = http.createServer((req, res) => {
      const route = (req.url ?? '/').split('?')[0];
      req.resume();
      if (req.method === 'POST' && route === '/x-logout') {
        state.revoked = true;
        state.logoutPosts += 1;
        res.writeHead(204);
        return void res.end();
      }
      if (route === '/' || route === '/if/flow/default-authentication-flow/') return html(res, loginPage(state.mode));
      if (route === AUTH_PATHS.userInterface) {
        const alive = /(?:^|;\s*)authentik_session=alive(?:;|$)/.test(String(req.headers.cookie ?? ''));
        if (alive && !state.revoked) return html(res, '<!doctype html><p id="user">user</p>');
        return redirect(res, '/if/flow/default-authentication-flow/?next=%2Fif%2Fuser%2F');
      }
      if (route === AUTH_PATHS.invalidation) return redirect(res, '/if/flow/default-invalidation-flow/');
      if (route === '/if/flow/default-invalidation-flow/') {
        // Authentik처럼 load 뒤에 흐름 실행기가 로그아웃을 부르고 로그인 흐름으로 옮긴다(1.2 s 뒤)
        const go = state.mode.logout === 'complete' ? "<script>setTimeout(() => { fetch('/x-logout', { method: 'POST' }).then(() => { location.href = '/if/flow/default-authentication-flow/'; }); }, 1200);</script>" : '';
        return html(res, `<!doctype html><p id="signout">signing out</p>${go}`);
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

function sink(): FlowSink & { lines: string[] } {
  const lines: string[] = [];
  return {
    lines,
    emitStep: (task: string, step: string, verdict: Verdict, reason?: string, note?: string) => {
      lines.push(formatStep(task, step, verdict, reason, note));
    },
    emitInfo: (text: string, note?: string) => {
      lines.push(formatInfo(text, note));
    },
  };
}

function secrets(): Secrets {
  return { password: 'pw-' + crypto.randomBytes(8).toString('hex'), codes: ['123456', '654321'], step0: 0 };
}

function lockTarget(dir: string): LockTarget {
  return { file: path.join(dir, 'lock', LOCK_FILE_NAME), runMarker: path.join(dir, 'root', RUN_MARKER_NAME) };
}

async function rejection(p: Promise<unknown>): Promise<Error> {
  try {
    await p;
  } catch (e) {
    return e as Error;
  }
  throw new Error('expected a rejection');
}

function loginOptions(emu: Emu, s: ReturnType<typeof sink>, lock: LockTarget, events: string[]) {
  return {
    task: 'T077',
    startUrl: emu.base + '/',
    landing: { url: emu.base + AUTH_PATHS.userInterface, prefix: false },
    secrets: secrets(),
    lock,
    runId: RUN,
    sink: s,
    timeout: STEP_MS,
    pickCode: async (x: Secrets) => {
      events.push('pick');
      return x.codes[0];
    },
    onSessionMayExist: () => {
      events.push('session');
    },
  };
}

ft('authentik-flow: login walks identify → password → totp to the landing page; no lock', async ({ page, emu }, testInfo) => {
  const s = sink();
  const events: string[] = [];
  const lock = lockTarget(testInfo.outputPath('ok'));
  await authentikLogin(page, loginOptions(emu, s, lock, events));
  expect(s.lines).toEqual(['T077 identify PASS', 'T077 password PASS', 'T077 totp PASS']);
  expect(events).toEqual(['pick', 'session']);
  expect(await page.locator('#user').count()).toBe(1);
  expect(lockPresent(lock.file)).toBe(false);
});

ft('authentik-flow: a password step that does not advance after the value was entered → [guard] step-not-advanced + lock (D10 ⑦)', async ({ page, emu }, testInfo) => {
  emu.mode.password = 'stuck';
  const s = sink();
  const events: string[] = [];
  const lock = lockTarget(testInfo.outputPath('stuck'));
  const e = await rejection(authentikLogin(page, loginOptions(emu, s, lock, events)));
  expect(e.message).toBe('T077 password FAIL [guard] step-not-advanced password');
  expect(s.lines).toEqual(['T077 identify PASS', 'INFO login-lock written step=password — operator check before removal', 'T077 password FAIL [guard] step-not-advanced password']);
  expect(lockPresent(lock.file)).toBe(true);
  expect(events).toEqual([]);
});

ft('authentik-flow: a password that never reaches the field (fill fails) → [product], no lock (lock = value entered — 리뷰 A-10)', async ({ page, emu }, testInfo) => {
  emu.mode.password = 'disabled';
  const s = sink();
  const lock = lockTarget(testInfo.outputPath('disabled'));
  const e = await rejection(authentikLogin(page, loginOptions(emu, s, lock, [])));
  expect(e.message).toBe('T077 password FAIL [product] password-failed (secret-input)');
  expect(lockPresent(lock.file)).toBe(false);
  expect(lockPresent(lock.runMarker)).toBe(false);
});

ft('authentik-flow: TOTP entered then the field vanishes (auto-submit) → session flag raised before the fill, [guard] + lock (리뷰 B-5)', async ({ page, emu }, testInfo) => {
  emu.mode.totp = 'autosubmit';
  const s = sink();
  const events: string[] = [];
  const lock = lockTarget(testInfo.outputPath('autosubmit'));
  const e = await rejection(authentikLogin(page, loginOptions(emu, s, lock, events)));
  expect(e.message).toBe('T077 totp FAIL [guard] step-not-advanced totp');
  expect(events).toEqual(['pick', 'session']);
  expect(lockPresent(lock.file)).toBe(true);
  expect(s.lines.at(-1)).toBe('T077 totp FAIL [guard] step-not-advanced totp');
});

ft('authentik-flow: when the lock cannot be written the run-scoped marker stops the next credential gate (리뷰 B-4)', async ({ page, emu }, testInfo) => {
  emu.mode.password = 'stuck';
  const dir = testInfo.outputPath('unwritable');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'blocker'), 'x');
  const lock: LockTarget = { file: path.join(dir, 'blocker', 'lock', LOCK_FILE_NAME), runMarker: path.join(dir, 'root', RUN_MARKER_NAME) };
  const s = sink();
  const e = await rejection(authentikLogin(page, loginOptions(emu, s, lock, [])));
  expect(e.message).toBe('T077 password FAIL [guard] step-not-advanced password');
  expect(s.lines).toContain('INFO login-lock write-failed run-marker=written — remaining live tests stop at cred');
  expect(lockPresent(lock.runMarker)).toBe(true);
  expect(lockGate(lock)?.code).toBe('login-lock write-failed');
});

ft('authentik-flow: logout completes only when the login screen is visible, after the flow executor logged out (리뷰 A-1)', async ({ page, emu }) => {
  const t0 = Date.now();
  const doneAt = await authentikLogout(page, { origin: emu.base, timeout: 5_000 });
  expect(doneAt - t0, 'completion waits for the flow executor (1.2 s)').toBeGreaterThanOrEqual(1_000);
  expect(await page.locator(AUTH_SEL.identifyInput).count(), 'login screen marker').toBe(1);
  expect(emu.revoked, 'server-side logout happened before completion').toBe(true);
  expect(emu.logoutPosts).toBe(1);
});

ft('authentik-flow: a logout that never reaches the login screen is not reported as done', async ({ page, emu }) => {
  emu.mode.logout = 'never';
  const e = await rejection(authentikLogout(page, { origin: emu.base, timeout: STEP_MS }));
  expect(e.message).toBe('marker identify failed (timeout)');
  expect(emu.revoked).toBe(false);
});

function aliveState(emu: Emu) {
  const host = new URL(emu.base).hostname;
  return { cookies: [{ name: 'authentik_session', value: 'alive', domain: host, path: '/', expires: -1, httpOnly: false, secure: false, sameSite: 'Lax' as const }], origins: [] };
}

ft('authentik-flow: the dead state is confirmed in memory before any file is written (리뷰 B-6)', async ({ browser, emu }, testInfo) => {
  emu.revoked = true;
  const dir = testInfo.outputPath('auth-ok');
  const file = await confirmDeadAndStore(browser, aliveState(emu), { origin: emu.base, timeout: STEP_MS, runId: RUN, dir });
  expect(file).toBe(path.join(dir, `${RUN}-t077.json`));
  expect(fs.existsSync(file)).toBe(true);
});

ft('authentik-flow: a session that is still alive is rejected and nothing reaches the disk (리뷰 B-6)', async ({ browser, emu }, testInfo) => {
  emu.revoked = false;
  const dir = testInfo.outputPath('auth-alive');
  const e = await rejection(confirmDeadAndStore(browser, aliveState(emu), { origin: emu.base, timeout: STEP_MS, runId: RUN, dir }));
  expect(e.message).toBe('marker identify failed (timeout)');
  expect(fs.existsSync(path.join(dir, `${RUN}-t077.json`))).toBe(false);
});
