"""django_common.observability · django_common.health 계약 시험(T071 소유 · D11 oc-1..66) — T063 tests/test_observability.py
(obs-1..21)가 고정하지 않은 결정을 가른다.

설계 정본: specs/003-platform-foundation/design/build-notes.md 「## T071」(사실 ①–⑫ · 계약 보정 C1–C5 · 결정 D1–D15)과 「T071 r1
결과 · r2 결정」(Y1–Y7 — r2에서 더하거나 바꾼 사례는 독스트링에 〔r2 Yn〕을 단다) · 「T071 r2 결과 · r3 결정」(Z1–Z8 — r3에서 더하거나
바꾼 사례는 〔r3 Zn〕) · 「T071 r3 결과 · r4 결정」(Q1 · Q3 — r4에서 더하거나 바꾼 사례는 〔r4 Qn〕) · 「T071 r4 결과 · r5
결정」(P1–P5 — r5에서 더하거나 바꾼 사례는 〔r5 Pn〕) · 「T071 r5 결과 · r6 결정」(G1 · G2 · G8 — r6에서 더하거나 바꾼 사례는
〔r6 Gn〕) · 「T071 r6 결과 · r7 결정」(S1 · S5 — r7에서 더하거나 바꾼 사례는 〔r7 Sn〕) · 「T071 r7 결과 · r8 결정」(L1 · L2 —
r8에서 더하거나 바꾼 사례는 〔r8 Ln〕 · 메시지를 더한 단언 32줄은 아래 〔r8 L1〕 문단이 덮는다) · 「T071 r8 결과 · r9 결정」(K1 ·
K3 — r9에서 더하거나 바꾼 사례는 〔r9 Kn〕 · K2는 pyproject addopts) · 「T071 r9 결과 · r10 결정」(I1 · I2 — r10에서 넓힌
oc-66 판정은 〔r10 I1〕 · 공유 실행 원칙은 아래 〔r10 I2〕 문단과 pyproject 주석). 계약: contracts/pod-template.md §런타임 계약
「로그」 · 「트레이스 · Sentry」 · §django-common 공개 API · contracts/identity-admin-api.md 헬스 표 · 타임아웃 표 /health 행 ·
§관측(「T071 보정 2026-11-05」 · 「T071 r2」 · 「T071 r3」 · 「T071 r4」 · 「T071 r5」 · 「T071 r6」 · 「T071 r7」 · 「T071 r8」) ·
규칙 .claude/rules/django-pod.md §Logging · §Tests(django-common의 --show-capture=no · 공유 실행 원칙).

- 로그(D2): 확장 마스킹 키 · 닫힌 이름 목록 · bytes 키 · 헤더 쌍(oc-1 〔r2 Y4〕) · 재귀 꼴 · 순환 · 깊이 · 비str 키(oc-2) · 실제
  sink 경로의 마스킹 · 레코드 extra 버림 · 원본 레코드 msg의 마스킹(oc-3 — msg 단언은 변이 실행에서 생존한 M14를 잡으려고 빨강 뒤에
  더했다 · 보고 ②) · JSON 폴백(repr 금지 — oc-4) · 예외 렌더에 지역 변수 없음(oc-5) · configure_logging 재호출 · 다른 핸들러 · 기존
  로거 · 레벨(oc-6) · 쓰기 · 렌더 실패 = 고정 줄(oc-53 〔r2 Y4〕) · 모르는 수준 이름(oc-54 〔r2 Y6〕) · 더한 이름 · 접미 · 접두 · 쿠키
  접두 · camelCase · memoryview 키와 남는 이웃(oc-1 〔r3 Z4〕) · 실제 sink의 META · headers · COOKIES 덤프(oc-56 〔r3 Z4〕) · Django
  인증 폼 비밀번호 필드 · request.POST 꼴 QueryDict(oc-1 〔r5 P2〕) · camelCase 머리글자 경계와 남는 이웃(oc-1 〔r5 P3〕) ·
  camelCase 세 꼴 판정 — 머리글자 뒤 소문자 낱말 꼴(oc-1 〔r6 G2〕).
- 미들웨어(D3): 500 경로 응답 헤더(oc-7) · ip 없음(oc-8) · request.user 미접근(oc-9) · code · route · duration_ms(oc-10) · 앞
  요청 contextvars 차단(oc-11) · problem 슬러그(oc-12 · T070 r4 V6).
- sub_hash(D4): 공식 · SECRET_KEY 파생(oc-13) · 로그 값 = span 값(oc-14).
- OTel(D5): 거부 env 일곱 · import 때 굳은 요청 속성 목록(oc-15 〔r2 Y1〕) · 샘플러 없음 = 0.1(oc-16) · 무효 샘플러 · ARG(oc-17) ·
  스킴 없는 엔드포인트(oc-18) · 엔드포인트 없음 · 빈 값 = 내보내기 0 · WARNING 한 줄(oc-19) · Resource · APP_VERSION · pod 이름
  꼴(oc-20) · 전역 provider 1회(oc-21 — 새 프로세스) · gunicorn RAW_URI의 http.target(oc-22) · 비샘플 요청 로그(oc-23) · 계측
  미들웨어가 MIDDLEWARE에 없으면 거부(oc-55 〔r2 Y6〕) · 거부 env 아홉(oc-15 〔r3 Z1〕 — OTEL_PROPAGATORS · CAPTURE_ALL_METHODS) · 운영
  경로(env가 OTel import 전에 있다 · 새 프로세스): OTel import 전 env 검사(oc-57) · 공백뿐인 요청 속성 env 받음(oc-58) · Django 계측
  지표 끔(oc-59) · import 때 굳은 값 확인 (a) · (b) · (c)(oc-60 〔r3 Z1〕) · OTEL_PROPAGATORS 해석 규칙(쉼표 · str.strip — 탭 · 유니코드
  공백 포함 · 대소문자 · 빈 토큰)은 OTel과 같다(oc-15 사례 · OTel _load_propagators와의 대조 oc-63 · 운영 경로의 대소문자 토큰 거부와
  기본 밖 받음 값 oc-64 〔r4 Q1〕) · 받는 이름은 OTel보다 좁다(OTel이 받는 none · sentry도 거부 — oc-15 · 의도된 좁힘 고정 oc-63
  〔r5 P1〕) · 굳은 값 helper의 판 올림 경로(모듈 · 속성 · 이름 없음 — oc-65 〔r4 Q3〕) · 거부 env 열하나(oc-15 〔r5 P5〕 — OTLP 헤더
  둘 · 엔드포인트를 둔 채 OTel 로거 WARNING 0) · 거부 env 열일곱(〔r6 G1〕 — mTLS 클라이언트 키 · 인증서 env 넷(oc-15) · 엔드포인트
  env 둘의 닫힌 꼴 밖 값(oc-18) · 둘 다 span_exporter와 무관 · 받는 꼴 · 받음 사례의 클러스터 DNS 이름은 조회되지 않는다) ·
  엔드포인트 스킴의 대소문자 무시는 ASCII로만(〔r7 S1〕 — ſ(U+017F)가 든 스킴은 거부 · oc-18).
- Sentry(D7 — 가로채는 Transport · 실제 WSGIHandler 경로 · 시험마다 isolation scope · 정리 = close → set_client(None)): 빈 DSN =
  init 없음(oc-24) · init 인자 · 통합 집합 · 경고 0(oc-25) · 설정 오류(oc-26) · 뷰 예외 이벤트의 값 없음 · 태그(oc-27) · trace_id
  태그(oc-28) · 로그 · DisallowedHost · 예외 없는 503 → 이벤트 0(oc-29) · before_send 예외 → 이벤트 0(oc-30) · before_send
  단위(oc-31) · 나가는 http.client 요청 헤더(oc-32) · 세션 envelope 0(oc-33) · auth 설정 오류 500 세 경로(oc-34 Bearer 프레임 ·
  oc-35 Access 프레임 · oc-36 DRAGONFLY_URL · sub · sid — T070 인계 U7 · W4 · X7 · F4) · 클라이언트가 정한 상관 값(꼴 밖
  X-Request-ID · 위조 sentry-trace · baggage)이 이벤트 · envelope 머리에 없음(oc-52 〔r2 Y3〕) · 요청 헤더 허용 목록에 traceparent
  없음 · 꼴 밖 traceparent 원문 없음(oc-31 · oc-52 〔r3 Z2〕) · sentry_sdk.init 실패(꼴이 틀린 사용자 정보 프록시 env · init 대역의
  Exception) = 예외 클래스 이름만 실은 설정 오류 · 연쇄 예외 없음 · 클라이언트 비활성 · 네트워크 0 · BaseException은 그대로
  올라온다(oc-26 〔r8 L2〕) · 프록시 사용자 이름도 감시 값 · 메시지는 기대 문자열 전체와 같다(oc-26 〔r9 K3〕).
- 헬스(D6): 블랙홀 3종 병렬(oc-37) · 마감 2.5 s(oc-38) · 진행 중 상한은 검사 칸마다 8(oc-39 · oc-47..51 〔r2 Y2〕 — oc-51은 대역
  probe 진입 수를 기다린 뒤 센다 〔r3 Z7〕) · 요청 스레드의 열린 연결(oc-40) · Kafka 설정 오류 = fail(oc-41) · 쿼리 붙은
  DRAGONFLY_URL = 다이얼 0(oc-42) · auth를 건 API에서도 200 · OpenAPI(oc-43) · 본문 꼴 · unknown(oc-44) · 스레드를 만들거나 시작하지
  못하면 그 검사만 곧바로 fail · 자리는 정확히 한 번 놓는다(oc-61 〔r3 Z3〕) · BaseException은 올라오고 자리는 돌아온다(oc-62) ·
  시작한 뒤 예외면(Exception · BaseException) 그 작업 스레드가 살아 있는 동안 자리를 쥔다(oc-61 · oc-62 〔r5 P4〕) · ident를 못 본
  경합 대역에서도 자리는 한 번만 놓인다(oc-61 〔r5 보강〕).
- import 부작용 0 · 공개 이름(oc-45 — 새 프로세스).
- librdkafka 로그(D9): /health Kafka 검사 클라이언트 설정 = client_config() + log_level 0(oc-46 — 변이 실행에서 생존한 M60을 잡으려고
  빨강 뒤에 더했다 · 보고 ②).
- 자기 점검: 이 모듈의 시험 함수는 단언 재작성을 거치지 않았다(oc-66 〔r9 K1〕 — 아래 〔r8 L1〕 · 〔r9 K1〕 문단) · 판정은 @로
  시작하는 지역 이름 전부이고, 모듈 독스트링의 표식 낱말도 직접 본다(oc-66 〔r10 I1〕).

값 없음 단언은 입력(헤더 · 쿼리 · 쿠키 · 본문 · 지역 변수 · repr · XFF · sub · sid · 설정 URL · 프록시 env)에 시험이 실행 때
만든 감시 문자열(SENTINEL — `oc-<이름>-<무작위 hex>`)을 심어 공허하지 않게 한다(T069 J9). 이름에 비밀 낱말을 쓰지
않는다(gitleaks).

〔r8 L1〕 이 모듈은 pytest 단언 재작성을 끈다(표식 PYTEST_DONT_REWRITE — pytest는 모듈 독스트링에서 이 낱말을 찾는다). 그래서
단언이 실패해도 피연산자 값 · 비교 설명이 실리지 않고, 실패 출력에는 소스 줄과 단언 메시지(이름표)만 실린다 — 지금의 단언과
앞으로 더할 단언이 함께 그렇다. 단언 메시지에는 이름표 · 시험이 정한 이름 목록(감시 값 이름 · 키 · 로거 · 함수 이름) · 수(줄 수 ·
칸 수 · 경과 시간 · 종료 코드) · 시험이 정한 후보 상수만 싣는다 — 감시 값 · 입력 원문 · 이벤트 dict는 싣지 않는다. 진단이 필요한
이름 목록 단언(시험이 정한 이름 집합의 부분 목록을 `== []`로 견주는 단언 — _leaks · 남은 이름 · 다른 이름표)은 같은 식을 메시지로
되풀이한다(비교 식은 그대로다). 대가: 실패 출력에 값 비교 설명이 없다 — 디버깅 때는 표식을 잠시 빼고 로컬에서만 돌린다(그 출력은
공유하지 않는다). 감시 값 노출은 여전히 이름 목록(_leaks)으로 판정하고, 앞 라운드의 접기도 그대로 둔다(이름표가 실패 자리를
알려 준다): 〔r6 G8〕 감시 값이 든 구조를 그대로 견주던 앞 단언(oc-1 · oc-3 · oc-27 · oc-31)은 같은 비교를 bool로 접었다(`same =
<같은 식>` 다음 `assert same, "<이름표>"`).
〔r7 S5〕 실패하면 감시 값을 찍을 수 있던 잠재 단언(oc-1 meta · items · headers · top_pair · oc-3 probe meta · oc-27 url의 `?` ·
oc-31 request url · unrecorded contexts · out contexts)도 같은 방식으로 접었다(oc-3 probe meta는 r1 변이 M03, oc-1 top_pair는 r2 ·
r3 변이 Y4-8x 로그에 실패 자리로 나온 적이 있다).
〔r9 K1〕 재작성을 끈 모듈의 assert는 python -O · PYTHONOPTIMIZE에서 컴파일 때 지워진다 — 모듈 머리(from __future__ 다음)의
가드가 그 실행에서 수집을 RuntimeError로 끝낸다(보통 실행에서는 컴파일러가 그 블록을 지운다). 표식이 빠져 재작성이 켜지면 시험
함수의 지역 이름에 재작성 임시 변수(@py_assert…)가 생겨 oc-66이 실패한다(표식을 잠시 뺀 로컬 디버깅 실행에서도 그렇다).
〔r9 K2〕 pytest가 실패 보고에 붙이는 Captured log · stdout · stderr 칸은 django-common pyproject addopts의 --show-capture=no가
닫는다 — 위 「실패 출력」 문장은 이 기본과 아래 공유 실행 원칙 위에서 맞다. 〔r10 I2〕 공유 실행(CI 포함)은 패키지 설정을 쓴다:
packages/django-common에서 돌리거나 그 안의 경로만 주어 그 pyproject.toml이 ini로 골라지게 한다 · python -O · PYTHONOPTIMIZE로
돌리지 않는다(위 〔r9 K1〕 — 이 모듈은 수집을 거부하고, 그 밖의 맨 assert는 조용히 지워진다) · 실패 출력을 넓히는 옵션(규칙
§Tests의 목록 — -l/--showlocals · --tb=long · --full-trace · no가 아닌 --show-capture · log_cli/--log-cli-level ·
--log-file/log_file · no가 아닌 junit_logging)을 더하지 않는다. 그런 옵션은 디버깅 때 로컬에서만 쓰고 그 출력은 공유하지 않는다.

인프라: conftest T060–T063 픽스처(log_sink · log_lines · pg · jwks_server · settings) + tests/_obs_fakes.py(가로채는 Transport ·
헤더 기록 서버 · 수락 계수 리스너 · 블랙홀 · WSGIHandler 호출) + tests/obscontractapp/(urlconf · 뷰 · request.user 탐지
미들웨어). 모든 주소는 127.0.0.1이다. DB 마크(django_db(transaction=True))는 /ready · /health의 DB 판정을 보는 시험(oc-37 ·
oc-38 · oc-40 · oc-44 · oc-47)에만 있다 — 나머지에서 DB 검사는 pytest-django 차단으로 fail이 된다(그 시험은 DB 항목을 단언하지
않는다). OTEL_* · SENTRY_* env는 시험마다 지운다(개발자 환경 값이 판정에 끼지 않게).

헬스 칸 시험(oc-39 · oc-47..51 〔r2 Y2〕 · oc-61 · oc-62 〔r3 Z3〕)은 칸 객체(health._SLOTS)를 직접 쥐거나 probe 대역(_FakeProbe —
알리기 전 · 알린 뒤 Event로 붙든다)을 쓴다. 시험이 채운 칸은 그 시험 안에서 비우고, 대역이 만든 스레드는 끝날 때까지 기다린다(뒤
시험 · 묶음 실행에 남지 않게). 시작 실패 시험은 이름이 정해진 검사 스레드의 생성 · 시작만 실패시키고, 끝나면 그 칸에서 샌 자리를
돌려놓는다(단언은 돌려놓기 전에 잰 여유로 한다).

전역 OTel 상태(전역 textmap · semconv 모드 · 계측 미들웨어 클래스 속성 · sys.modules 항목 · _StabilityMode 이름)를 바꾸는
시험(oc-15 · oc-60 · oc-65)은 MonkeyPatch 문맥 안에서만 바꾸고 나가면 되돌린다. env가 import 전에 있어야 하는 운영 경로(oc-21 ·
oc-45 · oc-53 · oc-57..59 · oc-64)는 새 프로세스에서 본다.

〔r5 P1〕 oc-63은 sentry-sdk가 등록한 propagator entry point를 적재한다(sentry_sdk.integrations.opentelemetry import) — 그 전후의 전역
textmap · Sentry 전역 상태(scope 셋 · 그 클라이언트 · 전역 이벤트 처리기)가 같음을 확인하고, 바뀌었으면 되돌린 뒤 되돌림을 단언한다.
〔r5 P5〕 oc-15의 OTLP 헤더 사례는 opentelemetry 로거를 caplog 처리기로만 받는다(그 블록 동안 전파를 꺼 pytest 보고의 캡처 로그 절에
OTel 메시지 원문이 실리지 않게 — 단언은 (로거 이름, 수준)만 쓴다). 〔r6 G1〕 oc-15의 mTLS 클라이언트 자격 사례와 oc-18의 엔드포인트
사례도 같다. 받음 사례의 클러스터 DNS 이름은 socket.getaddrinfo 대역이 이름만 기록하고 조회 없이 막는다(조회 0을 단언한다).

빨간 상태: T071 구현 전에는 모듈 머리의 `from django_common import health, observability`가 ImportError(수집 단계 — 원인은 모듈
부재)다. r2 사례는 r1 구현에서 실패한다(보고 ② — r1이 이미 맞는 Y6 사례는 변이로 판별력을 보였다). r3 사례는 r2 구현에서
실패한다(r3 보고 ② — r2가 이미 맞는 사례는 변이로 판별력을 보였다). r4 사례는 r3 구현에서 실패한다(r4 보고 ② — r3가 이미 맞는
사례는 변이로 판별력을 보였다). r5 사례는 r4 구현에서 실패한다(r5 보고 ② — r4가 이미 맞는 사례는 변이로 판별력을 보였다). r6
사례는 r5 구현에서 실패한다(r6 보고 ② — r5가 이미 맞는 사례와 G8 접기는 변이로 판별력을 보였다). r7 사례(S1)는 r6 구현에서
실패한다(r7 보고 ② — S5 접기는 같은 식을 bool로 바꿀 뿐이라 동작이 같다). r8 사례(L2 — 프록시 env · init 대역의 ValueError)는 r7
구현에서 실패한다(r8 보고 ② — r7이 이미 맞는 BaseException 사례는 변이로 판별력을 보였다 · L1 표식과 메시지는 판정을 바꾸지
않는다). r9 사례(K1 가드 · oc-66 · K3 강화)는 r8 구현에서도 통과한다(r9 보고 ② — 모두 강화라 판별력은 변이 K1-1 · L2-5로
보였다).
"""

from __future__ import annotations

# 〔r9 K1〕 -O · PYTHONOPTIMIZE 가드 — 이 모듈은 단언 재작성을 끄므로(모듈 독스트링 〔r8 L1〕) 그 실행에서는 assert가 컴파일 때
# 지워져 시험이 공허하게 통과한다. 수집을 여기서 끝낸다(메시지에 값 없음). 보통 실행에서는 컴파일러가 이 블록을 지운다.
if not __debug__:
    raise RuntimeError("이 모듈은 단언 재작성을 끈다(PYTEST_DONT_REWRITE) · -O · PYTHONOPTIMIZE에서는 assert가 지워지므로 돌리지 않는다")

import datetime as dt
import decimal
import inspect
import io
import json
import logging
import os
import re
import secrets
import socket
import subprocess
import sys
import threading
import time
import traceback
import urllib.request
import uuid
import warnings
from collections.abc import Callable, Iterator, Mapping
from contextlib import contextmanager
from copy import deepcopy
from pathlib import Path
from typing import TYPE_CHECKING, Any, NoReturn

import pytest
import sentry_sdk
import structlog
from django.core.exceptions import ImproperlyConfigured
from django.db import connections
from django.http import QueryDict
from django.http.request import HttpHeaders
from django.test import Client, RequestFactory
from django.utils.crypto import salted_hmac
from opentelemetry import propagate
from opentelemetry.baggage.propagation import W3CBaggagePropagator
from opentelemetry.context import Context
from opentelemetry.instrumentation._semconv import (
    _OpenTelemetrySemanticConventionStability,
    _OpenTelemetryStabilitySignalType,
    _StabilityMode,
)
from opentelemetry.instrumentation.django import DjangoInstrumentor
from opentelemetry.instrumentation.django.middleware.otel_middleware import _DjangoMiddleware
from opentelemetry.propagators.composite import CompositePropagator
from opentelemetry.propagators.textmap import TextMapPropagator
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter
from opentelemetry.sdk.trace.sampling import ALWAYS_ON, ParentBased, TraceIdRatioBased
from opentelemetry.util.re import parse_env_headers
from sentry_sdk import scope as sentry_scopes
from sentry_sdk.integrations.logging import LoggingIntegration
from sentry_sdk.integrations.redis import RedisIntegration
from sentry_sdk.integrations.stdlib import StdlibIntegration

from django_common import health, observability
from django_common.kafka import client_config
from django_common.observability import (
    configure_logging,
    configure_otel,
    configure_sentry,
    mask_sensitive,
    sub_hash,
)
from tests import _jwt
from tests._obs_fakes import (
    CaptureTransport,
    CountingListener,
    HeaderRecorder,
    WsgiResult,
    blackhole,
    call_wsgi,
    closed_port,
)
from tests._problem import assert_problem
from tests._secret import Secret
from tests.obscontractapp import middleware as user_trap

if TYPE_CHECKING:
    from django.http import HttpResponse
    from opentelemetry.sdk.trace import ReadableSpan
    from pytest_django.fixtures import SettingsWrapper

    from tests.conftest import JwksInfo, LogLines

PACKAGE_ROOT = Path(__file__).resolve().parents[1]
OC_URLCONF = "tests.obscontractapp.urls"
REQUEST_ID_MIDDLEWARE = "django_common.observability.RequestIdMiddleware"
OC_MIDDLEWARE = (
    REQUEST_ID_MIDDLEWARE,
    "tests.testapp.middleware.HeaderTenantMiddleware",
    "tests.obsapp.middleware.HeaderClaimsMiddleware",
    "tests.obscontractapp.middleware.UserTrapMiddleware",
)
AUTH_MIDDLEWARE = (REQUEST_ID_MIDDLEWARE, "django_common.auth.JwtAuthMiddleware")
HOST_MIDDLEWARE = (REQUEST_ID_MIDDLEWARE, "django.middleware.common.CommonMiddleware")
REQUEST_ID = "X-Request-ID"
SUB = _jwt.BEARER_SUB
CHECK_NAMES = frozenset({"db", "dragonfly", "kafka_producer"})
# 계약(pod-template 「트레이스 · Sentry」 행)의 Sentry 요청 헤더 허용 목록(소문자 비교) — x-request-id는 없다(검증된 값은 태그
# request_id가 싣는다 〔r2 Y3〕) · traceparent도 없다(검증된 trace 문맥은 contexts.trace · 태그 trace_id가 기록 중 span일 때만
# 싣는다 〔r3 Z2〕).
SENTRY_HEADER_ALLOWLIST = frozenset({"host", "user-agent", "accept", "content-type", "content-length"})
# 127.0.0.1:9(닫힌 포트)를 가리키는 가짜 DSN — 전송은 CaptureTransport라 네트워크 0(비밀 아님 · 공개 키 자리는 낱말).
FAKE_DSN = "http://oc-public@127.0.0.1:9/1"
# 〔r8 L2〕 https 가짜 DSN(같은 닫힌 포트) · 꼴이 틀린 사용자 정보 프록시 URL의 범위 밖 포트 · 그 URL을 해석하다 urllib3가 내는 예외
# 클래스(urllib3 2.8.0 — 메시지에 URL이 실린다) · 사례마다 지우는 프록시 env(소문자 꼴도 — stdlib getproxies는 소문자 꼴이 이기고,
# REQUEST_METHOD가 있으면 HTTP_PROXY를 버린다 · NO_PROXY는 프록시를 건너뛰게 한다).
FAKE_HTTPS_DSN = "https://oc-public@127.0.0.1:9/1"
PROXY_BAD_PORT = 99999
PROXY_PARSE_ERROR = "LocationParseError"
PROXY_ENVS = ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY", "REQUEST_METHOD")
# 〔r9 K3〕 init 실패 메시지 전체(구현의 고정 문구 — {}에 예외 클래스 이름만 들어간다 · 값 없음). oc-26이 메시지를 이것과 통째로 견준다.
SENTRY_INIT_FAILURE = (
    "sentry_sdk.init이 {}로 실패했다(예외 메시지는 싣지 않는다 — Sentry 설정과 sentry-sdk가 읽는 env(프록시 · 인증서)를 확인한다)"
)
SENTRY_INTEGRATIONS = ["argv", "atexit", "dedupe", "django", "excepthook", "logging", "modules", "threading"]
BSP_THREAD = "OtelBatchSpanRecordProcessor"
DEADLINE_MS = 2500.0
# 헬스 검사 칸(/ready의 DB · /health의 세 항목)과 칸마다 살아 있는 검사 스레드 상한(계약 타임아웃 표 /health 행 〔r2 Y2〕).
HEALTH_SLOTS = ("ready", "db", "dragonfly", "kafka_producer")
SLOT_LIMIT = 8
HEALTH_THREAD = "django-common-health-"
DOWN_LIMIT_S = 3.0
HANG_LIMIT_S = 10.0
ABSENT = "<absent>"
# Django 계측 미들웨어의 단락 대역(뷰 · URL 해석 앞에서 403 — 지표 시험 〔r3 Z1〕).
SHORT_CIRCUIT_MIDDLEWARE = "tests.obscontractapp.middleware.ShortCircuitMiddleware"
# OTEL_PROPAGATORS 후보(이름표, 값 〔r4 Q1〕) — oc-15가 configure_otel의 거부 · 받음을 고정하고, oc-63이 같은 후보(+ 없음)를 OTel
# 해석(opentelemetry.propagate._load_propagators)과 견준다. 감시 값 사례는 oc-15에만 둔다. 실패 출력에는 이름표만 싣는다.
PROPAGATORS_REJECTED = (
    # 〔r3 Z1〕
    ("none", "none"),
    ("none-cased", " None "),
    ("tracecontext-none", "tracecontext,none"),
    ("baggage-only", "baggage"),
    ("empty-token", "tracecontext,,baggage"),
    # 〔r4 Q1〕 받음에서 옮겼다(계약 변경 r4 Q1 — OTel import가 그 값을 실은 ValueError로 끝난다)
    ("cased-pair", " TraceContext , baggage "),
    ("spaces", "   "),
    # 〔r4 Q1〕 더한 거부
    ("upper", "TRACECONTEXT"),
    ("trailing-comma", "tracecontext,"),
    ("leading-comma", ",tracecontext"),
    ("tab", "\t"),
    ("no-comma", "tracecontext baggage"),
    ("upper-baggage", " tracecontext ,BAGGAGE"),
)
PROPAGATORS_ACCEPTED = (
    # 〔r3 Z1〕
    ("tracecontext", "tracecontext"),
    ("reordered", "baggage,tracecontext"),
    ("empty", ""),
    # 〔r4 Q1〕 더한 받음(앞뒤 공백 · 겹침 · 순서)
    ("spaced-pair", " tracecontext , baggage "),
    ("repeated", "tracecontext,tracecontext"),
    ("mixed-repeated", "baggage, tracecontext,baggage"),
)
# 〔r5 P1〕 의도된 좁힘 — OTel은 받고(설치된 entry point · fields에 traceparent) 우리는 거부한다: sentry-sdk가 등록한 sentry
# (SentryPropagator — 클라이언트 sentry-trace를 원격 부모로 삼고 나가는 요청에 sentry-trace · baggage를 싣는다). oc-15가 거부를,
# oc-63이 「우리 거부 · OTel 받음」을 함께 고정한다(sentry-sdk가 그 entry point를 거두면 oc-63이 실패해 계약 문장을 다시 보게 한다).
PROPAGATORS_NARROWED = (("sentry-pair", "tracecontext,sentry"),)
# 〔r6 G1〕 OTLP 엔드포인트 env 둘(TRACES가 비면 일반 값 — 각 env를 따로 본다) · mTLS 클라이언트 키 · 인증서 env 넷(계약 「트레이스 ·
# Sentry」 행 — 거부 env 열일곱). PEM 꼴 시험 값은 머리 줄 뒤에 감시 값만 둔다(실제 키 · 인증서 꼴이 아니다 — _pem_like).
TRACES_ENDPOINT = "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"
GENERAL_ENDPOINT = "OTEL_EXPORTER_OTLP_ENDPOINT"
ENDPOINT_ENVS = (TRACES_ENDPOINT, GENERAL_ENDPOINT)
OTLP_MTLS_ENVS = (
    "OTEL_EXPORTER_OTLP_CLIENT_KEY",
    "OTEL_EXPORTER_OTLP_TRACES_CLIENT_KEY",
    "OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE",
    "OTEL_EXPORTER_OTLP_TRACES_CLIENT_CERTIFICATE",
)
PEM_LABEL = "PRIVATE KEY"
# 받음 사례의 클러스터 DNS 이름 조각(_name_lookups가 이 조각이 든 이름의 조회를 기록하고 막는다).
CLUSTER_NAME_FRAGMENT = "alloy"


# --- 헬퍼 ------------------------------------------------------------------------------------------------------


def _sentinel(name: str) -> str:
    """감시 문자열 `oc-<이름>-<16 hex>`(실행 때 만든다 — 소스 · 출처 줄에 나타나지 않는다 · 헤더 · URL · 클레임에 안전한 글자)."""
    return f"oc-{name}-{secrets.token_hex(8)}"


def _leaks(text: str, needles: Mapping[str, str]) -> list[str]:
    """needles(이름 → 감시 값) 가운데 text에 나타난 것의 이름 목록 — 값은 Secret으로 감싸 실패 출력에 실리지 않는다."""
    haystack = Secret(text)
    return sorted(name for name, value in needles.items() if value and Secret(value) in haystack)


def _events(records: list[dict[str, Any]], event: str) -> list[dict[str, Any]]:
    return [record for record in records if record.get("event") == event]


def _one(records: list[dict[str, Any]], event: str) -> dict[str, Any]:
    matches = _events(records, event)
    assert len(matches) == 1, f"{event} 줄 수 {len(matches)}"
    return matches[0]


def _for_request(records: list[dict[str, Any]], request_id: str) -> list[dict[str, Any]]:
    return [record for record in records if record.get("request_id") == request_id]


def _finished(records: list[dict[str, Any]], response: HttpResponse) -> dict[str, Any]:
    """응답 헤더 X-Request-ID로 그 요청의 request_finished 줄 하나를 찾는다."""
    return _one(_for_request(records, response[REQUEST_ID]), "request_finished")


