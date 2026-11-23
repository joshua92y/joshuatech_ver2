// e2e/lib/evidence.ts — 증거 스크린샷(설계 D10 ⑨ · r1 — B-4 ② ④ · 〔77-4〕 · 〔77-15〕). 자동 screenshot은 off — 증거는 이 helper의 명시적 mask 촬영만.
// mask 로케이터마다 count()가 표 행 수(≥ 1)와 같을 때만 찍고, 아니면 찍지 않고 [product] mask-target-missing.
// 파일은 JT_E2E_EVIDENCE_DIR(저장소 밖)에만 · 커밋 0 · 보고에는 파일 이름 · SHA-256 · 가린 칸 목록만.
import type { Locator, Page } from '@playwright/test';
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { errorCode, safeError } from './http';
import { emitInfo } from './out';

const REPO_ROOT = path.resolve(__dirname, '..', '..');
const NAME = /^[a-z0-9][a-z0-9-]*$/;
const RUN_ID = /^[A-Za-z0-9][A-Za-z0-9-]*$/;

export interface MaskSpec {
  label: string;
  locator: Locator;
}

export function masksMatch(rows: number, counts: readonly number[]): boolean {
  return Number.isInteger(rows) && rows >= 1 && counts.length > 0 && counts.every((c) => c === rows);
}

export function evidenceDir(env: Record<string, string | undefined> = process.env, tmp: string = os.tmpdir()): string {
  if (env.JT_E2E_EVIDENCE_DIR) return env.JT_E2E_EVIDENCE_DIR;
  const runId = env.JT_E2E_RUN_ID;
  if (!runId || !RUN_ID.test(runId)) throw safeError('evidence: run id missing', 'run-id');
  return path.join(tmp, 'jt-e2e', runId, 'evidence');
}

function insideRepo(dir: string): boolean {
  const rel = path.relative(REPO_ROOT, path.resolve(dir));
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

export async function evidenceShot(page: Page, name: string, rows: number, masks: readonly MaskSpec[], opts: { dir?: string } = {}): Promise<{ file: string; sha256: string; masked: string[] }> {
  if (!NAME.test(name)) throw safeError('evidence: name rejected', 'error');
  for (const m of masks) if (!NAME.test(m.label)) throw safeError('evidence: mask label rejected', 'error');
  const counts: number[] = [];
  for (const m of masks) counts.push(await m.locator.count());
  if (!masksMatch(rows, counts)) throw safeError('[product] mask-target-missing', 'mask-target-missing');
  const dir = opts.dir ?? evidenceDir();
  if (insideRepo(dir)) throw safeError('evidence: dir must be outside the repository', 'evidence-dir');
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `${name}.png`);
  try {
    await page.screenshot({ path: file, mask: masks.map((m) => m.locator), animations: 'disabled', caret: 'hide' });
  } catch (e) {
    const code = errorCode(e);
    throw safeError(`evidence ${name} failed (${code})`, code);
  }
  const sha256 = crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const masked = masks.map((m) => m.label);
  emitInfo(`evidence file=${name}.png sha256=${sha256} masks=${masked.join(',')}`);
  return { file, sha256, masked };
}
