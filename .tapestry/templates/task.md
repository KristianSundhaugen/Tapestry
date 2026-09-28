---
feature: {{FEATURE_ID}}
task: {{TASK_ID}}
title: {{TITLE}}
wave: 1
depends_on: []
touches: []                    # files/dirs this task may change; nothing else
status: todo                   # todo | in_progress | in_review | approved | merged | blocked
branch:                        # set by the implementer
pr:                            # PR number, set by the implementer
assignee: implementer
---

# Task {{TASK_ID}}: {{TITLE}}

This file is the complete brief for one implementer. It must be self-contained: the implementer does not read the plan or other tasks.

## Goal

One sentence. What exists after this task that did not before.

## Context

Only what this task needs: relevant spec decisions, the shared interfaces it consumes or provides, and any prior-wave results it builds on. Paths, not prose.

## Steps

Ordered, concrete, small. Each step names the file and the change. Prefer "add function X to `src/a.ts` that does Y" over "implement X".

1.
2.
3.

## Acceptance criteria

Maps to spec ACs. Each has a command or check that proves it.

| # | Criterion | Proof |
|---|-----------|-------|
| T1 | | `npm test -- x.spec.ts` passes |

## Tests to write

Which test files and which cases. Write the test first when the behaviour is clear.

## Do not

Things that are tempting but out of scope for this task (they belong to another task or to nobody).

## Done when

- [ ] All acceptance criteria proven, with output pasted in the PR body
- [ ] `commands.test`, `commands.lint`, `commands.typecheck` from `.tapestry/config.json` pass (or are recorded as unavailable)
- [ ] Only files listed in `touches` changed (plus new test files)
- [ ] PR opened against the base branch with the PR template filled
- [ ] Report returned to the orchestrator (task, branch, PR, status, checks, scope, decisions)
