// e2e/revocation.spec.ts — T079 세션 폐기 시험(US4 AC3 · AC4 · FR-024 · 027 · 036 · SC-003 — 시간 측정 합격선은 T085). 설계 = specs/003-platform-foundation/design/t077-design.md D7.
// 측정 경로 = (A) BFF 프록시(T077-c 확정 · 〔77-1〕 · 〔77-7〕). live 프로젝트(JT_E2E_LIVE=1)에서만 실린다.
// 단계마다 out.ts로 'T079 <step> PASS|FAIL <근거>' 한 줄(비밀 0 · 기계 판독 부분 = 첫 ' — ' 앞 ASCII). 2단계 표기 = 'INFO t079 chain=<dev|prod> stage=<1|2>'.
// 오늘(T080 전) 기대 = 두 시험 모두 reach-auth에서 '[gate] authentik-absent until T080'(Traefik 404 서명 전체 일치) — 빨강 관찰은 컨트롤러가 런처 live-red로 한다(D9).
// 호출은 모두 lib/http.ts 감싸개(pace ≥ 200 ms — plan A32 · VD-3)를 지난다. probe는 호출마다 새 요청 컨텍스트 + 사본 쿠키를 명시 Cookie 헤더로 싣는다.
// 쿠키 사본은 메모리에만 둔다 — storageState 파일 0(〔77-14〕). 자격은 reach-auth · chain · reach-bff가 통과한 뒤에만 읽는다(readSecretsOnce).
// Authentik 로그인 · 로그아웃 흐름과 VD-T081-a 상수는 lib/authentik-flow.ts(T077과 공용). 빌드 리뷰 r1: 로그아웃 완료 = 로그인 화면 표식(A-1 — AC4 doneAt ·
// cleanup done도 그 뒤) · cred 직전 잠금 표식 확인(B-4) · log-reason 창 아래 경계 시계 여유(A-8) · 진단 재질문 첫 간격 ≥ 500 ms(A-9) · test 기반 = lib/test-base(B-3).
// 문면의 「Authentik 관리 API로 세션 삭제」는 스펙 밖 — 운영자 수동 + 스크린샷(R30) · UD-4 증거 기록만(〔77-3〕).
import { test as base } from './lib/test-base';
import type { APIRequestContext, Page, TestInfo } from '@playwright/test';
import { authentikLogin, authentikLogout, createSteps, productOrEnv, type Classified, type Steps } from './lib/authentik-flow';
import {
  AC3_PROBE_DELAY_MS,
  AC3_SPAN_MS,
  AC4_PATH,
  AC4_PROBE_DELAY_MS,
  AC4_SPAN_MS,
  BFF_PATHS,
  LOG_POLL_MS,
  LOGOUT_BODY,
  ac4Gate,
  classifyBffHealth,
  classifyBffHealthError,
  diagnoseUntil,
  gapWaitMs,
  judgeLogout,
  judgeRevokedProbe,
  judgeSession,
  judgeTenantsMe,
  logoutHeaders,
  observeHttp,
  pickSessionCopies,
  pollUntil,
  probeHeaders,
  resolveChain,
  revocationWindow,
  sleep,
  type Chain,
  type ProbeVerdict,
  type SessionCopies,
  type Stop,
  type Verdict,
} from './lib/bff';
import { readSecretsOnce, type Secrets } from './lib/env-contract';
import { currentOriginPath, errorCode, freshGet, freshPost, httpGet, safeError, safeErrorCode, type HttpResult } from './lib/http';
import { fetchLogs, prepareKubectl, selectRevocationLines, type LogSelection } from './lib/kubectl-log';
import { liveLockTarget, lockGate } from './lib/login-lock';
import { emitInfo, emitStep } from './lib/out';
import { AUTH_ORIGIN, CONTROL_URL, REACH_URL, classifyReach, classifyReachError, observe, reachReason, type ReachVerdict } from './lib/reach';

const TASK = 'T079';
const S: Steps = createSteps(TASK);
const STEP_TIMEOUT = 15_000;

// 앞 Authentik 로그아웃 완료 시각(같은 워커 안 — 시험 1 cleanup). 시험 2의 웹훅 간격 기준이고, 모르면(워커 재시작 등) 간격 전체를 기다린다.
let lastAuthentikLogoutMs: number | undefined;

