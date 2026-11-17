---
status: accepted
date: 2026-09-02
decision-makers:
  - joshua92y
  - Claude (analysis)
---
# ADR 0003: 런타임 트랙 — 웹 Workers + API OCI K3s 2노드 + Argo CD

<!-- 근거: spec D3·D12·D17·§1(토폴로지)·§7(리스크 표)·§8 ADR 표, plan Complexity Tracking 1행·A14(RAM 재계산), research R1(K3S-D1~D3)·R2·R10(OBSERVABILITY-D1~D4)·R14(OCI-OPS-D9·D10) -->

## Context and Problem Statement

웹과 API를 어디서 실행할지 정해야 한다. 제약: 1인 운영(패치·장애 대응 부담), 비용(OCI PAYG — 구 무료 한도면 월 ≈ $1–2, 새 한도 적용 시 ≈ $30 리스크, Budgets 35 SGD), 커머스 SaaS 청사진(pod별 DB 독점·outbox → Kafka·Authentik·OpenFGA — Django 상주 프로세스가 전제), 그리고 K8s·GitOps 운영 경험 자체가 프로젝트 목표(이력서 가치)라는 점. 헌법 단순성 원칙과 충돌하므로 plan Complexity Tracking에 정당화를 기록했다.

## Considered Options

- **웹 = Cloudflare Workers(정적 자산 + BFF) / API = OCI K3s 2노드 + Argo CD (채택)** — 웹 트래픽은 무료 에지로, 상주 스택은 클러스터로 분리
- Cloudflare-native(전부 Workers·D1·Queues) — 운영 부담 최소지만 Django·CNPG·Kafka 청사진이 성립하지 않고 K8s 학습 가치가 없음
- compose-pull(docker compose + pull 에이전트) — RAM은 적지만 drift 복원·네임스페이스 격리·quota가 없어 SP-3 이후 pod 8개에서 수동 운영이 됨(사용자가 기각)
- 전부 K3s(웹도 클러스터에서 서빙) — 웹 정적 트래픽이 노드 RAM·대역을 소모하고 Cloudflare 무료 에지·에지 캐시를 포기

## Decision Outcome

웹은 Cloudflare Workers(정적 자산 무료 + BFF Route Handler — 상세는 ADR 0004), API는 OCI A1 인스턴스 2대(각 2 OCPU/13 GB, PAYG) 위 K3s에 두고 Argo CD가 pull CD(ADR 0002 원칙 3)를 수행한다.

- **노드 배치**: 노드 A `role=platform`(K3s server·Traefik·Argo CD·Vault+ESO·Kafka·Authentik·OpenFGA·Alloy·앱 pod 선호) ≈ 8.6 GiB / **예산 9 GiB**. 노드 B `role=data`(K3s agent·CNPG·Dragonfly·cert-manager·CNPG 오퍼레이터) ≈ 3.6 GiB / **예산 8 GiB** — SP-3 Elasticsearch·Kibana 자리(≈ 3 GiB)는 전부 노드 B에 남긴다. Kafka는 A 고정(Postgres fsync/WAL과 디스크 I/O 분리).
- **인그레스(D12)**: 번들 Traefik 공개 443 + cert-manager DNS-01 와일드카드 + Cloudflare proxied Full(strict), NSG로 Cloudflare IP 한정(80 미개방) + Authenticated Origin Pulls.
- **전환 트리거**: ① RAM — US7(운영·비용 시나리오) 실측이 예산 초과 또는 OOMKill이면 Argo core 전환 → Alloy 축소 → dev quota 축소 순으로 완화하고, 그래도 부족하면 Redpanda 검토(ADR 0008 트리거). ② 비용 — 월 Compute > 3 SGD면 예산 알림·13 → 12 GB 축소·유료 자원 생성 금지; 첫 청구서가 $30 수준(새 무료 한도 적용 확인)이면 D17(인스턴스 사양)을 재결정한다.

### Consequences

- 좋음: 웹 트래픽이 클러스터 자원과 완전히 분리되고 정적 자산은 무료·무제한. 선언적 상태·drift 복원·네임스페이스 격리(dev+prod 상시)로 pod가 8개로 늘어도 운영 절차가 같다. K8s·GitOps·Vault 운영 이력이 남는다.
- 나쁨: 2노드 26 GB(≈ 24.2 GiB) 안에서 플랫폼 스택이 RAM 대부분을 차지해 여유가 ≈ 0.4 GiB(노드 A)뿐이고, K3s·Argo·Traefik·cert-manager의 업그레이드가 전부 1인 몫이다(Renovate·system-upgrade-controller·런북으로 완화).
- 위험 수용: PAYG 무료 한도의 실제 적용(구 3,000/18,000 vs 새 1,500/9,000)은 문서로 확정 불가 — 첫 청구서로 확정하고 Budgets 35 SGD + 알림 규칙 4개로 감시한다.

### 부록: D14 관측 (Grafana Cloud·Alloy·Sentry)

spec §8 ADR 표에 따라 D14를 이 ADR 부록에 귀속한다. 관측은 **Grafana Cloud Free + Alloy**(k8s-monitoring v4 차트, `monitoring` ns, collectors 2개 — metrics StatefulSet·logs DaemonSet, 10k active series 한도는 기본 allowlist + cadvisor exclude + 60 s 간격으로 관리)와 **Sentry SaaS Free**(Django·web 클라이언트, PII 마스킹)로 구성한다. 트레이스는 OTLP(샘플링 prod 0.1), `traceparent`·`x-request-id` 전파, 대시보드 3·알림 규칙 13(`runbook_url`). 기각: 자체 ES 로그(노드 RAM ≈ 3 GiB를 SP-3 검색에 양보), GlitchTip(자체 운영 부담). 근거: 관측 백엔드를 클러스터 밖에 둬야 클러스터 장애 때도 신호가 남는다.
