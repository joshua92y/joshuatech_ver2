# T045 G3 머지 전 기준값 캡처 — platform-gitops `platform/secrets/README.md` §2의 블록 그대로(추출 2026-09-21).
# 실행: 창 D에서 **dot-source**로 — `. <이 파일 경로>` ($preHash · $preUid · $sha 가 세션에 남아야 머지 뒤 게이트가 쓴다).
# 값은 화면에 나오지 않는다. 남는 것은 해시와 UID뿐이다(비밀 아님).
$ErrorActionPreference = 'Stop'
# ⚠ DNS 토큰 값 자체를 세션 변수로 남기지 않는다(존 전체 DNS 쓰기 권한). 비교는 해시로만 한다 —
#    복구용 원본은 PM과 Vault kv에 있다.
$sha     = { param($s) [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([string]$s))) }
# 가드 ⓐ — **아직 인수 전인가.** 인수가 이미 일어난 뒤에 캡처하면 preHash = 덮인 값이라 게이트 ③이 가짜 PASS를 낸다.
#   ESO는 인수 첫 단계에서 managed 라벨을 반드시 붙인다(provider 조회 실패·인수 해제 뒤에도 라벨은 남는다).
$m = kubectl -n cert-manager get secret cloudflare-dns-token -o 'jsonpath={.metadata.labels.reconcile\.external-secrets\.io/managed}'
if ($LASTEXITCODE -ne 0) { throw 'managed 라벨 조회 실패 — 판정 불가' }
if (-not [string]::IsNullOrWhiteSpace($m)) { throw '이미 ESO가 손댄 Secret이다 — 기준값으로 쓸 수 없다(이전 시도·인수 해제 뒤에도 라벨은 남는다. PM 원본과 대조한다)' }
# 가드 ⓑ — **키 집합.** ES가 매핑하지 않은 키는 인수 순간 삭제된다(2026-09-21 DR1 실측). 값은 출력하지 않는다.
$keys = kubectl -n cert-manager get secret cloudflare-dns-token -o 'go-template={{range $k,$v := .data}}{{$k}}{{"\n"}}{{end}}'
if ($LASTEXITCODE -ne 0) { throw '키 목록 취득 실패' }
if (-not [string]::Equals((@($keys) -join ','), 'api-token', [StringComparison]::Ordinal)) { throw "api-token 외의 키가 있다($(@($keys) -join ',')) — 인수하면 삭제된다. ES 매핑에 추가하기 전에는 머지하지 않는다" }
$b64     = kubectl -n cert-manager get secret cloudflare-dns-token -o 'jsonpath={.data.api-token}'
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($b64)) { throw '인수 전 값 취득 실패' }
$preHash = & $sha $b64
Remove-Variable b64
$preUid  = kubectl -n cert-manager get secret cloudflare-dns-token -o 'jsonpath={.metadata.uid}'
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($preUid)) { throw '인수 전 UID 취득 실패' }
'캡처 완료: preHash · preUid 보관(값 아님). 이제 PR을 머지한다.'
