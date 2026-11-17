"""django_common.kafka — Kafka 클라이언트 설정 검증(T069 · D6 · r2 J8 · r3 K8 · T071 /health 공용).

계약: contracts/events.md §outbox 릴레이 「구현 규칙」 설정 · contracts/pod-template.md 「Kafka」 행 · 규칙
.claude/rules/django-pod.md §Outbox and events. 설계 정본: specs/003-platform-foundation/design/build-notes.md 「## T069」
D6 · 「T069 r1 결과 · r2 결정」 J8 · 「T069 r2 결과 · r3 결정」 K8.

client_config()는 호출 시점에 Django 설정 두 개를 읽어 confluent-kafka(librdkafka) 설정 dict를 돌려준다:
- KAFKA_BOOTSTRAP_SERVERS: 비지 않은 str(운영 env KAFKA_BOOTSTRAP — 옮기는 것은 템플릿 settings · T072).
- KAFKA_CLIENT_CONFIG: str 키 Mapping(confluent 설정 키). 금지 키(FORBIDDEN_KEYS): `bootstrap.servers`와 그 별칭
  `metadata.broker.list`(주소는 위 설정이 정한다) · `transactional.id`(transactionalId ACL이 없다) · `delivery.report.only.error`
  (성공 DR이 오지 않아 모든 행이 재발송된다) · `partitioner`(키 무시 — 같은 테넌트 = 같은 파티션을 깬다) ·
  `enable.gapless.guarantee`(치명 오류 경로를 늘린다) · `default.topic.config`(confluent가 그 안의 키를 최상위 값보다 우선해
  합친다 — 이 모듈의 모든 검사를 덮는다 · 실측). librdkafka는 `topic.<속성>`을 토픽 속성 `<속성>`으로 읽으므로(실측 —
  `topic.partitioner`) 키 이름은 `topic.` 접두를 뗀 속성 이름(property_name)으로 비교한다.
- NUL(U+0000): 키나 str 값(KAFKA_BOOTSTRAP_SERVERS 포함)에 있으면 거부한다(K8). confluent는 키와 값을 C 문자열로 넘겨 NUL에서
  자르므로, `partitioner` + NUL 같은 키 · `none` + NUL 같은 값이 잘린 뒤에는 금지 키 · 거부 값이 되어 이 모듈의 비교를 비켜 간다
  (리뷰 r2 B2-1 실측). 메시지는 키 이름까지만 싣고, 키 자체에 NUL이 있으면 「키」라고만 쓴다.
- `security.protocol`은 필수이고 SASL_SSL · PLAINTEXT만 받는다(대소문자 무시 — PLAINTEXT를 기본값으로 두지 않는다: 명시한
  시험 · 로컬 compose만). SASL_SSL이면 `sasl.mechanism`(또는 복수형 `sasl.mechanisms` — librdkafka의 같은 속성) =
  SCRAM-SHA-512(librdkafka는 글자 그대로 비교한다 · 빠지면 경고만 내고 GSSAPI로 만든다) · `sasl.username` · `sasl.password` ·
  `ssl.ca.location`(마운트한 cluster CA — 기본 저장소는 Strimzi CA를 모른다)이 비지 않은 str이어야 한다.
- SASL_SSL에서 인증서 검증 · 호스트 이름 검사의 두 키는 양성 목록이다(K8 — fail-closed): `enable.ssl.certificate.verification`은
  없거나 True · 정수 1(bool 아님) · str "true" · "t"(대소문자 무시) · "1"(librdkafka가 참으로 읽는 꼴 그대로 — confluent는 값을
  str()로 넘긴다), `ssl.endpoint.identification.algorithm`은 없거나 str "https"(대소문자 무시)일 때만 받는다. 그 밖은 전부
  거부한다. r2의 「librdkafka가 거짓으로 읽는 꼴 · none만 거부」는 정확 일치라 앞 공백(librdkafka는 enum 값의 왼쪽 공백을 뗀다) ·
  NUL 접미로 비켜 갔다(B2-1) — librdkafka의 공백 제거 · 대소문자 해석을 흉내 내지 않으므로 공백이 붙은 안전한 값(" https")도
  거부된다. PLAINTEXT에는 TLS가 없으므로 두 키를 보지 않는다.
- 결과 = {"bootstrap.servers": KAFKA_BOOTSTRAP_SERVERS, **KAFKA_CLIENT_CONFIG}(새 dict).

어기면 ImproperlyConfigured — 메시지에는 설정 · 키 이름만 싣고 값은 싣지 않는다(`sasl.password`). 이 모듈은 설정 dict를 로그 ·
예외 · repr에 싣지 않는다. 프로듀서 고정값(enable.idempotence · delivery.timeout.ms)은 django_common.outbox.relay가 더한다
(같은 property_name 비교). confluent_kafka를 import하지 않는다(검증만 한다).
"""

from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured

__all__ = ["client_config"]  # 공개 API(계약 pod-template) — property_name · FORBIDDEN_KEYS는 relay가 같이 쓴다

