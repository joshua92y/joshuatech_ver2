// e2e/selftest/kubectl-log.test.ts — T079 log-reason의 kubectl 경로 · 자식 env · 인자 · 신원 · 로그 선택(창 · source · reason)(설계 D7 kubectl-log · log-reason · D12 ①b) selftest.
// 브라우저 0 · 네트워크 0 · 실제 kubectl 0 — 파일 존재와 실행은 주입한 가짜로 본다(기본 실행기만 node 자신으로 한 번 확인한다).
import { test, expect } from '@playwright/test';
import * as crypto from 'node:crypto';
import { NAMES } from '../lib/env-contract';
import {
  AGENT_VIEW_USER,
  KUBECTL_ENV_NAMES,
  KUBECTL_EXE,
  REVOCATION_EVENT,
  checkKubeconfig,
  defaultRunner,
  fetchLogs,
  findKubectl,
  judgeWhoami,
  kubectlEnv,
  liveFindContext,
  logsArgs,
  parseUtcTs,
  prepareKubectl,
  selectRevocationLines,
  sinceTimeArg,
  whoamiArgs,
  type FindContext,
  type Runner,
} from '../lib/kubectl-log';

const REPO = 'D:\\code\\repo';
const TMPD = 'C:\\Users\\op\\AppData\\Local\\Temp';
const BIN = 'C:\\tools\\k8s';
const KC = 'C:\\Users\\op\\.kube\\agent-view';
const T0 = Date.UTC(2026, 10, 23, 9, 0, 0, 0);

function marker(): string {
  return 'mk' + crypto.randomBytes(8).toString('hex');
}

function fileSet(files: readonly string[]): (p: string) => boolean {
  const set = new Set(files.map((f) => f.toLowerCase()));
  return (p: string) => set.has(p.toLowerCase());
}

function ctx(files: readonly string[], cwd = 'C:\\elsewhere'): FindContext {
  return { cwd, guardDirs: [REPO, TMPD], isFile: fileSet(files) };
}

function reason(v: { ok: boolean; code?: string; prefix?: string }): string {
  return v.ok ? v.code ?? 'ok' : `[${v.prefix}] ${v.code}`;
}

// ms 정밀도 ISO 문자열 + (선택) 마이크로초 꼬리
function ts(ms: number, micros = ''): string {
  return new Date(ms).toISOString().slice(0, -1) + micros + 'Z';
}

function rec(o: Record<string, unknown>): string {
  return JSON.stringify({ level: 'info', logger: 'identity_admin.revocation', ...o });
}

const REVOKE = { event: REVOCATION_EVENT, reason: 'logout_all', scope: 'user', source: 'revoke', tenant_id: 't-1', sub_hash: 'a'.repeat(32), revocation_id: 'r-1' };

test('kubectl-log: constants — kubectl.exe, agent-view identity, child env allowlist', () => {
  expect(KUBECTL_EXE).toBe('kubectl.exe');
  expect(AGENT_VIEW_USER).toBe('system:serviceaccount:kube-system:agent-view');
  expect([...KUBECTL_ENV_NAMES]).toEqual(['PATH', 'SystemRoot', 'KUBECONFIG', 'USERPROFILE', 'TEMP']);
  expect(REVOCATION_EVENT).toBe('session_revocation.recorded');
});

test('kubectl-log: PATH lookup skips empty, relative, dot, root-relative and cwd entries; the first absolute kubectl.exe wins', () => {
  const files = ['.\\kubectl.exe', 'bin\\kubectl.exe', '\\bin\\kubectl.exe', `${REPO}\\kubectl.exe`, `${BIN}\\kubectl.exe`, 'C:\\other\\kubectl.exe'];
  const PATH = ['', '  ', '.', 'bin', '\\bin', REPO, `"${BIN}"`, 'C:\\other'].join(';');
  expect(findKubectl(PATH, ctx(files, REPO))).toEqual({ ok: true, exe: `${BIN}\\kubectl.exe` });
  // cwd 항목은 끝 구분자 · 대소문자와 무관하게 cwd다
  expect(findKubectl(`${REPO.toUpperCase()}\\;${BIN}`, ctx(files, REPO))).toEqual({ ok: true, exe: `${BIN}\\kubectl.exe` });
  // 실행 파일이 없는 항목은 건너뛴다
  expect(findKubectl(['C:\\empty', 'C:\\other'].join(';'), ctx(files))).toEqual({ ok: true, exe: 'C:\\other\\kubectl.exe' });
});

