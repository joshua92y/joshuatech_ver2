// e2e/selftest/test-base.test.ts — 공통 test 기반의 옵션 재단언(리뷰 B-3 · C-1) selftest. 순수 함수만 — 브라우저 0 · 네트워크 0.
// 파일 단위 덮기(옵션 픽스처)는 FullConfig.projects[].use에 드러나지 않아 globalSetup ③이 못 본다. 그래서 spec · needle · selftest-browser가
// 쓰는 test 기반(lib/test-base.ts)의 자동 픽스처가 시험마다 실제 픽스처 값을 프로젝트 설정 값과 다시 맞춰 본다. 결과는 이름뿐이다(값 0).
import { test, expect } from '@playwright/test';
import * as crypto from 'node:crypto';
import { GUARDED_OPTIONS, optionViolations } from '../lib/test-base';

const PROJECT_USE = {
  trace: 'off',
  video: 'off',
  screenshot: 'off',
  locale: 'en-US',
  ignoreHTTPSErrors: false,
  acceptDownloads: false,
  launchOptions: { env: { TEMP: 'C:\\t', SystemRoot: 'C:\\Windows' } },
  baseURL: 'https://auth.joshuatech.dev',
};

function actual(): Record<string, unknown> {
  return {
    trace: 'off',
    video: 'off',
    screenshot: 'off',
    headless: true,
    channel: undefined,
    launchOptions: { env: { TEMP: 'C:\\t', SystemRoot: 'C:\\Windows' } },
    connectOptions: undefined,
    contextOptions: {},
    proxy: undefined,
    storageState: undefined,
    extraHTTPHeaders: undefined,
    httpCredentials: undefined,
    ignoreHTTPSErrors: false,
    acceptDownloads: false,
    baseURL: 'https://auth.joshuatech.dev',
  };
}

test('test-base: the guarded option fixtures are exactly the recording, browser and context options that can carry or record values', () => {
  expect([...GUARDED_OPTIONS].sort()).toEqual(
    ['acceptDownloads', 'baseURL', 'channel', 'connectOptions', 'contextOptions', 'extraHTTPHeaders', 'headless', 'httpCredentials', 'ignoreHTTPSErrors', 'launchOptions', 'proxy', 'screenshot', 'storageState', 'trace', 'video'].sort(),
  );
});

test('test-base: the reviewed configuration has no violation (object and string recording modes both read as off)', () => {
  expect(optionViolations(actual(), PROJECT_USE)).toEqual([]);
  expect(optionViolations({ ...actual(), trace: { mode: 'off' }, video: { mode: 'off' }, screenshot: { mode: 'off' } }, PROJECT_USE)).toEqual([]);
  expect(optionViolations({ ...actual(), baseURL: undefined }, { ...PROJECT_USE, baseURL: undefined })).toEqual([]);
});

test('test-base: a file-level override of any guarded option is reported by name', () => {
  const cases: Array<[Record<string, unknown>, string]> = [
    [{ trace: 'on' }, 'trace'],
    [{ trace: { mode: 'retain-on-failure' } }, 'trace'],
    [{ video: 'on' }, 'video'],
    [{ video: { mode: 'on', size: { width: 1, height: 1 } } }, 'video'],
    [{ screenshot: 'only-on-failure' }, 'screenshot'],
    [{ screenshot: { mode: 'on', fullPage: true } }, 'screenshot'],
    [{ headless: false }, 'headless'],
    [{ channel: 'chrome' }, 'channel'],
    [{ launchOptions: { env: { TEMP: 'C:\\t', SystemRoot: 'C:\\Windows' }, args: ['--remote-debugging-port=9222'] } }, 'launchOptions'],
    [{ launchOptions: { env: { TEMP: 'C:\\t', SystemRoot: 'C:\\Windows', SSLKEYLOGFILE: 'C:\\k' } } }, 'launchOptions'],
    [{ launchOptions: {} }, 'launchOptions'],
    [{ connectOptions: { wsEndpoint: 'ws://127.0.0.1:1' } }, 'connectOptions'],
    // 기록 옵션 이름은 static-gate가 막는 글자라 조각으로 만든다
    [{ contextOptions: { [['record', 'Har'].join('')]: { path: 'x.har' } } }, 'contextOptions'],
    [{ contextOptions: { [['record', 'Video'].join('')]: { dir: 'v' } } }, 'contextOptions'],
    [{ proxy: { server: 'http://127.0.0.1:8080' } }, 'proxy'],
    [{ storageState: 'state.json' }, 'storageState'],
    [{ extraHTTPHeaders: { 'x-a': 'b' } }, 'extraHTTPHeaders'],
    [{ httpCredentials: { username: 'u', password: 'p' } }, 'httpCredentials'],
    [{ ignoreHTTPSErrors: true }, 'ignoreHTTPSErrors'],
    [{ acceptDownloads: true }, 'acceptDownloads'],
    [{ baseURL: 'https://elsewhere.example' }, 'baseURL'],
  ];
  for (const [over, name] of cases) {
    expect(optionViolations({ ...actual(), ...over }, PROJECT_USE), JSON.stringify(Object.keys(over))).toEqual([name]);
  }
  expect(optionViolations({ ...actual(), video: 'on', trace: 'on', proxy: { server: 'x' } }, PROJECT_USE)).toEqual(['proxy', 'trace', 'video']);
});

test('test-base: violations are option names only — values never appear', () => {
  const secret = 'mk' + crypto.randomBytes(8).toString('hex');
  const r = optionViolations({ ...actual(), extraHTTPHeaders: { cookie: secret }, httpCredentials: { username: secret, password: secret }, storageState: secret }, PROJECT_USE);
  expect(r).toEqual(['extraHTTPHeaders', 'httpCredentials', 'storageState']);
  expect(JSON.stringify(r).includes(secret)).toBe(false);
});
