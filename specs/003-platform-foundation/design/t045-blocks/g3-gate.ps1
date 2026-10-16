# T045 G3 머지 뒤 게이트 — platform-gitops `platform/secrets/README.md` §2의 블록 그대로(추출 2026-09-21).
# 실행: 캡처를 한 **같은 창**에서 dot-source — `. <이 파일 경로>`. 기대 출력: `OK 값 불변 · UID 불변 · ownerRef 없음`.
if (-not $preHash -or -not $preUid -or -not $sha) { throw '기준값이 세션에 없다 — 캡처를 같은 창에서 dot-source 로 실행했는지 확인(머지 뒤에는 다시 캡처할 수 없다)' }
$ErrorActionPreference = 'Stop'
try {
  $r = kubectl -n cert-manager get externalsecret cloudflare-dns-token -o 'jsonpath={.status.conditions[?(@.type=="Ready")].reason}'
  if ($LASTEXITCODE -ne 0) { throw 'ES 상태 취득 실패 — 판정 불가' }
  if (-not [string]::Equals($r, 'SecretSynced', [StringComparison]::Ordinal)) { throw "ES reason=$r — provider 실패면 Secret의 값·UID는 미변경이다(managed 라벨만 붙는다). Events·ESO 로그를 §1의 표로 가른다" }
  $post = kubectl -n cert-manager get secret cloudflare-dns-token -o 'jsonpath={.data.api-token}'
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($post)) { throw '인수 후 값 취득 실패' }
  $postHash = & $sha $post
  Remove-Variable post
  $postUid = kubectl -n cert-manager get secret cloudflare-dns-token -o 'jsonpath={.metadata.uid}'
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($postUid)) { throw '인수 후 UID 취득 실패' }
  $own = kubectl -n cert-manager get secret cloudflare-dns-token -o 'jsonpath={.metadata.ownerReferences}'
  if ($LASTEXITCODE -ne 0) { throw 'ownerReferences 조회 실패 — 판정 불가(빈 문자열을 "없음"으로 읽지 않는다)' }
  if (-not [string]::Equals($preHash, $postHash, [StringComparison]::Ordinal)) { throw '값이 바뀌었다 — G4로 가지 않는다. kv 재확인' }
  if (-not [string]::Equals($preUid,  $postUid,  [StringComparison]::Ordinal)) { throw 'UID가 바뀌었다 = 제자리 인수가 아니다 — G4로 가지 않는다' }
  if (-not [string]::IsNullOrWhiteSpace($own))                                 { throw 'ownerReferences가 붙었다 — creationPolicy가 Orphan이 아니다. ES를 지우지 말고 매니페스트 확인' }
  'OK 값 불변 · UID 불변 · ownerRef 없음'
}
finally {
  Remove-Variable post, postHash, postUid, own, r -ErrorAction SilentlyContinue
}
