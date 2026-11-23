// e2e/lib/totp-window.ts — TOTP 코드 창(설계 D5 · 〔77-5〕). 블록은 시드 대신 연속 30 s 단계의 코드 N개와 첫 단계 번호만 넘긴다.
// 입력 직전 다음 30 s 경계 + 0.5 s까지 기다려 그 단계의 코드를 쓴다 — 로그인마다 새 단계(last_t 재사용 거부 회피). 창이 바닥나면 시도 없이 [env].
import { safeError } from './http';
import type { Secrets } from './env-contract';

export const STEP_MS = 30_000;
export const SETTLE_MS = 500;

export type TotpPlan = { kind: 'use'; step: number; index: number; waitMs: number } | { kind: 'exhausted' };

export function planTotp(nowMs: number, step0: number, count: number, lastUsedStep?: number): TotpPlan {
  let step = Math.floor(nowMs / STEP_MS) + 1;
  if (lastUsedStep !== undefined && step <= lastUsedStep) step = lastUsedStep + 1;
  const index = step - step0;
  if (!Number.isInteger(index) || index < 0 || index >= count) return { kind: 'exhausted' };
  return { kind: 'use', step, index, waitMs: step * STEP_MS + SETTLE_MS - nowMs };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function createTotpPicker(clock: () => number = Date.now, wait: (ms: number) => Promise<void> = sleep): (s: Secrets) => Promise<string> {
  let lastUsed: number | undefined;
  return async (s) => {
    const p = planTotp(clock(), s.step0, s.codes.length, lastUsed);
    if (p.kind === 'exhausted') throw safeError('[env] totp-window-exhausted', 'totp-window-exhausted');
    if (p.waitMs > 0) await wait(p.waitMs);
    lastUsed = p.step;
    return s.codes[p.index];
  };
}

export const codeForNextStep = createTotpPicker();
