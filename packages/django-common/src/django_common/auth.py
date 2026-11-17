"""django_common.auth — 요청 인증 미들웨어(JwtAuthMiddleware) · Cloudflare Access JWT 검증기(AccessJwtValidator) · 세션 거부
목록(Denylist) · Authentik 웹훅 HMAC 헬퍼(verify_authentik_webhook) · 인증 설정 검사(check_settings)(T070).

계약: contracts/pod-template.md §런타임 계약 「인증」 · 타임아웃 표 · §django-common 공개 API(T070 보정 2026-11-05 · r2 · r3 ·
r4) · contracts/identity-admin-api.md §인증 계층 · §호출자 식별 · §웹훅 서명 규약 · §오류 슬러그 · contracts/denylist.md §조회
규약 · 규칙 .claude/rules/django-pod.md §Auth · §Settings · §Errors · §Dragonfly. 설계 정본: specs/003-platform-foundation/
design/build-notes.md 「## T070」(사실 ①–⑨ · 계약 보정 C1–C4 · 결정 D1–D14) · 「T070 r1 결과 · r2 결정」(N1–N13) · 「T070 r2
결과 · r3 결정」(U1–U13) · 「T070 r3 결과 · r4 결정」(V1–V7) · 「T070 r4 결과 · r5 결정」(W1–W8) · 「T070 r5 결과 · r6 결정」(X1–X8).

JwtAuthMiddleware(sync 전용 · URL 해석 전에 판정 · 순서 고정 · 설정은 요청마다 django.conf.settings에서 읽는다)
⓪ request.path_info가 AUTH_EXEMPT_PATHS(라이브러리 기본 헬스 3 + /webhooks/authentik · str만 담은 tuple · list · set ·
   frozenset — 아니면 ImproperlyConfigured · 정확 일치 — 끝 슬래시 · 접두 불인정)에 있으면 아무것도 하지 않고 넘긴다: 호스트
   검사 · 요청 속성 · 키 fetch · Dragonfly 모두 없음. 웹훅 경로는 뷰가 verify_authentik_webhook으로 검증한다.
① 호스트 선행: request.get_host() — ALLOWED_HOSTS 밖이면 DisallowedHost가 그대로 올라가 요청 urlconf의 handler400이 400
   invalid_host를 만든다(자격 검사보다 먼저 · 미들웨어 순서와 무관). 이어서 요청 속성 셋(access_claims · auth_claims ·
   tenant_id)을 지운다 — 앞선 미들웨어가 둔 값이 인증을 거치지 않고 뷰 · TenantContextMiddleware에 닿지 않게(이 속성을
   두는 미들웨어는 이 미들웨어 뒤에 둔다).
② AUTH_ACCESS_ONLY_PATHS(기본 빈 튜플 · 같은 타입 검사 · 정확 일치)면 ③만 거쳐 request.access_claims를 두고 넘긴다(Bearer ·
   act · 거부 목록 없음 — 뷰가 조회한다). 두 목록에 다 있으면 ⓪이 먼저다.
③ Access(AccessJwtValidator) — 실패 403 access_required.
④ Bearer — 실패 401 invalid_token. ⑤ AUTH_ACTOR_SUB가 비어 있지 않을 때만 act.sub — 실패 401 invalid_token(④와 같은 단계).
⑥ 거부 목록(Denylist) — 폐기 401 session_revoked · 조회 실패 503 denylist_unavailable(fail-closed).
⑦ 성공: request.access_claims(Access 클레임) · request.auth_claims(검증된 Bearer payload 전체) · request.tenant_id(tenant_id
   클레임이 있을 때만 · uuid.UUID)를 두고 뷰를 부른다. 실패 응답에는 이 속성이 하나도 없다.
실패 응답은 AuthError 하위 형의 to_response()(RFC 9457 · detail · 추가 헤더 없음)다. 동시 실패는 이 순서의 앞 단계가 답한다.
설정 오류(ImproperlyConfigured — 설정 이름만 · 연쇄 없음)는 그대로 올라간다(handler500 → 500).

Access(③ · AccessJwtValidator.validate(token) -> dict)
- 헤더 Cf-Access-Jwt-Assertion. certs = 팀 기준 URL + /cdn-cgi/access/certs · iss = 팀 기준 URL. 팀 기준 URL =
  ACCESS_TEAM_DOMAIN을 분해해 다시 만든 정규형 `<scheme>://<host>[:<port>]`다(Cloudflare iss는 소문자 · 포트 없음 — 값을
  그대로 쓰면 모든 요청이 조용히 403): 스킴이 없으면 https · 스킴 · 호스트는 소문자 · 기본 포트(https 443 · http 80) · 빈
  포트 · 끝 `/`는 뗀다 · 호스트는 루프백 IP 리터럴(먼저 본다 — IPv6는 `[…]`로 다시 감싼다) 또는 LDH 이름(T070 r3 U2 — 라벨
  1–63자 `[a-z0-9-]` · 영숫자로 시작하고 끝남(하이픈은 가운데만) · 빈 라벨 · 앞 · 끝 점 없음 · 전체 253자 이하 · 마지막 라벨이
  숫자 꼴이면 안 된다(T070 r4 V1 — 10진 숫자만이거나 `0x` + 16진 숫자(빈 것 포함 — `0x` 자체도) · WHATWG URL
  ends-in-a-number와 같다): `0` · `10.0.0.1` · `127.1` · `0x7f000001` · `127.0.0.0x1` · `169.254.169.0xfe`는 이름 조회가
  inet_aton 꼴로 다른 주소(IP)를 풀 수 있다 · 마지막이 아닌 라벨은 보지 않는다 · 끝 점은 이름이 풀려도 iss가 `…com.`이 되어
  조용히 403) · 포트는 1–65535 · http://는 루프백 IP 리터럴만(시험 서버 · 이름은 조회하지 않는다). 공백 · 제어 문자 ·
  비ASCII · 밑줄 · 사용자 정보 · 경로 · 쿼리 · 조각(빈 것 포함) · 잘못된 포트는 ImproperlyConfigured.
- RS256만 · audience = {ACCESS_AUD_M2M, ACCESS_AUD_ADMIN} 가운데 비지 않은 값(dev의 빈 ACCESS_AUD_ADMIN은 뺀다 — 남기면
  PyJWT가 aud [""]를 받아들인다) · 필수 exp · iat · aud · iss · nbf는 있으면 검증 · leeway 5 s · common_name이 str이고
  ACCESS_EXPECTED_CN(서비스 토큰 Client ID)과 같아야 한다(Client ID 꼴은 보지 않는다 — 설정 값의 글자 범위는 아래 「인증
  문자열 설정」). 실패 AccessRequired.

Bearer(④ ⑤ — 공개하지 않는다)
- `Authorization: Bearer <token>` — 스킴 대소문자 무시 · 구분은 공백 하나 · 토큰에 공백 없음.
- 키는 AUTHENTIK_JWKS_URL(svc DNS)에서만(Access 키와 섞지 않는다 · discovery 없음 · iss는 문자열 비교만). RS256 ·
  audience = AUTHENTIK_AUDIENCE · issuer = AUTHENTIK_ISSUER · 필수 exp · iat · sub · aud · iss(PyJWT는 require가 없으면 exp
  없는 토큰도 받는다) · leeway 5 s.
- 클레임 모양(fail-closed): sub 비지 않은 str · sid 있으면(JSON null 포함) 비지 않은 str · tenant_id 있으면 소문자 정규형
  UUID 문자열(str(uuid.UUID(v)) == v) · AUTH_ACTOR_SUB가 비어 있지 않으면 act가 dict이고 act["sub"]가 같아야 한다(빈 값 =
  impersonation 모드 — act를 보지 않는다).

서명 키 가져오기(Access · Authentik 공통)
- PyJWKClient(url, cache_jwk_set=True, lifespan=3600, timeout=2)를 인스턴스 안에 URL별로 둔다(cooldown 30 s는 PyJWT 기본값 —
  모르는 kid는 마지막 성공 fetch 뒤 30 s가 지나야 한 번 다시 가져온다 · 새 인스턴스는 다시 가져온다).
- 키 집합 획득(캐시 · fetch · JWK Set 해석 · 서명 키 거르기)의 실패는 토큰 결함이 아니라 의존성 장애다 → 503
  auth_keys_unavailable(만료 뒤 fetch 실패 · cooldown 재조회 실패 포함 — 만료된 키를 쓰지 않는다). PyJWT는 객체가 아닌 JSON ·
  서명 키 후보 없음을 모르는 kid와 같은 PyJWKClientError로 올리므로 클래스로 가르지 않고 단계로 가른다(_KeyClient). 재조회
  뒤에도 kid가 없으면 토큰 결함(Access 403 · Bearer 401). 키 URL이 http · https가 아니면 ImproperlyConfigured.
- fetch 실패 백오프(T070 r3 U4 · _KeyClient.fetch_data): 키 URL 하나의 fetch가 실패하면(어떤 예외든) 창을 둔다 — 1 s에서
  시작해 연속 실패마다 직전 창의 2배 · 최대 30 s(_KEYS_BACKOFF_INITIAL_S · _KEYS_BACKOFF_MAX_S — 호출 때 읽는다 · 실패
  횟수로 거듭제곱하지 않는다 — 오래가는 장애에서 float 변환이 넘친다) · 창은 실패를 안 시각부터 센다(fetch 시작부터 세면 긴
  fetch 뒤 기다리던 판정이 창 밖에서 다시 가져온다) · 성공하면 초기화한다 · 시계는 time.monotonic(단조)이다. 창 안에서 fetch가
  필요한 판정(빈 캐시 · 만료 · 모르는 kid 재조회)은 네트워크 없이 503 auth_keys_unavailable(WARNING error=backoff)이고,
  캐시로 통과하는 판정은 영향이 없다. 장애 중 fetch는 키 URL마다 창 하나에 한 번이고 회복이 늦어지는 시간은 최대 창
  길이(30 s)다 — 대가: 기동 직후나 만료 시점의 일시 장애 한 번이 그 키 URL의 fetch를 1 s 동안 막는다.
- 한계(PyJWT 2.15): 키 집합 응답이 서명 키 후보 없는 키(kid 없음 · use enc)만 담고 200이면 PyJWT가 그 집합을 캐시해
  lifespan 동안 503이 이어진다(fail-closed — 복구는 lifespan 만료 또는 프로세스 재시작).
- 한계(PyJWT 2.15 · 장애 중 잠금 대기): get_signing_key는 PyJWT 2.15.1 클라이언트 RLock(`_client_lock` — jwks_client.py:277)을
  쥔 채 키 집합을 얻고(캐시 확인 · fetch) cooldown을 판정해 다시 가져온다 — 캐시 확인과 fetch_data가 모두 그 잠금 안에서
  불린다(jwks_client.py:277–291). 그래서 fetch가 도는 동안 같은 출처의 모든 판정(캐시로 통과할 아는 kid 포함)이 그 PyJWT 잠금을
  기다리고, 그 대기는 fetch 한 번의 시간이다(연결 · 읽기 소켓 동작마다 2 s · 연결은 해석된 주소마다 — 아래 시간 상한 문단).
  백오프 상태는 _KeyClient 자기 잠금 아래에서만 읽고 쓴다(PyJWT 비공개 _client_lock에 기대지 않는다 · T070 r4 V4) — 자기 잠금은
  fetch_data 안에서만 쥐므로 캐시 적중 판정은 그 잠금을 쥐지 않는다. fetch가 실패하면 백오프 창이 열려 기다리던 판정과 뒤이은
  판정이 네트워크 없이 곧바로 끝나므로, 빈 캐시 · 만료 장애에서도 대기가 요청마다 계단처럼 쌓이지 않는다 · 창 안에서는 모르는
  kid 재조회도 네트워크를 타지 않는다. Access 단계는 다른 자격보다 먼저 돌므로 엣지를 거치지 않고 pod 포트에 닿는
  클러스터 안 호출자(같은 ns · NetworkPolicy가 허용한 identity · traefik)가 자격 없이 일으킬 수 있다 — Bearer 단계는 유효한
  Access를 통과한 뒤에만 닿는다(엣지 트래픽은 Cloudflare가 Access 헤더를 덮어쓴다). fail-closed는 유지되고 우회는 없다(가용성
  문제 — T085 VD R3가 대기 시간을 잰다).
- PyJWT 결합(T070 r4 V4): PyJWT 2.15.1 호출 순서(get_signing_key → get_signing_keys → get_jwk_set → fetch_data) · 공개
  메서드 이름 둘(`get_signing_keys` · `fetch_data`) · get_signing_key의 클라이언트 잠금이 캐시 확인까지 감싸는 것(동시 빈 캐시
  판정의 fetch 중복 제거 — ac-24h가 고정한다 · 그 시험이 실패하면 build-notes T070 r5 W3의 고르지 않은 안 (a)를 다시 정한다 ·
  T070 r6 X2)에 기댄다 — PyJWT를 올리면 test_auth_contract를 돌린다.

Denylist(⑥ · 공개 — T073 /session/check가 재사용)
- lookup(sub, sid=None) -> DenylistRecord(sub_nbf: int | None, sid_revoked: bool) · DenylistRecord.revokes(iat)
  = (sub_nbf가 있고 > iat) 또는 sid_revoked. sub는 비지 않은 str · sid는 None 또는 비지 않은 str(아니면 TypeError ·
  ValueError — 호출자 오류).
- 호출마다 DRAGONFLY_URL을 읽고 URL별 클라이언트를 인스턴스 안에 둔다(같은 인스턴스가 바뀐 URL을 따른다). 클라이언트 =
  Redis.from_url(url, socket_timeout=0.2, socket_connect_timeout=0.2, retry=Retry(NoBackoff(), 0)) — 지연 생성 · 생성할 때
  연결 · PING 없음. URL에 쿼리가 있으면 조회하지 않는다(redis-py는 URL 쿼리가 키워드 인자를 덮어써 0.2 s · 재시도 0이
  무너진다).
- 파이프라인 1회(transaction=False — GET revoked:sub:{sub} + sid가 있으면 EXISTS revoked:sid:{sid}). 값이 정수가 아니거나
  (int() 실패) 어떤 예외든 DenylistUnavailable(503) — 예외 메시지(키 = sub · URL)는 응답 · 로그 · 연쇄에 싣지 않는다.
  결과를 캐시하지 않는다.
- 지표 denylist_lookup_seconds(Histogram · 레이블 result — ok: 키 없음 · revoked: 폐기 키가 있었다(sub 키 또는 sid 키 —
  거부 여부는 호출자의 revokes(iat)가 정한다) · error: 조회 실패). 조회 1회 = 관측 1회 · 모듈 수준 1회 등록.

시간 상한(키 fetch 2 s · 거부 목록 0.2 s)은 연결 · 읽기 소켓 동작마다 걸린다 — 요청 전체의 상한이 아니다. DNS 해석
(getaddrinfo)은 시간 제한 밖이고, 연결 시간 초과는 해석된 주소(A · AAAA)마다 따로 걸린다(socket.create_connection이 주소를
차례로 시도한다 — 주소 N개면 연결에만 최대 2 s × N · redis-py도 주소마다 0.2 s). Dragonfly 새 연결은 핸드셰이크 왕복(HELLO ·
AUTH · CLIENT SETINFO 등 최대 4)마다 0.2 s가 따로 걸리며, 키 fetch는 키 URL마다 직렬화된다(PyJWT 2.15.1 클라이언트 잠금 ·
_KeyClient 자기 잠금 — 바이트를 조금씩 흘리는 엔드포인트도 상한을 넘길 수 있다).

로그(D12): 판정마다 남기지 않는다(요청 로그는 T071이 상태 코드로 남긴다). 의존성 장애 둘만 logger django_common.auth
WARNING 한 줄 — `auth.keys_unavailable source=<access|authentik> error=<예외 클래스 | backoff>` · `auth.denylist_unavailable
source=denylist error=<예외 클래스 | url_query>`(토큰 · URL · 키 · 예외 메시지 없음).

인증 문자열 설정(T070 r4 V2 — _required · _optional로 읽는 ACCESS_TEAM_DOMAIN · ACCESS_AUD_M2M · ACCESS_AUD_ADMIN ·
ACCESS_EXPECTED_CN · AUTHENTIK_JWKS_URL · AUTHENTIK_ISSUER · AUTHENTIK_AUDIENCE · AUTH_ACTOR_SUB · DRAGONFLY_URL)은 공백 없는
출력 가능 ASCII(`!` U+0021 – `~` U+007E)만 받는다: 공백 · 제어 문자 · 줄바꿈 · 탭 · 비ASCII(NBSP 같은 Unicode 공백 · 폭 0 ·
BOM · 보이지 않는 채움 문자 · 동형 글자)가 하나라도 있으면 ImproperlyConfigured(설정 이름만 · 값 없음)다. YAML 블록 스칼라
`|`의 끝 줄바꿈이나 복사해 붙인 보이지 않는 글자가 비교(iss · aud · common_name · act.sub)를 늘 어긋나게 해 모든 판정을 조용한
403 · 401로 만들지 않게 한다. str.isprintable()로는 모자란다(한글 채움 문자 U+3164 · 점자 빈칸 U+2800은 보이지 않지만 출력
가능으로 분류된다). 빈 값 규칙은 그대로다(_required는 빈 값 거부 · _optional은 빈 값 유효). 경로 목록 설정(_paths)은 범위
밖이다(값이 settings 코드에 있고 path_info는 공백을 담을 수 있다).

설정 검사(check_settings() · 공개 · T070 r3 U3): 요청 때 인증 계층이 읽는 설정을 요청 경로와 같은 판정 함수로 요청 없이
검사한다(사본 규칙 없음 · 순서는 함수 독스트링). 기동 검사(T072)가 불러 요청 때 500이 되는 설정 오류를 기동 실패로
앞당긴다. 네트워크 · 이름 조회 · Dragonfly 연결 · 키 fetch가 없다.

웹훅(verify_authentik_webhook(body, signature, *, secret, now=None) -> WebhookEvent)
- 빈 secret은 ValueError(설정 오류 · 심층 방어 — pod 설정이 기동에서 먼저 막는다) · str 아닌 secret · bytes 아닌
  body(bytearray · memoryview 포함 — Django request.body는 bytes다 · T070 r3 U1)는 TypeError · naive now는 ValueError.
- 서명 꼴 `sha256=<hex 소문자 64>`(fullmatch) · 본문 UTF-8 디코드 → JSON(RecursionError 포함) → 정규형(sort_keys ·
  separators (",", ":") · ensure_ascii)의 HMAC-SHA256을 hmac.compare_digest로 비교 → 본문 객체 · pk(비지 않은 str) ·
  created(str · tz 있는 ISO 8601 · `Z` 허용) · |now − created| ≤ 300 s. 하나라도 어기면 WebhookSignatureInvalid(401) —
  메시지 · 연쇄 없음. 반환 WebhookEvent(pk · created(aware) · data(본문 dict 전체)). 멱등 저장 · 업무 필드 검증은 뷰의 몫이다.

Ninja auth callable은 두지 않는다(D10 — 미들웨어가 모든 비면제 경로를 URL 해석 전에 판정하므로 중복이고, Ninja auth=는 OR
의미 · 기본 401 본문은 RFC 9457 밖이다). 뷰는 request.auth_claims · request.tenant_id를 읽는다. 사람 admin 경로(GitHub IdP
Access JWT — common_name · Bearer 없음)는 미결이다(T072 · T073 · T084).

import 시점에는 네트워크 · 스레드 · 설정 값을 건드리지 않는다(지표 denylist_lookup_seconds 등록만).
"""

