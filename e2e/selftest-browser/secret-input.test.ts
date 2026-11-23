// e2e/selftest-browser/secret-input.test.ts — 비밀 입력 감싸개(설계 D10 ③ · 컨트롤러 N-4 · 빌드 리뷰 r1 — B-5) selftest. 로컬 page.setContent만 — 네트워크 0.
// 칸 확인은 길이만 받는다(secret-input의 valueLength — 값을 읽는 단언 0). 「칸에 들어간 뒤의 실패」는 따로 된 코드로 낸다(호출 측이 잠금 표식으로 다룬다).
import { test, expect } from '../lib/test-base';
import type { Page } from '@playwright/test';
import * as crypto from 'node:crypto';
import { AFTER_FILL_CODE, secretFill, valueLength } from '../lib/secret-input';
import { safeErrorCode } from '../lib/http';

function value(): string {
  return 'sv' + crypto.randomBytes(10).toString('hex');
}

async function lengthOf(page: Page, sel: string): Promise<number> {
  return valueLength(page.locator(sel));
}

async function rejection(p: Promise<unknown>): Promise<Error> {
  try {
    await p;
  } catch (e) {
    return e as Error;
  }
  throw new Error('expected a rejection');
}

test('secret-input: fills the field (length check only)', async ({ page }) => {
  await page.setContent('<input id="pw" type="password">');
  const v = value();
  await secretFill(page.locator('#pw'), v, 'password');
  expect(await lengthOf(page, '#pw')).toBe(v.length);
});

test('secret-input: a fill that cannot happen fails with a value-free error and no cause (value never entered)', async ({ page }) => {
  await page.setContent('<input id="pw" type="password" disabled>');
  const v = value();
  const e = await rejection(secretFill(page.locator('#pw'), v, 'password', { timeout: 1_000 }));
  expect(e.message).toBe('secret-input password failed');
  expect(safeErrorCode(e)).toBe('secret-input');
  expect(String(e.stack).includes(v)).toBe(false);
  expect((e as { cause?: unknown }).cause).toBeUndefined();
});

test('secret-input: a field that does not keep the value is cleared and reported as a failure after fill', async ({ page }) => {
  await page.setContent('<input id="code" type="text"><script>document.getElementById("code").addEventListener("input", (ev) => { ev.target.value = ev.target.value.slice(0, 3); });</script>');
  const v = value();
  const e = await rejection(secretFill(page.locator('#code'), v, 'totp', { timeout: 2_000 }));
  expect(e.message).toBe('secret-input totp failed after fill');
  expect(safeErrorCode(e)).toBe(AFTER_FILL_CODE);
  expect(String(e.stack).includes(v)).toBe(false);
  expect(await lengthOf(page, '#code')).toBe(0);
});

test('secret-input: the field disappears right after the value was entered (auto-submit) → failure after fill, value-free (리뷰 B-5)', async ({ page }) => {
  await page.setContent('<div id="box"><input id="code" type="text"></div><script>const i = document.getElementById("code"); i.addEventListener("input", () => { if (i.value.length >= 6) document.getElementById("box").replaceChildren(); });</script>');
  const v = value();
  const e = await rejection(secretFill(page.locator('#code'), v, 'totp', { timeout: 1_000 }));
  expect(safeErrorCode(e)).toBe(AFTER_FILL_CODE);
  expect(e.message).toBe('secret-input totp failed after fill');
  expect(String(e.stack).includes(v)).toBe(false);
});

test('secret-input: a missing element fails without the value (never entered)', async ({ page }) => {
  await page.setContent('<p>none</p>');
  const v = value();
  const e = await rejection(secretFill(page.locator('#absent'), v, 'password', { timeout: 500 }));
  expect(e.message).toBe('secret-input password failed');
  expect(safeErrorCode(e)).toBe('secret-input');
  expect(String(e.stack).includes(v)).toBe(false);
});

test('secret-input: labels are fixed ASCII words', async ({ page }) => {
  await page.setContent('<input id="pw" type="password">');
  await expect(secretFill(page.locator('#pw'), value(), 'bad label!')).rejects.toThrow(/label/);
});
