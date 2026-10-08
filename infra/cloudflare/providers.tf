# plan/apply는 운영자만 실행한다 — 에이전트는 어떤 프로바이더 자격 증명도 갖지 않으며
# apply를 절대 실행하지 않는다(에이전트의 이 스택 검증은 `init -backend=false`·`validate`·`fmt -check`뿐).
#
# Cloudflare API 토큰은 환경 변수 CLOUDFLARE_API_TOKEN 으로만 전달한다
# (운영자의 joshuatech-tofu-deploy 토큰, 패스워드 매니저 보관). 토큰을 코드·tfvars에 적어 커밋하는 것은 금지다.
# 토큰에 필요한 권한(운영자 확인): Zone:Read · DNS:Edit · Zone Settings:Edit · Zone WAF:Edit(rulesets) ·
# Access: Apps and Policies:Edit · Access: Service Tokens:Edit · Access: Organizations, Identity Providers, and Groups:Edit ·
# Cloudflare Tunnel:Edit · Workers Scripts:Edit(커스텀 도메인) · Workers R2 Storage:Edit — 존 joshuatech.dev 와 그 계정 한정.

provider "cloudflare" {}
