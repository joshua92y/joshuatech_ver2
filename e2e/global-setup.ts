// e2e/global-setup.ts — 실행 전 관문(설계 D3 globalSetup ①–⑤ · D10 ⑦ · r1 — B-3 · B-5 · B-6 · A-11 · r2 — V-7 · VD-T077-3 · VD-T077-6).
// 줄은 모두 out.ts로 낸다. 멈출 때는 멈춤 줄을 내고 같은 기계 판독 문구로 던진다(값 0 — 이름 · 개수만).
// 순서(빌드 리뷰 r1 — A-2): ⑤ 잔여 계수를 맨 앞에 둔다 — 다른 가드가 먼저 멈춰도 [state] 줄이 늘 나온다(노출 의심 신호가 조용히 사라지지 않게).
// 그 뒤 ① env → ② argv → ③ FullConfig → ④ 프로필 · 잠금 표식. 순서는 순수 함수 setupPlan이 정하고 selftest 표가 고정한다.
// VD-T077-6 실측(1.65.1): CLI 덮기는 FullConfig에 드러난다 — --trace → project.use.trace · --reporter → config.reporter(옵션 없이) ·
// --output → project.outputDir · --workers → config.workers · --retries → project.retries · --headed → project.use.headless=false.
// 러너 argv는 FullConfig.argv(= 러너 process.argv 스냅숏)로 읽는다.
import type { FullConfig } from '@playwright/test';
import * as os from 'node:os';
import * as path from 'node:path';
import { countResidue, removeAll } from './lib/auth-dir';
import { liveLockLocation, lockDecision, lockPresent, profileDecision, type LockDecision } from './lib/login-lock';
import { emitInfo, emitStop, formatStop, type StopPrefix } from './lib/out';

const REPO_ROOT = path.resolve(__dirname, '..');

// ① env 가드 — 디버그 · 진단 · 프록시 · 브라우저 위치 · Playwright 덮기 env. Playwright 1.65.1은 NODE_OPTIONS에 아무것도 넣지 않는다(VD-T077-3 —
// Node 24에서 module.registerHooks로 변환기를 단다). 그래서 NODE_OPTIONS는 메모리 플래그만 허용하고 나머지는 이름만 내고 멈춘다.
const EXACT_NAMES = new Set(['PWDEBUG', 'NODE_DEBUG', 'SSLKEYLOGFILE', 'NODE_EXTRA_CA_CERTS', 'NODE_TLS_REJECT_UNAUTHORIZED']);
// Playwright가 러너에 스스로 넣는 값 · 이 설정이 넣는 값만 허용한다(그 밖 PLAYWRIGHT_* · PW_* · PWTEST_*는 리포터 · 캐시 · 원격 브라우저를 바꾼다)
const ALLOWED_PLAYWRIGHT_ENV: Record<string, string> = { PLAYWRIGHT_TEST: '1', PLAYWRIGHT_NO_COPY_PROMPT: '1' };
const NODE_OPTIONS_ALLOWED = /^--max-(old|semi)-space-size=\d+$/;

export function envGuard(env: Record<string, string | undefined>): string[] {
  const bad: string[] = [];
  for (const [name, value] of Object.entries(env)) {
    if (value === undefined) continue;
    const upper = name.toUpperCase();
    if (EXACT_NAMES.has(upper)) bad.push(name);
    else if (upper === 'DEBUG') {
      if (/pw|\*/i.test(value)) bad.push(name);
    } else if (upper.endsWith('_PROXY')) bad.push(name);
    else if (upper === 'NODE_OPTIONS') {
      const tokens = value.split(/\s+/).filter((t) => t.length > 0);
      if (!tokens.every((t) => NODE_OPTIONS_ALLOWED.test(t))) bad.push(name);
    } else if (upper.startsWith('PLAYWRIGHT_') || upper.startsWith('PW_') || upper.startsWith('PWTEST_')) {
      if (ALLOWED_PLAYWRIGHT_ENV[upper] !== value) bad.push(name);
    }
  }
  return bad.sort();
}

