// e2e/hello.spec.ts — T087 사이트 E2E(US5 AC1 · AC2 · AC3 일부 · AC5 · FR-023 · FR-027 · FR-031 · Edge :210 · SC-007). 설계 = specs/003-platform-foundation/design/t086-design.md D10–D12.
// site 프로젝트(JT_E2E_SITE=1 + BASE_URL + JT_E2E_SITE_MODE — 설정이 대상을 검증한다)에서만 실린다. 스펙은 env를 읽지 않는다: 모드는 프로젝트 metadata,
// 대상은 baseURL 픽스처로만 받고 시험마다 다시 검증한다.
// 시험마다 첫 단계는 reach(freshGet <base>/ko) — 부재 단언(Set-Cookie 0 · 배지 0 · 쿠키 0)은 도달(v2 표식) 뒤에만 뜻이 있다(D12). 예외는 h-7 local(reach 전 INFO + skip —
// 로컬 next start에는 상류 identity-admin이 없다 · 판정은 prod에서 T095).
// 단계마다 out.ts로 'T087 <step> PASS|FAIL <근거>' 한 줄 — 상태 · 수 · 고정 사유 코드 · 우리 상수(경로 · slug)만(응답 본문 · 헤더 · 쿠키 값 0).
// 호출은 모두 lib/http.ts 감싸개(pace ≥ 200 ms — VD-3)를 지나고, 페이지 탐침은 lib/site-probe.ts(수 · 불리언만 돌려준다)만 쓴다.
// 오늘(T091 전) 기대 = 8건이 reach에서 '[gate] site-absent until T091'(루프백 거부 + apps/web 스캐폴드 없음) · h-7 skip — 빨강 관찰은 런처 site-red(루프백만).
import { test } from './lib/test-base';
import type { Page, TestInfo } from '@playwright/test';
import { errorCode, freshGet, guarded, navigate, safeError, type HttpResult } from './lib/http';
import { emitInfo, emitStep } from './lib/out';
import {
  HEALTH_DEGRADED_INFO,
  HEALTH_PATH,
  HEALTH_SKIP_INFO,
  LOCALES,
  NOTES,
  NOTE_SEL,
  NOT_A_POD_PATH,
  PREFETCH_WINDOW_MS,
  ROOT_CASES,
  SITE_MARKER_SELECTOR,
  classifySiteReach,
  classifySiteReachError,
  judgeCookieNames,
  judgeHealth,
  judgeLocale,
  judgeNotFound,
  judgePrefetch,
  judgeRootRedirect,
  judgeSetCookie,
  judgeTokenLayers,
  observeSite,
  scaffoldPresent,
  siteErrorVerdict,
  validateSiteTarget,
  type SiteMode,
  type SiteStop,
} from './lib/site';
import { probeTokenLayers, refStableUnderDark, startPrefetchCounter } from './lib/site-probe';

const TASK = 'T087';
const HTTP_TIMEOUT = 20_000;

interface Site {
  base: string;
  mode: SiteMode;
}

// 실패 단계 줄을 내고 값 없는 새 오류로 멈춘다
function stop(step: string, v: SiteStop): never {
  emitStep(TASK, step, 'FAIL', `[${v.prefix}] ${v.code}`, v.note);
  throw safeError(`${TASK} ${step} FAIL [${v.prefix}] ${v.code}`, v.code);
}

function productStop(step: string, code: string): never {
  return stop(step, { ok: false, prefix: 'product', code });
}

// target — 설정이 검증한 대상을 시험 안에서 다시 검증한다(방어 이중 · 값 0)
function target(testInfo: TestInfo, baseURL: string | undefined): Site {
  const v = validateSiteTarget(baseURL, testInfo.project.metadata.jtSiteMode);
  if (!v.ok) stop('target', v);
  return { base: v.base, mode: v.mode };
}

// reach — <base>/ko 한 번(리다이렉트 미추적 · 20 s). D11 표: local 거부 + 스캐폴드 없음만 [gate].
async function reach(site: Site): Promise<void> {
  let r: HttpResult;
  try {
    r = await freshGet(`${site.base}/ko`, { maxRedirects: 0, timeout: HTTP_TIMEOUT });
  } catch (e) {
    stop('reach', classifySiteReachError(site.mode, errorCode(e), scaffoldPresent()));
  }
  const v = classifySiteReach(site.mode, observeSite(r));
  if (!v.ok) stop('reach', v);
  emitStep(TASK, 'reach', 'PASS', v.code);
}

