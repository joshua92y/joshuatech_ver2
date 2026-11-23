// e2e/lib/kubectl-log.ts — T079 log-reason의 kubectl 경로(설계 D7 kubectl-log · log-reason · r1 — B-11). identity-admin 로그에서 폐기 기록 줄을 센다.
// kubectl.exe는 PATH에서 직접 찾는다(빈 · 상대 · '.' · 루트 상대 항목과 cwd 제외) → 절대 경로 · 가드 자리 아래면 [guard]로 멈춘다 → shell 0.
// 가드 자리 = 저장소 루트 · os.tmpdir() · 토큰 홈의 AppData\Local\Temp · 블록 소유 루트 JT_E2E_ROOT(빌드 리뷰 r1 — A-5: 런처 · 블록 실행에서
// 자식 TEMP는 루트 아래 tmp라 os.tmpdir()만으로는 사용자 실제 Temp에 심은 kubectl을 못 막는다).
// 자식 env = 허용 목록(PATH · SystemRoot · KUBECONFIG · USERPROFILE · TEMP). 먼저 auth whoami가 agent-view가 아니면 멈춘다(tests/platform 게이트 gate-3과 같은 신원).
// 인자 = --kubeconfig <KUBECONFIG> --request-timeout=20s -n jt-<env> logs deploy/identity-admin -c web --since-time=<창 시작>.
// 판정은 JSON 줄의 event · source · reason · ts(ISO 8601 UTC — pod-template.md 「로그」 행)만 본다(identity-admin-api.md:140).
// 출력은 개수 · 시각뿐이다(원시 줄 · sub_hash · IP 0). 파싱 예외는 원시 줄 없이 다시 던지고, kubectl 실패는 종료 코드만 싣는다(stderr · argv 0).
import { execFile } from 'node:child_process';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import type { Stop } from './bff';
import { safeError } from './http';
import { tokenHome } from './login-lock';

const win = path.win32;
const REPO_ROOT = path.resolve(__dirname, '..', '..');

export const KUBECTL_EXE = 'kubectl.exe';
export const AGENT_VIEW_USER = 'system:serviceaccount:kube-system:agent-view';
export const KUBECTL_ENV_NAMES = ['PATH', 'SystemRoot', 'KUBECONFIG', 'USERPROFILE', 'TEMP'] as const;
export const REVOCATION_EVENT = 'session_revocation.recorded';
const REQUEST_TIMEOUT = '--request-timeout=20s';
const NAMESPACES = new Set(['jt-dev', 'jt-prod']);
const RUN_TIMEOUT_MS = 30_000;
const MAX_BUFFER = 16 * 1024 * 1024;

// ---- kubectl.exe 찾기 ----
export interface FindContext {
  cwd: string;
  guardDirs: readonly string[]; // 이 아래에서 찾은 kubectl.exe는 부르지 않는다
  isFile: (p: string) => boolean;
}

// 드라이브 절대(C:\…) 또는 UNC(\\server\share)만 — '.' · 'bin' · '\bin'(현재 드라이브 루트 상대)은 상대 항목이다
function fullyQualified(p: string): boolean {
  return /^[A-Za-z]:[\\/]/.test(p) || /^[\\/]{2}[^\\/]/.test(p);
}

function norm(p: string): string {
  return win.normalize(p).replace(/[\\/]+$/, '').toLowerCase();
}

function inside(parent: string, child: string): boolean {
  const a = norm(parent);
  const b = norm(child);
  return b === a || b.startsWith(a + '\\');
}

export function findKubectl(pathValue: string | undefined, ctx: FindContext): { ok: true; exe: string } | Stop {
  const cwd = norm(ctx.cwd);
  for (const raw of (pathValue ?? '').split(';')) {
    const entry = raw.trim().replace(/^"(.*)"$/, '$1');
    if (entry.length === 0 || !fullyQualified(entry)) continue;
    if (norm(entry) === cwd) continue;
    const exe = win.join(entry, KUBECTL_EXE);
    if (!ctx.isFile(exe)) continue;
    // 저장소 · 임시 디렉터리 · 블록 루트에 심은 kubectl을 부르지 않는다 — 찾은 첫 실행 파일이 그 아래면 거기서 멈춘다
    if (ctx.guardDirs.some((d) => inside(d, exe))) return { ok: false, prefix: 'guard', code: 'kubectl-location' };
    return { ok: true, exe };
  }
  return { ok: false, prefix: 'env', code: 'kubectl-not-found' };
}

function defaultIsFile(p: string): boolean {
  try {
    return fs.statSync(p).isFile();
  } catch {
    return false;
  }
}