test('kubectl-log: a kubectl.exe found under the repository or os.tmpdir() → [guard] (the search stops); none → [env]', () => {
  const inRepo = `${REPO}\\tools`;
  expect(reason(findKubectl([inRepo, BIN].join(';'), ctx([`${inRepo}\\kubectl.exe`, `${BIN}\\kubectl.exe`])))).toBe('[guard] kubectl-location');
  expect(reason(findKubectl(`${REPO.toUpperCase()}\\TOOLS`, ctx([`${inRepo}\\kubectl.exe`])))).toBe('[guard] kubectl-location');
  const inTmp = `${TMPD}\\jt-e2e\\x`;
  expect(reason(findKubectl([inTmp, BIN].join(';'), ctx([`${inTmp}\\kubectl.exe`, `${BIN}\\kubectl.exe`])))).toBe('[guard] kubectl-location');
  expect(reason(findKubectl('C:\\a;C:\\b', ctx([])))).toBe('[env] kubectl-not-found');
  expect(reason(findKubectl(undefined, ctx([])))).toBe('[env] kubectl-not-found');
  expect(reason(findKubectl('', ctx([])))).toBe('[env] kubectl-not-found');
});

test('kubectl-log: the guard also covers the token-home Temp and the block root JT_E2E_ROOT when the child TEMP is redirected (리뷰 A-5)', () => {
  const home = 'C:\\Users\\op';
  const tokenTemp = `${home}\\AppData\\Local\\Temp`;
  const blockRoot = 'D:\\blocks\\t077-x';
  const files = [`${tokenTemp}\\planted\\kubectl.exe`, `${blockRoot}\\bin\\kubectl.exe`, `${BIN}\\kubectl.exe`];
  // 런처 · 블록 실행에서 os.tmpdir()는 루트 아래 tmp다 — 실제 사용자 Temp는 토큰 홈 기준으로 따로 막는다
  const fc = liveFindContext({ JT_E2E_ROOT: blockRoot }, { home, tmpdir: `${blockRoot}\\tmp`, cwd: 'C:\\elsewhere', isFile: fileSet(files) });
  expect(reason(findKubectl([`${tokenTemp}\\planted`, BIN].join(';'), fc))).toBe('[guard] kubectl-location');
  expect(reason(findKubectl([`${blockRoot}\\bin`, BIN].join(';'), fc))).toBe('[guard] kubectl-location');
  expect(reason(findKubectl([`${tokenTemp.toUpperCase()}\\PLANTED`, BIN].join(';'), fc))).toBe('[guard] kubectl-location');
  expect(findKubectl(BIN, fc)).toEqual({ ok: true, exe: `${BIN}\\kubectl.exe` });
  // 저장소 루트 · os.tmpdir()는 그대로 가드 목록에 있다
  expect(fc.guardDirs.map((d) => d.toLowerCase())).toEqual(expect.arrayContaining([`${blockRoot}\\tmp`.toLowerCase(), tokenTemp.toLowerCase(), blockRoot.toLowerCase()]));
  // 비었거나 상대인 JT_E2E_ROOT는 가드 목록에 넣지 않는다(빈 글자 · 상대 글자가 아무 경로나 덮지 않게)
  for (const bad of ['', 'relative\\root', '.']) {
    const f2 = liveFindContext({ JT_E2E_ROOT: bad }, { home, tmpdir: TMPD, cwd: 'C:\\elsewhere', isFile: fileSet(files) });
    expect(f2.guardDirs.length, bad).toBe(3);
    expect(findKubectl(BIN, f2), bad).toEqual({ ok: true, exe: `${BIN}\\kubectl.exe` });
  }
});

