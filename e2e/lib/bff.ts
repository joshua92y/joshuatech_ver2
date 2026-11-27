// e2e/lib/bff.ts — T079 BFF 체인 · 분류 · 판정(설계 D7 · D5 · D12 ①b · r2 — A-2 · V-9). 순수 함수 — 호출은 http.ts 감싸개, 출력은 out.ts가 한다.
// 계약: contracts/bff-api.md §엔드포인트(logout · proxy · health) · §하류 호출 규약 · §오류 형식 + pod-template.md 「오류」 행(type = .../problems/<슬러그의 _를 ->).
// 판정 결과에는 상태 코드와 고정 사유 코드만 싣는다 — 본문 · 헤더 · 쿠키 값 0.
// 여기서는 [gate]가 나오지 않는다(D5 — [gate]는 Traefik 404 서명 · Ingress · Job 부재뿐이고, T079의 빨강 증거는 reach-auth의 [gate]다 — D9 ④).
import type { HttpResult } from './http';
import type { StopPrefix } from './out';

export interface Stop {
  ok: false;
  prefix: StopPrefix;
  code: string;
  note?: string;
}

export type Verdict = { ok: true; code: string } | Stop;

export function stopReason(s: Stop): string {
  return `[${s.prefix}] ${s.code}`;
}

// ---- 체인(D5 JT_E2E_CHAIN — 디스패치 지시문이 준다 · 비밀 아님) ----
// stage 1 = dev 체인(로컬 next dev — 서버 기동 주체는 T077-b 결정 · 권고 (b′) 병행) · stage 2 = prod(T094 도메인 전환 뒤 재실행)
export const CHAIN_ENV = 'JT_E2E_CHAIN';
export const CHAINS = {
  dev: { base: 'http://localhost:3000', ns: 'jt-dev', stage: 1 },
  prod: { base: 'https://joshuatech.dev', ns: 'jt-prod', stage: 2 },
} as const;
export type ChainName = keyof typeof CHAINS;

export interface Chain {
  ok: true;
  chain: ChainName;
  base: string;
  ns: string;
  stage: 1 | 2;
}

export function resolveChain(env: Record<string, string | undefined>): Chain | Stop {
  const v = env[CHAIN_ENV];
  if (typeof v !== 'string' || v.length === 0) return { ok: false, prefix: 'env', code: `missing ${CHAIN_ENV}` };
  // 표에 있는 두 글자만 받는다(프로토타입 키 · 대소문자 · 공백 변형은 꼴 오류 — 값은 싣지 않는다)
  if (v !== 'dev' && v !== 'prod') return { ok: false, prefix: 'env', code: `shape ${CHAIN_ENV}` };
  const c = CHAINS[v];
  return { ok: true, chain: v, base: c.base, ns: c.ns, stage: c.stage };
}

// ---- 계약 경로 · 이름(bff-api.md) ----
export const BFF_PATHS = {
  health: '/api/health',
  login: '/api/auth/login',
  callback: '/api/auth/callback',
  logout: '/api/auth/logout',
  session: '/api/session',
  tenantsMe: '/api/proxy/identity-admin/tenants/me',
} as const;
// 계약 쿠키 이름(B-6 — __Host- 접두 · t086-design.md §0-7). 시험의 독립 기대값이다 — gateway에서 가져오지 않는다. 접두 없는 옛 이름은 BFF가 읽지 않는다.
export const BFF_SESSION_COOKIE = '__Host-jt_session';
export const BFF_CSRF_COOKIE = '__Host-jt_csrf';
export const CSRF_HEADER = 'x-csrf-token';
// all_devices: true 명시 — UD-7 = (나) 2026-11-24 — 모든 기기는 명시해야 한다(생략 = 이 기기만 · 교환 토큰에 sid 없음 — denylist.md:23 · 〔77-14〕)
export const LOGOUT_BODY: Readonly<{ all_devices: true }> = Object.freeze({ all_devices: true });
// 밑줄 → 하이픈(bff-api.md:87 · pod-template.md 「오류」 행). 밑줄 꼴 session_revoked 글자 일치는 PASS가 아니다(r1 — A-4).
export const PROBLEM_SESSION_REVOKED = 'https://joshuatech.dev/problems/session-revoked';