def _fail_without_trace(what: str, exc: BaseException) -> NoReturn:
    """예외를 원 트레이스백 · 메시지 없이 실패로 바꾼다(psycopg conninfo 인자의 비밀번호가 긴 트레이스백에 실리지 않게 —
    tests/test_observability.py와 같은 이유 · 호출자는 except 블록 밖에서 부른다)."""
    kind = f"{type(exc).__module__}.{type(exc).__name__}"
    pytest.fail(f"{what}: 예외로 끝났다({kind}) — 원 트레이스백 · 메시지는 싣지 않는다", pytrace=False)


def _safe_get(client: Client, path: str, **kwargs: Any) -> HttpResponse:
    failure: BaseException | None = None
    try:
        response = client.get(path, **kwargs)
    except Exception as exc:  # noqa: BLE001 — 어떤 예외든 원 트레이스백 없이 실패로 바꾼다
        failure = exc
    else:
        return response
    _fail_without_trace(f"GET {path}", failure)


def _timed_get(client: Client, path: str) -> tuple[HttpResponse, float]:
    """GET 한 번과 경과 시간(초) — 데몬 스레드에서 돈다(HANG_LIMIT_S 안에 끝나지 않으면 실패 · 그 스레드의 DB 연결은 닫는다)."""
    outcome: list[HttpResponse | BaseException] = []

    def run() -> None:
        try:
            outcome.append(client.get(path))
        except BaseException as exc:  # noqa: BLE001 — 스레드 경계: 어떤 예외든 호출 스레드로 넘긴다
            outcome.append(exc)
        finally:
            connections.close_all()

    worker = threading.Thread(target=run, name="oc-timed-get", daemon=True)
    started = time.perf_counter()
    worker.start()
    worker.join(HANG_LIMIT_S)
    elapsed = time.perf_counter() - started
    if worker.is_alive():
        pytest.fail(f"GET {path}가 {HANG_LIMIT_S:.0f} s 안에 끝나지 않았다")
    result = outcome[0]
    if isinstance(result, BaseException):
        _fail_without_trace(f"GET {path}", result)
    return result, elapsed


@contextmanager
def _db_at(host: str, port: int, *, connect_timeout: int) -> Iterator[None]:
    """default 별칭 연결 설정(settings.DATABASES["default"]와 같은 dict)을 host:port로 돌린다 — 끝나면 되돌린다.

    요청 스레드의 열린 연결은 먼저 닫는다. 작업 스레드의 새 연결은 이 dict를 그대로 쓴다. psycopg는 connect_timeout 2 s 미만을
    2 s로 올린다.
    """
    connection = connections["default"]
    original = deepcopy(connection.settings_dict)
    try:
        connection.close()
        connection.settings_dict["HOST"] = host
        connection.settings_dict["PORT"] = str(port)
        connection.settings_dict["OPTIONS"] = {**original["OPTIONS"], "connect_timeout": connect_timeout}
        yield
    finally:
        connection.close()
        connection.settings_dict.clear()
        connection.settings_dict.update(original)


def _response_text(response: HttpResponse) -> str:
    headers = "\n".join(f"{name}: {value}" for name, value in response.items())
    return f"{response.content.decode('utf-8', errors='replace')}\n{headers}"


def _span_text(span: ReadableSpan) -> str:
    """span의 이름 · 속성 · 이벤트 · 링크 · 상태 설명을 한 문자열로(누출 검사용)."""
    parts: list[str] = [span.name, str(span.status.description or "")]
    parts.extend(f"{key}={value!r}" for key, value in dict(span.attributes or {}).items())
    for event in span.events:
        parts.append(event.name)
        parts.extend(f"{key}={value!r}" for key, value in dict(event.attributes or {}).items())
    for link in span.links:
        parts.extend(f"{key}={value!r}" for key, value in dict(link.attributes or {}).items())
    return "\n".join(parts)


def _traceparent(*, sampled: bool) -> tuple[str, str]:
    """(trace id 32 hex, W3C traceparent) — sampled면 플래그 01 · 아니면 00."""
    trace_id = secrets.token_hex(16)
    return trace_id, f"00-{trace_id}-{secrets.token_hex(8)}-{'01' if sampled else '00'}"


def _bsp_threads() -> int:
    """살아 있는 BatchSpanProcessor 작업 스레드 수."""
    return sum(1 for thread in threading.enumerate() if thread.name == BSP_THREAD and thread.is_alive())


@contextmanager
def _otel(span_exporter: InMemorySpanExporter | None = None) -> Iterator[TracerProvider]:
    """configure_otel → (시험) → uninstrument · shutdown."""
    provider = configure_otel(span_exporter=span_exporter)
    try:
        yield provider
    finally:
        DjangoInstrumentor().uninstrument()
        provider.shutdown()


_FACTORY = RequestFactory()


def _environ(
    method: str, path: str, *, headers: dict[str, str] | None = None, body: bytes | None = None, **extra: Any
) -> dict[str, Any]:
    """RequestFactory로 만든 WSGI environ(call_wsgi 입력) — POST 본문은 application/json."""
    if method == "POST":
        request = _FACTORY.post(path, data=body or b"", content_type="application/json", headers=headers, **extra)
    else:
        request = _FACTORY.get(path, headers=headers, **extra)
    return dict(request.environ)


def _frames(event: Mapping[str, Any]) -> list[dict[str, Any]]:
    """이벤트의 스택 프레임 전부(exception.values[*] · threads.values[*]의 stacktrace.frames)."""
    frames: list[dict[str, Any]] = []
    for section in ("exception", "threads"):
        container = event.get(section)
        values = container.get("values", []) if isinstance(container, dict) else []
        for value in values:
            stacktrace = value.get("stacktrace") if isinstance(value, dict) else None
            if isinstance(stacktrace, dict):
                frames.extend(frame for frame in stacktrace.get("frames", []) if isinstance(frame, dict))
    return frames


def _function_names(event: Mapping[str, Any]) -> set[str]:
    """프레임 function 값의 마지막 조각(`Class.method` → `method`)."""
    return {str(frame.get("function", "")).rsplit(".", 1)[-1] for frame in _frames(event)}


def _breadcrumb_values(event: Mapping[str, Any]) -> list[Any]:
    crumbs = event.get("breadcrumbs")
    if isinstance(crumbs, dict):
        return list(crumbs.get("values", []))
    return list(crumbs or [])


def _header_names(event: Mapping[str, Any]) -> set[str]:
    request = event.get("request")
    headers = request.get("headers", {}) if isinstance(request, dict) else {}
    return {str(name).lower() for name in headers}


class _ListHandler(logging.Handler):
    """받은 레코드를 쌓는 stdlib 핸들러(다른 루트 핸들러 자리)."""

    def __init__(self) -> None:
        super().__init__(level=logging.DEBUG)
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


class _ReprProbe:
    """repr · str에 감시 값을 싣는 객체 — JSON 폴백이 repr · str을 쓰면 값이 샌다."""

    def __init__(self, marker: str) -> None:
        self.marker = marker

    def __repr__(self) -> str:
        return f"_ReprProbe({self.marker})"

    def __str__(self) -> str:
        return f"str:{self.marker}"


class _Exploding(Mapping[str, Any]):
    """항목을 읽으면 예외를 내는 Mapping — 마스킹은 예외를 내지 않아야 한다."""

    def __getitem__(self, key: str) -> Any:
        raise RuntimeError("oc-exploding-getitem")

    def __iter__(self) -> Iterator[str]:
        raise RuntimeError("oc-exploding-iter")

    def __len__(self) -> int:
        raise RuntimeError("oc-exploding-len")


def _child_env() -> dict[str, str]:
    """새 프로세스 env — 시험 설정 · OTEL_* · SENTRY_* · PROMETHEUS_MULTIPROC_DIR 제거."""
    env = {
        key: value
        for key, value in os.environ.items()
        if not key.upper().startswith(("OTEL_", "SENTRY_")) and key.upper() != "PROMETHEUS_MULTIPROC_DIR"
    }
    env["DJANGO_SETTINGS_MODULE"] = "tests.settings"
    return env


