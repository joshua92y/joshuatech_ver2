// T089 시험 기반 — 가짜 상류(기록형 라우터 · specs/003-platform-foundation/design/t086-design.md D9-2 · C1 · C8).
//
// - deps.fetch에 넣는 vi.fn: 인자는 Request 하나(아니면 API 위반으로 기록). 부를 때마다 {method, url, headers, body,
//   cache, redirect, signal}을 기록하고 매번 새 Response를 만든다. 처리기 없는 호출 = unexpected(파일 수준 afterEach가 실패시킨다).
// - 모든 응답에 적대 헤더가 기본으로 붙는다: set-cookie CF_Authorization=<바늘> · location https://evil.invalid/<바늘>
//   · cf-ray <바늘> · x-request-id <바늘> · access-control-allow-origin *(hostile: false면 뺀다).
// - 시간 초과 = req.signal abort에서만 거부(HANG) · 본문 정지 = 헤더 뒤 스트림 정지 · abort에서 스트림 오류(stall).
// - 호출 종류(kind)는 메서드 · origin · 경로 · grant_type · Bearer 유무로 가른다(RFC 2606 origin).

import { vi } from "vitest";

import { fake } from "./needles";

export const ISSUER = "https://auth.example.test/application/o/web-bff-test/";
export const AUTH_ORIGIN = "https://auth.example.test";
export const AUTHORIZE_URL = `${AUTH_ORIGIN}/application/o/authorize/`;
export const TOKEN_URL = `${AUTH_ORIGIN}/application/o/token/`;
export const REVOKE_URL = `${AUTH_ORIGIN}/application/o/revoke/`;
export const END_SESSION_URL = `${ISSUER}end-session/`;
export const M2M = "https://m2m.example.test";
export const SITE = "https://site.example.test";
export const EVIL_ORIGIN = "https://evil.invalid";

export const GRANT_CODE = "authorization_code";
export const GRANT_REFRESH = "refresh_token";
export const GRANT_EXCHANGE = "urn:ietf:params:oauth:grant-type:token-exchange";
export const TOKEN_TYPE_ACCESS = "urn:ietf:params:oauth:token-type:access_token";

export type CallKind =
  | "check"
  | "pod"
  | "sessions-revoke"
  | "health"
  | "token-code"
  | "token-refresh"
  | "token-exchange"
  | "rfc7009"
  | "unknown";

export interface Recorded {
  seq: number;
  kind: CallKind;
  method: string;
  url: string;
  origin: string;
  pathname: string;
  query: URLSearchParams;
  /** 소문자 이름 → 값 */
  headers: Record<string, string>;
  headerNames: string[];
  body: string;
  /** application/x-www-form-urlencoded 본문 */
  form: URLSearchParams | null;
  /** JSON 본문(파싱 실패 = undefined) */
  json: unknown;
  cache: string;
  redirect: string;
  signal: AbortSignal;
}

export type Reply =
  | { status: number; headers?: Array<[string, string]>; body?: string | null; hostile?: boolean }
  | { hang: true }
  | { stall: { status: number; headers: Array<[string, string]>; prefix: string } }
  | { throws: Error };
export type Handler = Reply | ((rec: Recorded) => Reply | Promise<Reply>);

export interface HostileNeedles {
  cookie: string;
  location: string;
  requestId: string;
  cfRay: string;
}

export function json(status: number, value: unknown, contentType = "application/json"): Reply {
  return { status, headers: [["content-type", contentType]], body: JSON.stringify(value) };
}

export function problemReply(status: number, slug: string): Reply {
  return json(
    status,
    { type: `https://joshuatech.dev/problems/${slug}`, title: slug, status, detail: "pod", instance: "/x" },
    "application/problem+json",
  );
}

export function html(status: number, text = "<html><body>edge</body></html>"): Reply {
  return { status, headers: [["content-type", "text/html; charset=utf-8"]], body: text };
}

export function raw(status: number, body: string | null, contentType?: string): Reply {
  return { status, headers: contentType ? [["content-type", contentType]] : [], body };
}

export function empty(status: number): Reply {
  return { status, body: null };
}

export const HANG: Reply = { hang: true };

export function stall(status = 200, contentType = "application/json", prefix = '{"'): Reply {
  return { stall: { status, headers: [["content-type", contentType]], prefix } };
}

export function throwsTypeError(message: string): Reply {
  return { throws: new TypeError(message) };
}

function abortError(signal: AbortSignal): unknown {
  return signal.reason ?? new DOMException("The operation was aborted.", "AbortError");
}

function classify(method: string, u: URL, form: URLSearchParams | null, headers: Record<string, string>): CallKind {
  if (u.origin === M2M) {
    if (method === "GET" && u.pathname === "/session/check") return Object.hasOwn(headers, "authorization") ? "pod" : "check";
    if (method === "GET" && u.pathname === "/tenants/me") return "pod";
    if (method === "POST" && u.pathname === "/sessions/revoke") return "sessions-revoke";
    if (method === "GET" && u.pathname === "/health") return "health";
  }
  if (u.origin === AUTH_ORIGIN && method === "POST") {
    if (u.pathname === "/application/o/revoke/") return "rfc7009";
    if (u.pathname === "/application/o/token/") {
      const grant = form?.get("grant_type");
      if (grant === GRANT_CODE) return "token-code";
      if (grant === GRANT_REFRESH) return "token-refresh";
      if (grant === GRANT_EXCHANGE) return "token-exchange";
    }
  }
  return "unknown";
}

