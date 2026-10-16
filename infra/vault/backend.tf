# 원격 상태: OCI Object Storage S3 호환 API (버킷 joshuatech-tfstate) — infra/oci·infra/cloudflare와 같은 버킷, 키만 다르다.
#
# 운영자 전용 절차 — 에이전트는 절대 실행하지 않는다(에이전트는 `init -backend=false`까지만):
#   0. **새 창의 첫 줄**: Set-PSReadLineOption -HistorySaveStyle SaveNothing ; try { Stop-Transcript } catch {}
#      (오류 "현재 전사 중이 아닙니다"가 정상; 경로가 출력되면 전사가 켜져 있던 것 → 그 파일 삭제 후 새 창 — `$Transcript`는 자동 변수가 아니라 프로브가 못 된다)
#      ; 정책 전사 확인: Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription','HKCU:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription' -EA SilentlyContinue | % EnableTranscripting → 값 없음/0
#      (런북 §0 창 시작 체크리스트)
#   1. Vault가 port-forward로 도달 가능해야 한다(별도 창): kubectl -n vault port-forward svc/vault 18200:8200   # admin kubeconfig
#   2. provider 자격은 환경변수로만 준다(파일·.tf·명령줄 리터럴 금지, `vault login` 금지 — ~/.vault-token 잔존):
#        $env:VAULT_ADDR  = 'http://127.0.0.1:18200'
#        $env:VAULT_TOKEN = (Read-Host -AsSecureString 'VAULT_TOKEN' | ConvertFrom-SecureString -AsPlainText)   # 비밀번호 관리자에서 붙여넣기
#   3. init/plan/apply:
#        $env:AWS_REQUEST_CHECKSUM_CALCULATION='when_required'; tofu -chdir=infra/vault init
#        tofu -chdir=infra/vault plan -out=t044.tfplan      # 기대: 15 to add / 0 to change / 0 to destroy
#        tofu -chdir=infra/vault apply t044.tfplan
#   3b. 부분 적용 복구 — 재apply가 "path is already in use at kv/ | kubernetes/"로 실패할 때(마운트·auth 2개는 upsert가 아니다;
#       config·policy·role 13개는 재apply로 수렴): tofu -chdir=infra/vault import vault_mount.kv kv ;
#       tofu -chdir=infra/vault import vault_auth_backend.kubernetes kubernetes → plan이 0 destroy인지 확인한 뒤 apply.
#       `vault secrets disable kv`로 풀지 않는다(kv 데이터 소멸).
#   4. 끝나면 Remove-Item Env:VAULT_TOKEN ; Remove-Item infra/vault/t044.tfplan ; Test-Path $env:USERPROFILE\.vault-token → False
#
# 상태 파일에는 시크릿이 들어가지 않는다: kv 값을 관리하지 않고(vault_generic_secret·vault_kv_secret* 금지), auth/kubernetes/config에
# token_reviewer_jwt·kubernetes_ca_cert를 설정하지 않는다(Vault가 자기 파드의 로컬 SA 토큰을 리뷰어로 쓴다). 다만 상태·plan은
# "누가 무엇을 읽을 수 있는가"의 완전한 인가 지도이므로 비공개·버저닝 버킷을 유지하고 plan 파일은 로컬에 남기지 않는다.
#
# profile "joshuatech-tfstate": 운영자가 svc-tfstate 사용자의 Customer Secret Key를 로컬 ~/.aws/credentials에 보관한다.
terraform {
  backend "s3" {
    bucket  = "joshuatech-tfstate"
    key     = "vault/terraform.tfstate"
    region  = "ap-chuncheon-1"
    profile = "joshuatech-tfstate"

    # axvjykgvo2m1 = 테넌시 Object Storage 네임스페이스(infra/oci/backend.tf와 동일).
    endpoints = {
      s3 = "https://axvjykgvo2m1.compat.objectstorage.ap-chuncheon-1.oraclecloud.com"
    }

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true

    # OCI S3 호환 API는 조건부 쓰기 기반 lockfile을 지원하지 않는다.
    use_lockfile = false
  }
}
