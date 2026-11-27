// e2e/lib/authentik-flow.ts — 두 live spec(T077 auth.spec · T079 revocation.spec)이 함께 쓰는 Authentik 흐름(설계 D6 · D7 · 빌드 리뷰 r1).
// r0에서 두 spec에 복제돼 있던 VD-T081-a 상수 · 로그인 단계 · 로그아웃을 한 곳에 모았다 — T081 스펙 상수 커밋이 한 파일만 고치고, 흐름 동작을
// selftest-browser(로컬 127.0.0.1 흉내 서버)로 시험할 수 있게 했다(spec 파일끼리는 import할 수 없다).
// 고친 동작:
//   A-1  로그아웃 완료 = 로그인 화면 표식(identify 칸)이 보일 때. 무효화 진입점이 302로 보내는 /if/flow/<무효화 slug>/ 자체가 /if/flow/ 접두를 만족해
//        r0의 접두 대기는 실제 로그아웃(흐름 실행기의 API 호출) 전에 돌아왔다.
//   A-10 · B-5  잠금 표식 조건 = 「값이 칸에 들어간 뒤」(입력 뒤). secretFill이 값이 칸에 들어간 뒤 실패하면(자동 제출 등) 그것도 잠금으로 다룬다.
//        세션 플래그(정리 로그아웃 대상)는 TOTP 값을 넣기 전에 세운다 — 세션이 없을 때 무효화 흐름을 밟아도 해가 없다.
//   B-4  잠금 표식을 못 쓰면 실행 범위 표식으로 물러나 같은 실행의 남은 live 시험이 cred에서 멈춘다(login-lock lockGate).
//   B-6  죽은 상태는 메모리 객체로 새 컨텍스트를 열어 먼저 확인하고, 확인된 뒤에만 e2e/.auth/에 쓴다(살아 있는 쿠키가 디스크에 놓이지 않게).
// 출력 · 값: 단계 줄은 FlowSink(기본 = out.ts)로만 내고, 비밀 · 쿠키 · URL 쿼리는 싣지 않는다.
import type { Browser, BrowserContextOptions, Page } from '@playwright/test';
import { writeDeadState } from './auth-dir';
import { E2E_EMAIL, type Secrets } from './env-contract';
import { errorCode, guarded, navigate, safeError, safeErrorCode, waitForPath } from './http';
import { recordLock, type LockTarget } from './login-lock';
import { emitInfo, emitStep, type StopPrefix, type Verdict } from './out';
import { AUTH_ORIGIN } from './reach';
import { AFTER_FILL_CODE, secretFill } from './secret-input';
import { codeForNextStep } from './totp-window';

export const STEP_TIMEOUT = 15_000;

// VD-T081-a 상수(추론 — T081 배포 · 운영자 수동 단계 뒤 스펙 상수 커밋으로 확정한다. 오늘은 reach에서 멈추므로 라이브에서 쓰이지 않는다)
export const AUTH_SEL = {
  identifyInput: 'input[name="uidField"]',
  passwordInput: 'input[name="password"]',
  totpInput: 'input[name="code"]',
  submit: 'button[type="submit"]',
  sessionsRows: 'ak-user-settings-session table tbody tr',
  sessionsIp: 'ak-user-settings-session table tbody tr td:nth-child(2)',
  sessionsUa: 'ak-user-settings-session table tbody tr td:nth-child(3)',
} as const;
export const AUTH_PATHS = {
  userInterface: '/if/user/',
  sessions: '/if/user/#/settings;%7B%22page%22%3A%22page-sessions%22%7D',
  invalidation: '/flows/-/default/invalidation/',
} as const;
export const AUTH_SESSION_COOKIE = 'authentik_session';

export interface Classified {
  prefix: StopPrefix;
  code: string;
  note?: string;
}

// 단계 줄 출구 — 기본은 out.ts. selftest는 메모리로 받는다(실행 출력에 가짜 단계 줄이 섞이지 않게).
export interface FlowSink {
  emitStep(task: string, step: string, verdict: Verdict, reason?: string, note?: string): void;
  emitInfo(text: string, note?: string): void;
}

export const outSink: FlowSink = {
  emitStep: (task, step, verdict, reason, note) => {
    emitStep(task, step, verdict, reason, note);
  },
  emitInfo: (text, note) => {
    emitInfo(text, note);
  },
};

