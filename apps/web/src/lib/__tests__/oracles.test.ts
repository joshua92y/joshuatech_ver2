// T089 자기 시험(specs/003-platform-foundation/design/t086-design.md D9-6) — 처음부터 초록이어야 한다.
//
// gateway.test.ts가 기대값을 계산 · 판정할 때 쓰는 시험 기반 자체를 검증한다(gateway · image-loader를 적재하지 않는다).
//   O1 JWE 오라클: RFC 7516 부록 A.1 AES-GCM 벡터 · 왕복 · compact 꼴 · 같은 평문 두 봉인 · 변조(AAD 포함) 실패
//      + RFC 7636 부록 B(PKCE S256) 독립 계산
//   O2 hasNeedle: 세 인코딩 양성(원문 · base64url 정렬 셋 · 표준 base64 · 퍼센트 · 폼) · 음성
//   O3 기록형 라우터: 기록 필드 · 종류 분류 · 매번 새 Response · 적대 헤더 · 순서 처리기 · unexpected · 불변식 판정
//      + VD-T089-3(Request가 cache · redirect · 헤더 · signal을 보존)
//   O4 매달린 상류 · 본문 정지: abort에서만 거부 · 가짜 타이머 2999 / 3000 ms 경계(VD-T089-2 — 시험 기반 수준)
//   O5 쿠키 파서 · C28 기대값(대소문자 · 여러 Set-Cookie · 접두 이름 · 음성)
//   O6 assertResponseHeaders 양성 · 음성

import { createHash } from "node:crypto";

import { afterEach, describe, expect, it, vi } from "vitest";

import {
  CSRF_COOKIE,
  PKCE_COOKIE,
  SESSION_COOKIE,
  cookieHeader,
  cookieNamed,
  expectCookieDeleted,
  expectCookieSet,
  parseSetCookie,
  setCookies,
} from "./cookies";
import {
  AUTHORIZE_URL,
  GRANT_CODE,
  GRANT_EXCHANGE,
  GRANT_REFRESH,
  HANG,
  M2M,
  REVOKE_URL,
  TOKEN_URL,
  createUpstream,
  empty,
  json,
  stall,
} from "./fake-upstream";
import { assertResponseHeaders } from "./headers";
import { C8_HEADER_NAMES, upstreamViolations } from "./invariants";
import { b64url, fake, fakeJwt, fromB64url, hasNeedle, randomHex } from "./needles";
import { gcmDecrypt, gcmEncrypt, seal, splitCompact, tamper, unseal } from "./oracle-jwe";

afterEach(() => {
  vi.useRealTimers();
});

// RFC 7516 부록 A.1 — AES-GCM 단계(A.1.2 CEK · A.1.4 IV · A.1.5 AAD · A.1.6 암호문 · 태그). 보호 헤더 부호화는 실행 중에 만든다.
const RFC7516_A1_CEK = [
  177, 161, 244, 128, 84, 143, 225, 115, 63, 180, 3, 255, 107, 154, 212, 246, 138, 7, 110, 91, 112, 46, 34, 105, 47,
  130, 203, 46, 122, 234, 64, 252,
];
const RFC7516_A1_IV = [227, 197, 117, 252, 2, 219, 233, 68, 180, 225, 77, 219];
const RFC7516_A1_PLAINTEXT = "The true sign of intelligence is not knowledge but imagination.";
const RFC7516_A1_CIPHERTEXT_B64URL =
  "5eym8TW_c8SuK0ltJ3rpYIzOeDQz7TALvtu6UG9oMo4vpzs9tX_EFShS8iB7j6jiSdiwkIr3ajwQzaBtQD_A";
const RFC7516_A1_TAG_B64URL = "XFBoMYUZodetZdvTiFvSkQ";

// RFC 7636 부록 B — 32옥텟 → code_verifier(base64url) → S256 code_challenge.
const RFC7636_B_OCTETS = [
  116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186, 22, 212, 37, 77, 105, 214, 191, 240, 91, 88,
  5, 88, 83, 132, 141, 121,
];
const RFC7636_B_CHALLENGE = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM";

