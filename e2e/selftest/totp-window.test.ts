// e2e/selftest/totp-window.test.ts — TOTP 코드 창(설계 D5 · 〔77-5〕) selftest. 가짜 시계 — 브라우저 0 · 네트워크 0.
import { test, expect } from '@playwright/test';
import { SETTLE_MS, STEP_MS, createTotpPicker, planTotp } from '../lib/totp-window';

const K = 58_000_000; // 임의의 30 s 단계 번호

test('totp-window: step is 30 s and the settle margin 0.5 s', () => {
  expect(STEP_MS).toBe(30_000);
  expect(SETTLE_MS).toBe(500);
});

test('totp-window: waits for the next boundary + 0.5 s and uses that step', () => {
  const now = K * STEP_MS + 12_345;
  const p = planTotp(now, K - 2, 20);
  expect(p).toEqual({ kind: 'use', step: K + 1, index: 3, waitMs: (K + 1) * STEP_MS + SETTLE_MS - now });
});

test('totp-window: exactly on a boundary still waits for the next one', () => {
  const now = K * STEP_MS;
  const p = planTotp(now, K, 20);
  expect(p).toEqual({ kind: 'use', step: K + 1, index: 1, waitMs: STEP_MS + SETTLE_MS });
});

test('totp-window: a step already used is never reused (last_t)', () => {
  const now = K * STEP_MS + 100;
  const p = planTotp(now, K, 20, K + 1);
  expect(p).toEqual({ kind: 'use', step: K + 2, index: 2, waitMs: (K + 2) * STEP_MS + SETTLE_MS - now });
});

test('totp-window: exhausted window → no attempt', () => {
  expect(planTotp((K + 25) * STEP_MS, K, 20)).toEqual({ kind: 'exhausted' });
  expect(planTotp((K + 19) * STEP_MS + 1, K, 20)).toEqual({ kind: 'exhausted' });
  expect(planTotp(K * STEP_MS, K + 5, 20)).toEqual({ kind: 'exhausted' });
});

test('totp-window: picker sleeps until the boundary, returns that code and remembers the step', async () => {
  let now = K * STEP_MS + 29_000;
  const slept: number[] = [];
  const pick = createTotpPicker(() => now, async (ms) => { slept.push(ms); now += ms; });
  const codes = ['000001', '000002', '000003', '000004', '000005'];
  const first = await pick({ password: 'x', codes, step0: K });
  expect(first).toBe('000002');
  expect(slept).toEqual([1_500]);
  const second = await pick({ password: 'x', codes, step0: K });
  expect(second).toBe('000003');
  expect(slept[1]).toBe(STEP_MS);
});

test('totp-window: picker throws a value-free [env] totp-window-exhausted', async () => {
  const pick = createTotpPicker(() => (K + 30) * STEP_MS, async () => undefined);
  let message = '';
  try {
    await pick({ password: 'x', codes: ['111111', '222222'], step0: K });
  } catch (e) {
    message = (e as Error).message;
  }
  expect(message).toBe('[env] totp-window-exhausted');
});