const NETWORK_CODES = new Set(['dns', 'refused', 'reset', 'network', 'tls']);

export function productOrEnv(stepName: string): (e: unknown) => Classified {
  return (e) => {
    const code = errorCode(e);
    return NETWORK_CODES.has(code) ? { prefix: 'env', code: `network (${code})` } : { prefix: 'product', code: `${stepName}-failed (${code})` };
  };
}

export interface Steps {
  fail(stepName: string, c: Classified): never;
  step<T>(stepName: string, fn: () => Promise<T>, classify: (e: unknown) => Classified): Promise<T>;
}

// 단계 줄 'T07x <step> PASS|FAIL <근거>'(기계 판독 부분 ASCII — D5) · 실패는 값 없는 새 오류로 던진다
export function createSteps(task: string, sink: FlowSink = outSink): Steps {
  const fail = (stepName: string, c: Classified): never => {
    sink.emitStep(task, stepName, 'FAIL', `[${c.prefix}] ${c.code}`, c.note);
    throw safeError(`${task} ${stepName} FAIL [${c.prefix}] ${c.code}`, c.code);
  };
  const step = async <T>(stepName: string, fn: () => Promise<T>, classify: (e: unknown) => Classified): Promise<T> => {
    let v: T;
    try {
      v = await fn();
    } catch (e) {
      fail(stepName, classify(e));
    }
    sink.emitStep(task, stepName, 'PASS');
    return v;
  };
  return { fail, step };
}

// 자격 단계가 안 넘어가면(자격 거부 표식 포함 — VD-T081-a) 잠금 표식을 남기고 멈춘다 — 운영자가 원인을 확인한 뒤에만 지운다(D10 ⑦).
// 표식을 못 쓰면 실행 범위 표식으로 물러난다(리뷰 B-4 — 같은 실행의 남은 live 시험이 cred에서 멈춘다).
export function lockGuard(stepName: string, lock: LockTarget, sink: FlowSink, runId: string): Classified {
  const r = recordLock(lock, { step: stepName, runId });
  if (r === 'lock') sink.emitInfo(`login-lock written step=${stepName}`, 'operator check before removal');
  else if (r === 'run-marker') sink.emitInfo('login-lock write-failed run-marker=written', 'remaining live tests stop at cred');
  else sink.emitInfo('login-lock write-failed run-marker=failed', 'operator check - later live tests in this run are not stopped');
  return { prefix: 'guard', code: `step-not-advanced ${stepName}` };
}

// 로그인 화면 표식(identify 칸)이 보일 때까지
export async function waitForLoginScreen(page: Page, timeout: number = STEP_TIMEOUT): Promise<void> {
  await guarded('marker identify', () => page.locator(AUTH_SEL.identifyInput).waitFor({ state: 'visible', timeout }));
}

export interface LoginOptions {
  task: string;
  startUrl: string; // T077 = auth. 루트 · T079 = <체인>/api/auth/login
  landing: { url: string; prefix: boolean }; // TOTP 뒤 도착(origin + pathname만 — 쿼리 0)
  secrets: Secrets;
  lock: LockTarget;
  runId: string;
  onSessionMayExist: () => void; // 정리 로그아웃 대상 표시(TOTP 값을 넣기 전에 부른다)
  sink?: FlowSink;
  timeout?: number;
  pickCode?: (s: Secrets) => Promise<string>; // 기본 = 다음 30 s 경계 + 0.5 s의 코드(totp-window)
}

// 값이 칸에 들어갔는지: secretFill이 끝났거나, 들어간 뒤 실패했으면 참(A-10 · B-5 — 잠금 표식 조건 = 입력 뒤)
async function enterSecret(fill: () => Promise<void>, entered: { v: boolean }): Promise<void> {
  try {
    await fill();
  } catch (e) {
    if (safeErrorCode(e) === AFTER_FILL_CODE) entered.v = true;
    throw e;
  }
  entered.v = true;
}