describe("O1 JWE 오라클", () => {
  it("O1-1 RFC 7516 부록 A.1 AES-GCM 벡터 — AAD = ASCII(b64url(보호 헤더))", async () => {
    const aad = b64url(JSON.stringify({ alg: "RSA-OAEP", enc: "A256GCM" }));
    const cek = new Uint8Array(RFC7516_A1_CEK);
    const iv = new Uint8Array(RFC7516_A1_IV);
    const { ciphertext, tag } = await gcmEncrypt(cek, iv, aad, new TextEncoder().encode(RFC7516_A1_PLAINTEXT));
    expect(b64url(ciphertext)).toBe(RFC7516_A1_CIPHERTEXT_B64URL);
    expect(b64url(tag)).toBe(RFC7516_A1_TAG_B64URL);
    const plain = await gcmDecrypt(cek, iv, aad, ciphertext, tag);
    expect(new TextDecoder().decode(plain)).toBe(RFC7516_A1_PLAINTEXT);
    await expect(gcmDecrypt(cek, iv, `${aad}x`, ciphertext, tag)).rejects.toThrow();
  });

  it("O1-2 왕복 · compact 꼴(v1. · 5조각 · 둘째 빈 값 · IV 16자 · 태그 22자) · 보호 헤더 정확", async () => {
    const key = randomHex(32);
    const payload = { refresh_token: fake("rt"), sub: fake("sub"), sid: fake("sid"), issued_at: 1 };
    const value = await seal(key, "jt-session", payload);
    expect(value.startsWith("v1.")).toBe(true);
    const parts = value.slice(3).split(".");
    expect(parts).toHaveLength(5);
    expect(parts[1]).toBe("");
    expect(parts[2]).toMatch(/^[A-Za-z0-9_-]{16}$/);
    expect(parts[4]).toMatch(/^[A-Za-z0-9_-]{22}$/);
    const opened = await unseal(key, value);
    expect(opened.header).toEqual({ alg: "dir", enc: "A256GCM", typ: "jt-session" });
    expect(opened.payload).toEqual(payload);
    expect(hasNeedle(value, payload.refresh_token)).toBe(false);
  });

  it("O1-3 같은 평문 두 봉인 — IV · 암호문이 다르다", async () => {
    const key = randomHex(32);
    const payload = { state: fake("s") };
    const a = splitCompact(await seal(key, "jt-pkce", payload));
    const b = splitCompact(await seal(key, "jt-pkce", payload));
    expect(a[0]).toBe(b[0]);
    expect(a[2]).not.toBe(b[2]);
    expect(a[3]).not.toBe(b[3]);
  });

  it("O1-4 변조 · 다른 키 · 꼴 오류는 복호하지 못한다(헤더 변조 = 같은 뜻 · 다른 바이트)", async () => {
    const key = randomHex(32);
    const value = await seal(key, "jt-session", { sub: fake("sub") });
    expect((await unseal(key, value)).payload.sub).toBeTypeOf("string");
    const tamperedHeader = tamper(value, "header");
    expect(JSON.parse(Buffer.from(splitCompact(tamperedHeader)[0], "base64url").toString())).toEqual({
      alg: "dir",
      enc: "A256GCM",
      typ: "jt-session",
    });
    for (const bad of [
      tamperedHeader,
      tamper(value, "iv"),
      tamper(value, "ciphertext"),
      tamper(value, "tag"),
      value.slice(3),
      `v2.${value.slice(3)}`,
    ]) {
      await expect(unseal(key, bad)).rejects.toThrow();
    }
    await expect(unseal(randomHex(32), value)).rejects.toThrow();
    expect(() => fromB64url("a+b/")).toThrow();
  });

  it("O1-5 RFC 7636 부록 B — node:crypto S256 독립 계산", () => {
    const verifier = b64url(new Uint8Array(RFC7636_B_OCTETS));
    expect(verifier).toHaveLength(43);
    expect(createHash("sha256").update(verifier, "ascii").digest("base64url")).toBe(RFC7636_B_CHALLENGE);
  });
});