from __future__ import annotations

import hashlib
import hmac
import ipaddress
import json
import logging
import re
import threading
import time
import uuid
from collections.abc import Callable, Collection
from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, ClassVar
from urllib.parse import urlsplit

import jwt
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.http import HttpRequest, HttpResponse, HttpResponseBase
from jwt import PyJWK, PyJWKClient
from prometheus_client import Histogram
from redis import Redis
from redis.backoff import NoBackoff
from redis.retry import Retry

from django_common.problem import problem_response

__all__ = [
    "AccessJwtValidator",
    "AccessRequired",
    "AuthError",
    "AuthKeysUnavailable",
    "Denylist",
    "DenylistRecord",
    "DenylistUnavailable",
    "InvalidToken",
    "JwtAuthMiddleware",
    "SessionRevoked",
    "WebhookEvent",
    "WebhookSignatureInvalid",
    "check_settings",
    "verify_authentik_webhook",
]

logger = logging.getLogger("django_common.auth")

_EXEMPT_SETTING = "AUTH_EXEMPT_PATHS"
_DEFAULT_EXEMPT_PATHS = ("/healthz", "/ready", "/health", "/webhooks/authentik")
_ACCESS_ONLY_SETTING = "AUTH_ACCESS_ONLY_PATHS"
_DEFAULT_ACCESS_ONLY_PATHS: tuple[str, ...] = ()
_TEAM_DOMAIN_SETTING = "ACCESS_TEAM_DOMAIN"
_JWKS_URL_SETTING = "AUTHENTIK_JWKS_URL"
_ACCESS_HEADER = "Cf-Access-Jwt-Assertion"
_AUTHORIZATION_HEADER = "Authorization"
_CERTS_PATH = "/cdn-cgi/access/certs"
# 팀 기준 URL — 스킴별 기본 포트(정규형에서 뗀다) · 소문자로 맞춘 호스트 이름의 LDH 라벨(fullmatch — 1–63자 [a-z0-9-] ·
# 영숫자로 시작하고 끝난다 · 하이픈은 가운데만) · 이름 전체 길이 상한 · 숫자 꼴 라벨(fullmatch — 마지막 라벨에 쓰면 안 된다 ·
# 10진 숫자만이거나 `0x` + 16진 숫자(빈 것 포함 — `0x` 자체도) · WHATWG URL ends-in-a-number와 같다 · T070 r3 U2 · r4 V1).
_DEFAULT_PORTS = {"http": 80, "https": 443}
_HOST_LABEL = re.compile(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?")
_HOST_MAX_LENGTH = 253
_NUMERIC_LABEL = re.compile(r"[0-9]+|0x[0-9a-f]*")
_ALGORITHMS = ["RS256"]
_LEEWAY_S = 5
_KEYS_LIFESPAN_S = 3600
_KEYS_FETCH_TIMEOUT_S = 2
# 키 fetch 실패 백오프 창(T070 r3 U4) — 첫 실패 1 s · 연속 실패마다 직전 창의 2배 · 상한 30 s(_KeyClient가 호출 때 읽는다).
_KEYS_BACKOFF_INITIAL_S = 1.0
_KEYS_BACKOFF_MAX_S = 30.0
_ACCESS_REQUIRED_CLAIMS = ["exp", "iat", "aud", "iss"]
_BEARER_REQUIRED_CLAIMS = ["exp", "iat", "sub", "aud", "iss"]
_DENYLIST_TIMEOUT_S = 0.2
_REQUEST_ATTRIBUTES = ("access_claims", "auth_claims", "tenant_id")
# fullmatch로 쓴다 — `$`는 끝 줄바꿈 앞에서도 맞는다. 소문자 hex만(계약 — 대문자 hex는 거부).
_WEBHOOK_SIGNATURE = re.compile(r"sha256=[0-9a-f]{64}")
_WEBHOOK_WINDOW_S = 300
# 토큰 검증에서 나는 토큰 결함 쪽 예외 — PyJWT 예외 전부 + 꼴이 깨진 입력이 표준 라이브러리에서 내는 것(500으로 새지 않게).
# 서명 키 획득 실패(AuthKeysUnavailable)와 설정 오류(ImproperlyConfigured)는 여기에 들지 않는다.
_TOKEN_ERRORS = (jwt.PyJWTError, ValueError, TypeError, RecursionError)

_LOOKUP_SECONDS = Histogram(
    "denylist_lookup_seconds",
    "거부 목록(Dragonfly) 조회 시간(초) — result: ok 키 없음 · revoked 폐기 키 있음 · error 조회 실패",
    labelnames=("result",),
)


# --- 오류 형(D8) -------------------------------------------------------------------------------------------------------


class AuthError(Exception):
    """인증 실패의 공통 형 — 하위 형마다 slug · status가 정해져 있고 to_response()가 RFC 9457 응답을 만든다.

    응답에는 detail · 추가 헤더(WWW-Authenticate 등)를 싣지 않는다 — 예외 인자 · 메시지도 쓰지 않는다(토큰 · 비밀 · URL ·
    라이브러리 예외 문자열이 응답으로 새지 않게).
    """

    slug: ClassVar[str] = "invalid_token"
    status: ClassVar[int] = 401

    def to_response(self) -> HttpResponse:
        return problem_response(self.slug, self.status)


class InvalidToken(AuthError):
    """Bearer 토큰이 없거나 검증 · 클레임 모양 · act 검사에 실패했다 — 401 invalid_token."""

    slug = "invalid_token"
    status = 401


class AccessRequired(AuthError):
    """Cloudflare Access JWT가 없거나 검증 · common_name 검사에 실패했다 — 403 access_required."""

    slug = "access_required"
    status = 403


class SessionRevoked(AuthError):
    """거부 목록이 이 토큰을 폐기했다(revoked:sub nbf > iat 또는 revoked:sid 존재) — 401 session_revoked."""

    slug = "session_revoked"
    status = 401


class DenylistUnavailable(AuthError):
    """거부 목록을 조회하지 못했다(연결 · 시간 초과 · NOPERM · 값 이상 · URL 쿼리 등 무엇이든) — 503 fail-closed."""

    slug = "denylist_unavailable"
    status = 503


class AuthKeysUnavailable(AuthError):
    """서명 키 집합(Authentik JWKS · Access certs)을 가져오거나 읽지 못했다 — 의존성 장애 503 auth_keys_unavailable."""

    slug = "auth_keys_unavailable"
    status = 503


class WebhookSignatureInvalid(AuthError):
    """웹훅 서명 · 본문 · 시각 검증 실패 — 401 webhook_signature_invalid."""

    slug = "webhook_signature_invalid"
    status = 401


# --- 설정(D6 — 호출 시점에 읽는다 · 메시지에 설정 이름만) ---------------------------------------------------------------


def _required(name: str) -> str:
    """비어 있으면 안 되는 인증 문자열 설정 — 없거나 비었거나 str이 아니면 ImproperlyConfigured(이름만) · 글자는
    _printable_ascii가 본다(T070 r4 V2)."""
    value = getattr(settings, name, None)
    if not isinstance(value, str) or not value:
        raise ImproperlyConfigured(f"{name} 설정이 없거나 비었거나 str이 아니다") from None
    return _printable_ascii(name, value)


def _optional(name: str) -> str:
    """빈 값이 유효한 인증 문자열 설정(없으면 빈 값) — str이 아니면 ImproperlyConfigured(이름만) · 글자는 _printable_ascii가
    본다(빈 값은 그대로 유효하다 · T070 r4 V2)."""
    value = getattr(settings, name, "")
    if not isinstance(value, str):
        raise ImproperlyConfigured(f"{name} 설정은 str이어야 한다(빈 값 허용)") from None
    return _printable_ascii(name, value)


def _printable_ascii(name: str, value: str) -> str:
    """인증 문자열 설정 값(T070 r4 V2) — 글자가 모두 공백 없는 출력 가능 ASCII(`!` U+0021 – `~` U+007E)면 그대로 돌려주고,
    하나라도 밖이면 ImproperlyConfigured(설정 이름만 · 값 없음). 범위는 팀 기준 URL 원문 검사(_base_url_parts)와 같다 —
    str.isprintable()이 아니다(U+3164 · U+2800은 보이지 않지만 출력 가능으로 분류된다)."""
    if any(not "!" <= character <= "~" for character in value):
        raise ImproperlyConfigured(f"{name} 설정에 공백 · 제어 문자 · 비ASCII 글자가 있다(`!`–`~`만 받는다)") from None
    return value


def _paths(name: str, default: tuple[str, ...]) -> Collection[str]:
    """경로 목록 설정 — str만 담은 tuple · list · set · frozenset(str 하나면 `in`이 부분 문자열 검사가 된다)."""
    value = getattr(settings, name, default)
    if not isinstance(value, (tuple, list, set, frozenset)) or not all(isinstance(path, str) for path in value):
        raise ImproperlyConfigured(f"{name}는 str만 담은 tuple · list · set · frozenset이어야 한다") from None
    return value


def _team_base_url() -> str:
    """ACCESS_TEAM_DOMAIN → 팀 기준 URL 정규형 `<scheme>://<host>[:<port>]`(certs URL과 Access iss의 기준).

    Cloudflare iss는 소문자 · 포트 없음이다 — 값을 그대로 쓰면(대문자 호스트 · `:443` · 빈 포트) 모든 요청이 조용히 403이
    되므로 분해한 조각으로 다시 만든다: 기본 포트(https 443 · http 80)는 뗀다.
    """
    raw = _required(_TEAM_DOMAIN_SETTING)
    parts = _base_url_parts(raw if "://" in raw else f"https://{raw}")
    if parts is None:
        raise ImproperlyConfigured(
            f"{_TEAM_DOMAIN_SETTING}는 팀 기준 URL(https://<host>[:<port>] · 스킴이 없으면 https)이어야 한다"
        ) from None
    scheme, host, port, loopback = parts
    if scheme == "http" and not loopback:
        raise ImproperlyConfigured(f"{_TEAM_DOMAIN_SETTING}의 http://는 루프백 IP 리터럴(시험 서버)만 받는다") from None
    suffix = "" if port is None or port == _DEFAULT_PORTS[scheme] else f":{port}"
    return f"{scheme}://{host}{suffix}"


def _base_url_parts(candidate: str) -> tuple[str, str, int | None, bool] | None:
    """팀 기준 URL 꼴이면 (스킴 · 정규 호스트 · 포트(없거나 빈 포트면 None) · 루프백 IP 리터럴인가) — 꼴이 아니면 None.

    - 원문에 공백 · 제어 문자 · 비ASCII · `?` · `#`가 있으면 None — urlsplit는 탭 · 줄바꿈을 지우고 앞쪽 공백 · 제어 문자를
      떼어 내므로 그 전에 본다(빈 쿼리 · 조각도 여기서 거부된다). 요청 경로의 ACCESS_TEAM_DOMAIN은 _required가 같은 글자
      범위를 먼저 본다(T070 r4 V2) — 글자 검사는 이 함수 자신의 입력 검사로 남긴다.
    - 스킴 http · https(urlsplit가 소문자로 준다) · 호스트 필수 · 사용자 정보 없음 · 경로는 없거나 `/` · 포트는 숫자
      1–65535(`:0` · `:00`은 None · `:0443`은 443 · T070 r3 U2).
    - 정규 호스트: 루프백 IP 리터럴이면 ipaddress 표기(IPv6는 `[…]`로 다시 감싼다 — 이름 규칙보다 먼저 본다) · 아니면 소문자
      호스트(urlsplit hostname)가 괄호 없이 LDH 이름이어야 한다(_ldh_host_name — 밑줄 · IPvFuture · 루프백 아닌 IPv6 · 끝 점 ·
      빈 라벨 · 라벨 앞뒤 하이픈 · 숫자 꼴 마지막 라벨(10진 숫자만 · `0x` + 16진 숫자 — r4 V1)은 None — 이름은 조회하지
      않는다).
    """
    if any(not "!" <= character <= "~" for character in candidate) or "?" in candidate or "#" in candidate:
        return None
    try:
        parts = urlsplit(candidate)
        port = parts.port  # 숫자가 아니거나 범위 밖인 포트는 ValueError · 빈 포트(`host:`)는 None
    except ValueError:
        return None
    host = parts.hostname  # 소문자 · IPv6 괄호를 뗀 값
    if (
        parts.scheme not in _DEFAULT_PORTS
        or not host
        or port == 0
        or parts.username is not None
        or parts.password is not None
        or parts.path not in ("", "/")
    ):
        return None
    loopback = _loopback_literal(host)
    if loopback is not None:
        return parts.scheme, loopback, port, True
    if "[" in parts.netloc or not _ldh_host_name(host):
        return None
    return parts.scheme, host, port, False


def _ldh_host_name(host: str) -> bool:
    """소문자로 맞춘 호스트가 LDH 이름인가(T070 r3 U2 · r4 V1): 전체 253자 이하 · 라벨마다 _HOST_LABEL(빈 라벨 — 앞 · 끝 점 ·
    `..` — 은 맞지 않는다) · 마지막 라벨이 숫자 꼴(_NUMERIC_LABEL — 10진 숫자만 · `0x` + 16진 숫자(빈 것 포함))이 아니다(`0` ·
    `10.0.0.1` · `127.1` · `0x7f000001` · `127.0.0.0x1`은 이름 조회가 inet_aton 꼴로 다른 주소를 풀 수 있다 · WHATWG URL
    ends-in-a-number와 같다 · 마지막이 아닌 라벨은 보지 않는다). 이름은 조회하지 않는다."""
    labels = host.split(".")
    if len(host) > _HOST_MAX_LENGTH or any(_HOST_LABEL.fullmatch(label) is None for label in labels):
        return False
    return _NUMERIC_LABEL.fullmatch(labels[-1]) is None


def _loopback_literal(host: str) -> str | None:
    """루프백 IP 리터럴(127.0.0.0/8 · ::1)이면 URL 호스트 표기(ipaddress 정규 표기 · IPv6는 `[…]`) — 아니면 None(이름은
    조회하지 않는다)."""
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        return None
    if not address.is_loopback:
        return None
    return f"[{address}]" if address.version == 6 else str(address)


def _access_audiences() -> list[str]:
    """Access audience = ACCESS_AUD_M2M(필수) · ACCESS_AUD_ADMIN(빈 값이면 뺀다) — 중복 없이."""
    candidates = (_required("ACCESS_AUD_M2M"), _optional("ACCESS_AUD_ADMIN"))
    return [audience for audience in dict.fromkeys(candidates) if audience]


# --- 서명 키 가져오기(D5) ----------------------------------------------------------------------------------------------


class _KeysUnavailable(Exception):
    """서명 키 집합을 얻지 못했다(내부 신호 — error = 원 예외 클래스 이름 또는 backoff(백오프 창 안 · T070 r3 U4) · 원
    예외는 잇지 않는다)."""

    def __init__(self, error: str) -> None:
        super().__init__(error)
        self.error = error


class _KeyClient(PyJWKClient):
    """PyJWKClient + 키 집합 획득 실패의 분류 + fetch 실패 백오프(T070 r3 U4 · r4 V4).

    - 분류: get_signing_keys(…)(캐시 조회 · fetch · JWK Set 해석 · 서명 키 거르기)에서 난 예외는 토큰과 무관한 의존성
      장애다 → _KeysUnavailable(원 예외 클래스 이름 — 백오프 신호는 error=backoff 그대로 통과시킨다). get_signing_key(kid)는
      cooldown 재조회도 이 메서드로 하므로, 그 밖으로 올라오는 PyJWKClientError는 「키 집합은 얻었는데 kid가 없다」뿐이다(토큰
      결함).
    - 백오프: PyJWT 공개 메서드 fetch_data(캐시가 비었거나 만료됐을 때 · 모르는 kid 재조회 때만 불린다 — 캐시 적중은 부르지
      않는다)를 덮어쓴다. 상태는 이 클라이언트(키 URL 하나)에 두고 자기 잠금(_backoff_lock · RLock — T070 r4 V4) 아래에서만
      읽고 쓴다. PyJWT 비공개 속성(_client_lock)은 읽지 않는다 — 그 속성이 없는 판에서 AttributeError가 되거나, 재진입 불가
      Lock으로 바뀐 판에서 get_signing_key가 쥔 잠금을 같은 스레드가 다시 쥐려다 멈추지 않게. PyJWT 2.15.1에서 그 잠금을 쥐는
      곳은 get_signing_key(jwks_client.py:277)뿐이고 PyJWKClient.fetch_data는 쥐지 않으므로, 잠금 순서는 언제나 PyJWT 잠금 →
      자기 잠금이고 반대 순서로 쥐는 경로가 없다(교착 없음). 2.15.1에서는 get_signing_key 경로를 PyJWT 잠금이 이미 직렬화하고,
      그 잠금이 없는 판에서는 자기 잠금이 fetch를 직렬화한다 — 직렬화할 뿐 중복은 없애지 않는다: PyJWT 잠금이 없는 판에서 빈
      캐시 · 만료에 동시 요청이 몰리고 fetch가 성공하면 fetch가 요청 수만큼 돈다(기다리던 판정은 이미 캐시 확인을 지났다).
      2.15.1에서는 PyJWT 잠금이 캐시 확인까지 감싸 fetch 1이다(ac-24h — 중복 제거는 PyJWT 잠금 몫이다 · T070 r5 W3). 창은
      실패를 안 시각부터 센다.
    - PyJWT 결합: 모듈 독스트링 「서명 키 가져오기」의 「PyJWT 결합」 그대로다(호출 순서 · 공개 메서드 이름 둘 · 잠금 범위).
    """

    def __init__(self, uri: str, **options: Any) -> None:
        super().__init__(uri, **options)
        self._backoff_lock = threading.RLock()  # 백오프 상태의 자기 잠금(PyJWT _client_lock과 무관 · T070 r4 V4)
        self._backoff_s = 0.0  # 직전 창 길이(0 = 창 없음 — 아직 실패한 적이 없거나 마지막 fetch가 성공했다)
        self._backoff_until: float | None = None  # 창이 끝나는 단조 시각(time.monotonic)

    def fetch_data(self) -> Any:
        with self._backoff_lock:
            if self._backoff_until is not None and time.monotonic() < self._backoff_until:
                raise _KeysUnavailable("backoff")
            try:
                data = super().fetch_data()
            except Exception:
                # 어떤 실패든 창을 연다 — 직전 창의 2배(실패 횟수로 거듭제곱하지 않는다) · 상한 · 상수는 호출 때 읽는다.
                previous = self._backoff_s
                self._backoff_s = _KEYS_BACKOFF_INITIAL_S if previous <= 0 else min(previous * 2, _KEYS_BACKOFF_MAX_S)
                self._backoff_until = time.monotonic() + self._backoff_s
                raise
            self._backoff_s = 0.0
            self._backoff_until = None
            return data

    def get_signing_keys(self, refresh: bool = False) -> list[PyJWK]:
        error = "Exception"
        try:
            return super().get_signing_keys(refresh)
        except _KeysUnavailable:
            raise  # 백오프 창 — fetch_data가 이미 분류했다(error=backoff · 잇는 예외 없음)
        except Exception as exc:  # noqa: BLE001 — 키 집합 획득의 어떤 실패든 의존성 장애다(fail-closed 503)
            error = type(exc).__name__
        raise _KeysUnavailable(error)


class _SigningKeys:
    """서명 키 출처 하나(Access certs 또는 Authentik JWKS)의 URL별 _KeyClient — 미들웨어 · 검증기 인스턴스 안에 둔다."""

    def __init__(self, source: str, setting: str) -> None:
        self._source = source
        self._setting = setting
        self._clients: dict[str, _KeyClient] = {}
        self._lock = threading.Lock()

    def signing_key(self, token: str, url: str) -> PyJWK:
        """token 헤더의 kid에 맞는 서명 키. 키 집합 획득 실패 → AuthKeysUnavailable(WARNING 한 줄) · 토큰 결함(꼴 · 모르는
        kid)은 PyJWTError 그대로 올린다."""
        client = self._client(url)
        error = "Exception"
        try:
            return client.get_signing_key_from_jwt(token)
        except _KeysUnavailable as exc:
            error = exc.error
        logger.warning("auth.keys_unavailable source=%s error=%s", self._source, error)
        raise AuthKeysUnavailable() from None

    def _client(self, url: str) -> _KeyClient:
        with self._lock:
            client = self._clients.get(url)
            if client is None:
                client = _key_client(url, self._setting)
                self._clients[url] = client
            return client


def _key_client(url: str, setting: str) -> _KeyClient:
    """키 URL의 _KeyClient(1시간 캐시 · fetch 2 s) — 생성은 네트워크를 쓰지 않는다. http · https URL이 아니면(PyJWKClient가
    생성에서 거부한다) ImproperlyConfigured(설정 이름만). 요청 경로(_SigningKeys)와 check_settings가 같이 쓴다(T070 r3 U3)."""
    try:
        return _KeyClient(url, cache_jwk_set=True, lifespan=_KEYS_LIFESPAN_S, timeout=_KEYS_FETCH_TIMEOUT_S)
    except (jwt.PyJWKClientError, ValueError):
        pass
    raise ImproperlyConfigured(f"{setting} 설정은 http · https URL이어야 한다") from None


# --- Access(D3) ------------------------------------------------------------------------------------------------------


class AccessJwtValidator:
    """Cloudflare Access JWT(Cf-Access-Jwt-Assertion) 검증기 — 규칙은 모듈 독스트링 「Access」.

    설정은 validate() 호출 때 읽는다. 서명 키는 이 인스턴스 안에 URL별 PyJWKClient(1시간 캐시 · fetch 2 s)로 둔다.
    """

    def __init__(self) -> None:
        self._keys = _SigningKeys("access", _TEAM_DOMAIN_SETTING)

    def validate(self, token: str | None) -> dict[str, Any]:
        """검증된 Access 클레임 dict — 실패 AccessRequired · 키를 얻지 못하면 AuthKeysUnavailable."""
        base = _team_base_url()
        audiences = _access_audiences()
        expected_common_name = _required("ACCESS_EXPECTED_CN")
        if not isinstance(token, str) or not token:
            raise AccessRequired()
        claims: dict[str, Any] | None = None
        try:
            key = self._keys.signing_key(token, base + _CERTS_PATH)
            claims = jwt.decode(
                token,
                key,
                algorithms=_ALGORITHMS,
                audience=audiences,
                issuer=base,
                leeway=_LEEWAY_S,
                options={"require": _ACCESS_REQUIRED_CLAIMS},
            )
        except _TOKEN_ERRORS:
            claims = None
        if claims is None:
            raise AccessRequired()
        common_name = claims.get("common_name")
        if not isinstance(common_name, str) or common_name != expected_common_name:
            raise AccessRequired()
        return claims


# --- Bearer(D4) ------------------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class _Bearer:
    """검증된 Bearer 토큰 — claims(payload 전체) · 거부 목록 조회 값(sub · sid · iat) · tenant_id(UUID 또는 None)."""

    claims: dict[str, Any]
    sub: str
    sid: str | None
    iat: int
    tenant_id: uuid.UUID | None


class _BearerValidator:
    """Authentik Bearer 검증(④ ⑤) — 규칙은 모듈 독스트링 「Bearer」. 설정은 validate() 호출 때 읽는다."""

    def __init__(self) -> None:
        self._keys = _SigningKeys("authentik", _JWKS_URL_SETTING)

    def validate(self, header: str | None) -> _Bearer:
        jwks_url = _required(_JWKS_URL_SETTING)
        issuer = _required("AUTHENTIK_ISSUER")
        audience = _required("AUTHENTIK_AUDIENCE")
        actor_sub = _optional("AUTH_ACTOR_SUB")
        token = _bearer_token(header)
        if token is None:
            raise InvalidToken()
        claims: dict[str, Any] | None = None
        try:
            key = self._keys.signing_key(token, jwks_url)
            claims = jwt.decode(
                token,
                key,
                algorithms=_ALGORITHMS,
                audience=audience,
                issuer=issuer,
                leeway=_LEEWAY_S,
                options={"require": _BEARER_REQUIRED_CLAIMS},
            )
        except _TOKEN_ERRORS:
            claims = None
        bearer = None if claims is None else _bearer_from_claims(claims, actor_sub)
        if bearer is None:
            raise InvalidToken()
        return bearer


def _bearer_token(header: str | None) -> str | None:
    """`Bearer <token>`(스킴 대소문자 무시 · 공백 하나 · 토큰에 공백 없음)의 토큰 — 꼴이 아니면 None."""
    if not isinstance(header, str):
        return None
    scheme, separator, token = header.partition(" ")
    if separator != " " or not scheme.isascii() or scheme.lower() != "bearer":
        return None
    if not token or any(character.isspace() for character in token):
        return None
    return token


def _bearer_from_claims(claims: dict[str, Any], actor_sub: str) -> _Bearer | None:
    """클레임 모양 검사(D4 · fail-closed) — 어기면 None."""
    sub = claims.get("sub")
    if not isinstance(sub, str) or not sub:
        return None
    sid: str | None = None
    if "sid" in claims:
        value = claims["sid"]
        if not isinstance(value, str) or not value:
            return None
        sid = value
    tenant_id: uuid.UUID | None = None
    if "tenant_id" in claims:
        tenant_id = _canonical_uuid(claims["tenant_id"])
        if tenant_id is None:
            return None
    if actor_sub:
        act = claims.get("act")
        if not isinstance(act, dict) or act.get("sub") != actor_sub:
            return None
    try:
        iat = int(claims["iat"])  # PyJWT가 require · int()로 이미 검증했다(문자열 · 실수 꼴도 int로 읽힌다)
    except (KeyError, TypeError, ValueError, OverflowError):
        return None
    return _Bearer(claims=claims, sub=sub, sid=sid, iat=iat, tenant_id=tenant_id)


def _canonical_uuid(value: object) -> uuid.UUID | None:
    """소문자 정규형 UUID 문자열이면 uuid.UUID — 대문자 · 중괄호 · urn:uuid: · 32 hex · str 아님은 None."""
    if not isinstance(value, str):
        return None
    try:
        parsed = uuid.UUID(value)
    except ValueError:
        return None
    return parsed if str(parsed) == value else None


# --- 거부 목록(D7) ------------------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class DenylistRecord:
    """거부 목록 원시 조회 결과 — sub_nbf = revoked:sub:{sub} 값(정수 · 키가 없으면 None) · sid_revoked = revoked:sid:{sid}
    존재(sid를 묻지 않았으면 False)."""

    sub_nbf: int | None
    sid_revoked: bool

    def revokes(self, iat: int) -> bool:
        """iat에 발급된 토큰을 거부하는가 — sub_nbf가 있고 iat보다 크거나(같으면 아니다) sid가 폐기됐다."""
        return (self.sub_nbf is not None and self.sub_nbf > iat) or self.sid_revoked


class Denylist:
    """세션 거부 목록(Dragonfly) 조회 — 규칙은 모듈 독스트링 「Denylist」. 생성은 연결하지 않는다."""

    def __init__(self) -> None:
        self._clients: dict[str, Redis] = {}
        self._lock = threading.Lock()

    def lookup(self, sub: str, sid: str | None = None) -> DenylistRecord:
        """revoked:sub:{sub} · (sid가 있으면) revoked:sid:{sid}를 파이프라인 1회로 조회한다 — 실패 DenylistUnavailable."""
        if not isinstance(sub, str) or (sid is not None and not isinstance(sid, str)):
            raise TypeError("sub는 str · sid는 None 또는 str이어야 한다")
        if not sub or sid == "":
            raise ValueError("sub · sid는 비지 않은 str이어야 한다")
        url = _required("DRAGONFLY_URL")
        started = time.perf_counter()
        record: DenylistRecord | None = None
        error = "Exception"
        try:
            if _url_has_query(url):
                error = "url_query"
            else:
                record = self._query(url, sub, sid)
        except Exception as exc:  # noqa: BLE001 — 어떤 조회 실패든 503 fail-closed(메시지는 키 · URL을 실을 수 있다)
            error = type(exc).__name__
        elapsed = time.perf_counter() - started
        if record is None:
            _LOOKUP_SECONDS.labels(result="error").observe(elapsed)
            logger.warning("auth.denylist_unavailable source=denylist error=%s", error)
            raise DenylistUnavailable() from None
        result = "revoked" if record.sid_revoked or record.sub_nbf is not None else "ok"
        _LOOKUP_SECONDS.labels(result=result).observe(elapsed)
        return record

    def _client(self, url: str) -> Redis:
        with self._lock:
            client = self._clients.get(url)
            if client is None:
                client = _denylist_client(url)
                self._clients[url] = client
            return client

    def _query(self, url: str, sub: str, sid: str | None) -> DenylistRecord:
        with self._client(url).pipeline(transaction=False) as pipe:
            pipe.get(f"revoked:sub:{sub}")
            if sid is not None:
                pipe.exists(f"revoked:sid:{sid}")
            values = pipe.execute()
        raw_nbf = values[0]
        sub_nbf = None if raw_nbf is None else int(raw_nbf)
        sid_revoked = sid is not None and int(values[1]) > 0
        return DenylistRecord(sub_nbf=sub_nbf, sid_revoked=sid_revoked)


def _url_has_query(url: str) -> bool:
    """DRAGONFLY_URL에 쿼리가 있는가 — redis-py는 URL 쿼리를 키워드 인자보다 우선해 0.2 s · 재시도 0을 덮어쓴다(사실 ④).
    urlsplit의 ValueError는 그대로 올린다. 요청 경로(lookup — 503 url_query)와 check_settings(설정 오류)가 같이 쓴다."""
    return bool(urlsplit(url).query)


def _denylist_client(url: str) -> Redis:
    """거부 목록 클라이언트(D7) — 지연 생성(연결 · PING 없음) · 0.2 s · 재시도 0을 명시한다(어느 생성 경로의 기본값에도
    기대지 않는다). 요청 경로(Denylist._client)와 check_settings(생성만)가 같이 쓴다(T070 r3 U3)."""
    return Redis.from_url(
        url,
        socket_timeout=_DENYLIST_TIMEOUT_S,
        socket_connect_timeout=_DENYLIST_TIMEOUT_S,
        retry=Retry(NoBackoff(), 0),
    )


# --- 설정 검사(T070 r3 U3) ----------------------------------------------------------------------------------------------


def check_settings() -> None:
    """인증 설정 전부를 요청 없이 검사한다 — 기동 검사(T072)가 부른다(요청 때 500이 되는 설정 오류를 기동 실패로 앞당긴다).

    요청 때 인증 계층이 쓰는 판정 함수를 그대로 부른다(사본 규칙 없음). 순서는 고정이고 첫 실패에서 멈춘다(필수 · 선택 =
    _required · _optional — 둘 다 공백 없는 출력 가능 ASCII만 받는다 · 아래 V2 · T070 r4):
    ① AUTH_EXEMPT_PATHS ② AUTH_ACCESS_ONLY_PATHS(형 — _paths) ③ ACCESS_TEAM_DOMAIN(필수 + V2 + 팀 기준 URL — _team_base_url)
    ④ ACCESS_AUD_M2M(필수 + V2) ⑤ ACCESS_AUD_ADMIN(선택 + V2 — ④⑤는 _access_audiences) ⑥ ACCESS_EXPECTED_CN(필수 + V2)
    ⑦ AUTHENTIK_JWKS_URL(필수 + V2 + http · https — 키 클라이언트 생성 _key_client · fetch 없음) ⑧ AUTHENTIK_ISSUER(필수 + V2)
    ⑨ AUTHENTIK_AUDIENCE(필수 + V2) ⑩ AUTH_ACTOR_SUB(선택 + V2) ⑪ DRAGONFLY_URL(필수 + V2 · 쿼리 없음 — _url_has_query ·
    Redis.from_url이 받는 URL — 거부 목록 클라이언트와 같은 생성 인자로 만들기만 하고 연결하지 않는다 · _denylist_client).
    순서는 시험이 고정한다 — 형 검사의 자리는 ac-23c · 깊은 검사(V2 · 팀 기준 URL · ⑦ 스킴 · ⑪ 쿼리)의 자리는 ac-23d(T070 r4 V3).
    네트워크 · 이름 조회 · Dragonfly 연결 · 키 fetch는 없다. 실패는 ImproperlyConfigured(설정 이름만 · 값 없음 · 연쇄
    없음). 요청 때 동작은 그대로다 — DRAGONFLY_URL의 쿼리 · 해석 실패는 요청 때 503 denylist_unavailable(error=url_query ·
    예외 클래스)이고 여기서는 설정 오류다.
    """
    _paths(_EXEMPT_SETTING, _DEFAULT_EXEMPT_PATHS)
    _paths(_ACCESS_ONLY_SETTING, _DEFAULT_ACCESS_ONLY_PATHS)
    _team_base_url()
    _access_audiences()
    _required("ACCESS_EXPECTED_CN")
    _key_client(_required(_JWKS_URL_SETTING), _JWKS_URL_SETTING)
    _required("AUTHENTIK_ISSUER")
    _required("AUTHENTIK_AUDIENCE")
    _optional("AUTH_ACTOR_SUB")
    url = _required("DRAGONFLY_URL")
    usable = False
    try:
        if not _url_has_query(url):
            _denylist_client(url).close()  # 생성만 — 연결 · PING 없음(연결이 없는 풀을 닫는다)
            usable = True
    except Exception:  # noqa: BLE001, S110 — URL 해석 · 클라이언트 생성의 어떤 실패든 설정 오류다(메시지는 URL을 싣는다)
        pass
    if not usable:
        raise ImproperlyConfigured("DRAGONFLY_URL은 쿼리 없는 redis URL(Redis.from_url이 받는 꼴)이어야 한다") from None


# --- 미들웨어(D2) -------------------------------------------------------------------------------------------------------


class JwtAuthMiddleware:
    """요청 인증(sync 전용) — 동작 전부는 모듈 독스트링 「JwtAuthMiddleware」."""

    sync_capable = True
    async_capable = False

    def __init__(self, get_response: Callable[[HttpRequest], HttpResponseBase]) -> None:
        self.get_response = get_response
        self._access = AccessJwtValidator()
        self._bearer = _BearerValidator()
        self._denylist = Denylist()

    def __call__(self, request: HttpRequest) -> HttpResponseBase:
        path = request.path_info
        if path in _paths(_EXEMPT_SETTING, _DEFAULT_EXEMPT_PATHS):
            return self.get_response(request)
        request.get_host()  # ALLOWED_HOSTS 밖이면 DisallowedHost → handler400(400 invalid_host) — 자격 검사보다 먼저
        for name in _REQUEST_ATTRIBUTES:
            vars(request).pop(name, None)
        access_only = path in _paths(_ACCESS_ONLY_SETTING, _DEFAULT_ACCESS_ONLY_PATHS)
        try:
            attributes = self._authenticate(request, access_only=access_only)
        except AuthError as error:
            return error.to_response()
        for name, value in attributes.items():
            setattr(request, name, value)
        return self.get_response(request)

    def _authenticate(self, request: HttpRequest, *, access_only: bool) -> dict[str, object]:
        """③–⑥ 판정 — 성공하면 둘 요청 속성(이름 → 값) · 실패는 AuthError 하위 형을 올린다."""
        access_claims = self._access.validate(request.headers.get(_ACCESS_HEADER))
        if access_only:
            return {"access_claims": access_claims}
        bearer = self._bearer.validate(request.headers.get(_AUTHORIZATION_HEADER))
        if self._denylist.lookup(bearer.sub, bearer.sid).revokes(bearer.iat):
            raise SessionRevoked()
        attributes: dict[str, object] = {"access_claims": access_claims, "auth_claims": bearer.claims}
        if bearer.tenant_id is not None:
            attributes["tenant_id"] = bearer.tenant_id
        return attributes


# --- 웹훅(D9) ----------------------------------------------------------------------------------------------------------


@dataclass(frozen=True)
class WebhookEvent:
    """검증된 Authentik 웹훅 — pk(멱등 키) · created(aware datetime) · data(본문 dict 전체)."""

    pk: str
    created: datetime
    data: dict[str, Any]


def verify_authentik_webhook(
    body: bytes, signature: str | None, *, secret: str, now: datetime | None = None
) -> WebhookEvent:
    """X-Authentik-Signature 정규형 HMAC + pk · created(±300 s) 검증 — 규칙은 모듈 독스트링 「웹훅」."""
    if not isinstance(secret, str):
        raise TypeError("secret은 str이어야 한다")
    if not secret:
        raise ValueError("웹훅 비밀이 비었다 — 빈 HMAC 비밀은 누구나 서명할 수 있다(pod 설정 오류)")
    if now is not None and (not isinstance(now, datetime) or now.utcoffset() is None):
        raise ValueError("now는 tz가 있는 datetime이어야 한다")
    if not isinstance(body, bytes):  # bytearray · memoryview도 거부한다(T070 r3 U1 — Django request.body는 bytes다)
        raise TypeError("body는 bytes여야 한다")
    event = _webhook_event(body, signature, secret, datetime.now(UTC) if now is None else now)
    if event is None:
        raise WebhookSignatureInvalid()
    return event


def _webhook_event(body: bytes, signature: object, secret: str, now: datetime) -> WebhookEvent | None:
    """검증을 통과하면 WebhookEvent · 어느 단계든 어기면 None(호출자가 WebhookSignatureInvalid로 바꾼다)."""
    if not isinstance(signature, str) or _WEBHOOK_SIGNATURE.fullmatch(signature) is None:
        return None
    try:
        data = json.loads(body.decode("utf-8"))
        canonical = json.dumps(data, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("ascii")
    except (ValueError, TypeError, RecursionError):
        return None
    expected = "sha256=" + hmac.new(secret.encode(), canonical, hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        return None
    if not isinstance(data, dict):
        return None
    pk, created_text = data.get("pk"), data.get("created")
    if not isinstance(pk, str) or not pk or not isinstance(created_text, str):
        return None
    try:
        created = datetime.fromisoformat(created_text)
    except ValueError:
        return None
    if created.utcoffset() is None:
        return None
    try:
        skew = abs((now - created).total_seconds())
    except OverflowError:
        return None
    if skew > _WEBHOOK_WINDOW_S:
        return None
    return WebhookEvent(pk=pk, created=created, data=data)
