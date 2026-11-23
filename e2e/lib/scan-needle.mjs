// e2e/lib/scan-needle.mjs — 바늘 스캔(설계 D10 ⑧ · r2 — V-6 · VD-T077-4). Node 내장 모듈만. 런처 메모리의 바늘을 함수 인자로 받는다(파일 · argv 0).
// 바늘 꼴 = 전체 · base64 · base64url(세 정렬) · 퍼센트 인코딩 · SHA-256 hex(대소문자) · 8자 이상 조각(난수 부분이 든 조각만 — 고정 접두만으로 된 글자는 세지 않는다).
// 6자리 코드는 숫자 경계 안의 전체 일치, 가짜 IP · UA는 전체 일치(8자 규칙 밖). 결과는 면별 일치 수뿐이다(일치한 글자 0).
// 압축 · 이미지(trace.zip · video.webm · png)는 풀거나 읽지 못하므로 그 파일 자체를 센다(countArtifacts — 빌드 리뷰 r1 — B-1 ④).
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';

const WINDOW = 8;

// 스캔이 들여다보지 못하는 산출물 확장자(trace · 영상 · 스크린샷)
export const ARTIFACT_EXTENSIONS = Object.freeze(['.zip', '.webm', '.png']);

function b64Cores(buf, url) {
  const out = [];
  for (let k = 0; k < 3; k += 1) {
    let s = Buffer.concat([Buffer.alloc(k), buf]).toString(url ? 'base64url' : 'base64');
    if (url) s = s.replace(/=+$/, '');
    const start = Math.ceil((k * 4) / 3);
    const tail = (k + buf.length) % 3 === 0 ? 0 : 4;
    const core = s.slice(start, Math.max(start, s.length - tail));
    if (core.length >= WINDOW) out.push(core);
  }
  return out;
}

/**
 * @param {{ value: string, kind: 'fragment' | 'exact' | 'code', fixed?: number }} spec
 * @returns {string[]}
 */
export function forms(spec) {
  const v = spec.value;
  if (spec.kind !== 'fragment') {
    const f = new Set([v, encodeURIComponent(v)]);
    if (v.includes('/')) f.add(v.split('/').join('\\/'));
    return [...f];
  }
  const fixed = Math.max(0, Math.min(spec.fixed ?? 0, v.length));
  const buf = Buffer.from(v, 'utf8');
  const sha = crypto.createHash('sha256').update(v).digest('hex');
  const f = new Set([v, encodeURIComponent(v), sha, sha.toUpperCase(), ...b64Cores(buf, false), ...b64Cores(buf, true)]);
  for (let i = Math.max(0, fixed - WINDOW + 1); i + WINDOW <= v.length; i += 1) f.add(v.slice(i, i + WINDOW));
  return [...f];
}

function escapeRe(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function countRe(text, re) {
  let n = 0;
  re.lastIndex = 0;
  while (re.exec(text) !== null) n += 1;
  return n;
}

function countPlain(text, needle) {
  let n = 0;
  let at = text.indexOf(needle);
  while (at !== -1) {
    n += 1;
    at = text.indexOf(needle, at + 1);
  }
  return n;
}

function boundaryRe(form) {
  const head = /^\d/.test(form) ? '(?<![0-9])' : '';
  const tail = /\d$/.test(form) ? '(?![0-9])' : '';
  return new RegExp(head + escapeRe(form) + tail, 'g');
}

/**
 * @param {string} text
 * @param {ReadonlyArray<{ value: string, kind: 'fragment' | 'exact' | 'code', fixed?: number }>} specs
 * @returns {number}
 */
export function countText(text, specs) {
  let n = 0;
  for (const spec of specs) {
    for (const form of forms(spec)) {
      n += spec.kind === 'fragment' ? countPlain(text, form) : countRe(text, boundaryRe(form));
    }
  }
  return n;
}

function decodings(buf) {
  return [buf.toString('latin1'), buf.toString('utf16le'), buf.length > 1 ? buf.subarray(1).toString('utf16le') : ''];
}

/**
 * 디렉터리(또는 파일)를 재귀로 펼친다 — 심볼릭 링크는 따라가지 않는다.
 * @param {string} target
 * @param {readonly string[]} exclude
 * @returns {string[]}
 */
export function listFiles(target, exclude = []) {
  const ex = exclude.map((e) => path.resolve(e).toLowerCase());
  const out = [];
  const visit = (p) => {
    if (ex.includes(path.resolve(p).toLowerCase())) return;
    let st;
    try {
      st = fs.lstatSync(p);
    } catch {
      return;
    }
    if (st.isSymbolicLink()) return;
    if (st.isDirectory()) {
      for (const name of fs.readdirSync(p)) visit(path.join(p, name));
    } else if (st.isFile()) {
      out.push(p);
    }
  };
  visit(target);
  return out;
}

function countFile(file, specs) {
  let buf;
  try {
    buf = fs.readFileSync(file);
  } catch {
    return 0;
  }
  let n = 0;
  for (const text of decodings(buf)) n += countText(text, specs);
  return n;
}

/**
 * 디렉터리 아래(제외 경로 밖)의 바이너리 산출물 수 — 확장자 대소문자 무관.
 * @param {readonly string[]} dirs
 * @param {readonly string[]} exclude
 * @returns {number}
 */
export function countArtifacts(dirs, exclude = []) {
  let n = 0;
  for (const d of dirs) for (const f of listFiles(d, exclude)) if (ARTIFACT_EXTENSIONS.includes(path.extname(f).toLowerCase())) n += 1;
  return n;
}

/**
 * @param {ReadonlyArray<{ value: string, kind: 'fragment' | 'exact' | 'code', fixed?: number }>} specs
 * @param {ReadonlyArray<{ name: string, files?: string[], dirs?: string[], exclude?: string[], texts?: string[] }>} surfaces
 * @returns {Record<string, number>}
 */
export function scanSurfaces(specs, surfaces) {
  const hits = {};
  for (const s of surfaces) {
    let n = 0;
    for (const f of s.files ?? []) n += countFile(f, specs);
    for (const d of s.dirs ?? []) for (const f of listFiles(d, s.exclude ?? [])) n += countFile(f, specs);
    for (const t of s.texts ?? []) n += countText(t, specs);
    hits[s.name] = n;
  }
  return hits;
}
