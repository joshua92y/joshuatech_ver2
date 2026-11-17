"""seed_tenant 관리 명령(T073 설계 D19 — pod 소유 새 파일) — SP-1 고정 테넌트 하나와 멤버십 둘(owner · member)을 DB(정본)에
만들고, 그 파생을 Authentik(그룹 소속 · `attributes.tenant_id`)과 OpenFGA(관계 튜플)에 쓴다.

정본: data-model.md §1(시드 · 파생 쓰기 규칙 · 「세부」 T073 보정) · §2 · §10 · contracts/identity-admin-api.md §관리 명령 ·
§identity-admin 전용 설정(쓰기 플래그 · 자리값 자격) · §타임아웃 · 설계 D19 · D18 · D20.

`python manage.py seed_tenant --tenant-id <uuid v7> --owner-sub <sub> --member-sub <sub> [--authentik-token-stdin]` —
운영자가 `kubectl --kubeconfig <관리자 kubeconfig> -n jt-<env> exec deploy/identity-admin -c web -- python manage.py
seed_tenant …`로 돈다(stdin 토큰을 쓸 때는 `exec -i` — `-t` 없음 · 토큰 블록의 정본은 README 「관리 명령」 · runtime 프로필 · app
role — B 등급 표 둘과 런타임 설정이 필요하다 · Job을 두지 않는다). prod를 먼저 돈다(Authentik 쓰기는 쓰기 플래그가 참인 prod
시드만 한다). 고정 테넌트 UUID는 코드에 두지 않는다 — 인자로만 받는다(정본 = data-model §1 「SP-1 고정 테넌트」 줄).

0. 바깥 트랜잭션 안(`connection.in_atomic_block`)이면 아무것도 읽거나 쓰기 전에 CommandError — 4단계의 atomic이 savepoint가 되어
   DB(정본)가 커밋되기 전에 파생을 쓰게 되고, 바깥 블록이 롤백하면 파생만 남는다(revoke_sessions의 가드와 같다). 출력 줄의 `ENV`
   설정도 여기서(읽기 · 쓰기 앞) 읽는다 — 없으면(migrate 프로필 등) CommandError다(revoke_sessions와 같은 설정 · 같은 판정 —
   DB · 파생을 다 쓴 뒤 출력 줄 없이 끝나지 않게).
1. 인자: `--tenant-id` = UUID 8-4-4-4-12 꼴(대소문자 무관 · 중괄호 · `urn:` · hex 32자 꼴은 받지 않는다)이고 v7 → 소문자 정규형 ·
   `--owner-sub` · `--member-sub` = 출력 가능 ASCII(`!`-`~`) 1-255자(`revocation.valid_identifier`)이고 서로 다르며 Authentik 사용자
   uuid의 소문자 정규형(8-4-4-4-12 — data-model §1 「세부」 T073 보정 2026-11-16)이다 — 대문자 · 숫자 pk · username은 5단계
   조회에서 반드시 실패하는데 그 판정은 4단계 DB 커밋 뒤라, 정규화하지 않고 여기서 거부한다(운영자가 붙여 넣은 값을 다시 보게) ·
   `--authentik-token-stdin`이면 표준 입력 한 줄(끝 CR/LF만 뗀다 · 비지 않은 출력 가능 ASCII) — 표준 입력이 터미널(`isatty()` 참 ·
   속성이 없으면 터미널이 아니다)이면 읽기 전에 CommandError(`kubectl exec -it`에서 친 토큰은 화면에 찍힌다) · 이 실행의 Authentik
   호출은 모두 그 토큰을 쓴다(설정의 장기 토큰을 쓰지 않는다). `call_command`는 `stdin=` 키워드로 넘긴다(stealth_options).
2. 자리값 자격(설계 D18): Authentik 토큰(stdin을 주면 그 값) · OPENFGA_STORE_ID · OPENFGA_PRESHARED_KEY 가운데 하나라도
   `conf.PLACEHOLDER_MARK`가 들면 CommandError(요청 0 · DB 0 · 문구에는 설정 이름만). OPENFGA_STORE_ID가 경로 성분 꼴
   (`openfga.STORE_ID_FORM` = 7단계 outbound.build_url의 성분 검사와 같은 `[A-Za-z0-9_-]{1,64}`)이 아니어도 CommandError다(7단계
   검사는 그대로 둔다 — 여기서 미리 보지 않으면 DB · (prod) Authentik을 쓴 뒤 매번 같은 자리에서 멈춘다).
3. 그룹 조회(읽기 · DB 앞 · 쓰기 플래그와 무관): `authentik.find_group("tenant:<uuid>")`(이름 정확 일치 · 첫 쪽)가 정확히 하나이고
   그 pk가 UUID 꼴이며 `is_superuser`가 False여야 한다(키 없음 · None · True는 거부 — 닫힌 쪽 · 소속을 쓰면 두 사용자가 Authentik
   관리자가 된다) — 아니면 CommandError이고 그룹을 만들지 않으며 DB를 쓰지 않는다(오타 난 v7 `--tenant-id`가 slug `joshuatech`
   행을 남겨 올바른 재실행을 slug 충돌로 막지 않게 · 빈 결과는 「없다」와 「필터가 무시돼 뒤 쪽에 있다」를 가르지 않으므로 문구는
   「찾지 못했다」다).
4. DB(atomic 하나 · app role · ORM `objects.create`): Tenant가 그 id로 있으면 slug가 `joshuatech`이어야 한다(display_name · status는
   건드리지 않는다) · 없으면 slug가 다른 id로 있는지 먼저 보고(있으면 CommandError — 새 행을 만들지 않는다) 만든다(slug
   `joshuatech` · display_name `JoshuaTech` · status는 모델 기본값 active). 멤버십 둘은 없으면 만들고, 있는데 role이 인자와 다르면
   CommandError(atomic이 롤백 — 그 실행의 DB 쓰기 0 · SP-1에는 role을 바꾸는 경로가 없고, 내리면 OpenFGA에 옛 관계가 남는다).
   경합 IntegrityError는 문구 없는 CommandError다(제약 DETAIL의 행 값을 싣지 않는다).
5. 사용자 조회(읽기 · 쓰기 플래그와 무관): sub마다 `authentik.find_user(sub)`(uuid 정확 일치 · 첫 쪽)가 정확히 하나이고 pk는 정수 pk
   꼴(`authentik.valid_pk`) · `attributes`는 사전 · `groups`는 목록이어야 한다 — 아니면 CommandError(DB 행은 남는다).
6. Authentik 판정과 쓰기: 사용자마다 소속(`groups`에 그룹 pk가 있는가) · attribute(`attributes.tenant_id`가 이 테넌트인가).
   `tenant_id` 키가 다른 값으로 있으면(빈 값 · null 포함) 쓰기 플래그와 무관하게, 두 사용자를 다 본 뒤 아무것도 쓰기 전에
   CommandError다(사용자를 조용히 다른 테넌트로 옮기지 않는다). 플래그 참: 소속이 없을 때만 `authentik.add_user` · `tenant_id` 키가
   없을 때만 「5단계에서 읽은 attributes + tenant_id」 전체를 `authentik.patch_attributes`(PATCH는 attributes를 통째로 바꾼다 — 다른
   키를 지우지 않게) → 하나라도 썼으면 `written` · 아니면 `unchanged`. 두 메서드가 False(pk 꼴 아님 · 호출 0)를 돌려주면
   CommandError다. 플래그 거짓: 쓰지 않고 어긋난 항목 수(사용자 둘 × 항목 둘 = 0-4)를 `skipped(drift=<n>)`로 싣는다(3 · 5단계에서
   읽은 값으로 견준다 — 추가 호출 없음). 조회와 PATCH 사이에 Authentik에서 바뀐 그 사용자의 attributes는 덮인다(PATCH는 사전
   전체를 보낸다 — 인정된 한계 · 시드 중에는 그 사용자를 고치지 않는다).
7. OpenFGA(dev도 쓴다): `openfga.write_tuples([(user:<owner>, owner, tenant:<uuid>), (user:<member>, member,
   tenant:<uuid>)])` 한 번(`on_duplicate: "ignore"`) — 판정은 쓰기 응답으로만 한다(2xx가 아니면 상태 코드만 담은 CommandError).
8. stdout에 `seed_tenant:`로 시작하는 줄 하나: `seed_tenant: OK env=<env> tenant=<uuid> memberships=created:<n>/unchanged:<n>
   authentik=written|unchanged|skipped(drift=<n>) fga=ok` — `env`는 0단계에서 읽은 `ENV` 설정(revoke_sessions와 같은 설정 · 같은
   자리 — 머리말 바로 뒤) · sub · 토큰 · URL을 싣지 않는다(실제 실행에서는 같은 stdout에 구조 로그 JSON 줄이 섞인다 — 읽는 쪽은
   접두로 찾는다). 실패하면 이 줄이 없다.
파생(5-7단계)이 실패해도 4단계의 DB 행은 남는다. 문구 꼬리가 갈래를 말한다(값 없음): 일시 오류(outbound `.transient` — 429 · 5xx ·
연결 · 시간 초과 · 마감)로 멈췄으면 「DB 행은 남았다 · 다시 실행하면 마저 쓴다」(재실행이 멱등하게 마저 쓴다) · 그 밖(사용자를 찾지
못함 · 여럿 · 응답 꼴 밖 · 일시 아닌 HTTP 상태 · attribute 충돌 · 쓰기 메서드 False · OpenFGA 4xx · invalid_request)이면 「DB 행은
남았다 · 인자 · 상태를 고친 뒤 다시 실행한다(틀린 인자로 남은 행 · 파생은 런북 T114로 지운다)」 — 같은 인자로 다시 돌아도 같은
자리에서 멈추고, 이 명령은 행 · 파생을 지우지 않는다. 이벤트 발행 · platform-admin 그룹 · Job은 없다. Authentik · OpenFGA 호출은
재시도가 없다(호출마다 소켓 동작 5 s — outbound). CommandError 문구에는 값(sub · 토큰 · URL · store id · DB DETAIL · 예외 문구)을
싣지 않는다 — HTTP 실패는 상태 코드나 종류만이고 except 블록 밖에서 `from None`으로 올린다(문구는 cp949로 쓸 수 있는 글자만 —
Windows 콘솔). 종료 코드: 0 = OK · 1 = CommandError(어느 단계든) · 2 = 인자 사용법 오류.
"""

