# backup-verify 픽스처

`tests/scripts/backup-verify.tests.ps1`(T048)이 쓰는 커밋된 픽스처는 `vault-mock.snap` 하나다. 나머지 픽스처(age 키쌍 · SQLite · K3s 번들 · 암호문)는 하네스가 실행할 때마다 임시 디렉터리에 새로 만들고 끝에 지운다.

## vault-mock.snap

| 항목 | 값 |
|---|---|
| 크기 | 14,699바이트 |
| SHA-256 | `0c38a97b665b034a13ef85880d1455084ddda0db1f819d79906006cb3d0b3c7a` |
| 만든 날 | 2026-10-01 (T048 컨트롤러) |
| 만든 방법 | 이 PC에서 띄운 일회용 단일 노드 Vault(Raft 스토리지 · 노드 ID `n1` · `127.0.0.1:18201`)를 초기화한 뒤 `vault operator raft snapshot save`로 저장 |
| `vault operator raft snapshot inspect`(CLI 2.1.0) | exit 0 · `ID bolt-snapshot` · `Size 14828` · `Index 45` · `Term 3` · `Version 1` · 키 행 23개 · `Total Size 14.4KB` |

**비밀이 없는 이유**

- 운영 Vault와 무관한 일회용 인스턴스다. 운영 데이터 · 운영 키는 한 번도 들어가지 않았다.
- 스냅샷 안의 저장 항목은 그 인스턴스의 barrier 키로 암호화돼 있고, 그 인스턴스의 unseal 키 · root 토큰은 만든 직후 폐기됐다. 이 파일로는 아무것도 복호화할 수 없다.
- 평문으로 보이는 것은 스냅샷 메타데이터(`meta.json` — 인덱스 · 텀 · 로컬 주소)와 키 이름(`core/…` · `sys/…` · 그 인스턴스의 `logical/<uuid>` 마운트 식별자)뿐이다.

**쓰임**: 하네스가 실행마다 만드는 일회용 age 키로 이 파일을 암호화해 `scripts/backup-verify.ps1`의 Vault 경로(`age -d` → `vault operator raft snapshot inspect`)를 진짜 도구로 시험한다. 잘린 스냅샷 · 쓰레기 파일 경우도 이 파일에서 하네스가 만든다.

**바꿀 때**: 다른 견본으로 바꾸면 하네스의 기대값(키 행 수 · `Index` · `Term` · `Total Size`)과 이 표를 함께 고친다. 운영 Vault의 스냅샷은 절대 넣지 않는다.
