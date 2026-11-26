// T089 (US5 · 시험 먼저) — apps/web BFF gateway · 이미지 로더 계약 시험(vitest · fetch 주입).
//
// 과제(tasks.md T089): PKCE · state · JWE 쿠키 · 교환 캐시(impersonation · actor_token 0) · /session/check 2 s 캐시 ·
//   inactive → 쿠키 삭제 · 401 · 하류 헤더 · 3 s AbortController → 503 upstream_unavailable · 프록시 정적 맵 ·
//   return_to · 이미지 로더 폴백 · 로그 JSON 마스킹 — FAIL 확인.
// 정본: specs/003-platform-foundation/contracts/bff-api.md + T089 보정(design/t086-design.md D7 C1–C29 · D8 · D9 ·
//   §0 UD-7 · UD-7a(ㄱ) · UD-8 · B-6 · §7 N-5 · N-8 · N-9 · N-15 · N-17) · .claude/rules/web.md · identity-admin-api.md :56–:58.
// 짝 구현: T091 src/lib/image-loader.ts · T092 src/lib/gateway.ts(+ app/api/**/route.ts 어댑터 — env를 얻어 위임만).
// 빨강(T091 · T092 전): 사례마다 늦은 적재(import("./gateway") · import("./image-loader"))가 실패한다 — passed 0.
//
// ── 이 시험이 고정하는 모듈 API(머리 주석이 정본 — D6) ─────────────────────────────────────────────────────
// src/lib/gateway.ts — ESM named exports
//   createGateway(env, deps) -> Gateway        던지지 않는다(설정이 무효여도 — C26)
//     env  Readonly<Record<string, string | undefined>> — 7개만 읽는다:
//          Workers Secrets SESSION_ENCRYPTION_KEY(16진 64자) · WEB_BFF_CLIENT_SECRET · CF_ACCESS_CLIENT_ID(<32 hex>.access)
//          · CF_ACCESS_CLIENT_SECRET / vars IDENTITY_M2M_URL(https origin) · AUTHENTIK_ISSUER(https · 끝 /) · WEB_BFF_CLIENT_ID
//     deps { fetch(req: Request): Promise<Response>   유일한 상류 통로(인자는 Request 하나 · 전역 fetch 0)
//            now(): number                            epoch ms(Date.now 꼴) — 캐시 TTL · ID 토큰 exp · pkce created_at의 유일한 시계
//            randomBytes(n): Uint8Array               PKCE verifier · state · CSRF 값만(JWE IV는 JWE 층이 스스로)
//            sample(): boolean                        traceparent sampled(true → 01 · false → 00)
//            log(line: string): void }                요청마다 정확히 한 줄 JSON(console.* 0)
//   Gateway = { login, callback, logout, refresh, session, health, proxy } — 정확히 이 7키 · 모두 (req: Request) => Promise<Response>
//     어떤 상류 입력 · deps.fetch 예외에도 reject 0(G17). 캐시(폐기 확인 2 s · 교환)는 인스턴스 안.
//   validateEnv(env) -> readonly string[]       꼴이 틀리거나 없는 env 이름(정렬) — 값은 싣지 않는다(C26)
//   isSameOriginPath(decoded, origin) -> boolean  bff-api.md 「같은 origin 경로」 공유 정의 — ③ 출력 가능 ASCII는
//     return_to 규칙(login · callback 재검증)에서 따로 본다(N-8). G2-4는 두 읽기에서 결과가 같은 사례만 직접 본다.
//   matchProxyRoute(rawUrl, method) -> { pod, path } | null   C20(원문 pathname 정확 일치 · GET만)
//   s256(verifier) -> Promise<string>             base64url(SHA-256(ASCII(verifier))) 무패딩
// src/lib/image-loader.ts
//   export default imageLoader({ src, width, quality }) -> string · export fallbackSrc(url) -> string | null   (C21)
//
// ── 계약 세부(시험이 기대값으로 쓰는 것) ───────────────────────────────────────────────────────────────────
// 쿠키(B-6 · N-9 · C28): __Host-jt_session · __Host-jt_csrf · __Host-jt_pkce(Path=/ · Max-Age=300). 옛 이름 jt_session ·
//   jt_csrf는 읽지 않는다(세션을 쓰는 네 라우트 모두 — G4-4 · G11-1). 같은 이름 둘 이상 = 무효. 쿠키 값 = `v1.` + JWE
//   compact(dir · A256GCM · typ) — __tests__/oracle-jwe.ts.
//   세션 평문 정확 키: refresh_token · sub · sid · tenant_id(uuid) · issued_at(정수 초) + 있을 때만 email · name.
//   pkce 평문 정확 키: state · verifier · return_to(C27 ⑤ 직렬화) · created_at(정수 epoch 초 = ⌊now()/1000⌋) · typ jt-pkce.
//   pkce 만료 = created_at + 300 s를 넘을 때(정확히 300 s는 유효 — G3-1b). 콜백 밖 라우트에 실려 온 __Host-jt_pkce(N-9의
//   대가)의 값 · 평문 state · verifier는 하류 · 로그 · 응답 0(G8 · G13 — 리뷰 B-2 · 라우트별 하류는 G8-3 — 검증 V1-1).
//   CSRF = 16진 32자(소문자) · 상태 변경 요청 헤더 x-csrf-token과 같아야 한다.
// Authentik(C1 · C7): authorize · token · revoke = issuer origin + /application/o/{authorize,token,revoke}/ · end-session =
//   issuer + end-session/ · client_secret_post · 헤더 정확 {accept, content-type(form)}.
//   x-end-session-url(C23)은 AUTHENTIK_ISSUER · WEB_BFF_CLIENT_ID가 둘 다 유효할 때만 — 하나만 무효여도 0(G16-5 (b) · (c)).
//   code 교환 키 6 · refresh 키 4(grant_type, refresh_token, client_id, client_secret) · 교환 키 6 · RFC 7009 키 4
//   (token, token_type_hint=refresh_token, client_id, client_secret).
// 캐시: 폐기 확인 적중 ⇔ now − 저장 < 2000 ms(키 sub + issued_at + sid · 판정 아님은 저장 0) · 교환 적중 ⇔ now − 저장 <
//   (min(expires_in, 300) − 30) s(키 sub | aud | issued_at · expires_in 없음 · 정수 아님 → 저장 0 — C13).
// 3 s(C14): 상류 호출마다 AbortController + setTimeout(3000)(AbortSignal.timeout 0) · 헤더 + 본문 읽기까지 · 재시도 0.
// 응답(C16): 모든 응답 cache-control no-store · nosniff · x-request-id(crypto.randomUUID) · ACAO 0 · 헤더 이름 집합은
//   __tests__/headers.ts 표. problem = {type, title, status, detail?, instance, request_id} · type =
//   https://joshuatech.dev/problems/<slug — _를 -로> · instance = 요청 pathname(질의 0).
// 로그(C15): 키 9개 정확 · level ≥500 error · 4xx warn · 그 밖 info · route = 라우트 템플릿 · upstream = 그 요청의 마지막
//   상류 호출 종류(identity-admin | authentik | null) · upstream_ms = 그 호출의 정수 ms(null ⇔ upstream null) ·
//   exchange_result ∈ {cache_hit, exchanged, denied, error, null}(교환 캐시를 쓰지도 교환을 시도하지도 않은 요청 = null).
// 설계 해석(보고 대상): G17 「필드 꼴 오류」 행별 적용 — id_token(두 조각 · base64url 아님)은 code 교환 행만, expires_in
//   문자열은 code 교환 · refresh 행만(교환 응답의 expires_in 꼴 오류는 C13 「캐시 0」 — G7-10).
// ───────────────────────────────────────────────────────────────────────────────────────────────────────────
// 가짜 비밀은 전부 실행 중에 만든다(D9-5): fake() · randomHex() · fakeJwt() · 사용자 정보 URL은 + 로 잇는다.

import { createHash, randomUUID } from "node:crypto";

import { describe, expect, it, vi } from "vitest";

import {
  CSRF_COOKIE,
  LEGACY_CSRF_COOKIE,
  LEGACY_SESSION_COOKIE,
  type ParsedCookie,
  PKCE_COOKIE,
  SESSION_COOKIE,
  SESSION_MAX_AGE,
  cookieHeader,
  cookieNamed,
  setCookies,
} from "./__tests__/cookies";
import {
  AUTHORIZE_URL,
  AUTH_ORIGIN,
  type CallKind,
  END_SESSION_URL,
  EVIL_ORIGIN,
  GRANT_EXCHANGE,
  HANG,
  ISSUER,
  M2M,
  REVOKE_URL,
  type Recorded,
  type Reply,
  SITE,
  TOKEN_TYPE_ACCESS,
  TOKEN_URL,
  type Upstream,
  createUpstream,
  empty,
  html,
  json,
  problemReply,
  raw,
  stall,
  throwsTypeError,
} from "./__tests__/fake-upstream";
import { type Outcome, type RouteName, assertResponseHeaders } from "./__tests__/headers";
import { installFileInvariants, track } from "./__tests__/invariants";
import { b64url, fake, fakeJwt, hasNeedle, randomBytes, randomHex } from "./__tests__/needles";
import { seal, splitCompact, tamper, unseal } from "./__tests__/oracle-jwe";

installFileInvariants();

// ── 늦은 적재(D9-1) — 적재는 expect 밖 · 사례마다 ───────────────────────────────────────────────────────────
// 구현 전(T092 · T091) 모듈이라 형식이 없다 — any로 받는다.
type GatewayModule = any;
async function loadGateway(): Promise<GatewayModule> {
  return await import("./gateway");
}
async function loadImageLoader(): Promise<GatewayModule> {
  return await import("./image-loader");
}

// ── 상수 ─────────────────────────────────────────────────────────────────────────────────────────────────
const T0 = Date.UTC(2026, 10, 24, 3, 0, 0);
const T0S = T0 / 1000;
const ROUTES = ["callback", "health", "login", "logout", "proxy", "refresh", "session"] as const;
const ENV_NAMES = [
  "AUTHENTIK_ISSUER",
  "CF_ACCESS_CLIENT_ID",
  "CF_ACCESS_CLIENT_SECRET",
  "IDENTITY_M2M_URL",
  "SESSION_ENCRYPTION_KEY",
  "WEB_BFF_CLIENT_ID",
  "WEB_BFF_CLIENT_SECRET",
];
const ROUTE_PATH: Record<Exclude<RouteName, "proxy">, string> = {
  login: "/api/auth/login",
  callback: "/api/auth/callback",
  logout: "/api/auth/logout",
  refresh: "/api/auth/refresh",
  session: "/api/session",
  health: "/api/health",
};
const ROUTE_TEMPLATE: Record<RouteName, string> = { ...ROUTE_PATH, proxy: "/api/proxy/[pod]/[...path]" };
const PROBLEM_BASE = "https://joshuatech.dev/problems/";
const CDN = "https://cdn.joshuatech.dev";
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const B64URL43 = /^[A-Za-z0-9_-]{43}$/;
const HEX32 = /^[0-9a-f]{32}$/;
const PRINTABLE_ASCII = /^[\x21-\x7e]+$/;
const TRACEPARENT = /^00-([0-9a-f]{32})-([0-9a-f]{16})-(0[01])$/;
const ISO_TS = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/;
const AUTHORIZE_KEYS = ["client_id", "code_challenge", "code_challenge_method", "redirect_uri", "response_type", "scope", "state"];
const LOG_KEYS = ["exchange_result", "level", "request_id", "route", "status", "trace_id", "ts", "upstream", "upstream_ms"];
// RFC 7636 부록 B — 32옥텟(→ verifier) · S256 challenge
const RFC7636_B_OCTETS = [
  116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186, 22, 212, 37, 77, 105, 214, 191, 240, 91, 88,
  5, 88, 83, 132, 141, 121,
];
const RFC7636_B_CHALLENGE = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";

// ── 고정물 ───────────────────────────────────────────────────────────────────────────────────────────────
type Env = Record<string, string | undefined>;

/** 유효한 env — 비밀성 값은 전부 실행 중 생성(비밀 이름 옆 리터럴 0). */
function baseEnv(): Env {
  const env: Env = {
    AUTHENTIK_ISSUER: ISSUER,
    IDENTITY_M2M_URL: M2M,
    CF_ACCESS_CLIENT_ID: `${randomHex(16)}.access`,
    SESSION_ENCRYPTION_KEY: randomHex(32),
  };
  for (const name of ["WEB_BFF_CLIENT_ID", "WEB_BFF_CLIENT_SECRET", "CF_ACCESS_CLIENT_SECRET"]) {
    env[name] = fake(name.toLowerCase().replaceAll("_", "-"));
  }
  return env;
}

function envSecretNeedles(env: Env): Record<string, string> {
  const out: Record<string, string> = {};
  for (const name of ["SESSION_ENCRYPTION_KEY", "WEB_BFF_CLIENT_SECRET", "CF_ACCESS_CLIENT_ID", "CF_ACCESS_CLIENT_SECRET"]) {
    out[`env ${name}`] = env[name] as string;
  }
  return out;
}

interface Ctx {
  mod: GatewayModule;
  gw: GatewayModule;
  env: Env;
  up: Upstream;
  clock: { t: number };
  logs: string[];
  sampled: { v: boolean };
}

async function setup(over: { env?: Env; sampled?: boolean } = {}): Promise<Ctx> {
  const mod = await loadGateway();
  const up = track(createUpstream());
  const clock = { t: T0 };
  const logs: string[] = [];
  const sampled = { v: over.sampled ?? false };
  const env = over.env ?? baseEnv();
  const deps = {
    fetch: up.fetch,
    now: () => clock.t,
    randomBytes: (n: number) => randomBytes(n),
    sample: () => sampled.v,
    log: (line: string) => {
      logs.push(line);
    },
  };
  const gw = mod.createGateway(env, deps);
  return { mod, gw, env, up, clock, logs, sampled };
}

function keyOf(ctx: Ctx): string {
  return ctx.env.SESSION_ENCRYPTION_KEY as string;
}

// ── 호출 ─────────────────────────────────────────────────────────────────────────────────────────────────
interface Out {
  res: Response;
  status: number;
  text: string;
  body: GatewayModule;
  cookies: ParsedCookie[];
  log: Record<string, unknown>;
}

/** 모든 호출은 여기를 지난다(G17 불변식 — reject면 그 사례 실패) · 요청마다 로그 정확히 1줄(C15). */
async function run(ctx: Ctx, route: RouteName, request: Request): Promise<Out> {
  const before = ctx.logs.length;
  let res: unknown;
  try {
    res = await ctx.gw[route](request);
  } catch (err) {
    throw new Error(`G17 invariant: ${route} rejected (${(err as Error)?.name ?? typeof err}) — reject 0 for any input`);
  }
  if (!(res instanceof Response)) {
    throw new Error(`${route} did not resolve to a Response`);
  }
  const text = await res.clone().text();
  let body: GatewayModule;
  try {
    body = text === "" ? undefined : JSON.parse(text);
  } catch {
    body = undefined;
  }
  const added = ctx.logs.slice(before);
  expect(added.length, `${route}: exactly one log line per request (C15)`).toBe(1);
  let log: Record<string, unknown>;
  try {
    log = JSON.parse(added[0]) as Record<string, unknown>;
  } catch {
    throw new Error(`${route}: log line is not JSON (C15)`);
  }
  return { res, status: res.status, text, body, cookies: setCookies(res), log };
}

function get(path: string, init: { cookie?: string; headers?: Array<[string, string]> } = {}): Request {
  const headers = new Headers(init.headers ?? []);
  if (init.cookie !== undefined) headers.set("cookie", init.cookie);
  return new Request(`${SITE}${path}`, { method: "GET", headers });
}

function post(
  path: string,
  init: { cookie?: string; csrf?: string | null; body?: string | null; headers?: Array<[string, string]> } = {},
): Request {
  const headers = new Headers(init.headers ?? []);
  if (init.cookie !== undefined) headers.set("cookie", init.cookie);
  if (init.csrf) headers.set("x-csrf-token", init.csrf);
  if (init.body !== undefined && init.body !== null) headers.set("content-type", "application/json");
  return new Request(`${SITE}${path}`, { method: "POST", headers, body: init.body ?? undefined });
}

// ── 세션 ─────────────────────────────────────────────────────────────────────────────────────────────────
interface Claims {
  refresh_token: string;
  sub: string;
  sid: string;
  tenant_id: string;
  issued_at: number;
  email?: string;
  name?: string;
}
interface Session {
  claims: Claims;
  value: string;
  csrf: string;
}

function claims(over: Partial<Claims> = {}): Claims {
  return {
    refresh_token: fake("rt"),
    sub: fake("sub"),
    sid: fake("sid"),
    tenant_id: randomUUID(),
    issued_at: T0S - 600,
    email: `${fake("user")}@example.test`,
    name: fake("name"),
    ...over,
  };
}

async function mintSession(ctx: Ctx, over: Partial<Claims> = {}, drop: Array<keyof Claims> = []): Promise<Session> {
  const c = claims(over) as unknown as Record<string, unknown>;
  for (const k of drop) delete c[k];
  return { claims: c as unknown as Claims, value: await seal(keyOf(ctx), "jt-session", c), csrf: randomHex(16) };
}

function cookieOf(s: Session, extra: Array<[string, string]> = []): string {
  return cookieHeader([[SESSION_COOKIE, s.value], [CSRF_COOKIE, s.csrf], ...extra]);
}

/** 회전 응답이 있으면 새 세션 쿠키 값으로 바꾼 사본(브라우저처럼). */
function follow(s: Session, out: Out): Session {
  const next = cookieNamed(out.cookies, SESSION_COOKIE);
  return next && next.value !== "" ? { ...s, value: next.value } : s;
}

function sessionReq(s: Session | null, headers: Array<[string, string]> = []): Request {
  return get("/api/session", { cookie: s ? cookieOf(s) : undefined, headers });
}

function proxyReq(s: Session | null, path = "/tenants/me", headers: Array<[string, string]> = []): Request {
  return get(`/api/proxy/identity-admin${path}`, { cookie: s ? cookieOf(s) : undefined, headers });
}

function refreshReq(s: Session, csrf: string | null = s.csrf, cookie = cookieOf(s)): Request {
  return post("/api/auth/refresh", { cookie, csrf });
}

function logoutReq(
  s: Session | null,
  body: string | null = null,
  opts: { csrf?: string | null; cookie?: string; query?: string; headers?: Array<[string, string]> } = {},
): Request {
  return post(`/api/auth/logout${opts.query ?? ""}`, {
    cookie: opts.cookie ?? (s ? cookieOf(s) : undefined),
    csrf: opts.csrf === undefined ? s?.csrf : opts.csrf,
    body,
    headers: opts.headers,
  });
}

// ── login · callback ─────────────────────────────────────────────────────────────────────────────────────
interface Pkce {
  value: string;
  state: string;
  verifier: string;
}

async function sealPkce(
  ctx: Ctx,
  over: Partial<{ state: string; verifier: string; return_to: string; created_at: number }> = {},
  typ = "jt-pkce",
): Promise<Pkce> {
  const p = { state: fake("state"), verifier: b64url(randomBytes(32)), return_to: "/ko", created_at: T0S, ...over };
  return { value: await seal(keyOf(ctx), typ, p), state: p.state, verifier: p.verifier };
}

