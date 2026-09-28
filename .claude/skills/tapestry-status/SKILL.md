---
name: tapestry-status
description: Show the state of Tapestry features - stage, task board, open PRs and anything blocked. Usage /tapestry-status [feature-id]. Read-only.
argument-hint: "[feature-id]"
allowed-tools: Read, Bash(scripts/tapestry-status.sh*), Bash(gh pr list *)
---

Show Tapestry status.

Run `scripts/tapestry-status.sh $ARGUMENTS` and present its output. With no argument it lists every feature with its stage and task counts; with a feature id it prints the task board, the last ten ledger events and the *Blocked / needs human* section.

Then, if a feature id was given and any task has a PR, run `gh pr list --search "<feature-id>" --state open --json number,title,isDraft,statusCheckRollup` and summarise: which PRs are green, which are drafts (blocked implementers), and which have a review verdict in `reviews/` but are not merged.

End with the single most useful next command (`/tapestry-interview`, `/tapestry-plan`, `/tapestry-run`, `/tapestry-learn`, or "unblock X in progress.md").
