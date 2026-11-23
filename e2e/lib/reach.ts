// e2e/lib/reach.ts — 도달 분류(설계 D6 reach · D5 실패 분류 · VD-T077-1). 순수 함수 — 호출은 http.ts 감싸개가 한다.
// [gate](빨강 증거)는 Traefik 404 서명이 전부 맞을 때만이다. 서명 자체가 오리진(노드 A Traefik) 도달 증거다(T076 D10 기준값).
// 출력에는 상태 코드 · 어긋난 필드 이름만 싣는다 — 본문 · 헤더 값 0.
import * as crypto from 'node:crypto';

export const AUTH_ORIGIN = 'https://auth.joshuatech.dev';
export const AUTH_HOST = 'auth.joshuatech.dev';
export const REACH_URL = `${AUTH_ORIGIN}/`;
// 대조 호스트 — 무자격 401은 엣지(Access) 응답이라 오리진을 증명하지 못한다 → INFO만(설계 D6 · r1 — A-2)
export const CONTROL_URL = 'https://identity-m2m-dev.joshuatech.dev/health';

export const TRAEFIK_404 = {
  status: 404,
  contentType: 'text/plain; charset=utf-8',
  length: 19,
  sha256: 'b16e15764b8bc06c5c3f9f19bc8b99fa48e7894aa5a6ccdad65da49bbf564793',
} as const;

// Authentik 200 HTML 표식(추론 — VD-T080-a · VD-T081-a에서 확정)
const AUTHENTIK_MARKERS = ['ak-flow-executor', 'ak-interface-user', 'ak-interface-admin'];
// Authentik 범주 리다이렉트 경로(추론 — VD-T080-a)
const AUTHENTIK_PATH_PREFIXES = ['/if/', '/flows/'];

export interface ReachObservation {
  status: number;
  contentType: string | null;
  bodyLength: number;
  bodySha256: string;
  cfCacheStatus: string | null;
  location: string | null;
  authentikMarker: boolean;
}

export type ReachVerdict =
  | { ok: true; code: 'authentik-redirect' | 'authentik-page' }
  | { ok: false; prefix: 'gate' | 'env' | 'product'; code: string };

export function sha256Hex(body: Buffer): string {
  return crypto.createHash('sha256').update(body).digest('hex');
}

export function hasAuthentikMarker(body: Buffer): boolean {
  const text = body.toString('utf8');
  return AUTHENTIK_MARKERS.some((m) => text.includes(m));
}

function mediaType(contentType: string | null): string {
  return (contentType ?? '').split(';')[0].trim().toLowerCase();
}

function isAuthentikRedirect(location: string | null): boolean {
  if (!location) return false;
  let u: URL;
  try {
    u = new URL(location, REACH_URL);
  } catch {
    return false;
  }
  if (u.protocol !== 'https:' || u.host !== AUTH_HOST) return false;
  return AUTHENTIK_PATH_PREFIXES.some((p) => u.pathname.startsWith(p));
}

function isAccessRedirect(location: string | null): boolean {
  if (!location) return false;
  try {
    const u = new URL(location, REACH_URL);
    return u.protocol === 'https:' && u.hostname.endsWith('.cloudflareaccess.com');
  } catch {
    return false;
  }
}

function signatureMismatch(o: ReachObservation): string[] {
  const m: string[] = [];
  if ((o.contentType ?? '') !== TRAEFIK_404.contentType) m.push('content-type');
  if (o.bodyLength !== TRAEFIK_404.length) m.push('length');
  if (o.bodySha256 !== TRAEFIK_404.sha256) m.push('sha256');
  if ((o.cfCacheStatus ?? '').toUpperCase() === 'HIT') m.push('cf-cache-status');
  return m;
}

export function classifyReach(o: ReachObservation): ReachVerdict {
  const s = o.status;
  if (s === 404) {
    const mismatch = signatureMismatch(o);
    if (mismatch.length === 0) return { ok: false, prefix: 'gate', code: 'authentik-absent until T080' };
    return { ok: false, prefix: 'product', code: `reach-unexpected status=404 mismatch=${mismatch.sort().join(',')}` };
  }
  if (s >= 500 && s <= 599) return { ok: false, prefix: 'env', code: `origin status=${s}` };
  if (s === 302 && isAuthentikRedirect(o.location)) return { ok: true, code: 'authentik-redirect' };
  if (s === 302 && isAccessRedirect(o.location)) return { ok: false, prefix: 'product', code: 'reach-access status=302' };
  if (s === 401) return { ok: false, prefix: 'product', code: 'reach-access status=401' };
  if (s === 200 && mediaType(o.contentType) === 'text/html' && o.authentikMarker) return { ok: true, code: 'authentik-page' };
  return { ok: false, prefix: 'product', code: `reach-unexpected status=${s}` };
}

export function classifyReachError(code: string): ReachVerdict {
  return { ok: false, prefix: 'env', code: `network (${code})` };
}

export function reachReason(v: ReachVerdict): string {
  return v.ok ? v.code : `[${v.prefix}] ${v.code}`;
}

export function observe(status: number, headers: Record<string, string>, body: Buffer): ReachObservation {
  return {
    status,
    contentType: headers['content-type'] ?? null,
    bodyLength: body.length,
    bodySha256: sha256Hex(body),
    cfCacheStatus: headers['cf-cache-status'] ?? null,
    location: headers['location'] ?? null,
    authentikMarker: hasAuthentikMarker(body),
  };
}
