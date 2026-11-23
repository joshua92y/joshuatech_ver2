// e2e/selftest/tracked-files.test.ts — 정확한 파일 집합(설계 D4 · r1 — B-12) selftest. 새 파일은 이 목록을 고치는 커밋으로만 들어온다.
// 집합 = git이 추적하거나 추적할 수 있는(무시되지 않은) e2e 파일 — 커밋 전에도 같은 판정이 서도록 --others --exclude-standard를 더한다.
import { test, expect } from '@playwright/test';
import { spawnSync } from 'node:child_process';
import * as fs from 'node:fs';
import * as path from 'node:path';

const REPO = path.resolve(__dirname, '..', '..');

// T077 조각 ①a + T079 조각 ①b의 e2e 파일(설계 D1 · D12). ①b = revocation.spec.ts · lib/{bff,kubectl-log}.ts · selftest/{bff,kubectl-log}.test.ts.
// 리뷰 r1 수정: lib/test-base.ts(B-3 공통 test 기반) · lib/authentik-flow.ts(A-1 · B-4 · B-5 · B-6 흐름 — 두 spec 공용) + 그 selftest 셋
// (selftest/test-base · selftest-browser/authentik-flow · selftest-browser/fixture-guard).
const EXPECTED_E2E = [
  'e2e/README.md',
  'e2e/auth.spec.ts',
  'e2e/global-setup.ts',
  'e2e/global-teardown.ts',
  'e2e/lib/auth-dir.ts',
  'e2e/lib/authentik-flow.ts',
  'e2e/lib/bff.ts',
  'e2e/lib/env-contract.ts',
  'e2e/lib/evidence.ts',
  'e2e/lib/http.ts',
  'e2e/lib/kubectl-log.ts',
  'e2e/lib/launch.mjs',
  'e2e/lib/login-lock.ts',
  'e2e/lib/out.ts',
  'e2e/lib/pace.ts',
  'e2e/lib/reach.ts',
  'e2e/lib/scan-needle.mjs',
  'e2e/lib/secret-input.ts',
  'e2e/lib/test-base.ts',
  'e2e/lib/totp-window.ts',
  'e2e/needle/needle-control.test.ts',
  'e2e/needle/needle.test.ts',
  'e2e/revocation.spec.ts',
  'e2e/selftest-browser/authentik-flow.test.ts',
  'e2e/selftest-browser/evidence.test.ts',
  'e2e/selftest-browser/fixture-guard.test.ts',
  'e2e/selftest-browser/secret-input.test.ts',
  'e2e/selftest/auth-dir.test.ts',
  'e2e/selftest/bff.test.ts',
  'e2e/selftest/config-hygiene.test.ts',
  'e2e/selftest/env-contract.test.ts',
  'e2e/selftest/global-setup.test.ts',
  'e2e/selftest/http.test.ts',
  'e2e/selftest/kubectl-log.test.ts',
  'e2e/selftest/launch.test.ts',
  'e2e/selftest/login-lock.test.ts',
  'e2e/selftest/out.test.ts',
  'e2e/selftest/pace.test.ts',
  'e2e/selftest/reach.test.ts',
  'e2e/selftest/scan-needle.test.ts',
  'e2e/selftest/static-gate.test.ts',
  'e2e/selftest/test-base.test.ts',
  'e2e/selftest/totp-window.test.ts',
  'e2e/selftest/tracked-files.test.ts',
];

const ROOT_FILES = ['package.json', 'pnpm-lock.yaml', 'playwright.config.ts', '.gitignore'];

function git(args: string[]): { status: number | null; out: string } {
  const r = spawnSync('git', ['-C', REPO, ...args], { encoding: 'utf8', shell: false, windowsHide: true });
  return { status: r.status, out: r.stdout ?? '' };
}

test('tracked-files: e2e file set is exactly the reviewed list', () => {
  const r = git(['ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', 'e2e']);
  expect(r.status, 'git ls-files exit').toBe(0);
  const files = r.out.split('\0').filter((s) => s.length > 0).sort();
  const extra = files.filter((f) => !EXPECTED_E2E.includes(f));
  const missing = EXPECTED_E2E.filter((f) => !files.includes(f));
  expect(extra, 'unexpected e2e files').toEqual([]);
  expect(missing, 'missing e2e files').toEqual([]);
});

test('tracked-files: nothing under e2e/.auth is tracked', () => {
  const r = git(['ls-files', '--cached', '-z', '--', 'e2e/.auth']);
  expect(r.status, 'git ls-files exit').toBe(0);
  expect(r.out.split('\0').filter((s) => s.length > 0)).toEqual([]);
});

test('tracked-files: the four root files exist', () => {
  for (const f of ROOT_FILES) expect(fs.existsSync(path.join(REPO, f)), f).toBe(true);
});

test('tracked-files: artifact and secret paths are ignored at any depth (D4)', () => {
  for (const p of [
    'e2e/.auth/t077-x-t077.json',
    'test-results/a/b.txt',
    'apps/web/test-results/a.txt',
    'playwright-report/index.html',
    'apps/web/playwright-report/index.html',
    'blob-report/report.zip',
    '.dev.vars',
    'apps/web/.dev.vars',
    'apps/web/.dev.vars.preview',
  ]) {
    const r = git(['check-ignore', '--no-index', '-q', '--', p]);
    expect(r.status, p).toBe(0);
  }
  const notIgnored = git(['check-ignore', '--no-index', '-q', '--', 'e2e/auth.spec.ts']);
  expect(notIgnored.status, 'e2e/auth.spec.ts must not be ignored').toBe(1);
});
