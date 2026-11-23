// e2e/lib/env-contract.ts — env 계약 · 모드 판정(설계 D5 · §5-1 코드 관문 · r2 — V-6 · 컨트롤러 N-1).
// 자격 env(JT_E2E_SECRET_*)와 바늘 묶음(JT_E2E_NEEDLE_SET)은 이 파일만 읽는다(static-gate). 읽는 자리 = 시험 본문, 도달 단계가 통과한 뒤.
// 모드는 프로젝트 이름으로 가른다(env로 고를 수 없다). live는 config metadata.jtApprovedBlock(검토된 자격 블록 경로)과
// JT_E2E_BLOCK이 같을 때만 값을 읽는다 — 지금은 null이라 늘 [guard](T077-a). 판정 결과에 값을 싣지 않는다(이름 · 사유 코드만).
import type { TestInfo } from '@playwright/test';

// 바늘 꼴 상수(설계 D10 ⑧) — 값이 아니라 접두다. 런처(launch.mjs)가 같은 접두로 실행마다 난수 바늘을 만든다.
export const NEEDLE_PREFIX = 'JTNEEDLE-';
export const CONTROL_PREFIX = NEEDLE_PREFIX + 'ctl-';

// 고정 신원(infra.md — e2e 로컬 사용자)
export const E2E_EMAIL = 'e2e@joshuatech.dev';

export const NAMES = {
  password: 'JT_E2E_SECRET_PASSWORD',
  codes: 'JT_E2E_SECRET_TOTP_CODES',
  step0: 'JT_E2E_TOTP_STEP0',
  block: 'JT_E2E_BLOCK',
  needleSet: 'JT_E2E_NEEDLE_SET',
} as const;

export const SECRET_ENV_NAMES: readonly string[] = [NAMES.password, NAMES.codes, NAMES.step0];

export interface Secrets {
  password: string;
  codes: readonly string[];
  step0: number;
}

export interface NeedleExtras {
  cookie: string;
  authorization: string;
  query: string;
  ip: string;
  ua: string;
}

// 노출 경로별 대조 바늘(빌드 리뷰 r1 — B-1) — needle-control이 감싸개 없이 같은 경로를 밟을 때만 쓴다(대조 꼴만 · 자격 이름은 읽지 않는다)
export interface ControlPaths {
  fill: string;
  requestHeaders: string;
  setCookie: string;
  url: string;
  goto: string;
  file: string;
}

export type Decision =
  | { kind: 'ok'; mode: 'live'; secrets: Secrets }
  | { kind: 'ok'; mode: 'needle'; secrets: Secrets; extras: NeedleExtras }
  | { kind: 'control'; control: string; paths: ControlPaths }
  | { kind: 'stop'; prefix: 'guard' | 'env'; code: string };

const CODES_SHAPE = /^\d{6}(,\d{6}){1,39}$/;
const STEP0_SHAPE = /^\d+$/;
const CONTROL_FIELDS = ['control', 'controlFill', 'controlRequest', 'controlSetCookie', 'controlUrl', 'controlGoto', 'controlFile'] as const;
const NEEDLE_SET_FIELDS = ['password', 'codes', 'step0', 'cookie', 'authorization', 'query', 'ip', 'ua', ...CONTROL_FIELDS] as const;

const guard = (code: string): Decision => ({ kind: 'stop', prefix: 'guard', code });
const envFail = (code: string): Decision => ({ kind: 'stop', prefix: 'env', code });

type Reader = (name: string) => string | undefined;

function present(v: string | undefined): v is string {
  return typeof v === 'string' && v.length > 0;
}

function parseNeedleSet(raw: string | undefined): Record<(typeof NEEDLE_SET_FIELDS)[number], string> | undefined {
  if (!present(raw)) return undefined;
  let v: unknown;
  try {
    v = JSON.parse(raw);
  } catch {
    return undefined;
  }
  if (typeof v !== 'object' || v === null) return undefined;
  const o = v as Record<string, unknown>;
  for (const f of NEEDLE_SET_FIELDS) if (typeof o[f] !== 'string') return undefined;
  return o as Record<(typeof NEEDLE_SET_FIELDS)[number], string>;
}