// 호출마다 새 요청 컨텍스트(쿠키 jar 0 · accept-language 없음 — VD-T087-1)
async function get(step: string, url: string, headers?: Record<string, string>): Promise<HttpResult> {
  try {
    return await freshGet(url, { maxRedirects: 0, timeout: HTTP_TIMEOUT, headers });
  } catch (e) {
    return stop(step, siteErrorVerdict(step, errorCode(e)));
  }
}

// Set-Cookie 위생 — local 0 · prod는 엣지 이름만(이름을 INFO로)
function checkSetCookie(step: string, site: Site, pathname: string, r: HttpResult): void {
  const v = judgeSetCookie(site.mode, pathname, r);
  if (!v.ok) stop(step, v);
  if (v.edge.length > 0) emitInfo(`${step} edge-set-cookie path=${pathname} names=${v.edge.join(',')}`);
}

async function countOf(page: Page, step: string, selector: string): Promise<number> {
  try {
    return await guarded(`count ${step}`, () => page.locator(selector).count());
  } catch (e) {
    return stop(step, siteErrorVerdict(step, errorCode(e)));
  }
}

// 브라우저 탐색 — 200 + v2 표식(그 페이지에 실제로 닿았는지 — 뒤의 0 단언이 공허하지 않게)
async function open(page: Page, step: string, site: Site, pathname: string): Promise<void> {
  let status: number | null = null;
  try {
    status = await navigate(page, site.base + pathname);
  } catch (e) {
    stop(step, siteErrorVerdict(step, errorCode(e)));
  }
  if (status !== 200) productStop(step, `navigate status=${status === null ? 'none' : status} path=${pathname}`);
  const marker = await countOf(page, step, SITE_MARKER_SELECTOR);
  if (marker < 1) productStop(step, `navigate-marker path=${pathname}`);
}