interface T079State {
  base?: string;
  copies?: SessionCopies;
  bffUp: boolean; // BFF 세션이 섰다(callback 완료)
  bffEnded: boolean; // BFF logout 204 또는 폐기 확인(probe 401)
  authUp: boolean; // Authentik 로그인 세션이 섰을 수 있다(TOTP 값을 넣기 전에 세운다 — B-5)
  authEnded: boolean; // Authentik 로그아웃 완료(로그인 화면 표식 — A-1)
}

function runId(): string {
  return process.env.JT_E2E_RUN_ID ?? 'unknown';
}

function fail(stepName: string, c: Classified | Stop): never {
  return S.fail(stepName, { prefix: c.prefix, code: c.code, note: c.note });
}

// ---- 공통 단계 ----

// 1. reach-auth — D6 reach와 같다(공개 HTTPS GET · 자격 헤더 0 · 리다이렉트 미추적 · 20 s). [gate]는 Traefik 404 서명 전체 일치일 때만.
async function reachAuth(ctx: APIRequestContext, baseURL: unknown): Promise<void> {
  if (baseURL !== AUTH_ORIGIN) fail('reach-auth', { prefix: 'guard', code: 'baseurl-mismatch' });
  let verdict: ReachVerdict;
  try {
    const r = await httpGet(ctx, REACH_URL, { maxRedirects: 0, timeout: 20_000 });
    verdict = classifyReach(observe(r.status, r.headers, r.body));
  } catch (e) {
    verdict = classifyReachError(errorCode(e));
  }
  try {
    const c = await httpGet(ctx, CONTROL_URL, { maxRedirects: 0, timeout: 20_000 });
    emitInfo(`reach-control status=${c.status}`, 'edge response - not origin evidence');
  } catch (e) {
    emitInfo(`reach-control error=${errorCode(e)}`);
  }
  if (!verdict.ok) {
    const note = verdict.prefix === 'gate' ? 'Traefik 404 signature (T076 D10) matched' : undefined;
    emitStep(TASK, 'reach-auth', 'FAIL', reachReason(verdict), note);
    throw safeError(`${TASK} reach-auth FAIL ${reachReason(verdict)}`, 'reach');
  }
  emitStep(TASK, 'reach-auth', 'PASS', reachReason(verdict));
}

// 2. chain — JT_E2E_CHAIN → base · ns(값이 없거나 표 밖이면 이름만 실은 [env])
function chainStep(): Chain {
  const c = resolveChain(process.env);
  if (!c.ok) fail('chain', c);
  emitStep(TASK, 'chain', 'PASS', c.chain);
  emitInfo(`t079 chain=${c.chain} stage=${c.stage}`);
  return c;
}

// 3. reach-bff — GET <base>/api/health → 200 JSON upstream identity-admin이면 PASS. 어느 갈래도 [gate]가 아니다(r2 — A-2 · V-9).
async function reachBff(ctx: APIRequestContext, chain: Chain): Promise<void> {
  let v: Verdict;
  try {
    const r = await httpGet(ctx, chain.base + BFF_PATHS.health, { maxRedirects: 0, timeout: 20_000 });
    v = classifyBffHealth(chain.chain, observeHttp(r));
  } catch (e) {
    v = classifyBffHealthError(chain.chain, errorCode(e));
  }
  if (!v.ok) fail('reach-bff', v);
  emitStep(TASK, 'reach-bff', 'PASS', v.code);
}

// 4. cred — 잠금 표식 · 실행 범위 표식 확인(같은 실행의 앞 시험이 남겼으면 자격을 읽지 않는다 — B-4) → D5(모드 판정 포함). 값은 출력 0.
function cred(testInfo: TestInfo): Secrets {
  const gate = lockGate(liveLockTarget());
  if (gate) fail('cred', gate);
  const d = readSecretsOnce(testInfo);
  if (d.kind !== 'ok' || d.mode !== 'live') {
    fail('cred', d.kind === 'stop' ? { prefix: d.prefix, code: d.code } : { prefix: 'guard', code: 'unexpected-mode' });
  }
  emitStep(TASK, 'cred', 'PASS', 'names-and-shapes');
  return d.secrets;
}

