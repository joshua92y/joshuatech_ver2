// T089 시험 기반 — JWE 오라클(specs/003-platform-foundation/design/t086-design.md D9-4 · C3).
//
// gateway와 독립된 기대값 계산기: Web Crypto AES-GCM만 쓴다(jose 0).
// 쿠키 값 꼴 = `v1.` + compact `<b64url(보호 헤더)>..<b64url(IV 12 B)>.<b64url(암호문)>.<b64url(태그 16 B)>`
// 보호 헤더 = 정확히 {alg:"dir", enc:"A256GCM", typ}(typ ∈ {jt-session, jt-pkce}) · AAD = ASCII(b64url(보호 헤더))
// (RFC 7516 §5.1 14단계). 오라클은 정상 꼴만 읽고, 어긋나면 던진다 — gateway의 판정 규칙을 흉내 내지 않는다.

import { webcrypto } from "node:crypto";

import { b64url, fromB64url, randomBytes } from "./needles";

const subtle = webcrypto.subtle;
const utf8 = new TextEncoder();
const strictUtf8 = new TextDecoder("utf-8", { fatal: true });

export const JWE_PREFIX = "v1.";

function keyBytes(keyHex: string): Uint8Array {
  if (!/^[0-9a-f]{64}$/.test(keyHex)) {
    throw new Error("oracle: key must be 64 lowercase hex");
  }
  return new Uint8Array(Buffer.from(keyHex, "hex"));
}

/** AES-GCM(128비트 태그) 원시 암호화 — 반환 = 암호문 · 태그 분리. */
export async function gcmEncrypt(
  key: Uint8Array,
  iv: Uint8Array,
  aad: string,
  plaintext: Uint8Array,
): Promise<{ ciphertext: Uint8Array; tag: Uint8Array }> {
  const k = await subtle.importKey("raw", key, "AES-GCM", false, ["encrypt"]);
  const sealed = new Uint8Array(
    await subtle.encrypt({ name: "AES-GCM", iv, additionalData: utf8.encode(aad), tagLength: 128 }, k, plaintext),
  );
  return { ciphertext: sealed.slice(0, sealed.length - 16), tag: sealed.slice(sealed.length - 16) };
}

/** AES-GCM 원시 복호 — 태그 · AAD가 맞지 않으면 던진다. */
export async function gcmDecrypt(
  key: Uint8Array,
  iv: Uint8Array,
  aad: string,
  ciphertext: Uint8Array,
  tag: Uint8Array,
): Promise<Uint8Array> {
  const k = await subtle.importKey("raw", key, "AES-GCM", false, ["decrypt"]);
  const joined = new Uint8Array(ciphertext.length + tag.length);
  joined.set(ciphertext);
  joined.set(tag, ciphertext.length);
  return new Uint8Array(
    await subtle.decrypt({ name: "AES-GCM", iv, additionalData: utf8.encode(aad), tagLength: 128 }, k, joined),
  );
}

export interface SealOptions {
  /** 보호 헤더를 바꾼다(변이 사례 — A256KW · A128GCM · 키 더함). 기본 {alg:"dir", enc:"A256GCM", typ}. */
  header?: Record<string, unknown>;
  /** 접두를 바꾼다(변이 사례 — "" · "v2."). 기본 "v1.". */
  prefix?: string;
}

/** 봉인 — 쿠키 값 문자열. IV는 봉인마다 새로(12 B). */
export async function seal(keyHex: string, typ: string, payload: unknown, opts: SealOptions = {}): Promise<string> {
  const headerB64 = b64url(JSON.stringify(opts.header ?? { alg: "dir", enc: "A256GCM", typ }));
  const iv = randomBytes(12);
  const { ciphertext, tag } = await gcmEncrypt(keyBytes(keyHex), iv, headerB64, utf8.encode(JSON.stringify(payload)));
  return `${opts.prefix ?? JWE_PREFIX}${headerB64}..${b64url(iv)}.${b64url(ciphertext)}.${b64url(tag)}`;
}

export interface Unsealed {
  header: Record<string, unknown>;
  headerB64: string;
  ivB64: string;
  ciphertextB64: string;
  tagB64: string;
  payload: Record<string, unknown>;
}

/** 쿠키 값을 compact 다섯 조각으로 가른다(`v1.` 접두 · 조각 5 · 둘째 빈 값이 아니면 던진다). */
export function splitCompact(value: string): string[] {
  if (!value.startsWith(JWE_PREFIX)) {
    throw new Error("oracle: missing v1. prefix");
  }
  const parts = value.slice(JWE_PREFIX.length).split(".");
  if (parts.length !== 5) {
    throw new Error("oracle: compact must have 5 parts");
  }
  if (parts[1] !== "") {
    throw new Error("oracle: encrypted key part must be empty (dir)");
  }
  return parts;
}

/** 복호 — 꼴 · IV 길이 · 태그 길이 · 태그 검증이 하나라도 어긋나면 던진다. */
export async function unseal(keyHex: string, value: string): Promise<Unsealed> {
  const [headerB64, , ivB64, ciphertextB64, tagB64] = splitCompact(value);
  const header = JSON.parse(strictUtf8.decode(fromB64url(headerB64))) as Record<string, unknown>;
  const iv = fromB64url(ivB64);
  const tag = fromB64url(tagB64);
  if (iv.length !== 12) {
    throw new Error("oracle: IV must be 12 bytes");
  }
  if (tag.length !== 16) {
    throw new Error("oracle: tag must be 16 bytes");
  }
  const plain = await gcmDecrypt(keyBytes(keyHex), iv, headerB64, fromB64url(ciphertextB64), tag);
  const payload = JSON.parse(strictUtf8.decode(plain)) as Record<string, unknown>;
  return { header, headerB64, ivB64, ciphertextB64, tagB64, payload };
}

export type JwePart = "header" | "iv" | "ciphertext" | "tag";

/**
 * compact의 한 조각을 바꾼다.
 * header = 같은 뜻 · 다른 바이트(키 순서를 뒤집어 다시 부호화 — AAD만 어긋난다), 그 밖 = 첫 바이트 비트 반전.
 */
export function tamper(value: string, part: JwePart): string {
  const parts = splitCompact(value);
  if (part === "header") {
    const header = JSON.parse(strictUtf8.decode(fromB64url(parts[0]))) as Record<string, unknown>;
    const reordered = Object.fromEntries(Object.entries(header).reverse());
    parts[0] = b64url(JSON.stringify(reordered));
    if (parts[0] === splitCompact(value)[0]) {
      throw new Error("oracle: header tamper produced identical bytes");
    }
  } else {
    const index = { iv: 2, ciphertext: 3, tag: 4 }[part];
    const bytes = fromB64url(parts[index]);
    bytes[0] ^= 0x01;
    parts[index] = b64url(bytes);
  }
  return `${JWE_PREFIX}${parts.join(".")}`;
}
