"""OpenFGA 쓰기 클라이언트(T073 설계 D20 · D19 7단계 — pod 소유 새 파일) — seed_tenant가 테넌트 관계 튜플을 쓴다.

정본: data-model.md §1(파생 쓰기 규칙 — OpenFGA) · §10(모델 · 튜플 꼴 `user:<sub>` owner|member `tenant:<uuid>`) ·
contracts/identity-admin-api.md §타임아웃 · 재시도(identity-admin → OpenFGA(시드) 5 s · 재시도 없음) · 설계 D19 7단계 · D20.
표준 라이브러리 + outbound만 쓴다(openfga-sdk를 들이지 않는다 — aiohttp 의존 트리 · 숨은 재시도 · 설계 D20 「기각」).

write_tuples(tuple_keys) -> None
- `POST <OPENFGA_API_URL>/stores/<OPENFGA_STORE_ID>/write` 한 번 · 본문 `{"writes": {"tuple_keys": [{"user", "relation",
  "object"} …], "on_duplicate": "ignore"}}` — 이미 있는 튜플은 건너뛰고 새 튜플만 쓴다. 한 요청의 일괄 쓰기는 원자적이라 중복
  400을 성공으로 삼키면 빠진 튜플을 놓친다(data-model §1). 인증은 `Authorization: Bearer <OPENFGA_PRESHARED_KEY>`(outbound의 헤더
  조립 — 키 글자 규칙 `[!-~]+`도 거기서 본다 · 아니면 호출 0 · invalid_request).
- 설정 셋(URL · store id · 키)은 호출 때 읽는다. store id는 경로 성분이라 outbound.build_url이 꼴(`[A-Za-z0-9_-]{1,64}`)을 본 뒤
  넣는다 — 아니면 호출 0 · UpstreamUnavailable("invalid_request")(설계 D20 · W5 — conf 교차 규칙이 아니라 호출 시점 검사다 ·
  segments는 튜플이다). OpenFGA HTTP API 경로라 끝 슬래시를 붙이지 않는다.
- 시간은 outbound의 소켓 동작마다 5 s · 재시도 없음. 2xx가 아니면 UpstreamStatus(status) · 그 밖의 실패는 UpstreamUnavailable(kind)
  — outbound 오류 형 그대로다(문구 · args에 상태 코드나 종류만 · 연쇄 없음). 응답 본문(`{}`)은 쓰지 않는다 — 판정은 쓰기 응답의
  상태로만 한다(설계 G14).
- 자리값 자격 · 쓰기 플래그는 보지 않는다 — 부를지 정하는 것은 호출자(seed_tenant)의 몫이다(설계 D18 · authentik.py와 같다).

STORE_ID_FORM — store id 꼴(fullmatch) 상수. outbound.build_url의 str 성분 검사와 같은 꼴이고(위 호출 시점 검사는 outbound가 그대로
한다), seed_tenant가 DB를 쓰기 전(2단계)에 이 상수로 미리 본다(data-model §1 「세부」 T073 보정 2026-11-16).

import 시점에 객체 · 연결 · 설정 읽기가 없다. 로그를 내지 않는다(설계 D25).
"""

from __future__ import annotations

import re
from collections.abc import Iterable

from django.conf import settings

from identity_admin import outbound

__all__ = ["ON_DUPLICATE", "STORE_ID_FORM", "write_tuples"]

ON_DUPLICATE = "ignore"  # 이미 있는 튜플은 건너뛴다(OpenFGA write 요청의 writes.on_duplicate — 설계 D19 7 · 조사 E18)
# store id(경로 성분)의 꼴 — outbound._SEGMENT_RE(build_url의 str 성분 검사)와 같은 정규식이다(seed 2단계의 사전 검사가 쓴다)
STORE_ID_FORM = re.compile(r"[A-Za-z0-9_-]{1,64}")


def write_tuples(tuple_keys: Iterable[tuple[str, str, str]]) -> None:
    """(user, relation, object) 튜플들을 한 요청으로 쓴다(on_duplicate ignore) — 실패는 outbound 오류 형(모듈 독스트링)."""
    url = outbound.build_url(
        settings.OPENFGA_API_URL, ("stores", settings.OPENFGA_STORE_ID, "write"), trailing_slash=False
    )
    keys = [{"user": user, "relation": relation, "object": target} for user, relation, target in tuple_keys]
    body = {"writes": {"tuple_keys": keys, "on_duplicate": ON_DUPLICATE}}
    outbound.request_json("POST", url, token=settings.OPENFGA_PRESHARED_KEY, body=body)
