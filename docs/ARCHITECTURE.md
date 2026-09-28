# Architecture

How Tapestry is put together, and why. Read [AGENTS.md](AGENTS.md) for the roles and handoffs, [TOOLING.md](TOOLING.md) for the tool choices.

## The five stages

```
┌─────────┐   ┌───────────┐   ┌────────┐   ┌──────────────────────┐   ┌─────────┐   ┌───────┐
│  idea   │──▶│ interview │──▶│  plan  │──▶│ run: implement+review│──▶│  merge  │──▶│ learn │
└─────────┘   └───────────┘   └────────┘   └──────────────────────┘   └─────────┘   └───────┘
 /tapestry-new  -interview       -plan        -run (per wave)          -run          -learn
                human ✓ spec     human ✓ plan                          (or human)    human ✓ PR
```

| Stage | Who | Reads | Writes | Gate to next |
|-------|-----|-------|--------|--------------|
| 1 Interview | skill in the main session, with the human | raw idea, config, knowledge, code | `interview.md`, `spec.md` | spec `status: approved` |
| 2 Plan | `planner` agent | spec, interview, knowledge, code | `plan.md`, `tasks/*.md` | plan approved, wave validation passes |
| 3 Implement | N × `implementer` agents, each in a worktree | its task file, shared interfaces, conventions | code on its branch, a PR | PR open, checks in PR body |
| 4 Review | `reviewer` agent per PR, fresh context | diff, task brief, `REVIEW.md`, prior rounds | fix commits on the PR branch, `reviews/*.md`, PR comment | verdict `approve`/`fixed` |
| 4b Merge | orchestrator | ledger, `gh pr checks` | merge, ledger | all tasks in wave merged |
| 5 Learn | `librarian` agent | ledger, reviews, PRs, agent memories | `knowledge/`, `rules/project/`, `CLAUDE.md` notes | human merges the docs PR |

## Filesystem as the state machine

Tapestry has no database and no daemon. State is files in the repo:

```
.tapestry/features/001-url-shortener/
  interview.md     stage 1        status: interviewed
  spec.md          stage 1        status: draft → approved
  plan.md          stage 2        status: draft → approved
  tasks/01-x.md    stage 2→4      status: todo → in_progress → in_review → approved → merged | blocked
  progress.md      all stages     stage: new → interviewed → specced → planned → running → merged → learned
  reviews/02-r1.md stage 4        verdict: approve | fixed | changes_requested | blocked
```

`progress.md` is the ledger: a task board, an append-only event log, a *Blocked / needs human* section and a list of decisions made during execution. The stage skills write it in the main session; during a run the orchestrator is its only writer, recording what agents report (agents on parallel branches never edit `.tapestry/`, so PRs cannot conflict on the ledger). The orchestrator reads it first, reconciles it against `gh` (PRs merged by hand, closed PRs), and only then acts. This is what makes `/tapestry-run` resumable after a crash, a compaction, or a switch of machines, and what lets a human see exactly what happened without reading transcripts.

## Waves: how parallelism stays safe

The planner assigns every task a `wave` and a `touches` list. `scripts/tapestry-validate.sh` refuses a plan where two tasks in the same wave touch overlapping paths (prefix overlap counts) or where a task depends on a task in the same or a later wave. Within a wave, implementers run concurrently; the wave ends when all its PRs are merged; the next wave's worktrees branch from the merged base. Cross-task agreement happens through the *Shared interfaces* section of the plan, copied into each brief, not through agents talking to each other.

This trades some throughput (a wave waits for its slowest task) for zero merge conflicts by construction. Conflicts can still occur when the base branch moves for other reasons; the implementer rebases before opening the PR, and the orchestrator dispatches a bounded rebase (`maxRebaseAttempts`) if a merge fails.

## Isolation

- **Implementers and reviewers** run with `isolation: worktree`: Claude Code gives each a checkout under `.claude/worktrees/`, branched from the base branch. Their Bash runs there. They cannot edit the main checkout.
- **The orchestrator** stays in the main checkout on the base branch and never edits code. The `guard-bash.sh` hook blocks commits on the base branch, so even a confused orchestrator cannot commit source there.
- **Context isolation**: implementers do not see the plan or other tasks; reviewers do not see the implementer's reasoning. Fresh eyes are the point.

## Memory: how the project learns

Three layers, all in git except the last:

1. **`CLAUDE.md` + `.claude/rules/`** — short, always loaded. `rules/project/*.md` use `paths:` frontmatter so a rule about HTTP handlers only loads when an agent edits handler files.
2. **`.tapestry/knowledge/`** — architecture, decisions, conventions, gotchas, glossary. Loaded on demand by the planner and reviewer. Written by the librarian, pruned by the librarian.
3. **Agent memory** — `planner`, `implementer` and `reviewer` have `memory: project`, so Claude Code keeps `.claude/agent-memory/<agent>/MEMORY.md` for each: operational notes like "run tests with `--pool=forks`". Committed, shared across the team. The librarian promotes durable entries to layer 2.
4. **Claude Code auto memory** (`~/.claude/projects/<project>/memory/`) — machine-local, not part of Tapestry, but it works alongside.

The learn loop is deliberately a PR a human merges. It is the one place the team reviews what the agents now believe about the codebase.

## Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `guard-bash.sh` | PreToolUse (Bash) | exit 2 on force-push to protected branches, direct push to protected branches, commits on the base branch, obvious credentials |
| `post-edit-format.sh` | PostToolUse (Edit\|Write) | run `commands.format` on the edited file; never blocks |
| `session-start.sh` | SessionStart | print active features, stages and blocked items as context |

Hooks are deterministic; instructions in agent files are advisory. Anything that must never happen is a hook or a permission deny, not a sentence in a prompt.

## Ceremony scaling

The full pipeline is for changes that span several files, several context windows, or several people. For a change you can describe as a diff in one sentence, the documented quick path is: branch, change, PR, `/tapestry-review <pr>`. `/tapestry-new` suggests the quick path when the idea looks small. `pipeline.skipPipelineBelowLines` is the heuristic threshold.

## What Tapestry deliberately does not do

- No custom orchestration daemon, message bus or "hive". Claude Code's subagents, worktrees and `gh` are enough, and every extra layer is something that fails silently at 2 a.m.
- No GitHub MCP server, no git MCP. See [TOOLING.md](TOOLING.md).
- No auto-merge without green checks; no force-push ever; no unbounded loops.
- No attempt to be language-aware. Commands come from `config.json`; the CI workflow has a marked spot for your toolchain step.
