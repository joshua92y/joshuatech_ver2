# 기존 인스턴스 2대 — `tofu plan -generate-config-out` 결과(2026-09-03)를 정리한 파일 (T008).
# 현재 상태 그대로 코드화(diff 0 목표) — 알려진 편차는 후속 태스크에서 수정한다:
#   are_legacy_imds_endpoints_disabled: T010(2026-09-03)에서 false → true(IMDS v1 비활성; provider 문서상 instance_options와
#   그 하위 필드 모두 (Updatable) → in-place 갱신), boot 볼륨 47GB → T013(노드 B, 아래 절차)/T014(노드 A).
# T009(2026-09-03): nsg_ids 배선(노드 A: platform+cluster, 노드 B: cluster) —
#   provider 문서상 create_vnic_details.nsg_ids는 (Updatable)이라 VNIC in-place 갱신이다.
#   plan이 replace를 요구하면 prevent_destroy가 막는다 — 그 경우 진행하지 말고 보고한다.
#   assign_public_ip는 ignore_changes에 둔다 — 영구 가드(T010에서 문구 정정; 블록 내 주석).
# metadata의 ssh_authorized_keys는 공개 키이며 비밀이 아니다. 두 노드 모두 v1 키 리터럴이며 인스턴스가 사는 동안 바뀌지 않는다 — OCI API 는
#   metadata 의 user_data·ssh_authorized_keys 를 launch 뒤 불변으로 취급한다(아래 근거; 운영자 실측 2026-09-04 400 InvalidParameter).
#   실제 로그인 키 교체는 호스트의 ~ubuntu/.ssh/authorized_keys 에서 한다(T013 은 아래 6단계 수동, T014 는 host-prep.sh).
#
# ---- T013 재이미지 리허설: 노드 B joshtech_cache (Ubuntu 24.04, 부트 100 GB) — 운영자 절차 (완료 2026-09-04, 기록 docs/runbooks/bootstrap.md §2) ----
# 에이전트는 plan/apply·SSH·oci 변경 명령을 실행하지 않는다. 아래는 운영자가 사용자 재확인 뒤 순서대로 실행한다(PowerShell 7 기준).
# 변수는 variables.tf(ubuntu_2404_image_ocid·node_boot_volume_size_gb) — T014 는 노드 A에 같은 변수를 배선했다(아래 "T014" 절이 이 절차를 노드 A 값으로 반복한다).
#
# 스키마·API 근거(provider oracle/oci 8.29.0 internal/service/core/core_instance_resource.go, oci-go-sdk core/update_instance_details.go,
# cloud-init cloudinit/sources/DataSourceOracle.py 원문 확인 2026-09-04):
#   - source_details.source_id·boot_volume_size_in_gbs·is_preserve_boot_volume_enabled·kms_key_id 에는 ForceNew 가 없다 → in-place UPDATE.
#     source_id 가 바뀌면 Update() 가 UpdateInstance(sourceDetails = UpdateInstanceSourceViaImageDetails: imageId·bootVolumeSizeInGBs·
#     isPreserveBootVolumeEnabled; kmsKeyId 는 GetOk 라 빈 문자열이면 생략)를 보내고 work request 완료까지 기다린다.
#   - source_details.boot_volume_vpus_per_gb 는 ForceNew 다 — "10" 을 바꾸면 replace(prevent_destroy 가 막는다). 절대 건드리지 않는다.
#   - is_preserve_boot_volume_enabled = true: 문서 "교체 성공 뒤 이전에 붙어 있던 부트 볼륨을 보존" — 구 볼륨은 detached 로 남고 운영자가 삭제한다.
#     최상위 preserve_boot_volume 은 terminate 시의 보존 옵션이라 이 교체와 무관하다(설정하지 않는다).
#   - update_operation_constraint = "ALLOW_DOWNTIME": SDK/API 기본값이 ALLOW_DOWNTIME 이고, AVOID_DOWNTIME 이면 재부팅이 필요한 이 교체를 거부한다.
#     명시는 기본값 의존을 없애 의도를 고정하기 위한 것이다. Update() 가 요청에 그대로 싣는다.
#   - metadata: OCI API(UpdateInstanceDetails.metadata·extendedMetadata)는 "user_data 와 ssh_authorized_keys 는 launch 뒤 바꿀 수 없다 —
#     갱신·삭제·추가 요청은 거부된다"(운영자 실측 2026-09-04: instance update --metadata → 400 InvalidParameter). provider 도
#     CustomizeDiff(ForceNewIfChange("metadata"))로 두 키의 변경을 replace 로 만든다. 따라서 (a) metadata 는 ignore_changes 에 두고 어떤
#     도구로도 건드리지 않는다, (b) 재이미지된 볼륨의 첫 부팅에서 cloud-init(OCI datasource, IMDS v2)이 불변 metadata 의 v1 키를
#     ~ubuntu/.ssh/authorized_keys 에 넣는다, (c) cloud-config(user_data)로 키를 갈아끼우는 길은 없다(user_data 추가도 거부되고, cloud-init
#     DataSourceOracle 은 user_data 를 metadata.user_data 에서만 읽는다), (d) 그러므로 키 교체는 6단계에서 v1 키로 접속해 authorized_keys 를
#     joshuatech-ops 로 덮어쓰는 호스트 작업이다. v1 개인키 파기는 §0 토큰 표 ⑦ 순서(T103·T105 뒤)를 따른다.
#   - 임시 SSH 22 규칙은 tofu 코드에 두지 않는다: tests/infra/tofu.tests.ps1 nsg-3/nsg-4 는 구성에 선언된 규칙 리소스마다 planned 인스턴스가
#     0 이면 fail closed(count/for_each 게이트 불가)이고, nsg-1 은 NSG 정확히 2개·노드 B = nsg-cluster 만(전용 NSG 불가)이다. 그래서 규칙은
#     OCI CLI 로 넣고 CLI 로 뺀다(5·8단계) — .claude/rules/infra.md "22 는 cloudflared 만"의 부트스트랩 예외(운영자 /32, CLI 창)이며 desired
#     state(git)에는 22 ingress 가 없다. tofu 는 규칙을 개별 리소스로만 추적하므로 CLI 규칙은 plan 에 드러나지 않는다 — 제거의 증거는 8단계의
#     nsg rules list 뿐이다. 운영자 IP 는 저장소에 적지 않는다.
#   - 교체 뒤에도 VNIC·사설 IP 10.0.10.193·reserved 공개 IP 129.154.62.250·nsg-cluster 소속은 그대로다(VNIC 은 재생성되지 않는다).
#
# 0. 셸 준비(값은 저장소·채팅에 적지 않는다):
#   $env:TF_VAR_budget_alert_email = '...'                                   (T010 부터 필수)
#   $env:CLOUDFLARE_API_TOKEN      = '...'                                   (data.cloudflare_ip_ranges)
#   $env:AWS_REQUEST_CHECKSUM_CALCULATION = 'when_required'                  (backend.tf 주석)
#   $env:TEMP_SSH_CIDR = '<운영자 공인 IP>/32'   (tofu 변수가 아니다 — 5단계 CLI 전용)
#   if ($env:TEMP_SSH_CIDR -notmatch '^\d{1,3}(\.\d{1,3}){3}/32$') { throw 'TEMP_SSH_CIDR must be /32' }
#   $PUB = (Get-Content "$HOME\.ssh\joshuatech-ops.pub" -Raw).Trim()
#   if ($PUB -notmatch '^(ssh-ed25519|sk-ssh-ed25519@openssh\.com) \S+') { throw 'joshuatech-ops.pub: ssh-ed25519 또는 sk-ssh-ed25519@openssh.com 한 줄이어야 한다' }
#   (ssh/scp 의 -o IdentitiesOnly=yes: ssh-agent 에 v1·새 키가 함께 실려 있어도 -i 로 지정한 키만 제시한다 — 6단계 ①②③ 의 "어느 키로 열렸는가" 검증이 성립하는 조건)
#   $V1KEY = '<v1 개인키 경로>'   (재이미지 직후 유일하게 통하는 키 — 6단계에서만 쓴다; 파기는 §0 ⑦ 순서)
#   $NODE_B = 'ocid1.instance.oc1.ap-chuncheon-1.an4w4ljr46wbjmqcplrmdldp75dpapkzvlrfx6oxpm4jluti3vpyn7rpersa'
#   $TEN    = 'ocid1.tenancy.oc1..aaaaaaaat7iglpjj2kugdmf7an2v4uimrxr3ggtwo4txkbwptfjh5apddzpa'   (var.compartment_ocid 기본값)
#   $IMG    = 'ocid1.image.oc1.ap-chuncheon-1.aaaaaaaalxokbvhkaibe6ieaosyvzxih2xyglm3ypyiedbg3x4rpifmauw5a'   (var.ubuntu_2404_image_ocid 기본값)
#   $AD     = 'TxjY:AP-CHUNCHEON-1-AD-1'
#   $tmp = Join-Path $env:TEMP 't013'; New-Item -ItemType Directory -Force $tmp | Out-Null
# 1. 사전 확인(읽기 전용): 현재 이미지가 Ubuntu 인지, 목표 이미지가 AVAILABLE 인지, 블록 스토리지 한도, 구 부트 볼륨 OCID(OLD_BV) 기록
#   $cur = oci compute instance get --instance-id $NODE_B --query 'data."source-details"."image-id"' --raw-output
#   oci compute image get --image-id $cur --query 'data.{name:"display-name",os:"operating-system",ver:"operating-system-version"}'
#   oci compute image get --image-id $IMG --query 'data.{name:"display-name",state:"lifecycle-state"}'   → Canonical-Ubuntu-24.04-aarch64-2026.07.17-0 / AVAILABLE
#   oci limits resource-availability get --service-name block-storage --limit-name total-storage-gb --compartment-id $TEN --availability-domain $AD
#     → available 이 100 이상이어야 한다(preserve 방식은 창 동안 47 + 100 GB 가 공존; T014 는 다시 +100).
#   $OLD_BV = oci compute boot-volume-attachment list --availability-domain $AD --compartment-id $TEN --instance-id $NODE_B --query 'data[?"lifecycle-state"==`ATTACHED`]."boot-volume-id" | [0]' --raw-output
#     (정본은 이 ATTACHED 필터 조회다. tofu output node_b_boot_volume_id 는 참고값: provider getBootVolume 이 attachment 목록 Items[0] 을 상태 필터
#      없이 취하므로 교체 뒤에는 DETACHED 구 볼륨이 올 수 있다.)
# 2. metadata 는 건드리지 않는다(API 불변 — 위 근거). oci compute instance update --metadata 를 실행하지 말 것: 두 키의 갱신·추가는 400 으로
#    거부되고, 다른 키를 빠뜨린 요청도 실패한다. 이 단계의 유일한 사전 조건은 v1 개인키($V1KEY)가 손에 있는 것이다(6단계에서 쓴다).
# 3. plan(사용자 재확인 전 검토): 기대 = oci_core_instance.node_b update in-place 1 (source_details.source_id 구 → Ubuntu 24.04,
#    boot_volume_size_in_gbs "47" → "100", is_preserve_boot_volume_enabled false → true, update_operation_constraint null → "ALLOW_DOWNTIME"),
#    destroy 0·replace 0, 그 외 리소스 변경 0(요약 "0 to add, 1 to change, 0 to destroy"), Outputs: + node_b_boot_volume_id(참고값; 이 시점엔 OLD_BV)·+ nsg_cluster_id.
#    다른 변경(특히 metadata, node_a, NSG 규칙)이 하나라도 있으면 apply 금지 → 보고.
#   tofu -chdir=infra/oci plan -out=t013.tfplan
# 4. apply(사용자 재확인 뒤): tofu -chdir=infra/oci apply t013.tfplan   (work request 수 분; 인스턴스는 재부팅되고 새 부트 볼륨으로 뜬다)
#   $NEW_BV = oci compute boot-volume-attachment list --availability-domain $AD --compartment-id $TEN --instance-id $NODE_B --query 'data[?"lifecycle-state"==`ATTACHED`]."boot-volume-id" | [0]' --raw-output
#   if (-not $NEW_BV -or $NEW_BV -eq $OLD_BV) { throw 'boot volume not replaced' }   (tofu output 은 참고값 — 1단계 주석)
# 5. 임시 SSH 규칙(nsg-cluster, 운영자 IP /32, 22/tcp). 두 노드 모두 이 NSG 에 있으므로 창은 짧게, 끝나면 반드시 8단계:
#   $NSG = tofu -chdir=infra/oci output -raw nsg_cluster_id
#   @(@{ direction='INGRESS'; protocol='6'; source=$env:TEMP_SSH_CIDR; sourceType='CIDR_BLOCK'; isStateless=$false; description='T013 temp ssh (remove me)';
#        tcpOptions=@{ destinationPortRange=@{ min=22; max=22 } } }) | ConvertTo-Json -AsArray -Compress -Depth 5 | Set-Content -NoNewline -Encoding ascii "$tmp\temp-ssh.json"
#   oci network nsg rules add --nsg-id $NSG --security-rules "file://$tmp\temp-ssh.json"
#   $RULE = oci network nsg rules list --nsg-id $NSG --query 'data[?description==`T013 temp ssh (remove me)`].id | [0]' --raw-output
#   if (-not $RULE) { throw 'temp rule id missing' }
# 6. SSH 확인 + 로그인 키 교체 — 순서는 "추가 → 새 키로 검증 → v1 제거"(새 키가 실패하면 v1 이 그대로 남아 잠금 경로 0). 직접 22 는 이 리허설
#    창에서만; 이후는 cloudflared 터널만(.claude/rules/infra.md):
#   ssh-keygen -R 129.154.62.250   (새 볼륨 = 새 host key)
#   ssh -o IdentitiesOnly=yes -i $V1KEY ubuntu@129.154.62.250 'cloud-init status --wait; lsb_release -a'   → "status: done"(exit 0) 또는 "degraded done"(exit 2)이면 진행 / "Ubuntu 24.04.x LTS"
#     (첫 부팅의 cloud-init 이 불변 metadata 의 v1 키를 넣었으므로 이 시점엔 v1 으로만 열린다; --wait 로 cloud-init 종료를 기다린 뒤에만 손댄다)
#   ① 추가(v1 키로):
#     ssh -o IdentitiesOnly=yes -i $V1KEY ubuntu@129.154.62.250 "printf '%s\n' '$PUB' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && wc -l ~/.ssh/authorized_keys"   → 2
#   ② 새 키로 접속해 v1 제거(새 키 접속 자체가 검증이다; 이 명령을 v1 키로 실행하지 말 것):
#     ssh -o IdentitiesOnly=yes -i "$HOME\.ssh\joshuatech-ops" ubuntu@129.154.62.250 "grep -v wlsgh@Home-2024 ~/.ssh/authorized_keys > ~/.ssh/ak.new && mv ~/.ssh/ak.new ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && grep -c wlsgh@Home-2024 ~/.ssh/authorized_keys; wc -l ~/.ssh/authorized_keys; lsb_release -ds"   → 0 / 1 / Ubuntu 24.04
#     (②의 접속이 실패하면 authorized_keys 는 v1 + 새 키 그대로다 — 키·에이전트를 점검하고 ②만 다시 한다. grep -v 결과가 비면 mv 전에 멈춘다.)
#   ③ v1 거부 확인:
#     ssh -o IdentitiesOnly=yes -i $V1KEY ubuntu@129.154.62.250 true   → Permission denied (publickey) 여야 한다
#   (이 시점부터 노드 B 의 로그인 키는 joshuatech-ops 뿐이다. 이후 재부팅에서 cloud-init ssh 모듈은 per-instance 라 v1 키를 다시 넣지 않는다 —
#    단 `cloud-init clean` 이나 /var/lib/cloud 삭제는 금지: 다음 부팅에 불변 metadata 의 v1 키가 재주입된다. 재이미지마다 v1 키가 들어오는 것은
#    정상이며 T014 host-prep.sh 의 멱등 교체(같은 ①→②→③ 순서를 상속)가 흡수한다. 나머지 호스트 준비(iptables·wireguard·패키지 등)도 T014 몫이라
#    여기서는 하지 않는다.)
# 7. 구 부트 볼륨 삭제(교체 뒤 detached·AVAILABLE 인지 먼저 확인; delete 프롬프트 y):
#   oci bv boot-volume get --boot-volume-id $OLD_BV --query 'data.{state:"lifecycle-state",gb:"size-in-gbs"}'   → AVAILABLE / 47
#   oci compute boot-volume-attachment list --availability-domain $AD --compartment-id $TEN --boot-volume-id $OLD_BV --query 'data[?"lifecycle-state"==`ATTACHED`]'   → 빈 목록
#   oci bv boot-volume delete --boot-volume-id $OLD_BV
# 8. 임시 규칙 제거 + 확인 — --security-rule-ids 는 인라인 JSON 이어야 한다(T013 실측: file:// 형식은 "Unable to process JSON input" 으로 실패):
#   oci network nsg rules remove --nsg-id $NSG --security-rule-ids "[`"$RULE`"]"
#   oci network nsg rules list --nsg-id $NSG --query 'length(data)'   → 1 (자기참조 all 하나만) — 임시 규칙 제거의 유일한 증거다
#   tofu -chdir=infra/oci plan -detailed-exitcode   → exit 0 "No changes" — 규칙 제거의 증명이 아니라(tofu 는 CLI 규칙을 못 본다) 재이미지 뒤 회귀 검사다.
#     source_details.boot_volume_size_in_gbs 나 boot_volume_id 의 변경이 보이면 STOP: provider 가 DETACHED 구 attachment(Items[0])를 읽은 것이다 —
#     7단계 삭제가 끝났는지 확인하고 다시 plan, 그래도 남으면 apply 하지 말고 보고(구 볼륨 리사이즈 경로).
# 9. 하네스: 같은 셸(TF_VAR_budget_alert_email 설정)에서 pwsh -NoProfile -File tests/infra/tofu.tests.ps1 — plan 단언 포함 전부 PASS 여야 한다.
#
# ---- T014 노드 A joshtech_api_1st 재이미지 — T013 절차 0–9 를 아래 치환으로 반복한다(운영자, 사용자 재확인 뒤; 6단계만 host-prep.sh 로 바뀐다) ----
# 노드 A 값: $NODE_A = 'ocid1.instance.oc1.ap-chuncheon-1.an4w4ljr46wbjmqcqnacrfilhr4yro4dizvsplrti2lcyt4cnf43fhbiqpga', 공개 IP 144.24.85.118(reserved),
#   사설 IP 10.0.7.78(subnet api), NSG [nsg-node-a-platform, nsg-cluster], FAULT-DOMAIN-3, 현재 이미지 …yjkoaca(v1 Ubuntu) 47 GB.
#   VNIC·사설 IP·reserved IP·NSG 소속은 교체 뒤에도 그대로다(T013 과 같은 메커니즘: UpdateInstance sourceDetails, VNIC 재생성 없음).
# 영향: 노드 A 는 Cloudflare 가 바라보는 v1 API 의 호스트다 — 재이미지 = v1 API 서비스 종료(노드 위 컨테이너·볼륨 소멸, 백업 없음).
#   사용자 수용 T009 옵션 2(2026-09-03); v1 배포는 T012 에서 이미 차단됐다. 노드 B 와 달리 이 창은 되돌릴 수 없으므로 실행 직전 사용자 재확인.
# 스토리지 창: 100(B) + 47(A 구) + 100(A 신) = 247 GB. T013 실측 available 61,346 GB 라 여유(1단계에서 다시 읽는다).
# 0. T013 0단계와 같다. 다만 $NODE_B 대신 $NODE_A, $tmp 는 t014. $PUB 는 host-prep.sh 의 NEW_PUBKEY 로도 쓴다(같은 한 줄).
# 1. $NODE_B → $NODE_A. 현재 이미지 os 가 Ubuntu 인지(v1 …yjkoaca) 확인, $OLD_BV 기록(ATTACHED 필터 조회가 정본).
# 2. 동일 — metadata 는 건드리지 않는다(API 불변).
# 3. plan 기대 = oci_core_instance.node_a update in-place 1: source_details.source_id …yjkoaca → var.ubuntu_2404_image_ocid,
#    boot_volume_size_in_gbs "47" → "100", is_preserve_boot_volume_enabled false → true, update_operation_constraint null → "ALLOW_DOWNTIME";
#    요약 "0 to add, 1 to change, 0 to destroy"; Outputs: + node_a_boot_volume_id(참고값; 이 시점엔 OLD_BV). node_b·NSG·metadata 변경이 보이면 apply 금지.
#   tofu -chdir=infra/oci plan -out=t014.tfplan
# 4. tofu -chdir=infra/oci apply t014.tfplan → $NEW_BV(ATTACHED 필터, $NODE_A) ≠ $OLD_BV 확인(T013 4단계 명령의 $NODE_B → $NODE_A).
# 5. 임시 규칙: description 'T014 temp ssh (remove me)'. NSG 는 같은 nsg-cluster(두 노드 공유 — 창 동안 노드 B 의 22 도 열린다; 창은 짧게).
#    이 창에서 노드 B host-prep 도 함께 돌린다(아래 6-④).
# 6. SSH 확인 + 로그인 키 교체 + 호스트 준비 — host-prep.sh 두 번(추가 → 새 키로 검증 → v1 제거 순서를 스크립트가 상속; DROP_V1_KEY=1 은
#    새 키 세션에서만 유효하고 스크립트가 sshd 로그 지문으로 강제한다). PowerShell 은 '<' 리다이렉션이 없고 파이프가 CRLF 를 붙이므로 scp 로 올린다:
#   ssh-keygen -R 144.24.85.118
#   ssh -o IdentitiesOnly=yes -i $V1KEY ubuntu@144.24.85.118 'cloud-init status --wait; lsb_release -ds'   → done(0) 또는 degraded done(2) / Ubuntu 24.04.x
#   ① 1회차(v1 키 세션 — 새 키 추가 + iptables·wireguard·패키지·unattended·시간대; DROP_V1_KEY 없음):
#     scp -o IdentitiesOnly=yes -i $V1KEY infra/bootstrap/host-prep.sh ubuntu@144.24.85.118:/tmp/host-prep.sh
#     ssh -o IdentitiesOnly=yes -i $V1KEY ubuntu@144.24.85.118 "sudo NEW_PUBKEY='$PUB' NODE_ROLE=platform bash /tmp/host-prep.sh"   → summary: authorized_keys 2 line(s), other keys=1
#   ② 2회차(새 키 세션 — 접속 성공 자체가 검증):
#     ssh -o IdentitiesOnly=yes -i "$HOME\.ssh\joshuatech-ops" ubuntu@144.24.85.118 "sudo NEW_PUBKEY='$PUB' NODE_ROLE=platform DROP_V1_KEY=1 bash /tmp/host-prep.sh"
#       → changes this run: 1(authorized_keys 다른 키 1 줄 제거)뿐, 나머지 unchanged/present = 멱등 증거; authorized_keys 1 line(s), other keys=0
#   ③ ssh -o IdentitiesOnly=yes -i $V1KEY ubuntu@144.24.85.118 true   → Permission denied (publickey)
#   ④ 노드 B(이미 새 키뿐; NODE_ROLE=data) — 같은 창에서 두 번 돌려 멱등을 증명한다(2회차 DROP_V1_KEY=1 은 "제거할 다른 키 없음" 이어야 한다):
#     scp -o IdentitiesOnly=yes -i "$HOME\.ssh\joshuatech-ops" infra/bootstrap/host-prep.sh ubuntu@129.154.62.250:/tmp/host-prep.sh
#     ssh -o IdentitiesOnly=yes -i "$HOME\.ssh\joshuatech-ops" ubuntu@129.154.62.250 "sudo NEW_PUBKEY='$PUB' NODE_ROLE=data bash /tmp/host-prep.sh"
#     ssh -o IdentitiesOnly=yes -i "$HOME\.ssh\joshuatech-ops" ubuntu@129.154.62.250 "sudo NEW_PUBKEY='$PUB' NODE_ROLE=data DROP_V1_KEY=1 bash /tmp/host-prep.sh"   → changes this run: 0
#   (두 노드 모두 /tmp/host-prep.sh 는 남겨도 무해 — 비밀이 없다. 원하면 rm.)
# 7. 동일($OLD_BV = 노드 A 구 볼륨, 47 GB — AVAILABLE·attachment 없음 확인 뒤 삭제).
# 8. 임시 규칙 제거는 인라인 JSON(T013 8단계와 동일 형식):
#   oci network nsg rules remove --nsg-id $NSG --security-rule-ids "[`"$RULE`"]"
#   oci network nsg rules list --nsg-id $NSG --query 'length(data)'   → 1
# 8b. outputs-only 수렴(T013 실측: 구 볼륨 삭제 뒤 provider 가 새 attachment 를 읽어 boot_volume_id output 만 바뀐다):
#   tofu -chdir=infra/oci plan -detailed-exitcode   → exit 2 이되 "Plan: 0 to add, 0 to change, 0 to destroy" + "Changes to Outputs: ~ node_a_boot_volume_id" 만이어야 한다
#   tofu -chdir=infra/oci apply   (outputs-only; 리소스 변경이 하나라도 보이면 STOP — T013 8단계의 DETACHED 구 attachment 경로 점검)
#   tofu -chdir=infra/oci plan -detailed-exitcode   → exit 0 "No changes"
# 9. 동일 + pwsh -NoProfile -File tests/infra/host-prep.tests.ps1(정적) — 실행 결과(summary 두 노드 × 2회)는 docs/runbooks/bootstrap.md §2 T014 에 기록한다.

