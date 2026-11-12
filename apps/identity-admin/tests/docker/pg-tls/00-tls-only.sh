#!/bin/sh
# 시험 전용(T060): 원격(TCP) 접속은 TLS만 받는다 — 평문은 pg_hba에서 거부한다.
# 공식 entrypoint는 이 스크립트보다 먼저(pg_setup_hba_conf) pg_hba.conf 끝에 `host all all all scram-sha-256`을
# 붙인다. 그 줄을 hostssl(scram-sha-256) + hostnossl(reject) 두 줄로 바꾸고 결과를 grep으로 확인한다.
# 확인이 어긋나면 exit 1 — 초기화가 멈추고 컨테이너가 준비되지 않는다(fail closed).
hba="$PGDATA/pg_hba.conf"
sed -i 's/^host all all all scram-sha-256$/hostssl all all all scram-sha-256\nhostnossl all all all reject/' "$hba" || exit 1
if ! grep -qx 'hostssl all all all scram-sha-256' "$hba" || ! grep -qx 'hostnossl all all all reject' "$hba"; then
    echo "00-tls-only: TLS 전용 pg_hba 줄을 찾지 못했다" >&2
    exit 1
fi
if grep -qx 'host all all all scram-sha-256' "$hba"; then
    echo "00-tls-only: 평문 허용 줄(host all all all scram-sha-256)이 남아 있다" >&2
    exit 1
fi
echo "00-tls-only: pg_hba 원격 접속 = hostssl(scram-sha-256) + hostnossl(reject)"
