// e2e/selftest/static-gate.test.ts — 노출 0 정적 관문(설계 D10 ⑤ · r2 — V-2 · V-5 · V-6 · r1 리뷰 A-4 · B-2 · B-3 · C-1 · C-2 · C-4). e2e/** 와 루트 config 소스를 본다.
// 패턴 · 접두는 조각으로 조립해 이 파일이 스스로 걸리지 않게 한다. 위반은 규칙 id와 파일 경로만 낸다(일치한 글자 0).
// 규칙마다 양성 대조가 있다 — 심은 글자를 그 규칙이 잡고, 허용된 파일에서는 그 규칙이 조용해야 한다.
import { test, expect } from '@playwright/test';
import * as fs from 'node:fs';
import * as path from 'node:path';

const REPO = path.resolve(__dirname, '..', '..');
const J = (...parts: string[]): string => parts.join('');
const lit = (s: string): RegExp => new RegExp(s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));

const OUT = 'e2e/lib/out.ts';
const LAUNCH = 'e2e/lib/launch.mjs';
const SCAN = 'e2e/lib/scan-needle.mjs';
const CONTROL = 'e2e/needle/needle-control.test.ts';
const AUTH_DIR = 'e2e/lib/auth-dir.ts';
const EVIDENCE = 'e2e/lib/evidence.ts';
const ENV_CONTRACT = 'e2e/lib/env-contract.ts';
const HTTP = 'e2e/lib/http.ts';
const SECRET_INPUT = 'e2e/lib/secret-input.ts';
const TEST_BASE = 'e2e/lib/test-base.ts';
const FIXTURE_GUARD = 'e2e/selftest-browser/fixture-guard.test.ts';

// 공통 test 기반을 써야 하는 파일(브라우저 · 요청 픽스처를 쓰는 spec · needle · selftest-browser — 리뷰 B-3)
const baseUser = (rel: string): boolean => /^e2e\/[^/]+\.spec\.ts$/.test(rel) || rel.startsWith('e2e/needle/') || rel.startsWith('e2e/selftest-browser/');
// 줄을 내는 실행 코드(spec · lib · globalSetup/Teardown — 리뷰 C-4). out.ts · 런처 · 스캐너는 제외(이름 붙은 출력 예외).
const emitter = (rel: string): boolean =>
  /^e2e\/[^/]+\.spec\.ts$/.test(rel) || /^e2e\/global-(setup|teardown)\.ts$/.test(rel) || (/^e2e\/lib\/[^/]+\.ts$/.test(rel) && rel !== OUT);

interface Rule {
  id: string;
  hit: (text: string) => boolean;
  allowed: readonly string[];
  applies?: (rel: string) => boolean;
}

const rx = (re: RegExp) => (text: string): boolean => re.test(text);

