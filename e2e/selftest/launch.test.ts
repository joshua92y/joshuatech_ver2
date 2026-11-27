// e2e/selftest/launch.test.ts — 런처 launch.mjs의 순수 함수(설계 D9 · D10 ⑧ · r2 — V-3 · V-6 · 컨트롤러 N-1) selftest. 브라우저 0 · 네트워크 0.
// launch.mjs는 import.meta를 쓰는 ESM이라 동적 import로 싣는다(Playwright의 CJS require 훅은 .mjs를 CommonJS로 바꿔 import.meta에서 깨진다 — 1.65.1 실측).
import { test as base, expect } from '@playwright/test';
import * as path from 'node:path';
import { CONTROL_PREFIX, NAMES, NEEDLE_PREFIX as CONTRACT_PREFIX } from '../lib/env-contract';
import { validateSiteTarget } from '../lib/site';
import { SITE_TARGET_GUARD } from '../../playwright.config';

type Launch = typeof import('../lib/launch.mjs');
type Scan = typeof import('../lib/scan-needle.mjs');

const test = base.extend<{ L: Launch; S: Scan }>({
  L: async ({}, use) => {
    await use(await import('../lib/launch.mjs'));
  },
  S: async ({}, use) => {
    await use(await import('../lib/scan-needle.mjs'));
  },
});

const TMP = 'C:\\Users\\op\\AppData\\Local\\Temp';
const RUN = 't077-20261123T090000Z-a1b2c3';
const ESC = String.fromCharCode(27);

function source(): Record<string, string> {
  return {
    SystemRoot: 'C:\\Windows',
    PATH: 'C:\\Windows\\system32',
    USERPROFILE: 'C:\\Users\\op',
    LOCALAPPDATA: 'C:\\Users\\op\\AppData\\Local',
    TEMP: TMP,
    TMP: TMP,
    KUBECONFIG: 'C:\\Users\\op\\.kube\\agent-view',
    [NAMES.password]: 'leak-pw',
    [NAMES.block]: 'x.ps1',
    [NAMES.needleSet]: '{}',
    HTTPS_PROXY: 'http://proxy',
    NODE_OPTIONS: '--inspect',
    GITHUB_TOKEN: 'leak',
    // T087 — 런처 env의 site 값은 site 모드가 넘기는 대상(target)으로만 자식에 간다(다른 모드 · source 직접 복사 0)
    BASE_URL: 'http://leak.example',
    JT_E2E_SITE: '1',
    JT_E2E_SITE_MODE: 'prod',
  };
}

const LIVE_RED_NAMES = [
  'JT_E2E_EVIDENCE_DIR', 'JT_E2E_LIVE', 'JT_E2E_OUTPUT_DIR', 'JT_E2E_ROOT', 'JT_E2E_RUN_ID',
  'LOCALAPPDATA', 'PATH', 'SystemRoot', 'TEMP', 'TMP', 'USERPROFILE',
];

test('launch: allowlist constants (D9 — r2 — V-3 · V-4)', ({ L }) => {
  expect(L.BASE_ENV_NAMES).toEqual(['SystemRoot', 'PATH', 'USERPROFILE', 'LOCALAPPDATA', 'TEMP', 'TMP']);
  expect(L.COMMON_ENV_NAMES).toEqual(['JT_E2E_RUN_ID', 'JT_E2E_ROOT', 'JT_E2E_OUTPUT_DIR', 'JT_E2E_EVIDENCE_DIR']);
  expect(L.NEEDLE_PREFIX).toBe(CONTRACT_PREFIX);
});

test('launch: layout keeps outputDir, evidence, logs and child TEMP under one root in tmp', ({ L }) => {
  const l = L.planLayout(TMP, RUN);
  expect(l.root).toBe(path.join(TMP, 'jt-e2e', RUN));
  for (const k of ['out', 'evidence', 'logs', 'tmp'] as const) expect(path.dirname(l[k]), k).toBe(l.root);
});

test('launch: live-red child env is exactly the allowlist + JT_E2E_LIVE (no KUBECONFIG, secrets, block or needle set)', ({ L }) => {
  const l = L.planLayout(TMP, RUN);
  const env = L.buildChildEnv(source(), l, RUN, L.modeValues('live-red'));
  expect(Object.keys(env).sort()).toEqual(LIVE_RED_NAMES);
  expect(L.expectedEnvNames('live-red')).toEqual(LIVE_RED_NAMES);
  expect(env.TEMP).toBe(l.tmp);
  expect(env.TMP).toBe(l.tmp);
  expect(env.JT_E2E_ROOT).toBe(l.root);
  expect(env.JT_E2E_OUTPUT_DIR).toBe(l.out);
  expect(env.JT_E2E_EVIDENCE_DIR).toBe(l.evidence);
  expect(env.JT_E2E_RUN_ID).toBe(RUN);
  expect(env.JT_E2E_LIVE).toBe('1');
});