function readSecrets(read: Reader): { missing: string[]; values: { password?: string; codes?: string; step0?: string } } {
  const password = read(NAMES.password);
  const codes = read(NAMES.codes);
  const step0 = read(NAMES.step0);
  const missing: string[] = [];
  if (!present(password)) missing.push(NAMES.password);
  if (!present(codes)) missing.push(NAMES.codes);
  if (!present(step0)) missing.push(NAMES.step0);
  return { missing, values: { password, codes, step0 } };
}

function shaped(values: { password?: string; codes?: string; step0?: string }): Secrets | Decision {
  if (!CODES_SHAPE.test(values.codes as string)) return envFail(`shape ${NAMES.codes}`);
  if (!STEP0_SHAPE.test(values.step0 as string)) return envFail(`shape ${NAMES.step0}`);
  return { password: values.password as string, codes: (values.codes as string).split(','), step0: Number(values.step0) };
}

function isDecision(x: Secrets | Decision): x is Decision {
  return (x as Decision).kind !== undefined;
}

export function decide(project: string, read: Reader, approvedBlock: unknown): Decision {
  if (project === 'live') {
    // 코드 관문 — 승인 커밋이 metadata.jtApprovedBlock을 넣기 전에는 값을 읽지 않는다(§5-1)
    if (typeof approvedBlock !== 'string' || approvedBlock.length === 0 || read(NAMES.block) !== approvedBlock) {
      return guard('outside-reviewed-block (T077-a)');
    }
    if (read(NAMES.needleSet) !== undefined) return guard('needle-shaped value in live');
    const { missing, values } = readSecrets(read);
    if (missing.length > 0) return envFail(`missing ${missing.join(',')}`);
    if ((values.password as string).startsWith(NEEDLE_PREFIX)) return guard('needle-shaped value in live');
    const s = shaped(values);
    if (isDecision(s)) return s;
    return { kind: 'ok', mode: 'live', secrets: s };
  }
  if (project === 'needle') {
    const set = parseNeedleSet(read(NAMES.needleSet));
    if (!set) return guard('non-needle value in needle');
    const { missing, values } = readSecrets(read);
    if (missing.length > 0) return envFail(`missing ${missing.join(',')}`);
    const same = values.password === set.password && values.codes === set.codes && values.step0 === set.step0;
    if (!same || !set.password.startsWith(NEEDLE_PREFIX)) return guard('non-needle value in needle');
    const s = shaped(values);
    if (isDecision(s)) return s;
    return { kind: 'ok', mode: 'needle', secrets: s, extras: { cookie: set.cookie, authorization: set.authorization, query: set.query, ip: set.ip, ua: set.ua } };
  }
  if (project === 'needle-control') {
    const set = parseNeedleSet(read(NAMES.needleSet));
    // 대조 값만 돌려준다 — 하나라도 대조 꼴이 아니면 멈춘다(실제 바늘 · 자격이 대조 자리로 흘러들지 않게)
    if (!set || !CONTROL_FIELDS.every((f) => set[f].startsWith(CONTROL_PREFIX) && set[f].length > CONTROL_PREFIX.length)) return guard('non-control value in needle-control');
    return {
      kind: 'control',
      control: set.control,
      paths: { fill: set.controlFill, requestHeaders: set.controlRequest, setCookie: set.controlSetCookie, url: set.controlUrl, goto: set.controlGoto, file: set.controlFile },
    };
  }
  return guard('project-not-allowed');
}

// 한 번 읽고 지운다 — 판정 뒤 계약 이름을 env에서 지워 이 프로세스가 띄우는 자식(kubectl 등)이 물려받지 않게 한다(러너 env에는 남는다 — §5 위험 3).
export function scrubAndDecide(project: string, env: Record<string, string | undefined>, approvedBlock: unknown): Decision {
  try {
    return decide(project, (name) => env[name], approvedBlock);
  } finally {
    for (const n of [...SECRET_ENV_NAMES, NAMES.needleSet]) delete env[n];
  }
}

let cached: { project: string; decision: Decision } | undefined;

export function readSecretsOnce(testInfo: TestInfo): Decision {
  const project = testInfo.project.name;
  if (cached && cached.project === project) return cached.decision;
  const approved = (testInfo.config.metadata as Record<string, unknown> | undefined)?.jtApprovedBlock ?? null;
  const decision = scrubAndDecide(project, process.env, approved);
  cached = { project, decision };
  return decision;
}