_BOOTSTRAP_SETTING = "KAFKA_BOOTSTRAP_SERVERS"
_CONFIG_SETTING = "KAFKA_CLIENT_CONFIG"
FORBIDDEN_KEYS = (
    "bootstrap.servers",
    "metadata.broker.list",
    "transactional.id",
    "delivery.report.only.error",
    "partitioner",
    "enable.gapless.guarantee",
    "default.topic.config",
)
_TOPIC_PREFIX = "topic."
_PROTOCOLS = frozenset({"SASL_SSL", "PLAINTEXT"})
_MECHANISM_KEYS = ("sasl.mechanism", "sasl.mechanisms")
_MECHANISM = "SCRAM-SHA-512"
_SASL_REQUIRED = ("sasl.username", "sasl.password", "ssl.ca.location")
_VERIFICATION_KEY = "enable.ssl.certificate.verification"
_TRUE_WORDS = frozenset({"true", "t", "1"})  # librdkafka 불 값 해석의 참 꼴(str — 대소문자 무시)
_ALGORITHM_KEY = "ssl.endpoint.identification.algorithm"
_NUL = chr(0)


def property_name(key: str) -> str:
    """설정 키 → librdkafka 속성 이름(`topic.` 접두를 뗀다 — librdkafka는 `topic.<속성>`을 토픽 속성으로 읽는다)."""
    return key.removeprefix(_TOPIC_PREFIX)


def _non_empty_str(value: object) -> bool:
    return isinstance(value, str) and value != ""


def _verification_on(value: object) -> bool:
    """enable.ssl.certificate.verification의 양성 목록 — True · 정수 1(bool 아님) · str "true" · "t"(대소문자 무시) · "1"."""
    if value is True or (type(value) is int and value == 1):
        return True
    return isinstance(value, str) and value.lower() in _TRUE_WORDS


def _https(value: object) -> bool:
    """ssl.endpoint.identification.algorithm의 양성 목록 — str "https"(대소문자 무시)."""
    return isinstance(value, str) and value.lower() == "https"


def client_config() -> dict[str, Any]:
    """설정 KAFKA_BOOTSTRAP_SERVERS · KAFKA_CLIENT_CONFIG를 검증한 confluent-kafka 설정 dict(규칙은 모듈 독스트링)."""
    bootstrap = getattr(settings, _BOOTSTRAP_SETTING, None)
    if not _non_empty_str(bootstrap):
        raise ImproperlyConfigured(f"{_BOOTSTRAP_SETTING}는 비지 않은 str이어야 한다")
    if _NUL in bootstrap:
        raise ImproperlyConfigured(f"{_BOOTSTRAP_SETTING}에 NUL(U+0000)을 둘 수 없다")
    extra = getattr(settings, _CONFIG_SETTING, None)
    if not isinstance(extra, Mapping) or not all(isinstance(key, str) for key in extra):
        raise ImproperlyConfigured(f"{_CONFIG_SETTING}는 str 키 Mapping(confluent-kafka 설정 키)이어야 한다")
    for key, value in extra.items():
        if _NUL in key:
            raise ImproperlyConfigured(f"{_CONFIG_SETTING}의 키에 NUL(U+0000)을 둘 수 없다")
        if isinstance(value, str) and _NUL in value:
            raise ImproperlyConfigured(f"{_CONFIG_SETTING}의 {key} 값에 NUL(U+0000)을 둘 수 없다")
    for key in extra:
        if property_name(key) in FORBIDDEN_KEYS:
            raise ImproperlyConfigured(f"{_CONFIG_SETTING}에 {key} 키를 둘 수 없다")
    protocol = extra.get("security.protocol")
    if not isinstance(protocol, str) or protocol.upper() not in _PROTOCOLS:
        raise ImproperlyConfigured(
            f"{_CONFIG_SETTING}의 security.protocol은 필수이고 SASL_SSL 또는 PLAINTEXT(명시할 때만)여야 한다"
        )
    if protocol.upper() == "SASL_SSL":
        mechanisms = [extra[key] for key in _MECHANISM_KEYS if key in extra]
        if not mechanisms or any(mechanism != _MECHANISM for mechanism in mechanisms):
            raise ImproperlyConfigured(
                f"{_CONFIG_SETTING}: SASL_SSL이면 sasl.mechanism(또는 sasl.mechanisms)은 {_MECHANISM}이어야 한다"
            )
        for key in _SASL_REQUIRED:
            if not _non_empty_str(extra.get(key)):
                raise ImproperlyConfigured(f"{_CONFIG_SETTING}: SASL_SSL이면 {key}가 비지 않은 str이어야 한다")
        if _VERIFICATION_KEY in extra and not _verification_on(extra[_VERIFICATION_KEY]):
            raise ImproperlyConfigured(
                f'{_CONFIG_SETTING}: SASL_SSL에서 {_VERIFICATION_KEY}는 없거나 True · 1 · "true" · "t" · "1"이어야 한다'
            )
        if _ALGORITHM_KEY in extra and not _https(extra[_ALGORITHM_KEY]):
            raise ImproperlyConfigured(f'{_CONFIG_SETTING}: SASL_SSL에서 {_ALGORITHM_KEY}는 없거나 "https"여야 한다')
    return {"bootstrap.servers": bootstrap, **extra}
