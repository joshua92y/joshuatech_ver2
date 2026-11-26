// T089 시험 기반 — 쿠키 상수 · Set-Cookie 파서 · C28 속성 기대값(specs/003-platform-foundation/design/t086-design.md
// D9-4 · C28 · §0-7 B-6 · §7 N-9).
//
// 쿠키 이름은 시험의 자기 상수다 — gateway에서 가져오지 않는다(독립 기대값 · §0-7).
// N-9: pkce 쿠키 = `__Host-jt_pkce` · `Path=/`(본문의 `__Secure-jt_pkce` · `Path=/api/auth/callback`은 이 꼴로 읽는다).

import { expect } from "vitest";

export const SESSION_COOKIE = "__Host-jt_session";
export const CSRF_COOKIE = "__Host-jt_csrf";
export const PKCE_COOKIE = "__Host-jt_pkce";
/** 접두 없는 옛 이름 — BFF는 읽지 않는다(없는 것과 같다 · C5). */
export const LEGACY_SESSION_COOKIE = "jt_session";
export const LEGACY_CSRF_COOKIE = "jt_csrf";
export const CONTRACT_COOKIES: readonly string[] = [SESSION_COOKIE, CSRF_COOKIE, PKCE_COOKIE];

export const SESSION_MAX_AGE = 2592000;
export const PKCE_MAX_AGE = 300;

export interface ParsedCookie {
  name: string;
  value: string;
  /** 속성 이름은 소문자 · 값 없는 플래그는 true. */
  attrs: Record<string, string | true>;
  /** 두 번 이상 나온 속성 이름(소문자). */
  duplicateAttrs: string[];
  line: string;
}

/** Set-Cookie 한 줄 → 이름 · 값 · 속성 맵(속성 이름 대소문자 무관). */
export function parseSetCookie(line: string): ParsedCookie {
  const segments = line.split(";");
  const first = segments.shift() ?? "";
  const eq = first.indexOf("=");
  if (eq <= 0) {
    throw new Error("Set-Cookie without name=value");
  }
  const attrs: Record<string, string | true> = {};
  const duplicateAttrs: string[] = [];
  for (const segment of segments) {
    const s = segment.trim();
    if (s === "") {
      continue;
    }
    const i = s.indexOf("=");
    const key = (i < 0 ? s : s.slice(0, i)).trim().toLowerCase();
    const value: string | true = i < 0 ? true : s.slice(i + 1).trim();
    if (Object.hasOwn(attrs, key)) {
      duplicateAttrs.push(key);
    }
    attrs[key] = value;
  }
  return { name: first.slice(0, eq).trim(), value: first.slice(eq + 1).trim(), attrs, duplicateAttrs, line };
}

/** 응답의 Set-Cookie 전부(여러 줄 — Headers.getSetCookie). */
export function setCookies(res: Response): ParsedCookie[] {
  return res.headers.getSetCookie().map(parseSetCookie);
}

/** C28 「설정」 속성(소문자 이름 · SameSite 값은 소문자로 비교). 삭제 = 같은 속성 + 빈 값 + Max-Age=0. */
export const SET_ATTRS: Readonly<Record<string, Readonly<Record<string, string | true>>>> = {
  [SESSION_COOKIE]: { httponly: true, secure: true, samesite: "lax", path: "/", "max-age": String(SESSION_MAX_AGE) },
  [CSRF_COOKIE]: { secure: true, samesite: "lax", path: "/", "max-age": String(SESSION_MAX_AGE) },
  [PKCE_COOKIE]: { httponly: true, secure: true, samesite: "lax", path: "/", "max-age": String(PKCE_MAX_AGE) },
};

function normalizedAttrs(c: ParsedCookie): Record<string, string | true> {
  const out: Record<string, string | true> = { ...c.attrs };
  if (typeof out.samesite === "string") {
    out.samesite = out.samesite.toLowerCase();
  }
  return out;
}

/** 「설정」 꼴 정확 비교(C28): 값 있음 · 속성 집합 정확 · Domain · Partitioned · Expires 0 · 중복 속성 0. */
export function expectCookieSet(c: ParsedCookie | undefined, name: string): ParsedCookie {
  expect(c, `${name} Set-Cookie 있음`).toBeDefined();
  const cookie = c as ParsedCookie;
  expect(cookie.name).toBe(name);
  expect(cookie.value.length, `${name} 설정 값은 비지 않는다`).toBeGreaterThan(0);
  expect(cookie.duplicateAttrs, `${name} 중복 속성`).toEqual([]);
  expect(normalizedAttrs(cookie), `${name} 설정 속성(C28)`).toEqual(SET_ATTRS[name]);
  return cookie;
}

/** 「삭제」 꼴 정확 비교(C28): 빈 값 · 같은 속성 · Max-Age=0. */
export function expectCookieDeleted(c: ParsedCookie | undefined, name: string): ParsedCookie {
  expect(c, `${name} 삭제 Set-Cookie 있음`).toBeDefined();
  const cookie = c as ParsedCookie;
  expect(cookie.name).toBe(name);
  expect(cookie.value, `${name} 삭제 값은 빈 값`).toBe("");
  expect(cookie.duplicateAttrs, `${name} 중복 속성`).toEqual([]);
  expect(normalizedAttrs(cookie), `${name} 삭제 속성(C28)`).toEqual({ ...SET_ATTRS[name], "max-age": "0" });
  return cookie;
}

/** 요청 Cookie 헤더 값. */
export function cookieHeader(pairs: ReadonlyArray<readonly [string, string]>): string {
  return pairs.map(([n, v]) => `${n}=${v}`).join("; ");
}

/** 이름이 같은 Set-Cookie 하나(없거나 둘 이상이면 undefined — 정확 단언은 headers.ts가 한다). */
export function cookieNamed(cookies: ParsedCookie[], name: string): ParsedCookie | undefined {
  const found = cookies.filter((c) => c.name === name);
  return found.length === 1 ? found[0] : undefined;
}
