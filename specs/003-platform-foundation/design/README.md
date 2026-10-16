# design/ — task 단위 설계·감사 문서 보존 (003-platform-foundation)

task별 설계 워크플로와 검수에서 나온 **내부 작업 자료**를 보존한다(`.claude/rules/specs.md` §프로젝트 추가물). 게시하지 않으며 task가 닫힌 뒤에는 고치지 않는다. 게시 가능한 증류본은 `content/tmp/003-t<NNN>/`의 학습 로그다(`.claude/rules/content.md` §`content/tmp/`).

| 파일 | task | 내용 |
|---|---|---|
| `t042-audit-report.md` | T042 | cert-manager·와일드카드 인증서 작업의 10렌즈 전체 검수 보고서(컨트롤러 오류 7건 정정 근거) |
| `t043-design.md` | T043 | AOP 강제 설계 — 결정 D1–D6 · 운영자 절차 13단계 · VD 24항목 |
| `t044-design.md` | T044 | Vault 설계 — 결정 D1–D9(§2.10 사용자 확정 기록) · 매니페스트·tofu 정본 · 운영자 절차 0–19 · 위험·VD 표 |
| `build-notes.md` | T031– | 컨트롤러의 task별 진행 노트(리뷰 결과·실측·정정 사실·사고 기록) |

- 보존 시점: 2026-09-17. 원본은 세션 스크래치패드(OS 임시 디렉터리)에 있었고, **`t042-design.md`는 보존 전에 유실**됐다(T042의 결정·실측은 `docs/runbooks/bootstrap.md` §3 T042 절과 `t042-audit-report.md`에 남아 있다). 이 유실이 "설계 문서는 task가 끝나는 시점에 이 디렉터리로 옮긴다"는 규칙의 계기다.
- 사본에서 개인 이메일 주소는 `<operator-email>`·`<access-email>`로 가렸다. 그 밖의 내용은 원문 그대로다.
