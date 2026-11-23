// e2e/selftest/env-contract.test.ts — env 계약 · 모드 판정 표(설계 D5 · 컨트롤러 N-1) selftest. 브라우저 0 · 네트워크 0.
// 값은 시험 안에서 만든다(바늘 리터럴 0 — 접두는 env-contract의 꼴 상수만 쓴다).
import { test, expect } from '@playwright/test';
import * as crypto from 'node:crypto';
import { CONTROL_PREFIX, E2E_EMAIL, NAMES, NEEDLE_PREFIX, SECRET_ENV_NAMES, decide, scrubAndDecide, type Decision } from '../lib/env-contract';

const BLOCK = 'specs/003-platform-foundation/design/t08x-blocks/example-block.ps1';

function hex(n: number): string {
  return crypto.randomBytes(n).toString('hex');
}

function codes(n: number): string {
  return Array.from({ length: n }, () => String(crypto.randomInt(0, 1_000_000)).padStart(6, '0')).join(',');
}

function spy(env: Record<string, string | undefined>) {
  const read: string[] = [];
  return { read, get: (name: string) => { read.push(name); return env[name]; } };
}

function liveEnv(): Record<string, string | undefined> {
  return { [NAMES.block]: BLOCK, [NAMES.password]: 'pw-' + hex(8), [NAMES.codes]: codes(20), [NAMES.step0]: '58000000' };
}

function needleSet() {
  return {
    password: NEEDLE_PREFIX + 'pw-' + hex(6),
    codes: codes(20),
    step0: '58000000',
    cookie: NEEDLE_PREFIX + 'ck-' + hex(8),
    authorization: NEEDLE_PREFIX + 'az-' + hex(8),
    query: NEEDLE_PREFIX + 'q-' + hex(6),
    ip: '203.0.113.' + String(crypto.randomInt(1, 255)),
    ua: NEEDLE_PREFIX + 'UA/' + hex(4),
    control: CONTROL_PREFIX + 'log-' + hex(6),
    controlFill: CONTROL_PREFIX + 'inp-' + hex(6),
    controlRequest: CONTROL_PREFIX + 'req-' + hex(6),
    controlSetCookie: CONTROL_PREFIX + 'sck-' + hex(6),
    controlUrl: CONTROL_PREFIX + 'url-' + hex(6),
    controlGoto: CONTROL_PREFIX + 'nav-' + hex(6),
    controlFile: CONTROL_PREFIX + 'pgs-' + hex(6),
  };
}

function needleEnv(set = needleSet()): Record<string, string | undefined> {
  return { [NAMES.needleSet]: JSON.stringify(set), [NAMES.password]: set.password, [NAMES.codes]: set.codes, [NAMES.step0]: set.step0 };
}

function stop(d: Decision): string {
  return d.kind === 'stop' ? `[${d.prefix}] ${d.code}` : d.kind;
}

test('env-contract: fixed identity and names', () => {
  expect(E2E_EMAIL).toBe('e2e@joshuatech.dev');
  expect(SECRET_ENV_NAMES).toEqual([NAMES.password, NAMES.codes, NAMES.step0]);
  expect(NAMES.block).toBe('JT_E2E_BLOCK');
  expect(NAMES.step0).toBe('JT_E2E_TOTP_STEP0');
  expect(CONTROL_PREFIX.startsWith(NEEDLE_PREFIX)).toBe(true);
});

test('env-contract: live with jtApprovedBlock null → [guard] outside-reviewed-block, no secret name is read', () => {
  const s = spy(liveEnv());
  expect(stop(decide('live', s.get, null))).toBe('[guard] outside-reviewed-block (T077-a)');
  for (const n of SECRET_ENV_NAMES) expect(s.read.includes(n), n).toBe(false);
  expect(s.read.includes(NAMES.needleSet)).toBe(false);
});

test('env-contract: live with a block that differs from the approved path → guard', () => {
  const env = liveEnv();
  env[NAMES.block] = 'tmp/other.ps1';
  const s = spy(env);
  expect(stop(decide('live', s.get, BLOCK))).toBe('[guard] outside-reviewed-block (T077-a)');
  for (const n of SECRET_ENV_NAMES) expect(s.read.includes(n), n).toBe(false);
  expect(stop(decide('live', spy({ ...liveEnv(), [NAMES.block]: undefined }).get, BLOCK))).toBe('[guard] outside-reviewed-block (T077-a)');
  expect(stop(decide('live', spy(liveEnv()).get, ''))).toBe('[guard] outside-reviewed-block (T077-a)');
});

test('env-contract: live refuses needle-shaped input', () => {
  const env = liveEnv();
  env[NAMES.needleSet] = '{}';
  expect(stop(decide('live', spy(env).get, BLOCK))).toBe('[guard] needle-shaped value in live');
  const env2 = liveEnv();
  env2[NAMES.password] = NEEDLE_PREFIX + 'pw-' + hex(6);
  expect(stop(decide('live', spy(env2).get, BLOCK))).toBe('[guard] needle-shaped value in live');
});

test('env-contract: missing names are listed by name only ([env], not SKIP)', () => {
  const env = liveEnv();
  delete env[NAMES.password];
  env[NAMES.codes] = '';
  const d = decide('live', spy(env).get, BLOCK);
  expect(stop(d)).toBe(`[env] missing ${NAMES.password},${NAMES.codes}`);
});