from __future__ import annotations

import re
import sys
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError, CommandParser
from django.db import IntegrityError, connection, transaction

from identity_admin import authentik, conf, openfga, outbound, revocation
from identity_admin.models import Tenant, TenantMembership

PREFIX = "seed_tenant:"
SLUG = "joshuatech"  # data-model §1 시드 — slug · display_name은 상수다
DISPLAY_NAME = "JoshuaTech"
OWNER, MEMBER = "owner", "member"
TENANT_ID_VERSION = 7
ATTRIBUTE = "tenant_id"  # Authentik user.attributes 키(ScopeMapping tenant_id의 원천 — data-model §9)
_UUID_FORM = re.compile(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}")
# sub = Authentik 사용자 uuid의 소문자 정규형(fullmatch — data-model §1 「세부」 · §9 user_uuid sub 모드)
_SUB_FORM = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}")
_TOKEN_FORM = re.compile(r"[!-~]+")  # stdin 토큰(fullmatch — conf의 비밀 글자 규칙 · outbound 헤더 규칙과 같다)
# 실패 문구의 꼬리(값 없음) — 3단계(DB 앞) · 4단계 뒤 파생(5-7단계)의 일시 오류 · 그 밖
_NO_DB = " - DB는 쓰지 않았다"
_RETRY = " - DB 행은 남았다 · 다시 실행하면 마저 쓴다"
_FIX = " - DB 행은 남았다 · 인자 · 상태를 고친 뒤 다시 실행한다(틀린 인자로 남은 행 · 파생은 런북 T114로 지운다)"
# _upstream의 꼬리 쌍(일시 오류일 때, 그 밖) — 3단계는 일시 여부와 무관하고, 파생은 일시 오류만 재실행이 마저 쓴다
_BEFORE_DB = (_NO_DB, _NO_DB)
_DERIVED = (_RETRY, _FIX)