// ---- 관찰(상태 · content-type · 본문만 — 그 밖의 헤더는 버린다) ----
export interface HttpObservation {
  status: number;
  contentType: string | null;
  body: Buffer;
}

export function observeHttp(r: HttpResult): HttpObservation {
  return { status: r.status, contentType: r.headers['content-type'] ?? null, body: r.body };
}

function mediaType(contentType: string | null): string {
  return (contentType ?? '').split(';')[0].trim().toLowerCase();
}

// JSON 객체만 돌려준다. JSON.parse 오류 메시지는 입력 조각을 싣는다(V8) — 오류를 삼키고 null만 돌려준다.
function jsonObject(body: Buffer): Record<string, unknown> | null {
  let v: unknown;
  try {
    v = JSON.parse(body.toString('utf8'));
  } catch {
    return null;
  }
  return typeof v === 'object' && v !== null && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
}

const product = (code: string): Stop => ({ ok: false, prefix: 'product', code });

// ---- reach-bff(D7 공통 단계 3 · r2 — A-2 · V-9) ----
export const DEV_ABSENT_NOTE = 'T092 · T085 · dev 서버 미기동';
export const PROD_NOT_BFF_NOTE = 'T094 전';

export function classifyBffHealth(chain: ChainName, o: HttpObservation): Verdict {
  if (o.status === 200 && mediaType(o.contentType) === 'application/json') {
    const j = jsonObject(o.body);
    if (j !== null && j.upstream === 'identity-admin') return { ok: true, code: 'bff-health' };
  }
  // 52x와 그 밖 5xx → [env] origin(D6 reach와 같다 — 빨강 증거 아님)
  if (o.status >= 500 && o.status <= 599) return { ok: false, prefix: 'env', code: `origin status=${o.status}` };
  // prod 비계약(apex가 아직 v1인 경우 포함) = 체인 부재(T094 전). T094 뒤에는 [product]로 바꾼다(§5-3 · 컨트롤러 — N-5).
  if (chain === 'prod') return { ok: false, prefix: 'env', code: `prod-chain-not-bff status=${o.status}`, note: PROD_NOT_BFF_NOTE };
  return product(`bff-health-unexpected status=${o.status}`);
}

export function classifyBffHealthError(chain: ChainName, code: string): Verdict {
  if (chain === 'dev' && code === 'refused') return { ok: false, prefix: 'env', code: 'dev-chain-server-absent', note: DEV_ABSENT_NOTE };
  return { ok: false, prefix: 'env', code: `network (${code})` };
}

// ---- probe 판정(D7 — r1 — A-4) ----
export type ProbeVerdict = { ok: true; layer: 'pod-relay' | 'bff' } | Stop;

export function judgeRevokedProbe(o: HttpObservation): ProbeVerdict {
  if (o.status !== 401) return product(`probe-not-revoked status=${o.status}`);
  if (mediaType(o.contentType) !== 'application/problem+json') return product('probe-media-type');
  const j = jsonObject(o.body);
  if (j === null) return product('probe-body-not-json');
  const t = j.type;
  if (typeof t !== 'string') return product('probe-type-missing');
  // 층위(INFO): 본문에 request_id 없음 = pod 401을 BFF가 중계(bff-api.md:90) · 있음 = BFF 자신의 401(폐기 확인). 실제 꼴은 VD-T092-a.
  if (t === PROBLEM_SESSION_REVOKED) return { ok: true, layer: Object.prototype.hasOwnProperty.call(j, 'request_id') ? 'bff' : 'pod-relay' };
  if (t.includes('session_revoked')) return product('probe-type-underscore');
  return product('probe-type-mismatch');
}

// ---- 쿠키 사본(D7 공통 단계 copy — 메모리에만 · 파일 0) ----
export interface SessionCopies {
  session: string;
  csrf: string;
}

export interface CookieLike {
  name: string;
  value: string;
  domain: string;
}

