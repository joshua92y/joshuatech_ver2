// e2e/selftest/launch.test.ts — 런처 launch.mjs의 순수 함수(설계 D9 · D10 ⑧ · r2 — V-3 · V-6 · 컨트롤러 N-1) selftest. 브라우저 0 · 네트워크 0.
// launch.mjs는 import.meta를 쓰는 ESM이라 동적 import로 싣는다(Playwright의 CJS require 훅은 .mjs를 CommonJS로 바꿔 import.meta에서 깨진다 — 1.65.1 실측).
import { test as base, expect } from '@playwright/test';
import * as path from 'node:path';
import { CONTROL_PREFIX, NAMES, NEEDLE_PREFIX as CONTRACT_PREFIX } from '../lib/env-contract';

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

test('launch: run id shape', ({ L }) => {
  expect(L.makeRunId(new Date(Date.UTC(2026, 10, 23, 9, 5, 7)), 'a1b2c3')).toBe('t077-20261123T090507Z-a1b2c3');
  expect(/^t077-\d{8}T\d{6}Z-[0-9a-f]{6}$/.test(L.makeRunId())).toBe(true);
});
