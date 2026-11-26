// e2e/lib/launch.mjs — e2e 런처(설계 D9 · D10 ⑧ · r1 — A-6 · B-14 · A-7 · r2 — V-2 · V-3 · V-4 · V-6 · T087 — t086-design.md D10 ③). Node 내장 모듈만.
// 사용: node e2e/lib/launch.mjs <selftest|selftest-browser|needle|list|live-red|site|site-red>
//   selftest · selftest-browser — 브라우저 0 / 로컬 setContent만. 끝 줄 '<n> passed, <m> failed'(run-all e2e-selftest 슬롯이 읽는다).
//   needle — 바늘을 실행마다 만들어 자식 env로만 넘기고 두 실행 + 스캔. 실행 1 = 감싸개를 지나는 의도 실패 9 · 모든 면 hits 0 · 루트 바이너리 산출물 0,
//            실행 2 = 감싸개 없이 같은 노출 경로를 밟는 경로별 양성 대조(빌드 리뷰 r1 — B-1). 끝 줄 'needle=PASS|FAIL …'(면별 hits 수 · 경로별 대조 수).
//   list — JT_E2E_LIVE=1 · JT_E2E_NEEDLE=1 · JT_E2E_SITE=1(대상 = 런처 상수 http://127.0.0.1:9 · local)을 따로 준 --list 세 번 → 프로젝트별 수.
//   live-red — 공개 호스트 무자격 GET(빨강 관찰 — 컨트롤러 몫). 자식 env = 허용 목록 + JT_E2E_LIVE=1. 끝 줄에 gate-reach=<n>/<live 시험 수>(리뷰 A-3).
//   site — T087 site 프로젝트. 런처 env의 BASE_URL · JT_E2E_SITE_MODE를 대상으로 넘긴다(검증은 설정 — 값은 출력 0). 자식 env = 허용 목록 + JT_E2E_SITE=1 · BASE_URL ·
//          JT_E2E_SITE_MODE. 끝 줄 'site passed=… failed=… skipped=… allowed-skip=<0|1> child-exit=… root=…' — exit 0 = 자식 0 · 실패 0 · skip = allowed-skip ·
//          통과 ≥ 1 · 루트 삭제(allowed-skip = local이고 'INFO T087 health skipped mode=local' 줄이 있을 때 1). prod 모드는 공개 apex를 부른다 — 컨트롤러 지시가 있을 때만.
//   site-red — 루프백 빈 포트(닫힌 포트)를 local 대상으로 site를 돌린다(빨강 관찰 — 공개 호스트 0). 끝 줄 'site-red … gate-site=<g>/<failed> …' —
//          g = 중계한 줄 가운데 'T087 reach FAIL [gate] site-absent until T091' 줄 수(올바른 이유의 빨강은 g = failed일 때뿐).
// 공통: 블록 소유 루트 os.tmpdir()/jt-e2e/<runId>(outputDir · evidence · 로그 · 자식 TEMP/TMP) · 자식 env 허용 목록 · shell 0 ·
// 출력은 판정 줄 · env 이름 · 수뿐(값 0 — static-gate 이름 붙은 예외) · finally에서 루트 삭제 + 존재 0 확인.
import { spawn, spawnSync } from 'node:child_process';
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import { createRequire } from 'node:module';
import * as net from 'node:net';
import * as os from 'node:os';
import * as path from 'node:path';
import { fileURLToPath } from 'node:url';
import { countArtifacts, scanSurfaces } from './scan-needle.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(HERE, '..', '..');
export const CONFIG_PATH = path.join(REPO_ROOT, 'playwright.config.ts');

// 자식 env 허용 목록(D9 — r2 — V-3 · V-4 · VD-T077-3 최종): 기본 이름 + 런처 공통 + 모드 값. KUBECONFIG · JT_E2E_BLOCK은 어느 모드에서도 0.
export const BASE_ENV_NAMES = ['SystemRoot', 'PATH', 'USERPROFILE', 'LOCALAPPDATA', 'TEMP', 'TMP'];
export const COMMON_ENV_NAMES = ['JT_E2E_RUN_ID', 'JT_E2E_ROOT', 'JT_E2E_OUTPUT_DIR', 'JT_E2E_EVIDENCE_DIR'];

// 바늘 꼴(D10 ⑧ — 값은 실행마다 난수). env-contract.ts의 NEEDLE_PREFIX와 같아야 한다(selftest가 고정).
export const NEEDLE_PREFIX = 'JTNEEDLE-';
const NAMES = {
  password: 'JT_E2E_SECRET_PASSWORD',
  codes: 'JT_E2E_SECRET_TOTP_CODES',
  step0: 'JT_E2E_TOTP_STEP0',
  needleSet: 'JT_E2E_NEEDLE_SET',
};

export const MODES = ['selftest', 'selftest-browser', 'needle', 'list', 'live-red', 'site', 'site-red'];
const CHILD_TIMEOUT_MS = 570_000;

// T087 site 값(D10 ② ③) — 이 세 이름만 site 모드의 자식에 더한다(값은 런처가 정한 대상에서 · 런처 env를 그대로 복사하지 않는다)
export const SITE_ENV_NAMES = ['JT_E2E_SITE', 'BASE_URL', 'JT_E2E_SITE_MODE'];
// list의 site --list 대상(연결하지 않는다 — 시험 수만 센다)
export const LIST_SITE_TARGET = Object.freeze({ base: 'http://127.0.0.1:9', mode: 'local' });
// local 실행의 h-7 skip 표식 — 이 줄이 있을 때만 skip 1을 받아들인다
export const SITE_HEALTH_SKIP_LINE = 'INFO T087 health skipped mode=local';
const SURFACES = ['log', 'root', 'test-results', 'auth', 'tmp-playwright', 'git-status'];