test('launch: selftest and list child env carry no mode secrets', ({ L }) => {
  const l = L.planLayout(TMP, RUN);
  const baseNames = [...L.BASE_ENV_NAMES, ...L.COMMON_ENV_NAMES].sort();
  expect(Object.keys(L.buildChildEnv(source(), l, RUN, L.modeValues('selftest'))).sort()).toEqual(baseNames);
  expect(Object.keys(L.buildChildEnv(source(), l, RUN, L.modeValues('selftest-browser'))).sort()).toEqual(baseNames);
  expect(Object.keys(L.buildChildEnv(source(), l, RUN, L.modeValues('list-live'))).sort()).toEqual([...baseNames, 'JT_E2E_LIVE'].sort());
  expect(Object.keys(L.buildChildEnv(source(), l, RUN, L.modeValues('list-needle'))).sort()).toEqual([...baseNames, 'JT_E2E_NEEDLE'].sort());
});

test('launch: needle child env carries launcher-made needles under the real contract names', ({ L }) => {
  const set = L.makeNeedleSet();
  const env = L.buildChildEnv(source(), L.planLayout(TMP, RUN), RUN, L.modeValues('needle', set));
  expect(env.JT_E2E_NEEDLE).toBe('1');
  expect(env[NAMES.password]).toBe(set.password);
  expect(env[NAMES.codes]).toBe(set.codes);
  expect(env[NAMES.step0]).toBe(set.step0);
  expect(JSON.parse(env[NAMES.needleSet] as string)).toEqual(set);
  expect(env.KUBECONFIG).toBeUndefined();
  expect(env[NAMES.block]).toBeUndefined();
});

test('launch: a missing base variable is refused', ({ L }) => {
  const s: Record<string, string | undefined> = source();
  delete s.SystemRoot;
  expect(() => L.buildChildEnv(s, L.planLayout(TMP, RUN), RUN, L.modeValues('selftest'))).toThrow(/SystemRoot/);
});

// 대조 바늘 — 노출 경로마다 하나(리뷰 B-1). 꼬리표는 16진 글자로 시작하지 않아 가장 짧은 조각(고정 7자 + 난수 1자)이 경로끼리 겹치지 않는다.
const CONTROL_FIELDS = ['control', 'controlFill', 'controlRequest', 'controlSetCookie', 'controlUrl', 'controlGoto', 'controlFile'] as const;

test('launch: needle set shapes are fixed, values random per run', ({ L }) => {
  const a = L.makeNeedleSet();
  const b = L.makeNeedleSet();
  const esc = (s: string) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const P = esc(L.NEEDLE_PREFIX);
  expect(new RegExp('^' + P + 'pw-[0-9a-f]{12}$').test(a.password)).toBe(true);
  expect(new RegExp('^' + P + 'ck-[0-9a-f]{16}$').test(a.cookie)).toBe(true);
  expect(new RegExp('^' + P + 'az-[0-9a-f]{16}$').test(a.authorization)).toBe(true);
  expect(new RegExp('^' + P + 'q-[0-9a-f]{12}$').test(a.query)).toBe(true);
  expect(new RegExp('^' + P + 'UA/[0-9a-f]{8}$').test(a.ua)).toBe(true);
  expect(/^203\.0\.113\.([1-9]|[1-9]\d|1\d\d|2[0-4]\d|25[0-4])$/.test(a.ip)).toBe(true);
  expect(/^\d{6}(,\d{6}){19}$/.test(a.codes)).toBe(true);
  expect(/^\d+$/.test(a.step0)).toBe(true);
  expect(Object.keys(L.CONTROL_TAGS).sort()).toEqual([...CONTROL_FIELDS].sort());
  const tags = new Set<string>();
  for (const f of CONTROL_FIELDS) {
    const tag = L.CONTROL_TAGS[f] as string;
    expect(tag.startsWith('ctl-') && tag.endsWith('-'), f).toBe(true);
    expect(/^ctl-[g-z][a-z]*-$/.test(tag), `${f} tag starts with a non-hex letter`).toBe(true);
    tags.add(tag);
    expect(new RegExp('^' + esc(CONTROL_PREFIX) + esc(tag.slice('ctl-'.length)) + '[0-9a-f]{12}$').test(a[f]), f).toBe(true);
  }
  expect(tags.size).toBe(CONTROL_FIELDS.length);
  for (const k of ['password', 'cookie', 'authorization', 'query', 'ua', ...CONTROL_FIELDS] as const) expect(a[k] === b[k], k).toBe(false);
});

