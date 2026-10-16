# packages/

앱들이 공유하는 라이브러리 패키지 디렉터리다. SP-1 이후 계획:

- `content/` — 콘텐츠 로더·스키마 (TypeScript, pnpm 워크스페이스)
- `events/` — 이벤트 스키마·계약 (TypeScript, pnpm 워크스페이스)
- `authz/` — OpenFGA 인가 모델
- `django-common/` — Django pod 공통 라이브러리 (Python, uv 워크스페이스)
