# Boundary: Report vs diff

## Purpose
`report.md` must describe exactly what changed.

## Inputs
`report.md`; output of `git diff --stat $(git merge-base main HEAD)...HEAD`; output of `git log --oneline $(git merge-base main HEAD)..HEAD`.

## Checklist
- Every file in the diff stat appears under Changes Made; nothing is claimed that is absent from the diff.
- Validation claims (commands, counts) match what was actually run; unrun checks are listed as such.
- Next lists every unchecked converge item and every deferred task.
- Commits follow Conventional Commits.

## Output format
`Verdict: ✅ | ❌` then a bullet list of mismatches (file or claim, what is wrong).