test('launch: run 1 scans every needle except the controls; each control path is scanned on its own surface; roots differ (N-1)', ({ L }) => {
  const set = L.makeNeedleSet();
  const run1 = L.needleSpecs(set, 'run1') as Array<{ value: string; kind: string; fixed?: number }>;
  for (const f of CONTROL_FIELDS) expect(run1.some((s) => s.value === set[f]), f).toBe(false);
  expect(run1.some((s) => s.value === set.password)).toBe(true);
  expect(run1.filter((s) => s.kind === 'code').length).toBe(20);
  expect(run1.find((s) => s.value === set.ip)?.kind).toBe('exact');
  expect(run1.find((s) => s.value === set.ua)?.kind).toBe('exact');
  const pw = run1.find((s) => s.value === set.password);
  expect(pw?.kind).toBe('fragment');
  expect(pw?.fixed).toBe((L.NEEDLE_PREFIX + 'pw-').length);
  const ctl = L.controlSpecs(set) as Record<string, Array<{ value: string; kind: string; fixed?: number }>>;
  expect(Object.keys(ctl).sort()).toEqual([...CONTROL_FIELDS].sort());
  for (const f of CONTROL_FIELDS) {
    expect(ctl[f].map((s) => s.value), f).toEqual([set[f]]);
    expect(ctl[f][0].kind).toBe('fragment');
    expect(ctl[f][0].fixed, f).toBe((L.NEEDLE_PREFIX + L.CONTROL_TAGS[f]).length);
  }
  // 메시지 경로는 로그 면, 페이지 스냅숏 경로는 보존된 산출물(루트 면)에서 잡혀야 한다
  expect(L.CONTROL_SURFACE).toEqual({ control: 'log', controlFill: 'log', controlRequest: 'log', controlSetCookie: 'log', controlUrl: 'log', controlGoto: 'log', controlFile: 'root' });
  const plan = L.planNeedleRuns(TMP, RUN);
  expect(plan.run1.root === plan.run2.root).toBe(false);
  expect(path.dirname(plan.run1.root)).toBe(path.join(TMP, 'jt-e2e'));
  expect(path.dirname(plan.run2.root)).toBe(path.join(TMP, 'jt-e2e'));
});

test('launch: a control needle never matches another needle of the same run (per-path attribution — 20 random sets)', ({ L, S }) => {
  for (let i = 0; i < 20; i += 1) {
    const set = L.makeNeedleSet();
    const ctl = L.controlSpecs(set) as Record<string, Array<{ value: string; kind: 'fragment'; fixed?: number }>>;
    const others = [...CONTROL_FIELDS.map((f) => set[f]), set.password, set.cookie, set.authorization, set.query, set.ua];
    for (const f of CONTROL_FIELDS) {
      for (const v of others) {
        if (v === set[f]) continue;
        expect(S.countText(`x ${v} y`, ctl[f]), `${f} vs other needle`).toBe(0);
      }
    }
    // 6자리 코드 바늘은 숫자 경계 전체 일치라 난수 16진에 우연히 들 확률(실행당 약 1e-4)이 있어 이 성질 시험에서는 뺀다
    const run1 = (L.needleSpecs(set, 'run1') as Array<{ value: string; kind: 'fragment' | 'exact' | 'code'; fixed?: number }>).filter((s) => s.kind !== 'code');
    for (const f of CONTROL_FIELDS) expect(S.countText(`x ${set[f]} y`, run1), `run1 needles vs ${f}`).toBe(0);
  }
});

const LIST_OUT = [
  '',
  'Running 9 tests using 1 worker',
  '',
  '  ok 1 [selftest] › e2e\\selftest\\a.test.ts:5:1 › a (4ms)',
  '  x  2 [needle] › e2e\\needle\\needle.test.ts:9:1 › nd-1 secret input fails (2ms)',
  '',
  '',
  '  1) [needle] › e2e\\needle\\needle.test.ts:9:1 › nd-1 secret input fails ─────────────────────',
  '',
  '    Error: secret-input password failed',
  '',
  '       9 | test(...)',
  '        at C:\\repo\\e2e\\needle\\needle.test.ts:11:30',
  '',
  '    Error Context: ..\\out\\needle-nd-1\\error-context.md',
  '',
  '  2) [needle] › e2e\\needle\\needle.test.ts:20:1 › nd-3 connection drop with needle headers ─────',
  '',
  '    ' + ESC + '[31mError: GET http://127.0.0.1:51234/nd-3 failed (reset)' + ESC + '[39m',
  '',
  '  2 failed',
  '    [needle] › e2e\\needle\\needle.test.ts:9:1 › nd-1 secret input fails ──────────────',
  '    [needle] › e2e\\needle\\needle.test.ts:20:1 › nd-3 connection drop with needle headers ───',
  '  1 skipped',
  '  6 passed (5.1s)',
  '',
].join('\n');

test('launch: parseSummary reads the list reporter summary (ANSI stripped); none → null', ({ L }) => {
  expect(L.parseSummary(LIST_OUT)).toEqual({ passed: 6, failed: 2, flaky: 0, skipped: 1, interrupted: 0, didNotRun: 0, errors: 0 });
  expect(L.parseSummary('Error: No tests found\n')).toBeNull();
  expect(L.parseSummary('  3 passed (1s)\n  1 error was not a part of any test, see above for details\n')).toEqual({ passed: 3, failed: 0, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 1 });
  expect(L.parseSummary('INFO 5 passed, 0 failed\n  5 passed (1s)\n')?.passed).toBe(5);
});

