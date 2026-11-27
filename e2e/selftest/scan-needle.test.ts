// e2e/selftest/scan-needle.test.ts — 바늘 스캔(설계 D10 ⑧ · r2 — V-6) selftest. 브라우저 0 · 네트워크 0.
// 바늘은 시험 안에서 만든다(리터럴 0 · 접두는 env-contract의 꼴 상수).
// scan-needle.mjs는 런처(ESM)도 싣는다 — 같은 워커에서 한 번은 CJS로 · 한 번은 ESM으로 실리면 이름 있는 내보내기가 깨지므로 동적 import(ESM)로만 싣는다.
import { test as base, expect } from '@playwright/test';
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { NEEDLE_PREFIX } from '../lib/env-contract';

type Scan = typeof import('../lib/scan-needle.mjs');

const test = base.extend<{ S: Scan }>({
  S: async ({}, use) => {
    await use(await import('../lib/scan-needle.mjs'));
  },
});

function needle(tag: string) {
  const fixedPart = NEEDLE_PREFIX + tag + '-';
  const value = fixedPart + crypto.randomBytes(6).toString('hex');
  return { name: tag, value, kind: 'fragment' as const, fixed: fixedPart.length };
}

test('scan-needle: forms cover full, base64, base64url, sha256 and 8-char random fragments', ({ S }) => {
  const n = needle('pw');
  const f = S.forms(n);
  expect(f.includes(n.value)).toBe(true);
  const sha = crypto.createHash('sha256').update(n.value).digest('hex');
  expect(f.includes(sha)).toBe(true);
  expect(f.includes(sha.toUpperCase())).toBe(true);
  expect(f.includes(n.value.slice(n.fixed - 1, n.fixed + 7))).toBe(true);
  expect(f.some((x) => x === NEEDLE_PREFIX.slice(0, 8))).toBe(false);
  for (const x of f) {
    if (x.length >= 8 && n.value.includes(x)) {
      const at = n.value.indexOf(x);
      expect(at + x.length > n.fixed, `fragment ${at}`).toBe(true);
    }
  }
});

test('scan-needle: each planted encoding is found in a log text', ({ S }) => {
  const n = needle('ck');
  const buf = Buffer.from(n.value);
  const planted = [
    n.value,
    buf.toString('base64'),
    buf.toString('base64url'),
    crypto.createHash('sha256').update(n.value).digest('hex'),
    crypto.createHash('sha256').update(n.value).digest('hex').toUpperCase(),
    n.value.slice(n.fixed - 2, n.fixed + 6),
    Buffer.from('ab' + n.value + 'cd').toString('base64'),
    Buffer.from('x' + n.value).toString('base64url'),
    'cookie: jt_session=' + n.value + '; Path=/',
    encodeURIComponent('q=' + n.value),
  ];
  planted.forEach((p, i) => {
    expect(S.countText(`line one\nprefix ${p} suffix\n`, [n]), `planted #${i}`).toBeGreaterThan(0);
  });
});

test('scan-needle: unplanted control, prefix-only text and short fragments give 0', ({ S }) => {
  const n = needle('pw');
  // 가장 짧은 조각(고정부 7자 + 난수 1자)이 겹치지 않게 대조 바늘의 첫 난수 글자를 다르게 만든다 — 실제 실행에는 같은 꼴의 값이 하나뿐이다.
  const first = n.value[n.fixed];
  const flip = first === '0' ? '1' : '0';
  const sameShape = n.value.slice(0, n.fixed) + flip + crypto.randomBytes(6).toString('hex').slice(1);
  const otherTag = needle('ot');
  expect(S.countText(`nothing here ${sameShape}`, [n])).toBe(0);
  expect(S.countText(`nothing here ${otherTag.value}`, [n])).toBe(0);
  expect(S.countText(`only the fixed part ${NEEDLE_PREFIX}pw-zzzzzzzzzzzz`, [n])).toBe(0);
  expect(S.countText(`seven ${n.value.slice(n.fixed, n.fixed + 7)} chars`, [n])).toBe(0);
});

test('scan-needle: 6-digit codes and fake IP / UA match only as whole values', ({ S }) => {
  const code = { name: 'code', value: '123456', kind: 'code' as const };
  expect(S.countText('otp 123456 ok', [code])).toBe(1);
  expect(S.countText('n=91234567', [code])).toBe(0);
  expect(S.countText('t=1234567', [code])).toBe(0);
  const ip = { name: 'ip', value: '203.0.113.7', kind: 'exact' as const };
  expect(S.countText('from 203.0.113.7 ok', [ip])).toBe(1);
  expect(S.countText('from 203.0.113.77 ok', [ip])).toBe(0);
  const ua = { name: 'ua', value: NEEDLE_PREFIX + 'UA/' + crypto.randomBytes(4).toString('hex'), kind: 'exact' as const };
  expect(S.countText(`agent ${ua.value} x`, [ua])).toBe(1);
  expect(S.countText(`agent ${encodeURIComponent(ua.value)} x`, [ua])).toBe(1);
});