// 실행 1의 의도 실패 9건 — 제목 → 첫 오류 줄(포트는 <port>로 맞춘다). 다른 실패(브라우저 부재 등)는 메시지가 달라 FAIL이다.
// 빌드 리뷰 r1 — B-1: nd-2는 값이 칸에 남은 채 멈추고, nd-3b(응답 헤더 뒤 끊김 — Set-Cookie) · nd-8(쿼리 URL 탐색 시간 초과)을 더했으며,
// nd-5는 대기 중 쿼리 URL로 다시 탐색하는 실제 callback 꼴이다. 설계 D10 ⑧의 「정확히 7건」 → 9건(정정 노트 후보).
export const EXPECTED_NEEDLE_FAILURES = Object.freeze({
  'nd-1 secret input fails': 'secret-input password failed',
  'nd-2 step transition fails while the values stay in the fields': 'marker totp-step failed (timeout)',
  'nd-3 connection drop with needle headers': 'GET http://127.0.0.1:<port>/nd-3 failed (reset)',
  'nd-3b connection drop after needle response headers': 'GET http://127.0.0.1:<port>/nd-3b failed (reset)',
  'nd-4 server error with needle headers': 'GET http://127.0.0.1:<port>/nd-4 failed (status 500)',
  'nd-5 waitForURL timeout while the page re-navigates to a needle query url': 'WAIT http://127.0.0.1:<port>/nd-5-never failed (timeout)',
  'nd-6 sessions rows mismatch': 'sessions rows',
  'nd-7 evidence mask target missing': '[product] mask-target-missing',
  'nd-8 navigation timeout on a needle query url': 'GOTO http://127.0.0.1:<port>/nd-8 failed (timeout)',
});

// 실행 2(needle-control)의 의도 실패 1건 — 페이지 스냅숏 경로의 대조는 실패한 시험이 남기는 error-context로만 보인다.
export const EXPECTED_CONTROL_FAILURES = Object.freeze({
  'c-pgs page snapshot of a failed test lands in the preserved output': 'needle-control page-snapshot path',
});

// 대조 바늘 — 노출 경로마다 하나(빌드 리뷰 r1 — B-1). 실행 2가 감싸개 없이 같은 경로를 밟아 그 경로의 대조 바늘이 정해진 면에서 잡혀야 한다
// (그래야 실행 1의 「hits 0」이 공허하지 않다). 꼬리표는 16진이 아닌 글자로 시작한다 — 가장 짧은 조각(고정 7자 + 난수 1자)이 경로끼리 겹치지 않아 경로별로 센다.
export const CONTROL_TAGS = Object.freeze({
  control: 'ctl-log-', // console 출력 — 스캐너 자체의 로그 면 양성 대조
  controlFill: 'ctl-inp-', // fill 오류의 call log(nd-1 · 감싸개 변이 M2)
  controlRequest: 'ctl-req-', // 요청 헤더(cookie)의 call log(nd-3 · M1)
  controlSetCookie: 'ctl-sck-', // 응답 헤더(Set-Cookie)의 call log(nd-3b)
  controlUrl: 'ctl-url-', // waitForURL 오류의 「navigated to」 쿼리(nd-5)
  controlGoto: 'ctl-nav-', // goto 오류의 탐색 URL 쿼리(nd-8 — 리다이렉트 뒤 URL은 1.65.1 오류에 실리지 않아 직접 탐색 꼴)
  controlFile: 'ctl-pgs-', // 실패 시험의 페이지 스냅숏 → 보존된 error-context(nd-2 · nd-6 · nd-7)
});
export const CONTROL_SURFACE = Object.freeze({
  control: 'log',
  controlFill: 'log',
  controlRequest: 'log',
  controlSetCookie: 'log',
  controlUrl: 'log',
  controlGoto: 'log',
  controlFile: 'root',
});
const CONTROL_SHORT = Object.freeze({ control: 'log', controlFill: 'inp', controlRequest: 'req', controlSetCookie: 'sck', controlUrl: 'url', controlGoto: 'nav', controlFile: 'pgs' });

export function makeRunId(now = new Date(), hex = crypto.randomBytes(3).toString('hex')) {
  const p = (n) => String(n).padStart(2, '0');
  const ts = `${now.getUTCFullYear()}${p(now.getUTCMonth() + 1)}${p(now.getUTCDate())}T${p(now.getUTCHours())}${p(now.getUTCMinutes())}${p(now.getUTCSeconds())}Z`;
  return `t077-${ts}-${hex}`;
}

export function planLayout(tmpdir, runId) {
  const root = path.join(tmpdir, 'jt-e2e', runId);
  return { root, out: path.join(root, 'out'), evidence: path.join(root, 'evidence'), logs: path.join(root, 'logs'), tmp: path.join(root, 'tmp') };
}

// 바늘 두 실행은 루트를 따로 만든다(컨트롤러 N-1 — 빌더 선택). 실행 1의 스캔 묶음에는 대조 바늘이 없다.
export function planNeedleRuns(tmpdir, runId) {
  return { run1: planLayout(tmpdir, `${runId}-n1`), run2: planLayout(tmpdir, `${runId}-n2`) };
}

export function makeNeedleSet(now = Date.now()) {
  const hex = (n) => crypto.randomBytes(n).toString('hex');
  const codes = Array.from({ length: 20 }, () => String(crypto.randomInt(0, 1_000_000)).padStart(6, '0')).join(',');
  const set = {
    password: `${NEEDLE_PREFIX}pw-${hex(6)}`,
    codes,
    step0: String(Math.floor(now / 30_000)),
    cookie: `${NEEDLE_PREFIX}ck-${hex(8)}`,
    authorization: `${NEEDLE_PREFIX}az-${hex(8)}`,
    query: `${NEEDLE_PREFIX}q-${hex(6)}`,
    ip: `203.0.113.${crypto.randomInt(1, 255)}`,
    ua: `${NEEDLE_PREFIX}UA/${hex(4)}`,
  };
  for (const [k, tag] of Object.entries(CONTROL_TAGS)) set[k] = `${NEEDLE_PREFIX}${tag}${hex(6)}`;
  return set;
}