// 어디서나 0(설계 D10 ⑤ 첫 목록 + ④ 집행 — 값을 실패 메시지 · 출력 · 파일에 싣는 단언 · 값 추출 · 기록 · 가로채기 · 덮기)
const ANYWHERE: Array<[string, RegExp]> = [
  ['tracing', lit(J('trac', 'ing.'))],
  ['record-har', lit(J('record', 'Har'))],
  ['route-from-har', lit(J('routeFrom', 'HAR'))],
  ['record-video', lit(J('record', 'Video'))],
  ['attach', lit(J('.att', 'ach('))],
  ['pause', lit(J('.pau', 'se('))],
  ['listener', new RegExp(J('\\.(on|once|addListener|prependListener)\\(\\s*[\'"`]', '(request|response|console|requestfinished|requestfailed|framenavigated|pageerror|dialog|download|popup|websocket|filechooser|weberror|worker)[\'"`]'))],
  ['to-be-ok', lit(J('toBe', 'OK('))],
  ['to-have-url', lit(J('toHave', 'URL('))],
  ['to-have-value', lit(J('toHave', 'Value('))],
  ['input-value', lit(J('input', 'Value('))],
  ['to-have-text', lit(J('toHave', 'Text('))],
  ['to-contain-text', lit(J('toContain', 'Text('))],
  ['to-match-aria-snapshot', lit(J('toMatchAria', 'Snapshot('))],
  ['text-content', lit(J('text', 'Content('))],
  ['inner-text', lit(J('inner', 'Text('))],
  ['all-text-contents', lit(J('allText', 'Contents('))],
  ['all-inner-texts', lit(J('allInner', 'Texts('))],
  ['wait-for-request', lit(J('waitFor', 'Request('))],
  ['wait-for-navigation', lit(J('waitFor', 'Navigation('))],
  ['wait-for-event', lit(J('waitFor', 'Event('))],
  // 리뷰 B-2 — 로케이터 매처는 실패 때 body aria snapshot(입력 칸 값 포함)을 error-context에 싣는다(1.65.1)
  ['locator-matcher', new RegExp(J('\\.(toBe(Visible|Hidden|Enabled|Disabled|Checked|Editable|Empty|Focused|Attached|InViewport)|', 'toHave(Count|Class|CSS|Id|Role|Values|Title|Attribute|JSProperty|Accessible[A-Za-z]*)|toContainClass)\\('))],
  ['to-match-snapshot', lit(J('toMatch', 'Snapshot('))],
  ['aria-snapshot', lit(J('aria', 'Snapshot('))],
  ['inner-html', lit(J('inner', 'HTML('))],
  ['page-content', lit(J('.cont', 'ent()'))],
  ['get-attribute', lit(J('getAttri', 'bute('))],
  ['typing', new RegExp(J('\\.(type|insertText|pressSeq', 'uentially)\\('))],
  ['attachments-push', lit(J('attachments', '.push('))],
  ['annotations-push', lit(J('annotations', '.push('))],
  ['fd-write', new RegExp(J('write', 'Sync\\(\\s*[12]\\s*,'))],
  ['route', new RegExp(J('\\.(route|unroute|routeWeb', 'Socket)\\('))],
  ['expose', new RegExp(J('\\.expose(Binding|', 'Function)\\('))],
  // 리뷰 B-2 — 요청 픽스처 별칭 · page/context의 요청 속성 별칭은 이름 기반 규칙을 비켜 간다
  ['request-alias', new RegExp(J('\\brequest\\s*:\\s*[A-Za-z_$]|\\brequest\\s+', 'as\\s+[A-Za-z_$]'))],
  ['request-property', new RegExp(J('\\.requ', 'est\\b'))],
  // 리뷰 C-2 — 스냅숏 자리를 저장소 안으로 되돌리는 설정
  ['snapshot-template', new RegExp(J('snapshotPath', 'Template|pathTem', 'plate'))],
];