@dataclass(frozen=True)
class _User:
    """5단계에서 읽은 Authentik 사용자 — 역할 이름 · pk · attributes(사전) · groups(그룹 pk 목록)."""

    role: str
    pk: int
    attributes: dict[str, Any]
    groups: list[Any]


def _reason(error: outbound.UpstreamError | None) -> str:
    """HTTP 실패의 값 없는 사유 — 상태 코드나 종류만."""
    if isinstance(error, outbound.UpstreamStatus):
        return f"status={error.status}"
    if isinstance(error, outbound.UpstreamUnavailable):
        return f"error={error.kind}"
    return "error=unknown"


def _upstream[T](what: str, tails: tuple[str, str], fn: Callable[..., T], *args: Any, **kwargs: Any) -> T:
    """Authentik · OpenFGA 호출 한 번 — outbound 오류 형은 상태 · 종류만 담은 CommandError로 바꾼다(except 블록 밖 `from None`).
    문구 꼬리는 tails = (일시 오류일 때, 그 밖)에서 오류의 `.transient`(outbound — 429 · 5xx · 연결 · 시간 초과 · 마감)로 고른다."""
    failure: outbound.UpstreamError | None = None
    try:
        return fn(*args, **kwargs)
    except outbound.UpstreamError as exc:
        failure = exc
    tail = tails[0] if failure is not None and failure.transient else tails[1]
    raise CommandError(f"{what} 실패({_reason(failure)}){tail}") from None