// 'run1' = 대조 바늘을 뺀 실행 1 바늘 · 'all' = 대조 바늘까지
export function needleSpecs(set, which) {
  const frag = (name, value, tag) => ({ name, value, kind: 'fragment', fixed: (NEEDLE_PREFIX + tag).length });
  const specs = [
    frag('password', set.password, 'pw-'),
    ...set.codes.split(',').map((c, i) => ({ name: `code${i}`, value: c, kind: 'code' })),
    frag('cookie', set.cookie, 'ck-'),
    frag('authorization', set.authorization, 'az-'),
    frag('query', set.query, 'q-'),
    { name: 'ip', value: set.ip, kind: 'exact' },
    { name: 'ua', value: set.ua, kind: 'exact' },
  ];
  if (which === 'run1') return specs;
  if (which === 'all') return [...specs, ...Object.values(controlSpecs(set)).flat()];
  throw new Error('launch: unknown needle spec set');
}

// 경로별 대조 바늘 스캔 묶음(경로마다 따로 센다)
export function controlSpecs(set) {
  const out = {};
  for (const [k, tag] of Object.entries(CONTROL_TAGS)) out[k] = [{ name: k, value: set[k], kind: 'fragment', fixed: (NEEDLE_PREFIX + tag).length }];
  return out;
}

export function siteValues(target) {
  if (!target || typeof target.base !== 'string' || typeof target.mode !== 'string') throw new Error('launch: site target missing');
  return { JT_E2E_SITE: '1', BASE_URL: target.base, JT_E2E_SITE_MODE: target.mode };
}

// extra = needle 묶음(needle) · 대상 { base, mode }(site · site-red)
export function modeValues(mode, extra) {
  switch (mode) {
    case 'selftest':
    case 'selftest-browser':
      return {};
    case 'list-live':
    case 'live-red':
      return { JT_E2E_LIVE: '1' };
    case 'list-needle':
      return { JT_E2E_NEEDLE: '1' };
    case 'list-site':
      return siteValues(LIST_SITE_TARGET);
    case 'site':
    case 'site-red':
      return siteValues(extra);
    case 'needle':
      return {
        JT_E2E_NEEDLE: '1',
        [NAMES.password]: extra.password,
        [NAMES.codes]: extra.codes,
        [NAMES.step0]: extra.step0,
        [NAMES.needleSet]: JSON.stringify(extra),
      };
    default:
      throw new Error('launch: unknown mode');
  }
}

// site 모드의 대상 = 런처 env의 BASE_URL · JT_E2E_SITE_MODE(이름은 대소문자 무관 — Windows env). 하나라도 없으면 null. 꼴 검증의 정본은 설정(validateSiteTarget)이다.
export function readSiteTarget(source) {
  const base = lookup(source, 'BASE_URL');
  const mode = lookup(source, 'JT_E2E_SITE_MODE');
  if (typeof base !== 'string' || base.length === 0 || typeof mode !== 'string' || mode.length === 0) return null;
  return { base, mode };
}

// 사전 검사 — 설정의 validateSiteTarget(e2e/lib/site.ts — 정본)과 같은 규칙이다. 설정 로드의 throw는 Playwright 오류 줄이라 중계되지 않으므로(끝 줄 failed=-1만 남는다)
// 자식을 띄우기 전에 값 없는 [guard] 줄로 이유를 낸다. 두 판정이 같은지는 selftest launch가 사례 표로 고정한다.
export const SITE_TARGET_GUARD_LINE = '[guard] site-target-not-allowed — local = http://127.0.0.1:<port> | http://localhost:<port> · prod = https://joshuatech.dev';
const SITE_LOCAL_ORIGIN = /^http:\/\/(127\.0\.0\.1|localhost):([0-9]{1,5})$/;

export function siteTargetAllowed(target) {
  if (!target || typeof target.base !== 'string') return false;
  if (target.mode === 'prod') return target.base === 'https://joshuatech.dev';
  if (target.mode !== 'local') return false;
  const m = SITE_LOCAL_ORIGIN.exec(target.base);
  if (!m) return false;
  const port = Number(m[2]);
  if (!Number.isInteger(port) || port < 1 || port > 65535) return false;
  try {
    return new URL(target.base).origin === target.base;
  } catch {
    return false;
  }
}

function lookup(source, name) {
  if (Object.prototype.hasOwnProperty.call(source, name)) return source[name];
  const lower = name.toLowerCase();
  for (const k of Object.keys(source)) if (k.toLowerCase() === lower) return source[k];
  return undefined;
}

export function buildChildEnv(source, layout, runId, values) {
  const env = {};
  const missing = [];
  for (const n of ['SystemRoot', 'PATH', 'USERPROFILE', 'LOCALAPPDATA']) {
    const v = lookup(source, n);
    if (typeof v === 'string' && v.length > 0) env[n] = v;
    else missing.push(n);
  }
  if (missing.length > 0) throw new Error(`launch: missing base env ${missing.join(',')}`);
  env.TEMP = layout.tmp;
  env.TMP = layout.tmp;
  env.JT_E2E_RUN_ID = runId;
  env.JT_E2E_ROOT = layout.root;
  env.JT_E2E_OUTPUT_DIR = layout.out;
  env.JT_E2E_EVIDENCE_DIR = layout.evidence;
  for (const [k, v] of Object.entries(values)) env[k] = v;
  return env;
}