// 이름 붙은 파일에서만
const NAMED: Rule[] = [
  { id: 'console', hit: rx(lit(J('cons', 'ole.'))), allowed: [OUT, LAUNCH, SCAN, CONTROL] },
  { id: 'stdout', hit: rx(lit(J('process.', 'stdout'))), allowed: [OUT, LAUNCH, SCAN, CONTROL] },
  { id: 'stderr', hit: rx(lit(J('process.', 'stderr'))), allowed: [OUT, LAUNCH, SCAN, CONTROL] },
  { id: 'storage-state-path', hit: rx(new RegExp(J('storage', 'State\\(\\s*\\{\\s*path'))), allowed: [AUTH_DIR] },
  // 리뷰 C-2 — 대소문자 무관(toHaveScreenshot 포함)
  { id: 'screenshot', hit: rx(new RegExp(J('screen', 'shot\\('), 'i')), allowed: [EVIDENCE] },
  { id: 'secret-env', hit: rx(lit(J('JT_E2E_', 'SECRET_'))), allowed: [ENV_CONTRACT, LAUNCH] },
  { id: 'needle-set-env', hit: rx(lit(J('JT_E2E_', 'NEEDLE_SET'))), allowed: [ENV_CONTRACT, LAUNCH] },
  // 리뷰 A-4 — 읽기 꼴은 env-contract.ts만(런처는 이름 글자만 쓸 수 있다 · 동적 읽기는 이어 붙인 이름을 막는다)
  { id: 'secret-env-read', hit: rx(lit(J('process.env.JT_E2E_', 'SECRET_'))), allowed: [ENV_CONTRACT] },
  { id: 'needle-set-read', hit: rx(lit(J('process.env.JT_E2E_', 'NEEDLE_SET'))), allowed: [ENV_CONTRACT] },
  { id: 'env-dynamic', hit: rx(lit(J('process.e', 'nv['))), allowed: [ENV_CONTRACT] },
  { id: 'request', hit: rx(lit(J('requ', 'est.'))), allowed: [HTTP, CONTROL] },
  { id: 'goto', hit: rx(lit(J('go', 'to('))), allowed: [HTTP, CONTROL] },
  { id: 'wait-for-url', hit: rx(lit(J('waitFor', 'URL('))), allowed: [HTTP, CONTROL] },
  { id: 'wait-for-response', hit: rx(lit(J('waitFor', 'Response('))), allowed: [HTTP] },
  { id: 'url-read', hit: rx(lit(J('.u', 'rl('))), allowed: [HTTP] },
  { id: 'needle-prefix', hit: rx(lit(J('JTNEE', 'DLE-'))), allowed: [LAUNCH, ENV_CONTRACT] },
  // 리뷰 B-2 — 값을 읽는 evaluate는 길이만 읽는 secret-input에만. fill은 secret-input과 고정 신원(E2E_EMAIL) 인자만.
  { id: 'evaluate', hit: rx(new RegExp(J('\\.(evaluate|evaluateAll|evaluateHandle|\\$eval|\\$\\$eval)', '\\('))), allowed: [SECRET_INPUT] },
  { id: 'fill', hit: rx(new RegExp(J('\\.fi', 'll\\(\\s*(?!E2E_EMAIL\\s*[,)])'))), allowed: [SECRET_INPUT, CONTROL] },
  // 리뷰 B-3 — 재단언 픽스처를 다른 곳에서 덮어 끄지 못하게 이름을 test-base에만 둔다
  { id: 'guard-fixture', hit: rx(lit(J('jtFixture', 'Guard'))), allowed: [TEST_BASE] },
  // 리뷰 B-3 · C-1 — 파일 단위 옵션 덮기(test 객체의 use 호출)는 FullConfig에 드러나지 않아 기록 끄기 세 겹을 우회한다.
  // 예외는 그 우회를 실행 때 막는지 보는 양성 대조 한 파일뿐이다(로컬 setContent만).
  { id: 'test-use', hit: rx(lit(J('.us', 'e('))), allowed: [FIXTURE_GUARD] },
];

// 경로 범위 규칙(리뷰 B-3 · C-4)
const PW_VALUE_IMPORT = new RegExp(J('^\\s*import\\s+(?!type\\b)[^;]*?from\\s*[\'"]@playwright/', 'test[\'"]|require\\(\\s*[\'"]@playwright/test[\'"]\\s*\\)'), 'm');
const BASE_IMPORT = new RegExp(J('from\\s*[\'"](\\.\\.?/)(lib/)?test-', 'base[\'"]'));