/** 실제 login 응답에서 pkce 쿠키 · state · verifier를 얻는다(왕복 시험). */
async function startLogin(ctx: Ctx, rawReturnTo: string | null = null): Promise<Pkce> {
  const out = await run(ctx, "login", get(`/api/auth/login${rawReturnTo === null ? "" : `?return_to=${rawReturnTo}`}`));
  expect(out.status, "login 302").toBe(302);
  const value = cookieNamed(out.cookies, PKCE_COOKIE)?.value as string;
  const state = new URL(out.res.headers.get("location") as string).searchParams.get("state") as string;
  const verifier = (await unseal(keyOf(ctx), value)).payload.verifier as string;
  return { value, state, verifier };
}

function callbackReq(code: string | null, state: string | null, pkce: string | string[] | null, extraQuery = ""): Request {
  const q = new URLSearchParams();
  if (code !== null) q.set("code", code);
  if (state !== null) q.set("state", state);
  const values = pkce === null ? [] : Array.isArray(pkce) ? pkce : [pkce];
  const cookie = values.length > 0 ? cookieHeader(values.map((v) => [PKCE_COOKIE, v] as [string, string])) : undefined;
  return get(`/api/auth/callback?${q.toString()}${extraQuery}`, { cookie });
}

function idClaims(ctx: Ctx, over: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    iss: ISSUER,
    aud: ctx.env.WEB_BFF_CLIENT_ID,
    exp: T0S + 300,
    iat: T0S - 5,
    sub: fake("sub"),
    sid: fake("sid"),
    tenant_id: randomUUID(),
    email: `${fake("user")}@example.test`,
    name: fake("name"),
    ...over,
  };
}

interface CodeTokens {
  access: string;
  refresh: string;
  idToken: string;
}

function codeTokens(ctx: Ctx, id: Record<string, unknown>): { tokens: CodeTokens; reply: Reply } {
  const tokens = { access: fake("at"), refresh: fake("rt"), idToken: fakeJwt(id) };
  return {
    tokens,
    reply: json(200, {
      access_token: tokens.access,
      refresh_token: tokens.refresh,
      id_token: tokens.idToken,
      token_type: "Bearer",
      expires_in: 300,
    }),
  };
}

// ── 표준 상류 ────────────────────────────────────────────────────────────────────────────────────────────
interface Issued {
  refresh: string[];
  access: string[];
  exchanged: string[];
}

/** 확인 active · refresh(회전) · 교환 · pod · /sessions/revoke 202 · RFC 7009 200 · /health 200. 발급 토큰을 기록한다. */
function standard(ctx: Ctx, opts: { exchangeTtl?: unknown } = {}): Issued {
  const issued: Issued = { refresh: [], access: [], exchanged: [] };
  ctx.up.on("check", json(200, { active: true }));
  ctx.up.on("token-refresh", () => {
    const rt = fake("rt-rotated");
    const at = fake("at");
    issued.refresh.push(rt);
    issued.access.push(at);
    return json(200, { access_token: at, refresh_token: rt, token_type: "Bearer", expires_in: 300 });
  });
  ctx.up.on("token-exchange", () => {
    const xt = fake("xt");
    issued.exchanged.push(xt);
    const body: Record<string, unknown> = { access_token: xt, issued_token_type: TOKEN_TYPE_ACCESS, token_type: "Bearer" };
    const ttl = Object.hasOwn(opts, "exchangeTtl") ? opts.exchangeTtl : 300;
    if (ttl !== undefined) body.expires_in = ttl;
    return json(200, body);
  });
  ctx.up.on("pod", (rec) => json(200, { pod: "identity-admin", path: rec.pathname }));
  ctx.up.on("sessions-revoke", json(202, { id: randomUUID(), nbf: T0S + 1, expires_at: new Date((T0S + 331) * 1000).toISOString() }));
  ctx.up.on("rfc7009", empty(200));
  ctx.up.on(
    "health",
    json(200, {
      status: "ok",
      version: "1.0.0",
      git_sha: randomHex(20),
      checks: {
        db: { status: "ok", latency_ms: 3 },
        dragonfly: { status: "ok", latency_ms: 1 },
        kafka_producer: { status: "ok", latency_ms: 2 },
      },
    }),
  );
  return issued;
}