export function expectedEnvNames(mode) {
  const extra = mode === 'needle' ? makeNeedleSet() : mode === 'site' || mode === 'site-red' ? LIST_SITE_TARGET : undefined;
  const values = modeValues(mode, extra);
  return [...BASE_ENV_NAMES, ...COMMON_ENV_NAMES, ...Object.keys(values)].sort();
}

const ANSI = new RegExp(String.fromCharCode(27) + '\\[[0-9;]*[A-Za-z]', 'g');

export function stripAnsi(s) {
  return String(s).replace(ANSI, '');
}

function lines(text) {
  return stripAnsi(text).split(/\r?\n/);
}

export function parseSummary(text) {
  const r = { passed: 0, failed: 0, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 0 };
  let found = false;
  for (const line of lines(text)) {
    let m;
    if ((m = /^  (\d+) passed \(.+\)$/.exec(line))) r.passed = Number(m[1]);
    else if ((m = /^  (\d+) failed$/.exec(line))) r.failed = Number(m[1]);
    else if ((m = /^  (\d+) flaky$/.exec(line))) r.flaky = Number(m[1]);
    else if ((m = /^  (\d+) skipped$/.exec(line))) r.skipped = Number(m[1]);
    else if ((m = /^  (\d+) interrupted$/.exec(line))) r.interrupted = Number(m[1]);
    else if ((m = /^  (\d+) did not run$/.exec(line))) r.didNotRun = Number(m[1]);
    else if (/^  1 error was not a part of any test/.test(line)) r.errors = 1;
    else if ((m = /^  (\d+) errors were not a part of any test/.exec(line))) r.errors = Number(m[1]);
    else continue;
    found = true;
  }
  return found ? r : null;
}

function failedTotal(s) {
  return s.failed + s.flaky + s.skipped + s.interrupted + s.didNotRun + s.errors;
}

export function selftestEndLine(s) {
  if (!s) return '0 passed, 1 failed';
  const failed = failedTotal(s);
  if (s.passed === 0 && failed === 0) return '0 passed, 1 failed';
  return `${s.passed} passed, ${failed} failed`;
}

const FAILURE_HEADER = /^  \d+\) \[[^\]]+\] › .+?:\d+:\d+ › (.+?)(?: ─+)?\s*$/;
const SUMMARY_LINE = /^  \d+ (passed|failed|flaky|skipped|interrupted|did not run)\b/;

function normalizePort(s) {
  return s.replace(/127\.0\.0\.1:\d+/g, '127.0.0.1:<port>');
}

export function parseFailures(text) {
  const out = [];
  let cur = null;
  for (const line of lines(text)) {
    const h = FAILURE_HEADER.exec(line);
    if (h) {
      cur = { title: h[1].trim(), message: null };
      out.push(cur);
      continue;
    }
    if (SUMMARY_LINE.test(line)) {
      cur = null;
      continue;
    }
    if (cur && cur.message === null) {
      const m = /^    [A-Za-z]*Error: (.*)$/.exec(line);
      if (m) cur.message = normalizePort(m[1]);
    }
  }
  return out.map((f) => ({ title: f.title, message: f.message ?? '' }));
}

// 요약 블록의 실패 · flaky · interrupted 시험 제목(소스 글자 — 값 0)
function summaryTitles(text) {
  const out = [];
  let inBlock = false;
  for (const line of lines(text)) {
    if (/^  \d+ (failed|flaky|interrupted)$/.test(line)) {
      inBlock = true;
      continue;
    }
    if (inBlock && /^    \[[^\]]+\] › /.test(line)) {
      out.push(line.trim().replace(/ ─+$/, '').split(' › ').join(' > '));
      continue;
    }
    inBlock = false;
  }
  return out;
}

export function parseListCounts(text) {
  const counts = {};
  let n = 0;
  let total = null;
  for (const line of lines(text)) {
    const m = /^  \[([^\]]+)\] › /.exec(line);
    if (m) {
      counts[m[1]] = (counts[m[1]] ?? 0) + 1;
      n += 1;
      continue;
    }
    const t = /^Total: (\d+) tests? in \d+ files?$/.exec(line);
    if (t) total = Number(t[1]);
  }
  if (total === null || total !== n) return null;
  return counts;
}

// out.ts 꼴의 줄만 옮긴다(자식 출력의 다른 줄 — 오류 본문 · 콘솔 출력 — 은 옮기지 않는다)
const RELAY_SHAPES = [
  /^T0\d\d [a-z][a-z0-9-]* (PASS|FAIL)( |$)/,
  /^INFO [\x20-\x7e]/,
  /^\[(gate|product|env|decision|guard|state)\] [\x20-\x7e]/,
  /^SUMMARY [\x20-\x7e]/,
];

export function relay(text) {
  return lines(text).filter((l) => {
    if (!RELAY_SHAPES.some((re) => re.test(l))) return false;
    const at = l.indexOf(' — ');
    const machine = at === -1 ? l : l.slice(0, at);
    return /^[\x20-\x7e]+$/.test(machine) && !/[\x00-\x1f\x7f]/.test(l);
  });
}

function fmtHits(h) {
  return SURFACES.map((s) => `${s}:${typeof h[s] === 'number' ? h[s] : -1}`).join(',');
}

function cleanSummary(s, passed, failed) {
  return !!s && s.passed === passed && s.failed === failed && s.flaky === 0 && s.skipped === 0 && s.interrupted === 0 && s.didNotRun === 0 && s.errors === 0;
}

// 기대 목록과 제목 · 메시지가 정확히 같은 실패 수(같은 제목은 한 번만)
function matchFailures(failures, expected) {
  const seen = new Set();
  let matched = 0;
  for (const f of failures) {
    if (seen.has(f.title)) continue;
    seen.add(f.title);
    if (Object.prototype.hasOwnProperty.call(expected, f.title) && expected[f.title] === f.message) matched += 1;
  }
  return matched;
}

