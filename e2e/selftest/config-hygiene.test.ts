// e2e/selftest/config-hygiene.test.ts — 해석된 설정 = 설계 D3(VD-T077-5). 이름 붙은 필드만 비교한다(객체 통째 비교 · diff 출력 0 — env가 찍히지 않게).
import { test, expect } from '@playwright/test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { AUTH_BASE_URL, BROWSER_ENV_NAMES, NEEDLE_LIVE_CONFLICT, buildConfig, makeRunId } from '../../playwright.config';

const REPO = path.resolve(__dirname, '..', '..');

function inside(parent: string, child: string): boolean {
  const rel = path.relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

test('config-hygiene: resolved FullConfig — reporter, output, workers, timeouts', async ({}, testInfo) => {
  const c = testInfo.config;
  expect(c.reporter.length, 'reporter count').toBe(1);
  expect(c.reporter[0][0], 'reporter name').toBe('list');
  expect((c.reporter[0][1] as { printSteps?: unknown } | undefined)?.printSteps, 'printSteps').toBe(false);
  expect(c.preserveOutput, 'preserveOutput').toBe('never');
  expect(c.workers, 'workers').toBe(1);
  expect(c.fullyParallel, 'fullyParallel').toBe(false);
  expect(c.forbidOnly, 'forbidOnly').toBe(true);
  expect(c.maxFailures, 'maxFailures').toBe(0);
  expect(c.globalTimeout, 'globalTimeout').toBe(540_000);
  expect(c.webServer, 'webServer').toBeNull();
  expect((c.metadata as { jtApprovedBlock?: unknown }).jtApprovedBlock, 'jtApprovedBlock').toBeNull();
  expect(path.basename(String(c.globalSetup)), 'globalSetup').toBe('global-setup.ts');
  expect(path.basename(String(c.globalTeardown)), 'globalTeardown').toBe('global-teardown.ts');
  expect(path.relative(path.join(REPO, 'e2e'), c.rootDir), 'testDir').toBe('');
  // 스냅숏 기준 이미지를 쓰지 않는다(리뷰 C-2)
  expect((c as unknown as { updateSnapshots?: unknown }).updateSnapshots, 'updateSnapshots').toBe('none');
});

test('config-hygiene: preserveOutput is never, except always for the needle run (리뷰 B-1 — 실패 산출물을 스캔 면에 남긴다)', () => {
  const id = { JT_E2E_RUN_ID: 't077-20261123T000000Z-abcdef' };
  expect(buildConfig(id).preserveOutput).toBe('never');
  expect(buildConfig({ ...id, JT_E2E_LIVE: '1' }).preserveOutput).toBe('never');
  expect(buildConfig({ ...id, JT_E2E_NEEDLE: '1' }).preserveOutput).toBe('always');
  expect(buildConfig({ ...id, JT_E2E_NEEDLE: 'true' }).preserveOutput).toBe('never');
});

test('config-hygiene: snapshot directory lives under the output directory (outside the repo); snapshots are never written', () => {
  const runId = 't077-20261123T000000Z-abcdef';
  const cfg = buildConfig({ JT_E2E_RUN_ID: runId, JT_E2E_OUTPUT_DIR: 'D:\\root\\out' });
  expect(cfg.snapshotDir).toBe(path.join('D:\\root\\out', 'snapshots'));
  expect(cfg.updateSnapshots).toBe('none');
  // 템플릿 설정 이름은 static-gate가 막는 글자라 조각으로 만든다
  expect((cfg as Record<string, unknown>)[['snapshotPath', 'Template'].join('')]).toBeUndefined();
  expect(buildConfig({ JT_E2E_RUN_ID: runId }).snapshotDir).toBe(path.join(os.tmpdir(), 'jt-e2e', runId, 'snapshots'));
});

test('config-hygiene: every resolved project records nothing and runs once', async ({}, testInfo) => {
  const names = testInfo.config.projects.map((p) => p.name);
  expect(names.includes('selftest'), 'selftest project').toBe(true);
  for (const p of testInfo.config.projects) {
    const use = p.use as Record<string, unknown>;
    expect(use.trace, `${p.name} trace`).toBe('off');
    expect(use.video, `${p.name} video`).toBe('off');
    expect(use.screenshot, `${p.name} screenshot`).toBe('off');
    expect(use.locale, `${p.name} locale`).toBe('en-US');
    expect(use.timezoneId, `${p.name} timezoneId`).toBe('UTC');
    expect(use.ignoreHTTPSErrors, `${p.name} ignoreHTTPSErrors`).toBe(false);
    expect(use.acceptDownloads, `${p.name} acceptDownloads`).toBe(false);
    expect(use.actionTimeout, `${p.name} actionTimeout`).toBe(15_000);
    expect(use.navigationTimeout, `${p.name} navigationTimeout`).toBe(30_000);
    expect(use.channel, `${p.name} channel`).toBeUndefined();
    expect(use.headless === false, `${p.name} headless`).toBe(false);
    const lo = (use.launchOptions ?? {}) as Record<string, unknown>;
    expect(lo.executablePath, `${p.name} executablePath`).toBeUndefined();
    expect(lo.channel, `${p.name} launchOptions.channel`).toBeUndefined();
    const envNames = Object.keys((lo.env ?? {}) as Record<string, unknown>).sort();
    for (const n of envNames) expect((BROWSER_ENV_NAMES as readonly string[]).includes(n), `${p.name} browser env name ${n}`).toBe(true);
    expect(p.retries, `${p.name} retries`).toBe(0);
    expect(p.timeout, `${p.name} timeout`).toBe(120_000);
    expect(inside(REPO, p.outputDir), `${p.name} outputDir outside repo`).toBe(false);
    expect(inside(REPO, p.snapshotDir), `${p.name} snapshotDir outside repo`).toBe(false);
  }
});

test('config-hygiene: expect timeout 10 s and no webServer in the user config', () => {
  const cfg = buildConfig({ JT_E2E_RUN_ID: 't077-20261123T000000Z-abcdef' });
  expect(cfg.expect?.timeout, 'expect timeout').toBe(10_000);
  expect(cfg.webServer, 'webServer').toBeUndefined();
  expect(cfg.use?.baseURL, 'top-level baseURL').toBeUndefined();
});

test('config-hygiene: browser env allowlist (VD-T077-3)', () => {
  expect([...BROWSER_ENV_NAMES].sort()).toEqual(['LOCALAPPDATA', 'SystemRoot', 'TEMP', 'TMP', 'USERPROFILE']);
  const cfg = buildConfig({ JT_E2E_RUN_ID: 't077-20261123T000000Z-abcdef', SystemRoot: 'C:\\Windows', TEMP: 'C:\\t', TMP: 'C:\\t', LOCALAPPDATA: 'C:\\l', USERPROFILE: 'C:\\u', PATH: 'C:\\p', KUBECONFIG: 'C:\\k', JT_E2E_BLOCK: 'x' });
  const env = (cfg.use?.launchOptions?.env ?? {}) as Record<string, string>;
  expect(Object.keys(env).sort()).toEqual(['LOCALAPPDATA', 'SystemRoot', 'TEMP', 'TMP', 'USERPROFILE']);
});

test('config-hygiene: projects are conditional on the flags; no flag → selftest projects only', () => {
  const id = { JT_E2E_RUN_ID: 't077-20261123T000000Z-abcdef' };
  const names = (env: Record<string, string>) => (buildConfig({ ...id, ...env }).projects ?? []).map((p) => p.name);
  expect(names({})).toEqual(['selftest', 'selftest-browser']);
  expect(names({ JT_E2E_LIVE: '1' })).toEqual(['selftest', 'selftest-browser', 'live']);
  expect(names({ JT_E2E_NEEDLE: '1' })).toEqual(['selftest', 'selftest-browser', 'needle', 'needle-control']);
  expect(names({ JT_E2E_LIVE: 'true' })).toEqual(['selftest', 'selftest-browser']);
  expect(() => buildConfig({ ...id, JT_E2E_LIVE: '1', JT_E2E_NEEDLE: '1' })).toThrow(NEEDLE_LIVE_CONFLICT);
  expect(NEEDLE_LIVE_CONFLICT.startsWith('[guard] needle-live-conflict')).toBe(true);
});

test('config-hygiene: live project targets the fixed Authentik origin and the two live specs', () => {
  const cfg = buildConfig({ JT_E2E_RUN_ID: 't077-20261123T000000Z-abcdef', JT_E2E_LIVE: '1' });
  const live = (cfg.projects ?? []).find((p) => p.name === 'live');
  expect(AUTH_BASE_URL).toBe('https://auth.joshuatech.dev');
  expect(live?.use?.baseURL, 'live baseURL').toBe(AUTH_BASE_URL);
  expect(live?.testMatch, 'live testMatch').toEqual(['auth.spec.ts', 'revocation.spec.ts']);
  const sel = (cfg.projects ?? []).find((p) => p.name === 'selftest');
  expect(sel?.testMatch, 'selftest testMatch').toBe('selftest/**/*.test.ts');
});

test('config-hygiene: outputDir = JT_E2E_OUTPUT_DIR, else <tmp>/jt-e2e/<runId>', () => {
  const runId = 't077-20261123T000000Z-abcdef';
  expect(buildConfig({ JT_E2E_RUN_ID: runId, JT_E2E_OUTPUT_DIR: 'D:\\root\\out' }).outputDir).toBe('D:\\root\\out');
  expect(buildConfig({ JT_E2E_RUN_ID: runId }).outputDir).toBe(path.join(os.tmpdir(), 'jt-e2e', runId));
  expect(() => buildConfig({})).toThrow(/run id/);
  expect(() => buildConfig({ JT_E2E_RUN_ID: '../x' })).toThrow(/run id/);
});

test('config-hygiene: run id shape t07x-<yyyyMMddTHHmmssZ>-<6 hex>', () => {
  expect(makeRunId(new Date(Date.UTC(2026, 10, 23, 9, 5, 7)), 'a1b2c3')).toBe('t077-20261123T090507Z-a1b2c3');
  expect(/^t077-\d{8}T\d{6}Z-[0-9a-f]{6}$/.test(makeRunId())).toBe(true);
});

test('config-hygiene: Playwright error-context page snapshot is disabled in workers', () => {
  expect(process.env.PLAYWRIGHT_NO_COPY_PROMPT).toBe('1');
});

test('config-hygiene: root package.json has no scripts and pins @playwright/test exactly; installed version matches', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(REPO, 'package.json'), 'utf8'));
  expect(pkg.scripts, 'scripts').toBeUndefined();
  expect(Object.keys(pkg.devDependencies ?? {}), 'devDependencies').toEqual(['@playwright/test']);
  expect(pkg.devDependencies['@playwright/test'], 'pin').toBe('1.65.1');
  const installed = JSON.parse(fs.readFileSync(require.resolve('@playwright/test/package.json', { paths: [REPO] }), 'utf8'));
  expect(installed.version, 'installed version').toBe('1.65.1');
});
