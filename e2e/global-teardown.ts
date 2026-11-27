// e2e/global-teardown.ts — e2e/.auth 정리 두 번째 겹(설계 D3 globalTeardown · D10 ⑥ · 컨트롤러 N-3). 실행 뒤 e2e/.auth 0.
// 빌드 리뷰 r1 — A-2: 지우기 전에 센다. 남아 있으면(이 실행의 정리 겹이 실패했거나 globalSetup이 잔여를 보고하지 못한 경우)
// [state] 줄을 낸 뒤 지우고, 실행을 실패로 끝낸다 — 노출 의심 신호가 조용히 사라지지 않게. 값 0 — 개수만.
import { countResidue, removeAll } from './lib/auth-dir';
import { emitInfo, emitStop, formatStop, type StopPrefix } from './lib/out';

export function teardownDecision(countBefore: number): { fail: boolean; state?: { prefix: StopPrefix; code: string; note: string } } {
  if (countBefore <= 0) return { fail: false };
  return { fail: true, state: { prefix: 'state', code: `auth-residue at teardown count=${countBefore}`, note: 'removed - server session invalidation unconfirmed' } };
}

export default async function globalTeardown(): Promise<void> {
  const d = teardownDecision(countResidue());
  if (d.state) emitStop(d.state.prefix, d.state.code, d.state.note);
  try {
    removeAll();
  } catch {
    emitStop('state', 'auth-residue remove-failed', 'operator check');
    throw new Error(formatStop('state', 'auth-residue remove-failed'));
  }
  emitInfo(`auth-residue ${countResidue()}`);
  if (d.state) throw new Error(formatStop(d.state.prefix, d.state.code));
}
