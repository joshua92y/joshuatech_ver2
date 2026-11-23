// e2e/lib/auth-dir.ts — e2e/.auth 수명(설계 D3 ⑤ · D6 state-dead · D10 ⑥ · 〔77-14〕). gitignore 대상 · 실행 뒤 0.
// T077은 로그아웃 뒤의 죽은 상태만 여기에 쓴다(살아 있는 세션은 디스크에 놓이지 않는다). 삭제는 세 겹: 시험 teardown → globalTeardown → 블록 finally.
import * as fs from 'node:fs';
import * as path from 'node:path';
import { safeError } from './http';

export const AUTH_DIR = path.resolve(__dirname, '..', '.auth');

const RUN_ID = /^[A-Za-z0-9][A-Za-z0-9-]*$/;

function countFiles(dir: string): number {
  let n = 0;
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) n += countFiles(full);
    else n += 1;
  }
  return n;
}

export function countResidue(dir: string = AUTH_DIR): number {
  if (!fs.existsSync(dir)) return 0;
  return countFiles(dir);
}

export function removeAll(dir: string = AUTH_DIR): void {
  fs.rmSync(dir, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
  if (fs.existsSync(dir)) throw safeError('auth-dir: residue could not be removed', 'auth-residue');
}

export function deadStatePath(runId: string, dir: string = AUTH_DIR): string {
  if (!RUN_ID.test(runId)) throw safeError('auth-dir: run id rejected', 'run-id');
  return path.join(dir, `${runId}-t077.json`);
}

export function writeDeadState(state: unknown, runId: string, dir: string = AUTH_DIR): string {
  const file = deadStatePath(runId, dir);
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(file, JSON.stringify(state), { encoding: 'utf8', flag: 'wx' });
  return file;
}

// 파일 하나 지우기 — unlinkSync + 지운 뒤 확인. Node v24.11.1 · Windows의 비재귀 fs.rmSync(<파일>)은 경로에 비ASCII(한글) 글자가 있으면
// 오류 없이 파일을 남기거나 프로세스를 중단시킨다(r1 실측 — unlinkSync는 지운다). 없는 파일은 조용히 지나간다.
export function removeFile(file: string): void {
  try {
    fs.unlinkSync(file);
  } catch (e) {
    if ((e as { code?: unknown }).code !== 'ENOENT') throw safeError('auth-dir: file could not be removed', 'auth-residue');
  }
  if (fs.existsSync(file)) throw safeError('auth-dir: file could not be removed', 'auth-residue');
}
