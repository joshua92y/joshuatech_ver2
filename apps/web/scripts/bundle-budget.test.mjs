// apps/web/scripts/bundle-budget.test.mjs — T088(US5 · 시험 먼저 · vitest). 짝 구현 = T093 `apps/web/scripts/bundle-budget.mjs`.
//
// 과제(tasks.md T088): dry-run outdir 픽스처의 gzip 합산 계산, 2,621,440 bytes 초과 시 exit 1, 이하 0 — FAIL 확인.
// 정본: specs/003-platform-foundation/design/t086-design.md D5 · D12(T088) · spec AC4 · FR-028.
// 빨강(T093 전): 이 파일을 수집할 때 "./bundle-budget.mjs" 로드가 실패한다(구현 없음).
//
// 이 시험이 고정하는 모듈 API(시험 머리 주석이 정본 — T093은 이름 · 꼴 그대로 만족한다):
//   ESM · Node 내장만 import한다.
//   · LIMIT_BYTES = 2_621_440(= 2.5 MiB — tasks.md:240 문면)
//   · MEASURED_EXTENSIONS = ['.js', '.mjs', '.wasm', '.bin'](.map과 그 밖은 세지 않는다 — VD-T088-1)
//   · measureDir(dir) → { files, gzipBytes }: 재귀 · 이름순 · 심볼릭 링크 미추적. 확장자가 MEASURED_EXTENSIONS인 일반 파일마다
//       zlib.gzipSync(buf, { level: 9 }).length를 더한다(files = 센 파일 수).
//   · judge(gzipBytes, limit = LIMIT_BYTES) → boolean(gzipBytes ≤ limit이면 true — 이하 통과)
//   · formatSummary(r) → CLI 요약 줄을 만드는 도우미(인자 꼴은 T093 재량 — 이 시험은 CLI 출력으로만 본다)
//   · CLI node bundle-budget.mjs --measure <dir> [--limit <bytes>]
//       stdout 정확히 한 줄(인쇄 가능 ASCII + '\n'):
//         bundle-budget files=<n> gzip_bytes=<n> gzip_mib=<x.xx> limit_bytes=<n> result=pass|fail
//         (gzip_mib = gzip_bytes / 1,048,576을 소수 둘째 자리로)
//       종료 코드 0 = 이하(result=pass) · 1 = 초과(result=fail — 요약 줄과 함께)
//         · 2 = 사용 오류(--measure 누락 · 값 없음 · 디렉터리 없음 · 측정 대상 0(빈 디렉터리 · .map만) · --limit가 10진 정수 아님)
//           — 이때 stdout 빈 값 · stderr 한 줄 `bundle-budget: error <code>`(code = 소문자 · 숫자 · '-' · '_')
//       인자 없음 = T093 빌드 경로(opennextjs-cloudflare build → wrangler versions upload --dry-run --outdir → 측정) — 시험 밖.
//       import만으로는 돌지 않는다(import.meta.main 가드).
// 픽스처는 커밋하지 않는다: 실행 중 mkdtempSync + crypto.randomBytes(압축되지 않는 바이트) → afterEach 삭제.
// 기대 gzip 합은 이 시험이 따로 계산한다(측정 대상 표시는 픽스처 표가 정한다 — MEASURED_EXTENSIONS를 빌려 쓰지 않는다).
// 자식 node는 네트워크에 닿지 않는다(임시 디렉터리 cwd · 인자 고정).

import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { gzipSync } from 'node:zlib';

import { afterEach, describe, expect, it } from 'vitest';

import { LIMIT_BYTES, MEASURED_EXTENSIONS, judge, measureDir } from './bundle-budget.mjs';

const SCRIPT = fileURLToPath(new URL('./bundle-budget.mjs', import.meta.url));
const SUMMARY_RE = /^bundle-budget files=(\d+) gzip_bytes=(\d+) gzip_mib=(\d+\.\d{2}) limit_bytes=(\d+) result=(pass|fail)$/;
const USAGE_RE = /^bundle-budget: error [a-z0-9_-]+$/;
const CHILD_TIMEOUT_MS = 60_000;

// bb-1 픽스처 표: [상대 경로, 바이트 수, 측정 대상인가]
const BB1_TREE = [
  ['a.js', 1500, true],
  ['sub/b.mjs', 2300, true],
  ['c.wasm', 900, true],
  ['d.bin', 3100, true],
  ['e.js.map', 1700, false],
  ['f.txt', 1200, false],
];

