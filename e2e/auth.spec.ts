// e2e/auth.spec.ts — T077 로그인 시험(US4 AC1 tester 자동 몫 · FR-022 · 023 · 026 · 044). 설계 = specs/003-platform-foundation/design/t077-design.md D6.
// live 프로젝트(JT_E2E_LIVE=1)에서만 실린다. 단계마다 out.ts로 'T077 <step> PASS|FAIL <근거>' 한 줄(비밀 0 · 기계 판독 부분 = 첫 ' — ' 앞 ASCII).
// 오늘(T080 전) 기대 = reach에서 '[gate] authentik-absent until T080'(Traefik 404 서명 전체 일치) — 빨강 관찰은 컨트롤러가 런처 live-red로 한다(D9).
// 자격은 reach가 통과한 뒤에만 읽는다(readSecretsOnce) — config metadata.jtApprovedBlock이 null인 동안 cred는 늘 [guard](T077-a · §5-1 코드 관문).
// 살아 있는 세션은 디스크에 놓이지 않는다: 상태는 메모리로 받고, 로그아웃 뒤 메모리로 죽은 것을 확인한 상태만 e2e/.auth/에 쓴다(〔77-14〕 · 빌드 리뷰 r1 — B-6).
// 흐름(identify–totp · 로그아웃 · 죽은 상태 확인)과 VD-T081-a 상수는 lib/authentik-flow.ts(T079와 공용 — selftest-browser가 동작을 시험한다).
// 빌드 리뷰 r1: 로그아웃 완료 = 로그인 화면 표식(A-1) · cred 직전 잠금 표식 확인(B-4) · 잠금 조건 = 값이 칸에 들어간 뒤(A-10 · B-5) · test 기반 = lib/test-base(B-3).
// 소셜 로그인(AC1)은 스펙 밖 — 운영자 1회 수동 + 가린 스크린샷(D10 ⑨ · T085).
import { test as base, expect } from './lib/test-base';
import { removeFile } from './lib/auth-dir';
import { AUTH_PATHS, AUTH_SEL, AUTH_SESSION_COOKIE, authentikLogin, authentikLogout, confirmDeadAndStore, createSteps, productOrEnv, type Steps } from './lib/authentik-flow';
import { readSecretsOnce } from './lib/env-contract';
import { evidenceShot } from './lib/evidence';
import { currentOriginPath, errorCode, guarded, httpGet, navigate, safeError, safeErrorCode } from './lib/http';
import { liveLockTarget, lockGate } from './lib/login-lock';
import { emitInfo, emitStep } from './lib/out';
import { AUTH_ORIGIN, CONTROL_URL, REACH_URL, classifyReach, classifyReachError, observe, reachReason, type ReachVerdict } from './lib/reach';

const TASK = 'T077';
const S: Steps = createSteps(TASK);
const STEP_TIMEOUT = 15_000;

interface T077State {
  sessionUp: boolean; // Authentik 세션이 섰을 수 있다(TOTP 값을 넣기 전에 세운다 — B-5)
  loggedOut: boolean; // 로그아웃 완료(로그인 화면 표식 — A-1)
  deadUnconfirmed: boolean; // 죽은 상태 확인 실패 — 서버 세션이 남았을 수 있다(B-6)
  deadFile?: string;
  mem?: unknown;
}

function runId(): string {
  return process.env.JT_E2E_RUN_ID ?? 'unknown';
}

const test = base.extend<{ t077: T077State }>({
  // cleanup(fixture teardown · 늘): 세션이 섰는데 로그아웃이 확인되지 않았으면 다시 로그아웃(완료 = 로그인 화면 표식 · 실패해도 값 출력 0) · 파일 삭제 · 메모리 상태 버림
  t077: async ({ page }, use) => {
    const st: T077State = { sessionUp: false, loggedOut: false, deadUnconfirmed: false };
    await use(st);
    if (st.sessionUp && !st.loggedOut) {
      try {
        await authentikLogout(page, { timeout: STEP_TIMEOUT });
        emitInfo('cleanup logout=done');
      } catch {
        emitInfo('cleanup logout=failed', 'server session may remain - operator check');
      }
    }
    if (st.deadUnconfirmed) emitInfo('cleanup session=unconfirmed', 'server session may remain - operator check');
    if (st.deadFile) removeFile(st.deadFile);
    st.mem = undefined;
    emitInfo(`cleanup auth-file=${st.deadFile ? 'removed' : 'none'}`);
  },
});

