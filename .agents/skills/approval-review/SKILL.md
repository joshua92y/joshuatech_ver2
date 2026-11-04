---
name: approval-review
description: Review an active feature's spec, plan, and tasks with parallel boundary agents before a human approves implementation.
---

# Approval review

Gate implementation on a recorded, multi-boundary review and an explicit human decision.

## Safety invariants

- Treat an Approved or Done `spec.md`, its `plan.md`, and its `tasks.md` as immutable. If the active feature is already Approved or Done, stop without editing those files.
- A Draft spec may change only once in this workflow: after the human explicitly chooses approval, change its Status to Approved. Never edit `plan.md` or `tasks.md` here.
- Do not implement anything from this skill.
- Review agents are read-only. Give them only the required excerpts, never whole feature artifacts.

## 1. Resolve the active feature

Resolve candidates in this order: `SPECIFY_FEATURE_DIRECTORY`, the current git branch when it maps to an existing `specs/<branch>/` directory, then `.specify/feature.json`. Treat the JSON file as a consistency check when an environment or branch candidate exists. If no authoritative candidate resolves, or resolved candidates disagree, ask the user for the feature directory and stop until they answer.

Every candidate from the environment, branch, or `.specify/feature.json` must canonicalize to an immediate child of `<git-root>/specs/`, have a basename matching `^\d{3,}-[a-z0-9-]+$`, and traverse no existing reparse point or link. Reject any outside, nested, invalidly named, or linked candidate before comparing sources or reading feature artifacts.

Read `spec.md`, `plan.md`, `tasks.md`, and any `checklists/*.md`. If `plan.md` or `tasks.md` is missing, stop and name the required `$speckit-plan` or `$speckit-tasks` step. Require the spec Status to be Draft.

## 2. Gather machine inputs

Resolve `$speckit-analyze` directly to `.agents/skills/speckit-analyze/SKILL.md`, read that file completely, and execute its full read-only workflow as a nested step in this same turn. Explicit-only Spec Kit skills are not guaranteed to appear in the implicit skill catalog, so do not depend on catalog listing. Bind no child arguments unless the triggering user message explicitly supplied them; a literal `$ARGUMENTS` token in a managed skill is a placeholder, never user input. Do not merely recommend the nested skill or defer it to another turn.

Keep the complete analysis report for the spec-consistency reviewer. Count unchecked `- [ ]` items in `checklists/*.md` separately.

## 3. Dispatch boundary reviewers

Use these rubrics from `boundaries/`: `security.md`, `tenant-data.md`, `operability.md`, `trends.md`, `spec-consistency.md`, and, only for a feature declaring Kubernetes, GitOps, or infrastructure resources, `k8s-security.md`.

Prepare one bounded prompt per applicable rubric containing:

- the full rubric;
- the feature name;
- excerpts from `spec.md`: User Scenarios & Testing, Requirements, and Key Entities;
- excerpts from `plan.md`: Summary, Technical Context, Constitution Check, Project Structure, and Complexity Tracking;
- phase headings and task lines from `tasks.md`;
- Core Principles from the constitution;
- for spec consistency only, the nested analysis report and unchecked-checklist count;
- for Kubernetes security only, contract excerpts about hostnames, access policies, GitOps layout, and secret paths.

Tell every reviewer to make no file changes and to return only its rubric's output format. Only the trends reviewer may browse the web; it must cite primary or official URLs. Tell every other reviewer not to use network tools.

Call `spawn_agent` once per reviewer with `fork_turns: "none"` and a unique lowercase snake-case task name. Start every reviewer before making any wait call. After all spawns succeed, use `wait_agent` until every reviewer has returned. If a reviewer fails, retry that boundary once with a fresh unique task name; if it still fails, stop rather than inventing a result.

## 4. Record the review

Write `specs/<feature>/reviews/YYYY-MM-DD-approval.md` with this structure:

```markdown
# Approval review — <feature> (YYYY-MM-DD)
Inputs: spec.md (Status: Draft), plan.md, tasks.md, checklists: <n> unchecked, $speckit-analyze: <finding count>

## Security
| 항목 | 상태 | 비고 |
|---|---|---|
### Findings

## Tenant & data boundary
...
## Operability
...
## Trends
| 기술 | 현재 plan | 최신 동향 | 제안 | 출처 |
|---|---|---|---|---|
### Findings

## Spec consistency
...

## K8s security
...

## 종합 의견
**판정**: 승인 권고 | 수정 후 승인 권고 | 재설계 권고
- 근거
- 수정 필요 항목

## 사용자 결정
- [ ] 승인 (YYYY-MM-DD)
```

Use `✅ 충족`, `⚠️ 보완`, `❌ 위반`, or `— 해당 없음` in status cells. Keep the K8s section and mark it not applicable when that reviewer was skipped. Derive the overall judgment from the returned findings; never suppress a high-severity issue.

## 5. Obtain the human decision

Show the overall judgment and numbered fixes. If `request_user_input` is available, ask one question with the choices 승인, 수정 후 재검토, and 재설계. Otherwise ask the same concise question in the normal response and stop. Do not infer a choice from earlier approval wording; only the answer to this post-review question authorizes the status transition.

- On 승인: tick the review checkbox with today's date, change the Draft spec Status to `Approved (YYYY-MM-DD)`, regenerate `specs/README.md`, and commit `docs(<feature>): approval 리뷰 및 Status Approved`.
- On 수정 후 재검토: list the required corrections and route them through `$speckit-clarify`, `$speckit-plan`, or `$speckit-tasks` as appropriate, then rerun this review. Do not edit an artifact after it becomes Approved.
- On 재설계: stop and leave the next action to the user.

Never mark a spec Approved without the explicit post-review answer, and never begin implementation from this workflow.