const temps = [];

afterEach(() => {
  for (const dir of temps.splice(0)) rmSync(dir, { recursive: true, force: true });
});

/** afterEach가 지우는 빈 임시 디렉터리 */
function tempDir() {
  const dir = mkdtempSync(join(tmpdir(), 'jt-bundle-budget-'));
  temps.push(dir);
  return dir;
}

/** entries([경로, 바이트 수, 측정 대상])를 무작위 바이트로 쓰고 독립 기대값 { dir, files, gzip }을 돌려준다 */
function writeTree(entries) {
  const dir = tempDir();
  let files = 0;
  let gzip = 0;
  for (const [rel, size, measured] of entries) {
    const full = join(dir, ...rel.split('/'));
    mkdirSync(dirname(full), { recursive: true });
    const buf = randomBytes(size);
    writeFileSync(full, buf);
    if (measured) {
      files += 1;
      gzip += gzipSync(buf, { level: 9 }).length;
    }
  }
  return { dir, files, gzip };
}

/** CLI를 자식 node로 돌린다(cwd = 빈 임시 디렉터리) */
function runCli(args) {
  const r = spawnSync(process.execPath, [SCRIPT, ...args], { cwd: tempDir(), encoding: 'utf8', timeout: CHILD_TIMEOUT_MS });
  return { status: r.status, stdout: r.stdout ?? '', stderr: r.stderr ?? '' };
}

/** stdout이 요약 한 줄인지 보고 필드를 돌려준다 */
function summaryOf(stdout, label) {
  const lines = stdout.split('\n');
  expect(lines.length === 2 && lines[1] === '', `${label}: stdout 정확히 한 줄('\\n'으로 끝남)`).toBe(true);
  const m = SUMMARY_RE.exec(lines[0]);
  expect(m !== null, `${label}: 요약 줄 꼴`).toBe(true);
  return { files: Number(m[1]), gzipBytes: Number(m[2]), mib: m[3], limitBytes: Number(m[4]), result: m[5] };
}

describe('bundle-budget — 모듈 API', () => {
  it('bb-1 measureDir — 재귀 · 측정 확장자만(.map · .txt 제외) · 파일마다 gzip -9 합', () => {
    expect(MEASURED_EXTENSIONS).toEqual(['.js', '.mjs', '.wasm', '.bin']);
    const t = writeTree(BB1_TREE);
    const r = measureDir(t.dir);
    expect(r.files, 'bb-1 files').toBe(4);
    expect(r.gzipBytes, 'bb-1 gzipBytes = 독립 level 9 합').toBe(t.gzip);
  });

  it('bb-2 한도 = 2.5 × 1024 × 1024 = 2,621,440 B · CLI 기본 한도가 그 값', () => {
    expect(LIMIT_BYTES).toBe(2.5 * 1024 * 1024);
    expect(LIMIT_BYTES).toBe(2_621_440);
    const t = writeTree([['a.js', 64, true]]);
    const run = runCli(['--measure', t.dir]);
    expect(summaryOf(run.stdout, 'bb-2').limitBytes, 'bb-2 limit_bytes 기본').toBe(2_621_440);
  });

  it('bb-3 경계 — judge(2,621,440) 참 · judge(2,621,441) 거짓 · limit 인자도 이하 통과', () => {
    expect(judge(2_621_440)).toBe(true);
    expect(judge(2_621_441)).toBe(false);
    expect(judge(100, 100)).toBe(true);
    expect(judge(101, 100)).toBe(false);
  });
});

