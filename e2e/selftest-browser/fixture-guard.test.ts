// e2e/selftest-browser/fixture-guard.test.ts — 공통 test 기반(lib/test-base.ts)의 자동 재단언 픽스처가 실제로 걸리는지 보는 양성 대조(빌드 리뷰 r1 — B-3 · C-1).
// 리뷰가 실측한 우회 꼴 그대로 파일 맨 위에서 기록 옵션을 덮는다(워커 범위 옵션은 파일 맨 위에서만 덮을 수 있다 — 1.65.1). 이 파일의 test는 페이지 · 컨텍스트를
// 만들기 전에 [guard] fixture-override로 실패해야 하므로 실패를 기대하는 시험으로 둔다. 자동 픽스처가 빠지거나(auto 해제) 그 값을 보지 않으면 통과해 버려
// 「기대한 실패 없음」으로 실패한다. 이 파일은 static-gate test-use 규칙의 이름 붙은 예외 하나다(로컬 · 네트워크 0 · 페이지 0). 이 대조는 [guard] 줄 하나를 낸다.
// (extend로 옵션 픽스처의 기본값을 바꾸는 꼴은 프로젝트 설정 use가 다시 덮어 실효가 없다 — 1.65.1 실측.)
import { test } from '../lib/test-base';

test.use({ screenshot: 'only-on-failure' });

test.fail('fixture-guard: a recording option overridden inside a file stops the test before any page (expected failure)', async () => {
  // 몸체는 비어 있다 — 자동 픽스처가 걸리지 않으면 이 시험은 통과해 버린다
});