function fmtControls(controlHits) {
  return Object.keys(CONTROL_TAGS)
    .map((k) => {
      const surface = CONTROL_SURFACE[k];
      const h = controlHits[k];
      return `${CONTROL_SHORT[k]}@${surface}:${h && typeof h[surface] === 'number' ? h[surface] : -1}`;
    })
    .join(',');
}

// needle=PASS 조건(설계 D10 ⑧ + 빌드 리뷰 r1 — B-1):
//   실행 1 — exit 1 · 의도 실패 정확히 9 · 메시지 9/9 · 모든 면 hits 0 · 루트의 바이너리 산출물(zip · webm · png) 0
//   실행 2 — exit 1 · 의도 실패 1(페이지 스냅숏 대조) · 나머지 통과 · 경로마다 대조 바늘이 정해진 면에서 ≥ 1 · 산출물 양성 대조 ≥ 1 · 실행 1 바늘 0
export function judgeNeedle(x) {
  const { run1, run2 } = x;
  const n1 = Object.keys(EXPECTED_NEEDLE_FAILURES).length;
  const n2 = Object.keys(EXPECTED_CONTROL_FAILURES).length;
  const nControls = Object.keys(CONTROL_TAGS).length;
  const m1 = matchFailures(run1.failures, EXPECTED_NEEDLE_FAILURES);
  const m2 = matchFailures(run2.failures, EXPECTED_CONTROL_FAILURES);
  const controlsOk = Object.keys(CONTROL_TAGS).every((k) => {
    const h = run2.controlHits[k];
    return !!h && SURFACES.every((s) => typeof h[s] === 'number' && h[s] >= 0) && h[CONTROL_SURFACE[k]] >= 1;
  });
  const conds = [
    run1.exit === 1,
    cleanSummary(run1.summary, 0, n1),
    run1.failures.length === n1 && m1 === n1,
    SURFACES.every((s) => run1.hits[s] === 0),
    run1.artifacts === 0,
    run2.exit === 1 && cleanSummary(run2.summary, nControls - n2, n2),
    run2.failures.length === n2 && m2 === n2,
    controlsOk,
    typeof run2.artifacts === 'number' && run2.artifacts >= 1,
    SURFACES.every((s) => run2.otherHits[s] === 0),
  ];
  const pass = conds.every(Boolean);
  const failed1 = run1.summary ? run1.summary.failed : -1;
  const passed2 = run2.summary ? run2.summary.passed : -1;
  const failed2 = run2.summary ? run2.summary.failed : -1;
  const line =
    `needle=${pass ? 'PASS' : 'FAIL'} run1-exit=${run1.exit} run1-failed=${failed1} run1-messages=${m1}/${n1} run1-hits=${fmtHits(run1.hits)} run1-artifacts=${run1.artifacts}` +
    ` run2-exit=${run2.exit} run2-passed=${passed2} run2-failed=${failed2} run2-messages=${m2}/${n2} controls=${fmtControls(run2.controlHits)} run2-artifacts=${run2.artifacts} run2-other-hits=${fmtHits(run2.otherHits)}`;
  return { pass, line };
}

// live-red 「올바른 이유의 빨강」 계수(빌드 리뷰 r1 — A-3): 중계한 줄 가운데 reach · reach-auth의 Traefik 404 서명 [gate] 줄 수
const GATE_REACH = /^T07[79] reach(-auth)? FAIL \[gate\] authentik-absent until T080( — |$)/;

export function countGateReach(lines) {
  return lines.filter((l) => GATE_REACH.test(l)).length;
}

// 끝 줄 — gate-reach=<n>/<live 시험 수>. exit는 D9 그대로(자식 exit 0 · 잔여 줄 · 루트 삭제일 때만 0).
export function liveRedEndLine({ summary, gateReach, exit, residue, cleaned }) {
  const failed = summary ? failedTotal(summary) : -1;
  const total = summary ? summary.passed + failed : -1;
  return `live-red passed=${summary ? summary.passed : 0} failed=${failed} gate-reach=${gateReach}/${total} child-exit=${exit} auth-residue=${residue ? 'ok' : 'missing'} root=${cleaned ? 'removed' : 'left'}`;
}

// ---- T087 site · site-red(D10 ③) — skip은 실패와 따로 센다(local의 h-7 skip만 허용) ----
function siteFailed(s) {
  return s.failed + s.flaky + s.interrupted + s.didNotRun + s.errors;
}

export function allowedSkip(siteMode, relayedLines) {
  return siteMode === 'local' && relayedLines.includes(SITE_HEALTH_SKIP_LINE) ? 1 : 0;
}

export function siteEndLine({ summary, allowed, exit, cleaned }) {
  return `site passed=${summary ? summary.passed : 0} failed=${summary ? siteFailed(summary) : -1} skipped=${summary ? summary.skipped : 0} allowed-skip=${allowed} child-exit=${exit} root=${cleaned ? 'removed' : 'left'}`;
}

// exit 0 = 자식 0 · 실패 0 · skip = 허용 수 · 통과 ≥ 1(빈 초록 0) · 루트 삭제
export function siteOk({ summary, allowed, exit, cleaned }) {
  return !!summary && exit === 0 && siteFailed(summary) === 0 && summary.skipped === allowed && summary.passed > 0 && cleaned === true;
}

// site-red 「올바른 이유의 빨강」 계수: 중계한 줄 가운데 reach의 루프백 거부 + 스캐폴드 없음 [gate] 줄 수
const GATE_SITE = /^T087 reach FAIL \[gate\] site-absent until T091( — |$)/;

export function countGateSite(lines) {
  return lines.filter((l) => GATE_SITE.test(l)).length;
}