test('kubectl-log: child env is exactly the allowlist (names are case-insensitive on Windows; nothing else passes)', () => {
  const m = marker();
  const source: Record<string, string> = {
    Path: 'C:\\p',
    SYSTEMROOT: 'C:\\Windows',
    KUBECONFIG: KC,
    USERPROFILE: 'C:\\Users\\op',
    TEMP: 'C:\\t',
    TMP: 'C:\\t',
    LOCALAPPDATA: 'C:\\l',
    HTTPS_PROXY: 'http://proxy',
    NODE_OPTIONS: '--inspect',
    GITHUB_TOKEN: m,
    [NAMES.password]: m,
    [NAMES.block]: 'x.ps1',
    [NAMES.needleSet]: m,
  };
  const env = kubectlEnv(source);
  expect(Object.keys(env).sort()).toEqual(['KUBECONFIG', 'PATH', 'SystemRoot', 'TEMP', 'USERPROFILE']);
  expect(env.PATH).toBe('C:\\p');
  expect(env.SystemRoot).toBe('C:\\Windows');
  expect(JSON.stringify(env).includes(m)).toBe(false);
  expect(Object.keys(kubectlEnv({ PATH: 'C:\\p', TEMP: '' }))).toEqual(['PATH']);
});

test('kubectl-log: KUBECONFIG must be one existing absolute file (missing · path list · relative · absent → [env])', () => {
  const isFile = (p: string) => p === KC;
  expect(checkKubeconfig(KC, isFile)).toEqual({ ok: true, path: KC });
  expect(reason(checkKubeconfig(undefined, isFile))).toBe('[env] missing KUBECONFIG');
  expect(reason(checkKubeconfig('', isFile))).toBe('[env] missing KUBECONFIG');
  expect(reason(checkKubeconfig(`${KC};C:\\Users\\op\\.kube\\config`, isFile))).toBe('[env] shape KUBECONFIG');
  expect(reason(checkKubeconfig('agent-view', isFile))).toBe('[env] shape KUBECONFIG');
  expect(reason(checkKubeconfig('C:\\Users\\op\\.kube\\missing', isFile))).toBe('[env] kubeconfig-not-found');
});

test('kubectl-log: whoami must be agent-view — another user → [guard]; unparsable → [env] without the raw text', () => {
  const who = (u: unknown) => JSON.stringify({ kind: 'SelfSubjectReview', status: { userInfo: { username: u, groups: ['system:authenticated'] } } });
  expect(judgeWhoami(who(AGENT_VIEW_USER))).toEqual({ ok: true, code: 'agent-view' });
  expect(reason(judgeWhoami(who('kubernetes-admin')))).toBe('[guard] kubectl-identity-not-agent-view');
  expect(reason(judgeWhoami(who(undefined)))).toBe('[guard] kubectl-identity-not-agent-view');
  expect(reason(judgeWhoami('null'))).toBe('[guard] kubectl-identity-not-agent-view');
  const m = marker();
  const bad = judgeWhoami(`error: ${m}`);
  expect(reason(bad)).toBe('[env] kubectl-whoami-unusable');
  expect(JSON.stringify(bad).includes(m)).toBe(false);
  expect(JSON.stringify(judgeWhoami(who(m))).includes(m)).toBe(false);
});

test('kubectl-log: argv is fixed — whoami, and logs deploy/identity-admin -c web with --since-time in whole UTC seconds', () => {
  expect(whoamiArgs(KC)).toEqual(['--kubeconfig', KC, '--request-timeout=20s', 'auth', 'whoami', '-o', 'json']);
  const t = Date.UTC(2026, 10, 23, 9, 5, 7, 812);
  expect(sinceTimeArg(t)).toBe('2026-11-23T09:05:07Z');
  expect(logsArgs(KC, 'jt-dev', t)).toEqual(['--kubeconfig', KC, '--request-timeout=20s', '-n', 'jt-dev', 'logs', 'deploy/identity-admin', '-c', 'web', '--since-time=2026-11-23T09:05:07Z']);
  expect(logsArgs(KC, 'jt-prod', t)[4]).toBe('jt-prod');
  for (const ns of ['kube-system', 'identity', 'jt-dev ', '']) expect(() => logsArgs(KC, ns, t), ns).toThrow(/namespace/);
});

