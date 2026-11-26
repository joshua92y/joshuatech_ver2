// T089 시험 기반 — 파일 수준 불변식(specs/003-platform-foundation/design/t086-design.md D9-2 · C8 · C15 · G13).
//
// installFileInvariants()를 시험 파일 최상위에서 한 번 부른다. 사례마다:
//   beforeEach — 전역 fetch를 「불리면 실패」로 바꾸고(vi.stubGlobal) console 다섯 메서드를 엿본다.
//   afterEach  — track()으로 등록한 가짜 상류의 모든 기록 호출에 대해
//                ① redirect === 'manual' ② origin ∈ {issuer origin, IDENTITY_M2M_URL} ③ /session/check는 cache 'no-store'
//                ④ 헤더 이름 집합 = C8(종류별 정확) ⑤ 처리기 없는 호출 0 · Request 아닌 인자 0
//                + 전역 fetch 호출 0 · console 호출 0 — 하나라도 어기면 그 사례가 실패한다.
// 위반 메시지에는 값(헤더 값 · 질의 값)을 싣지 않는다 — 종류 · 경로 · 이름만.

import { afterEach, beforeEach, expect, type MockInstance, vi } from "vitest";

import { AUTH_ORIGIN, type CallKind, M2M, type Upstream } from "./fake-upstream";

const AUTHENTIK = ["accept", "content-type"];
const CHECK = ["accept", "cf-access-client-id", "cf-access-client-secret", "traceparent", "x-forwarded-user-sub", "x-request-id"];
const POD = [...CHECK, "authorization"];
const SESSIONS_REVOKE = [...POD, "content-type"];
const HEALTH = ["accept", "cf-access-client-id", "cf-access-client-secret", "traceparent", "x-request-id"];

/** C8 하류 헤더 이름 정확 집합(정렬). */
export const C8_HEADER_NAMES: Readonly<Record<Exclude<CallKind, "unknown">, readonly string[]>> = {
  "token-code": [...AUTHENTIK].sort(),
  "token-refresh": [...AUTHENTIK].sort(),
  "token-exchange": [...AUTHENTIK].sort(),
  rfc7009: [...AUTHENTIK].sort(),
  check: [...CHECK].sort(),
  pod: [...POD].sort(),
  "sessions-revoke": [...SESSIONS_REVOKE].sort(),
  health: [...HEALTH].sort(),
};

const CONSOLE_METHODS = ["log", "info", "warn", "error", "debug"] as const;

const tracked: Upstream[] = [];
let consoleSpies: MockInstance[] = [];
let globalFetch: MockInstance | undefined;

/** 이 사례의 가짜 상류를 afterEach 불변식에 올린다. */
export function track(up: Upstream): Upstream {
  tracked.push(up);
  return up;
}

function sameList(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

/** 한 가짜 상류의 불변식 위반 목록(빈 배열 = 통과). */
export function upstreamViolations(up: Upstream): string[] {
  const v: string[] = [];
  for (const c of up.calls) {
    const tag = `#${c.seq} ${c.kind} ${c.method} ${c.pathname}`;
    if (c.redirect !== "manual") v.push(`${tag}: redirect=${c.redirect} (manual expected)`);
    if (c.origin !== AUTH_ORIGIN && c.origin !== M2M) v.push(`${tag}: origin outside {issuer origin, IDENTITY_M2M_URL}`);
    if (c.kind === "check" && c.cache !== "no-store") v.push(`${tag}: cache=${c.cache} (no-store expected)`);
    if (c.kind === "unknown") {
      v.push(`${tag}: unknown call kind`);
      continue;
    }
    const want = C8_HEADER_NAMES[c.kind];
    if (!sameList(c.headerNames, want)) {
      v.push(`${tag}: header names [${c.headerNames.join(",")}] != C8 [${want.join(",")}]`);
    }
  }
  for (const u of up.unexpected) v.push(`unexpected upstream call: ${u}`);
  return v;
}

export function installFileInvariants(): void {
  beforeEach(() => {
    tracked.length = 0;
    const stub = vi.fn(async () => {
      throw new Error("global fetch called — deps.fetch is the only upstream path");
    });
    vi.stubGlobal("fetch", stub);
    globalFetch = stub;
    consoleSpies = CONSOLE_METHODS.map((m) => vi.spyOn(console, m).mockImplementation(() => undefined));
  });

  afterEach(() => {
    const violations: string[] = [];
    for (const up of tracked) violations.push(...upstreamViolations(up));
    const globalCalls = globalFetch?.mock.calls.length ?? 0;
    if (globalCalls > 0) violations.push(`global fetch called ${globalCalls}x`);
    CONSOLE_METHODS.forEach((m, i) => {
      const n = consoleSpies[i]?.mock.calls.length ?? 0;
      if (n > 0) violations.push(`console.${m} called ${n}x`);
    });
    for (const s of consoleSpies) s.mockRestore();
    consoleSpies = [];
    vi.unstubAllGlobals();
    vi.useRealTimers();
    tracked.length = 0;
    expect(violations, "file-level invariants (D9-2 · C8 · G13)").toEqual([]);
  });
}