// ── 단언 도우미 ──────────────────────────────────────────────────────────────────────────────────────────
function mediaType(res: Response): string {
  return (res.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
}

function formKeys(rec: Recorded): string[] {
  return [...(rec.form ?? new URLSearchParams()).keys()].sort();
}

/** RFC 9457 problem 꼴(C16): 키 정확 · type 슬러그 · status · instance = 요청 pathname · request_id = 헤더. */
function expectProblem(out: Out, status: number, slug: string, instance: string): void {
  expect(out.status, `status (${slug})`).toBe(status);
  expect(mediaType(out.res), "problem content-type").toBe("application/problem+json");
  expect(out.body, "problem body is a JSON object").toBeTypeOf("object");
  const keys = Object.keys(out.body ?? {}).sort();
  expect(keys.filter((k) => k !== "detail"), "problem keys").toEqual(["instance", "request_id", "status", "title", "type"]);
  expect(out.body.type).toBe(`${PROBLEM_BASE}${slug}`);
  expect(out.body.status).toBe(status);
  expect(typeof out.body.title === "string" && out.body.title.length > 0, "problem title").toBe(true);
  if (Object.hasOwn(out.body, "detail")) expect(out.body.detail).toBeTypeOf("string");
  expect(out.body.instance).toBe(instance);
  expect(out.body.request_id).toBe(out.res.headers.get("x-request-id"));
}

/** 로그 한 줄의 꼴(C15). */
function expectLogForm(out: Out, route: RouteName): void {
  const e = out.log;
  expect(Object.keys(e).sort(), "log keys (C15)").toEqual(LOG_KEYS);
  expect(e.ts).toMatch(ISO_TS);
  expect(e.level).toBe(out.status >= 500 ? "error" : out.status >= 400 ? "warn" : "info");
  expect(e.request_id).toBe(out.res.headers.get("x-request-id"));
  expect(e.route).toBe(ROUTE_TEMPLATE[route]);
  expect(e.status).toBe(out.status);
  expect(["identity-admin", "authentik", null]).toContain(e.upstream);
  if (e.upstream === null) {
    expect(e.upstream_ms).toBeNull();
  } else {
    expect(Number.isInteger(e.upstream_ms) && (e.upstream_ms as number) >= 0, "upstream_ms integer").toBe(true);
  }
  expect(["cache_hit", "exchanged", "denied", "error", null]).toContain(e.exchange_result);
  expect(e.trace_id).toMatch(/^[0-9a-f]{32}$/);
  expect(e.trace_id).not.toBe("0".repeat(32));
}

function expectLog(out: Out, route: RouteName, upstream: string | null, exchange: string | null): void {
  expectLogForm(out, route);
  expect(out.log.upstream, "log upstream").toBe(upstream);
  expect(out.log.exchange_result, "log exchange_result").toBe(exchange);
}

type Needles = Record<string, string>;

/**
 * 바늘 0(G13): 로그 · 응답 본문(problem detail 포함) · 응답 헤더(BFF 자신의 Set-Cookie는 헤더 면에서 제외)에 없다.
 * BFF 자신의 Set-Cookie 값은 로그 · 본문 면에서 바늘이다. 「바늘 0」 앞에 로그 줄 ≥ 1을 먼저 본다.
 */
function expectNoNeedles(ctx: Ctx, outs: Out[], needles: Needles, bodyExempt: string[] = []): void {
  expect(ctx.logs.length, "log lines >= 1 before needle-absence").toBeGreaterThanOrEqual(1);
  const logText = ctx.logs.join("\n");
  const own: Needles = {};
  for (const out of outs) {
    for (const c of out.cookies) {
      if (c.value.length >= 8) own[`BFF Set-Cookie ${c.name}`] = c.value;
    }
  }
  for (const [label, value] of Object.entries({ ...needles, ...own })) {
    expect(hasNeedle(logText, value), `log contains ${label}`).toBe(false);
  }
  for (const out of outs) {
    const headerText = [...out.res.headers]
      .filter(([k]) => k !== "set-cookie")
      .map(([k, v]) => `${k}: ${v}`)
      .join("\n");
    for (const [label, value] of Object.entries(needles)) {
      if (!bodyExempt.includes(label)) expect(hasNeedle(out.text, value), `body contains ${label}`).toBe(false);
      expect(hasNeedle(headerText, value), `headers contain ${label}`).toBe(false);
    }
    for (const [label, value] of Object.entries(own)) {
      expect(hasNeedle(out.text, value), `body contains ${label}`).toBe(false);
    }
  }
}

/** 하류로 나간 모든 호출(URL · 헤더 값 · 본문)에 바늘 0. */
function expectNoNeedlesDownstream(ctx: Ctx, needles: Needles): void {
  expect(ctx.up.calls.length, "downstream calls >= 1 before needle-absence").toBeGreaterThan(0);
  for (const c of ctx.up.calls) {
    const surface = [c.url, ...Object.values(c.headers), c.body].join("\n");
    for (const [label, value] of Object.entries(needles)) {
      expect(hasNeedle(surface, value), `downstream #${c.seq} ${c.kind} contains ${label}`).toBe(false);
    }
  }
}

/** x-end-session-url 값(C23 · G11-12). */
function expectEndSession(ctx: Ctx, res: Response): string {
  const v = res.headers.get("x-end-session-url");
  expect(v, "x-end-session-url present").not.toBeNull();
  const u = new URL(v as string);
  expect(`${u.origin}${u.pathname}`).toBe(END_SESSION_URL);
  expect([...u.searchParams.keys()].sort()).toEqual(["client_id", "post_logout_redirect_uri"]);
  expect(u.searchParams.get("client_id")).toBe(ctx.env.WEB_BFF_CLIENT_ID);
  expect(u.searchParams.get("post_logout_redirect_uri")).toBe(`${SITE}/`);
  expect(u.hash).toBe("");
  expect(`${u.username}${u.password}`).toBe("");
  expect((v as string).includes("evil.invalid")).toBe(false);
  expect(res.headers.get("location")).toBeNull();
  return v as string;
}

/** 회전 쿠키(C10): 새 refresh · 나머지 평문 그대로 · 새 IV · CSRF 같은 값 다시. */
async function expectRotated(ctx: Ctx, out: Out, before: Session, newRefresh: string): Promise<void> {
  const next = cookieNamed(out.cookies, SESSION_COOKIE);
  const opened = await unseal(keyOf(ctx), next?.value as string);
  expect(opened.header).toEqual({ alg: "dir", enc: "A256GCM", typ: "jt-session" });
  expect(opened.payload).toEqual({ ...before.claims, refresh_token: newRefresh });
  expect(opened.ivB64).not.toBe(splitCompact(before.value)[2]);
  expect(cookieNamed(out.cookies, CSRF_COOKIE)?.value).toBe(before.csrf);
}

async function drain(rounds = 25): Promise<void> {
  for (let i = 0; i < rounds; i += 1) {
    await new Promise<void>((resolve) => setImmediate(resolve));
  }
}

/** 3 s 경계(C14 · VD-T089-2): kind 호출이 나간 뒤 2999 ms 미결 · 3000 ms에 응답 · 그 호출의 signal이 abort됐다. */
async function expectTimeoutAt3s(ctx: Ctx, kind: CallKind, start: () => Promise<Out>): Promise<Out> {
  vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
  let settled = false;
  const p = start();
  p.then(
    () => {
      settled = true;
    },
    () => {
      settled = true;
    },
  );
  const rec = await ctx.up.waitFor(kind);
  await vi.advanceTimersByTimeAsync(2999);
  await drain();
  expect(settled, `${kind}: still pending at 2999 ms`).toBe(false);
  await vi.advanceTimersByTimeAsync(1);
  for (let i = 0; i < 500 && !settled; i += 1) {
    await new Promise<void>((resolve) => setImmediate(resolve));
  }
  expect(settled, `${kind}: answered at 3000 ms`).toBe(true);
  const out = await p;
  expect(rec.signal.aborted, `${kind}: the 3 s AbortController aborted the call`).toBe(true);
  vi.useRealTimers();
  return out;
}

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G0 적재", () => {
  it("G0-1 gateway — 다섯 export 함수 · Gateway 정확히 7키 · validateEnv 유효 [] · 빈 env 7이름(정렬)", async () => {
    const mod = await loadGateway();
    for (const name of ["createGateway", "validateEnv", "isSameOriginPath", "matchProxyRoute", "s256"]) {
      expect(typeof mod[name], name).toBe("function");
    }
    const ctx = await setup();
    expect(Object.keys(ctx.gw).sort()).toEqual([...ROUTES]);
    for (const r of ROUTES) expect(typeof ctx.gw[r], r).toBe("function");
    expect(mod.validateEnv(ctx.env)).toEqual([]);
    expect(mod.validateEnv({})).toEqual(ENV_NAMES);
  });

  it("G0-2 image-loader — default · fallbackSrc 함수 · 변환 한 건", async () => {
    const mod = await loadImageLoader();
    expect(typeof mod.default).toBe("function");
    expect(typeof mod.fallbackSrc).toBe("function");
    expect(mod.default({ src: `${CDN}/a.png`, width: 64 })).toBe(
      `${CDN}/cdn-cgi/image/width=64,quality=75,format=auto,onerror=redirect/a.png`,
    );
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G1 login · PKCE", () => {
  it("G1-1 302 authorize — 질의 키 정확 7 · S256 · __Host-jt_pkce 봉인(C4 · C28 · N-9) · 세션 쿠키 0 · 상류 0", async () => {
    const ctx = await setup();
    const out = await run(ctx, "login", get(`/api/auth/login?return_to=${encodeURIComponent("/ko")}`));
    expect(out.status).toBe(302);
    const cookies = assertResponseHeaders("login", "login-302", out.res);
    expect(ctx.up.calls).toHaveLength(0);
    const loc = new URL(out.res.headers.get("location") as string);
    expect(`${loc.origin}${loc.pathname}`).toBe(AUTHORIZE_URL);
    expect([...loc.searchParams.keys()].sort()).toEqual(AUTHORIZE_KEYS);
    expect(loc.hash).toBe("");
    expect(loc.searchParams.get("response_type")).toBe("code");
    expect(loc.searchParams.get("client_id")).toBe(ctx.env.WEB_BFF_CLIENT_ID);
    expect(loc.searchParams.get("redirect_uri")).toBe(`${SITE}/api/auth/callback`);
    expect((loc.searchParams.get("scope") as string).split(" ")).toEqual(expect.arrayContaining(["openid", "offline_access"]));
    expect(loc.searchParams.get("code_challenge_method")).toBe("S256");
    const state = loc.searchParams.get("state") as string;
    const challenge = loc.searchParams.get("code_challenge") as string;
    expect(state).toMatch(B64URL43);
    expect(challenge).toMatch(B64URL43);
    const opened = await unseal(keyOf(ctx), cookieNamed(cookies, PKCE_COOKIE)?.value as string);
    expect(opened.header).toEqual({ alg: "dir", enc: "A256GCM", typ: "jt-pkce" });
    expect(Object.keys(opened.payload).sort()).toEqual(["created_at", "return_to", "state", "verifier"]);
    expect(opened.payload.state).toBe(state);
    expect(opened.payload.verifier).toMatch(B64URL43);
    expect(challenge).toBe(createHash("sha256").update(opened.payload.verifier as string, "ascii").digest("base64url"));
    expect(opened.payload.return_to).toBe("/ko");
    expect(opened.payload.created_at).toBe(T0S);
    expect(loc.href.includes(opened.payload.verifier as string)).toBe(false);
    expectLog(out, "login", null, null);
  });

  it("G1-2 login 두 번 — state · verifier · pkce 쿠키 값이 서로 다르다", async () => {
    const ctx = await setup();
    const a = await startLogin(ctx);
    const b = await startLogin(ctx);
    expect(a.state).not.toBe(b.state);
    expect(a.verifier).not.toBe(b.verifier);
    expect(a.value).not.toBe(b.value);
    expect(a.state).not.toBe(a.verifier);
  });

  it("G1-3 s256 — RFC 7636 부록 B 벡터 · node:crypto 독립 계산과 같다", async () => {
    const mod = await loadGateway();
    const verifier = b64url(new Uint8Array(RFC7636_B_OCTETS));
    expect(await mod.s256(verifier)).toBe(RFC7636_B_CHALLENGE);
    const other = b64url(randomBytes(32));
    expect(await mod.s256(other)).toBe(createHash("sha256").update(other, "ascii").digest("base64url"));
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
const enc = encodeURIComponent;

describe("G2 return_to(C27 · N-8)", () => {
  // [이름, 질의 원문(null = 없음), 봉인 기대값(C27 ⑤ — callback이 302 Location으로 쓸 값)]
  const ALLOWED: Array<[string, string | null, string]> = [
    ["/", enc("/"), "/"],
    ["/ko", enc("/ko"), "/ko"],
    ["/ko/notes?x=1#y", enc("/ko/notes?x=1#y"), "/ko/notes?x=1#y"],
    ["질의 %252F → /%2F/evil.com", "/%252F/evil.com", "/%2F/evil.com"],
    ["2,048자", enc(`/${"a".repeat(2047)}`), `/${"a".repeat(2047)}`],
    ["없음 → /", null, "/"],
    ['"×500 → %22×500', enc(`/${'"'.repeat(500)}`), `/${"%22".repeat(500)}`],
  ];

  it.each(ALLOWED)("G2-1 허용 %s → 302 · 봉인 return_to 정확 · 출력 가능 ASCII · 같은 origin · pathname // 아님", async (_l, rawValue, sealed) => {
    const ctx = await setup();
    const out = await run(ctx, "login", get(`/api/auth/login${rawValue === null ? "" : `?return_to=${rawValue}`}`));
    expect(out.status).toBe(302);
    const cookies = assertResponseHeaders("login", "login-302", out.res);
    const v = (await unseal(keyOf(ctx), cookieNamed(cookies, PKCE_COOKIE)?.value as string)).payload.return_to as string;
    expect(v).toBe(sealed);
    expect(v).toMatch(PRINTABLE_ASCII);
    const resolved = new URL(v, `${SITE}/api/auth/callback`);
    expect(resolved.origin).toBe(SITE);
    expect(resolved.pathname.startsWith("//")).toBe(false);
    expect(ctx.up.calls).toHaveLength(0);
  });

  // [이름, 질의 원문]
  const REJECTED: Array<[string, string]> = [
    ["r0 https://evil.com", enc("https://evil.com")],
    ["r0 //evil.com", enc("//evil.com")],
    ["r0 /%5Cevil.com", "/%5Cevil.com"],
    ["r0 /%09/evil.com", "/%09/evil.com"],
    ["r0 /%0D%0A", "/%0D%0A"],
    ["r0 앞 공백", "%20/ko"],
    ["r0 중간 공백", "/ko%20x"],
    ["r0 /%7F", "/%7F"],
    ["r0 javascript:alert(1)", enc("javascript:alert(1)")],
    ["r0 빈 값", ""],
    ["r1 /..//evil.com", enc("/..//evil.com")],
    ["r1 /.//evil.com", enc("/.//evil.com")],
    ["r1 /a/..//evil.com", enc("/a/..//evil.com")],
    ["r1 /ko/..//evil.com", enc("/ko/..//evil.com")],
    ["r1 디코딩 뒤 /%2e%2e//evil.com", "/%252e%252e//evil.com"],
    ["r1 %00", "/%00"],
    ["r1 2,049자", enc(`/${"a".repeat(2048)}`)],
    ["r2 비ASCII /ko/%ED%95%9C", "/ko/%ED%95%9C"],
    ["r2 깨진 /ko/%E0%A4%A", "/ko/%E0%A4%A"],
    ["r2 깨진 /%", "/%"],
    ["r2 깨진 /%G1", "/%G1"],
    ["r2 + 든 /ko+x", "/ko+x"],
    ['r2 바이트 상한 "×2047', enc(`/${'"'.repeat(2047)}`)],
  ];

  it.each(REJECTED)("G2-2 400 %s — invalid-return-to · pkce 0 · 상류 0", async (_l, rawValue) => {
    const ctx = await setup();
    const out = await run(ctx, "login", get(`/api/auth/login?return_to=${rawValue}`));
    expectProblem(out, 400, "invalid-return-to", "/api/auth/login");
    assertResponseHeaders("login", "body", out.res);
    expect(ctx.up.calls).toHaveLength(0);
    expectLog(out, "login", null, null);
  });

  it("G2-3 return_to 둘 → 400 · detail은 고정 문구(입력에 따라 바뀌지 않는다)", async () => {
    const ctx = await setup();
    const two = await run(ctx, "login", get(`/api/auth/login?return_to=${enc("/a")}&return_to=${enc("/b")}`));
    expectProblem(two, 400, "invalid-return-to", "/api/auth/login");
    const other = await run(ctx, "login", get(`/api/auth/login?return_to=${enc("//evil.example")}`));
    expectProblem(other, 400, "invalid-return-to", "/api/auth/login");
    expect(two.body.detail).toBe(other.body.detail);
    expect(ctx.up.calls).toHaveLength(0);
  });

  it("G2-4 isSameOriginPath — 디코딩 값 규칙(N-8과 무관하게 뜻이 같은 사례만)", async () => {
    const mod = await loadGateway();
    for (const v of ["/", "/ko", "/ko/notes?x=1#y", "/%2F/evil.com"]) {
      expect(mod.isSameOriginPath(v, SITE), v).toBe(true);
    }
    for (const v of [
      "",
      "//evil.com",
      "/\\evil.com",
      "/\t/evil.com",
      "https://evil.com",
      "javascript:alert(1)",
      "/..//evil.com",
      "/a/..//evil.com",
      " /ko",
      "/ko x",
      "/\x7f",
      "/\r\n",
    ]) {
      expect(mod.isSameOriginPath(v, SITE), JSON.stringify(v)).toBe(false);
    }
  });

  it.each([["//evil.com"], ["/..//evil.com"], ["/ko/한"]])(
    "G2-5 callback 재검증 — 봉인 return_to %s → 400 invalid-return-to · 토큰 호출 0 · pkce 삭제",
    async (sealedReturn) => {
      const ctx = await setup();
      const pkce = await sealPkce(ctx, { return_to: sealedReturn });
      const out = await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value));
      expectProblem(out, 400, "invalid-return-to", "/api/auth/callback");
      assertResponseHeaders("callback", "callback-error", out.res);
      expect(ctx.up.calls).toHaveLength(0);
    },
  );
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G3 callback", () => {
  const INVALID_STATE: Array<[string, (ctx: Ctx, good: Pkce) => Promise<Request>]> = [
    ["state 불일치", async (_c, good) => callbackReq(fake("code"), fake("state"), good.value)],
    ["state 없음", async (_c, good) => callbackReq(fake("code"), null, good.value)],
    ["pkce 쿠키 없음", async (_c, good) => callbackReq(fake("code"), good.state, null)],
    [
      "만료(created_at + 301 s)",
      async (c) => {
        const p = await sealPkce(c, { created_at: T0S - 301 });
        return callbackReq(fake("code"), p.state, p.value);
      },
    ],
    ["같은 이름 pkce 쿠키 둘(N-9)", async (_c, good) => callbackReq(fake("code"), good.state, [good.value, good.value])],
    ["변조된 pkce", async (_c, good) => callbackReq(fake("code"), good.state, tamper(good.value, "ciphertext"))],
    [
      "typ jt-session으로 봉인",
      async (c) => {
        const p = await sealPkce(c, {}, "jt-session");
        return callbackReq(fake("code"), p.state, p.value);
      },
    ],
  ];

  it.each(INVALID_STATE)("G3-1 %s → 400 invalid-state · 토큰 0 · pkce 삭제(Path=/)", async (_l, build) => {
    const ctx = await setup();
    const good = await sealPkce(ctx);
    const out = await run(ctx, "callback", await build(ctx, good));
    expectProblem(out, 400, "invalid-state", "/api/auth/callback");
    assertResponseHeaders("callback", "callback-error", out.res);
    expect(ctx.up.calls).toHaveLength(0);
  });

  // 시계는 정수 초(T0)에 둔다 — 초 미만 자리는 C4가 정하지 않아 고정하지 않는다(리뷰 A-10 — `>=` 구현을 잡는 경계).
  it("G3-1b 만료 경계(C4 「created_at + 300 s를 넘으면」) — 정확히 300 s는 유효(코드 교환 · 302) · 301 s는 400 invalid-state", async () => {
    const ctx = await setup();
    ctx.up.on("token-code", codeTokens(ctx, idClaims(ctx)).reply);
    const edge = await sealPkce(ctx, { created_at: T0S - 300 });
    const atEdge = await run(ctx, "callback", callbackReq(fake("code"), edge.state, edge.value));
    expect(atEdge.status, "created_at + 300 s exactly is still valid").toBe(302);
    assertResponseHeaders("callback", "callback-302", atEdge.res, { location: "/ko" });
    expect(ctx.up.count("token-code")).toBe(1);
    const late = await sealPkce(ctx, { created_at: T0S - 301 });
    const expired = await run(ctx, "callback", callbackReq(fake("code"), late.state, late.value));
    expectProblem(expired, 400, "invalid-state", "/api/auth/callback");
    assertResponseHeaders("callback", "callback-error", expired.res);
    expect(ctx.up.count("token-code"), "no token call for the expired pkce").toBe(1);
  });

  it("G3-2 성공 — 코드 교환 본문 키 정확 6 · C7 · 세션 평문 C3 · CSRF 32 hex · pkce 삭제 · 302 = 봉인 값 · identity-admin 0", async () => {
    const ctx = await setup();
    const pkce = await startLogin(ctx, enc("/ko/notes?x=1#y"));
    const id = idClaims(ctx);
    const { tokens, reply } = codeTokens(ctx, id);
    ctx.up.on("token-code", reply);
    const code = fake("code");
    const out = await run(ctx, "callback", callbackReq(code, pkce.state, pkce.value));
    expect(out.status).toBe(302);
    const cookies = assertResponseHeaders("callback", "callback-302", out.res, { location: "/ko/notes?x=1#y" });
    expect(ctx.up.kinds()).toEqual(["token-code"]);
    const [rec] = ctx.up.ofKind("token-code");
    expect(`${rec.origin}${rec.pathname}`).toBe(TOKEN_URL);
    expect(rec.headers["content-type"]).toMatch(/^application\/x-www-form-urlencoded/);
    expect(rec.headers.accept).toContain("application/json");
    expect(formKeys(rec)).toEqual(["client_id", "client_secret", "code", "code_verifier", "grant_type", "redirect_uri"]);
    expect(rec.form?.get("grant_type")).toBe("authorization_code");
    expect(rec.form?.get("code")).toBe(code);
    expect(rec.form?.get("redirect_uri")).toBe(`${SITE}/api/auth/callback`);
    expect(rec.form?.get("code_verifier")).toBe(pkce.verifier);
    expect(rec.form?.get("client_id")).toBe(ctx.env.WEB_BFF_CLIENT_ID);
    expect(rec.form?.get("client_secret")).toBe(ctx.env.WEB_BFF_CLIENT_SECRET);
    const session = await unseal(keyOf(ctx), cookieNamed(cookies, SESSION_COOKIE)?.value as string);
    expect(session.header).toEqual({ alg: "dir", enc: "A256GCM", typ: "jt-session" });
    expect(session.payload).toEqual({
      refresh_token: tokens.refresh,
      sub: id.sub,
      sid: id.sid,
      tenant_id: id.tenant_id,
      issued_at: id.iat,
      email: id.email,
      name: id.name,
    });
    expect(cookieNamed(cookies, CSRF_COOKIE)?.value).toMatch(HEX32);
    expectLog(out, "callback", "authentik", null);
  });

  it("G3-2b ID 토큰에 email · name이 없으면 세션 평문에도 없다(키 정확 5)", async () => {
    const ctx = await setup();
    const pkce = await startLogin(ctx);
    const id = idClaims(ctx);
    delete id.email;
    delete id.name;
    const { tokens, reply } = codeTokens(ctx, id);
    ctx.up.on("token-code", reply);
    const out = await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value));
    const cookies = assertResponseHeaders("callback", "callback-302", out.res, { location: "/" });
    const session = await unseal(keyOf(ctx), cookieNamed(cookies, SESSION_COOKIE)?.value as string);
    expect(session.payload).toEqual({
      refresh_token: tokens.refresh,
      sub: id.sub,
      sid: id.sid,
      tenant_id: id.tenant_id,
      issued_at: id.iat,
    });
  });

  it("G3-2c (N-8) 봉인 /%2F/evil.com은 다시 디코딩하지 않는다 → 302 같은 값", async () => {
    const ctx = await setup();
    const pkce = await startLogin(ctx, "/%252F/evil.com");
    ctx.up.on("token-code", codeTokens(ctx, idClaims(ctx)).reply);
    const out = await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value));
    expect(out.status).toBe(302);
    assertResponseHeaders("callback", "callback-302", out.res, { location: "/%2F/evil.com" });
  });

  it.each([
    ["302", empty(302)],
    ["500", html(500)],
    ["503 problem", problemReply(503, "upstream")],
  ] as Array<[string, Reply]>)("G3-3 코드 교환 %s → 503 · 세션 쿠키 0 · pkce 삭제", async (_l, reply) => {
    const ctx = await setup();
    const pkce = await startLogin(ctx);
    ctx.up.on("token-code", reply);
    const out = await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value));
    expectProblem(out, 503, "upstream-unavailable", "/api/auth/callback");
    assertResponseHeaders("callback", "callback-error", out.res);
    expect(ctx.up.count("token-code")).toBe(1);
  });

  const BAD_CLAIMS: Array<[string, (c: Record<string, unknown>, ctx: Ctx) => void]> = [
    ["aud 다른 값", (c) => {
      c.aud = fake("other-client");
    }],
    ["iss 다른 값", (c) => {
      c.iss = `${AUTH_ORIGIN}/application/o/other/`;
    }],
    ["지난 exp", (c) => {
      c.exp = T0S - 60;
    }],
    ["정수 아닌 iat", (c) => {
      c.iat = T0S - 0.5;
    }],
    ["문자열 iat", (c) => {
      c.iat = String(T0S - 5);
    }],
    ["uuid 아닌 tenant_id", (c) => {
      c.tenant_id = fake("tenant");
    }],
    ["sub 빈 값", (c) => {
      c.sub = "";
    }],
    ["sub 공백", (c) => {
      c.sub = `${fake("a")} b`;
    }],
    ["sub 256자", (c) => {
      c.sub = "s".repeat(256);
    }],
    ["sid 없음", (c) => {
      delete c.sid;
    }],
    ["sid 빈 값", (c) => {
      c.sid = "";
    }],
    ["sid 공백", (c) => {
      c.sid = `${fake("a")} b`;
    }],
    ["sid 256자", (c) => {
      c.sid = "s".repeat(256);
    }],
  ];

  it.each(BAD_CLAIMS)("G3-4 C19 위반 %s → 503 · 세션 쿠키 0 · pkce 삭제(N-15)", async (_l, mutate) => {
    const ctx = await setup();
    const pkce = await startLogin(ctx);
    const id = idClaims(ctx);
    mutate(id, ctx);
    ctx.up.on("token-code", codeTokens(ctx, id).reply);
    const out = await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value));
    expectProblem(out, 503, "upstream-unavailable", "/api/auth/callback");
    assertResponseHeaders("callback", "callback-error", out.res);
    expect(ctx.up.count("token-code")).toBe(1);
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G4 JWE 쿠키(C3 · C5)", () => {
  it("G4-1 callback 세션 쿠키 꼴 — 같은 평문 두 봉인의 IV · 암호문 다름 · 평문 바늘 0 · Set-Cookie 줄 < 4096", async () => {
    const ctx = await setup();
    const id = idClaims(ctx, {
      sub: randomHex(32),
      sid: randomHex(32),
      email: `${randomHex(24)}@example.test`,
      name: `${fake("name")} ${fake("n")}`.replaceAll(" ", "-"),
    });
    const tokens = { access: fake("at"), refresh: randomHex(64), idToken: fakeJwt(id) };
    const body = { access_token: tokens.access, refresh_token: tokens.refresh, id_token: tokens.idToken, token_type: "Bearer", expires_in: 300 };
    ctx.up.on("token-code", [json(200, body), json(200, body)]);
    const values: string[] = [];
    for (let i = 0; i < 2; i += 1) {
      const pkce = await startLogin(ctx);
      const out = await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value));
      const c = cookieNamed(assertResponseHeaders("callback", "callback-302", out.res, { location: "/" }), SESSION_COOKIE);
      expect((c?.line ?? "").length).toBeLessThan(4096);
      values.push(c?.value as string);
    }
    const [a, b] = values;
    for (const v of values) {
      const parts = splitCompact(v);
      expect(parts).toHaveLength(5);
      expect(parts[2]).toMatch(/^[A-Za-z0-9_-]{16}$/);
      for (const needle of [tokens.refresh, id.sub as string, id.sid as string]) {
        expect(hasNeedle(v, needle)).toBe(false);
      }
    }
    const [oa, ob] = [await unseal(keyOf(ctx), a), await unseal(keyOf(ctx), b)];
    expect(oa.payload).toEqual(ob.payload);
    expect(oa.ivB64).not.toBe(ob.ivB64);
    expect(oa.ciphertextB64).not.toBe(ob.ciphertextB64);
  });

  const INVALID_COOKIES: Array<[string, (ctx: Ctx, c: Claims, value: string) => Promise<string>]> = [
    ["암호문 변조", async (_x, _c, v) => tamper(v, "ciphertext")],
    ["태그 변조", async (_x, _c, v) => tamper(v, "tag")],
    ["IV 변조", async (_x, _c, v) => tamper(v, "iv")],
    ["보호 헤더 변조(같은 뜻 · 다른 바이트)", async (_x, _c, v) => tamper(v, "header")],
    ["다른 키", async (_x, c) => seal(randomHex(32), "jt-session", c)],
    ["접두 없음", async (_x, _c, v) => v.slice(3)],
    ["v2. 접두", async (_x, _c, v) => `v2.${v.slice(3)}`],
    ["alg A256KW", async (x, c) => seal(keyOf(x), "jt-session", c, { header: { alg: "A256KW", enc: "A256GCM", typ: "jt-session" } })],
    ["enc A128GCM", async (x, c) => seal(keyOf(x), "jt-session", c, { header: { alg: "dir", enc: "A128GCM", typ: "jt-session" } })],
    ["typ jt-pkce", async (x, c) => seal(keyOf(x), "jt-pkce", c)],
    ["보호 헤더 키 더함(kid)", async (x, c) => seal(keyOf(x), "jt-session", c, { header: { alg: "dir", enc: "A256GCM", typ: "jt-session", kid: "k1" } })],
    ["평문 키 더함", async (x, c) => seal(keyOf(x), "jt-session", { ...c, x: 1 })],
    [
      "sid 없음",
      async (x, c) => {
        const { sid: _sid, ...rest } = c;
        return seal(keyOf(x), "jt-session", rest);
      },
    ],
  ];

  it.each(INVALID_COOKIES)("G4-2 무효 쿠키 %s → /api/session 401 session-revoked · 두 쿠키 삭제 · 상류 0", async (_l, mutate) => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const bad = await mutate(ctx, s.claims, s.value);
    const out = await run(ctx, "session", get("/api/session", { cookie: cookieHeader([[SESSION_COOKIE, bad], [CSRF_COOKIE, s.csrf]]) }));
    expectProblem(out, 401, "session-revoked", "/api/session");
    assertResponseHeaders("session", "session-deleted", out.res);
    expect(ctx.up.calls).toHaveLength(0);
  });

  it("G4-3 같은 이름 __Host-jt_session 둘(B-6) → 무효 · 401 · 두 쿠키 삭제 · 상류 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const out = await run(ctx, "session", sessionReq(null, [["cookie", cookieOf(s, [[SESSION_COOKIE, s.value]])]]));
    expectProblem(out, 401, "session-revoked", "/api/session");
    assertResponseHeaders("session", "session-deleted", out.res);
    expect(ctx.up.calls).toHaveLength(0);
  });

  /** G4-4 요청 — 쿠키 헤더를 그대로 싣고, 상태 변경 라우트(refresh · logout)는 x-csrf-token을 주어진 값으로 맞춘다. */
  function namedCookieReq(route: "session" | "proxy" | "refresh" | "logout", cookie: string, csrf: string): Request {
    if (route === "session") return get("/api/session", { cookie });
    if (route === "proxy") return get(PROXY_ME, { cookie });
    return post(ROUTE_PATH[route], { cookie, csrf });
  }

  // 리뷰 B-3: 옛 이름 무시(B-6 · C5)를 세션 쿠키를 쓰는 네 라우트 모두에 고정한다(라우트마다 옛 이름을 대신 읽는 구현을 잡는다).
  it.each([["session"], ["proxy"], ["refresh"], ["logout"]] as Array<["session" | "proxy" | "refresh" | "logout"]>)(
    "G4-4 %s — 옛 이름만(jt_session=유효 JWE · jt_csrf + 맞는 x-csrf-token) → 쿠키 없음과 같다(401 · Set-Cookie 0 · 상류 0) · 옛 이름(다른 유효 세션) + 새 이름 → 새 이름만 읽는다",
    async (route) => {
      const ctx = await setup();
      const issued = standard(ctx);
      const s = await mintSession(ctx);
      const legacyOnly = cookieHeader([[LEGACY_SESSION_COOKIE, s.value], [LEGACY_CSRF_COOKIE, s.csrf]]);
      const out = await run(ctx, route, namedCookieReq(route, legacyOnly, s.csrf));
      expectProblem(out, 401, "session-revoked", route === "proxy" ? PROXY_ME : ROUTE_PATH[route]);
      if (route === "logout") {
        assertResponseHeaders("logout", "logout-no-cookie", out.res, { endSession: true });
        expectEndSession(ctx, out.res);
      } else {
        assertResponseHeaders(route, "body", out.res);
      }
      expect(ctx.up.calls).toHaveLength(0);

      const other = await mintSession(ctx);
      const both = cookieOf(s, [[LEGACY_SESSION_COOKIE, other.value], [LEGACY_CSRF_COOKIE, other.csrf]]);
      const read = await run(ctx, route, namedCookieReq(route, both, s.csrf));
      expect(read.status).toBe(route === "session" || route === "proxy" ? 200 : 204);
      const checks = ctx.up.ofKind("check");
      expect(checks).toHaveLength(1);
      expect(checks[0].query.get("sub"), "the check uses the __Host- session").toBe(s.claims.sub);
      expect(checks[0].query.get("sid")).toBe(s.claims.sid);
      if (route === "session") expect(read.body.sub).toBe(s.claims.sub);
      if (route === "proxy") expect(ctx.up.ofKind("pod")[0].headers["x-forwarded-user-sub"]).toBe(s.claims.sub);
      if (route === "refresh") await expectRotated(ctx, read, s, issued.refresh[0]);
      if (route === "logout") expect(ctx.up.ofKind("sessions-revoke")[0].json).toEqual(revokeBody(s, null));
    },
  );
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
/** 폐기 확인의 「판정 아님」(200 + boolean active만 판정 — web.md :29 · bff-api.md :48) — G5-4 · G11-8 */
const NON_VERDICT: Array<[string, () => Reply]> = [
  ["400 problem", () => problemReply(400, "validation-error")],
  ["403 problem(access_required)", () => problemReply(403, "access-required")],
  ["401 text/html", () => html(401)],
  ["302", () => empty(302)],
  ["500", () => html(500)],
  ["503 problem(denylist-unavailable)", () => problemReply(503, "denylist-unavailable")],
  ["깨진 JSON", () => raw(200, '{"active":', "application/json")],
  ["{}", () => json(200, {})],
  ['{"active":"false"}', () => json(200, { active: "false" })],
  ['{"active":null}', () => json(200, { active: null })],
];