test('launch: parseFailures returns title + first error line, port normalized', ({ L }) => {
  expect(L.parseFailures(LIST_OUT)).toEqual([
    { title: 'nd-1 secret input fails', message: 'secret-input password failed' },
    { title: 'nd-3 connection drop with needle headers', message: 'GET http://127.0.0.1:<port>/nd-3 failed (reset)' },
  ]);
});

test('launch: selftest end line counts every non-pass outcome as failed', ({ L }) => {
  expect(L.selftestEndLine({ passed: 6, failed: 2, flaky: 0, skipped: 1, interrupted: 0, didNotRun: 0, errors: 0 })).toBe('6 passed, 3 failed');
  expect(L.selftestEndLine({ passed: 10, failed: 0, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 0 })).toBe('10 passed, 0 failed');
  expect(L.selftestEndLine({ passed: 0, failed: 0, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 0 })).toBe('0 passed, 1 failed');
  expect(L.selftestEndLine(null)).toBe('0 passed, 1 failed');
});

test('launch: parseListCounts counts tests per project and checks the total', ({ L }) => {
  const out = [
    'Listing tests:',
    '  [selftest] › e2e\\selftest\\a.test.ts:5:1 › a',
    '  [selftest] › e2e\\selftest\\a.test.ts:9:1 › b',
    '  [live] › e2e\\auth.spec.ts:40:1 › T077 login',
    'Total: 3 tests in 2 files',
    '',
  ].join('\n');
  expect(L.parseListCounts(out)).toEqual({ selftest: 2, live: 1 });
  expect(L.parseListCounts(out.replace('Total: 3', 'Total: 4'))).toBeNull();
  expect(L.parseListCounts('Error: x')).toBeNull();
});

test('launch: relay passes only out.ts shapes', ({ L }) => {
  const text = [
    'T077 reach FAIL [gate] authentik-absent until T080 — 서명 일치',
    'INFO auth-residue 0',
    '[guard] login-lock present — operator check',
    'SUMMARY T077 x',
    '7 passed, 0 failed',
    'needle=PASS',
    'Error: boom',
    '  ok 1 [selftest] › a',
    'cookie: x',
  ].join('\n');
  expect(L.relay(text)).toEqual([
    'T077 reach FAIL [gate] authentik-absent until T080 — 서명 일치',
    'INFO auth-residue 0',
    '[guard] login-lock present — operator check',
    'SUMMARY T077 x',
  ]);
});

function zeroHits() {
  return { log: 0, root: 0, 'test-results': 0, auth: 0, 'tmp-playwright': 0, 'git-status': 0 };
}

function passing(L: Launch) {
  const failures = Object.entries(L.EXPECTED_NEEDLE_FAILURES).map(([title, message]) => ({ title, message: message as string }));
  const controlFailures = Object.entries(L.EXPECTED_CONTROL_FAILURES).map(([title, message]) => ({ title, message: message as string }));
  const controlHits: Record<string, Record<string, number>> = {};
  for (const f of CONTROL_FIELDS) controlHits[f] = { ...zeroHits(), [L.CONTROL_SURFACE[f] as string]: 2 };
  const n1 = failures.length;
  const nc = Object.keys(L.CONTROL_SURFACE).length;
  return {
    run1: { exit: 1, summary: { passed: 0, failed: n1, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 0 }, failures, hits: zeroHits(), artifacts: 0 },
    run2: {
      exit: 1,
      summary: { passed: nc - controlFailures.length, failed: controlFailures.length, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 0 },
      failures: controlFailures,
      controlHits,
      otherHits: zeroHits(),
      artifacts: 1,
    },
  };
}

test('launch: nine intended needle failures (nd-1 … nd-8 with nd-3b) and one intended control failure are expected (리뷰 B-1)', ({ L }) => {
  expect(Object.keys(L.EXPECTED_NEEDLE_FAILURES).length).toBe(9);
  for (const t of Object.keys(L.EXPECTED_NEEDLE_FAILURES)) expect(/^nd-([1-8]|3b) /.test(t), t).toBe(true);
  expect(Object.keys(L.EXPECTED_NEEDLE_FAILURES).map((t) => t.split(' ')[0])).toEqual(['nd-1', 'nd-2', 'nd-3', 'nd-3b', 'nd-4', 'nd-5', 'nd-6', 'nd-7', 'nd-8']);
  expect(L.EXPECTED_NEEDLE_FAILURES['nd-3b connection drop after needle response headers']).toBe('GET http://127.0.0.1:<port>/nd-3b failed (reset)');
  expect(Object.keys(L.EXPECTED_CONTROL_FAILURES)).toEqual(['c-pgs page snapshot of a failed test lands in the preserved output']);
});