test('env-contract: shape checks — codes window, step0 integer', () => {
  const one = liveEnv();
  one[NAMES.codes] = codes(1);
  expect(stop(decide('live', spy(one).get, BLOCK))).toBe(`[env] shape ${NAMES.codes}`);
  const many = liveEnv();
  many[NAMES.codes] = codes(41);
  expect(stop(decide('live', spy(many).get, BLOCK))).toBe(`[env] shape ${NAMES.codes}`);
  const five = liveEnv();
  five[NAMES.codes] = '12345,123456';
  expect(stop(decide('live', spy(five).get, BLOCK))).toBe(`[env] shape ${NAMES.codes}`);
  const step = liveEnv();
  step[NAMES.step0] = '12.5';
  expect(stop(decide('live', spy(step).get, BLOCK))).toBe(`[env] shape ${NAMES.step0}`);
});

test('env-contract: live with an approved block and well-formed env → ok', () => {
  const env = liveEnv();
  const d = decide('live', spy(env).get, BLOCK);
  expect(d.kind).toBe('ok');
  if (d.kind !== 'ok') return;
  expect(d.mode).toBe('live');
  expect(d.secrets.codes.length).toBe(20);
  expect(d.secrets.step0).toBe(58_000_000);
  expect(d.secrets.password).toBe(env[NAMES.password]);
});

test('env-contract: needle accepts only the launcher needle set', () => {
  const set = needleSet();
  const d = decide('needle', spy(needleEnv(set)).get, null);
  expect(d.kind).toBe('ok');
  if (d.kind === 'ok' && d.mode === 'needle') {
    expect(d.extras.ip).toBe(set.ip);
    expect(d.extras.cookie).toBe(set.cookie);
    expect(d.secrets.codes.length).toBe(20);
  }
  const noSet = needleEnv(set);
  delete noSet[NAMES.needleSet];
  expect(stop(decide('needle', spy(noSet).get, null))).toBe('[guard] non-needle value in needle');
  const broken = needleEnv(set);
  broken[NAMES.needleSet] = '{not json';
  expect(stop(decide('needle', spy(broken).get, null))).toBe('[guard] non-needle value in needle');
  const differs = needleEnv(set);
  differs[NAMES.password] = NEEDLE_PREFIX + 'pw-' + hex(6);
  expect(stop(decide('needle', spy(differs).get, null))).toBe('[guard] non-needle value in needle');
  const real = needleSet();
  real.password = 'pw-' + hex(6);
  expect(stop(decide('needle', spy(needleEnv(real)).get, null))).toBe('[guard] non-needle value in needle');
  const codeDiff = needleEnv(set);
  codeDiff[NAMES.codes] = codes(20);
  expect(stop(decide('needle', spy(codeDiff).get, null))).toBe('[guard] non-needle value in needle');
});

test('env-contract: needle-control returns only the control values (one per exposure path) and never reads the secret names', () => {
  const set = needleSet();
  const s = spy(needleEnv(set));
  const d = decide('needle-control', s.get, null);
  expect(d).toEqual({
    kind: 'control',
    control: set.control,
    paths: { fill: set.controlFill, requestHeaders: set.controlRequest, setCookie: set.controlSetCookie, url: set.controlUrl, goto: set.controlGoto, file: set.controlFile },
  });
  for (const n of SECRET_ENV_NAMES) expect(s.read.includes(n), n).toBe(false);
  const bad = { ...set, control: NEEDLE_PREFIX + 'pw-' + hex(6) };
  expect(stop(decide('needle-control', spy(needleEnv(bad)).get, null))).toBe('[guard] non-control value in needle-control');
  expect(stop(decide('needle-control', spy({}).get, null))).toBe('[guard] non-control value in needle-control');
  // 경로별 대조 값 하나라도 대조 꼴이 아니거나 빠지면 멈춘다(실제 바늘이 대조 자리로 흘러들지 않게)
  for (const k of ['controlFill', 'controlRequest', 'controlSetCookie', 'controlUrl', 'controlGoto', 'controlFile'] as const) {
    const wrong = { ...set, [k]: NEEDLE_PREFIX + 'ck-' + hex(8) };
    expect(stop(decide('needle-control', spy(needleEnv(wrong)).get, null)), k).toBe('[guard] non-control value in needle-control');
    const missing: Record<string, string> = { ...set };
    delete missing[k];
    expect(stop(decide('needle-control', spy({ [NAMES.needleSet]: JSON.stringify(missing) }).get, null)), `${k} missing`).toBe('[guard] non-control value in needle-control');
  }
});

test('env-contract: any other project → guard', () => {
  for (const p of ['selftest', 'selftest-browser', '', 'Live']) {
    expect(stop(decide(p, spy(liveEnv()).get, BLOCK)), p).toBe('[guard] project-not-allowed');
  }
});

test('env-contract: stop codes never contain values', () => {
  const env = liveEnv();
  const pw = NEEDLE_PREFIX + 'pw-' + hex(6);
  env[NAMES.password] = pw;
  const d = decide('live', spy(env).get, BLOCK);
  expect(JSON.stringify(d).includes(pw)).toBe(false);
});

test('env-contract: scrubAndDecide removes every contract name from the env even on guard', () => {
  const env: Record<string, string | undefined> = { ...needleEnv(), [NAMES.block]: BLOCK, OTHER: 'kept' };
  const d = scrubAndDecide('live', env, null);
  expect(stop(d)).toBe('[guard] outside-reviewed-block (T077-a)');
  for (const n of [...SECRET_ENV_NAMES, NAMES.needleSet]) expect(Object.prototype.hasOwnProperty.call(env, n), n).toBe(false);
  expect(env.OTHER).toBe('kept');
});
