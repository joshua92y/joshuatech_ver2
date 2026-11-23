// e2e/lib/pace.ts — 호출 간격(설계 D7 · plan A32 · VD-3). 모든 요청 · 탐색 호출은 앞 호출과 ≥ 200 ms 떨어진다(Rate Limiting에 스스로 걸리지 않게).

export const MIN_GAP_MS = 200;

export function waitNeeded(nowMs: number, lastMs: number | undefined, gapMs: number = MIN_GAP_MS): number {
  if (lastMs === undefined) return 0;
  const w = lastMs + gapMs - nowMs;
  return w > 0 ? w : 0;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function createPacer(gapMs: number = MIN_GAP_MS, clock: () => number = Date.now, wait: (ms: number) => Promise<void> = sleep): () => Promise<void> {
  let last: number | undefined;
  return async () => {
    const w = waitNeeded(clock(), last, gapMs);
    if (w > 0) await wait(w);
    last = clock();
  };
}

export const pace = createPacer();