// identify → password → totp → 도착(설계 D6 identify–totp · D7 bff-login). 단계마다 줄 하나.
export async function authentikLogin(page: Page, o: LoginOptions): Promise<void> {
  const sink = o.sink ?? outSink;
  const timeout = o.timeout ?? STEP_TIMEOUT;
  const S = createSteps(o.task, sink);

  // identify — 고정 신원(비밀 아님)
  await S.step('identify', async () => {
    await navigate(page, o.startUrl, { timeout });
    await waitForLoginScreen(page, timeout);
    await guarded('fill identify', () => page.locator(AUTH_SEL.identifyInput).fill(E2E_EMAIL, { timeout }));
    await guarded('submit identify', () => page.locator(AUTH_SEL.submit).first().click({ timeout }));
    await guarded('marker password-step', () => page.locator(AUTH_SEL.passwordInput).waitFor({ state: 'visible', timeout }));
  }, productOrEnv('identify'));

  // password — 값이 칸에 들어간 뒤 단계가 안 넘어가면 [guard] + 잠금 표식
  const pw = { v: false };
  await S.step('password', async () => {
    await enterSecret(() => secretFill(page.locator(AUTH_SEL.passwordInput), o.secrets.password, 'password', { timeout }), pw);
    await guarded('submit password', () => page.locator(AUTH_SEL.submit).first().click({ timeout }));
    await guarded('marker totp-step', () => page.locator(AUTH_SEL.totpInput).waitFor({ state: 'visible', timeout }));
  }, (e) => (pw.v ? lockGuard('password', o.lock, sink, o.runId) : productOrEnv('password')(e)));

  // totp — 다음 30 s 경계 + 0.5 s 대기 → 그 단계의 코드 → 세션 플래그 → 값 → 제출 → 도착
  const code = { v: false };
  await S.step('totp', async () => {
    const value = await (o.pickCode ?? codeForNextStep)(o.secrets);
    o.onSessionMayExist();
    await enterSecret(() => secretFill(page.locator(AUTH_SEL.totpInput), value, 'totp', { timeout }), code);
    await guarded('submit totp', () => page.locator(AUTH_SEL.submit).first().click({ timeout }));
    await waitForPath(page, o.landing.url, { prefix: o.landing.prefix, timeout });
  }, (e) => {
    if (safeErrorCode(e) === 'totp-window-exhausted') return { prefix: 'env', code: 'totp-window-exhausted' };
    return code.v ? lockGuard('totp', o.lock, sink, o.runId) : productOrEnv('totp')(e);
  });
}

// Authentik 로그아웃(사용자 자신 — 관리 토큰 0): 무효화 흐름 → 로그인 화면 표식이 보이면 완료. 완료 시각(ms)을 돌려준다(A-1).
export async function authentikLogout(page: Page, o: { origin?: string; timeout?: number } = {}): Promise<number> {
  const origin = o.origin ?? AUTH_ORIGIN;
  const timeout = o.timeout ?? STEP_TIMEOUT;
  await navigate(page, origin + AUTH_PATHS.invalidation, { timeout });
  await waitForLoginScreen(page, timeout);
  return Date.now();
}

// 죽은 상태 확인(B-6): 메모리 상태로 새 컨텍스트 → /if/user/ → 로그인 화면으로 돌려보내지는지. 살아 있으면 던진다(파일 0).
export async function verifyDeadState(browser: Browser, state: unknown, o: { origin?: string; timeout?: number } = {}): Promise<void> {
  const origin = o.origin ?? AUTH_ORIGIN;
  const timeout = o.timeout ?? STEP_TIMEOUT;
  const ctx = await browser.newContext({
    storageState: state as BrowserContextOptions['storageState'],
    acceptDownloads: false,
    ignoreHTTPSErrors: false,
    locale: 'en-US',
    timezoneId: 'UTC',
  });
  try {
    const p2 = await ctx.newPage();
    await navigate(p2, origin + AUTH_PATHS.userInterface, { timeout });
    await waitForLoginScreen(p2, timeout);
  } finally {
    await ctx.close().catch(() => undefined);
  }
}

// 확인된 뒤에만 e2e/.auth/<runId>-t077.json에 쓴다(문면 「storageState e2e/.auth/」 — 〔77-14〕). 파일 쓰기 실패는 코드 'state-file'.
export async function confirmDeadAndStore(browser: Browser, state: unknown, o: { origin?: string; timeout?: number; runId: string; dir?: string }): Promise<string> {
  await verifyDeadState(browser, state, o);
  try {
    return writeDeadState(state, o.runId, o.dir);
  } catch {
    throw safeError('state file could not be written', 'state-file');
  }
}