export function siteRedEndLine({ summary, gateSite, exit, cleaned }) {
  const failed = summary ? siteFailed(summary) : -1;
  return `site-red passed=${summary ? summary.passed : 0} failed=${failed} skipped=${summary ? summary.skipped : 0} gate-site=${gateSite}/${failed} child-exit=${exit} root=${cleaned ? 'removed' : 'left'}`;
}

// ---- list(세 번의 --list) ----
function listCount(c, k) {
  return c && typeof c[k] === 'number' ? c[k] : 0;
}

export function listCountsAgree(live, needle, site) {
  if (!live || !needle || !site) return false;
  return ['selftest', 'selftest-browser'].every((k) => listCount(live, k) === listCount(needle, k) && listCount(live, k) === listCount(site, k));
}

export function listEndLine({ live, needle, site, ok }) {
  const n = listCount;
  return `list live=${n(live, 'live')} needle=${n(needle, 'needle')} needle-control=${n(needle, 'needle-control')} site=${n(site, 'site')} selftest=${n(live, 'selftest')} selftest-browser=${n(live, 'selftest-browser')} result=${ok ? 'ok' : 'FAIL'}`;
}

export function resolveCli(repoRoot = REPO_ROOT) {
  try {
    const req = createRequire(path.join(repoRoot, 'package.json'));
    const pkgPath = req.resolve('@playwright/test/package.json');
    const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
    const bin = typeof pkg.bin === 'string' ? pkg.bin : pkg.bin && pkg.bin.playwright;
    if (!bin) return null;
    const cli = path.resolve(path.dirname(pkgPath), bin);
    return fs.existsSync(cli) ? { cli, version: String(pkg.version) } : null;
  } catch {
    return null;
  }
}

function insideRepo(p) {
  const rel = path.relative(REPO_ROOT, p);
  return rel === '' || (!rel.startsWith('..') && !path.isAbsolute(rel));
}

function say(line) {
  process.stdout.write(line + '\n');
}

function runChild(cli, project, extraArgs, env, layout, label) {
  for (const d of [layout.logs, layout.tmp, layout.out, layout.evidence]) fs.mkdirSync(d, { recursive: true });
  const outFile = path.join(layout.logs, `${label}.stdout.log`);
  const errFile = path.join(layout.logs, `${label}.stderr.log`);
  const outFd = fs.openSync(outFile, 'w');
  const errFd = fs.openSync(errFile, 'w');
  const args = [cli, 'test', '--config', CONFIG_PATH, ...(project ? [`--project=${project}`] : []), ...extraArgs];
  return new Promise((resolve) => {
    let timedOut = false;
    let settled = false;
    const finish = (code) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      for (const fd of [outFd, errFd]) {
        try {
          fs.closeSync(fd);
        } catch {
          // 이미 닫혔다
        }
      }
      const read = (f) => {
        try {
          return fs.readFileSync(f, 'utf8');
        } catch {
          return '';
        }
      };
      resolve({ exit: timedOut ? -2 : code, stdout: read(outFile), stderr: read(errFile), outFile, errFile });
    };
    let child;
    try {
      child = spawn(process.execPath, args, { cwd: REPO_ROOT, env, stdio: ['ignore', outFd, errFd], shell: false, windowsHide: true });
    } catch {
      finish(-1);
      return;
    }
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill();
    }, CHILD_TIMEOUT_MS);
    child.on('error', () => finish(-1));
    child.on('close', (code) => finish(typeof code === 'number' ? code : -1));
  });
}

function removeRoot(layout) {
  try {
    fs.rmSync(layout.root, { recursive: true, force: true, maxRetries: 10, retryDelay: 300 });
  } catch {
    // 아래 존재 확인이 판정한다
  }
  const gone = !fs.existsSync(layout.root);
  try {
    fs.rmdirSync(path.dirname(layout.root));
  } catch {
    // jt-e2e 디렉터리에 다른 실행이 남아 있으면 둔다
  }
  return gone;
}

function tmpPlaywrightDirs() {
  const t = os.tmpdir();
  try {
    return fs.readdirSync(t).filter((n) => n.toLowerCase().startsWith('playwright')).map((n) => path.join(t, n));
  } catch {
    return [];
  }
}

function gitStatusText() {
  const git = spawnSync('git', ['-C', REPO_ROOT, 'status', '--porcelain', '--ignored', '--', 'e2e', 'test-results', 'playwright-report', 'blob-report'], { encoding: 'utf8', shell: false, windowsHide: true });
  return git.status === 0 ? { ok: true, text: git.stdout ?? '' } : { ok: false, text: '' };
}

function scanAll(specs, layout, logFiles, git = gitStatusText()) {
  const hits = scanSurfaces(specs, [
    { name: 'log', files: logFiles },
    { name: 'root', dirs: [layout.root], exclude: [layout.logs] },
    { name: 'test-results', dirs: [path.join(REPO_ROOT, 'test-results')] },
    { name: 'auth', dirs: [path.join(REPO_ROOT, 'e2e', '.auth')] },
    { name: 'tmp-playwright', dirs: tmpPlaywrightDirs() },
    { name: 'git-status', texts: [git.text] },
  ]);
  if (!git.ok) hits['git-status'] = -1;
  return hits;
}

// 루트(로그 · 증거 밖)의 바이너리 산출물 수 — 스캐너가 풀지 못하는 압축 · 이미지 자체를 hit로 센다(빌드 리뷰 r1 — B-1 ④)
function artifactsIn(layout) {
  return countArtifacts([layout.root], [layout.logs, layout.evidence]);
}

const ZERO_SUMMARY = { passed: 0, failed: 0, flaky: 0, skipped: 0, interrupted: 0, didNotRun: 0, errors: 0 };

