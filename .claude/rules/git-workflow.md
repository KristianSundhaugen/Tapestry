# Git workflow

Always loaded. Values in angle brackets come from `.tapestry/config.json`.

## Branches

- Base branch: `<project.baseBranch>` (default `main`). Protected: never commit to it, never force-push it.
- Task branches: `<git.branchPrefix>/<feature-id>/<task-id>-<slug>`, e.g. `tapestry/001-short-links/02-create-endpoint`.
- Quick fixes outside the pipeline: `<git.branchPrefix>/quick/<slug>`.
- One branch per task. A branch is created from the base branch (or from the worktree Claude Code created for the agent) and deleted after merge.

## Commits

Conventional Commits, imperative mood, under 72 characters in the subject:

```
<type>(<scope>): <subject>

<body: what and why, not how. Wrap at 72.>

Task: <feature-id>/<task-id>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`, `build`, `ci`. Scope is the module or area, optional. Review fixes use `fix(review): …`. Learnings use `docs(knowledge): …`.

Commit when a coherent step is green, not at the end. A commit that contains five steps is archaeology.

## Pull requests

- Title = commit subject style: `feat(links): add POST /links endpoint`.
- Body from `.tapestry/templates/pr-body.md`, fully filled. The acceptance-criteria table must contain real command output.
- Target the base branch. Draft while checks are red; ready-for-review when green.
- Labels if the repo has them: `tapestry`, `wave-<n>`.
- Merge strategy `<pipeline.mergeStrategy>` (default squash). Delete branch on merge.

## Before opening or updating a PR

```bash
git fetch origin
git rebase origin/<baseBranch>          # keep history linear; resolve conflicts, rerun checks
<commands.lint>; <commands.typecheck>; <commands.test>
git push -u origin HEAD                 # first push
git push --force-with-lease             # after a rebase, never plain --force
gh pr create --base <baseBranch> --title "…" --body-file /tmp/pr-body.md
```

## Worktrees

Implementers and reviewers run in Claude Code worktrees (`.claude/worktrees/<name>`), so parallel agents never touch the same checkout. Rules:

- When an agent finishes and has pushed, it runs `git switch --detach` so its branch is free for the reviewer to check out elsewhere.
- Never `cd` out of your worktree to edit the main checkout.
- The orchestrator runs `git worktree prune` between waves and `git pull --ff-only` after every merge, so the next wave's worktrees start from the merged base.

## Merging (orchestrator only)

```bash
gh pr checks <n> --watch            # wait for CI
gh pr merge <n> --squash --delete-branch
```

Merge in wave order. After each merge, `git pull --ff-only origin <baseBranch>` so the next wave's worktrees branch from the merged base.

## Ledger commits (orchestrator, interviewer, planner)

The only commits made directly on the base branch: `git add .tapestry && git commit -m "chore(tapestry): …" && git push`, containing files under `.tapestry/` only. The guard hook allows a base-branch commit only when the command mentions `tapestry`. If the repository's branch protection rejects the push, keep the commits local and tell the user; never force.

## Secrets

Never commit `.env*`, keys, tokens or credentials, including in tests. `gitleaks` runs in the reviewer's checks; the pre-tool hook blocks obvious cases.
