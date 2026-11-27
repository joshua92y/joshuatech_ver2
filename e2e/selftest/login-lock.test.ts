// e2e/selftest/login-lock.test.ts — 로그인 잠금 표식(설계 D10 ⑦ · r2 — V-4) selftest.
// (토큰 홈 · env 값 · 디렉터리)를 인자로 받는 순수 함수만 시험한다 — 실제 표식 자리는 건드리지 않는다.
import { test, expect } from '@playwright/test';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { LOCK_DIR_NAME, LOCK_FILE_NAME, RUN_MARKER_NAME, lockDecision, lockGate, lockLocation, lockPresent, profileDecision, recordLock, runMarkerPath, tokenHome, writeLock } from '../lib/login-lock';

const HOME = 'C:\\Users\\e2e-op';

test('login-lock: location is <token home>\\AppData\\Local\\jt-e2e-lock\\e2e-login-lock.json', () => {
  const loc = lockLocation(HOME, { USERPROFILE: HOME, LOCALAPPDATA: HOME + '\\AppData\\Local' });
  expect(loc.dir).toBe('C:\\Users\\e2e-op\\AppData\\Local\\jt-e2e-lock');
  expect(loc.file).toBe('C:\\Users\\e2e-op\\AppData\\Local\\jt-e2e-lock\\e2e-login-lock.json');
  expect(loc.mismatch).toEqual([]);
  expect(LOCK_DIR_NAME).toBe('jt-e2e-lock');
  expect(LOCK_FILE_NAME).toBe('e2e-login-lock.json');
});

test('login-lock: separate from the O-9 DPAPI JWT directory (%LOCALAPPDATA%\\jt-e2e)', () => {
  const loc = lockLocation(HOME, {});
  expect(path.win32.basename(loc.dir)).not.toBe('jt-e2e');
  expect(path.win32.dirname(loc.dir)).toBe('C:\\Users\\e2e-op\\AppData\\Local');
});

test('login-lock: env comparison is normalized and case-insensitive', () => {
  expect(lockLocation(HOME, { USERPROFILE: 'c:\\users\\E2E-OP\\', LOCALAPPDATA: 'C:/Users/e2e-op/AppData/Local/' }).mismatch).toEqual([]);
  expect(lockLocation(HOME, {}).mismatch).toEqual([]);
});

test('login-lock: profile env that points elsewhere is reported by name', () => {
  expect(lockLocation(HOME, { USERPROFILE: 'D:\\other' }).mismatch).toEqual(['USERPROFILE']);
  expect(lockLocation(HOME, { LOCALAPPDATA: 'D:\\other\\Local' }).mismatch).toEqual(['LOCALAPPDATA']);
  expect(lockLocation(HOME, { USERPROFILE: 'D:\\a', LOCALAPPDATA: 'D:\\b' }).mismatch).toEqual(['USERPROFILE', 'LOCALAPPDATA']);
});

test('login-lock: profile mismatch → [guard] in a live run, INFO otherwise', () => {
  expect(profileDecision(['USERPROFILE'], true)).toEqual({ kind: 'stop', prefix: 'guard', code: 'profile-env-mismatch USERPROFILE' });
  expect(profileDecision(['USERPROFILE'], false)).toEqual({ kind: 'info', text: 'profile-env-mismatch USERPROFILE' });
  expect(profileDecision([], true)).toEqual({ kind: 'none' });
});

test('login-lock: lock present → [guard] in a live run (never deleted), INFO otherwise', () => {
  expect(lockDecision(true, true)).toEqual({ kind: 'stop', prefix: 'guard', code: 'login-lock present' });
  expect(lockDecision(true, false)).toEqual({ kind: 'info', text: 'login-lock present' });
  expect(lockDecision(false, true)).toEqual({ kind: 'none' });
});

test('login-lock: write records only step, UTC and run id', async ({}, testInfo) => {
  const file = path.join(testInfo.outputPath('lock'), LOCK_FILE_NAME);
  expect(lockPresent(file)).toBe(false);
  writeLock(file, { step: 'password', runId: 't077-20261123T090000Z-a1b2c3', utc: '2026-11-23T09:00:00Z' });
  expect(lockPresent(file)).toBe(true);
  const rec = JSON.parse(fs.readFileSync(file, 'utf8'));
  expect(Object.keys(rec).sort()).toEqual(['runId', 'step', 'utc']);
  expect(rec.step).toBe('password');
});