describe("O2 hasNeedle", () => {
  it("O2-1 양성 — 원문 · base64url(정렬 0 · 1 · 2) · 표준 base64 · 퍼센트 · 폼 · 소문자 16진", () => {
    const n = fake("needle");
    const special = `${fake("n")} /+=?&`;
    expect(hasNeedle(`x${n}y`, n)).toBe(true);
    expect(hasNeedle(b64url(n), n)).toBe(true);
    expect(hasNeedle(b64url(`a${n}`), n)).toBe(true);
    expect(hasNeedle(b64url(`ab${n}z`), n)).toBe(true);
    expect(hasNeedle(`{"x":"${b64url(`abc${n}`)}"}`, n)).toBe(true);
    expect(hasNeedle(Buffer.from(`q${special}`).toString("base64"), special)).toBe(true);
    expect(hasNeedle(`?v=${encodeURIComponent(special)}`, special)).toBe(true);
    expect(hasNeedle(new URLSearchParams({ v: special }).toString(), special)).toBe(true);
    expect(hasNeedle(encodeURIComponent(special).toLowerCase(), special)).toBe(true);
    expect(hasNeedle(JSON.stringify({ t: fakeJwt({ sub: n }) }), n)).toBe(true);
  });

  it("O2-2 음성 — 무관한 값 · 한 글자 모자란 바늘 · 짧은 바늘 거부", () => {
    const n = fake("needle");
    expect(hasNeedle(fake("other"), n)).toBe(false);
    expect(hasNeedle(n.slice(0, -1), n)).toBe(false);
    expect(hasNeedle(b64url(n.slice(0, -1)), n)).toBe(false);
    expect(hasNeedle("", n)).toBe(false);
    expect(() => hasNeedle("x", "short")).toThrow();
  });
});

function checkRequest(extra: Record<string, string> = {}, init: RequestInit = {}): Request {
  return new Request(`${M2M}/session/check?sub=a&iat=1&sid=b`, {
    headers: {
      accept: "application/json",
      "cf-access-client-id": `${randomHex(16)}.access`,
      "cf-access-client-secret": fake("cs"),
      traceparent: `00-${randomHex(16)}-${randomHex(8)}-00`,
      "x-forwarded-user-sub": "a",
      "x-request-id": crypto.randomUUID(),
      ...extra,
    },
    cache: "no-store",
    redirect: "manual",
    ...init,
  });
}

