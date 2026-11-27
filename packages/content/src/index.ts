// packages/content/src/index.ts — T090: 공개 표면(D2) — 재수출만(import만으로 파일 접근 · 출력 0).
//
// 값: getCollection · ContentValidationError(머리 :12–:31 고정) · COLLECTIONS · LANGS(T091 생성 스크립트의 반복용 — LANGS = 로케일).
// 형: ContentItem · ContentIssue · Collection · Lang · Frontmatter · Heading.
// Node 전용(T086-e): 페이지 · 레이아웃은 생성 산출물만 import하고 이 패키지에서는 import type만 쓴다(web.md).
// Shiki 코드 언어 목록(mdx.ts CODE_LANGS)은 내부 상수라 내보내지 않는다(〔A-24〕 ②).

export { ContentValidationError, getCollection } from './loader.ts';
export type { ContentIssue, ContentItem } from './loader.ts';
export { LANGS } from './mdx.ts';
export type { Heading, Lang } from './mdx.ts';
export { COLLECTIONS } from './schema.ts';
export type { Collection, Frontmatter } from './schema.ts';