// 5. bff-login — 브라우저 <base>/api/auth/login → Authentik 흐름(lib/authentik-flow — identify–totp) → callback. callback의 code · state는 출력 0(origin + pathname만 본다).
async function bffLogin(page: Page, chain: Chain, secrets: Secrets, st: T079State): Promise<void> {
  await authentikLogin(page, {
    task: TASK,
    startUrl: chain.base + BFF_PATHS.login,
    // TOTP 뒤 BFF origin으로 돌아온다(callback 302 → return_to)
    landing: { url: chain.base + '/', prefix: true },
    secrets,
    lock: liveLockTarget(),
    runId: runId(),
    timeout: STEP_TIMEOUT,
    onSessionMayExist: () => {
      st.authUp = true;
    },
  });
  // callback이 302가 아니면(400 invalid_state · 503 upstream_unavailable 등) 문서가 callback 경로에 남는다
  await S.step('bff-login', async () => {
    if (currentOriginPath(page) === chain.base + BFF_PATHS.callback) throw safeError('bff callback not completed', 'bff-callback-not-completed');
  }, (e) => ({ prefix: 'product', code: safeErrorCode(e) ?? 'bff-login-failed' }));
  st.bffUp = true;
}

// 6. copy — context 쿠키에서 jt_session · jt_csrf 사본을 메모리에만(파일 0). 개수만 출력한다.
async function copyStep(page: Page, chain: Chain, st: T079State): Promise<SessionCopies> {
  let picked: ReturnType<typeof pickSessionCopies>;
  try {
    picked = pickSessionCopies(await page.context().cookies(), chain.base);
  } catch (e) {
    fail('copy', productOrEnv('copy')(e));
  }
  if (!picked.ok) fail('copy', picked);
  st.copies = picked.copies;
  emitStep(TASK, 'copy', 'PASS', 'cookies=2', 'memory only - no storageState file');
  return picked.copies;
}

async function probeGet(url: string, copies: SessionCopies): Promise<HttpResult> {
  return freshGet(url, { headers: probeHeaders(copies), maxRedirects: 0, timeout: 20_000 });
}

// 7. baseline — probe와 같은 꼴(새 컨텍스트 + 명시 Cookie)로 GET /api/session 200 → GET /api/proxy/identity-admin/tenants/me 200 + role member(T083 · FR-036).
// 같은 꼴로 먼저 200을 보아야 뒤의 401이 폐기 때문임을 안다(쿠키 전달 실패의 401을 거짓 PASS로 보지 않게).
async function baseline(chain: Chain, copies: SessionCopies): Promise<void> {
  const check = async (path: string, judge: (o: ReturnType<typeof observeHttp>) => Verdict): Promise<Verdict> => {
    try {
      return judge(observeHttp(await probeGet(chain.base + path, copies)));
    } catch (e) {
      const c = productOrEnv('baseline')(e);
      return { ok: false, prefix: c.prefix, code: c.code };
    }
  };
  const s = await check(BFF_PATHS.session, judgeSession);
  if (!s.ok) fail('baseline', s);
  const t = await check(BFF_PATHS.tenantsMe, judgeTenantsMe);
  if (!t.ok) fail('baseline', t);
  emitStep(TASK, 'baseline', 'PASS', `${s.code} ${t.code}`);
}

// probe — 지정 시각까지 기다린 뒤 한 번 묻고 판정한다. 401이 아니면 FAIL + 진단 INFO(첫 재질문도 ≥ 500 ms 뒤 — A-9 · 10 s까지 · 호출마다 새 컨텍스트 · 첫 폐기 판정 시각).
async function probeOnce(chain: Chain, copies: SessionCopies): Promise<ProbeVerdict> {
  try {
    return judgeRevokedProbe(observeHttp(await probeGet(chain.base + BFF_PATHS.tenantsMe, copies)));
  } catch (e) {
    const c = productOrEnv('probe')(e);
    return { ok: false, prefix: c.prefix, code: c.code };
  }
}

async function probeStep(chain: Chain, copies: SessionCopies, sinceMs: number, delayMs: number): Promise<void> {
  await sleep(sinceMs + delayMs - Date.now());
  const v = await probeOnce(chain, copies);
  if (v.ok) {
    emitInfo(`t079 probe layer=${v.layer}`, v.layer === 'bff' ? 'BFF own 401 (request_id present)' : 'pod 401 relayed by BFF (no request_id)');
    emitStep(TASK, 'probe', 'PASS', `401 session-revoked delay-ms=${delayMs}`);
    return;
  }
  const d = await diagnoseUntil(() => probeOnce(chain, copies), (x) => x.ok, { sinceMs });
  emitInfo(`t079 diag first-revoked-ms=${d.doneAtMs === null ? 'none' : d.doneAtMs - sinceMs} tries=${d.tries}`, 'SC-003 data - pass mark is T085');
  fail('probe', v);
}

