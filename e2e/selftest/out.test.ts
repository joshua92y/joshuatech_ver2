// e2e/selftest/out.test.ts — 출력 통로 out.ts(설계 D5 · D10 ⑤) selftest. 브라우저 0 · 네트워크 0.
import { test, expect } from '@playwright/test';
import { SEP, checkLine, emit, formatInfo, formatStep, formatStop, formatSummary } from '../lib/out';

test('out: step line — machine part ASCII, note after the separator', () => {
  const line = formatStep('T077', 'reach', 'FAIL', '[gate] authentik-absent until T080', 'Traefik 404 서명 일치');
  expect(line).toBe('T077 reach FAIL [gate] authentik-absent until T080' + SEP + 'Traefik 404 서명 일치');
  expect(formatStep('T077', 'landed', 'PASS')).toBe('T077 landed PASS');
});

test('out: info, stop and summary shapes', () => {
  expect(formatInfo('auth-residue 0')).toBe('INFO auth-residue 0');
  expect(formatStop('guard', 'login-lock present', 'operator check')).toBe('[guard] login-lock present' + SEP + 'operator check');
  expect(formatStop('state', 'previous-run residue')).toBe('[state] previous-run residue');
  expect(formatSummary('T077 steps=3')).toBe('SUMMARY T077 steps=3');
});

test('out: every stop prefix of the failure classification is accepted', () => {
  for (const p of ['gate', 'product', 'env', 'decision', 'guard', 'state'] as const) {
    expect(checkLine(`[${p}] code-${p}`)).toBe(`[${p}] code-${p}`);
  }
});

test('out: rejects newline, carriage return and control characters', () => {
  expect(() => checkLine('INFO a\nINFO b')).toThrow(/newline/);
  expect(() => checkLine('INFO a\rb')).toThrow(/newline/);
  expect(() => checkLine('INFO a\tb')).toThrow(/ASCII/);
  expect(() => checkLine('INFO a' + SEP + 'b' + String.fromCharCode(7) + 'c')).toThrow(/control/);
});

test('out: rejects a non-ASCII machine part but allows Korean after the separator', () => {
  expect(() => checkLine('T077 reach FAIL 한글')).toThrow(/ASCII/);
  expect(checkLine('INFO ok' + SEP + '한글 설명')).toBe('INFO ok' + SEP + '한글 설명');
});

test('out: rejects shapes outside the fixed set (including summary spoofing)', () => {
  for (const bad of ['hello', '3 passed, 0 failed', 'needle=PASS', 'Error: x', 'T077 reach MAYBE', 'T077 Reach PASS', '[other] x', 'INFO', 'SKIP e2e-selftest tests -- x']) {
    expect(() => checkLine(bad), bad).toThrow(/shape|ASCII/);
  }
});

test('out: a rejected line is never echoed in the error message', () => {
  const marker = 'zq' + 'xv' + '91';
  let message = '';
  try {
    checkLine(`not-a-shape ${marker}`);
  } catch (e) {
    message = String((e as Error).message) + String((e as Error).stack);
  }
  expect(message.length).toBeGreaterThan(0);
  expect(message.includes(marker)).toBe(false);
});

test('out: emit writes exactly one line through the writer; a rejected line writes nothing', () => {
  const written: string[] = [];
  emit('INFO one', (s) => written.push(s));
  expect(written).toEqual(['INFO one\n']);
  expect(() => emit('bad line', (s) => written.push(s))).toThrow();
  expect(written.length).toBe(1);
});

test('out: empty note after the separator is rejected', () => {
  expect(() => checkLine('INFO x' + SEP)).toThrow(/note/);
});