function tokenRequest(form: Record<string, string>, url = TOKEN_URL): Request {
  return new Request(url, {
    method: "POST",
    headers: { accept: "application/json", "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(form).toString(),
    redirect: "manual",
  });
}

describe("O3 기록형 라우터", () => {
  it("O3-1 기록 필드(method · url · 질의 · 헤더 · 본문 · cache · redirect · signal) · 적대 헤더 기본 — VD-T089-3", async () => {
    const up = createUpstream();
    up.on("check", json(200, { active: true }));
    const ac = new AbortController();
    const res = await up.fetch(checkRequest({}, { signal: ac.signal }));
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ active: true });
    const [rec] = up.calls;
    expect(rec.kind).toBe("check");
    expect(rec.method).toBe("GET");
    expect(rec.origin + rec.pathname).toBe(`${M2M}/session/check`);
    expect(Object.fromEntries(rec.query)).toEqual({ sub: "a", iat: "1", sid: "b" });
    expect(rec.headerNames).toEqual([...C8_HEADER_NAMES.check]);
    expect(rec.cache).toBe("no-store");
    expect(rec.redirect).toBe("manual");
    expect(rec.signal.aborted).toBe(false);
    ac.abort();
    expect(rec.signal.aborted).toBe(true);
    expect(res.headers.getSetCookie()).toEqual([`CF_Authorization=${up.hostile.cookie}; Path=/; Secure; HttpOnly`]);
    expect(res.headers.get("location")).toBe(`https://evil.invalid/${up.hostile.location}`);
    expect(res.headers.get("x-request-id")).toBe(up.hostile.requestId);
    expect(res.headers.get("cf-ray")).toBe(up.hostile.cfRay);
    expect(res.headers.get("access-control-allow-origin")).toBe("*");
    expect(upstreamViolations(up)).toEqual([]);
  });

  it("O3-2 종류 분류 — 토큰 grant 셋 · RFC 7009 · pod(Bearer) · /sessions/revoke · /health · 모르는 호출", async () => {
    const up = createUpstream();
    for (const kind of ["token-code", "token-refresh", "token-exchange", "rfc7009", "pod", "sessions-revoke", "health"] as const) {
      up.on(kind, empty(200));
    }
    await up.fetch(tokenRequest({ grant_type: GRANT_CODE, code: "c" }));
    await up.fetch(tokenRequest({ grant_type: GRANT_REFRESH, refresh_token: "r" }));
    await up.fetch(tokenRequest({ grant_type: GRANT_EXCHANGE, subject_token: "s" }));
    await up.fetch(tokenRequest({ token: "r", token_type_hint: "refresh_token" }, REVOKE_URL));
    await up.fetch(checkRequest({ authorization: "Bearer x" }));
    await up.fetch(new Request(`${M2M}/tenants/me`, { headers: { authorization: "Bearer x" }, redirect: "manual" }));
    await up.fetch(
      new Request(`${M2M}/sessions/revoke`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ all_devices: true, reason: "logout_all" }),
        redirect: "manual",
      }),
    );
    await up.fetch(new Request(`${M2M}/health`, { redirect: "manual" }));
    const unknown = await up.fetch(new Request(AUTHORIZE_URL, { redirect: "manual" }));
    expect(up.kinds()).toEqual([
      "token-code",
      "token-refresh",
      "token-exchange",
      "rfc7009",
      "pod",
      "pod",
      "sessions-revoke",
      "health",
      "unknown",
    ]);
    expect(up.calls[0].form?.get("code")).toBe("c");
    expect(up.calls[6].json).toEqual({ all_devices: true, reason: "logout_all" });
    expect(unknown.status).toBe(418);
    expect(up.unexpected).toHaveLength(1);
  });

  it("O3-3 매번 새 Response · 순서 처리기는 한 번씩 · 다 쓰면 unexpected · 처리기 함수는 기록을 받는다", async () => {
    const up = createUpstream();
    up.on("check", [json(200, { active: true }), json(200, { active: false })]);
    const a = await up.fetch(checkRequest());
    const b = await up.fetch(checkRequest());
    const c = await up.fetch(checkRequest());
    expect(a).not.toBe(b);
    expect(await a.json()).toEqual({ active: true });
    expect(await b.json()).toEqual({ active: false });
    expect(c.status).toBe(418);
    expect(up.unexpected).toHaveLength(1);
    const up2 = createUpstream();
    up2.on("health", (rec) => json(200, { seen: rec.pathname }));
    const r1 = await up2.fetch(new Request(`${M2M}/health`, { redirect: "manual" }));
    const r2 = await up2.fetch(new Request(`${M2M}/health`, { redirect: "manual" }));
    expect(r1).not.toBe(r2);
    expect(await r1.json()).toEqual({ seen: "/health" });
    expect(await r2.json()).toEqual({ seen: "/health" });
  });

  it("O3-4 hostile:false는 적대 헤더를 빼고 · Request가 아닌 인자는 unexpected", async () => {
    const up = createUpstream();
    up.on("health", { status: 200, headers: [["content-type", "application/json"]], body: "{}", hostile: false });
    const res = await up.fetch(new Request(`${M2M}/health`, { redirect: "manual" }));
    expect([...res.headers.keys()]).toEqual(["content-type"]);
    const r2 = await up.fetch(`${M2M}/health`);
    expect(r2.status).toBe(418);
    expect(up.unexpected).toEqual(["deps.fetch argument is not a Request"]);
  });

  it("O3-5 불변식 판정 — 준수 호출 통과 · redirect follow · 밖 origin · no-store 없음 · 헤더 집합 어긋남 · unexpected", async () => {
    const ok = createUpstream();
    ok.on("check", json(200, { active: true }));
    await ok.fetch(checkRequest());
    expect(upstreamViolations(ok)).toEqual([]);

    const cases: Array<[string, Request]> = [
      ["redirect", checkRequest({}, { redirect: "follow" })],
      ["no-store", checkRequest({}, { cache: "default" })],
      ["extra header", checkRequest({ cookie: "a=b" })],
      ["missing header", new Request(`${M2M}/session/check?sub=a&iat=1`, { cache: "no-store", redirect: "manual" })],
    ];
    for (const [label, request] of cases) {
      const up = createUpstream();
      up.on("check", json(200, { active: true }));
      await up.fetch(request);
      expect(upstreamViolations(up).length, label).toBeGreaterThan(0);
    }
    const outside = createUpstream();
    await outside.fetch(new Request("https://other.example.test/session/check", { redirect: "manual" }));
    expect(upstreamViolations(outside).length).toBeGreaterThan(0);
    const unrouted = createUpstream();
    await unrouted.fetch(checkRequest());
    expect(upstreamViolations(unrouted)).toContain("unexpected upstream call: #1 check GET https://m2m.example.test/session/check");
  });
});