describe("G5 /session/check(폐기 확인 · 2 s 캐시)", () => {
  it("G5-1 URL · 질의 키 정확 {sub, iat, sid} · no-store · manual · C8 값 · active → C18 · 토큰 · pod 호출 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const out = await run(ctx, "session", sessionReq(s));
    expect(out.status).toBe(200);
    assertResponseHeaders("session", "body", out.res);
    expect(mediaType(out.res)).toBe("application/json");
    expect(out.body).toEqual({
      sub: s.claims.sub,
      tenant_id: s.claims.tenant_id,
      email: s.claims.email,
      name: s.claims.name,
      exp: s.claims.issued_at + SESSION_MAX_AGE,
    });
    expect(ctx.up.kinds()).toEqual(["check"]);
    const [rec] = ctx.up.ofKind("check");
    expect(`${rec.origin}${rec.pathname}`).toBe(`${M2M}/session/check`);
    expect([...rec.query.keys()].sort()).toEqual(["iat", "sid", "sub"]);
    expect(rec.query.get("sub")).toBe(s.claims.sub);
    expect(rec.query.get("iat")).toBe(String(s.claims.issued_at));
    expect(rec.query.get("sid")).toBe(s.claims.sid);
    expect(rec.cache).toBe("no-store");
    expect(rec.redirect).toBe("manual");
    expect(rec.headers["cf-access-client-id"]).toBe(ctx.env.CF_ACCESS_CLIENT_ID);
    expect(rec.headers["cf-access-client-secret"]).toBe(ctx.env.CF_ACCESS_CLIENT_SECRET);
    expect(rec.headers["x-forwarded-user-sub"]).toBe(s.claims.sub);
    expect(rec.headers["x-request-id"]).toBe(out.res.headers.get("x-request-id"));
    expect(rec.headers.traceparent).toMatch(TRACEPARENT);
    expect(rec.headers.accept).toContain("application/json");
    expectLog(out, "session", "identity-admin", null);
  });

  it("G5-2 캐시 — 1999 ms 적중 · 2000 ms 재조회", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    expect((await run(ctx, "session", sessionReq(s))).status).toBe(200);
    ctx.clock.t = T0 + 1999;
    expect((await run(ctx, "session", sessionReq(s))).status).toBe(200);
    expect(ctx.up.count("check")).toBe(1);
    ctx.clock.t = T0 + 2000;
    expect((await run(ctx, "session", sessionReq(s))).status).toBe(200);
    expect(ctx.up.count("check")).toBe(2);
  });

  it.each([["sub"], ["issued_at"], ["sid"]] as Array<[keyof Claims]>)("G5-3 %s만 다름 → 별도 키(확인 다시)", async (field) => {
    const ctx = await setup();
    standard(ctx);
    const base = claims();
    const a = await mintSession(ctx, base);
    const changed = field === "issued_at" ? base.issued_at - 1 : fake(field);
    const b = await mintSession(ctx, { ...base, [field]: changed });
    expect((await run(ctx, "session", sessionReq(a))).status).toBe(200);
    expect((await run(ctx, "session", sessionReq(b))).status).toBe(200);
    expect(ctx.up.count("check")).toBe(2);
    expect((await run(ctx, "session", sessionReq(a))).status).toBe(200);
    expect(ctx.up.count("check")).toBe(2);
  });

  it.each(NON_VERDICT)("G5-4 판정 아님 %s → 503 · Set-Cookie 0 · refresh · 교환 0 · 캐시 0", async (_l, reply) => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("check", reply());
    const s = await mintSession(ctx);
    const out = await run(ctx, "session", sessionReq(s));
    expectProblem(out, 503, "upstream-unavailable", "/api/session");
    assertResponseHeaders("session", "body", out.res);
    expect(ctx.up.count("check")).toBe(1);
    const again = await run(ctx, "session", sessionReq(s));
    expect(again.status).toBe(503);
    expect(ctx.up.count("check")).toBe(2);
    expect(ctx.up.kinds()).toEqual(["check", "check"]);
  });

  it.each([["refresh"], ["proxy"]] as Array<["refresh" | "proxy"]>)(
    "G5-5 %s도 판정 아님(500) → 503 · 쿠키 유지(Set-Cookie 0) · 회전 0 · 토큰 호출 0",
    async (route) => {
      const ctx = await setup();
      standard(ctx);
      ctx.up.on("check", html(500));
      const s = await mintSession(ctx);
      const out = await run(ctx, route, route === "refresh" ? refreshReq(s) : proxyReq(s));
      expect(out.status).toBe(503);
      expectProblem(out, 503, "upstream-unavailable", route === "refresh" ? "/api/auth/refresh" : "/api/proxy/identity-admin/tenants/me");
      assertResponseHeaders(route, "body", out.res);
      expect(ctx.up.kinds()).toEqual(["check"]);
    },
  );
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G6 inactive", () => {
  async function inactiveCase(route: "session" | "refresh" | "proxy", rfc7009: Reply | null): Promise<void> {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("check", json(200, { active: false }));
    if (rfc7009) ctx.up.on("rfc7009", rfc7009);
    const s = await mintSession(ctx);
    const request = route === "session" ? sessionReq(s) : route === "refresh" ? refreshReq(s) : proxyReq(s);
    const instance = route === "proxy" ? "/api/proxy/identity-admin/tenants/me" : ROUTE_PATH[route];
    const start = () => run(ctx, route, request);
    const out = rfc7009 && "hang" in rfc7009 ? await expectTimeoutAt3s(ctx, "rfc7009", start) : await start();
    expectProblem(out, 401, "session-revoked", instance);
    assertResponseHeaders(route, "session-deleted", out.res);
    expect(ctx.up.kinds()).toEqual(["check", "rfc7009"]);
    const [rec] = ctx.up.ofKind("rfc7009");
    expect(`${rec.origin}${rec.pathname}`).toBe(REVOKE_URL);
    expect(formKeys(rec)).toEqual(["client_id", "client_secret", "token", "token_type_hint"]);
    expect(rec.form?.get("token")).toBe(s.claims.refresh_token);
    expect(rec.form?.get("token_type_hint")).toBe("refresh_token");
    expect(rec.form?.get("client_id")).toBe(ctx.env.WEB_BFF_CLIENT_ID);
    expect(rec.form?.get("client_secret")).toBe(ctx.env.WEB_BFF_CLIENT_SECRET);
  }

  it.each([["session"], ["refresh"], ["proxy"]] as Array<["session" | "refresh" | "proxy"]>)(
    "G6-1 %s — inactive → RFC 7009(쿠키 refresh) → 두 쿠키 삭제 → 401 · refresh · 교환 0",
    async (route) => {
      await inactiveCase(route, null);
    },
  );

  it.each([["session"], ["proxy"]] as Array<["session" | "proxy"]>)("G6-2 %s — RFC 7009가 500이어도 같다", async (route) => {
    await inactiveCase(route, html(500));
  });

  it("G6-3 RFC 7009가 시간 초과여도 같다(3 s 뒤 401 · 삭제)", async () => {
    await inactiveCase("session", HANG);
  });

  it("G6-4 active /api/session — email · name이 쿠키에 없으면 null · exp = issued_at + 2592000 · 토큰 호출 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx, {}, ["email", "name"]);
    const out = await run(ctx, "session", sessionReq(s));
    expect(out.status).toBe(200);
    expect(out.body).toEqual({
      sub: s.claims.sub,
      tenant_id: s.claims.tenant_id,
      email: null,
      name: null,
      exp: s.claims.issued_at + SESSION_MAX_AGE,
    });
    expect(ctx.up.kinds()).toEqual(["check"]);
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G7 교환(RFC 8693 impersonation · C10 · C11 · C13)", () => {
  it("G7-1 첫 프록시 — 확인 → refresh → 교환 → pod · 교환 본문 키 정확 6 · actor_token 0 · Bearer · 회전 쿠키(C10) · exchanged", async () => {
    const ctx = await setup();
    const issued = standard(ctx);
    const s = await mintSession(ctx);
    const out = await run(ctx, "proxy", proxyReq(s));
    expect(out.status).toBe(200);
    assertResponseHeaders("proxy", "rotated", out.res);
    expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "pod"]);
    const [refresh] = ctx.up.ofKind("token-refresh");
    expect(formKeys(refresh)).toEqual(["client_id", "client_secret", "grant_type", "refresh_token"]);
    expect(refresh.form?.get("grant_type")).toBe("refresh_token");
    expect(refresh.form?.get("refresh_token")).toBe(s.claims.refresh_token);
    const [ex] = ctx.up.ofKind("token-exchange");
    expect(`${ex.origin}${ex.pathname}`).toBe(TOKEN_URL);
    expect(formKeys(ex)).toEqual(["audience", "client_id", "client_secret", "grant_type", "subject_token", "subject_token_type"]);
    expect(ex.form?.get("grant_type")).toBe(GRANT_EXCHANGE);
    expect(ex.form?.get("subject_token")).toBe(issued.access[0]);
    expect(ex.form?.get("subject_token_type")).toBe(TOKEN_TYPE_ACCESS);
    expect(ex.form?.get("audience")).toBe("identity-admin");
    expect(ex.form?.get("client_id")).toBe(ctx.env.WEB_BFF_CLIENT_ID);
    expect(ex.form?.get("client_secret")).toBe(ctx.env.WEB_BFF_CLIENT_SECRET);
    expect(ex.form?.has("actor_token")).toBe(false);
    const [pod] = ctx.up.ofKind("pod");
    expect(pod.url).toBe(`${M2M}/tenants/me`);
    expect(pod.headers.authorization).toBe(`Bearer ${issued.exchanged[0]}`);
    expect(pod.headers["cf-access-client-id"]).toBe(ctx.env.CF_ACCESS_CLIENT_ID);
    expect(pod.headers["cf-access-client-secret"]).toBe(ctx.env.CF_ACCESS_CLIENT_SECRET);
    expect(pod.headers["x-forwarded-user-sub"]).toBe(s.claims.sub);
    await expectRotated(ctx, out, s, issued.refresh[0]);
    expectLog(out, "proxy", "identity-admin", "exchanged");
  });

  it("G7-2 2 s 안 둘째 요청 — 확인 0 · 교환 0 · cache_hit / 2.5 s — 확인 1 · 교환 0", async () => {
    const ctx = await setup();
    standard(ctx);
    let s = await mintSession(ctx);
    const first = await run(ctx, "proxy", proxyReq(s));
    s = follow(s, first);
    ctx.clock.t = T0 + 1000;
    const second = await run(ctx, "proxy", proxyReq(s));
    expect(second.status).toBe(200);
    assertResponseHeaders("proxy", "body", second.res);
    expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "pod", "pod"]);
    expectLog(second, "proxy", "identity-admin", "cache_hit");
    ctx.clock.t = T0 + 2500;
    const third = await run(ctx, "proxy", proxyReq(s));
    expect(third.status).toBe(200);
    expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "pod", "pod", "check", "pod"]);
    expectLog(third, "proxy", "identity-admin", "cache_hit");
  });

  it.each([
    [3600, 269, 270],
    [120, 89, 90],
  ])("G7-3 교환 expires_in %i → %i s 적중 · %i s 미스(min(expires_in, 300) − 30)", async (ttl, hit, miss) => {
    const ctx = await setup();
    standard(ctx, { exchangeTtl: ttl });
    let s = await mintSession(ctx);
    s = follow(s, await run(ctx, "proxy", proxyReq(s)));
    ctx.clock.t = T0 + hit * 1000;
    const atHit = await run(ctx, "proxy", proxyReq(s));
    expect(atHit.status).toBe(200);
    expect(ctx.up.count("token-exchange")).toBe(1);
    expectLog(atHit, "proxy", "identity-admin", "cache_hit");
    ctx.clock.t = T0 + miss * 1000;
    const atMiss = await run(ctx, "proxy", proxyReq(s));
    expect(atMiss.status).toBe(200);
    expect(ctx.up.count("token-exchange")).toBe(2);
    expect(ctx.up.count("token-refresh")).toBe(2);
    expectLog(atMiss, "proxy", "identity-admin", "exchanged");
  });

  it("G7-4 issued_at만 다른 세션 → 교환 캐시 미스", async () => {
    const ctx = await setup();
    standard(ctx);
    const base = claims();
    await run(ctx, "proxy", proxyReq(await mintSession(ctx, base)));
    const other = await run(ctx, "proxy", proxyReq(await mintSession(ctx, { ...base, issued_at: base.issued_at + 1 })));
    expect(other.status).toBe(200);
    expect(ctx.up.count("token-exchange")).toBe(2);
    expectLog(other, "proxy", "identity-admin", "exchanged");
  });

  it("G7-5 refresh 라우트 뒤 그 세션은 미스 · 다른 세션은 적중(그 세션 항목만 — 86-20)", async () => {
    const ctx = await setup();
    standard(ctx);
    let a = await mintSession(ctx);
    let b = await mintSession(ctx);
    a = follow(a, await run(ctx, "proxy", proxyReq(a)));
    b = follow(b, await run(ctx, "proxy", proxyReq(b)));
    expect(ctx.up.count("token-exchange")).toBe(2);
    const refreshed = await run(ctx, "refresh", refreshReq(a));
    expect(refreshed.status).toBe(204);
    a = follow(a, refreshed);
    const againA = await run(ctx, "proxy", proxyReq(a));
    expectLog(againA, "proxy", "identity-admin", "exchanged");
    expect(ctx.up.count("token-exchange")).toBe(3);
    const againB = await run(ctx, "proxy", proxyReq(b));
    expectLog(againB, "proxy", "identity-admin", "cache_hit");
    expect(ctx.up.count("token-exchange")).toBe(3);
  });

  it("G7-6 sub A · B 같은 issued_at → 교환 2회 · 각자 자기 토큰 · B exchanged", async () => {
    const ctx = await setup();
    const issued = standard(ctx);
    const a = await mintSession(ctx, { issued_at: T0S - 60 });
    const b = await mintSession(ctx, { issued_at: T0S - 60 });
    await run(ctx, "proxy", proxyReq(a));
    const outB = await run(ctx, "proxy", proxyReq(b));
    expect(ctx.up.count("token-exchange")).toBe(2);
    const pods = ctx.up.ofKind("pod");
    expect(pods[0].headers.authorization).toBe(`Bearer ${issued.exchanged[0]}`);
    expect(pods[1].headers.authorization).toBe(`Bearer ${issued.exchanged[1]}`);
    expect(pods[1].headers["x-forwarded-user-sub"]).toBe(b.claims.sub);
    expectLog(outB, "proxy", "identity-admin", "exchanged");
  });

  it.each([[400], [403]])("G7-7 교환 %i → 401 exchange-denied · 삭제 0 · 회전 쿠키(C10) · denied · pod 0", async (status) => {
    const ctx = await setup();
    const issued = standard(ctx);
    ctx.up.on("token-exchange", json(status, { error: "invalid_request" }));
    const s = await mintSession(ctx);
    const out = await run(ctx, "proxy", proxyReq(s));
    expectProblem(out, 401, "exchange-denied", "/api/proxy/identity-admin/tenants/me");
    assertResponseHeaders("proxy", "rotated", out.res);
    await expectRotated(ctx, out, s, issued.refresh[0]);
    expect(ctx.up.count("pod")).toBe(0);
    expectLog(out, "proxy", "authentik", "denied");
  });

  it.each([
    ["401", json(401, { error: "invalid_client" })],
    ["500", html(500)],
    ["302", empty(302)],
  ] as Array<[string, Reply]>)("G7-8 교환 %s → 503 · 회전 쿠키(C10) · error · pod 0", async (_l, reply) => {
    const ctx = await setup();
    const issued = standard(ctx);
    ctx.up.on("token-exchange", reply);
    const s = await mintSession(ctx);
    const out = await run(ctx, "proxy", proxyReq(s));
    expectProblem(out, 503, "upstream-unavailable", "/api/proxy/identity-admin/tenants/me");
    assertResponseHeaders("proxy", "rotated", out.res);
    await expectRotated(ctx, out, s, issued.refresh[0]);
    expect(ctx.up.count("pod")).toBe(0);
    expectLog(out, "proxy", "authentik", "error");
  });

  it.each([
    ["없음", undefined],
    ["문자열", "300"],
  ] as Array<[string, unknown]>)("G7-10 교환 expires_in %s → 응답은 중계 · 캐시 0(다음 요청이 다시 교환 — C13)", async (_l, ttl) => {
    const ctx = await setup();
    standard(ctx, { exchangeTtl: ttl });
    let s = await mintSession(ctx);
    const first = await run(ctx, "proxy", proxyReq(s));
    expect(first.status).toBe(200);
    s = follow(s, first);
    ctx.clock.t = T0 + 500;
    const second = await run(ctx, "proxy", proxyReq(s));
    expect(second.status).toBe(200);
    expect(ctx.up.count("token-exchange")).toBe(2);
    expectLog(second, "proxy", "identity-admin", "exchanged");
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
interface HostileClient {
  label: string;
  cookies: Array<[string, string]>;
  headers: Array<[string, string]>;
  needles: Needles;
}

/** G8 적대 클라이언트 라벨(it.each 이름) — 값은 사례마다 hostileClient(ctx)가 실행 중에 만든다(pkce는 그 사례의 키로 봉인). */
const HOSTILE_LABELS: readonly string[] = [
  "cookie CF_Authorization",
  "cookie 옛 이름 jt_session · jt_csrf",
  "cookie __Host-jt_pkce(봉인 · 콜백 밖 — N-9 Path=/)",
  "authorization",
  "cf-access-client-id",
  "cf-access-client-secret",
  "cf-access-jwt-assertion",
  "cf-access-token",
  "x-forwarded-user-sub",
  "traceparent",
  "tracestate",
  "x-request-id",
];

/** 들어온 세션 · CSRF 쿠키 값 바늘(G8 하류 · G13 로그 · 응답 — 리뷰 B-2). */
function sessionNeedles(s: Session): Needles {
  return { "incoming __Host-jt_session": s.value, "incoming __Host-jt_csrf": s.csrf };
}

/**
 * 콜백 밖 요청에 실려 온 pkce 쿠키(N-9 `Path=/` — 최대 300 s 같은 origin 요청마다)의 바늘: 쿠키 값 · 봉인 평문 verifier · state.
 * login도 예외가 없다 — login은 state를 새로 만든다(C4). 들어온 state가 새 authorize Location에 실리면 재사용 결함이다.
 */
function pkceNeedles(p: Pkce): Needles {
  return { "incoming __Host-jt_pkce": p.value, "incoming pkce verifier": p.verifier, "incoming pkce state": p.state };
}

async function hostileClient(ctx: Ctx): Promise<HostileClient[]> {
  const n = (label: string) => fake(label);
  const trace = randomHex(16);
  const cfAuth = n("client-cf-authorization");
  const legacy = n("legacy-session");
  const legacyCsrf = n("legacy-csrf");
  const bearer = n("client-bearer");
  const pkce = await sealPkce(ctx);
  const items: HostileClient[] = [
    { label: "cookie CF_Authorization", cookies: [["CF_Authorization", cfAuth]], headers: [], needles: { CF_Authorization: cfAuth } },
    {
      label: "cookie 옛 이름 jt_session · jt_csrf",
      cookies: [[LEGACY_SESSION_COOKIE, legacy], [LEGACY_CSRF_COOKIE, legacyCsrf]],
      headers: [],
      needles: { "legacy jt_session": legacy, "legacy jt_csrf": legacyCsrf },
    },
    {
      label: "cookie __Host-jt_pkce(봉인 · 콜백 밖 — N-9 Path=/)",
      cookies: [[PKCE_COOKIE, pkce.value]],
      headers: [],
      needles: pkceNeedles(pkce),
    },
    { label: "authorization", cookies: [], headers: [["authorization", `Bearer ${bearer}`]], needles: { authorization: bearer } },
  ];
  for (const h of ["cf-access-client-id", "cf-access-client-secret", "cf-access-jwt-assertion", "cf-access-token", "x-forwarded-user-sub"]) {
    const v = n(`client-${h}`);
    items.push({ label: h, cookies: [], headers: [[h, v]], needles: { [h]: v } });
  }
  const ts = n("client-tracestate");
  const rid = n("client-request-id");
  items.push(
    { label: "traceparent", cookies: [], headers: [["traceparent", `00-${trace}-${randomHex(8)}-01`]], needles: { "client trace-id": trace } },
    { label: "tracestate", cookies: [], headers: [["tracestate", `jt=${ts}`]], needles: { tracestate: ts } },
    { label: "x-request-id", cookies: [], headers: [["x-request-id", rid]], needles: { "client x-request-id": rid } },
  );
  return items;
}

describe("G8 하류 헤더(C8) · 클라이언트 헤더 비전달", () => {
  it.each(HOSTILE_LABELS.map((l) => [l]))(
    "G8-1 클라이언트 %s 바늘 + 들어온 세션 · CSRF 쿠키 값 → 프록시 전 경로의 하류 · 로그 · 응답 0",
    async (label) => {
      const ctx = await setup();
      standard(ctx);
      const s = await mintSession(ctx);
      const item = (await hostileClient(ctx)).find((i) => i.label === label);
      expect(item, "hostileClient item for this label").toBeDefined();
      const { cookies, headers } = item as HostileClient;
      const needles: Needles = { ...(item as HostileClient).needles, ...sessionNeedles(s) };
      const out = await run(ctx, "proxy", proxyReq(null, "/tenants/me", [["cookie", cookieOf(s, cookies)], ...headers]));
      expect(out.status).toBe(200);
      expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "pod"]);
      expectNoNeedlesDownstream(ctx, needles);
      expectNoNeedles(ctx, [out], needles);
      expect(out.res.headers.get("x-request-id")).toMatch(UUID_V4);
    },
  );

  it("G8-2 섞어서 — 프록시 · logout · health · /api/session의 하류 · 로그 · 응답 0(들어온 세션 · CSRF · pkce 쿠키 값 포함) · 하류 헤더 이름 C8 정확", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const all = await hostileClient(ctx);
    expect(all.map((i) => i.label)).toEqual(HOSTILE_LABELS);
    const extraCookies = all.flatMap((i) => i.cookies);
    const headers = all.flatMap((i) => i.headers);
    const needles = Object.assign({}, ...all.map((i) => i.needles), sessionNeedles(s)) as Needles;
    const withCookie: Array<[string, string]> = [["cookie", cookieOf(s, extraCookies)], ...headers];
    const outs = [
      await run(ctx, "proxy", proxyReq(null, "/tenants/me", withCookie)),
      await run(ctx, "session", sessionReq(null, withCookie)),
      await run(ctx, "health", get("/api/health", { headers: withCookie })),
      await run(ctx, "logout", logoutReq(s, null, { cookie: cookieOf(s, extraCookies), headers })),
    ];
    expect(outs.map((o) => o.status)).toEqual([200, 200, 200, 204]);
    expect(new Set(ctx.up.kinds())).toEqual(new Set(["check", "token-refresh", "token-exchange", "pod", "health", "sessions-revoke", "rfc7009"]));
    expectNoNeedlesDownstream(ctx, needles);
    expectNoNeedles(ctx, outs, needles, []);
  });

  // 검증 V1-1: G8-2는 한 인스턴스를 공유해 /api/session 다리가 2 s 확인 캐시에, logout 다리의 확인 · refresh · 교환이 확인 ·
  // 교환 캐시에 적중한다(그 다리들의 하류 0). refresh 라우트는 하류 바늘 사례에 없었다. 라우트마다 새 인스턴스(캐시 공유 0)로
  // 그 라우트의 하류 호출을 실제로 내게 하고(종류 · 순서 정확 — 공허 0), 들어온 세션 · CSRF · pkce 쿠키 값(+ 봉인 평문
  // verifier · state)과 적대 클라이언트 값이 하류 · 로그 · 응답에 0인지 본다.
  it.each([
    ["session", 200, ["check"], "body"],
    ["refresh", 204, ["check", "token-refresh"], "rotated"],
    ["logout", 204, ["check", "token-refresh", "token-exchange", "sessions-revoke", "rfc7009"], "logout-deleted"],
  ] as Array<["session" | "refresh" | "logout", number, CallKind[], Outcome]>)(
    "G8-3 [%s] 새 인스턴스(캐시 0) — 세션 · CSRF + 적대 쿠키(CF_Authorization · 옛 이름 · pkce) · 적대 헤더(+ 맞는 CSRF) → 하류 호출 있음 · 하류 · 로그 · 응답 0",
    async (route, status, kinds, outcome) => {
      const ctx = await setup();
      standard(ctx);
      const s = await mintSession(ctx);
      const all = await hostileClient(ctx);
      expect(all.map((i) => i.label)).toEqual(HOSTILE_LABELS);
      const cookie = cookieOf(s, all.flatMap((i) => i.cookies));
      const headers = all.flatMap((i) => i.headers);
      const needles = Object.assign({}, ...all.map((i) => i.needles), sessionNeedles(s)) as Needles;
      expect(Object.keys(needles), "needles carry the incoming session · CSRF · pkce values (V1-1)").toEqual(
        expect.arrayContaining([
          "incoming __Host-jt_session",
          "incoming __Host-jt_csrf",
          "incoming __Host-jt_pkce",
          "incoming pkce verifier",
          "incoming pkce state",
        ]),
      );
      const request =
        route === "session"
          ? get(ROUTE_PATH.session, { cookie, headers })
          : post(ROUTE_PATH[route], { cookie, csrf: s.csrf, headers });
      const out = await run(ctx, route, request);
      expect(out.status, `${route} status`).toBe(status);
      expect(ctx.up.kinds(), `${route} downstream kinds (fresh instance — no cache hit)`).toEqual(kinds);
      expectNoNeedlesDownstream(ctx, needles);
      expectNoNeedles(ctx, [out], needles);
      assertResponseHeaders(route, outcome, out.res, { endSession: route === "logout" });
    },
  );
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
function hostileNeedles(ctx: Ctx): Needles {
  return {
    "upstream set-cookie": ctx.up.hostile.cookie,
    "upstream location": ctx.up.hostile.location,
    "upstream x-request-id": ctx.up.hostile.requestId,
    "upstream cf-ray": ctx.up.hostile.cfRay,
  };
}

const PROXY_ME = "/api/proxy/identity-admin/tenants/me";

interface TimedCase {
  kind: CallKind;
  route: RouteName;
  build(ctx: Ctx): Promise<Request>;
  verify(ctx: Ctx, out: Out): void;
}

/** 상류 종류마다 「그 호출이 실패하면」의 라우트 결과(G9 · G13-9) */
function timedCases(): Array<[string, TimedCase]> {
  return [
    [
      "[session] check",
      {
        kind: "check",
        route: "session",
        build: async (ctx) => sessionReq(await mintSession(ctx)),
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", "/api/session");
          assertResponseHeaders("session", "body", out.res);
          expect(ctx.up.kinds()).toEqual(["check"]);
        },
      },
    ],
    [
      "[refresh] token-refresh",
      {
        kind: "token-refresh",
        route: "refresh",
        build: async (ctx) => refreshReq(await mintSession(ctx)),
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", "/api/auth/refresh");
          assertResponseHeaders("refresh", "body", out.res);
          expect(ctx.up.kinds()).toEqual(["check", "token-refresh"]);
        },
      },
    ],
    [
      "[proxy] token-exchange",
      {
        kind: "token-exchange",
        route: "proxy",
        build: async (ctx) => proxyReq(await mintSession(ctx)),
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", PROXY_ME);
          assertResponseHeaders("proxy", "rotated", out.res);
          expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange"]);
        },
      },
    ],
    [
      "[proxy] pod",
      {
        kind: "pod",
        route: "proxy",
        build: async (ctx) => proxyReq(await mintSession(ctx)),
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", PROXY_ME);
          assertResponseHeaders("proxy", "rotated", out.res);
          expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "pod"]);
        },
      },
    ],
    [
      "[health] health",
      {
        kind: "health",
        route: "health",
        build: async () => get("/api/health"),
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", "/api/health");
          assertResponseHeaders("health", "body", out.res);
          expect(ctx.up.kinds()).toEqual(["health"]);
        },
      },
    ],
    [
      "[logout] sessions-revoke",
      {
        kind: "sessions-revoke",
        route: "logout",
        build: async (ctx) => logoutReq(await mintSession(ctx)),
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", "/api/auth/logout");
          assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
          expectEndSession(ctx, out.res);
          expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "sessions-revoke", "rfc7009"]);
        },
      },
    ],
    [
      "[logout] rfc7009(202 뒤)",
      {
        kind: "rfc7009",
        route: "logout",
        build: async (ctx) => logoutReq(await mintSession(ctx)),
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", "/api/auth/logout");
          assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
          expectEndSession(ctx, out.res);
          expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "sessions-revoke", "rfc7009"]);
        },
      },
    ],
    [
      "[callback] token-code",
      {
        kind: "token-code",
        route: "callback",
        build: async (ctx) => {
          const pkce = await startLogin(ctx);
          return callbackReq(fake("code"), pkce.state, pkce.value);
        },
        verify: (ctx, out) => {
          expectProblem(out, 503, "upstream-unavailable", "/api/auth/callback");
          assertResponseHeaders("callback", "callback-error", out.res);
          expect(ctx.up.kinds()).toEqual(["token-code"]);
        },
      },
    ],
  ];
}

