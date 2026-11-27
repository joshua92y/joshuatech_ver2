// e2e/selftest/global-setup.test.ts — globalSetup 가드(설계 D3 globalSetup ①–⑤ · VD-T077-3 · VD-T077-6) selftest. 순수 함수만.
// r1: 잔여 검사(⑤)는 모든 가드보다 먼저다(리뷰 A-2) — 가드 순서는 setupPlan 표로 고정한다. teardown도 지우기 전에 센다.
import { test, expect } from '@playwright/test';
import * as path from 'node:path';
import { argvGuard, configGuard, envGuard, residueDecision, setupPlan, type SetupObservation } from '../global-setup';
import { teardownDecision } from '../global-teardown';

test('global-setup: env guard reports names of debug, proxy and override variables', () => {
  expect(envGuard({ PATH: 'x', SystemRoot: 'y', PLAYWRIGHT_TEST: '1', PLAYWRIGHT_NO_COPY_PROMPT: '1', DEBUG: 'express:*x' })).toEqual(['DEBUG']);
  expect(envGuard({ PATH: 'x', DEBUG: 'express' })).toEqual([]);
  const flagged: Record<string, string> = {
    PWDEBUG: '1',
    NODE_DEBUG: 'http',
    SSLKEYLOGFILE: 'C:\\k.log',
    NODE_EXTRA_CA_CERTS: 'C:\\ca.pem',
    NODE_TLS_REJECT_UNAUTHORIZED: '0',
    PLAYWRIGHT_BROWSERS_PATH: '0',
    PLAYWRIGHT_DOWNLOAD_HOST: 'x',
    PLAYWRIGHT_CHROMIUM_DOWNLOAD_HOST: 'x',
    http_proxy: 'http://p',
    HTTPS_PROXY: 'http://p',
    All_Proxy: 'http://p',
    NO_PROXY: 'x',
    PLAYWRIGHT_LIST_PRINT_STEPS: '1',
    PW_TEST_REPORTER: 'x',
    PWTEST_CACHE_DIR: 'x',
  };
  for (const [k, v] of Object.entries(flagged)) {
    expect(envGuard({ PATH: 'x', [k]: v }), k).toEqual([k]);
  }
  expect(envGuard({ DEBUG: 'pw:api' })).toEqual(['DEBUG']);
  expect(envGuard({ DEBUG: '*' })).toEqual(['DEBUG']);
  expect(envGuard({ PLAYWRIGHT_TEST: '0' })).toEqual(['PLAYWRIGHT_TEST']);
});

test('global-setup: NODE_OPTIONS — Playwright 1.65.1 adds nothing; only memory flags are tolerated', () => {
  expect(envGuard({})).toEqual([]);
  expect(envGuard({ NODE_OPTIONS: '' })).toEqual([]);
  expect(envGuard({ NODE_OPTIONS: '--max-old-space-size=4096' })).toEqual([]);
  for (const v of ['--inspect', '--inspect-brk=9229', '--require x.js', '-r x', '--import x.mjs', '--experimental-loader x', '--cpu-prof', '--heapsnapshot-signal=SIGUSR2', '--trace-warnings', '--max-old-space-size=4096 --inspect']) {
    expect(envGuard({ NODE_OPTIONS: v }), v).toEqual(['NODE_OPTIONS']);
  }
});

test('global-setup: env guard output is sorted names only', () => {
  const r = envGuard({ PWDEBUG: 'secret-a', HTTPS_PROXY: 'secret-b' });
  expect(r).toEqual(['HTTPS_PROXY', 'PWDEBUG']);
  expect(r.join(',').includes('secret')).toBe(false);
});

test('global-setup: argv guard flags CLI overrides (names only)', () => {
  const base = ['C:\\node.exe', 'C:\\cli.js', 'test', '--config', 'C:\\repo\\playwright.config.ts', '--project=selftest'];
  expect(argvGuard(base)).toEqual([]);
  expect(argvGuard([...base, '--list'])).toEqual([]);
  for (const a of ['--ui', '--ui-port=9000', '--ui-host', '--debug', '--debug=inspector', '--headed', '--trace', '--trace=on', '--reporter', '--reporter=dot', '--add-reporter=json', '--output', '--output=C:\\x', '--workers', '--workers=2', '-j', '-j4', '--retries', '--retries=1', '--repeat-each', '--repeat-each=3', '--tsconfig', '--tsconfig=x.json', '--update-snapshots', '--update-snapshots=all', '-u']) {
    const r = argvGuard([...base, a]);
    expect(r.length, a).toBe(1);
    expect(a.startsWith(r[0]), a).toBe(true);
  }
  // 플래그 값 자리의 글자는 플래그가 아니다(예: --project=update)
  expect(argvGuard([...base, '--project=update-snapshots'])).toEqual([]);
});