def _tenant_id(raw: object) -> uuid.UUID:
    """1 — `--tenant-id`: UUID 8-4-4-4-12 꼴 · v7(RFC 9562 변형) → UUID(소문자 정규형은 str())."""
    if not isinstance(raw, str) or _UUID_FORM.fullmatch(raw) is None:
        raise CommandError("--tenant-id는 UUID(8-4-4-4-12 꼴)여야 한다")
    parsed = uuid.UUID(raw)
    if parsed.version != TENANT_ID_VERSION:  # 변형이 RFC 4122/9562가 아니면 version은 None이다
        raise CommandError("--tenant-id는 UUID v7이어야 한다(SP-1 고정 테넌트 UUID - data-model §1)")
    return parsed


def _subs(owner: object, member: object) -> tuple[str, str]:
    """1 — `--owner-sub` · `--member-sub`: 출력 가능 ASCII 1-255자 · 서로 다르다 · Authentik 사용자 uuid의 소문자 정규형이다
    (정규화하지 않고 거부한다 — 운영자가 무엇을 붙여 넣었는지 다시 보게 · 5단계 조회에서 반드시 실패할 sub가 4단계의 DB 행을
    남기지 않게)."""
    if not revocation.valid_identifier(owner) or not revocation.valid_identifier(member):
        raise CommandError("--owner-sub · --member-sub는 출력 가능 ASCII(!-~) 1-255자여야 한다")
    if owner == member:
        raise CommandError("--owner-sub와 --member-sub가 같다 - owner · member는 서로 다른 사용자다")
    owner_sub, member_sub = str(owner), str(member)  # valid_identifier는 str만 받는다(값 그대로)
    if _SUB_FORM.fullmatch(owner_sub) is None or _SUB_FORM.fullmatch(member_sub) is None:
        raise CommandError("--owner-sub · --member-sub는 Authentik 사용자 uuid(소문자 8-4-4-4-12)여야 한다")
    return owner_sub, member_sub