resource "oci_core_instance" "node_a" {
  availability_domain = "TxjY:AP-CHUNCHEON-1-AD-1"
  compartment_id      = var.compartment_ocid
  defined_tags        = {}
  display_name        = "joshtech_api_1st"
  extended_metadata   = {}
  fault_domain        = "FAULT-DOMAIN-3"
  freeform_tags       = {}
  metadata = {
    # T014: OCI API 상 불변(launch 뒤 갱신·삭제·추가 거부; provider 는 변경을 replace 로 취급) — 이 v1 리터럴이 곧 실제 값이다.
    # 실제 로그인 키 교체는 호스트 authorized_keys 에서 한다(머리 주석 T014 6단계 = infra/bootstrap/host-prep.sh). 여기서는 절대 바꾸지 않는다.
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLOZ71CEhQCsJoElCcU25q+/FOBwvFv/yfYKX/4osSFNHHGRGhTpF8VrcCruQKg2zPtV6krMP9THdF4B4c+Z4Rl30MQec8xHK973SBby7SQ1EjVTfrp23d396ng8JEVo0sQXHPi8gjkTpdFQ+7jcUyIM6r3vGK93gXcz4TEqUCmKiJF7DID5Kex9V3HQvXr304yU/QKfWnvkORWfHidVihM4aDSKBqzJIHAs7gjlZCqzVSURczRFD1vqNh8Ry3ndDSqEUgc4xzkszlEJfQ71Gmxmq4ORysgGce6Z2GRTuCQ8y6X5ao8qOjlgIMfDd78sduIHlf6hiS8cqOFYjIcpoOOxPBceljoSrftyuuMs+ld5VKMqKyZFkxwi+90dxvqadLutPZ0dBGZJE+EqTkqLW2qdQ+HnkMiYG5jRXHULP8zfAygjNc0YFuRT20UHr25A7CiNFcSjukDqAsNraW7fNXSX3Fv81LwFB79qFLn42OqjX5bpmPeTPckv1xp2gbz+tNVAIThynWcd48M0KtDmYhIF/E7EvQWthBSqJUPhZ0X9x9p27rRTGILAi1gZJYFjU1EPiSFV9kp0IIg6eJhpkgO17akYTVsf4yzkquLnoN+IZY5zAMhbd+MVXp+hrnhZlZkYiMEaDT0rfS7Q0JmJRktkO2UmoDefygqUdd2JNIEw== wlsgh@Home-2024"
  }
  security_attributes = {}
  shape               = "VM.Standard.A1.Flex"
  state               = "RUNNING"
  # T014: 재이미지(source_details.source_id 교체)는 재부팅을 수반한다. SDK/API 기본값도 ALLOW_DOWNTIME 이지만 의도 고정용으로 명시한다(AVOID_DOWNTIME 이면 거부).
  update_operation_constraint = "ALLOW_DOWNTIME"

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    is_live_migration_preferred = false
    recovery_action             = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = false
    assign_public_ip          = "true"
    defined_tags              = {}
    display_name              = "joshtech_api_1st"
    freeform_tags             = {}
    hostname_label            = "joshtech-api"
    # T009: 공개 경계(nsg-node-a-platform: Cloudflare→443) + 클러스터 내부(nsg-cluster).
    nsg_ids                = [oci_core_network_security_group.node_a_platform.id, oci_core_network_security_group.cluster.id]
    private_ip             = "10.0.7.78"
    private_ip_id          = ""
    security_attributes    = {}
    skip_source_dest_check = false
    subnet_cidr            = ""
    subnet_id              = oci_core_subnet.api.id
    vlan_id                = ""
  }

  # T010: IMDS v1(/opc/v1) 비활성 — .claude/rules/infra.md "IMDS v1 stays disabled". 노드 위 도구는 v2(/opc/v2 + Authorization: Bearer Oracle)만 쓴다.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  shape_config {
    baseline_ocpu_utilization = "BASELINE_1_1"
    local_volume_size_in_gbs  = 0
    memory_in_gbs             = 13
    nvmes                     = 0
    ocpus                     = 2
    resource_management       = ""
    vcpus                     = 2
  }

  # T014: 이미지 교체(in-place UPDATE — 머리 주석 "스키마 근거"; 노드 B T013 과 같은 변수). 이전 이미지 ocid1.image.oc1.ap-chuncheon-1.aaaaaaaamwkrl3fycvbnrt6d3cztl22se3j3z5x22yxhfvedu3za2yjkoaca (v1, 47 GB).
  source_details {
    boot_volume_size_in_gbs = var.node_boot_volume_size_gb
    # boot_volume_vpus_per_gb 는 provider 8.29.0 에서 ForceNew 다 — 절대 바꾸지 않는다(바꾸면 replace → prevent_destroy 가 막는다).
    boot_volume_vpus_per_gb = "10"
    # 교체 성공 뒤 이전 부트 볼륨을 보존(detached) — 운영자가 검사·수동 삭제한다(머리 주석 7단계). terminate 시 옵션인 최상위 preserve_boot_volume 과는 다르다.
    is_preserve_boot_volume_enabled = true
    kms_key_id                      = ""
    source_id                       = var.ubuntu_2404_image_ocid
    source_type                     = "image"
  }

  lifecycle {
    prevent_destroy = true
    # assign_public_ip — 영구 가드(T010에서 문구 정정; T009의 "교체 창 임시 차단"이 아니다). 공개 IP의 소유자는
    # oci_core_public_ip(reserved, network.tf)다. provider 문서상 이 필드는 (Updatable)이며, 값이 바뀌면 provider가 VNIC의
    # 공개 IP를 직접 생성·삭제한다 — reserved IP가 붙어 있어도 예외가 아니라서 여기서 false로 읽히거나 바뀌면 그 reserved IP까지
    # 건드린다(주소 유실 경로). 따라서 컷오버가 끝나도 이 ignore는 유지한다: 이 리소스가 공개 IP를 절대 관리하지 않게 하는 상시 조치다.
    ignore_changes = [metadata, defined_tags, create_vnic_details[0].hostname_label, create_vnic_details[0].assign_public_ip]
  }
}