// 가드 자리: 저장소 루트 · os.tmpdir() · <토큰 홈>\AppData\Local\Temp(login-lock과 같은 토큰 홈 기준 — env에 기대지 않는다) · JT_E2E_ROOT(절대 경로일 때만)
export function liveFindContext(
  env: Record<string, string | undefined> = process.env,
  o: { home?: string; tmpdir?: string; cwd?: string; isFile?: (p: string) => boolean } = {},
): FindContext {
  const guardDirs = [REPO_ROOT, o.tmpdir ?? os.tmpdir(), win.join(o.home ?? tokenHome(), 'AppData', 'Local', 'Temp')];
  const root = env.JT_E2E_ROOT;
  if (typeof root === 'string' && fullyQualified(root)) guardDirs.push(root);
  return { cwd: o.cwd ?? process.cwd(), guardDirs, isFile: o.isFile ?? defaultIsFile };
}

// ---- 자식 env · KUBECONFIG ----
// Windows env 이름은 대소문자를 가리지 않는다(Path · SYSTEMROOT 등) — 정확한 이름을 먼저 보고 없으면 대소문자 무관으로 찾는다.
function lookup(source: Record<string, string | undefined>, name: string): string | undefined {
  if (Object.prototype.hasOwnProperty.call(source, name)) return source[name];
  const lower = name.toLowerCase();
  for (const k of Object.keys(source)) if (k.toLowerCase() === lower) return source[k];
  return undefined;
}

export function kubectlEnv(source: Record<string, string | undefined>): Record<string, string> {
  const env: Record<string, string> = {};
  for (const n of KUBECTL_ENV_NAMES) {
    const v = lookup(source, n);
    if (typeof v === 'string' && v.length > 0) env[n] = v;
  }
  return env;
}

export function checkKubeconfig(value: string | undefined, isFile: (p: string) => boolean): { ok: true; path: string } | Stop {
  if (typeof value !== 'string' || value.length === 0) return { ok: false, prefix: 'env', code: 'missing KUBECONFIG' };
  // 경로 목록 · 상대 경로는 받지 않는다(기본 kubeconfig로 흘러가지 않게 — tests/platform gate-2와 같은 규칙)
  if (value.includes(';') || !fullyQualified(value)) return { ok: false, prefix: 'env', code: 'shape KUBECONFIG' };
  if (!isFile(value)) return { ok: false, prefix: 'env', code: 'kubeconfig-not-found' };
  return { ok: true, path: value };
}

// ---- 인자 ----
export function whoamiArgs(kubeconfig: string): string[] {
  return ['--kubeconfig', kubeconfig, REQUEST_TIMEOUT, 'auth', 'whoami', '-o', 'json'];
}

// --since-time은 RFC 3339 — 초 단위로 내린다(창 판정은 줄의 ts로 따로 한다)
export function sinceTimeArg(ms: number): string {
  return new Date(Math.floor(ms / 1000) * 1000).toISOString().replace(/\.000Z$/, 'Z');
}

export function logsArgs(kubeconfig: string, ns: string, sinceMs: number): string[] {
  if (!NAMESPACES.has(ns)) throw safeError('kubectl-log: namespace rejected', 'namespace');
  return ['--kubeconfig', kubeconfig, REQUEST_TIMEOUT, '-n', ns, 'logs', 'deploy/identity-admin', '-c', 'web', `--since-time=${sinceTimeArg(sinceMs)}`];
}

// ---- 신원 ----
export function judgeWhoami(stdout: string): { ok: true; code: 'agent-view' } | Stop {
  let v: unknown;
  try {
    v = JSON.parse(stdout);
  } catch {
    return { ok: false, prefix: 'env', code: 'kubectl-whoami-unusable' };
  }
  const status = typeof v === 'object' && v !== null ? (v as Record<string, unknown>).status : undefined;
  const info = typeof status === 'object' && status !== null ? (status as Record<string, unknown>).userInfo : undefined;
  const user = typeof info === 'object' && info !== null ? (info as Record<string, unknown>).username : undefined;
  if (user === AGENT_VIEW_USER) return { ok: true, code: 'agent-view' };
  return { ok: false, prefix: 'guard', code: 'kubectl-identity-not-agent-view' };
}

// ---- 실행 ----
export type Runner = (exe: string, args: readonly string[], env: Record<string, string>) => Promise<{ code: number; stdout: string }>;

// shell 0 · 시간 상한 · 실패면 종료 코드만(오류 객체는 명령 줄 · stderr를 싣는다 — 넘기지 않는다)
export const defaultRunner: Runner = (exe, args, env) =>
  new Promise((resolve) => {
    try {
      execFile(exe, [...args], { env, shell: false, windowsHide: true, timeout: RUN_TIMEOUT_MS, maxBuffer: MAX_BUFFER, encoding: 'utf8' }, (err, stdout) => {
        if (!err) {
          resolve({ code: 0, stdout: String(stdout) });
          return;
        }
        const code = (err as { code?: unknown }).code;
        resolve({ code: typeof code === 'number' ? code : -1, stdout: '' });
      });
    } catch {
      resolve({ code: -1, stdout: '' });
    }
  });

export interface Prepared {
  ok: true;
  exe: string;
  kubeconfig: string;
  env: Record<string, string>;
}

