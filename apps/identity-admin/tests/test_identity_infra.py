"""T073 ia 시험 — 설정 · ACL · 모델의 DB 꼴 · 외부 HTTP 클라이언트(설계 D1 「test_identity_infra.py」 · 조각 ②: ia-20 · 23 · 24 ·
조각 ④: ia-22 · 41).

- ia-20(D4 · D5 · VD-T073-3): 모델 셋(tenant · tenant_membership · session_revocation_log)은 pod 앱 identity_admin의
  GlobalModel(B 등급)이다 — 세 표의 RLS가 꺼져 있다(ENABLE · FORCE 둘 다) · check_rls 위반 0 · 성공 줄의 B 등급 수 ≥ 4(outbox + 셋) · 제약
  · 인덱스 이름(설계 D4 표 · data-model §1–§3 — srl_user_floor_idx는 `(sub, nbf DESC) WHERE sid IS NULL` 부분 인덱스)이 카탈로그에
  있다 · 업무 필드만으로 ORM `objects.create()`(app role)를 하면 pk · created_at(tenant는 updated_at도)이 RETURNING으로 채워지고
  (refresh 없이 uuid.UUID · datetime 형 — 저장 전 값 DatabaseDefault는 None이 아니라서 형으로 본다) id는 UUID v7이다
  (`uuid_extract_version(id)` = 7 — db_default=UUID7()).
  제약 식(fix-2 F10): owner 별칭으로 위반 행(대문자 슬러그 · 빈 표시 이름 · 모르는 상태 · 모르는 역할 · 모르는 reason)을 넣으면 그
  제약 이름(psycopg diag.constraint_name)의 IntegrityError다 · 계약의 reason 다섯 값은 모두 들어간다. 정적(DB 없음): 0001_initial은
  dependencies 빈 목록 · operations는 CreateModel 셋뿐(core 0001과 엮이지 않는다 · 손 SQL · RunPython 0 — D5).
- ia-23(D6 · D18의 conf 부분 — 기동 하위 프로세스: 템플릿 tests._boot의 boot · assert_refused · boot_facts):
  ① 나가는 쪽 자격 셋(AUTHENTIK_API_TOKEN · OPENFGA_STORE_ID · OPENFGA_PRESHARED_KEY)에 자리값 + JT_PLACEHOLDER_EXEMPT = 그 셋 →
  종료 0 ② 면제 env 없이 같은 자리값 → 거부 이름 = 그 셋 ③ 들어오는 쪽 검증 값(AUTHENTIK_WEBHOOK_SECRET · AUTHENTIK_JWKS_URL ·
  AUTHENTIK_ISSUER)에 자리값 + 그 이름으로 면제 요청 → 거부(그 이름 + JT_PLACEHOLDER_EXEMPT) ④ conf.PLACEHOLDER_EXEMPTABLE ==
  나가는 쪽 셋(정확 일치) ⑤ 웹훅 비밀 31자 → 거부 · 32자 → 종료 0 ⑥ API URL 둘(AUTHENTIK_API_URL · OPENFGA_API_URL)에 사용자
  정보 · 쿼리 · 조각 · 경로(`/api`) → 각각 거부(같은 URL에 `/` 경로는 종료 0 — 부정 사례의 짝).
  in-process `conf.load(environ=…)`(템플릿 test_settings_load_* 꼴 · 기준 매핑 = 래퍼 env — fix-2):
  ⑦ settings 노출 7(F1): django.conf.settings의 전용 설정 일곱이 래퍼 env 값과 같다(쓰기 플래그는 bool False) · RuntimeEnv
  repr에 비밀 셋의 값이 없다 ⑧ 쓰기 플래그의 문자열 해석(F2): "false" → False · "true" → True · env 없음 → False · "" ·
  "False " → 거부 ⑨ 비밀 셋은 공백 없는 출력 가능 ASCII(F6): 끝 LF · CRLF · 가운데 공백 · 비ASCII → 그 이름만 거부(덧붙인
  글자를 뺀 값은 통과) ⑩ 서비스 기준 URL의 netloc = 호스트[:포트](F7): 퍼센트 인코딩 · 빈 포트 · 포트 0 · 범위 밖 포트 ·
  IPv6 리터럴 · `;` · 역슬래시 → 그 이름만 거부(svc 이름 · 루프백 · 대문자 스킴과 호스트는 통과).
- ia-24(D24 · 정적): compose/dragonfly-dev.acl의 `USER identity-admin` 줄 규칙 토큰 == conftest DRAGONFLY_USERS[POD_NAME]에서
  resetchannels를 뺀 것 == tests/test_api.py의 T066 사본 IA_DRAGONFLY_RULES(AST로 읽는다 · T075 수정 라운드 1) == contracts/denylist.md
  §ACL identity-admin 행(시험 상수 — specs 경로를 읽지 않는다) · aclfile 전체 == 세 줄 정본(default · admin · identity-admin 줄 — 순서 ·
  LF · 끝 LF 하나 · 다른 USER 줄 0 · T075 수정 라운드 2 RB2-1).
- 손 수정 ⑩의 단언 재작성 등록(fix-6 K4 · 정적): tests._ia_support · tests._ia_fakes가 pytest 단언 재작성을 받았다(모듈 전역에
  `@pytest_ar` — 템플릿 tests/test_logging.py의 REWRITTEN_HELPERS 단언과 같은 방식).
- ia-18(D23 · 조각 ⑥ · 정적 — 파일을 pyyaml로 읽는다 · DB · Docker 없음): deploy/base/externalsecret-env.yaml의 `data[0..7]`이 순정
  생성 커밋의 순서 그대로(overlay 인덱스 패치의 인터페이스) · `data[8..11]`이 설계 D23 표(secretKey · remoteRef key · property)와
  같고 그 넷의 template.data env 값이 `{{ .<secretKey> }}`이다(client_id · client_secret 없음 — 항목 수 12) · template 참조 ⊆
  secretKey · store `vault-dev`(ClusterSecretStore) · 모든 키가 `dev/` / deploy/base/configmap.yaml의 AUTHENTIK_WRITES_ENABLED가
  문자열 "false"이고 서비스 기준 URL 키 둘이 없다(기본값 = svc DNS) / env.example의 키 집합 ⊇ conf.RuntimeEnv 필드 − {POD_IP ·
  POD_NAMESPACE · DATABASE_OWNER_URL · JT_PLACEHOLDER_EXEMPT}(새 필드를 더하고 env.example을 잊으면 걸린다) · 주석 · 빈 줄 밖의 모든
  줄이 `KEY=`(키만 — 값 없음)이고 DATABASE_OWNER_URL 키가 없다(fix-6 K3 — 템플릿 하네스의 같은 검사는 sample-pod에만 돈다).
- ia-19 옆(S9 — 조각 ③-b2 첫 단계 · 하위 프로세스 · Docker 없음): urlconf를 import해도 기본 REGISTRY에 업무 지표
  `session_revocations`가 없고 지표 함수 첫 호출 뒤에 생긴다(지연 등록 — relay 레지스트리에 web 지표가 실리지 않는다).
- ia-22(D20 · 조각 ④ — `outbound.request_json` · `build_url`, 원시 HTTP 서버 tests._ia_fakes.RawHttpServer): JSON 응답 · 헤더
  (Bearer · Accept · User-Agent = identity-admin/<호출 때의 APP_VERSION> · 본문이 있을 때만 Content-Type) · 204와 빈 본문 None /
  302 + Location → UpstreamStatus(302)이고 둘째 서버가 받은 요청 0(양성 대조: urllib 기본 opener는 따라가 Authorization을 다시
  보낸다) · 프록시 env를 둬도 직접 간다(양성 대조: 기본 opener는 프록시 서버를 지난다) · 블랙홀 → 5 s대 timeout · 마감을 준 느린
  본문 → 마감에서 deadline(양성 대조: 마감 없으면 끝까지 읽는다) · 마감으로 줄어든 소켓 타임아웃의 시간 초과는 20회 되풀이해도
  deadline · 마감 0 s → 호출 0 · file · ftp · data 스킴 → 호출 0 scheme · 호스트 없는 http URL → 호출 0 invalid_request /
  질의 값의 & · # · % · 공백이 원문 그대로(반환 URL을 글자 그대로 견준다 — 기준 URL 끝 `/`는 뗀다) · 꼴이 아닌 경로 성분(2**63
  이상 정수 포함) → 호출 0 invalid_request · lone surrogate 질의 값 · 문자열 · bytes segments · JSON 기본형이 아닌 본문 →
  invalid_request(값 · 형 이름 없음) / 1 MiB 초과 → too_large(정확히 1 MiB는 통과) · JSON이 아닌 200 → malformed ·
  Content-Length에 못 미쳐 끊긴 본문(일부 · 0바이트) · 종결 chunk 전에 끊긴 chunked → connection(짝: 길이가 맞으면 값) · 상태
  표(404 · 401 · 403 거짓 / 429 · 500 · 503 참) / 토큰 끝 LF · 가운데 CR · 비ASCII(한글 · latin-1) · 「LF + 공백」 → 호출 0
  invalid_request(양성 대조: 그 글자를 뺀 토큰은 1회 닿는다) / HTTPS 핸들러는 https URL에서만 짓고 두 핸들러는 debuglevel 0 /
  오류 위생: 예외 str · repr · args에 URL · 질의 값 · 토큰 · 루프백 주소가 없고 `__cause__` · `__context__` None ·
  `__suppress_context__` 참.
- ia-41(D20 · 조각 ④ — `authentik.py` 메서드 여덟, 확장 가짜 tests._ia_fakes.FakeAuthentikExt): 메서드마다 경로와 끝 슬래시 ·
  질의(키 · 값 원문) · 필터 무시 미끼 거르기(find_group 이름 · find_user uuid 정확 일치 · list_sessions의 user == pk — bool ·
  문자열 user는 버린다) · 쪽 매김(page_size 100 · page 1부터 · next 0에서 멈춤) · 쪽 상한(끝나지 않는 next → 세션 정확히 10쪽 ·
  이벤트 정확히 50쪽 · ceiling_hits 0 · truncated · 상한은 모듈 속성으로 덮인다) · 이벤트는 쪽마다 Listing을 내준다(둘째 쪽 503 →
  첫 쪽은 받았고 그다음에 예외 · 셋째 쪽 요청 0) · 2쪽 이후의 404는 목록의 끝(1쪽 404는 UpstreamStatus) · 한 쪽 101건 →
  malformed(100건은 통과) · 꼴이 아닌 pk · uuid → 호출 0(get_user None · add_user · patch_attributes False · delete_session
  skipped · list_sessions 빈 Listing) · 인자 방어(find_*의 None · 빈 문자열 → [] · Mapping이 아닌 attributes → False · lone
  surrogate username → invalid_request — 모두 호출 0) · 반환 꼴(delete_session의 204 deleted · 404 gone · 403 · 503은
  UpstreamStatus) · 계약 밖 본문 → malformed · token 인자는 메서드 여덟 모두에서 그 호출의 모든 요청에 쓰인다 · 설정(토큰 · 기준
  URL)은 호출 때 읽는다(원시 요청 줄로 본다) · 마감 0 s → 메서드 여덟 모두 호출 0.
- 조각 ⑤-b 첫 단계(조각 ④ 검증 4V-1 – 4V-4 반영 — V1 · V2 · V4 · V5): 사용자 pk 2**63은 꼴 아님(get_user None · add_user ·
  patch_attributes False · list_sessions 빈 Listing · 호출 0 — 짝 2**63 - 1은 요청이 나간다) · 10만 단 중첩 본문 · 스킴에 탭이 든
  URL → invalid_request(호출 0) · 2쪽의 403 · 429는 목록의 끝이 아니다(404만 끝) · `_timeout_kind`의 두 절반(넉넉한 마감 →
  timeout · 시간 초과 때 지난 마감 → deadline) · 상한 쪽이어도 next 0이면 truncated 거짓 · find_*의 정수 · bytes 인자 → [] ·
  dict가 아닌 Mapping attributes는 받는다 · capsys 묶음의 길이는 단언 앞에서 묶는다.

DB · 가짜 서버가 필요 없는 시험은 ia73_env를 쓰지 않는다(이 모듈은 pytestmark로 환경을 고르지 않는다 — DB 마크는 ia-20의
DB 노드 둘만 · ia-22 · ia-41은 시험마다 `@pytest.mark.usefixtures("ia73_env")` — DNS 가드 · 프록시 끄기 · 가짜 초기화).
구현 모듈(identity_admin.conf 의 새 상수 · 모델)은 시험 함수 안에서 가져온다(모델은 apps.get_models()에서 db_table로 —
_ia_support.model). 실패 문구는 cp949로 쓸 수 있는 글자만 쓴다. 자격 · 비밀 · env 매핑은 assert 식 안의 호출 인자로 두지 않는다.
"""

from __future__ import annotations

import ast
import http.client
import importlib
import io
import json
import os
import re
import secrets
import subprocess
import sys
import urllib.request
import uuid
from collections.abc import Callable, Iterable, Iterator, Mapping
from contextlib import ExitStack
from datetime import UTC, datetime, timedelta
from pathlib import Path
from types import MappingProxyType
from typing import TYPE_CHECKING, Any

import pytest
import yaml

from tests._boot import assert_refused, boot, boot_facts, refused_names
from tests._ia_fakes import SESSIONS_PATH, FakeAuthentikExt, RawHttpServer, RawReply, make_event, make_session
from tests._ia_support import DB, OWNER_ALIAS, db_now, impl, model, timed
from tests._identity_fakes import blackhole, closed_port
from tests._secret import Secret

if TYPE_CHECKING:
    from pytest_django.fixtures import SettingsWrapper

POD_ROOT = Path(__file__).resolve().parents[1]
POD_NAME = "identity-admin"
POD_APP_LABEL = "identity_admin"

# --- ia-20 상수(설계 D4 표 · data-model §1–§3 · C24) ----------------------------------------------------------------------

GRADE_B_TABLES = ("tenant", "tenant_membership", "session_revocation_log")
CHECK_RLS_OK = re.compile(r"check_rls: OK - A 등급 (\d+) · B 등급 (\d+) · 프레임워크 (\d+)")
# 제약 이름 → pg_constraint.contype(u = unique · c = check). PG 18은 NOT NULL도 pg_constraint에 두므로 ⊇로 본다.
EXPECTED_CONSTRAINTS: dict[str, dict[str, str]] = {
    "tenant": {
        "tenant_slug_uniq": "u",
        "tenant_slug_format": "c",
        "tenant_display_name_nonempty": "c",
        "tenant_status_valid": "c",
    },
    "tenant_membership": {
        "tenant_membership_sub_tenant_uniq": "u",
        "tenant_membership_role_valid": "c",
    },
    "session_revocation_log": {
        "srl_event_pk_uniq": "u",
        "srl_reason_valid": "c",
    },
}
# 인덱스 이름 → pg_get_indexdef의 「USING …」 꼬리(재적용 · purge의 expires_at · 세션 하한의 sub별 최댓값 — D29).
EXPECTED_INDEX_TAILS = {
    "srl_expires_at_idx": "USING btree (expires_at)",
    "srl_user_floor_idx": "USING btree (sub, nbf DESC) WHERE (sid IS NULL)",
}
UUID_VERSION = 7
# 0001_initial의 꼴(D5 — makemigrations 산출 그대로: core 0001과 엮이지 않는다 · 손 SQL · RunPython 0).
INITIAL_MIGRATION = (POD_APP_LABEL, "0001_initial")
INITIAL_OPERATIONS = ["CreateModel", "CreateModel", "CreateModel"]
# 계약의 reason 다섯 값(data-model §3 — tenant_suspended 포함 · 양성 대조).
CONTRACT_REASONS = ("logout", "logout_all", "admin", "authentik_webhook", "tenant_suspended")

# --- ia-23 상수(설계 D6 · contracts/identity-admin-api.md §identity-admin 전용 설정) ---------------------------------------

OUTBOUND_EXEMPTABLE = ("AUTHENTIK_API_TOKEN", "OPENFGA_STORE_ID", "OPENFGA_PRESHARED_KEY")
INBOUND_NOT_EXEMPTABLE = ("AUTHENTIK_WEBHOOK_SECRET", "AUTHENTIK_JWKS_URL", "AUTHENTIK_ISSUER")
EXEMPT_ENV = "JT_PLACEHOLDER_EXEMPT"
# conf.PLACEHOLDER_MARK(`PLACEHOLDER-`)를 담은 자리값 — 숫자를 넣지 않는다(gitleaks · 설계 X33).
PLACEHOLDER = "PLACEHOLDER-SET-BY-OPERATOR"
WEBHOOK_SECRET_MIN = 32
SERVICE_URLS = {
    "AUTHENTIK_API_URL": "http://authentik-server.identity.svc:9000",
    "OPENFGA_API_URL": "http://openfga.identity.svc:8080",
}
URL_DEFECTS = ("userinfo", "query", "fragment", "path")
# ⑦ settings 노출 7(설계 D6) — 래퍼 env 값과 같아야 하는 여섯 + 쓰기 플래그(래퍼가 env를 지운다 → 기본 False · bool).
IA_ENV_SETTINGS = (
    "AUTHENTIK_API_URL",
    "AUTHENTIK_API_TOKEN",
    "AUTHENTIK_WEBHOOK_SECRET",
    "OPENFGA_API_URL",
    "OPENFGA_STORE_ID",
    "OPENFGA_PRESHARED_KEY",
)
WRITES_FLAG = "AUTHENTIK_WRITES_ENABLED"
IA_SECRETS = ("AUTHENTIK_API_TOKEN", "AUTHENTIK_WEBHOOK_SECRET", "OPENFGA_PRESHARED_KEY")
REFUSAL_PREFIX = "설정 오류: "  # conf의 거부 문구 앞머리(이름만 싣는다)
# ⑨ 비밀 값에 덧붙이거나 끼우는 글자 — 줄바꿈(YAML 블록 스칼라의 끝 줄바꿈) · 공백 · 보이지 않는 비ASCII(U+200B 폭 없는 공백).
LF = chr(0x0A)
CR = chr(0x0D)
TAB = chr(0x09)
ZERO_WIDTH_SPACE = chr(0x200B)
NO_BREAK_SPACE = chr(0xA0)  # 2V-2 — Unicode 공백(isprintable 거짓 · isspace 참)
HANGUL_LETTER = chr(0xD55C)  # 2V-2 — 보이는 비ASCII(isprintable 참 — 「출력 가능」만 보는 판정은 받는다)
LATIN1_LETTER = chr(0xE9)  # 2V-2 — U+0100 아래의 보이는 비ASCII(latin-1로 인코딩된다 — 헤더에 그대로 실릴 수 있다)
# ⑩ 서비스 기준 URL — netloc이 `호스트[:포트]` 꼴이 아니어서 거부되는 값과 통과하는 값(호스트 · 포트 말고는 기준 URL 꼴을 지킨다).
BACKSLASH = chr(0x5C)
SERVICE_URL_REFUSED = (
    "http://auth%2ejoshuatech%2edev",  # urllib.request가 호스트를 unquote해 공개 호스트로 붙는다(FR-046)
    "http://svc%2eidentity:9000",
    "http://host:",  # 빈 포트
    "http://host:0",
    "http://host:99999",
    "http://[::1]:8080",  # IPv6 리터럴(계약 값은 svc DNS 이름이다)
    "http://host;x",
    f"http://host{BACKSLASH}evil.svc",
    "http://a_b",  # 2V-2 — 호스트 글자 밖(`_`)
    "http://host~x",  # 2V-2 — 호스트 글자 밖(`~`)
)
SERVICE_URL_ACCEPTED = (
    "http://authentik-server.identity.svc:9000",
    "http://127.0.0.1:8080/",
    "HTTPS://Host-1.identity.svc",
)