describe("G9 상류 3 s(C14 · VD-T089-2)", () => {
  const CASES = timedCases();

  it.each(CASES)("G9-1 %s — 매달린 상류: 2999 ms 미결 · 3000 ms 503 · 호출 1 · abort", async (_l, c) => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on(c.kind, HANG);
    const request = await c.build(ctx);
    const out = await expectTimeoutAt3s(ctx, c.kind, () => run(ctx, c.route, request));
    expect(ctx.up.count(c.kind)).toBe(1);
    c.verify(ctx, out);
  });

  const STALL: CallKind[] = ["check", "token-refresh", "token-exchange", "pod", "health", "token-code"];
  it.each(CASES.filter(([, c]) => STALL.includes(c.kind)))("G9-2 %s — 헤더 뒤 본문 정지: 3000 ms 503", async (_l, c) => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on(c.kind, stall(200, "application/json", '{"a":'));
    const request = await c.build(ctx);
    const out = await expectTimeoutAt3s(ctx, c.kind, () => run(ctx, c.route, request));
    c.verify(ctx, out);
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
const UNMAPPED_PODS = ["portfolio-core", "constructor", "__proto__", "hasOwnProperty", "toString", "IDENTITY-ADMIN", "identity-admin."];
const PATH_VARIANTS = [
  "/tenants/me/",
  "//me",
  "/Tenants/me",
  "/tenants/me;x=1",
  "/tenants/%6De",
  "/tenants%2Fme",
  "/tenants%2fme",
  "/tenants%5Cme",
  "/tenants/%2E%2E/health",
  "/tenants",
  "/tenants/me/x",
  "/session/check/",
  "/health",
  "/sessions/revoke",
  "",
  "/",
];
const OTHER_METHODS = ["POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"];

describe("G10 프록시(C20 · 중계 · C10)", () => {
  it.each(UNMAPPED_PODS.map((p) => [p]))("G10-1 맵 밖 pod %s → 404 not-found · 상류 0(유효 세션이어도)", async (pod) => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const request = get(`/api/proxy/${pod}/tenants/me`, { cookie: cookieOf(s) });
    const out = await run(ctx, "proxy", request);
    expectProblem(out, 404, "not-found", new URL(request.url).pathname);
    assertResponseHeaders("proxy", "body", out.res);
    expect(ctx.up.calls).toHaveLength(0);
    expectLog(out, "proxy", null, null);
  });

  it.each(PATH_VARIANTS.map((p) => [p === "" ? "(빈 경로)" : p, p]))("G10-2 경로 변형 %s → 404 · 상류 0", async (_l, path) => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const request = get(`/api/proxy/identity-admin${path}`, { cookie: cookieOf(s) });
    const out = await run(ctx, "proxy", request);
    expectProblem(out, 404, "not-found", new URL(request.url).pathname);
    assertResponseHeaders("proxy", "body", out.res);
    expect(ctx.up.calls).toHaveLength(0);
  });

  it.each(OTHER_METHODS.map((m) => [m]))("G10-3 메서드 %s → 404 · 상류 0(세션 · CSRF가 맞아도)", async (method) => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const headers = new Headers({ cookie: cookieOf(s), "x-csrf-token": s.csrf });
    const out = await run(ctx, "proxy", new Request(`${SITE}${PROXY_ME}`, { method, headers }));
    expect(out.status).toBe(404);
    if (method === "HEAD") {
      expect(out.res.headers.get("x-request-id")).toMatch(UUID_V4);
      expect(out.res.headers.get("cache-control")).toBe("no-store");
      expect(out.res.headers.get("x-content-type-options")).toBe("nosniff");
      expect(out.cookies).toEqual([]);
    } else {
      expectProblem(out, 404, "not-found", PROXY_ME);
      assertResponseHeaders("proxy", "body", out.res);
    }
    expect(ctx.up.calls).toHaveLength(0);
  });

  it("G10-4 /tenants/me?x=1&sub=… → 상류 URL = 맵 base + 상수(클라이언트 질의 0)", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const out = await run(ctx, "proxy", proxyReq(s, `/tenants/me?x=1&sub=${fake("other")}`));
    expect(out.status).toBe(200);
    expect(ctx.up.ofKind("pod").map((c) => c.url)).toEqual([`${M2M}/tenants/me`]);
  });

  it("G10-5 /session/check?sub=other&iat=1&sid=evil → 세션 값(sub · iat = issued_at · sid)으로 다시 만든다", async () => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("pod", json(200, { active: true }));
    const s = await mintSession(ctx);
    const out = await run(ctx, "proxy", proxyReq(s, `/session/check?sub=${fake("other")}&iat=1&sid=evil`));
    expect(out.status).toBe(200);
    expect(out.body).toEqual({ active: true });
    const pods = ctx.up.ofKind("pod");
    expect(pods).toHaveLength(1);
    expect(`${pods[0].origin}${pods[0].pathname}`).toBe(`${M2M}/session/check`);
    expect([...pods[0].query.keys()].sort()).toEqual(["iat", "sid", "sub"]);
    expect(pods[0].query.get("sub")).toBe(s.claims.sub);
    expect(pods[0].query.get("iat")).toBe(String(s.claims.issued_at));
    expect(pods[0].query.get("sid")).toBe(s.claims.sid);
    expect(pods[0].headers.authorization).toMatch(/^Bearer /);
  });

  const RELAY: Array<[string, Reply, number]> = [
    ["200 application/json", json(200, { tenant_id: randomUUID(), name: "t" }), 200],
    ["200 application/json; charset=utf-8", json(200, { ok: 1 }, "application/json; charset=utf-8"), 200],
    ["401 problem+json", problemReply(401, "session-revoked"), 401],
    ["404 problem+json", problemReply(404, "not-found"), 404],
  ];

  it.each(RELAY)("G10-6 중계 %s → 상태 · 본문 · content-type 그대로 · 삭제 0 · 회전 쿠키 · 상류 적대 헤더 0", async (_l, reply, status) => {
    const ctx = await setup();
    const issued = standard(ctx);
    ctx.up.on("pod", reply);
    const s = await mintSession(ctx);
    const out = await run(ctx, "proxy", proxyReq(s));
    expect(out.status).toBe(status);
    const sent = reply as { body: string; headers: Array<[string, string]> };
    expect(out.text).toBe(sent.body);
    expect(out.res.headers.get("content-type")).toBe(sent.headers[0][1]);
    assertResponseHeaders("proxy", "rotated", out.res);
    await expectRotated(ctx, out, s, issued.refresh[0]);
    expectNoNeedles(ctx, [out], hostileNeedles(ctx));
    expectLog(out, "proxy", "identity-admin", "exchanged");
  });

  const NO_RELAY: Array<[string, Reply]> = [
    ["200 text/html", html(200)],
    ["204", empty(204)],
    ["302", empty(302)],
    ["404 text/html", html(404)],
    ["400 application/json(problem 아님)", json(400, { error: "x" })],
    ["500 application/json", json(500, { error: "x" })],
    ["530", html(530)],
    ["503 problem+json", problemReply(503, "denylist-unavailable")],
  ];

  it.each(NO_RELAY)("G10-7 중계하지 않음 %s → 503 upstream-unavailable(BFF problem · 쿠키 유지 · 회전 쿠키)", async (_l, reply) => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("pod", reply);
    const s = await mintSession(ctx);
    const out = await run(ctx, "proxy", proxyReq(s));
    expectProblem(out, 503, "upstream-unavailable", PROXY_ME);
    assertResponseHeaders("proxy", "rotated", out.res);
    expectNoNeedles(ctx, [out], hostileNeedles(ctx));
    expectLog(out, "proxy", "identity-admin", "exchanged");
  });

  it("G10-8 세션 쿠키 없음 → 401 · Set-Cookie 0 · 상류 0 / 무효 쿠키 → 401 · 두 쿠키 삭제 · 상류 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const none = await run(ctx, "proxy", proxyReq(null));
    expectProblem(none, 401, "session-revoked", PROXY_ME);
    assertResponseHeaders("proxy", "body", none.res);
    const s = await mintSession(ctx);
    const bad = await run(ctx, "proxy", get(PROXY_ME, { cookie: cookieHeader([[SESSION_COOKIE, tamper(s.value, "tag")], [CSRF_COOKIE, s.csrf]]) }));
    expectProblem(bad, 401, "session-revoked", PROXY_ME);
    assertResponseHeaders("proxy", "session-deleted", bad.res);
    expect(ctx.up.calls).toHaveLength(0);
  });

  it("G10-9 matchProxyRoute — 허용 둘(질의 무관) · 경로 변형 · 맵 밖 pod · GET 밖 메서드 → null", async () => {
    const mod = await loadGateway();
    const base = `${SITE}/api/proxy`;
    expect(mod.matchProxyRoute(`${base}/identity-admin/tenants/me`, "GET")).toEqual({ pod: "identity-admin", path: "/tenants/me" });
    expect(mod.matchProxyRoute(`${base}/identity-admin/session/check?sub=x`, "GET")).toEqual({
      pod: "identity-admin",
      path: "/session/check",
    });
    for (const p of PATH_VARIANTS) {
      expect(mod.matchProxyRoute(new Request(`${base}/identity-admin${p}`).url, "GET"), p).toBeNull();
    }
    for (const pod of UNMAPPED_PODS) {
      expect(mod.matchProxyRoute(`${base}/${pod}/tenants/me`, "GET"), pod).toBeNull();
    }
    for (const m of OTHER_METHODS) {
      expect(mod.matchProxyRoute(`${base}/identity-admin/tenants/me`, m), m).toBeNull();
    }
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
const DEVICE_BODIES: Array<[string, string | null]> = [
  ["본문 없음", null],
  ["{}", "{}"],
  ['{"all_devices":false}', '{"all_devices":false}'],
];
const ALL_DEVICES = '{"all_devices":true}';

function revokeBody(s: Session, body: string | null): Record<string, unknown> {
  return body === ALL_DEVICES
    ? { all_devices: true, reason: "logout_all" }
    : { all_devices: false, reason: "logout", sid: s.claims.sid };
}

describe("G11 logout · refresh · CSRF(C6 · C12 · C22 · C23 · C25)", () => {
  it.each([["logout"], ["refresh"]] as Array<["logout" | "refresh"]>)(
    "G11-1 %s — CSRF 헤더 없음 · 불일치 · CSRF 쿠키 없음 · 옛 이름 jt_csrf만(맞는 헤더) · 32 hex 아님 → 403 csrf-mismatch · 상류 0 · Set-Cookie 0 · end-session 0",
    async (route) => {
      const ctx = await setup();
      standard(ctx);
      const s = await mintSession(ctx);
      const variants: Array<[string, string, string | null]> = [
        ["헤더 없음", cookieOf(s), null],
        ["불일치", cookieOf(s), randomHex(16)],
        ["CSRF 쿠키 없음", cookieHeader([[SESSION_COOKIE, s.value]]), s.csrf],
        // 리뷰 B-3: 옛 이름 CSRF 쿠키는 없는 것과 같다(B-6 · C5) — 헤더가 그 값과 같아도 403.
        ["옛 이름 jt_csrf만 + 맞는 헤더", cookieHeader([[SESSION_COOKIE, s.value], [LEGACY_CSRF_COOKIE, s.csrf]]), s.csrf],
        ["32 hex 아님", cookieHeader([[SESSION_COOKIE, s.value], [CSRF_COOKIE, "abc"]]), "abc"],
      ];
      for (const [label, cookie, header] of variants) {
        const request = route === "logout" ? logoutReq(s, null, { cookie, csrf: header }) : refreshReq(s, header, cookie);
        const out = await run(ctx, route, request);
        expect(out.status, label).toBe(403);
        expectProblem(out, 403, "csrf-mismatch", ROUTE_PATH[route]);
        assertResponseHeaders(route, "body", out.res);
      }
      expect(ctx.up.calls).toHaveLength(0);
    },
  );

  it("G11-2 세션 쿠키 없음(CSRF보다 먼저) — logout 401 · end-session 있음 / refresh 401 · 헤더 0 · 둘 다 Set-Cookie 0 · 상류 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const csrf = randomHex(16);
    for (const withCsrf of [true, false]) {
      const cookie = withCsrf ? cookieHeader([[CSRF_COOKIE, csrf]]) : undefined;
      const lo = await run(ctx, "logout", post("/api/auth/logout", { cookie, csrf: withCsrf ? csrf : null }));
      expectProblem(lo, 401, "session-revoked", "/api/auth/logout");
      assertResponseHeaders("logout", "logout-no-cookie", lo.res, { endSession: true });
      expectEndSession(ctx, lo.res);
      const re = await run(ctx, "refresh", post("/api/auth/refresh", { cookie, csrf: withCsrf ? csrf : null }));
      expectProblem(re, 401, "session-revoked", "/api/auth/refresh");
      assertResponseHeaders("refresh", "body", re.res);
    }
    expect(ctx.up.calls).toHaveLength(0);
  });

  it("G11-3 무효 쿠키 + 유효 CSRF · 본문 → 401 · 두 쿠키 삭제 · end-session · 상류 0 / 순서: CSRF 불일치 403 · 나쁜 본문 400이 먼저(삭제 0)", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const bad: Session = { ...s, value: tamper(s.value, "tag") };
    const out = await run(ctx, "logout", logoutReq(bad));
    expectProblem(out, 401, "session-revoked", "/api/auth/logout");
    assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
    expectEndSession(ctx, out.res);
    const csrfFirst = await run(ctx, "logout", logoutReq(bad, null, { csrf: randomHex(16) }));
    expectProblem(csrfFirst, 403, "csrf-mismatch", "/api/auth/logout");
    assertResponseHeaders("logout", "body", csrfFirst.res);
    const bodyFirst = await run(ctx, "logout", logoutReq(bad, "[]"));
    expectProblem(bodyFirst, 400, "invalid-request", "/api/auth/logout");
    assertResponseHeaders("logout", "body", bodyFirst.res);
    expect(ctx.up.calls).toHaveLength(0);
  });

  const BAD_BODIES = [
    "all_devices=true",
    "   ",
    "[]",
    "null",
    "true",
    '"x"',
    '{"all_devices":"true"}',
    '{"all_devices":1}',
    '{"all_devices":null}',
    '{"all_devices":true,"x":1}',
    '{"x":1}',
  ];

  it.each(BAD_BODIES.map((b) => [JSON.stringify(b), b]))("G11-4 본문 %s → 400 invalid-request · 상류 0 · Set-Cookie 0 · end-session 0", async (_l, body) => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const out = await run(ctx, "logout", logoutReq(s, body));
    expectProblem(out, 400, "invalid-request", "/api/auth/logout");
    assertResponseHeaders("logout", "body", out.res);
    expect(ctx.up.calls).toHaveLength(0);
  });

  it.each(DEVICE_BODIES)(
    "G11-5 이 기기(%s) + active — 확인 → refresh → 교환 → /sessions/revoke(본문 정확) → RFC 7009(새 refresh) → 삭제 → 204",
    async (_l, body) => {
      const ctx = await setup();
      const issued = standard(ctx);
      const s = await mintSession(ctx);
      const out = await run(ctx, "logout", logoutReq(s, body));
      expect(out.status).toBe(204);
      expect(out.text).toBe("");
      assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
      expectEndSession(ctx, out.res);
      expect(ctx.up.kinds()).toEqual(["check", "token-refresh", "token-exchange", "sessions-revoke", "rfc7009"]);
      const [rv] = ctx.up.ofKind("sessions-revoke");
      expect(rv.url).toBe(`${M2M}/sessions/revoke`);
      expect((rv.headers["content-type"] ?? "").split(";")[0].trim()).toBe("application/json");
      expect(rv.headers.authorization).toBe(`Bearer ${issued.exchanged[0]}`);
      expect(rv.json).toEqual({ all_devices: false, reason: "logout", sid: s.claims.sid });
      const [rfc] = ctx.up.ofKind("rfc7009");
      expect(formKeys(rfc)).toEqual(["client_id", "client_secret", "token", "token_type_hint"]);
      expect(rfc.form?.get("token")).toBe(issued.refresh[0]);
      expectLog(out, "logout", "authentik", "exchanged");
    },
  );

  it("G11-6 모든 기기 + active — 본문 정확 {all_devices:true, reason:logout_all}(sid 키 0) · 204 · end-session", async () => {
    const ctx = await setup();
    const issued = standard(ctx);
    const s = await mintSession(ctx);
    const out = await run(ctx, "logout", logoutReq(s, ALL_DEVICES));
    expect(out.status).toBe(204);
    assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
    expectEndSession(ctx, out.res);
    const [rv] = ctx.up.ofKind("sessions-revoke");
    expect(rv.json).toEqual({ all_devices: true, reason: "logout_all" });
    expect(ctx.up.ofKind("rfc7009")[0].form?.get("token")).toBe(issued.refresh[0]);
  });

  it.each([...DEVICE_BODIES, ["모든 기기", ALL_DEVICES]] as Array<[string, string | null]>)(
    "G11-7 inactive(%s) — /sessions/revoke · refresh · 교환 0 · RFC 7009 1 → 삭제 → 이 기기 204 · 모든 기기 401",
    async (_l, body) => {
      const ctx = await setup();
      standard(ctx);
      ctx.up.on("check", json(200, { active: false }));
      const s = await mintSession(ctx);
      const out = await run(ctx, "logout", logoutReq(s, body));
      if (body === ALL_DEVICES) {
        expectProblem(out, 401, "session-revoked", "/api/auth/logout");
      } else {
        expect(out.status).toBe(204);
      }
      assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
      expectEndSession(ctx, out.res);
      expect(ctx.up.kinds()).toEqual(["check", "rfc7009"]);
      expect(ctx.up.ofKind("rfc7009")[0].form?.get("token")).toBe(s.claims.refresh_token);
    },
  );

  it.each([
    ["500", html(500)],
    ["시간 초과", HANG],
  ] as Array<[string, Reply]>)("G11-7b inactive · RFC 7009 %s여도 같다(이 기기 204 · 모든 기기 401)", async (_l, reply) => {
    for (const body of [null, ALL_DEVICES]) {
      const ctx = await setup();
      standard(ctx);
      ctx.up.on("check", json(200, { active: false }));
      ctx.up.on("rfc7009", reply);
      const s = await mintSession(ctx);
      const start = () => run(ctx, "logout", logoutReq(s, body));
      const out = "hang" in reply ? await expectTimeoutAt3s(ctx, "rfc7009", start) : await start();
      expect(out.status).toBe(body === ALL_DEVICES ? 401 : 204);
      assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
      expect(ctx.up.kinds()).toEqual(["check", "rfc7009"]);
    }
  });

  it.each(NON_VERDICT)("G11-8 확인 판정 아님 %s → RFC 7009만 → 삭제 → 503 · end-session", async (_l, reply) => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("check", reply());
    const s = await mintSession(ctx);
    const out = await run(ctx, "logout", logoutReq(s));
    expectProblem(out, 503, "upstream-unavailable", "/api/auth/logout");
    assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
    expectEndSession(ctx, out.res);
    expect(ctx.up.kinds()).toEqual(["check", "rfc7009"]);
    expect(ctx.up.ofKind("rfc7009")[0].form?.get("token")).toBe(s.claims.refresh_token);
  });

  const LOGOUT_FAILURES: Array<[string, CallKind, () => Reply, "new" | "old"]> = [
    ["/sessions/revoke 302", "sessions-revoke", () => empty(302), "new"],
    ["/sessions/revoke 500", "sessions-revoke", () => html(500), "new"],
    ["/sessions/revoke 400", "sessions-revoke", () => problemReply(400, "validation-error"), "new"],
    ["교환 400", "token-exchange", () => json(400, { error: "invalid_request" }), "new"],
    ["교환 403", "token-exchange", () => json(403, { error: "access_denied" }), "new"],
    ["교환 500", "token-exchange", () => html(500), "new"],
    ["교환 302", "token-exchange", () => empty(302), "new"],
    ["내부 refresh 500", "token-refresh", () => html(500), "old"],
    ["내부 refresh 302", "token-refresh", () => empty(302), "old"],
  ];

  function expectLogoutFailure(ctx: Ctx, out: Out, s: Session, body: string | null, rfcToken: string, revokeCalled: boolean): void {
    expectProblem(out, 503, "upstream-unavailable", "/api/auth/logout");
    assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
    expectEndSession(ctx, out.res);
    expect(ctx.up.count("rfc7009")).toBe(1);
    expect(ctx.up.ofKind("rfc7009")[0].form?.get("token")).toBe(rfcToken);
    expect(ctx.up.count("sessions-revoke")).toBe(revokeCalled ? 1 : 0);
    for (const rv of ctx.up.ofKind("sessions-revoke")) {
      expect(rv.json, "this-device request is never widened").toEqual(revokeBody(s, body));
    }
  }

  it.each(LOGOUT_FAILURES)("G11-9 %s → RFC 7009 시도 → 삭제 → 503 · end-session · 넓힌 호출 0(두 범위)", async (_l, kind, reply, which) => {
    for (const body of [null, ALL_DEVICES]) {
      const ctx = await setup();
      const issued = standard(ctx);
      ctx.up.on(kind, reply());
      const s = await mintSession(ctx);
      const out = await run(ctx, "logout", logoutReq(s, body));
      expectLogoutFailure(ctx, out, s, body, which === "new" ? issued.refresh[0] : s.claims.refresh_token, kind === "sessions-revoke");
    }
  });

  it.each([
    ["교환", "token-exchange", "new"],
    ["내부 refresh", "token-refresh", "old"],
  ] as Array<[string, CallKind, "new" | "old"]>)("G11-9b %s 시간 초과 → RFC 7009 시도 → 삭제 → 503 · end-session", async (_l, kind, which) => {
    const ctx = await setup();
    const issued = standard(ctx);
    ctx.up.on(kind, HANG);
    const s = await mintSession(ctx);
    const out = await expectTimeoutAt3s(ctx, kind, () => run(ctx, "logout", logoutReq(s)));
    expectLogoutFailure(ctx, out, s, null, which === "new" ? issued.refresh[0] : s.claims.refresh_token, false);
  });

  it.each([
    ["500", html(500)],
    ["302", empty(302)],
  ] as Array<[string, Reply]>)("G11-10 RFC 7009 %s(active · /sessions/revoke 202 뒤) → 삭제 → 503 · end-session", async (_l, reply) => {
    const ctx = await setup();
    const issued = standard(ctx);
    ctx.up.on("rfc7009", reply);
    const s = await mintSession(ctx);
    const out = await run(ctx, "logout", logoutReq(s));
    expectLogoutFailure(ctx, out, s, null, issued.refresh[0], true);
  });

  it.each([
    ["이 기기", null],
    ["모든 기기", ALL_DEVICES],
  ] as Array<[string, string | null]>)(
    "G11-11 내부 refresh invalid_grant(%s) → /sessions/revoke 0 · 교환 0 · RFC 7009 시도(옛 refresh) → 삭제 → 503(V-B-1 · N-17)",
    async (_l, body) => {
      const ctx = await setup();
      standard(ctx);
      ctx.up.on("token-refresh", json(400, { error: "invalid_grant" }));
      const s = await mintSession(ctx);
      const out = await run(ctx, "logout", logoutReq(s, body));
      expectLogoutFailure(ctx, out, s, body, s.claims.refresh_token, false);
      expect(ctx.up.count("token-exchange")).toBe(0);
    },
  );

  it("G11-12 x-end-session-url 값 — 설정 · 요청 origin뿐(질의 · origin · referer · x-forwarded-host · host · forwarded 무시) · Location 0 · 로그 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const hostile: Array<[string, string]> = [
      ["origin", EVIL_ORIGIN],
      ["referer", `${EVIL_ORIGIN}/x`],
      ["x-forwarded-host", "evil.invalid"],
      ["host", "evil.invalid"],
      ["forwarded", "host=evil.invalid;proto=https"],
    ];
    const query = `?post_logout_redirect_uri=${enc(`${EVIL_ORIGIN}/x`)}&return_to=${enc("//evil.invalid")}`;
    const s1 = await mintSession(ctx);
    const outs: Out[] = [];
    outs.push(await run(ctx, "logout", post(`/api/auth/logout${query}`, { headers: hostile })));
    outs.push(await run(ctx, "logout", logoutReq({ ...s1, value: tamper(s1.value, "tag") }, null, { query, headers: hostile })));
    outs.push(await run(ctx, "logout", logoutReq(s1, null, { query, headers: hostile })));
    ctx.up.on("check", json(200, { active: false }));
    outs.push(await run(ctx, "logout", logoutReq(await mintSession(ctx), null, { query, headers: hostile })));
    ctx.up.on("check", html(500));
    outs.push(await run(ctx, "logout", logoutReq(await mintSession(ctx), null, { query, headers: hostile })));
    expect(outs.map((o) => o.status)).toEqual([401, 401, 204, 204, 503]);
    const values = outs.map((o) => expectEndSession(ctx, o.res));
    expect(new Set(values).size).toBe(1);
    expect(hasNeedle(ctx.logs.join("\n"), values[0]), "x-end-session-url value in logs (C15)").toBe(false);
  });

  it("G11-13 로그아웃 뒤 같은 isolate — 같은 쿠키 사본이 1 s 안에 와도 확인을 다시 한다(캐시 미사용) → inactive → 401 · 교환 캐시 미사용", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    expect((await run(ctx, "session", sessionReq(s))).status).toBe(200);
    const copy = follow(s, await run(ctx, "proxy", proxyReq(s)));
    ctx.clock.t = T0 + 100;
    expect((await run(ctx, "logout", logoutReq(copy))).status).toBe(204);
    const checks = ctx.up.count("check");
    const refreshes = ctx.up.count("token-refresh");
    const exchanges = ctx.up.count("token-exchange");
    const pods = ctx.up.count("pod");
    ctx.up.on("check", json(200, { active: false }));
    ctx.clock.t = T0 + 600;
    const again = await run(ctx, "session", sessionReq(s));
    expectProblem(again, 401, "session-revoked", "/api/session");
    expect(ctx.up.count("check")).toBe(checks + 1);
    ctx.clock.t = T0 + 700;
    const proxied = await run(ctx, "proxy", proxyReq(copy));
    expectProblem(proxied, 401, "session-revoked", PROXY_ME);
    expect(ctx.up.count("token-refresh")).toBe(refreshes);
    expect(ctx.up.count("token-exchange")).toBe(exchanges);
    expect(ctx.up.count("pod")).toBe(pods);
  });

  it("G11-14 refresh 성공 — refresh 본문 키 정확 4 · 새 쿠키(새 refresh · 나머지 그대로 · 새 IV) · CSRF 같은 값 다시 · 204", async () => {
    const ctx = await setup();
    const issued = standard(ctx);
    const s = await mintSession(ctx);
    const out = await run(ctx, "refresh", refreshReq(s));
    expect(out.status).toBe(204);
    expect(out.text).toBe("");
    assertResponseHeaders("refresh", "rotated", out.res);
    expect(ctx.up.kinds()).toEqual(["check", "token-refresh"]);
    const [rec] = ctx.up.ofKind("token-refresh");
    expect(`${rec.origin}${rec.pathname}`).toBe(TOKEN_URL);
    expect(formKeys(rec)).toEqual(["client_id", "client_secret", "grant_type", "refresh_token"]);
    expect(rec.form?.get("refresh_token")).toBe(s.claims.refresh_token);
    expect(rec.form?.get("client_secret")).toBe(ctx.env.WEB_BFF_CLIENT_SECRET);
    await expectRotated(ctx, out, s, issued.refresh[0]);
    expectLog(out, "refresh", "authentik", null);
  });

  it("G11-14b refresh 응답에 refresh_token이 없으면 옛 값을 유지한 새 쿠키(C12)", async () => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("token-refresh", json(200, { access_token: fake("at"), token_type: "Bearer", expires_in: 300 }));
    const s = await mintSession(ctx);
    const out = await run(ctx, "refresh", refreshReq(s));
    expect(out.status).toBe(204);
    assertResponseHeaders("refresh", "rotated", out.res);
    await expectRotated(ctx, out, s, s.claims.refresh_token);
  });

  it("G11-15 refresh invalid_grant → 두 쿠키 삭제 · 401 session-revoked", async () => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("token-refresh", json(400, { error: "invalid_grant" }));
    const s = await mintSession(ctx);
    const out = await run(ctx, "refresh", refreshReq(s));
    expectProblem(out, 401, "session-revoked", "/api/auth/refresh");
    assertResponseHeaders("refresh", "session-deleted", out.res);
    expect(ctx.up.count("token-refresh")).toBe(1);
  });

  it.each([
    ["500", html(500)],
    ["503 problem", problemReply(503, "x")],
    ["302", empty(302)],
    ["400 invalid_request(invalid_grant 아님)", json(400, { error: "invalid_request" })],
  ] as Array<[string, Reply]>)("G11-16 refresh %s → 503 · Set-Cookie 0(쿠키 유지)", async (_l, reply) => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("token-refresh", reply);
    const s = await mintSession(ctx);
    const out = await run(ctx, "refresh", refreshReq(s));
    expectProblem(out, 503, "upstream-unavailable", "/api/auth/refresh");
    assertResponseHeaders("refresh", "body", out.res);
    expect(ctx.up.kinds()).toEqual(["check", "token-refresh"]);
  });

  it("G11-17 refresh inactive → RFC 7009 → 두 쿠키 삭제 → 401 · 재발급 0", async () => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("check", json(200, { active: false }));
    const s = await mintSession(ctx);
    const out = await run(ctx, "refresh", refreshReq(s));
    expectProblem(out, 401, "session-revoked", "/api/auth/refresh");
    assertResponseHeaders("refresh", "session-deleted", out.res);
    expect(ctx.up.kinds()).toEqual(["check", "rfc7009"]);
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G12 상관 · 공통(C9 · C16)", () => {
  it("G12-1 x-request-id — UUID · 요청마다 다름 · 클라이언트 값과 다름 · 하류 = 응답 헤더 = problem request_id = 로그", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const clientId = randomUUID();
    const h: Array<[string, string]> = [["x-request-id", clientId]];
    const outs = [
      await run(ctx, "login", get("/api/auth/login", { headers: h })),
      await run(ctx, "session", sessionReq(s, h)),
      await run(ctx, "proxy", proxyReq(s, "/tenants/me", h)),
      await run(ctx, "proxy", get("/api/proxy/not-a-pod/x", { headers: h })),
      await run(ctx, "health", get("/api/health", { headers: h })),
    ];
    expect(outs.map((o) => o.status)).toEqual([302, 200, 200, 404, 200]);
    const ids = outs.map((o) => o.res.headers.get("x-request-id") as string);
    for (const id of ids) {
      expect(id).toMatch(UUID_V4);
      expect(id).not.toBe(clientId);
    }
    expect(new Set(ids).size).toBe(ids.length);
    outs.forEach((o, i) => expect(o.log.request_id).toBe(ids[i]));
    expect(outs[3].body.request_id).toBe(ids[3]);
    expect(ctx.up.ofKind("check")[0].headers["x-request-id"]).toBe(ids[1]);
    expect(ctx.up.ofKind("pod")[0].headers["x-request-id"]).toBe(ids[2]);
    expect(ctx.up.ofKind("health")[0].headers["x-request-id"]).toBe(ids[4]);
  });

  it.each([
    [true, "01"],
    [false, "00"],
  ])("G12-2 traceparent — sampled %s → %s · 0 아닌 id · 한 요청 같은 trace-id · 로그 trace_id · 요청마다 다름 · 클라이언트 값 무시", async (sampled, flag) => {
    const ctx = await setup({ sampled });
    standard(ctx);
    const s = await mintSession(ctx);
    const clientTrace = randomHex(16);
    const first = await run(ctx, "proxy", proxyReq(s, "/tenants/me", [["traceparent", `00-${clientTrace}-${randomHex(8)}-01`]]));
    const m2m = ctx.up.calls.filter((c) => c.origin === M2M);
    expect(m2m.map((c) => c.kind)).toEqual(["check", "pod"]);
    const traceIds = new Set<string>();
    for (const c of m2m) {
      const m = TRACEPARENT.exec(c.headers.traceparent ?? "");
      expect(m, "traceparent form").not.toBeNull();
      const [, traceId, spanId, f] = m as RegExpExecArray;
      expect(traceId).not.toBe("0".repeat(32));
      expect(spanId).not.toBe("0".repeat(16));
      expect(f).toBe(flag);
      traceIds.add(traceId);
    }
    expect(traceIds.size).toBe(1);
    const [traceId] = [...traceIds];
    expect(traceId).not.toBe(clientTrace);
    expect(first.log.trace_id).toBe(traceId);
    ctx.clock.t = T0 + 5000;
    const second = await run(ctx, "session", sessionReq(follow(s, first)));
    expect(second.status).toBe(200);
    expect(second.log.trace_id).not.toBe(traceId);
    expect(TRACEPARENT.exec(ctx.up.ofKind("check")[1].headers.traceparent ?? "")?.[1]).toBe(second.log.trace_id);
  });

  it("G12-3 공통 — 라우트 × 결과마다 no-store · nosniff · ACAO 0 · instance 질의 0 · 계약 쿠키 이름만 · 상류 적대 헤더 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const outs: Out[] = [
      await run(ctx, "login", get("/api/auth/login?return_to=%2Fko&x=1")),
      await run(ctx, "login", get("/api/auth/login?return_to=%2F%2Fevil.example&x=1")),
      await run(ctx, "session", sessionReq(s)),
      await run(ctx, "session", get("/api/session?x=1")),
      await run(ctx, "proxy", proxyReq(s, "/tenants/me?x=1")),
      await run(ctx, "proxy", get("/api/proxy/not-a-pod/x?y=1")),
      await run(ctx, "health", get("/api/health?z=1")),
      await run(ctx, "refresh", refreshReq(s, randomHex(16))),
      await run(ctx, "callback", get("/api/auth/callback?code=x&state=y")),
      await run(ctx, "logout", logoutReq(s)),
    ];
    expect(outs.map((o) => o.status)).toEqual([302, 400, 200, 401, 200, 404, 200, 403, 400, 204]);
    for (const o of outs) {
      expect(o.res.headers.get("cache-control")).toBe("no-store");
      expect(o.res.headers.get("x-content-type-options")).toBe("nosniff");
      expect(o.res.headers.get("access-control-allow-origin")).toBeNull();
      expect(o.res.headers.has("cf-ray")).toBe(false);
      for (const c of o.cookies) expect([SESSION_COOKIE, CSRF_COOKIE, PKCE_COOKIE]).toContain(c.name);
      if (o.body && typeof o.body.instance === "string") expect(o.body.instance.includes("?")).toBe(false);
    }
    expectNoNeedles(ctx, outs, hostileNeedles(ctx));
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G13 로그 · 마스킹(C15 · bff-api.md :95–:96)", () => {
  it("G13-1 일곱 라우트 — 요청마다 한 줄 JSON · 키 9 정확 · 값 꼴(level · route 템플릿 · upstream · trace_id)", async () => {
    const ctx = await setup();
    standard(ctx);
    const s = await mintSession(ctx);
    const pkce = await startLogin(ctx);
    ctx.up.on("token-code", codeTokens(ctx, idClaims(ctx)).reply);
    const rows: Array<[RouteName, Out]> = [
      ["callback", await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value))],
      ["session", await run(ctx, "session", sessionReq(s))],
      ["proxy", await run(ctx, "proxy", proxyReq(s))],
      ["health", await run(ctx, "health", get("/api/health"))],
      ["refresh", await run(ctx, "refresh", refreshReq(s, randomHex(16)))],
      ["logout", await run(ctx, "logout", logoutReq(s))],
      ["login", await run(ctx, "login", get(`/api/auth/login?return_to=${enc("//x")}`))],
    ];
    expect(rows.map(([, o]) => o.status)).toEqual([302, 200, 200, 200, 403, 204, 400]);
    for (const [route, o] of rows) expectLogForm(o, route);
    expect(ctx.logs).toHaveLength(8);
  });

  it("G13-2 경로별 upstream · exchange_result", async () => {
    const ctx = await setup();
    standard(ctx);
    let s = await mintSession(ctx);
    expectLog(await run(ctx, "login", get("/api/auth/login")), "login", null, null);
    expectLog(await run(ctx, "session", sessionReq(s)), "session", "identity-admin", null);
    const first = await run(ctx, "proxy", proxyReq(s));
    expectLog(first, "proxy", "identity-admin", "exchanged");
    s = follow(s, first);
    expectLog(await run(ctx, "proxy", proxyReq(s)), "proxy", "identity-admin", "cache_hit");
    expectLog(await run(ctx, "proxy", get("/api/proxy/not-a-pod/x")), "proxy", null, null);
    expectLog(await run(ctx, "health", get("/api/health")), "health", "identity-admin", null);
    const refreshed = await run(ctx, "refresh", refreshReq(s));
    expectLog(refreshed, "refresh", "authentik", null);
    s = follow(s, refreshed);
    expectLog(await run(ctx, "logout", logoutReq(s)), "logout", "authentik", "exchanged");
  });

  it("G13-3 [login] 바늘 0 — 질의 code · state · 들어온 쿠키(세션 · CSRF · 앞선 pkce · 옛 이름) · 자격 헤더 · env 비밀 · 자기 pkce 쿠키(302 · 400)", async () => {
    const ctx = await setup();
    const s = await mintSession(ctx);
    const incoming = await sealPkce(ctx);
    const code = fake("code");
    const state = fake("state");
    const bearer = fake("bearer");
    const cfAuth = fake("cf-authorization");
    const cfId = fake("cf-access-id");
    const cfSecret = fake("cf-access-secret");
    const legacy = fake("legacy-session");
    const headers: Array<[string, string]> = [
      ["cookie", cookieOf(s, [["CF_Authorization", cfAuth], [LEGACY_SESSION_COOKIE, legacy], [PKCE_COOKIE, incoming.value]])],
      ["authorization", `Bearer ${bearer}`],
      ["cf-access-client-id", cfId],
      ["cf-access-client-secret", cfSecret],
    ];
    const ok = await run(ctx, "login", get(`/api/auth/login?return_to=%2Fko&code=${code}&state=${state}`, { headers }));
    const bad = await run(ctx, "login", get(`/api/auth/login?return_to=%2F%2Fevil.example&code=${code}&state=${state}`, { headers }));
    expect(ok.status).toBe(302);
    expectProblem(bad, 400, "invalid-return-to", "/api/auth/login");
    expectNoNeedles(ctx, [ok, bad], {
      code,
      state,
      authorization: bearer,
      CF_Authorization: cfAuth,
      "cf-access-client-id": cfId,
      "cf-access-client-secret": cfSecret,
      "legacy jt_session": legacy,
      ...sessionNeedles(s),
      ...pkceNeedles(incoming),
      ...envSecretNeedles(ctx.env),
    });
  });

  it("G13-4 [callback-revalidate] 바늘 0 — 재검증 400 · 질의 code · state · 들어온 pkce 쿠키 · verifier", async () => {
    const ctx = await setup();
    const pkce = await sealPkce(ctx, { return_to: "/..//evil.com" });
    const code = fake("code");
    const out = await run(ctx, "callback", callbackReq(code, pkce.state, pkce.value));
    expectProblem(out, 400, "invalid-return-to", "/api/auth/callback");
    expectNoNeedles(ctx, [out], {
      code,
      state: pkce.state,
      "incoming __Host-jt_pkce": pkce.value,
      verifier: pkce.verifier,
      ...envSecretNeedles(ctx.env),
    });
  });

  it("G13-5 [callback] 바늘 0 — 성공 302 · 토큰 응답 · id_token · 원문 sub · sid · 상류 적대 헤더", async () => {
    const ctx = await setup();
    const pkce = await startLogin(ctx);
    const id = idClaims(ctx);
    const { tokens, reply } = codeTokens(ctx, id);
    ctx.up.on("token-code", reply);
    const code = fake("code");
    const out = await run(ctx, "callback", callbackReq(code, pkce.state, pkce.value));
    expect(out.status).toBe(302);
    expectNoNeedles(ctx, [out], {
      code,
      state: pkce.state,
      "incoming __Host-jt_pkce": pkce.value,
      verifier: pkce.verifier,
      access: tokens.access,
      refresh: tokens.refresh,
      id_token: tokens.idToken,
      sub: id.sub as string,
      sid: id.sid as string,
      ...hostileNeedles(ctx),
      ...envSecretNeedles(ctx.env),
    });
  });

  it("G13-6 [proxy] 바늘 0 — 성공(회전 · 교환) · 404(질의 code · state) · 들어온 쿠키(세션 · CSRF · pkce) · 토큰 · 원문 sub · sid · 상류 적대 헤더", async () => {
    const ctx = await setup();
    const issued = standard(ctx);
    const s = await mintSession(ctx);
    const incoming = await sealPkce(ctx);
    const cookie = cookieOf(s, [[PKCE_COOKIE, incoming.value]]);
    const code = fake("code");
    const state = fake("state");
    const ok = await run(ctx, "proxy", get(`/api/proxy/identity-admin/tenants/me?code=${code}&state=${state}`, { cookie }));
    const nf = await run(ctx, "proxy", get(`/api/proxy/not-a-pod/x?code=${code}&state=${state}`, { cookie }));
    expect(ok.status).toBe(200);
    expectProblem(nf, 404, "not-found", "/api/proxy/not-a-pod/x");
    expectNoNeedles(ctx, [ok, nf], {
      code,
      state,
      ...sessionNeedles(s),
      ...pkceNeedles(incoming),
      "old refresh": s.claims.refresh_token,
      "new refresh": issued.refresh[0],
      access: issued.access[0],
      exchanged: issued.exchanged[0],
      sub: s.claims.sub,
      sid: s.claims.sid,
      ...hostileNeedles(ctx),
      ...envSecretNeedles(ctx.env),
    });
  });

  it("G13-7 [logout] 바늘 0 — active 204 · 세션 쿠키 없음 401(pkce 쿠키만 · 질의 code · state) · 들어온 쿠키(세션 · CSRF · pkce) · end-session 값은 로그 0", async () => {
    const ctx = await setup();
    const issued = standard(ctx);
    const s = await mintSession(ctx);
    const incoming = await sealPkce(ctx);
    const code = fake("code");
    const state = fake("state");
    const query = `?code=${code}&state=${state}`;
    const ok = await run(ctx, "logout", logoutReq(s, null, { query, cookie: cookieOf(s, [[PKCE_COOKIE, incoming.value]]) }));
    const none = await run(ctx, "logout", post(`/api/auth/logout${query}`, { cookie: cookieHeader([[PKCE_COOKIE, incoming.value]]) }));
    expect(ok.status).toBe(204);
    expectProblem(none, 401, "session-revoked", "/api/auth/logout");
    expect(hasNeedle(ctx.logs.join("\n"), expectEndSession(ctx, ok.res))).toBe(false);
    expectNoNeedles(ctx, [ok, none], {
      code,
      state,
      ...sessionNeedles(s),
      ...pkceNeedles(incoming),
      "old refresh": s.claims.refresh_token,
      "new refresh": issued.refresh[0],
      access: issued.access[0],
      exchanged: issued.exchanged[0],
      sub: s.claims.sub,
      sid: s.claims.sid,
      ...hostileNeedles(ctx),
      ...envSecretNeedles(ctx.env),
    });
  });

  it("G13-8 [session · refresh · health] 바늘 0 — 들어온 쿠키(세션 · CSRF · pkce) · /api/session 본문의 sub만 예외", async () => {
    const ctx = await setup();
    const issued = standard(ctx);
    const s = await mintSession(ctx);
    const incoming = await sealPkce(ctx);
    const withPkce = cookieOf(s, [[PKCE_COOKIE, incoming.value]]);
    const session = await run(ctx, "session", get("/api/session", { cookie: withPkce }));
    const refreshed = await run(ctx, "refresh", refreshReq(s, s.csrf, withPkce));
    const health = await run(ctx, "health", get("/api/health", { cookie: cookieHeader([[PKCE_COOKIE, incoming.value]]) }));
    expect([session.status, refreshed.status, health.status]).toEqual([200, 204, 200]);
    const needles: Needles = {
      ...sessionNeedles(s),
      ...pkceNeedles(incoming),
      "old refresh": s.claims.refresh_token,
      "new refresh": issued.refresh[0],
      access: issued.access[0],
      sub: s.claims.sub,
      sid: s.claims.sid,
      ...hostileNeedles(ctx),
      ...envSecretNeedles(ctx.env),
    };
    expectNoNeedles(ctx, [session], needles, ["sub"]);
    expectNoNeedles(ctx, [refreshed, health], needles);
  });

  it.each(timedCases())("G13-9 %s — 주입 fetch TypeError(메시지에 바늘 URL) → 실패 갈래 응답 · reject 0 · 바늘 0", async (_l, c) => {
    const ctx = await setup();
    standard(ctx);
    const needle = fake("typeerror-needle");
    ctx.up.on(c.kind, throwsTypeError(`fetch failed: ${M2M}/x?sub=${needle}&token=${needle}`));
    const out = await run(ctx, c.route, await c.build(ctx));
    expect(ctx.up.count(c.kind)).toBe(1);
    c.verify(ctx, out);
    expectNoNeedles(ctx, [out], { "TypeError message": needle });
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G14 이미지 로더(C21 · FR-030)", () => {
  it("G14-1 cdn 원본 → /cdn-cgi/image/width,quality(기본 75),format=auto,onerror=redirect/<경로> 정확", async () => {
    const { default: imageLoader } = await loadImageLoader();
    expect(imageLoader({ src: `${CDN}/notes/a.png`, width: 640, quality: 80 })).toBe(
      `${CDN}/cdn-cgi/image/width=640,quality=80,format=auto,onerror=redirect/notes/a.png`,
    );
    expect(imageLoader({ src: `${CDN}/notes/a.png`, width: 320 })).toBe(
      `${CDN}/cdn-cgi/image/width=320,quality=75,format=auto,onerror=redirect/notes/a.png`,
    );
  });

  it("G14-2 fallbackSrc(imageLoader(x)) === x.src(변환 오류 시 원본 폴백)", async () => {
    const mod = await loadImageLoader();
    for (const x of [
      { src: `${CDN}/notes/a.png`, width: 640, quality: 80 },
      { src: `${CDN}/p/2026/b.webp`, width: 16 },
    ]) {
      expect(mod.fallbackSrc(mod.default(x))).toBe(x.src);
    }
  });

  it("G14-3 루트 상대 경로는 그대로(저장소 자산 — 빌드 시 변형) · 같은 경로의 cdn 원본은 변환된다(항등 로더 대조 — D12)", async () => {
    const { default: imageLoader } = await loadImageLoader();
    expect(imageLoader({ src: "/images/a.png", width: 640 })).toBe("/images/a.png");
    expect(imageLoader({ src: `${CDN}/images/a.png`, width: 640 })).toBe(
      `${CDN}/cdn-cgi/image/width=640,quality=75,format=auto,onerror=redirect/images/a.png`,
    );
  });

  it("G14-4 다른 호스트 · 접미 속임 · 스킴 상대 → 던진다(cdn 원본 양성과 짝)", async () => {
    const { default: imageLoader } = await loadImageLoader();
    expect(imageLoader({ src: `${CDN}/ok.png`, width: 64 })).toBe(`${CDN}/cdn-cgi/image/width=64,quality=75,format=auto,onerror=redirect/ok.png`);
    for (const src of ["https://evil.example/a.png", "https://cdn.joshuatech.dev.evil.example/a.png", "//evil.example/a.png"]) {
      expect(() => imageLoader({ src, width: 64 }), src).toThrow();
    }
  });

  it("G14-5 변환 URL이 아니면 fallbackSrc → null", async () => {
    const mod = await loadImageLoader();
    expect(mod.fallbackSrc(mod.default({ src: `${CDN}/a.png`, width: 8 }))).toBe(`${CDN}/a.png`);
    for (const url of [`${CDN}/a.png`, "/images/a.png", "https://evil.example/cdn-cgi/image/width=1/x.png"]) {
      expect(mod.fallbackSrc(url), url).toBeNull();
    }
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
describe("G15 /api/health(C17)", () => {
  it("G15-1 GET /health · 200 JSON → 키 정확 {status, upstream, upstream_ms, checks} · checks 정화 · 확인 · 쿠키 0", async () => {
    const ctx = await setup();
    standard(ctx);
    const leak = fake("check-error");
    ctx.up.on(
      "health",
      json(200, {
        status: "degraded",
        version: "1.2.3",
        git_sha: randomHex(20),
        checks: {
          db: { status: "ok", latency_ms: 3, error: leak },
          dragonfly: { status: "fail", latency_ms: 200 },
          "Bad-Name": { status: "ok", latency_ms: 1 },
          [`a${"b".repeat(32)}`]: { status: "ok", latency_ms: 1 },
        },
      }),
    );
    const s = await mintSession(ctx);
    const out = await run(ctx, "health", get("/api/health", { cookie: cookieOf(s) }));
    expect(out.status).toBe(200);
    assertResponseHeaders("health", "body", out.res);
    expect(mediaType(out.res)).toBe("application/json");
    expect(Object.keys(out.body).sort()).toEqual(["checks", "status", "upstream", "upstream_ms"]);
    expect(out.body.status).toBe("degraded");
    expect(out.body.upstream).toBe("identity-admin");
    expect(Number.isInteger(out.body.upstream_ms) && out.body.upstream_ms >= 0).toBe(true);
    expect(out.body.checks).toEqual({ db: { status: "ok", latency_ms: 3 }, dragonfly: { status: "fail", latency_ms: 200 } });
    expect(ctx.up.kinds()).toEqual(["health"]);
    const [rec] = ctx.up.ofKind("health");
    expect(rec.url).toBe(`${M2M}/health`);
    expect(rec.headers["cf-access-client-id"]).toBe(ctx.env.CF_ACCESS_CLIENT_ID);
    expect(rec.headers["x-request-id"]).toBe(out.res.headers.get("x-request-id"));
    expectNoNeedles(ctx, [out], { "check error": leak, ...hostileNeedles(ctx) });
    expectLog(out, "health", "identity-admin", null);
  });

  it("G15-2 상류 ok → status ok · checks 셋", async () => {
    const ctx = await setup();
    standard(ctx);
    const out = await run(ctx, "health", get("/api/health"));
    expect(out.status).toBe(200);
    expect(out.body.status).toBe("ok");
    expect(Object.keys(out.body.checks).sort()).toEqual(["db", "dragonfly", "kafka_producer"]);
  });

  const BAD_HEALTH: Array<[string, Reply]> = [
    ["302", empty(302)],
    ["403 text/html", html(403)],
    ["500", html(500)],
    ["200 text/html", html(200)],
    ["깨진 JSON", raw(200, '{"status":', "application/json")],
    ['status "weird"', json(200, { status: "weird", checks: {} })],
    ["status 없음", json(200, { checks: {} })],
  ];

  it.each(BAD_HEALTH)("G15-3 %s → 503 · 상류 set-cookie 0 · 호출 1", async (_l, reply) => {
    const ctx = await setup();
    standard(ctx);
    ctx.up.on("health", reply);
    const out = await run(ctx, "health", get("/api/health"));
    expectProblem(out, 503, "upstream-unavailable", "/api/health");
    assertResponseHeaders("health", "body", out.res);
    expect(ctx.up.kinds()).toEqual(["health"]);
    expectNoNeedles(ctx, [out], hostileNeedles(ctx));
  });
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
function envCases(): Array<[string, string, string | undefined]> {
  return [
    ["키 62자", "SESSION_ENCRYPTION_KEY", randomHex(31)],
    ["키 66자", "SESSION_ENCRYPTION_KEY", randomHex(33)],
    ["키 16진 아님", "SESSION_ENCRYPTION_KEY", `${randomHex(31)}zz`],
    ["키 없음", "SESSION_ENCRYPTION_KEY", undefined],
    ["CF_ACCESS_CLIENT_ID .access 없음", "CF_ACCESS_CLIENT_ID", randomHex(16)],
    ["CF_ACCESS_CLIENT_ID 31 hex", "CF_ACCESS_CLIENT_ID", `${randomHex(16).slice(1)}.access`],
    ["WEB_BFF_CLIENT_SECRET 빈 값", "WEB_BFF_CLIENT_SECRET", ""],
    ["WEB_BFF_CLIENT_SECRET 끝 줄바꿈", "WEB_BFF_CLIENT_SECRET", `${fake("w")}\n`],
    ["CF_ACCESS_CLIENT_SECRET 빈 값", "CF_ACCESS_CLIENT_SECRET", ""],
    ["IDENTITY_M2M_URL 경로", "IDENTITY_M2M_URL", `${M2M}/x`],
    ["IDENTITY_M2M_URL 끝 /", "IDENTITY_M2M_URL", `${M2M}/`],
    ["IDENTITY_M2M_URL http:", "IDENTITY_M2M_URL", M2M.replace("https:", "http:")],
    ["IDENTITY_M2M_URL 사용자 정보", "IDENTITY_M2M_URL", "https://" + fake("u") + ":" + fake("p") + "@m2m.example.test"],
    ["IDENTITY_M2M_URL 질의", "IDENTITY_M2M_URL", `${M2M}?x=1`],
    ["AUTHENTIK_ISSUER http:", "AUTHENTIK_ISSUER", ISSUER.replace("https:", "http:")],
    [
      "AUTHENTIK_ISSUER 사용자 정보",
      "AUTHENTIK_ISSUER",
      "https://" + fake("u") + ":" + fake("p") + "@auth.example.test/application/o/web-bff-test/",
    ],
    ["AUTHENTIK_ISSUER ?x", "AUTHENTIK_ISSUER", `${ISSUER}?x`],
    ["AUTHENTIK_ISSUER #x", "AUTHENTIK_ISSUER", `${ISSUER}#x`],
    ["AUTHENTIK_ISSUER 끝 / 없음", "AUTHENTIK_ISSUER", ISSUER.slice(0, -1)],
    ["WEB_BFF_CLIENT_ID 빈 값", "WEB_BFF_CLIENT_ID", ""],
  ];
}

const INVALID_INSTANCES: Array<[string, (env: Env) => void, boolean]> = [
  [
    "(a) 키만 무효 — 종료 설정 유효",
    (env) => {
      env.SESSION_ENCRYPTION_KEY = randomHex(31);
    },
    true,
  ],
  [
    "(b) AUTHENTIK_ISSUER 무효",
    (env) => {
      env.AUTHENTIK_ISSUER = ISSUER.replace("https:", "http:");
    },
    false,
  ],
  // 리뷰 A-10: C23 「둘 다 유효할 때만」의 다른 반쪽 — issuer만 보는 구현 · 이름이 있는지만 보는 구현(빈 값 통과)을 잡는다.
  [
    "(c) WEB_BFF_CLIENT_ID만 무효(빈 값) — AUTHENTIK_ISSUER 유효",
    (env) => {
      env.WEB_BFF_CLIENT_ID = "";
    },
    false,
  ],
];

async function invalidSetup(mutate: (env: Env) => void): Promise<Ctx> {
  const env = baseEnv();
  mutate(env);
  return await setup({ env });
}

describe("G16 env(C26 · N-5)", () => {
  it.each(envCases())("G16-1 validateEnv %s → [그 이름] 하나만(유효 env는 [])", async (_l, name, value) => {
    const mod = await loadGateway();
    const env = baseEnv();
    expect(mod.validateEnv(env)).toEqual([]);
    const bad: Env = { ...env };
    if (value === undefined) delete bad[name];
    else bad[name] = value;
    expect(mod.validateEnv(bad)).toEqual([name]);
  });

  it("G16-2 createGateway({}, deps)는 던지지 않는다 — /api/session 503 · 맵 밖 프록시 404 · 상류 0", async () => {
    const ctx = await setup({ env: {} });
    const out = await run(ctx, "session", get("/api/session"));
    expectProblem(out, 503, "upstream-unavailable", "/api/session");
    const nf = await run(ctx, "proxy", get("/api/proxy/not-a-pod/x"));
    expectProblem(nf, 404, "not-found", "/api/proxy/not-a-pod/x");
    expect(ctx.up.calls).toHaveLength(0);
  });

  it.each(INVALID_INSTANCES)("G16-3 %s — proxy 맵 판정은 env 없이 404 · 맵을 지나면 503 · 상류 0", async (_l, mutate) => {
    const ctx = await invalidSetup(mutate);
    const s = { value: await seal(randomHex(32), "jt-session", claims()), csrf: randomHex(16) };
    const cookie = cookieHeader([[SESSION_COOKIE, s.value], [CSRF_COOKIE, s.csrf]]);
    const nf = await run(ctx, "proxy", get("/api/proxy/not-a-pod/x", { cookie }));
    expectProblem(nf, 404, "not-found", "/api/proxy/not-a-pod/x");
    assertResponseHeaders("proxy", "body", nf.res);
    const mapped = await run(ctx, "proxy", get(PROXY_ME, { cookie }));
    expectProblem(mapped, 503, "upstream-unavailable", PROXY_ME);
    assertResponseHeaders("proxy", "body", mapped.res);
    expect(ctx.up.calls).toHaveLength(0);
    expectLog(mapped, "proxy", null, null);
  });

  it.each(INVALID_INSTANCES)(
    "G16-4 %s — login · callback(pkce 삭제 — N-5) · refresh · session · health → 503 · end-session 0 · 상류 0 · 로그 1(유효 설정 대조 302 · 200)",
    async (_l, mutate) => {
      const valid = await setup();
      standard(valid);
      expect((await run(valid, "login", get("/api/auth/login"))).status).toBe(302);
      expect((await run(valid, "session", sessionReq(await mintSession(valid)))).status).toBe(200);

      const ctx = await invalidSetup(mutate);
      const value = await seal(randomHex(32), "jt-session", claims());
      const csrf = randomHex(16);
      const cookie = cookieHeader([[SESSION_COOKIE, value], [CSRF_COOKIE, csrf]]);
      const pkce = await seal(randomHex(32), "jt-pkce", { state: "s", verifier: "v", return_to: "/", created_at: T0S });
      const cases: Array<[RouteName, Request]> = [
        ["login", get("/api/auth/login")],
        ["callback", callbackReq(fake("code"), "s", pkce)],
        ["refresh", post("/api/auth/refresh", { cookie, csrf })],
        ["session", get("/api/session", { cookie })],
        ["health", get("/api/health")],
      ];
      for (const [route, request] of cases) {
        const out = await run(ctx, route, request);
        expectProblem(out, 503, "upstream-unavailable", ROUTE_PATH[route as Exclude<RouteName, "proxy">]);
        assertResponseHeaders(route, route === "callback" ? "callback-error" : "body", out.res);
        expectLog(out, route, null, null);
      }
      expect(ctx.up.calls).toHaveLength(0);
    },
  );

  it.each(INVALID_INSTANCES)(
    "G16-5 %s — logout: 쿠키 없음 401 · CSRF 불일치 403 · 유효 본문 → 두 쿠키 삭제 · 503(end-session은 종료 설정이 유효할 때만) · 상류 0",
    async (_l, mutate, endSessionValid) => {
      const ctx = await invalidSetup(mutate);
      const value = await seal(randomHex(32), "jt-session", claims());
      const csrf = randomHex(16);
      const cookie = cookieHeader([[SESSION_COOKIE, value], [CSRF_COOKIE, csrf]]);
      const none = await run(ctx, "logout", post("/api/auth/logout", { cookie: cookieHeader([[CSRF_COOKIE, csrf]]), csrf }));
      expectProblem(none, 401, "session-revoked", "/api/auth/logout");
      assertResponseHeaders("logout", "logout-no-cookie", none.res, { endSession: endSessionValid });
      if (endSessionValid) expectEndSession(ctx, none.res);
      const mismatch = await run(ctx, "logout", post("/api/auth/logout", { cookie, csrf: randomHex(16) }));
      expectProblem(mismatch, 403, "csrf-mismatch", "/api/auth/logout");
      assertResponseHeaders("logout", "body", mismatch.res);
      const deleted = await run(ctx, "logout", post("/api/auth/logout", { cookie, csrf, body: "{}" }));
      expectProblem(deleted, 503, "upstream-unavailable", "/api/auth/logout");
      assertResponseHeaders("logout", "logout-deleted", deleted.res, { endSession: endSessionValid });
      if (endSessionValid) expectEndSession(ctx, deleted.res);
      expectLog(deleted, "logout", null, null);
      expect(ctx.up.calls).toHaveLength(0);
    },
  );
});

// ════════════════════════════════════════════════════════════════════════════════════════════════════════
type G17Route = "callback" | "refresh" | "proxy-refresh" | "proxy-exchange" | "logout-refresh" | "logout-exchange";

function brokenReplies(label: G17Route, ctx: Ctx, needle: string): Array<[string, Reply]> {
  const base = (): Record<string, unknown> => ({ access_token: fake("at"), refresh_token: fake("rt"), token_type: "Bearer", expires_in: 300 });
  const withId = (extra: Record<string, unknown>): Record<string, unknown> => ({ ...base(), id_token: fakeJwt(idClaims(ctx)), ...extra });
  const shape = label === "callback" ? withId : (extra: Record<string, unknown>) => ({ ...base(), ...extra });
  const rows: Array<[string, Reply]> = [
    ["200 text/html(앞에 토큰 바늘)", html(200, `<html>${needle}</html>`)],
    ["200 깨진 JSON", raw(200, `{"access_token":"${needle}`, "application/json")],
    ["access_token 숫자", json(200, shape({ access_token: 12345 }))],
  ];
  if (label === "callback") {
    const [h, p] = fakeJwt(idClaims(ctx)).split(".");
    rows.push(["id_token 두 조각", json(200, shape({ id_token: `${h}.${p}` }))]);
    rows.push(["id_token base64url 아님", json(200, shape({ id_token: `${h}.not*base64url!.${p}` }))]);
  }
  if (label === "callback" || label.endsWith("refresh")) {
    rows.push(["expires_in 문자열", json(200, shape({ expires_in: "300" }))]);
  }
  return rows;
}

describe("G17 꼴이 깨진 200 · reject 0(V-B-4)", () => {
  const ROWS: G17Route[] = ["callback", "refresh", "proxy-refresh", "proxy-exchange", "logout-refresh", "logout-exchange"];
  const KIND: Record<G17Route, CallKind> = {
    callback: "token-code",
    refresh: "token-refresh",
    "proxy-refresh": "token-refresh",
    "proxy-exchange": "token-exchange",
    "logout-refresh": "token-refresh",
    "logout-exchange": "token-exchange",
  };

  it.each(ROWS.map((r) => [r]))("G17-1 %s — 200 + 깨진 본문 · 필드 꼴 오류 각각 → 503(라우트 규칙) · 로그 1 · 바늘 0", async (row) => {
    const probe = await setup();
    const replies = brokenReplies(row, probe, fake("token-needle")).length;
    expect(replies).toBeGreaterThanOrEqual(3);
    for (let i = 0; i < replies; i += 1) {
      const ctx = await setup();
      const issued = standard(ctx);
      const needle = fake("token-needle");
      const [label, reply] = brokenReplies(row, ctx, needle)[i];
      ctx.up.on(KIND[row], reply);
      const s = await mintSession(ctx);
      let out: Out;
      if (row === "callback") {
        const pkce = await startLogin(ctx);
        out = await run(ctx, "callback", callbackReq(fake("code"), pkce.state, pkce.value));
        expectProblem(out, 503, "upstream-unavailable", "/api/auth/callback");
        assertResponseHeaders("callback", "callback-error", out.res);
      } else if (row === "refresh") {
        out = await run(ctx, "refresh", refreshReq(s));
        expectProblem(out, 503, "upstream-unavailable", "/api/auth/refresh");
        assertResponseHeaders("refresh", "body", out.res);
      } else if (row === "proxy-refresh") {
        out = await run(ctx, "proxy", proxyReq(s));
        expectProblem(out, 503, "upstream-unavailable", PROXY_ME);
        assertResponseHeaders("proxy", "body", out.res);
        expect(ctx.up.count("token-exchange"), label).toBe(0);
      } else if (row === "proxy-exchange") {
        out = await run(ctx, "proxy", proxyReq(s));
        expectProblem(out, 503, "upstream-unavailable", PROXY_ME);
        assertResponseHeaders("proxy", "rotated", out.res);
        await expectRotated(ctx, out, s, issued.refresh[0]);
        expect(ctx.up.count("pod"), label).toBe(0);
      } else {
        out = await run(ctx, "logout", logoutReq(s));
        const rfcToken = row === "logout-refresh" ? s.claims.refresh_token : issued.refresh[0];
        expectLogoutFailure503(ctx, out, s, rfcToken);
      }
      expect(ctx.up.count(KIND[row]), label).toBe(1);
      expectNoNeedles(ctx, [out], { "token needle in broken body": needle });
    }
  });
});

/** logout 실패 갈래(G17): 삭제 · 503 · end-session · /sessions/revoke 0 · 넓힌 호출 0 · RFC 7009 시도 */
function expectLogoutFailure503(ctx: Ctx, out: Out, s: Session, rfcToken: string): void {
  expectProblem(out, 503, "upstream-unavailable", "/api/auth/logout");
  assertResponseHeaders("logout", "logout-deleted", out.res, { endSession: true });
  expectEndSession(ctx, out.res);
  expect(ctx.up.count("sessions-revoke")).toBe(0);
  expect(ctx.up.count("rfc7009")).toBe(1);
  expect(ctx.up.ofKind("rfc7009")[0].form?.get("token")).toBe(rfcToken);
  expect(s.claims.sid.length).toBeGreaterThan(0);
}