describe('bundle-budget — CLI', () => {
  it('bb-4 CLI 초과 — 2,700,000 B 무작위 .bin → exit 1 · result=fail · gzip_bytes = 독립값 · limit_bytes=2621440', () => {
    const t = writeTree([['d.bin', 2_700_000, true]]);
    expect(t.gzip > 2_621_440, 'bb-4 픽스처가 한도를 넘는다').toBe(true);
    const run = runCli(['--measure', t.dir]);
    expect(run.status, 'bb-4 exit').toBe(1);
    expect(summaryOf(run.stdout, 'bb-4')).toMatchObject({ files: 1, gzipBytes: t.gzip, limitBytes: 2_621_440, result: 'fail' });
  });

  it('bb-5 CLI 통과 — exit 0 · result=pass · stderr 빈 값', () => {
    const t = writeTree(BB1_TREE);
    const run = runCli(['--measure', t.dir]);
    expect(run.status, 'bb-5 exit').toBe(0);
    expect(run.stderr, 'bb-5 stderr').toBe('');
    expect(summaryOf(run.stdout, 'bb-5')).toMatchObject({ files: 4, gzipBytes: t.gzip, limitBytes: 2_621_440, result: 'pass' });
  });

  it('bb-6 --limit 100 → exit 1 · limit_bytes=100 · result=fail', () => {
    const t = writeTree(BB1_TREE);
    const run = runCli(['--measure', t.dir, '--limit', '100']);
    expect(run.status, 'bb-6 exit').toBe(1);
    expect(summaryOf(run.stdout, 'bb-6')).toMatchObject({ gzipBytes: t.gzip, limitBytes: 100, result: 'fail' });
  });

  it('bb-6b CLI 경계 — 독립 합 S: --limit S → exit 0 · --limit S−1 → exit 1', () => {
    const t = writeTree(BB1_TREE);
    const at = runCli(['--measure', t.dir, '--limit', String(t.gzip)]);
    expect(at.status, 'bb-6b --limit S exit').toBe(0);
    expect(summaryOf(at.stdout, 'bb-6b S')).toMatchObject({ gzipBytes: t.gzip, limitBytes: t.gzip, result: 'pass' });
    const below = runCli(['--measure', t.dir, '--limit', String(t.gzip - 1)]);
    expect(below.status, 'bb-6b --limit S-1 exit').toBe(1);
    expect(summaryOf(below.stdout, 'bb-6b S-1')).toMatchObject({ gzipBytes: t.gzip, limitBytes: t.gzip - 1, result: 'fail' });
  });

  it.each([
    ['디렉터리 없음', (t) => ['--measure', join(t.dir, 'absent')]],
    ['빈 디렉터리', (t) => ['--measure', join(t.dir, 'empty')]],
    ['.map만', (t) => ['--measure', join(t.dir, 'maps')]],
    ['--measure 값 없음', () => ['--measure']],
    ['--measure 누락', () => ['--limit', '100']],
    ['--limit abc', (t) => ['--measure', t.dir, '--limit', 'abc']],
  ])('bb-7 사용 오류 — %s → exit 2 · stdout 빈 값 · stderr 한 줄', (_name, argsOf) => {
    const t = writeTree([['a.js', 64, true], ['maps/x.js.map', 64, false]]);
    mkdirSync(join(t.dir, 'empty'));
    const run = runCli(argsOf(t));
    expect(run.status, 'bb-7 exit').toBe(2);
    expect(run.stdout, 'bb-7 stdout').toBe('');
    const lines = run.stderr.split('\n');
    expect(lines.length === 2 && lines[1] === '' && USAGE_RE.test(lines[0]), 'bb-7 stderr 한 줄 `bundle-budget: error <code>`').toBe(true);
  });

  it('bb-8 출력 위생 — 통과 · 초과 모두 stdout 한 줄 · 인쇄 가능 ASCII · gzip_mib = gzip_bytes / 1 MiB', () => {
    const t = writeTree(BB1_TREE);
    for (const args of [['--measure', t.dir], ['--measure', t.dir, '--limit', '100']]) {
      const run = runCli(args);
      const s = summaryOf(run.stdout, `bb-8 ${args.length}`);
      const body = run.stdout.slice(0, -1);
      expect([...body].every((ch) => ch >= ' ' && ch <= '~'), 'bb-8 인쇄 가능 ASCII').toBe(true);
      expect(Math.abs(Number(s.mib) - s.gzipBytes / 1_048_576) <= 0.005 + 1e-9, 'bb-8 gzip_mib 반올림').toBe(true);
    }
  });

  it('bb-9 import 무실행 — 자식 import → stdout 빈 값 · exit 0 / 직접 실행은 요약 줄', () => {
    const child = spawnSync(
      process.execPath,
      ['--input-type=module', '-e', `await import(${JSON.stringify(pathToFileURL(SCRIPT).href)});`],
      { cwd: tempDir(), encoding: 'utf8', timeout: CHILD_TIMEOUT_MS },
    );
    expect(child.status, 'bb-9 import exit').toBe(0);
    expect(child.stdout, 'bb-9 import stdout').toBe('');
    const t = writeTree([['a.js', 64, true]]);
    const direct = runCli(['--measure', t.dir]);
    expect(direct.status, 'bb-9 직접 실행 exit').toBe(0);
    expect(summaryOf(direct.stdout, 'bb-9 직접 실행').result).toBe('pass');
  });
});
