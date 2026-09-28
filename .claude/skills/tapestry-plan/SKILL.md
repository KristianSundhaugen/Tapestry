---
name: tapestry-plan
description: Stage 2 of Tapestry. Dispatch the planner agent to turn an approved spec into plan.md and one self-contained task brief per work item, grouped into waves of file-disjoint tasks; validate; ask the human to approve. Usage /tapestry-plan <feature-id>.
argument-hint: "<feature-id>"
allowed-tools: Read, Edit, Agent, AskUserQuestion, Bash(scripts/*), Bash(cat *), Bash(date *), Bash(git add .tapestry*), Bash(git commit *), Bash(git push)
disable-model-invocation: true
---

Plan feature `$ARGUMENTS`.

## Preconditions

1. Read `.tapestry/features/$ARGUMENTS/spec.md`. It must exist and have `status: approved` (or `pipeline.humanApprovesSpec` is false in `.tapestry/config.json`). Otherwise tell the user to finish `/tapestry-interview $ARGUMENTS` and stop.
2. Read `.tapestry/features/$ARGUMENTS/progress.md`. If `plan.md` already exists with `status: approved`, ask whether to re-plan (this discards existing task files that are still `todo`) or stop.

## Dispatch

Use the **planner** subagent with this prompt:

> Plan Tapestry feature `$ARGUMENTS`. Read the spec, interview, config, knowledge and the code. Write `plan.md` and `tasks/NN-slug.md` using the templates, run `scripts/tapestry-validate.sh $ARGUMENTS`, update the task board in `progress.md`. Report back: task count, waves, biggest risk, added assumptions.

Wait for the result. Do not write the plan yourself.

## Validate and present

1. Run `scripts/tapestry-validate.sh $ARGUMENTS`. If it fails, send the planner the errors and ask it to fix them (at most twice), then stop and show the user.
2. Show the user the *Waves* table from `plan.md` and the planner's report. Ask, with `AskUserQuestion`: approve, request changes (free text), or cancel.
3. On approve: set `status: approved` and `approved_by:` in `plan.md`, set every task's frontmatter to `status: todo`, set `stage: planned` in `progress.md`, append `human  plan-approved  N tasks, M waves`. If `pipeline.humanApprovesPlan` is false, approve automatically and say so.
4. On changes: send the planner the feedback and repeat from step 1.
5. Commit the artifacts on the base branch: `git add .tapestry && git commit -m "chore(tapestry): plan $ARGUMENTS" && git push` (the guard hook allows base-branch commits whose command mentions `tapestry`; only `.tapestry/` files may be in them). If the push is rejected by branch protection, tell the user.
6. Tell the user the next step: `/tapestry-run $ARGUMENTS`, and remind them that it will open one PR per task and, unless `pipeline.humanMergesPRs` is true, merge approved PRs in wave order.
