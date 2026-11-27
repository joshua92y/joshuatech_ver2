// e2e/lib/test-base.ts — 공통 test 기반(빌드 리뷰 r1 — B-3 · C-1). spec · needle · selftest-browser는 test를 여기서만 가져온다(static-gate).
// 파일 단위 옵션 덮기(test 객체의 use 호출 · extend로 옵션 픽스처를 덮기)는 FullConfig.projects[].use에 드러나지 않아 globalSetup ③ · config-hygiene이
// 못 본다(trace · video · 자동 screenshot이 실제로 켜진다 — 리뷰 실측). 그래서 자동 픽스처가 시험마다 실제 옵션 픽스처 값을 프로젝트 설정 값과 다시 맞춰 보고,
// 어긋나면 브라우저 · 요청 컨텍스트를 만들기 전에 [guard] fixture-override <이름>으로 멈춘다(값 0 — 이름만).
// 재단언 픽스처 이름은 이 파일에만 둔다(다른 곳에서 덮어 끄지 못하게 — static-gate guard-fixture).
import { test as pwTest, expect } from '@playwright/test';
import { safeError } from './http';
import { emitStop } from './out';

export { expect };

// 값을 기록하거나(trace · video · screenshot · contextOptions의 녹화) 값을 싣거나(헤더 · 자격 · 상태) 브라우저 · 연결을 바꾸는(headless · channel ·
// launchOptions · connectOptions · proxy) 옵션 픽스처
export const GUARDED_OPTIONS = [
  'trace',
  'video',
  'screenshot',
  'headless',
  'channel',
  'launchOptions',
  'connectOptions',
  'contextOptions',
  'proxy',
  'storageState',
  'extraHTTPHeaders',
  'httpCredentials',
  'ignoreHTTPSErrors',
  'acceptDownloads',
  'baseURL',
] as const;

function recordingMode(v: unknown): string {
  if (v === undefined || v === null) return 'off';
  if (typeof v === 'string') return v;
  if (typeof v === 'object') {
    const m = (v as { mode?: unknown }).mode;
    return typeof m === 'string' ? m : 'off';
  }
  return 'invalid';
}

function canonical(v: unknown): unknown {
  if (Array.isArray(v)) return v.map(canonical);
  if (v !== null && typeof v === 'object') {
    const o = v as Record<string, unknown>;
    return Object.fromEntries(Object.keys(o).sort().map((k) => [k, canonical(o[k])]));
  }
  return v;
}

function sameValue(a: unknown, b: unknown): boolean {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
}

// 실제 픽스처 값(actual) ↔ 프로젝트 설정 값(projectUse — globalSetup ③이 이미 검사한 값). 결과는 어긋난 옵션 이름(정렬)뿐이다.
export function optionViolations(actual: Record<string, unknown>, projectUse: Record<string, unknown>): string[] {
  const bad: string[] = [];
  for (const f of ['trace', 'video', 'screenshot']) if (recordingMode(actual[f]) !== 'off') bad.push(f);
  if (actual.headless !== true) bad.push('headless');
  for (const f of ['channel', 'connectOptions', 'proxy', 'storageState', 'extraHTTPHeaders', 'httpCredentials']) if (actual[f] !== undefined) bad.push(f);
  if (!sameValue(actual.launchOptions ?? {}, projectUse.launchOptions ?? {})) bad.push('launchOptions');
  if (!sameValue(actual.contextOptions ?? {}, projectUse.contextOptions ?? {})) bad.push('contextOptions');
  if (actual.ignoreHTTPSErrors !== false) bad.push('ignoreHTTPSErrors');
  if (actual.acceptDownloads !== false) bad.push('acceptDownloads');
  if (actual.baseURL !== projectUse.baseURL) bad.push('baseURL');
  return bad.sort();
}

export const test = pwTest.extend<{ jtFixtureGuard: void }>({
  jtFixtureGuard: [
    async (
      { trace, video, screenshot, headless, channel, launchOptions, connectOptions, contextOptions, proxy, storageState, extraHTTPHeaders, httpCredentials, ignoreHTTPSErrors, acceptDownloads, baseURL },
      use,
      testInfo,
    ) => {
      const actual: Record<string, unknown> = { trace, video, screenshot, headless, channel, launchOptions, connectOptions, contextOptions, proxy, storageState, extraHTTPHeaders, httpCredentials, ignoreHTTPSErrors, acceptDownloads, baseURL };
      const bad = optionViolations(actual, testInfo.project.use as Record<string, unknown>);
      if (bad.length > 0) {
        const code = `fixture-override ${bad.join(',')}`;
        emitStop('guard', code);
        throw safeError(`[guard] ${code}`, 'fixture-override');
      }
      await use();
    },
    { auto: true },
  ],
});