async function runSelftest(pw, mode, runId) {
  const layout = planLayout(os.tmpdir(), runId);
  let summary = null;
  let exit = -1;
  let titles = [];
  let cleaned = false;
  try {
    const env = buildChildEnv(process.env, layout, runId, modeValues(mode));
    say(`INFO launch mode=${mode} run=${runId} playwright=${pw.version}`);
    say(`INFO child-env names=${Object.keys(env).sort().join(',')}`);
    const r = await runChild(pw.cli, mode, [], env, layout, mode);
    exit = r.exit;
    for (const l of relay(r.stdout + '\n' + r.stderr)) say(l);
    summary = parseSummary(r.stdout);
    titles = summaryTitles(r.stdout);
  } finally {
    cleaned = removeRoot(layout);
  }
  for (const t of titles) say(`FAIL test -- ${t}`);
  if (!cleaned) say('FAIL cleanup -- run root not removed');
  let end = selftestEndLine(summary);
  const failed = Number(end.split(', ')[1].split(' ')[0]);
  const ok = exit === 0 && failed === 0 && cleaned;
  if (!ok && failed === 0) end = `${summary ? summary.passed : 0} passed, 1 failed`;
  say(end);
  return ok ? 0 : 1;
}

async function runList(pw, runId) {
  const layout = planLayout(os.tmpdir(), runId);
  let a;
  let b;
  let c;
  let cleaned = false;
  try {
    say(`INFO launch mode=list run=${runId} playwright=${pw.version}`);
    const envA = buildChildEnv(process.env, layout, runId, modeValues('list-live'));
    a = await runChild(pw.cli, null, ['--list'], envA, layout, 'list-live');
    const envB = buildChildEnv(process.env, layout, runId, modeValues('list-needle'));
    b = await runChild(pw.cli, null, ['--list'], envB, layout, 'list-needle');
    const envC = buildChildEnv(process.env, layout, runId, modeValues('list-site'));
    c = await runChild(pw.cli, null, ['--list'], envC, layout, 'list-site');
  } finally {
    cleaned = removeRoot(layout);
  }
  const ca = a ? parseListCounts(a.stdout) : null;
  const cb = b ? parseListCounts(b.stdout) : null;
  const cc = c ? parseListCounts(c.stdout) : null;
  const ok = !!a && !!b && !!c && a.exit === 0 && b.exit === 0 && c.exit === 0 && listCountsAgree(ca, cb, cc) && cleaned;
  if (!cleaned) say('FAIL cleanup -- run root not removed');
  say(listEndLine({ live: ca, needle: cb, site: cc, ok }));
  return ok ? 0 : 1;
}

function reportFailures(label, failures, expected) {
  for (const title of Object.keys(expected)) {
    const f = failures.find((x) => x.title === title);
    const status = !f ? 'missing' : f.message === expected[title] ? 'match' : 'mismatch';
    say(`INFO ${label} ${title.split(' ')[0]} ${status}`);
  }
  for (const t of new Set(failures.map((f) => f.title))) if (!Object.prototype.hasOwnProperty.call(expected, t)) say(`INFO ${label} unexpected-failure`);
}

async function runNeedle(pw, runId) {
  const set = makeNeedleSet();
  const plan = planNeedleRuns(os.tmpdir(), runId);
  const values = modeValues('needle', set);
  const noHits = Object.fromEntries(SURFACES.map((s) => [s, -1]));
  let run1 = { exit: -1, summary: null, failures: [], hits: { ...noHits }, artifacts: -1 };
  let run2 = { exit: -1, summary: null, failures: [], controlHits: {}, otherHits: { ...noHits }, artifacts: -1 };
  let cleaned1 = false;
  let cleaned2 = false;
  say(`INFO launch mode=needle run=${runId} playwright=${pw.version}`);
  try {
    const env1 = buildChildEnv(process.env, plan.run1, `${runId}-n1`, values);
    say(`INFO child-env names=${Object.keys(env1).sort().join(',')}`);
    const r1 = await runChild(pw.cli, 'needle', [], env1, plan.run1, 'needle');
    run1 = {
      exit: r1.exit,
      summary: parseSummary(r1.stdout),
      failures: parseFailures(r1.stdout),
      hits: scanAll(needleSpecs(set, 'run1'), plan.run1, [r1.outFile, r1.errFile]),
      artifacts: artifactsIn(plan.run1),
    };
  } finally {
    cleaned1 = removeRoot(plan.run1);
  }
  try {
    const env2 = buildChildEnv(process.env, plan.run2, `${runId}-n2`, values);
    const r2 = await runChild(pw.cli, 'needle-control', [], env2, plan.run2, 'needle-control');
    const logs = [r2.outFile, r2.errFile];
    const git = gitStatusText();
    const controlHits = {};
    for (const [k, specs] of Object.entries(controlSpecs(set))) controlHits[k] = scanAll(specs, plan.run2, logs, git);
    run2 = {
      exit: r2.exit,
      summary: parseSummary(r2.stdout),
      failures: parseFailures(r2.stdout),
      controlHits,
      otherHits: scanAll(needleSpecs(set, 'run1'), plan.run2, logs, git),
      artifacts: artifactsIn(plan.run2),
    };
  } finally {
    cleaned2 = removeRoot(plan.run2);
  }
  reportFailures('needle', run1.failures, EXPECTED_NEEDLE_FAILURES);
  reportFailures('needle-control', run2.failures, EXPECTED_CONTROL_FAILURES);
  if (!cleaned1 || !cleaned2) say('FAIL cleanup -- run root not removed');
  const j = judgeNeedle({ run1: { ...run1, summary: run1.summary ?? ZERO_SUMMARY }, run2: { ...run2, summary: run2.summary ?? ZERO_SUMMARY } });
  const pass = j.pass && cleaned1 && cleaned2;
  say(pass ? j.line : j.line.replace(/^needle=PASS/, 'needle=FAIL'));
  return pass ? 0 : 1;
}