const REPO = path.resolve('C:\\repo');
const TMP = path.resolve('C:\\Users\\op\\AppData\\Local\\Temp');

function good() {
  return {
    reporter: [['list', { printSteps: false }]] as unknown[],
    workers: 1,
    preserveOutput: 'never',
    updateSnapshots: 'none',
    projects: [
      {
        name: 'selftest',
        retries: 0,
        outputDir: path.join(TMP, 'jt-e2e', 'r1', 'out'),
        snapshotDir: path.join(TMP, 'jt-e2e', 'r1', 'out', 'snapshots'),
        use: { trace: 'off', video: 'off', screenshot: 'off', launchOptions: { env: { TEMP: 'x' } } } as Record<string, unknown>,
      },
    ],
  };
}

function withProjects(names: string[]) {
  const c = good();
  c.projects = names.map((name) => ({ ...good().projects[0], name }));
  return c;
}

const CTX = { repoRoot: REPO, tmpdir: TMP, jtRoot: undefined as string | undefined, evidenceDir: path.join(TMP, 'jt-e2e', 'r1', 'evidence') };

test('global-setup: config guard accepts the reviewed configuration', () => {
  expect(configGuard(good() as never, CTX)).toEqual([]);
});

test('global-setup: config guard reports overridden fields by name', () => {
  const cases: Array<[(c: ReturnType<typeof good>) => void, string]> = [
    [(c) => { c.reporter = [['dot']]; }, 'reporter'],
    [(c) => { c.reporter = [['list']]; }, 'reporter'],
    [(c) => { c.reporter = [['list', { printSteps: false }], ['json']]; }, 'reporter'],
    [(c) => { c.workers = 2; }, 'workers'],
    [(c) => { c.preserveOutput = 'failures-only'; }, 'preserveOutput'],
    [(c) => { c.projects[0].retries = 1; }, 'projects.selftest.retries'],
    [(c) => { c.projects[0].use.trace = 'on'; }, 'projects.selftest.use.trace'],
    [(c) => { c.projects[0].use.trace = { mode: 'off' }; }, 'projects.selftest.use.trace'],
    [(c) => { c.projects[0].use.video = 'retain-on-failure'; }, 'projects.selftest.use.video'],
    [(c) => { c.projects[0].use.screenshot = 'only-on-failure'; }, 'projects.selftest.use.screenshot'],
    [(c) => { c.projects[0].use.headless = false; }, 'projects.selftest.use.headless'],
    [(c) => { c.projects[0].use.channel = 'chrome'; }, 'projects.selftest.use.channel'],
    [(c) => { c.projects[0].use.launchOptions = { executablePath: 'C:\\x.exe' }; }, 'projects.selftest.use.launchOptions.executablePath'],
    [(c) => { c.projects[0].use.launchOptions = { channel: 'msedge' }; }, 'projects.selftest.use.launchOptions.channel'],
    [(c) => { c.projects[0].outputDir = path.join(REPO, 'test-results'); }, 'projects.selftest.outputDir'],
    [(c) => { c.projects[0].outputDir = 'D:\\elsewhere\\out'; }, 'projects.selftest.outputDir'],
    // 스냅숏 — 기준 이미지를 쓰지 않고(updateSnapshots none) 자리는 저장소 밖(리뷰 C-2 — mask 없는 PNG가 저장소에 남지 않게)
    [(c) => { c.updateSnapshots = 'missing'; }, 'updateSnapshots'],
    [(c) => { c.updateSnapshots = 'all'; }, 'updateSnapshots'],
    [(c) => { c.projects[0].snapshotDir = path.join(REPO, 'e2e'); }, 'projects.selftest.snapshotDir'],
  ];
  for (const [mutate, field] of cases) {
    const c = good();
    mutate(c);
    expect(configGuard(c as never, CTX), field).toEqual([field]);
  }
});

test('global-setup: outputDir and evidence dir may live under the block root JT_E2E_ROOT outside the repo', () => {
  const root = 'D:\\blocks\\t077-x';
  const c = good();
  c.projects[0].outputDir = path.join(root, 'out');
  expect(configGuard(c as never, { ...CTX, jtRoot: root, evidenceDir: path.join(root, 'evidence') })).toEqual([]);
  expect(configGuard(c as never, { ...CTX, jtRoot: path.join(REPO, 'x'), evidenceDir: path.join(REPO, 'x', 'evidence') })).toEqual(['projects.selftest.outputDir', 'evidenceDir']);
  expect(configGuard(good() as never, { ...CTX, evidenceDir: path.join(REPO, 'e2e', 'evidence') })).toEqual(['evidenceDir']);
});

test('global-setup: residue → count line + [state] stop, none when empty', () => {
  expect(residueDecision(0)).toEqual({ kind: 'none' });
  expect(residueDecision(2)).toEqual({ kind: 'stop', prefix: 'state', code: 'previous-run residue count=2', note: 'server session invalidation unconfirmed' });
});

