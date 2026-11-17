# 시험 · 로컬 전용 PostgreSQL 18.6 + TLS 이미지(T072 D16 — django-common tests/docker/pg-tls와 같은 이미지). tests/conftest.py의
# `pg` 픽스처가 testcontainers로 세션마다 빌드하고(빌드 캐시) 세션이 끝나도 지우지 않는다 — 이미지 ID force 삭제가 같은 이미지를
# 쓰는 동시 세션을 깨뜨리므로(T072 ② r2 H11) 다음 빌드가 같은 태그를 덮는다. 레지스트리에 올리지 않는다(로컬 compose도 이 이미지).
# 원격(TCP) 접속은 TLS만 받는다(00-tls-only.sh — hostssl + hostnossl reject) · 시험 · 로컬 sslmode는 require다.
# 인증서·키는 빌드 때 만드는 1회용 자체 서명이다(비밀이 아니다 · 이 시험 컨테이너 밖에서 쓰지 않는다).
# 위치는 VOLUME(/var/lib/postgresql) 밖이어야 한다: docker-py가 쓰는 classic 빌더는 VOLUME 경로에 RUN이 쓴
# 파일을 버린다(T060 실측 — PG 18 이미지는 VOLUME이 /var/lib/postgresql · PGDATA가 그 아래 18/docker).
FROM postgres:18.6-alpine@sha256:10a5c69a83035ab5239f5620d708520e8b28f5aa1f2b20143e6024532edadfb5
COPY 00-tls-only.sh /docker-entrypoint-initdb.d/00-tls-only.sh
RUN apk add --no-cache openssl \
    && mkdir -p /etc/postgresql-tls \
    && openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=jt-test-pg" \
        -keyout /etc/postgresql-tls/server.key -out /etc/postgresql-tls/server.crt \
    && chown postgres:postgres /etc/postgresql-tls/server.crt /etc/postgresql-tls/server.key \
    && chmod 600 /etc/postgresql-tls/server.key \
    && chmod 755 /docker-entrypoint-initdb.d/00-tls-only.sh
CMD ["postgres", "-c", "ssl=on", "-c", "ssl_cert_file=/etc/postgresql-tls/server.crt", "-c", "ssl_key_file=/etc/postgresql-tls/server.key"]