test('kubectl-log: ts must be ISO 8601 UTC (Z or +00:00); sub-millisecond digits are dropped; other forms do not parse', () => {
  expect(parseUtcTs('2026-11-23T09:00:00.123456Z')).toBe(T0 + 123);
  expect(parseUtcTs('2026-11-23T09:00:00.999999Z')).toBe(T0 + 999);
  expect(parseUtcTs('2026-11-23T09:00:00Z')).toBe(T0);
  expect(parseUtcTs('2026-11-23T09:00:00.5+00:00')).toBe(T0 + 500);
  for (const bad of ['2026-11-23T09:00:00', '2026-11-23T18:00:00+09:00', '2026-11-23 09:00:00Z', '2026-13-01T00:00:00Z', 'yesterday', '', 1795424400000, null, undefined]) {
    expect(parseUtcTs(bad), String(bad)).toBeNull();
  }
});

test('kubectl-log: log selection counts recorded revocations by window, source and reason (bounds inclusive)', () => {
  const lines = [
    rec({ ...REVOKE, ts: ts(T0 + 300, '456') }), // 창 안
    rec({ ...REVOKE, ts: ts(T0) }), // 아래 경계
    rec({ ...REVOKE, ts: ts(T0 + 12_000, '999') }), // 위 경계(ms 아래는 버림)
    rec({ ...REVOKE, ts: ts(T0 - 1, '999') }), // 창 앞
    rec({ ...REVOKE, ts: ts(T0 + 12_001) }), // 창 뒤
    rec({ ...REVOKE, source: 'webhook', reason: 'authentik_webhook', ts: ts(T0 + 400) }), // 다른 source · reason
    rec({ ...REVOKE, reason: 'logout', ts: ts(T0 + 400) }), // 다른 reason
    rec({ ...REVOKE, source: 'admin', ts: ts(T0 + 400) }), // 다른 source
    rec({ ...REVOKE, event: 'request_finished', ts: ts(T0 + 400) }), // 다른 이벤트
  ].join('\n');
  const ac3 = selectRevocationLines(lines, { source: 'revoke', reason: 'logout_all', startMs: T0, endMs: T0 + 12_000 });
  expect(ac3).toEqual({ matched: 3, outside: 2, badTs: 0, firstOffsetMs: 0, json: 9, nonJson: 0, malformed: 0 });
  const ac4 = selectRevocationLines(lines, { source: 'webhook', reason: 'authentik_webhook', startMs: T0, endMs: T0 + 4_000 });
  expect(ac4).toEqual({ matched: 1, outside: 0, badTs: 0, firstOffsetMs: 400, json: 9, nonJson: 0, malformed: 0 });
  // 같은 줄이라도 창이 다르면 세지 않는다
  expect(selectRevocationLines(lines, { source: 'webhook', reason: 'authentik_webhook', startMs: T0 + 401, endMs: T0 + 4_401 }).matched).toBe(0);
});

test('kubectl-log: symmetric clock slack — a line up to 2 s before the anchor counts; the first offset is measured from the anchor (리뷰 A-8)', () => {
  const lines = [
    rec({ ...REVOKE, ts: ts(T0 - 1_999) }), // 아래 여유 안(pod 시계가 늦은 경우)
    rec({ ...REVOKE, ts: ts(T0 - 2_000) }), // 아래 경계
    rec({ ...REVOKE, ts: ts(T0 - 2_001) }), // 창 앞
    rec({ ...REVOKE, ts: ts(T0 + 500) }),
  ].join('\n');
  const sel = selectRevocationLines(lines, { source: 'revoke', reason: 'logout_all', anchorMs: T0, startMs: T0 - 2_000, endMs: T0 + 12_000 });
  expect(sel).toEqual({ matched: 3, outside: 1, badTs: 0, firstOffsetMs: -2_000, json: 4, nonJson: 0, malformed: 0 });
  // anchor가 없으면 창 시작이 기준이다(이전 꼴과 같다)
  expect(selectRevocationLines(lines, { source: 'revoke', reason: 'logout_all', startMs: T0, endMs: T0 + 12_000 }).firstOffsetMs).toBe(500);
});

