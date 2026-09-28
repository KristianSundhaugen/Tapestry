---
name: tapestry-review
description: Run the Tapestry reviewer agent on one pull request. Finds bugs, security issues and best-practice violations, applies safe fixes as commits on the PR branch, writes a report and posts a summary. Works for pipeline PRs and for any other PR in the repo. Usage /tapestry-review <pr-number> [feature-id task-id round].
argument-hint: "<pr-number> [feature-id task-id round]"
allowed-tools: Read, Agent, Bash(gh pr view *), Bash(gh pr list *), Bash(git fetch *), Bash(git worktree *)
disable-model-invocation: true
---

Review pull request `$0` (arguments are zero-indexed: `$0` is the PR number).

1. `gh pr view $0 --json number,title,headRefName,baseRefName,body,isDraft,state`. If the PR is closed or merged, say so and stop. If it is a draft, ask whether to review anyway.
2. Work out the pipeline context: if `$1` is given, use `$1 $2 $3` as feature id, task id and round. Otherwise look for a `Task:` line in the PR body (`<feature-id>/<task-id>`) and count existing `reviews/<task>-r*.md` files to pick the round. If none, this is a standalone PR: reports go to `.tapestry/reviews/pr-$0-r<round>.md`.
3. `git fetch origin && git worktree prune`.
4. Dispatch the **reviewer** subagent:

   > Review PR #$0<, feature <id>, task <NN>, round <r> | standalone, round <r>>. Follow the reviewer procedure in full: check out the PR in your worktree, run deterministic checks and scanners, verify the PR's own proofs, three-pass read (correctness, security, practice), apply safe fixes as `fix(review)` commits and push, write the report from the template, post the summary comment, update the ledger if this is a pipeline PR. Report the summary line, verdict, findings with actions, and check results.

5. Show the user the reviewer's report and the path of the written report file. If the verdict is `changes_requested`, list the unapplied patches and offer to dispatch the implementer to address them. Do not fix anything in this session.
