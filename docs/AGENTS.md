# Agents: roles, prompts, handoffs

The prompts themselves live in `.claude/agents/*.md` (agents) and `.claude/skills/*/SKILL.md` (stage commands). This page is the map.

## Roles

| Role | Kind | Context | Tools | Isolation | Memory | Sole responsibility |
|------|------|---------|-------|-----------|--------|---------------------|
| **Interviewer** | skill `/tapestry-interview`, runs in the main session | your session | Read, Write, AskUserQuestion | none (needs the human) | writes `knowledge/decisions.md`, `glossary.md` | remove ambiguity; produce `interview.md` and a one-page approved `spec.md` |
| **Orchestrator** | skill `/tapestry-run`, runs in the main session | your session | Read, Edit (ledger only), Agent, `gh`, `git fetch/worktree` | main checkout, base branch | ledger | dispatch, track, merge; never code |
| **Planner** | agent | fresh | Read, Glob, Grep, Bash, Write, Edit | none (writes only under `.tapestry/`) | `memory: project` | spec → plan + task briefs in validated waves |
| **Implementer** | agent, one per task | fresh | Read, Glob, Grep, Bash, Write, Edit | `isolation: worktree` | `memory: project` | one brief → one PR with proof |
| **Reviewer** | agent, one per PR per round | fresh | Read, Glob, Grep, Bash, Write, Edit | `isolation: worktree` | `memory: project` | inspect PR for bugs, security, practice; apply fixes; report with evidence |
| **Librarian** | agent | fresh | Read, Glob, Grep, Bash, Write, Edit | none | – | distil learnings, prune, open the docs PR |

Why the interview is not an agent: it needs `AskUserQuestion` and a human present. Everything downstream of an approved spec can run without you, which is why those are agents.

## Handoff protocol

Every handoff is a file plus a short dispatch prompt. No agent receives another agent's transcript.

```
human ──raw idea──▶ /tapestry-new ──interview.md skeleton──▶ /tapestry-interview
      ◀─questions──                                          │
      ──answers───▶                                          ▼
                                             spec.md (approved) ──▶ planner
                                                                      │
                                       plan.md + tasks/NN.md (approved) ──▶ orchestrator
                                                                               │ per wave, per task:
                                                          tasks/NN.md ─────────┼──▶ implementer ──PR──▶ reviewer
                                                                               │        ▲                 │
                                                                               │        └──reviews/NN-rK──┘ (≤ maxReviewRounds)
                                                                               │                          │
                                                                               ◀────approve/fixed─────────┘
                                                                               │ merge, next wave
                                                          progress.md (merged) ──▶ librarian ──docs PR──▶ human
```

**Dispatch prompts** are fixed strings in the skills, with only ids substituted. This keeps runs reproducible: the same plan produces the same dispatches.

**Return contracts** (what an agent must say when it finishes) are in each agent file under *Report to the caller*. The orchestrator relies on them: task id, branch, PR number, check results, scope statement, decisions.

**Ledger writes**: during a run, only the orchestrator writes `progress.md` and task frontmatter, on the base branch, from what agents report. Agents on parallel branches never touch the ledger, so PRs never conflict on it. Before acting, the orchestrator reconciles the ledger with `gh` (a PR merged by hand, a closed PR), so the ledger is authoritative but self-healing.

## Orchestration model

- **Within a wave: parallel.** Implementers for all tasks in the wave are dispatched together (capped at `maxParallelImplementers`; Claude Code runs them as background subagents). Reviewers likewise, one per PR.
- **Across waves: sequential.** Wave N+1 starts after every wave-N PR is merged. Dependencies always point to earlier waves; the validator enforces it.
- **Review loop: bounded.** `changes_requested` → the same implementer is resumed with the report path → reviewer round r+1. After `maxReviewRounds`, `blocked`.
- **Merge: in task order, only green.** `gh pr checks --watch` then `gh pr merge --squash --delete-branch`. With `humanMergesPRs: true`, the orchestrator stops at "approved".

### Conflict resolution

| Situation | Handling |
|-----------|----------|
| Two tasks would touch the same file in one wave | rejected at plan validation; the planner moves one to a later wave |
| Base branch moved while a task was in progress | implementer rebases before opening the PR (`--force-with-lease` on its own branch only) |
| PR cannot be merged (behind / conflicting) | orchestrator dispatches the implementer to rebase, at most `maxRebaseAttempts`; reviewer runs a rebase-only round; then merge |
| Reviewer's fix collides with implementer's follow-up | cannot happen: reviewer and implementer never work on the branch at the same time (the review loop is strictly alternating), and a resumed implementer pulls the branch first |
| Two PRs both change the ledger | cannot happen: agents never edit `.tapestry/`; the orchestrator writes the ledger on the base branch |
| Spec assumption proves false during implementation | implementer stops, writes *Blocked / needs human*, opens a draft PR with what exists |
| Two features running at once | supported; they have separate ledgers and branches. Their waves are not coordinated, so keep their `touches` apart or run them one after the other |

### Stop conditions (all agents)

Brief not self-contained · assumption contradicted by code · would need to change files outside `touches` · a proof cannot be run and there is no alternative · review round limit · rebase attempt limit · anything requiring a force-push to a protected branch. In every case the agent writes the specifics to *Blocked / needs human*, sets the task `blocked`, and finishes cleanly. The orchestrator shows that section and asks before continuing.

## Reviewer in detail

The reviewer is the stage the brief cares most about, so its contract is spelled out:

1. Deterministic first: project commands, then scanners (`semgrep`, `gitleaks`, optional `trivy`). Red deterministic checks are blocking findings.
2. Verify the PR's own claims: every proof command in the PR body is re-run.
3. Three passes over the diff and surrounding code: correctness, security, practice. Findings need `file:line` and evidence; naming-based inferences are questions, not findings.
4. Apply safe fixes as `fix(review): …` commits; re-run checks; push. Unsafe or judgement-requiring fixes go in the report as patches with `changes_requested`.
5. Report file from the template committed on the PR branch, PR summary comment, verdict in the return message. (No `gh pr review --approve`: GitHub rejects self-approval from the account that opened the PR; the orchestrator acts on the verdict instead.)

`REVIEW.md` calibrates severity, evidence bar, nit caps and re-review convergence, and is shared with Anthropic's managed Code Review if you enable that too.

## Customising

- Change a role's model: set `models.<role>` in `config.json` and the `model:` line in `.claude/agents/<role>.md` (Claude Code reads the frontmatter; `/tapestry-setup` keeps them in sync when you change the config through it).
- Add a role (e.g. a `docs-writer` for wave-final documentation tasks): copy `implementer.md`, narrow its tools and `touches` policy, and reference it from the planner's method so it can assign tasks to it via the `assignee` frontmatter.
- Tighten the reviewer: add repo-specific "always check" rules to `REVIEW.md`; they reach the reviewer more reliably than a longer agent prompt.
