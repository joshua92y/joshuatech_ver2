// e2e/lib/secret-input.ts — 비밀 입력 감싸개(설계 D10 ③ · r1 — B-1 ①). Playwright call log에는 fill("<값>")이 평문으로 실린다(VD-T077-4 실측).
// 실패하거나 칸이 값을 지키지 못하면 칸을 비우고 값 없는 새 오류를 던진다(원래 오류 객체 · message를 넘기지 않는다). step 제목 · console 0.
// 칸 확인은 길이만 받는다(locator.evaluate(e => e.value.length)) — 값을 읽지 않는다. 값을 읽는 evaluate는 이 파일에만 둔다(static-gate).
// 오류 코드 두 갈래(빌드 리뷰 r1 — B-5): 'secret-input' = 값이 칸에 들어가지 못했다(fill 자체 실패) · AFTER_FILL_CODE = 값이 칸에 들어간 뒤 실패했다
// (길이 확인 실패 · 자동 제출로 칸이 사라짐 등 — 이미 제출됐을 수 있으므로 호출 측이 잠금 표식으로 다룬다).
import type { Locator } from '@playwright/test';
import { safeError } from './http';

const LABEL = /^[a-z][a-z0-9-]*$/;

export const AFTER_FILL_CODE = 'secret-input-after-fill';

// 칸 값의 길이만(값 0)
export async function valueLength(locator: Locator, opts: { timeout?: number } = {}): Promise<number> {
  return locator.evaluate((e) => (e as HTMLInputElement).value.length, undefined, { timeout: opts.timeout });
}

export async function secretFill(locator: Locator, value: string, label: string, opts: { timeout?: number } = {}): Promise<void> {
  if (!LABEL.test(label)) throw safeError('secret-input: label rejected', 'error');
  let filled = false;
  let kept = false;
  try {
    await locator.fill(value, { timeout: opts.timeout });
    filled = true;
    kept = (await valueLength(locator, opts)) === value.length;
  } catch {
    kept = false;
  }
  if (!kept) {
    try {
      await locator.fill('', { timeout: 1_000 });
    } catch {
      // 비우기 실패도 값 출력 0
    }
    if (filled) throw safeError(`secret-input ${label} failed after fill`, AFTER_FILL_CODE);
    throw safeError(`secret-input ${label} failed`, 'secret-input');
  }
}