export interface Upstream {
  fetch: ReturnType<typeof vi.fn>;
  calls: Recorded[];
  unexpected: string[];
  hostile: HostileNeedles;
  /** 종류의 처리기를 정한다(배열 = 차례로 한 번씩 · 다 쓰면 unexpected). 다시 부르면 바꾼다. */
  on(kind: CallKind, handler: Handler | Handler[]): void;
  ofKind(kind: CallKind): Recorded[];
  count(kind: CallKind): number;
  kinds(): CallKind[];
  /** n번째 kind 호출을 기다린다(실시간 예산 — 가짜 타이머와 무관). */
  waitFor(kind: CallKind, n?: number, budgetMs?: number): Promise<Recorded>;
}

export function createUpstream(): Upstream {
  const calls: Recorded[] = [];
  const unexpected: string[] = [];
  const handlers = new Map<CallKind, Handler | Handler[]>();
  const hostile: HostileNeedles = {
    cookie: fake("cf-authorization"),
    location: fake("location"),
    requestId: fake("upstream-request-id"),
    cfRay: fake("cf-ray"),
  };

  function withHostile(headers: Headers): Headers {
    headers.append("set-cookie", `CF_Authorization=${hostile.cookie}; Path=/; Secure; HttpOnly`);
    if (!headers.has("location")) headers.set("location", `${EVIL_ORIGIN}/${hostile.location}`);
    headers.set("cf-ray", hostile.cfRay);
    headers.set("x-request-id", hostile.requestId);
    headers.set("access-control-allow-origin", "*");
    return headers;
  }

  function teapot(): Response {
    return new Response("<html>unrouted</html>", {
      status: 418,
      headers: withHostile(new Headers([["content-type", "text/html"]])),
    });
  }

  function build(reply: Reply, rec: Recorded): Response | Promise<Response> {
    if ("throws" in reply) {
      throw reply.throws;
    }
    if ("hang" in reply) {
      return new Promise<Response>((_, reject) => {
        const s = rec.signal;
        if (s.aborted) {
          reject(abortError(s));
          return;
        }
        s.addEventListener("abort", () => reject(abortError(s)), { once: true });
      });
    }
    if ("stall" in reply) {
      const s = rec.signal;
      const stream = new ReadableStream<Uint8Array>({
        start(controller) {
          controller.enqueue(new TextEncoder().encode(reply.stall.prefix));
          const fail = (): void => controller.error(abortError(s));
          if (s.aborted) fail();
          else s.addEventListener("abort", fail, { once: true });
        },
      });
      return new Response(stream, { status: reply.stall.status, headers: withHostile(new Headers(reply.stall.headers)) });
    }
    const headers = new Headers(reply.headers ?? []);
    if (reply.hostile !== false) withHostile(headers);
    return new Response(reply.body ?? null, { status: reply.status, headers });
  }

  function take(kind: CallKind): Handler | undefined {
    const h = handlers.get(kind);
    if (Array.isArray(h)) {
      return h.shift();
    }
    return h;
  }

  const fetch = vi.fn(async (input: unknown): Promise<Response> => {
    if (!(input instanceof Request)) {
      unexpected.push("deps.fetch argument is not a Request");
      return teapot();
    }
    const req = input;
    const u = new URL(req.url);
    const headers: Record<string, string> = {};
    for (const [k, v] of req.headers) headers[k] = v;
    const body = await req.text();
    const contentType = headers["content-type"] ?? "";
    const form = contentType.startsWith("application/x-www-form-urlencoded") ? new URLSearchParams(body) : null;
    let parsed: unknown;
    try {
      parsed = body === "" ? undefined : JSON.parse(body);
    } catch {
      parsed = undefined;
    }
    const rec: Recorded = {
      seq: calls.length + 1,
      kind: classify(req.method, u, form, headers),
      method: req.method,
      url: req.url,
      origin: u.origin,
      pathname: u.pathname,
      query: new URLSearchParams(u.search),
      headers,
      headerNames: Object.keys(headers).sort(),
      body,
      form,
      json: parsed,
      cache: req.cache,
      redirect: req.redirect,
      signal: req.signal,
    };
    calls.push(rec);
    const handler = rec.kind === "unknown" ? undefined : take(rec.kind);
    if (handler === undefined) {
      unexpected.push(`#${rec.seq} ${rec.kind} ${rec.method} ${rec.origin}${rec.pathname}`);
      return teapot();
    }
    const reply = typeof handler === "function" ? await handler(rec) : handler;
    return build(reply, rec);
  });

  const ofKind = (kind: CallKind): Recorded[] => calls.filter((c) => c.kind === kind);

  return {
    fetch,
    calls,
    unexpected,
    hostile,
    on(kind, handler) {
      handlers.set(kind, Array.isArray(handler) ? [...handler] : handler);
    },
    ofKind,
    count: (kind) => ofKind(kind).length,
    kinds: () => calls.map((c) => c.kind),
    async waitFor(kind, n = 1, budgetMs = 2000) {
      const t0 = performance.now();
      for (;;) {
        const list = ofKind(kind);
        if (list.length >= n) return list[n - 1];
        if (performance.now() - t0 > budgetMs) {
          throw new Error(`waitFor(${kind}, ${n}) — no call within ${budgetMs} ms`);
        }
        await new Promise<void>((resolve) => setImmediate(resolve));
      }
    },
  };
}