def _run_child(script: str) -> dict[str, Any]:
    """script를 이 인터프리터의 새 프로세스로 돌리고 마지막 줄 JSON을 돌려준다."""
    completed = subprocess.run(  # noqa: S603 — 이 인터프리터 · 고정 스크립트
        [sys.executable, "-c", script],
        cwd=PACKAGE_ROOT,
        env=_child_env(),
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    assert completed.returncode == 0, f"자식 프로세스 종료 코드 {completed.returncode}"
    lines = completed.stdout.strip().splitlines()
    assert lines, "자식 프로세스 출력이 비었다"
    result: dict[str, Any] = json.loads(lines[-1])
    return result


def _run_child_full(script: str) -> tuple[dict[str, Any], str]:
    """_run_child와 같되 자식의 stdout · stderr 전문도 돌려준다(감시 값이 출력 어디에도 없는지 보는 시험용 〔r3 Z1〕 — 전문은
    단언 피연산자로 쓰지 않고 _leaks로 접는다)."""
    completed = subprocess.run(  # noqa: S603 — 이 인터프리터 · 고정 스크립트
        [sys.executable, "-c", script],
        cwd=PACKAGE_ROOT,
        env=_child_env(),
        capture_output=True,
        text=True,
        timeout=180,
        check=False,
    )
    assert completed.returncode == 0, f"자식 프로세스 종료 코드 {completed.returncode}"
    lines = completed.stdout.strip().splitlines()
    assert lines, "자식 프로세스 출력이 비었다"
    result: dict[str, Any] = json.loads(lines[-1])
    return result, completed.stdout + completed.stderr


class _BrokenStream(io.StringIO):
    """write가 OSError를 내는 stream(stdout EPIPE 같은 쓰기 실패 — flush는 정상 · 〔r2 Y4〕)."""

    def write(self, text: str) -> int:
        raise OSError("oc-broken-stream")


class _BadClock(dt.datetime):
    """isoformat이 예외를 내는 datetime 하위형(JSON 렌더 실패 — repr는 된다 · 〔r2 Y4〕)."""

    def isoformat(self, *args: Any, **kwargs: Any) -> str:
        raise RuntimeError("oc-bad-clock")


def _emit_failure_shape(text: str) -> tuple[Any, ...]:
    """stderr 조각의 꼴 — 줄 하나 · JSON 객체 · 키가 정확히 ts · level · logger · event · error이고 ts가 ISO 8601 UTC면
    ("fixed", level, logger, event, error) · 아니면 ("other", 줄 수)(원문은 돌려주지 않는다 — 실패 출력에 값이 실리지 않게)."""
    lines = text.split("\n")
    if len(lines) != 2 or lines[1] != "":
        return ("other", len(lines))
    try:
        record = json.loads(lines[0])
        when = dt.datetime.fromisoformat(record["ts"])
    except (ValueError, KeyError, TypeError):
        return ("other", len(lines))
    if not isinstance(record, dict) or sorted(record) != ["error", "event", "level", "logger", "ts"]:
        return ("other", len(lines))
    if when.utcoffset() != dt.timedelta(0):
        return ("other", len(lines))
    return ("fixed", record["level"], record["logger"], record["event"], record["error"])


# --- 헬스 칸 도우미(〔r2 Y2〕) ---------------------------------------------------------------------------------------


class _FakeProbe:
    """헬스 probe 대역 — 부른 스레드를 기록하고(정리 때 join) ok를 알린다. hold_before는 알리기 전에(마감을 넘겨 버려진 상태),
    hold_after는 알린 뒤에(결과를 알리고 정리 중인 상태) 그 Event가 설 때까지 붙든다."""

    def __init__(
        self,
        ok: bool = True,
        *,
        hold_before: threading.Event | None = None,
        hold_after: threading.Event | None = None,
    ) -> None:
        self.ok = ok
        self.hold_before = hold_before
        self.hold_after = hold_after
        self._lock = threading.Lock()
        self._threads: list[threading.Thread] = []

    def __call__(self, done: Callable[[bool], None]) -> None:
        with self._lock:
            self._threads.append(threading.current_thread())
        if self.hold_before is not None:
            self.hold_before.wait(HANG_LIMIT_S)
        done(self.ok)
        if self.hold_after is not None:
            self.hold_after.wait(HANG_LIMIT_S)

    @property
    def calls(self) -> int:
        with self._lock:
            return len(self._threads)

    def wait_calls(self, count: int) -> bool:
        """probe에 들어온 스레드 수가 count가 될 때까지 기다린다(HANG_LIMIT_S) — 됐으면 True(〔r3 Z7〕 작업 스레드가 짧은 마감 안에
        probe에 들어온다는 가정 없이 센다)."""
        deadline = time.monotonic() + HANG_LIMIT_S
        while self.calls < count and time.monotonic() < deadline:
            time.sleep(0.01)
        return self.calls >= count

    def alive(self) -> int:
        with self._lock:
            return sum(1 for thread in self._threads if thread.is_alive())

    def join(self) -> bool:
        """기록한 스레드가 모두 끝나기를 기다린다(HANG_LIMIT_S) — 다 끝났으면 True."""
        with self._lock:
            threads = list(self._threads)
        for thread in threads:
            thread.join(HANG_LIMIT_S)
        return not any(thread.is_alive() for thread in threads)


@contextmanager
def _slots_full(*names: str) -> Iterator[dict[str, tuple[int, bool]]]:
    """헬스 칸을 상한까지 시험이 쥔다 — 앞 시험의 정리 중 스레드가 남았으면 끝나기를 기다린다(칸마다 8 s). 칸마다 (쥔 수, 상한 + 1번째
    acquire 결과)를 돌려주고(정상 = (SLOT_LIMIT, False)), 나가면 쥔 만큼 놓는다."""
    held: list[Any] = []
    observed: dict[str, tuple[int, bool]] = {}
    try:
        for name in names:
            slot = health._SLOTS[name]
            taken = 0
            deadline = time.monotonic() + 8.0
            while taken < SLOT_LIMIT and time.monotonic() < deadline:
                if slot.acquire():
                    held.append(slot)
                    taken += 1
                else:
                    time.sleep(0.05)
            overflow = slot.acquire()
            if overflow:
                held.append(slot)
            observed[name] = (taken, overflow)
        yield observed
    finally:
        for slot in held:
            slot.release()


def _wait_slot_free(name: str) -> None:
    """칸이 비었는지 확인한다(앞 시험의 정리 중 스레드가 끝나기를 기다린 뒤 상한까지 쥐었다 놓는다)."""
    with _slots_full(name) as observed:
        pass
    assert observed == {name: (SLOT_LIMIT, False)}, observed


@contextmanager
def _thread_starts() -> Iterator[list[str]]:
    """블록 안에서 시작한 모든 스레드의 이름(시작 순서)."""
    names: list[str] = []
    real_start = threading.Thread.start

    def counting_start(self: threading.Thread, *args: Any, **kwargs: Any) -> None:
        names.append(self.name)
        real_start(self, *args, **kwargs)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(threading.Thread, "start", counting_start)
        yield names


def _health_checks(client: Client) -> dict[str, Any]:
    """GET /health(200) 본문의 checks."""
    response = _safe_get(client, "/health")
    assert response.status_code == 200
    checks: dict[str, Any] = json.loads(response.content)["checks"]
    return checks


def _free_capacity(name: str) -> int:
    """칸의 지금 여유 — 기다리지 않고 얻을 수 있는 자리 수(상한까지 얻어 보고 곧바로 놓는다 · 〔r3 Z3〕)."""
    slot = health._SLOTS[name]
    taken = 0
    try:
        while taken <= SLOT_LIMIT and slot.acquire():
            taken += 1
    finally:
        for _ in range(taken):
            slot.release()
    return taken


def _restore_slot(name: str) -> int:
    """시험이 새게 한 칸 자리를 돌려놓고 그 수를 돌려준다(〔r3 Z3〕 — 그 칸에 살아 있는 검사 스레드가 없을 때만 부른다: 빨강 · 변이
    실행에서 샌 자리가 뒤 시험의 칸 단언을 흔들지 않게. 단언은 돌려놓기 전에 잰 여유로 한다)."""
    missing = SLOT_LIMIT - _free_capacity(name)
    for _ in range(missing):
        health._SLOTS[name].release()
    return missing


@contextmanager
def _thread_failure(name: str, where: str, error: BaseException) -> Iterator[list[str]]:
    """이름이 name인 스레드만 생성(where="init") · 시작(where="start")에서 error를 낸다(다른 스레드는 그대로 · 〔r3 Z3〕).
    where="started"면 실제로 시작한 뒤 error를 낸다(작업 스레드는 돈다 — 자리를 정확히 한 번 놓는지 본다). 낸 자리를 쌓는다."""
    real_init = threading.Thread.__init__
    real_start = threading.Thread.start
    raised: list[str] = []

    def failing_init(self: threading.Thread, *args: Any, **kwargs: Any) -> None:
        if kwargs.get("name") == name:
            raised.append("init")
            raise error
        real_init(self, *args, **kwargs)

    def failing_start(self: threading.Thread) -> None:
        if self.name != name:
            real_start(self)
            return
        if where == "started":
            real_start(self)
        raised.append(where)
        raise error

    with pytest.MonkeyPatch.context() as patch:
        if where == "init":
            patch.setattr(threading.Thread, "__init__", failing_init)
        else:
            patch.setattr(threading.Thread, "start", failing_start)
        yield raised


@contextmanager
def _hidden_ident(name: str) -> Iterator[None]:
    """블록 안에서 이름이 name인 스레드의 ident를 None으로 보인다(〔r5 보강〕 — start()의 예외가 새 스레드의 ident 설정보다 먼저 온
    경합의 대역: 시작 실패 경로는 「시작되지 않음」으로 보고 자리를 놓고, 실제로 도는 작업 스레드의 finally도 놓는다). 다른 스레드의
    ident는 원래 getter가 준다."""
    real_ident = threading.Thread.ident

    def ident(thread: threading.Thread) -> int | None:
        return None if thread.name == name else real_ident.fget(thread)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(threading.Thread, "ident", property(ident))
        yield


@contextmanager
def _thread_errors() -> Iterator[list[str]]:
    """블록 안에서 스레드가 처리하지 못한 예외의 클래스 이름(threading.excepthook — 〔r3 Z3〕 칸 자리를 두 번 놓으면
    BoundedSemaphore가 작업 스레드에서 ValueError를 낸다)."""
    seen: list[str] = []

    def hook(args: threading.ExceptHookArgs) -> None:
        seen.append(args.exc_type.__name__)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(threading, "excepthook", hook)
        yield seen


# --- 전역 trace 상태 · OTel 로거 도우미(〔r5 P1 · P5〕) ------------------------------------------------------------------


def _trace_globals() -> dict[str, Any]:
    """OTel 전역 textmap과 Sentry 전역 상태(scope 셋 · 그 클라이언트 · 전역 이벤트 처리기)의 지금 객체(〔r5 P1〕 — 같음은 is로,
    이벤트 처리기 목록은 tuple 같음으로 본다)."""
    global_scope = sentry_sdk.get_global_scope()
    isolation_scope = sentry_sdk.get_isolation_scope()
    current_scope = sentry_sdk.get_current_scope()
    return {
        "textmap": propagate.get_global_textmap(),
        "global_scope": global_scope,
        "global_client": global_scope.client,
        "isolation_scope": isolation_scope,
        "isolation_client": isolation_scope.client,
        "current_scope": current_scope,
        "current_client": current_scope.client,
        "event_processors": tuple(sentry_scopes.global_event_processors),
    }


def _changed_trace_globals(before: Mapping[str, Any]) -> list[str]:
    """before 뒤 바뀐 전역 trace 상태의 이름(바뀐 것이 없으면 [])."""
    now = _trace_globals()
    return sorted(
        name
        for name, value in before.items()
        if (now[name] != value if name == "event_processors" else now[name] is not value)
    )


def _restore_trace_globals(before: Mapping[str, Any]) -> list[str]:
    """바뀐 전역 trace 상태를 before로 되돌리고, 되돌리기 전에 바뀌어 있던 이름을 돌려준다(〔r5 P1〕 — 시험이 남긴 전역 상태가 뒤
    시험에 끼지 않게)."""
    changed = _changed_trace_globals(before)
    if "textmap" in changed:
        propagate.set_global_textmap(before["textmap"])
    if "global_scope" in changed:
        sentry_scopes._global_scope = before["global_scope"]
    if "isolation_scope" in changed:
        sentry_scopes._isolation_scope.set(before["isolation_scope"])
    if "current_scope" in changed:
        sentry_scopes._current_scope.set(before["current_scope"])
    for kind in ("global", "isolation", "current"):
        if f"{kind}_client" in changed:
            before[f"{kind}_scope"].client = before[f"{kind}_client"]
    if "event_processors" in changed:
        sentry_scopes.global_event_processors[:] = before["event_processors"]
    return changed


@contextmanager
def _otel_log_capture(caplog: pytest.LogCaptureFixture) -> Iterator[Callable[[], list[tuple[str, str]]]]:
    """opentelemetry 로거의 레코드를 caplog 처리기로만 받는다(〔r5 P5〕) — 블록 동안 그 로거 수준을 WARNING으로 두고 전파를 꺼,
    pytest 보고의 캡처 로그 절 · 다른 처리기에 OTel 메시지 원문(헤더 쌍 — 감시 값)이 가지 않게 한다. 돌려주는 함수는 마지막
    caplog.clear() 뒤 받은 opentelemetry 접두 로거의 WARNING 이상을 (로거 이름, 수준)으로만 준다(메시지는 단언 피연산자로 쓰지
    않는다)."""
    otel_logger = logging.getLogger("opentelemetry")
    saved_level, saved_propagate = otel_logger.level, otel_logger.propagate
    otel_logger.setLevel(logging.WARNING)
    otel_logger.propagate = False
    otel_logger.addHandler(caplog.handler)
    try:
        yield lambda: [
            (record.name, record.levelname)
            for record in caplog.records
            if record.name.startswith("opentelemetry") and record.levelno >= logging.WARNING
        ]
    finally:
        otel_logger.removeHandler(caplog.handler)
        otel_logger.propagate = saved_propagate
        otel_logger.setLevel(saved_level)


# --- OTLP 자격 통로 도우미(〔r6 G1〕) ----------------------------------------------------------------------------------


def _pem_like(needle: str) -> str:
    """PEM 꼴 시험 값 — PEM 머리 줄 뒤에 감시 값만 둔다(실제 키 · 인증서 꼴이 아니다)."""
    return f"-----BEGIN {PEM_LABEL}----- {needle}"


def _fullwidth(digits: str) -> str:
    """ASCII 숫자를 전각 숫자(U+FF10–U+FF19)로 바꾼다 — 유니코드 숫자 부류는 받고 ASCII 숫자 부류는 받지 않는 포트 꼴."""
    return "".join(chr(0xFF10 + int(digit)) for digit in digits)


def _configure_verdict(
    name: str, needles: Mapping[str, str], span_exporter: InMemorySpanExporter | None
) -> tuple[Any, ...]:
    """configure_otel 한 번의 판정 — 거부면 ("rejected", 메시지에 name이 있는가, 메시지에 실린 needles 이름, 연쇄 예외가 없는가) ·
    받으면 ("accepted",)(계측을 거두고 provider를 닫는다). 메시지 · 값은 판정 밖으로 내지 않는다(실패 출력에 실리지 않게)."""
    try:
        provider = configure_otel(span_exporter=span_exporter)
    except ImproperlyConfigured as error:
        message = str(error)
        return (
            "rejected",
            name in message,
            _leaks(message, needles),
            error.__cause__ is None and error.__context__ is None,
        )
    DjangoInstrumentor().uninstrument()
    provider.shutdown()
    return ("accepted",)


@contextmanager
def _name_lookups(fragment: str) -> Iterator[list[str]]:
    """블록 안에서 fragment가 든 이름(대소문자 무시)의 socket.getaddrinfo 호출을 이름만 기록하고 조회 없이 OSError로 끝낸다 —
    받음 사례의 클러스터 DNS 이름이 이 프로세스에서 조회되지 않음을 본다(다른 이름은 그대로 넘긴다)."""
    seen: list[str] = []
    original = socket.getaddrinfo

    def guarded(host: Any, *args: Any, **kwargs: Any) -> Any:
        text = host.decode("ascii", "replace") if isinstance(host, bytes) else str(host)
        if fragment in text.lower():
            seen.append(text)
            raise OSError("oc-name-lookup-blocked")
        return original(host, *args, **kwargs)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(socket, "getaddrinfo", guarded)
        yield seen


# --- Sentry init 실패 도우미(〔r8 L2〕) -------------------------------------------------------------------------------


class _InitAborted(BaseException):
    """시험 전용 BaseException 하위 형 — sentry_sdk.init 대역이 낸다(configure_sentry는 잡지 않고 그대로 올려야 한다)."""


def _raising_init(error: BaseException) -> Callable[..., NoReturn]:
    """부르면 error를 내는 sentry_sdk.init 대역(인자는 보지 않는다)."""

    def init(*args: Any, **kwargs: Any) -> NoReturn:
        raise error

    return init


@contextmanager
def _network_attempts() -> Iterator[list[str]]:
    """블록 안의 소켓 연결 · 이름 조회 시도를 종류만 기록하고 시도 없이 OSError로 끝낸다(주소 · 이름은 싣지 않는다 — sentry_sdk.init
    실패 사례의 「네트워크 0」을 본다)."""
    seen: list[str] = []

    def blocked(kind: str) -> Callable[..., NoReturn]:
        def guard(*args: Any, **kwargs: Any) -> NoReturn:
            seen.append(kind)
            raise OSError("oc-network-blocked")

        return guard

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(socket.socket, "connect", blocked("connect"))
        patch.setattr(socket.socket, "connect_ex", blocked("connect_ex"))
        patch.setattr(socket, "getaddrinfo", blocked("getaddrinfo"))
        yield seen


def _exception_text(error: BaseException | None) -> str:
    """예외 하나의 str · repr · 트레이스백 문자열(누출 검사용 — 단언 피연산자로 쓰지 않고 _leaks로 접는다)."""
    if error is None:
        return ""
    return "\n".join((str(error), repr(error), "".join(traceback.format_exception(error))))


def _init_failure_verdict(expected: str, needles: Mapping[str, str]) -> tuple[Any, ...]:
    """configure_sentry() 한 번의 판정 — transport 없이 부른다(프록시 env는 SDK가 HTTP 전송을 만들 때 읽는다).

    ImproperlyConfigured면 ("rejected", 메시지에 expected(예외 클래스 이름)가 있는가, 메시지가 기대 문자열 전체(SENTRY_INIT_FAILURE에
    expected를 넣은 것)와 같은가 〔r9 K3〕, 메시지에 실린 needles 이름, 메시지 · __cause__ · __context__ 어디든 실린 needles 이름,
    __cause__ is None, __context__ is None, 클라이언트 활성, 네트워크 시도 종류) · 다른 Exception이면 ("raised", 예외 클래스 이름,
    클라이언트 활성, 네트워크 시도 종류) · 돌아오면 ("returned", 반환값, 클라이언트 활성, 네트워크 시도 종류). 메시지 · 값은 판정
    밖으로 내지 않는다(판정에는 bool · 이름만 — 실패 출력에 실리지 않게). 클라이언트가 섰으면 닫고 뗀다(다음 사례에 남지 않게).
    """
    error: Exception | None = None
    returned: object = None
    with _network_attempts() as attempts:
        try:
            returned = configure_sentry()
        except Exception as raised:  # noqa: BLE001 — 어떤 예외든 값 없이 판정으로 접는다
            error = raised
    active = sentry_sdk.get_client().is_active()
    if active:
        sentry_sdk.get_client().close()
        sentry_sdk.get_global_scope().set_client(None)
    if error is None:
        return ("returned", returned, active, attempts)
    if not isinstance(error, ImproperlyConfigured):
        return ("raised", type(error).__name__, active, attempts)
    message = str(error)
    chained = "\n".join(_exception_text(item) for item in (error, error.__cause__, error.__context__))
    return (
        "rejected",
        expected in message,
        message == SENTRY_INIT_FAILURE.format(expected),
        _leaks(message, needles),
        _leaks(chained, needles),
        error.__cause__ is None,
        error.__context__ is None,
        active,
        attempts,
    )


# --- 픽스처 ------------------------------------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def _hermetic_env(monkeypatch: pytest.MonkeyPatch) -> None:
    """OTEL_* · SENTRY_* env를 지운다 — 개발자 환경 값이 configure_otel · sentry_sdk 판정에 끼지 않게."""
    for name in list(os.environ):
        if name.upper().startswith(("OTEL_", "SENTRY_")):
            monkeypatch.delenv(name)


@pytest.fixture
def oc_settings(settings: SettingsWrapper) -> SettingsWrapper:
    """MIDDLEWARE(테스트마다 새 list — instrument()가 제자리에서 고친다) · ROOT_URLCONF를 관측 계약용으로 덮는다."""
    settings.MIDDLEWARE = list(OC_MIDDLEWARE)
    settings.ROOT_URLCONF = OC_URLCONF
    return settings


@pytest.fixture
def oc_client(oc_settings: SettingsWrapper) -> Client:
    """뷰 예외를 다시 던지지 않는 시험 Client(500 응답을 그대로 받는다)."""
    return Client(raise_request_exception=False)


@pytest.fixture
def oc_otel(
    oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> Iterator[tuple[TracerProvider, InMemorySpanExporter]]:
    """계약 샘플러 env + configure_otel(span_exporter=InMemorySpanExporter()) — Client보다 앞 인자로 둔다(첫 요청 전 계측)."""
    monkeypatch.setenv("OTEL_TRACES_SAMPLER", "parentbased_traceidratio")
    monkeypatch.setenv("OTEL_TRACES_SAMPLER_ARG", "0.1")
    exporter = InMemorySpanExporter()
    with _otel(exporter) as provider:
        yield provider, exporter


@pytest.fixture
def sentry_settings(settings: SettingsWrapper) -> SettingsWrapper:
    """SENTRY_DSN = 가짜 DSN · ENV = test(시험 설정에는 두 이름이 없다 — 테스트가 끝나면 되돌린다)."""
    settings.SENTRY_DSN = FAKE_DSN
    settings.ENV = "test"
    return settings


@pytest.fixture
def sentry_scope() -> Iterator[None]:
    """isolation scope 안에서 돌리고, 끝나면 클라이언트를 닫아 전역 scope에서 뗀다(`with sentry_sdk.init()` 금지 — 경고가
    tests 모듈로 귀속된다 · 통합 패치 · ignore_logger는 프로세스 전역에 남지만 클라이언트가 없으면 동작하지 않는다)."""
    with sentry_sdk.isolation_scope():
        try:
            yield
        finally:
            sentry_sdk.get_client().close()
            sentry_sdk.get_global_scope().set_client(None)


@pytest.fixture
def sentry_capture(sentry_settings: SettingsWrapper, sentry_scope: None) -> CaptureTransport:
    """configure_sentry(transport=CaptureTransport()) — 초기화했으면 True."""
    capture = CaptureTransport()
    assert configure_sentry(transport=capture) is True
    return capture


@pytest.fixture
def auth500_settings(settings: SettingsWrapper, jwks_server: JwksInfo) -> SettingsWrapper:
    """RequestIdMiddleware → JwtAuthMiddleware 체인 · 관측 계약 urlconf · 로컬 JWKS 서버(Access certs · Authentik JWKS).

    DRAGONFLY_URL은 닫힌 포트(oc-34 · oc-35는 거부 목록 단계에 닿지 않는다 · oc-36이 덮는다).
    """
    settings.MIDDLEWARE = list(AUTH_MIDDLEWARE)
    settings.ROOT_URLCONF = OC_URLCONF
    settings.ACCESS_TEAM_DOMAIN = jwks_server.base_url
    settings.AUTHENTIK_JWKS_URL = jwks_server.jwks_url
    settings.DRAGONFLY_URL = Secret(f"redis://test-pod:{secrets.token_hex(8)}@127.0.0.1:{closed_port()}/0")
    return settings


# --- 로그(D2) -----------------------------------------------------------------------------------------------------


def test_oc_1_mask_removes_extended_keys() -> None:
    """oc-1 — mask_sensitive(processor 직접 호출)는 정규화(소문자 · `_`→`-` · 앞 `http-` 제거) 뒤 이름이 authorization ·
    proxy-authorization · cookie · set-cookie · x-authentik-signature · x-forwarded-user-sub이거나 cf-access-로 시작하는 키를
    키째 지운다 — 최상위 · 중첩 dict · HttpHeaders(Mapping) · list · tuple 안 어디서든(D2). 근접 이름(cf-access · cf-accessory ·
    x-authorization · authorizations · cookie-name · HTTP_ACCEPT)은 남고, 감시 값은 결과 JSON 어디에도 없다.

    〔r2 Y4〕 정규화는 `.`도 `-`로 바꾸고 bytes 키는 latin-1로 풀어 판정한다. 닫힌 이름 목록(헤더 x-csrftoken · 쿠키 cf-authorization ·
    sessionid · csrftoken · jt-session · jt-csrf · META csrf-cookie · query-string · raw-uri · request-uri · 비밀 이름과 접미 ·
    자격 URL 설정 · sub)도 키째 지운다. 첫 항목이 마스킹 이름인 길이 2 list · tuple(헤더 쌍)은 시퀀스의 원소면 원소째, Mapping의
    값이면 키째 뺀다. 이웃 값(token_count · partition-key · idempotency_key · sid · x-request-id · sub_hash · request_id ·
    subject · 마스킹 이름이 아닌 bytes 키 · 길이 3 시퀀스 · 이름이 다른 쌍)은 남는다 — 목록이 접미 규칙 밖으로 넓어지지 않았다.

    〔r3 Z4〕 더한 이름(referer · referrer · csrfmiddlewaretoken · session-key · passphrase · pgpassword) · 접미(-passwd · -apikey ·
    -access-key · -passphrase · -key-pem) · 접두 opentelemetry-instrumentor-(OTel이 META에 두는 항목) · 쿠키 접두(`__Host-` ·
    `__Secure-` — 정규화 뒤 `--host-` · `--secure-` 하나를 뗀다) · camelCase(소문자 · 숫자 → 대문자 경계에 `-`를 넣은 꼴도 판정 —
    accessToken · clientSecret · sessionKey · oauth2Token · awsSecretAccessKey) · memoryview 키(latin-1로 풀어 판정)와 memoryview 첫
    항목 쌍도 지운다. 풀 수 없는(해제된) memoryview 키는 판정 밖이라 `<memoryview>` 자리 표시로 남는다(예외 없음). 넓히지 않는
    이웃(일반 `-key` · `-url` 접미 — partitionKey · AUTHENTIK_JWKS_URL · identity_m2m_url · tokenCount · 식별자 AWS_ACCESS_KEY_ID ·
    인증서 PEM ssl.ca.pem · ssl.certificate.pem · 쿠키 접두만 붙은 평범한 이름 `__Host-theme`)은 남는다.

    〔r5 P2〕 Django 인증 폼의 비밀번호 필드(정확한 이름 넷 — password1 · password2 · new-password1 · new-password2, camelCase
    newPassword1 꼴 포함)도 지운다. request.POST 꼴 QueryDict(csrfmiddlewaretoken · password1 · password2 · old_password ·
    new_password1 · new_password2 · username)는 username만 남는다. 비밀번호 설정 이름(PASSWORD_RESET_TIMEOUT · PASSWORD_HASHERS ·
    AUTH_PASSWORD_VALIDATORS)은 남는다. 〔r5 P3〕 camelCase는 머리글자 끝 경계(대문자 뒤 「대문자 + 소문자」 앞 — APIToken →
    API-Token)에도 `-`를 넣은 꼴로 판정한다: APIToken · myAPIToken · XAPIToken · IDToken · JWTSecret · AWSSecretKey · DBPassword ·
    XApiKey를 지우고, 이웃 AWSAccessKeyID · XRequestID · IDTokenType은 남는다. 앞 사례(〔r3 Z4〕 camelCase 포함)가 그대로 지워지는
    것은 아래 단언이 그대로 보인다.

    〔r6 G2〕 camelCase는 세 꼴(원래 꼴 · 첫 경계만 넣은 꼴 · 두 경계를 넣은 꼴)로 판정해 하나라도 맞으면 지운다 — 머리글자 뒤에
    소문자 낱말이 오는 꼴(myAPIkey · googleAPIkey · xAPIkey · xCSRFtoken · myPASSwd · myPASSphrase · myPREsharedKey — 두 경계를 한
    꼴에만 넣으면 my-AP-Ikey로 갈려 남는다)도 지운다. 남는 이웃(앞 사례 그대로)은 남는다. 〔r6 G8〕 감시 값이 든 구조를 견주는 앞
    단언(headers 형 · bytes_maps · wsgi_headers · pair_map)은 같은 비교를 bool로 접었다(실패 출력에 이름표만). 〔r7 S5〕 meta ·
    items · headers · top_pair 단언도 같은 방식으로 접었다."""
    removed = (
        "Authorization",
        "proxy_authorization",
        "COOKIE",
        "Set-Cookie",
        "x_authentik_signature",
        "X-Forwarded-User-Sub",
        "cf_access_jwt_assertion",
        "CF-Access-Client-Id",
        "cf-access-client-secret",
        "Cf-Access-Authenticated-User-Email",
        "HTTP_AUTHORIZATION",
        "HTTP_COOKIE",
        "HTTP_CF_ACCESS_JWT_ASSERTION",
        "HTTP_X_FORWARDED_USER_SUB",
        "HTTP_PROXY_AUTHORIZATION",
        "http-set-cookie",
        # 〔r2 Y4〕 닫힌 이름 목록 — 헤더 · 쿠키 · META/environ · 비밀 이름 · 접미 · 자격 URL 설정 · 원문 주체
        "X-CSRFToken",
        "HTTP_X_CSRFTOKEN",
        "CF_Authorization",
        "sessionid",
        "csrftoken",
        "jt_session",
        "JT-CSRF",
        "CSRF_COOKIE",
        "QUERY_STRING",
        "RAW_URI",
        "REQUEST_URI",
        "password",
        "PASSWD",
        "Secret",
        "token",
        "api_key",
        "APIKEY",
        "private_key",
        "SECRET_KEY",
        "preshared.key",
        "sasl.password",
        "ssl.key.password",
        "AUTHENTIK_API_TOKEN",
        "AUTHENTIK_WEBHOOK_SECRET",
        "OPENFGA_PRESHARED_KEY",
        "x-csrf-token",
        "X-Api-Key",
        "refresh_token",
        "client.secret",
        "ssh_private_key",
        "django.secret-key",
        "DATABASE_URL",
        "database_owner_url",
        "DRAGONFLY_URL",
        "sub",
        # 〔r3 Z4〕 더한 이름 · 접미 · 접두 · 쿠키 접두 · camelCase
        "Referer",
        "HTTP_REFERER",
        "referrer",
        "csrfmiddlewaretoken",
        "session_key",
        "Passphrase",
        "PGPASSWORD",
        "db_passwd",
        "X-ApiKey",
        "AWS_SECRET_ACCESS_KEY",
        "gpg.passphrase",
        "ssl.key.pem",
        "private_key_pem",
        "opentelemetry-instrumentor-django.duration_attr_key",
        "opentelemetry-instrumentor-django.span_key",
        "__Host-sessionid",
        "__Secure-jt_session",
        "__Host-csrftoken",
        "accessToken",
        "refreshToken",
        "idToken",
        "clientSecret",
        "sessionKey",
        "privateKey",
        "secretKey",
        "oauth2Token",
        "dbPasswd",
        "awsSecretAccessKey",
        "sessionId",
        # 〔r5 P2〕 Django 인증 폼의 비밀번호 필드(정확한 이름 넷 · camelCase 꼴)
        "password1",
        "password2",
        "new_password1",
        "new_password2",
        "newPassword1",
        # 〔r5 P3〕 camelCase 머리글자 끝 경계(APIToken → API-Token)
        "APIToken",
        "myAPIToken",
        "XAPIToken",
        "IDToken",
        "JWTSecret",
        "AWSSecretKey",
        "DBPassword",
        "XApiKey",
        # 〔r6 G2〕 머리글자 뒤 소문자 낱말(첫 경계만 넣은 꼴로 지운다 — my-APIkey → my-apikey)
        "myAPIkey",
        "googleAPIkey",
        "xAPIkey",
        "xCSRFtoken",
        "myPASSwd",
        "myPASSphrase",
        "myPREsharedKey",
    )
    kept = (
        "cf-access",
        "cf-accessory",
        "x-authorization",
        "authorizations",
        "cookie-name",
        "HTTP_ACCEPT",
        # 〔r2 Y4〕 이웃 값 — `-key` · `-url` 일반 접미 · sid · 접두가 같은 이름은 남는다
        "token_count",
        "partition-key",
        "idempotency_key",
        "sid",
        "x-request-id",
        "sub_hash",
        "request_id",
        "subject",
        # 〔r3 Z4〕 넓히지 않는 이웃 — 일반 `-key` · `-url` 접미(camelCase 꼴 포함) · 식별자 · 인증서 PEM · 쿠키 접두만 붙은 이름
        "partitionKey",
        "AUTHENTIK_JWKS_URL",
        "identity_m2m_url",
        "tokenCount",
        "AWS_ACCESS_KEY_ID",
        "ssl.ca.pem",
        "ssl.certificate.pem",
        "__Host-theme",
        # 〔r5 P2〕 비밀번호 설정 이름(비밀 아님) · 〔r5 P3〕 머리글자 경계를 더해도 비밀 이름이 아닌 이웃
        "PASSWORD_RESET_TIMEOUT",
        "PASSWORD_HASHERS",
        "AUTH_PASSWORD_VALIDATORS",
        "AWSAccessKeyID",
        "XRequestID",
        "IDTokenType",
    )
    needles = {f"top-{index}": _sentinel(f"top{index}") for index in range(len(removed))}
    event: dict[str, Any] = {key: needles[f"top-{index}"] for index, key in enumerate(removed)}
    event.update(dict.fromkeys(kept, "kept"))
    needles.update({name: _sentinel(name) for name in ("meta", "list", "tuple", "hdr-auth", "hdr-cf")})
    event["meta"] = {"HTTP_AUTHORIZATION": needles["meta"], "HTTP_ACCEPT": "*/*"}
    event["items"] = [{"Cookie": needles["list"], "keep": 1}, ("x", {"Set-Cookie": needles["tuple"], "keep": 2})]
    event["headers"] = HttpHeaders(
        {
            "HTTP_AUTHORIZATION": needles["hdr-auth"],
            "HTTP_CF_ACCESS_CLIENT_SECRET": needles["hdr-cf"],
            "HTTP_ACCEPT": "text/plain",
        }
    )
    # 〔r2 Y4〕 bytes 키(latin-1로 풀어 판정) · 헤더 쌍(시퀀스 원소 · Mapping 값 · 최상위 값) · 쌍이 아닌 이웃.
    needles.update(
        {
            name: _sentinel(name)
            for name in (
                "bytes-auth",
                "bytes-cookie",
                "bytes-sasl",
                "pair-auth",
                "pair-setcookie",
                "pair-bytes",
                "pair-value",
                "pair-top",
            )
        }
    )
    # bytes 키는 dict 하나에 하나씩 — 남는 bytes 키는 모두 "<bytes>"로 바뀌어 한 dict 안에서는 뒤 값이 앞 값을 덮는다(누출이 가려진다).
    event["bytes_maps"] = [
        {b"authorization": needles["bytes-auth"], "keep": 1},
        {b"HTTP_COOKIE": needles["bytes-cookie"], "keep": 2},
        {b"sasl.password": needles["bytes-sasl"], "keep": 3},
        {b"accept": "*/*"},
    ]
    event["wsgi_headers"] = [
        ("Authorization", needles["pair-auth"]),
        ("Accept", "text/plain"),
        ["Set-Cookie", needles["pair-setcookie"]],
        (b"Cookie", needles["pair-bytes"]),
        ("X-Request-ID", "rid-1"),
    ]
    event["pair_map"] = {"one": ("Proxy-Authorization", needles["pair-value"]), "keep": 1}
    event["top_pair"] = ["sub", needles["pair-top"]]
    event["triple"] = ("authorization", "a", "b")
    event["plain_pair"] = ("accept", "x")
    # 〔r3 Z4〕 memoryview 키(dict 하나에 하나씩 — 남는 키는 "<memoryview>"로 바뀐다) · memoryview 첫 항목 쌍 · 해제된 memoryview 키.
    needles.update({name: _sentinel(name) for name in ("mv-key", "mv-pair")})
    event["mv_maps"] = [{memoryview(b"Authorization"): needles["mv-key"], "keep": 1}, {memoryview(b"accept"): "*/*"}]
    event["mv_pairs"] = [(memoryview(b"Set-Cookie"), needles["mv-pair"]), ("Accept", "x")]
    released = memoryview(b"x-api-key")
    event["mv_released"] = {released: "released-value"}
    released.release()
    # 〔r5 P2〕 request.POST 꼴 QueryDict(Django 인증 폼 제출 — 사용자 만들기 · 비밀번호 바꾸기 필드) — username만 남는다.
    form_fields = ("csrfmiddlewaretoken", "password1", "password2", "old_password", "new_password1", "new_password2")
    needles.update({f"form-{name}": _sentinel(f"form{index}") for index, name in enumerate(form_fields)})
    posted = QueryDict(mutable=True)
    for name in form_fields:
        posted[name] = needles[f"form-{name}"]
    posted["username"] = "oc-user"
    event["post"] = posted
    out = mask_sensitive(None, "info", event)
    remaining = set(out)
    # 〔r5〕 남은 마스킹 이름을 이름만으로 보인다(아래 isdisjoint와 같은 판정 — 실패 출력에 값이 실리지 않는다).
    assert sorted(key for key in removed if key in out) == [], sorted(key for key in removed if key in out)
    assert remaining.isdisjoint(removed)
    assert all(out.get(key) == "kept" for key in kept)
    # 〔r7 S5〕 감시 값이 든 구조와의 잠재 단언(meta · items · headers · top_pair)도 bool로 접는다(같은 식 — 실패 출력에 이름표만).
    same = out["meta"] == {"HTTP_ACCEPT": "*/*"}
    assert same, "meta"
    same = out["items"] == [{"keep": 1}, ["x", {"keep": 2}]]
    assert same, "items"
    # 〔r6 G8〕 감시 값이 든 구조의 비교는 bool로 접는다(같은 식 — 실패 출력에 이름표만).
    same = type(out["headers"]) is dict
    assert same, "headers 형"
    same = out["headers"] == {"Accept": "text/plain"}
    assert same, "headers"
    same = out["bytes_maps"] == [{"keep": 1}, {"keep": 2}, {"keep": 3}, {"<bytes>": "*/*"}]
    assert same, "bytes_maps"
    same = out["wsgi_headers"] == [["Accept", "text/plain"], ["X-Request-ID", "rid-1"]]
    assert same, "wsgi_headers"
    same = out["pair_map"] == {"keep": 1}
    assert same, "pair_map"
    same = "top_pair" not in out
    assert same, "top_pair"
    assert (out["triple"], out["plain_pair"]) == (["authorization", "a", "b"], ["accept", "x"])
    # 〔r3 Z4〕 키 · 첫 항목만 견준다(값은 피연산자로 싣지 않는다 — 실패 출력에 감시 값이 실리지 않게).
    assert [sorted(str(key) for key in item) for item in out["mv_maps"]] == [["keep"], ["<memoryview>"]]
    assert [item[0] for item in out["mv_pairs"]] == ["Accept"]
    assert out["mv_released"] == {"<memoryview>": "released-value"}
    # 〔r5 P2〕 키만 견준다(값은 피연산자로 싣지 않는다).
    assert type(out["post"]) is dict
    assert sorted(out["post"]) == ["username"]
    assert _leaks(json.dumps(out), needles) == [], _leaks(json.dumps(out), needles)


def test_oc_2_mask_structure_and_robustness() -> None:
    """oc-2 — 재귀 꼴(D2): Mapping → dict · tuple → list · 키가 str · int · float · bool · None이면 그대로 · 아니면
    `<타입 이름>` · 순환 → "<cycle>" · 같은 객체를 두 번 참조(순환 아님)는 둘 다 펼친다 · 이벤트 dict 아래 16단 중첩까지 그대로
    · 17단째 컨테이너 → "<truncated>" · 항목을 읽다 예외를 내는 Mapping → "<_Exploding>"(예외 없음) · 컨테이너가 아닌 값은 그
    객체 그대로(문자열화는 렌더러 몫) · 결과는 json.dumps로 바뀐다."""
    loop: dict[str, Any] = {"name": "loop"}
    loop["self"] = loop
    looped_list: list[Any] = [1]
    looped_list.append(looped_list)
    shared = {"v": 1}
    deep: dict[str, Any] = {}
    leaf = deep
    for _ in range(20):
        leaf["n"] = {}
        leaf = leaf["n"]
    marker = uuid.uuid4()
    event: dict[str, Any] = {
        "keys": {3: "int", 2.5: "float", True: "bool", None: "none", b"raw": "bytes", ("t",): "tuple"},
        "loop": loop,
        "looped_list": looped_list,
        "pair": [shared, shared],
        "deep": deep,
        "bad": _Exploding(),
        "nested_tuple": ("a", ("b", ("c",))),
        "value": marker,
    }
    out = mask_sensitive(None, "info", event)
    assert out["keys"] == {3: "int", 2.5: "float", True: "bool", None: "none", "<bytes>": "bytes", "<tuple>": "tuple"}
    assert out["loop"] == {"name": "loop", "self": "<cycle>"}
    assert out["looped_list"] == [1, "<cycle>"]
    assert out["pair"] == [{"v": 1}, {"v": 1}]
    assert out["bad"] == "<_Exploding>"
    assert out["nested_tuple"] == ["a", ["b", ["c"]]]
    assert out["value"] is marker
    node = out["deep"]  # 이벤트 dict 아래 1단
    for _ in range(15):  # 2단 … 16단
        node = node["n"]
        assert isinstance(node, dict)
    assert node["n"] == "<truncated>"  # 17단
    json.dumps(out, default=str)


def test_oc_3_sink_masks_and_drops_record_extras(log_lines: LogLines) -> None:
    """oc-3 — 실제 sink 경로(configure_logging 세션 설정): structlog 줄의 확장 키(cf_access_client_secret · proxy_authorization ·
    set_cookie · x_forwarded_user_sub · 중첩 HTTP_COOKIE)는 키째 없고 이웃 값은 남는다 · 루트의 다른 핸들러가 받는 원본 레코드의
    msg(event dict)도 이미 마스킹돼 있다(D2 — 마스킹을 structlog 체인의 wrap_for_formatter 앞에도 둔다: 다른 핸들러 · handleError
    출력에 원문이 남지 않게) · stdlib 줄은 레코드 extra(민감 키 · request 객체(repr에 쿼리) · 평범한 키)를 싣지 않는다(ExtraAdder
    없음 — D2) · 두 줄 모두 한 JSON 객체 · 감시 값 없음. 〔r6 G8〕 원본 레코드의 확장 키 단언은 같은 비교를 bool로 접었다. 〔r7 S5〕
    렌더된 줄의 meta 단언도 같은 방식으로 접었다."""
    needles = {name: _sentinel(name) for name in ("cf", "proxy", "setcookie", "fwd", "meta", "extra", "query")}
    root = logging.getLogger()
    other = _ListHandler()
    root.addHandler(other)
    try:
        structlog.get_logger("tests.oc.sink").info(
            "oc_sink_probe",
            cf_access_client_secret=needles["cf"],
            proxy_authorization=needles["proxy"],
            set_cookie=needles["setcookie"],
            x_forwarded_user_sub=needles["fwd"],
            meta={"HTTP_COOKIE": needles["meta"], "HTTP_ACCEPT": "*/*"},
            keep="kept",
        )
    finally:
        root.removeHandler(other)
    originals = [
        record.msg
        for record in other.records
        if isinstance(record.msg, dict) and record.msg.get("event") == "oc_sink_probe"
    ]
    assert len(originals) == 1
    # 〔r6 G8〕 감시 값이 든 원본 레코드와의 비교는 bool로 접는다(같은 식 — 실패 출력에 이름표만).
    same = {"cf_access_client_secret", "proxy_authorization", "set_cookie", "x_forwarded_user_sub"}.isdisjoint(originals[0])
    assert same, "originals[0] 확장 키"
    assert _leaks(json.dumps(originals[0], default=str), needles) == [], _leaks(json.dumps(originals[0], default=str), needles)
    request = _FACTORY.get(f"/oc/sink?access_token={needles['query']}")
    logging.getLogger("tests.oc.sink").warning(
        "oc stdlib probe",
        extra={"cf_access_client_secret": needles["extra"], "request": request, "oc_extra": "plain"},
    )
    records = log_lines()
    probe = _one(records, "oc_sink_probe")
    assert probe.get("keep") == "kept"
    assert {"cf_access_client_secret", "proxy_authorization", "set_cookie", "x_forwarded_user_sub"}.isdisjoint(probe)
    # 〔r7 S5〕 감시 값이 든 렌더 줄과의 잠재 단언도 bool로 접는다(같은 식 — 실패 출력에 이름표만).
    same = probe.get("meta") == {"HTTP_ACCEPT": "*/*"}
    assert same, "probe meta"
    stdlib = _one(records, "oc stdlib probe")
    assert (stdlib.get("logger"), stdlib.get("level")) == ("tests.oc.sink", "warning")
    assert {"cf_access_client_secret", "request", "oc_extra"}.isdisjoint(stdlib)
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


def test_oc_4_json_fallback_never_uses_repr(log_lines: LogLines) -> None:
    """oc-4 — JSON 폴백(fail-closed · D2): UUID → str · datetime · date · time → isoformat · Decimal → str · bytes · set ·
    repr에 감시 값을 실은 객체 · HttpRequest → `<타입 이름>`(repr · str 금지) · 감시 값 없음."""
    needles = {"repr": _sentinel("repr"), "query": _sentinel("query")}
    value = uuid.uuid4()
    when = dt.datetime(2026, 11, 6, 1, 2, 3, tzinfo=dt.UTC)
    structlog.get_logger("tests.oc.render").info(
        "oc_render_probe",
        uid=value,
        when=when,
        day=when.date(),
        clock=dt.time(1, 2, 3),
        amount=decimal.Decimal("1.50"),
        raw=b"bytes-value",
        bag={1, 2},
        probe=_ReprProbe(needles["repr"]),
        req=_FACTORY.get(f"/oc/render?access_token={needles['query']}"),
    )
    probe = _one(log_lines(), "oc_render_probe")
    observed = {key: probe.get(key) for key in ("uid", "when", "day", "clock", "amount", "raw", "bag", "probe", "req")}
    assert observed == {
        "uid": str(value),
        "when": when.isoformat(),
        "day": "2026-11-06",
        "clock": "01:02:03",
        "amount": "1.50",
        "raw": "<bytes>",
        "bag": "<set>",
        "probe": "<_ReprProbe>",
        "req": "<WSGIRequest>",
    }
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


def test_oc_5_exception_rendering_has_no_locals(log_lines: LogLines) -> None:
    """oc-5 — 예외는 format_exc_info(표준 트레이스백 문자열)로만 렌더한다(D2 · dict_tracebacks · show_locals 금지): structlog
    log.exception과 stdlib logger.error(exc_info=True) 두 줄 모두 exception 문자열(형 · 메시지 · 함수 이름)을 싣고, 실패한
    프레임의 지역 변수(감시 값)는 어디에도 없다 · exc_info 키가 남지 않는다."""
    needles = {"local": _sentinel("local")}

    def failing(marker_value: str) -> None:
        conninfo = f"dbname=jt password={marker_value}"  # 지역 변수 — show_locals면 줄에 실린다
        raise RuntimeError(f"oc-render-failure length={len(conninfo)}")

    try:
        failing(needles["local"])
    except RuntimeError:
        structlog.get_logger("tests.oc.exc").exception("oc_structlog_exception")
    try:
        failing(needles["local"])
    except RuntimeError:
        logging.getLogger("tests.oc.exc").error("oc stdlib exception", exc_info=True)
    records = log_lines()
    for name in ("oc_structlog_exception", "oc stdlib exception"):
        line = _one(records, name)
        rendered = line.get("exception")
        assert isinstance(rendered, str), name
        assert "RuntimeError: oc-render-failure" in rendered, name
        assert "failing" in rendered, name
        assert line.get("level") == "error", name
        assert "exc_info" not in line, name
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


def test_oc_6_configure_logging_replaces_only_its_handler(log_sink: io.StringIO) -> None:
    """oc-6 — configure_logging는 자기 핸들러(표식)만 바꾼다(D2 · dictConfig 없음): 두 번 불러도 한 이벤트 = 한 줄(앞 stream에는
    더 쓰지 않는다) · 루트의 다른 핸들러는 남아 레코드를 받는다 · 루트 핸들러 수 불변 · 기존 로거의 level · propagate ·
    disabled · handlers는 그대로 · 루트 레벨 = level 인자(WARNING이면 INFO 줄이 없다). 끝나면 세션 sink로 되돌린다."""
    root = logging.getLogger()
    other = _ListHandler()
    root.addHandler(other)
    existing = logging.getLogger("tests.oc.existing")
    keep_handler = logging.NullHandler()
    existing.addHandler(keep_handler)
    existing.setLevel(logging.ERROR)
    existing.propagate = False
    existing.disabled = True
    count_before = len(root.handlers)
    first, second, third = io.StringIO(), io.StringIO(), io.StringIO()
    try:
        configure_logging(stream=first)
        configure_logging(stream=second)
        count_after = len(root.handlers)
        structlog.get_logger("tests.oc.twice").info("oc_twice")
        logging.getLogger("tests.oc.twice").info("oc stdlib twice")
        second_events = [json.loads(line)["event"] for line in second.getvalue().splitlines()]
        first_text = first.getvalue()
        other_messages = [record.getMessage() for record in other.records if record.name == "tests.oc.twice"]
        root_level = root.level
        existing_state = (existing.level, existing.propagate, existing.disabled, list(existing.handlers))
        configure_logging(stream=third, level="WARNING")
        warning_level = root.level
        structlog.get_logger("tests.oc.twice").info("oc_info_dropped")
        structlog.get_logger("tests.oc.twice").warning("oc_warning_kept")
        third_events = [json.loads(line)["event"] for line in third.getvalue().splitlines()]
    finally:
        root.removeHandler(other)
        existing.removeHandler(keep_handler)
        existing.setLevel(logging.NOTSET)
        existing.propagate = True
        existing.disabled = False
        configure_logging(stream=log_sink)
    assert count_after == count_before
    assert (second_events.count("oc_twice"), second_events.count("oc stdlib twice")) == (1, 1)
    assert first_text == ""
    assert "oc stdlib twice" in other_messages
    assert root_level == logging.INFO
    assert existing_state == (logging.ERROR, False, True, [keep_handler])
    assert warning_level == logging.WARNING
    assert "oc_info_dropped" not in third_events
    assert "oc_warning_kept" in third_events


# --- 미들웨어(D3) -------------------------------------------------------------------------------------------------


def test_oc_7_failed_request_echoes_request_id(oc_client: Client, log_lines: LogLines) -> None:
    """oc-7 — 뷰 예외(500): 응답 헤더 X-Request-ID = 그 요청 request_failed 줄의 request_id(형식 안 상류 값 그대로) ·
    request_finished 없음(django-structlog 실패 갈래) · request_failed의 request = "GET /oc/boom"(쿼리 없음) · code 500 ·
    exception 렌더에 뷰 지역 변수(X-Oc-Sentinel 값) 없음 · 쿼리 값 없음."""
    needles = {"local": _sentinel("local"), "query": _sentinel("query")}
    response = oc_client.get(
        f"/oc/boom?access_token={needles['query']}",
        headers={REQUEST_ID: "oc-fail-1", "X-Oc-Sentinel": needles["local"]},
    )
    assert response.status_code == 500
    assert response[REQUEST_ID] == "oc-fail-1"
    records = log_lines()
    failed = _one(records, "request_failed")
    assert (failed.get("request_id"), failed.get("request"), failed.get("code")) == ("oc-fail-1", "GET /oc/boom", 500)
    assert "RuntimeError" in str(failed.get("exception", ""))
    assert _events(records, "request_finished") == []
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


def test_oc_8_client_ip_not_logged(oc_client: Client, log_lines: LogLines) -> None:
    """oc-8 — ip를 남기지 않는다(D3 — X-Forwarded-For 왼쪽 값은 조작 가능 · 개인정보): X-Forwarded-For · X-Real-Ip · REMOTE_ADDR에
    문서용 주소를 실어도 요청 줄 어디에도 ip 키 · 그 주소가 없다."""
    forwarded = f"203.0.113.{secrets.randbelow(200) + 20}"
    peer = f"198.51.100.{secrets.randbelow(200) + 20}"
    response = oc_client.get(
        "/oc/ping", headers={"X-Forwarded-For": forwarded, "X-Real-Ip": forwarded}, REMOTE_ADDR=peer
    )
    assert response.status_code == 200
    lines = _for_request(log_lines(), response[REQUEST_ID])
    assert {"request_started", "oc_ping", "request_finished"} <= {line.get("event") for line in lines}
    assert [line.get("event") for line in lines if "ip" in line] == []
    assert _leaks(log_lines.raw, {"forwarded": forwarded, "peer": peer}) == [], _leaks(
        log_lines.raw, {"forwarded": forwarded, "peer": peer}
    )


def test_oc_9_request_user_not_accessed(oc_client: Client, log_lines: LogLines) -> None:
    """oc-9 — request.user에 접근하지 않는다(D3 — AuthenticationMiddleware가 있는 pod에서 /healthz DB 조회 0): 안쪽 미들웨어가 둔
    지연 사용자 객체는 성공(200) · 실패(500) 두 갈래 모두 평가되지 않고 · user_id 키가 없다."""
    user_trap.USER_TRAP_HITS.clear()
    ok = oc_client.get("/oc/ping", headers={"X-Oc-User-Trap": "1"})
    failed = oc_client.get("/oc/boom", headers={"X-Oc-User-Trap": "1"})
    hits = list(user_trap.USER_TRAP_HITS)
    user_trap.USER_TRAP_HITS.clear()
    assert (ok.status_code, failed.status_code) == (200, 500)
    assert hits == []
    assert [record.get("event") for record in log_lines() if "user_id" in record] == []


def test_oc_10_finished_fields(oc_client: Client, log_lines: LogLines) -> None:
    """oc-10 — request_finished 필드(D3): code(상태) · route(해석된 때만 — resolver route · Ninja 헬스는 "healthz") ·
    duration_ms(float · 0 이상 · 소수 한 자리) · request(쿼리 없음) · 404는 route 키 없음 · 수준은 4xx WARNING."""
    ping = oc_client.get("/oc/ping?x=1")
    missing = oc_client.get("/oc/missing")
    healthz = oc_client.get("/healthz")
    problem = oc_client.get("/oc/problem/plain-json")
    records = log_lines()
    first = _finished(records, ping)
    assert (first.get("code"), first.get("route"), first.get("request")) == (200, "oc/ping", "GET /oc/ping")
    duration = first.get("duration_ms")
    assert isinstance(duration, float)
    assert duration >= 0
    assert round(duration, 1) == duration
    not_found = _finished(records, missing)
    assert (not_found.get("code"), not_found.get("level"), "route" in not_found) == (404, "warning", False)
    assert isinstance(not_found.get("duration_ms"), float)
    assert _finished(records, healthz).get("route") == "healthz"
    assert _finished(records, problem).get("route") == "oc/problem/<str:kind>"


def test_oc_11_stale_contextvars_are_cleared(oc_client: Client, log_lines: LogLines) -> None:
    """oc-11 — 요청 머리에서 structlog contextvars를 먼저 비운다(D3 — 앞 요청이 handle_response를 끝내지 못했을 때 남은 값
    차단): 요청 전 스레드에 묶인 키(감시 값 · 낡은 request_id)는 그 요청의 어느 줄에도 없고 · 응답 X-Request-ID는 새 값 · 요청이
    끝나면 contextvars가 비어 있다."""
    needles = {"stale": _sentinel("stale")}
    structlog.contextvars.bind_contextvars(oc_stale=needles["stale"], request_id="oc-stale-request-id")
    try:
        response = oc_client.get("/oc/ping")
    finally:
        leftover = sorted(structlog.contextvars.get_contextvars())
        structlog.contextvars.clear_contextvars()
    assert response.status_code == 200
    assert response[REQUEST_ID] != "oc-stale-request-id"
    records = log_lines()
    started = _one(records, "request_started")
    assert started.get("request_id") == response[REQUEST_ID]
    assert [record.get("event") for record in records if "oc_stale" in record] == []
    assert leftover == []
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


def test_oc_12_problem_slug(oc_client: Client, log_lines: LogLines) -> None:
    """oc-12 — request_finished의 problem(D3 · T070 r4 V6): application/problem+json 응답이고 본문 type이
    `https://joshuatech.dev/problems/<slug>`이면 slug(Content-Type 매개변수 무관) · application/json · 다른 출처 · 경로 조각 둘 ·
    type이 str 아님 · JSON 아님 · 스트리밍 응답(본문을 읽지 않는다 — 스트림은 그대로 끝까지 나온다)은 키 없음 · 본문의 다른
    값(detail의 감시 값)은 실리지 않는다. 〔r2 Y6〕 본문이 64 KiB를 넘으면 읽지 않는다(정확히 65536바이트는 읽고 65537바이트는 키
    없음)."""
    needles = {"detail": _sentinel("detail")}
    expected = {
        "revoked": "session-revoked",
        "charset": "not-ready",
        "plain-json": ABSENT,
        "foreign": ABSENT,
        "nested": ABSENT,
        "type-int": ABSENT,
        "not-json": ABSENT,
        "stream": ABSENT,
        "limit": "session-revoked",
        "huge": ABSENT,
    }
    responses = {
        kind: oc_client.get(f"/oc/problem/{kind}", headers={"X-Oc-Sentinel": needles["detail"]}) for kind in expected
    }
    streamed = b"".join(responses["stream"].streaming_content)
    records = log_lines()
    observed = {kind: _finished(records, response).get("problem", ABSENT) for kind, response in responses.items()}
    assert observed == expected
    assert json.loads(streamed)["type"] == "https://joshuatech.dev/problems/session-revoked"
    assert (len(responses["limit"].content), len(responses["huge"].content)) == (64 * 1024, 64 * 1024 + 1)
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


# --- sub_hash(D4) -----------------------------------------------------------------------------------------------


def test_oc_13_sub_hash_formula(settings: SettingsWrapper) -> None:
    """oc-13 — sub_hash = salted_hmac("django_common.observability.sub_hash", sub, sha256) 앞 32 hex(D4 · SECRET_KEY 파생 —
    새 비밀 설정 0) · SECRET_KEY를 돌리면 값이 바뀐다 · str 아닌 sub는 TypeError · 빈 sub는 ValueError."""
    expected = salted_hmac("django_common.observability.sub_hash", SUB, algorithm="sha256").hexdigest()[:32]
    assert sub_hash(SUB) == expected
    assert re.fullmatch(r"[0-9a-f]{32}", expected)
    settings.SECRET_KEY = "django-common-tests-rotated"  # 시험 전용 고정 문자열 — 비밀이 아니다
    assert sub_hash(SUB) != expected
    with pytest.raises(TypeError):
        sub_hash(None)  # type: ignore[arg-type]
    with pytest.raises(ValueError, match="sub"):
        sub_hash("")


def test_oc_14_sub_hash_same_in_log_and_span(
    oc_otel: tuple[TracerProvider, InMemorySpanExporter], oc_client: Client, log_lines: LogLines
) -> None:
    """oc-14 — 로그와 span이 같은 함수를 쓴다(D4): sampled 요청의 request_finished sub_hash = span 속성 sub_hash = sub_hash(sub) ·
    tenant_id도 둘 다 같은 str."""
    _, exporter = oc_otel
    _, traceparent = _traceparent(sampled=True)
    headers = {"traceparent": traceparent, "X-Test-Sub": SUB, "X-Test-Tenant": _jwt.TENANT_ID}
    response = oc_client.get("/oc/ping", headers=headers)
    assert response.status_code == 200
    finished = _finished(log_lines(), response)
    spans = exporter.get_finished_spans()
    assert len(spans) == 1
    attributes = dict(spans[0].attributes or {})
    assert finished.get("sub_hash") == attributes.get("sub_hash") == sub_hash(SUB)
    assert finished.get("tenant_id") == attributes.get("tenant_id") == _jwt.TENANT_ID


# --- OTel(D5) --------------------------------------------------------------------------------------------------


def test_oc_15_rejected_env(
    oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture, tmp_path: Path
) -> None:
    """oc-15 — 거부 env(D5 · 이름만 실은 ImproperlyConfigured · 계측 · MIDDLEWARE 변화 0): OTEL_SEMCONV_STABILITY_OPT_IN에
    http(url.query를 공개 API로 지울 수 없다) · 헤더 캡처 env(요청 · 응답 — Authorization이 가림 없이 실린다) ·
    OTEL_PYTHON_DJANGO_MIDDLEWARE_POSITION(가장 바깥이어야 request_started가 span 안이다) · OTEL_PYTHON_DJANGO_INSTRUMENT=False.
    http가 없는 opt-in(database)은 받는다.

    〔r2 Y1〕 거부 env는 일곱이다 — OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS(비지 않으면 · 요청 객체 속성을 str()로 span 속성에
    싣는다 · 값의 감시 문자열은 메시지에 없다) · OTEL_SDK_DISABLED=true(SDK와 같은 판정 — strip · 소문자 · span 0이 기동 신호 없이
    이어진다). 빈 · 공백뿐인 TRACED_REQUEST_ATTRS와 true가 아닌 OTEL_SDK_DISABLED는 받는다. 심층 방어: 계측 미들웨어 클래스의 요청
    속성 목록(import 때 env로 굳는다)이 비지 않은 list이거나 속성이 없으면(판 올림) 거부 · 계측 0 · MIDDLEWARE 불변 · 내보내기 스레드는
    provider shutdown이 거둔다. 〔r2 Y6〕 semconv 판정은 대소문자를 무시하고(HTTP) MIDDLEWARE_POSITION은 빈 값이어도 거부한다.

    〔r3 Z1〕 거부 env는 아홉이다 — OTEL_PROPAGATORS(none · 빈 토큰 · 다른 이름 · baggage뿐은 거부 · 감시 토큰 이름은 메시지에 없다 ·
    토큰 규칙은 아래 〔r4 Q1〕) · OTEL_PYTHON_INSTRUMENTATION_HTTP_CAPTURE_ALL_METHODS(원문이 비지 않으면 — strip 없음: OTel이 원문의
    참/거짓으로 읽어 공백도 켠다). 받는 값: tracecontext · 순서 바꾼 baggage,tracecontext · 빈 값 · 빈 CAPTURE_ALL_METHODS. 이
    프로세스의 전역 textmap은 수집 때 env 없이 굳었다 — import 전 env의 운영 경로는 oc-57 · oc-58 · oc-64가 새 프로세스에서 본다.

    〔r4 Q1〕 OTEL_PROPAGATORS 해석 규칙은 OTel(propagate._load_propagators)과 같다(받는 이름은 더 좁다 — 〔r5 P1〕) — 원문이 비면(빈
    값) 받고, 아니면 쉼표 토큰마다 앞뒤 공백(str.strip이 떼는 것 전부 — 탭 · 유니코드 공백 포함)을 떼어 대소문자 그대로 tracecontext
    · baggage와 같아야 하며 tracecontext가 하나 이상 있어야 한다(겹침 · 순서는
    받는다). 계약 변경 r4 Q1: r3의 받음 사례 「대소문자 · 공백 섞인 tracecontext,baggage」와 「공백(없음과 같다)」은 거부로 옮겼다(OTel
    import가 그 값을 실은 ValueError로 끝난다). 더한 거부: TRACECONTEXT · tracecontext, · ,tracecontext · 탭뿐 · tracecontext
    baggage(쉼표 없음) · tracecontext ,BAGGAGE. 더한 받음: 앞뒤 공백 섞인 tracecontext , baggage · tracecontext,tracecontext ·
    baggage, tracecontext,baggage. 감시 값 밖의 후보는 모듈 상수 PROPAGATORS_REJECTED · PROPAGATORS_ACCEPTED이고, oc-63이 같은 후보를
    OTel 해석과 견준다.

    〔r5 P1〕 받는 이름은 OTel보다 좁다 — OTel이 받는 none · sentry(sentry-sdk가 등록)도 거부한다: PROPAGATORS_NARROWED
    (tracecontext,sentry)는 거부다(oc-63이 「OTel은 받는다」를 함께 고정한다).

    〔r5 P5〕 거부 env는 열하나다 — OTEL_EXPORTER_OTLP_HEADERS · OTEL_EXPORTER_OTLP_TRACES_HEADERS(원문이 비지 않으면 — 공백뿐인 값
    포함 · pod는 자격 없이 클러스터 안 수집기로 보내고 자격은 수집기가 갖는다). 엔드포인트 env를 둔 채 내보내기 대역 없이
    configure_otel()을 부른다 — 거부가 없으면 OTLPSpanExporter가 두 env를 읽고, 꼴이 틀린 쌍(콜론 꼴 `Authorization: Bearer <감시
    값>` · 공백뿐)은 OTel이 원문을 WARNING으로 남긴다. 사례(env마다 콜론 꼴 · URL 인코딩 쌍 · 공백뿐)마다 이름만 실은 거부 · 메시지와
    연쇄 예외에 값 · 감시 값 없음(연쇄 없음) · OTel 로거 WARNING 0 · 계측 0 · MIDDLEWARE 불변 · 내보내기 스레드 0이다. 같은 받기
    경로에서 OTel 헤더 꼴 오류 WARNING이 보임을 감시 값이 아닌 대조 조각으로 확인한다(공허 방지). 두 env의 빈 값은 받는다.

    〔r6 G1〕 거부 env는 열일곱이다 — mTLS 클라이언트 키 · 인증서 env 넷(OTEL_EXPORTER_OTLP_CLIENT_KEY · _TRACES_CLIENT_KEY ·
    _CLIENT_CERTIFICATE · _TRACES_CLIENT_CERTIFICATE — 원문이 비지 않으면, 공백뿐인 값 포함 · 키 env가 없으면 OTel은 인증서 값만
    requests에 넘겨 키를 함께 담은 PEM 한 파일로 인증한다)과 엔드포인트 env 둘의 닫힌 꼴 밖 값(oc-18). 유효한 엔드포인트를 둔 채
    내보내기 대역 없이 · 대역을 넘겨서 부른다(검사는 span_exporter와 무관하다). 사례(env마다 PEM 꼴 값 · 공백뿐)마다 이름만 실은
    거부 · 메시지와 연쇄 예외에 값 · 감시 값 없음 · OTel 로거 WARNING 이상 0 · 계측 0 · MIDDLEWARE 불변 · 내보내기 스레드 0이다.
    받음(대역 없이): 새 env 넷의 빈 값 · 서버 검증용 CA 묶음 OTEL_EXPORTER_OTLP_CERTIFICATE(있는 파일 경로 — 공개 값 · 받음만
    본다)는 계측 · 내보내기 스레드 1 · OTel 로거 0이다."""
    marker = _sentinel("env")
    rejected = (
        ("OTEL_SEMCONV_STABILITY_OPT_IN", "http"),
        ("OTEL_SEMCONV_STABILITY_OPT_IN", " http/dup"),
        ("OTEL_SEMCONV_STABILITY_OPT_IN", "database,http"),
        ("OTEL_SEMCONV_STABILITY_OPT_IN", "HTTP"),
        ("OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_REQUEST", f"authorization,{marker}"),
        ("OTEL_INSTRUMENTATION_HTTP_CAPTURE_HEADERS_SERVER_RESPONSE", f"set-cookie,{marker}"),
        ("OTEL_PYTHON_DJANGO_MIDDLEWARE_POSITION", "1"),
        ("OTEL_PYTHON_DJANGO_MIDDLEWARE_POSITION", ""),
        ("OTEL_PYTHON_DJANGO_INSTRUMENT", "False"),
        ("OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS", f"META,{marker}"),
        ("OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS", f" headers,COOKIES,{marker} "),
        ("OTEL_SDK_DISABLED", "true"),
        ("OTEL_SDK_DISABLED", " TRUE "),
        # 〔r3 Z1〕 OTEL_PROPAGATORS · CAPTURE_ALL_METHODS — 감시 값 밖의 OTEL_PROPAGATORS 값은 PROPAGATORS_REJECTED(r3 다섯 그대로 +
        # 〔r4 Q1〕 받음에서 옮긴 둘 · 더한 여섯 — oc-63과 같은 후보)
        *(("OTEL_PROPAGATORS", value) for _, value in PROPAGATORS_REJECTED),
        # 〔r5 P1〕 의도된 좁힘(OTel은 받는다 — oc-63)
        *(("OTEL_PROPAGATORS", value) for _, value in PROPAGATORS_NARROWED),
        ("OTEL_PROPAGATORS", f"tracecontext,{marker}"),
        ("OTEL_PYTHON_INSTRUMENTATION_HTTP_CAPTURE_ALL_METHODS", "1"),
        ("OTEL_PYTHON_INSTRUMENTATION_HTTP_CAPTURE_ALL_METHODS", "   "),
    )
    accepted: list[str] = []
    for name, value in rejected:
        monkeypatch.setenv(name, value)
        try:
            configure_otel(span_exporter=InMemorySpanExporter())
        except ImproperlyConfigured as error:
            message = str(error)
            assert name in message, name
            assert marker not in message, name
            assert error.__cause__ is None, name
        else:
            accepted.append(name)
            DjangoInstrumentor().uninstrument()
        finally:
            monkeypatch.delenv(name)
        assert DjangoInstrumentor().is_instrumented_by_opentelemetry is False, name
        assert oc_settings.MIDDLEWARE == list(OC_MIDDLEWARE), name
    assert accepted == []
    monkeypatch.setenv("OTEL_SEMCONV_STABILITY_OPT_IN", "database")
    with _otel(InMemorySpanExporter()):
        assert DjangoInstrumentor().is_instrumented_by_opentelemetry is True
    monkeypatch.delenv("OTEL_SEMCONV_STABILITY_OPT_IN")
    allowed = (
        ("OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS", ""),
        ("OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS", "   "),
        ("OTEL_SDK_DISABLED", "false"),
        ("OTEL_SDK_DISABLED", "1"),
        ("OTEL_SDK_DISABLED", ""),
        # 〔r3 Z1〕 OTEL_PROPAGATORS 값은 PROPAGATORS_ACCEPTED(r3 셋 그대로 + 〔r4 Q1〕 더한 셋 — 대소문자 · 공백뿐 사례는 거부로
        # 옮겼다: 계약 변경 r4 Q1)
        *(("OTEL_PROPAGATORS", value) for _, value in PROPAGATORS_ACCEPTED),
        ("OTEL_PYTHON_INSTRUMENTATION_HTTP_CAPTURE_ALL_METHODS", ""),
        # 〔r5 P5〕 OTLP 헤더 env의 빈 값(없음과 같다)
        ("OTEL_EXPORTER_OTLP_HEADERS", ""),
        ("OTEL_EXPORTER_OTLP_TRACES_HEADERS", ""),
    )
    passed: list[tuple[str, str]] = []
    for name, value in allowed:
        monkeypatch.setenv(name, value)
        with _otel(InMemorySpanExporter()):
            if DjangoInstrumentor().is_instrumented_by_opentelemetry:
                passed.append((name, value))
        monkeypatch.delenv(name)
    assert passed == list(allowed)
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", f"http://127.0.0.1:{closed_port()}")
    frozen: dict[str, tuple[Any, ...]] = {}
    for case in ("non-empty", "missing"):
        before = _bsp_threads()
        with pytest.MonkeyPatch.context() as patch:
            if case == "non-empty":
                patch.setattr(_DjangoMiddleware, "_traced_request_attrs", ["META", marker])
            else:
                patch.delattr(_DjangoMiddleware, "_traced_request_attrs")
            try:
                configure_otel()
            except ImproperlyConfigured as error:
                message = str(error)
                outcome: tuple[Any, ...] = (
                    "OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS" in message,
                    marker not in message,
                    error.__cause__ is None,
                )
            else:
                outcome = ("accepted",)
                DjangoInstrumentor().uninstrument()
        frozen[case] = (
            outcome,
            DjangoInstrumentor().is_instrumented_by_opentelemetry,
            oc_settings.MIDDLEWARE == list(OC_MIDDLEWARE),
            _bsp_threads() - before,
        )
    assert frozen == dict.fromkeys(("non-empty", "missing"), ((True, True, True), False, True, 0))
    # 〔r5 P5〕 OTLP 헤더 env 둘 — 엔드포인트 env(루프백 닫힌 포트)를 둔 채 내보내기 대역 없이 부른다(거부가 없으면 OTLPSpanExporter가
    # 두 env를 읽는다). 감시 값은 콜론 꼴 · URL 인코딩 쌍에 하나씩 심는다.
    header_envs = ("OTEL_EXPORTER_OTLP_HEADERS", "OTEL_EXPORTER_OTLP_TRACES_HEADERS")
    header_needles = {f"{env}:{form}": _sentinel(f"hdr-{form}") for env in header_envs for form in ("colon", "pair")}
    header_cases = [
        case
        for env in header_envs
        for case in (
            (env, "colon", f"Authorization: Bearer {header_needles[f'{env}:colon']}"),
            (env, "pair", f"authorization=Bearer%20{header_needles[f'{env}:pair']}"),
            (env, "spaces", "   "),
        )
    ]
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", f"http://127.0.0.1:{closed_port()}")
    headers_seen: dict[str, tuple[Any, ...]] = {}
    with _otel_log_capture(caplog) as otel_warnings:
        for name, form, value in header_cases:
            caplog.clear()
            before = _bsp_threads()
            monkeypatch.setenv(name, value)
            try:
                provider = configure_otel()
            except ImproperlyConfigured as error:
                message = str(error)
                verdict: tuple[Any, ...] = (
                    "rejected",
                    name in message,
                    _leaks(message, header_needles),
                    error.__cause__ is None and error.__context__ is None,
                )
            else:
                verdict = ("accepted",)
                DjangoInstrumentor().uninstrument()
                provider.shutdown()
            finally:
                monkeypatch.delenv(name)
            headers_seen[f"{name}:{form}"] = (
                verdict,
                otel_warnings(),
                DjangoInstrumentor().is_instrumented_by_opentelemetry,
                oc_settings.MIDDLEWARE == list(OC_MIDDLEWARE),
                _bsp_threads() - before,
            )
        # 대조(공허 방지): 같은 받기 경로에서 OTel 헤더 꼴 오류 WARNING은 보인다(감시 값이 아닌 조각).
        caplog.clear()
        parse_env_headers("oc-control: x", liberal=True)
        control = otel_warnings()
    assert headers_seen == {
        f"{name}:{form}": (("rejected", True, [], True), [], False, True, 0) for name, form, _ in header_cases
    }
    assert control == [("opentelemetry.util.re", "WARNING")]
    # 〔r6 G1〕 mTLS 클라이언트 키 · 인증서 env 넷 — 유효한 엔드포인트(루프백 닫힌 포트)를 둔 채 내보내기 대역 없이 · 대역을 넘겨서
    # 부른다(거부가 없으면 대역 없는 호출에서 OTLPSpanExporter가 그 env를 requests cert로 넘긴다). 감시 값은 PEM 꼴 값에 env마다 심는다.
    mtls_needles = {env: _sentinel("mtls") for env in OTLP_MTLS_ENVS}
    mtls_cases = [
        (env, form, value)
        for env in OTLP_MTLS_ENVS
        for form, value in (("pem", _pem_like(mtls_needles[env])), ("spaces", "   "))
    ]
    modes = ("no-exporter", "exporter")
    monkeypatch.setenv(GENERAL_ENDPOINT, f"http://127.0.0.1:{closed_port()}")
    mtls_seen: dict[str, tuple[Any, ...]] = {}
    ca_bundle = tmp_path / "oc-ca.pem"
    ca_bundle.write_text("oc-ca-bundle\n", encoding="utf-8")
    mtls_allowed = [*((env, "") for env in OTLP_MTLS_ENVS), ("OTEL_EXPORTER_OTLP_CERTIFICATE", str(ca_bundle))]
    mtls_passed: list[tuple[str, tuple[Any, ...]]] = []
    with _otel_log_capture(caplog) as otel_warnings:
        for name, form, value in mtls_cases:
            for mode in modes:
                caplog.clear()
                before = _bsp_threads()
                monkeypatch.setenv(name, value)
                try:
                    verdict = _configure_verdict(
                        name, mtls_needles, InMemorySpanExporter() if mode == "exporter" else None
                    )
                finally:
                    monkeypatch.delenv(name)
                mtls_seen[f"{name}:{form}:{mode}"] = (
                    verdict,
                    otel_warnings(),
                    DjangoInstrumentor().is_instrumented_by_opentelemetry,
                    oc_settings.MIDDLEWARE == list(OC_MIDDLEWARE),
                    _bsp_threads() - before,
                )
        # 받음: 새 env 넷의 빈 값(없음과 같다) · CA 묶음 경로(있는 파일).
        for name, value in mtls_allowed:
            caplog.clear()
            before = _bsp_threads()
            monkeypatch.setenv(name, value)
            try:
                with _otel():
                    during = (DjangoInstrumentor().is_instrumented_by_opentelemetry, _bsp_threads() - before)
            finally:
                monkeypatch.delenv(name)
            mtls_passed.append((name, (during, otel_warnings(), _bsp_threads() - before)))
    assert mtls_seen == {
        f"{name}:{form}:{mode}": (("rejected", True, [], True), [], False, True, 0)
        for name, form, _ in mtls_cases
        for mode in modes
    }
    assert mtls_passed == [(name, ((True, 1), [], 0)) for name, _ in mtls_allowed]


def test_oc_16_sampler_defaults_to_contract(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-16 — OTEL_TRACES_SAMPLER가 없거나 비면 계약 기본 ParentBased(TraceIdRatioBased(0.1))(D5 — SDK 기본
    parentbased_always_on이 아니다 · 샘플러가 없으면 ARG는 쓰이지 않는다)."""
    expected = ParentBased(TraceIdRatioBased(0.1)).get_description()
    monkeypatch.setenv("OTEL_TRACES_SAMPLER_ARG", "0.9")
    observed = []
    for value in (None, ""):
        if value is None:
            monkeypatch.delenv("OTEL_TRACES_SAMPLER", raising=False)
        else:
            monkeypatch.setenv("OTEL_TRACES_SAMPLER", value)
        with _otel(InMemorySpanExporter()) as provider:
            observed.append(provider.sampler.get_description())
    assert observed == [expected, expected]


def test_oc_17_invalid_sampler_rejected(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-17 — 샘플러 env 검증(D5 — SDK의 「경고 뒤 비율 1.0 · parentbased_always_on」 fail-open을 막는다): 모르는 이름 · 앞 공백 ·
    비율 샘플러의 ARG 없음 · 빈 값 · 숫자 아님 · [0, 1] 밖 · nan · inf → ImproperlyConfigured(이름만). SDK 이름 집합(대소문자
    무시)과 [0, 1] ARG는 받는다."""
    invalid = (
        ("bogus", None),
        (" parentbased_traceidratio", "0.1"),
        ("parentbased_traceidratio", None),
        ("parentbased_traceidratio", ""),
        ("traceidratio", "abc"),
        ("parentbased_traceidratio", "2"),
        ("parentbased_traceidratio", "-0.1"),
        ("parentbased_traceidratio", "nan"),
        ("traceidratio", "inf"),
    )
    passed: list[tuple[str, str | None]] = []
    for sampler, argument in invalid:
        monkeypatch.setenv("OTEL_TRACES_SAMPLER", sampler)
        if argument is None:
            monkeypatch.delenv("OTEL_TRACES_SAMPLER_ARG", raising=False)
        else:
            monkeypatch.setenv("OTEL_TRACES_SAMPLER_ARG", argument)
        try:
            configure_otel(span_exporter=InMemorySpanExporter())
        except ImproperlyConfigured as error:
            assert "OTEL_TRACES_SAMPLER" in str(error)
        else:
            passed.append((sampler, argument))
            DjangoInstrumentor().uninstrument()
    assert passed == []
    accepted = (
        ("always_on", None, "AlwaysOnSampler"),
        ("PARENTBASED_TRACEIDRATIO", "0.5", ParentBased(TraceIdRatioBased(0.5)).get_description()),
        ("traceidratio", "1", TraceIdRatioBased(1.0).get_description()),
        ("parentbased_traceidratio", "0", ParentBased(TraceIdRatioBased(0.0)).get_description()),
    )
    observed = []
    for sampler, argument, _ in accepted:
        monkeypatch.setenv("OTEL_TRACES_SAMPLER", sampler)
        if argument is None:
            monkeypatch.delenv("OTEL_TRACES_SAMPLER_ARG", raising=False)
        else:
            monkeypatch.setenv("OTEL_TRACES_SAMPLER_ARG", argument)
        with _otel(InMemorySpanExporter()) as provider:
            observed.append(provider.sampler.get_description())
    assert observed == [description for _, _, description in accepted]


def test_oc_18_otlp_endpoint_needs_scheme(
    oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch, caplog: pytest.LogCaptureFixture
) -> None:
    """oc-18 — OTEL_EXPORTER_OTLP_ENDPOINT · _TRACES_ENDPOINT는 http:// · https://로 시작해야 한다(D5 · T098 문면 값에 스킴이 없다 ·
    span_exporter와 무관하다 — 계약 변경 r6 G1: 전에는 span_exporter가 없을 때만 봤다): 스킴 없음 · 다른 스킴 →
    ImproperlyConfigured(이름만). 스킴이 있으면 BatchSpanProcessor 작업 스레드가 서고(내보낼 span 없음 — 네트워크 0) shutdown이
    거둔다.

    〔r6 G1〕 엔드포인트 env 둘은 비지 않으면 닫힌 꼴 scheme://host[:port][/path]만 받는다 — scheme http · https(ASCII 대소문자 무시) ·
    host ASCII 영문자 · 숫자 · `.` · `-` · port ASCII 십진 1–65535 · path `/`로 시작하는 ASCII 영문자 · 숫자 · `.` · `_` · `~` ·
    `/` · `-`. 거부(각 env를 따로 · 사례마다 내보내기 대역 없이 · 대역을 넘겨서 — 감시 값은 사용자 정보 · 쿼리 · 조각 · 퍼센트
    인코딩 사례에 심는다): 사용자 정보(이름:값 · 값만 · 빈 호스트) · 쿼리 · 조각 · 퍼센트 인코딩 · 역슬래시(포트 뒤 · 경로 안) ·
    공백뿐 · 끝 줄바꿈 · 포트 0 · 65536 · 빈 포트 · 비숫자 포트 · 전각 숫자 포트 · IPv6 리터럴 · 빈 호스트 · 앞의 스킴 없음 셋, 그리고
    TRACES 빈 값 뒤 꼴 밖 일반 env(or 대체) · 유효한 TRACES와 함께 둔 꼴 밖 일반 env(둘 다 일반 env 이름으로 거부). 거부마다 이름만
    실은 ImproperlyConfigured · 메시지와 연쇄 예외에 값 · 감시 값 없음 · OTel 로거 WARNING 이상 0 · 계측 0 · MIDDLEWARE 불변 ·
    내보내기 스레드 0이다(OTel 로거는 caplog 처리기로만 받는다 — 〔r5 P5〕와 같다). 받음(env마다 · 대역 없이): 루프백 · https 클러스터 DNS
    이름 · 경로 붙은 이름 · 대문자 스킴, 그리고 한쪽 env의 빈 값 — 계측 · 내보내기 스레드 1 · OTel 로거 0이고, 받음 사례의 클러스터
    DNS 이름은 조회되지 않는다(내보낼 span이 없다 — 조회하면 이름을 기록하고 막는다).

    〔r7 S1〕 스킴의 대소문자 무시는 ASCII로만 한다 — 유니코드 대소문자 접기는 ſ(U+017F)를 s로 본다. 거부에 스킴 끝이 ſ인 사례
    둘(scheme-long-s · scheme-long-s-upper — 값은 chr(0x17F)로 만든다)을 env마다 · 두 모드로 더했다. 받음의 대문자 스킴은 그대로
    받는다."""
    rejected = ("alloy.monitoring.svc:4318", "grpc://127.0.0.1:4317", "127.0.0.1:4318/v1/traces")
    passed: list[tuple[str, str]] = []
    for name in ("OTEL_EXPORTER_OTLP_ENDPOINT", "OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"):
        for value in rejected:
            monkeypatch.setenv(name, value)
            try:
                configure_otel()
            except ImproperlyConfigured as error:
                message = str(error)
                assert name in message
                assert value not in message
            else:
                passed.append((name, value))
                DjangoInstrumentor().uninstrument()
            finally:
                monkeypatch.delenv(name)
    assert passed == []
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", f"http://127.0.0.1:{closed_port()}")
    before = _bsp_threads()
    with _otel():
        during = _bsp_threads()
    after = _bsp_threads()
    assert (during - before, after - before) == (1, 0)
    monkeypatch.delenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    # 〔r6 G1〕 닫힌 꼴 밖 값 — env마다 따로 둔다(다른 쪽은 없음). 감시 값은 env · 꼴마다 하나씩이다.
    port = closed_port()
    loopback = f"http://127.0.0.1:{port}"
    sentinel_forms = ("userinfo", "userinfo-token", "userinfo-empty-host", "query", "fragment", "percent")
    endpoint_needles = {f"{env}:{form}": _sentinel(f"ep-{form}") for env in ENDPOINT_ENVS for form in sentinel_forms}
    endpoint_cases: list[tuple[str, dict[str, str], str]] = []
    for env in ENDPOINT_ENVS:
        needle = {form: endpoint_needles[f"{env}:{form}"] for form in sentinel_forms}
        malformed = (
            ("userinfo", f"http://otel-user:{needle['userinfo']}@127.0.0.1:{port}/v1/traces"),
            ("userinfo-token", f"http://{needle['userinfo-token']}@127.0.0.1:{port}/v1/traces"),
            ("userinfo-empty-host", f"http://u:{needle['userinfo-empty-host']}@:4318/v1/traces"),
            ("query", f"{loopback}/v1/traces?api_key={needle['query']}"),
            ("fragment", f"{loopback}/v1/traces#{needle['fragment']}"),
            ("percent", f"{loopback}/v1/traces/%3F{needle['percent']}"),
            ("backslash", f"{loopback}\\v1\\traces"),
            ("backslash-path", f"{loopback}/v1\\traces"),
            ("spaces", "   "),
            ("newline", f"{loopback}/v1/traces\n"),
            ("port-0", "http://127.0.0.1:0/v1/traces"),
            ("port-65536", "http://127.0.0.1:65536/v1/traces"),
            ("port-empty", "http://127.0.0.1:/v1/traces"),
            ("port-alpha", "http://127.0.0.1:abc/v1/traces"),
            ("port-fullwidth", f"http://127.0.0.1:{_fullwidth('4318')}/v1/traces"),
            ("ipv6", "http://[::1]:4318"),
            ("empty-host", "http://:4318"),
            # 〔r7 S1〕 스킴 끝의 U+017F — 유니코드 대소문자 접기로는 s와 같고 ASCII 대소문자 무시로는 다르다.
            ("scheme-long-s", "http" + chr(0x17F) + f"://127.0.0.1:{port}/v1/traces"),
            ("scheme-long-s-upper", "HTTP" + chr(0x17F) + f"://127.0.0.1:{port}/v1/traces"),
            *((f"no-scheme-{index}", value) for index, value in enumerate(rejected)),
        )
        endpoint_cases.extend((f"{env}:{form}", {env: value}, env) for form, value in malformed)
    # or 대체(TRACES 빈 값 → 일반 env) · 유효한 TRACES와 함께 둔 꼴 밖 일반 env — 둘 다 일반 env 이름으로 거부한다.
    endpoint_needles["fallback"] = _sentinel("ep-fallback")
    bad_general = f"http://otel-user:{endpoint_needles['fallback']}@127.0.0.1:{port}/v1/traces"
    endpoint_cases.append(("or-fallback", {TRACES_ENDPOINT: "", GENERAL_ENDPOINT: bad_general}, GENERAL_ENDPOINT))
    endpoint_cases.append(
        ("traces-valid", {TRACES_ENDPOINT: f"{loopback}/v1/traces", GENERAL_ENDPOINT: bad_general}, GENERAL_ENDPOINT)
    )
    accepted_cases = [
        (f"{env}:{label}", {env: value})
        for env in ENDPOINT_ENVS
        for label, value in (
            ("loopback", loopback),
            ("svc-https", "https://alloy.monitoring.svc.cluster.local:4318"),
            ("svc-path", "http://alloy.monitoring.svc:4318/v1/traces"),
            ("upper-scheme", "HTTP://Alloy.monitoring.svc:4318/"),
        )
    ]
    accepted_cases += [
        ("traces-empty", {TRACES_ENDPOINT: "", GENERAL_ENDPOINT: loopback}),
        ("general-empty", {GENERAL_ENDPOINT: "", TRACES_ENDPOINT: f"{loopback}/v1/traces"}),
    ]
    modes = ("no-exporter", "exporter")
    endpoint_seen: dict[str, tuple[Any, ...]] = {}
    accepted_seen: dict[str, tuple[Any, ...]] = {}
    with _otel_log_capture(caplog) as otel_warnings:
        for label, env_values, name in endpoint_cases:
            needles = {**endpoint_needles, **{f"value:{key}": value for key, value in env_values.items() if value.strip()}}
            for mode in modes:
                caplog.clear()
                before = _bsp_threads()
                for key, value in env_values.items():
                    monkeypatch.setenv(key, value)
                try:
                    verdict = _configure_verdict(name, needles, InMemorySpanExporter() if mode == "exporter" else None)
                finally:
                    for key in env_values:
                        monkeypatch.delenv(key)
                endpoint_seen[f"{label}:{mode}"] = (
                    verdict,
                    otel_warnings(),
                    DjangoInstrumentor().is_instrumented_by_opentelemetry,
                    oc_settings.MIDDLEWARE == list(OC_MIDDLEWARE),
                    _bsp_threads() - before,
                )
        with _name_lookups(CLUSTER_NAME_FRAGMENT) as lookups:
            for label, env_values in accepted_cases:
                caplog.clear()
                before = _bsp_threads()
                for key, value in env_values.items():
                    monkeypatch.setenv(key, value)
                try:
                    with _otel():
                        during = (DjangoInstrumentor().is_instrumented_by_opentelemetry, _bsp_threads() - before)
                finally:
                    for key in env_values:
                        monkeypatch.delenv(key)
                accepted_seen[label] = (during, otel_warnings(), _bsp_threads() - before)
    assert endpoint_seen == {
        f"{label}:{mode}": (("rejected", True, [], True), [], False, True, 0)
        for label, _, _ in endpoint_cases
        for mode in modes
    }
    assert accepted_seen == {label: ((True, 1), [], 0) for label, _ in accepted_cases}
    assert lookups == []


def test_oc_19_no_endpoint_no_exporter(
    oc_settings: SettingsWrapper, log_lines: LogLines, monkeypatch: pytest.MonkeyPatch
) -> None:
    """oc-19 — span_exporter도 엔드포인트도 없으면 내보내기를 두지 않는다(D5): BatchSpanProcessor 스레드 0 · WARNING 한 줄
    otel_exporter_disabled(logger django_common.observability · 이름만 — 표준 필드 밖 키 없음). span_exporter가 있으면 그 줄이
    없다. 〔r2 Y6〕 엔드포인트 env 둘이 빈 값이면 없는 것과 같다(거부 · 내보내기 없이 같은 WARNING 한 줄)."""
    before = _bsp_threads()
    with _otel():
        during = _bsp_threads()
    records = log_lines()
    warning = _one(records, "otel_exporter_disabled")
    assert (warning.get("level"), warning.get("logger")) == ("warning", "django_common.observability")
    assert set(warning) <= {"ts", "level", "logger", "event"}
    assert during == before
    with _otel(InMemorySpanExporter()):
        pass
    assert _events(log_lines(), "otel_exporter_disabled") == []
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", "")
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT", "")
    empty_before = _bsp_threads()
    with _otel():
        empty_during = _bsp_threads()
    assert empty_during == empty_before
    assert len(_events(log_lines(), "otel_exporter_disabled")) == 1


def test_oc_20_resource_names(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-20 — Resource(D5): service.name = OUTBOX_SOURCE(pod 이름) · service.version = APP_VERSION · OTEL_SERVICE_NAME ·
    OTEL_RESOURCE_ATTRIBUTES가 있으면 그것이 이긴다 · OUTBOX_SOURCE가 kebab pod 이름이 아니면 ImproperlyConfigured(계측 0).
    〔r2 Y6〕 kebab 경계(끝 · 앞 하이픈 · 숫자로 시작 · 하이픈 둘 · 대문자는 거부, `pod1-2x`는 받는다) · APP_VERSION이 비지 않은 str가
    아니면(빈 값 · 수 · None) ImproperlyConfigured(이름만 · 계측 0)."""
    with _otel(InMemorySpanExporter()) as provider:
        default_attributes = dict(provider.resource.attributes)
    assert (default_attributes.get("service.name"), default_attributes.get("service.version")) == (
        oc_settings.OUTBOX_SOURCE,
        oc_settings.APP_VERSION,
    )
    monkeypatch.setenv("OTEL_SERVICE_NAME", "oc-env-service")
    monkeypatch.setenv("OTEL_RESOURCE_ATTRIBUTES", "service.version=9.9.9,deployment.environment=oc")
    with _otel(InMemorySpanExporter()) as provider:
        env_attributes = dict(provider.resource.attributes)
    assert (
        env_attributes.get("service.name"),
        env_attributes.get("service.version"),
        env_attributes.get("deployment.environment"),
    ) == ("oc-env-service", "9.9.9", "oc")
    monkeypatch.delenv("OTEL_SERVICE_NAME")
    monkeypatch.delenv("OTEL_RESOURCE_ATTRIBUTES")
    oc_settings.OUTBOX_SOURCE = "Not_A_Pod"
    with pytest.raises(ImproperlyConfigured, match="OUTBOX_SOURCE"):
        configure_otel(span_exporter=InMemorySpanExporter())
    assert DjangoInstrumentor().is_instrumented_by_opentelemetry is False
    pod_names: dict[str, bool] = {}
    for value in ("pod-", "-pod", "1pod", "pod--x", "Pod", "pod1-2x"):
        oc_settings.OUTBOX_SOURCE = value
        try:
            with _otel(InMemorySpanExporter()):
                pass
        except ImproperlyConfigured as error:
            assert "OUTBOX_SOURCE" in str(error), value
            pod_names[value] = False
        else:
            pod_names[value] = True
    assert pod_names == {"pod-": False, "-pod": False, "1pod": False, "pod--x": False, "Pod": False, "pod1-2x": True}
    oc_settings.OUTBOX_SOURCE = "identity-admin"
    versions: list[tuple[Any, bool, bool, bool]] = []
    for value in ("", 7, None):
        oc_settings.APP_VERSION = value
        try:
            configure_otel(span_exporter=InMemorySpanExporter())
        except ImproperlyConfigured as error:
            versions.append((value, "APP_VERSION" in str(error), error.__cause__ is None, True))
        else:
            versions.append((value, False, False, False))
            DjangoInstrumentor().uninstrument()
        assert DjangoInstrumentor().is_instrumented_by_opentelemetry is False, value
    assert versions == [("", True, True, True), (7, True, True, True), (None, True, True, True)]


def test_oc_21_global_provider_set_once() -> None:
    """oc-21 — 전역 provider는 아직 Proxy일 때만 set한다(D5 · 덮어쓰기 경고 0) · 다시 부르면 uninstrument 뒤 재계측(「이미 계측」
    경고 0) · 반환값은 새 provider: 새 프로세스(시험 설정)에서 configure_otel을 두 번 부른다."""
    script = (
        "import json, logging\n"
        "messages = []\n"
        "class Grab(logging.Handler):\n"
        "    def emit(self, record):\n"
        "        messages.append(record.getMessage())\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    root = logging.getLogger()\n"
        "    root.addHandler(Grab())\n"
        "    root.setLevel(logging.DEBUG)\n"
        "    from opentelemetry import trace\n"
        "    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter\n"
        "    from django_common.observability import configure_otel\n"
        "    before = type(trace.get_tracer_provider()).__name__\n"
        "    first = configure_otel(span_exporter=InMemorySpanExporter())\n"
        "    first_global = trace.get_tracer_provider() is first\n"
        "    second = configure_otel(span_exporter=InMemorySpanExporter())\n"
        "    result = {\n"
        "        'before': before,\n"
        "        'first_global': first_global,\n"
        "        'kept_first': trace.get_tracer_provider() is first,\n"
        "        'distinct': first is not second,\n"
        "        'override_warnings': sum('Overriding' in message for message in messages),\n"
        "        'already_instrumented': sum('already instrumented' in message for message in messages),\n"
        "    }\n"
        "except Exception as exc:\n"
        "    result = {'error': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    )
    assert _run_child(script) == {
        "before": "ProxyTracerProvider",
        "first_global": True,
        "kept_first": True,
        "distinct": True,
        "override_warnings": 0,
        "already_instrumented": 0,
    }


def test_oc_22_raw_uri_target_has_no_query(
    oc_otel: tuple[TracerProvider, InMemorySpanExporter], oc_client: Client
) -> None:
    """oc-22 — gunicorn RAW_URI 경로(D5 — 0.66b2는 RAW_URI가 있으면 http.target에 경로 + 쿼리를 싣고 http.url은 두지 않는다):
    response_hook이 http.target을 `?` 앞까지로 덮어쓴다 · span 어디에도 쿼리 감시 값이 없다."""
    _, exporter = oc_otel
    needles = {"query": _sentinel("query")}
    raw = f"/oc/ping?access_token={needles['query']}&x=1"
    _, traceparent = _traceparent(sampled=True)
    response = oc_client.get(raw, headers={"traceparent": traceparent}, RAW_URI=raw)
    assert response.status_code == 200
    spans = exporter.get_finished_spans()
    assert len(spans) == 1
    attributes = {key: str(value) for key, value in dict(spans[0].attributes or {}).items()}
    assert attributes.get("http.target") == "/oc/ping"
    assert "http.url" not in attributes
    assert _leaks(_span_text(spans[0]), needles) == [], _leaks(_span_text(spans[0]), needles)


def test_oc_23_unsampled_request_has_no_trace_ids(
    oc_otel: tuple[TracerProvider, InMemorySpanExporter], oc_client: Client, log_lines: LogLines
) -> None:
    """oc-23 — 상류가 샘플링하지 않은 요청(플래그 00 — 유효하지만 기록하지 않는 span)의 요청 줄에는 trace_id · span_id가 없다
    (D2 — 기록 중 span일 때만 · 내보낸 span과 1:1) · span 0."""
    _, exporter = oc_otel
    _, traceparent = _traceparent(sampled=False)
    response = oc_client.get("/oc/ping", headers={"traceparent": traceparent})
    assert response.status_code == 200
    lines = _for_request(log_lines(), response[REQUEST_ID])
    assert {"request_started", "oc_ping", "request_finished"} <= {line.get("event") for line in lines}
    assert [line.get("event") for line in lines if "trace_id" in line or "span_id" in line] == []
    assert len(exporter.get_finished_spans()) == 0


# --- Sentry(D7) ------------------------------------------------------------------------------------------------


def test_oc_24_empty_dsn_does_not_initialise(
    settings: SettingsWrapper, sentry_scope: None, monkeypatch: pytest.MonkeyPatch
) -> None:
    """oc-24 — SENTRY_DSN이 비었거나 None이거나 설정이 없으면 init하지 않고 False(D7 — 빈 DSN init은 패치 · 전파를 켠다):
    클라이언트가 비활성(is_active False) 그대로 · env SENTRY_DSN은 보지 않는다 · str 아닌 값은 ImproperlyConfigured(이름만)."""
    monkeypatch.setenv("SENTRY_DSN", FAKE_DSN)
    settings.ENV = "test"
    observed = []
    for value in ("", None):
        settings.SENTRY_DSN = value
        observed.append((configure_sentry(transport=CaptureTransport()), sentry_sdk.get_client().is_active()))
    del settings.SENTRY_DSN
    observed.append((configure_sentry(transport=CaptureTransport()), sentry_sdk.get_client().is_active()))
    assert observed == [(False, False)] * 3
    settings.SENTRY_DSN = 123
    with pytest.raises(ImproperlyConfigured, match="SENTRY_DSN"):
        configure_sentry(transport=CaptureTransport())
    assert sentry_sdk.get_client().is_active() is False


def test_oc_25_init_options_and_integrations(sentry_settings: SettingsWrapper, sentry_scope: None) -> None:
    """oc-25 — init 인자(D7): 지역 변수 · 본문 · 브레드크럼 · 나가는 전파 · 세션 · spotlight · debug · 자동 통합 끔 · 넘기지 않는
    것(send_default_pii · 트레이스 · 프로파일 · enable_tracing — 0이 아니라 미설정) · environment = ENV · release =
    `<OUTBOX_SOURCE>@<APP_GIT_SHA>` · 통합 집합 정확히(Redis · Stdlib 없음 — Redis 통합은 거부 목록 키의 원문 sub를 싣는다) ·
    LoggingIntegration은 이벤트 · 브레드크럼 처리기가 없다 · should_send_default_pii False · configure_sentry 동안
    DeprecationWarning 0(send_default_pii를 넘기면 sentry_sdk.client에 귀속되는 폐기 경고가 난다). 〔r2 Y3〕 Sentry Logs 처리기도
    없다(sentry_logs_level=None — 기본 INFO면 처리기가 생기고, 켜지면 레코드 extra · args가 마스킹 · before_send 없이 나간다)."""
    capture = CaptureTransport()
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        assert configure_sentry(transport=capture) is True
    deprecations = [warning.category.__name__ for warning in caught if issubclass(warning.category, DeprecationWarning)]
    assert deprecations == []
    client = sentry_sdk.get_client()
    pinned = {
        key: client.options.get(key)
        for key in (
            "dsn",
            "environment",
            "release",
            "include_local_variables",
            "max_request_body_size",
            "max_breadcrumbs",
            "trace_propagation_targets",
            "auto_session_tracking",
            "spotlight",
            "debug",
            "auto_enabling_integrations",
            "default_integrations",
            "send_default_pii",
            "traces_sample_rate",
            "traces_sampler",
            "profiles_sample_rate",
            "profile_session_sample_rate",
            "enable_tracing",
            "enable_logs",
        )
    }
    assert pinned == {
        "dsn": FAKE_DSN,
        "environment": "test",
        "release": f"{sentry_settings.OUTBOX_SOURCE}@{sentry_settings.APP_GIT_SHA}",
        "include_local_variables": False,
        "max_request_body_size": "never",
        "max_breadcrumbs": 0,
        "trace_propagation_targets": [],
        "auto_session_tracking": False,
        "spotlight": False,
        "debug": False,
        "auto_enabling_integrations": False,
        "default_integrations": True,
        "send_default_pii": None,
        "traces_sample_rate": None,
        "traces_sampler": None,
        "profiles_sample_rate": None,
        "profile_session_sample_rate": None,
        "enable_tracing": None,
        "enable_logs": False,
    }
    assert callable(client.options.get("before_send"))
    assert client.should_send_default_pii() is False
    assert sorted(client.integrations) == SENTRY_INTEGRATIONS
    assert client.get_integration(RedisIntegration) is None
    assert client.get_integration(StdlibIntegration) is None
    logging_integration = client.get_integration(LoggingIntegration)
    assert logging_integration is not None
    assert (logging_integration._handler, logging_integration._breadcrumb_handler) == (None, None)
    assert logging_integration._sentry_logs_handler is None
    assert client.transport is capture


def test_oc_26_invalid_sentry_settings(sentry_settings: SettingsWrapper, sentry_scope: None) -> None:
    """oc-26 — DSN이 있으면 ENV ∈ {dev, prod, test} · release 원천(OUTBOX_SOURCE kebab · APP_GIT_SHA hex) · DSN 꼴이 맞아야 한다
    (D7): 어기면 ImproperlyConfigured — 메시지에 설정 이름만(값 없음) · 연쇄 없음 · init 없음(클라이언트 비활성). 〔r2 Y6〕
    APP_GIT_SHA는 소문자 hex 7–64자다(6자 · 65자 · 대문자는 거부, 7자 · 64자는 init).

    〔r8 L2〕 sentry_sdk.init이 Exception을 내면 예외 클래스 이름만 실은 ImproperlyConfigured다 — 꼴이 틀린 사용자 정보 프록시
    env(HTTPS_PROXY + https DSN · HTTP_PROXY + http DSN — 루프백 DSN · 범위 밖 포트 · 사용자 정보에 감시 값 · transport 없이 불러 SDK가
    HTTP 전송을 만들며 env를 읽는다 · 사례마다 PROXY_ENVS를 소문자 꼴까지 지우고 MonkeyPatch로 되돌린다)와 init을 감시 값 실은
    ValueError 대역으로 바꾼 사례 모두: 메시지에 예외 클래스 이름(urllib3 LocationParseError · ValueError) · 메시지 · __cause__ ·
    __context__에 감시 값 없음 · __cause__ · __context__ 둘 다 None(연쇄 예외 없음) · 그 뒤 클라이언트 비활성 · 소켓 연결 · 이름
    조회 0(_network_attempts가 종류만 기록하고 막는다). init 대역이 BaseException 하위 형(_InitAborted)을 내면 그 객체가 그대로
    올라온다(같은 객체 · 클라이언트 비활성).

    〔r9 K3〕 프록시 사례는 사용자 이름도 감시 값이다(감시 값 글자는 URL 사용자 정보에 써도 된다 — 비밀번호만 가린 URL을 메시지에
    싣는 회귀도 잡는다). 메시지는 기대 문자열 전체(SENTRY_INIT_FAILURE — 구현의 고정 문구에 예외 클래스 이름만 바뀐다)와 같아야
    한다(판정에는 bool만)."""
    marker = _sentinel("bad")
    cases = {
        "ENV": f"staging-{marker}",
        "APP_GIT_SHA": f"not-a-sha-{marker}",
        "OUTBOX_SOURCE": f"Bad_Pod_{marker}",
        "SENTRY_DSN": f"not-a-dsn-{marker}",
    }
    outcomes: dict[str, tuple[bool, bool, bool, bool]] = {}
    for name, value in cases.items():
        original = getattr(sentry_settings, name)
        setattr(sentry_settings, name, value)
        error: ImproperlyConfigured | None = None
        try:
            configure_sentry(transport=CaptureTransport())
        except ImproperlyConfigured as raised:
            error = raised
        finally:
            setattr(sentry_settings, name, original)
        if error is None:
            outcomes[name] = (False, False, False, False)
            continue
        outcomes[name] = (
            name in str(error),
            marker not in str(error),
            error.__cause__ is None and (error.__context__ is None or error.__suppress_context__),
            sentry_sdk.get_client().is_active() is False,
        )
    assert outcomes == dict.fromkeys(cases, (True, True, True, True))
    original_sha = sentry_settings.APP_GIT_SHA
    shas: dict[str, str] = {}
    for value in ("abcdef0", "a" * 64, "abcdef", "a" * 65, "ABCDEF1"):
        sentry_settings.APP_GIT_SHA = value
        try:
            initialised = configure_sentry(transport=CaptureTransport())
        except ImproperlyConfigured as error:
            active = sentry_sdk.get_client().is_active()
            shas[value] = "rejected" if "APP_GIT_SHA" in str(error) and not active else "rejected-badly"
        else:
            shas[value] = "initialised" if initialised else "not-initialised"
            sentry_sdk.get_client().close()
            sentry_sdk.get_global_scope().set_client(None)
    sentry_settings.APP_GIT_SHA = original_sha
    assert shas == {
        "abcdef0": "initialised",
        "a" * 64: "initialised",
        "abcdef": "rejected",
        "a" * 65: "rejected",
        "ABCDEF1": "rejected",
    }
    # 〔r8 L2〕 init 실패 → 예외 클래스 이름만 실은 ImproperlyConfigured(판정은 _init_failure_verdict — 실패 출력에는 이름표만).
    verdicts: dict[str, tuple[Any, ...]] = {}
    needles: dict[str, str] = {}
    for label, proxy_env, dsn in (("https-proxy", "HTTPS_PROXY", FAKE_HTTPS_DSN), ("http-proxy", "HTTP_PROXY", FAKE_DSN)):
        needles[label] = _sentinel(label)
        # 〔r9 K3〕 사용자 이름도 감시 값이다(앞 라운드의 고정 이름 대신).
        needles[f"{label}-user"] = _sentinel(f"{label}-user")
        user = needles[f"{label}-user"]
        with pytest.MonkeyPatch.context() as patch:
            for name in PROXY_ENVS:
                patch.delenv(name.lower(), raising=False)
                patch.delenv(name, raising=False)
            patch.setenv(proxy_env, f"http://{user}:{needles[label]}@127.0.0.1:{PROXY_BAD_PORT}")
            sentry_settings.SENTRY_DSN = dsn
            try:
                verdicts[label] = _init_failure_verdict(PROXY_PARSE_ERROR, needles)
            finally:
                sentry_settings.SENTRY_DSN = FAKE_DSN
    needles["value-error"] = _sentinel("value-error")
    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(sentry_sdk, "init", _raising_init(ValueError(needles["value-error"])))
        verdicts["value-error"] = _init_failure_verdict("ValueError", needles)
    expected = dict.fromkeys(("https-proxy", "http-proxy", "value-error"), ("rejected", True, True, [], [], True, True, False, []))
    assert verdicts == expected, sorted(label for label in expected if verdicts.get(label) != expected[label])
    aborted = _InitAborted("oc-init-aborted")
    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(sentry_sdk, "init", _raising_init(aborted))
        try:
            configure_sentry()
        except _InitAborted as raised:
            escaped: tuple[Any, ...] = ("escaped", raised is aborted)
        except Exception as raised:  # noqa: BLE001 — BaseException을 잡아 바꾸면 클래스 이름으로 접는다
            escaped = ("raised", type(raised).__name__)
        else:
            escaped = ("returned",)
    same = (escaped, sentry_sdk.get_client().is_active()) == (("escaped", True), False)
    assert same, "base exception"


def test_oc_27_view_exception_event_is_scrubbed(
    oc_settings: SettingsWrapper, sentry_capture: CaptureTransport, log_lines: LogLines
) -> None:
    """oc-27 — 실제 WSGIHandler 경로의 뷰 예외 → 이벤트 1(D7 — django.test.Client는 Sentry가 패치한 WSGIHandler.__call__을
    거치지 않아 헤더 시험이 공허하다): 요청 헤더는 허용 목록만(소문자 비교 · 허용 목록 안 헤더는 남는다) · query_string ·
    cookies · data · user 없음 · env는 SERVER_NAME · SERVER_PORT만 · url에 `?` 없음 · 그 경로의 _meta 없음 · 프레임 vars 없음 ·
    브레드크럼 0(뷰의 INFO · stdlib WARNING · 수동 add_breadcrumb) · 태그 request_id = 응답 X-Request-ID · 이벤트 · 그 요청의
    로그 어디에도 감시 값(헤더 · 쿼리 · 쿠키 · 본문 · 지역 변수 · 브레드크럼 · XFF)이 없다. 〔r2 Y3〕 요청 헤더에 x-request-id가 없고
    (검증된 값은 태그가 싣는다) · OTel이 없어 기록 중 span이 없으니 contexts.trace도 없다. 〔r6 G8〕 브레드크럼 단언은 같은 비교를
    bool로 접었다. 〔r7 S5〕 url의 `?` 단언도 같은 방식으로 접었다."""
    names = ("query", "authorization", "cookie", "cf-jwt", "cf-id", "cf-secret", "authentik", "fwd-sub", "local")
    needles = {name: _sentinel(name) for name in (*names, "body", "breadcrumb")}
    forwarded = f"203.0.113.{secrets.randbelow(200) + 20}"
    headers = {
        "Authorization": f"Bearer {needles['authorization']}",
        "Cookie": f"sid={needles['cookie']}",
        "Cf-Access-Jwt-Assertion": needles["cf-jwt"],
        "Cf-Access-Client-Id": needles["cf-id"],
        "Cf-Access-Client-Secret": needles["cf-secret"],
        "X-Authentik-Signature": f"sha256={needles['authentik']}",
        "X-Forwarded-User-Sub": needles["fwd-sub"],
        "X-Forwarded-For": forwarded,
        "Cf-Connecting-Ip": forwarded,
        "X-Oc-Sentinel": needles["local"],
        "X-Oc-Breadcrumb": needles["breadcrumb"],
        REQUEST_ID: "oc-sentry-1",
        "User-Agent": "oc-agent/1",
        "Accept": "application/json",
    }
    body = json.dumps({"payload": needles["body"]}).encode()
    result = call_wsgi(_environ("POST", f"/oc/boom?access_token={needles['query']}", headers=headers, body=body))
    assert result.status == 500
    assert result.headers.get("x-request-id") == "oc-sentry-1"
    events = sentry_capture.events()
    assert len(events) == 1
    event = events[0]
    request = event.get("request") if isinstance(event.get("request"), dict) else {}
    header_names = _header_names(event)
    assert sorted(header_names - SENTRY_HEADER_ALLOWLIST) == []
    assert {"user-agent", "accept", "content-type", "content-length"} <= header_names
    assert "x-request-id" not in header_names
    assert "trace" not in event.get("contexts", {})
    assert sorted({"query_string", "cookies", "data"} & set(request)) == [], sorted(
        {"query_string", "cookies", "data"} & set(request)
    )
    assert set(request.get("env", {})) <= {"SERVER_NAME", "SERVER_PORT"}
    # 〔r7 S5〕 감시 값(쿼리)이 든 url과의 잠재 단언도 bool로 접는다(같은 식 — 실패 출력에 이름표만).
    same = "?" not in str(request.get("url", ""))
    assert same, "url ?"
    assert "user" not in event
    assert "request" not in event.get("_meta", {})
    frames = _frames(event)
    assert frames
    assert [frame.get("function") for frame in frames if "vars" in frame] == []
    assert "RuntimeError" in [value.get("type") for value in event["exception"]["values"]]
    # 〔r6 G8〕 감시 값이 든 브레드크럼과의 비교는 bool로 접는다(같은 식 — 실패 출력에 이름표만).
    same = _breadcrumb_values(event) == []
    assert same, "breadcrumbs"
    assert event.get("tags", {}).get("request_id") == "oc-sentry-1"
    assert _leaks(json.dumps(event), {**needles, "forwarded": forwarded}) == [], _leaks(
        json.dumps(event), {**needles, "forwarded": forwarded}
    )
    records = log_lines()
    assert _one(records, "request_failed").get("request_id") == "oc-sentry-1"
    assert _leaks(log_lines.raw, {**needles, "forwarded": forwarded}) == [], _leaks(
        log_lines.raw, {**needles, "forwarded": forwarded}
    )


def test_oc_28_trace_id_tag_when_sampled(
    oc_otel: tuple[TracerProvider, InMemorySpanExporter], sentry_capture: CaptureTransport
) -> None:
    """oc-28 — 태그 trace_id(D7): 포착 시점에 OTel span이 기록 중이면(sampled traceparent) 그 trace id(32 hex) · 비샘플 요청에는
    trace_id 태그가 없다 · request_id 태그는 둘 다 있다."""
    trace_id, sampled = _traceparent(sampled=True)
    _, unsampled = _traceparent(sampled=False)
    first = call_wsgi(_environ("GET", "/oc/boom", headers={"traceparent": sampled}))
    second = call_wsgi(_environ("GET", "/oc/boom", headers={"traceparent": unsampled}))
    assert (first.status, second.status) == (500, 500)
    events = sentry_capture.events()
    assert len(events) == 2
    tags = [event.get("tags", {}) for event in events]
    assert tags[0].get("trace_id") == trace_id
    assert "trace_id" not in tags[1]
    assert [tag.get("request_id") for tag in tags] == [first.headers.get("x-request-id"), second.headers.get("x-request-id")]


def test_oc_29_logs_and_handled_errors_make_no_events(
    oc_settings: SettingsWrapper, sentry_capture: CaptureTransport, log_lines: LogLines
) -> None:
    """oc-29 — errors only = 예외 포착만(D7 · 쿼터): structlog ERROR · stdlib ERROR(exc_info) · 예외 없는 503(request_finished ·
    django.request ERROR 두 줄) · ALLOWED_HOSTS 밖 Host(django.security.DisallowedHost ERROR + exc_info · 400) → 이벤트 0. 그
    ERROR 줄들은 실제로 나왔다(공허하지 않음)."""
    log_error = call_wsgi(_environ("GET", "/oc/log-error"))
    unavailable = call_wsgi(_environ("GET", "/oc/unavailable"))
    oc_settings.MIDDLEWARE = list(HOST_MIDDLEWARE)
    disallowed = call_wsgi(_environ("GET", "/oc/ping", headers={"Host": "evil.example"}))
    assert (log_error.status, unavailable.status, disallowed.status) == (200, 503, 400)
    error_loggers = {record.get("logger") for record in log_lines() if record.get("level") == "error"}
    expected_loggers = {
        "tests.obscontractapp",
        "tests.obscontractapp.std",
        "django_structlog.middlewares.request",
        "django.request",
        "django.security.DisallowedHost",
    }
    assert sorted(expected_loggers - error_loggers) == [], sorted(expected_loggers - error_loggers)
    assert sentry_capture.events() == []


def test_oc_30_before_send_failure_drops_event(
    oc_settings: SettingsWrapper, sentry_capture: CaptureTransport, monkeypatch: pytest.MonkeyPatch
) -> None:
    """oc-30 — before_send가 예외를 내면 이벤트를 버린다(D7 · fail-closed — SDK가 callback_error로 버린다 · 구현은 예외를 삼켜
    원 이벤트를 돌려주지 않는다): 정리 함수를 망가뜨린 채 뷰 예외 → 이벤트 0."""

    def broken(event: dict[str, Any]) -> dict[str, Any]:
        raise RuntimeError("oc scrub failure")

    monkeypatch.setattr(observability, "_scrub_event", broken)
    result = call_wsgi(_environ("GET", "/oc/boom"))
    assert result.status == 500
    assert sentry_capture.events() == []


def test_oc_31_before_send_unit() -> None:
    """oc-31 — before_send 단위(D7 · 직렬화된 dict): 요청 헤더는 허용 목록만(대소문자 무관 · 이름 꼴 유지) · query_string ·
    cookies · data · user · env의 다른 키 · url의 `?` · `#` 뒤 · _meta.request · _meta.user를 지우고 다른 _meta는 남긴다 ·
    exception · threads 프레임 vars를 지운다 · 이벤트 전체에 D2 키 마스킹(extra · contexts의 중첩 키) · 기존 태그는 남기고
    request_id(structlog contextvars) · trace_id(기록 중 span)를 단다 · 감시 값 없음 · request가 dict가 아니어도 예외 없음.
    〔r2 Y3〕 x-request-id 헤더는 남지 않는다 · contexts.trace: 기록 중 span이면 trace_id · span_id를 그 span 값으로 바꾸고
    parent_span_id · dynamic_sampling_context를 지운다(다른 키는 남는다) · 아니면 trace 문맥을 지운다. 〔r2 Y6〕 request는 url ·
    method · headers · env만 남는다(SDK가 더할 다른 키도 — 허용 목록) · 쿼리 없는 url의 `#` 조각도 뗀다. 〔r3 Z2〕 traceparent 헤더도
    남지 않는다(허용 목록 = host · user-agent · accept · content-type · content-length — 값에 감시 값). 〔r6 G8〕 감시 값이 든 구조의
    단언(recorded contexts · fragment request · request env · 프레임 vars · extra)은 같은 비교를 bool로 접었다. 〔r7 S5〕 request
    url · unrecorded contexts · out contexts 단언도 같은 방식으로 접었다."""
    needles = {
        name: _sentinel(name)
        for name in ("q", "c", "d", "ip", "auth", "cookie", "jwt", "cfs", "sig", "xff", "cip", "sub", "fw", "tp")
    }
    needles.update({name: _sentinel(name) for name in ("user", "var", "thread-var", "extra-a", "extra-b", "ctx")})
    needles.update({name: _sentinel(name) for name in ("rx", "frag", "tr-trace", "tr-span", "tr-parent", "tr-dsc")})
    event: dict[str, Any] = {
        "request": {
            "url": f"http://testserver/oc/x?access_token={needles['q']}#frag",
            "method": "GET",
            "query_string": f"access_token={needles['q']}",
            "cookies": {"sid": needles["c"]},
            "data": {"k": needles["d"]},
            "oc_extra": needles["rx"],
            "env": {"SERVER_NAME": "testserver", "SERVER_PORT": "80", "REMOTE_ADDR": needles["ip"]},
            "headers": {
                "Host": "testserver",
                "USER-AGENT": "ua",
                "accept": "a",
                "Content-Type": "ct",
                "Content-Length": "1",
                "X-Request-Id": "rid",
                "Traceparent": needles["tp"],
                "Authorization": needles["auth"],
                "Cookie": needles["cookie"],
                "Cf-Access-Jwt-Assertion": needles["jwt"],
                "Cf-Access-Client-Secret": needles["cfs"],
                "X-Authentik-Signature": needles["sig"],
                "X-Forwarded-For": needles["xff"],
                "Cf-Connecting-Ip": needles["cip"],
                "X-Forwarded-User-Sub": needles["sub"],
                "Forwarded": needles["fw"],
            },
        },
        "user": {"id": needles["user"]},
        "exception": {
            "values": [{"type": "E", "value": "v", "stacktrace": {"frames": [{"function": "f", "vars": {"x": needles["var"]}}]}}]
        },
        "threads": {"values": [{"stacktrace": {"frames": [{"function": "g", "vars": {"y": needles["thread-var"]}}]}}]},
        "extra": {"nested": {"HTTP_AUTHORIZATION": needles["extra-a"], "cf_access_client_id": needles["extra-b"], "keep": "k"}},
        "contexts": {"oc": {"set-cookie": needles["ctx"], "ok": 1}},
        "_meta": {"request": {"headers": {"Authorization": {"": {"rem": [["!config", "s"]]}}}}, "user": {}, "exception": {"x": 1}},
        "tags": {"existing": "t"},
    }
    def forged_trace_event() -> dict[str, Any]:
        """클라이언트 sentry-trace · baggage가 정한 trace 문맥(감시 값) — 기록 중 span이면 바뀌고 아니면 지워져야 한다."""
        return {
            "message": "m",
            "contexts": {
                "trace": {
                    "trace_id": needles["tr-trace"],
                    "span_id": needles["tr-span"],
                    "parent_span_id": needles["tr-parent"],
                    "dynamic_sampling_context": {"public_key": needles["tr-dsc"], "release": needles["tr-dsc"]},
                    "op": "oc-op",
                },
                "oc": {"ok": 1},
            },
        }

    span_provider = TracerProvider(sampler=ALWAYS_ON)
    structlog.contextvars.bind_contextvars(request_id="oc-unit-rid")
    try:
        with span_provider.get_tracer("oc-unit").start_as_current_span("oc-unit-span") as span:
            expected_trace = format(span.get_span_context().trace_id, "032x")
            expected_span = format(span.get_span_context().span_id, "016x")
            out = observability._sentry_before_send(event, {})
            recorded = observability._sentry_before_send(forged_trace_event(), {})
        fallback = observability._sentry_before_send({"request": "not-a-dict", "message": "m"}, {})
        unrecorded = observability._sentry_before_send(forged_trace_event(), {})
        fragment = observability._sentry_before_send(
            {"request": {"url": f"http://testserver/oc/y#{needles['frag']}", "method": "GET"}}, {}
        )
    finally:
        structlog.contextvars.clear_contextvars()
        span_provider.shutdown()
    assert out is not None
    request = out["request"]
    assert sorted(request) == ["env", "headers", "method", "url"]
    assert sorted(request["headers"]) == sorted(["Host", "USER-AGENT", "accept", "Content-Type", "Content-Length"])
    # 〔r7 S5〕 감시 값이 든 구조와의 잠재 단언(request url · unrecorded contexts · out contexts)도 bool로 접는다(같은 식).
    same = request["url"] == "http://testserver/oc/x"
    assert same, "request url"
    assert recorded is not None
    # 〔r6 G8〕 감시 값이 든 구조의 비교는 bool로 접는다(같은 식 — 실패 출력에 이름표만).
    same = recorded["contexts"] == {
        "trace": {"trace_id": expected_trace, "span_id": expected_span, "op": "oc-op"},
        "oc": {"ok": 1},
    }
    assert same, "recorded contexts"
    assert unrecorded is not None
    same = unrecorded["contexts"] == {"oc": {"ok": 1}}
    assert same, "unrecorded contexts"
    assert fragment is not None
    same = fragment["request"] == {"url": "http://testserver/oc/y", "method": "GET"}
    assert same, "fragment request"
    assert _leaks(json.dumps([recorded, unrecorded, fragment]), needles) == [], _leaks(
        json.dumps([recorded, unrecorded, fragment]), needles
    )
    same = request["env"] == {"SERVER_NAME": "testserver", "SERVER_PORT": "80"}
    assert same, "request env"
    assert "user" not in out
    assert sorted(out["_meta"]) == ["exception"]
    same = [frame for frame in _frames(out) if "vars" in frame] == []
    assert same, "frame vars"
    same = out["extra"] == {"nested": {"keep": "k"}}
    assert same, "extra"
    same = out["contexts"] == {"oc": {"ok": 1}}
    assert same, "out contexts"
    assert out["tags"] == {"existing": "t", "request_id": "oc-unit-rid", "trace_id": expected_trace}
    assert _leaks(json.dumps(out), needles) == [], _leaks(json.dumps(out), needles)
    assert fallback is not None
    assert fallback.get("message") == "m"


def test_oc_32_outgoing_requests_carry_no_sentry_headers(sentry_capture: CaptureTransport) -> None:
    """oc-32 — 나가는 http.client 요청에 sentry-trace · baggage가 없다(D7 — 기본 trace_propagation_targets [".*"]는 트레이싱이
    꺼져도 PyJWKClient · OTLP 호출에 DSN 공개 키 · release를 싣는다): 로컬 헤더 기록 서버로 urllib GET(프록시 없음).
    〔r2 Y5〕 단일 방어(옵션 값 — trace_propagation_targets=[] · StdlibIntegration 끔)는 oc-25가 고정하고, 이 시험은 두 겹을 함께 없앤
    경우(기본 targets + StdlibIntegration 켬 — 복합 변이 M67+M68)를 가른다. 한 겹만 남아도 헤더는 붙지 않는다."""
    recorder = HeaderRecorder()
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(recorder.url, timeout=5) as response:
            response.read()
    finally:
        recorder.close()
    assert len(recorder.requests) == 1
    assert sorted({"sentry-trace", "baggage"} & set(recorder.requests[0])) == [], sorted(
        {"sentry-trace", "baggage"} & set(recorder.requests[0])
    )


def test_oc_33_no_session_envelopes(oc_settings: SettingsWrapper, sentry_capture: CaptureTransport) -> None:
    """oc-33 — 세션 envelope 0(D7 · auto_session_tracking=False — 기본은 WSGI 요청마다 세션을 모아 flush 때 보낸다): 요청 하나 →
    flush → session · sessions 항목 없음."""
    result = call_wsgi(_environ("GET", "/oc/ping"))
    assert result.status == 200
    sentry_sdk.get_client().flush(timeout=2)
    assert [kind for kind in sentry_capture.item_types() if kind.startswith("session")] == []


def _assert_auth_500(
    result: WsgiResult,
    capture: CaptureTransport,
    log_lines: LogLines,
    *,
    setting: str,
    frames: set[str],
    needles: Mapping[str, str],
) -> None:
    """auth 설정 오류 500 단언(oc-34..36): 이벤트 1(ImproperlyConfigured · 메시지에 설정 이름) · 비밀을 쥔 프레임이 스택에 있다(공허
    방지) · 프레임 vars 없음 · 요청 헤더는 허용 목록만 · 이벤트 · 같은 요청의 JSON 로그(request_failed · django.request — 둘 다
    예외 렌더를 싣는다) 어디에도 감시 값이 없다."""
    assert result.status == 500
    request_id = result.headers.get("x-request-id")
    assert request_id
    events = capture.events()
    assert len(events) == 1
    event = events[0]
    values = event.get("exception", {}).get("values", [])
    assert values
    assert values[-1].get("type") == "ImproperlyConfigured"
    assert setting in str(values[-1].get("value", ""))
    assert sorted(frames - _function_names(event)) == [], sorted(frames - _function_names(event))
    assert [frame.get("function") for frame in _frames(event) if "vars" in frame] == []
    assert sorted(_header_names(event) - SENTRY_HEADER_ALLOWLIST) == []
    assert _leaks(json.dumps(event), needles) == [], _leaks(json.dumps(event), needles)
    records = log_lines()
    failed = _one(records, "request_failed")
    assert failed.get("request_id") == request_id
    assert "ImproperlyConfigured" in str(failed.get("exception", ""))
    django_lines = [record for record in records if record.get("logger") == "django.request"]
    assert len(django_lines) == 1
    assert "ImproperlyConfigured" in str(django_lines[0].get("exception", ""))
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


def test_oc_34_auth_config_error_bearer_frame(
    auth500_settings: SettingsWrapper, sentry_capture: CaptureTransport, jwks_server: JwksInfo, log_lines: LogLines
) -> None:
    """oc-34 — auth 설정 오류 500 (a)(T070 인계 N12 · U7): AUTHENTIK_AUDIENCE를 비운 채 유효 Access(클레임에 감시 값) + 감시 값
    Bearer → Bearer 검증 프레임(validate)의 지역 변수 header에 원문 Bearer · _authenticate의 access_claims에 감시 값 → 이벤트 ·
    로그 어디에도 없다."""
    needles = {"bearer": _sentinel("bearer"), "access-claim": _sentinel("access")}
    access = _jwt.mint(_jwt.access_claims(oc_note=needles["access-claim"]), jwks_server.access_key, _jwt.ACCESS_KID)
    auth500_settings.AUTHENTIK_AUDIENCE = ""
    headers = {"Authorization": f"Bearer {needles['bearer']}", "Cf-Access-Jwt-Assertion": access}
    result = call_wsgi(_environ("GET", "/oc/protected", headers=headers))
    _assert_auth_500(
        result,
        sentry_capture,
        log_lines,
        setting="AUTHENTIK_AUDIENCE",
        frames={"_authenticate", "validate", "_required"},
        needles={**needles, "access-token": access},
    )


def test_oc_35_auth_config_error_access_frame(
    auth500_settings: SettingsWrapper, sentry_capture: CaptureTransport, log_lines: LogLines
) -> None:
    """oc-35 — auth 설정 오류 500 (b)(T070 인계 U7): ACCESS_TEAM_DOMAIN 끝 줄바꿈(V2 위반) + 감시 값 Access JWT · Bearer →
    AccessJwtValidator.validate 프레임의 지역 변수 token에 원문 Access(엣지에서 다시 쓸 수 있는 자격) → 이벤트 · 로그 어디에도
    없다."""
    needles = {"bearer": _sentinel("bearer"), "access": _sentinel("access")}
    auth500_settings.ACCESS_TEAM_DOMAIN = auth500_settings.ACCESS_TEAM_DOMAIN + "\n"
    headers = {"Authorization": f"Bearer {needles['bearer']}", "Cf-Access-Jwt-Assertion": needles["access"]}
    result = call_wsgi(_environ("GET", "/oc/protected", headers=headers))
    _assert_auth_500(
        result,
        sentry_capture,
        log_lines,
        setting="ACCESS_TEAM_DOMAIN",
        frames={"_authenticate", "validate", "_team_base_url", "_printable_ascii"},
        needles=needles,
    )


def test_oc_36_auth_config_error_denylist_frame(
    auth500_settings: SettingsWrapper, sentry_capture: CaptureTransport, jwks_server: JwksInfo, log_lines: LogLines
) -> None:
    """oc-36 — auth 설정 오류 500 (c)(T070 인계 W4 · X7 · F4): DRAGONFLY_URL 비밀번호 자리에 감시 값 + 끝 줄바꿈(V2 위반) + 유효
    Access(클레임에 감시 값) · Bearer(sub · sid에 감시 값) → _required · _printable_ascii 프레임 value에 원문 URL · Denylist.lookup
    프레임에 sub · sid · _authenticate 프레임에 검증된 _Bearer(클레임) → 이벤트 · 로그 어디에도 없다(원문 토큰 문자열도)."""
    needles = {name: _sentinel(name) for name in ("password", "sub", "sid", "access-claim")}
    url = f"redis://test-pod:{needles['password']}@127.0.0.1:{closed_port()}/0"
    auth500_settings.DRAGONFLY_URL = Secret(url + "\n")
    access = _jwt.mint(_jwt.access_claims(oc_note=needles["access-claim"]), jwks_server.access_key, _jwt.ACCESS_KID)
    bearer = _jwt.mint(
        _jwt.bearer_claims(sub=needles["sub"], sid=needles["sid"]), jwks_server.authentik_key, _jwt.AUTHENTIK_KID
    )
    headers = {"Authorization": f"Bearer {bearer}", "Cf-Access-Jwt-Assertion": access}
    result = call_wsgi(_environ("GET", "/oc/protected", headers=headers))
    _assert_auth_500(
        result,
        sentry_capture,
        log_lines,
        setting="DRAGONFLY_URL",
        frames={"_authenticate", "lookup", "_required", "_printable_ascii"},
        needles={**needles, "url": url, "bearer-token": bearer, "access-token": access},
    )


# --- 헬스(D6) ----------------------------------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True)
def test_oc_37_health_blackholes_run_in_parallel(oc_settings: SettingsWrapper, log_lines: LogLines) -> None:
    """oc-37 — 블랙홀 3종(연결은 성립하고 응답 없음 — OS 무관 · T066 인계): DB(connect_timeout 1 → psycopg 2 s) · Dragonfly ·
    Kafka → /health 200 · degraded · 세 항목 fail · 경과 < 3 s · 병렬(Dragonfly · Kafka의 latency_ms가 DB 판정을 기다리지 않는다
    — 순차면 DB 뒤에 시작한다) · fail 항목에도 latency_ms · 응답 · 로그에 Dragonfly 비밀번호 없음."""
    needles = {"password": _sentinel("password")}
    with blackhole() as db_port, blackhole() as dragonfly_port, blackhole() as kafka_port:
        oc_settings.DRAGONFLY_URL = Secret(f"redis://test-pod:{needles['password']}@127.0.0.1:{dragonfly_port}/0")
        oc_settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{kafka_port}"
        with _db_at("127.0.0.1", db_port, connect_timeout=1):
            response, elapsed = _timed_get(Client(raise_request_exception=False), "/health")
    assert response.status_code == 200
    body = json.loads(response.content)
    assert body.get("status") == "degraded"
    checks = body.get("checks", {})
    assert {name: item.get("status") for name, item in checks.items()} == dict.fromkeys(CHECK_NAMES, "fail")
    latency = {name: item.get("latency_ms") for name, item in checks.items()}
    assert all(isinstance(value, float) for value in latency.values()), latency
    assert elapsed < DOWN_LIMIT_S, f"/health 경과 {elapsed:.3f} s"
    assert latency["db"] >= 1500, latency
    assert latency["dragonfly"] < 1000, latency
    assert latency["kafka_producer"] < 1800, latency
    log_lines()  # sink의 새 줄을 raw에 쌓는다(raw는 부를 때만 자란다 — 부르지 않으면 로그 단언이 공허하다 · 변이 N02가 드러냈다)
    assert _leaks(_response_text(response) + log_lines.raw, needles) == [], _leaks(
        _response_text(response) + log_lines.raw, needles
    )


@pytest.mark.django_db(transaction=True)
def test_oc_38_deadline_bounds_ready_and_health(oc_settings: SettingsWrapper) -> None:
    """oc-38 — 마감 2.5 s(D6 · 전체 < 3 s): connect_timeout 5인 DB 블랙홀에서 /ready는 마감에 503 not_ready · /health는 마감에
    db fail · latency_ms = 마감 값 2500.0(Dragonfly · Kafka는 설정 없음 = 곧바로 fail) · 둘 다 < 3 s."""
    with blackhole() as db_port, _db_at("127.0.0.1", db_port, connect_timeout=5):
        client = Client(raise_request_exception=False)
        ready, ready_s = _timed_get(client, "/ready")
        health_response, health_s = _timed_get(client, "/health")
    assert_problem(ready, 503, "not_ready")
    assert 2.3 <= ready_s < DOWN_LIMIT_S, f"/ready 경과 {ready_s:.3f} s"
    body = json.loads(health_response.content)
    assert body["checks"]["db"] == {"status": "fail", "latency_ms": DEADLINE_MS}
    assert health_s < DOWN_LIMIT_S, f"/health 경과 {health_s:.3f} s"


def test_oc_39_in_flight_cap(oc_settings: SettingsWrapper) -> None:
    """oc-39 — 진행 중 검사 상한(D6 · 지속 정지에서 스레드가 쌓이지 않는다) 〔r2 Y2 — 공유 상한 32 → 검사 칸마다 8〕: 네 칸(/ready의
    DB · /health의 db · dragonfly · kafka_producer)을 시험이 모두 쥐면(남은 작업 스레드가 끝나기를 기다려 칸마다 정확히 8 · 9번째는
    실패) /health는 새 스레드 없이 곧바로 세 항목 fail(latency_ms 0.0) · /ready는 곧바로 503."""
    client = Client(raise_request_exception=False)
    with _slots_full(*HEALTH_SLOTS) as observed, _thread_starts() as starts:
        started = time.perf_counter()
        health_response = client.get("/health")
        ready = client.get("/ready")
        elapsed = time.perf_counter() - started
    assert observed == dict.fromkeys(HEALTH_SLOTS, (SLOT_LIMIT, False))
    body = json.loads(health_response.content)
    assert body["checks"] == {name: {"status": "fail", "latency_ms": 0.0} for name in CHECK_NAMES}
    assert_problem(ready, 503, "not_ready")
    assert starts == []
    assert elapsed < 0.5, f"경과 {elapsed:.3f} s"


@pytest.mark.django_db(transaction=True)
def test_oc_40_open_request_connection_does_not_hide_db_down(oc_settings: SettingsWrapper) -> None:
    """oc-40 — 요청 스레드에 열린 DB 연결이 있어도 다운을 본다(D6 — 검사는 작업 스레드의 새 연결): 요청 스레드(=시험 스레드)의
    default 연결을 열어 둔 채 설정을 닫힌 포트로 바꾸면 /ready 503 · /health db fail · 그 연결은 열린 채다."""
    connection = connections["default"]
    original = deepcopy(connection.settings_dict)
    failure: BaseException | None = None
    try:
        connection.ensure_connection()
    except Exception as exc:  # noqa: BLE001 — 원 트레이스백 없이 실패로 바꾼다(conninfo 비밀번호)
        failure = exc
    if failure is not None:
        _fail_without_trace("default DB 연결", failure)
    try:
        connection.settings_dict["HOST"] = "127.0.0.1"
        connection.settings_dict["PORT"] = str(closed_port())
        connection.settings_dict["OPTIONS"] = {**original["OPTIONS"], "connect_timeout": 1}
        client = Client(raise_request_exception=False)
        ready = _safe_get(client, "/ready")
        health_response = _safe_get(client, "/health")
        still_open = connection.connection is not None and not connection.connection.closed
    finally:
        connection.close()
        connection.settings_dict.clear()
        connection.settings_dict.update(original)
    assert_problem(ready, 503, "not_ready")
    assert json.loads(health_response.content)["checks"]["db"]["status"] == "fail"
    assert still_open


def test_oc_41_kafka_configuration_error_is_fail(oc_settings: SettingsWrapper) -> None:
    """oc-41 — Kafka 검사는 client_config()의 ImproperlyConfigured를 포함한 모든 예외를 fail로 바꾼다(D6 · 500 금지): 빈
    bootstrap · 금지 키 · SASL_SSL 필수 키 없음 → /health 200 · kafka_producer fail · 다이얼 없이 곧바로(< 1 s)."""
    cases = (
        ("", {"security.protocol": "PLAINTEXT"}),
        (f"127.0.0.1:{closed_port()}", {"security.protocol": "PLAINTEXT", "partitioner": "random"}),
        (f"127.0.0.1:{closed_port()}", {"security.protocol": "SASL_SSL"}),
    )
    observed = []
    for bootstrap, config in cases:
        oc_settings.KAFKA_BOOTSTRAP_SERVERS = bootstrap
        oc_settings.KAFKA_CLIENT_CONFIG = config
        response, elapsed = _timed_get(Client(raise_request_exception=False), "/health")
        status = json.loads(response.content)["checks"]["kafka_producer"]["status"]
        observed.append((response.status_code, status, elapsed < 1.0))
    assert observed == [(200, "fail", True)] * len(cases)


def test_oc_42_dragonfly_url_with_query_is_fail_without_dial(oc_settings: SettingsWrapper) -> None:
    """oc-42 — DRAGONFLY_URL에 쿼리가 있으면 시도 없이 fail(D6 · T070 D7 — 쿼리가 0.2 s · 재시도 0을 덮는다): 수락 수 0. 쿼리를
    떼면 같은 리스너에 다이얼한다(공허 방지) · str이 아닌 값도 fail."""
    listener = CountingListener()
    password = secrets.token_hex(8)
    try:
        oc_settings.DRAGONFLY_URL = Secret(f"redis://test-pod:{password}@{listener.address}/0?socket_timeout=5")
        with_query, _ = _timed_get(Client(raise_request_exception=False), "/health")
        query_dials = listener.count
        oc_settings.DRAGONFLY_URL = Secret(f"redis://test-pod:{password}@{listener.address}/0")
        without_query, _ = _timed_get(Client(raise_request_exception=False), "/health")
        plain_dials = listener.count - query_dials
        oc_settings.DRAGONFLY_URL = None
        not_text, _ = _timed_get(Client(raise_request_exception=False), "/health")
    finally:
        listener.close()
    statuses = [json.loads(response.content)["checks"]["dragonfly"]["status"] for response in (with_query, without_query, not_text)]
    assert statuses == ["fail", "fail", "fail"]
    assert query_dials == 0
    assert plain_dials >= 1


def test_oc_43_health_ignores_api_auth(oc_client: Client) -> None:
    """oc-43 — 세 연산 모두 auth=None(D6): 모든 연산을 거부하는 auth를 건 NinjaAPI에 붙여도 /secured/healthz · /secured/health는
    200(auth를 상속한 /secured/guarded는 401 — 공허 방지) · OpenAPI에 세 GET 경로가 보인다."""
    from tests.obscontractapp.urls import secured_api

    healthz = oc_client.get("/secured/healthz")
    detailed = oc_client.get("/secured/health")
    guarded = oc_client.get("/secured/guarded")
    assert (healthz.status_code, detailed.status_code, guarded.status_code) == (200, 200, 401)
    paths = secured_api.get_openapi_schema()["paths"]
    visible = sorted(path for path, operations in paths.items() if "get" in operations and "guarded" not in path)
    assert visible == ["/secured/health", "/secured/healthz", "/secured/ready"]


@pytest.mark.django_db(transaction=True)
def test_oc_44_health_body_shapes(oc_settings: SettingsWrapper) -> None:
    """oc-44 — 본문 꼴(D6 · 계약 헬스 표): /ready 200 = {"status": "ok"} · /health 키 = status · version · git_sha · checks ·
    항목 키 = status · latency_ms(사유 · 예외 문자열 없음) · /healthz의 APP_VERSION · APP_GIT_SHA가 str가 아니거나 없으면
    "unknown"(liveness는 설정 오류로 죽지 않는다)."""
    client = Client(raise_request_exception=False)
    ready = _safe_get(client, "/ready")
    assert ready.status_code == 200
    assert json.loads(ready.content) == {"status": "ok"}
    body = json.loads(_safe_get(client, "/health").content)
    assert sorted(body) == ["checks", "git_sha", "status", "version"]
    assert sorted(body["checks"]) == sorted(CHECK_NAMES)
    assert {name: sorted(item) for name, item in body["checks"].items()} == dict.fromkeys(
        CHECK_NAMES, ["latency_ms", "status"]
    )
    oc_settings.APP_VERSION = 7
    del oc_settings.APP_GIT_SHA
    healthz = client.get("/healthz")
    assert json.loads(healthz.content) == {"status": "ok", "version": "unknown", "git_sha": "unknown"}


# --- import 부작용 · 공개 이름(D8 · D11) -----------------------------------------------------------------------------


def test_oc_45_import_has_no_side_effects() -> None:
    """oc-45 — import 부작용 0(D11): 새 프로세스(시험 설정 · django.setup() 뒤)에서 observability · health를 import해도 소켓
    연결 · 이름 조회 · 스레드 시작 0 · structlog 미설정 · 루트 로거 핸들러 · 레벨 불변 · OTel 전역 provider Proxy · 계측 0 ·
    MIDDLEWARE 불변 · sentry_sdk 미import · prometheus 기본 REGISTRY 이름 집합 불변 · django_common.outbox.metrics 미import.
    공개 이름(D8): observability.__all__ · health.__all__ 정확히."""
    script = (
        "import json, socket, sys, threading\n"
        "counts = {'connect': 0, 'lookup': 0, 'thread_start': 0}\n"
        "def counting(name, real):\n"
        "    def wrapper(*args, **kwargs):\n"
        "        counts[name] += 1\n"
        "        return real(*args, **kwargs)\n"
        "    return wrapper\n"
        "result = {}\n"
        "try:\n"
        "    import logging\n"
        "    import django\n"
        "    django.setup()\n"
        "    from django.conf import settings\n"
        "    import structlog\n"
        "    from prometheus_client import REGISTRY\n"
        "    from opentelemetry import trace\n"
        "    root = logging.getLogger()\n"
        "    handlers_before = list(root.handlers)\n"
        "    level_before = root.level\n"
        "    middleware_before = list(settings.MIDDLEWARE)\n"
        "    names_before = sorted(metric.name for metric in REGISTRY.collect())\n"
        "    sentry_before = 'sentry_sdk' in sys.modules\n"
        "    socket.socket.connect = counting('connect', socket.socket.connect)\n"
        "    socket.socket.connect_ex = counting('connect', socket.socket.connect_ex)\n"
        "    socket.create_connection = counting('connect', socket.create_connection)\n"
        "    socket.getaddrinfo = counting('lookup', socket.getaddrinfo)\n"
        "    threading.Thread.start = counting('thread_start', threading.Thread.start)\n"
        "    threads_before = threading.active_count()\n"
        "    import django_common.observability as observability\n"
        "    import django_common.health as health\n"
        "    from opentelemetry.instrumentation.django import DjangoInstrumentor\n"
        "    result = dict(counts)\n"
        "    result.update({\n"
        "        'threads_delta': threading.active_count() - threads_before,\n"
        "        'structlog_configured': structlog.is_configured(),\n"
        "        'root_same': root.handlers == handlers_before and root.level == level_before,\n"
        "        'provider': type(trace.get_tracer_provider()).__name__,\n"
        "        'instrumented': DjangoInstrumentor().is_instrumented_by_opentelemetry,\n"
        "        'middleware_same': list(settings.MIDDLEWARE) == middleware_before,\n"
        "        'sentry_before': sentry_before,\n"
        "        'sentry_after': 'sentry_sdk' in sys.modules,\n"
        "        'registry_same': sorted(metric.name for metric in REGISTRY.collect()) == names_before,\n"
        "        'outbox_metrics': 'django_common.outbox.metrics' in sys.modules,\n"
        "        'observability_all': sorted(observability.__all__),\n"
        "        'health_all': sorted(health.__all__),\n"
        "    })\n"
        "except Exception as exc:\n"
        "    result = {'error': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    )
    assert _run_child(script) == {
        "connect": 0,
        "lookup": 0,
        "thread_start": 0,
        "threads_delta": 0,
        "structlog_configured": False,
        "root_same": True,
        "provider": "ProxyTracerProvider",
        "instrumented": False,
        "middleware_same": True,
        "sentry_before": False,
        "sentry_after": False,
        "registry_same": True,
        "outbox_metrics": False,
        "observability_all": sorted(
            ["RequestIdMiddleware", "configure_logging", "configure_otel", "configure_sentry", "mask_sensitive", "sub_hash"]
        ),
        "health_all": ["health_router"],
    }


# --- librdkafka 로그(D9) ------------------------------------------------------------------------------------------


def test_oc_46_health_kafka_client_logs_off(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-46 — /health의 Kafka 검사 클라이언트만 librdkafka 로그를 끈다(D9 · D6 — 장애 신호는 relay 프로듀서 줄과 이 검사 결과가
    맡는다 · 끄지 않으면 Kafka 장애 동안 요청마다 stderr에 비JSON 줄이 쌓인다): AdminClient에 넘긴 설정 = client_config() +
    log_level 0(다른 키는 그대로 · 한 번만 만든다). 설정 dict는 단언 피연산자로 싣지 않는다(KAFKA_CLIENT_CONFIG는 운영에서
    sasl.password를 담는다)."""
    seen: list[dict[str, Any]] = []
    real_admin_client = health.AdminClient

    def recording(config: dict[str, Any]) -> Any:
        seen.append(dict(config))
        return real_admin_client(config)

    monkeypatch.setattr(health, "AdminClient", recording)
    oc_settings.KAFKA_BOOTSTRAP_SERVERS = f"127.0.0.1:{closed_port()}"
    response, _ = _timed_get(Client(raise_request_exception=False), "/health")
    expected = {**client_config(), "log_level": 0}
    assert response.status_code == 200
    assert len(seen) == 1
    matches = seen[0] == expected
    assert matches, f"AdminClient 설정 키 {sorted(seen[0])} · log_level {seen[0].get('log_level')!r}"


# --- 헬스 칸(D6 〔r2 Y2〕) -----------------------------------------------------------------------------------------


@pytest.mark.django_db(transaction=True)
def test_oc_47_health_slots_full_ready_still_judges_db(oc_settings: SettingsWrapper) -> None:
    """oc-47 〔r2 Y2 (1)〕 — /health의 세 칸(db · dragonfly · kafka_producer)을 상한까지 채워도 DB가 살아 있으면 /ready는 200이다
    (readiness = DB만 — /health의 부하 · 버려진 스레드가 readiness를 바꾸지 않는다): 그때 /health는 새 스레드 없이 세 항목
    fail(latency_ms 0.0)이고, /ready는 자기 칸의 새 스레드 하나로 실제 DB를 본다."""
    client = Client(raise_request_exception=False)
    with _slots_full("db", "dragonfly", "kafka_producer") as observed, _thread_starts() as starts:
        checks = _health_checks(client)
        ready = _safe_get(client, "/ready")
    assert observed == dict.fromkeys(("db", "dragonfly", "kafka_producer"), (SLOT_LIMIT, False))
    assert checks == {name: {"status": "fail", "latency_ms": 0.0} for name in CHECK_NAMES}
    assert ready.status_code == 200
    assert json.loads(ready.content) == {"status": "ok"}
    assert starts == [f"{HEALTH_THREAD}ready"]


def test_oc_48_kafka_slot_full_fails_only_kafka(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-48 〔r2 Y2 (2)〕 — Kafka 칸만 채우면 /health의 kafka_producer만 곧바로 fail(latency_ms 0.0 · 새 스레드 없음)이고 db ·
    dragonfly는 자기 칸의 새 스레드로 그대로 판정한다(한 의존의 정지가 다른 항목을 fail로 만들지 않는다). 세 probe는 곧바로 ok를
    알리는 대역이다."""
    probes = {name: _FakeProbe() for name in CHECK_NAMES}
    monkeypatch.setattr(health, "_db_probe", probes["db"])
    monkeypatch.setattr(health, "_dragonfly_probe", probes["dragonfly"])
    monkeypatch.setattr(health, "_kafka_probe", probes["kafka_producer"])
    client = Client(raise_request_exception=False)
    try:
        with _slots_full("kafka_producer") as observed, _thread_starts() as starts:
            checks = _health_checks(client)
    finally:
        joined = [probe.join() for probe in probes.values()]
    assert observed == {"kafka_producer": (SLOT_LIMIT, False)}
    assert checks["kafka_producer"] == {"status": "fail", "latency_ms": 0.0}
    assert {name: checks[name]["status"] for name in ("db", "dragonfly")} == {"db": "ok", "dragonfly": "ok"}
    assert sorted(starts) == [f"{HEALTH_THREAD}db", f"{HEALTH_THREAD}dragonfly"]
    assert probes["kafka_producer"].calls == 0
    assert all(joined)


def test_oc_49_ready_slot_full_leaves_health_db(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-49 〔r2 Y2 (3)〕 — /ready 칸을 채우면 /ready는 곧바로 503(새 스레드 없음)이고, /health의 db는 자기 칸에서 그대로 판정한다
    (같은 probe 함수를 두 칸이 따로 센다 · 세 probe는 곧바로 ok를 알리는 대역)."""
    probes = {name: _FakeProbe() for name in CHECK_NAMES}
    monkeypatch.setattr(health, "_db_probe", probes["db"])
    monkeypatch.setattr(health, "_dragonfly_probe", probes["dragonfly"])
    monkeypatch.setattr(health, "_kafka_probe", probes["kafka_producer"])
    client = Client(raise_request_exception=False)
    try:
        with _slots_full("ready") as observed, _thread_starts() as starts:
            ready = client.get("/ready")
            ready_starts = list(starts)
            checks = _health_checks(client)
    finally:
        joined = [probe.join() for probe in probes.values()]
    assert observed == {"ready": (SLOT_LIMIT, False)}
    assert_problem(ready, 503, "not_ready")
    assert ready_starts == []
    assert {name: item["status"] for name, item in checks.items()} == dict.fromkeys(CHECK_NAMES, "ok")
    assert sorted(starts) == sorted(f"{HEALTH_THREAD}{name}" for name in CHECK_NAMES)
    assert all(joined)


def test_oc_50_cleaning_up_threads_hold_the_slot(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-50 〔r2 Y2 (4)〕 — 상한은 결과를 알린 뒤 정리 중인 스레드까지 센다: Kafka probe 대역이 ok를 알린 뒤 붙들려 있으면(정리 중)
    /health 8번은 모두 kafka ok인데 그 스레드 8이 살아 있고, 9번째 /health의 kafka_producer는 새 스레드 없이 곧바로 fail(latency_ms
    0.0)이다(db · dragonfly는 ok). 붙든 스레드가 끝나면 다음 호출은 새 검사다(probe를 다시 부르고 ok — 결과 재사용 없음)."""
    release = threading.Event()
    kafka = _FakeProbe(hold_after=release)
    db, dragonfly = _FakeProbe(), _FakeProbe()
    monkeypatch.setattr(health, "_kafka_probe", kafka)
    monkeypatch.setattr(health, "_db_probe", db)
    monkeypatch.setattr(health, "_dragonfly_probe", dragonfly)
    _wait_slot_free("kafka_producer")
    client = Client(raise_request_exception=False)
    try:
        filling = [_health_checks(client)["kafka_producer"]["status"] for _ in range(SLOT_LIMIT)]
        alive = kafka.alive()
        with _thread_starts() as starts:
            ninth = _health_checks(client)
    finally:
        release.set()
        joined = [probe.join() for probe in (kafka, db, dragonfly)]
    fresh = _health_checks(client)
    joined.append(kafka.join())
    assert filling == ["ok"] * SLOT_LIMIT
    assert alive == SLOT_LIMIT
    assert ninth["kafka_producer"] == {"status": "fail", "latency_ms": 0.0}
    assert {name: ninth[name]["status"] for name in ("db", "dragonfly")} == {"db": "ok", "dragonfly": "ok"}
    assert f"{HEALTH_THREAD}kafka_producer" not in starts
    assert fresh["kafka_producer"]["status"] == "ok"
    assert kafka.calls == SLOT_LIMIT + 1
    assert all(joined)


def test_oc_51_abandoned_threads_hold_the_slot(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-51 〔r2 Y2 (4)〕 — 상한은 마감을 넘겨 버려진 스레드도 센다: /ready의 DB probe 대역이 알리기 전에 붙들려 있으면(이 시험은
    마감을 0.05 s로 줄인다) /ready 8번은 마감에 503이고 그 스레드 8이 살아 있으며, 9번째 /ready는 새 스레드 없이 곧바로 503이다.
    붙든 스레드가 끝나면 다음 /ready는 새 검사다(200). 〔r3 Z7〕 살아 있는 수는 대역 probe에 들어온 스레드가 8이 되기를
    기다린 뒤(HANG_LIMIT_S) 센다(작업 스레드가 마감 50 ms 안에 probe에 들어온다는 가정을 없앤다)."""
    gate = threading.Event()
    db = _FakeProbe(hold_before=gate)
    monkeypatch.setattr(health, "_db_probe", db)
    _wait_slot_free("ready")
    client = Client(raise_request_exception=False)
    try:
        with pytest.MonkeyPatch.context() as patch:
            patch.setattr(health, "_DEADLINE_S", 0.05)
            filling = [client.get("/ready").status_code for _ in range(SLOT_LIMIT)]
            entered = db.wait_calls(SLOT_LIMIT)
            alive = db.alive()
            with _thread_starts() as starts:
                ninth = client.get("/ready")
    finally:
        gate.set()
        joined = [db.join()]
    fresh = client.get("/ready")
    joined.append(db.join())
    assert filling == [503] * SLOT_LIMIT
    assert entered
    assert alive == SLOT_LIMIT
    assert_problem(ninth, 503, "not_ready")
    assert starts == []
    assert fresh.status_code == 200
    assert db.calls == SLOT_LIMIT + 1
    assert all(joined)


# --- Sentry 상관 값(D7 〔r2 Y3〕) ----------------------------------------------------------------------------------


def test_oc_52_forged_correlation_values_are_dropped(
    oc_otel: tuple[TracerProvider, InMemorySpanExporter], sentry_capture: CaptureTransport, log_lines: LogLines
) -> None:
    """oc-52 〔r2 Y3〕 — 클라이언트가 정한 상관 값은 Sentry 이벤트 · envelope 머리에 남지 않는다(B-6): 꼴 밖 X-Request-ID(감시 값 +
    공백 — pod가 새 uuid4로 바꾼다) · 위조 sentry-trace(무작위 trace · span id) · baggage(sentry-public_key · sentry-release ·
    sentry-environment에 감시 값)를 실제 WSGIHandler 경로로 보낸다. sampled traceparent 요청: contexts.trace의 trace_id · span_id =
    기록 중 OTel span(내보낸 span과 같다) · parent_span_id · dynamic_sampling_context 없음. 비샘플 요청: contexts.trace 없음. 두
    이벤트 모두 요청 헤더에 x-request-id 없음 · 태그 request_id = 응답 X-Request-ID(새 uuid4) · envelope 머리에 trace 없음 · 이벤트 ·
    envelope 직렬화 바이트 · 그 요청들의 로그 어디에도 감시 값 · 위조 id가 없다. 〔r3 Z2〕 세 번째 요청의 꼴 밖 traceparent(감시 값 +
    꼬리 — OTel이 버린다)도 이벤트 본문 · envelope 직렬화 바이트 · 로그 어디에도 없고, 세 이벤트 모두 요청 헤더에 traceparent가
    없다(검증된 trace 문맥은 contexts.trace · 태그가 기록 중 span일 때만 싣는다)."""
    _, exporter = oc_otel
    needles = {name: _sentinel(name) for name in ("request-id", "public-key", "release", "environment")}
    forged_trace, forged_span = secrets.token_hex(16), secrets.token_hex(8)
    needles.update({"forged-trace": forged_trace, "forged-span": forged_span})
    otel_trace, sampled = _traceparent(sampled=True)
    _, unsampled = _traceparent(sampled=False)
    forged = {
        REQUEST_ID: f"{needles['request-id']} x",
        "sentry-trace": f"{forged_trace}-{forged_span}-1",
        "baggage": (
            f"sentry-trace_id={forged_trace},sentry-public_key={needles['public-key']},"
            f"sentry-release={needles['release']},sentry-environment={needles['environment']}"
        ),
    }
    first = call_wsgi(_environ("GET", "/oc/boom", headers={**forged, "traceparent": sampled}))
    second = call_wsgi(_environ("GET", "/oc/boom", headers={**forged, "traceparent": unsampled}))
    assert (first.status, second.status) == (500, 500)
    events = sentry_capture.events()
    assert len(events) == 2
    spans = exporter.get_finished_spans()
    assert len(spans) == 1
    recorded = events[0].get("contexts", {}).get("trace", {})
    # 값은 단언 피연산자로 싣지 않는다(위조 id가 실패 출력에 실리지 않게) — 맞는지만 접는다.
    same_ids = (
        recorded.get("trace_id") == otel_trace,
        otel_trace == format(spans[0].context.trace_id, "032x"),
        recorded.get("span_id") == format(spans[0].context.span_id, "016x"),
    )
    assert same_ids == (True, True, True)
    assert sorted({"parent_span_id", "dynamic_sampling_context"} & set(recorded)) == [], sorted(
        {"parent_span_id", "dynamic_sampling_context"} & set(recorded)
    )
    assert "trace" not in events[1].get("contexts", {})
    for event, result in zip(events, (first, second), strict=True):
        request_id = result.headers.get("x-request-id", "")
        assert "x-request-id" not in _header_names(event)
        assert event.get("tags", {}).get("request_id") == request_id
        assert uuid.UUID(request_id).version == 4
    assert [sorted(headers) for headers in sentry_capture.envelope_headers() if "trace" in headers] == []
    serialized = "\n".join(chunk.decode("utf-8", errors="replace") for chunk in sentry_capture.serialized())
    assert _leaks(json.dumps(events) + serialized, needles) == [], _leaks(json.dumps(events) + serialized, needles)
    log_lines()  # sink의 새 줄을 raw에 쌓는다
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)
    # 〔r3 Z2〕 꼴 밖 traceparent — 새 루트 span의 샘플링(0.1)은 무작위라 contexts.trace · span 수는 보지 않는다.
    malformed = {"traceparent": _sentinel("traceparent")}
    third = call_wsgi(_environ("GET", "/oc/boom", headers={"traceparent": f"{malformed['traceparent']} junk"}))
    assert third.status == 500
    all_events = sentry_capture.events()
    assert len(all_events) == 3
    assert [sorted(_header_names(event) & {"traceparent"}) for event in all_events] == [[], [], []]
    serialized_all = "\n".join(chunk.decode("utf-8", errors="replace") for chunk in sentry_capture.serialized())
    assert _leaks(json.dumps(all_events) + serialized_all, malformed) == [], _leaks(
        json.dumps(all_events) + serialized_all, malformed
    )
    log_lines()
    assert _leaks(log_lines.raw, malformed) == [], _leaks(log_lines.raw, malformed)


# --- 로그 쓰기 실패 · 수준 이름(D2 〔r2 Y4 · Y6〕) -------------------------------------------------------------------


def test_oc_53_emit_failure_writes_fixed_line(log_sink: io.StringIO, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-53 〔r2 Y4〕 — 표식 핸들러의 쓰기 · 렌더가 실패하면 레코드 값 없이 고정 JSON 한 줄(ts · level error · logger
    django_common.observability · event log_emit_failed · error = 예외 클래스 이름)만 부를 때의 sys.stderr에 쓴다 — 표준 handleError의
    「--- Logging error ---」 · 트레이스백 · `Message: %r` · `Arguments:`가 없다(repr 금지 우회를 막는다 · B-4): 쓰기 OSError(structlog
    줄 · stdlib 줄의 args) · 렌더 예외(isoformat이 예외를 내는 datetime) → 실패 한 번에 고정 줄 하나 · 감시 값 없음. 4300자리를 넘는
    int는 새 프로세스에서 본다(pytest LogCaptureHandler는 그 레코드의 str() 실패를 다시 올려 우리 핸들러 앞에서 로그 호출을 끝낸다).
    끝나면 세션 sink로 되돌린다."""
    needles = {name: _sentinel(name) for name in ("repr", "note", "arg", "clock")}
    stderr = io.StringIO()
    monkeypatch.setattr(sys, "stderr", stderr)
    chunks: list[str] = []

    def take() -> None:
        chunks.append(stderr.getvalue())
        stderr.seek(0)
        stderr.truncate()

    try:
        configure_logging(stream=_BrokenStream())
        structlog.get_logger("tests.oc.emit").info("oc_emit_write", probe=_ReprProbe(needles["repr"]), note=needles["note"])
        take()
        logging.getLogger("tests.oc.emit").warning("oc emit stdlib %s", needles["arg"])
        take()
        configure_logging(stream=io.StringIO())
        structlog.get_logger("tests.oc.emit").info(
            "oc_emit_render", when=_BadClock(2026, 11, 6, tzinfo=dt.UTC), note=needles["clock"]
        )
        take()
    finally:
        configure_logging(stream=log_sink)
    shapes = [_emit_failure_shape(chunk) for chunk in chunks]
    fixed = ("fixed", "error", "django_common.observability", "log_emit_failed")
    assert shapes == [(*fixed, "OSError"), (*fixed, "OSError"), (*fixed, "RuntimeError")]
    assert _leaks("".join(chunks), needles) == [], _leaks("".join(chunks), needles)
    int_needle = _sentinel("int")
    script = (
        "import io, json, sys\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    import structlog\n"
        "    from django_common.observability import configure_logging\n"
        "    configure_logging(stream=io.StringIO())\n"
        "    captured = io.StringIO()\n"
        "    real = sys.stderr\n"
        "    sys.stderr = captured\n"
        "    try:\n"
        "        structlog.get_logger('tests.oc.emit').info('oc_emit_int', big=10 ** 5000, note=NEEDLE)\n"
        "    finally:\n"
        "        sys.stderr = real\n"
        "    text = captured.getvalue()\n"
        "    lines = text.split(chr(10))\n"
        "    first = json.loads(lines[0]) if lines[0] else None\n"
        "    shaped = isinstance(first, dict)\n"
        "    result = {\n"
        "        'lines': len(lines),\n"
        "        'keys': sorted(first) if shaped else None,\n"
        "        'event': first.get('event') if shaped else None,\n"
        "        'error': first.get('error') if shaped else None,\n"
        "        'leaked': NEEDLE in text,\n"
        "    }\n"
        "except Exception as exc:\n"
        "    result = {'failure': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    ).replace("NEEDLE", repr(int_needle))
    assert _run_child(script) == {
        "lines": 2,
        "keys": ["error", "event", "level", "logger", "ts"],
        "event": "log_emit_failed",
        "error": "ValueError",
        "leaked": False,
    }


def test_oc_54_configure_logging_rejects_unknown_level(log_sink: io.StringIO, log_lines: LogLines) -> None:
    """oc-54 〔r2 Y6〕 — level이 logging 수준 이름(대소문자 무시)이 아니면 핸들러를 바꾸기 전에 ValueError(D2 · 계약 §공개 API):
    모르는 이름 · 빈 값 · 수 · None → ValueError · 루트 핸들러 · 레벨은 그대로이고 다음 줄은 원래 sink로 간다(새 stream은 비어
    있다) · 소문자 이름(warning)은 받는다. 끝나면 세션 sink로 되돌린다."""
    root = logging.getLogger()
    handlers_before = list(root.handlers)
    level_before = root.level
    fresh = io.StringIO()
    rejected: list[Any] = []
    try:
        for value in ("bogus", "", 10, None):
            try:
                configure_logging(stream=fresh, level=value)  # type: ignore[arg-type]
            except ValueError:
                rejected.append(value)
        unchanged = (list(root.handlers) == handlers_before, root.level == level_before)
        structlog.get_logger("tests.oc.level").info("oc_level_after_reject")
        fresh_text = fresh.getvalue()
        configure_logging(stream=io.StringIO(), level="warning")
        lowered = root.level
    finally:
        configure_logging(stream=log_sink)
    assert rejected == ["bogus", "", 10, None]
    assert unchanged == (True, True)
    assert fresh_text == ""
    assert _one(log_lines(), "oc_level_after_reject").get("logger") == "tests.oc.level"
    assert lowered == logging.WARNING


# --- 계측 미들웨어 삽입(D5 〔r2 Y6〕) -------------------------------------------------------------------------------


class _Conflict:
    """instrument()가 의존성 충돌로 보고 조용히 끝나게 하는 대역(BaseInstrumentor는 참이면 ERROR 한 줄을 남기고 돌아간다)."""

    def __bool__(self) -> bool:
        return True

    def _format_message(self, name: str) -> str:
        return f"oc dependency conflict for {name}"


def test_oc_55_instrumentation_must_insert_middleware(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-55 〔r2 Y6〕 — instrument() 뒤 계측 미들웨어가 MIDDLEWARE에 없으면 ImproperlyConfigured(D5 — 의존성 충돌이면
    instrument()가 ERROR 한 줄만 남기고 아무것도 하지 않는다 · 조용한 열림 대신 기동 실패): 의존성 충돌 · 계측 본체가 아무것도 하지
    않는 경우 둘 다 거부(이름 · 연쇄 없음) · 계측 0 · MIDDLEWARE 불변 · 내보내기 스레드는 provider shutdown이 거둔다."""
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", f"http://127.0.0.1:{closed_port()}")
    cases: dict[str, tuple[str, Callable[..., Any]]] = {
        "conflict": ("_check_dependency_conflicts", lambda self: _Conflict()),
        "noop": ("_instrument", lambda self, **kwargs: None),
    }
    outcomes: dict[str, tuple[Any, ...]] = {}
    for case, (attribute, replacement) in cases.items():
        before = _bsp_threads()
        with pytest.MonkeyPatch.context() as patch:
            patch.setattr(DjangoInstrumentor, attribute, replacement)
            try:
                configure_otel()
            except ImproperlyConfigured as error:
                outcome: tuple[Any, ...] = ("MIDDLEWARE" in str(error), error.__cause__ is None)
            else:
                outcome = ("accepted",)
                DjangoInstrumentor().uninstrument()
        outcomes[case] = (
            outcome,
            DjangoInstrumentor().is_instrumented_by_opentelemetry,
            oc_settings.MIDDLEWARE == list(OC_MIDDLEWARE),
            _bsp_threads() - before,
        )
    assert outcomes == dict.fromkeys(cases, ((True, True), False, True, 0))


# --- 마스킹 실제 sink(D2 〔r3 Z4〕) -----------------------------------------------------------------------------------


def test_oc_56_meta_headers_cookies_dump_is_masked(
    oc_otel: tuple[TracerProvider, InMemorySpanExporter], oc_client: Client, log_lines: LogLines
) -> None:
    """oc-56 〔r3 Z4 · B-4〕 — 실제 sink(configure_logging 세션 설정 + configure_otel 계측): 뷰가 request.META · request.headers ·
    request.COOKIES를 로그 필드로 넘겨도(호출자 규칙을 어긴 사고) 그 줄에 쿼리 · Referer · 쿠키의 감시 값이 없다 — OTel이 META에 두는
    요청 속성 dict(http.url에 쿼리)는 접두 opentelemetry-instrumentor-로, HTTP_REFERER · Referer는 referer로, QUERY_STRING · RAW_URI는
    META 이름으로, `__Host-` 접두 쿠키는 접두를 뗀 이름(sessionid)으로 키째 지워진다. gunicorn RAW_URI 경로(뷰 시점의 http.target은
    route)도 같다. 이웃 값(PATH_INFO · REQUEST_METHOD · Accept · 마스킹 이름이 아닌 쿠키)은 남는다(공허 방지)."""
    needles = {name: _sentinel(name) for name in ("query", "referer", "cookie", "raw-query")}
    plain = oc_client.get(
        f"/oc/dump?access_token={needles['query']}",
        headers={
            "Referer": f"http://127.0.0.1/cb?code={needles['referer']}",
            "Cookie": f"__Host-sessionid={needles['cookie']}; theme=dark",
            "Accept": "application/json",
        },
    )
    raw = f"/oc/dump?access_token={needles['raw-query']}"
    gunicorn = oc_client.get(raw, RAW_URI=raw)
    assert (plain.status_code, gunicorn.status_code) == (200, 200)
    records = log_lines()
    dumps = [_one(_for_request(records, response[REQUEST_ID]), "oc_dump") for response in (plain, gunicorn)]
    meta, headers, cookies = (dumps[0].get(key, {}) for key in ("meta", "headers", "cookies"))
    kept = (
        meta.get("PATH_INFO") == "/oc/dump",
        meta.get("REQUEST_METHOD") == "GET",
        headers.get("Accept") == "application/json",
        cookies.get("theme") == "dark",
    )
    assert kept == (True, True, True, True)
    # 키 이름만 견준다(값은 피연산자로 싣지 않는다).
    gone = (
        sorted(
            key
            for key in meta
            if str(key).startswith(("opentelemetry-instrumentor-", "HTTP_REFERER", "HTTP_COOKIE", "QUERY_STRING"))
        ),
        sorted(key for key in headers if str(key).lower() in ("referer", "cookie")),
        sorted(key for key in cookies if "sessionid" in str(key)),
        sorted(key for key in dumps[1].get("meta", {}) if str(key).startswith(("RAW_URI", "QUERY_STRING", "opentelemetry"))),
    )
    assert gone == ([], [], [], [])
    assert _leaks(log_lines.raw, needles) == [], _leaks(log_lines.raw, needles)


# --- OTel 운영 경로 · 굳은 값 · 지표(D5 〔r3 Z1〕) --------------------------------------------------------------------


def test_oc_57_propagators_checked_before_otel_import() -> None:
    """oc-57 〔r3 Z1 · B-1〕 — 운영 경로(env가 OTel import 전에 있다 · 새 프로세스): 모르는 이름(감시 토큰)이 든 OTEL_PROPAGATORS는
    configure_otel이 OTel을 import하기 전에 이름만 실은 ImproperlyConfigured로 끝낸다 — OTel import가 내는 값 실은 ValueError가 아니다 ·
    연쇄 없음 · opentelemetry.propagate는 올라오지 않았다 · 자식 출력(stdout · stderr) 어디에도 감시 값이 없다."""
    needle = _sentinel("propagator")
    script = (
        "import json, os, sys\n"
        "os.environ['OTEL_PROPAGATORS'] = 'tracecontext,' + NEEDLE\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter\n"
        "    from django_common.observability import configure_otel\n"
        "    try:\n"
        "        configure_otel(span_exporter=InMemorySpanExporter())\n"
        "    except Exception as exc:\n"
        "        message = str(exc)\n"
        "        context = exc.__context__ is not None and not exc.__suppress_context__\n"
        "        result = {\n"
        "            'error': type(exc).__name__,\n"
        "            'named': 'OTEL_PROPAGATORS' in message,\n"
        "            'leaked': NEEDLE in message,\n"
        "            'chained': exc.__cause__ is not None or context,\n"
        "        }\n"
        "    else:\n"
        "        result = {'error': None}\n"
        "    result['propagate_loaded'] = 'opentelemetry.propagate' in sys.modules\n"
        "except Exception as exc:\n"
        "    result = {'failure': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    ).replace("NEEDLE", repr(needle))
    result, output = _run_child_full(script)
    assert result == {
        "error": "ImproperlyConfigured",
        "named": True,
        "leaked": False,
        "chained": False,
        "propagate_loaded": False,
    }
    assert _leaks(output, {"propagator": needle}) == [], _leaks(output, {"propagator": needle})


def test_oc_58_blank_traced_request_attrs_at_import() -> None:
    """oc-58 〔r3 Z1 · A-3〕 — 운영 경로(env가 OTel import 전에 있다 · 새 프로세스): 공백뿐인 OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS를
    env 검사(strip — 빈 값)와 굳은 값 확인(OTel은 [""]로 굳힌다 — 공백 항목만인 list는 빈 것)이 같은 판정으로 받는다(계측 1 ·
    굳은 값 [""] — getattr(request, "")는 None이라 span에 싣는 것이 없다)."""
    script = (
        "import json, os\n"
        "os.environ['OTEL_PYTHON_DJANGO_TRACED_REQUEST_ATTRS'] = '   '\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter\n"
        "    from django_common.observability import configure_otel\n"
        "    configure_otel(span_exporter=InMemorySpanExporter())\n"
        "    from opentelemetry.instrumentation.django import DjangoInstrumentor\n"
        "    from opentelemetry.instrumentation.django.middleware.otel_middleware import _DjangoMiddleware\n"
        "    result = {\n"
        "        'instrumented': DjangoInstrumentor().is_instrumented_by_opentelemetry,\n"
        "        'frozen': list(_DjangoMiddleware._traced_request_attrs),\n"
        "    }\n"
        "except Exception as exc:\n"
        "    result = {'error': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    )
    assert _run_child(script) == {"instrumented": True, "frozen": [""]}


def test_oc_59_django_instrumentation_metrics_off() -> None:
    """oc-59 〔r3 Z1 · B-6〕 — Django 계측의 OTel 지표는 끈다(meter_provider = NoOp — web 지표는 prometheus_client): 새 프로세스에
    전역 SDK MeterProvider + InMemoryMetricReader를 둔 채 configure_otel 뒤 쿼리에 감시 값을 넣은 404 요청과 미들웨어가 단락하는
    요청(gunicorn RAW_URI 꼴 — 둘 다 process_view가 없어 http.target이 route로 바뀌지 않는다)을 보낸다 → Django 계측 범위의 data
    point 0 · 직렬화한 지표 어디에도 감시 값 없음. 대조: 같은 MeterProvider의 시험 계수기는 읽힌다(reader가 살아 있다 — 공허 방지)."""
    needle = _sentinel("metric")
    script = (
        "import json\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    from django.conf import settings\n"
        "    from opentelemetry import metrics\n"
        "    from opentelemetry.sdk.metrics import MeterProvider\n"
        "    from opentelemetry.sdk.metrics.export import InMemoryMetricReader\n"
        "    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter\n"
        "    reader = InMemoryMetricReader()\n"
        "    metrics.set_meter_provider(MeterProvider(metric_readers=[reader]))\n"
        "    metrics.get_meter('oc-control').create_counter('oc_control_total').add(1)\n"
        "    settings.ALLOWED_HOSTS = ['testserver']\n"
        "    settings.MIDDLEWARE = [__SHORT__]\n"
        "    settings.ROOT_URLCONF = __URLS__\n"
        "    from django_common.observability import configure_otel\n"
        "    configure_otel(span_exporter=InMemorySpanExporter())\n"
        "    from django.test import Client\n"
        "    client = Client(raise_request_exception=False)\n"
        "    missing = '/oc/missing?access_token=' + NEEDLE\n"
        "    first = client.get(missing, RAW_URI=missing)\n"
        "    guarded = '/oc/ping?sub=' + NEEDLE\n"
        "    second = client.get(guarded, HTTP_X_OC_SHORT_CIRCUIT='1', RAW_URI=guarded)\n"
        "    data = reader.get_metrics_data()\n"
        "    text = data.to_json() if data is not None else ''\n"
        "    points = {}\n"
        "    for resource_metrics in data.resource_metrics if data is not None else []:\n"
        "        for scope_metrics in resource_metrics.scope_metrics:\n"
        "            count = sum(len(metric.data.data_points) for metric in scope_metrics.metrics)\n"
        "            points[scope_metrics.scope.name] = points.get(scope_metrics.scope.name, 0) + count\n"
        "    result = {\n"
        "        'statuses': [first.status_code, second.status_code],\n"
        "        'django_points': sum(n for name, n in points.items() if 'django' in name),\n"
        "        'control_points': points.get('oc-control', 0),\n"
        "        'leaked': NEEDLE in text,\n"
        "    }\n"
        "except Exception as exc:\n"
        "    result = {'error': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    )
    script = (
        script.replace("NEEDLE", repr(needle))
        .replace("__SHORT__", repr(SHORT_CIRCUIT_MIDDLEWARE))
        .replace("__URLS__", repr(OC_URLCONF))
    )
    result, output = _run_child_full(script)
    assert result == {"statuses": [404, 403], "django_points": 0, "control_points": 1, "leaked": False}
    assert _leaks(output, {"metric": needle}) == [], _leaks(output, {"metric": needle})


class _FieldsFail(TextMapPropagator):
    """fields를 읽으면 예외를 내는 propagator(굳은 값 확인 (b)가 읽다 실패하는 경우 · 〔r3 Z1〕)."""

    def extract(self, carrier: Any, context: Context | None = None, getter: Any = None) -> Context:
        return context if context is not None else Context()

    def inject(self, carrier: Any, context: Context | None = None, setter: Any = None) -> None:
        return None

    @property
    def fields(self) -> set[str]:
        raise RuntimeError("oc-fields")


def test_oc_60_frozen_otel_state(oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-60 〔r3 Z1〕 — instrument() 뒤 import 때 굳은 OTel 상태 확인(삽입 확인과 같은 자리): (a) 요청 속성 목록이 공백 항목만이면
    받는다([""] · ["  ", ""] — OTel이 공백 env를 굳힌 꼴 · A-3) · (b) 전역 propagator(import 때 OTEL_PROPAGATORS로 굳는다)의 fields에
    traceparent가 없거나(baggage만 · 빈 Composite = none) 읽다 예외가 나면 · (c) semconv HTTP 모드(프로세스에 한 번 굳는다)가 기본이
    아니면(http · http/dup) 거부 — 이름(OTEL_PROPAGATORS · OTEL_SEMCONV_STABILITY_OPT_IN)만 · 연쇄 없음 · 계측 0 · MIDDLEWARE 불변 ·
    내보내기 스레드는 provider shutdown이 거둔다. 전역 상태는 시험 안에서 바꾸고 되돌린다 · 기본 상태는 받는다(대조)."""
    monkeypatch.setenv("OTEL_EXPORTER_OTLP_ENDPOINT", f"http://127.0.0.1:{closed_port()}")
    outcomes: dict[str, tuple[Any, ...]] = {}
    for case, value in (("blank-1", [""]), ("blank-2", ["  ", ""])):
        with pytest.MonkeyPatch.context() as patch:
            patch.setattr(_DjangoMiddleware, "_traced_request_attrs", value)
            try:
                with _otel(InMemorySpanExporter()):
                    outcomes[case] = ("instrumented", DjangoInstrumentor().is_instrumented_by_opentelemetry)
            except ImproperlyConfigured:
                outcomes[case] = ("rejected",)
    stability = _OpenTelemetrySemanticConventionStability
    mapping = dict(stability._OTEL_SEMCONV_STABILITY_SIGNAL_MAPPING)

    def textmap(propagator: TextMapPropagator) -> Callable[[pytest.MonkeyPatch], None]:
        return lambda patch: patch.setattr(propagate, "_HTTP_TEXT_FORMAT", propagator)

    def semconv(mode: _StabilityMode) -> Callable[[pytest.MonkeyPatch], None]:
        def apply(patch: pytest.MonkeyPatch) -> None:
            patch.setattr(_DjangoMiddleware, "_sem_conv_opt_in_mode", _DjangoMiddleware._sem_conv_opt_in_mode)
            patch.setattr(stability, "_initialized", True)
            patch.setattr(
                stability,
                "_OTEL_SEMCONV_STABILITY_SIGNAL_MAPPING",
                {**mapping, _OpenTelemetryStabilitySignalType.HTTP: mode},
            )

        return apply

    cases: dict[str, tuple[str, Callable[[pytest.MonkeyPatch], None]]] = {
        "baggage-only": ("OTEL_PROPAGATORS", textmap(CompositePropagator([W3CBaggagePropagator()]))),
        "no-propagator": ("OTEL_PROPAGATORS", textmap(CompositePropagator([]))),
        "fields-fail": ("OTEL_PROPAGATORS", textmap(_FieldsFail())),
        "semconv-http": ("OTEL_SEMCONV_STABILITY_OPT_IN", semconv(_StabilityMode.HTTP)),
        "semconv-http-dup": ("OTEL_SEMCONV_STABILITY_OPT_IN", semconv(_StabilityMode.HTTP_DUP)),
    }
    for case, (name, apply) in cases.items():
        before = _bsp_threads()
        with pytest.MonkeyPatch.context() as patch:
            apply(patch)
            try:
                configure_otel()
            except ImproperlyConfigured as error:
                outcome: tuple[Any, ...] = (name in str(error), error.__cause__ is None)
            else:
                outcome = ("accepted",)
                DjangoInstrumentor().uninstrument()
        outcomes[case] = (
            outcome,
            DjangoInstrumentor().is_instrumented_by_opentelemetry,
            oc_settings.MIDDLEWARE == list(OC_MIDDLEWARE),
            _bsp_threads() - before,
        )
    assert outcomes == {
        "blank-1": ("instrumented", True),
        "blank-2": ("instrumented", True),
        **dict.fromkeys(cases, ((True, True), False, True, 0)),
    }
    with _otel(InMemorySpanExporter()):
        assert DjangoInstrumentor().is_instrumented_by_opentelemetry is True


# --- 헬스 스레드 시작 실패(D6 〔r3 Z3〕) ------------------------------------------------------------------------------


def test_oc_61_thread_start_failure_fails_only_that_check(
    oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """oc-61 〔r3 Z3 · B-2〕 — 칸 자리를 얻은 뒤 검사 스레드를 만들거나 시작하지 못하면(예외 종류와 무관 — 시작의 RuntimeError ·
    MemoryError · 생성자의 MemoryError · RuntimeError) 그 검사만 곧바로 fail이고 500이 없다: /ready → 503 not_ready · /health → 200 ·
    그 항목만 fail(latency_ms 0.0) · 다른 항목은 자기 칸의 새 스레드로 그대로 판정(대역 probe ok) · 호출 뒤 그 칸 여유가 8로
    돌아온다(자리를 놓는다). 시작한 뒤 예외가 난 경우(작업 스레드는 돈다)도 그 항목은 곧바로 fail이고, 자리는 정확히 한 번 놓인다 —
    작업 스레드의 finally와 실패 경로가 겹쳐 BoundedSemaphore 초과 해제(ValueError)가 나지 않고, 스레드가 끝난 뒤 여유는 8이다.

    〔r5 P4〕 시작한 뒤 예외면 그 작업 스레드가 살아 있는 동안 그 칸 여유는 7이다(시작 실패 경로는 시작되지 않은 스레드의 자리만
    놓고, 시작된 스레드의 자리는 그 finally가 놓는다). 「살아 있는 동안」은 시간 가정 없이 잰다 — 대역 probe 진입을 기다린 뒤(gate
    앞에서 기다린다) 여유를 재고, 잰 뒤에도 그 스레드가 살아 있음을 확인한다.

    〔r5 보강 — 변이 Z3-4x 생존〕 시작했지만 start()의 예외가 새 스레드의 ident 설정보다 먼저 온 경합(대역 _hidden_ident — 그 스레드의
    ident를 None으로 보인다): 시작 실패 경로가 자리를 놓고(P4 한계 — 일찍 놓는다) 작업 스레드의 finally도 놓지만, 1회용 놓기라 두 번
    놓지 않는다 — 그 항목은 곧바로 fail · 초과 해제(ValueError) 0 · 끝난 뒤 여유 8. 살아 있는 동안의 여유는 기록된 한계라 단언하지
    않는다."""
    probes = {name: _FakeProbe() for name in CHECK_NAMES}
    monkeypatch.setattr(health, "_db_probe", probes["db"])
    monkeypatch.setattr(health, "_dragonfly_probe", probes["dragonfly"])
    monkeypatch.setattr(health, "_kafka_probe", probes["kafka_producer"])
    client = Client(raise_request_exception=False)
    failures: tuple[tuple[str, type[Exception]], ...] = (
        ("start", RuntimeError),
        ("start", MemoryError),
        ("init", MemoryError),
        ("init", RuntimeError),
    )
    observed: dict[str, tuple[Any, ...]] = {}
    expected: dict[str, tuple[Any, ...]] = {}
    try:
        for where, error in failures:
            for slot_name, path in (("ready", "/ready"), ("kafka_producer", "/health")):
                _wait_slot_free(slot_name)
                try:
                    with _thread_failure(f"{HEALTH_THREAD}{slot_name}", where, error(f"oc-{where}")) as raised:
                        response = client.get(path)
                    free = _free_capacity(slot_name)
                finally:
                    restored = _restore_slot(slot_name)
                if path == "/ready":
                    problem_type = json.loads(response.content).get("type") if response.content else None
                    shape: tuple[Any, ...] = (response.status_code, response.get("Content-Type"), problem_type)
                    expected_shape: tuple[Any, ...] = (
                        503,
                        "application/problem+json",
                        "https://joshuatech.dev/problems/not-ready",
                    )
                else:
                    checks = json.loads(response.content).get("checks", {}) if response.status_code == 200 else {}
                    shape = (response.status_code, {name: item.get("status") for name, item in checks.items()})
                    shape += (checks.get("kafka_producer", {}).get("latency_ms"),)
                    expected_shape = (200, {"db": "ok", "dragonfly": "ok", "kafka_producer": "fail"}, 0.0)
                key = f"{where}-{error.__name__}-{slot_name}"
                observed[key] = (shape, raised, free, restored)
                expected[key] = (expected_shape, [where], SLOT_LIMIT, 0)
    finally:
        joined = [probe.join() for probe in probes.values()]
    assert observed == expected
    assert all(joined)
    gate = threading.Event()
    held = _FakeProbe(hold_before=gate)
    monkeypatch.setattr(health, "_kafka_probe", held)
    _wait_slot_free("kafka_producer")
    with _thread_errors() as thread_errors:
        try:
            with _thread_failure(f"{HEALTH_THREAD}kafka_producer", "started", RuntimeError("oc-started")) as raised:
                started_checks = _health_checks(client)
            # 〔r5 P4〕 작업 스레드가 probe 안(gate 앞)에 있는 동안 잰다 — 잰 뒤에도 살아 있으면 잴 때도 살아 있었다.
            live_entered = held.wait_calls(1)
            live_free = _free_capacity("kafka_producer")
            live_alive = held.alive()
        finally:
            gate.set()
            started_joined = held.join() and all(probe.join() for probe in probes.values())
    started_free = _free_capacity("kafka_producer")
    restored = _restore_slot("kafka_producer")
    assert started_checks["kafka_producer"] == {"status": "fail", "latency_ms": 0.0}
    assert (raised, held.calls, started_joined) == (["started"], 1, True)
    assert thread_errors == []
    assert (live_entered, live_free, live_alive) == (True, SLOT_LIMIT - 1, 1)
    assert (started_free, restored) == (SLOT_LIMIT, 0)
    # 〔r5 보강 — Z3-4x〕 ident를 못 본 경합 대역 — 두 놓기 경로가 겹쳐도 1회용 놓기라 한 번만 놓는다.
    unseen_gate = threading.Event()
    unseen = _FakeProbe(hold_before=unseen_gate)
    monkeypatch.setattr(health, "_kafka_probe", unseen)
    _wait_slot_free("kafka_producer")
    kafka_thread = f"{HEALTH_THREAD}kafka_producer"
    with _thread_errors() as unseen_errors:
        try:
            with (
                _hidden_ident(kafka_thread),
                _thread_failure(kafka_thread, "started", RuntimeError("oc-unseen")) as unseen_raised,
            ):
                unseen_checks = _health_checks(client)
            unseen_entered = unseen.wait_calls(1)
        finally:
            unseen_gate.set()
            unseen_joined = unseen.join() and all(probe.join() for probe in probes.values())
    unseen_free = _free_capacity("kafka_producer")
    unseen_restored = _restore_slot("kafka_producer")
    assert unseen_checks["kafka_producer"] == {"status": "fail", "latency_ms": 0.0}
    assert (unseen_raised, unseen_entered, unseen.calls, unseen_joined) == (["started"], True, 1, True)
    assert unseen_errors == []
    assert (unseen_free, unseen_restored) == (SLOT_LIMIT, 0)


class _StartAborted(BaseException):
    """Exception이 아닌 BaseException 하위 형(스레드 생성 · 시작 중 KeyboardInterrupt · SystemExit 같은 경우의 대역 · 〔r3 Z3〕)."""


def test_oc_62_base_exception_propagates_and_frees_slot(
    oc_settings: SettingsWrapper, monkeypatch: pytest.MonkeyPatch
) -> None:
    """oc-62 〔r3 Z3〕 — Exception이 아닌 BaseException(하위 형 대역)이 검사 스레드의 생성 · 시작에서 나면 그대로 올라온다(헬스가
    삼키지 않는다 — 시험 Client 밖으로 나온다) · 시작되지 않은 스레드의 칸 자리는 놓여 호출 뒤 여유가 8로 돌아온다.

    〔r5 P4〕 시작한 뒤 BaseException(대역 _StartAborted — oc-61 「started」와 같은 꼴)도 그대로 올라오고, 그 작업 스레드가 살아 있는
    동안 /ready 칸 여유는 7 · 끝난 뒤 8이다(시작된 스레드의 자리는 그 finally가 놓는다 · 초과 해제 0). 「살아 있는 동안」은 대역
    probe가 gate 앞에서 기다리는 동안 잰다(시간 가정 없음)."""
    client = Client(raise_request_exception=False)
    observed: dict[str, tuple[Any, ...]] = {}
    for where in ("init", "start"):
        _wait_slot_free("ready")
        escaped = False
        try:
            with _thread_failure(f"{HEALTH_THREAD}ready", where, _StartAborted(f"oc-{where}")) as raised:
                try:
                    client.get("/ready")
                except _StartAborted:
                    escaped = True
            free = _free_capacity("ready")
        finally:
            restored = _restore_slot("ready")
            structlog.contextvars.clear_contextvars()
        observed[where] = (escaped, raised, free, restored)
    assert observed == {
        "init": (True, ["init"], SLOT_LIMIT, 0),
        "start": (True, ["start"], SLOT_LIMIT, 0),
    }
    # 〔r5 P4〕 시작한 뒤 BaseException — 작업 스레드는 대역 probe 안(gate 앞)에서 기다린다.
    gate = threading.Event()
    held = _FakeProbe(hold_before=gate)
    monkeypatch.setattr(health, "_db_probe", held)
    _wait_slot_free("ready")
    started_escaped = False
    with _thread_errors() as thread_errors:
        try:
            with _thread_failure(f"{HEALTH_THREAD}ready", "started", _StartAborted("oc-started")) as raised:
                try:
                    client.get("/ready")
                except _StartAborted:
                    started_escaped = True
            live_entered = held.wait_calls(1)
            live_free = _free_capacity("ready")
            live_alive = held.alive()
        finally:
            gate.set()
            started_joined = held.join()
            structlog.contextvars.clear_contextvars()
    started_free = _free_capacity("ready")
    restored = _restore_slot("ready")
    assert (started_escaped, raised, held.calls, started_joined) == (True, ["started"], 1, True)
    assert thread_errors == []
    assert (live_entered, live_free, live_alive) == (True, SLOT_LIMIT - 1, 1)
    assert (started_free, restored) == (SLOT_LIMIT, 0)


# --- OTEL_PROPAGATORS 해석 · 굳은 값 판 올림 경로(D5 〔r4 Q1 · Q3〕) -------------------------------------------------


def test_oc_63_propagators_match_otel_parsing(monkeypatch: pytest.MonkeyPatch) -> None:
    """oc-63 〔r4 Q1 · 빌더 r3 ⑧-1〕 — OTEL_PROPAGATORS 해석 규칙은 OTel과 같다(받는 이름은 더 좁다 — 아래 〔r5 P1〕): 후보(oc-15의
    OTEL_PROPAGATORS 값 가운데 감시 값 사례와 PROPAGATORS_NARROWED 밖 — PROPAGATORS_REJECTED · PROPAGATORS_ACCEPTED — 와
    없음)마다 「env 검사(_check_otel_env)가 받는다」 ⇔ 「OTel이 import 때
    쓰는 opentelemetry.propagate._load_propagators()(부를 때 env를 읽는다)가 예외 없이 끝나고 그 fields에 traceparent가 있다」. 받는
    후보와 거부하는 후보가 둘 다 있다(공허한 대조 금지) · 받는 후보는 없음과 PROPAGATORS_ACCEPTED다. 실패 출력에는 후보 원문 대신
    이름표만 싣는다. env는 MonkeyPatch로 둔다(_load_propagators는 새 propagator를 돌려줄 뿐 전역 textmap을 바꾸지 않는다).

    OTel 비공개 함수(_load_propagators)에 기댄다 — 그 함수가 없어지거나 해석이 바뀌면 이 시험이 실패한다. opentelemetry-api 판
    올림 때 OTEL_PROPAGATORS 규칙(계약 「트레이스 · Sentry」 행)을 다시 확인하라는 신호다.

    〔r5 P1 · 빌더 r4 ⑧-1〕 의도된 좁힘: PROPAGATORS_NARROWED(tracecontext,sentry — sentry-sdk가 등록한 entry point)마다 「우리는
    거부한다」와 「_load_propagators()는 예외 없이 끝나고 fields에 traceparent가 있다(OTel은 받는다)」를 함께 단언한다(sentry-sdk가
    그 entry point를 거두면 실패한다 — 계약 문장을 다시 본다). 그 적재는 sentry_sdk.integrations.opentelemetry를 import한다 — 부르기
    전후 전역 textmap · Sentry 전역 상태(scope 셋 · 그 클라이언트 · 전역 이벤트 처리기)가 같음을 단언하고, 바뀌었으면 되돌린 뒤
    되돌림을 단언한다(뒤 시험에 남지 않게)."""
    load = getattr(propagate, "_load_propagators", None)
    assert callable(load), "opentelemetry.propagate._load_propagators가 없다 — 판 올림: OTEL_PROPAGATORS 규칙을 다시 확인한다"
    candidates = (("absent", None), *PROPAGATORS_ACCEPTED, *PROPAGATORS_REJECTED)
    ours: dict[str, bool] = {}
    theirs: dict[str, bool] = {}
    for label, value in candidates:
        if value is None:
            monkeypatch.delenv("OTEL_PROPAGATORS", raising=False)
        else:
            monkeypatch.setenv("OTEL_PROPAGATORS", value)
        try:
            observability._check_otel_env()
        except ImproperlyConfigured:
            ours[label] = False
        else:
            ours[label] = True
        try:
            loaded = load()
        except Exception:  # noqa: BLE001 — OTel import가 낼 예외(모르는 이름 · 빈 토큰 = ValueError)는 받지 않음이다
            theirs[label] = False
        else:
            theirs[label] = "traceparent" in loaded.fields
    monkeypatch.delenv("OTEL_PROPAGATORS", raising=False)
    assert len(ours) == len(theirs) == len(candidates)
    assert sorted(label for label in ours if ours[label] != theirs[label]) == [], sorted(
        label for label in ours if ours[label] != theirs[label]
    )
    accepted = sorted(label for label, ok in ours.items() if ok)
    rejected = sorted(label for label, ok in ours.items() if not ok)
    assert accepted and rejected
    assert accepted == sorted(["absent", *(label for label, _ in PROPAGATORS_ACCEPTED)])
    # 〔r5 P1〕 의도된 좁힘 — 우리는 거부하고 OTel은 받는다. 적재 전후 전역 trace 상태가 같다(바뀌었으면 되돌린 뒤 되돌림을 본다).
    narrowed: dict[str, tuple[Any, ...]] = {}
    for label, value in PROPAGATORS_NARROWED:
        monkeypatch.setenv("OTEL_PROPAGATORS", value)
        try:
            observability._check_otel_env()
        except ImproperlyConfigured:
            ours_narrowed = "rejected"
        else:
            ours_narrowed = "accepted"
        before = _trace_globals()
        try:
            loaded = load()
        except Exception as error:  # noqa: BLE001 — entry point가 없어지면(ValueError) 결과로 접는다
            theirs_narrowed: tuple[Any, ...] = ("raised", type(error).__name__)
        else:
            theirs_narrowed = ("loaded", "traceparent" in loaded.fields)
        finally:
            changed = _restore_trace_globals(before)
        narrowed[label] = (
            ours_narrowed,
            theirs_narrowed,
            changed,
            _changed_trace_globals(before),
            "sentry_sdk.integrations.opentelemetry" in sys.modules,
        )
    monkeypatch.delenv("OTEL_PROPAGATORS", raising=False)
    assert narrowed
    assert narrowed == dict.fromkeys(narrowed, ("rejected", ("loaded", True), [], [], True)), (
        "의도된 좁힘(우리 거부 · OTel 받음) 또는 적재 전후 전역 trace 상태가 어긋났다 — sentry-sdk 판 올림이면 계약 「트레이스 ·"
        " Sentry」 행의 OTEL_PROPAGATORS 문장을 다시 확인한다"
    )


def test_oc_64_propagators_case_and_spaces_at_import() -> None:
    """oc-64 〔r4 Q1 · 빌더 r3 ⑧-1〕 — 운영 경로(env가 OTel import 전에 있다 · 새 프로세스): 대소문자가 다른 토큰(TraceContext — OTel
    import는 그 값을 실은 ValueError로 끝난다)은 configure_otel이 OTel을 import하기 전에 이름만 실은 ImproperlyConfigured로
    끝낸다(ValueError 아님 · 메시지에 값 없음 · 연쇄 없음 · opentelemetry.propagate는 올라오지 않았다). 기본이 아닌 받음 값(앞뒤
    공백 · 순서 바꿈 — " baggage , tracecontext ")은 configure_otel이 성공하고(계측 1) 전역 textmap의 fields에 traceparent ·
    baggage가 있다."""
    cased = (
        "import json, os, sys\n"
        "os.environ['OTEL_PROPAGATORS'] = VALUE\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter\n"
        "    from django_common.observability import configure_otel\n"
        "    try:\n"
        "        configure_otel(span_exporter=InMemorySpanExporter())\n"
        "    except Exception as exc:\n"
        "        message = str(exc)\n"
        "        context = exc.__context__ is not None and not exc.__suppress_context__\n"
        "        result = {\n"
        "            'error': type(exc).__name__,\n"
        "            'named': 'OTEL_PROPAGATORS' in message,\n"
        "            'valued': VALUE in message,\n"
        "            'chained': exc.__cause__ is not None or context,\n"
        "        }\n"
        "    else:\n"
        "        result = {'error': None}\n"
        "    result['propagate_loaded'] = 'opentelemetry.propagate' in sys.modules\n"
        "except Exception as exc:\n"
        "    result = {'failure': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    ).replace("VALUE", repr("TraceContext"))
    spaced = (
        "import json, os\n"
        "os.environ['OTEL_PROPAGATORS'] = VALUE\n"
        "result = {}\n"
        "try:\n"
        "    import django\n"
        "    django.setup()\n"
        "    from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter\n"
        "    from django_common.observability import configure_otel\n"
        "    configure_otel(span_exporter=InMemorySpanExporter())\n"
        "    from opentelemetry import propagate\n"
        "    from opentelemetry.instrumentation.django import DjangoInstrumentor\n"
        "    fields = propagate.get_global_textmap().fields\n"
        "    result = {\n"
        "        'instrumented': DjangoInstrumentor().is_instrumented_by_opentelemetry,\n"
        "        'traceparent': 'traceparent' in fields,\n"
        "        'baggage': 'baggage' in fields,\n"
        "    }\n"
        "except Exception as exc:\n"
        "    result = {'error': type(exc).__name__}\n"
        "print(json.dumps(result))\n"
    ).replace("VALUE", repr(" baggage , tracecontext "))
    observed = {"cased": _run_child(cased), "spaced": _run_child(spaced)}
    assert observed == {
        "cased": {
            "error": "ImproperlyConfigured",
            "named": True,
            "valued": False,
            "chained": False,
            "propagate_loaded": False,
        },
        "spaced": {"instrumented": True, "traceparent": True, "baggage": True},
    }


class _NoDefaultMode:
    """DEFAULT 이름이 없는 _StabilityMode 대역(판 올림으로 그 이름이 바뀌거나 없어진 경우 · 〔r4 Q3〕)."""

    HTTP = _StabilityMode.HTTP


def test_oc_65_frozen_state_helpers_on_version_bump() -> None:
    """oc-65 〔r4 Q3 · 빌더 r3 ⑧-3〕 — 굳은 값 확인 helper를 직접 부른다(configure_otel을 거치면 instrument()가 semconv 속성을 늘
    다시 쓴다): 판 올림으로 모듈 · 속성 · 이름이 없어지면 예외 없이 거부 쪽이다. (c) _semconv_mode_default — 계측 미들웨어 클래스의
    _sem_conv_opt_in_mode를 지움 · DEFAULT가 없는 _StabilityMode 대역 · 둘 다(없는 값끼리 같다고 보지 않는다) · _semconv 모듈 import
    실패 · 계측 미들웨어 모듈 import 실패 → False. (a) _traced_request_attrs_frozen — 계측 미들웨어 모듈 import 실패 → True. 대조:
    바꾸기 전과 되돌린 뒤는 (c) True · (a) False다(지금 상태 — 공허 방지). import 실패는 sys.modules 항목을 None으로 두고, 원복은
    사례마다 MonkeyPatch 문맥이 한다."""
    semconv_name = "opentelemetry.instrumentation._semconv"
    middleware_name = "opentelemetry.instrumentation.django.middleware.otel_middleware"

    def state() -> tuple[Any, Any]:
        return (observability._semconv_mode_default(), observability._traced_request_attrs_frozen())

    def outcome(check: Callable[[], bool]) -> Any:
        try:
            return check()
        except Exception as error:  # noqa: BLE001 — 예외도 결과로 접는다(판 올림 경로는 예외 없이 거부여야 한다)
            return ("raised", type(error).__name__)

    def both_missing(patch: pytest.MonkeyPatch) -> None:
        """속성과 DEFAULT 이름이 함께 없다 — 없는 값끼리(None is None) 기본으로 보지 않는다."""
        patch.delattr(_DjangoMiddleware, "_sem_conv_opt_in_mode")
        patch.setattr(sys.modules[semconv_name], "_StabilityMode", _NoDefaultMode)

    cases: dict[str, tuple[Callable[[pytest.MonkeyPatch], None], Callable[[], bool]]] = {
        "c-attribute-missing": (
            lambda patch: patch.delattr(_DjangoMiddleware, "_sem_conv_opt_in_mode"),
            observability._semconv_mode_default,
        ),
        "c-default-missing": (
            lambda patch: patch.setattr(sys.modules[semconv_name], "_StabilityMode", _NoDefaultMode),
            observability._semconv_mode_default,
        ),
        "c-both-missing": (both_missing, observability._semconv_mode_default),
        "c-semconv-import-fails": (
            lambda patch: patch.setitem(sys.modules, semconv_name, None),
            observability._semconv_mode_default,
        ),
        "c-middleware-import-fails": (
            lambda patch: patch.setitem(sys.modules, middleware_name, None),
            observability._semconv_mode_default,
        ),
        "a-middleware-import-fails": (
            lambda patch: patch.setitem(sys.modules, middleware_name, None),
            observability._traced_request_attrs_frozen,
        ),
    }
    observed: dict[str, Any] = {"before": state()}
    for case, (apply, check) in cases.items():
        with pytest.MonkeyPatch.context() as patch:
            apply(patch)
            observed[case] = outcome(check)
    observed["after"] = state()
    assert observed == {
        "before": (True, False),
        "c-attribute-missing": False,
        "c-default-missing": False,
        "c-both-missing": False,
        "c-semconv-import-fails": False,
        "c-middleware-import-fails": False,
        "a-middleware-import-fails": True,
        "after": (True, False),
    }


def test_oc_66_module_assertions_are_not_rewritten() -> None:
    """oc-66 〔r9 K1〕 — 이 모듈의 시험 함수(이름이 test_로 시작하는 모듈 함수 전부)는 pytest 단언 재작성을 거치지 않았다: 함수의
    __code__.co_varnames에 재작성 임시 변수(@로 시작하는 이름 — 〔r10 I1〕 앞 라운드의 @py_assert 접두를 넓혔다)가 없다. 모듈
    독스트링의 표식 낱말이 빠지면 재작성이 켜져 이 시험이 실패한다(실패 메시지에는 함수 이름과 이름표만 싣는다). -O ·
    PYTHONOPTIMIZE 실행은 모듈 머리의 가드가 수집 단계에서 막는다.

    〔r10 I1〕 파이썬 식별자는 @로 시작할 수 없으니 @ 판정에는 재작성기의 임시 이름만 걸린다 — pytest가 @ 뒤의 임시 이름(지금은
    py_assert · py_format)을 바꿔도 조용히 통과하지 않는다. 모듈 독스트링(__doc__)에 표식 낱말이 있음도 함께 단언한다(표식을 직접
    본다 — 재작성기가 @ 밖의 이름을 쓰게 되어도 표식이 빠지면 잡는다 · bool로 접어 실패 메시지는 이름표뿐이다). 두 절은 따로
    잡는다(r10 변이 I1-1 · I1-2)."""
    functions = {
        name: value for name, value in list(globals().items()) if name.startswith("test_") and inspect.isfunction(value)
    }
    assert test_oc_66_module_assertions_are_not_rewritten in functions.values(), "oc-66 self"
    rewritten = sorted(
        name
        for name, function in functions.items()
        if any(variable.startswith("@") for variable in function.__code__.co_varnames)
    )
    assert rewritten == [], rewritten
    marked = "PYTEST_DONT_REWRITE" in (__doc__ or "")
    assert marked, "oc-66 marker"
