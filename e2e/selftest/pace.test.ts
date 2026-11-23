// e2e/selftest/pace.test.ts — 호출 간격 ≥ 200 ms(plan A32 · VD-3 · 설계 D7) selftest. 가짜 시계 — 브라우저 0 · 네트워크 0.
import { test, expect } from '@playwright/test';
import { MIN_GAP_MS, createPacer, waitNeeded } from '../lib/pace';

test('pace: minimum gap is 200 ms', () => {
  expect(MIN_GAP_MS).toBe(200);
});

test('pace: waitNeeded computes the remaining gap', () => {
  expect(waitNeeded(1_000, undefined)).toBe(0);
  expect(waitNeeded(1_000, 900)).toBe(100);
  expect(waitNeeded(1_000, 700)).toBe(0);
  expect(waitNeeded(1_000, 1_000)).toBe(200);
  expect(waitNeeded(1_000, 950, 500)).toBe(450);
});

test('pace: a pacer sleeps only when the previous call was too recent', async () => {
  let now = 10_000;
  const slept: number[] = [];
  const pace = createPacer(MIN_GAP_MS, () => now, async (ms) => {
    slept.push(ms);
    now += ms;
  });
  await pace();
  expect(slept).toEqual([]);
  now += 50;
  await pace();
  expect(slept).toEqual([150]);
  now += 1_000;
  await pace();
  expect(slept).toEqual([150]);
});