test('global-setup: preserveOutput always is accepted only for a needle run without live (리뷰 B-1 — 실패 산출물을 스캔 면에 남긴다)', () => {
  const needle = withProjects(['selftest', 'selftest-browser', 'needle', 'needle-control']);
  needle.preserveOutput = 'always';
  expect(configGuard(needle as never, CTX)).toEqual([]);
  const selftestOnly = withProjects(['selftest', 'selftest-browser']);
  selftestOnly.preserveOutput = 'always';
  expect(configGuard(selftestOnly as never, CTX)).toEqual(['preserveOutput']);
  const live = withProjects(['selftest', 'selftest-browser', 'live']);
  live.preserveOutput = 'always';
  expect(configGuard(live as never, CTX)).toEqual(['preserveOutput']);
  const both = withProjects(['needle', 'live']);
  both.preserveOutput = 'always';
  expect(configGuard(both as never, CTX)).toEqual(['preserveOutput']);
  const failuresOnly = withProjects(['needle']);
  failuresOnly.preserveOutput = 'failures-only';
  expect(configGuard(failuresOnly as never, CTX)).toEqual(['preserveOutput']);
});

const CLEAN: SetupObservation = { residue: 0, badEnv: [], badArgv: [], badConfig: [], profile: { kind: 'none' }, lock: { kind: 'none' } };

function stops(o: Partial<SetupObservation>) {
  return setupPlan({ ...CLEAN, ...o });
}

test('global-setup: plan order — residue is checked before every guard and always yields its [state] line (리뷰 A-2)', () => {
  expect(stops({})).toEqual([]);
  const residueStop = { kind: 'stop', prefix: 'state', code: 'previous-run residue count=1', note: 'server session invalidation unconfirmed', removeResidue: true };
  // 다른 가드가 함께 걸려도 잔여 줄이 먼저 나오고 거기서 멈춘다(지운 뒤 멈춤 — 노출 의심 신호가 조용히 사라지지 않는다)
  expect(stops({ residue: 1, badEnv: ['NODE_DEBUG'] })).toEqual([residueStop]);
  expect(stops({ residue: 1, badArgv: ['--trace'], badConfig: ['workers'], profile: { kind: 'stop', prefix: 'guard', code: 'profile-env-mismatch USERPROFILE' }, lock: { kind: 'stop', prefix: 'guard', code: 'login-lock present' } })).toEqual([residueStop]);
  expect(stops({ residue: 3, lock: { kind: 'info', text: 'login-lock present' } })).toEqual([{ ...residueStop, code: 'previous-run residue count=3' }]);
});

test('global-setup: plan order — env, argv, config, profile, lock; infos before the first stop are kept', () => {
  const env = { kind: 'stop', prefix: 'guard', code: 'env-not-allowed NODE_DEBUG,PWDEBUG' };
  const argv = { kind: 'stop', prefix: 'guard', code: 'cli-override --trace' };
  const cfg = { kind: 'stop', prefix: 'guard', code: 'config-override workers' };
  expect(stops({ badEnv: ['NODE_DEBUG', 'PWDEBUG'], badArgv: ['--trace'], badConfig: ['workers'] })).toEqual([env]);
  expect(stops({ badArgv: ['--trace'], badConfig: ['workers'] })).toEqual([argv]);
  expect(stops({ badConfig: ['workers'], lock: { kind: 'stop', prefix: 'guard', code: 'login-lock present' } })).toEqual([cfg]);
  expect(stops({ profile: { kind: 'info', text: 'profile-env-mismatch USERPROFILE' }, lock: { kind: 'info', text: 'login-lock present' } })).toEqual([
    { kind: 'info', text: 'profile-env-mismatch USERPROFILE' },
    { kind: 'info', text: 'login-lock present' },
  ]);
  expect(stops({ profile: { kind: 'stop', prefix: 'guard', code: 'profile-env-mismatch LOCALAPPDATA' }, lock: { kind: 'stop', prefix: 'guard', code: 'login-lock present' } })).toEqual([
    { kind: 'stop', prefix: 'guard', code: 'profile-env-mismatch LOCALAPPDATA' },
  ]);
  expect(stops({ lock: { kind: 'stop', prefix: 'guard', code: 'login-lock present' } })).toEqual([{ kind: 'stop', prefix: 'guard', code: 'login-lock present', note: 'operator check' }]);
});

test('global-teardown: residue found at teardown is reported as [state] before it is removed, and fails the run', () => {
  expect(teardownDecision(0)).toEqual({ fail: false });
  expect(teardownDecision(2)).toEqual({ fail: true, state: { prefix: 'state', code: 'auth-residue at teardown count=2', note: 'removed - server session invalidation unconfirmed' } });
});
