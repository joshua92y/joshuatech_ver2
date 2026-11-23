// playwright.config.ts — 루트 Playwright 설정(설계 specs/003-platform-foundation/design/t077-design.md D3 · T077-d).
// 자리 = 저장소 루트: 인자 없는 `pnpm exec playwright test`도 늘 이 설정을 잡고, tester 쓰기 가드(^e2e/) 밖이라 약화는 리뷰된 커밋으로만 들어온다.
// 인자 없는 실행 = selftest 두 프로젝트뿐이다. needle · live는 런처(e2e/lib/launch.mjs) · 검토된 자격 블록이 주는 플래그로만 실린다.
import { defineConfig, type PlaywrightTestConfig } from '@playwright/test';
import * as crypto from 'node:crypto';
import * as os from 'node:os';
import * as path from 'node:path';

export const AUTH_BASE_URL = 'https://auth.joshuatech.dev';
// 브라우저 프로세스 env 허용 목록(VD-T077-3 최종) — process.env를 통째로 넘기지 않는다(r1 — B-11).
export const BROWSER_ENV_NAMES = ['SystemRoot', 'TEMP', 'TMP', 'LOCALAPPDATA', 'USERPROFILE'] as const;
export const NEEDLE_LIVE_CONFLICT = '[guard] needle-live-conflict — needle+live 동시 금지';

const RUN_ID = /^[A-Za-z0-9][A-Za-z0-9-]*$/;

export function makeRunId(now: Date = new Date(), hex: string = crypto.randomBytes(3).toString('hex')): string {
  const p = (n: number) => String(n).padStart(2, '0');
  const ts = `${now.getUTCFullYear()}${p(now.getUTCMonth() + 1)}${p(now.getUTCDate())}T${p(now.getUTCHours())}${p(now.getUTCMinutes())}${p(now.getUTCSeconds())}Z`;
  return `t077-${ts}-${hex}`;
}

export function buildConfig(env: Record<string, string | undefined>): PlaywrightTestConfig {
  const live = env.JT_E2E_LIVE === '1';
  const needle = env.JT_E2E_NEEDLE === '1';
  // 바늘 값이 실제 IdP로 가지 않게 두 플래그는 함께 실리지 않는다(r2 — V-9)
  if (live && needle) throw new Error(NEEDLE_LIVE_CONFLICT);
  const runId = env.JT_E2E_RUN_ID;
  if (!runId || !RUN_ID.test(runId)) throw new Error('[guard] run id missing or malformed (JT_E2E_RUN_ID)');
  const outputDir = env.JT_E2E_OUTPUT_DIR || path.join(os.tmpdir(), 'jt-e2e', runId);
  const browserEnv: Record<string, string> = {};
  for (const n of BROWSER_ENV_NAMES) {
    const v = env[n];
    if (typeof v === 'string' && v.length > 0) browserEnv[n] = v;
  }

  const projects: NonNullable<PlaywrightTestConfig['projects']> = [
    { name: 'selftest', testMatch: 'selftest/**/*.test.ts' },
    { name: 'selftest-browser', testMatch: 'selftest-browser/**/*.test.ts' },
  ];
  if (needle) {
    projects.push({ name: 'needle', testMatch: 'needle/needle.test.ts' });
    projects.push({ name: 'needle-control', testMatch: 'needle/needle-control.test.ts' });
  }
  if (live) {
    projects.push({ name: 'live', testMatch: ['auth.spec.ts', 'revocation.spec.ts'], use: { baseURL: AUTH_BASE_URL } });
  }

  return {
    testDir: './e2e',
    outputDir,
    // 실패 산출물(error-context 등)을 남기지 않는다(r1 — B-4 (a)). 단 needle 실행만 'always' — 런처가 실행 뒤 루트 전체를 바늘 스캔하므로
    // 시험 끝에 지워지는 일시 파일(error-context · trace · 영상)도 스캔 면에 남겨야 한다(빌드 리뷰 r1 — B-1). live와 needle은 위에서 배타다.
    preserveOutput: needle ? 'always' : 'never',
    // 스냅숏 기준 이미지를 쓰지 않고(mask 없는 PNG가 생기지 않게) 자리도 저장소 밖 outputDir 아래로 둔다(빌드 리뷰 r1 — C-2)
    updateSnapshots: 'none',
    snapshotDir: path.join(outputDir, 'snapshots'),
    // HTML · blob · json · junit 금지 — HTML step 제목에 fill 값이 평문으로 실리고 리포트 서버가 프로세스를 붙든다(r1 — A-16)
    reporter: [['list', { printSteps: false }]],
    // 같은 사용자 로그인은 직렬이어야 한다(TOTP last_t · Reputation)
    workers: 1,
    fullyParallel: false,
    retries: 0,
    forbidOnly: true,
    maxFailures: 0,
    timeout: 120_000,
    expect: { timeout: 10_000 },
    globalTimeout: 540_000,
    globalSetup: './e2e/global-setup.ts',
    globalTeardown: './e2e/global-teardown.ts',
    // 검토된 자격 블록 경로(§5-1 코드 관문 · r1 — B-2). null인 동안 live는 자격 env가 있어도 값을 읽지 않는다. 승인 커밋(G-1–G-7 뒤)만 바꾼다.
    metadata: { jtApprovedBlock: null },
    // CI 신호가 있어도 git 커밋 · diff를 metadata에 모으지 않는다
    captureGitInfo: { commit: false, diff: false },
    use: {
      trace: 'off',
      video: 'off',
      screenshot: 'off',
      actionTimeout: 15_000,
      navigationTimeout: 30_000,
      locale: 'en-US',
      timezoneId: 'UTC',
      ignoreHTTPSErrors: false,
      acceptDownloads: false,
      launchOptions: { env: browserEnv },
    },
    projects,
  };
}

// 직접 실행(런처 밖)에서도 러너 · 워커가 같은 runId(→ 같은 outputDir)를 보게 한다 — 워커는 설정을 다시 읽고 러너 env를 물려받는다.
if (!process.env.JT_E2E_RUN_ID) process.env.JT_E2E_RUN_ID = makeRunId();
// 실패 때 error-context.md에 페이지 aria snapshot(화면 글자 — Sessions의 IP · UA 등)을 싣지 않는다(VD-T077-4 실측 — 1.65.1 워커가 이 env를 본다).
process.env.PLAYWRIGHT_NO_COPY_PROMPT = '1';

export default defineConfig(buildConfig(process.env));