test('launch: judgeNeedle PASS only when every condition holds', ({ L }) => {
  const ok = L.judgeNeedle(passing(L));
  expect(ok.pass).toBe(true);
  expect(ok.line.startsWith('needle=PASS ')).toBe(true);
  expect(ok.line.includes('run1-messages=9/9')).toBe(true);
  expect(ok.line.includes(' run1-artifacts=0 ')).toBe(true);
  expect(ok.line.includes(' run2-messages=1/1 ')).toBe(true);
  expect(ok.line.includes(' controls=log@log:2,inp@log:2,req@log:2,sck@log:2,url@log:2,nav@log:2,pgs@root:2 ')).toBe(true);
  expect(ok.line.includes(' run2-artifacts=1 ')).toBe(true);
  const fails: Array<[string, (x: ReturnType<typeof passing>) => void]> = [
    ['run1 exit 0', (x) => { x.run1.exit = 0; }],
    ['eight failures', (x) => { x.run1.summary.failed = 8; x.run1.failures.pop(); }],
    ['message mismatch', (x) => { x.run1.failures[0] = { title: x.run1.failures[0].title, message: 'browserType.launch: Executable does not exist' }; }],
    ['duplicate title', (x) => { x.run1.failures[1] = { ...x.run1.failures[0] }; }],
    ['run1 hit in root', (x) => { x.run1.hits.root = 1; }],
    ['run1 hit in git status', (x) => { x.run1.hits['git-status'] = 1; }],
    ['run1 binary artifact (trace zip / video / png) in the root', (x) => { x.run1.artifacts = 1; }],
    ['a message-path control only outside the log', (x) => { x.run2.controlHits.controlUrl.log = 0; x.run2.controlHits.controlUrl.root = 3; }],
    ['the page-snapshot control not in the preserved root', (x) => { x.run2.controlHits.controlFile.root = 0; x.run2.controlHits.controlFile.log = 3; }],
    ['the console control missing', (x) => { x.run2.controlHits.control.log = 0; }],
    ['the fill control missing', (x) => { x.run2.controlHits.controlFill.log = 0; }],
    ['the request-header control missing', (x) => { x.run2.controlHits.controlRequest.log = 0; }],
    ['the set-cookie control missing', (x) => { x.run2.controlHits.controlSetCookie.log = 0; }],
    ['the redirect-navigation control missing', (x) => { x.run2.controlHits.controlGoto.log = 0; }],
    ['a control scan error', (x) => { x.run2.controlHits.controlFill.auth = -1; }],
    ['run2 leaks another needle', (x) => { x.run2.otherHits.log = 1; }],
    ['run2 without the intended control failure', (x) => { x.run2.exit = 0; x.run2.summary.failed = 0; x.run2.summary.passed += 1; x.run2.failures = []; }],
    ['run2 control failure message differs', (x) => { x.run2.failures[0] = { title: x.run2.failures[0].title, message: 'something else' }; }],
    ['run2 extra failure', (x) => { x.run2.summary.failed = 2; x.run2.summary.passed -= 1; x.run2.failures.push({ title: 'c-inp raw fill exposes the value in its error', message: 'control controlFill did not expose its needle' }); }],
    ['run2 artifact positive control missing', (x) => { x.run2.artifacts = 0; }],
    ['scan error', (x) => { x.run1.hits.auth = -1; }],
  ];
  for (const [name, mutate] of fails) {
    const x = passing(L);
    mutate(x);
    const r = L.judgeNeedle(x);
    expect(r.pass, name).toBe(false);
    expect(r.line.startsWith('needle=FAIL '), name).toBe(true);
  }
});

const GATE = 'authentik-absent until T080';

test('launch: live-red counts the reach [gate] lines — the right reason for the red (리뷰 A-3)', ({ L }) => {
  const lines = [
    `T077 reach FAIL [gate] ${GATE} — Traefik 404 signature (T076 D10) matched`,
    `T079 reach-auth FAIL [gate] ${GATE} — Traefik 404 signature (T076 D10) matched`,
    `T079 reach-auth FAIL [gate] ${GATE}`,
    'T079 reach-auth FAIL [product] reach-unexpected status=404 mismatch=sha256',
    'T077 reach FAIL [env] origin status=522',
    'INFO reach-control status=401 — edge response - not origin evidence',
    `T078 reach FAIL [gate] ${GATE}`,
    `T077 cred FAIL [gate] ${GATE}`,
    `T077 reach PASS authentik-redirect`,
    `T079 reach-auth FAIL [gate] ${GATE} until later`,
    `INFO T077 reach FAIL [gate] ${GATE}`,
  ];
  expect(L.countGateReach(lines)).toBe(3);
  expect(L.countGateReach([])).toBe(0);
});