// ② 러너 argv 가드 — CLI 덮기(playwright.dev test-cli). 반환은 걸린 플래그 이름뿐이다.
// --update-snapshots · -u(리뷰 C-2) — 스냅숏 기준 이미지(mask 없는 PNG)를 쓰게 하는 덮기.
const ARGV_FLAGS = ['--ui', '--debug', '--headed', '--trace', '--reporter', '--add-reporter', '--output', '--workers', '-j', '--retries', '--repeat-each', '--tsconfig', '--update-snapshots', '-u'];

export function argvGuard(argv: readonly string[]): string[] {
  const bad: string[] = [];
  for (const a of argv) {
    for (const f of ARGV_FLAGS) {
      const hit = f === '--ui' ? a.startsWith('--ui') : f === '-j' ? /^-j(\d*|=.*)$/.test(a) : a === f || a.startsWith(f + '=');
      if (hit) {
        bad.push(f);
        break;
      }
    }
  }
  return bad;
}

function inside(parent: string, child: string): boolean {
  const rel = path.relative(parent, child);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

export interface ConfigGuardContext {
  repoRoot: string;
  tmpdir: string;
  jtRoot?: string;
  evidenceDir: string;
}

function allowedLocation(dir: string, ctx: ConfigGuardContext): boolean {
  if (inside(ctx.repoRoot, dir)) return false;
  if (inside(ctx.tmpdir, dir)) return true;
  return ctx.jtRoot !== undefined && !inside(ctx.repoRoot, ctx.jtRoot) && inside(ctx.jtRoot, dir);
}

// ③ FullConfig 재단언 — 이름 붙은 필드만 본다. 반환은 어긋난 필드 경로뿐이다(값 0).
// preserveOutput: 'never'. 단 needle 실행(needle 프로젝트가 실리고 live가 없는 설정)만 'always'다 — 실패 산출물(error-context 등)을
// 루트에 남겨 바늘 스캔 면에 들게 한다(빌드 리뷰 r1 — B-1). live와 needle은 설정 로드에서 이미 배타다(D3).
// 스냅숏(리뷰 C-2): updateSnapshots 'none' · snapshotDir은 outputDir와 같은 허용 자리(저장소 밖).
export function configGuard(config: FullConfig, ctx: ConfigGuardContext): string[] {
  const bad: string[] = [];
  const rep = config.reporter as unknown as Array<[string, Record<string, unknown> | undefined]>;
  if (!(rep.length === 1 && rep[0][0] === 'list' && rep[0][1]?.printSteps === false)) bad.push('reporter');
  if (config.workers !== 1) bad.push('workers');
  const names = config.projects.map((p) => p.name);
  const needleRun = names.includes('needle') && !names.includes('live');
  if (!(config.preserveOutput === 'never' || (config.preserveOutput === 'always' && needleRun))) bad.push('preserveOutput');
  if ((config as unknown as { updateSnapshots?: unknown }).updateSnapshots !== 'none') bad.push('updateSnapshots');
  for (const p of config.projects) {
    const key = `projects.${p.name}`;
    const use = p.use as Record<string, unknown>;
    if (p.retries !== 0) bad.push(`${key}.retries`);
    for (const f of ['trace', 'video', 'screenshot']) if (use[f] !== 'off') bad.push(`${key}.use.${f}`);
    if (use.headless === false) bad.push(`${key}.use.headless`);
    if (use.channel !== undefined) bad.push(`${key}.use.channel`);
    const lo = (use.launchOptions ?? {}) as Record<string, unknown>;
    if (lo.executablePath !== undefined) bad.push(`${key}.use.launchOptions.executablePath`);
    if (lo.channel !== undefined) bad.push(`${key}.use.launchOptions.channel`);
    if (!allowedLocation(p.outputDir, ctx)) bad.push(`${key}.outputDir`);
    if (!allowedLocation(p.snapshotDir, ctx)) bad.push(`${key}.snapshotDir`);
  }
  if (!allowedLocation(ctx.evidenceDir, ctx)) bad.push('evidenceDir');
  return bad;
}

// ⑤ e2e/.auth 잔여 — 이전 live 실행의 흔적이라 어느 모드에서 발견돼도 노출 의심이다.
export function residueDecision(count: number): { kind: 'none' } | { kind: 'stop'; prefix: 'state'; code: string; note: string } {
  if (count <= 0) return { kind: 'none' };
  return { kind: 'stop', prefix: 'state', code: `previous-run residue count=${count}`, note: 'server session invalidation unconfirmed' };
}

// 관찰(부작용 0 — 잔여는 파일 수만, 나머지는 이름 · 판정만)
export interface SetupObservation {
  residue: number;
  badEnv: readonly string[];
  badArgv: readonly string[];
  badConfig: readonly string[];
  profile: LockDecision;
  lock: LockDecision;
}

export type SetupAction =
  | { kind: 'info'; text: string }
  | { kind: 'stop'; prefix: StopPrefix; code: string; note?: string; removeResidue?: boolean };

// 순서 고정(리뷰 A-2): 잔여 → env → argv → config → 프로필 → 잠금 표식. 첫 멈춤에서 끝난다(그 앞의 INFO는 남긴다).
export function setupPlan(o: SetupObservation): SetupAction[] {
  const out: SetupAction[] = [];
  const residue = residueDecision(o.residue);
  if (residue.kind === 'stop') return [{ kind: 'stop', prefix: residue.prefix, code: residue.code, note: residue.note, removeResidue: true }];
  if (o.badEnv.length > 0) return [{ kind: 'stop', prefix: 'guard', code: `env-not-allowed ${o.badEnv.join(',')}` }];
  if (o.badArgv.length > 0) return [{ kind: 'stop', prefix: 'guard', code: `cli-override ${o.badArgv.join(',')}` }];
  if (o.badConfig.length > 0) return [{ kind: 'stop', prefix: 'guard', code: `config-override ${o.badConfig.join(',')}` }];
  for (const d of [o.profile, o.lock]) {
    if (d.kind === 'info') out.push({ kind: 'info', text: d.text });
    if (d.kind === 'stop') {
      out.push(d.code === 'login-lock present' ? { kind: 'stop', prefix: d.prefix, code: d.code, note: 'operator check' } : { kind: 'stop', prefix: d.prefix, code: d.code });
      return out;
    }
  }
  return out;
}

function evidenceDirFor(env: Record<string, string | undefined>): string {
  if (env.JT_E2E_EVIDENCE_DIR) return env.JT_E2E_EVIDENCE_DIR;
  return path.join(os.tmpdir(), 'jt-e2e', env.JT_E2E_RUN_ID ?? 'unknown-run', 'evidence');
}

export default async function globalSetup(config: FullConfig): Promise<void> {
  // ⑤ 잔여 계수가 맨 앞이다 — 아래 어느 가드보다 먼저(리뷰 A-2)
  const residue = countResidue();
  const live = config.projects.some((p) => p.name === 'live');
  const argv = config.argv && config.argv.length > 0 ? config.argv : process.argv;
  const loc = liveLockLocation();
  const plan = setupPlan({
    residue,
    badEnv: envGuard(process.env),
    badArgv: argvGuard(argv),
    badConfig: configGuard(config, { repoRoot: REPO_ROOT, tmpdir: os.tmpdir(), jtRoot: process.env.JT_E2E_ROOT, evidenceDir: evidenceDirFor(process.env) }),
    profile: profileDecision(loc.mismatch, live),
    lock: lockDecision(lockPresent(loc.file), live),
  });
  for (const a of plan) {
    if (a.kind === 'info') {
      emitInfo(a.text);
      continue;
    }
    emitStop(a.prefix, a.code, a.note);
    if (a.removeResidue) removeAll();
    throw new Error(formatStop(a.prefix, a.code));
  }
}
