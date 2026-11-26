// e2e/lib/site-probe.ts — T087 h-6 · h-9 페이지 탐침(설계 specs/003-platform-foundation/design/t086-design.md D10 ⑤). 반환은 수 · 불리언뿐이다.
// static-gate 이름 붙은 예외 둘: evaluate(토큰 CSSOM을 페이지 안에서 판정 — 토큰 값은 페이지 밖으로 나오지 않는다) · request 이벤트 리스너(prefetch 계수기 —
// 헤더 하나만 보고 수만 센다 · 요청 객체 보관 0 · URL 읽기 0 · 모아 둔 요청 목록 읽기 0). 이 파일을 가져올 수 있는 것은 hello.spec.ts와 그 selftest-browser뿐이다
// (site-probe-import). 출력 0 — 줄은 spec이 out.ts로 낸다.
import type { Page, Request } from '@playwright/test';
import type { TokenLayers } from './site';

type ProbeOp = 'layers' | 'stash' | 'compare';

// 페이지 안에서 도는 함수 — 바깥 이름을 쓰지 않는다(직렬화돼 페이지로 간다).
// 같은 origin 스타일시트의 :root 규칙(미디어 · 지원 · 레이어 · import 안 포함 — dark 재정의도 선언으로 센다)에서 --jt-ref- · --jt-sys- · --jt-comp- 선언을 모은다.
//   layers  — 수 · 참조 방향 · 계산값 판정(TokenLayers). 해석할 수 없는 커스텀 속성의 계산값은 빈 문자열이다(VD-T087-2) — var( 가 남아도 실패로 본다.
//   stash   — 지금 색 구성표에서 ref 계산값 묶음을 페이지에 맡기고 ref 수를 돌려준다.
//   compare — 지금 계산값 묶음이 맡긴 것과 같으면 1, 다르면 0(맡긴 것은 지운다).
const tokenProbe = (op: ProbeOp): TokenLayers | number => {
  const REF = '--jt-ref-';
  const SYS = '--jt-sys-';
  const COMP = '--jt-comp-';
  const KEY = '__jtRefSnapshot';
  const decls: Array<[string, string]> = [];
  const isRoot = (sel: string): boolean => sel.split(',').some((s) => s.trim() === ':root');
  const walk = (rules: CSSRuleList): void => {
    for (const rule of Array.from(rules)) {
      const r = rule as CSSRule & { selectorText?: string; style?: CSSStyleDeclaration; cssRules?: CSSRuleList; styleSheet?: CSSStyleSheet | null };
      if (typeof r.selectorText === 'string' && r.style) {
        if (!isRoot(r.selectorText)) continue;
        for (let i = 0; i < r.style.length; i += 1) {
          const name = r.style.item(i);
          if (name.startsWith('--jt-')) decls.push([name, r.style.getPropertyValue(name)]);
        }
      } else if (r.cssRules) {
        walk(r.cssRules);
      } else if (r.styleSheet) {
        try {
          walk(r.styleSheet.cssRules);
        } catch {
          // 다른 origin의 import 시트는 판정 밖
        }
      }
    }
  };
  for (const sheet of Array.from(document.styleSheets)) {
    let rules: CSSRuleList;
    try {
      rules = sheet.cssRules;
    } catch {
      continue; // 다른 origin 시트는 읽을 수 없다(판정 밖)
    }
    walk(rules);
  }
  const ref = new Set<string>();
  const sys = new Set<string>();
  const comp = new Set<string>();
  for (const [n] of decls) {
    if (n.startsWith(REF)) ref.add(n);
    else if (n.startsWith(SYS)) sys.add(n);
    else if (n.startsWith(COMP)) comp.add(n);
  }
  const computed = getComputedStyle(document.documentElement);
  const value = (n: string): string => computed.getPropertyValue(n).trim();
  const w = window as unknown as Record<string, unknown>;
  if (op === 'stash' || op === 'compare') {
    const snap = JSON.stringify(Array.from(ref).sort().map((n) => [n, value(n)]));
    if (op === 'stash') {
      w[KEY] = snap;
      return ref.size;
    }
    const same = typeof w[KEY] === 'string' && w[KEY] === snap ? 1 : 0;
    delete w[KEY];
    return same;
  }
  const targets = (v: string): string[] => {
    const out: string[] = [];
    const re = /var\(\s*(--[A-Za-z0-9_-]+)/g;
    let m: RegExpExecArray | null;
    while ((m = re.exec(v)) !== null) out.push(m[1]);
    return out;
  };
  const all = [...Array.from(ref), ...Array.from(sys), ...Array.from(comp)];
  const allResolve = all.length > 0 && all.every((n) => value(n).length > 0 && !value(n).includes('var('));
  let sysRefsRefOrSys = true;
  let sysChainExists = false;
  let compAvoidsRef = true;
  let compChainExists = false;
  for (const [n, v] of decls) {
    if (n.startsWith(SYS)) {
      for (const t of targets(v)) {
        if (!t.startsWith(REF) && !t.startsWith(SYS)) sysRefsRefOrSys = false;
        if (ref.has(t)) sysChainExists = true;
      }
    } else if (n.startsWith(COMP)) {
      for (const t of targets(v)) {
        if (t.startsWith(REF)) compAvoidsRef = false;
        if (sys.has(t)) compChainExists = true;
      }
    }
  }
  return { refCount: ref.size, sysCount: sys.size, compCount: comp.size, allResolve, sysRefsRefOrSys, sysChainExists, compAvoidsRef, compChainExists };
};

// 페이지가 돌려준 것을 정해진 꼴로만 옮긴다(수 · 불리언 — 그 밖의 값은 버린다)
function asLayers(v: unknown): TokenLayers {
  const o = (typeof v === 'object' && v !== null ? v : {}) as Record<string, unknown>;
  const num = (k: string): number => {
    const x = o[k];
    return typeof x === 'number' && Number.isFinite(x) ? x : -1;
  };
  const flag = (k: string): boolean => o[k] === true;
  return {
    refCount: num('refCount'),
    sysCount: num('sysCount'),
    compCount: num('compCount'),
    allResolve: flag('allResolve'),
    sysRefsRefOrSys: flag('sysRefsRefOrSys'),
    sysChainExists: flag('sysChainExists'),
    compAvoidsRef: flag('compAvoidsRef'),
    compChainExists: flag('compChainExists'),
  };
}

// h-6 — 토큰 3계층(86-4): 수 · ref/sys/comp 참조 방향 · 계산값이 모두 해석되는가
export async function probeTokenLayers(page: Page): Promise<TokenLayers> {
  return asLayers(await page.evaluate(tokenProbe, 'layers'));
}

// h-6 — dark 색 구성표에서 ref(원시 값)가 그대로인가(테마는 sys만 다시 잇는다 — web.md:54). ref가 없으면 거짓(공허한 참 0). 끝나면 light로 돌려 놓는다.
export async function refStableUnderDark(page: Page): Promise<boolean> {
  await page.emulateMedia({ colorScheme: 'light' });
  const n = await page.evaluate(tokenProbe, 'stash');
  await page.emulateMedia({ colorScheme: 'dark' });
  const same = await page.evaluate(tokenProbe, 'compare');
  await page.emulateMedia({ colorScheme: 'light' });
  return typeof n === 'number' && n > 0 && same === 1;
}

// h-9 — Next-Router-Prefetch: 1 요청 수(web.md:17). 계수 창 = 시작부터 stop()까지 — 시작 전 · 멈춘 뒤는 세지 않는다. 요청 객체는 보관하지 않는다.
export const PREFETCH_HEADER = 'next-router-prefetch';

export interface PrefetchCounter {
  stop(): number;
}

export function startPrefetchCounter(page: Page): PrefetchCounter {
  let n = 0;
  let open = true;
  const onPrefetch = (r: Request): void => {
    if (open && r.headers()[PREFETCH_HEADER] === '1') n += 1;
  };
  page.on('request', onPrefetch);
  return {
    stop: (): number => {
      if (open) {
        open = false;
        page.off('request', onPrefetch);
      }
      return n;
    },
  };
}