test('login-lock: token home comes from the process token, not from USERPROFILE', () => {
  expect(tokenHome()).toBe(os.userInfo().homedir);
});

test('login-lock: the run-scoped write-failed marker lives in the block root (else <tmp>/jt-e2e/<runId>)', () => {
  expect(RUN_MARKER_NAME).toBe('login-lock-write-failed');
  expect(runMarkerPath({ JT_E2E_ROOT: 'D:\\blocks\\t077-x', JT_E2E_RUN_ID: 't077-20261123T090000Z-a1b2c3' }, 'C:\\tmp')).toBe(path.join('D:\\blocks\\t077-x', 'login-lock-write-failed'));
  expect(runMarkerPath({ JT_E2E_RUN_ID: 't077-20261123T090000Z-a1b2c3' }, 'C:\\tmp')).toBe(path.join('C:\\tmp', 'jt-e2e', 't077-20261123T090000Z-a1b2c3', 'login-lock-write-failed'));
  // 상대 루트 · 꼴이 아닌 run id는 쓰지 않는다
  expect(runMarkerPath({ JT_E2E_ROOT: 'rel\\root', JT_E2E_RUN_ID: '../x' }, 'C:\\tmp')).toBe(path.join('C:\\tmp', 'jt-e2e', 'unknown-run', 'login-lock-write-failed'));
});

test('login-lock: the credential gate stops on a lock or a run-scoped write-failed marker before any value is read (리뷰 B-4)', async ({}, testInfo) => {
  const dir = testInfo.outputPath('gate');
  const withLock = { file: path.join(dir, 'a', 'lock', LOCK_FILE_NAME), runMarker: path.join(dir, 'a', 'root', RUN_MARKER_NAME) };
  expect(lockGate(withLock)).toBeNull();
  writeLock(withLock.file, { step: 'password', runId: 'r' });
  expect(lockGate(withLock)).toEqual({ prefix: 'guard', code: 'login-lock present', note: 'operator check' });
  const withMarker = { file: path.join(dir, 'b', 'lock', LOCK_FILE_NAME), runMarker: path.join(dir, 'b', 'root', RUN_MARKER_NAME) };
  fs.mkdirSync(path.dirname(withMarker.runMarker), { recursive: true });
  fs.writeFileSync(withMarker.runMarker, '{}');
  expect(lockGate(withMarker)).toEqual({ prefix: 'guard', code: 'login-lock write-failed', note: 'a credential step did not advance in this run and the lock could not be written - operator check' });
});

test('login-lock: recordLock writes the lock; when that fails it leaves the run-scoped marker so the remaining live tests stop (리뷰 B-4)', async ({}, testInfo) => {
  const dir = testInfo.outputPath('record');
  const ok = { file: path.join(dir, 'lock', LOCK_FILE_NAME), runMarker: path.join(dir, 'root', RUN_MARKER_NAME) };
  expect(recordLock(ok, { step: 'totp', runId: 'r1' })).toBe('lock');
  expect(lockPresent(ok.file)).toBe(true);
  expect(lockPresent(ok.runMarker)).toBe(false);
  // 표식 자리가 쓸 수 없는 곳(일반 파일 아래)이면 실행 표식으로 물러난다
  fs.mkdirSync(dir, { recursive: true });
  const blocker = path.join(dir, 'blocker');
  fs.writeFileSync(blocker, 'x');
  const bad = { file: path.join(blocker, 'lock', LOCK_FILE_NAME), runMarker: path.join(dir, 'root2', RUN_MARKER_NAME) };
  expect(recordLock(bad, { step: 'password', runId: 'r2' })).toBe('run-marker');
  expect(lockPresent(bad.runMarker)).toBe(true);
  expect(lockGate(bad)?.code).toBe('login-lock write-failed');
  const rec = JSON.parse(fs.readFileSync(bad.runMarker, 'utf8'));
  expect(Object.keys(rec).sort()).toEqual(['runId', 'step', 'utc']);
  // 둘 다 못 쓰면 'failed'
  const worse = { file: path.join(blocker, 'a', LOCK_FILE_NAME), runMarker: path.join(blocker, 'b', RUN_MARKER_NAME) };
  expect(recordLock(worse, { step: 'password', runId: 'r3' })).toBe('failed');
});
