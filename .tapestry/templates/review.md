---
feature: {{FEATURE_ID}}
task: {{TASK_ID}}
pr: {{PR_NUMBER}}
round: 1
verdict: pending          # approve | fixed | changes_requested | blocked
reviewer: reviewer
scanners:                 # e.g. semgrep: 0 findings, gitleaks: clean, or "not installed"
---

# Review: PR #{{PR_NUMBER}} — {{TITLE}} (round 1)

## Summary

One line first: `N blocking, M important, K nits — verdict`. Then two or three sentences on the overall state of the change.

## Findings

Each finding has a severity, a location, a claim with evidence, and what was done about it. Findings without a `file:line` citation are not findings.

### F1 · blocking · `src/x.ts:42`

**Claim**: what is wrong and what input triggers it.
**Evidence**: the code, the test, or the scanner output.
**Action**: `fixed in <commit>` | `patch below, not applied because …` | `needs human: …`

```diff
# patch when not applied
```

## Checks run

| Check | Command | Result |
|-------|---------|--------|
| tests | | pass / fail / n/a |
| lint | | |
| typecheck | | |
| semgrep | | |
| gitleaks | | |
| acceptance criteria | see task file | T1 ✓ T2 ✓ |

## Scope check

Did the PR change only the files in the task's `touches` list (plus tests)? List any extras and whether they are justified.

## Verdict

`approve` — nothing blocking, fixes (if any) applied and green.
`fixed` — reviewer applied fixes; needs the checks re-run by the orchestrator before approve.
`changes_requested` — something the reviewer could not safely fix; implementer must address the listed findings.
`blocked` — needs a human decision (spec conflict, unsafe change, missing access).
