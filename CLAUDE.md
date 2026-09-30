# Tapestry

This repository uses **Tapestry**, a multi-agent development pipeline for Claude Code. Raw idea → structured interview → executable plan → parallel implementers (one PR each) → automated reviewer that applies fixes → merged code → learnings written back to the repo.

## Start here

- Project profile: `.tapestry/config.json` (stack, commands, base branch, limits). Read it before running any project command.
- Project knowledge: `.tapestry/knowledge/` (architecture, decisions, conventions, gotchas). Read the relevant file before planning or reviewing.
- Feature artifacts: `.tapestry/features/<id>/` (`interview.md`, `spec.md`, `plan.md`, `tasks/`, `progress.md`, `reviews/`). The `progress.md` ledger is the source of truth for pipeline state.
- Pipeline rules: `.claude/rules/tapestry-pipeline.md` and `.claude/rules/git-workflow.md` are always loaded. Project-specific rules learned over time live in `.claude/rules/project/`.

## Commands

| Command | Stage |
|---------|-------|
| `/tapestry-setup` | one-time project onboarding: fills `config.json`, seeds knowledge |
| `/tapestry-new <idea>` | create a feature folder from a raw idea |
| `/tapestry-interview <id>` | structured interview → `interview.md` → `spec.md` |
| `/tapestry-plan <id>` | spec → `plan.md` + `tasks/*.md` (waves of independent tasks) |
| `/tapestry-run <id>` | orchestrate: dispatch implementers per wave, then reviewers, merge, next wave |
| `/tapestry-review <pr>` | run the reviewer agent on one PR (also used by `/tapestry-run`) |
| `/tapestry-learn <id>` | after merge: librarian distils learnings into knowledge + rules |
| `/tapestry-status [id]` | show ledger state |

## Non-negotiables

1. The orchestrator (main session running `/tapestry-run`) never edits project code. It dispatches agents and updates `progress.md`.
2. One task = one worktree = one branch = one PR. Two agents never share a branch.
3. Nothing is "done" without the proof command output in the PR body.
4. Reviewers work from a fresh context and cite `file:line` for every finding.
5. Agents that cannot proceed write to the **Blocked / needs human** section of `progress.md` and stop. They do not guess.
6. On Windows, run `scripts/*.sh` through the Bash tool (Git Bash); the `.ps1` twins are for the human's PowerShell terminal.
7. Small change (roughly under `pipeline.skipPipelineBelowLines` lines, one sentence to describe)? Skip the pipeline, do it directly on a branch, open a PR, run `/tapestry-review`.

## Review calibration

The reviewer agent and Claude Code's built-in `/code-review` both follow the rules in `REVIEW.md`, imported here so a single file is the source of truth:

@REVIEW.md

## Project notes

<!-- /tapestry-setup writes a short project summary below this line. Keep it under 20 lines; details go in .tapestry/knowledge/. -->