// 줄을 내는 호출의 인자 안 코드에 값 출처가 있으면 위반이다(out.ts는 줄의 꼴만 본다 — 리뷰 C-4).
// 문자열 · 템플릿의 글자 부분은 값이 아니므로 빼고, 템플릿의 ${…} 식과 일반 코드만 본다(예: 'copies=cleared' 글자는 통과).
const EMIT_CALL = new RegExp(J('\\b(emit(Step|Info|Stop|Summary)|fa', 'il)\\s*\\('), 'g');
const VALUE_SOURCE = /\.value\b|\bcookies\s*\(|\bstorageState\s*\(|\bsecrets\b|\bcopies\b|\.body\b|\bheaders\b/;

type Ctx = { k: 'code'; paren: number } | { k: 'sq' } | { k: 'dq' } | { k: 'tpl' } | { k: 'expr'; brace: number };

// open = 여는 괄호 자리. 인자 목록의 코드 글자만 돌려준다(문자열 · 템플릿 글자 부분은 공백 하나로).
function argumentCode(text: string, open: number): string {
  const stack: Ctx[] = [{ k: 'code', paren: 0 }];
  let out = '';
  for (let i = open; i < text.length; i += 1) {
    const c = text[i];
    const top = stack[stack.length - 1];
    if (top.k === 'sq' || top.k === 'dq') {
      if (c === '\\') i += 1;
      else if ((top.k === 'sq' && c === "'") || (top.k === 'dq' && c === '"')) stack.pop();
      continue;
    }
    if (top.k === 'tpl') {
      if (c === '\\') i += 1;
      else if (c === '`') stack.pop();
      else if (c === '$' && text[i + 1] === '{') {
        stack.push({ k: 'expr', brace: 1 });
        i += 1;
        out += ' ';
      }
      continue;
    }
    if (c === "'" || c === '"' || c === '`') {
      stack.push(c === "'" ? { k: 'sq' } : c === '"' ? { k: 'dq' } : { k: 'tpl' });
      out += ' ';
      continue;
    }
    if (top.k === 'expr') {
      if (c === '{') top.brace += 1;
      else if (c === '}') {
        top.brace -= 1;
        if (top.brace === 0) {
          stack.pop();
          out += ' ';
          continue;
        }
      }
      out += c;
      continue;
    }
    if (c === '(') top.paren += 1;
    else if (c === ')') {
      top.paren -= 1;
      if (top.paren === 0) return out + c;
    }
    out += c;
  }
  return out;
}

function emitArgsCarryValues(text: string): boolean {
  EMIT_CALL.lastIndex = 0;
  let m: RegExpExecArray | null;
  while ((m = EMIT_CALL.exec(text)) !== null) {
    if (VALUE_SOURCE.test(argumentCode(text, m.index + m[0].length - 1))) return true;
  }
  return false;
}

const SCOPED: Rule[] = [
  { id: 'pw-test-import', hit: rx(PW_VALUE_IMPORT), allowed: [], applies: baseUser },
  { id: 'test-base-required', hit: (t) => !BASE_IMPORT.test(t), allowed: [], applies: baseUser },
  { id: 'emit-args', hit: emitArgsCarryValues, allowed: [], applies: emitter },
];

const RULES: readonly Rule[] = [...ANYWHERE.map(([id, re]) => ({ id, hit: rx(re), allowed: [] as string[] })), ...NAMED, ...SCOPED];
const CODE_EXT = new Set(['.ts', '.mts', '.cts', '.tsx', '.js', '.mjs', '.cjs', '.jsx']);

function walk(dir: string, out: string[]): void {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    if (ent.name === '.auth' || ent.name === 'node_modules') continue;
    const full = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(full, out);
    else if (ent.isFile() && CODE_EXT.has(path.extname(ent.name))) out.push(full);
  }
}

function sources(): Array<{ rel: string; text: string }> {
  const files: string[] = [];
  walk(path.join(REPO, 'e2e'), files);
  files.push(path.join(REPO, 'playwright.config.ts'));
  return files.map((f) => ({ rel: path.relative(REPO, f).split(path.sep).join('/'), text: fs.readFileSync(f, 'utf8') }));
}

function violations(files: ReadonlyArray<{ rel: string; text: string }>): string[] {
  const found: string[] = [];
  for (const f of files) {
    for (const r of RULES) {
      if (r.applies && !r.applies(f.rel)) continue;
      if (r.allowed.includes(f.rel)) continue;
      if (r.hit(f.text)) found.push(`${r.id} ${f.rel}`);
    }
  }
  return found;
}

test('static-gate: the scan covers e2e/** sources, the root config and this file', () => {
  const rels = sources().map((s) => s.rel);
  for (const must of [
    'playwright.config.ts', HTTP, OUT, ENV_CONTRACT, LAUNCH, SCAN, SECRET_INPUT, TEST_BASE, 'e2e/lib/authentik-flow.ts', 'e2e/auth.spec.ts', 'e2e/global-setup.ts',
    'e2e/global-teardown.ts', 'e2e/selftest/static-gate.test.ts', CONTROL, 'e2e/needle/needle.test.ts', 'e2e/revocation.spec.ts', 'e2e/lib/bff.ts', 'e2e/lib/kubectl-log.ts',
    'e2e/selftest-browser/authentik-flow.test.ts', 'e2e/selftest-browser/evidence.test.ts', 'e2e/selftest-browser/secret-input.test.ts', 'e2e/selftest-browser/fixture-guard.test.ts',
  ]) {
    expect(rels.includes(must), must).toBe(true);
  }
});

test('static-gate: no violations in e2e/** and the root config', () => {
  expect(violations(sources())).toEqual([]);
});

const BASE_LINE = J("import { test } from '../lib/test-", "base';\n");

// 규칙마다 심을 글자와 그 규칙이 적용되는 자리
const PLANTED: Record<string, { rel: string; text: string }> = {
  tracing: { rel: 'e2e/planted.ts', text: J('context.trac', 'ing.start()') },
  'record-har': { rel: 'e2e/planted.ts', text: J('{ record', 'Har: {} }') },
  'route-from-har': { rel: 'e2e/planted.ts', text: J('page.routeFrom', 'HAR(x)') },
  'record-video': { rel: 'e2e/planted.ts', text: J('{ record', 'Video: {} }') },
  attach: { rel: 'e2e/planted.ts', text: J('testInfo.att', 'ach("x")') },
  pause: { rel: 'e2e/planted.ts', text: J('page.pau', 'se()') },
  listener: { rel: 'e2e/planted.ts', text: J('page.on("re', 'quest", f)') },
  'to-be-ok': { rel: 'e2e/planted.ts', text: J('expect(r).toBe', 'OK()') },
  'to-have-url': { rel: 'e2e/planted.ts', text: J('expect(p).toHave', 'URL(u)') },
  'to-have-value': { rel: 'e2e/planted.ts', text: J('expect(l).toHave', 'Value(v)') },
  'input-value': { rel: 'e2e/planted.ts', text: J('await l.input', 'Value()') },
  'to-have-text': { rel: 'e2e/planted.ts', text: J('expect(l).toHave', 'Text(t)') },
  'to-contain-text': { rel: 'e2e/planted.ts', text: J('expect(l).toContain', 'Text(t)') },
  'to-match-aria-snapshot': { rel: 'e2e/planted.ts', text: J('expect(l).toMatchAria', 'Snapshot(s)') },
  'text-content': { rel: 'e2e/planted.ts', text: J('await l.text', 'Content()') },
  'inner-text': { rel: 'e2e/planted.ts', text: J('await l.inner', 'Text()') },
  'all-text-contents': { rel: 'e2e/planted.ts', text: J('await l.allText', 'Contents()') },
  'all-inner-texts': { rel: 'e2e/planted.ts', text: J('await l.allInner', 'Texts()') },
  'wait-for-request': { rel: 'e2e/planted.ts', text: J('page.waitFor', 'Request(u)') },
  'wait-for-navigation': { rel: 'e2e/planted.ts', text: J('page.waitFor', 'Navigation()') },
  'wait-for-event': { rel: 'e2e/planted.ts', text: J('page.waitFor', 'Event("x")') },
  'locator-matcher': { rel: 'e2e/planted.ts', text: J('await expect(page.locator("#x")).toBe', 'Visible()') },
  'to-match-snapshot': { rel: 'e2e/planted.ts', text: J('expect(buf).toMatch', 'Snapshot("a.png")') },
  'aria-snapshot': { rel: 'e2e/planted.ts', text: J('await l.aria', 'Snapshot()') },
  'inner-html': { rel: 'e2e/planted.ts', text: J('await l.inner', 'HTML()') },
  'page-content': { rel: 'e2e/planted.ts', text: J('await page.cont', 'ent()') },
  'get-attribute': { rel: 'e2e/planted.ts', text: J('await l.getAttri', 'bute("value")') },
  typing: { rel: 'e2e/planted.ts', text: J('await page.keyboard.ty', 'pe(s)') },
  'attachments-push': { rel: 'e2e/planted.ts', text: J('testInfo.attachments', '.push({ name: "x", body: b })') },
  'annotations-push': { rel: 'e2e/planted.ts', text: J('testInfo.annotations', '.push({ type: "x", description: d })') },
  'fd-write': { rel: 'e2e/planted.ts', text: J('fs.write', 'Sync(1, s)') },
  route: { rel: 'e2e/planted.ts', text: J('await page.rou', 'te("**/*", h)') },
  expose: { rel: 'e2e/planted.ts', text: J('await page.expose', 'Function("f", f)') },
  'test-use': { rel: 'e2e/planted.ts', text: J('test.us', 'e({ trace: "on" })') },
  'request-alias': { rel: 'e2e/planted.ts', text: J('async ({ requ', 'est: ctx }) => ctx.get(u)') },
  'request-property': { rel: 'e2e/planted.ts', text: J('const r = page.requ', 'est; await r.get(u)') },
  'snapshot-template': { rel: 'e2e/planted.ts', text: J('{ snapshotPath', 'Template: "{testDir}/x" }') },
  console: { rel: 'e2e/planted.ts', text: J('cons', 'ole.log(x)') },
  stdout: { rel: 'e2e/planted.ts', text: J('process.', 'stdout.write(x)') },
  stderr: { rel: 'e2e/planted.ts', text: J('process.', 'stderr.write(x)') },
  'storage-state-path': { rel: 'e2e/planted.ts', text: J('await c.storage', 'State({ path: f })') },
  screenshot: { rel: 'e2e/planted.ts', text: J('await expect(page).toHaveScreen', 'shot("a.png")') },
  'secret-env': { rel: 'e2e/planted.ts', text: J('const n = "JT_E2E_', 'SECRET_PASSWORD"') },
  'needle-set-env': { rel: 'e2e/planted.ts', text: J('const n = "JT_E2E_', 'NEEDLE_SET"') },
  'secret-env-read': { rel: 'e2e/planted.ts', text: J('process.env.JT_E2E_', 'SECRET_PASSWORD') },
  'needle-set-read': { rel: 'e2e/planted.ts', text: J('process.env.JT_E2E_', 'NEEDLE_SET') },
  'env-dynamic': { rel: 'e2e/planted.ts', text: J('const v = process.e', 'nv["JT_E2E_" + "SECRET_" + k]') },
  request: { rel: 'e2e/planted.ts', text: J('await requ', 'est.get(u)') },
  goto: { rel: 'e2e/planted.ts', text: J('await page.go', 'to(u)') },
  'wait-for-url': { rel: 'e2e/planted.ts', text: J('await page.waitFor', 'URL(u)') },
  'wait-for-response': { rel: 'e2e/planted.ts', text: J('await page.waitFor', 'Response(u)') },
  'url-read': { rel: 'e2e/planted.ts', text: J('const u = page.u', 'rl()') },
  'needle-prefix': { rel: 'e2e/planted.ts', text: J('const v = "JTNEE', 'DLE-pw-1"') },
  evaluate: { rel: 'e2e/planted.ts', text: J('await page.eval', 'uate(() => location.href)') },
  fill: { rel: 'e2e/planted.ts', text: J('await l.fi', 'll(secrets.password)') },
  'guard-fixture': { rel: 'e2e/planted.ts', text: J('base.extend({ jtFixture', 'Guard: [async ({}, use) => use(), { auto: true }] })') },
  'pw-test-import': { rel: 'e2e/planted.spec.ts', text: BASE_LINE + J("import { test as t2 } from '@playwright/", "test';") },
  'test-base-required': { rel: 'e2e/needle/planted.test.ts', text: 'const x = 1;' },
  'emit-args': { rel: 'e2e/planted.spec.ts', text: BASE_LINE + J('emit', 'Info(`cookie=${c.val', 'ue}`);') },
};

test('static-gate: every rule detects a planted pattern and stays quiet in its allowed files (positive control)', () => {
  expect(Object.keys(PLANTED).sort()).toEqual(RULES.map((r) => r.id).sort());
  for (const r of RULES) {
    const p = PLANTED[r.id];
    expect(violations([p]).includes(`${r.id} ${p.rel}`), `${r.id} detects`).toBe(true);
    for (const ok of r.allowed) expect(violations([{ rel: ok, text: p.text }]).includes(`${r.id} ${ok}`), `${r.id} allowed in ${ok}`).toBe(false);
  }
});

test('static-gate: rule details — listener forms, fill identity line, type-only imports, emit argument scope', () => {
  // 리스너는 따옴표 종류 · 공백과 무관하게, 탐색 이벤트도 잡는다
  expect(violations([{ rel: 'e2e/x.ts', text: J("page.once( 'con", "sole', f)") }])).toEqual(['listener e2e/x.ts']);
  expect(violations([{ rel: 'e2e/x.ts', text: J('page.on(`framena', 'vigated`, f)') }])).toEqual(['listener e2e/x.ts']);
  // 고정 신원 한 줄만 fill 예외다
  expect(violations([{ rel: 'e2e/x.ts', text: J('await email.fi', 'll(E2E_EMAIL)') }])).toEqual([]);
  expect(violations([{ rel: 'e2e/x.ts', text: J('await email.fi', 'll(E2E_EMAIL, { timeout: 1 })') }])).toEqual([]);
  expect(violations([{ rel: 'e2e/x.ts', text: J('await email.fi', 'll(E2E_EMAIL + x)') }])).toEqual(['fill e2e/x.ts']);
  // 타입 전용 import는 허용, 값 import · require는 위반
  expect(violations([{ rel: 'e2e/x.spec.ts', text: BASE_LINE + J("import type { Page } from '@playwright/", "test';") }])).toEqual([]);
  expect(violations([{ rel: 'e2e/selftest-browser/x.test.ts', text: BASE_LINE + J("const pw = require('@playwright/", "test');") }])).toEqual(['pw-test-import e2e/selftest-browser/x.test.ts']);
  // selftest(브라우저 0)는 test 기반 의무 밖이다
  expect(violations([{ rel: 'e2e/selftest/x.test.ts', text: J("import { test } from '@playwright/", "test';") }])).toEqual([]);
  // 줄 인자 검사는 실행 코드에만 — 값 출처가 없는 템플릿은 통과
  expect(violations([{ rel: 'e2e/lib/x.ts', text: J('emit', 'Info(`cookies count=${s.cookies.length}`)') }])).toEqual([]);
  expect(violations([{ rel: 'e2e/lib/x.ts', text: J('fa', 'il("cred", { prefix: "env", code: `missing ${secrets.password}` })') }])).toEqual(['emit-args e2e/lib/x.ts']);
  expect(violations([{ rel: 'e2e/selftest/x.test.ts', text: J('emit', 'Info(`v=${c.val', 'ue}`)') }])).toEqual([]);
  // 글자 속 낱말(copies=cleared · 'headers') · 다른 호출의 값은 위반이 아니다 — 인자 코드만 본다
  expect(violations([{ rel: 'e2e/lib/x.ts', text: J('emit', "Info(`t079 cleanup copies=cleared`, 'no headers');\nconst h = copies.session;") }])).toEqual([]);
  expect(violations([{ rel: 'e2e/lib/x.ts', text: J('emit', 'Step(T, "copy", "PASS", `n=${copies.session.length}`)') }])).toEqual(['emit-args e2e/lib/x.ts']);
  expect(argumentCode(J('emit', 'Info(`a ${x.val', 'ue} b`, "c(d)")'), J('emit', 'Info').length)).toBe(J('(  x.val', 'ue ,  )'));
});
