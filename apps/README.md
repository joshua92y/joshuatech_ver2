# apps/

배포 단위 애플리케이션이 들어가는 디렉터리다. SP-1 이후 계획:

- `web/` — Next.js + OpenNext(Cloudflare Workers) 프런트엔드·BFF
- `identity-admin/` — Django pod (계정·테넌트·세션 관리)

pod 하나 = 디렉터리 하나 = 소유 데이터베이스 하나(헌법 III).
