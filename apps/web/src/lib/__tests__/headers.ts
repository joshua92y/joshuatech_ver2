// T089 시험 기반 — assertResponseHeaders(specs/003-platform-foundation/design/t086-design.md D9-4 표 · C16 · C23 · C28 · §7 N-5).
//
// 응답 헤더 이름 집합을 라우트 × 결과마다 정확히 본다. B = {x-request-id, cache-control, x-content-type-options}.
//   outcome           헤더 이름 집합                                              Set-Cookie
//   body              B + content-type (200 JSON · problem)                       0
//   empty             B (204)                                                     0
//   login-302         B + location + set-cookie                                   pkce 설정
//   callback-302      B + location + set-cookie                                   세션 · CSRF 설정 + pkce 삭제
//   callback-error    B + content-type + set-cookie (400 · 503 · 설정 무효 503 — N-5)  pkce 삭제
//   logout-no-cookie  B + content-type (+ x-end-session-url — C23 조건)             0
//   logout-deleted    B (+ content-type — 204가 아니면) + set-cookie (+ x-end-session-url)  세션 · CSRF 삭제
//   session-deleted   B + content-type + set-cookie (inactive · 무효 쿠키 401 — session · refresh · proxy)  세션 · CSRF 삭제
//   rotated           B (+ content-type — 204가 아니면) + set-cookie (회전이 있었던 refresh · proxy)  세션 · CSRF 설정
// `location`은 login · callback 302에만 · `x-end-session-url`은 logout에만(opts.endSession) · ACAO 0.
// `set-cookie` 이름은 계약 이름(__Host-jt_session · __Host-jt_csrf · __Host-jt_pkce)만이고 동작(설정 · 삭제)과 속성이 정확하다.

import { expect } from "vitest";

import {
  CONTRACT_COOKIES,
  CSRF_COOKIE,
  type ParsedCookie,
  PKCE_COOKIE,
  SESSION_COOKIE,
  expectCookieDeleted,
  expectCookieSet,
  setCookies,
} from "./cookies";

export const BASE_HEADER_NAMES: readonly string[] = ["cache-control", "x-content-type-options", "x-request-id"];

export type RouteName = "login" | "callback" | "logout" | "refresh" | "session" | "health" | "proxy";
export type Outcome =
  | "body"
  | "empty"
  | "login-302"
  | "callback-302"
  | "callback-error"
  | "logout-no-cookie"
  | "logout-deleted"
  | "session-deleted"
  | "rotated";

export interface HeaderOptions {
  /** 302 Location 기대값(정확 비교). login은 무작위 질의라 생략하고 따로 본다. */
  location?: string;
  /** x-end-session-url 있음(logout만 · C23 조건). */
  endSession?: boolean;
}

interface Expectation {
  body: boolean;
  location: boolean;
  set: string[];
  del: string[];
  endSession: boolean;
}

function expectationFor(route: RouteName, outcome: Outcome, res: Response, opts: HeaderOptions): Expectation {
  const none = { body: false, location: false, set: [] as string[], del: [] as string[], endSession: false };
  const only = (allowed: RouteName[]): void => {
    if (!allowed.includes(route)) {
      throw new Error(`assertResponseHeaders: outcome ${outcome} does not apply to route ${route}`);
    }
  };
  if (opts.endSession && route !== "logout") {
    throw new Error("assertResponseHeaders: x-end-session-url applies to logout only");
  }
  switch (outcome) {
    case "body":
      return { ...none, body: true, endSession: false };
    case "empty":
      return { ...none };
    case "login-302":
      only(["login"]);
      return { ...none, location: true, set: [PKCE_COOKIE] };
    case "callback-302":
      only(["callback"]);
      return { ...none, location: true, set: [SESSION_COOKIE, CSRF_COOKIE], del: [PKCE_COOKIE] };
    case "callback-error":
      only(["callback"]);
      return { ...none, body: true, del: [PKCE_COOKIE] };
    case "logout-no-cookie":
      only(["logout"]);
      return { ...none, body: true, endSession: opts.endSession === true };
    case "logout-deleted":
      only(["logout"]);
      return {
        ...none,
        body: res.status !== 204,
        del: [SESSION_COOKIE, CSRF_COOKIE],
        endSession: opts.endSession === true,
      };
    case "session-deleted":
      only(["session", "refresh", "proxy"]);
      return { ...none, body: true, del: [SESSION_COOKIE, CSRF_COOKIE] };
    case "rotated":
      only(["refresh", "proxy"]);
      return { ...none, body: res.status !== 204, set: [SESSION_COOKIE, CSRF_COOKIE] };
    default:
      throw new Error(`assertResponseHeaders: unknown outcome ${String(outcome)}`);
  }
}

/** 라우트 × 결과의 응답 헤더를 정확히 단언하고 Set-Cookie 파싱 결과를 돌려준다. */
export function assertResponseHeaders(
  route: RouteName,
  outcome: Outcome,
  res: Response,
  opts: HeaderOptions = {},
): ParsedCookie[] {
  const e = expectationFor(route, outcome, res, opts);
  const expected = new Set<string>(BASE_HEADER_NAMES);
  if (e.body) expected.add("content-type");
  if (e.location) expected.add("location");
  if (e.set.length + e.del.length > 0) expected.add("set-cookie");
  if (e.endSession) expected.add("x-end-session-url");

  const names = [...new Set([...res.headers.keys()])].sort();
  expect(names, `${route} · ${outcome} 응답 헤더 이름 집합(D9-4)`).toEqual([...expected].sort());
  expect(res.headers.get("cache-control"), "cache-control(C16)").toBe("no-store");
  expect(res.headers.get("x-content-type-options"), "nosniff(C16)").toBe("nosniff");
  expect(res.headers.get("access-control-allow-origin"), "ACAO 0(C16)").toBeNull();
  if (e.location && opts.location !== undefined) {
    expect(res.headers.get("location"), `${route} 302 Location`).toBe(opts.location);
  }

  const cookies = setCookies(res);
  for (const c of cookies) {
    expect(CONTRACT_COOKIES, `Set-Cookie 이름은 계약 이름만`).toContain(c.name);
  }
  const got = cookies.map((c) => `${c.value === "" ? "del" : "set"}:${c.name}`).sort();
  const want = [...e.set.map((n) => `set:${n}`), ...e.del.map((n) => `del:${n}`)].sort();
  expect(got, `${route} · ${outcome} Set-Cookie 동작`).toEqual(want);
  for (const c of cookies) {
    if (c.value === "") {
      expectCookieDeleted(c, c.name);
    } else {
      expectCookieSet(c, c.name);
    }
  }
  return cookies;
}