def _stdin_token(stream: Any) -> str:
    """1 — `--authentik-token-stdin`: 터미널이 아닌 stream의 한 줄(끝 CR/LF만 뗀다) · 비지 않은 출력 가능 ASCII. 터미널 판정
    (`isatty()` — 속성이 없으면 터미널이 아니다)은 읽기 앞이다(터미널에서 읽으면 친 토큰이 화면 · 터미널 기록에 남는다)."""
    unreadable = terminal = False
    line: object = None
    try:
        isatty = getattr(stream, "isatty", None)
        terminal = bool(isatty()) if callable(isatty) else False
        if not terminal:
            line = stream.readline()
    except (OSError, ValueError):  # 닫힌 · 읽을 수 없는 stdin(isatty도) · 디코드 실패(UnicodeDecodeError — 문구에 바이트가 실린다)
        unreadable = True
    if terminal:
        raise CommandError("표준 입력이 터미널이다 - 토큰은 파이프로 넣는다(README 꼴)")
    if unreadable or not isinstance(line, str):
        raise CommandError("표준 입력에서 Authentik 토큰을 읽지 못했다")
    token = line.rstrip("\r\n")
    if _TOKEN_FORM.fullmatch(token) is None:
        raise CommandError("표준 입력의 Authentik 토큰은 비지 않은 출력 가능 ASCII(!-~) 한 줄이어야 한다")
    return token


def _refuse_placeholders(stdin_token: str | None) -> None:
    """2 — 자리값 자격(설계 D18): 어느 하나라도 PLACEHOLDER_MARK가 들면 CommandError(설정 이름만 싣는다). stdin 토큰을 주면
    Authentik 쪽은 그 값으로 판정한다(설정 토큰은 이 실행에서 쓰지 않는다)."""
    if stdin_token is None:
        authentik_credential = ("AUTHENTIK_API_TOKEN", settings.AUTHENTIK_API_TOKEN)
    else:
        authentik_credential = ("--authentik-token-stdin", stdin_token)
    credentials = (
        authentik_credential,
        ("OPENFGA_STORE_ID", settings.OPENFGA_STORE_ID),
        ("OPENFGA_PRESHARED_KEY", settings.OPENFGA_PRESHARED_KEY),
    )
    placeholders = [name for name, value in credentials if conf.PLACEHOLDER_MARK in str(value)]
    if placeholders:
        raise CommandError(f"자리값 자격이다({' · '.join(placeholders)}) - 실값을 넣은 뒤 다시 실행한다")


def _refuse_store_id() -> None:
    """2 — OPENFGA_STORE_ID가 경로 성분 꼴(openfga.STORE_ID_FORM — 7단계 outbound.build_url의 성분 검사와 같은 꼴)이 아니면
    CommandError(설정 이름만 싣는다) — 7단계에서야 거부되면 DB · (prod) Authentik을 쓴 뒤 매번 같은 자리에서 멈춘다."""
    store_id = settings.OPENFGA_STORE_ID
    if not isinstance(store_id, str) or openfga.STORE_ID_FORM.fullmatch(store_id) is None:
        raise CommandError("OPENFGA_STORE_ID가 꼴([A-Za-z0-9_-]{1,64})이 아니다 - 설정을 고친 뒤 다시 실행한다")


def _group_pk(tenant: str, token: str | None) -> str:
    """3 — 그룹 `tenant:<uuid>`의 pk(이름 정확 일치가 정확히 하나 · pk UUID 꼴 · `is_superuser`가 False) · 아니면
    CommandError(DB를 쓰기 전이다)."""
    found = _upstream("Authentik 그룹 조회", _BEFORE_DB, authentik.find_group, f"tenant:{tenant}", token=token)
    if not found:
        raise CommandError(
            "Authentik 그룹 tenant:<--tenant-id>를 찾지 못했다(이름 정확 일치 · 첫 쪽) - 그룹 껍데기는 blueprint가 만든다 · "
            f"만들지 않는다{_NO_DB}"
        )
    if len(found) > 1:
        raise CommandError(f"이름이 tenant:<--tenant-id>인 Authentik 그룹이 여럿이다{_NO_DB}")
    pk = found[0].get("pk")
    if not authentik.valid_uuid(pk):
        raise CommandError(f"Authentik 그룹 조회 응답의 pk가 UUID 꼴이 아니다{_NO_DB}")
    if found[0].get("is_superuser") is not False:  # 키 없음 · None · True 모두 거부(닫힌 쪽 — 소속을 쓰면 관리자가 된다)
        raise CommandError(
            "Authentik 그룹 tenant:<--tenant-id>가 superuser 그룹이거나 응답에 is_superuser가 없다 - 쓰지 않는다 · "
            "DB는 쓰지 않았다"
        )
    return str(pk)  # valid_uuid는 str만 받는다(값 그대로)