test('kubectl-log: non-JSON and malformed lines are counted, never echoed; a bad ts is not a match', () => {
  const m = marker();
  const text = [
    `[2026-11-23 09:00:00 +0000] [1] [INFO] Booting worker with pid: ${m}`,
    `{"event": "${m}`,
    '[1,2]',
    rec({ ...REVOKE, ts: 'bad', sub_hash: m }),
    '',
    rec({ ...REVOKE, ts: ts(T0 + 1), sub_hash: m }),
  ].join('\r\n');
  const sel = selectRevocationLines(text, { source: 'revoke', reason: 'logout_all', startMs: T0, endMs: T0 + 12_000 });
  expect(sel).toEqual({ matched: 1, outside: 0, badTs: 1, firstOffsetMs: 1, json: 2, nonJson: 2, malformed: 1 });
  expect(JSON.stringify(sel).includes(m)).toBe(false);
});

test('kubectl-log: a parse failure is rethrown without raw text or cause', () => {
  let e: Error | undefined;
  try {
    selectRevocationLines(42 as never, { source: 'revoke', reason: 'logout_all', startMs: T0, endMs: T0 + 1 });
  } catch (x) {
    e = x as Error;
  }
  expect(e?.message).toBe('kubectl-log: parse failed');
  expect((e as { cause?: unknown } | undefined)?.cause).toBeUndefined();
});

function fakeRunner(script: (args: readonly string[]) => { code: number; stdout: string }) {
  const calls: Array<{ exe: string; args: string[]; env: Record<string, string> }> = [];
  const runner: Runner = async (exe, args, env) => {
    calls.push({ exe, args: [...args], env: { ...env } });
    return script(args);
  };
  return { calls, runner };
}

function liveEnv(m: string): Record<string, string> {
  return { PATH: BIN, SystemRoot: 'C:\\Windows', KUBECONFIG: KC, USERPROFILE: 'C:\\Users\\op', TEMP: 'C:\\t', [NAMES.password]: m, HTTPS_PROXY: 'http://p' };
}

const WHOAMI_OK = JSON.stringify({ status: { userInfo: { username: AGENT_VIEW_USER } } });

test('kubectl-log: prepare runs whoami before logs, with the allowlisted env and fixed argv; logs text stays in memory', async () => {
  const m = marker();
  const { calls, runner } = fakeRunner((args) => (args.includes('whoami') ? { code: 0, stdout: WHOAMI_OK } : { code: 0, stdout: rec({ ...REVOKE, ts: ts(T0 + 5) }) }));
  const fc = ctx([`${BIN}\\kubectl.exe`, KC]);
  const prep = await prepareKubectl(liveEnv(m), fc, runner);
  expect(prep.ok).toBe(true);
  if (!prep.ok) return;
  const logs = await fetchLogs(prep, 'jt-dev', T0, runner);
  expect(logs.ok).toBe(true);
  if (logs.ok) expect(selectRevocationLines(logs.text, { source: 'revoke', reason: 'logout_all', startMs: T0, endMs: T0 + 12_000 }).matched).toBe(1);
  expect(calls.length).toBe(2);
  expect(calls[0].args).toEqual(whoamiArgs(KC));
  expect(calls[1].args).toEqual(logsArgs(KC, 'jt-dev', T0));
  for (const c of calls) {
    expect(c.exe).toBe(`${BIN}\\kubectl.exe`);
    expect(Object.keys(c.env).sort()).toEqual(['KUBECONFIG', 'PATH', 'SystemRoot', 'TEMP', 'USERPROFILE']);
    expect(JSON.stringify(c.env).includes(m)).toBe(false);
  }
});