# --- ia-24 상수 ---------------------------------------------------------------------------------------------------------

ACL_FILE = POD_ROOT / "compose" / "dragonfly-dev.acl"
# T066 수용 시험의 ACL 사용자(identity-admin-test) 규칙 사본 — ia-24가 AST로 읽어 같은 값인지 본다(T075 수정 라운드 1 RB-6 · import하지 않는다).
TEST_API_FILE = POD_ROOT / "tests" / "test_api.py"
# contracts/denylist.md §ACL identity-admin 행 그대로(T066 IA_DRAGONFLY_RULES와 같은 값 — 시험이 specs 경로를 읽지 않게). 꼬리
# `-@admin -@dangerous -client`는 T075 UD-9(B2 — ACL SETUSER · CONFIG · FLUSHALL · CLIENT KILL 등을 막는다).
IA_DRAGONFLY_RULES = ("~revoked:*", "~identity-admin:*", "+@all", "-@admin", "-@dangerous", "-client")
# compose aclfile 전체 정본(T075 수정 라운드 2 RB2-1 — 템플릿 gen-39 check_aclfile_exact의 identity-admin 짝): default 줄(꺼짐 · AUTH ·
# HELLO만) · admin 줄(시험 픽스처용 슈퍼유저 · 채널 &*) · identity-admin 줄(IA_DRAGONFLY_RULES) — 이 순서 · LF · 끝 LF 하나 · 다른 USER 줄 0.
# default 줄을 지우거나 켜거나(`ON nopass ~* &* +@all`) 슈퍼유저 줄을 더하면 인증 없이 모든 명령이 열린다.
IA_ACLFILE_TEXT = (
    "USER default OFF +auth +hello\n"
    "USER admin ON nopass ~* &* +@all\n"
    f"USER {POD_NAME} ON nopass {' '.join(IA_DRAGONFLY_RULES)}\n"
)
# 손 수정 ⑩(tests/conftest.py)이 pytest 단언 재작성에 더한 ia 도우미 모듈 — 재작성된 모듈에만 pytest가 넣는 전역 이름 @pytest_ar가
# 있다(템플릿 tests/test_logging.py의 REWRITTEN_HELPERS와 같은 방식 · fix-6 K4).
IA_REWRITTEN_HELPERS = ("tests._ia_support", "tests._ia_fakes")

# --- ia-18 상수(설계 D23 · contracts/gitops-repo.md 「pod마다 ExternalSecret 2개」 행) ---------------------------------------

IA18_ES_FILE = POD_ROOT / "deploy" / "base" / "externalsecret-env.yaml"
IA18_CONFIGMAP_FILE = POD_ROOT / "deploy" / "base" / "configmap.yaml"
IA18_ENV_EXAMPLE = POD_ROOT / "env.example"
# data[0..7] = 순정 생성 커밋(조각 ⓪)의 순서 그대로 — (secretKey, remoteRef.key, remoteRef.property). prod overlay의 인덱스 replace가
# 앞에 `op: test`(secretKey)를 두므로 순번이 바뀌면 overlay 렌더가 깨진다(새 항목은 끝에만 덧붙인다).
GENERATED_ES_DATA = (
    ("db_username", "dev/db/dev_identity_admin/app", "username"),
    ("db_password", "dev/db/dev_identity_admin/app", "password"),
    ("kafka_password", "dev/kafka/identity-admin", "password"),
    ("dragonfly_url", "dev/dragonfly/identity-admin", "url"),
    ("authentik_issuer", "dev/authentik/identity-admin", "issuer"),
    ("authentik_jwks_url", "dev/authentik/identity-admin", "jwks_url"),
    ("sentry_dsn", "dev/sentry/identity-admin", "dsn"),
    ("secret_key", "dev/django/identity-admin", "secret_key"),
)
# data[8..11] = 설계 D23 표 — (secretKey, remoteRef.key, remoteRef.property, template.data의 env 이름). client_id · client_secret은
# 매핑하지 않는다(pod에 그 설정이 없다 — C26).
IA_ES_DATA = (
    ("authentik_api_token", "dev/authentik/identity-admin", "api_token", "AUTHENTIK_API_TOKEN"),
    ("authentik_webhook_secret", "dev/authentik/webhooks/identity-admin", "secret", "AUTHENTIK_WEBHOOK_SECRET"),
    ("openfga_store_id", "dev/openfga/store_id", "store_id", "OPENFGA_STORE_ID"),
    ("openfga_preshared_key", "dev/openfga/preshared", "key", "OPENFGA_PRESHARED_KEY"),
)
ES_STORE = ("ClusterSecretStore", "vault-dev")  # base = dev(prod overlay가 store와 키 접두를 바꾼다)
ES_KEY_PREFIX = "dev/"
TEMPLATE_REFERENCE = re.compile(r"\{\{-?\s*\.([A-Za-z_][A-Za-z0-9_]*)")  # ESO 템플릿 v2의 `{{ .<secretKey> … }}`
# base ConfigMap — 쓰기 플래그는 늘 명시 문자열(빈 값 · 따옴표 없는 불린 금지) · 서비스 기준 URL 둘은 두지 않는다(기본값 = svc DNS ·
# 포트가 바뀌면 overlay가 키를 더한다).
WRITES_FLAG_BASE = "false"
CONFIGMAP_ABSENT = ("AUTHENTIK_API_URL", "OPENFGA_API_URL")
# env.example에 두지 않는 RuntimeEnv 필드 — 클러스터가 주는 값(downward API) · 런타임에 두지 않는 값 · 면제 env(템플릿 env.example도
# 같은 넷을 뺀다)
ENV_EXAMPLE_EXEMPT = frozenset({"POD_IP", "POD_NAMESPACE", "DATABASE_OWNER_URL", "JT_PLACEHOLDER_EXEMPT"})
# env.example의 주석 · 빈 줄 밖의 줄 꼴 = 키만(값 없음 — fullmatch) · 두지 않는 키(migrate Job 전용 — contracts/pod-template.md
# §생성 트리 env.example 행). 템플릿 하네스의 같은 검사(check_env_example)는 sample-pod에만 돈다(fix-6 K3).
ENV_EXAMPLE_KEY_ONLY = re.compile(r"[A-Z][A-Z0-9_]*=")
ENV_EXAMPLE_FORBIDDEN = frozenset({"DATABASE_OWNER_URL"})


def _kebab(name: str) -> str:
    return name.lower().replace("_", "-")


# --- ia-20 ------------------------------------------------------------------------------------------------------------


def _owner_rows(query: str, params: list[object]) -> list[tuple[object, ...]]:
    from django.db import connections

    with connections[OWNER_ALIAS].cursor() as cursor:
        cursor.execute(query, params)
        return list(cursor.fetchall())


@DB
def test_ia_20_grade_b_tables_catalog_and_uuid7() -> None:
    """ia-20 — 모듈 독스트링(B 등급 셋 · RLS 꺼짐 · check_rls B ≥ 4 · 제약 · 인덱스 이름 · ORM create의 pk · UUID v7)."""
    from django.core.management import call_command
    from django_common.tenancy import GlobalModel, check_rls

    models = {table: model(table) for table in GRADE_B_TABLES}
    shapes = {table: (found._meta.app_label, issubclass(found, GlobalModel)) for table, found in models.items()}
    assert shapes == dict.fromkeys(GRADE_B_TABLES, (POD_APP_LABEL, True)), f"모델 앱 라벨 · B 등급 표식 {shapes}"

    flags = {
        name: (enabled, forced)
        for name, enabled, forced in _owner_rows(
            "SELECT c.relname, c.relrowsecurity, c.relforcerowsecurity FROM pg_catalog.pg_class c"
            " JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
            " WHERE n.nspname = 'public' AND c.relkind = 'r' AND c.relname = ANY(%s)",
            [list(GRADE_B_TABLES)],
        )
    }
    assert flags == dict.fromkeys(GRADE_B_TABLES, (False, False)), f"B 등급 표의 RLS(ENABLE, FORCE) {flags}"

    violations = check_rls(using=OWNER_ALIAS)
    assert violations == [], f"check_rls 위반 {violations}"
    out = io.StringIO()
    call_command("check_rls", database=OWNER_ALIAS, stdout=out)
    match = CHECK_RLS_OK.fullmatch(out.getvalue().strip())
    assert match is not None, "check_rls 성공 줄이 계약 꼴이 아니다"
    grade_b = int(match.group(2))
    assert grade_b >= 1 + len(GRADE_B_TABLES), f"check_rls B 등급 수 {grade_b}(기대 >= 4 - outbox + 셋)"

    for table, expected in EXPECTED_CONSTRAINTS.items():
        found = {
            str(name): str(kind)
            for name, kind in _owner_rows(
                "SELECT conname, contype FROM pg_catalog.pg_constraint WHERE conrelid = %s::regclass",
                [f"public.{table}"],
            )
        }
        missing = {name: kind for name, kind in expected.items() if found.get(name) != kind}
        assert missing == {}, f"{table}: 카탈로그에 없거나 종류가 다른 제약 {sorted(missing)}"
    indexes = {
        str(name): str(definition)
        for name, definition in _owner_rows(
            "SELECT indexname, indexdef FROM pg_catalog.pg_indexes WHERE schemaname = 'public' AND tablename = %s",
            ["session_revocation_log"],
        )
    }
    wrong = sorted(name for name, tail in EXPECTED_INDEX_TAILS.items() if not indexes.get(name, "").endswith(tail))
    assert wrong == [], f"session_revocation_log: 없거나 꼴이 다른 인덱스 {wrong}"

    # VD-T073-3: 업무 필드만으로 ORM create(app role · default 별칭) → pk · created_at이 RETURNING으로 채워지고(refresh 없이 —
    # 저장 전 값 DatabaseDefault는 None이 아니므로 형으로 본다) id는 UUID v7이다.
    now = db_now()
    tenant = models["tenant"].objects.create(slug="ia-twenty", display_name="IA Twenty")
    membership = models["tenant_membership"].objects.create(tenant_id=tenant.pk, sub="ia-20-sub", role="owner")
    log = models["session_revocation_log"].objects.create(
        tenant_id=tenant.pk,
        sub="ia-20-sub",
        reason="logout_all",
        nbf=now,
        expires_at=now + timedelta(seconds=330),
    )
    created = {"tenant": tenant, "tenant_membership": membership, "session_revocation_log": log}
    filled = {
        table: (isinstance(row.pk, uuid.UUID), isinstance(row.created_at, datetime)) for table, row in created.items()
    }
    assert filled == dict.fromkeys(GRADE_B_TABLES, (True, True)), f"create 뒤 (pk UUID, created_at datetime) {filled}"
    tenant_shape = (tenant.status, isinstance(tenant.updated_at, datetime))
    assert tenant_shape == ("active", True), f"tenant (status, updated_at datetime) {tenant_shape}"
    versions = {  # 표 이름은 위 상수(GRADE_B_TABLES)뿐이다
        table: _owner_rows(f"SELECT uuid_extract_version(id) FROM {table} WHERE id = %s", [row.pk])  # noqa: S608
        for table, row in created.items()
    }
    assert versions == dict.fromkeys(GRADE_B_TABLES, [(UUID_VERSION,)]), f"uuid_extract_version(id) {versions}"


def _violated_constraint(table: str, fields: Mapping[str, Any]) -> str | None:
    """owner 별칭으로 table에 행 하나를 넣는다 → 위반한 제약 이름(IntegrityError의 psycopg 원인 diag.constraint_name) · 들어가면
    None. 사례마다 transaction.atomic(using=owner)로 감싼다 — DB 마크(transaction=True) 아래에서는 바깥 블록이 없어 이 블록이 곧
    트랜잭션이고, 위반이면 롤백되어 다음 사례가 깨진 트랜잭션을 물려받지 않는다. 예외 문구 · DETAIL(행 값)은 버린다."""
    from django.db import IntegrityError, transaction

    failure: IntegrityError | None = None
    try:
        with transaction.atomic(using=OWNER_ALIAS):
            model(table).objects.using(OWNER_ALIAS).create(**fields)
    except IntegrityError as exc:
        failure = exc
    if failure is None:
        return None
    constraint = getattr(getattr(failure.__cause__, "diag", None), "constraint_name", None)
    return str(constraint) if constraint else "<제약 이름 없음>"


@DB
def test_ia_20_check_constraints_reject_by_name() -> None:
    """ia-20(F10) — 제약 식: 위반 행 → 그 제약 이름의 IntegrityError(대문자 슬러그 → tenant_slug_format · 빈 표시 이름 →
    tenant_display_name_nonempty · 모르는 상태 → tenant_status_valid · 모르는 역할(SP-2 예약 admin) →
    tenant_membership_role_valid · 모르는 reason → srl_reason_valid) / 양성: 계약의 reason 다섯 값은 모두 들어간다."""
    now = db_now(OWNER_ALIAS)
    tenant_id = uuid.uuid4()

    def log(reason: str, sub: str) -> dict[str, Any]:
        return {
            "tenant_id": tenant_id,
            "sub": sub,
            "reason": reason,
            "nbf": now,
            "expires_at": now + timedelta(seconds=330),
        }

    cases: dict[str, tuple[str, dict[str, Any]]] = {
        "tenant_slug_format": ("tenant", {"slug": "Ia-Upper", "display_name": "IA Upper"}),
        "tenant_display_name_nonempty": ("tenant", {"slug": "ia-empty-name", "display_name": ""}),
        "tenant_status_valid": ("tenant", {"slug": "ia-status", "display_name": "IA Status", "status": "archived"}),
        "tenant_membership_role_valid": (
            "tenant_membership",
            {"tenant_id": tenant_id, "sub": "ia-20-role", "role": "admin"},
        ),
        "srl_reason_valid": ("session_revocation_log", log("expired", "ia-20-reason")),
    }
    violated = {expected: _violated_constraint(table, fields) for expected, (table, fields) in cases.items()}
    assert violated == {name: name for name in cases}, f"위반 행이 걸린 제약(기대 = 사례 이름) {violated}"
    accepted = {
        reason: _violated_constraint("session_revocation_log", log(reason, f"ia-20-{reason}"))
        for reason in CONTRACT_REASONS
    }
    assert accepted == dict.fromkeys(CONTRACT_REASONS), f"계약 reason 값이 걸린 제약 {accepted}"


def test_ia_20_initial_migration_shape() -> None:
    """ia-20(F10 · 정적 · DB 없음) — identity_admin 0001_initial의 dependencies == [] · operations == CreateModel 셋뿐(D5:
    core 0001과 엮이면 `migrate core zero`가 세 표를 지웠다 다시 만든다 · makemigrations --check는 dependencies · RunSQL을 보지
    않는다)."""
    from django.db.migrations.loader import MigrationLoader

    migration = MigrationLoader(None, ignore_no_migrations=True).disk_migrations[INITIAL_MIGRATION]
    shape = (list(migration.dependencies), [type(operation).__name__ for operation in migration.operations])
    assert shape == ([], INITIAL_OPERATIONS), f"0001_initial (dependencies, operations) {shape}"


# --- ia-23 ------------------------------------------------------------------------------------------------------------


def _placeholder_value(name: str) -> str:
    """name 자리의 자리값 — 그 이름의 다른 규칙(URL 꼴 · 길이)은 지나고 게이트 2만 걸리는 꼴."""
    if name == "AUTHENTIK_JWKS_URL":
        return f"http://{PLACEHOLDER}.identity.svc:9000/application/o/{POD_NAME}/jwks/"
    if name == "AUTHENTIK_ISSUER":
        return f"https://{PLACEHOLDER}.invalid/application/o/{POD_NAME}/"
    if name == "AUTHENTIK_WEBHOOK_SECRET":
        return f"{PLACEHOLDER}-WEBHOOK-SECRET"  # 32자 이상(길이 규칙은 지난다)
    return PLACEHOLDER


