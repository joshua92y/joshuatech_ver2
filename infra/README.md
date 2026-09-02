# infra/

인프라 선언(OpenTofu)과 부트스트랩 스크립트 디렉터리다. SP-1 이후 계획:

- `oci/` — OCI 인스턴스·네트워크·버킷·IAM
- `cloudflare/` — DNS·Workers·Access·R2
- `vault/` — Vault 정책·auth·시크릿 엔진
- `grafana/` — Grafana Cloud 리소스
- `bootstrap/` — K3s·Argo CD 초기 설치 스크립트

상태 파일(`*.tfstate`)은 커밋하지 않는다(원격 state: OCI Object Storage `jt-tfstate`).