test('launch: live-red end line carries gate-reach=<n>/<live tests>; exit stays per D9', ({ L }) => {
  const s = { passed: 0, failed: 3, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 0 };
  expect(L.liveRedEndLine({ summary: s, gateReach: 3, exit: 1, residue: true, cleaned: true })).toBe('live-red passed=0 failed=3 gate-reach=3/3 child-exit=1 auth-residue=ok root=removed');
  expect(L.liveRedEndLine({ summary: { ...s, failed: 2, didNotRun: 1 }, gateReach: 1, exit: 1, residue: false, cleaned: false })).toBe('live-red passed=0 failed=3 gate-reach=1/3 child-exit=1 auth-residue=missing root=left');
  expect(L.liveRedEndLine({ summary: null, gateReach: 0, exit: 1, residue: true, cleaned: true })).toBe('live-red passed=0 failed=-1 gate-reach=0/-1 child-exit=1 auth-residue=ok root=removed');
});

test('launch: CLI is resolved to an absolute path from the repo root; a root without @playwright/test → null (SKIP path)', ({ L }, testInfo) => {
  const r = L.resolveCli();
  expect(r?.version).toBe('1.65.1');
  expect(path.isAbsolute(r?.cli ?? '')).toBe(true);
  expect(path.basename(r?.cli ?? '')).toBe('cli.js');
  expect(L.resolveCli(testInfo.outputPath('no-such-root'))).toBeNull();
});

// ---- T087(설계 t086-design.md D10 ③) — site · site-red · list의 site 실행 ----
const SITE_NAMES = [
  'BASE_URL', 'JT_E2E_EVIDENCE_DIR', 'JT_E2E_OUTPUT_DIR', 'JT_E2E_ROOT', 'JT_E2E_RUN_ID', 'JT_E2E_SITE', 'JT_E2E_SITE_MODE',
  'LOCALAPPDATA', 'PATH', 'SystemRoot', 'TEMP', 'TMP', 'USERPROFILE',
];
const SITE_SUMMARY = { passed: 8, failed: 0, flaky: 0, skipped: 1, interrupted: 0, didNotRun: 0, errors: 0 };

test('launch: modes include site and site-red; site env names are JT_E2E_SITE · BASE_URL · JT_E2E_SITE_MODE', ({ L }) => {
  expect(L.MODES).toEqual(['selftest', 'selftest-browser', 'needle', 'list', 'live-red', 'site', 'site-red']);
  expect(L.SITE_ENV_NAMES).toEqual(['JT_E2E_SITE', 'BASE_URL', 'JT_E2E_SITE_MODE']);
});

test('launch: site and site-red child env = allowlist + the three site names, values from the target (no KUBECONFIG, secrets, block or needle set)', ({ L }) => {
  const l = L.planLayout(TMP, RUN);
  const target = { base: 'http://127.0.0.1:3000', mode: 'local' };
  for (const mode of ['site', 'site-red']) {
    const env = L.buildChildEnv(source(), l, RUN, L.modeValues(mode, target));
    expect(Object.keys(env).sort(), mode).toEqual(SITE_NAMES);
    expect(L.expectedEnvNames(mode), mode).toEqual(SITE_NAMES);
    expect(env.JT_E2E_SITE).toBe('1');
    expect(env.BASE_URL).toBe(target.base);
    expect(env.JT_E2E_SITE_MODE).toBe('local');
  }
  expect(() => L.modeValues('site')).toThrow();
  expect(() => L.modeValues('site-red', { base: 'http://127.0.0.1:3000' })).toThrow();
});

test('launch: selftest, live and needle runs never carry the site names even when the launcher env has them', ({ L }) => {
  const l = L.planLayout(TMP, RUN);
  for (const mode of ['selftest', 'selftest-browser', 'list-live', 'list-needle', 'live-red']) {
    const env = L.buildChildEnv(source(), l, RUN, L.modeValues(mode));
    for (const n of L.SITE_ENV_NAMES) expect(Object.prototype.hasOwnProperty.call(env, n), `${mode} ${n}`).toBe(false);
  }
});

test('launch: list-site uses the launcher constant target http://127.0.0.1:9 · local', ({ L }) => {
  expect(L.LIST_SITE_TARGET).toEqual({ base: 'http://127.0.0.1:9', mode: 'local' });
  expect(L.modeValues('list-site')).toEqual({ JT_E2E_SITE: '1', BASE_URL: 'http://127.0.0.1:9', JT_E2E_SITE_MODE: 'local' });
  expect(Object.keys(L.buildChildEnv(source(), L.planLayout(TMP, RUN), RUN, L.modeValues('list-site'))).sort()).toEqual(SITE_NAMES);
});

test('launch: site mode reads BASE_URL and JT_E2E_SITE_MODE from the launcher env (case-insensitive names); either missing → null', ({ L }) => {
  expect(L.readSiteTarget({ BASE_URL: 'http://127.0.0.1:3000', JT_E2E_SITE_MODE: 'local' })).toEqual({ base: 'http://127.0.0.1:3000', mode: 'local' });
  expect(L.readSiteTarget({ base_url: 'https://joshuatech.dev', jt_e2e_site_mode: 'prod' })).toEqual({ base: 'https://joshuatech.dev', mode: 'prod' });
  expect(L.readSiteTarget({ BASE_URL: 'http://127.0.0.1:3000' })).toBeNull();
  expect(L.readSiteTarget({ JT_E2E_SITE_MODE: 'local' })).toBeNull();
  expect(L.readSiteTarget({ BASE_URL: '', JT_E2E_SITE_MODE: 'local' })).toBeNull();
  expect(L.readSiteTarget({})).toBeNull();
});