describe("O4 매달린 상류 · 본문 정지(VD-T089-2 — 시험 기반 수준)", () => {
  async function drain(): Promise<void> {
    for (let i = 0; i < 20; i += 1) {
      await new Promise<void>((resolve) => setImmediate(resolve));
    }
  }

  /** gateway가 쓸 꼴: AbortController + setTimeout(3000) · 헤더 + 본문 읽기까지 */
  async function timedCall(up: ReturnType<typeof createUpstream>, request: () => Request): Promise<string> {
    const ac = new AbortController();
    const t = setTimeout(() => ac.abort(), 3000);
    try {
      const res = await up.fetch(new Request(request(), { signal: ac.signal }));
      return await res.text();
    } finally {
      clearTimeout(t);
    }
  }

  it("O4-1 HANG — 2999 ms 미결 · 3000 ms AbortError · 기록 signal aborted", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    const up = createUpstream();
    up.on("health", HANG);
    let settled: "pending" | "resolved" | "rejected" = "pending";
    const p = timedCall(up, () => new Request(`${M2M}/health`, { redirect: "manual" })).then(
      () => {
        settled = "resolved";
      },
      (err: unknown) => {
        settled = (err as Error).name === "AbortError" ? "rejected" : "resolved";
      },
    );
    const rec = await up.waitFor("health");
    await vi.advanceTimersByTimeAsync(2999);
    await drain();
    expect(settled).toBe("pending");
    await vi.advanceTimersByTimeAsync(1);
    await drain();
    expect(settled).toBe("rejected");
    await p;
    expect(rec.signal.aborted).toBe(true);
  });

  it("O4-2 본문 정지 — 헤더는 즉시 · 본문 읽기는 3000 ms abort에서 거부", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    const up = createUpstream();
    up.on("health", stall(200, "application/json", '{"status":'));
    let settled: "pending" | "resolved" | "rejected" = "pending";
    const p = timedCall(up, () => new Request(`${M2M}/health`, { redirect: "manual" })).then(
      () => {
        settled = "resolved";
      },
      (err: unknown) => {
        settled = (err as Error).name === "AbortError" ? "rejected" : "resolved";
      },
    );
    await up.waitFor("health");
    await vi.advanceTimersByTimeAsync(2999);
    await drain();
    expect(settled).toBe("pending");
    await vi.advanceTimersByTimeAsync(1);
    await drain();
    expect(settled).toBe("rejected");
    await p;
  });

  it("O4-3 HANG은 abort 없이는 끝나지 않는다(60 s를 당겨도 미결)", async () => {
    vi.useFakeTimers({ toFake: ["setTimeout", "clearTimeout"] });
    const up = createUpstream();
    up.on("health", HANG);
    let settled = false;
    void up.fetch(new Request(`${M2M}/health`, { redirect: "manual" })).then(
      () => {
        settled = true;
      },
      () => {
        settled = true;
      },
    );
    await up.waitFor("health");
    await vi.advanceTimersByTimeAsync(60_000);
    await drain();
    expect(settled).toBe(false);
  });
});