async function run(runner: Runner, exe: string, args: readonly string[], env: Record<string, string>): Promise<{ code: number; stdout: string } | null> {
  try {
    return await runner(exe, args, env);
  } catch {
    return null;
  }
}

// kubectl 찾기 → KUBECONFIG 확인 → whoami = agent-view. 여기를 지난 뒤에만 logs를 부른다.
export async function prepareKubectl(env: Record<string, string | undefined>, ctx: FindContext = liveFindContext(), runner: Runner = defaultRunner): Promise<Prepared | Stop> {
  const found = findKubectl(lookup(env, 'PATH'), ctx);
  if (!found.ok) return found;
  const kc = checkKubeconfig(lookup(env, 'KUBECONFIG'), ctx.isFile);
  if (!kc.ok) return kc;
  const childEnv = kubectlEnv(env);
  const r = await run(runner, found.exe, whoamiArgs(kc.path), childEnv);
  if (r === null) return { ok: false, prefix: 'env', code: 'kubectl-run-failed' };
  if (r.code !== 0) return { ok: false, prefix: 'env', code: `kubectl-whoami-failed exit=${r.code}` };
  const who = judgeWhoami(r.stdout);
  if (!who.ok) return who;
  return { ok: true, exe: found.exe, kubeconfig: kc.path, env: childEnv };
}

// 로그 원문은 메모리에서만 쓴다(selectRevocationLines로 개수만 뽑는다).
export async function fetchLogs(p: Prepared, ns: string, sinceMs: number, runner: Runner = defaultRunner): Promise<{ ok: true; text: string } | Stop> {
  const r = await run(runner, p.exe, logsArgs(p.kubeconfig, ns, sinceMs), p.env);
  if (r === null) return { ok: false, prefix: 'env', code: 'kubectl-run-failed' };
  if (r.code !== 0) return { ok: false, prefix: 'env', code: `kubectl-logs-failed exit=${r.code}` };
  return { ok: true, text: r.stdout };
}

// ---- 로그 선택(창 · source · reason) ----
const UTC_TS = /^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.(\d{1,9}))?(?:Z|\+00:00)$/;

// ISO 8601 UTC(Z 또는 +00:00)만 받는다. ms 아래 자리는 버린다(structlog는 마이크로초까지 낸다).
export function parseUtcTs(v: unknown): number | null {
  if (typeof v !== 'string') return null;
  const m = UTC_TS.exec(v);
  if (!m) return null;
  const whole = Date.parse(`${m[1]}Z`);
  if (!Number.isFinite(whole)) return null;
  const ms = m[2] === undefined ? 0 : Number((m[2] + '00').slice(0, 3));
  return whole + ms;
}

export interface LogCriteria {
  source: string;
  reason: string;
  startMs: number; // 창 아래 경계(시계 여유 포함 — 빌드 리뷰 r1 — A-8)
  endMs: number;
  anchorMs?: number; // 오프셋 기준(t0 · t1). 없으면 startMs
}

export interface LogSelection {
  matched: number; // event · source · reason이 맞고 ts가 창 안인 줄
  outside: number; // 맞지만 ts가 창 밖인 줄
  badTs: number; // 맞지만 ts가 UTC ISO 8601이 아닌 줄
  firstOffsetMs: number | null; // 기준(anchor)부터 첫 일치 줄까지(ms — 아래 여유 안의 줄이면 음수)
  json: number;
  nonJson: number; // gunicorn 생애 줄 등 원문 줄
  malformed: number;
}

export function selectRevocationLines(text: string, c: LogCriteria): LogSelection {
  try {
    const s: LogSelection = { matched: 0, outside: 0, badTs: 0, firstOffsetMs: null, json: 0, nonJson: 0, malformed: 0 };
    for (const raw of text.split(/\r?\n/)) {
      const line = raw.trim();
      if (line.length === 0) continue;
      if (!line.startsWith('{')) {
        s.nonJson += 1;
        continue;
      }
      let rec: unknown;
      try {
        rec = JSON.parse(line);
      } catch {
        s.malformed += 1;
        continue;
      }
      if (typeof rec !== 'object' || rec === null || Array.isArray(rec)) {
        s.malformed += 1;
        continue;
      }
      s.json += 1;
      const r = rec as Record<string, unknown>;
      if (r.event !== REVOCATION_EVENT || r.source !== c.source || r.reason !== c.reason) continue;
      const ms = parseUtcTs(r.ts);
      if (ms === null) {
        s.badTs += 1;
        continue;
      }
      if (ms < c.startMs || ms > c.endMs) {
        s.outside += 1;
        continue;
      }
      s.matched += 1;
      const off = ms - (c.anchorMs ?? c.startMs);
      if (s.firstOffsetMs === null || off < s.firstOffsetMs) s.firstOffsetMs = off;
    }
    return s;
  } catch {
    throw safeError('kubectl-log: parse failed', 'parse');
  }
}
