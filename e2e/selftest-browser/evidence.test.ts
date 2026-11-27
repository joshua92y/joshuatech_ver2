// e2e/selftest-browser/evidence.test.ts — 증거 스크린샷 mask 판정(설계 D10 ⑨ · 빌드 리뷰 r1 — C-3) selftest. 로컬 page.setContent만 — 네트워크 0.
import { test, expect } from '../lib/test-base';
import * as crypto from 'node:crypto';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { evidenceDir, evidenceShot, masksMatch } from '../lib/evidence';

// 고정 폭 칸 — 글자가 달라도 배치는 같다(가린 칸의 글자만 다른 두 화면이 같은 화소가 되게)
function fixedTable(ip: string, ua: string, other: string): string {
  return [
    '<style>body{margin:0;font:14px monospace;background:#fff} table{border-collapse:collapse;table-layout:fixed;width:600px}',
    ' td{width:200px;height:24px;overflow:hidden;white-space:nowrap;padding:0;border:1px solid #000}</style>',
    '<table id="sessions"><tbody>',
    `<tr><td class="ip">${ip}</td><td class="ua">${ua}</td><td class="other">${other}</td></tr>`,
    '</tbody></table>',
  ].join('');
}

const TABLE = [
  '<table id="sessions"><tbody>',
  '<tr><td class="ip">198.51.100.10</td><td class="ua">Agent A</td></tr>',
  '<tr><td class="ip">198.51.100.11</td><td class="ua">Agent B</td></tr>',
  '</tbody></table>',
].join('');

test('evidence: mask judgement — every mask count must equal the row count (≥ 1)', () => {
  expect(masksMatch(2, [2, 2])).toBe(true);
  expect(masksMatch(2, [2, 0])).toBe(false);
  expect(masksMatch(2, [1, 2])).toBe(false);
  expect(masksMatch(0, [0, 0])).toBe(false);
  expect(masksMatch(1, [])).toBe(false);
});

test('evidence: shot is taken with masks into the evidence dir, sha256 returned', async ({ page }, testInfo) => {
  await page.setContent(TABLE);
  const dir = testInfo.outputPath('evidence');
  const rows = await page.locator('#sessions tbody tr').count();
  const r = await evidenceShot(page, 'sessions', rows, [
    { label: 'ip', locator: page.locator('#sessions td.ip') },
    { label: 'ua', locator: page.locator('#sessions td.ua') },
  ], { dir });
  expect(r.file).toBe(path.join(dir, 'sessions.png'));
  expect(r.masked).toEqual(['ip', 'ua']);
  const sha = crypto.createHash('sha256').update(fs.readFileSync(r.file)).digest('hex');
  expect(r.sha256).toBe(sha);
  fs.rmSync(dir, { recursive: true, force: true });
});

// 제목은 ASCII만 — 시험 출력 디렉터리 이름이 제목에서 나온다(비ASCII 경로의 Node 24 rmSync 문제를 피한다)
test('evidence: masks are really applied - shots differing only in masked cells are byte-identical, an unmasked difference shows (review C-3)', async ({ page }, testInfo) => {
  const dir = testInfo.outputPath('mask-proof');
  const masks = () => [
    { label: 'ip', locator: page.locator('#sessions td.ip') },
    { label: 'ua', locator: page.locator('#sessions td.ua') },
  ];
  const shot = async (name: string, ip: string, ua: string, other: string): Promise<Buffer> => {
    await page.setContent(fixedTable(ip, ua, other));
    const r = await evidenceShot(page, name, 1, masks(), { dir });
    return fs.readFileSync(r.file);
  };
  const a = await shot('mask-a', '198.51.100.10', 'Agent A/1.0', 'same');
  const b = await shot('mask-b', '203.0.113.254', 'Totally Different Agent/9.9', 'same');
  const c = await shot('mask-c', '198.51.100.10', 'Agent A/1.0', 'changed');
  expect(a.equals(b), 'masked cells hide their text (mask applied)').toBe(true);
  expect(a.equals(c), 'an unmasked difference is visible (the comparison is not vacuous)').toBe(false);
});

test('evidence: a mask target that does not match every row → [product] mask-target-missing, no file', async ({ page }, testInfo) => {
  await page.setContent(TABLE);
  const dir = testInfo.outputPath('evidence-missing');
  const rows = await page.locator('#sessions tbody tr').count();
  await expect(evidenceShot(page, 'sessions', rows, [
    { label: 'ip', locator: page.locator('#sessions td.no-such-cell') },
  ], { dir })).rejects.toThrow('[product] mask-target-missing');
  expect(fs.existsSync(path.join(dir, 'sessions.png'))).toBe(false);
  await expect(evidenceShot(page, 'sessions', 0, [], { dir })).rejects.toThrow('[product] mask-target-missing');
});

test('evidence: the evidence dir must be outside the repository', async ({ page }) => {
  await page.setContent(TABLE);
  const inRepo = path.resolve(__dirname, '..', 'evidence-in-repo');
  await expect(evidenceShot(page, 'sessions', 2, [
    { label: 'ip', locator: page.locator('#sessions td.ip') },
  ], { dir: inRepo })).rejects.toThrow(/outside the repository/);
  expect(fs.existsSync(inRepo)).toBe(false);
});

test('evidence: default dir = JT_E2E_EVIDENCE_DIR, else <tmp>/jt-e2e/<runId>/evidence', () => {
  expect(evidenceDir({ JT_E2E_EVIDENCE_DIR: 'D:\\root\\evidence', JT_E2E_RUN_ID: 'r' }, 'C:\\tmp')).toBe('D:\\root\\evidence');
  expect(evidenceDir({ JT_E2E_RUN_ID: 't077-20261123T000000Z-abcdef' }, 'C:\\tmp')).toBe(path.join('C:\\tmp', 'jt-e2e', 't077-20261123T000000Z-abcdef', 'evidence'));
  expect(() => evidenceDir({}, 'C:\\tmp')).toThrow(/run id/);
});

test('evidence: names are fixed ASCII words', async ({ page }) => {
  await page.setContent(TABLE);
  await expect(evidenceShot(page, '../x', 2, [{ label: 'ip', locator: page.locator('#sessions td.ip') }], { dir: 'C:\\tmp\\x' })).rejects.toThrow(/name/);
});
