# Tapestry pipeline rules

Always loaded. These describe *where things live* and *who may do what*. The detailed procedure for each stage is in the matching skill.

## Artifacts

```
.tapestry/
  config.json                 project profile (commands, limits, branch names)
  knowledge/                  long-term project memory (committed)
  templates/                  the shapes below; copy, never edit in place
  features/<NNN-slug>/
    interview.md              stage 1 output
    spec.md                   stage 1 output, one page, human-approved
    plan.md                   stage 2 index: approach, waves table, shared interfaces
    tasks/NN-slug.md          stage 2 output: one self-contained brief per task
    progress.md               ledger: task board + event log + blocked section
    reviews/NN-rK.md          stage 4 output: one report per PR per round
```

Feature ids are `NNN-slug` with a zero-padded sequence (`001-short-links`). Task ids are `NN` inside a feature.

## Stage gates

| From | To | Gate |
|------|----|------|
| new | interviewed | `interview.md` complete, no unanswered mandatory sections (set by `/tapestry-interview` before it writes the spec) |
| interviewed | specced | `spec.md` `status: approved` (human, unless `pipeline.humanApprovesSpec` is false) |
| specced | planned | `plan.md` `status: approved`, every task file exists, wave check passes (no two tasks in one wave share a path in `touches`) |
| planned | running | `/tapestry-run` started, ledger `stage: running` |
| running | merged | every task `merged` |
| merged | learned | `/tapestry-learn` ran, knowledge updated |

## Who may do what

| Actor | May edit | Must not |
|-------|----------|----------|
| Orchestrator (main session in `/tapestry-run`) | `progress.md`, task-file frontmatter (`status`, `branch`, `pr`) — **the only writer of these** | any project source file; any branch other than the base branch (merges only via `gh pr merge`) |
| Interviewer (skill, main session) | `interview.md`, `spec.md`, `progress.md` (stage + event), `knowledge/glossary.md`, `knowledge/decisions.md` | code |
| Planner (agent) | `plan.md`, `tasks/*.md`, `progress.md` task board | code, `spec.md` |
| Implementer (agent, worktree) | files in its task's `touches`, new test files | anything under `.tapestry/` or `.claude/`; the base branch; other tasks' files |
| Reviewer (agent, worktree) | the PR branch (fix commits), its own `reviews/<task>-r<round>.md` | `progress.md`, task briefs, `spec.md`, `plan.md`, the base branch |
| Librarian (agent, worktree) | `.tapestry/knowledge/*`, `.claude/rules/project/*`, the "Project notes" block of `CLAUDE.md`, `progress.md` (stage + event) | code, `spec.md`, `plan.md`, task briefs, reviews |

Why the orchestrator owns the ledger: parallel branches that each append to `progress.md` conflict on every merge. Agents put events in their return message; the orchestrator writes them down on the base branch.

## Ledger discipline

- The event log gets one line per event: `YYYY-MM-DD HH:MM  <actor>  <event>  <detail>`. During `/tapestry-run` the orchestrator writes all of them, naming the agent that caused the event.
- Task status moves only forward: `todo → in_progress → in_review → approved → merged`, with `blocked` reachable from any state.
- Feature stage: `new → interviewed → specced → planned → running → merged → learned`.
- If the ledger and reality disagree (e.g. a PR was merged by hand), the orchestrator fixes the ledger from `gh` output before doing anything else.

## Stop conditions

A refusal by the personal push window is **not** a stop condition for blocking: agents report `HELD: push window` and the orchestrator resumes after the window (see `/tapestry-run`).

Agents stop and write to **Blocked / needs human** when: a spec assumption is wrong; a task would need to change files outside `touches`; a check cannot be run and the task has no other proof; a review reached `pipeline.maxReviewRounds`; a rebase failed `pipeline.maxRebaseAttempts` times; or anything would require force-pushing a protected branch.

## Context hygiene

- Briefs, not plans: an implementer receives its task file and the shared-interfaces section, never `plan.md`.
- Reviewers receive the diff, the task brief and `REVIEW.md`, never the implementer's transcript.
- `CLAUDE.md` stays under 60 lines. Anything longer goes to `.tapestry/knowledge/` or a rule.