def test_ia_23_outbound_placeholders_exempt_only_with_env() -> None:
    """ia-23 ① · ② — 나가는 쪽 자격 셋에 자리값 + JT_PLACEHOLDER_EXEMPT = 그 셋 → 종료 0(위생) / 같은 자리값에 면제 env 없음 →
    기동 거부 · 거부 이름 = 그 셋(정확히)."""
    placeholders = {name: _placeholder_value(name) for name in OUTBOUND_EXEMPTABLE}
    exempted = boot({**placeholders, EXEMPT_ENV: ",".join(OUTBOUND_EXEMPTABLE)})
    facts = boot_facts(exempted)
    assert facts["profile"] == "runtime"
    refused = boot(placeholders)
    assert_refused(refused, *OUTBOUND_EXEMPTABLE)


def test_ia_23_inbound_placeholders_not_exemptable() -> None:
    """ia-23 ③ — 양성 대조(같은 준비물 · 나가는 쪽 이름 하나를 자리값 + 면제 → 종료 0)를 먼저 단언하고, 들어오는 쪽 검증 값
    셋(웹훅 비밀 · JWKS URL · ISSUER)은 하나씩 자리값 + 그 이름으로 면제 요청 → 거부 이름 = 그 이름 + JT_PLACEHOLDER_EXEMPT."""
    control = boot({"AUTHENTIK_API_TOKEN": PLACEHOLDER, EXEMPT_ENV: "AUTHENTIK_API_TOKEN"})
    boot_facts(control)
    for name in INBOUND_NOT_EXEMPTABLE:
        result = boot({name: _placeholder_value(name), EXEMPT_ENV: name})
        assert_refused(result, name, EXEMPT_ENV)


def test_ia_23_exemptable_constant_is_outbound_three() -> None:
    """ia-23 ④ — conf.PLACEHOLDER_EXEMPTABLE == 나가는 쪽 자격 셋(정확 일치 — 닫힌 상한 · 들어오는 쪽 값은 넣지 않는다)."""
    conf = importlib.import_module("identity_admin.conf")
    exemptable = conf.PLACEHOLDER_EXEMPTABLE
    assert exemptable == frozenset(OUTBOUND_EXEMPTABLE)


def test_ia_23_webhook_secret_minimum_length() -> None:
    """ia-23 ⑤ — AUTHENTIK_WEBHOOK_SECRET 31자 → 기동 거부(그 이름만) / 32자 → 종료 0(웹훅은 HMAC 하나로 지킨다 — D6 〔Y21〕)."""
    secret = secrets.token_urlsafe(WEBHOOK_SECRET_MIN)
    short = boot({"AUTHENTIK_WEBHOOK_SECRET": secret[: WEBHOOK_SECRET_MIN - 1]})
    assert_refused(short, "AUTHENTIK_WEBHOOK_SECRET")
    exact = boot({"AUTHENTIK_WEBHOOK_SECRET": secret[:WEBHOOK_SECRET_MIN]})
    boot_facts(exact)


def _url_defect(base: str, defect: str) -> str:
    if defect == "userinfo":
        return base.replace("://", f"://ia-user:{secrets.token_urlsafe(12)}@", 1)
    if defect == "query":
        return f"{base}?page=next"
    if defect == "fragment":
        return f"{base}#part"
    return f"{base}/api"


@pytest.mark.parametrize("name", sorted(SERVICE_URLS), ids=_kebab)
def test_ia_23_service_base_url_shape(name: str) -> None:
    """ia-23 ⑥ — 양성 대조: 기본 URL + `/` 경로 → 종료 0 / 같은 URL에 사용자 정보 · 쿼리 · 조각 · 경로(`/api`)가 들면 각각 기동
    거부 · 거부 이름 = 그 설정만(스킴 · 호스트는 클러스터 안 그대로 — 공개 도메인 규칙과 섞이지 않는다)."""
    base = SERVICE_URLS[name]
    accepted = boot({name: f"{base}/"})
    boot_facts(accepted)
    for defect in URL_DEFECTS:
        result = boot({name: _url_defect(base, defect)})
        names = refused_names(result)
        assert names == [name], f"{name}: {defect}이 든 URL의 거부 이름 {names}(기대 [{name}]) - {result.summary()}"
        assert_refused(result, name)


# --- ia-23 in-process(conf.load(environ=…) — 하위 프로세스 없음 · fix-2) ------------------------------------------------------


def _wrapper_environ() -> dict[str, str]:
    """래퍼(tests/settings.py)가 채운 설정 env — conf.load(environ=…)가 그대로 통과하는 기준 매핑. 래퍼 상수 POD_SETTINGS_ENV의
    이름만 싣는다(개발자 셸의 다른 env는 섞지 않는다 — 템플릿 test_auth_middleware._wrapper_environ과 같은 꼴). 비밀이 든다 —
    단언 식 안에 두지 않는다."""
    from django.conf import settings

    return {name: os.environ[name] for name in settings.POD_SETTINGS_ENV if name in os.environ}


def _load(environ: Mapping[str, str]) -> tuple[Any, list[str] | None]:
    """conf.load(environ=environ) → (LoadedSettings, None) · 거부면 (None, 거부 이름 정렬 — 중복은 그대로 둔다). 거부 문구가
    「설정 오류: <이름들>」 꼴이 아니거나 연쇄 예외가 있으면 실패한다(문구는 단언 메시지에 싣지 않는다)."""
    from django.core.exceptions import ImproperlyConfigured

    conf = importlib.import_module("identity_admin.conf")
    loaded: Any = None
    refused: ImproperlyConfigured | None = None
    try:
        loaded = conf.load(environ=environ)
    except ImproperlyConfigured as exc:
        refused = exc
    if refused is None:
        return loaded, None
    text = str(refused)
    shaped = text.startswith(REFUSAL_PREFIX) and (refused.__cause__, refused.__context__) == (None, None)
    assert shaped, "거부가 「설정 오류: <이름들>」 꼴이 아니거나 연쇄 예외가 있다"
    return None, sorted(part.strip() for part in text.removeprefix(REFUSAL_PREFIX).split(","))


def test_ia_23_settings_expose_identity_seven() -> None:
    """ia-23 ⑦(F1) — django.conf.settings(래퍼 = pod 설정 star-import)에 전용 설정 일곱이 있고 값이 래퍼 env와 같다(비밀 셋 ·
    store id · URL 둘 = os.environ 값 · 쓰기 플래그 = bool False) · conf.RuntimeEnv repr에 비밀 셋의 값이 없다. 비교는 단언 밖에서
    하고 어긋난 이름만 단언한다(비밀을 단언 식에 두지 않는다 — build-notes R0-2)."""
    from django.conf import settings

    conf = importlib.import_module("identity_admin.conf")
    missing = object()
    observed = {name: getattr(settings, name, missing) for name in IA_ENV_SETTINGS}
    mismatched = sorted(
        name
        for name in IA_ENV_SETTINGS
        if name not in os.environ or not isinstance(observed[name], str) or observed[name] != os.environ[name]
    )
    if getattr(settings, WRITES_FLAG, missing) is not False:
        mismatched.append(WRITES_FLAG)
    assert mismatched == [], f"settings 노출이 래퍼 env 값과 다르거나 없는 이름 {mismatched}"
    model_repr = repr(conf.RuntimeEnv())
    leaked = [name for name in IA_SECRETS if Secret(os.environ[name]) in model_repr]
    assert leaked == [], f"RuntimeEnv repr에 값이 실린 비밀 {leaked}"


def test_ia_23_writes_flag_string_parsing() -> None:
    """ia-23 ⑧(F2) — AUTHENTIK_WRITES_ENABLED의 env 문자열 해석: "false" → False · "true" → True(bool) · env 없음 →
    False(fail-safe) · "" · "False "(끝 공백) → 거부 이름 = 그 설정 하나(계약: ConfigMap은 늘 명시 문자열 · 빈 문자열은 기동
    실패)."""
    base = _wrapper_environ()
    absent = WRITES_FLAG not in base
    assert absent, "기준 매핑에 쓰기 플래그가 있다(래퍼는 그 env를 지운다 - env 없음 사례의 전제)"
    observed: dict[str, tuple[str, object]] = {}
    values = (("false", "false"), ("true", "true"), ("absent", None), ("empty", ""), ("trailing-space", "False "))
    for case, value in values:
        loaded, refused = _load(base if value is None else {**base, WRITES_FLAG: value})
        flag = None if loaded is None else loaded.runtime.AUTHENTIK_WRITES_ENABLED
        observed[case] = ("refused", refused) if loaded is None else (type(flag).__name__, flag)
    expected = {
        "false": ("bool", False),
        "true": ("bool", True),
        "absent": ("bool", False),
        "empty": ("refused", [WRITES_FLAG]),
        "trailing-space": ("refused", [WRITES_FLAG]),
    }
    assert observed == expected


def test_ia_23_secrets_printable_ascii() -> None:
    """ia-23 ⑨(F6) — 비밀 셋(AUTHENTIK_API_TOKEN · AUTHENTIK_WEBHOOK_SECRET · OPENFGA_PRESHARED_KEY)은 공백 없는 출력 가능 ASCII:
    웹훅 31자 + LF(줄바꿈이 32자째로 세어져 길이 규칙을 넘는 꼴) · 43자 + LF · 토큰 + LF · preshared + CRLF · 토큰 가운데 공백 ·
    토큰에 비ASCII 한 글자(U+200B · 한글 · U+00E9) · U+00A0 · 앞 공백 · 가운데 탭(2V-2) → 거부 이름 = 그 설정 하나 / 양성 대조:
    덧붙이거나 끼운 글자를 뺀 값 → 통과(31자 + LF는 길이
    규칙 때문에 LF 자리를 출력 가능 글자로 바꾼 32자). 웹훅 20자 + LF(길이 · 글자 규칙 둘 다 어김) → 이름은 한 번만. 값은 시험이
    만든 난수다(단언 식 · 메시지에 값을 두지 않는다)."""
    base = _wrapper_environ()
    webhook, token, preshared = "AUTHENTIK_WEBHOOK_SECRET", "AUTHENTIK_API_TOKEN", "OPENFGA_PRESHARED_KEY"
    cases: dict[str, tuple[str, str, str]] = {}  # 사례 → (설정 이름, 결함 값, 양성 대조 값)
    value = secrets.token_urlsafe(32)
    cases["webhook-31-lf"] = (webhook, value[:31] + LF, value[:32])
    value = secrets.token_urlsafe(32)
    cases["webhook-43-lf"] = (webhook, value + LF, value)
    value = secrets.token_urlsafe(32)
    cases["token-lf"] = (token, value + LF, value)
    value = secrets.token_urlsafe(32)
    cases["preshared-crlf"] = (preshared, value + CR + LF, value)
    value = secrets.token_urlsafe(32)
    cases["token-inner-space"] = (token, value[:21] + " " + value[21:], value)
    value = secrets.token_urlsafe(32)
    cases["token-non-ascii"] = (token, value[:21] + ZERO_WIDTH_SPACE + value[21:], value)
    # 2V-2 — 보이는 비ASCII(한글 · latin-1) · Unicode 공백(U+00A0) · 앞 공백 · 가운데 탭: 「출력 가능」만 보거나 판정 전에 앞
    # 공백을 떼는 구현을 가른다.
    value = secrets.token_urlsafe(32)
    cases["token-hangul"] = (token, value[:21] + HANGUL_LETTER + value[21:], value)
    value = secrets.token_urlsafe(32)
    cases["token-latin1"] = (token, value[:21] + LATIN1_LETTER + value[21:], value)
    value = secrets.token_urlsafe(32)
    cases["token-no-break-space"] = (token, value[:21] + NO_BREAK_SPACE + value[21:], value)
    value = secrets.token_urlsafe(32)
    cases["token-leading-space"] = (token, " " + value, value)
    value = secrets.token_urlsafe(32)
    cases["token-tab"] = (token, value[:21] + TAB + value[21:], value)
    observed: dict[str, tuple[list[str] | None, list[str] | None]] = {}
    for case, (name, defect, control) in cases.items():
        observed[case] = (_load({**base, name: defect})[1], _load({**base, name: control})[1])
    expected = {case: ([name], None) for case, (name, _defect, _control) in cases.items()}
    assert observed == expected, "(결함 값의 거부 이름, 양성 대조의 거부 이름)이 기대와 다르다"
    both = _load({**base, webhook: secrets.token_urlsafe(32)[:20] + LF})[1]
    assert both == [webhook], f"길이 · 글자 규칙을 둘 다 어긴 웹훅 비밀의 거부 이름 {both}(기대 [{webhook}] 한 번)"


@pytest.mark.parametrize("name", sorted(SERVICE_URLS), ids=_kebab)
def test_ia_23_service_base_url_host_port(name: str) -> None:
    """ia-23 ⑩(F7) — 서비스 기준 URL의 netloc은 `호스트[:포트]`(호스트 = ASCII 글자 · 숫자 · `.` · `-` · 포트 = ASCII 숫자 1–65535):
    퍼센트 인코딩 호스트(urllib.request가 unquote해 공개 호스트로 붙는다) · 빈 포트 · 포트 0 · 범위 밖 포트 · IPv6 리터럴 · `;` ·
    역슬래시 · 호스트의 `_` · `~`(2V-2) → 거부 이름 = 그 설정 하나 / svc 이름 · 루프백 IP + `/` · 대문자 스킴과 호스트 → 통과."""
    base = _wrapper_environ()
    refused = {value: _load({**base, name: value})[1] for value in SERVICE_URL_REFUSED}
    accepted = {value: _load({**base, name: value})[1] for value in SERVICE_URL_ACCEPTED}
    expected_refused = dict.fromkeys(SERVICE_URL_REFUSED, [name])
    assert refused == expected_refused, f"{name}: 거부돼야 할 값의 거부 이름"
    assert accepted == dict.fromkeys(SERVICE_URL_ACCEPTED), f"{name}: 통과해야 할 값의 거부 이름"


# --- ia-24 ------------------------------------------------------------------------------------------------------------


def _module_constant(path: Path, name: str) -> object:
    """모듈 최상위 `name = <리터럴>`(또는 주석 달린 대입) 하나의 값 — ast.literal_eval. 대입이 정확히 하나가 아니면 AssertionError."""
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=path.name)
    values = [
        node.value
        for node in tree.body
        if (isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == name for t in node.targets))
        or (isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.target.id == name and node.value is not None)
    ]
    assert len(values) == 1, f"{path.name}: 최상위 {name} 대입 수 {len(values)}"
    return ast.literal_eval(values[0])


def test_ia_24_dragonfly_acl_rules_match_contract() -> None:
    """ia-24 — compose aclfile의 `USER identity-admin ON nopass <규칙>` 줄이 정확히 하나이고 그 규칙 토큰 == conftest
    DRAGONFLY_USERS[POD_NAME]에서 resetchannels(첫 토큰)를 뺀 것 == tests/test_api.py의 T066 사본 IA_DRAGONFLY_RULES(AST — 수정 라운드 1
    RB-6: 그 사본만 옛 규칙이면 identity-admin-test 사용자가 B2 꼬리 없이 만들어져 시험이 운영보다 넓은 권한으로 돈다) == contracts/denylist.md
    §ACL identity-admin 행. 수정 라운드 2 RB2-1: aclfile 전체(줄 끝 그대로)가 세 줄 정본 IA_ACLFILE_TEXT(default · admin · identity-admin
    줄 — 순서 · LF · 끝 LF 하나 · 다른 USER 줄 0)와 같다."""
    conftest = importlib.import_module("tests.conftest")
    lines = ACL_FILE.read_text(encoding="utf-8").splitlines()
    users = [line.split() for line in lines if line.split()[:2] == ["USER", POD_NAME]]
    assert len(users) == 1, f"{ACL_FILE.name}: USER {POD_NAME} 줄 수 {len(users)}"
    tokens = users[0]
    assert tokens[2:4] == ["ON", "nopass"], f"{ACL_FILE.name}: USER {POD_NAME} 줄의 상태 · 인증 토큰 {tokens[2:4]}"
    conftest_rules = tuple(conftest.DRAGONFLY_USERS[POD_NAME])
    assert conftest_rules[:1] == ("resetchannels",), f"conftest 규칙 첫 토큰 {conftest_rules[:1]}"
    api_rules = _module_constant(TEST_API_FILE, "IA_DRAGONFLY_RULES")
    observed = {"aclfile": tuple(tokens[4:]), "conftest": conftest_rules[1:], "test_api": api_rules}
    assert observed == {"aclfile": IA_DRAGONFLY_RULES, "conftest": IA_DRAGONFLY_RULES, "test_api": IA_DRAGONFLY_RULES}
    # 줄 끝 그대로 읽는다 — read_text는 CRLF · CR을 LF로 바꿔 끝 줄바꿈 · CR 판정을 가린다
    acl_text = ACL_FILE.read_bytes().decode("utf-8")
    assert acl_text == IA_ACLFILE_TEXT, f"{ACL_FILE.name} 전체가 세 줄 정본(default · admin · {POD_NAME} 줄, 끝 LF 하나)과 다르다"


def test_ia_helper_modules_are_assert_rewritten() -> None:
    """손 수정 ⑩(fix-6 K4) — tests/conftest.py의 register_assert_rewrite에 더한 ia 도우미 둘(tests._ia_support · tests._ia_fakes)이
    pytest 단언 재작성을 받았다(재작성한 단언은 명시 raise라 python -O에도 남는다). 재생성으로 두 이름이 빠지면 여기서 걸린다 —
    tests._ia_support는 conftest의 pytest_plugins로도 재작성 표시를 받으므로(pytest가 플러그인 모듈을 import 앞에 표시한다) 그 이름 하나만
    빠진 경우는 재작성이 그대로라 통과한다(이 노드가 지키는 것은 두 모듈의 재작성 상태다)."""
    plain = [name for name in IA_REWRITTEN_HELPERS if "@pytest_ar" not in vars(importlib.import_module(name))]
    assert plain == [], f"단언 재작성 밖의 ia 도우미 모듈: {plain}"


# --- ia-18(설계 D23 · 조각 ⑥ — 정적: deploy/base · env.example) ----------------------------------------------------------