// log-reason — kubectl-log로 --since-time=<창 아래 경계> 읽기 → event session_revocation.recorded · source · reason · ts ∈ 창인 줄 ≥ 1.
// 창 = [기준 − 시계 여유, 기준 + 폭 + 시계 여유](A-8). 줄이 아직 없으면 창 끝까지 2 s 간격으로 다시 읽는다. 출력은 개수 · 시각(기준부터 ms)뿐이다.
async function logReason(chain: Chain, source: string, reason: string, win: { anchorMs: number; startMs: number; endMs: number }): Promise<void> {
  let prep: Awaited<ReturnType<typeof prepareKubectl>>;
  try {
    prep = await prepareKubectl(process.env);
  } catch (e) {
    fail('log-reason', { prefix: 'env', code: `kubectl (${errorCode(e)})` });
  }
  if (!prep.ok) fail('log-reason', prep);
  const ready = prep;
  type Read = { ok: true; sel: LogSelection } | Stop;
  let r: { value: Read; tries: number };
  try {
    r = await pollUntil<Read>(async () => {
      const logs = await fetchLogs(ready, chain.ns, win.startMs);
      if (!logs.ok) return logs;
      return { ok: true, sel: selectRevocationLines(logs.text, { source, reason, ...win }) };
    }, (x) => !x.ok || x.sel.matched >= 1, { deadlineMs: win.endMs, intervalMs: LOG_POLL_MS });
  } catch (e) {
    fail('log-reason', { prefix: 'env', code: `kubectl (${errorCode(e)})` });
  }
  const x = r.value;
  if (!x.ok) fail('log-reason', x);
  const s = x.sel;
  emitInfo(`t079 log-reason matched=${s.matched} outside=${s.outside} bad-ts=${s.badTs} reads=${r.tries}`);
  if (s.matched < 1) fail('log-reason', { prefix: 'product', code: `reason-not-logged source=${source} reason=${reason}` });
  emitStep(TASK, 'log-reason', 'PASS', `source=${source} reason=${reason} matched=${s.matched} first-offset-ms=${s.firstOffsetMs}`);
}

// Authentik 로그아웃 — lib/authentik-flow(완료 = 로그인 화면 표식 — A-1). 완료 시각을 돌려준다(관리 토큰 0 — 사용자 자신의 로그아웃).
async function logoutAuthentik(page: Page): Promise<number> {
  try {
    return await authentikLogout(page, { timeout: STEP_TIMEOUT });
  } finally {
    lastAuthentikLogoutMs = Date.now();
  }
}

const test = base.extend<{ t079: T079State }>({
  // cleanup(fixture teardown · 늘): 서 있는 BFF 세션이 끝나지 않았으면 logout all_devices(probe 꼴) · Authentik 로그아웃(완료 = 로그인 화면 표식) · 사본 지움. 값 출력 0.
  t079: async ({ page }, use) => {
    const st: T079State = { bffUp: false, bffEnded: false, authUp: false, authEnded: false };
    await use(st);
    let bff = 'none';
    if (st.bffUp && !st.bffEnded && st.copies && st.base) {
      try {
        const r = await freshPost(st.base + BFF_PATHS.logout, LOGOUT_BODY, { headers: logoutHeaders(st.copies), maxRedirects: 0, timeout: STEP_TIMEOUT });
        bff = r.status === 204 ? 'done' : `status-${r.status}`;
      } catch (e) {
        bff = `error-${errorCode(e)}`;
      }
    }
    let auth = 'none';
    if (st.authUp && !st.authEnded) {
      try {
        await logoutAuthentik(page);
        auth = 'done';
      } catch (e) {
        auth = `error-${errorCode(e)}`;
      }
    }
    st.copies = undefined;
    const leftover = !['none', 'done'].includes(bff) || !['none', 'done'].includes(auth);
    emitInfo(`t079 cleanup bff-logout=${bff} authentik-logout=${auth} copies=cleared`, leftover ? 'server session may remain - operator check' : undefined);
  },
});

