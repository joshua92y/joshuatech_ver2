// e2e/lib/login-lock.ts — 로그인 잠금 표식(설계 D10 ⑦ · r2 — V-4). 비밀번호 · TOTP 단계가 안 넘어가면 남기는 표식(비밀 0 — 단계 · UTC · runId).
// 자리 = <토큰 홈>\AppData\Local\jt-e2e-lock\e2e-login-lock.json. 토큰 홈 = os.userInfo().homedir(프로세스 토큰의 프로필 — env에 기대지 않는다;
// os.homedir()는 USERPROFILE env를 먼저 본다 — VD-T077-3 실측). env USERPROFILE · LOCALAPPDATA는 대조만 한다.
// O-9 DPAPI JWT 디렉터리(%LOCALAPPDATA%\jt-e2e)와 다른 디렉터리다. 실행을 넘어 남고, 운영자가 원인을 확인한 뒤에만 지운다(코드는 지우지 않는다).
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';

export const LOCK_DIR_NAME = 'jt-e2e-lock';
export const LOCK_FILE_NAME = 'e2e-login-lock.json';

const win = path.win32;

export interface LockLocation {
  dir: string;
  file: string;
  mismatch: string[];
}

export type LockDecision = { kind: 'stop'; prefix: 'guard'; code: string } | { kind: 'info'; text: string } | { kind: 'none' };

function norm(p: string): string {
  return win.normalize(p.replace(/\//g, '\\')).replace(/\\+$/, '').toLowerCase();
}

export function tokenHome(): string {
  return os.userInfo().homedir;
}

export function lockLocation(home: string, env: { USERPROFILE?: string; LOCALAPPDATA?: string }): LockLocation {
  const local = win.join(home, 'AppData', 'Local');
  const dir = win.join(local, LOCK_DIR_NAME);
  const mismatch: string[] = [];
  if (env.USERPROFILE !== undefined && norm(env.USERPROFILE) !== norm(home)) mismatch.push('USERPROFILE');
  if (env.LOCALAPPDATA !== undefined && norm(env.LOCALAPPDATA) !== norm(local)) mismatch.push('LOCALAPPDATA');
  return { dir, file: win.join(dir, LOCK_FILE_NAME), mismatch };
}

export function lockPresent(file: string): boolean {
  return fs.existsSync(file);
}

export function writeLock(file: string, rec: { step: string; runId: string; utc?: string }): void {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const body = { step: rec.step, utc: rec.utc ?? new Date().toISOString(), runId: rec.runId };
  fs.writeFileSync(file, JSON.stringify(body), 'utf8');
}

// ---- 실행 중간의 잠금 확인(빌드 리뷰 r1 — B-4) ----
// globalSetup은 실행 시작에서만 본다. 같은 실행의 다음 시험이 같은 자격을 다시 제출하지 않게, 두 spec의 cred 단계(자격 읽기 직전)가 lockGate로 다시 본다.
// 표식 쓰기가 실패하면 실행 범위 표식(블록 소유 루트 아래 — 워커가 다시 떠도 남는다)을 대신 남겨 남은 live 시험을 멈춘다.
export const RUN_MARKER_NAME = 'login-lock-write-failed';
const RUN_ID = /^[A-Za-z0-9][A-Za-z0-9-]*$/;

export interface LockTarget {
  file: string; // 실행을 넘어 남는 잠금 표식(토큰 홈 기준)
  runMarker: string; // 이 실행 안에서만 보는 쓰기 실패 표식
}

export function runMarkerPath(env: Record<string, string | undefined> = process.env, tmp: string = os.tmpdir()): string {
  const root = env.JT_E2E_ROOT;
  if (typeof root === 'string' && root.length > 0 && path.isAbsolute(root)) return path.join(root, RUN_MARKER_NAME);
  const runId = env.JT_E2E_RUN_ID && RUN_ID.test(env.JT_E2E_RUN_ID) ? env.JT_E2E_RUN_ID : 'unknown-run';
  return path.join(tmp, 'jt-e2e', runId, RUN_MARKER_NAME);
}

export function lockGate(t: LockTarget): { prefix: 'guard'; code: string; note: string } | null {
  if (lockPresent(t.file)) return { prefix: 'guard', code: 'login-lock present', note: 'operator check' };
  if (lockPresent(t.runMarker)) return { prefix: 'guard', code: 'login-lock write-failed', note: 'a credential step did not advance in this run and the lock could not be written - operator check' };
  return null;
}

// 'lock' = 표식을 썼다 · 'run-marker' = 표식은 못 쓰고 실행 표식을 썼다 · 'failed' = 둘 다 못 썼다(값 0 — 단계 · UTC · runId만)
export function recordLock(t: LockTarget, rec: { step: string; runId: string; utc?: string }): 'lock' | 'run-marker' | 'failed' {
  try {
    writeLock(t.file, rec);
    return 'lock';
  } catch {
    try {
      writeLock(t.runMarker, rec);
      return 'run-marker';
    } catch {
      return 'failed';
    }
  }
}

export function profileDecision(mismatch: readonly string[], live: boolean): LockDecision {
  if (mismatch.length === 0) return { kind: 'none' };
  const code = `profile-env-mismatch ${mismatch.join(',')}`;
  return live ? { kind: 'stop', prefix: 'guard', code } : { kind: 'info', text: code };
}

export function lockDecision(present: boolean, live: boolean): LockDecision {
  if (!present) return { kind: 'none' };
  return live ? { kind: 'stop', prefix: 'guard', code: 'login-lock present' } : { kind: 'info', text: 'login-lock present' };
}

// 이 프로세스의 실제 표식 자리(globalSetup · 시험이 같은 자리를 본다)
export function liveLockLocation(): LockLocation {
  return lockLocation(tokenHome(), { USERPROFILE: process.env.USERPROFILE, LOCALAPPDATA: process.env.LOCALAPPDATA });
}

export function liveLockTarget(): LockTarget {
  return { file: liveLockLocation().file, runMarker: runMarkerPath(process.env) };
}
