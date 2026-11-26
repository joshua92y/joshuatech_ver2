// T089 시험 기반 — 가짜 비밀 · 바늘 · 인코딩 도우미(specs/003-platform-foundation/design/t086-design.md D9-5 · G13).
//
// 비밀성 값은 전부 실행 중에 만든다: fake(label) = `${label}-${randomUUID()}` · 키 = 무작위 바이트 · JWT 꼴은 조립한다.
// 이 파일과 시험 파일에는 비밀 꼴 리터럴을 두지 않는다(GitGuardian 「Generic Password」 오탐 선례 — D9-5).
// 바늘 단언은 불리언 꼴(hasNeedle(...) === false)로만 쓴다 — 실패 메시지에 값이 찍히지 않게.

import { randomUUID, webcrypto } from "node:crypto";

/** 가짜 비밀 · 바늘 값(실행 중 생성). */
export function fake(label: string): string {
  return `${label}-${randomUUID()}`;
}

export function randomBytes(n: number): Uint8Array {
  return webcrypto.getRandomValues(new Uint8Array(n));
}

export function hex(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString("hex");
}

export function randomHex(nBytes: number): string {
  return hex(randomBytes(nBytes));
}

export function b64url(input: Uint8Array | string): string {
  return Buffer.from(input).toString("base64url");
}

/** base64url 글자만 받는다(패딩 · 표준 base64 글자 거부). */
export function fromB64url(s: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]*$/.test(s)) {
    throw new Error("not base64url");
  }
  return new Uint8Array(Buffer.from(s, "base64url"));
}

/** JWT 꼴 문자열 — 서명 자리는 무작위 바이트. 실행 중에만 조립한다(리터럴 0). */
export function fakeJwt(
  payload: Record<string, unknown>,
  header: Record<string, unknown> = { alg: "RS256", typ: "JWT" },
): string {
  return [b64url(JSON.stringify(header)), b64url(JSON.stringify(payload)), b64url(randomBytes(64))].join(".");
}

/** base64 · base64url 부호화에서 바늘 바이트만으로 정해지는 가운데 글자열 — 앞 바이트 정렬 0 · 1 · 2 셋. */
function base64Cores(bytes: Buffer): string[] {
  const cores: string[] = [];
  for (let k = 0; k < 3; k += 1) {
    const buf = Buffer.concat([Buffer.alloc(k, 0), bytes]);
    const start = Math.ceil((8 * k) / 6);
    const end = Math.floor((8 * buf.length) / 6);
    for (const encoding of ["base64url", "base64"] as const) {
      const encoded = buf.toString(encoding).replace(/=+$/, "");
      cores.push(encoded.slice(start, end));
    }
  }
  return cores;
}

/**
 * 바늘의 세 인코딩: 원문 · base64url(표준 base64 · 앞 바이트 정렬 셋 포함) · 퍼센트(encodeURIComponent · 폼 · 소문자 16진).
 * 8자 미만 바늘은 거짓 양성 위험이 커 받지 않는다.
 */
export function needleForms(needle: string): string[] {
  if (needle.length < 8) {
    throw new Error("needle too short to scan reliably");
  }
  const percent = encodeURIComponent(needle);
  const forms = new Set<string>([
    needle,
    percent,
    percent.replace(/%[0-9A-F]{2}/g, (m) => m.toLowerCase()),
    new URLSearchParams({ n: needle }).toString().slice(2),
    ...base64Cores(Buffer.from(needle, "utf8")),
  ]);
  forms.delete("");
  return [...forms];
}

/** haystack에 바늘이 세 인코딩 가운데 하나로라도 들어 있는가. */
export function hasNeedle(haystack: string, needle: string): boolean {
  return needleForms(needle).some((form) => haystack.includes(form));
}