resource "oci_core_instance" "node_b" {
  availability_domain = "TxjY:AP-CHUNCHEON-1-AD-1"
  compartment_id      = var.compartment_ocid
  defined_tags        = {}
  display_name        = "joshtech_cache"
  extended_metadata   = {}
  fault_domain        = "FAULT-DOMAIN-1"
  freeform_tags       = {}
  metadata = {
    # T013: OCI API 상 불변(launch 뒤 갱신·삭제·추가 거부; provider 는 변경을 replace 로 취급) — 이 v1 리터럴이 곧 실제 값이다.
    # 실제 로그인 키 교체는 호스트 authorized_keys 에서 한다(머리 주석 6단계 / T014 host-prep.sh). 여기서는 절대 바꾸지 않는다.
    ssh_authorized_keys = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDLOZ71CEhQCsJoElCcU25q+/FOBwvFv/yfYKX/4osSFNHHGRGhTpF8VrcCruQKg2zPtV6krMP9THdF4B4c+Z4Rl30MQec8xHK973SBby7SQ1EjVTfrp23d396ng8JEVo0sQXHPi8gjkTpdFQ+7jcUyIM6r3vGK93gXcz4TEqUCmKiJF7DID5Kex9V3HQvXr304yU/QKfWnvkORWfHidVihM4aDSKBqzJIHAs7gjlZCqzVSURczRFD1vqNh8Ry3ndDSqEUgc4xzkszlEJfQ71Gmxmq4ORysgGce6Z2GRTuCQ8y6X5ao8qOjlgIMfDd78sduIHlf6hiS8cqOFYjIcpoOOxPBceljoSrftyuuMs+ld5VKMqKyZFkxwi+90dxvqadLutPZ0dBGZJE+EqTkqLW2qdQ+HnkMiYG5jRXHULP8zfAygjNc0YFuRT20UHr25A7CiNFcSjukDqAsNraW7fNXSX3Fv81LwFB79qFLn42OqjX5bpmPeTPckv1xp2gbz+tNVAIThynWcd48M0KtDmYhIF/E7EvQWthBSqJUPhZ0X9x9p27rRTGILAi1gZJYFjU1EPiSFV9kp0IIg6eJhpkgO17akYTVsf4yzkquLnoN+IZY5zAMhbd+MVXp+hrnhZlZkYiMEaDT0rfS7Q0JmJRktkO2UmoDefygqUdd2JNIEw== wlsgh@Home-2024"
  }
  security_attributes = {}
  shape               = "VM.Standard.A1.Flex"
  state               = "RUNNING"
  # T013: 재이미지(source_details.source_id 교체)는 재부팅을 수반한다. SDK/API 기본값도 ALLOW_DOWNTIME 이지만 의도 고정용으로 명시한다(AVOID_DOWNTIME 이면 거부).
  update_operation_constraint = "ALLOW_DOWNTIME"

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    is_live_migration_preferred = false
    recovery_action             = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = false
    assign_public_ip          = "true"
    defined_tags              = {}
    display_name              = "joshtech_cache"
    freeform_tags             = {}
    hostname_label            = "joshtech-cache"
    # T009: 클러스터 내부(nsg-cluster)만 — 노드 B는 공개 ingress가 전혀 없다.
    nsg_ids                = [oci_core_network_security_group.cluster.id]
    private_ip             = "10.0.10.193"
    private_ip_id          = ""
    security_attributes    = {}
    skip_source_dest_check = false
    subnet_cidr            = ""
    subnet_id              = oci_core_subnet.cache.id
    vlan_id                = ""
  }

  # T010: IMDS v1(/opc/v1) 비활성 — .claude/rules/infra.md "IMDS v1 stays disabled". 노드 위 도구는 v2(/opc/v2 + Authorization: Bearer Oracle)만 쓴다.
  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  shape_config {
    baseline_ocpu_utilization = "BASELINE_1_1"
    local_volume_size_in_gbs  = 0
    memory_in_gbs             = 13
    nvmes                     = 0
    ocpus                     = 2
    resource_management       = ""
    vcpus                     = 2
  }

  # T013: 이미지 교체(in-place UPDATE — 머리 주석 "스키마 근거"). 이전 이미지 ocid1.image.oc1.ap-chuncheon-1.aaaaaaaaxuyyow2meckrqx27dj3nphly7dwq5pu7sr3id5uqzuy3wdk3khya (47 GB).
  source_details {
    boot_volume_size_in_gbs = var.node_boot_volume_size_gb
    # boot_volume_vpus_per_gb 는 provider 8.29.0 에서 ForceNew 다 — 절대 바꾸지 않는다(바꾸면 replace → prevent_destroy 가 막는다).
    boot_volume_vpus_per_gb = "10"
    # 교체 성공 뒤 이전 부트 볼륨을 보존(detached) — 운영자가 검사·수동 삭제한다(머리 주석 7단계). terminate 시 옵션인 최상위 preserve_boot_volume 과는 다르다.
    is_preserve_boot_volume_enabled = true
    kms_key_id                      = ""
    source_id                       = var.ubuntu_2404_image_ocid
    source_type                     = "image"
  }

  lifecycle {
    prevent_destroy = true
    # assign_public_ip — 영구 가드(T010에서 문구 정정; T009의 "교체 창 임시 차단"이 아니다). 공개 IP의 소유자는
    # oci_core_public_ip(reserved, network.tf)다. provider 문서상 이 필드는 (Updatable)이며, 값이 바뀌면 provider가 VNIC의
    # 공개 IP를 직접 생성·삭제한다 — reserved IP가 붙어 있어도 예외가 아니라서 여기서 false로 읽히거나 바뀌면 그 reserved IP까지
    # 건드린다(주소 유실 경로). 따라서 컷오버가 끝나도 이 ignore는 유지한다: 이 리소스가 공개 IP를 절대 관리하지 않게 하는 상시 조치다.
    # metadata — T008 가드 그대로 유지. OCI API 상 user_data·ssh_authorized_keys 는 불변이라(위 metadata 블록 주석) 리터럴이 곧 실제 값이고
    # ignore 를 풀어도 diff 0 이어야 하지만, 풀어서 얻는 것이 없고 오타 한 글자가 replace 요구(prevent_destroy 차단)로 이어지므로 풀지 않는다.
    ignore_changes = [metadata, defined_tags, create_vnic_details[0].hostname_label, create_vnic_details[0].assign_public_ip]
  }
}

# T013/T014 참고값: provider getBootVolume 이 boot volume attachment 목록의 Items[0] 을 상태 필터 없이 취하므로 교체 직후에는 DETACHED 구 볼륨이
# 올 수 있다. 정본은 머리 주석 1·4단계의 ATTACHED 필터 CLI 조회다. 구 볼륨 삭제 뒤 이 값만 바뀌는 plan 은 outputs-only apply 로 수렴한다(8b단계).
output "node_a_boot_volume_id" {
  description = "노드 A(joshtech_api_1st) 부트 볼륨 OCID — 참고값(state 기준; 정본은 ATTACHED 필터 CLI 조회)"
  value       = oci_core_instance.node_a.boot_volume_id
}

output "node_b_boot_volume_id" {
  description = "노드 B(joshtech_cache) 부트 볼륨 OCID — 참고값(state 기준; 정본은 ATTACHED 필터 CLI 조회)"
  value       = oci_core_instance.node_b.boot_volume_id
}