def _seed_rows(tenant_id: uuid.UUID, owner: str, member: str) -> tuple[int, int]:
    """4 — Tenant · 멤버십 둘(atomic 하나) → (created, unchanged). 실패는 CommandError(그 실행의 DB 쓰기 0)."""
    created = unchanged = 0
    conflicted = False
    try:
        with transaction.atomic():
            tenant = Tenant.objects.filter(pk=tenant_id).first()
            if tenant is None:
                if Tenant.objects.filter(slug=SLUG).exists():
                    raise CommandError("slug joshuatech가 다른 테넌트 id로 이미 있다 - 새 행을 만들지 않는다")
                Tenant.objects.create(id=tenant_id, slug=SLUG, display_name=DISPLAY_NAME)
            elif tenant.slug != SLUG:
                raise CommandError("그 --tenant-id의 Tenant slug가 joshuatech가 아니다 - 바꾸지 않는다")
            for sub, role in ((owner, OWNER), (member, MEMBER)):
                current = TenantMembership.objects.filter(tenant_id=tenant_id, sub=sub).values_list("role", flat=True)
                existing = current.first()
                if existing is None:
                    TenantMembership.objects.create(tenant_id=tenant_id, sub=sub, role=role)
                    created += 1
                elif existing != role:
                    raise CommandError(
                        f"--{role}-sub의 기존 멤버십 role이 인자와 다르다 - 바꾸지 않는다(SP-1에는 role 변경 경로가 없다) · "
                        "이 실행의 DB 쓰기는 0이다"
                    )
                else:
                    unchanged += 1
    except IntegrityError:  # 동시 실행의 경합(tenant pk · slug · (sub, tenant_id) 유일) — DETAIL에 행 값이 실린다
        conflicted = True
    if conflicted:
        raise CommandError("DB 무결성 충돌(동시 실행 등) - 이 실행의 DB 쓰기는 0이다 · 다시 실행한다") from None
    return created, unchanged


def _user(role: str, sub: str, token: str | None) -> _User:
    """5 — sub의 Authentik 사용자(uuid 정확 일치가 정확히 하나 · pk 정수 pk 꼴 · attributes 사전 · groups 목록)."""
    found = _upstream(f"Authentik {role} 사용자 조회", _DERIVED, authentik.find_user, sub, token=token)
    if not found:
        raise CommandError(f"Authentik {role} 사용자(uuid = sub)를 찾지 못했다(uuid 정확 일치 · 첫 쪽){_FIX}")
    if len(found) > 1:
        raise CommandError(f"uuid가 같은 Authentik {role} 사용자가 여럿이다{_FIX}")
    pk, attributes, groups = found[0].get("pk"), found[0].get("attributes"), found[0].get("groups")
    if not authentik.valid_pk(pk) or not isinstance(attributes, dict) or not isinstance(groups, list):
        raise CommandError(f"Authentik {role} 사용자 응답의 꼴이 계약 밖이다(pk · attributes · groups){_FIX}")
    return _User(role=role, pk=int(pk), attributes=attributes, groups=groups)  # valid_pk는 int만 받는다(값 그대로)