async function runLiveRed(pw, runId) {
  const layout = planLayout(os.tmpdir(), runId);
  let r = null;
  let cleaned = false;
  let relayed = [];
  try {
    const env = buildChildEnv(process.env, layout, runId, modeValues('live-red'));
    const names = Object.keys(env).sort();
    say(`INFO launch mode=live-red run=${runId} playwright=${pw.version}`);
    say(`INFO child-env names=${names.join(',')}`);
    if (names.join(',') !== expectedEnvNames('live-red').join(',')) {
      say('FAIL live-red -- child env names differ from the allowlist');
      return 1;
    }
    r = await runChild(pw.cli, 'live', [], env, layout, 'live');
    relayed = relay(r.stdout + '\n' + r.stderr);
    for (const l of relayed) say(l);
  } finally {
    cleaned = removeRoot(layout);
  }
  const residue = lines(r.stdout).includes('INFO auth-residue 0');
  if (!cleaned) say('FAIL cleanup -- run root not removed');
  say(liveRedEndLine({ summary: parseSummary(r.stdout), gateReach: countGateReach(relayed), exit: r.exit, residue, cleaned }));
  return r.exit === 0 && residue && cleaned ? 0 : 1;
}

// T087 — site 프로젝트 한 번(대상은 site: 런처 env · site-red: 닫힌 루프백 포트). 대상 값은 출력하지 않는다(env 이름 · 판정 줄 · 수만).
async function runSiteProject(pw, runId, mode, target) {
  const layout = planLayout(os.tmpdir(), runId);
  let r = null;
  let relayed = [];
  let titles = [];
  let cleaned = false;
  try {
    const env = buildChildEnv(process.env, layout, runId, modeValues(mode, target));
    const names = Object.keys(env).sort();
    say(`INFO launch mode=${mode} run=${runId} playwright=${pw.version}`);
    say(`INFO child-env names=${names.join(',')}`);
    if (names.join(',') === expectedEnvNames(mode).join(',')) {
      r = await runChild(pw.cli, 'site', [], env, layout, mode);
      relayed = relay(r.stdout + '\n' + r.stderr);
      for (const l of relayed) say(l);
      titles = summaryTitles(r.stdout);
    } else {
      say(`FAIL ${mode} -- child env names differ from the allowlist`);
    }
  } finally {
    cleaned = removeRoot(layout);
  }
  for (const t of titles) say(`FAIL test -- ${t}`);
  if (!cleaned) say('FAIL cleanup -- run root not removed');
  return { r, relayed, cleaned };
}

async function runSite(pw, runId, target) {
  const { r, relayed, cleaned } = await runSiteProject(pw, runId, 'site', target);
  const x = { summary: r ? parseSummary(r.stdout) : null, allowed: allowedSkip(target.mode, relayed), exit: r ? r.exit : -1, cleaned };
  say(siteEndLine(x));
  return siteOk(x) ? 0 : 1;
}

// 닫힌 루프백 포트 — 잡았다가 놓는다(연결 거부를 낸다). 공개 호스트 0.
function closedLoopbackPort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.once('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const addr = srv.address();
      const port = addr && typeof addr === 'object' ? addr.port : 0;
      srv.close(() => (port > 0 ? resolve(port) : reject(new Error('launch: no loopback port'))));
    });
  });
}

async function runSiteRed(pw, runId) {
  const port = await closedLoopbackPort();
  const { r, relayed, cleaned } = await runSiteProject(pw, runId, 'site-red', { base: `http://127.0.0.1:${port}`, mode: 'local' });
  const exit = r ? r.exit : -1;
  say(siteRedEndLine({ summary: r ? parseSummary(r.stdout) : null, gateSite: countGateSite(relayed), exit, cleaned }));
  return exit === 0 && cleaned ? 0 : 1;
}

export async function main(argv) {
  const mode = argv[0];
  if (argv.length !== 1 || !MODES.includes(mode)) {
    say('FAIL launch -- usage: node e2e/lib/launch.mjs <selftest|selftest-browser|needle|list|live-red|site|site-red>');
    return 2;
  }
  // site는 대상 두 이름이 런처 env에 있어야 한다(이름만 출력 — 값 0)
  const siteTarget = mode === 'site' ? readSiteTarget(process.env) : null;
  if (mode === 'site' && !siteTarget) {
    say('FAIL launch -- site mode needs BASE_URL and JT_E2E_SITE_MODE in the launcher env');
    return 2;
  }
  if (mode === 'site' && !siteTargetAllowed(siteTarget)) {
    say(SITE_TARGET_GUARD_LINE);
    return 2;
  }
  const pw = resolveCli();
  if (!pw) {
    if (mode === 'selftest') {
      say('SKIP e2e-selftest tests -- @playwright/test not installed');
      return 0;
    }
    say('FAIL launch -- @playwright/test not installed');
    return 1;
  }
  if (insideRepo(os.tmpdir())) {
    say('FAIL launch -- os.tmpdir() is inside the repository');
    return 1;
  }
  const runId = makeRunId();
  try {
    if (mode === 'selftest' || mode === 'selftest-browser') return await runSelftest(pw, mode, runId);
    if (mode === 'list') return await runList(pw, runId);
    if (mode === 'needle') return await runNeedle(pw, runId);
    if (mode === 'site') return await runSite(pw, runId, siteTarget);
    if (mode === 'site-red') return await runSiteRed(pw, runId);
    return await runLiveRed(pw, runId);
  } catch (e) {
    say(`FAIL launch -- internal error (${e && e.name ? e.name : 'unknown'})`);
    return 1;
  }
}

const invoked = process.argv[1] ? path.resolve(process.argv[1]).toLowerCase() : '';
if (invoked === fileURLToPath(import.meta.url).toLowerCase()) {
  main(process.argv.slice(2)).then(
    (code) => {
      process.exitCode = code;
    },
    () => {
      process.exitCode = 1;
    },
  );
}