// 런처의 사전 검사는 설정의 validateSiteTarget(정본 — e2e/lib/site.ts)과 같은 판정이어야 한다(값 없이 [guard] 줄로 일찍 멈출 뿐)
const TARGET_CASES: Array<[unknown, unknown]> = [
  ['http://127.0.0.1:3000', 'local'],
  ['http://localhost:3000', 'local'],
  ['http://127.0.0.1:1', 'local'],
  ['http://localhost:65535', 'local'],
  ['https://joshuatech.dev', 'prod'],
  ['http://127.0.0.1:3000/', 'local'],
  ['http://127.0.0.1:3000/ko', 'local'],
  ['http://127.0.0.1:3000?x=1', 'local'],
  ['http://127.0.0.1:3000#x', 'local'],
  ['https://127.0.0.1:3000', 'local'],
  ['http://127.0.0.2:3000', 'local'],
  ['http://0.0.0.0:3000', 'local'],
  ['http://[::1]:3000', 'local'],
  ['http://localhost', 'local'],
  ['http://127.0.0.1:0', 'local'],
  ['http://127.0.0.1:65536', 'local'],
  ['http://127.0.0.1:03000', 'local'],
  ['http://localhost:80', 'local'],
  ['http://user@127.0.0.1:3000', 'local'],
  ['HTTP://LOCALHOST:3000', 'local'],
  ['http://localhost.:3000', 'local'],
  [' http://127.0.0.1:3000', 'local'],
  ['https://joshuatech.dev', 'local'],
  ['http://127.0.0.1:3000', 'prod'],
  ['https://joshuatech.dev/', 'prod'],
  ['https://www.joshuatech.dev', 'prod'],
  ['http://joshuatech.dev', 'prod'],
  ['https://preview.joshuatech.dev', 'prod'],
  ['https://joshuatech.dev:443', 'prod'],
  ['http://127.0.0.1:3000', 'Local'],
  ['http://127.0.0.1:3000', ''],
  ['http://127.0.0.1:3000', '__proto__'],
  ['http://127.0.0.1:3000', undefined],
  [undefined, 'local'],
  ['', 'local'],
];

test('launch: the site pre-check agrees with validateSiteTarget on every case and prints the guard without the value', ({ L }) => {
  for (const [b, m] of TARGET_CASES) {
    expect(L.siteTargetAllowed({ base: b, mode: m }), `${String(b)} ${String(m)}`).toBe(validateSiteTarget(b, m).ok);
  }
  expect(L.siteTargetAllowed(null)).toBe(false);
  expect(L.SITE_TARGET_GUARD_LINE.startsWith('[guard] site-target-not-allowed — ')).toBe(true);
  expect(L.SITE_TARGET_GUARD_LINE.includes('127.0.0.1:3000')).toBe(false);
  // 런처 줄과 설정 가드 글자는 같다(어느 쪽에서 멈춰도 같은 이유를 읽는다)
  expect(L.SITE_TARGET_GUARD_LINE).toBe(SITE_TARGET_GUARD);
});

test('launch: allowed skip = 1 only for a local run that printed the exact health-skip INFO line', ({ L }) => {
  const lines = ['T087 reach PASS site-v2', 'INFO T087 health skipped mode=local'];
  expect(L.SITE_HEALTH_SKIP_LINE).toBe('INFO T087 health skipped mode=local');
  expect(L.allowedSkip('local', lines)).toBe(1);
  expect(L.allowedSkip('prod', lines)).toBe(0);
  expect(L.allowedSkip('local', ['T087 reach PASS site-v2'])).toBe(0);
  expect(L.allowedSkip('local', ['INFO T087 health skipped mode=prod'])).toBe(0);
  expect(L.allowedSkip('local', ['xINFO T087 health skipped mode=local'])).toBe(0);
});