def _single_document(path: Path, kind: str) -> dict[str, Any]:
    """deploy/base 파일 하나(pyyaml) — 매핑 문서 정확히 하나이고 그 kind."""
    documents = [doc for doc in yaml.safe_load_all(path.read_text(encoding="utf-8")) if doc is not None]
    kinds = [doc.get("kind") if isinstance(doc, dict) else type(doc).__name__ for doc in documents]
    assert kinds == [kind], f"{path.name}: 문서 꼴 {kinds}(기대 {kind} 하나)"
    document: dict[str, Any] = documents[0]
    return document


def test_ia_18_env_externalsecret_order_and_mapping() -> None:
    """ia-18(D23) — ExternalSecret identity-admin-env: data[0..7]이 순정 생성 커밋의 순서 그대로 · data[8..11]이 설계 D23 표와 같다
    (항목 수 12 — client_id · client_secret 없음) · 그 넷의 template.data env 값이 정확히 `{{ .<secretKey> }}` · template.data의 참조
    전부 ⊆ secretKey · store = ClusterSecretStore vault-dev · remoteRef.key 전부 `dev/`로 시작한다. YAML에서 읽는 값은 이름(secretKey ·
    키 경로 · property · env 이름)뿐이다."""
    spec = _single_document(IA18_ES_FILE, "ExternalSecret")["spec"]
    data = [(item["secretKey"], item["remoteRef"]["key"], item["remoteRef"]["property"]) for item in spec["data"]]
    template = spec["target"]["template"]["data"]
    secret_keys = {name for name, _, _ in data}
    referenced = {name for value in template.values() for name in TEMPLATE_REFERENCE.findall(str(value))}
    ia_template = {env: template.get(env) for _, _, _, env in IA_ES_DATA}
    store = (spec["secretStoreRef"]["kind"], spec["secretStoreRef"]["name"])
    off_prefix = [key for _, key, _ in data if not key.startswith(ES_KEY_PREFIX)]

    assert data[:8] == list(GENERATED_ES_DATA)  # 순정 생성 커밋의 순서(overlay 인덱스 패치의 인터페이스)
    assert data[8:] == [row[:3] for row in IA_ES_DATA]  # 설계 D23 표 — 끝에만 덧붙인다
    assert ia_template == {env: "{{ ." + key + " }}" for key, _, _, env in IA_ES_DATA}
    assert (len(referenced) > 0, sorted(referenced - secret_keys)) == (True, [])
    assert (store, off_prefix) == (ES_STORE, [])


def test_ia_18_configmap_writes_flag_and_no_service_urls() -> None:
    """ia-18(D23 · D6 「값 꼴」) — ConfigMap identity-admin-config의 AUTHENTIK_WRITES_ENABLED는 문자열 "false"(따옴표 없는 불린이면
    pyyaml이 bool로 읽는다 — 템플릿 base_configmap_env()의 「값이 전부 문자열」 단언도 함께 걸린다) · AUTHENTIK_API_URL ·
    OPENFGA_API_URL 키는 없다(기본값 = svc DNS — 포트가 바뀌면 overlay가 키를 더한다)."""
    data = _single_document(IA18_CONFIGMAP_FILE, "ConfigMap")["data"]
    flag = data.get(WRITES_FLAG)
    present = [name for name in CONFIGMAP_ABSENT if name in data]

    assert (type(flag).__name__, flag) == ("str", WRITES_FLAG_BASE)
    assert present == []


def test_ia_18_env_example_covers_runtime_fields() -> None:
    """ia-18(D23 · 〔Y8〕) — env.example의 키(주석 · 빈 줄 밖의 `KEY=` 줄) 집합 ⊇ conf.RuntimeEnv 필드 이름 − {POD_IP · POD_NAMESPACE ·
    DATABASE_OWNER_URL · JT_PLACEHOLDER_EXEMPT}. 뺀 넷이 실제 필드 이름인지도 본다(이름이 바뀌어 빼기가 공허해지지 않게).
    fix-6 K3: 주석 · 빈 줄 밖의 모든 줄이 `[A-Z][A-Z0-9_]*=`에 fullmatch(키만 — 값 없음)이고 키에 DATABASE_OWNER_URL이 없다(migrate Job
    전용). 실패 문구에는 줄 번호와 키 이름만 싣는다(값을 찍지 않는다 — 줄 내용을 단언 식에 두지 않는다)."""
    conf = impl("conf")
    fields = set(conf.RuntimeEnv.model_fields)
    lines = IA18_ENV_EXAMPLE.read_text(encoding="utf-8").splitlines()
    numbered = enumerate(lines, start=1)
    entries = [(number, line) for number, line in numbered if line.strip() and not line.lstrip().startswith("#")]
    keys = {line.split("=", 1)[0].strip() for _, line in entries}
    missing = sorted(fields - ENV_EXAMPLE_EXEMPT - keys)
    stale_exempt = sorted(ENV_EXAMPLE_EXEMPT - fields)
    not_key_only = [number for number, line in entries if ENV_EXAMPLE_KEY_ONLY.fullmatch(line) is None]
    forbidden = sorted(keys & ENV_EXAMPLE_FORBIDDEN)

    assert (missing, stale_exempt) == ([], [])
    assert not_key_only == [], f"env.example에서 'KEY='(키만) 꼴이 아닌 줄 번호 {not_key_only}"
    assert forbidden == [], f"env.example에 두지 않는 키(migrate Job 전용) {forbidden}"


# --- ia-19 옆(S9 — 업무 지표의 지연 등록 · 하위 프로세스 · Docker 없음) ------------------------------------------------------

METRICS_MARK = "JT-METRICS "
METRICS_TIMEOUT_S = 120
REVOCATION_METRIC = "session_revocations"  # REGISTRY.collect()의 이름(Counter session_revocations_total — `_total`을 뗀 꼴)
# 자식에게 넘기는 OS env 이름(허용 목록 — 인터프리터 · 소켓 · 임시 파일에 필요한 것만). 설정 env는 래퍼 값(POD_SETTINGS_ENV)만
# 넘긴다 — 실제 process env 전체(개발자 셸의 PROMETHEUS_MULTIPROC_DIR · 프록시 · OTel 등)를 넘기지 않는다.
CHILD_OS_ENV = (
    "PATH",
    "PATHEXT",
    "SYSTEMROOT",
    "SYSTEMDRIVE",
    "WINDIR",
    "COMSPEC",
    "TEMP",
    "TMP",
    "TMPDIR",
    "HOME",
    "USERPROFILE",
    "LANG",
    "LC_ALL",
)
# 자식 본문(앞에 MARK 대입 줄이 붙는다) — django.setup() → urlconf import(→ api → identity_api → revocation →
# identity_metrics 사슬) → 지표 이름 → 지표 함수 첫 호출 → 지표 이름.
_METRICS_BODY = """
import json
import sys

import django
from prometheus_client import REGISTRY


def names():
    return sorted({metric.name for metric in REGISTRY.collect()})


django.setup()
import identity_admin.urls  # noqa: F401

chained = "identity_admin.identity_metrics" in sys.modules
before = names()
from identity_admin import identity_metrics

identity_metrics.session_revocations_total()
after = names()
print(MARK + json.dumps({"chained": chained, "before": before, "after": after}), flush=True)
"""
METRICS_SCRIPT = f"MARK = {METRICS_MARK!r}\n" + _METRICS_BODY


def test_ia_19_revocation_metric_registers_lazily() -> None:
    """ia-19 옆(S9 — 설계 D25 「지표」 · 템플릿 불변식 「relay 레지스트리에 web 지표 없음」): 새 프로세스(pod 설정 · 래퍼 env 값)에서
    `django.setup()` → `import identity_admin.urls`(identity_metrics까지 import되는 사슬 — chained 참이 그 전제다) → 기본
    REGISTRY에 `session_revocations`가 없다 / 양성 대조: `identity_metrics.session_revocations_total()` 호출 뒤 있다. 자식 env =
    OS 허용 목록 + 래퍼 설정 값 + DJANGO_SETTINGS_MODULE(pod 설정) — 실제 process env 전체를 넘기지 않는다."""
    from django.conf import settings

    env = {name: os.environ[name] for name in CHILD_OS_ENV if name in os.environ}
    env.update({name: os.environ[name] for name in settings.POD_SETTINGS_ENV if name in os.environ})
    env.update(DJANGO_SETTINGS_MODULE="identity_admin.settings", PYTHONIOENCODING="utf-8")
    completed: subprocess.CompletedProcess[str] | None
    try:
        completed = subprocess.run(  # noqa: S603 — 인자 고정 · shell 없음 · 이 프로세스의 인터프리터
            [sys.executable, "-c", METRICS_SCRIPT],
            cwd=POD_ROOT,
            env=env,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=METRICS_TIMEOUT_S,
            check=False,
            shell=False,
        )
    except subprocess.TimeoutExpired:
        completed = None  # 실패는 except 밖에서 낸다(명령 줄 · 부분 출력이 연쇄 예외로 실리지 않게)
    if completed is None:
        pytest.fail(f"지표 탐침 프로세스가 {METRICS_TIMEOUT_S} s 안에 끝나지 않았다", pytrace=False)
    returncode = completed.returncode
    marked = [line for line in completed.stdout.splitlines() if line.startswith(METRICS_MARK)]
    stderr_lines = len([line for line in completed.stderr.splitlines() if line.strip()])
    assert (returncode, len(marked)) == (0, 1), f"종료 코드 {returncode} · 표식 줄 {len(marked)} · stderr {stderr_lines}줄"
    facts = json.loads(marked[0][len(METRICS_MARK) :])
    observed = (facts["chained"], REVOCATION_METRIC in facts["before"], REVOCATION_METRIC in facts["after"])

    assert observed == (True, False, True)


# --- ia-22 · ia-41 상수(설계 D20 · D16 · D17 · D26 · contracts/identity-admin-api.md §타임아웃 · 재시도) ----------------------

MIB = 1024 * 1024
JSON_TYPE = "application/json"
USER_AGENT_PRODUCT = "identity-admin"  # User-Agent = identity-admin/<APP_VERSION>(설계 D20 헤더)
BLACKHOLE_WINDOW_S = (4.5, 7.0)  # 「5 s대 오류」 — 소켓 동작마다 5 s(시험의 독립 기대값)
HANG_LIMIT_S_IA22 = 20.0  # 멈춤을 유한한 실패로 바꾸는 상한(성능 요구가 아니다)
SLOW_PIECES, SLOW_DELAY_S = 8, 0.25  # 느린 본문 — 조각 사이 지연 합 (8 - 1) × 0.25 = 1.75 s
SLOW_DEADLINE_S = 0.5
SLOW_STALL_S = 2.0  # 상태 줄 앞 지연 — 소켓 타임아웃이 min(5, 남은 시간)이면 마감에서 끊긴다
SLOW_FULL_MIN_S = 1.6  # 마감 없는 호출은 본문 끝까지 기다린다
SLOW_CUT_MAX_S = 1.2  # 마감 0.5 s에서 끊겼다고 볼 경과 상한(조각 한두 개 + 여유 — 본문 전체 1.75 s보다 작다)
# 4B-5 — 마감으로 줄어든 소켓 타임아웃의 시간 초과(상태 줄이 늦는 응답 + 짧은 마감)를 되풀이하는 횟수 · 마감 · 상태 줄 지연.
REPEAT_COUNT, REPEAT_DEADLINE_S, REPEAT_STALL_S = 20, 0.05, 0.5
# 조각 ⑤-b V4 ②(4V-1) — `_timeout_kind`의 두 절반: 덮은 소켓 타임아웃 · 상태 줄 지연 · 마감이 답하는 남은 시간.
HALVES_SOCKET_TIMEOUT_S, HALVES_STALL_S, HALVES_REMAINING_S = 0.2, 1.0, 60.0
TLS_PROBE_DEADLINE_S = 1.0  # https 짝(닫힌 포트) 호출의 마감 — 핸들러를 만든 뒤 연결 실패 · 마감 어느 쪽이든 일시 오류다
QUERY_ORIGINAL = "a&b #c %d e"  # 질의 값의 & · # · % · 공백(urlencode가 원문 그대로 실어야 한다 — 사실 ㉙)
ENCODED_QUERY = "uuid=a%26b+%23c+%25d+e&page=2"  # {"uuid": QUERY_ORIGINAL, "page": 2}의 urlencode(시험의 독립 기대값)
LONE_SURROGATE = chr(0xD800)  # 4B-4 — utf-8로 인코딩되지 않는 글자(urlencode의 UnicodeEncodeError — repr · args에 값 원문)
INT_SEGMENT_LIMIT = 2**63  # build_url의 int 경로 성분은 이 값 미만만 받는다(4B-4 — 시험의 독립 기대값)
DEEP_BODY_LEVELS = 100_000  # 조각 ⑤-b V2(4V-3) — json.dumps가 RecursionError를 내는 중첩 깊이(재귀 한도보다 충분히 깊다)
CHUNKED_HEADERS = (("Transfer-Encoding", "chunked"), ("Content-Type", "application/json"))
STATUS_ERROR = "UpstreamStatus"
UNAVAILABLE_ERROR = "UpstreamUnavailable"
SESSION_PAGE_LIMIT = 10  # 설계 D16 · D26 authentik.SESSION_PAGE_LIMIT(시험의 독립 기대값)
EVENT_PAGE_LIMIT = 50  # 설계 D17 · D26 authentik.EVENT_PAGE_LIMIT
PAGE_SIZE = "100"  # 목록 질의의 page_size(설계 D16 4 · D17 2)
PAGE_SIZE_COUNT = 100  # 한 쪽 results의 상한(= page_size — 넘으면 malformed · 4B-7)
CORE = "/api/v3/core"
EVENTS = "/api/v3/events/events/"
GROUP_NAME = f"tenant:{QUERY_ORIGINAL}"  # 그룹 이름에 & · # · % · 공백(질의 인코딩)
GROUP_PK = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
DECOY_GROUP_PK = "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"
NEAR_GROUP_PK = "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
UNKNOWN_GROUP_PK = "dddddddd-dddd-4ddd-8ddd-dddddddddddd"
OWNER_UUID = "11111111-1111-4111-8111-111111111111"
MEMBER_UUID = "22222222-2222-4222-8222-222222222222"
DECOY_UUID = "99999999-9999-4999-8999-999999999999"
OWNER_NAME = f"o{QUERY_ORIGINAL}"  # username에 & · # · % · 공백(세션 목록 질의 인코딩)
S1 = "5e551011-0000-4000-8000-000000000001"
S2 = "5e551011-0000-4000-8000-000000000002"
TENANT_ID_VALUE = "0192e4c1-7a00-7000-8000-00000000c0de"
# 미끼가 정답보다 앞에 온다(필터 없이 첫 결과를 쓰는 구현은 미끼를 고른다 — T066 _seed_fakes와 같은 원칙).
IA41_USERS = (
    {"pk": 1, "uuid": DECOY_UUID, "username": "akadmin", "attributes": {"keep": "admin"}},
    {"pk": 101, "uuid": OWNER_UUID, "username": OWNER_NAME, "attributes": {"existing": "keep"}},
    {"pk": 102, "uuid": MEMBER_UUID, "username": "member"},
)
IA41_GROUPS = (
    {"pk": DECOY_GROUP_PK, "name": "authentik Admins", "users": [1], "is_superuser": True},
    {"pk": NEAR_GROUP_PK, "name": f"{GROUP_NAME} x", "users": []},
    {"pk": GROUP_PK, "name": GROUP_NAME, "users": []},
)
# 꼴이 아닌 경로 성분 — 사용자 pk(1 이상 2**63 미만 정수 · bool 제외 — build_url의 int 성분 상한과 같다) · 그룹 pk와 세션
# uuid(UUID 8-4-4-4-12 꼴 문자열).
BAD_PKS: dict[str, Any] = {
    "digits-str": "101",
    "bool": True,
    "zero": 0,
    "negative": -1,
    "float": 1.5,
    "none": None,
    "traversal": "../groups",
    "int-limit": INT_SEGMENT_LIMIT,  # 조각 ⑤-b V1(4V-4) — 상한 밖이면 invalid_request가 아니라 「꼴 아님」(호출 0)이다
}
BAD_UUIDS: dict[str, Any] = {
    "plain": "not-a-uuid",
    "traversal": "../users/101",
    "int": 7,
    "none": None,
    "hex32": "5e551011000040008000000000000001",
    "suffix": f"{S1}/x",
    "braced": "{" + S1 + "}",
}
# 경로 성분 안전 글자(`[A-Za-z0-9_-]{1,64}` · 0 이상 정수) 밖의 값 — build_url이 호출 전에 거부한다.
BAD_SEGMENTS: dict[str, Any] = {
    "dot-dot": "..",
    "slash": "a/b",
    "question": "a?b",
    "hash": "a#b",
    "percent": "a%2fb",
    "space": "a b",
    "empty": "",
    "too-long": "a" * 65,
    "bool": True,
    "negative": -1,
    "float": 1.5,
    "none": None,
    "int-limit": INT_SEGMENT_LIMIT,
}


@pytest.fixture
def ia22_raw() -> Iterator[RawHttpServer]:
    """원시 HTTP 서버 하나(시험마다 새로 띄우고 닫는다 — 응답은 시험이 script로 정한다 · 기본 200 `{}`)."""
    server = RawHttpServer()
    try:
        yield server
    finally:
        server.close()


def _attempt(call: Callable[[], Any]) -> tuple[Any, Exception | None]:
    """call() → (결과, None) · 예외면 (None, 예외). 예외는 값으로 받아 단언 밖에서 본다(트레이스백을 싣지 않는다)."""
    try:
        return call(), None
    except Exception as exc:  # noqa: BLE001 — 예외 종류 · 속성을 값으로 본다
        return None, exc


def _failure(error: BaseException | None) -> tuple[str | None, Any, Any]:
    """(예외 클래스 이름, kind 또는 status, transient) — 예외가 없으면 셋 다 None."""
    if error is None:
        return None, None, None
    detail = getattr(error, "kind", getattr(error, "status", None))
    return type(error).__name__, detail, getattr(error, "transient", None)