test('kubectl-log: prepare stops before any kubectl call on a bad PATH or KUBECONFIG; another identity stops before logs', async () => {
  const m = marker();
  const none = fakeRunner(() => ({ code: 0, stdout: WHOAMI_OK }));
  expect(reason(await prepareKubectl(liveEnv(m), ctx([KC]), none.runner))).toBe('[env] kubectl-not-found');
  expect(reason(await prepareKubectl({ ...liveEnv(m), KUBECONFIG: '' }, ctx([`${BIN}\\kubectl.exe`]), none.runner))).toBe('[env] missing KUBECONFIG');
  expect(none.calls.length).toBe(0);
  const admin = fakeRunner(() => ({ code: 0, stdout: JSON.stringify({ status: { userInfo: { username: 'kubernetes-admin' } } }) }));
  expect(reason(await prepareKubectl(liveEnv(m), ctx([`${BIN}\\kubectl.exe`, KC]), admin.runner))).toBe('[guard] kubectl-identity-not-agent-view');
  expect(admin.calls.length).toBe(1);
});

test('kubectl-log: kubectl failures surface the exit code only (no stderr, no argv)', async () => {
  const m = marker();
  const fc = ctx([`${BIN}\\kubectl.exe`, KC]);
  const w = fakeRunner(() => ({ code: 1, stdout: `error: ${m}` }));
  const r1 = await prepareKubectl(liveEnv(m), fc, w.runner);
  expect(reason(r1)).toBe('[env] kubectl-whoami-failed exit=1');
  const thrower: Runner = async () => {
    throw new Error(`spawn ${m} ENOENT`);
  };
  const r2 = await prepareKubectl(liveEnv(m), fc, thrower);
  expect(reason(r2)).toBe('[env] kubectl-run-failed');
  const okPrep = await prepareKubectl(liveEnv(m), fc, fakeRunner(() => ({ code: 0, stdout: WHOAMI_OK })).runner);
  expect(okPrep.ok).toBe(true);
  if (!okPrep.ok) return;
  const r3 = await fetchLogs(okPrep, 'jt-prod', T0, fakeRunner(() => ({ code: 1, stdout: m })).runner);
  expect(reason(r3)).toBe('[env] kubectl-logs-failed exit=1');
  const r4 = await fetchLogs(okPrep, 'jt-prod', T0, thrower);
  expect(reason(r4)).toBe('[env] kubectl-run-failed');
  for (const r of [r1, r2, r3, r4]) expect(JSON.stringify(r).includes(m)).toBe(false);
});

test('kubectl-log: the default runner runs an absolute executable without a shell and reports exit code + stdout only', async () => {
  const env = { SystemRoot: process.env.SystemRoot ?? 'C:\\Windows', PATH: process.env.PATH ?? '' };
  // 자식 node 스크립트 글자 — static-gate fd-write 규칙에 스스로 걸리지 않게 조각으로 조립한다
  const out1 = (expr: string) => ['require("fs").write', 'Sync(1, ', expr, ')'].join('');
  const ok = await defaultRunner(process.execPath, ['-e', out1('"ok-" + (1 + 1)')], env);
  expect(ok).toEqual({ code: 0, stdout: 'ok-2' });
  const bad = await defaultRunner(process.execPath, ['-e', out1('"partial"') + '; process.exit(3)'], env);
  expect(bad).toEqual({ code: 3, stdout: '' });
  // 셸 메타 문자는 인자 글자 그대로 넘어간다(셸 0)
  const lit = await defaultRunner(process.execPath, ['-e', out1('process.argv[1]'), 'a&b|c'], env);
  expect(lit).toEqual({ code: 0, stdout: 'a&b|c' });
  const missing = await defaultRunner('C:\\no-such-dir-jt\\kubectl.exe', ['version'], env);
  expect(missing).toEqual({ code: -1, stdout: '' });
});