function setLine(name: string, value: string): string {
  const flags = name === CSRF_COOKIE ? "Secure" : "HttpOnly; Secure";
  const maxAge = name === PKCE_COOKIE ? 300 : 2592000;
  return `${name}=${value}; ${flags}; SameSite=Lax; Path=/; Max-Age=${maxAge}`;
}

function delLine(name: string): string {
  const flags = name === CSRF_COOKIE ? "Secure" : "HttpOnly; Secure";
  return `${name}=; ${flags}; SameSite=Lax; Path=/; Max-Age=0`;
}

describe("O5 쿠키 파서 · C28 기대값", () => {
  it("O5-1 이름 · 값(= 포함) · 속성 소문자 · 플래그 true · 접두 이름 보존", () => {
    const c = parseSetCookie(`${SESSION_COOKIE}=v1.a=b..c; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=2592000`);
    expect(c.name).toBe("__Host-jt_session");
    expect(c.value).toBe("v1.a=b..c");
    expect(c.attrs).toEqual({ httponly: true, secure: true, samesite: "Lax", path: "/", "max-age": "2592000" });
    expect(c.duplicateAttrs).toEqual([]);
  });

  it("O5-2 대소문자 무관 — 속성 이름 · SameSite 값", () => {
    expectCookieSet(parseSetCookie(`${CSRF_COOKIE}=${randomHex(16)}; SECURE; samesite=LAX; PATH=/; max-age=2592000`), CSRF_COOKIE);
    expectCookieDeleted(parseSetCookie(`${PKCE_COOKIE}=; httponly; secure; SameSite=lax; path=/; MAX-AGE=0`), PKCE_COOKIE);
  });

  it("O5-3 여러 Set-Cookie — getSetCookie 순서 · 이름별 하나 찾기", () => {
    const headers = new Headers();
    headers.append("set-cookie", setLine(SESSION_COOKIE, "v1.s"));
    headers.append("set-cookie", setLine(CSRF_COOKIE, "abc"));
    headers.append("set-cookie", delLine(PKCE_COOKIE));
    const cookies = setCookies(new Response(null, { status: 204, headers }));
    expect(cookies.map((c) => c.name)).toEqual([SESSION_COOKIE, CSRF_COOKIE, PKCE_COOKIE]);
    expect(cookieNamed(cookies, CSRF_COOKIE)?.value).toBe("abc");
    expect(cookieNamed([...cookies, cookies[1]], CSRF_COOKIE)).toBeUndefined();
    expect(cookieHeader([[SESSION_COOKIE, "a"], [CSRF_COOKIE, "b"]])).toBe("__Host-jt_session=a; __Host-jt_csrf=b");
  });

  it("O5-4 설정 꼴 음성 — Domain · Expires · Partitioned · HttpOnly 빠짐 · CSRF에 HttpOnly · Max-Age · Path · 중복 · 빈 값", () => {
    const bad = [
      [SESSION_COOKIE, `${setLine(SESSION_COOKIE, "v")}; Domain=site.example.test`],
      [SESSION_COOKIE, `${setLine(SESSION_COOKIE, "v")}; Expires=Wed, 21 Oct 2026 07:28:00 GMT`],
      [SESSION_COOKIE, `${setLine(SESSION_COOKIE, "v")}; Partitioned`],
      [SESSION_COOKIE, `${SESSION_COOKIE}=v; Secure; SameSite=Lax; Path=/; Max-Age=2592000`],
      [CSRF_COOKIE, `${CSRF_COOKIE}=v; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=2592000`],
      [SESSION_COOKIE, `${SESSION_COOKIE}=v; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=86400`],
      [PKCE_COOKIE, `${PKCE_COOKIE}=v; HttpOnly; Secure; SameSite=Lax; Path=/api/auth/callback; Max-Age=300`],
      [SESSION_COOKIE, `${setLine(SESSION_COOKIE, "v")}; Max-Age=0`],
      [SESSION_COOKIE, setLine(SESSION_COOKIE, "")],
      [SESSION_COOKIE, `${SESSION_COOKIE}=v; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=2592000`],
    ] as const;
    for (const [name, line] of bad) {
      expect(() => expectCookieSet(parseSetCookie(line), name), line).toThrow();
    }
    expect(() => expectCookieSet(parseSetCookie(setLine(SESSION_COOKIE, "v")), CSRF_COOKIE)).toThrow();
    expect(() => expectCookieSet(undefined, SESSION_COOKIE)).toThrow();
  });

  it("O5-5 삭제 꼴 — 빈 값 · Max-Age=0 · 같은 속성(같은 Path)", () => {
    for (const name of [SESSION_COOKIE, CSRF_COOKIE, PKCE_COOKIE]) {
      expectCookieDeleted(parseSetCookie(delLine(name)), name);
      expect(() => expectCookieDeleted(parseSetCookie(setLine(name, "v")), name)).toThrow();
      expect(() => expectCookieDeleted(parseSetCookie(`${delLine(name)}; Domain=x.test`), name)).toThrow();
    }
    expect(() =>
      expectCookieDeleted(parseSetCookie(`${PKCE_COOKIE}=; HttpOnly; Secure; SameSite=Lax; Path=/api/auth/callback; Max-Age=0`), PKCE_COOKIE),
    ).toThrow();
    expect(() => expectCookieDeleted(parseSetCookie(`${SESSION_COOKIE}=; Max-Age=0`), SESSION_COOKIE)).toThrow();
  });
});