test('T079 AC3 all-device logout via the BFF - /tenants/me 401 session-revoked after 1 s, reason logged', async ({ page, request, t079 }, testInfo) => {
  await reachAuth(request, testInfo.project.use.baseURL);
  const chain = chainStep();
  await reachBff(request, chain);
  const secrets = cred(testInfo);
  t079.base = chain.base;
  await bffLogin(page, chain, secrets, t079);
  const copies = await copyStep(page, chain, t079);
  await baseline(chain, copies);

  // logout — POST <base>/api/auth/logout { all_devices: true } + x-csrf-token → 204. 창 기준 t0 = 요청 직전 UTC(r1 — A-3 ①).
  const t0 = Date.now();
  let res: HttpResult;
  try {
    res = await freshPost(chain.base + BFF_PATHS.logout, LOGOUT_BODY, { headers: logoutHeaders(copies), maxRedirects: 0, timeout: 20_000 });
  } catch (e) {
    fail('logout', productOrEnv('logout')(e));
  }
  const loggedOutAt = Date.now();
  const lv = judgeLogout(observeHttp(res));
  if (!lv.ok) fail('logout', lv);
  t079.bffEnded = true;
  emitStep(TASK, 'logout', 'PASS', 'status=204 all_devices=true');

  // wait — 응답 + 1000 ms → probe 1회(층위 둘 다 합격 — 같은 isolate = pod 401 중계 · 다른 isolate = BFF 폐기 확인 401 · VD-T092-a)
  await probeStep(chain, copies, loggedOutAt, AC3_PROBE_DELAY_MS);
  await logReason(chain, 'revoke', 'logout_all', revocationWindow(t0, AC3_SPAN_MS));
  // cleanup(fixture) — Authentik 세션 로그아웃 · 사본 지움
});

test('T079 AC4 Authentik logout - webhook revocation, /tenants/me 401 after 2 s, reason logged', async ({ page, request, t079 }, testInfo) => {
  await reachAuth(request, testInfo.project.use.baseURL);
  const chain = chainStep();
  // UD-4 결정 상수 — 'undecided'(기본)면 여기서 [decision](사용자 결정 대기 — 빨강 증거 아님)
  const gate = ac4Gate(AC4_PATH);
  if (!gate.ok) fail('ac4-path', gate);
  emitStep(TASK, 'ac4-path', 'PASS', gate.code);
  await reachBff(request, chain);
  const secrets = cred(testInfo);
  t079.base = chain.base;
  await bffLogin(page, chain, secrets, t079);
  const copies = await copyStep(page, chain, t079);
  await baseline(chain, copies);

  // 간격 — 앞 Authentik 로그아웃(시험 1 cleanup — 이것도 authentik_webhook 기록을 만든다)과 이 로그아웃 사이를 웹훅 지연 상한보다 길게(r1 — A-3 ①)
  const gapMs = gapWaitMs(Date.now(), lastAuthentikLogoutMs);
  emitInfo(`t079 webhook-gap wait-ms=${gapMs}`);
  await sleep(gapMs);

  // 창 기준 t1 = Authentik 로그아웃 직전 UTC → 브라우저에서 e2e 사용자가 직접 로그아웃(관리 토큰 0) → 로그인 화면 표식이 보인 시각 = 완료(A-1)
  const t1 = Date.now();
  let doneAt = 0;
  try {
    doneAt = await logoutAuthentik(page);
  } catch (e) {
    fail('authentik-logout', productOrEnv('authentik-logout')(e));
  }
  t079.authEnded = true;
  emitStep(TASK, 'authentik-logout', 'PASS', 'login screen reached');

  // 완료 + 2000 ms → probe. AC4 PASS = probe 401 그리고 log-reason(webhook · authentik_webhook · [t1 − 2 s, t1 + 2 s + 2 s]) — BFF 층 401도 이 로그 조건을 함께 만족해야 한다(VD-T081-c).
  await probeStep(chain, copies, doneAt, AC4_PROBE_DELAY_MS);
  t079.bffEnded = true;
  await logReason(chain, 'webhook', 'authentik_webhook', revocationWindow(t1, AC4_SPAN_MS));
});