def _hygiene(error: BaseException | None, needles: Mapping[str, str]) -> list[str]:
    """오류 위생 위반 목록 — 예외 없음 · outbound 오류 형이 아님 · str · repr · args에 needle(URL · 질의 값 · 토큰 등) · 연쇄 예외
    (`__cause__`가 None이 아님 · `__context__`가 None이 아님 — raise를 except 블록 안으로 옮기면 URL · 질의를 가진 원 예외가
    남는다(4A-5) · `__suppress_context__`가 거짓). needle 값은 싣지 않는다(이름만)."""
    if error is None:
        return ["no-error"]
    problems: list[str] = []
    if type(error).__name__ not in (STATUS_ERROR, UNAVAILABLE_ERROR):
        problems.append(f"type:{type(error).__name__}")
    texts = {"str": str(error), "repr": repr(error), "args": repr(error.args)}
    problems.extend(
        f"{place}:{name}" for place, text in texts.items() for name, needle in needles.items() if needle in text
    )
    if error.__cause__ is not None:
        problems.append("cause")
    if error.__context__ is not None:
        problems.append("context")
    if error.__suppress_context__ is not True:
        problems.append("suppress-context")
    return problems


def _token() -> Secret:
    return Secret(secrets.token_urlsafe(24))


# --- ia-22(D20 — outbound.request_json · build_url) -------------------------------------------------------------------


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_json_reply_and_headers(ia22_raw: RawHttpServer, settings: SettingsWrapper) -> None:
    """ia-22 — 성공 반환과 헤더: 200 JSON → 디코드한 값 · 201 → 값 · 204 · 빈 200 → None / 받은 요청마다 `Authorization: Bearer
    <token>` · `Accept: application/json` · `User-Agent: identity-admin/<APP_VERSION>`(호출 때의 설정 — 시험이 덮은 값) · 본문이
    있는 POST만 `Content-Type: application/json`과 JSON 본문 · 메서드 · 경로 그대로."""
    outbound = impl("outbound")
    token = _token()
    settings.APP_VERSION = "9.9.9-ia22"
    ia22_raw.script(
        RawReply.json({"ok": [1, "two"]}),
        RawReply.json({"made": True}, status=201),
        RawReply(status=204, chunks=()),
        RawReply(chunks=()),
    )
    base = ia22_raw.base_url
    replies = [
        _attempt(lambda: outbound.request_json("GET", f"{base}/api/v3/core/users/", token=token)),
        _attempt(lambda: outbound.request_json("POST", f"{base}/api/v3/core/x/", token=token, body={"pk": 7})),
        _attempt(lambda: outbound.request_json("DELETE", f"{base}/api/v3/core/y/", token=token)),
        _attempt(lambda: outbound.request_json("GET", f"{base}/api/v3/core/z/", token=token)),
    ]
    requests = ia22_raw.requests
    authorized = [request.header("authorization") == f"Bearer {token}" for request in requests]
    shapes = [
        (request.method, request.path, request.header("accept"), request.header("user-agent"))
        for request in requests
    ]
    bodies = [
        (request.header("content-type"), json.loads(request.body) if request.body else None) for request in requests
    ]
    agent = f"{USER_AGENT_PRODUCT}/9.9.9-ia22"

    assert replies == [({"ok": [1, "two"]}, None), ({"made": True}, None), (None, None), (None, None)]
    assert authorized == [True, True, True, True]
    assert shapes == [
        ("GET", "/api/v3/core/users/", JSON_TYPE, agent),
        ("POST", "/api/v3/core/x/", JSON_TYPE, agent),
        ("DELETE", "/api/v3/core/y/", JSON_TYPE, agent),
        ("GET", "/api/v3/core/z/", JSON_TYPE, agent),
    ]
    assert bodies == [(None, None), (JSON_TYPE, {"pk": 7}), (None, None), (None, None)]


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_redirect_is_error_and_not_followed() -> None:
    """ia-22 — 302 + Location(둘째 서버) → UpstreamStatus(302 · transient 거짓)이고 둘째 서버가 받은 요청이 늘지 않는다
    (Authorization이 따라가지 않는다) / 양성 대조(같은 준비물): urllib 기본 opener(build_opener)는 따라가 둘째 서버에
    Authorization을 다시 보낸다(조각 ① 실측 — Python 3.13)."""
    outbound = impl("outbound")
    token = _token()
    with ExitStack() as stack:
        target = RawHttpServer()
        stack.callback(target.close)
        origin = RawHttpServer()
        stack.callback(origin.close)
        location = f"{target.base_url}/landing"
        origin.script(RawReply.redirect(location), RawReply.redirect(location))
        request = urllib.request.Request(f"{origin.base_url}/start", headers={"Authorization": f"Bearer {token}"})
        with urllib.request.build_opener().open(request, timeout=5) as followed:
            followed.read()
        control = (target.count, [item.header("authorization") == f"Bearer {token}" for item in target.requests])
        value, error = _attempt(lambda: outbound.request_json("GET", f"{origin.base_url}/start", token=token))
        after = (target.count, origin.count)

    assert control == (1, [True])
    assert (value, _failure(error)) == (None, (STATUS_ERROR, 302, False))
    assert after == (1, 2)


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_proxy_env_is_ignored(monkeypatch: pytest.MonkeyPatch) -> None:
    """ia-22 — 프록시 env(HTTP_PROXY · http_proxy = 원시 서버 · NO_PROXY 없음)를 둬도 대상에 직접 간다(프록시 count 그대로 ·
    대상 count 1) / 양성 대조(같은 준비물): urllib 기본 opener는 그 프록시 서버를 지난다(프록시 count 1 · 대상 0 — ia73_env의
    NO_PROXY=*를 지우지 않으면 이 대조가 서지 않는다)."""
    outbound = impl("outbound")
    token = _token()
    with ExitStack() as stack:
        proxy = RawHttpServer()
        stack.callback(proxy.close)
        target = RawHttpServer()
        stack.callback(target.close)
        for name in ("NO_PROXY", "no_proxy"):
            monkeypatch.delenv(name, raising=False)
        for name in ("HTTP_PROXY", "http_proxy"):
            monkeypatch.setenv(name, proxy.base_url)
        url = f"{target.base_url}/api/v3/core/users/"
        with urllib.request.build_opener().open(url, timeout=5) as via_proxy:
            via_proxy.read()
        control = (proxy.count, target.count)
        reply = _attempt(lambda: outbound.request_json("GET", url, token=token))
        after = (proxy.count, target.count)

    assert control == (1, 0)
    assert reply == ({}, None)
    assert after == (1, 1)


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_blackhole_times_out_near_5s() -> None:
    """ia-22 — 연결은 받고 응답하지 않는 포트(블랙홀) → 5 s대에 UpstreamUnavailable("timeout" · transient 참) · 오류 위생(URL ·
    토큰 없음 · 연쇄 끊김)."""
    outbound = impl("outbound")
    token = _token()
    with blackhole() as port:
        url = f"http://127.0.0.1:{port}/api/v3/core/users/"
        (value, error), elapsed = timed(
            lambda: _attempt(lambda: outbound.request_json("GET", url, token=token)), HANG_LIMIT_S_IA22
        )
    low, high = BLACKHOLE_WINDOW_S
    problems = _hygiene(error, {"url": url, "token": token, "loopback": "127.0.0.1"})

    assert (value, _failure(error)) == (None, (UNAVAILABLE_ERROR, "timeout", True))
    assert low <= elapsed < high, f"블랙홀 오류까지 {elapsed:.2f} s(기대 {low}-{high} s)"
    assert problems == []


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_deadline_cuts_slow_body(ia22_raw: RawHttpServer) -> None:
    """ia-22 — 조각 사이에 지연을 둔 느린 본문(합 1.75 s): 마감 0.5 s를 주면 본문을 읽는 사이에 끊겨 UpstreamUnavailable
    ("deadline" · transient 참)이 1.2 s 안에 난다 / 상태 줄이 2 s 늦는 응답 + 마감 0.5 s → 소켓 타임아웃이 min(5, 남은 시간)이라
    마감에서 끊겨 "deadline"(1.2 s 안) / 양성 대조(같은 응답 · 마감 없음): 끝까지 읽어 값을 돌려준다(1.6 s 이상). 판정은
    클라이언트 쪽 예외와 경과 시간이다(원시 서버의 errors는 보조)."""
    outbound = impl("outbound")
    token = _token()
    body = json.dumps({"results": list(range(200))}).encode()
    slow = RawReply.slow(body, pieces=SLOW_PIECES, delay_s=SLOW_DELAY_S)
    stalled = RawReply.slow(body, pieces=1, delay_s=0.0, head_delay_s=SLOW_STALL_S)
    ia22_raw.script(slow, slow, stalled)
    url = f"{ia22_raw.base_url}/api/v3/events/events/"

    def with_deadline() -> Any:
        return outbound.request_json("GET", url, token=token, deadline=outbound.Deadline(SLOW_DEADLINE_S))

    (full, full_error), full_s = timed(
        lambda: _attempt(lambda: outbound.request_json("GET", url, token=token)), HANG_LIMIT_S_IA22
    )
    (cut, cut_error), cut_s = timed(lambda: _attempt(with_deadline), HANG_LIMIT_S_IA22)
    (head, head_error), head_s = timed(lambda: _attempt(with_deadline), HANG_LIMIT_S_IA22)
    full_view = (full_error, full == json.loads(body), full_s >= SLOW_FULL_MIN_S)

    assert full_view == (None, True, True)
    assert (cut, _failure(cut_error)) == (None, (UNAVAILABLE_ERROR, "deadline", True))
    assert cut_s < SLOW_CUT_MAX_S, f"마감 {SLOW_DEADLINE_S} s 호출이 {cut_s:.2f} s 뒤에 끝났다"
    assert (head, _failure(head_error)) == (None, (UNAVAILABLE_ERROR, "deadline", True))
    assert head_s < SLOW_CUT_MAX_S, f"상태 줄이 {SLOW_STALL_S} s 늦는 응답에 마감 {SLOW_DEADLINE_S} s 호출이 {head_s:.2f} s"


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_shrunk_socket_timeout_is_deadline(ia22_raw: RawHttpServer, monkeypatch: pytest.MonkeyPatch) -> None:
    """ia-22(4B-5) — 마감을 받아 소켓 타임아웃이 남은 시간으로 줄어 있었으면(< 5 s) 그 시간 초과는 deadline이다: 상태 줄이
    REPEAT_STALL_S 늦는 응답 + 마감 REPEAT_DEADLINE_S를 REPEAT_COUNT회 되풀이해도 종류는 "deadline"(transient 참)뿐이다
    (「시간 초과가 난 뒤 remaining() <= 0인가」만 보는 판정은 대기 단위의 경계에서 timeout으로 뒤집힐 수 있다) / 그 경계의 결정적
    사례: 시계가 멈춘 마감(remaining()이 늘 REPEAT_DEADLINE_S — 줄인 타임아웃이 끊었는데 남은 시간은 아직 양수라고 답한다) →
    "deadline".
    조각 ⑤-b V4 ②(4V-1 — `_timeout_kind`의 두 절반): `outbound.DEFAULT_TIMEOUT_S`를 0.2로 덮고 상태 줄이 1 s 늦는 응답 — 남은
    시간이 늘 60인 마감(소켓 타임아웃이 줄지 않았고 시간 초과 때 마감도 남았다) → "timeout" / 첫 remaining()만 60이고 그 뒤 -1인 마감
    (소켓 타임아웃은 줄지 않았지만 시간 초과 때 마감이 지났다) → "deadline". 소켓 타임아웃이 0.2 s라 5 s를 기다리지 않는다."""
    outbound = impl("outbound")
    token = _token()

    class FrozenDeadline(outbound.Deadline):  # type: ignore[misc, name-defined]
        """남은 시간이 늘 REPEAT_DEADLINE_S인 마감(시계가 멈춘 경계 — 서버는 실물 원시 서버다)."""

        def remaining(self) -> float:
            return REPEAT_DEADLINE_S

    class SteadyDeadline(outbound.Deadline):  # type: ignore[misc, name-defined]
        """남은 시간이 늘 HALVES_REMAINING_S인 마감(넉넉하다)."""

        def remaining(self) -> float:
            return HALVES_REMAINING_S

    class LapsingDeadline(outbound.Deadline):  # type: ignore[misc, name-defined]
        """첫 remaining()만 HALVES_REMAINING_S이고 그 뒤는 -1인 마감(호출 앞에서는 남았고 시간 초과 때는 지났다)."""

        def __init__(self) -> None:
            super().__init__(HALVES_REMAINING_S)
            self.asked = 0

        def remaining(self) -> float:
            self.asked += 1
            return HALVES_REMAINING_S if self.asked == 1 else -1.0

    stalled = RawReply.slow(b"{}", pieces=1, delay_s=0.0, head_delay_s=REPEAT_STALL_S)
    ia22_raw.script(*([stalled] * (REPEAT_COUNT + 1)))
    url = f"{ia22_raw.base_url}/api/v3/core/users/"
    kinds: list[tuple[str | None, Any, Any]] = []
    for _ in range(REPEAT_COUNT):
        _, error = _attempt(
            lambda: outbound.request_json("GET", url, token=token, deadline=outbound.Deadline(REPEAT_DEADLINE_S))
        )
        kinds.append(_failure(error))
    _, frozen_error = _attempt(lambda: outbound.request_json("GET", url, token=token, deadline=FrozenDeadline(0)))
    late = RawReply.slow(b"{}", pieces=1, delay_s=0.0, head_delay_s=HALVES_STALL_S)
    ia22_raw.script(late, late)
    monkeypatch.setattr(outbound, "DEFAULT_TIMEOUT_S", HALVES_SOCKET_TIMEOUT_S)
    _, steady_error = _attempt(lambda: outbound.request_json("GET", url, token=token, deadline=SteadyDeadline(0)))
    _, lapsing_error = _attempt(lambda: outbound.request_json("GET", url, token=token, deadline=LapsingDeadline()))
    halves = (_failure(steady_error), _failure(lapsing_error))

    assert kinds == [(UNAVAILABLE_ERROR, "deadline", True)] * REPEAT_COUNT
    assert _failure(frozen_error) == (UNAVAILABLE_ERROR, "deadline", True)
    assert halves == ((UNAVAILABLE_ERROR, "timeout", True), (UNAVAILABLE_ERROR, "deadline", True))


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_zero_deadline_makes_no_call(ia22_raw: RawHttpServer) -> None:
    """ia-22 — 양성 대조: 같은 서버에 마감 5 s → 1회 닿는다 / 마감 0 s → UpstreamUnavailable("deadline" · transient 참) · 호출 0
    (원시 서버 count 그대로 — 거절한 요청도 센다)."""
    outbound = impl("outbound")
    token = _token()
    url = f"{ia22_raw.base_url}/api/v3/core/users/"
    control = _attempt(lambda: outbound.request_json("GET", url, token=token, deadline=outbound.Deadline(5)))
    control_count = ia22_raw.count
    value, error = _attempt(lambda: outbound.request_json("GET", url, token=token, deadline=outbound.Deadline(0)))

    assert (control, control_count) == (({}, None), 1)
    assert (value, _failure(error), ia22_raw.count) == (None, (UNAVAILABLE_ERROR, "deadline", True), 1)


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_non_http_schemes_make_no_call(ia22_raw: RawHttpServer, tmp_path: Path) -> None:
    """ia-22 — 양성 대조: 원시 서버에 http → 1회 / file(있는 파일) · ftp(같은 포트) · data 스킴 → UpstreamUnavailable("scheme" ·
    transient 거짓) · 호출 0(원시 서버 count 그대로) · 파일 내용을 돌려주지 않는다."""
    outbound = impl("outbound")
    token = _token()
    readable = tmp_path / "ia22.json"
    readable.write_text('{"file": "read"}', encoding="utf-8")
    control = _attempt(lambda: outbound.request_json("GET", f"{ia22_raw.base_url}/api/", token=token))
    control_count = ia22_raw.count
    urls = {
        "file": readable.as_uri(),
        "ftp": f"ftp://127.0.0.1:{ia22_raw.port}/api/",
        "data": "data:application/json,{}",
    }
    refused: dict[str, tuple[Any, tuple[str | None, Any, Any]]] = {}
    for name, url in urls.items():
        value, error = _attempt(lambda url=url: outbound.request_json("GET", url, token=token))
        refused[name] = (value, _failure(error))

    assert (control, control_count) == (({}, None), 1)
    assert refused == dict.fromkeys(urls, (None, (UNAVAILABLE_ERROR, "scheme", False)))
    assert ia22_raw.count == 1


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_hostless_url_is_invalid_request(ia22_raw: RawHttpServer) -> None:
    """ia-22(4B-3) — 호스트 없는 http URL(`http:/x` · `http://` — urllib이 reason이 문자열인 URLError('no host given')를 낸다) →
    UpstreamUnavailable("invalid_request" · transient 거짓 — 다시 해도 같은 입력이다 · 연결 오류로 재시도하지 않는다) · 호출 0 ·
    오류 위생 / 조각 ⑤-b V2(4V-3): 스킴 글자 사이에 탭이 든 URL(`ht<TAB>tp://127.0.0.1:<원시 서버 포트>/x` — urlsplit은 탭을
    지워 http로 읽고 urllib Request는 모르는 스킴으로 읽어 opener.open()이 None을 준다)도 같은 부류다(invalid_request · 호출 0 —
    connection이 아니다) / 양성 대조: 원시 서버에 http → 1회 닿는다."""
    outbound = impl("outbound")
    token = _token()
    control = _attempt(lambda: outbound.request_json("GET", f"{ia22_raw.base_url}/api/", token=token))
    control_count = ia22_raw.count
    urls = {
        "one-slash": "http:/x",
        "empty-host": "http://",
        "tab-in-scheme": "ht" + TAB + f"tp://127.0.0.1:{ia22_raw.port}/x",
    }
    refused: dict[str, tuple[Any, tuple[str | None, Any, Any], list[str]]] = {}
    for name, url in urls.items():
        value, error = _attempt(lambda url=url: outbound.request_json("GET", url, token=token))
        refused[name] = (value, _failure(error), _hygiene(error, {"token": token}))

    assert (control, control_count) == (({}, None), 1)
    assert refused == dict.fromkeys(urls, (None, (UNAVAILABLE_ERROR, "invalid_request", False), []))
    assert ia22_raw.count == 1


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_query_values_and_path_segments(ia22_raw: RawHttpServer) -> None:
    """ia-22 — build_url: 질의 값의 & · # · % · 공백이 원시 서버가 받은 값과 같다(urlencode · 정수 값은 문자열) · 끝 슬래시가 붙은
    기준 URL의 반환 문자열을 글자 그대로 견준다(기준 URL 끝 `/`를 떼 `//api`가 되지 않는다 — 원시 서버는 `//`로 시작하는 경로를
    `/`로 접어 기록하므로 path 단언으로는 갈리지 않는다 · 4A-4) · 경로는 성분을 `/`로 잇고 끝 슬래시(trailing_slash=False면
    없음) · UUID · 정수(2**63 - 1까지) · ULID 꼴 성분은 그대로 / 꼴이 아닌 경로 성분(`..` · `/` · `?` · `#` · `%` · 공백 · 빈 값 ·
    65자 · bool · 음수 · 실수 · None · 2**63) → UpstreamUnavailable("invalid_request" · transient 거짓) · 호출 0."""
    outbound = impl("outbound")
    token = _token()
    base = ia22_raw.base_url
    ulid = "01JC0Q4T7Z9W8X6Y5V4U3T2S1R"
    url = outbound.build_url(f"{base}/", ("api", "v3", "core", "users"), query={"uuid": QUERY_ORIGINAL, "page": 2})
    plain = outbound.build_url(base, ("stores", ulid, "write"), trailing_slash=False)
    mixed = outbound.build_url(base, ("api", 101, S1, INT_SEGMENT_LIMIT - 1))
    reply = _attempt(lambda: outbound.request_json("GET", url, token=token))
    (request,) = ia22_raw.requests
    received = (request.path, request.query)
    refused: dict[str, tuple[Any, tuple[str | None, Any, Any]]] = {}
    for name, segment in BAD_SEGMENTS.items():
        value, error = _attempt(
            lambda segment=segment: outbound.request_json(
                "GET", outbound.build_url(base, ("api", segment)), token=token
            )
        )
        refused[name] = (value, _failure(error))

    assert url == f"{base}/api/v3/core/users/?{ENCODED_QUERY}"
    assert reply == ({}, None)
    assert received == ("/api/v3/core/users/", {"uuid": [QUERY_ORIGINAL], "page": ["2"]})
    assert (plain, mixed) == (f"{base}/stores/{ulid}/write", f"{base}/api/101/{S1}/{INT_SEGMENT_LIMIT - 1}/")
    assert refused == dict.fromkeys(BAD_SEGMENTS, (None, (UNAVAILABLE_ERROR, "invalid_request", False)))
    assert ia22_raw.count == 1


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_unencodable_inputs_are_invalid_request(ia22_raw: RawHttpServer) -> None:
    """ia-22(4B-4) — 요청 준비 단계의 접기 밖으로 새던 예외가 UpstreamUnavailable("invalid_request" · transient 거짓)로 접힌다:
    lone surrogate가 든 질의 값(urlencode의 UnicodeEncodeError — repr · args에 값 원문) · segments가 str(`build_url(base, "ab")` —
    튜플 쉼표가 빠진 호출이 글자 단위 경로가 된다) · bytes · 본문이 JSON 기본형이 아님(`{"a": {1}}` — json.dumps의 TypeError는
    형 이름을 싣는다) · 순환 참조 본문 · 10만 단으로 중첩한 목록 본문(json.dumps의 RecursionError — 조각 ⑤-b V2) → 호출 0 ·
    예외의 str · repr · args에 그 값 · 형 이름이 없다 · 연쇄 없음 / 양성 대조: 같은 서버에 정상 질의의 GET · JSON 본문의 POST →
    1회씩 닿는다."""
    outbound = impl("outbound")
    token = _token()
    base = ia22_raw.base_url
    marker = f"ia22-{secrets.token_hex(6)}"
    url = outbound.build_url(base, ("api", "v3", "core", "users"), query={"uuid": marker})
    control = (
        _attempt(lambda: outbound.request_json("GET", url, token=token)),
        _attempt(lambda: outbound.request_json("POST", url, token=token, body={"a": [1]})),
    )
    control_count = ia22_raw.count
    circular: list[Any] = []
    circular.append(circular)
    deep: list[Any] = []
    innermost = deep
    for _ in range(DEEP_BODY_LEVELS):
        innermost.append([])
        innermost = innermost[0]
    calls: dict[str, Callable[[], Any]] = {
        "query-surrogate": lambda: outbound.build_url(base, ("api",), query={"uuid": marker + LONE_SURROGATE}),
        "segments-str": lambda: outbound.build_url(base, "ab"),
        "segments-bytes": lambda: outbound.build_url(base, b"ab"),
        "body-set": lambda: outbound.request_json("POST", url, token=token, body={"a": {1}}),
        "body-circular": lambda: outbound.request_json("POST", url, token=token, body=circular),
        "body-deep": lambda: outbound.request_json("POST", url, token=token, body=deep),
    }
    needles = {"value": marker, "type-name": "Object of type", "token": token}
    observed: dict[str, tuple[Any, tuple[str | None, Any, Any], list[str]]] = {}
    for name, call in calls.items():
        value, error = _attempt(call)
        observed[name] = (value, _failure(error), _hygiene(error, needles))

    assert (control, control_count) == ((({}, None), ({}, None)), 2)
    assert observed == dict.fromkeys(calls, (None, (UNAVAILABLE_ERROR, "invalid_request", False), []))
    assert ia22_raw.count == 2


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_response_size_cap(ia22_raw: RawHttpServer) -> None:
    """ia-22 — 응답 본문 정확히 1 MiB → 값(JSON 문자열) / 1 MiB + 1바이트 → UpstreamUnavailable("too_large" · transient 거짓 —
    다시 해도 같다)."""
    outbound = impl("outbound")
    token = _token()
    ia22_raw.script(RawReply.large(MIB), RawReply.large(MIB + 1))
    url = f"{ia22_raw.base_url}/api/v3/events/events/"
    at_cap, at_cap_error = _attempt(lambda: outbound.request_json("GET", url, token=token))
    over, over_error = _attempt(lambda: outbound.request_json("GET", url, token=token))
    at_cap_view = (type(at_cap).__name__, len(at_cap) if isinstance(at_cap, str) else None, _failure(at_cap_error))

    assert at_cap_view == ("str", MIB - 2, (None, None, None))
    assert (over, _failure(over_error)) == (None, (UNAVAILABLE_ERROR, "too_large", False))


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_non_json_and_status_errors(ia22_raw: RawHttpServer) -> None:
    """ia-22 — JSON이 아닌 200(text/html) → UpstreamUnavailable("malformed" · transient 거짓) / 상태 표: 404 · 401 · 403 →
    UpstreamStatus(transient 거짓) · 429 · 500 · 503 → UpstreamStatus(transient 참 — 다시 하면 될 수 있다)."""
    outbound = impl("outbound")
    token = _token()
    statuses = (404, 401, 403, 429, 500, 503)
    ia22_raw.script(
        RawReply.text(b"<html>not json</html>"),
        *(RawReply.json({"detail": f"fake {status}"}, status=status) for status in statuses),
    )
    url = f"{ia22_raw.base_url}/api/v3/core/users/"
    observed: dict[str, tuple[Any, tuple[str | None, Any, Any]]] = {}
    for case in ("non-json", *map(str, statuses)):
        value, error = _attempt(lambda: outbound.request_json("GET", url, token=token))
        observed[case] = (value, _failure(error))

    assert observed == {
        "non-json": (None, (UNAVAILABLE_ERROR, "malformed", False)),
        "404": (None, (STATUS_ERROR, 404, False)),
        "401": (None, (STATUS_ERROR, 401, False)),
        "403": (None, (STATUS_ERROR, 403, False)),
        "429": (None, (STATUS_ERROR, 429, True)),
        "500": (None, (STATUS_ERROR, 500, True)),
        "503": (None, (STATUS_ERROR, 503, True)),
    }


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_truncated_body_is_connection_error(ia22_raw: RawHttpServer) -> None:
    """ia-22(4A-1 · 4B-1) — 본문이 다 오기 전에 상대가 끊은 응답은 연결 오류(일시)다: Content-Length를 실제보다 크게 적고 본문 일부만
    보낸 뒤 끊음 → UpstreamUnavailable("connection" · transient 참)(JSON이 아님 malformed가 아니다) · 같은 헤더에 본문 0바이트 →
    "connection"(성공 None이 아니다 — read1은 남은 길이가 있어도 EOF에서 빈 바이트를 줄 뿐이다) · chunked가 종결 chunk 전에 끊김 →
    "connection"(http.client가 IncompleteRead로 올린다 — 지금 동작의 고정) / 짝: 길이가 맞는 같은 응답 · 종결 chunk까지 온
    chunked → 값."""
    outbound = impl("outbound")
    token = _token()
    body = json.dumps({"results": list(range(40))}).encode()
    declared = (("Content-Type", JSON_TYPE), ("Content-Length", str(len(body))))
    chunk = f"{len(body):x}".encode() + b"\r\n" + body + b"\r\n"
    replies = {
        "exact": RawReply(headers=declared, chunks=(body,), content_length=False),
        "partial": RawReply(headers=declared, chunks=(body[: len(body) // 2],), content_length=False),
        "empty": RawReply(headers=declared, chunks=(), content_length=False),
        "chunked-whole": RawReply(headers=CHUNKED_HEADERS, chunks=(chunk, b"0\r\n\r\n"), content_length=False),
        "chunked-cut": RawReply(headers=CHUNKED_HEADERS, chunks=(chunk,), content_length=False),
    }
    ia22_raw.script(*replies.values())
    url = f"{ia22_raw.base_url}/api/v3/core/users/"
    observed: dict[str, tuple[Any, tuple[str | None, Any, Any]]] = {}
    for case in replies:
        value, error = _attempt(lambda: outbound.request_json("GET", url, token=token))
        observed[case] = (value, _failure(error))
    cut = (None, (UNAVAILABLE_ERROR, "connection", True))

    assert observed == {
        "exact": (json.loads(body), (None, None, None)),
        "partial": cut,
        "empty": cut,
        "chunked-whole": (json.loads(body), (None, None, None)),
        "chunked-cut": cut,
    }
    assert ia22_raw.count == len(replies)


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_https_handler_only_for_https(
    ia22_raw: RawHttpServer, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """ia-22(4B-5) — opener의 HTTPS 핸들러(만들 때마다 기본 SSL 컨텍스트를 새로 짓는다 — 평문 호출 시간의 거의 전부)는 URL
    스킴이 https일 때만 만든다: http 호출 → 만든 수 0 / 짝: https URL(닫힌 루프백 포트 — 핸들러를 만든 뒤 연결 실패 또는 마감 ·
    일시 오류) → 1이고 debuglevel 0을 받았다 · HTTP 핸들러도 debuglevel 0이다(전역 HTTPConnection.debuglevel을 1로 켜도 http
    호출의 stdout이 비어 있다 — 켜지면 http.client가 Authorization이 든 요청 헤더를 stdout에 찍는다). 만든 수는
    urllib.request.HTTPSHandler 모듈 속성을 세는 하위 클래스로 덮어 센다(구현은 호출 때 모듈 속성으로 읽는다)."""
    outbound = impl("outbound")
    token = _token()
    made: list[Any] = []
    original = urllib.request.HTTPSHandler

    class CountingHttpsHandler(original):  # type: ignore[misc, valid-type]
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            made.append(kwargs.get("debuglevel", args[0] if args else None))
            super().__init__(*args, **kwargs)

    monkeypatch.setattr(urllib.request, "HTTPSHandler", CountingHttpsHandler)
    monkeypatch.setattr(http.client.HTTPConnection, "debuglevel", 1)
    capsys.readouterr()
    plain = _attempt(lambda: outbound.request_json("GET", f"{ia22_raw.base_url}/api/", token=token))
    plain_made = len(made)
    printed = capsys.readouterr().out
    needles = {"token": token, "send": "send:", "reply": "reply:"}
    leaked = [name for name, needle in needles.items() if needle in printed]
    printed_chars = len(printed)  # 조각 ⑤-b V5 — 핀이 빠지면 Authorization 줄을 담는 묶음을 assert 식 안 호출에 두지 않는다
    tls_url = f"https://127.0.0.1:{closed_port()}/api/"
    _, tls_error = _attempt(
        lambda: outbound.request_json("GET", tls_url, token=token, deadline=outbound.Deadline(TLS_PROBE_DEADLINE_S))
    )
    tls_kind = _failure(tls_error)
    tls_view = (made, tls_kind[0], tls_kind[2])

    assert (plain, plain_made, leaked, printed_chars) == (({}, None), 0, [], 0)
    assert tls_view == ([0], UNAVAILABLE_ERROR, True)


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_bad_token_characters_make_no_call(ia22_raw: RawHttpServer) -> None:
    """ia-22(조각 ② 리뷰 2B-1) — `token=` 인자는 기동 게이트를 지나지 않는다: 토큰 끝 LF · 가운데 CR · 비ASCII(한글 · latin-1
    é) · 「LF + 공백」 → UpstreamUnavailable("invalid_request" · transient 거짓) · 호출 0(원시 서버 count 그대로) · 예외 str ·
    repr · args에 토큰 조각(앞 8자 · 뒤 8자)이 없다 · 연쇄 끊김 / 양성 대조: 같은 토큰에서 그 글자만 뺀 호출 → 1회 닿는다.
    (http.client는 CR · LF가 든 헤더 값을 ValueError 문구에 통째로 싣고, latin-1 글자와 「LF + 공백」은 그대로 보낸다.)"""
    outbound = impl("outbound")
    raw_token = secrets.token_urlsafe(24)
    url = f"{ia22_raw.base_url}/api/v3/core/users/"
    control = _attempt(lambda: outbound.request_json("GET", url, token=Secret(raw_token)))
    control_count = ia22_raw.count
    defects = {
        "end-lf": raw_token + LF,
        "mid-cr": raw_token[:12] + CR + raw_token[12:],
        "hangul": raw_token[:12] + HANGUL_LETTER + raw_token[12:],
        "latin1": raw_token[:12] + LATIN1_LETTER + raw_token[12:],
        "lf-space": raw_token[:12] + LF + " " + raw_token[12:],
    }
    fragments = {"head": raw_token[:8], "tail": raw_token[-8:]}
    observed: dict[str, tuple[Any, tuple[str | None, Any, Any], list[str]]] = {}
    for name, defect in defects.items():
        value, error = _attempt(lambda defect=defect: outbound.request_json("GET", url, token=Secret(defect)))
        observed[name] = (value, _failure(error), _hygiene(error, fragments))

    assert (control, control_count) == (({}, None), 1)
    assert observed == dict.fromkeys(defects, (None, (UNAVAILABLE_ERROR, "invalid_request", False), []))
    assert ia22_raw.count == 1


@pytest.mark.usefixtures("ia73_env")
def test_ia_22_errors_carry_no_url_query_or_token(ia22_raw: RawHttpServer) -> None:
    """ia-22 — 오류 문자열 위생(설계 D20 「오류 형」 · 「연쇄 끊기」): 상태 404(본문에 질의 값) · 302(Location에 질의 값) · JSON이
    아닌 200(본문 = 질의 값) · 1 MiB 초과 · ftp 스킴 · 마감 0 s · 닫힌 포트(연결 실패) · 꼴이 아닌 경로 성분 · LF 토큰 — 예외마다
    outbound 오류 형이고 str · repr · args에 URL · 질의 값(사용자 uuid 자리) · 토큰 · 루프백 주소가 없으며 `__cause__` None ·
    `__suppress_context__` 참이다."""
    outbound = impl("outbound")
    token = _token()
    needle = f"ia22-{secrets.token_hex(6)}"
    base = ia22_raw.base_url
    url = outbound.build_url(base, ("api", "v3", "core", "users"), query={"uuid": needle})
    ia22_raw.script(
        RawReply.json({"detail": needle}, status=404),
        RawReply.redirect(f"{base}/{needle}"),
        RawReply.text(needle.encode()),
        RawReply.large(MIB + 1),
    )
    closed = f"http://127.0.0.1:{closed_port()}/api/?uuid={needle}"
    calls: dict[str, Callable[[], Any]] = {
        "status-404": lambda: outbound.request_json("GET", url, token=token),
        "redirect": lambda: outbound.request_json("GET", url, token=token),
        "malformed": lambda: outbound.request_json("GET", url, token=token),
        "too-large": lambda: outbound.request_json("GET", url, token=token),
        "scheme": lambda: outbound.request_json("GET", url.replace("http://", "ftp://", 1), token=token),
        "deadline": lambda: outbound.request_json("GET", url, token=token, deadline=outbound.Deadline(0)),
        "connection": lambda: outbound.request_json("GET", closed, token=token),
        "path-segment": lambda: outbound.build_url(base, ("api", f"{needle}/x")),
        "token-lf": lambda: outbound.request_json("GET", url, token=Secret(f"{token}{LF}")),
    }
    needles = {"url": url, "query": needle, "token": token, "loopback": "127.0.0.1"}
    problems: dict[str, list[str]] = {}
    transient: dict[str, Any] = {}
    for name, call in calls.items():
        _, error = _attempt(call)
        problems[name] = _hygiene(error, needles)
        transient[name] = getattr(error, "transient", None)

    assert problems == dict.fromkeys(calls, [])
    assert transient == {
        "status-404": False,
        "redirect": False,
        "malformed": False,
        "too-large": False,
        "scheme": False,
        "deadline": True,
        "connection": True,
        "path-segment": False,
        "token-lf": False,
    }


# --- ia-41(D20 — authentik.py 메서드 여덟 · 확장 가짜) ---------------------------------------------------------------------


def _seed_ia41(fake: FakeAuthentikExt, **surfaces: Any) -> None:
    """확장 가짜 상태 — 미끼 사용자 · 그룹이 정답보다 앞(IA41_USERS · IA41_GROUPS) + 세션 · 이벤트(있으면)."""
    fake.reset(groups=IA41_GROUPS, users=IA41_USERS, **surfaces)


def _listing_view(listing: Any) -> tuple[list[Any], int, bool]:
    """Listing → (항목의 uuid 또는 pk, pages, truncated)."""
    keys = [item.get("uuid", item.get("pk")) for item in listing.items]
    return keys, listing.pages, listing.truncated


def _drain(pages: Iterable[Any]) -> tuple[list[tuple[list[Any], int, bool]], Exception | None]:
    """쪽 단위 제너레이터(logout_event_pages)를 끝까지 돈다 → (받은 쪽마다의 _listing_view · 도중에 난 예외 또는 None) — 예외 앞에
    받은 쪽도 남긴다(쪽 단위 처리: 뒤 쪽의 실패가 앞 쪽을 되돌리지 않는다)."""
    received: list[tuple[list[Any], int, bool]] = []
    try:
        for listing in pages:
            received.append(_listing_view(listing))
    except Exception as exc:  # noqa: BLE001 — 예외 종류 · 속성을 값으로 본다
        return received, exc
    return received, None


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_find_group_exact_name(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 find_group — `GET /api/v3/core/groups/?name=<이름>`(끝 슬래시 · 질의 키는 name 하나 · 값의 & · # · % · 공백이 가짜가
    받은 값과 같다) → 이름이 정확히 같은 그룹만: 필터 무시 미끼 모드에서도(미끼 superuser 그룹 · 앞이 같은 이름은 버린다) · 필터를
    지키는 가짜에서도 같다 · 없는 이름 → []."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik)
    ia73_authentik.ignore_filters = True
    decoyed = [group.get("pk") for group in authentik.find_group(GROUP_NAME)]
    ia73_authentik.ignore_filters = False
    filtered = [group.get("pk") for group in authentik.find_group(GROUP_NAME)]
    missing = authentik.find_group("tenant:missing")
    requests = [(request.method, request.path, request.query) for request in ia73_authentik.requests_to("groups")]

    assert (decoyed, filtered, missing) == ([GROUP_PK], [GROUP_PK], [])
    assert requests == [
        ("GET", f"{CORE}/groups/", {"name": [GROUP_NAME]}),
        ("GET", f"{CORE}/groups/", {"name": [GROUP_NAME]}),
        ("GET", f"{CORE}/groups/", {"name": ["tenant:missing"]}),
    ]


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_find_user_exact_uuid(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 find_user — `GET /api/v3/core/users/?uuid=<uuid>`(질의 키는 uuid 하나 · 값 원문 그대로) → uuid가 정확히 같은 사용자만:
    필터 무시 미끼 모드에서도(미끼 akadmin이 앞) · 필터를 지키는 가짜에서도 같다 · & · # · % · 공백이 든 값 → [](원문 그대로 실린다)."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik)
    ia73_authentik.ignore_filters = True
    decoyed = [user.get("pk") for user in authentik.find_user(OWNER_UUID)]
    ia73_authentik.ignore_filters = False
    filtered = [user.get("pk") for user in authentik.find_user(OWNER_UUID)]
    odd = authentik.find_user(QUERY_ORIGINAL)
    requests = [(request.method, request.path, request.query) for request in ia73_authentik.requests_to("users")]

    assert (decoyed, filtered, odd) == ([101], [101], [])
    assert requests == [
        ("GET", f"{CORE}/users/", {"uuid": [OWNER_UUID]}),
        ("GET", f"{CORE}/users/", {"uuid": [OWNER_UUID]}),
        ("GET", f"{CORE}/users/", {"uuid": [QUERY_ORIGINAL]}),
    ]


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_get_user(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 get_user — `GET /api/v3/core/users/<pk>/` → 사용자 dict · 404 → None / 꼴이 아닌 pk(문자열 숫자 · bool · 0 · 음수 ·
    실수 · None · `../groups` · 2**63 — 조각 ⑤-b V1: 대조가 거른 이벤트의 pk 하나가 일시 아닌 예외가 아니라 「사용자 없음」이다) →
    None · 예외 없음 · 호출 0(앞의 정상 호출 셋은 닿았다 — 짝 2**63 - 1은 꼴을 지나 요청이 나가고 가짜 404로 None) / 403 →
    UpstreamStatus(403 — 404와 갈린다)."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik)
    found = authentik.get_user(101)
    shape = None if found is None else (found.get("pk"), found.get("uuid"))
    absent = authentik.get_user(999)
    edge = authentik.get_user(INT_SEGMENT_LIMIT - 1)
    control = len(ia73_authentik.requests)
    skipped = {case: _attempt(lambda value=value: authentik.get_user(value)) for case, value in BAD_PKS.items()}
    after_skips = len(ia73_authentik.requests)
    ia73_authentik.forbid("user_detail")
    _, forbidden = _attempt(lambda: authentik.get_user(101))
    paths = [(request.method, request.path) for request in ia73_authentik.requests_to("user_detail")]

    assert (shape, absent, edge, control) == ((101, OWNER_UUID), None, None, 3)
    assert (skipped, after_skips) == (dict.fromkeys(BAD_PKS, (None, None)), 3)
    assert _failure(forbidden) == (STATUS_ERROR, 403, False)
    assert paths == [
        ("GET", f"{CORE}/users/101/"),
        ("GET", f"{CORE}/users/999/"),
        ("GET", f"{CORE}/users/{INT_SEGMENT_LIMIT - 1}/"),
        ("GET", f"{CORE}/users/101/"),
    ]


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_add_user(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 add_user — `POST /api/v3/core/groups/<그룹 pk>/add_user/` 본문 `{"pk": <사용자 pk>}`(application/json — 가짜 415를
    지난다) → True · 소속이 생긴다 / 꼴이 아닌 그룹 pk(UUID 꼴 아님 · 경로 넘기 · 정수) · 사용자 pk(문자열 · bool · 0 · 2**63 — 조각
    ⑤-b V1: 본문에 실려 나가지 않는다) → False · 예외 없음 · 변경 요청 0 / 없는 그룹 → UpstreamStatus(404)."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik)
    added = authentik.add_user(GROUP_PK, 102)
    members = ia73_authentik.group_users(GROUP_NAME)
    control = len(ia73_authentik.mutations())
    bad = {
        "group-plain": ("not-a-uuid", 102),
        "group-traversal": (f"{GROUP_PK}/../x", 102),
        "group-int": (7, 102),
        "user-str": (GROUP_PK, "102"),
        "user-bool": (GROUP_PK, True),
        "user-zero": (GROUP_PK, 0),
        "user-int-limit": (GROUP_PK, INT_SEGMENT_LIMIT),
    }
    skipped = {case: _attempt(lambda args=args: authentik.add_user(*args)) for case, args in bad.items()}
    after_skips = len(ia73_authentik.mutations())
    _, missing = _attempt(lambda: authentik.add_user(UNKNOWN_GROUP_PK, 102))
    posts = [(request.method, request.path, request.body) for request in ia73_authentik.requests_to("add_user")]

    assert (added, members, control) == (True, {102}, 1)
    assert (skipped, after_skips) == (dict.fromkeys(bad, (False, None)), 1)
    assert _failure(missing) == (STATUS_ERROR, 404, False)
    assert posts == [
        ("POST", f"{CORE}/groups/{GROUP_PK}/add_user/", {"pk": 102}),
        ("POST", f"{CORE}/groups/{UNKNOWN_GROUP_PK}/add_user/", {"pk": 102}),
    ]


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_patch_attributes(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 patch_attributes — `PATCH /api/v3/core/users/<pk>/` 본문 `{"attributes": <준 사전 전체>}` → True · 가짜의 attributes가
    그 사전이다(통째로 바꾼다) / 꼴이 아닌 pk(2**63 포함 — 조각 ⑤-b V1) → False · 예외 없음 · 변경 요청 0."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik)
    attributes = {"existing": "keep", "tenant_id": TENANT_ID_VALUE}
    patched = authentik.patch_attributes(101, attributes)
    stored = ia73_authentik.user(101)["attributes"]
    control = len(ia73_authentik.mutations())
    skipped = {
        case: _attempt(lambda value=value: authentik.patch_attributes(value, attributes))
        for case, value in BAD_PKS.items()
    }
    after_skips = len(ia73_authentik.mutations())
    patches = [(request.method, request.path, request.body) for request in ia73_authentik.mutations()]

    assert (patched, stored, control) == (True, attributes, 1)
    assert (skipped, after_skips) == (dict.fromkeys(BAD_PKS, (False, None)), 1)
    assert patches == [("PATCH", f"{CORE}/users/101/", {"attributes": attributes})]


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_list_sessions_filter_pages_and_ceiling(
    ia73_authentik: FakeAuthentikExt, monkeypatch: pytest.MonkeyPatch
) -> None:
    """ia-41 list_sessions — `GET /api/v3/core/authenticated_sessions/?user__username=<이름>&page_size=100&page=<n>`(이름의
    & · # · % · 공백 원문 그대로): 필터 무시 미끼 모드(남의 세션 · bool · 문자열 user 섞임)에서 user == pk(정수)인 세션만 · 150개 → 두 쪽
    (page 1 · 2 · next 0에서 멈춤 · truncated 거짓) / 꼴이 아닌 user pk · 빈 username → 빈 Listing · 호출 0 / 끝나지 않는 next →
    정확히 10쪽에서 멈춤(truncated 참 · ceiling_hits 0 — 시간이 아니라 요청 수로 본다) / 상한은 쓰는 자리에서 모듈 속성으로 읽는다
    (SESSION_PAGE_LIMIT를 3으로 덮으면 3쪽)."""
    authentik = impl("authentik")
    owned = [make_session(101) for _ in range(150)]
    decoys = [make_session(102), make_session(True), make_session("101")]
    _seed_ia41(ia73_authentik, sessions=[decoys[0], *owned[:75], decoys[1], *owned[75:], decoys[2]])
    ia73_authentik.ignore_filters = True
    listing = _listing_view(authentik.list_sessions(101, OWNER_NAME))
    queries = [request.query for request in ia73_authentik.requests_to("sessions")]
    before_skips = len(ia73_authentik.requests)
    skipped = {case: _listing_view(authentik.list_sessions(value, OWNER_NAME)) for case, value in BAD_PKS.items()}
    skipped["empty-username"] = _listing_view(authentik.list_sessions(101, ""))
    after_skips = len(ia73_authentik.requests)
    _seed_ia41(ia73_authentik, sessions=[make_session(101, S1)])
    ia73_authentik.endless_next = True
    endless, _ = timed(lambda: authentik.list_sessions(101, OWNER_NAME), HANG_LIMIT_S_IA22)
    endless_view = (*_listing_view(endless), len(ia73_authentik.requests_to("sessions")), ia73_authentik.ceiling_hits)
    _seed_ia41(ia73_authentik, sessions=[make_session(101, S1)])
    ia73_authentik.endless_next = True
    monkeypatch.setattr(authentik, "SESSION_PAGE_LIMIT", 3)
    lowered = _listing_view(authentik.list_sessions(101, OWNER_NAME))
    lowered_requests = len(ia73_authentik.requests_to("sessions"))

    def page(number: int) -> dict[str, list[str]]:
        return {"user__username": [OWNER_NAME], "page_size": [PAGE_SIZE], "page": [str(number)]}

    assert listing == ([session["uuid"] for session in owned], 2, False)
    assert queries == [page(1), page(2)]
    assert (skipped, after_skips) == (dict.fromkeys([*BAD_PKS, "empty-username"], ([], 0, False)), before_skips)
    assert endless_view == ([S1], SESSION_PAGE_LIMIT, True, SESSION_PAGE_LIMIT, 0)
    assert (lowered, lowered_requests) == (([S1], 3, True), 3)


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_delete_session_outcomes(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 delete_session — `DELETE /api/v3/core/authenticated_sessions/<uuid>/` → 204 "deleted" · 같은 것 다시 → 404
    "gone"(지움과 갈라 센다 — 남의 세션 · 권한 없음도 404다 · 사실 ⑭) / 꼴이 아닌 uuid(UUID 꼴 아님 · 경로 넘기 · 정수 · None · hex 32자 ·
    뒤에 붙은 경로 · 중괄호) → "skipped" · 호출 0 / 503 → UpstreamStatus(503 · transient 참) · 403 → UpstreamStatus(403 · 거짓)."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik, sessions=[make_session(101, S1), make_session(101, S2)])
    first = authentik.delete_session(S1)
    again = authentik.delete_session(S1)
    control = (len(ia73_authentik.mutations()), ia73_authentik.deleted_sessions)
    skipped = {case: authentik.delete_session(value) for case, value in BAD_UUIDS.items()}
    after_skips = len(ia73_authentik.mutations())
    ia73_authentik.inject("session_detail", 503)
    _, unavailable = _attempt(lambda: authentik.delete_session(S2))
    ia73_authentik.forbid("session_detail")
    _, forbidden = _attempt(lambda: authentik.delete_session(S2))
    deletes = [(request.method, request.path) for request in ia73_authentik.requests_to("session_detail")]
    remaining = [session.get("uuid") for session in ia73_authentik.sessions]

    assert (first, again, control) == ("deleted", "gone", (2, [S1]))
    assert (skipped, after_skips) == (dict.fromkeys(BAD_UUIDS, "skipped"), 2)
    assert (_failure(unavailable), _failure(forbidden)) == ((STATUS_ERROR, 503, True), (STATUS_ERROR, 403, False))
    assert deletes == [("DELETE", f"{SESSIONS_PATH}{S1}/")] * 2 + [("DELETE", f"{SESSIONS_PATH}{S2}/")] * 2
    assert remaining == [S2]


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_logout_event_pages(ia73_authentik: FakeAuthentikExt, monkeypatch: pytest.MonkeyPatch) -> None:
    """ia-41 logout_event_pages — `GET /api/v3/events/events/?actions=logout&ordering=-created&page_size=100&page=<n>`를
    쪽마다 Listing(items = 그 쪽 이벤트 전부 · pages = 그 쪽 번호 · truncated = 상한 쪽인데 next가 0이 아니다)으로 내준다(4A-2 — 설계 D17
    「이미 기록한 행은 남는다」): logout 120개(+ login 미끼 — 필터를 지키는 가짜가 거른다) → 두 쪽(100 · 20 · 받은 차례 = 최신 먼저 ·
    truncated 거짓) / 한 쪽으로 끝나는 목록 → Listing 하나(truncated 거짓) / 둘째 쪽 503 → 첫 쪽의 Listing은 받았고 그다음에
    UpstreamStatus(503 · transient 참) · 셋째 쪽 요청 0 / 끝나지 않는 next → 요청 정확히 50 · 마지막 Listing.truncated 참 ·
    ceiling_hits 0 / 상한은 모듈 속성으로 읽는다(EVENT_PAGE_LIMIT를 2로 덮으면 2쪽) · 같은 상한 2에서 logout 120개(둘째 쪽 next 0)
    → 둘째 Listing의 truncated 거짓(상한 쪽이어도 next가 0이면 잘린 것이 아니다 — 조각 ⑤-b V4 ③) / 마감 0 s → 첫 next()에서
    UpstreamUnavailable("deadline") · 요청 0."""
    outbound = impl("outbound")
    authentik = impl("authentik")
    now = datetime.now(UTC)
    logouts = [make_event(101, now - timedelta(minutes=index)) for index in range(250)]
    pks = [event["pk"] for event in logouts]
    login = make_event(101, now - timedelta(seconds=30), action="login")
    _seed_ia41(ia73_authentik, events=[login, *logouts[:120]])
    two = _drain(authentik.logout_event_pages())
    queries = [request.query for request in ia73_authentik.requests_to("events")]
    _seed_ia41(ia73_authentik, events=[logouts[0]])
    single = _drain(authentik.logout_event_pages())
    _seed_ia41(ia73_authentik, events=logouts)
    ia73_authentik.inject("events", None, 503)
    received, failed = _drain(authentik.logout_event_pages())
    failed_view = (received, _failure(failed), len(ia73_authentik.requests_to("events")))
    _seed_ia41(ia73_authentik, events=[logouts[0]])
    ia73_authentik.endless_next = True
    (endless, endless_error), _ = timed(lambda: _drain(authentik.logout_event_pages()), HANG_LIMIT_S_IA22)
    endless_view = (
        len(endless),
        endless[0] if endless else None,
        endless[-1] if endless else None,
        [view[2] for view in endless[:-1]],
        endless_error,
        len(ia73_authentik.requests_to("events")),
        ia73_authentik.ceiling_hits,
    )
    _seed_ia41(ia73_authentik, events=[logouts[0]])
    ia73_authentik.endless_next = True
    monkeypatch.setattr(authentik, "EVENT_PAGE_LIMIT", 2)
    lowered = _drain(authentik.logout_event_pages())
    lowered_requests = len(ia73_authentik.requests_to("events"))
    _seed_ia41(ia73_authentik, events=logouts[:120])  # 상한(2) 쪽에서 next가 0으로 끝나는 목록 — 조각 ⑤-b V4 ③
    at_limit = _drain(authentik.logout_event_pages())
    _seed_ia41(ia73_authentik, events=[logouts[0]])
    pages = authentik.logout_event_pages(deadline=outbound.Deadline(0))
    _, expired = _attempt(lambda: next(pages))
    expired_view = (_failure(expired), len(ia73_authentik.requests))

    def page(number: int) -> dict[str, list[str]]:
        return {"actions": ["logout"], "ordering": ["-created"], "page_size": [PAGE_SIZE], "page": [str(number)]}

    assert two == ([(pks[:100], 1, False), (pks[100:120], 2, False)], None)
    assert queries == [page(1), page(2)]
    assert single == ([([pks[0]], 1, False)], None)
    assert failed_view == ([(pks[:100], 1, False)], (STATUS_ERROR, 503, True), 2)
    assert endless_view == (
        EVENT_PAGE_LIMIT,
        ([pks[0]], 1, False),
        ([], EVENT_PAGE_LIMIT, True),
        [False] * (EVENT_PAGE_LIMIT - 1),
        None,
        EVENT_PAGE_LIMIT,
        0,
    )
    assert (lowered, lowered_requests) == (([([pks[0]], 1, False), ([], 2, True)], None), 2)
    assert at_limit == ([(pks[:100], 1, False), (pks[100:120], 2, False)], None)
    assert expired_view == ((UNAVAILABLE_ERROR, "deadline", True), 0)


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_not_found_after_first_page_ends_listing(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41(4B-6) — 쪽 매김 목록에서 2쪽 이후의 404(쪽 사이에 목록이 줄었다 — DRF가 범위 밖 쪽에 내는 응답)는 목록의 끝이다:
    list_sessions → 1쪽에서 모은 항목을 돌려준다(pages 1 · truncated 거짓 · 요청 2) · logout_event_pages → 첫 쪽을 내준 뒤 조용히
    끝난다(요청 2) / 1쪽의 404는 지금처럼 UpstreamStatus(404 · transient 거짓)다(조용히 끝나지 않는다 — 설계 D17) / 끝은 404만이다
    (조각 ⑤-b V4 ① — 4V-1): 세션 목록의 2쪽 403 → UpstreamStatus(403 · transient 거짓) · 429 → UpstreamStatus(429 · transient
    참)(1쪽 세션만 지우고 truncated 거짓으로 끝나지 않는다 · 429는 재시도 대상이다) · 이벤트 목록의 2쪽 429 → 첫 쪽 Listing을 받은
    뒤 UpstreamStatus(429) · 요청 2."""
    authentik = impl("authentik")
    owned = [make_session(101) for _ in range(150)]
    logouts = [make_event(101, datetime.now(UTC) - timedelta(minutes=index)) for index in range(150)]
    second_page: dict[str, Any] = {}
    for status in (403, 429):
        _seed_ia41(ia73_authentik, sessions=owned)
        ia73_authentik.inject("sessions", None, status)
        _, error = _attempt(lambda: authentik.list_sessions(101, OWNER_NAME))
        second_page[f"sessions-{status}"] = (_failure(error), len(ia73_authentik.requests_to("sessions")))
    _seed_ia41(ia73_authentik, events=logouts)
    ia73_authentik.inject("events", None, 429)
    received, error = _drain(authentik.logout_event_pages())
    second_page["events-429"] = (received, _failure(error), len(ia73_authentik.requests_to("events")))
    _seed_ia41(ia73_authentik, sessions=owned)
    ia73_authentik.inject("sessions", None, 404)
    sessions_cut = _attempt(lambda: _listing_view(authentik.list_sessions(101, OWNER_NAME)))
    sessions_cut_requests = len(ia73_authentik.requests_to("sessions"))
    _seed_ia41(ia73_authentik, sessions=owned)
    ia73_authentik.inject("sessions", 404)
    _, sessions_missing = _attempt(lambda: authentik.list_sessions(101, OWNER_NAME))
    _seed_ia41(ia73_authentik, events=logouts)
    ia73_authentik.inject("events", None, 404)
    events_cut = _drain(authentik.logout_event_pages())
    events_cut_requests = len(ia73_authentik.requests_to("events"))
    _seed_ia41(ia73_authentik, events=logouts)
    ia73_authentik.inject("events", 404)
    events_missing = _drain(authentik.logout_event_pages())
    events_missing_view = (events_missing[0], _failure(events_missing[1]))

    assert (sessions_cut, sessions_cut_requests) == ((([s["uuid"] for s in owned[:100]], 1, False), None), 2)
    assert _failure(sessions_missing) == (STATUS_ERROR, 404, False)
    assert (events_cut, events_cut_requests) == (([([e["pk"] for e in logouts[:100]], 1, False)], None), 2)
    assert events_missing_view == ([], (STATUS_ERROR, 404, False))
    assert second_page == {
        "sessions-403": ((STATUS_ERROR, 403, False), 2),
        "sessions-429": ((STATUS_ERROR, 429, True), 2),
        "events-429": ([([e["pk"] for e in logouts[:100]], 1, False)], (STATUS_ERROR, 429, True), 2),
    }


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_page_over_page_size_is_malformed(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41(4B-7) — 쪽 매김 목록에서 한 쪽의 results가 page_size(100)를 넘으면 UpstreamUnavailable("malformed" · transient
    거짓)이다(요청한 쪽 크기를 어긴 상류 — 누적 메모리의 값싼 상한): 101건 한 쪽 → malformed(세션 · 이벤트) / 짝: 100건 한 쪽 →
    통과(100건)."""
    authentik = impl("authentik")
    sessions = [make_session(101) for _ in range(PAGE_SIZE_COUNT + 1)]
    events = [make_event(101, datetime.now(UTC) - timedelta(minutes=index)) for index in range(PAGE_SIZE_COUNT + 1)]

    def body(results: list[dict[str, Any]]) -> tuple[int, dict[str, Any]]:
        return 200, {"pagination": {"next": 0}, "results": results}

    _seed_ia41(ia73_authentik)
    ia73_authentik.inject("sessions", body(sessions[:PAGE_SIZE_COUNT]), body(sessions))
    ia73_authentik.inject("events", body(events[:PAGE_SIZE_COUNT]), body(events))
    at_size = (
        _attempt(lambda: len(authentik.list_sessions(101, OWNER_NAME).items)),
        _attempt(lambda: [len(listing.items) for listing in authentik.logout_event_pages()]),
    )
    over = (
        _failure(_attempt(lambda: authentik.list_sessions(101, OWNER_NAME))[1]),
        _failure(_attempt(lambda: list(authentik.logout_event_pages()))[1]),
    )

    assert at_size == ((PAGE_SIZE_COUNT, None), ([PAGE_SIZE_COUNT], None))
    assert over == ((UNAVAILABLE_ERROR, "malformed", False), (UNAVAILABLE_ERROR, "malformed", False))


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_out_of_contract_bodies_are_malformed(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 — 계약 밖 응답 꼴 → UpstreamUnavailable("malformed" · transient 거짓): results 없음(find_group) · results가 목록이
    아님(find_user) · 사용자 단건이 객체가 아님(get_user) · pagination.next가 정수가 아님(문자열 — list_sessions · bool —
    logout_event_pages) / 짝: 주입이 다 쓰인 뒤 같은 호출은 정상이다."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik, sessions=[make_session(101, S1)], events=[make_event(101, datetime.now(UTC))])
    ia73_authentik.inject("groups", (200, {"no": "results"}))
    ia73_authentik.inject("users", (200, {"results": "x"}))
    ia73_authentik.inject("user_detail", (200, ["not", "an", "object"]))
    ia73_authentik.inject("sessions", (200, {"pagination": {"next": "2"}, "results": []}))
    ia73_authentik.inject("events", (200, {"pagination": {"next": True}, "results": []}))
    calls: dict[str, Callable[[], Any]] = {
        "find_group": lambda: authentik.find_group(GROUP_NAME),
        "find_user": lambda: authentik.find_user(OWNER_UUID),
        "get_user": lambda: authentik.get_user(101),
        "list_sessions": lambda: authentik.list_sessions(101, OWNER_NAME),
        "logout_event_pages": lambda: list(authentik.logout_event_pages()),
    }
    observed = {name: _failure(_attempt(call)[1]) for name, call in calls.items()}
    normal = (
        [group.get("pk") for group in authentik.find_group(GROUP_NAME)],
        [user.get("pk") for user in authentik.find_user(OWNER_UUID)],
        authentik.get_user(101) is not None,
        _listing_view(authentik.list_sessions(101, OWNER_NAME)),
        [len(listing.items) for listing in authentik.logout_event_pages()],
    )

    assert observed == dict.fromkeys(calls, (UNAVAILABLE_ERROR, "malformed", False))
    assert normal == ([GROUP_PK], [101], True, ([S1], 1, False), [1])


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_token_and_base_url_read_at_call_time(
    ia73_authentik: FakeAuthentikExt, ia22_raw: RawHttpServer, settings: SettingsWrapper
) -> None:
    """ia-41 — 설정은 호출 때 읽는다: 설정 토큰을 다른 값으로 덮어도 `token=` 인자(seed의 stdin 토큰 자리)로 준 값으로 인증한다 ·
    인자가 없으면 설정 토큰(가짜 403 — 그 요청은 인증 실패로 기록된다) / AUTHENTIK_API_URL을 원시 서버(끝 슬래시 붙음)로 바꾸면 다음
    호출이 그리로 간다(원시 요청 줄 `GET /api/v3/core/users/?uuid=<uuid> HTTP/1.1` — 기준 URL 끝 `/`를 떼 `//api`가 되지 않는다 ·
    원시 서버는 `//`로 시작하는 경로를 `/`로 접어 기록하므로 path로는 갈리지 않는다(4A-4) · 설정 토큰의 Bearer)."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik)
    settings.AUTHENTIK_API_TOKEN = _token()
    explicit = [user.get("pk") for user in authentik.find_user(OWNER_UUID, token=ia73_authentik.token)]
    _, refused = _attempt(lambda: authentik.find_user(OWNER_UUID))
    authorized = [request.authorized for request in ia73_authentik.requests]
    settings.AUTHENTIK_API_URL = f"{ia22_raw.base_url}/"
    ia22_raw.script(RawReply.json({"pagination": {"next": 0}, "results": []}))
    moved = authentik.find_user(OWNER_UUID)
    (request,) = ia22_raw.requests
    expected_bearer = f"Bearer {settings.AUTHENTIK_API_TOKEN}"
    raw_view = (request.request_line, request.header("authorization") == expected_bearer)

    assert explicit == [101]
    assert _failure(refused) == (STATUS_ERROR, 403, False)
    assert authorized == [True, False]
    assert (moved, raw_view) == ([], (f"GET {CORE}/users/?uuid={OWNER_UUID} HTTP/1.1", True))


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_token_argument_reaches_every_method(ia73_authentik: FakeAuthentikExt, settings: SettingsWrapper) -> None:
    """ia-41(4A-3) — `token=` 인자(seed의 stdin 토큰 자리 — 설계 D19 「그 실행의 모든 호출이 그 토큰을 쓴다」)는 메서드 여덟
    모두에서 그 호출의 모든 요청에 쓰인다: 설정 토큰을 틀린 값으로 둔 채 token=<가짜 토큰>으로 부르면 메서드마다 그 호출이 낸
    요청(1회 이상)이 전부 인증된 것으로 기록되고(가짜의 authorized) 예외가 없다 / 양성 대조(같은 준비물): token 없이 부르면 설정
    토큰이라 가짜가 403이다."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik, sessions=[make_session(101, S1)], events=[make_event(101, datetime.now(UTC))])
    settings.AUTHENTIK_API_TOKEN = _token()
    token = ia73_authentik.token
    _, refused = _attempt(lambda: authentik.find_user(OWNER_UUID))
    control = (_failure(refused), [request.authorized for request in ia73_authentik.requests])
    calls: dict[str, Callable[[], Any]] = {
        "find_group": lambda: authentik.find_group(GROUP_NAME, token=token),
        "find_user": lambda: authentik.find_user(OWNER_UUID, token=token),
        "get_user": lambda: authentik.get_user(101, token=token),
        "add_user": lambda: authentik.add_user(GROUP_PK, 102, token=token),
        "patch_attributes": lambda: authentik.patch_attributes(101, {"existing": "keep"}, token=token),
        "list_sessions": lambda: authentik.list_sessions(101, OWNER_NAME, token=token),
        "delete_session": lambda: authentik.delete_session(S1, token=token),
        "logout_event_pages": lambda: list(authentik.logout_event_pages(token=token)),
    }
    observed: dict[str, tuple[tuple[str | None, Any, Any], list[bool]]] = {}
    for name, call in calls.items():
        before = len(ia73_authentik.requests)
        _, error = _attempt(call)
        observed[name] = (_failure(error), [request.authorized for request in ia73_authentik.requests[before:]])

    assert control == ((STATUS_ERROR, 403, False), [False])
    assert observed == dict.fromkeys(calls, ((None, None, None), [True]))


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_bad_arguments_make_no_call(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41(4B-4) — 인자 방어(모두 호출 0): find_user · find_group의 인자가 비지 않은 str이 아니면(None · 빈 문자열 · 정수 ·
    bytes — 조각 ⑤-b V4 ④) [](필터 `?uuid=None`을 보내 그 필드가 없는 항목을 None == None으로 고르지 않는다) ·
    patch_attributes의 attributes가 Mapping이 아니면(두 글자 문자열의 목록 — dict()가 사전으로 읽는다 · None) False ·
    username에 lone surrogate가 든 list_sessions → UpstreamUnavailable("invalid_request" · transient 거짓) · 예외에 그 값이 없다
    / 양성 대조(같은 준비물): 정상 인자의 다섯 호출은 1회씩 닿는다(dict가 아닌 Mapping — MappingProxyType — 의 attributes도
    받는다 · V4 ④)."""
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik, sessions=[make_session(101, S1)])
    control = (
        [user.get("pk") for user in authentik.find_user(OWNER_UUID)],
        [group.get("pk") for group in authentik.find_group(GROUP_NAME)],
        authentik.patch_attributes(101, {"existing": "keep"}),
        authentik.patch_attributes(101, MappingProxyType({"existing": "keep"})),
        _listing_view(authentik.list_sessions(101, OWNER_NAME)),
    )
    control_requests = len(ia73_authentik.requests)
    marker = f"ia41-{secrets.token_hex(6)}"
    calls: dict[str, Callable[[], Any]] = {
        "find_user-none": lambda: authentik.find_user(None),
        "find_user-empty": lambda: authentik.find_user(""),
        "find_user-int": lambda: authentik.find_user(5),
        "find_user-bytes": lambda: authentik.find_user(OWNER_UUID.encode()),
        "find_group-none": lambda: authentik.find_group(None),
        "find_group-empty": lambda: authentik.find_group(""),
        "find_group-int": lambda: authentik.find_group(5),
        "find_group-bytes": lambda: authentik.find_group(GROUP_NAME.encode()),
        "patch-pairs": lambda: authentik.patch_attributes(5, ["ab", "cd"]),
        "patch-none": lambda: authentik.patch_attributes(5, None),
    }
    skipped = {name: _attempt(call) for name, call in calls.items()}
    _, surrogate = _attempt(lambda: authentik.list_sessions(101, marker + LONE_SURROGATE))
    surrogate_view = (_failure(surrogate), _hygiene(surrogate, {"value": marker}))
    after = len(ia73_authentik.requests)

    assert (control, control_requests) == (([101], [GROUP_PK], True, True, ([S1], 1, False)), 5)
    assert skipped == {
        "find_user-none": ([], None),
        "find_user-empty": ([], None),
        "find_user-int": ([], None),
        "find_user-bytes": ([], None),
        "find_group-none": ([], None),
        "find_group-empty": ([], None),
        "find_group-int": ([], None),
        "find_group-bytes": ([], None),
        "patch-pairs": (False, None),
        "patch-none": (False, None),
    }
    assert surrogate_view == ((UNAVAILABLE_ERROR, "invalid_request", False), [])
    assert after == control_requests


@pytest.mark.usefixtures("ia73_env")
def test_ia_41_deadline_zero_makes_no_call(ia73_authentik: FakeAuthentikExt) -> None:
    """ia-41 — 양성 대조: 마감 5 s로 find_user → 1회 닿는다 / 마감 0 s → 메서드 여덟 모두 UpstreamUnavailable("deadline" ·
    transient 참) · 그 뒤 요청 0(호출자 — 위임 · 대조 작업 — 의 전체 마감이 메서드 안의 모든 호출에 걸린다)."""
    outbound = impl("outbound")
    authentik = impl("authentik")
    _seed_ia41(ia73_authentik, sessions=[make_session(101, S1)], events=[make_event(101, datetime.now(UTC))])
    control = [user.get("pk") for user in authentik.find_user(OWNER_UUID, deadline=outbound.Deadline(5))]
    control_requests = len(ia73_authentik.requests)
    calls: dict[str, Callable[[Any], Any]] = {
        "find_group": lambda deadline: authentik.find_group(GROUP_NAME, deadline=deadline),
        "find_user": lambda deadline: authentik.find_user(OWNER_UUID, deadline=deadline),
        "get_user": lambda deadline: authentik.get_user(101, deadline=deadline),
        "add_user": lambda deadline: authentik.add_user(GROUP_PK, 102, deadline=deadline),
        "patch_attributes": lambda deadline: authentik.patch_attributes(101, {}, deadline=deadline),
        "list_sessions": lambda deadline: authentik.list_sessions(101, OWNER_NAME, deadline=deadline),
        "delete_session": lambda deadline: authentik.delete_session(S1, deadline=deadline),
        "logout_event_pages": lambda deadline: next(authentik.logout_event_pages(deadline=deadline)),
    }
    refused: dict[str, tuple[str | None, Any, Any]] = {}
    for name, call in calls.items():
        _, error = _attempt(lambda call=call: call(outbound.Deadline(0)))
        refused[name] = _failure(error)

    assert (control, control_requests) == ([101], 1)
    assert refused == dict.fromkeys(calls, (UNAVAILABLE_ERROR, "deadline", True))
    assert len(ia73_authentik.requests) == 1