export function pickSessionCopies(cookies: readonly CookieLike[], base: string): { ok: true; copies: SessionCopies } | Stop {
  const host = new URL(base).hostname.toLowerCase();
  const matches = (name: string) =>
    cookies.filter((c) => c.name === name && typeof c.value === 'string' && c.value.length > 0 && String(c.domain).replace(/^\./, '').toLowerCase() === host);
  const s = matches(BFF_SESSION_COOKIE);
  const c = matches(BFF_CSRF_COOKIE);
  const missing = [s.length === 0 ? BFF_SESSION_COOKIE : '', c.length === 0 ? BFF_CSRF_COOKIE : ''].filter((x) => x !== '');
  if (missing.length > 0) return product(`session-cookies-missing names=${missing.join(',')}`);
  const ambiguous = [s.length > 1 ? BFF_SESSION_COOKIE : '', c.length > 1 ? BFF_CSRF_COOKIE : ''].filter((x) => x !== '');
  if (ambiguous.length > 0) return product(`session-cookies-ambiguous names=${ambiguous.join(',')}`);
  return { ok: true, copies: { session: s[0].value, csrf: c[0].value } };
}

export function cookieHeader(c: SessionCopies): string {
  return `${BFF_SESSION_COOKIE}=${c.session}; ${BFF_CSRF_COOKIE}=${c.csrf}`;
}

export function probeHeaders(c: SessionCopies): Record<string, string> {
  return { cookie: cookieHeader(c) };
}

export function logoutHeaders(c: SessionCopies): Record<string, string> {
  return { cookie: cookieHeader(c), [CSRF_HEADER]: c.csrf };
}

// ---- 기준선 · 로그아웃(D7 공통 단계 baseline · 시험 1 logout — 〔77-7〕) ----
export function judgeSession(o: HttpObservation): Verdict {
  if (o.status !== 200) return product(`baseline-session status=${o.status}`);
  if (mediaType(o.contentType) !== 'application/json' || jsonObject(o.body) === null) return product('baseline-session-shape');
  return { ok: true, code: 'session-active' };
}

export function judgeTenantsMe(o: HttpObservation): Verdict {
  if (o.status !== 200) return product(`baseline-tenants-me status=${o.status}`);
  const j = mediaType(o.contentType) === 'application/json' ? jsonObject(o.body) : null;
  if (j === null) return product('baseline-tenants-me-shape');
  // e2e 사용자 = member(T083 seed_tenant — FR-036)
  if (j.role !== 'member') return product('baseline-role-not-member');
  return { ok: true, code: 'role=member' };
}

export function judgeLogout(o: HttpObservation): Verdict {
  if (o.status === 204) return { ok: true, code: 'logout-204' };
  return product(`logout-unexpected status=${o.status}`);
}

// ---- 시험 2 · AC4 결정 상수(UD-4 — SC-003 「Authentik 세션 삭제」 경로 · 권고 B = 로그아웃 이벤트 웹훅 · t073-design.md:2493) ----
// 'undecided'(기본) → reach-auth · chain 뒤 [decision]. 권고 B로 정해지면 T081 커밋이 'authentik-logout'으로 바꾼다(selftest bff가 이 값을 고정한다).
export type Ac4Path = 'undecided' | 'authentik-logout';
export const AC4_PATH: Ac4Path = 'undecided';

export function ac4Gate(p: Ac4Path): Verdict {
  if (p === 'authentik-logout') return { ok: true, code: 'authentik-logout' };
  return { ok: false, prefix: 'decision', code: 'UD-4 undecided', note: 'AC4 path (user decision before T081)' };
}