def _sync_authentik(group_pk: str, tenant: str, users: list[_User], token: str | None) -> str:
    """6 — 소속 · attribute 판정과 쓰기 → `written` · `unchanged` · `skipped(drift=<n>)`."""
    conflicts = [user.role for user in users if ATTRIBUTE in user.attributes and user.attributes[ATTRIBUTE] != tenant]
    if conflicts:  # 쓰기 플래그와 무관 · 아무것도 쓰기 전
        raise CommandError(
            f"Authentik {' · '.join(conflicts)} 사용자의 attributes.tenant_id가 이 테넌트가 아니다 - 쓰지 않는다(사용자를 "
            f"조용히 다른 테넌트로 옮기지 않는다){_FIX}"
        )
    # 사용자마다 (사용자, 소속이 없다, tenant_id 키가 없다) — drift = 어긋난 항목 수(사용자 둘 × 항목 둘 = 0-4)
    plan = [(user, group_pk not in user.groups, ATTRIBUTE not in user.attributes) for user in users]
    drift = sum(int(needs_group) + int(needs_attribute) for _, needs_group, needs_attribute in plan)
    if not settings.AUTHENTIK_WRITES_ENABLED:  # 호출 때의 설정 — 쓰지 않고 어긋난 항목 수만
        return f"skipped(drift={drift})"
    for user, needs_group, needs_attribute in plan:
        if needs_group:
            added = _upstream(
                f"Authentik {user.role} 소속 쓰기", _DERIVED, authentik.add_user, group_pk, user.pk, token=token
            )
            if not added:
                raise CommandError(f"Authentik {user.role} 소속 쓰기를 보내지 못했다(그룹 · 사용자 pk 꼴){_FIX}")
        if needs_attribute:
            merged = {**user.attributes, ATTRIBUTE: tenant}
            patched = _upstream(
                f"Authentik {user.role} attribute 쓰기",
                _DERIVED,
                authentik.patch_attributes,
                user.pk,
                merged,
                token=token,
            )
            if not patched:
                raise CommandError(f"Authentik {user.role} attribute 쓰기를 보내지 못했다(사용자 pk 꼴){_FIX}")
    return "written" if drift else "unchanged"


class Command(BaseCommand):
    help = (
        "SP-1 고정 테넌트 시드(--tenant-id · --owner-sub · --member-sub) - 그룹 조회 · DB(Tenant · 멤버십 둘) · Authentik 소속 · "
        "attribute · OpenFGA 튜플. 출력 한 줄."
    )
    stealth_options = ("stdin",)

    def add_arguments(self, parser: CommandParser) -> None:
        parser.add_argument("--tenant-id", required=True, help="고정 테넌트 UUID(v7 · 8-4-4-4-12 꼴).")
        parser.add_argument("--owner-sub", required=True, help="owner 사용자 sub(Authentik 사용자 uuid · 소문자 8-4-4-4-12).")
        parser.add_argument(
            "--member-sub", required=True, help="member 사용자 sub(owner와 다르다 · Authentik 사용자 uuid · 소문자 8-4-4-4-12)."
        )
        parser.add_argument(
            "--authentik-token-stdin",
            action="store_true",
            help="Authentik 호출에 설정의 토큰 대신 표준 입력 한 줄의 토큰을 쓴다(터미널이 아닌 파이프 - exec -i).",
        )

    def handle(self, *args: Any, **options: Any) -> None:
        if connection.in_atomic_block:  # 0 — 읽기 · 쓰기 앞
            raise CommandError("바깥 트랜잭션 안에서는 돌 수 없다 - DB(정본)가 커밋되기 전에 파생을 쓰게 된다")
        env = getattr(settings, "ENV", None)  # 0 — 출력 줄의 env(호출 시점의 설정 · revoke_sessions와 같다) · 읽기 · 쓰기 앞
        if not env:
            raise CommandError("ENV 설정이 없다 - runtime 프로필(web 컨테이너)에서 돌린다")
        tenant_id = _tenant_id(options["tenant_id"])  # 1
        owner, member = _subs(options["owner_sub"], options["member_sub"])
        token = _stdin_token(options.get("stdin") or sys.stdin) if options["authentik_token_stdin"] else None
        _refuse_placeholders(token)  # 2
        _refuse_store_id()
        tenant = str(tenant_id)
        group_pk = _group_pk(tenant, token)  # 3
        created, unchanged = _seed_rows(tenant_id, owner, member)  # 4
        users = [_user(OWNER, owner, token), _user(MEMBER, member, token)]  # 5
        state = _sync_authentik(group_pk, tenant, users, token)  # 6
        target = f"tenant:{tenant}"  # 7
        tuple_keys = [(f"user:{owner}", OWNER, target), (f"user:{member}", MEMBER, target)]
        _upstream("OpenFGA 쓰기", _DERIVED, openfga.write_tuples, tuple_keys)
        self.stdout.write(  # 8
            f"{PREFIX} OK env={env} tenant={tenant} memberships=created:{created}/unchanged:{unchanged} "
            f"authentik={state} fga=ok"
        )
