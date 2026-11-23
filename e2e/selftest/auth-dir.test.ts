// e2e/selftest/auth-dir.test.ts — e2e/.auth 수명(설계 D3 ⑤ · D6 state-dead · D10 ⑥) selftest. 실제 e2e/.auth는 건드리지 않는다(임시 디렉터리만).
import { test, expect } from '@playwright/test';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { AUTH_DIR, countResidue, deadStatePath, removeAll, removeFile, writeDeadState } from '../lib/auth-dir';

test('auth-dir: AUTH_DIR is <repo>/e2e/.auth', () => {
  const expected = path.resolve(__dirname, '..', '.auth');
  expect(path.relative(expected, AUTH_DIR)).toBe('');
});

test('auth-dir: residue count is recursive and 0 for a missing directory', async ({}, testInfo) => {
  const dir = testInfo.outputPath('auth-a');
  expect(countResidue(dir)).toBe(0);
  fs.mkdirSync(path.join(dir, 'nested'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'a.json'), '{}');
  fs.writeFileSync(path.join(dir, 'nested', 'b.json'), '{}');
  expect(countResidue(dir)).toBe(2);
  removeAll(dir);
  expect(fs.existsSync(dir)).toBe(false);
  expect(countResidue(dir)).toBe(0);
});

test('auth-dir: dead state file is <runId>-t077.json inside the directory', async ({}, testInfo) => {
  const dir = testInfo.outputPath('auth-b');
  const runId = 't077-20261123T090000Z-a1b2c3';
  expect(deadStatePath(runId, dir)).toBe(path.join(dir, `${runId}-t077.json`));
  const file = writeDeadState({ cookies: [{ name: 'n' }], origins: [] }, runId, dir);
  expect(file).toBe(path.join(dir, `${runId}-t077.json`));
  expect(JSON.parse(fs.readFileSync(file, 'utf8'))).toEqual({ cookies: [{ name: 'n' }], origins: [] });
  expect(countResidue(dir)).toBe(1);
  removeFile(file);
  expect(fs.existsSync(file)).toBe(false);
  removeFile(file);
  removeAll(dir);
});

// 제목은 ASCII만 — 시험 출력 디렉터리 이름이 제목에서 나오고, 아래 removeAll이 그 부모를 지운다
test('auth-dir: removeFile really removes the file even on a non-ASCII path and verifies it (Node 24.11.1 Windows rmSync)', async ({}, testInfo) => {
  // Node v24.11.1 · Windows: 비재귀 fs.rmSync(<파일>)이 경로에 한글이 있으면 오류 없이 파일을 남기거나 프로세스를 중단시킨다(unlinkSync는 지운다 — 스크래치 실측).
  const dir = path.join(testInfo.outputPath('auth-c'), '세션-dir');
  const file = writeDeadState({ cookies: [], origins: [] }, 't077-20261123T090000Z-a1b2c3', dir);
  expect(fs.existsSync(file)).toBe(true);
  removeFile(file);
  expect(fs.existsSync(file), 'dead state file removed').toBe(false);
  removeFile(file); // 없는 파일은 조용히 지나간다
  removeAll(path.dirname(dir));
});

test('auth-dir: run ids with separators or dots are refused', () => {
  for (const bad of ['../x', 'a/b', 'a\\b', '..', '', 'a.b']) {
    expect(() => deadStatePath(bad, 'C:\\tmp\\x'), bad).toThrow(/run id/);
  }
});