function base(extra: Array<[string, string]> = []): Headers {
  return new Headers([
    ["x-request-id", crypto.randomUUID()],
    ["cache-control", "no-store"],
    ["x-content-type-options", "nosniff"],
    ...extra,
  ]);
}

function withCookies(h: Headers, lines: string[]): Headers {
  for (const line of lines) h.append("set-cookie", line);
  return h;
}

describe("O6 assertResponseHeaders", () => {
  it("O6-1 양성 — 결과 꼴마다(D9-4 표)", () => {
    const pj: Array<[string, string]> = [["content-type", "application/problem+json"]];
    assertResponseHeaders("session", "body", new Response("{}", { status: 200, headers: base([["content-type", "application/json"]]) }));
    assertResponseHeaders("refresh", "empty", new Response(null, { status: 204, headers: base() }));
    assertResponseHeaders(
      "login",
      "login-302",
      new Response(null, { status: 302, headers: withCookies(base([["location", AUTHORIZE_URL]]), [setLine(PKCE_COOKIE, "v1.p")]) }),
    );
    assertResponseHeaders(
      "callback",
      "callback-302",
      new Response(null, {
        status: 302,
        headers: withCookies(base([["location", "/ko"]]), [
          setLine(SESSION_COOKIE, "v1.s"),
          setLine(CSRF_COOKIE, randomHex(16)),
          delLine(PKCE_COOKIE),
        ]),
      }),
      { location: "/ko" },
    );
    assertResponseHeaders(
      "callback",
      "callback-error",
      new Response("{}", { status: 400, headers: withCookies(base(pj), [delLine(PKCE_COOKIE)]) }),
    );
    assertResponseHeaders("logout", "logout-no-cookie", new Response("{}", { status: 401, headers: base(pj) }));
    assertResponseHeaders(
      "logout",
      "logout-no-cookie",
      new Response("{}", { status: 401, headers: base([...pj, ["x-end-session-url", "https://a.test/"]]) }),
      { endSession: true },
    );
    assertResponseHeaders(
      "logout",
      "logout-deleted",
      new Response(null, {
        status: 204,
        headers: withCookies(base([["x-end-session-url", "https://a.test/"]]), [delLine(SESSION_COOKIE), delLine(CSRF_COOKIE)]),
      }),
      { endSession: true },
    );
    assertResponseHeaders(
      "logout",
      "logout-deleted",
      new Response("{}", { status: 503, headers: withCookies(base(pj), [delLine(SESSION_COOKIE), delLine(CSRF_COOKIE)]) }),
    );
    assertResponseHeaders(
      "proxy",
      "session-deleted",
      new Response("{}", { status: 401, headers: withCookies(base(pj), [delLine(SESSION_COOKIE), delLine(CSRF_COOKIE)]) }),
    );
    assertResponseHeaders(
      "refresh",
      "rotated",
      new Response(null, {
        status: 204,
        headers: withCookies(base(), [setLine(SESSION_COOKIE, "v1.n"), setLine(CSRF_COOKIE, randomHex(16))]),
      }),
    );
    assertResponseHeaders(
      "proxy",
      "rotated",
      new Response("{}", {
        status: 200,
        headers: withCookies(base([["content-type", "application/json"]]), [
          setLine(SESSION_COOKIE, "v1.n"),
          setLine(CSRF_COOKIE, randomHex(16)),
        ]),
      }),
    );
  });

  it("O6-2 음성 — nosniff · cache-control · 남는 헤더 · ACAO · 204의 content-type · 모르는 쿠키 · 빠진 삭제 · Location · end-session · Domain", () => {
    const json200 = (extra: Array<[string, string]>, h = base([["content-type", "application/json"], ...extra])) =>
      new Response("{}", { status: 200, headers: h });
    const noNosniff = new Headers([["x-request-id", "r"], ["cache-control", "no-store"], ["content-type", "application/json"]]);
    const cacheOther = base([["content-type", "application/json"]]);
    cacheOther.set("cache-control", "private");
    const bad: Array<[string, () => unknown]> = [
      ["nosniff 없음", () => assertResponseHeaders("session", "body", new Response("{}", { headers: noNosniff }))],
      ["cache-control", () => assertResponseHeaders("session", "body", new Response("{}", { headers: cacheOther }))],
      ["cf-ray", () => assertResponseHeaders("session", "body", json200([["cf-ray", "x"]]))],
      ["ACAO", () => assertResponseHeaders("session", "body", json200([["access-control-allow-origin", "*"]]))],
      [
        "204 content-type",
        () => assertResponseHeaders("refresh", "empty", new Response(null, { status: 204, headers: base([["content-type", "text/plain"]]) })),
      ],
      [
        "CF_Authorization",
        () =>
          assertResponseHeaders(
            "proxy",
            "body",
            json200([], withCookies(base([["content-type", "application/json"]]), ["CF_Authorization=x; Path=/"])),
          ),
      ],
      [
        "CSRF 삭제 빠짐",
        () =>
          assertResponseHeaders(
            "session",
            "session-deleted",
            new Response("{}", { status: 401, headers: withCookies(base([["content-type", "application/problem+json"]]), [delLine(SESSION_COOKIE)]) }),
          ),
      ],
      [
        "Location 다름",
        () =>
          assertResponseHeaders(
            "callback",
            "callback-302",
            new Response(null, {
              status: 302,
              headers: withCookies(base([["location", "/en"]]), [setLine(SESSION_COOKIE, "s"), setLine(CSRF_COOKIE, "c"), delLine(PKCE_COOKIE)]),
            }),
            { location: "/ko" },
          ),
      ],
      [
        "x-end-session-url 기대 밖",
        () =>
          assertResponseHeaders(
            "logout",
            "logout-no-cookie",
            new Response("{}", { status: 401, headers: base([["content-type", "application/problem+json"], ["x-end-session-url", "https://a.test/"]]) }),
          ),
      ],
      ["logout 밖 endSession", () => assertResponseHeaders("session", "body", json200([]), { endSession: true })],
      [
        "Domain",
        () =>
          assertResponseHeaders(
            "refresh",
            "rotated",
            new Response(null, {
              status: 204,
              headers: withCookies(base(), [`${setLine(SESSION_COOKIE, "s")}; Domain=example.test`, setLine(CSRF_COOKIE, "c")]),
            }),
          ),
      ],
      ["outcome 라우트 불일치", () => assertResponseHeaders("session", "login-302", json200([]))],
    ];
    for (const [label, fn] of bad) {
      expect(fn, label).toThrow();
    }
  });
});