// ---- 시간(D7) ----
export const AC3_PROBE_DELAY_MS = 1_000; // logout 응답 + 1 s → probe
export const AC4_PROBE_DELAY_MS = 2_000; // Authentik 로그아웃 완료 + 2 s → probe
export const AC3_SPAN_MS = 10_000; // log-reason 창 [t0 − 시계 여유, t0 + 10 s + 시계 여유]
export const AC4_SPAN_MS = 2_000; // log-reason 창 [t1 − 시계 여유, t1 + 2 s + 시계 여유]
// 시계 여유는 위아래 대칭이다(빌드 리뷰 r1 — A-8: pod 시계가 클라이언트보다 늦으면 아래 경계 여유 0에서 거짓 reason-not-logged).
// 아래 여유가 앞선 기록과 겹치지 않는 근거: AC3의 revoke · logout_all 줄은 이 로그아웃만 만든다 · AC4의 앞 웹훅은 15 s 간격 밖이다.
export const CLOCK_SLACK_MS = 2_000;
export const DIAG_INTERVAL_MS = 500; // probe가 401이 아닐 때 진단 재질문 간격(≥ 500 ms)
export const DIAG_LIMIT_MS = 10_000; // 진단 재질문 상한(logout 응답부터 10 s — SC-003 자료 · 측정 합격선은 T085)
export const WEBHOOK_GAP_MS = 15_000; // 앞 Authentik 로그아웃과 시험 2 로그아웃 사이(웹훅 지연 상한보다 길게 — VD-T081-b로 보정)
export const LOG_POLL_MS = 2_000; // log-reason 재읽기 간격(창 끝까지)

// anchorMs = 창 기준(t0 · t1 — 오프셋 출력 기준) · startMs = 아래 경계(--since-time도 여기서 내린다) · endMs = 위 경계
export function revocationWindow(anchorMs: number, spanMs: number): { anchorMs: number; startMs: number; endMs: number } {
  return { anchorMs, startMs: anchorMs - CLOCK_SLACK_MS, endMs: anchorMs + spanMs + CLOCK_SLACK_MS };
}

// 앞 Authentik 로그아웃 시각을 모르면(워커 재시작 등) 간격 전체를 기다린다 — 그 기록이 시험 2 창에 들지 않게.
export function gapWaitMs(nowMs: number, lastLogoutMs: number | undefined, gapMs: number = WEBHOOK_GAP_MS): number {
  if (lastLogoutMs === undefined) return gapMs;
  const w = lastLogoutMs + gapMs - nowMs;
  return w > 0 ? w : 0;
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms > 0 ? ms : 0));
}

// probe가 401이 아닐 때의 진단 재질문(D7 :247 — 「≥ 500 ms 간격」): 놓친 probe 뒤 첫 재질문 전에도 간격만큼 기다린다(빌드 리뷰 r1 — A-9).
// 마감 = sinceMs + DIAG_LIMIT_MS. 첫 재질문은 마감과 무관하게 한 번 돈다(pollUntil).
export async function diagnoseUntil<T>(
  attempt: () => Promise<T>,
  done: (v: T) => boolean,
  opts: { sinceMs: number; limitMs?: number; intervalMs?: number; clock?: () => number; wait?: (ms: number) => Promise<void> },
): Promise<{ value: T; tries: number; doneAtMs: number | null }> {
  const intervalMs = opts.intervalMs ?? DIAG_INTERVAL_MS;
  const wait = opts.wait ?? sleep;
  await wait(intervalMs);
  return pollUntil(attempt, done, { deadlineMs: opts.sinceMs + (opts.limitMs ?? DIAG_LIMIT_MS), intervalMs, clock: opts.clock, wait });
}

// 첫 시도는 늘 한다. 성공하면 그 시각(doneAtMs)과 함께 멈추고, 다음 시도가 마감을 넘기면 doneAtMs null로 멈춘다.
export async function pollUntil<T>(
  attempt: () => Promise<T>,
  done: (v: T) => boolean,
  opts: { deadlineMs: number; intervalMs: number; clock?: () => number; wait?: (ms: number) => Promise<void> },
): Promise<{ value: T; tries: number; doneAtMs: number | null }> {
  const clock = opts.clock ?? Date.now;
  const wait = opts.wait ?? sleep;
  let tries = 0;
  for (;;) {
    const value = await attempt();
    tries += 1;
    const now = clock();
    if (done(value)) return { value, tries, doneAtMs: now };
    if (now + opts.intervalMs > opts.deadlineMs) return { value, tries, doneAtMs: null };
    await wait(opts.intervalMs);
  }
}