test('launch: site end line and exit — 0 only when the child passed, nothing failed, the only skip is the allowed one, something passed and the root is gone', ({ L }) => {
  const ok = { summary: SITE_SUMMARY, allowed: 1, exit: 0, cleaned: true };
  expect(L.siteEndLine(ok)).toBe('site passed=8 failed=0 skipped=1 allowed-skip=1 child-exit=0 root=removed');
  expect(L.siteOk(ok)).toBe(true);
  // prod 실행 = skip 0
  expect(L.siteOk({ summary: { ...SITE_SUMMARY, passed: 9, skipped: 0 }, allowed: 0, exit: 0, cleaned: true })).toBe(true);
  const bad: Array<[string, Record<string, unknown>]> = [
    ['child exit 1', { ...ok, exit: 1 }],
    ['a failure', { ...ok, summary: { ...SITE_SUMMARY, passed: 7, failed: 1 } }],
    ['flaky', { ...ok, summary: { ...SITE_SUMMARY, passed: 7, flaky: 1 } }],
    ['interrupted', { ...ok, summary: { ...SITE_SUMMARY, passed: 7, interrupted: 1 } }],
    ['did not run', { ...ok, summary: { ...SITE_SUMMARY, passed: 7, didNotRun: 1 } }],
    ['error outside tests', { ...ok, summary: { ...SITE_SUMMARY, errors: 1 } }],
    ['skip not allowed (prod or no INFO line)', { ...ok, allowed: 0 }],
    ['two skips', { ...ok, summary: { ...SITE_SUMMARY, passed: 7, skipped: 2 } }],
    ['nothing passed', { ...ok, summary: { ...SITE_SUMMARY, passed: 0 } }],
    ['no summary', { ...ok, summary: null }],
    ['root left', { ...ok, cleaned: false }],
  ];
  for (const [name, x] of bad) expect(L.siteOk(x), name).toBe(false);
  expect(L.siteEndLine({ summary: { ...SITE_SUMMARY, passed: 6, failed: 1, interrupted: 1 }, allowed: 1, exit: 1, cleaned: false })).toBe('site passed=6 failed=2 skipped=1 allowed-skip=1 child-exit=1 root=left');
  expect(L.siteEndLine({ summary: null, allowed: 0, exit: 1, cleaned: true })).toBe('site passed=0 failed=-1 skipped=0 allowed-skip=0 child-exit=1 root=removed');
});

const SITE_GATE = 'T087 reach FAIL [gate] site-absent until T091';

test('launch: site-red counts only the reach [gate] site-absent lines (the right reason for the red) and prints gate-site=<g>/<failed>', ({ L }) => {
  const lines = [
    `${SITE_GATE} — loopback refused and apps/web scaffold absent (next.config.ts)`,
    SITE_GATE,
    'T087 reach FAIL [env] site-server-not-running',
    'T087 reach FAIL [env] network (timeout)',
    'T087 reach FAIL [product] reach-unexpected status=200',
    `${SITE_GATE} until later`,
    `INFO ${SITE_GATE}`,
    'T079 reach FAIL [gate] site-absent until T091',
    'T087 h-1 FAIL [gate] site-absent until T091',
    'T087 reach PASS site-v2',
  ];
  expect(L.countGateSite(lines)).toBe(2);
  expect(L.countGateSite([])).toBe(0);
  // 중계는 out.ts 꼴의 T087 줄을 그대로 옮긴다
  expect(L.relay(lines[0])).toEqual([lines[0]]);
  const s = { passed: 0, failed: 8, flaky: 0, skipped: 1, interrupted: 0, didNotRun: 0, errors: 0 };
  expect(L.siteRedEndLine({ summary: s, gateSite: 8, exit: 1, cleaned: true })).toBe('site-red passed=0 failed=8 skipped=1 gate-site=8/8 child-exit=1 root=removed');
  expect(L.siteRedEndLine({ summary: { ...s, failed: 7, interrupted: 1 }, gateSite: 7, exit: 1, cleaned: true })).toBe('site-red passed=0 failed=8 skipped=1 gate-site=7/8 child-exit=1 root=removed');
  expect(L.siteRedEndLine({ summary: null, gateSite: 0, exit: 1, cleaned: false })).toBe('site-red passed=0 failed=-1 skipped=0 gate-site=0/-1 child-exit=1 root=left');
});

test('launch: list end line carries site=<n> next to the live · needle counts; selftest counts must agree across the three listings', ({ L }) => {
  const live = { selftest: 180, 'selftest-browser': 30, live: 3 };
  const needle = { selftest: 180, 'selftest-browser': 30, needle: 9, 'needle-control': 8 };
  const site = { selftest: 180, 'selftest-browser': 30, site: 9 };
  expect(L.listCountsAgree(live, needle, site)).toBe(true);
  expect(L.listCountsAgree(live, needle, { ...site, selftest: 179 })).toBe(false);
  expect(L.listCountsAgree(live, needle, null)).toBe(false);
  expect(L.listEndLine({ live, needle, site, ok: true })).toBe('list live=3 needle=9 needle-control=8 site=9 selftest=180 selftest-browser=30 result=ok');
  expect(L.listEndLine({ live: null, needle, site: null, ok: false })).toBe('list live=0 needle=9 needle-control=8 site=0 selftest=0 selftest-browser=0 result=FAIL');
});

test('launch: run id shape', ({ L }) => {
  expect(L.makeRunId(new Date(Date.UTC(2026, 10, 23, 9, 5, 7)), 'a1b2c3')).toBe('t077-20261123T090507Z-a1b2c3');
  expect(/^t077-\d{8}T\d{6}Z-[0-9a-f]{6}$/.test(L.makeRunId())).toBe(true);
});