test('scan-needle: surfaces — files, directories (with exclusion), UTF-16 and texts; counts only', async ({ S }, testInfo) => {
  const n = needle('az');
  const root = testInfo.outputPath('surf');
  const logs = path.join(root, 'logs');
  fs.mkdirSync(path.join(root, 'deep', 'er'), { recursive: true });
  fs.mkdirSync(logs, { recursive: true });
  fs.writeFileSync(path.join(root, 'deep', 'er', 'a.bin'), Buffer.concat([crypto.randomBytes(64), Buffer.from(n.value), crypto.randomBytes(64)]));
  fs.writeFileSync(path.join(root, 'deep', 'u16.txt'), Buffer.from('x' + n.value, 'utf16le'));
  fs.writeFileSync(path.join(logs, 'stdout.log'), `ok\n${n.value}\n`);
  fs.writeFileSync(path.join(root, 'clean.txt'), 'nothing');
  expect(S.listFiles(root, []).length).toBe(4);
  expect(S.listFiles(root, [logs]).length).toBe(3);
  expect(S.listFiles(path.join(root, 'missing'), [])).toEqual([]);
  const hits = S.scanSurfaces([n], [
    { name: 'log', files: [path.join(logs, 'stdout.log')] },
    { name: 'root', dirs: [root], exclude: [logs] },
    { name: 'empty', dirs: [path.join(root, 'missing')] },
    { name: 'git-status', texts: ['?? e2e/lib/x.ts\n'] },
  ]);
  expect(Object.keys(hits)).toEqual(['log', 'root', 'empty', 'git-status']);
  expect(hits.log).toBeGreaterThan(0);
  expect(hits.root).toBeGreaterThanOrEqual(2);
  expect(hits.empty).toBe(0);
  expect(hits['git-status']).toBe(0);
  for (const v of Object.values(hits)) expect(typeof v).toBe('number');
});

test('scan-needle: UTF-16LE text at an odd byte offset is found (positive control for the shifted decoding — 리뷰 C-6)', async ({ S }, testInfo) => {
  const n = needle('az');
  const dir = testInfo.outputPath('u16-odd');
  fs.mkdirSync(dir, { recursive: true });
  // 1바이트 접두 뒤의 UTF-16LE — 짝수 정렬 디코딩으로는 글자가 어긋나 보이지 않는다
  fs.writeFileSync(path.join(dir, 'odd.bin'), Buffer.concat([Buffer.from([0x41]), Buffer.from(n.value, 'utf16le')]));
  fs.writeFileSync(path.join(dir, 'even.bin'), Buffer.from(n.value, 'utf16le'));
  const odd = S.scanSurfaces([n], [{ name: 'odd', files: [path.join(dir, 'odd.bin')] }]);
  const even = S.scanSurfaces([n], [{ name: 'even', files: [path.join(dir, 'even.bin')] }]);
  expect(odd.odd).toBeGreaterThan(0);
  expect(even.even).toBeGreaterThan(0);
  const clean = S.scanSurfaces([n], [{ name: 'clean', files: [path.join(dir, 'missing.bin')] }]);
  expect(clean.clean).toBe(0);
});

test('scan-needle: binary artifacts (zip · webm · png, any case) under a root are counted as hits by themselves; evidence and logs are excluded (리뷰 B-1)', async ({ S }, testInfo) => {
  const root = testInfo.outputPath('artifacts');
  const evidence = path.join(root, 'evidence');
  const logs = path.join(root, 'logs');
  for (const d of [path.join(root, 'out', 'a'), evidence, logs]) fs.mkdirSync(d, { recursive: true });
  expect(S.countArtifacts([root], [evidence, logs])).toBe(0);
  fs.writeFileSync(path.join(root, 'out', 'a', 'trace.zip'), 'PK');
  fs.writeFileSync(path.join(root, 'out', 'a', 'video.WEBM'), 'x');
  fs.writeFileSync(path.join(root, 'out', 'test-failed-1.Png'), 'x');
  fs.writeFileSync(path.join(root, 'out', 'error-context.md'), 'x');
  fs.writeFileSync(path.join(evidence, 'sessions.png'), 'x');
  fs.writeFileSync(path.join(logs, 'needle.stdout.log'), 'x');
  expect(S.countArtifacts([root], [evidence, logs])).toBe(3);
  expect(S.countArtifacts([path.join(root, 'missing')], [])).toBe(0);
  expect([...S.ARTIFACT_EXTENSIONS].sort()).toEqual(['.png', '.webm', '.zip']);
});