test('T077 e2e local user login - one session, logout, dead state', async ({ page, request, browser, t077 }, testInfo) => {
  if (testInfo.project.use.baseURL !== AUTH_ORIGIN) S.fail('reach', { prefix: 'guard', code: 'baseurl-mismatch' });

  // reach — 공개 HTTPS GET(자격 헤더 0 · 리다이렉트 미추적 · 20 s)
  let verdict: ReachVerdict;
  try {
    const r = await httpGet(request, REACH_URL, { maxRedirects: 0, timeout: 20_000 });
    verdict = classifyReach(observe(r.status, r.headers, r.body));
  } catch (e) {
    verdict = classifyReachError(errorCode(e));
  }
  try {
    const c = await httpGet(request, CONTROL_URL, { maxRedirects: 0, timeout: 20_000 });
    emitInfo(`reach-control status=${c.status}`, 'edge response - not origin evidence');
  } catch (e) {
    emitInfo(`reach-control error=${errorCode(e)}`);
  }
  if (!verdict.ok) {
    const note = verdict.prefix === 'gate' ? 'Traefik 404 signature (T076 D10) matched' : undefined;
    emitStep(TASK, 'reach', 'FAIL', reachReason(verdict), note);
    throw safeError(`${TASK} reach FAIL ${reachReason(verdict)}`, 'reach');
  }
  emitStep(TASK, 'reach', 'PASS', reachReason(verdict));

  // cred — 잠금 표식 · 실행 범위 표식 확인(같은 실행의 앞 시험이 남겼으면 자격을 읽지 않는다 — B-4) → env 계약(D5): 이름 · 꼴 · 모드 판정. 값은 출력 0.
  const lock = liveLockTarget();
  const gate = lockGate(lock);
  if (gate) S.fail('cred', gate);
  const d = readSecretsOnce(testInfo);
  if (d.kind !== 'ok' || d.mode !== 'live') {
    S.fail('cred', d.kind === 'stop' ? { prefix: d.prefix, code: d.code } : { prefix: 'guard', code: 'unexpected-mode' });
  }
  emitStep(TASK, 'cred', 'PASS', 'names-and-shapes');

  // identify → password → totp → /if/user/ (lib/authentik-flow — 잠금 조건 = 값이 칸에 들어간 뒤 · 세션 플래그는 TOTP 값 전에)
  await authentikLogin(page, {
    task: TASK,
    startUrl: REACH_URL,
    landing: { url: AUTH_ORIGIN + AUTH_PATHS.userInterface, prefix: false },
    secrets: d.secrets,
    lock,
    runId: runId(),
    timeout: STEP_TIMEOUT,
    onSessionMayExist: () => {
      t077.sessionUp = true;
    },
  });

  // landed — origin + pathname만 비교(쿼리 출력 0)
  await S.step('landed', async () => {
    if (currentOriginPath(page) !== AUTH_ORIGIN + AUTH_PATHS.userInterface) throw safeError('landed path differs', 'landed-path');
  }, () => ({ prefix: 'product', code: 'landed-path' }));

  // sessions — 행 수만 단언한다(로케이터 단언 0 — 받은 글자가 실패 메시지에 실리지 않게). 증거는 mask 촬영만.
  const rows = page.locator(AUTH_SEL.sessionsRows);
  let n = 0;
  try {
    await navigate(page, AUTH_ORIGIN + AUTH_PATHS.sessions);
    await guarded('marker sessions', () => rows.first().waitFor({ state: 'visible', timeout: STEP_TIMEOUT }));
    n = await guarded('count sessions', () => rows.count());
  } catch (e) {
    S.fail('sessions', productOrEnv('sessions')(e));
  }
  if (n !== 1) emitStep(TASK, 'sessions', 'FAIL', n >= 2 ? `[state] residual-sessions n=${n}` : `[product] sessions-rows n=${n}`);
  expect(n, 'sessions rows').toBe(1);
  try {
    await evidenceShot(page, 't077-sessions', n, [
      { label: 'ip', locator: page.locator(AUTH_SEL.sessionsIp) },
      { label: 'ua', locator: page.locator(AUTH_SEL.sessionsUa) },
    ]);
  } catch (e) {
    S.fail('sessions', { prefix: 'product', code: safeErrorCode(e) ?? 'evidence-failed' });
  }
  emitStep(TASK, 'sessions', 'PASS', 'rows=1');

  // state-mem — storageState를 메모리 객체로 받는다(파일 0). 쿠키는 이름 판정 · 개수만, 도메인 집합은 INFO.
  const state = await S.step('state-mem', async () => {
    const s = await page.context().storageState();
    const domains = [...new Set(s.cookies.map((c) => c.domain))];
    emitInfo(`cookies count=${s.cookies.length}`);
    emitInfo(`cookie-domains count=${domains.length} auth-host-only=${domains.every((x) => x.replace(/^\./, '') === 'auth.joshuatech.dev') ? 'yes' : 'no'}`);
    if (!s.cookies.some((c) => c.name === AUTH_SESSION_COOKIE)) throw safeError('session cookie missing', 'session-cookie-missing');
    return s;
  }, (e) => ({ prefix: 'product', code: safeErrorCode(e) ?? 'state-mem-failed' }));
  t077.mem = state;

  // logout — Authentik 무효화 흐름 → 로그인 화면 표식이 보이면 완료(A-1 — 무효화 흐름 페이지 자체로는 완료가 아니다)
  await S.step('logout', async () => {
    await authentikLogout(page, { timeout: STEP_TIMEOUT });
  }, productOrEnv('logout'));
  t077.loggedOut = true;

  // state-dead — 메모리 상태로 새 컨텍스트 → /if/user/ → 로그인 화면으로 돌려보내지는지 먼저 확인하고, 확인된 죽은 상태만 e2e/.auth/<runId>-t077.json에 쓴다(B-6).
  // 확인 실패면 로그아웃이 확인되지 않은 것으로 되돌린다 — 정리 단계가 다시 로그아웃하고 「server session may remain」을 낸다.
  await S.step('state-dead', async () => {
    t077.deadFile = await confirmDeadAndStore(browser, state, { runId: runId(), timeout: STEP_TIMEOUT });
  }, (e) => {
    if (safeErrorCode(e) === 'state-file') return { prefix: 'env', code: 'state-file-write-failed' };
    t077.loggedOut = false;
    t077.deadUnconfirmed = true;
    return { prefix: 'product', code: `state-dead-not-rejected (${errorCode(e)})` };
  });
});