async function probe<T>(step: string, fn: () => Promise<T>): Promise<T> {
  try {
    return await fn();
  } catch (e) {
    return stop(step, siteErrorVerdict(step, errorCode(e)));
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

test('h-1 /ko /en /ja answer 200 text/html with the v2 marker', async ({ baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  for (const lang of LOCALES) {
    const pathname = `/${lang}`;
    const v = judgeLocale(pathname, await get('h-1', site.base + pathname));
    if (!v.ok) stop('h-1', v);
  }
  emitStep(TASK, 'h-1', 'PASS', `locales=${LOCALES.length}`);
});

test('h-2 every locale lists notes 001 and 002 with a title, the pubDate time and the claude-code tag', async ({ page, baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  for (const lang of LOCALES) {
    const pathname = `/${lang}`;
    await open(page, 'h-2', site, pathname);
    const all = await countOf(page, 'h-2', NOTE_SEL.any);
    if (all < 2) productStop('h-2', `notes n=${all} path=${pathname}`);
    for (const note of NOTES) {
      const root = NOTE_SEL.note(note.slug);
      const fields: Array<[string, string]> = [
        ['note', root],
        ['title', `${root} ${NOTE_SEL.title}`],
        ['time', `${root} ${NOTE_SEL.time(note.pubDate)}`],
        ['tag', `${root} ${NOTE_SEL.tag}`],
      ];
      for (const [field, selector] of fields) {
        const n = await countOf(page, 'h-2', selector);
        if (n !== 1) productStop('h-2', `note-${field} n=${n} slug=${note.slug} path=${pathname}`);
      }
    }
  }
  emitStep(TASK, 'h-2', 'PASS', `locales=${LOCALES.length} notes=${NOTES.length}`);
});

test('h-3 no Set-Cookie on /ko /en /ja and on / with accept-language ko; no browser cookie after visiting the locales', async ({ page, baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  for (const lang of LOCALES) {
    const pathname = `/${lang}`;
    checkSetCookie('h-3', site, pathname, await get('h-3', site.base + pathname));
  }
  checkSetCookie('h-3', site, '/', await get('h-3', `${site.base}/`, { 'accept-language': 'ko' }));
  for (const lang of LOCALES) await open(page, 'h-3', site, `/${lang}`);
  // 이름만 꺼낸다(값은 받자마자 버린다)
  const names = await probe('h-3', async () => (await page.context().cookies()).map((c) => c.name));
  const v = judgeCookieNames(site.mode, '/ko,/en,/ja', names);
  if (!v.ok) stop('h-3', v);
  if (v.edge.length > 0) emitInfo(`h-3 edge-browser-cookies names=${v.edge.join(',')}`);
  emitStep(TASK, 'h-3', 'PASS', `responses=${LOCALES.length + 1} app-cookies=0`);
});

test('h-4 / answers 302 to the Accept-Language locale in all seven cases, without Set-Cookie', async ({ baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  for (const c of ROOT_CASES) {
    const r = await get('h-4', `${site.base}/`, c.acceptLanguage === null ? undefined : { 'accept-language': c.acceptLanguage });
    const v = judgeRootRedirect(site.base, c, r);
    if (!v.ok) stop('h-4', v);
    checkSetCookie('h-4', site, '/', r);
  }
  emitStep(TASK, 'h-4', 'PASS', `cases=${ROOT_CASES.length}`);
});

test('h-5 /ja marks notes 001 and 002 untranslated and shows the Korean original; /ko has no badge', async ({ page, baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  await open(page, 'h-5', site, '/ja');
  for (const note of NOTES) {
    const root = NOTE_SEL.note(note.slug);
    const badge = await countOf(page, 'h-5', `${root} ${NOTE_SEL.badge}`);
    if (badge !== 1) productStop('h-5', `ja-badge n=${badge} slug=${note.slug}`);
    const ko = await countOf(page, 'h-5', `${root}${NOTE_SEL.langKo}`);
    if (ko !== 1) productStop('h-5', `ja-note-lang n=${ko} slug=${note.slug}`);
  }
  await open(page, 'h-5', site, '/ko');
  const notes = await countOf(page, 'h-5', NOTE_SEL.any);
  if (notes < 2) productStop('h-5', `notes n=${notes} path=/ko`);
  const koBadges = await countOf(page, 'h-5', NOTE_SEL.badge);
  if (koBadges !== 0) productStop('h-5', `ko-badge n=${koBadges}`);
  await open(page, 'h-5', site, '/en');
  emitInfo(`h-5 en badges=${await countOf(page, 'h-5', NOTE_SEL.badge)}`);
  emitStep(TASK, 'h-5', 'PASS', `ja-badges=${NOTES.length} ko-badges=0`);
});

test('h-6 design tokens resolve in three layers (ref -> sys -> comp) and ref stays put under dark', async ({ page, baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  await open(page, 'h-6', site, '/ko');
  const t = await probe('h-6', () => probeTokenLayers(page));
  const v = judgeTokenLayers(t);
  if (!v.ok) stop('h-6', v);
  const stable = await probe('h-6', () => refStableUnderDark(page));
  if (!stable) productStop('h-6', 'token-ref-changes-under-dark');
  emitStep(TASK, 'h-6', 'PASS', `ref=${t.refCount} sys=${t.sysCount} comp=${t.compCount}`);
});

test('h-7 prod /api/health answers 200 JSON upstream identity-admin with upstream_ms and x-request-id (local: skipped)', async ({ baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  if (site.mode === 'local') {
    emitInfo(HEALTH_SKIP_INFO);
    test.skip(true, 'local next start has no upstream identity-admin - T095 judges this case on prod');
    return;
  }
  await reach(site);
  const r = await get('h-7', site.base + HEALTH_PATH);
  const v = judgeHealth(r);
  if (!v.ok) stop('h-7', v);
  // 계약상 유효한 degraded(상류 값 — C17)는 PASS — 값 없는 INFO 한 줄만 낸다(리뷰 A-2)
  if (v.degraded) emitInfo(HEALTH_DEGRADED_INFO);
  checkSetCookie('h-7', site, HEALTH_PATH, r);
  emitStep(TASK, 'h-7', 'PASS', v.code);
});

test('h-8 an unmapped proxy pod is a 404 problem with request_id = x-request-id, nosniff and no Set-Cookie (no config needed - C26)', async ({ baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  const r = await get('h-8', site.base + NOT_A_POD_PATH);
  const v = judgeNotFound(r);
  if (!v.ok) stop('h-8', v);
  checkSetCookie('h-8', site, NOT_A_POD_PATH, r);
  emitStep(TASK, 'h-8', 'PASS', v.code);
});

test('h-9 /ko makes at most 10 Next-Router-Prefetch requests within 30 s of load (prefetch storm guard)', async ({ page, baseURL }, testInfo) => {
  const site = target(testInfo, baseURL);
  await reach(site);
  const counter = startPrefetchCounter(page);
  let n: number;
  try {
    await open(page, 'h-9', site, '/ko');
    await sleep(PREFETCH_WINDOW_MS);
  } finally {
    n = counter.stop();
  }
  emitInfo(`prefetch n=${n}`);
  const v = judgePrefetch(n);
  if (!v.ok) stop('h-9', v);
  emitStep(TASK, 'h-9', 'PASS', v.code);
});
